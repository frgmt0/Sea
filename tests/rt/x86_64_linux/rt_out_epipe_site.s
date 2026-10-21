# sea/tests/rt/x86_64_linux/rt_out_epipe_site.s -- a buffer flush fails in the middle of the program: the error carries the site of the output call (LANGUAGE 9.2)
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
    leaq .Lblock(%rip), %rdi    # 70000 bytes > the 64 KiB buffer: the flush happens inside the call
    movl $70000, %esi
    xorl %edx, %edx             # site 0
    call sea_out_bytes
    EPILOGUE                    # not reached

    .section .rodata
.Lblock: .fill 70000, 1, 0x61
    .section .data.rel.ro,"aw",@progbits
    .p2align 3
    SSTR .Lfile0, 5, "s.sea"
    .globl sea_sites
sea_sites:
    .quad .Lfile0
    .quad 7
