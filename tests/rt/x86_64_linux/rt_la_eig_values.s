# sea/tests/rt/x86_64_linux/rt_la_eig_values.s -- sea_eig_sym and sea_eig_sym_gen bit for bit (DESIGN.md 2.13.5 EIG_SYM, EIG_SYM_GEN; 2.13.6; L-ip, L-iy; Decision 121): each case prints the eigenvalues' bits (NaN as NaN), the result's rank, rows, cols and count, and whether the arguments are untouched. Exact cases: a diagonal matrix (its sorted diagonal), [2 1; 1 2] (1, 3), diagonal K with power-of-four diagonal M (the quotients). Every other expected value is derived by a Python-float transcription of 2.13.6's steps (tred1, tql1 with pythag = sea_hypot's bit-exact model tests/vectors/math_model.py, SIGN, the 10.6 sort; CHOL's steps then Z = R^-T K, C = Z R^-1), one IEEE binary64 operation per step, never by LAPACK or NumPy: the 1 x 1 -0 (kept), +-0 diagonals, tridiag(-1, 2, -1) of order 10, a 4 x 4 integer matrix, a matrix whose last row is zero off the diagonal (tred1's scale = 0 branch), a 40 x 40 integer matrix K[i,j] = ((ij + i + j) mod 7) - 3, overflow (all 1e308: 2 x 2 finite garbage; 3 x 3 scale = Inf, NaN through tql1, the search for m stopping at n - 1), Inf and NaN elements (n NaN, L-ip), the pencils 2 x 2, 3 x 3 and 40 x 40 with M = R'R of an exact dyadic R (the blocked Cholesky crosses SEA_LA_NB, gives R exactly under every variant), and L-iy's three NaN cases (Inf on M's diagonal; NaN in K, also with an indefinite M: no error; K = 1e300 I, M = 1e-300 I, whose reduction overflows). n = 0 gives empty vectors. Run under the baseline variant and the best one with identical output; every object released (heap check).
.include "errors.inc"
.include "rt.inc"

# ---- test helpers (the same block in every rt_la_lu/private/free test) -
# Append a literal text (caller-saved registers clobbered).
.macro TXT text
    leaq .Ltxt_s\@(%rip), %rdi
    movq $(.Ltxt_e\@ - .Ltxt_s\@), %rsi
    call sea_out_write
    .pushsection .rodata
.Ltxt_s\@: .ascii "\text"
.Ltxt_e\@:
    .popsection
.endm
# The release sequence of pass 4 (DESIGN.md 4.9) on the object in reg
# (not %rdi): the count drops by one unless static, sea_free at 0
# (caller-saved registers clobbered).
.macro REL reg
    movq \reg, %rdi
    movq (%rdi), %rax
    testq %rax, %rax
    jz .Lrel\@
    decq %rax
    movq %rax, (%rdi)
    jnz .Lrel\@
    call sea_free
.Lrel\@:
.endm
# A function frame: %rbp, %rbx, %r12-%r15 saved, 8 bytes of locals at
# 0(%rsp); entered at %rsp = 8 (mod 16), so %rsp = 0 (mod 16) after it.
.macro PROLOGUE
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $8, %rsp
.endm
.macro EPILOGUE
    addq $8, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret
.endm
# The largest order the test buffers hold.
.equ MAXN, 80
.equ BUFBYTES, (MAXN * MAXN * 8)

    .text
# putcstr -- append the NUL-terminated text at %rdi. Clobbers caller-saved
# registers. Callee-saved used: %rbx (the text). Frame 24 bytes.
    .p2align 4
putcstr:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp
    movq %rdi, %rbx
    call strlen@PLT
    movq %rax, %rsi
    movq %rbx, %rdi
    call sea_out_write
    addq $8, %rsp
    popq %rbx
    popq %rbp
    ret

# putdec -- append the decimal text of %rdi (signed).
#   Clobbers: all caller-saved registers. Frame: 8 (%rbp) + 32 bytes.
    .p2align 4
putdec:
    pushq %rbp
    movq %rsp, %rbp
    subq $32, %rsp
    leaq 32(%rsp), %r8
    movq %rdi, %rax
    xorl %r9d, %r9d
    testq %rax, %rax
    jns 1f
    negq %rax
    movl $1, %r9d
1:  movl $10, %ecx
2:  xorl %edx, %edx
    divq %rcx
    addb $48, %dl
    decq %r8
    movb %dl, (%r8)
    testq %rax, %rax
    jnz 2b
    testl %r9d, %r9d
    jz 3f
    decq %r8
    movb $45, (%r8)
3:  movq %r8, %rdi
    leaq 32(%rsp), %rsi
    subq %r8, %rsi
    call sea_out_write
    movq %rbp, %rsp
    popq %rbp
    ret

# puthex -- append %rdi as 16 upper-case hexadecimal digits. Clobbers
# caller-saved registers. Frame: 8 (%rbp) + 16 bytes.
    .p2align 4
puthex:
    pushq %rbp
    movq %rsp, %rbp
    subq $16, %rsp
    movl $16, %ecx
1:  movl %edi, %eax
    andl $15, %eax
    leal 48(%rax), %edx
    leal 55(%rax), %r8d
    cmpl $10, %eax
    cmovael %r8d, %edx
    decl %ecx
    movb %dl, (%rsp,%rcx)
    shrq $4, %rdi
    testl %ecx, %ecx
    jnz 1b
    movq %rsp, %rdi
    movl $16, %esi
    call sea_out_write
    movq %rbp, %rsp
    popq %rbp
    ret

# putf -- append the f64 bits in %rdi: `NaN` for every NaN (its bits are
# not observable, LANGUAGE.md 6.5), else the 16 hexadecimal digits.
    .p2align 4
putf:
    pushq %rbp
    movq %rsp, %rbp
    movq %rdi, %rax
    shlq $1, %rax
    movabsq $0xFFE0000000000000, %rcx
    cmpq %rcx, %rax
    jbe 1f
    TXT "NaN"
    jmp 2f
1:  call puthex
2:  popq %rbp
    ret

# newmat -- a new dynamic f64 array (count 1, elements unwritten).
#   Inputs  : %rdi = rank, %rsi = rows, %rdx = cols (1 for a vector)
#   Outputs : %rax = the array. Clobbers caller-saved registers.
    .p2align 4
newmat:
    pushq %rbp
    movq %rsp, %rbp
    movq %rdx, %rcx
    movq %rsi, %rdx
    movq %rdi, %rsi
    movl $SEA_EK_F64, %edi
    xorl %r8d, %r8d                 # site 0
    call sea_arr_new_u
    popq %rbp
    ret

# copyq -- copy %rdx qwords from %rsi to %rdi (exact). Clobbers %rcx %rdi %rsi.
    .p2align 4
copyq:
    movq %rdx, %rcx
    cld
    rep movsq
    ret

# fillq -- set %rdx qwords at %rdi to the bits %rsi. Clobbers %rax %rcx %rdi.
    .p2align 4
fillq:
    movq %rdx, %rcx
    movq %rsi, %rax
    cld
    rep stosq
    ret

# eqvals -- compare %rdx doubles at %rdi and %rsi by == (so +0 = -0; a NaN
# is never equal). Outputs: %rax = 0 if all equal, else 1 + the first
# differing index. Clobbers %rax %rcx %xmm0.
    .p2align 4
eqvals:
    xorl %ecx, %ecx
1:  cmpq %rdx, %rcx
    jae 3f
    movsd (%rdi,%rcx,8), %xmm0
    ucomisd (%rsi,%rcx,8), %xmm0
    jp 2f
    jne 2f
    incq %rcx
    jmp 1b
2:  leaq 1(%rcx), %rax
    ret
3:  xorl %eax, %eax
    ret

# eqbits -- compare %rdx qwords at %rdi and %rsi bit for bit. Outputs as
# eqvals. Clobbers %rax %rcx %r8.
    .p2align 4
eqbits:
    xorl %ecx, %ecx
1:  cmpq %rdx, %rcx
    jae 3f
    movq (%rdi,%rcx,8), %r8
    cmpq (%rsi,%rcx,8), %r8
    jne 2f
    incq %rcx
    jmp 1b
2:  leaq 1(%rcx), %rax
    ret
3:  xorl %eax, %eax
    ret

# genR -- the exact Cholesky factor of order n (ld n): R[i,j] = ((3i + 5j)
# mod 4) - 1 for i < j, R[j,j] = 2^(j mod 3), R[i,j] = +0 for i > j.
#   Inputs  : %rdi = R, %rsi = n. Clobbers caller-saved registers. Leaf.
    .p2align 4
genR:
    xorl %r8d, %r8d                 # j
1:  cmpq %rsi, %r8
    jae 6f
    xorl %r9d, %r9d                 # i
2:  cmpq %rsi, %r9
    jae 5f
    cmpq %r8, %r9
    ja 3f                           # i > j: +0
    je 4f                           # i = j: 2^(j mod 3)
    leaq (%r9,%r9,2), %rax          # 3i
    leaq (%r8,%r8,4), %rcx          # 5j
    addq %rcx, %rax
    andq $3, %rax                   # mod 4
    decq %rax
    cvtsi2sdq %rax, %xmm0
    movsd %xmm0, (%rdi)
    jmp 9f
3:  movq $0, (%rdi)
    jmp 9f
4:  movq %r8, %rax
    xorl %edx, %edx
    movl $3, %ecx
    divq %rcx                       # %rdx = j mod 3
    movl $1, %eax
    movl %edx, %ecx
    shll %cl, %eax
    cvtsi2sdl %eax, %xmm0
    movsd %xmm0, (%rdi)
9:  addq $8, %rdi
    incq %r9
    jmp 2b
5:  incq %r8
    jmp 1b
6:  ret

# rtr -- A = R'R (n x n, ld n): A[i,j] = sum over k = 0 .. min(i,j) of
# R[k,i]*R[k,j], k ascending (exact on genR's data).
#   Inputs  : %rdi = R, %rsi = A, %rdx = n. Clobbers caller-saved. Leaf.
    .p2align 4
rtr:
    xorl %r8d, %r8d                 # j
1:  cmpq %rdx, %r8
    jae 5f
    xorl %r9d, %r9d                 # i
2:  cmpq %rdx, %r9
    jae 4f
    movq %r9, %r10
    cmpq %r8, %r10
    cmova %r8, %r10                 # min(i, j)
    movq %r9, %rax
    imulq %rdx, %rax
    leaq (%rdi,%rax,8), %r11        # &R[0, i]
    movq %r8, %rax
    imulq %rdx, %rax
    leaq (%rdi,%rax,8), %rcx        # &R[0, j]
    xorpd %xmm0, %xmm0
    xorl %eax, %eax                 # k
3:  movsd (%r11,%rax,8), %xmm1
    mulsd (%rcx,%rax,8), %xmm1
    addsd %xmm1, %xmm0
    incq %rax
    cmpq %r10, %rax
    jbe 3b
    movq %r8, %rax
    imulq %rdx, %rax
    addq %r9, %rax
    movsd %xmm0, (%rsi,%rax,8)      # A[i, j]
    incq %r9
    jmp 2b
4:  incq %r8
    jmp 1b
5:  ret

# genX -- X[i,c] = ((i + 2c) mod 5) - 2 (n x m, ld n).
#   Inputs  : %rdi = X, %rsi = n, %rdx = m. Clobbers caller-saved. Leaf.
    .p2align 4
genX:
    movq %rdx, %r10
    xorl %r8d, %r8d                 # c
1:  cmpq %r10, %r8
    jae 4f
    xorl %r9d, %r9d                 # i
2:  cmpq %rsi, %r9
    jae 3f
    leaq (%r9,%r8,2), %rax
    xorl %edx, %edx
    movl $5, %ecx
    divq %rcx
    subq $2, %rdx
    cvtsi2sdq %rdx, %xmm0
    movsd %xmm0, (%rdi)
    addq $8, %rdi
    incq %r9
    jmp 2b
3:  incq %r8
    jmp 1b
4:  ret

# mulAX -- B = A X (A n x n, X and B n x m, ld n): B[i,c] = sum over k
# ascending of A[i,k]*X[k,c] (exact on the tests' data).
#   Inputs  : %rdi = A, %rsi = X, %rdx = B, %rcx = n, %r8 = m.
#   Clobbers caller-saved. Leaf.
    .p2align 4
mulAX:
    pushq %rbx
    xorl %r9d, %r9d                 # c
1:  cmpq %r8, %r9
    jae 5f
    xorl %r10d, %r10d               # i
2:  cmpq %rcx, %r10
    jae 4f
    xorpd %xmm0, %xmm0
    xorl %r11d, %r11d               # k
    movq %r9, %rbx
    imulq %rcx, %rbx
    leaq (%rsi,%rbx,8), %rbx        # &X[0, c]
3:  movq %r11, %rax
    imulq %rcx, %rax
    addq %r10, %rax
    movsd (%rdi,%rax,8), %xmm1      # A[i, k]
    mulsd (%rbx,%r11,8), %xmm1
    addsd %xmm1, %xmm0
    incq %r11
    cmpq %rcx, %r11
    jb 3b
    movq %r9, %rax
    imulq %rcx, %rax
    addq %r10, %rax
    movsd %xmm0, (%rdx,%rax,8)
    incq %r10
    jmp 2b
4:  incq %r9
    jmp 1b
5:  popq %rbx
    ret

# genPLU -- an exact LU case of order n (ld n): L unit lower with L[i,k] =
# (((3i + 5k) mod 5) - 2) / 4 for i > k (|L| <= 1/2), U upper with
# U[k,j] = ((7k + 3j) mod 7) - 3 for j > k and U[k,k] = 2^(k mod 3),
# ipiv[k] = k + ((5k + 3) mod (n - k)) (u32), and A = P_0 P_1 ... P_{n-1}
# L U (P_k exchanges rows k and ipiv[k]), so that partial pivoting on A
# finds exactly ipiv, L and U (2.13.8's la_lu_exact construction).
#   Inputs  : %rdi = L, %rsi = U, %rdx = ipiv, %rcx = A, %r8 = n
#   Clobbers caller-saved registers.
#   Callee-saved used: %rbx = L, %r12 = U, %r13 = ipiv, %r14 = A,
#             %r15 = n. Frame 56.
    .p2align 4
genPLU:
    PROLOGUE
    movq %rdi, %rbx
    movq %rsi, %r12
    movq %rdx, %r13
    movq %rcx, %r14
    movq %r8, %r15
    # L and U.
    xorl %r8d, %r8d                 # column j (or k)
1:  cmpq %r15, %r8
    jae 7f
    xorl %r9d, %r9d                 # row i
2:  cmpq %r15, %r9
    jae 6f
    movq %r8, %r10
    imulq %r15, %r10
    addq %r9, %r10                  # the element index i + j*n
    # L[i, j]
    cmpq %r8, %r9
    jb 3f                           # i < j: L = 0, U below
    je 4f                           # i = j: L = 1, U = 2^(j mod 3)
    leaq (%r9,%r9,2), %rax          # i > j: L = (((3i + 5j) mod 5) - 2) / 4, U = 0
    leaq (%r8,%r8,4), %rcx
    addq %rcx, %rax
    xorl %edx, %edx
    movl $5, %ecx
    divq %rcx
    subq $2, %rdx
    cvtsi2sdq %rdx, %xmm0
    mulsd .Lquarter(%rip), %xmm0
    movsd %xmm0, (%rbx,%r10,8)
    movq $0, (%r12,%r10,8)
    jmp 5f
3:  movq $0, (%rbx,%r10,8)          # U[i, j], i < j: ((7i + 3j) mod 7) - 3
    leaq 0(,%r9,8), %rax
    subq %r9, %rax                  # 7i
    leaq (%r8,%r8,2), %rcx          # 3j
    addq %rcx, %rax
    xorl %edx, %edx
    movl $7, %ecx
    divq %rcx
    subq $3, %rdx
    cvtsi2sdq %rdx, %xmm0
    movsd %xmm0, (%r12,%r10,8)
    jmp 5f
4:  movabsq $0x3FF0000000000000, %rax
    movq %rax, (%rbx,%r10,8)        # L[j, j] = 1
    movq %r8, %rax
    xorl %edx, %edx
    movl $3, %ecx
    divq %rcx
    movl $1, %eax
    movl %edx, %ecx
    shll %cl, %eax
    cvtsi2sdl %eax, %xmm0
    movsd %xmm0, (%r12,%r10,8)
