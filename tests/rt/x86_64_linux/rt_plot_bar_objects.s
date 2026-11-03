# sea/tests/rt/x86_64_linux/rt_plot_bar_objects.s -- the series records of BAR, BARH, CONTOUR and IMAGE (DESIGN.md 2.14.5, 2.14.6 "Objects", "Style and colour", "Block sizes", "Freeing"; L-kf, L-kh, Decision 132 (a)): kind, axes index, colour (the cycle for a bar or barh without a colour, which advances it; the argument written in either case of hex digits, which does not; -1 for a contour without a colour and 0 for an image, neither touching the cycle), width bits, label (retained once, 0 for ""), n, m, levels, flag, and the data block (a copy, never the argument: x then h, h, or x, y, Z column-major; none for an empty series; x only for a contour with no y), with CONTOUR's colour and site in its stack arguments; the arguments untouched; then sea_free of the figure frees every block with its exact size and releases the labels (live and freed counts; heap check: no object left).
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
.macro MAT name, r, c
    .p2align 6
\name:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_ARRAY, SEA_EK_F64, 2, 0, 0, 0, 0, 0
    .quad \r, \c, (\r) * (\c), \name + SEA_ARR_SIZE, 8, 0
.endm

# ---- the test ---------------------------------------------------------
# The private layouts read here (DESIGN.md 2.14.6 "Objects", L-kw):
# Figure 72 axes table, 80 nsr, 96 series table; axes record 160 cycle
# index; series record (128 bytes) 0 kind 8 axes 16 colour 40 width 48
# label 56 n 64 m 72 data 80 levels 88 flag.
    .bss
    .p2align 3
gFIG:   .zero 8
gA:     .zero 8
gS1:    .zero 8                     # the labels "11" and "12" (count 1 each)
gS2:    .zero 8
live0:  .zero 8
freed0: .zero 8
    .text
# The entries' calls (operands are movq sources).
.macro BARC x, h, w, lab, col
    movq gA(%rip), %rdi
    leaq \x(%rip), %rsi
    leaq \h(%rip), %rdx
    movq \lab, %rcx
    leaq \col(%rip), %r8
    xorl %r9d, %r9d
    movsd \w(%rip), %xmm0
    call sea_bar
.endm
.macro BARHC h, w, lab, col
    movq gA(%rip), %rdi
    leaq \h(%rip), %rsi
    movq \lab, %rdx
    leaq \col(%rip), %rcx
    xorl %r8d, %r8d
    movsd \w(%rip), %xmm0
    call sea_barh
.endm
.macro CONTC x, y, z, lev, lab, col
    subq $16, %rsp
    leaq \col(%rip), %rax
    movq %rax, 0(%rsp)              # color: the first stack argument
    movq $0, 8(%rsp)                # site: the second
    movq gA(%rip), %rdi
    leaq \x(%rip), %rsi
    leaq \y(%rip), %rdx
    leaq \z(%rip), %rcx
    movq $\lev, %r8
    movq $\lab, %r9
    call sea_contour
    addq $16, %rsp
.endm
.macro IMGC x, y, z, cb
    movq gA(%rip), %rdi
    leaq \x(%rip), %rsi
    leaq \y(%rip), %rdx
    leaq \z(%rip), %rcx
    movq $\cb, %r8
    xorl %r9d, %r9d
    call sea_image
.endm
# Field printers: %rbx = the record.
.macro PF label, off
    TXT " \label "
    movq \off(%rbx), %rdi
    call putdec
.endm
.macro PH label, off, n
    TXT " \label "
    movq \off(%rbx), %rdi
    movl $\n, %esi
    call puthexn
.endm
.macro SRREC idx
    movq gFIG(%rip), %rax
    movq 96(%rax), %rbx
    addq $(\idx * 128), %rbx
.endm
# ` Acyc <n>`: the axes record's cycle index.
.macro ACYC
    TXT " Acyc "
    movq gFIG(%rip), %rax
    movq 72(%rax), %rax
    movq 160(%rax), %rdi
    call putdec
.endm
# ` label <0/1>` whether the label field is string g; ` Src <count>`.
.macro ISLAB g
    TXT " label "
    movq 48(%rbx), %rax
    xorl %edi, %edi
    cmpq \g(%rip), %rax
    sete %dil
    call putdec
    TXT " Src "
    movq \g(%rip), %rax
    movq (%rax), %rdi
    call putdec
.endm
# ` copy <0/1>`: the data block exists and is not the array arg's buffer.
.macro COPY arg
    TXT " copy "
    movq 72(%rbx), %rax
    xorl %edi, %edi
    testq %rax, %rax
    jz .Lcp\@
    cmpq (\arg + SEA_ARR_DATA)(%rip), %rax
    setne %dil
.Lcp\@:
    call putdec
.endm
# ` data v0 .. v(n-1)`: n values of the data block as integers.
.macro DATAN n
    TXT " data"
    movq 72(%rbx), %r12
    xorl %r13d, %r13d
.Ldn\@:
    TXT " "
    cvttsd2si (%r12,%r13,8), %rdi
    call putdec
    incq %r13
    cmpq $\n, %r13
    jb .Ldn\@
.endm
.macro COUNTS
    TXT " live "
    movq sea_live(%rip), %rdi
    subq live0(%rip), %rdi
    call putdec
    TXT " freed "
    movq sea_freed(%rip), %rdi
    subq freed0(%rip), %rdi
    call putdec
