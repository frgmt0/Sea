// sea/tests/rt/arm64_macos/rt_format_basic.s -- sea_format (DESIGN.md 4.8 FORMAT, LANGUAGE.md 11.1): a new string (count 1, tag, length) of exactly the bytes sea_printf writes for the same format and slots: text, %05d, %-4s, %.3f, %8d of NaN, %e, %%; the empty format gives an empty string; %d of -0.0, %+d, %f of an i64; nothing goes to stdout; live count back to 0 (heap check)
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
// FMT fmt, slots: x0 := _sea_format(fmt, slots, site 0); print it as
// [bytes] LF, then its count, tag and length; release it.
.macro FMT fmt, slots
    LA x0, \fmt
    LA x1, \slots
    mov x2, #0
    bl _sea_format
    mov x19, x0
    bl Lput_str
    ldr x9, [x19, #SEA_STR_RC]
    KV " rc=", x9
    ldrb w9, [x19, #SEA_STR_TAG]
    cmp w9, #SEA_TAG_STR
    cset x9, eq
    KV " tag_ok=", x9
    ldr x9, [x19, #SEA_STR_LEN]
    KV " len=", x9
    TXT "\n"
    REL x19
.endm

    .section __TEXT,__text,regular,pure_instructions
    .globl _sea_main
    .p2align 2
_sea_main:
    PROLOGUE
    LIVE x20
    KV "live before=", x20
    TXT "\n"
    FMT Lf1, Ls1
    FMT Lf2, Ls2
    FMT Lf3, Ls3
    // The same format through sea_printf: the same bytes on stdout.
    TXT "["
    LA x0, Lf1
    LA x1, Ls1
    mov x2, #0
    bl _sea_printf
    TXT "]\n"
    LIVE x20
    KV "live after=", x20
    TXT "\n"
    EPILOGUE

    .section __TEXT,__const
Lt_n:   .ascii "n="
Lt_s:   .ascii " s="
Lt_bar: .ascii "|"
Lt_sp:  .ascii " "
Lt_pc:  .ascii "%"
    .section __DATA,__const
    SSTR Lab, 2, "ab"
    .p2align 3
// "n=%05d s=%-4s|%.3f %8d %e%%"
Lf1:
    .quad 11, 5
    FTEXT Lt_n, 2
    FCONV 100, SEA_FF_ZERO, SEA_CLS_I, 5, -1        // %05d
    FTEXT Lt_s, 3
    FCONV 115, SEA_FF_LEFT, SEA_CLS_P, 4, -1        // %-4s
    FTEXT Lt_bar, 1
    FCONV 102, 0, SEA_CLS_F, -1, 3                  // %.3f
    FTEXT Lt_sp, 1
    FCONV 100, 0, SEA_CLS_F, 8, -1                  // %8d of an f64
    FTEXT Lt_sp, 1
    FCONV 101, 0, SEA_CLS_F, -1, -1                 // %e
    FTEXT Lt_pc, 1                                  // %%
Ls1:
    .quad 42, Lab, 0x400921F9F01B866E, 0x7FF8000000000000, 0x3FF8000000000000
// the empty format: no piece
Lf2:
    .quad 0, 0
Ls2:
    .quad 0
// "%d|%+d|%f": -0.0 under %d, an i64 with +, an i64 under %f
Lf3:
    .quad 5, 3
    FCONV 100, 0, SEA_CLS_F, -1, -1                 // %d of -0.0
    FTEXT Lt_bar, 1
    FCONV 100, SEA_FF_PLUS, SEA_CLS_I, -1, -1       // %+d
    FTEXT Lt_bar, 1
    FCONV 102, 0, SEA_CLS_I, -1, -1                 // %f of an i64
Ls3:
    .quad 0x8000000000000000, 7, 7
    .p2align 3
    .globl _sea_sites
_sea_sites:
    .quad Lab, 1
