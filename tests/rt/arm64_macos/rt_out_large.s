// sea/tests/rt/arm64_macos/rt_out_large.s -- output larger than the 64 KiB buffer: padding runs, an exact buffer-size run, many blocks; bytes and order preserved across flushes
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
    PUT Lhead, 5
    mov w0, #45                 // 100000 x '-'
    LI x1, 100000
    bl _sea_out_repeat
    PUT Lnl, 1
    mov w0, #97                 // exactly 65536 (the buffer size) x 'a'
    LI x1, 65536
    bl _sea_out_repeat
    PUT Lbar, 2
    mov w19, #10                // ten blocks of 16000 bytes
1:  adrp x0, Lblock@PAGE
    add x0, x0, Lblock@PAGEOFF
    mov x1, #16000
    bl _sea_out_write
    subs w19, w19, #1
    b.ne 1b
    PUT Ltail, 5
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
    ret

    .section __TEXT,__const
Lhead: .ascii "head\n"
Lnl:   .ascii "\n"
Lbar:  .ascii "|\n"
Ltail: .ascii "tail\n"
Lblock:
    .rept 1000
    .ascii "0123456789abcdef"
    .endr
    .section __DATA,__const
    .p2align 3
    .globl _sea_sites
_sea_sites:
    .quad 0
