# =====================================================================
# sea/runtime/x86_64_linux/rt_eig.s -- eigenvalues of a symmetric matrix
# and of a symmetric-definite pencil (DESIGN.md 2.13.5 entries EIG_SYM,
# EIG_SYM_GEN; 2.13.6 "EIG_SYM", "EIG_SYM_GEN", "Private routines";
# Decisions 121, 123; L-ip, L-iy; LANGUAGE.md 10.8). The x86_64-linux
# twin of runtime/arm64_macos/rt_eig.s.
#
# Defines (global, rt.inc SEA_ENTRY_LIST):
#   sea_eig_sym     (A, site) -> a new f64 vector of the n eigenvalues of
#                   the symmetric matrix A, ascending
#   sea_eig_sym_gen (K, M, site) -> a new f64 vector of the eigenvalues
#                   of K x = lambda M x, ascending
# Uses: sea_la_potrf, sea_la_issym (rt_lu.s, the private routines of
#       2.13.6, L-jc), sea_hypot (rt_math.s), sea_alloc, sea_free_block,
#       sea_free (rt_mem.s), sea_arr_new_u (rt_arr.s), sea_err (rt_err.s).
#
# Matrices are column-major: element (i, j) of an n x n matrix is at
# DATA + 8 * (i + j * n).
#
# Algorithm (Decision 121 (a)): EISPACK tred1 (Householder reduction of
# the lower triangle to a symmetric tridiagonal (d, e), with its scaling
# of each row by the sum of magnitudes; eigenvalues only) then tql1 (the
# implicit QL iteration with its shifts and its ordering step), each
# operation as the published algorithm writes it, transcribed 0-based:
# pythag(a, b) = sea_hypot(a, b), SIGN(a, b) = |a| with b's sign bit,
# tql1's convergence test tst1 + |e[m]| = tst1, at most SEA_EIG_MAXIT
# iterations per eigenvalue (a failure makes that eigenvalue and every
# later one NaN, L-ip). The search for a small subdiagonal element stops
# at m = n - 1 (tql1's "e(n) is always zero, so there is no exit through
# the bottom of the loop"; it differs from testing e[n-1] only when tst1
# is NaN). The n values are then sorted stably by LANGUAGE.md 10.6's f64
# order (ascending, -0 = +0, NaN last), a no-op unless a NaN occurs.
# EIG_SYM_GEN (dsygst itype 1, the plain form): R = sea_la_potrf of a
# copy of M; Z = R^-T K column by column, C = Z R^-1 row by row, both
# unblocked, in one n x n area (each step overwrites the element it has
# just read last); then tred1 and tql1 on C's lower triangle.
#
# Operation order (L-it): every sum, product and division is the one the
# spec writes, in its order, one scalar SSE2 instruction each (no FMA,
# true divisions, sqrtsd), so both targets give the same bits; this one
# form is used under every variant. Fortran's A - B*C - D*E is (A - B*C)
# - D*E; -X*Y*.../W is the negated left-to-right product and quotient
# (round to nearest is symmetric, so the negation's place changes no bit).
#
# Memory: the result by sea_arr_new_u (rank 1, rows n, cols 1; every
# element written: the d of tred1/tql1 lives in it), allocated before
# the one scratch block of a call (sea_alloc), which is freed with
# sea_free_block before the entry returns: EIG_SYM 8n^2 (the copy of A)
# + 8n (e); EIG_SYM_GEN 8n^2 (R) + 8n^2 (Z, then C) + 8n (e) + 8n*NB
# (sea_la_potrf's W, only when n > NB). n = 0 and the n-NaN results use
# no scratch. NOT_POSDEF frees the scratch and the result (sea_free:
# uncounted) before sea_err, so a failing call leaves the live count as
# it was.
#
# ABI: System V AMD64; the entries preserve %rbx %rbp %r12-%r15 and
# %rsp, never change MXCSR, and leave the direction flag clear (rep movsq
# runs with it clear, as the ABI guarantees on entry). The local routines
# (.Lrt_eig_*) state their own clobbers. Stack (below the entry's return
# address): an entry's frame (72 bytes) plus a return address and
# .Lrt_eig_core's frame (24 at its call of .Lrt_eig_tql1; 40 at the leaf
# .Lrt_eig_tred1, which pushes 48) plus a return address and
# .Lrt_eig_tql1's frame (168) plus a return address and sea_hypot (a
# leaf, no frame): 288 bytes, the deepest own path (measured: 288 for
# EIG_SYM; 440 for EIG_SYM_GEN, its 256 bytes to sea_la_potrf's frame
# (168, rt_lu.s) plus bsk_kern_gemm_sub's below it, every variant);
# sea_alloc, sea_arr_new_u, sea_free, sea_err and Baysick's kernel run
# below the entry's frame, covered by SEA_STACK_MARGIN.
# =====================================================================
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

# ---- frames ----------------------------------------------------------
# Every frame below is entered at %rsp = 8 (mod 16); after the pushes
# of %rbp %rbx %r12-%r15 (48 bytes) %rsp = 8 (mod 16), so every locals
# size is 8 (mod 16).
# The entries: the scratch block and its byte count.
.equ RT_EIG_E_S,        0
.equ RT_EIG_E_SB,       8
.equ RT_EIG_E_LOCALS,   24
# .Lrt_eig_tql1's doubles and words.
.equ RT_EIG_Q_F,        0           # f, the accumulated shift
.equ RT_EIG_Q_TST1,     8
.equ RT_EIG_Q_C,        16
.equ RT_EIG_Q_C2,       24
.equ RT_EIG_Q_C3,       32
.equ RT_EIG_Q_S,        40
.equ RT_EIG_Q_S2,       48
.equ RT_EIG_Q_P,        56
.equ RT_EIG_Q_G,        64
.equ RT_EIG_Q_H,        72
.equ RT_EIG_Q_EL1,      80
.equ RT_EIG_Q_DL1,      88
.equ RT_EIG_Q_J,        96          # the iteration count of this l
.equ RT_EIG_Q_M,        104
.equ RT_EIG_Q_LOCALS,   120
# The error helpers: four slots.
.equ RT_EIG_ERR_LOCALS, (4 * SEA_SLOT_SIZE)

.if ((RT_EIG_E_LOCALS % 16) != 8) || ((RT_EIG_Q_LOCALS % 16) != 8)
    .error "rt_eig: frames must keep %rsp aligned"
.endif
.if (48 + RT_EIG_E_LOCALS + 8 + 24 + 8 + 48 + RT_EIG_Q_LOCALS + 8) > 512
    .error "rt_eig: the deepest own path exceeds 512 bytes"
.endif
.if (48 + RT_EIG_E_LOCALS + 8 + 168) > 512
    .error "rt_eig: the entry and sea_la_potrf's frame exceed 512 bytes"
