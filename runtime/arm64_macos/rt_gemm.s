// =====================================================================
// sea/runtime/arm64_macos/rt_gemm.s -- the products of `@` (DESIGN.md
// 2.13.5 entries MATMUL, GEMV, VECMAT; 2.13.6 "Baysick views", "GEMV",
// "VECMAT", "MATMUL"; 2.13.2; LANGUAGE.md 6.8, 10.5, 10.8).
//
// Defines (global, rt.inc SEA_ENTRY_LIST):
//   _sea_matmul (A, B, site) -> C = A @ B, A r x k, B k x c (class R:
//               Baysick's _bsk_kern_gemm)
//   _sea_gemv   (A, x, site) -> y = A @ x, A r x k, x of k (class E)
//   _sea_vecmat (x, A, site) -> y = x @ A, x of k, A k x c (class E)
// Uses: _sea_arr_new, _sea_arr_new_u (rt_arr.s), _sea_err (rt_err.s),
//       _sea_variant (rt_kern.s; arm64-macos has the one form
//       SEA_VAR_NEON, so the kernels below are the NEON forms and the
//       cell is not consulted), Baysick's _bsk_kern_gemm.
//
// Every argument is borrowed and never written; the result is a new
// array with count 1. Operands are dynamic f64 arrays (the compiled code
// converts i64 and makes fixed-size operands dynamic, L-iq): A and B of
// rank 2, x of rank 1. Element (i, j) of an r x c matrix is at
// DATA + 8 * (i + j * r) (column-major).
//
// Checks (L-ik, L-ij): the only failure besides `out of memory` (the
// result's allocation, reported by rt_arr.s) is an inner-extent mismatch,
// _sea_err(SEA_E_SHAPE_MISMATCH, site, slots) with the two operands'
// shapes in source order as the `h` slots of DESIGN.md 4.8: rows, cols
// (SEA_SHAPE_VEC for a vector), the left operand first. It is made
// before anything is allocated, also when an operand is empty.
//
// Empty operands never reach a kernel (DESIGN.md 2.13.2, 4.3): a zero
// outer extent gives the empty result (sea_arr_new_u, no element), a
// zero inner extent the zero result of the outer shape (sea_arr_new,
// every element +0). Otherwise the result is made by sea_arr_new_u and
// every element is written by the kernel.
//
// GEMV (class E, DESIGN.md 2.13.2): y[i] = A[i,0]*x[0], then
// y[i] = y[i] + A[i,j]*x[j] for j = 1 .. k-1, each product and sum
// rounded separately (fmul then fadd, never FMA); the first term is the
// product itself, so a row of -0 products gives -0. Blocking (free,
// L-iz): panels of 8 rows in four 2-lane accumulators, column by column
// (A[i0..i0+8, j] is contiguous), then pairs of rows in one 2-lane
// accumulator, then a last row in a scalar register: the same chain per
// element in every form.
//
// VECMAT (class E, LANGUAGE.md 10.5): for each column j, the pinned
// 8-lane sum of the products x[kk]*A[kk,j] (x's element the first
// operand): accumulator a[kk mod 8], all eight starting at -0.0, in four
// 2-lane registers (lanes 0-1, 2-3, 4-5, 6-7); the k mod 8 tail lanes
// beyond k receive -0.0 in place of a product (exact: x + -0.0 = x for
// every x, L-iz), never a value read outside the vectors; the result
// ((a0 + a1) + (a2 + a3)) + ((a4 + a5) + (a6 + a7)).
//
// MATMUL (class R): C = sea_arr_new_u(f64, 2, r, c) and
// _bsk_kern_gemm(V(C), V(B), V(A)), where V(X) of a column-major r x c
// block with column stride ld is the Baysick view MV_DATA = &X[0,0],
// MV_ROWS = c, MV_COLS = r, MV_LD = ld (the row-major transpose), so the
// kernel computes C' = B' A', which is C in column-major; ld is each
// matrix's row count. Its KS_* status is ignored (Baysick's IEEE rules
// propagate non-finite values, DESIGN.md 2.13.5).
//
// ABI: AAPCS64; the entries preserve x19-x28, x29, sp, d8-d15 and FPCR
// (never written here); the kernels are leaves using only x9-x15,
// v0-v7 and v16-v23. Stack: the largest own frame is _sea_matmul's 160
// bytes (DESIGN.md 2.13.5: at most 512); below it run sea_arr_new(_u)
// and _bsk_kern_gemm, whose frames SEA_STACK_MARGIN covers.
// =====================================================================
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"
.include "runtime.inc"

