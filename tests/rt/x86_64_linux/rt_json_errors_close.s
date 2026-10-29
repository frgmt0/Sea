# sea/tests/rt/x86_64_linux/rt_json_errors_close.s -- a write_json to /dev/full (Linux only) whose value fits in the buffer: the final write of JSON_CLOSE (the 2 bytes `1` LF) fails with ENOSPC; the file is closed once, then `cannot write '/dev/full': No space left on device` at the site, status 1 (DESIGN.md 2.11.6, 4.8 entry 28)
.include "limits.inc"
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
# Append a text and a LF (caller-saved registers clobbered).
.macro SAY text
    leaq .Lsay_s\@(%rip), %rdi
    movq $(.Lsay_e\@ - .Lsay_s\@), %rsi
    call sea_out_write
    .pushsection .rodata
.Lsay_s\@: .ascii "\text"
    .byte 10
.Lsay_e\@:
    .popsection
.endm
# After a compare: `<text>` + LF if condition cc holds, else `<text> BAD` + LF.
.macro CHECK cc, text
    j\cc .Lck_ok\@
    leaq .Lck_bs\@(%rip), %rdi
    movq $(.Lck_be\@ - .Lck_bs\@), %rsi
    jmp .Lck_out\@
.Lck_ok\@:
    leaq .Lck_s\@(%rip), %rdi
    movq $(.Lck_e\@ - .Lck_s\@), %rsi
.Lck_out\@:
    call sea_out_write
    .pushsection .rodata
.Lck_s\@: .ascii "\text"
    .byte 10
.Lck_e\@:
.Lck_bs\@: .ascii "\text BAD"
    .byte 10
.Lck_be\@:
    .popsection
.endm
# Append the bytes of the string object in a register (not %rdi/%rsi).
.macro PUTSTR reg
    leaq SEA_STR_BYTES(\reg), %rdi
    movq SEA_STR_LEN(\reg), %rsi
    call sea_out_write
.endm
# sea_err(code, site, slots label); noreturn.
.macro RAISE code, site, slots
    movl $\code, %edi
    movq $\site, %rsi
    leaq \slots(%rip), %rdx
    call sea_err
.endm
# sea_main's frame: %rbp, %rbx, %r12-%r15 saved, 8 bytes of locals at
# 0(%rsp); entered at %rsp = 8 (mod 16), so %rsp = 0 (mod 16) after it.
.macro PROLOGUE
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $8, %rsp
.endm
.macro EPILOGUE
    addq $8, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret
.endm
# The error-site table: site 0 is m.sea:\line.
.macro SITES line
    .pushsection .data.rel.ro,"aw",@progbits
    .p2align 3
    SSTR .Lsite_file, 5, "m.sea"
    .p2align 3
    .globl sea_sites
sea_sites:
    .quad .Lsite_file
    .quad \line
    .popsection
.endm

    .text
# putdec -- append the decimal text of %rdi (signed) to standard output.
#   Clobbers: all caller-saved registers. Frame: 8 (%rbp) + 32 bytes.
    .p2align 4
putdec:
    pushq %rbp
    movq %rsp, %rbp
    subq $32, %rsp
    leaq 32(%rsp), %r8
    movq %rdi, %rax
    xorl %r9d, %r9d
    testq %rax, %rax
    jns 1f
    negq %rax
    movl $1, %r9d
1:  movl $10, %ecx
2:  xorl %edx, %edx
    divq %rcx
    addb $48, %dl
    decq %r8
    movb %dl, (%r8)
    testq %rax, %rax
    jnz 2b
    testl %r9d, %r9d
    jz 3f
    decq %r8
    movb $45, (%r8)
3:  movq %r8, %rdi
    leaq 32(%rsp), %rsi
    subq %r8, %rsi
    call sea_out_write
    movq %rbp, %rsp
    popq %rbp
    ret
# putnl -- append a LF.
    .p2align 4
putnl:
    pushq %rbp
    movq %rsp, %rbp
    leaq .Lnl(%rip), %rdi
    movl $1, %esi
    call sea_out_write
    popq %rbp
    ret
    .pushsection .rodata
