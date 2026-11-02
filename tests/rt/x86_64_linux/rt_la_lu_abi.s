# sea/tests/rt/x86_64_linux/rt_la_lu_abi.s -- the ABI of sea_lu, sea_chol, sea_lu_solve, sea_chol_solve, sea_solve, sea_rcond and the private sea_la_potrf and sea_la_issym (DESIGN.md 2.13.5 "ABI", "Stack"; 2.13.8 "Runtime"): each case is called with %rbx %rbp %r12-%r15 holding known patterns and the 128 KiB below %rsp guard-filled; afterwards those registers, %rsp, MXCSR's control bits and the direction flag must be unchanged and the call, its callees included (sea_alloc, sea_arr_new_u, bsk_kern_gemm_sub with its packing), must have written at most SEA_STACK_MARGIN bytes below %rsp (DESIGN.md 4.6). Cases at order 70 (three panels, every Baysick update) and order 3, both solve paths and the failed Cholesky attempt. Each case prints `<label>: ok`; a failure prints its error bits and exits 1. Run under the baseline variant (pass 1) and the best usable one (pass 2); every object is released (heap check).
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

# ---- the ABI check ----------------------------------------------------
.equ PAT_RBX, 0x5EA0000000000303
.equ PAT_RBP, 0x5EA0000000000505
.equ PAT_R12, 0x5EA0000000000C0C
.equ PAT_R13, 0x5EA0000000000D0D
.equ PAT_R14, 0x5EA0000000000E0E
.equ PAT_R15, 0x5EA0000000000F0F
.equ GUARD_BYTES, 131072            # guard-filled below the call's return slot
.equ GUARD_WORD, 0xC0FFEE5EA5EA5EA5 # the guard pattern
.equ MXCSR_CTL, 0xFFC0              # MXCSR's control bits (the flags may change)
.equ RFLAGS_DF, 0x400               # the direction flag
.if GUARD_BYTES <= SEA_STACK_MARGIN
    .error "the guard must reach below SEA_STACK_MARGIN"
.endif

    .data
    .p2align 3
.Lres:   .quad 0                    # the result of the last call (%rax)
.Lsp:    .quad 0                    # %rsp at the call site
.Lmx0:   .long 0                    # MXCSR before the call
.Lmx1:   .long 0                    # MXCSR after the call
.Ldepth: .quad 0                    # bytes the call wrote below its return slot
    .bss
    .p2align 4
bufR:   .zero BUFBYTES
bufA:   .zero BUFBYTES              # R'R (SPD)
bufL:   .zero BUFBYTES
bufU:   .zero BUFBYTES
bufP:   .zero BUFBYTES              # P L U (not symmetric)
bufM:   .zero BUFBYTES              # sea_la_potrf's matrix
bufW:   .zero (MAXN * SEA_LA_NB * 8)
ipiv:   .zero (MAXN * 4)
    .p2align 3
objs:   .zero (8 * 16)              # the operands, by OBJ_* index
    .text
.equ OBJ_S70, 0                     # R'R, 70 x 70
.equ OBJ_P70, 1                     # P L U, 70 x 70
.equ OBJ_S3, 2                      # R'R, 3 x 3
.equ OBJ_B, 3                       # 70 x 40
.equ OBJ_V, 4                       # a vector of 70
.equ OBJ_F70, 5                     # lu(P70)
.equ OBJ_C70, 6                     # chol(S70)
.equ OBJ_B3, 7                      # 3 x 2
.equ OBJ_F3, 8                      # lu(S3)
.equ OBJ_IND, 9                     # [1, 2; 2, 1]
.equ OBJ_B2, 10                     # 2 x 1
.equ OBJ_COUNT, 11

# probe -- call a routine under the ABI check.
#   Inputs  : %rdi = the routine, %rsi %rdx %rcx %r8 = its four arguments
#   Outputs : %rax = 0, or the sum of: 1 %rsp changed, 2 MXCSR's control
#             bits changed, 4 one of %rbx %rbp %r12-%r15 changed, 8 the
#             direction flag set, 16 the call wrote more than
#             SEA_STACK_MARGIN bytes below its return slot; .Lres = %rax
#             of the call, .Ldepth = the bytes written below the return slot
#   Clobbers: the caller-saved registers
#   Callee-saved used: all of them hold the test patterns during the call
#   Frame   : 8 (%rbp) + 40 (callee-saved) + 24
    .p2align 4
