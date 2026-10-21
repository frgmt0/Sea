// =====================================================================
// sea/runtime/arm64_macos/rt_fmt.s -- the pre-parsed printf engine
// (LANGUAGE.md 11.1; DESIGN.md 4.5, 4.8).
//
// Defines:
//   _sea_printf   (global, SEA_ENT_PRINTF) format a pre-parsed format
//                 (SEA_FMT_*) with its argument slots into the standard
//                 output, through _sea_out_bytes
//   _sea_fmt_g    (private to the runtime) an f64 as Sea's printf("%g")
//                 prints it, for _sea_err's `f` arguments (DESIGN.md 2.6.2)
// Uses:
//   _sea_out_bytes (rt_out.s) x0 = bytes, x1 = length (> 0), x2 = site
//                 index; appends to the standard-output buffer and returns
//                 normally (a failed write is reported there, noreturn)
//   _snprintf     (libSystem) the digits of finite f64 conversions
//
// How each conversion is made (LANGUAGE.md 11.1, DESIGN.md 4.5):
//   * integers (i64, bool; %d of an integral f64 below 2^63) by own code;
//     %d of an integral f64 of magnitude >= 2^63 takes its exact digits
//     from snprintf("%.0f", |x|), which is exact for an integral value;
//   * finite f64 for f F e E g G (and %d of a non-integral f64, which is
//     %e with precision 6) through snprintf with a single-conversion C
//     format built from the piece: the flags + space #, the precision and
//     the letter. Width and the 0 and - flags are applied here, so a
//     width of any size costs no buffer;
//   * a precision above RTF_PREC_MAX is clamped for snprintf and the
//     missing digits are appended as zeros (before the exponent): the
//     exact decimal expansion of a binary64 has at most 767 significant
//     digits and at most 1074 digits after the point, so every digit
//     beyond RTF_PREC_MAX (of %f, %e, or %#g) is 0. %g without # strips
//     trailing zeros anyway, and the %g style choice (P > X) is the same
//     for every P > 308;
//   * NaN, Inf, -Inf in MATLAB spelling, never through C: NaN never
//     signed, +Inf as Inf, +Inf (flag +) or " Inf" (flag space), padded
//     with spaces only (0 and # and the precision are ignored);
//   * %s: the string's bytes, at most `precision` of them; width counts
//     bytes; padding with spaces.
// The program never calls setlocale, so snprintf runs in the C locale
// ('.' as the decimal point) and in the default rounding mode.
// =====================================================================
.include "limits.inc"
.include "rt.inc"

// Size of the conversion buffer in _sea_printf's frame. The longest text
// snprintf writes into it: %f with precision RTF_PREC_MAX of -DBL_MAX,
// 1 + 309 + 1 + RTF_PREC_MAX bytes + NUL = 1412 (see RTF_PREC_MAX).
.equ RTF_BUF,           1536
// Largest precision passed to snprintf (>= 1074 digits after the point
// and >= 767 significant digits: every digit beyond it is exactly 0).
.equ RTF_PREC_MAX,      1100
// C's default precision of f F e E g G.
.equ RTF_PREC_DEFAULT,  6
// Buffer of _sea_fmt_g: "%g" text is at most 13 bytes ("-2.22507e-308").
.equ RTF_GBUF,          32

    .section __TEXT,__text,regular,pure_instructions

// ---------------------------------------------------------------------
// _sea_printf -- format a pre-parsed format into the standard output.
//   Purpose : LANGUAGE.md 11.1; the entry PRINTF of DESIGN.md 4.8.
//   Inputs  : x0 = pre-parsed format (SEA_FMT_*), x1 = argument slots
//             (SEA_SLOT_SIZE each, one per conversion piece, in order),
//             x2 = site index (passed to _sea_out_bytes for the error
//             report of a failed write)
//   Outputs : none
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = current piece, x20 = pieces left,
//             x21 = next argument slot, x22 = site index,
//             x23 = conversion letter, then the sign length (0 or 1) of
//             an integer conversion, x24 = flags (SEA_FF_*),
//             x25 = argument class (SEA_CLS_*), x26 = width (-1 absent),
//             x27 = precision (-1 absent), x28 = the argument slot value
//   Frame   : 96 bytes (frame record + x19..x28) + RTF_BUF (conversion
//             buffer at [sp]) = 1632 bytes
// ---------------------------------------------------------------------
    .globl _sea_printf
    .p2align 2
