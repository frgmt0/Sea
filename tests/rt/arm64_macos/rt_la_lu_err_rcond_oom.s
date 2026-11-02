// sea/tests/rt/arm64_macos/rt_la_lu_err_rcond_oom.s -- sea_rcond of an Lu handle of order 2^58 with ||A||_1 = 1 and no zero pivot (a static object in the private layout of DESIGN.md 2.13.6 "Handles"; its factor is never reached): none of the special values applies, and the scratch of 2n doubles (2^62 bytes) cannot be mapped: `out of memory`, RCOND's only failure (DESIGN.md 2.13.5) at the call's site, status 1
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

    .section __TEXT,__text,regular,pure_instructions
// _sea_main -- the calls with site 0 (la.sea:12); the last one fails and
// never returns. Frame 16 bytes.
    .globl _sea_main
    .p2align 2
_sea_main:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    adrp x0, LF@PAGE
    add x0, x0, LF@PAGEOFF
    mov x1, #0
    bl _sea_rcond                  // noreturn here
    ldp x29, x30, [sp], #16
    ret

    .section __DATA,__const
    .p2align 6
LF:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_LU, 0, 0, 0, 0, 0, 0, 0
    .quad 288230376151711744        // n = 2^58 (the factor is never reached)
    .quad 0x3FF0000000000000        // ||A||_1 = 1
    .quad -1                        // no zero pivot
    .quad 0, 0, 0

    .p2align 3
    .globl _sea_sites
_sea_sites:
    .quad Lsite_file
    .quad 12
Lsite_file:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 6
    .ascii "la.sea"
