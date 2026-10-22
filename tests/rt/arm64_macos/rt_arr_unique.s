// sea/tests/rt/arm64_macos/rt_arr_unique.s -- sea_arr_unique: a count-1 array comes back unchanged; a count-2 f64 matrix is copied (header and data equal, old count 1); a static array (count 0) is copied and keeps count 0; a str[] copy retains its dynamic elements (static and null elements as they are); a struct array copy retains its reference fields; live count back to 0 (heap check)
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

// CHECK cond, text: after a compare, print text and LF if cond holds,
// else text, " BAD" and LF (x0-x17 clobbered).
.macro CHECK cond, text
    b.\cond Lck_ok\@
    TXT "\text BAD\n"
    b Lck_end\@
Lck_ok\@:
    TXT "\text\n"
Lck_end\@:
.endm
// LIVEOUT text: print the live-object count, then text and LF.
.macro LIVEOUT text
    LIVE x0
    bl Lput_dec
    TXT "\text\n"
.endm
// UNIQ: x20 = sea_arr_unique(x19, site 0).
.macro UNIQ
    mov x0, x19
    mov x1, #0
    bl _sea_arr_unique
    mov x20, x0
.endm
// RCIS reg, off, n: compare the u64 at [reg + off] with n.
.macro RCIS reg, off, n
    ldr x9, [\reg, #\off]
    cmp x9, #\n
.endm
// SAME: compare Lsamehdr(x19, x20) with 1.
.macro SAME
    mov x0, x19
    mov x1, x20
    bl Lsamehdr
    cmp x0, #1
.endm
// STRCAT: x0 = a new string "xx".
.macro STRCAT
    LA x0, Lsx
    LA x1, Lsx
    mov x2, #0
    bl _sea_str_cat
.endm

    .section __TEXT,__text,regular,pure_instructions
// Lsamehdr -- x0 = original, x1 = copy: x0 = 1 if ek, rank, rows, cols,
//   cap, esize, slay agree, the copy's data follows its header and its data
//   bytes equal the original's. Clobbers x0-x17. Frame 16 bytes.
    .p2align 2
Lsamehdr:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    mov x9, x0
    mov x0, #0
    ldrb w10, [x9, #SEA_ARR_EK]
    ldrb w11, [x1, #SEA_ARR_EK]
    cmp w10, w11
    b.ne 9f
    ldrb w10, [x9, #SEA_ARR_RANK]
    ldrb w11, [x1, #SEA_ARR_RANK]
    cmp w10, w11
    b.ne 9f
    ldr x10, [x9, #SEA_ARR_ROWS]
    ldr x11, [x1, #SEA_ARR_ROWS]
    cmp x10, x11
    b.ne 9f
    ldr x12, [x9, #SEA_ARR_COLS]
    ldr x11, [x1, #SEA_ARR_COLS]
    cmp x12, x11
    b.ne 9f
    mul x10, x10, x12
    ldr x11, [x1, #SEA_ARR_CAP]
    cmp x10, x11
    b.ne 9f
    ldr x12, [x9, #SEA_ARR_ESIZE]
    ldr x11, [x1, #SEA_ARR_ESIZE]
    cmp x12, x11
    b.ne 9f
    ldr x13, [x9, #SEA_ARR_SLAY]
    ldr x11, [x1, #SEA_ARR_SLAY]
    cmp x13, x11
    b.ne 9f
    add x13, x1, #SEA_ARR_SIZE
    ldr x11, [x1, #SEA_ARR_DATA]
    cmp x13, x11
    b.ne 9f
    mul x2, x10, x12                // data bytes
    ldr x0, [x9, #SEA_ARR_DATA]
    ldr x1, [x1, #SEA_ARR_DATA]
    bl _memcmp
    cmp w0, #0
    cset x0, eq
9:  ldp x29, x30, [sp], #16
    ret

    .globl _sea_main
    .p2align 2
_sea_main:
    PROLOGUE
    // 1. Count 1: the same array.
    mov x0, #SEA_EK_I64
    mov x1, #1
    mov x2, #3
    mov x3, #1
    mov x4, #0
    bl _sea_arr_new
    mov x19, x0
    UNIQ
    cmp x20, x19
    CHECK eq, "count 1: same array"
    RCIS x19, SEA_ARR_RC, 1
    CHECK eq, "count 1: count unchanged"
    mov x0, x19
    bl _sea_release
    // 2. A shared f64 matrix: copied.
    mov x0, #SEA_EK_F64
    mov x1, #2
    mov x2, #2
    mov x3, #3
    mov x4, #0
    bl _sea_arr_new
    mov x19, x0
    ldr x9, [x19, #SEA_ARR_DATA]
    LA x10, Lsix                    // 1.5, 2.5, ... in the six elements
    ldp x11, x12, [x10]
    stp x11, x12, [x9]
    ldp x11, x12, [x10, #16]
    stp x11, x12, [x9, #16]
    ldp x11, x12, [x10, #32]
    stp x11, x12, [x9, #32]
    mov x9, #2
    str x9, [x19, #SEA_ARR_RC]      // count 2
    UNIQ
    cmp x20, x19
    CHECK ne, "count 2: a new array"
    RCIS x20, SEA_ARR_RC, 1
    CHECK eq, "count 2: copy count 1"
    RCIS x19, SEA_ARR_RC, 1
    CHECK eq, "count 2: old count 1"
    SAME
    CHECK eq, "count 2: same header and data"
    mov x0, x19
    bl _sea_release
    mov x0, x20
    bl _sea_release
    // 3. A static array: copied, its count stays 0.
    LA x19, Lstat
    UNIQ
    cmp x20, x19
    CHECK ne, "static: a new array"
    RCIS x20, SEA_ARR_RC, 1
    CHECK eq, "static: copy count 1"
    RCIS x19, SEA_ARR_RC, SEA_RC_STATIC
    CHECK eq, "static: count stays 0"
    SAME
    CHECK eq, "static: same header and data"
    mov x0, x20
    bl _sea_release
    // 4. A shared str[]: [fresh, static, null, fresh].
    mov x0, #SEA_EK_STR
    mov x1, #1
    mov x2, #4
    mov x3, #1
    mov x4, #0
    bl _sea_arr_new
    mov x19, x0
    STRCAT
    ldr x9, [x19, #SEA_ARR_DATA]
    str x0, [x9, #0]
    LA x10, Lsx
    str x10, [x9, #8]
    STRCAT
    ldr x9, [x19, #SEA_ARR_DATA]
    str x0, [x9, #24]
    mov x9, #2
    str x9, [x19, #SEA_ARR_RC]      // count 2
    UNIQ
    SAME
    CHECK eq, "str[]: same header and elements"
    ldr x9, [x20, #SEA_ARR_DATA]
    ldr x9, [x9, #0]
    RCIS x9, SEA_STR_RC, 2
    CHECK eq, "str[]: element 0 count 2"
    ldr x9, [x20, #SEA_ARR_DATA]
    ldr x9, [x9, #24]
    RCIS x9, SEA_STR_RC, 2
    CHECK eq, "str[]: element 3 count 2"
    LA x10, Lsx
    RCIS x10, SEA_STR_RC, SEA_RC_STATIC
    CHECK eq, "str[]: static element count 0"
    RCIS x19, SEA_ARR_RC, 1
    CHECK eq, "str[]: old count 1"
    mov x0, x19
    bl _sea_release
    mov x0, x20
    bl _sea_release
    // 5. A shared struct array {f64 x; str s} (16 bytes, one reference
    // field at 8): [{2.5, fresh}, {0, null}].
    LA x0, Lslay
    mov x1, #1
    mov x2, #2
    mov x3, #1
    mov x4, #0
    bl _sea_arr_new_s
    mov x19, x0
    STRCAT
    ldr x9, [x19, #SEA_ARR_DATA]
    str x0, [x9, #8]
    LA x10, Lsix
    ldr x11, [x10, #8]              // 2.5
    str x11, [x9, #0]
    mov x9, #2
    str x9, [x19, #SEA_ARR_RC]      // count 2
    UNIQ
    SAME
    CHECK eq, "struct: same header and elements"
    ldr x9, [x20, #SEA_ARR_DATA]
    ldr x9, [x9, #8]
    RCIS x9, SEA_STR_RC, 2
    CHECK eq, "struct: reference field count 2"
    RCIS x19, SEA_ARR_RC, 1
    CHECK eq, "struct: old count 1"
    mov x0, x19
    bl _sea_release
    mov x0, x20
    bl _sea_release
    EPILOGUE

    .section __DATA,__const
    SSTR Lsx, 1, "x"
    .p2align 3
Lsix:
    .quad 0x3FF8000000000000, 0x4004000000000000, 0x400C000000000000
    .quad 0x4012000000000000, 0x4016000000000000, 0x401A000000000000
Lslay:
    .quad 16, 1, 8
    .p2align 6
Lstat:                              // a static f64 vector of 3: count 0, data after the header
    .quad SEA_RC_STATIC
    .byte SEA_TAG_ARRAY, SEA_EK_F64, 1, 0, 0, 0, 0, 0
    .quad 3, 1, 3, Lstat + SEA_ARR_SIZE, SEA_ESIZE_F64, 0
    .quad 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000
    .p2align 3
    .globl _sea_sites
_sea_sites:
    .quad 0
