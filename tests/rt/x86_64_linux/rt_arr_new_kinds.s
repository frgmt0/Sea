# sea/tests/rt/x86_64_linux/rt_arr_new_kinds.s -- sea_arr_new of each element kind and both ranks with zero, one and many elements: every header field, a zeroed buffer (also in a recycled block whose buffer was dirtied), and the live count back to 0 (heap check)
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

# A case: ek, rank, rows, cols, the expected esize, the label and its length.
.equ E_EK,      0
.equ E_RANK,    8
.equ E_ROWS,    16
.equ E_COLS,    24
.equ E_ESIZE,   32
.equ E_LBL,     40
.equ E_LLEN,    48
.equ E_SIZE,    56
.macro CASE ek, rank, rows, cols, esize, text
    .pushsection .data.rel.ro,"aw",@progbits
    .quad \ek, \rank, \rows, \cols, \esize, .Lcl\@, .Lcle\@ - .Lcl\@
    .popsection
    .pushsection .rodata
.Lcl\@: .ascii "\text"
.Lcle\@:
    .popsection
.endm

    .text
# checkarr -- %rdi = the array, %rsi = its case, %edx = 1 to check that
#   the buffer is all zero bytes. %eax = 1 if every field is right.
#   Leaf; clobbers %rax %rcx %r8 %r9.
    .p2align 4
checkarr:
    xorl %eax, %eax
    cmpq $1, SEA_ARR_RC(%rdi)
    jne 9f
    cmpb $SEA_TAG_ARRAY, SEA_ARR_TAG(%rdi)
    jne 9f
    movzbl SEA_ARR_EK(%rdi), %ecx
    cmpq E_EK(%rsi), %rcx
    jne 9f
    movzbl SEA_ARR_RANK(%rdi), %ecx
    cmpq E_RANK(%rsi), %rcx
    jne 9f
    cmpl $0, SEA_ARR_RANK+1(%rdi)   # bytes 11 .. 14
    jne 9f
    cmpb $0, SEA_ARR_RANK+5(%rdi)   # byte 15
    jne 9f
    movq SEA_ARR_ROWS(%rdi), %rcx
    cmpq E_ROWS(%rsi), %rcx
    jne 9f
    movq SEA_ARR_COLS(%rdi), %r8
    cmpq E_COLS(%rsi), %r8
    jne 9f
    imulq %r8, %rcx                 # rows * cols
    cmpq SEA_ARR_CAP(%rdi), %rcx
    jne 9f
    leaq SEA_ARR_SIZE(%rdi), %r8
    cmpq SEA_ARR_DATA(%rdi), %r8    # data right after the header
    jne 9f
    testq $(SEA_DATA_ALIGN - 1), %r8
    jnz 9f
    movq SEA_ARR_ESIZE(%rdi), %r9
    cmpq E_ESIZE(%rsi), %r9
    jne 9f
    cmpq $0, SEA_ARR_SLAY(%rdi)
    jne 9f
    testl %edx, %edx
    jz 8f
    imulq %r9, %rcx                 # bytes of the buffer
1:  testq %rcx, %rcx
    jz 8f
    cmpb $0, (%r8)
    jne 9f
    incq %r8
    decq %rcx
    jmp 1b
8:  movl $1, %eax
9:  ret

    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    PROLOGUE
    movl $2, %r15d                  # two passes: the second gets recycled, dirtied blocks
.Lpass:
    leaq .Ltab(%rip), %r12
    movl $((.Ltab_end - .Ltab) / E_SIZE), %r13d
.Lcase:
    movl E_EK(%r12), %edi
    movl E_RANK(%r12), %esi
    movq E_ROWS(%r12), %rdx
    movq E_COLS(%r12), %rcx
    xorl %r8d, %r8d                 # site 0
    call sea_arr_new
    movq %rax, %rbx
    movq %rbx, %rdi
    movq %r12, %rsi
    movl $1, %edx
    call checkarr
    movl %eax, %r14d
    movq E_LBL(%r12), %rdi
    movq E_LLEN(%r12), %rsi
    call sea_out_write
    testl %r14d, %r14d
    jz 1f
    PUT .Lok, 4
    jmp 2f
