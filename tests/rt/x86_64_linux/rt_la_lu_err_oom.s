# sea/tests/rt/x86_64_linux/rt_la_lu_err_oom.s -- sea_lu of a (fabricated) 2^28 x 2^28 matrix: the handle block (64 + 8n^2 + 4n bytes, about 2^59) cannot be allocated, so out of memory at the call's site, through sea_alloc (DESIGN.md 2.13.5 "Memory"); the elements are never read.
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
    xorl %esi, %esi                 # site 0: la.sea:12
    call sea_lu
    popq %rbp                       # not reached: the entry stops the program
    ret
    .size sea_main, . - sea_main

    .section .data.rel.ro,"aw",@progbits
    MAT .LA, 2, 268435456, 268435456, 1
    .quad P1
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