5:  incq %r9
    jmp 2b
6:  incq %r8
    jmp 1b
    # ipiv
7:  xorl %r8d, %r8d
8:  cmpq %r15, %r8
    jae 9f
    leaq (%r8,%r8,4), %rax
    addq $3, %rax                   # 5k + 3
    movq %r15, %rcx
    subq %r8, %rcx                  # n - k
    xorl %edx, %edx
    divq %rcx
    addq %r8, %rdx
    movl %edx, (%r13,%r8,4)
    incq %r8
    jmp 8b
    # A = L U (as R'R's loop: A[i,j] = sum over k <= min(i,j) of L[i,k]*U[k,j])
9:  xorl %r8d, %r8d                 # j
10: cmpq %r15, %r8
    jae 14f
    xorl %r9d, %r9d                 # i
11: cmpq %r15, %r9
    jae 13f
    movq %r9, %r10
    cmpq %r8, %r10
    cmova %r8, %r10                 # min(i, j)
    xorpd %xmm0, %xmm0
    xorl %r11d, %r11d               # k
12: movq %r11, %rax
    imulq %r15, %rax
    addq %r9, %rax
    movsd (%rbx,%rax,8), %xmm1      # L[i, k]
    movq %r8, %rax
    imulq %r15, %rax
    addq %r11, %rax
    mulsd (%r12,%rax,8), %xmm1      # * U[k, j]
    addsd %xmm1, %xmm0
    incq %r11
    cmpq %r10, %r11
    jbe 12b
    movq %r8, %rax
    imulq %r15, %rax
    addq %r9, %rax
    movsd %xmm0, (%r14,%rax,8)
    incq %r9
    jmp 11b
13: incq %r8
    jmp 10b
    # The row exchanges, k = n-1 down to 0.
14: movq %r15, %r8
15: testq %r8, %r8
    jz 17f
    decq %r8
    movl (%r13,%r8,4), %r9d         # p
    cmpq %r8, %r9
    je 15b
    leaq (%r14,%r8,8), %r10
    leaq (%r14,%r9,8), %r11
    leaq (,%r15,8), %rsi
    movq %r15, %rdx
16: movq (%r10), %rax
    movq (%r11), %rcx
    movq %rcx, (%r10)
    movq %rax, (%r11)
    addq %rsi, %r10
    addq %rsi, %r11
    decq %rdx
    jnz 16b
    jmp 15b
17: EPILOGUE
    .section .rodata
    .p2align 3
.Lquarter: .quad 0x3FD0000000000000 # 0.25
    .text

# Kernel variants: a test runs its cases twice, "pass 1" under the last
# usable Baysick variant (the baseline form, sse2 on x86_64) and "pass 2"
# under the first (the best one, the variant main selects by default),
# each selected as main selects one (bsk_kern_use, then sea_variant from
# its name); on a CPU with one usable variant both passes use it.
# nvariants -- %rax = the number of usable variants. Clobbers caller-saved.
    .p2align 4
nvariants:
    pushq %rbp
    movq %rsp, %rbp
    call bsk_kern_variants
    movq %rax, %rcx
    xorl %eax, %eax
1:  cmpq $0, (%rcx,%rax,8)
    je 2f
    incq %rax
    jmp 1b
2:  popq %rbp
    ret
# usevariant -- select usable variant %rdi (0-based). Clobbers caller-saved.
#   Callee-saved used: %rbx (its name). Frame 24 bytes.
    .p2align 4
usevariant:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp
    pushq %rdi
    subq $8, %rsp
    call bsk_kern_variants
    addq $8, %rsp
    popq %rdi
    movq (%rax,%rdi,8), %rbx        # the name
    movq %rbx, %rdi
    call bsk_kern_use
    movq $SEA_VAR_SSE2, sea_variant(%rip)
    cmpb $'a', (%rbx)               # "avx2"
    jne 1f
    movq $SEA_VAR_AVX2, sea_variant(%rip)
1:  addq $8, %rsp
    popq %rbx
    popq %rbp
    ret
# ---- end of the test helpers ------------------------------------------

# ---- the test ---------------------------------------------------------
# A case record (8-byte words): label, kind (1 sea_eig_sym(A), 2
# sea_eig_sym_gen(A, M)), n, A's elements, M's elements (column-major).
.equ VC_SIZE, 40

# runcases -- every case under the current variant: `<label>: <values>
# | <rank> <rows> <cols> rc=<count> args ok|CHANGED`.
#   Callee-saved used: %rbx = the record, %r12 = A, %r13 = M, %r14 = the
#             result, %r15 = the index. Frame 56.
    .p2align 4
runcases:
    PROLOGUE
    leaq vcases(%rip), %rbx
1:  cmpq $0, (%rbx)
    je 9f
    movl $2, %edi                   # A: a new n x n matrix of the case's data
    movq 16(%rbx), %rsi
    movq %rsi, %rdx
    call newmat
    movq %rax, %r12
    movq SEA_ARR_DATA(%r12), %rdi
    movq 24(%rbx), %rsi
    movq 16(%rbx), %rdx
    imulq %rdx, %rdx
    call copyq
    xorl %r13d, %r13d
    cmpq $2, 8(%rbx)
    jne 2f
    movl $2, %edi                   # M
    movq 16(%rbx), %rsi
    movq %rsi, %rdx
    call newmat
    movq %rax, %r13
    movq SEA_ARR_DATA(%r13), %rdi
    movq 32(%rbx), %rsi
    movq 16(%rbx), %rdx
    imulq %rdx, %rdx
    call copyq
    movq %r12, %rdi
    movq %r13, %rsi
    xorl %edx, %edx                 # site 0
    call sea_eig_sym_gen
    jmp 3f
2:  movq %r12, %rdi
    xorl %esi, %esi                 # site 0
    call sea_eig_sym
3:  movq %rax, %r14
    movq (%rbx), %rdi
    call putcstr
    TXT ":"
    xorl %r15d, %r15d
4:  cmpq SEA_ARR_ROWS(%r14), %r15
    jae 5f
    TXT " "
    movq SEA_ARR_DATA(%r14), %rax
    movq (%rax,%r15,8), %rdi
    call putf
    incq %r15
    jmp 4b
5:  TXT " | "
    movzbl SEA_ARR_RANK(%r14), %edi
    call putdec
    TXT " "
    movq SEA_ARR_ROWS(%r14), %rdi
    call putdec
    TXT " "
    movq SEA_ARR_COLS(%r14), %rdi
    call putdec
    TXT " rc="
    movq SEA_OBJ_RC(%r14), %rdi
    call putdec
    # The arguments are untouched (bit for bit).
    movq SEA_ARR_DATA(%r12), %rdi
    movq 24(%rbx), %rsi
    movq 16(%rbx), %rdx
    imulq %rdx, %rdx
    call eqbits
    movq %rax, %r15
    testq %r13, %r13
    jz 6f
    movq SEA_ARR_DATA(%r13), %rdi
    movq 32(%rbx), %rsi
    movq 16(%rbx), %rdx
    imulq %rdx, %rdx
    call eqbits
    orq %rax, %r15
6:  testq %r15, %r15
    jnz 7f
    TXT " args ok\n"
    jmp 8f
7:  TXT " args CHANGED\n"
8:  REL %r14
    REL %r12
    testq %r13, %r13
    jz 10f
    REL %r13
10: addq $VC_SIZE, %rbx
    jmp 1b
9:  EPILOGUE

    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    PROLOGUE
    call nvariants
    leaq -1(%rax), %rdi
    call usevariant
    TXT "pass 1\n"
    call runcases
    xorl %edi, %edi
    call usevariant
    TXT "pass 2\n"
    call runcases
    EPILOGUE
    .size sea_main, . - sea_main

    .section .data.rel.ro,"aw",@progbits
    .p2align 3
vcases:
    .quad .Ll0, 1, 0, .Ld0A, 0
    .quad .Ll1, 1, 6, .Ld1A, 0
    .quad .Ll2, 1, 1, .Ld2A, 0
    .quad .Ll3, 1, 2, .Ld3A, 0
    .quad .Ll4, 1, 2, .Ld4A, 0
    .quad .Ll5, 1, 10, .Ld5A, 0
    .quad .Ll6, 1, 4, .Ld6A, 0
    .quad .Ll7, 1, 3, .Ld7A, 0
    .quad .Ll8, 1, 40, .Ld8A, 0
    .quad .Ll9, 1, 2, .Ld9A, 0
    .quad .Ll10, 1, 3, .Ld10A, 0
    .quad .Ll11, 1, 2, .Ld11A, 0
    .quad .Ll12, 1, 3, .Ld12A, 0
    .quad .Ll13, 2, 0, .Ld13A, .Ld13M
    .quad .Ll14, 2, 3, .Ld14A, .Ld14M
    .quad .Ll15, 2, 2, .Ld15A, .Ld15M
    .quad .Ll16, 2, 3, .Ld16A, .Ld16M
    .quad .Ll17, 2, 40, .Ld17A, .Ld17M
    .quad .Ll18, 2, 2, .Ld18A, .Ld18M
    .quad .Ll19, 2, 2, .Ld19A, .Ld19M
    .quad .Ll20, 2, 2, .Ld20A, .Ld20M
    .quad .Ll21, 2, 2, .Ld21A, .Ld21M
    .quad 0
.Ld0A:
.Ll0: .asciz "eig_sym 0x0"
.Ld1A:
    .quad 0x4008000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0xBFF0000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x3FE0000000000000, 0x0000000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000
    .quad 0x0000000000000000, 0xC000000000000000, 0x0000000000000000, 0x0000000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000
    .quad 0x4000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000
.Ll1: .asciz "eig_sym diag"
.Ld2A:
    .quad 0x8000000000000000
.Ll2: .asciz "eig_sym 1x1 -0"
.Ld3A:
    .quad 0x8000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000
.Ll3: .asciz "eig_sym zeros +-0"
.Ld4A:
    .quad 0x4000000000000000, 0x3FF0000000000000, 0x3FF0000000000000, 0x4000000000000000
.Ll4: .asciz "eig_sym [2 1; 1 2]"
.Ld5A:
    .quad 0x4000000000000000, 0xBFF0000000000000, 0x0000000000000000, 0x0000000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0xBFF0000000000000, 0x4000000000000000
    .quad 0xBFF0000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000
    .quad 0x0000000000000000, 0xBFF0000000000000, 0x4000000000000000, 0xBFF0000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000
    .quad 0xBFF0000000000000, 0x4000000000000000, 0xBFF0000000000000, 0x0000000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0xBFF0000000000000
    .quad 0x4000000000000000, 0xBFF0000000000000, 0x0000000000000000, 0x0000000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0xBFF0000000000000, 0x4000000000000000
    .quad 0xBFF0000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000
    .quad 0x0000000000000000, 0xBFF0000000000000, 0x4000000000000000, 0xBFF0000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000
    .quad 0xBFF0000000000000, 0x4000000000000000, 0xBFF0000000000000, 0x0000000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0xBFF0000000000000
    .quad 0x4000000000000000, 0xBFF0000000000000, 0x0000000000000000, 0x0000000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0xBFF0000000000000, 0x4000000000000000
.Ll5: .asciz "eig_sym tridiag 10"
.Ld6A:
    .quad 0x4010000000000000, 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000
    .quad 0x3FF0000000000000, 0x4000000000000000, 0x0000000000000000, 0x3FF0000000000000
    .quad 0xC000000000000000, 0x0000000000000000, 0x4008000000000000, 0xC000000000000000
    .quad 0x4000000000000000, 0x3FF0000000000000, 0xC000000000000000, 0xBFF0000000000000
.Ll6: .asciz "eig_sym 4x4"
.Ld7A:
    .quad 0x3FF0000000000000, 0x4000000000000000, 0x0000000000000000, 0x4000000000000000
    .quad 0x3FF0000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000
    .quad 0x4014000000000000