.endif

    .text

# =====================================================================
# Leaf helpers
# =====================================================================

# ---------------------------------------------------------------------
# .Lrt_eig_finite -- are all cnt doubles at p finite?
#   Inputs  : %rdi = p, %rsi = cnt (>= 0)
#   Outputs : %rax = 1 if none is +-Inf or NaN, else 0
#   Clobbers: %rcx %rdx %rdi %rsi, flags
#   Frame   : none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_eig_finite:
    movabsq $0x7FF0000000000000, %rdx   # the exponent field
1:  testq %rsi, %rsi
    jz 2f
    movq (%rdi), %rcx
    andq %rdx, %rcx
    cmpq %rdx, %rcx
    je 3f                           # exponent all ones: +-Inf or NaN
    addq $8, %rdi
    decq %rsi
    jmp 1b
2:  movl $1, %eax
    ret
3:  xorl %eax, %eax
    ret

# ---------------------------------------------------------------------
# .Lrt_eig_nanfill -- set cnt doubles at p to NaN (#7FF8000000000000).
#   Inputs  : %rdi = p, %rsi = cnt (>= 0)
#   Outputs : the doubles written
#   Clobbers: %rax %rcx %rdi, flags
#   Frame   : none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_eig_nanfill:
    movabsq $0x7FF8000000000000, %rax
    movq %rsi, %rcx
    rep stosq
    ret

# ---------------------------------------------------------------------
# .Lrt_eig_sort -- the stable insertion sort of LANGUAGE.md 10.6's f64
#   order: v moves below d[j-1] only when v is a number and d[j-1] is NaN
#   or greater than v (so -0 = +0 and equal values keep their order, NaN
#   last).
#   Inputs  : %rdi = d, %rsi = n (>= 0)
#   Outputs : d sorted in place
#   Clobbers: %rcx %rdx %xmm0 %xmm1, flags
#   Frame   : none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_eig_sort:
    movl $1, %ecx                   # i
1:  cmpq %rsi, %rcx
    jae 5f
    movsd (%rdi,%rcx,8), %xmm0      # v = d[i]
    movq %rcx, %rdx                 # j
    ucomisd %xmm0, %xmm0
    jp 4f                           # v is NaN: it stays
2:  testq %rdx, %rdx
    jz 4f
    movsd -8(%rdi,%rdx,8), %xmm1    # d[j-1]
    ucomisd %xmm1, %xmm1
    jp 3f                           # d[j-1] NaN: v goes below it
    ucomisd %xmm0, %xmm1
    jbe 4f                          # d[j-1] <= v: stop
3:  movsd %xmm1, (%rdi,%rdx,8)      # d[j] = d[j-1]
    decq %rdx
    jmp 2b
4:  movsd %xmm0, (%rdi,%rdx,8)      # d[j] = v
    incq %rcx
    jmp 1b
5:  ret

# ---------------------------------------------------------------------
# .Lrt_eig_rtk -- Z = R^-T K in place, column by column: for each column
#   c, for j ascending: Z[j,c] = (Z[j,c] - R[0,j]*Z[0,c] - ... -
#   R[j-1,j]*Z[j-1,c]) / R[j,j] (Z holds K on entry; subtractions in kk
#   order, true divisions).
#   Inputs  : %rdi = R (n x n, ld n; Z follows it at R + 8n^2),
#             %rsi = n (>= 1)
#   Outputs : Z written
#   Clobbers: %rax %rcx %rdx %r8-%r11 %xmm0 %xmm1, flags
#   Frame   : none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_eig_rtk:
    leaq (,%rsi,8), %rdx            # 8n, the column stride
    movq %rsi, %rax
    imulq %rdx, %rax
    leaq (%rdi,%rax), %r8           # &Z[0, c], c = 0
    xorl %r9d, %r9d                 # c
1:  xorl %r10d, %r10d               # j
    movq %rdi, %r11                 # &R[0, j]
2:  movsd (%r8,%r10,8), %xmm0       # t = Z[j,c] (K[j,c])
    xorl %ecx, %ecx                 # kk
3:  cmpq %r10, %rcx
    jae 4f
    movsd (%r11,%rcx,8), %xmm1      # R[kk,j]
    mulsd (%r8,%rcx,8), %xmm1       # * Z[kk,c]
    subsd %xmm1, %xmm0
    incq %rcx
    jmp 3b
4:  divsd (%r11,%r10,8), %xmm0      # / R[j,j]
    movsd %xmm0, (%r8,%r10,8)
    addq %rdx, %r11
    incq %r10
    cmpq %rsi, %r10
    jb 2b
    addq %rdx, %r8                  # the next column of Z
    incq %r9
    cmpq %rsi, %r9
    jb 1b
    ret

# ---------------------------------------------------------------------
# .Lrt_eig_zri -- C = Z R^-1 in place, row by row: for each row r, for j
#   ascending: C[r,j] = (Z[r,j] - R[0,j]*C[r,0] - ... - R[j-1,j]*
#   C[r,j-1]) / R[j,j] (subtractions in kk order, true divisions).
#   Inputs  : %rdi = R (n x n, ld n; Z, then C, follows it at R + 8n^2),
#             %rsi = n (>= 1)
#   Outputs : C written over Z
#   Clobbers: %rax %rcx %rdx %r8-%r11 %xmm0 %xmm1, flags
#   Frame   : 8 bytes (the row cursor pushed), leaf
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_eig_zri:
    leaq (,%rsi,8), %rdx            # 8n, the column stride
    movq %rsi, %rax
    imulq %rdx, %rax
    leaq (%rdi,%rax), %r8           # &C[r, 0], r = 0
    xorl %r9d, %r9d                 # r
1:  xorl %r10d, %r10d               # j
    movq %rdi, %r11                 # &R[0, j]
2:  movq %r10, %rax
    imulq %rdx, %rax
    movsd (%r8,%rax), %xmm0         # t = Z[r,j]
    xorl %ecx, %ecx                 # kk
    pushq %r8                       # &C[r, kk], walked along the row
3:  cmpq %r10, %rcx
    jae 4f
    movsd (%r11,%rcx,8), %xmm1      # R[kk,j]
    mulsd (%r8), %xmm1              # * C[r,kk]
    subsd %xmm1, %xmm0
    addq %rdx, %r8
    incq %rcx
    jmp 3b
4:  popq %r8
    divsd (%r11,%r10,8), %xmm0      # / R[j,j]
    movsd %xmm0, (%r8,%rax)         # C[r,j]
    addq %rdx, %r11
    incq %r10
    cmpq %rsi, %r10
    jb 2b
    addq $8, %r8                    # the next row
    incq %r9
    cmpq %rsi, %r9
    jb 1b
    ret

