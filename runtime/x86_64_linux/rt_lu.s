# =====================================================================
# sea/runtime/x86_64_linux/rt_lu.s -- LU and Cholesky factorizations,
# their solves, solve(A, B) and rcond (DESIGN.md 2.13.5 entries LU, CHOL,
# LU_SOLVE, CHOL_SOLVE, SOLVE, RCOND; 2.13.6 "LU", "Triangular solves",
# "CHOL", "CHOL_SOLVE", "SOLVE", "RCOND", "Handles", "Private
# routines"; 2.13.2; LANGUAGE.md 10.8). The x86_64-linux twin of
# runtime/arm64_macos/rt_lu.s.
#
# Defines (global, rt.inc SEA_ENTRY_LIST):
#   sea_lu         (A, site) -> a new Lu handle of the square matrix A
#   sea_chol       (A, site) -> a new Chol handle (A = R'R, upper of A)
#   sea_lu_solve   (F, B, site) -> X with A X = B, F = lu(A)
#   sea_chol_solve (F, B, site) -> X with R'R X = B, F = chol(A)
#   sea_solve      (A, B, site) -> X with A X = B (Cholesky or LU)
#   sea_rcond      (F, site) -> %xmm0 = the 1-norm reciprocal condition
#                  estimate of an Lu handle
# Defines (private routines, L-jc: .globl + .hidden, no rt.inc record,
# no allocation, no error, no site; rt_eig.s calls them):
#   sea_la_potrf   (a, n, ld, w) -> %rax = 0, or 1 + the index of the
#                  first failing pivot
#   sea_la_issym   (a, n, ld) -> %rax = 1 if symmetric (Decision 123),
#                  else 0
# Uses: sea_alloc, sea_free_block, sea_free, sea_live (rt_mem.s),
#       sea_arr_new_u (rt_arr.s), sea_err (rt_err.s), Baysick's
#       bsk_kern_gemm_sub (through its trampoline, the variant main
#       selected).
#
# Matrices are column-major: element (i, j) of a matrix with column
# stride ld is at DATA + 8 * (i + j * ld); a block X[r0..r1, c0..c1] is
# rows r0 .. r1-1 and columns c0 .. c1-1. The panels of an order-n
# algorithm are J_t = [t*NB, min(n, (t+1)*NB)), NB = SEA_LA_NB.
#
# Handles (L-is; the layout is private to the runtimes and the same in
# both): one sea_alloc block of SEA_OBJ_HDR + 48 bytes of fields (n at
# 16, ||A||_1 at 24, the first zero pivot index at 32 or -1 if none,
# bytes 40 .. 63 zero), then at offset 64 the n x n factor (column-major,
# ld n), followed for an Lu by the n pivot indices as u32 (LAPACK's ipiv,
# 0-based). A Chol stores 0.0 as its norm and -1 as its zero pivot (it
# has neither). Block sizes: Lu 64 + 8n^2 + 4n, Chol 64 + 8n^2 (rt_mem.s
# sea_free computes the same). sea_lu and sea_chol add one to sea_live
# when the handle exists; a failing sea_chol frees its block first.
#
# Operation order (L-it; class-R results differ only through the
# Baysick kernel calls): every sum, product and division is the one the
# spec writes, in its order; the 2-lane SSE2 loops (.Lrt_lu_axpy,
# .Lrt_lu_divs) only process two independent elements at once, never
# reorder one element's sequence; dot products (.Lrt_lu_dotsub) are
# sequential scalar chains. No FMA, true divisions, sqrtsd. Every product
# is written in the spec's operand order (F[i,k]*F[k,c], R[kk,j]*R[kk,c],
# ...). This one form is used under every variant.
#
# Baysick views (2.13.6): V(X) of a column-major block of r rows and c
# columns with column stride ld is MV_DATA = &X[0,0], MV_ROWS = c,
# MV_COLS = r, MV_LD = ld (the row-major transpose), and C <- C - A*B is
# bsk_kern_gemm_sub(V(C), V(B), V(A)). Every call has extents >= 1 and a
# C that shares no element with its factors.
#
# Memory: results by sea_arr_new_u (every element written; the empty
# results have none); handles one sea_alloc block each; scratch (SOLVE's
# factor copy, the transposed panel W, RCOND's vectors) one sea_alloc
# block per call, allocated after the result and freed with
# sea_free_block before the entry returns.
#
# ABI: System V AMD64; the entries preserve %rbx %rbp %r12-%r15 and
# %rsp, never change MXCSR, and leave the direction flag clear (rep movsq
# runs with it clear, as the ABI guarantees on entry). The private
# routines follow the same ABI. The local routines (.Lrt_lu_*) state
# their own clobbers. Stack: the deepest own path is an entry's frame
# (at most 104 bytes below its return address, all asserted below 512)
# plus a return address and a local routine's frame (at most 152 bytes,
# .Lrt_lu_getrf, sea_la_potrf) plus a return address and a leaf (none):
# at most 272 bytes; below it run sea_alloc, sea_arr_new_u, sea_err and
# bsk_kern_gemm_sub, whose frames SEA_STACK_MARGIN covers.
# =====================================================================
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"
.include "runtime.inc"              # Baysick's (found through -I <baysick>/include): MV_* and bsk_kern_gemm_sub

# ---- the handle's private layout (L-is) ------------------------------
.equ RT_LU_H_N,         SEA_OBJ_HDR         # u64 n
.equ RT_LU_H_NORM,      (SEA_OBJ_HDR + 8)   # f64 ||A||_1 (Lu), 0.0 (Chol)
.equ RT_LU_H_ZP,        (SEA_OBJ_HDR + 16)  # i64 the first zero pivot index, -1 if none
.equ RT_LU_H_RES0,      (SEA_OBJ_HDR + 24)  # bytes 40 .. 63: zero
.equ RT_LU_H_F,         (SEA_OBJ_HDR + 48)  # the factor, then (Lu) the pivots
.if (RT_LU_H_N != 16) || (RT_LU_H_NORM != 24) || (RT_LU_H_ZP != 32) || (RT_LU_H_F != 64)
    .error "rt_lu: the handle layout of DESIGN.md 2.13.6 (n 16, norm 24, zero pivot 32, factor 64)"
.endif

# ---- frames (locals below the six pushes %rbp %rbx %r12-%r15) -------
# Entered at %rsp = 8 (mod 16); after the six pushes %rsp = 8 (mod 16),
# so every locals size is 8 (mod 16).
# sea_lu, sea_lu_solve: no locals but the alignment word.
.equ RT_LU_E_LOCALS,    8
# sea_chol: the scratch W, its bytes, the handle's bytes, the status.
.equ RT_LU_CH_W,        0
.equ RT_LU_CH_WB,       8
.equ RT_LU_CH_HB,       16
.equ RT_LU_CH_ST,       24
.equ RT_LU_CH_LOCALS,   40
# sea_chol_solve: the scratch W and its bytes.
.equ RT_LU_CS_W,        0
.equ RT_LU_CS_WB,       8
.equ RT_LU_CS_LOCALS,   24
# sea_solve: the scratch block, its bytes, W, the pivots, the path.
.equ RT_LU_SV_S,        0
.equ RT_LU_SV_SB,       8
.equ RT_LU_SV_W,        16
.equ RT_LU_SV_PIV,      24
.equ RT_LU_SV_CH,       32          # 1: the Cholesky path, 0: LU
.equ RT_LU_SV_LOCALS,   40
# sea_rcond: est, estold, iter, j, ||A||_1.
.equ RT_LU_RC_EST,      0
.equ RT_LU_RC_ESTOLD,   8
.equ RT_LU_RC_ITER,     16
.equ RT_LU_RC_J,        24
.equ RT_LU_RC_NORM,     32
.equ RT_LU_RC_LOCALS,   40
# The local routines with three views (.Lrt_lu_getrf, .Lrt_lu_getrs,
# .Lrt_lu_trsu, .Lrt_lu_potrs, sea_la_potrf): V0, V1, V2, then three
# words.
.equ RT_LU_V0,          0
.equ RT_LU_V1,          MV_SIZE
.equ RT_LU_V2,          (2 * MV_SIZE)
.equ RT_LU_W0,          (3 * MV_SIZE)
.equ RT_LU_W1,          (3 * MV_SIZE + 8)
.equ RT_LU_W2,          (3 * MV_SIZE + 16)
.equ RT_LU_VLOCALS,     (3 * MV_SIZE + 24)  # 120
# The error helpers: four slots.
.equ RT_LU_ERR_LOCALS,  (4 * SEA_SLOT_SIZE)

.if ((48 + RT_LU_E_LOCALS) > 512) || ((48 + RT_LU_CH_LOCALS) > 512) || ((48 + RT_LU_CS_LOCALS) > 512) || ((48 + RT_LU_SV_LOCALS) > 512) || ((48 + RT_LU_RC_LOCALS) > 512)
    .error "rt_lu: an entry's frame exceeds 512 bytes"
.endif
.if ((RT_LU_E_LOCALS % 16) != 8) || ((RT_LU_CH_LOCALS % 16) != 8) || ((RT_LU_CS_LOCALS % 16) != 8) || ((RT_LU_SV_LOCALS % 16) != 8) || ((RT_LU_RC_LOCALS % 16) != 8) || ((RT_LU_VLOCALS % 16) != 8)
    .error "rt_lu: frames must keep %rsp aligned"
.endif
.if (48 + RT_LU_SV_LOCALS + 8 + 48 + RT_LU_VLOCALS + 8) > 512
    .error "rt_lu: the deepest own path exceeds 512 bytes"
.endif

    .text

# =====================================================================
# Leaf helpers (custom contracts: each states exactly what it clobbers;
# all preserve %rcx %r8-%r11 unless stated, so loops keep their
# counters there across them).
# =====================================================================

# ---------------------------------------------------------------------
# .Lrt_lu_axpy -- dst[i] = dst[i] - src[i]*s for i = 0 .. cnt-1
#   (contiguous; two independent elements per SSE2 step).
#   Inputs  : %rdi = dst, %rsi = src, %xmm0 = s, %rdx = cnt (>= 0)
#   Outputs : dst written
#   Clobbers: %rdi %rsi %rdx %xmm0-%xmm2, flags
#   Frame   : none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_lu_axpy:
    unpcklpd %xmm0, %xmm0           # s in both lanes
    cmpq $2, %rdx
    jb .Lrt_lu_axpy_one
.Lrt_lu_axpy_two:
    movupd (%rsi), %xmm1
    mulpd %xmm0, %xmm1              # src[i]*s
    movupd (%rdi), %xmm2
    subpd %xmm1, %xmm2              # dst[i] - src[i]*s
    movupd %xmm2, (%rdi)
    addq $16, %rsi
    addq $16, %rdi
    subq $2, %rdx
    cmpq $2, %rdx
    jae .Lrt_lu_axpy_two
.Lrt_lu_axpy_one:
    testq %rdx, %rdx
    jz 1f
    movsd (%rsi), %xmm1             # the last odd element
    mulsd %xmm0, %xmm1
    movsd (%rdi), %xmm2
    subsd %xmm1, %xmm2
    movsd %xmm2, (%rdi)
1:  ret

# ---------------------------------------------------------------------
# .Lrt_lu_axpys -- dst[i] = dst[i] - src[i*stride]*s, i = 0 .. cnt-1
#   (dst contiguous, src strided; scalar).
#   Inputs  : %rdi = dst, %rsi = src, %xmm0 = s, %rdx = cnt (>= 0),
#             %r11 = src stride in bytes
#   Outputs : dst written
#   Clobbers: %rdi %rsi %rdx %xmm1 %xmm2, flags
#   Frame   : none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_lu_axpys:
    testq %rdx, %rdx
    jz 2f
1:  movsd (%rsi), %xmm1
    mulsd %xmm0, %xmm1              # src[i]*s
    movsd (%rdi), %xmm2
    subsd %xmm1, %xmm2              # dst[i] - src[i]*s
    movsd %xmm2, (%rdi)
    addq $8, %rdi
    addq %r11, %rsi
    decq %rdx
    jnz 1b
2:  ret

# ---------------------------------------------------------------------
# .Lrt_lu_divs -- dst[i] = dst[i] / d for i = 0 .. cnt-1 (true divisions).
#   Inputs  : %rdi = dst, %xmm0 = d, %rdx = cnt (>= 0)
#   Outputs : dst written
#   Clobbers: %rdi %rdx %xmm0 %xmm1, flags
#   Frame   : none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_lu_divs:
    unpcklpd %xmm0, %xmm0           # d in both lanes
    cmpq $2, %rdx
    jb .Lrt_lu_divs_one
