# sea/tests/rt/x86_64_linux/rt_out_basic.s -- bytes written through _sea_out_write come out unchanged: text, a zero-length write, binary bytes (NUL, 0xFF)
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
    PUT .Ltxt1, 11
    movq %rsp, %rdi             # a zero-length write appends nothing
    xorl %esi, %esi
    call sea_out_write
    PUT .Ltxt2, 6
    EPILOGUE

    .section .rodata
.Ltxt1: .ascii "hello, sea\n"
.Ltxt2: .byte 97, 0, 98, 255, 99, 10
    .section .data.rel.ro,"aw",@progbits
    .p2align 3
    .globl sea_sites
sea_sites:
    .quad 0
