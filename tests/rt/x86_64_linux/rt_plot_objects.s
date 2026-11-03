# sea/tests/rt/x86_64_linux/rt_plot_objects.s -- the Figure and Axes objects and the entries that change them (DESIGN.md 2.14.5, 2.14.6 "Objects", "Style and colour", "Freeing"; L-ke, L-kf, L-kh, L-ki, L-km, L-lb): FIGURE (count 1, tag 3, fields, the name retained, both tables of 8 records, the rest zero), PANEL (records, occupancy bits, the handle retaining the figure), TWIN_Y (a new twin record with the base's row, col and spans and cycle index 1; the same record again from the base and from the twin), PLOT and XLINE (record fields, colour from the argument, the style letter or the cycle, which advances only in the last case and wraps after seven; the data copied; an empty series without a block; the table doubling past 8), the property entries (the pair's fields in the base record, the own y-axis's in the twin), X_TICKS/Y_TICKS (each label retained, a replaced list released, an empty list back to numeric), and sea_free of both tags (live and freed counts, the figure freed with its last handle, every retained string released). Heap check: no object left.
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
# The private layouts read here (DESIGN.md 2.14.6 "Objects", L-kw):
# Figure 16 nrows 24 ncols 32 w 40 h 48 name 56 nax 64 axcap 72 axes
# table 80 nsr 88 srcap 96 series table, 192 occupancy; Axes 16 figure 24
# index; axes record (256 bytes) 0 kind 8 base 16 twin 24 row 32 col 40
# rowspan 48 colspan 56 title 64 xlabel 72 ylabel 80 flags 88 legend
# 96/104 x limits 112/120 y limits 128/136 x labels 144/152 y labels 160
# cycle; series record (128 bytes) 0 kind 8 axes 16 colour 24 line 32
# marker 40 width 48 label 56 n 72 data 96 xline position.
    .bss
    .p2align 3
gFIG:   .zero 8
gA:     .zero 8
gB:     .zero 8
gT:     .zero 8
gT2:    .zero 8
gT3:    .zero 8
gS:     .zero 8 * 7                 # gS+8*k = the string of k (k = 1 .. 6)
live0:  .zero 8
freed0: .zero 8
    .data
    .p2align 6
LABS:                               # a str[] vector of 2 (static; elements set at run time)
    .quad SEA_RC_STATIC
    .byte SEA_TAG_ARRAY, SEA_EK_STR, 1, 0, 0, 0, 0, 0
    .quad 2, 1, 2, LABS + SEA_ARR_SIZE, 8, 0
    .quad 0, 0
    .p2align 6
NONE:                               # an empty str[] vector
    .quad SEA_RC_STATIC
    .byte SEA_TAG_ARRAY, SEA_EK_STR, 1, 0, 0, 0, 0, 0
    .quad 0, 1, 0, NONE + SEA_ARR_SIZE, 8, 0
    .text

# The entries' calls (the operands are movq sources: $label or memory).
.macro PLOT ax, x, y, sty, lab, w, col
    subq $16, %rsp
    movq $0, 0(%rsp)                # the site, PLOT's stack argument
    movq \ax, %rdi
    movq \x, %rsi
    movq \y, %rdx
    movq \sty, %rcx
    movq \lab, %r8
    movq \col, %r9
    movsd \w(%rip), %xmm0
    call sea_plot
    addq $16, %rsp
.endm
.macro XLINE ax, x, sty, col
    movq \ax, %rdi
    movsd \x(%rip), %xmm0
    movq \sty, %rsi
    movq \col, %rdx
    xorl %ecx, %ecx
    call sea_xline
.endm
# Field printers: %rbx = the record or object.
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
# %rbx = axes record idx / series record idx of gFIG (the tables may
# have moved since the last call).
.macro AXREC idx
    movq gFIG(%rip), %rax
    movq 72(%rax), %rbx
    addq $(\idx * 256), %rbx
.endm
.macro SRREC idx
    movq gFIG(%rip), %rax
    movq 96(%rax), %rbx
    addq $(\idx * 128), %rbx