.Ll7: .asciz "eig_sym zero row (scale 0)"
.Ld8A:
    .quad 0xC008000000000000, 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000
    .quad 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000, 0xC008000000000000
    .quad 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000
    .quad 0x4000000000000000, 0x4008000000000000, 0xC008000000000000, 0xC000000000000000
    .quad 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000, 0x4000000000000000
    .quad 0x4008000000000000, 0xC008000000000000, 0xC000000000000000, 0xBFF0000000000000
    .quad 0x0000000000000000, 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000
    .quad 0xC008000000000000, 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000
    .quad 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000, 0xC008000000000000
    .quad 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000
    .quad 0xC000000000000000, 0x0000000000000000, 0x4000000000000000, 0xC008000000000000
    .quad 0xBFF0000000000000, 0x3FF0000000000000, 0x4008000000000000, 0xC000000000000000
    .quad 0x0000000000000000, 0x4000000000000000, 0xC008000000000000, 0xBFF0000000000000
    .quad 0x3FF0000000000000, 0x4008000000000000, 0xC000000000000000, 0x0000000000000000
    .quad 0x4000000000000000, 0xC008000000000000, 0xBFF0000000000000, 0x3FF0000000000000
    .quad 0x4008000000000000, 0xC000000000000000, 0x0000000000000000, 0x4000000000000000
    .quad 0xC008000000000000, 0xBFF0000000000000, 0x3FF0000000000000, 0x4008000000000000
    .quad 0xC000000000000000, 0x0000000000000000, 0x4000000000000000, 0xC008000000000000
    .quad 0xBFF0000000000000, 0x3FF0000000000000, 0x4008000000000000, 0xC000000000000000
    .quad 0x0000000000000000, 0x4000000000000000, 0xC008000000000000, 0xBFF0000000000000
    .quad 0xBFF0000000000000, 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000
    .quad 0xC008000000000000, 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000
    .quad 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000, 0xC008000000000000
    .quad 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000, 0x4000000000000000
    .quad 0xC000000000000000, 0x3FF0000000000000, 0xC008000000000000, 0x0000000000000000
    .quad 0x4008000000000000, 0xBFF0000000000000, 0x4000000000000000, 0xC000000000000000
    .quad 0x3FF0000000000000, 0xC008000000000000, 0x0000000000000000, 0x4008000000000000
    .quad 0xBFF0000000000000, 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000
    .quad 0xC008000000000000, 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000
    .quad 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000, 0xC008000000000000
    .quad 0x0000000000000000, 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000
    .quad 0x4000000000000000, 0xBFF0000000000000, 0x4008000000000000, 0x0000000000000000
    .quad 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000
    .quad 0xBFF0000000000000, 0x4008000000000000, 0x0000000000000000, 0xC008000000000000
    .quad 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000, 0xBFF0000000000000
    .quad 0x4008000000000000, 0x0000000000000000, 0xC008000000000000, 0x3FF0000000000000
    .quad 0xC000000000000000, 0x4000000000000000, 0xBFF0000000000000, 0x4008000000000000
    .quad 0x0000000000000000, 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000
    .quad 0x4000000000000000, 0xBFF0000000000000, 0x4008000000000000, 0x0000000000000000
    .quad 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000
    .quad 0x3FF0000000000000, 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000
    .quad 0x0000000000000000, 0xC000000000000000, 0x4008000000000000, 0x3FF0000000000000
    .quad 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000, 0x0000000000000000
    .quad 0xC000000000000000, 0x4008000000000000, 0x3FF0000000000000, 0xBFF0000000000000
    .quad 0xC008000000000000, 0x4000000000000000, 0x0000000000000000, 0xC000000000000000
    .quad 0x4008000000000000, 0x3FF0000000000000, 0xBFF0000000000000, 0xC008000000000000
    .quad 0x4000000000000000, 0x0000000000000000, 0xC000000000000000, 0x4008000000000000
    .quad 0x3FF0000000000000, 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000
    .quad 0x0000000000000000, 0xC000000000000000, 0x4008000000000000, 0x3FF0000000000000
    .quad 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000, 0x0000000000000000
    .quad 0x4000000000000000, 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000
    .quad 0xC000000000000000, 0xC008000000000000, 0x4008000000000000, 0x4000000000000000
    .quad 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000, 0xC000000000000000
    .quad 0xC008000000000000, 0x4008000000000000, 0x4000000000000000, 0x3FF0000000000000
    .quad 0x0000000000000000, 0xBFF0000000000000, 0xC000000000000000, 0xC008000000000000
    .quad 0x4008000000000000, 0x4000000000000000, 0x3FF0000000000000, 0x0000000000000000
    .quad 0xBFF0000000000000, 0xC000000000000000, 0xC008000000000000, 0x4008000000000000
    .quad 0x4000000000000000, 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000
    .quad 0xC000000000000000, 0xC008000000000000, 0x4008000000000000, 0x4000000000000000
    .quad 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000, 0xC000000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0xC008000000000000, 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000
    .quad 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000, 0xC008000000000000
    .quad 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000
    .quad 0x4000000000000000, 0x4008000000000000, 0xC008000000000000, 0xC000000000000000
    .quad 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000, 0x4000000000000000
    .quad 0x4008000000000000, 0xC008000000000000, 0xC000000000000000, 0xBFF0000000000000
    .quad 0x0000000000000000, 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000
    .quad 0xC008000000000000, 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000
    .quad 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000, 0xC008000000000000
    .quad 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000
    .quad 0xC000000000000000, 0x0000000000000000, 0x4000000000000000, 0xC008000000000000
    .quad 0xBFF0000000000000, 0x3FF0000000000000, 0x4008000000000000, 0xC000000000000000
    .quad 0x0000000000000000, 0x4000000000000000, 0xC008000000000000, 0xBFF0000000000000
    .quad 0x3FF0000000000000, 0x4008000000000000, 0xC000000000000000, 0x0000000000000000
    .quad 0x4000000000000000, 0xC008000000000000, 0xBFF0000000000000, 0x3FF0000000000000
    .quad 0x4008000000000000, 0xC000000000000000, 0x0000000000000000, 0x4000000000000000
    .quad 0xC008000000000000, 0xBFF0000000000000, 0x3FF0000000000000, 0x4008000000000000
    .quad 0xC000000000000000, 0x0000000000000000, 0x4000000000000000, 0xC008000000000000
    .quad 0xBFF0000000000000, 0x3FF0000000000000, 0x4008000000000000, 0xC000000000000000
    .quad 0x0000000000000000, 0x4000000000000000, 0xC008000000000000, 0xBFF0000000000000
    .quad 0xBFF0000000000000, 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000
    .quad 0xC008000000000000, 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000
    .quad 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000, 0xC008000000000000
    .quad 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000, 0x4000000000000000
    .quad 0xC000000000000000, 0x3FF0000000000000, 0xC008000000000000, 0x0000000000000000
    .quad 0x4008000000000000, 0xBFF0000000000000, 0x4000000000000000, 0xC000000000000000
    .quad 0x3FF0000000000000, 0xC008000000000000, 0x0000000000000000, 0x4008000000000000
    .quad 0xBFF0000000000000, 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000
    .quad 0xC008000000000000, 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000
    .quad 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000, 0xC008000000000000
    .quad 0x0000000000000000, 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000
    .quad 0x4000000000000000, 0xBFF0000000000000, 0x4008000000000000, 0x0000000000000000
    .quad 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000
    .quad 0xBFF0000000000000, 0x4008000000000000, 0x0000000000000000, 0xC008000000000000
    .quad 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000, 0xBFF0000000000000
    .quad 0x4008000000000000, 0x0000000000000000, 0xC008000000000000, 0x3FF0000000000000
    .quad 0xC000000000000000, 0x4000000000000000, 0xBFF0000000000000, 0x4008000000000000
    .quad 0x0000000000000000, 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000
    .quad 0x4000000000000000, 0xBFF0000000000000, 0x4008000000000000, 0x0000000000000000
    .quad 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000
    .quad 0x3FF0000000000000, 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000
    .quad 0x0000000000000000, 0xC000000000000000, 0x4008000000000000, 0x3FF0000000000000
    .quad 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000, 0x0000000000000000
    .quad 0xC000000000000000, 0x4008000000000000, 0x3FF0000000000000, 0xBFF0000000000000
    .quad 0xC008000000000000, 0x4000000000000000, 0x0000000000000000, 0xC000000000000000
    .quad 0x4008000000000000, 0x3FF0000000000000, 0xBFF0000000000000, 0xC008000000000000
    .quad 0x4000000000000000, 0x0000000000000000, 0xC000000000000000, 0x4008000000000000
    .quad 0x3FF0000000000000, 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000
    .quad 0x0000000000000000, 0xC000000000000000, 0x4008000000000000, 0x3FF0000000000000
    .quad 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000, 0x0000000000000000
    .quad 0x4000000000000000, 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000
    .quad 0xC000000000000000, 0xC008000000000000, 0x4008000000000000, 0x4000000000000000
    .quad 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000, 0xC000000000000000
    .quad 0xC008000000000000, 0x4008000000000000, 0x4000000000000000, 0x3FF0000000000000
    .quad 0x0000000000000000, 0xBFF0000000000000, 0xC000000000000000, 0xC008000000000000
    .quad 0x4008000000000000, 0x4000000000000000, 0x3FF0000000000000, 0x0000000000000000
    .quad 0xBFF0000000000000, 0xC000000000000000, 0xC008000000000000, 0x4008000000000000
    .quad 0x4000000000000000, 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000
    .quad 0xC000000000000000, 0xC008000000000000, 0x4008000000000000, 0x4000000000000000
    .quad 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000, 0xC000000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0xC008000000000000, 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000
    .quad 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000, 0xC008000000000000
    .quad 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000
    .quad 0x4000000000000000, 0x4008000000000000, 0xC008000000000000, 0xC000000000000000
    .quad 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000, 0x4000000000000000
    .quad 0x4008000000000000, 0xC008000000000000, 0xC000000000000000, 0xBFF0000000000000
    .quad 0x0000000000000000, 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000
    .quad 0xC008000000000000, 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000
    .quad 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000, 0xC008000000000000
    .quad 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000
    .quad 0xC000000000000000, 0x0000000000000000, 0x4000000000000000, 0xC008000000000000
    .quad 0xBFF0000000000000, 0x3FF0000000000000, 0x4008000000000000, 0xC000000000000000
    .quad 0x0000000000000000, 0x4000000000000000, 0xC008000000000000, 0xBFF0000000000000
    .quad 0x3FF0000000000000, 0x4008000000000000, 0xC000000000000000, 0x0000000000000000
    .quad 0x4000000000000000, 0xC008000000000000, 0xBFF0000000000000, 0x3FF0000000000000
    .quad 0x4008000000000000, 0xC000000000000000, 0x0000000000000000, 0x4000000000000000
    .quad 0xC008000000000000, 0xBFF0000000000000, 0x3FF0000000000000, 0x4008000000000000
    .quad 0xC000000000000000, 0x0000000000000000, 0x4000000000000000, 0xC008000000000000
    .quad 0xBFF0000000000000, 0x3FF0000000000000, 0x4008000000000000, 0xC000000000000000
    .quad 0x0000000000000000, 0x4000000000000000, 0xC008000000000000, 0xBFF0000000000000
    .quad 0xBFF0000000000000, 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000
    .quad 0xC008000000000000, 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000
    .quad 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000, 0xC008000000000000
    .quad 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000, 0x4000000000000000
    .quad 0xC000000000000000, 0x3FF0000000000000, 0xC008000000000000, 0x0000000000000000
    .quad 0x4008000000000000, 0xBFF0000000000000, 0x4000000000000000, 0xC000000000000000
    .quad 0x3FF0000000000000, 0xC008000000000000, 0x0000000000000000, 0x4008000000000000
    .quad 0xBFF0000000000000, 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000
    .quad 0xC008000000000000, 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000
    .quad 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000, 0xC008000000000000
    .quad 0x0000000000000000, 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000
    .quad 0x4000000000000000, 0xBFF0000000000000, 0x4008000000000000, 0x0000000000000000
    .quad 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000
    .quad 0xBFF0000000000000, 0x4008000000000000, 0x0000000000000000, 0xC008000000000000
    .quad 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000, 0xBFF0000000000000
    .quad 0x4008000000000000, 0x0000000000000000, 0xC008000000000000, 0x3FF0000000000000
    .quad 0xC000000000000000, 0x4000000000000000, 0xBFF0000000000000, 0x4008000000000000
    .quad 0x0000000000000000, 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000
    .quad 0x4000000000000000, 0xBFF0000000000000, 0x4008000000000000, 0x0000000000000000
    .quad 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000
    .quad 0x3FF0000000000000, 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000
    .quad 0x0000000000000000, 0xC000000000000000, 0x4008000000000000, 0x3FF0000000000000
    .quad 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000, 0x0000000000000000
    .quad 0xC000000000000000, 0x4008000000000000, 0x3FF0000000000000, 0xBFF0000000000000
    .quad 0xC008000000000000, 0x4000000000000000, 0x0000000000000000, 0xC000000000000000
    .quad 0x4008000000000000, 0x3FF0000000000000, 0xBFF0000000000000, 0xC008000000000000
    .quad 0x4000000000000000, 0x0000000000000000, 0xC000000000000000, 0x4008000000000000
    .quad 0x3FF0000000000000, 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000
    .quad 0x0000000000000000, 0xC000000000000000, 0x4008000000000000, 0x3FF0000000000000
    .quad 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000, 0x0000000000000000
    .quad 0x4000000000000000, 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000
    .quad 0xC000000000000000, 0xC008000000000000, 0x4008000000000000, 0x4000000000000000
    .quad 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000, 0xC000000000000000
    .quad 0xC008000000000000, 0x4008000000000000, 0x4000000000000000, 0x3FF0000000000000
    .quad 0x0000000000000000, 0xBFF0000000000000, 0xC000000000000000, 0xC008000000000000
    .quad 0x4008000000000000, 0x4000000000000000, 0x3FF0000000000000, 0x0000000000000000
    .quad 0xBFF0000000000000, 0xC000000000000000, 0xC008000000000000, 0x4008000000000000
    .quad 0x4000000000000000, 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000
    .quad 0xC000000000000000, 0xC008000000000000, 0x4008000000000000, 0x4000000000000000
    .quad 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000, 0xC000000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0xC008000000000000, 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000
    .quad 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000, 0xC008000000000000
    .quad 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000
    .quad 0x4000000000000000, 0x4008000000000000, 0xC008000000000000, 0xC000000000000000
    .quad 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000, 0x4000000000000000
    .quad 0x4008000000000000, 0xC008000000000000, 0xC000000000000000, 0xBFF0000000000000
    .quad 0x0000000000000000, 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000
    .quad 0xC008000000000000, 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000
    .quad 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000, 0xC008000000000000
    .quad 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000
    .quad 0xC000000000000000, 0x0000000000000000, 0x4000000000000000, 0xC008000000000000
    .quad 0xBFF0000000000000, 0x3FF0000000000000, 0x4008000000000000, 0xC000000000000000
    .quad 0x0000000000000000, 0x4000000000000000, 0xC008000000000000, 0xBFF0000000000000
    .quad 0x3FF0000000000000, 0x4008000000000000, 0xC000000000000000, 0x0000000000000000
    .quad 0x4000000000000000, 0xC008000000000000, 0xBFF0000000000000, 0x3FF0000000000000
    .quad 0x4008000000000000, 0xC000000000000000, 0x0000000000000000, 0x4000000000000000
    .quad 0xC008000000000000, 0xBFF0000000000000, 0x3FF0000000000000, 0x4008000000000000
    .quad 0xC000000000000000, 0x0000000000000000, 0x4000000000000000, 0xC008000000000000
    .quad 0xBFF0000000000000, 0x3FF0000000000000, 0x4008000000000000, 0xC000000000000000
    .quad 0x0000000000000000, 0x4000000000000000, 0xC008000000000000, 0xBFF0000000000000
    .quad 0xBFF0000000000000, 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000
    .quad 0xC008000000000000, 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000
    .quad 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000, 0xC008000000000000
    .quad 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000, 0x4000000000000000
    .quad 0xC000000000000000, 0x3FF0000000000000, 0xC008000000000000, 0x0000000000000000
    .quad 0x4008000000000000, 0xBFF0000000000000, 0x4000000000000000, 0xC000000000000000
    .quad 0x3FF0000000000000, 0xC008000000000000, 0x0000000000000000, 0x4008000000000000
    .quad 0xBFF0000000000000, 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000
    .quad 0xC008000000000000, 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000
    .quad 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000, 0xC008000000000000
    .quad 0x0000000000000000, 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000
    .quad 0x4000000000000000, 0xBFF0000000000000, 0x4008000000000000, 0x0000000000000000
    .quad 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000
    .quad 0xBFF0000000000000, 0x4008000000000000, 0x0000000000000000, 0xC008000000000000
    .quad 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000, 0xBFF0000000000000
    .quad 0x4008000000000000, 0x0000000000000000, 0xC008000000000000, 0x3FF0000000000000
    .quad 0xC000000000000000, 0x4000000000000000, 0xBFF0000000000000, 0x4008000000000000
    .quad 0x0000000000000000, 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000
    .quad 0x4000000000000000, 0xBFF0000000000000, 0x4008000000000000, 0x0000000000000000
    .quad 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000
    .quad 0x3FF0000000000000, 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000
    .quad 0x0000000000000000, 0xC000000000000000, 0x4008000000000000, 0x3FF0000000000000
    .quad 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000, 0x0000000000000000
    .quad 0xC000000000000000, 0x4008000000000000, 0x3FF0000000000000, 0xBFF0000000000000
    .quad 0xC008000000000000, 0x4000000000000000, 0x0000000000000000, 0xC000000000000000
    .quad 0x4008000000000000, 0x3FF0000000000000, 0xBFF0000000000000, 0xC008000000000000
    .quad 0x4000000000000000, 0x0000000000000000, 0xC000000000000000, 0x4008000000000000
    .quad 0x3FF0000000000000, 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000
    .quad 0x0000000000000000, 0xC000000000000000, 0x4008000000000000, 0x3FF0000000000000
    .quad 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000, 0x0000000000000000
    .quad 0x4000000000000000, 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000
    .quad 0xC000000000000000, 0xC008000000000000, 0x4008000000000000, 0x4000000000000000
    .quad 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000, 0xC000000000000000
    .quad 0xC008000000000000, 0x4008000000000000, 0x4000000000000000, 0x3FF0000000000000
    .quad 0x0000000000000000, 0xBFF0000000000000, 0xC000000000000000, 0xC008000000000000
    .quad 0x4008000000000000, 0x4000000000000000, 0x3FF0000000000000, 0x0000000000000000
    .quad 0xBFF0000000000000, 0xC000000000000000, 0xC008000000000000, 0x4008000000000000
    .quad 0x4000000000000000, 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000
    .quad 0xC000000000000000, 0xC008000000000000, 0x4008000000000000, 0x4000000000000000
    .quad 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000, 0xC000000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0xC008000000000000, 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000
    .quad 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000, 0xC008000000000000
    .quad 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000
    .quad 0x4000000000000000, 0x4008000000000000, 0xC008000000000000, 0xC000000000000000
    .quad 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000, 0x4000000000000000
    .quad 0x4008000000000000, 0xC008000000000000, 0xC000000000000000, 0xBFF0000000000000
    .quad 0x0000000000000000, 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000
    .quad 0xC008000000000000, 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000
    .quad 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000, 0xC008000000000000
    .quad 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000
    .quad 0xC000000000000000, 0x0000000000000000, 0x4000000000000000, 0xC008000000000000
    .quad 0xBFF0000000000000, 0x3FF0000000000000, 0x4008000000000000, 0xC000000000000000
    .quad 0x0000000000000000, 0x4000000000000000, 0xC008000000000000, 0xBFF0000000000000
    .quad 0x3FF0000000000000, 0x4008000000000000, 0xC000000000000000, 0x0000000000000000
    .quad 0x4000000000000000, 0xC008000000000000, 0xBFF0000000000000, 0x3FF0000000000000
    .quad 0x4008000000000000, 0xC000000000000000, 0x0000000000000000, 0x4000000000000000
    .quad 0xC008000000000000, 0xBFF0000000000000, 0x3FF0000000000000, 0x4008000000000000
    .quad 0xC000000000000000, 0x0000000000000000, 0x4000000000000000, 0xC008000000000000
    .quad 0xBFF0000000000000, 0x3FF0000000000000, 0x4008000000000000, 0xC000000000000000
    .quad 0x0000000000000000, 0x4000000000000000, 0xC008000000000000, 0xBFF0000000000000
    .quad 0xBFF0000000000000, 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000
    .quad 0xC008000000000000, 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000
    .quad 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000, 0xC008000000000000
    .quad 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000, 0x4000000000000000
    .quad 0xC000000000000000, 0x3FF0000000000000, 0xC008000000000000, 0x0000000000000000
    .quad 0x4008000000000000, 0xBFF0000000000000, 0x4000000000000000, 0xC000000000000000
    .quad 0x3FF0000000000000, 0xC008000000000000, 0x0000000000000000, 0x4008000000000000
    .quad 0xBFF0000000000000, 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000
    .quad 0xC008000000000000, 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000
    .quad 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000, 0xC008000000000000
    .quad 0x0000000000000000, 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000
    .quad 0x4000000000000000, 0xBFF0000000000000, 0x4008000000000000, 0x0000000000000000
    .quad 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000
    .quad 0xBFF0000000000000, 0x4008000000000000, 0x0000000000000000, 0xC008000000000000
    .quad 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000, 0xBFF0000000000000
    .quad 0x4008000000000000, 0x0000000000000000, 0xC008000000000000, 0x3FF0000000000000
    .quad 0xC000000000000000, 0x4000000000000000, 0xBFF0000000000000, 0x4008000000000000
    .quad 0x0000000000000000, 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000
    .quad 0x4000000000000000, 0xBFF0000000000000, 0x4008000000000000, 0x0000000000000000
    .quad 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000
    .quad 0x3FF0000000000000, 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000
    .quad 0x0000000000000000, 0xC000000000000000, 0x4008000000000000, 0x3FF0000000000000
    .quad 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000, 0x0000000000000000
    .quad 0xC000000000000000, 0x4008000000000000, 0x3FF0000000000000, 0xBFF0000000000000
    .quad 0xC008000000000000, 0x4000000000000000, 0x0000000000000000, 0xC000000000000000
    .quad 0x4008000000000000, 0x3FF0000000000000, 0xBFF0000000000000, 0xC008000000000000
    .quad 0x4000000000000000, 0x0000000000000000, 0xC000000000000000, 0x4008000000000000
    .quad 0x3FF0000000000000, 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000
    .quad 0x0000000000000000, 0xC000000000000000, 0x4008000000000000, 0x3FF0000000000000
    .quad 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000, 0x0000000000000000
    .quad 0x4000000000000000, 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000
    .quad 0xC000000000000000, 0xC008000000000000, 0x4008000000000000, 0x4000000000000000
    .quad 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000, 0xC000000000000000
    .quad 0xC008000000000000, 0x4008000000000000, 0x4000000000000000, 0x3FF0000000000000
    .quad 0x0000000000000000, 0xBFF0000000000000, 0xC000000000000000, 0xC008000000000000
    .quad 0x4008000000000000, 0x4000000000000000, 0x3FF0000000000000, 0x0000000000000000
    .quad 0xBFF0000000000000, 0xC000000000000000, 0xC008000000000000, 0x4008000000000000
    .quad 0x4000000000000000, 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000
    .quad 0xC000000000000000, 0xC008000000000000, 0x4008000000000000, 0x4000000000000000
    .quad 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000, 0xC000000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0xC008000000000000, 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000
    .quad 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000, 0xC008000000000000
    .quad 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000
    .quad 0x4000000000000000, 0x4008000000000000, 0xC008000000000000, 0xC000000000000000
    .quad 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000, 0x4000000000000000
    .quad 0x4008000000000000, 0xC008000000000000, 0xC000000000000000, 0xBFF0000000000000
    .quad 0x0000000000000000, 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000
    .quad 0xC008000000000000, 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000
    .quad 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000, 0xC008000000000000
    .quad 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000
    .quad 0xC000000000000000, 0x0000000000000000, 0x4000000000000000, 0xC008000000000000
    .quad 0xBFF0000000000000, 0x3FF0000000000000, 0x4008000000000000, 0xC000000000000000
    .quad 0x0000000000000000, 0x4000000000000000, 0xC008000000000000, 0xBFF0000000000000
    .quad 0x3FF0000000000000, 0x4008000000000000, 0xC000000000000000, 0x0000000000000000
    .quad 0x4000000000000000, 0xC008000000000000, 0xBFF0000000000000, 0x3FF0000000000000
    .quad 0x4008000000000000, 0xC000000000000000, 0x0000000000000000, 0x4000000000000000
    .quad 0xC008000000000000, 0xBFF0000000000000, 0x3FF0000000000000, 0x4008000000000000
    .quad 0xC000000000000000, 0x0000000000000000, 0x4000000000000000, 0xC008000000000000
    .quad 0xBFF0000000000000, 0x3FF0000000000000, 0x4008000000000000, 0xC000000000000000
    .quad 0x0000000000000000, 0x4000000000000000, 0xC008000000000000, 0xBFF0000000000000
    .quad 0xBFF0000000000000, 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000
    .quad 0xC008000000000000, 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000
    .quad 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000, 0xC008000000000000
    .quad 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000, 0x4000000000000000
    .quad 0xC000000000000000, 0x3FF0000000000000, 0xC008000000000000, 0x0000000000000000
    .quad 0x4008000000000000, 0xBFF0000000000000, 0x4000000000000000, 0xC000000000000000
    .quad 0x3FF0000000000000, 0xC008000000000000, 0x0000000000000000, 0x4008000000000000
    .quad 0xBFF0000000000000, 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000
    .quad 0xC008000000000000, 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000
    .quad 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000, 0xC008000000000000
    .quad 0x0000000000000000, 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000
    .quad 0x4000000000000000, 0xBFF0000000000000, 0x4008000000000000, 0x0000000000000000
    .quad 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000
    .quad 0xBFF0000000000000, 0x4008000000000000, 0x0000000000000000, 0xC008000000000000
    .quad 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000, 0xBFF0000000000000
    .quad 0x4008000000000000, 0x0000000000000000, 0xC008000000000000, 0x3FF0000000000000
    .quad 0xC000000000000000, 0x4000000000000000, 0xBFF0000000000000, 0x4008000000000000
    .quad 0x0000000000000000, 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000
    .quad 0x4000000000000000, 0xBFF0000000000000, 0x4008000000000000, 0x0000000000000000
    .quad 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000
    .quad 0x3FF0000000000000, 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000
    .quad 0x0000000000000000, 0xC000000000000000, 0x4008000000000000, 0x3FF0000000000000
    .quad 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000, 0x0000000000000000
    .quad 0xC000000000000000, 0x4008000000000000, 0x3FF0000000000000, 0xBFF0000000000000
    .quad 0xC008000000000000, 0x4000000000000000, 0x0000000000000000, 0xC000000000000000
    .quad 0x4008000000000000, 0x3FF0000000000000, 0xBFF0000000000000, 0xC008000000000000
    .quad 0x4000000000000000, 0x0000000000000000, 0xC000000000000000, 0x4008000000000000
    .quad 0x3FF0000000000000, 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000
    .quad 0x0000000000000000, 0xC000000000000000, 0x4008000000000000, 0x3FF0000000000000
    .quad 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000, 0x0000000000000000
