# sea/tests/rt/x86_64_linux/rt_sort_str.s -- sea_sort and sea_argsort of str vectors (DESIGN.md 4.8, LANGUAGE.md 10.6, STR_CMP order): nine fresh strings with the empty string, a prefix chain a < ab < abc, upper case before lower case, the byte 0xFF last, and ties (two a, two ab) kept in input order ascending and descending (s[k] is the very object v[p[k]]); a sorted copy holds one more count of each element and gives it back on release, argsort none; static elements stay at count 0; n = 0 and n = 1; v unchanged; live count back to 0 (heap check)
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

# ---- test helpers (the same block in every rt_sort test) --------------
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
# A static vector (count SEA_RC_STATIC) of n 8-byte elements of kind ek; the
# elements follow the macro, right after the header.
.macro SARR label, ek, n
    .p2align 6
\label:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_ARRAY, \ek, 1, 0, 0, 0, 0, 0
    .quad \n, 1, \n, \label + SEA_ARR_SIZE, 8, 0
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

    .text
# putcstr -- append the NUL-terminated text at %rdi. Clobbers caller-saved
# registers. Callee-saved used: %rbx (the text). Frame 24 bytes.
    .p2align 4
putcstr:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp
    movq %rdi, %rbx
    call strlen@PLT
    movq %rax, %rsi
    movq %rbx, %rdi
    call sea_out_write
    addq $8, %rsp
    popq %rbx
    popq %rbp
    ret

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

# puthex -- append %rdi as 16 upper-case hexadecimal digits (the bits of
# an f64). Clobbers caller-saved registers. Frame: 8 (%rbp) + 16 bytes.
    .p2align 4
puthex:
    pushq %rbp
    movq %rsp, %rbp
    subq $16, %rsp
    movl $16, %ecx
1:  movl %edi, %eax
    andl $15, %eax                  # the lowest digit, written right to left
    leal 48(%rax), %edx             # '0' + d
    leal 55(%rax), %r8d             # 'A' - 10 + d
    cmpl $10, %eax
    cmovael %r8d, %edx
    decl %ecx
    movb %dl, (%rsp,%rcx)
    shrq $4, %rdi
    testl %ecx, %ecx
    jnz 1b
    movq %rsp, %rdi
    movl $16, %esi
    call sea_out_write
    movq %rbp, %rsp
    popq %rbp
    ret

# putstr -- append the bytes of the string object at %rdi between [ and ].
#   Clobbers caller-saved registers. Callee-saved used: %rbx. Frame 24 bytes.
    .p2align 4
putstr:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp
    movq %rdi, %rbx
    TXT "["
    leaq SEA_STR_BYTES(%rbx), %rdi
    movq SEA_STR_LEN(%rbx), %rsi
    call sea_out_write
    TXT "]"
    addq $8, %rsp
    popq %rbx
    popq %rbp
    ret

# putnl -- append a LF.
    .p2align 4
putnl:
    pushq %rbp
    movq %rsp, %rbp
    TXT "\n"
    popq %rbp
    ret

# putvec -- append each element of the vector at %rdi after a space: f64
# as hex bits, i64 in decimal, str as [bytes]. Clobbers caller-saved
# registers. Callee-saved used: %rbx = vector, %r12 = k, %r13 = n,
# %r14 = ek. Frame 40 bytes.
    .p2align 4
putvec:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14                      # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq SEA_ARR_ROWS(%rbx), %r13
    movzbl SEA_ARR_EK(%rbx), %r14d
    xorl %r12d, %r12d
1:  cmpq %r13, %r12
    jae 9f
    TXT " "
    movq SEA_ARR_DATA(%rbx), %rax
    movq (%rax,%r12,8), %rdi        # element k
    cmpl $SEA_EK_F64, %r14d
    jne 2f
    call puthex
    jmp 4f
2:  cmpl $SEA_EK_STR, %r14d
    jne 3f
    call putstr
    jmp 4f
3:  call putdec
4:  incq %r12
    jmp 1b
9:  popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

