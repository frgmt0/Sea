// sea/tests/rt/arm64_macos/rt_main_limit.s -- a function with the prologue stack-limit check (DESIGN 4.6) recurses until sp - frame < _sea_stack_limit: error at the function's site, status 1
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
    PUT Lstart, 6
    bl Lrec
    EPILOGUE
Lrec:
    sub x16, sp, #48            // sp minus this function's frame size
    adrp x17, _sea_stack_limit@PAGE
    ldr x17, [x17, _sea_stack_limit@PAGEOFF]
    cmp x16, x17
    b.lo Loverflow
    stp x29, x30, [sp, #-48]!
    mov x29, sp
    bl Lrec
    ldp x29, x30, [sp], #48     // not reached
    ret
Loverflow:
    mov w0, #SEA_E_STACK_OVERFLOW
    mov x1, #0                  // the site of the function's definition line
    mov x2, #0
    bl _sea_err

    .section __TEXT,__const
Lstart: .ascii "start\n"
    .section __DATA,__const
    .p2align 3
    SSTR Lfile0, 7, "fib.sea"
    .globl _sea_sites
_sea_sites:
    .quad Lfile0
    .quad 9
