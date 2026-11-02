// =====================================================================
// sea/runtime/arm64_macos/rt_lu.s -- the factorizations, the solves and
// rcond (DESIGN.md 2.13.5 entries LU, CHOL, LU_SOLVE, CHOL_SOLVE, SOLVE,
// RCOND; 2.13.6 "Baysick views", "LU", "Triangular solves with many
// right-hand sides", "CHOL", "CHOL_SOLVE", "SOLVE", "RCOND", "Handles",
// "Private routines"; 2.13.2; LANGUAGE.md 10.8).
//
// Defines (global, rt.inc SEA_ENTRY_LIST):
//   _sea_lu         (A, site) -> a new Lu handle (P A = L U, and ||A||_1)
//   _sea_chol       (A, site) -> a new Chol handle (A = R' R)
//   _sea_lu_solve   (F, B, site) -> X with A X = B, F an Lu of A
//   _sea_chol_solve (F, B, site) -> X with R' R X = B, F a Chol
//   _sea_solve      (A, B, site) -> X with A X = B (Cholesky or LU)
//   _sea_rcond      (F, site) -> d0 = the reciprocal 1-norm condition
//                   estimate of an Lu
// Defines (private to the runtime, L-jc; no rt.inc record, no
// allocation, no error, no site; AAPCS64):
//   _sea_la_potrf (x0 = a, x1 = n, x2 = ld, x3 = w) -> x0 = status
//       CHOL's algorithm in place on the column-major n x n matrix at a
//       with column stride ld (ld >= n), reading only its upper triangle;
//       on success its strict lower triangle is +0 and the upper triangle
//       holds R. w: scratch of at least n * SEA_LA_NB doubles for the
//       transposed panel W (only touched when n > SEA_LA_NB). Result 0
//       when R is complete, else 1 + the index of the first pivot that
//       is not greater than 0 (a NaN pivot included). Rows n .. ld-1 of
//       each column are never touched. Preserves x19-x28, d8-d15, FPCR;
//       clobbers what AAPCS64 allows (it calls _bsk_kern_gemm_sub).
//   _sea_la_issym (x0 = a, x1 = n, x2 = ld) -> x0 = 1 when every pair
//       a[i,j], a[j,i] (i < j, compared column by column) is equal (==,
//       so +0 equals -0) or both NaN, else 0. A leaf: clobbers x9-x13,
//       d0, d1 and the flags only (x0-x2 other than x0's result kept).
// Uses: _sea_alloc, _sea_free_block, _sea_live (rt_mem.s), _sea_arr_new_u
//       (rt_arr.s), _sea_err (rt_err.s), memcpy (libSystem), Baysick's
//       _bsk_kern_gemm_sub (through its trampoline, under the variant
//       main selected).
//
// Notation (DESIGN.md 2.13.6): matrices are column-major, A[i,j] at
// DATA + 8 * (i + j * ld); panels J = [j0, j1) with j1 = min(n, j0 + NB),
// NB = SEA_LA_NB. Every sum runs in the stated index order, each product
// and each sum rounded separately (fmul then fsub/fadd, never FMA),
// divisions are true divisions, fsqrt is correctly rounded. Everything
// here is scalar and the same IEEE operations in the same order as the
// x86_64 runtime (L-it); results differ between targets and variants only
// through Baysick's kernels.
//
// Baysick views: V(X) of a column-major r x c block X with column stride
// ld is MV_DATA = &X[0,0], MV_ROWS = c, MV_COLS = r, MV_LD = ld (the
// row-major transpose), so C <- C - A B is
// _bsk_kern_gemm_sub(V(C), V(B), V(A)) (Lrt_lu_gsub). Every call has
// r, c and the inner extent >= 1 and a C sharing no element with A or B
// (blocks of one matrix with interleaved address ranges are allowed by
// Baysick DESIGN.md 6.6.1).
//
// Handles (L-is; the private layout of DESIGN.md 4.8, the same in both
// runtimes): one _sea_alloc block: the object header (count, tag; bytes
// 9 .. 15 zero), n at 16, ||A||_1 at 24 (an f64; 0 in a Chol), the first
// zero pivot index at 32 (-1 if none; always -1 in a Chol), 40 .. 63
// zero, at 64 the n x n factor column-major with ld n, then for an Lu
// the n pivot indices as u32 (LAPACK's ipiv, 0-based). sea_lu and
// sea_chol count the handle in _sea_live once it is complete; sea_free
// (rt_mem.s) frees and uncounts it.
//
// Memory (DESIGN.md 2.13.5): every result is made by sea_arr_new_u (or
// is a handle block) before any scratch; scratch is one _sea_alloc block
// per call, freed with _sea_free_block before the entry returns, so the
// live count changes only by the result. A failing allocation is
// _sea_err(SEA_E_OUT_OF_MEMORY, site) on _sea_alloc's path. Every
// argument is borrowed and never written (a handle argument is not
// retained); the result has count 1.
//
// Checks, in each row's order (L-ik): NOT_SQUARE (the operand's shape as
// one `h` pair), SHAPE_MISMATCH (n x n, then B's shape: rows, then cols
// or SEA_SHAPE_VEC), SINGULAR (no slot), NOT_POSDEF (no slot).
//
// ABI: AAPCS64; every entry preserves x19-x28, x29, sp, d8-d15 and FPCR
// (never written here). Stack: every own frame is at most 128 bytes
// (DESIGN.md 2.13.5: at most 512); the deepest chain is an entry (128),
// a solve or factor routine (96), Lrt_lu_gsub (112), then
// _bsk_kern_gemm_sub's frames, which SEA_STACK_MARGIN covers.
// =====================================================================
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"
.include "runtime.inc"

// The handle's private layout (DESIGN.md 2.13.6 "Handles", 4.8).
.equ RT_LU_H_N,         16          /* u64  the order n */
.equ RT_LU_H_ANORM,     24          /* f64  ||A||_1 of the input (Lu); 0 (Chol) */
.equ RT_LU_H_ZP,        32          /* i64  the first zero pivot index, -1 if none */
.equ RT_LU_H_Z0,        40          /* 40 .. 63: zero */
.equ RT_LU_H_F,         64          /* the n x n factor, then an Lu's n u32 pivots */
.if (RT_LU_H_N != SEA_OBJ_HDR) || (RT_LU_H_F != (SEA_OBJ_HDR + 48))
    .error "rt_lu: the handle layout is SEA_OBJ_HDR + 48 bytes of fields"
.endif

// The entries' frame: the frame record, x19-x28, then 32 bytes (four
// error slots, or d8-d11 in _sea_rcond).
.equ RT_LU_SLOTS,       96
.equ RT_LU_FRAME,       128
// The factor and solve routines' frame: the frame record, x19-x28.
.equ RT_LU_RFRAME,      96
// Lrt_lu_gsub's frame: the frame record and three MV views.
.equ RT_LU_G_VC,        16
.equ RT_LU_G_VB,        (16 + MV_SIZE)
.equ RT_LU_G_VA,        (16 + 2 * MV_SIZE)
.equ RT_LU_G_FRAME,     (16 + 3 * MV_SIZE)  /* 112 bytes */
.if (RT_LU_FRAME > 512) || (RT_LU_G_FRAME > 512) || ((RT_LU_G_FRAME % 16) != 0)
    .error "rt_lu: frames must be 16-byte multiples of at most 512 bytes"
.endif
.if (SEA_LA_NB < 1) || (SEA_LA_NB > 4095)
    .error "rt_lu: SEA_LA_NB must fit an add immediate"
.endif

