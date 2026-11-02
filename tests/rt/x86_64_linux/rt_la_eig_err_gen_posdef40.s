# sea/tests/rt/x86_64_linux/rt_la_eig_err_gen_posdef40.s -- sea_eig_sym_gen(K, M) with K = I and M = I but M[39,39] = -1, order 40: sea_la_potrf's blocked path (two panels, its scratch W in the call's one scratch block) reports pivot 39, so matrix is not positive definite at the call's site (2.13.5 EIG_SYM_GEN, 2.13.6).
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
.equ PI, 0x7FF0000000000000
.equ M1, 0xBFF0000000000000

    .text
    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    pushq %rbp
    movq %rsp, %rbp
    leaq .LK(%rip), %rdi
    leaq .LM(%rip), %rsi
    xorl %edx, %edx                 # site 0: la.sea:12
    call sea_eig_sym_gen
    popq %rbp                       # not reached: the entry stops the program
    ret
    .size sea_main, . - sea_main

    .section .data.rel.ro,"aw",@progbits
    MAT .LK, 2, 40, 40, 1600
    .quad P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1
    MAT .LM, 2, 40, 40, 1600
    .quad P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P1, P0
    .quad P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, P0, M1
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