# ---------------------------------------------------------------------
# .Lrt_eig_tred1 -- EISPACK tred1 (0-based): reduce the lower triangle
#   of the n x n matrix a (ld n) to a symmetric tridiagonal: d the
#   diagonal, e[1 .. n-1] the subdiagonal, e[0] = 0. a is overwritten.
#     for i: d[i] = a[n-1,i]; a[n-1,i] = a[i,i]
#     for i = n-1 down to 0: l = i-1; i = 0: e[0] = 0, done;
#       scale = 0 + |d[0]| + ... + |d[l]|;
#       scale = 0: for j <= l: d[j] = a[l,j]; a[l,j] = a[i,j];
#         a[i,j] = 0; e[i] = 0; next i;
#       h = 0; for k <= l: d[k] = d[k]/scale; h = h + d[k]*d[k];
#       f = d[l]; g = -SIGN(sqrt(h), f); e[i] = scale*g; h = h - f*g;
#       d[l] = f - g;
#       l > 0: e[0..l] = 0; for j <= l: f = d[j]; g = e[j] + a[j,j]*f;
#           for k = j+1 .. l: g = g + a[k,j]*d[k]; e[k] = e[k] +
#           a[k,j]*f; e[j] = g;
#         f = 0; for j <= l: e[j] = e[j]/h; f = f + e[j]*d[j];
#         h = f/(h + h); for j <= l: e[j] = e[j] - h*d[j];
#         for j <= l: f = d[j]; g = e[j]; for k = j .. l: a[k,j] =
#           (a[k,j] - f*e[k]) - g*d[k];
#       for j <= l: f = d[j]; d[j] = a[l,j]; a[l,j] = a[i,j];
#         a[i,j] = f*scale
#   Inputs  : %rdi = a, %rsi = n (>= 1), %rdx = d, %rcx = e
#   Outputs : d, e written
#   Clobbers: %rax %rsi %r8-%r11 %xmm0-%xmm6 %xmm8-%xmm11, flags
#   Callee-saved used (saved and restored): %rbx = i, %r12 = l, %r13 = j,
#             %r14 = k, %r15 = a pointer; %rbp = n
#   Frame   : 48 bytes (%rbp %rbx %r12-%r15), leaf
#   Registers: %rdi = a, %rsi = 8n (the column stride), %rdx = d,
#             %rcx = e; %xmm8 = scale, %xmm9 = h, %xmm10 = f, %xmm11 = g
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_eig_tred1:
    pushq %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    movq %rsi, %rbp                 # n
    shlq $3, %rsi                   # 8n
    # d[i] = a[n-1,i]; a[n-1,i] = a[i,i].
    leaq -8(%rdi,%rsi), %r8         # &a[n-1, 0]
    movq %rdi, %r9                  # &a[0, 0]
    xorl %ebx, %ebx
1:  movq (%r8), %rax
    movq %rax, (%rdx,%rbx,8)        # d[i] = a[n-1, i]
    movq (%r9), %rax
    movq %rax, (%r8)                # a[n-1, i] = a[i, i]
    addq %rsi, %r8
    leaq 8(%r9,%rsi), %r9           # the next diagonal element
    incq %rbx
    cmpq %rbp, %rbx
    jb 1b

    leaq -1(%rbp), %rbx             # i = n-1
.Lrt_eig_t1_i:
    testq %rbx, %rbx
    jz .Lrt_eig_t1_last
    leaq -1(%rbx), %r12             # l = i-1
    # scale = 0 + |d[0]| + ... + |d[l]|, in order.
    xorpd %xmm8, %xmm8
    movapd .Lrt_eig_abs(%rip), %xmm6
    xorl %r14d, %r14d
1:  movsd (%rdx,%r14,8), %xmm0
    andpd %xmm6, %xmm0
    addsd %xmm0, %xmm8
    incq %r14
    cmpq %r12, %r14
    jbe 1b
    xorpd %xmm0, %xmm0
    ucomisd %xmm0, %xmm8
    jp .Lrt_eig_t1_scaled           # NaN is not 0 (.ne. holds)
    jne .Lrt_eig_t1_scaled
    # scale = 0: d[j] = a[l,j]; a[l,j] = a[i,j]; a[i,j] = 0; e[i] = 0.
    leaq (%rdi,%r12,8), %r8         # &a[l, 0]
    leaq (%rdi,%rbx,8), %r9         # &a[i, 0]
    xorl %r13d, %r13d
2:  movq (%r8), %rax
    movq %rax, (%rdx,%r13,8)
    movq (%r9), %rax
    movq %rax, (%r8)
    movq $0, (%r9)                  # +0
    addq %rsi, %r8
    addq %rsi, %r9
    incq %r13
    cmpq %r12, %r13
    jbe 2b
    movq $0, (%rcx,%rbx,8)          # e[i] = 0
    jmp .Lrt_eig_t1_next

.Lrt_eig_t1_scaled:
    # d[k] = d[k]/scale; h = h + d[k]*d[k].
    xorpd %xmm9, %xmm9              # h = 0
    xorl %r14d, %r14d
3:  movsd (%rdx,%r14,8), %xmm0
    divsd %xmm8, %xmm0
    movsd %xmm0, (%rdx,%r14,8)
    mulsd %xmm0, %xmm0
    addsd %xmm0, %xmm9
    incq %r14
    cmpq %r12, %r14
    jbe 3b
    # f = d[l]; g = -SIGN(sqrt(h), f).
    movsd (%rdx,%r12,8), %xmm10     # f
    sqrtsd %xmm9, %xmm11
    andpd .Lrt_eig_abs(%rip), %xmm11    # |sqrt(h)|
    movapd %xmm10, %xmm0
    andpd .Lrt_eig_sign(%rip), %xmm0    # f's sign bit
    orpd %xmm0, %xmm11
    xorpd .Lrt_eig_sign(%rip), %xmm11   # g = -SIGN(sqrt(h), f)
    # e[i] = scale*g; h = h - f*g; d[l] = f - g.
    movapd %xmm8, %xmm0
    mulsd %xmm11, %xmm0
    movsd %xmm0, (%rcx,%rbx,8)
    movapd %xmm10, %xmm0
    mulsd %xmm11, %xmm0
    subsd %xmm0, %xmm9
    movapd %xmm10, %xmm0
    subsd %xmm11, %xmm0
    movsd %xmm0, (%rdx,%r12,8)
    testq %r12, %r12
    jz .Lrt_eig_t1_285              # l = 0: no a*u

    # Form a*u: e[0..l] = 0, then column by column.
    xorl %r13d, %r13d
4:  movq $0, (%rcx,%r13,8)
    incq %r13
    cmpq %r12, %r13
    jbe 4b
    xorl %r13d, %r13d               # j
    movq %rdi, %r15                 # &a[0, j]
