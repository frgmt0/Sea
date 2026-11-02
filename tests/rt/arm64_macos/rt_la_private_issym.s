// sea/tests/rt/arm64_macos/rt_la_private_issym.s -- the private routine sea_la_issym (DESIGN.md 2.13.6 "Private routines", Decision 123, L-jc): 1 when every pair a[i,j], a[j,i] is equal (==, so +0 equals -0) or both NaN, else 0; the diagonal and the rows n .. ld-1 of each column are never compared. Cases: orders 0 and 1 (no pair, even a NaN diagonal), a 3x3 with ld 4 holding a +0/-0 pair, a NaN pair and garbage padding (1), each pair broken once (NaN vs 1 in both orientations, 2 vs 3: 0), and A = R'R of order 70 (1), then with one element of its last column changed (0). It is a leaf: x19-x28 and d8-d15 are not looked at here, rt_la_lu_abi checks them
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

// ---- exact test data (the same block in rt_la_lu_blocked, rt_la_lu_abi,
// rt_la_private_potrf and rt_la_free_handles) ----------------------------
// Every value below is a small integer or a dyadic with denominator 4, so
// every product and partial sum of the factorizations and solves is
// exact and every order (Baysick's blocking and FMA included) gives the
// same bits (DESIGN.md 2.13.8 "exact data").

// Lmod -- x0 mod x1 (x0 >= 0). Clobbers x9. Leaf.
    .p2align 2
Lmod:
    udiv x9, x0, x1
    msub x0, x9, x1, x0
    ret

// Lgen_r -- R, upper triangular, at x0 with column stride x2, order x1:
// R[j,j] = 1, 2, 4 for j mod 3 = 0, 1, 2; R[i,j] = ((5i + 11j) mod 7) - 3
// for i < j; R[i,j] = +0 for i > j (rows n .. ld-1 untouched).
// Clobbers x0-x15, d0. Frame 16 bytes (calls Lmod).
    .p2align 2
Lgen_r:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x11, x0                 // the matrix
    mov x12, x1                 // n
    lsl x13, x2, #3             // the column stride in bytes
    mov x14, #0                 // j
1:  cmp x14, x12
    b.hs 5f
    mov x15, #0                 // i
2:  cmp x15, x12
    b.hs 4f
    cmp x15, x14
    b.hi 3f                     // below: +0
    b.lo 6f
    mov x0, x14                 // the diagonal
    mov x1, #3
    bl Lmod
    mov x10, #1
    lsl x10, x10, x0            // 1, 2, 4
    scvtf d0, x10
    b 7f
6:  mov x10, #5
    mul x0, x15, x10
    mov x10, #11
    madd x0, x14, x10, x0
    mov x1, #7
    bl Lmod
    sub x0, x0, #3
    scvtf d0, x0
    b 7f
