# =====================================================================
# sea/runtime/x86_64_linux/rt_plot2.s -- the plotting library's bars,
# contours and images (LANGUAGE.md 12.3, 12.6; DESIGN.md 2.14.5, 2.14.6
# "Bars", "Images", "Contours", "The colour map", item 9; L-kq - L-ks,
# L-ko). The x86_64-linux twin of runtime/arm64_macos/rt_plot2.s: the same
# records, operations and bytes.
#
# Defines (global, rt.inc SEA_ENTRY_LIST, ids 68 - 71):
#   sea_bar      (ax, x, h, label, color, site; width in %xmm0)
#   sea_barh     (ax, h, label, color, site; width in %xmm0)
#   sea_contour  (ax, x, y, Z, levels, labels; color and site in the stack
#                arguments at 8(%rsp) and 16(%rsp) on entry, L-ku)
#   sea_image    (ax, x, y, Z, colorbar, site)
# Defines (.globl + .hidden, private to the runtime, called by rt_plot.s
# and by tests/rt):
#   sea_plt2_ext      (record, y descriptor): the data extents of a series
#                     of kind 3 - 6 (bar, barh, contour, image)
#   sea_plt2_draw     (record, y-axis): its elements inside the data group
#   sea_plt2_colorbar ():  item 9 of the panel being written
#   sea_plt_cmap      (e) -> the colour map's entry e as 0xRRGGBB
# Uses: rt_plot.s's shared routines and state (sea_plt_*: its file
#   header), sea_png and sea_b64 (rt_png.s), sea_alloc, sea_free_block,
#   sea_retain (rt_mem.s), sea_fmt_num (rt_fmt.s); glibc memcpy.
#
# The entries check their arguments in parameter order (DESIGN.md 2.14.2,
# L-kg) and append a series record (the layout of rt_plot.s) with one
# uncounted data block: a bar's x then h (16n bytes), a barh's h (8n), a
# contour's or an image's x, y and Z column-major (8(n + m + nm)); no
# block when that size is 0. A bar series takes the colour argument or the
# axes' next cycle colour; a contour stores its colour argument or -1 (the
# map per level) and never advances the cycle; an image has no colour.
#
# Drawing (at SAVE_SVG, through rt_plot.s): every coordinate is mapped and
# clamped by sea_plt_map before use; every length is the absolute
# difference of two clamped ends; the readings where 2.14.6 leaves room are
# those of the 9c READINGS (the order of the extents, the colorbar's x).
# The colour map is built once, at its first use, by the operations of
# 2.14.6 into a table of 256 entries.
#
# NUMBERS: one IEEE double operation per operation written, in that order,
# no FMA; NaN-sensitive tests are explicit ucomisd branches; a float
# becomes an integer only when it is bounded (a map index, a PNG entry).
#
# ABI: System V AMD64; the entries preserve %rbx %rbp %r12 - %r15 and
# %rsp, never change MXCSR and leave the direction flag clear. Stack: each
# entry's own frame is at most 72 bytes below its return address; at
# SAVE_SVG the deepest own path through this file is SAVE_SVG (56) + the
# panel writer (104) + the contour writer (72) + marching squares (312) +
# the segment writer (24) + the %.2f writer (24), each with its return
# address: sea_fmt_num is called 640 bytes below SAVE_SVG's return
# address (the 9b line path: 352). The measured total (snprintf
# included): DESIGN.md 4.8.
# =====================================================================
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

# ---- The records of rt_plot.s (DESIGN.md 2.14.6 "Objects") -----------
.equ RTP_FG_NSR,        80
.equ RTP_AH_FIG,        16
.equ RTP_AH_IDX,        24
.equ RTP_SR_KIND,       0
.equ RTP_SR_AX,         8
.equ RTP_SR_COLOR,      16
.equ RTP_SR_WIDTH,      40
.equ RTP_SR_LABEL,      48
.equ RTP_SR_N,          56
.equ RTP_SR_M,          64
.equ RTP_SR_DATA,       72
.equ RTP_SR_LEVELS,     80
.equ RTP_SR_FLAG,       88
.equ RTP_SR_SHIFT,      7
.equ RTP_SK_BAR,        3
.equ RTP_SK_BARH,       4
.equ RTP_SK_CONTOUR,    5
.equ RTP_SK_IMAGE,      6
# An axis descriptor (rt_plot.s RTP_A_*): the fields used here.
.equ RTP_A_EHAS,        0
.equ RTP_A_ELO,         8
.equ RTP_A_EHI,         16
.equ RTP_A_LO,          72
.equ RTP_A_HI,          80
.equ RTP_A_NT,          88
.equ RTP_A_SIZE,        (248 + 8 * 352)
.equ RTP_AXIS_CB,       3           # the colorbar's descriptor (the fourth)
.equ RTP_NUMBUF,        352         # sea_fmt_num's destination size
.equ RTP_CB_N,          256         # the colorbar PNG: 1 x 256
.equ RTP_WHITE,         0xFFFFFF
.equ RTP_B_INF,         0x7FF0000000000000
.equ RTP_B_INF2,        0xFFE0000000000000 # |bits| << 1 >= it: NaN or +-Inf
.equ RTP_B_ABS,         0x7FFFFFFFFFFFFFFF

# ---- Frames, as in rt_plot.s --------------------------------------------
# ENTER/LEAVE: %rbp, %rbx, %r12 - %r15 saved, then `locals` bytes at
# 0(%rsp); locals = 8 (mod 16) keeps %rsp = 0 (mod 16) at the calls; the
# frame is 48 + locals bytes below the return address.
.macro ENTER locals
    .if ((\locals) % 16) != 8
        .error "rt_plot2: ENTER needs locals = 8 (mod 16)"
    .endif
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $(\locals), %rsp
.endm
.macro LEAVE locals
    addq $(\locals), %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret
.endm
# LIT text -- append literal bytes to the SVG buffer (caller-saved
# registers clobbered; %rsp = 0 (mod 16)).
.macro LIT text
    leaq .Lrt_plot2_lit\@(%rip), %rdi
    movl $(.Lrt_plot2_lite\@ - .Lrt_plot2_lit\@), %esi
    call sea_plt_put
    .pushsection .rodata
.Lrt_plot2_lit\@: .ascii "\text"
.Lrt_plot2_lite\@:
    .popsection
.endm
# F2 mem -- append the f64 at mem as %.2f.
.macro F2 mem
    movsd \mem, %xmm0
    call sea_plt_f2
.endm
# NONFIN xreg, label -- jump to label unless xreg is finite (clobbers
# %rax, %rcx).
.macro NONFIN xreg, label
    movq \xreg, %rax
    shlq $1, %rax
    movabsq $RTP_B_INF2, %rcx
    cmpq %rcx, %rax
    jae \label
.endm

    .text

# =====================================================================
# Small helpers of the entries
# =====================================================================

# ---------------------------------------------------------------------
# .Lrt_plot2_chkw -- PLOT_WIDTH (the bits of width) unless width is
#   finite and > 0.
#   Inputs  : %xmm0 = width.  Clobbers: %rax, %rcx, %xmm1, flags
#   Frame   : none (leaf; sea_plt_raise does not return)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot2_chkw:
    xorpd %xmm1, %xmm1
    ucomisd %xmm1, %xmm0
    jbe 1f                          # <= 0 or NaN
    movq %xmm0, %rax
    movabsq $RTP_B_INF, %rcx
    cmpq %rcx, %rax
    jae 1f                          # +Inf
    ret
1:  movl $SEA_E_PLOT_WIDTH, %edi
    movq sea_plt_site(%rip), %rsi
    movq %xmm0, %rdx
    call sea_plt_raise

# ---------------------------------------------------------------------
# .Lrt_plot2_chkc -- a colour argument: -1 for "", 0xRRGGBB, or COLOR
#   with the whole string.
#   Inputs  : %rdi = the colour string.  Outputs: %rax
#   Clobbers: %rcx, %rdx, %rsi, flags.  Frame: none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot2_chkc:
    call sea_plt_colorarg           # (keeps %rdi)
    cmpq $-2, %rax
    je 1f
    ret
1:  movq %rdi, %rdx
    movl $SEA_E_COLOR, %edi
    movq sea_plt_site(%rip), %rsi
    call sea_plt_raise

# ---------------------------------------------------------------------
# .Lrt_plot2_alloc -- an uncounted block of %rdi bytes at the entry's
#   site, or 0 for 0 bytes (2.14.6 "Block sizes").
#   Outputs : %rax.  Clobbers: all caller-saved registers
#   Callee-saved used: %rbp.  Frame: 8 bytes
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot2_alloc:
    xorl %eax, %eax
    testq %rdi, %rdi
    jz 1f
    pushq %rbp
    movq %rsp, %rbp
    movq sea_plt_site(%rip), %rsi
    call sea_alloc
    popq %rbp
1:  ret

# ---------------------------------------------------------------------
# .Lrt_plot2_cpy -- copy an f64 array's first n elements to dst.
#   Inputs  : %rdi = dst, %rsi = the array, %rdx = n
#   Clobbers: all caller-saved registers.  Frame: none (tail call)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot2_cpy:
    movq SEA_ARR_DATA(%rsi), %rsi
    shlq $3, %rdx
    jmp memcpy@PLT

# ---------------------------------------------------------------------
# .Lrt_plot2_rec -- append a zero-filled series record of a kind for an
#   Axes (the table doubled when full).
#   Inputs  : %rdi = the Axes, %rsi = the kind
#   Outputs : %rax = the record (kind and axes index set)
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = the Axes, %r12 = the kind, %rbp
#   Frame   : 24 bytes
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot2_rec:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12                      # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
    movq RTP_AH_FIG(%rbx), %rdi
    movl $RTP_FG_NSR, %esi
    movl $RTP_SR_SHIFT, %edx
    call sea_plt_grow
    movq %r12, RTP_SR_KIND(%rax)
    movq RTP_AH_IDX(%rbx), %rcx
    movq %rcx, RTP_SR_AX(%rax)
    popq %r12
    popq %rbx
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_plot2_label -- a series' label: 0 for "", else the string,
#   retained.
#   Inputs  : %rdi = the record, %rsi = the label
#   Clobbers: all caller-saved registers.  Frame: none (tail call)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot2_label:
    cmpq $0, SEA_STR_LEN(%rsi)
    je 1f
    movq %rsi, RTP_SR_LABEL(%rdi)
    movq %rsi, %rdi
    jmp sea_retain
1:  ret

