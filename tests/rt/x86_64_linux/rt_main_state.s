# sea/tests/rt/x86_64_linux/rt_main_state.s -- start-up state: sea_variant is SEA_VAR_SSE2 or SEA_VAR_AVX2; sea_main runs at the top of a 64 MiB stack whose limit is SEA_STACK_MARGIN above the guard page
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
    movq sea_variant(%rip), %rax
    cmpq $SEA_VAR_SSE2, %rax
    je 1f
    cmpq $SEA_VAR_AVX2, %rax
    jne .Lbad                   # neither x86_64 variant id
1:  movq sea_stack_limit(%rip), %rax
    movq %rsp, %rcx
    cmpq %rcx, %rax
    jae .Lbad                   # the limit is below %rsp
    subq %rax, %rcx             # room between %rsp and the limit
    movl $(64*1024*1024 - SEA_STACK_MARGIN), %edx
    cmpq %rdx, %rcx
    ja .Lbad                    # at most stack size - margin
    subq $256, %rdx
    cmpq %rdx, %rcx
    jb .Lbad                    # and %rsp is within 256 bytes of the top
    PUT .Lok, 9
    EPILOGUE
.Lbad:
    PUT .Lno, 10
    EPILOGUE

    .section .rodata
.Lok: .ascii "state ok\n"
.Lno: .ascii "state bad\n"
    .section .data.rel.ro,"aw",@progbits
    .p2align 3
    .globl sea_sites
sea_sites:
    .quad 0
