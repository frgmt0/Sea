// sea/tests/rt/arm64_macos/rt_vmath_abi.s -- the ABI of the vector elementary functions (DESIGN.md 2.12.8, 6.2 "Runtime tests (7d)"): for every case below, sea_<fn>_x is called with x19-x29, d8-d15 and FPCR (AHP and FZ16 set) holding known patterns and the 1024 bytes below sp guard-filled; afterwards x19-x29, sp, d8-d15 and FPCR must be unchanged, the bytes from 1024 to 512 below the incoming sp untouched (at most 512 bytes used), and each result lane bit-identical to the scalar entry sea_<fn> of that lane. The cases put common, special and rare-path lanes (exp |x| >= 512, Payne-Hanek, subnormals, NaN, infinities, pow with |y ln x| >= 512, hypot below 2^-500) in each lane position. Each case prints "<entry> case <n>: ok"; the first failure prints what differs and exits 1.
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

// ---- test helpers (the same block in every 4c runtime test) ----------
// A static string object (rt.inc SEA_STR_*): count SEA_RC_STATIC, tag, length, bytes.
.macro SSTR label, len, text
    .p2align 3
\label:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad \len
    .ascii "\text"
.endm
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
// Print a literal text, then a register in signed decimal (x0-x17 clobbered;
// reg must not be x0-x17 unless it is x1).
.macro KV text, reg
    mov x1, \reg
    .pushsection __TEXT,__cstring,cstring_literals
Lkv\@: .asciz "\text"
    .popsection
    LA x0, Lkv\@
    bl Lput_kv
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

// Lput_kv -- print a text, then x1 in signed decimal. x0 = text. Clobbers
// x0-x17. Callee-saved used: x19 (the value). Frame 32 bytes.
    .p2align 2
Lput_kv:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x1
    bl Lput_cstr
    mov x0, x19
    bl Lput_dec
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Lput_str -- print a string object's bytes between [ and ]. x0 = the
// object. Clobbers x0-x17. Callee-saved used: x19. Frame 32 bytes.
    .p2align 2
