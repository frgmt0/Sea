# sea/tests/rt/x86_64_linux/rt_la_gemm_abi.s -- the ABI of sea_gemv, sea_vecmat and sea_matmul (DESIGN.md 2.13.5 "ABI", "Stack"; 2.13.8 "Runtime"): each case is called with x19-x29, d8-d15 and FPCR (AHP and FZ16 set) holding known patterns and the 128 KiB below sp guard-filled; afterwards x19-x29, sp, d8-d15 and FPCR must be unchanged and the call, its callees included (sea_arr_new(_u), _bsk_kern_gemm with its packing), must have written at most SEA_STACK_MARGIN bytes below sp (DESIGN.md 4.6: the margin covers the runtime frames). Cases: GEMV and VECMAT with panels and tails, MATMUL small and large (a 130x300 @ 300x90 product reaches the blocked kernel paths), and the empty and zero shortcuts. Each case prints `<label>: ok`; a failure prints its error bits and exits 1. The cases run under the first variant (x86_64: sse2) and under the selected one.
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
.Lres:   .quad 0                    # the result of the last call
.Lsp:    .quad 0                    # %rsp at the call site
.Lmx0:   .long 0                    # MXCSR before the call
.Lmx1:   .long 0                    # MXCSR after the call
.Ldepth: .quad 0                    # bytes the call wrote below its return slot
    .text

# probe -- call an entry under the ABI check.
#   Inputs  : %rdi = the entry, %rsi = left, %rdx = right (site 0)
#   Outputs : %rax = 0, or the sum of: 1 %rsp changed, 2 MXCSR's control
#             bits changed, 4 one of %rbx %rbp %r12-%r15 changed, 8 the
#             direction flag set, 16 the call wrote more than
#             SEA_STACK_MARGIN bytes below its return slot; .Lres = the
#             result, .Ldepth = the bytes written below the return slot
#   Clobbers: the caller-saved registers
#   Callee-saved used: all of them hold the test patterns during the call
#   Frame   : 8 (%rbp) + 40 (callee-saved) + 8
    .p2align 4
probe:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $8, %rsp                   # %rsp = 0 (mod 16): the call site
    movq %rdi, %r11                 # the entry
    movq %rsi, %r12
    movq %rdx, %r13
    # The guard: GUARD_BYTES ending at -8(%rsp), the return address's slot.
    leaq -8-GUARD_BYTES(%rsp), %rdi
    movl $GUARD_BYTES/8, %ecx
    movabsq $GUARD_WORD, %rax
    cld
    rep stosq
    stmxcsr .Lmx0(%rip)
    movq %r12, %rdi                 # the arguments
    movq %r13, %rsi
    xorl %edx, %edx
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
    movq .Lsp(%rip), %rsp           # back to the call site's %rsp
3:  movl .Lmx0(%rip), %ecx
    xorl .Lmx1(%rip), %ecx
    testl $MXCSR_CTL, %ecx
    jz 4f
    orl $2, %eax
4:  testq $RFLAGS_DF, %r8
    jz 5f
    orl $8, %eax
    cld
    # The depth: the lowest guard word changed, from the bottom up.
5:  movq .Lsp(%rip), %rdx
    leaq -8-GUARD_BYTES(%rdx), %rdi # the lowest guard word
    leaq -8(%rdx), %rsi             # the return address's slot (excluded)
    movabsq $GUARD_WORD, %rcx
6:  cmpq %rsi, %rdi
    jae 7f
    cmpq (%rdi), %rcx
    jne 7f
    addq $8, %rdi
    jmp 6b
7:  subq %rdi, %rsi                 # 0 when nothing was written
    movq %rsi, .Ldepth(%rip)
    cmpq $SEA_STACK_MARGIN, %rsi
    jbe 8f
    orl $16, %eax
8:  addq $8, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

# newarr -- a new dynamic f64 array (count 1), element i = (i mod 7) - 3.
#   Inputs  : %rdi = rank, %rsi = rows, %rdx = cols
#   Outputs : %rax = the array
#   Clobbers: caller-saved registers. Frame 8 bytes (%rbp).
    .p2align 4
newarr:
    pushq %rbp
    movq %rsp, %rbp
    movq %rdx, %rcx
    movq %rsi, %rdx
    movq %rdi, %rsi
    movl $SEA_EK_F64, %edi
    xorl %r8d, %r8d
    call sea_arr_new_u
    movq SEA_ARR_ROWS(%rax), %r9
    imulq SEA_ARR_COLS(%rax), %r9   # elements
    movq SEA_ARR_DATA(%rax), %r10
    movq %rax, %r11
    xorl %esi, %esi                 # i
    movl $7, %edi
