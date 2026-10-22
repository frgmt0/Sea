// =====================================================================
// sea/runtime/arm64_macos/rt_str.s -- string entries (DESIGN.md 4.1,
// 4.8 entries STR_CAT, STR_CMP, STR_LOWER, STR_I64, STR_F64;
// LANGUAGE.md 4.4, 10.9).
//
// Defines (global, rt.inc SEA_ENTRY_LIST):
//   _sea_str_cat   (a, b, site)  -> a new string: a's bytes, then b's
//   _sea_str_cmp   (a, b)        -> -1, 0, 1: byte-wise, unsigned, the
//                                   proper prefix first
//   _sea_str_lower (s, site)     -> a new string, A-Z as a-z
//   _sea_str_i64   (v, site)     -> a new string: v in decimal
//   _sea_str_f64   (d0 = x, x0 = site) -> a new string: nan, inf, -inf
//                                   or C's %.17g of x
// Uses: _sea_alloc, _sea_live (rt_mem.s), _sea_err (rt_err.s); memcpy,
//       memcmp, snprintf (libSystem).
//
// A string is one block of SEA_STR_BYTES + length bytes (DESIGN.md 4.1):
// count 1, tag SEA_TAG_STR with bytes 9..15 zero, the length, the bytes
// (no NUL). Every new string adds one to the live counter. Arguments are
// borrowed; a result is owned by the caller. A length above
// SEA_LIM_STR_BYTES, or no memory, is _sea_err(SEA_E_OUT_OF_MEMORY, site).
// The program never calls setlocale: snprintf runs in the C locale.
// =====================================================================
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

.equ RT_STR_DEC_BYTES,  32          /* digits of an i64 (at most 20) and a sign */
.equ RT_STR_G17_BYTES,  32          /* %.17g text: at most 24 bytes ("-2.2250738585072014e-308") and a NUL */

    .section __TEXT,__text,regular,pure_instructions