.Ll8: .asciz "eig_sym 40"
.Ld9A:
    .quad 0x7FE1CCF385EBC8A0, 0x7FE1CCF385EBC8A0, 0x7FE1CCF385EBC8A0, 0x7FE1CCF385EBC8A0
.Ll9: .asciz "eig_sym 2x2 1e308"
.Ld10A:
    .quad 0x7FE1CCF385EBC8A0, 0x7FE1CCF385EBC8A0, 0x7FE1CCF385EBC8A0, 0x7FE1CCF385EBC8A0
    .quad 0x7FE1CCF385EBC8A0, 0x7FE1CCF385EBC8A0, 0x7FE1CCF385EBC8A0, 0x7FE1CCF385EBC8A0
    .quad 0x7FE1CCF385EBC8A0
.Ll10: .asciz "eig_sym 3x3 1e308 (scale Inf)"
.Ld11A:
    .quad 0x3FF0000000000000, 0x7FF0000000000000, 0x7FF0000000000000, 0x4000000000000000
.Ll11: .asciz "eig_sym Inf"
.Ld12A:
    .quad 0x3FF0000000000000, 0x7FF8000000000000, 0x0000000000000000, 0x7FF8000000000000
    .quad 0x4000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000
    .quad 0x4008000000000000
.Ll12: .asciz "eig_sym NaN pair"
.Ld13A:
.Ld13M:
.Ll13: .asciz "eig_sym_gen 0x0"
.Ld14A:
    .quad 0x4000000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000
    .quad 0x4018000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000
    .quad 0xC008000000000000
.Ld14M:
    .quad 0x4010000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000
    .quad 0x4030000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000
    .quad 0x3FD0000000000000
.Ll14: .asciz "eig_sym_gen diag K, power-of-four M"
.Ld15A:
    .quad 0x4000000000000000, 0xBFF0000000000000, 0xBFF0000000000000, 0x3FF0000000000000
.Ld15M:
    .quad 0x4000000000000000, 0x3FF0000000000000, 0x3FF0000000000000, 0x4008000000000000
.Ll15: .asciz "eig_sym_gen 2x2"
.Ld16A:
    .quad 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000, 0x4000000000000000
    .quad 0xBFF0000000000000, 0x3FE0000000000000, 0x4008000000000000, 0x3FE0000000000000
    .quad 0x4010000000000000
.Ld16M:
    .quad 0x4010000000000000, 0x4000000000000000, 0x0000000000000000, 0x4000000000000000
    .quad 0x4014000000000000, 0x3FF0000000000000, 0x0000000000000000, 0x3FF0000000000000
    .quad 0x4008000000000000
