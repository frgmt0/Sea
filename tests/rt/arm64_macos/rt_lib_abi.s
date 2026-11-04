// sea/tests/rt/arm64_macos/rt_lib_abi.s -- the ABI of the five text entries (DESIGN.md 2.15.5 "ABI", "Stack"; 2.15.8 "Runtime tests"): each call is made with x19-x29, d8-d15 and FPCR (AHP and FZ16 set) holding known patterns and the 128 KiB below sp guard-filled; afterwards x19-x29, sp, d8-d15 and FPCR must be unchanged, the call, its callees included (_sea_alloc, _sea_free_block, _sea_arr_new, _sea_str_make, memcpy, memchr, open, read, close, strtod), must have written at most SEA_STACK_MARGIN bytes below sp, and a sea_parse_i64 call (which calls nothing when it succeeds) at most 512 bytes (its own frame bound). Cases: read_lines of the fixture in.txt, split with a one-byte and a two-byte separator, parse_i64 at -2^63 and in base 36, parse_f64 of a short text (the frame buffer), a 303-byte text (the uncounted block) and a word, substr of a range and an empty one. Each call's result is checked (an integer, the f64 bits, or a str[] / string whose count is 1, then released) and prints `<label>: ok`; a failure prints `<label>: BAD <bits>` (the bits of Lprobe, 32 a wrong result, 64 parse_i64 beyond 512 bytes) and exits 1. The heap check reports no live object
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

// ---- the ABI check ----------------------------------------------------
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
Lresd:   .quad 0                    // the bits of d0 after the last call
Lsp:     .quad 0                    // sp before the call
Lfpcr0:  .quad 0                    // FPCR before the test set it
Lfpcr1:  .quad 0                    // FPCR during the call
Ldepth:  .quad 0                    // bytes below sp the call wrote
    .section __TEXT,__text,regular,pure_instructions

