// sea/tests/rt/arm64_macos/rt_la_gemm_abi.s -- the ABI of sea_gemv, sea_vecmat and sea_matmul (DESIGN.md 2.13.5 "ABI", "Stack"; 2.13.8 "Runtime"): each case is called with x19-x29, d8-d15 and FPCR (AHP and FZ16 set) holding known patterns and the 128 KiB below sp guard-filled; afterwards x19-x29, sp, d8-d15 and FPCR must be unchanged and the call, its callees included (sea_arr_new(_u), _bsk_kern_gemm with its packing), must have written at most SEA_STACK_MARGIN bytes below sp (DESIGN.md 4.6: the margin covers the runtime frames). Cases: GEMV and VECMAT with panels and tails, MATMUL small and large (a 130x300 @ 300x90 product reaches the blocked kernel paths), and the empty and zero shortcuts. Each case prints `<label>: ok`; a failure prints its error bits and exits 1. The cases run under the first variant (x86_64: sse2) and under the selected one.
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

// ---- test helpers (the same block in every rt_la_gemm test) -----------
// The address of a label.
.macro LA reg, label
    adrp \reg, \label@PAGE
    add \reg, \reg, \label@PAGEOFF
.endm
// Load a 64-bit constant into a register.
.macro LI reg, val
    movz \reg, #((\val) & 0xffff)
    movk \reg, #(((\val) >> 16) & 0xffff), lsl #16
    movk \reg, #(((\val) >> 32) & 0xffff), lsl #32
    movk \reg, #(((\val) >> 48) & 0xffff), lsl #48
.endm
// Print a literal text (x0-x17 clobbered).
.macro TXT text
    .pushsection __TEXT,__cstring,cstring_literals
Ltxt\@: .asciz "\text"
    .popsection
    LA x0, Ltxt\@
    bl Lput_cstr
.endm
// The live-object counter of rt_mem.s into a register.
.macro LIVE reg
    adrp \reg, _sea_live@PAGE
    ldr \reg, [\reg, _sea_live@PAGEOFF]
.endm
// The release sequence of pass 4 (DESIGN.md 4.9) on the object in reg:
// the count drops by one unless static, _sea_free at 0 (x0-x17 clobbered).
.macro REL reg
    mov x0, \reg
    ldr x10, [x0]
    cbz x10, Lrel\@
    subs x10, x10, #1
    str x10, [x0]
    b.ne Lrel\@
    bl _sea_free
