// =====================================================================
// sea/runtime/arm64_macos/rt_plot2.s -- the plotting library's bars,
// contours and images: the entries of sub-phase 9c, their element
// writers, marching squares, the colour map and the colorbar
// (LANGUAGE.md 12.3, 12.6; DESIGN.md 2.14.5, 2.14.6 "Bars", "Images",
// "The colour map", "Contour levels and marching squares", item 9;
// lead decisions L-kq .. L-kt, L-ko).
//
// Defines (global, rt.inc SEA_ENTRY_LIST):
//   _sea_bar      (ax, x, h, d0 = width, label, color, site)
//   _sea_barh     (ax, h, d0 = width, label, color, site)
//   _sea_contour  (ax, x, y, Z, levels, labels, color, site)
//   _sea_image    (ax, x, y, Z, colorbar, site)
// Defines (private, .private_extern), called by rt_plot.s's writer with
// x28 = its state block:
//   _sea_plot2_extent    (rec, its y-axis): the extents of series kinds 3 .. 6
//   _sea_plot2_cbar      (): the pair's colorbar image into RS_CBAR
//   _sea_plot2_series    (rec): the element of a series of kind 3 .. 6
//   _sea_plot2_colorbar  (): item 9, the colorbar of RS_CBAR
//   _sea_plot_cmap       (e) -> w0 = colour-map entry e as 0xRRGGBB
// Uses: rt_plot.s's private writer routines (_sea_plot_*), _sea_png,
//       _sea_b64 (rt_png.s), _sea_alloc, _sea_free_block, _sea_retain
//       (rt_mem.s), _sea_err (rt_err.s), _sea_fmt_num (rt_fmt.s),
//       memcpy (libSystem).
//
// SERIES RECORDS (2.14.6 "Objects"): kind 3 (bar: data x then h, 16 n
// bytes), 4 (barh: h, 8 n bytes), 5 (contour) and 6 (image), both x, y,
// then Z column-major, 8 (n + m + n m) bytes, n = len(x), m = len(y);
// a block of size 0 is not allocated. A contour stores its colour or -1
// ("the colour map per level", Decision 132), its levels and labels; an
// image its colorbar flag.
//
// THE WRITER: the routines below run inside SAVE_SVG with x28 = rt_plot.s's
// state block (the RS_* offsets, the same as rt_plot.s's) and append to
// its buffer through _sea_plot_bput and the other writer routines; every
// coordinate is mapped and clamped by _sea_plot_mapx and _sea_plot_mapy
// before any use (L-kl).
//
// ABI: AAPCS64; every entry preserves x19-x28, x29, sp, d8-d15 and FPCR
// (never written). Every own frame is at most 128 bytes (2.14.5: at most
// 512); no routine recurses.
// =====================================================================
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

// ---- the layouts of rt_plot.s (DESIGN.md 2.14.6 "Objects"; L-kw) -------
.equ RTP_F_AXT,     72              /* ptr  the axes table */
.equ RTP_F_NSR,     80              /* u64  series records */
.equ RTP_F_SRT,     96              /* ptr  the series table */
.equ RTP_A_FIG,     16              /* ptr  an Axes' figure */
.equ RTP_A_IDX,     24              /* u64  its axes record index */
.equ RTP_AX_BASE,   8               /* the base's index */
.equ RTP_SR_SIZE,   128             /* a series record */
.equ RTP_SR_KIND,   0               /* 3 bar, 4 barh, 5 contour, 6 image */
.equ RTP_SR_AX,     8               /* the axes record's index */
.equ RTP_SR_COLOR,  16              /* 0xRRGGBB, or -1: the colour map per level */
.equ RTP_SR_WIDTH,  40              /* f64  the bar width in units */
.equ RTP_SR_LABEL,  48              /* str, or 0 for "" */
.equ RTP_SR_N,      56
.equ RTP_SR_M,      64
.equ RTP_SR_DATA,   72              /* the data block, or 0 */
.equ RTP_SR_LEVELS, 80
.equ RTP_SR_FLAG,   88              /* labels (contour) or colorbar (image) */
.equ RTP_K_BAR,     3
.equ RTP_K_BARH,    4
.equ RTP_K_CONTOUR, 5
.equ RTP_K_IMAGE,   6
// ---- rt_plot.s's writer state (its RS_* and AS_* offsets) -----------------
.equ AS_LO,         0
.equ AS_HI,         8
.equ AS_MODE,       16
.equ AS_NT,         24
.equ AS_REV,        64
.equ AS_CAT,        72
.equ AS_NCAT,       80
.equ AS_EXT,        88
.equ AS_ELO,        96
.equ AS_EHI,        104
.equ AS_SIZE,       176
.equ RS_BPTR,       0
.equ RS_BLEN,       8
.equ RS_BCAP,       16
.equ RS_SITE,       24
.equ RS_FIG,        32
.equ RS_TWIN,       48
.equ RS_BIDX,       56
.equ RS_TIDX,       64
.equ RS_PX,         72
.equ RS_PY,         80
.equ RS_PW,         88
.equ RS_PH,         96
.equ RS_FIRST,      104
.equ RS_CBAR,       120             /* the pair's colorbar image record, or 0 */
.equ RS_AX,         128
.equ RS_AY,         (RS_AX + AS_SIZE)
.equ RS_AT,         (RS_AY + AS_SIZE)
.equ RS_NUM,        (RS_AT + AS_SIZE)
.equ RTP_NUMBUF,    336
.equ RS_T0,         (RS_NUM + RTP_NUMBUF)
// ---- this file's own state ---------------------------------------------
// The contour cell (Lrp2_cs): the four corners a, b, c, d (index 0 .. 3)
// with their values and coordinates, the level and the scan's mode.
.equ CS_Z,          0               /* f64[4] corner values */
.equ CS_X,          32              /* f64[4] corner x */
.equ CS_Y,          64              /* f64[4] corner y */
.equ CS_L,          96              /* f64  the level */
.equ CS_AXIS,       104             /* the series' y-axis (AS_*) */
.equ CS_MODE,       112             /* 0 write the segments, 1 find the first */
.equ CS_OPEN,       120             /* 1 once the level's group is open */
.equ CS_COLOR,      128             /* the level's colour */
.equ CS_SIZE,       136
.equ RP2_CMAP_N,    256             /* colour-map entries */
.equ RP2_WHITE,     0xffffff        /* a NaN image cell */

// ---- helpers ------------------------------------------------------------
// The address of a label.
.macro LADR reg, label
    adrp \reg, \label@PAGE
    add \reg, \reg, \label@PAGEOFF
