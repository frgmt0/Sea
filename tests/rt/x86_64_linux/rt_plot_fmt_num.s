# sea/tests/rt/x86_64_linux/rt_plot_fmt_num.s -- the private sea_fmt_num of rt_fmt.s (DESIGN.md 2.14.6 "Notation", L-ld): one finite f64 under %.<p>f or %.<p>g as C prints it: %.2f of +0, -0 and -0.001 (a pure C conversion: -0.00, the sign is the caller's business), 1e5, 123.456, 2.675 and -2e5; %.{p}f with p = 0 .. 4 and a tie; %g of 1e6, 1e-5, 1e-4, 123456789, 1.000002, -2.5e-7 and 0; %.7g, %.17g and %.12g (Decision 142's widths); and the longest text, %.4f of -DBL_MAX (315 bytes), with the NUL after the text and no byte written past the 352-byte destination. Each line: `<letter><precision> <text> <length>`.
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

# ---- test helpers (the same block in every rt_plot test that prints) --
# Append a literal text (caller-saved registers clobbered).
.macro TXT text
    leaq .Ltxt_s\@(%rip), %rdi
    movq $(.Ltxt_e\@ - .Ltxt_s\@), %rsi
    call sea_out_write
    .pushsection .rodata
.Ltxt_s\@: .ascii "\text"
.Ltxt_e\@:
    .popsection
.endm
# The release sequence of pass 4 (DESIGN.md 4.9) on the object in reg
# (not %rdi): the count drops by one unless static, sea_free at 0
# (caller-saved registers clobbered).
.macro REL reg
    movq \reg, %rdi
    movq (%rdi), %rax
    testq %rax, %rax
    jz .Lrel\@
    decq %rax
    movq %rax, (%rdi)
    jnz .Lrel\@
    call sea_free
.Lrel\@:
.endm
# A function frame: %rbp, %rbx, %r12-%r15 saved, 8 bytes of locals at
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
# A static string object (count SEA_RC_STATIC).
.macro SSTR label, text
    .p2align 3
\label:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad .Lsse\@ - .Lsss\@
.Lsss\@: .ascii "\text"
.Lsse\@:
.endm
# A static dynamic f64 vector of n elements (count SEA_RC_STATIC); its
# elements follow the header.
.macro VEC name, n
    .p2align 6
\name:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_ARRAY, SEA_EK_F64, 1, 0, 0, 0, 0, 0
    .quad \n, 1, \n, \name + SEA_ARR_SIZE, 8, 0
.endm

    .text
# putdec -- append the decimal text of %rdi (signed).
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

# puthexn -- append the low %esi hexadecimal digits of %rdi, upper case
#   (16 for f64 bits, 6 for a colour). Clobbers caller-saved registers.
#   Frame: 8 (%rbp) + 16 bytes.
    .p2align 4
puthexn:
    pushq %rbp
    movq %rsp, %rbp
    subq $16, %rsp
    movl %esi, %ecx
    movl %esi, %r9d
1:  movl %edi, %eax
    andl $15, %eax
    leal 48(%rax), %edx
    leal 55(%rax), %r8d
    cmpl $10, %eax
    cmovael %r8d, %edx
    decl %ecx
    movb %dl, (%rsp,%rcx)
    shrq $4, %rdi
    testl %ecx, %ecx
    jnz 1b
    movq %rsp, %rdi
    movl %r9d, %esi
    call sea_out_write
    movq %rbp, %rsp
    popq %rbp
    ret
# ---- end of the test helpers ------------------------------------------

# ---- the test ---------------------------------------------------------
.equ NUMDST, 352                    # sea_fmt_num's destination size (rt_fmt.s)
.equ CANARY, 0x5A                   # the bytes after the destination
    .bss
    .p2align 4
dst:    .zero NUMDST + 16
    .text
    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    PROLOGUE
    leaq cases(%rip), %rbx
1:  movzbl (%rbx), %eax
    testl %eax, %eax
    jz 9f
    leaq dst(%rip), %rdi            # the destination: canary bytes everywhere
    movl $CANARY, %eax
    movl $(NUMDST + 16), %ecx
    cld
    rep stosb
    leaq dst(%rip), %rdi
    movzbl (%rbx), %esi             # letter
    movq 8(%rbx), %rdx              # precision
    movsd 16(%rbx), %xmm0           # x
    call sea_fmt_num
    movq %rax, %r12                 # the length
    leaq 0(%rbx), %rdi              # `<letter><precision> `
    movl $1, %esi
    call sea_out_write
    movq 8(%rbx), %rdi
    call putdec
    TXT " "
    leaq dst(%rip), %rdi            # the text
    movq %r12, %rsi
    call sea_out_write
    TXT " "
    movq %r12, %rdi
    call putdec
    leaq dst(%rip), %rax            # the NUL after the text, the canary after the destination
    cmpb $0, (%rax,%r12)
    jne 2f
    xorl %ecx, %ecx
3:  cmpb $CANARY, (NUMDST)(%rax,%rcx)
    jne 2f
    incq %rcx
    cmpq $16, %rcx
    jb 3b
    TXT "\n"
    addq $24, %rbx
    jmp 1b
2:  TXT " BAD\n"
    addq $24, %rbx
    jmp 1b
9:  EPILOGUE
    .size sea_main, . - sea_main

    .section .rodata
    .p2align 3
cases:                              # letter, precision, x (bits)
    .quad 'f', 2, 0x0000000000000000 # 0
    .quad 'f', 2, 0x8000000000000000 # -0
    .quad 'f', 2, 0xBF50624DD2F1A9FC # -0.001
    .quad 'f', 2, 0x40F86A0000000000 # 1e5
    .quad 'f', 2, 0x405EDD2F1A9FBE77 # 123.456
    .quad 'f', 2, 0x4005666666666666 # 2.675 (2.67499999999999982236431605997495353221893310546875)
    .quad 'f', 2, 0xC1086A0000000000 # -2e5 (the lower clamp of a coordinate, -2P is never written)
    .quad 'f', 0, 0x400921F9F01B866E # 3.14159
    .quad 'f', 1, 0x400921F9F01B866E
    .quad 'f', 2, 0x400921F9F01B866E
    .quad 'f', 3, 0x400921F9F01B866E
    .quad 'f', 4, 0x400921F9F01B866E
    .quad 'f', 0, 0x4004000000000000 # 2.5: a tie, to even
    .quad 'g', 6, 0x412E848000000000 # 1e6
    .quad 'g', 6, 0x3EE4F8B588E368F1 # 1e-5
    .quad 'g', 6, 0x3F1A36E2EB1C432D # 1e-4
    .quad 'g', 6, 0x419D6F3454000000 # 123456789
    .quad 'g', 6, 0x3FF0000218DEF417 # 1.000002
    .quad 'g', 6, 0xBE90C6F7A0B5ED8D # -2.5e-7
    .quad 'g', 6, 0x0000000000000000 # 0
    .quad 'g', 7, 0x3FF0000218DEF417 # 1.000002
    .quad 'g', 17, 0x3FB999999999999A # 0.1
    .quad 'g', 17, 0x3FD5555555555555 # 1/3
    .quad 'g', 12, 0x426D1A9E2B680000 # 1e12 + 5e6
    .quad 'f', 4, 0xFFEFFFFFFFFFFFFF # -DBL_MAX: the longest text, 315 bytes
    .quad 0
    .section .data.rel.ro,"aw",@progbits
    .p2align 3
    .globl sea_sites
sea_sites:
    .quad .Lsite_file
    .quad 1
.Lsite_file:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 8
    .ascii "plot.sea"

    .section .note.GNU-stack,"",@progbits
