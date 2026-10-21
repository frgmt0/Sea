// sea/tests/rt/arm64_macos/rt_main_kernel_default.s -- kernel selection (DESIGN 4.4): Baysick's variant in use after start-up and _sea_variant (arm64-macos has one variant, neon)
.include "errors.inc"
.include "rt.inc"

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
// Append static bytes to the standard-output buffer (x0, x1 clobbered).
.macro PUT label, len
    adrp x0, \label@PAGE
    add x0, x0, \label@PAGEOFF
    mov x1, #\len
    bl _sea_out_write
.endm
// _sea_err(code, site, slots label); noreturn.
.macro RAISE code, site, slots
    mov w0, #\code
    mov x1, #\site
    adrp x2, \slots@PAGE
    add x2, x2, \slots@PAGEOFF
    bl _sea_err
.endm
// Load a 32-bit constant into a register.
.macro LI reg, val
    movz \reg, #((\val) & 0xffff)
    movk \reg, #(((\val) >> 16) & 0xffff), lsl #16
.endm
// Function prologue / epilogue of _sea_main-like routines (frame record only).
.macro PROLOGUE
    stp x29, x30, [sp, #-16]!
    mov x29, sp
.endm
.macro EPILOGUE
    ldp x29, x30, [sp], #16
    ret
.endm

    .section __TEXT,__text,regular,pure_instructions
    .globl _sea_main
    .p2align 2
_sea_main:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    PUT Lk, 7
    bl _bsk_kern_name
    mov x19, x0                 // the name of the variant in use
    bl _strlen
    mov x1, x0
    mov x0, x19
    bl _sea_out_write
    PUT Lv, 9
    adrp x9, _sea_variant@PAGE
    ldr x9, [x9, _sea_variant@PAGEOFF]
    add x9, x9, #48             // the id as one decimal digit
    strb w9, [sp, #24]
    add x0, sp, #24
    mov x1, #1
    bl _sea_out_write
    PUT Lnl, 1
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
    .section __TEXT,__const
Lk:  .ascii "kernel "
Lv:  .ascii " variant "
Lnl: .ascii "\n"
    .section __DATA,__const
    .p2align 3
    .globl _sea_sites
_sea_sites:
    .quad 0