Lrel\@:
.endm
// _sea_main's frame: the frame record and x19-x28 (all callee-saved).
.macro PROLOGUE
    stp x29, x30, [sp, #-96]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp x27, x28, [sp, #80]
.endm
.macro EPILOGUE
    ldp x27, x28, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #96
    ret
.endm
// The entries, by their index in the case tables.
.equ ENT_GEMV, 0
.equ ENT_VECMAT, 1
.equ ENT_MATMUL, 2
// The variant of the first pass: the one form of arm64-macos.
.equ FIRST_VARIANT, SEA_VAR_NEON

    .section __TEXT,__text,regular,pure_instructions

// Lput_cstr -- print a NUL-terminated text. x0 = text. Clobbers x0-x17.
// Callee-saved used: x19 (the text). Frame 32 bytes.
    .p2align 2
Lput_cstr:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    bl _strlen                  // its length
    mov x1, x0
    mov x0, x19
    bl _sea_out_write           // into the standard-output buffer
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Lput_dec -- print x0 as a signed decimal. Clobbers x0-x17. Frame 48
// bytes (frame record, 32 bytes of digits).
    .p2align 2
Lput_dec:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    add x9, sp, #48             // digits right to left from the end
    cmp x0, #0
    cset w11, lt                // negative?
    cneg x10, x0, lt            // magnitude (2^63 exact as unsigned)
    mov x12, #10
1:  udiv x13, x10, x12
    msub x14, x13, x12, x10     // the next digit
    add w14, w14, #'0'
    strb w14, [x9, #-1]!
    mov x10, x13
    cbnz x10, 1b
    cbz w11, 2f
    mov w14, #'-'
    strb w14, [x9, #-1]!
2:  mov x0, x9
    add x1, sp, #48
    sub x1, x1, x9              // the number of bytes
    bl _sea_out_write
    ldp x29, x30, [sp], #48
    ret

// Lput_hex -- print x0 as 16 upper-case hexadecimal digits. Clobbers
// x0-x17. Frame 32 bytes (frame record, 16 bytes of digits).
    .p2align 2
Lput_hex:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    add x9, sp, #16             // the digits at [sp + 16, sp + 32)
    mov x10, #16
1:  and x11, x0, #0xf           // the lowest digit, written right to left
    add x12, x11, #'0'
    add x13, x11, #('A' - 10)
    cmp x11, #10
    csel x12, x13, x12, hs
    sub x10, x10, #1
    strb w12, [x9, x10]
    lsr x0, x0, #4
    cbnz x10, 1b
    mov x0, x9
    mov x1, #16
    bl _sea_out_write
    ldp x29, x30, [sp], #32
    ret

// Lput_f -- print the f64 bits in x0: `NaN` for every NaN (its bits are
// not observable, LANGUAGE.md 6.5), else the 16 hexadecimal digits.
// Clobbers x0-x17. Frame 16 bytes.
    .p2align 2
Lput_f:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    lsl x9, x0, #1              // drop the sign
    LI x10, 0xFFE0000000000000  // the exponent all ones, shifted
    cmp x9, x10
    b.ls 1f                     // not above +inf: a number
    TXT "NaN"
    b 2f
1:  bl Lput_hex
2:  ldp x29, x30, [sp], #16
    ret

// Lmk -- a new dynamic f64 array (count 1) holding a copy of n doubles.
//   Inputs  : x0 = rank, x1 = rows, x2 = cols (1 for a vector), x3 = the
//             source doubles (rows * cols of them, column-major)
//   Outputs : x0 = the array
//   Clobbers: x0-x17, v0-v7, v16-v31
//   Callee-saved used: x19 = the source, x20 = the array. Frame 32 bytes.
    .p2align 2
Lmk:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x3
    mov x4, x2
    mov x3, x4                  // cols
    mov x2, x1                  // rows
    mov x1, x0                  // rank
    mov x0, #SEA_EK_F64
    mov x4, #0                  // site 0
    bl _sea_arr_new_u
    mov x20, x0
    ldr x9, [x20, #SEA_ARR_ROWS]
    ldr x10, [x20, #SEA_ARR_COLS]
    mul x2, x9, x10
    lsl x2, x2, #3              // the bytes
    ldr x0, [x20, #SEA_ARR_DATA]
    mov x1, x19
    bl _memcpy
    mov x0, x20
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Ldirty -- leave a freed block of the class a result of this shape takes
// with every element 42.0 (#4045000000000000): the allocator hands the
// most recently freed block of a class out first, so a result that is not
// fully written shows it.
//   Inputs  : x0 = rank, x1 = rows, x2 = cols
//   Clobbers: x0-x17
//   Callee-saved used: x19 = the array. Frame 32 bytes.
    .p2align 2
Ldirty:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x3, x2
    mov x2, x1
    mov x1, x0
    mov x0, #SEA_EK_F64
    mov x4, #0
    bl _sea_arr_new_u
    mov x19, x0
    ldr x9, [x19, #SEA_ARR_ROWS]
    ldr x10, [x19, #SEA_ARR_COLS]
    mul x9, x9, x10             // elements
    ldr x10, [x19, #SEA_ARR_DATA]
    LI x11, 0x4045000000000000
    cbz x9, 2f
1:  str x11, [x10], #8
    subs x9, x9, #1
    b.ne 1b
2:  REL x19                     // count 1 -> freed
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Lcall -- call an entry by its table index.
//   Inputs  : x0 = ENT_*, x1 = the left operand, x2 = the right operand
//   Outputs : x0 = the entry's result
//   Clobbers: as the entries. Frame 16 bytes.
    .p2align 2
Lcall:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    LA x9, Lentries
    ldr x9, [x9, x0, lsl #3]
    mov x0, x1
    mov x1, x2
    mov x2, #0                  // site 0
    blr x9
    ldp x29, x30, [sp], #16
    ret
    .section __DATA,__const
    .p2align 3
Lentries:
    .quad _sea_gemv, _sea_vecmat, _sea_matmul
    .section __TEXT,__text,regular,pure_instructions
// ---- end of the test helpers ------------------------------------------

// ---- the ABI check ----------------------------------------------------
// The pattern held in a preserved register during the call (n = its number).
.macro PATV reg, n
    LI \reg, (0x5EA0000000000000 | ((\n) << 40) | ((\n) << 8) | (\n))
.endm
.equ GUARD_BYTES, 131072            /* guard-filled below the incoming sp */
.equ GUARD_WORD, 0xC0FFEE5EA5EA5EA5 /* the guard pattern */
.equ FPCR_SET, ((1 << 26) | (1 << 19))  /* AHP and FZ16: no effect on f64 */
.if GUARD_BYTES <= SEA_STACK_MARGIN
    .error "the guard must reach below SEA_STACK_MARGIN"
.endif

    .section __DATA,__data
    .p2align 3
Lres:    .quad 0                    // the result of the last call
Lsp:     .quad 0                    // sp before the call
Lfpcr0:  .quad 0                    // FPCR before the test set it
Lfpcr1:  .quad 0                    // FPCR during the call
Ldepth:  .quad 0                    // bytes below sp the call wrote
    .section __TEXT,__text,regular,pure_instructions

// Lprobe -- call an entry under the ABI check.
//   Inputs  : x0 = the entry, x1 = left, x2 = right (site 0)
//   Outputs : x0 = 0, or the sum of: 1 sp changed, 2 FPCR changed, 4 one
//             of x19-x29 changed, 8 one of d8-d15 changed, 16 the call
//             wrote more than SEA_STACK_MARGIN bytes below sp;
//             Lres = the result, Ldepth = the bytes written below sp
//   Clobbers: x0-x17, v0-v7, v16-v31, NZCV
//   Callee-saved used: x19-x29 and d8-d15 hold the patterns during the
//             call (saved and restored here)
//   Frame   : 160 bytes (frame record, x19-x28, d8-d15)
    .p2align 2
Lprobe:
    stp x29, x30, [sp, #-160]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp x27, x28, [sp, #80]
    stp d8, d9, [sp, #96]
    stp d10, d11, [sp, #112]
    stp d12, d13, [sp, #128]
    stp d14, d15, [sp, #144]
    mov x16, x0                     // the entry
    mov x0, x1                      // its arguments
    mov x1, x2
    mov x2, #0
    // FPCR: AHP and FZ16 set; the value read back is the one to keep
    mrs x9, fpcr
    LA x10, Lfpcr0
    str x9, [x10]
    LI x11, FPCR_SET
    orr x9, x9, x11
    msr fpcr, x9
    mrs x9, fpcr
    LA x10, Lfpcr1
    str x9, [x10]
    // the guard below sp, and sp itself
    mov x10, sp
    mov x13, #GUARD_BYTES
    sub x11, x10, x13
    LI x12, GUARD_WORD
1:  str x12, [x11], #8
    cmp x11, x10
    b.lo 1b
    LA x11, Lsp
    str x10, [x11]
    // the patterns
    PATV x19, 19
    PATV x20, 20
    PATV x21, 21
    PATV x22, 22
    PATV x23, 23
    PATV x24, 24
    PATV x25, 25
    PATV x26, 26
    PATV x27, 27
    PATV x28, 28
    PATV x29, 29
    PATV x9, 108
    fmov d8, x9
    PATV x9, 109
    fmov d9, x9
    PATV x9, 110
    fmov d10, x9
    PATV x9, 111
    fmov d11, x9
    PATV x9, 112
    fmov d12, x9
    PATV x9, 113
    fmov d13, x9
    PATV x9, 114
    fmov d14, x9
    PATV x9, 115
    fmov d15, x9
    blr x16                         // the entry
    LA x9, Lres
    str x0, [x9]
    mov x13, #0                     // the error bits
    // sp (restored from Lsp in any case, so that the frame is reachable)
    LA x10, Lsp
    ldr x10, [x10]
    mov x9, sp
    cmp x9, x10
    b.eq 2f
    orr x13, x13, #1
2:  mov sp, x10
    // FPCR
    mrs x9, fpcr
    LA x10, Lfpcr1
    ldr x10, [x10]
    cmp x9, x10
    b.eq 3f
    orr x13, x13, #2
3:  LA x10, Lfpcr0
    ldr x10, [x10]
    msr fpcr, x10                   // the original FPCR
    // x19-x29
    mov x14, #0
    PATV x9, 19
    cmp x19, x9
    cinc x14, x14, ne
    PATV x9, 20
    cmp x20, x9
    cinc x14, x14, ne
    PATV x9, 21
    cmp x21, x9
    cinc x14, x14, ne
    PATV x9, 22
    cmp x22, x9
    cinc x14, x14, ne
    PATV x9, 23
    cmp x23, x9
    cinc x14, x14, ne
    PATV x9, 24
    cmp x24, x9
    cinc x14, x14, ne
    PATV x9, 25
    cmp x25, x9
    cinc x14, x14, ne
    PATV x9, 26
    cmp x26, x9
    cinc x14, x14, ne
    PATV x9, 27
    cmp x27, x9
    cinc x14, x14, ne
    PATV x9, 28
    cmp x28, x9
    cinc x14, x14, ne
    PATV x9, 29
    cmp x29, x9
    cinc x14, x14, ne
    cbz x14, 4f
    orr x13, x13, #4
4:  mov x29, sp                     // this frame again
    // d8-d15 (the low 64 bits are preserved)
    mov x14, #0
    PATV x9, 108
    fmov x10, d8
    cmp x10, x9
    cinc x14, x14, ne
    PATV x9, 109
    fmov x10, d9
    cmp x10, x9
    cinc x14, x14, ne
    PATV x9, 110
    fmov x10, d10
    cmp x10, x9
    cinc x14, x14, ne
    PATV x9, 111
    fmov x10, d11
    cmp x10, x9
    cinc x14, x14, ne
    PATV x9, 112
    fmov x10, d12
    cmp x10, x9
    cinc x14, x14, ne
    PATV x9, 113
    fmov x10, d13
    cmp x10, x9
    cinc x14, x14, ne
    PATV x9, 114
    fmov x10, d14
    cmp x10, x9
    cinc x14, x14, ne
    PATV x9, 115
    fmov x10, d15
    cmp x10, x9
    cinc x14, x14, ne
    cbz x14, 5f
    orr x13, x13, #8
    // the depth: the lowest guard word overwritten, from the bottom up
5:  mov x10, sp
    mov x9, #GUARD_BYTES
    sub x11, x10, x9
    LI x12, GUARD_WORD
6:  cmp x11, x10
    b.hs 7f
    ldr x9, [x11]
    cmp x9, x12
    b.ne 7f
    add x11, x11, #8
    b 6b
7:  sub x9, x10, x11                // 0 when nothing was written
    LA x10, Ldepth
    str x9, [x10]
    mov x10, #SEA_STACK_MARGIN
    cmp x9, x10
    b.ls 8f
    orr x13, x13, #16
8:  mov x0, x13
    ldp d14, d15, [sp, #144]
    ldp d12, d13, [sp, #128]
    ldp d10, d11, [sp, #112]
    ldp d8, d9, [sp, #96]
    ldp x27, x28, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #160
    ret

// Lnew -- a new dynamic f64 array (count 1), element i = (i mod 7) - 3.
//   Inputs  : x0 = rank, x1 = rows, x2 = cols
//   Outputs : x0 = the array
//   Clobbers: x0-x17, d0. Frame 16 bytes.
    .p2align 2
Lnew:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x3, x2
    mov x2, x1
    mov x1, x0
    mov x0, #SEA_EK_F64
    mov x4, #0
    bl _sea_arr_new_u
    ldr x9, [x0, #SEA_ARR_ROWS]
    ldr x10, [x0, #SEA_ARR_COLS]
    mul x9, x9, x10
    ldr x10, [x0, #SEA_ARR_DATA]
    mov x11, #0                     // i
    mov x12, #7
1:  cmp x11, x9
    b.hs 2f
    udiv x13, x11, x12
    msub x13, x13, x12, x11         // i mod 7
    sub x13, x13, #3
    scvtf d0, x13
    str d0, [x10, x11, lsl #3]
    add x11, x11, #1
    b 1b
2:  ldp x29, x30, [sp], #16
    ret

// A case record (8-byte words): label, ENT_*, the left operand's rank,
// rows, cols, the right operand's rank, rows, cols.
.equ AR_SIZE, 64

// Lcases_run -- every ABI case under the current variant: `<label>: ok`,
// or `<label>: BAD <bits>` (the error bits of Lprobe) and exit 1.
//   Callee-saved used: x19 = the record, x20 = left, x21 = right,
//             x22 = the error bits, x23 = the deepest write.
//   Outputs : x0 = the deepest write of the cases. Frame 96 bytes.
    .p2align 2
Lcases_run:
    PROLOGUE
    LA x19, Lacases
    mov x23, #0
1:  ldr x9, [x19]
    cbz x9, 9f
    ldp x0, x1, [x19, #16]
    ldr x2, [x19, #32]
    bl Lnew
    mov x20, x0
    ldp x0, x1, [x19, #40]
    ldr x2, [x19, #56]
    bl Lnew
    mov x21, x0
    LA x9, Lentries
    ldr x10, [x19, #8]
    ldr x0, [x9, x10, lsl #3]
    mov x1, x20
    mov x2, x21
    bl Lprobe
    mov x22, x0
    LA x9, Ldepth
    ldr x9, [x9]
    cmp x9, x23
    csel x23, x9, x23, hi
    ldr x0, [x19]
    bl Lput_cstr
    cbnz x22, 2f
    TXT ": ok\n"
    LA x9, Lres
    ldr x9, [x9]
    REL x9
    REL x20
    REL x21
    add x19, x19, #AR_SIZE
    b 1b
2:  TXT ": BAD "
    mov x0, x22
    bl Lput_dec
    TXT "\n"
    bl _sea_out_flush
    mov x0, #1
    bl _exit
9:  mov x0, x23
    EPILOGUE

// ---- the test ---------------------------------------------------------
// _sea_main -- the cases under FIRST_VARIANT, then under the variant main
// selected. Callee-saved used: x19 (the selected variant). Frame 96.
    .globl _sea_main
    .p2align 2
_sea_main:
    PROLOGUE
    LA x9, _sea_variant
    ldr x19, [x9]
    mov x10, #FIRST_VARIANT
    str x10, [x9]
    TXT "pass 1\n"
    bl Lcases_run
    LA x9, _sea_variant
    str x19, [x9]
    TXT "pass 2\n"
    bl Lcases_run
    EPILOGUE

    .section __DATA,__const
    .p2align 3
Lacases:
    .quad Ln0, ENT_GEMV, 2, 19, 5, 1, 5, 1
    .quad Ln1, ENT_GEMV, 2, 37, 33, 1, 33, 1
    .quad Ln2, ENT_GEMV, 2, 4, 0, 1, 0, 1
    .quad Ln3, ENT_GEMV, 2, 0, 3, 1, 3, 1
    .quad Ln4, ENT_VECMAT, 1, 13, 1, 2, 13, 3
    .quad Ln5, ENT_VECMAT, 1, 40, 1, 2, 40, 17
    .quad Ln6, ENT_VECMAT, 1, 0, 1, 2, 0, 5
    .quad Ln7, ENT_MATMUL, 2, 3, 5, 2, 5, 2
    .quad Ln8, ENT_MATMUL, 2, 70, 40, 2, 40, 65
    .quad Ln9, ENT_MATMUL, 2, 130, 300, 2, 300, 90
    .quad Ln10, ENT_MATMUL, 2, 4, 0, 2, 0, 6
    .quad Ln11, ENT_MATMUL, 2, 0, 3, 2, 3, 6
    .quad 0
Ln0:  .asciz "gemv 19x5 @ 5"
Ln1:  .asciz "gemv 37x33 @ 33"
Ln2:  .asciz "gemv 4x0 @ 0"
Ln3:  .asciz "gemv 0x3 @ 3"
Ln4:  .asciz "vecmat 13 @ 13x3"
Ln5:  .asciz "vecmat 40 @ 40x17"
Ln6:  .asciz "vecmat 0 @ 0x5"
Ln7:  .asciz "matmul 3x5 @ 5x2"
Ln8:  .asciz "matmul 70x40 @ 40x65"
Ln9:  .asciz "matmul 130x300 @ 300x90"
Ln10: .asciz "matmul 4x0 @ 0x6"
Ln11: .asciz "matmul 0x3 @ 3x6"
    .p2align 3
    .globl _sea_sites
_sea_sites:
    .quad Lsite_file
    .quad 1
Lsite_file:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 6
    .ascii "la.sea"