# hdr -- %rdi = a result vector, %esi = expected ek, %rdx = expected n:
# %eax = 1 if count 1, SEA_TAG_ARRAY, ek, rank 1, rows n, cols 1, cap n,
# data right after the header, esize 8 and slay 0; else 0. Clobbers %rcx,
# flags. Leaf.
    .p2align 4
hdr:
    xorl %eax, %eax
    cmpq $1, SEA_ARR_RC(%rdi)
    jne 9f
    cmpb $SEA_TAG_ARRAY, SEA_ARR_TAG(%rdi)
    jne 9f
    movzbl SEA_ARR_EK(%rdi), %ecx
    cmpl %esi, %ecx
    jne 9f
    cmpb $1, SEA_ARR_RANK(%rdi)
    jne 9f
    cmpq %rdx, SEA_ARR_ROWS(%rdi)
    jne 9f
    cmpq $1, SEA_ARR_COLS(%rdi)
    jne 9f
    cmpq %rdx, SEA_ARR_CAP(%rdi)
    jne 9f
    leaq SEA_ARR_SIZE(%rdi), %rcx
    cmpq %rcx, SEA_ARR_DATA(%rdi)
    jne 9f
    cmpq $8, SEA_ARR_ESIZE(%rdi)
    jne 9f
    cmpq $0, SEA_ARR_SLAY(%rdi)
    jne 9f
    movl $1, %eax
9:  ret

# casev -- %rdi = label, %rsi = v, %rdx = desc: s = sea_sort(v, desc), p =
# sea_argsort(v, desc); appends "<label> sort: <s>", "<label> argsort: <p>"
# and "<label>: results ok" when both headers are right (hdr), every
# p[k] < n and s[k] has the bits of v[p[k]]; releases s and p.
# Clobbers caller-saved registers. Callee-saved used: %rbx = label,
# %r12 = v, %r13 = desc, %r14 = s, %r15 = p; locals ok at 0(%rsp), n at
# 8(%rsp). Frame 48 + 24 = 72 bytes.
    .p2align 4
casev:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15                      # %rsp = 8 (mod 16)
    subq $24, %rsp                  # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
    movq %rdx, %r13
    movq SEA_ARR_ROWS(%r12), %rax
    movq %rax, 8(%rsp)
    movq %r12, %rdi
    movq %r13, %rsi
    xorl %edx, %edx
    call sea_sort
    movq %rax, %r14
    movq %r12, %rdi
    movq %r13, %rsi
    xorl %edx, %edx
    call sea_argsort
    movq %rax, %r15
    movq %rbx, %rdi
    call putcstr
    TXT " sort:"
    movq %r14, %rdi
    call putvec
    call putnl
    movq %rbx, %rdi
    call putcstr
    TXT " argsort:"
    movq %r15, %rdi
    call putvec
    call putnl
    movq %r14, %rdi                 # the headers
    movzbl SEA_ARR_EK(%r12), %esi
    movq 8(%rsp), %rdx
    call hdr
    movq %rax, 0(%rsp)
    movq %r15, %rdi
    movl $SEA_EK_I64, %esi
    movq 8(%rsp), %rdx
    call hdr
    andq %rax, 0(%rsp)
    xorl %ecx, %ecx                 # s[k] = v[p[k]] for every k
1:  cmpq 8(%rsp), %rcx
    jae 2f
    movq SEA_ARR_DATA(%r15), %rax
    movq (%rax,%rcx,8), %rdx        # p[k]
    cmpq 8(%rsp), %rdx
    jae 3f
    movq SEA_ARR_DATA(%r12), %rax
    movq (%rax,%rdx,8), %rax        # v[p[k]]
    movq SEA_ARR_DATA(%r14), %rdx
    cmpq (%rdx,%rcx,8), %rax        # s[k]
    jne 3f
    incq %rcx
    jmp 1b
3:  movq $0, 0(%rsp)
2:  movq %rbx, %rdi
    call putcstr
    cmpq $1, 0(%rsp)
    CHECK e, ": results ok"
    movq %r14, %rdi
    call sea_release
    movq %r15, %rdi
    call sea_release
    addq $24, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

