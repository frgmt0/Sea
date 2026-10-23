// sea/tests/rt/arm64_macos/rt_sort_scratch.s -- the scratch block of sea_sort and sea_argsort (DESIGN.md 4.8 "Scratch"): for the insertion (f64, n = 4: 12n bytes), radix (i64, n = 40: 24n + 16384 bytes) and str (n = 4: 8n bytes) paths, the entry adds exactly one live object (the result) and gives its scratch block back before it returns (the block it took, the head of the request's class after a prior allocate and free, is handed out again afterwards); live count back to 0 (heap check)
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

// Lscratch -- x0 = label, x1 = v, x2 = the scratch request DESIGN.md 4.8
// states for v (in bytes), x3 = 0 for sea_sort, 1 for sea_argsort.
// A block X of that request is allocated and freed first, so it heads
// its class (DESIGN.md 4.1: the most recently freed block is handed out
// first; the result's class differs from the scratch's for the vectors
// used here). Then the entry runs: the live count must grow by exactly
// one (the result, "<label>: one new object"), and after the result's
// release the next allocation of that request must be X again ("<label>:
// scratch block given back"): the entry took X as its scratch and freed it.
// Clobbers x0-x17. Callee-saved used: x19 = label, x20 = v, x21 = bytes,
// x22 = mode, x23 = X, x24 = the result, x25 = the live count before.
// Frame 64 bytes.
    .p2align 2
Lscratch:
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]
    stp x23, x24, [sp, #48]
    str x25, [sp, #56]
    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov x22, x3
    mov x0, x21
    mov x1, #0
    bl _sea_alloc
    mov x23, x0                 // X
    mov x0, x23
    mov x1, x21
    bl _sea_free_block          // X heads its class
    LIVE x25
    mov x0, x20
    mov x1, #0
    mov x2, #0
    cbnz x22, 1f
    bl _sea_sort
    b 2f
1:  bl _sea_argsort
2:  mov x24, x0
    mov x0, x19
    bl Lput_cstr
    LIVE x9
    add x10, x25, #1
    cmp x9, x10
    CHECK eq, ": one new object"
    mov x0, x24
    bl _sea_release
    mov x0, x21
    mov x1, #0
    bl _sea_alloc
    mov x24, x0                 // Y: X again?
    mov x0, x19
    bl Lput_cstr
    cmp x24, x23
    CHECK eq, ": scratch block given back"
    mov x0, x24
    mov x1, x21
    bl _sea_free_block
    ldr x25, [sp, #56]
    ldp x23, x24, [sp, #48]
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret

    .globl _sea_main
    .p2align 2
_sea_main:
    PROLOGUE
    LA x19, Ltable
1:  ldr x0, [x19]
    cbz x0, 2f
    ldr x1, [x19, #8]
    ldr x2, [x19, #16]
    ldr x3, [x19, #24]
    bl Lscratch
    add x19, x19, #32
    b 1b
2:  EPILOGUE

    .section __TEXT,__cstring,cstring_literals
Ll_fs:   .asciz "f64 n4 sort"
Ll_fa:   .asciz "f64 n4 argsort"
Ll_is:   .asciz "i64 n40 sort"
Ll_ia:   .asciz "i64 n40 argsort"
Ll_ss:   .asciz "str n4 sort"
Ll_sa:   .asciz "str n4 argsort"

    .section __DATA,__const
    .p2align 3
Ltable:                             // label, v, scratch bytes, mode
    .quad Ll_fs, Lv_f4, 12 * 4, 0   // insertion: 12n rounded up to 8
    .quad Ll_fa, Lv_f4, 12 * 4, 1
    .quad Ll_is, Lv_i40, 24 * 40 + 16384, 0 // radix: 24n + 16384
    .quad Ll_ia, Lv_i40, 24 * 40 + 16384, 1
    .quad Ll_ss, Lv_s4, 8 * 4, 0    // str: 8n
    .quad Ll_sa, Lv_s4, 8 * 4, 1
    .quad 0
    SSTR Ls_x, 1, "x"
    SSTR Ls_y, 1, "y"
    SARR Lv_f4, SEA_EK_F64, 4       // 3.0, 1.0, 2.0, 0.5
    .quad 0x4008000000000000, 0x3FF0000000000000, 0x4000000000000000, 0x3FE0000000000000
    SARR Lv_i40, SEA_EK_I64, 40     // 39, 38, ..., 0
    .set Lseq_i, 0
    .rept 40
    .quad 39 - Lseq_i
    .set Lseq_i, Lseq_i + 1
    .endr
    SARR Lv_s4, SEA_EK_STR, 4       // y, x, y, x
    .quad Ls_y, Ls_x, Ls_y, Ls_x
    .p2align 3
    .globl _sea_sites
_sea_sites:
    .quad 0