// _sea_matmul's frame: the frame record, x19-x24, three MV views (the
// error slots reuse the first 32 bytes of the view area).
.equ RT_GEMM_MM_VC,     64          /* V(C) */
.equ RT_GEMM_MM_VB,     (64 + MV_SIZE)      /* V(B) */
.equ RT_GEMM_MM_VA,     (64 + 2 * MV_SIZE)  /* V(A) */
.equ RT_GEMM_MM_FRAME,  (64 + 3 * MV_SIZE)  /* 160 bytes */
// _sea_gemv's and _sea_vecmat's frame: the frame record, x19-x24, the
// four error slots.
.equ RT_GEMM_V_SLOTS,   64
.equ RT_GEMM_V_FRAME,   (64 + 4 * SEA_SLOT_SIZE)    /* 96 bytes */

.if (RT_GEMM_MM_FRAME > 512) || (RT_GEMM_V_FRAME > 512) || ((RT_GEMM_MM_FRAME % 16) != 0) || ((RT_GEMM_V_FRAME % 16) != 0)
    .error "rt_gemm: frames must be 16-byte multiples of at most 512 bytes"
.endif
.if (MV_SIZE < 4 * SEA_SLOT_SIZE)
    .error "rt_gemm: the error slots must fit in one view"
.endif

    .section __TEXT,__text,regular,pure_instructions

// ---------------------------------------------------------------------
// _sea_matmul -- the entry MATMUL.
//   Inputs  : x0 = A (r x k), x1 = B (k' x c), x2 = site
//   Outputs : x0 = C, a new r x c f64 matrix (count 1)
//   Clobbers: x0-x17, v0-v7, v16-v31, flags (and what _bsk_kern_gemm
//             may clobber under AAPCS64)
//   Callee-saved used: x19 = A, x20 = B, x21 = site, x22 = r, x23 = c,
//             x24 = k, then C
//   Frame   : 160 bytes (frame record, x19-x24, three MV views; the
//             error slots in the first view)
// ---------------------------------------------------------------------
    .globl _sea_matmul
    .p2align 2