.Lrt_lu_divs_two:
    movupd (%rdi), %xmm1
    divpd %xmm0, %xmm1              # dst[i] / d
    movupd %xmm1, (%rdi)
    addq $16, %rdi
    subq $2, %rdx
    cmpq $2, %rdx
    jae .Lrt_lu_divs_two
.Lrt_lu_divs_one:
    testq %rdx, %rdx
    jz 1f
    movsd (%rdi), %xmm1
    divsd %xmm0, %xmm1
    movsd %xmm1, (%rdi)
1:  ret

# ---------------------------------------------------------------------
# .Lrt_lu_dotsub -- s = s - a[0]*b[0] - a[1]*b[1] - ... (a sequential
#   chain, index order, each product and difference rounded).
#   Inputs  : %xmm0 = s, %rdi = a, %rsi = b (both contiguous),
#             %rdx = cnt (>= 0)
#   Outputs : %xmm0 = the result
#   Clobbers: %rdi %rsi %rdx %xmm1, flags
#   Frame   : none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_lu_dotsub:
    testq %rdx, %rdx
    jz 2f
1:  movsd (%rdi), %xmm1
    mulsd (%rsi), %xmm1             # a[i]*b[i]
    subsd %xmm1, %xmm0              # s - a[i]*b[i]
    addq $8, %rdi
    addq $8, %rsi
    decq %rdx
    jnz 1b
2:  ret

# ---------------------------------------------------------------------
# .Lrt_lu_mkview -- fill a Baysick view V(X) of the block
#   X[r0..r1, c0..c1] of a column-major matrix: MV_DATA = base +
#   8*(r0 + c0*ld), MV_ROWS = c1 - c0, MV_COLS = r1 - r0, MV_LD = ld.
#   Inputs  : %rdi = the view, %rsi = base, %rdx = ld, %rcx = r0,
#             %r8 = r1, %r9 = c0, %r10 = c1
#   Outputs : the view written
#   Clobbers: %rax, flags (every input register preserved)
#   Frame   : none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_lu_mkview:
    movq %r9, %rax
    imulq %rdx, %rax                # c0*ld
    addq %rcx, %rax                 # + r0
    leaq (%rsi,%rax,8), %rax
    movq %rax, MV_DATA(%rdi)
    movq %r10, %rax
    subq %r9, %rax
    movq %rax, MV_ROWS(%rdi)        # c1 - c0
    movq %r8, %rax
    subq %rcx, %rax
    movq %rax, MV_COLS(%rdi)        # r1 - r0
    movq %rdx, MV_LD(%rdi)
    ret

# ---------------------------------------------------------------------
# .Lrt_lu_wcopy -- W = (R[j0..j1, j1..n])' (exact moves): W is
#   (n - j1) x (j1 - j0), column-major with ld n - j1, W[q, p] =
#   R[j0 + p, j1 + q].
#   Inputs  : %rdi = R, %rsi = R's ld, %rdx = j0, %rcx = j1 (> j0),
#             %r8 = n (> j1), %r9 = W
#   Outputs : W written
#   Clobbers: %rax %rcx %rdx %rsi %r8-%r11, flags
#   Frame   : none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_lu_wcopy:
    subq %rcx, %r8                  # n - j1: W's rows
    movq %rcx, %rax
    imulq %rsi, %rax
    addq %rdx, %rax
    leaq (%rdi,%rax,8), %r10        # &R[j0, j1]
    shlq $3, %rsi                   # R's column stride in bytes
    subq %rdx, %rcx                 # j1 - j0: W's columns
1:  movq %r10, %rax                 # &R[j0+p, j1]: along row j0+p
    movq %r8, %rdx
2:  movq (%rax), %r11
    movq %r11, (%r9)                # W[q, p] = R[j0+p, j1+q]
    addq $8, %r9
    addq %rsi, %rax
    decq %rdx
    jnz 2b
    addq $8, %r10                   # the next row of R
    decq %rcx
    jnz 1b
    ret

# ---------------------------------------------------------------------
# .Lrt_lu_zlower -- set the strict lower triangle of an n x n block to +0.
#   Inputs  : %rdi = a, %rsi = n, %rdx = ld
#   Outputs : a[i, j] = +0 for i > j
#   Clobbers: %rcx %rdx %rdi %r8 %r9, flags
#   Frame   : none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_lu_zlower:
    xorl %ecx, %ecx                 # j
    shlq $3, %rdx                   # ld in bytes
1:  cmpq %rsi, %rcx
    jae 4f
    leaq 1(%rcx), %r8               # i = j + 1
    leaq (%rdi,%r8,8), %r9          # &a[j+1, j]
2:  cmpq %rsi, %r8
    jae 3f
    movq $0, (%r9)                  # +0
    addq $8, %r9
    incq %r8
    jmp 2b
3:  addq %rdx, %rdi                 # the next column
    incq %rcx
    jmp 1b
4:  ret

# ---------------------------------------------------------------------
# .Lrt_lu_cpupper -- copy the upper triangle (i <= j) of an n x n
#   column-major matrix (ld n) into another (ld n); exact moves.
#   Inputs  : %rdi = dst, %rsi = src, %rdx = n
#   Outputs : dst's upper triangle written (its strict lower untouched)
#   Clobbers: %rax %rcx %rdi %rsi %r8 %r9, flags
#   Frame   : 16 bytes (dst and src saved around each rep movsq), leaf
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_lu_cpupper:
    xorl %r8d, %r8d                 # j
    leaq (,%rdx,8), %r9             # the column stride in bytes
1:  cmpq %rdx, %r8
    jae 2f
    pushq %rdi                      # dst and src: rep movsq advances them
    pushq %rsi
    leaq 1(%r8), %rcx               # rows 0 .. j
    rep movsq
    popq %rsi
    popq %rdi
    addq %r9, %rdi
    addq %r9, %rsi
    incq %r8
    jmp 1b
2:  ret

# =====================================================================
# Private routines (L-jc)
# =====================================================================

# ---------------------------------------------------------------------
# sea_la_issym -- Decision 123's symmetric test.
#   Purpose : 1 when a[i,j] and a[j,i] are equal (==, so +0 and -0 are
#             equal) or both NaN for every pair i < j, else 0; the pairs
#             are compared column by column (j ascending, then i).
#   Inputs  : %rdi = a, %rsi = n, %rdx = ld (column stride, elements)
#   Outputs : %rax = 1 or 0
#   Clobbers: %rcx %r8-%r11 %xmm0 %xmm1, flags
#   Callee-saved used: none
#   Frame   : none (leaf)
# ---------------------------------------------------------------------
    .globl sea_la_issym
    .hidden sea_la_issym
    .type sea_la_issym, @function
    .p2align 4
sea_la_issym:
    xorl %ecx, %ecx                 # j
    leaq (,%rdx,8), %r8             # ld in bytes
    movq %rdi, %r9                  # &a[0, j]
.Lrt_lu_issym_col:
    cmpq %rsi, %rcx
    jae .Lrt_lu_issym_yes
    xorl %r10d, %r10d               # i
    leaq (%rdi,%rcx,8), %r11        # &a[j, i] for i = 0
.Lrt_lu_issym_row:
    cmpq %rcx, %r10
    jae .Lrt_lu_issym_next
    movsd (%r9,%r10,8), %xmm0       # a[i, j]
    movsd (%r11), %xmm1             # a[j, i]
    ucomisd %xmm1, %xmm0
    jp .Lrt_lu_issym_nan            # unordered: symmetric only if both are NaN
    jne .Lrt_lu_issym_no
.Lrt_lu_issym_step:
    addq %r8, %r11
    incq %r10
    jmp .Lrt_lu_issym_row
.Lrt_lu_issym_nan:
    ucomisd %xmm0, %xmm0
    jnp .Lrt_lu_issym_no            # a[i, j] is a number, a[j, i] NaN
    ucomisd %xmm1, %xmm1
    jnp .Lrt_lu_issym_no            # a[j, i] is a number, a[i, j] NaN
    jmp .Lrt_lu_issym_step
.Lrt_lu_issym_next:
    addq %r8, %r9                   # the next column
    incq %rcx
    jmp .Lrt_lu_issym_col
.Lrt_lu_issym_yes:
    movl $1, %eax
    ret
.Lrt_lu_issym_no:
    xorl %eax, %eax
    ret
    .size sea_la_issym, . - sea_la_issym

# ---------------------------------------------------------------------
# sea_la_potrf -- CHOL's algorithm in place (DESIGN.md 2.13.6 "CHOL";
#   LAPACK dpotrf 'U' with dpotf2 panels).
#   Purpose : R with A = R'R on the n x n column-major matrix at a
#             (column stride ld), reading only its upper triangle; the
#             strict lower triangle is set to +0 before the first panel
#             and after the last. Per panel J = [j0, j1): (1) the
#             diagonal block, j = j0 .. j1-1: d = R[j,j] - R[kk,j]*R[kk,j]
#             (kk = j0 .. j-1); not d > 0: stop; R[j,j] = sqrt(d); for
#             c = j+1 .. j1-1: R[j,c] = (R[j,c] - R[kk,j]*R[kk,c]) /
#             R[j,j]; (2) the block row, c = j1 .. n-1, j = j0 .. j1-1:
#             R[j,c] = (R[j,c] - R[kk,j]*R[kk,c]) / R[j,j]; (3) when
#             j1 < n: W = (R[j0..j1, j1..n])' and for each panel
#             K = [k0, k1), k0 >= j1: bsk_kern_gemm_sub(V(R[j1..k1,
#             k0..k1]), V(R[j0..j1, k0..k1]), V(W[0..k1-j1, 0..j1-j0])).
#   Inputs  : %rdi = a, %rsi = n, %rdx = ld (>= n), %rcx = w, a scratch
#             area of at least n * SEA_LA_NB doubles (unused when
#             n <= SEA_LA_NB)
#   Outputs : %rax = 0 when R is complete, else 1 + the index of the
#             first failing pivot (a is then partly factored)
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = a, %r12 = n,
#             %r13 = ld, %r14 = w, %r15 = j0; %rbp the frame pointer
#   Frame   : 48 bytes (%rbp %rbx %r12-%r15) + 120 (three views, j1,
#             k0, k1) = 168 bytes
# ---------------------------------------------------------------------
    .globl sea_la_potrf
    .hidden sea_la_potrf
    .type sea_la_potrf, @function
    .p2align 4
sea_la_potrf:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $RT_LU_VLOCALS, %rsp       # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
    movq %rdx, %r13
    movq %rcx, %r14
    movq %rbx, %rdi                 # the strict lower triangle := +0
    movq %r12, %rsi
    movq %r13, %rdx
    call .Lrt_lu_zlower
    xorl %r15d, %r15d               # j0
.Lrt_lu_potrf_panel:
    cmpq %r12, %r15
    jae .Lrt_lu_potrf_ok
    leaq SEA_LA_NB(%r15), %rax
    cmpq %r12, %rax
    cmova %r12, %rax
    movq %rax, RT_LU_W0(%rsp)       # j1 = min(n, j0 + NB)

    # (1) The diagonal block, j = j0 .. j1-1 (%rcx; %r8 = &R[0, j]).
    movq %r15, %rcx
.Lrt_lu_potrf_diag:
    cmpq RT_LU_W0(%rsp), %rcx
    jae .Lrt_lu_potrf_brow
    movq %rcx, %r8
    imulq %r13, %r8
    leaq (%rbx,%r8,8), %r8          # column j
    movsd (%r8,%rcx,8), %xmm0       # d = R[j,j]
    leaq (%r8,%r15,8), %rdi         # R[j0.., j]
    movq %rdi, %rsi
    movq %rcx, %rdx
    subq %r15, %rdx                 # kk = j0 .. j-1
    call .Lrt_lu_dotsub             # d - R[kk,j]*R[kk,j]
    xorpd %xmm1, %xmm1
    ucomisd %xmm1, %xmm0
    jbe .Lrt_lu_potrf_fail          # not d > 0 (d <= 0 or NaN)
    sqrtsd %xmm0, %xmm0
    movsd %xmm0, (%r8,%rcx,8)       # R[j,j] = sqrt(d)
    leaq 1(%rcx), %r9               # c = j+1 .. j1-1
    leaq (%r8,%r13,8), %r10         # column c
