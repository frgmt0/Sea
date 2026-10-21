# sea/tests/rt/x86_64_linux/rt_clock_monotonic.s -- _sea_now (LANGUAGE 13): positive, equals sec + nsec/1e9 of CLOCK_MONOTONIC (between two direct readings), advances across a sleep, nanosecond resolution
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
    subq $56, %rsp              # %rsp = 0 (mod 16): ts0 at 0, ts2 at 16, before/value/after at 32/40/48
    movq %rsp, %rdi
    call .Lread                 # %xmm0 = CLOCK_MONOTONIC now, converted
    movsd %xmm0, 32(%rsp)       # before
    call sea_now
    movsd %xmm0, 40(%rsp)       # the value under test
    leaq 16(%rsp), %rdi
    call .Lread
    movsd %xmm0, 48(%rsp)       # after

    # check 1: the value is positive
    xorpd %xmm1, %xmm1
    movsd 40(%rsp), %xmm0
    ucomisd %xmm1, %xmm0
    ja 1f
    PUT .Lf1, 14
    jmp 2f
1:  PUT .Lp1, 9
2:
    # check 2: before <= value <= after
    movsd 32(%rsp), %xmm0
    ucomisd 40(%rsp), %xmm0
    ja 3f                       # before > value
    movsd 40(%rsp), %xmm0
    ucomisd 48(%rsp), %xmm0
    ja 3f                       # value > after
    PUT .Lp2, 7
    jmp 4f
3:  PUT .Lf2, 12
4:
    # check 3: after usleep(20 ms), now() advanced by at least 19 ms and less than 5 s
    movl $20000, %edi
    call usleep@PLT
    call sea_now
    subsd 40(%rsp), %xmm0
    ucomisd .Lmin(%rip), %xmm0
    jb 5f
    ucomisd .Lmax(%rip), %xmm0
    ja 5f
    PUT .Lp3, 6
    jmp 6f
5:  PUT .Lf3, 11
6:
    # check 4: consecutive distinct readings differ by far less than a millisecond
    # (resolution): spin until the value changes, at most 10,000,000 calls
    call sea_now
    movsd %xmm0, 32(%rsp)
    movl $10000000, %ebx
7:  call sea_now
    ucomisd 32(%rsp), %xmm0
    jne 8f
    decl %ebx
    jnz 7b
    PUT .Lf4, 16
    jmp 9f
8:  subsd 32(%rsp), %xmm0
    ucomisd .Lms(%rip), %xmm0
    ja 10f
    PUT .Lp4, 11
    jmp 9f
10: PUT .Lf4, 16
9:
    addq $56, %rsp
    popq %rbx
    EPILOGUE

# .Lread -- %rdi = &timespec: clock_gettime(CLOCK_MONOTONIC = 1) -> %xmm0 = sec + nsec / 1e9
.Lread:
    pushq %rbx                  # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rdi, %rsi
    movl $1, %edi
    call clock_gettime@PLT
    cvtsi2sdq (%rbx), %xmm0
    cvtsi2sdq 8(%rbx), %xmm1
    movl $1000000000, %eax
    cvtsi2sdq %rax, %xmm2
    divsd %xmm2, %xmm1
    addsd %xmm1, %xmm0
    popq %rbx
    ret

    .section .rodata
.Lp1: .ascii "positive\n"
.Lf1: .ascii "FAIL positive\n"
.Lp2: .ascii "bounds\n"
.Lf2: .ascii "FAIL bounds\n"
.Lp3: .ascii "sleep\n"
.Lf3: .ascii "FAIL sleep\n"
.Lp4: .ascii "resolution\n"
.Lf4: .ascii "FAIL resolution\n"
    .p2align 3
.Lmin: .double 0.019
.Lmax: .double 5.0
.Lms:  .double 0.001
    .section .data.rel.ro,"aw",@progbits
    .p2align 3
    .globl sea_sites
sea_sites:
    .quad 0
