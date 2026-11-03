# sea/tests/rt/x86_64_linux/rt_plot_ticks.s -- ported from tests/rt/arm64_macos/rt_plot_ticks.s with the same expected bytes (target-independent): the tick rules of DESIGN.md 2.14.6 (limits rules 1, 2, 4, 5, tick labels with `%.{p}f`, `%g` for steps >= 1e6 or < 1e-4, Decision 142's `%.{q}g`): six panels with the ranges 0 .. 6 and 0.1 .. 0.95; -3 .. 7 and a zero range at 0; a zero range at 5 and 0 .. 3e6; 0 .. 3e-5 and 1 .. 1.00001 (repeated `%g` texts: `%.7g`); categories a b c with no data and explicit limits 0.5 .. 3.7; 1e12 .. 1e12 + 5e6 (`%.7g`) and no finite y (0 .. 1). Every Axes value is dropped before save_svg (L-ke). The SVG is filtered: `panel` per panel group, then `xtick TEXT` / `ytick TEXT` per tick label. The expected texts were derived with a Python transcription of the rules, operation for operation (not from the runtime)
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

# ---- the helpers of the tests ported from tests/rt/arm64_macos --------
# A static dynamic-f64 vector of n elements; the element bit patterns
# follow the macro (n .quad values).
.macro FVEC label, n
    .p2align 6
\label:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_ARRAY, SEA_EK_F64, 1, 0, 0, 0, 0, 0
    .quad \n, 1, \n, \label + SEA_ARR_SIZE, 8, 0
.endm
# A static str vector of n elements; the string pointers follow.
.macro SVEC label, n
    .p2align 6
\label:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_ARRAY, SEA_EK_STR, 1, 0, 0, 0, 0, 0
    .quad \n, 1, \n, \label + SEA_ARR_SIZE, 8, 0
.endm

    .bss
    .p2align 4
dumpbuf: .zero 1048576
dumplen: .zero 8
    .text
# readall -- read the whole file at the NUL-terminated path %rdi (at most
#   1 MiB) into dumpbuf; dumplen = its length. Clobbers the caller-saved
#   registers. Callee-saved used: %rbx (descriptor). Frame: 8 (%rbp) +
#   8 (%rbx).
    .p2align 4
readall:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp
    xorl %esi, %esi                 # O_RDONLY
    xorl %eax, %eax
    call open@PLT
    movl %eax, %ebx
    movq $0, dumplen(%rip)
1:  movl %ebx, %edi                 # read until end of file
    leaq dumpbuf(%rip), %rsi
    addq dumplen(%rip), %rsi
    movl $1048576, %edx
    subq dumplen(%rip), %rdx
    call read@PLT
    testq %rax, %rax
    jle 2f
    addq %rax, dumplen(%rip)
    jmp 1b
2:  movl %ebx, %edi
    call close@PLT
    addq $8, %rsp
    popq %rbx
    popq %rbp
    ret

# dump -- print the whole file at the NUL-terminated path %rdi.
#   Clobbers the caller-saved registers. Frame: 8 (%rbp) + 8.
    .p2align 4
dump:
    pushq %rbp
    movq %rsp, %rbp
    call readall
    leaq dumpbuf(%rip), %rdi
    movq dumplen(%rip), %rsi
    call sea_out_write
    popq %rbp
    ret

# ticks -- print the panel and tick-label lines of the file at %rdi:
#   `panel` for each line starting `<g class="panel"`, `xtick T` / `ytick
#   T` for each line starting `<text class="xtick"` / `<text
#   class="ytick"` (T between the first `>` and `</text>`). Clobbers the
#   caller-saved registers. Callee-saved used: %rbx = cursor, %r12 = end,
#   %r13 = line start. Frame: 8 (%rbp) + 24 + 8.
    .p2align 4
ticks:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    subq $8, %rsp
    call readall
    leaq dumpbuf(%rip), %rbx
    movq %rbx, %r12
    addq dumplen(%rip), %r12
1:  cmpq %r12, %rbx
    jae 9f
    movq %rbx, %r13                 # the line start
2:  movb (%rbx), %al                # to the end of the line
    incq %rbx
    cmpb $10, %al
    jne 2b
    movq %r13, %rdi
    leaq p_panel(%rip), %rsi
    movl $16, %edx
    call strncmp@PLT
    testl %eax, %eax
    jnz 3f
    TXT "panel\n"
    jmp 1b
3:  movq %r13, %rdi
    leaq p_xtick(%rip), %rsi
    movl $19, %edx
    call strncmp@PLT
    testl %eax, %eax
    jz 4f
    movq %r13, %rdi
    leaq p_ytick(%rip), %rsi
    movl $19, %edx
    call strncmp@PLT
    testl %eax, %eax
    jnz 1b
    TXT "ytick "
    jmp 5f