.Lnl: .byte 10
    .popsection

# The test's own write and close (the program's definitions take the place of glibc's for
# the runtime's write@PLT / close@PLT calls): each performs the system call itself and, for a
# descriptor >= 3 (the JSON file; 0-2 are the standard streams), first logs `write N` (N the
# byte count asked for) or `close` + LF on standard error with a raw write(2), so the
# expected stderr shows every write and close of the file in order.

# rawlog -- write text (%rdi, %rsi bytes, at most 30), the decimal %rdx unless it is
#   negative, and LF to fd 2 with the write system call. Frame: 8 (%rbp) + 64.
    .p2align 4
rawlog:
    pushq %rbp
    movq %rsp, %rbp
    subq $64, %rsp
    xorl %ecx, %ecx
1:  cmpq %rsi, %rcx
    jae 2f
    movb (%rdi,%rcx), %al
    movb %al, (%rsp,%rcx)
    incq %rcx
    jmp 1b
2:  testq %rdx, %rdx
    js 4f
    leaq 64(%rsp), %r8              # digits backwards from the end of the frame
    movq %rdx, %rax
    movl $10, %r9d
3:  xorl %edx, %edx
    divq %r9
    addb $48, %dl
    decq %r8
    movb %dl, (%r8)
    testq %rax, %rax
    jnz 3b
    leaq 64(%rsp), %r10
5:  cmpq %r10, %r8
    jae 4f
    movb (%r8), %al
    movb %al, (%rsp,%rcx)
    incq %rcx
    incq %r8
    jmp 5b
4:  movb $10, (%rsp,%rcx)
    incq %rcx
    movl $1, %eax                   # SYS_write
    movl $2, %edi
    movq %rsp, %rsi
    movq %rcx, %rdx
    syscall
    movq %rbp, %rsp
    popq %rbp
    ret

# sysret -- a raw system call result in %rax: -4095 .. -1 sets errno and gives -1.
#   Clobbers: caller-saved registers. Callee-saved used: %rbx (saved).
    .p2align 4
sysret:
    cmpq $-4095, %rax
    jb 1f
    pushq %rbx
    negq %rax
    movq %rax, %rbx
    call __errno_location@PLT
    movl %ebx, (%rax)
    movq $-1, %rax
    popq %rbx
1:  ret

    .globl write
    .type write, @function
    .p2align 4
write:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    subq $8, %rsp
    movl %edi, %ebx
    movq %rsi, %r12
    movq %rdx, %r13
    cmpl $3, %ebx
    jl 1f
    leaq .Lw_txt(%rip), %rdi
    movl $6, %esi
    movq %r13, %rdx
    call rawlog
1:  movl $1, %eax                   # SYS_write
    movslq %ebx, %rdi
    movq %r12, %rsi
    movq %r13, %rdx
    syscall
    call sysret
    addq $8, %rsp
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

    .globl close
    .type close, @function
    .p2align 4
close:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp
    movl %edi, %ebx
    cmpl $3, %ebx
    jl 1f
    leaq .Lc_txt(%rip), %rdi
    movl $5, %esi
    movq $-1, %rdx
    call rawlog
1:  movl $3, %eax                   # SYS_close
    movslq %ebx, %rdi
    syscall
    call sysret
    addq $8, %rsp
    popq %rbx
    popq %rbp
    ret
    .pushsection .rodata
.Lw_txt: .ascii "write "
.Lc_txt: .ascii "close"
    .popsection

    .text
    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    PROLOGUE
    SAY "begin"
    leaq .Lpath(%rip), %rdi
    xorl %esi, %esi
    call sea_json_open
    movl $1, %edi
    xorl %esi, %esi
    call sea_json_i64
    xorl %edi, %edi
    call sea_json_close
    SAY "not reached"
    EPILOGUE

    .section .data.rel.ro,"aw",@progbits
    .p2align 3
.Lpath:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 9
    .byte 47, 100, 101, 118, 47, 102, 117, 108, 108
    SITES 6