# runtable -- %rdi = a table of {label, v, desc} triples of quads, ended
# by a zero label: casev for each. Clobbers caller-saved registers.
# Callee-saved used: %rbx (the table cursor). Frame 24 bytes.
    .p2align 4
runtable:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp
    movq %rdi, %rbx
1:  movq (%rbx), %rdi
    testq %rdi, %rdi
    jz 2f
    movq 8(%rbx), %rsi
    movq 16(%rbx), %rdx
    call casev
    addq $24, %rbx
    jmp 1b
2:  addq $8, %rsp
    popq %rbx
    popq %rbp
    ret
# ---- end of the test helpers ---------------------------------------------

.equ RT_NSTR, 9                     # the dynamic vector's length

# counts -- %rdi = text, %rsi = a str vector: appends the text, then the
# count of each element after a space, then LF. Clobbers caller-saved
# registers. Callee-saved used: %rbx = vector, %r12 = k, %r13 = n.
# Frame 40 bytes.
    .p2align 4
counts:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    subq $8, %rsp                   # %rsp = 0 (mod 16)
    movq %rsi, %rbx
    call putcstr
    movq SEA_ARR_ROWS(%rbx), %r13
    xorl %r12d, %r12d
1:  cmpq %r13, %r12
    jae 2f
    TXT " "
    movq SEA_ARR_DATA(%rbx), %rax
    movq (%rax,%r12,8), %rax
    movq SEA_STR_RC(%rax), %rdi     # the element's count
    call putdec
    incq %r12
    jmp 1b
2:  call putnl
    addq $8, %rsp
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

# fresh -- %rdi = a str vector, %rsi = a table of static strings: element
# k = a fresh string (count 1) with the bytes of string k (sea_str_cat
# with the empty string). Clobbers caller-saved registers. Callee-saved
# used: %rbx = vector, %r12 = table, %r13 = k, %r14 = n. Frame 40 bytes.
    .p2align 4
fresh:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14                      # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
    movq SEA_ARR_ROWS(%rbx), %r14
    xorl %r13d, %r13d
1:  cmpq %r14, %r13
    jae 2f
    movq (%r12,%r13,8), %rdi
    leaq .Ls_empty(%rip), %rsi
    xorl %edx, %edx
    call sea_str_cat                # always a new object
    movq SEA_ARR_DATA(%rbx), %rdx
    movq %rax, (%rdx,%r13,8)
    incq %r13
    jmp 1b
