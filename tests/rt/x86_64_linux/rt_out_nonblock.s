# sea/tests/rt/x86_64_linux/rt_out_nonblock.s -- stdout is a non-blocking pipe that is full: EAGAIN is waited out with poll, not an error; 300000 bytes arrive intact
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
    movl $1, %edi               # fcntl(1, F_SETFL, O_NONBLOCK): variadic, no vector registers
    movl $4, %esi               # F_SETFL
    movl $2048, %edx            # O_NONBLOCK on Linux
    xorl %eax, %eax
    call fcntl@PLT
    testl %eax, %eax
    jnz .Lfail
    movl $120, %edi             # 300000 x 'x'
    movl $300000, %esi
    call sea_out_repeat
    PUT .Lnl, 1
    EPILOGUE
.Lfail:
    movl $SEA_E_USER, %edi      # fcntl failed: cannot run the test
    movq $SEA_SITE_NONE, %rsi
    leaq .Lslot(%rip), %rdx
    call sea_err

    .section .rodata
.Lnl: .ascii "\n"
    .section .data.rel.ro,"aw",@progbits
    .p2align 3
    SSTR .Lmsg, 12, "fcntl failed"
.Lslot: .quad .Lmsg
    .globl sea_sites
sea_sites:
    .quad 0
