// sea/tests/rt/arm64_macos/rt_la_lu_blocked.s -- the blocked paths (n > SEA_LA_NB: panels, block rows, trailing updates through _bsk_kern_gemm_sub) of sea_lu, sea_lu_solve, sea_chol, sea_chol_solve and sea_solve (DESIGN.md 2.13.6), on exact data (DESIGN.md 2.13.8): A = P'(L U) with L unit lower (|L[i,k]| <= 1/2, dyadic), U upper (integers, diagonal 1, 2, 4, -2) and a row permutation P, so partial pivoting reproduces L, U and P exactly; and A = R'R with R upper (integers, diagonal 1, 2, 4), so Cholesky reproduces R exactly; X integer and B = A X. Orders 33, 64, 70, right-hand sides a vector, 3 and 40 columns. Checked: the Lu factor against L and U as values (==: exact data fixes values, not the sign of an exact zero, L-jl), its interchanges bit for bit (applied to A they give L U), its first zero pivot (-1) and ||A||_1; the Chol factor against R as values with its strict lower triangle +0 bit for bit; every solution against X as values, for both handle solves and for sea_solve (its LU path and its Cholesky path); the live count rises by one per call and each result has count 1. Each case prints `<label>: ok`, or `BAD` and the sum of 1 factor, 2 interchanges, 4 handle solve, 8 solve, 16 ownership, 32 fields
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
.equ NMAX, 70
.zerofill __DATA,__bss,Lb_l,(8*NMAX*NMAX),4     // L (or R)
.zerofill __DATA,__bss,Lb_u,(8*NMAX*NMAX),4     // U
.zerofill __DATA,__bss,Lb_p,(8*NMAX*NMAX),4     // L U (or R'R)
.zerofill __DATA,__bss,Lb_a,(8*NMAX*NMAX),4     // A
.zerofill __DATA,__bss,Lb_x,(8*NMAX*NMAX),4     // X
.zerofill __DATA,__bss,Lb_b,(8*NMAX*NMAX),4     // B
.zerofill __DATA,__bss,Lb_t,(8*NMAX*NMAX),4     // scratch

// Lcmpd -- x0 = 0 when the x2 doubles at x0 and x1 have the same bits
// (pure moves: the interchanges).
    .p2align 2
Lcmpd:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    lsl x2, x2, #3
    bl _memcmp
    cmp w0, #0
    cset x0, ne
    ldp x29, x30, [sp], #16
    ret

// Lcmpv -- x0 = 0 when the x2 doubles at x0 and x1 are equal as values
// (==): exact data fixes every value but not the sign of an exact zero
// (a zero quotient by a negative pivot is -0; Baysick's kernels leave the
// sign of an exact zero sum open, L-jl). Clobbers x9, d0, d1.
    .p2align 2
Lcmpv:
    mov x9, #0
