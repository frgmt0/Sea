// sea/tests/rt/arm64_macos/rt_la_eig_err_nsym_negzero_nan.s -- sea_eig_sym of [0 NaN; 1 0]: a NaN paired with a number is not symmetric (Decision 123): `matrix is not symmetric` at the call's site, status 1 (DESIGN.md 2.13.5 EIG_SYM, EIG_SYM_GEN; L-ik)
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

    .section __TEXT,__text,regular,pure_instructions
// _sea_main -- the call with site 0 (la.sea:12); it fails and never
// returns. Frame 16 bytes.
    .globl _sea_main
    .p2align 2
_sea_main:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    adrp x0, Lk@PAGE
    add x0, x0, Lk@PAGEOFF
    mov x1, #0
    bl _sea_eig_sym              // noreturn here
    ldp x29, x30, [sp], #16
    ret

    .section __DATA,__const
    .p2align 6
Lk:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_ARRAY, SEA_EK_F64, 2, 0, 0, 0, 0, 0
    .quad 2, 2, 4, Lk + SEA_ARR_SIZE, 8, 0
    .quad 0x0000000000000000, 0x3FF0000000000000, 0x7FF8000000000000, 0x0000000000000000
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
