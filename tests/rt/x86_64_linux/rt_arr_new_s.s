# sea/tests/rt/x86_64_linux/rt_arr_new_s.s -- sea_arr_new_s with a descriptor of two reference fields ({str a; f64 x; str b}, 24 bytes, offsets 0 and 16): the header (SEA_EK_STRUCT, esize SEA_SL_SIZE, SEA_ARR_SLAY), a zeroed buffer, and sea_free releasing the non-null reference fields (one string freed, one shared string left with count 1, null fields skipped); live count back to 0 (heap check)
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
    leaq .Lslay(%rip), %rdi
    movl $2, %esi
    movl $3, %edx
    movl $2, %ecx
    xorl %r8d, %r8d
    call sea_arr_new_s
    movq %rax, %rbx                 # a 3 x 2 struct matrix
    cmpq $1, SEA_ARR_RC(%rbx)
    CHECK e, "count 1"
    cmpb $SEA_TAG_ARRAY, SEA_ARR_TAG(%rbx)
    CHECK e, "tag array"
    cmpb $SEA_EK_STRUCT, SEA_ARR_EK(%rbx)
    CHECK e, "ek struct"
    cmpb $2, SEA_ARR_RANK(%rbx)
    CHECK e, "rank 2"
    cmpq $3, SEA_ARR_ROWS(%rbx)
    CHECK e, "rows 3"
    cmpq $2, SEA_ARR_COLS(%rbx)
    CHECK e, "cols 2"
    cmpq $6, SEA_ARR_CAP(%rbx)
    CHECK e, "cap 6"
    leaq SEA_ARR_SIZE(%rbx), %rax
    cmpq SEA_ARR_DATA(%rbx), %rax
    CHECK e, "data after the header"
    cmpq $24, SEA_ARR_ESIZE(%rbx)
    CHECK e, "esize 24"
    leaq .Lslay(%rip), %rax
    cmpq SEA_ARR_SLAY(%rbx), %rax
    CHECK e, "slay the descriptor"
    # The buffer: 6 * 24 zero bytes.
    movq SEA_ARR_DATA(%rbx), %rdi
    movl $(6*24), %ecx
    xorl %eax, %eax
1:  orb (%rdi), %al
    incq %rdi
    decl %ecx
    jnz 1b
    testb %al, %al
    CHECK z, "buffer zeroed"
    # Element 0's field a: a fresh string (count 1); element 5's field b:
    # a string the test also holds (count 2). Every other field stays null.
    leaq .Lsab(%rip), %rdi
    leaq .Lsc(%rip), %rsi
    xorl %edx, %edx
    call sea_str_cat
    movq SEA_ARR_DATA(%rbx), %rcx
    movq %rax, 0(%rcx)              # element 0, offset 0
    leaq .Lsc(%rip), %rdi
    leaq .Lsab(%rip), %rsi
    xorl %edx, %edx
    call sea_str_cat
    movq %rax, %r12                 # held by the test ...
    movq %r12, %rdi
    call sea_retain                 # ... and by the array
    movq SEA_ARR_DATA(%rbx), %rcx
    movq %r12, 5*24+16(%rcx)        # element 5, offset 16
    movq sea_live(%rip), %rdi
    call putdec                     # 3: the array and two strings
    SAY " live"
    movq %rbx, %rdi
    call sea_release                # count 0: sea_free
    movq sea_live(%rip), %rdi
    call putdec                     # 1: the shared string
    SAY " live after the release"
    cmpq $1, SEA_STR_RC(%r12)
    CHECK e, "shared string count 1"
    movq %r12, %rdi
    call sea_release
    EPILOGUE

    .section .rodata
    .p2align 3
.Lslay:                             # {str a; f64 x; str b}
    .quad 24, 2, 0, 16
    SSTR .Lsab, 2, "ab"
    SSTR .Lsc, 1, "c"
    SITES 1
