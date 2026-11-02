# sea/tests/rt/x86_64_linux/rt_la_lu_err_solve_shape.s -- sea_solve of a 3 x 3 A and a vector of 4: shape mismatch: 3x3 vs 4 (DESIGN.md 2.13.5 SOLVE, L-ij).
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

# A static dynamic-array object (count SEA_RC_STATIC) of f64 elements;
# its elements follow the header.
.macro MAT name, rank, rows, cols, cap
    .p2align 6
\name:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_ARRAY, SEA_EK_F64, \rank, 0, 0, 0, 0, 0
    .quad \rows, \cols, \cap, \name + SEA_ARR_SIZE, 8, 0
.endm
.equ P0, 0x0000000000000000
.equ P1, 0x3FF0000000000000
.equ P2, 0x4000000000000000
.equ P4, 0x4010000000000000
.equ QN, 0x7FF8000000000000

    .text
    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    pushq %rbp
    movq %rsp, %rbp
    leaq .LA(%rip), %rdi
    leaq .LB(%rip), %rsi
    xorl %edx, %edx                 # site 0: la.sea:12
    call sea_solve
    popq %rbp                       # not reached: the entry stops the program
    ret
    .size sea_main, . - sea_main

    .section .data.rel.ro,"aw",@progbits
    MAT .LA, 2, 3, 3, 9
    .quad P1, P0, P0, P0, P1, P0, P0, P0, P1
    MAT .LB, 1, 4, 1, 4
    .quad P1, P1, P1, P1
    .p2align 3
    .globl sea_sites
sea_sites:
    .quad .Lsite_file
    .quad 12
.Lsite_file:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 6
    .ascii "la.sea"

    .section .note.GNU-stack,"",@progbits