.endm
# ` name <count>` of string k.
.macro SRC label, k
    TXT " \label "
    movq (gS + 8 * \k)(%rip), %rax
    movq (%rax), %rdi
    call putdec
.endm
# ` live <+d> freed <+d>` relative to the counts after the strings.
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
# ` label <0/1>`: whether the pointer field equals string k.
.macro ISSTR label, off, k
    TXT " \label "
    movq \off(%rbx), %rax
    xorl %edi, %edi
    cmpq (gS + 8 * \k)(%rip), %rax
    sete %dil
    call putdec
.endm
# ` data v0 .. v5`: the series' 2n data values as integers.
.macro DATA6
    TXT " data"
    movq 72(%rbx), %r12
    xorl %r13d, %r13d
.Ld6\@:
    TXT " "
    cvttsd2si (%r12,%r13,8), %rdi
    call putdec
    incq %r13
    cmpq $6, %r13
    jb .Ld6\@
.endm

    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    PROLOGUE
    movl $1, %r12d                  # the strings 11 .. 16, count 1 each
1:  leaq 10(%r12), %rdi
    xorl %esi, %esi
    call sea_str_i64
    leaq gS(%rip), %rcx
    movq %rax, (%rcx,%r12,8)
    incq %r12
    cmpq $6, %r12
    jbe 1b
    movq (gS + 40)(%rip), %rax      # LABS = [15, 16]
    movq %rax, (LABS + SEA_ARR_SIZE)(%rip)
    movq (gS + 48)(%rip), %rax
    movq %rax, (LABS + SEA_ARR_SIZE + 8)(%rip)
    movq sea_live(%rip), %rax
    movq %rax, live0(%rip)
    movq sea_freed(%rip), %rax
    movq %rax, freed0(%rip)

    # FIGURE: a 2 x 3 figure named "11", 640 x 480.
    movl $2, %edi
    movl $3, %esi
    movq (gS + 8)(%rip), %rdx
    movl $640, %ecx
    movl $480, %r8d
    xorl %r9d, %r9d
    call sea_figure
    movq %rax, gFIG(%rip)
    movq %rax, %rbx
    TXT "figure:"
    COUNTS
    PF rc, 0
    PF tag, 8
    PF nrows, 16
    PF ncols, 24
    PF w, 32
    PF h, 40
    ISSTR name, 48, 1
    SRC namerc, 1
    PF nax, 56
    PF axcap, 64
    PF nsr, 80
    PF srcap, 88
    TXT " zero "
    xorl %edi, %edi                 # bytes 104 .. 703: all zero
    movl $104, %ecx
