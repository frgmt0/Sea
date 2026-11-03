// sea/tests/rt/arm64_macos/rt_plot_ticks.s -- the tick rules of DESIGN.md 2.14.6 (limits rules 1, 2, 4, 5, tick labels with `%.{p}f`, `%g` for steps >= 1e6 or < 1e-4, Decision 142's `%.{q}g`): six panels with the ranges 0 .. 6 and 0.1 .. 0.95; -3 .. 7 and a zero range at 0; a zero range at 5 and 0 .. 3e6; 0 .. 3e-5 and 1 .. 1.00001 (repeated `%g` texts: `%.7g`); categories a b c with no data and explicit limits 0.5 .. 3.7; 1e12 .. 1e12 + 5e6 (`%.7g`) and no finite y (0 .. 1). Every Axes value is dropped before save_svg (L-ke). The SVG is filtered: `panel` per panel group, then `xtick TEXT` / `ytick TEXT` per tick label. The expected texts were derived with a Python transcription of the rules, operation for operation (not from the runtime)
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


// Lticks -- print the panel and tick-label lines of the file at x0 (read
// into Ldump_buf by Ldump's loop): `panel` for each `<g class="panel"`
// line, `xtick T` / `ytick T` for each tick text element (T between `>`
// and `</text>`). Clobbers x0-x17. Callee-saved used: x19 = cursor, x20 =
// end, x21 = line start. Frame 48 bytes.
    .p2align 2
Lticks:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    mov w1, #0
    bl _open
    mov w21, w0
    mov x20, #0
1:  mov w0, w21
    LA x1, Ldump_buf
    add x1, x1, x20
    mov x2, #1048576
    sub x2, x2, x20
    bl _read
    cmp x0, #0
    b.le 2f
    add x20, x20, x0
    b 1b
2:  mov w0, w21
    bl _close
    LA x19, Ldump_buf
    add x20, x19, x20
Lticks_line:
    cmp x19, x20
    b.hs Lticks_done
    mov x21, x19                // the line start
3:  ldrb w9, [x19], #1          // to the end of the line
    cmp w9, #10
    b.ne 3b
    mov x0, x21
    LA x1, Lp_panel
    mov x2, #16
    bl _strncmp
    cbnz w0, 4f
    TXT "panel\n"
    b Lticks_line
4:  mov x0, x21
    LA x1, Lp_xtick
    mov x2, #19
    bl _strncmp
    cbz w0, 5f
    mov x0, x21
    LA x1, Lp_ytick
    mov x2, #19
    bl _strncmp
    cbnz w0, Lticks_line
    TXT "ytick "
    b 6f
5:  TXT "xtick "
6:  mov x9, x21                 // the text: after the first `>`
7:  ldrb w10, [x9], #1
    cmp w10, #'>'
    b.ne 7b
    mov x0, x9
    sub x1, x19, x9
    sub x1, x1, #8              // without `</text>` and LF
    bl _sea_out_write
    TXT "\n"
    b Lticks_line
Lticks_done:
    ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

    .globl _sea_main
    .p2align 2
