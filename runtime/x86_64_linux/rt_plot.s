# =====================================================================
# sea/runtime/x86_64_linux/rt_plot.s -- the plotting library's core:
# the Figure and Axes objects, the entries FIGURE PANEL TWIN_Y SAVE_SVG
# PLOT XLINE and the eleven property entries, the layout, the limits
# and ticks, the SVG writer and the legend (LANGUAGE.md 12; DESIGN.md
# 2.14.2, 2.14.5, 2.14.6; L-ke - L-lf). The x86_64-linux twin of
# runtime/arm64_macos/rt_plot.s: the same layouts, operations and bytes.
#
# Defines (global, rt.inc SEA_ENTRY_LIST, ids 62 - 67 and 72 - 82):
#   sea_figure     (nrows, ncols, name, width, height, site) -> Figure
#   sea_panel      (fig, row, col, rowspan, colspan, site) -> Axes
#   sea_twin_y     (ax, site) -> Axes
#   sea_save_svg   (fig, path, site)
#   sea_plot       (ax, x, y, style, label, color, site on the stack;
#                  width in %xmm0)
#   sea_xline      (ax, style, color, site; x in %xmm0)
#   sea_xlabel sea_ylabel sea_title (ax, s)
#   sea_legend     (ax, loc, site)
#   sea_grid       (ax, on)
#   sea_xlim sea_ylim (ax, site; lo, hi in %xmm0, %xmm1)
#   sea_x_ticks sea_y_ticks (ax, labels, site)
#   sea_y_reverse sea_axis_equal (ax)
# The entries of 9c (BAR, BARH, CONTOUR, IMAGE) are in rt_plot2.s; this
# file draws kinds 1 (line) and 2 (xline) and hands the series kinds 3 - 6
# to rt_plot2.s for their extents (sea_plt2_ext) and elements
# (sea_plt2_draw), and the colorbar of item 9 (sea_plt2_colorbar).
# Shared with rt_plot2.s (.globl + .hidden, private to the runtime, named
# sea_plt_*: aliases of the local routines and the writer's state below,
# so this file's own code and bytes are unchanged by them): the routines
# raise recs grow colorarg rescol room put f2 color map ext widen inside
# texts tick floor, and the state site bufp bufn px py pw ph axd trec cbar.
# Uses: sea_alloc, sea_free_block, sea_retain, sea_release, sea_live
#   (rt_mem.s); sea_err (rt_err.s); sea_fmt_num (rt_fmt.s); sea_file_put
#   (rt_file.s); sea_plt2_ext, sea_plt2_draw, sea_plt2_colorbar
#   (rt_plot2.s); glibc memcpy through the PLT.
#
# OBJECTS (DESIGN.md 2.14.6 "Objects", L-ke, L-kf; the offsets RTP_* are
# the same in both runtimes and read by tests/rt): a Figure is one
# RTP_FG_SIZE block holding the grid, size, name, the axes table, the
# series table and the occupancy map; an Axes is one RTP_AH_SIZE block
# holding a counted reference to its figure and an axes record index.
# Every other block (tables, data copies, label lists, the SVG buffer)
# comes from sea_alloc uncounted and is freed by its exact size. Both
# tables start with RTP_CAP0 records and double (a new block, the records
# copied, the old block freed) when full.
#
# SAVE_SVG builds the whole document in one growing buffer (RTP_BUF0
# bytes, doubled by copy when full), then sea_file_put writes it and
# frees the buffer, before an error is reported too (L-lc). The writer's state (the buffer, the panel
# being written, its layout and its three axis descriptors) is private
# static storage: the runtime has one thread and no routine here
# recurses, and an error ends the program.
#
# NUMBERS (DESIGN.md 2.14.6 "Notation"): every operation is one IEEE
# double operation in the order the spec writes it; no FMA; floor and
# ceil are exact (.Lrt_plot_floor, .Lrt_plot_ceil: SSE2 only, the C
# results including the sign of a zero result); integers are converted
# by cvtsi2sd (exact below 2^53); every NaN-sensitive test is an explicit
# ucomisd branch (never minsd/maxsd), and a float becomes an integer
# only after it has passed a test that bounds it (a tick count <= 7).
# Coordinates are written with sea_fmt_num's %.2f after the clamp of
# "Mapping" (L-kl).
#
# ABI: System V AMD64; the entries preserve %rbx %rbp %r12-%r15 and %rsp,
# never change MXCSR and leave the direction flag clear (rep stosq runs
# with it clear, as the ABI guarantees on entry). The local routines
# (.Lrt_plot_*) state their own clobbers. Stack: every entry's own frame
# is at most 104 bytes below its return address (asserted below 512); the
# deepest own path of this file is SAVE_SVG (104) + the panel writer (96)
# + a series or legend writer (96) + the marker writer (40) + the %.2f
# writer (24) + sea_fmt_num, each with its return address (with 9c the
# deepest own path passes rt_plot2.s's contour writer: its header);
# below it run sea_alloc,
# sea_fmt_num's snprintf, sea_file_put and sea_err, whose frames
# SEA_STACK_MARGIN covers (the measured total: DESIGN.md 4.8).
# =====================================================================
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

# ---- Figure (SEA_TAG_FIGURE), RTP_FG_SIZE bytes ----------------------
.equ RTP_FG_NROWS,      16          # u64 grid rows
.equ RTP_FG_NCOLS,      24          # u64 grid columns
.equ RTP_FG_W,          32          # u64 width (px)
.equ RTP_FG_H,          40          # u64 height (px)
.equ RTP_FG_NAME,       48          # ptr the name (a retained str)
.equ RTP_FG_NAX,        56          # u64 axes records
.equ RTP_FG_AXCAP,      64          # u64 their capacity
.equ RTP_FG_AXT,        72          # ptr the axes table (RTP_AX_SIZE-byte records)
.equ RTP_FG_NSR,        80          # u64 series records
.equ RTP_FG_SRCAP,      88          # u64 their capacity
.equ RTP_FG_SRT,        96          # ptr the series table (RTP_SR_SIZE-byte records)
.equ RTP_FG_OCC,        192         # u64[SEA_LIM_PLOT_GRID] occupancy map: bit c of word r
.equ RTP_FG_SIZE,       704
.if (RTP_FG_OCC + 8 * SEA_LIM_PLOT_GRID) != RTP_FG_SIZE
    .error "rt_plot: the Figure block of DESIGN.md 2.14.6 is 192 + 8 * SEA_LIM_PLOT_GRID bytes"
.endif
# ---- Axes handle (SEA_TAG_AXES), RTP_AH_SIZE bytes --------------------
.equ RTP_AH_FIG,        16          # ptr the figure (counted)
.equ RTP_AH_IDX,        24          # u64 the axes record's index
.equ RTP_AH_SIZE,       32
# ---- Axes record, RTP_AX_SIZE bytes, zero-filled when made ------------
.equ RTP_AX_KIND,       0           # 0 base, 1 twin
.equ RTP_AX_BASE,       8           # the base's index (its own for a base)
.equ RTP_AX_TWIN,       16          # the twin's index, -1 if none (a twin's -1)
.equ RTP_AX_ROW,        24
.equ RTP_AX_COL,        32
.equ RTP_AX_RS,         40          # rowspan
.equ RTP_AX_CS,         48          # colspan
.equ RTP_AX_TITLE,      56          # str or 0 (pair property: base)
.equ RTP_AX_XLAB,       64          # str or 0 (pair property: base)
.equ RTP_AX_YLAB,       72          # str or 0 (own y-axis)
.equ RTP_AX_FLAGS,      80          # RTP_F_* bits
.equ RTP_AX_LEG,        88          # legend location 0 none, 1 - 8
.equ RTP_AX_XLO,        96          # f64 x limits (pair: base)
.equ RTP_AX_XHI,        104
.equ RTP_AX_YLO,        112         # f64 y limits (own)
.equ RTP_AX_YHI,        120
.equ RTP_AX_XCAT,       128         # block of retained str pointers (pair: base)
.equ RTP_AX_NXCAT,      136
.equ RTP_AX_YCAT,       144         # (own)
.equ RTP_AX_NYCAT,      152
.equ RTP_AX_CYC,        160         # colour cycle index (0 base, 1 twin)
.equ RTP_AX_SIZE,       256
.equ RTP_AX_SHIFT,      8           # log2 RTP_AX_SIZE
.equ RTP_F_GRID,        1
.equ RTP_F_YREV,        2
.equ RTP_F_EQUAL,       4
.equ RTP_F_XLIM,        8
.equ RTP_F_YLIM,        16
# ---- Series record, RTP_SR_SIZE bytes, zero-filled when made ----------
.equ RTP_SR_KIND,       0           # RTP_SK_*
.equ RTP_SR_AX,         8           # the axes record's index
.equ RTP_SR_COLOR,      16          # 0xRRGGBB, or -1 (contour: the map per level)
.equ RTP_SR_LINE,       24          # 0 none, 1 solid, 2 --, 3 :, 4 -.
.equ RTP_SR_MARK,       32          # 0 none, 1 - 9 for o s d ^ v x + * .
.equ RTP_SR_WIDTH,      40          # f64
.equ RTP_SR_LABEL,      48          # str, or 0 for ""
.equ RTP_SR_N,          56
.equ RTP_SR_M,          64
.equ RTP_SR_DATA,       72          # uncounted block: x then y (a line series)
.equ RTP_SR_LEVELS,     80
.equ RTP_SR_FLAG,       88
.equ RTP_SR_XPOS,       96          # f64 (xline)
.equ RTP_SR_SIZE,       128
.equ RTP_SR_SHIFT,      7           # log2 RTP_SR_SIZE
.equ RTP_SK_LINE,       1
.equ RTP_SK_XLINE,      2
.equ RTP_SK_BAR,        3
.equ RTP_SK_BARH,       4
.equ RTP_SK_IMAGE,      6
.equ RTP_MK_DOT,        9           # the marker `.` (filled)
.equ RTP_CAP0,          8           # first capacity of both tables
# ---- The writer --------------------------------------------------------
.equ RTP_BUF0,          65536       # first SVG buffer size (L-lc)
.equ RTP_NUMBUF,        352         # sea_fmt_num's destination size (rt_fmt.s RTF_NUMDST)
.equ RTP_NTICK,         8           # numeric ticks per axis, at most
# Layout (LANGUAGE.md 12.5, L-kw: local equates, not contract values).
.equ RTP_HB,            24          # heading band
.equ RTP_ML,            56          # margins: left
.equ RTP_MR,            16          # right
.equ RTP_MR1,           68          # right with a twin or a colorbar
.equ RTP_MR2,           120         # right with both
.equ RTP_MT,            28          # top
.equ RTP_MB,            44          # bottom
# An axis descriptor of the panel being written (x, the base's y, the
# twin's y), RTP_A_SIZE bytes each.
.equ RTP_A_EHAS,        0           # 1 once a finite data value was seen
.equ RTP_A_ELO,         8           # f64 the extent
.equ RTP_A_EHI,         16
.equ RTP_A_EXPL,        24          # nonzero: explicit limits
.equ RTP_A_XLO,         32          # f64 the explicit limits
.equ RTP_A_XHI,         40
.equ RTP_A_NCAT,        48          # category labels (0: numeric ticks)
.equ RTP_A_CAT,         56          # their block
.equ RTP_A_REV,         64          # nonzero: a reversed y-axis
.equ RTP_A_LO,          72          # f64 the limits drawn
.equ RTP_A_HI,          80
.equ RTP_A_NT,          88          # ticks drawn
.equ RTP_A_I0,          96          # first category index drawn
.equ RTP_A_S,           104         # f64 the step
.equ RTP_A_K,           112         # its k
.equ RTP_A_TV,          120         # f64[RTP_NTICK] numeric tick values
.equ RTP_A_TL,          184         # u64[RTP_NTICK] their text lengths
.equ RTP_A_TT,          248         # their texts, RTP_NUMBUF bytes each
.equ RTP_A_SIZE,        (RTP_A_TT + RTP_NTICK * RTP_NUMBUF)
# f64 bit patterns.
.equ RTP_B_ONE,         0x3FF0000000000000
.equ RTP_B_2P52,        0x4330000000000000 # 2^52: every |x| >= it is integral
.equ RTP_B_INF,         0x7FF0000000000000
.equ RTP_B_INF2,        0xFFE0000000000000 # +Inf << 1: |bits| << 1 >= it is NaN or +-Inf
.equ RTP_B_QNAN,        0x7FF8000000000000
.equ RTP_B_SIGN,        0x8000000000000000

# ---- Frames ------------------------------------------------------------
# ENTER/LEAVE: %rbp, %rbx, %r12 - %r15 saved, then `locals` bytes at
# 0(%rsp). Entered at %rsp = 8 (mod 16), so locals = 8 (mod 16) keeps
# %rsp = 0 (mod 16) at the calls; the frame is 48 + locals bytes below
# the return address.
.macro ENTER locals
    .if ((\locals) % 16) != 8
        .error "rt_plot: ENTER needs locals = 8 (mod 16)"
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
# LIT text -- append the literal bytes to the SVG buffer (caller-saved
# registers clobbered; the caller's %rsp = 0 (mod 16)).
.macro LIT text
    leaq .Lrt_plot_lit\@(%rip), %rdi
    movl $(.Lrt_plot_lite\@ - .Lrt_plot_lit\@), %esi
    call .Lrt_plot_put
    .pushsection .rodata
.Lrt_plot_lit\@: .ascii "\text"
.Lrt_plot_lite\@:
    .popsection
.endm
# F2 mem -- append the f64 at mem as %.2f (caller-saved registers clobbered).
.macro F2 mem
    movsd \mem, %xmm0
    call .Lrt_plot_f2
.endm
# NONFIN xreg, label -- jump to label unless the f64 in xreg is finite
# (clobbers %rax, %rcx).
.macro NONFIN xreg, label
    movq \xreg, %rax
    shlq $1, %rax
    movabsq $RTP_B_INF2, %rcx
    cmpq %rcx, %rax
    jae \label
.endm
# AXD reg, n -- the address of axis descriptor n (0 x, 1 y, 2 the twin's y).
.macro AXD reg, n
    leaq (.Lrt_plot_axd + (\n) * RTP_A_SIZE)(%rip), \reg
.endm
# SHAREF name / SHARED name -- a hidden global alias (a function / an
# object) at this place, for rt_plot2.s (see the file header).
.macro SHAREF name
    .globl \name
    .hidden \name
    .type \name, @function
\name:
.endm
.macro SHARED name
    .globl \name
    .hidden \name
    .type \name, @object
\name:
.endm

    .text

# =====================================================================
# Exact arithmetic helpers (leaves)
# =====================================================================

# ---------------------------------------------------------------------
# .Lrt_plot_floor, .Lrt_plot_ceil -- C's floor and ceil in SSE2 (no
#   roundsd): |x| >= 2^52, +-Inf and NaN are returned as they are; else
#   the truncation t = (double)(long)x is moved one down (floor, t > x)
#   or up (ceil, t < x); a zero result takes the sign of x (floor(-0) =
#   -0, ceil(-0.5) = -0), as IEEE roundToIntegral gives.
#   Inputs  : %xmm0 = x
#   Outputs : %xmm0 = floor(x) / ceil(x)
#   Clobbers: %rax, %rcx, %xmm1, %xmm2, flags
#   Callee-saved used: none.  Frame: none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
SHAREF sea_plt_floor
.Lrt_plot_floor:
    movq %xmm0, %rax
    btrq $63, %rax                  # |x|'s bits
    movabsq $RTP_B_2P52, %rcx
    cmpq %rcx, %rax
    jae 3f                          # integral already, Inf or NaN
    cvttsd2si %xmm0, %rax           # truncate toward 0 (|x| < 2^52: exact)
    cvtsi2sdq %rax, %xmm1
    ucomisd %xmm0, %xmm1
    jbe 1f                          # t <= x: t is the floor
    movabsq $RTP_B_ONE, %rax
    movq %rax, %xmm2
    subsd %xmm2, %xmm1              # t > x: one less
1:  xorpd %xmm2, %xmm2
    ucomisd %xmm2, %xmm1
    jne 2f
    movq %xmm0, %rax                # a zero result: the sign of x
    movabsq $RTP_B_SIGN, %rcx
    andq %rcx, %rax
    movq %rax, %xmm1
2:  movapd %xmm1, %xmm0
3:  ret

    .p2align 4
.Lrt_plot_ceil:
    movq %xmm0, %rax
    btrq $63, %rax
    movabsq $RTP_B_2P52, %rcx
    cmpq %rcx, %rax
    jae 3f                          # integral already, Inf or NaN
    cvttsd2si %xmm0, %rax
    cvtsi2sdq %rax, %xmm1
    ucomisd %xmm0, %xmm1
    jae 1f                          # t >= x: t is the ceiling
    movabsq $RTP_B_ONE, %rax
    movq %rax, %xmm2
    addsd %xmm2, %xmm1              # t < x: one more
1:  xorpd %xmm2, %xmm2
    ucomisd %xmm2, %xmm1
    jne 2f
    movq %xmm0, %rax                # a zero result: the sign of x
    movabsq $RTP_B_SIGN, %rcx
    andq %rcx, %rax
    movq %rax, %xmm1
2:  movapd %xmm1, %xmm0
3:  ret

# ---------------------------------------------------------------------
# .Lrt_plot_dk -- d(k) of the step rule (DESIGN.md 2.14.6 limits 5,
#   L-kk): 1.0 multiplied by 10.0 k times for k >= 0, else 1.0 divided
#   by (1.0 multiplied by 10.0 -k times).
#   Inputs  : %edi = k (-300 .. 300)
#   Outputs : %xmm0 = d(k)
#   Clobbers: %ecx, %xmm1, %xmm2, flags.  Frame: none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot_dk:
    movsd .Lrt_plot_c_one(%rip), %xmm0
    movsd .Lrt_plot_c_ten(%rip), %xmm1
    movl %edi, %ecx
    testl %ecx, %ecx
    js 2f
1:  testl %ecx, %ecx                # k >= 0: k multiplications
    jz 3f
    mulsd %xmm1, %xmm0
    decl %ecx
    jmp 1b
2:  negl %ecx                       # k < 0: 1 / (10 multiplied -k times)
    movapd %xmm0, %xmm2
4:  mulsd %xmm1, %xmm2
    decl %ecx
    jnz 4b
    divsd %xmm2, %xmm0
3:  ret

# ---------------------------------------------------------------------
# .Lrt_plot_count -- count(s) = ceil(hi / s) - floor(lo / s) (limits 5);
#   infinite or NaN when a quotient overflows.
#   Inputs  : %xmm0 = lo, %xmm1 = hi, %xmm2 = s
#   Outputs : %xmm0 = the count (a float)
#   Clobbers: %rax, %rcx, %xmm1 - %xmm5, flags
#   Frame   : none (calls only the leaves .Lrt_plot_ceil/.Lrt_plot_floor)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot_count:
    movapd %xmm1, %xmm3
    divsd %xmm2, %xmm3              # hi / s
    movapd %xmm0, %xmm4
    divsd %xmm2, %xmm4              # lo / s
    movapd %xmm3, %xmm0
    call .Lrt_plot_ceil
    movapd %xmm0, %xmm5             # ceil(hi / s)
    movapd %xmm4, %xmm0
    call .Lrt_plot_floor            # floor(lo / s)
    subsd %xmm0, %xmm5
    movapd %xmm5, %xmm0
    ret

