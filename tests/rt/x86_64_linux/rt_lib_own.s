# =====================================================================
# sea/tests/rt/x86_64_linux/rt_lib_own.s -- ownership of the text entries (DESIGN.md
# 2.15.5, 2.15.6, 2.15.8 "Runtime tests"; L-mh, L-mk, L-mq): every argument borrowed
# (dynamic count-1 strings made with sea_str_make, their count and bytes unchanged
# after the call), every result owned and new: sea_split's and sea_read_lines's vectors
# count 1, rank 1, str elements each a distinct new string (count 1) that is no
# argument, also for a single field equal to s; sea_substr a new string also for the
# whole of s and for an empty range (lo = hi, lo > hi out of range); two reads of one
# file give independent vectors; sea_parse_i64 and sea_parse_f64 make no object; after
# every release the live count is back to its start (and 0 at exit: heap check).
# The splits are DESIGN.md 2.15.2's examples plus a separator longer than s, equal to s,
# and a multi-byte separator with a partial match at the end. Expected bytes: by hand
# from 2.15.2. Fixture: rt_lib_own.files/in.txt.
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

# same_str -- %rax = 0 when the string objects %rdi and %rsi hold the same bytes.
# Callee-saved used: %rbx, %r12. Frame: 24 bytes + 8 pad.
    .p2align 4
same_str:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    movq %rdi, %rbx
    movq %rsi, %r12
    movl $1, %eax
    movq SEA_STR_LEN(%rbx), %rdx
    cmpq SEA_STR_LEN(%r12), %rdx
    jne 1f
    leaq SEA_STR_BYTES(%rbx), %rdi
    leaq SEA_STR_BYTES(%r12), %rsi
    call memcmp@PLT
    movslq %eax, %rax
1:  popq %r12
    popq %rbx
    popq %rbp
    ret

# dyn -- a new dynamic copy (count 1) of the static string %rdi (sea_str_make).
    .p2align 4
dyn:
    pushq %rbp
    movq %rsp, %rbp
    movq SEA_STR_LEN(%rdi), %rsi
    leaq SEA_STR_BYTES(%rdi), %rdi
    xorl %edx, %edx                 # site 0
    call sea_str_make
    popq %rbp
    ret

# untouched -- check that the dynamic argument %rdi still has count 1 and the
# bytes of the static original %rsi. Callee-saved used: %rbx, %r12.
    .p2align 4
untouched:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    movq %rdi, %rbx
    movq %rsi, %r12
    cmpq $1, SEA_STR_RC(%rbx)
    CHECK e, "argument count unchanged"
    movq %rbx, %rdi
    movq %r12, %rsi
    call same_str
    testq %rax, %rax
    CHECK z, "argument bytes unchanged"
    popq %r12
    popq %rbx
    popq %rbp
    ret

# SPLIT_CASE s, sep: dynamic copies of the two statics, split, `split <s> <sep>: `
# and the vector; the vector checked (new distinct elements, none an argument), the
# arguments checked untouched; everything released.
.macro SPLIT_CASE s, sep
    leaq \s(%rip), %rdi
    call dyn
    movq %rax, %r12
    leaq \sep(%rip), %rdi
    call dyn
    movq %rax, %r13
    TXT "split ["
    movq %r12, %rdi
    call put_esc
    TXT "] ["
    movq %r13, %rdi
    call put_esc
    TXT "]: "
    movq %r12, %rdi
    movq %r13, %rsi
    xorl %edx, %edx
    call sea_split
    movq %rax, %rbx
    movq %rbx, %rdi
    call put_strvec
    movq %rbx, %rdi
    movq %r12, %rsi
    movq %r13, %rdx
    call check_strvec
    movq %r12, %rdi
    leaq \s(%rip), %rsi
    call untouched
    movq %r13, %rdi
    leaq \sep(%rip), %rsi
    call untouched
    REL %rbx
    REL %r12
    REL %r13
.endm

# SUBSTR_CASE s, lo, hi: `substr <s> <lo> <hi>: [<len>] <bytes>`; the result a new
# string (count 1, not the argument), the argument untouched; both released.
.macro SUBSTR_CASE s, lo, hi
    leaq \s(%rip), %rdi
    call dyn
    movq %rax, %r12
    TXT "substr ["
    movq %r12, %rdi
    call put_esc
    TXT "] \lo \hi: ["
    movq %r12, %rdi
    movq $\lo, %rsi
    movq $\hi, %rdx
    xorl %ecx, %ecx
    call sea_substr
    movq %rax, %rbx
    movq SEA_STR_LEN(%rbx), %rdi
    call put_dec
    TXT "] "
    movq %rbx, %rdi
    call put_esc
    TXT "\n"
    cmpq $1, SEA_STR_RC(%rbx)
    CHECK e, "substr count 1"
    movq SEA_STR_TAG(%rbx), %rax
    cmpq $SEA_TAG_STR, %rax
    CHECK e, "substr tag str, bytes 9-15 zero"
    cmpq %r12, %rbx
    CHECK ne, "substr is not the argument"
    movq %r12, %rdi
    leaq \s(%rip), %rsi
    call untouched
    REL %rbx
    REL %r12