.Lrt_lu_potrf_drow:
    cmpq RT_LU_W0(%rsp), %r9
    jae .Lrt_lu_potrf_dnext
    movsd (%r10,%rcx,8), %xmm0      # s = R[j,c]
    leaq (%r8,%r15,8), %rdi         # R[j0.., j]
    leaq (%r10,%r15,8), %rsi        # R[j0.., c]
    movq %rcx, %rdx
    subq %r15, %rdx
    call .Lrt_lu_dotsub             # s - R[kk,j]*R[kk,c]
    divsd (%r8,%rcx,8), %xmm0       # s / R[j,j]
    movsd %xmm0, (%r10,%rcx,8)
    leaq (%r10,%r13,8), %r10
    incq %r9
    jmp .Lrt_lu_potrf_drow
.Lrt_lu_potrf_dnext:
    incq %rcx
    jmp .Lrt_lu_potrf_diag

    # (2) The block row: c = j1 .. n-1 (%r9, %r10 = column c), j = j0 ..
    # j1-1 (%rcx, %r8 = column j).
.Lrt_lu_potrf_brow:
    movq RT_LU_W0(%rsp), %r9
.Lrt_lu_potrf_bcol:
    cmpq %r12, %r9
    jae .Lrt_lu_potrf_trail
    movq %r9, %r10
    imulq %r13, %r10
    leaq (%rbx,%r10,8), %r10
    movq %r15, %rcx
.Lrt_lu_potrf_bj:
    cmpq RT_LU_W0(%rsp), %rcx
    jae .Lrt_lu_potrf_bnext
    movq %rcx, %r8
    imulq %r13, %r8
    leaq (%rbx,%r8,8), %r8
    movsd (%r10,%rcx,8), %xmm0      # s = R[j,c]
    leaq (%r8,%r15,8), %rdi
    leaq (%r10,%r15,8), %rsi
    movq %rcx, %rdx
    subq %r15, %rdx
    call .Lrt_lu_dotsub             # s - R[kk,j]*R[kk,c], kk = j0 .. j-1
    divsd (%r8,%rcx,8), %xmm0       # s / R[j,j]
    movsd %xmm0, (%r10,%rcx,8)
    incq %rcx
    jmp .Lrt_lu_potrf_bj
.Lrt_lu_potrf_bnext:
    incq %r9
    jmp .Lrt_lu_potrf_bcol

    # (3) The trailing update of the upper triangle.
.Lrt_lu_potrf_trail:
    movq RT_LU_W0(%rsp), %rcx
    cmpq %r12, %rcx
    jae .Lrt_lu_potrf_next          # j1 = n: none
    movq %rbx, %rdi                 # W = (R[j0..j1, j1..n])'
    movq %r13, %rsi
    movq %r15, %rdx
    movq %r12, %r8
    movq %r14, %r9
    call .Lrt_lu_wcopy
    movq RT_LU_W0(%rsp), %rax
    movq %rax, RT_LU_W1(%rsp)       # k0 = j1
.Lrt_lu_potrf_kpanel:
    movq RT_LU_W1(%rsp), %r9        # k0
    cmpq %r12, %r9
    jae .Lrt_lu_potrf_next
    leaq SEA_LA_NB(%r9), %r10
    cmpq %r12, %r10
    cmova %r12, %r10
    movq %r10, RT_LU_W2(%rsp)       # k1 = min(n, k0 + NB)
    # V0 = V(R[j1..k1, k0..k1]) (C)
    leaq RT_LU_V0(%rsp), %rdi
    movq %rbx, %rsi
    movq %r13, %rdx
    movq RT_LU_W0(%rsp), %rcx
    movq %r10, %r8
    call .Lrt_lu_mkview
    # V1 = V(R[j0..j1, k0..k1]) (B)
    leaq RT_LU_V1(%rsp), %rdi
    movq %r15, %rcx
    movq RT_LU_W0(%rsp), %r8
    call .Lrt_lu_mkview
    # V2 = V(W[0..k1-j1, 0..j1-j0]), W's ld n - j1 (A)
    leaq RT_LU_V2(%rsp), %rdi
    movq %r14, %rsi
    movq %r12, %rdx
    subq RT_LU_W0(%rsp), %rdx       # n - j1
    xorl %ecx, %ecx
    movq RT_LU_W2(%rsp), %r8
    subq RT_LU_W0(%rsp), %r8        # k1 - j1
    xorl %r9d, %r9d
    movq RT_LU_W0(%rsp), %r10
    subq %r15, %r10                 # j1 - j0
    call .Lrt_lu_mkview
    leaq RT_LU_V0(%rsp), %rdi       # C <- C - W[...] * R[j0..j1, k0..k1]
    leaq RT_LU_V1(%rsp), %rsi
    leaq RT_LU_V2(%rsp), %rdx
    call bsk_kern_gemm_sub          # its status is ignored
    movq RT_LU_W2(%rsp), %rax
    movq %rax, RT_LU_W1(%rsp)       # k0 = k1
    jmp .Lrt_lu_potrf_kpanel
.Lrt_lu_potrf_next:
    movq RT_LU_W0(%rsp), %r15       # j0 = j1
    jmp .Lrt_lu_potrf_panel

.Lrt_lu_potrf_ok:
    movq %rbx, %rdi                 # the strict lower triangle := +0 again
    movq %r12, %rsi
    movq %r13, %rdx
    call .Lrt_lu_zlower
    xorl %eax, %eax                 # R complete
    jmp .Lrt_lu_potrf_ret
.Lrt_lu_potrf_fail:
    leaq 1(%rcx), %rax              # 1 + the failing pivot's index
.Lrt_lu_potrf_ret:
    addq $RT_LU_VLOCALS, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret
    .size sea_la_potrf, . - sea_la_potrf

# =====================================================================
# Local routines of the factorizations and solves
# =====================================================================

# ---------------------------------------------------------------------
# .Lrt_lu_getrf -- LU with partial pivoting in place (DESIGN.md 2.13.6
#   "LU": dgetrf's right-looking structure with dgetf2 panels).
#   Purpose : per panel J = [j0, j1): (1) for k = j0 .. j1-1: the pivot p
#             is the first row of largest magnitude of column k (from
#             k; a candidate replaces it only when strictly larger, so a
#             NaN never does, L-in); piv[k] = p; rows k and p exchanged
#             across all n columns; F[k,k] != 0 (NaN included): F[i,k] =
#             F[i,k] / F[k,k] for i > k, else the first zero pivot
#             recorded; then F[i,c] = F[i,c] - F[i,k]*F[k,c] for c = k+1
#             .. j1-1, i > k; (2) the block row: c = j1 .. n-1, k = j0 ..
#             j1-1, i = k+1 .. j1-1: F[i,c] = F[i,c] - F[i,k]*F[k,c];
#             (3) when j1 < n: bsk_kern_gemm_sub(V(F[j1..n, j1..n]),
#             V(F[j0..j1, j1..n]), V(F[j1..n, j0..j1])), ld n.
#   Inputs  : %rdi = F (n x n, ld n), %rsi = n (>= 0), %rdx = piv (n u32)
#   Outputs : F = L (unit, strictly below) and U; piv; %rax = the first
#             zero pivot's index, or -1
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = F, %r12 = n,
#             %r13 = piv, %r14 = j0, %r15 = j1; %rbp the frame pointer
#   Frame   : 48 bytes + 120 (three views, the zero pivot) = 168 bytes
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_lu_getrf:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $RT_LU_VLOCALS, %rsp       # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
    movq %rdx, %r13
    movq $-1, RT_LU_W0(%rsp)        # no zero pivot yet
    xorl %r14d, %r14d               # j0
.Lrt_lu_getrf_panel:
    cmpq %r12, %r14
    jae .Lrt_lu_getrf_done
    leaq SEA_LA_NB(%r14), %r15
    cmpq %r12, %r15
    cmova %r12, %r15                # j1 = min(n, j0 + NB)

    # (1) The panel: k = j0 .. j1-1 (%rcx), %r8 = &F[0, k].
    movq %r14, %rcx
.Lrt_lu_getrf_k:
    cmpq %r15, %rcx
    jae .Lrt_lu_getrf_brow
    movq %rcx, %r8
    imulq %r12, %r8
    leaq (%rbx,%r8,8), %r8          # column k
    # The pivot search: %r9 = p, %xmm3 = m = |F[p,k]|.
    movq %rcx, %r9
    movsd (%r8,%rcx,8), %xmm3
    andpd .Lrt_lu_abs(%rip), %xmm3
    leaq 1(%rcx), %r10              # i = k+1 .. n-1
.Lrt_lu_getrf_search:
    cmpq %r12, %r10
    jae .Lrt_lu_getrf_found
    movsd (%r8,%r10,8), %xmm1
    andpd .Lrt_lu_abs(%rip), %xmm1
    ucomisd %xmm3, %xmm1
    jbe 1f                          # not strictly greater (or NaN): keep p
    movq %r10, %r9
    movapd %xmm1, %xmm3
1:  incq %r10
    jmp .Lrt_lu_getrf_search
.Lrt_lu_getrf_found:
    movl %r9d, (%r13,%rcx,4)        # piv[k] = p
    cmpq %rcx, %r9
    je .Lrt_lu_getrf_noswap
    # Exchange rows k and p across all n columns (exact moves).
    leaq (%rbx,%rcx,8), %r10        # &F[k, 0]
    leaq (%rbx,%r9,8), %r11         # &F[p, 0]
    leaq (,%r12,8), %rsi            # the column stride in bytes
    movq %r12, %rdx
2:  movq (%r10), %rax
    movq (%r11), %rdi
    movq %rdi, (%r10)
    movq %rax, (%r11)
    addq %rsi, %r10
    addq %rsi, %r11
    decq %rdx
    jnz 2b
.Lrt_lu_getrf_noswap:
    movsd (%r8,%rcx,8), %xmm0       # the pivot F[k,k]
    xorpd %xmm1, %xmm1
    ucomisd %xmm1, %xmm0
    jp .Lrt_lu_getrf_scale          # NaN != 0: divide (it propagates)
    jne .Lrt_lu_getrf_scale
    cmpq $0, RT_LU_W0(%rsp)         # an exactly zero pivot (+0 or -0)
    jge .Lrt_lu_getrf_update        # one is recorded already
    movq %rcx, RT_LU_W0(%rsp)
    jmp .Lrt_lu_getrf_update        # the column is left as it is
.Lrt_lu_getrf_scale:
    leaq 8(%r8,%rcx,8), %rdi        # F[k+1.., k] / F[k,k]
    movq %r12, %rdx
    subq %rcx, %rdx
    decq %rdx                       # n - k - 1
    call .Lrt_lu_divs
.Lrt_lu_getrf_update:
    # F[i,c] -= F[i,k]*F[k,c], c = k+1 .. j1-1 (%r9, %r10 = column c).
    leaq 1(%rcx), %r9
    leaq (,%r12,8), %r11            # the column stride in bytes
    leaq (%r8,%r11), %r10
.Lrt_lu_getrf_ucol:
    cmpq %r15, %r9
    jae .Lrt_lu_getrf_knext
    movsd (%r10,%rcx,8), %xmm0      # F[k,c]
    leaq 8(%r10,%rcx,8), %rdi       # F[k+1.., c]
    leaq 8(%r8,%rcx,8), %rsi        # F[k+1.., k]
    movq %r12, %rdx
    subq %rcx, %rdx
    decq %rdx
    call .Lrt_lu_axpy
    addq %r11, %r10
    incq %r9
    jmp .Lrt_lu_getrf_ucol
.Lrt_lu_getrf_knext:
    incq %rcx
    jmp .Lrt_lu_getrf_k

    # (2) The block row: c = j1 .. n-1 (%r9, %r10 = column c), k = j0 ..
    # j1-1 (%rcx, %r8 = column k), i = k+1 .. j1-1.
.Lrt_lu_getrf_brow:
    movq %r15, %r9
.Lrt_lu_getrf_bcol:
    cmpq %r12, %r9
    jae .Lrt_lu_getrf_trail
    movq %r9, %r10
    imulq %r12, %r10
    leaq (%rbx,%r10,8), %r10
    movq %r14, %rcx
.Lrt_lu_getrf_bk:
    cmpq %r15, %rcx
    jae .Lrt_lu_getrf_bnext
    movq %rcx, %r8
    imulq %r12, %r8
    leaq (%rbx,%r8,8), %r8
    movsd (%r10,%rcx,8), %xmm0      # F[k,c]
    leaq 8(%r10,%rcx,8), %rdi       # F[k+1.., c]
    leaq 8(%r8,%rcx,8), %rsi        # F[k+1.., k]
    movq %r15, %rdx
    subq %rcx, %rdx
    decq %rdx                       # j1 - k - 1
    call .Lrt_lu_axpy
    incq %rcx
    jmp .Lrt_lu_getrf_bk