# ---------------------------------------------------------------------
# .Lrt_plot_step -- the step of [lo, hi] (DESIGN.md 2.14.6 limits 5):
#   k = 0; while k < 300 and not count(5 d(k)) <= 7: k + 1; while k >
#   -300 and count(5 d(k - 1)) <= 7: k - 1; s = the first of 1 d(k),
#   2 d(k), 5 d(k) with count(s) <= 7, else no step. Every test "<= 7"
#   is an ordered ucomisd (false for NaN), so an infinite or NaN count is
#   "more than 7".
#   Inputs  : %xmm0 = lo, %xmm1 = hi
#   Outputs : %eax = 1 and %xmm0 = s, %edx = k; or %eax = 0 (no step)
#   Clobbers: %rcx, %rdx, %rdi, %r8, %r9, %xmm0 - %xmm10, flags
#   Frame   : none (calls only leaves); %xmm6 = lo, %xmm7 = hi, %xmm8 =
#             7.0, %xmm9 = d(k), %xmm10 = s, %r8d = k, %r9 = the
#             multiplier index
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot_step:
    movapd %xmm0, %xmm6
    movapd %xmm1, %xmm7
    movsd .Lrt_plot_c_seven(%rip), %xmm8
    xorl %r8d, %r8d                 # k = 0
1:  cmpl $300, %r8d                 # up: while k < 300 and not count(5 d(k)) <= 7
    jge 2f
    movl %r8d, %edi
    call .Lrt_plot_dk
    mulsd .Lrt_plot_c_five(%rip), %xmm0
    movapd %xmm0, %xmm2
    movapd %xmm6, %xmm0
    movapd %xmm7, %xmm1
    call .Lrt_plot_count
    ucomisd %xmm0, %xmm8
    jae 2f                          # 7 >= count (ordered): stop
    incl %r8d
    jmp 1b
2:  cmpl $-300, %r8d                # down: while k > -300 and count(5 d(k - 1)) <= 7
    jle 3f
    leal -1(%r8), %edi
    call .Lrt_plot_dk
    mulsd .Lrt_plot_c_five(%rip), %xmm0
    movapd %xmm0, %xmm2
    movapd %xmm6, %xmm0
    movapd %xmm7, %xmm1
    call .Lrt_plot_count
    ucomisd %xmm0, %xmm8
    jb 3f                           # count > 7 or NaN: stop
    decl %r8d
    jmp 2b
3:  movl %r8d, %edi                 # the candidates 1 d(k), 2 d(k), 5 d(k)
    call .Lrt_plot_dk
    movapd %xmm0, %xmm9
    xorl %r9d, %r9d
4:  leaq .Lrt_plot_c_mult(%rip), %rax
    movsd (%rax,%r9,8), %xmm10
    mulsd %xmm9, %xmm10             # m * d(k) (1 * d(k) is d(k) exactly)
    movapd %xmm10, %xmm2
    movapd %xmm6, %xmm0
    movapd %xmm7, %xmm1
    call .Lrt_plot_count
    ucomisd %xmm0, %xmm8
    jae 5f                          # this one has at most 7 intervals
    incq %r9
    cmpq $3, %r9
    jb 4b
    xorl %eax, %eax                 # no step (only possible at k = 300)
    ret
5:  movapd %xmm10, %xmm0
    movl %r8d, %edx
    movl $1, %eax
    ret

# ---------------------------------------------------------------------
# .Lrt_plot_clamp -- the coordinate clamp of "Mapping" (L-kl): NaN and
#   values below -P become -P, values above 2P become 2P (P =
#   SEA_LIM_PLOT_PX).
#   Inputs  : %xmm0 = a coordinate
#   Outputs : %xmm0 = the clamped coordinate
#   Clobbers: %eax, %xmm1, flags.  Frame: none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot_clamp:
    movl $-SEA_LIM_PLOT_PX, %eax
    cvtsi2sdl %eax, %xmm1           # -P
    ucomisd %xmm0, %xmm0
    jp 1f                           # NaN: -P
    ucomisd %xmm1, %xmm0
    jb 1f                           # below -P (-Inf included): -P
    movl $(2 * SEA_LIM_PLOT_PX), %eax
    cvtsi2sdl %eax, %xmm1           # 2P
    ucomisd %xmm1, %xmm0
    jbe 2f                          # inside
1:  movapd %xmm1, %xmm0             # -P or 2P
2:  ret

# ---------------------------------------------------------------------
# .Lrt_plot_map -- X(v) or Y(v) of the panel being written, clamped
#   (DESIGN.md 2.14.6 "Mapping"): X(v) = px + ((v - lo) / (hi - lo)) *
#   pw; Y(v) = py + ph - ((v - lo) / (hi - lo)) * ph, or py + (...) * ph
#   for a reversed axis.
#   Inputs  : %rdi = the axis (0 x, 1 y, 2 the twin's y), %xmm0 = v
#   Outputs : %xmm0 = the clamped coordinate
#   Clobbers: %rax, %rcx, %xmm1, %xmm2, flags
#   Frame   : none (tail jump to the leaf .Lrt_plot_clamp)
# ---------------------------------------------------------------------
    .p2align 4
SHAREF sea_plt_map
.Lrt_plot_map:
    imulq $RTP_A_SIZE, %rdi, %rcx
    leaq .Lrt_plot_axd(%rip), %rax
    addq %rax, %rcx                 # the descriptor
    movsd RTP_A_LO(%rcx), %xmm1
    movsd RTP_A_HI(%rcx), %xmm2
    subsd %xmm1, %xmm0              # v - lo
    subsd %xmm1, %xmm2              # hi - lo
    divsd %xmm2, %xmm0              # t
    testq %rdi, %rdi
    jnz 1f
    mulsd .Lrt_plot_pw(%rip), %xmm0 # x: px + t * pw
    addsd .Lrt_plot_px(%rip), %xmm0
    jmp .Lrt_plot_clamp
1:  mulsd .Lrt_plot_ph(%rip), %xmm0 # t * ph
    cmpq $0, RTP_A_REV(%rcx)
    jne 2f
    movsd .Lrt_plot_py(%rip), %xmm1 # y: (py + ph) - t * ph
    addsd .Lrt_plot_ph(%rip), %xmm1
    subsd %xmm0, %xmm1
    movapd %xmm1, %xmm0
    jmp .Lrt_plot_clamp
2:  addsd .Lrt_plot_py(%rip), %xmm0 # reversed: py + t * ph
    jmp .Lrt_plot_clamp

# ---------------------------------------------------------------------
# .Lrt_plot_ext -- add one value to an axis extent (value by value,
#   non-finite skipped; L-kj).
#   Inputs  : %rdi = the descriptor, %xmm0 = v
#   Outputs : none
#   Clobbers: %rax, %rcx, flags.  Frame: none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
SHAREF sea_plt_ext
.Lrt_plot_ext:
    NONFIN %xmm0, 3f
    cmpq $0, RTP_A_EHAS(%rdi)
    jne 1f
    movq $1, RTP_A_EHAS(%rdi)       # the first value: the whole extent
    movsd %xmm0, RTP_A_ELO(%rdi)
    movsd %xmm0, RTP_A_EHI(%rdi)
    ret
1:  ucomisd RTP_A_ELO(%rdi), %xmm0
    jae 2f
    movsd %xmm0, RTP_A_ELO(%rdi)    # v < lo
2:  ucomisd RTP_A_EHI(%rdi), %xmm0
    jbe 3f
    movsd %xmm0, RTP_A_EHI(%rdi)    # v > hi
3:  ret

# =====================================================================
# The SVG buffer
# =====================================================================

# ---------------------------------------------------------------------
# .Lrt_plot_room -- make room for n more bytes in the SVG buffer
#   (doubled by copy until it fits; out of memory at the entry's site).
#   Inputs  : %rdi = n
#   Outputs : %rax = where the next byte goes
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = the bytes needed, %r12 = the new capacity,
#             %r13 = the new block, %r14 (alignment), %rbp
#   Frame   : 40 bytes (%rbp %rbx %r12 %r13 %r14)
# ---------------------------------------------------------------------
    .p2align 4
SHAREF sea_plt_room
.Lrt_plot_room:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14                      # %rsp = 0 (mod 16)
    movq .Lrt_plot_bufn(%rip), %rbx
    addq %rdi, %rbx                 # bytes needed
    cmpq .Lrt_plot_bufc(%rip), %rbx
    jbe 2f
    movq .Lrt_plot_bufc(%rip), %r12
1:  shlq $1, %r12                   # double until it fits
    cmpq %rbx, %r12
    jb 1b
    movq %r12, %rdi
    movq .Lrt_plot_site(%rip), %rsi
    call sea_alloc
    movq %rax, %r13
    movq %r13, %rdi                 # the bytes so far
    movq .Lrt_plot_bufp(%rip), %rsi
    movq .Lrt_plot_bufn(%rip), %rdx
    call memcpy@PLT
    movq .Lrt_plot_bufp(%rip), %rdi # the old block
    movq .Lrt_plot_bufc(%rip), %rsi
    call sea_free_block
    movq %r13, .Lrt_plot_bufp(%rip)
    movq %r12, .Lrt_plot_bufc(%rip)
2:  movq .Lrt_plot_bufp(%rip), %rax
    addq .Lrt_plot_bufn(%rip), %rax
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_plot_put -- append bytes.
#   Inputs  : %rdi = the bytes, %rsi = their count
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = the bytes, %r12 = the count, %rbp
#   Frame   : 24 bytes (%rbp %rbx %r12)
# ---------------------------------------------------------------------
    .p2align 4
