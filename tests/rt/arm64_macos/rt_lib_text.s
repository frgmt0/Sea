// sea/tests/rt/arm64_macos/rt_lib_text.s -- sea_parse_i64, sea_parse_f64, sea_split and sea_substr on the examples of DESIGN.md 2.15.2 and 2.15.6 and hand-derived edge cases (range ends in bases 2, 8, 16 and 36, signs, leading zeros, both cases of letters; zeros of both signs, the eight words, ".5" "5." and exponents, the halfway case 2^53 + 1, the subnormal and overflow edges, texts of 255, 256 and 303 bytes on both sides of RTT_FBUF; separators longer than s, equal to s, overlapping and partly matching at the end; empty ranges out of bounds). Printed in the known-answer format of rt_lib_kat (one line per case, texts quoted, parse_f64 as the 16 lower-case hex digits of its bits); every result is released and the heap check reports no live object
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

// ---- the case tables and their runner (the same in rt_lib_text and rt_lib_kat) ----
// A string object for a case table, in __DATA,__data, its address at the
// record (texts hold no backslash).
.macro CSTR text
    .quad Lcs\@
    .pushsection __DATA,__data
    .p2align 3
Lcs\@:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad Lce\@ - Lcb\@
Lcb\@:
    .ascii "\text"
Lce\@:
    .popsection
.endm
// A parse_i64 record: base, text.
.macro CI64 base, text
    .quad \base
    CSTR "\text"
.endm
// A parse_f64 record: text.
.macro CF64 text
    CSTR "\text"
.endm
// A split record: s, sep.
.macro CSPL s, p
    CSTR "\s"
    CSTR "\p"
.endm
// A substr record: s, lo, hi.
.macro CSUB s, lo, hi
    CSTR "\s"
    .quad \lo, \hi
.endm

    .section __TEXT,__text,regular,pure_instructions
// _sea_main -- every case of the four tables, in the known-answer format
//   (one line per case; texts quoted; parse_f64's value as 16 lower-case
//   hexadecimal digits of its bits). Every result is released.
//   Callee-saved used: x19 = the record, x20 = the result, x21 = element
//   index, x22 = a saved value. Frame 96 bytes.
    .globl _sea_main
    .p2align 2
_sea_main:
    PROLOGUE
    // parse_i64 B "T" V
    LA x19, Lc_i64
