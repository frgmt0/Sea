// sea/tests/rt/arm64_macos/rt_la_lu_err_singular.s -- sea_lu_solve with the Lu of [1 2; 2 4] (pivot 2, then 2 - 0.5*4 = 0: a recorded zero pivot; sea_lu itself does not fail) and a vector of 2: `matrix is singular` (DESIGN.md 2.13.5 LU_SOLVE, L-il) at the call's site, status 1
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
    bl _sea_lu                  // the handle (count 1)
    adrp x1, Lb@PAGE
    add x1, x1, Lb@PAGEOFF
    mov x2, #0
    bl _sea_lu_solve                  // noreturn here
    ldp x29, x30, [sp], #16
    ret

    .section __DATA,__const
    .p2align 6
La:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_ARRAY, SEA_EK_F64, 2, 0, 0, 0, 0, 0
    .quad 2, 2, 4, La + SEA_ARR_SIZE, 8, 0
    .quad 0x3FF0000000000000, 0x4000000000000000, 0x4000000000000000, 0x4010000000000000
    .p2align 6
Lb:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_ARRAY, SEA_EK_F64, 1, 0, 0, 0, 0, 0
    .quad 2, 1, 2, Lb + SEA_ARR_SIZE, 8, 0
    .quad 0x3FF0000000000000, 0x3FF0000000000000
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