2:  orq (%rbx,%rcx), %rdi
    addq $8, %rcx
    cmpq $704, %rcx
    jb 2b
    call putdec
    TXT "\n"

    # PANEL A at (0, 1) spanning 2 x 2.
    movq gFIG(%rip), %rdi
    xorl %esi, %esi
    movl $1, %edx
    movl $2, %ecx
    movl $2, %r8d
    xorl %r9d, %r9d
    call sea_panel
    movq %rax, gA(%rip)
    movq %rax, %rbx
    TXT "panel A:"
    COUNTS
    PF rc, 0
    PF tag, 8
    TXT " fig "
    movq 16(%rbx), %rax
    xorl %edi, %edi
    cmpq gFIG(%rip), %rax
    sete %dil
    call putdec
    PF idx, 24
    TXT " |"
    AXREC 0
    PF kind, 0
    PF base, 8
    PF twin, 16
    PF row, 24
    PF col, 32
    PF rs, 40
    PF cs, 48
    PF cyc, 160
    movq gFIG(%rip), %rbx
    PF figrc, 0
    PF nax, 56
    PF occ0, 192
    PF occ1, 200
    TXT "\n"

    # PANEL B at (1, 0).
    movq gFIG(%rip), %rdi
    movl $1, %esi
    xorl %edx, %edx
    movl $1, %ecx
    movl $1, %r8d
    xorl %r9d, %r9d
    call sea_panel
    movq %rax, gB(%rip)
    movq %rax, %rbx
    TXT "panel B:"
    PF idx, 24
    AXREC 1
    PF kind, 0
    PF base, 8
    PF twin, 16
    PF row, 24
    PF col, 32
    PF rs, 40
    PF cs, 48
    movq gFIG(%rip), %rbx
    PF occ0, 192
    PF occ1, 200
    PF nax, 56
    PF figrc, 0
    COUNTS
    TXT "\n"

    # TWIN_Y of A: a new twin record.
    movq gA(%rip), %rdi
    xorl %esi, %esi
    call sea_twin_y
    movq %rax, gT(%rip)
    movq %rax, %rbx
    TXT "twin T:"
    PF idx, 24
    AXREC 2
    PF kind, 0
    PF base, 8
    PF twin, 16
    PF row, 24
    PF col, 32
    PF rs, 40
    PF cs, 48
    PF cyc, 160
    AXREC 0
    PF Atwin, 16
    movq gFIG(%rip), %rbx
    PF nax, 56
    PF figrc, 0
    COUNTS
    TXT "\n"

    # TWIN_Y of A again, and of the twin: the same record.
    movq gA(%rip), %rdi
    xorl %esi, %esi
    call sea_twin_y
    movq %rax, gT2(%rip)
    movq gT(%rip), %rdi
    xorl %esi, %esi
    call sea_twin_y
    movq %rax, gT3(%rip)
    TXT "twin again:"
    movq gT2(%rip), %rbx
    PF T2idx, 24
    movq gT3(%rip), %rbx
    PF T3idx, 24
    movq gFIG(%rip), %rbx
    PF nax, 56
    PF figrc, 0
    COUNTS
    TXT "\n"

    # PLOT on A: style "r--o", label "12", width 2.
    PLOT gA(%rip), $X3, $Y3, $Srdo, (gS + 16)(%rip), W2, $EMP
    SRREC 0
    TXT "plot 0:"
    PF kind, 0
    PF ax, 8
    PH color, 16, 6
    PF line, 24
    PF mark, 32
    PH width, 40, 16
    ISSTR label, 48, 2
    SRC S2rc, 2
    PF n, 56
    DATA6
    AXREC 0
    PF Acyc, 160
    movq gFIG(%rip), %rbx
    PF nsr, 80
    TXT "\n"

    # Marker only: the cycle's first colour, no line.
    PLOT gA(%rip), $X3, $Y3, $So, $EMP, W1, $EMP
    SRREC 1
    TXT "plot 1:"
    PH color, 16, 6
    PF line, 24
    PF mark, 32
    PF label, 48
    AXREC 0
    PF Acyc, 160
    TXT "\n"

    # An explicit colour of mixed case: kept, the cycle not advanced.
    PLOT gA(%rip), $X3, $Y3, $Scolon, $EMP, W1, $Chex
    SRREC 2
    TXT "plot 2:"
    PH color, 16, 6
    PF line, 24
    PF mark, 32
    AXREC 0
    PF Acyc, 160
    TXT "\n"

    # On the twin: its cycle starts at the second colour.
    PLOT gT(%rip), $X3, $Y3, $Sdashdot, $EMP, W1, $EMP
    SRREC 3
    TXT "plot 3:"
    PF ax, 8
    PH color, 16, 6
    PF line, 24
    AXREC 2
    PF Tcyc, 160
    TXT "\n"

    # XLINE on B: "--" from the cycle, then "k" from its letter.
    XLINE gB(%rip), Xhalf, $Sdash, $EMP
    XLINE gB(%rip), Xhalf, $Sk, $EMP
    SRREC 4
    TXT "xline 4:"
    PF kind, 0
    PF ax, 8
    PH color, 16, 6
    PF line, 24
    PF mark, 32
    PH xpos, 96, 16
    PF n, 56
    PF data, 72
    SRREC 5
    TXT " | xline 5:"
    PH color, 16, 6
    PF line, 24
    AXREC 1
    PF Bcyc, 160
    TXT "\n"

    # An empty series with the style letter g.
    PLOT gB(%rip), $EV, $EV, $Sg, $EMP, W1, $EMP
    SRREC 6
    TXT "plot 6:"
    PH color, 16, 6
    PF line, 24
    PF mark, 32
    PF n, 56
    PF data, 72
    TXT "\n"

    # Three more on B: the series table doubles past 8 records.
    PLOT gB(%rip), $X3, $Y3, $Sstar, $EMP, W1, $EMP
    PLOT gB(%rip), $X3, $Y3, $Sstar, $EMP, W1, $EMP
    PLOT gB(%rip), $X3, $Y3, $Sstar, $EMP, W1, $EMP
    TXT "grow:"
    movq gFIG(%rip), %rbx
    PF nsr, 80
    PF srcap, 88
    SRREC 0
    TXT " s0"
    PF n, 56
    DATA6
    SRREC 9
    TXT " s9"
    PH color, 16, 6
    PF mark, 32
    AXREC 1
    PF Bcyc, 160
    TXT "\n"

    # Four more: the cycle wraps after seven colours.
    PLOT gB(%rip), $X3, $Y3, $Splus, $EMP, W1, $EMP
    PLOT gB(%rip), $X3, $Y3, $Splus, $EMP, W1, $EMP
    PLOT gB(%rip), $X3, $Y3, $Splus, $EMP, W1, $EMP
    PLOT gB(%rip), $X3, $Y3, $Splus, $EMP, W1, $EMP
    TXT "wrap:"
    SRREC 10
    PH s10, 16, 6
    SRREC 11
    PH s11, 16, 6
    SRREC 12
    PH s12, 16, 6
    SRREC 13
    PH s13, 16, 6
    AXREC 1
    PF Bcyc, 160
    movq gFIG(%rip), %rbx
    PF nsr, 80
    TXT "\n"

    # The strings of the pair (base record) and of each own y-axis.
    movq gT(%rip), %rdi
    movq (gS + 24)(%rip), %rsi
    call sea_xlabel
    movq gT(%rip), %rdi
    movq (gS + 24)(%rip), %rsi
    call sea_ylabel
    movq gA(%rip), %rdi
    movq (gS + 24)(%rip), %rsi
    call sea_title
    movq gA(%rip), %rdi
    movq (gS + 32)(%rip), %rsi
    call sea_title
    movq gB(%rip), %rdi
    movq (gS + 32)(%rip), %rsi
    call sea_ylabel
    TXT "strings:"
    AXREC 0
    ISSTR Axlab, 64, 3
    ISSTR Atitle, 56, 4
    PF Aylab, 72
    AXREC 2
    ISSTR Tylab, 72, 3
    PF Txlab, 64
    PF Ttitle, 56
    AXREC 1
    ISSTR Bylab, 72, 4
    SRC S3rc, 3
    SRC S4rc, 4
    TXT "\n"

    # LEGEND, GRID, XLIM, YLIM, Y_REVERSE, AXIS_EQUAL.
    movq gT(%rip), %rdi
    leaq Ssw(%rip), %rsi
    xorl %edx, %edx
    call sea_legend
    AXREC 0
    TXT "legend:"
    PF southwest, 88
    movq gA(%rip), %rdi
    leaq Sbest(%rip), %rsi
    xorl %edx, %edx
    call sea_legend
    AXREC 0
    PF best, 88
    AXREC 2
    PF T, 88
    TXT "\n"
    movq gT(%rip), %rdi
    movl $1, %esi
    call sea_grid
    AXREC 0
    TXT "grid:"
    PF on, 80
    movq gA(%rip), %rdi
    xorl %esi, %esi
    call sea_grid
    AXREC 0
    PF off, 80
    movq gA(%rip), %rdi
    movl $1, %esi
    call sea_grid
    AXREC 0
    PF on, 80
    TXT "\n"
    movq gT(%rip), %rdi
    movsd Xm1(%rip), %xmm0
    movsd W2(%rip), %xmm1
    xorl %esi, %esi
    call sea_xlim
    movq gT(%rip), %rdi
    xorpd %xmm0, %xmm0
    movsd X5(%rip), %xmm1
    xorl %esi, %esi
    call sea_ylim
    movq gT(%rip), %rdi
    call sea_y_reverse
    movq gT(%rip), %rdi
    call sea_axis_equal
    movq gA(%rip), %rdi
    call sea_y_reverse
    TXT "flags:"
    AXREC 0
    PF A, 80
    PH xlo, 96, 16
    PH xhi, 104, 16
    PH ylo, 112, 16
    PH yhi, 120, 16
    AXREC 2
    PF T, 80
    PH Tylo, 112, 16
    PH Tyhi, 120, 16
    PH Txlo, 96, 16
    AXREC 1
    PF B, 80
    TXT "\n"

    # X_TICKS and Y_TICKS: each label retained; a replaced list released.
    movq gT(%rip), %rdi
    movl $LABS, %esi
    xorl %edx, %edx
    call sea_x_ticks
    movq gB(%rip), %rdi
    movl $LABS, %esi
    xorl %edx, %edx
    call sea_y_ticks
    movq gA(%rip), %rdi
    movl $LABS, %esi
    xorl %edx, %edx
    call sea_x_ticks
    TXT "ticks:"
    AXREC 0
    PF Anx, 136
    PF Any, 152
    movq 128(%rbx), %rbx
    ISSTR A0, 0, 5
    ISSTR A1, 8, 6
    AXREC 1
    PF Bny, 152
    AXREC 2
    PF Tny, 152
    PF Tnx, 136
    SRC S5rc, 5
    SRC S6rc, 6
    TXT "\n"
    movq gA(%rip), %rdi
    movl $NONE, %esi
    xorl %edx, %edx
    call sea_x_ticks
    TXT "none:"
    AXREC 0
    PF Axcat, 128
    PF Anx, 136
    SRC S5rc, 5
    SRC S6rc, 6
    TXT "\n"

    # Freeing (L-lb): the Figure handle first, then the Axes; the figure
    # goes with the last handle.
    movq gFIG(%rip), %rax
    REL %rax
    TXT "release fig:"
    COUNTS
    movq gFIG(%rip), %rbx
    PF figrc, 0
    TXT "\n"
    movq gA(%rip), %rax
    REL %rax
    movq gB(%rip), %rax
    REL %rax
    movq gT(%rip), %rax
    REL %rax
    movq gT2(%rip), %rax
    REL %rax
    TXT "release A B T T2:"
    COUNTS
    movq gFIG(%rip), %rbx
    PF figrc, 0
    TXT "\n"
    movq gT3(%rip), %rax
    REL %rax
    TXT "release T3:"
    COUNTS
    SRC S1, 1
    SRC S2, 2
    SRC S3, 3
    SRC S4, 4
    SRC S5, 5
    SRC S6, 6
    TXT "\n"
    movl $1, %r12d                  # our own strings
