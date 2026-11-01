# =====================================================================
# sea/runtime/x86_64_linux/rt_gemm.s -- the products of `@` (DESIGN.md
# 2.13.5 entries MATMUL, GEMV, VECMAT; 2.13.6 "Baysick views", "GEMV",
# "VECMAT", "MATMUL"; 2.13.2; LANGUAGE.md 6.8, 10.5, 10.8). The
# x86_64-linux twin of runtime/arm64_macos/rt_gemm.s.
#
# Defines (global, rt.inc SEA_ENTRY_LIST):
#   sea_matmul (A, B, site) -> C = A @ B, A r x k, B k x c (class R:
#              Baysick's bsk_kern_gemm)
#   sea_gemv   (A, x, site) -> y = A @ x, A r x k, x of k (class E)
#   sea_vecmat (x, A, site) -> y = x @ A, x of k, A k x c (class E)
# Uses: sea_arr_new, sea_arr_new_u (rt_arr.s), sea_err (rt_err.s),
#       sea_variant (rt_kern.s), Baysick's bsk_kern_gemm.
#
# Every argument is borrowed and never written; the result is a new
# array with count 1. Operands are dynamic f64 arrays (the compiled code
# converts i64 and makes fixed-size operands dynamic, L-iq): A and B of
# rank 2, x of rank 1. Element (i, j) of an r x c matrix is at
# DATA + 8 * (i + j * r) (column-major).
#
# Checks (L-ik, L-ij): the only failure besides `out of memory` (the
# result's allocation, reported by rt_arr.s) is an inner-extent mismatch,
# sea_err(SEA_E_SHAPE_MISMATCH, site, slots) with the two operands'
# shapes in source order as the `h` slots of DESIGN.md 4.8: rows, cols
# (SEA_SHAPE_VEC for a vector), the left operand first. It is made
# before anything is allocated, also when an operand is empty.
#
# Empty operands never reach a kernel (DESIGN.md 2.13.2, 4.3): a zero
# outer extent gives the empty result (sea_arr_new_u, no element), a
# zero inner extent the zero result of the outer shape (sea_arr_new,
# every element +0). Otherwise the result is made by sea_arr_new_u and
# every element is written by the kernel.
#
# Variants (L-iu): GEMV and VECMAT have an SSE2 form (sea_variant =
# SEA_VAR_SSE2) and an AVX2 form (SEA_VAR_AVX2), chosen at each call by
# reading sea_variant. Both perform, for every element, the same IEEE
# operations in the same order as each other and as the arm64 NEON form
# (class E: the same bits), with the same operand order in every
# multiply and add (no FMA, no reordered sum). The AVX2 forms end with
# vzeroupper.
#
# GEMV (class E, DESIGN.md 2.13.2): y[i] = A[i,0]*x[0], then
# y[i] = y[i] + A[i,j]*x[j] for j = 1 .. k-1, each product and sum
# rounded separately; the first term is the product itself, so a row of
# -0 products gives -0. Blocking (free, L-iz): SSE2 panels of 8 rows
# (four 2-lane accumulators), AVX2 panels of 16 rows (four 4-lane
# accumulators) then of 4 rows (one), then pairs of rows (one 2-lane
# accumulator), then a last row in a scalar register; A[i0.., j] is
# contiguous, so each panel streams the columns j = 0 .. k-1.
#
# VECMAT (class E, LANGUAGE.md 10.5): for each column j, the pinned
# 8-lane sum of the products x[kk]*A[kk,j] (x's element the first
# operand): accumulator a[kk mod 8], all eight starting at -0.0 (SSE2:
# four 2-lane registers, lanes 0-1, 2-3, 4-5, 6-7; AVX2: two 4-lane
# registers, lanes 0-3, 4-7); the k mod 8 tail lanes beyond k receive
# -0.0 in place of a product (exact: x + -0.0 = x for every x, L-iz):
# the tail's products are written into an 8-slot block of -0.0 in the
# red zone, never read outside the vectors; the result
# ((a0 + a1) + (a2 + a3)) + ((a4 + a5) + (a6 + a7)).
#
# MATMUL (class R): C = sea_arr_new_u(f64, 2, r, c) and
# bsk_kern_gemm(V(C), V(B), V(A)), where V(X) of a column-major r x c
# block with column stride ld is the Baysick view MV_DATA = &X[0,0],
# MV_ROWS = c, MV_COLS = r, MV_LD = ld (the row-major transpose), so the
# kernel computes C' = B' A', which is C in column-major; ld is each
# matrix's row count. Its KS_* status is ignored.
#
# ABI: System V AMD64; the entries preserve %rbx %rbp %r12-%r15 and
# %rsp, never change MXCSR, and leave the direction flag clear; the
# kernels are leaves using only caller-saved registers and the red zone
# (VECMAT's 64-byte tail block). Stack: the largest own frame is
# sea_matmul's 152 bytes below the return address (DESIGN.md 2.13.5:
# at most 512); below it run sea_arr_new(_u) and bsk_kern_gemm, whose
# frames SEA_STACK_MARGIN covers.
# =====================================================================
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"
.include "runtime.inc"              # Baysick's (found through -I <baysick>/include): MV_* and bsk_kern_gemm

