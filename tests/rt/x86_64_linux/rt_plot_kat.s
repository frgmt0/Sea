# sea/tests/rt/x86_64_linux/rt_plot_kat.s -- the known answers of rt_png.s (DESIGN.md 2.14.6 "PNG", 2.14.8 "The known answers' files", L-kt, L-ld): the private sea_crc32 and sea_adler32 on the empty input, `123456789`, `Wikipedia` and 1, 65 535, 65 536 and 200 000 bytes of the seeded sequence (byte i = (73 i + 41) mod 256); sea_b64 on its first 0 ... 5 and 1 000 bytes; whole PNGs from sea_png (the 1 x 1 white image, the 2 x 2 image #ff0000 #00ff00 / #0000ff #ffffff, the 21 846 x 1 image whose pixel bytes are the seeded sequence's first 65 538 bytes (two stored blocks of 65 535 and 4), and the 1 x 256 colorbar, row r the colour map's entry 255 - r from sea_plt_cmap), each as `png W H LEN CRC` (the CRC-32 of the whole file) and, for the first two, `pngb64 TEXT`. The expected output is tests/vectors/plot9_cases.py's (zlib and base64 as the oracle), never the runtime's. Each PNG block is freed with its length (heap check).
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
.equ NSEQ, 200000                   # the longest seeded input
.equ WIDE, 21846                    # the wide image's width
    .bss
    .p2align 4
seq:    .zero NSEQ                  # the seeded sequence
raw:    .zero 1 + 3 * WIDE          # a PNG's raw data (the largest: the wide image)
out:    .zero 2048                  # a base64 text
    .text
# kat2 -- the crc32 and adler32 lines of one input.
#   Inputs: %rdi = the bytes, %rsi = their count. Clobbers caller-saved.
#   Callee-saved used: %rbx = the bytes, %r12 = the count. Frame: 24 + 8.
    .p2align 4
kat2:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    movq %rdi, %rbx
    movq %rsi, %r12
    TXT "crc32 "
    movq %r12, %rdi
    call putdec
    TXT " "
    movq %rbx, %rdi
    movq %r12, %rsi
    call sea_crc32
    movq %rax, %rdi
    movl $8, %esi
    call puthexn
    TXT "\nadler32 "
    movq %r12, %rdi
    call putdec
    TXT " "
    movq %rbx, %rdi
    movq %r12, %rsi
    call sea_adler32
    movq %rax, %rdi
    movl $8, %esi
    call puthexn
    TXT "\n"
    popq %r12
    popq %rbx
    popq %rbp
    ret

# b64line -- `<tag><base64 of the bytes>\n` (the tag already written).
#   Inputs: %rdi = the bytes, %rsi = their count (<= 1500). Clobbers
#   caller-saved. Frame: 8 (%rbp).
    .p2align 4
b64line:
    pushq %rbp
    movq %rsp, %rbp
    movq %rsi, %rdx
    movq %rdi, %rsi
    leaq out(%rip), %rdi
    call sea_b64
    leaq out(%rip), %rdi
    movq %rax, %rsi
    call sea_out_write
    TXT "\n"
    popq %rbp
    ret

# pngcase -- the PNG of raw: `png W H LEN CRC`, then with show != 0
#   `pngb64 TEXT`; the block freed.
#   Inputs: %rdi = w, %rsi = h, %edx = show. Clobbers caller-saved.
#   Callee-saved used: %rbx = w, %r12 = h, %r13 = show, %r14 = the block,
#   %r15 = its length. Frame: PROLOGUE.
    .p2align 4
pngcase:
    PROLOGUE
    movq %rdi, %rbx
    movq %rsi, %r12
    movl %edx, %r13d
    leaq raw(%rip), %rdi
    movq %rbx, %rsi
    movq %r12, %rdx
    xorl %ecx, %ecx                 # site 0
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
    testl %r13d, %r13d
    jz 1f
    TXT "pngb64 "
    movq %r14, %rdi
    movq %r15, %rsi
    call b64line
1:  movq %r14, %rdi
    movq %r15, %rsi
    call sea_free_block
    EPILOGUE

    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    PROLOGUE
    # The seeded sequence: byte i = (73 i + 41) mod 256.
    leaq seq(%rip), %rdi
    xorl %ecx, %ecx
1:  imull $73, %ecx, %eax
    addl $41, %eax
    movb %al, (%rdi,%rcx)
    incl %ecx
    cmpl $NSEQ, %ecx
    jb 1b
    # CRC-32 and Adler-32.
    leaq seq(%rip), %rdi
    xorl %esi, %esi
    call kat2
    leaq S123(%rip), %rdi
    movl $9, %esi
    call kat2
    leaq WIKI(%rip), %rdi
    movl $9, %esi
    call kat2
    leaq lens(%rip), %rbx
2:  movq (%rbx), %rsi
    testq %rsi, %rsi
    jz 3f
    leaq seq(%rip), %rdi
    call kat2
    addq $8, %rbx
    jmp 2b
    # Base64 on 0 .. 5 and 1000 bytes.
3:  leaq b64lens(%rip), %rbx
4:  movq (%rbx), %r12
    testq %r12, %r12
    js 5f
    TXT "b64 "
    movq %r12, %rdi
    call putdec
    TXT " "
    leaq seq(%rip), %rdi
    movq %r12, %rsi
    call b64line
    addq $8, %rbx
    jmp 4b
    # The 1 x 1 white image.
5:  leaq raw(%rip), %rdi
    movl $0xFFFFFF00, (%rdi)        # 0, ff ff ff
    movl $1, %edi
    movl $1, %esi
    movl $1, %edx
    call pngcase
    # The 2 x 2 image.
    leaq raw(%rip), %rdi
    leaq TWO(%rip), %rsi
    movl $14, %ecx
    rep movsb
    movl $2, %edi
    movl $2, %esi
    movl $1, %edx
    call pngcase
    # The 21 846 x 1 image: 0, then the seeded sequence's first 65 538 bytes.
    leaq raw(%rip), %rdi
    movb $0, (%rdi)
    incq %rdi
    leaq seq(%rip), %rsi
    movl $(3 * WIDE), %ecx
    rep movsb
    movl $WIDE, %edi
    movl $1, %esi
    xorl %edx, %edx
    call pngcase
    # The colorbar: 1 x 256, row r the map entry 255 - r.
    xorl %ebx, %ebx
6:  movl $255, %edi
    subl %ebx, %edi
    call sea_plt_cmap
    leaq raw(%rip), %rdi
    leaq (%rdi,%rbx,4), %rdi
    movb $0, (%rdi)
    movb %al, 3(%rdi)
    shrl $8, %eax
    movb %al, 2(%rdi)
    shrl $8, %eax
    movb %al, 1(%rdi)
    incl %ebx
    cmpl $256, %ebx
    jb 6b
    movl $1, %edi
    movl $256, %esi
    xorl %edx, %edx
    call pngcase
    EPILOGUE
    .size sea_main, . - sea_main

    .section .rodata
    .p2align 3
lens:   .quad 1, 65535, 65536, 200000, 0
b64lens: .quad 0, 1, 2, 3, 4, 5, 1000, -1
S123:   .ascii "123456789"
WIKI:   .ascii "Wikipedia"
TWO:    .byte 0, 0xFF, 0, 0, 0, 0xFF, 0, 0, 0, 0, 0xFF, 0xFF, 0xFF, 0xFF
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
