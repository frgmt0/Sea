# =====================================================================
# sea/tests/rt/x86_64_linux/rt_lib_lines.s -- sea_read_lines on the fixtures of
# rt_lib_lines.files/ (DESIGN.md 2.15.2, 2.15.6; L-mf, L-mg): each example of the line
# rule (LF; a CR before the LF removed; the bytes after the last LF a line with one
# final CR removed; an empty file no line; NUL, 0xFF and a UTF-8 BOM kept), printed as
# `<file>: <count>` and one `  [<len>] <bytes>` line per line (bytes outside 0x20-0x7E
# and \ as \xHH); every result checked by check_strvec (count 1, rank 1, str
# elements, each a distinct new string) and released. big.txt (200003 bytes, 855
# lines, generated) has the CR at offset 65535 and its LF at 65536 (across the first
# 65536-byte buffer) and lines across 131072 (the second doubling); it prints its count,
# the sum of the line lengths, and lines 0, 654 (the one ended by that CRLF) and 854
# (the last, without LF, its final CR removed). Expected bytes: the rule applied by
# hand (big.txt: its construction). Run under the heap check: 0 live objects.
# =====================================================================
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

# ---- test helpers (the same block in every rt_lib_* test but the errors and the KAT) ----
# A static string object (rt.inc SEA_STR_*): count SEA_RC_STATIC, tag, length, bytes.
.macro SSTR label, text
    .p2align 3
\label:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad .Lsstr_e\@ - .Lsstr_s\@
.Lsstr_s\@:
    .ascii "\text"
.Lsstr_e\@:
.endm
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
# After a compare: nothing if condition cc holds, else `BAD <text>` + LF and the
# failure count + 1 (caller-saved registers clobbered).
.macro CHECK cc, text
    j\cc .Lck_ok\@
    TXT "BAD \text\n"
    incq nbad(%rip)
.Lck_ok\@:
.endm
# The release sequence of pass 4 (DESIGN.md 4.9) on the object in a register or
# memory operand: the count drops by one unless static, sea_free at 0.
.macro REL val
    movq \val, %rdi
    movq SEA_OBJ_RC(%rdi), %rax
    testq %rax, %rax
    jz .Lrel\@
    decq %rax
    movq %rax, SEA_OBJ_RC(%rdi)
    jnz .Lrel\@
    call sea_free
.Lrel\@:
.endm
# sea_main's frame: %rbp, %rbx, %r12-%r15 saved, 56 bytes of locals at 0(%rsp)
# (entered at %rsp = 8 (mod 16), so %rsp = 0 (mod 16) after it).
.macro PROLOGUE
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $56, %rsp
.endm
.macro EPILOGUE
    addq $56, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret
.endm

    .bss
    .p2align 3
nbad:   .zero 8                     # the number of failed checks
    .text
# put_dec -- append %rdi in signed decimal. Frame: 8 (%rbp) + 32 bytes of digits.
    .p2align 4
put_dec:
    pushq %rbp
    movq %rsp, %rbp
    subq $32, %rsp
    leaq 32(%rsp), %r8
    movq %rdi, %rax
    xorl %r9d, %r9d
    testq %rax, %rax
    jns 1f
    negq %rax                       # magnitude (2^63 exact as unsigned)
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

# put_esc -- append a string object's (%rdi) bytes: 0x20-0x7E but \ as they are,
# every other byte as \xHH (lowercase). Callee-saved used: %rbx = cursor, %r12 =
# end. Frame: 32 bytes (%rbp %rbx %r12 + 8 pad) + 16 bytes of text.
    .p2align 4
put_esc:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    subq $16, %rsp
    leaq SEA_STR_BYTES(%rdi), %rbx
    movq SEA_STR_LEN(%rdi), %r12
    addq %rbx, %r12
1:  cmpq %r12, %rbx
    je 3f
    movzbl (%rbx), %eax
    cmpl $92, %eax                  # '\' is escaped
    je 2f
    leal -32(%rax), %ecx
    cmpl $94, %ecx
    ja 2f                           # outside 0x20-0x7E
    movb %al, (%rsp)
    movq %rsp, %rdi
    movl $1, %esi
    call sea_out_write
    incq %rbx
    jmp 1b
2:  movb $92, (%rsp)                # \xHH
    movb $120, 1(%rsp)
    leaq .Lhexdig(%rip), %rcx
    movl %eax, %edx
    shrl $4, %edx
    movb (%rcx,%rdx), %dl
    movb %dl, 2(%rsp)
    andl $15, %eax
    movb (%rcx,%rax), %al
    movb %al, 3(%rsp)
    movq %rsp, %rdi
    movl $4, %esi
    call sea_out_write
    incq %rbx
    jmp 1b
