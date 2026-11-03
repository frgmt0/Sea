# sea/tests/rt/x86_64_linux/rt_plot_err_ylim_inf.s -- YLIM(-Inf, 0): AXIS_LIMITS (lo not finite) (DESIGN.md 2.14.2 "When things happen", 2.14.5; L-kg): the failing call at site 1 reports at plot.sea:16, status 1
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

# ---- the calls of the error tests -------------------------------------
# Each macro makes one runtime call with immediate integer arguments
# (strings and vectors by label) at the site given; the results of
# FIG and PAN are kept in %rbx (the figure) and %r12 (the axes).
.macro FIG nr, nc, w, h, site
    movq $\nr, %rdi
    movq $\nc, %rsi
    leaq EMP(%rip), %rdx
    movq $\w, %rcx
    movq $\h, %r8
    movq $\site, %r9
    call sea_figure
    movq %rax, %rbx
.endm
.macro PAN r, c, rs, cs, site
    movq %rbx, %rdi
    movq $\r, %rsi
    movq $\c, %rdx
    movq $\rs, %rcx
    movq $\cs, %r8
    movq $\site, %r9
    call sea_panel
    movq %rax, %r12
.endm
# PLOT x, y, style, width (an f64 label), color, site.
.macro PLOT x, y, sty, w, col, site
    movq $\site, 0(%rsp)            # PLOT's stack argument
    movq %r12, %rdi
    leaq \x(%rip), %rsi
    leaq \y(%rip), %rdx
    leaq \sty(%rip), %rcx
    leaq EMP(%rip), %r8
    leaq \col(%rip), %r9
    movsd \w(%rip), %xmm0
    call sea_plot
.endm
# XLINE x (an f64 label), style, color, site.
.macro XLINE x, sty, col, site
    movq %r12, %rdi
    movsd \x(%rip), %xmm0
    leaq \sty(%rip), %rsi
    leaq \col(%rip), %rdx
    movq $\site, %rcx
    call sea_xline
.endm
# LIM entry (sea_xlim or sea_ylim), lo, hi (f64 labels), site.
.macro LIM entry, lo, hi, site
    movq %r12, %rdi
    movsd \lo(%rip), %xmm0
    movsd \hi(%rip), %xmm1
    movq $\site, %rsi
    call \entry
.endm
.macro LEG loc, site
    movq %r12, %rdi
    leaq \loc(%rip), %rsi
    movq $\site, %rdx
    call sea_legend
.endm
.macro SAVE path, site
    movq %rbx, %rdi
    leaq \path(%rip), %rsi
    movq $\site, %rdx
    call sea_save_svg
.endm

# ---- the test ---------------------------------------------------------
.equ SITE1_LINE, 16
    .text
    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    PROLOGUE
    TXT "begin\n"
    FIG 1, 1, 640, 480, 0
    PAN 0, 0, 1, 1, 0
    LIM sea_ylim, FMINF, F0, 1
    TXT "returned\n"
    EPILOGUE
    .size sea_main, . - sea_main

    .section .rodata
    .p2align 3
F0:     .double 0.0
F1:     .double 1.0
F2:     .double 2.0
FNAN:   .quad 0x7FF8000000000000
FMINF:  .quad 0xFFF0000000000000
    .section .data.rel.ro,"aw",@progbits
    SSTR EMP, ""
    SSTR SOLID, "-"
    SSTR STY1, "-x+"
    SSTR STY2, "--o"
    SSTR STYQ, "q"
    SSTR COL1, "#12345"
    SSTR LOCT, "top"
    SSTR PATHM, "missing/a.svg"
    VEC V2, 2
    .double 0.0, 1.0
    VEC V4, 4
    .double 0.0, 1.0, 2.0, 3.0
    VEC V5, 5
    .double 0.0, 1.0, 2.0, 3.0, 4.0
    .p2align 3
    .globl sea_sites
sea_sites:
    .quad .Lsite_file
    .quad 1
    .quad .Lsite_file
    .quad SITE1_LINE
.Lsite_file:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 8
    .ascii "plot.sea"

    .section .note.GNU-stack,"",@progbits
