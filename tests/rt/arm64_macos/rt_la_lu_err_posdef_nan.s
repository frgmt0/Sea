// sea/tests/rt/arm64_macos/rt_la_lu_err_posdef_nan.s -- sea_chol of [NaN]: a NaN pivot is not greater than 0: `matrix is not positive definite` (L-im: the one place a NaN stops instead of propagating) at the call's site, status 1
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
    bl _sea_chol                  // noreturn here
    ldp x29, x30, [sp], #16
    ret

    .section __DATA,__const
    .p2align 6
La:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_ARRAY, SEA_EK_F64, 2, 0, 0, 0, 0, 0
    .quad 1, 1, 1, La + SEA_ARR_SIZE, 8, 0
    .quad 0x7FF8000000000000
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
