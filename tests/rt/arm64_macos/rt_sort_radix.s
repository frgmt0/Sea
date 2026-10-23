// sea/tests/rt/arm64_macos/rt_sort_radix.s -- the radix path of sea_sort and sea_argsort (DESIGN.md 4.8): keys differing in one byte only (one pass, seven skipped), 40 equal keys (every pass skipped), keys differing in every byte (all eight passes), ascending and descending with their expected bytes; then 5000-element i64 (six passes skipped) and f64 vectors from a 64-bit LCG, checked in the test: headers, a permutation, s[k] = v[p[k]], the order of LANGUAGE.md 10.6 and stability; live count back to 0 (heap check)
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

// ---- test helpers (the same block in every rt_sort test) --------------
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
// A static vector (count SEA_RC_STATIC) of n 8-byte elements of kind ek; the
// elements follow the macro, right after the header.
.macro SARR label, ek, n
    .p2align 6
\label:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_ARRAY, \ek, 1, 0, 0, 0, 0, 0
    .quad \n, 1, \n, \label + SEA_ARR_SIZE, 8, 0
.endm
// The address of a label.
.macro LA reg, label
    adrp \reg, \label@PAGE
    add \reg, \reg, \label@PAGEOFF
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
// After a compare: text and LF if cond holds, else text, " BAD" and LF.
.macro CHECK cond, text
    b.\cond Lck_ok\@
    TXT "\text BAD\n"
    b Lck_end\@
Lck_ok\@:
    TXT "\text\n"
Lck_end\@:
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

// Lput_hex -- print x0 as 16 upper-case hexadecimal digits (the bits of an
// f64). Clobbers x0-x17. Frame 32 bytes (frame record, 16 bytes of digits).
    .p2align 2
Lput_hex:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    add x9, sp, #16             // the digits at [sp + 16, sp + 32)
    mov x10, #16
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
    mov x1, #16
    bl _sea_out_write
    ldp x29, x30, [sp], #32
    ret

// Lput_str -- print a string object's bytes between [ and ]. x0 = the
// object. Clobbers x0-x17. Callee-saved used: x19. Frame 32 bytes.
    .p2align 2
