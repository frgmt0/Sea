// =====================================================================
// sea/runtime/arm64_macos/rt_eig.s -- the eigenvalues of a symmetric
// matrix and of a symmetric-definite pencil (DESIGN.md 2.13.5 entries
// EIG_SYM, EIG_SYM_GEN; 2.13.6 "EIG_SYM", "EIG_SYM_GEN", "Private
// routines"; Decisions 121 (a), 123; L-ip, L-iy; LANGUAGE.md 10.8).
//
// Defines (global, rt.inc SEA_ENTRY_LIST):
//   _sea_eig_sym     (A, site) -> a new f64 vector of the n eigenvalues
//                    of the symmetric A, ascending
//   _sea_eig_sym_gen (K, M, site) -> a new f64 vector of the n
//                    eigenvalues of K x = lambda M x, ascending
// Uses: _sea_la_issym, _sea_la_potrf (rt_lu.s, private, L-jc),
//       _sea_hypot (rt_math.s; pythag), _sea_alloc, _sea_free_block
//       (rt_mem.s), _sea_arr_new_u (rt_arr.s), _sea_err (rt_err.s),
//       memcpy (libSystem).
//
// Notation (DESIGN.md 2.13.6): matrices are column-major, A[i,j] at
// DATA + 8 * (i + j * n). Every operation below is one IEEE operation
// in the stated order (fmul then fadd/fsub, never FMA; true divisions;
// fsqrt correctly rounded), the same as the x86_64 runtime (L-it). No
// Baysick kernel is reached except through _sea_la_potrf (CHOL's
// blocked algorithm, n > SEA_LA_NB only), so EIG_SYM's result is the
// same under every variant and EIG_SYM_GEN's for n <= SEA_LA_NB.
//
// The algorithm (Decision 121 (a)): EISPACK tred1 (Householder reduction
// of the lower triangle to a tridiagonal (d, e), with its row scaling by
// the sum of magnitudes) then tql1 (implicit QL with shifts, the
// machine-independent convergence test, its own ordering of the found
// values), transcribed statement by statement with 0-based indices
// (Fortran index i is i - 1 here); pythag(a, b) = sea_hypot(a, b),
// SIGN(a, b) = |a| with b's sign bit. tred1's e2 (the squares of e) is
// an output tql1 never reads and is not formed. An eigenvalue not found
// within SEA_EIG_MAXIT QL iterations, and every later one, is NaN
// (L-ip). tql1's search for a negligible e[m] always stops at m = n - 1
// (e[n-1] = 0) unless tst1 is NaN; then m = n - 1 is taken (the search's
// last index). The n values are then sorted by LANGUAGE.md 10.6's f64
// order (a stable insertion sort: ascending, -0 equal to +0, NaN after
// every number, equal values in their order).
//
// EIG_SYM_GEN (LAPACK dsygst itype 1, plain form): R = sea_la_potrf of a
// copy of M (M = R'R); Z = R^-T K column by column, then C = Z R^-1 row
// by row, both unblocked and in place over a copy of K; then EIG_SYM's
// reduction and iteration on C's lower triangle (no symmetry test).
//
// Checks, in each row's order (DESIGN.md 2.13.5, L-ik, L-iy):
//   EIG_SYM:     NOT_SQUARE (A's shape), NOT_SYMMETRIC; n = 0: empty;
//                an element +-Inf or NaN: n NaN.
//   EIG_SYM_GEN: NOT_SQUARE (K), NOT_SQUARE (M), SHAPE_MISMATCH (K's, M's
//                shape), NOT_SYMMETRIC (K, then M); n = 0: empty; an
//                element of K or M +-Inf or NaN: n NaN; NOT_POSDEF (M);
//                an element of C +-Inf or NaN: n NaN.
//
// Memory (DESIGN.md 2.13.5): the result (sea_arr_new_u, every element
// written) is made before the one scratch block (_sea_alloc), which is
// freed with _sea_free_block before the entry returns or fails, so the
// live count changes only by the result. The result vector's buffer is
// tql1's d. Scratch: EIG_SYM: the lower triangle a (n x n), then e (n);
// EIG_SYM_GEN: R (n x n), Z/C (n x n), e (n), then W (n * SEA_LA_NB,
// only when n > SEA_LA_NB). Every argument is borrowed and never
// written; the result has count 1.
//
// ABI: AAPCS64; every entry preserves x19-x28, x29, sp, d8-d15 and FPCR
// (never written here). Stack: the entries' frames are 128 bytes, tql1's
// 160 (sea_hypot is a leaf); the deepest chain is EIG_SYM_GEN (128) ->
// _sea_la_potrf -> Baysick's _bsk_kern_gemm_sub (rt_lu.s's frames, then
// Baysick's, which SEA_STACK_MARGIN covers).
// =====================================================================
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

// The entries' frame: the frame record, x19-x28, then four error slots.
.equ RT_EIG_SLOTS,      96
.equ RT_EIG_FRAME,      128
// tql1's frame: the frame record, x19-x26, d8-d15, el1, dl1.
.equ RT_EIG_Q_EL1,      144
.equ RT_EIG_Q_DL1,      152
.equ RT_EIG_Q_FRAME,    160
.if (RT_EIG_FRAME > 512) || (RT_EIG_Q_FRAME > 512) || ((RT_EIG_Q_FRAME % 16) != 0)
    .error "rt_eig: frames must be 16-byte multiples of at most 512 bytes"
.endif
.if (SEA_LA_NB < 1) || (SEA_LA_NB > 4095) || (SEA_EIG_MAXIT < 1) || (SEA_EIG_MAXIT > 4095)
    .error "rt_eig: SEA_LA_NB and SEA_EIG_MAXIT must fit a compare immediate"
.endif

