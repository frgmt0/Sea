# sea/tests/rt/x86_64_linux/rt_plot_svg_cat.s -- category labels under limits rules 1 and 6, applied in their numbered order (DESIGN.md 2.14.6 "Limits" 1, 2, 5, 6, "Tick labels"; L-kk): a 344 x 172 figure, two panels of 100 x 100. p0 has x labels a, b, c and xlim(0, 2): rule 1 comes first, so its x ticks are the numeric step-5 ticks of [0, 2] (s = 0.5: 0.0 .. 2.0), not the labels. p1 has the same labels and no limits (rule 2: -0.5 .. 2.5) and axis_equal over y data 0 .. 4 (ticks 0 .. 4, s = 1): uy = 0.04 >= ux = 0.03, so rule 6 changes the category x axis to -1 .. 3 with explicit-limit numeric ticks -1 .. 3. The file t.svg is printed byte for byte, derived by hand; then no object is left.
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
rbuf:   .zero 8192
gA1:    .zero 8
    .text
    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    PROLOGUE
    # figure(1, 2, "", 344, 172)
    movl $1, %edi
    movl $2, %esi
    leaq EMP(%rip), %rdx
    movl $344, %ecx
    movl $172, %r8d
    xorl %r9d, %r9d
    call sea_figure
    movq %rax, %rbx                 # %rbx = the figure
    # p0 = panel(0, 0): x_ticks(["a", "b", "c"]), xlim(0, 2), plot([0, 1, 2], [0, 1, 2])
    movq %rbx, %rdi
    xorl %esi, %esi
    xorl %edx, %edx
    movl $1, %ecx
    movl $1, %r8d
    xorl %r9d, %r9d
    call sea_panel
    movq %rax, %r12                 # %r12 = p0
    movq %r12, %rdi
    leaq LABS(%rip), %rsi
    xorl %edx, %edx
    call sea_x_ticks
    movq %r12, %rdi
    movsd F0(%rip), %xmm0
    movsd F2(%rip), %xmm1
    xorl %esi, %esi
    call sea_xlim
    movq $0, 0(%rsp)                # the site, PLOT's stack argument
    movq %r12, %rdi
    leaq VX(%rip), %rsi
    leaq VX(%rip), %rdx
    leaq STY(%rip), %rcx
    leaq EMP(%rip), %r8
    leaq EMP(%rip), %r9
    movsd F1(%rip), %xmm0
    call sea_plot
    # p1 = panel(0, 1): x_ticks(["a", "b", "c"]), plot([0, 1, 2], [0, 2, 4]), axis_equal
    movq %rbx, %rdi
    xorl %esi, %esi
    movl $1, %edx
    movl $1, %ecx
    movl $1, %r8d
    xorl %r9d, %r9d
    call sea_panel
    movq %rax, %r13                 # %r13 = p1
    movq %r13, %rdi
    leaq LABS(%rip), %rsi
    xorl %edx, %edx
    call sea_x_ticks
    movq $0, 0(%rsp)
    movq %r13, %rdi
    leaq VX(%rip), %rsi
    leaq VY(%rip), %rdx
    leaq STY(%rip), %rcx
    leaq EMP(%rip), %r8
    leaq EMP(%rip), %r9
    movsd F1(%rip), %xmm0
    call sea_plot
    movq %r13, %rdi
    call sea_axis_equal
    # save_svg(fig, "t.svg")
    movq %rbx, %rdi
    leaq PATH(%rip), %rsi
    xorl %edx, %edx
    call sea_save_svg
    REL %r13
    REL %r12
    REL %rbx
    # The file, byte for byte, on standard output.
    leaq cpath(%rip), %rdi
    xorl %esi, %esi                 # O_RDONLY
    xorl %eax, %eax
    call open@PLT
    movl %eax, %r13d
    movl %r13d, %edi
    leaq rbuf(%rip), %rsi
    movl $8192, %edx
    call read@PLT
    movq %rax, %r14
    movl %r13d, %edi
    call close@PLT
    leaq rbuf(%rip), %rdi
    movq %r14, %rsi
    call sea_out_write
    TXT "live "
    movq sea_live(%rip), %rdi
    call putdec
    TXT "\n"
    EPILOGUE
    .size sea_main, . - sea_main

    .section .rodata
    .p2align 3
F0:     .double 0.0
F1:     .double 1.0
F2:     .double 2.0
cpath:  .asciz "t.svg"
    .data
    SSTR EMP, ""
    SSTR STY, "-"
    SSTR PATH, "t.svg"
    SSTR LA, "a"
    SSTR LB, "b"
    SSTR LC, "c"
    .p2align 6
LABS:                               # a static str[] vector of 3
    .quad SEA_RC_STATIC
    .byte SEA_TAG_ARRAY, SEA_EK_STR, 1, 0, 0, 0, 0, 0
    .quad 3, 1, 3, LABS + SEA_ARR_SIZE, 8, 0
    .quad LA, LB, LC
    VEC VX, 3
    .double 0.0, 1.0, 2.0
    VEC VY, 3
    .double 0.0, 2.0, 4.0
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
