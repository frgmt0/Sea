# sea/tests/rt/x86_64_linux/rt_la_gemm_sweep.s -- GEMV and VECMAT bit for bit against the pinned orders of DESIGN.md 2.13.2 (LANGUAGE.md 10.5, 10.8) for every pair of extents 0 .. 33 (r, k for GEMV, k, c for VECMAT: every panel, pair and tail of every variant, empty operands included), on LCG data with about 0.1-0.2% each of +-0, +-Inf, NaN with payloads and subnormals among normal numbers of exponents -15 .. 16; and MATMUL on exact integer data (70x40 @ 40x65, 33x17 @ 17x9, 1x64 @ 64x1, 64x1 @ 1x64). Each sweep prints a 64-bit FNV-1a-style hash of the extents and result bits (a NaN folded as #7FF8000000000000, its bits not being observable); the hashes are those of a binary64 transcription of the pinned orders. Pass 1 runs under the first variant of the target (x86_64: sse2), pass 2 under the selected one (x86_64: avx2 on an AVX2 host), so equal lines show the forms bit-identical; the arm64 NEON form prints the same bytes. Heap check: 0 live objects.
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

# ---- test helpers (the same block in every rt_la_gemm test) -----------
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
# sea_main's frame: %rbp, %rbx, %r12-%r15 saved, 8 bytes of locals at
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
# The entries, by their index in the case tables.
.equ ENT_GEMV, 0
.equ ENT_VECMAT, 1
.equ ENT_MATMUL, 2
# The variant of the first pass: the baseline form of x86_64-linux.
.equ FIRST_VARIANT, SEA_VAR_SSE2

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

# putdec -- append the decimal text of %rdi (signed) to standard output.
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
    andl $15, %eax                  # the lowest digit, written right to left
    leal 48(%rax), %edx             # '0' + d
    leal 55(%rax), %r8d             # 'A' - 10 + d
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
# Clobbers caller-saved registers. Frame 8 bytes (%rbp).
    .p2align 4
putf:
    pushq %rbp
    movq %rsp, %rbp
    movq %rdi, %rax
    shlq $1, %rax                   # drop the sign
    movabsq $0xFFE0000000000000, %rcx   # the exponent all ones, shifted
    cmpq %rcx, %rax
    jbe 1f                          # not above +inf: a number
    TXT "NaN"
    jmp 2f
1:  call puthex
2:  popq %rbp
    ret

# mkarr -- a new dynamic f64 array (count 1) holding a copy of n doubles.
#   Inputs  : %rdi = rank, %rsi = rows, %rdx = cols (1 for a vector),
#             %rcx = the source doubles (rows * cols, column-major)
#   Outputs : %rax = the array
#   Clobbers: caller-saved registers
#   Callee-saved used: %rbx = the source, %r12 = the array. Frame 24 bytes.
    .p2align 4
mkarr:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12                      # %rsp = 0 (mod 16)
    movq %rcx, %rbx
    movq %rdx, %rcx                 # cols
    movq %rsi, %rdx                 # rows
    movq %rdi, %rsi                 # rank
    movl $SEA_EK_F64, %edi
    xorl %r8d, %r8d                 # site 0
    call sea_arr_new_u
    movq %rax, %r12
    movq SEA_ARR_ROWS(%r12), %rdx
    imulq SEA_ARR_COLS(%r12), %rdx
    shlq $3, %rdx                   # the bytes
    movq SEA_ARR_DATA(%r12), %rdi
    movq %rbx, %rsi
    call memcpy@PLT
    movq %r12, %rax
    popq %r12
    popq %rbx
    popq %rbp
    ret

# dirty -- leave a freed block of the class a result of this shape takes
# with every element 42.0 (#4045000000000000): the allocator hands the
# most recently freed block of a class out first, so a result that is not
# fully written shows it.
#   Inputs  : %rdi = rank, %rsi = rows, %rdx = cols
#   Clobbers: caller-saved registers
#   Callee-saved used: %rbx = the array. Frame 24 bytes.
    .p2align 4
dirty:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp
    movq %rdx, %rcx
    movq %rsi, %rdx
    movq %rdi, %rsi
    movl $SEA_EK_F64, %edi
    xorl %r8d, %r8d
    call sea_arr_new_u
    movq %rax, %rbx
    movq SEA_ARR_ROWS(%rbx), %rcx
    imulq SEA_ARR_COLS(%rbx), %rcx  # elements
    movq SEA_ARR_DATA(%rbx), %rdi
    movabsq $0x4045000000000000, %rax
    cld
    rep stosq
    REL %rbx                        # count 1 -> freed
    addq $8, %rsp
    popq %rbx
    popq %rbp
    ret