3:  fmov d0, xzr
7:  madd x10, x14, x13, x11
    str d0, [x10, x15, lsl #3]
    add x15, x15, #1
    b 2b
4:  add x14, x14, #1
    b 1b
5:  ldp x29, x30, [sp], #16
    ret

// Lgen_l -- L, unit lower triangular, n x n at x0 (stride n), order x1:
// L[i,k] for i > k = 0, 1/2, -1/2, 1/4, -1/4 for (7i + 3k) mod 5 = 0 .. 4
// (every |L[i,k]| < 1, so partial pivoting picks the unit row each step);
// L[k,k] = 1; +0 above.
// Clobbers x0-x15, d0. Frame 16 bytes.
    .p2align 2
Lgen_l:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x11, x0
    mov x12, x1
    lsl x13, x1, #3
    mov x14, #0                 // k
1:  cmp x14, x12
    b.hs 5f
    mov x15, #0                 // i
2:  cmp x15, x12
    b.hs 4f
    fmov d0, xzr
    cmp x15, x14
    b.lo 3f                     // above: +0
    fmov d0, #1.0
    b.eq 3f                     // the unit diagonal
    mov x10, #7
    mul x0, x15, x10
    mov x10, #3
    madd x0, x14, x10, x0
    mov x1, #5
    bl Lmod
    LA x10, Lgen_ltab
    ldr d0, [x10, x0, lsl #3]
3:  madd x10, x14, x13, x11
    str d0, [x10, x15, lsl #3]
    add x15, x15, #1
    b 2b
4:  add x14, x14, #1
    b 1b
5:  ldp x29, x30, [sp], #16
    ret

// Lgen_u -- U, upper triangular, n x n at x0 (stride n), order x1:
// U[k,k] = 1, 2, 4, -2 for k mod 4 = 0 .. 3; U[k,j] = ((5k + 11j) mod 7)
// - 3 for k < j; +0 below.
// Clobbers x0-x15, d0. Frame 16 bytes.
    .p2align 2
Lgen_u:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x11, x0
    mov x12, x1
    lsl x13, x1, #3
    mov x14, #0                 // j
1:  cmp x14, x12
    b.hs 5f
    mov x15, #0                 // k
2:  cmp x15, x12
    b.hs 4f
    fmov d0, xzr
    cmp x15, x14
    b.hi 3f                     // below: +0
    b.lo 6f
    and x0, x14, #3             // the diagonal
    LA x10, Lgen_utab
    ldr d0, [x10, x0, lsl #3]
    b 3f
6:  mov x10, #5
    mul x0, x15, x10
    mov x10, #11
    madd x0, x14, x10, x0
    mov x1, #7
    bl Lmod
    sub x0, x0, #3
    scvtf d0, x0
3:  madd x10, x14, x13, x11
    str d0, [x10, x15, lsl #3]
    add x15, x15, #1
    b 2b
4:  add x14, x14, #1
    b 1b
5:  ldp x29, x30, [sp], #16
    ret

// Lgen_x -- X, n x m at x0 (stride n): X[i,c] = ((3i + 5c) mod 7) - 3.
// Inputs x0, x1 = n, x2 = m. Clobbers x0-x15, d0. Frame 16 bytes.
    .p2align 2
Lgen_x:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x11, x0
    mov x12, x1
    mov x13, x2
    mov x14, #0                 // c
1:  cmp x14, x13
    b.hs 5f
    mov x15, #0                 // i
2:  cmp x15, x12
    b.hs 4f
    mov x10, #3
    mul x0, x15, x10
    mov x10, #5
    madd x0, x14, x10, x0
    mov x1, #7
    bl Lmod
    sub x0, x0, #3
    scvtf d0, x0
    str d0, [x11], #8
    add x15, x15, #1
    b 2b
4:  add x14, x14, #1
    b 1b
5:  ldp x29, x30, [sp], #16
    ret

// Lmul -- C = op(A) B, column-major, every stride the stored row count:
//   x0 = C (r x c), x1 = A (r x k, or k x r when x6 = 1: op(A) = A'),
//   x2 = B (k x c), x3 = r, x4 = k, x5 = c, x6 = transpose flag.
// Exact data only (any order gives the same bits). Clobbers x7-x17,
// d0-d2. Leaf.
    .p2align 2
Lmul:
    mov x7, #0                  // j
1:  cmp x7, x5
    b.hs 6f
    mov x8, #0                  // i
2:  cmp x8, x3
    b.hs 5f
    fmov d0, xzr
    mov x9, #0                  // t
3:  cmp x9, x4
    b.hs 4f
    cbz x6, 7f
    madd x10, x8, x4, x9        // A'[i,t] = A[t + i*k]
    b 8f
7:  madd x10, x9, x3, x8        // A[i + t*r]
8:  ldr d1, [x1, x10, lsl #3]
    madd x10, x7, x4, x9        // B[t + j*k]
    ldr d2, [x2, x10, lsl #3]
    fmul d1, d1, d2
    fadd d0, d0, d1
    add x9, x9, #1
    b 3b
4:  madd x10, x7, x3, x8
    str d0, [x0, x10, lsl #3]
    add x8, x8, #1
    b 2b
5:  add x7, x7, #1
    b 1b
6:  ret

// Lperm -- dst[i, :] = src[p(i), :] with p(i) = (17 i + 5) mod n (a
// permutation for the orders used: 17 is prime to them), n x m, stride n.
// x0 = dst, x1 = src, x2 = n, x3 = m. Clobbers x9-x15, d0. Leaf.
    .p2align 2
Lperm:
    mov x9, #0                  // i
1:  cmp x9, x2
    b.hs 4f
    mov x10, #17
    mul x10, x9, x10
    add x10, x10, #5
    udiv x11, x10, x2
    msub x10, x11, x2, x10      // p(i)
    mov x12, #0                 // c
2:  cmp x12, x3
    b.hs 3f
    madd x13, x12, x2, x10
    ldr d0, [x1, x13, lsl #3]
    madd x13, x12, x2, x9
    str d0, [x0, x13, lsl #3]
    add x12, x12, #1
    b 2b
3:  add x9, x9, #1
    b 1b
4:  ret

    .section __DATA,__const
    .p2align 3
Lgen_ltab:
    .quad 0x0000000000000000, 0x3FE0000000000000, 0xBFE0000000000000
    .quad 0x3FD0000000000000, 0xBFD0000000000000
Lgen_utab:
    .quad 0x3FF0000000000000, 0x4000000000000000, 0x4010000000000000
    .quad 0xC000000000000000
    .section __TEXT,__text,regular,pure_instructions
// ---- end of the exact test data ----------------------------------------

// ---- the test ---------------------------------------------------------
.zerofill __DATA,__bss,Lbuf_r,(8*70*70),4
.zerofill __DATA,__bss,Lbuf_a,(8*70*70),4

// Lone -- print `<label>: <result>` for sea_la_issym(a, n, ld).
//   Inputs  : x0 = label, x1 = a, x2 = n, x3 = ld
//   Callee-saved used: x19-x22. Frame 96 bytes.
    .p2align 2
Lone:
    PROLOGUE
    mov x19, x0
    mov x0, x1
    mov x1, x2
    mov x2, x3
    bl _sea_la_issym
    mov x20, x0
    mov x0, x19
    bl Lput_cstr
    TXT ": "
    mov x0, x20
    bl Lput_dec
    TXT "\n"
    EPILOGUE

// _sea_main -- the static cases, then the order-70 ones. Frame 96.
    .globl _sea_main
    .p2align 2
_sea_main:
    PROLOGUE
    LA x19, Lcases
1:  ldr x0, [x19]
    cbz x0, 2f
    ldp x1, x2, [x19, #8]
    ldr x3, [x19, #24]
    bl Lone
    add x19, x19, #32
    b 1b
2:  LA x0, Lbuf_r               // R of order 70, then A = R'R
    mov x1, #70
    mov x2, #70
    bl Lgen_r
    LA x0, Lbuf_a
    LA x1, Lbuf_r
    LA x2, Lbuf_r
    mov x3, #70
    mov x4, #70
    mov x5, #70
    mov x6, #1
    bl Lmul
    TXT "order 70 R'R"
    LA x1, Lbuf_a
    adr x0, Lempty
    mov x2, #70
    mov x3, #70
    bl Lone
    LA x9, Lbuf_a               // A[68,69] (pairs with A[69,68]) + 1
    mov x10, #(68 + 69 * 70)
    ldr d0, [x9, x10, lsl #3]
    fmov d1, #1.0
    fadd d0, d0, d1
    str d0, [x9, x10, lsl #3]
    TXT "order 70 A[68,69] changed"
    adr x0, Lempty
    LA x1, Lbuf_a
    mov x2, #70
    mov x3, #70
    bl Lone
    EPILOGUE
Lempty: .asciz ""
    .p2align 2

.equ G1, 0x4045000000000000
.equ G2, 0x7FF0000000000001
.equ PZ, 0x0000000000000000
.equ NZ, 0x8000000000000000
.equ QN, 0x7FF8000000000000
.equ ONE, 0x3FF0000000000000
.equ TWO, 0x4000000000000000
.equ THREE, 0x4008000000000000
.equ FIVE, 0x4014000000000000
.equ SEVEN, 0x401C000000000000
.equ NINE, 0x4022000000000000

    .section __DATA,__const
    .p2align 3
// Case records: label, a, n, ld.
Lcases:
    .quad Lc0, Ls1, 0, 4
    .quad Lc1, Lnan1, 1, 1
    .quad Lc2, Ls1, 3, 4
    .quad Lc3, Ls2, 3, 4
    .quad Lc4, Ls3, 3, 4
    .quad Lc5, Ls4, 3, 4
    .quad 0
Lc0: .asciz "order 0"
Lc1: .asciz "order 1 NaN"
Lc2: .asciz "3x3 +0/-0 and NaN pairs"
Lc3: .asciz "3x3 a[0,2] NaN a[2,0] 1"
Lc4: .asciz "3x3 a[0,2] 1 a[2,0] NaN"
Lc5: .asciz "3x3 a[1,2] 2 a[2,1] 3"
    .p2align 3
Lnan1: .quad QN
// Column-major, ld 4: rows 0-2 and a padding row.
Ls1: .quad FIVE, PZ, QN, G1,   NZ, SEVEN, TWO, G2,   QN, TWO, NINE, G1
Ls2: .quad FIVE, PZ, ONE, G1,  NZ, SEVEN, TWO, G2,   QN, TWO, NINE, G1
Ls3: .quad FIVE, PZ, QN, G1,   NZ, SEVEN, TWO, G2,   ONE, TWO, NINE, G1
Ls4: .quad FIVE, PZ, QN, G1,   NZ, SEVEN, THREE, G2, QN, TWO, NINE, G1
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
