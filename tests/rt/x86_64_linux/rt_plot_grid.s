# sea/tests/rt/x86_64_linux/rt_plot_grid.s -- PANEL's occupancy map and the axes table (DESIGN.md 2.14.5 PANEL, 2.14.6 "Objects"): a panel spanning all 64 columns of a 1 x 64 grid (every bit of word 0), the last cell of a 64 x 64 grid (bit 63 of word 63) and columns 62 - 63 of its rows 0 - 62, and 16 panels of a 4 x 4 grid (the axes table doubling from 8 to 16 records, each record keeping its base index, cell and spans). All handles released: no object left.
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
# Figure fields read here (DESIGN.md 2.14.6, L-kw): 56 nax, 64 axcap,
# 72 axes table, 192 + 8r occupancy word r; axes record (256 bytes) 8
# base, 24 row, 32 col, 40 rowspan, 48 colspan.
    .bss
    .p2align 3
gF:     .zero 8 * 3                 # the three figures
gH:     .zero 8 * 32                # every Axes handle made
gN:     .zero 8                     # handles made
    .text

# newfig -- gF[%rdi] = figure(%rsi, %rdx, "", 960, 720). Frame 56.
    .p2align 4
newfig:
    PROLOGUE
    movq %rdi, %rbx
    movq %rsi, %rdi
    movq %rdx, %rsi
    leaq EMP(%rip), %rdx
    movl $960, %ecx
    movl $720, %r8d
    xorl %r9d, %r9d
    call sea_figure
    leaq gF(%rip), %rcx
    movq %rax, (%rcx,%rbx,8)
    EPILOGUE
# panel -- a panel of gF[%rdi] at (%rsi, %rdx) spanning %rcx x %r8; the
# handle is kept in gH. Frame 56.
    .p2align 4
panel:
    PROLOGUE
    leaq gF(%rip), %rax
    movq (%rax,%rdi,8), %rdi
    xorl %r9d, %r9d
    call sea_panel
    movq gN(%rip), %rcx
    leaq gH(%rip), %rdx
    movq %rax, (%rdx,%rcx,8)
    incq gN(%rip)
    EPILOGUE
# occ -- print ` occ<r> <word r of gF[%rdi]>` for r = %rsi. Frame 56.
    .p2align 4
occ:
    PROLOGUE
    movq %rdi, %rbx
    movq %rsi, %r12
    TXT " occ"
    movq %r12, %rdi
    call putdec
    TXT " "
    leaq gF(%rip), %rax
    movq (%rax,%rbx,8), %rax
    movq 192(%rax,%r12,8), %rdi
    call putdec
    EPILOGUE

    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    PROLOGUE
    # A 1 x 64 grid and one panel spanning all 64 columns.
    xorl %edi, %edi
    movl $1, %esi
    movl $64, %edx
    call newfig
    xorl %edi, %edi
    xorl %esi, %esi
    xorl %edx, %edx
    movl $1, %ecx
    movl $64, %r8d
    call panel
    TXT "1x64:"
    xorl %edi, %edi
    xorl %esi, %esi
    call occ
    TXT "\n"
    # A 64 x 64 grid: the last cell, then columns 62 - 63 of rows 0 - 62.
    movl $1, %edi
    movl $64, %esi
    movl $64, %edx
    call newfig
    movl $1, %edi
    movl $63, %esi
    movl $63, %edx
    movl $1, %ecx
    movl $1, %r8d
    call panel
    movl $1, %edi
    xorl %esi, %esi
    movl $62, %edx
    movl $63, %ecx
    movl $2, %r8d
    call panel
    TXT "64x64:"
    movl $1, %edi
    xorl %esi, %esi
    call occ
    movl $1, %edi
    movl $62, %esi
    call occ
    movl $1, %edi
    movl $63, %esi
    call occ
    TXT "\n"
    # A 4 x 4 grid filled cell by cell, rows first: the axes table
    # doubles past 8 records; every record keeps its cell.
    movl $2, %edi
    movl $4, %esi
    movl $4, %edx
    call newfig
    xorl %r12d, %r12d               # cell number
1:  movl $2, %edi
    movq %r12, %rsi
    shrq $2, %rsi                   # row
    movq %r12, %rdx
    andq $3, %rdx                   # column
    movl $1, %ecx
    movl $1, %r8d
    call panel
    incq %r12
    cmpq $16, %r12
    jb 1b
    TXT "4x4:"
    movq (gF + 16)(%rip), %rbx
    TXT " nax "
    movq 56(%rbx), %rdi
    call putdec
    TXT " axcap "
    movq 64(%rbx), %rdi
    call putdec
    TXT " wrong "
    xorl %r13d, %r13d               # records whose fields differ from their cell
    xorl %r12d, %r12d
2:  movq %r12, %rax
    shlq $8, %rax
    addq 72(%rbx), %rax
    movq %r12, %rcx
    shrq $2, %rcx
    movq %r12, %rdx
    andq $3, %rdx
    xorl %r8d, %r8d
    cmpq 8(%rax), %r12
    setne %r8b
    orl %r8d, %r13d
    cmpq 24(%rax), %rcx
    setne %r8b
    orl %r8d, %r13d
    cmpq 32(%rax), %rdx
    setne %r8b
    orl %r8d, %r13d
    cmpq $1, 40(%rax)
    setne %r8b
    orl %r8d, %r13d
    cmpq $1, 48(%rax)
    setne %r8b
    orl %r8d, %r13d
    incq %r12
    cmpq $16, %r12
    jb 2b
    movq %r13, %rdi
    call putdec
    movl $2, %edi
    xorl %esi, %esi
    call occ
    movl $2, %edi
    movl $3, %esi
    call occ
    movl $2, %edi
    movl $4, %esi
    call occ
    TXT "\n"
    # Release the figures, then every handle: nothing is left.
    xorl %r12d, %r12d
3:  leaq gF(%rip), %rax
    movq (%rax,%r12,8), %rax
    REL %rax
    incq %r12
    cmpq $3, %r12
    jb 3b
    xorl %r12d, %r12d
4:  leaq gH(%rip), %rax
    movq (%rax,%r12,8), %rax
    REL %rax
    incq %r12
    cmpq gN(%rip), %r12
    jb 4b
    TXT "live "
    movq sea_live(%rip), %rdi
    call putdec
    TXT "\n"
    EPILOGUE
    .size sea_main, . - sea_main

    .section .data.rel.ro,"aw",@progbits
    SSTR EMP, ""
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