SHAREF sea_plt_put
.Lrt_plot_put:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12                      # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
    movq %r12, %rdi
    call .Lrt_plot_room
    movq %rax, %rdi
    movq %rbx, %rsi
    movq %r12, %rdx
    call memcpy@PLT
    addq %r12, .Lrt_plot_bufn(%rip)
    popq %r12
    popq %rbx
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_plot_f2 -- append an f64 as %.2f (sea_fmt_num straight into the
#   buffer; the value is finite: every caller passes a clamped
#   coordinate or a layout value, L-kl).
#   Inputs  : %xmm0 = the value
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbp.  Frame: 24 bytes (%rbp + the value + pad)
# ---------------------------------------------------------------------
    .p2align 4
SHAREF sea_plt_f2
.Lrt_plot_f2:
    pushq %rbp
    movq %rsp, %rbp
    subq $16, %rsp                  # the value at 0(%rsp); %rsp = 0 (mod 16)
    movsd %xmm0, 0(%rsp)
    movl $RTP_NUMBUF, %edi
    call .Lrt_plot_room
    movq %rax, %rdi
    movl $102, %esi                 # 'f'
    movl $2, %edx
    movsd 0(%rsp), %xmm0
    call sea_fmt_num                # %rax = the text's length
    addq %rax, .Lrt_plot_bufn(%rip)
    addq $16, %rsp
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_plot_int -- append a non-negative integer in decimal (%d).
#   Inputs  : %rdi = the value (>= 0)
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbp.  Frame: 40 bytes (%rbp + 32 digit scratch)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot_int:
    pushq %rbp
    movq %rsp, %rbp
    subq $32, %rsp                  # digits right to left, ending at 32(%rsp)
    movq %rdi, %rax
    leaq 32(%rsp), %rdi
    movl $10, %ecx
1:  xorl %edx, %edx
    divq %rcx
    addb $48, %dl                   # '0' + digit
    decq %rdi
    movb %dl, (%rdi)
    testq %rax, %rax
    jnz 1b
    leaq 32(%rsp), %rsi
    subq %rdi, %rsi                 # the digit count
    call .Lrt_plot_put
    addq $32, %rsp
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_plot_color -- append a colour as #rrggbb, lower case.
#   Inputs  : %rdi = 0xRRGGBB
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = the colour, %rbp.  Frame: 24 bytes
# ---------------------------------------------------------------------
    .p2align 4
SHAREF sea_plt_color
.Lrt_plot_color:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp                   # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movl $8, %edi
    call .Lrt_plot_room
    movb $35, (%rax)                # '#'
    leaq .Lrt_plot_hex(%rip), %rdx
    movl $6, %ecx                   # six digits, the last one first
1:  movq %rbx, %rsi
    andl $15, %esi
    movb (%rdx,%rsi), %sil
    movb %sil, (%rax,%rcx)
    shrq $4, %rbx
    decl %ecx
    jnz 1b
    addq $7, .Lrt_plot_bufn(%rip)
    addq $8, %rsp
    popq %rbx
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_plot_dash -- append the dash attribute of a line code (2.14.6
#   "Series forms": ` stroke-dasharray="6 4"`, `"2 3"`, `"6 3 2 3"` for
#   2, 3, 4; nothing for 0 and 1).
#   Inputs  : %rdi = the line code
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbp.  Frame: 8 bytes (%rbp)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot_dash:
    pushq %rbp                      # %rsp = 0 (mod 16)
    movq %rsp, %rbp
    cmpq $2, %rdi
    je 2f
    cmpq $3, %rdi
    je 3f
    cmpq $4, %rdi
    jne 1f
    LIT " stroke-dasharray=\"6 3 2 3\""
    jmp 1f
2:  LIT " stroke-dasharray=\"6 4\""
    jmp 1f
3:  LIT " stroke-dasharray=\"2 3\""
1:  popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_plot_escb -- append text bytes XML-escaped (2.14.6, L-kp): & < >
#   " as &amp; &lt; &gt; &quot;, every byte 0x00 - 0x1F but 0x09, 0x0A,
#   0x0D as a space, every other byte as it is.
#   Inputs  : %rdi = the bytes, %rsi = their count
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = the bytes, %r12 = the count, %r13 = the
#             output cursor, %rbp.  Frame: 40 bytes (%rbp %rbx %r12 %r13
#             + 8 pad)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot_escb:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    subq $8, %rsp                   # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
    leaq (%r12,%r12,2), %rdi
    shlq $1, %rdi                   # at most 6 bytes per byte (&quot;)
    call .Lrt_plot_room
    movq %rax, %r13
    xorl %ecx, %ecx                 # index
1:  cmpq %r12, %rcx
    jae 9f
    movzbl (%rbx,%rcx), %eax
    incq %rcx
    cmpl $38, %eax                  # '&'
    je 2f
    cmpl $60, %eax                  # '<'
    je 3f
    cmpl $62, %eax                  # '>'
    je 4f
    cmpl $34, %eax                  # '"'
    je 5f
    cmpl $32, %eax
    jae 8f                          # 0x20 and above: as it is
    cmpl $9, %eax
    je 8f
    cmpl $10, %eax
    je 8f
    cmpl $13, %eax
    je 8f
    movl $32, %eax                  # another control byte: a space
8:  movb %al, (%r13)
    incq %r13
    jmp 1b
2:  movl $0x706D6126, (%r13)        # "&amp"
    movb $59, 4(%r13)               # ';'
    addq $5, %r13
    jmp 1b
3:  movl $0x3B746C26, (%r13)        # "&lt;"
    addq $4, %r13
    jmp 1b
4:  movl $0x3B746726, (%r13)        # "&gt;"
    addq $4, %r13
    jmp 1b
5:  movl $0x6F757126, (%r13)        # "&quo"
    movw $0x3B74, 4(%r13)           # "t;"
    addq $6, %r13
    jmp 1b
9:  subq .Lrt_plot_bufp(%rip), %r13
    movq %r13, .Lrt_plot_bufn(%rip) # the new length
    addq $8, %rsp
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_plot_esc -- append a string object's bytes XML-escaped (a null
#   pointer is the empty text).
#   Inputs  : %rdi = the string, or 0
#   Clobbers: all caller-saved registers.  Frame: none (tail jump)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot_esc:
    testq %rdi, %rdi
    jz 1f
    movq SEA_STR_LEN(%rdi), %rsi
    leaq SEA_STR_BYTES(%rdi), %rdi
    jmp .Lrt_plot_escb
1:  ret

# ---------------------------------------------------------------------
# .Lrt_plot_ttext -- append a tick label: numeric texts as they are
#   (digits, sign, point, exponent), category labels escaped.
#   Inputs  : %rdi = the bytes, %rsi = their count, %edx = 1 to escape
#   Clobbers: all caller-saved registers.  Frame: none (tail jumps)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot_ttext:
    testl %edx, %edx
    jnz .Lrt_plot_escb
    jmp .Lrt_plot_put

# =====================================================================
# Errors, records, arguments
# =====================================================================

# ---------------------------------------------------------------------
# .Lrt_plot_raise -- sea_err(code, site, slots); noreturn.
#   Inputs  : %edi = code, %rsi = site, %rdx %rcx %r8 %r9 %r10 %r11 =
#             slots 0 - 5 (as many as the code's args letters use)
#   Frame   : 8 bytes (%rbp), %rsp rounded down to 16, six slots
# ---------------------------------------------------------------------
    .p2align 4
SHAREF sea_plt_raise
.Lrt_plot_raise:
    pushq %rbp
    movq %rsp, %rbp
    andq $-16, %rsp                 # noreturn: align however we came here
    subq $48, %rsp
    movq %rdx, 0(%rsp)
    movq %rcx, 8(%rsp)
    movq %r8, 16(%rsp)
    movq %r9, 24(%rsp)
    movq %r10, 32(%rsp)
    movq %r11, 40(%rsp)
    movq %rsp, %rdx
    call sea_err                    # noreturn
    ud2

# ---------------------------------------------------------------------
# .Lrt_plot_recs -- the records of an Axes handle.
#   Inputs  : %rdi = the Axes
#   Outputs : %rax = its own axes record, %rdx = its base's record, %rcx
#             = the figure, %r8 = its own index
#   Clobbers: %r9, flags.  Frame: none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
SHAREF sea_plt_recs
.Lrt_plot_recs:
    movq RTP_AH_FIG(%rdi), %rcx
    movq RTP_AH_IDX(%rdi), %r8
    movq RTP_FG_AXT(%rcx), %r9
    movq %r8, %rax
    shlq $RTP_AX_SHIFT, %rax
    addq %r9, %rax                  # own record
    movq RTP_AX_BASE(%rax), %rdx
    shlq $RTP_AX_SHIFT, %rdx
    addq %r9, %rdx                  # the base's record (a base's own)
    ret

# ---------------------------------------------------------------------
# .Lrt_plot_grow -- append a zero-filled record to one of a figure's
#   tables, doubling the table when it is full (a new block of 2 x the
#   capacity, the records copied, the old block freed).
#   Inputs  : %rdi = the figure, %rsi = the offset of the table's count
#             (RTP_FG_NAX or RTP_FG_NSR; the capacity and the block
#             follow at +8, +16), %rdx = log2 of the record size
#   Outputs : %rax = the new record, %rdx = its index
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = the count's address, %r12 = the shift,
#             %r13 = the new capacity, %r14 = the new block, %r15 = the
#             index, %rbp.  Frame: 56 bytes (ENTER 8)
# ---------------------------------------------------------------------
    .p2align 4
SHAREF sea_plt_grow
.Lrt_plot_grow:
    ENTER 8
    leaq (%rdi,%rsi), %rbx
    movq %rdx, %r12
    movq (%rbx), %r15               # the index of the new record
    cmpq 8(%rbx), %r15
    jb 1f                           # room left
    movq 8(%rbx), %r13
    shlq $1, %r13                   # the new capacity
    movq %r13, %rdi
    movl %r12d, %ecx
    shlq %cl, %rdi
    movq .Lrt_plot_site(%rip), %rsi
    call sea_alloc
    movq %rax, %r14
    movq %r14, %rdi                 # copy the records
    movq 16(%rbx), %rsi
    movq %r15, %rdx
    movl %r12d, %ecx
    shlq %cl, %rdx
    call memcpy@PLT
    movq 16(%rbx), %rdi             # free the old block
    movq 8(%rbx), %rsi
    movl %r12d, %ecx
    shlq %cl, %rsi
    call sea_free_block
    movq %r14, 16(%rbx)
    movq %r13, 8(%rbx)
1:  movq %r15, %r13
    movl %r12d, %ecx
    shlq %cl, %r13
    addq 16(%rbx), %r13             # the record
    movq %r13, %rdi
    movl $1, %eax
    shlq %cl, %rax
    shrq $3, %rax
    movq %rax, %rcx                 # its qwords
    xorl %eax, %eax
    rep stosq                       # zero-filled
    incq (%rbx)
    movq %r13, %rax                 # %rax = the record
    movq %r15, %rdx                 # %rdx = its index
    LEAVE 8

# ---------------------------------------------------------------------
# .Lrt_plot_mkaxes -- a new Axes handle (count 1, counted in sea_live)
#   referring to axes record idx of fig (fig retained).
#   Inputs  : %rdi = the figure, %rsi = the index
#   Outputs : %rax = the handle
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = the figure, %r12 = the index, %rbp
#   Frame   : 24 bytes (%rbp %rbx %r12)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot_mkaxes:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12                      # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
    movl $RTP_AH_SIZE, %edi
    movq .Lrt_plot_site(%rip), %rsi
    call sea_alloc
    movq $1, SEA_OBJ_RC(%rax)
    movq $SEA_TAG_AXES, SEA_OBJ_TAG(%rax) # the tag, bytes 9 - 15 zero
    movq %rbx, RTP_AH_FIG(%rax)
    movq %r12, RTP_AH_IDX(%rax)
    incq SEA_OBJ_RC(%rbx)           # the figure is retained (never static)
    incq sea_live(%rip)             # one more object
    popq %r12
    popq %rbx
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_plot_style -- parse a style string (2.14.6 "Style and colour",
#   L-ki): left to right, `--` or `-.` first, then `-` or `:`, then a
#   marker `o s d ^ v x + * .`, then a colour letter `r g b c m y k w`; a
#   second item of a kind or any other byte is an error.
#   Inputs  : %rdi = the style string
#   Outputs : %rax = the line code (0 none, 1 - 4), or -1 on an error;
#             %rdx = the marker code (0 none, 1 - 9); %rcx = the colour
#             letter's 0xRRGGBB, or -1
#   Clobbers: %rsi, %rdi, %r8 - %r11, flags.  Frame: none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot_style:
    movq SEA_STR_LEN(%rdi), %rsi
    leaq SEA_STR_BYTES(%rdi), %rdi
    xorl %eax, %eax
    xorl %edx, %edx
    movq $-1, %rcx
    xorl %r8d, %r8d                 # position
1:  cmpq %rsi, %r8
    jae 9f
    movzbl (%rdi,%r8), %r9d
    cmpl $45, %r9d                  # '-'
    jne 4f
    testq %rax, %rax
    jnz 8f                          # a second line part
    movl $1, %eax                   # `-` unless `--` or `-.` follows
    leaq 1(%r8), %r10
    cmpq %rsi, %r10
    jae 3f
    movzbl (%rdi,%r10), %r10d
    cmpl $45, %r10d
    jne 2f
    movl $2, %eax                   # `--`
    addq $2, %r8
    jmp 1b
2:  cmpl $46, %r10d                 # '.'
    jne 3f
    movl $4, %eax                   # `-.`
    addq $2, %r8
    jmp 1b
3:  incq %r8                        # `-`
    jmp 1b
4:  cmpl $58, %r9d                  # ':'
    jne 5f
    testq %rax, %rax
    jnz 8f
    movl $3, %eax
    incq %r8
    jmp 1b
5:  leaq .Lrt_plot_markers(%rip), %r11 # a marker?
    xorl %r10d, %r10d
6:  cmpb (%r11,%r10), %r9b
    je 7f
    incq %r10
    cmpq $9, %r10
    jb 6b
    leaq .Lrt_plot_letters(%rip), %r11 # a colour letter?
    xorl %r10d, %r10d
10: cmpb (%r11,%r10), %r9b
    je 11f
    incq %r10
    cmpq $8, %r10
    jb 10b
    jmp 8f                          # any other byte
7:  testq %rdx, %rdx
    jnz 8f                          # a second marker
    leaq 1(%r10), %rdx
    incq %r8
    jmp 1b
11: testq %rcx, %rcx
    jns 8f                          # a second colour letter
    leaq .Lrt_plot_lettercol(%rip), %r11
    movq (%r11,%r10,8), %rcx
    incq %r8
    jmp 1b
8:  movq $-1, %rax                  # LINE_STYLE
9:  ret

# ---------------------------------------------------------------------
# .Lrt_plot_colorarg -- parse a colour argument: "" or `#` and six hex
#   digits of either case.
#   Inputs  : %rdi = the colour string
#   Outputs : %rax = -1 for "", 0xRRGGBB, or -2 on an error (COLOR)
#   Clobbers: %rcx, %rdx, %rsi, flags.  Frame: none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
SHAREF sea_plt_colorarg
.Lrt_plot_colorarg:
    movq SEA_STR_LEN(%rdi), %rcx
    movq $-1, %rax
    testq %rcx, %rcx
    jz 9f                           # "": no colour
    cmpq $7, %rcx
    jne 8f
    cmpb $35, SEA_STR_BYTES(%rdi)   # '#'
    jne 8f
    xorl %eax, %eax
    movl $1, %ecx
1:  movzbl SEA_STR_BYTES(%rdi,%rcx), %edx
    leal -48(%rdx), %esi            # '0' - '9'
    cmpl $10, %esi
    jb 2f
    leal -97(%rdx), %esi            # 'a' - 'f'
    cmpl $6, %esi
    jb 3f
    leal -65(%rdx), %esi            # 'A' - 'F'
    cmpl $6, %esi
    jae 8f
3:  addl $10, %esi
2:  shlq $4, %rax
    orq %rsi, %rax
    incl %ecx
    cmpl $7, %ecx
    jb 1b
    ret
8:  movq $-2, %rax
9:  ret

# ---------------------------------------------------------------------
# .Lrt_plot_rescol -- a series' colour (2.14.6, L-kh): the colour
#   argument if given, else the style's letter, else the cycle colour at
#   the axes' own cycle index (index mod 7), which then advances by one.
#   Inputs  : %rdi = the Axes, %rsi = the colour argument (-1: none),
#             %rdx = the style's colour (-1: none)
#   Outputs : %rax = 0xRRGGBB
#   Clobbers: %rcx, %rdx, %r8, %r9, flags.  Frame: none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
SHAREF sea_plt_rescol
.Lrt_plot_rescol:
    movq %rsi, %rax
    testq %rax, %rax
    jns 1f                          # the colour argument
    movq %rdx, %rax
    testq %rax, %rax
    jns 1f                          # the style's letter
    call .Lrt_plot_recs             # %rax = own record
    movq %rax, %r8
    movq RTP_AX_CYC(%r8), %rax
    incq RTP_AX_CYC(%r8)            # the cycle advances
    xorl %edx, %edx
    movl $7, %ecx
    divq %rcx                       # %rdx = index mod 7
    leaq .Lrt_plot_cycle(%rip), %rcx
    movq (%rcx,%rdx,8), %rax
1:  ret

# ---------------------------------------------------------------------
# .Lrt_plot_setstr -- replace a retained string field: the new string
#   retained, the old one released.
#   Inputs  : %rdi = the field's address, %rsi = the new string
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = the field, %r12 = the string, %rbp
#   Frame   : 24 bytes (%rbp %rbx %r12)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot_setstr:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12                      # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
    movq %r12, %rdi
    call sea_retain
    movq (%rbx), %rdi
    movq %r12, (%rbx)
    call sea_release                # the previous one (0: nothing)
    popq %r12
    popq %rbx
    popq %rbp
    ret

# =====================================================================
# The entries
# =====================================================================

# ---------------------------------------------------------------------
# sea_figure -- entry FIGURE (62).
#   Purpose : FIGURE_GRID unless 1 <= nrows, ncols <= SEA_LIM_PLOT_GRID,
#             then FIGURE_SIZE unless 1 <= width, height <=
#             SEA_LIM_PLOT_PX; a new Figure (count 1, counted) with no
#             axes, both tables of RTP_CAP0 records, the name retained.
#   Inputs  : %rdi = nrows, %rsi = ncols, %rdx = name, %rcx = width,
#             %r8 = height, %r9 = site
#   Outputs : %rax = the Figure
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = nrows, %r12 = ncols, %r13 = name, %r14 =
#             width, %r15 = height, %rbp; 0(%rsp) = the figure
#   Frame   : 56 bytes (ENTER 8)
# ---------------------------------------------------------------------
    .globl sea_figure
    .type sea_figure, @function
    .p2align 4
sea_figure:
    ENTER 8
    movq %rdi, %rbx
    movq %rsi, %r12
    movq %rdx, %r13
    movq %rcx, %r14
    movq %r8, %r15
    movq %r9, .Lrt_plot_site(%rip)
    cmpq $1, %rbx                   # the grid
    jl 1f
    cmpq $SEA_LIM_PLOT_GRID, %rbx
    jg 1f
    cmpq $1, %r12
    jl 1f
    cmpq $SEA_LIM_PLOT_GRID, %r12
    jg 1f
    cmpq $1, %r14                   # the size
    jl 2f
    cmpq $SEA_LIM_PLOT_PX, %r14
    jg 2f
    cmpq $1, %r15
    jl 2f
    cmpq $SEA_LIM_PLOT_PX, %r15
    jg 2f
    movl $RTP_FG_SIZE, %edi         # the block, zero-filled
    movq .Lrt_plot_site(%rip), %rsi
    call sea_alloc
    movq %rax, 0(%rsp)
    movq %rax, %rdi
    movl $(RTP_FG_SIZE / 8), %ecx
    xorl %eax, %eax
    rep stosq
    movq 0(%rsp), %rax
    movq $1, SEA_OBJ_RC(%rax)
    movq $SEA_TAG_FIGURE, SEA_OBJ_TAG(%rax)
    movq %rbx, RTP_FG_NROWS(%rax)
    movq %r12, RTP_FG_NCOLS(%rax)
    movq %r14, RTP_FG_W(%rax)
    movq %r15, RTP_FG_H(%rax)
    movq %r13, RTP_FG_NAME(%rax)
    movq $RTP_CAP0, RTP_FG_AXCAP(%rax)
    movq $RTP_CAP0, RTP_FG_SRCAP(%rax)
    movq %r13, %rdi
    call sea_retain                 # the name
    movl $(RTP_CAP0 * RTP_AX_SIZE), %edi
    movq .Lrt_plot_site(%rip), %rsi
    call sea_alloc
    movq 0(%rsp), %rcx
    movq %rax, RTP_FG_AXT(%rcx)     # the axes table
    movl $(RTP_CAP0 * RTP_SR_SIZE), %edi
    movq .Lrt_plot_site(%rip), %rsi
    call sea_alloc
    movq 0(%rsp), %rcx
    movq %rax, RTP_FG_SRT(%rcx)     # the series table
    incq sea_live(%rip)             # one more object
    movq %rcx, %rax
    LEAVE 8
1:  movl $SEA_E_FIGURE_GRID, %edi
    movq .Lrt_plot_site(%rip), %rsi
    movq %rbx, %rdx
    movq %r12, %rcx
    call .Lrt_plot_raise
2:  movl $SEA_E_FIGURE_SIZE, %edi
    movq .Lrt_plot_site(%rip), %rsi
    movq %r14, %rdx
    movq %r15, %rcx
    call .Lrt_plot_raise
    .size sea_figure, . - sea_figure

# ---------------------------------------------------------------------
# sea_panel -- entry PANEL (63).
#   Purpose : PANEL_CELL (row < 0, col < 0, rowspan < 1, colspan < 1,
#             row + rowspan > nrows, col + colspan > ncols; tested as
#             rowspan > nrows - row, which cannot overflow), then
#             PANEL_TAKEN at the first occupied cell of the span, rows
#             ascending, then columns (Decision 133 (b)); a new base axes
#             record, its cells marked, and a new Axes handle.
#   Inputs  : %rdi = fig, %rsi = row, %rdx = col, %rcx = rowspan, %r8 =
#             colspan, %r9 = site
#   Outputs : %rax = the Axes
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = fig, %r12 = row, %r13 = col, %r14 =
#             rowspan, %r15 = colspan, %rbp; 0(%rsp) = the column mask,
#             8(%rsp) = the new index
#   Frame   : 72 bytes (ENTER 24)
# ---------------------------------------------------------------------
    .globl sea_panel
    .type sea_panel, @function
    .p2align 4
sea_panel:
    ENTER 24
    movq %rdi, %rbx
    movq %rsi, %r12
    movq %rdx, %r13
    movq %rcx, %r14
    movq %r8, %r15
    movq %r9, .Lrt_plot_site(%rip)
    testq %r12, %r12                # PANEL_CELL
    js 8f
    testq %r13, %r13
    js 8f
    cmpq $1, %r14
    jl 8f
    cmpq $1, %r15
    jl 8f
    movq RTP_FG_NROWS(%rbx), %rax
    subq %r12, %rax
    cmpq %rax, %r14
    jg 8f                           # row + rowspan > nrows
    movq RTP_FG_NCOLS(%rbx), %rax
    subq %r13, %rax
    cmpq %rax, %r15
    jg 8f                           # col + colspan > ncols
    movq $-1, %rax                  # the mask of columns col .. col+colspan-1
    cmpq $64, %r15
    je 1f
    movl %r15d, %ecx
    movl $1, %eax
    shlq %cl, %rax
    decq %rax
1:  movl %r13d, %ecx
    shlq %cl, %rax
    movq %rax, 0(%rsp)
    movq %r12, %rdx                 # PANEL_TAKEN: rows ascending
2:  movq RTP_FG_OCC(%rbx,%rdx,8), %rcx
    andq 0(%rsp), %rcx
    jnz 9f                          # an occupied cell in this row
    incq %rdx
    movq %r12, %rax
    addq %r14, %rax
    cmpq %rax, %rdx
    jb 2b
    movq %rbx, %rdi                 # the record
    movl $RTP_FG_NAX, %esi
    movl $RTP_AX_SHIFT, %edx
    call .Lrt_plot_grow             # %rax = record, %rdx = index
    movq %rdx, 8(%rsp)
    movq %rdx, RTP_AX_BASE(%rax)    # kind 0 (base), its own base
    movq $-1, RTP_AX_TWIN(%rax)
    movq %r12, RTP_AX_ROW(%rax)
    movq %r13, RTP_AX_COL(%rax)
    movq %r14, RTP_AX_RS(%rax)
    movq %r15, RTP_AX_CS(%rax)
    movq %r12, %rdx                 # mark the cells
    movq 0(%rsp), %rcx
3:  orq %rcx, RTP_FG_OCC(%rbx,%rdx,8)
    incq %rdx
    movq %r12, %rax
    addq %r14, %rax
    cmpq %rax, %rdx
    jb 3b
    movq %rbx, %rdi
    movq 8(%rsp), %rsi
    call .Lrt_plot_mkaxes
    LEAVE 24
8:  movl $SEA_E_PANEL_CELL, %edi
    movq .Lrt_plot_site(%rip), %rsi
    movq %r12, %rdx
    movq %r13, %rcx
    movq %r14, %r8
    movq %r15, %r9
    movq RTP_FG_NROWS(%rbx), %r10
    movq RTP_FG_NCOLS(%rbx), %r11
    call .Lrt_plot_raise
9:  bsfq %rcx, %rcx                 # the first occupied column
    movl $SEA_E_PANEL_TAKEN, %edi
    movq .Lrt_plot_site(%rip), %rsi
    call .Lrt_plot_raise            # (%rdx = row, %rcx = column)
    .size sea_panel, . - sea_panel

# ---------------------------------------------------------------------
# sea_twin_y -- entry TWIN_Y (64), Decision 134 (a): of a twin, the twin
#   itself; of a base with a twin, that twin; else a new twin record
#   (kind 1, its base, no twin, the base's row, col and spans, cycle
#   index 1) whose index the base stores. A new Axes handle to the result.
#   Inputs  : %rdi = ax, %rsi = site
#   Outputs : %rax = the Axes
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = the figure, %r12 = ax's index, %r13 = the
#             result's index, %rbp.  Frame: 56 bytes (ENTER 8)
# ---------------------------------------------------------------------
    .globl sea_twin_y
    .type sea_twin_y, @function
    .p2align 4
sea_twin_y:
    ENTER 8
    movq %rsi, .Lrt_plot_site(%rip)
    call .Lrt_plot_recs             # %rax = own record, %rcx = figure, %r8 = index
    movq %rcx, %rbx
    movq %r8, %r12
    movq %r8, %r13
    cmpq $1, RTP_AX_KIND(%rax)
    je 2f                           # a twin: itself
    movq RTP_AX_TWIN(%rax), %r13
    testq %r13, %r13
    jns 2f                          # a base with a twin: that twin
    movq %rbx, %rdi                 # a new twin record
    movl $RTP_FG_NAX, %esi
    movl $RTP_AX_SHIFT, %edx
    call .Lrt_plot_grow
    movq %rdx, %r13
    movq $1, RTP_AX_KIND(%rax)
    movq %r12, RTP_AX_BASE(%rax)
    movq $-1, RTP_AX_TWIN(%rax)
    movq $1, RTP_AX_CYC(%rax)       # Decision 135 (a): starts at #d95319
    movq %r12, %rcx                 # the base (its table may have moved)
    shlq $RTP_AX_SHIFT, %rcx
    addq RTP_FG_AXT(%rbx), %rcx
    movq RTP_AX_ROW(%rcx), %rdx     # the base's cell and spans, copied
    movq %rdx, RTP_AX_ROW(%rax)
    movq RTP_AX_COL(%rcx), %rdx
    movq %rdx, RTP_AX_COL(%rax)
    movq RTP_AX_RS(%rcx), %rdx
    movq %rdx, RTP_AX_RS(%rax)
    movq RTP_AX_CS(%rcx), %rdx
    movq %rdx, RTP_AX_CS(%rax)
    movq %r13, RTP_AX_TWIN(%rcx)
2:  movq %rbx, %rdi
    movq %r13, %rsi
    call .Lrt_plot_mkaxes
    LEAVE 8
    .size sea_twin_y, . - sea_twin_y

# ---------------------------------------------------------------------
# sea_plot -- entry PLOT (66).
#   Purpose : SHAPE_MISMATCH (len(x), len(y)), LINE_STYLE, PLOT_WIDTH
#             (not finite or not > 0), COLOR, in that order; then a line
#             series appended with copies of x and y, its colour resolved
#             now (L-kh), its line code 1 when the style has neither a
#             line part nor a marker.
#   Inputs  : %rdi = ax, %rsi = x, %rdx = y, %rcx = style, %r8 = label,
#             %r9 = color, %xmm0 = width, 8(%rsp) = site (the stack
#             argument, L-ku)
#   Outputs : none
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = ax, %r12 = x, %r13 = y, %r14 = style, then
#             the data block, %r15 = label, %rbp; locals: 0 color, 8
#             width, 16 line, 24 marker, 32 the style's colour, 40 the
#             colour
#   Frame   : 104 bytes (ENTER 56)
# ---------------------------------------------------------------------
.equ RTP_PL_COLOR,      0
.equ RTP_PL_WIDTH,      8
.equ RTP_PL_LINE,       16
.equ RTP_PL_MARK,       24
.equ RTP_PL_SCOL,       32
.equ RTP_PL_COL,        40
    .globl sea_plot
    .type sea_plot, @function
    .p2align 4
sea_plot:
    ENTER 56
    movq 16(%rbp), %rax             # the site: 8(%rsp) at the entry
    movq %rax, .Lrt_plot_site(%rip)
    movq %rdi, %rbx
    movq %rsi, %r12
    movq %rdx, %r13
    movq %rcx, %r14
    movq %r8, %r15
    movq %r9, RTP_PL_COLOR(%rsp)
    movsd %xmm0, RTP_PL_WIDTH(%rsp)
    # 1. The shapes of x and y (two vectors).
    movq SEA_ARR_ROWS(%r12), %rdx
    movq SEA_ARR_ROWS(%r13), %r8
    cmpq %rdx, %r8
    je 1f
    movl $SEA_E_SHAPE_MISMATCH, %edi
    movq .Lrt_plot_site(%rip), %rsi
    movq $SEA_SHAPE_VEC, %rcx
    movq $SEA_SHAPE_VEC, %r9
    call .Lrt_plot_raise
    # 2. The style.
1:  movq %r14, %rdi
    call .Lrt_plot_style
    testq %rax, %rax
    jns 2f
    movl $SEA_E_LINE_STYLE, %edi
    movq .Lrt_plot_site(%rip), %rsi
    movq %r14, %rdx
    call .Lrt_plot_raise
2:  movq %rax, RTP_PL_LINE(%rsp)
    movq %rdx, RTP_PL_MARK(%rsp)
    movq %rcx, RTP_PL_SCOL(%rsp)
    # 3. The width: finite and > 0.
    movsd RTP_PL_WIDTH(%rsp), %xmm0
    xorpd %xmm1, %xmm1
    ucomisd %xmm1, %xmm0
    jbe 3f                          # <= 0 or NaN
    movq RTP_PL_WIDTH(%rsp), %rax
    movabsq $RTP_B_INF, %rcx
    cmpq %rcx, %rax
    jb 4f                           # positive and finite
3:  movl $SEA_E_PLOT_WIDTH, %edi
    movq .Lrt_plot_site(%rip), %rsi
    movq RTP_PL_WIDTH(%rsp), %rdx
    call .Lrt_plot_raise
    # 4. The colour.
4:  movq RTP_PL_COLOR(%rsp), %rdi
    call .Lrt_plot_colorarg
    cmpq $-2, %rax
    jne 5f
    movl $SEA_E_COLOR, %edi
    movq .Lrt_plot_site(%rip), %rsi
    movq RTP_PL_COLOR(%rsp), %rdx
    call .Lrt_plot_raise
5:  movq %rbx, %rdi                 # resolve it now (L-kh)
    movq %rax, %rsi
    movq RTP_PL_SCOL(%rsp), %rdx
    call .Lrt_plot_rescol
    movq %rax, RTP_PL_COL(%rsp)
    movq RTP_PL_LINE(%rsp), %rax    # neither a line part nor a marker: solid
    orq RTP_PL_MARK(%rsp), %rax
    jnz 6f
    movq $1, RTP_PL_LINE(%rsp)
    # 5. The data copy: x then y, 16n bytes (none when n = 0).
6:  xorl %r14d, %r14d
    movq SEA_ARR_ROWS(%r12), %rdi
    testq %rdi, %rdi
    jz 7f
    shlq $4, %rdi
    movq .Lrt_plot_site(%rip), %rsi
    call sea_alloc
    movq %rax, %r14
    movq %r14, %rdi
    movq SEA_ARR_DATA(%r12), %rsi
    movq SEA_ARR_ROWS(%r12), %rdx
    shlq $3, %rdx
    call memcpy@PLT
    movq SEA_ARR_ROWS(%r12), %rdi
    leaq (%r14,%rdi,8), %rdi
    movq SEA_ARR_DATA(%r13), %rsi
    movq SEA_ARR_ROWS(%r12), %rdx
    shlq $3, %rdx
    call memcpy@PLT
    # 6. The record.
7:  movq RTP_AH_FIG(%rbx), %rdi
    movl $RTP_FG_NSR, %esi
    movl $RTP_SR_SHIFT, %edx
    call .Lrt_plot_grow
    movq $RTP_SK_LINE, RTP_SR_KIND(%rax)
    movq RTP_AH_IDX(%rbx), %rcx
    movq %rcx, RTP_SR_AX(%rax)
    movq RTP_PL_COL(%rsp), %rcx
    movq %rcx, RTP_SR_COLOR(%rax)
    movq RTP_PL_LINE(%rsp), %rcx
    movq %rcx, RTP_SR_LINE(%rax)
    movq RTP_PL_MARK(%rsp), %rcx
    movq %rcx, RTP_SR_MARK(%rax)
    movq RTP_PL_WIDTH(%rsp), %rcx
    movq %rcx, RTP_SR_WIDTH(%rax)
    movq SEA_ARR_ROWS(%r12), %rcx
    movq %rcx, RTP_SR_N(%rax)
    movq %r14, RTP_SR_DATA(%rax)
    cmpq $0, SEA_STR_LEN(%r15)
    je 8f                           # label "": stored as 0
    movq %r15, RTP_SR_LABEL(%rax)
    movq %r15, %rdi
    call sea_retain
8:  LEAVE 56
    .size sea_plot, . - sea_plot

# ---------------------------------------------------------------------
# sea_xline -- entry XLINE (67).
#   Purpose : LINE_STYLE (a marker included, L-ki), then COLOR; an xline
#             series appended (line code 1 when the style has none), its
#             colour resolved now.
#   Inputs  : %rdi = ax, %xmm0 = x, %rsi = style, %rdx = color, %rcx =
#             site
#   Outputs : none
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = ax, %r12 = style, %r13 = color, %r14 =
#             the line code, %r15 = the colour, %rbp; locals: 0 x, 8 the
#             style's colour
#   Frame   : 72 bytes (ENTER 24)
# ---------------------------------------------------------------------
    .globl sea_xline
    .type sea_xline, @function
    .p2align 4
sea_xline:
    ENTER 24
    movq %rcx, .Lrt_plot_site(%rip)
    movq %rdi, %rbx
    movq %rsi, %r12
    movq %rdx, %r13
    movsd %xmm0, 0(%rsp)
    movq %r12, %rdi
    call .Lrt_plot_style
    testq %rax, %rax
    js 1f
    testq %rdx, %rdx
    jz 2f                           # no marker: valid
1:  movl $SEA_E_LINE_STYLE, %edi
    movq .Lrt_plot_site(%rip), %rsi
    movq %r12, %rdx
    call .Lrt_plot_raise
2:  movq %rax, %r14
    movq %rcx, 8(%rsp)
    testq %r14, %r14
    jnz 3f
    movl $1, %r14d                  # no line part: solid
3:  movq %r13, %rdi
    call .Lrt_plot_colorarg
    cmpq $-2, %rax
    jne 4f
    movl $SEA_E_COLOR, %edi
    movq .Lrt_plot_site(%rip), %rsi
    movq %r13, %rdx
    call .Lrt_plot_raise
4:  movq %rbx, %rdi
    movq %rax, %rsi
    movq 8(%rsp), %rdx
    call .Lrt_plot_rescol
    movq %rax, %r15
    movq RTP_AH_FIG(%rbx), %rdi
    movl $RTP_FG_NSR, %esi
    movl $RTP_SR_SHIFT, %edx
    call .Lrt_plot_grow
    movq $RTP_SK_XLINE, RTP_SR_KIND(%rax)
    movq RTP_AH_IDX(%rbx), %rcx
    movq %rcx, RTP_SR_AX(%rax)
    movq %r15, RTP_SR_COLOR(%rax)
    movq %r14, RTP_SR_LINE(%rax)
    movq 0(%rsp), %rcx
    movq %rcx, RTP_SR_XPOS(%rax)
    LEAVE 24
    .size sea_xline, . - sea_xline

# ---------------------------------------------------------------------
# sea_xlabel, sea_ylabel, sea_title -- entries XLABEL, YLABEL, TITLE
#   (72 - 74): the pair's x label (base record), ax's own y label, the
#   pair's title (base record) become s (retained; the previous one
#   released). Cannot fail.
#   Inputs  : %rdi = ax, %rsi = s
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbp.  Frame: 8 bytes (%rbp)
# ---------------------------------------------------------------------
    .globl sea_xlabel
    .type sea_xlabel, @function
    .p2align 4
sea_xlabel:
    pushq %rbp                      # %rsp = 0 (mod 16)
    movq %rsp, %rbp
    call .Lrt_plot_recs             # (keeps %rsi)
    leaq RTP_AX_XLAB(%rdx), %rdi
    call .Lrt_plot_setstr
    popq %rbp
    ret
    .size sea_xlabel, . - sea_xlabel

    .globl sea_ylabel
    .type sea_ylabel, @function
    .p2align 4
sea_ylabel:
    pushq %rbp
    movq %rsp, %rbp
    call .Lrt_plot_recs
    leaq RTP_AX_YLAB(%rax), %rdi
    call .Lrt_plot_setstr
    popq %rbp
    ret
    .size sea_ylabel, . - sea_ylabel

    .globl sea_title
    .type sea_title, @function
    .p2align 4
sea_title:
    pushq %rbp
    movq %rsp, %rbp
    call .Lrt_plot_recs
    leaq RTP_AX_TITLE(%rdx), %rdi
    call .Lrt_plot_setstr
    popq %rbp
    ret
    .size sea_title, . - sea_title

# ---------------------------------------------------------------------
# sea_legend -- entry LEGEND (75): LEGEND_LOC unless loc is one of
#   north south east west northeast northwest southeast southwest (1 -
#   8) or best (5, L-kn); the pair's legend location.
#   Inputs  : %rdi = ax, %rsi = loc, %rdx = site
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbp.  Frame: 8 bytes (%rbp)
# ---------------------------------------------------------------------
    .globl sea_legend
    .type sea_legend, @function
    .p2align 4
sea_legend:
    pushq %rbp
    movq %rsp, %rbp
    movq %rdx, %r10                 # the site (.Lrt_plot_recs clobbers %rdx)
    call .Lrt_plot_recs             # %rdx = base record
    leaq .Lrt_plot_locs(%rip), %r9  # entries: length byte, the name, the code byte
1:  movzbl (%r9), %ecx
    testl %ecx, %ecx
    jz 9f                           # no name matches
    cmpq SEA_STR_LEN(%rsi), %rcx
    jne 3f
    xorl %eax, %eax                 # compare the bytes
2:  cmpq %rcx, %rax
    jae 4f
    movb 1(%r9,%rax), %r11b
    cmpb SEA_STR_BYTES(%rsi,%rax), %r11b
    jne 3f
    incq %rax
    jmp 2b
3:  leaq 2(%r9,%rcx), %r9           # the next entry
    jmp 1b
4:  movzbl 1(%r9,%rcx), %eax        # the code
    movq %rax, RTP_AX_LEG(%rdx)
    popq %rbp
    ret
9:  movq %rsi, %rdx                 # LEGEND_LOC with the whole string
    movl $SEA_E_LEGEND_LOC, %edi
    movq %r10, %rsi
    call .Lrt_plot_raise
    .size sea_legend, . - sea_legend

# ---------------------------------------------------------------------
# sea_grid -- entry GRID (76): the pair's grid switch. Cannot fail.
#   Inputs  : %rdi = ax, %rsi = on (0 / 1)
#   Clobbers: %rax %rcx %rdx %r8 %r9, flags.  Frame: none (leaf)
# ---------------------------------------------------------------------
    .globl sea_grid
    .type sea_grid, @function
    .p2align 4
sea_grid:
    call .Lrt_plot_recs
    andq $~RTP_F_GRID, RTP_AX_FLAGS(%rdx)
    testq %rsi, %rsi
    jz 1f
    orq $RTP_F_GRID, RTP_AX_FLAGS(%rdx)
1:  ret
    .size sea_grid, . - sea_grid

# ---------------------------------------------------------------------
# sea_xlim, sea_ylim -- entries XLIM, YLIM (77, 78): AXIS_LIMITS (lo,
#   hi) unless both are finite and lo < hi; the pair's x limits (base
#   record) / ax's own y limits, and their flag.
#   Inputs  : %rdi = ax, %xmm0 = lo, %xmm1 = hi, %rsi = site
#   Clobbers: all caller-saved registers.  Frame: none (a leaf unless it
#             raises)
# ---------------------------------------------------------------------
    .globl sea_xlim
    .type sea_xlim, @function
    .p2align 4
sea_xlim:
    xorl %r10d, %r10d               # x: the base record
    jmp .Lrt_plot_lim
    .size sea_xlim, . - sea_xlim

    .globl sea_ylim
    .type sea_ylim, @function
    .p2align 4
sea_ylim:
    movl $1, %r10d                  # y: ax's own record
    .size sea_ylim, . - sea_ylim
.Lrt_plot_lim:
    NONFIN %xmm0, 8f
    NONFIN %xmm1, 8f
    ucomisd %xmm1, %xmm0
    jae 8f                          # lo >= hi
    call .Lrt_plot_recs
    testl %r10d, %r10d
    jnz 1f
    movsd %xmm0, RTP_AX_XLO(%rdx)
    movsd %xmm1, RTP_AX_XHI(%rdx)
    orq $RTP_F_XLIM, RTP_AX_FLAGS(%rdx)
    ret
1:  movsd %xmm0, RTP_AX_YLO(%rax)
    movsd %xmm1, RTP_AX_YHI(%rax)
    orq $RTP_F_YLIM, RTP_AX_FLAGS(%rax)
    ret
8:  movl $SEA_E_AXIS_LIMITS, %edi
    movq %xmm0, %rdx
    movq %xmm1, %rcx
    call .Lrt_plot_raise            # (%rsi = site)

# ---------------------------------------------------------------------
# sea_x_ticks, sea_y_ticks -- entries X_TICKS, Y_TICKS (79, 80): the
#   pair's x category labels (base record) / ax's own y category labels
#   become the strings of labels (a new block of n pointers, each string
#   retained; none for n = 0, which returns to numeric ticks); the
#   previous labels are released and their block freed.
#   Inputs  : %rdi = ax, %rsi = labels (a str[] vector), %rdx = site
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = labels, %r12 = n, %r13 = the field's
#             address (block, then count at +8), %r14 = the new block,
#             %r15 = the index, %rbp.  Frame: 56 bytes (ENTER 8)
# ---------------------------------------------------------------------
    .globl sea_x_ticks
    .type sea_x_ticks, @function
    .p2align 4
sea_x_ticks:
    xorl %ecx, %ecx                 # x
    jmp .Lrt_plot_ticks
    .size sea_x_ticks, . - sea_x_ticks

    .globl sea_y_ticks
    .type sea_y_ticks, @function
    .p2align 4
sea_y_ticks:
    movl $1, %ecx                   # y
    .size sea_y_ticks, . - sea_y_ticks
.Lrt_plot_ticks:
    ENTER 8
    movq %rdx, .Lrt_plot_site(%rip)
    movq %rsi, %rbx
    movq SEA_ARR_ROWS(%rbx), %r12
    movl %ecx, %r14d
    call .Lrt_plot_recs
    leaq RTP_AX_XCAT(%rdx), %r13
    testl %r14d, %r14d
    jz 1f
    leaq RTP_AX_YCAT(%rax), %r13
1:  xorl %r14d, %r14d               # the new block (none when n = 0)
    testq %r12, %r12
    jz 3f
    leaq (,%r12,8), %rdi
    movq .Lrt_plot_site(%rip), %rsi
    call sea_alloc
    movq %rax, %r14
    xorl %r15d, %r15d
2:  movq SEA_ARR_DATA(%rbx), %rax
    movq (%rax,%r15,8), %rdi
    movq %rdi, (%r14,%r15,8)
    call sea_retain                 # each label
    incq %r15
    cmpq %r12, %r15
    jb 2b
3:  movq (%r13), %rbx               # the previous labels: released, block freed
    testq %rbx, %rbx
    jz 5f
    xorl %r15d, %r15d
4:  movq (%rbx,%r15,8), %rdi
    call sea_release
    incq %r15
    cmpq 8(%r13), %r15
    jb 4b
    movq %rbx, %rdi
    movq 8(%r13), %rsi
    shlq $3, %rsi
    call sea_free_block
5:  movq %r14, (%r13)
    movq %r12, 8(%r13)
    LEAVE 8

# ---------------------------------------------------------------------
# sea_y_reverse, sea_axis_equal -- entries Y_REVERSE, AXIS_EQUAL (81,
#   82): ax's own y-axis runs downward / the pair's base axes get equal
#   data units. Cannot fail.
#   Inputs  : %rdi = ax
#   Clobbers: %rax %rcx %rdx %r8 %r9, flags.  Frame: none (leaf)
# ---------------------------------------------------------------------
    .globl sea_y_reverse
    .type sea_y_reverse, @function
    .p2align 4
sea_y_reverse:
    call .Lrt_plot_recs
    orq $RTP_F_YREV, RTP_AX_FLAGS(%rax)
    ret
    .size sea_y_reverse, . - sea_y_reverse

    .globl sea_axis_equal
    .type sea_axis_equal, @function
    .p2align 4
sea_axis_equal:
    call .Lrt_plot_recs
    orq $RTP_F_EQUAL, RTP_AX_FLAGS(%rdx)
    ret
    .size sea_axis_equal, . - sea_axis_equal

# =====================================================================
# Limits and ticks (DESIGN.md 2.14.6 "Limits", "Tick labels"; L-kk)
# =====================================================================

# ---------------------------------------------------------------------
# .Lrt_plot_widen -- the default limits before the step (limits 4): no
#   extent: 0 .. 1; lo = hi = v: v - |v|/10 .. v + |v|/10, or -1 .. 1
#   for v = 0; if either is not finite, v - 1 .. v + 1, and 0 .. 1 if
#   those are equal; else the extent itself.
#   Inputs  : %rdi = the descriptor
#   Outputs : %xmm0 = lo, %xmm1 = hi
#   Clobbers: %rax, %rcx, %xmm2, %xmm3, flags.  Frame: none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
SHAREF sea_plt_widen
.Lrt_plot_widen:
    cmpq $0, RTP_A_EHAS(%rdi)
    je 5f
    movsd RTP_A_ELO(%rdi), %xmm0
    movsd RTP_A_EHI(%rdi), %xmm1
    ucomisd %xmm1, %xmm0
    jne 9f                          # a range: the extent
    xorpd %xmm2, %xmm2
    ucomisd %xmm2, %xmm0
    jne 1f
    movsd .Lrt_plot_c_one(%rip), %xmm1 # v = 0: -1 .. 1
    movapd %xmm1, %xmm0
    xorpd .Lrt_plot_c_sign(%rip), %xmm0
    ret
1:  movapd %xmm0, %xmm2             # v
    andpd .Lrt_plot_c_abs(%rip), %xmm2
    divsd .Lrt_plot_c_ten(%rip), %xmm2 # |v| / 10
    movapd %xmm0, %xmm3
    subsd %xmm2, %xmm0              # v - |v|/10
    addsd %xmm3, %xmm2              # v + |v|/10 (= |v|/10 + v exactly)
    movapd %xmm2, %xmm1
    NONFIN %xmm0, 2f
    NONFIN %xmm1, 2f
    ret
2:  movapd %xmm3, %xmm0             # v - 1 .. v + 1
    subsd .Lrt_plot_c_one(%rip), %xmm0
    movapd %xmm3, %xmm1
    addsd .Lrt_plot_c_one(%rip), %xmm1
    ucomisd %xmm1, %xmm0
    jne 9f
5:  xorpd %xmm0, %xmm0              # 0 .. 1
    movsd .Lrt_plot_c_one(%rip), %xmm1
9:  ret

# ---------------------------------------------------------------------
# .Lrt_plot_tickgen -- the numeric ticks (c0 + f64(i)) * s for i = 0 ..
#   m (m <= 7), each kept unless it equals the last tick kept or is not
#   finite (limits 5).
#   Inputs  : %rdi = the descriptor, %xmm0 = c0, %xmm1 = s, %rsi = m
#   Outputs : RTP_A_NT and RTP_A_TV of the descriptor
#   Clobbers: %rax, %rcx, %rdx, %r8, %xmm2 - %xmm4, flags
#   Frame   : none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot_tickgen:
    movq $0, RTP_A_NT(%rdi)
    movabsq $RTP_B_QNAN, %rax
    movq %rax, %xmm4                # the last tick drawn: none (NaN equals nothing)
    xorl %edx, %edx                 # i
1:  cmpq %rsi, %rdx
    ja 3f
    cvtsi2sdq %rdx, %xmm2
    addsd %xmm0, %xmm2              # c0 + f64(i) (= f64(i) + c0 exactly)
    mulsd %xmm1, %xmm2              # * s
    ucomisd %xmm4, %xmm2
    jnp 2f                          # ordered: equal?
    jmp 4f
2:  je 5f                           # equal to the last one drawn: not drawn
4:  movq %xmm2, %rax
    shlq $1, %rax
    movabsq $RTP_B_INF2, %rcx
    cmpq %rcx, %rax
    jae 5f                          # not finite: not drawn
    movq RTP_A_NT(%rdi), %r8
    movsd %xmm2, RTP_A_TV(%rdi,%r8,8)
    incq RTP_A_NT(%rdi)
    movapd %xmm2, %xmm4             # the last tick drawn
5:  incq %rdx
    jmp 1b
3:  ret

# ---------------------------------------------------------------------
# .Lrt_plot_inside -- explicit-limit ticks of [lo, hi] (limits 1, 3, 6):
#   the step of [lo, hi]; c0 = ceil(lo / s), m = floor(hi / s) - c0 (no
#   tick when negative; at most 7 since count(s) <= 7 bounds it, and
#   clamped to 7 before the conversion all the same).
#   Inputs  : %rdi = the descriptor (RTP_A_LO, RTP_A_HI set)
#   Outputs : RTP_A_S, RTP_A_K, RTP_A_NT, RTP_A_TV (RTP_A_NT 0 when there
#             is no step)
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = the descriptor, %rbp; locals 0 s, 8 c0
#   Frame   : 72 bytes (ENTER 24)
# ---------------------------------------------------------------------
    .p2align 4
SHAREF sea_plt_inside
.Lrt_plot_inside:
    ENTER 24
    movq %rdi, %rbx
    movq $0, RTP_A_NT(%rbx)
    movsd RTP_A_LO(%rbx), %xmm0
    movsd RTP_A_HI(%rbx), %xmm1
    call .Lrt_plot_step
    testl %eax, %eax
    jz 9f                           # no step: no ticks
    movsd %xmm0, RTP_A_S(%rbx)
    movsd %xmm0, 0(%rsp)
    movslq %edx, %rdx
    movq %rdx, RTP_A_K(%rbx)
    movsd RTP_A_LO(%rbx), %xmm0     # c0 = ceil(lo / s)
    divsd 0(%rsp), %xmm0
    call .Lrt_plot_ceil
    movsd %xmm0, 8(%rsp)
    movsd RTP_A_HI(%rbx), %xmm0     # floor(hi / s) - c0
    divsd 0(%rsp), %xmm0
    call .Lrt_plot_floor
    subsd 8(%rsp), %xmm0
    xorpd %xmm1, %xmm1
    ucomisd %xmm1, %xmm0
    jb 9f                           # negative: no tick
    movsd .Lrt_plot_c_seven(%rip), %xmm1
    ucomisd %xmm1, %xmm0
    jbe 1f
    movapd %xmm1, %xmm0             # (never more than 7)
1:  cvttsd2si %xmm0, %rsi           # m, 0 .. 7
    movq %rbx, %rdi
    movsd 8(%rsp), %xmm0
    movsd 0(%rsp), %xmm1
    call .Lrt_plot_tickgen
9:  LEAVE 24

# ---------------------------------------------------------------------
# .Lrt_plot_limits -- one axis's limits and numeric ticks (limits 1 -
#   5, in that order): explicit limits keep their values with the
#   inside ticks, numeric even with category labels (RTP_A_NCAT is
#   cleared in the descriptor);
#   category labels give -0.5 .. n - 0.5, widened to the extent (their
#   ticks are chosen by .Lrt_plot_catrange); a pair holding an image
#   takes the extent itself (widened as in 4) with the inside ticks; else
#   the default rule (step, floor and ceil to it, the ticks from
#   floor(lo / s), or the widened limits and no ticks when there is no
#   step or a rounded limit is not finite).
#   Inputs  : %rdi = the descriptor (extent, explicit limits, categories
#             set); .Lrt_plot_tight
#   Outputs : RTP_A_LO, RTP_A_HI and the numeric ticks
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = the descriptor, %rbp; locals 0 lo, 8 hi,
#             16 s, 24 floor(lo / s), 32 hi'
#   Frame   : 88 bytes (ENTER 40)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot_limits:
    ENTER 40
    movq %rdi, %rbx
    movq $0, RTP_A_NT(%rbx)
    cmpq $0, RTP_A_EXPL(%rbx)
    je 1f
    movsd RTP_A_XLO(%rbx), %xmm0    # 1. explicit
    movsd %xmm0, RTP_A_LO(%rbx)
    movsd RTP_A_XHI(%rbx), %xmm0
    movsd %xmm0, RTP_A_HI(%rbx)
    movq $0, RTP_A_NCAT(%rbx)       # numeric ticks, category labels or not
    movq %rbx, %rdi
    call .Lrt_plot_inside
    jmp 9f
1:  movq RTP_A_NCAT(%rbx), %rax
    testq %rax, %rax
    jz 3f
    cvtsi2sdq %rax, %xmm1           # 2. category: -0.5 .. f64(n) - 0.5
    subsd .Lrt_plot_c_half(%rip), %xmm1
    movsd .Lrt_plot_c_mhalf(%rip), %xmm0
    cmpq $0, RTP_A_EHAS(%rbx)
    je 2f
    movsd RTP_A_ELO(%rbx), %xmm2    # min(-0.5, extent lo)
    ucomisd %xmm0, %xmm2
    jae 21f
    movapd %xmm2, %xmm0
21: movsd RTP_A_EHI(%rbx), %xmm2    # max(f64(n) - 0.5, extent hi)
    ucomisd %xmm1, %xmm2
    jbe 2f
    movapd %xmm2, %xmm1
2:  movsd %xmm0, RTP_A_LO(%rbx)
    movsd %xmm1, RTP_A_HI(%rbx)
    jmp 9f
3:  movq %rbx, %rdi
    call .Lrt_plot_widen            # %xmm0 = lo, %xmm1 = hi
    movsd %xmm0, 0(%rsp)
    movsd %xmm1, 8(%rsp)
    movsd %xmm0, RTP_A_LO(%rbx)     # (kept when there is no step)
    movsd %xmm1, RTP_A_HI(%rbx)
    cmpq $0, .Lrt_plot_tight(%rip)
    je 4f
    movq %rbx, %rdi                 # 3. tight: the inside ticks
    call .Lrt_plot_inside
    jmp 9f
4:  call .Lrt_plot_step             # 4. default (%xmm0, %xmm1 still lo, hi)
    testl %eax, %eax
    jz 9f                           # no step: lo .. hi, no ticks
    movsd %xmm0, 16(%rsp)
    movsd %xmm0, RTP_A_S(%rbx)
    movslq %edx, %rdx
    movq %rdx, RTP_A_K(%rbx)
    movsd 8(%rsp), %xmm0            # hi' = ceil(hi / s) * s
    divsd 16(%rsp), %xmm0
    call .Lrt_plot_ceil
    mulsd 16(%rsp), %xmm0
    NONFIN %xmm0, 9f                # not finite: lo .. hi, no ticks
    movsd %xmm0, 32(%rsp)
    movsd 0(%rsp), %xmm0            # lo' = floor(lo / s) * s
    divsd 16(%rsp), %xmm0
    call .Lrt_plot_floor
    movsd %xmm0, 24(%rsp)           # floor(lo / s), the first tick's multiple
    mulsd 16(%rsp), %xmm0
    NONFIN %xmm0, 9f
    movsd %xmm0, RTP_A_LO(%rbx)     # both finite: the rounded limits
    movsd 32(%rsp), %xmm0
    movsd %xmm0, RTP_A_HI(%rbx)
    movsd 0(%rsp), %xmm0            # count(s) of the unrounded lo, hi
    movsd 8(%rsp), %xmm1
    movsd 16(%rsp), %xmm2
    call .Lrt_plot_count            # 0 .. 7: the step passed that test
    cvttsd2si %xmm0, %rsi
    movq %rbx, %rdi
    movsd 24(%rsp), %xmm0
    movsd 16(%rsp), %xmm1
    call .Lrt_plot_tickgen
9:  LEAVE 40

# ---------------------------------------------------------------------
# .Lrt_plot_equal -- axis equal on the base axes (limits 6): ux = (xhi -
#   xlo) / pw, uy = (yhi - ylo) / ph; if ux > uy the y limits become c -
#   (ux * ph) / 2 .. c + (ux * ph) / 2 with c = (ylo + yhi) / 2, else the
#   x limits likewise with uy * pw; the changed axis gets the numeric
#   inside ticks of its new limits, a category axis included (its
#   RTP_A_NCAT cleared); if a new limit is not finite, nothing changes.
#   Inputs  : the x and y descriptors, the layout
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = the descriptor that changes, %rbp; locals
#             0 the new lo, 8 the new hi
#   Frame   : 72 bytes (ENTER 24)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot_equal:
    ENTER 24
    AXD %rax, 0
    AXD %rcx, 1
    movsd RTP_A_HI(%rax), %xmm0     # ux
    subsd RTP_A_LO(%rax), %xmm0
    divsd .Lrt_plot_pw(%rip), %xmm0
    movsd RTP_A_HI(%rcx), %xmm1     # uy
    subsd RTP_A_LO(%rcx), %xmm1
    divsd .Lrt_plot_ph(%rip), %xmm1
    ucomisd %xmm1, %xmm0
    jbe 1f
    movq %rcx, %rbx                 # ux > uy: the y limits
    mulsd .Lrt_plot_ph(%rip), %xmm0 # ux * ph
    jmp 2f
1:  movq %rax, %rbx                 # else the x limits
    movapd %xmm1, %xmm0
    mulsd .Lrt_plot_pw(%rip), %xmm0 # uy * pw
2:  divsd .Lrt_plot_c_two(%rip), %xmm0 # half the new range
    movsd RTP_A_LO(%rbx), %xmm1     # c = (lo + hi) / 2
    addsd RTP_A_HI(%rbx), %xmm1
    divsd .Lrt_plot_c_two(%rip), %xmm1
    movapd %xmm1, %xmm2
    subsd %xmm0, %xmm2              # c - d
    addsd %xmm0, %xmm1              # c + d
    NONFIN %xmm2, 9f
    NONFIN %xmm1, 9f
    movsd %xmm2, RTP_A_LO(%rbx)
    movsd %xmm1, RTP_A_HI(%rbx)
    movq $0, RTP_A_NCAT(%rbx)       # explicit-limit ticks, a category axis's too
    movq %rbx, %rdi
    call .Lrt_plot_inside
9:  LEAVE 24

# ---------------------------------------------------------------------
# .Lrt_plot_catrange -- the category ticks of an axis: i = 0 .. n - 1
#   with lo <= f64(i) <= hi (a contiguous run: its first index and its
#   length).
#   Inputs  : %rdi = the descriptor
#   Outputs : RTP_A_I0, RTP_A_NT (unchanged for a numeric axis)
#   Clobbers: %rax, %rcx, %rdx, %xmm0, flags.  Frame: none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot_catrange:
    movq RTP_A_NCAT(%rdi), %rcx
    testq %rcx, %rcx
    jz 9f
    movq $0, RTP_A_NT(%rdi)
    xorl %edx, %edx
1:  cmpq %rcx, %rdx
    jae 9f
    cvtsi2sdq %rdx, %xmm0
    ucomisd RTP_A_LO(%rdi), %xmm0
    jb 2f                           # below lo
    ucomisd RTP_A_HI(%rdi), %xmm0
    ja 2f                           # above hi
    cmpq $0, RTP_A_NT(%rdi)
    jne 3f
    movq %rdx, RTP_A_I0(%rdi)       # the first one drawn
3:  incq RTP_A_NT(%rdi)
2:  incq %rdx
    jmp 1b
9:  ret

# ---------------------------------------------------------------------
# .Lrt_plot_fmtall -- every numeric tick's text: v + 0.0 (so -0 is 0)
#   under %.<prec><letter>.
#   Inputs  : %rdi = the descriptor, %esi = letter, %rdx = precision
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = the descriptor, %r12 = letter, %r13 =
#             precision, %r14 = the index, %rbp.  Frame: 56 (ENTER 8)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot_fmtall:
    ENTER 8
    movq %rdi, %rbx
    movl %esi, %r12d
    movq %rdx, %r13
    xorl %r14d, %r14d
1:  cmpq RTP_A_NT(%rbx), %r14
    jae 9f
    imulq $RTP_NUMBUF, %r14, %rdi
    leaq RTP_A_TT(%rbx,%rdi), %rdi
    movl %r12d, %esi
    movq %r13, %rdx
    movsd RTP_A_TV(%rbx,%r14,8), %xmm0
    xorpd %xmm1, %xmm1
    addsd %xmm1, %xmm0              # v + 0.0
    call sea_fmt_num
    movq %rax, RTP_A_TL(%rbx,%r14,8)
    incq %r14
    jmp 1b
9:  LEAVE 8

# ---------------------------------------------------------------------
# .Lrt_plot_dups -- whether two adjacent tick texts are equal.
#   Inputs  : %rdi = the descriptor
#   Outputs : %eax = 1 if some text equals the one before it, else 0
#   Clobbers: %rcx, %rdx, %rsi, %r8, %r9, %r10, flags.  Frame: none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot_dups:
    movl $1, %edx                   # i
1:  cmpq RTP_A_NT(%rdi), %rdx
    jae 8f
    movq RTP_A_TL(%rdi,%rdx,8), %rcx
    cmpq -8 + RTP_A_TL(%rdi,%rdx,8), %rcx
    jne 4f                          # lengths differ
    imulq $RTP_NUMBUF, %rdx, %r8
    leaq RTP_A_TT(%rdi,%r8), %r8    # text i
    leaq -RTP_NUMBUF(%r8), %r9      # text i - 1
    xorl %esi, %esi
2:  cmpq %rcx, %rsi
    jae 7f                          # every byte equal
    movb (%r8,%rsi), %r10b
    cmpb (%r9,%rsi), %r10b
    jne 4f
    incq %rsi
    jmp 2b
4:  incq %rdx
    jmp 1b
7:  movl $1, %eax
    ret
8:  xorl %eax, %eax
    ret

# ---------------------------------------------------------------------
# .Lrt_plot_texts -- the numeric tick texts of an axis ("Tick labels"):
#   %g when s >= 1e6 or s < 1e-4, else %.{p}f with p = max(0, -k); when
#   two adjacent texts are equal, %.{q}g with q the smallest of 7 .. 17
#   that makes them all differ (Decision 142 (a)).
#   Inputs  : %rdi = the descriptor
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = the descriptor, %r12 = q, %rbp
#   Frame   : 56 bytes (ENTER 8)
# ---------------------------------------------------------------------
    .p2align 4
SHAREF sea_plt_texts
.Lrt_plot_texts:
    ENTER 8
    movq %rdi, %rbx
    cmpq $0, RTP_A_NCAT(%rbx)
    jne 9f                          # category labels are the texts
    cmpq $0, RTP_A_NT(%rbx)
    je 9f
    movsd RTP_A_S(%rbx), %xmm0
    movl $103, %esi                 # 'g', precision 6
    movl $6, %edx
    ucomisd .Lrt_plot_c_1e6(%rip), %xmm0
    jae 2f                          # s >= 1e6
    ucomisd .Lrt_plot_c_1em4(%rip), %xmm0
    jb 2f                           # s < 1e-4
    movl $102, %esi                 # 'f', p = max(0, -k)
    movq RTP_A_K(%rbx), %rdx
    negq %rdx
    jns 2f
    xorl %edx, %edx
2:  movq %rbx, %rdi
    call .Lrt_plot_fmtall
    movq %rbx, %rdi
    call .Lrt_plot_dups
    testl %eax, %eax
    jz 9f
    movl $7, %r12d                  # %.{q}g, q = 7 .. 17
3:  movq %rbx, %rdi
    movl $103, %esi
    movq %r12, %rdx
    call .Lrt_plot_fmtall
    cmpq $17, %r12
    jae 9f                          # 17 digits always differ
    movq %rbx, %rdi
    call .Lrt_plot_dups
    testl %eax, %eax
    jz 9f
    incq %r12
    jmp 3b
9:  LEAVE 8

# ---------------------------------------------------------------------
# .Lrt_plot_tick -- tick j of an axis of the panel being written.
#   Inputs  : %rdi = the axis (0 x, 1 y, 2 the twin's y), %rsi = j (<
#             its RTP_A_NT)
#   Outputs : %xmm0 = its clamped coordinate (X or Y), %rax = its text,
#             %rdx = the text's length, %ecx = 1 for a category label
#             (escaped when written), else 0
#   Clobbers: %rsi, %r8 - %r11, %xmm1, %xmm2, flags
#   Frame   : none (calls only the leaf .Lrt_plot_map)
# ---------------------------------------------------------------------
    .p2align 4
SHAREF sea_plt_tick
.Lrt_plot_tick:
    imulq $RTP_A_SIZE, %rdi, %r8
    leaq .Lrt_plot_axd(%rip), %rax
    addq %rax, %r8                  # the descriptor
    cmpq $0, RTP_A_NCAT(%r8)
    je 2f
    addq RTP_A_I0(%r8), %rsi        # a category: label i0 + j at f64(i0 + j)
    cvtsi2sdq %rsi, %xmm0
    movq RTP_A_CAT(%r8), %rax
    movq (%rax,%rsi,8), %rax
    xorl %r9d, %r9d                 # (a null label: empty)
    xorl %r10d, %r10d
    testq %rax, %rax
    jz 1f
    leaq SEA_STR_BYTES(%rax), %r9
    movq SEA_STR_LEN(%rax), %r10
1:  movl $1, %r11d
    jmp 3f
2:  movsd RTP_A_TV(%r8,%rsi,8), %xmm0 # numeric: value j and its text
    imulq $RTP_NUMBUF, %rsi, %r9
    leaq RTP_A_TT(%r8,%r9), %r9
    movq RTP_A_TL(%r8,%rsi,8), %r10
    xorl %r11d, %r11d
3:  call .Lrt_plot_map
    movq %r9, %rax
    movq %r10, %rdx
    movl %r11d, %ecx
    ret

# =====================================================================
# The SVG writer (DESIGN.md 2.14.6 "The SVG element grammar")
# =====================================================================

# ---------------------------------------------------------------------
# sea_save_svg -- entry SAVE_SVG (65): the document built in the buffer
#   (the header, the canvas, the heading, each base axes in creation
#   order as one panel group, `</svg>`), written by sea_file_put, which
#   frees the buffer after the write or before reporting its error (L-lc).
#   Inputs  : %rdi = fig, %rsi = path, %rdx = site
#   Outputs : none
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = the figure, %r12 = the path, %r13 = the
#             record index, %r14 = the panel number k, %rbp
#   Frame   : 56 bytes (ENTER 8)
# ---------------------------------------------------------------------
    .globl sea_save_svg
    .type sea_save_svg, @function
    .p2align 4
sea_save_svg:
    ENTER 8
    movq %rdi, %rbx
    movq %rsi, %r12
    movq %rdx, .Lrt_plot_site(%rip)
    movq %rbx, .Lrt_plot_fig(%rip)
    movl $RTP_BUF0, %edi            # the buffer
    movq .Lrt_plot_site(%rip), %rsi
    call sea_alloc
    movq %rax, .Lrt_plot_bufp(%rip)
    movq $0, .Lrt_plot_bufn(%rip)
    movq $RTP_BUF0, .Lrt_plot_bufc(%rip)
    # 1 - 3: the declaration, the root, the canvas.
    LIT "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
    LIT "<svg xmlns=\"http://www.w3.org/2000/svg\" class=\"sea-figure\" width=\""
    movq RTP_FG_W(%rbx), %rdi
    call .Lrt_plot_int
    LIT "\" height=\""
    movq RTP_FG_H(%rbx), %rdi
    call .Lrt_plot_int
    LIT "\" viewBox=\"0 0 "
    movq RTP_FG_W(%rbx), %rdi
    call .Lrt_plot_int
    LIT " "
    movq RTP_FG_H(%rbx), %rdi
    call .Lrt_plot_int
    LIT "\" font-family=\"sans-serif\">\n"
    LIT "<rect class=\"canvas\" x=\"0\" y=\"0\" width=\""
    movq RTP_FG_W(%rbx), %rdi
    call .Lrt_plot_int
    LIT "\" height=\""
    movq RTP_FG_H(%rbx), %rdi
    call .Lrt_plot_int
    LIT "\" fill=\"#ffffff\"/>\n"
    # 4: the heading (and the band hb = 24) when the name is not empty.
    xorpd %xmm0, %xmm0
    movsd %xmm0, .Lrt_plot_hb(%rip)
    movq RTP_FG_NAME(%rbx), %rax
    testq %rax, %rax
    jz 1f
    cmpq $0, SEA_STR_LEN(%rax)
    je 1f
    movl $RTP_HB, %eax
    cvtsi2sdl %eax, %xmm0
    movsd %xmm0, .Lrt_plot_hb(%rip)
    LIT "<text class=\"heading\" x=\""
    cvtsi2sdq RTP_FG_W(%rbx), %xmm0 # f64(W) / 2
    divsd .Lrt_plot_c_two(%rip), %xmm0
    call .Lrt_plot_f2
    LIT "\" y=\"17.00\" font-size=\"14\" text-anchor=\"middle\">"
    movq RTP_FG_NAME(%rbx), %rdi
    call .Lrt_plot_esc
    LIT "</text>\n"
    # The cell size: cw = f64(W) / f64(ncols), ch = (f64(H) - hb) / f64(nrows).
1:  cvtsi2sdq RTP_FG_W(%rbx), %xmm0
    cvtsi2sdq RTP_FG_NCOLS(%rbx), %xmm1
    divsd %xmm1, %xmm0
    movsd %xmm0, .Lrt_plot_cw(%rip)
    cvtsi2sdq RTP_FG_H(%rbx), %xmm0
    subsd .Lrt_plot_hb(%rip), %xmm0
    cvtsi2sdq RTP_FG_NROWS(%rbx), %xmm1
    divsd %xmm1, %xmm0
    movsd %xmm0, .Lrt_plot_ch(%rip)
    # 5: each base axes, in creation order.
    xorl %r13d, %r13d
    xorl %r14d, %r14d
2:  cmpq RTP_FG_NAX(%rbx), %r13
    jae 3f
    movq %r13, %rax
    shlq $RTP_AX_SHIFT, %rax
    addq RTP_FG_AXT(%rbx), %rax
    cmpq $0, RTP_AX_KIND(%rax)
    jne 4f                          # a twin is drawn with its base
    movq %r13, %rdi
    movq %r14, %rsi
    call .Lrt_plot_panel
    incq %r14
4:  incq %r13
    jmp 2b
    # 6: the end; the file (sea_file_put frees the buffer).
3:  LIT "</svg>\n"
    movq %r12, %rdi
    movq .Lrt_plot_bufp(%rip), %rsi
    movq .Lrt_plot_bufn(%rip), %rdx
    movq .Lrt_plot_site(%rip), %rcx
    movq .Lrt_plot_bufc(%rip), %r8  # sea_file_put frees the buffer, on error too
    movq $0, .Lrt_plot_bufp(%rip)
    call sea_file_put
    LEAVE 8
    .size sea_save_svg, . - sea_save_svg

# ---------------------------------------------------------------------
# .Lrt_plot_scales -- the three axis descriptors of the panel being
#   written: their properties, the data extents (a line series' x values
#   to x, its y values to its own axes' y; an xline gives nothing; the x
#   axis takes both axes' series), the limits and ticks of each, axis
#   equal, the category runs and the tick texts.
#   Inputs  : .Lrt_plot_fig, .Lrt_plot_brec, .Lrt_plot_trec, the indices
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = the base record, %r12 = the twin record
#             (or 0), %r13 = the series record, %r14 = series left /
#             point index, %r15 = the series' y descriptor, %rbp;
#             locals 0 the series' n, 8 its data
#   Frame   : 72 bytes (ENTER 24)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot_scales:
    ENTER 24
    movq .Lrt_plot_brec(%rip), %rbx
    movq .Lrt_plot_trec(%rip), %r12
    leaq .Lrt_plot_axd(%rip), %rdi  # clear the three descriptors
    movl $(3 * RTP_A_SIZE / 8), %ecx
    xorl %eax, %eax
    rep stosq
    movq RTP_AX_FLAGS(%rbx), %rcx
    AXD %rdi, 0                     # x: the pair's (base record)
    movq %rcx, %rax
    andq $RTP_F_XLIM, %rax
    movq %rax, RTP_A_EXPL(%rdi)
    movq RTP_AX_XLO(%rbx), %rax
    movq %rax, RTP_A_XLO(%rdi)
    movq RTP_AX_XHI(%rbx), %rax
    movq %rax, RTP_A_XHI(%rdi)
    movq RTP_AX_NXCAT(%rbx), %rax
    movq %rax, RTP_A_NCAT(%rdi)
    movq RTP_AX_XCAT(%rbx), %rax
    movq %rax, RTP_A_CAT(%rdi)
    AXD %rdi, 1                     # y: the base's own
    movq %rbx, %rsi
    call .Lrt_plot_yprops
    testq %r12, %r12
    jz 1f
    AXD %rdi, 2                     # the twin's y
    movq %r12, %rsi
    call .Lrt_plot_yprops
    # The extents.
1:  movq .Lrt_plot_fig(%rip), %rax
    movq RTP_FG_SRT(%rax), %r13
    movq RTP_FG_NSR(%rax), %r14
2:  testq %r14, %r14
    jz 6f
    movq RTP_SR_AX(%r13), %rax
    AXD %r15, 1
    cmpq .Lrt_plot_bidx(%rip), %rax
    je 3f
    AXD %r15, 2
    cmpq .Lrt_plot_tidx(%rip), %rax
    jne 5f                          # another panel's series
3:  movq RTP_SR_KIND(%r13), %rax
    cmpq $RTP_SK_LINE, %rax
    je 31f
    cmpq $RTP_SK_BAR, %rax
    jb 5f                           # an xline gives no extent
    movq %r13, %rdi                 # kinds 3 - 6: rt_plot2.s
    movq %r15, %rsi
    call sea_plt2_ext
    jmp 5f
31: movq RTP_SR_N(%r13), %rax
    movq %rax, 0(%rsp)
    movq RTP_SR_DATA(%r13), %rax
    movq %rax, 8(%rsp)
    pushq %r14                      # (series left, kept across the points)
    pushq %r14
    xorl %r14d, %r14d
4:  cmpq 16(%rsp), %r14
    jae 41f
    movq 24(%rsp), %rax
    movsd (%rax,%r14,8), %xmm0      # x_i to x
    AXD %rdi, 0
    call .Lrt_plot_ext
    movq 16(%rsp), %rcx
    movq 24(%rsp), %rax
    leaq (%rax,%rcx,8), %rax
    movsd (%rax,%r14,8), %xmm0      # y_i to its own y
    movq %r15, %rdi
    call .Lrt_plot_ext
    incq %r14
    jmp 4b
41: popq %r14
    popq %r14
5:  addq $RTP_SR_SIZE, %r13
    decq %r14
    jmp 2b
    # The limits of each axis, then axis equal, then the ticks' texts.
6:  AXD %rdi, 0
    call .Lrt_plot_limits
    AXD %rdi, 1
    call .Lrt_plot_limits
    testq %r12, %r12
    jz 7f
    AXD %rdi, 2
    call .Lrt_plot_limits
7:  testq $RTP_F_EQUAL, RTP_AX_FLAGS(%rbx)
    jz 8f
    call .Lrt_plot_equal
8:  xorl %r13d, %r13d
81: imulq $RTP_A_SIZE, %r13, %rdi
    leaq .Lrt_plot_axd(%rip), %rax
    addq %rax, %rdi
    movq %rdi, %r15
    call .Lrt_plot_catrange
    movq %r15, %rdi
    call .Lrt_plot_texts
    incq %r13
    cmpq $3, %r13
    jb 81b
    LEAVE 24

# ---------------------------------------------------------------------
# .Lrt_plot_yprops -- a y descriptor's properties from an axes record:
#   explicit limits, category labels, the reversed flag.
#   Inputs  : %rdi = the descriptor, %rsi = the axes record
#   Clobbers: %rax, %rcx, flags.  Frame: none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot_yprops:
    movq RTP_AX_FLAGS(%rsi), %rcx
    movq %rcx, %rax
    andq $RTP_F_YLIM, %rax
    movq %rax, RTP_A_EXPL(%rdi)
    andq $RTP_F_YREV, %rcx
    movq %rcx, RTP_A_REV(%rdi)
    movq RTP_AX_YLO(%rsi), %rax
    movq %rax, RTP_A_XLO(%rdi)
    movq RTP_AX_YHI(%rsi), %rax
    movq %rax, RTP_A_XHI(%rdi)
    movq RTP_AX_NYCAT(%rsi), %rax
    movq %rax, RTP_A_NCAT(%rdi)
    movq RTP_AX_YCAT(%rsi), %rax
    movq %rax, RTP_A_CAT(%rdi)
    ret

# ---------------------------------------------------------------------
# .Lrt_plot_panel -- one base axes and its twin as one panel group (the
#   items 5.1 - 5.13 of the grammar; the colorbar of 5.9 is 9c's).
#   Inputs  : %rdi = the base's index, %rsi = k (its rank among bases)
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = the figure, %r12 = the base record, %r13 =
#             the twin record (or 0), %r14 = the tick / series index,
#             %r15 = series left, %rbp; locals 0 k, 8 first (1 until a
#             path piece is written), 16 a coordinate, 24 the text, 32
#             its length, 40 its escape flag, 48 spare
#   Frame   : 104 bytes (ENTER 56)
# ---------------------------------------------------------------------
.equ RTP_P_K,           0
.equ RTP_P_FIRST,       8
.equ RTP_P_C,           16
.equ RTP_P_TXT,         24
.equ RTP_P_TLEN,        32
.equ RTP_P_TESC,        40
# SEP: a space unless this is the first piece of a path.
.macro SEP
    cmpq $0, RTP_P_FIRST(%rsp)
    jne 1f
    LIT " "
1:  movq $0, RTP_P_FIRST(%rsp)
.endm
    .p2align 4
.Lrt_plot_panel:
    ENTER 56
    movq %rsi, RTP_P_K(%rsp)
    movq .Lrt_plot_fig(%rip), %rbx
    movq %rdi, .Lrt_plot_bidx(%rip)
    movq %rdi, %r12
    shlq $RTP_AX_SHIFT, %r12
    addq RTP_FG_AXT(%rbx), %r12     # the base record
    movq %r12, .Lrt_plot_brec(%rip)
    movq RTP_AX_TWIN(%r12), %rax
    movq %rax, .Lrt_plot_tidx(%rip)
    xorl %r13d, %r13d
    testq %rax, %rax
    js 1f
    movq %rax, %r13
    shlq $RTP_AX_SHIFT, %r13
    addq RTP_FG_AXT(%rbx), %r13     # the twin record
1:  movq %r13, .Lrt_plot_trec(%rip)
    # Does the pair hold an image (tight limits), one with a colorbar?
    movq $0, .Lrt_plot_tight(%rip)
    movq $0, .Lrt_plot_cbar(%rip)   # the colorbar's image (the last one, L-ko)
    xorl %r15d, %r15d               # the colorbar flag
    movq RTP_FG_SRT(%rbx), %rcx
    movq RTP_FG_NSR(%rbx), %rdx
2:  testq %rdx, %rdx
    jz 3f
    movq RTP_SR_AX(%rcx), %rax
    cmpq .Lrt_plot_bidx(%rip), %rax
    je 21f
    cmpq .Lrt_plot_tidx(%rip), %rax
    jne 22f
21: cmpq $RTP_SK_IMAGE, RTP_SR_KIND(%rcx)
    jne 22f
    movq $1, .Lrt_plot_tight(%rip)
    cmpq $0, RTP_SR_FLAG(%rcx)
    je 22f
    movl $1, %r15d
    movq %rcx, .Lrt_plot_cbar(%rip)
22: addq $RTP_SR_SIZE, %rcx
    decq %rdx
    jmp 2b
    # The layout (DESIGN.md 2.14.6 "Layout"; mr per L-ko).
3:  movl $RTP_MR, %eax
    testq %r13, %r13
    setnz %cl
    movzbl %cl, %ecx
    addl %r15d, %ecx                # twin + colorbar: 0, 1 or 2
    cmpl $1, %ecx
    jb 4f
    movl $RTP_MR1, %eax
    je 4f
    movl $RTP_MR2, %eax
4:  cvtsi2sdl %eax, %xmm5           # mr
    cvtsi2sdq RTP_AX_COL(%r12), %xmm0 # px = f64(col) * cw + 56
    mulsd .Lrt_plot_cw(%rip), %xmm0
    movl $RTP_ML, %eax
    cvtsi2sdl %eax, %xmm4
    addsd %xmm4, %xmm0
    movsd %xmm0, .Lrt_plot_px(%rip)
    cvtsi2sdq RTP_AX_ROW(%r12), %xmm0 # py = (hb + f64(row) * ch) + 28
    mulsd .Lrt_plot_ch(%rip), %xmm0
    movsd .Lrt_plot_hb(%rip), %xmm1
    addsd %xmm0, %xmm1
    movl $RTP_MT, %eax
    cvtsi2sdl %eax, %xmm2
    addsd %xmm2, %xmm1
    movsd %xmm1, .Lrt_plot_py(%rip)
    cvtsi2sdq RTP_AX_CS(%r12), %xmm0 # pw = (f64(colspan) * cw - 56) - mr
    mulsd .Lrt_plot_cw(%rip), %xmm0
    subsd %xmm4, %xmm0
    subsd %xmm5, %xmm0
    movsd .Lrt_plot_c_one(%rip), %xmm3
    ucomisd %xmm3, %xmm0
    jae 5f
    movapd %xmm3, %xmm0             # below 1: 1
5:  movsd %xmm0, .Lrt_plot_pw(%rip)
    cvtsi2sdq RTP_AX_RS(%r12), %xmm0 # ph = (f64(rowspan) * ch - 28) - 44
    mulsd .Lrt_plot_ch(%rip), %xmm0
    subsd %xmm2, %xmm0
    movl $RTP_MB, %eax
    cvtsi2sdl %eax, %xmm1
    subsd %xmm1, %xmm0
    ucomisd %xmm3, %xmm0
    jae 6f
    movapd %xmm3, %xmm0
6:  movsd %xmm0, .Lrt_plot_ph(%rip)
    call .Lrt_plot_scales
    # 5.1 - 5.3: the group, the clip path, the plot area.
    LIT "<g class=\"panel\" id=\"p"
    movq RTP_P_K(%rsp), %rdi
    call .Lrt_plot_int
    LIT "\">\n<clipPath id=\"c"
    movq RTP_P_K(%rsp), %rdi
    call .Lrt_plot_int
    LIT "\"><rect"
    call .Lrt_plot_box
    LIT "/></clipPath>\n<rect class=\"plot-area\""
    call .Lrt_plot_box
    LIT " fill=\"#ffffff\"/>\n"
    # 5.4: the grid: x ticks `M{X} {py} V{py+ph}`, base y ticks
    # `M{px} {Y} H{px+pw}`.
    testq $RTP_F_GRID, RTP_AX_FLAGS(%r12)
    jz 20f
    LIT "<path class=\"grid\" d=\""
    movq $1, RTP_P_FIRST(%rsp)
    xorl %r14d, %r14d
10: AXD %rax, 0
    cmpq RTP_A_NT(%rax), %r14
    jae 11f
    xorl %edi, %edi
    movq %r14, %rsi
    call .Lrt_plot_tick
    movsd %xmm0, RTP_P_C(%rsp)
    SEP
    LIT "M"
    F2 RTP_P_C(%rsp)
    LIT " "
    F2 .Lrt_plot_py(%rip)
    LIT " V"
    call .Lrt_plot_pyph
    call .Lrt_plot_f2
    incq %r14
    jmp 10b
11: xorl %r14d, %r14d
12: AXD %rax, 1
    cmpq RTP_A_NT(%rax), %r14
    jae 13f
    movl $1, %edi
    movq %r14, %rsi
    call .Lrt_plot_tick
    movsd %xmm0, RTP_P_C(%rsp)
    SEP
    LIT "M"
    F2 .Lrt_plot_px(%rip)
    LIT " "
    F2 RTP_P_C(%rsp)
    LIT " H"
    call .Lrt_plot_pxpw
    call .Lrt_plot_f2
    incq %r14
    jmp 12b
13: LIT "\" fill=\"none\" stroke=\"#dfdfdf\" stroke-width=\"0.50\"/>\n"
    # 5.5: the data group, the pair's series in call order (L-le).
20: LIT "<g class=\"data\" clip-path=\"url(#c"
    movq RTP_P_K(%rsp), %rdi
    call .Lrt_plot_int
    LIT ")\">\n"
    movq RTP_FG_SRT(%rbx), %r14
    movq RTP_FG_NSR(%rbx), %r15
21: testq %r15, %r15
    jz 25f
    movq RTP_SR_AX(%r14), %rax
    movl $1, %esi                   # the series' y-axis
    cmpq .Lrt_plot_bidx(%rip), %rax
    je 22f
    movl $2, %esi
    cmpq .Lrt_plot_tidx(%rip), %rax
    jne 24f
22: movq RTP_SR_KIND(%r14), %rax
    movq %r14, %rdi
    cmpq $RTP_SK_LINE, %rax
    jne 23f
    call .Lrt_plot_wline
    jmp 24f
23: cmpq $RTP_SK_XLINE, %rax
    jne 26f
    call .Lrt_plot_wxline
    jmp 24f
26: call sea_plt2_draw              # kinds 3 - 6: rt_plot2.s (%rdi, %rsi)
24: addq $RTP_SR_SIZE, %r14
    decq %r15
    jmp 21b
25: LIT "</g>\n<rect class=\"axes-box\""
    call .Lrt_plot_box
    LIT " fill=\"none\" stroke=\"#262626\" stroke-width=\"1.00\"/>\n"
    # 5.7: the tick marks: x `M{X} {py+ph} v-5.00`, base y `M{px} {Y}
    # h5.00`, the twin's `M{px+pw} {Y} h-5.00`.
    LIT "<path class=\"tick-marks\" d=\""
    movq $1, RTP_P_FIRST(%rsp)
    xorl %r14d, %r14d
30: AXD %rax, 0
    cmpq RTP_A_NT(%rax), %r14
    jae 31f
    xorl %edi, %edi
    movq %r14, %rsi
    call .Lrt_plot_tick
    movsd %xmm0, RTP_P_C(%rsp)
    SEP
    LIT "M"
    F2 RTP_P_C(%rsp)
    LIT " "
    call .Lrt_plot_pyph
    call .Lrt_plot_f2
    LIT " v-5.00"
    incq %r14
    jmp 30b
31: xorl %r14d, %r14d
32: AXD %rax, 1
    cmpq RTP_A_NT(%rax), %r14
    jae 33f
    movl $1, %edi
    movq %r14, %rsi
    call .Lrt_plot_tick
    movsd %xmm0, RTP_P_C(%rsp)
    SEP
    LIT "M"
    F2 .Lrt_plot_px(%rip)
    LIT " "
    F2 RTP_P_C(%rsp)
    LIT " h5.00"
    incq %r14
    jmp 32b
33: testq %r13, %r13
    jz 36f
    xorl %r14d, %r14d
34: AXD %rax, 2
    cmpq RTP_A_NT(%rax), %r14
    jae 36f
    movl $2, %edi
    movq %r14, %rsi
    call .Lrt_plot_tick
    movsd %xmm0, RTP_P_C(%rsp)
    SEP
    LIT "M"
    call .Lrt_plot_pxpw
    call .Lrt_plot_f2
    LIT " "
    F2 RTP_P_C(%rsp)
    LIT " h-5.00"
    incq %r14
    jmp 34b
36: LIT "\" fill=\"none\" stroke=\"#262626\" stroke-width=\"1.00\"/>\n"
    # 5.8: the tick labels.
    xorl %r14d, %r14d
40: AXD %rax, 0
    cmpq RTP_A_NT(%rax), %r14
    jae 41f
    xorl %edi, %edi
    movq %r14, %rsi
    call .Lrt_plot_tick
    call .Lrt_plot_keept
    LIT "<text class=\"xtick\" x=\""
    F2 RTP_P_C(%rsp)
    LIT "\" y=\""
    call .Lrt_plot_pyph             # (py + ph) + 14
    movl $14, %eax
    cvtsi2sdl %eax, %xmm1
    addsd %xmm1, %xmm0
    call .Lrt_plot_f2
    LIT "\" font-size=\"10\" text-anchor=\"middle\">"
    call .Lrt_plot_putt
    LIT "</text>\n"
    incq %r14
    jmp 40b
41: xorl %r14d, %r14d
42: AXD %rax, 1
    cmpq RTP_A_NT(%rax), %r14
    jae 43f
    movl $1, %edi
    movq %r14, %rsi
    call .Lrt_plot_tick
    call .Lrt_plot_keept
    LIT "<text class=\"ytick\" x=\""
    movsd .Lrt_plot_px(%rip), %xmm0 # px - 6
    movl $6, %eax
    cvtsi2sdl %eax, %xmm1
    subsd %xmm1, %xmm0
    call .Lrt_plot_f2
    LIT "\" y=\""
    call .Lrt_plot_y35
    LIT "\" font-size=\"10\" text-anchor=\"end\">"
    call .Lrt_plot_putt
    LIT "</text>\n"
    incq %r14
    jmp 42b
43: testq %r13, %r13
    jz 50f
    xorl %r14d, %r14d
44: AXD %rax, 2
    cmpq RTP_A_NT(%rax), %r14
    jae 50f
    movl $2, %edi
    movq %r14, %rsi
    call .Lrt_plot_tick
    call .Lrt_plot_keept
    LIT "<text class=\"ytick2\" x=\""
    call .Lrt_plot_pxpw             # (px + pw) + 6
    movl $6, %eax
    cvtsi2sdl %eax, %xmm1
    addsd %xmm1, %xmm0
    call .Lrt_plot_f2
    LIT "\" y=\""
    call .Lrt_plot_y35
    LIT "\" font-size=\"10\" text-anchor=\"start\">"
    call .Lrt_plot_putt
    LIT "</text>\n"
    incq %r14
    jmp 44b
    # 5.9: the colorbar of the pair's last image with colorbar: true.
50: cmpq $0, .Lrt_plot_cbar(%rip)
    je 59f
    call sea_plt2_colorbar
    # 5.10: the axis labels.
59: movq RTP_AX_XLAB(%r12), %rax
    testq %rax, %rax
    jz 51f
    cmpq $0, SEA_STR_LEN(%rax)
    je 51f
    LIT "<text class=\"xlabel\" x=\""
    call .Lrt_plot_xmid
    call .Lrt_plot_f2
    LIT "\" y=\""
    call .Lrt_plot_pyph             # (py + ph) + 34
    movl $34, %eax
    cvtsi2sdl %eax, %xmm1
    addsd %xmm1, %xmm0
    call .Lrt_plot_f2
    LIT "\" font-size=\"12\" text-anchor=\"middle\">"
    movq RTP_AX_XLAB(%r12), %rdi
    call .Lrt_plot_esc
    LIT "</text>\n"
51: movq RTP_AX_YLAB(%r12), %rax
    testq %rax, %rax
    jz 52f
    cmpq $0, SEA_STR_LEN(%rax)
    je 52f
    LIT "<text class=\"ylabel\" font-size=\"12\" text-anchor=\"middle\" transform=\"translate("
    movsd .Lrt_plot_px(%rip), %xmm0 # px - 42
    movl $42, %eax
    cvtsi2sdl %eax, %xmm1
    subsd %xmm1, %xmm0
    call .Lrt_plot_f2
    LIT " "
    call .Lrt_plot_ymid
    call .Lrt_plot_f2
    LIT ") rotate(-90)\">"
    movq RTP_AX_YLAB(%r12), %rdi
    call .Lrt_plot_esc
    LIT "</text>\n"
52: testq %r13, %r13
    jz 53f
    movq RTP_AX_YLAB(%r13), %rax
    testq %rax, %rax
    jz 53f
    cmpq $0, SEA_STR_LEN(%rax)
    je 53f
    LIT "<text class=\"ylabel2\" font-size=\"12\" text-anchor=\"middle\" transform=\"translate("
    call .Lrt_plot_pxpw             # (px + pw) + 48
    movl $48, %eax
    cvtsi2sdl %eax, %xmm1
    addsd %xmm1, %xmm0
    call .Lrt_plot_f2
    LIT " "
    call .Lrt_plot_ymid
    call .Lrt_plot_f2
    LIT ") rotate(90)\">"
    movq RTP_AX_YLAB(%r13), %rdi
    call .Lrt_plot_esc
    LIT "</text>\n"
    # 5.11: the title.
53: movq RTP_AX_TITLE(%r12), %rax
    testq %rax, %rax
    jz 54f
    cmpq $0, SEA_STR_LEN(%rax)
    je 54f
    LIT "<text class=\"title\" x=\""
    call .Lrt_plot_xmid
    call .Lrt_plot_f2
    LIT "\" y=\""
    movsd .Lrt_plot_py(%rip), %xmm0 # py - 8
    movl $8, %eax
    cvtsi2sdl %eax, %xmm1
    subsd %xmm1, %xmm0
    call .Lrt_plot_f2
    LIT "\" font-size=\"14\" text-anchor=\"middle\">"
    movq RTP_AX_TITLE(%r12), %rdi
    call .Lrt_plot_esc
    LIT "</text>\n"
    # 5.12, 5.13: the legend, the end of the group.
54: call .Lrt_plot_legend
    LIT "</g>\n"
    LEAVE 56

# Small pieces of the panel writer (leaves or tail calls on the panel's
# frame layout; each states what it reads).
# .Lrt_plot_pyph -- %xmm0 = py + ph.  Clobbers nothing else.
    .p2align 4
.Lrt_plot_pyph:
    movsd .Lrt_plot_py(%rip), %xmm0
    addsd .Lrt_plot_ph(%rip), %xmm0
    ret
# .Lrt_plot_pxpw -- %xmm0 = px + pw.  Clobbers nothing else.
    .p2align 4
.Lrt_plot_pxpw:
    movsd .Lrt_plot_px(%rip), %xmm0
    addsd .Lrt_plot_pw(%rip), %xmm0
    ret
# .Lrt_plot_xmid -- %xmm0 = px + pw / 2.  Clobbers %xmm1.
    .p2align 4
.Lrt_plot_xmid:
    movsd .Lrt_plot_pw(%rip), %xmm1
    divsd .Lrt_plot_c_two(%rip), %xmm1
    movsd .Lrt_plot_px(%rip), %xmm0
    addsd %xmm1, %xmm0
    ret
# .Lrt_plot_ymid -- %xmm0 = py + ph / 2.  Clobbers %xmm1.
    .p2align 4
.Lrt_plot_ymid:
    movsd .Lrt_plot_ph(%rip), %xmm1
    divsd .Lrt_plot_c_two(%rip), %xmm1
    movsd .Lrt_plot_py(%rip), %xmm0
    addsd %xmm1, %xmm0
    ret
# .Lrt_plot_keept -- store .Lrt_plot_tick's results in the caller's
#   (the panel's) locals RTP_P_C, RTP_P_TXT, RTP_P_TLEN, RTP_P_TESC (8
#   bytes above this routine's return address).  Clobbers nothing else.
    .p2align 4
.Lrt_plot_keept:
    movsd %xmm0, 8 + RTP_P_C(%rsp)
    movq %rax, 8 + RTP_P_TXT(%rsp)
    movq %rdx, 8 + RTP_P_TLEN(%rsp)
    movq %rcx, 8 + RTP_P_TESC(%rsp)
    ret
# .Lrt_plot_putt -- append the tick text kept in the panel's locals.
#   Clobbers all caller-saved registers.  Frame: none (tail jump).
    .p2align 4
.Lrt_plot_putt:
    movq 8 + RTP_P_TXT(%rsp), %rdi
    movq 8 + RTP_P_TLEN(%rsp), %rsi
    movl 8 + RTP_P_TESC(%rsp), %edx
    jmp .Lrt_plot_ttext
# .Lrt_plot_y35 -- append %.2f of the kept coordinate + 3.5.
#   Clobbers all caller-saved registers.  Frame: none (tail jump).
    .p2align 4
.Lrt_plot_y35:
    movsd 8 + RTP_P_C(%rsp), %xmm0
    addsd .Lrt_plot_c_35(%rip), %xmm0
    jmp .Lrt_plot_f2

# ---------------------------------------------------------------------
# .Lrt_plot_box -- append ` x="{px}" y="{py}" width="{pw}"
#   height="{ph}"` (the clip rectangle, the plot area, the axes box).
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbp.  Frame: 8 bytes (%rbp)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot_box:
    pushq %rbp
    movq %rsp, %rbp
    LIT " x=\""
    F2 .Lrt_plot_px(%rip)
    LIT "\" y=\""
    F2 .Lrt_plot_py(%rip)
    LIT "\" width=\""
    F2 .Lrt_plot_pw(%rip)
    LIT "\" height=\""
    F2 .Lrt_plot_ph(%rip)
    LIT "\""
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_plot_wline -- a line series (2.14.6 "Series forms"): if it has a
#   line, `<path class="line" ...>` whose d holds the runs of consecutive
#   finite points (`M{X} {Y}`, then ` L{X} {Y}` per further point, runs
#   joined by one space); then, if it has a marker, `<path
#   class="markers" ...>` with the marker of every finite point.
#   Inputs  : %rdi = the series record, %rsi = its y-axis (1 or 2)
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = the record, %r12 = n, %r13 = x, %r14 = y,
#             %r15 = the point index, %rbp; locals 0 the y-axis, 8 X, 16
#             Y, 24 first, 32 in a run
#   Frame   : 88 bytes (ENTER 40)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot_wline:
    ENTER 40
    movq %rdi, %rbx
    movq %rsi, 0(%rsp)
    movq RTP_SR_N(%rbx), %r12
    movq RTP_SR_DATA(%rbx), %r13
    leaq (%r13,%r12,8), %r14
    cmpq $0, RTP_SR_LINE(%rbx)
    je 20f
    LIT "<path class=\"line\" d=\""
    movq $1, 24(%rsp)
    movq $0, 32(%rsp)
    xorl %r15d, %r15d
1:  cmpq %r12, %r15
    jae 9f
    call .Lrt_plot_pt               # %eax = 1 and X, Y at 8, 16(%rsp) if finite
    testl %eax, %eax
    jnz 2f
    movq $0, 32(%rsp)               # a break: the run ends
    jmp 8f
2:  cmpq $0, 32(%rsp)
    je 3f
    LIT " L"                        # a further point of the run
    jmp 4f
3:  cmpq $0, 24(%rsp)               # a new run
    jne 31f
    LIT " "
31: LIT "M"
    movq $0, 24(%rsp)
    movq $1, 32(%rsp)
4:  F2 8(%rsp)
    LIT " "
    F2 16(%rsp)
8:  incq %r15
    jmp 1b
9:  LIT "\" fill=\"none\" stroke=\""
    movq RTP_SR_COLOR(%rbx), %rdi
    call .Lrt_plot_color
    LIT "\" stroke-width=\""
    F2 RTP_SR_WIDTH(%rbx)
    LIT "\""
    movq RTP_SR_LINE(%rbx), %rdi
    call .Lrt_plot_dash
    LIT "/>\n"
20: cmpq $0, RTP_SR_MARK(%rbx)
    je 29f
    LIT "<path class=\"markers\" d=\""
    movq $1, 24(%rsp)
    xorl %r15d, %r15d
21: cmpq %r12, %r15
    jae 28f
    call .Lrt_plot_pt
    testl %eax, %eax
    jz 27f
    cmpq $0, 24(%rsp)
    jne 22f
    LIT " "
22: movq $0, 24(%rsp)
    movq RTP_SR_MARK(%rbx), %rdi
    movsd 8(%rsp), %xmm0
    movsd 16(%rsp), %xmm1
    call .Lrt_plot_marker
27: incq %r15
    jmp 21b
28: movq %rbx, %rdi
    call .Lrt_plot_mtail
29: LEAVE 40

# .Lrt_plot_pt -- point %r15 of .Lrt_plot_wline's series: %eax = 1 and
#   its clamped X, Y stored at 8 and 16 above the caller's locals base
#   when x and y are finite, else %eax = 0. Reads %r13 (x), %r14 (y),
#   %r15, the caller's local 0 (the y-axis). Clobbers the caller-saved
#   registers but %rax's result.  Frame: none (calls leaves).
    .p2align 4
.Lrt_plot_pt:
    movsd (%r13,%r15,8), %xmm0
    NONFIN %xmm0, 9f
    movsd (%r14,%r15,8), %xmm0
    NONFIN %xmm0, 9f
    movsd (%r13,%r15,8), %xmm0
    xorl %edi, %edi
    call .Lrt_plot_map
    movsd %xmm0, 8 + 8(%rsp)        # X (the caller's 8(%rsp))
    movsd (%r14,%r15,8), %xmm0
    movq 8 + 0(%rsp), %rdi          # the series' y-axis
    call .Lrt_plot_map
    movsd %xmm0, 8 + 16(%rsp)       # Y
    movl $1, %eax
    ret
9:  xorl %eax, %eax
    ret

# ---------------------------------------------------------------------
# .Lrt_plot_mtail -- the end of a markers element: `" fill="{f}"
#   stroke="{c}" stroke-width="1.00"/>`, f `none`, or the colour for `.`.
#   Inputs  : %rdi = the series record
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = the record, %rbp.  Frame: 24 bytes
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot_mtail:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp                   # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    LIT "\" fill=\""
    cmpq $RTP_MK_DOT, RTP_SR_MARK(%rbx)
    jne 1f
    movq RTP_SR_COLOR(%rbx), %rdi
    call .Lrt_plot_color
    jmp 2f
1:  LIT "none"
2:  LIT "\" stroke=\""
    movq RTP_SR_COLOR(%rbx), %rdi
    call .Lrt_plot_color
    LIT "\" stroke-width=\"1.00\"/>\n"
    addq $8, %rsp
    popq %rbx
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_plot_wxline -- an xline series: `<path class="xline" d="{d}"
#   fill="none" stroke="{c}" stroke-width="1.00"[ dash]/>`, d `M{X} {py}
#   V{py+ph}` for a finite position, else empty (L-kj).
#   Inputs  : %rdi = the series record
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = the record, %rbp; 0(%rsp) = X
#   Frame   : 24 bytes (%rbp %rbx + 8)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot_wxline:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp                   # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    LIT "<path class=\"xline\" d=\""
    movsd RTP_SR_XPOS(%rbx), %xmm0
    NONFIN %xmm0, 1f
    xorl %edi, %edi
    call .Lrt_plot_map
    movsd %xmm0, 0(%rsp)
    LIT "M"
    F2 0(%rsp)
    LIT " "
    F2 .Lrt_plot_py(%rip)
    LIT " V"
    call .Lrt_plot_pyph
    call .Lrt_plot_f2
1:  LIT "\" fill=\"none\" stroke=\""
    movq RTP_SR_COLOR(%rbx), %rdi
    call .Lrt_plot_color
    LIT "\" stroke-width=\"1.00\""
    movq RTP_SR_LINE(%rbx), %rdi
    call .Lrt_plot_dash
    LIT "/>\n"
    addq $8, %rsp
    popq %rbx
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_plot_marker -- one marker's path piece centred at (X, Y) from its
#   template (.Lrt_plot_mk_*): literal bytes, and the codes 1 (X + off)
#   and 2 (Y + off) followed by a signed byte off, written %.2f (off 0:
#   the coordinate itself; X - 3 is X + (-3), the same IEEE result).
#   Inputs  : %rdi = the marker code (1 - 9), %xmm0 = X, %xmm1 = Y
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = the template cursor, %r12 = the end of a
#             literal run, %rbp; 0(%rsp) = X, 8(%rsp) = Y
#   Frame   : 40 bytes (%rbp %rbx %r12 + 16)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_plot_marker:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    subq $16, %rsp                  # %rsp = 0 (mod 16)
    movsd %xmm0, 0(%rsp)
    movsd %xmm1, 8(%rsp)
    leaq .Lrt_plot_mk_tab(%rip), %rax
    movq -8(%rax,%rdi,8), %rbx      # the template of code 1 .. 9
1:  movzbl (%rbx), %eax
    testl %eax, %eax
    jz 9f                           # the end
    cmpl $3, %eax
    jb 3f                           # a coordinate
    movq %rbx, %r12                 # a literal run up to the next code
2:  incq %r12
    cmpb $3, (%r12)
    jae 2b
    movq %rbx, %rdi
    movq %r12, %rsi
    subq %rbx, %rsi
    call .Lrt_plot_put
    movq %r12, %rbx
    jmp 1b
3:  leaq -8(%rsp,%rax,8), %rcx      # X (code 1) or Y (code 2)
    movsd (%rcx), %xmm0
    movsbl 1(%rbx), %eax            # the offset
    testl %eax, %eax
    jz 4f
    cvtsi2sdl %eax, %xmm1
    addsd %xmm1, %xmm0
4:  call .Lrt_plot_f2
    addq $2, %rbx
    jmp 1b
9:  addq $16, %rsp
    popq %r12
    popq %rbx
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_plot_legend -- the legend of the panel being written (2.14.6
#   "Legend", L-kn): when the pair's location is set and one of its line
#   or bar series has a label, a box of n entries in call order (lw =
#   7.2 x the longest label's bytes, bw = 40 + lw, bh = 16n + 8; bx, by
#   by the location), each with its sample and its label.
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = the base record, %r12 = the series record,
#             %r13 = series left, %r14 = the entry number r, %r15 = the
#             location, %rbp; locals 0 n, 8 the longest label, 16 bx,
#             24 by, 32 bw, 40 bh, 48 yc
#   Frame   : 104 bytes (ENTER 56)
# ---------------------------------------------------------------------
.equ RTP_L_N,           0
.equ RTP_L_MAX,         8
.equ RTP_L_BX,          16
.equ RTP_L_BY,          24
.equ RTP_L_BW,          32
.equ RTP_L_BH,          40
.equ RTP_L_YC,          48
    .p2align 4
.Lrt_plot_legend:
    ENTER 56
    movq .Lrt_plot_brec(%rip), %rbx
    movq RTP_AX_LEG(%rbx), %r15
    testq %r15, %r15
    jz 99f                          # no location: no legend
    movq $0, RTP_L_N(%rsp)          # n and the longest label
    movq $0, RTP_L_MAX(%rsp)
    movq .Lrt_plot_fig(%rip), %rax
    movq RTP_FG_SRT(%rax), %r12
    movq RTP_FG_NSR(%rax), %r13
1:  testq %r13, %r13
    jz 3f
    movq %r12, %rdi
    call .Lrt_plot_legent           # %eax = 1 for an entry
    testl %eax, %eax
    jz 2f
    incq RTP_L_N(%rsp)
    movq RTP_SR_LABEL(%r12), %rax
    movq SEA_STR_LEN(%rax), %rax
    cmpq RTP_L_MAX(%rsp), %rax
    jbe 2f
    movq %rax, RTP_L_MAX(%rsp)
2:  addq $RTP_SR_SIZE, %r12
    decq %r13
    jmp 1b
3:  cmpq $0, RTP_L_N(%rsp)
    je 99f                          # no labelled series: no legend
    # The box: bw = 40 + 7.2 * maxlen, bh = f64(16n + 8).
    cvtsi2sdq RTP_L_MAX(%rsp), %xmm0
    mulsd .Lrt_plot_c_72(%rip), %xmm0 # lw (= 7.2 * f64(maxlen) exactly)
    movl $40, %eax
    cvtsi2sdl %eax, %xmm1
    addsd %xmm1, %xmm0
    movsd %xmm0, RTP_L_BW(%rsp)
    movq RTP_L_N(%rsp), %rax
    shlq $4, %rax
    addq $8, %rax
    cvtsi2sdq %rax, %xmm0
    movsd %xmm0, RTP_L_BH(%rsp)
    movl $8, %eax                   # 8.0 in %xmm2
    cvtsi2sdl %eax, %xmm2
    # bx: east side ((px + pw) - 8) - bw, west px + 8, else px + (pw - bw) / 2.
    leaq .Lrt_plot_locside(%rip), %rax
    movzbl -1(%rax,%r15), %ecx      # bit 0 east, bit 1 west, bit 2 north, bit 3 south
    testl $1, %ecx
    jz 4f
    call .Lrt_plot_pxpw
    subsd %xmm2, %xmm0
    subsd RTP_L_BW(%rsp), %xmm0
    jmp 6f
4:  testl $2, %ecx
    jz 5f
    movsd .Lrt_plot_px(%rip), %xmm0
    addsd %xmm2, %xmm0
    jmp 6f
5:  movsd .Lrt_plot_pw(%rip), %xmm1
    subsd RTP_L_BW(%rsp), %xmm1
    divsd .Lrt_plot_c_two(%rip), %xmm1
    movsd .Lrt_plot_px(%rip), %xmm0
    addsd %xmm1, %xmm0
6:  movsd %xmm0, RTP_L_BX(%rsp)
    # by: north side py + 8, south ((py + ph) - 8) - bh, else py + (ph - bh) / 2.
    testl $4, %ecx
    jz 7f
    movsd .Lrt_plot_py(%rip), %xmm0
    addsd %xmm2, %xmm0
    jmp 10f
7:  testl $8, %ecx
    jz 8f
    call .Lrt_plot_pyph
    subsd %xmm2, %xmm0
    subsd RTP_L_BH(%rsp), %xmm0
    jmp 10f
8:  movsd .Lrt_plot_ph(%rip), %xmm1
    subsd RTP_L_BH(%rsp), %xmm1
    divsd .Lrt_plot_c_two(%rip), %xmm1
    movsd .Lrt_plot_py(%rip), %xmm0
    addsd %xmm1, %xmm0
10: movsd %xmm0, RTP_L_BY(%rsp)
    LIT "<g class=\"legend\">\n<rect class=\"legend-box\" x=\""
    F2 RTP_L_BX(%rsp)
    LIT "\" y=\""
    F2 RTP_L_BY(%rsp)
    LIT "\" width=\""
    F2 RTP_L_BW(%rsp)
    LIT "\" height=\""
    F2 RTP_L_BH(%rsp)
    LIT "\" fill=\"#ffffff\" stroke=\"#262626\" stroke-width=\"0.50\"/>\n"
    # The entries, yc = (by + 12) + f64(16 r).
    movq .Lrt_plot_fig(%rip), %rax
    movq RTP_FG_SRT(%rax), %r12
    movq RTP_FG_NSR(%rax), %r13
    xorl %r14d, %r14d
11: testq %r13, %r13
    jz 30f
    movq %r12, %rdi
    call .Lrt_plot_legent
    testl %eax, %eax
    jz 29f
    movsd RTP_L_BY(%rsp), %xmm0
    movl $12, %eax
    cvtsi2sdl %eax, %xmm1
    addsd %xmm1, %xmm0
    movq %r14, %rax
    shlq $4, %rax
    cvtsi2sdq %rax, %xmm1
    addsd %xmm1, %xmm0
    movsd %xmm0, RTP_L_YC(%rsp)
    cmpq $RTP_SK_LINE, RTP_SR_KIND(%r12)
    jne 20f
    # A line series: its line sample, then its marker sample.
    cmpq $0, RTP_SR_LINE(%r12)
    je 12f
    LIT "<path class=\"legend-line\" d=\"M"
    movl $6, %edi
    call .Lrt_plot_bxp
    LIT " "
    F2 RTP_L_YC(%rsp)
    LIT " H"
    movl $26, %edi
    call .Lrt_plot_bxp
    LIT "\" fill=\"none\" stroke=\""
    movq RTP_SR_COLOR(%r12), %rdi
    call .Lrt_plot_color
    LIT "\" stroke-width=\""
    F2 RTP_SR_WIDTH(%r12)
    LIT "\""
    movq RTP_SR_LINE(%r12), %rdi
    call .Lrt_plot_dash
    LIT "/>\n"
12: cmpq $0, RTP_SR_MARK(%r12)
    je 25f
    LIT "<path class=\"legend-marker\" d=\""
    movsd RTP_L_BX(%rsp), %xmm0     # at (bx + 16, yc)
    movl $16, %eax
    cvtsi2sdl %eax, %xmm1
    addsd %xmm1, %xmm0
    movsd RTP_L_YC(%rsp), %xmm1
    movq RTP_SR_MARK(%r12), %rdi
    call .Lrt_plot_marker
    movq %r12, %rdi
    call .Lrt_plot_mtail
    jmp 25f
    # A bar series: its swatch.
20: LIT "<rect class=\"legend-bar\" x=\""
    movl $10, %edi
    call .Lrt_plot_bxp
    LIT "\" y=\""
    movsd RTP_L_YC(%rsp), %xmm0     # yc - 4
    movl $4, %eax
    cvtsi2sdl %eax, %xmm1
    subsd %xmm1, %xmm0
    call .Lrt_plot_f2
    LIT "\" width=\"12.00\" height=\"8.00\" fill=\""
    movq RTP_SR_COLOR(%r12), %rdi
    call .Lrt_plot_color
    LIT "\"/>\n"
    # The label.
25: LIT "<text class=\"legend-label\" x=\""
    movl $32, %edi
    call .Lrt_plot_bxp
    LIT "\" y=\""
    movsd RTP_L_YC(%rsp), %xmm0     # yc + 4
    movl $4, %eax
    cvtsi2sdl %eax, %xmm1
    addsd %xmm1, %xmm0
    call .Lrt_plot_f2
    LIT "\" font-size=\"12\">"
    movq RTP_SR_LABEL(%r12), %rdi
    call .Lrt_plot_esc
    LIT "</text>\n"
    incq %r14
29: addq $RTP_SR_SIZE, %r12
    decq %r13
    jmp 11b
30: LIT "</g>\n"
99: LEAVE 56

# .Lrt_plot_bxp -- append %.2f of bx + c (bx in the legend's locals, 8
#   bytes above this routine's return address).
#   Inputs: %edi = c.  Clobbers all caller-saved registers (tail jump).
    .p2align 4
.Lrt_plot_bxp:
    cvtsi2sdl %edi, %xmm1
    movsd 8 + RTP_L_BX(%rsp), %xmm0
    addsd %xmm1, %xmm0
    jmp .Lrt_plot_f2

# .Lrt_plot_legent -- whether a series is a legend entry of the panel
#   being written: a line, bar or barh series of the pair with a label.
#   Inputs: %rdi = the series record.  Outputs: %eax = 1 or 0.
#   Clobbers: %rcx, flags.  Frame: none (leaf)
    .p2align 4
.Lrt_plot_legent:
    xorl %eax, %eax
    cmpq $0, RTP_SR_LABEL(%rdi)
    je 9f                           # no label
    movq RTP_SR_AX(%rdi), %rcx
    cmpq .Lrt_plot_bidx(%rip), %rcx
    je 1f
    cmpq .Lrt_plot_tidx(%rip), %rcx
    jne 9f                          # another panel's
1:  movq RTP_SR_KIND(%rdi), %rcx
    cmpq $RTP_SK_LINE, %rcx
    je 2f
    cmpq $RTP_SK_BAR, %rcx
    je 2f
    cmpq $RTP_SK_BARH, %rcx
    jne 9f
2:  movl $1, %eax
9:  ret

# =====================================================================
# Constant data
# =====================================================================
    .section .rodata
    .p2align 3
.Lrt_plot_c_one:    .quad RTP_B_ONE
.Lrt_plot_c_two:    .quad 0x4000000000000000 # 2.0
.Lrt_plot_c_five:   .quad 0x4014000000000000 # 5.0
.Lrt_plot_c_seven:  .quad 0x401C000000000000 # 7.0
.Lrt_plot_c_ten:    .quad 0x4024000000000000 # 10.0
.Lrt_plot_c_half:   .quad 0x3FE0000000000000 # 0.5
.Lrt_plot_c_mhalf:  .quad 0xBFE0000000000000 # -0.5
.Lrt_plot_c_35:     .quad 0x400C000000000000 # 3.5
.Lrt_plot_c_72:     .quad 0x401CCCCCCCCCCCCD # 7.2 (the double nearest)
.Lrt_plot_c_1e6:    .quad 0x412E848000000000 # 1e6
.Lrt_plot_c_1em4:   .quad 0x3F1A36E2EB1C432D # 1e-4 (the double nearest)
.Lrt_plot_c_mult:   .quad RTP_B_ONE, 0x4000000000000000, 0x4014000000000000 # 1, 2, 5
    .p2align 4
.Lrt_plot_c_sign:   .quad RTP_B_SIGN, 0
.Lrt_plot_c_abs:    .quad 0x7FFFFFFFFFFFFFFF, 0
.Lrt_plot_hex:      .ascii "0123456789abcdef"
.Lrt_plot_markers:  .ascii "osd^vx+*."          # marker codes 1 .. 9
.Lrt_plot_letters:  .ascii "rgbcmykw"           # colour letters
    .p2align 3
.Lrt_plot_lettercol:                            # their colours (LANGUAGE.md 12.3)
    .quad 0xFF0000, 0x00A000, 0x0000FF, 0x00BFBF, 0xBF00BF, 0xBFBF00, 0x000000, 0xFFFFFF
.Lrt_plot_cycle:                                # the colour cycle (LANGUAGE.md 12.3)
    .quad 0x0072BD, 0xD95319, 0xEDB120, 0x7E2F8E, 0x77AC30, 0x4DBEEE, 0xA2142F
# Legend locations: length, name, code (L-kn: best is northeast); 0 ends.
.Lrt_plot_locs:
    .byte 5
    .ascii "north"
    .byte 1, 5
    .ascii "south"
    .byte 2, 4
    .ascii "east"
    .byte 3, 4
    .ascii "west"
    .byte 4, 9
    .ascii "northeast"
    .byte 5, 9
    .ascii "northwest"
    .byte 6, 9
    .ascii "southeast"
    .byte 7, 9
    .ascii "southwest"
    .byte 8, 4
    .ascii "best"
    .byte 5, 0
# The sides of locations 1 .. 8: bit 0 east, 1 west, 2 north, 3 south.
.Lrt_plot_locside:
    .byte 4, 8, 1, 2, 5, 6, 9, 10
# Marker templates (2.14.6 "Series forms"): 1, off = X + off; 2, off =
# Y + off; 0 ends.
.Lrt_plot_mk_o:
    .ascii "M"
    .byte 1, -3
    .ascii " "
    .byte 2, 0
    .ascii " a3.00 3.00 0 1 0 6.00 0.00 a3.00 3.00 0 1 0 -6.00 0.00"
    .byte 0
.Lrt_plot_mk_s:
    .ascii "M"
    .byte 1, -3
    .ascii " "
    .byte 2, -3
    .ascii " h6.00 v6.00 h-6.00 z"
    .byte 0
.Lrt_plot_mk_d:
    .ascii "M"
    .byte 1, 0
    .ascii " "
    .byte 2, -3
    .ascii " l3.00 3.00 l-3.00 3.00 l-3.00 -3.00 z"
    .byte 0
.Lrt_plot_mk_up:
    .ascii "M"
    .byte 1, 0
    .ascii " "
    .byte 2, -3
    .ascii " l3.00 6.00 h-6.00 z"
    .byte 0
.Lrt_plot_mk_dn:
    .ascii "M"
    .byte 1, 0
    .ascii " "
    .byte 2, 3
    .ascii " l3.00 -6.00 h-6.00 z"
    .byte 0
.Lrt_plot_mk_x:
    .ascii "M"
    .byte 1, -3
    .ascii " "
    .byte 2, -3
    .ascii " l6.00 6.00 M"
    .byte 1, -3
    .ascii " "
    .byte 2, 3
    .ascii " l6.00 -6.00"
    .byte 0
.Lrt_plot_mk_plus:
    .ascii "M"
    .byte 1, -3
    .ascii " "
    .byte 2, 0
    .ascii " h6.00 M"
    .byte 1, 0
    .ascii " "
    .byte 2, -3
    .ascii " v6.00"
    .byte 0
.Lrt_plot_mk_star:                              # the + form, a space, the x form
    .ascii "M"
    .byte 1, -3
    .ascii " "
    .byte 2, 0
    .ascii " h6.00 M"
    .byte 1, 0
    .ascii " "
    .byte 2, -3
    .ascii " v6.00 M"
    .byte 1, -3
    .ascii " "
    .byte 2, -3
    .ascii " l6.00 6.00 M"
    .byte 1, -3
    .ascii " "
    .byte 2, 3
    .ascii " l6.00 -6.00"
    .byte 0
.Lrt_plot_mk_dot:
    .ascii "M"
    .byte 1, -1
    .ascii " "
    .byte 2, 0
    .ascii " a1.00 1.00 0 1 0 2.00 0.00 a1.00 1.00 0 1 0 -2.00 0.00"
    .byte 0

    .section .data.rel.ro,"aw",@progbits
    .p2align 3
.Lrt_plot_mk_tab:                               # by marker code 1 .. 9
    .quad .Lrt_plot_mk_o, .Lrt_plot_mk_s, .Lrt_plot_mk_d, .Lrt_plot_mk_up
    .quad .Lrt_plot_mk_dn, .Lrt_plot_mk_x, .Lrt_plot_mk_plus, .Lrt_plot_mk_star
    .quad .Lrt_plot_mk_dot

# =====================================================================
# The writer's state (see the file header)
# =====================================================================
    .bss
    .p2align 3
SHARED sea_plt_site
.Lrt_plot_site:  .zero 8            # the running entry's site
SHARED sea_plt_bufp
.Lrt_plot_bufp:  .zero 8            # the SVG buffer, its length, its capacity
SHARED sea_plt_bufn
.Lrt_plot_bufn:  .zero 8
.Lrt_plot_bufc:  .zero 8
.Lrt_plot_fig:   .zero 8            # the figure being written
.Lrt_plot_brec:  .zero 8            # the panel's base record, twin record (or 0)
SHARED sea_plt_trec
.Lrt_plot_trec:  .zero 8
.Lrt_plot_bidx:  .zero 8            # their indices (the twin's -1 if none)
.Lrt_plot_tidx:  .zero 8
.Lrt_plot_tight: .zero 8            # 1 when the pair holds an image
SHARED sea_plt_cbar
.Lrt_plot_cbar:  .zero 8            # the pair's last image record with colorbar: true, or 0
.Lrt_plot_hb:    .zero 8            # f64 the heading band, the cell size
.Lrt_plot_cw:    .zero 8
.Lrt_plot_ch:    .zero 8
SHARED sea_plt_px
.Lrt_plot_px:    .zero 8            # f64 the panel's plot area
SHARED sea_plt_py
.Lrt_plot_py:    .zero 8
SHARED sea_plt_pw
.Lrt_plot_pw:    .zero 8
SHARED sea_plt_ph
.Lrt_plot_ph:    .zero 8
SHARED sea_plt_axd
.Lrt_plot_axd:   .zero 4 * RTP_A_SIZE # the axis descriptors x, y, the twin's y, the colorbar's (rt_plot2.s)

    .section .note.GNU-stack,"",@progbits