.Lrt_eig_t1_au:
    movsd (%rdx,%r13,8), %xmm10     # f = d[j]
    movsd (%r15,%r13,8), %xmm11     # a[j,j]
    mulsd %xmm10, %xmm11            # a[j,j]*f
    addsd (%rcx,%r13,8), %xmm11     # g = e[j] + a[j,j]*f
    leaq 1(%r13), %r14              # k = j+1 .. l
5:  cmpq %r12, %r14
    ja 6f
    movsd (%r15,%r14,8), %xmm1      # a[k,j]
    movapd %xmm1, %xmm0
    mulsd (%rdx,%r14,8), %xmm0      # a[k,j]*d[k]
    addsd %xmm0, %xmm11             # g = g + a[k,j]*d[k]
    mulsd %xmm10, %xmm1             # a[k,j]*f
    addsd (%rcx,%r14,8), %xmm1      # e[k] + a[k,j]*f
    movsd %xmm1, (%rcx,%r14,8)
    incq %r14
    jmp 5b
6:  movsd %xmm11, (%rcx,%r13,8)     # e[j] = g
    addq %rsi, %r15
    incq %r13
    cmpq %r12, %r13
    jbe .Lrt_eig_t1_au

    # Form p: e[j] = e[j]/h; f = f + e[j]*d[j]; h = f/(h + h).
    xorpd %xmm10, %xmm10            # f = 0
    xorl %r13d, %r13d
7:  movsd (%rcx,%r13,8), %xmm0
    divsd %xmm9, %xmm0
    movsd %xmm0, (%rcx,%r13,8)
    mulsd (%rdx,%r13,8), %xmm0
    addsd %xmm0, %xmm10
    incq %r13
    cmpq %r12, %r13
    jbe 7b
    movapd %xmm9, %xmm0
    addsd %xmm9, %xmm0              # h + h
    movapd %xmm10, %xmm9
    divsd %xmm0, %xmm9              # h = f/(h + h)
    # Form q: e[j] = e[j] - h*d[j].
    xorl %r13d, %r13d
8:  movsd (%rdx,%r13,8), %xmm0
    mulsd %xmm9, %xmm0
    movsd (%rcx,%r13,8), %xmm1
    subsd %xmm0, %xmm1
    movsd %xmm1, (%rcx,%r13,8)
    incq %r13
    cmpq %r12, %r13
    jbe 8b
    # Form the reduced a: a[k,j] = (a[k,j] - f*e[k]) - g*d[k], k = j .. l.
    xorl %r13d, %r13d               # j
    movq %rdi, %r15                 # &a[0, j]
.Lrt_eig_t1_red:
    movsd (%rdx,%r13,8), %xmm10     # f = d[j]
    movsd (%rcx,%r13,8), %xmm11     # g = e[j]
    movq %r13, %r14                 # k
9:  movsd (%rcx,%r14,8), %xmm0
    mulsd %xmm10, %xmm0             # f*e[k]
    movsd (%r15,%r14,8), %xmm1
    subsd %xmm0, %xmm1              # a[k,j] - f*e[k]
    movsd (%rdx,%r14,8), %xmm0
    mulsd %xmm11, %xmm0             # g*d[k]
    subsd %xmm0, %xmm1
    movsd %xmm1, (%r15,%r14,8)
    incq %r14
    cmpq %r12, %r14
    jbe 9b
    addq %rsi, %r15
    incq %r13
    cmpq %r12, %r13
    jbe .Lrt_eig_t1_red

.Lrt_eig_t1_285:
    # f = d[j]; d[j] = a[l,j]; a[l,j] = a[i,j]; a[i,j] = f*scale.
    leaq (%rdi,%r12,8), %r8         # &a[l, 0]
    leaq (%rdi,%rbx,8), %r9         # &a[i, 0]
    xorl %r13d, %r13d
10: movsd (%rdx,%r13,8), %xmm0      # f
    movq (%r8), %rax
    movq %rax, (%rdx,%r13,8)        # d[j] = a[l, j]
    movq (%r9), %rax
    movq %rax, (%r8)                # a[l, j] = a[i, j]
    mulsd %xmm8, %xmm0
    movsd %xmm0, (%r9)              # a[i, j] = f*scale
    addq %rsi, %r8
    addq %rsi, %r9
    incq %r13
    cmpq %r12, %r13
    jbe 10b
.Lrt_eig_t1_next:
    decq %rbx
    jmp .Lrt_eig_t1_i
.Lrt_eig_t1_last:
    movq $0, (%rcx)                 # i = 0: e[0] = 0
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_eig_tql1 -- EISPACK tql1 (0-based): the eigenvalues of the
#   symmetric tridiagonal (d, e) of .Lrt_eig_tred1, by the implicit QL
#   iteration, into d in tql1's order (ascending); an eigenvalue not
#   found within SEA_EIG_MAXIT iterations, and every later one, NaN.
#     n = 1: done. e[i-1] = e[i] (i = 1 .. n-1); f = 0; tst1 = 0;
#     e[n-1] = 0. For l = 0 .. n-1: j = 0; h = |d[l]| + |e[l]|; tst1 <
#     h: tst1 = h; m = the first of l .. n-2 with tst1 + |e[m]| = tst1,
#     else n-1; m != l: repeat { j = MAXIT: d[l..n-1] = NaN, return;
#     j = j+1; g = d[l]; p = (d[l+1] - g) / (2*e[l]); r = hypot(p, 1);
#     d[l] = e[l] / (p + SIGN(r, p)); d[l+1] = e[l] * (p + SIGN(r, p));
#     dl1 = d[l+1]; h = g - d[l]; d[i] = d[i] - h (i = l+2 .. n-1);
#     f = f + h; p = d[m]; c = 1; c2 = c; el1 = e[l+1]; s = 0; for i =
#     m-1 down to l: c3 = c2; c2 = c; s2 = s; g = c*e[i]; h = c*p; r =
#     hypot(p, e[i]); e[i+1] = s*r; s = e[i]/r; c = p/r; p = c*d[i] -
#     s*g; d[i+1] = h + s*(c*g + s*d[i]); p = -s*s2*c3*el1*e[l]/dl1;
#     e[l] = s*p; d[l] = c*p } while tst1 + |e[l]| > tst1; p = d[l] + f;
#     i = l; while i > 0 and not p >= d[i-1]: d[i] = d[i-1], i = i-1;
#     d[i] = p.
#   Inputs  : %rdi = d, %rsi = e, %rdx = n (>= 1)
#   Outputs : d written; e overwritten
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = d, %r12 = e, %r13 = n,
#             %r14 = l, %r15 = i; %rbp the frame pointer
#   Frame   : 48 bytes (%rbp %rbx %r12-%r15) + 120 (locals) = 168 bytes
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_eig_tql1:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $RT_EIG_Q_LOCALS, %rsp     # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
    movq %rdx, %r13
    cmpq $1, %r13
    je .Lrt_eig_q_ret
    # e[i-1] = e[i]; f = 0; tst1 = 0; e[n-1] = 0.
    movl $1, %ecx
