// sea/tests/rt/arm64_macos/rt_out_epipe_site.s -- a buffer flush fails in the middle of the program: the error carries the site of the output call (LANGUAGE 9.2)
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
    adrp x0, Lblock@PAGE        // 70000 bytes > the 64 KiB buffer: the flush happens inside the call
    add x0, x0, Lblock@PAGEOFF
    LI x1, 70000
    mov x2, #0                  // site 0
    bl _sea_out_bytes
    EPILOGUE                    // not reached

    .section __TEXT,__const
Lblock: .fill 70000, 1, 0x61
    .section __DATA,__const
    .p2align 3
    SSTR Lfile0, 5, "s.sea"
    .globl _sea_sites
_sea_sites:
    .quad Lfile0
    .quad 7