# callent -- call an entry by its table index.
#   Inputs  : %rdi = ENT_*, %rsi = the left operand, %rdx = the right one
#   Outputs : %rax = the entry's result
#   Clobbers: as the entries. Frame 8 bytes (%rbp).
    .p2align 4
callent:
    pushq %rbp
    movq %rsp, %rbp
    leaq entries(%rip), %rax
    movq (%rax,%rdi,8), %rax
    movq %rsi, %rdi
    movq %rdx, %rsi
    xorl %edx, %edx                 # site 0
    call *%rax
    popq %rbp
    ret
    .section .data.rel.ro,"aw",@progbits
    .p2align 3
entries:
    .quad sea_gemv, sea_vecmat, sea_matmul
    .text
# ---- end of the test helpers ------------------------------------------

# ---- the sweep --------------------------------------------------------
# The data: the 64-bit LCG s = s * 6364136223846793005 + 1442695040888963407
# from SEED; one value per step from u = s: cat = u >> 54; sign = bit 53;
# m = u's low 52 bits; cat 0: +0, 1: -0, 2: +Inf, 3: -Inf, 4: the quiet
# NaN #7FF8000000000000 | (u & #FFFF), 5: a subnormal (sign, m), else a
# normal number with the exponent 1008 + bits 47..51 (sign, m). The
# exact GEMM data: (u >> 59) - 16 as an f64 (-16 .. 15).
# The hash: h = #CBF29CE484222325; fold(b): h = (h XOR b) * #100000001B3
# (mod 2^64); each case folds its outer extent, then every result
# element's bits, a NaN as #7FF8000000000000 (NaN bits are not
# observable, LANGUAGE.md 6.5).
.equ SEED, 0x5EA0000000000853
.equ LCG_A, 6364136223846793005
.equ LCG_C, 1442695040888963407
.equ FNV0, 0xCBF29CE484222325
.equ FNVP, 0x100000001B3
.equ MAXN, 34                       # extents 0 .. 33

    .data
    .p2align 3
.Lstate: .quad 0
    .text

# lcgstep -- one LCG step. Outputs: %rax = u. Clobbers %rcx, %rdx. Leaf.
    .p2align 4
lcgstep:
    movq .Lstate(%rip), %rax
    movabsq $LCG_A, %rcx
    imulq %rcx, %rax
    movabsq $LCG_C, %rcx
    addq %rcx, %rax
    movq %rax, .Lstate(%rip)
    ret

# lcgval -- the next value's bits (see above). Outputs: %rax. Clobbers
# %rcx %rdx %rsi %rdi %r8. Leaf (calls the leaf lcgstep).
    .p2align 4
lcgval:
    call lcgstep
    movq %rax, %rcx
    shrq $54, %rcx                  # cat
    movq %rax, %rsi
    shrq $53, %rsi
    andl $1, %esi
    shlq $63, %rsi                  # the sign
    movabsq $0x000FFFFFFFFFFFFF, %rdi
    andq %rax, %rdi                 # m
    cmpq $5, %rcx
    ja 6f
    je 5f
    cmpq $4, %rcx
    je 4f
    cmpq $3, %rcx
    je 3f
    cmpq $2, %rcx
    je 2f
    cmpq $1, %rcx
    je 1f
    xorl %eax, %eax                 # 0: +0
    ret
1:  movabsq $0x8000000000000000, %rax   # 1: -0
    ret
2:  movabsq $0x7FF0000000000000, %rax   # 2: +Inf
    ret
3:  movabsq $0xFFF0000000000000, %rax   # 3: -Inf
    ret
4:  andl $0xFFFF, %eax              # 4: a quiet NaN with a payload
    movabsq $0x7FF8000000000000, %rcx
    orq %rcx, %rax
    ret
5:  movq %rsi, %rax                 # 5: a subnormal
    orq %rdi, %rax
    ret
6:  movq %rax, %r8                  # a normal number
    shrq $47, %r8
    andl $31, %r8d
    addq $1008, %r8
    shlq $52, %r8
    movq %rsi, %rax
    orq %rdi, %rax
    orq %r8, %rax
    ret

# lcgival -- the next exact GEMM value (an f64 -16 .. 15) in %rax's bits.
# Clobbers %rcx %rdx %xmm0. Leaf.
    .p2align 4
