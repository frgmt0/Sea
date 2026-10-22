# sea/tests/rt/x86_64_linux/rt_arr_unique.s -- sea_arr_unique: a count-1 array comes back unchanged; a count-2 f64 matrix is copied (header and data equal, old count 1); a static array (count 0) is copied and keeps count 0; a str[] copy retains its dynamic elements (static and null elements as they are); a struct array copy retains its reference fields; live count back to 0 (heap check)
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
# samehdr -- %rdi = original, %rsi = copy: %eax = 1 if ek, rank, rows, cols, cap,
#   esize, slay agree, the copy's data follows its header and its data bytes equal
#   the original's. Clobbers caller-saved registers.
    .p2align 4
samehdr:
    pushq %rbp
    movq %rsp, %rbp
    xorl %eax, %eax
    movb SEA_ARR_EK(%rdi), %cl
    cmpb SEA_ARR_EK(%rsi), %cl
    jne 9f
    movb SEA_ARR_RANK(%rdi), %cl
    cmpb SEA_ARR_RANK(%rsi), %cl
    jne 9f
    movq SEA_ARR_ROWS(%rdi), %rcx
    cmpq SEA_ARR_ROWS(%rsi), %rcx
    jne 9f
    movq SEA_ARR_COLS(%rdi), %rdx
    cmpq SEA_ARR_COLS(%rsi), %rdx
    jne 9f
    imulq %rdx, %rcx
    cmpq SEA_ARR_CAP(%rsi), %rcx
    jne 9f
    movq SEA_ARR_ESIZE(%rdi), %rdx
    cmpq SEA_ARR_ESIZE(%rsi), %rdx
    jne 9f
    movq SEA_ARR_SLAY(%rdi), %r8
    cmpq SEA_ARR_SLAY(%rsi), %r8
    jne 9f
    leaq SEA_ARR_SIZE(%rsi), %r8
    cmpq SEA_ARR_DATA(%rsi), %r8
    jne 9f
    imulq %rcx, %rdx                # data bytes
    movq SEA_ARR_DATA(%rdi), %rdi
    movq SEA_ARR_DATA(%rsi), %rsi
    call memcmp@PLT
    testl %eax, %eax
    sete %al
    movzbl %al, %eax
