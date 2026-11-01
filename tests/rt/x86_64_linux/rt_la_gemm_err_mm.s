# sea/tests/rt/x86_64_linux/rt_la_gemm_err_mm.s -- sea_matmul of a 2x3 and a 4x2 matrix: `shape mismatch: 2x3 vs 4x2` (DESIGN.md 2.13.2 "Run-time errors", 2.13.5, L-ij: the operands' shapes in source order as `h` slots) at the call's site, status 1, nothing on standard output
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

    .text
# sea_main -- the failing call with site 0; never returns. Frame 8 bytes
# (%rbp), so %rsp = 0 (mod 16) at the call.
    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    pushq %rbp
    movq %rsp, %rbp
    leaq .Lleft(%rip), %rdi
    leaq .Lright(%rip), %rsi
    xorl %edx, %edx                 # site 0: la.sea:12
    call sea_matmul                # noreturn here
    popq %rbp
    ret
    .size sea_main, . - sea_main

    .section .data.rel.ro,"aw",@progbits
    .p2align 6
.Lleft:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_ARRAY, SEA_EK_F64, 2, 0, 0, 0, 0, 0
    .quad 2, 3, 6, .Lleft + SEA_ARR_SIZE, 8, 0
    .quad 0x3FF0000000000000, 0x3FF0000000000000, 0x3FF0000000000000, 0x3FF0000000000000, 0x3FF0000000000000, 0x3FF0000000000000
    .p2align 6
.Lright:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_ARRAY, SEA_EK_F64, 2, 0, 0, 0, 0, 0
    .quad 4, 2, 8, .Lright + SEA_ARR_SIZE, 8, 0
    .quad 0x3FF0000000000000, 0x3FF0000000000000, 0x3FF0000000000000, 0x3FF0000000000000, 0x3FF0000000000000, 0x3FF0000000000000, 0x3FF0000000000000, 0x3FF0000000000000
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