.Lrt_lu_getrf_bnext:
    incq %r9
    jmp .Lrt_lu_getrf_bcol

    # (3) The trailing update.
.Lrt_lu_getrf_trail:
    cmpq %r12, %r15
    jae .Lrt_lu_getrf_next
    leaq RT_LU_V0(%rsp), %rdi       # V0 = V(F[j1..n, j1..n]) (C)
    movq %rbx, %rsi
    movq %r12, %rdx
    movq %r15, %rcx
    movq %r12, %r8
    movq %r15, %r9
    movq %r12, %r10
    call .Lrt_lu_mkview
    leaq RT_LU_V1(%rsp), %rdi       # V1 = V(F[j0..j1, j1..n]) (B)
    movq %r14, %rcx
    movq %r15, %r8
    call .Lrt_lu_mkview
    leaq RT_LU_V2(%rsp), %rdi       # V2 = V(F[j1..n, j0..j1]) (A)
    movq %r15, %rcx
    movq %r12, %r8
    movq %r14, %r9
    movq %r15, %r10
    call .Lrt_lu_mkview
    leaq RT_LU_V0(%rsp), %rdi
    leaq RT_LU_V1(%rsp), %rsi
    leaq RT_LU_V2(%rsp), %rdx
    call bsk_kern_gemm_sub          # its status is ignored
.Lrt_lu_getrf_next:
    movq %r15, %r14                 # j0 = j1
    jmp .Lrt_lu_getrf_panel
.Lrt_lu_getrf_done:
    movq RT_LU_W0(%rsp), %rax
    addq $RT_LU_VLOCALS, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_lu_trsu -- X = U^-1 X, the backward solve with an upper triangle
#   (DESIGN.md 2.13.6, step (3) of the LU solve and CHOL_SOLVE's
#   backward half), panels descending.
#   Purpose : per panel J = [j0, j1), last first: for each column c of X,
#             for k = j1-1 down to j0: X[k,c] = X[k,c] / U[k,k], then
#             X[i,c] = X[i,c] - U[i,k]*X[k,c] for i = j0 .. k-1; then,
#             when j0 > 0, bsk_kern_gemm_sub(V(X[0..j0, 0..m]),
#             V(X[j0..j1, 0..m]), V(U[0..j0, j0..j1])).
#   Inputs  : %rdi = U (n x n, ld n), %rsi = n (>= 1), %rdx = X (n x m,
#             ld n), %rcx = m (>= 1)
#   Outputs : X overwritten
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = U, %r12 = n,
#             %r13 = X, %r14 = m, %r15 = j0; %rbp the frame pointer
#   Frame   : 48 bytes + 120 (three views, j1) = 168 bytes
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_lu_trsu:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $RT_LU_VLOCALS, %rsp       # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
    movq %rdx, %r13
    movq %rcx, %r14
    leaq -1(%r12), %rax             # the last panel: j0 = ((n-1) / NB) * NB
    xorl %edx, %edx
    movl $SEA_LA_NB, %ecx
    divq %rcx
    imulq $SEA_LA_NB, %rax, %r15
.Lrt_lu_trsu_panel:
    leaq SEA_LA_NB(%r15), %rax
    cmpq %r12, %rax
    cmova %r12, %rax
    movq %rax, RT_LU_W0(%rsp)       # j1 = min(n, j0 + NB)
    # For each column c (%r9, %r10 = column c of X), k = j1-1 down to j0
    # (%rcx, %r8 = column k of U).
    xorl %r9d, %r9d
    movq %r13, %r10
.Lrt_lu_trsu_col:
    cmpq %r14, %r9
    jae .Lrt_lu_trsu_gemm
    movq RT_LU_W0(%rsp), %rcx
    decq %rcx
.Lrt_lu_trsu_k:
    movq %rcx, %r8
    imulq %r12, %r8
    leaq (%rbx,%r8,8), %r8
    movsd (%r10,%rcx,8), %xmm0
    divsd (%r8,%rcx,8), %xmm0       # X[k,c] / U[k,k]
    movsd %xmm0, (%r10,%rcx,8)
    leaq (%r10,%r15,8), %rdi        # X[j0.., c]
    leaq (%r8,%r15,8), %rsi         # U[j0.., k]
    movq %rcx, %rdx
    subq %r15, %rdx                 # k - j0
    call .Lrt_lu_axpy               # X[i,c] - U[i,k]*X[k,c]
    cmpq %r15, %rcx
    je .Lrt_lu_trsu_cnext
    decq %rcx
    jmp .Lrt_lu_trsu_k
.Lrt_lu_trsu_cnext:
    leaq (%r10,%r12,8), %r10
    incq %r9
    jmp .Lrt_lu_trsu_col
.Lrt_lu_trsu_gemm:
    testq %r15, %r15
    jz .Lrt_lu_trsu_done            # j0 = 0: the first panel was the last
    leaq RT_LU_V0(%rsp), %rdi       # V0 = V(X[0..j0, 0..m]) (C)
    movq %r13, %rsi
    movq %r12, %rdx
    xorl %ecx, %ecx
    movq %r15, %r8
    xorl %r9d, %r9d
    movq %r14, %r10
    call .Lrt_lu_mkview
    leaq RT_LU_V1(%rsp), %rdi       # V1 = V(X[j0..j1, 0..m]) (B)
    movq %r15, %rcx
    movq RT_LU_W0(%rsp), %r8
    call .Lrt_lu_mkview
    leaq RT_LU_V2(%rsp), %rdi       # V2 = V(U[0..j0, j0..j1]) (A)
    movq %rbx, %rsi
    xorl %ecx, %ecx
    movq %r15, %r8
    movq %r15, %r9
    movq RT_LU_W0(%rsp), %r10
    call .Lrt_lu_mkview
    leaq RT_LU_V0(%rsp), %rdi
    leaq RT_LU_V1(%rsp), %rsi
    leaq RT_LU_V2(%rsp), %rdx
    call bsk_kern_gemm_sub          # its status is ignored
    subq $SEA_LA_NB, %r15           # the previous panel
    jmp .Lrt_lu_trsu_panel
.Lrt_lu_trsu_done:
    addq $RT_LU_VLOCALS, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_lu_getrs -- X = A^-1 X from LU's factors (DESIGN.md 2.13.6
#   "Triangular solves with many right-hand sides").
#   Purpose : (1) for k = 0 .. n-1, rows k and piv[k] of X exchanged;
#             (2) forward with the unit L, panels ascending: for each
#             column c, for k in J, i = k+1 .. j1-1: X[i,c] = X[i,c] -
#             F[i,k]*X[k,c]; then, when j1 < n,
#             bsk_kern_gemm_sub(V(X[j1..n, 0..m]), V(X[j0..j1, 0..m]),
#             V(F[j1..n, j0..j1])); (3) .Lrt_lu_trsu with U (a tail jump).
#   Inputs  : %rdi = F (n x n, ld n), %rsi = n (>= 1), %rdx = piv,
#             %rcx = X (n x m, ld n), %r8 = m (>= 1)
#   Outputs : X overwritten
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = F, %r12 = n,
#             %r13 = X, %r14 = m, %r15 = j0; %rbp the frame pointer
#   Frame   : 48 bytes + 120 (three views, j1) = 168 bytes; then
#             .Lrt_lu_trsu's in its place
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_lu_getrs:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $RT_LU_VLOCALS, %rsp       # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
    movq %rcx, %r13
    movq %r8, %r14

    # (1) The interchanges, k ascending (exact moves).
    xorl %ecx, %ecx                 # k
    leaq (,%r12,8), %r11            # the column stride in bytes
.Lrt_lu_getrs_swap:
    cmpq %r12, %rcx
    jae .Lrt_lu_getrs_fwd
    movl (%rdx,%rcx,4), %r9d        # p = piv[k]
    cmpq %rcx, %r9
    je 2f
    leaq (%r13,%rcx,8), %r10        # &X[k, 0]
    leaq (%r13,%r9,8), %rsi         # &X[p, 0]
    movq %r14, %rdi
1:  movq (%r10), %rax
    movq (%rsi), %r8
    movq %r8, (%r10)
    movq %rax, (%rsi)
    addq %r11, %r10
    addq %r11, %rsi
    decq %rdi
    jnz 1b
2:  incq %rcx
    jmp .Lrt_lu_getrs_swap

    # (2) Forward with the unit L.
.Lrt_lu_getrs_fwd:
    xorl %r15d, %r15d               # j0
.Lrt_lu_getrs_panel:
    cmpq %r12, %r15
    jae .Lrt_lu_getrs_back
    leaq SEA_LA_NB(%r15), %rax
    cmpq %r12, %rax
    cmova %r12, %rax
    movq %rax, RT_LU_W0(%rsp)       # j1
    xorl %r9d, %r9d                 # c
    movq %r13, %r10                 # column c of X
.Lrt_lu_getrs_col:
    cmpq %r14, %r9
    jae .Lrt_lu_getrs_gemm
    movq %r15, %rcx                 # k = j0 .. j1-1
.Lrt_lu_getrs_k:
    cmpq RT_LU_W0(%rsp), %rcx
    jae .Lrt_lu_getrs_cnext
    movq %rcx, %r8
    imulq %r12, %r8
    leaq (%rbx,%r8,8), %r8          # column k of F
    movsd (%r10,%rcx,8), %xmm0      # X[k,c]
    leaq 8(%r10,%rcx,8), %rdi       # X[k+1.., c]
    leaq 8(%r8,%rcx,8), %rsi        # F[k+1.., k]
    movq RT_LU_W0(%rsp), %rdx
    subq %rcx, %rdx
    decq %rdx                       # j1 - k - 1
    call .Lrt_lu_axpy               # X[i,c] - F[i,k]*X[k,c]
    incq %rcx
    jmp .Lrt_lu_getrs_k
.Lrt_lu_getrs_cnext:
    leaq (%r10,%r12,8), %r10
    incq %r9
    jmp .Lrt_lu_getrs_col
.Lrt_lu_getrs_gemm:
    movq RT_LU_W0(%rsp), %rax
    cmpq %r12, %rax
    jae .Lrt_lu_getrs_pnext         # j1 = n: none
    leaq RT_LU_V0(%rsp), %rdi       # V0 = V(X[j1..n, 0..m]) (C)
    movq %r13, %rsi
    movq %r12, %rdx
    movq %rax, %rcx
    movq %r12, %r8
    xorl %r9d, %r9d
    movq %r14, %r10
    call .Lrt_lu_mkview
    leaq RT_LU_V1(%rsp), %rdi       # V1 = V(X[j0..j1, 0..m]) (B)
    movq %r15, %rcx
    movq RT_LU_W0(%rsp), %r8
    call .Lrt_lu_mkview
    leaq RT_LU_V2(%rsp), %rdi       # V2 = V(F[j1..n, j0..j1]) (A)
    movq %rbx, %rsi
    movq RT_LU_W0(%rsp), %rcx
    movq %r12, %r8
    movq %r15, %r9
    movq RT_LU_W0(%rsp), %r10
    call .Lrt_lu_mkview
    leaq RT_LU_V0(%rsp), %rdi
    leaq RT_LU_V1(%rsp), %rsi
    leaq RT_LU_V2(%rsp), %rdx
    call bsk_kern_gemm_sub          # its status is ignored
.Lrt_lu_getrs_pnext:
    movq RT_LU_W0(%rsp), %r15
    jmp .Lrt_lu_getrs_panel

    # (3) Backward with U: .Lrt_lu_trsu(F, n, X, m), as a tail jump.
.Lrt_lu_getrs_back:
    movq %rbx, %rdi
    movq %r12, %rsi
    movq %r13, %rdx
    movq %r14, %rcx
    addq $RT_LU_VLOCALS, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    jmp .Lrt_lu_trsu