# sea_matmul's locals (below the six pushes): three MV views, then C.
.equ RT_GEMM_MM_VC,     0           # V(C); the error slots reuse it
.equ RT_GEMM_MM_VB,     MV_SIZE     # V(B)
.equ RT_GEMM_MM_VA,     (2 * MV_SIZE)       # V(A)
.equ RT_GEMM_MM_C,      (3 * MV_SIZE)       # the result C
.equ RT_GEMM_MM_LOCALS, (3 * MV_SIZE + 8)   # 104: %rsp = 0 (mod 16)
# sea_gemv's and sea_vecmat's locals: four error slots, then y.
.equ RT_GEMM_V_SLOTS,   0
.equ RT_GEMM_V_Y,       (4 * SEA_SLOT_SIZE)
.equ RT_GEMM_V_LOCALS,  (4 * SEA_SLOT_SIZE + 8)     # 40: %rsp = 0 (mod 16)
# VECMAT's tail block in the red zone (leaf kernels only).
.equ RT_GEMM_TAIL,      -64

.if ((48 + RT_GEMM_MM_LOCALS) > 512) || ((48 + RT_GEMM_V_LOCALS) > 512) || ((RT_GEMM_MM_LOCALS % 16) != 8) || ((RT_GEMM_V_LOCALS % 16) != 8)
    .error "rt_gemm: frames must keep %rsp aligned and stay within 512 bytes"
.endif
.if (MV_SIZE < 4 * SEA_SLOT_SIZE)
    .error "rt_gemm: the error slots must fit in one view"
.endif

    .text

# ---------------------------------------------------------------------
# sea_matmul -- the entry MATMUL.
#   Inputs  : %rdi = A (r x k), %rsi = B (k' x c), %rdx = site
#   Outputs : %rax = C, a new r x c f64 matrix (count 1)
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = A, %r12 = B,
#             %r13 = site, %r14 = r, %r15 = c; %rbp the frame pointer
#   Frame   : 48 bytes (%rbp %rbx %r12-%r15) + 104 (three MV views, C;
#             the error slots in the first view) = 152 bytes
# ---------------------------------------------------------------------
    .globl sea_matmul
    .type sea_matmul, @function
    .p2align 4
sea_matmul:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15                      # %rsp = 8 (mod 16)
    subq $RT_GEMM_MM_LOCALS, %rsp   # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
    movq %rdx, %r13
    movq SEA_ARR_ROWS(%rbx), %r14   # r
    movq SEA_ARR_COLS(%r12), %r15   # c
    movq SEA_ARR_ROWS(%r12), %rax   # k'
    cmpq SEA_ARR_COLS(%rbx), %rax   # k
    jne .Lrt_gemm_matmul_shape      # the check comes before any allocation

    # The result shape r x c.
    movl $SEA_EK_F64, %edi
    movl $2, %esi
    movq %r14, %rdx
    movq %r15, %rcx
    movq %r13, %r8
    testq %r14, %r14
    jz .Lrt_gemm_matmul_empty       # r = 0: the empty matrix
    testq %r15, %r15
    jz .Lrt_gemm_matmul_empty       # c = 0: the empty matrix
    testq %rax, %rax
    jz .Lrt_gemm_matmul_zero        # k = 0: the r x c zero matrix
    call sea_arr_new_u              # every element written by the kernel
    movq %rax, RT_GEMM_MM_C(%rsp)

    # V(C) = {C.data, c, r, r}: the row-major c x r transpose of C.
    movq SEA_ARR_DATA(%rax), %rcx
    movq %rcx, (RT_GEMM_MM_VC + MV_DATA)(%rsp)
    movq %r15, (RT_GEMM_MM_VC + MV_ROWS)(%rsp)
    movq %r14, (RT_GEMM_MM_VC + MV_COLS)(%rsp)
    movq %r14, (RT_GEMM_MM_VC + MV_LD)(%rsp)
    # V(B) = {B.data, c, k, k}.
    movq SEA_ARR_DATA(%r12), %rcx
    movq SEA_ARR_ROWS(%r12), %rdx   # k
    movq %rcx, (RT_GEMM_MM_VB + MV_DATA)(%rsp)
    movq %r15, (RT_GEMM_MM_VB + MV_ROWS)(%rsp)
    movq %rdx, (RT_GEMM_MM_VB + MV_COLS)(%rsp)
    movq %rdx, (RT_GEMM_MM_VB + MV_LD)(%rsp)
    # V(A) = {A.data, k, r, r}.
    movq SEA_ARR_DATA(%rbx), %rcx
    movq %rcx, (RT_GEMM_MM_VA + MV_DATA)(%rsp)
    movq %rdx, (RT_GEMM_MM_VA + MV_ROWS)(%rsp)
    movq %r14, (RT_GEMM_MM_VA + MV_COLS)(%rsp)
    movq %r14, (RT_GEMM_MM_VA + MV_LD)(%rsp)
    # C' = B' A': bsk_kern_gemm(V(C), V(B), V(A)); the status is ignored.
    leaq RT_GEMM_MM_VC(%rsp), %rdi
    leaq RT_GEMM_MM_VB(%rsp), %rsi
    leaq RT_GEMM_MM_VA(%rsp), %rdx
    call bsk_kern_gemm
    movq RT_GEMM_MM_C(%rsp), %rax
    jmp .Lrt_gemm_matmul_done