// Save and restore x19-x28 above the frame record.
.macro RT_LU_SAVE
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp x27, x28, [sp, #80]
.endm
.macro RT_LU_RESTORE
    ldp x27, x28, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
.endm
// dst = min(n, j0 + SEA_LA_NB): the end of the panel starting at j0.
.macro RT_LU_PEND dst, j0, n
    add \dst, \j0, #SEA_LA_NB
    cmp \dst, \n
    csel \dst, \n, \dst, hi
.endm
// dst = the bytes of SOLVE's W region for order n: 8 * n * SEA_LA_NB when
// n > SEA_LA_NB (a trailing update exists), else 0. Clobbers the flags.
.macro RT_LU_WBYTES dst, n
    mov \dst, #(8 * SEA_LA_NB)
    mul \dst, \dst, \n
    cmp \n, #SEA_LA_NB
    csel \dst, \dst, xzr, hi
.endm
// _sea_live + 1: a handle is complete (rt_mem.s's object counter).
.macro RT_LU_COUNT
    adrp x9, _sea_live@PAGE
    ldr x10, [x9, _sea_live@PAGEOFF]
    add x10, x10, #1
    str x10, [x9, _sea_live@PAGEOFF]
.endm

    .section __TEXT,__text,regular,pure_instructions

// =====================================================================
// Shared leaf routines
// =====================================================================

// ---------------------------------------------------------------------
// Lrt_lu_norm1 -- ||A||_1 by dlange's rule (DESIGN.md 2.13.6 "LU"):
//   s_j = |A[0,j]| + |A[1,j]| + ... in row order; the norm is s_0, then
//   s_j whenever s_j > norm or s_j is NaN; 0 for n = 0.
//   Inputs  : x0 = &A[0,0] (column stride n), x1 = n
//   Outputs : d0 = ||A||_1
//   Clobbers: x9-x11, d1, d2, flags
//   Callee-saved used: none
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_lu_norm1:
    fmov d0, xzr                    // n = 0: 0
    mov x9, #0                      // j
Lrt_lu_norm1_col:
    cmp x9, x1
    b.hs Lrt_lu_norm1_ret
    ldr d1, [x0]                    // s = |A[0,j]|
    fabs d1, d1
    mov x10, #1                     // i
Lrt_lu_norm1_row:
    cmp x10, x1
    b.hs Lrt_lu_norm1_take
    ldr d2, [x0, x10, lsl #3]
    fabs d2, d2
    fadd d1, d1, d2                 // s + |A[i,j]|, row order
    add x10, x10, #1
    b Lrt_lu_norm1_row
Lrt_lu_norm1_take:
    add x0, x0, x1, lsl #3          // the next column
    cbz x9, Lrt_lu_norm1_set        // s_0 is taken as it is
    fcmp d1, d0
    b.gt Lrt_lu_norm1_set           // s_j > norm
    fcmp d1, d1
    b.vc Lrt_lu_norm1_next          // s_j is a number not above the norm
Lrt_lu_norm1_set:
    fmov d0, d1
Lrt_lu_norm1_next:
    add x9, x9, #1
    b Lrt_lu_norm1_col
Lrt_lu_norm1_ret:
    ret

// ---------------------------------------------------------------------
// Lrt_lu_cpupper -- copy the upper triangle (i <= j) of an n x n matrix
//   (column stride n) into another (column stride n); the destination's
//   strict lower triangle is not written and the source's is not read.
//   Inputs  : x0 = destination, x1 = source, x2 = n
//   Outputs : none
//   Clobbers: x0, x1, x9-x11, d0, flags
//   Callee-saved used: none
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_lu_cpupper:
    lsl x9, x2, #3                  // the column stride in bytes
    mov x10, #0                     // j
Lrt_lu_cpupper_col:
    cmp x10, x2
    b.hs Lrt_lu_cpupper_ret
    mov x11, #0                     // i = 0 .. j
Lrt_lu_cpupper_row:
    ldr d0, [x1, x11, lsl #3]
    str d0, [x0, x11, lsl #3]
    add x11, x11, #1
    cmp x11, x10
    b.ls Lrt_lu_cpupper_row
    add x0, x0, x9                  // the next columns
    add x1, x1, x9
    add x10, x10, #1
    b Lrt_lu_cpupper_col
Lrt_lu_cpupper_ret:
    ret

// ---------------------------------------------------------------------
// Lrt_lu_zlower -- set the strict lower triangle (i > j) of an n x n
//   matrix with column stride ld to +0.
//   Inputs  : x0 = &a[0,0], x1 = n, x2 = ld
//   Outputs : none
//   Clobbers: x0, x9-x11, flags
//   Callee-saved used: none
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_lu_zlower:
    lsl x9, x2, #3                  // the column stride in bytes
    mov x10, #0                     // j
Lrt_lu_zlower_col:
    add x11, x10, #1                // i = j + 1
    cmp x11, x1
    b.hs Lrt_lu_zlower_ret          // nothing below the diagonal from here on
Lrt_lu_zlower_row:
    str xzr, [x0, x11, lsl #3]      // +0
    add x11, x11, #1
    cmp x11, x1
    b.lo Lrt_lu_zlower_row
    add x0, x0, x9
    add x10, x10, #1
    b Lrt_lu_zlower_col
Lrt_lu_zlower_ret:
    ret

// ---------------------------------------------------------------------
// Lrt_lu_wcopy -- W = (a[j0..j1, j1..n])': W[i + t * (n - j1)] =
//   a[j0 + t, j1 + i] for t < j1 - j0, i < n - j1 (exact moves; the
//   transposed panel of CHOL step 3 and CHOL_SOLVE's forward update).
//   Inputs  : x0 = &a[0,0], x1 = ld, x2 = j0, x3 = j1 (< n), x4 = n,
//             x5 = W
//   Outputs : none
//   Clobbers: x5, x9-x15, d0, flags
//   Callee-saved used: none
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_lu_wcopy:
    lsl x9, x1, #3                  // the column stride in bytes
    sub x10, x3, x2                 // jb: W's columns
    sub x11, x4, x3                 // n - j1: W's rows
    madd x12, x3, x9, x0            // &a[0, j1]
    add x12, x12, x2, lsl #3        // &a[j0, j1]
    mov x13, #0                     // t
Lrt_lu_wcopy_col:
    cmp x13, x10
    b.hs Lrt_lu_wcopy_ret
    mov x14, x12                    // &a[j0 + t, j1]: along row j0 + t
    mov x15, x11
Lrt_lu_wcopy_row:
    ldr d0, [x14]
    str d0, [x5], #8                // W[i, t], i ascending
    add x14, x14, x9
    subs x15, x15, #1
    b.ne Lrt_lu_wcopy_row
    add x12, x12, #8                // the next row of a
    add x13, x13, #1
    b Lrt_lu_wcopy_col
Lrt_lu_wcopy_ret:
    ret

// ---------------------------------------------------------------------
// Lrt_lu_lswp -- apply the interchanges to X: for k = 0 .. n-1, rows k
//   and piv[k] of the n x m matrix X (column stride n) are exchanged.
//   Inputs  : x0 = &X[0,0], x1 = n, x2 = m, x3 = piv (n u32)
//   Outputs : none
//   Clobbers: x9-x15, d0, d1, flags
//   Callee-saved used: none
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_lu_lswp:
    lsl x9, x1, #3                  // the column stride in bytes
    mov x10, #0                     // k
Lrt_lu_lswp_k:
    cmp x10, x1
    b.hs Lrt_lu_lswp_ret
    ldr w11, [x3, x10, lsl #2]      // p = piv[k]
    cmp x11, x10
    b.eq Lrt_lu_lswp_next           // no interchange
    add x12, x0, x10, lsl #3        // &X[k, 0]
    add x13, x0, x11, lsl #3        // &X[p, 0]
    mov x14, x2                     // columns
    cbz x14, Lrt_lu_lswp_next
Lrt_lu_lswp_col:
    ldr d0, [x12]
    ldr d1, [x13]
    str d1, [x12]                   // exact moves
    str d0, [x13]
    add x12, x12, x9
    add x13, x13, x9
    subs x14, x14, #1
    b.ne Lrt_lu_lswp_col
Lrt_lu_lswp_next:
    add x10, x10, #1
    b Lrt_lu_lswp_k
Lrt_lu_lswp_ret:
    ret

// ---------------------------------------------------------------------
// Lrt_lu_gsub -- C <- C - A B through Baysick's kernel:
//   _bsk_kern_gemm_sub(V(C), V(B), V(A)) (file header).
//   Inputs  : x0 = &C[0,0], x1 = r (>= 1), x2 = c (>= 1), x3 = k (>= 1),
//             x4 = C's column stride, x5 = &A[0,0] (r x k), x6 = A's
//             column stride, x7 = &B[0,0] (k x c), x8 = B's column stride
//             (a private convention of this file)
//   Outputs : C updated; the kernel's KS_* status is ignored (Baysick's
//             IEEE rules propagate non-finite values, DESIGN.md 2.13.5)
//   Clobbers: what AAPCS64 allows (x0-x17, v0-v7, v16-v31, flags)
//   Callee-saved used: none
//   Frame   : 112 bytes (frame record, three MV views)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_lu_gsub:
    stp x29, x30, [sp, #-RT_LU_G_FRAME]!    // frame record
    mov x29, sp
    // V(C) = {C, c, r, ldc}: the row-major c x r transpose of C.
    str x0, [sp, #(RT_LU_G_VC + MV_DATA)]
    str x2, [sp, #(RT_LU_G_VC + MV_ROWS)]
    str x1, [sp, #(RT_LU_G_VC + MV_COLS)]
    str x4, [sp, #(RT_LU_G_VC + MV_LD)]
    // V(B) = {B, c, k, ldb}.
    str x7, [sp, #(RT_LU_G_VB + MV_DATA)]
    str x2, [sp, #(RT_LU_G_VB + MV_ROWS)]
    str x3, [sp, #(RT_LU_G_VB + MV_COLS)]
    str x8, [sp, #(RT_LU_G_VB + MV_LD)]
    // V(A) = {A, k, r, lda}.
    str x5, [sp, #(RT_LU_G_VA + MV_DATA)]
    str x3, [sp, #(RT_LU_G_VA + MV_ROWS)]
    str x1, [sp, #(RT_LU_G_VA + MV_COLS)]
    str x6, [sp, #(RT_LU_G_VA + MV_LD)]
    // C' = C' - B' A' in Baysick's row-major terms.
    add x0, sp, #RT_LU_G_VC
    add x1, sp, #RT_LU_G_VB
    add x2, sp, #RT_LU_G_VA
    bl _bsk_kern_gemm_sub
    ldp x29, x30, [sp], #RT_LU_G_FRAME
    ret

// =====================================================================
// The private routines (L-jc)
// =====================================================================

// ---------------------------------------------------------------------
// _sea_la_issym -- Decision 123's symmetric test (file header).
//   Inputs  : x0 = &a[0,0], x1 = n, x2 = ld (column stride)
//   Outputs : x0 = 1 symmetric, 0 not
//   Clobbers: x9-x13, d0, d1, flags (x1, x2 preserved)
//   Callee-saved used: none
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .private_extern _sea_la_issym
    .p2align 2
_sea_la_issym:
    lsl x13, x2, #3                 // the column stride in bytes (x2 kept)
    mov x9, #1                      // j (column 0 has no pair i < j)
Lrt_lu_issym_col:
    cmp x9, x1
    b.hs Lrt_lu_issym_yes
    madd x11, x9, x13, x0           // &a[0, j]
    add x12, x0, x9, lsl #3         // &a[j, 0]
    mov x10, #0                     // i
Lrt_lu_issym_row:
    ldr d0, [x11, x10, lsl #3]      // a[i, j]
    ldr d1, [x12]                   // a[j, i]
    fcmp d0, d1
    b.eq Lrt_lu_issym_pair          // equal (+0 == -0)
    fcmp d0, d0
    b.vc Lrt_lu_issym_no            // a[i,j] is a number and they differ
    fcmp d1, d1
    b.vc Lrt_lu_issym_no            // a[i,j] NaN, a[j,i] a number
Lrt_lu_issym_pair:
    add x12, x12, x13               // a[j, i + 1]
    add x10, x10, #1
    cmp x10, x9
    b.lo Lrt_lu_issym_row
    add x9, x9, #1
    b Lrt_lu_issym_col
Lrt_lu_issym_yes:
    mov x0, #1
    ret
Lrt_lu_issym_no:
    mov x0, #0
    ret

// ---------------------------------------------------------------------
// _sea_la_potrf -- CHOL's algorithm (DESIGN.md 2.13.6 "CHOL"; LAPACK
//   dpotrf 'U', right-looking with dpotf2 panels), in place.
//   Inputs  : x0 = &a[0,0], x1 = n, x2 = ld (>= n), x3 = W (scratch of
//             n * SEA_LA_NB doubles, touched only when n > SEA_LA_NB)
//   Outputs : x0 = 0 (R complete, strict lower triangle +0), else 1 +
//             the index of the first pivot d with d > 0 false
//   Clobbers: x0-x17, v0-v7, v16-v31, flags
//   Callee-saved used: x19 = a, x20 = n, x21 = ld, x22 = W, x23 = j0,
//             x24 = j1, x25 = ld in bytes, x26 = j, x27 = k0 or c,
//             x28 = k1
//   Frame   : 96 bytes (frame record, x19-x28)
// ---------------------------------------------------------------------
    .private_extern _sea_la_potrf
    .p2align 2
_sea_la_potrf:
    stp x29, x30, [sp, #-RT_LU_RFRAME]!     // frame record
    mov x29, sp
    RT_LU_SAVE
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    lsl x25, x21, #3                // the column stride in bytes
    // The strict lower triangle +0: the trailing updates write below the
    // diagonal inside diagonal blocks, so it must hold defined values.
    bl Lrt_lu_zlower                // (a, n, ld) still in x0-x2
    mov x23, #0                     // j0

Lrt_lu_potrf_panel:
    cmp x23, x20
    b.hs Lrt_lu_potrf_done
    RT_LU_PEND x24, x23, x20        // j1

    // 1. The diagonal block, j = j0 .. j1-1.
    mov x26, x23
Lrt_lu_potrf_dj:
    cmp x26, x24
    b.hs Lrt_lu_potrf_brow
    madd x9, x26, x25, x19          // &R[0, j]
    ldr d0, [x9, x26, lsl #3]       // d = R[j,j]
    mov x10, x23                    // kk = j0 .. j-1
Lrt_lu_potrf_dk:
    cmp x10, x26
    b.hs Lrt_lu_potrf_dtest
    ldr d1, [x9, x10, lsl #3]
    fmul d1, d1, d1                 // R[kk,j] * R[kk,j]
    fsub d0, d0, d1
    add x10, x10, #1
    b Lrt_lu_potrf_dk
Lrt_lu_potrf_dtest:
    fcmp d0, #0.0
    b.gt Lrt_lu_potrf_dok           // d > 0 (false for a NaN)
    add x0, x26, #1                 // 1 + the failing pivot's index
    b Lrt_lu_potrf_ret
Lrt_lu_potrf_dok:
    fsqrt d0, d0
    str d0, [x9, x26, lsl #3]       // R[j,j] = sqrt(d)
    add x27, x26, #1                // c = j+1 .. j1-1
Lrt_lu_potrf_dc:
    cmp x27, x24
    b.hs Lrt_lu_potrf_dnext
    madd x12, x27, x25, x19         // &R[0, c]
    ldr d2, [x12, x26, lsl #3]      // s = R[j,c]
    mov x10, x23
Lrt_lu_potrf_dck:
    cmp x10, x26
    b.hs Lrt_lu_potrf_dcdiv
    ldr d1, [x9, x10, lsl #3]       // R[kk,j]
    ldr d3, [x12, x10, lsl #3]      // R[kk,c]
    fmul d1, d1, d3
    fsub d2, d2, d1
    add x10, x10, #1
    b Lrt_lu_potrf_dck
Lrt_lu_potrf_dcdiv:
    fdiv d2, d2, d0                 // s / R[j,j]
    str d2, [x12, x26, lsl #3]
    add x27, x27, #1
    b Lrt_lu_potrf_dc
Lrt_lu_potrf_dnext:
    add x26, x26, #1
    b Lrt_lu_potrf_dj

    // 2. The block row: c = j1 .. n-1, j = j0 .. j1-1.
Lrt_lu_potrf_brow:
    mov x27, x24
Lrt_lu_potrf_bc:
    cmp x27, x20
    b.hs Lrt_lu_potrf_trail
    madd x12, x27, x25, x19         // &R[0, c]
    mov x26, x23
Lrt_lu_potrf_bj:
    cmp x26, x24
    b.hs Lrt_lu_potrf_bcnext
    madd x9, x26, x25, x19          // &R[0, j]
    ldr d2, [x12, x26, lsl #3]      // s = R[j,c]
    mov x10, x23
Lrt_lu_potrf_bk:
    cmp x10, x26
    b.hs Lrt_lu_potrf_bdiv
    ldr d1, [x9, x10, lsl #3]
    ldr d3, [x12, x10, lsl #3]
    fmul d1, d1, d3                 // R[kk,j] * R[kk,c]
    fsub d2, d2, d1
    add x10, x10, #1
    b Lrt_lu_potrf_bk
Lrt_lu_potrf_bdiv:
    ldr d0, [x9, x26, lsl #3]       // R[j,j]
    fdiv d2, d2, d0
    str d2, [x12, x26, lsl #3]
    add x26, x26, #1
    b Lrt_lu_potrf_bj
Lrt_lu_potrf_bcnext:
    add x27, x27, #1
    b Lrt_lu_potrf_bc

    // 3. The trailing update of the upper triangle, when j1 < n:
    // W = (R[j0..j1, j1..n])', then for each panel K = [k0, k1), k0 >= j1:
    // R[j1..k1, k0..k1] -= W[0..k1-j1, :] R[j0..j1, k0..k1].
Lrt_lu_potrf_trail:
    cmp x24, x20
    b.hs Lrt_lu_potrf_pnext
    mov x0, x19
    mov x1, x21
    mov x2, x23
    mov x3, x24
    mov x4, x20
    mov x5, x22
    bl Lrt_lu_wcopy
    mov x27, x24                    // k0
Lrt_lu_potrf_tk:
    cmp x27, x20
    b.hs Lrt_lu_potrf_pnext
    RT_LU_PEND x28, x27, x20        // k1
    madd x0, x27, x25, x19
    add x0, x0, x24, lsl #3         // C = &R[j1, k0]
    sub x1, x28, x24                // r = k1 - j1
    sub x2, x28, x27                // c = k1 - k0
    sub x3, x24, x23                // k = jb
    mov x4, x21                     // C's stride ld
    mov x5, x22                     // A = W
    sub x6, x20, x24                // W's stride n - j1
    madd x7, x27, x25, x19
    add x7, x7, x23, lsl #3         // B = &R[j0, k0]
    mov x8, x21
    bl Lrt_lu_gsub
    mov x27, x28
    b Lrt_lu_potrf_tk
Lrt_lu_potrf_pnext:
    mov x23, x24
    b Lrt_lu_potrf_panel

Lrt_lu_potrf_done:
    // The parts below the diagonal the updates wrote: +0 again.
    mov x0, x19
    mov x1, x20
    mov x2, x21
    bl Lrt_lu_zlower
    mov x0, #0                      // R is complete
Lrt_lu_potrf_ret:
    RT_LU_RESTORE
    ldp x29, x30, [sp], #RT_LU_RFRAME
    ret

// =====================================================================
// LU and the triangular solves
// =====================================================================

// ---------------------------------------------------------------------
// Lrt_lu_getrf -- the blocked LU with partial pivoting of DESIGN.md
//   2.13.6 "LU" (dgetrf's right-looking structure, dgetf2 panels), in
//   place on F (column stride n).
//   Inputs  : x0 = &F[0,0], x1 = n, x2 = piv (room for n u32)
//   Outputs : x0 = the first exactly zero pivot's index, or -1; F holds
//             L (unit, below the diagonal) and U; piv the interchanges
//   Clobbers: x0-x17, v0-v7, v16-v31, flags
//   Callee-saved used: x19 = F, x20 = n, x21 = piv, x22 = n * 8,
//             x23 = j0, x24 = j1, x25 = the first zero pivot, x26 = k
//   Frame   : 96 bytes (frame record, x19-x28)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_lu_getrf:
    stp x29, x30, [sp, #-RT_LU_RFRAME]!     // frame record
    mov x29, sp
    RT_LU_SAVE
    mov x19, x0
    mov x20, x1
    mov x21, x2
    lsl x22, x20, #3                // the column stride in bytes
    mov x25, #-1                    // no zero pivot yet
    mov x23, #0                     // j0

Lrt_lu_getrf_panel:
    cmp x23, x20
    b.hs Lrt_lu_getrf_done
    RT_LU_PEND x24, x23, x20        // j1

    // 1. The panel, k = j0 .. j1-1.
    mov x26, x23
Lrt_lu_getrf_k:
    cmp x26, x24
    b.hs Lrt_lu_getrf_brow
    madd x9, x26, x22, x19          // &F[0, k]
    // The pivot: the first row of strictly largest magnitude (a NaN
    // never replaces the current candidate, L-in).
    ldr d0, [x9, x26, lsl #3]
    fabs d0, d0                     // m = |F[k,k]|
    mov x10, x26                    // p = k
    add x11, x26, #1
Lrt_lu_getrf_ps:
    cmp x11, x20
    b.hs Lrt_lu_getrf_psdone
    ldr d1, [x9, x11, lsl #3]
    fabs d1, d1
    fcmp d1, d0
    fcsel d0, d1, d0, gt            // |F[i,k]| > m (false when unordered)
    csel x10, x11, x10, gt
    add x11, x11, #1
    b Lrt_lu_getrf_ps
Lrt_lu_getrf_psdone:
    str w10, [x21, x26, lsl #2]     // piv[k] = p
    cmp x10, x26
    b.eq Lrt_lu_getrf_scale
    // Rows k and p exchanged across all n columns (exact moves).
    add x12, x19, x26, lsl #3       // &F[k, 0]
    add x13, x19, x10, lsl #3       // &F[p, 0]
    mov x14, x20
Lrt_lu_getrf_swap:
    ldr d1, [x12]
    ldr d2, [x13]
    str d2, [x12]
    str d1, [x13]
    add x12, x12, x22
    add x13, x13, x22
    subs x14, x14, #1
    b.ne Lrt_lu_getrf_swap
Lrt_lu_getrf_scale:
    ldr d0, [x9, x26, lsl #3]       // the pivot F[k,k]
    fcmp d0, #0.0
    b.eq Lrt_lu_getrf_zero          // exactly +-0 (a NaN pivot divides)
    add x11, x26, #1
Lrt_lu_getrf_div:
    cmp x11, x20
    b.hs Lrt_lu_getrf_upd
    ldr d1, [x9, x11, lsl #3]
    fdiv d1, d1, d0                 // F[i,k] / F[k,k]: a true division
    str d1, [x9, x11, lsl #3]
    add x11, x11, #1
    b Lrt_lu_getrf_div
Lrt_lu_getrf_zero:
    cmp x25, #0
    csel x25, x26, x25, lt          // the first zero pivot; the column stays
    // Then for c = k+1 .. j1-1, i = k+1 .. n-1: F[i,c] -= F[i,k] F[k,c].
Lrt_lu_getrf_upd:
    add x12, x26, #1                // c
Lrt_lu_getrf_uc:
    cmp x12, x24
    b.hs Lrt_lu_getrf_knext
    madd x13, x12, x22, x19         // &F[0, c]
    ldr d2, [x13, x26, lsl #3]      // F[k,c]
    add x11, x26, #1                // i
Lrt_lu_getrf_ui:
    cmp x11, x20
    b.hs Lrt_lu_getrf_ucnext
    ldr d1, [x9, x11, lsl #3]       // F[i,k]
    fmul d1, d1, d2
    ldr d3, [x13, x11, lsl #3]
    fsub d3, d3, d1
    str d3, [x13, x11, lsl #3]
    add x11, x11, #1
    b Lrt_lu_getrf_ui
Lrt_lu_getrf_ucnext:
    add x12, x12, #1
    b Lrt_lu_getrf_uc
Lrt_lu_getrf_knext:
    add x26, x26, #1
    b Lrt_lu_getrf_k

    // 2. The block row: c = j1 .. n-1, k = j0 .. j1-1, i = k+1 .. j1-1:
    // F[i,c] -= F[i,k] F[k,c] (L11^-1 applied, L11 unit lower).
Lrt_lu_getrf_brow:
    mov x12, x24                    // c
Lrt_lu_getrf_bc:
    cmp x12, x20
    b.hs Lrt_lu_getrf_trail
    madd x13, x12, x22, x19         // &F[0, c]
    mov x14, x23                    // k
Lrt_lu_getrf_bk:
    cmp x14, x24
    b.hs Lrt_lu_getrf_bcnext
    madd x9, x14, x22, x19          // &F[0, k]
    ldr d2, [x13, x14, lsl #3]      // F[k,c]
    add x11, x14, #1                // i
Lrt_lu_getrf_bi:
    cmp x11, x24
    b.hs Lrt_lu_getrf_bknext
    ldr d1, [x9, x11, lsl #3]       // F[i,k]
    fmul d1, d1, d2
    ldr d3, [x13, x11, lsl #3]
    fsub d3, d3, d1
    str d3, [x13, x11, lsl #3]
    add x11, x11, #1
    b Lrt_lu_getrf_bi
Lrt_lu_getrf_bknext:
    add x14, x14, #1
    b Lrt_lu_getrf_bk
Lrt_lu_getrf_bcnext:
    add x12, x12, #1
    b Lrt_lu_getrf_bc

    // 3. The trailing update, when j1 < n:
    // F[j1..n, j1..n] -= F[j1..n, j0..j1] F[j0..j1, j1..n], all ld n.
Lrt_lu_getrf_trail:
    cmp x24, x20
    b.hs Lrt_lu_getrf_pnext
    madd x0, x24, x22, x19
    add x0, x0, x24, lsl #3         // C = &F[j1, j1]
    sub x1, x20, x24                // r = n - j1
    mov x2, x1                      // c = n - j1
    sub x3, x24, x23                // k = jb
    mov x4, x20
    madd x5, x23, x22, x19
    add x5, x5, x24, lsl #3         // A = &F[j1, j0]
    mov x6, x20
    madd x7, x24, x22, x19
    add x7, x7, x23, lsl #3         // B = &F[j0, j1]
    mov x8, x20
    bl Lrt_lu_gsub
Lrt_lu_getrf_pnext:
    mov x23, x24
    b Lrt_lu_getrf_panel

Lrt_lu_getrf_done:
    mov x0, x25
    RT_LU_RESTORE
    ldp x29, x30, [sp], #RT_LU_RFRAME
    ret

// ---------------------------------------------------------------------
// Lrt_lu_fwdl -- X <- L^-1 X with the unit lower L of F, panels
//   ascending (DESIGN.md 2.13.6 "Triangular solves", step 2): for each
//   column c, k in J, i = k+1 .. j1-1: X[i,c] -= F[i,k] X[k,c]; then,
//   when j1 < n, X[j1..n, :] -= F[j1..n, j0..j1] X[j0..j1, :].
//   Inputs  : x0 = &F[0,0], x1 = n (>= 1), x2 = &X[0,0], x3 = m (>= 1);
//             both with column stride n
//   Outputs : X updated
//   Clobbers: x0-x17, v0-v7, v16-v31, flags
//   Callee-saved used: x19 = F, x20 = n, x21 = X, x22 = m, x23 = j0,
//             x24 = j1, x25 = n * 8, x26 = c
//   Frame   : 96 bytes (frame record, x19-x28)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_lu_fwdl:
    stp x29, x30, [sp, #-RT_LU_RFRAME]!     // frame record
    mov x29, sp
    RT_LU_SAVE
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    lsl x25, x20, #3                // the column stride in bytes
    mov x23, #0                     // j0
Lrt_lu_fwdl_panel:
    cmp x23, x20
    b.hs Lrt_lu_fwdl_ret
    RT_LU_PEND x24, x23, x20        // j1
    mov x26, #0                     // c
Lrt_lu_fwdl_c:
    cmp x26, x22
    b.hs Lrt_lu_fwdl_trail
    madd x12, x26, x25, x21         // &X[0, c]
    mov x14, x23                    // k
Lrt_lu_fwdl_k:
    cmp x14, x24
    b.hs Lrt_lu_fwdl_cnext
    madd x9, x14, x25, x19          // &F[0, k]
    ldr d2, [x12, x14, lsl #3]      // X[k,c]
    add x11, x14, #1                // i
Lrt_lu_fwdl_i:
    cmp x11, x24
    b.hs Lrt_lu_fwdl_knext
    ldr d1, [x9, x11, lsl #3]       // F[i,k]
    fmul d1, d1, d2
    ldr d3, [x12, x11, lsl #3]
    fsub d3, d3, d1
    str d3, [x12, x11, lsl #3]
    add x11, x11, #1
    b Lrt_lu_fwdl_i
Lrt_lu_fwdl_knext:
    add x14, x14, #1
    b Lrt_lu_fwdl_k
Lrt_lu_fwdl_cnext:
    add x26, x26, #1
    b Lrt_lu_fwdl_c
Lrt_lu_fwdl_trail:
    cmp x24, x20
    b.hs Lrt_lu_fwdl_pnext
    add x0, x21, x24, lsl #3        // C = &X[j1, 0]
    sub x1, x20, x24                // r = n - j1
    mov x2, x22                     // c = m
    sub x3, x24, x23                // k = jb
    mov x4, x20
    madd x5, x23, x25, x19
    add x5, x5, x24, lsl #3         // A = &F[j1, j0]
    mov x6, x20
    add x7, x21, x23, lsl #3        // B = &X[j0, 0]
    mov x8, x20
    bl Lrt_lu_gsub
Lrt_lu_fwdl_pnext:
    mov x23, x24
    b Lrt_lu_fwdl_panel
Lrt_lu_fwdl_ret:
    RT_LU_RESTORE
    ldp x29, x30, [sp], #RT_LU_RFRAME
    ret

// ---------------------------------------------------------------------
// Lrt_lu_bwdu -- X <- U^-1 X with the upper triangle U of F (an Lu's U
//   or a Chol's R), panels descending (DESIGN.md 2.13.6 step 3, and
//   CHOL_SOLVE's backward half): for each column c, k = j1-1 down to j0:
//   X[k,c] = X[k,c] / F[k,k], then X[i,c] -= F[i,k] X[k,c] for i = j0 ..
//   k-1; then, when j0 > 0, X[0..j0, :] -= F[0..j0, j0..j1] X[j0..j1, :].
//   Inputs  : x0 = &F[0,0], x1 = n (>= 1), x2 = &X[0,0], x3 = m (>= 1);
//             both with column stride n
//   Outputs : X updated
//   Clobbers: x0-x17, v0-v7, v16-v31, flags
//   Callee-saved used: x19 = F, x20 = n, x21 = X, x22 = m, x23 = j0,
//             x24 = j1, x25 = n * 8, x26 = c
//   Frame   : 96 bytes (frame record, x19-x28)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_lu_bwdu:
    stp x29, x30, [sp, #-RT_LU_RFRAME]!     // frame record
    mov x29, sp
    RT_LU_SAVE
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    lsl x25, x20, #3                // the column stride in bytes
    // The last panel starts at ((n - 1) / NB) * NB.
    sub x9, x20, #1
    mov x10, #SEA_LA_NB
    udiv x9, x9, x10
    mul x23, x9, x10                // j0
Lrt_lu_bwdu_panel:
    RT_LU_PEND x24, x23, x20        // j1
    mov x26, #0                     // c
Lrt_lu_bwdu_c:
    cmp x26, x22
    b.hs Lrt_lu_bwdu_trail
    madd x12, x26, x25, x21         // &X[0, c]
    mov x14, x24                    // k + 1
Lrt_lu_bwdu_k:
    cmp x14, x23
    b.ls Lrt_lu_bwdu_cnext          // k + 1 = j0: the panel is done
    sub x14, x14, #1                // k
    madd x9, x14, x25, x19          // &F[0, k]
    ldr d2, [x12, x14, lsl #3]
    ldr d0, [x9, x14, lsl #3]
    fdiv d2, d2, d0                 // X[k,c] / F[k,k]
    str d2, [x12, x14, lsl #3]
    mov x11, x23                    // i = j0 .. k-1
Lrt_lu_bwdu_i:
    cmp x11, x14
    b.hs Lrt_lu_bwdu_k
    ldr d1, [x9, x11, lsl #3]       // F[i,k]
    fmul d1, d1, d2
    ldr d3, [x12, x11, lsl #3]
    fsub d3, d3, d1
    str d3, [x12, x11, lsl #3]
    add x11, x11, #1
    b Lrt_lu_bwdu_i
Lrt_lu_bwdu_cnext:
    add x26, x26, #1
    b Lrt_lu_bwdu_c
Lrt_lu_bwdu_trail:
    cbz x23, Lrt_lu_bwdu_ret        // j0 = 0: the first panel was the last
    mov x0, x21                     // C = &X[0, 0]
    mov x1, x23                     // r = j0
    mov x2, x22                     // c = m
    sub x3, x24, x23                // k = jb
    mov x4, x20
    madd x5, x23, x25, x19          // A = &F[0, j0]
    mov x6, x20
    add x7, x21, x23, lsl #3        // B = &X[j0, 0]
    mov x8, x20
    bl Lrt_lu_gsub
    sub x23, x23, #SEA_LA_NB        // the previous panel
    b Lrt_lu_bwdu_panel
Lrt_lu_bwdu_ret:
    RT_LU_RESTORE
    ldp x29, x30, [sp], #RT_LU_RFRAME
    ret

// ---------------------------------------------------------------------
// Lrt_lu_fwdr -- X <- R^-T X with a Chol's R, panels ascending
//   (DESIGN.md 2.13.6 "CHOL_SOLVE"): for each column c, j in J ascending:
//   X[j,c] = X[j,c] / R[j,j], then X[i,c] -= R[j,i] X[j,c] for i = j+1 ..
//   j1-1; then, when j1 < n, W = (R[j0..j1, j1..n])' and
//   X[j1..n, :] -= W X[j0..j1, :].
//   Inputs  : x0 = &R[0,0], x1 = n (>= 1), x2 = &X[0,0], x3 = m (>= 1)
//             (both with column stride n), x4 = W (n * SEA_LA_NB doubles;
//             touched only when n > SEA_LA_NB)
//   Outputs : X updated
//   Clobbers: x0-x17, v0-v7, v16-v31, flags
//   Callee-saved used: x19 = R, x20 = n, x21 = X, x22 = m, x23 = j0,
//             x24 = j1, x25 = n * 8, x26 = c, x27 = W
//   Frame   : 96 bytes (frame record, x19-x28)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_lu_fwdr:
    stp x29, x30, [sp, #-RT_LU_RFRAME]!     // frame record
    mov x29, sp
    RT_LU_SAVE
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x27, x4
    lsl x25, x20, #3                // the column stride in bytes
    mov x23, #0                     // j0
Lrt_lu_fwdr_panel:
    cmp x23, x20
    b.hs Lrt_lu_fwdr_ret
    RT_LU_PEND x24, x23, x20        // j1
    mov x26, #0                     // c
Lrt_lu_fwdr_c:
    cmp x26, x22
    b.hs Lrt_lu_fwdr_trail
    madd x12, x26, x25, x21         // &X[0, c]
    mov x14, x23                    // j
Lrt_lu_fwdr_j:
    cmp x14, x24
    b.hs Lrt_lu_fwdr_cnext
    madd x9, x14, x25, x19          // &R[0, j]
    ldr d2, [x12, x14, lsl #3]
    ldr d0, [x9, x14, lsl #3]
    fdiv d2, d2, d0                 // X[j,c] / R[j,j]
    str d2, [x12, x14, lsl #3]
    add x11, x14, #1                // i
    madd x13, x11, x25, x19         // &R[0, i]
    add x13, x13, x14, lsl #3       // &R[j, i]: along row j
Lrt_lu_fwdr_i:
    cmp x11, x24
    b.hs Lrt_lu_fwdr_jnext
    ldr d1, [x13]                   // R[j,i]
    fmul d1, d1, d2
    ldr d3, [x12, x11, lsl #3]
    fsub d3, d3, d1
    str d3, [x12, x11, lsl #3]
    add x13, x13, x25
    add x11, x11, #1
    b Lrt_lu_fwdr_i
Lrt_lu_fwdr_jnext:
    add x14, x14, #1
    b Lrt_lu_fwdr_j
Lrt_lu_fwdr_cnext:
    add x26, x26, #1
    b Lrt_lu_fwdr_c
Lrt_lu_fwdr_trail:
    cmp x24, x20
    b.hs Lrt_lu_fwdr_pnext
    mov x0, x19
    mov x1, x20
    mov x2, x23
    mov x3, x24
    mov x4, x20
    mov x5, x27
    bl Lrt_lu_wcopy                 // W = (R[j0..j1, j1..n])'
    add x0, x21, x24, lsl #3        // C = &X[j1, 0]
    sub x1, x20, x24                // r = n - j1
    mov x2, x22                     // c = m
    sub x3, x24, x23                // k = jb
    mov x4, x20
    mov x5, x27                     // A = W
    sub x6, x20, x24                // W's stride n - j1
    add x7, x21, x23, lsl #3        // B = &X[j0, 0]
    mov x8, x20
    bl Lrt_lu_gsub
Lrt_lu_fwdr_pnext:
    mov x23, x24
    b Lrt_lu_fwdr_panel
Lrt_lu_fwdr_ret:
    RT_LU_RESTORE
    ldp x29, x30, [sp], #RT_LU_RFRAME
    ret

// =====================================================================
// The entries
// =====================================================================

// ---------------------------------------------------------------------
// _sea_lu -- the entry LU.
//   Inputs  : x0 = A (a dynamic f64 matrix), x1 = site
//   Outputs : x0 = a new Lu handle (count 1, counted in _sea_live)
//   Clobbers: x0-x17, v0-v7, v16-v31, flags
//   Callee-saved used: x19 = A, x20 = site, x21 = n, x22 = the handle
//   Frame   : 128 bytes (frame record, x19-x28, four error slots)
// ---------------------------------------------------------------------
    .globl _sea_lu
    .p2align 2
_sea_lu:
    stp x29, x30, [sp, #-RT_LU_FRAME]!      // frame record
    mov x29, sp
    RT_LU_SAVE
    mov x19, x0
    mov x20, x1
    ldr x21, [x19, #SEA_ARR_ROWS]   // n
    ldr x9, [x19, #SEA_ARR_COLS]
    cmp x9, x21
    b.ne Lrt_lu_lu_square
    // The handle: the fields, n x n doubles, n u32 pivots.
    mul x10, x21, x21
    lsl x10, x10, #3
    add x10, x10, x21, lsl #2
    add x0, x10, #RT_LU_H_F
    mov x1, x20
    bl _sea_alloc
    mov x22, x0
    mov x9, #1
    str x9, [x22, #SEA_OBJ_RC]      // count 1
    str xzr, [x22, #SEA_OBJ_TAG]    // the tag byte and bytes 9 .. 15: 0
    mov w9, #SEA_TAG_LU
    strb w9, [x22, #SEA_OBJ_TAG]
    str x21, [x22, #RT_LU_H_N]
    str xzr, [x22, #RT_LU_H_Z0]
    str xzr, [x22, #(RT_LU_H_Z0 + 8)]
    str xzr, [x22, #(RT_LU_H_Z0 + 16)]
    // ||A||_1 of the input.
    ldr x0, [x19, #SEA_ARR_DATA]
    mov x1, x21
    bl Lrt_lu_norm1
    str d0, [x22, #RT_LU_H_ANORM]
    // F = A, then the factorization in place.
    add x0, x22, #RT_LU_H_F
    ldr x1, [x19, #SEA_ARR_DATA]
    mul x2, x21, x21
    lsl x2, x2, #3
    bl _memcpy
    add x0, x22, #RT_LU_H_F
    mov x1, x21
    mul x9, x21, x21
    add x2, x0, x9, lsl #3          // the pivots after the factor
    bl Lrt_lu_getrf
    str x0, [x22, #RT_LU_H_ZP]      // the first zero pivot, or -1
    RT_LU_COUNT
    mov x0, x22
    RT_LU_RESTORE
    ldp x29, x30, [sp], #RT_LU_FRAME
    ret
Lrt_lu_lu_square:
    // NOT_SQUARE: A's shape rows x cols.
    stp x21, x9, [sp, #RT_LU_SLOTS]
    mov x0, #SEA_E_NOT_SQUARE
    mov x1, x20
    add x2, sp, #RT_LU_SLOTS
    bl _sea_err                     // noreturn

// ---------------------------------------------------------------------
// _sea_chol -- the entry CHOL.
//   Inputs  : x0 = A (a dynamic f64 matrix), x1 = site
//   Outputs : x0 = a new Chol handle (count 1, counted in _sea_live)
//   Clobbers: x0-x17, v0-v7, v16-v31, flags
//   Callee-saved used: x19 = A, x20 = site, x21 = n, x22 = the handle,
//             x23 = W or 0, x24 = the handle's bytes, x25 = potrf's status
//   Frame   : 128 bytes (frame record, x19-x28, four error slots)
// ---------------------------------------------------------------------
    .globl _sea_chol
    .p2align 2
_sea_chol:
    stp x29, x30, [sp, #-RT_LU_FRAME]!      // frame record
    mov x29, sp
    RT_LU_SAVE
    mov x19, x0
    mov x20, x1
    ldr x21, [x19, #SEA_ARR_ROWS]   // n
    ldr x9, [x19, #SEA_ARR_COLS]
    cmp x9, x21
    b.ne Lrt_lu_chol_square
    // The handle: the fields and n x n doubles.
    mul x24, x21, x21
    lsl x24, x24, #3
    add x24, x24, #RT_LU_H_F
    mov x0, x24
    mov x1, x20
    bl _sea_alloc
    mov x22, x0
    mov x9, #1
    str x9, [x22, #SEA_OBJ_RC]      // count 1
    str xzr, [x22, #SEA_OBJ_TAG]    // the tag byte and bytes 9 .. 15: 0
    mov w9, #SEA_TAG_CHOL
    strb w9, [x22, #SEA_OBJ_TAG]
    str x21, [x22, #RT_LU_H_N]
    str xzr, [x22, #RT_LU_H_ANORM]  // no norm in a Chol: 0
    mov x9, #-1
    str x9, [x22, #RT_LU_H_ZP]      // no zero pivot
    str xzr, [x22, #RT_LU_H_Z0]
    str xzr, [x22, #(RT_LU_H_Z0 + 8)]
    str xzr, [x22, #(RT_LU_H_Z0 + 16)]
    // R = the upper triangle of A (the strict lower one is never read).
    add x0, x22, #RT_LU_H_F
    ldr x1, [x19, #SEA_ARR_DATA]
    mov x2, x21
    bl Lrt_lu_cpupper
    // W, after the handle, only when there is a trailing update.
    mov x23, #0
    cmp x21, #SEA_LA_NB
    b.ls 1f
    mov x0, #(8 * SEA_LA_NB)
    mul x0, x0, x21
    mov x1, x20
    bl _sea_alloc
    mov x23, x0
1:  add x0, x22, #RT_LU_H_F
    mov x1, x21
    mov x2, x21
    mov x3, x23
    bl _sea_la_potrf
    mov x25, x0
    cbz x23, 2f
    mov x0, x23                     // W back
    mov x1, #(8 * SEA_LA_NB)
    mul x1, x1, x21
    bl _sea_free_block
2:  cbnz x25, Lrt_lu_chol_posdef
    RT_LU_COUNT
    mov x0, x22
    RT_LU_RESTORE
    ldp x29, x30, [sp], #RT_LU_FRAME
    ret
Lrt_lu_chol_posdef:
    // The handle was never counted: its block goes back as it is.
    mov x0, x22
    mov x1, x24
    bl _sea_free_block
    mov x0, #SEA_E_NOT_POSDEF
    mov x1, x20
    mov x2, #0                      // no argument slots
    bl _sea_err                     // noreturn
Lrt_lu_chol_square:
    stp x21, x9, [sp, #RT_LU_SLOTS] // A's shape
    mov x0, #SEA_E_NOT_SQUARE
    mov x1, x20
    add x2, sp, #RT_LU_SLOTS
    bl _sea_err                     // noreturn

// ---------------------------------------------------------------------
// Lrt_lu_shape -- SHAPE_MISMATCH of a solve: n x n, then B's shape.
//   Inputs  : x0 = n, x1 = B, x2 = site, x3 = the slots (32 bytes)
//   Outputs : none (noreturn)
//   Clobbers: everything _sea_err may
//   Callee-saved used: none
//   Frame   : none (a tail call of _sea_err)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_lu_shape:
    stp x0, x0, [x3]                // n x n
    ldr x9, [x1, #SEA_ARR_ROWS]
    ldr x10, [x1, #SEA_ARR_COLS]
    ldrb w11, [x1, #SEA_ARR_RANK]
    mov x12, #SEA_SHAPE_VEC
    cmp w11, #1
    csel x10, x12, x10, eq          // a vector: its length alone
    stp x9, x10, [x3, #(2 * SEA_SLOT_SIZE)]
    mov x0, #SEA_E_SHAPE_MISMATCH
    mov x1, x2
    mov x2, x3
    b _sea_err                      // noreturn

// ---------------------------------------------------------------------
// Lrt_lu_newx -- the result of a solve: a new array of B's rank and
//   shape (sea_arr_new_u), and, when it has elements, a copy of B in it.
//   Inputs  : x0 = B, x1 = site
//   Outputs : x0 = X
//   Clobbers: x0-x17, v0-v7, v16-v31, flags
//   Callee-saved used: x19 = B, x20 = X
//   Frame   : 32 bytes (frame record, x19, x20)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_lu_newx:
    stp x29, x30, [sp, #-32]!       // frame record
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    mov x4, x1                      // site
    mov x0, #SEA_EK_F64
    ldrb w1, [x19, #SEA_ARR_RANK]
    ldr x2, [x19, #SEA_ARR_ROWS]
    ldr x3, [x19, #SEA_ARR_COLS]
    bl _sea_arr_new_u
    mov x20, x0
    ldr x9, [x19, #SEA_ARR_ROWS]
    ldr x10, [x19, #SEA_ARR_COLS]
    mul x2, x9, x10
    cbz x2, 1f                      // no element: nothing to copy
    lsl x2, x2, #3
    ldr x0, [x20, #SEA_ARR_DATA]
    ldr x1, [x19, #SEA_ARR_DATA]
    bl _memcpy                      // X = B
1:  mov x0, x20
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// ---------------------------------------------------------------------
// _sea_lu_solve -- the entry LU_SOLVE.
//   Inputs  : x0 = F (an Lu), x1 = B (a vector or matrix), x2 = site
//   Outputs : x0 = X, a new array of B's rank and shape (count 1)
//   Clobbers: x0-x17, v0-v7, v16-v31, flags
//   Callee-saved used: x19 = F, x20 = B, x21 = site, x22 = n, x23 = m,
//             x24 = X
//   Frame   : 128 bytes (frame record, x19-x28, four error slots)
// ---------------------------------------------------------------------
    .globl _sea_lu_solve
    .p2align 2
_sea_lu_solve:
    stp x29, x30, [sp, #-RT_LU_FRAME]!      // frame record
    mov x29, sp
    RT_LU_SAVE
    mov x19, x0
    mov x20, x1
    mov x21, x2
    ldr x22, [x19, #RT_LU_H_N]      // n
    ldr x9, [x20, #SEA_ARR_ROWS]
    ldr x23, [x20, #SEA_ARR_COLS]   // m (1 for a vector)
    cmp x9, x22
    b.ne Lrt_lu_lus_shape
    cbz x22, 1f                     // order 0: no pivot to test
    ldr x9, [x19, #RT_LU_H_ZP]
    tbz x9, #63, Lrt_lu_lus_singular    // a recorded zero pivot
1:  mov x0, x20
    mov x1, x21
    bl Lrt_lu_newx                  // X = a copy of B
    mov x24, x0
    cbz x22, Lrt_lu_lus_ret         // n = 0 or m = 0: no arithmetic
    cbz x23, Lrt_lu_lus_ret
    // (1) the interchanges, (2) L forward, (3) U backward.
    ldr x0, [x24, #SEA_ARR_DATA]
    mov x1, x22
    mov x2, x23
    add x3, x19, #RT_LU_H_F
    mul x9, x22, x22
    add x3, x3, x9, lsl #3          // the pivots
    bl Lrt_lu_lswp
    add x0, x19, #RT_LU_H_F
    mov x1, x22
    ldr x2, [x24, #SEA_ARR_DATA]
    mov x3, x23
    bl Lrt_lu_fwdl
    add x0, x19, #RT_LU_H_F
    mov x1, x22
    ldr x2, [x24, #SEA_ARR_DATA]
    mov x3, x23
    bl Lrt_lu_bwdu
Lrt_lu_lus_ret:
    mov x0, x24
    RT_LU_RESTORE
    ldp x29, x30, [sp], #RT_LU_FRAME
    ret
Lrt_lu_lus_shape:
    mov x0, x22
    mov x1, x20
    mov x2, x21
    add x3, sp, #RT_LU_SLOTS
    bl Lrt_lu_shape                 // noreturn
Lrt_lu_lus_singular:
    mov x0, #SEA_E_SINGULAR
    mov x1, x21
    mov x2, #0                      // no argument slots
    bl _sea_err                     // noreturn

// ---------------------------------------------------------------------
// _sea_chol_solve -- the entry CHOL_SOLVE.
//   Inputs  : x0 = F (a Chol), x1 = B (a vector or matrix), x2 = site
//   Outputs : x0 = X, a new array of B's rank and shape (count 1)
//   Clobbers: x0-x17, v0-v7, v16-v31, flags
//   Callee-saved used: x19 = F, x20 = B, x21 = site, x22 = n, x23 = m,
//             x24 = X, x25 = W or 0
//   Frame   : 128 bytes (frame record, x19-x28, four error slots)
// ---------------------------------------------------------------------
    .globl _sea_chol_solve
    .p2align 2
_sea_chol_solve:
    stp x29, x30, [sp, #-RT_LU_FRAME]!      // frame record
    mov x29, sp
    RT_LU_SAVE
    mov x19, x0
    mov x20, x1
    mov x21, x2
    ldr x22, [x19, #RT_LU_H_N]      // n
    ldr x9, [x20, #SEA_ARR_ROWS]
    ldr x23, [x20, #SEA_ARR_COLS]   // m (1 for a vector)
    cmp x9, x22
    b.ne Lrt_lu_chs_shape
    mov x0, x20
    mov x1, x21
    bl Lrt_lu_newx                  // X = a copy of B
    mov x24, x0
    cbz x22, Lrt_lu_chs_ret         // n = 0 or m = 0: no arithmetic
    cbz x23, Lrt_lu_chs_ret
    // W (after the result) only when there is a trailing update.
    mov x25, #0
    cmp x22, #SEA_LA_NB
    b.ls 1f
    mov x0, #(8 * SEA_LA_NB)
    mul x0, x0, x22
    mov x1, x21
    bl _sea_alloc
    mov x25, x0
1:  add x0, x19, #RT_LU_H_F         // R' forward
    mov x1, x22
    ldr x2, [x24, #SEA_ARR_DATA]
    mov x3, x23
    mov x4, x25
    bl Lrt_lu_fwdr
    add x0, x19, #RT_LU_H_F         // R backward
    mov x1, x22
    ldr x2, [x24, #SEA_ARR_DATA]
    mov x3, x23
    bl Lrt_lu_bwdu
    cbz x25, Lrt_lu_chs_ret
    mov x0, x25                     // W back
    mov x1, #(8 * SEA_LA_NB)
    mul x1, x1, x22
    bl _sea_free_block
Lrt_lu_chs_ret:
    mov x0, x24
    RT_LU_RESTORE
    ldp x29, x30, [sp], #RT_LU_FRAME
    ret
Lrt_lu_chs_shape:
    mov x0, x22
    mov x1, x20
    mov x2, x21
    add x3, sp, #RT_LU_SLOTS
    bl Lrt_lu_shape                 // noreturn

// ---------------------------------------------------------------------
// _sea_solve -- the entry SOLVE (DESIGN.md 2.13.6 "SOLVE"). The scratch
//   block S holds A's copy (n x n, ld n), then W (n * SEA_LA_NB doubles,
//   present only when n > SEA_LA_NB), then the n u32 pivots of the LU path.
//   Inputs  : x0 = A (a dynamic f64 matrix), x1 = B, x2 = site
//   Outputs : x0 = X, a new array of B's rank and shape (count 1)
//   Clobbers: x0-x17, v0-v7, v16-v31, flags
//   Callee-saved used: x19 = A, x20 = B, x21 = site, x22 = n, x23 = m,
//             x24 = X, x25 = S, x26 = S's bytes, x27 = the path (0
//             Cholesky, 1 LU), x28 = n * n * 8
//   Frame   : 128 bytes (frame record, x19-x28, four error slots)
// ---------------------------------------------------------------------
    .globl _sea_solve
    .p2align 2
_sea_solve:
    stp x29, x30, [sp, #-RT_LU_FRAME]!      // frame record
    mov x29, sp
    RT_LU_SAVE
    mov x19, x0
    mov x20, x1
    mov x21, x2
    ldr x22, [x19, #SEA_ARR_ROWS]   // n
    ldr x9, [x19, #SEA_ARR_COLS]
    cmp x9, x22
    b.ne Lrt_lu_sol_square
    ldr x9, [x20, #SEA_ARR_ROWS]
    ldr x23, [x20, #SEA_ARR_COLS]   // m (1 for a vector)
    cmp x9, x22
    b.ne Lrt_lu_sol_shape
    mov x0, x20
    mov x1, x21
    bl Lrt_lu_newx                  // X = a copy of B (the result first)
    mov x24, x0
    cbz x22, Lrt_lu_sol_ret         // n = 0: the empty result
    // S: n*n doubles, n*NB doubles (only when n > NB), n u32.
    mul x28, x22, x22
    lsl x28, x28, #3
    RT_LU_WBYTES x9, x22
    add x26, x28, x9
    add x26, x26, x22, lsl #2
    mov x0, x26
    mov x1, x21
    bl _sea_alloc
    mov x25, x0
    // The Cholesky attempt when A is symmetric (Decision 123) and every
    // A[i,i] > 0 (a NaN fails).
    mov x27, #1
    ldr x0, [x19, #SEA_ARR_DATA]
    mov x1, x22
    mov x2, x22
    bl _sea_la_issym
    cbz x0, Lrt_lu_sol_lu
    ldr x9, [x19, #SEA_ARR_DATA]
    add x10, x22, #1
    lsl x10, x10, #3                // the diagonal's stride
    mov x11, x22
Lrt_lu_sol_diag:
    ldr d0, [x9]
    fcmp d0, #0.0
    b.gt 1f
    b Lrt_lu_sol_lu                 // not > 0
1:  add x9, x9, x10
    subs x11, x11, #1
    b.ne Lrt_lu_sol_diag
    mov x0, x25                     // CHOL's algorithm on A's upper triangle
    ldr x1, [x19, #SEA_ARR_DATA]
    mov x2, x22
    bl Lrt_lu_cpupper
    mov x0, x25
    mov x1, x22
    mov x2, x22
    add x3, x25, x28                // W
    bl _sea_la_potrf
    cbnz x0, Lrt_lu_sol_lu          // a failing pivot: LU instead (L-jb)
    mov x27, #0
    b Lrt_lu_sol_solve
Lrt_lu_sol_lu:
    // LU's algorithm on a fresh copy of A.
    mov x0, x25
    ldr x1, [x19, #SEA_ARR_DATA]
    mov x2, x28
    bl _memcpy
    mov x0, x25
    mov x1, x22
    RT_LU_WBYTES x9, x22
    add x2, x28, x9
    add x2, x25, x2                 // the pivots
    bl Lrt_lu_getrf
    tbz x0, #63, Lrt_lu_sol_singular    // an exactly zero pivot
Lrt_lu_sol_solve:
    cbz x23, Lrt_lu_sol_free        // m = 0: nothing to solve
    cbz x27, Lrt_lu_sol_chol
    ldr x0, [x24, #SEA_ARR_DATA]    // LU_SOLVE's algorithm
    mov x1, x22
    mov x2, x23
    RT_LU_WBYTES x9, x22
    add x3, x28, x9
    add x3, x25, x3                 // the pivots
    bl Lrt_lu_lswp
    mov x0, x25
    mov x1, x22
    ldr x2, [x24, #SEA_ARR_DATA]
    mov x3, x23
    bl Lrt_lu_fwdl
    b Lrt_lu_sol_back
Lrt_lu_sol_chol:
    mov x0, x25                     // CHOL_SOLVE's algorithm
    mov x1, x22
    ldr x2, [x24, #SEA_ARR_DATA]
    mov x3, x23
    add x4, x25, x28                // W
    bl Lrt_lu_fwdr
Lrt_lu_sol_back:
    mov x0, x25
    mov x1, x22
    ldr x2, [x24, #SEA_ARR_DATA]
    mov x3, x23
    bl Lrt_lu_bwdu
Lrt_lu_sol_free:
    mov x0, x25
    mov x1, x26
    bl _sea_free_block              // the scratch back
Lrt_lu_sol_ret:
    mov x0, x24
    RT_LU_RESTORE
    ldp x29, x30, [sp], #RT_LU_FRAME
    ret
Lrt_lu_sol_singular:
    mov x0, x25
    mov x1, x26
    bl _sea_free_block              // the scratch back first
    mov x0, x24
    bl _sea_free                    // X has count 1: freed and uncounted
    mov x0, #SEA_E_SINGULAR
    mov x1, x21
    mov x2, #0                      // no argument slots
    bl _sea_err                     // noreturn
Lrt_lu_sol_square:
    stp x22, x9, [sp, #RT_LU_SLOTS] // A's shape
    mov x0, #SEA_E_NOT_SQUARE
    mov x1, x21
    add x2, sp, #RT_LU_SLOTS
    bl _sea_err                     // noreturn
Lrt_lu_sol_shape:
    mov x0, x22
    mov x1, x20
    mov x2, x21
    add x3, sp, #RT_LU_SLOTS
    bl Lrt_lu_shape                 // noreturn

// =====================================================================
// RCOND (DESIGN.md 2.13.6 "RCOND"; LAPACK dgecon with dlacn2, the
// interchanges never applied, unscaled triangular solves). The guard
// (the user's decision, 8c, replacing "an overflow makes est non-finite,
// giving 0"): after every solve of steps 1-3, s = sum |x| in index
// order; s +Inf or NaN gives rcond 0 at once. Where a step uses sum |x|
// right after a solve, that sum is s; the sums after the L^-T U^-T
// solves serve the guard only.
// =====================================================================

// ---------------------------------------------------------------------
// Lrt_lu_rc_s1 -- x <- U^-1 L^-1 x: L forward (unit; for k ascending,
//   x[i] -= F[i,k] x[k] for i > k), then U backward (for k descending,
//   x[k] = x[k] / F[k,k], then x[i] -= F[i,k] x[k] for i < k).
//   Inputs  : x0 = &F[0,0] (column stride n), x1 = n (>= 1), x2 = x
//   Outputs : x updated
//   Clobbers: x9-x12, d1-d3, flags
//   Callee-saved used: none
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_lu_rc_s1:
    lsl x9, x1, #3                  // the column stride in bytes
    mov x10, #0                     // k
    mov x11, x0                     // &F[0, k]
Lrt_lu_rc_s1_lk:
    cmp x10, x1
    b.hs Lrt_lu_rc_s1_u
    ldr d1, [x2, x10, lsl #3]       // x[k]
    add x12, x10, #1                // i
Lrt_lu_rc_s1_li:
    cmp x12, x1
    b.hs Lrt_lu_rc_s1_lnext
    ldr d2, [x11, x12, lsl #3]      // F[i,k]
    fmul d2, d2, d1
    ldr d3, [x2, x12, lsl #3]
    fsub d3, d3, d2
    str d3, [x2, x12, lsl #3]
    add x12, x12, #1
    b Lrt_lu_rc_s1_li
Lrt_lu_rc_s1_lnext:
    add x10, x10, #1
    add x11, x11, x9
    b Lrt_lu_rc_s1_lk
Lrt_lu_rc_s1_u:
    mov x10, x1                     // k + 1
Lrt_lu_rc_s1_uk:
    cbz x10, Lrt_lu_rc_s1_ret
    sub x10, x10, #1                // k, descending
    madd x11, x10, x9, x0           // &F[0, k]
    ldr d1, [x2, x10, lsl #3]
    ldr d2, [x11, x10, lsl #3]
    fdiv d1, d1, d2                 // x[k] / F[k,k]
    str d1, [x2, x10, lsl #3]
    mov x12, #0                     // i < k
Lrt_lu_rc_s1_ui:
    cmp x12, x10
    b.hs Lrt_lu_rc_s1_uk
    ldr d2, [x11, x12, lsl #3]      // F[i,k]
    fmul d2, d2, d1
    ldr d3, [x2, x12, lsl #3]
    fsub d3, d3, d2
    str d3, [x2, x12, lsl #3]
    add x12, x12, #1
    b Lrt_lu_rc_s1_ui
Lrt_lu_rc_s1_ret:
    ret

// ---------------------------------------------------------------------
// Lrt_lu_rc_s2 -- x <- L^-T U^-T x: U' forward (for k ascending, x[k] =
//   (x[k] - F[0,k] x[0] - ... - F[k-1,k] x[k-1]) / F[k,k]), then L'
//   backward (unit; for k descending, x[k] = x[k] - F[k+1,k] x[k+1] -
//   ... - F[n-1,k] x[n-1]); the subtractions in index order.
//   Inputs  : x0 = &F[0,0] (column stride n), x1 = n (>= 1), x2 = x
//   Outputs : x updated
//   Clobbers: x9-x12, d1-d3, flags
//   Callee-saved used: none
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_lu_rc_s2:
    lsl x9, x1, #3                  // the column stride in bytes
    mov x10, #0                     // k
    mov x11, x0                     // &F[0, k]
Lrt_lu_rc_s2_uk:
    cmp x10, x1
    b.hs Lrt_lu_rc_s2_l
    ldr d1, [x2, x10, lsl #3]       // s = x[k]
    mov x12, #0                     // i < k, ascending
Lrt_lu_rc_s2_ui:
    cmp x12, x10
    b.hs Lrt_lu_rc_s2_udiv
    ldr d2, [x11, x12, lsl #3]      // F[i,k]
    ldr d3, [x2, x12, lsl #3]       // x[i]
    fmul d2, d2, d3
    fsub d1, d1, d2
    add x12, x12, #1
    b Lrt_lu_rc_s2_ui
Lrt_lu_rc_s2_udiv:
    ldr d2, [x11, x10, lsl #3]
    fdiv d1, d1, d2                 // / F[k,k]
    str d1, [x2, x10, lsl #3]
    add x10, x10, #1
    add x11, x11, x9
    b Lrt_lu_rc_s2_uk
Lrt_lu_rc_s2_l:
    mov x10, x1                     // k + 1
Lrt_lu_rc_s2_lk:
    cbz x10, Lrt_lu_rc_s2_ret
    sub x10, x10, #1                // k, descending
    madd x11, x10, x9, x0           // &F[0, k]
    ldr d1, [x2, x10, lsl #3]       // s = x[k]
    add x12, x10, #1                // i > k, ascending
Lrt_lu_rc_s2_li:
    cmp x12, x1
    b.hs Lrt_lu_rc_s2_lst
    ldr d2, [x11, x12, lsl #3]      // F[i,k]
    ldr d3, [x2, x12, lsl #3]
    fmul d2, d2, d3
    fsub d1, d1, d2
    add x12, x12, #1
    b Lrt_lu_rc_s2_li
Lrt_lu_rc_s2_lst:
    str d1, [x2, x10, lsl #3]
    b Lrt_lu_rc_s2_lk
Lrt_lu_rc_s2_ret:
    ret

// ---------------------------------------------------------------------
// Lrt_lu_rc_asum -- the sum of the magnitudes in index order (from +0).
//   Inputs  : x0 = x, x1 = n
//   Outputs : d0 = |x[0]| + |x[1]| + ...
//   Clobbers: x9, d1, flags
//   Callee-saved used: none
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_lu_rc_asum:
    fmov d0, xzr
    mov x9, #0
Lrt_lu_rc_asum_i:
    cmp x9, x1
    b.hs Lrt_lu_rc_asum_ret
    ldr d1, [x0, x9, lsl #3]
    fabs d1, d1
    fadd d0, d0, d1
    add x9, x9, #1
    b Lrt_lu_rc_asum_i
Lrt_lu_rc_asum_ret:
    ret

// ---------------------------------------------------------------------
// Lrt_lu_rc_gsum -- the guard after a solve (the user's rule replacing
//   "an overflow makes est non-finite, giving 0"): s = sum |x| in index
//   order (Lrt_lu_rc_asum) and whether it is finite.
//   Inputs  : x0 = x, x1 = n
//   Outputs : d0 = s; x0 = 1 when s is finite, 0 when it is +Inf or NaN
//   Clobbers: x9, d1, flags
//   Callee-saved used: none
//   Frame   : 16 bytes (frame record)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_lu_rc_gsum:
    stp x29, x30, [sp, #-16]!       // frame record
    mov x29, sp
    bl Lrt_lu_rc_asum
    mov x9, #0x7FF0000000000000
    fmov d1, x9
    fcmp d0, d1                     // s >= 0: finite iff s < +Inf
    cset x0, mi                     // (mi is false when unordered: NaN)
    ldp x29, x30, [sp], #16
    ret

// ---------------------------------------------------------------------
// Lrt_lu_rc_imax -- the first index of largest |x[i]| (BLAS idamax:
//   start at 0, move only to a strictly greater magnitude).
//   Inputs  : x0 = x, x1 = n (>= 1)
//   Outputs : x0 = the index
//   Clobbers: x9, x10, d0, d1, flags
//   Callee-saved used: none
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_lu_rc_imax:
    ldr d0, [x0]
    fabs d0, d0                     // the largest magnitude so far
    mov x10, #0                     // its index
    mov x9, #1
Lrt_lu_rc_imax_i:
    cmp x9, x1
    b.hs Lrt_lu_rc_imax_ret
    ldr d1, [x0, x9, lsl #3]
    fabs d1, d1
    fcmp d1, d0
    fcsel d0, d1, d0, gt            // strictly greater (never a NaN)
    csel x10, x9, x10, gt
    add x9, x9, #1
    b Lrt_lu_rc_imax_i
Lrt_lu_rc_imax_ret:
    mov x0, x10
    ret

// ---------------------------------------------------------------------
// Lrt_lu_rc_sign -- xi[i] = sgn(x[i]) and x[i] = xi[i]: +1 when x[i] >= 0
//   (so -0 gives +1), else -1 (so a NaN gives -1).
//   Inputs  : x0 = x, x1 = xi, x2 = n
//   Outputs : x and xi written
//   Clobbers: x9, d0-d2, flags
//   Callee-saved used: none
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_lu_rc_sign:
    fmov d1, #1.0
    fmov d2, #-1.0
    mov x9, #0
Lrt_lu_rc_sign_i:
    cmp x9, x2
    b.hs Lrt_lu_rc_sign_ret
    ldr d0, [x0, x9, lsl #3]
    fcmp d0, #0.0
    fcsel d0, d1, d2, ge            // ge is false when unordered
    str d0, [x1, x9, lsl #3]
    str d0, [x0, x9, lsl #3]
    add x9, x9, #1
    b Lrt_lu_rc_sign_i
Lrt_lu_rc_sign_ret:
    ret

// ---------------------------------------------------------------------
// Lrt_lu_rc_same -- whether sgn(x[i]) = xi[i] for every i.
//   Inputs  : x0 = x, x1 = xi, x2 = n
//   Outputs : x0 = 1 all equal, 0 not
//   Clobbers: x9, d0-d3, flags
//   Callee-saved used: none
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_lu_rc_same:
    fmov d1, #1.0
    fmov d2, #-1.0
    mov x9, #0
Lrt_lu_rc_same_i:
    cmp x9, x2
    b.hs Lrt_lu_rc_same_yes
    ldr d0, [x0, x9, lsl #3]
    fcmp d0, #0.0
    fcsel d0, d1, d2, ge            // sgn(x[i])
    ldr d3, [x1, x9, lsl #3]
    fcmp d0, d3
    b.ne Lrt_lu_rc_same_no
    add x9, x9, #1
    b Lrt_lu_rc_same_i
Lrt_lu_rc_same_yes:
    mov x0, #1
    ret
Lrt_lu_rc_same_no:
    mov x0, #0
    ret

// ---------------------------------------------------------------------
// _sea_rcond -- the entry RCOND.
//   Inputs  : x0 = F (an Lu), x1 = site
//   Outputs : d0 = rcond: +Inf for order 0; NaN when ||A||_1 is NaN; 0
//             for a recorded zero pivot; 0 when ||A||_1 is 0 or +Inf;
//             0 when the sum |x| after any solve of steps 1-3 is
//             +Inf or NaN (the guard); 0 when est is +Inf, NaN or 0;
//             else (1 / est) / ||A||_1 (Decision 129, L-io)
//   Clobbers: x0-x17, v0-v7, v16-v31, flags
//   Callee-saved used: x19 = F, x20 = site, x21 = n, x22 = x (scratch,
//             2n doubles), x23 = xi = x + n, x24 = j, x25 = iter,
//             x26 = jlast, x27 = &F[0,0]; d8 = ||A||_1, d9 = est,
//             d10 = estold
//   Frame   : 128 bytes (frame record, x19-x28, d8-d11)
// ---------------------------------------------------------------------
    .globl _sea_rcond
    .p2align 2
_sea_rcond:
    stp x29, x30, [sp, #-RT_LU_FRAME]!      // frame record
    mov x29, sp
    RT_LU_SAVE
    stp d8, d9, [sp, #RT_LU_SLOTS]
    stp d10, d11, [sp, #(RT_LU_SLOTS + 16)]
    mov x19, x0
    mov x20, x1
    // The special values, in Decision 129's order.
    ldr x21, [x19, #RT_LU_H_N]
    cbz x21, Lrt_lu_rc_inf          // order 0: +Inf
    ldr d8, [x19, #RT_LU_H_ANORM]
    fcmp d8, d8
    b.vs Lrt_lu_rc_nan              // ||A||_1 NaN: NaN
    ldr x9, [x19, #RT_LU_H_ZP]
    tbz x9, #63, Lrt_lu_rc_zero     // a recorded zero pivot: 0
    fcmp d8, #0.0
    b.eq Lrt_lu_rc_zero             // ||A||_1 = 0: 0
    mov x9, #0x7FF0000000000000
    fmov d0, x9
    fcmp d8, d0
    b.eq Lrt_lu_rc_zero             // ||A||_1 = +Inf: 0
    // The scratch: x and xi, n doubles each.
    lsl x0, x21, #4
    mov x1, x20
    bl _sea_alloc
    mov x22, x0
    add x23, x22, x21, lsl #3
    add x27, x19, #RT_LU_H_F

    // 1. x[i] = 1/n (one division); x <- U^-1 L^-1 x.
    ucvtf d0, x21
    fmov d1, #1.0
    fdiv d0, d1, d0
    mov x9, #0
1:  str d0, [x22, x9, lsl #3]
    add x9, x9, #1
    cmp x9, x21
    b.lo 1b
    mov x0, x27
    mov x1, x21
    mov x2, x22
    bl Lrt_lu_rc_s1
    mov x0, x22
    mov x1, x21
    bl Lrt_lu_rc_gsum
    cbz x0, Lrt_lu_rc_guard         // sum |x| not finite: 0
    fmov d9, d0                     // est = sum |x| (= |x[0]| for n = 1)
    cmp x21, #1
    b.eq Lrt_lu_rc_step4            // n = 1: step 4
    mov x0, x22
    mov x1, x23
    mov x2, x21
    bl Lrt_lu_rc_sign               // xi = sgn(x); x = xi
    mov x0, x27
    mov x1, x21
    mov x2, x22
    bl Lrt_lu_rc_s2                 // x <- L^-T U^-T xi
    mov x0, x22
    mov x1, x21
    bl Lrt_lu_rc_gsum               // the guard only
    cbz x0, Lrt_lu_rc_guard
    mov x0, x22
    mov x1, x21
    bl Lrt_lu_rc_imax
    mov x24, x0                     // j
    mov x25, #2                     // iter

    // 2. x = e_j; x <- U^-1 L^-1 x; estold = est; est = sum |x|.
Lrt_lu_rc_step2:
    mov x9, #0
3:  str xzr, [x22, x9, lsl #3]      // +0
    add x9, x9, #1
    cmp x9, x21
    b.lo 3b
    fmov d0, #1.0
    str d0, [x22, x24, lsl #3]
    mov x0, x27
    mov x1, x21
    mov x2, x22
    bl Lrt_lu_rc_s1
    fmov d10, d9                    // estold
    mov x0, x22
    mov x1, x21
    bl Lrt_lu_rc_gsum
    cbz x0, Lrt_lu_rc_guard
    fmov d9, d0                     // est
    mov x0, x22
    mov x1, x23
    mov x2, x21
    bl Lrt_lu_rc_same
    cbnz x0, Lrt_lu_rc_step3        // a repeated sign vector
    fcmp d9, d10
    b.ls Lrt_lu_rc_step3            // est <= estold (false when unordered)
    mov x0, x22
    mov x1, x23
    mov x2, x21
    bl Lrt_lu_rc_sign
    mov x0, x27
    mov x1, x21
    mov x2, x22
    bl Lrt_lu_rc_s2
    mov x0, x22
    mov x1, x21
    bl Lrt_lu_rc_gsum               // the guard only
    cbz x0, Lrt_lu_rc_guard
    mov x26, x24                    // jlast
    mov x0, x22
    mov x1, x21
    bl Lrt_lu_rc_imax
    mov x24, x0                     // j
    ldr d0, [x22, x26, lsl #3]      // x[jlast]
    ldr d1, [x22, x24, lsl #3]
    fabs d1, d1                     // |x[j]|
    fcmp d0, d1
    b.eq Lrt_lu_rc_step3            // x[jlast] = |x[j]| (false when unordered)
    cmp x25, #SEA_RCOND_ITMAX
    b.hs Lrt_lu_rc_step3
    add x25, x25, #1
    b Lrt_lu_rc_step2

    // 3. x[i] = s_i (1 + i / (n - 1)), s alternating from +1;
    // x <- U^-1 L^-1 x; t = 2 (sum |x| / (3n)); est = t if t > est.
Lrt_lu_rc_step3:
    sub x9, x21, #1
    ucvtf d2, x9                    // n - 1 (n >= 2 here)
    fmov d3, #1.0
    mov x10, #0                     // i
4:  ucvtf d0, x10
    fdiv d0, d0, d2                 // i / (n - 1)
    fadd d0, d3, d0                 // 1 + that
    fneg d1, d0
    tst x10, #1
    fcsel d0, d1, d0, ne            // odd i: the sign -1
    str d0, [x22, x10, lsl #3]
    add x10, x10, #1
    cmp x10, x21
    b.lo 4b
    mov x0, x27
    mov x1, x21
    mov x2, x22
    bl Lrt_lu_rc_s1
    mov x0, x22
    mov x1, x21
    bl Lrt_lu_rc_gsum
    cbz x0, Lrt_lu_rc_guard
    mov x9, #3
    mul x9, x9, x21
    ucvtf d1, x9                    // 3n
    fdiv d0, d0, d1
    fmov d1, #2.0
    fmul d0, d1, d0                 // t
    fcmp d0, d9
    fcsel d9, d0, d9, gt            // t > est

    // 4. The scratch back; rcond = 0 when est is +Inf, NaN or 0, else
    // (1 / est) / ||A||_1.
Lrt_lu_rc_step4:
    mov x0, x22
    lsl x1, x21, #4
    bl _sea_free_block
    fcmp d9, d9
    b.vs Lrt_lu_rc_zero             // est NaN
    fcmp d9, #0.0
    b.eq Lrt_lu_rc_zero             // est 0
    mov x9, #0x7FF0000000000000
    fmov d0, x9
    fcmp d9, d0
    b.eq Lrt_lu_rc_zero             // est +Inf
    fmov d0, #1.0
    fdiv d0, d0, d9
    fdiv d0, d0, d8
    b Lrt_lu_rc_ret
Lrt_lu_rc_guard:
    // A solve gave a non-finite sum |x|: the scratch back, rcond 0.
    mov x0, x22
    lsl x1, x21, #4
    bl _sea_free_block
    b Lrt_lu_rc_zero
Lrt_lu_rc_inf:
    mov x9, #0x7FF0000000000000
    fmov d0, x9
    b Lrt_lu_rc_ret
Lrt_lu_rc_nan:
    fmov d0, d8                     // ||A||_1 itself (a NaN)
    b Lrt_lu_rc_ret
Lrt_lu_rc_zero:
    fmov d0, xzr
Lrt_lu_rc_ret:
    ldp d10, d11, [sp, #(RT_LU_SLOTS + 16)]
    ldp d8, d9, [sp, #RT_LU_SLOTS]
    RT_LU_RESTORE
    ldp x29, x30, [sp], #RT_LU_FRAME
    ret
