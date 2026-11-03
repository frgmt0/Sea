// sea/tests/rt/arm64_macos/rt_plot_props.s -- the property entries (DESIGN.md 2.14.5 XLABEL .. AXIS_EQUAL; 2.14.6 "Objects"; L-km): xlabel, title, grid, legend, xlim, x_ticks and axis_equal of a twin act on the base record, ylabel, ylim, y_ticks and y_reverse on the twin own record; a string set twice keeps the last (the previous released); every legend location name and its code (best is 5); grid on and off; the limit values and flags; category labels retained, the previous ones released, an empty list returning to none (block 0, count 0); the strings released when the figure is freed. Heap check count: 3 strings, the figure, 2 Axes, none live
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

// ---- test helpers (the same block in every rt_plot_* test) -------------
// A static string object (rt.inc SEA_STR_*): count SEA_RC_STATIC, tag, length, bytes.
.macro SSTR label, len, text
    .p2align 3
\label:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad \len
    .ascii "\text"
.endm
// A static dynamic-f64 vector of n elements (rt.inc SEA_ARR_*); the
// element bit patterns follow the macro (n .quad values).
.macro FVEC label, n
    .p2align 6
\label:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_ARRAY, SEA_EK_F64, 1, 0, 0, 0, 0, 0
    .quad \n, 1, \n, \label + SEA_ARR_SIZE, 8, 0
.endm
// A static str vector of n elements; the string pointers follow.
.macro SVEC label, n
    .p2align 6
\label:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_ARRAY, SEA_EK_STR, 1, 0, 0, 0, 0, 0
    .quad \n, 1, \n, \label + SEA_ARR_SIZE, 8, 0
.endm
// The address of a label.
.macro LA reg, label
    adrp \reg, \label@PAGE
    add \reg, \reg, \label@PAGEOFF
.endm
// Load a 64-bit constant into a register.
.macro LI reg, val
    movz \reg, #((\val) & 0xffff)
    movk \reg, #(((\val) >> 16) & 0xffff), lsl #16
    movk \reg, #(((\val) >> 32) & 0xffff), lsl #32
    movk \reg, #(((\val) >> 48) & 0xffff), lsl #48
.endm
// Load the f64 with the given bits into a d register (x9 clobbered).
.macro LF dreg, bits
    LI x9, \bits
    fmov \dreg, x9
.endm
// Print a literal text (x0-x17 clobbered).
.macro TXT text
    .pushsection __TEXT,__cstring,cstring_literals
Ltxt\@: .asciz "\text"
    .popsection
    LA x0, Ltxt\@
    bl Lput_cstr
.endm
// Print a literal text, then a register in signed decimal (x0-x17 clobbered;
// reg must not be x0-x17 unless it is x1).
.macro KV text, reg
    mov x1, \reg
    .pushsection __TEXT,__cstring,cstring_literals
Lkv\@: .asciz "\text"
    .popsection
    LA x0, Lkv\@
    bl Lput_kv
.endm
// The live-object and freed-object counters of rt_mem.s into a register.
.macro LIVE reg
    adrp \reg, _sea_live@PAGE
    ldr \reg, [\reg, _sea_live@PAGEOFF]
.endm
.macro FREED reg
    adrp \reg, _sea_freed@PAGE
    ldr \reg, [\reg, _sea_freed@PAGEOFF]
.endm
// The release sequence of pass 4 (DESIGN.md 4.9) on the object in reg:
// the count drops by one unless static, _sea_free at 0 (x0-x17 clobbered).
.macro REL reg
    mov x0, \reg
    ldr x10, [x0]
    cbz x10, Lrel\@
    subs x10, x10, #1
    str x10, [x0]
    b.ne Lrel\@
    bl _sea_free