# ---------------------------------------------------------------------
# .Lrt_lu_potrs -- X = (R'R)^-1 X from Cholesky's R (DESIGN.md 2.13.6
#   "CHOL_SOLVE").
#   Purpose : forward with R', panels ascending: for each column c, for
#             j in J ascending: X[j,c] = X[j,c] / R[j,j], then X[i,c] =
#             X[i,c] - R[j,i]*X[j,c] for i = j+1 .. j1-1; then, when
#             j1 < n, W = (R[j0..j1, j1..n])' and
#             bsk_kern_gemm_sub(V(X[j1..n, 0..m]), V(X[j0..j1, 0..m]),
#             V(W)); then backward with R: .Lrt_lu_trsu (a tail jump).
#   Inputs  : %rdi = R (n x n, ld n), %rsi = n (>= 1), %rdx = X (n x m,
#             ld n), %rcx = m (>= 1), %r8 = W (n * SEA_LA_NB doubles;
#             unused when n <= SEA_LA_NB)
#   Outputs : X overwritten
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = R, %r12 = n,
#             %r13 = X, %r14 = m, %r15 = j0; %rbp the frame pointer
#   Frame   : 48 bytes + 120 (three views, j1, W) = 168 bytes; then
#             .Lrt_lu_trsu's in its place
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_lu_potrs:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $RT_LU_VLOCALS, %rsp       # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
    movq %rdx, %r13
    movq %rcx, %r14
    movq %r8, RT_LU_W1(%rsp)        # W
    xorl %r15d, %r15d               # j0
.Lrt_lu_potrs_panel:
    cmpq %r12, %r15
    jae .Lrt_lu_potrs_back
    leaq SEA_LA_NB(%r15), %rax
    cmpq %r12, %rax
    cmova %r12, %rax
    movq %rax, RT_LU_W0(%rsp)       # j1
    xorl %r9d, %r9d                 # c
    movq %r13, %r10                 # column c of X
    leaq (,%r12,8), %r11            # R's row stride in bytes (along a row)
.Lrt_lu_potrs_col:
    cmpq %r14, %r9
    jae .Lrt_lu_potrs_gemm
    movq %r15, %rcx                 # j = j0 .. j1-1
.Lrt_lu_potrs_j:
    cmpq RT_LU_W0(%rsp), %rcx
    jae .Lrt_lu_potrs_cnext
    movq %rcx, %r8
    imulq %r12, %r8
    addq %rcx, %r8
    leaq (%rbx,%r8,8), %r8          # &R[j,j]
    movsd (%r10,%rcx,8), %xmm0
    divsd (%r8), %xmm0              # X[j,c] / R[j,j]
    movsd %xmm0, (%r10,%rcx,8)
    leaq 8(%r10,%rcx,8), %rdi       # X[j+1.., c]
    leaq (%r8,%r11), %rsi           # R[j, j+1..] (along row j)
    movq RT_LU_W0(%rsp), %rdx
    subq %rcx, %rdx
    decq %rdx                       # j1 - j - 1
    call .Lrt_lu_axpys              # X[i,c] - R[j,i]*X[j,c]
    incq %rcx
    jmp .Lrt_lu_potrs_j
.Lrt_lu_potrs_cnext:
    leaq (%r10,%r12,8), %r10
    incq %r9
    jmp .Lrt_lu_potrs_col
.Lrt_lu_potrs_gemm:
    movq RT_LU_W0(%rsp), %rcx
    cmpq %r12, %rcx
    jae .Lrt_lu_potrs_pnext         # j1 = n: none
    movq %rbx, %rdi                 # W = (R[j0..j1, j1..n])'
    movq %r12, %rsi
    movq %r15, %rdx
    movq %r12, %r8
    movq RT_LU_W1(%rsp), %r9
    call .Lrt_lu_wcopy
    leaq RT_LU_V0(%rsp), %rdi       # V0 = V(X[j1..n, 0..m]) (C)
    movq %r13, %rsi
    movq %r12, %rdx
    movq RT_LU_W0(%rsp), %rcx
    movq %r12, %r8
    xorl %r9d, %r9d
    movq %r14, %r10
    call .Lrt_lu_mkview
    leaq RT_LU_V1(%rsp), %rdi       # V1 = V(X[j0..j1, 0..m]) (B)
    movq %r15, %rcx
    movq RT_LU_W0(%rsp), %r8
    call .Lrt_lu_mkview
    leaq RT_LU_V2(%rsp), %rdi       # V2 = V(W): (n-j1) x (j1-j0), ld n-j1 (A)
    movq RT_LU_W1(%rsp), %rsi
    movq %r12, %rdx
    subq RT_LU_W0(%rsp), %rdx
    xorl %ecx, %ecx
    movq %rdx, %r8
    xorl %r9d, %r9d
    movq RT_LU_W0(%rsp), %r10
    subq %r15, %r10
    call .Lrt_lu_mkview
    leaq RT_LU_V0(%rsp), %rdi
    leaq RT_LU_V1(%rsp), %rsi
    leaq RT_LU_V2(%rsp), %rdx
    call bsk_kern_gemm_sub          # its status is ignored
.Lrt_lu_potrs_pnext:
    movq RT_LU_W0(%rsp), %r15
    jmp .Lrt_lu_potrs_panel

    # Backward with R: .Lrt_lu_trsu(R, n, X, m), as a tail jump.
.Lrt_lu_potrs_back:
    movq %rbx, %rdi
    movq %r12, %rsi
    movq %r13, %rdx
    movq %r14, %rcx
    addq $RT_LU_VLOCALS, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    jmp .Lrt_lu_trsu

# ---------------------------------------------------------------------
# .Lrt_lu_square_err -- NOT_SQUARE with the operand's shape (noreturn).
#   Inputs  : %rdi = the matrix, %rsi = site
#   Outputs : none (sea_err does not return)
#   Clobbers: (never returns)
#   Callee-saved used: %rbp the frame pointer
#   Frame   : 8 (%rbp) + 32 (slots) bytes
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_lu_square_err:
    pushq %rbp
    movq %rsp, %rbp
    subq $RT_LU_ERR_LOCALS, %rsp
    movq SEA_ARR_ROWS(%rdi), %rax
    movq %rax, (0 * SEA_SLOT_SIZE)(%rsp)    # rows
    movq SEA_ARR_COLS(%rdi), %rax
    movq %rax, (1 * SEA_SLOT_SIZE)(%rsp)    # cols
    movl $SEA_E_NOT_SQUARE, %edi
    movq %rsp, %rdx
    call sea_err                    # noreturn
    ud2

# ---------------------------------------------------------------------
# .Lrt_lu_shape_err -- SHAPE_MISMATCH: n x n, then B's shape (noreturn).
#   Inputs  : %rdi = n, %rsi = B, %rdx = site
#   Outputs : none (sea_err does not return)
#   Clobbers: (never returns)
#   Callee-saved used: %rbp the frame pointer
#   Frame   : 8 (%rbp) + 32 (slots) bytes
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_lu_shape_err:
    pushq %rbp
    movq %rsp, %rbp
    subq $RT_LU_ERR_LOCALS, %rsp
    movq %rdi, (0 * SEA_SLOT_SIZE)(%rsp)    # n x n
    movq %rdi, (1 * SEA_SLOT_SIZE)(%rsp)
    movq SEA_ARR_ROWS(%rsi), %rax
    movq %rax, (2 * SEA_SLOT_SIZE)(%rsp)    # B's rows
    movq SEA_ARR_COLS(%rsi), %rax
    movq $SEA_SHAPE_VEC, %rcx
    cmpb $1, SEA_ARR_RANK(%rsi)
    cmove %rcx, %rax                        # a vector: SEA_SHAPE_VEC
    movq %rax, (3 * SEA_SLOT_SIZE)(%rsp)
    movq %rdx, %rsi
    movl $SEA_E_SHAPE_MISMATCH, %edi
    movq %rsp, %rdx
    call sea_err                    # noreturn
    ud2

# ---------------------------------------------------------------------
# .Lrt_lu_newx -- the result X of a solve: sea_arr_new_u(f64, rank(B),
#   rows(B), cols(B), site); when it has elements, B's are copied into
#   it (exact moves).
#   Inputs  : %rdi = B, %rsi = site
#   Outputs : %rax = X (count 1)
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = B; %rbp
#   Frame   : 24 bytes (%rbp %rbx, the alignment word)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_lu_newx:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp                   # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r8                  # site
    movl $SEA_EK_F64, %edi
    movzbl SEA_ARR_RANK(%rbx), %esi
    movq SEA_ARR_ROWS(%rbx), %rdx
    movq SEA_ARR_COLS(%rbx), %rcx
    call sea_arr_new_u
    movq SEA_ARR_ROWS(%rbx), %rcx
    imulq SEA_ARR_COLS(%rbx), %rcx  # rows * cols (0 for an empty B)
    movq SEA_ARR_DATA(%rbx), %rsi
    movq SEA_ARR_DATA(%rax), %rdi
    rep movsq                       # X = B
    addq $8, %rsp
    popq %rbx
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_lu_newh -- a new handle block with its fields (L-is).
#   Inputs  : %rdi = n, %rsi = the byte count, %rdx = the tag
#             (SEA_TAG_LU or SEA_TAG_CHOL), %rcx = site
#   Outputs : %rax = the block: count 1, the tag, n, norm 0.0, zero pivot
#             -1, bytes 40 .. 63 zero; not yet counted in sea_live
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = n, %r12 = the tag; %rbp
#   Frame   : 24 bytes (%rbp %rbx %r12)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_lu_newh:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12                      # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rdx, %r12
    movq %rsi, %rdi
    movq %rcx, %rsi
    call sea_alloc                  # out of memory: sea_err(SEA_E_OUT_OF_MEMORY, site)
    movq $1, SEA_OBJ_RC(%rax)       # count 1
    movq %r12, SEA_OBJ_TAG(%rax)    # the tag byte, bytes 9 .. 15 zero
    movq %rbx, RT_LU_H_N(%rax)
    movq $0, RT_LU_H_NORM(%rax)     # 0.0
    movq $-1, RT_LU_H_ZP(%rax)      # no zero pivot
    movq $0, RT_LU_H_RES0(%rax)
    movq $0, (RT_LU_H_RES0 + 8)(%rax)
    movq $0, (RT_LU_H_RES0 + 16)(%rax)
    popq %r12
    popq %rbx
    popq %rbp
    ret

# =====================================================================
# Entries
# =====================================================================

# ---------------------------------------------------------------------
# sea_lu -- the entry LU.
#   Purpose : A not square: NOT_SQUARE (A's shape). A new Lu handle
#             (counted in sea_live): ||A||_1 of the input (for each
#             column j, s_j = |A[0,j]| + |A[1,j]| + ... in row order;
#             ||A||_1 = s_0, then it becomes s_j when s_j > ||A||_1 or
#             s_j is NaN; 0 for n = 0), A copied into the factor block,
#             .Lrt_lu_getrf, the first exactly zero pivot recorded. Never
#             fails for a singular A.
#   Inputs  : %rdi = A (a dynamic f64 matrix, borrowed), %rsi = site
#   Outputs : %rax = the handle (count 1)
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = A, %r12 = site,
#             %r13 = n, %r14 = the handle; %r15 unused; %rbp the frame
#             pointer
#   Frame   : 48 bytes + 8 (alignment) = 56 bytes
# ---------------------------------------------------------------------
    .globl sea_lu
    .type sea_lu, @function
    .p2align 4
sea_lu:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $RT_LU_E_LOCALS, %rsp      # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
    movq SEA_ARR_ROWS(%rbx), %r13   # n
    cmpq SEA_ARR_COLS(%rbx), %r13
    jne .Lrt_lu_lu_square

    # The handle: 64 + 8n^2 + 4n bytes.
    movq %r13, %rsi
    imulq %r13, %rsi
    shlq $3, %rsi
    leaq RT_LU_H_F(%rsi,%r13,4), %rsi
    movq %r13, %rdi
    movl $SEA_TAG_LU, %edx
    movq %r12, %rcx
    call .Lrt_lu_newh
    movq %rax, %r14

    # ||A||_1 (%xmm2), dlange's rule.
    xorpd %xmm2, %xmm2              # 0 for n = 0
    testq %r13, %r13
    jz .Lrt_lu_lu_normed
    movq SEA_ARR_DATA(%rbx), %rsi
    movapd .Lrt_lu_abs(%rip), %xmm4
    xorl %ecx, %ecx                 # j
.Lrt_lu_lu_ncol:
    xorpd %xmm0, %xmm0              # s_j: +0 + |A[0,j]| = |A[0,j]|
    movq %r13, %rdx
