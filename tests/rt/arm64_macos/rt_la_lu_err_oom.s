// sea/tests/rt/arm64_macos/rt_la_lu_err_oom.s -- sea_lu of a 2^29 x 2^29 matrix (a static header whose elements are never reached: the handle is allocated first): the handle's block of 2^61 + 2^31 + 64 bytes cannot be mapped: `out of memory` (DESIGN.md 2.13.5 "Memory") at the call's site, status 1
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
    adrp x0, La@PAGE
    add x0, x0, La@PAGEOFF
    mov x1, #0
    bl _sea_lu                  // noreturn here
    ldp x29, x30, [sp], #16
    ret

    .section __DATA,__const
    .p2align 6
La:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_ARRAY, SEA_EK_F64, 2, 0, 0, 0, 0, 0
    .quad 536870912, 536870912, 0, Lnodata, 8, 0
    .p2align 3
Lnodata: .quad 0
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