4:  TXT "xtick "
5:  movq %r13, %rdi                 # the text: after the first `>`
6:  movb (%rdi), %al
    incq %rdi
    cmpb $'>', %al
    jne 6b
    movq %rbx, %rsi
    subq %rdi, %rsi
    subq $8, %rsi                   # without `</text>` and LF
    call sea_out_write
    TXT "\n"
    jmp 1b
9:  addq $8, %rsp
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret
    .section .rodata
p_panel: .asciz "<g class=\"panel\""
p_xtick: .asciz "<text class=\"xtick\""
p_ytick: .asciz "<text class=\"ytick\""
    .text
# ---- the calls of the ported tests (operands: $imm, labels by leaq) ----
.macro FIGURE nr, nc, name, w, h
    movl $\nr, %edi
    movl $\nc, %esi
    leaq \name(%rip), %rdx
    movl $\w, %ecx
    movl $\h, %r8d
    xorl %r9d, %r9d
    call sea_figure
.endm
# PANEL fig (a register other than the argument registers), r, c
.macro PANEL fig, r, c
    movq \fig, %rdi
    movl $\r, %esi
    movl $\c, %edx
    movl $1, %ecx
    movl $1, %r8d
    xorl %r9d, %r9d
    call sea_panel
.endm
# PLOTW ax, x, y, style, label: width 1.0, color "", site 0 (the stack
# argument at 0(%rsp)).
.macro PLOTW ax, x, y, sty, lab
    movq $0, 0(%rsp)
    movq \ax, %rdi
    leaq \x(%rip), %rsi
    leaq \y(%rip), %rdx
    leaq \sty(%rip), %rcx
    leaq \lab(%rip), %r8
    leaq EMPTY(%rip), %r9
    movsd ONE(%rip), %xmm0
    call sea_plot
.endm
    .section .rodata
    .p2align 3
ONE:    .double 1.0
    .text

# ---- the test ---------------------------------------------------------
# PANELPLOT c, x, y: panel(fig, 0, c), plot(ax, x, y, "-"), the handle
# dropped (L-ke: the figure keeps the record).
.macro PANELPLOT c, x, y
    PANEL %rbx, 0, \c
    movq %rax, %r12
    PLOTW %r12, \x, \y, DASH, EMPTY
    REL %r12
.endm
    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    PROLOGUE
    # figure(1, 6, width: 2400, height: 400)
    FIGURE 1, 6, EMPTY, 2400, 400
    movq %rax, %rbx
    PANELPLOT 0, X0, Y0
    PANELPLOT 1, X1, Y1
    PANELPLOT 2, X2, Y2
    PANELPLOT 3, X3, Y3
    # panel 4: x labels a b c, no data, ylim(0.5, 3.7)
    PANEL %rbx, 0, 4
    movq %rax, %r12
    movq %r12, %rdi
    leaq CATS(%rip), %rsi
    xorl %edx, %edx
    call sea_x_ticks
    movq %r12, %rdi
    movsd LO4(%rip), %xmm0
    movsd HI4(%rip), %xmm1
    xorl %esi, %esi
    call sea_ylim
    REL %r12
    PANELPLOT 5, X5, NAN2
    movq %rbx, %rdi
    leaq PATH(%rip), %rsi
    xorl %edx, %edx
    call sea_save_svg
    REL %rbx
    leaq cpath(%rip), %rdi
    call ticks
    EPILOGUE
    .size sea_main, . - sea_main

    .section .rodata
    .p2align 3
LO4:    .quad 0x3FE0000000000000
HI4:    .quad 0x400D99999999999A
cpath:  .asciz "k.svg"
    .section .data.rel.ro,"aw",@progbits
    SSTR EMPTY, ""
    SSTR DASH, "-"
    SSTR PATH, "k.svg"
    SSTR LA, "a"
    SSTR LB, "b"
    SSTR LC, "c"
    SVEC CATS, 3
    .quad LA, LB, LC
    FVEC X0, 2
    .quad 0x0000000000000000, 0x4018000000000000
    FVEC Y0, 2
    .quad 0x3FB999999999999A, 0x3FEE666666666666
    FVEC X1, 2
    .quad 0xC008000000000000, 0x401C000000000000
    FVEC Y1, 2
    .quad 0x0000000000000000, 0x0000000000000000
    FVEC X2, 2
    .quad 0x4014000000000000, 0x4014000000000000
    FVEC Y2, 2
    .quad 0x0000000000000000, 0x4146E36000000000
    FVEC X3, 2
    .quad 0x0000000000000000, 0x3EFF75104D551D69
    FVEC Y3, 2
    .quad 0x3FF0000000000000, 0x3FF0000A7C5AC472
    FVEC X5, 2
    .quad 0x426D1A94A2000000, 0x426D1A9E2B680000
    FVEC NAN2, 2
    .quad 0x7FF8000000000000, 0x7FF8000000000000
    .section .data.rel.ro,"aw",@progbits
    .p2align 3
    .globl sea_sites
sea_sites:
    .quad .Lsite_file
    .quad 7
.Lsite_file:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 5
    .ascii "p.sea"

    .section .note.GNU-stack,"",@progbits
