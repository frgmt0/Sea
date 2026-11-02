// sea/tests/rt/arm64_macos/rt_la_private_potrf.s -- the private routine sea_la_potrf (DESIGN.md 2.13.6 "CHOL", "Private routines", L-jc): on A = R'R for an exact upper triangular R (Lgen_r: integer entries, diagonal 1, 2, 4), held with a column stride ld >= n whose strict lower triangle holds NaN and whose rows n .. ld-1 hold a sentinel, the status is 0, the upper triangle equals R (as values: exact data fixes values, not the sign of an exact zero a kernel update may leave, L-jl), the strict lower triangle +0 and the sentinel rows untouched, at orders 0, 1, 3, 32 (one panel), 33 and 70 (blocked, _bsk_kern_gemm_sub updates); a pivot made exactly 0 at index f, or NaN, gives the status 1 + f (orders 3 and 70, in the first, a middle and the last panel)
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
.equ LDMAX, 73
.equ SENT, 0x5EA5C0DE5EA5C0DE       /* rows n .. ld-1: must stay */
.equ QNAN, 0x7FF8000000000BAD       /* the strict lower input: never read */
.zerofill __DATA,__bss,Lbuf_a,(8*LDMAX*NMAX),4
.zerofill __DATA,__bss,Lbuf_r,(8*NMAX*NMAX),4
.zerofill __DATA,__bss,Lbuf_t,(8*NMAX*NMAX),4
.zerofill __DATA,__bss,Lbuf_w,(8*NMAX*SEA_LA_NB),4

// Lpcase -- one case of sea_la_potrf on A = R'R (R of Lgen_r), held with
// column stride ld: rows i <= j hold A, rows j < i < n a NaN (only the
// upper triangle may be read), rows n .. ld-1 the sentinel.
//   Inputs  : x0 = label, x1 = n, x2 = ld, x3 = mode (0: A as it is;
//             1: A[f,f] -= R[f,f]^2, so the pivot d at f is exactly 0;
//             2: A[f,f] = NaN), x4 = f
//   Prints  : `<label>: status <s>` then ` ok` when (mode 0) the upper
//             triangle equals R (==), the strict lower triangle is
//             +0 and the sentinel rows are untouched (modes 1, 2: the
//             sentinel only), else ` BAD <number of wrong words>`
//   Callee-saved used: x19 = label, x20 = n, x21 = ld, x22 = mode,
//             x23 = f, x24 = status, x25 = faults, x26 = j, x27 = i
//   Frame   : 96 bytes
    .p2align 2
Lpcase:
    PROLOGUE
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, x4
    LA x0, Lbuf_r               // R, stride n
    mov x1, x20
    mov x2, x20
    bl Lgen_r
    LA x0, Lbuf_t               // A = R'R, stride n
    LA x1, Lbuf_r
    LA x2, Lbuf_r
    mov x3, x20
    mov x4, x20
    mov x5, x20
    mov x6, #1
    bl Lmul
    // The input, column stride ld.
    LA x9, Lbuf_a
    LA x10, Lbuf_t
    LI x11, QNAN
    LI x12, SENT
    mov x26, #0                 // j
1:  cmp x26, x20
    b.hs 5f
    mov x27, #0                 // i
