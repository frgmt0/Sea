// sea/tests/rt/arm64_macos/rt_fmod_special.s -- sea_fmod's special cases (LANGUAGE.md 6.6, DESIGN.md 4.8 FMOD, L-cm): b = +-0 returns a's bits (inf, NaN payloads, -0 included); an infinite a or a NaN operand gives #7FF8000000000000; zero results keep the sign of a; b = +-inf; the floored adjustment for each sign combination, rounded once
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
// ---- phase-6 helpers (the same block in every 6b runtime test) --------
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

// Lcat -- print the bytes of a file (x0 = NUL-terminated path) to the
// standard-output buffer; a file that cannot be opened prints
// "<no file>". Clobbers x0-x17. Callee-saved used: x19 (fd). Frame 32
// bytes + a 4096-byte read buffer at [sp].
    .p2align 2
Lcat:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    sub sp, sp, #4096
    mov w1, #0                  // O_RDONLY
    bl _open
    mov w19, w0
    tbz w0, #31, 1f
    TXT "<no file>"
    b 3f
1:  mov w0, w19                 // read up to 4096 bytes
    mov x1, sp
    mov x2, #4096
    bl _read
    cmp x0, #0
    b.le 2f                     // end of file (or an error)
    mov x1, x0
    mov x0, sp
    bl _sea_out_write
    b 1b
2:  mov w0, w19
    bl _close
3:  add sp, sp, #4096
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
// ---- end of the phase-6 helpers ---------------------------------------

// FM a, b: print the bits of _sea_fmod(a, b) and LF (a, b given as bits).
.macro FM a, b
    LI x9, \a
    fmov d0, x9
    LI x10, \b
    fmov d1, x10
    bl _sea_fmod
    fmov x0, d0
    bl Lput_hex
    TXT "\n"
.endm

    .section __TEXT,__text,regular,pure_instructions
    .globl _sea_main
    .p2align 2
_sea_main:
    PROLOGUE
    // b = +-0: a's bits unchanged (also inf, NaN payloads, -0)
    FM 0x4014000000000000, 0x0000000000000000      // 5 % +0
    FM 0x4014000000000000, 0x8000000000000000      // 5 % -0
    FM 0x7FF0000000000000, 0x0000000000000000      // inf % 0
    FM 0x7FF8000000000123, 0x0000000000000000      // NaN (payload) % 0
    FM 0xFFF0000000000001, 0x8000000000000000      // -sNaN % -0
    FM 0x8000000000000000, 0x0000000000000000      // -0 % 0
    // an infinite a or a NaN operand: #7FF8000000000000
    FM 0x7FF0000000000000, 0x4000000000000000      // inf % 2
    FM 0xFFF0000000000000, 0x4000000000000000      // -inf % 2
    FM 0xFFF8000000000123, 0x4000000000000000      // -NaN % 2
    FM 0x3FF0000000000000, 0x7FF8000000000456      // 1 % NaN
    FM 0x7FF0000000000000, 0x7FF8000000000000      // inf % NaN
    FM 0x7FF0000000000000, 0x7FF0000000000000      // inf % inf
    // signed zeros: a zero r keeps fmod's sign (the sign of a)
    FM 0xC018000000000000, 0x4008000000000000      // -6 % 3 = -0
    FM 0x4018000000000000, 0xC008000000000000      // 6 % -3 = +0
    FM 0x0000000000000000, 0xC008000000000000      // +0 % -3 = +0
    FM 0x8000000000000000, 0x4008000000000000      // -0 % 3 = -0
    FM 0x401C000000000000, 0x401C000000000000      // 7 % 7 = +0
    FM 0xC01C000000000000, 0x401C000000000000      // -7 % 7 = -0
    // b = +-inf
    FM 0xBFF0000000000000, 0x7FF0000000000000      // -1 % inf = inf
    FM 0x3FF0000000000000, 0x7FF0000000000000      // 1 % inf = 1
    FM 0x3FF0000000000000, 0xFFF0000000000000      // 1 % -inf = -inf
    FM 0xBFF0000000000000, 0xFFF0000000000000      // -1 % -inf = -1
    FM 0x8000000000000000, 0x7FF0000000000000      // -0 % inf = -0
    // the floored adjustment, each sign combination
    FM 0x4016000000000000, 0x4000000000000000      // 5.5 % 2 = 1.5
    FM 0xC016000000000000, 0x4000000000000000      // -5.5 % 2 = 0.5
    FM 0x4016000000000000, 0xC000000000000000      // 5.5 % -2 = -0.5
    FM 0xC016000000000000, 0xC000000000000000      // -5.5 % -2 = -1.5
    // r + b rounded once: -2^-1074 % 1 = 1 - 2^-1074, rounded to 1
    FM 0x8000000000000001, 0x3FF0000000000000
    EPILOGUE

    .section __DATA,__const
    .p2align 3
    .globl _sea_sites
_sea_sites:
    .quad 0