// Lprobe -- call an entry under the ABI check.
//   Inputs  : x0 = a case record: label, entry, then the four integer
//             arguments x0..x3 (the site among them)
//   Outputs : x0 = 0, or the sum of: 1 sp changed, 2 FPCR changed, 4 one
//             of x19-x29 changed, 8 one of d8-d15 changed, 16 the call
//             wrote more than SEA_STACK_MARGIN bytes below sp;
//             Lres = x0 and Lresd = d0 after the call, Ldepth = the
//             bytes written below sp
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
    ldr x16, [x0, #8]               // the entry
    ldp x1, x2, [x0, #24]           // its arguments
    ldr x3, [x0, #40]
    ldr x0, [x0, #16]
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
    blr x16                         // the entry
    LA x9, Lres
    str x0, [x9]
    fmov x10, d0
    str x10, [x9, #8]               // Lresd
    mov x13, #0                     // the error bits
    // sp (restored from Lsp in any case, so that the frame is reachable)
    LA x10, Lsp
    ldr x10, [x10]
    mov x9, sp
    cmp x9, x10
    b.eq 2f
    orr x13, x13, #1
2:  mov sp, x10
    // FPCR
    mrs x9, fpcr
    LA x10, Lfpcr1
    ldr x10, [x10]
    cmp x9, x10
    b.eq 3f
    orr x13, x13, #2
3:  LA x10, Lfpcr0
    ldr x10, [x10]
    msr fpcr, x10                   // the original FPCR
    // x19-x29
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
    // d8-d15 (the low 64 bits are preserved)
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


// A case record (8-byte words): label (C text), entry, the arguments x0..x3,
// the kind (0 an i64 result, 1 an f64 result's bits, 2 a new object with
// count 1), the expected value (kinds 0 and 1).
.equ AR_SIZE, 64
.macro CASE label, entry, a0, a1, a2, a3, kind, want
    .pushsection __TEXT,__cstring,cstring_literals
Lcl\@: .asciz "\label"
    .popsection
    .quad Lcl\@, \entry, \a0, \a1, \a2, \a3, \kind, \want
.endm

    .section __TEXT,__text,regular,pure_instructions
// _sea_main -- every case under Lprobe.
//   Callee-saved used: x19 = the record, x20 = the error bits. Frame 96.
    .globl _sea_main
    .p2align 2
_sea_main:
    PROLOGUE
    LA x19, Lacases
Lmain_case:
    ldr x9, [x19]
    cbz x9, Lmain_done
    mov x0, x19
    bl Lprobe
    mov x20, x0                     // the ABI bits
    ldr x9, [x19, #48]              // the kind
    LA x10, Lres
    cmp x9, #1
    b.lo 1f
    b.eq 2f
    ldr x0, [x10]                   // kind 2: an object of count 1
    ldr x11, [x0]
    cmp x11, #1
    b.eq 3f
    orr x20, x20, #32
3:  REL x0                          // released (a str[] with its strings)
    b 4f
1:  ldr x11, [x10]                  // kind 0: x0
    b 5f
2:  ldr x11, [x10, #8]              // kind 1: d0's bits
5:  ldr x12, [x19, #56]
    cmp x11, x12
    b.eq 4f
    orr x20, x20, #32
4:  ldr x9, [x19, #8]               // parse_i64: its own frame only
    LA x10, _sea_parse_i64
    cmp x9, x10
    b.ne 6f
    LA x10, Ldepth
    ldr x10, [x10]
    cmp x10, #512
    b.ls 6f
    orr x20, x20, #64
6:  ldr x0, [x19]
    bl Lput_cstr
    cbnz x20, Lmain_bad
    TXT ": ok\n"
    add x19, x19, #AR_SIZE
    b Lmain_case
Lmain_bad:
    TXT ": BAD "
    mov x0, x20
    bl Lput_dec
    TXT "\n"
    bl _sea_out_flush
    mov w0, #1
    bl _exit
Lmain_done:
    EPILOGUE

    .section __DATA,__const
    .p2align 3
Lacases:
    CASE "read_lines in.txt", _sea_read_lines, Lpath, 0, 0, 0, 2, 0
    CASE "split one-byte separator", _sea_split, Ls_csv, Ls_comma, 0, 0, 2, 0
    CASE "split two-byte separator", _sea_split, Ls_colons, Ls_cc, 0, 0, 2, 0
    CASE "parse_i64 -2^63", _sea_parse_i64, Ls_min, 10, 0, 0, 0, 0x8000000000000000
    CASE "parse_i64 base 36", _sea_parse_i64, Ls_zz, 36, 0, 0, 0, 1295
    CASE "parse_f64 short", _sea_parse_f64, Ls_f15, 0, 0, 0, 1, 0x3FF8000000000000
    CASE "parse_f64 long", _sea_parse_f64, Ls_flong, 0, 0, 0, 1, 0x3FF8000000000000
    CASE "parse_f64 word", _sea_parse_f64, Ls_minf, 0, 0, 0, 1, 0xFFF0000000000000
    CASE "substr range", _sea_substr, Ls_hello, 1, 4, 0, 2, 0
    CASE "substr empty", _sea_substr, Ls_hello, 9, 2, 0, 2, 0
    .quad 0

    SSTR Lpath, 6, "in.txt"
    SSTR Ls_csv, 6, "a,b,,c"
    SSTR Ls_comma, 1, ","
    SSTR Ls_colons, 7, "a::b::c"
    SSTR Ls_cc, 2, "::"
    SSTR Ls_min, 20, "-9223372036854775808"
    SSTR Ls_zz, 2, "zz"
    SSTR Ls_f15, 3, "1.5"
    SSTR Ls_flong, 303, "0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001.5"
    SSTR Ls_minf, 4, "-Inf"
    SSTR Ls_hello, 5, "hello"
    SSTR Lfile, 5, "m.sea"
    .p2align 3
    .globl _sea_sites
_sea_sites:
    .quad Lfile, 3