_sea_printf:
    stp x29, x30, [sp, #-96]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp x27, x28, [sp, #80]
    sub sp, sp, #RTF_BUF            // conversion buffer at [sp]
    ldr x20, [x0, #SEA_FMT_NPIECE]  // pieces to go
    add x19, x0, #SEA_FMT_PIECES    // first piece
    mov x21, x1                     // first argument slot
    mov x22, x2                     // site index for write errors

Lrt_fmt_printf_loop:
    cbz x20, Lrt_fmt_printf_done
    ldrb w9, [x19, #SEA_FP_KIND]
    cmp w9, #SEA_FPK_CONV
    b.eq Lrt_fmt_printf_conv
    // Text piece: its bytes as they are (%% is already a single %).
    ldr x0, [x19, #SEA_FP_TEXT]
    ldr x1, [x19, #SEA_FP_TLEN]
    mov x2, x22
    bl Lrt_fmt_out
    b Lrt_fmt_printf_next

Lrt_fmt_printf_conv:
    // Load the piece's fields and consume one argument slot.
    ldrb w23, [x19, #SEA_FP_CONV]
    ldrb w24, [x19, #SEA_FP_FLAGS]
    ldrb w25, [x19, #SEA_FP_CLS]
    ldrsw x26, [x19, #SEA_FP_WIDTH]
    ldrsw x27, [x19, #SEA_FP_PREC]
    ldr x28, [x21], #SEA_SLOT_SIZE
    // Dispatch on the letter: s, d/i, else the float letters f F e E g G
    // (pass 2 admits no other letter, LANGUAGE.md 11.1).
    cmp w23, #'s'
    b.eq Lrt_fmt_printf_str
    cmp w23, #'d'
    b.eq Lrt_fmt_printf_int
    cmp w23, #'i'
    b.eq Lrt_fmt_printf_int

    // ---- f F e E g G -------------------------------------------------
    // An i64 argument is converted (round to nearest, ties to even:
    // scvtf in the default FPCR mode); it is always finite.
    cmp w25, #SEA_CLS_I
    b.ne 1f
    scvtf d0, x28
    b Lrt_fmt_printf_float
1:  fmov d0, x28
    // Non-finite: |bits| << 1 >= the bits of Inf << 1.
    lsl x9, x28, #1
    movz x10, #0xFFE0, lsl #48
    cmp x9, x10
    b.hs Lrt_fmt_printf_nonfinite

    // Finite f64 in d0, letter w23, precision x27: digits by snprintf.
Lrt_fmt_printf_float:
    mov w0, w23                     // letter
    mov w1, w24                     // flags (+ space # are used)
    mov x2, x27                     // precision
    mov x3, sp                      // into the conversion buffer
    mov x4, #RTF_BUF
    bl Lrt_fmt_float                // x0 len, x1 zeros, x2 split, x3 sign len
    // Lay out: body at [sp], zeros inserted at the split, width/0/-.
    mov x9, x2
    mov x4, x1                      // zeros to insert
    mov x1, x0                      // body length
    mov x2, x3                      // sign length
    mov x3, x9                      // split position
    mov x0, sp
    mov x5, x26                     // width
    mov w9, #(SEA_FF_LEFT | SEA_FF_ZERO)
    and w6, w24, w9                 // 0 is honoured for finite floats
    mov x7, x22
    bl Lrt_fmt_emit
    b Lrt_fmt_printf_next

    // ---- NaN, Inf, -Inf (bits in x28) -------------------------------
Lrt_fmt_printf_nonfinite:
    mov x0, sp
    mov x1, x28
    mov w2, w24
    bl Lrt_fmt_nonfinite            // x0 = length of the spelling at [sp]
    mov x1, x0                      // body length
    mov x0, sp
    mov x2, #0                      // no sign to keep in front of zeros
    mov x3, x1                      // no split
    mov x4, #0                      // no zeros inserted
    mov x5, x26                     // width
    and w6, w24, #SEA_FF_LEFT       // spaces only: 0 and # are ignored
    mov x7, x22
    bl Lrt_fmt_emit
    b Lrt_fmt_printf_next

    // ---- s ------------------------------------------------------------
Lrt_fmt_printf_str:
    ldr x1, [x28, #SEA_STR_LEN]     // bytes in the string
    tbnz x27, #63, 1f               // no precision: all of them
    cmp x27, x1
    csel x1, x27, x1, lo            // precision truncates (in bytes)
1:  add x0, x28, #SEA_STR_BYTES
    mov x2, #0
    mov x3, x1                      // no split
    mov x4, #0
    mov x5, x26                     // width counts bytes
    and w6, w24, #SEA_FF_LEFT       // spaces only
    mov x7, x22
    bl Lrt_fmt_emit
    b Lrt_fmt_printf_next

    // ---- d i ------------------------------------------------------------
Lrt_fmt_printf_int:
    cmp w25, #SEA_CLS_F
    b.eq Lrt_fmt_printf_intf
    // i64 (or bool, 0/1): magnitude as an unsigned 64-bit value, so
    // INT64_MIN's magnitude 2^63 is exact.
    cmp x28, #0
    cset w11, lt                    // negative?
    cneg x10, x28, lt               // |value| (mod 2^64)

    // Unsigned magnitude x10, negative flag w11.
Lrt_fmt_printf_intu:
    bl Lrt_fmt_printf_intsign       // sign at [sp]; x23 = sign length
    // C: precision 0 with the value 0 prints no digits.
    cbnz x27, 1f
    cbnz x10, 1f
    mov x0, #0
    b Lrt_fmt_printf_inttail
    // Digits right to left at the end of the buffer, then moved to
    // [sp + sign length].
1:  add x12, sp, #RTF_BUF           // end of the buffer
    mov x13, #10
2:  udiv x14, x10, x13              // quotient
    msub x15, x14, x13, x10         // remainder = next digit
    add w15, w15, #'0'
    strb w15, [x12, #-1]!
    mov x10, x14
    cbnz x10, 2b
    add x14, sp, #RTF_BUF
    sub x0, x14, x12                // number of digits (1 .. 20)
    add x9, sp, x23                 // destination after the sign
    mov x13, x0
3:  ldrb w15, [x12], #1
    strb w15, [x9], #1
    subs x13, x13, #1
    b.ne 3b
    b Lrt_fmt_printf_inttail

    // %d of an f64 (bits in x28): MATLAB rule (LANGUAGE.md 11.1).
Lrt_fmt_printf_intf:
    lsl x9, x28, #1
    movz x10, #0xFFE0, lsl #48
    cmp x9, x10
    b.hs Lrt_fmt_printf_nonfinite   // NaN, Inf, -Inf
    fmov d0, x28
    frintz d1, d0
    fcmp d1, d0
    b.ne Lrt_fmt_printf_intnonint   // not integral: %e, precision 6
    // Integral. Below 2^63 in magnitude it converts exactly to i64;
    // -0.0 is the integer 0 (no sign).
    fabs d2, d0
    movz x9, #0x43E0, lsl #48       // bits of 2^63
    fmov d3, x9
    fcmp d2, d3
    b.ge Lrt_fmt_printf_intbig
    fcvtzs x9, d0
    cmp x9, #0
    cset w11, lt
    cneg x10, x9, lt
    b Lrt_fmt_printf_intu

    // |x| >= 2^63, integral: the exact digits of snprintf("%.0f", |x|).
Lrt_fmt_printf_intbig:
    fcmp d0, #0.0
    cset w11, mi                    // negative?
    bl Lrt_fmt_printf_intsign       // sign at [sp]; x23 = sign length
    fmov d0, x28
    fabs d0, d0
    mov w0, #'f'
    mov w1, #0                      // no flags: digits only
    mov x2, #0                      // precision 0
    add x3, sp, x23                 // after the sign
    mov x4, #RTF_BUF
    sub x4, x4, x23
    bl Lrt_fmt_float                // x0 = number of digits
    b Lrt_fmt_printf_inttail

    // Non-integral f64 under %d: %e with the same flags and width and
    // precision 6.
Lrt_fmt_printf_intnonint:
    mov w23, #'e'
    mov x27, #RTF_PREC_DEFAULT
    b Lrt_fmt_printf_float

    // Integer layout: [sp] = sign (x23 bytes) + x0 digits. The precision
    // is the minimum number of digits (zeros inserted after the sign);
    // with a precision the 0 flag is ignored (C99 7.19.6.1).
Lrt_fmt_printf_inttail:
    subs x4, x27, x0                // zeros = precision - digits
    csel x4, x4, xzr, gt            // (none if <= 0 or no precision)
    add x1, x23, x0                 // body length
    mov x0, sp
    mov x2, x23                     // sign stays in front
    mov x3, x23                     // zeros go right after the sign
    mov x5, x26                     // width
    mov w9, #(SEA_FF_LEFT | SEA_FF_ZERO)
    and w6, w24, w9
    tbnz x27, #63, 1f
    bic w6, w6, #SEA_FF_ZERO        // a precision cancels the 0 flag
1:  mov x7, x22
    bl Lrt_fmt_emit

Lrt_fmt_printf_next:
    add x19, x19, #SEA_FP_SIZE
    sub x20, x20, #1
    b Lrt_fmt_printf_loop

Lrt_fmt_printf_done:
    add sp, sp, #RTF_BUF
    ldp x27, x28, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #96
    ret

    // Local subroutine of _sea_printf (shares its frame: called with bl
    // from inside it, so [sp] here is _sea_printf's buffer).
    //   Inputs : w11 = negative (0/1), w24 = flags
    //   Outputs: the sign byte at [sp] ('-', '+' or ' ') if any;
    //            x23 = its length (0 or 1)
    //   Clobbers: w9, x23
Lrt_fmt_printf_intsign:
    mov x23, #0
    cbz w11, 1f
    mov w9, #'-'
    b 3f
1:  tst w24, #SEA_FF_PLUS
    b.eq 2f
    mov w9, #'+'
    b 3f
2:  tst w24, #SEA_FF_SPACE
    b.eq 4f
    mov w9, #' '
3:  strb w9, [sp]
    mov x23, #1
4:  ret

// ---------------------------------------------------------------------
// Lrt_fmt_nonfinite -- spell NaN, Inf or -Inf (LANGUAGE.md 11.1).
//   Inputs  : x0 = destination (>= 4 bytes), x1 = the f64's bits (NaN or
//             +-Inf), w2 = flags (only + and space are looked at)
//   Outputs : x0 = length written (3 or 4); no NUL
//   Clobbers: x1-x4
//   Callee-saved used: none
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_fmt_nonfinite:
    lsl x3, x1, #1
    movz x4, #0xFFE0, lsl #48
    cmp x3, x4
    b.hi Lrt_fmt_nonfinite_nan      // above Inf: NaN, never signed
    mov x3, x0                      // cursor
    tbnz x1, #63, Lrt_fmt_nonfinite_neg
    // +Inf: "+Inf" with +, " Inf" with space (C's sign rules), else "Inf".
    tst w2, #SEA_FF_PLUS
    b.eq 1f
    mov w4, #'+'
    strb w4, [x3], #1
    b Lrt_fmt_nonfinite_inf
1:  tst w2, #SEA_FF_SPACE
    b.eq Lrt_fmt_nonfinite_inf
    mov w4, #' '
    strb w4, [x3], #1
    b Lrt_fmt_nonfinite_inf
Lrt_fmt_nonfinite_neg:
    mov w4, #'-'
    strb w4, [x3], #1
Lrt_fmt_nonfinite_inf:
    mov w4, #'I'
    strb w4, [x3], #1
    mov w4, #'n'
    strb w4, [x3], #1
    mov w4, #'f'
    strb w4, [x3], #1
    sub x0, x3, x0                  // length
    ret
Lrt_fmt_nonfinite_nan:
    mov w4, #'N'
    strb w4, [x0]
    mov w4, #'a'
    strb w4, [x0, #1]
    mov w4, #'N'
    strb w4, [x0, #2]
    mov x0, #3
    ret

// ---------------------------------------------------------------------
// Lrt_fmt_float -- the text of a finite f64 under one C conversion.
//   Purpose : snprintf(buf, size, "%[+][ ][#].<p><letter>", x), with the
//             precision clamped to RTF_PREC_MAX; reports how many zeros
//             the clamp left out and where they belong.
//   Inputs  : d0 = x (finite), w0 = letter (f F e E g G), w1 = flags
//             (SEA_FF_PLUS, SEA_FF_SPACE, SEA_FF_ALT are used),
//             x2 = precision (-1: absent, C's default 6), x3 = buffer,
//             x4 = its size (enough for the clamped text and a NUL)
//   Outputs : x0 = length of the text in the buffer (no sign stripped),
//             x1 = zeros to insert (precision beyond RTF_PREC_MAX of
//             f F e E, and of g G with #), x2 = split: where the zeros
//             go (the offset of 'e'/'E', else the length), x3 = sign
//             length (1 if the text starts with '-', '+' or ' ', else 0)
//   Clobbers: x0-x17, d0-d7, d16-d31
//   Callee-saved used: x19 = buffer, x20 = letter, x21 = zeros to insert,
//             x22 = buffer size
//   Frame   : 48 bytes (frame record + x19..x22) + 16 (variadic slot at
//             [sp]) + 32 (C format at [sp, #16]) = 96 bytes
// ---------------------------------------------------------------------
    .p2align 2
Lrt_fmt_float:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    sub sp, sp, #48
    mov x19, x3
    mov w20, w0
    mov x22, x4
    // Absent precision: C's default.
    tbz x2, #63, 1f
    mov x2, #RTF_PREC_DEFAULT
    // Clamp; the zeros left out are exact (see the file header).
1:  mov x21, #0
    cmp x2, #RTF_PREC_MAX
    b.le 2f
    sub x21, x2, #RTF_PREC_MAX
    mov x2, #RTF_PREC_MAX
2:  // g/G without # strips trailing zeros: nothing to insert.
    orr w9, w20, #0x20              // lower-case letter
    cmp w9, #'g'
    b.ne 3f
    tst w1, #SEA_FF_ALT
    csel x21, xzr, x21, eq
3:  // Build the C format at [sp, #16].
    add x9, sp, #16
    mov w10, #'%'
    strb w10, [x9], #1
    tst w1, #SEA_FF_PLUS
    b.eq 4f
    mov w10, #'+'
    strb w10, [x9], #1
4:  tst w1, #SEA_FF_SPACE
    b.eq 5f
    mov w10, #' '
    strb w10, [x9], #1
5:  tst w1, #SEA_FF_ALT
    b.eq 6f
    mov w10, #'#'
    strb w10, [x9], #1
6:  mov w10, #'.'
    strb w10, [x9], #1
    // Precision (0 .. RTF_PREC_MAX) in decimal: digits right to left in
    // the variadic slot's spare bytes [sp, #8..15], then copied.
    add x11, sp, #16                // one past the scratch digits
    mov x12, #10
7:  udiv x13, x2, x12
    msub x14, x13, x12, x2
    add w14, w14, #'0'
    strb w14, [x11, #-1]!
    mov x2, x13
    cbnz x2, 7b
    add x13, sp, #16
8:  ldrb w14, [x11], #1
    strb w14, [x9], #1
    cmp x11, x13
    b.lo 8b
    strb w20, [x9], #1              // the letter
    strb wzr, [x9]                  // NUL
    // snprintf(buffer, size, format, x): the double is variadic, so on
    // Apple arm64 it goes in the stack slot at [sp].
    str d0, [sp]
    mov x0, x19
    mov x1, x22
    add x2, sp, #16
    bl _snprintf
    sxtw x0, w0                     // text length (fits: see RTF_BUF)
    // Split: the exponent letter, if any.
    mov x2, #0
9:  cmp x2, x0
    b.eq 10f
    ldrb w9, [x19, x2]
    orr w9, w9, #0x20
    cmp w9, #'e'
    b.eq 10f
    add x2, x2, #1
    b 9b
10: // Sign length.
    mov x3, #0
    ldrb w9, [x19]
    cmp w9, #'-'
    b.eq 11f
    cmp w9, #'+'
    b.eq 11f
    cmp w9, #' '
    b.ne 12f
11: mov x3, #1
12: mov x1, x21
    add sp, sp, #48
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// ---------------------------------------------------------------------
// Lrt_fmt_emit -- write a converted field with its padding.
//   Purpose : body = sign (signlen bytes) + rest; `zeros` zeros are
//             inserted at offset `split` (precision zeros); the field is
//             padded to the width: spaces on the left, or on the right
//             with SEA_FF_LEFT, or zeros after the sign with SEA_FF_ZERO
//             (ignored with SEA_FF_LEFT, as in C).
//   Inputs  : x0 = body, x1 = body length, x2 = sign length,
//             x3 = split (sign length <= split <= body length),
//             x4 = zeros to insert, x5 = width (-1: absent),
//             w6 = flags (only SEA_FF_LEFT and SEA_FF_ZERO are looked
//             at), x7 = site index
//   Outputs : none
//   Clobbers: x0-x17, d0-d7, d16-d31, flags (calls _sea_out_bytes)
//   Callee-saved used: x19 = body, x20 = body length, x21 = sign length,
//             x22 = split, x23 = zeros, x24 = site, x25 = padding,
//             x26 = flags
//   Frame   : 80 bytes (frame record + x19..x26)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_fmt_emit:
    stp x29, x30, [sp, #-80]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x23, x4
    mov x24, x7
    mov w26, w6
    // padding = width - (body + zeros), at least 0 (width -1: none).
    add x9, x1, x4
    subs x25, x5, x9
    csel x25, x25, xzr, gt
    // Leading spaces: neither - nor 0.
    mov w9, #(SEA_FF_LEFT | SEA_FF_ZERO)
    tst w26, w9
    b.ne 1f
    mov x0, x25
    mov w1, #' '
    mov x2, x24
    bl Lrt_fmt_fill
1:  // The sign.
    mov x0, x19
    mov x1, x21
    mov x2, x24
    bl Lrt_fmt_out
    // Zero padding: 0 without -.
    tst w26, #SEA_FF_LEFT
    b.ne 2f
    tst w26, #SEA_FF_ZERO
    b.eq 2f
    mov x0, x25
    mov w1, #'0'
    mov x2, x24
    bl Lrt_fmt_fill
2:  // Body up to the split, the inserted zeros, the rest.
    add x0, x19, x21
    sub x1, x22, x21
    mov x2, x24
    bl Lrt_fmt_out
    mov x0, x23
    mov w1, #'0'
    mov x2, x24
    bl Lrt_fmt_fill
    add x0, x19, x22
    sub x1, x20, x22
    mov x2, x24
    bl Lrt_fmt_out
    // Trailing spaces with -.
    tst w26, #SEA_FF_LEFT
    b.eq 3f
    mov x0, x25
    mov w1, #' '
    mov x2, x24
    bl Lrt_fmt_fill
3:  ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #80
    ret

// ---------------------------------------------------------------------
// Lrt_fmt_fill -- write `count` copies of a space or a zero.
//   Inputs  : x0 = count (may be 0), w1 = ' ' or '0', x2 = site index
//   Outputs : none (a failed write is the run-time error at the site)
//   Clobbers: x0-x17, d0-d7, d16-d31, flags (calls _sea_out_repeat)
//   Callee-saved used: x19 = site index
//   Frame   : 32 bytes (frame record + x19 + pad)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_fmt_fill:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x2                     // site
    mov x3, x0
    mov w0, w1                      // the byte
    mov x1, x3                      // the count
    bl _sea_out_repeat              // x0 = 0 or errno
    cbnz x0, 1f
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
1:  mov x1, x19
    bl _sea_out_fail                // noreturn

// ---------------------------------------------------------------------
// Lrt_fmt_out -- _sea_out_bytes unless the length is 0.
//   Inputs  : x0 = bytes, x1 = length, x2 = site index
//   Outputs : none
//   Clobbers: as _sea_out_bytes (x0-x17, d0-d7, d16-d31, flags)
//   Callee-saved used: none
//   Frame   : none (tail call or return)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_fmt_out:
    cbz x1, 1f
    b _sea_out_bytes                // tail call: returns to our caller
1:  ret

// ---------------------------------------------------------------------
// _sea_fmt_g -- an f64 as Sea's printf("%g") prints it.
//   Purpose : the spelling of _sea_err's `f` arguments (DESIGN.md 2.6.2):
//             C's %g (precision 6) for finite values, NaN, Inf, -Inf
//             otherwise (LANGUAGE.md 11.1).
//   Inputs  : x0 = destination (at least 16 bytes; at most 13 are
//             written, no NUL), d0 = the value
//   Outputs : x0 = number of bytes written
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = destination
//   Frame   : 32 bytes (frame record + x19 + pad) + RTF_GBUF (text at
//             [sp]) = 64 bytes
// ---------------------------------------------------------------------
    .private_extern _sea_fmt_g
    .p2align 2
_sea_fmt_g:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    sub sp, sp, #RTF_GBUF
    mov x19, x0
    // Non-finite: the MATLAB spelling, straight into the destination.
    fmov x1, d0
    lsl x9, x1, #1
    movz x10, #0xFFE0, lsl #48
    cmp x9, x10
    b.lo 1f
    mov w2, #0                      // no flags
    bl Lrt_fmt_nonfinite            // x0 = destination, x1 = bits
    b 3f
1:  // Finite: snprintf "%g" into the local buffer, then copy.
    mov w0, #'g'
    mov w1, #0
    mov x2, #-1                     // default precision 6
    mov x3, sp
    mov x4, #RTF_GBUF
    bl Lrt_fmt_float                // x0 = length
    mov x9, #0
2:  ldrb w10, [sp, x9]
    strb w10, [x19, x9]
    add x9, x9, #1
    cmp x9, x0
    b.lo 2b
3:  add sp, sp, #RTF_GBUF
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