1:  movq (%r12,%rcx,8), %rax
    movq %rax, -8(%r12,%rcx,8)
    incq %rcx
    cmpq %r13, %rcx
    jb 1b
    movq $0, -8(%r12,%r13,8)
    movq $0, RT_EIG_Q_F(%rsp)
    movq $0, RT_EIG_Q_TST1(%rsp)
    xorl %r14d, %r14d               # l

.Lrt_eig_q_l:
    movq $0, RT_EIG_Q_J(%rsp)       # j = 0
    movapd .Lrt_eig_abs(%rip), %xmm6
    movsd (%rbx,%r14,8), %xmm0
    andpd %xmm6, %xmm0
    movsd (%r12,%r14,8), %xmm1
    andpd %xmm6, %xmm1
    addsd %xmm1, %xmm0              # h = |d[l]| + |e[l]|
    movsd RT_EIG_Q_TST1(%rsp), %xmm2
    ucomisd %xmm2, %xmm0
    jbe 2f                          # not tst1 < h (or NaN): keep tst1
    movsd %xmm0, RT_EIG_Q_TST1(%rsp)
    movapd %xmm0, %xmm2
    # Look for a small subdiagonal element: m = l .. n-2, else n-1.
2:  movq %r14, %rcx                 # m
    leaq -1(%r13), %rdx
3:  cmpq %rdx, %rcx
    jae 4f                          # m = n-1: e[n-1] = 0
    movsd (%r12,%rcx,8), %xmm0
    andpd %xmm6, %xmm0
    addsd %xmm2, %xmm0              # tst2 = tst1 + |e[m]|
    ucomisd %xmm2, %xmm0
    jp 5f
    je 4f                           # tst2 = tst1: e[m] negligible
5:  incq %rcx
    jmp 3b
4:  movq %rcx, RT_EIG_Q_M(%rsp)
    cmpq %r14, %rcx
    je .Lrt_eig_q_found

.Lrt_eig_q_iter:
    cmpq $SEA_EIG_MAXIT, RT_EIG_Q_J(%rsp)
    je .Lrt_eig_q_fail
    incq RT_EIG_Q_J(%rsp)
    # Form the shift.
    movsd (%rbx,%r14,8), %xmm0
    movsd %xmm0, RT_EIG_Q_G(%rsp)   # g = d[l]
    movsd 8(%rbx,%r14,8), %xmm1
    subsd %xmm0, %xmm1              # d[l+1] - g
    movsd (%r12,%r14,8), %xmm2
    addsd %xmm2, %xmm2              # 2*e[l] (exact doubling)
    divsd %xmm2, %xmm1
    movsd %xmm1, RT_EIG_Q_P(%rsp)   # p
    movapd %xmm1, %xmm0
    movsd .Lrt_eig_one(%rip), %xmm1
    call sea_hypot                  # r = pythag(p, 1)
    movsd RT_EIG_Q_P(%rsp), %xmm1   # p
    andpd .Lrt_eig_abs(%rip), %xmm0
    movapd %xmm1, %xmm2
    andpd .Lrt_eig_sign(%rip), %xmm2
    orpd %xmm2, %xmm0               # SIGN(r, p)
    addsd %xmm1, %xmm0              # t = p + SIGN(r, p)
    movsd (%r12,%r14,8), %xmm1      # e[l]
    movapd %xmm1, %xmm2
    divsd %xmm0, %xmm1              # e[l] / t
    movsd %xmm1, (%rbx,%r14,8)      # d[l]
    mulsd %xmm0, %xmm2              # e[l] * t
    movsd %xmm2, 8(%rbx,%r14,8)     # d[l+1]
    movsd %xmm2, RT_EIG_Q_DL1(%rsp) # dl1
    movsd RT_EIG_Q_G(%rsp), %xmm3
    subsd %xmm1, %xmm3              # h = g - d[l]
    leaq 2(%r14), %rcx              # i = l+2 .. n-1: d[i] = d[i] - h
6:  cmpq %r13, %rcx
    jae 7f
    movsd (%rbx,%rcx,8), %xmm0
    subsd %xmm3, %xmm0
    movsd %xmm0, (%rbx,%rcx,8)
    incq %rcx
    jmp 6b
7:  movsd RT_EIG_Q_F(%rsp), %xmm0
    addsd %xmm3, %xmm0
    movsd %xmm0, RT_EIG_Q_F(%rsp)   # f = f + h
    # The QL transformation.
    movq RT_EIG_Q_M(%rsp), %r15
    movsd (%rbx,%r15,8), %xmm0
    movsd %xmm0, RT_EIG_Q_P(%rsp)   # p = d[m]
    movsd .Lrt_eig_one(%rip), %xmm0
    movsd %xmm0, RT_EIG_Q_C(%rsp)   # c = 1
    movsd %xmm0, RT_EIG_Q_C2(%rsp)  # c2 = c
    movsd 8(%r12,%r14,8), %xmm0
    movsd %xmm0, RT_EIG_Q_EL1(%rsp) # el1 = e[l+1]
    movq $0, RT_EIG_Q_S(%rsp)       # s = 0
    decq %r15                       # i = m-1 (>= l)
