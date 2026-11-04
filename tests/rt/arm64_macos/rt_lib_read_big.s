// sea/tests/rt/arm64_macos/rt_lib_read_big.s -- sea_read_lines of a file larger than two chunks (DESIGN.md 2.15.6 step 3: the buffer of RTT_CHUNK = 65 536 bytes doubled twice; 2.15.8): the fixture big.txt (200 003 bytes, generated once, LF and CRLF line ends, a few lone CRs inside lines, the CR of a CRLF at offset 65 535 and its LF at 65 536, no final LF) prints the line count, the sum of the lengths, the sum of all line bytes, the sum of (k + 1) * length of line k, and the first line, the line ended by the CRLF across the boundary, the line after it and the last line (quoted, as rt_lib_read). Expected output from the generator's own application of 2.15.2's line rule. The heap check reports no live object
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

// Lline -- print `<name> <k>: "<line k>"`. x0 = the name (C text), x1 = k,
// x2 = the str[]. Callee-saved used: x19 = k, x20 = the vector. Frame 32.
    .p2align 2
Lline:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x1
    mov x20, x2
    bl Lput_cstr
    TXT " "
    mov x0, x19
    bl Lput_dec
    TXT ": "
    ldr x9, [x20, #SEA_ARR_DATA]
    ldr x0, [x9, x19, lsl #3]
    bl Lput_q
    TXT "\n"
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// _sea_main -- callee-saved used: x19 = the str[], x20 = rows, x21 = k,
// x22 = sum of lengths, x23 = sum of bytes, x24 = weighted sum, x25 = the
// boundary line's index. Frame 96.
// The index of the line ended by the CRLF at offsets 65 535 and 65 536 (a
// property of the fixture, from its generator).
.equ BOUND_LINE, 432
    .globl _sea_main
    .p2align 2
_sea_main:
    PROLOGUE
    LA x0, Lpath
    mov x1, #0
    bl _sea_read_lines
    mov x19, x0
    ldr x20, [x19, #SEA_ARR_ROWS]
    mov x21, #0
    mov x22, #0
    mov x23, #0
    mov x24, #0
    mov x25, #BOUND_LINE
1:  cmp x21, x20
    b.hs 3f
    ldr x9, [x19, #SEA_ARR_DATA]
    ldr x9, [x9, x21, lsl #3]
    ldr x10, [x9, #SEA_STR_LEN]
    add x22, x22, x10
    add x11, x21, #1
    madd x24, x11, x10, x24         // (k + 1) * length
    add x12, x9, #SEA_STR_BYTES
    mov x13, #0
2:  cmp x13, x10
    b.hs 4f
    ldrb w14, [x12, x13]
    add x23, x23, x14
    add x13, x13, #1
    b 2b
4:  add x21, x21, #1
    b 1b
3:  TXT "lines: "
    mov x0, x20
    bl Lput_dec
    TXT "\nbytes: "
    mov x0, x22
    bl Lput_dec
    TXT "\nsum: "
    mov x0, x23
    bl Lput_dec
    TXT "\nweighted: "
    mov x0, x24
    bl Lput_dec
    TXT "\n"
    LA x0, Ln_first
    mov x1, #0
    mov x2, x19
    bl Lline
    LA x0, Ln_bound
    mov x1, x25
    mov x2, x19
    bl Lline
    LA x0, Ln_after
    add x1, x25, #1
    mov x2, x19
    bl Lline
    LA x0, Ln_last
    sub x1, x20, #1
    mov x2, x19
    bl Lline
    REL x19
    EPILOGUE

    .section __TEXT,__cstring,cstring_literals
Ln_first: .asciz "first"
Ln_bound: .asciz "boundary"
Ln_after: .asciz "after"
Ln_last:  .asciz "last"
    .section __DATA,__const
    SSTR Lpath, 7, "big.txt"
    SSTR Lfile, 5, "m.sea"
    .p2align 3
    .globl _sea_sites
_sea_sites:
    .quad Lfile, 3
