// sea/tests/rt/arm64_macos/rt_la_lu_values.s -- sea_lu, sea_chol, sea_lu_solve, sea_chol_solve and sea_solve on small exact matrices (DESIGN.md 2.13.5, 2.13.6 "LU", "CHOL", "Triangular solves", "CHOL_SOLVE", "SOLVE", "Handles"; 2.13.2; L-in, L-im, L-jb; LANGUAGE.md 10.8), every expected value derived by hand from 2.13.6's steps. Handles: the tag, n, ||A||_1 (dlange's NaN rule), the first zero pivot, the factor and the pivots (an interchange, a NaN first candidate that is kept, a zero pivot with a NaN below it, two interchanges of a 3x3, a Chol from the upper triangle only with NaN and garbage below, order 0). Solves: a vector and a matrix B (one solution element -0), the Cholesky path, the LU path for a non-symmetric A whose upper triangle alone is positive definite, the LU fallback of a symmetric indefinite A, a symmetric NaN pair propagating, a +0/-0 pair taken as symmetric. Ownership on every call: the live count rises by exactly one, the result has count 1 and its tag, the arguments (handles included) keep count 1 and their bytes
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
.zerofill __DATA,__bss,Lsave,8192,4     // a copy of an argument's block

// A case record (8-byte words): label, kind, n, A data, B rank, B rows,
// B cols, B data.
.equ K_LU, 0                            // the handle of sea_lu(A)
.equ K_CHOL, 1                          // the handle of sea_chol(A)
.equ K_LUS, 2                           // sea_lu_solve(sea_lu(A), B)
.equ K_CHS, 3                           // sea_chol_solve(sea_chol(A), B)
.equ K_SOL, 4                           // sea_solve(A, B)
.equ CR_SIZE, 64

// Lsnap -- copy x1 bytes of the block at x0 into Lsave. Clobbers x0-x17.
    .p2align 2
Lsnap:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x2, x1
    mov x1, x0
    LA x0, Lsave
    bl _memcpy
    ldp x29, x30, [sp], #16
    ret

// Lsame -- x0 = 0 when the x1 bytes at x0 equal Lsave, else 1.
    .p2align 2
Lsame:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x2, x1
    LA x1, Lsave
    bl _memcmp
    cmp w0, #0
    cset x0, ne
    ldp x29, x30, [sp], #16
    ret

// Lhbytes -- the bytes of a handle: 64 + 8 n^2 (+ 4 n for an Lu).
// x0 = the handle -> x0. Clobbers x9-x11.
    .p2align 2
