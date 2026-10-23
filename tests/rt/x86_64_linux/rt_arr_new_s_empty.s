# sea/tests/rt/x86_64_linux/rt_arr_new_s_empty.s -- sea_arr_new_s with an empty struct (descriptor SEA_SL_SIZE 0, no reference offsets; lead decision L-h): an array of 3 elements and one of 0 have esize 0, SEA_EK_STRUCT, the descriptor, the right extents and a data pointer aligned and after the header; sea_arr_unique of a shared one (count 2) gives a distinct count-1 copy with the same header; sea_free of each; live count back to 0 (heap check)
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

# LIVEOUT text: print the live-object count, then text and LF.
.macro LIVEOUT text
    movq sea_live(%rip), %rdi
    call putdec
    SAY "\text"
.endm
# EHDR reg, rows, tag: the header checks of an empty-struct vector of
# `rows` elements in reg (caller-saved registers clobbered).
.macro EHDR reg, rows, tag
    cmpq $1, SEA_ARR_RC(\reg)
    CHECK e, "\tag count 1"
    cmpb $SEA_TAG_ARRAY, SEA_ARR_TAG(\reg)
    CHECK e, "\tag tag array"
    cmpb $SEA_EK_STRUCT, SEA_ARR_EK(\reg)
    CHECK e, "\tag ek struct"
    cmpb $1, SEA_ARR_RANK(\reg)
    CHECK e, "\tag rank 1"
    cmpq $\rows, SEA_ARR_ROWS(\reg)
    CHECK e, "\tag rows"
    cmpq $1, SEA_ARR_COLS(\reg)
    CHECK e, "\tag cols 1"
    cmpq $\rows, SEA_ARR_CAP(\reg)
    CHECK e, "\tag cap"
    cmpq $0, SEA_ARR_ESIZE(\reg)
    CHECK e, "\tag esize 0"
    leaq .Lslay(%rip), %rax
    cmpq SEA_ARR_SLAY(\reg), %rax
    CHECK e, "\tag slay the descriptor"
    leaq SEA_ARR_SIZE(\reg), %rax
    cmpq SEA_ARR_DATA(\reg), %rax
    CHECK e, "\tag data after the header"
    testq $(SEA_DATA_ALIGN - 1), SEA_ARR_DATA(\reg)
    CHECK z, "\tag data aligned"
.endm

    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    PROLOGUE
    leaq .Lslay(%rip), %rdi
    movl $1, %esi
    movl $3, %edx
    movl $1, %ecx
    xorl %r8d, %r8d
    call sea_arr_new_s
    movq %rax, %rbx                 # 3 empty structs
    EHDR %rbx, 3, "three:"
    LIVEOUT " live"                 # 1
    leaq .Lslay(%rip), %rdi
    movl $1, %esi
    xorl %edx, %edx
    movl $1, %ecx
    xorl %r8d, %r8d
    call sea_arr_new_s
    movq %rax, %r12                 # no elements at all
    EHDR %r12, 0, "zero:"
    LIVEOUT " live"                 # 2
    movq $2, SEA_ARR_RC(%rbx)       # shared: count 2
    movq %rbx, %rdi
    xorl %esi, %esi
    call sea_arr_unique
    movq %rax, %r13
    cmpq %rbx, %r13
    CHECK ne, "unique: a new array"
    cmpq $1, SEA_ARR_RC(%rbx)
    CHECK e, "unique: old count 1"
    EHDR %r13, 3, "copy:"
    LIVEOUT " live"                 # 3
    movq %rbx, %rdi
    call sea_release
    LIVEOUT " live"                 # 2
    movq %r12, %rdi
    call sea_release
    LIVEOUT " live"                 # 1
    movq %r13, %rdi
    call sea_release
    LIVEOUT " live after the releases"  # 0
    EPILOGUE

    .section .rodata
    .p2align 3
.Lslay:                             # {} : size 0, no reference fields
    .quad 0, 0
    SITES 1