1:  movsd (%rsi), %xmm1
    andpd %xmm4, %xmm1
    addsd %xmm1, %xmm0              # s_j + |A[i,j]|, row order
    addq $8, %rsi
    decq %rdx
    jnz 1b
    testq %rcx, %rcx
    jz 2f                           # j = 0: ||A||_1 = s_0
    ucomisd %xmm2, %xmm0
    ja 2f                           # s_j > ||A||_1
    ucomisd %xmm0, %xmm0
    jp 2f                           # s_j is NaN
    jmp 3f
2:  movapd %xmm0, %xmm2
3:  incq %rcx
    cmpq %r13, %rcx
    jb .Lrt_lu_lu_ncol
.Lrt_lu_lu_normed:
    movsd %xmm2, RT_LU_H_NORM(%r14)

    # F = A, then the factorization.
    movq SEA_ARR_DATA(%rbx), %rsi
    leaq RT_LU_H_F(%r14), %rdi
    movq %r13, %rcx
    imulq %r13, %rcx
    rep movsq
    leaq RT_LU_H_F(%r14), %rdi      # F
    movq %r13, %rsi
    movq %r13, %rdx
    imulq %r13, %rdx
    leaq (%rdi,%rdx,8), %rdx        # piv, after the factor
    call .Lrt_lu_getrf
    movq %rax, RT_LU_H_ZP(%r14)     # the first zero pivot, or -1
    incq sea_live(%rip)             # the handle exists: one more object
    movq %r14, %rax
    addq $RT_LU_E_LOCALS, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret
.Lrt_lu_lu_square:
    movq %rbx, %rdi
    movq %r12, %rsi
    call .Lrt_lu_square_err         # noreturn
    .size sea_lu, . - sea_lu

# ---------------------------------------------------------------------
# sea_chol -- the entry CHOL.
#   Purpose : NOT_SQUARE (A's shape); a new Chol handle holding R (A =
#             R'R) from the upper triangle of A only (L-im), by
#             sea_la_potrf; its strict lower triangle +0. A pivot not
#             greater than 0 (a NaN included): the scratch and the handle
#             freed (uncounted), then NOT_POSDEF.
#   Inputs  : %rdi = A (borrowed), %rsi = site
#   Outputs : %rax = the handle (count 1, counted in sea_live)
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = A, %r12 = site,
#             %r13 = n, %r14 = the handle; %r15 unused; %rbp
#   Frame   : 48 bytes + 40 (W, its bytes, the handle's bytes, the
#             status, alignment) = 88 bytes
# ---------------------------------------------------------------------
    .globl sea_chol
    .type sea_chol, @function
    .p2align 4
sea_chol:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $RT_LU_CH_LOCALS, %rsp     # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
    movq SEA_ARR_ROWS(%rbx), %r13   # n
    cmpq SEA_ARR_COLS(%rbx), %r13
    jne .Lrt_lu_chol_square

    # The handle (the result): 64 + 8n^2 bytes.
    movq %r13, %rsi
    imulq %r13, %rsi
    shlq $3, %rsi
    addq $RT_LU_H_F, %rsi
    movq %rsi, RT_LU_CH_HB(%rsp)
    movq %r13, %rdi
    movl $SEA_TAG_CHOL, %edx
    movq %r12, %rcx
    call .Lrt_lu_newh
    movq %rax, %r14
    # R's upper triangle = A's.
    leaq RT_LU_H_F(%r14), %rdi
    movq SEA_ARR_DATA(%rbx), %rsi
    movq %r13, %rdx
    call .Lrt_lu_cpupper
    # The scratch W (n * NB doubles), after the result, when n > NB.
    movq $0, RT_LU_CH_W(%rsp)
    cmpq $SEA_LA_NB, %r13
    jbe 1f
    imulq $(8 * SEA_LA_NB), %r13, %rdi
    movq %rdi, RT_LU_CH_WB(%rsp)
    movq %r12, %rsi
    call sea_alloc
    movq %rax, RT_LU_CH_W(%rsp)
1:  leaq RT_LU_H_F(%r14), %rdi
    movq %r13, %rsi
    movq %r13, %rdx
    movq RT_LU_CH_W(%rsp), %rcx
    call sea_la_potrf
    movq %rax, RT_LU_CH_ST(%rsp)
    movq RT_LU_CH_W(%rsp), %rdi
    testq %rdi, %rdi
    jz 2f
    movq RT_LU_CH_WB(%rsp), %rsi
    call sea_free_block             # the scratch goes before the entry returns
2:  cmpq $0, RT_LU_CH_ST(%rsp)
    jne .Lrt_lu_chol_posdef
    incq sea_live(%rip)             # the handle exists: one more object
    movq %r14, %rax
    addq $RT_LU_CH_LOCALS, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret
.Lrt_lu_chol_posdef:
    movq %r14, %rdi                 # the handle's block, uncounted
    movq RT_LU_CH_HB(%rsp), %rsi
    call sea_free_block
    movl $SEA_E_NOT_POSDEF, %edi
    movq %r12, %rsi
    xorl %edx, %edx                 # no slots
    call sea_err                    # noreturn
    ud2
.Lrt_lu_chol_square:
    movq %rbx, %rdi
    movq %r12, %rsi
    call .Lrt_lu_square_err         # noreturn
    .size sea_chol, . - sea_chol

# ---------------------------------------------------------------------
# sea_lu_solve -- the entry LU_SOLVE.
#   Purpose : F an Lu of order n, B a vector or matrix; rows(B) != n:
#             SHAPE_MISMATCH (n x n, B's shape); a recorded zero pivot
#             (n > 0): SINGULAR; then a new array of B's rank and shape,
#             empty without arithmetic when n = 0 or m = 0, else X = B
#             and .Lrt_lu_getrs (interchanges, unit L, U).
#   Inputs  : %rdi = F (borrowed), %rsi = B (borrowed), %rdx = site
#   Outputs : %rax = X (count 1)
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = F, %r12 = B,
#             %r13 = site, %r14 = n, %r15 = X; %rbp
#   Frame   : 48 bytes + 8 (alignment) = 56 bytes
# ---------------------------------------------------------------------
    .globl sea_lu_solve
    .type sea_lu_solve, @function
    .p2align 4
sea_lu_solve:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $RT_LU_E_LOCALS, %rsp      # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
    movq %rdx, %r13
    movq RT_LU_H_N(%rbx), %r14      # n
    cmpq SEA_ARR_ROWS(%r12), %r14
    jne .Lrt_lu_lus_shape
    cmpq $0, RT_LU_H_ZP(%rbx)
    jge .Lrt_lu_lus_singular        # a zero pivot is recorded only when n > 0
    movq %r12, %rdi                 # X = B (a copy of B's shape)
    movq %r13, %rsi
    call .Lrt_lu_newx
    movq %rax, %r15
    testq %r14, %r14
    jz .Lrt_lu_lus_done             # n = 0: empty
    movq SEA_ARR_COLS(%r12), %r8    # m
    testq %r8, %r8
    jz .Lrt_lu_lus_done             # m = 0: empty
    leaq RT_LU_H_F(%rbx), %rdi      # F
    movq %r14, %rsi
    movq %r14, %rdx
    imulq %r14, %rdx
    leaq (%rdi,%rdx,8), %rdx        # piv
    movq SEA_ARR_DATA(%r15), %rcx   # X
    call .Lrt_lu_getrs
.Lrt_lu_lus_done:
    movq %r15, %rax
    addq $RT_LU_E_LOCALS, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret
.Lrt_lu_lus_shape:
    movq %r14, %rdi
    movq %r12, %rsi
    movq %r13, %rdx
    call .Lrt_lu_shape_err          # noreturn
.Lrt_lu_lus_singular:
    movl $SEA_E_SINGULAR, %edi
    movq %r13, %rsi
    xorl %edx, %edx
    call sea_err                    # noreturn
    ud2
    .size sea_lu_solve, . - sea_lu_solve

# ---------------------------------------------------------------------
# sea_chol_solve -- the entry CHOL_SOLVE.
#   Purpose : F a Chol of order n; the shape check as LU_SOLVE (a Chol
#             has no zero pivot); a new array of B's shape, empty when
#             n = 0 or m = 0, else X = B and .Lrt_lu_potrs with a scratch
#             W of n * NB doubles when n > NB.
#   Inputs  : %rdi = F (borrowed), %rsi = B (borrowed), %rdx = site
#   Outputs : %rax = X (count 1)
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = F, %r12 = B,
#             %r13 = site, %r14 = n, %r15 = X; %rbp
#   Frame   : 48 bytes + 24 (W, its bytes, alignment) = 72 bytes
# ---------------------------------------------------------------------
    .globl sea_chol_solve
    .type sea_chol_solve, @function
    .p2align 4
sea_chol_solve:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $RT_LU_CS_LOCALS, %rsp     # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
    movq %rdx, %r13
    movq RT_LU_H_N(%rbx), %r14      # n
    cmpq SEA_ARR_ROWS(%r12), %r14
    jne .Lrt_lu_chs_shape
    movq %r12, %rdi                 # X = B
    movq %r13, %rsi
    call .Lrt_lu_newx
    movq %rax, %r15
    testq %r14, %r14
    jz .Lrt_lu_chs_done             # n = 0: empty
    cmpq $0, SEA_ARR_COLS(%r12)
    je .Lrt_lu_chs_done             # m = 0: empty
    movq $0, RT_LU_CS_W(%rsp)       # the scratch W, after the result
    cmpq $SEA_LA_NB, %r14
    jbe 1f
    imulq $(8 * SEA_LA_NB), %r14, %rdi
    movq %rdi, RT_LU_CS_WB(%rsp)
    movq %r13, %rsi
    call sea_alloc
    movq %rax, RT_LU_CS_W(%rsp)
1:  leaq RT_LU_H_F(%rbx), %rdi      # R
    movq %r14, %rsi
    movq SEA_ARR_DATA(%r15), %rdx   # X
    movq SEA_ARR_COLS(%r12), %rcx   # m
    movq RT_LU_CS_W(%rsp), %r8
    call .Lrt_lu_potrs
    movq RT_LU_CS_W(%rsp), %rdi
    testq %rdi, %rdi
    jz .Lrt_lu_chs_done
    movq RT_LU_CS_WB(%rsp), %rsi
    call sea_free_block
.Lrt_lu_chs_done:
    movq %r15, %rax
    addq $RT_LU_CS_LOCALS, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret
.Lrt_lu_chs_shape:
    movq %r14, %rdi
    movq %r12, %rsi
    movq %r13, %rdx
    call .Lrt_lu_shape_err          # noreturn
    .size sea_chol_solve, . - sea_chol_solve

# ---------------------------------------------------------------------
# sea_solve -- the entry SOLVE.
#   Purpose : NOT_SQUARE (A's shape); the shape check (n x n, B's shape);
#             a new array X of B's shape; for n > 0 one scratch block
#             (the factor n x n, W of n * NB doubles when n > NB, the n
#             u32 pivots): when A is symmetric (sea_la_issym, Decision
#             123) and every A[i,i] > 0 (a NaN fails), CHOL's algorithm
#             (sea_la_potrf) on a copy of A's upper triangle; if that is
#             not tried or reaches a failing pivot, LU's (.Lrt_lu_getrf)
#             on a fresh copy of A (L-jb); an LU zero pivot: the scratch
#             and X freed, SINGULAR; then m = 0 returns X empty, else
#             X = B and .Lrt_lu_potrs or .Lrt_lu_getrs. The result is
#             what solve(chol(A), B) or solve(lu(A), B) gives for the
#             path taken.
#   Inputs  : %rdi = A (borrowed), %rsi = B (borrowed), %rdx = site
#   Outputs : %rax = X (count 1)
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = A, %r12 = B,
#             %r13 = site, %r14 = n, %r15 = X; %rbp
#   Frame   : 48 bytes + 40 (scratch, its bytes, W, pivots, path) = 88
# ---------------------------------------------------------------------
    .globl sea_solve
    .type sea_solve, @function
    .p2align 4
sea_solve:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $RT_LU_SV_LOCALS, %rsp     # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
    movq %rdx, %r13
    movq SEA_ARR_ROWS(%rbx), %r14   # n
    cmpq SEA_ARR_COLS(%rbx), %r14
    jne .Lrt_lu_sv_square
    cmpq SEA_ARR_ROWS(%r12), %r14
    jne .Lrt_lu_sv_shape
    movq %r12, %rdi                 # X, B's shape (B copied in; overwritten later)
    movq %r13, %rsi
    call .Lrt_lu_newx
    movq %rax, %r15
    testq %r14, %r14
    jz .Lrt_lu_sv_ret               # n = 0: the empty result of B's shape

    # The scratch block: factor 8n^2, W 8n*NB (n > NB), pivots 4n.
    movq %r14, %rax
    imulq %r14, %rax
    shlq $3, %rax                   # 8n^2
    xorl %ecx, %ecx
    cmpq $SEA_LA_NB, %r14
    jbe 1f
    imulq $(8 * SEA_LA_NB), %r14, %rcx