Lput_str:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    TXT "["
    add x0, x19, #SEA_STR_BYTES
    ldr x1, [x19, #SEA_STR_LEN]
    bl _sea_out_write
    TXT "]"
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

// Lput_vec -- print each element of a vector after a space: f64 as hex
// bits, i64 in decimal, str as [bytes]. x0 = the vector. Clobbers x0-x17.
// Callee-saved used: x19 = vector, x20 = k, x21 = n, x22 = ek. Frame 48.
    .p2align 2
Lput_vec:
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    mov x19, x0
    ldr x21, [x19, #SEA_ARR_ROWS]
    ldrb w22, [x19, #SEA_ARR_EK]
    mov x20, #0
1:  cmp x20, x21
    b.hs 9f
    TXT " "
    ldr x9, [x19, #SEA_ARR_DATA]
    ldr x0, [x9, x20, lsl #3]   // element k
    cmp w22, #SEA_EK_F64
    b.ne 2f
    bl Lput_hex
    b 4f
2:  cmp w22, #SEA_EK_STR
    b.ne 3f
    bl Lput_str
    b 4f
3:  bl Lput_dec
4:  add x20, x20, #1
    b 1b
9:  ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #48
    ret

// Lhdr -- x0 = a result vector, x1 = expected ek, x2 = expected n: x0 = 1
// if count 1, SEA_TAG_ARRAY, ek, rank 1, rows n, cols 1, cap n, data right
// after the header, esize 8 and slay 0; else 0. Clobbers x9-x11. Leaf.
    .p2align 2
Lhdr:
    mov x9, x0
    mov x0, #0
    ldr x10, [x9, #SEA_ARR_RC]
    cmp x10, #1
    b.ne 9f
    ldrb w10, [x9, #SEA_ARR_TAG]
    cmp w10, #SEA_TAG_ARRAY
    b.ne 9f
    ldrb w10, [x9, #SEA_ARR_EK]
    cmp x10, x1
    b.ne 9f
    ldrb w10, [x9, #SEA_ARR_RANK]
    cmp w10, #1
    b.ne 9f
    ldr x10, [x9, #SEA_ARR_ROWS]
    cmp x10, x2
    b.ne 9f
    ldr x10, [x9, #SEA_ARR_COLS]
    cmp x10, #1
    b.ne 9f
    ldr x10, [x9, #SEA_ARR_CAP]
    cmp x10, x2
    b.ne 9f
    add x11, x9, #SEA_ARR_SIZE
    ldr x10, [x9, #SEA_ARR_DATA]
    cmp x10, x11
    b.ne 9f
    ldr x10, [x9, #SEA_ARR_ESIZE]
    cmp x10, #8
    b.ne 9f
    ldr x10, [x9, #SEA_ARR_SLAY]
    cbnz x10, 9f
    mov x0, #1
9:  ret

// Lcase -- x0 = label, x1 = v, x2 = desc: s = sea_sort(v, desc), p =
// sea_argsort(v, desc); prints "<label> sort: <s>", "<label> argsort: <p>"
// and "<label>: results ok" when both headers are right (Lhdr), every
// p[k] < n and s[k] has the bits of v[p[k]]; releases s and p.
// Clobbers x0-x17. Callee-saved used: x19 = label, x20 = v, x21 = desc,
// x22 = s, x23 = p, x24 = ok, x25 = n, x26 = k. Frame 80 bytes.
    .p2align 2
Lcase:
    stp x29, x30, [sp, #-80]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    ldr x25, [x20, #SEA_ARR_ROWS]
    mov x0, x20
    mov x1, x21
    mov x2, #0
    bl _sea_sort
    mov x22, x0
    mov x0, x20
    mov x1, x21
    mov x2, #0
    bl _sea_argsort
    mov x23, x0
    mov x0, x19
    bl Lput_cstr
    TXT " sort:"
    mov x0, x22
    bl Lput_vec
    TXT "\n"
    mov x0, x19
    bl Lput_cstr
    TXT " argsort:"
    mov x0, x23
    bl Lput_vec
    TXT "\n"
    mov x0, x22                 // the headers
    ldrb w1, [x20, #SEA_ARR_EK]
    mov x2, x25
    bl Lhdr
    mov x24, x0
    mov x0, x23
    mov x1, #SEA_EK_I64
    mov x2, x25
    bl Lhdr
    and x24, x24, x0
    mov x26, #0                 // s[k] = v[p[k]] for every k
1:  cmp x26, x25
    b.hs 2f
    ldr x9, [x23, #SEA_ARR_DATA]
    ldr x10, [x9, x26, lsl #3]  // p[k]
    cmp x10, x25
    b.hs 3f
    ldr x11, [x20, #SEA_ARR_DATA]
    ldr x11, [x11, x10, lsl #3] // v[p[k]]
    ldr x12, [x22, #SEA_ARR_DATA]
    ldr x12, [x12, x26, lsl #3] // s[k]
    cmp x11, x12
    b.ne 3f
    add x26, x26, #1
    b 1b
3:  mov x24, #0
2:  mov x0, x19
    bl Lput_cstr
    cmp x24, #1
    CHECK eq, ": results ok"
    mov x0, x22
    bl _sea_release
    mov x0, x23
    bl _sea_release
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #80
    ret

// Lrun_table -- x0 = a table of {label, v, desc} triples of quads, ended
// by a zero label: Lcase for each. Clobbers x0-x17. Callee-saved used:
// x19 (the table cursor). Frame 32 bytes.
    .p2align 2
Lrun_table:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
1:  ldr x0, [x19]
    cbz x0, 2f
    ldr x1, [x19, #8]
    ldr x2, [x19, #16]
    bl Lcase
    add x19, x19, #24
    b 1b
2:  ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
// ---- end of the test helpers ---------------------------------------------

.equ RT_LCG_N, 5000                 // the self-checked vectors' length

// Lverify -- x0 = label, x1 = v (f64 without NaN, or i64), x2 = desc:
// s = sea_sort(v, desc), p = sea_argsort(v, desc); prints "<label>: ok"
// when both headers are right (Lhdr), p is a permutation of 0 .. n-1,
// s[k] has the bits of v[p[k]], and for every k >= 1 v[p[k-1]] is before
// v[p[k]] (ascending: less, descending: greater) or equal to it with
// p[k-1] < p[k] (stability); else "<label>: ok BAD". Releases s, p and
// the marks. Clobbers x0-x17, d0-d1. Callee-saved used: x19 = label,
// x20 = v, x21 = desc, x22 = s, x23 = p, x24 = the marks (a bool vector),
// x25 = n, x26 = k, x27 = ok, x28 = v's elements. Frame 96 bytes.
    .p2align 2
Lverify:
    stp x29, x30, [sp, #-96]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    stp x25, x26, [sp, #64]
    stp x27, x28, [sp, #80]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    ldr x25, [x20, #SEA_ARR_ROWS]
    ldr x28, [x20, #SEA_ARR_DATA]
    mov x0, x20
    mov x1, x21
    mov x2, #0
    bl _sea_sort
    mov x22, x0
    mov x0, x20
    mov x1, x21
    mov x2, #0
    bl _sea_argsort
    mov x23, x0
    mov x0, #SEA_EK_BOOL        // the marks, all false
    mov x1, #1
    mov x2, x25
    mov x3, #1
    mov x4, #0
    bl _sea_arr_new
    mov x24, x0
    mov x0, x22
    ldrb w1, [x20, #SEA_ARR_EK]
    mov x2, x25
    bl Lhdr
    mov x27, x0
    mov x0, x23
    mov x1, #SEA_EK_I64
    mov x2, x25
    bl Lhdr
    and x27, x27, x0
    mov x26, #0
1:  cmp x26, x25
    b.hs 8f
    ldr x9, [x23, #SEA_ARR_DATA]
    ldr x10, [x9, x26, lsl #3]  // j = p[k]
    cmp x10, x25
    b.hs 7f                     // out of range
    ldr x11, [x24, #SEA_ARR_DATA]
    ldrb w12, [x11, x10]
    cbnz w12, 7f                // j seen before: not a permutation
    mov w12, #1
    strb w12, [x11, x10]
    ldr x12, [x22, #SEA_ARR_DATA]
    ldr x12, [x12, x26, lsl #3] // s[k]
    ldr x13, [x28, x10, lsl #3] // b = v[j]
    cmp x12, x13
    b.ne 7f
    cbz x26, 6f
    sub x14, x26, #1
    ldr x14, [x9, x14, lsl #3]  // p[k-1]
    ldr x15, [x28, x14, lsl #3] // a = v[p[k-1]]
    ldrb w16, [x20, #SEA_ARR_EK]
    cmp w16, #SEA_EK_F64
    b.eq 2f
    cmp x15, x13                // i64: signed
    b 3f
2:  fmov d0, x15
    fmov d1, x13
    fcmp d0, d1                 // f64: no NaN here
3:  b.eq 5f
    cbnz x21, 4f
    b.lt 6f                     // ascending: a < b
    b 7f
4:  b.gt 6f                     // descending: a > b
    b 7f
5:  cmp x14, x10                // equal: input order kept
    b.hs 7f
6:  add x26, x26, #1
    b 1b
7:  mov x27, #0
8:  mov x0, x19
    bl Lput_cstr
    cmp x27, #1
    CHECK eq, ": ok"
    mov x0, x22
    bl _sea_release
    mov x0, x23
    bl _sea_release
    mov x0, x24
    bl _sea_release
    ldp x27, x28, [sp, #80]
    ldp x25, x26, [sp, #64]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #96
    ret

// Llcg -- x0 = ek (SEA_EK_I64 or SEA_EK_F64): a new vector of RT_LCG_N
// elements from the 64-bit LCG x <- x * 6364136223846793005 +
// 1442695040888963407 (x0 = 1, one step per element): i64 x >> 52
// (logical: 0 .. 4095, many ties; bytes 2..7 of every key equal, so six
// radix passes are skipped), f64 (x >> 54, arithmetic) * 0.25 (-128 ..
// 127.75, exact). Clobbers x0-x17, d0-d1. Callee-saved used: x19 = ek,
// x20 = the vector. Frame 32 bytes.
    .p2align 2
Llcg:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    mov x1, #1
    mov x2, #RT_LCG_N
    mov x3, #1
    mov x4, #0
    bl _sea_arr_new_u
    mov x20, x0
    ldr x9, [x20, #SEA_ARR_DATA]
    movz x10, #0x7f2d                // 6364136223846793005 = 0x5851F42D4C957F2D
    movk x10, #0x4c95, lsl #16
    movk x10, #0xf42d, lsl #32
    movk x10, #0x5851, lsl #48
    movz x11, #0x814f                // 1442695040888963407 = 0x14057B7EF767814F
    movk x11, #0xf767, lsl #16
    movk x11, #0x7b7e, lsl #32
    movk x11, #0x1405, lsl #48
    mov x13, #1                      // x
    mov x14, #0                      // k
    mov x16, #RT_LCG_N
    fmov d1, #0.25
1:  madd x13, x13, x10, x11          // x = x * a + c (mod 2^64)
    cmp x19, #SEA_EK_I64
    b.ne 2f
    lsr x15, x13, #52
    b 3f
2:  asr x15, x13, #54
    scvtf d0, x15
    fmul d0, d0, d1
    fmov x15, d0
3:  str x15, [x9, x14, lsl #3]
    add x14, x14, #1
    cmp x14, x16
    b.lo 1b
    mov x0, x20
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

    .globl _sea_main
    .p2align 2
_sea_main:
    PROLOGUE
    LA x0, Ltable
    bl Lrun_table
    mov x0, #SEA_EK_I64
    bl Llcg
    mov x19, x0
    LA x0, Ll_li_a
    mov x1, x19
    mov x2, #0
    bl Lverify
    LA x0, Ll_li_d
    mov x1, x19
    mov x2, #1
    bl Lverify
    mov x0, x19
    bl _sea_release
    mov x0, #SEA_EK_F64
    bl Llcg
    mov x19, x0
    LA x0, Ll_lf_a
    mov x1, x19
    mov x2, #0
    bl Lverify
    LA x0, Ll_lf_d
    mov x1, x19
    mov x2, #1
    bl Lverify
    mov x0, x19
    bl _sea_release
    EPILOGUE

    .section __TEXT,__cstring,cstring_literals
Ll_ska:  .asciz "skip asc"
Ll_skd:  .asciz "skip desc"
Ll_eqa:  .asciz "equal asc"
Ll_eqd:  .asciz "equal desc"
Ll_ala:  .asciz "alt asc"
Ll_ald:  .asciz "alt desc"
Ll_li_a: .asciz "lcg i64 n5000 asc"
Ll_li_d: .asciz "lcg i64 n5000 desc"
Ll_lf_a: .asciz "lcg f64 n5000 asc"
Ll_lf_d: .asciz "lcg f64 n5000 desc"

    .section __DATA,__const
    .p2align 3
Ltable:
    .quad Ll_ska, Lv_skip, 0
    .quad Ll_skd, Lv_skip, 1
    .quad Ll_eqa, Lv_eq, 0
    .quad Ll_eqd, Lv_eq, 1
    .quad Ll_ala, Lv_alt, 0
    .quad Ll_ald, Lv_alt, 1
    .quad 0
    // (39 - i) * 256: the keys differ in byte 1 only (one pass, the others skipped)
    SARR Lv_skip, SEA_EK_I64, 40
    .set Lseq_i, 0
    .rept 40
    .quad (39 - Lseq_i) * 256
    .set Lseq_i, Lseq_i + 1
    .endr
    // 40 times 3.5: every pass skipped
    SARR Lv_eq, SEA_EK_F64, 40
    .rept 40
    .quad 0x400C000000000000
    .endr
    // 0, -1, 0, -1, ...: the keys differ in every byte (all 8 passes)
    SARR Lv_alt, SEA_EK_I64, 40
    .rept 20
    .quad 0, -1
    .endr
    .p2align 3
    .globl _sea_sites
_sea_sites:
    .quad 0
