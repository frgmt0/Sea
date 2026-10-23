// sea/tests/rt/arm64_macos/rt_sort_f64.s -- sea_sort and sea_argsort of f64 vectors (DESIGN.md 4.8, LANGUAGE.md 10.6): n = 0, 1, 2; a 14-element vector (insertion sort) and the same values three times (42 elements, radix sort), ascending and descending: -0 and +0 equal and kept in input order with their signs, NaNs (both signs, several payloads) after every number ascending and before every number descending in input order, ties stable in both directions, +-inf, subnormals; the result headers, s[k] = v[p[k]] bit for bit; live count back to 0 (heap check)
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

// The 14 values of the mixed vector (f64 bits): 2.0, NaN, -0, -inf, +0, a
// negative NaN with a payload, 1.0, +inf, -0, a positive NaN with a
// payload, 2.0, -1.0, the least positive subnormal, its negative.
.macro FMIX
    .quad 0x4000000000000000, 0x7FF8000000000000, 0x8000000000000000, 0xFFF0000000000000
    .quad 0x0000000000000000, 0xFFF4000000000001, 0x3FF0000000000000, 0x7FF0000000000000
    .quad 0x8000000000000000, 0x7FF0000000000001, 0x4000000000000000, 0xBFF0000000000000
    .quad 0x0000000000000001, 0x8000000000000001
.endm

    .globl _sea_main
    .p2align 2
_sea_main:
    PROLOGUE
    LA x0, Ltable
    bl Lrun_table
    EPILOGUE

    .section __TEXT,__cstring,cstring_literals
Ll_n0:   .asciz "f64 n0"
Ll_n1:   .asciz "f64 n1"
Ll_n2a:  .asciz "f64 n2 asc"
Ll_n2d:  .asciz "f64 n2 desc"
Ll_mxa:  .asciz "f64 mix asc"
Ll_mxd:  .asciz "f64 mix desc"
Ll_rpa:  .asciz "f64 rep asc"
Ll_rpd:  .asciz "f64 rep desc"

    .section __DATA,__const
    .p2align 3
Ltable:
    .quad Ll_n0, Lv_n0, 0
    .quad Ll_n1, Lv_n1, 0
    .quad Ll_n2a, Lv_n2, 0
    .quad Ll_n2d, Lv_n2, 1
    .quad Ll_mxa, Lv_mix, 0
    .quad Ll_mxd, Lv_mix, 1
    .quad Ll_rpa, Lv_rep, 0
    .quad Ll_rpd, Lv_rep, 1
    .quad 0
    SARR Lv_n0, SEA_EK_F64, 0
    SARR Lv_n1, SEA_EK_F64, 1
    .quad 0x8000000000000000        // -0
    SARR Lv_n2, SEA_EK_F64, 2
    .quad 0x7FF8000000000000, 0xFFF0000000000000 // NaN, -inf
    SARR Lv_mix, SEA_EK_F64, 14     // insertion sort
    FMIX
    SARR Lv_rep, SEA_EK_F64, 42     // radix sort: the 14 values three times
    FMIX
    FMIX
    FMIX
    .p2align 3
    .globl _sea_sites
_sea_sites:
    .quad 0
