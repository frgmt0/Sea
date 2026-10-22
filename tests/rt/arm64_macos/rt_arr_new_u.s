// sea/tests/rt/arm64_macos/rt_arr_new_u.s -- sea_arr_new_u of each numeric element kind and both ranks with zero, one and many elements: every header field as sea_arr_new (the buffer contents are not tested), and the live count back to 0 (heap check)
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

// ---- test helpers (the same block in every 4c runtime test) ----------
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
// Print a literal text, then a register in signed decimal (x0-x17 clobbered;
// reg must not be x0-x17 unless it is x1).
.macro KV text, reg
    mov x1, \reg
    .pushsection __TEXT,__cstring,cstring_literals
Lkv\@: .asciz "\text"
    .popsection
    LA x0, Lkv\@
    bl Lput_kv
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

// Lput_kv -- print a text, then x1 in signed decimal. x0 = text. Clobbers
// x0-x17. Callee-saved used: x19 (the value). Frame 32 bytes.
    .p2align 2
Lput_kv:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x1
    bl Lput_cstr
    mov x0, x19
    bl Lput_dec
    ldr x19, [sp, #16]
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
    LA x0, Lput_s_lb
    mov x1, #1
    bl _sea_out_write
    add x0, x19, #SEA_STR_BYTES
    ldr x1, [x19, #SEA_STR_LEN]
    bl _sea_out_write
    LA x0, Lput_s_rb
    mov x1, #1
    bl _sea_out_write
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

    .section __TEXT,__const
Lput_s_lb: .ascii "["
Lput_s_rb: .ascii "]"
    .section __TEXT,__text,regular,pure_instructions
// ---- end of the test helpers ------------------------------------------

// A case: ek, rank, rows, cols, the expected esize, the label and its length.
.equ E_EK,      0
.equ E_RANK,    8
.equ E_ROWS,    16
.equ E_COLS,    24
.equ E_ESIZE,   32
.equ E_LBL,     40
.equ E_LLEN,    48
.equ E_SIZE,    56
.macro CASE ek, rank, rows, cols, esize, text
    .quad \ek, \rank, \rows, \cols, \esize, Lcl\@, Lcle\@ - Lcl\@
    .pushsection __TEXT,__const
Lcl\@: .ascii "\text"
Lcle\@:
    .popsection
.endm

    .section __TEXT,__text,regular,pure_instructions
// Lcheckarr -- x0 = the array, x1 = its case, w2 = 1 to check that the
//   buffer is all zero bytes. x0 = 1 if every header field is right.
//   Leaf; clobbers x0, x9-x13.
    .p2align 2
Lcheckarr:
    mov x9, x0
    mov x0, #0
    ldr x10, [x9, #SEA_ARR_RC]
    cmp x10, #1
    b.ne 9f
    ldrb w10, [x9, #SEA_ARR_TAG]
    cmp w10, #SEA_TAG_ARRAY
    b.ne 9f
    ldrb w10, [x9, #SEA_ARR_EK]
    ldr x11, [x1, #E_EK]
    cmp x10, x11
    b.ne 9f
    ldrb w10, [x9, #SEA_ARR_RANK]
    ldr x11, [x1, #E_RANK]
    cmp x10, x11
    b.ne 9f
    ldur w10, [x9, #(SEA_ARR_RANK + 1)]     // bytes 11 .. 14
    cbnz w10, 9f
    ldrb w10, [x9, #(SEA_ARR_RANK + 5)]     // byte 15
    cbnz w10, 9f
    ldr x10, [x9, #SEA_ARR_ROWS]
    ldr x11, [x1, #E_ROWS]
    cmp x10, x11
    b.ne 9f
    ldr x12, [x9, #SEA_ARR_COLS]
    ldr x11, [x1, #E_COLS]
    cmp x12, x11
    b.ne 9f
    mul x10, x10, x12               // rows * cols
    ldr x11, [x9, #SEA_ARR_CAP]
    cmp x10, x11
    b.ne 9f
    add x12, x9, #SEA_ARR_SIZE
    ldr x11, [x9, #SEA_ARR_DATA]
    cmp x12, x11                    // data right after the header
    b.ne 9f
    tst x12, #(SEA_DATA_ALIGN - 1)
    b.ne 9f
    ldr x13, [x9, #SEA_ARR_ESIZE]
    ldr x11, [x1, #E_ESIZE]
    cmp x13, x11
    b.ne 9f
    ldr x11, [x9, #SEA_ARR_SLAY]
    cbnz x11, 9f
    cbz w2, 8f
    mul x10, x10, x13               // bytes of the buffer
1:  cbz x10, 8f
    ldrb w11, [x12], #1
    cbnz w11, 9f
    sub x10, x10, #1
    b 1b
8:  mov x0, #1
9:  ret

    .globl _sea_main
    .p2align 2
_sea_main:
    PROLOGUE
    mov x23, #2                     // two passes: the second gets recycled, dirtied blocks
Lpass:
    LA x19, Ltab
    LA x20, Ltab_end
Lcase:
    ldr x0, [x19, #E_EK]
    ldr x1, [x19, #E_RANK]
    ldr x2, [x19, #E_ROWS]
    ldr x3, [x19, #E_COLS]
    mov x4, #0                      // site 0
    bl _sea_arr_new_u
    mov x21, x0
    mov x1, x19
    mov w2, #0
    bl Lcheckarr
    mov x22, x0
    ldr x0, [x19, #E_LBL]
    ldr x1, [x19, #E_LLEN]
    bl _sea_out_write
    cbz x22, 1f
    TXT " ok\n"
    b 2f
1:  TXT " BAD\n"
2:  // Free it, then dirty its buffer bytes (the block is on a free list:
    // only its first word is the list link), so that the next allocation
    // of the class gets a block that is not clean.
    ldr x22, [x21, #SEA_ARR_CAP]
    ldr x9, [x21, #SEA_ARR_ESIZE]
    mul x22, x22, x9
    mov x0, x21
    bl _sea_release
    add x0, x21, #SEA_ARR_SIZE
    mov w1, #0xFF
    mov x2, x22
    bl _memset
    add x19, x19, #E_SIZE
    cmp x19, x20
    b.lo Lcase
    subs x23, x23, #1
    b.ne Lpass
    EPILOGUE

    .section __DATA,__const
    .p2align 3
Ltab:
    CASE SEA_EK_F64, 1, 0, 1, SEA_ESIZE_F64, "f64 vector 0"
    CASE SEA_EK_F64, 1, 1, 1, SEA_ESIZE_F64, "f64 vector 1"
    CASE SEA_EK_F64, 1, 100, 1, SEA_ESIZE_F64, "f64 vector 100"
    CASE SEA_EK_F64, 2, 3, 0, SEA_ESIZE_F64, "f64 matrix 3x0"
    CASE SEA_EK_F64, 2, 1, 1, SEA_ESIZE_F64, "f64 matrix 1x1"
    CASE SEA_EK_F64, 2, 7, 5, SEA_ESIZE_F64, "f64 matrix 7x5"
    CASE SEA_EK_I64, 1, 0, 1, SEA_ESIZE_I64, "i64 vector 0"
    CASE SEA_EK_I64, 1, 1, 1, SEA_ESIZE_I64, "i64 vector 1"
    CASE SEA_EK_I64, 1, 100, 1, SEA_ESIZE_I64, "i64 vector 100"
    CASE SEA_EK_I64, 2, 0, 3, SEA_ESIZE_I64, "i64 matrix 0x3"
    CASE SEA_EK_I64, 2, 1, 1, SEA_ESIZE_I64, "i64 matrix 1x1"
    CASE SEA_EK_I64, 2, 7, 5, SEA_ESIZE_I64, "i64 matrix 7x5"
    CASE SEA_EK_BOOL, 1, 0, 1, SEA_ESIZE_BOOL, "bool vector 0"
    CASE SEA_EK_BOOL, 1, 1, 1, SEA_ESIZE_BOOL, "bool vector 1"
    CASE SEA_EK_BOOL, 1, 100, 1, SEA_ESIZE_BOOL, "bool vector 100"
    CASE SEA_EK_BOOL, 2, 3, 0, SEA_ESIZE_BOOL, "bool matrix 3x0"
    CASE SEA_EK_BOOL, 2, 1, 1, SEA_ESIZE_BOOL, "bool matrix 1x1"
    CASE SEA_EK_BOOL, 2, 7, 5, SEA_ESIZE_BOOL, "bool matrix 7x5"
Ltab_end:
    .p2align 3
    .globl _sea_sites
_sea_sites:
    .quad 0