9:  popq %rbp
    ret

    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    PROLOGUE
    # 1. Count 1: the same array.
    movl $SEA_EK_I64, %edi
    movl $1, %esi
    movl $3, %edx
    movl $1, %ecx
    xorl %r8d, %r8d
    call sea_arr_new
    movq %rax, %rbx
    movq %rbx, %rdi
    xorl %esi, %esi
    call sea_arr_unique
    cmpq %rbx, %rax
    CHECK e, "count 1: same array"
    cmpq $1, SEA_ARR_RC(%rbx)
    CHECK e, "count 1: count unchanged"
    movq %rbx, %rdi
    call sea_release

    # 2. A shared f64 matrix: copied.
    movl $SEA_EK_F64, %edi
    movl $2, %esi
    movl $2, %edx
    movl $3, %ecx
    xorl %r8d, %r8d
    call sea_arr_new
    movq %rax, %rbx
    movq SEA_ARR_DATA(%rbx), %rcx
    movabsq $0x3FF8000000000000, %rax # 1.5, 2.5, ... in the six elements
    movq %rax, 0(%rcx)
    movabsq $0x4004000000000000, %rax
    movq %rax, 8(%rcx)
    movabsq $0x400C000000000000, %rax
    movq %rax, 16(%rcx)
    movabsq $0x4012000000000000, %rax
    movq %rax, 24(%rcx)
    movabsq $0x4016000000000000, %rax
    movq %rax, 32(%rcx)
    movabsq $0x401A000000000000, %rax
    movq %rax, 40(%rcx)
    incq SEA_ARR_RC(%rbx)           # count 2
    movq %rbx, %rdi
    xorl %esi, %esi
    call sea_arr_unique
    movq %rax, %r12
    cmpq %rbx, %r12
    CHECK ne, "count 2: a new array"
    cmpq $1, SEA_ARR_RC(%r12)
    CHECK e, "count 2: copy count 1"
    cmpq $1, SEA_ARR_RC(%rbx)
    CHECK e, "count 2: old count 1"
    movq %rbx, %rdi
    movq %r12, %rsi
    call samehdr
    cmpl $1, %eax
    CHECK e, "count 2: same header and data"
    movq %rbx, %rdi
    call sea_release
    movq %r12, %rdi
    call sea_release

    # 3. A static array: copied, its count stays 0.
    leaq .Lstat(%rip), %rbx
    movq %rbx, %rdi
    xorl %esi, %esi
    call sea_arr_unique
    movq %rax, %r12
    cmpq %rbx, %r12
    CHECK ne, "static: a new array"
    cmpq $1, SEA_ARR_RC(%r12)
    CHECK e, "static: copy count 1"
    cmpq $SEA_RC_STATIC, SEA_ARR_RC(%rbx)
    CHECK e, "static: count stays 0"
    movq %rbx, %rdi
    movq %r12, %rsi
    call samehdr
    cmpl $1, %eax
    CHECK e, "static: same header and data"
    movq %r12, %rdi
    call sea_release

    # 4. A shared str[]: [fresh, static, null, fresh].
    movl $SEA_EK_STR, %edi
    movl $1, %esi
    movl $4, %edx
    movl $1, %ecx
    xorl %r8d, %r8d
    call sea_arr_new
    movq %rax, %rbx
    leaq .Lsx(%rip), %rdi
    leaq .Lsx(%rip), %rsi
    xorl %edx, %edx
    call sea_str_cat
    movq SEA_ARR_DATA(%rbx), %rcx
    movq %rax, 0(%rcx)
    leaq .Lsx(%rip), %rax
    movq %rax, 8(%rcx)
    leaq .Lsx(%rip), %rdi
    leaq .Lsx(%rip), %rsi
    xorl %edx, %edx
    call sea_str_cat
    movq SEA_ARR_DATA(%rbx), %rcx
    movq %rax, 24(%rcx)
    incq SEA_ARR_RC(%rbx)           # count 2
    movq %rbx, %rdi
    xorl %esi, %esi
    call sea_arr_unique
    movq %rax, %r12
    movq %rbx, %rdi
    movq %r12, %rsi
    call samehdr
    cmpl $1, %eax
    CHECK e, "str[]: same header and elements"
    movq SEA_ARR_DATA(%r12), %rcx
    movq 0(%rcx), %rax
    cmpq $2, SEA_STR_RC(%rax)
    CHECK e, "str[]: element 0 count 2"
    movq SEA_ARR_DATA(%r12), %rcx
    movq 24(%rcx), %rax
    cmpq $2, SEA_STR_RC(%rax)
    CHECK e, "str[]: element 3 count 2"
    cmpq $SEA_RC_STATIC, .Lsx+SEA_STR_RC(%rip)
    CHECK e, "str[]: static element count 0"
    cmpq $1, SEA_ARR_RC(%rbx)
    CHECK e, "str[]: old count 1"
    movq %rbx, %rdi
    call sea_release
    movq %r12, %rdi
    call sea_release

    # 5. A shared struct array {f64 x; str s} (16 bytes, one reference
    # field at 8): [{2.5, fresh}, {0, null}].
    leaq .Lslay(%rip), %rdi
    movl $1, %esi
    movl $2, %edx
    movl $1, %ecx
    xorl %r8d, %r8d
    call sea_arr_new_s
    movq %rax, %rbx
    leaq .Lsx(%rip), %rdi
    leaq .Lsx(%rip), %rsi
    xorl %edx, %edx
    call sea_str_cat
    movq SEA_ARR_DATA(%rbx), %rcx
    movq %rax, 8(%rcx)
    movabsq $0x4004000000000000, %rax
    movq %rax, 0(%rcx)
    incq SEA_ARR_RC(%rbx)           # count 2
    movq %rbx, %rdi
    xorl %esi, %esi
    call sea_arr_unique
    movq %rax, %r12
    movq %rbx, %rdi
    movq %r12, %rsi
    call samehdr
    cmpl $1, %eax
    CHECK e, "struct: same header and elements"
    movq SEA_ARR_DATA(%r12), %rcx
    movq 8(%rcx), %rax
    cmpq $2, SEA_STR_RC(%rax)
    CHECK e, "struct: reference field count 2"
    cmpq $1, SEA_ARR_RC(%rbx)
    CHECK e, "struct: old count 1"
    movq %rbx, %rdi
    call sea_release
    movq %r12, %rdi
    call sea_release
    EPILOGUE

    .section .rodata
    SSTR .Lsx, 1, "x"
    .p2align 3
.Lslay:
    .quad 16, 1, 8
    .p2align 6
.Lstat:                             # a static f64 vector of 3: count 0, data after the header
    .quad SEA_RC_STATIC
    .byte SEA_TAG_ARRAY, SEA_EK_F64, 1, 0, 0, 0, 0, 0
    .quad 3, 1, 3, .Lstat + SEA_ARR_SIZE, SEA_ESIZE_F64, 0
    .quad 0x3FF0000000000000, 0x4000000000000000, 0x4008000000000000
    SITES 1
