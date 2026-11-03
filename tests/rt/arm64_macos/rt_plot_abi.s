// sea/tests/rt/arm64_macos/rt_plot_abi.s -- the ABI of every 9b entry (DESIGN.md 2.14.5 "ABI", "Stack"; 2.14.8 "Runtime tests"): each call is made with x19-x29, d8-d15 and FPCR (AHP and FZ16 set) holding known patterns and the 128 KiB below sp guard-filled; afterwards x19-x29, sp, d8-d15 and FPCR must be unchanged and the call, its callees included (_sea_alloc, memcpy, memset, snprintf through _sea_fmt_num, _sea_file_put and the write), must have written at most SEA_STACK_MARGIN bytes below sp. The figure built by the calls exercises a twin, markers of three kinds, NaN data, xlines, labels, a legend, the grid, explicit limits, categories, a reversed and an equal-units panel and Decision 142 (ylim 1 .. 1.00001), so that SAVE_SVG walks every 9b path. Each call prints `<label>: ok`; a failure prints its error bits and exits 1. Heap check count: the figure and 3 Axes, none live
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


// ---- the ABI check (as rt_la_lu_abi's, with an argument block) ---------
// The pattern held in a preserved register during the call (n = its number).
.macro PATV reg, n
    LI \reg, (0x5EA0000000000000 | ((\n) << 40) | ((\n) << 8) | (\n))
.endm
.equ GUARD_BYTES, 131072            /* guard-filled below the incoming sp */
.equ GUARD_WORD, 0xC0FFEE5EA5EA5EA5 /* the guard pattern */
.equ FPCR_SET, ((1 << 26) | (1 << 19))  /* AHP and FZ16: no effect on f64 */
.if GUARD_BYTES <= SEA_STACK_MARGIN
    .error "the guard must reach below SEA_STACK_MARGIN"
.endif

    .section __DATA,__data
    .p2align 3
Lres:    .quad 0                    // the result of the last call
Lsp:     .quad 0                    // sp before the call
Lfpcr0:  .quad 0                    // FPCR before the test set it
Lfpcr1:  .quad 0                    // FPCR during the call
Ldepth:  .quad 0                    // bytes below sp the call wrote
Lmaxdepth: .quad 0                  // the deepest of all calls
Lshow:   .quad 0                    // 1: print each depth (a measurement aid)
Largs:   .space 80                  // x0-x7, then d0, d1 of the next call
    .section __TEXT,__text,regular,pure_instructions

// Lprobe -- call a routine under the ABI check.
//   Inputs  : x0 = the routine; its arguments in Largs
//   Outputs : x0 = 0, or the sum of: 1 sp changed, 2 FPCR changed, 4 one
//             of x19-x29 changed, 8 one of d8-d15 changed, 16 the call
//             wrote more than SEA_STACK_MARGIN bytes below sp; Lres = the
//             result, Ldepth = the bytes written below sp
//   Clobbers: x0-x17, v0-v7, v16-v31, NZCV
//   Callee-saved used: x19-x29 and d8-d15 hold the patterns during the
//             call (saved and restored here)
//   Frame   : 160 bytes (frame record, x19-x28, d8-d15)
    .p2align 2
