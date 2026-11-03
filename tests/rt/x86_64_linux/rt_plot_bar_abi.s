# sea/tests/rt/x86_64_linux/rt_plot_bar_abi.s -- the ABI of the four entries of rt_plot2.s and of SAVE_SVG drawing their series (DESIGN.md 2.14.5 "Shared rules": ABI, Stack): each call is made with %rbx %rbp %r12-%r15 holding known patterns and the 128 KiB below %rsp guard-filled; afterwards those registers, %rsp, MXCSR's control bits and the direction flag must be unchanged and the call, its callees included (sea_alloc, the PNG writer, snprintf through sea_fmt_num, sea_file_put), must have written at most SEA_STACK_MARGIN bytes below %rsp. CONTOUR's colour and site travel in its two stack arguments. The figure is 1 x 2: a bar series and a contour with labels and the map colours, an image with its colorbar and a barh series on the twin (mr 120), a legend with both bar entries; the second panel an image with a NaN cell, a value of 1e300 and its colorbar and a contour in one colour. SAVE_SVG writes all of it. Each case prints `<entry>: ok`; then every handle is released (heap check).
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
args:   .zero 8 * 6                 # the integer arguments of the next call
fargs:  .zero 8 * 2                 # its f64 arguments (%xmm0, %xmm1)
stkarg: .quad 0                     # the first stack argument (CONTOUR's color)
stkarg2: .quad 0                    # the second (CONTOUR's site)
res:    .quad 0                     # %rax of the last call
callsp: .quad 0                     # %rsp at the call
mx0:    .long 0                     # MXCSR before the call
mx1:    .long 0                     # MXCSR after the call
depth:  .quad 0                     # bytes the call wrote below its return slot
gFIG:   .quad 0                     # the figure
gA0:    .quad 0                     # the axes: panel (0, 0)
gA1:    .quad 0                     # panel (0, 1)
gTW:    .quad 0                     # the twin of gA0

    .text
# probe -- call a routine under the ABI check.
#   Inputs  : %rdi = the routine; args, fargs, stkarg and stkarg2 its arguments
#   Outputs : %rax = 0, or the sum of: 1 %rsp changed, 2 MXCSR's control
#             bits changed, 4 one of %rbx %rbp %r12-%r15 changed, 8 the
#             direction flag set, 16 the call wrote more than
#             SEA_STACK_MARGIN bytes below its return slot; res = %rax of
#             the call, depth = the bytes written below the return slot
#   Clobbers: the caller-saved registers
#   Callee-saved used: all of them hold the test patterns during the call
#   Frame   : 8 (%rbp) + 40 (callee-saved) + 24; the stack arguments at
#             0(%rsp) and 8(%rsp) at the call (8(%rsp) and 16(%rsp) on the routine's entry)
    .p2align 4
probe:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $24, %rsp                  # %rsp = 0 (mod 16)
    movq %rdi, %r11                 # the routine
    movq stkarg(%rip), %rax
    movq %rax, 0(%rsp)              # the stack arguments
    movq stkarg2(%rip), %rax
    movq %rax, 8(%rsp)
    leaq -8-GUARD_BYTES(%rsp), %rdi # the guard: GUARD_BYTES ending at the return slot
    movl $GUARD_BYTES/8, %ecx
    movabsq $GUARD_WORD, %rax
    cld
    rep stosq
    stmxcsr mx0(%rip)
    movq args(%rip), %rdi           # the arguments
    movq (args + 8)(%rip), %rsi
    movq (args + 16)(%rip), %rdx
    movq (args + 24)(%rip), %rcx
    movq (args + 32)(%rip), %r8
    movq (args + 40)(%rip), %r9
    movsd fargs(%rip), %xmm0
    movsd (fargs + 8)(%rip), %xmm1
    movq %rsp, callsp(%rip)
    movabsq $PAT_RBX, %rbx
    movabsq $PAT_RBP, %rbp
    movabsq $PAT_R12, %r12
    movabsq $PAT_R13, %r13
    movabsq $PAT_R14, %r14
    movabsq $PAT_R15, %r15
    call *%r11
    movq %rax, res(%rip)
    pushfq
    popq %r8                        # RFLAGS after the call
    stmxcsr mx1(%rip)
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
2:  cmpq callsp(%rip), %rsp
    je 3f
    orl $1, %eax
    movq callsp(%rip), %rsp
3:  movl mx0(%rip), %ecx
    xorl mx1(%rip), %ecx
    testl $MXCSR_CTL, %ecx
    jz 4f
    orl $2, %eax
4:  testq $RFLAGS_DF, %r8
    jz 5f
    orl $8, %eax
    cld
5:  movq callsp(%rip), %rdx         # the depth: the lowest guard word changed
    leaq -8-GUARD_BYTES(%rdx), %rdi
    leaq -8(%rdx), %rsi
    movabsq $GUARD_WORD, %rcx
6:  cmpq %rsi, %rdi
    jae 7f
    cmpq (%rdi), %rcx
    jne 7f
    addq $8, %rdi
    jmp 6b
7:  subq %rdi, %rsi
    movq %rsi, depth(%rip)
    cmpq $SEA_STACK_MARGIN, %rsi
    jbe 8f
    orl $16, %eax
8:  addq $24, %rsp                  # %rsp is the call site's again
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

# The argument setters: integer argument i from a movq source, f64
# argument i from a label, the stack argument.
.macro IA i, src
    movq \src, %rax
    movq %rax, (args + 8 * \i)(%rip)