.Lrt_gemm_matmul_empty:
    call sea_arr_new_u              # no element to write
    jmp .Lrt_gemm_matmul_done
.Lrt_gemm_matmul_zero:
    call sea_arr_new                # every element +0, no kernel call
.Lrt_gemm_matmul_done:
    addq $RT_GEMM_MM_LOCALS, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

.Lrt_gemm_matmul_shape:
    # SHAPE_MISMATCH: A's shape r x k, then B's shape k' x c.
    movq %r14, (RT_GEMM_MM_VC + 0 * SEA_SLOT_SIZE)(%rsp)
    movq SEA_ARR_COLS(%rbx), %rcx
    movq %rcx, (RT_GEMM_MM_VC + 1 * SEA_SLOT_SIZE)(%rsp)
    movq %rax, (RT_GEMM_MM_VC + 2 * SEA_SLOT_SIZE)(%rsp)
    movq %r15, (RT_GEMM_MM_VC + 3 * SEA_SLOT_SIZE)(%rsp)
    movl $SEA_E_SHAPE_MISMATCH, %edi
    movq %r13, %rsi
    leaq RT_GEMM_MM_VC(%rsp), %rdx
    call sea_err                    # noreturn
    .size sea_matmul, . - sea_matmul

# ---------------------------------------------------------------------
# sea_gemv -- the entry GEMV.
#   Inputs  : %rdi = A (r x k), %rsi = x (a vector of k'), %rdx = site
#   Outputs : %rax = y, a new f64 vector of r (count 1)
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = A, %r12 = x,
#             %r13 = site, %r14 = r, %r15 = k; %rbp the frame pointer
#   Frame   : 48 bytes (%rbp %rbx %r12-%r15) + 40 (four error slots, y)
#             = 88 bytes
# ---------------------------------------------------------------------
    .globl sea_gemv
    .type sea_gemv, @function
    .p2align 4
sea_gemv:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15                      # %rsp = 8 (mod 16)
    subq $RT_GEMM_V_LOCALS, %rsp    # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
    movq %rdx, %r13
    movq SEA_ARR_ROWS(%rbx), %r14   # r
    movq SEA_ARR_COLS(%rbx), %r15   # k
    movq SEA_ARR_ROWS(%r12), %rax   # k' (x's length)
    cmpq %r15, %rax
    jne .Lrt_gemm_gemv_shape

    # y: a vector of r; zeros (sea_arr_new) when k = 0.
    movl $SEA_EK_F64, %edi
    movl $1, %esi
    movq %r14, %rdx
    movl $1, %ecx
    movq %r13, %r8
    testq %r15, %r15
    jz .Lrt_gemm_gemv_zero
    call sea_arr_new_u
    movq %rax, RT_GEMM_V_Y(%rsp)
    testq %r14, %r14
    jz .Lrt_gemm_gemv_ret           # r = 0: the empty vector
    movq SEA_ARR_DATA(%rbx), %rdi
    movq SEA_ARR_DATA(%r12), %rsi
    movq SEA_ARR_DATA(%rax), %rdx
    movq %r14, %rcx
    movq %r15, %r8
    cmpq $SEA_VAR_AVX2, sea_variant(%rip)
    je 1f
    call .Lrt_gemm_gemv_sse2        # r >= 1, k >= 1
    jmp .Lrt_gemm_gemv_ret
1:  call .Lrt_gemm_gemv_avx2
.Lrt_gemm_gemv_ret:
    movq RT_GEMM_V_Y(%rsp), %rax
    jmp .Lrt_gemm_gemv_done
