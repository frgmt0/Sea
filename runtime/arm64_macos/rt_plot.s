// =====================================================================
// sea/runtime/arm64_macos/rt_plot.s -- the plotting library's core: the
// Figure and Axes objects, the entries of sub-phase 9b and the SVG
// writer (LANGUAGE.md 12; DESIGN.md 2.14.2, 2.14.5, 2.14.6; lead
// decisions L-ke .. L-lf).
//
// Defines (global, rt.inc SEA_ENTRY_LIST):
//   _sea_figure     (nrows, ncols, name, width, height, site) -> Figure
//   _sea_panel      (fig, row, col, rowspan, colspan, site) -> Axes
//   _sea_twin_y     (ax, site) -> Axes
//   _sea_save_svg   (fig, path, site)
//   _sea_plot       (ax, x, y, style, label, d0 = width, color, site)
//   _sea_xline      (ax, d0 = x, style, color, site)
//   _sea_xlabel, _sea_ylabel, _sea_title (ax, s)
//   _sea_legend     (ax, loc, site)
//   _sea_grid       (ax, on)
//   _sea_xlim, _sea_ylim (ax, d0 = lo, d1 = hi, site)
//   _sea_x_ticks, _sea_y_ticks (ax, labels, site)
//   _sea_y_reverse, _sea_axis_equal (ax)
// BAR, BARH, CONTOUR and IMAGE (series kinds 3 .. 6) are sub-phase 9c's
// (rt_plot2.s, L-lf); until then no series of those kinds exists, so the
// writer draws kinds 1 (line) and 2 (xline) only.
// Uses: _sea_alloc, _sea_free_block, _sea_retain, _sea_release,
//       _sea_live (rt_mem.s), _sea_err (rt_err.s), _sea_fmt_num
//       (rt_fmt.s), _sea_file_put (rt_file.s), memcpy, memset, memcmp
//       (libSystem).
//
// OBJECTS (DESIGN.md 2.14.6 "Objects"; the RTP_* offsets below, the same
// in both runtimes, read by tests/rt and by rt_mem.s's sea_free). A
// Figure is one 704-byte block holding the whole state (L-ke): the
// grid, the size, the retained name, the axes table (256-byte records),
// the series table (128-byte records), both of capacity 8 at first and
// doubled when full, and the occupancy map (one u64 per grid row). An
// Axes is a 32-byte block: a counted reference to its figure and an axes
// record index. Figure and Axes objects are counted in _sea_live by the
// constructors here (L-lb); every other block is an uncounted
// _sea_alloc block, freed with _sea_free_block by its exact size.
//
// ENTRIES (DESIGN.md 2.14.5): every argument is borrowed (a string is
// retained only where it is stored, an array only read and copied, L-kf);
// a result has count 1; each entry checks its arguments in parameter
// order (L-kg, 2.14.2's check order) and reports the first failure with
// _sea_err(code, site, slots), never returning.
//
// SAVE_SVG (DESIGN.md 2.14.6). The document is built in one growing
// uncounted block (65 536 bytes, doubled by copy), then written by
// _sea_file_put, which frees the block (L-lc). For each base axes in
// creation order: the layout, the extents, the limits and ticks (rules
// 1 .. 6), the tick label formats (Decision 142), then the elements of
// the grammar in order. Every number is a C conversion through
// _sea_fmt_num (`%.2f`, `%.{p}f`, `%g`, `%.{q}g`) or an integer written
// here (`%d`); every operation is one IEEE operation in the order of
// 2.14.6 (no FMA); every coordinate is clamped (L-kl) before it is used.
//
// THE WRITER'S STATE: one static block Lrtp_st (RS_*), the buffer
// descriptor, the panel being written, its three axes (RS_AX the pair's
// x-axis, RS_AY the base's y-axis, RS_AT the twin's) and three text
// buffers. The private writer routines below expect x28 = Lrtp_st (set
// by _sea_save_svg) and, like every routine here, preserve x19-x28.
// Programs are single-threaded and SAVE_SVG does not nest.
//
// ABI: AAPCS64; every entry preserves x19-x28, x29, sp, d8-d15 and FPCR
// (never written). Every own frame is at most 160 bytes (2.14.5: at most
// 512); no routine recurses.
// =====================================================================
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

// ---- the private layouts (DESIGN.md 2.14.6 "Objects"; L-kw) -----------
.equ RTP_F_NROWS,   16              /* u64  grid rows */
.equ RTP_F_NCOLS,   24              /* u64  grid columns */
.equ RTP_F_W,       32              /* u64  width in px */
.equ RTP_F_H,       40              /* u64  height in px */
.equ RTP_F_NAME,    48              /* ptr  the name (a retained str) */
.equ RTP_F_NAX,     56              /* u64  axes records */
.equ RTP_F_AXCAP,   64              /* u64  their capacity */
.equ RTP_F_AXT,     72              /* ptr  the axes table */
.equ RTP_F_NSR,     80              /* u64  series records */
.equ RTP_F_SRCAP,   88              /* u64  their capacity */
.equ RTP_F_SRT,     96              /* ptr  the series table */
.equ RTP_F_OCC,     192             /* u64[SEA_LIM_PLOT_GRID] the occupancy map */
.equ RTP_F_SIZE,    704             /* the Figure block */
.equ RTP_A_FIG,     16              /* ptr  an Axes' figure (counted) */
.equ RTP_A_IDX,     24              /* u64  its axes record index */
.equ RTP_A_SIZE,    32              /* the Axes block */
.equ RTP_TAB0,      8               /* first capacity of both tables */
.equ RTP_AX_SIZE,   256             /* an axes record (zero-filled when made) */
.equ RTP_AX_KIND,   0               /* 0 base, 1 twin */
.equ RTP_AX_BASE,   8               /* the base's index (its own for a base) */
.equ RTP_AX_TWIN,   16              /* the twin's index, -1 if none (a twin's -1) */
.equ RTP_AX_ROW,    24
.equ RTP_AX_COL,    32
.equ RTP_AX_RSPAN,  40
.equ RTP_AX_CSPAN,  48
.equ RTP_AX_TITLE,  56              /* str or 0 */
.equ RTP_AX_XLAB,   64              /* str or 0 */
.equ RTP_AX_YLAB,   72              /* str or 0 */
.equ RTP_AX_FLAGS,  80              /* RTP_FL_* */
.equ RTP_AX_LEG,    88              /* 0 none, 1 .. 8 north .. southwest */
.equ RTP_AX_XLO,    96              /* f64 */
.equ RTP_AX_XHI,    104
.equ RTP_AX_YLO,    112
.equ RTP_AX_YHI,    120
.equ RTP_AX_XCAT,   128             /* ptr  x category labels (each retained), count at 136 */
.equ RTP_AX_NXCAT,  136
.equ RTP_AX_YCAT,   144             /* ptr  y category labels, count at 152 */
.equ RTP_AX_NYCAT,  152
.equ RTP_AX_CYC,    160             /* the colour cycle index */
.equ RTP_FL_GRID,   0               /* bit numbers of RTP_AX_FLAGS */
.equ RTP_FL_YREV,   1
.equ RTP_FL_EQUAL,  2
.equ RTP_FL_XLIM,   3
.equ RTP_FL_YLIM,   4
.equ RTP_SR_SIZE,   128             /* a series record */
.equ RTP_SR_KIND,   0               /* 1 line, 2 xline, 3 bar, 4 barh, 5 contour, 6 image */
.equ RTP_SR_AX,     8               /* the axes record's index */
.equ RTP_SR_COLOR,  16              /* 0xRRGGBB, or -1: the colour map per level */
.equ RTP_SR_LINE,   24              /* 0 none, 1 solid, 2 --, 3 :, 4 -. */
.equ RTP_SR_MARK,   32              /* 0 none, 1 .. 9 o s d ^ v x + * . */
.equ RTP_SR_WIDTH,  40              /* f64 */
.equ RTP_SR_LABEL,  48              /* str, or 0 for "" */
.equ RTP_SR_N,      56
.equ RTP_SR_M,      64
.equ RTP_SR_DATA,   72              /* the data block, or 0 */
.equ RTP_SR_LEVELS, 80
.equ RTP_SR_FLAG,   88
.equ RTP_SR_XPOS,   96              /* f64: an xline's position */
.equ RTP_K_LINE,    1               /* series kinds */
.equ RTP_K_XLINE,   2
.equ RTP_K_BAR,     3
.equ RTP_K_IMAGE,   6
.equ RTP_MK_DOT,    9               /* the marker `.`, filled */
.if (RTP_F_OCC + 8 * SEA_LIM_PLOT_GRID) != RTP_F_SIZE
    .error "rt_plot: the occupancy map ends the Figure block"
.endif
.if RTP_F_NROWS != SEA_OBJ_HDR
    .error "rt_plot: the Figure fields follow SEA_OBJ_HDR"
.endif

// ---- the writer's state (Lrtp_st) ---------------------------------------
// One axis (AS_*): limits, ticks and their format.
.equ AS_LO,         0               /* f64  the limits */
.equ AS_HI,         8
.equ AS_MODE,       16              /* 0 no ticks, 1 numeric, 2 category */
.equ AS_NT,         24              /* ticks (numeric: in AS_TV; category: 0 .. n-1) */
.equ AS_K,          32              /* the step's k */
.equ AS_S,          40              /* f64 the step */
.equ AS_LET,        48              /* the label conversion letter: 'f' or 'g' */
.equ AS_PREC,       56              /* its precision (-1: C's 6) */
.equ AS_REV,        64              /* 1: a reversed y-axis */
.equ AS_CAT,        72              /* the category labels (str pointers) */
.equ AS_NCAT,       80
.equ AS_EXT,        88              /* 1 when the extent holds a value */
.equ AS_ELO,        96              /* f64 the extent */
.equ AS_EHI,        104
.equ AS_TV,         112             /* f64[8] the numeric ticks */
.equ AS_SIZE,       176
.equ RTP_TMAX,      8               /* at most 8 numeric ticks (2.14.6 rule 5) */
.equ RS_BPTR,       0               /* the SVG buffer block */
.equ RS_BLEN,       8               /* bytes in it */
.equ RS_BCAP,       16              /* its size */
.equ RS_SITE,       24              /* SAVE_SVG's site */
.equ RS_FIG,        32              /* the figure */
.equ RS_BASE,       40              /* the base axes record */
.equ RS_TWIN,       48              /* the twin's record, or 0 */
.equ RS_BIDX,       56              /* the base's index */
.equ RS_TIDX,       64              /* the twin's index, -1 if none */
.equ RS_PX,         72              /* f64 the plot area */
.equ RS_PY,         80
.equ RS_PW,         88
.equ RS_PH,         96
.equ RS_FIRST,      104             /* 1 before the first item of a path */
.equ RS_TIGHT,      112             /* 1 when the pair holds an image (rule 3) */
.equ RS_AX,         128             /* the pair's x-axis */
.equ RS_AY,         (RS_AX + AS_SIZE)   /* the base's y-axis */
.equ RS_AT,         (RS_AY + AS_SIZE)   /* the twin's y-axis */
.equ RS_NUM,        (RS_AT + AS_SIZE)   /* number text for the buffer */
.equ RTP_NUMBUF,    336             /* rt_fmt.s's RTF_NUMBUF */
.equ RS_T0,         (RS_NUM + RTP_NUMBUF)   /* tick texts */
.equ RS_T1,         (RS_T0 + RTP_NUMBUF)
.equ RS_SIZE,       (RS_T1 + RTP_NUMBUF)
.equ RTP_BUF0,      65536           /* first size of the SVG buffer */

// ---- helpers ------------------------------------------------------------
// The address of a label.
.macro LADR reg, label
    adrp \reg, \label@PAGE
    add \reg, \reg, \label@PAGEOFF
.endm
// Load a constant (at most 32 bits) into a register.
.macro LI32 reg, val
    movz \reg, #((\val) & 0xffff)
    movk \reg, #(((\val) >> 16) & 0xffff), lsl #16
