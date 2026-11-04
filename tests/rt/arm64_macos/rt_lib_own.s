// sea/tests/rt/arm64_macos/rt_lib_own.s -- ownership of the text entries (DESIGN.md 2.15.5 "every argument object is borrowed ... every result object is owned (count 1)", 2.15.6, 2.15.8 "Runtime tests"; L-mh, L-mk): with dynamic argument strings (count 1), each result has count 1; a str[] result is a rank-1 SEA_EK_STR vector of the expected length whose elements are new strings (count 1, tag SEA_TAG_STR), distinct from one another and from the arguments (split without a match too); a substr result is a new string also for the whole range and for an empty range; the arguments keep count 1 and their bytes; the live count rises by exactly the new objects, and is back at its start after the result is released (the release of FREE). parse_i64 and parse_f64 leave the live count and their argument unchanged. Each case prints `<label>: ok`, or `<label>: BAD <bits>` (1 count, 2 shape or tag, 4 shares an argument, 8 live count after the call, 16 two elements alike, 32 an argument changed, 64 live count after the release) and exits 1. The heap check reports no live object
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

    .section __DATA,__data
    .p2align 3
Llive0:  .quad 0                    // the live count before the call
    .section __TEXT,__text,regular,pure_instructions

// Lmk -- a dynamic string (count 1) of a C text. x0 = text. Outputs x0.
// Clobbers x0-x17. Callee-saved used: x19 (the text). Frame 32 bytes.
    .p2align 2
Lmk:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    bl _strlen
    mov x1, x0
    mov x0, x19
    mov x2, #0
    bl _sea_str_make
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Lsnap -- Llive0 = the live count. Clobbers x9, x10.
    .p2align 2
Lsnap:
    LIVE x9
    LA x10, Llive0
    str x9, [x10]
    ret

// Largok -- is a dynamic argument unchanged? x0 = the object (or 0: yes),
// x1 = its C text. Outputs x0 = 0, or 32. Clobbers x0-x17. Callee-saved
// used: x19, x20. Frame 32 bytes.
    .p2align 2