.Lrt_gemm_gemv_zero:
    call sea_arr_new                # k = 0: r times +0, no kernel call
.Lrt_gemm_gemv_done:
    addq $RT_GEMM_V_LOCALS, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

.Lrt_gemm_gemv_shape:
    # SHAPE_MISMATCH: A's shape r x k, then x's shape k' (a vector).
    movq %r14, (RT_GEMM_V_SLOTS + 0 * SEA_SLOT_SIZE)(%rsp)
    movq %r15, (RT_GEMM_V_SLOTS + 1 * SEA_SLOT_SIZE)(%rsp)
    movq %rax, (RT_GEMM_V_SLOTS + 2 * SEA_SLOT_SIZE)(%rsp)
    movq $SEA_SHAPE_VEC, (RT_GEMM_V_SLOTS + 3 * SEA_SLOT_SIZE)(%rsp)
    movl $SEA_E_SHAPE_MISMATCH, %edi
    movq %r13, %rsi
    leaq RT_GEMM_V_SLOTS(%rsp), %rdx
    call sea_err                    # noreturn
    .size sea_gemv, . - sea_gemv

# ---------------------------------------------------------------------
# sea_vecmat -- the entry VECMAT.
#   Inputs  : %rdi = x (a vector of k'), %rsi = A (k x c), %rdx = site
#   Outputs : %rax = y, a new f64 vector of c (count 1)
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = x, %r12 = A,
#             %r13 = site, %r14 = k, %r15 = c; %rbp the frame pointer
#   Frame   : 48 bytes (%rbp %rbx %r12-%r15) + 40 (four error slots, y)
#             = 88 bytes
# ---------------------------------------------------------------------
    .globl sea_vecmat
    .type sea_vecmat, @function
    .p2align 4
sea_vecmat:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15                      # %rsp = 8 (mod 16)
    subq $RT_GEMM_V_LOCALS, %rsp    # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
    movq %rdx, %r13
    movq SEA_ARR_ROWS(%r12), %r14   # k (A's rows)
    movq SEA_ARR_COLS(%r12), %r15   # c
    movq SEA_ARR_ROWS(%rbx), %rax   # k' (x's length)
    cmpq %r14, %rax
    jne .Lrt_gemm_vecmat_shape

    # y: a vector of c; zeros (sea_arr_new) when k = 0.
    movl $SEA_EK_F64, %edi
    movl $1, %esi
    movq %r15, %rdx
    movl $1, %ecx
    movq %r13, %r8
    testq %r14, %r14
    jz .Lrt_gemm_vecmat_zero
    call sea_arr_new_u
    movq %rax, RT_GEMM_V_Y(%rsp)
    testq %r15, %r15
    jz .Lrt_gemm_vecmat_ret         # c = 0: the empty vector
    movq SEA_ARR_DATA(%rbx), %rdi
    movq SEA_ARR_DATA(%r12), %rsi
    movq SEA_ARR_DATA(%rax), %rdx
    movq %r14, %rcx
    movq %r15, %r8
    cmpq $SEA_VAR_AVX2, sea_variant(%rip)
    je 1f
    call .Lrt_gemm_vecmat_sse2      # k >= 1, c >= 1
    jmp .Lrt_gemm_vecmat_ret
1:  call .Lrt_gemm_vecmat_avx2
.Lrt_gemm_vecmat_ret:
    movq RT_GEMM_V_Y(%rsp), %rax
    jmp .Lrt_gemm_vecmat_done
.Lrt_gemm_vecmat_zero:
    call sea_arr_new                # k = 0: c times +0, no kernel call
.Lrt_gemm_vecmat_done:
    addq $RT_GEMM_V_LOCALS, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

.Lrt_gemm_vecmat_shape:
    # SHAPE_MISMATCH: x's shape k' (a vector), then A's shape k x c.
    movq %rax, (RT_GEMM_V_SLOTS + 0 * SEA_SLOT_SIZE)(%rsp)
    movq $SEA_SHAPE_VEC, (RT_GEMM_V_SLOTS + 1 * SEA_SLOT_SIZE)(%rsp)
    movq %r14, (RT_GEMM_V_SLOTS + 2 * SEA_SLOT_SIZE)(%rsp)
    movq %r15, (RT_GEMM_V_SLOTS + 3 * SEA_SLOT_SIZE)(%rsp)
    movl $SEA_E_SHAPE_MISMATCH, %edi
    movq %r13, %rsi
    leaq RT_GEMM_V_SLOTS(%rsp), %rdx
    call sea_err                    # noreturn
    .size sea_vecmat, . - sea_vecmat