# ---------------------------------------------------------------------
# .Lrt_plot2_grid -- the data block of a contour or image: x (n), y (m),
#   then Z's n * m elements column-major (8(n + m + nm) bytes; none when
#   that is 0).
#   Inputs  : %rdi = x, %rsi = y, %rdx = Z (shape m x n, checked)
#   Outputs : %rax = the block or 0
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = x, %r12 = y, %r13 = Z, %r14 = the block,
#             %r15 = n, %rbp; 0(%rsp) = m
#   Frame   : 56 bytes (ENTER 8)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot2_grid:
    ENTER 8
    movq %rdi, %rbx
    movq %rsi, %r12
    movq %rdx, %r13
    movq SEA_ARR_ROWS(%rbx), %r15   # n
    movq SEA_ARR_ROWS(%r12), %rax   # m
    movq %rax, 0(%rsp)
    imulq %r15, %rax                # nm
    addq %r15, %rax
    addq 0(%rsp), %rax              # n + m + nm
    leaq (,%rax,8), %rdi
    call .Lrt_plot2_alloc
    movq %rax, %r14
    testq %r14, %r14
    jz 9f
    movq %r14, %rdi                 # x
    movq %rbx, %rsi
    movq %r15, %rdx
    call .Lrt_plot2_cpy
    leaq (%r14,%r15,8), %rdi        # y
    movq %r12, %rsi
    movq 0(%rsp), %rdx
    call .Lrt_plot2_cpy
    movq %r15, %rax                 # Z at 8(n + m)
    addq 0(%rsp), %rax
    leaq (%r14,%rax,8), %rdi
    movq %r13, %rsi
    movq %r15, %rdx
    imulq 0(%rsp), %rdx
    call .Lrt_plot2_cpy
9:  movq %r14, %rax
    LEAVE 8

# =====================================================================
# The entries
# =====================================================================

# ---------------------------------------------------------------------
# sea_bar -- entry BAR (68).
#   Purpose : SHAPE_MISMATCH (len(x), len(h)), PLOT_WIDTH, COLOR, in
#             that order; then a bar series with a copy of x and h, its
#             colour resolved now (the argument, else the cycle, L-kh).
#   Inputs  : %rdi = ax, %rsi = x, %rdx = h, %rcx = label, %r8 = color,
#             %r9 = site, %xmm0 = width
#   Outputs : none
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = ax, %r12 = x, %r13 = h, %r14 = label, %r15
#             = color, then the data block, %rbp; locals 0 width, 8 the
#             colour
#   Frame   : 72 bytes (ENTER 24)
# ---------------------------------------------------------------------
    .globl sea_bar
    .type sea_bar, @function
    .p2align 4
sea_bar:
    ENTER 24
    movq %r9, sea_plt_site(%rip)
    movq %rdi, %rbx
    movq %rsi, %r12
    movq %rdx, %r13
    movq %rcx, %r14
    movq %r8, %r15
    movsd %xmm0, 0(%rsp)
    # 1. The shapes of x and h (two vectors).
    movq SEA_ARR_ROWS(%r12), %rdx
    movq SEA_ARR_ROWS(%r13), %r8
    cmpq %rdx, %r8
    je 1f
    movl $SEA_E_SHAPE_MISMATCH, %edi
    movq sea_plt_site(%rip), %rsi
    movq $SEA_SHAPE_VEC, %rcx
    movq $SEA_SHAPE_VEC, %r9
    call sea_plt_raise
    # 2. The width; 3. the colour, resolved now.
1:  movsd 0(%rsp), %xmm0
    call .Lrt_plot2_chkw
    movq %r15, %rdi
    call .Lrt_plot2_chkc
    movq %rbx, %rdi
    movq %rax, %rsi
    movq $-1, %rdx                  # no style letter
    call sea_plt_rescol
    movq %rax, 8(%rsp)
    # 4. The data copy: x then h.
    movq SEA_ARR_ROWS(%r12), %rdi
    shlq $4, %rdi
    call .Lrt_plot2_alloc
    movq %rax, %r15
    testq %r15, %r15
    jz 2f
    movq %r15, %rdi
    movq %r12, %rsi
    movq SEA_ARR_ROWS(%r12), %rdx
    call .Lrt_plot2_cpy
    movq SEA_ARR_ROWS(%r12), %rdx
    leaq (%r15,%rdx,8), %rdi
    movq %r13, %rsi
    call .Lrt_plot2_cpy
    # 5. The record.
2:  movq %rbx, %rdi
    movl $RTP_SK_BAR, %esi
    call .Lrt_plot2_rec
    movq 8(%rsp), %rcx
    movq %rcx, RTP_SR_COLOR(%rax)
    movq 0(%rsp), %rcx
    movq %rcx, RTP_SR_WIDTH(%rax)
    movq SEA_ARR_ROWS(%r12), %rcx
    movq %rcx, RTP_SR_N(%rax)
    movq %r15, RTP_SR_DATA(%rax)
    movq %rax, %rdi
    movq %r14, %rsi
    call .Lrt_plot2_label
    LEAVE 24
    .size sea_bar, . - sea_bar

# ---------------------------------------------------------------------
# sea_barh -- entry BARH (69): PLOT_WIDTH, COLOR; a horizontal bar
#   series with a copy of h at y = 0, 1, ...
#   Inputs  : %rdi = ax, %rsi = h, %rdx = label, %rcx = color, %r8 =
#             site, %xmm0 = width
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = ax, %r12 = h, %r13 = label, %r14 = the
#             colour, %r15 = the data block, %rbp; local 0 width
#   Frame   : 56 bytes (ENTER 8)
# ---------------------------------------------------------------------
    .globl sea_barh
    .type sea_barh, @function
    .p2align 4
sea_barh:
    ENTER 8
    movq %r8, sea_plt_site(%rip)
    movq %rdi, %rbx
    movq %rsi, %r12
    movq %rdx, %r13
    movq %rcx, %r14
    movsd %xmm0, 0(%rsp)
    call .Lrt_plot2_chkw            # 1. the width
    movq %r14, %rdi                 # 2. the colour
    call .Lrt_plot2_chkc
    movq %rbx, %rdi
    movq %rax, %rsi
    movq $-1, %rdx
    call sea_plt_rescol
    movq %rax, %r14
    movq SEA_ARR_ROWS(%r12), %rdi   # the data copy: h, 8n bytes
    shlq $3, %rdi
    call .Lrt_plot2_alloc
    movq %rax, %r15
    testq %r15, %r15
    jz 1f
    movq %r15, %rdi
    movq %r12, %rsi
    movq SEA_ARR_ROWS(%r12), %rdx
    call .Lrt_plot2_cpy
1:  movq %rbx, %rdi
    movl $RTP_SK_BARH, %esi
    call .Lrt_plot2_rec
    movq %r14, RTP_SR_COLOR(%rax)
    movq 0(%rsp), %rcx
    movq %rcx, RTP_SR_WIDTH(%rax)
    movq SEA_ARR_ROWS(%r12), %rcx
    movq %rcx, RTP_SR_N(%rax)
    movq %r15, RTP_SR_DATA(%rax)
    movq %rax, %rdi
    movq %r13, %rsi
    call .Lrt_plot2_label
    LEAVE 8
    .size sea_barh, . - sea_barh

# ---------------------------------------------------------------------
# sea_contour -- entry CONTOUR (70): SHAPE_EXPECTED (len(y) x len(x),
#   Z's shape), CONTOUR_LEVELS (levels < 1), COLOR; a contour series with
#   copies of x, y and Z, its colour the argument or -1 (the map per
#   level, Decision 132 (a)); the cycle does not advance.
#   Inputs  : %rdi = ax, %rsi = x, %rdx = y, %rcx = Z, %r8 = levels, %r9
#             = labels (0 / 1), 8(%rsp) = color, 16(%rsp) = site (the
#             stack arguments on entry: 16(%rbp), 24(%rbp) after ENTER)
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = ax, %r12 = x, %r13 = y, %r14 = Z, %r15 =
#             levels, %rbp; locals 0 color, 8 labels, 16 the colour
#   Frame   : 72 bytes (ENTER 24)
# ---------------------------------------------------------------------
    .globl sea_contour
    .type sea_contour, @function
    .p2align 4
sea_contour:
    ENTER 24
    movq 24(%rbp), %rax             # the site (16(%rsp) on entry)
    movq %rax, sea_plt_site(%rip)
    movq 16(%rbp), %rax             # color (8(%rsp) on entry)
    movq %rax, 0(%rsp)
    movq %r9, 8(%rsp)
    movq %rdi, %rbx
    movq %rsi, %r12
    movq %rdx, %r13
    movq %rcx, %r14
    movq %r8, %r15
    call .Lrt_plot2_zshape          # 1. Z is len(y) x len(x)
    cmpq $1, %r15                   # 2. levels >= 1
    jge 1f
    movl $SEA_E_CONTOUR_LEVELS, %edi
    movq sea_plt_site(%rip), %rsi
    movq %r15, %rdx
    call sea_plt_raise
1:  movq 0(%rsp), %rdi              # 3. the colour (-1 for "")
    call .Lrt_plot2_chkc
    movq %rax, 16(%rsp)
    movq %r12, %rdi                 # the data copy
    movq %r13, %rsi
    movq %r14, %rdx
    call .Lrt_plot2_grid
    movq %rax, %r14
    movq %rbx, %rdi
    movl $RTP_SK_CONTOUR, %esi
    call .Lrt_plot2_rec
    movq 16(%rsp), %rcx
    movq %rcx, RTP_SR_COLOR(%rax)
    movq SEA_ARR_ROWS(%r12), %rcx
    movq %rcx, RTP_SR_N(%rax)
    movq SEA_ARR_ROWS(%r13), %rcx
    movq %rcx, RTP_SR_M(%rax)
    movq %r14, RTP_SR_DATA(%rax)
    movq %r15, RTP_SR_LEVELS(%rax)
    movq 8(%rsp), %rcx
    movq %rcx, RTP_SR_FLAG(%rax)
    LEAVE 24
    .size sea_contour, . - sea_contour

# ---------------------------------------------------------------------
# sea_image -- entry IMAGE (71): SHAPE_EXPECTED; an image series with
#   copies of x, y and Z, the colorbar flag.
#   Inputs  : %rdi = ax, %rsi = x, %rdx = y, %rcx = Z, %r8 = colorbar
#             (0 / 1), %r9 = site
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = ax, %r12 = x, %r13 = y, %r14 = Z, then the
#             block, %r15 = colorbar, %rbp
#   Frame   : 56 bytes (ENTER 8)
# ---------------------------------------------------------------------
    .globl sea_image
    .type sea_image, @function
    .p2align 4
sea_image:
    ENTER 8
    movq %r9, sea_plt_site(%rip)
    movq %rdi, %rbx
    movq %rsi, %r12
    movq %rdx, %r13
    movq %rcx, %r14
    movq %r8, %r15
    call .Lrt_plot2_zshape
    movq %r12, %rdi
    movq %r13, %rsi
    movq %r14, %rdx
    call .Lrt_plot2_grid
    movq %rax, %r14
    movq %rbx, %rdi
    movl $RTP_SK_IMAGE, %esi
    call .Lrt_plot2_rec
    movq SEA_ARR_ROWS(%r12), %rcx
    movq %rcx, RTP_SR_N(%rax)
    movq SEA_ARR_ROWS(%r13), %rcx
    movq %rcx, RTP_SR_M(%rax)
    movq %r14, RTP_SR_DATA(%rax)
    movq %r15, RTP_SR_FLAG(%rax)
    LEAVE 8
    .size sea_image, . - sea_image