Lprobe:
    stp x29, x30, [sp, #-160]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp x27, x28, [sp, #80]
    stp d8, d9, [sp, #96]
    stp d10, d11, [sp, #112]
    stp d12, d13, [sp, #128]
    stp d14, d15, [sp, #144]
    mov x16, x0                     // the routine
    // FPCR: AHP and FZ16 set; the value read back is the one to keep
    mrs x9, fpcr
    LA x10, Lfpcr0
    str x9, [x10]
    LI x11, FPCR_SET
    orr x9, x9, x11
    msr fpcr, x9
    mrs x9, fpcr
    LA x10, Lfpcr1
    str x9, [x10]
    // the guard below sp, and sp itself
    mov x10, sp
    mov x13, #GUARD_BYTES
    sub x11, x10, x13
    LI x12, GUARD_WORD
1:  str x12, [x11], #8
    cmp x11, x10
    b.lo 1b
    LA x11, Lsp
    str x10, [x11]
    // the patterns
    PATV x19, 19
    PATV x20, 20
    PATV x21, 21
    PATV x22, 22
    PATV x23, 23
    PATV x24, 24
    PATV x25, 25
    PATV x26, 26
    PATV x27, 27
    PATV x28, 28
    PATV x29, 29
    PATV x9, 108
    fmov d8, x9
    PATV x9, 109
    fmov d9, x9
    PATV x9, 110
    fmov d10, x9
    PATV x9, 111
    fmov d11, x9
    PATV x9, 112
    fmov d12, x9
    PATV x9, 113
    fmov d13, x9
    PATV x9, 114
    fmov d14, x9
    PATV x9, 115
    fmov d15, x9
    LA x17, Largs                   // the arguments
    ldp x0, x1, [x17]
    ldp x2, x3, [x17, #16]
    ldp x4, x5, [x17, #32]
    ldp x6, x7, [x17, #48]
    ldp d0, d1, [x17, #64]
    blr x16                         // the routine
    LA x9, Lres
    str x0, [x9]
    mov x13, #0                     // the error bits
    LA x10, Lsp
    ldr x10, [x10]
    mov x9, sp
    cmp x9, x10
    b.eq 2f
    orr x13, x13, #1
2:  mov sp, x10
    mrs x9, fpcr
    LA x10, Lfpcr1
    ldr x10, [x10]
    cmp x9, x10
    b.eq 3f
    orr x13, x13, #2
3:  LA x10, Lfpcr0
    ldr x10, [x10]
    msr fpcr, x10                   // the original FPCR
    mov x14, #0
    PATV x9, 19
    cmp x19, x9
    cinc x14, x14, ne
    PATV x9, 20
    cmp x20, x9
    cinc x14, x14, ne
    PATV x9, 21
    cmp x21, x9
    cinc x14, x14, ne
    PATV x9, 22
    cmp x22, x9
    cinc x14, x14, ne
    PATV x9, 23
    cmp x23, x9
    cinc x14, x14, ne
    PATV x9, 24
    cmp x24, x9
    cinc x14, x14, ne
    PATV x9, 25
    cmp x25, x9
    cinc x14, x14, ne
    PATV x9, 26
    cmp x26, x9
    cinc x14, x14, ne
    PATV x9, 27
    cmp x27, x9
    cinc x14, x14, ne
    PATV x9, 28
    cmp x28, x9
    cinc x14, x14, ne
    PATV x9, 29
    cmp x29, x9
    cinc x14, x14, ne
    cbz x14, 4f
    orr x13, x13, #4
4:  mov x29, sp                     // this frame again
    mov x14, #0
    PATV x9, 108
    fmov x10, d8
    cmp x10, x9
    cinc x14, x14, ne
    PATV x9, 109
    fmov x10, d9
    cmp x10, x9
    cinc x14, x14, ne
    PATV x9, 110
    fmov x10, d10
    cmp x10, x9
    cinc x14, x14, ne
    PATV x9, 111
    fmov x10, d11
    cmp x10, x9
    cinc x14, x14, ne
    PATV x9, 112
    fmov x10, d12
    cmp x10, x9
    cinc x14, x14, ne
    PATV x9, 113
    fmov x10, d13
    cmp x10, x9
    cinc x14, x14, ne
    PATV x9, 114
    fmov x10, d14
    cmp x10, x9
    cinc x14, x14, ne
    PATV x9, 115
    fmov x10, d15
    cmp x10, x9
    cinc x14, x14, ne
    cbz x14, 5f
    orr x13, x13, #8
    // the depth: the lowest guard word overwritten, from the bottom up
5:  mov x10, sp
    mov x9, #GUARD_BYTES
    sub x11, x10, x9
    LI x12, GUARD_WORD
6:  cmp x11, x10
    b.hs 7f
    ldr x9, [x11]
    cmp x9, x12
    b.ne 7f
    add x11, x11, #8
    b 6b
7:  sub x9, x10, x11                // 0 when nothing was written
    LA x10, Ldepth
    str x9, [x10]
    LA x10, Lmaxdepth
    ldr x11, [x10]
    cmp x9, x11
    csel x11, x9, x11, hi
    str x11, [x10]
    mov x10, #SEA_STACK_MARGIN
    cmp x9, x10
    b.ls 8f
    orr x13, x13, #16
8:  mov x0, x13
    ldp d14, d15, [sp, #144]
    ldp d12, d13, [sp, #128]
    ldp d10, d11, [sp, #112]
    ldp d8, d9, [sp, #96]
    ldp x27, x28, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #160
    ret

// Lrun -- one call under Lprobe: `<label>: ok`, or `<label>: BAD <bits>`
// and exit 1. x0 = label, x1 = routine (arguments in Largs). Returns the
// result in x0. Callee-saved used: x19 = label, x20 = bits. Frame 32.
    .p2align 2
Lrun:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    mov x0, x1
    bl Lprobe
    mov x20, x0
    mov x0, x19
    bl Lput_cstr
    cbnz x20, 1f
    TXT ": ok"
    LA x9, Lshow
    ldr x9, [x9]
    cbz x9, 2f
    LA x9, Ldepth
    ldr x9, [x9]
    KV " depth ", x9
2:  TXT "\n"
    LA x9, Lres
    ldr x0, [x9]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
1:  KV ": BAD ", x20
    TXT "\n"
    bl _sea_out_flush
    mov w0, #1
    bl _exit

    .globl _sea_main
    .p2align 2
_sea_main:
    PROLOGUE
    // figure
    LA x17, Largs
    mov x9, #2
    str x9, [x17, #0]
    mov x9, #2
    str x9, [x17, #8]
    LA x9, Lname
    str x9, [x17, #16]
    mov x9, #400
    str x9, [x17, #24]
    mov x9, #300
    str x9, [x17, #32]
    mov x9, #0
    str x9, [x17, #40]
    LA x0, Ll_figure
    LA x1, _sea_figure
    bl Lrun
    mov x19, x0
    // panel
    LA x17, Largs
    mov x9, x19
    str x9, [x17, #0]
    mov x9, #0
    str x9, [x17, #8]
    mov x9, #0
    str x9, [x17, #16]
    mov x9, #1
    str x9, [x17, #24]
    mov x9, #2
    str x9, [x17, #32]
    mov x9, #0
    str x9, [x17, #40]
    LA x0, Ll_panel
    LA x1, _sea_panel
    bl Lrun
    mov x20, x0
    // twin_y
    LA x17, Largs
    mov x9, x20
    str x9, [x17, #0]
    mov x9, #0
    str x9, [x17, #8]
    LA x0, Ll_twin_y
    LA x1, _sea_twin_y
    bl Lrun
    mov x21, x0
    // panel 2
    LA x17, Largs
    mov x9, x19
    str x9, [x17, #0]
    mov x9, #1
    str x9, [x17, #8]
    mov x9, #0
    str x9, [x17, #16]
    mov x9, #1
    str x9, [x17, #24]
    mov x9, #1
    str x9, [x17, #32]
    mov x9, #0
    str x9, [x17, #40]
    LA x0, Ll_panel_2
    LA x1, _sea_panel
    bl Lrun
    mov x22, x0
    // plot
    LA x17, Largs
    mov x9, x20
    str x9, [x17, #0]
    LA x9, Lx
    str x9, [x17, #8]
    LA x9, Ly
    str x9, [x17, #16]
    LA x9, Ls_o
    str x9, [x17, #24]
    LA x9, Ls_lab
    str x9, [x17, #32]
    LA x9, Lempty
    str x9, [x17, #40]
    mov x9, #0
    str x9, [x17, #48]
    LI x9, 0x3FF8000000000000
    str x9, [x17, #64]
    LA x0, Ll_plot
    LA x1, _sea_plot
    bl Lrun
    // plot on the twin
    LA x17, Largs
    mov x9, x21
    str x9, [x17, #0]
    LA x9, Lx
    str x9, [x17, #8]
    LA x9, Ly2
    str x9, [x17, #16]
    LA x9, Ls_star
    str x9, [x17, #24]
    LA x9, Ls_t
    str x9, [x17, #32]
    LA x9, Ls_col
    str x9, [x17, #40]
    mov x9, #0
    str x9, [x17, #48]
    LI x9, 0x3FF0000000000000
    str x9, [x17, #64]
    LA x0, Ll_plot_on_the_twin
    LA x1, _sea_plot
    bl Lrun
    // plot with NaN
    LA x17, Largs
    mov x9, x22
    str x9, [x17, #0]
    LA x9, Lxn
    str x9, [x17, #8]
    LA x9, Ly
    str x9, [x17, #16]
    LA x9, Ls_dot
    str x9, [x17, #24]
    LA x9, Lempty
    str x9, [x17, #32]
    LA x9, Lempty
    str x9, [x17, #40]
    mov x9, #0
    str x9, [x17, #48]
    LI x9, 0x3FF0000000000000
    str x9, [x17, #64]
    LA x0, Ll_plot_with_NaN
    LA x1, _sea_plot
    bl Lrun
    // xline
    LA x17, Largs
    mov x9, x20
    str x9, [x17, #0]
    LA x9, Ls_colon
    str x9, [x17, #8]
    LA x9, Lempty
    str x9, [x17, #16]
    mov x9, #0
    str x9, [x17, #24]
    LI x9, 0x3FF8000000000000
    str x9, [x17, #64]
    LA x0, Ll_xline
    LA x1, _sea_xline
    bl Lrun
    // xline NaN
    LA x17, Largs
    mov x9, x21
    str x9, [x17, #0]
    LA x9, Ls_dash
    str x9, [x17, #8]
    LA x9, Lempty
    str x9, [x17, #16]
    mov x9, #0
    str x9, [x17, #24]
    LI x9, 0x7FF8000000000000
    str x9, [x17, #64]
    LA x0, Ll_xline_NaN
    LA x1, _sea_xline
    bl Lrun
    // xlabel
    LA x17, Largs
    mov x9, x21
    str x9, [x17, #0]
    LA x9, Ls_lab
    str x9, [x17, #8]
    LA x0, Ll_xlabel
    LA x1, _sea_xlabel
    bl Lrun
    // ylabel
    LA x17, Largs
    mov x9, x21
    str x9, [x17, #0]
    LA x9, Ls_t
    str x9, [x17, #8]
    LA x0, Ll_ylabel
    LA x1, _sea_ylabel
    bl Lrun
    // title
    LA x17, Largs
    mov x9, x20
    str x9, [x17, #0]
    LA x9, Lname
    str x9, [x17, #8]
    LA x0, Ll_title
    LA x1, _sea_title
    bl Lrun
    // legend
    LA x17, Largs
    mov x9, x21
    str x9, [x17, #0]
    LA x9, Ls_best
    str x9, [x17, #8]
    mov x9, #0
    str x9, [x17, #16]
    LA x0, Ll_legend
    LA x1, _sea_legend
    bl Lrun
    // grid
    LA x17, Largs
    mov x9, x20
    str x9, [x17, #0]
    mov x9, #1
    str x9, [x17, #8]
    LA x0, Ll_grid
    LA x1, _sea_grid
    bl Lrun
    // xlim
    LA x17, Largs
    mov x9, x22
    str x9, [x17, #0]
    mov x9, #0
    str x9, [x17, #8]
    LI x9, 0xBFF0000000000000
    str x9, [x17, #64]
    LI x9, 0x4014000000000000
    str x9, [x17, #72]
    LA x0, Ll_xlim
    LA x1, _sea_xlim
    bl Lrun
    // ylim
    LA x17, Largs
    mov x9, x21
    str x9, [x17, #0]
    mov x9, #0
    str x9, [x17, #8]
    LI x9, 0x3FF0000000000000
    str x9, [x17, #64]
    LI x9, 0x3FF0000A7C5AC472
    str x9, [x17, #72]
    LA x0, Ll_ylim
    LA x1, _sea_ylim
    bl Lrun
    // x_ticks
    LA x17, Largs
    mov x9, x20
    str x9, [x17, #0]
    LA x9, Lcats
    str x9, [x17, #8]
    mov x9, #0
    str x9, [x17, #16]
    LA x0, Ll_x_ticks
    LA x1, _sea_x_ticks
    bl Lrun
    // y_ticks
    LA x17, Largs
    mov x9, x22
    str x9, [x17, #0]
    LA x9, Lcats
    str x9, [x17, #8]
    mov x9, #0
    str x9, [x17, #16]
    LA x0, Ll_y_ticks
    LA x1, _sea_y_ticks
    bl Lrun
    // y_reverse
    LA x17, Largs
    mov x9, x22
    str x9, [x17, #0]
    LA x0, Ll_y_reverse
    LA x1, _sea_y_reverse
    bl Lrun
    // axis_equal
    LA x17, Largs
    mov x9, x22
    str x9, [x17, #0]
    LA x0, Ll_axis_equal
    LA x1, _sea_axis_equal
    bl Lrun
    // save_svg
    LA x17, Largs
    mov x9, x19
    str x9, [x17, #0]
    LA x9, Lpath
    str x9, [x17, #8]
    mov x9, #0
    str x9, [x17, #16]
    LA x0, Ll_save_svg
    LA x1, _sea_save_svg
    bl Lrun
    REL x22
    REL x21
    REL x20
    REL x19
    LA x9, Lshow
    ldr x9, [x9]
    cbz x9, 1f
    LA x9, Lmaxdepth
    ldr x9, [x9]
    KV "deepest ", x9
    TXT "\n"
1:  EPILOGUE

    .section __TEXT,__cstring,cstring_literals
Ll_figure: .asciz "figure"
Ll_panel: .asciz "panel"
Ll_twin_y: .asciz "twin_y"
Ll_panel_2: .asciz "panel 2"
Ll_plot: .asciz "plot"
Ll_plot_on_the_twin: .asciz "plot on the twin"
Ll_plot_with_NaN: .asciz "plot with NaN"
Ll_xline: .asciz "xline"
Ll_xline_NaN: .asciz "xline NaN"
Ll_xlabel: .asciz "xlabel"
Ll_ylabel: .asciz "ylabel"
Ll_title: .asciz "title"
Ll_legend: .asciz "legend"
Ll_grid: .asciz "grid"
Ll_xlim: .asciz "xlim"
Ll_ylim: .asciz "ylim"
Ll_x_ticks: .asciz "x_ticks"
Ll_y_ticks: .asciz "y_ticks"
Ll_y_reverse: .asciz "y_reverse"
Ll_axis_equal: .asciz "axis_equal"
Ll_save_svg: .asciz "save_svg"
    .section __DATA,__const
    SSTR Lname, 2, "N&"
    SSTR Lempty, 0, ""
    SSTR Ls_o, 2, "-o"
    SSTR Ls_star, 3, "--*"
    SSTR Ls_dot, 1, "."
    SSTR Ls_colon, 1, ":"
    SSTR Ls_dash, 2, "--"
    SSTR Ls_lab, 3, "lab"
    SSTR Ls_t, 1, "t"
    SSTR Ls_col, 7, "#123456"
    SSTR Ls_best, 4, "best"
    SSTR Lpath, 5, "a.svg"
    SSTR Lc1, 2, "c1"
    SSTR Lc2, 2, "c2"
    SVEC Lcats, 2
    .quad Lc1, Lc2
    FVEC Lx, 3
    .quad 0x0000000000000000, 0x3FF0000000000000, 0x4000000000000000
    FVEC Ly, 3
    .quad 0x3FF0000000000000, 0x4008000000000000, 0x4000000000000000
    FVEC Ly2, 3
    .quad 0x4024000000000000, 0x7FF0000000000000, 0x4034000000000000
    FVEC Lxn, 3
    .quad 0x0000000000000000, 0x7FF8000000000000, 0x4000000000000000
    SSTR Lfile, 5, "p.sea"
    .p2align 3
    .globl _sea_sites
_sea_sites:
    .quad Lfile, 7