# ---------------------------------------------------------------------
# .Lrt_gemm_gemv_sse2 -- y = A x in GEMV's pinned order, SSE2 form.
#   Inputs  : %rdi = &A[0,0], %rsi = &x[0], %rdx = &y[0], %rcx = r >= 1,
#             %r8 = k >= 1 (A is r x k, column stride r)
#   Outputs : y[0 .. r-1] written
#   Clobbers: %rax %rcx %rdx %rdi %r8 %r9 %r11, %xmm0-%xmm8, flags
#   Callee-saved used: none
#   Frame   : none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_gemm_gemv_sse2:
    leaq (,%rcx,8), %r9             # the column stride in bytes
    leaq (%rsi,%r8,8), %r8          # x's end: the column loop's bound
    # %rcx = rows left, %rdi = &A[i0,0], %rdx = &y[i0] from here on.

    # Panels of 8 rows: four 2-lane accumulators %xmm0-%xmm3.
.Lrt_gemm_gemv_sse2_p8:
    cmpq $8, %rcx
    jb .Lrt_gemm_gemv_sse2_p2
    movq %rdi, %rax                 # &A[i0, j]
    movq %rsi, %r11                 # &x[j]
    movsd (%r11), %xmm4
    unpcklpd %xmm4, %xmm4           # x[0] in both lanes
    addq $8, %r11
    movupd (%rax), %xmm0
    mulpd %xmm4, %xmm0              # y = A[i,0] * x[0]: the first term
    movupd 16(%rax), %xmm1
    mulpd %xmm4, %xmm1
    movupd 32(%rax), %xmm2
    mulpd %xmm4, %xmm2
    movupd 48(%rax), %xmm3
    mulpd %xmm4, %xmm3
1:  cmpq %r8, %r11                  # columns 1 .. k-1
    je 2f
    addq %r9, %rax
    movsd (%r11), %xmm4
    unpcklpd %xmm4, %xmm4           # x[j]
    addq $8, %r11
    movupd (%rax), %xmm5
    mulpd %xmm4, %xmm5              # A[i,j] * x[j], rounded
    addpd %xmm5, %xmm0              # y + product, rounded
    movupd 16(%rax), %xmm6
    mulpd %xmm4, %xmm6
    addpd %xmm6, %xmm1
    movupd 32(%rax), %xmm7
    mulpd %xmm4, %xmm7
    addpd %xmm7, %xmm2
    movupd 48(%rax), %xmm8
    mulpd %xmm4, %xmm8
    addpd %xmm8, %xmm3
    jmp 1b
2:  movupd %xmm0, (%rdx)
    movupd %xmm1, 16(%rdx)
    movupd %xmm2, 32(%rdx)
    movupd %xmm3, 48(%rdx)
    addq $64, %rdi
    addq $64, %rdx
    subq $8, %rcx
    jmp .Lrt_gemm_gemv_sse2_p8

    # Pairs of rows: one 2-lane accumulator, the same chain.
.Lrt_gemm_gemv_sse2_p2:
    cmpq $2, %rcx
    jb .Lrt_gemm_gemv_sse2_p1
    movq %rdi, %rax
    movq %rsi, %r11
    movsd (%r11), %xmm4
    unpcklpd %xmm4, %xmm4
    addq $8, %r11
    movupd (%rax), %xmm0
    mulpd %xmm4, %xmm0              # the first term
1:  cmpq %r8, %r11
    je 2f
    addq %r9, %rax
    movsd (%r11), %xmm4
    unpcklpd %xmm4, %xmm4
    addq $8, %r11
    movupd (%rax), %xmm5
    mulpd %xmm4, %xmm5
    addpd %xmm5, %xmm0
    jmp 1b
2:  movupd %xmm0, (%rdx)
    addq $16, %rdi
    addq $16, %rdx
    subq $2, %rcx
    jmp .Lrt_gemm_gemv_sse2_p2

    # A last single row: scalar, the same chain.
.Lrt_gemm_gemv_sse2_p1:
    testq %rcx, %rcx
    jz 3f
    movq %rdi, %rax
    movq %rsi, %r11
    movsd (%rax), %xmm0
    mulsd (%r11), %xmm0             # the first term
    addq $8, %r11
1:  cmpq %r8, %r11
    je 2f
    addq %r9, %rax
    movsd (%rax), %xmm5
    mulsd (%r11), %xmm5
    addsd %xmm5, %xmm0
    addq $8, %r11
    jmp 1b
2:  movsd %xmm0, (%rdx)
3:  ret

