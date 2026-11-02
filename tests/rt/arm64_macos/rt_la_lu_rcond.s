// sea/tests/rt/arm64_macos/rt_la_lu_rcond.s -- sea_rcond (DESIGN.md 2.13.5, 2.13.6 "RCOND", L-io, Decision 129; LANGUAGE.md 10.8) on handles made by sea_lu, expected values derived by hand from 2.13.6's steps. The special values in Decision 129's order: order 0 +Inf; ||A||_1 NaN gives NaN, also when a zero pivot is recorded too ([0 1; NaN 1]); a zero pivot 0; ||A||_1 = +Inf 0; the guard after every solve (the user's 8c decision: a sum |x| that is +Inf or NaN after any solve of steps 1-3 gives 0 at once): order 1 with the pivot 2^-1070 (step 1's first solve overflows), diag(1, 2^-1070) (the same; without the guard the steps reach est = 1 through 0 * Inf = NaN iterates), and [1 MAX; 0 0.5] (MAX the largest double: step 1's first solve gives x = [-MAX, 1], sum MAX, finite; the second-kind solve on xi = [-1, 1] gives x[1] = (1 + MAX) / 0.5 = +Inf, so only the L^-T U^-T guard fires) all 0. Estimates found exactly by the steps: [4] (1), diag(1, 2, 4, 8) (1/8: step 2 stops on a repeated sign vector, step 3's t stays below est), [1 -1; 0 1] (1/4), [2 1; 4 3] with an interchange ((1 / 3.5) / 6, its two divisions rounded). The handle keeps count 1 and its bytes, the live count does not change (the scratch is freed), the result is in d0
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

// ---- test helpers (the same block in the rt_la_lu, rt_la_private and
// rt_la_free tests that print; not in the rt_la_lu_err_* programs) -------
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
// The live-object and freed-object counters of rt_mem.s into a register.
.macro LIVE reg
    adrp \reg, _sea_live@PAGE
    ldr \reg, [\reg, _sea_live@PAGEOFF]
.endm
.macro FREED reg
    adrp \reg, _sea_freed@PAGE
    ldr \reg, [\reg, _sea_freed@PAGEOFF]
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
// A frame record and x19-x28 (all callee-saved).
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
// The private handle layout (DESIGN.md 2.13.6 "Handles", 4.8).
.equ H_N, 16
.equ H_ANORM, 24
.equ H_ZP, 32
.equ H_F, 64

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
    cneg x10, x0, lt            // magnitude
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
    add x9, sp, #16
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
    b.ls 1f
    TXT "NaN"
    b 2f
1:  bl Lput_hex
2:  ldp x29, x30, [sp], #16
    ret

// Lput_fs -- print x1 doubles at x0, each after a space. Clobbers
// x0-x17. Callee-saved used: x19, x20. Frame 32 bytes.
    .p2align 2
Lput_fs:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    mov x20, x1
1:  cbz x20, 2f
    TXT " "
    ldr x0, [x19], #8
    bl Lput_f
    sub x20, x20, #1
    b 1b
2:  ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Lmk -- a new dynamic f64 array (count 1) holding a copy of the doubles.
//   Inputs  : x0 = rank, x1 = rows, x2 = cols (1 for a vector), x3 = the
//             source doubles (rows * cols, column-major)
//   Outputs : x0 = the array
//   Clobbers: x0-x17, v0-v7, v16-v31
//   Callee-saved used: x19 = the source, x20 = the array. Frame 32 bytes.
    .p2align 2
