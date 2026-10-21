// sea/tests/rt/arm64_macos/rt_out_basic.s -- bytes written through _sea_out_write come out unchanged: text, a zero-length write, binary bytes (NUL, 0xFF)
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
    PROLOGUE
    PUT Ltxt1, 11
    mov x0, sp                  // a zero-length write appends nothing
    mov x1, #0
    bl _sea_out_write
    PUT Ltxt2, 6
    EPILOGUE

    .section __TEXT,__const
Ltxt1: .ascii "hello, sea\n"
Ltxt2: .byte 97, 0, 98, 255, 99, 10
    .section __DATA,__const
    .p2align 3
    .globl _sea_sites
_sea_sites:
    .quad 0