.Lrt_eig_q_ql:
    movsd RT_EIG_Q_C2(%rsp), %xmm0
    movsd %xmm0, RT_EIG_Q_C3(%rsp)  # c3 = c2
    movsd RT_EIG_Q_C(%rsp), %xmm1
    movsd %xmm1, RT_EIG_Q_C2(%rsp)  # c2 = c
    movsd RT_EIG_Q_S(%rsp), %xmm0
    movsd %xmm0, RT_EIG_Q_S2(%rsp)  # s2 = s
    movsd (%r12,%r15,8), %xmm2      # e[i]
    movapd %xmm1, %xmm0
    mulsd %xmm2, %xmm0
    movsd %xmm0, RT_EIG_Q_G(%rsp)   # g = c*e[i]
    movsd RT_EIG_Q_P(%rsp), %xmm0   # p
    mulsd %xmm0, %xmm1
    movsd %xmm1, RT_EIG_Q_H(%rsp)   # h = c*p
    movapd %xmm2, %xmm1
    call sea_hypot                  # r = pythag(p, e[i])
    movsd RT_EIG_Q_S(%rsp), %xmm1
    mulsd %xmm0, %xmm1
    movsd %xmm1, 8(%r12,%r15,8)     # e[i+1] = s*r
    movsd (%r12,%r15,8), %xmm1
    divsd %xmm0, %xmm1              # s = e[i]/r
    movsd %xmm1, RT_EIG_Q_S(%rsp)
    movsd RT_EIG_Q_P(%rsp), %xmm2
    divsd %xmm0, %xmm2              # c = p/r
    movsd %xmm2, RT_EIG_Q_C(%rsp)
    movsd (%rbx,%r15,8), %xmm3      # d[i]
    movapd %xmm2, %xmm4
    mulsd %xmm3, %xmm4              # c*d[i]
    movsd RT_EIG_Q_G(%rsp), %xmm5   # g
    movapd %xmm1, %xmm0
    mulsd %xmm5, %xmm0              # s*g
    subsd %xmm0, %xmm4              # p = c*d[i] - s*g
    movsd %xmm4, RT_EIG_Q_P(%rsp)
    mulsd %xmm5, %xmm2              # c*g
    mulsd %xmm1, %xmm3              # s*d[i]
    addsd %xmm3, %xmm2              # c*g + s*d[i]
    mulsd %xmm1, %xmm2              # s*(c*g + s*d[i])
    movsd RT_EIG_Q_H(%rsp), %xmm0
    addsd %xmm2, %xmm0              # h + s*(...)
    movsd %xmm0, 8(%rbx,%r15,8)     # d[i+1]
    cmpq %r14, %r15
    je 8f
    decq %r15
    jmp .Lrt_eig_q_ql
    # p = -s*s2*c3*el1*e[l]/dl1; e[l] = s*p; d[l] = c*p.
8:  movsd RT_EIG_Q_S(%rsp), %xmm1   # s
    movapd %xmm1, %xmm0
    mulsd RT_EIG_Q_S2(%rsp), %xmm0
    mulsd RT_EIG_Q_C3(%rsp), %xmm0
    mulsd RT_EIG_Q_EL1(%rsp), %xmm0
    mulsd (%r12,%r14,8), %xmm0
    divsd RT_EIG_Q_DL1(%rsp), %xmm0
    xorpd .Lrt_eig_sign(%rip), %xmm0    # p
    mulsd %xmm0, %xmm1
    movsd %xmm1, (%r12,%r14,8)      # e[l] = s*p
    mulsd RT_EIG_Q_C(%rsp), %xmm0
    movsd %xmm0, (%rbx,%r14,8)      # d[l] = c*p
    andpd .Lrt_eig_abs(%rip), %xmm1
    movsd RT_EIG_Q_TST1(%rsp), %xmm2
    addsd %xmm2, %xmm1              # tst2 = tst1 + |e[l]|
    ucomisd %xmm2, %xmm1
    ja .Lrt_eig_q_iter              # tst2 > tst1: iterate again

.Lrt_eig_q_found:
    # p = d[l] + f, then tql1's ordering step.
    movsd (%rbx,%r14,8), %xmm0
    addsd RT_EIG_Q_F(%rsp), %xmm0   # p
    movq %r14, %rcx                 # i = l
9:  testq %rcx, %rcx
    jz 10f
    movsd -8(%rbx,%rcx,8), %xmm1    # d[i-1]
    ucomisd %xmm1, %xmm0
    jae 10f                         # p >= d[i-1]: stop
    movsd %xmm1, (%rbx,%rcx,8)      # d[i] = d[i-1]
    decq %rcx
    jmp 9b
10: movsd %xmm0, (%rbx,%rcx,8)      # d[i] = p
    incq %r14
    cmpq %r13, %r14
    jb .Lrt_eig_q_l
    jmp .Lrt_eig_q_ret

.Lrt_eig_q_fail:
    leaq (%rbx,%r14,8), %rdi        # d[l .. n-1] = NaN (L-ip)
    movq %r13, %rsi
    subq %r14, %rsi
    call .Lrt_eig_nanfill
.Lrt_eig_q_ret:
    addq $RT_EIG_Q_LOCALS, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_eig_core -- tred1, tql1 and the sort: the eigenvalues of the
#   lower triangle of the n x n matrix a into d.
#   Inputs  : %rdi = a (overwritten), %rsi = n (>= 1), %rdx = d,
#             %rcx = e (n doubles of work)
#   Outputs : d written, ascending (NaN last)
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = d, %r12 = n; %rbp
#   Frame   : 40 bytes (%rbp %rbx %r12, e, alignment) around
#             .Lrt_eig_tred1, 24 (%rbp %rbx %r12) around .Lrt_eig_tql1
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_eig_core:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12                      # %rsp = 0 (mod 16)
    movq %rdx, %rbx
    movq %rsi, %r12
    pushq %rcx                      # e, kept for tql1
    subq $8, %rsp
    call .Lrt_eig_tred1             # (a, n, d, e)
    addq $8, %rsp
    popq %rsi                       # e
    movq %rbx, %rdi
    movq %r12, %rdx
    call .Lrt_eig_tql1              # (d, e, n)
    movq %rbx, %rdi
    movq %r12, %rsi
    call .Lrt_eig_sort
    popq %r12
    popq %rbx
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_eig_square_err -- NOT_SQUARE with the operand's shape (noreturn).
#   Inputs  : %rdi = the matrix, %rsi = site
#   Outputs : none (sea_err does not return)
#   Clobbers: (never returns)
#   Callee-saved used: %rbp the frame pointer
#   Frame   : 8 (%rbp) + 32 (slots) bytes
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_eig_square_err:
    pushq %rbp
    movq %rsp, %rbp
    subq $RT_EIG_ERR_LOCALS, %rsp
    movq SEA_ARR_ROWS(%rdi), %rax
    movq %rax, (0 * SEA_SLOT_SIZE)(%rsp)    # rows
    movq SEA_ARR_COLS(%rdi), %rax
    movq %rax, (1 * SEA_SLOT_SIZE)(%rsp)    # cols
    movl $SEA_E_NOT_SQUARE, %edi
    movq %rsp, %rdx
    call sea_err                    # noreturn
    ud2

# ---------------------------------------------------------------------
# .Lrt_eig_shape_err -- SHAPE_MISMATCH: K's shape, then M's (noreturn).
#   Inputs  : %rdi = K, %rsi = M, %rdx = site
#   Outputs : none (sea_err does not return)
#   Clobbers: (never returns)
#   Callee-saved used: %rbp the frame pointer
#   Frame   : 8 (%rbp) + 32 (slots) bytes
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_eig_shape_err:
    pushq %rbp
    movq %rsp, %rbp
    subq $RT_EIG_ERR_LOCALS, %rsp
    movq SEA_ARR_ROWS(%rdi), %rax
    movq %rax, (0 * SEA_SLOT_SIZE)(%rsp)    # K's rows
    movq SEA_ARR_COLS(%rdi), %rax
    movq %rax, (1 * SEA_SLOT_SIZE)(%rsp)    # K's cols
    movq SEA_ARR_ROWS(%rsi), %rax
    movq %rax, (2 * SEA_SLOT_SIZE)(%rsp)    # M's rows
    movq SEA_ARR_COLS(%rsi), %rax
    movq %rax, (3 * SEA_SLOT_SIZE)(%rsp)    # M's cols
    movq %rdx, %rsi
    movl $SEA_E_SHAPE_MISMATCH, %edi
    movq %rsp, %rdx
    call sea_err                    # noreturn
    ud2