lcgival:
    call lcgstep
    shrq $59, %rax
    subq $16, %rax
    cvtsi2sdq %rax, %xmm0
    movq %xmm0, %rax
    ret

# fold -- h = (h XOR b) * FNVP. Inputs: %rdi = h, %rsi = b. Outputs:
# %rax. Clobbers %rcx. Leaf.
    .p2align 4
fold:
    movq %rdi, %rax
    xorq %rsi, %rax
    movabsq $FNVP, %rcx
    imulq %rcx, %rax
    ret

# fillarr -- a new dynamic f64 array (count 1) filled from a value routine.
#   Inputs  : %rdi = rank, %rsi = rows, %rdx = cols, %rcx = lcgval or
#             lcgival
#   Outputs : %rax = the array
#   Clobbers: caller-saved registers
#   Callee-saved used: %rbx = the routine, %r12 = the array, %r13 =
#             cursor, %r14 = elements left. Frame 40 bytes.
    .p2align 4
fillarr:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14                      # %rsp = 0 (mod 16)
    movq %rcx, %rbx
    movq %rdx, %rcx
    movq %rsi, %rdx
    movq %rdi, %rsi
    movl $SEA_EK_F64, %edi
    xorl %r8d, %r8d
    call sea_arr_new_u
    movq %rax, %r12
    movq SEA_ARR_DATA(%r12), %r13
    movq SEA_ARR_ROWS(%r12), %r14
    imulq SEA_ARR_COLS(%r12), %r14
1:  testq %r14, %r14
    jz 2f
    call *%rbx
    movq %rax, (%r13)               # column-major, in generation order
    addq $8, %r13
    decq %r14
    jmp 1b
2:  movq %r12, %rax
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

# foldres -- fold the outer extent, then every element (NaN canonical).
#   Inputs  : %rdi = h, %rsi = the extent, %rdx = the result array
#   Outputs : %rax = h
#   Clobbers: %rax %rcx %rdx %rsi %rdi %r8 %r9. Leaf.
    .p2align 4
foldres:
    movq %rdx, %r8
    call fold                       # the extent
    movq SEA_ARR_ROWS(%r8), %r9
    imulq SEA_ARR_COLS(%r8), %r9
    movq SEA_ARR_DATA(%r8), %r8
1:  testq %r9, %r9
    jz 3f
    movq (%r8), %rsi
    addq $8, %r8
    movq %rsi, %rdx
    shlq $1, %rdx                   # a NaN: above +Inf without the sign
    movabsq $0xFFE0000000000000, %rcx
    cmpq %rcx, %rdx
    jbe 2f
    movabsq $0x7FF8000000000000, %rsi   # canonical
2:  movq %rax, %rdi
    call fold
    decq %r9
    jmp 1b
3:  ret

# sweepmv -- GEMV for every r, k in 0 .. 33 (A then x from the LCG).
#   Outputs : %rax = the hash
#   Callee-saved used: %rbx = r, %r12 = k, %r13 = A, %r14 = x,
#             %r15 = y, 0(%rsp) = h. Frame 56 bytes.
    .p2align 4
sweepmv:
    PROLOGUE
    movabsq $SEED, %rax
    movq %rax, .Lstate(%rip)
    movabsq $FNV0, %rax
    movq %rax, (%rsp)
    xorl %ebx, %ebx
1:  xorl %r12d, %r12d
2:  movl $2, %edi                   # A: r x k
    movq %rbx, %rsi
    movq %r12, %rdx
    leaq lcgval(%rip), %rcx
    call fillarr
    movq %rax, %r13
    movl $1, %edi                   # x: k
    movq %r12, %rsi
    movl $1, %edx
    leaq lcgval(%rip), %rcx
    call fillarr
    movq %rax, %r14
    movq %r13, %rdi
    movq %r14, %rsi
    xorl %edx, %edx
    call sea_gemv
    movq %rax, %r15
    movq (%rsp), %rdi
    movq %rbx, %rsi
    movq %r15, %rdx
    call foldres
    movq %rax, (%rsp)
    REL %r15
    REL %r13
    REL %r14
    incq %r12
    cmpq $MAXN, %r12
    jb 2b
    incq %rbx
    cmpq $MAXN, %rbx
    jb 1b
    movq (%rsp), %rax
    EPILOGUE

# sweepvm -- VECMAT for every k, c in 0 .. 33 (x then A).
#   Outputs : %rax = the hash
#   Callee-saved used: %rbx = k, %r12 = c, %r13 = x, %r14 = A,
#             %r15 = y, 0(%rsp) = h. Frame 56 bytes.
    .p2align 4