1:  PUT .Lbad, 5
2:  # Free it, then dirty its buffer bytes (the block is on a free list:
    # only its first word is the list link), so that the next allocation
    # of the class gets a block that is not clean.
    movq SEA_ARR_CAP(%rbx), %r14
    imulq SEA_ARR_ESIZE(%rbx), %r14
    movq %rbx, %rdi
    call sea_release
    leaq SEA_ARR_SIZE(%rbx), %rdi
    movl $0xFF, %esi
    movq %r14, %rdx
    call memset@PLT
    addq $E_SIZE, %r12
    decl %r13d
    jnz .Lcase
    decl %r15d
    jnz .Lpass
    EPILOGUE

    .section .rodata
.Lok:  .ascii " ok\n"
.Lbad: .ascii " BAD\n"
    .section .data.rel.ro,"aw",@progbits
    .p2align 3
.Ltab:
    CASE SEA_EK_F64, 1, 0, 1, SEA_ESIZE_F64, "f64 vector 0"
    CASE SEA_EK_F64, 1, 1, 1, SEA_ESIZE_F64, "f64 vector 1"
    CASE SEA_EK_F64, 1, 100, 1, SEA_ESIZE_F64, "f64 vector 100"
    CASE SEA_EK_F64, 2, 3, 0, SEA_ESIZE_F64, "f64 matrix 3x0"
    CASE SEA_EK_F64, 2, 1, 1, SEA_ESIZE_F64, "f64 matrix 1x1"
    CASE SEA_EK_F64, 2, 7, 5, SEA_ESIZE_F64, "f64 matrix 7x5"
    CASE SEA_EK_I64, 1, 0, 1, SEA_ESIZE_I64, "i64 vector 0"
    CASE SEA_EK_I64, 1, 1, 1, SEA_ESIZE_I64, "i64 vector 1"
    CASE SEA_EK_I64, 1, 100, 1, SEA_ESIZE_I64, "i64 vector 100"
    CASE SEA_EK_I64, 2, 0, 3, SEA_ESIZE_I64, "i64 matrix 0x3"
    CASE SEA_EK_I64, 2, 1, 1, SEA_ESIZE_I64, "i64 matrix 1x1"
    CASE SEA_EK_I64, 2, 7, 5, SEA_ESIZE_I64, "i64 matrix 7x5"
    CASE SEA_EK_BOOL, 1, 0, 1, SEA_ESIZE_BOOL, "bool vector 0"
    CASE SEA_EK_BOOL, 1, 1, 1, SEA_ESIZE_BOOL, "bool vector 1"
    CASE SEA_EK_BOOL, 1, 100, 1, SEA_ESIZE_BOOL, "bool vector 100"
    CASE SEA_EK_BOOL, 2, 3, 0, SEA_ESIZE_BOOL, "bool matrix 3x0"
    CASE SEA_EK_BOOL, 2, 1, 1, SEA_ESIZE_BOOL, "bool matrix 1x1"
    CASE SEA_EK_BOOL, 2, 7, 5, SEA_ESIZE_BOOL, "bool matrix 7x5"
    CASE SEA_EK_STR, 1, 0, 1, SEA_ESIZE_PTR, "str vector 0"
    CASE SEA_EK_STR, 1, 1, 1, SEA_ESIZE_PTR, "str vector 1"
    CASE SEA_EK_STR, 1, 100, 1, SEA_ESIZE_PTR, "str vector 100"
    CASE SEA_EK_STR, 2, 0, 3, SEA_ESIZE_PTR, "str matrix 0x3"
    CASE SEA_EK_STR, 2, 1, 1, SEA_ESIZE_PTR, "str matrix 1x1"
    CASE SEA_EK_STR, 2, 7, 5, SEA_ESIZE_PTR, "str matrix 7x5"
.Ltab_end:
    SITES 1