1:  leaq (%rax,%rcx), %rdx          # + W
    leaq (%rdx,%r14,4), %rdi        # + pivots
    movq %rdi, RT_LU_SV_SB(%rsp)
    movq %rdx, RT_LU_SV_PIV(%rsp)   # offsets for now
    movq %rax, RT_LU_SV_W(%rsp)
    movq %r13, %rsi
    call sea_alloc
    movq %rax, RT_LU_SV_S(%rsp)
    addq %rax, RT_LU_SV_W(%rsp)     # W = S + 8n^2
    addq %rax, RT_LU_SV_PIV(%rsp)   # piv = W + its bytes
    movq $0, RT_LU_SV_CH(%rsp)

    # The Cholesky attempt: A symmetric and every A[i,i] > 0.
    movq SEA_ARR_DATA(%rbx), %rdi
    movq %r14, %rsi
    movq %r14, %rdx
    call sea_la_issym
    testq %rax, %rax
    jz .Lrt_lu_sv_lu
    movq SEA_ARR_DATA(%rbx), %rsi
    leaq 8(,%r14,8), %rdx           # the diagonal's stride: 8(n + 1)
    movq %r14, %rcx
    xorpd %xmm1, %xmm1
2:  movsd (%rsi), %xmm0
    ucomisd %xmm1, %xmm0
    jbe .Lrt_lu_sv_lu               # A[i,i] > 0 fails (<= 0 or NaN)
    addq %rdx, %rsi
    decq %rcx
    jnz 2b
    movq RT_LU_SV_S(%rsp), %rdi     # the factor = A's upper triangle
    movq SEA_ARR_DATA(%rbx), %rsi
    movq %r14, %rdx
    call .Lrt_lu_cpupper
    movq RT_LU_SV_S(%rsp), %rdi
    movq %r14, %rsi
    movq %r14, %rdx
    movq RT_LU_SV_W(%rsp), %rcx
    call sea_la_potrf
    testq %rax, %rax
    jnz .Lrt_lu_sv_lu               # a failing pivot: LU on a fresh copy
    movq $1, RT_LU_SV_CH(%rsp)
    jmp .Lrt_lu_sv_solve

    # LU on a fresh copy of A.
.Lrt_lu_sv_lu:
    movq SEA_ARR_DATA(%rbx), %rsi
    movq RT_LU_SV_S(%rsp), %rdi
    movq %r14, %rcx
    imulq %r14, %rcx
    rep movsq
    movq RT_LU_SV_S(%rsp), %rdi
    movq %r14, %rsi
    movq RT_LU_SV_PIV(%rsp), %rdx
    call .Lrt_lu_getrf
    testq %rax, %rax
    jns .Lrt_lu_sv_singular         # a zero pivot (index >= 0)

    # The solve (X = B already); m = 0: nothing to do.
.Lrt_lu_sv_solve:
    movq SEA_ARR_COLS(%r12), %rcx   # m
    testq %rcx, %rcx
    jz .Lrt_lu_sv_free
    cmpq $0, RT_LU_SV_CH(%rsp)
    je 3f
    movq RT_LU_SV_S(%rsp), %rdi     # R
    movq %r14, %rsi
    movq SEA_ARR_DATA(%r15), %rdx
    movq RT_LU_SV_W(%rsp), %r8
    call .Lrt_lu_potrs
    jmp .Lrt_lu_sv_free
3:  movq %rcx, %r8                  # m
    movq RT_LU_SV_S(%rsp), %rdi     # F
    movq %r14, %rsi
    movq RT_LU_SV_PIV(%rsp), %rdx
    movq SEA_ARR_DATA(%r15), %rcx
    call .Lrt_lu_getrs
.Lrt_lu_sv_free:
    movq RT_LU_SV_S(%rsp), %rdi
    movq RT_LU_SV_SB(%rsp), %rsi
    call sea_free_block             # the scratch goes before the entry returns
.Lrt_lu_sv_ret:
    movq %r15, %rax
    addq $RT_LU_SV_LOCALS, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret
.Lrt_lu_sv_singular:
    movq RT_LU_SV_S(%rsp), %rdi     # free the scratch and X, then the error
    movq RT_LU_SV_SB(%rsp), %rsi
    call sea_free_block
    movq %r15, %rdi
    call sea_free                   # X has count 1: freed and uncounted
    movl $SEA_E_SINGULAR, %edi
    movq %r13, %rsi
    xorl %edx, %edx
    call sea_err                    # noreturn
    ud2
.Lrt_lu_sv_square:
    movq %rbx, %rdi
    movq %r13, %rsi
    call .Lrt_lu_square_err         # noreturn
.Lrt_lu_sv_shape:
    movq %r14, %rdi
    movq %r12, %rsi
    movq %r13, %rdx
    call .Lrt_lu_shape_err          # noreturn
    .size sea_solve, . - sea_solve

# ---------------------------------------------------------------------
# .Lrt_lu_rcsolve -- x = U^-1 L^-1 x (RCOND's first solve, no
#   interchanges, unblocked): L forward, unit: for k ascending, x[i] =
#   x[i] - F[i,k]*x[k] for i > k; then U backward: for k descending,
#   x[k] = x[k] / F[k,k], then x[i] = x[i] - F[i,k]*x[k] for i < k.
#   Inputs  : %rdi = F (n x n, ld n), %rsi = n (>= 1), %rdx = x
#   Outputs : x overwritten
#   Clobbers: %rax %rcx %rdx %rdi %rsi %r8-%r11 %xmm0-%xmm2, flags
#   Callee-saved used: %rbp the frame pointer
#   Frame   : 8 bytes (%rbp)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_lu_rcsolve:
    pushq %rbp
    movq %rsp, %rbp
    movq %rdi, %r8                  # F
    movq %rsi, %r9                  # n
    movq %rdx, %r10                 # x
    xorl %ecx, %ecx                 # k
1:  leaq 1(%rcx), %rax
    cmpq %r9, %rax
    jae 2f                          # k = n-1 has nothing below it
    movq %rcx, %r11
    imulq %r9, %r11
    leaq (%r8,%r11,8), %r11         # column k
    movsd (%r10,%rcx,8), %xmm0      # x[k]
    leaq 8(%r10,%rcx,8), %rdi
    leaq 8(%r11,%rcx,8), %rsi
    movq %r9, %rdx
    subq %rcx, %rdx
    decq %rdx
    call .Lrt_lu_axpy               # x[i] - F[i,k]*x[k], i > k
    incq %rcx
    jmp 1b
2:  leaq -1(%r9), %rcx              # k = n-1 down to 0
3:  movq %rcx, %r11
    imulq %r9, %r11
    leaq (%r8,%r11,8), %r11
    movsd (%r10,%rcx,8), %xmm0
    divsd (%r11,%rcx,8), %xmm0      # x[k] / F[k,k]
    movsd %xmm0, (%r10,%rcx,8)
    movq %r10, %rdi
    movq %r11, %rsi
    movq %rcx, %rdx
    call .Lrt_lu_axpy               # x[i] - F[i,k]*x[k], i < k
    testq %rcx, %rcx
    jz 4f
    decq %rcx
    jmp 3b
