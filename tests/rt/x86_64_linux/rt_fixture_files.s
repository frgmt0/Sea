# =====================================================================
# sea/tests/rt/x86_64_linux/rt_fixture_files.s -- proves the rt NAME.files/ sidecar
# (L-mp, DESIGN.md 2.15.8): the program opens "fixture.txt", which exists only
# in rt_fixture_files.files/, reads it and writes it to standard output
# (libc open, read, write). Expected stdout = the fixture's bytes
# (rt_fixture_files.out); an absent fixture makes open fail and the program exit 1.
# The x86_64 port of tests/rt/arm64_macos/rt_fixture_files.s. Run by
# tests/rt/run_rt_linux.sh, linked with the x86_64-linux runtime.
# =====================================================================
.include "limits.inc"
.include "rt.inc"

    .text

# sea_main -- open the fixture, copy up to 256 bytes of it to stdout.
#   Frame: 272 bytes (%rbp, 256-byte buffer at -256(%rbp), saved %rbx + pad);
#   callee-saved used: %rbx = the file descriptor
    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $264, %rsp                 # buffer 256 bytes, 16-byte aligned frame
    leaq .Lfx_path(%rip), %rdi
    xorl %esi, %esi                 # O_RDONLY
    call open@PLT
    testl %eax, %eax
    js .Lfx_fail                    # -1: the fixture is missing
    movl %eax, %ebx
    movl %ebx, %edi
    leaq -272(%rbp), %rsi           # buffer
    movl $256, %edx
    call read@PLT                   # %rax = bytes read
    testq %rax, %rax
    jle .Lfx_fail
    movq %rax, %rdx
    movl $1, %edi                   # standard output
    leaq -272(%rbp), %rsi
    call write@PLT
    movl %ebx, %edi
    call close@PLT
    addq $264, %rsp
    popq %rbx
    popq %rbp
    ret
.Lfx_fail:
    movl $1, %edi
    call exit@PLT
    .size sea_main, .-sea_main

    .section .rodata
.Lfx_path:
    .asciz "fixture.txt"

    .section .data.rel.ro,"aw",@progbits
    .p2align 3
# The error-site table (no site is used).
    .globl sea_sites
sea_sites:
    .quad 0, 0
