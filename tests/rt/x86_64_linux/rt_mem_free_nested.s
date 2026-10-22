# sea/tests/rt/x86_64_linux/rt_mem_free_nested.s -- sea_free of a struct vector whose reference fields hold strings and str[] vectors: the release recurses into the nested vectors (fresh strings freed, a shared vector left with count 1, a static string and null fields skipped); live count back to 0 (heap check)
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
    # A struct vector of two (layout of .Lslay: s at 0, x at 8, v at 16):
    # {fresh, 0, v = str[2] [fresh, static]}, {null, 0, w = str[1] [fresh],
    # which the test also holds}.
    leaq .Lslay(%rip), %rdi
    movl $1, %esi
    movl $2, %edx
    movl $1, %ecx
    xorl %r8d, %r8d
    call sea_arr_new_s
    movq %rax, %rbx                 # the struct vector
    leaq .Lsx(%rip), %rdi
    leaq .Lsy(%rip), %rsi
    xorl %edx, %edx
    call sea_str_cat
    movq SEA_ARR_DATA(%rbx), %rcx
    movq %rax, 0(%rcx)              # element 0's s: a fresh string
    movl $SEA_EK_STR, %edi
    movl $1, %esi
    movl $2, %edx
    movl $1, %ecx
    xorl %r8d, %r8d
    call sea_arr_new
    movq %rax, %r12                 # v
    leaq .Lsy(%rip), %rdi
    leaq .Lsx(%rip), %rsi
    xorl %edx, %edx
    call sea_str_cat
    movq SEA_ARR_DATA(%r12), %rcx
    movq %rax, 0(%rcx)              # v[0]: a fresh string
    leaq .Lsx(%rip), %rax
    movq %rax, 8(%rcx)              # v[1]: the static string
    movq SEA_ARR_DATA(%rbx), %rcx
    movq %r12, 16(%rcx)             # element 0's v
    movl $SEA_EK_STR, %edi
    movl $1, %esi
    movl $1, %edx
    movl $1, %ecx
    xorl %r8d, %r8d
    call sea_arr_new
    movq %rax, %r13                 # w
    leaq .Lsx(%rip), %rdi
    leaq .Lsx(%rip), %rsi
    xorl %edx, %edx
    call sea_str_cat
    movq SEA_ARR_DATA(%r13), %rcx
    movq %rax, 0(%rcx)              # w[0]: a fresh string
    movq %r13, %rdi
    call sea_retain                 # w: held by the test and the vector
    movq SEA_ARR_DATA(%rbx), %rcx
    movq %r13, 24+16(%rcx)          # element 1's v
    movq sea_live(%rip), %rdi
    call putdec                     # 6: vector, s, v, v[0], w, w[0]
    SAY " live"
    movq %rbx, %rdi
    call sea_release                # frees the vector, s, v and v[0]
    movq sea_live(%rip), %rdi
    call putdec
    SAY " live after freeing the array"
    cmpq $1, SEA_ARR_RC(%r13)
    CHECK e, "shared str[] count 1"
    cmpq $SEA_RC_STATIC, .Lsx+SEA_STR_RC(%rip)
    CHECK e, "static string untouched"
    movq %r13, %rdi
    call sea_release                # frees w and w[0]
    movq sea_live(%rip), %rdi
    call putdec
    SAY " live at the end"
    EPILOGUE

    .section .rodata
    .p2align 3
.Lslay:                             # {str s; f64 x; str[] v}: 24 bytes, references at 0 and 16
    .quad 24, 2, 0, 16
    SSTR .Lsx, 1, "x"
    SSTR .Lsy, 2, "yy"
    SITES 1