probe:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $24, %rsp                  # 0(%rsp) = arg 3, 8(%rsp) = arg 4; %rsp = 0 (mod 16)
    movq %rdi, %r11                 # the routine
    movq %rsi, %r12
    movq %rdx, %r13
    movq %rcx, 0(%rsp)
    movq %r8, 8(%rsp)
    leaq -8-GUARD_BYTES(%rsp), %rdi # the guard: GUARD_BYTES ending at the return slot
    movl $GUARD_BYTES/8, %ecx
    movabsq $GUARD_WORD, %rax
    cld
    rep stosq
    stmxcsr .Lmx0(%rip)
    movq %r12, %rdi                 # the arguments
    movq %r13, %rsi
    movq 0(%rsp), %rdx
    movq 8(%rsp), %rcx
    movq %rsp, .Lsp(%rip)
    movabsq $PAT_RBX, %rbx
    movabsq $PAT_RBP, %rbp
    movabsq $PAT_R12, %r12
    movabsq $PAT_R13, %r13
    movabsq $PAT_R14, %r14
    movabsq $PAT_R15, %r15
    call *%r11
    movq %rax, .Lres(%rip)
    pushfq
    popq %r8                        # RFLAGS after the call
    stmxcsr .Lmx1(%rip)
    xorl %eax, %eax                 # the error bits
    movabsq $PAT_RBX, %rcx
    cmpq %rcx, %rbx
    jne 1f
    movabsq $PAT_RBP, %rcx
    cmpq %rcx, %rbp
    jne 1f
    movabsq $PAT_R12, %rcx
    cmpq %rcx, %r12
    jne 1f
    movabsq $PAT_R13, %rcx
    cmpq %rcx, %r13
    jne 1f
    movabsq $PAT_R14, %rcx
    cmpq %rcx, %r14
    jne 1f
    movabsq $PAT_R15, %rcx
    cmpq %rcx, %r15
    je 2f
1:  orl $4, %eax
2:  cmpq .Lsp(%rip), %rsp
    je 3f
    orl $1, %eax
    movq .Lsp(%rip), %rsp
3:  movl .Lmx0(%rip), %ecx
    xorl .Lmx1(%rip), %ecx
    testl $MXCSR_CTL, %ecx
    jz 4f
    orl $2, %eax
4:  testq $RFLAGS_DF, %r8
    jz 5f
    orl $8, %eax
    cld
5:  movq .Lsp(%rip), %rdx           # the depth: the lowest guard word changed
    leaq -8-GUARD_BYTES(%rdx), %rdi
    leaq -8(%rdx), %rsi
    movabsq $GUARD_WORD, %rcx
6:  cmpq %rsi, %rdi
    jae 7f
    cmpq (%rdi), %rcx
    jne 7f
    addq $8, %rdi
    jmp 6b
7:  subq %rdi, %rsi
    movq %rsi, .Ldepth(%rip)
    cmpq $SEA_STACK_MARGIN, %rsi
    jbe 8f
    orl $16, %eax
8:  addq $24, %rsp                 # %rsp is the call site's again
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

# mkobj -- objs[%rdi] = a new array of rank %rsi, %rdx x %rcx holding the
# doubles at %r8 (count 1). Callee-saved used: %rbx, %r12. Frame 56.
    .p2align 4
mkobj:
    PROLOGUE
    movq %rdi, %rbx
    movq %r8, %r12
    movq %rsi, %rdi
    movq %rdx, %rsi
    movq %rcx, %rdx
    call newmat
    leaq objs(%rip), %rcx
    movq %rax, (%rcx,%rbx,8)
    movq SEA_ARR_DATA(%rax), %rdi
    movq %r12, %rsi
    movq SEA_ARR_ROWS(%rax), %rdx
    imulq SEA_ARR_COLS(%rax), %rdx
    call copyq
    EPILOGUE

# setup -- the operands of the cases.
    .p2align 4
