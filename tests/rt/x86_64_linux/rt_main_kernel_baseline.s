# sea/tests/rt/x86_64_linux/rt_main_kernel_baseline.s -- kernel selection (DESIGN 4.4, 4.7.1): SEA_KERNELS=baseline selects Baysick's x86_64 baseline, sse2, and sea_variant = SEA_VAR_SSE2
.include "errors.inc"
.include "rt.inc"

# A static string object (rt.inc SEA_STR_*): count SEA_RC_STATIC, tag, length, bytes.
.macro SSTR label, len, text
    .p2align 3
\label:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad \len
    .ascii "\text"
.endm
# Append static bytes to the standard-output buffer (caller-saved registers clobbered).
.macro PUT label, len
    leaq \label(%rip), %rdi
    movq $\len, %rsi
    call sea_out_write
.endm
# sea_err(code, site, slots label); noreturn.
.macro RAISE code, site, slots
    movl $\code, %edi
    movq $\site, %rsi
    leaq \slots(%rip), %rdx
    call sea_err
.endm
# Function prologue / epilogue of sea_main-like routines (frame pointer only;
# entered at %rsp = 8 (mod 16), so %rsp = 0 (mod 16) after the push).
.macro PROLOGUE
    pushq %rbp
    movq %rsp, %rbp
.endm
.macro EPILOGUE
    popq %rbp
    ret
.endm

    .text
    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    PROLOGUE
    pushq %rbx
    subq $8, %rsp               # %rsp = 0 (mod 16); a byte buffer at 0(%rsp)
    PUT .Lk, 7
    call bsk_kern_name
    movq %rax, %rbx             # the name of the variant in use
    movq %rax, %rdi
    call strlen@PLT
    movq %rax, %rsi
    movq %rbx, %rdi
    call sea_out_write
    PUT .Lv, 9
    movq sea_variant(%rip), %rax
    addl $48, %eax              # the id as one decimal digit
    movb %al, (%rsp)
    movq %rsp, %rdi
    movl $1, %esi
    call sea_out_write
    PUT .Lnl, 1
    addq $8, %rsp
    popq %rbx
    EPILOGUE
    .section .rodata
.Lk:  .ascii "kernel "
.Lv:  .ascii " variant "
.Lnl: .ascii "\n"
    .section .data.rel.ro,"aw",@progbits
    .p2align 3
    .globl sea_sites
sea_sites:
    .quad 0
