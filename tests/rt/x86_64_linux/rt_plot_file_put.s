# sea/tests/rt/x86_64_linux/rt_plot_file_put.s -- the private sea_file_put of rt_file.s (DESIGN.md 2.14.6 "The byte buffer and the file", L-lc, L-ld): a whole file written by open(O_WRONLY | O_CREAT | O_TRUNC, 0666), sea_write_all and close: ten bytes into a new a.txt, then three bytes into the same file (truncated: 3 bytes left, not 10), then a sea_alloc block of 64 bytes holding "xy" given with its size (freed after the write: the next sea_alloc of its class returns the same block, the small classes being LIFO, DESIGN.md 4.1), then no bytes (an empty file); each file read back and printed as `<length> [<bytes>]`. A cap of 0 frees nothing. No object is made.
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

# ---- test helpers (the same block in every rt_plot test that prints) --
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
# A static string object (count SEA_RC_STATIC).
.macro SSTR label, text
    .p2align 3
\label:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad .Lsse\@ - .Lsss\@
.Lsss\@: .ascii "\text"
.Lsse\@:
.endm
# A static dynamic f64 vector of n elements (count SEA_RC_STATIC); its
# elements follow the header.
.macro VEC name, n
    .p2align 6
\name:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_ARRAY, SEA_EK_F64, 1, 0, 0, 0, 0, 0
    .quad \n, 1, \n, \name + SEA_ARR_SIZE, 8, 0
.endm

    .text
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

# puthexn -- append the low %esi hexadecimal digits of %rdi, upper case
#   (16 for f64 bits, 6 for a colour). Clobbers caller-saved registers.
#   Frame: 8 (%rbp) + 16 bytes.
    .p2align 4
puthexn:
    pushq %rbp
    movq %rsp, %rbp
    subq $16, %rsp
    movl %esi, %ecx
    movl %esi, %r9d
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
    movl %r9d, %esi
    call sea_out_write
    movq %rbp, %rsp
    popq %rbp
    ret
# ---- end of the test helpers ------------------------------------------

# ---- the test ---------------------------------------------------------
    .bss
    .p2align 4
rbuf:   .zero 64
    .text
# show -- read the whole file a.txt (at most 64 bytes) and append
#   `<length> [<bytes>]` + LF. Frame: 8 (%rbp) + 8 (%rbx) + 8.
    .p2align 4
show:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp
    leaq cpath(%rip), %rdi
    xorl %esi, %esi                 # O_RDONLY
    xorl %eax, %eax
    call open@PLT
    movl %eax, %ebx
    movl %ebx, %edi
    leaq rbuf(%rip), %rsi
    movl $64, %edx
    call read@PLT
    movq %rax, 0(%rsp)
    movl %ebx, %edi
    call close@PLT
    movq 0(%rsp), %rdi
    call putdec
    TXT " ["
    leaq rbuf(%rip), %rdi
    movq 0(%rsp), %rsi
    call sea_out_write
    TXT "]\n"
    addq $8, %rsp
    popq %rbx
    popq %rbp
    ret

    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    PROLOGUE
    # 1. A new file of ten bytes.
    leaq PATH(%rip), %rdi
    leaq ten(%rip), %rsi
    movl $10, %edx
    xorl %ecx, %ecx
    xorl %r8d, %r8d                 # cap 0: the bytes are not freed
    call sea_file_put
    call show
    # 2. The same file again, shorter: truncated, not overwritten in place.
    leaq PATH(%rip), %rdi
    leaq three(%rip), %rsi
    movl $3, %edx
    xorl %ecx, %ecx
    xorl %r8d, %r8d                 # cap 0: the bytes are not freed
    call sea_file_put
    call show
    # 3. A block of 64 bytes from sea_alloc holding "xy", given with its
    #    size: freed after the write, so the next sea_alloc of its class
    #    hands the same block out again (small classes are LIFO, DESIGN.md
    #    4.1).
    movl $64, %edi
    xorl %esi, %esi
    call sea_alloc
    movq %rax, %r12                 # %r12 = the block
    movb $'x', (%r12)
    movb $'y', 1(%r12)
    leaq PATH(%rip), %rdi
    movq %r12, %rsi
    movl $2, %edx
    xorl %ecx, %ecx
    movl $64, %r8d                  # cap 64: freed by sea_file_put
    call sea_file_put
    call show
    movl $64, %edi
    xorl %esi, %esi
    call sea_alloc
    xorl %edi, %edi
    cmpq %r12, %rax
    sete %dil
    movq %rax, %r12
    pushq %rdi
    pushq %rdi
    TXT "block given back "
    popq %rdi
    popq %rdi
    call putdec
    TXT "\n"
    movq %r12, %rdi                 # the block, freed for good
    movl $64, %esi
    call sea_free_block
    # 4. No bytes: an empty file.
    leaq PATH(%rip), %rdi
    leaq three(%rip), %rsi
    xorl %edx, %edx
    xorl %ecx, %ecx
    xorl %r8d, %r8d                 # cap 0: the bytes are not freed
    call sea_file_put
    call show
    # 5. No object was made: the path copy and the block are blocks.
    TXT "live "
    movq sea_live(%rip), %rdi
    call putdec
    TXT "\n"
    EPILOGUE
    .size sea_main, . - sea_main

    .section .rodata
ten:    .ascii "0123456789"
three:  .ascii "abc"
cpath:  .asciz "a.txt"
    .section .data.rel.ro,"aw",@progbits
    SSTR PATH, "a.txt"
    .p2align 3
    .globl sea_sites
sea_sites:
    .quad .Lsite_file
    .quad 1
.Lsite_file:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 8
    .ascii "plot.sea"

    .section .note.GNU-stack,"",@progbits
