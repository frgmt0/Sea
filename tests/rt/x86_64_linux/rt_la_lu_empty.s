# sea/tests/rt/x86_64_linux/rt_la_lu_empty.s -- the empty shortcuts of the factorization entries (DESIGN.md 2.13.2 "Empty operands", 2.13.5, 2.13.6; L-ik, L-io): lu and chol of a 0 x 0 matrix give handles of order 0 (lu's norm 0.0 and no zero pivot), rcond of an order-0 Lu is +Inf; lu_solve, chol_solve and solve with n = 0 give the empty result of B's rank and shape (0 x m matrices and the empty vector); with n = 3 and a B of no column all three give a 3 x 0 result (after the checks: solve still factors A, by the Cholesky path for an SPD A and by LU otherwise). Every result has count 1; every object is released (heap check).
.include "limits.inc"
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
    .p2align 3
    .data
vA0:    .quad 0                     # 0 x 0
vA3:    .quad 0                     # [4, 1, 1; 1, 3, 1; 1, 1, 2]: SPD
vN3:    .quad 0                     # [0, 1, 0; 2, 0, 0; 0, 0, 4]: not symmetric
vF0:    .quad 0
vC0:    .quad 0
vF3:    .quad 0
vC3:    .quad 0
    .text

# shape -- print ` <rank> <rows> <cols> rc=<count>` of the array %rdi,
# then release it. Callee-saved used: %rbx. Frame 56.
    .p2align 4
shape:
    PROLOGUE
    movq %rdi, %rbx
    TXT " "
    movzbl SEA_ARR_RANK(%rbx), %edi
    call putdec
    TXT " "
    movq SEA_ARR_ROWS(%rbx), %rdi
    call putdec
    TXT " "
    movq SEA_ARR_COLS(%rbx), %rdi
    call putdec
    TXT " rc="
    movq SEA_OBJ_RC(%rbx), %rdi
    call putdec
    TXT "\n"
    REL %rbx
    EPILOGUE

# fromdata -- a new matrix (count 1) of rank %rdi, %rsi x %rdx, holding
# the doubles at %rcx. Callee-saved used: %rbx, %r12. Frame 56.
    .p2align 4
fromdata:
    PROLOGUE
    movq %rcx, %rbx
    call newmat
    movq %rax, %r12
    movq SEA_ARR_DATA(%r12), %rdi
    movq %rbx, %rsi
    movq SEA_ARR_ROWS(%r12), %rdx
    imulq SEA_ARR_COLS(%r12), %rdx
    call copyq
    movq %r12, %rax
    EPILOGUE

# solve2 -- %rax = entry(%rsi, B) for B a new empty array of rank %rdx,
# %rcx x %r8 (released after the call); %rdi = the entry.
#   Callee-saved used: %rbx = entry, %r12 = left, %r13 = B. Frame 56.
    .p2align 4
solve2:
    PROLOGUE
    movq %rdi, %rbx
    movq %rsi, %r12
    movq %rdx, %rdi
    movq %rcx, %rsi
    movq %r8, %rdx
    call newmat
    movq %rax, %r13
    movq %r12, %rdi
    movq %r13, %rsi
    xorl %edx, %edx
    call *%rbx
    movq %rax, %r12
    REL %r13
    movq %r12, %rax
    EPILOGUE

.macro CASE label, entry, left, rank, rows, cols
    leaq \label(%rip), %rdi
    call putcstr
    TXT ":"
    leaq \entry(%rip), %rdi
    movq \left(%rip), %rsi
    movl $\rank, %edx
    movl $\rows, %ecx
    movl $\cols, %r8d
    call solve2
    movq %rax, %rdi
    call shape