.Ll16: .asciz "eig_sym_gen 3x3"
.Ld17A:
    .quad 0xC008000000000000, 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000
    .quad 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000, 0xC008000000000000
    .quad 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000
    .quad 0x4000000000000000, 0x4008000000000000, 0xC008000000000000, 0xC000000000000000
    .quad 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000, 0x4000000000000000
    .quad 0x4008000000000000, 0xC008000000000000, 0xC000000000000000, 0xBFF0000000000000
    .quad 0x0000000000000000, 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000
    .quad 0xC008000000000000, 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000
    .quad 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000, 0xC008000000000000
    .quad 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000
    .quad 0xC000000000000000, 0x0000000000000000, 0x4000000000000000, 0xC008000000000000
    .quad 0xBFF0000000000000, 0x3FF0000000000000, 0x4008000000000000, 0xC000000000000000
    .quad 0x0000000000000000, 0x4000000000000000, 0xC008000000000000, 0xBFF0000000000000
    .quad 0x3FF0000000000000, 0x4008000000000000, 0xC000000000000000, 0x0000000000000000
    .quad 0x4000000000000000, 0xC008000000000000, 0xBFF0000000000000, 0x3FF0000000000000
    .quad 0x4008000000000000, 0xC000000000000000, 0x0000000000000000, 0x4000000000000000
    .quad 0xC008000000000000, 0xBFF0000000000000, 0x3FF0000000000000, 0x4008000000000000
    .quad 0xC000000000000000, 0x0000000000000000, 0x4000000000000000, 0xC008000000000000
    .quad 0xBFF0000000000000, 0x3FF0000000000000, 0x4008000000000000, 0xC000000000000000
    .quad 0x0000000000000000, 0x4000000000000000, 0xC008000000000000, 0xBFF0000000000000
    .quad 0xBFF0000000000000, 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000
    .quad 0xC008000000000000, 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000
    .quad 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000, 0xC008000000000000
    .quad 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000, 0x4000000000000000
    .quad 0xC000000000000000, 0x3FF0000000000000, 0xC008000000000000, 0x0000000000000000
    .quad 0x4008000000000000, 0xBFF0000000000000, 0x4000000000000000, 0xC000000000000000
    .quad 0x3FF0000000000000, 0xC008000000000000, 0x0000000000000000, 0x4008000000000000
    .quad 0xBFF0000000000000, 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000
    .quad 0xC008000000000000, 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000
    .quad 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000, 0xC008000000000000
    .quad 0x0000000000000000, 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000
    .quad 0x4000000000000000, 0xBFF0000000000000, 0x4008000000000000, 0x0000000000000000
    .quad 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000
    .quad 0xBFF0000000000000, 0x4008000000000000, 0x0000000000000000, 0xC008000000000000
    .quad 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000, 0xBFF0000000000000
    .quad 0x4008000000000000, 0x0000000000000000, 0xC008000000000000, 0x3FF0000000000000
    .quad 0xC000000000000000, 0x4000000000000000, 0xBFF0000000000000, 0x4008000000000000
    .quad 0x0000000000000000, 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000
    .quad 0x4000000000000000, 0xBFF0000000000000, 0x4008000000000000, 0x0000000000000000
    .quad 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000
    .quad 0x3FF0000000000000, 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000
    .quad 0x0000000000000000, 0xC000000000000000, 0x4008000000000000, 0x3FF0000000000000
    .quad 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000, 0x0000000000000000
    .quad 0xC000000000000000, 0x4008000000000000, 0x3FF0000000000000, 0xBFF0000000000000
    .quad 0xC008000000000000, 0x4000000000000000, 0x0000000000000000, 0xC000000000000000
    .quad 0x4008000000000000, 0x3FF0000000000000, 0xBFF0000000000000, 0xC008000000000000
    .quad 0x4000000000000000, 0x0000000000000000, 0xC000000000000000, 0x4008000000000000
    .quad 0x3FF0000000000000, 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000
    .quad 0x0000000000000000, 0xC000000000000000, 0x4008000000000000, 0x3FF0000000000000
    .quad 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000, 0x0000000000000000
    .quad 0x4000000000000000, 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000
    .quad 0xC000000000000000, 0xC008000000000000, 0x4008000000000000, 0x4000000000000000
    .quad 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000, 0xC000000000000000
    .quad 0xC008000000000000, 0x4008000000000000, 0x4000000000000000, 0x3FF0000000000000
    .quad 0x0000000000000000, 0xBFF0000000000000, 0xC000000000000000, 0xC008000000000000
    .quad 0x4008000000000000, 0x4000000000000000, 0x3FF0000000000000, 0x0000000000000000
    .quad 0xBFF0000000000000, 0xC000000000000000, 0xC008000000000000, 0x4008000000000000
    .quad 0x4000000000000000, 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000
    .quad 0xC000000000000000, 0xC008000000000000, 0x4008000000000000, 0x4000000000000000
    .quad 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000, 0xC000000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0xC008000000000000, 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000
    .quad 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000, 0xC008000000000000
    .quad 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000
    .quad 0x4000000000000000, 0x4008000000000000, 0xC008000000000000, 0xC000000000000000
    .quad 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000, 0x4000000000000000
    .quad 0x4008000000000000, 0xC008000000000000, 0xC000000000000000, 0xBFF0000000000000
    .quad 0x0000000000000000, 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000
    .quad 0xC008000000000000, 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000
    .quad 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000, 0xC008000000000000
    .quad 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000
    .quad 0xC000000000000000, 0x0000000000000000, 0x4000000000000000, 0xC008000000000000
    .quad 0xBFF0000000000000, 0x3FF0000000000000, 0x4008000000000000, 0xC000000000000000
    .quad 0x0000000000000000, 0x4000000000000000, 0xC008000000000000, 0xBFF0000000000000
    .quad 0x3FF0000000000000, 0x4008000000000000, 0xC000000000000000, 0x0000000000000000
    .quad 0x4000000000000000, 0xC008000000000000, 0xBFF0000000000000, 0x3FF0000000000000
    .quad 0x4008000000000000, 0xC000000000000000, 0x0000000000000000, 0x4000000000000000
    .quad 0xC008000000000000, 0xBFF0000000000000, 0x3FF0000000000000, 0x4008000000000000
    .quad 0xC000000000000000, 0x0000000000000000, 0x4000000000000000, 0xC008000000000000
    .quad 0xBFF0000000000000, 0x3FF0000000000000, 0x4008000000000000, 0xC000000000000000
    .quad 0x0000000000000000, 0x4000000000000000, 0xC008000000000000, 0xBFF0000000000000
    .quad 0xBFF0000000000000, 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000
    .quad 0xC008000000000000, 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000
    .quad 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000, 0xC008000000000000
    .quad 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000, 0x4000000000000000
    .quad 0xC000000000000000, 0x3FF0000000000000, 0xC008000000000000, 0x0000000000000000
    .quad 0x4008000000000000, 0xBFF0000000000000, 0x4000000000000000, 0xC000000000000000
    .quad 0x3FF0000000000000, 0xC008000000000000, 0x0000000000000000, 0x4008000000000000
    .quad 0xBFF0000000000000, 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000
    .quad 0xC008000000000000, 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000
    .quad 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000, 0xC008000000000000
    .quad 0x0000000000000000, 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000
    .quad 0x4000000000000000, 0xBFF0000000000000, 0x4008000000000000, 0x0000000000000000
    .quad 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000
    .quad 0xBFF0000000000000, 0x4008000000000000, 0x0000000000000000, 0xC008000000000000
    .quad 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000, 0xBFF0000000000000
    .quad 0x4008000000000000, 0x0000000000000000, 0xC008000000000000, 0x3FF0000000000000
    .quad 0xC000000000000000, 0x4000000000000000, 0xBFF0000000000000, 0x4008000000000000
    .quad 0x0000000000000000, 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000
    .quad 0x4000000000000000, 0xBFF0000000000000, 0x4008000000000000, 0x0000000000000000
    .quad 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000
    .quad 0x3FF0000000000000, 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000
    .quad 0x0000000000000000, 0xC000000000000000, 0x4008000000000000, 0x3FF0000000000000
    .quad 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000, 0x0000000000000000
    .quad 0xC000000000000000, 0x4008000000000000, 0x3FF0000000000000, 0xBFF0000000000000
    .quad 0xC008000000000000, 0x4000000000000000, 0x0000000000000000, 0xC000000000000000
    .quad 0x4008000000000000, 0x3FF0000000000000, 0xBFF0000000000000, 0xC008000000000000
    .quad 0x4000000000000000, 0x0000000000000000, 0xC000000000000000, 0x4008000000000000
    .quad 0x3FF0000000000000, 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000
    .quad 0x0000000000000000, 0xC000000000000000, 0x4008000000000000, 0x3FF0000000000000
    .quad 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000, 0x0000000000000000
    .quad 0x4000000000000000, 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000
    .quad 0xC000000000000000, 0xC008000000000000, 0x4008000000000000, 0x4000000000000000
    .quad 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000, 0xC000000000000000
    .quad 0xC008000000000000, 0x4008000000000000, 0x4000000000000000, 0x3FF0000000000000
    .quad 0x0000000000000000, 0xBFF0000000000000, 0xC000000000000000, 0xC008000000000000
    .quad 0x4008000000000000, 0x4000000000000000, 0x3FF0000000000000, 0x0000000000000000
    .quad 0xBFF0000000000000, 0xC000000000000000, 0xC008000000000000, 0x4008000000000000
    .quad 0x4000000000000000, 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000
    .quad 0xC000000000000000, 0xC008000000000000, 0x4008000000000000, 0x4000000000000000
    .quad 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000, 0xC000000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0xC008000000000000, 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000
    .quad 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000, 0xC008000000000000
    .quad 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000
    .quad 0x4000000000000000, 0x4008000000000000, 0xC008000000000000, 0xC000000000000000
    .quad 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000, 0x4000000000000000
    .quad 0x4008000000000000, 0xC008000000000000, 0xC000000000000000, 0xBFF0000000000000
    .quad 0x0000000000000000, 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000
    .quad 0xC008000000000000, 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000
    .quad 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000, 0xC008000000000000
    .quad 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000
    .quad 0xC000000000000000, 0x0000000000000000, 0x4000000000000000, 0xC008000000000000
    .quad 0xBFF0000000000000, 0x3FF0000000000000, 0x4008000000000000, 0xC000000000000000
    .quad 0x0000000000000000, 0x4000000000000000, 0xC008000000000000, 0xBFF0000000000000
    .quad 0x3FF0000000000000, 0x4008000000000000, 0xC000000000000000, 0x0000000000000000
    .quad 0x4000000000000000, 0xC008000000000000, 0xBFF0000000000000, 0x3FF0000000000000
    .quad 0x4008000000000000, 0xC000000000000000, 0x0000000000000000, 0x4000000000000000
    .quad 0xC008000000000000, 0xBFF0000000000000, 0x3FF0000000000000, 0x4008000000000000
    .quad 0xC000000000000000, 0x0000000000000000, 0x4000000000000000, 0xC008000000000000
    .quad 0xBFF0000000000000, 0x3FF0000000000000, 0x4008000000000000, 0xC000000000000000
    .quad 0x0000000000000000, 0x4000000000000000, 0xC008000000000000, 0xBFF0000000000000
    .quad 0xBFF0000000000000, 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000
    .quad 0xC008000000000000, 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000
    .quad 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000, 0xC008000000000000
    .quad 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000, 0x4000000000000000
    .quad 0xC000000000000000, 0x3FF0000000000000, 0xC008000000000000, 0x0000000000000000
    .quad 0x4008000000000000, 0xBFF0000000000000, 0x4000000000000000, 0xC000000000000000
    .quad 0x3FF0000000000000, 0xC008000000000000, 0x0000000000000000, 0x4008000000000000
    .quad 0xBFF0000000000000, 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000
    .quad 0xC008000000000000, 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000
    .quad 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000, 0xC008000000000000
    .quad 0x0000000000000000, 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000
    .quad 0x4000000000000000, 0xBFF0000000000000, 0x4008000000000000, 0x0000000000000000
    .quad 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000
    .quad 0xBFF0000000000000, 0x4008000000000000, 0x0000000000000000, 0xC008000000000000
    .quad 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000, 0xBFF0000000000000
    .quad 0x4008000000000000, 0x0000000000000000, 0xC008000000000000, 0x3FF0000000000000
    .quad 0xC000000000000000, 0x4000000000000000, 0xBFF0000000000000, 0x4008000000000000
    .quad 0x0000000000000000, 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000
    .quad 0x4000000000000000, 0xBFF0000000000000, 0x4008000000000000, 0x0000000000000000
    .quad 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000
    .quad 0x3FF0000000000000, 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000
    .quad 0x0000000000000000, 0xC000000000000000, 0x4008000000000000, 0x3FF0000000000000
    .quad 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000, 0x0000000000000000
    .quad 0xC000000000000000, 0x4008000000000000, 0x3FF0000000000000, 0xBFF0000000000000
    .quad 0xC008000000000000, 0x4000000000000000, 0x0000000000000000, 0xC000000000000000
    .quad 0x4008000000000000, 0x3FF0000000000000, 0xBFF0000000000000, 0xC008000000000000
    .quad 0x4000000000000000, 0x0000000000000000, 0xC000000000000000, 0x4008000000000000
    .quad 0x3FF0000000000000, 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000
    .quad 0x0000000000000000, 0xC000000000000000, 0x4008000000000000, 0x3FF0000000000000
    .quad 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000, 0x0000000000000000
    .quad 0x4000000000000000, 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000
    .quad 0xC000000000000000, 0xC008000000000000, 0x4008000000000000, 0x4000000000000000
    .quad 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000, 0xC000000000000000
    .quad 0xC008000000000000, 0x4008000000000000, 0x4000000000000000, 0x3FF0000000000000
    .quad 0x0000000000000000, 0xBFF0000000000000, 0xC000000000000000, 0xC008000000000000
    .quad 0x4008000000000000, 0x4000000000000000, 0x3FF0000000000000, 0x0000000000000000
    .quad 0xBFF0000000000000, 0xC000000000000000, 0xC008000000000000, 0x4008000000000000
    .quad 0x4000000000000000, 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000
    .quad 0xC000000000000000, 0xC008000000000000, 0x4008000000000000, 0x4000000000000000
    .quad 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000, 0xC000000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0xC008000000000000, 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000
    .quad 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000, 0xC008000000000000
    .quad 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000
    .quad 0x4000000000000000, 0x4008000000000000, 0xC008000000000000, 0xC000000000000000
    .quad 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000, 0x4000000000000000
    .quad 0x4008000000000000, 0xC008000000000000, 0xC000000000000000, 0xBFF0000000000000
    .quad 0x0000000000000000, 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000
    .quad 0xC008000000000000, 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000
    .quad 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000, 0xC008000000000000
    .quad 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000
    .quad 0xC000000000000000, 0x0000000000000000, 0x4000000000000000, 0xC008000000000000
    .quad 0xBFF0000000000000, 0x3FF0000000000000, 0x4008000000000000, 0xC000000000000000
    .quad 0x0000000000000000, 0x4000000000000000, 0xC008000000000000, 0xBFF0000000000000
    .quad 0x3FF0000000000000, 0x4008000000000000, 0xC000000000000000, 0x0000000000000000
    .quad 0x4000000000000000, 0xC008000000000000, 0xBFF0000000000000, 0x3FF0000000000000
    .quad 0x4008000000000000, 0xC000000000000000, 0x0000000000000000, 0x4000000000000000
    .quad 0xC008000000000000, 0xBFF0000000000000, 0x3FF0000000000000, 0x4008000000000000
    .quad 0xC000000000000000, 0x0000000000000000, 0x4000000000000000, 0xC008000000000000
    .quad 0xBFF0000000000000, 0x3FF0000000000000, 0x4008000000000000, 0xC000000000000000
    .quad 0x0000000000000000, 0x4000000000000000, 0xC008000000000000, 0xBFF0000000000000
    .quad 0xBFF0000000000000, 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000
    .quad 0xC008000000000000, 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000
    .quad 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000, 0xC008000000000000
    .quad 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000, 0x4000000000000000
    .quad 0xC000000000000000, 0x3FF0000000000000, 0xC008000000000000, 0x0000000000000000
    .quad 0x4008000000000000, 0xBFF0000000000000, 0x4000000000000000, 0xC000000000000000
    .quad 0x3FF0000000000000, 0xC008000000000000, 0x0000000000000000, 0x4008000000000000
    .quad 0xBFF0000000000000, 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000
    .quad 0xC008000000000000, 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000
    .quad 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000, 0xC008000000000000
    .quad 0x0000000000000000, 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000
    .quad 0x4000000000000000, 0xBFF0000000000000, 0x4008000000000000, 0x0000000000000000
    .quad 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000
    .quad 0xBFF0000000000000, 0x4008000000000000, 0x0000000000000000, 0xC008000000000000
    .quad 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000, 0xBFF0000000000000
    .quad 0x4008000000000000, 0x0000000000000000, 0xC008000000000000, 0x3FF0000000000000
    .quad 0xC000000000000000, 0x4000000000000000, 0xBFF0000000000000, 0x4008000000000000
    .quad 0x0000000000000000, 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000
    .quad 0x4000000000000000, 0xBFF0000000000000, 0x4008000000000000, 0x0000000000000000
    .quad 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000
    .quad 0x3FF0000000000000, 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000
    .quad 0x0000000000000000, 0xC000000000000000, 0x4008000000000000, 0x3FF0000000000000
    .quad 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000, 0x0000000000000000
    .quad 0xC000000000000000, 0x4008000000000000, 0x3FF0000000000000, 0xBFF0000000000000
    .quad 0xC008000000000000, 0x4000000000000000, 0x0000000000000000, 0xC000000000000000
    .quad 0x4008000000000000, 0x3FF0000000000000, 0xBFF0000000000000, 0xC008000000000000
    .quad 0x4000000000000000, 0x0000000000000000, 0xC000000000000000, 0x4008000000000000
    .quad 0x3FF0000000000000, 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000
    .quad 0x0000000000000000, 0xC000000000000000, 0x4008000000000000, 0x3FF0000000000000
    .quad 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000, 0x0000000000000000
    .quad 0x4000000000000000, 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000
    .quad 0xC000000000000000, 0xC008000000000000, 0x4008000000000000, 0x4000000000000000
    .quad 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000, 0xC000000000000000
    .quad 0xC008000000000000, 0x4008000000000000, 0x4000000000000000, 0x3FF0000000000000
    .quad 0x0000000000000000, 0xBFF0000000000000, 0xC000000000000000, 0xC008000000000000
    .quad 0x4008000000000000, 0x4000000000000000, 0x3FF0000000000000, 0x0000000000000000
    .quad 0xBFF0000000000000, 0xC000000000000000, 0xC008000000000000, 0x4008000000000000
    .quad 0x4000000000000000, 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000
    .quad 0xC000000000000000, 0xC008000000000000, 0x4008000000000000, 0x4000000000000000
    .quad 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000, 0xC000000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0xC008000000000000, 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000
    .quad 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000, 0xC008000000000000
    .quad 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000
    .quad 0x4000000000000000, 0x4008000000000000, 0xC008000000000000, 0xC000000000000000
    .quad 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000, 0x4000000000000000
    .quad 0x4008000000000000, 0xC008000000000000, 0xC000000000000000, 0xBFF0000000000000
    .quad 0x0000000000000000, 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000
    .quad 0xC008000000000000, 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000
    .quad 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000, 0xC008000000000000
    .quad 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000
    .quad 0xC000000000000000, 0x0000000000000000, 0x4000000000000000, 0xC008000000000000
    .quad 0xBFF0000000000000, 0x3FF0000000000000, 0x4008000000000000, 0xC000000000000000
    .quad 0x0000000000000000, 0x4000000000000000, 0xC008000000000000, 0xBFF0000000000000
    .quad 0x3FF0000000000000, 0x4008000000000000, 0xC000000000000000, 0x0000000000000000
    .quad 0x4000000000000000, 0xC008000000000000, 0xBFF0000000000000, 0x3FF0000000000000
    .quad 0x4008000000000000, 0xC000000000000000, 0x0000000000000000, 0x4000000000000000
    .quad 0xC008000000000000, 0xBFF0000000000000, 0x3FF0000000000000, 0x4008000000000000
    .quad 0xC000000000000000, 0x0000000000000000, 0x4000000000000000, 0xC008000000000000
    .quad 0xBFF0000000000000, 0x3FF0000000000000, 0x4008000000000000, 0xC000000000000000
    .quad 0x0000000000000000, 0x4000000000000000, 0xC008000000000000, 0xBFF0000000000000
    .quad 0xBFF0000000000000, 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000
    .quad 0xC008000000000000, 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000
    .quad 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000, 0xC008000000000000
    .quad 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000, 0x4000000000000000
    .quad 0xC000000000000000, 0x3FF0000000000000, 0xC008000000000000, 0x0000000000000000
    .quad 0x4008000000000000, 0xBFF0000000000000, 0x4000000000000000, 0xC000000000000000
    .quad 0x3FF0000000000000, 0xC008000000000000, 0x0000000000000000, 0x4008000000000000
    .quad 0xBFF0000000000000, 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000
    .quad 0xC008000000000000, 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000
    .quad 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000, 0xC008000000000000
    .quad 0x0000000000000000, 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000
    .quad 0x4000000000000000, 0xBFF0000000000000, 0x4008000000000000, 0x0000000000000000
    .quad 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000
    .quad 0xBFF0000000000000, 0x4008000000000000, 0x0000000000000000, 0xC008000000000000
    .quad 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000, 0xBFF0000000000000
    .quad 0x4008000000000000, 0x0000000000000000, 0xC008000000000000, 0x3FF0000000000000
    .quad 0xC000000000000000, 0x4000000000000000, 0xBFF0000000000000, 0x4008000000000000
    .quad 0x0000000000000000, 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000
    .quad 0x4000000000000000, 0xBFF0000000000000, 0x4008000000000000, 0x0000000000000000
    .quad 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000
    .quad 0x3FF0000000000000, 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000
    .quad 0x0000000000000000, 0xC000000000000000, 0x4008000000000000, 0x3FF0000000000000
    .quad 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000, 0x0000000000000000
    .quad 0xC000000000000000, 0x4008000000000000, 0x3FF0000000000000, 0xBFF0000000000000
    .quad 0xC008000000000000, 0x4000000000000000, 0x0000000000000000, 0xC000000000000000
    .quad 0x4008000000000000, 0x3FF0000000000000, 0xBFF0000000000000, 0xC008000000000000
    .quad 0x4000000000000000, 0x0000000000000000, 0xC000000000000000, 0x4008000000000000
    .quad 0x3FF0000000000000, 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000
    .quad 0x0000000000000000, 0xC000000000000000, 0x4008000000000000, 0x3FF0000000000000
    .quad 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000, 0x0000000000000000
    .quad 0x4000000000000000, 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000
    .quad 0xC000000000000000, 0xC008000000000000, 0x4008000000000000, 0x4000000000000000
    .quad 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000, 0xC000000000000000
    .quad 0xC008000000000000, 0x4008000000000000, 0x4000000000000000, 0x3FF0000000000000
    .quad 0x0000000000000000, 0xBFF0000000000000, 0xC000000000000000, 0xC008000000000000
    .quad 0x4008000000000000, 0x4000000000000000, 0x3FF0000000000000, 0x0000000000000000
    .quad 0xBFF0000000000000, 0xC000000000000000, 0xC008000000000000, 0x4008000000000000
    .quad 0x4000000000000000, 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000
    .quad 0xC000000000000000, 0xC008000000000000, 0x4008000000000000, 0x4000000000000000
    .quad 0x3FF0000000000000, 0x0000000000000000, 0xBFF0000000000000, 0xC000000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0x4008000000000000, 0x4008000000000000, 0x4008000000000000, 0x4008000000000000
    .quad 0xC008000000000000, 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000
    .quad 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000, 0xC008000000000000
    .quad 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000
    .quad 0x4000000000000000, 0x4008000000000000, 0xC008000000000000, 0xC000000000000000
    .quad 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000, 0x4000000000000000
    .quad 0x4008000000000000, 0xC008000000000000, 0xC000000000000000, 0xBFF0000000000000
    .quad 0x0000000000000000, 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000
    .quad 0xC008000000000000, 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000
    .quad 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000, 0xC008000000000000
    .quad 0xC000000000000000, 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000
    .quad 0xC000000000000000, 0x0000000000000000, 0x4000000000000000, 0xC008000000000000
    .quad 0xBFF0000000000000, 0x3FF0000000000000, 0x4008000000000000, 0xC000000000000000
    .quad 0x0000000000000000, 0x4000000000000000, 0xC008000000000000, 0xBFF0000000000000
    .quad 0x3FF0000000000000, 0x4008000000000000, 0xC000000000000000, 0x0000000000000000
    .quad 0x4000000000000000, 0xC008000000000000, 0xBFF0000000000000, 0x3FF0000000000000
    .quad 0x4008000000000000, 0xC000000000000000, 0x0000000000000000, 0x4000000000000000
    .quad 0xC008000000000000, 0xBFF0000000000000, 0x3FF0000000000000, 0x4008000000000000
    .quad 0xC000000000000000, 0x0000000000000000, 0x4000000000000000, 0xC008000000000000
    .quad 0xBFF0000000000000, 0x3FF0000000000000, 0x4008000000000000, 0xC000000000000000
    .quad 0x0000000000000000, 0x4000000000000000, 0xC008000000000000, 0xBFF0000000000000
    .quad 0xBFF0000000000000, 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000
    .quad 0xC008000000000000, 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000
    .quad 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000, 0xC008000000000000
    .quad 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000, 0x4000000000000000
    .quad 0xC000000000000000, 0x3FF0000000000000, 0xC008000000000000, 0x0000000000000000
    .quad 0x4008000000000000, 0xBFF0000000000000, 0x4000000000000000, 0xC000000000000000
    .quad 0x3FF0000000000000, 0xC008000000000000, 0x0000000000000000, 0x4008000000000000
    .quad 0xBFF0000000000000, 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000
    .quad 0xC008000000000000, 0x0000000000000000, 0x4008000000000000, 0xBFF0000000000000
    .quad 0x4000000000000000, 0xC000000000000000, 0x3FF0000000000000, 0xC008000000000000
    .quad 0x0000000000000000, 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000
    .quad 0x4000000000000000, 0xBFF0000000000000, 0x4008000000000000, 0x0000000000000000
    .quad 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000
    .quad 0xBFF0000000000000, 0x4008000000000000, 0x0000000000000000, 0xC008000000000000
    .quad 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000, 0xBFF0000000000000
    .quad 0x4008000000000000, 0x0000000000000000, 0xC008000000000000, 0x3FF0000000000000
    .quad 0xC000000000000000, 0x4000000000000000, 0xBFF0000000000000, 0x4008000000000000
    .quad 0x0000000000000000, 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000
    .quad 0x4000000000000000, 0xBFF0000000000000, 0x4008000000000000, 0x0000000000000000
    .quad 0xC008000000000000, 0x3FF0000000000000, 0xC000000000000000, 0x4000000000000000
    .quad 0x3FF0000000000000, 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000
    .quad 0x0000000000000000, 0xC000000000000000, 0x4008000000000000, 0x3FF0000000000000
    .quad 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000, 0x0000000000000000
    .quad 0xC000000000000000, 0x4008000000000000, 0x3FF0000000000000, 0xBFF0000000000000
    .quad 0xC008000000000000, 0x4000000000000000, 0x0000000000000000, 0xC000000000000000
    .quad 0x4008000000000000, 0x3FF0000000000000, 0xBFF0000000000000, 0xC008000000000000
    .quad 0x4000000000000000, 0x0000000000000000, 0xC000000000000000, 0x4008000000000000
    .quad 0x3FF0000000000000, 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000
    .quad 0x0000000000000000, 0xC000000000000000, 0x4008000000000000, 0x3FF0000000000000
    .quad 0xBFF0000000000000, 0xC008000000000000, 0x4000000000000000, 0x0000000000000000