2:  popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    PROLOGUE
    # v: nine fresh strings "b" "a" "ab" "" "\xff" "a" "B" "abc" "ab".
    movl $SEA_EK_STR, %edi
    movl $1, %esi
    movl $RT_NSTR, %edx
    movl $1, %ecx
    xorl %r8d, %r8d
    call sea_arr_new
    movq %rax, %rbx
    movq %rbx, %rdi
    leaq .Lstrs(%rip), %rsi
    call fresh
    leaq .Ll_asc(%rip), %rdi
    movq %rbx, %rsi
    xorl %edx, %edx
    call casev
    leaq .Ll_desc(%rip), %rdi
    movq %rbx, %rsi
    movl $1, %edx
    call casev
    # Counts: a sorted copy holds one count of each element; argsort none.
    movq %rbx, %rdi
    xorl %esi, %esi
    xorl %edx, %edx
    call sea_sort
    movq %rax, %r12
    leaq .Lt_withs(%rip), %rdi
    movq %rbx, %rsi
    call counts
    movq %r12, %rdi
    call sea_release
    leaq .Lt_after(%rip), %rdi
    movq %rbx, %rsi
    call counts
    movq %rbx, %rdi
    movl $1, %esi
    xorl %edx, %edx
    call sea_argsort
    movq %rax, %r12
    leaq .Lt_withp(%rip), %rdi
    movq %rbx, %rsi
    call counts
    movq %r12, %rdi
    call sea_release
    # Static elements: sorted, their counts stay SEA_RC_STATIC.
    leaq .Ll_stat(%rip), %rdi
    leaq .Lv_stat(%rip), %rsi
    xorl %edx, %edx
    call casev
    leaq .Lv_stat(%rip), %rdi
    xorl %esi, %esi
    xorl %edx, %edx
    call sea_sort
    movq %rax, %r12
    leaq .Lt_stat(%rip), %rdi
    leaq .Lv_stat(%rip), %rsi
    call counts
    movq %r12, %rdi
    call sea_release
    # n = 0 and n = 1 (a fresh "abc").
    leaq .Ll_n0(%rip), %rdi
    leaq .Lv_n0(%rip), %rsi
    xorl %edx, %edx
    call casev
    movl $SEA_EK_STR, %edi
    movl $1, %esi
    movl $1, %edx
    movl $1, %ecx
    xorl %r8d, %r8d
    call sea_arr_new
    movq %rax, %r13
    movq %r13, %rdi
    leaq .Lstrs1(%rip), %rsi
    call fresh
    leaq .Ll_n1(%rip), %rdi
    movq %r13, %rsi
    movl $1, %edx
    call casev
    movq %r13, %rdi
    xorl %esi, %esi
    xorl %edx, %edx
    call sea_sort
    movq %rax, %r12
    leaq .Lt_n1(%rip), %rdi
    movq %r13, %rsi
    call counts
    movq %r12, %rdi
    call sea_release
    # v unchanged: element k still has string k's bytes and count 1.
    movl $1, %r14d                  # ok
    xorl %r15d, %r15d               # k
1:  cmpq $RT_NSTR, %r15
    jae 2f
    movq SEA_ARR_DATA(%rbx), %rax
    movq (%rax,%r15,8), %rdi
    cmpq $1, SEA_STR_RC(%rdi)
    je 3f
    xorl %r14d, %r14d
3:  leaq .Lstrs(%rip), %rax
    movq (%rax,%r15,8), %rsi
    call sea_str_cmp
    testq %rax, %rax
    jz 4f
    xorl %r14d, %r14d
4:  incq %r15
    jmp 1b
2:  cmpq $1, %r14
    CHECK e, "input unchanged"
    movq %rbx, %rdi
    call sea_release
    movq %r13, %rdi
    call sea_release
    EPILOGUE

    .section .rodata
.Ll_asc:  .asciz "str asc"
.Ll_desc: .asciz "str desc"
.Ll_stat: .asciz "str static"
.Ll_n0:   .asciz "str n0"
.Ll_n1:   .asciz "str n1"
.Lt_withs: .asciz "counts with a sorted copy:"
.Lt_after: .asciz "counts after its release:"
.Lt_withp: .asciz "counts with an argsort result:"
.Lt_stat: .asciz "static counts with a sorted copy:"
.Lt_n1:   .asciz "n1 count with a sorted copy:"

    .section .data.rel.ro,"aw",@progbits
    SSTR .Ls_b, 1, "b"
    SSTR .Ls_a, 1, "a"
    SSTR .Ls_ab, 2, "ab"
    SSTR .Ls_empty, 0, ""
    SSTR .Ls_ff, 1, "\377"
    SSTR .Ls_a2, 1, "a"
    SSTR .Ls_B, 1, "B"
    SSTR .Ls_abc, 3, "abc"
    SSTR .Ls_ab2, 2, "ab"
    .p2align 3
.Lstrs:                             # the bytes of v's elements, in order
    .quad .Ls_b, .Ls_a, .Ls_ab, .Ls_empty, .Ls_ff, .Ls_a2, .Ls_B, .Ls_abc, .Ls_ab2
.Lstrs1:
    .quad .Ls_abc
    SARR .Lv_stat, SEA_EK_STR, 2    # static "b", "a"
    .quad .Ls_b, .Ls_a
    SARR .Lv_n0, SEA_EK_STR, 0
    .p2align 3
    .globl sea_sites
sea_sites:
    .quad 0

    .section .note.GNU-stack,"",@progbits