# ---------------------------------------------------------------------
# .Lrt_plot2_zshape -- SHAPE_EXPECTED (len(y) x len(x), Z's rows x cols)
#   unless Z is len(y) x len(x); CONTOUR's and IMAGE's first check.
#   Inputs  : %r12 = x, %r13 = y, %r14 = Z (the caller's registers)
#   Clobbers: %rdx, %rcx, %r8, %r9, flags.  Frame: none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot2_zshape:
    movq SEA_ARR_ROWS(%r13), %rdx   # expected: len(y) x len(x)
    movq SEA_ARR_ROWS(%r12), %rcx
    movq SEA_ARR_ROWS(%r14), %r8    # got: Z's shape
    movq SEA_ARR_COLS(%r14), %r9
    cmpq %rdx, %r8
    jne 1f
    cmpq %rcx, %r9
    jne 1f
    ret
1:  movl $SEA_E_SHAPE_EXPECTED, %edi
    movq sea_plt_site(%rip), %rsi
    call sea_plt_raise

# =====================================================================
# Shared pieces of the drawing
# =====================================================================

# ---------------------------------------------------------------------
# sea_plt_cmap -- the colour map's entry e (2.14.6 "The colour map"),
#   the table built at the first use.
#   Inputs  : %edi = e (0 .. 255)
#   Outputs : %eax = 0xRRGGBB
#   Clobbers: %rcx, %rdx, %rsi, %r8 - %r11, %xmm0 - %xmm4, flags
#   Frame   : none (calls only leaves)
# ---------------------------------------------------------------------
    .globl sea_plt_cmap
    .hidden sea_plt_cmap
    .type sea_plt_cmap, @function
    .p2align 4
sea_plt_cmap:
    cmpq $0, .Lrt_plot2_cmok(%rip)
    jne 1f
    movl %edi, %r11d
    call .Lrt_plot2_cmbuild
    movl %r11d, %edi
1:  movl %edi, %eax
    leaq .Lrt_plot2_cmtab(%rip), %rcx
    movl (%rcx,%rax,4), %eax
    ret
    .size sea_plt_cmap, . - sea_plt_cmap

# ---------------------------------------------------------------------
# .Lrt_plot2_cmbuild -- the 256 entries: p = f64(4e) / 255; s =
#   min(floor(p), 3); f = p - f64(s); per channel round(A_s + f * (A_s+1
#   - A_s)), the channels as f64, round half away from zero (every value
#   is positive: trunc, then + 1 when the remainder is >= 0.5).
#   Clobbers: %rax, %rcx, %rdx, %rsi, %r8 - %r10, %xmm0 - %xmm4, flags
#   Frame   : none (calls the leaf sea_plt_floor)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot2_cmbuild:
    xorl %r8d, %r8d                 # e
1:  leal (,%r8,4), %eax             # p = f64(4e) / 255
    cvtsi2sdl %eax, %xmm0
    divsd .Lrt_plot2_c_255(%rip), %xmm0
    movapd %xmm0, %xmm3             # p
    call sea_plt_floor              # floor(p) (0 .. 4, exact)
    cvttsd2si %xmm0, %r9d
    cmpl $3, %r9d
    jle 2f
    movl $3, %r9d                   # s = min(floor(p), 3)
2:  cvtsi2sdl %r9d, %xmm0
    subsd %xmm0, %xmm3              # f = p - f64(s)
    leaq .Lrt_plot2_anchor(%rip), %rsi
    leaq (%r9,%r9,2), %rax
    addq %rax, %rsi                 # A_s's three channels, then A_s+1's
    xorl %r10d, %r10d               # the entry being built
    xorl %ecx, %ecx                 # channel 0 .. 2
3:  movzbl (%rsi,%rcx), %eax        # A_s
    cvtsi2sdl %eax, %xmm1
    movzbl 3(%rsi,%rcx), %edx       # A_s+1
    cvtsi2sdl %edx, %xmm2
    subsd %xmm1, %xmm2              # A_s+1 - A_s
    mulsd %xmm3, %xmm2              # f * (...)
    addsd %xmm2, %xmm1              # A_s + f * (...)
    cvttsd2si %xmm1, %eax           # round: trunc ...
    cvtsi2sdl %eax, %xmm4
    subsd %xmm4, %xmm1
    ucomisd .Lrt_plot2_c_half(%rip), %xmm1
    jb 4f
    incl %eax                       # ... + 1 when the remainder is >= 0.5
4:  shll $8, %r10d
    orl %eax, %r10d
    incl %ecx
    cmpl $3, %ecx
    jb 3b
    leaq .Lrt_plot2_cmtab(%rip), %rax
    movl %r10d, (%rax,%r8,4)
    incl %r8d
    cmpl $256, %r8d
    jb 1b
    movq $1, .Lrt_plot2_cmok(%rip)
    ret

# ---------------------------------------------------------------------
# .Lrt_plot2_zrange -- zmin, zmax of a contour's or image's finite cells
#   (first wins on ties) and the degenerate flag: no finite cell, zmax =
#   zmin, or zmax - zmin not finite (2.14.6 "Images", "Contours").
#   Inputs  : %rdi = the record
#   Outputs : .Lrt_plot2_zlo, .Lrt_plot2_zhi, .Lrt_plot2_zhas (1 when a
#             finite cell exists), .Lrt_plot2_zdeg (1 when degenerate)
#   Clobbers: %rax, %rcx, %rdx, %rsi, %r8, %xmm0 - %xmm2, flags
#   Frame   : none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot2_zrange:
    movq RTP_SR_N(%rdi), %rax
    movq RTP_SR_M(%rdi), %rdx
    leaq (%rax,%rdx), %rcx
    imulq %rax, %rdx                # nm cells
    movq RTP_SR_DATA(%rdi), %rsi
    leaq (%rsi,%rcx,8), %rsi        # Z
    xorl %r8d, %r8d                 # has
    xorpd %xmm1, %xmm1
    xorpd %xmm2, %xmm2
1:  testq %rdx, %rdx
    jz 4f
    movsd (%rsi), %xmm0
    addq $8, %rsi
    decq %rdx
    NONFIN %xmm0, 1b
    testl %r8d, %r8d
    jnz 2f
    movl $1, %r8d                   # the first finite cell
    movapd %xmm0, %xmm1
    movapd %xmm0, %xmm2
    jmp 1b
2:  ucomisd %xmm1, %xmm0
    jae 3f
    movapd %xmm0, %xmm1             # z < zmin
3:  ucomisd %xmm2, %xmm0
    jbe 1b
    movapd %xmm0, %xmm2             # z > zmax
    jmp 1b
4:  movsd %xmm1, .Lrt_plot2_zlo(%rip)
    movsd %xmm2, .Lrt_plot2_zhi(%rip)
    movq %r8, .Lrt_plot2_zhas(%rip)
    movq $1, .Lrt_plot2_zdeg(%rip)
    testl %r8d, %r8d
    jz 5f                           # no finite cell
    ucomisd %xmm1, %xmm2
    je 5f                           # zmax = zmin
    subsd %xmm1, %xmm2
    NONFIN %xmm2, 5f                # zmax - zmin overflowed
    movq $0, .Lrt_plot2_zdeg(%rip)
5:  ret

# ---------------------------------------------------------------------
# .Lrt_plot2_zcol -- an image cell's colour (2.14.6 "Images"): NaN white;
#   degenerate entry 0; z >= zmax 255; z <= zmin 0; else floor(((z -
#   zmin) / (zmax - zmin)) * 256), 256 becoming 255. The colour map table
#   must be built.
#   Inputs  : %xmm0 = z; .Lrt_plot2_zlo/zhi/zdeg
#   Outputs : %eax = 0xRRGGBB
#   Clobbers: %rcx, %xmm0, %xmm1, flags.  Frame: none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot2_zcol:
    ucomisd %xmm0, %xmm0
    jp 8f                           # NaN: white
    xorl %eax, %eax                 # entry 0
    cmpq $0, .Lrt_plot2_zdeg(%rip)
    jne 7f
    movl $255, %eax
    ucomisd .Lrt_plot2_zhi(%rip), %xmm0
    jae 7f                          # z >= zmax
    xorl %eax, %eax
    ucomisd .Lrt_plot2_zlo(%rip), %xmm0
    jbe 7f                          # z <= zmin
    subsd .Lrt_plot2_zlo(%rip), %xmm0 # (z - zmin) / (zmax - zmin) * 256
    movsd .Lrt_plot2_zhi(%rip), %xmm1
    subsd .Lrt_plot2_zlo(%rip), %xmm1
    divsd %xmm1, %xmm0
    mulsd .Lrt_plot2_c_256(%rip), %xmm0
    cvttsd2si %xmm0, %eax           # floor of a value in (0, 256]
    cmpl $255, %eax
    jbe 7f
    movl $255, %eax
7:  leaq .Lrt_plot2_cmtab(%rip), %rcx
    movl (%rcx,%rax,4), %eax
    ret
8:  movl $RTP_WHITE, %eax
    ret

# ---------------------------------------------------------------------
# .Lrt_plot2_iext -- an image's extent (2.14.6 "Images"): with n, m >=
#   1, hx = 0.5 for n = 1, else (x[n-1] - x[0]) / f64(2(n - 1)); a = x[0]
#   - hx, b = x[n-1] + hx; the same for y. Drawn (and an extent) only
#   when all four ends are finite.
#   Inputs  : %rdi = the record
#   Outputs : %eax = 1 and %xmm0 = a, %xmm1 = b, %xmm2 = a_y, %xmm3 =
#             b_y; or %eax = 0
#   Clobbers: %rcx, %rdx, %rsi, %r8, %xmm4, %xmm5, flags
#   Frame   : none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot2_iext:
    movq RTP_SR_N(%rdi), %rsi
    movq RTP_SR_M(%rdi), %rdx
    testq %rsi, %rsi
    jz 9f
    testq %rdx, %rdx
    jz 9f
    movq RTP_SR_DATA(%rdi), %r8     # x
    call .Lrt_plot2_ends            # x: %xmm4 = a, %xmm5 = b
    movapd %xmm4, %xmm0
    movapd %xmm5, %xmm1
    leaq (%r8,%rsi,8), %r8          # y
    movq %rdx, %rsi
    call .Lrt_plot2_ends
    movapd %xmm4, %xmm2
    movapd %xmm5, %xmm3
    movq %xmm0, %rax                # all four finite?
    shlq $1, %rax
    movabsq $RTP_B_INF2, %rcx
    cmpq %rcx, %rax
    jae 9f
    movq %xmm1, %rax
    shlq $1, %rax
    cmpq %rcx, %rax
    jae 9f
    movq %xmm2, %rax
    shlq $1, %rax
    cmpq %rcx, %rax
    jae 9f
    movq %xmm3, %rax
    shlq $1, %rax
    cmpq %rcx, %rax
    jae 9f
    movl $1, %eax
    ret
9:  xorl %eax, %eax
    ret

# ---------------------------------------------------------------------
# .Lrt_plot2_ends -- the two extent ends of k >= 1 coordinates at %r8:
#   a = v[0] - h and b = v[k-1] + h, h = 0.5 (k = 1) or (v[k-1] - v[0]) /
#   f64(2(k - 1)).
#   Inputs  : %r8 = the coordinates v, %rsi = k (>= 1)
#   Outputs : %xmm4 = a, %xmm5 = b
#   Clobbers: %rax, %xmm4, %xmm5, flags
#   Callee-saved used: none
#   Frame   : none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot2_ends:
    movsd .Lrt_plot2_c_half(%rip), %xmm5 # h for k = 1
    cmpq $1, %rsi
    je 1f
    movsd -8(%r8,%rsi,8), %xmm5     # (v[k-1] - v[0]) / f64(2(k - 1))
    subsd (%r8), %xmm5
    leaq -1(%rsi), %rax
    addq %rax, %rax
    cvtsi2sdq %rax, %xmm4
    divsd %xmm4, %xmm5
