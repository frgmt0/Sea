// sea/tests/rt/arm64_macos/rt_plot_objects.s -- the Figure and Axes objects (DESIGN.md 2.14.5 FIGURE, PANEL, TWIN_Y; 2.14.6 "Objects", "Freeing", "Block sizes"; L-ke, L-lb): the fields of a new Figure (tag 3, count 1, both tables of capacity 8, the name retained), a panel (tag 4, the figure retained, its record and occupancy bits), twin_y (a new twin record of kind 1 with cycle index 1; twin_y again and twin_y of the twin return that record through new handles, Decision 134 (a)), the axes table doubling from 8 to 16 records with the records kept, and sea_free of both tags: an Axes freed after its Figure handle frees the figure with the last handle, releasing the name; the live and freed counts at each step. Heap check count: the name string, 2 figures and 13 Axes made, none live
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
// Lrec -- print an axes record: kind base twin row col rowspan colspan
// cycle. x0 = the record. Callee-saved used: x19. Frame 32 bytes.
    .p2align 2
Lrec:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    ldr x9, [x19, #AX_KIND]
    KV " kind ", x9
    ldr x9, [x19, #AX_BASE]
    KV " base ", x9
    ldr x9, [x19, #AX_TWIN]
    KV " twin ", x9
    ldr x9, [x19, #AX_ROW]
    KV " row ", x9
    ldr x9, [x19, #AX_COL]
    KV " col ", x9
    ldr x9, [x19, #AX_RSPAN]
    KV " span ", x9
    ldr x9, [x19, #AX_CSPAN]
    KV "x", x9
    ldr x9, [x19, #AX_CYC]
    KV " cycle ", x9
    TXT "\n"
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Lnewpanel -- panel(x0 fig, x1 row, x2 col, x3 rowspan, x4 colspan)
// with site 0. Frame 16 bytes.
    .p2align 2
Lnewpanel:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x5, #0
    bl _sea_panel
    ldp x29, x30, [sp], #16
    ret

    .globl _sea_main
    .p2align 2
_sea_main:
    PROLOGUE
    LIVE x27                        // the live count at the start
    FREED x28                       // and the freed count
    // A dynamic name string: _sea_str_i64(42) = "42" (count 1).
    mov x0, #42
    mov x1, #0
    bl _sea_str_i64
    mov x21, x0
    // fig = figure(2, 3, name, 640, 480)
    mov x0, #2
    mov x1, #3
    mov x2, x21
    mov x3, #640
    mov x4, #480
    mov x5, #0
    bl _sea_figure
    mov x19, x0
    ldrb w9, [x19, #SEA_OBJ_TAG]
    KV "figure: tag ", x9
    ldr x9, [x19, #SEA_OBJ_RC]
    KV " count ", x9
    LIVE x9
    sub x9, x9, x27
    KV " live +", x9
    TXT "\n"
    ldr x9, [x19, #F_NROWS]
    KV "fields:", x9
    ldr x9, [x19, #F_NCOLS]
    KV " ", x9
    ldr x9, [x19, #F_W]
    KV " ", x9
    ldr x9, [x19, #F_H]
    KV " ", x9
    ldr x9, [x19, #F_NAX]
    KV " axes ", x9
    ldr x9, [x19, #F_AXCAP]
    KV "/", x9
    ldr x9, [x19, #F_NSR]
    KV " series ", x9
    ldr x9, [x19, #F_SRCAP]
    KV "/", x9
    ldr x9, [x19, #F_NAME]
    cmp x9, x21
    cset x9, eq
    KV " name kept ", x9
    ldr x9, [x21, #SEA_OBJ_RC]
    KV " name count ", x9
    TXT "\n"
    // ax = panel(fig, 0, 1, rowspan: 2)
    mov x0, x19
    mov x1, #0
    mov x2, #1
    mov x3, #2
    mov x4, #1
    bl Lnewpanel
    mov x20, x0
    ldrb w9, [x20, #SEA_OBJ_TAG]
    KV "panel: tag ", x9
    ldr x9, [x20, #SEA_OBJ_RC]
    KV " count ", x9
    ldr x9, [x20, #A_FIG]
    cmp x9, x19
    cset x9, eq
    KV " fig ", x9
    ldr x9, [x20, #A_IDX]
    KV " idx ", x9
    ldr x9, [x19, #SEA_OBJ_RC]
    KV " fig count ", x9
    LIVE x9
    sub x9, x9, x27
    KV " live +", x9
    TXT "\n"
    ldr x9, [x19, #(F_OCC + 0)]
    KV "occupancy: ", x9
    ldr x9, [x19, #(F_OCC + 8)]
    KV " ", x9
    ldr x9, [x19, #(F_OCC + 16)]
    KV " ", x9
    TXT "\n"
    TXT "record 0:"
    ldr x0, [x19, #F_AXT]
    bl Lrec
    // tw = twin_y(ax): record 1
    mov x0, x20
    mov x1, #0
    bl _sea_twin_y
    mov x22, x0
    ldr x9, [x22, #A_IDX]
    KV "twin: idx ", x9
    ldr x9, [x19, #F_NAX]
    KV " axes ", x9
    ldr x9, [x19, #SEA_OBJ_RC]
    KV " fig count ", x9
    TXT "\n"
    TXT "record 0:"
    ldr x0, [x19, #F_AXT]
    bl Lrec
    TXT "record 1:"
    ldr x0, [x19, #F_AXT]
    add x0, x0, #256
    bl Lrec
    // twin_y(ax) again and twin_y(tw): the same record, new handles.
    mov x0, x20
    mov x1, #0
    bl _sea_twin_y
    mov x23, x0
    mov x0, x22
    mov x1, #0
    bl _sea_twin_y
    mov x24, x0
    ldr x9, [x23, #A_IDX]
    KV "again: idx ", x9
    ldr x9, [x24, #A_IDX]
    KV " of the twin: idx ", x9
    cmp x23, x22
    cset x9, ne
    KV " new handles ", x9
    ldr x9, [x19, #F_NAX]
    KV " axes ", x9
    ldr x9, [x19, #SEA_OBJ_RC]
    KV " fig count ", x9
    LIVE x9
    sub x9, x9, x27
    KV " live +", x9
    TXT "\n"
    REL x23
    REL x24
    ldr x9, [x19, #SEA_OBJ_RC]
    KV "two released: fig count ", x9
    LIVE x9
    sub x9, x9, x27
    KV " live +", x9
    FREED x9
    sub x9, x9, x28
    KV " freed +", x9
    TXT "\n"
    // The Figure handle first, then the Axes: the figure lives on.
    REL x19
    LIVE x9
    sub x9, x9, x27
    KV "figure handle released: live +", x9
    ldr x9, [x19, #SEA_OBJ_RC]
    KV " fig count ", x9
    TXT "\n"
    REL x22
    LIVE x9
    sub x9, x9, x27
    KV "twin released: live +", x9
    ldr x9, [x21, #SEA_OBJ_RC]
    KV " name count ", x9
    TXT "\n"
    REL x20
    LIVE x9
    sub x9, x9, x27
    KV "last handle released: live +", x9
    FREED x9
    sub x9, x9, x28
    KV " freed +", x9
    ldr x9, [x21, #SEA_OBJ_RC]
    KV " name count ", x9
    TXT "\n"
    // A 3x3 figure with 9 panels: the axes table doubles at the 9th.
    mov x0, #3
    mov x1, #3
    LA x2, Lempty
    mov x3, #300
    mov x4, #300
    mov x5, #0
    bl _sea_figure
    mov x19, x0
    mov x25, #0                     // panel number r * 3 + c
1:  mov x0, x19
    mov x9, #3
    udiv x1, x25, x9
    msub x2, x1, x9, x25
    mov x3, #1
    mov x4, #1
    bl Lnewpanel
    REL x0                          // the handle is dropped at once
    ldr x9, [x19, #F_NAX]
    KV "axes ", x9
    ldr x9, [x19, #F_AXCAP]
    KV "/", x9
    TXT "\n"
    add x25, x25, #1
    cmp x25, #9
    b.lo 1b
    TXT "record 7:"
    ldr x0, [x19, #F_AXT]
    add x0, x0, #(7 * 256)
    bl Lrec
    TXT "record 8:"
    ldr x0, [x19, #F_AXT]
    add x0, x0, #(8 * 256)
    bl Lrec
    ldr x9, [x19, #(F_OCC + 0)]
    KV "occupancy: ", x9
    ldr x9, [x19, #(F_OCC + 8)]
    KV " ", x9
    ldr x9, [x19, #(F_OCC + 16)]
    KV " ", x9
    TXT "\n"
    REL x19
    REL x21
    LIVE x9
    sub x9, x9, x27
    KV "end: live +", x9
    FREED x9
    sub x9, x9, x28
    KV " freed +", x9
    TXT "\n"
    EPILOGUE

    .section __DATA,__const
    SSTR Lempty, 0, ""
    SSTR Lfile, 5, "p.sea"
    .p2align 3
    .globl _sea_sites
_sea_sites:
    .quad Lfile, 7