setup:
    PROLOGUE
    leaq bufR(%rip), %rdi
    movl $70, %esi
    call genR
    leaq bufR(%rip), %rdi
    leaq bufA(%rip), %rsi
    movl $70, %edx
    call rtr
    movl $OBJ_S70, %edi
    movl $2, %esi
    movl $70, %edx
    movl $70, %ecx
    leaq bufA(%rip), %r8
    call mkobj
    leaq bufL(%rip), %rdi
    leaq bufU(%rip), %rsi
    leaq ipiv(%rip), %rdx
    leaq bufP(%rip), %rcx
    movl $70, %r8d
    call genPLU
    movl $OBJ_P70, %edi
    movl $2, %esi
    movl $70, %edx
    movl $70, %ecx
    leaq bufP(%rip), %r8
    call mkobj
    movl $OBJ_B, %edi               # B: the first 2800 doubles of R'R
    movl $2, %esi
    movl $70, %edx
    movl $40, %ecx
    leaq bufA(%rip), %r8
    call mkobj
    movl $OBJ_V, %edi
    movl $1, %esi
    movl $70, %edx
    movl $1, %ecx
    leaq bufA(%rip), %r8
    call mkobj
    leaq bufR(%rip), %rdi           # R'R of order 3
    movl $3, %esi
    call genR
    leaq bufR(%rip), %rdi
    leaq bufA(%rip), %rsi
    movl $3, %edx
    call rtr
    movl $OBJ_S3, %edi
    movl $2, %esi
    movl $3, %edx
    movl $3, %ecx
    leaq bufA(%rip), %r8
    call mkobj
    movl $OBJ_B3, %edi
    movl $2, %esi
    movl $3, %edx
    movl $2, %ecx
    leaq bufA(%rip), %r8
    call mkobj
    movl $OBJ_IND, %edi
    movl $2, %esi
    movl $2, %edx
    movl $2, %ecx
    leaq .Lind(%rip), %r8
    call mkobj
    movl $OBJ_B2, %edi
    movl $2, %esi
    movl $2, %edx
    movl $1, %ecx
    leaq .Lind(%rip), %r8
    call mkobj
    leaq objs(%rip), %rbx
    movq (OBJ_P70 * 8)(%rbx), %rdi
    xorl %esi, %esi
    call sea_lu
    movq %rax, (OBJ_F70 * 8)(%rbx)
    movq (OBJ_S70 * 8)(%rbx), %rdi
    xorl %esi, %esi
    call sea_chol
    movq %rax, (OBJ_C70 * 8)(%rbx)
    movq (OBJ_S3 * 8)(%rbx), %rdi
    xorl %esi, %esi
    call sea_lu
    movq %rax, (OBJ_F3 * 8)(%rbx)
    EPILOGUE

# A case record (8-byte words): label, routine, result kind (0 none to
# release: %rax not an object, 1 an object to release), arg 1, arg 2
# (each an OBJ_* index, or -1 for 0 / a literal as stated below), the
# kind of args 3 and 4 (0: site 0 as arg 2 or 3; 2: sea_la_potrf's
# (bufM, 70, 70, bufW) with bufM = R'R of order 70; 3: sea_la_issym's
# (bufA, 70, 70)).
.equ AC_SIZE, 48

# runcases -- every case under the current variant: `<label>: ok`, or
# `<label>: BAD <bits>` and exit 1.
#   Callee-saved used: %rbx = the record, %r14 = the error bits, %r15 =
#             objs. Frame 56.
    .p2align 4
runcases:
    PROLOGUE
    leaq acases(%rip), %rbx
    leaq objs(%rip), %r15
1:  cmpq $0, (%rbx)
    je 9f
    movq 40(%rbx), %rax
    cmpq $2, %rax
    je 3f
    cmpq $3, %rax
    je 4f
    # An entry: (obj, site) or (obj, obj, site).
    movq 8(%rbx), %rdi
    movq 24(%rbx), %rax
    movq (%r15,%rax,8), %rsi
    xorl %edx, %edx
    xorl %ecx, %ecx
    xorl %r8d, %r8d
    movq 32(%rbx), %rax
    testq %rax, %rax
    js 2f
    movq (%r15,%rax,8), %rdx
2:  call probe
    jmp 5f
3:  leaq bufR(%rip), %rdi           # sea_la_potrf on a fresh R'R of order 70
    movl $70, %esi
    call genR
    leaq bufR(%rip), %rdi
    leaq bufM(%rip), %rsi
    movl $70, %edx
    call rtr
    leaq sea_la_potrf(%rip), %rdi
    leaq bufM(%rip), %rsi
    movl $70, %edx
    movl $70, %ecx
    leaq bufW(%rip), %r8
    call probe
    jmp 5f