# ---------------------------------------------------------------------
# .Lrt_gemm_gemv_avx2 -- y = A x in GEMV's pinned order, AVX2 form.
#   Inputs  : as .Lrt_gemm_gemv_sse2
#   Outputs : y[0 .. r-1] written
#   Clobbers: %rax %rcx %rdx %rdi %r8 %r9 %r11, %ymm0-%ymm8, flags; the
#             upper halves are zeroed on return (vzeroupper)
#   Callee-saved used: none
#   Frame   : none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_gemm_gemv_avx2:
    leaq (,%rcx,8), %r9             # the column stride in bytes
    leaq (%rsi,%r8,8), %r8          # x's end

    # Panels of 16 rows: four 4-lane accumulators %ymm0-%ymm3.
.Lrt_gemm_gemv_avx2_p16:
    cmpq $16, %rcx
    jb .Lrt_gemm_gemv_avx2_p4
    movq %rdi, %rax
    movq %rsi, %r11
    vbroadcastsd (%r11), %ymm4      # x[0] in four lanes
    addq $8, %r11
    vmovupd (%rax), %ymm0
    vmulpd %ymm4, %ymm0, %ymm0      # y = A[i,0] * x[0]: the first term
    vmovupd 32(%rax), %ymm1
    vmulpd %ymm4, %ymm1, %ymm1
    vmovupd 64(%rax), %ymm2
    vmulpd %ymm4, %ymm2, %ymm2
    vmovupd 96(%rax), %ymm3
    vmulpd %ymm4, %ymm3, %ymm3
1:  cmpq %r8, %r11
    je 2f
    addq %r9, %rax
    vbroadcastsd (%r11), %ymm4      # x[j]
    addq $8, %r11
    vmovupd (%rax), %ymm5
    vmulpd %ymm4, %ymm5, %ymm5      # A[i,j] * x[j], rounded
    vaddpd %ymm5, %ymm0, %ymm0      # y + product, rounded
    vmovupd 32(%rax), %ymm6
    vmulpd %ymm4, %ymm6, %ymm6
    vaddpd %ymm6, %ymm1, %ymm1
    vmovupd 64(%rax), %ymm7
    vmulpd %ymm4, %ymm7, %ymm7
    vaddpd %ymm7, %ymm2, %ymm2
    vmovupd 96(%rax), %ymm8
    vmulpd %ymm4, %ymm8, %ymm8
    vaddpd %ymm8, %ymm3, %ymm3
    jmp 1b
2:  vmovupd %ymm0, (%rdx)
    vmovupd %ymm1, 32(%rdx)
    vmovupd %ymm2, 64(%rdx)
    vmovupd %ymm3, 96(%rdx)
    addq $128, %rdi
    addq $128, %rdx
    subq $16, %rcx
    jmp .Lrt_gemm_gemv_avx2_p16

    # Panels of 4 rows: one 4-lane accumulator.
.Lrt_gemm_gemv_avx2_p4:
    cmpq $4, %rcx
    jb .Lrt_gemm_gemv_avx2_p2
    movq %rdi, %rax
    movq %rsi, %r11
    vbroadcastsd (%r11), %ymm4
    addq $8, %r11
    vmovupd (%rax), %ymm0
    vmulpd %ymm4, %ymm0, %ymm0      # the first term
1:  cmpq %r8, %r11
    je 2f
    addq %r9, %rax
    vbroadcastsd (%r11), %ymm4
    addq $8, %r11
    vmovupd (%rax), %ymm5
    vmulpd %ymm4, %ymm5, %ymm5
    vaddpd %ymm5, %ymm0, %ymm0
    jmp 1b
2:  vmovupd %ymm0, (%rdx)
    addq $32, %rdi
    addq $32, %rdx
    subq $4, %rcx
    jmp .Lrt_gemm_gemv_avx2_p4

    # A pair of rows: one 2-lane accumulator (VEX-encoded).
.Lrt_gemm_gemv_avx2_p2:
    cmpq $2, %rcx
    jb .Lrt_gemm_gemv_avx2_p1
    movq %rdi, %rax
    movq %rsi, %r11
    vmovddup (%r11), %xmm4          # x[0] in both lanes
    addq $8, %r11
    vmovupd (%rax), %xmm0
    vmulpd %xmm4, %xmm0, %xmm0      # the first term
1:  cmpq %r8, %r11
    je 2f
    addq %r9, %rax
    vmovddup (%r11), %xmm4
    addq $8, %r11
    vmovupd (%rax), %xmm5
    vmulpd %xmm4, %xmm5, %xmm5
    vaddpd %xmm5, %xmm0, %xmm0
    jmp 1b
2:  vmovupd %xmm0, (%rdx)
    addq $16, %rdi
    addq $16, %rdx
    subq $2, %rcx

    # A last single row: scalar, the same chain.
.Lrt_gemm_gemv_avx2_p1:
    testq %rcx, %rcx
    jz 3f
    movq %rdi, %rax
    movq %rsi, %r11
    vmovsd (%rax), %xmm0
    vmulsd (%r11), %xmm0, %xmm0     # the first term
    addq $8, %r11
