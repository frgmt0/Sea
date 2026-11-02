// sea/tests/rt/arm64_macos/rt_la_lu_err_solve_shape.s -- sea_solve of a 3x3 A and a 2x5 B: `shape mismatch: 3x3 vs 2x5` (DESIGN.md 2.13.5 SOLVE, L-ij) at the call's site, status 1
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
    adrp x1, Lb@PAGE
    add x1, x1, Lb@PAGEOFF
    mov x2, #0
    bl _sea_solve                  // noreturn here
    ldp x29, x30, [sp], #16
    ret

    .section __DATA,__const
    .p2align 6
La:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_ARRAY, SEA_EK_F64, 2, 0, 0, 0, 0, 0
    .quad 3, 3, 9, La + SEA_ARR_SIZE, 8, 0
    .quad 0x4010000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x4010000000000000, 0x0000000000000000, 0x0000000000000000, 0x0000000000000000, 0x4010000000000000
    .p2align 6
Lb:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_ARRAY, SEA_EK_F64, 2, 0, 0, 0, 0, 0
    .quad 2, 5, 10, Lb + SEA_ARR_SIZE, 8, 0
    .quad 0x3FF0000000000000, 0x3FF0000000000000, 0x3FF0000000000000, 0x3FF0000000000000, 0x3FF0000000000000, 0x3FF0000000000000, 0x3FF0000000000000, 0x3FF0000000000000, 0x3FF0000000000000, 0x3FF0000000000000
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