1:  movsd (%r8), %xmm4              # a = v[0] - h
    subsd %xmm5, %xmm4
    addsd -8(%r8,%rsi,8), %xmm5     # b = h + v[k-1] (= v[k-1] + h exactly)
    ret

# ---------------------------------------------------------------------
# .Lrt_plot2_hw -- a bar series' half width (2.14.6 "Bars", L-kq): Delta
#   = the smallest positive difference of consecutive values in the
#   ascending sort of the finite x values (1 without one); hw = (width *
#   Delta) / 2. The finite values are sorted in a scratch block (freed
#   before the return).
#   Inputs  : %rdi = the record
#   Outputs : %xmm0 = hw
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = the record, %r12 = n, %r13 = x, %r14 = the
#             scratch block, %r15 = the finite count, %rbp; local 0 Delta
#   Frame   : 56 bytes (ENTER 8)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot2_hw:
    ENTER 8
    movq %rdi, %rbx
    movq RTP_SR_N(%rbx), %r12
    movq RTP_SR_DATA(%rbx), %r13
    movsd .Lrt_plot2_c_one(%rip), %xmm0
    movsd %xmm0, 0(%rsp)            # Delta = 1 unless found below
    xorl %r15d, %r15d               # the finite values
    xorl %edx, %edx
1:  cmpq %r12, %rdx
    jae 2f
    movsd (%r13,%rdx,8), %xmm0
    incq %rdx
    NONFIN %xmm0, 1b
    incq %r15
    jmp 1b
2:  cmpq $2, %r15
    jb 8f                           # fewer than two: Delta 1
    leaq (,%r15,8), %rdi
    call .Lrt_plot2_alloc
    movq %rax, %r14
    xorl %edx, %edx                 # copy them
    xorl %esi, %esi
3:  cmpq %r12, %rdx
    jae 4f
    movsd (%r13,%rdx,8), %xmm0
    incq %rdx
    NONFIN %xmm0, 3b
    movsd %xmm0, (%r14,%rsi,8)
    incq %rsi
    jmp 3b
4:  movq %r14, %rdi
    movq %r15, %rsi
    call .Lrt_plot2_hsort
    xorl %edx, %edx                 # found
    leaq -1(%r15), %rsi
    xorl %ecx, %ecx                 # k
5:  cmpq %rsi, %rcx
    jae 7f
    movsd 8(%r14,%rcx,8), %xmm0     # s[k+1] - s[k]
    subsd (%r14,%rcx,8), %xmm0
    incq %rcx
    xorpd %xmm1, %xmm1
    ucomisd %xmm1, %xmm0
    jbe 5b                          # not positive
    testl %edx, %edx
    jz 6f
    ucomisd 0(%rsp), %xmm0
    jae 5b                          # not smaller
6:  movsd %xmm0, 0(%rsp)
    movl $1, %edx
    jmp 5b
7:  movq %r14, %rdi                 # free the scratch
    leaq (,%r15,8), %rsi
    call sea_free_block
8:  movsd RTP_SR_WIDTH(%rbx), %xmm0 # hw = (width * Delta) / 2
    mulsd 0(%rsp), %xmm0
    divsd .Lrt_plot2_c_two(%rip), %xmm0
    LEAVE 8

# ---------------------------------------------------------------------
# .Lrt_plot2_hsort -- heap sort of n >= 2 finite f64 values, ascending.
#   Inputs  : %rdi = the values, %rsi = n
#   Clobbers: %rax, %r8 - %r11, %xmm0, %xmm1, flags.  Frame: none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot2_hsort:
    movq %rsi, %r8                  # build: start = n / 2 - 1 down to 0
    shrq $1, %r8
1:  testq %r8, %r8
    jz 2f
    decq %r8
    movq %r8, %r9
    movq %rsi, %r10
    call .Lrt_plot2_sift
    jmp 1b
2:  leaq -1(%rsi), %r8              # end = n - 1 down to 1
3:  testq %r8, %r8
    jz 4f
    movsd (%rdi), %xmm0             # swap a[0], a[end]
    movsd (%rdi,%r8,8), %xmm1
    movsd %xmm1, (%rdi)
    movsd %xmm0, (%rdi,%r8,8)
    xorl %r9d, %r9d                 # sift(0, end)
    movq %r8, %r10
    call .Lrt_plot2_sift
    decq %r8
    jmp 3b
4:  ret

# ---------------------------------------------------------------------
# .Lrt_plot2_sift -- sift a[root] down within a[0 .. len-1] (a max-heap).
#   Inputs  : %rdi = a (f64 elements), %r9 = root, %r10 = len
#   Outputs : a rearranged in place
#   Clobbers: %rax, %r9, %r11, %xmm0, %xmm1, flags
#   Callee-saved used: none
#   Frame   : none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot2_sift:
1:  leaq 1(%r9,%r9), %r11           # child = 2 root + 1
    cmpq %r10, %r11
    jae 9f
    leaq 1(%r11), %rax
    cmpq %r10, %rax
    jae 2f
    movsd (%rdi,%r11,8), %xmm0      # the larger child
    ucomisd (%rdi,%rax,8), %xmm0
    jae 2f
    movq %rax, %r11
2:  movsd (%rdi,%r9,8), %xmm0
    movsd (%rdi,%r11,8), %xmm1
    ucomisd %xmm1, %xmm0
    jae 9f                          # a[root] >= a[child]: done
    movsd %xmm1, (%rdi,%r9,8)
    movsd %xmm0, (%rdi,%r11,8)
    movq %r11, %r9
    jmp 1b
9:  ret

# ---------------------------------------------------------------------
# .Lrt_plot2_span -- the start and length of a span between two clamped
#   ends: %xmm0 = first if first <= second else second; %xmm1 = |second
#   - first|.
#   Inputs  : %xmm0 = first, %xmm1 = second
#   Clobbers: %xmm2, flags.  Frame: none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot2_span:
    movapd %xmm1, %xmm2
    subsd %xmm0, %xmm2              # second - first
    andpd .Lrt_plot2_c_abs(%rip), %xmm2
    ucomisd %xmm1, %xmm0
    jbe 1f
    movapd %xmm1, %xmm0             # first > second: the second
1:  movapd %xmm2, %xmm1
    ret

# ---------------------------------------------------------------------
# .Lrt_plot2_rect -- `<rect class="bar" x="{x}" y="{y}" width="{w}"
#   height="{h}"/>` from .Lrt_plot2_rx, ry, rw, rh.
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbp.  Frame: 8 bytes
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot2_rect:
    pushq %rbp
    movq %rsp, %rbp
    LIT "<rect class=\"bar\""
    call .Lrt_plot2_xywh
    LIT "/>\n"
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_plot2_xywh -- append ` x="{rx}" y="{ry}" width="{rw}"
#   height="{rh}"` (the rectangle in .Lrt_plot2_rx .. .Lrt_plot2_rh).
#   Inputs  : the four rectangle cells
#   Outputs : the attributes appended to the SVG buffer
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbp
#   Frame   : 8 bytes
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot2_xywh:
    pushq %rbp
    movq %rsp, %rbp
    LIT " x=\""
    F2 .Lrt_plot2_rx(%rip)
    LIT "\" y=\""
    F2 .Lrt_plot2_ry(%rip)
    LIT "\" width=\""
    F2 .Lrt_plot2_rw(%rip)
    LIT "\" height=\""
    F2 .Lrt_plot2_rh(%rip)
    LIT "\""
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_plot2_png64 -- base64 of a PNG block straight into the SVG buffer,
#   then the block freed.
#   Inputs  : %rdi = the PNG block, %rsi = its length (= its size)
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = the block, %r12 = its length, %rbp
#   Frame   : 24 bytes
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot2_png64:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12                      # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
    leaq 2(%r12), %rax              # 4 * ceil(len / 3) bytes
    xorl %edx, %edx
    movl $3, %ecx
    divq %rcx
    leaq (,%rax,4), %rdi
    call sea_plt_room
    movq %rax, %rdi
    movq %rbx, %rsi
    movq %r12, %rdx
    call sea_b64
    addq %rax, sea_plt_bufn(%rip)
    movq %rbx, %rdi
    movq %r12, %rsi
    call sea_free_block
    popq %r12
    popq %rbx
    popq %rbp
    ret

# =====================================================================
# Extents (DESIGN.md 2.14.6 "Data extents")
# =====================================================================

# ---------------------------------------------------------------------
# sea_plt2_ext -- the extents of a series of kind 3 - 6: a bar gives x_i -
#   hw, x_i + hw to x and 0, h_i to its y-axis per drawn bar; a barh 0 to x
#   (always), then f64(i) -/+ width / 2 to its y-axis and h_i (if finite) to
#   x for every i; a
#   contour its finite x and y coordinates; an image its four extent ends
#   when it is drawn (READINGS X4, X5, X9).
#   Inputs  : %rdi = the record, %rsi = its y descriptor
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = the record, %r12 = the y descriptor, %r13 =
#             the data, %r14 = n, %r15 = the index, %rbp; locals 0 hw (or
#             width / 2), 8 a, 16 b
#   Frame   : 72 bytes (ENTER 24)
# ---------------------------------------------------------------------
    .globl sea_plt2_ext
    .hidden sea_plt2_ext
    .type sea_plt2_ext, @function
    .p2align 4
sea_plt2_ext:
    ENTER 24
    movq %rdi, %rbx
    movq %rsi, %r12
    movq RTP_SR_DATA(%rbx), %r13
    movq RTP_SR_N(%rbx), %r14
    xorl %r15d, %r15d
    movq RTP_SR_KIND(%rbx), %rax
    cmpq $RTP_SK_BARH, %rax
    je 20f
    cmpq $RTP_SK_CONTOUR, %rax
    je 30f
    cmpq $RTP_SK_IMAGE, %rax
    je 40f
    # A bar series.
    movq %rbx, %rdi
    call .Lrt_plot2_hw
    movsd %xmm0, 0(%rsp)
10: cmpq %r14, %r15
    jae 99f
    movsd (%r13,%r15,8), %xmm0      # x_i
    leaq (%r13,%r14,8), %rdx
    movsd (%rdx,%r15,8), %xmm1      # h_i
    incq %r15
    NONFIN %xmm0, 10b
    NONFIN %xmm1, 10b
    movapd %xmm0, %xmm2
    subsd 0(%rsp), %xmm2            # a = x_i - hw
    NONFIN %xmm2, 10b
    addsd 0(%rsp), %xmm0            # b = x_i + hw
    NONFIN %xmm0, 10b
    movsd %xmm2, 8(%rsp)
    movsd %xmm0, 16(%rsp)
    leaq sea_plt_axd(%rip), %rdi    # a, b to x
    movsd 8(%rsp), %xmm0
    call sea_plt_ext
    leaq sea_plt_axd(%rip), %rdi
    movsd 16(%rsp), %xmm0
    call sea_plt_ext
    movq %r12, %rdi                 # 0, h_i to its y-axis
    xorpd %xmm0, %xmm0
    call sea_plt_ext
    leaq (%r13,%r14,8), %rdx
    movsd -8(%rdx,%r15,8), %xmm0
    movq %r12, %rdi
    call sea_plt_ext
    jmp 10b
    # A barh series: 0 to x first, also with no bar (2.14.6 states no
    # condition for it, unlike a bar's "when a bar is drawn"); width / 2
    # once.