1:  cmpq %r8, %r11
    je 2f
    addq %r9, %rax
    vmovsd (%rax), %xmm5
    vmulsd (%r11), %xmm5, %xmm5
    vaddsd %xmm5, %xmm0, %xmm0
    addq $8, %r11
    jmp 1b
2:  vmovsd %xmm0, (%rdx)
3:  vzeroupper
    ret

# ---------------------------------------------------------------------
# .Lrt_gemm_vecmat_sse2 -- y = x A in VECMAT's pinned 8-lane order,
# SSE2 form.
#   Inputs  : %rdi = &x[0], %rsi = &A[0,0], %rdx = &y[0], %rcx = k >= 1,
#             %r8 = c >= 1 (A is k x c, column stride k)
#   Outputs : y[0 .. c-1] written
#   Clobbers: %rax %rcx %rdx %rsi %r8-%r11, %xmm0-%xmm8, %xmm15, flags;
#             the 64 bytes below %rsp (red zone: the tail block)
#   Callee-saved used: none
#   Frame   : none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_gemm_vecmat_sse2:
    movabsq $0x8000000000000000, %rax
    movq %rax, %xmm15
    unpcklpd %xmm15, %xmm15         # -0.0 in both lanes: the start and the padding
    movq %rcx, %r9
    andq $7, %r9                    # t = k mod 8: the tail's products
    shrq $3, %rcx                   # the number of full blocks of 8
    # %rsi walks through A: column j is contiguous, column j+1 follows.

.Lrt_gemm_vecmat_sse2_col:
    movapd %xmm15, %xmm0            # a0 a1 = -0.0
    movapd %xmm15, %xmm1            # a2 a3
    movapd %xmm15, %xmm2            # a4 a5
    movapd %xmm15, %xmm3            # a6 a7
    movq %rdi, %r11                 # &x[0]
    movq %rcx, %r10                 # full blocks left
    testq %r10, %r10
    jz 2f
1:  movupd (%r11), %xmm4            # x[kk], x[kk+1]
    movupd (%rsi), %xmm5            # A[kk,j], A[kk+1,j]
    mulpd %xmm5, %xmm4              # x * A, rounded
    addpd %xmm4, %xmm0              # a + product
    movupd 16(%r11), %xmm4
    movupd 16(%rsi), %xmm5
    mulpd %xmm5, %xmm4
    addpd %xmm4, %xmm1
    movupd 32(%r11), %xmm4
    movupd 32(%rsi), %xmm5
    mulpd %xmm5, %xmm4
    addpd %xmm4, %xmm2
    movupd 48(%r11), %xmm4
    movupd 48(%rsi), %xmm5
    mulpd %xmm5, %xmm4
    addpd %xmm4, %xmm3
    addq $64, %r11
    addq $64, %rsi
    decq %r10
    jnz 1b

    # The tail: an 8-slot block of -0.0 receives the t products.
2:  testq %r9, %r9
    jz 4f
    movupd %xmm15, (RT_GEMM_TAIL + 0)(%rsp)
    movupd %xmm15, (RT_GEMM_TAIL + 16)(%rsp)
    movupd %xmm15, (RT_GEMM_TAIL + 32)(%rsp)
    movupd %xmm15, (RT_GEMM_TAIL + 48)(%rsp)
    xorl %eax, %eax                 # lane l
3:  movsd (%r11,%rax,8), %xmm4
    mulsd (%rsi,%rax,8), %xmm4      # x[kk] * A[kk,j]
    movsd %xmm4, RT_GEMM_TAIL(%rsp,%rax,8)
    incq %rax
    cmpq %r9, %rax
    jb 3b
    movupd (RT_GEMM_TAIL + 0)(%rsp), %xmm4
    addpd %xmm4, %xmm0              # every lane: a + product or a + -0.0
    movupd (RT_GEMM_TAIL + 16)(%rsp), %xmm4
    addpd %xmm4, %xmm1
    movupd (RT_GEMM_TAIL + 32)(%rsp), %xmm4
    addpd %xmm4, %xmm2
    movupd (RT_GEMM_TAIL + 48)(%rsp), %xmm4
    addpd %xmm4, %xmm3
    leaq (%rsi,%r9,8), %rsi         # past the column's tail

    # ((a0 + a1) + (a2 + a3)) + ((a4 + a5) + (a6 + a7)).
