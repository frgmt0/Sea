# sea/tests/rt/x86_64_linux/rt_out_large.s -- output larger than the 64 KiB buffer: padding runs, an exact buffer-size run, many blocks; bytes and order preserved across flushes
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
    subq $8, %rsp               # %rsp = 0 (mod 16)
    PUT .Lhead, 5
    movl $45, %edi              # 100000 x '-'
    movl $100000, %esi
    call sea_out_repeat
    PUT .Lnl, 1
    movl $97, %edi              # exactly 65536 (the buffer size) x 'a'
    movl $65536, %esi
    call sea_out_repeat
    PUT .Lbar, 2
    movl $10, %ebx              # ten blocks of 16000 bytes
1:  leaq .Lblock(%rip), %rdi
    movl $16000, %esi
    call sea_out_write
    decl %ebx
    jnz 1b
    PUT .Ltail, 5
    addq $8, %rsp
    popq %rbx
    EPILOGUE

    .section .rodata
.Lhead: .ascii "head\n"
.Lnl:   .ascii "\n"
.Lbar:  .ascii "|\n"
.Ltail: .ascii "tail\n"
.Lblock:
    .rept 1000
    .ascii "0123456789abcdef"
    .endr
    .section .data.rel.ro,"aw",@progbits
    .p2align 3
    .globl sea_sites
sea_sites:
    .quad 0