Lhbytes:
    ldr x9, [x0, #H_N]
    ldrb w10, [x0, #SEA_OBJ_TAG]
    mul x11, x9, x9
    lsl x11, x11, #3
    cmp w10, #SEA_TAG_LU
    b.ne 1f
    add x11, x11, x9, lsl #2
1:  add x0, x11, #H_F
    ret

// Lcase -- one record (see above): the arguments as fresh objects
// (count 1), the call, the ownership checks, the line, the releases.
//   Callee-saved used: x19 = record, x20 = A, x21 = B or 0, x22 = F (the
//             handle argument) or 0, x23 = the live count before the
//             call, x24 = result, x25 = faults, x26 = scratch
//   Frame   : 96 bytes
    .p2align 2
Lcase:
    PROLOGUE
    mov x19, x0
    mov x21, #0
    mov x22, #0
    mov x0, #2                  // A: n x n
    ldr x1, [x19, #16]
    mov x2, x1
    ldr x3, [x19, #24]
    bl Lmk
    mov x20, x0
    ldr x9, [x19, #8]
    cmp x9, #K_LUS
    b.lo 1f
    ldp x0, x1, [x19, #32]      // B
    ldp x2, x3, [x19, #48]
    bl Lmk
    mov x21, x0
    ldr x9, [x19, #8]           // the handle argument, made before the window
    cmp x9, #K_SOL
    b.eq 1f
    mov x0, x20
    mov x1, #0
    cmp x9, #K_LUS
    b.ne 2f
    bl _sea_lu
    b 3f
2:  bl _sea_chol
3:  mov x22, x0
    bl Lhbytes
    mov x1, x0
    mov x0, x22
    bl Lsnap                    // the handle's bytes before the call
1:  // A's and B's bytes are fixed in their tables: compared below.
    LIVE x23
    ldr x9, [x19, #8]
    mov x1, #0                  // site 0 for the one-argument entries
    mov x0, x20
    cbz x9, 4f
    cmp x9, #K_CHOL
    b.eq 5f
    mov x2, #0                  // site 0
    mov x1, x21
    mov x0, x22
    cmp x9, #K_LUS
    b.eq 6f
    cmp x9, #K_CHS
    b.eq 7f
    mov x0, x20                 // K_SOL
    bl _sea_solve
    b 8f
4:  bl _sea_lu
    b 8f
5:  bl _sea_chol
    b 8f
6:  bl _sea_lu_solve
    b 8f
7:  bl _sea_chol_solve
8:  mov x24, x0
    // Ownership.
    mov x25, #0
    LIVE x9
    add x10, x23, #1
    cmp x9, x10
    cinc x25, x25, ne           // exactly one new object
    ldr x9, [x24, #SEA_OBJ_RC]
    cmp x9, #1
    cinc x25, x25, ne           // the result owned
    ldr x9, [x20, #SEA_OBJ_RC]
    cmp x9, #1
    cinc x25, x25, ne           // A borrowed
    ldr x0, [x20, #SEA_ARR_DATA]
    ldr x1, [x19, #24]
    ldr x2, [x19, #16]
    mul x2, x2, x2
    lsl x2, x2, #3
    bl _memcmp
    cmp w0, #0
    cinc x25, x25, ne           // A's elements unchanged
    cbz x21, 9f
    ldr x9, [x21, #SEA_OBJ_RC]
    cmp x9, #1
    cinc x25, x25, ne           // B borrowed
    ldr x0, [x21, #SEA_ARR_DATA]
    ldr x1, [x19, #56]
    ldr x9, [x21, #SEA_ARR_ROWS]
    ldr x10, [x21, #SEA_ARR_COLS]
    mul x2, x9, x10
    lsl x2, x2, #3
    bl _memcmp
    cmp w0, #0
    cinc x25, x25, ne
9:  cbz x22, 10f
    ldr x9, [x22, #SEA_OBJ_RC]
    cmp x9, #1
    cinc x25, x25, ne           // the handle not retained
    mov x0, x22
    bl Lhbytes
    mov x1, x0
    mov x0, x22
    bl Lsame
    add x25, x25, x0            // and its bytes unchanged
10: ldr x0, [x19]
    bl Lput_cstr
    TXT ":"
    ldr x9, [x19, #8]
    cmp x9, #K_LUS
    b.hs 20f
    // A handle: tag, n, norm, zero pivot, ownership, factor, pivots.
    TXT " tag "
    ldrb w0, [x24, #SEA_OBJ_TAG]
    bl Lput_dec
    TXT " n "
    ldr x0, [x24, #H_N]
    bl Lput_dec
    TXT " anorm "
    ldr x0, [x24, #H_ANORM]
    bl Lput_f
    TXT " zp "
    ldr x0, [x24, #H_ZP]
    bl Lput_dec
    bl Lown
    TXT " F"
    add x0, x24, #H_F
    ldr x1, [x24, #H_N]
    mul x1, x1, x1
    bl Lput_fs
    ldrb w9, [x24, #SEA_OBJ_TAG]
    cmp w9, #SEA_TAG_LU
    b.ne 30f
    TXT " piv"
    ldr x26, [x24, #H_N]
    mul x9, x26, x26
    add x9, x24, x9, lsl #3
    add x19, x9, #H_F           // (x19 is not needed any more)
11: cbz x26, 30f
    TXT " "
    ldr w0, [x19], #4
    bl Lput_dec
    sub x26, x26, #1
    b 11b
20: // A solve: rank, shape, ownership, elements.
    TXT " "
    ldrb w0, [x24, #SEA_ARR_RANK]
    bl Lput_dec
    TXT " "
    ldr x0, [x24, #SEA_ARR_ROWS]
    bl Lput_dec
    TXT "x"
    ldr x0, [x24, #SEA_ARR_COLS]
    bl Lput_dec
    ldrb w9, [x24, #SEA_ARR_TAG]
    cmp w9, #SEA_TAG_ARRAY
    cinc x25, x25, ne
    ldrb w9, [x24, #SEA_ARR_EK]
    cmp w9, #SEA_EK_F64
    cinc x25, x25, ne
    bl Lown
    ldr x0, [x24, #SEA_ARR_DATA]
    ldr x9, [x24, #SEA_ARR_ROWS]
    ldr x10, [x24, #SEA_ARR_COLS]
    mul x1, x9, x10
    bl Lput_fs
30: TXT "\n"
    REL x24
    REL x20
    cbz x21, 31f
    REL x21
31: cbz x22, 32f
    REL x22
32: EPILOGUE

// Lown -- ` own ok` when x25 = 0, else ` own BAD`. Clobbers x0-x17.
    .p2align 2
Lown:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    cbnz x25, 1f
    TXT " own ok"
    b 2f
1:  TXT " own BAD"
2:  ldp x29, x30, [sp], #16
    ret

// _sea_main -- every record. Callee-saved used: x19. Frame 96.
    .globl _sea_main
    .p2align 2
_sea_main:
    PROLOGUE
    LA x19, Lcases
1:  ldr x9, [x19]
    cbz x9, 2f
    mov x0, x19
    bl Lcase
    add x19, x19, #CR_SIZE
    b 1b
2:  EPILOGUE

.equ PZ, 0x0000000000000000
.equ NZ, 0x8000000000000000
.equ QN, 0x7FF8000000000000
.equ HALF, 0x3FE0000000000000
.equ ONE, 0x3FF0000000000000
.equ TWO, 0x4000000000000000
.equ THREE, 0x4008000000000000
.equ FOUR, 0x4010000000000000
.equ FIVE, 0x4014000000000000
.equ SIX, 0x4018000000000000
.equ SEVEN, 0x401C000000000000
.equ EIGHT, 0x4020000000000000
.equ TEN, 0x4024000000000000
.equ TWELVE, 0x4028000000000000
.equ FOURTEEN, 0x402C000000000000
.equ SEVENTEEN, 0x4031000000000000
.equ TWENTYFOUR, 0x4038000000000000
.equ TWENTYNINE, 0x403D000000000000
.equ NINETYNINE, 0x4058C00000000000
.equ M2, 0xC000000000000000
.equ M3, 0xC008000000000000
.equ M8, 0xC020000000000000

    .section __DATA,__const
    .p2align 3
Lcases:
    .quad Lh1, K_LU, 2, La22, 0, 0, 0, 0
    .quad Lh2, K_LU, 2, Lanan, 0, 0, 0, 0
    .quad Lh3, K_LU, 2, Lazp, 0, 0, 0, 0
    .quad Lh4, K_LU, 3, La33, 0, 0, 0, 0
    .quad Lh5, K_LU, 0, La22, 0, 0, 0, 0
    .quad Lh6, K_CHOL, 3, Lcup, 0, 0, 0, 0
    .quad Lh7, K_CHOL, 0, La22, 0, 0, 0, 0
    .quad Ls1, K_LUS, 2, La22, 1, 2, 1, Lb1
    .quad Ls2, K_LUS, 2, La22, 2, 2, 2, Lb2
    .quad Ls3, K_LUS, 3, La33, 1, 3, 1, Lb3
    .quad Ls4, K_CHS, 3, Lcsym, 2, 3, 2, Lb4
    .quad Ls5, K_SOL, 3, Lcsym, 1, 3, 1, Lb4
    .quad Ls6, K_SOL, 3, La33, 1, 3, 1, Lb3
    .quad Ls7, K_SOL, 2, Lasym, 1, 2, 1, Lb7
    .quad Ls8, K_SOL, 2, Laind, 1, 2, 1, Lb8
    .quad Ls9, K_SOL, 2, Lanp, 1, 2, 1, Lb9
    .quad Ls10, K_SOL, 2, Laz, 1, 2, 1, Lb10
    .quad 0
Lh1:  .asciz "lu 2x2 interchange"
Lh2:  .asciz "lu NaN first candidate"
Lh3:  .asciz "lu zero pivot NaN below"
Lh4:  .asciz "lu 3x3"
Lh5:  .asciz "lu 0x0"
Lh6:  .asciz "chol 3x3 upper triangle only"
Lh7:  .asciz "chol 0x0"
Ls1:  .asciz "lu_solve 2x2 vector"
Ls2:  .asciz "lu_solve 2x2 matrix"
Ls3:  .asciz "lu_solve 3x3"
Ls4:  .asciz "chol_solve 3x3 matrix"
Ls5:  .asciz "solve symmetric (Cholesky)"
Ls6:  .asciz "solve 3x3 (LU)"
Ls7:  .asciz "solve upper positive definite, not symmetric (LU)"
Ls8:  .asciz "solve symmetric indefinite (LU fallback)"
Ls9:  .asciz "solve symmetric NaN pair"
Ls10: .asciz "solve +0/-0 pair"
    .p2align 3
// Matrices, column-major.
La22:  .quad TWO, FOUR, ONE, THREE              // [2 1; 4 3]
Lanan: .quad QN, FIVE, ONE, ONE                 // [NaN 1; 5 1]
Lazp:  .quad PZ, QN, ONE, ONE                   // [0 1; NaN 1]
La33:  .quad ONE, TWO, FOUR, TWO, FOUR, ONE, THREE, ONE, TWO  // [1 2 3; 2 4 1; 4 1 2]
Lcup:  .quad FOUR, QN, NINETYNINE, TWO, SEVENTEEN, QN, 0xC000000000000000, SEVEN, SIX
Lcsym: .quad FOUR, TWO, 0xC000000000000000, TWO, SEVENTEEN, SEVEN, 0xC000000000000000, SEVEN, SIX
Lasym: .quad TWO, FOUR, ONE, FOUR               // [2 1; 4 4]
Laind: .quad ONE, TWO, TWO, ONE                 // [1 2; 2 1]
Lanp:  .quad FOUR, QN, QN, FOUR                 // [4 NaN; NaN 4]
Laz:   .quad FOUR, NZ, PZ, ONE                  // [4 +0; -0 1]
// Right-hand sides.
Lb1:   .quad TEN, TWENTYFOUR
Lb2:   .quad TEN, TWENTYFOUR, ONE, TWO
Lb3:   .quad SIX, M3, EIGHT
Lb4:   .quad TEN, TWENTYNINE, SIX, M8, TWELVE, FOURTEEN
Lb7:   .quad THREE, EIGHT
Lb8:   .quad THREE, THREE
Lb9:   .quad ONE, ONE
Lb10:  .quad EIGHT, THREE
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