Lput_str:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    LA x0, Lput_s_lb
    mov x1, #1
    bl _sea_out_write
    add x0, x19, #SEA_STR_BYTES
    ldr x1, [x19, #SEA_STR_LEN]
    bl _sea_out_write
    LA x0, Lput_s_rb
    mov x1, #1
    bl _sea_out_write
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

    .section __TEXT,__const
Lput_s_lb: .ascii "["
Lput_s_rb: .ascii "]"
    .section __TEXT,__text,regular,pure_instructions
// ---- end of the test helpers ------------------------------------------
// ---- phase-6 helpers (the same block in every 6b runtime test) --------
// Lput_hex -- print x0 as 16 upper-case hexadecimal digits (the bits of an
// f64). Clobbers x0-x17. Frame 32 bytes (frame record, 16 bytes of digits).
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

// Lcat -- print the bytes of a file (x0 = NUL-terminated path) to the
// standard-output buffer; a file that cannot be opened prints
// "<no file>". Clobbers x0-x17. Callee-saved used: x19 (fd). Frame 32
// bytes + a 4096-byte read buffer at [sp].
    .p2align 2
Lcat:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    sub sp, sp, #4096
    mov w1, #0                  // O_RDONLY
    bl _open
    mov w19, w0
    tbz w0, #31, 1f
    TXT "<no file>"
    b 3f
1:  mov w0, w19                 // read up to 4096 bytes
    mov x1, sp
    mov x2, #4096
    bl _read
    cmp x0, #0
    b.le 2f                     // end of file (or an error)
    mov x1, x0
    mov x0, sp
    bl _sea_out_write
    b 1b
2:  mov w0, w19
    bl _close
3:  add sp, sp, #4096
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
// ---- end of the phase-6 helpers ---------------------------------------

// ---- the ABI check ----------------------------------------------------
// The pattern held in a preserved register during the call (n = its number).
.macro PATV reg, n
    LI \reg, (0x5EA0000000000000 | ((\n) << 40) | ((\n) << 8) | (\n))
.endm
.equ GUARD_BYTES, 1024              /* guard-filled below the incoming sp */
.equ STACK_BOUND, 512               /* DESIGN.md 2.12.8: at most 512 bytes used */
.equ GUARD_WORD, 0xC0FFEE5EA5EA5EA5 /* the guard pattern */
.equ FPCR_SET, ((1 << 26) | (1 << 19))  /* AHP and FZ16: no effect on f64 */
// Case record: name, vector entry, scalar entry, x lane 0, x lane 1,
// y lane 0, y lane 1 (y ignored by the one-operand entries).
.equ CR_NAME, 0
.equ CR_VEC, 8
.equ CR_SCAL, 16
.equ CR_X, 24
.equ CR_Y, 40
.equ CR_SIZE, 56

    .section __DATA,__data
    .p2align 4
Lres:   .quad 0, 0                  // the vector result of the last call
Lsp:    .quad 0                     // sp before the call
Lfpcr0: .quad 0                     // FPCR before the test set it
Lfpcr1: .quad 0                     // FPCR during the call
    .section __TEXT,__text,regular,pure_instructions

// Lcheck -- call one case's vector entry under the ABI check.
//   Inputs  : x0 = the case record
//   Outputs : x0 = 0, or the sum of: 1 sp changed, 2 FPCR changed, 4 one
//             of x19-x29 changed, 8 one of d8-d15 changed, 16 a guard
//             word between 1024 and 512 bytes below sp overwritten;
//             Lres = the result vector
//   Clobbers: x0-x17, v0-v7, v16-v31, NZCV
//   Callee-saved used: x19-x29 and d8-d15 hold the patterns during the
//             call (saved and restored here)
//   Frame   : 160 bytes (frame record, x19-x28, d8-d15)
    .p2align 2
Lcheck:
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
    mov x17, x0                     // the record
    ldr q0, [x17, #CR_X]            // the operands
    ldr q1, [x17, #CR_Y]
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
    sub x11, x10, #GUARD_BYTES
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
    ldr x16, [x17, #CR_VEC]
    blr x16                         // the vector entry
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
    // d8-d15 (the low 64 bits are preserved; the upper ones may change)
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
5:  // the guard words from GUARD_BYTES to STACK_BOUND below sp
    mov x10, sp
    sub x11, x10, #GUARD_BYTES
    sub x10, x10, #STACK_BOUND
    LI x12, GUARD_WORD
6:  ldr x9, [x11], #8
    cmp x9, x12
    b.ne 7f
    cmp x11, x10
    b.lo 6b
    b 8f
7:  orr x13, x13, #16
8:  LA x10, Lres
    str q0, [x10]                   // the result vector
    mov x0, x13
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

// Lname -- print the case's entry name. x0 = the record. Clobbers x0-x17.
    .p2align 2
Lname:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    ldr x0, [x0, #CR_NAME]
    bl Lput_cstr
    ldp x29, x30, [sp], #16
    ret

// _sea_main: every case of Lcases in order. x19 = the record, x20 = the
// end, x21 = the case number within its entry, x22 = the previous name,
// x23 = the lane, x24 = the scalar result's bits, x25 = the vector lane's.
    .globl _sea_main
    .p2align 2
_sea_main:
    PROLOGUE
    LA x19, Lcases
    LA x20, Lcases_end
    mov x21, #0
    mov x22, #0
Lmain_next:
    cmp x19, x20
    b.hs Lmain_done
    ldr x9, [x19, #CR_NAME]
    cmp x9, x22
    add x10, x21, #1                // the next case number of this entry
    mov x11, #1                     // or 1 for a new entry
    csel x21, x10, x11, eq
    mov x22, x9
    mov x0, x19
    bl Lcheck
    cbnz x0, Lmain_abi
    // each lane against the scalar entry
    mov x23, #0
2:  add x9, x19, #CR_X
    ldr d0, [x9, x23, lsl #3]       // x of this lane
    add x9, x19, #CR_Y
    ldr d1, [x9, x23, lsl #3]       // y of this lane
    ldr x9, [x19, #CR_SCAL]
    blr x9
    fmov x24, d0
    LA x9, Lres
    ldr x25, [x9, x23, lsl #3]
    cmp x24, x25
    b.ne Lmain_lane                 // compared as bits
    add x23, x23, #1
    cmp x23, #2
    b.lo 2b
    mov x0, x19
    bl Lname
    KV " case ", x21
    TXT ": ok\n"
    add x19, x19, #CR_SIZE
    b Lmain_next
Lmain_done:
    EPILOGUE
Lmain_abi:
    mov x23, x0
    mov x0, x19
    bl Lname
    KV " case ", x21
    KV ": ABI violated, bits ", x23
    TXT "\n"
    bl _sea_out_flush
    mov w0, #1
    bl _exit
Lmain_lane:
    mov x0, x19
    bl Lname
    KV " case ", x21
    KV ": lane ", x23
    TXT " vector="
    mov x0, x25
    bl Lput_hex
    TXT " scalar="
    mov x0, x24
    bl Lput_hex
    TXT "\n"
    bl _sea_out_flush
    mov w0, #1
    bl _exit

// ---- the cases ----------------------------------------------------------
.macro CASE name, x0, x1, y0, y1
    .quad Lnm_\name, _\name\()_x, _\name, \x0, \x1, \y0, \y1
.endm
    .section __TEXT,__cstring,cstring_literals
Lnm_sea_log: .asciz "sea_log_x"
Lnm_sea_exp: .asciz "sea_exp_x"
Lnm_sea_sin: .asciz "sea_sin_x"
Lnm_sea_cos: .asciz "sea_cos_x"
Lnm_sea_pow: .asciz "sea_pow_x"
Lnm_sea_hypot: .asciz "sea_hypot_x"
    .section __DATA,__const
    .p2align 3
Lcases:
    // log: common; subnormal lane 0; negative lane 1; +0 and NaN; +inf
    // and 1e300; 1.0 and the largest subnormal
    CASE sea_log, 0x4004000000000000, 0x3FD3333333333333, 0, 0
    CASE sea_log, 0x0000000000000001, 0x401C000000000000, 0, 0
    CASE sea_log, 0x4024000000000000, 0xBFF0000000000000, 0, 0
    CASE sea_log, 0x0000000000000000, 0x7FF8000000000123, 0, 0
    CASE sea_log, 0x7FF0000000000000, 0x7E37E43C8800759C, 0, 0
    CASE sea_log, 0x3FF0000000000000, 0x000FFFFFFFFFFFFF, 0, 0
    // exp: common; 600 (|x| >= 512) lane 0; -800 lane 1; NaN and a tiny
    // x; +-inf; 0 and 709
    CASE sea_exp, 0x3FF0000000000000, 0xC00C000000000000, 0, 0
    CASE sea_exp, 0x4082C00000000000, 0x3FE0000000000000, 0, 0
    CASE sea_exp, 0x3FD0000000000000, 0xC089000000000000, 0, 0
    CASE sea_exp, 0x7FF8000000000000, 0x3BC79CA10C924223, 0, 0
    CASE sea_exp, 0x7FF0000000000000, 0xFFF0000000000000, 0, 0
    CASE sea_exp, 0x0000000000000000, 0x4086280000000000, 0, 0
    // sin, cos: common; 1e10 (Payne-Hanek) lane 0; 1e300 lane 1; inf and
    // NaN; tiny and 2^23; -0 and 100
    CASE sea_sin, 0x3FF0000000000000, 0x4008000000000000, 0, 0
    CASE sea_sin, 0x4202A05F20000000, 0x3FE0000000000000, 0, 0
    CASE sea_sin, 0x3FE0000000000000, 0x7E37E43C8800759C, 0, 0
    CASE sea_sin, 0x7FF0000000000000, 0x7FF8000000000000, 0, 0
    CASE sea_sin, 0x39B4484BFEEBC2A0, 0x4160000000000000, 0, 0
    CASE sea_sin, 0x8000000000000000, 0x4059000000000000, 0, 0
    CASE sea_cos, 0x3FF0000000000000, 0x4008000000000000, 0, 0
    CASE sea_cos, 0x4202A05F20000000, 0x3FE0000000000000, 0, 0
    CASE sea_cos, 0x3FE0000000000000, 0x7E37E43C8800759C, 0, 0
    CASE sea_cos, 0x7FF0000000000000, 0x7FF8000000000000, 0, 0
    CASE sea_cos, 0x39B4484BFEEBC2A0, 0x4160000000000000, 0, 0
    CASE sea_cos, 0x8000000000000000, 0x4059000000000000, 0, 0
    // pow (x lanes, then y lanes): 2^0.5 and 3^-1.5; (-8)^3 and 0^-1;
    // 1^NaN and 2^1500 (|y ln x| >= 512); NaN^0 and (-2)^0.5; the largest
    // subnormal^2 and 10^-310; (-1)^inf and inf^-2
    CASE sea_pow, 0x4000000000000000, 0x4008000000000000, 0x3FE0000000000000, 0xBFF8000000000000
    CASE sea_pow, 0xC020000000000000, 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000
    CASE sea_pow, 0x3FF0000000000000, 0x4000000000000000, 0x7FF8000000000000, 0x4097700000000000
    CASE sea_pow, 0x7FF8000000000000, 0xC000000000000000, 0x0000000000000000, 0x3FE0000000000000
    CASE sea_pow, 0x000FFFFFFFFFFFFF, 0x4024000000000000, 0x4000000000000000, 0xC073600000000000
    CASE sea_pow, 0xBFF0000000000000, 0x7FF0000000000000, 0x7FF0000000000000, 0xC000000000000000
    // hypot (x lanes, then y lanes): (3, 4) and (1e300, 1e300); (inf,
    // NaN) and (5, 0); two subnormals and (2, 3); (0, 0) and (NaN, 1);
    // a huge and a tiny operand, and (-3, -4)
    CASE sea_hypot, 0x4008000000000000, 0x7E37E43C8800759C, 0x4010000000000000, 0x7E37E43C8800759C
    CASE sea_hypot, 0x7FF0000000000000, 0x4014000000000000, 0x7FF8000000000000, 0x0000000000000000
    CASE sea_hypot, 0x0000123456789ABC, 0x4000000000000000, 0x0000000FEDCBA987, 0x4008000000000000
    CASE sea_hypot, 0x0000000000000000, 0x7FF8000000000000, 0x0000000000000000, 0x3FF0000000000000
    CASE sea_hypot, 0x6974E718D7D7625A, 0xC008000000000000, 0x16687E92154EF7AC, 0xC010000000000000
Lcases_end:

// The site table (none used).
    .section __DATA,__const
    .p2align 3
    .globl _sea_sites
_sea_sites:
    .quad 0