_sea_matmul:
    stp x29, x30, [sp, #-RT_GEMM_MM_FRAME]!     // frame record
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    ldr x22, [x19, #SEA_ARR_ROWS]   // r
    ldr x24, [x19, #SEA_ARR_COLS]   // k
    ldr x23, [x20, #SEA_ARR_COLS]   // c
    ldr x9, [x20, #SEA_ARR_ROWS]    // k'
    cmp x9, x24
    b.ne Lrt_gemm_matmul_shape      // the check comes before any allocation

    // The result shape r x c; the call below fills the arguments.
    mov x0, #SEA_EK_F64
    mov x1, #2
    mov x2, x22
    mov x3, x23
    mov x4, x21
    cbz x22, Lrt_gemm_matmul_empty  // r = 0: the empty matrix
    cbz x23, Lrt_gemm_matmul_empty  // c = 0: the empty matrix
    cbz x24, Lrt_gemm_matmul_zero   // k = 0: the r x c zero matrix
    bl _sea_arr_new_u               // every element written by the kernel
    mov x24, x0                     // C (k is no longer needed: B's rows)

    // V(C) = {C.data, c, r, r}: the row-major c x r transpose of C.
    ldr x9, [x24, #SEA_ARR_DATA]
    str x9, [sp, #(RT_GEMM_MM_VC + MV_DATA)]
    str x23, [sp, #(RT_GEMM_MM_VC + MV_ROWS)]
    str x22, [sp, #(RT_GEMM_MM_VC + MV_COLS)]
    str x22, [sp, #(RT_GEMM_MM_VC + MV_LD)]
    // V(B) = {B.data, c, k, k}.
    ldr x9, [x20, #SEA_ARR_DATA]
    ldr x10, [x20, #SEA_ARR_ROWS]   // k (= k' = A's cols)
    str x9, [sp, #(RT_GEMM_MM_VB + MV_DATA)]
    str x23, [sp, #(RT_GEMM_MM_VB + MV_ROWS)]
    str x10, [sp, #(RT_GEMM_MM_VB + MV_COLS)]
    str x10, [sp, #(RT_GEMM_MM_VB + MV_LD)]
    // V(A) = {A.data, k, r, r}.
    ldr x9, [x19, #SEA_ARR_DATA]
    str x9, [sp, #(RT_GEMM_MM_VA + MV_DATA)]
    str x10, [sp, #(RT_GEMM_MM_VA + MV_ROWS)]
    str x22, [sp, #(RT_GEMM_MM_VA + MV_COLS)]
    str x22, [sp, #(RT_GEMM_MM_VA + MV_LD)]
    // C' = B' A': _bsk_kern_gemm(V(C), V(B), V(A)); the status is ignored.
    add x0, sp, #RT_GEMM_MM_VC
    add x1, sp, #RT_GEMM_MM_VB
    add x2, sp, #RT_GEMM_MM_VA
    bl _bsk_kern_gemm
    mov x0, x24
    b Lrt_gemm_matmul_done

Lrt_gemm_matmul_empty:
    bl _sea_arr_new_u               // no element to write
    b Lrt_gemm_matmul_done
Lrt_gemm_matmul_zero:
    bl _sea_arr_new                 // every element +0, no kernel call
Lrt_gemm_matmul_done:
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #RT_GEMM_MM_FRAME
    ret

Lrt_gemm_matmul_shape:
    // SHAPE_MISMATCH: A's shape r x k, then B's shape k' x c.
    stp x22, x24, [sp, #RT_GEMM_MM_VC]
    stp x9, x23, [sp, #(RT_GEMM_MM_VC + 2 * SEA_SLOT_SIZE)]
    mov x0, #SEA_E_SHAPE_MISMATCH
    mov x1, x21
    add x2, sp, #RT_GEMM_MM_VC
    bl _sea_err                     // noreturn

// ---------------------------------------------------------------------
// _sea_gemv -- the entry GEMV.
//   Inputs  : x0 = A (r x k), x1 = x (a vector of k'), x2 = site
//   Outputs : x0 = y, a new f64 vector of r (count 1)
//   Clobbers: x0-x17, v0-v7, v16-v31, flags
//   Callee-saved used: x19 = A, x20 = x, x21 = site, x22 = r, x23 = k,
//             x24 = y
//   Frame   : 96 bytes (frame record, x19-x24, four error slots)
// ---------------------------------------------------------------------
    .globl _sea_gemv
    .p2align 2
_sea_gemv:
    stp x29, x30, [sp, #-RT_GEMM_V_FRAME]!      // frame record
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    ldr x22, [x19, #SEA_ARR_ROWS]   // r
    ldr x23, [x19, #SEA_ARR_COLS]   // k
    ldr x9, [x20, #SEA_ARR_ROWS]    // k' (x's length)
    cmp x9, x23
    b.ne Lrt_gemm_gemv_shape

    // y: a vector of r; zeros (sea_arr_new) when k = 0.
    mov x0, #SEA_EK_F64
    mov x1, #1
    mov x2, x22
    mov x3, #1
    mov x4, x21
    cbz x23, Lrt_gemm_gemv_zero
    bl _sea_arr_new_u
    mov x24, x0
    cbz x22, Lrt_gemm_gemv_ret      // r = 0: the empty vector
    ldr x0, [x19, #SEA_ARR_DATA]
    ldr x1, [x20, #SEA_ARR_DATA]
    ldr x2, [x24, #SEA_ARR_DATA]
    mov x3, x22
    mov x4, x23
    bl Lrt_gemm_gemv_neon           // r >= 1, k >= 1
Lrt_gemm_gemv_ret:
    mov x0, x24
    b Lrt_gemm_gemv_done
Lrt_gemm_gemv_zero:
    bl _sea_arr_new                 // k = 0: r times +0, no kernel call
Lrt_gemm_gemv_done:
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #RT_GEMM_V_FRAME
    ret

Lrt_gemm_gemv_shape:
    // SHAPE_MISMATCH: A's shape r x k, then x's shape k' (a vector).
    stp x22, x23, [sp, #RT_GEMM_V_SLOTS]
    mov x10, #SEA_SHAPE_VEC
    stp x9, x10, [sp, #(RT_GEMM_V_SLOTS + 2 * SEA_SLOT_SIZE)]
    mov x0, #SEA_E_SHAPE_MISMATCH
    mov x1, x21
    add x2, sp, #RT_GEMM_V_SLOTS
    bl _sea_err                     // noreturn

// ---------------------------------------------------------------------
// _sea_vecmat -- the entry VECMAT.
//   Inputs  : x0 = x (a vector of k'), x1 = A (k x c), x2 = site
//   Outputs : x0 = y, a new f64 vector of c (count 1)
//   Clobbers: x0-x17, v0-v7, v16-v31, flags
//   Callee-saved used: x19 = x, x20 = A, x21 = site, x22 = k, x23 = c,
//             x24 = y
//   Frame   : 96 bytes (frame record, x19-x24, four error slots)
// ---------------------------------------------------------------------
    .globl _sea_vecmat
    .p2align 2
_sea_vecmat:
    stp x29, x30, [sp, #-RT_GEMM_V_FRAME]!      // frame record
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    ldr x22, [x20, #SEA_ARR_ROWS]   // k (A's rows)
    ldr x23, [x20, #SEA_ARR_COLS]   // c
    ldr x9, [x19, #SEA_ARR_ROWS]    // k' (x's length)
    cmp x9, x22
    b.ne Lrt_gemm_vecmat_shape

    // y: a vector of c; zeros (sea_arr_new) when k = 0.
    mov x0, #SEA_EK_F64
    mov x1, #1
    mov x2, x23
    mov x3, #1
    mov x4, x21
    cbz x22, Lrt_gemm_vecmat_zero
    bl _sea_arr_new_u
    mov x24, x0
    cbz x23, Lrt_gemm_vecmat_ret    // c = 0: the empty vector
    ldr x0, [x19, #SEA_ARR_DATA]
    ldr x1, [x20, #SEA_ARR_DATA]
    ldr x2, [x24, #SEA_ARR_DATA]
    mov x3, x22
    mov x4, x23
    bl Lrt_gemm_vecmat_neon         // k >= 1, c >= 1
Lrt_gemm_vecmat_ret:
    mov x0, x24
    b Lrt_gemm_vecmat_done
Lrt_gemm_vecmat_zero:
    bl _sea_arr_new                 // k = 0: c times +0, no kernel call
Lrt_gemm_vecmat_done:
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #RT_GEMM_V_FRAME
    ret

Lrt_gemm_vecmat_shape:
    // SHAPE_MISMATCH: x's shape k' (a vector), then A's shape k x c.
    mov x10, #SEA_SHAPE_VEC
    stp x9, x10, [sp, #RT_GEMM_V_SLOTS]
    stp x22, x23, [sp, #(RT_GEMM_V_SLOTS + 2 * SEA_SLOT_SIZE)]
    mov x0, #SEA_E_SHAPE_MISMATCH
    mov x1, x21
    add x2, sp, #RT_GEMM_V_SLOTS
    bl _sea_err                     // noreturn

// ---------------------------------------------------------------------
// Lrt_gemm_gemv_neon -- y = A x in GEMV's pinned order (file header).
//   Inputs  : x0 = &A[0,0], x1 = &x[0], x2 = &y[0], x3 = r >= 1,
//             x4 = k >= 1 (A is r x k, column stride r)
//   Outputs : y[0 .. r-1] written
//   Clobbers: x9-x15, v0-v4, v16-v19, flags
//   Callee-saved used: none
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_gemm_gemv_neon:
    lsl x9, x3, #3                  // the column stride in bytes
    mov x10, #0                     // i0: the first row of the panel

    // Panels of 8 rows: four 2-lane accumulators v16-v19.
Lrt_gemm_gemv_neon_p8:
    sub x11, x3, x10                // rows left
    cmp x11, #8
    b.lo Lrt_gemm_gemv_neon_p2
    add x12, x0, x10, lsl #3        // &A[i0, 0]
    mov x13, x1                     // &x[0]
    ld1 {v0.2d, v1.2d, v2.2d, v3.2d}, [x12]
    ld1r {v4.2d}, [x13], #8         // x[0] in both lanes
    fmul v16.2d, v0.2d, v4.2d       // y = A[i,0] * x[0]: the first term
    fmul v17.2d, v1.2d, v4.2d
    fmul v18.2d, v2.2d, v4.2d
    fmul v19.2d, v3.2d, v4.2d
    subs x14, x4, #1                // columns 1 .. k-1 left
    b.eq 2f
1:  add x12, x12, x9                // &A[i0, j]
    ld1 {v0.2d, v1.2d, v2.2d, v3.2d}, [x12]
    ld1r {v4.2d}, [x13], #8         // x[j]
    fmul v0.2d, v0.2d, v4.2d        // A[i,j] * x[j], rounded
    fmul v1.2d, v1.2d, v4.2d
    fmul v2.2d, v2.2d, v4.2d
    fmul v3.2d, v3.2d, v4.2d
    fadd v16.2d, v16.2d, v0.2d      // y + product, rounded
    fadd v17.2d, v17.2d, v1.2d
    fadd v18.2d, v18.2d, v2.2d
    fadd v19.2d, v19.2d, v3.2d
    subs x14, x14, #1
    b.ne 1b
2:  add x15, x2, x10, lsl #3        // &y[i0]
    st1 {v16.2d, v17.2d, v18.2d, v19.2d}, [x15]
    add x10, x10, #8
    b Lrt_gemm_gemv_neon_p8

    // Pairs of rows: one 2-lane accumulator, the same chain.
Lrt_gemm_gemv_neon_p2:
    cmp x11, #2
    b.lo Lrt_gemm_gemv_neon_p1
    add x12, x0, x10, lsl #3        // &A[i0, 0]
    mov x13, x1
    ld1 {v0.2d}, [x12]
    ld1r {v4.2d}, [x13], #8
    fmul v16.2d, v0.2d, v4.2d       // the first term
    subs x14, x4, #1
    b.eq 2f
1:  add x12, x12, x9
    ld1 {v0.2d}, [x12]
    ld1r {v4.2d}, [x13], #8
    fmul v0.2d, v0.2d, v4.2d
    fadd v16.2d, v16.2d, v0.2d
    subs x14, x14, #1
    b.ne 1b
2:  add x15, x2, x10, lsl #3
    st1 {v16.2d}, [x15]
    add x10, x10, #2
    sub x11, x3, x10
    b Lrt_gemm_gemv_neon_p2

    // A last single row: scalar, the same chain.
Lrt_gemm_gemv_neon_p1:
    cbz x11, Lrt_gemm_gemv_neon_ret
    add x12, x0, x10, lsl #3        // &A[r-1, 0]
    mov x13, x1
    ldr d0, [x12]
    ldr d4, [x13], #8
    fmul d16, d0, d4                // the first term
    subs x14, x4, #1
    b.eq 2f
1:  add x12, x12, x9
    ldr d0, [x12]
    ldr d4, [x13], #8
    fmul d0, d0, d4
    fadd d16, d16, d0
    subs x14, x14, #1
    b.ne 1b
2:  str d16, [x2, x10, lsl #3]
Lrt_gemm_gemv_neon_ret:
    ret

// ---------------------------------------------------------------------
// Lrt_gemm_vecmat_neon -- y = x A in VECMAT's pinned 8-lane order (file
// header).
//   Inputs  : x0 = &x[0], x1 = &A[0,0], x2 = &y[0], x3 = k >= 1,
//             x4 = c >= 1 (A is k x c, column stride k)
//   Outputs : y[0 .. c-1] written
//   Clobbers: x9-x15, v0-v7, v16-v23, flags
//   Callee-saved used: none
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_gemm_vecmat_neon:
    movi v23.2d, #0
    fneg v23.2d, v23.2d             // -0.0 in both lanes: the start and the padding
    and x9, x3, #7                  // t = k mod 8: the tail's products
    lsr x10, x3, #3                 // the number of full blocks of 8
    mov x11, x1                     // &A[0, j]: column j is contiguous
    mov x15, #0                     // j

Lrt_gemm_vecmat_neon_col:
    mov v16.16b, v23.16b            // a0 a1 = -0.0
    mov v17.16b, v23.16b            // a2 a3
    mov v18.16b, v23.16b            // a4 a5
    mov v19.16b, v23.16b            // a6 a7
    mov x12, x0                     // &x[0]
    mov x13, x10                    // full blocks left
    cbz x13, 2f
1:  ld1 {v0.2d, v1.2d, v2.2d, v3.2d}, [x12], #64    // x[kk .. kk+8]
    ld1 {v4.2d, v5.2d, v6.2d, v7.2d}, [x11], #64    // A[kk .. kk+8, j]
    fmul v0.2d, v0.2d, v4.2d        // x[kk] * A[kk,j], rounded
    fmul v1.2d, v1.2d, v5.2d
    fmul v2.2d, v2.2d, v6.2d
    fmul v3.2d, v3.2d, v7.2d
    fadd v16.2d, v16.2d, v0.2d      // a[kk mod 8] + product
    fadd v17.2d, v17.2d, v1.2d
    fadd v18.2d, v18.2d, v2.2d
    fadd v19.2d, v19.2d, v3.2d
    subs x13, x13, #1
    b.ne 1b

    // The tail: t products into the lanes 0 .. t-1, -0.0 in the others.
2:  cbz x9, 4f
    mov v0.16b, v23.16b
    mov v1.16b, v23.16b
    mov v2.16b, v23.16b
    mov v3.16b, v23.16b
    ldr d4, [x12]                   // lane 0
    ldr d5, [x11]
    fmul d4, d4, d5
    mov v0.d[0], v4.d[0]
    cmp x9, #1
    b.eq 3f
    ldr d4, [x12, #8]               // lane 1
    ldr d5, [x11, #8]
    fmul d4, d4, d5
    mov v0.d[1], v4.d[0]
    cmp x9, #2
    b.eq 3f
    ldr d4, [x12, #16]              // lane 2
    ldr d5, [x11, #16]
    fmul d4, d4, d5
    mov v1.d[0], v4.d[0]
    cmp x9, #3
    b.eq 3f
    ldr d4, [x12, #24]              // lane 3
    ldr d5, [x11, #24]
    fmul d4, d4, d5
    mov v1.d[1], v4.d[0]
    cmp x9, #4
    b.eq 3f
    ldr d4, [x12, #32]              // lane 4
    ldr d5, [x11, #32]
    fmul d4, d4, d5
    mov v2.d[0], v4.d[0]
    cmp x9, #5
    b.eq 3f
    ldr d4, [x12, #40]              // lane 5
    ldr d5, [x11, #40]
    fmul d4, d4, d5
    mov v2.d[1], v4.d[0]
    cmp x9, #6
    b.eq 3f
    ldr d4, [x12, #48]              // lane 6 (t = 7: lane 7 stays -0.0)
    ldr d5, [x11, #48]
    fmul d4, d4, d5
    mov v3.d[0], v4.d[0]
3:  fadd v16.2d, v16.2d, v0.2d      // every lane: a + product or a + -0.0
    fadd v17.2d, v17.2d, v1.2d
    fadd v18.2d, v18.2d, v2.2d
    fadd v19.2d, v19.2d, v3.2d
    add x11, x11, x9, lsl #3        // past the column's tail

    // ((a0 + a1) + (a2 + a3)) + ((a4 + a5) + (a6 + a7)).
4:  faddp d0, v16.2d                // a0 + a1
    faddp d1, v17.2d                // a2 + a3
    faddp d2, v18.2d                // a4 + a5
    faddp d3, v19.2d                // a6 + a7
    fadd d0, d0, d1
    fadd d2, d2, d3
    fadd d0, d0, d2
    str d0, [x2, x15, lsl #3]       // y[j]
    add x15, x15, #1
    cmp x15, x4
    b.lo Lrt_gemm_vecmat_neon_col
    ret