// Save and restore x19-x28 above the frame record.
.macro RT_EIG_SAVE
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp x27, x28, [sp, #80]
.endm
.macro RT_EIG_RESTORE
    ldp x27, x28, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
.endm
// dst = SIGN(dst, src): |dst| with src's sign bit (Fortran's SIGN).
.macro RT_EIG_SIGN dst, src, tmp
    fabs \dst, \dst
    fmov \tmp, \src
    tbz \tmp, #63, 1f
    fneg \dst, \dst
1:
.endm

    .section __TEXT,__text,regular,pure_instructions

// =====================================================================
// Leaf helpers
// =====================================================================

// ---------------------------------------------------------------------
// Lrt_eig_nonfin -- is one of count doubles +-Inf or NaN?
//   Inputs  : x0 = the doubles, x1 = count
//   Outputs : x0 = 1 when one has an all-ones exponent, else 0
//   Clobbers: x1, x9, x10, flags
//   Callee-saved used: none
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_eig_nonfin:
    movz x10, #0xFFE0, lsl #48      // the exponent all ones, shifted left 1
Lrt_eig_nonfin_loop:
    cbz x1, Lrt_eig_nonfin_no
    ldr x9, [x0], #8
    lsl x9, x9, #1                  // drop the sign
    cmp x9, x10
    b.hs Lrt_eig_nonfin_yes         // Inf or NaN
    sub x1, x1, #1
    b Lrt_eig_nonfin_loop
Lrt_eig_nonfin_no:
    mov x0, #0
    ret
Lrt_eig_nonfin_yes:
    mov x0, #1
    ret

// ---------------------------------------------------------------------
// Lrt_eig_nanfill -- n doubles := NaN (L-ip, L-iy).
//   Inputs  : x0 = the doubles, x1 = n
//   Outputs : none
//   Clobbers: x0, x1, x9, flags
//   Callee-saved used: none
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_eig_nanfill:
    movz x9, #0x7FF8, lsl #48       // the default NaN
Lrt_eig_nanfill_loop:
    cbz x1, Lrt_eig_nanfill_ret
    str x9, [x0], #8
    sub x1, x1, #1
    b Lrt_eig_nanfill_loop
Lrt_eig_nanfill_ret:
    ret

// ---------------------------------------------------------------------
// Lrt_eig_cplower -- copy the lower triangle (i >= j) of an n x n matrix
//   (column stride n) into another (column stride n); the destination's
//   strict upper triangle is not written, the source's not read.
//   Inputs  : x0 = destination, x1 = source, x2 = n
//   Outputs : none
//   Clobbers: x0, x1, x9-x11, d0, flags
//   Callee-saved used: none
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_eig_cplower:
    lsl x9, x2, #3                  // the column stride in bytes
    mov x10, #0                     // j
Lrt_eig_cplower_col:
    cmp x10, x2
    b.hs Lrt_eig_cplower_ret
    mov x11, x10                    // i = j .. n - 1
Lrt_eig_cplower_row:
    ldr d0, [x1, x11, lsl #3]
    str d0, [x0, x11, lsl #3]
    add x11, x11, #1
    cmp x11, x2
    b.lo Lrt_eig_cplower_row
    add x0, x0, x9                  // the next columns
    add x1, x1, x9
    add x10, x10, #1
    b Lrt_eig_cplower_col
Lrt_eig_cplower_ret:
    ret

// ---------------------------------------------------------------------
// Lrt_eig_sort -- sort n doubles by LANGUAGE.md 10.6's f64 order, stable
//   (insertion: an element moves right past x only when it is greater:
//   a NaN when x is a number, or a number > x).
//   Inputs  : x0 = the doubles, x1 = n
//   Outputs : none
//   Clobbers: x9-x11, d0, d1, flags
//   Callee-saved used: none
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_eig_sort:
    mov x9, #1                      // i
Lrt_eig_sort_i:
    cmp x9, x1
    b.hs Lrt_eig_sort_ret
    ldr d0, [x0, x9, lsl #3]        // x = d[i]
    mov x10, x9                     // its place
Lrt_eig_sort_j:
    cbz x10, Lrt_eig_sort_put
    sub x11, x10, #1
    ldr d1, [x0, x11, lsl #3]       // d[place - 1]
    fcmp d1, d0
    b.gt Lrt_eig_sort_move          // a number greater than x
    b.vc Lrt_eig_sort_put           // ordered, not greater: stays
    fcmp d0, d0
    b.vs Lrt_eig_sort_put           // x NaN: nothing is greater (NaN = NaN)
Lrt_eig_sort_move:                  // (or d[place - 1] NaN, x a number)
    str d1, [x0, x10, lsl #3]
    mov x10, x11
    b Lrt_eig_sort_j
Lrt_eig_sort_put:
    str d0, [x0, x10, lsl #3]
    add x9, x9, #1
    b Lrt_eig_sort_i
Lrt_eig_sort_ret:
    ret

// ---------------------------------------------------------------------
// Lrt_eig_reduce -- dsygst itype 1, plain form (DESIGN.md 2.13.6
//   "EIG_SYM_GEN"), in place over Z = a copy of K:
//   Z = R^-T K: for each column c, for j ascending: s = K[j,c]; s = s -
//     R[kk,j] * Z[kk,c] for kk = 0 .. j - 1; Z[j,c] = s / R[j,j];
//   C = Z R^-1: for each row r, for j ascending: s = Z[r,j]; s = s -
//     R[kk,j] * C[r,kk] for kk = 0 .. j - 1; C[r,j] = s / R[j,j].
//   (Z[j,c] is read before it is written and only Z[kk < j, c] is read
//   after; likewise C[r,j] and C[r, kk < j]: the work can share one
//   array.)
//   Inputs  : x0 = R (upper triangle, column stride n), x1 = Z (n x n,
//             column stride n; holds K on entry, C on exit), x2 = n
//   Outputs : none
//   Clobbers: x4-x7, x9-x12, d0-d2, flags
//   Callee-saved used: none
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_eig_reduce:
    lsl x4, x2, #3                  // the column stride in bytes
    mov x5, #0                      // c
Lrt_eig_reduce_zc:
    cmp x5, x2
    b.hs Lrt_eig_reduce_c
    madd x9, x5, x4, x1             // &Z[0,c]
    mov x6, #0                      // j
Lrt_eig_reduce_zj:
    cmp x6, x2
    b.hs Lrt_eig_reduce_zcnext
    madd x10, x6, x4, x0            // &R[0,j]
    ldr d0, [x9, x6, lsl #3]        // s = K[j,c]
    mov x7, #0                      // kk
Lrt_eig_reduce_zk:
    cmp x7, x6
    b.hs Lrt_eig_reduce_zdiv
    ldr d1, [x10, x7, lsl #3]       // R[kk,j]
    ldr d2, [x9, x7, lsl #3]        // Z[kk,c]
    fmul d1, d1, d2
    fsub d0, d0, d1                 // s - R[kk,j] Z[kk,c], kk order
    add x7, x7, #1
    b Lrt_eig_reduce_zk
Lrt_eig_reduce_zdiv:
    ldr d1, [x10, x6, lsl #3]       // R[j,j]
    fdiv d0, d0, d1
    str d0, [x9, x6, lsl #3]        // Z[j,c]
    add x6, x6, #1
    b Lrt_eig_reduce_zj
Lrt_eig_reduce_zcnext:
    add x5, x5, #1
    b Lrt_eig_reduce_zc
Lrt_eig_reduce_c:
    mov x5, #0                      // r
Lrt_eig_reduce_cr:
    cmp x5, x2
    b.hs Lrt_eig_reduce_ret
    add x9, x1, x5, lsl #3          // &C[r,0] (row r: stride n doubles)
    mov x6, #0                      // j
Lrt_eig_reduce_cj:
    cmp x6, x2
    b.hs Lrt_eig_reduce_crnext
    madd x10, x6, x4, x0            // &R[0,j]
    madd x11, x6, x4, x9            // &C[r,j]
    ldr d0, [x11]                   // s = Z[r,j]
    mov x7, #0                      // kk
    mov x12, x9                     // &C[r,kk]
Lrt_eig_reduce_ck:
    cmp x7, x6
    b.hs Lrt_eig_reduce_cdiv
    ldr d1, [x10, x7, lsl #3]       // R[kk,j]
    ldr d2, [x12]                   // C[r,kk]
    fmul d1, d1, d2
    fsub d0, d0, d1                 // s - R[kk,j] C[r,kk], kk order
    add x12, x12, x4
    add x7, x7, #1
    b Lrt_eig_reduce_ck
Lrt_eig_reduce_cdiv:
    ldr d1, [x10, x6, lsl #3]       // R[j,j]
    fdiv d0, d0, d1
    str d0, [x11]                   // C[r,j]
    add x6, x6, #1
    b Lrt_eig_reduce_cj
Lrt_eig_reduce_crnext:
    add x5, x5, #1
    b Lrt_eig_reduce_cr
Lrt_eig_reduce_ret:
    ret

// ---------------------------------------------------------------------
// Lrt_eig_tred1 -- EISPACK tred1 (eigenvalues only), 0-based: reduce
//   the lower triangle of a to the tridiagonal (d, e): d the diagonal,
//   e[i] the subdiagonal element (i, i - 1), e[0] = 0. a's lower
//   triangle is overwritten (its strict upper triangle is never read
//   nor written). Statement by statement (Fortran labels in brackets):
//     for i: d[i] = a[n-1,i]; a[n-1,i] = a[i,i]                  [100]
//     for i = n-1 down to 0: l = i - 1; h = 0; scale = 0;
//       i = 0: e[i] = 0, next                                    [130]
//       scale = scale + |d[k]|, k = 0 .. l                       [120]
//       scale = 0 (not != 0): for j = 0 .. l: d[j] = a[l,j];
//         a[l,j] = a[i,j]; a[i,j] = 0; e[i] = 0, next      [125, 130]
//       for k = 0 .. l: d[k] = d[k] / scale; h = h + d[k] d[k]   [150]
//       f = d[l]; g = -SIGN(sqrt(h), f); e[i] = scale g;
//       h = h - f g; d[l] = f - g; l = 0: go to [285]
//       e[j] = 0 for j = 0 .. l                                  [170]
//       for j = 0 .. l: f = d[j]; g = e[j] + a[j,j] f; for k = j+1
//         .. l: g = g + a[k,j] d[k]; e[k] = e[k] + a[k,j] f;
//         e[j] = g                                          [200-240]
//       f = 0; for j: e[j] = e[j] / h; f = f + e[j] d[j]         [245]
//       h = f / (h + h); for j: e[j] = e[j] - h d[j]             [250]
//       for j: f = d[j]; g = e[j]; for k = j .. l: a[k,j] =
//         (a[k,j] - f e[k]) - g d[k]                        [260-280]
//       [285] for j = 0 .. l: f = d[j]; d[j] = a[l,j];
//         a[l,j] = a[i,j]; a[i,j] = f scale                      [290]
//   Inputs  : x0 = a (column stride n), x1 = n (>= 1), x2 = d, x3 = e
//   Outputs : d, e
//   Clobbers: x4-x10, d0-d6, flags
//   Callee-saved used: none
//   Frame   : none (leaf)
//   Registers: x4 = 8n, x5 = i, x6 = l, x7 = j, x8 = k, x10 = &a[0,j];
//             d0 = h, d1 = scale, d2 = f, d3 = g
// ---------------------------------------------------------------------
    .p2align 2
Lrt_eig_tred1:
    lsl x4, x1, #3                  // the column stride in bytes
    sub x6, x1, #1                  // n - 1
    mov x5, #0                      // i
Lrt_eig_tred1_init:                 // [100]
    madd x10, x5, x4, x0            // &a[0,i]
    ldr d4, [x10, x6, lsl #3]       // a[n-1,i]
    str d4, [x2, x5, lsl #3]        // d[i]
    ldr d5, [x10, x5, lsl #3]       // a[i,i]
    str d5, [x10, x6, lsl #3]       // a[n-1,i]
    add x5, x5, #1
    cmp x5, x1
    b.lo Lrt_eig_tred1_init
    // x5 = n: the loop below takes i = n - 1 down to 0.
Lrt_eig_tred1_i:
    cbz x5, Lrt_eig_tred1_ret
    sub x5, x5, #1                  // i
    cbz x5, Lrt_eig_tred1_ezero     // l < 0 (Fortran l < 1): [130]
    sub x6, x5, #1                  // l
    fmov d0, xzr                    // h = 0
    fmov d1, xzr                    // scale = 0
    mov x8, #0                      // k
Lrt_eig_tred1_scale:                // [120]
    ldr d4, [x2, x8, lsl #3]
    fabs d4, d4
    fadd d1, d1, d4                 // scale + |d[k]|
    add x8, x8, #1
    cmp x8, x6
    b.ls Lrt_eig_tred1_scale
    fcmp d1, #0.0
    b.ne Lrt_eig_tred1_scaled       // scale != 0: [140]
    mov x7, #0                      // j
Lrt_eig_tred1_zrow:                 // [125]
    madd x10, x7, x4, x0            // &a[0,j]
    ldr d4, [x10, x6, lsl #3]
    str d4, [x2, x7, lsl #3]        // d[j] = a[l,j]
    ldr d5, [x10, x5, lsl #3]
    str d5, [x10, x6, lsl #3]       // a[l,j] = a[i,j]
    str xzr, [x10, x5, lsl #3]      // a[i,j] = 0
    add x7, x7, #1
    cmp x7, x6
    b.ls Lrt_eig_tred1_zrow
Lrt_eig_tred1_ezero:                // [130]
    str xzr, [x3, x5, lsl #3]       // e[i] = 0
    b Lrt_eig_tred1_i
Lrt_eig_tred1_scaled:
    mov x8, #0                      // k
Lrt_eig_tred1_div:                  // [150]
    ldr d4, [x2, x8, lsl #3]
    fdiv d4, d4, d1                 // d[k] / scale
    str d4, [x2, x8, lsl #3]
    fmul d5, d4, d4
    fadd d0, d0, d5                 // h + d[k] d[k]
    add x8, x8, #1
    cmp x8, x6
    b.ls Lrt_eig_tred1_div
    ldr d2, [x2, x6, lsl #3]        // f = d[l]
    fsqrt d3, d0
    RT_EIG_SIGN d3, d2, x9          // SIGN(sqrt(h), f)
    fneg d3, d3                     // g
    fmul d4, d1, d3
    str d4, [x3, x5, lsl #3]        // e[i] = scale g
    fmul d4, d2, d3
    fsub d0, d0, d4                 // h = h - f g
    fsub d4, d2, d3
    str d4, [x2, x6, lsl #3]        // d[l] = f - g
    cbz x6, Lrt_eig_tred1_285       // l = 0 (Fortran l = 1)
    mov x7, #0
Lrt_eig_tred1_ez:                   // [170]
    str xzr, [x3, x7, lsl #3]       // e[j] = 0
    add x7, x7, #1
    cmp x7, x6
    b.ls Lrt_eig_tred1_ez
    mov x7, #0                      // j: form A u [200-240]
Lrt_eig_tred1_au:
    ldr d2, [x2, x7, lsl #3]        // f = d[j]
    madd x10, x7, x4, x0            // &a[0,j]
    ldr d4, [x10, x7, lsl #3]       // a[j,j]
    fmul d4, d4, d2
    ldr d3, [x3, x7, lsl #3]
    fadd d3, d3, d4                 // g = e[j] + a[j,j] f
    add x8, x7, #1                  // k = j + 1 .. l
Lrt_eig_tred1_auk:
    cmp x8, x6
    b.hi Lrt_eig_tred1_auend
    ldr d5, [x10, x8, lsl #3]       // a[k,j]
    ldr d6, [x2, x8, lsl #3]        // d[k]
    fmul d6, d5, d6
    fadd d3, d3, d6                 // g + a[k,j] d[k]
    fmul d5, d5, d2                 // a[k,j] f
    ldr d6, [x3, x8, lsl #3]
    fadd d6, d6, d5
    str d6, [x3, x8, lsl #3]        // e[k] + a[k,j] f
    add x8, x8, #1
    b Lrt_eig_tred1_auk
Lrt_eig_tred1_auend:                // [220]
    str d3, [x3, x7, lsl #3]        // e[j] = g
    add x7, x7, #1
    cmp x7, x6
    b.ls Lrt_eig_tred1_au
    fmov d2, xzr                    // f = 0: form p [245]
    mov x7, #0
Lrt_eig_tred1_p:
    ldr d4, [x3, x7, lsl #3]
    fdiv d4, d4, d0                 // e[j] / h
    str d4, [x3, x7, lsl #3]
    ldr d5, [x2, x7, lsl #3]
    fmul d5, d4, d5
    fadd d2, d2, d5                 // f + e[j] d[j]
    add x7, x7, #1
    cmp x7, x6
    b.ls Lrt_eig_tred1_p
    fadd d4, d0, d0
    fdiv d0, d2, d4                 // h = f / (h + h)
    mov x7, #0                      // form q [250]
Lrt_eig_tred1_q:
    ldr d4, [x3, x7, lsl #3]
    ldr d5, [x2, x7, lsl #3]
    fmul d5, d0, d5
    fsub d4, d4, d5                 // e[j] - h d[j]
    str d4, [x3, x7, lsl #3]
    add x7, x7, #1
    cmp x7, x6
    b.ls Lrt_eig_tred1_q
    mov x7, #0                      // j: form the reduced a [260-280]
Lrt_eig_tred1_red:
    ldr d2, [x2, x7, lsl #3]        // f = d[j]
    ldr d3, [x3, x7, lsl #3]        // g = e[j]
    madd x10, x7, x4, x0            // &a[0,j]
    mov x8, x7                      // k = j .. l
Lrt_eig_tred1_redk:
    ldr d4, [x10, x8, lsl #3]       // a[k,j]
    ldr d5, [x3, x8, lsl #3]
    fmul d5, d2, d5
    fsub d4, d4, d5                 // a[k,j] - f e[k]
    ldr d6, [x2, x8, lsl #3]
    fmul d6, d3, d6
    fsub d4, d4, d6                 // ... - g d[k]
    str d4, [x10, x8, lsl #3]
    add x8, x8, #1
    cmp x8, x6
    b.ls Lrt_eig_tred1_redk
    add x7, x7, #1
    cmp x7, x6
    b.ls Lrt_eig_tred1_red
Lrt_eig_tred1_285:
    mov x7, #0                      // j [290]
Lrt_eig_tred1_back:
    madd x10, x7, x4, x0            // &a[0,j]
    ldr d2, [x2, x7, lsl #3]        // f = d[j]
    ldr d4, [x10, x6, lsl #3]
    str d4, [x2, x7, lsl #3]        // d[j] = a[l,j]
    ldr d5, [x10, x5, lsl #3]
    str d5, [x10, x6, lsl #3]       // a[l,j] = a[i,j]
    fmul d4, d2, d1
    str d4, [x10, x5, lsl #3]       // a[i,j] = f scale
    add x7, x7, #1
    cmp x7, x6
    b.ls Lrt_eig_tred1_back
    b Lrt_eig_tred1_i
Lrt_eig_tred1_ret:
    ret

// ---------------------------------------------------------------------
// Lrt_eig_tql1 -- EISPACK tql1 (machine-independent form), 0-based:
//   the eigenvalues of the tridiagonal (d, e) into d, ordered as tql1
//   orders them; e is destroyed. Statement by statement:
//     n = 1: return. e[i-1] = e[i] for i = 1 .. n-1; f = 0; tst1 = 0;
//     e[n-1] = 0                                                 [100]
//     for l = 0 .. n-1: j = 0; h = |d[l]| + |e[l]|; tst1 < h: tst1 = h;
//       m = the first index from l with tst1 + |e[m]| = tst1 (n - 1
//       when there is none: only a NaN tst1)                [110, 120]
//       m != l: [130] j = SEA_EIG_MAXIT: d[l .. n-1] = NaN, return;
//         j = j + 1; l1 = l + 1; g = d[l];
//         p = (d[l1] - g) / (2 e[l]); r = pythag(p, 1);
//         d[l] = e[l] / (p + SIGN(r, p)); d[l1] = e[l] (p + SIGN(r, p));
//         dl1 = d[l1]; h = g - d[l]; d[i] = d[i] - h, i = l + 2 .. n-1;
//         f = f + h                                              [145]
//         p = d[m]; c = 1; c2 = c; el1 = e[l1]; s = 0
//         for i = m - 1 down to l: c3 = c2; c2 = c; s2 = s;
//           g = c e[i]; h = c p; r = pythag(p, e[i]); e[i+1] = s r;
//           s = e[i] / r; c = p / r; p = c d[i] - s g;
//           d[i+1] = h + s (c g + s d[i])                        [200]
//         p = -s s2 c3 el1 e[l] / dl1 (the products left to right, the
//         division, the sign; negation is exact, so the bits are
//         Fortran's -(...) either way); e[l] = s p; d[l] = c p;
//         tst1 + |e[l]| > tst1: go to [130]
//       [210] p = d[l] + f; for i = l down to 1: p >= d[i-1]: stop;
//         d[i] = d[i-1]; d[i] = p                         [230-270]
//   g and h of the rotation are formed after pythag's call (it changes
//   none of c, p, e[i]), so they need no preserved register.
//   Inputs  : x0 = d, x1 = e, x2 = n (>= 1)
//   Outputs : d
//   Clobbers: x0-x17, v0-v7, v16-v31, flags (what sea_hypot may)
//   Callee-saved used: x19 = d, x20 = e, x21 = n, x22 = l, x23 = m,
//             x24 = j (iterations), x25 = i (+ 1 in the rotation loop);
//             d8 = f, d9 = tst1, d10 = c, d11 = c2, d12 = c3, d13 = s,
//             d14 = s2, d15 = p
//   Frame   : 160 bytes (frame record, x19-x26, d8-d15, el1, dl1)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_eig_tql1:
    cmp x2, #1
    b.ls Lrt_eig_tql1_leaf          // n = 1: d is the eigenvalue
    stp x29, x30, [sp, #-RT_EIG_Q_FRAME]!   // frame record
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp d8, d9, [sp, #80]
    stp d10, d11, [sp, #96]
    stp d12, d13, [sp, #112]
    stp d14, d15, [sp, #128]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x9, #1                      // [100] e[i-1] = e[i]
Lrt_eig_tql1_shift:
    ldr d0, [x20, x9, lsl #3]
    sub x10, x9, #1
    str d0, [x20, x10, lsl #3]
    add x9, x9, #1
    cmp x9, x21
    b.lo Lrt_eig_tql1_shift
    fmov d8, xzr                    // f = 0
    fmov d9, xzr                    // tst1 = 0
    sub x9, x21, #1
    str xzr, [x20, x9, lsl #3]      // e[n-1] = 0
    mov x22, #0                     // l
Lrt_eig_tql1_l:
    cmp x22, x21
    b.hs Lrt_eig_tql1_done
    mov x24, #0                     // j = 0
    ldr d0, [x19, x22, lsl #3]
    fabs d0, d0
    ldr d1, [x20, x22, lsl #3]
    fabs d1, d1
    fadd d0, d0, d1                 // h = |d[l]| + |e[l]|
    fcmp d9, d0
    fcsel d9, d0, d9, mi            // tst1 < h: tst1 = h
    mov x23, x22                    // m = l
Lrt_eig_tql1_search:                // [110]
    ldr d1, [x20, x23, lsl #3]
    fabs d1, d1
    fadd d1, d9, d1                 // tst2 = tst1 + |e[m]|
    fcmp d1, d9
    b.eq Lrt_eig_tql1_m             // [120]
    add x23, x23, #1
    cmp x23, x21
    b.lo Lrt_eig_tql1_search
    sub x23, x21, #1                // none (tst1 NaN): m = n - 1
Lrt_eig_tql1_m:
    cmp x23, x22
    b.eq Lrt_eig_tql1_found         // m = l: [210]
Lrt_eig_tql1_iter:                  // [130]
    cmp x24, #SEA_EIG_MAXIT
    b.eq Lrt_eig_tql1_fail
    add x24, x24, #1                // j = j + 1
    // The shift.
    add x9, x22, #1                 // l1
    ldr d0, [x19, x22, lsl #3]      // g = d[l]
    ldr d1, [x19, x9, lsl #3]
    fsub d1, d1, d0                 // d[l1] - g
    ldr d2, [x20, x22, lsl #3]
    fadd d2, d2, d2                 // 2 e[l] (exact)
    fdiv d15, d1, d2                // p
    fmov d0, d15
    fmov d1, #1.0
    bl _sea_hypot                   // r = pythag(p, 1)
    RT_EIG_SIGN d0, d15, x9         // SIGN(r, p)
    fadd d0, d15, d0                // p + SIGN(r, p)
    ldr d1, [x20, x22, lsl #3]      // e[l]
    fdiv d2, d1, d0                 // e[l] / (p + SIGN(r, p))
    fmul d3, d1, d0                 // e[l] (p + SIGN(r, p))
    add x9, x22, #1                 // l1
    ldr d4, [x19, x22, lsl #3]      // g (d[l] before the store)
    str d2, [x19, x22, lsl #3]      // d[l]
    str d3, [x19, x9, lsl #3]       // d[l1]
    str d3, [sp, #RT_EIG_Q_DL1]     // dl1 = d[l1]
    fsub d4, d4, d2                 // h = g - d[l]
    add x10, x22, #2                // i = l2 .. n-1
Lrt_eig_tql1_sub:
    cmp x10, x21
    b.hs Lrt_eig_tql1_145
    ldr d5, [x19, x10, lsl #3]
    fsub d5, d5, d4                 // d[i] - h
    str d5, [x19, x10, lsl #3]
    add x10, x10, #1
    b Lrt_eig_tql1_sub
Lrt_eig_tql1_145:
    fadd d8, d8, d4                 // f = f + h
    // The QL transformation.
    ldr d15, [x19, x23, lsl #3]     // p = d[m]
    fmov d10, #1.0                  // c = 1
    fmov d11, d10                   // c2 = c
    ldr d0, [x20, x9, lsl #3]
    str d0, [sp, #RT_EIG_Q_EL1]     // el1 = e[l1]
    fmov d13, xzr                   // s = 0
    mov x25, x23                    // i + 1 = m
Lrt_eig_tql1_rot:                   // for i = m - 1 down to l
    cmp x25, x22
    b.ls Lrt_eig_tql1_rotend
    sub x25, x25, #1                // i
    fmov d12, d11                   // c3 = c2
    fmov d11, d10                   // c2 = c
    fmov d14, d13                   // s2 = s
    fmov d0, d15
    ldr d1, [x20, x25, lsl #3]
    bl _sea_hypot                   // r = pythag(p, e[i])
    ldr d1, [x20, x25, lsl #3]      // e[i]
    fmul d2, d10, d1                // g = c e[i]
    fmul d3, d10, d15               // h = c p
    fmul d4, d13, d0
    add x9, x25, #1
    str d4, [x20, x9, lsl #3]       // e[i+1] = s r
    fdiv d13, d1, d0                // s = e[i] / r
    fdiv d10, d15, d0               // c = p / r
    ldr d5, [x19, x25, lsl #3]      // d[i]
    fmul d6, d10, d5                // c d[i]
    fmul d7, d13, d2                // s g
    fsub d15, d6, d7                // p = c d[i] - s g
    fmul d6, d10, d2                // c g
    fmul d7, d13, d5                // s d[i]
    fadd d6, d6, d7
    fmul d6, d13, d6                // s (c g + s d[i])
    fadd d6, d3, d6
    str d6, [x19, x9, lsl #3]       // d[i+1] = h + s (c g + s d[i])
    b Lrt_eig_tql1_rot
Lrt_eig_tql1_rotend:
    fmul d0, d13, d14               // s s2
    fmul d0, d0, d12                // ... c3
    ldr d1, [sp, #RT_EIG_Q_EL1]
    fmul d0, d0, d1                 // ... el1
    ldr d1, [x20, x22, lsl #3]
    fmul d0, d0, d1                 // ... e[l]
    ldr d1, [sp, #RT_EIG_Q_DL1]
    fdiv d0, d0, d1                 // ... / dl1
    fneg d15, d0                    // p
    fmul d0, d13, d15
    str d0, [x20, x22, lsl #3]      // e[l] = s p
    fmul d1, d10, d15
    str d1, [x19, x22, lsl #3]      // d[l] = c p
    fabs d0, d0
    fadd d0, d9, d0                 // tst2 = tst1 + |e[l]|
    fcmp d0, d9
    b.gt Lrt_eig_tql1_iter          // tst2 > tst1: [130]
Lrt_eig_tql1_found:                 // [210]
    ldr d0, [x19, x22, lsl #3]
    fadd d0, d0, d8                 // p = d[l] + f
    mov x9, x22                     // i = l
Lrt_eig_tql1_order:                 // [230]
    cbz x9, Lrt_eig_tql1_put        // [250] i = 0
    sub x10, x9, #1
    ldr d1, [x19, x10, lsl #3]      // d[i-1]
    fcmp d0, d1
    b.ge Lrt_eig_tql1_put           // p >= d[i-1]: [270]
    str d1, [x19, x9, lsl #3]       // d[i] = d[i-1]
    mov x9, x10
    b Lrt_eig_tql1_order
Lrt_eig_tql1_put:                   // [270]
    str d0, [x19, x9, lsl #3]       // d[i] = p
    add x22, x22, #1
    b Lrt_eig_tql1_l
Lrt_eig_tql1_fail:
    // No convergence within SEA_EIG_MAXIT iterations: d[l .. n-1] = NaN.
    add x0, x19, x22, lsl #3
    sub x1, x21, x22
    bl Lrt_eig_nanfill
Lrt_eig_tql1_done:
    ldp d14, d15, [sp, #128]
    ldp d12, d13, [sp, #112]
    ldp d10, d11, [sp, #96]
    ldp d8, d9, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #RT_EIG_Q_FRAME
Lrt_eig_tql1_leaf:
    ret

// ---------------------------------------------------------------------
// Lrt_eig_solve -- tred1, tql1 and the final sort.
//   Inputs  : x0 = a (lower triangle, column stride n; destroyed),
//             x1 = n (>= 1), x2 = d (n doubles: the result), x3 = e
//             (n doubles of scratch)
//   Outputs : d = the eigenvalues by LANGUAGE.md 10.6's f64 order
//   Clobbers: x0-x17, v0-v7, v16-v31, flags
//   Callee-saved used: x19 = n, x20 = d, x21 = e
//   Frame   : 48 bytes (frame record, x19, x20, x21, pad)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_eig_solve:
    stp x29, x30, [sp, #-48]!       // frame record
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    mov x19, x1
    mov x20, x2
    mov x21, x3
    bl Lrt_eig_tred1                // (a, n, d, e)
    mov x0, x20
    mov x1, x21
    mov x2, x19
    bl Lrt_eig_tql1                 // (d, e, n)
    mov x0, x20
    mov x1, x19
    bl Lrt_eig_sort                 // (d, n)
    ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// =====================================================================
// The entries
// =====================================================================

// ---------------------------------------------------------------------
// _sea_eig_sym -- the entry EIG_SYM.
//   Inputs  : x0 = A (a dynamic f64 matrix), x1 = site
//   Outputs : x0 = a new f64 vector of n (count 1)
//   Clobbers: x0-x17, v0-v7, v16-v31, flags
//   Callee-saved used: x19 = A, x20 = site, x21 = n, x22 = the result,
//             x23 = the scratch block, x24 = its bytes, x25 = n * n
//   Frame   : 128 bytes (frame record, x19-x28, four error slots)
// ---------------------------------------------------------------------
    .globl _sea_eig_sym
    .p2align 2
_sea_eig_sym:
    stp x29, x30, [sp, #-RT_EIG_FRAME]!     // frame record
    mov x29, sp
    RT_EIG_SAVE
    mov x19, x0
    mov x20, x1
    ldr x21, [x19, #SEA_ARR_ROWS]   // n
    ldr x9, [x19, #SEA_ARR_COLS]
    cmp x9, x21
    b.ne Lrt_eig_sym_square
    ldr x0, [x19, #SEA_ARR_DATA]
    mov x1, x21
    mov x2, x21
    bl _sea_la_issym                // Decision 123
    cbz x0, Lrt_eig_sym_nsym
    // The result first: a vector of n.
    mov x0, #SEA_EK_F64
    mov x1, #1
    mov x2, x21
    mov x3, #1
    mov x4, x20
    bl _sea_arr_new_u
    mov x22, x0
    cbz x21, Lrt_eig_sym_ret        // n = 0: the empty vector
    mul x25, x21, x21
    ldr x0, [x19, #SEA_ARR_DATA]
    mov x1, x25
    bl Lrt_eig_nonfin
    cbnz x0, Lrt_eig_sym_nan        // an Inf or NaN: n NaN (L-ip)
    // Scratch: a (n x n), then e (n).
    add x24, x25, x21
    lsl x24, x24, #3
    mov x0, x24
    mov x1, x20
    bl _sea_alloc
    mov x23, x0
    mov x0, x23                     // a = A's lower triangle
    ldr x1, [x19, #SEA_ARR_DATA]
    mov x2, x21
    bl Lrt_eig_cplower
    mov x0, x23
    mov x1, x21
    ldr x2, [x22, #SEA_ARR_DATA]    // d: the result's elements
    add x3, x23, x25, lsl #3        // e
    bl Lrt_eig_solve
    mov x0, x23
    mov x1, x24
    bl _sea_free_block              // the scratch back
Lrt_eig_sym_ret:
    mov x0, x22
    RT_EIG_RESTORE
    ldp x29, x30, [sp], #RT_EIG_FRAME
    ret
Lrt_eig_sym_nan:
    ldr x0, [x22, #SEA_ARR_DATA]
    mov x1, x21
    bl Lrt_eig_nanfill
    b Lrt_eig_sym_ret
Lrt_eig_sym_square:
    stp x21, x9, [sp, #RT_EIG_SLOTS]    // A's shape
    mov x0, #SEA_E_NOT_SQUARE
    mov x1, x20
    add x2, sp, #RT_EIG_SLOTS
    bl _sea_err                     // noreturn
Lrt_eig_sym_nsym:
    mov x0, #SEA_E_NOT_SYMMETRIC
    mov x1, x20
    mov x2, #0                      // no argument slots
    bl _sea_err                     // noreturn

// ---------------------------------------------------------------------
// _sea_eig_sym_gen -- the entry EIG_SYM_GEN.
//   Inputs  : x0 = K, x1 = M (dynamic f64 matrices), x2 = site
//   Outputs : x0 = a new f64 vector of n (count 1)
//   Clobbers: x0-x17, v0-v7, v16-v31, flags
//   Callee-saved used: x19 = K, x20 = M, x21 = site, x22 = n, x23 = the
//             result, x24 = the scratch block, x25 = its bytes, x26 =
//             n * n, x27 = W's offset in the scratch, or 0
//   Frame   : 128 bytes (frame record, x19-x28, four error slots)
// ---------------------------------------------------------------------
    .globl _sea_eig_sym_gen
    .p2align 2
_sea_eig_sym_gen:
    stp x29, x30, [sp, #-RT_EIG_FRAME]!     // frame record
    mov x29, sp
    RT_EIG_SAVE
    mov x19, x0
    mov x20, x1
    mov x21, x2
    ldr x22, [x19, #SEA_ARR_ROWS]   // n
    ldr x9, [x19, #SEA_ARR_COLS]
    cmp x9, x22
    b.ne Lrt_eig_gen_ksquare        // NOT_SQUARE (K)
    ldr x10, [x20, #SEA_ARR_ROWS]
    ldr x11, [x20, #SEA_ARR_COLS]
    cmp x11, x10
    b.ne Lrt_eig_gen_msquare        // NOT_SQUARE (M)
    cmp x10, x22
    b.ne Lrt_eig_gen_shape          // different orders
    ldr x0, [x19, #SEA_ARR_DATA]
    mov x1, x22
    mov x2, x22
    bl _sea_la_issym                // K symmetric?
    cbz x0, Lrt_eig_gen_nsym
    ldr x0, [x20, #SEA_ARR_DATA]
    mov x1, x22
    mov x2, x22
    bl _sea_la_issym                // M symmetric?
    cbz x0, Lrt_eig_gen_nsym
    // The result first: a vector of n.
    mov x0, #SEA_EK_F64
    mov x1, #1
    mov x2, x22
    mov x3, #1
    mov x4, x21
    bl _sea_arr_new_u
    mov x23, x0
    cbz x22, Lrt_eig_gen_ret        // n = 0: the empty vector
    // L-iy: an Inf or NaN in K or M gives n NaN, before the Cholesky.
    mul x26, x22, x22
    ldr x0, [x19, #SEA_ARR_DATA]
    mov x1, x26
    bl Lrt_eig_nonfin
    cbnz x0, Lrt_eig_gen_nan
    ldr x0, [x20, #SEA_ARR_DATA]
    mov x1, x26
    bl Lrt_eig_nonfin
    cbnz x0, Lrt_eig_gen_nan
    // Scratch: R (n x n), Z/C (n x n), e (n), W (n * NB, n > NB only).
    lsl x25, x26, #4
    add x25, x25, x22, lsl #3
    mov x27, #0
    cmp x22, #SEA_LA_NB
    b.ls 1f
    mov x27, x25                    // W after e
    mov x9, #(8 * SEA_LA_NB)
    mul x9, x9, x22
    add x25, x25, x9
1:  mov x0, x25
    mov x1, x21
    bl _sea_alloc
    mov x24, x0
    mov x0, x24                     // R = M (potrf reads its upper triangle)
    ldr x1, [x20, #SEA_ARR_DATA]
    lsl x2, x26, #3
    bl _memcpy
    add x0, x24, x26, lsl #3        // Z = K
    ldr x1, [x19, #SEA_ARR_DATA]
    lsl x2, x26, #3
    bl _memcpy
    mov x0, x24
    mov x1, x22
    mov x2, x22
    mov x3, #0                      // no W needed for n <= NB
    cbz x27, 2f
    add x3, x24, x27
2:  bl _sea_la_potrf                // M = R'R
    cbnz x0, Lrt_eig_gen_posdef
    mov x0, x24
    add x1, x24, x26, lsl #3
    mov x2, x22
    bl Lrt_eig_reduce               // C = R^-T K R^-1 (over Z)
    add x0, x24, x26, lsl #3
    mov x1, x26
    bl Lrt_eig_nonfin
    cbnz x0, Lrt_eig_gen_nanfree    // the reduction overflowed: n NaN
    add x0, x24, x26, lsl #3        // a = C (its lower triangle)
    mov x1, x22
    ldr x2, [x23, #SEA_ARR_DATA]    // d: the result's elements
    add x3, x24, x26, lsl #4        // e
    bl Lrt_eig_solve
    mov x0, x24
    mov x1, x25
    bl _sea_free_block              // the scratch back
Lrt_eig_gen_ret:
    mov x0, x23
    RT_EIG_RESTORE
    ldp x29, x30, [sp], #RT_EIG_FRAME
    ret
Lrt_eig_gen_nanfree:
    mov x0, x24
    mov x1, x25
    bl _sea_free_block              // the scratch back
Lrt_eig_gen_nan:
    ldr x0, [x23, #SEA_ARR_DATA]
    mov x1, x22
    bl Lrt_eig_nanfill
    b Lrt_eig_gen_ret
Lrt_eig_gen_posdef:
    mov x0, x24
    mov x1, x25
    bl _sea_free_block              // the scratch back first
    mov x0, x23
    bl _sea_free                    // the result has count 1: freed and uncounted
    mov x0, #SEA_E_NOT_POSDEF
    mov x1, x21
    mov x2, #0                      // no argument slots
    bl _sea_err                     // noreturn
Lrt_eig_gen_ksquare:
    stp x22, x9, [sp, #RT_EIG_SLOTS]    // K's shape
    mov x0, #SEA_E_NOT_SQUARE
    mov x1, x21
    add x2, sp, #RT_EIG_SLOTS
    bl _sea_err                     // noreturn
Lrt_eig_gen_msquare:
    stp x10, x11, [sp, #RT_EIG_SLOTS]   // M's shape
    mov x0, #SEA_E_NOT_SQUARE
    mov x1, x21
    add x2, sp, #RT_EIG_SLOTS
    bl _sea_err                     // noreturn
Lrt_eig_gen_shape:
    stp x22, x9, [sp, #RT_EIG_SLOTS]    // K's shape, then M's
    stp x10, x11, [sp, #(RT_EIG_SLOTS + 2 * SEA_SLOT_SIZE)]
    mov x0, #SEA_E_SHAPE_MISMATCH
    mov x1, x21
    add x2, sp, #RT_EIG_SLOTS
    bl _sea_err                     // noreturn
Lrt_eig_gen_nsym:
    mov x0, #SEA_E_NOT_SYMMETRIC
    mov x1, x21
    mov x2, #0                      // no argument slots
    bl _sea_err                     // noreturn