.endm

    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    PROLOGUE
    movl $11, %edi                  # the labels
    xorl %esi, %esi
    call sea_str_i64
    movq %rax, gS1(%rip)
    movl $12, %edi
    xorl %esi, %esi
    call sea_str_i64
    movq %rax, gS2(%rip)
    movq sea_live(%rip), %rax
    movq %rax, live0(%rip)
    movq sea_freed(%rip), %rax
    movq %rax, freed0(%rip)
    movl $1, %edi                   # a 1 x 1 figure, one panel
    movl $1, %esi
    leaq EMP(%rip), %rdx
    movl $640, %ecx
    movl $480, %r8d
    xorl %r9d, %r9d
    call sea_figure
    movq %rax, gFIG(%rip)
    movq %rax, %rdi
    xorl %esi, %esi
    xorl %edx, %edx
    movl $1, %ecx
    movl $1, %r8d
    xorl %r9d, %r9d
    call sea_panel
    movq %rax, gA(%rip)

    # BAR: the cycle colour, labelled.
    BARC X3, H3, W05, gS1(%rip), EMP
    SRREC 0
    TXT "bar 0:"
    PF kind, 0
    PF ax, 8
    PH color, 16, 6
    PH width, 40, 16
    ISLAB gS1
    PF n, 56
    COPY X3
    DATAN 6
    ACYC
    TXT " nsr "
    movq gFIG(%rip), %rax
    movq 80(%rax), %rdi
    call putdec
    TXT "\n"
    # BAR: empty, a colour argument in mixed case, no label.
    movq $EMP, %rax
    BARC X0, X0, W1, %rax, CMIX
    SRREC 1
    TXT "bar 1:"
    PH color, 16, 6
    PF label, 48
    PF n, 56
    PF data, 72
    ACYC
    TXT "\n"
    # BARH: the next cycle colour, labelled.
    BARHC H3, W08, gS2(%rip), EMP
    SRREC 2
    TXT "barh 2:"
    PF kind, 0
    PH color, 16, 6
    PH width, 40, 16
    ISLAB gS2
    PF n, 56
    COPY H3
    DATAN 3
    ACYC
    TXT "\n"
    # CONTOUR: no colour (-1), labels, 4 levels.
    CONTC X3, Y2, Z23, 4, 1, EMP
    SRREC 3
    TXT "contour 3:"
    PF kind, 0
    PF color, 16
    PF n, 56
    PF m, 64
    PF levels, 80
    PF flag, 88
    PF label, 48
    COPY Z23
    DATAN 11
    ACYC
    TXT "\n"
    # CONTOUR: a colour argument, 1 level, no labels.
    CONTC X3, Y2, Z23, 1, 0, CGRN
    SRREC 4
    TXT "contour 4:"
    PH color, 16, 6
    PF levels, 80
    PF flag, 88
    ACYC
    TXT "\n"
    # CONTOUR: 3 x values, no y: a 0 x 3 Z, a block of x only.
    CONTC X3, X0, Z03, 2, 0, EMP
    SRREC 5
    TXT "contour 5:"
    PF n, 56
    PF m, 64
    DATAN 3
    TXT "\n"
    # IMAGE: colorbar, the data copied.
    IMGC X3, Y2, Z23, 1
    SRREC 6
    TXT "image 6:"
    PF kind, 0
    PF color, 16
    PF n, 56
    PF m, 64
    PF flag, 88
    PF label, 48
    COPY Z23
    DATAN 11
    ACYC
    TXT "\n"
    # IMAGE: empty, no block.
    IMGC X0, X0, Z00, 0
    SRREC 7
    TXT "image 7:"
    PF n, 56
    PF m, 64
    PF data, 72
    PF flag, 88
    TXT " nsr "
    movq gFIG(%rip), %rax
    movq 80(%rax), %rdi
    call putdec
    TXT "\n"
    # The arguments are untouched.
    TXT "args:"
    leaq X3(%rip), %rbx
    PF X3rows, SEA_ARR_ROWS
    TXT " X3_0 "
    movq SEA_ARR_DATA(%rbx), %rax
    cvttsd2si (%rax), %rdi
    call putdec
    leaq Z23(%rip), %rbx
    PF Zrows, SEA_ARR_ROWS
    PF Zcols, SEA_ARR_COLS
    TXT "\n"
    # Freed: the Axes, then the figure with every block and label.
    movq gA(%rip), %rax
    REL %rax
    TXT "release A:"
    COUNTS
    TXT "\n"
    movq gFIG(%rip), %rax
    REL %rax
    TXT "release fig:"
    COUNTS
    TXT " S1 "
    movq gS1(%rip), %rax
    movq (%rax), %rdi
    call putdec
    TXT " S2 "
    movq gS2(%rip), %rax
    movq (%rax), %rdi
    call putdec
    TXT "\n"
    movq gS1(%rip), %rax
    REL %rax
    movq gS2(%rip), %rax
    REL %rax
    EPILOGUE
    .size sea_main, . - sea_main

    .section .rodata
    .p2align 3
W05:    .double 0.5
W08:    .double 0.8
W1:     .double 1.0
    .section .data.rel.ro,"aw",@progbits
    SSTR EMP, ""
    SSTR CMIX, "#Ab12Cd"
    SSTR CGRN, "#00FF00"
    VEC X0, 0
    VEC X3, 3
    .double 2.0, 0.0, 1.0
    VEC H3, 3
    .double 1.0, 2.0, 3.0
    VEC Y2, 2
    .double 0.0, 1.0
    MAT Z23, 2, 3                   # [1 2 3; 4 5 6], column-major
    .double 1, 4, 2, 5, 3, 6
    MAT Z03, 0, 3
    MAT Z00, 0, 0
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