Lrel\@:
.endm
// _sea_main's frame: the frame record, x19-x28 (all callee-saved) and 16
// bytes of scratch at sp+96.
.macro PROLOGUE
    stp x29, x30, [sp, #-112]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp x27, x28, [sp, #80]
.endm
.macro EPILOGUE
    ldp x27, x28, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #112
    ret
.endm
// The private layouts of DESIGN.md 2.14.6 "Objects" (L-kw: tests/rt reads
// these offsets).
.equ F_NROWS, 16
.equ F_NCOLS, 24
.equ F_W, 32
.equ F_H, 40
.equ F_NAME, 48
.equ F_NAX, 56
.equ F_AXCAP, 64
.equ F_AXT, 72
.equ F_NSR, 80
.equ F_SRCAP, 88
.equ F_SRT, 96
.equ F_OCC, 192
.equ A_FIG, 16
.equ A_IDX, 24
.equ AX_KIND, 0
.equ AX_BASE, 8
.equ AX_TWIN, 16
.equ AX_ROW, 24
.equ AX_COL, 32
.equ AX_RSPAN, 40
.equ AX_CSPAN, 48
.equ AX_TITLE, 56
.equ AX_XLAB, 64
.equ AX_YLAB, 72
.equ AX_FLAGS, 80
.equ AX_LEG, 88
.equ AX_XLO, 96
.equ AX_XHI, 104
.equ AX_YLO, 112
.equ AX_YHI, 120
.equ AX_XCAT, 128
.equ AX_NXCAT, 136
.equ AX_YCAT, 144
.equ AX_NYCAT, 152
.equ AX_CYC, 160
.equ SR_KIND, 0
.equ SR_AX, 8
.equ SR_COLOR, 16
.equ SR_LINE, 24
.equ SR_MARK, 32
.equ SR_WIDTH, 40
.equ SR_LABEL, 48
.equ SR_N, 56
.equ SR_M, 64
.equ SR_DATA, 72
.equ SR_XPOS, 96

    .section __TEXT,__text,regular,pure_instructions

// Lput_cstr -- print a NUL-terminated text. x0 = text. Clobbers x0-x17.
// Callee-saved used: x19 (the text). Frame 32 bytes.
    .p2align 2
Lput_cstr:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    bl _strlen                  // its length
    mov x1, x0
    mov x0, x19
    bl _sea_out_write           // into the standard-output buffer
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Lput_dec -- print x0 as a signed decimal. Clobbers x0-x17. Frame 48
// bytes (frame record, 32 bytes of digits).
    .p2align 2
Lput_dec:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    add x9, sp, #48             // digits right to left from the end
    cmp x0, #0
    cset w11, lt                // negative?
    cneg x10, x0, lt            // magnitude (2^63 exact as unsigned)
    mov x12, #10
1:  udiv x13, x10, x12
    msub x14, x13, x12, x10     // the next digit
    add w14, w14, #'0'
    strb w14, [x9, #-1]!
    mov x10, x13
    cbnz x10, 1b
    cbz w11, 2f
    mov w14, #'-'
    strb w14, [x9, #-1]!
2:  mov x0, x9
    add x1, sp, #48
    sub x1, x1, x9              // the number of bytes
    bl _sea_out_write
    ldp x29, x30, [sp], #48
    ret

// Lput_kv -- print a text, then x1 in signed decimal. x0 = text. Clobbers
// x0-x17. Callee-saved used: x19 (the value). Frame 32 bytes.
    .p2align 2
Lput_kv:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x1
    bl Lput_cstr
    mov x0, x19
    bl Lput_dec
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Lput_hexn -- print the low x1 hexadecimal digits of x0 in lower case.
// Clobbers x0-x17. Frame 48 bytes (frame record, 32 bytes of digits).
    .p2align 2
Lput_hexn:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    add x9, sp, #16
    mov x10, x1
1:  and x11, x0, #0xf           // the lowest digit, written right to left
    add x12, x11, #'0'
    add x13, x11, #('a' - 10)
    cmp x11, #10
    csel x12, x13, x12, hs
    sub x10, x10, #1
    strb w12, [x9, x10]
    lsr x0, x0, #4
    cbnz x10, 1b
    mov x0, x9
    bl _sea_out_write           // x1 = the count, still
    ldp x29, x30, [sp], #48
    ret

// Lput_str -- print a string object's bytes between [ and ] (`-` for 0).
// x0 = the object. Clobbers x0-x17. Callee-saved used: x19. Frame 32.
    .p2align 2
Lput_str:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    cbnz x19, 1f
    LA x0, Lput_s_dash
    mov x1, #1
    bl _sea_out_write
    b 2f
1:  LA x0, Lput_s_lb
    mov x1, #1
    bl _sea_out_write
    add x0, x19, #SEA_STR_BYTES
    ldr x1, [x19, #SEA_STR_LEN]
    bl _sea_out_write
    LA x0, Lput_s_rb
    mov x1, #1
    bl _sea_out_write
2:  ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Ldump -- print the whole file at the NUL-terminated path x0 (at most
// 1 MiB). Clobbers x0-x17. Callee-saved used: x19 (descriptor), x20
// (bytes read). Frame 32 bytes.
    .p2align 2
Ldump:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov w1, #0                  // O_RDONLY
    bl _open
    mov w19, w0
    mov x20, #0
1:  mov w0, w19                 // read until end of file
    LA x1, Ldump_buf
    add x1, x1, x20
    mov x2, #1048576
    sub x2, x2, x20
    bl _read
    cmp x0, #0
    b.le 2f
    add x20, x20, x0
    b 1b
2:  mov w0, w19
    bl _close
    LA x0, Ldump_buf
    mov x1, x20
    bl _sea_out_write
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

    .section __TEXT,__const
Lput_s_lb:   .ascii "["
Lput_s_rb:   .ascii "]"
Lput_s_dash: .ascii "-"
.zerofill __DATA,__bss,Ldump_buf,1048576,4
    .section __TEXT,__text,regular,pure_instructions
// ---- end of the test helpers ------------------------------------------
// Lstr3 -- print the counts of the strings in x22, x23, x24. Frame 16.
    .p2align 2
Lstr3:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    ldr x9, [x22, #SEA_OBJ_RC]
    KV "counts ", x9
    ldr x9, [x23, #SEA_OBJ_RC]
    KV " ", x9
    ldr x9, [x24, #SEA_OBJ_RC]
    KV " ", x9
    TXT "\n"
    ldp x29, x30, [sp], #16
    ret

// Lrecp -- print an axes record's properties. x0 = record. Callee-saved
// used: x19 (record), x20 (label index). Frame 32 bytes.
    .p2align 2
Lrecp:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    TXT " title "
    ldr x0, [x19, #AX_TITLE]
    bl Lput_str
    TXT " xlabel "
    ldr x0, [x19, #AX_XLAB]
    bl Lput_str
    TXT " ylabel "
    ldr x0, [x19, #AX_YLAB]
    bl Lput_str
    ldr x9, [x19, #AX_FLAGS]
    KV " flags ", x9
    ldr x9, [x19, #AX_LEG]
    KV " legend ", x9
    TXT " x "
    ldr x0, [x19, #AX_XLO]
    mov x1, #16
    bl Lput_hexn
    TXT " "
    ldr x0, [x19, #AX_XHI]
    mov x1, #16
    bl Lput_hexn
    TXT " y "
    ldr x0, [x19, #AX_YLO]
    mov x1, #16
    bl Lput_hexn
    TXT " "
    ldr x0, [x19, #AX_YHI]
    mov x1, #16
    bl Lput_hexn
    ldr x9, [x19, #AX_NXCAT]
    KV " xcat ", x9
    mov x20, #0
1:  ldr x9, [x19, #AX_NXCAT]
    cmp x20, x9
    b.hs 2f
    TXT " "
    ldr x9, [x19, #AX_XCAT]
    ldr x0, [x9, x20, lsl #3]
    bl Lput_str
    add x20, x20, #1
    b 1b
2:  ldr x9, [x19, #AX_XCAT]
    cmp x9, #0
    cset x9, ne
    KV " block ", x9
    ldr x9, [x19, #AX_NYCAT]
    KV " ycat ", x9
    mov x20, #0
3:  ldr x9, [x19, #AX_NYCAT]
    cmp x20, x9
    b.hs 4f
    TXT " "
    ldr x9, [x19, #AX_YCAT]
    ldr x0, [x9, x20, lsl #3]
    bl Lput_str
    add x20, x20, #1
    b 3b
4:  TXT "\n"
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Lleg -- legend(x21 = the twin, x0 = loc), then print the base's code.
// Frame 16 bytes.
    .p2align 2
Lleg:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x1, x0
    mov x0, x21
    mov x2, #0
    bl _sea_legend
    ldr x9, [x19, #F_AXT]
    ldr x9, [x9, #AX_LEG]
    KV " ", x9
    ldp x29, x30, [sp], #16
    ret

    .globl _sea_main
    .p2align 2
_sea_main:
    PROLOGUE
    // The strings "1", "2", "3" (count 1 each).
    mov x0, #1
    mov x1, #0
    bl _sea_str_i64
    mov x22, x0
    mov x0, #2
    mov x1, #0
    bl _sea_str_i64
    mov x23, x0
    mov x0, #3
    mov x1, #0
    bl _sea_str_i64
    mov x24, x0
    // fig, ax = panel(fig, 0, 0), tw = twin_y(ax)
    mov x0, #1
    mov x1, #1
    LA x2, Lempty
    mov x3, #960
    mov x4, #720
    mov x5, #0
    bl _sea_figure
    mov x19, x0
    mov x0, x19
    mov x1, #0
    mov x2, #0
    mov x3, #1
    mov x4, #1
    mov x5, #0
    bl _sea_panel
    mov x20, x0
    mov x0, x20
    mov x1, #0
    bl _sea_twin_y
    mov x21, x0
    // xlabel(tw, "1"), then xlabel(ax, "2"): the base keeps "2"
    mov x0, x21
    mov x1, x22
    bl _sea_xlabel
    bl Lstr3
    mov x0, x20
    mov x1, x23
    bl _sea_xlabel
    bl Lstr3
    // ylabel(tw, "3"), ylabel(ax, "L"), title(tw, "T")
    mov x0, x21
    mov x1, x24
    bl _sea_ylabel
    mov x0, x20
    LA x1, LL
    bl _sea_ylabel
    mov x0, x21
    LA x1, LT
    bl _sea_title
    bl Lstr3
    // every legend location
    TXT "legend"
    LA x0, Lnorth
    bl Lleg
    LA x0, Lsouth
    bl Lleg
    LA x0, Least
    bl Lleg
    LA x0, Lwest
    bl Lleg
    LA x0, Lne
    bl Lleg
    LA x0, Lnw
    bl Lleg
    LA x0, Lse
    bl Lleg
    LA x0, Lsw
    bl Lleg
    LA x0, Lbest
    bl Lleg
    TXT "\n"
    // grid(tw, on: true), grid(ax, on: false): flags bit 0
    mov x0, x21
    mov x1, #1
    bl _sea_grid
    ldr x9, [x19, #F_AXT]
    ldr x9, [x9, #AX_FLAGS]
    KV "grid on ", x9
    mov x0, x20
    mov x1, #0
    bl _sea_grid
    ldr x9, [x19, #F_AXT]
    ldr x9, [x9, #AX_FLAGS]
    KV " off ", x9
    TXT "\n"
    mov x0, x21
    mov x1, #1
    bl _sea_grid
    // xlim(tw, -1, 2); ylim(tw, 0, 40); ylim(ax, 0.5, 1.5)
    mov x0, x21
    fmov d0, #-1.0
    fmov d1, #2.0
    mov x1, #0
    bl _sea_xlim
    mov x0, x21
    movi d0, #0
    LF d1, 0x4044000000000000
    mov x1, #0
    bl _sea_ylim
    mov x0, x20
    fmov d0, #0.5
    fmov d1, #1.5
    mov x1, #0
    bl _sea_ylim
    // y_reverse(tw), axis_equal(tw)
    mov x0, x21
    bl _sea_y_reverse
    mov x0, x21
    bl _sea_axis_equal
    // x_ticks(tw, ["1", "2"]), x_ticks(ax, ["3"]), y_ticks(tw, ["L"])
    LA x9, Lv12
    str x22, [x9, #SEA_ARR_SIZE]
    str x23, [x9, #(SEA_ARR_SIZE + 8)]
    LA x9, Lv3
    str x24, [x9, #SEA_ARR_SIZE]
    mov x0, x21
    LA x1, Lv12
    mov x2, #0
    bl _sea_x_ticks
    bl Lstr3
    mov x0, x20
    LA x1, Lv3
    mov x2, #0
    bl _sea_x_ticks
    bl Lstr3
    mov x0, x21
    LA x1, LvL
    mov x2, #0
    bl _sea_y_ticks
    TXT "base:"
    ldr x0, [x19, #F_AXT]
    bl Lrecp
    TXT "twin:"
    ldr x0, [x19, #F_AXT]
    add x0, x0, #256
    bl Lrecp
    // x_ticks(ax, an empty list): none again
    mov x0, x20
    LA x1, Lv0
    mov x2, #0
    bl _sea_x_ticks
    bl Lstr3
    TXT "base:"
    ldr x0, [x19, #F_AXT]
    bl Lrecp
    REL x21
    REL x20
    REL x19
    TXT "after the figure: "
    bl Lstr3
    REL x22
    REL x23
    REL x24
    EPILOGUE

    .section __DATA,__data
    SVEC Lv12, 2
    .quad 0, 0
    SVEC Lv3, 1
    .quad 0
    .section __DATA,__const
    SVEC LvL, 1
    .quad LL
    SVEC Lv0, 0
    SSTR Lempty, 0, ""
    SSTR LL, 1, "L"
    SSTR LT, 1, "T"
    SSTR Lnorth, 5, "north"
    SSTR Lsouth, 5, "south"
    SSTR Least, 4, "east"
    SSTR Lwest, 4, "west"
    SSTR Lne, 9, "northeast"
    SSTR Lnw, 9, "northwest"
    SSTR Lse, 9, "southeast"
    SSTR Lsw, 9, "southwest"
    SSTR Lbest, 4, "best"
    SSTR Lfile, 5, "p.sea"
    .p2align 3
    .globl _sea_sites
_sea_sites:
    .quad Lfile, 7