sweepvm:
    PROLOGUE
    movabsq $SEED, %rax
    movq %rax, .Lstate(%rip)
    movabsq $FNV0, %rax
    movq %rax, (%rsp)
    xorl %ebx, %ebx
1:  xorl %r12d, %r12d
2:  movl $1, %edi                   # x: k
    movq %rbx, %rsi
    movl $1, %edx
    leaq lcgval(%rip), %rcx
    call fillarr
    movq %rax, %r13
    movl $2, %edi                   # A: k x c
    movq %rbx, %rsi
    movq %r12, %rdx
    leaq lcgval(%rip), %rcx
    call fillarr
    movq %rax, %r14
    movq %r13, %rdi
    movq %r14, %rsi
    xorl %edx, %edx
    call sea_vecmat
    movq %rax, %r15
    movq (%rsp), %rdi
    movq %r12, %rsi
    movq %r15, %rdx
    call foldres
    movq %rax, (%rsp)
    REL %r15
    REL %r13
    REL %r14
    incq %r12
    cmpq $MAXN, %r12
    jb 2b
    incq %rbx
    cmpq $MAXN, %rbx
    jb 1b
    movq (%rsp), %rax
    EPILOGUE

# sweepmm -- MATMUL on exact integer data, the shapes of .Lmm_shapes.
#   Outputs : %rax = the hash
#   Callee-saved used: %rbx = the shape record, %r13 = A, %r14 = B,
#             %r15 = C, 0(%rsp) = h. Frame 56 bytes.
    .p2align 4
sweepmm:
    PROLOGUE
    movabsq $SEED, %rax
    movq %rax, .Lstate(%rip)
    movabsq $FNV0, %rax
    movq %rax, (%rsp)
    leaq .Lmm_shapes(%rip), %rbx
1:  cmpq $0, (%rbx)
    je 2f
    movl $2, %edi                   # A: r x k
    movq (%rbx), %rsi
    movq 8(%rbx), %rdx
    leaq lcgival(%rip), %rcx
    call fillarr
    movq %rax, %r13
    movl $2, %edi                   # B: k x c
    movq 8(%rbx), %rsi
    movq 16(%rbx), %rdx
    leaq lcgival(%rip), %rcx
    call fillarr
    movq %rax, %r14
    movq %r13, %rdi
    movq %r14, %rsi
    xorl %edx, %edx
    call sea_matmul
    movq %rax, %r15
    movq (%rbx), %rsi
    imulq 16(%rbx), %rsi            # the extent: r * c
    movq (%rsp), %rdi
    movq %r15, %rdx
    call foldres
    movq %rax, (%rsp)
    REL %r15
    REL %r13
    REL %r14
    addq $24, %rbx
    jmp 1b
2:  movq (%rsp), %rax
    EPILOGUE

    .section .rodata
    .p2align 3
.Lmm_shapes:                        # r, k, c
    .quad 70, 40, 65
    .quad 33, 17, 9
    .quad 1, 64, 1
    .quad 64, 1, 64
    .quad 0
    .text

# onepass -- the three sweeps; prints `pass <n> gemv|vecmat|matmul <hash>`.
#   Inputs  : %rdi = n. Callee-saved used: %rbx = n. Frame 24 bytes.
    .p2align 4
onepass:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp
    movq %rdi, %rbx
    TXT "pass "
    movq %rbx, %rdi
    call putdec
    TXT " gemv "
    call sweepmv
    movq %rax, %rdi
    call puthex
    TXT "\npass "
    movq %rbx, %rdi
    call putdec
    TXT " vecmat "
    call sweepvm
    movq %rax, %rdi
    call puthex
    TXT "\npass "
    movq %rbx, %rdi
    call putdec
    TXT " matmul "
    call sweepmm
    movq %rax, %rdi
    call puthex
    TXT "\n"
    addq $8, %rsp
    popq %rbx
    popq %rbp
    ret

# ---- the test ---------------------------------------------------------
# sea_main -- pass 1 under FIRST_VARIANT, pass 2 under the variant main
# selected; both must give the hashes of the pinned orders.
# Callee-saved used: %rbx (the selected variant). Frame 56 bytes.
    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    PROLOGUE
    movq sea_variant(%rip), %rbx
    movq $FIRST_VARIANT, sea_variant(%rip)
    movl $1, %edi
    call onepass
    movq %rbx, sea_variant(%rip)
    movl $2, %edi
    call onepass
    EPILOGUE
    .size sea_main, . - sea_main

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