20: leaq sea_plt_axd(%rip), %rdi
    xorpd %xmm0, %xmm0
    call sea_plt_ext
    movsd RTP_SR_WIDTH(%rbx), %xmm0
    divsd .Lrt_plot2_c_two(%rip), %xmm0
    movsd %xmm0, 0(%rsp)
21: cmpq %r14, %r15
    jae 99f
    cvtsi2sdq %r15, %xmm0           # f64(i) - width / 2, f64(i) + width / 2
    movapd %xmm0, %xmm1
    subsd 0(%rsp), %xmm0
    addsd 0(%rsp), %xmm1
    movsd %xmm1, 16(%rsp)
    movq %r12, %rdi
    call sea_plt_ext
    movsd 16(%rsp), %xmm0
    movq %r12, %rdi
    call sea_plt_ext
    leaq sea_plt_axd(%rip), %rdi    # h_i to x (non-finite skipped)
    movsd (%r13,%r15,8), %xmm0
    call sea_plt_ext
    incq %r15
    jmp 21b
    # A contour series: x to x, y to its y-axis.
30: cmpq %r14, %r15
    jae 31f
    leaq sea_plt_axd(%rip), %rdi
    movsd (%r13,%r15,8), %xmm0
    call sea_plt_ext
    incq %r15
    jmp 30b
31: leaq (%r13,%r14,8), %r13        # y
    movq RTP_SR_M(%rbx), %r14
    xorl %r15d, %r15d
32: cmpq %r14, %r15
    jae 99f
    movq %r12, %rdi
    movsd (%r13,%r15,8), %xmm0
    call sea_plt_ext
    incq %r15
    jmp 32b
    # An image series: its four ends when drawn.
40: movq %rbx, %rdi
    call .Lrt_plot2_iext
    testl %eax, %eax
    jz 99f
    movsd %xmm1, 0(%rsp)
    movsd %xmm2, 8(%rsp)
    movsd %xmm3, 16(%rsp)
    leaq sea_plt_axd(%rip), %rdi    # a, b to x (sea_plt_ext keeps the xmm registers)
    call sea_plt_ext
    leaq sea_plt_axd(%rip), %rdi
    movsd 0(%rsp), %xmm0
    call sea_plt_ext
    movq %r12, %rdi                 # a_y, b_y to its y-axis
    movsd 8(%rsp), %xmm0
    call sea_plt_ext
    movq %r12, %rdi
    movsd 16(%rsp), %xmm0
    call sea_plt_ext
99: LEAVE 24
    .size sea_plt2_ext, . - sea_plt2_ext

# =====================================================================
# The element writers (DESIGN.md 2.14.6 "Series forms")
# =====================================================================

# ---------------------------------------------------------------------
# sea_plt2_draw -- the elements of a series of kind 3 - 6 (a tail jump
#   to its writer).
#   Inputs  : %rdi = the record, %rsi = its y-axis (1 or 2)
#   Clobbers: all caller-saved registers.  Frame: the writer's
# ---------------------------------------------------------------------
    .globl sea_plt2_draw
    .hidden sea_plt2_draw
    .type sea_plt2_draw, @function
    .p2align 4
sea_plt2_draw:
    movq RTP_SR_KIND(%rdi), %rax
    cmpq $RTP_SK_BAR, %rax
    je .Lrt_plot2_wbar
    cmpq $RTP_SK_BARH, %rax
    je .Lrt_plot2_wbarh
    cmpq $RTP_SK_CONTOUR, %rax
    je .Lrt_plot2_wcont
    jmp .Lrt_plot2_wimg
    .size sea_plt2_draw, . - sea_plt2_draw

# ---------------------------------------------------------------------
# .Lrt_plot2_wbar -- a bar series: `<g class="bars" fill="{c}">`, per
#   drawn bar `<rect class="bar" .../>` (x and width from X(x_i - hw),
#   X(x_i + hw); y and height from Y(0), Y(h_i); READINGS X7), `</g>`.
#   Inputs  : %rdi = the record, %rsi = its y-axis
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = the record, %r12 = n, %r13 = x, %r14 = the
#             index, %r15 = the y-axis, %rbp; locals 0 hw, 8 a, 16 b,
#             24 X(a), 32 Y(0)
#   Frame   : 88 bytes (ENTER 40)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot2_wbar:
    ENTER 40
    movq %rdi, %rbx
    movq %rsi, %r15
    movq RTP_SR_N(%rbx), %r12
    movq RTP_SR_DATA(%rbx), %r13
    call .Lrt_plot2_gbars
    movq %rbx, %rdi
    call .Lrt_plot2_hw
    movsd %xmm0, 0(%rsp)
    xorl %r14d, %r14d
1:  cmpq %r12, %r14
    jae 9f
    movsd (%r13,%r14,8), %xmm0      # x_i, h_i finite?
    NONFIN %xmm0, 8f
    leaq (%r13,%r12,8), %rdx
    movsd (%rdx,%r14,8), %xmm1
    NONFIN %xmm1, 8f
    movapd %xmm0, %xmm2
    subsd 0(%rsp), %xmm2            # a = x_i - hw
    NONFIN %xmm2, 8f
    addsd 0(%rsp), %xmm0            # b = x_i + hw
    NONFIN %xmm0, 8f
    movsd %xmm2, 8(%rsp)
    movsd %xmm0, 16(%rsp)
    xorl %edi, %edi                 # X(a), X(b): x and width
    movsd 8(%rsp), %xmm0
    call sea_plt_map
    movsd %xmm0, 24(%rsp)
    xorl %edi, %edi
    movsd 16(%rsp), %xmm0
    call sea_plt_map
    movapd %xmm0, %xmm1
    movsd 24(%rsp), %xmm0
    call .Lrt_plot2_span
    movsd %xmm0, .Lrt_plot2_rx(%rip)
    movsd %xmm1, .Lrt_plot2_rw(%rip)
    movq %r15, %rdi                 # Y(0), Y(h_i): y and height
    xorpd %xmm0, %xmm0
    call sea_plt_map
    movsd %xmm0, 32(%rsp)
    leaq (%r13,%r12,8), %rdx
    movsd (%rdx,%r14,8), %xmm0
    movq %r15, %rdi
    call sea_plt_map
    movapd %xmm0, %xmm1
    movsd 32(%rsp), %xmm0
    call .Lrt_plot2_span
    movsd %xmm0, .Lrt_plot2_ry(%rip)
    movsd %xmm1, .Lrt_plot2_rh(%rip)
    call .Lrt_plot2_rect
8:  incq %r14
    jmp 1b
9:  LIT "</g>\n"
    LEAVE 40

# ---------------------------------------------------------------------
# .Lrt_plot2_gbars -- `<g class="bars" fill="{c}">` of the record in
#   %rbx (the caller's), the colour as sea_plt_color writes it.
#   Inputs  : %rbx = the series record (the caller's, kept)
#   Outputs : the opening tag appended to the SVG buffer
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbp
#   Frame   : 8 bytes
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot2_gbars:
    pushq %rbp
    movq %rsp, %rbp
    LIT "<g class=\"bars\" fill=\""
    movq RTP_SR_COLOR(%rbx), %rdi
    call sea_plt_color
    LIT "\">\n"
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_plot2_wbarh -- a barh series: the bar form with the axes
#   exchanged: y and height from Y(f64(i) - width / 2), Y(f64(i) + width
#   / 2), x and width from X(0), X(h_i); drawn when h_i and both ends are
#   finite.
#   Inputs  : %rdi = the record, %rsi = its y-axis
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = the record, %r12 = n, %r13 = h, %r14 = the
#             index, %r15 = the y-axis, %rbp; locals 0 width / 2, 8 a,
#             16 b, 24 Y(a), 32 X(0)
#   Frame   : 88 bytes (ENTER 40)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot2_wbarh:
    ENTER 40
    movq %rdi, %rbx
    movq %rsi, %r15
    movq RTP_SR_N(%rbx), %r12
    movq RTP_SR_DATA(%rbx), %r13
    call .Lrt_plot2_gbars
    movsd RTP_SR_WIDTH(%rbx), %xmm0
    divsd .Lrt_plot2_c_two(%rip), %xmm0
    movsd %xmm0, 0(%rsp)
    xorl %r14d, %r14d
1:  cmpq %r12, %r14
    jae 9f
    movsd (%r13,%r14,8), %xmm1      # h_i finite?
    NONFIN %xmm1, 8f
    cvtsi2sdq %r14, %xmm0
    movapd %xmm0, %xmm2
    subsd 0(%rsp), %xmm2            # a = f64(i) - width / 2
    NONFIN %xmm2, 8f
    addsd 0(%rsp), %xmm0            # b = f64(i) + width / 2
    NONFIN %xmm0, 8f
    movsd %xmm2, 8(%rsp)
    movsd %xmm0, 16(%rsp)
    movq %r15, %rdi                 # Y(a), Y(b): y and height
    movsd 8(%rsp), %xmm0
    call sea_plt_map
    movsd %xmm0, 24(%rsp)
    movq %r15, %rdi
    movsd 16(%rsp), %xmm0
    call sea_plt_map
    movapd %xmm0, %xmm1
    movsd 24(%rsp), %xmm0
    call .Lrt_plot2_span
    movsd %xmm0, .Lrt_plot2_ry(%rip)
    movsd %xmm1, .Lrt_plot2_rh(%rip)
    xorl %edi, %edi                 # X(0), X(h_i): x and width
    xorpd %xmm0, %xmm0
    call sea_plt_map
    movsd %xmm0, 32(%rsp)
    xorl %edi, %edi
    movsd (%r13,%r14,8), %xmm0
    call sea_plt_map
    movapd %xmm0, %xmm1
    movsd 32(%rsp), %xmm0
    call .Lrt_plot2_span
    movsd %xmm0, .Lrt_plot2_rx(%rip)
    movsd %xmm1, .Lrt_plot2_rw(%rip)
    call .Lrt_plot2_rect
8:  incq %r14
    jmp 1b
9:  LIT "</g>\n"
    LEAVE 40

