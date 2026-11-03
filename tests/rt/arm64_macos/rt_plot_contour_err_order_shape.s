// sea/tests/rt/arm64_macos/rt_plot_contour_err_order_shape.s -- sea_contour with a wrong Z shape, levels 0 and a bad colour: the shape first (2.14.2: contour checks the shape of Z, levels, color)
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

// ---- extras of the 9c tests ------------------------------------------------
// A static dynamic-f64 matrix of rows x cols (column-major elements follow).
.macro FMAT label, rows, cols
    .p2align 6
\label:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_ARRAY, SEA_EK_F64, 2, 0, 0, 0, 0, 0
    .quad \rows, \cols, (\rows) * (\cols), \label + SEA_ARR_SIZE, 8, 0
.endm
.equ SR_LEVELS, 80
.equ SR_FLAG, 88
    .section __TEXT,__text,regular,pure_instructions
// Lput_HEX8 -- print the low 32 bits of x0 as 8 upper-case hexadecimal
// digits. Clobbers x0-x17. Frame 32 bytes (frame record, 8 digits).
    .p2align 2
Lput_HEX8:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    add x9, sp, #16
    mov x10, #8
1:  and x11, x0, #0xf           // the lowest digit, written right to left
    add x12, x11, #'0'
    add x13, x11, #('A' - 10)
    cmp x11, #10
    csel x12, x13, x12, hs
    sub x10, x10, #1
    strb w12, [x9, x10]
    lsr x0, x0, #4
    cbnz x10, 1b
    mov x0, x9
    mov x1, #8
    bl _sea_out_write
    ldp x29, x30, [sp], #32
    ret
// Lsr9 -- print series record x0 (index x1): kind ax colour (16 hex
// digits) width label n m data levels flag. Callee-saved used: x19.
// Frame 32 bytes.
    .p2align 2
Lsr9:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    KV "s", x1
    ldr x9, [x19, #SR_KIND]
    KV ": kind ", x9
    ldr x9, [x19, #SR_AX]
    KV " ax ", x9
    TXT " colour "
    ldr x0, [x19, #SR_COLOR]
    mov x1, #16
    bl Lput_hexn
    TXT " width "
    ldr x0, [x19, #SR_WIDTH]
    mov x1, #16
    bl Lput_hexn
    TXT " label "
    ldr x0, [x19, #SR_LABEL]
    bl Lput_str
    ldr x9, [x19, #SR_N]
    KV " n ", x9
    ldr x9, [x19, #SR_M]
    KV " m ", x9
    ldr x9, [x19, #SR_DATA]
    cmp x9, #0
    cset x9, ne
    KV " data ", x9
    ldr x9, [x19, #SR_LEVELS]
    KV " levels ", x9
    ldr x9, [x19, #SR_FLAG]
    KV " flag ", x9
    TXT "\n"
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
// Lwords -- print x1 words at x0 as 16-digit hex, each after a space.
// Callee-saved used: x19 (cursor), x20 (left). Frame 32 bytes.
    .p2align 2
Lwords:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    mov x20, x1
1:  cbz x20, 2f
    TXT " "
    ldr x0, [x19], #8
    mov x1, #16
    bl Lput_hexn
    sub x20, x20, #1
    b 1b
2:  ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
// ---- end of the extras -----------------------------------------------------

    .globl _sea_main
    .p2align 2
_sea_main:
    PROLOGUE
    LI x0, 1
    LI x1, 1
    LA x2, Ls0
    LI x3, 960
    LI x4, 720
    mov x5, #0
    bl _sea_figure
    mov x19, x0
    mov x0, x19
    LI x1, 0
    LI x2, 0
    LI x3, 1
    LI x4, 1
    mov x5, #0
    bl _sea_panel
    mov x20, x0
    mov x0, x20
    LA x1, Lv1
    LA x2, Lv2
    LA x3, Lm3
    LI x4, 0
    mov x5, #0
    LA x6, Ls4
    mov x7, #1
    bl _sea_contour
    TXT "not reached\n"
    EPILOGUE

    .section __DATA,__const
    SSTR Ls0, 0, ""
    FVEC Lv1, 3
    .quad 0x0000000000000000, 0x3FF0000000000000, 0x4000000000000000
    FVEC Lv2, 2
    .quad 0x0000000000000000, 0x3FF0000000000000
    FMAT Lm3, 3, 2
    .quad 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000, 0x4010000000000000, 0x4014000000000000, 0x4018000000000000
    SSTR Ls4, 1, "x"
    SSTR Lfile, 5, "p.sea"
    .p2align 3
    .globl _sea_sites
_sea_sites:
    .quad Lfile, 7
    .quad Lfile, 12