// ---------------------------------------------------------------------
// Lrt_str_make -- a new string object of a given length, bytes unset.
//   Inputs  : x0 = length (<= SEA_LIM_STR_BYTES), x1 = site
//   Outputs : x0 = the string (count 1, tag, length set)
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = length
//   Frame   : 32 bytes (frame record + x19, pad)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_str_make:
    stp x29, x30, [sp, #-32]!       // frame record
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    add x0, x0, #SEA_STR_BYTES      // header and bytes: one block
    bl _sea_alloc                   // x1 = site; noreturn on failure
    mov x9, #1
    str x9, [x0, #SEA_STR_RC]       // count 1
    str xzr, [x0, #SEA_STR_TAG]     // bytes 8..15 zero
    mov w9, #SEA_TAG_STR
    strb w9, [x0, #SEA_STR_TAG]
    str x19, [x0, #SEA_STR_LEN]
    adrp x9, _sea_live@PAGE
    ldr x10, [x9, _sea_live@PAGEOFF]
    add x10, x10, #1                // one more live object
    str x10, [x9, _sea_live@PAGEOFF]
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// ---------------------------------------------------------------------
// Lrt_str_from -- a new string holding a copy of a byte range.
//   Inputs  : x0 = bytes, x1 = length (<= SEA_LIM_STR_BYTES), x2 = site
//   Outputs : x0 = the string
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = source, x20 = length, x21 = the string
//   Frame   : 48 bytes (frame record + x19..x21, pad)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_str_from:
    stp x29, x30, [sp, #-48]!       // frame record
    mov x29, sp
    stp x19, x20, [sp, #16]
    str x21, [sp, #32]
    mov x19, x0
    mov x20, x1
    mov x0, x1
    mov x1, x2
    bl Lrt_str_make
    mov x21, x0
    add x0, x0, #SEA_STR_BYTES      // copy the bytes in
    mov x1, x19
    mov x2, x20
    bl _memcpy
    mov x0, x21
    ldr x21, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// ---------------------------------------------------------------------
// _sea_str_cat -- the entry STR_CAT (always a new object).
//   Inputs  : x0 = a, x1 = b, x2 = site
//   Outputs : x0 = the new string a + b
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = a, x20 = b, x21 = the result, x22 = a's
//             length
//   Frame   : 48 bytes (frame record + x19..x22)
// ---------------------------------------------------------------------
    .globl _sea_str_cat
    .p2align 2
_sea_str_cat:
    stp x29, x30, [sp, #-48]!       // frame record
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    mov x20, x1
    ldr x22, [x19, #SEA_STR_LEN]
    ldr x9, [x20, #SEA_STR_LEN]
    add x0, x22, x9                 // each <= 2^31 - 1: no overflow
    mov x10, #SEA_LIM_STR_BYTES
    cmp x0, x10
    b.hi Lrt_str_cat_oom            // longer than a str may be
    mov x1, x2
    bl Lrt_str_make
    mov x21, x0
    add x0, x21, #SEA_STR_BYTES     // a's bytes first
    add x1, x19, #SEA_STR_BYTES
    mov x2, x22
    bl _memcpy
    add x0, x21, #SEA_STR_BYTES
    add x0, x0, x22                 // then b's
    add x1, x20, #SEA_STR_BYTES
    ldr x2, [x20, #SEA_STR_LEN]
    bl _memcpy
    mov x0, x21
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret
Lrt_str_cat_oom:
    mov w0, #SEA_E_OUT_OF_MEMORY
    mov x1, x2                      // the site
    mov x2, #0
    bl _sea_err                     // noreturn

// ---------------------------------------------------------------------
// _sea_str_cmp -- the entry STR_CMP.
//   Purpose : compare the common prefix byte-wise as unsigned values
//             (memcmp); if it is equal, the shorter string is the lesser.
//   Inputs  : x0 = a, x1 = b
//   Outputs : x0 = -1, 0 or 1
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = a's length, x20 = b's length
//   Frame   : 32 bytes (frame record + x19, x20)
// ---------------------------------------------------------------------
    .globl _sea_str_cmp
    .p2align 2
_sea_str_cmp:
    stp x29, x30, [sp, #-32]!       // frame record
    mov x29, sp
    stp x19, x20, [sp, #16]
    ldr x19, [x0, #SEA_STR_LEN]
    ldr x20, [x1, #SEA_STR_LEN]
    cmp x19, x20
    csel x2, x19, x20, lo           // the common length
    add x0, x0, #SEA_STR_BYTES
    add x1, x1, #SEA_STR_BYTES
    bl _memcmp                      // unsigned bytes; any sign and size
    cmp w0, #0
    b.ne 1f
    cmp x19, x20                    // equal prefix: the lengths decide
1:  cset x0, gt                     // 1 if greater
    csinv x0, x0, xzr, ge           // -1 if less, else 0 or 1
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// ---------------------------------------------------------------------
// _sea_str_lower -- the entry STR_LOWER.
//   Purpose : a new string, the bytes 0x41..0x5A ('A'..'Z') replaced by
//             0x61..0x7A, every other byte unchanged (LANGUAGE.md 10.9).
//   Inputs  : x0 = s, x1 = site
//   Outputs : x0 = the new string
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = s
//   Frame   : 32 bytes (frame record + x19, pad)
// ---------------------------------------------------------------------
    .globl _sea_str_lower
    .p2align 2
_sea_str_lower:
    stp x29, x30, [sp, #-32]!       // frame record
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    ldr x0, [x19, #SEA_STR_LEN]
    bl Lrt_str_make                 // x1 = site
    ldr x9, [x19, #SEA_STR_LEN]     // bytes to go
    add x10, x19, #SEA_STR_BYTES    // source
    add x11, x0, #SEA_STR_BYTES     // destination
1:  cbz x9, 3f
    ldrb w12, [x10], #1
    sub w13, w12, #'A'
    cmp w13, #('Z' - 'A')
    b.hi 2f                         // not an upper-case ASCII letter
    add w12, w12, #('a' - 'A')
2:  strb w12, [x11], #1
    sub x9, x9, #1
    b 1b
3:  ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// ---------------------------------------------------------------------
// _sea_str_i64 -- the entry STR_I64.
//   Purpose : v in decimal, '-' before a negative value, no leading
//             zeros (-9223372036854775808 for -2^63).
//   Inputs  : x0 = v, x1 = site
//   Outputs : x0 = the new string
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: none
//   Frame   : 16 bytes (frame record) + RT_STR_DEC_BYTES (digits) = 48
// ---------------------------------------------------------------------
    .globl _sea_str_i64
    .p2align 2
_sea_str_i64:
    stp x29, x30, [sp, #-16]!       // frame record
    mov x29, sp
    sub sp, sp, #RT_STR_DEC_BYTES
    mov x2, x1                      // site, for Lrt_str_from
    // Magnitude as an unsigned value (2^63 for INT64_MIN is exact).
    cmp x0, #0
    cset w11, lt                    // negative?
    cneg x10, x0, lt
    add x9, sp, #RT_STR_DEC_BYTES   // digits right to left from the end
    mov x12, #10
1:  udiv x13, x10, x12
    msub x14, x13, x12, x10         // the next digit
    add w14, w14, #'0'
    strb w14, [x9, #-1]!
    mov x10, x13
    cbnz x10, 1b
    cbz w11, 2f
    mov w14, #'-'
    strb w14, [x9, #-1]!
2:  add x1, sp, #RT_STR_DEC_BYTES
    sub x1, x1, x9                  // length
    mov x0, x9
    bl Lrt_str_from
    add sp, sp, #RT_STR_DEC_BYTES
    ldp x29, x30, [sp], #16
    ret

// ---------------------------------------------------------------------
// _sea_str_f64 -- the entry STR_F64 (LANGUAGE.md 10.9, user decision C2).
//   Purpose : `nan` for every NaN (any sign and payload), `inf` for +Inf,
//             `-inf` for -Inf, otherwise the bytes of C's %.17g of x
//             (through snprintf: 0.10000000000000001, -0, 100,
//             1.0000000000000001e+300).
//   Inputs  : d0 = x, x0 = site
//   Outputs : x0 = the new string
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = site
//   Frame   : 32 bytes (frame record + x19, pad) + 16 (the variadic
//             slot at [sp]) + RT_STR_G17_BYTES (text at [sp, #16]) = 80
// ---------------------------------------------------------------------
    .globl _sea_str_f64
    .p2align 2
_sea_str_f64:
    stp x29, x30, [sp, #-32]!       // frame record
    mov x29, sp
    str x19, [sp, #16]
    sub sp, sp, #(16 + RT_STR_G17_BYTES)
    mov x19, x0
    fcmp d0, d0
    b.vs Lrt_str_f64_nan            // unordered with itself: NaN
    fmov x9, d0
    lsl x10, x9, #1                 // |bits| << 1
    movz x11, #0xFFE0, lsl #48      // Inf's bits << 1
    cmp x10, x11
    b.eq Lrt_str_f64_inf
    // Finite: snprintf(text, size, "%.17g", x); the double is variadic,
    // so on Apple arm64 it goes in the stack slot at [sp].
    str d0, [sp]
    add x0, sp, #16
    mov x1, #RT_STR_G17_BYTES
    adrp x2, Lrt_str_s_g17@PAGE
    add x2, x2, Lrt_str_s_g17@PAGEOFF
    bl _snprintf
    sxtw x1, w0                     // the text's length
    add x0, sp, #16
    b Lrt_str_f64_make
Lrt_str_f64_nan:
    adrp x0, Lrt_str_s_nan@PAGE
    add x0, x0, Lrt_str_s_nan@PAGEOFF
    mov x1, #3
    b Lrt_str_f64_make
Lrt_str_f64_inf:
    adrp x0, Lrt_str_s_minf@PAGE    // "-inf": the sign bit decides
    add x0, x0, Lrt_str_s_minf@PAGEOFF
    mov x1, #4
    tbnz x9, #63, Lrt_str_f64_make
    add x0, x0, #1                  // "inf"
    mov x1, #3
Lrt_str_f64_make:
    mov x2, x19
    bl Lrt_str_from
    add sp, sp, #(16 + RT_STR_G17_BYTES)
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

    .section __TEXT,__cstring,cstring_literals
Lrt_str_s_g17:  .asciz "%.17g"
    .section __TEXT,__const
Lrt_str_s_nan:  .ascii "nan"
Lrt_str_s_minf: .ascii "-inf"