4:  movapd %xmm0, %xmm8
    unpckhpd %xmm8, %xmm8
    addsd %xmm8, %xmm0              # a0 + a1
    movapd %xmm1, %xmm8
    unpckhpd %xmm8, %xmm8
    addsd %xmm8, %xmm1              # a2 + a3
    movapd %xmm2, %xmm8
    unpckhpd %xmm8, %xmm8
    addsd %xmm8, %xmm2              # a4 + a5
    movapd %xmm3, %xmm8
    unpckhpd %xmm8, %xmm8
    addsd %xmm8, %xmm3              # a6 + a7
    addsd %xmm1, %xmm0
    addsd %xmm3, %xmm2
    addsd %xmm2, %xmm0
    movsd %xmm0, (%rdx)             # y[j]
    addq $8, %rdx
    decq %r8
    jnz .Lrt_gemm_vecmat_sse2_col
    ret

# ---------------------------------------------------------------------
# .Lrt_gemm_vecmat_avx2 -- y = x A in VECMAT's pinned 8-lane order,
# AVX2 form.
#   Inputs  : as .Lrt_gemm_vecmat_sse2
#   Outputs : y[0 .. c-1] written
#   Clobbers: %rax %rcx %rdx %rsi %r8-%r11, %ymm0-%ymm6, %ymm15, flags;
#             the 64 bytes below %rsp (red zone: the tail block); the
#             upper halves are zeroed on return (vzeroupper)
#   Callee-saved used: none
#   Frame   : none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_gemm_vecmat_avx2:
    movabsq $0x8000000000000000, %rax
    vmovq %rax, %xmm15
    vbroadcastsd %xmm15, %ymm15     # -0.0 in four lanes
    movq %rcx, %r9
    andq $7, %r9                    # t = k mod 8
    shrq $3, %rcx                   # full blocks of 8

.Lrt_gemm_vecmat_avx2_col:
    vmovapd %ymm15, %ymm0           # a0 .. a3 = -0.0
    vmovapd %ymm15, %ymm1           # a4 .. a7
    movq %rdi, %r11
    movq %rcx, %r10
    testq %r10, %r10
    jz 2f
1:  vmovupd (%r11), %ymm4           # x[kk .. kk+4]
    vmulpd (%rsi), %ymm4, %ymm4     # x * A, rounded
    vaddpd %ymm4, %ymm0, %ymm0      # a + product
    vmovupd 32(%r11), %ymm4
    vmulpd 32(%rsi), %ymm4, %ymm4
    vaddpd %ymm4, %ymm1, %ymm1
    addq $64, %r11
    addq $64, %rsi
    decq %r10
    jnz 1b

    # The tail: an 8-slot block of -0.0 receives the t products.
2:  testq %r9, %r9
    jz 4f
    vmovupd %ymm15, (RT_GEMM_TAIL + 0)(%rsp)
    vmovupd %ymm15, (RT_GEMM_TAIL + 32)(%rsp)
    xorl %eax, %eax
3:  vmovsd (%r11,%rax,8), %xmm4
    vmulsd (%rsi,%rax,8), %xmm4, %xmm4      # x[kk] * A[kk,j]
    vmovsd %xmm4, RT_GEMM_TAIL(%rsp,%rax,8)
    incq %rax
    cmpq %r9, %rax
    jb 3b
    vaddpd (RT_GEMM_TAIL + 0)(%rsp), %ymm0, %ymm0   # a + product or a + -0.0
    vaddpd (RT_GEMM_TAIL + 32)(%rsp), %ymm1, %ymm1
    leaq (%rsi,%r9,8), %rsi         # past the column's tail

    # ((a0 + a1) + (a2 + a3)) + ((a4 + a5) + (a6 + a7)).
4:  vextractf128 $1, %ymm0, %xmm2   # a2 a3
    vunpckhpd %xmm0, %xmm0, %xmm3   # a1
    vaddsd %xmm3, %xmm0, %xmm3      # a0 + a1
    vunpckhpd %xmm2, %xmm2, %xmm4   # a3
    vaddsd %xmm4, %xmm2, %xmm4      # a2 + a3
    vaddsd %xmm4, %xmm3, %xmm3      # (a0 + a1) + (a2 + a3)
    vextractf128 $1, %ymm1, %xmm2   # a6 a7
    vunpckhpd %xmm1, %xmm1, %xmm5   # a5
    vaddsd %xmm5, %xmm1, %xmm5      # a4 + a5
    vunpckhpd %xmm2, %xmm2, %xmm6   # a7
    vaddsd %xmm6, %xmm2, %xmm6      # a6 + a7
    vaddsd %xmm6, %xmm5, %xmm5      # (a4 + a5) + (a6 + a7)
    vaddsd %xmm5, %xmm3, %xmm3
    vmovsd %xmm3, (%rdx)            # y[j]
    addq $8, %rdx
    decq %r8
    jnz .Lrt_gemm_vecmat_avx2_col
    vzeroupper
    ret

    .section .note.GNU-stack,"",@progbits
