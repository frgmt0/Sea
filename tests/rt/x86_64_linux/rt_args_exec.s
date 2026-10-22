# sea/tests/rt/x86_64_linux/rt_args_exec.s -- sea_args of real command-line arguments: started without arguments, the program runs itself again (execv(argv[0])) with "alpha", "", "two words", "3"; then the argc main saved (5) and the str[] of the four arguments in order; live count back to 0 (heap check)
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

    .text
    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    PROLOGUE
    subq $48, %rsp                  # a new argv for the re-exec (6 pointers)
    # Started without arguments (the runner passes none): run this program
    # again with the arguments of .Largs (execv returns only on failure).
    cmpq $1, sea_argc(%rip)
    jne .Lhave
    movq sea_argv(%rip), %rax
    movq (%rax), %rbx               # argv[0]: the program's path
    movq %rbx, (%rsp)
    leaq .Largs(%rip), %rcx
    movl $1, %edx
1:  movq (%rcx), %rax               # the arguments, then NULL
    movq %rax, (%rsp,%rdx,8)
    addq $8, %rcx
    incq %rdx
    testq %rax, %rax
    jnz 1b
    movq %rbx, %rdi
    movq %rsp, %rsi
    call execv@PLT
    SAY "exec failed"
    jmp .Ldone
.Lhave:
    PUT .Largc, 5                   # the argc main saved
    movq sea_argc(%rip), %rdi
    call putdec
    call putnl
    xorl %edi, %edi                 # site 0
    call sea_args
    movq %rax, %rbx
    movq SEA_ARR_ROWS(%rbx), %rdi
    call putdec
    SAY " arguments"
    xorl %r12d, %r12d
2:  cmpq SEA_ARR_ROWS(%rbx), %r12
    jae 3f
    movq SEA_ARR_DATA(%rbx), %rax
    movq (%rax,%r12,8), %r13
    PUT .Llb, 1
    PUTSTR %r13                     # [bytes]
    PUT .Lrb, 1
    cmpq $1, SEA_STR_RC(%r13)
    CHECK e, " count 1"
    incq %r12
    jmp 2b
3:  movq %rbx, %rdi
    call sea_release
.Ldone:
    addq $48, %rsp
    EPILOGUE

    .section .rodata
.Largc: .ascii "argc "
.Llb: .ascii "["
.Lrb: .ascii "]"
.La0: .asciz "alpha"
.La1: .asciz ""
.La2: .asciz "two words"
.La3: .asciz "3"
    .section .data.rel.ro,"aw",@progbits
    .p2align 3
.Largs:
    .quad .La0, .La1, .La2, .La3, 0
    SITES 1