3:  leaq gS(%rip), %rcx
    movq (%rcx,%r12,8), %rax
    REL %rax
    incq %r12
    cmpq $6, %r12
    jbe 3b
    EPILOGUE
    .size sea_main, . - sea_main

    .section .data.rel.ro,"aw",@progbits
    SSTR EMP, ""
    SSTR Srdo, "r--o"
    SSTR So, "o"
    SSTR Scolon, ":"
    SSTR Sdashdot, "-."
    SSTR Sdash, "--"
    SSTR Sk, "k"
    SSTR Sg, "g"
    SSTR Sstar, "*"
    SSTR Splus, "+"
    SSTR Chex, "#ABCdef"
    SSTR Ssw, "southwest"
    SSTR Sbest, "best"
    .p2align 3
W1:     .quad 0x3FF0000000000000    # 1.0
W2:     .quad 0x4000000000000000    # 2.0
Xhalf:  .quad 0x3FE0000000000000    # 0.5
Xm1:    .quad 0xBFF0000000000000    # -1.0
X5:     .quad 0x4014000000000000    # 5.0
    VEC X3, 3
    .quad 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000 # 1 2 3
    VEC Y3, 3
    .quad 0x4010000000000000, 0x4014000000000000, 0x4018000000000000 # 4 5 6
    VEC EV, 0
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
