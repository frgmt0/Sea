// =====================================================================
// sea/runtime/arm64_macos/rt_text.s -- the text entries of phase L
// (DESIGN.md 2.15.5, 2.15.6; LANGUAGE.md 10.9; lead decisions L-mh,
// L-mi, L-mj, L-mk).
//
// Defines (global, rt.inc SEA_ENTRY_LIST):
//   _sea_split     (s, sep, site)     -> a new str[] of the fields of s
//                                        between the occurrences of sep
//   _sea_parse_i64 (s, base, site)    -> x0 = the i64 written in s
//   _sea_parse_f64 (s, site)          -> d0 = the f64 written in s,
//                                        correctly rounded
//   _sea_substr    (s, lo, hi, site)  -> a new string of s's bytes
//                                        lo .. hi - 1
// Uses: _sea_str_make (rt_str.s), _sea_arr_new (rt_arr.s), _sea_alloc,
//       _sea_free_block (rt_mem.s), _sea_err (rt_err.s); memcpy, strtod
//       (libSystem).
//
// Every argument is borrowed; every result object is owned (count 1,
// counted in _sea_live). A failing entry calls _sea_err with the site
// (its last integer argument) and never returns. No entry changes FPCR:
// strtod rounds to nearest in the C locale, which the program never
// changes (L-mj). The one scratch block (PARSE_F64's copy of a text of
// RTT_FBUF bytes or more) is uncounted and freed with its exact size
// before the entry returns or reports.
// =====================================================================
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

.equ RTT_FBUF,      256             /* PARSE_F64's frame buffer: texts shorter than this (L-mu; not a contract value) */
.equ RTT_WORD_SIZE, 24              /* a record of the word table: length, bits, 8 text bytes */
.equ RTT_WORDS,     8               /* the words of LANGUAGE.md 10.9 */

// The digit run of the parse_f64 grammar: advance xi over the bytes
// '0'..'9' of [xb, xb + xn). Clobbers w11.
.macro RTT_DIGITS xi, xb, xn
Lrtt_dig\@:
    cmp \xi, \xn
    b.hs Lrtt_dige\@                // end of the text
    ldrb w11, [\xb, \xi]
    sub w11, w11, #'0'
    cmp w11, #9
    b.hi Lrtt_dige\@                // not a digit
    add \xi, \xi, #1
    b Lrtt_dig\@
Lrtt_dige\@:
.endm

    .section __TEXT,__text,regular,pure_instructions

// ---------------------------------------------------------------------
// Lrt_text_match -- does sep occur at a position of s?
//   Inputs  : x0 = the address in s, x1 = sep's bytes, x2 = m >= 1 (the
//             caller has checked that m bytes remain)
//   Outputs : x0 = 1 if the m bytes equal sep's, else 0
//   Clobbers: x0, x9-x12, flags
//   Callee-saved used: none
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_text_match:
    mov x9, #0                      // byte index
1:  ldrb w10, [x0, x9]
    ldrb w11, [x1, x9]
    cmp w10, w11
    b.ne 2f                         // a byte differs
    add x9, x9, #1
    cmp x9, x2
    b.lo 1b
    mov x0, #1                      // all m bytes equal
    ret
2:  mov x0, #0
    ret

// ---------------------------------------------------------------------
// _sea_split -- the entry SPLIT (DESIGN.md 2.15.6; L-mh).
//   Purpose : m = len(sep), 0 is SPLIT_SEP. Pass 1 counts the
//             non-overlapping matches c scanning left to right (after a
//             match the scan resumes after it); the vector of c + 1
//             elements (ARR_NEW: ARRAY_SIZE above SEA_LIM_EXTENT); pass 2
//             repeats the scan and makes element k a new string of the
//             bytes between the previous match (or 0) and this one, the
//             last element the bytes after the last match. Every element
//             is a new string, also when c = 0.
//   Inputs  : x0 = s, x1 = sep, x2 = site
//   Outputs : x0 = the new str[] (rank 1, c + 1 elements)
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = s, x20 = sep, x21 = site, x22 = n,
//             x23 = m, x24 = c, then the vector, x25 = i (scan
//             position), x26 = b (the current field's start), x27 = k
//             (the element index), x28 = s's bytes
//   Frame   : 96 bytes (frame record + x19..x28)
// ---------------------------------------------------------------------
    .globl _sea_split
    .p2align 2
