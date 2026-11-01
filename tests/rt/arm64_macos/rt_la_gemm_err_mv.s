// sea/tests/rt/arm64_macos/rt_la_gemm_err_mv.s -- sea_gemv of a 2x3 matrix and a vector of 4: `shape mismatch: 2x3 vs 4` (DESIGN.md 2.13.2 "Run-time errors", 2.13.5, L-ij: the operands' shapes in source order as `h` slots) at the call's site, status 1, nothing on standard output
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
    bl _sea_gemv                 // noreturn here
    ldp x29, x30, [sp], #16
    ret

    .section __DATA,__const
    .p2align 6
Lleft:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_ARRAY, SEA_EK_F64, 2, 0, 0, 0, 0, 0
    .quad 2, 3, 6, Lleft + SEA_ARR_SIZE, 8, 0
    .quad 0x3FF0000000000000, 0x3FF0000000000000, 0x3FF0000000000000, 0x3FF0000000000000, 0x3FF0000000000000, 0x3FF0000000000000
    .p2align 6
Lright:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_ARRAY, SEA_EK_F64, 1, 0, 0, 0, 0, 0
    .quad 4, 1, 4, Lright + SEA_ARR_SIZE, 8, 0
    .quad 0x3FF0000000000000, 0x3FF0000000000000, 0x3FF0000000000000, 0x3FF0000000000000
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
