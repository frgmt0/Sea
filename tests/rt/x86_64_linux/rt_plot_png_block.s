# sea/tests/rt/x86_64_linux/rt_plot_png_block.s -- the stored-block boundaries of sea_png (DESIGN.md 2.14.6 "PNG", L-kt): raw data of exactly 65 535 bytes (28 x 771: one block, BFINAL on it), of 65 536 bytes (21 845 x 1: blocks of 65 535 and 1) and of 87 380 bytes in 21 845 rows (1 x 21 845: 65 535 and 21 845); the pixel bytes, rows from the top, are the seeded sequence (byte i = (73 i + 41) mod 256). Each line `png W H RAWLEN LEN CRC` (the CRC-32 of the whole file, by the private sea_crc32). The expected output was computed independently with Python's zlib.crc32, zlib.adler32 and struct, every stream checked by zlib.decompress (never from the runtime). Each block is freed with its length.
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
.equ NSEQ, 65535                    # the most pixel bytes of a case
.equ NRAW, 87380                    # the most raw bytes of a case
    .bss
    .p2align 4
seq:    .zero NSEQ
raw:    .zero NRAW
    .text
# pngcase -- the raw data of a w x h image of seeded pixels, its PNG,
#   `png W H RAWLEN LEN CRC`, the block freed.
#   Inputs: %rdi = w, %rsi = h. Clobbers caller-saved.
#   Callee-saved used: %rbx = w, %r12 = h, %r13 = the raw length, %r14 =
#   the block, %r15 = its length. Frame: PROLOGUE.
    .p2align 4
pngcase:
    PROLOGUE
    movq %rdi, %rbx
    movq %rsi, %r12
    leaq raw(%rip), %rdi            # per row: 0, then 3w pixel bytes
    leaq seq(%rip), %rsi
    xorl %edx, %edx
1:  cmpq %r12, %rdx
    jae 2f
    movb $0, (%rdi)
    incq %rdi
    leaq (%rbx,%rbx,2), %rcx
    rep movsb
    incq %rdx
    jmp 1b
2:  leaq raw(%rip), %rax
    subq %rax, %rdi
    movq %rdi, %r13
    leaq raw(%rip), %rdi
    movq %rbx, %rsi
    movq %r12, %rdx
    xorl %ecx, %ecx
    call sea_png
    movq %rax, %r14
    movq %rdx, %r15
    TXT "png "
    movq %rbx, %rdi
    call putdec
    TXT " "
    movq %r12, %rdi
    call putdec
    TXT " "
    movq %r13, %rdi
    call putdec
    TXT " "
    movq %r15, %rdi
    call putdec
    TXT " "
    movq %r14, %rdi
    movq %r15, %rsi
    call sea_crc32
    movq %rax, %rdi
    movl $8, %esi
    call puthexn
    TXT "\n"
    movq %r14, %rdi
    movq %r15, %rsi
    call sea_free_block
    EPILOGUE

    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    PROLOGUE
    leaq seq(%rip), %rdi            # the seeded sequence
    xorl %ecx, %ecx
1:  imull $73, %ecx, %eax
    addl $41, %eax
    movb %al, (%rdi,%rcx)
    incl %ecx
    cmpl $NSEQ, %ecx
    jb 1b
    movl $28, %edi
    movl $771, %esi
    call pngcase
    movl $21845, %edi
    movl $1, %esi
    call pngcase
    movl $1, %edi
    movl $21845, %esi
    call pngcase
    EPILOGUE
    .size sea_main, . - sea_main

    .data
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