2:  cmp x27, x21
    b.hs 4f
    mov x13, x12                // the sentinel row
    cmp x27, x20
    b.hs 3f
    mov x13, x11                // below the diagonal: NaN
    cmp x27, x26
    b.hi 3f
    madd x14, x26, x20, x27
    ldr x13, [x10, x14, lsl #3] // A[i,j]
3:  madd x14, x26, x21, x27
    str x13, [x9, x14, lsl #3]
    add x27, x27, #1
    b 2b
4:  add x26, x26, #1
    b 1b
5:  cbz x22, 7f
    madd x14, x23, x21, x23     // &A[f,f] in the input
    LA x9, Lbuf_a
    add x9, x9, x14, lsl #3
    cmp x22, #2
    b.eq 6f
    madd x14, x23, x20, x23
    LA x10, Lbuf_r
    ldr d1, [x10, x14, lsl #3]  // R[f,f]
    fmul d1, d1, d1
    ldr d0, [x9]
    fsub d0, d0, d1
    str d0, [x9]
    b 7f
6:  LI x10, QNAN
    str x10, [x9]
7:  LA x0, Lbuf_a
    mov x1, x20
    mov x2, x21
    LA x3, Lbuf_w
    bl _sea_la_potrf
    mov x24, x0
    // The check.
    mov x25, #0
    LA x9, Lbuf_a
    LA x10, Lbuf_r
    LI x12, SENT
    mov x26, #0
8:  cmp x26, x20
    b.hs 12f
    mov x27, #0
9:  cmp x27, x21
    b.hs 11f
    madd x14, x26, x21, x27
    ldr x13, [x9, x14, lsl #3]  // the output word
    cmp x27, x20
    b.lo 10f
    cmp x13, x12                // a sentinel row
    cinc x25, x25, ne
    b 13f
10: cbnz x22, 13f               // a failing case: R is not checked
    cmp x27, x26
    b.ls 15f
    cmp x13, #0                 // below the diagonal: +0 bit for bit
    cinc x25, x25, ne
    b 13f
15: madd x14, x26, x20, x27     // R[i,j] as a value (exact data fixes
    ldr d1, [x10, x14, lsl #3]  // values, not the sign of an exact zero
    fmov d0, x13                // a kernel update may leave, L-jl)
    fcmp d0, d1
    cset x15, ne
    add x25, x25, x15
13: add x27, x27, #1
    b 9b
11: add x26, x26, #1
    b 8b
12: mov x0, x19
    bl Lput_cstr
    TXT ": status "
    mov x0, x24
    bl Lput_dec
    cbnz x25, 14f
    TXT " ok\n"
    EPILOGUE
14: TXT " BAD "
    mov x0, x25
    bl Lput_dec
    TXT "\n"
    EPILOGUE

// A case record: label, n, ld, mode, f.
.equ PR_SIZE, 40

// _sea_main -- every case of Lpcases. Callee-saved used: x19. Frame 96.
    .globl _sea_main
    .p2align 2
_sea_main:
    PROLOGUE
    LA x19, Lpcases
1:  ldr x0, [x19]
    cbz x0, 2f
    ldp x1, x2, [x19, #8]
    ldp x3, x4, [x19, #24]
    bl Lpcase
    add x19, x19, #PR_SIZE
    b 1b
2:  EPILOGUE

    .section __DATA,__const
    .p2align 3
Lpcases:
    .quad Lp0, 0, 1, 0, 0
    .quad Lp1, 1, 1, 0, 0
    .quad Lp2, 3, 5, 0, 0
    .quad Lp3, 32, 32, 0, 0
    .quad Lp4, 33, 35, 0, 0
    .quad Lp5, 70, 73, 0, 0
    .quad Lp6, 3, 4, 1, 2
    .quad Lp7, 70, 73, 1, 40
    .quad Lp8, 70, 70, 2, 0
    .quad Lp9, 70, 71, 1, 69
    .quad Lp10, 64, 64, 2, 33
    .quad 0
Lp0:  .asciz "n 0"
Lp1:  .asciz "n 1"
Lp2:  .asciz "n 3 ld 5"
Lp3:  .asciz "n 32 ld 32"
Lp4:  .asciz "n 33 ld 35"
Lp5:  .asciz "n 70 ld 73"
Lp6:  .asciz "n 3 zero pivot at 2"
Lp7:  .asciz "n 70 zero pivot at 40"
Lp8:  .asciz "n 70 NaN pivot at 0"
Lp9:  .asciz "n 70 zero pivot at 69"
Lp10: .asciz "n 64 NaN pivot at 33"

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
