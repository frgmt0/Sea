// sea/tests/rt/arm64_macos/rt_lib_read.s -- sea_read_lines on the fixtures of rt_lib_read.files/ (DESIGN.md 2.15.2 "read_lines", 2.15.6; L-mf): each of 2.15.2's examples (a\nb, a\nb\n, a\r\nb\r\n, a\n\n, \n, a\r\r\n, a\rb, a\r, the empty file), \r\n and a lone \r (one empty line each), NUL, 0xFF and a UTF-8 BOM kept, a mixed file, and a file named "-" (a host path, not standard input). Each file prints `<path>: <count>`, then each line quoted (bytes outside 0x20..0x7E as \xHH); every result is released, and the heap check reports no live object
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

// ---- test helpers (the same block in every rt_lib text test) ----------
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
// Print a literal text (x0-x17 clobbered).
.macro TXT text
    .pushsection __TEXT,__cstring,cstring_literals
Ltxt\@: .asciz "\text"
    .popsection
    LA x0, Ltxt\@
    bl Lput_cstr
.endm
// The live-object counter of rt_mem.s into a register.
.macro LIVE reg
    adrp \reg, _sea_live@PAGE
    ldr \reg, [\reg, _sea_live@PAGEOFF]
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
// _sea_main's frame: the frame record and x19-x28 (all callee-saved).
.macro PROLOGUE
    stp x29, x30, [sp, #-96]!
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
    ldp x29, x30, [sp], #96
    ret
.endm

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

// Lput_hex -- print x0 as 16 lower-case hexadecimal digits. Clobbers
// x0-x17. Frame 32 bytes (frame record, 16 bytes of digits).
    .p2align 2
Lput_hex:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    add x9, sp, #16             // the digits at [sp + 16, sp + 32)
    mov x10, #16
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
    mov x1, #16
    bl _sea_out_write
    ldp x29, x30, [sp], #32
    ret

// Lput_q -- print a string object's bytes between double quotes, each
// byte outside 0x20..0x7E, and the bytes \ and ", as \xHH (two
// lower-case digits). x0 = the object. Clobbers x0-x17. Callee-saved
// used: x19 = the bytes, x20 = bytes left. Frame 48 bytes (frame record,
// x19, x20, 4 bytes of escape text).
    .p2align 2
Lput_q:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    add x19, x0, #SEA_STR_BYTES
    ldr x20, [x0, #SEA_STR_LEN]
    LA x0, Lput_s_dq
    mov x1, #1
    bl _sea_out_write
1:  cbz x20, 4f
    ldrb w9, [x19]
    cmp w9, #'\\'
    b.eq 2f
    cmp w9, #'"'
    b.eq 2f
    sub w10, w9, #0x20
    cmp w10, #(0x7E - 0x20)
    b.hi 2f                     // not printable
    mov x0, x19                 // the byte as it is
    mov x1, #1
    bl _sea_out_write
    b 3f
2:  mov w10, #'\\'              // \xHH
    strb w10, [sp, #32]
    mov w10, #'x'
    strb w10, [sp, #33]
    lsr w11, w9, #4
    and w12, w9, #0xf
    add w13, w11, #'0'
    add w14, w11, #('a' - 10)
    cmp w11, #10
    csel w13, w14, w13, hs
    strb w13, [sp, #34]
    add w13, w12, #'0'
    add w14, w12, #('a' - 10)
    cmp w12, #10
    csel w13, w14, w13, hs
    strb w13, [sp, #35]
    add x0, sp, #32
    mov x1, #4
    bl _sea_out_write
3:  add x19, x19, #1
    sub x20, x20, #1
    b 1b
4:  LA x0, Lput_s_dq
    mov x1, #1
    bl _sea_out_write
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

    .section __TEXT,__const
Lput_s_dq: .ascii "\""
    .section __TEXT,__text,regular,pure_instructions
// ---- end of the test helpers ------------------------------------------

    .globl _sea_main
    .p2align 2
_sea_main:
    PROLOGUE
    LA x19, Lpaths
Lmain_file:
    ldr x20, [x19], #8              // the next path, 0 at the end
    cbz x20, Lmain_done
    mov x0, x20
    mov x1, #0                      // site 0
    bl _sea_read_lines
    mov x21, x0                     // the str[]
    mov x0, x20
    bl Lput_q
    TXT ": "
    ldr x0, [x21, #SEA_ARR_ROWS]
    bl Lput_dec
    TXT "\n"
    mov x22, #0                     // line index
1:  ldr x9, [x21, #SEA_ARR_ROWS]
    cmp x22, x9
    b.hs 2f
    TXT "  "
    ldr x9, [x21, #SEA_ARR_DATA]
    ldr x0, [x9, x22, lsl #3]
    bl Lput_q
    TXT "\n"
    add x22, x22, #1
    b 1b
2:  REL x21                         // the vector and its strings
    b Lmain_file
Lmain_done:
    EPILOGUE

    .section __DATA,__const
    SSTR Lp1, 6, "f1.txt"
    SSTR Lp2, 6, "f2.txt"
    SSTR Lp3, 6, "f3.txt"
    SSTR Lp4, 6, "f4.txt"
    SSTR Lp5, 6, "f5.txt"
    SSTR Lp6, 6, "f6.txt"
    SSTR Lp7, 6, "f7.txt"
    SSTR Lp8, 6, "f8.txt"
    SSTR Lp9, 6, "f9.txt"
    SSTR Lp10, 7, "f10.txt"
    SSTR Lp11, 7, "f11.txt"
    SSTR Lp12, 7, "f12.txt"
    SSTR Lp13, 7, "f13.txt"
    SSTR Lp14, 1, "-"
    .p2align 3
Lpaths:
    .quad Lp1, Lp2, Lp3, Lp4, Lp5, Lp6, Lp7, Lp8, Lp9, Lp10, Lp11, Lp12, Lp13, Lp14, 0
    SSTR Lfile, 5, "m.sea"
    .p2align 3
    .globl _sea_sites
_sea_sites:
    .quad Lfile, 3