.endm
// Load an f64 constant of the table Lrp2_k (clobbers x16).
.macro LDK dreg, name
    adrp x16, Lrp2_k@PAGE
    add x16, x16, Lrp2_k@PAGEOFF
    ldr \dreg, [x16, #K_\name]
.endm
// Append a NUL-terminated literal to the SVG buffer.
.macro PUTC label
    LADR x0, \label
    bl _sea_plot_bcstr
.endm
// Append an f64 register as `%.2f`.
.macro F2 dreg
    fmov d0, \dreg
    bl _sea_plot_f2
.endm
// Branch to label when the f64 in dreg is NaN or infinite (tmp scratch).
.macro BNF dreg, tmp, label
    fsub \tmp, \dreg, \dreg
    fcmp \tmp, \tmp
    b.vs \label
.endm
// An Axes handle's figure and records: x0 = the Axes in; out x0 = its
// figure, x1 = its own axes record, x3 = its own index (clobbers x9, x10).
.macro AXES
    ldr x3, [x0, #RTP_A_IDX]
    ldr x0, [x0, #RTP_A_FIG]
    ldr x9, [x0, #RTP_F_AXT]
    add x1, x9, x3, lsl #8          /* its own record (256 bytes each) */
.endm

// ---- the f64 constants (index * 8) ---------------------------------------
.macro KDEF name, idx, val
.equ K_\name, ((\idx) * 8)
    .double \val
.endm
    .section __TEXT,__const
    .p2align 3
Lrp2_k:
    KDEF ONE, 0, 1.0
    KDEF HALF, 1, 0.5
    KDEF TWO, 2, 2.0
    KDEF F12, 3, 12.0               /* the colorbar's offset and width */
    KDEF F16, 4, 16.0               /* its tick labels' offset */
    KDEF F52, 5, 52.0               /* its shift with a twin */
    KDEF F256, 6, 256.0
    KDEF F255, 7, 255.0
    KDEF FOUR, 8, 4.0
// The anchors of the colour map (LANGUAGE.md 12.6): A0 .. A4, each red,
// green, blue as f64.
Lrp2_anchors:
    .double 48.0, 18.0, 59.0        /* #30123b */
    .double 70.0, 134.0, 251.0      /* #4686fb */
    .double 26.0, 228.0, 182.0      /* #1ae4b6 */
    .double 250.0, 186.0, 57.0      /* #faba39 */
    .double 122.0, 4.0, 3.0         /* #7a0403 */

    .section __TEXT,__text,regular,pure_instructions

// =====================================================================
// The entries (DESIGN.md 2.14.5): checks in parameter order, then a
// series record with copies of the data
// =====================================================================

// ---------------------------------------------------------------------
// _sea_bar -- the entry BAR: SHAPE_MISMATCH (x's, h's shape), PLOT_WIDTH
//   (not finite or not > 0), COLOR; a bar series (kind 3) with a copy of
//   x then h, its colour the argument or the cycle colour (L-kh).
//   Inputs  : x0 = Axes, x1 = x, x2 = h, d0 = width, x3 = label, x4 =
//             color, x5 = site
//   Outputs : none
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = Axes, x20 = x, x21 = h, x22 = label, x23 =
//             color, x24 = site, x25 = colour, x26 = data block, d8 = width
//   Frame   : 128 bytes (frame record + x19..x26, d8, pad, four slots at 96)
// ---------------------------------------------------------------------
    .globl _sea_bar
    .p2align 2
_sea_bar:
    stp x29, x30, [sp, #-128]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    str d8, [sp, #80]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, x4
    mov x24, x5
    fmov d8, d0
    // The shapes of x and h.
    ldr x9, [x20, #SEA_ARR_ROWS]
    ldr x10, [x21, #SEA_ARR_ROWS]
    cmp x9, x10
    b.eq 1f
    mov x11, #SEA_SHAPE_VEC
    stp x9, x11, [sp, #96]          // x's shape, then h's
    stp x10, x11, [sp, #112]
    mov w0, #SEA_E_SHAPE_MISMATCH
    b Lrp2_bar_err
    // The width, then the colour.
1:  mov x0, x23
    bl Lrp2_wcol                    // x0 = 0 ok (x1 colour arg), 1 width, 2 colour
    cbz x0, 2f
    cmp x0, #1
    b.ne 11f
    str d8, [sp, #96]
    mov w0, #SEA_E_PLOT_WIDTH
    b Lrp2_bar_err
11: str x23, [sp, #96]
    mov w0, #SEA_E_COLOR
    b Lrp2_bar_err
2:  mov x25, x1                     // the argument colour
    mov x0, x19
    AXES                            // x1 = its own record (the cycle)
    mov x2, x1
    mov x0, x25
    mov x1, #-1                     // no style letter
    bl _sea_plot_resolve
    mov x25, x0
    // The data: x then h, 16 n bytes (none when n = 0).
    mov x26, #0
    ldr x9, [x20, #SEA_ARR_ROWS]
    cbz x9, 3f
    lsl x0, x9, #4
    mov x1, x24
    bl _sea_alloc
    mov x26, x0
    ldr x1, [x20, #SEA_ARR_DATA]
    ldr x2, [x20, #SEA_ARR_ROWS]
    lsl x2, x2, #3
    bl _memcpy                      // x
    ldr x2, [x20, #SEA_ARR_ROWS]
    lsl x2, x2, #3
    add x0, x26, x2
    ldr x1, [x21, #SEA_ARR_DATA]
    bl _memcpy                      // h
    // The record.
3:  mov x0, x19
    mov x1, #RTP_K_BAR
    mov x2, x24
    bl Lrp2_record                  // x0 = record
    str x25, [x0, #RTP_SR_COLOR]
    str d8, [x0, #RTP_SR_WIDTH]
    ldr x9, [x20, #SEA_ARR_ROWS]
    str x9, [x0, #RTP_SR_N]
    str x26, [x0, #RTP_SR_DATA]
    mov x1, x22
    bl Lrp2_label
    ldr d8, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #128
    ret
Lrp2_bar_err:
    mov x1, x24
    add x2, sp, #96
    bl _sea_err                     // noreturn

// ---------------------------------------------------------------------
// _sea_barh -- the entry BARH: PLOT_WIDTH, COLOR; a horizontal bar
//   series (kind 4) with a copy of h, its colour as BAR's.
//   Inputs  : x0 = Axes, x1 = h, d0 = width, x2 = label, x3 = color,
//             x4 = site
//   Outputs : none
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = Axes, x20 = h, x21 = label, x22 = color,
//             x23 = site, x24 = colour, x25 = data block, d8 = width
//   Frame   : 96 bytes (frame record + x19..x25, d8, one slot at 80)
// ---------------------------------------------------------------------
    .globl _sea_barh
    .p2align 2
_sea_barh:
    stp x29, x30, [sp, #-96]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, xzr, [sp, #64]
    str d8, [sp, #72]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, x4
    fmov d8, d0
    // The width, then the colour.
    mov x0, x22
    bl Lrp2_wcol
    cbz x0, 2f
    cmp x0, #1
    b.ne 1f
    str d8, [sp, #80]
    mov w0, #SEA_E_PLOT_WIDTH
    b Lrp2_barh_err
1:  str x22, [sp, #80]
    mov w0, #SEA_E_COLOR
    b Lrp2_barh_err
2:  mov x24, x1
    mov x0, x19
    AXES
    mov x2, x1
    mov x0, x24
    mov x1, #-1
    bl _sea_plot_resolve
    mov x24, x0
    // The data: h, 8 n bytes (none when n = 0).
    mov x25, #0
    ldr x9, [x20, #SEA_ARR_ROWS]
    cbz x9, 3f
    lsl x0, x9, #3
    mov x1, x23
    bl _sea_alloc
    mov x25, x0
    ldr x1, [x20, #SEA_ARR_DATA]
    ldr x2, [x20, #SEA_ARR_ROWS]
    lsl x2, x2, #3
    bl _memcpy
3:  mov x0, x19
    mov x1, #RTP_K_BARH
    mov x2, x23
    bl Lrp2_record
    str x24, [x0, #RTP_SR_COLOR]
    str d8, [x0, #RTP_SR_WIDTH]
    ldr x9, [x20, #SEA_ARR_ROWS]
    str x9, [x0, #RTP_SR_N]
    str x25, [x0, #RTP_SR_DATA]
    mov x1, x21
    bl Lrp2_label
    ldr d8, [sp, #72]
    ldr x25, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #96
    ret
Lrp2_barh_err:
    mov x1, x23
    add x2, sp, #80
    bl _sea_err                     // noreturn

// ---------------------------------------------------------------------
// _sea_contour -- the entry CONTOUR: SHAPE_EXPECTED (len(y) x len(x),
//   Z's shape), CONTOUR_LEVELS (levels < 1), COLOR; a contour series
//   (kind 5) with copies of x, y, Z; its colour the argument, or -1 for
//   "" (the colour map per level; the cycle does not advance, Decision
//   132 (a)).
//   Inputs  : x0 = Axes, x1 = x, x2 = y, x3 = Z, x4 = levels, x5 =
//             labels (0/1), x6 = color, x7 = site
//   Outputs : none
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = Axes, x20 = x, x21 = y, x22 = Z, x23 =
//             levels, x24 = labels, x25 = color, x26 = site, x27 = colour
//             (then the data block)
//   Frame   : 128 bytes (frame record + x19..x27, pad, four slots at 96)
// ---------------------------------------------------------------------
    .globl _sea_contour
    .p2align 2
_sea_contour:
    stp x29, x30, [sp, #-128]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    str x27, [sp, #80]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, x4
    mov x24, x5
    mov x25, x6
    mov x26, x7
    // The shape of Z: len(y) x len(x).
    mov x0, x20
    mov x1, x21
    mov x2, x22
    add x3, sp, #96
    bl Lrp2_zshape
    cbz x0, 1f
    mov w0, #SEA_E_SHAPE_EXPECTED
    b Lrp2_con_err
    // The levels.
1:  cmp x23, #1
    b.ge 2f
    str x23, [sp, #96]
    mov w0, #SEA_E_CONTOUR_LEVELS
    b Lrp2_con_err
    // The colour: kept as given, -1 for "".
2:  mov x0, x25
    bl _sea_plot_color
    cmn x0, #2
    b.ne 3f
    str x25, [sp, #96]
    mov w0, #SEA_E_COLOR
    b Lrp2_con_err
3:  mov x27, x0
    mov x0, x20
    mov x1, x21
    mov x2, x22
    mov x3, x26
    bl Lrp2_copy3                   // x0 = the data block or 0
    str x0, [sp, #104]
    mov x0, x19
    mov x1, #RTP_K_CONTOUR
    mov x2, x26
    bl Lrp2_record
    str x27, [x0, #RTP_SR_COLOR]
    ldr x9, [x20, #SEA_ARR_ROWS]
    str x9, [x0, #RTP_SR_N]
    ldr x9, [x21, #SEA_ARR_ROWS]
    str x9, [x0, #RTP_SR_M]
    ldr x9, [sp, #104]
    str x9, [x0, #RTP_SR_DATA]
    str x23, [x0, #RTP_SR_LEVELS]
    str x24, [x0, #RTP_SR_FLAG]
    ldr x27, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #128
    ret
Lrp2_con_err:
    mov x1, x26
    add x2, sp, #96
    bl _sea_err                     // noreturn

// ---------------------------------------------------------------------
// _sea_image -- the entry IMAGE: SHAPE_EXPECTED; an image series (kind
//   6) with copies of x, y, Z and the colorbar flag (no colour).
//   Inputs  : x0 = Axes, x1 = x, x2 = y, x3 = Z, x4 = colorbar (0/1),
//             x5 = site
//   Outputs : none
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = Axes, x20 = x, x21 = y, x22 = Z, x23 =
//             colorbar, x24 = site
//   Frame   : 96 bytes (frame record + x19..x24, four slots at 64; the
//             data block kept at 88 once the checks have passed)
// ---------------------------------------------------------------------
    .globl _sea_image
    .p2align 2
_sea_image:
    stp x29, x30, [sp, #-96]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, x4
    mov x24, x5
    mov x0, x20
    mov x1, x21
    mov x2, x22
    add x3, sp, #64
    bl Lrp2_zshape
    cbz x0, 1f
    mov w0, #SEA_E_SHAPE_EXPECTED
    mov x1, x24
    add x2, sp, #64
    bl _sea_err                     // noreturn
1:  mov x0, x20
    mov x1, x21
    mov x2, x22
    mov x3, x24
    bl Lrp2_copy3
    mov x9, x0
    str x9, [sp, #88]               // the block (x25 is not saved here)
    mov x0, x19
    mov x1, #RTP_K_IMAGE
    mov x2, x24
    bl Lrp2_record
    ldr x9, [x20, #SEA_ARR_ROWS]
    str x9, [x0, #RTP_SR_N]
    ldr x9, [x21, #SEA_ARR_ROWS]
    str x9, [x0, #RTP_SR_M]
    ldr x9, [sp, #88]
    str x9, [x0, #RTP_SR_DATA]
    str x23, [x0, #RTP_SR_FLAG]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #96
    ret

// ---------------------------------------------------------------------
// Lrp2_wcol -- the width and colour checks of BAR and BARH: the width
//   finite and > 0, then the colour string "" or `#rrggbb`.
//   Inputs  : d8 = width (the caller's), x0 = the colour string
//   Outputs : x0 = 0 valid (x1 = the colour, or -1 for ""), 1 width
//             invalid, 2 colour invalid
//   Clobbers: x0-x17, d0-d1, flags
//   Frame   : 16 bytes (frame record)
// ---------------------------------------------------------------------
    .p2align 2
Lrp2_wcol:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    BNF d8, d1, 1f
    fcmp d8, #0.0
    b.le 1f
    bl _sea_plot_color              // x0 = colour, -1 for "", -2 invalid
    mov x1, x0
    mov x0, #0
    cmn x1, #2
    b.ne 2f
    mov x0, #2
    b 2f
1:  mov x0, #1
2:  ldp x29, x30, [sp], #16
    ret

// ---------------------------------------------------------------------
// Lrp2_zshape -- the shape check of CONTOUR and IMAGE: Z must be
//   len(y) x len(x); else the four slots expected (len(y), len(x)), got
//   (Z's rows, cols).
//   Inputs  : x0 = x, x1 = y, x2 = Z, x3 = the slot area (4 words)
//   Outputs : x0 = 0 when it matches, 1 (slots written) when not
//   Clobbers: x9-x12, flags
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrp2_zshape:
    ldr x9, [x0, #SEA_ARR_ROWS]     // len(x)
    ldr x10, [x1, #SEA_ARR_ROWS]    // len(y)
    ldr x11, [x2, #SEA_ARR_ROWS]
    ldr x12, [x2, #SEA_ARR_COLS]
    cmp x11, x10
    ccmp x12, x9, #0, eq
    b.ne 1f
    mov x0, #0
    ret
1:  stp x10, x9, [x3]               // expected len(y) x len(x)
    stp x11, x12, [x3, #16]         // got Z's shape
    mov x0, #1
    ret

// ---------------------------------------------------------------------
// Lrp2_copy3 -- the data block of a contour or image: x, y, then Z
//   column-major, 8 (n + m + n m) bytes (none when that is 0).
//   Inputs  : x0 = x, x1 = y, x2 = Z, x3 = site
//   Outputs : x0 = the block, or 0
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = x, x20 = y, x21 = Z, x22 = block
//   Frame   : 48 bytes (frame record + x19..x22)
// ---------------------------------------------------------------------
    .p2align 2
Lrp2_copy3:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, #0
    ldr x9, [x19, #SEA_ARR_ROWS]    // n
    ldr x10, [x20, #SEA_ARR_ROWS]   // m
    madd x11, x9, x10, x9
    add x11, x11, x10               // n + m + n m
    cbz x11, 1f
    lsl x0, x11, #3
    mov x1, x3
    bl _sea_alloc
    mov x22, x0
    ldr x1, [x19, #SEA_ARR_DATA]    // x
    ldr x2, [x19, #SEA_ARR_ROWS]
    lsl x2, x2, #3
    bl _memcpy
    ldr x9, [x19, #SEA_ARR_ROWS]
    add x0, x22, x9, lsl #3
    ldr x1, [x20, #SEA_ARR_DATA]    // y
    ldr x2, [x20, #SEA_ARR_ROWS]
    lsl x2, x2, #3
    bl _memcpy
    ldr x9, [x19, #SEA_ARR_ROWS]
    ldr x10, [x20, #SEA_ARR_ROWS]
    add x11, x9, x10
    add x0, x22, x11, lsl #3
    ldr x1, [x21, #SEA_ARR_DATA]    // Z, n m elements, column-major
    mul x2, x9, x10
    lsl x2, x2, #3
    bl _memcpy
1:  mov x0, x22
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// ---------------------------------------------------------------------
// Lrp2_record -- append a series record of a kind for an Axes (the
//   figure's series table may move: every record pointer is taken
//   afresh).
//   Inputs  : x0 = Axes, x1 = kind, x2 = site
//   Outputs : x0 = the new record (zero-filled but kind and axes index)
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = Axes, x20 = kind
//   Frame   : 32 bytes (frame record + x19, x20)
// ---------------------------------------------------------------------
    .p2align 2
Lrp2_record:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    mov x20, x1
    ldr x0, [x19, #RTP_A_FIG]
    mov x1, #1                      // the series table
    bl _sea_plot_append             // x0 = record
    str x20, [x0, #RTP_SR_KIND]
    ldr x9, [x19, #RTP_A_IDX]
    str x9, [x0, #RTP_SR_AX]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// ---------------------------------------------------------------------
// Lrp2_label -- a series' label: retained and stored unless "" (0).
//   Inputs  : x0 = the record, x1 = the label
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Frame   : none (tail call of _sea_retain)
// ---------------------------------------------------------------------
    .p2align 2
Lrp2_label:
    ldr x9, [x1, #SEA_STR_LEN]
    cbz x9, 1f
    str x1, [x0, #RTP_SR_LABEL]
    mov x0, x1
    b _sea_retain
1:  ret

// =====================================================================
// Shared computations
// =====================================================================

// ---------------------------------------------------------------------
// Lrp2_ext1 -- widen an axis's extent by one value unless it is not
//   finite (ties keep the earlier value: strict < and >, L-lh).
//   Inputs  : x0 = the axis (AS_*), d0 = the value
//   Clobbers: x9, d1, d2, flags
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrp2_ext1:
    BNF d0, d1, 9f                  // non-finite: skipped
    ldr x9, [x0, #AS_EXT]
    cbnz x9, 1f
    str d0, [x0, #AS_ELO]           // the first value
    str d0, [x0, #AS_EHI]
    mov x9, #1
    str x9, [x0, #AS_EXT]
    ret
1:  ldr d1, [x0, #AS_ELO]
    fcmp d0, d1
    b.pl 2f
    str d0, [x0, #AS_ELO]           // a new minimum
2:  ldr d2, [x0, #AS_EHI]
    fcmp d0, d2
    b.le 9f
    str d0, [x0, #AS_EHI]           // a new maximum
9:  ret

// ---------------------------------------------------------------------
// Lrp2_zrange -- the smallest and largest finite value of a matrix.
//   Inputs  : x0 = values, x1 = count
//   Outputs : x0 = 1 when there is a finite value (d0 = zmin, d1 =
//             zmax), else 0
//   Clobbers: x0-x2, d0-d3, flags
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrp2_zrange:
    mov x2, #0                      // none yet
1:  cbz x1, 9f
    ldr d2, [x0], #8
    sub x1, x1, #1
    BNF d2, d3, 1b
    cbnz x2, 2f
    fmov d0, d2                     // the first finite value
    fmov d1, d2
    mov x2, #1
    b 1b
2:  fcmp d2, d0
    fcsel d0, d2, d0, mi            // a smaller one
    fcmp d2, d1
    fcsel d1, d2, d1, gt            // a larger one
    b 1b
9:  mov x0, x2
    ret

// ---------------------------------------------------------------------
// Lrp2_zcheck -- whether a matrix has usable colours and levels: a finite
//   value, zmax != zmin and d = zmax - zmin finite (2.14.6 "Images",
//   "Contour levels").
//   Inputs  : x0 = values, x1 = count
//   Outputs : x0 = 1 usable (d0 = zmin, d1 = zmax, d2 = d), else 0
//   Clobbers: x0-x2, d0-d3, x16, flags
//   Frame   : 16 bytes (frame record)
// ---------------------------------------------------------------------
    .p2align 2
Lrp2_zcheck:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    bl Lrp2_zrange
    cbz x0, 1f
    fcmp d0, d1
    b.eq 1f                         // zmax = zmin
    fsub d2, d1, d0                 // d = zmax - zmin
    BNF d2, d3, 1f                  // overflowed
    mov x0, #1
    b 2f
1:  mov x0, #0
2:  ldp x29, x30, [sp], #16
    ret

// ---------------------------------------------------------------------
// Lrp2_yaxis -- a series' own y-axis in the writer state: the base's
//   (RS_AY) or the twin's (RS_AT).
//   Inputs  : x0 = the series record; x28 = the state
//   Outputs : x0 = the axis
//   Clobbers: x9, x10, flags
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrp2_yaxis:
    ldr x9, [x0, #RTP_SR_AX]
    ldr x10, [x28, #RS_BIDX]
    add x0, x28, #RS_AY
    cmp x9, x10
    b.eq 1f
    add x0, x28, #RS_AT
1:  ret


// ---------------------------------------------------------------------
// Lrp2_hsort -- sort f64 values ascending in place (heapsort: no
//   recursion, no allocation; the values are finite, so the sorted
//   sequence is unique but for the order of -0 and +0, which no caller
//   can observe).
//   Inputs  : x0 = values, x1 = count
//   Clobbers: x2-x7, d0-d2, flags
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrp2_hsort:
    cmp x1, #2
    b.lo 9f
    mov x2, #0                      // phase 0: build the heap
    lsr x3, x1, #1                  // sift from n / 2 - 1 down to 0
    mov x4, x1                      // the heap's size
1:  cbz x3, 3f
    sub x3, x3, #1
    mov x5, x3
    b 5f
3:  mov x2, #1                      // phase 1: extract the largest
    mov x4, x1
4:  cmp x4, #1
    b.ls 9f
    sub x4, x4, #1                  // the new size, and the place freed
    ldr d0, [x0]
    ldr d1, [x0, x4, lsl #3]
    str d1, [x0]                    // the root to the end
    str d0, [x0, x4, lsl #3]
    mov x5, #0
    // Sift element x5 down within the size x4 (x6 = the larger child).
5:  lsl x6, x5, #1
    add x6, x6, #1                  // the left child
    cmp x6, x4
    b.hs 8f
    ldr d0, [x0, x6, lsl #3]
    add x7, x6, #1                  // the right child, if any
    cmp x7, x4
    b.hs 6f
    ldr d1, [x0, x7, lsl #3]
    fcmp d0, d1
    b.pl 6f
    mov x6, x7
    fmov d0, d1
6:  ldr d2, [x0, x5, lsl #3]
    fcmp d2, d0
    b.pl 8f                         // not smaller than its children: placed
    str d0, [x0, x5, lsl #3]
    str d2, [x0, x6, lsl #3]
    mov x5, x6
    b 5b
8:  cbnz x2, 4b                     // the next phase step
    b 1b
9:  ret

// ---------------------------------------------------------------------
// Lrp2_delta -- a bar series' Delta (2.14.6 "Bars", L-kq): the smallest
//   positive difference of consecutive values in the ascending sort of
//   its finite x values, 1 with fewer than two distinct values (the
//   sort runs on an uncounted scratch block, freed here).
//   Inputs  : x0 = the series record; x28 = the state (RS_SITE)
//   Outputs : d0 = Delta
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = record, x20 = finite count, x21 = block,
//             d8 = Delta
//   Frame   : 48 bytes (frame record + x19..x21, d8)
// ---------------------------------------------------------------------
    .p2align 2
Lrp2_delta:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    str d8, [sp, #40]
    mov x19, x0
    LDK d8, ONE                     // fewer than two distinct values: 1
    // Count the finite x values.
    ldr x9, [x19, #RTP_SR_N]
    ldr x10, [x19, #RTP_SR_DATA]
    mov x20, #0
1:  cbz x9, 2f
    ldr d0, [x10], #8
    sub x9, x9, #1
    BNF d0, d1, 1b
    add x20, x20, #1
    b 1b
2:  cmp x20, #2
    b.lo 9f
    // Copy them into the scratch block and sort it.
    lsl x0, x20, #3
    ldr x1, [x28, #RS_SITE]
    bl _sea_alloc
    mov x21, x0
    ldr x9, [x19, #RTP_SR_N]
    ldr x10, [x19, #RTP_SR_DATA]
    mov x11, x21
3:  cbz x9, 4f
    ldr d0, [x10], #8
    sub x9, x9, #1
    BNF d0, d1, 3b
    str d0, [x11], #8
    b 3b
4:  mov x0, x21
    mov x1, x20
    bl Lrp2_hsort
    // The smallest positive consecutive difference (x12 = found).
    mov x12, #0
    mov x13, #1
5:  cmp x13, x20
    b.hs 7f
    sub x14, x13, #1
    ldr d0, [x21, x13, lsl #3]
    ldr d1, [x21, x14, lsl #3]
    fsub d0, d0, d1                 // s[k] - s[k - 1] (+Inf when it overflows)
    add x13, x13, #1
    fcmp d0, #0.0
    b.le 5b                         // equal values: not positive
    cbz x12, 6f
    fcmp d0, d2
    b.pl 5b
6:  fmov d2, d0                     // the smallest so far
    mov x12, #1
    b 5b
7:  cbz x12, 8f
    fmov d8, d2
8:  mov x0, x21
    lsl x1, x20, #3
    bl _sea_free_block
9:  fmov d0, d8
    ldr d8, [sp, #40]
    ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// ---------------------------------------------------------------------
// Lrp2_ends -- an image's extent ends along one axis (2.14.6 "Images",
//   L-kr): h = 0.5 for one value, else (v[k-1] - v[0]) / f64(2 (k - 1));
//   the ends v[0] - h and v[k-1] + h.
//   Inputs  : x1 = values, x2 = count (>= 1)
//   Outputs : d0 = a, d1 = b
//   Clobbers: x3, x16, d2, d3
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrp2_ends:
    ldr d0, [x1]
    sub x3, x2, #1
    ldr d1, [x1, x3, lsl #3]
    cmp x2, #1
    b.ne 1f
    LDK d2, HALF
    b 2f
1:  fsub d2, d1, d0                 // v[k-1] - v[0]
    lsl x3, x3, #1
    scvtf d3, x3                    // f64(2 (k - 1))
    fdiv d2, d2, d3
2:  fsub d0, d0, d2
    fadd d1, d1, d2
    ret

// ---------------------------------------------------------------------
// Lrp2_imgext -- an image series' extent: none with no cell or when an
//   end is not finite.
//   Inputs  : x0 = the series record
//   Outputs : x0 = 1 (d0 = a, d1 = b on x; d2 = a, d3 = b on y), else 0
//   Clobbers: x0-x3, x9-x11, x16, d0-d7, flags
//   Frame   : 16 bytes (frame record)
// ---------------------------------------------------------------------
    .p2align 2
Lrp2_imgext:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    ldr x9, [x0, #RTP_SR_N]
    ldr x10, [x0, #RTP_SR_M]
    cbz x9, 8f                      // no cell
    cbz x10, 8f
    ldr x11, [x0, #RTP_SR_DATA]
    mov x1, x11                     // x
    mov x2, x9
    bl Lrp2_ends
    fmov d4, d0
    fmov d5, d1
    add x1, x11, x9, lsl #3         // y
    mov x2, x10
    bl Lrp2_ends
    fmov d2, d0
    fmov d3, d1
    fmov d0, d4
    fmov d1, d5
    BNF d0, d6, 8f
    BNF d1, d6, 8f
    BNF d2, d6, 8f
    BNF d3, d6, 8f
    mov x0, #1
    b 9f
8:  mov x0, #0
9:  ldp x29, x30, [sp], #16
    ret

// =====================================================================
// The writer's hooks (called by rt_plot.s with x28 = its state)
// =====================================================================

// ---------------------------------------------------------------------
// _sea_plot2_extent -- the extents of a series of kind 3 .. 6 (2.14.6
//   "Data extents"): a bar series gives x_i - hw, x_i + hw of each drawn
//   bar to x and 0, h_i to its y-axis; a barh series 0 and each finite
//   h_i to x and i - width / 2, i + width / 2 for every i to its y-axis;
//   a contour its x to x and its y to its y-axis; an image its extent
//   ends (a, b on x, then on y).
//   Inputs  : x0 = the series record, x1 = its own y-axis; x28 = the state
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = record, x20 = y-axis, x21 = n, x22 = data,
//             x23 = i, d8 = hw, d9 = h_i or f64(i)
//   Frame   : 80 bytes (frame record + x19..x23, pad, d8, d9)
// ---------------------------------------------------------------------
    .private_extern _sea_plot2_extent
    .p2align 2
_sea_plot2_extent:
    stp x29, x30, [sp, #-80]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    str x23, [sp, #48]
    stp d8, d9, [sp, #64]
    mov x19, x0
    mov x20, x1
    ldr x21, [x19, #RTP_SR_N]
    ldr x22, [x19, #RTP_SR_DATA]
    mov x23, #0
    ldr x9, [x19, #RTP_SR_KIND]
    cmp x9, #RTP_K_BARH
    b.eq Lrp2_ext_barh
    cmp x9, #RTP_K_CONTOUR
    b.eq Lrp2_ext_con
    cmp x9, #RTP_K_IMAGE
    b.eq Lrp2_ext_img
    cmp x9, #RTP_K_BAR
    b.ne Lrp2_ext_done
    // A bar series: hw = (width * Delta) / 2.
    mov x0, x19
    bl Lrp2_delta
    ldr d1, [x19, #RTP_SR_WIDTH]
    fmul d0, d1, d0
    LDK d1, TWO
    fdiv d8, d0, d1
1:  cmp x23, x21
    b.hs Lrp2_ext_done
    ldr d0, [x22, x23, lsl #3]      // x_i
    add x9, x22, x21, lsl #3
    ldr d9, [x9, x23, lsl #3]       // h_i
    add x23, x23, #1
    BNF d0, d1, 1b                  // a bar is drawn when x_i, h_i ...
    BNF d9, d1, 1b
    fsub d4, d0, d8                 // ... and both ends are finite
    fadd d3, d0, d8
    BNF d4, d1, 1b
    BNF d3, d1, 1b
    add x0, x28, #RS_AX
    fmov d0, d4
    bl Lrp2_ext1                    // x_i - hw (Lrp2_ext1 keeps d3)
    fmov d0, d3
    bl Lrp2_ext1                    // x_i + hw
    mov x0, x20
    movi d0, #0
    bl Lrp2_ext1                    // the baseline 0
    fmov d0, d9
    bl Lrp2_ext1                    // h_i
    b 1b
Lrp2_ext_barh:
    // A barh series: hw = width / 2; x takes 0 and each finite h_i.
    ldr d0, [x19, #RTP_SR_WIDTH]
    LDK d1, TWO
    fdiv d8, d0, d1
    add x0, x28, #RS_AX
    movi d0, #0
    bl Lrp2_ext1
2:  cmp x23, x21
    b.hs 3f
    ldr d0, [x22, x23, lsl #3]
    add x23, x23, #1
    bl Lrp2_ext1                    // skips a non-finite h_i
    b 2b
3:  mov x23, #0                     // y takes i - hw, i + hw for every i
4:  cmp x23, x21
    b.hs Lrp2_ext_done
    scvtf d9, x23
    add x23, x23, #1
    mov x0, x20
    fsub d0, d9, d8
    bl Lrp2_ext1
    fadd d0, d9, d8
    bl Lrp2_ext1
    b 4b
Lrp2_ext_con:
    // A contour: its x values to x, its y values to its y-axis.
    add x0, x28, #RS_AX
5:  cmp x23, x21
    b.hs 6f
    ldr d0, [x22, x23, lsl #3]
    add x23, x23, #1
    bl Lrp2_ext1
    b 5b
6:  add x22, x22, x21, lsl #3       // y
    ldr x21, [x19, #RTP_SR_M]
    mov x23, #0
    mov x0, x20
7:  cmp x23, x21
    b.hs Lrp2_ext_done
    ldr d0, [x22, x23, lsl #3]
    add x23, x23, #1
    bl Lrp2_ext1
    b 7b
Lrp2_ext_img:
    // An image: its extent ends, if it is drawn.
    mov x0, x19
    bl Lrp2_imgext
    cbz x0, Lrp2_ext_done
    fmov d4, d0                     // Lrp2_ext1 keeps d3 .. d7
    fmov d5, d1
    fmov d6, d2
    fmov d7, d3
    add x0, x28, #RS_AX
    fmov d0, d4
    bl Lrp2_ext1
    fmov d0, d5
    bl Lrp2_ext1
    mov x0, x20
    fmov d0, d6
    bl Lrp2_ext1
    fmov d0, d7
    bl Lrp2_ext1
Lrp2_ext_done:
    ldp d8, d9, [sp, #64]
    ldr x23, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #80
    ret

// ---------------------------------------------------------------------
// _sea_plot2_cbar -- the pair's colorbar (L-ko): the last image series of
//   the pair with colorbar: true, or none.
//   Inputs  : x28 = the state (RS_FIG, RS_BIDX, RS_TIDX set)
//   Outputs : RS_CBAR = that record, or 0
//   Clobbers: x9-x15, flags
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .private_extern _sea_plot2_cbar
    .p2align 2
_sea_plot2_cbar:
    str xzr, [x28, #RS_CBAR]
    ldr x9, [x28, #RS_FIG]
    ldr x10, [x9, #RTP_F_SRT]
    ldr x11, [x9, #RTP_F_NSR]
    ldr x12, [x28, #RS_BIDX]
    ldr x13, [x28, #RS_TIDX]        // -1 matches no index
1:  cbz x11, 9f
    ldr x14, [x10, #RTP_SR_AX]
    cmp x14, x12
    ccmp x14, x13, #4, ne           // this pair's?
    b.ne 2f
    ldr x14, [x10, #RTP_SR_KIND]
    cmp x14, #RTP_K_IMAGE
    b.ne 2f
    ldr x14, [x10, #RTP_SR_FLAG]
    cbz x14, 2f
    str x10, [x28, #RS_CBAR]        // the last one wins
2:  add x10, x10, #RTP_SR_SIZE
    sub x11, x11, #1
    b 1b
9:  ret

// ---------------------------------------------------------------------
// _sea_plot2_series -- the element of a series of kind 3 .. 6 (2.14.6
//   "Series forms"); other kinds write nothing.
//   Inputs  : x0 = the series record; x28 = the state
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Frame   : none (tail calls)
// ---------------------------------------------------------------------
    .private_extern _sea_plot2_series
    .p2align 2
_sea_plot2_series:
    ldr x9, [x0, #RTP_SR_KIND]
    cmp x9, #RTP_K_BAR
    b.eq Lrp2_bars
    cmp x9, #RTP_K_BARH
    b.eq Lrp2_bars
    cmp x9, #RTP_K_CONTOUR
    b.eq Lrp2_contour
    cmp x9, #RTP_K_IMAGE
    b.eq Lrp2_image
    ret

// ---------------------------------------------------------------------
// Lrp2_bars -- a bar or barh series: `<g class="bars" fill="{c}">`, a
//   rect per drawn bar, `</g>`. A bar: a, b = x_i -+ hw on x, 0 and h_i on
//   its y-axis; a barh: a, b = i -+ width / 2 on its y-axis, 0 and h_i on
//   x; each rect's position the smaller of its two clamped ends, its size
//   their absolute difference (L-kl).
//   Inputs  : x0 = the series record; x28 = the state
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = record, x20 = i, x21 = n, x22 = x values (a
//             barh's h), x23 = h values, x24 = its y-axis, x25 = kind,
//             d8 = hw, d9 = h_i, then its mapped end, d10, d11 = the two
//             mapped ends a, b, d12 = the mapped 0
//   Frame   : 128 bytes (frame record + x19..x25, pad, d8..d12, pad)
// ---------------------------------------------------------------------
    .p2align 2
Lrp2_bars:
    stp x29, x30, [sp, #-128]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    str x25, [sp, #64]
    stp d8, d9, [sp, #80]
    stp d10, d11, [sp, #96]
    str d12, [sp, #112]
    mov x19, x0
    bl Lrp2_yaxis
    mov x24, x0
    ldr x25, [x19, #RTP_SR_KIND]
    ldr x21, [x19, #RTP_SR_N]
    ldr x22, [x19, #RTP_SR_DATA]
    add x23, x22, x21, lsl #3
    mov x20, #0
    PUTC Lrp2_s_gbars
    ldr x0, [x19, #RTP_SR_COLOR]
    bl _sea_plot_bcolor
    PUTC Lrp2_s_qgt
    cmp x25, #RTP_K_BARH
    b.eq Lrp2_bars_h
    // Vertical bars: hw = (width * Delta) / 2.
    mov x0, x19
    bl Lrp2_delta
    ldr d1, [x19, #RTP_SR_WIDTH]
    fmul d0, d1, d0
    LDK d1, TWO
    fdiv d8, d0, d1
1:  cmp x20, x21
    b.hs Lrp2_bars_end
    ldr d0, [x22, x20, lsl #3]      // x_i
    ldr d9, [x23, x20, lsl #3]      // h_i
    add x20, x20, #1
    BNF d0, d1, 1b
    BNF d9, d1, 1b
    fsub d10, d0, d8                // a = x_i - hw
    fadd d11, d0, d8                // b = x_i + hw
    BNF d10, d1, 1b
    BNF d11, d1, 1b
    fmov d0, d10
    bl _sea_plot_mapx
    fmov d10, d0                    // X(a)
    fmov d0, d11
    bl _sea_plot_mapx
    fmov d11, d0                    // X(b)
    mov x0, x24
    movi d0, #0
    bl _sea_plot_mapy
    fmov d12, d0                    // Y(0)
    mov x0, x24
    fmov d0, d9
    bl _sea_plot_mapy
    fmov d9, d0                     // Y(h_i)
    fcmp d10, d11
    fcsel d0, d10, d11, ls          // x = min(X(a), X(b))
    fsub d2, d11, d10
    fabs d2, d2                     // w = |X(b) - X(a)|
    fcmp d12, d9
    fcsel d1, d12, d9, ls           // y = min(Y(0), Y(h_i))
    fsub d3, d9, d12
    fabs d3, d3                     // h = |Y(h_i) - Y(0)|
    LADR x0, Lrp2_s_bar
    LADR x1, Lrp2_s_qclose
    bl _sea_plot_xywh
    b 1b
Lrp2_bars_h:
    // Horizontal bars: hw = width / 2 (x22 holds the h values).
    ldr d0, [x19, #RTP_SR_WIDTH]
    LDK d1, TWO
    fdiv d8, d0, d1
2:  cmp x20, x21
    b.hs Lrp2_bars_end
    ldr d9, [x22, x20, lsl #3]      // h_i
    scvtf d0, x20                   // f64(i)
    add x20, x20, #1
    BNF d9, d1, 2b
    fsub d10, d0, d8                // a = i - width / 2
    fadd d11, d0, d8                // b = i + width / 2
    BNF d10, d1, 2b
    BNF d11, d1, 2b
    mov x0, x24
    fmov d0, d10
    bl _sea_plot_mapy
    fmov d10, d0                    // Y(a)
    mov x0, x24
    fmov d0, d11
    bl _sea_plot_mapy
    fmov d11, d0                    // Y(b)
    movi d0, #0
    bl _sea_plot_mapx
    fmov d12, d0                    // X(0)
    fmov d0, d9
    bl _sea_plot_mapx
    fmov d9, d0                     // X(h_i)
    fcmp d12, d9
    fcsel d0, d12, d9, ls           // x = min(X(0), X(h_i))
    fsub d2, d9, d12
    fabs d2, d2                     // w = |X(h_i) - X(0)|
    fcmp d10, d11
    fcsel d1, d10, d11, ls          // y = min(Y(a), Y(b))
    fsub d3, d11, d10
    fabs d3, d3                     // h = |Y(b) - Y(a)|
    LADR x0, Lrp2_s_bar
    LADR x1, Lrp2_s_qclose
    bl _sea_plot_xywh
    b 2b
Lrp2_bars_end:
    PUTC Lrp2_s_eg
    ldr d12, [sp, #112]
    ldp d10, d11, [sp, #96]
    ldp d8, d9, [sp, #80]
    ldr x25, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #128
    ret

// =====================================================================
// Images, the colour map and the PNG in the buffer
// =====================================================================

// ---------------------------------------------------------------------
// Lrp2_cmapb -- build the colour map once (2.14.6 "The colour map"):
//   entry e: p = f64(4 e) / 255, s = min(floor(p), 3), f = p - f64(s),
//   each channel round(A_s + f * (A_{s+1} - A_s)) (round half away from
//   zero), packed 0xRRGGBB.
//   Inputs  : none
//   Clobbers: x5-x16, d0-d3, flags
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrp2_cmapb:
    LADR x9, Lrp2_cmapok
    ldr x10, [x9]
    cbnz x10, 9f                    // built already
    LADR x11, Lrp2_cmap
    LADR x12, Lrp2_anchors
    mov x13, #0                     // e
1:  lsl x14, x13, #2
    scvtf d0, x14
    LDK d1, F255
    fdiv d0, d0, d1                 // p = f64(4 e) / 255
    frintm d1, d0
    fcvtzs x14, d1
    cmp x14, #3
    mov x15, #3
    csel x14, x15, x14, gt          // s = min(floor(p), 3)
    scvtf d1, x14
    fsub d1, d0, d1                 // f = p - f64(s)
    mov x15, #24
    madd x15, x14, x15, x12         // A_s (three f64 per anchor)
    mov x7, #0                      // the colour
    mov x6, #0                      // the channel
2:  ldr d2, [x15, x6, lsl #3]       // A_s
    add x5, x15, #24
    ldr d3, [x5, x6, lsl #3]        // A_{s+1}
    fsub d3, d3, d2
    fmul d3, d1, d3                 // f * (A_{s+1} - A_s)
    fadd d3, d2, d3                 // A_s + ...
    frinta d3, d3                   // round half away from zero
    fcvtzs x5, d3
    lsl x7, x7, #8
    orr x7, x7, x5
    add x6, x6, #1
    cmp x6, #3
    b.lo 2b
    str w7, [x11, x13, lsl #2]
    add x13, x13, #1
    cmp x13, #RP2_CMAP_N
    b.lo 1b
    mov x10, #1
    str x10, [x9]
9:  ret

// ---------------------------------------------------------------------
// _sea_plot_cmap -- colour-map entry e (for the writer and tests/rt).
//   Inputs  : x0 = e (0 .. 255)
//   Outputs : w0 = 0xRRGGBB
//   Clobbers: x5-x16, d0-d3, flags
//   Frame   : 16 bytes (frame record)
// ---------------------------------------------------------------------
    .private_extern _sea_plot_cmap
    .p2align 2
_sea_plot_cmap:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    bl Lrp2_cmapb                   // keeps x0
    LADR x9, Lrp2_cmap
    ldr w0, [x9, x0, lsl #2]
    ldp x29, x30, [sp], #16
    ret

// ---------------------------------------------------------------------
// Lrp2_zcol -- the colour of an image cell (2.14.6 "Images"): NaN white;
//   with no usable range entry 0; else z >= zmax 255, z <= zmin 0, else
//   floor(((z - zmin) / (zmax - zmin)) * 256), 255 if that is 256. The
//   map must be built (Lrp2_cmapb).
//   Inputs  : d0 = z, x1 = 1 when the range is usable, d1 = zmin, d2 =
//             zmax
//   Outputs : w0 = 0xRRGGBB
//   Clobbers: x0, x9, x10, x16, d3, d4, flags
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrp2_zcol:
    fcmp d0, d0
    b.vs 3f                         // NaN: white
    mov x9, #0
    cbz x1, 2f                      // no usable range: entry 0
    mov x9, #255
    fcmp d0, d2
    b.ge 2f                         // z >= zmax (+Inf included)
    mov x9, #0
    fcmp d0, d1
    b.ls 2f                         // z <= zmin (-Inf included)
    fsub d3, d0, d1                 // z - zmin
    fsub d4, d2, d1                 // zmax - zmin
    fdiv d3, d3, d4
    LDK d4, F256
    fmul d3, d3, d4
    frintm d3, d3                   // floor(...)
    fcvtzs x9, d3
    cmp x9, #255
    mov x10, #255
    csel x9, x10, x9, gt            // 256 becomes 255
2:  LADR x10, Lrp2_cmap
    ldr w0, [x10, x9, lsl #2]
    ret
3:  movz w0, #(RP2_WHITE & 0xffff)
    movk w0, #(RP2_WHITE >> 16), lsl #16
    ret

// ---------------------------------------------------------------------
// Lrp2_breserve -- reserve bytes at the end of the SVG buffer, growing it
//   as rt_plot.s's _sea_plot_bput does (doubled by copy; OUT_OF_MEMORY at
//   SAVE_SVG's site through _sea_alloc).
//   Inputs  : x0 = the count; x28 = the state
//   Outputs : x0 = where to write them (the buffer's length advanced)
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = count, x20 = new block, x21 = new size
//   Frame   : 48 bytes (frame record + x19..x21, pad)
// ---------------------------------------------------------------------
    .p2align 2
Lrp2_breserve:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    mov x19, x0
    ldr x9, [x28, #RS_BLEN]
    ldr x10, [x28, #RS_BCAP]
    add x11, x9, x19                // the length needed
    cmp x11, x10
    b.ls 2f
    mov x21, x10
1:  lsl x21, x21, #1                // double until it fits
    cmp x21, x11
    b.lo 1b
    mov x0, x21
    ldr x1, [x28, #RS_SITE]
    bl _sea_alloc
    mov x20, x0
    ldr x1, [x28, #RS_BPTR]
    ldr x2, [x28, #RS_BLEN]
    bl _memcpy
    ldr x0, [x28, #RS_BPTR]
    ldr x1, [x28, #RS_BCAP]
    bl _sea_free_block
    str x20, [x28, #RS_BPTR]
    str x21, [x28, #RS_BCAP]
2:  ldr x0, [x28, #RS_BPTR]
    ldr x9, [x28, #RS_BLEN]
    add x0, x0, x9
    add x9, x9, x19
    str x9, [x28, #RS_BLEN]
    ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// ---------------------------------------------------------------------
// Lrp2_pngout -- an image's PNG written as base64 into the SVG buffer
//   (2.14.6 "PNG", "Base64"): the file built by _sea_png, the raw block
//   freed, the base64 text written in place, the file freed.
//   Inputs  : x0 = raw block (freed here), x1 = its length, x2 = w, x3 =
//             h; x28 = the state
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = raw, x20 = its length, x21 = the file, x22 =
//             its length
//   Frame   : 48 bytes (frame record + x19..x22)
// ---------------------------------------------------------------------
    .p2align 2
Lrp2_pngout:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    mov x20, x1
    ldr x4, [x28, #RS_SITE]
    bl _sea_png                     // x0 = file, x1 = length
    mov x21, x0
    mov x22, x1
    mov x0, x19
    mov x1, x20
    bl _sea_free_block              // the raw data
    add x9, x22, #2                 // 4 * ceil(length / 3) letters
    mov x10, #3
    udiv x9, x9, x10
    lsl x0, x9, #2
    bl Lrp2_breserve
    mov x1, x21
    mov x2, x22
    bl _sea_b64
    mov x0, x21
    mov x1, x22
    bl _sea_free_block              // the file
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// ---------------------------------------------------------------------
// Lrp2_imgraw -- an image's raw PNG data (2.14.6 "Images"): per PNG row r
//   (from the top) the filter byte 0, then per column c the cell (i, j)
//   with i = m - 1 - r, or r when Y(a_y) < Y(b_y), and j = c, or
//   n - 1 - c when X(a) > X(b); each pixel the cell's colour.
//   Inputs  : x0 = the series record (n, m >= 1), x1 = flags (bit 0: the
//             columns flipped, bit 1: the rows top-down); x28 = the state
//   Outputs : x0 = the raw block (uncounted), x1 = its length m (1 + 3 n)
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = record, x20 = flags (bit 2: the range is
//             usable), x21 = n, x22 = m, x23 = Z, x24 = the block, x25 =
//             cursor, x26 = r, x27 = c, d8 = zmin, d9 = zmax
//   Frame   : 112 bytes (frame record + x19..x27, a slot for i at 88, d8, d9)
// ---------------------------------------------------------------------
    .p2align 2
Lrp2_imgraw:
    stp x29, x30, [sp, #-112]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    str x27, [sp, #80]
    stp d8, d9, [sp, #96]
    mov x19, x0
    mov x20, x1
    ldr x21, [x19, #RTP_SR_N]
    ldr x22, [x19, #RTP_SR_M]
    ldr x9, [x19, #RTP_SR_DATA]
    add x10, x21, x22
    add x23, x9, x10, lsl #3        // Z
    mov x0, x23
    mul x1, x21, x22
    bl Lrp2_zcheck                  // x0 usable, d0 zmin, d1 zmax
    orr x20, x20, x0, lsl #2
    fmov d8, d0
    fmov d9, d1
    bl Lrp2_cmapb
    add x9, x21, x21, lsl #1
    add x9, x9, #1                  // 1 + 3 n
    mul x0, x9, x22
    ldr x1, [x28, #RS_SITE]
    bl _sea_alloc
    mov x24, x0
    mov x25, x0
    mov x26, #0
1:  cmp x26, x22
    b.hs 9f
    strb wzr, [x25], #1             // the filter byte
    sub x10, x22, #1
    sub x10, x10, x26               // i = m - 1 - r ...
    tbz x20, #1, 2f
    mov x10, x26                    // ... or r
2:  mov x27, #0
3:  cmp x27, x21
    b.hs 5f
    mov x11, x27                    // j = c ...
    tbz x20, #0, 4f
    sub x11, x21, #1
    sub x11, x11, x27               // ... or n - 1 - c
4:  madd x12, x11, x22, x10         // j m + i
    ldr d0, [x23, x12, lsl #3]
    ubfx x1, x20, #2, #1
    fmov d1, d8
    fmov d2, d9
    str x10, [sp, #88]              // i across the call (x10 is scratch)
    bl Lrp2_zcol
    ldr x10, [sp, #88]
    lsr w9, w0, #16
    strb w9, [x25]                  // red, green, blue
    lsr w9, w0, #8
    strb w9, [x25, #1]
    strb w0, [x25, #2]
    add x25, x25, #3
    add x27, x27, #1
    b 3b
5:  add x26, x26, #1
    b 1b
9:  mov x0, x24
    add x9, x21, x21, lsl #1
    add x9, x9, #1
    mul x1, x9, x22
    ldp d8, d9, [sp, #96]
    ldr x27, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #112
    ret

// ---------------------------------------------------------------------
// Lrp2_image -- an image series (2.14.6 "Series forms"): when it has a
//   cell and its extent is finite, `<image class="image" …>` spanning
//   min(X(a), X(b)) .. max and the y analogue, with its PNG; nothing
//   otherwise.
//   Inputs  : x0 = the series record; x28 = the state
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = record, x20 = flags, d8 = X(a), d9 = X(b),
//             d10 = Y(a_y), d11 = Y(b_y)
//   Frame   : 64 bytes (frame record + x19, x20, d8..d11)
// ---------------------------------------------------------------------
    .p2align 2
Lrp2_image:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp d8, d9, [sp, #32]
    stp d10, d11, [sp, #48]
    mov x19, x0
    bl Lrp2_imgext
    cbz x0, 9f                      // no cell or a non-finite end
    fmov d8, d0
    fmov d9, d1
    fmov d10, d2
    fmov d11, d3
    fmov d0, d8
    bl _sea_plot_mapx
    fmov d8, d0                     // X(a)
    fmov d0, d9
    bl _sea_plot_mapx
    fmov d9, d0                     // X(b)
    mov x0, x19
    bl Lrp2_yaxis
    mov x20, x0
    fmov d0, d10
    bl _sea_plot_mapy
    fmov d10, d0                    // Y(a_y)
    mov x0, x20
    fmov d0, d11
    bl _sea_plot_mapy
    fmov d11, d0                    // Y(b_y)
    fcmp d8, d9
    cset x20, gt                    // bit 0: X(a) > X(b), columns flipped
    fcmp d10, d11
    cset x9, mi                     // bit 1: Y(a_y) < Y(b_y), rows top-down
    orr x20, x20, x9, lsl #1
    fcmp d8, d9
    fcsel d0, d8, d9, ls            // x = min(X(a), X(b))
    fsub d2, d9, d8
    fabs d2, d2                     // w
    fcmp d10, d11
    fcsel d1, d10, d11, ls          // y = min(Y(a_y), Y(b_y))
    fsub d3, d11, d10
    fabs d3, d3                     // h
    LADR x0, Lrp2_s_image
    LADR x1, Lrp2_s_href
    bl _sea_plot_xywh
    mov x0, x19
    mov x1, x20
    bl Lrp2_imgraw                  // x0 = raw, x1 = length
    ldr x2, [x19, #RTP_SR_N]        // w = n
    ldr x3, [x19, #RTP_SR_M]        // h = m
    bl Lrp2_pngout
    PUTC Lrp2_s_qclose
9:  ldp d10, d11, [sp, #48]
    ldp d8, d9, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// ---------------------------------------------------------------------
// _sea_plot2_colorbar -- item 9 (2.14.6; L-ko): at xc = px + pw + 12 (+ 52
//   with a twin) the 1 x 256 PNG of the map (row r entry 255 - r), its
//   box, its tick marks and labels; the ticks an explicit-limit axis over
//   the image's finite min .. max (no finite cell or zero width widened
//   as rule 4), mapped like a y-axis onto py .. py + ph.
//   Inputs  : x28 = the state (RS_CBAR set, the plot area laid out)
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = record, x20 = the axis, x21 = raw block,
//             d8 = xc
//   Frame   : 48 bytes (frame record + x19..x21, d8)
// ---------------------------------------------------------------------
    .private_extern _sea_plot2_colorbar
    .p2align 2
_sea_plot2_colorbar:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    str d8, [sp, #40]
    ldr x19, [x28, #RS_CBAR]
    // xc = ((px + pw) + 12) (+ 52 with a twin).
    ldr d0, [x28, #RS_PX]
    ldr d1, [x28, #RS_PW]
    fadd d0, d0, d1
    LDK d1, F12
    fadd d8, d0, d1
    ldr x9, [x28, #RS_TWIN]
    cbz x9, 1f
    LDK d1, F52
    fadd d8, d8, d1
    // The axis over the image's finite range.
1:  LADR x20, Lrp2_ac
    str xzr, [x20, #AS_REV]
    str xzr, [x20, #AS_CAT]
    str xzr, [x20, #AS_NCAT]
    ldr x9, [x19, #RTP_SR_N]
    ldr x10, [x19, #RTP_SR_M]
    ldr x11, [x19, #RTP_SR_DATA]
    add x12, x9, x10
    add x0, x11, x12, lsl #3        // Z (no element is read when n m = 0)
    mul x1, x9, x10
    bl Lrp2_zrange
    str x0, [x20, #AS_EXT]
    str d0, [x20, #AS_ELO]
    str d1, [x20, #AS_EHI]
    mov x0, x20
    bl _sea_plot_widen              // rule 4's widening
    mov x0, x20
    bl _sea_plot_ticks_in           // explicit-limit ticks
    mov x0, x20
    bl _sea_plot_tickfmt
    // The strip.
    LADR x0, Lrp2_s_cbimage
    LADR x1, Lrp2_s_href
    fmov d0, d8
    ldr d1, [x28, #RS_PY]
    LDK d2, F12
    ldr d3, [x28, #RS_PH]
    bl _sea_plot_xywh
    mov x0, #(4 * RP2_CMAP_N)       // 256 rows of 1 + 3 bytes
    ldr x1, [x28, #RS_SITE]
    bl _sea_alloc
    mov x21, x0
    bl Lrp2_cmapb
    LADR x10, Lrp2_cmap
    mov x11, #0                     // r
2:  mov x12, #(RP2_CMAP_N - 1)
    sub x12, x12, x11               // entry 255 - r
    ldr w13, [x10, x12, lsl #2]
    add x14, x21, x11, lsl #2
    strb wzr, [x14]                 // the filter byte
    lsr w15, w13, #16
    strb w15, [x14, #1]
    lsr w15, w13, #8
    strb w15, [x14, #2]
    strb w13, [x14, #3]
    add x11, x11, #1
    cmp x11, #RP2_CMAP_N
    b.lo 2b
    mov x0, x21
    mov x1, #(4 * RP2_CMAP_N)
    mov x2, #1
    mov x3, #RP2_CMAP_N
    bl Lrp2_pngout
    PUTC Lrp2_s_qclose
    // The box.
    LADR x0, Lrp2_s_cbbox
    LADR x1, Lrp2_s_boxend
    fmov d0, d8
    ldr d1, [x28, #RS_PY]
    LDK d2, F12
    ldr d3, [x28, #RS_PH]
    bl _sea_plot_xywh
    // The tick marks: M{xc+12} {Y} h-3.00 per tick.
    PUTC Lrp2_s_cbticks
    mov x9, #1
    str x9, [x28, #RS_FIRST]
    mov x0, x20
    mov x1, #0
    LDK d0, F12
    fadd d0, d8, d0
    LADR x2, Lrp2_s_hm3
    mov x3, #0
    bl _sea_plot_tickpath
    PUTC Lrp2_s_boxend
    // The tick labels at xc + 16.
    mov x0, x20
    mov x1, #0
    LADR x2, Lrp2_s_ctick
    LADR x3, Lrp2_s_ctickend
    LDK d0, F16
    fadd d0, d8, d0
    bl _sea_plot_ticktexts
    ldr d8, [sp, #40]
    ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// =====================================================================
// Contours (2.14.6 "Contour levels and marching squares"; L-ks)
// =====================================================================

// ---------------------------------------------------------------------
// Lrp2_edge -- the clamped point of a crossed edge of the cell in
//   Lrp2_cs: from its first corner (z1, p1) to its second (z2, p2), t =
//   (L - z1) / (z2 - z1) and each coordinate p1 + t * (p2 - p1); then X
//   and Y (the series' y-axis), clamped.
//   Inputs  : x0 = the edge (0 a-b, 1 b-c, 2 d-c, 3 a-d); x28 = the state
//   Outputs : d0 = X, d1 = Y
//   Clobbers: x0, x9-x13, x16, d0-d7, flags
//   Frame   : 16 bytes (frame record)
// ---------------------------------------------------------------------
    .p2align 2
Lrp2_edge:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    LADR x9, Lrp2_cs
    LADR x10, Lrp2_edges
    add x10, x10, x0, lsl #1
    ldrb w11, [x10]                 // the first corner
    ldrb w12, [x10, #1]             // the second
    add x13, x9, #CS_Z
    ldr d2, [x13, x11, lsl #3]      // z1
    ldr d3, [x13, x12, lsl #3]      // z2
    ldr d4, [x9, #CS_L]
    fsub d4, d4, d2                 // L - z1
    fsub d3, d3, d2                 // z2 - z1
    fdiv d5, d4, d3                 // t
    add x13, x9, #CS_X
    ldr d2, [x13, x11, lsl #3]
    ldr d3, [x13, x12, lsl #3]
    fsub d3, d3, d2
    fmul d3, d5, d3
    fadd d6, d2, d3                 // x1 + t * (x2 - x1)
    add x13, x9, #CS_Y
    ldr d2, [x13, x11, lsl #3]
    ldr d3, [x13, x12, lsl #3]
    fsub d3, d3, d2
    fmul d3, d5, d3
    fadd d7, d2, d3                 // y1 + t * (y2 - y1)
    fmov d0, d6
    bl _sea_plot_mapx               // keeps d4 .. d7
    fmov d6, d0
    LADR x9, Lrp2_cs
    ldr x0, [x9, #CS_AXIS]
    fmov d0, d7
    bl _sea_plot_mapy               // keeps d5 .. d7
    fmov d1, d0
    fmov d0, d6
    ldp x29, x30, [sp], #16
    ret

// ---------------------------------------------------------------------
// Lrp2_emit -- one segment from edge e1's point to edge e2's: in mode 0
//   written (opening the level's group before its first segment); in
//   mode 1 its midpoint returned.
//   Inputs  : x0 = e1, x1 = e2 (e1 < e2); x28 = the state
//   Outputs : x0 = 1 in mode 1 (d0, d1 = ((X1 + X2) / 2, (Y1 + Y2) / 2)),
//             else 0
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = e2, x20 = Lrp2_cs, d8 = X1, d9 = Y1, d10 =
//             X2, d11 = Y2
//   Frame   : 64 bytes (frame record + x19, x20, d8..d11)
// ---------------------------------------------------------------------
    .p2align 2
Lrp2_emit:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp d8, d9, [sp, #32]
    stp d10, d11, [sp, #48]
    mov x19, x1
    LADR x20, Lrp2_cs
    bl Lrp2_edge
    fmov d8, d0
    fmov d9, d1
    mov x0, x19
    bl Lrp2_edge
    fmov d10, d0
    fmov d11, d1
    ldr x9, [x20, #CS_MODE]
    cbnz x9, 2f
    ldr x9, [x20, #CS_OPEN]
    cbnz x9, 1f
    PUTC Lrp2_s_glevel              // the level's group, at its first segment
    ldr x0, [x20, #CS_COLOR]
    bl _sea_plot_bcolor
    PUTC Lrp2_s_qgt
    mov x9, #1
    str x9, [x20, #CS_OPEN]
1:  PUTC Lrp2_s_seg
    F2 d8
    PUTC Lrp2_s_qy1
    F2 d9
    PUTC Lrp2_s_qx2
    F2 d10
    PUTC Lrp2_s_qy2
    F2 d11
    PUTC Lrp2_s_qclose
    mov x0, #0
    b 3f
2:  fadd d0, d8, d10                // the midpoint of the clamped ends
    LDK d2, TWO
    fdiv d0, d0, d2
    fadd d1, d9, d11
    fdiv d1, d1, d2
    mov x0, #1
3:  ldp d10, d11, [sp, #48]
    ldp d8, d9, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

// ---------------------------------------------------------------------
// Lrp2_scan -- marching squares for one level (Lrp2_cs: CS_L, CS_MODE,
//   CS_AXIS, CS_COLOR, CS_OPEN set): the cells column-major (j = 0 ..
//   n - 2 outer, i = 0 .. m - 2 inner), corners a = Z[i,j], b = Z[i,j+1],
//   c = Z[i+1,j+1], d = Z[i+1,j]; a cell with a non-finite corner value
//   or coordinate skipped; a corner above when its value >= L; edges e0
//   a-b, e1 b-c, e2 d-c, e3 a-d crossed when their corners differ; two
//   crossed edges one segment (the lower edge first); four (a saddle)
//   two by the centre m = ((a + b) + (c + d)) / 4: (e0, e1), (e2, e3) when
//   m >= L equals a's state, else (e0, e3), (e1, e2). Mode 1 stops at the
//   first segment.
//   Inputs  : x0 = the series record; x28 = the state
//   Outputs : x0 = 1 when mode 1 found a segment (d0, d1 its midpoint)
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = record, x20 = j, x21 = i, x22 = n, x23 = m,
//             x24 = Lrp2_cs, x25 = x values, x26 = y values, x27 = Z,
//             d8 = L
//   Frame   : 112 bytes (frame record + x19..x27, d8 at 88, the second
//             saddle pair at 96)
// ---------------------------------------------------------------------
    .p2align 2
Lrp2_scan:
    stp x29, x30, [sp, #-112]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp x27, xzr, [sp, #80]
    str d8, [sp, #88]
    mov x19, x0
    LADR x24, Lrp2_cs
    ldr d8, [x24, #CS_L]
    ldr x22, [x19, #RTP_SR_N]
    ldr x23, [x19, #RTP_SR_M]
    ldr x25, [x19, #RTP_SR_DATA]
    add x26, x25, x22, lsl #3
    add x27, x26, x23, lsl #3
    mov x20, #0
Lrp2_scan_j:
    add x9, x20, #1
    cmp x9, x22
    b.hs Lrp2_scan_none             // j + 1 < n
    mov x21, #0
Lrp2_scan_i:
    add x9, x21, #1
    cmp x9, x23
    b.hs Lrp2_scan_jn               // i + 1 < m
    madd x10, x20, x23, x21         // a: j m + i
    add x11, x10, x23               // b: (j + 1) m + i
    add x12, x11, #1                // c: (j + 1) m + i + 1
    add x13, x10, #1                // d: j m + i + 1
    ldr d0, [x27, x10, lsl #3]
    ldr d1, [x27, x11, lsl #3]
    ldr d2, [x27, x12, lsl #3]
    ldr d3, [x27, x13, lsl #3]
    ldr d4, [x25, x20, lsl #3]      // x[j]
    add x9, x20, #1
    ldr d5, [x25, x9, lsl #3]       // x[j + 1]
    ldr d6, [x26, x21, lsl #3]      // y[i]
    add x9, x21, #1
    ldr d7, [x26, x9, lsl #3]       // y[i + 1]
    BNF d0, d16, Lrp2_scan_in
    BNF d1, d16, Lrp2_scan_in
    BNF d2, d16, Lrp2_scan_in
    BNF d3, d16, Lrp2_scan_in
    BNF d4, d16, Lrp2_scan_in
    BNF d5, d16, Lrp2_scan_in
    BNF d6, d16, Lrp2_scan_in
    BNF d7, d16, Lrp2_scan_in
    stp d0, d1, [x24, #CS_Z]        // a, b
    stp d2, d3, [x24, #(CS_Z + 16)] // c, d
    stp d4, d5, [x24, #CS_X]        // a at x[j], b at x[j+1]
    stp d5, d4, [x24, #(CS_X + 16)] // c at x[j+1], d at x[j]
    stp d6, d6, [x24, #CS_Y]        // a, b at y[i]
    stp d7, d7, [x24, #(CS_Y + 16)] // c, d at y[i+1]
    fcmp d0, d8
    cset w10, ge                    // a above
    fcmp d1, d8
    cset w11, ge                    // b above
    fcmp d2, d8
    cset w12, ge                    // c above
    fcmp d3, d8
    cset w13, ge                    // d above
    eor w14, w10, w11               // e0
    eor w15, w11, w12               // e1
    orr w14, w14, w15, lsl #1
    eor w15, w13, w12               // e2
    orr w14, w14, w15, lsl #2
    eor w15, w10, w13               // e3
    orr w14, w14, w15, lsl #3       // the crossed edges
    cbz w14, Lrp2_scan_in
    cmp w14, #15
    b.eq Lrp2_scan_saddle
    rbit w15, w14
    clz w0, w15                     // the lower edge
    clz w15, w14
    mov w1, #31
    sub w1, w1, w15                 // the higher edge
    bl Lrp2_emit
    cbnz x0, Lrp2_scan_found
    b Lrp2_scan_in
Lrp2_scan_saddle:
    fadd d16, d0, d1                // m = ((a + b) + (c + d)) / 4
    fadd d17, d2, d3
    fadd d16, d16, d17
    LDK d17, FOUR
    fdiv d16, d16, d17
    fcmp d16, d8
    cset w15, ge                    // the centre above (NaN: not)
    cmp w15, w10
    b.ne 1f
    mov x0, #0                      // (e0, e1) then (e2, e3)
    mov x1, #1
    mov x9, #2
    mov x10, #3
    b 2f
1:  mov x0, #0                      // (e0, e3) then (e1, e2)
    mov x1, #3
    mov x9, #1
    mov x10, #2
2:  stp x9, x10, [sp, #96]          // the second pair across the call
    bl Lrp2_emit
    cbnz x0, Lrp2_scan_found
    ldp x0, x1, [sp, #96]
    bl Lrp2_emit
    cbnz x0, Lrp2_scan_found
Lrp2_scan_in:
    add x21, x21, #1
    b Lrp2_scan_i
Lrp2_scan_jn:
    add x20, x20, #1
    b Lrp2_scan_j
Lrp2_scan_none:
    mov x0, #0
Lrp2_scan_found:
    ldr d8, [sp, #88]
    ldr x27, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #112
    ret

// ---------------------------------------------------------------------
// Lrp2_level -- level k of a contour: L_k = zmin + (f64(k) * d) / f64(n
//   + 1); not finite is no level.
//   Inputs  : x0 = k, d8 = zmin, d9 = d, d11 = f64(n + 1) (the caller's)
//   Outputs : x0 = 1 and d0 = L_k when it is finite, else 0
//   Clobbers: x0, d0, d1, flags
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrp2_level:
    scvtf d0, x0
    fmul d0, d0, d9                 // f64(k) * d
    fdiv d0, d0, d11                // ... / f64(n + 1)
    fadd d0, d8, d0                 // zmin + ...
    mov x0, #0
    BNF d0, d1, 1f
    mov x0, #1
1:  ret

// ---------------------------------------------------------------------
// Lrp2_contour -- a contour series (2.14.6 "Series forms"):
//   `<g class="contour" fill="none" stroke-width="1.00">`, per level k =
//   1 .. n with a segment its group (the series colour, or with -1 the
//   map entry floor(256 k / (n + 1))) and segments, `</g>`; then with
//   labels each such level's `%g` at its first segment's midpoint. No
//   level when there is no finite cell, zmax = zmin or d = zmax - zmin
//   is not finite.
//   Inputs  : x0 = the series record; x28 = the state
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = record, x20 = k, x21 = n (levels), x22 =
//             usable, x24 = Lrp2_cs, d8 = zmin, d9 = d, d10 = L, d11 =
//             f64(n + 1), d12 = X, d13 = Y of a label
//   Frame   : 112 bytes (frame record + x19..x22, x24, pad, d8..d13)
// ---------------------------------------------------------------------
    .p2align 2
Lrp2_contour:
    stp x29, x30, [sp, #-112]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    str x24, [sp, #48]
    stp d8, d9, [sp, #64]
    stp d10, d11, [sp, #80]
    stp d12, d13, [sp, #96]
    mov x19, x0
    LADR x24, Lrp2_cs
    bl Lrp2_yaxis
    str x0, [x24, #CS_AXIS]
    ldr x9, [x19, #RTP_SR_N]
    ldr x10, [x19, #RTP_SR_M]
    ldr x11, [x19, #RTP_SR_DATA]
    add x12, x9, x10
    add x0, x11, x12, lsl #3        // Z
    mul x1, x9, x10
    bl Lrp2_zcheck                  // x0 usable, d0 zmin, d2 d
    mov x22, x0
    fmov d8, d0
    fmov d9, d2
    ldr x21, [x19, #RTP_SR_LEVELS]
    add x9, x21, #1
    scvtf d11, x9                   // f64(n + 1)
    PUTC Lrp2_s_gcontour
    cbz x22, 5f
    mov x20, #1
1:  cmp x20, x21
    b.hi 5f
    mov x0, x20
    bl Lrp2_level
    cbz x0, 4f                      // not finite: no level
    str d0, [x24, #CS_L]
    ldr x9, [x19, #RTP_SR_COLOR]
    tbz x9, #63, 2f                 // the series colour, else the map's
    // floor(256 k / (n + 1)) exactly for every k <= n: eight steps of
    // binary long division of the remainder k by n + 1 (no product
    // 256 k, which would overflow 64 bits for k >= 2^56).
    add x10, x21, #1                // n + 1 (unsigned)
    mov x11, x20                    // the remainder, < n + 1
    mov x0, #0
    mov x12, #8
3:  lsl x11, x11, #1                // < 2 (n + 1) <= 2^64
    lsl x0, x0, #1
    cmp x11, x10
    b.lo 31f
    sub x11, x11, x10
    orr x0, x0, #1
31: subs x12, x12, #1
    b.ne 3b
    bl _sea_plot_cmap
    mov w9, w0
2:  str x9, [x24, #CS_COLOR]
    str xzr, [x24, #CS_MODE]
    str xzr, [x24, #CS_OPEN]
    mov x0, x19
    bl Lrp2_scan
    ldr x9, [x24, #CS_OPEN]
    cbz x9, 4f                      // no segment: no group
    PUTC Lrp2_s_eg
4:  add x20, x20, #1
    b 1b
5:  PUTC Lrp2_s_eg
    // The labels: each level with a segment, ascending.
    cbz x22, 9f
    ldr x9, [x19, #RTP_SR_FLAG]
    cbz x9, 9f
    mov x20, #1
6:  cmp x20, x21
    b.hi 9f
    mov x0, x20
    bl Lrp2_level
    cbz x0, 8f
    fmov d10, d0
    str d0, [x24, #CS_L]
    mov x9, #1
    str x9, [x24, #CS_MODE]
    mov x0, x19
    bl Lrp2_scan
    cbz x0, 8f                      // no segment: no label
    fmov d12, d0
    fmov d13, d1
    add x0, x28, #RS_T0             // the level written %g
    mov w1, #'g'
    mov x2, #-1
    fmov d0, d10
    bl _sea_fmt_num
    mov x4, x0
    add x3, x28, #RS_T0
    LADR x0, Lrp2_s_clabel
    LADR x1, Lrp2_s_qy
    LADR x2, Lrp2_s_clabelend
    fmov d0, d12
    fmov d1, d13
    bl _sea_plot_textel
8:  add x20, x20, #1
    b 6b
9:  ldp d12, d13, [sp, #96]
    ldp d10, d11, [sp, #80]
    ldp d8, d9, [sp, #64]
    ldr x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #112
    ret

// =====================================================================
// Tables and literals
// =====================================================================
    .section __TEXT,__const
// The edges' corners (first, second): e0 a-b, e1 b-c, e2 d-c, e3 a-d.
Lrp2_edges:
    .byte 0, 1, 1, 2, 3, 2, 0, 3

    .section __TEXT,__cstring,cstring_literals
Lrp2_s_gbars:       .asciz "<g class=\"bars\" fill=\""
Lrp2_s_qgt:         .asciz "\">\n"
Lrp2_s_bar:         .asciz "<rect class=\"bar\" x=\""
Lrp2_s_qclose:      .asciz "\"/>\n"
Lrp2_s_eg:          .asciz "</g>\n"
Lrp2_s_image:       .asciz "<image class=\"image\" x=\""
Lrp2_s_href:        .asciz "\" preserveAspectRatio=\"none\" style=\"image-rendering:pixelated\" href=\"data:image/png;base64,"
Lrp2_s_cbimage:     .asciz "<image class=\"colorbar\" x=\""
Lrp2_s_cbbox:       .asciz "<rect class=\"colorbar-box\" x=\""
Lrp2_s_boxend:      .asciz "\" fill=\"none\" stroke=\"#262626\" stroke-width=\"1.00\"/>\n"
Lrp2_s_cbticks:     .asciz "<path class=\"colorbar-ticks\" d=\""
Lrp2_s_hm3:         .asciz " h-3.00"
Lrp2_s_ctick:       .asciz "<text class=\"ctick\" x=\""
Lrp2_s_ctickend:    .asciz "\" font-size=\"10\" text-anchor=\"start\">"
Lrp2_s_gcontour:    .asciz "<g class=\"contour\" fill=\"none\" stroke-width=\"1.00\">\n"
Lrp2_s_glevel:      .asciz "<g class=\"contour-level\" stroke=\""
Lrp2_s_seg:         .asciz "<line class=\"contour-segment\" x1=\""
Lrp2_s_qy1:         .asciz "\" y1=\""
Lrp2_s_qx2:         .asciz "\" x2=\""
Lrp2_s_qy2:         .asciz "\" y2=\""
Lrp2_s_clabel:      .asciz "<text class=\"contour-label\" x=\""
Lrp2_s_qy:          .asciz "\" y=\""
Lrp2_s_clabelend:   .asciz "\" font-size=\"10\" text-anchor=\"middle\">"

// ---------------------------------------------------------------------
// State: the colour map (built once) and its flag, the contour cell, the
// colorbar's axis (AS_*).
// ---------------------------------------------------------------------
.zerofill __DATA,__bss,Lrp2_cmap,(4 * RP2_CMAP_N),2
.zerofill __DATA,__bss,Lrp2_cmapok,8,3
.zerofill __DATA,__bss,Lrp2_cs,CS_SIZE,3
.zerofill __DATA,__bss,Lrp2_ac,AS_SIZE,3