3:  addq $16, %rsp
    popq %r12
    popq %rbx
    popq %rbp
    ret
    .pushsection .rodata
.Lhexdig: .ascii "0123456789abcdef"
    .popsection

# check_strvec -- check a str[] result (%rdi): count 1, SEA_TAG_ARRAY, element
# kind str, rank 1, cols 1; every element non-null, count 1, SEA_TAG_STR,
# header bytes 9-15 zero, distinct from every other element and from the
# objects at %rsi and %rdx (the arguments; 0 for none). A failure prints BAD.
# Callee-saved used: %rbx = the vector, %r12 = i, %r13 = j, %r14 = arg 1,
# %r15 = arg 2. Frame: 48 bytes + 8 pad.
    .p2align 4
check_strvec:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $8, %rsp
    movq %rdi, %rbx
    movq %rsi, %r14
    movq %rdx, %r15
    cmpq $1, SEA_ARR_RC(%rbx)
    CHECK e, "vector count 1"
    cmpb $SEA_TAG_ARRAY, SEA_ARR_TAG(%rbx)
    CHECK e, "vector tag"
    cmpb $SEA_EK_STR, SEA_ARR_EK(%rbx)
    CHECK e, "vector element kind str"
    cmpb $1, SEA_ARR_RANK(%rbx)
    CHECK e, "vector rank 1"
    cmpq $1, SEA_ARR_COLS(%rbx)
    CHECK e, "vector cols 1"
    xorl %r12d, %r12d
1:  cmpq SEA_ARR_ROWS(%rbx), %r12
    jae 4f
    movq SEA_ARR_DATA(%rbx), %rax
    movq (%rax,%r12,8), %rcx
    testq %rcx, %rcx
    CHECK nz, "element non-null"
    movq SEA_ARR_DATA(%rbx), %rax
    movq (%rax,%r12,8), %rcx
    testq %rcx, %rcx
    jz 3f
    cmpq $1, SEA_STR_RC(%rcx)
    CHECK e, "element count 1"
    movq SEA_ARR_DATA(%rbx), %rax
    movq (%rax,%r12,8), %rcx
    movq SEA_STR_TAG(%rcx), %rdx
    cmpq $SEA_TAG_STR, %rdx
    CHECK e, "element tag str, bytes 9-15 zero"
    movq SEA_ARR_DATA(%rbx), %rax
    movq (%rax,%r12,8), %rcx
    cmpq %r14, %rcx
    CHECK ne, "element is not argument 1"
    movq SEA_ARR_DATA(%rbx), %rax
    movq (%rax,%r12,8), %rcx
    cmpq %r15, %rcx
    CHECK ne, "element is not argument 2"
    leaq 1(%r12), %r13              # distinct from every later element
2:  cmpq SEA_ARR_ROWS(%rbx), %r13
    jae 3f
    movq SEA_ARR_DATA(%rbx), %rax
    movq (%rax,%r12,8), %rcx
    cmpq (%rax,%r13,8), %rcx
    CHECK ne, "elements distinct"
    incq %r13
    jmp 2b
3:  incq %r12
    jmp 1b
4:  addq $8, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

# put_strvec -- append a str[] (%rdi): `<rows>` LF, then per element two
# spaces, `[<len>] `, the escaped bytes, LF. Callee-saved used: %rbx = the
# vector, %r12 = i. Frame: 24 bytes + 8 pad.
    .p2align 4
put_strvec:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    movq %rdi, %rbx
    movq SEA_ARR_ROWS(%rbx), %rdi
    call put_dec
    TXT "\n"
    xorl %r12d, %r12d
1:  cmpq SEA_ARR_ROWS(%rbx), %r12
    jae 2f
    TXT "  ["
    movq SEA_ARR_DATA(%rbx), %rax
    movq (%rax,%r12,8), %rax
    movq SEA_STR_LEN(%rax), %rdi
    call put_dec
    TXT "] "
    movq SEA_ARR_DATA(%rbx), %rax
    movq (%rax,%r12,8), %rdi
    call put_esc
    TXT "\n"
    incq %r12
    jmp 1b
2:  popq %r12
    popq %rbx
    popq %rbp
    ret

# finish -- append `checks: ok` or `checks: <n> BAD` and LF.
    .p2align 4