# ---------------------------------------------------------------------
# .Lrt_plot2_wimg -- an image series (2.14.6 "Images", L-kr): when it is
#   drawn, `<image class="image" x y width height ... href="data:image/
#   png;base64,{b}"/>`, the PNG of n x m pixels whose column c holds Z's
#   column c (n - 1 - c when X(a) > X(b)) and row r Z's row m - 1 - r
#   (r when Y(a_y) < Y(b_y)); nothing otherwise.
#   Inputs  : %rdi = the record, %rsi = its y-axis
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = the record, %r12 = the raw block, %r13 =
#             the write cursor, %r14 = r, %r15 = c, %rbp; locals 0 the
#             y-axis, 8 n, 16 m, 24 Z, 32 columns reversed, 40 rows
#             reversed (row r is Z's m - 1 - r), 48 the raw size, 56 a,
#             64 b, 72 a_y, 80 b_y
#   Frame   : 136 bytes (ENTER 88)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot2_wimg:
    ENTER 88
    movq %rdi, %rbx
    movq %rsi, 0(%rsp)
    call .Lrt_plot2_iext
    testl %eax, %eax
    jz 99f                          # no cell or a non-finite end: nothing
    movsd %xmm0, 56(%rsp)
    movsd %xmm1, 64(%rsp)
    movsd %xmm2, 72(%rsp)
    movsd %xmm3, 80(%rsp)
    movq RTP_SR_N(%rbx), %rax
    movq %rax, 8(%rsp)
    movq RTP_SR_M(%rbx), %rcx
    movq %rcx, 16(%rsp)
    addq %rcx, %rax
    movq RTP_SR_DATA(%rbx), %rdx
    leaq (%rdx,%rax,8), %rdx
    movq %rdx, 24(%rsp)             # Z
    # X(a), X(b): x, width and the column order.
    xorl %edi, %edi
    movsd 56(%rsp), %xmm0
    call sea_plt_map
    movsd %xmm0, 56(%rsp)
    xorl %edi, %edi
    movsd 64(%rsp), %xmm0
    call sea_plt_map
    movsd %xmm0, 64(%rsp)
    movapd %xmm0, %xmm1
    movsd 56(%rsp), %xmm0
    xorl %eax, %eax
    ucomisd %xmm1, %xmm0
    seta %al                        # X(a) > X(b): columns reversed
    movq %rax, 32(%rsp)
    call .Lrt_plot2_span
    movsd %xmm0, .Lrt_plot2_rx(%rip)
    movsd %xmm1, .Lrt_plot2_rw(%rip)
    # Y(a_y), Y(b_y): y, height and the row order.
    movq 0(%rsp), %rdi
    movsd 72(%rsp), %xmm0
    call sea_plt_map
    movsd %xmm0, 72(%rsp)
    movq 0(%rsp), %rdi
    movsd 80(%rsp), %xmm0
    call sea_plt_map
    movapd %xmm0, %xmm1
    movsd 72(%rsp), %xmm0
    xorl %eax, %eax
    ucomisd %xmm1, %xmm0
    setae %al                       # Y(a_y) >= Y(b_y): row r is Z's m - 1 - r
    movq %rax, 40(%rsp)
    call .Lrt_plot2_span
    movsd %xmm0, .Lrt_plot2_ry(%rip)
    movsd %xmm1, .Lrt_plot2_rh(%rip)
    # The colours: the range, the map; the raw data m * (1 + 3n).
    movq %rbx, %rdi
    call .Lrt_plot2_zrange
    xorl %edi, %edi
    call sea_plt_cmap               # (builds the table at the first use)
    movq 8(%rsp), %rax
    leaq 1(%rax,%rax,2), %rax
    imulq 16(%rsp), %rax
    movq %rax, 48(%rsp)
    movq %rax, %rdi
    movq sea_plt_site(%rip), %rsi
    call sea_alloc
    movq %rax, %r12
    movq %rax, %r13
    xorl %r14d, %r14d               # r
1:  cmpq 16(%rsp), %r14
    jae 5f
    movb $0, (%r13)                 # the filter byte
    incq %r13
    movq %r14, %r8                  # Z's row i
    cmpq $0, 40(%rsp)
    je 2f
    movq 16(%rsp), %r8
    decq %r8
    subq %r14, %r8                  # m - 1 - r
2:  xorl %r15d, %r15d               # c
3:  cmpq 8(%rsp), %r15
    jae 4f
    movq %r15, %rax                 # Z's column j
    cmpq $0, 32(%rsp)
    je 31f
    movq 8(%rsp), %rax
    decq %rax
    subq %r15, %rax                 # n - 1 - c
31: imulq 16(%rsp), %rax            # Z[i, j] at j * m + i
    addq %r8, %rax
    movq 24(%rsp), %rdx
    movsd (%rdx,%rax,8), %xmm0
    call .Lrt_plot2_zcol            # (keeps %r8)
    movb %al, 2(%r13)               # B, G, R
    shrl $8, %eax
    movb %al, 1(%r13)
    shrl $8, %eax
    movb %al, (%r13)
    addq $3, %r13
    incq %r15
    jmp 3b
4:  incq %r14
    jmp 1b
5:  movq %r12, %rdi                 # the PNG, the raw block freed
    movq 8(%rsp), %rsi
    movq 16(%rsp), %rdx
    movq sea_plt_site(%rip), %rcx
    call sea_png
    movq %rax, %r14
    movq %rdx, %r15
    movq %r12, %rdi
    movq 48(%rsp), %rsi
    call sea_free_block
    LIT "<image class=\"image\""
    call .Lrt_plot2_xywh
    LIT " preserveAspectRatio=\"none\" style=\"image-rendering:pixelated\" href=\"data:image/png;base64,"
    movq %r14, %rdi
    movq %r15, %rsi
    call .Lrt_plot2_png64
    LIT "\"/>\n"
99: LEAVE 88

# ---------------------------------------------------------------------
# .Lrt_plot2_wcont -- a contour series (2.14.6 "Contours", L-ks): `<g
#   class="contour" fill="none" stroke-width="1.00">`; per level k = 1 ..
#   n with a segment `<g class="contour-level" stroke="{c}">`, its
#   segments, `</g>`; then `</g>`; then with labels: true one label per
#   such level at its first segment's midpoint, `%g` of the level. No
#   level when the range is degenerate; a non-finite level is no level.
#   Inputs  : %rdi = the record, %rsi = its y-axis
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = the record, %r12 = k, %r13 = n (levels),
#             %r14 = the y-axis, %r15 = the pass (0 segments, 1 labels),
#             %rbp; locals 0 L, 8 the buffer length before the level's
#             group
#   Frame   : 72 bytes (ENTER 24)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot2_wcont:
    ENTER 24
    movq %rdi, %rbx
    movq %rsi, %r14
    movq RTP_SR_LEVELS(%rbx), %r13
    LIT "<g class=\"contour\" fill=\"none\" stroke-width=\"1.00\">\n"
    movq %rbx, %rdi
    call .Lrt_plot2_zrange
    xorl %edi, %edi
    call sea_plt_cmap
    xorl %r15d, %r15d               # pass 0: the segments
    cmpq $0, .Lrt_plot2_zdeg(%rip)
    jne 7f                          # no level
1:  movl $1, %r12d                  # k = 1 .. n
2:  cmpq %r13, %r12
    ja 6f
    call .Lrt_plot2_level           # %xmm0 = L_k (zmin + (f64(k) d) / f64(n + 1))
    NONFIN %xmm0, 5f                # not finite: no level
    movsd %xmm0, 0(%rsp)
    testq %r15, %r15
    jnz 4f
    movq sea_plt_bufn(%rip), %rax   # pass 0: the group, its segments
    movq %rax, 8(%rsp)
    LIT "<g class=\"contour-level\" stroke=\""
    movq RTP_SR_COLOR(%rbx), %rdi
    cmpq $-1, %rdi
    jne 3f
    movl $256, %eax                 # the map entry floor(256 k / (n + 1))
    mulq %r12
    leaq 1(%r13), %rcx
    divq %rcx
    movl %eax, %edi
    call sea_plt_cmap
    movl %eax, %edi
3:  call sea_plt_color
    LIT "\">\n"
    movq %rbx, %rdi
    movsd 0(%rsp), %xmm0
    movq %r14, %rsi
    xorl %edx, %edx
    call .Lrt_plot2_march           # %rax = the segments written
    testq %rax, %rax
    jnz 31f
    movq 8(%rsp), %rax              # none: the group is taken back
    movq %rax, sea_plt_bufn(%rip)
    jmp 5f
31: LIT "</g>\n"
    jmp 5f
4:  movq %rbx, %rdi                 # pass 1: the first segment's midpoint
    movsd 0(%rsp), %xmm0
    movq %r14, %rsi
    movl $1, %edx
    call .Lrt_plot2_march
    testq %rax, %rax
    jz 5f                           # the level has no segment
    LIT "<text class=\"contour-label\" x=\""
    F2 .Lrt_plot2_mx(%rip)
    LIT "\" y=\""
    F2 .Lrt_plot2_my(%rip)
    LIT "\" font-size=\"10\" text-anchor=\"middle\">"
    movl $RTP_NUMBUF, %edi          # %g of the level
    call sea_plt_room
    movq %rax, %rdi
    movl $103, %esi                 # 'g'
    movl $6, %edx
    movsd 0(%rsp), %xmm0
    call sea_fmt_num
    addq %rax, sea_plt_bufn(%rip)
    LIT "</text>\n"
5:  incq %r12
    jmp 2b
6:  testq %r15, %r15
    jnz 9f                          # the labels are done
    LIT "</g>\n"
    cmpq $0, RTP_SR_FLAG(%rbx)
    je 9f
    movl $1, %r15d                  # pass 1: the labels
    jmp 1b
7:  LIT "</g>\n"                    # no level: the empty group
9:  LEAVE 24

# ---------------------------------------------------------------------
# .Lrt_plot2_level -- the contour level L_k = zmin + (f64(k) * d) /
#   f64(n + 1) with d = zmax - zmin.
#   Inputs  : %r12 = k, %r13 = n (the caller's, read only), the cells
#             .Lrt_plot2_zlo and .Lrt_plot2_zhi
#   Outputs : %xmm0 = L_k
#   Clobbers: %rax, %xmm0, %xmm1
#   Callee-saved used: none (reads %r12, %r13)
#   Frame   : none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot2_level:
    movsd .Lrt_plot2_zhi(%rip), %xmm1
    subsd .Lrt_plot2_zlo(%rip), %xmm1 # d
    cvtsi2sdq %r12, %xmm0
    mulsd %xmm1, %xmm0              # f64(k) * d
    leaq 1(%r13), %rax
    cvtsi2sdq %rax, %xmm1
    divsd %xmm1, %xmm0              # / f64(n + 1)
    addsd .Lrt_plot2_zlo(%rip), %xmm0 # zmin + (...) (= (...) + zmin exactly)
    ret