Lmk:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x3
    mov x3, x2                  // cols
    mov x2, x1                  // rows
    mov x1, x0                  // rank
    mov x0, #SEA_EK_F64
    mov x4, #0                  // site 0
    bl _sea_arr_new_u
    mov x20, x0
    ldr x9, [x20, #SEA_ARR_ROWS]
    ldr x10, [x20, #SEA_ARR_COLS]
    mul x2, x9, x10
    lsl x2, x2, #3
    cbz x2, 1f
    ldr x0, [x20, #SEA_ARR_DATA]
    mov x1, x19
    bl _memcpy
1:  mov x0, x20
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
// ---- end of the test helpers ------------------------------------------

// ---- the test ---------------------------------------------------------
.zerofill __DATA,__bss,Lsave,512,4

// Lcase -- `<label>: <rcond bits> own ok|own BAD` for sea_rcond(sea_lu(A)).
//   Inputs  : x0 = record: label, n, A data
//   Callee-saved used: x19 = record, x20 = A, x21 = F, x22 = live before,
//             x23 = the result bits, x24 = faults, x25 = F's bytes
//   Frame   : 96 bytes
    .p2align 2
Lcase:
    PROLOGUE
    mov x19, x0
    mov x0, #2
    ldr x1, [x19, #8]
    mov x2, x1
    ldr x3, [x19, #16]
    bl Lmk
    mov x20, x0
    mov x1, #0
    bl _sea_lu
    mov x21, x0
    ldr x9, [x21, #H_N]         // the handle's bytes: 64 + 8n^2 + 4n
    mul x25, x9, x9
    lsl x25, x25, #3
    add x25, x25, x9, lsl #2
    add x25, x25, #H_F
    LA x0, Lsave
    mov x1, x21
    mov x2, x25
    bl _memcpy
    LIVE x22
    mov x0, x21
    mov x1, #0
    bl _sea_rcond
    fmov x23, d0
    mov x24, #0
    LIVE x9
    cmp x9, x22
    cinc x24, x24, ne           // nothing new is live
    ldr x9, [x21, #SEA_OBJ_RC]
    cmp x9, #1
    cinc x24, x24, ne           // the handle not retained
    mov x0, x21
    LA x1, Lsave
    mov x2, x25
    bl _memcmp
    cmp w0, #0
    cinc x24, x24, ne           // nor changed
    ldr x0, [x19]
    bl Lput_cstr
    TXT ": "
    mov x0, x23
    bl Lput_f
    cbnz x24, 1f
    TXT " own ok\n"
    b 2f
1:  TXT " own BAD\n"
2:  REL x21
    REL x20
    EPILOGUE

    .globl _sea_main
    .p2align 2
_sea_main:
    PROLOGUE
    LA x19, Lcases
1:  ldr x9, [x19]
    cbz x9, 2f
    mov x0, x19
    bl Lcase
    add x19, x19, #24
    b 1b
2:  EPILOGUE

.equ PZ, 0x0000000000000000
.equ QN, 0x7FF8000000000000
.equ INF, 0x7FF0000000000000
.equ ONE, 0x3FF0000000000000
.equ MONE, 0xBFF0000000000000
.equ TWO, 0x4000000000000000
.equ THREE, 0x4008000000000000
.equ FOUR, 0x4010000000000000
.equ EIGHT, 0x4020000000000000
.equ TINY, 0x0000000000000010   /* 2^-1070 */
.equ DMAX, 0x7FEFFFFFFFFFFFFF   /* the largest finite double */
.equ HALF, 0x3FE0000000000000

    .section __DATA,__const
    .p2align 3
Lcases:
    .quad Lc0, 0, Lm4
    .quad Lc1, 1, Lmnan
    .quad Lc2, 2, Lmzn
    .quad Lc3, 2, Lmz
    .quad Lc4, 1, Lminf
    .quad Lc5, 1, Lmtiny
    .quad Lc6, 1, Lm4
    .quad Lc7, 4, Lmd
    .quad Lc8, 2, Lmu
    .quad Lc9, 2, Lm22
    .quad Lc10, 2, Lmdt
    .quad Lc11, 2, Lmbig
    .quad 0
Lc0: .asciz "order 0"
Lc1: .asciz "[NaN]"
Lc2: .asciz "[0 1; NaN 1]"
Lc3: .asciz "[0 0; 0 1]"
Lc4: .asciz "[Inf]"
Lc5: .asciz "[2^-1070]"
Lc6: .asciz "[4]"
Lc7: .asciz "diag(1, 2, 4, 8)"
Lc8: .asciz "[1 -1; 0 1]"
Lc9: .asciz "[2 1; 4 3]"
Lc10: .asciz "diag(1, 2^-1070)"
Lc11: .asciz "[1 MAX; 0 0.5]"
    .p2align 3
Lm4:    .quad FOUR
Lmnan:  .quad QN
Lmzn:   .quad PZ, QN, ONE, ONE
Lmz:    .quad PZ, PZ, PZ, ONE
Lminf:  .quad INF
Lmtiny: .quad TINY
Lmd:    .quad ONE, PZ, PZ, PZ,  PZ, TWO, PZ, PZ,  PZ, PZ, FOUR, PZ,  PZ, PZ, PZ, EIGHT
Lmu:    .quad ONE, PZ, MONE, ONE
Lm22:   .quad TWO, FOUR, ONE, THREE
Lmdt:   .quad ONE, PZ, PZ, TINY
Lmbig:  .quad ONE, PZ, DMAX, HALF
    .section __TEXT,__text,regular,pure_instructions

    .section __DATA,__const
    .p2align 3
    .globl _sea_sites
_sea_sites:
    .quad Lsite_file
    .quad 12
Lsite_file:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 6
    .ascii "la.sea"
