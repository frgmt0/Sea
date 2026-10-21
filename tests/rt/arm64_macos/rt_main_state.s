// sea/tests/rt/arm64_macos/rt_main_state.s -- start-up state: _sea_variant is SEA_VAR_NEON; _sea_main runs at the top of a 64 MiB stack whose limit is SEA_STACK_MARGIN above the guard page
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
    adrp x9, _sea_variant@PAGE
    ldr x9, [x9, _sea_variant@PAGEOFF]
    cmp x9, #SEA_VAR_NEON
    b.ne Lbad
    adrp x9, _sea_stack_limit@PAGE
    ldr x9, [x9, _sea_stack_limit@PAGEOFF]
    mov x10, sp
    cmp x9, x10
    b.hs Lbad                   // the limit is below sp
    sub x10, x10, x9            // room between sp and the limit
    LI x11, (64*1024*1024 - SEA_STACK_MARGIN)
    cmp x10, x11
    b.hi Lbad                   // at most stack size - margin
    sub x11, x11, #256
    cmp x10, x11
    b.lo Lbad                   // and sp is within 256 bytes of the top
    PUT Lok, 9
    EPILOGUE
Lbad:
    PUT Lno, 10
    EPILOGUE

    .section __TEXT,__const
Lok: .ascii "state ok\n"
Lno: .ascii "state bad\n"
    .section __DATA,__const
    .p2align 3
    .globl _sea_sites
_sea_sites:
    .quad 0