# ---------------------------------------------------------------------
# .Lrt_plot2_march -- marching squares of one level (2.14.6 "Contour
#   levels and marching squares"): cells column-major (j outer, i inner);
#   a cell with a non-finite corner value or coordinate is skipped; a
#   corner is above when its value >= L; edges e0 a-b, e1 b-c, e2 d-c, e3
#   a-d, crossed when their corners differ; two crossed edges give one
#   segment (the lower edge's point first), four (the saddles) two, by
#   the centre ((a + b) + (c + d)) / 4 against a's state.
#   Mode 0 writes every segment's `<line>`; mode 1 stops at the first
#   segment and stores its clamped midpoint in .Lrt_plot2_mx, my.
#   Inputs  : %rdi = the record, %xmm0 = L, %rsi = the y-axis, %edx = mode
#   Outputs : %rax = the segments written (mode 1: 1 if one was found)
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = j, %r12 = i, %r13 = the count, %r14 = the
#             mode, %r15 = the corner states, %rbp; locals (RTP_MS_*):
#             L, the y-axis, n, m, x, y, Z, the corner values cz[4] (a b
#             c d), their x cx[4] and y cy[4], the segment's ends
#   Frame   : 312 bytes (ENTER 264)
# ---------------------------------------------------------------------
.equ RTP_MS_L,          0
.equ RTP_MS_YAX,        8
.equ RTP_MS_N,          16
.equ RTP_MS_M,          24
.equ RTP_MS_X,          32
.equ RTP_MS_Y,          40
.equ RTP_MS_Z,          48
.equ RTP_MS_CZ,         56          # a b c d
.equ RTP_MS_CX,         88          # x of a b c d
.equ RTP_MS_CY,         120         # y of a b c d
.equ RTP_MS_P,          152         # an edge point (x, y)
.equ RTP_MS_X1,         232
.equ RTP_MS_Y1,         240
.equ RTP_MS_X2,         248
.equ RTP_MS_Y2,         256
.equ RTP_MS_LOC,        264
    .p2align 4
.Lrt_plot2_march:
    ENTER RTP_MS_LOC
    movsd %xmm0, RTP_MS_L(%rsp)
    movq %rsi, RTP_MS_YAX(%rsp)
    movl %edx, %r14d
    movq RTP_SR_N(%rdi), %rax
    movq %rax, RTP_MS_N(%rsp)
    movq RTP_SR_M(%rdi), %rcx
    movq %rcx, RTP_MS_M(%rsp)
    movq RTP_SR_DATA(%rdi), %rdx
    movq %rdx, RTP_MS_X(%rsp)
    leaq (%rdx,%rax,8), %rdx
    movq %rdx, RTP_MS_Y(%rsp)
    leaq (%rdx,%rcx,8), %rdx
    movq %rdx, RTP_MS_Z(%rsp)
    xorl %r13d, %r13d
    xorl %ebx, %ebx                 # j = 0 .. n - 2
1:  leaq 1(%rbx), %rax
    cmpq RTP_MS_N(%rsp), %rax
    jae 90f
    xorl %r12d, %r12d               # i = 0 .. m - 2
2:  leaq 1(%r12), %rax
    cmpq RTP_MS_M(%rsp), %rax
    jae 80f
    # The corners: a (x[j], y[i]), b (x[j+1], y[i]), c (x[j+1], y[i+1]),
    # d (x[j], y[i+1]); Z[i, j] at j * m + i.
    movq RTP_MS_X(%rsp), %rdx
    movsd (%rdx,%rbx,8), %xmm0      # x[j]
    movsd 8(%rdx,%rbx,8), %xmm1     # x[j+1]
    movq RTP_MS_Y(%rsp), %rdx
    movsd (%rdx,%r12,8), %xmm2      # y[i]
    movsd 8(%rdx,%r12,8), %xmm3     # y[i+1]
    movsd %xmm0, RTP_MS_CX(%rsp)
    movsd %xmm1, RTP_MS_CX + 8(%rsp)
    movsd %xmm1, RTP_MS_CX + 16(%rsp)
    movsd %xmm0, RTP_MS_CX + 24(%rsp)
    movsd %xmm2, RTP_MS_CY(%rsp)
    movsd %xmm2, RTP_MS_CY + 8(%rsp)
    movsd %xmm3, RTP_MS_CY + 16(%rsp)
    movsd %xmm3, RTP_MS_CY + 24(%rsp)
    movq %rbx, %rax
    imulq RTP_MS_M(%rsp), %rax
    addq %r12, %rax
    movq RTP_MS_Z(%rsp), %rdx
    leaq (%rdx,%rax,8), %rdx        # &Z[i, j]
    movq RTP_MS_M(%rsp), %rax
    movsd (%rdx), %xmm4             # a
    movsd 8(%rdx), %xmm7            # d = Z[i+1, j]
    leaq (%rdx,%rax,8), %rdx        # &Z[i, j+1]
    movsd (%rdx), %xmm5             # b
    movsd 8(%rdx), %xmm6            # c = Z[i+1, j+1]
    movsd %xmm4, RTP_MS_CZ(%rsp)
    movsd %xmm5, RTP_MS_CZ + 8(%rsp)
    movsd %xmm6, RTP_MS_CZ + 16(%rsp)
    movsd %xmm7, RTP_MS_CZ + 24(%rsp)
    NONFIN %xmm0, 70f               # any non-finite corner value or coordinate
    NONFIN %xmm1, 70f
    NONFIN %xmm2, 70f
    NONFIN %xmm3, 70f
    NONFIN %xmm4, 70f
    NONFIN %xmm5, 70f
    NONFIN %xmm6, 70f
    NONFIN %xmm7, 70f
    # The states: bit 0 a, 1 b, 2 c, 3 d above (value >= L).
    movsd RTP_MS_L(%rsp), %xmm0
    xorl %r15d, %r15d
    xorl %ecx, %ecx
3:  movsd RTP_MS_CZ(%rsp,%rcx,8), %xmm1
    ucomisd %xmm0, %xmm1
    jb 4f
    btsl %ecx, %r15d
4:  incl %ecx
    cmpl $4, %ecx
    jb 3b
    # The crossed edges: e0 a/b, e1 b/c, e2 d/c, e3 a/d.
    movl %r15d, %eax
    shrl $1, %eax
    xorl %r15d, %eax                # bit 0: a ^ b, bit 1: b ^ c, bit 2: c ^ d
    andl $7, %eax
    movl %eax, %ecx
    andl $3, %ecx                   # e0, e1
    movl %eax, %edx
    andl $4, %edx                   # c ^ d -> e2
    orl %edx, %ecx
    movl %r15d, %edx
    shrl $3, %edx
    xorl %r15d, %edx
    andl $1, %edx                   # a ^ d -> e3
    shll $3, %edx
    orl %edx, %ecx                  # the crossed edges' mask
    jz 70f                          # none
    cmpl $5, %r15d                  # a, c above, b, d not: a saddle
    je 50f
    cmpl $10, %r15d                 # b, d above, a, c not: a saddle
    je 50f
    bsfl %ecx, %edi                 # two edges: the lower first
    bsrl %ecx, %esi
    call .Lrt_plot2_seg
    incq %r13
    testl %r14d, %r14d
    jnz 90f                         # mode 1: the first segment
    jmp 70f
    # A saddle: the centre's state against a's.
50: movsd RTP_MS_CZ(%rsp), %xmm1    # m = ((a + b) + (c + d)) / 4
    addsd RTP_MS_CZ + 8(%rsp), %xmm1
    movsd RTP_MS_CZ + 16(%rsp), %xmm2
    addsd RTP_MS_CZ + 24(%rsp), %xmm2
    addsd %xmm2, %xmm1
    divsd .Lrt_plot2_c_four(%rip), %xmm1
    xorl %eax, %eax
    ucomisd RTP_MS_L(%rsp), %xmm1
    setae %al                       # the centre's state
    movl %r15d, %ecx
    andl $1, %ecx                   # a's
    cmpl %ecx, %eax
    jne 60f
    xorl %edi, %edi                 # equal: (e0, e1), (e2, e3)
    movl $1, %esi
    call .Lrt_plot2_seg
    incq %r13
    testl %r14d, %r14d
    jnz 90f
    movl $2, %edi
    movl $3, %esi
    call .Lrt_plot2_seg
    incq %r13
    jmp 70f
60: xorl %edi, %edi                 # different: (e0, e3), (e1, e2)
    movl $3, %esi
    call .Lrt_plot2_seg
    incq %r13
    testl %r14d, %r14d
    jnz 90f
    movl $1, %edi
    movl $2, %esi
    call .Lrt_plot2_seg
    incq %r13
70: incq %r12
    jmp 2b
80: incq %rbx
    jmp 1b
90: movq %r13, %rax
    LEAVE RTP_MS_LOC

# ---------------------------------------------------------------------
# .Lrt_plot2_seg -- one segment of .Lrt_plot2_march's cell from edge e1's
#   point to edge e2's: both points mapped and clamped; mode 0 writes
#   `<line class="contour-segment" x1 y1 x2 y2/>`, mode 1 stores the
#   midpoint ((X1 + X2) / 2, (Y1 + Y2) / 2).
#   Inputs  : %edi = e1, %esi = e2; the march's locals (32 bytes above
#             this routine's %rsp after its pushes) and %r14 (the mode)
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = the march's locals, %r12 = e2, %rbp
#   Frame   : 24 bytes (%rbp %rbx %r12)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot2_seg:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12                      # %rsp = 0 (mod 16)
    leaq 32(%rsp), %rbx             # the march's locals (3 pushes + the return address)
    movl %esi, %r12d
    call .Lrt_plot2_ept             # e1: the point, then X1, Y1
    xorl %edi, %edi
    movsd RTP_MS_P(%rbx), %xmm0
    call sea_plt_map
    movsd %xmm0, RTP_MS_X1(%rbx)
    movq RTP_MS_YAX(%rbx), %rdi
    movsd RTP_MS_P + 8(%rbx), %xmm0
    call sea_plt_map
    movsd %xmm0, RTP_MS_Y1(%rbx)
    movl %r12d, %edi                # e2: X2, Y2
    call .Lrt_plot2_ept
    xorl %edi, %edi
    movsd RTP_MS_P(%rbx), %xmm0
    call sea_plt_map
    movsd %xmm0, RTP_MS_X2(%rbx)
    movq RTP_MS_YAX(%rbx), %rdi
    movsd RTP_MS_P + 8(%rbx), %xmm0
    call sea_plt_map
    movsd %xmm0, RTP_MS_Y2(%rbx)
    testl %r14d, %r14d
    jnz 5f
    LIT "<line class=\"contour-segment\" x1=\""
    F2 RTP_MS_X1(%rbx)
    LIT "\" y1=\""
    F2 RTP_MS_Y1(%rbx)
    LIT "\" x2=\""
    F2 RTP_MS_X2(%rbx)
    LIT "\" y2=\""
    F2 RTP_MS_Y2(%rbx)
    LIT "\"/>\n"
    jmp 9f
5:  movsd RTP_MS_X1(%rbx), %xmm0    # the midpoint of the clamped ends
    addsd RTP_MS_X2(%rbx), %xmm0
    divsd .Lrt_plot2_c_two(%rip), %xmm0
    movsd %xmm0, .Lrt_plot2_mx(%rip)
    movsd RTP_MS_Y1(%rbx), %xmm0
    addsd RTP_MS_Y2(%rbx), %xmm0
    divsd .Lrt_plot2_c_two(%rip), %xmm0
    movsd %xmm0, .Lrt_plot2_my(%rip)