.endm

    .text
    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    PROLOGUE
    movq sea_live(%rip), %rax
    movq %rax, 0(%rsp)              # the live count at the start
    SPLIT_CASE .Ls_aeeb, .Lcomma
    SPLIT_CASE .Ls_cac, .Lcomma
    SPLIT_CASE .Le, .Lcomma
    SPLIT_CASE .Ls_abc, .Lcomma
    SPLIT_CASE .Ls_aaa, .Ls_aa
    SPLIT_CASE .Ls_acc, .Lcc
    SPLIT_CASE .Ls_ab, .Ls_abc
    SPLIT_CASE .Ls_ab, .Ls_ab
    SPLIT_CASE .Ls_part, .Ldash2
    SPLIT_CASE .Lcomma, .Lcomma
    SPLIT_CASE .Ls_aaaa, .Ls_aa
    SUBSTR_CASE .Ls_paren, 1, 4
    SUBSTR_CASE .Ls_hello, 0, 5
    SUBSTR_CASE .Ls_hello, 4, 5
    SUBSTR_CASE .Ls_hello, 0, 1
    SUBSTR_CASE .Ls_hello, 2, 2
    SUBSTR_CASE .Ls_hello, 9, 2
    SUBSTR_CASE .Ls_hello, -5, -9
    SUBSTR_CASE .Le, 0, 0
    SUBSTR_CASE .Le, 3, -3
    # read_lines: the path argument untouched, a new vector.
    leaq .Lpath(%rip), %rdi
    call dyn
    movq %rax, %r12
    TXT "read_lines [in.txt]: "
    movq %r12, %rdi
    xorl %esi, %esi
    call sea_read_lines
    movq %rax, %rbx
    movq %rbx, %rdi
    call put_strvec
    movq %rbx, %rdi
    movq %r12, %rsi
    xorl %edx, %edx
    call check_strvec
    movq %r12, %rdi
    leaq .Lpath(%rip), %rsi
    call untouched
    REL %rbx
    # read_lines twice: two independent vectors (distinct, each count 1).
    movq %r12, %rdi
    xorl %esi, %esi
    call sea_read_lines
    movq %rax, %rbx
    movq %r12, %rdi
    xorl %esi, %esi
    call sea_read_lines
    movq %rax, %r13
    cmpq %rbx, %r13
    CHECK ne, "two reads give two vectors"
    movq SEA_ARR_DATA(%rbx), %rax
    movq SEA_ARR_DATA(%r13), %rcx
    movq (%rax), %rax
    cmpq (%rcx), %rax
    CHECK ne, "two reads give two first strings"
    movq %rbx, %rdi
    xorl %esi, %esi
    xorl %edx, %edx
    call check_strvec
    movq %r13, %rdi
    xorl %esi, %esi
    xorl %edx, %edx
    call check_strvec
    REL %rbx
    REL %r13
    REL %r12
    # parse_i64 and parse_f64: the argument untouched, nothing allocated.
    leaq .Ls_num(%rip), %rdi
    call dyn
    movq %rax, %r12
    movq sea_live(%rip), %r13
    movq %r12, %rdi
    movl $16, %esi
    xorl %edx, %edx
    call sea_parse_i64
    movq %rax, %rdi
    call put_dec
    TXT "\n"
    movq %r12, %rdi
    xorl %esi, %esi
    call sea_parse_f64
    cvttsd2si %xmm0, %rdi
    call put_dec
    TXT "\n"
    cmpq sea_live(%rip), %r13
    CHECK e, "parse: no object made"
    movq %r12, %rdi
    leaq .Ls_num(%rip), %rsi
    call untouched
    REL %r12
    # The live count is back to its start.
    movq 0(%rsp), %rax
    cmpq sea_live(%rip), %rax
    CHECK e, "live count back to the start"
    call finish
    EPILOGUE

    .section .data.rel.ro,"aw",@progbits
    SSTR .Le, ""
    SSTR .Lcomma, ","
    SSTR .Lcc, "::"
    SSTR .Ldash2, "--"
    SSTR .Ls_aeeb, "a,,b"
    SSTR .Ls_cac, ",a,"
    SSTR .Ls_abc, "abc"
    SSTR .Ls_ab, "ab"
    SSTR .Ls_aa, "aa"
    SSTR .Ls_aaa, "aaa"
    SSTR .Ls_aaaa, "aaaa"
    SSTR .Ls_acc, "a::b"
    SSTR .Ls_part, "a--b-"
    SSTR .Ls_paren, "(1.5)"
    SSTR .Ls_hello, "hello"
    SSTR .Ls_num, "1234"
    SSTR .Lpath, "in.txt"
    SSTR .Lfile, "m.sea"
    .p2align 3
    .globl sea_sites
sea_sites:
    .quad .Lfile, 1                 # site 0

    .section .note.GNU-stack,"",@progbits