1:  cmp x9, x2
    b.hs 2f
    ldr d0, [x0, x9, lsl #3]
    ldr d1, [x1, x9, lsl #3]
    add x9, x9, #1
    fcmp d0, d1
    b.eq 1b
    mov x0, #1
    ret
2:  mov x0, #0
    ret

// Lnorm1 -- the largest column sum of magnitudes of the n x n matrix at
// x0 (exact data: any order). x1 = n -> d0. Clobbers x9-x11, d0-d2.
    .p2align 2
Lnorm1:
    fmov d0, xzr
    mov x9, #0
1:  cmp x9, x1
    b.hs 4f
    fmov d1, xzr
    mov x10, #0
2:  cmp x10, x1
    b.hs 3f
    madd x11, x9, x1, x10
    ldr d2, [x0, x11, lsl #3]
    fabs d2, d2
    fadd d1, d1, d2
    add x10, x10, #1
    b 2b
3:  fmax d0, d0, d1
    add x9, x9, #1
    b 1b
4:  ret

// Lcall_new -- the live count before, the call done by the caller; this
// pair of macros checks that the count rose by one and the result (x0)
// has count 1; x25 collects 16.
.macro OWNCHK res
    LIVE x9
    add x10, x23, #1
    ldr x11, [\res, #SEA_OBJ_RC]
    cmp x9, x10
    ccmp x11, #1, #0, eq
    b.eq Lown\@
    orr x25, x25, #16
Lown\@:
.endm

// Lxb -- X (n x m, Lgen_x) and B = A X into Lb_x, Lb_b; x0 = n, x1 = m.
    .p2align 2
Lxb:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    mov x20, x1
    LA x0, Lb_x
    mov x1, x19
    mov x2, x20
    bl Lgen_x
    LA x0, Lb_b
    LA x1, Lb_a
    LA x2, Lb_x
    mov x3, x19
    mov x4, x19
    mov x5, x20
    mov x6, #0
    bl Lmul
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Lsolves -- the solve checks shared by both kinds: B as an array of
// rank x2 (n x m), X1 = handle solve (x3 = the entry, x4 = the handle),
// X2 = sea_solve(A array x5, B); x0 = n, x1 = m. Adds 4, 8, 16 to x25.
// Callee-saved used: x19 = n, x20 = m, x21 = B, x22 = handle, x23 = live,
// x24 = result, x26 = entry, x27 = A, x28 = rank. Frame 96.
    .p2align 2
Lsolves:
    PROLOGUE
    mov x19, x0
    mov x20, x1
    mov x28, x2
    mov x26, x3
    mov x22, x4
    mov x27, x5
    mov x0, x28                 // B
    mov x1, x19
    mov x2, x20
    LA x3, Lb_b
    bl Lmk
    mov x21, x0
    LIVE x23
    mov x0, x22
    mov x1, x21
    mov x2, #0
    blr x26                     // the handle solve
    mov x24, x0
    OWNCHK x24
    ldr x0, [x24, #SEA_ARR_DATA]
    LA x1, Lb_x
    mul x2, x19, x20
    bl Lcmpv
    cbz x0, 1f
    orr x25, x25, #4
1:  REL x24
    LIVE x23
    mov x0, x27
    mov x1, x21
    mov x2, #0
    bl _sea_solve
    mov x24, x0
    OWNCHK x24
    ldr x0, [x24, #SEA_ARR_DATA]
    LA x1, Lb_x
    mul x2, x19, x20
    bl Lcmpv
    cbz x0, 2f
    orr x25, x25, #8
2:  REL x24
    REL x21
    EPILOGUE

// Lucase -- an LU case: x0 = label, x1 = n, x2 = m, x3 = B's rank.
// Callee-saved used: x19 = label, x20 = n, x21 = m, x22 = rank, x23 =
// live, x24 = A, x25 = faults, x26 = F. Frame 96.
    .p2align 2
Lucase:
    PROLOGUE
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x25, #0
    LA x0, Lb_l
    mov x1, x20
    bl Lgen_l
    LA x0, Lb_u
    mov x1, x20
    bl Lgen_u
    LA x0, Lb_p                 // L U
    LA x1, Lb_l
    LA x2, Lb_u
    mov x3, x20
    mov x4, x20
    mov x5, x20
    mov x6, #0
    bl Lmul
    LA x0, Lb_a                 // A = rows of L U permuted
    LA x1, Lb_p
    mov x2, x20
    mov x3, x20
    bl Lperm
    mov x0, x20
    mov x1, x21
    bl Lxb
    mov x0, #2
    mov x1, x20
    mov x2, x20
    LA x3, Lb_a
    bl Lmk
    mov x24, x0
    LIVE x23
    mov x0, x24
    mov x1, #0
    bl _sea_lu
    mov x26, x0
    OWNCHK x26
    // The factor: L below the diagonal, U on and above it.
    LA x9, Lb_t
    LA x10, Lb_l
    LA x11, Lb_u
    mul x12, x20, x20
    mov x13, #0                 // element index
    mov x14, #0                 // j
    mov x15, #0                 // i
3:  cmp x13, x12
    b.hs 5f
    cmp x15, x14
    csel x16, x10, x11, hi      // below: L
    ldr x17, [x16, x13, lsl #3]
    str x17, [x9, x13, lsl #3]
    add x13, x13, #1
    add x15, x15, #1
    cmp x15, x20
    b.lo 3b
    mov x15, #0
    add x14, x14, #1
    b 3b
5:  add x0, x26, #H_F
    LA x1, Lb_t
    mul x2, x20, x20
    bl Lcmpv
    cbz x0, 6f
    orr x25, x25, #1
    // The interchanges applied to A in order give L U.
6:  LA x0, Lb_t
    LA x1, Lb_a
    mul x2, x20, x20
    lsl x2, x2, #3
    bl _memcpy
    mul x9, x20, x20
    add x9, x26, x9, lsl #3
    add x9, x9, #H_F            // the pivots
    LA x10, Lb_t
    mov x11, #0                 // k
7:  cmp x11, x20
    b.hs 9f
    ldr w12, [x9, x11, lsl #2]
    mov x13, #0                 // c
8:  cmp x13, x20
    b.hs 81f
    madd x14, x13, x20, x11
    madd x15, x13, x20, x12
    ldr x16, [x10, x14, lsl #3]
    ldr x17, [x10, x15, lsl #3]
    str x17, [x10, x14, lsl #3]
    str x16, [x10, x15, lsl #3]
    add x13, x13, #1
    b 8b
81: add x11, x11, #1
    b 7b
9:  LA x0, Lb_t
    LA x1, Lb_p
    mul x2, x20, x20
    bl Lcmpd
    cbz x0, 10f
    orr x25, x25, #2
10: ldr x9, [x26, #H_ZP]        // fields: no zero pivot, ||A||_1
    cmn x9, #1
    b.eq 11f
    orr x25, x25, #32
11: LA x0, Lb_a
    mov x1, x20
    bl Lnorm1
    ldr d1, [x26, #H_ANORM]
    fcmp d0, d1
    b.eq 12f
    orr x25, x25, #32
12: mov x0, x20
    mov x1, x21
    mov x2, x22
    LA x3, _sea_lu_solve
    mov x4, x26
    mov x5, x24
    bl Lsolves
    REL x26
    REL x24
    b Lreport

// Lchcase -- a Cholesky case: as Lucase.
    .p2align 2
Lchcase:
    PROLOGUE
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x25, #0
    LA x0, Lb_l                 // R
    mov x1, x20
    mov x2, x20
    bl Lgen_r
    LA x0, Lb_a                 // A = R'R
    LA x1, Lb_l
    LA x2, Lb_l
    mov x3, x20
    mov x4, x20
    mov x5, x20
    mov x6, #1
    bl Lmul
    mov x0, x20
    mov x1, x21
    bl Lxb
    mov x0, #2
    mov x1, x20
    mov x2, x20
    LA x3, Lb_a
    bl Lmk
    mov x24, x0
    LIVE x23
    mov x0, x24
    mov x1, #0
    bl _sea_chol
    mov x26, x0
    OWNCHK x26
    add x0, x26, #H_F
    LA x1, Lb_l
    mul x2, x20, x20
    bl Lcmpv
    cbz x0, 3f
    orr x25, x25, #1
3:  add x9, x26, #H_F           // the strict lower triangle: +0 bits
    mov x10, #0                 // j
4:  cmp x10, x20
    b.hs 1f
    add x11, x10, #1            // i
5:  cmp x11, x20
    b.hs 6f
    madd x12, x10, x20, x11
    ldr x13, [x9, x12, lsl #3]
    cbz x13, 7f
    orr x25, x25, #1
7:  add x11, x11, #1
    b 5b
6:  add x10, x10, #1
    b 4b
1:  ldr x9, [x26, #H_ZP]
    ldr x10, [x26, #H_ANORM]
    cmn x9, #1
    ccmp x10, #0, #0, eq
    b.eq 2f
    orr x25, x25, #32
2:  mov x0, x20
    mov x1, x21
    mov x2, x22
    LA x3, _sea_chol_solve
    mov x4, x26
    mov x5, x24
    bl Lsolves
    REL x26
    REL x24
    // (falls into Lreport with Lchcase's frame, the same as Lucase's)
Lreport:
    mov x0, x19
    bl Lput_cstr
    cbnz x25, 1f
    TXT ": ok\n"
    EPILOGUE
1:  TXT ": BAD "
    mov x0, x25
    bl Lput_dec
    TXT "\n"
    EPILOGUE

// _sea_main -- every record: label, kind (0 LU, 1 Cholesky), n, m, rank.
    .globl _sea_main
    .p2align 2
_sea_main:
    PROLOGUE
    LA x19, Lcases
1:  ldr x0, [x19]
    cbz x0, 3f
    ldp x9, x1, [x19, #8]
    ldp x2, x3, [x19, #24]
    cbnz x9, 2f
    bl Lucase
    add x19, x19, #40
    b 1b
2:  bl Lchcase
    add x19, x19, #40
    b 1b
3:  EPILOGUE

    .section __DATA,__const
    .p2align 3
Lcases:
    .quad Lc0, 0, 33, 1, 1
    .quad Lc1, 0, 64, 3, 2
    .quad Lc2, 0, 70, 40, 2
    .quad Lc3, 0, 70, 1, 1
    .quad Lc4, 1, 33, 3, 2
    .quad Lc5, 1, 64, 1, 1
    .quad Lc6, 1, 70, 40, 2
    .quad Lc7, 1, 70, 1, 1
    .quad 0
Lc0: .asciz "lu 33, vector"
Lc1: .asciz "lu 64, 3 columns"
Lc2: .asciz "lu 70, 40 columns"
Lc3: .asciz "lu 70, vector"
Lc4: .asciz "chol 33, 3 columns"
Lc5: .asciz "chol 64, vector"
Lc6: .asciz "chol 70, 40 columns"
Lc7: .asciz "chol 70, vector"
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
