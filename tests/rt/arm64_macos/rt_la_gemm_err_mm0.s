// sea/tests/rt/arm64_macos/rt_la_gemm_err_mm0.s -- sea_matmul of a 0x3 and a 2x0 matrix: the mismatch is reported although both are empty (the check comes first, L-ik): `shape mismatch: 0x3 vs 2x0` (DESIGN.md 2.13.2 "Run-time errors", 2.13.5, L-ij: the operands' shapes in source order as `h` slots) at the call's site, status 1, nothing on standard output
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

    .section __TEXT,__text,regular,pure_instructions
// _sea_main -- the failing call with site 0; never returns. Frame 16 bytes.
    .globl _sea_main
    .p2align 2
_sea_main:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    adrp x0, Lleft@PAGE
    add x0, x0, Lleft@PAGEOFF
    adrp x1, Lright@PAGE
    add x1, x1, Lright@PAGEOFF
    mov x2, #0                      // site 0: la.sea:12
    bl _sea_matmul                 // noreturn here
    ldp x29, x30, [sp], #16
    ret

    .section __DATA,__const
    .p2align 6
Lleft:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_ARRAY, SEA_EK_F64, 2, 0, 0, 0, 0, 0
    .quad 0, 3, 0, Lleft + SEA_ARR_SIZE, 8, 0
    .p2align 6
Lright:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_ARRAY, SEA_EK_F64, 2, 0, 0, 0, 0, 0
    .quad 2, 0, 0, Lright + SEA_ARR_SIZE, 8, 0
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