.endm
// Load an f64 constant of the table Lrtp_k (clobbers x16).
.macro LDK dreg, name
    adrp x16, Lrtp_k@PAGE
    add x16, x16, Lrtp_k@PAGEOFF
    ldr \dreg, [x16, #K_\name]
.endm
// Append a NUL-terminated literal to the SVG buffer.
.macro PUTC label
    LADR x0, \label
    bl Lrtp_bcstr
.endm
// Append one byte.
.macro PUTB ch
    mov w0, #\ch
    bl Lrtp_bbyte
.endm
// Append an f64 register as `%.2f`.
.macro F2 dreg
    fmov d0, \dreg
    bl Lrtp_f2
.endm
// Branch to label when the f64 in dreg is NaN or infinite (tmp scratch).
.macro BNF dreg, tmp, label
    fsub \tmp, \dreg, \dreg
    fcmp \tmp, \tmp
    b.vs \label
.endm
// An Axes handle's figure and records: x0 = the Axes in; out x0 = its
// figure, x1 = its own axes record, x2 = the pair's base record, x3 =
// its own index (clobbers x9, x10).
.macro AXES
    ldr x3, [x0, #RTP_A_IDX]
    ldr x0, [x0, #RTP_A_FIG]
    ldr x9, [x0, #RTP_F_AXT]
    add x1, x9, x3, lsl #8          /* its own record (256 bytes each) */
    ldr x10, [x1, #RTP_AX_BASE]
    add x2, x9, x10, lsl #8         /* the base's record */
.endm
// _sea_live + 1 (a Figure or Axes is complete; clobbers x9, x10).
.macro LIVE_INC
    adrp x9, _sea_live@PAGE
    ldr x10, [x9, _sea_live@PAGEOFF]
    add x10, x10, #1
    str x10, [x9, _sea_live@PAGEOFF]
.endm

// ---- the f64 constants (index * 8) ---------------------------------------
.macro KDEF name, idx, val
.equ K_\name, ((\idx) * 8)
    .double \val
.endm
    .section __TEXT,__const
    .p2align 3
Lrtp_k:
    KDEF ONE, 0, 1.0
    KDEF TEN, 1, 10.0
    KDEF TWO, 2, 2.0
    KDEF FIVE, 3, 5.0
    KDEF SEVEN, 4, 7.0
    KDEF HALF, 5, 0.5
    KDEF P, 6, 100000.0         /* SEA_LIM_PLOT_PX, the clamp */
    KDEF P2, 7, 200000.0        /* 2 * SEA_LIM_PLOT_PX */
    KDEF E6, 8, 1e6
    KDEF EM4, 9, 1e-4
    KDEF M56, 10, 56.0          /* left margin */
    KDEF M28, 11, 28.0          /* top margin */
    KDEF M44, 12, 44.0          /* bottom margin */
    KDEF M16, 13, 16.0          /* right margin; legend row */
    KDEF M68, 14, 68.0          /* right margin with a twin */
    KDEF M24, 15, 24.0          /* heading band */
    KDEF THREE, 16, 3.0
    KDEF T35, 17, 3.5
    KDEF SIX, 18, 6.0
    KDEF F14, 19, 14.0
    KDEF F34, 20, 34.0
    KDEF F42, 21, 42.0
    KDEF F48, 22, 48.0
    KDEF EIGHT, 23, 8.0
    KDEF F12, 24, 12.0
    KDEF F26, 25, 26.0
    KDEF F32, 26, 32.0
    KDEF F72, 27, 7.2           /* 0.6 x 12 px per byte */
    KDEF F40, 28, 40.0
    KDEF FOUR, 29, 4.0
    KDEF F10, 30, 10.0
.if SEA_LIM_PLOT_PX != 100000
    .error "rt_plot: K_P and K_P2 are SEA_LIM_PLOT_PX and twice it"
.endif
.if SEA_LIM_PLOT_GRID > 64
    .error "rt_plot: the occupancy map holds one u64 per grid row"
.endif

    .section __TEXT,__text,regular,pure_instructions

// =====================================================================
// The byte buffer (x28 = Lrtp_st)
// =====================================================================

// ---------------------------------------------------------------------
// Lrtp_bput -- append bytes to the SVG buffer, doubling it by copy when
//   full (2.14.6 "The byte buffer"; a failed allocation is _sea_alloc's
//   OUT_OF_MEMORY at SAVE_SVG's site).
//   Inputs  : x0 = bytes, x1 = count; x28 = Lrtp_st
//   Outputs : none
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = bytes, x20 = count, x21 = new block,
//             x22 = new size
//   Frame   : 48 bytes (frame record + x19..x22)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_bput:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    mov x20, x1
    ldr x9, [x28, #RS_BLEN]
    ldr x10, [x28, #RS_BCAP]
    add x11, x9, x20                // the length needed
    cmp x11, x10
    b.ls 2f                         // it fits
    mov x22, x10
1:  lsl x22, x22, #1                // double until it fits
    cmp x22, x11
    b.lo 1b
    mov x0, x22
    ldr x1, [x28, #RS_SITE]
    bl _sea_alloc                   // noreturn on failure
    mov x21, x0
    ldr x1, [x28, #RS_BPTR]         // copy what is there
    ldr x2, [x28, #RS_BLEN]
    bl _memcpy
    ldr x0, [x28, #RS_BPTR]         // free the old block
    ldr x1, [x28, #RS_BCAP]
    bl _sea_free_block
    str x21, [x28, #RS_BPTR]
    str x22, [x28, #RS_BCAP]
2:  ldr x0, [x28, #RS_BPTR]         // append at the end
    ldr x9, [x28, #RS_BLEN]
    add x0, x0, x9
    mov x1, x19
    mov x2, x20
    bl _memcpy
    ldr x9, [x28, #RS_BLEN]
    add x9, x9, x20
    str x9, [x28, #RS_BLEN]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// ---------------------------------------------------------------------
// Lrtp_bcstr -- append a NUL-terminated literal (without its NUL).
//   Inputs  : x0 = the text; x28 = Lrtp_st
//   Clobbers: as Lrtp_bput
//   Frame   : none (tail call of Lrtp_bput)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_bcstr:
    mov x1, #0
1:  ldrb w9, [x0, x1]               // its length
    cbz w9, 2f
    add x1, x1, #1
    b 1b
2:  b Lrtp_bput

// ---------------------------------------------------------------------
// Lrtp_bbyte -- append one byte.
//   Inputs  : w0 = the byte; x28 = Lrtp_st
//   Clobbers: as Lrtp_bput
//   Frame   : 32 bytes (frame record, the byte at sp+16)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_bbyte:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    strb w0, [sp, #16]
    add x0, sp, #16
    mov x1, #1
    bl Lrtp_bput
    ldp x29, x30, [sp], #32
    ret

// ---------------------------------------------------------------------
// Lrtp_f2 -- append an f64 as `%.2f` (2.14.6 `{X}`).
//   Inputs  : d0 = the value (finite); x28 = Lrtp_st
//   Clobbers: as Lrtp_bput
//   Frame   : 16 bytes (frame record)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_f2:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    add x0, x28, #RS_NUM
    mov w1, #'f'
    mov x2, #2
    bl _sea_fmt_num                 // x0 = length
    mov x1, x0
    add x0, x28, #RS_NUM
    ldp x29, x30, [sp], #16
    b Lrtp_bput

// ---------------------------------------------------------------------
// Lrtp_bint -- append a signed integer as `%d` (2.14.6 `{W}`, ids).
//   Inputs  : x0 = the value; x28 = Lrtp_st
//   Clobbers: as Lrtp_bput
//   Frame   : 48 bytes (frame record, 32 bytes of digits)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_bint:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    add x9, sp, #48                 // digits right to left from the end
    cmp x0, #0
    cset w11, lt                    // negative?
    cneg x10, x0, lt                // the magnitude
    mov x12, #10
1:  udiv x13, x10, x12
    msub x14, x13, x12, x10         // the next digit
    add w14, w14, #'0'
    strb w14, [x9, #-1]!
    mov x10, x13
    cbnz x10, 1b
    cbz w11, 2f
    mov w14, #'-'
    strb w14, [x9, #-1]!
2:  mov x0, x9
    add x1, sp, #48
    sub x1, x1, x9                  // the number of bytes
    bl Lrtp_bput
    ldp x29, x30, [sp], #48
    ret

// ---------------------------------------------------------------------
// Lrtp_bcolor -- append a colour `#rrggbb` in lower case (2.14.6 `{c}`).
//   Inputs  : x0 = 0xRRGGBB; x28 = Lrtp_st
//   Clobbers: as Lrtp_bput
//   Frame   : 32 bytes (frame record, 7 bytes of text at sp+16)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_bcolor:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    mov w9, #'#'
    strb w9, [sp, #16]
    LADR x12, Lrtp_s_hex
    mov x10, #6                     // six digits, the lowest last
1:  and x11, x0, #0xf
    ldrb w11, [x12, x11]
    add x13, sp, #16
    strb w11, [x13, x10]
    lsr x0, x0, #4
    subs x10, x10, #1
    b.ne 1b
    add x0, sp, #16
    mov x1, #7
    bl Lrtp_bput
    ldp x29, x30, [sp], #32
    ret

// ---------------------------------------------------------------------
// Lrtp_btext -- append text escaped (2.14.6 `{t}`, L-kp): `&` `<` `>` `"`
//   as `&amp;` `&lt;` `&gt;` `&quot;`, every byte 0x00-0x1F other than
//   0x09, 0x0A, 0x0D as a space, every other byte copied.
//   Inputs  : x0 = bytes, x1 = count; x28 = Lrtp_st
//   Clobbers: as Lrtp_bput
//   Callee-saved used: x19 = bytes, x20 = count, x21 = index, x22 = start
//             of the pending plain run
//   Frame   : 48 bytes (frame record + x19..x22)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_btext:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    mov x20, x1
    mov x21, #0
    mov x22, #0
Lrtp_btext_loop:
    cmp x21, x20
    b.hs Lrtp_btext_end
    ldrb w9, [x19, x21]
    LADR x0, Lrtp_s_amp
    cmp w9, #'&'
    b.eq Lrtp_btext_esc
    LADR x0, Lrtp_s_lt
    cmp w9, #'<'
    b.eq Lrtp_btext_esc
    LADR x0, Lrtp_s_gt
    cmp w9, #'>'
    b.eq Lrtp_btext_esc
    LADR x0, Lrtp_s_quot
    cmp w9, #'"'
    b.eq Lrtp_btext_esc
    cmp w9, #0x20
    b.hs 1f                         // a plain byte
    cmp w9, #0x09
    b.eq 1f
    cmp w9, #0x0A
    b.eq 1f
    cmp w9, #0x0D
    b.eq 1f
    LADR x0, Lrtp_s_sp              // a control byte: a space
    b Lrtp_btext_esc
1:  add x21, x21, #1
    b Lrtp_btext_loop
Lrtp_btext_esc:
    // The plain run before it, then the replacement (x0).
    str x0, [sp, #-16]!
    add x0, x19, x22
    sub x1, x21, x22
    cbz x1, 2f
    bl Lrtp_bput
2:  ldr x0, [sp], #16
    bl Lrtp_bcstr
    add x21, x21, #1
    mov x22, x21                    // the next run starts after it
    b Lrtp_btext_loop
Lrtp_btext_end:
    add x0, x19, x22                // the last plain run
    sub x1, x20, x22
    cbz x1, 3f
    bl Lrtp_bput
3:  ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// ---------------------------------------------------------------------
// Lrtp_bstr -- append a string object escaped (nothing for 0).
//   Inputs  : x0 = string object or 0; x28 = Lrtp_st
//   Clobbers: as Lrtp_bput
//   Frame   : none (tail call)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_bstr:
    cbz x0, 1f
    ldr x1, [x0, #SEA_STR_LEN]
    add x0, x0, #SEA_STR_BYTES
    b Lrtp_btext
1:  ret

// ---------------------------------------------------------------------
// Lrtp_xywh -- append prefix, x, `" y="`, y, `" width="`, w,
//   `" height="`, h, suffix (each number `%.2f`): the rectangles of the
//   grammar.
//   Inputs  : x0 = prefix, x1 = suffix (literals), d0-d3 = x, y, w, h;
//             x28 = Lrtp_st
//   Clobbers: as Lrtp_bput
//   Callee-saved used: x19 = suffix, d8-d11 = x, y, w, h
//   Frame   : 64 bytes (frame record, x19, pad, d8..d11)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_xywh:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    str x19, [sp, #16]
    stp d8, d9, [sp, #32]
    stp d10, d11, [sp, #48]
    mov x19, x1
    fmov d8, d0
    fmov d9, d1
    fmov d10, d2
    fmov d11, d3
    bl Lrtp_bcstr                   // the prefix
    F2 d8
    PUTC Lrtp_s_qy
    F2 d9
    PUTC Lrtp_s_qw
    F2 d10
    PUTC Lrtp_s_qh
    F2 d11
    mov x0, x19
    bl Lrtp_bcstr                   // the suffix
    ldp d10, d11, [sp, #48]
    ldp d8, d9, [sp, #32]
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// ---------------------------------------------------------------------
// Lrtp_textel -- append a text element: prefix, a, mid, b, suffix (the
//   numbers `%.2f`), the text escaped, then `</text>` and LF.
//   Inputs  : x0 = prefix, x1 = mid, x2 = suffix (literals), x3 = text
//             bytes, x4 = their count, d0 = a, d1 = b; x28 = Lrtp_st
//   Clobbers: as Lrtp_bput
//   Callee-saved used: x19 = mid, x20 = suffix, x21 = bytes, x22 =
//             count, d8 = a, d9 = b
//   Frame   : 64 bytes (frame record + x19..x22 + d8, d9)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_textel:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp d8, d9, [sp, #48]
    mov x19, x1
    mov x20, x2
    mov x21, x3
    mov x22, x4
    fmov d8, d0
    fmov d9, d1
    bl Lrtp_bcstr                   // prefix
    F2 d8
    mov x0, x19
    bl Lrtp_bcstr                   // mid
    F2 d9
    mov x0, x20
    bl Lrtp_bcstr                   // suffix
    mov x0, x21
    mov x1, x22
    bl Lrtp_btext                   // the text
    PUTC Lrtp_s_etext
    ldp d8, d9, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// ---------------------------------------------------------------------
// Lrtp_dash -- append ` stroke-dasharray="…"` for line codes 2, 3, 4
//   (2.14.6 "Series forms"); nothing for 0 and 1.
//   Inputs  : x0 = line code; x28 = Lrtp_st
//   Clobbers: as Lrtp_bput
//   Frame   : none (tail call)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_dash:
    LADR x9, Lrtp_s_dash2
    cmp x0, #2
    b.eq 1f
    LADR x9, Lrtp_s_dash3
    cmp x0, #3
    b.eq 1f
    LADR x9, Lrtp_s_dash4
    cmp x0, #4
    b.eq 1f
    ret
1:  mov x0, x9
    b Lrtp_bcstr

// =====================================================================
// Mapping (L-kl)
// =====================================================================

// ---------------------------------------------------------------------
// Lrtp_clamp -- NaN and values below -P become -P, values above 2P
//   become 2P (P = SEA_LIM_PLOT_PX).
//   Inputs  : d0;  Outputs: d0
//   Clobbers: d1, d2, x16, flags
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_clamp:
    LDK d1, P
    fneg d2, d1                     // -P
    fcmp d0, d0
    b.vs 1f                         // NaN
    fcmp d0, d2
    b.mi 1f                         // below -P (-Inf included)
    LDK d1, P2
    fcmp d0, d1
    b.gt 2f                         // above 2P (+Inf included)
    ret
1:  fmov d0, d2
    ret
2:  fmov d0, d1
    ret

// ---------------------------------------------------------------------
// Lrtp_mapx -- X(v) = px + ((v - xlo) / (xhi - xlo)) * pw, clamped.
//   Inputs  : d0 = v; x28 = Lrtp_st
//   Outputs : d0
//   Clobbers: d1-d3, x16, flags
//   Frame   : none (leaf, tail call of Lrtp_clamp)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_mapx:
    ldr d1, [x28, #(RS_AX + AS_LO)]
    ldr d2, [x28, #(RS_AX + AS_HI)]
    fsub d0, d0, d1                 // v - xlo
    fsub d2, d2, d1                 // xhi - xlo
    fdiv d0, d0, d2
    ldr d3, [x28, #RS_PW]
    fmul d0, d0, d3
    ldr d3, [x28, #RS_PX]
    fadd d0, d3, d0                 // px + ...
    b Lrtp_clamp

// ---------------------------------------------------------------------
// Lrtp_mapy -- Y(v) = py + ph - ((v - ylo) / (yhi - ylo)) * ph, or
//   py + ((v - ylo) / (yhi - ylo)) * ph for a reversed axis; clamped.
//   Inputs  : x0 = the axis (AS_*), d0 = v; x28 = Lrtp_st
//   Outputs : d0
//   Clobbers: d1-d4, x9, x16, flags
//   Frame   : none (leaf, tail call of Lrtp_clamp)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_mapy:
    ldr d1, [x0, #AS_LO]
    ldr d2, [x0, #AS_HI]
    fsub d0, d0, d1                 // v - ylo
    fsub d2, d2, d1                 // yhi - ylo
    fdiv d0, d0, d2
    ldr d3, [x28, #RS_PH]
    fmul d0, d0, d3                 // (...) * ph
    ldr d4, [x28, #RS_PY]
    ldr x9, [x0, #AS_REV]
    cbnz x9, 1f
    fadd d4, d4, d3                 // py + ph
    fsub d0, d4, d0                 // ... - (...) * ph
    b Lrtp_clamp
1:  fadd d0, d4, d0                 // reversed: py + (...) * ph
    b Lrtp_clamp

// =====================================================================
// Limits and ticks (2.14.6 "Limits", rules 1-6; L-kk)
// =====================================================================

// ---------------------------------------------------------------------
// Lrtp_dk -- d(k): 1.0 multiplied by 10 k times for k >= 0, else
//   1.0 / (1.0 multiplied by 10 -k times).
//   Inputs  : x0 = k (-300 .. 300)
//   Outputs : d0
//   Clobbers: x0, d1, d2, x16
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_dk:
    LDK d1, ONE
    LDK d2, TEN
    fmov d0, d1
    cmp x0, #0
    b.lt 2f
1:  cbz x0, 4f                      // k >= 0: k multiplications
    fmul d0, d0, d2
    sub x0, x0, #1
    b 1b
2:  neg x0, x0
3:  cbz x0, 31f                     // k < 0: 10 multiplied -k times ...
    fmul d0, d0, d2
    sub x0, x0, #1
    b 3b
31: fdiv d0, d1, d0                 // ... then 1.0 divided by it
4:  ret

// ---------------------------------------------------------------------
// Lrtp_cnt -- count(s) = ceil(hi / s) - floor(lo / s) and whether it is
//   <= 7 (false when it is NaN or infinite: rule 5).
//   Inputs  : d0 = s, d1 = lo, d2 = hi
//   Outputs : x0 = 1 when count <= 7, else 0; d0 = count; d1, d2 kept
//   Clobbers: d3-d5, x16, flags
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_cnt:
    fdiv d3, d2, d0
    frintp d3, d3                   // ceil(hi / s)
    fdiv d4, d1, d0
    frintm d4, d4                   // floor(lo / s)
    fsub d0, d3, d4
    LDK d5, SEVEN
    fcmp d0, d5
    cset x0, ls                     // <= 7, unordered false
    ret

// ---------------------------------------------------------------------
// Lrtp_step -- the step of rule 5 for [lo, hi].
//   Inputs  : d0 = lo, d1 = hi
//   Outputs : x0 = 1 and d0 = s, x1 = k when there is a step; x0 = 0 when
//             there is none
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = k, d8 = lo, d9 = hi, d10 = d(k)
//   Frame   : 48 bytes (frame record, x19, pad, d8..d10, pad)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_step:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    str x19, [sp, #16]
    stp d8, d9, [sp, #24]
    str d10, [sp, #40]
    fmov d8, d0
    fmov d9, d1
    mov x19, #0                     // k = 0
Lrtp_step_up:
    // while k < 300 and not count(5 d(k)) <= 7: k = k + 1
    cmp x19, #300
    b.ge Lrtp_step_down
    mov x0, x19
    bl Lrtp_dk
    LDK d1, FIVE
    fmul d0, d1, d0                 // 5 * d(k)
    fmov d1, d8
    fmov d2, d9
    bl Lrtp_cnt
    cbnz x0, Lrtp_step_down
    add x19, x19, #1
    b Lrtp_step_up
Lrtp_step_down:
    // while k > -300 and count(5 d(k - 1)) <= 7: k = k - 1
    cmn x19, #300
    b.le Lrtp_step_pick
    sub x0, x19, #1
    bl Lrtp_dk
    LDK d1, FIVE
    fmul d0, d1, d0
    fmov d1, d8
    fmov d2, d9
    bl Lrtp_cnt
    cbz x0, Lrtp_step_pick
    sub x19, x19, #1
    b Lrtp_step_down
Lrtp_step_pick:
    // s = the first of 1 d(k), 2 d(k), 5 d(k) with count <= 7.
    mov x0, x19
    bl Lrtp_dk
    fmov d10, d0                    // 1 * d(k) is d(k)
    fmov d1, d8
    fmov d2, d9
    bl Lrtp_cnt
    fmov d0, d10
    cbnz x0, Lrtp_step_found
    LDK d1, TWO
    fmul d0, d1, d10                // 2 * d(k)
    fmov d1, d8
    fmov d2, d9
    bl Lrtp_cnt
    LDK d1, TWO
    fmul d0, d1, d10
    cbnz x0, Lrtp_step_found
    LDK d1, FIVE
    fmul d0, d1, d10                // 5 * d(k)
    fmov d1, d8
    fmov d2, d9
    bl Lrtp_cnt
    LDK d1, FIVE
    fmul d0, d1, d10
    cbnz x0, Lrtp_step_found
    mov x0, #0                      // no step
    b 1f
Lrtp_step_found:
    mov x0, #1
    mov x1, x19
1:  ldr d10, [sp, #40]
    ldp d8, d9, [sp, #24]
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// ---------------------------------------------------------------------
// Lrtp_addtick -- append a numeric tick unless it is not finite or
//   equal to the last tick appended (rule 5), and at most RTP_TMAX.
//   Inputs  : x0 = the axis, d0 = the tick
//   Clobbers: x9, x10, d1, flags
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_addtick:
    BNF d0, d1, 1f                  // not finite: not drawn
    ldr x9, [x0, #AS_NT]
    cmp x9, #RTP_TMAX
    b.hs 1f
    add x10, x0, #AS_TV
    cbz x9, 2f
    sub x9, x9, #1
    ldr d1, [x10, x9, lsl #3]       // the tick before it
    add x9, x9, #1
    fcmp d0, d1
    b.eq 1f                         // equal: not drawn
2:  str d0, [x10, x9, lsl #3]
    add x9, x9, #1
    str x9, [x0, #AS_NT]
1:  ret

// ---------------------------------------------------------------------
// Lrtp_ticks_in -- the ticks of the step of rule 5 that lie inside the
//   axis's limits (rules 1 and 3, and rule 6's recomputation): with c0 =
//   ceil(lo / s), the ticks (c0 + f64(i)) * s for i = 0 .. floor(hi / s)
//   - c0 (none when that is negative). No step: no ticks.
//   Inputs  : x0 = the axis (AS_LO, AS_HI set)
//   Outputs : AS_MODE (0 or 1), AS_NT, AS_TV, AS_S, AS_K
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = axis, x20 = i, x21 = last i, d8 = s,
//             d9 = c0
//   Frame   : 64 bytes (frame record + x19..x21, pad, d8, d9)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_ticks_in:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    stp d8, d9, [sp, #48]
    mov x19, x0
    str xzr, [x19, #AS_MODE]
    str xzr, [x19, #AS_NT]
    ldr d0, [x19, #AS_LO]
    ldr d1, [x19, #AS_HI]
    bl Lrtp_step
    cbz x0, 9f                      // no step: no ticks
    str d0, [x19, #AS_S]
    str x1, [x19, #AS_K]
    mov x9, #1
    str x9, [x19, #AS_MODE]
    fmov d8, d0
    ldr d1, [x19, #AS_LO]
    fdiv d1, d1, d8
    frintp d9, d1                   // c0 = ceil(lo / s)
    ldr d2, [x19, #AS_HI]
    fdiv d2, d2, d8
    frintm d2, d2                   // floor(hi / s)
    fsub d2, d2, d9                 // the last i
    fcmp d2, #0.0
    b.mi 9f                         // negative: no tick
    fcvtzs x21, d2                  // <= 7 (it is at most count(s))
    cmp x21, #(RTP_TMAX - 1)
    mov x9, #(RTP_TMAX - 1)
    csel x21, x9, x21, hi
    mov x20, #0
1:  scvtf d0, x20
    fadd d0, d9, d0                 // c0 + f64(i)
    fmul d0, d0, d8                 // ... * s
    mov x0, x19
    bl Lrtp_addtick
    add x20, x20, #1
    cmp x20, x21
    b.ls 1b
9:  ldp d8, d9, [sp, #48]
    ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// ---------------------------------------------------------------------
// Lrtp_widen -- rule 4's limits before rounding (also rule 3's): no
//   extent 0 .. 1; a zero range at v: -1 .. 1 for v = 0, else v - |v|/10
//   .. v + |v|/10, else (not finite) v - 1 .. v + 1, else 0 .. 1; any
//   other extent itself.
//   Inputs  : x0 = the axis (AS_EXT, AS_ELO, AS_EHI)
//   Outputs : AS_LO, AS_HI
//   Clobbers: d0-d6, x9, x16, flags
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_widen:
    ldr x9, [x0, #AS_EXT]
    cbz x9, 3f                      // no extent: 0 .. 1
    ldr d0, [x0, #AS_ELO]
    ldr d1, [x0, #AS_EHI]
    fcmp d0, d1
    b.ne 5f                         // a range: the extent itself
    fcmp d0, #0.0
    b.ne 1f
    LDK d1, ONE                     // v = 0: -1 .. 1
    fneg d0, d1
    b 5f
1:  fabs d2, d0
    LDK d3, F10
    fdiv d2, d2, d3                 // |v| / 10
    fsub d4, d0, d2                 // v - |v|/10
    fadd d5, d0, d2                 // v + |v|/10
    BNF d4, d6, 2f
    BNF d5, d6, 2f
    fmov d0, d4
    fmov d1, d5
    b 5f
2:  LDK d3, ONE                     // v - 1 .. v + 1
    fsub d4, d0, d3
    fadd d5, d0, d3
    fcmp d4, d5
    b.eq 3f                         // equal: 0 .. 1
    fmov d0, d4
    fmov d1, d5
    b 5f
3:  movi d0, #0                     // 0 .. 1
    LDK d1, ONE
5:  str d0, [x0, #AS_LO]
    str d1, [x0, #AS_HI]
    ret

// ---------------------------------------------------------------------
// Lrtp_limits -- the limits and ticks of one axis (rules 1-5).
//   Purpose : explicit limits (rule 1) with the inside ticks; else
//             category labels (rule 2: -0.5 .. n - 0.5 widened to the
//             extent, ticks 0 .. n-1); else, when the pair holds an image
//             (RS_TIGHT), the widened extent with the inside ticks (rule
//             3); else rule 4: the widened extent rounded out to the
//             step, ticks (floor(lo / s) + f64(i)) * s for i = 0 ..
//             count(s), or the widened limits and no ticks when there is
//             no step or a rounded limit is not finite.
//   Inputs  : x0 = the axis (AS_EXT, AS_ELO, AS_EHI, AS_REV set), x1 = 1
//             when explicit limits are set, d0, d1 = those limits,
//             x2 = the category labels, x3 = their count; x28 = Lrtp_st
//   Outputs : AS_LO, AS_HI, AS_MODE, AS_NT, AS_TV, AS_S, AS_K, AS_CAT,
//             AS_NCAT
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = axis, x20 = i, x21 = count, d8 = s, d9 =
//             floor(lo / s)
//   Frame   : 64 bytes (frame record + x19..x21, pad, d8, d9)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_limits:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    stp d8, d9, [sp, #48]
    mov x19, x0
    str x2, [x19, #AS_CAT]
    str x3, [x19, #AS_NCAT]
    str xzr, [x19, #AS_MODE]
    str xzr, [x19, #AS_NT]
    cbz x1, 1f
    // Rule 1: the explicit limits, the ticks inside them.
    str d0, [x19, #AS_LO]
    str d1, [x19, #AS_HI]
    mov x0, x19
    bl Lrtp_ticks_in
    b 9f
1:  cbz x3, 3f
    // Rule 2: categories.
    LDK d0, HALF
    fneg d0, d0                     // -0.5
    scvtf d1, x3
    LDK d2, HALF
    fsub d1, d1, d2                 // f64(n) - 0.5
    ldr x9, [x19, #AS_EXT]
    cbz x9, 2f
    ldr d2, [x19, #AS_ELO]
    fcmp d2, d0
    fcsel d0, d2, d0, mi            // min(-0.5, extent lo)
    ldr d2, [x19, #AS_EHI]
    fcmp d2, d1
    fcsel d1, d2, d1, gt            // max(f64(n) - 0.5, extent hi)
2:  str d0, [x19, #AS_LO]
    str d1, [x19, #AS_HI]
    mov x9, #2
    str x9, [x19, #AS_MODE]
    str x3, [x19, #AS_NT]           // the ticks 0 .. n-1 (all inside)
    b 9f
3:  mov x0, x19
    bl Lrtp_widen                   // rules 3 and 4 widen the extent alike
    ldr x9, [x28, #RS_TIGHT]
    cbz x9, 4f
    mov x0, x19                     // rule 3: the inside ticks
    bl Lrtp_ticks_in
    b 9f
4:  // Rule 4: the step, the rounded limits, the ticks.
    ldr d0, [x19, #AS_LO]
    ldr d1, [x19, #AS_HI]
    bl Lrtp_step
    cbz x0, 9f                      // no step: lo, hi, no ticks
    fmov d8, d0
    mov x20, x1                     // k
    ldr d1, [x19, #AS_LO]
    fdiv d1, d1, d8
    frintm d9, d1                   // floor(lo / s)
    fmul d2, d9, d8                 // lo' = floor(lo / s) * s
    ldr d3, [x19, #AS_HI]
    fdiv d3, d3, d8
    frintp d3, d3                   // ceil(hi / s)
    fmul d4, d3, d8                 // hi' = ceil(hi / s) * s
    BNF d2, d5, 9f                  // not finite: lo, hi, no ticks
    BNF d4, d5, 9f
    str d2, [x19, #AS_LO]
    str d4, [x19, #AS_HI]
    str d8, [x19, #AS_S]
    str x20, [x19, #AS_K]
    mov x9, #1
    str x9, [x19, #AS_MODE]
    fsub d3, d3, d9                 // count(s), <= 7 (it passed)
    fcvtzs x21, d3
    cmp x21, #(RTP_TMAX - 1)
    mov x9, #(RTP_TMAX - 1)
    csel x21, x9, x21, hi
    mov x20, #0
5:  scvtf d0, x20
    fadd d0, d9, d0                 // floor(lo / s) + f64(i)
    fmul d0, d0, d8                 // ... * s
    mov x0, x19
    bl Lrtp_addtick
    add x20, x20, #1
    cmp x20, x21
    b.ls 5b
9:  ldp d8, d9, [sp, #48]
    ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// ---------------------------------------------------------------------
// Lrtp_equal -- rule 6 (axis equal on the base axes, after rules 1-5):
//   ux = (xhi - xlo) / pw, uy = (yhi - ylo) / ph; if ux > uy the y limits
//   become c -+ (ux * ph) / 2 with c = (ylo + yhi) / 2, else the x limits
//   likewise with uy * pw; the changed axis's ticks are the inside ticks
//   of its new limits. A new limit that is not finite changes nothing.
//   Inputs  : x28 = Lrtp_st (RS_AX, RS_AY, RS_PW, RS_PH set)
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Frame   : 16 bytes (frame record)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_equal:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    ldr d0, [x28, #(RS_AX + AS_LO)]
    ldr d1, [x28, #(RS_AX + AS_HI)]
    ldr d2, [x28, #(RS_AY + AS_LO)]
    ldr d3, [x28, #(RS_AY + AS_HI)]
    ldr d4, [x28, #RS_PW]
    ldr d5, [x28, #RS_PH]
    fsub d6, d1, d0
    fdiv d6, d6, d4                 // ux
    fsub d7, d3, d2
    fdiv d7, d7, d5                 // uy
    LDK d16, TWO
    fcmp d6, d7
    b.gt 1f
    // The x limits: c = (xlo + xhi) / 2, half = (uy * pw) / 2.
    fadd d17, d0, d1
    fdiv d17, d17, d16
    fmul d18, d7, d4
    fdiv d18, d18, d16
    fsub d19, d17, d18
    fadd d20, d17, d18
    add x0, x28, #RS_AX
    b 2f
1:  // The y limits: c = (ylo + yhi) / 2, half = (ux * ph) / 2.
    fadd d17, d2, d3
    fdiv d17, d17, d16
    fmul d18, d6, d5
    fdiv d18, d18, d16
    fsub d19, d17, d18
    fadd d20, d17, d18
    add x0, x28, #RS_AY
2:  BNF d19, d21, 3f                // not finite: both axes unchanged
    BNF d20, d21, 3f
    str d19, [x0, #AS_LO]
    str d20, [x0, #AS_HI]
    bl Lrtp_ticks_in                // x0 = the changed axis
3:  ldp x29, x30, [sp], #16
    ret

// ---------------------------------------------------------------------
// Lrtp_numtext -- the text of numeric tick j: v + 0.0 (so -0 is 0) under
//   the given conversion.
//   Inputs  : x0 = the axis, x1 = j, x2 = destination (RTP_NUMBUF bytes),
//             w3 = letter, x4 = precision
//   Outputs : x0 = length
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Frame   : 16 bytes (frame record)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_numtext:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    add x9, x0, #AS_TV
    ldr d0, [x9, x1, lsl #3]
    movi d1, #0
    fadd d0, d0, d1                 // v + 0.0
    mov x0, x2
    mov w1, w3
    mov x2, x4
    bl _sea_fmt_num
    ldp x29, x30, [sp], #16
    ret

// ---------------------------------------------------------------------
// Lrtp_distinct -- whether every two adjacent numeric ticks of the axis
//   get different texts under a conversion.
//   Inputs  : x0 = the axis, w1 = letter, x2 = precision; x28 = Lrtp_st
//   Outputs : x0 = 1 if all adjacent texts differ, else 0
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = axis, x20 = letter, x21 = precision,
//             x22 = j, x23 = length of text j - 1
//   Frame   : 64 bytes (frame record + x19..x23, pad)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_distinct:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    str x23, [sp, #48]
    mov x19, x0
    mov w20, w1
    mov x21, x2
    mov x22, #1
1:  ldr x9, [x19, #AS_NT]
    cmp x22, x9
    b.hs 3f                         // every pair differs
    mov x0, x19
    sub x1, x22, #1
    add x2, x28, #RS_T0
    mov w3, w20
    mov x4, x21
    bl Lrtp_numtext                 // text j - 1
    mov x23, x0
    mov x0, x19
    mov x1, x22
    add x2, x28, #RS_T1
    mov w3, w20
    mov x4, x21
    bl Lrtp_numtext                 // text j
    cmp x0, x23
    b.ne 2f                         // lengths differ
    add x0, x28, #RS_T0
    add x1, x28, #RS_T1
    mov x2, x23
    bl _memcmp
    cbz w0, 4f                      // equal texts
2:  add x22, x22, #1
    b 1b
3:  mov x0, #1
    b 5f
4:  mov x0, #0
5:  ldr x23, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// ---------------------------------------------------------------------
// Lrtp_tickfmt -- the conversion of a numeric axis's tick labels:
//   `%.{p}f` with p = max(0, -k), or `%g` when s >= 1e6 or s < 1e-4;
//   when two adjacent texts would be equal, `%.{q}g` with q the smallest
//   of 7 .. 17 that makes all adjacent texts differ (Decision 142 (a)).
//   Inputs  : x0 = the axis; x28 = Lrtp_st
//   Outputs : AS_LET, AS_PREC (nothing for a non-numeric axis)
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = axis, x20 = q
//   Frame   : 32 bytes (frame record + x19, x20)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_tickfmt:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    ldr x9, [x19, #AS_MODE]
    cmp x9, #1
    b.ne 9f
    ldr d0, [x19, #AS_S]
    mov w1, #'g'                    // %g (C's precision 6) ...
    mov x2, #-1
    LDK d1, E6
    fcmp d0, d1
    b.ge 1f                         // ... for s >= 1e6
    LDK d1, EM4
    fcmp d0, d1
    b.mi 1f                         // ... and s < 1e-4
    mov w1, #'f'                    // else %.{p}f, p = max(0, -k)
    ldr x2, [x19, #AS_K]
    neg x2, x2
    cmp x2, #0
    csel x2, xzr, x2, lt
1:  str x1, [x19, #AS_LET]
    str x2, [x19, #AS_PREC]
    mov x0, x19
    bl Lrtp_distinct
    cbnz x0, 9f
    mov x20, #7                     // Decision 142: q = 7 .. 17
2:  mov x0, x19
    mov w1, #'g'
    mov x2, x20
    bl Lrtp_distinct
    cbnz x0, 3f
    cmp x20, #17
    b.hs 3f                         // 17 always differs (equal ticks are not drawn)
    add x20, x20, #1
    b 2b
3:  mov x9, #'g'
    str x9, [x19, #AS_LET]
    str x20, [x19, #AS_PREC]
9:  ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// ---------------------------------------------------------------------
// Lrtp_tickval -- tick j's value: AS_TV[j] (numeric) or f64(j) (category).
//   Inputs  : x0 = the axis, x1 = j
//   Outputs : d0
//   Clobbers: x9
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_tickval:
    ldr x9, [x0, #AS_MODE]
    cmp x9, #2
    b.eq 1f
    add x9, x0, #AS_TV
    ldr d0, [x9, x1, lsl #3]
    ret
1:  scvtf d0, x1
    ret

// ---------------------------------------------------------------------
// Lrtp_ticktext -- tick j's label: the category string's bytes, or the
//   numeric text in RS_T0 under the axis's conversion.
//   Inputs  : x0 = the axis, x1 = j; x28 = Lrtp_st
//   Outputs : x0 = bytes, x1 = count
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Frame   : 16 bytes (frame record)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_ticktext:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    ldr x9, [x0, #AS_MODE]
    cmp x9, #2
    b.ne 1f
    ldr x9, [x0, #AS_CAT]
    ldr x9, [x9, x1, lsl #3]        // label j
    ldr x1, [x9, #SEA_STR_LEN]
    add x0, x9, #SEA_STR_BYTES
    b 2f
1:  ldr w3, [x0, #AS_LET]
    ldr x4, [x0, #AS_PREC]
    add x2, x28, #RS_T0
    bl Lrtp_numtext
    mov x1, x0
    add x0, x28, #RS_T0
2:  ldp x29, x30, [sp], #16
    ret

// ---------------------------------------------------------------------
// Lrtp_tickpath -- the path items of an axis's ticks, each `M`, then for
//   an x-axis X(tick) ` ` fixed, for a y-axis fixed ` ` Y(tick), then the
//   suffix literal and, if asked, the tail number; items joined by one
//   space across calls (RS_FIRST).
//   Inputs  : x0 = the axis, x1 = 1 for the x-axis, d0 = fixed, x2 =
//             suffix, x3 = 1 to write d1 after it, d1 = tail; x28 =
//             Lrtp_st
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = axis, x20 = is x, x21 = suffix, x22 = tail
//             flag, x23 = j, d8 = fixed, d9 = tail, d10 = mapped tick
//   Frame   : 96 bytes (frame record + x19..x23, pad, d8..d10, pad)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_tickpath:
    stp x29, x30, [sp, #-96]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    str x23, [sp, #48]
    stp d8, d9, [sp, #64]
    str d10, [sp, #80]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    fmov d8, d0
    fmov d9, d1
    mov x23, #0
1:  ldr x9, [x19, #AS_NT]
    cmp x23, x9
    b.hs 9f
    ldr x9, [x28, #RS_FIRST]        // one space between items
    cbnz x9, 2f
    PUTB ' '
2:  str xzr, [x28, #RS_FIRST]
    PUTB 'M'
    mov x0, x19
    mov x1, x23
    bl Lrtp_tickval
    cbz x20, 3f
    bl Lrtp_mapx                    // x: X, then fixed
    fmov d10, d0
    F2 d10
    PUTB ' '
    F2 d8
    b 4f
3:  mov x0, x19                     // y: fixed, then Y
    bl Lrtp_mapy
    fmov d10, d0
    F2 d8
    PUTB ' '
    F2 d10
4:  mov x0, x21
    bl Lrtp_bcstr                   // the suffix
    cbz x22, 5f
    F2 d9                           // and the tail
5:  add x23, x23, #1
    b 1b
9:  ldr d10, [sp, #80]
    ldp d8, d9, [sp, #64]
    ldr x23, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #96
    ret

// ---------------------------------------------------------------------
// Lrtp_ticktexts -- one text element per tick of an axis: for the
//   x-axis prefix X `" y="` fixed, for a y-axis prefix fixed `" y="`
//   Y + 3.5, then the suffix and the label.
//   Inputs  : x0 = the axis, x1 = 1 for the x-axis, x2 = prefix, x3 =
//             suffix, d0 = fixed; x28 = Lrtp_st
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = axis, x20 = is x, x21 = prefix, x22 =
//             suffix, x23 = j, x24 = label bytes, x25 = count, d8 =
//             fixed, d9 = the mapped tick
//   Frame   : 96 bytes (frame record + x19..x25, pad, d8, d9)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_ticktexts:
    stp x29, x30, [sp, #-96]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    str x25, [sp, #64]
    stp d8, d9, [sp, #80]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    fmov d8, d0
    mov x23, #0
1:  ldr x9, [x19, #AS_NT]
    cmp x23, x9
    b.hs 9f
    mov x0, x19
    mov x1, x23
    bl Lrtp_ticktext                // the label (RS_T0 for a number)
    mov x24, x0
    mov x25, x1
    mov x0, x19
    mov x1, x23
    bl Lrtp_tickval
    cbz x20, 2f
    bl Lrtp_mapx                    // x: a = X, b = fixed
    fmov d1, d8
    b 3f
2:  mov x0, x19                     // y: a = fixed, b = Y + 3.5
    bl Lrtp_mapy
    LDK d1, T35
    fadd d1, d0, d1
    fmov d0, d8
3:  mov x0, x21
    LADR x1, Lrtp_s_qy
    mov x2, x22
    mov x3, x24
    mov x4, x25
    bl Lrtp_textel
    add x23, x23, #1
    b 1b
9:  ldp d8, d9, [sp, #80]
    ldr x25, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #96
    ret

// =====================================================================
// Extents (2.14.6 "Data extents"; L-kj)
// =====================================================================

// ---------------------------------------------------------------------
// Lrtp_extend -- widen an axis's extent by the finite values of a vector
//   (value by value; ties keep the earlier value: strict < and >).
//   Inputs  : x0 = the axis, x1 = the values, x2 = their count
//   Clobbers: x1-x3, x9, d0-d2, flags
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_extend:
1:  cbz x2, 9f
    ldr d0, [x1], #8
    sub x2, x2, #1
    BNF d0, d1, 1b                  // non-finite: skipped
    ldr x9, [x0, #AS_EXT]
    cbnz x9, 2f
    str d0, [x0, #AS_ELO]           // the first value
    str d0, [x0, #AS_EHI]
    mov x9, #1
    str x9, [x0, #AS_EXT]
    b 1b
2:  ldr d1, [x0, #AS_ELO]
    fcmp d0, d1
    b.pl 3f
    str d0, [x0, #AS_ELO]           // a new minimum
3:  ldr d2, [x0, #AS_EHI]
    fcmp d0, d2
    b.le 1b
    str d0, [x0, #AS_EHI]           // a new maximum
    b 1b
9:  ret

// ---------------------------------------------------------------------
// Lrtp_extents -- the extents of the pair being written: a line series
//   gives its x values to the x-axis and its y values to its own y-axis;
//   an xline nothing; RS_TIGHT is set when the pair holds an image.
//   Inputs  : x28 = Lrtp_st (RS_FIG, RS_BIDX, RS_TIDX set)
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = series record, x20 = records left
//   Frame   : 32 bytes (frame record + x19, x20)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_extents:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str xzr, [x28, #(RS_AX + AS_EXT)]
    str xzr, [x28, #(RS_AY + AS_EXT)]
    str xzr, [x28, #(RS_AT + AS_EXT)]
    str xzr, [x28, #RS_TIGHT]
    ldr x9, [x28, #RS_FIG]
    ldr x19, [x9, #RTP_F_SRT]
    ldr x20, [x9, #RTP_F_NSR]
1:  cbz x20, 9f
    ldr x10, [x19, #RTP_SR_AX]
    ldr x11, [x28, #RS_BIDX]
    ldr x12, [x28, #RS_TIDX]
    cmp x10, x11
    b.eq 2f
    cmp x10, x12
    b.ne 5f                         // not this pair's
2:  ldr x13, [x19, #RTP_SR_KIND]
    cmp x13, #RTP_K_IMAGE
    b.ne 3f
    mov x9, #1
    str x9, [x28, #RS_TIGHT]
3:  cmp x13, #RTP_K_LINE
    b.ne 5f
    add x0, x28, #RS_AX             // x values to the x-axis
    ldr x1, [x19, #RTP_SR_DATA]
    ldr x2, [x19, #RTP_SR_N]
    bl Lrtp_extend
    ldr x10, [x19, #RTP_SR_AX]      // y values to its own y-axis
    ldr x11, [x28, #RS_BIDX]
    add x0, x28, #RS_AY
    cmp x10, x11
    b.eq 4f
    add x0, x28, #RS_AT
4:  ldr x2, [x19, #RTP_SR_N]
    ldr x1, [x19, #RTP_SR_DATA]
    add x1, x1, x2, lsl #3
    bl Lrtp_extend
5:  add x19, x19, #RTP_SR_SIZE
    sub x20, x20, #1
    b 1b
9:  ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// =====================================================================
// Series and legend writers
// =====================================================================

// ---------------------------------------------------------------------
// Lrtp_marker -- append one marker's path items centred at (X, Y)
//   (2.14.6 "Series forms"): from Lrtp_mk's entry list, each item `M`,
//   X + dx, ` `, Y + dy (a zero offset leaves the value as it is), then
//   its suffix literal.
//   Inputs  : x0 = marker code (1 .. 9), d0 = X, d1 = Y; x28 = Lrtp_st
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = entry, d8 = X, d9 = Y
//   Frame   : 48 bytes (frame record + x19, pad, d8, d9)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_marker:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    str x19, [sp, #16]
    stp d8, d9, [sp, #32]
    fmov d8, d0
    fmov d9, d1
    LADR x9, Lrtp_mk
    sub x0, x0, #1
    ldr x19, [x9, x0, lsl #3]       // the marker's entries
1:  ldr x9, [x19, #16]
    cbz x9, 9f                      // the end of the list
    PUTB 'M'
    ldr d1, [x19]                   // dx
    fmov d0, d8
    fcmp d1, #0.0
    b.eq 2f
    fadd d0, d8, d1                 // X + dx
2:  bl Lrtp_f2
    PUTB ' '
    ldr d1, [x19, #8]               // dy
    fmov d0, d9
    fcmp d1, #0.0
    b.eq 3f
    fadd d0, d9, d1                 // Y + dy
3:  bl Lrtp_f2
    ldr x0, [x19, #16]
    bl Lrtp_bcstr                   // the suffix
    add x19, x19, #24
    b 1b
9:  ldp d8, d9, [sp, #32]
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// ---------------------------------------------------------------------
// Lrtp_line -- a line series (2.14.6 "Series forms"): the path of the
//   runs of consecutive finite points if it has a line part, then the
//   path of the markers of the finite points if it has a marker.
//   Inputs  : x0 = the series record; x28 = Lrtp_st
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = record, x20 = i, x21 = n, x22 = x values,
//             x23 = y values, x24 = its y-axis, x25 = previous point
//             finite, x26 = pass (0 line, 1 markers), d8 = X, d9 = Y
//   Frame   : 112 bytes (frame record + x19..x26, d8, d9, pad)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_line:
    stp x29, x30, [sp, #-112]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp d8, d9, [sp, #80]
    mov x19, x0
    ldr x21, [x19, #RTP_SR_N]
    ldr x22, [x19, #RTP_SR_DATA]
    add x23, x22, x21, lsl #3
    ldr x9, [x19, #RTP_SR_AX]       // its own y-axis
    ldr x10, [x28, #RS_BIDX]
    add x24, x28, #RS_AY
    cmp x9, x10
    b.eq 1f
    add x24, x28, #RS_AT
1:  mov x26, #0
    ldr x9, [x19, #RTP_SR_LINE]
    cbz x9, Lrtp_line_marks         // markers only
    PUTC Lrtp_s_line
Lrtp_line_pass:
    // One pass over the points: the runs (x26 = 0) or the markers (1).
    mov x20, #0
    mov x25, #0
    mov x9, #1
    str x9, [x28, #RS_FIRST]
2:  cmp x20, x21
    b.hs Lrtp_line_end
    ldr d0, [x22, x20, lsl #3]
    ldr d1, [x23, x20, lsl #3]
    add x20, x20, #1
    BNF d0, d2, 3f
    BNF d1, d2, 3f
    fmov d9, d1
    bl Lrtp_mapx
    fmov d8, d0
    mov x0, x24
    fmov d0, d9
    bl Lrtp_mapy
    fmov d9, d0
    cbnz x26, 4f
    // Runs: `M{X} {Y}` starts a run (after one space), ` L{X} {Y}`
    // continues it.
    cbnz x25, 5f
    ldr x9, [x28, #RS_FIRST]
    cbnz x9, 6f
    PUTB ' '
6:  PUTB 'M'
    b 7f
5:  PUTC Lrtp_s_sl
7:  str xzr, [x28, #RS_FIRST]
    F2 d8
    PUTB ' '
    F2 d9
    mov x25, #1
    b 2b
3:  mov x25, #0                     // a non-finite point ends the run
    b 2b
4:  // Markers: one per finite point, joined by one space.
    ldr x9, [x28, #RS_FIRST]
    cbnz x9, 8f
    PUTB ' '
8:  str xzr, [x28, #RS_FIRST]
    ldr x0, [x19, #RTP_SR_MARK]
    fmov d0, d8
    fmov d1, d9
    bl Lrtp_marker
    b 2b
Lrtp_line_end:
    cbnz x26, Lrtp_line_mend
    // The line element's attributes.
    PUTC Lrtp_s_fnstroke
    ldr x0, [x19, #RTP_SR_COLOR]
    bl Lrtp_bcolor
    PUTC Lrtp_s_qsw
    ldr d0, [x19, #RTP_SR_WIDTH]
    bl Lrtp_f2
    PUTB '"'
    ldr x0, [x19, #RTP_SR_LINE]
    bl Lrtp_dash
    PUTC Lrtp_s_eclose
Lrtp_line_marks:
    ldr x9, [x19, #RTP_SR_MARK]
    cbz x9, Lrtp_line_done
    PUTC Lrtp_s_markers
    mov x26, #1
    b Lrtp_line_pass
Lrtp_line_mend:
    PUTC Lrtp_s_qfill
    ldr x9, [x19, #RTP_SR_MARK]
    cmp x9, #RTP_MK_DOT
    b.ne 1f
    ldr x0, [x19, #RTP_SR_COLOR]    // `.` is filled with the colour
    bl Lrtp_bcolor
    b 2f
1:  PUTC Lrtp_s_none
2:  PUTC Lrtp_s_qstroke
    ldr x0, [x19, #RTP_SR_COLOR]
    bl Lrtp_bcolor
    PUTC Lrtp_s_sw1close
Lrtp_line_done:
    ldp d8, d9, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #112
    ret

// ---------------------------------------------------------------------
// Lrtp_xline -- an xline (2.14.6 "Series forms"): d is
//   `M{X} {py} V{py+ph}` for a finite position, else empty.
//   Inputs  : x0 = the series record; x28 = Lrtp_st
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = record, d8 = X
//   Frame   : 32 bytes (frame record + x19, d8)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_xline:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    str d8, [sp, #24]
    mov x19, x0
    PUTC Lrtp_s_xline
    ldr d0, [x19, #RTP_SR_XPOS]
    BNF d0, d1, 1f                  // not finite: an empty d
    bl Lrtp_mapx
    fmov d8, d0
    PUTB 'M'
    F2 d8
    PUTB ' '
    ldr d0, [x28, #RS_PY]
    bl Lrtp_f2
    PUTC Lrtp_s_sv
    ldr d0, [x28, #RS_PY]
    ldr d1, [x28, #RS_PH]
    fadd d0, d0, d1                 // py + ph
    bl Lrtp_f2
1:  PUTC Lrtp_s_fnstroke
    ldr x0, [x19, #RTP_SR_COLOR]
    bl Lrtp_bcolor
    PUTC Lrtp_s_qsw1q
    ldr x0, [x19, #RTP_SR_LINE]
    bl Lrtp_dash
    PUTC Lrtp_s_eclose
    ldr d8, [sp, #24]
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// ---------------------------------------------------------------------
// Lrtp_inpair -- whether a series belongs to the pair being written.
//   Inputs  : x0 = the series record; x28 = Lrtp_st
//   Outputs : x0 = 1 or 0
//   Clobbers: x9-x11, flags
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_inpair:
    ldr x9, [x0, #RTP_SR_AX]
    ldr x10, [x28, #RS_BIDX]
    ldr x11, [x28, #RS_TIDX]        // -1 matches no index
    cmp x9, x10
    ccmp x9, x11, #4, ne            // equal to either
    cset x0, eq
    ret

// ---------------------------------------------------------------------
// Lrtp_legend -- the pair's legend (2.14.6 "Legend", L-kn): when its
//   location is set and a line or bar series of the pair has a label;
//   the entries in call order.
//   Inputs  : x28 = Lrtp_st
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = series record, x20 = records left, x21 =
//             entries, x22 = the longest label, x23 = location, x24 = r,
//             d8 = bx, d9 = by, d10 = yc, d11 = bw, d12 = bh
//   Frame   : 112 bytes (frame record + x19..x24, d8..d12, pad)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_legend:
    stp x29, x30, [sp, #-112]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp d8, d9, [sp, #64]
    stp d10, d11, [sp, #80]
    str d12, [sp, #96]
    ldr x9, [x28, #RS_BASE]
    ldr x23, [x9, #RTP_AX_LEG]
    cbz x23, Lrtp_leg_done          // no location
    // Count the entries and the longest label.
    mov x21, #0
    mov x22, #0
    ldr x9, [x28, #RS_FIG]
    ldr x19, [x9, #RTP_F_SRT]
    ldr x20, [x9, #RTP_F_NSR]
1:  cbz x20, 3f
    mov x0, x19
    bl Lrtp_legentry
    cbz x0, 2f
    add x21, x21, #1
    ldr x9, [x19, #RTP_SR_LABEL]
    ldr x9, [x9, #SEA_STR_LEN]
    cmp x9, x22
    csel x22, x9, x22, hi
2:  add x19, x19, #RTP_SR_SIZE
    sub x20, x20, #1
    b 1b
3:  cbz x21, Lrtp_leg_done          // no labelled series
    // The box: lw = 7.2 x the longest label, bw = 40 + lw, bh = 16 n + 8.
    ucvtf d0, x22
    LDK d1, F72
    fmul d0, d1, d0
    LDK d1, F40
    fadd d11, d1, d0                // bw
    lsl x9, x21, #4
    add x9, x9, #8
    ucvtf d12, x9                   // bh
    ldr d0, [x28, #RS_PX]
    ldr d1, [x28, #RS_PW]
    // bx: east side (3 east, 5 northeast, 7 southeast), west side (4,
    // 6, 8), centred (1 north, 2 south).
    cmp x23, #3
    b.eq 4f
    cmp x23, #5
    b.eq 4f
    cmp x23, #7
    b.eq 4f
    cmp x23, #2
    b.ls 5f
    LDK d2, EIGHT                   // west: px + 8
    fadd d8, d0, d2
    b 6f
4:  fadd d8, d0, d1                 // east: px + pw - 8 - bw
    LDK d2, EIGHT
    fsub d8, d8, d2
    fsub d8, d8, d11
    b 6f
5:  fsub d2, d1, d11                // centred: px + (pw - bw) / 2
    LDK d3, TWO
    fdiv d2, d2, d3
    fadd d8, d0, d2
6:  ldr d0, [x28, #RS_PY]
    ldr d1, [x28, #RS_PH]
    // by: north side (1, 5, 6), south side (2, 7, 8), middle (3, 4).
    cmp x23, #1
    b.eq 7f
    cmp x23, #5
    b.eq 7f
    cmp x23, #6
    b.eq 7f
    cmp x23, #2
    b.eq 8f
    cmp x23, #7
    b.hs 8f
    fsub d2, d1, d12                // middle: py + (ph - bh) / 2
    LDK d3, TWO
    fdiv d2, d2, d3
    fadd d9, d0, d2
    b 9f
7:  LDK d2, EIGHT                   // north: py + 8
    fadd d9, d0, d2
    b 9f
8:  fadd d9, d0, d1                 // south: py + ph - 8 - bh
    LDK d2, EIGHT
    fsub d9, d9, d2
    fsub d9, d9, d12
9:  PUTC Lrtp_s_glegend
    LADR x0, Lrtp_s_legbox
    LADR x1, Lrtp_s_legboxend
    fmov d0, d8
    fmov d1, d9
    fmov d2, d11
    fmov d3, d12
    bl Lrtp_xywh
    // The entries.
    mov x24, #0
    ldr x9, [x28, #RS_FIG]
    ldr x19, [x9, #RTP_F_SRT]
    ldr x20, [x9, #RTP_F_NSR]
Lrtp_leg_loop:
    cbz x20, Lrtp_leg_end
    mov x0, x19
    bl Lrtp_legentry
    cbz x0, Lrtp_leg_next
    // yc = by + 12 + 16 r
    LDK d0, F12
    fadd d10, d9, d0
    lsl x9, x24, #4
    ucvtf d0, x9
    fadd d10, d10, d0
    ldr x9, [x19, #RTP_SR_KIND]
    cmp x9, #RTP_K_BAR
    b.eq Lrtp_leg_bar
    ldr x9, [x19, #RTP_SR_LINE]
    cbz x9, 1f
    // The line sample: M{bx+6} {yc} H{bx+26}.
    PUTC Lrtp_s_legline
    LDK d0, SIX
    fadd d0, d8, d0
    bl Lrtp_f2
    PUTB ' '
    F2 d10
    PUTC Lrtp_s_sh
    LDK d0, F26
    fadd d0, d8, d0
    bl Lrtp_f2
    PUTC Lrtp_s_fnstroke
    ldr x0, [x19, #RTP_SR_COLOR]
    bl Lrtp_bcolor
    PUTC Lrtp_s_qsw
    ldr d0, [x19, #RTP_SR_WIDTH]
    bl Lrtp_f2
    PUTB '"'
    ldr x0, [x19, #RTP_SR_LINE]
    bl Lrtp_dash
    PUTC Lrtp_s_eclose
1:  ldr x9, [x19, #RTP_SR_MARK]
    cbz x9, Lrtp_leg_label
    // The marker sample at (bx + 16, yc).
    PUTC Lrtp_s_legmarker
    ldr x0, [x19, #RTP_SR_MARK]
    LDK d0, M16
    fadd d0, d8, d0
    fmov d1, d10
    bl Lrtp_marker
    PUTC Lrtp_s_qfill
    ldr x9, [x19, #RTP_SR_MARK]
    cmp x9, #RTP_MK_DOT
    b.ne 2f
    ldr x0, [x19, #RTP_SR_COLOR]
    bl Lrtp_bcolor
    b 3f
2:  PUTC Lrtp_s_none
3:  PUTC Lrtp_s_qstroke
    ldr x0, [x19, #RTP_SR_COLOR]
    bl Lrtp_bcolor
    PUTC Lrtp_s_sw1close
    b Lrtp_leg_label
Lrtp_leg_bar:
    // A bar series' sample: x = bx + 10, y = yc - 4, 12 x 8.
    PUTC Lrtp_s_legbar
    LDK d0, F10
    fadd d0, d8, d0
    bl Lrtp_f2
    PUTC Lrtp_s_qy
    LDK d0, FOUR
    fsub d0, d10, d0
    bl Lrtp_f2
    PUTC Lrtp_s_legbarend
    ldr x0, [x19, #RTP_SR_COLOR]
    bl Lrtp_bcolor
    PUTC Lrtp_s_qclose
Lrtp_leg_label:
    // The label at (bx + 32, yc + 4).
    LADR x0, Lrtp_s_leglabel
    LADR x1, Lrtp_s_qy
    LADR x2, Lrtp_s_leglabelend
    ldr x9, [x19, #RTP_SR_LABEL]
    add x3, x9, #SEA_STR_BYTES
    ldr x4, [x9, #SEA_STR_LEN]
    LDK d0, F32
    fadd d0, d8, d0
    LDK d1, FOUR
    fadd d1, d10, d1
    bl Lrtp_textel
    add x24, x24, #1
Lrtp_leg_next:
    add x19, x19, #RTP_SR_SIZE
    sub x20, x20, #1
    b Lrtp_leg_loop
Lrtp_leg_end:
    PUTC Lrtp_s_eg
Lrtp_leg_done:
    ldr d12, [sp, #96]
    ldp d10, d11, [sp, #80]
    ldp d8, d9, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #112
    ret

// ---------------------------------------------------------------------
// Lrtp_legentry -- whether a series is a legend entry of the pair: a
//   line or bar series of the pair with a label (a stored label is
//   never empty).
//   Inputs  : x0 = the series record; x28 = Lrtp_st
//   Outputs : x0 = 1 or 0
//   Clobbers: x9-x12, flags
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_legentry:
    mov x12, x0
    ldr x9, [x12, #RTP_SR_LABEL]
    cbz x9, 1f
    ldr x9, [x12, #RTP_SR_KIND]
    cmp x9, #RTP_K_LINE
    ccmp x9, #RTP_K_BAR, #4, ne
    b.ne 1f
    ldr x9, [x12, #RTP_SR_AX]
    ldr x10, [x28, #RS_BIDX]
    ldr x11, [x28, #RS_TIDX]
    cmp x9, x10
    ccmp x9, x11, #4, ne
    cset x0, eq
    ret
1:  mov x0, #0
    ret

// =====================================================================
// The panel and the document
// =====================================================================

// ---------------------------------------------------------------------
// Lrtp_panel -- lay out and write one base axes and its twin (2.14.6
//   "Layout" .. "The SVG element grammar" item 5).
//   Inputs  : x0 = the base's index, x1 = its rank k among the bases;
//             x28 = Lrtp_st (RS_FIG set)
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = k, x20 = base record, x21 = twin record or
//             0, x22 = series record, x23 = records left, x24 = figure,
//             d8 = px, d9 = py, d10 = pw, d11 = ph, d12-d15 scratch
//   Frame   : 128 bytes (frame record + x19..x24, pad, d8..d15)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_panel:
    stp x29, x30, [sp, #-128]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp d8, d9, [sp, #64]
    stp d10, d11, [sp, #80]
    stp d12, d13, [sp, #96]
    stp d14, d15, [sp, #112]
    mov x19, x1
    ldr x24, [x28, #RS_FIG]
    ldr x9, [x24, #RTP_F_AXT]
    str x0, [x28, #RS_BIDX]
    add x20, x9, x0, lsl #8         // the base record (256 bytes each)
    str x20, [x28, #RS_BASE]
    ldr x10, [x20, #RTP_AX_TWIN]
    str x10, [x28, #RS_TIDX]
    mov x21, #0
    tbnz x10, #63, 1f
    add x21, x9, x10, lsl #8        // the twin's record
1:  str x21, [x28, #RS_TWIN]

    // ---- Layout: cw = W / ncols, ch = (H - hb) / nrows, the cell span,
    // the margins (mr 16, or 68 with a twin), pw and ph at least 1.
    ldr x9, [x24, #RTP_F_W]
    ucvtf d0, x9
    ldr x9, [x24, #RTP_F_NCOLS]
    ucvtf d1, x9
    fdiv d12, d0, d1                // cw
    movi d13, #0                    // hb = 0 ...
    ldr x9, [x24, #RTP_F_NAME]
    ldr x9, [x9, #SEA_STR_LEN]
    cbz x9, 2f
    LDK d13, M24                    // ... or 24 with a name
2:  ldr x9, [x24, #RTP_F_H]
    ucvtf d0, x9
    fsub d0, d0, d13
    ldr x9, [x24, #RTP_F_NROWS]
    ucvtf d1, x9
    fdiv d14, d0, d1                // ch
    ldr x9, [x20, #RTP_AX_COL]
    ucvtf d0, x9
    fmul d0, d0, d12                // x0 = f64(col) * cw
    ldr x9, [x20, #RTP_AX_ROW]
    ucvtf d1, x9
    fmul d1, d1, d14
    fadd d1, d13, d1                // y0 = hb + f64(row) * ch
    ldr x9, [x20, #RTP_AX_CSPAN]
    ucvtf d2, x9
    fmul d2, d2, d12                // w = f64(colspan) * cw
    ldr x9, [x20, #RTP_AX_RSPAN]
    ucvtf d3, x9
    fmul d3, d3, d14                // h = f64(rowspan) * ch
    LDK d15, M16                    // mr
    cbz x21, 3f
    LDK d15, M68
3:  LDK d4, M56
    fadd d8, d0, d4                 // px = x0 + 56
    LDK d5, M28
    fadd d9, d1, d5                 // py = y0 + 28
    fsub d10, d2, d4
    fsub d10, d10, d15              // pw = w - 56 - mr
    fsub d11, d3, d5
    LDK d4, M44
    fsub d11, d11, d4               // ph = h - 28 - 44
    LDK d4, ONE
    fcmp d10, d4
    fcsel d10, d4, d10, mi          // below 1: 1
    fcmp d11, d4
    fcsel d11, d4, d11, mi
    str d8, [x28, #RS_PX]
    str d9, [x28, #RS_PY]
    str d10, [x28, #RS_PW]
    str d11, [x28, #RS_PH]

    // ---- The axes: reversal, extents, limits and ticks, rule 6, formats.
    str xzr, [x28, #(RS_AX + AS_REV)]
    ldr x9, [x20, #RTP_AX_FLAGS]
    ubfx x9, x9, #RTP_FL_YREV, #1
    str x9, [x28, #(RS_AY + AS_REV)]
    mov x9, #0
    cbz x21, 4f
    ldr x9, [x21, #RTP_AX_FLAGS]
    ubfx x9, x9, #RTP_FL_YREV, #1
4:  str x9, [x28, #(RS_AT + AS_REV)]
    bl Lrtp_extents
    add x0, x28, #RS_AX             // the pair's x-axis (the base's fields)
    ldr x1, [x20, #RTP_AX_FLAGS]
    ubfx x1, x1, #RTP_FL_XLIM, #1
    ldr d0, [x20, #RTP_AX_XLO]
    ldr d1, [x20, #RTP_AX_XHI]
    ldr x2, [x20, #RTP_AX_XCAT]
    ldr x3, [x20, #RTP_AX_NXCAT]
    bl Lrtp_limits
    add x0, x28, #RS_AY             // the base's y-axis
    ldr x1, [x20, #RTP_AX_FLAGS]
    ubfx x1, x1, #RTP_FL_YLIM, #1
    ldr d0, [x20, #RTP_AX_YLO]
    ldr d1, [x20, #RTP_AX_YHI]
    ldr x2, [x20, #RTP_AX_YCAT]
    ldr x3, [x20, #RTP_AX_NYCAT]
    bl Lrtp_limits
    str xzr, [x28, #(RS_AT + AS_MODE)]
    str xzr, [x28, #(RS_AT + AS_NT)]
    cbz x21, 5f
    add x0, x28, #RS_AT             // the twin's y-axis
    ldr x1, [x21, #RTP_AX_FLAGS]
    ubfx x1, x1, #RTP_FL_YLIM, #1
    ldr d0, [x21, #RTP_AX_YLO]
    ldr d1, [x21, #RTP_AX_YHI]
    ldr x2, [x21, #RTP_AX_YCAT]
    ldr x3, [x21, #RTP_AX_NYCAT]
    bl Lrtp_limits
5:  ldr x9, [x20, #RTP_AX_FLAGS]
    tbz x9, #RTP_FL_EQUAL, 6f
    bl Lrtp_equal                   // rule 6
6:  add x0, x28, #RS_AX
    bl Lrtp_tickfmt
    add x0, x28, #RS_AY
    bl Lrtp_tickfmt
    add x0, x28, #RS_AT
    bl Lrtp_tickfmt

    // ---- 5.1 .. 5.3: the group, the clip path, the plot area.
    PUTC Lrtp_s_gpanel
    mov x0, x19
    bl Lrtp_bint
    PUTC Lrtp_s_qgt
    PUTC Lrtp_s_clip
    mov x0, x19
    bl Lrtp_bint
    PUTC Lrtp_s_qgt0
    LADR x0, Lrtp_s_cliprect
    LADR x1, Lrtp_s_clipend
    fmov d0, d8
    fmov d1, d9
    fmov d2, d10
    fmov d3, d11
    bl Lrtp_xywh
    LADR x0, Lrtp_s_plotarea
    LADR x1, Lrtp_s_fillwhite
    fmov d0, d8
    fmov d1, d9
    fmov d2, d10
    fmov d3, d11
    bl Lrtp_xywh
    // ---- 5.4: the grid.
    ldr x9, [x20, #RTP_AX_FLAGS]
    tbz x9, #RTP_FL_GRID, 7f
    PUTC Lrtp_s_grid
    mov x9, #1
    str x9, [x28, #RS_FIRST]
    add x0, x28, #RS_AX             // M{X} {py} V{py+ph}
    mov x1, #1
    fmov d0, d9
    LADR x2, Lrtp_s_sv
    mov x3, #1
    fadd d1, d9, d11
    bl Lrtp_tickpath
    add x0, x28, #RS_AY             // M{px} {Y} H{px+pw}
    mov x1, #0
    fmov d0, d8
    LADR x2, Lrtp_s_sh
    mov x3, #1
    fadd d1, d8, d10
    bl Lrtp_tickpath
    PUTC Lrtp_s_gridend
    // ---- 5.5: the data group, every series of the pair in call order.
7:  PUTC Lrtp_s_gdata
    mov x0, x19
    bl Lrtp_bint
    PUTC Lrtp_s_dataend
    ldr x22, [x24, #RTP_F_SRT]
    ldr x23, [x24, #RTP_F_NSR]
8:  cbz x23, 10f
    mov x0, x22
    bl Lrtp_inpair
    cbz x0, 9f
    ldr x9, [x22, #RTP_SR_KIND]
    mov x0, x22
    cmp x9, #RTP_K_LINE
    b.ne 81f
    bl Lrtp_line
    b 9f
81: cmp x9, #RTP_K_XLINE
    b.ne 9f                         // kinds 3 .. 6: sub-phase 9c
    bl Lrtp_xline
9:  add x22, x22, #RTP_SR_SIZE
    sub x23, x23, #1
    b 8b
10: PUTC Lrtp_s_eg
    // ---- 5.6: the axes box.
    LADR x0, Lrtp_s_axesbox
    LADR x1, Lrtp_s_boxend
    fmov d0, d8
    fmov d1, d9
    fmov d2, d10
    fmov d3, d11
    bl Lrtp_xywh
    // ---- 5.7: the tick marks.
    PUTC Lrtp_s_tickmarks
    mov x9, #1
    str x9, [x28, #RS_FIRST]
    add x0, x28, #RS_AX             // M{X} {py+ph} v-5.00
    mov x1, #1
    fadd d0, d9, d11
    LADR x2, Lrtp_s_vm5
    mov x3, #0
    bl Lrtp_tickpath
    add x0, x28, #RS_AY             // M{px} {Y} h5.00
    mov x1, #0
    fmov d0, d8
    LADR x2, Lrtp_s_h5
    mov x3, #0
    bl Lrtp_tickpath
    cbz x21, 11f
    add x0, x28, #RS_AT             // M{px+pw} {Y} h-5.00
    mov x1, #0
    fadd d0, d8, d10
    LADR x2, Lrtp_s_hm5
    mov x3, #0
    bl Lrtp_tickpath
11: PUTC Lrtp_s_boxend
    // ---- 5.8: the tick labels.
    add x0, x28, #RS_AX
    mov x1, #1
    LADR x2, Lrtp_s_xtick
    LADR x3, Lrtp_s_xtickend
    fadd d0, d9, d11
    LDK d1, F14
    fadd d0, d0, d1                 // py + ph + 14
    bl Lrtp_ticktexts
    add x0, x28, #RS_AY
    mov x1, #0
    LADR x2, Lrtp_s_ytick
    LADR x3, Lrtp_s_ytickend
    LDK d1, SIX
    fsub d0, d8, d1                 // px - 6
    bl Lrtp_ticktexts
    cbz x21, 12f
    add x0, x28, #RS_AT
    mov x1, #0
    LADR x2, Lrtp_s_ytick2
    LADR x3, Lrtp_s_ytick2end
    fadd d0, d8, d10
    LDK d1, SIX
    fadd d0, d0, d1                 // px + pw + 6
    bl Lrtp_ticktexts
    // ---- 5.10: the labels (5.9, the colorbar, is sub-phase 9c's).
12: ldr x9, [x20, #RTP_AX_XLAB]
    cbz x9, 13f
    ldr x4, [x9, #SEA_STR_LEN]
    cbz x4, 13f
    add x3, x9, #SEA_STR_BYTES
    LADR x0, Lrtp_s_xlabel
    LADR x1, Lrtp_s_qy
    LADR x2, Lrtp_s_lab12
    LDK d1, TWO
    fdiv d0, d10, d1
    fadd d0, d8, d0                 // px + pw / 2
    fadd d1, d9, d11
    LDK d2, F34
    fadd d1, d1, d2                 // py + ph + 34
    bl Lrtp_textel
13: ldr x9, [x20, #RTP_AX_YLAB]
    cbz x9, 14f
    ldr x4, [x9, #SEA_STR_LEN]
    cbz x4, 14f
    add x3, x9, #SEA_STR_BYTES
    LADR x0, Lrtp_s_ylabel
    LADR x1, Lrtp_s_space
    LADR x2, Lrtp_s_rotm90
    LDK d1, F42
    fsub d0, d8, d1                 // px - 42
    LDK d2, TWO
    fdiv d1, d11, d2
    fadd d1, d9, d1                 // py + ph / 2
    bl Lrtp_textel
14: cbz x21, 15f
    ldr x9, [x21, #RTP_AX_YLAB]
    cbz x9, 15f
    ldr x4, [x9, #SEA_STR_LEN]
    cbz x4, 15f
    add x3, x9, #SEA_STR_BYTES
    LADR x0, Lrtp_s_ylabel2
    LADR x1, Lrtp_s_space
    LADR x2, Lrtp_s_rot90
    fadd d0, d8, d10
    LDK d1, F48
    fadd d0, d0, d1                 // px + pw + 48
    LDK d2, TWO
    fdiv d1, d11, d2
    fadd d1, d9, d1                 // py + ph / 2
    bl Lrtp_textel
    // ---- 5.11: the title.
15: ldr x9, [x20, #RTP_AX_TITLE]
    cbz x9, 16f
    ldr x4, [x9, #SEA_STR_LEN]
    cbz x4, 16f
    add x3, x9, #SEA_STR_BYTES
    LADR x0, Lrtp_s_title
    LADR x1, Lrtp_s_qy
    LADR x2, Lrtp_s_lab14
    LDK d1, TWO
    fdiv d0, d10, d1
    fadd d0, d8, d0                 // px + pw / 2
    LDK d1, EIGHT
    fsub d1, d9, d1                 // py - 8
    bl Lrtp_textel
    // ---- 5.12, 5.13: the legend, the end of the group.
16: bl Lrtp_legend
    PUTC Lrtp_s_eg
    ldp d14, d15, [sp, #112]
    ldp d12, d13, [sp, #96]
    ldp d10, d11, [sp, #80]
    ldp d8, d9, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #128
    ret

// ---------------------------------------------------------------------
// _sea_save_svg -- the entry SAVE_SVG (DESIGN.md 2.14.5, 2.14.6): the
//   document built in the buffer, then written by _sea_file_put, which
//   frees the buffer (L-lc).
//   Inputs  : x0 = the figure, x1 = path (str), x2 = site
//   Outputs : none
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = figure, x20 = path, x21 = axes record,
//             x22 = index, x23 = rank k, x28 = Lrtp_st
//   Frame   : 64 bytes (frame record + x19..x23, x28)
// ---------------------------------------------------------------------
    .globl _sea_save_svg
    .p2align 2
_sea_save_svg:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x28, [sp, #48]
    mov x19, x0
    mov x20, x1
    LADR x28, Lrtp_st
    str x2, [x28, #RS_SITE]
    str x19, [x28, #RS_FIG]
    mov x0, #RTP_BUF0               // the buffer
    mov x1, x2
    bl _sea_alloc
    str x0, [x28, #RS_BPTR]
    str xzr, [x28, #RS_BLEN]
    mov x9, #RTP_BUF0
    str x9, [x28, #RS_BCAP]
    // 1 .. 3: the declaration, the root, the canvas.
    PUTC Lrtp_s_xml
    PUTC Lrtp_s_svg
    ldr x0, [x19, #RTP_F_W]
    bl Lrtp_bint
    PUTC Lrtp_s_qheight
    ldr x0, [x19, #RTP_F_H]
    bl Lrtp_bint
    PUTC Lrtp_s_viewbox
    ldr x0, [x19, #RTP_F_W]
    bl Lrtp_bint
    PUTB ' '
    ldr x0, [x19, #RTP_F_H]
    bl Lrtp_bint
    PUTC Lrtp_s_svgend
    PUTC Lrtp_s_canvas
    ldr x0, [x19, #RTP_F_W]
    bl Lrtp_bint
    PUTC Lrtp_s_qheight
    ldr x0, [x19, #RTP_F_H]
    bl Lrtp_bint
    PUTC Lrtp_s_fillwhite
    // 4: the heading, x = f64(W) / 2.
    ldr x9, [x19, #RTP_F_NAME]
    ldr x10, [x9, #SEA_STR_LEN]
    cbz x10, 1f
    PUTC Lrtp_s_heading
    ldr x9, [x19, #RTP_F_W]
    ucvtf d0, x9
    LDK d1, TWO
    fdiv d0, d0, d1
    bl Lrtp_f2
    PUTC Lrtp_s_headingend
    ldr x0, [x19, #RTP_F_NAME]
    bl Lrtp_bstr
    PUTC Lrtp_s_etext
    // 5: each base axes in creation order.
1:  mov x22, #0
    mov x23, #0
2:  ldr x9, [x19, #RTP_F_NAX]
    cmp x22, x9
    b.hs 4f
    ldr x9, [x19, #RTP_F_AXT]
    add x21, x9, x22, lsl #8
    ldr x10, [x21, #RTP_AX_KIND]
    cbnz x10, 3f                    // a twin: drawn with its base
    mov x0, x22
    mov x1, x23
    bl Lrtp_panel
    add x23, x23, #1
3:  add x22, x22, #1
    b 2b
    // 6: the end; then the file (the buffer freed by _sea_file_put).
4:  PUTC Lrtp_s_esvg
    mov x0, x20
    ldr x1, [x28, #RS_BPTR]
    ldr x2, [x28, #RS_BLEN]
    ldr x3, [x28, #RS_SITE]
    ldr x4, [x28, #RS_BCAP]
    bl _sea_file_put
    ldp x23, x28, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// =====================================================================
// Objects and the entries that build the figure
// =====================================================================

// ---------------------------------------------------------------------
// Lrtp_append -- append a zero-filled record to a figure's axes or
//   series table, doubling the table (a new block, the records copied,
//   the old block freed) when it is full.
//   Inputs  : x0 = figure, x1 = 0 for the axes table, 1 for the series
//             table, x2 = site
//   Outputs : x0 = the new record, x1 = its index
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = figure, x20 = field offset (count; capacity
//             at +8, table at +16), x21 = record size, x22 = site,
//             x23 = new capacity, x24 = new table
//   Frame   : 64 bytes (frame record + x19..x24)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_append:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x19, x0
    mov x22, x2
    mov x20, #RTP_F_NAX
    mov x21, #RTP_AX_SIZE
    cbz x1, 1f
    mov x20, #RTP_F_NSR
    mov x21, #RTP_SR_SIZE
1:  add x9, x19, x20
    ldr x10, [x9]                   // count
    ldr x11, [x9, #8]               // capacity
    cmp x10, x11
    b.lo 2f
    lsl x23, x11, #1                // full: double
    mul x0, x23, x21
    mov x1, x22
    bl _sea_alloc
    mov x24, x0
    add x9, x19, x20
    ldr x1, [x9, #16]               // copy the records
    ldr x10, [x9]
    mul x2, x10, x21
    bl _memcpy
    add x9, x19, x20
    ldr x0, [x9, #16]               // free the old table
    ldr x10, [x9, #8]
    mul x1, x10, x21
    bl _sea_free_block
    add x9, x19, x20
    str x23, [x9, #8]
    str x24, [x9, #16]
2:  add x9, x19, x20
    ldr x10, [x9]
    ldr x11, [x9, #16]
    madd x0, x10, x21, x11          // the new record
    add x12, x10, #1
    str x12, [x9]                   // one more
    mov x24, x10                    // its index
    mov w1, #0
    mov x2, x21
    mov x23, x0
    bl _memset                      // zero-filled
    mov x0, x23
    mov x1, x24
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// ---------------------------------------------------------------------
// Lrtp_newaxes -- a new Axes handle (count 1, counted in _sea_live)
//   referring to a figure (retained) and an axes record index.
//   Inputs  : x0 = figure, x1 = index, x2 = site
//   Outputs : x0 = the handle
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = figure, x20 = index
//   Frame   : 32 bytes (frame record + x19, x20)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_newaxes:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    mov x20, x1
    mov x0, #RTP_A_SIZE
    mov x1, x2
    bl _sea_alloc
    mov x9, #1
    str x9, [x0, #SEA_OBJ_RC]       // count 1
    mov x9, #SEA_TAG_AXES
    str x9, [x0, #SEA_OBJ_TAG]      // the tag, bytes 9 .. 15 zero
    str x19, [x0, #RTP_A_FIG]
    str x20, [x0, #RTP_A_IDX]
    mov x20, x0
    mov x0, x19
    bl _sea_retain                  // the handle keeps the figure
    LIVE_INC
    mov x0, x20
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// ---------------------------------------------------------------------
// _sea_figure -- the entry FIGURE (DESIGN.md 2.14.5): FIGURE_GRID
//   (nrows, ncols outside 1 .. SEA_LIM_PLOT_GRID), then FIGURE_SIZE
//   (width, height outside 1 .. SEA_LIM_PLOT_PX); a new Figure with no
//   axes, the name retained, both tables of capacity 8.
//   Inputs  : x0 = nrows, x1 = ncols, x2 = name, x3 = width, x4 =
//             height, x5 = site
//   Outputs : x0 = the Figure (count 1)
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = nrows, x20 = ncols, x21 = name, x22 =
//             width, x23 = height, x24 = site, x25 = the Figure
//   Frame   : 96 bytes (frame record + x19..x25, pad, two slots at 80)
// ---------------------------------------------------------------------
    .globl _sea_figure
    .p2align 2
_sea_figure:
    stp x29, x30, [sp, #-96]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    str x25, [sp, #64]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, x4
    mov x24, x5
    // The grid, then the size (2.14.2's check order).
    cmp x19, #1
    b.lt Lrtp_fig_grid
    cmp x19, #SEA_LIM_PLOT_GRID
    b.gt Lrtp_fig_grid
    cmp x20, #1
    b.lt Lrtp_fig_grid
    cmp x20, #SEA_LIM_PLOT_GRID
    b.gt Lrtp_fig_grid
    LI32 x9, SEA_LIM_PLOT_PX
    cmp x22, #1
    b.lt Lrtp_fig_size
    cmp x22, x9
    b.gt Lrtp_fig_size
    cmp x23, #1
    b.lt Lrtp_fig_size
    cmp x23, x9
    b.gt Lrtp_fig_size
    // The block, zero-filled.
    mov x0, #RTP_F_SIZE
    mov x1, x24
    bl _sea_alloc
    mov x25, x0
    mov w1, #0
    mov x2, #RTP_F_SIZE
    bl _memset
    mov x9, #1
    str x9, [x25, #SEA_OBJ_RC]
    mov x9, #SEA_TAG_FIGURE
    str x9, [x25, #SEA_OBJ_TAG]
    str x19, [x25, #RTP_F_NROWS]
    str x20, [x25, #RTP_F_NCOLS]
    str x22, [x25, #RTP_F_W]
    str x23, [x25, #RTP_F_H]
    str x21, [x25, #RTP_F_NAME]
    mov x0, x21
    bl _sea_retain                  // the figure keeps its name
    // The two tables, capacity 8 each.
    mov x0, #(RTP_TAB0 * RTP_AX_SIZE)
    mov x1, x24
    bl _sea_alloc
    str x0, [x25, #RTP_F_AXT]
    mov x9, #RTP_TAB0
    str x9, [x25, #RTP_F_AXCAP]
    mov x0, #(RTP_TAB0 * RTP_SR_SIZE)
    mov x1, x24
    bl _sea_alloc
    str x0, [x25, #RTP_F_SRT]
    mov x9, #RTP_TAB0
    str x9, [x25, #RTP_F_SRCAP]
    LIVE_INC
    mov x0, x25
    ldr x25, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #96
    ret
Lrtp_fig_grid:
    stp x19, x20, [sp, #80]         // slots: nrows, ncols
    mov w0, #SEA_E_FIGURE_GRID
    b 1f
Lrtp_fig_size:
    stp x22, x23, [sp, #80]         // slots: width, height
    mov w0, #SEA_E_FIGURE_SIZE
1:  mov x1, x24
    add x2, sp, #80
    bl _sea_err                     // noreturn

// ---------------------------------------------------------------------
// _sea_panel -- the entry PANEL (DESIGN.md 2.14.5): PANEL_CELL (row <
//   0, col < 0, rowspan < 1, colspan < 1, row + rowspan > nrows, col +
//   colspan > ncols, tested without overflow as rowspan > nrows - row),
//   then PANEL_TAKEN (the first occupied cell, rows ascending, then
//   columns); the cells marked, a base axes record appended, a new Axes.
//   Inputs  : x0 = figure, x1 = row, x2 = col, x3 = rowspan, x4 =
//             colspan, x5 = site
//   Outputs : x0 = the Axes (count 1)
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = figure, x20 = row, x21 = col, x22 =
//             rowspan, x23 = colspan, x24 = site, x25 = r, x26 = c
//   Frame   : 128 bytes (frame record + x19..x26, six slots at 80)
// ---------------------------------------------------------------------
    .globl _sea_panel
    .p2align 2
_sea_panel:
    stp x29, x30, [sp, #-128]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, x4
    mov x24, x5
    ldr x9, [x19, #RTP_F_NROWS]
    ldr x10, [x19, #RTP_F_NCOLS]
    cmp x20, #0
    b.lt Lrtp_pan_cell
    cmp x21, #0
    b.lt Lrtp_pan_cell
    cmp x22, #1
    b.lt Lrtp_pan_cell
    cmp x23, #1
    b.lt Lrtp_pan_cell
    sub x11, x9, x20                // nrows - row
    cmp x22, x11
    b.gt Lrtp_pan_cell
    sub x11, x10, x21               // ncols - col
    cmp x23, x11
    b.gt Lrtp_pan_cell
    // PANEL_TAKEN: the first cell of the span that a panel holds.
    mov x25, x20
1:  add x11, x20, x22
    cmp x25, x11
    b.hs 3f
    add x12, x19, #RTP_F_OCC
    ldr x12, [x12, x25, lsl #3]     // row r's word
    mov x26, x21
2:  add x11, x21, x23
    cmp x26, x11
    b.hs 21f
    lsr x13, x12, x26
    tbnz x13, #0, Lrtp_pan_taken
    add x26, x26, #1
    b 2b
21: add x25, x25, #1
    b 1b
    // Mark the cells.
3:  mov x25, x20
4:  add x11, x20, x22
    cmp x25, x11
    b.hs 6f
    add x12, x19, #RTP_F_OCC
    ldr x13, [x12, x25, lsl #3]
    mov x26, x21
5:  add x11, x21, x23
    cmp x26, x11
    b.hs 51f
    mov x14, #1
    lsl x14, x14, x26
    orr x13, x13, x14               // bit c of word r
    add x26, x26, #1
    b 5b
51: str x13, [x12, x25, lsl #3]
    add x25, x25, #1
    b 4b
    // The base axes record (zero-filled: cycle 0, no flags, no legend).
6:  mov x0, x19
    mov x1, #0
    mov x2, x24
    bl Lrtp_append                  // x0 = record, x1 = index
    mov x25, x1
    str xzr, [x0, #RTP_AX_KIND]
    str x25, [x0, #RTP_AX_BASE]
    mov x9, #-1
    str x9, [x0, #RTP_AX_TWIN]
    str x20, [x0, #RTP_AX_ROW]
    str x21, [x0, #RTP_AX_COL]
    str x22, [x0, #RTP_AX_RSPAN]
    str x23, [x0, #RTP_AX_CSPAN]
    mov x0, x19
    mov x1, x25
    mov x2, x24
    bl Lrtp_newaxes
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #128
    ret
Lrtp_pan_cell:
    stp x20, x21, [sp, #80]         // row, col, rowspan, colspan, nrows, ncols
    stp x22, x23, [sp, #96]
    stp x9, x10, [sp, #112]
    mov w0, #SEA_E_PANEL_CELL
    b 7f
Lrtp_pan_taken:
    stp x25, x26, [sp, #80]         // the cell r, c
    mov w0, #SEA_E_PANEL_TAKEN
7:  mov x1, x24
    add x2, sp, #80
    bl _sea_err                     // noreturn

// ---------------------------------------------------------------------
// _sea_twin_y -- the entry TWIN_Y (DESIGN.md 2.14.5, Decision 134 (a)):
//   a twin returns itself, a base with a twin that twin, else a new twin
//   record (kind 1, the base's cells, cycle index 1) is appended and the
//   base points at it; a new Axes referring to the result.
//   Inputs  : x0 = Axes, x1 = site
//   Outputs : x0 = the Axes (count 1)
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = figure, x20 = index, x21 = site, x22 = the
//             twin's index
//   Frame   : 48 bytes (frame record + x19..x22)
// ---------------------------------------------------------------------
    .globl _sea_twin_y
    .p2align 2
_sea_twin_y:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x21, x1
    AXES                            // x0 fig, x1 own record, x3 index
    mov x19, x0
    mov x20, x3
    mov x22, x3                     // a twin: itself
    ldr x9, [x1, #RTP_AX_KIND]
    cbnz x9, 1f
    ldr x22, [x1, #RTP_AX_TWIN]     // a base with a twin: that twin
    tbz x22, #63, 1f
    mov x0, x19                     // a new twin record (the table may move)
    mov x1, #0
    mov x2, x21
    bl Lrtp_append                  // x0 = record, x1 = index
    mov x22, x1
    ldr x9, [x19, #RTP_F_AXT]
    add x10, x9, x20, lsl #8        // the base, read again
    mov x9, #1
    str x9, [x0, #RTP_AX_KIND]
    str x20, [x0, #RTP_AX_BASE]
    mov x9, #-1
    str x9, [x0, #RTP_AX_TWIN]
    ldr x9, [x10, #RTP_AX_ROW]
    str x9, [x0, #RTP_AX_ROW]
    ldr x9, [x10, #RTP_AX_COL]
    str x9, [x0, #RTP_AX_COL]
    ldr x9, [x10, #RTP_AX_RSPAN]
    str x9, [x0, #RTP_AX_RSPAN]
    ldr x9, [x10, #RTP_AX_CSPAN]
    str x9, [x0, #RTP_AX_CSPAN]
    mov x9, #1
    str x9, [x0, #RTP_AX_CYC]       // the twin's cycle starts at #d95319
    str x22, [x10, #RTP_AX_TWIN]
1:  mov x0, x19
    mov x1, x22
    mov x2, x21
    bl Lrtp_newaxes
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// ---------------------------------------------------------------------
// Lrtp_style -- parse a style string (2.14.6 "Style and colour", L-ki):
//   left to right `--` or `-.` first, then `-` or `:`, then a marker of
//   `o s d ^ v x + * .`, then a colour letter of `r g b c m y k w`; a
//   second item of a kind or any other byte is invalid. No line part and
//   no marker: line 1.
//   Inputs  : x0 = the style (str)
//   Outputs : x0 = 0 valid, 1 invalid; x1 = line code, x2 = marker code,
//             x3 = colour (0xRRGGBB) or -1
//   Clobbers: x4-x14, flags
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_style:
    ldr x4, [x0, #SEA_STR_LEN]
    add x5, x0, #SEA_STR_BYTES
    mov x6, #0                      // index
    mov x1, #0
    mov x2, #0
    mov x3, #-1
Lrtp_style_loop:
    cmp x6, x4
    b.hs Lrtp_style_end
    ldrb w7, [x5, x6]
    add x6, x6, #1
    cmp w7, #'-'
    b.ne 2f
    mov x8, #1                      // `-`, unless `--` or `-.`
    cmp x6, x4
    b.hs 1f
    ldrb w9, [x5, x6]
    cmp w9, #'-'
    mov x10, #2
    csel x8, x10, x8, eq
    cmp w9, #'.'
    mov x10, #4
    csel x8, x10, x8, eq
    cmp x8, #1
    cinc x6, x6, ne                 // two bytes
1:  cbnz x1, Lrtp_style_bad         // a second line part
    mov x1, x8
    b Lrtp_style_loop
2:  cmp w7, #':'
    b.ne 3f
    cbnz x1, Lrtp_style_bad
    mov x1, #3
    b Lrtp_style_loop
3:  LADR x9, Lrtp_s_markers_set     // a marker?
    mov x10, #0
4:  ldrb w11, [x9, x10]
    cbz w11, 5f
    add x10, x10, #1
    cmp w11, w7
    b.ne 4b
    cbnz x2, Lrtp_style_bad         // a second marker
    mov x2, x10                     // 1 .. 9
    b Lrtp_style_loop
5:  LADR x9, Lrtp_s_letters         // a colour letter?
    mov x10, #0
6:  ldrb w11, [x9, x10]
    cbz w11, Lrtp_style_bad         // any other byte
    cmp w11, w7
    b.eq 7f
    add x10, x10, #1
    b 6b
7:  tbz x3, #63, Lrtp_style_bad     // a second colour letter
    LADR x9, Lrtp_letter_rgb
    ldr w3, [x9, x10, lsl #2]
    b Lrtp_style_loop
Lrtp_style_end:
    orr x9, x1, x2
    cbnz x9, 8f
    mov x1, #1                      // neither: a solid line
8:  mov x0, #0
    ret
Lrtp_style_bad:
    mov x0, #1
    ret

// ---------------------------------------------------------------------
// Lrtp_color -- parse a colour string: "" or `#` and six hex digits of
//   either case.
//   Inputs  : x0 = the colour (str)
//   Outputs : x0 = 0xRRGGBB, -1 for "", -2 when invalid
//   Clobbers: x9-x13, flags
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_color:
    ldr x9, [x0, #SEA_STR_LEN]
    add x10, x0, #SEA_STR_BYTES
    mov x0, #-1
    cbz x9, 9f                      // ""
    mov x0, #-2
    cmp x9, #7
    b.ne 9f
    ldrb w11, [x10]
    cmp w11, #'#'
    b.ne 9f
    mov x12, #0                     // the value
    mov x13, #1
1:  ldrb w11, [x10, x13]
    sub w9, w11, #'0'
    cmp w9, #9
    b.ls 2f                         // 0-9
    orr w11, w11, #0x20             // a-f either case
    sub w9, w11, #'a'
    cmp w9, #5
    b.hi 8f
    add w9, w9, #10
2:  lsl x12, x12, #4
    orr x12, x12, x9
    add x13, x13, #1
    cmp x13, #7
    b.lo 1b
    mov x0, x12
    ret
8:  mov x0, #-2
9:  ret

// ---------------------------------------------------------------------
// Lrtp_resolve -- a series' colour (2.14.6, L-kh): the `color` argument,
//   else the style's letter, else the cycle colour at the axes record's
//   cycle index (mod 7), which then advances by one.
//   Inputs  : x0 = colour argument (>= 0 or -1), x1 = style colour
//             (>= 0 or -1), x2 = the axes record
//   Outputs : x0 = 0xRRGGBB
//   Clobbers: x9-x11, flags
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_resolve:
    tbz x0, #63, 1f                 // the argument
    mov x0, x1
    tbz x0, #63, 1f                 // the style's letter
    ldr x9, [x2, #RTP_AX_CYC]
    mov x10, #7
    udiv x11, x9, x10
    msub x11, x11, x10, x9          // index mod 7
    LADR x10, Lrtp_cycle
    ldr w0, [x10, x11, lsl #2]
    add x9, x9, #1
    str x9, [x2, #RTP_AX_CYC]       // advances only here
1:  ret

// ---------------------------------------------------------------------
// _sea_plot -- the entry PLOT (DESIGN.md 2.14.5): SHAPE_MISMATCH (the
//   two vector shapes), LINE_STYLE, PLOT_WIDTH (not finite or not > 0),
//   COLOR; then a line series with a copy of x and y in one block.
//   Inputs  : x0 = Axes, x1 = x, x2 = y, x3 = style, x4 = label, d0 =
//             width, x5 = color, x6 = site
//   Outputs : none
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = Axes, x20 = x, x21 = y, x22 = style, x23 =
//             label, x24 = color, x25 = site, x26 = line code, x27 =
//             marker code, x28 = colour, d8 = width
//   Frame   : 144 bytes (frame record + x19..x28, d8, pad, four slots
//             at 112)
// ---------------------------------------------------------------------
    .globl _sea_plot
    .p2align 2
_sea_plot:
    stp x29, x30, [sp, #-144]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp x27, x28, [sp, #80]
    str d8, [sp, #96]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, x4
    mov x24, x5
    mov x25, x6
    fmov d8, d0
    // The shapes of x and y.
    ldr x9, [x20, #SEA_ARR_ROWS]
    ldr x10, [x21, #SEA_ARR_ROWS]
    cmp x9, x10
    b.eq 1f
    mov x11, #SEA_SHAPE_VEC
    stp x9, x11, [sp, #112]         // x's shape, then y's
    stp x10, x11, [sp, #128]
    mov w0, #SEA_E_SHAPE_MISMATCH
    b Lrtp_plot_err
    // The style.
1:  mov x0, x22
    bl Lrtp_style
    mov x26, x1
    mov x27, x2
    mov x28, x3
    cbz x0, 2f
    str x22, [sp, #112]
    mov w0, #SEA_E_LINE_STYLE
    b Lrtp_plot_err
    // The width: finite and > 0.
2:  BNF d8, d1, 3f
    fcmp d8, #0.0
    b.gt 4f
3:  str d8, [sp, #112]
    mov w0, #SEA_E_PLOT_WIDTH
    b Lrtp_plot_err
    // The colour.
4:  mov x0, x24
    bl Lrtp_color
    cmn x0, #2
    b.ne 5f
    str x24, [sp, #112]
    mov w0, #SEA_E_COLOR
    b Lrtp_plot_err
5:  str x0, [sp, #128]              // the argument colour
    mov x0, x19
    AXES                            // x1 = its own record (the cycle)
    mov x2, x1
    ldr x0, [sp, #128]
    mov x1, x28                     // the style's colour
    bl Lrtp_resolve
    mov x28, x0                     // the colour
    // The data: x then y, 16 n bytes (none when n = 0).
    ldr x9, [x20, #SEA_ARR_ROWS]
    mov x0, #0
    cbz x9, 7f
    lsl x0, x9, #4
    mov x1, x25
    bl _sea_alloc
    str x0, [sp, #112]              // the block
    ldr x1, [x20, #SEA_ARR_DATA]
    ldr x2, [x20, #SEA_ARR_ROWS]
    lsl x2, x2, #3
    bl _memcpy                      // x
    ldr x0, [sp, #112]
    ldr x2, [x20, #SEA_ARR_ROWS]
    lsl x2, x2, #3
    add x0, x0, x2
    ldr x1, [x21, #SEA_ARR_DATA]
    bl _memcpy                      // y
    ldr x0, [sp, #112]
7:  str x0, [sp, #120]
    // The record.
    mov x0, x19
    AXES
    mov x1, #1
    mov x2, x25
    bl Lrtp_append                  // x0 = record (the series table)
    mov x9, #RTP_K_LINE
    str x9, [x0, #RTP_SR_KIND]
    ldr x9, [x19, #RTP_A_IDX]
    str x9, [x0, #RTP_SR_AX]
    str x28, [x0, #RTP_SR_COLOR]
    str x26, [x0, #RTP_SR_LINE]
    str x27, [x0, #RTP_SR_MARK]
    str d8, [x0, #RTP_SR_WIDTH]
    ldr x9, [x20, #SEA_ARR_ROWS]
    str x9, [x0, #RTP_SR_N]
    ldr x9, [sp, #120]
    str x9, [x0, #RTP_SR_DATA]
    ldr x9, [x23, #SEA_STR_LEN]     // the label, retained unless ""
    cbz x9, 8f
    str x23, [x0, #RTP_SR_LABEL]
    mov x0, x23
    bl _sea_retain
8:  ldr d8, [sp, #96]
    ldp x27, x28, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #144
    ret
Lrtp_plot_err:
    mov x1, x25
    add x2, sp, #112
    bl _sea_err                     // noreturn

// ---------------------------------------------------------------------
// _sea_xline -- the entry XLINE (DESIGN.md 2.14.5): LINE_STYLE (a marker
//   included, L-ki), COLOR; then an xline series (no data block; a
//   non-finite position is not an error, L-kj).
//   Inputs  : x0 = Axes, d0 = x, x1 = style, x2 = color, x3 = site
//   Outputs : none
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = Axes, x20 = style, x21 = color, x22 = site,
//             x23 = line code, x24 = style colour, x25 = colour, d8 = x
//   Frame   : 96 bytes (frame record + x19..x25, d8, one slot at 80)
// ---------------------------------------------------------------------
    .globl _sea_xline
    .p2align 2
_sea_xline:
    stp x29, x30, [sp, #-96]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    str x25, [sp, #64]
    str d8, [sp, #72]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    fmov d8, d0
    mov x0, x20
    bl Lrtp_style
    cbnz x0, 1f
    cbz x2, 2f                      // no marker: valid
1:  str x20, [sp, #80]
    mov w0, #SEA_E_LINE_STYLE
    b 4f
2:  mov x23, x1
    mov x24, x3
    mov x0, x21
    bl Lrtp_color
    cmn x0, #2
    b.ne 3f
    str x21, [sp, #80]
    mov w0, #SEA_E_COLOR
    b 4f
3:  mov x25, x0                     // the argument colour
    mov x0, x19
    AXES                            // x1 = its own record
    mov x2, x1
    mov x0, x25
    mov x1, x24
    bl Lrtp_resolve
    mov x25, x0
    mov x0, x19
    AXES                            // x0 = figure
    mov x1, #1
    mov x2, x22
    bl Lrtp_append
    mov x9, #RTP_K_XLINE
    str x9, [x0, #RTP_SR_KIND]
    ldr x9, [x19, #RTP_A_IDX]
    str x9, [x0, #RTP_SR_AX]
    str x25, [x0, #RTP_SR_COLOR]
    str x23, [x0, #RTP_SR_LINE]
    LDK d0, ONE
    str d0, [x0, #RTP_SR_WIDTH]     // drawn 1.00 wide
    str d8, [x0, #RTP_SR_XPOS]
    ldr d8, [sp, #72]
    ldr x25, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #96
    ret
4:  mov x1, x22
    add x2, sp, #80
    bl _sea_err                     // noreturn

// ---------------------------------------------------------------------
// Lrtp_setstr -- store a string into a field, retaining it and
//   releasing the previous one.
//   Inputs  : x0 = the field's address, x1 = the string
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = field, x20 = string
//   Frame   : 32 bytes (frame record + x19, x20)
// ---------------------------------------------------------------------
    .p2align 2
Lrtp_setstr:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    mov x20, x1
    mov x0, x20
    bl _sea_retain
    ldr x0, [x19]                   // the previous one
    str x20, [x19]
    bl _sea_release
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// ---------------------------------------------------------------------
// _sea_xlabel, _sea_ylabel, _sea_title -- the entries XLABEL (the
//   pair's x label), YLABEL (the y label of the axes' own y-axis), TITLE
//   (the pair's title); cannot fail (DESIGN.md 2.14.5, L-km).
//   Inputs  : x0 = Axes, x1 = s
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Frame   : 16 bytes (frame record)
// ---------------------------------------------------------------------
    .globl _sea_xlabel
    .p2align 2
_sea_xlabel:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x11, x1
    AXES
    add x0, x2, #RTP_AX_XLAB        // the base's
    mov x1, x11
    bl Lrtp_setstr
    ldp x29, x30, [sp], #16
    ret

    .globl _sea_ylabel
    .p2align 2
_sea_ylabel:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x11, x1
    AXES
    add x0, x1, #RTP_AX_YLAB        // its own
    mov x1, x11
    bl Lrtp_setstr
    ldp x29, x30, [sp], #16
    ret

    .globl _sea_title
    .p2align 2
_sea_title:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x11, x1
    AXES
    add x0, x2, #RTP_AX_TITLE       // the base's
    mov x1, x11
    bl Lrtp_setstr
    ldp x29, x30, [sp], #16
    ret

// ---------------------------------------------------------------------
// _sea_legend -- the entry LEGEND: LEGEND_LOC unless loc is one of
//   `north south east west northeast northwest southeast southwest best`
//   (codes 1 .. 8, `best` 5, L-kn); the pair's location.
//   Inputs  : x0 = Axes, x1 = loc, x2 = site
//   Clobbers: x0-x17, flags
//   Callee-saved used: none
//   Frame   : 32 bytes (frame record, one slot at 16)
// ---------------------------------------------------------------------
    .globl _sea_legend
    .p2align 2
_sea_legend:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    ldr x4, [x1, #SEA_STR_LEN]
    add x5, x1, #SEA_STR_BYTES
    LADR x6, Lrtp_locs              // (name, code) pairs, 0-terminated
1:  ldr x7, [x6], #16
    cbz x7, 5f                      // no match
    mov x8, #0
2:  ldrb w9, [x7, x8]               // compare: same bytes, same length
    cmp x8, x4
    b.eq 3f
    cbz w9, 1b
    ldrb w10, [x5, x8]
    cmp w9, w10
    b.ne 1b
    add x8, x8, #1
    b 2b
3:  cbnz w9, 1b                     // the name is longer
    ldur x8, [x6, #-8]              // its code
    AXES                            // x2 = the base
    str x8, [x2, #RTP_AX_LEG]
    ldp x29, x30, [sp], #32
    ret
5:  str x1, [sp, #16]
    mov w0, #SEA_E_LEGEND_LOC
    mov x1, x2
    add x2, sp, #16
    bl _sea_err                     // noreturn

// ---------------------------------------------------------------------
// _sea_grid -- the entry GRID: the pair's grid switch (on 0 or 1).
//   Inputs  : x0 = Axes, x1 = on
//   Clobbers: x0-x3, x9-x11, flags
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .globl _sea_grid
    .p2align 2
_sea_grid:
    mov x11, x1
    AXES
    ldr x9, [x2, #RTP_AX_FLAGS]
    bic x9, x9, #(1 << RTP_FL_GRID)
    cmp x11, #0
    cset x10, ne
    orr x9, x9, x10, lsl #RTP_FL_GRID
    str x9, [x2, #RTP_AX_FLAGS]
    ret

// ---------------------------------------------------------------------
// _sea_xlim, _sea_ylim -- the entries XLIM (the pair's x limits) and
//   YLIM (the axes' own y limits): AXIS_LIMITS (lo, hi) unless both are
//   finite and lo < hi.
//   Inputs  : x0 = Axes, d0 = lo, d1 = hi, x1 = site
//   Clobbers: x0-x17, d2, flags
//   Frame   : 32 bytes (frame record, two slots at 16)
// ---------------------------------------------------------------------
    .globl _sea_xlim
    .p2align 2
_sea_xlim:
    mov x13, #0                     // x: the base's fields
    b Lrtp_lim
    .globl _sea_ylim
    .p2align 2
_sea_ylim:
    mov x13, #1                     // y: its own fields
Lrtp_lim:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    mov x14, x1
    BNF d0, d2, 2f
    BNF d1, d2, 2f
    fcmp d0, d1
    b.pl 2f                         // not lo < hi
    AXES
    cbnz x13, 1f
    str d0, [x2, #RTP_AX_XLO]
    str d1, [x2, #RTP_AX_XHI]
    ldr x9, [x2, #RTP_AX_FLAGS]
    orr x9, x9, #(1 << RTP_FL_XLIM)
    str x9, [x2, #RTP_AX_FLAGS]
    ldp x29, x30, [sp], #32
    ret
1:  str d0, [x1, #RTP_AX_YLO]
    str d1, [x1, #RTP_AX_YHI]
    ldr x9, [x1, #RTP_AX_FLAGS]
    orr x9, x9, #(1 << RTP_FL_YLIM)
    str x9, [x1, #RTP_AX_FLAGS]
    ldp x29, x30, [sp], #32
    ret
2:  str d0, [sp, #16]
    str d1, [sp, #24]
    mov w0, #SEA_E_AXIS_LIMITS
    mov x1, x14
    add x2, sp, #16
    bl _sea_err                     // noreturn

// ---------------------------------------------------------------------
// _sea_x_ticks, _sea_y_ticks -- the entries X_TICKS (the pair's x
//   category labels) and Y_TICKS (the axes' own y labels): a new block
//   of the n string pointers, each retained (none for n = 0), then the
//   previous labels released and their block freed.
//   Inputs  : x0 = Axes, x1 = labels (a str vector), x2 = site
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = the field (block; count at +8), x20 =
//             labels, x21 = n, x22 = new block, x23 = cursor, x24 = left
//   Frame   : 64 bytes (frame record + x19..x24)
// ---------------------------------------------------------------------
    .globl _sea_x_ticks
    .p2align 2
_sea_x_ticks:
    mov x13, #0
    b Lrtp_cats
    .globl _sea_y_ticks
    .p2align 2
_sea_y_ticks:
    mov x13, #1
Lrtp_cats:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x20, x1
    mov x14, x2
    AXES
    add x19, x2, #RTP_AX_XCAT       // x: the base's
    cbz x13, 1f
    add x19, x1, #RTP_AX_YCAT       // y: its own
1:  ldr x9, [x20, #SEA_ARR_ROWS]
    ldr x10, [x20, #SEA_ARR_COLS]
    mul x21, x9, x10
    mov x22, #0
    cbz x21, 3f
    lsl x0, x21, #3
    mov x1, x14
    bl _sea_alloc
    mov x22, x0
    ldr x23, [x20, #SEA_ARR_DATA]
    mov x24, #0
2:  ldr x0, [x23, x24, lsl #3]      // copy and retain each label
    str x0, [x22, x24, lsl #3]
    bl _sea_retain
    add x24, x24, #1
    cmp x24, x21
    b.lo 2b
3:  ldr x23, [x19]                  // the previous block and count
    ldr x24, [x19, #8]
    str x22, [x19]
    str x21, [x19, #8]
    cbz x23, 5f
    mov x21, x24                    // its size: 8 x its count
    mov x22, x23
4:  cbz x24, 41f
    ldr x0, [x22], #8
    bl _sea_release
    sub x24, x24, #1
    b 4b
41: mov x0, x23
    lsl x1, x21, #3
    bl _sea_free_block
5:  ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// ---------------------------------------------------------------------
// _sea_y_reverse, _sea_axis_equal -- the entries Y_REVERSE (the axes'
//   own y-axis runs downward) and AXIS_EQUAL (the pair's base axes get
//   equal data units); switches that stay on; cannot fail.
//   Inputs  : x0 = Axes
//   Clobbers: x0-x3, x9, x10, flags
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .globl _sea_y_reverse
    .p2align 2
_sea_y_reverse:
    AXES
    ldr x9, [x1, #RTP_AX_FLAGS]     // its own record
    orr x9, x9, #(1 << RTP_FL_YREV)
    str x9, [x1, #RTP_AX_FLAGS]
    ret

    .globl _sea_axis_equal
    .p2align 2
_sea_axis_equal:
    AXES
    ldr x9, [x2, #RTP_AX_FLAGS]     // the base's record
    orr x9, x9, #(1 << RTP_FL_EQUAL)
    str x9, [x2, #RTP_AX_FLAGS]
    ret

// =====================================================================
// Tables and literals (DESIGN.md 2.14.6)
// =====================================================================
    .section __TEXT,__const
    .p2align 2
// The colour cycle (LANGUAGE.md 12.3), index mod 7.
Lrtp_cycle:
    .long 0x0072bd, 0xd95319, 0xedb120, 0x7e2f8e, 0x77ac30, 0x4dbeee, 0xa2142f
// The colours of the letters of Lrtp_s_letters, in that order.
Lrtp_letter_rgb:
    .long 0xff0000, 0x00a000, 0x0000ff, 0x00bfbf, 0xbf00bf, 0xbfbf00, 0x000000, 0xffffff

// The markers (codes 1 .. 9): items of (dx, dy, suffix), ended by a 0
// suffix; each item is `M{X+dx} {Y+dy}` and its suffix.
    .section __DATA,__const
    .p2align 3
Lrtp_mk:
    .quad Lrtp_mk_o, Lrtp_mk_s, Lrtp_mk_d, Lrtp_mk_up, Lrtp_mk_dn
    .quad Lrtp_mk_x, Lrtp_mk_plus, Lrtp_mk_star, Lrtp_mk_dot
Lrtp_mk_o:
    .double -3.0, 0.0
    .quad Lrtp_s_mo
    .double 0.0, 0.0
    .quad 0
Lrtp_mk_s:
    .double -3.0, -3.0
    .quad Lrtp_s_ms
    .double 0.0, 0.0
    .quad 0
Lrtp_mk_d:
    .double 0.0, -3.0
    .quad Lrtp_s_md
    .double 0.0, 0.0
    .quad 0
Lrtp_mk_up:
    .double 0.0, -3.0
    .quad Lrtp_s_mup
    .double 0.0, 0.0
    .quad 0
Lrtp_mk_dn:
    .double 0.0, 3.0
    .quad Lrtp_s_mdn
    .double 0.0, 0.0
    .quad 0
Lrtp_mk_x:
    .double -3.0, -3.0
    .quad Lrtp_s_mx1
    .double -3.0, 3.0
    .quad Lrtp_s_mx2
    .double 0.0, 0.0
    .quad 0
Lrtp_mk_plus:
    .double -3.0, 0.0
    .quad Lrtp_s_mp1
    .double 0.0, -3.0
    .quad Lrtp_s_mp2
    .double 0.0, 0.0
    .quad 0
Lrtp_mk_star:
    .double -3.0, 0.0
    .quad Lrtp_s_mp1
    .double 0.0, -3.0
    .quad Lrtp_s_mp2s
    .double -3.0, -3.0
    .quad Lrtp_s_mx1
    .double -3.0, 3.0
    .quad Lrtp_s_mx2
    .double 0.0, 0.0
    .quad 0
Lrtp_mk_dot:
    .double -1.0, 0.0
    .quad Lrtp_s_mdot
    .double 0.0, 0.0
    .quad 0
// The legend locations (L-kn): name, code; ended by 0.
Lrtp_locs:
    .quad Lrtp_s_north, 1, Lrtp_s_south, 2, Lrtp_s_east, 3, Lrtp_s_west, 4
    .quad Lrtp_s_northeast, 5, Lrtp_s_northwest, 6, Lrtp_s_southeast, 7
    .quad Lrtp_s_southwest, 8, Lrtp_s_best, 5, 0, 0

    .section __TEXT,__cstring,cstring_literals
Lrtp_s_hex:         .asciz "0123456789abcdef"
Lrtp_s_markers_set: .asciz "osd^vx+*."
Lrtp_s_letters:     .asciz "rgbcmykw"
Lrtp_s_north:       .asciz "north"
Lrtp_s_south:       .asciz "south"
Lrtp_s_east:        .asciz "east"
Lrtp_s_west:        .asciz "west"
Lrtp_s_northeast:   .asciz "northeast"
Lrtp_s_northwest:   .asciz "northwest"
Lrtp_s_southeast:   .asciz "southeast"
Lrtp_s_southwest:   .asciz "southwest"
Lrtp_s_best:        .asciz "best"
Lrtp_s_amp:         .asciz "&amp;"
Lrtp_s_lt:          .asciz "&lt;"
Lrtp_s_gt:          .asciz "&gt;"
Lrtp_s_quot:        .asciz "&quot;"
Lrtp_s_sp:          .asciz " "
Lrtp_s_space:       .asciz " "
Lrtp_s_qy:          .asciz "\" y=\""
Lrtp_s_qw:          .asciz "\" width=\""
Lrtp_s_qh:          .asciz "\" height=\""
Lrtp_s_etext:       .asciz "</text>\n"
Lrtp_s_eg:          .asciz "</g>\n"
Lrtp_s_eclose:      .asciz "/>\n"
Lrtp_s_qclose:      .asciz "\"/>\n"
Lrtp_s_dash2:       .asciz " stroke-dasharray=\"6 4\""
Lrtp_s_dash3:       .asciz " stroke-dasharray=\"2 3\""
Lrtp_s_dash4:       .asciz " stroke-dasharray=\"6 3 2 3\""
Lrtp_s_xml:         .asciz "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
Lrtp_s_svg:         .asciz "<svg xmlns=\"http://www.w3.org/2000/svg\" class=\"sea-figure\" width=\""
Lrtp_s_qheight:     .asciz "\" height=\""
Lrtp_s_viewbox:     .asciz "\" viewBox=\"0 0 "
Lrtp_s_svgend:      .asciz "\" font-family=\"sans-serif\">\n"
Lrtp_s_canvas:      .asciz "<rect class=\"canvas\" x=\"0\" y=\"0\" width=\""
Lrtp_s_fillwhite:   .asciz "\" fill=\"#ffffff\"/>\n"
Lrtp_s_heading:     .asciz "<text class=\"heading\" x=\""
Lrtp_s_headingend:  .asciz "\" y=\"17.00\" font-size=\"14\" text-anchor=\"middle\">"
Lrtp_s_esvg:        .asciz "</svg>\n"
Lrtp_s_gpanel:      .asciz "<g class=\"panel\" id=\"p"
Lrtp_s_qgt:         .asciz "\">\n"
Lrtp_s_clip:        .asciz "<clipPath id=\"c"
Lrtp_s_qgt0:        .asciz "\">"
Lrtp_s_cliprect:    .asciz "<rect x=\""
Lrtp_s_clipend:     .asciz "\"/></clipPath>\n"
Lrtp_s_plotarea:    .asciz "<rect class=\"plot-area\" x=\""
Lrtp_s_grid:        .asciz "<path class=\"grid\" d=\""
Lrtp_s_gridend:     .asciz "\" fill=\"none\" stroke=\"#dfdfdf\" stroke-width=\"0.50\"/>\n"
Lrtp_s_sv:          .asciz " V"
Lrtp_s_sh:          .asciz " H"
Lrtp_s_sl:          .asciz " L"
Lrtp_s_gdata:       .asciz "<g class=\"data\" clip-path=\"url(#c"
Lrtp_s_dataend:     .asciz ")\">\n"
Lrtp_s_axesbox:     .asciz "<rect class=\"axes-box\" x=\""
Lrtp_s_boxend:      .asciz "\" fill=\"none\" stroke=\"#262626\" stroke-width=\"1.00\"/>\n"
Lrtp_s_tickmarks:   .asciz "<path class=\"tick-marks\" d=\""
Lrtp_s_vm5:         .asciz " v-5.00"
Lrtp_s_h5:          .asciz " h5.00"
Lrtp_s_hm5:         .asciz " h-5.00"
Lrtp_s_xtick:       .asciz "<text class=\"xtick\" x=\""
Lrtp_s_xtickend:    .asciz "\" font-size=\"10\" text-anchor=\"middle\">"
Lrtp_s_ytick:       .asciz "<text class=\"ytick\" x=\""
Lrtp_s_ytickend:    .asciz "\" font-size=\"10\" text-anchor=\"end\">"
Lrtp_s_ytick2:      .asciz "<text class=\"ytick2\" x=\""
Lrtp_s_ytick2end:   .asciz "\" font-size=\"10\" text-anchor=\"start\">"
Lrtp_s_xlabel:      .asciz "<text class=\"xlabel\" x=\""
Lrtp_s_lab12:       .asciz "\" font-size=\"12\" text-anchor=\"middle\">"
Lrtp_s_ylabel:      .asciz "<text class=\"ylabel\" font-size=\"12\" text-anchor=\"middle\" transform=\"translate("
Lrtp_s_rotm90:      .asciz ") rotate(-90)\">"
Lrtp_s_ylabel2:     .asciz "<text class=\"ylabel2\" font-size=\"12\" text-anchor=\"middle\" transform=\"translate("
Lrtp_s_rot90:       .asciz ") rotate(90)\">"
Lrtp_s_title:       .asciz "<text class=\"title\" x=\""
Lrtp_s_lab14:       .asciz "\" font-size=\"14\" text-anchor=\"middle\">"
Lrtp_s_line:        .asciz "<path class=\"line\" d=\""
Lrtp_s_fnstroke:    .asciz "\" fill=\"none\" stroke=\""
Lrtp_s_qsw:         .asciz "\" stroke-width=\""
Lrtp_s_qsw1q:       .asciz "\" stroke-width=\"1.00\""
Lrtp_s_markers:     .asciz "<path class=\"markers\" d=\""
Lrtp_s_qfill:       .asciz "\" fill=\""
Lrtp_s_none:        .asciz "none"
Lrtp_s_qstroke:     .asciz "\" stroke=\""
Lrtp_s_sw1close:    .asciz "\" stroke-width=\"1.00\"/>\n"
Lrtp_s_xline:       .asciz "<path class=\"xline\" d=\""
Lrtp_s_glegend:     .asciz "<g class=\"legend\">\n"
Lrtp_s_legbox:      .asciz "<rect class=\"legend-box\" x=\""
Lrtp_s_legboxend:   .asciz "\" fill=\"#ffffff\" stroke=\"#262626\" stroke-width=\"0.50\"/>\n"
Lrtp_s_legline:     .asciz "<path class=\"legend-line\" d=\"M"
Lrtp_s_legmarker:   .asciz "<path class=\"legend-marker\" d=\""
Lrtp_s_legbar:      .asciz "<rect class=\"legend-bar\" x=\""
Lrtp_s_legbarend:   .asciz "\" width=\"12.00\" height=\"8.00\" fill=\""
Lrtp_s_leglabel:    .asciz "<text class=\"legend-label\" x=\""
Lrtp_s_leglabelend: .asciz "\" font-size=\"12\">"
Lrtp_s_mo:          .asciz " a3.00 3.00 0 1 0 6.00 0.00 a3.00 3.00 0 1 0 -6.00 0.00"
Lrtp_s_ms:          .asciz " h6.00 v6.00 h-6.00 z"
Lrtp_s_md:          .asciz " l3.00 3.00 l-3.00 3.00 l-3.00 -3.00 z"
Lrtp_s_mup:         .asciz " l3.00 6.00 h-6.00 z"
Lrtp_s_mdn:         .asciz " l3.00 -6.00 h-6.00 z"
Lrtp_s_mx1:         .asciz " l6.00 6.00 "
Lrtp_s_mx2:         .asciz " l6.00 -6.00"
Lrtp_s_mp1:         .asciz " h6.00 "
Lrtp_s_mp2:         .asciz " v6.00"
Lrtp_s_mp2s:        .asciz " v6.00 "
Lrtp_s_mdot:        .asciz " a1.00 1.00 0 1 0 2.00 0.00 a1.00 1.00 0 1 0 -2.00 0.00"

// ---------------------------------------------------------------------
// State: the writer's state block (RS_*).
// ---------------------------------------------------------------------
.zerofill __DATA,__bss,Lrtp_st,RS_SIZE,4