_sea_split:
    stp x29, x30, [sp, #-96]!       // frame record
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp x27, x28, [sp, #80]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    ldr x22, [x19, #SEA_STR_LEN]
    ldr x23, [x20, #SEA_STR_LEN]
    cbz x23, Lrt_text_split_empty   // an empty separator
    add x28, x19, #SEA_STR_BYTES

    // Pass 1: c = the number of matches.
    mov x24, #0
    mov x25, #0
    cmp x23, #1
    b.ne Lrt_text_split_count
    // m = 1: every byte equal to sep's one byte is a match.
    ldrb w12, [x20, #SEA_STR_BYTES]
1:  cmp x25, x22
    b.hs Lrt_text_split_alloc
    ldrb w9, [x28, x25]
    cmp w9, w12
    cinc x24, x24, eq               // one more match
    add x25, x25, #1
    b 1b
Lrt_text_split_count:
    add x9, x25, x23
    cmp x9, x22
    b.hi Lrt_text_split_alloc       // fewer than m bytes remain
    add x0, x28, x25
    add x1, x20, #SEA_STR_BYTES
    mov x2, x23
    bl Lrt_text_match
    cbz x0, 2f
    add x24, x24, #1                // a match: skip it whole
    add x25, x25, x23
    b Lrt_text_split_count
2:  add x25, x25, #1                // no match: the next position
    b Lrt_text_split_count

    // The vector of c + 1 string elements (null until filled).
Lrt_text_split_alloc:
    mov x0, #SEA_EK_STR
    mov x1, #1                      // rank 1
    add x2, x24, #1                 // rows = c + 1 (ARRAY_SIZE if too many)
    mov x3, #1                      // cols 1: a vector
    mov x4, x21
    bl _sea_arr_new
    mov x24, x0

    // Pass 2: the fields.
    mov x25, #0                     // i
    mov x26, #0                     // b
    mov x27, #0                     // k
Lrt_text_split_scan:
    add x9, x25, x23
    cmp x9, x22
    b.hi Lrt_text_split_last        // fewer than m bytes remain
    add x0, x28, x25
    add x1, x20, #SEA_STR_BYTES
    mov x2, x23
    bl Lrt_text_match
    cbnz x0, 3f
    add x25, x25, #1                // no match: the next position
    b Lrt_text_split_scan
3:  add x0, x28, x26                // a match at i: the field b .. i - 1
    sub x1, x25, x26
    mov x2, x21
    bl _sea_str_make
    ldr x9, [x24, #SEA_ARR_DATA]
    str x0, [x9, x27, lsl #3]       // element k
    add x27, x27, #1
    add x25, x25, x23               // resume after the match
    mov x26, x25                    // the next field starts there
    b Lrt_text_split_scan
Lrt_text_split_last:
    add x0, x28, x26                // the last field: b .. n - 1
    sub x1, x22, x26
    mov x2, x21
    bl _sea_str_make
    ldr x9, [x24, #SEA_ARR_DATA]
    str x0, [x9, x27, lsl #3]
    mov x0, x24
    ldp x27, x28, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #96
    ret
Lrt_text_split_empty:
    mov w0, #SEA_E_SPLIT_SEP
    mov x1, x21                     // the site
    mov x2, #0                      // no argument slots
    bl _sea_err                     // noreturn

// ---------------------------------------------------------------------
// _sea_parse_i64 -- the entry PARSE_I64 (DESIGN.md 2.15.6; L-mi).
//   Purpose : base outside 2 .. 36 is PARSE_BASE (base). Then s must be
//             an optional '+' or '-' and one or more digits of the base
//             ('0'-'9' 0-9, 'a'-'z' and 'A'-'Z' 10-35) and nothing else.
//             The magnitude is accumulated negatively: a = a * base - d,
//             with the step refused when a < ceil((-2^63 + d) / base)
//             (sdiv truncates toward zero, which is the ceiling of a
//             negative quotient), so -2^63 is reached exactly; the result
//             is a with '-', else -a (a = -2^63 is then out of range).
//             Any failure is PARSE_I64 (s, base).
//   Inputs  : x0 = s, x1 = base, x2 = site
//   Outputs : x0 = the value
//   Clobbers: x0, x9-x17, flags
//   Callee-saved used: none
//   Frame   : 32 bytes (frame record + the two error slots)
// ---------------------------------------------------------------------
    .globl _sea_parse_i64
    .p2align 2
_sea_parse_i64:
    stp x29, x30, [sp, #-32]!       // frame record (+ slots at sp+16)
    mov x29, sp
    sub x9, x1, #2
    cmp x9, #(36 - 2)
    b.hi Lrt_text_pi_base           // unsigned: below 2 (negative too) or above 36
    ldr x10, [x0, #SEA_STR_LEN]     // n
    add x11, x0, #SEA_STR_BYTES     // the bytes
    mov x12, #0                     // i
    mov w13, #0                     // 1 for a '-' sign
    cbz x10, Lrt_text_pi_bad        // the empty text
    ldrb w14, [x11]
    cmp w14, #'-'
    b.ne 1f
    mov w13, #1                     // '-': negative
    mov x12, #1
    b 2f
1:  cmp w14, #'+'
    b.ne 2f
    mov x12, #1                     // '+': skipped
2:  cmp x12, x10
    b.hs Lrt_text_pi_bad            // a sign and no digit
    mov x15, #0                     // a: minus the magnitude so far
    movz x17, #0x8000, lsl #48      // -2^63
Lrt_text_pi_loop:
    ldrb w14, [x11, x12]
    sub w9, w14, #'0'               // '0'..'9'
    cmp w9, #9
    b.ls 3f
    orr w9, w14, #0x20              // 'A'..'Z' as 'a'..'z' (no other byte lands there)
    sub w9, w9, #'a'
    cmp w9, #('z' - 'a')
    b.hi Lrt_text_pi_bad            // no digit value
    add w9, w9, #10
3:  cmp x9, x1
    b.hs Lrt_text_pi_bad            // a digit of a larger base
    add x16, x17, x9                // -2^63 + d
    sdiv x16, x16, x1               // ceil((-2^63 + d) / base)
    cmp x15, x16
    b.lt Lrt_text_pi_bad            // a * base - d < -2^63: out of range
    mul x16, x15, x1                // no overflow: a >= the bound
    sub x15, x16, x9
    add x12, x12, #1
    cmp x12, x10
    b.lo Lrt_text_pi_loop
    cbnz w13, 4f                    // '-': a is the value
    cmp x15, x17
    b.eq Lrt_text_pi_bad            // 2^63 has no i64 (x0 is still s)
    neg x15, x15
4:  mov x0, x15
    ldp x29, x30, [sp], #32
    ret
Lrt_text_pi_base:
    str x1, [sp, #16]               // slot 0 = the base
    mov w0, #SEA_E_PARSE_BASE
    mov x1, x2                      // the site
    add x2, sp, #16
    bl _sea_err                     // noreturn
Lrt_text_pi_bad:
    stp x0, x1, [sp, #16]           // slot 0 = s, slot 1 = the base
    mov w0, #SEA_E_PARSE_I64
    mov x1, x2                      // the site
    add x2, sp, #16
    bl _sea_err                     // noreturn

// ---------------------------------------------------------------------
// _sea_parse_f64 -- the entry PARSE_F64 (DESIGN.md 2.15.6; L-mj).
//   Purpose : (1) the eight words inf Inf +inf +Inf (+Inf), -inf -Inf
//             (-Inf), nan NaN (the quiet NaN #7FF8000000000000), compared
//             byte for byte, the length first; (2) otherwise the grammar
//               [ "+" | "-" ] ( digits [ "." [ digits ] ] | "." digits )
//               [ ( "e" | "E" ) [ "+" | "-" ] digits ]
//             checked over all n bytes left to right; (3) the bytes with
//             a NUL appended, in the frame buffer when n < RTT_FBUF, else
//             in an uncounted block of n + 1 bytes; x = strtod(buf, &end);
//             end must be buf + n (true after step 2; a guard); ERANGE is
//             ignored (overflow +-HUGE_VAL = +-Inf, underflow the
//             correctly rounded subnormal or zero); the block freed.
//             A failure is PARSE_F64 (s).
//   Inputs  : x0 = s, x1 = site
//   Outputs : d0 = the value
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: x19 = s, x20 = site, x21 = n, x22 = the bytes,
//             then the NUL-terminated copy
//   Frame   : 320 bytes: frame record, x19..x22 (16..47), strtod's end
//             pointer or the error slot (48), the value (56), the buffer
//             of RTT_FBUF bytes (64..319)
// ---------------------------------------------------------------------
.equ RTT_PF_END, 48
.equ RTT_PF_VAL, 56
.equ RTT_PF_BUF, 64
.equ RTT_PF_FRAME, (RTT_PF_BUF + RTT_FBUF)
    .globl _sea_parse_f64
    .p2align 2
_sea_parse_f64:
    stp x29, x30, [sp, #-RTT_PF_FRAME]!   // frame record
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    mov x20, x1
    ldr x21, [x19, #SEA_STR_LEN]
    add x22, x19, #SEA_STR_BYTES

    // (1) The words: a record matches when its length is n and its bytes
    // are s's.
    adrp x9, Lrt_text_words@PAGE
    add x9, x9, Lrt_text_words@PAGEOFF
    mov x10, #RTT_WORDS
Lrt_text_pf_word:
    ldr x11, [x9]                   // the word's length
    cmp x11, x21
    b.ne Lrt_text_pf_wnext
    mov x12, #0
1:  ldrb w13, [x22, x12]
    add x14, x9, #16
    ldrb w15, [x14, x12]
    cmp w13, w15
    b.ne Lrt_text_pf_wnext          // a byte differs
    add x12, x12, #1
    cmp x12, x11
    b.lo 1b
    ldr d0, [x9, #8]                // the word's value
    b Lrt_text_pf_ret
Lrt_text_pf_wnext:
    add x9, x9, #RTT_WORD_SIZE
    subs x10, x10, #1
    b.ne Lrt_text_pf_word

    // (2) The decimal grammar, i in x9.
    mov x9, #0
    cbz x21, Lrt_text_pf_bad        // the empty text
    ldrb w11, [x22]
    cmp w11, #'+'
    b.eq 2f
    cmp w11, #'-'
    b.ne 3f
2:  add x9, x9, #1                  // the optional sign
3:  mov x12, x9
    RTT_DIGITS x9, x22, x21         // the integer digits
    sub x13, x9, x12                // how many
    cmp x9, x21
    b.hs Lrt_text_pf_nodot
    ldrb w11, [x22, x9]
    cmp w11, #'.'
    b.ne Lrt_text_pf_nodot
    add x9, x9, #1                  // "."
    mov x12, x9
    RTT_DIGITS x9, x22, x21         // the fraction digits
    sub x14, x9, x12
    orr x14, x14, x13
    cbz x14, Lrt_text_pf_bad        // "." with no digit on either side
    b Lrt_text_pf_exp
Lrt_text_pf_nodot:
    cbz x13, Lrt_text_pf_bad        // no digit and no "."
Lrt_text_pf_exp:
    cmp x9, x21
    b.hs Lrt_text_pf_ok             // the end: a number
    ldrb w11, [x22, x9]
    orr w11, w11, #0x20             // 'E' as 'e' (only 'E' and 'e' land on 'e')
    cmp w11, #'e'
    b.ne Lrt_text_pf_bad            // another byte after the mantissa
    add x9, x9, #1
    cmp x9, x21
    b.hs Lrt_text_pf_bad            // "e" at the end
    ldrb w11, [x22, x9]
    cmp w11, #'+'
    b.eq 4f
    cmp w11, #'-'
    b.ne 5f
4:  add x9, x9, #1                  // the exponent's sign
5:  mov x12, x9
    RTT_DIGITS x9, x22, x21         // the exponent digits
    cmp x9, x12
    b.eq Lrt_text_pf_bad            // none
    cmp x9, x21
    b.ne Lrt_text_pf_bad            // a byte after the exponent

    // (3) A NUL-terminated copy, then strtod.
Lrt_text_pf_ok:
    add x0, sp, #RTT_PF_BUF         // the frame buffer ...
    cmp x21, #RTT_FBUF
    b.lo 6f
    add x0, x21, #1                 // ... or a block of n + 1 bytes
    mov x1, x20
    bl _sea_alloc                   // noreturn on failure
6:  mov x1, x22                     // the source bytes
    mov x22, x0                     // from now on: the copy
    mov x2, x21
    bl _memcpy
    strb wzr, [x22, x21]            // the NUL
    mov x0, x22
    add x1, sp, #RTT_PF_END
    bl _strtod                      // d0 = x; ERANGE ignored
    str d0, [sp, #RTT_PF_VAL]
    cmp x21, #RTT_FBUF
    b.lo 7f
    mov x0, x22
    add x1, x21, #1
    bl _sea_free_block              // the block, before any return or report
7:  ldr x9, [sp, #RTT_PF_END]
    add x10, x22, x21
    cmp x9, x10
    b.ne Lrt_text_pf_bad            // strtod stopped early (the guard)
    ldr d0, [sp, #RTT_PF_VAL]
Lrt_text_pf_ret:
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #RTT_PF_FRAME
    ret
Lrt_text_pf_bad:
    str x19, [sp, #RTT_PF_END]      // slot 0 = s
    mov w0, #SEA_E_PARSE_F64
    mov x1, x20                     // the site
    add x2, sp, #RTT_PF_END
    bl _sea_err                     // noreturn

// ---------------------------------------------------------------------
// _sea_substr -- the entry SUBSTR (DESIGN.md 2.15.6; L-mk).
//   Purpose : lo >= hi: a new empty string, whatever lo and hi are.
//             Else lo outside 0 .. n - 1 is INDEX_OOB (lo, 0, n); else
//             hi - 1 >= n is INDEX_OOB (hi - 1, 0, n) (hi - 1 >= lo >= 0
//             here); else a new string of the bytes lo .. hi - 1.
//   Inputs  : x0 = s, x1 = lo, x2 = hi, x3 = site
//   Outputs : x0 = the new string
//   Clobbers: x0-x17, d0-d7, d16-d31, flags
//   Callee-saved used: none
//   Frame   : 48 bytes (frame record + the three error slots, pad)
// ---------------------------------------------------------------------
    .globl _sea_substr
    .p2align 2
_sea_substr:
    stp x29, x30, [sp, #-48]!       // frame record (+ slots at sp+16)
    mov x29, sp
    ldr x9, [x0, #SEA_STR_LEN]      // n
    cmp x1, x2
    b.ge Lrt_text_sub_empty         // an empty range never fails
    cmp x1, x9
    b.hs Lrt_text_sub_lo            // unsigned: lo < 0 or lo >= n
    sub x10, x2, #1
    cmp x10, x9
    b.hs Lrt_text_sub_hi            // hi - 1 >= n
    add x0, x0, #SEA_STR_BYTES
    add x0, x0, x1                  // the bytes from lo
    sub x1, x2, x1                  // hi - lo of them
    mov x2, x3
    bl _sea_str_make
    ldp x29, x30, [sp], #48
    ret
Lrt_text_sub_empty:
    mov x1, #0                      // no byte (the address is not read)
    mov x2, x3
    bl _sea_str_make
    ldp x29, x30, [sp], #48
    ret
Lrt_text_sub_hi:
    mov x1, x10                     // report hi - 1
Lrt_text_sub_lo:
    stp x1, xzr, [sp, #16]          // slots: the index, dimension 0
    str x9, [sp, #32]               // the extent n
    mov w0, #SEA_E_INDEX_OOB
    mov x1, x3                      // the site
    add x2, sp, #16
    bl _sea_err                     // noreturn

// The words of parse_f64: length, the value's bits, the bytes (8, padded).
    .section __TEXT,__const
    .p2align 3
Lrt_text_words:
    .quad 3, 0x7FF0000000000000
    .ascii "inf\0\0\0\0\0"
    .quad 3, 0x7FF0000000000000
    .ascii "Inf\0\0\0\0\0"
    .quad 4, 0x7FF0000000000000
    .ascii "+inf\0\0\0\0"
    .quad 4, 0x7FF0000000000000
    .ascii "+Inf\0\0\0\0"
    .quad 4, 0xFFF0000000000000
    .ascii "-inf\0\0\0\0"
    .quad 4, 0xFFF0000000000000
    .ascii "-Inf\0\0\0\0"
    .quad 3, 0x7FF8000000000000
    .ascii "nan\0\0\0\0\0"
    .quad 3, 0x7FF8000000000000
    .ascii "NaN\0\0\0\0\0"