# =====================================================================
# Entries
# =====================================================================

# ---------------------------------------------------------------------
# sea_eig_sym -- the entry EIG_SYM.
#   Purpose : A not square: NOT_SQUARE (A's shape); not symmetric
#             (sea_la_issym, Decision 123): NOT_SYMMETRIC. A new f64
#             vector of n: n = 0 empty; an element +-Inf or NaN: n NaN
#             (L-ip); else A copied into scratch, .Lrt_eig_core (tred1
#             on its lower triangle, tql1, the sort).
#   Inputs  : %rdi = A (a dynamic f64 matrix, borrowed), %rsi = site
#   Outputs : %rax = the vector (count 1)
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = A, %r12 = site,
#             %r13 = n, %r14 = the result; %r15 unused; %rbp the frame
#             pointer
#   Frame   : 48 bytes + 24 (the scratch, its bytes, alignment) = 72
# ---------------------------------------------------------------------
    .globl sea_eig_sym
    .type sea_eig_sym, @function
    .p2align 4
sea_eig_sym:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $RT_EIG_E_LOCALS, %rsp     # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
    movq SEA_ARR_ROWS(%rbx), %r13   # n
    cmpq SEA_ARR_COLS(%rbx), %r13
    jne .Lrt_eig_s_square
    movq SEA_ARR_DATA(%rbx), %rdi
    movq %r13, %rsi
    movq %r13, %rdx
    call sea_la_issym
    testq %rax, %rax
    jz .Lrt_eig_s_sym
    # The result: a vector of n.
    movl $SEA_EK_F64, %edi
    movl $1, %esi
    movq %r13, %rdx
    movl $1, %ecx
    movq %r12, %r8
    call sea_arr_new_u
    movq %rax, %r14
    testq %r13, %r13
    jz .Lrt_eig_s_ret               # n = 0: the empty vector
    movq SEA_ARR_DATA(%rbx), %rdi
    movq %r13, %rsi
    imulq %r13, %rsi
    call .Lrt_eig_finite
    testq %rax, %rax
    jz .Lrt_eig_s_nan
    # The scratch: the copy of A (8n^2), e (8n).
    movq %r13, %rdi
    imulq %r13, %rdi
    addq %r13, %rdi
    shlq $3, %rdi
    movq %rdi, RT_EIG_E_SB(%rsp)
    movq %r12, %rsi
    call sea_alloc
    movq %rax, RT_EIG_E_S(%rsp)
    movq %rax, %rdi                 # the copy of A (exact moves)
    movq SEA_ARR_DATA(%rbx), %rsi
    movq %r13, %rcx
    imulq %r13, %rcx
    rep movsq
    movq RT_EIG_E_S(%rsp), %rdi     # a
    movq %r13, %rsi                 # n
    movq SEA_ARR_DATA(%r14), %rdx   # d: the result's elements
    movq %r13, %rcx
    imulq %r13, %rcx
    leaq (%rdi,%rcx,8), %rcx        # e, after the copy
    call .Lrt_eig_core
    movq RT_EIG_E_S(%rsp), %rdi
    movq RT_EIG_E_SB(%rsp), %rsi
    call sea_free_block             # the scratch goes before the entry returns
.Lrt_eig_s_ret:
    movq %r14, %rax
    addq $RT_EIG_E_LOCALS, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret
.Lrt_eig_s_nan:
    movq SEA_ARR_DATA(%r14), %rdi   # n NaN (L-ip)
    movq %r13, %rsi
    call .Lrt_eig_nanfill
    jmp .Lrt_eig_s_ret
.Lrt_eig_s_square:
    movq %rbx, %rdi
    movq %r12, %rsi
    call .Lrt_eig_square_err        # noreturn
.Lrt_eig_s_sym:
    movl $SEA_E_NOT_SYMMETRIC, %edi
    movq %r12, %rsi
    xorl %edx, %edx                 # no slots
    call sea_err                    # noreturn
    ud2
    .size sea_eig_sym, . - sea_eig_sym

# ---------------------------------------------------------------------
# sea_eig_sym_gen -- the entry EIG_SYM_GEN.
#   Purpose : NOT_SQUARE (K), NOT_SQUARE (M), different orders:
#             SHAPE_MISMATCH (K's, M's shape), NOT_SYMMETRIC (K, then M);
#             a new f64 vector of n, then L-iy's order: n = 0 empty; an
#             element of K or M +-Inf or NaN: n NaN; R = sea_la_potrf on
#             a scratch copy of M (a failing pivot: the scratch and the
#             result freed, NOT_POSDEF); Z = R^-T K column by column
#             (Z[j,c] = (K[j,c] - R[0,j]*Z[0,c] - ... - R[j-1,j]*
#             Z[j-1,c]) / R[j,j]) and C = Z R^-1 row by row (C[r,j] =
#             (Z[r,j] - R[0,j]*C[r,0] - ... - R[j-1,j]*C[r,j-1]) /
#             R[j,j]), both unblocked, in one area; an element of C
#             +-Inf or NaN: n NaN; else .Lrt_eig_core on C's lower
#             triangle (no symmetry test).
#   Inputs  : %rdi = K, %rsi = M (both borrowed), %rdx = site
#   Outputs : %rax = the vector (count 1)
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = K, %r12 = M,
#             %r13 = site, %r14 = n, %r15 = the result; %rbp the frame
#             pointer
#   Frame   : 48 bytes + 24 (the scratch, its bytes, alignment) = 72
# ---------------------------------------------------------------------
    .globl sea_eig_sym_gen
    .type sea_eig_sym_gen, @function
    .p2align 4