9:  popq %r12
    popq %rbx
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_plot2_ept -- the point of edge %edi (0 .. 3) of the march's cell:
#   from its first corner p1, z1 to its second p2, z2, t = (L - z1) /
#   (z2 - z1), x = p1x + t * (p2x - p1x), y = p1y + t * (p2y - p1y).
#   Inputs  : %edi = the edge, %rbx = the march's locals (the cell)
#   Outputs : (x, y) stored at RTP_MS_P(%rbx)
#   Clobbers: %rax, %rcx, %rdx, %xmm0 - %xmm3
#   Callee-saved used: none (reads %rbx)
#   Frame   : none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot2_ept:
    leaq .Lrt_plot2_edges(%rip), %rax
    movzbl (%rax,%rdi,2), %ecx      # the first corner
    movzbl 1(%rax,%rdi,2), %edx     # the second
    movsd RTP_MS_L(%rbx), %xmm0     # t
    subsd RTP_MS_CZ(%rbx,%rcx,8), %xmm0
    movsd RTP_MS_CZ(%rbx,%rdx,8), %xmm1
    subsd RTP_MS_CZ(%rbx,%rcx,8), %xmm1
    divsd %xmm1, %xmm0
    movsd RTP_MS_CX(%rbx,%rdx,8), %xmm2 # x
    subsd RTP_MS_CX(%rbx,%rcx,8), %xmm2
    mulsd %xmm0, %xmm2
    addsd RTP_MS_CX(%rbx,%rcx,8), %xmm2 # (= p1x + t * (...) exactly)
    movsd %xmm2, RTP_MS_P(%rbx)
    movsd RTP_MS_CY(%rbx,%rdx,8), %xmm3 # y
    subsd RTP_MS_CY(%rbx,%rcx,8), %xmm3
    mulsd %xmm0, %xmm3
    addsd RTP_MS_CY(%rbx,%rcx,8), %xmm3
    movsd %xmm3, RTP_MS_P + 8(%rbx)
    ret

# =====================================================================
# The colorbar (2.14.6 item 9, L-ko)
# =====================================================================

# ---------------------------------------------------------------------
# sea_plt2_colorbar -- item 9 for the pair's last image with colorbar:
#   true (sea_plt_cbar): at xc = (px + pw) + 12 (+ 52 with a twin), the
#   1 x 256 PNG (row r the map entry 255 - r), its box, its tick marks
#   `M{xc+12} {Y} h-3.00` and the `ctick` labels; the ticks those of an
#   explicit-limit axis over the image's finite min .. max (widened as
#   rule 4 when empty or of zero width), mapped like a y-axis (the
#   fourth axis descriptor).
#   Inputs  : sea_plt_cbar, sea_plt_trec, the layout
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = the descriptor, %r12 = the tick index,
#             %r13 = first (1 until a path piece is written), %rbp;
#             locals 0 xc, 8 the tick's Y, 16 its text, 24 its length
#   Frame   : 88 bytes (ENTER 40)
# ---------------------------------------------------------------------
    .globl sea_plt2_colorbar
    .hidden sea_plt2_colorbar
    .type sea_plt2_colorbar, @function
    .p2align 4
sea_plt2_colorbar:
    ENTER 40
    movsd sea_plt_px(%rip), %xmm0   # xc = (px + pw) + 12
    addsd sea_plt_pw(%rip), %xmm0
    addsd .Lrt_plot2_c_12(%rip), %xmm0
    cmpq $0, sea_plt_trec(%rip)
    je 1f
    addsd .Lrt_plot2_c_52(%rip), %xmm0 # + 52 with a twin
1:  movsd %xmm0, 0(%rsp)
    # The axis: the image's finite range, widened as rule 4, inside ticks.
    movq sea_plt_cbar(%rip), %rdi
    call .Lrt_plot2_zrange
    leaq (sea_plt_axd + RTP_AXIS_CB * RTP_A_SIZE)(%rip), %rbx
    movq %rbx, %rdi                 # cleared
    movl $(RTP_A_SIZE / 8), %ecx
    xorl %eax, %eax
    rep stosq
    movq .Lrt_plot2_zhas(%rip), %rax
    movq %rax, RTP_A_EHAS(%rbx)
    movq .Lrt_plot2_zlo(%rip), %rax
    movq %rax, RTP_A_ELO(%rbx)
    movq .Lrt_plot2_zhi(%rip), %rax
    movq %rax, RTP_A_EHI(%rbx)
    movq %rbx, %rdi
    call sea_plt_widen
    movsd %xmm0, RTP_A_LO(%rbx)
    movsd %xmm1, RTP_A_HI(%rbx)
    movq %rbx, %rdi
    call sea_plt_inside
    movq %rbx, %rdi
    call sea_plt_texts
    # The strip: a 1 x 256 PNG, row r the map entry 255 - r.
    xorl %edi, %edi
    call sea_plt_cmap
    movl $(4 * RTP_CB_N), %edi      # the raw data (1 + 3 bytes per row), uncounted
    movq sea_plt_site(%rip), %rsi
    call sea_alloc
    movq %rax, 32(%rsp)             # kept for the PNG and its release
    movq %rax, %rdi
    xorl %ecx, %ecx                 # r
2:  movl $255, %eax
    subl %ecx, %eax
    leaq .Lrt_plot2_cmtab(%rip), %rdx
    movl (%rdx,%rax,4), %eax
    movb $0, (%rdi)                 # the filter byte, then B, G, R
    movb %al, 3(%rdi)
    shrl $8, %eax
    movb %al, 2(%rdi)
    shrl $8, %eax
    movb %al, 1(%rdi)
    addq $4, %rdi
    incl %ecx
    cmpl $RTP_CB_N, %ecx
    jb 2b
    LIT "<image class=\"colorbar\" x=\""
    F2 0(%rsp)
    LIT "\" y=\""
    F2 sea_plt_py(%rip)
    LIT "\" width=\"12.00\" height=\""
    F2 sea_plt_ph(%rip)
    LIT "\" preserveAspectRatio=\"none\" style=\"image-rendering:pixelated\" href=\"data:image/png;base64,"
    movq 32(%rsp), %rdi
    movl $1, %esi
    movl $RTP_CB_N, %edx
    movq sea_plt_site(%rip), %rcx
    call sea_png
    movq %rax, %r12                 # the PNG (the tick loop reuses %r12 later)
    movq %rdx, %r13
    movq 32(%rsp), %rdi             # the raw block released
    movl $(4 * RTP_CB_N), %esi
    call sea_free_block
    movq %r12, %rdi
    movq %r13, %rsi
    call .Lrt_plot2_png64
    LIT "\"/>\n<rect class=\"colorbar-box\" x=\""
    F2 0(%rsp)
    LIT "\" y=\""
    F2 sea_plt_py(%rip)
    LIT "\" width=\"12.00\" height=\""
    F2 sea_plt_ph(%rip)
    LIT "\" fill=\"none\" stroke=\"#262626\" stroke-width=\"1.00\"/>\n"
    # The tick marks `M{xc+12} {Y} h-3.00`, joined by one space.
    LIT "<path class=\"colorbar-ticks\" d=\""
    movl $1, %r13d
    xorl %r12d, %r12d
3:  cmpq RTP_A_NT(%rbx), %r12
    jae 4f
    movl $RTP_AXIS_CB, %edi
    movq %r12, %rsi
    call sea_plt_tick
    movsd %xmm0, 8(%rsp)
    testl %r13d, %r13d
    jnz 31f
    LIT " "
31: xorl %r13d, %r13d
    LIT "M"
    movsd 0(%rsp), %xmm0
    addsd .Lrt_plot2_c_12(%rip), %xmm0
    call sea_plt_f2
    LIT " "
    F2 8(%rsp)
    LIT " h-3.00"
    incq %r12
    jmp 3b
4:  LIT "\" fill=\"none\" stroke=\"#262626\" stroke-width=\"1.00\"/>\n"
    # The labels.
    xorl %r12d, %r12d
5:  cmpq RTP_A_NT(%rbx), %r12
    jae 9f
    movl $RTP_AXIS_CB, %edi
    movq %r12, %rsi
    call sea_plt_tick
    movsd %xmm0, 8(%rsp)
    movq %rax, 16(%rsp)
    movq %rdx, 24(%rsp)
    LIT "<text class=\"ctick\" x=\""
    movsd 0(%rsp), %xmm0            # xc + 16
    addsd .Lrt_plot2_c_16(%rip), %xmm0
    call sea_plt_f2
    LIT "\" y=\""
    movsd 8(%rsp), %xmm0            # Y + 3.5
    addsd .Lrt_plot2_c_35(%rip), %xmm0
    call sea_plt_f2
    LIT "\" font-size=\"10\" text-anchor=\"start\">"
    movq 16(%rsp), %rdi             # a numeric text: as it is
    movq 24(%rsp), %rsi
    call sea_plt_put
    LIT "</text>\n"
    incq %r12
    jmp 5b
9:  LEAVE 40
    .size sea_plt2_colorbar, . - sea_plt2_colorbar

# =====================================================================
# Constant data
# =====================================================================
    .section .rodata
    .p2align 4
.Lrt_plot2_c_abs:   .quad RTP_B_ABS, 0
.Lrt_plot2_c_one:   .quad 0x3FF0000000000000 # 1.0
.Lrt_plot2_c_two:   .quad 0x4000000000000000 # 2.0
.Lrt_plot2_c_four:  .quad 0x4010000000000000 # 4.0
.Lrt_plot2_c_half:  .quad 0x3FE0000000000000 # 0.5
.Lrt_plot2_c_12:    .quad 0x4028000000000000 # 12.0
.Lrt_plot2_c_16:    .quad 0x4030000000000000 # 16.0
.Lrt_plot2_c_35:    .quad 0x400C000000000000 # 3.5
.Lrt_plot2_c_52:    .quad 0x404A000000000000 # 52.0
.Lrt_plot2_c_255:   .quad 0x406FE00000000000 # 255.0
.Lrt_plot2_c_256:   .quad 0x4070000000000000 # 256.0
# The colour map's anchors A0 .. A4 (LANGUAGE.md 12.6), R G B each.
.Lrt_plot2_anchor:
    .byte 0x30, 0x12, 0x3B, 0x46, 0x86, 0xFB, 0x1A, 0xE4, 0xB6
    .byte 0xFA, 0xBA, 0x39, 0x7A, 0x04, 0x03
# The edges' corners (indices into a b c d): e0 a-b, e1 b-c, e2 d-c, e3 a-d.
.Lrt_plot2_edges:
    .byte 0, 1, 1, 2, 3, 2, 0, 3

# =====================================================================
# State (one thread; nothing here recurses)
# =====================================================================
    .bss
    .p2align 3
.Lrt_plot2_cmok:  .zero 8           # 1 once the colour map table is built
.Lrt_plot2_zlo:   .zero 8           # f64 the finite range of the series' Z
.Lrt_plot2_zhi:   .zero 8
.Lrt_plot2_zhas:  .zero 8           # 1 when Z has a finite cell
.Lrt_plot2_zdeg:  .zero 8           # 1 when the range is degenerate
.Lrt_plot2_rx:    .zero 8           # f64 the rectangle being written
.Lrt_plot2_ry:    .zero 8
.Lrt_plot2_rw:    .zero 8
.Lrt_plot2_rh:    .zero 8
.Lrt_plot2_mx:    .zero 8           # f64 a level's first segment's midpoint
.Lrt_plot2_my:    .zero 8
.Lrt_plot2_cmtab: .zero 4 * 256     # the colour map, 0xRRGGBB per entry

    .section .note.GNU-stack,"",@progbits