Largok:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    mov x20, x1
    cbz x19, 1f
    ldr x9, [x19]
    cmp x9, #1
    b.ne 2f                         // its count changed
    mov x0, x20
    bl _strlen
    ldr x9, [x19, #SEA_STR_LEN]
    cmp x9, x0
    b.ne 2f                         // its length changed
    mov x2, x0
    add x0, x19, #SEA_STR_BYTES
    mov x1, x20
    bl _memcmp
    cbnz w0, 2f                     // its bytes changed
1:  mov x0, #0
    b 3f
2:  mov x0, #32
3:  ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Lnewstr -- the checks of one new string. x0 = it, x1, x2 = the
// arguments (0 for none). Outputs x0 = error bits 1, 2, 4. Clobbers
// x9-x12. Leaf.
    .p2align 2
Lnewstr:
    mov x12, #0
    ldr x9, [x0, #SEA_STR_RC]
    cmp x9, #1
    b.eq 1f
    orr x12, x12, #1                // count not 1
1:  ldrb w9, [x0, #SEA_STR_TAG]
    cmp w9, #SEA_TAG_STR
    b.eq 2f
    orr x12, x12, #2                // not a string
2:  cmp x0, x1
    b.eq 3f
    cmp x0, x2
    b.ne 4f
3:  orr x12, x12, #4                // the argument itself
4:  mov x0, x12
    ret

// Lcheck -- the checks of a result, then its release.
//   Inputs  : x0 = the result, x1 = its element count (-1: a string
//             result), x2 = argument 1, x3 = its C text, x4 = argument 2
//             or 0, x5 = its C text
//   Outputs : x0 = the error bits (see the file header)
//   Callee-saved used: x19 = result, x20 = count, x21 = arg 1, x22 = its
//             text, x23 = arg 2, x24 = its text, x25 = bits, x26 = index,
//             x27 = inner index. Frame 96 bytes.
    .p2align 2
Lcheck:
    PROLOGUE
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, x4
    mov x24, x5
    mov x25, #0
    ldr x9, [x19]
    cmp x9, #1
    b.eq 1f
    orr x25, x25, #1                // the result's count
1:  cmn x20, #1
    b.ne Lcheck_arr
    // A string result: new, one live object more.
    mov x0, x19
    mov x1, x21
    mov x2, x23
    bl Lnewstr
    orr x25, x25, x0
    mov x10, #1
    b Lcheck_live
Lcheck_arr:
    ldrb w9, [x19, #SEA_ARR_TAG]
    cmp w9, #SEA_TAG_ARRAY
    b.ne 2f
    ldrb w9, [x19, #SEA_ARR_EK]
    cmp w9, #SEA_EK_STR
    b.ne 2f
    ldrb w9, [x19, #SEA_ARR_RANK]
    cmp w9, #1
    b.ne 2f
    ldr x9, [x19, #SEA_ARR_ROWS]
    cmp x9, x20
    b.ne 2f
    ldr x9, [x19, #SEA_ARR_COLS]
    cmp x9, #1
    b.eq 3f
2:  orr x25, x25, #2                // the vector's shape
    b Lcheck_args
3:  mov x26, #0
4:  cmp x26, x20
    b.hs 6f
    ldr x9, [x19, #SEA_ARR_DATA]
    ldr x0, [x9, x26, lsl #3]
    mov x1, x21
    mov x2, x23
    bl Lnewstr
    orr x25, x25, x0
    mov x27, #0                     // distinct from the earlier elements
5:  cmp x27, x26
    b.hs 51f
    ldr x9, [x19, #SEA_ARR_DATA]
    ldr x10, [x9, x26, lsl #3]
    ldr x11, [x9, x27, lsl #3]
    cmp x10, x11
    b.ne 52f
    orr x25, x25, #16
52: add x27, x27, #1
    b 5b
51: add x26, x26, #1
    b 4b
6:  add x10, x20, #1                // the vector and its elements
Lcheck_live:
    LA x9, Llive0
    ldr x9, [x9]
    add x9, x9, x10
    LIVE x11
    cmp x11, x9
    b.eq Lcheck_args
    orr x25, x25, #8
Lcheck_args:
    mov x0, x21
    mov x1, x22
    bl Largok
    orr x25, x25, x0
    mov x0, x23
    mov x1, x24
    bl Largok
    orr x25, x25, x0
    REL x19                         // the result
    LA x9, Llive0
    ldr x9, [x9]
    LIVE x10
    cmp x10, x9
    b.eq 7f
    orr x25, x25, #64
7:  mov x0, x25
    EPILOGUE

// Lverdict -- print `<label>: ok`, or `<label>: BAD <bits>` and exit 1.
// x0 = the label (C text), x1 = the bits. Callee-saved used: x19. Frame 32.
    .p2align 2
Lverdict:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x1
    bl Lput_cstr
    cbnz x19, 1f
    TXT ": ok\n"
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
1:  TXT ": BAD "
    mov x0, x19
    bl Lput_dec
    TXT "\n"
    bl _sea_out_flush
    mov w0, #1
    bl _exit

// A split case: label, s, sep, the expected element count.
.macro SPLITCASE label, s, sep, n
    LA x0, \s
    bl Lmk
    mov x19, x0
    LA x0, \sep
    bl Lmk
    mov x20, x0
    bl Lsnap
    mov x0, x19
    mov x1, x20
    mov x2, #0
    bl _sea_split
    mov x1, #\n
    mov x2, x19
    LA x3, \s
    mov x4, x20
    LA x5, \sep
    bl Lcheck
    mov x21, x0
    REL x19
    REL x20
    LA x0, \label
    mov x1, x21
    bl Lverdict
.endm
// A substr case: label, s, lo, hi.
.macro SUBCASE label, s, lo, hi
    LA x0, \s
    bl Lmk
    mov x19, x0
    bl Lsnap
    mov x0, x19
    mov x1, #\lo
    mov x2, #\hi
    mov x3, #0
    bl _sea_substr
    mov x1, #-1
    mov x2, x19
    LA x3, \s
    mov x4, #0
    mov x5, #0
    bl Lcheck
    mov x21, x0
    REL x19
    LA x0, \label
    mov x1, x21
    bl Lverdict
.endm

    .globl _sea_main
    .p2align 2
_sea_main:
    PROLOGUE
    SPLITCASE Ll_s0, Lt_abc, Lt_comma, 1
    SPLITCASE Ll_s1, Lt_abc3, Lt_comma, 3
    SPLITCASE Ll_s2, Lt_abab, Lt_ab, 4
    SUBCASE Ll_u0, Lt_abc, 0, 3
    SUBCASE Ll_u1, Lt_abc, 1, 2
    SUBCASE Ll_u2, Lt_abc, 2, 1
    // read_lines: a str[] of three new strings
    LA x0, Lt_path
    bl Lmk
    mov x19, x0
    bl Lsnap
    mov x0, x19
    mov x1, #0
    bl _sea_read_lines
    mov x1, #3
    mov x2, x19
    LA x3, Lt_path
    mov x4, #0
    mov x5, #0
    bl Lcheck
    mov x21, x0
    REL x19
    LA x0, Ll_r0
    mov x1, x21
    bl Lverdict
    // parse_i64 and parse_f64: no object made, the argument untouched
    LA x0, Lt_num
    bl Lmk
    mov x19, x0
    bl Lsnap
    mov x0, x19
    mov x1, #10
    mov x2, #0
    bl _sea_parse_i64
    mov x22, #0
    cmp x0, #125
    b.eq 1f
    orr x22, x22, #2                // the value (checked by rt_lib_text too)
1:  mov x0, x19
    mov x1, #0
    bl _sea_parse_f64
    LI x9, 0x405F400000000000       // 125.0
    fmov x10, d0
    cmp x10, x9
    b.eq 2f
    orr x22, x22, #2
2:  LA x9, Llive0
    ldr x9, [x9]
    LIVE x10
    cmp x10, x9
    b.eq 3f
    orr x22, x22, #8
3:  mov x0, x19
    LA x1, Lt_num
    bl Largok
    orr x22, x22, x0
    REL x19
    LA x0, Ll_p0
    mov x1, x22
    bl Lverdict
    EPILOGUE

    .section __TEXT,__cstring,cstring_literals
Ll_s0:  .asciz "split without a match"
Ll_s1:  .asciz "split three fields"
Ll_s2:  .asciz "split two-byte separator"
Ll_u0:  .asciz "substr whole range"
Ll_u1:  .asciz "substr one byte"
Ll_u2:  .asciz "substr empty range"
Ll_r0:  .asciz "read_lines three lines"
Ll_p0:  .asciz "parse_i64 and parse_f64"
Lt_abc:   .asciz "abc"
Lt_abc3:  .asciz "a,b,c"
Lt_abab:  .asciz "abxabyab"
Lt_ab:    .asciz "ab"
Lt_comma: .asciz ","
Lt_path:  .asciz "three.txt"
Lt_num:   .asciz "125"

    .section __DATA,__const
    SSTR Lfile, 5, "m.sea"
    .p2align 3
    .globl _sea_sites
_sea_sites:
    .quad Lfile, 3