_sea_main:
    PROLOGUE
    // figure(1, 6, width: 2400, height: 400)
    mov x0, #1
    mov x1, #6
    LA x2, Lempty
    mov x3, #2400
    mov x4, #400
    mov x5, #0
    bl _sea_figure
    mov x19, x0

    // panel 0
    mov x0, x19
    mov x1, #0
    mov x2, #0
    mov x3, #1
    mov x4, #1
    mov x5, #0
    bl _sea_panel
    mov x20, x0
    mov x0, x20
    LA x1, Lx0
    LA x2, Ly0
    LA x3, Ldash
    LA x4, Lempty
    fmov d0, #1.0
    LA x5, Lempty
    mov x6, #0
    bl _sea_plot
    REL x20
    // panel 1
    mov x0, x19
    mov x1, #0
    mov x2, #1
    mov x3, #1
    mov x4, #1
    mov x5, #0
    bl _sea_panel
    mov x20, x0
    mov x0, x20
    LA x1, Lx1
    LA x2, Ly1
    LA x3, Ldash
    LA x4, Lempty
    fmov d0, #1.0
    LA x5, Lempty
    mov x6, #0
    bl _sea_plot
    REL x20
    // panel 2
    mov x0, x19
    mov x1, #0
    mov x2, #2
    mov x3, #1
    mov x4, #1
    mov x5, #0
    bl _sea_panel
    mov x20, x0
    mov x0, x20
    LA x1, Lx2
    LA x2, Ly2
    LA x3, Ldash
    LA x4, Lempty
    fmov d0, #1.0
    LA x5, Lempty
    mov x6, #0
    bl _sea_plot
    REL x20
    // panel 3
    mov x0, x19
    mov x1, #0
    mov x2, #3
    mov x3, #1
    mov x4, #1
    mov x5, #0
    bl _sea_panel
    mov x20, x0
    mov x0, x20
    LA x1, Lx3
    LA x2, Ly3
    LA x3, Ldash
    LA x4, Lempty
    fmov d0, #1.0
    LA x5, Lempty
    mov x6, #0
    bl _sea_plot
    REL x20
    // panel 4
    mov x0, x19
    mov x1, #0
    mov x2, #4
    mov x3, #1
    mov x4, #1
    mov x5, #0
    bl _sea_panel
    mov x20, x0
    mov x0, x20
    LA x1, Lcats
    mov x2, #0
    bl _sea_x_ticks
    mov x0, x20
    LF d0, 0x3FE0000000000000
    LF d1, 0x400D99999999999A
    mov x1, #0
    bl _sea_ylim
    REL x20
    // panel 5
    mov x0, x19
    mov x1, #0
    mov x2, #5
    mov x3, #1
    mov x4, #1
    mov x5, #0
    bl _sea_panel
    mov x20, x0
    mov x0, x20
    LA x1, Lx5
    LA x2, Lnan2
    LA x3, Ldash
    LA x4, Lempty
    fmov d0, #1.0
    LA x5, Lempty
    mov x6, #0
    bl _sea_plot
    REL x20

    mov x0, x19
    LA x1, Lpath
    mov x2, #0
    bl _sea_save_svg
    REL x19
    LA x0, Lcpath
    bl Lticks
    EPILOGUE

    .section __TEXT,__cstring,cstring_literals
Lcpath:    .asciz "k.svg"
Lp_panel:  .asciz "<g class=\"panel\""
Lp_xtick:  .asciz "<text class=\"xtick\""
Lp_ytick:  .asciz "<text class=\"ytick\""
    .section __DATA,__const
    SSTR Lempty, 0, ""
    SSTR Ldash, 1, "-"
    SSTR Lpath, 5, "k.svg"
    SSTR La, 1, "a"
    SSTR Lb, 1, "b"
    SSTR Lc, 1, "c"
    SVEC Lcats, 3
    .quad La, Lb, Lc

    FVEC Lx0, 2
    .quad 0x0000000000000000, 0x4018000000000000
    FVEC Ly0, 2
    .quad 0x3FB999999999999A, 0x3FEE666666666666
    FVEC Lx1, 2
    .quad 0xC008000000000000, 0x401C000000000000
    FVEC Ly1, 2
    .quad 0x0000000000000000, 0x0000000000000000
    FVEC Lx2, 2
    .quad 0x4014000000000000, 0x4014000000000000
    FVEC Ly2, 2
    .quad 0x0000000000000000, 0x4146E36000000000
    FVEC Lx3, 2
    .quad 0x0000000000000000, 0x3EFF75104D551D69
    FVEC Ly3, 2
    .quad 0x3FF0000000000000, 0x3FF0000A7C5AC472
    FVEC Lx5, 2
    .quad 0x426D1A94A2000000, 0x426D1A9E2B680000
    FVEC Lnan2, 2
    .quad 0x7FF8000000000000, 0x7FF8000000000000
    SSTR Lfile, 5, "p.sea"
    .p2align 3
    .globl _sea_sites
_sea_sites:
    .quad Lfile, 7