.endm
.macro FA i, lab
    movsd \lab(%rip), %xmm0
    movsd %xmm0, (fargs + 8 * \i)(%rip)
.endm
.macro SA src
    movq \src, %rax
    movq %rax, stkarg(%rip)
.endm
# CASE text, routine: probe the routine and print `<text>: ok`, or
# `<text>: bad <bits>`. With SHOW_DEPTH defined (a scratch build that
# measures DESIGN.md 2.14.5's deepest path) the depth follows.
.macro CASE text, routine
    leaq \routine(%rip), %rdi
    call probe
    movq %rax, %r12
    TXT "\text: "
    testq %r12, %r12
    jnz .Lcase_bad\@
    TXT "ok"
    jmp .Lcase_end\@
.Lcase_bad\@:
    TXT "bad "
    movq %r12, %rdi
    call putdec
.Lcase_end\@:
.ifdef SHOW_DEPTH
    TXT " "
    movq depth(%rip), %rdi
    call putdec
.endif
    TXT "\n"
.endm

.macro SA2 src
    movq \src, %rax
    movq %rax, stkarg2(%rip)
.endm

    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    PROLOGUE
    IA 0, $1
    IA 1, $2
    IA 2, $EMP
    IA 3, $640
    IA 4, $480
    IA 5, $0
    CASE "figure", sea_figure
    movq res(%rip), %rax
    movq %rax, gFIG(%rip)
    IA 0, gFIG(%rip)
    IA 1, $0
    IA 2, $0
    IA 3, $1
    IA 4, $1
    IA 5, $0
    CASE "panel", sea_panel
    movq res(%rip), %rax
    movq %rax, gA0(%rip)
    IA 2, $1
    CASE "panel", sea_panel
    movq res(%rip), %rax
    movq %rax, gA1(%rip)
    IA 0, gA0(%rip)
    IA 1, $0
    CASE "twin_y", sea_twin_y
    movq res(%rip), %rax
    movq %rax, gTW(%rip)
    # BAR on the base, labelled, the cycle colour.
    IA 0, gA0(%rip)
    IA 1, $VX4
    IA 2, $VH4
    IA 3, $LAB1
    IA 4, $EMP
    IA 5, $0
    FA 0, W08
    CASE "bar", sea_bar
    # BARH on the twin, labelled, a colour argument.
    IA 0, gTW(%rip)
    IA 1, $VH4
    IA 2, $LAB2
    IA 3, $GRN
    IA 4, $0
    FA 0, W05
    CASE "barh", sea_barh
    # CONTOUR on the base: 3 levels, labels, the map colours.
    IA 0, gA0(%rip)
    IA 1, $VX3
    IA 2, $VY2
    IA 3, $Z23
    IA 4, $3
    IA 5, $1
    SA $EMP
    SA2 $0
    CASE "contour", sea_contour
    # IMAGE on the base with its colorbar.
    IA 3, $Z23
    IA 4, $1
    IA 5, $0
    CASE "image", sea_image
    # IMAGE on the second panel: a NaN cell, a colorbar.
    IA 0, gA1(%rip)
    IA 3, $Z23N
    CASE "image", sea_image
    # CONTOUR on the second panel: 2 levels in one colour.
    IA 3, $Z23
    IA 4, $2
    IA 5, $1
    SA $BLU
    SA2 $0
    CASE "contour", sea_contour
    IA 0, gA0(%rip)
    IA 1, $BEST
    IA 2, $0
    CASE "legend", sea_legend
    IA 0, gFIG(%rip)
    IA 1, $PATH
    IA 2, $0
    CASE "save_svg", sea_save_svg
    # Every handle and the figure released: nothing is left.
    movq gTW(%rip), %rax
    REL %rax
    movq gA1(%rip), %rax
    REL %rax
    movq gA0(%rip), %rax
    REL %rax
    movq gFIG(%rip), %rax
    REL %rax
    TXT "live "
    movq sea_live(%rip), %rdi
    call putdec
    TXT "\n"
    EPILOGUE
    .size sea_main, . - sea_main

    .section .rodata
    .p2align 3
W05:    .double 0.5
W08:    .double 0.8
    .data
    SSTR EMP, ""
    SSTR LAB1, "bars"
    SSTR LAB2, "horizontal"
    SSTR GRN, "#00ff00"
    SSTR BLU, "#0000FF"
    SSTR BEST, "best"
    SSTR PATH, "f.svg"
    VEC VX4, 4
    .double 0.0, 1.0, 3.0, 4.0
    VEC VH4, 4
    .double 2.0, -1.0, 0.0, 3.5
    VEC VX3, 3
    .double 0.0, 1.0, 2.0
    VEC VY2, 2
    .double 0.0, 1.0
    .p2align 6
Z23:                                # [0 1 2; 3 4 6], column-major
    .quad SEA_RC_STATIC
    .byte SEA_TAG_ARRAY, SEA_EK_F64, 2, 0, 0, 0, 0, 0
    .quad 2, 3, 6, Z23 + SEA_ARR_SIZE, 8, 0
    .double 0.0, 3.0, 1.0, 4.0, 2.0, 6.0
    .p2align 6
Z23N:                               # [0 NaN 2; 3 4 1e300]: colorbar ticks of a huge range (%g)
    .quad SEA_RC_STATIC
    .byte SEA_TAG_ARRAY, SEA_EK_F64, 2, 0, 0, 0, 0, 0
    .quad 2, 3, 6, Z23N + SEA_ARR_SIZE, 8, 0
    .double 0.0, 3.0
    .quad 0x7FF8000000000000
    .double 4.0, 2.0, 1.0e300
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