finish:
    pushq %rbp
    movq %rsp, %rbp
    cmpq $0, nbad(%rip)
    jne 1f
    TXT "checks: ok\n"
    popq %rbp
    ret
1:  TXT "checks: "
    movq nbad(%rip), %rdi
    call put_dec
    TXT " BAD\n"
    popq %rbp
    ret
# ---- end of the test helpers ----


# read_show path_label: read_lines(path, site 0), print `<path>: ` and the vector,
# check it, release it (caller-saved registers clobbered; %rbx used).
.macro READ_SHOW path
    leaq \path(%rip), %rdi
    leaq SEA_STR_BYTES(%rdi), %rdi
    movq \path+SEA_STR_LEN(%rip), %rsi
    call sea_out_write
    TXT ": "
    leaq \path(%rip), %rdi
    xorl %esi, %esi
    call sea_read_lines
    movq %rax, %rbx
    movq %rbx, %rdi
    call put_strvec
    movq %rbx, %rdi
    leaq \path(%rip), %rsi
    xorl %edx, %edx
    call check_strvec
    REL %rbx
.endm
# show_line k: `  line <k>: [<len>] <bytes>` of the vector in %rbx.
.macro SHOW_LINE k
    TXT "  line \k: ["
    movq SEA_ARR_DATA(%rbx), %rax
    movq \k*8(%rax), %rax
    movq SEA_STR_LEN(%rax), %rdi
    call put_dec
    TXT "] "
    movq SEA_ARR_DATA(%rbx), %rax
    movq \k*8(%rax), %rdi
    call put_esc
    TXT "\n"
.endm

    .text
    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    PROLOGUE
    READ_SHOW .Lp0
    READ_SHOW .Lp1
    READ_SHOW .Lp2
    READ_SHOW .Lp3
    READ_SHOW .Lp4
    READ_SHOW .Lp5
    READ_SHOW .Lp6
    READ_SHOW .Lp7
    READ_SHOW .Lp8
    READ_SHOW .Lp9
    READ_SHOW .Lp10
    READ_SHOW .Lp11
    READ_SHOW .Lp12
    READ_SHOW .Lp13
    READ_SHOW .Lp14
    READ_SHOW .Lp15
    READ_SHOW .Lp16
    # big.txt: the count, the sum of the lengths, three lines.
    TXT "big.txt: "
    leaq .Lpbig(%rip), %rdi
    xorl %esi, %esi
    call sea_read_lines
    movq %rax, %rbx
    movq SEA_ARR_ROWS(%rbx), %rdi
    call put_dec
    TXT "\n  sum "
    xorl %r12d, %r12d               # the element index
    xorl %r13d, %r13d               # the sum of the lengths
1:  cmpq SEA_ARR_ROWS(%rbx), %r12
    jae 2f
    movq SEA_ARR_DATA(%rbx), %rax
    movq (%rax,%r12,8), %rax
    addq SEA_STR_LEN(%rax), %r13
    incq %r12
    jmp 1b
2:  movq %r13, %rdi
    call put_dec
    TXT "\n"
    SHOW_LINE 0
    SHOW_LINE 654
    SHOW_LINE 854
    movq %rbx, %rdi
    leaq .Lpbig(%rip), %rsi
    xorl %edx, %edx
    call check_strvec
    REL %rbx
    call finish
    EPILOGUE

    .section .data.rel.ro,"aw",@progbits
    SSTR .Lp0, "l01.txt"
    SSTR .Lp1, "l02.txt"
    SSTR .Lp2, "l03.txt"
    SSTR .Lp3, "l04.txt"
    SSTR .Lp4, "l05.txt"
    SSTR .Lp5, "l06.txt"
    SSTR .Lp6, "l07.txt"
    SSTR .Lp7, "l08.txt"
    SSTR .Lp8, "l09.txt"
    SSTR .Lp9, "l10.txt"
    SSTR .Lp10, "l11.txt"
    SSTR .Lp11, "l12.txt"
    SSTR .Lp12, "l13.txt"
    SSTR .Lp13, "l14.txt"
    SSTR .Lp14, "l15.txt"
    SSTR .Lp15, "l16.txt"
    SSTR .Lp16, "l17.txt"
    SSTR .Lpbig, "big.txt"
    SSTR .Lfile, "m.sea"
    .p2align 3
    .globl sea_sites
sea_sites:
    .quad .Lfile, 1                 # site 0

    .section .note.GNU-stack,"",@progbits