1:  ldr x9, [x19, #8]
    cbz x9, 2f
    TXT "parse_i64 "
    ldr x0, [x19]
    bl Lput_dec
    TXT " "
    ldr x0, [x19, #8]
    bl Lput_q
    TXT " "
    ldr x0, [x19, #8]
    ldr x1, [x19]
    mov x2, #0                      // site 0
    bl _sea_parse_i64
    bl Lput_dec
    TXT "\n"
    add x19, x19, #16
    b 1b
    // parse_f64 "T" H
2:  LA x19, Lc_f64
3:  ldr x9, [x19]
    cbz x9, 4f
    TXT "parse_f64 "
    ldr x0, [x19]
    bl Lput_q
    TXT " "
    ldr x0, [x19]
    mov x1, #0
    bl _sea_parse_f64
    fmov x0, d0
    bl Lput_hex
    TXT "\n"
    add x19, x19, #8
    b 3b
    // split "S" "P" C "F1" ...
4:  LA x19, Lc_split
5:  ldr x9, [x19]
    cbz x9, 7f
    TXT "split "
    ldr x0, [x19]
    bl Lput_q
    TXT " "
    ldr x0, [x19, #8]
    bl Lput_q
    TXT " "
    ldp x0, x1, [x19]
    mov x2, #0
    bl _sea_split
    mov x20, x0
    ldr x0, [x20, #SEA_ARR_ROWS]
    bl Lput_dec
    mov x21, #0
6:  ldr x9, [x20, #SEA_ARR_ROWS]
    cmp x21, x9
    b.hs Lsplit_eol
    TXT " "
    ldr x9, [x20, #SEA_ARR_DATA]
    ldr x0, [x9, x21, lsl #3]
    bl Lput_q
    add x21, x21, #1
    b 6b
Lsplit_eol:
    TXT "\n"
    REL x20
    add x19, x19, #16
    b 5b
    // substr "S" L H "R"
7:  LA x19, Lc_substr
8:  ldr x9, [x19]
    cbz x9, 9f
    TXT "substr "
    ldr x0, [x19]
    bl Lput_q
    TXT " "
    ldr x0, [x19, #8]
    bl Lput_dec
    TXT " "
    ldr x0, [x19, #16]
    bl Lput_dec
    TXT " "
    ldr x0, [x19]
    ldr x1, [x19, #8]
    ldr x2, [x19, #16]
    mov x3, #0
    bl _sea_substr
    mov x20, x0
    bl Lput_q
    TXT "\n"
    REL x20
    add x19, x19, #24
    b 8b
9:  EPILOGUE

    .section __DATA,__const
    .p2align 3
Lc_i64:
    CI64 10, "-123"
    CI64 16, "18FF50E5"
    CI64 16, "ff"
    CI64 10, "-9223372036854775808"
    CI64 10, "9223372036854775807"
    CI64 2, "101"
    CI64 10, "+42"
    CI64 10, "007"
    CI64 10, "-0"
    CI64 36, "zz"
    CI64 36, "ZZ"
    CI64 36, "1y2p0ij32e8e7"
    CI64 36, "-1Y2P0IJ32E8E8"
    CI64 16, "7fffffffffffffff"
    CI64 16, "-8000000000000000"
    CI64 8, "777777777777777777777"
    CI64 8, "-1000000000000000000000"
    CI64 2, "111111111111111111111111111111111111111111111111111111111111111"
    CI64 2, "-1000000000000000000000000000000000000000000000000000000000000000"
    CI64 3, "-00012"
    .quad 0, 0
Lc_f64:
    CF64 "0"
    CF64 "-0"
    CF64 "1.5"
    CF64 ".5"
    CF64 "5e-1"
    CF64 "5."
    CF64 "1e3"
    CF64 "1E-3"
    CF64 "+2.5"
    CF64 "-.5E+1"
    CF64 "inf"
    CF64 "Inf"
    CF64 "+inf"
    CF64 "+Inf"
    CF64 "-inf"
    CF64 "-Inf"
    CF64 "nan"
    CF64 "NaN"
    CF64 "1700000000.123456"
    CF64 "1e309"
    CF64 "-1e309"
    CF64 "1e-400"
    CF64 "-1e-400"
    CF64 "9007199254740993"
    CF64 "4.9406564584124654e-324"
    CF64 "2.4703282292062328e-324"
    CF64 "2.4703282292062327e-324"
    CF64 "1.7976931348623158e308"
    CF64 "1.7976931348623159e308"
    CF64 "0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001.5"
    CF64 "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001.5"
    CF64 "0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001.5"
    .quad 0
Lc_split:
    CSPL "a,,b", ","
    CSPL ",a,", ","
    CSPL "", ","
    CSPL "abc", ","
    CSPL "aaa", "aa"
    CSPL "a::b", "::"
    CSPL "ab", "abc"
    CSPL "ab", "ab"
    CSPL "x--y-", "--"
    CSPL "a--b---c", "--"
    CSPL "abababa", "aba"
    CSPL "can0 18FF50E5#0102", " "
    .quad 0, 0
Lc_substr:
    CSUB "(1.5)", 1, 4
    CSUB "abc", 0, 3
    CSUB "abc", 2, 3
    CSUB "abc", 0, 1
    CSUB "abc", 1, 1
    CSUB "ab", 9, 2
    CSUB "ab", -5, -7
    CSUB "ab", 2, 2
    CSUB "", 0, 0
    CSUB "hello", 4, 5
    .quad 0, 0, 0

    SSTR Lfile, 5, "m.sea"
    .p2align 3
    .globl _sea_sites
_sea_sites:
    .quad Lfile, 3