4:  leaq bufR(%rip), %rdi           # sea_la_issym on a symmetric R'R of order 70
    movl $70, %esi
    call genR
    leaq bufR(%rip), %rdi
    leaq bufM(%rip), %rsi
    movl $70, %edx
    call rtr
    leaq sea_la_issym(%rip), %rdi
    leaq bufM(%rip), %rsi
    movl $70, %edx
    movl $70, %ecx
    xorl %r8d, %r8d
    call probe
5:  movq %rax, %r14
    movq (%rbx), %rdi
    call putcstr
    testq %r14, %r14
    jnz 6f
    TXT ": ok\n"
    cmpq $1, 16(%rbx)
    jne 8f
    movq .Lres(%rip), %rax
    REL %rax
8:  addq $AC_SIZE, %rbx
    jmp 1b
6:  TXT ": BAD "
    movq %r14, %rdi
    call putdec
    TXT "\n"
    call sea_out_flush
    movl $1, %edi
    call _exit@PLT
9:  EPILOGUE

    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    PROLOGUE
    call setup
    call nvariants
    leaq -1(%rax), %rdi
    call usevariant
    TXT "pass 1\n"
    call runcases
    xorl %edi, %edi
    call usevariant
    TXT "pass 2\n"
    call runcases
    leaq objs(%rip), %rbx           # release the operands
    xorl %r12d, %r12d
1:  movq (%rbx,%r12,8), %rax
    REL %rax
    incq %r12
    cmpq $OBJ_COUNT, %r12
    jb 1b
    EPILOGUE
    .size sea_main, . - sea_main

    .section .rodata
    .p2align 3
.Lind:  .quad 0x3FF0000000000000, 0x4000000000000000, 0x4000000000000000, 0x3FF0000000000000
    .section .data.rel.ro,"aw",@progbits
    .p2align 3
acases:
    .quad .Ln0, sea_lu, 1, OBJ_P70, -1, 0
    .quad .Ln1, sea_lu, 1, OBJ_S3, -1, 0
    .quad .Ln2, sea_chol, 1, OBJ_S70, -1, 0
    .quad .Ln3, sea_chol, 1, OBJ_S3, -1, 0
    .quad .Ln4, sea_lu_solve, 1, OBJ_F70, OBJ_B, 0
    .quad .Ln5, sea_lu_solve, 1, OBJ_F70, OBJ_V, 0
    .quad .Ln6, sea_lu_solve, 1, OBJ_F3, OBJ_B3, 0
    .quad .Ln7, sea_chol_solve, 1, OBJ_C70, OBJ_B, 0
    .quad .Ln8, sea_chol_solve, 1, OBJ_C70, OBJ_V, 0
    .quad .Ln9, sea_solve, 1, OBJ_S70, OBJ_B, 0
    .quad .Ln10, sea_solve, 1, OBJ_P70, OBJ_B, 0
    .quad .Ln11, sea_solve, 1, OBJ_IND, OBJ_B2, 0
    .quad .Ln12, sea_solve, 1, OBJ_S3, OBJ_B3, 0
    .quad .Ln13, sea_rcond, 0, OBJ_F70, -1, 0
    .quad .Ln14, sea_rcond, 0, OBJ_F3, -1, 0
    .quad .Ln15, sea_la_potrf, 0, -1, -1, 2
    .quad .Ln16, sea_la_issym, 0, -1, -1, 3
    .quad 0
.Ln0:  .asciz "lu 70"
.Ln1:  .asciz "lu 3"
.Ln2:  .asciz "chol 70"
.Ln3:  .asciz "chol 3"
.Ln4:  .asciz "lu_solve 70 x 40"
.Ln5:  .asciz "lu_solve 70 vector"
.Ln6:  .asciz "lu_solve 3 x 2"
.Ln7:  .asciz "chol_solve 70 x 40"
.Ln8:  .asciz "chol_solve 70 vector"
.Ln9:  .asciz "solve 70 x 40 (Cholesky)"
.Ln10: .asciz "solve 70 x 40 (LU)"
.Ln11: .asciz "solve 2 x 1 (Cholesky fails, LU)"
.Ln12: .asciz "solve 3 x 2 (Cholesky)"
.Ln13: .asciz "rcond 70"
.Ln14: .asciz "rcond 3"
.Ln15: .asciz "sea_la_potrf 70"
.Ln16: .asciz "sea_la_issym 70"
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