4:  popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_lu_rcsolvet -- x = L^-T U^-T x (RCOND's second solve): U' forward:
#   for k ascending, x[k] = (x[k] - F[0,k]*x[0] - ... - F[k-1,k]*x[k-1])
#   / F[k,k]; then L' backward, unit: for k descending, x[k] = x[k] -
#   F[k+1,k]*x[k+1] - ... - F[n-1,k]*x[n-1] (subtractions in index order).
#   Inputs  : %rdi = F, %rsi = n (>= 1), %rdx = x
#   Outputs : x overwritten
#   Clobbers: %rax %rcx %rdx %rdi %rsi %r8-%r11 %xmm0 %xmm1, flags
#   Callee-saved used: %rbp the frame pointer
#   Frame   : 8 bytes (%rbp)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_lu_rcsolvet:
    pushq %rbp
    movq %rsp, %rbp
    movq %rdi, %r8
    movq %rsi, %r9
    movq %rdx, %r10
    xorl %ecx, %ecx                 # k ascending
1:  cmpq %r9, %rcx
    jae 2f
    movq %rcx, %r11
    imulq %r9, %r11
    leaq (%r8,%r11,8), %r11         # column k
    movsd (%r10,%rcx,8), %xmm0
    movq %r11, %rdi                 # F[0.., k]
    movq %r10, %rsi                 # x[0..]
    movq %rcx, %rdx
    call .Lrt_lu_dotsub             # x[k] - F[i,k]*x[i], i = 0 .. k-1
    divsd (%r11,%rcx,8), %xmm0      # / F[k,k]
    movsd %xmm0, (%r10,%rcx,8)
    incq %rcx
    jmp 1b
2:  leaq -1(%r9), %rcx              # k descending
3:  movq %rcx, %r11
    imulq %r9, %r11
    leaq (%r8,%r11,8), %r11
    movsd (%r10,%rcx,8), %xmm0
    leaq 8(%r11,%rcx,8), %rdi       # F[k+1.., k]
    leaq 8(%r10,%rcx,8), %rsi       # x[k+1..]
    movq %r9, %rdx
    subq %rcx, %rdx
    decq %rdx
    call .Lrt_lu_dotsub             # x[k] - F[i,k]*x[i], i = k+1 .. n-1
    movsd %xmm0, (%r10,%rcx,8)
    testq %rcx, %rcx
    jz 4f
    decq %rcx
    jmp 3b
4:  popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_lu_asum -- %xmm0 = |x[0]| + |x[1]| + ... (index order, from +0).
#   Outputs : %xmm0 = the sum
#   Inputs  : %rdi = x, %rsi = n (>= 1)
#   Clobbers: %rdi %rsi %xmm0 %xmm1, flags
#   Callee-saved used: none
#   Frame   : none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_lu_asum:
    xorpd %xmm0, %xmm0
1:  movsd (%rdi), %xmm1
    andpd .Lrt_lu_abs(%rip), %xmm1
    addsd %xmm1, %xmm0
    addq $8, %rdi
    decq %rsi
    jnz 1b
    ret

# ---------------------------------------------------------------------
# .Lrt_lu_idamax -- %rax = the first index of largest |x[i]| (BLAS
#   idamax: start at 0, move only to a strictly greater magnitude).
#   Inputs  : %rdi = x, %rsi = n (>= 1)
#   Clobbers: %rax %rcx %xmm0 %xmm1, flags
#   Callee-saved used: none
#   Frame   : none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_lu_idamax:
    xorl %eax, %eax
    movsd (%rdi), %xmm0
    andpd .Lrt_lu_abs(%rip), %xmm0  # m = |x[0]|
    movl $1, %ecx
1:  cmpq %rsi, %rcx
    jae 3f
    movsd (%rdi,%rcx,8), %xmm1
    andpd .Lrt_lu_abs(%rip), %xmm1
    ucomisd %xmm0, %xmm1
    jbe 2f                          # not strictly greater (or NaN)
    movq %rcx, %rax
    movapd %xmm1, %xmm0
2:  incq %rcx
    jmp 1b
3:  ret

# ---------------------------------------------------------------------
# .Lrt_lu_sgn -- xi[i] = sgn(x[i]) and x[i] = xi[i]: +1 when x[i] >= 0
#   (so -0 gives +1), else -1 (so NaN gives -1) (dlacn2's rule).
#   Outputs : x and xi written
#   Inputs  : %rdi = x, %rsi = xi, %rdx = n (>= 1)
#   Clobbers: %rax %rcx %rdx %rdi %rsi %xmm0 %xmm1, flags
#   Callee-saved used: none
#   Frame   : none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_lu_sgn:
    xorpd %xmm1, %xmm1
1:  movsd (%rdi), %xmm0
    movq .Lrt_lu_one(%rip), %rax    # +1
    movq .Lrt_lu_mone(%rip), %rcx   # -1
    ucomisd %xmm1, %xmm0
    cmovb %rcx, %rax                # x < 0 or unordered (CF set): -1
    movq %rax, (%rsi)
    movq %rax, (%rdi)
    addq $8, %rdi
    addq $8, %rsi
    decq %rdx
    jnz 1b
    ret

# ---------------------------------------------------------------------
# .Lrt_lu_samesgn -- %rax = 1 when sgn(x[i]) = xi[i] for every i, else 0.
#   Inputs  : %rdi = x, %rsi = xi, %rdx = n (>= 1)
#   Clobbers: %rax %rcx %rdx %rdi %rsi %r8 %xmm0 %xmm1, flags
#   Callee-saved used: none
#   Frame   : none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_lu_samesgn:
    xorpd %xmm1, %xmm1
1:  movsd (%rdi), %xmm0
    movq .Lrt_lu_one(%rip), %rax
    movq .Lrt_lu_mone(%rip), %rcx
    ucomisd %xmm1, %xmm0
    cmovb %rcx, %rax                # sgn(x[i])
    cmpq (%rsi), %rax
    jne 2f
    addq $8, %rdi
    addq $8, %rsi
    decq %rdx
    jnz 1b
    movl $1, %eax
    ret
2:  xorl %eax, %eax
    ret

# RT_LU_RCCHK -- inside sea_rcond, right after each solve: s = sum |x|
#   (index order, .Lrt_lu_asum); s = +Inf or NaN: rcond is 0 at once
#   (.Lrt_lu_rc_abort frees the scratch). Uses %r14 = x, %r13 = n.
#   Clobbers %rdi %rsi %xmm0 %xmm1, flags.
.macro RT_LU_RCCHK
    movq %r14, %rdi
    movq %r13, %rsi
    call .Lrt_lu_asum
    ucomisd %xmm0, %xmm0
    jp .Lrt_lu_rc_abort             # NaN
    ucomisd .Lrt_lu_inf(%rip), %xmm0
    je .Lrt_lu_rc_abort             # +Inf
.endm

# ---------------------------------------------------------------------
# sea_rcond -- the entry RCOND (DESIGN.md 2.13.6 "RCOND": dgecon with
#   dlacn2, no interchanges).
#   Purpose : L-io's values in Decision 129's order: order 0: +Inf;
#             ||A||_1 NaN: NaN; a recorded zero pivot: 0; ||A||_1 = 0 or
#             +Inf: 0; else est, the estimate of ||U^-1 L^-1||_1 by the
#             steps 1-3 of 2.13.6, where after every solve s = sum |x|
#             (index order) is +Inf or NaN gives 0 at once (the user's
#             spec change of 8c: diag(1, 2^-1070) meets 0 * Inf = NaN in
#             a solve); then 0 when est is +Inf, NaN or 0, else
#             (1 / est) / ||A||_1. The two vectors x and xi are one
#             scratch block (16n bytes).
#   Inputs  : %rdi = F (an Lu, borrowed), %rsi = site
#   Outputs : %xmm0 = rcond
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = the factor, %r12 =
#             site, %r13 = n, %r14 = x, %r15 = xi; %rbp
#   Frame   : 48 bytes + 40 (est, estold, iter, j, ||A||_1) = 88 bytes
# ---------------------------------------------------------------------
    .globl sea_rcond
    .type sea_rcond, @function
    .p2align 4
sea_rcond:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $RT_LU_RC_LOCALS, %rsp     # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
    movq RT_LU_H_N(%rbx), %r13      # n
    testq %r13, %r13
    jz .Lrt_lu_rc_inf               # order 0: +Inf
    movsd RT_LU_H_NORM(%rbx), %xmm0
    ucomisd %xmm0, %xmm0
    jp .Lrt_lu_rc_ret               # ||A||_1 NaN: NaN (that NaN)
    cmpq $0, RT_LU_H_ZP(%rbx)
    jge .Lrt_lu_rc_zero             # a zero pivot: 0
    xorpd %xmm1, %xmm1
    ucomisd %xmm1, %xmm0
    je .Lrt_lu_rc_zero              # ||A||_1 = 0: 0
    ucomisd .Lrt_lu_inf(%rip), %xmm0
    je .Lrt_lu_rc_zero              # ||A||_1 = +Inf: 0
    movsd %xmm0, RT_LU_RC_NORM(%rsp)
    leaq RT_LU_H_F(%rbx), %rbx      # the factor from here on

    # The scratch: x and xi, n doubles each.
    movq %r13, %rdi
    shlq $4, %rdi
    movq %r12, %rsi
    call sea_alloc
    movq %rax, %r14
    leaq (%r14,%r13,8), %r15

    # 1. x[i] = 1/n (one division); x = U^-1 L^-1 x.
    cvtsi2sdq %r13, %xmm1
    movsd .Lrt_lu_one(%rip), %xmm0
    divsd %xmm1, %xmm0
    xorl %ecx, %ecx
1:  movsd %xmm0, (%r14,%rcx,8)
    incq %rcx
    cmpq %r13, %rcx
    jb 1b
    movq %rbx, %rdi
    movq %r13, %rsi
    movq %r14, %rdx
    call .Lrt_lu_rcsolve
    RT_LU_RCCHK
    cmpq $1, %r13
    jne 2f
    movsd (%r14), %xmm0             # n = 1: est = |x[0]|
    andpd .Lrt_lu_abs(%rip), %xmm0
    movsd %xmm0, RT_LU_RC_EST(%rsp)
    jmp .Lrt_lu_rc_free
2:  movq %r14, %rdi                 # est = sum |x|
    movq %r13, %rsi
    call .Lrt_lu_asum
    movsd %xmm0, RT_LU_RC_EST(%rsp)
    movq %r14, %rdi                 # xi = sgn(x); x = xi
    movq %r15, %rsi
    movq %r13, %rdx
    call .Lrt_lu_sgn
    movq %rbx, %rdi                 # x = L^-T U^-T x
    movq %r13, %rsi
    movq %r14, %rdx
    call .Lrt_lu_rcsolvet
    RT_LU_RCCHK
    movq %r14, %rdi
    movq %r13, %rsi
    call .Lrt_lu_idamax
    movq %rax, RT_LU_RC_J(%rsp)     # j
    movq $2, RT_LU_RC_ITER(%rsp)    # iter = 2

    # 2. x = e_j; x = U^-1 L^-1 x; the tests; the next j.
.Lrt_lu_rc_step2:
    movq %r14, %rdi
    movq %r13, %rcx
    xorl %eax, %eax
    rep stosq                       # x = +0 ...
    movq RT_LU_RC_J(%rsp), %rax
    movq .Lrt_lu_one(%rip), %rcx
    movq %rcx, (%r14,%rax,8)        # ... x[j] = 1
    movq %rbx, %rdi
    movq %r13, %rsi
    movq %r14, %rdx
    call .Lrt_lu_rcsolve
    RT_LU_RCCHK
    movsd RT_LU_RC_EST(%rsp), %xmm0
    movsd %xmm0, RT_LU_RC_ESTOLD(%rsp)  # estold = est
    movq %r14, %rdi
    movq %r13, %rsi
    call .Lrt_lu_asum
    movsd %xmm0, RT_LU_RC_EST(%rsp)     # est = sum |x|
    movq %r14, %rdi
    movq %r15, %rsi
    movq %r13, %rdx
    call .Lrt_lu_samesgn
    testq %rax, %rax
    jnz .Lrt_lu_rc_step3            # the sign vector repeats
    movsd RT_LU_RC_ESTOLD(%rsp), %xmm1
    ucomisd RT_LU_RC_EST(%rsp), %xmm1
    jae .Lrt_lu_rc_step3            # est <= estold (ordered)
    movq %r14, %rdi                 # xi = sgn(x); x = xi
    movq %r15, %rsi
    movq %r13, %rdx
    call .Lrt_lu_sgn
    movq %rbx, %rdi                 # x = L^-T U^-T x
    movq %r13, %rsi
    movq %r14, %rdx
    call .Lrt_lu_rcsolvet
    RT_LU_RCCHK
    movq %r14, %rdi
    movq %r13, %rsi
    call .Lrt_lu_idamax             # the new j
    movq RT_LU_RC_J(%rsp), %rcx     # jlast
    movq %rax, RT_LU_RC_J(%rsp)
    movsd (%r14,%rcx,8), %xmm0      # x[jlast]
    movsd (%r14,%rax,8), %xmm1
    andpd .Lrt_lu_abs(%rip), %xmm1  # |x[j]|
    ucomisd %xmm1, %xmm0
    jp 3f                           # unordered: not equal
    je .Lrt_lu_rc_step3             # x[jlast] = |x[j]|
3:  cmpq $SEA_RCOND_ITMAX, RT_LU_RC_ITER(%rsp)
    jge .Lrt_lu_rc_step3
    incq RT_LU_RC_ITER(%rsp)
    jmp .Lrt_lu_rc_step2

    # 3. x[i] = s_i * (1 + i / (n-1)), s alternating from +1; t.
.Lrt_lu_rc_step3:
    leaq -1(%r13), %rax
    cvtsi2sdq %rax, %xmm2           # n - 1 (n >= 2 here)
    xorl %ecx, %ecx
4:  cvtsi2sdq %rcx, %xmm0
    divsd %xmm2, %xmm0              # i / (n-1)
    addsd .Lrt_lu_one(%rip), %xmm0  # 1 + i / (n-1)
    testb $1, %cl
    jz 5f
    xorpd .Lrt_lu_sign(%rip), %xmm0 # odd i: -
5:  movsd %xmm0, (%r14,%rcx,8)
    incq %rcx
    cmpq %r13, %rcx
    jb 4b
    movq %rbx, %rdi
    movq %r13, %rsi
    movq %r14, %rdx
    call .Lrt_lu_rcsolve
    RT_LU_RCCHK
    movq %r14, %rdi
    movq %r13, %rsi
    call .Lrt_lu_asum               # sum |x|
    leaq (%r13,%r13,2), %rax
    cvtsi2sdq %rax, %xmm1           # 3n
    divsd %xmm1, %xmm0              # sum |x| / (3n)
    mulsd .Lrt_lu_two(%rip), %xmm0  # t = 2 * (...)
    ucomisd RT_LU_RC_EST(%rsp), %xmm0
    jbe .Lrt_lu_rc_free             # not t > est
    movsd %xmm0, RT_LU_RC_EST(%rsp)

.Lrt_lu_rc_free:
    movq %r14, %rdi                 # the scratch goes before the entry returns
    movq %r13, %rsi
    shlq $4, %rsi
    call sea_free_block

    # 4. rcond = 0 when est is +Inf, NaN or 0, else (1 / est) / ||A||_1.
    movsd RT_LU_RC_EST(%rsp), %xmm1
    ucomisd %xmm1, %xmm1
    jp .Lrt_lu_rc_zero
    xorpd %xmm0, %xmm0
    ucomisd %xmm0, %xmm1
    je .Lrt_lu_rc_zero              # est = 0
    ucomisd .Lrt_lu_inf(%rip), %xmm1
    je .Lrt_lu_rc_zero
    movsd .Lrt_lu_one(%rip), %xmm0
    divsd %xmm1, %xmm0              # 1 / est
    divsd RT_LU_RC_NORM(%rsp), %xmm0    # / ||A||_1
    jmp .Lrt_lu_rc_ret
.Lrt_lu_rc_abort:
    movq %r14, %rdi                 # a solve gave a non-finite sum: free the scratch, rcond 0
    movq %r13, %rsi
    shlq $4, %rsi
    call sea_free_block
    jmp .Lrt_lu_rc_zero
.Lrt_lu_rc_inf:
    movsd .Lrt_lu_inf(%rip), %xmm0
    jmp .Lrt_lu_rc_ret
.Lrt_lu_rc_zero:
    xorpd %xmm0, %xmm0              # +0
.Lrt_lu_rc_ret:
    addq $RT_LU_RC_LOCALS, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret
    .size sea_rcond, . - sea_rcond

    .section .rodata
    .p2align 4
.Lrt_lu_abs:
    .quad 0x7FFFFFFFFFFFFFFF, 0x7FFFFFFFFFFFFFFF   # |x| mask, both lanes
.Lrt_lu_sign:
    .quad 0x8000000000000000, 0x8000000000000000   # the sign bit, both lanes
.Lrt_lu_one:
    .quad 0x3FF0000000000000        # 1.0
.Lrt_lu_mone:
    .quad 0xBFF0000000000000        # -1.0
.Lrt_lu_two:
    .quad 0x4000000000000000        # 2.0
.Lrt_lu_inf:
    .quad 0x7FF0000000000000        # +Inf

    .section .note.GNU-stack,"",@progbits