.Ld17M:
    .quad 0x3FF0000000000000, 0x0000000000000000, 0x3FF0000000000000, 0x4000000000000000
    .quad 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000, 0x4000000000000000
    .quad 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000, 0x4000000000000000
    .quad 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000, 0x4000000000000000
    .quad 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000, 0x4000000000000000
    .quad 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000, 0x4000000000000000
    .quad 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000, 0x4000000000000000
    .quad 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000, 0x4000000000000000
    .quad 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000, 0x4000000000000000
    .quad 0xBFF0000000000000, 0x0000000000000000, 0x3FF0000000000000, 0x4000000000000000
    .quad 0x0000000000000000, 0x4010000000000000, 0x0000000000000000, 0x4000000000000000
    .quad 0x4010000000000000, 0xC000000000000000, 0x0000000000000000, 0x4000000000000000
    .quad 0x4010000000000000, 0xC000000000000000, 0x0000000000000000, 0x4000000000000000
    .quad 0x4010000000000000, 0xC000000000000000, 0x0000000000000000, 0x4000000000000000
    .quad 0x4010000000000000, 0xC000000000000000, 0x0000000000000000, 0x4000000000000000
    .quad 0x4010000000000000, 0xC000000000000000, 0x0000000000000000, 0x4000000000000000
    .quad 0x4010000000000000, 0xC000000000000000, 0x0000000000000000, 0x4000000000000000
    .quad 0x4010000000000000, 0xC000000000000000, 0x0000000000000000, 0x4000000000000000
    .quad 0x4010000000000000, 0xC000000000000000, 0x0000000000000000, 0x4000000000000000
    .quad 0x4010000000000000, 0xC000000000000000, 0x0000000000000000, 0x4000000000000000
    .quad 0x3FF0000000000000, 0x0000000000000000, 0x4031000000000000, 0x4000000000000000
    .quad 0x4008000000000000, 0x4020000000000000, 0xC008000000000000, 0x4000000000000000
    .quad 0x4008000000000000, 0x4020000000000000, 0xC008000000000000, 0x4000000000000000
    .quad 0x4008000000000000, 0x4020000000000000, 0xC008000000000000, 0x4000000000000000
    .quad 0x4008000000000000, 0x4020000000000000, 0xC008000000000000, 0x4000000000000000
    .quad 0x4008000000000000, 0x4020000000000000, 0xC008000000000000, 0x4000000000000000
    .quad 0x4008000000000000, 0x4020000000000000, 0xC008000000000000, 0x4000000000000000
    .quad 0x4008000000000000, 0x4020000000000000, 0xC008000000000000, 0x4000000000000000
    .quad 0x4008000000000000, 0x4020000000000000, 0xC008000000000000, 0x4000000000000000
    .quad 0x4008000000000000, 0x4020000000000000, 0xC008000000000000, 0x4000000000000000
    .quad 0x4000000000000000, 0x4000000000000000, 0x4000000000000000, 0x4018000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x4010000000000000, 0x4010000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x4010000000000000, 0x4010000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x4010000000000000, 0x4010000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x4010000000000000, 0x4010000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x4010000000000000, 0x4010000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x4010000000000000, 0x4010000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x4010000000000000, 0x4010000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x4010000000000000, 0x4010000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x4010000000000000, 0x4010000000000000
    .quad 0xBFF0000000000000, 0x4010000000000000, 0x4008000000000000, 0x0000000000000000
    .quad 0x4024000000000000, 0x0000000000000000, 0x0000000000000000, 0x4010000000000000
    .quad 0x4010000000000000, 0x0000000000000000, 0x0000000000000000, 0x4010000000000000
    .quad 0x4010000000000000, 0x0000000000000000, 0x0000000000000000, 0x4010000000000000
    .quad 0x4010000000000000, 0x0000000000000000, 0x0000000000000000, 0x4010000000000000
    .quad 0x4010000000000000, 0x0000000000000000, 0x0000000000000000, 0x4010000000000000
    .quad 0x4010000000000000, 0x0000000000000000, 0x0000000000000000, 0x4010000000000000
    .quad 0x4010000000000000, 0x0000000000000000, 0x0000000000000000, 0x4010000000000000
    .quad 0x4010000000000000, 0x0000000000000000, 0x0000000000000000, 0x4010000000000000
    .quad 0x4010000000000000, 0x0000000000000000, 0x0000000000000000, 0x4010000000000000
    .quad 0x0000000000000000, 0xC000000000000000, 0x4020000000000000, 0x0000000000000000
    .quad 0x0000000000000000, 0x4036000000000000, 0x0000000000000000, 0x4000000000000000
    .quad 0x4020000000000000, 0x4000000000000000, 0x0000000000000000, 0x4000000000000000
    .quad 0x4020000000000000, 0x4000000000000000, 0x0000000000000000, 0x4000000000000000
    .quad 0x4020000000000000, 0x4000000000000000, 0x0000000000000000, 0x4000000000000000
    .quad 0x4020000000000000, 0x4000000000000000, 0x0000000000000000, 0x4000000000000000
    .quad 0x4020000000000000, 0x4000000000000000, 0x0000000000000000, 0x4000000000000000
    .quad 0x4020000000000000, 0x4000000000000000, 0x0000000000000000, 0x4000000000000000
    .quad 0x4020000000000000, 0x4000000000000000, 0x0000000000000000, 0x4000000000000000
    .quad 0x4020000000000000, 0x4000000000000000, 0x0000000000000000, 0x4000000000000000
    .quad 0x3FF0000000000000, 0x0000000000000000, 0xC008000000000000, 0x4010000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x4020000000000000, 0x4000000000000000
    .quad 0xC000000000000000, 0x4000000000000000, 0x4018000000000000, 0x4000000000000000
    .quad 0xC000000000000000, 0x4000000000000000, 0x4018000000000000, 0x4000000000000000
    .quad 0xC000000000000000, 0x4000000000000000, 0x4018000000000000, 0x4000000000000000
    .quad 0xC000000000000000, 0x4000000000000000, 0x4018000000000000, 0x4000000000000000
    .quad 0xC000000000000000, 0x4000000000000000, 0x4018000000000000, 0x4000000000000000
    .quad 0xC000000000000000, 0x4000000000000000, 0x4018000000000000, 0x4000000000000000
    .quad 0xC000000000000000, 0x4000000000000000, 0x4018000000000000, 0x4000000000000000
    .quad 0xC000000000000000, 0x4000000000000000, 0x4018000000000000, 0x4000000000000000
    .quad 0x4000000000000000, 0x4000000000000000, 0x4000000000000000, 0x4010000000000000
    .quad 0x4010000000000000, 0x4000000000000000, 0x4000000000000000, 0x402E000000000000
    .quad 0x0000000000000000, 0xBFF0000000000000, 0x4018000000000000, 0x4022000000000000
    .quad 0x0000000000000000, 0xBFF0000000000000, 0x4018000000000000, 0x4022000000000000
    .quad 0x0000000000000000, 0xBFF0000000000000, 0x4018000000000000, 0x4022000000000000
    .quad 0x0000000000000000, 0xBFF0000000000000, 0x4018000000000000, 0x4022000000000000
    .quad 0x0000000000000000, 0xBFF0000000000000, 0x4018000000000000, 0x4022000000000000
    .quad 0x0000000000000000, 0xBFF0000000000000, 0x4018000000000000, 0x4022000000000000
    .quad 0x0000000000000000, 0xBFF0000000000000, 0x4018000000000000, 0x4022000000000000
    .quad 0x0000000000000000, 0xBFF0000000000000, 0x4018000000000000, 0x4022000000000000
    .quad 0xBFF0000000000000, 0x4010000000000000, 0x4008000000000000, 0x0000000000000000
    .quad 0x4010000000000000, 0x4020000000000000, 0xC000000000000000, 0x0000000000000000
    .quad 0x403C000000000000, 0x0000000000000000, 0x0000000000000000, 0x4020000000000000
    .quad 0x4020000000000000, 0x0000000000000000, 0x0000000000000000, 0x4020000000000000
    .quad 0x4020000000000000, 0x0000000000000000, 0x0000000000000000, 0x4020000000000000
    .quad 0x4020000000000000, 0x0000000000000000, 0x0000000000000000, 0x4020000000000000
    .quad 0x4020000000000000, 0x0000000000000000, 0x0000000000000000, 0x4020000000000000
    .quad 0x4020000000000000, 0x0000000000000000, 0x0000000000000000, 0x4020000000000000
    .quad 0x4020000000000000, 0x0000000000000000, 0x0000000000000000, 0x4020000000000000
    .quad 0x4020000000000000, 0x0000000000000000, 0x0000000000000000, 0x4020000000000000
    .quad 0x0000000000000000, 0xC000000000000000, 0x4020000000000000, 0x0000000000000000
    .quad 0x0000000000000000, 0x4000000000000000, 0x4000000000000000, 0xBFF0000000000000
    .quad 0x0000000000000000, 0x402A000000000000, 0x0000000000000000, 0xC008000000000000
    .quad 0x4000000000000000, 0x4026000000000000, 0x0000000000000000, 0xC008000000000000
    .quad 0x4000000000000000, 0x4026000000000000, 0x0000000000000000, 0xC008000000000000
    .quad 0x4000000000000000, 0x4026000000000000, 0x0000000000000000, 0xC008000000000000
    .quad 0x4000000000000000, 0x4026000000000000, 0x0000000000000000, 0xC008000000000000
    .quad 0x4000000000000000, 0x4026000000000000, 0x0000000000000000, 0xC008000000000000
    .quad 0x4000000000000000, 0x4026000000000000, 0x0000000000000000, 0xC008000000000000
    .quad 0x4000000000000000, 0x4026000000000000, 0x0000000000000000, 0xC008000000000000
    .quad 0x3FF0000000000000, 0x0000000000000000, 0xC008000000000000, 0x4010000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x4018000000000000, 0x4018000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x4031000000000000, 0x4000000000000000
    .quad 0xC008000000000000, 0x4010000000000000, 0x4026000000000000, 0x4000000000000000
    .quad 0xC008000000000000, 0x4010000000000000, 0x4026000000000000, 0x4000000000000000
    .quad 0xC008000000000000, 0x4010000000000000, 0x4026000000000000, 0x4000000000000000
    .quad 0xC008000000000000, 0x4010000000000000, 0x4026000000000000, 0x4000000000000000
    .quad 0xC008000000000000, 0x4010000000000000, 0x4026000000000000, 0x4000000000000000
    .quad 0xC008000000000000, 0x4010000000000000, 0x4026000000000000, 0x4000000000000000
    .quad 0xC008000000000000, 0x4010000000000000, 0x4026000000000000, 0x4000000000000000
    .quad 0x4000000000000000, 0x4000000000000000, 0x4000000000000000, 0x4010000000000000
    .quad 0x4010000000000000, 0x4000000000000000, 0x4000000000000000, 0x4022000000000000
    .quad 0x4020000000000000, 0xC008000000000000, 0x4000000000000000, 0x4040800000000000
    .quad 0x0000000000000000, 0xBFF0000000000000, 0x4024000000000000, 0x402A000000000000
    .quad 0x0000000000000000, 0xBFF0000000000000, 0x4024000000000000, 0x402A000000000000
    .quad 0x0000000000000000, 0xBFF0000000000000, 0x4024000000000000, 0x402A000000000000
    .quad 0x0000000000000000, 0xBFF0000000000000, 0x4024000000000000, 0x402A000000000000
    .quad 0x0000000000000000, 0xBFF0000000000000, 0x4024000000000000, 0x402A000000000000
    .quad 0x0000000000000000, 0xBFF0000000000000, 0x4024000000000000, 0x402A000000000000
    .quad 0x0000000000000000, 0xBFF0000000000000, 0x4024000000000000, 0x402A000000000000
    .quad 0xBFF0000000000000, 0x4010000000000000, 0x4008000000000000, 0x0000000000000000
    .quad 0x4010000000000000, 0x4020000000000000, 0xC000000000000000, 0x0000000000000000
    .quad 0x4020000000000000, 0x4000000000000000, 0xC008000000000000, 0x0000000000000000
    .quad 0x4033000000000000, 0x0000000000000000, 0xC014000000000000, 0x4000000000000000
    .quad 0x4031000000000000, 0x0000000000000000, 0xC014000000000000, 0x4000000000000000
    .quad 0x4031000000000000, 0x0000000000000000, 0xC014000000000000, 0x4000000000000000
    .quad 0x4031000000000000, 0x0000000000000000, 0xC014000000000000, 0x4000000000000000
    .quad 0x4031000000000000, 0x0000000000000000, 0xC014000000000000, 0x4000000000000000
    .quad 0x4031000000000000, 0x0000000000000000, 0xC014000000000000, 0x4000000000000000
    .quad 0x4031000000000000, 0x0000000000000000, 0xC014000000000000, 0x4000000000000000
    .quad 0x0000000000000000, 0xC000000000000000, 0x4020000000000000, 0x0000000000000000
    .quad 0x0000000000000000, 0x4000000000000000, 0x4000000000000000, 0xBFF0000000000000
    .quad 0x0000000000000000, 0x4026000000000000, 0x4010000000000000, 0xBFF0000000000000
    .quad 0x0000000000000000, 0x4036000000000000, 0x0000000000000000, 0xC010000000000000
    .quad 0x4010000000000000, 0x4030000000000000, 0x0000000000000000, 0xC010000000000000
    .quad 0x4010000000000000, 0x4030000000000000, 0x0000000000000000, 0xC010000000000000
    .quad 0x4010000000000000, 0x4030000000000000, 0x0000000000000000, 0xC010000000000000
    .quad 0x4010000000000000, 0x4030000000000000, 0x0000000000000000, 0xC010000000000000
    .quad 0x4010000000000000, 0x4030000000000000, 0x0000000000000000, 0xC010000000000000
    .quad 0x4010000000000000, 0x4030000000000000, 0x0000000000000000, 0xC010000000000000
    .quad 0x3FF0000000000000, 0x0000000000000000, 0xC008000000000000, 0x4010000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x4018000000000000, 0x4018000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x4026000000000000, 0x4024000000000000
    .quad 0xC014000000000000, 0x0000000000000000, 0x4041800000000000, 0x4000000000000000
    .quad 0xC008000000000000, 0x4020000000000000, 0x402E000000000000, 0x4000000000000000
    .quad 0xC008000000000000, 0x4020000000000000, 0x402E000000000000, 0x4000000000000000
    .quad 0xC008000000000000, 0x4020000000000000, 0x402E000000000000, 0x4000000000000000
    .quad 0xC008000000000000, 0x4020000000000000, 0x402E000000000000, 0x4000000000000000
    .quad 0xC008000000000000, 0x4020000000000000, 0x402E000000000000, 0x4000000000000000
    .quad 0xC008000000000000, 0x4020000000000000, 0x402E000000000000, 0x4000000000000000
    .quad 0x4000000000000000, 0x4000000000000000, 0x4000000000000000, 0x4010000000000000
    .quad 0x4010000000000000, 0x4000000000000000, 0x4000000000000000, 0x4022000000000000
    .quad 0x4020000000000000, 0xC008000000000000, 0x4000000000000000, 0x402A000000000000
    .quad 0x4000000000000000, 0xC010000000000000, 0x4000000000000000, 0x4038000000000000
    .quad 0x0000000000000000, 0xC018000000000000, 0x4010000000000000, 0x4036000000000000
    .quad 0x0000000000000000, 0xC018000000000000, 0x4010000000000000, 0x4036000000000000
    .quad 0x0000000000000000, 0xC018000000000000, 0x4010000000000000, 0x4036000000000000
    .quad 0x0000000000000000, 0xC018000000000000, 0x4010000000000000, 0x4036000000000000
    .quad 0x0000000000000000, 0xC018000000000000, 0x4010000000000000, 0x4036000000000000
    .quad 0x0000000000000000, 0xC018000000000000, 0x4010000000000000, 0x4036000000000000
    .quad 0xBFF0000000000000, 0x4010000000000000, 0x4008000000000000, 0x0000000000000000
    .quad 0x4010000000000000, 0x4020000000000000, 0xC000000000000000, 0x0000000000000000
    .quad 0x4020000000000000, 0x4000000000000000, 0xC008000000000000, 0x0000000000000000
    .quad 0x4031000000000000, 0x4010000000000000, 0xC008000000000000, 0x0000000000000000
    .quad 0x403C000000000000, 0x0000000000000000, 0xC018000000000000, 0x4010000000000000
    .quad 0x4036000000000000, 0x0000000000000000, 0xC018000000000000, 0x4010000000000000
    .quad 0x4036000000000000, 0x0000000000000000, 0xC018000000000000, 0x4010000000000000
    .quad 0x4036000000000000, 0x0000000000000000, 0xC018000000000000, 0x4010000000000000
    .quad 0x4036000000000000, 0x0000000000000000, 0xC018000000000000, 0x4010000000000000
    .quad 0x4036000000000000, 0x0000000000000000, 0xC018000000000000, 0x4010000000000000
    .quad 0x0000000000000000, 0xC000000000000000, 0x4020000000000000, 0x0000000000000000
    .quad 0x0000000000000000, 0x4000000000000000, 0x4000000000000000, 0xBFF0000000000000
    .quad 0x0000000000000000, 0x4026000000000000, 0x4010000000000000, 0xBFF0000000000000
    .quad 0x0000000000000000, 0x4030000000000000, 0x4020000000000000, 0xC018000000000000
    .quad 0x0000000000000000, 0x4044000000000000, 0x0000000000000000, 0xC010000000000000
    .quad 0x4020000000000000, 0x4034000000000000, 0x0000000000000000, 0xC010000000000000
    .quad 0x4020000000000000, 0x4034000000000000, 0x0000000000000000, 0xC010000000000000
    .quad 0x4020000000000000, 0x4034000000000000, 0x0000000000000000, 0xC010000000000000
    .quad 0x4020000000000000, 0x4034000000000000, 0x0000000000000000, 0xC010000000000000
    .quad 0x4020000000000000, 0x4034000000000000, 0x0000000000000000, 0xC010000000000000
    .quad 0x3FF0000000000000, 0x0000000000000000, 0xC008000000000000, 0x4010000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x4018000000000000, 0x4018000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x4026000000000000, 0x4024000000000000
    .quad 0xC014000000000000, 0x0000000000000000, 0x402E000000000000, 0x4010000000000000
    .quad 0xC018000000000000, 0x0000000000000000, 0x403A000000000000, 0x4000000000000000
    .quad 0xC020000000000000, 0x4000000000000000, 0x4038000000000000, 0x4000000000000000
    .quad 0xC020000000000000, 0x4000000000000000, 0x4038000000000000, 0x4000000000000000
    .quad 0xC020000000000000, 0x4000000000000000, 0x4038000000000000, 0x4000000000000000
    .quad 0xC020000000000000, 0x4000000000000000, 0x4038000000000000, 0x4000000000000000
    .quad 0xC020000000000000, 0x4000000000000000, 0x4038000000000000, 0x4000000000000000
    .quad 0x4000000000000000, 0x4000000000000000, 0x4000000000000000, 0x4010000000000000
    .quad 0x4010000000000000, 0x4000000000000000, 0x4000000000000000, 0x4022000000000000
    .quad 0x4020000000000000, 0xC008000000000000, 0x4000000000000000, 0x402A000000000000
    .quad 0x4000000000000000, 0xC010000000000000, 0x4000000000000000, 0x4036000000000000
    .quad 0x4010000000000000, 0xC010000000000000, 0x4000000000000000, 0x4040800000000000
    .quad 0x0000000000000000, 0xC01C000000000000, 0x4018000000000000, 0x403B000000000000
    .quad 0x0000000000000000, 0xC01C000000000000, 0x4018000000000000, 0x403B000000000000
    .quad 0x0000000000000000, 0xC01C000000000000, 0x4018000000000000, 0x403B000000000000
    .quad 0x0000000000000000, 0xC01C000000000000, 0x4018000000000000, 0x403B000000000000
    .quad 0x0000000000000000, 0xC01C000000000000, 0x4018000000000000, 0x403B000000000000
    .quad 0xBFF0000000000000, 0x4010000000000000, 0x4008000000000000, 0x0000000000000000
    .quad 0x4010000000000000, 0x4020000000000000, 0xC000000000000000, 0x0000000000000000
    .quad 0x4020000000000000, 0x4000000000000000, 0xC008000000000000, 0x0000000000000000
    .quad 0x4031000000000000, 0x4010000000000000, 0xC008000000000000, 0x0000000000000000
    .quad 0x4036000000000000, 0x4020000000000000, 0xC020000000000000, 0x0000000000000000
    .quad 0x4047000000000000, 0x0000000000000000, 0xC018000000000000, 0x4020000000000000
    .quad 0x403A000000000000, 0x0000000000000000, 0xC018000000000000, 0x4020000000000000
    .quad 0x403A000000000000, 0x0000000000000000, 0xC018000000000000, 0x4020000000000000
    .quad 0x403A000000000000, 0x0000000000000000, 0xC018000000000000, 0x4020000000000000
    .quad 0x403A000000000000, 0x0000000000000000, 0xC018000000000000, 0x4020000000000000
    .quad 0x0000000000000000, 0xC000000000000000, 0x4020000000000000, 0x0000000000000000
    .quad 0x0000000000000000, 0x4000000000000000, 0x4000000000000000, 0xBFF0000000000000
    .quad 0x0000000000000000, 0x4026000000000000, 0x4010000000000000, 0xBFF0000000000000
    .quad 0x0000000000000000, 0x4030000000000000, 0x4020000000000000, 0xC018000000000000
    .quad 0x0000000000000000, 0x4034000000000000, 0x4000000000000000, 0xC01C000000000000
    .quad 0x0000000000000000, 0x403F000000000000, 0x0000000000000000, 0xC022000000000000
    .quad 0x4000000000000000, 0x403D000000000000, 0x0000000000000000, 0xC022000000000000
    .quad 0x4000000000000000, 0x403D000000000000, 0x0000000000000000, 0xC022000000000000
    .quad 0x4000000000000000, 0x403D000000000000, 0x0000000000000000, 0xC022000000000000
    .quad 0x4000000000000000, 0x403D000000000000, 0x0000000000000000, 0xC022000000000000
    .quad 0x3FF0000000000000, 0x0000000000000000, 0xC008000000000000, 0x4010000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x4018000000000000, 0x4018000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x4026000000000000, 0x4024000000000000
    .quad 0xC014000000000000, 0x0000000000000000, 0x402E000000000000, 0x4010000000000000
    .quad 0xC018000000000000, 0x0000000000000000, 0x4038000000000000, 0x4018000000000000
    .quad 0xC018000000000000, 0x0000000000000000, 0x4041800000000000, 0x4000000000000000
    .quad 0xC022000000000000, 0x4010000000000000, 0x403D000000000000, 0x4000000000000000
    .quad 0xC022000000000000, 0x4010000000000000, 0x403D000000000000, 0x4000000000000000
    .quad 0xC022000000000000, 0x4010000000000000, 0x403D000000000000, 0x4000000000000000
    .quad 0xC022000000000000, 0x4010000000000000, 0x403D000000000000, 0x4000000000000000
    .quad 0x4000000000000000, 0x4000000000000000, 0x4000000000000000, 0x4010000000000000
    .quad 0x4010000000000000, 0x4000000000000000, 0x4000000000000000, 0x4022000000000000
    .quad 0x4020000000000000, 0xC008000000000000, 0x4000000000000000, 0x402A000000000000
    .quad 0x4000000000000000, 0xC010000000000000, 0x4000000000000000, 0x4036000000000000
    .quad 0x4010000000000000, 0xC010000000000000, 0x4000000000000000, 0x403B000000000000
    .quad 0x4020000000000000, 0xC022000000000000, 0x4000000000000000, 0x4049800000000000
    .quad 0x0000000000000000, 0xC01C000000000000, 0x4024000000000000, 0x403F000000000000
    .quad 0x0000000000000000, 0xC01C000000000000, 0x4024000000000000, 0x403F000000000000
    .quad 0x0000000000000000, 0xC01C000000000000, 0x4024000000000000, 0x403F000000000000
    .quad 0x0000000000000000, 0xC01C000000000000, 0x4024000000000000, 0x403F000000000000
    .quad 0xBFF0000000000000, 0x4010000000000000, 0x4008000000000000, 0x0000000000000000
    .quad 0x4010000000000000, 0x4020000000000000, 0xC000000000000000, 0x0000000000000000
    .quad 0x4020000000000000, 0x4000000000000000, 0xC008000000000000, 0x0000000000000000
    .quad 0x4031000000000000, 0x4010000000000000, 0xC008000000000000, 0x0000000000000000
    .quad 0x4036000000000000, 0x4020000000000000, 0xC020000000000000, 0x0000000000000000
    .quad 0x403A000000000000, 0x4000000000000000, 0xC022000000000000, 0x0000000000000000
    .quad 0x4042800000000000, 0x0000000000000000, 0xC026000000000000, 0x4000000000000000
    .quad 0x4041800000000000, 0x0000000000000000, 0xC026000000000000, 0x4000000000000000
    .quad 0x4041800000000000, 0x0000000000000000, 0xC026000000000000, 0x4000000000000000
    .quad 0x4041800000000000, 0x0000000000000000, 0xC026000000000000, 0x4000000000000000
    .quad 0x0000000000000000, 0xC000000000000000, 0x4020000000000000, 0x0000000000000000
    .quad 0x0000000000000000, 0x4000000000000000, 0x4000000000000000, 0xBFF0000000000000
    .quad 0x0000000000000000, 0x4026000000000000, 0x4010000000000000, 0xBFF0000000000000
    .quad 0x0000000000000000, 0x4030000000000000, 0x4020000000000000, 0xC018000000000000
    .quad 0x0000000000000000, 0x4034000000000000, 0x4000000000000000, 0xC01C000000000000
    .quad 0x0000000000000000, 0x403D000000000000, 0x4010000000000000, 0xC01C000000000000
    .quad 0x0000000000000000, 0x4044000000000000, 0x0000000000000000, 0xC024000000000000
    .quad 0x4010000000000000, 0x4041000000000000, 0x0000000000000000, 0xC024000000000000
    .quad 0x4010000000000000, 0x4041000000000000, 0x0000000000000000, 0xC024000000000000
    .quad 0x4010000000000000, 0x4041000000000000, 0x0000000000000000, 0xC024000000000000
    .quad 0x3FF0000000000000, 0x0000000000000000, 0xC008000000000000, 0x4010000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x4018000000000000, 0x4018000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x4026000000000000, 0x4024000000000000
    .quad 0xC014000000000000, 0x0000000000000000, 0x402E000000000000, 0x4010000000000000
    .quad 0xC018000000000000, 0x0000000000000000, 0x4038000000000000, 0x4018000000000000
    .quad 0xC018000000000000, 0x0000000000000000, 0x403D000000000000, 0x4024000000000000
    .quad 0xC026000000000000, 0x0000000000000000, 0x404A800000000000, 0x4000000000000000
    .quad 0xC022000000000000, 0x4020000000000000, 0x4040800000000000, 0x4000000000000000
    .quad 0xC022000000000000, 0x4020000000000000, 0x4040800000000000, 0x4000000000000000
    .quad 0xC022000000000000, 0x4020000000000000, 0x4040800000000000, 0x4000000000000000
    .quad 0x4000000000000000, 0x4000000000000000, 0x4000000000000000, 0x4010000000000000
    .quad 0x4010000000000000, 0x4000000000000000, 0x4000000000000000, 0x4022000000000000
    .quad 0x4020000000000000, 0xC008000000000000, 0x4000000000000000, 0x402A000000000000
    .quad 0x4000000000000000, 0xC010000000000000, 0x4000000000000000, 0x4036000000000000
    .quad 0x4010000000000000, 0xC010000000000000, 0x4000000000000000, 0x403B000000000000
    .quad 0x4020000000000000, 0xC022000000000000, 0x4000000000000000, 0x403F000000000000
    .quad 0x4000000000000000, 0xC024000000000000, 0x4000000000000000, 0x4045000000000000
    .quad 0x0000000000000000, 0xC028000000000000, 0x4010000000000000, 0x4044000000000000
    .quad 0x0000000000000000, 0xC028000000000000, 0x4010000000000000, 0x4044000000000000
    .quad 0x0000000000000000, 0xC028000000000000, 0x4010000000000000, 0x4044000000000000
    .quad 0xBFF0000000000000, 0x4010000000000000, 0x4008000000000000, 0x0000000000000000
    .quad 0x4010000000000000, 0x4020000000000000, 0xC000000000000000, 0x0000000000000000
    .quad 0x4020000000000000, 0x4000000000000000, 0xC008000000000000, 0x0000000000000000
    .quad 0x4031000000000000, 0x4010000000000000, 0xC008000000000000, 0x0000000000000000
    .quad 0x4036000000000000, 0x4020000000000000, 0xC020000000000000, 0x0000000000000000
    .quad 0x403A000000000000, 0x4000000000000000, 0xC022000000000000, 0x0000000000000000
    .quad 0x4041800000000000, 0x4010000000000000, 0xC022000000000000, 0x0000000000000000
    .quad 0x4047000000000000, 0x0000000000000000, 0xC028000000000000, 0x4010000000000000
    .quad 0x4044000000000000, 0x0000000000000000, 0xC028000000000000, 0x4010000000000000
    .quad 0x4044000000000000, 0x0000000000000000, 0xC028000000000000, 0x4010000000000000
    .quad 0x0000000000000000, 0xC000000000000000, 0x4020000000000000, 0x0000000000000000
    .quad 0x0000000000000000, 0x4000000000000000, 0x4000000000000000, 0xBFF0000000000000
    .quad 0x0000000000000000, 0x4026000000000000, 0x4010000000000000, 0xBFF0000000000000
    .quad 0x0000000000000000, 0x4030000000000000, 0x4020000000000000, 0xC018000000000000
    .quad 0x0000000000000000, 0x4034000000000000, 0x4000000000000000, 0xC01C000000000000
    .quad 0x0000000000000000, 0x403D000000000000, 0x4010000000000000, 0xC01C000000000000
    .quad 0x0000000000000000, 0x4041000000000000, 0x4020000000000000, 0xC028000000000000
    .quad 0x0000000000000000, 0x404D000000000000, 0x0000000000000000, 0xC024000000000000
    .quad 0x4020000000000000, 0x4043000000000000, 0x0000000000000000, 0xC024000000000000
    .quad 0x4020000000000000, 0x4043000000000000, 0x0000000000000000, 0xC024000000000000
    .quad 0x3FF0000000000000, 0x0000000000000000, 0xC008000000000000, 0x4010000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x4018000000000000, 0x4018000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x4026000000000000, 0x4024000000000000
    .quad 0xC014000000000000, 0x0000000000000000, 0x402E000000000000, 0x4010000000000000
    .quad 0xC018000000000000, 0x0000000000000000, 0x4038000000000000, 0x4018000000000000
    .quad 0xC018000000000000, 0x0000000000000000, 0x403D000000000000, 0x4024000000000000
    .quad 0xC026000000000000, 0x0000000000000000, 0x4040800000000000, 0x4010000000000000
    .quad 0xC028000000000000, 0x0000000000000000, 0x4046000000000000, 0x4000000000000000
    .quad 0xC02C000000000000, 0x4000000000000000, 0x4045000000000000, 0x4000000000000000
    .quad 0xC02C000000000000, 0x4000000000000000, 0x4045000000000000, 0x4000000000000000
    .quad 0x4000000000000000, 0x4000000000000000, 0x4000000000000000, 0x4010000000000000
    .quad 0x4010000000000000, 0x4000000000000000, 0x4000000000000000, 0x4022000000000000
    .quad 0x4020000000000000, 0xC008000000000000, 0x4000000000000000, 0x402A000000000000
    .quad 0x4000000000000000, 0xC010000000000000, 0x4000000000000000, 0x4036000000000000
    .quad 0x4010000000000000, 0xC010000000000000, 0x4000000000000000, 0x403B000000000000
    .quad 0x4020000000000000, 0xC022000000000000, 0x4000000000000000, 0x403F000000000000
    .quad 0x4000000000000000, 0xC024000000000000, 0x4000000000000000, 0x4044000000000000
    .quad 0x4010000000000000, 0xC024000000000000, 0x4000000000000000, 0x4049800000000000
    .quad 0x0000000000000000, 0xC02A000000000000, 0x4018000000000000, 0x4046800000000000
    .quad 0x0000000000000000, 0xC02A000000000000, 0x4018000000000000, 0x4046800000000000
    .quad 0xBFF0000000000000, 0x4010000000000000, 0x4008000000000000, 0x0000000000000000
    .quad 0x4010000000000000, 0x4020000000000000, 0xC000000000000000, 0x0000000000000000
    .quad 0x4020000000000000, 0x4000000000000000, 0xC008000000000000, 0x0000000000000000
    .quad 0x4031000000000000, 0x4010000000000000, 0xC008000000000000, 0x0000000000000000
    .quad 0x4036000000000000, 0x4020000000000000, 0xC020000000000000, 0x0000000000000000
    .quad 0x403A000000000000, 0x4000000000000000, 0xC022000000000000, 0x0000000000000000
    .quad 0x4041800000000000, 0x4010000000000000, 0xC022000000000000, 0x0000000000000000
    .quad 0x4044000000000000, 0x4020000000000000, 0xC02C000000000000, 0x0000000000000000
    .quad 0x4050000000000000, 0x0000000000000000, 0xC028000000000000, 0x4020000000000000
    .quad 0x4046000000000000, 0x0000000000000000, 0xC028000000000000, 0x4020000000000000
    .quad 0x0000000000000000, 0xC000000000000000, 0x4020000000000000, 0x0000000000000000
    .quad 0x0000000000000000, 0x4000000000000000, 0x4000000000000000, 0xBFF0000000000000
    .quad 0x0000000000000000, 0x4026000000000000, 0x4010000000000000, 0xBFF0000000000000
    .quad 0x0000000000000000, 0x4030000000000000, 0x4020000000000000, 0xC018000000000000
    .quad 0x0000000000000000, 0x4034000000000000, 0x4000000000000000, 0xC01C000000000000
    .quad 0x0000000000000000, 0x403D000000000000, 0x4010000000000000, 0xC01C000000000000
    .quad 0x0000000000000000, 0x4041000000000000, 0x4020000000000000, 0xC028000000000000
    .quad 0x0000000000000000, 0x4043000000000000, 0x4000000000000000, 0xC02A000000000000
    .quad 0x0000000000000000, 0x4048800000000000, 0x0000000000000000, 0xC02E000000000000
    .quad 0x4000000000000000, 0x4047800000000000, 0x0000000000000000, 0xC02E000000000000
    .quad 0x3FF0000000000000, 0x0000000000000000, 0xC008000000000000, 0x4010000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x4018000000000000, 0x4018000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x4026000000000000, 0x4024000000000000
    .quad 0xC014000000000000, 0x0000000000000000, 0x402E000000000000, 0x4010000000000000
    .quad 0xC018000000000000, 0x0000000000000000, 0x4038000000000000, 0x4018000000000000
    .quad 0xC018000000000000, 0x0000000000000000, 0x403D000000000000, 0x4024000000000000
    .quad 0xC026000000000000, 0x0000000000000000, 0x4040800000000000, 0x4010000000000000
    .quad 0xC028000000000000, 0x0000000000000000, 0x4045000000000000, 0x4018000000000000
    .quad 0xC028000000000000, 0x0000000000000000, 0x404A800000000000, 0x4000000000000000
    .quad 0xC02E000000000000, 0x4010000000000000, 0x4047800000000000, 0x4000000000000000
    .quad 0x4000000000000000, 0x4000000000000000, 0x4000000000000000, 0x4010000000000000
    .quad 0x4010000000000000, 0x4000000000000000, 0x4000000000000000, 0x4022000000000000
    .quad 0x4020000000000000, 0xC008000000000000, 0x4000000000000000, 0x402A000000000000
    .quad 0x4000000000000000, 0xC010000000000000, 0x4000000000000000, 0x4036000000000000
    .quad 0x4010000000000000, 0xC010000000000000, 0x4000000000000000, 0x403B000000000000
    .quad 0x4020000000000000, 0xC022000000000000, 0x4000000000000000, 0x403F000000000000
    .quad 0x4000000000000000, 0xC024000000000000, 0x4000000000000000, 0x4044000000000000
    .quad 0x4010000000000000, 0xC024000000000000, 0x4000000000000000, 0x4046800000000000
    .quad 0x4020000000000000, 0xC02E000000000000, 0x4000000000000000, 0x4051400000000000
    .quad 0x0000000000000000, 0xC02A000000000000, 0x4024000000000000, 0x4048800000000000
    .quad 0xBFF0000000000000, 0x4010000000000000, 0x4008000000000000, 0x0000000000000000
    .quad 0x4010000000000000, 0x4020000000000000, 0xC000000000000000, 0x0000000000000000
    .quad 0x4020000000000000, 0x4000000000000000, 0xC008000000000000, 0x0000000000000000
    .quad 0x4031000000000000, 0x4010000000000000, 0xC008000000000000, 0x0000000000000000
    .quad 0x4036000000000000, 0x4020000000000000, 0xC020000000000000, 0x0000000000000000
    .quad 0x403A000000000000, 0x4000000000000000, 0xC022000000000000, 0x0000000000000000
    .quad 0x4041800000000000, 0x4010000000000000, 0xC022000000000000, 0x0000000000000000
    .quad 0x4044000000000000, 0x4020000000000000, 0xC02C000000000000, 0x0000000000000000
    .quad 0x4046000000000000, 0x4000000000000000, 0xC02E000000000000, 0x0000000000000000
    .quad 0x404B800000000000, 0x0000000000000000, 0xC031000000000000, 0x4000000000000000
    .quad 0x0000000000000000, 0xC000000000000000, 0x4020000000000000, 0x0000000000000000
    .quad 0x0000000000000000, 0x4000000000000000, 0x4000000000000000, 0xBFF0000000000000
    .quad 0x0000000000000000, 0x4026000000000000, 0x4010000000000000, 0xBFF0000000000000
    .quad 0x0000000000000000, 0x4030000000000000, 0x4020000000000000, 0xC018000000000000
    .quad 0x0000000000000000, 0x4034000000000000, 0x4000000000000000, 0xC01C000000000000
    .quad 0x0000000000000000, 0x403D000000000000, 0x4010000000000000, 0xC01C000000000000
    .quad 0x0000000000000000, 0x4041000000000000, 0x4020000000000000, 0xC028000000000000
    .quad 0x0000000000000000, 0x4043000000000000, 0x4000000000000000, 0xC02A000000000000
    .quad 0x0000000000000000, 0x4047800000000000, 0x4010000000000000, 0xC02A000000000000
    .quad 0x0000000000000000, 0x404D000000000000, 0x0000000000000000, 0xC030000000000000
    .quad 0x3FF0000000000000, 0x0000000000000000, 0xC008000000000000, 0x4010000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x4018000000000000, 0x4018000000000000
    .quad 0x0000000000000000, 0x0000000000000000, 0x4026000000000000, 0x4024000000000000
    .quad 0xC014000000000000, 0x0000000000000000, 0x402E000000000000, 0x4010000000000000
    .quad 0xC018000000000000, 0x0000000000000000, 0x4038000000000000, 0x4018000000000000
    .quad 0xC018000000000000, 0x0000000000000000, 0x403D000000000000, 0x4024000000000000
    .quad 0xC026000000000000, 0x0000000000000000, 0x4040800000000000, 0x4010000000000000
    .quad 0xC028000000000000, 0x0000000000000000, 0x4045000000000000, 0x4018000000000000
    .quad 0xC028000000000000, 0x0000000000000000, 0x4047800000000000, 0x4024000000000000
    .quad 0xC031000000000000, 0x0000000000000000, 0x4051C00000000000, 0x4000000000000000
    .quad 0x4000000000000000, 0x4000000000000000, 0x4000000000000000, 0x4010000000000000
    .quad 0x4010000000000000, 0x4000000000000000, 0x4000000000000000, 0x4022000000000000
    .quad 0x4020000000000000, 0xC008000000000000, 0x4000000000000000, 0x402A000000000000
    .quad 0x4000000000000000, 0xC010000000000000, 0x4000000000000000, 0x4036000000000000
    .quad 0x4010000000000000, 0xC010000000000000, 0x4000000000000000, 0x403B000000000000
    .quad 0x4020000000000000, 0xC022000000000000, 0x4000000000000000, 0x403F000000000000
    .quad 0x4000000000000000, 0xC024000000000000, 0x4000000000000000, 0x4044000000000000
    .quad 0x4010000000000000, 0xC024000000000000, 0x4000000000000000, 0x4046800000000000
    .quad 0x4020000000000000, 0xC02E000000000000, 0x4000000000000000, 0x4048800000000000
    .quad 0x4000000000000000, 0xC030000000000000, 0x4000000000000000, 0x404E000000000000
