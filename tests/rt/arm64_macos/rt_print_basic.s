// sea/tests/rt/arm64_macos/rt_print_basic.s -- sea_print (DESIGN.md 4.8 PRINT, LANGUAGE.md 11.2, L-cd): a string's bytes into the standard-output buffer, nothing added, in program order with sea_printf; an empty string writes nothing; NUL and 0xFF bytes as they are; the argument is borrowed (count unchanged); live count back to 0 (heap check)
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

// Pre-parsed format pieces (rt.inc SEA_FP_*): a text piece and a conversion piece.
.macro FTEXT label, len
    .byte SEA_FPK_TEXT, 0, 0, 0
    .long -1, -1, 0
    .quad \label, \len
.endm
.macro FCONV letter, flags, cls, width, prec
    .byte SEA_FPK_CONV, \letter, \flags, \cls
    .long \width, \prec, 0
    .quad 0, 0
.endm
// PR label: _sea_print(label, site 0).
.macro PR label
    LA x0, \label
    mov x1, #0
    bl _sea_print
.endm

    .section __TEXT,__text,regular,pure_instructions
    .globl _sea_main
    .p2align 2
_sea_main:
    PROLOGUE
    LA x0, Lfa                      // printf("a=%d\n", 1)
    LA x1, Lsa
    mov x2, #0
    bl _sea_printf
    PR Labc                         // print("abc")
    PR Lempty                       // print(""): nothing
    PR Llf                          // print("\n")
    PR Lbin                         // NUL and 0xFF bytes as they are
    LA x0, Lfb                      // printf("b\n")
    LA x1, Lsa
    mov x2, #0
    bl _sea_printf
    LA x0, Labc                     // a dynamic string: "abc" + "\n"
    LA x1, Llf
    mov x2, #0
    bl _sea_str_cat
    mov x19, x0
    mov x1, #0
    bl _sea_print                   // borrowed: still count 1
    ldr x9, [x19, #SEA_STR_RC]
    KV "rc=", x9
    TXT "\n"
    REL x19
    LIVE x20
    KV "live=", x20
    TXT "\n"
    EPILOGUE

    .section __TEXT,__const
Lt_a:   .ascii "a="
Lt_lf:  .ascii "\n"
Lt_b:   .ascii "b\n"
    .section __DATA,__const
    SSTR Labc, 3, "abc"
    SSTR Lempty, 0, ""
    SSTR Llf, 1, "\n"
    .p2align 3
Lbin:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 4
    .byte 0x78, 0x00, 0xFF, 0x0A    // "x", NUL, 0xFF, LF
    .p2align 3
Lfa:
    .quad 3, 1
    FTEXT Lt_a, 2
    FCONV 100, 0, SEA_CLS_I, -1, -1
    FTEXT Lt_lf, 1
Lfb:
    .quad 1, 0
    FTEXT Lt_b, 2
Lsa:
    .quad 1
    .p2align 3
    .globl _sea_sites
_sea_sites:
    .quad Labc, 1