1:  cmpq %r9, %rsi
    jae 2f
    movq %rsi, %rax
    xorl %edx, %edx
    divq %rdi                       # %rdx = i mod 7
    subq $3, %rdx
    cvtsi2sdq %rdx, %xmm0
    movsd %xmm0, (%r10,%rsi,8)
    incq %rsi
    jmp 1b
2:  movq %r11, %rax
    popq %rbp
    ret

# A case record (8-byte words): label, ENT_*, the left operand's rank,
# rows, cols, the right operand's rank, rows, cols.
.equ AR_SIZE, 64

# runcases -- every ABI case under the current variant: `<label>: ok`,
# or `<label>: BAD <bits>` (the error bits of probe) and exit 1.
#   Outputs : %rax = the deepest write of the cases
#   Callee-saved used: %rbx = the record, %r12 = left, %r13 = right,
#             %r14 = the error bits, %r15 = the deepest write. Frame 56.
    .p2align 4
runcases:
    PROLOGUE
    leaq acases(%rip), %rbx
    xorl %r15d, %r15d
1:  cmpq $0, (%rbx)
    je 9f
    movq 16(%rbx), %rdi
    movq 24(%rbx), %rsi
    movq 32(%rbx), %rdx
    call newarr
    movq %rax, %r12
    movq 40(%rbx), %rdi
    movq 48(%rbx), %rsi
    movq 56(%rbx), %rdx
    call newarr
    movq %rax, %r13
    leaq entries(%rip), %rax
    movq 8(%rbx), %rcx
    movq (%rax,%rcx,8), %rdi
    movq %r12, %rsi
    movq %r13, %rdx
    call probe
    movq %rax, %r14
    movq .Ldepth(%rip), %rax
    cmpq %r15, %rax
    cmova %rax, %r15
    movq (%rbx), %rdi
    call putcstr
    testq %r14, %r14
    jnz 2f
    TXT ": ok\n"
    movq .Lres(%rip), %rax
    REL %rax
    REL %r12
    REL %r13
    addq $AR_SIZE, %rbx
    jmp 1b
2:  TXT ": BAD "
    movq %r14, %rdi
    call putdec
    TXT "\n"
    call sea_out_flush
    movl $1, %edi
    call _exit@PLT
9:  movq %r15, %rax
    EPILOGUE

# ---- the test ---------------------------------------------------------
# sea_main -- the cases under FIRST_VARIANT, then under the variant main
# selected. Callee-saved used: %rbx (the selected variant). Frame 56.
    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    PROLOGUE
    movq sea_variant(%rip), %rbx
    movq $FIRST_VARIANT, sea_variant(%rip)
    TXT "pass 1\n"
    call runcases
    movq %rbx, sea_variant(%rip)
    TXT "pass 2\n"
    call runcases
    EPILOGUE
    .size sea_main, . - sea_main

    .section .data.rel.ro,"aw",@progbits
    .p2align 3
acases:
    .quad .Ln0, ENT_GEMV, 2, 19, 5, 1, 5, 1
    .quad .Ln1, ENT_GEMV, 2, 37, 33, 1, 33, 1
    .quad .Ln2, ENT_GEMV, 2, 4, 0, 1, 0, 1
    .quad .Ln3, ENT_GEMV, 2, 0, 3, 1, 3, 1
    .quad .Ln4, ENT_VECMAT, 1, 13, 1, 2, 13, 3
    .quad .Ln5, ENT_VECMAT, 1, 40, 1, 2, 40, 17
    .quad .Ln6, ENT_VECMAT, 1, 0, 1, 2, 0, 5
    .quad .Ln7, ENT_MATMUL, 2, 3, 5, 2, 5, 2
    .quad .Ln8, ENT_MATMUL, 2, 70, 40, 2, 40, 65
    .quad .Ln9, ENT_MATMUL, 2, 130, 300, 2, 300, 90
    .quad .Ln10, ENT_MATMUL, 2, 4, 0, 2, 0, 6
    .quad .Ln11, ENT_MATMUL, 2, 0, 3, 2, 3, 6
    .quad 0
.Ln0:  .asciz "gemv 19x5 @ 5"
.Ln1:  .asciz "gemv 37x33 @ 33"
.Ln2:  .asciz "gemv 4x0 @ 0"
.Ln3:  .asciz "gemv 0x3 @ 3"
.Ln4:  .asciz "vecmat 13 @ 13x3"
.Ln5:  .asciz "vecmat 40 @ 40x17"
.Ln6:  .asciz "vecmat 0 @ 0x5"
.Ln7:  .asciz "matmul 3x5 @ 5x2"
.Ln8:  .asciz "matmul 70x40 @ 40x65"
.Ln9:  .asciz "matmul 130x300 @ 300x90"
.Ln10: .asciz "matmul 4x0 @ 0x6"
.Ln11: .asciz "matmul 0x3 @ 3x6"
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
