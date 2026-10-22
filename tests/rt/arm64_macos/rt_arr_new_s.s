// sea/tests/rt/arm64_macos/rt_arr_new_s.s -- sea_arr_new_s with a descriptor of two reference fields ({str a; f64 x; str b}, 24 bytes, offsets 0 and 16): the header (SEA_EK_STRUCT, esize SEA_SL_SIZE, SEA_ARR_SLAY), a zeroed buffer, and sea_free releasing the non-null reference fields (one string freed, one shared string left with count 1, null fields skipped); live count back to 0 (heap check)
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

    .section __TEXT,__text,regular,pure_instructions
    .globl _sea_main
    .p2align 2
_sea_main:
    PROLOGUE
    LA x0, Lslay
    mov x1, #2
    mov x2, #3
    mov x3, #2
    mov x4, #0
    bl _sea_arr_new_s
    mov x19, x0                     // a 3 x 2 struct matrix
    ldr x9, [x19, #SEA_ARR_RC]
    cmp x9, #1
    CHECK eq, "count 1"
    ldrb w9, [x19, #SEA_ARR_TAG]
    cmp w9, #SEA_TAG_ARRAY
    CHECK eq, "tag array"
    ldrb w9, [x19, #SEA_ARR_EK]
    cmp w9, #SEA_EK_STRUCT
    CHECK eq, "ek struct"
    ldrb w9, [x19, #SEA_ARR_RANK]
    cmp w9, #2
    CHECK eq, "rank 2"
    ldr x9, [x19, #SEA_ARR_ROWS]
    cmp x9, #3
    CHECK eq, "rows 3"
    ldr x9, [x19, #SEA_ARR_COLS]
    cmp x9, #2
    CHECK eq, "cols 2"
    ldr x9, [x19, #SEA_ARR_CAP]
    cmp x9, #6
    CHECK eq, "cap 6"
    add x9, x19, #SEA_ARR_SIZE
    ldr x10, [x19, #SEA_ARR_DATA]
    cmp x9, x10
    CHECK eq, "data after the header"
    ldr x9, [x19, #SEA_ARR_ESIZE]
    cmp x9, #24
    CHECK eq, "esize 24"
    LA x9, Lslay
    ldr x10, [x19, #SEA_ARR_SLAY]
    cmp x9, x10
    CHECK eq, "slay the descriptor"
    ldr x9, [x19, #SEA_ARR_DATA]    // the buffer: 6 * 24 zero bytes
    mov x10, #(6 * 24)
    mov w11, #0
1:  ldrb w12, [x9], #1
    orr w11, w11, w12
    subs x10, x10, #1
    b.ne 1b
    cmp w11, #0
    CHECK eq, "buffer zeroed"
    // Element 0's field a: a fresh string (count 1); element 5's field b:
    // a string the test also holds (count 2). Every other field stays null.
    LA x0, Lsab
    LA x1, Lsc
    mov x2, #0
    bl _sea_str_cat
    ldr x9, [x19, #SEA_ARR_DATA]
    str x0, [x9, #0]                // element 0, offset 0
    LA x0, Lsc
    LA x1, Lsab
    mov x2, #0
    bl _sea_str_cat
    mov x20, x0                     // held by the test ...
    bl _sea_retain                  // ... and by the array
    ldr x9, [x19, #SEA_ARR_DATA]
    str x20, [x9, #(5 * 24 + 16)]   // element 5, offset 16
    LIVEOUT " live"                 // 3: the array and two strings
    mov x0, x19
    bl _sea_release                 // count 0: sea_free
    LIVEOUT " live after the release"   // 1: the shared string
    ldr x9, [x20, #SEA_STR_RC]
    cmp x9, #1
    CHECK eq, "shared string count 1"
    mov x0, x20
    bl _sea_release
    EPILOGUE

    .section __DATA,__const
    .p2align 3
Lslay:                              // {str a; f64 x; str b}
    .quad 24, 2, 0, 16
    SSTR Lsab, 2, "ab"
    SSTR Lsc, 1, "c"
    .p2align 3
    .globl _sea_sites
_sea_sites:
    .quad 0