.endm

    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    PROLOGUE
    movl $2, %edi                   # the matrices
    xorl %esi, %esi
    xorl %edx, %edx
    call newmat
    movq %rax, vA0(%rip)
    movl $2, %edi
    movl $3, %esi
    movl $3, %edx
    leaq .Lspd(%rip), %rcx
    call fromdata
    movq %rax, vA3(%rip)
    movl $2, %edi
    movl $3, %esi
    movl $3, %edx
    leaq .Lnsym(%rip), %rcx
    call fromdata
    movq %rax, vN3(%rip)

    # lu and chol of order 0: handles of order 0, rcond +Inf.
    movq vA0(%rip), %rdi
    xorl %esi, %esi
    call sea_lu
    movq %rax, vF0(%rip)
    movq %rax, %rbx
    TXT "lu(0x0): n="
    movq 16(%rbx), %rdi
    call putdec
    TXT " norm="
    movq 24(%rbx), %rdi
    call putf
    TXT " pivot="
    movq 32(%rbx), %rdi
    call putdec
    TXT " rc="
    movq SEA_OBJ_RC(%rbx), %rdi
    call putdec
    TXT "\nrcond(lu(0x0)): "
    movq %rbx, %rdi
    xorl %esi, %esi
    call sea_rcond
    movq %xmm0, %rdi
    call putf
    TXT "\n"
    movq vA0(%rip), %rdi
    xorl %esi, %esi
    call sea_chol
    movq %rax, vC0(%rip)
    movq %rax, %rbx
    TXT "chol(0x0): n="
    movq 16(%rbx), %rdi
    call putdec
    TXT " rc="
    movq SEA_OBJ_RC(%rbx), %rdi
    call putdec
    TXT "\n"
    movq vA3(%rip), %rdi
    xorl %esi, %esi
    call sea_lu
    movq %rax, vF3(%rip)
    movq vA3(%rip), %rdi
    xorl %esi, %esi
    call sea_chol
    movq %rax, vC3(%rip)

    CASE .Lc0, sea_lu_solve, vF0, 2, 0, 3
    CASE .Lc1, sea_lu_solve, vF0, 1, 0, 1
    CASE .Lc2, sea_chol_solve, vC0, 2, 0, 2
    CASE .Lc3, sea_chol_solve, vC0, 1, 0, 1
    CASE .Lc4, sea_solve, vA0, 2, 0, 4
    CASE .Lc5, sea_solve, vA0, 1, 0, 1
    CASE .Lc6, sea_lu_solve, vF3, 2, 3, 0
    CASE .Lc7, sea_chol_solve, vC3, 2, 3, 0
    CASE .Lc8, sea_solve, vA3, 2, 3, 0
    CASE .Lc9, sea_solve, vN3, 2, 3, 0

    movq vC3(%rip), %rax
    REL %rax
    movq vF3(%rip), %rax
    REL %rax
    movq vC0(%rip), %rax
    REL %rax
    movq vF0(%rip), %rax
    REL %rax
    movq vN3(%rip), %rax
    REL %rax
    movq vA3(%rip), %rax
    REL %rax
    movq vA0(%rip), %rax
    REL %rax
    EPILOGUE
    .size sea_main, . - sea_main

.equ P0, 0x0000000000000000
.equ P1, 0x3FF0000000000000
.equ P2, 0x4000000000000000
.equ P3, 0x4008000000000000
.equ P4, 0x4010000000000000
    .section .rodata
    .p2align 3
.Lspd:  .quad P4, P1, P1,  P1, P3, P1,  P1, P1, P2
.Lnsym: .quad P0, P2, P0,  P1, P0, P0,  P0, P0, P4
.Lc0: .asciz "lu_solve(order 0, 0x3)"
.Lc1: .asciz "lu_solve(order 0, vector 0)"
.Lc2: .asciz "chol_solve(order 0, 0x2)"
.Lc3: .asciz "chol_solve(order 0, vector 0)"
.Lc4: .asciz "solve(0x0, 0x4)"
.Lc5: .asciz "solve(0x0, vector 0)"
.Lc6: .asciz "lu_solve(order 3, 3x0)"
.Lc7: .asciz "chol_solve(order 3, 3x0)"
.Lc8: .asciz "solve(SPD 3x3, 3x0)"
.Lc9: .asciz "solve(non-symmetric 3x3, 3x0)"
    .section .data.rel.ro,"aw",@progbits
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