sea_eig_sym_gen:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $RT_EIG_E_LOCALS, %rsp     # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
    movq %rdx, %r13
    # The checks, in the row's order.
    movq SEA_ARR_ROWS(%rbx), %r14   # n
    cmpq SEA_ARR_COLS(%rbx), %r14
    jne .Lrt_eig_g_square_k
    movq SEA_ARR_ROWS(%r12), %rax
    cmpq SEA_ARR_COLS(%r12), %rax
    jne .Lrt_eig_g_square_m
    cmpq %rax, %r14
    jne .Lrt_eig_g_shape
    movq SEA_ARR_DATA(%rbx), %rdi
    movq %r14, %rsi
    movq %r14, %rdx
    call sea_la_issym               # K
    testq %rax, %rax
    jz .Lrt_eig_g_sym
    movq SEA_ARR_DATA(%r12), %rdi
    movq %r14, %rsi
    movq %r14, %rdx
    call sea_la_issym               # M
    testq %rax, %rax
    jz .Lrt_eig_g_sym
    # The result: a vector of n.
    movl $SEA_EK_F64, %edi
    movl $1, %esi
    movq %r14, %rdx
    movl $1, %ecx
    movq %r13, %r8
    call sea_arr_new_u
    movq %rax, %r15
    testq %r14, %r14
    jz .Lrt_eig_g_ret               # n = 0: the empty vector
    # A non-finite element of K or M: n NaN, before the Cholesky of M.
    movq SEA_ARR_DATA(%rbx), %rdi
    movq %r14, %rsi
    imulq %r14, %rsi
    call .Lrt_eig_finite
    testq %rax, %rax
    jz .Lrt_eig_g_nan
    movq SEA_ARR_DATA(%r12), %rdi
    movq %r14, %rsi
    imulq %r14, %rsi
    call .Lrt_eig_finite
    testq %rax, %rax
    jz .Lrt_eig_g_nan
    # The scratch: R (8n^2), Z/C (8n^2), e (8n), W (8n*NB when n > NB).
    movq %r14, %rdi
    imulq %r14, %rdi
    addq %rdi, %rdi                 # 2n^2
    addq %r14, %rdi                 # + n
    cmpq $SEA_LA_NB, %r14
    jbe 1f
    imulq $SEA_LA_NB, %r14, %rax
    addq %rax, %rdi                 # + n*NB
1:  shlq $3, %rdi
    movq %rdi, RT_EIG_E_SB(%rsp)
    movq %r13, %rsi
    call sea_alloc
    movq %rax, RT_EIG_E_S(%rsp)
    movq %r14, %rcx                 # R = M, Z = K (exact moves)
    imulq %r14, %rcx
    movq %rax, %rdi
    movq SEA_ARR_DATA(%r12), %rsi
    rep movsq
    movq %r14, %rcx
    imulq %r14, %rcx
    movq SEA_ARR_DATA(%rbx), %rsi
    rep movsq                       # %rdi continues at Z
    # R = the Cholesky factor of M.
    movq RT_EIG_E_S(%rsp), %rdi
    movq %r14, %rsi
    movq %r14, %rdx
    xorl %ecx, %ecx                 # no W when n <= NB (unused, 0 allowed)
    cmpq $SEA_LA_NB, %r14
    jbe 2f
    movq %r14, %rcx                 # W = S + 8(2n^2 + n), after e
    imulq %r14, %rcx
    addq %rcx, %rcx
    addq %r14, %rcx
    leaq (%rdi,%rcx,8), %rcx
2:  call sea_la_potrf
    testq %rax, %rax
    jnz .Lrt_eig_g_posdef
    # Z = R^-T K, column by column.
    movq RT_EIG_E_S(%rsp), %rdi     # R
    movq %r14, %rsi
    call .Lrt_eig_rtk
    # C = Z R^-1, row by row.
    movq RT_EIG_E_S(%rsp), %rdi
    movq %r14, %rsi
    call .Lrt_eig_zri
    # A non-finite element of C (an overflow of the reduction): n NaN.
    movq %r14, %rdi
    imulq %r14, %rdi
    movq RT_EIG_E_S(%rsp), %rax
    leaq (%rax,%rdi,8), %rdi        # C
    movq %r14, %rsi
    imulq %r14, %rsi
    call .Lrt_eig_finite
    testq %rax, %rax
    jz .Lrt_eig_g_cnan
    movq %r14, %rcx
    imulq %r14, %rcx
    movq RT_EIG_E_S(%rsp), %rdi
    leaq (%rdi,%rcx,8), %rdi        # a = C
    leaq (%rdi,%rcx,8), %rcx        # e, after C
    movq %r14, %rsi
    movq SEA_ARR_DATA(%r15), %rdx   # d: the result's elements
    call .Lrt_eig_core
.Lrt_eig_g_free:
    movq RT_EIG_E_S(%rsp), %rdi
    movq RT_EIG_E_SB(%rsp), %rsi
    call sea_free_block             # the scratch goes before the entry returns
.Lrt_eig_g_ret:
    movq %r15, %rax
    addq $RT_EIG_E_LOCALS, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret
.Lrt_eig_g_cnan:
    movq SEA_ARR_DATA(%r15), %rdi   # n NaN (L-iy), then the scratch freed
    movq %r14, %rsi
    call .Lrt_eig_nanfill
    jmp .Lrt_eig_g_free
.Lrt_eig_g_nan:
    movq SEA_ARR_DATA(%r15), %rdi   # n NaN (L-iy), no scratch yet
    movq %r14, %rsi
    call .Lrt_eig_nanfill
    jmp .Lrt_eig_g_ret
.Lrt_eig_g_posdef:
    movq RT_EIG_E_S(%rsp), %rdi     # free the scratch and the result, then the error
    movq RT_EIG_E_SB(%rsp), %rsi
    call sea_free_block
    movq %r15, %rdi
    call sea_free                   # the result has count 1: freed and uncounted
    movl $SEA_E_NOT_POSDEF, %edi
    movq %r13, %rsi
    xorl %edx, %edx                 # no slots
    call sea_err                    # noreturn
    ud2
.Lrt_eig_g_square_k:
    movq %rbx, %rdi
    movq %r13, %rsi
    call .Lrt_eig_square_err        # noreturn
.Lrt_eig_g_square_m:
    movq %r12, %rdi
    movq %r13, %rsi
    call .Lrt_eig_square_err        # noreturn
.Lrt_eig_g_shape:
    movq %rbx, %rdi
    movq %r12, %rsi
    movq %r13, %rdx
    call .Lrt_eig_shape_err         # noreturn
.Lrt_eig_g_sym:
    movl $SEA_E_NOT_SYMMETRIC, %edi
    movq %r13, %rsi
    xorl %edx, %edx                 # no slots
    call sea_err                    # noreturn
    ud2
    .size sea_eig_sym_gen, . - sea_eig_sym_gen

    .section .rodata
    .p2align 4
.Lrt_eig_abs:
    .quad 0x7FFFFFFFFFFFFFFF, 0x7FFFFFFFFFFFFFFF   # |x| mask, both lanes
.Lrt_eig_sign:
    .quad 0x8000000000000000, 0x8000000000000000   # the sign bit, both lanes
.Lrt_eig_one:
    .quad 0x3FF0000000000000        # 1.0

    .section .note.GNU-stack,"",@progbits