.Ll17: .asciz "eig_sym_gen 40 (blocked Cholesky, exact R)"
.Ld18A:
    .quad 0x3FF0000000000000, 0x0000000000000000, 0x0000000000000000, 0x4000000000000000
.Ld18M:
    .quad 0x7FF0000000000000, 0x0000000000000000, 0x0000000000000000, 0x3FF0000000000000
.Ll18: .asciz "eig_sym_gen Inf on M diagonal"
.Ld19A:
    .quad 0x3FF0000000000000, 0x0000000000000000, 0x0000000000000000, 0x7FF8000000000000
.Ld19M:
    .quad 0x3FF0000000000000, 0x0000000000000000, 0x0000000000000000, 0x3FF0000000000000
.Ll19: .asciz "eig_sym_gen NaN in K"
.Ld20A:
    .quad 0x7FF8000000000000, 0x0000000000000000, 0x0000000000000000, 0x3FF0000000000000
.Ld20M:
    .quad 0x3FF0000000000000, 0x4000000000000000, 0x4000000000000000, 0x3FF0000000000000
.Ll20: .asciz "eig_sym_gen NaN in K, M indefinite"
.Ld21A:
    .quad 0x7E37E43C8800759C, 0x0000000000000000, 0x0000000000000000, 0x7E37E43C8800759C
.Ld21M:
    .quad 0x01A56E1FC2F8F359, 0x0000000000000000, 0x0000000000000000, 0x01A56E1FC2F8F359
.Ll21: .asciz "eig_sym_gen reduction overflows"
    .p2align 3
    .globl sea_sites
sea_sites:
    .quad .Lsite_file
    .quad 1
.Lsite_file:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 6
    .ascii "la.sea"

    .section .note.GNU-stack,"",@progbits
