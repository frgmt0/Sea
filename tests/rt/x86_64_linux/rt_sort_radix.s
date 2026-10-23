# sea/tests/rt/x86_64_linux/rt_sort_radix.s -- the radix path of sea_sort and sea_argsort (DESIGN.md 4.8): keys differing in one byte only (one pass, seven skipped), 40 equal keys (every pass skipped), keys differing in every byte (all eight passes), ascending and descending with their expected bytes; then 5000-element i64 (six passes skipped) and f64 vectors from a 64-bit LCG, checked in the test: headers, a permutation, s[k] = v[p[k]], the order of LANGUAGE.md 10.6 and stability; live count back to 0 (heap check)
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

.equ RT_LCG_N, 5000                 # the self-checked vectors' length
# verify's locals (offsets from %rsp after its prologue).
.equ RT_V_DESC, 0
.equ RT_V_N,    8
.equ RT_V_OK,   16
.equ RT_V_VD,   24                  # v's elements
.equ RT_V_FRAME, 40

# verify -- %rdi = label, %rsi = v (f64 without NaN, or i64), %rdx = desc:
# s = sea_sort(v, desc), p = sea_argsort(v, desc); appends "<label>: ok"
# when both headers are right (hdr), p is a permutation of 0 .. n-1, s[k]
# has the bits of v[p[k]], and for every k >= 1 v[p[k-1]] is before
# v[p[k]] (ascending: less, descending: greater) or equal to it with
# p[k-1] < p[k] (stability); else "<label>: ok BAD". Releases s, p and the
# marks. Clobbers caller-saved registers. Callee-saved used: %rbx = label,
# %r12 = v, %r13 = s, %r14 = p, %r15 = the marks (a bool vector); locals
# RT_V_*. Frame 48 + RT_V_FRAME = 88 bytes.
    .p2align 4
verify:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15                      # %rsp = 8 (mod 16)
    subq $RT_V_FRAME, %rsp          # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
    movq %rdx, RT_V_DESC(%rsp)
    movq SEA_ARR_ROWS(%r12), %rax
    movq %rax, RT_V_N(%rsp)
    movq SEA_ARR_DATA(%r12), %rax
    movq %rax, RT_V_VD(%rsp)
    movq %r12, %rdi
    movq RT_V_DESC(%rsp), %rsi
    xorl %edx, %edx
    call sea_sort
    movq %rax, %r13
    movq %r12, %rdi
    movq RT_V_DESC(%rsp), %rsi
    xorl %edx, %edx
    call sea_argsort
    movq %rax, %r14
    movl $SEA_EK_BOOL, %edi         # the marks, all false
    movl $1, %esi
    movq RT_V_N(%rsp), %rdx
    movl $1, %ecx
    xorl %r8d, %r8d
    call sea_arr_new
    movq %rax, %r15
    movq %r13, %rdi
    movzbl SEA_ARR_EK(%r12), %esi
    movq RT_V_N(%rsp), %rdx
    call hdr
    movq %rax, RT_V_OK(%rsp)
    movq %r14, %rdi
    movl $SEA_EK_I64, %esi
    movq RT_V_N(%rsp), %rdx
    call hdr
    andq %rax, RT_V_OK(%rsp)
    xorl %ecx, %ecx                 # k
1:  cmpq RT_V_N(%rsp), %rcx
    jae 8f
    movq SEA_ARR_DATA(%r14), %r8    # p's elements
    movq (%r8,%rcx,8), %rdx         # j = p[k]
    cmpq RT_V_N(%rsp), %rdx
    jae 7f                          # out of range
    movq SEA_ARR_DATA(%r15), %r9
    cmpb $0, (%r9,%rdx)
    jne 7f                          # j seen before: not a permutation
    movb $1, (%r9,%rdx)
    movq RT_V_VD(%rsp), %r10
    movq (%r10,%rdx,8), %rax        # b = v[j]
    movq SEA_ARR_DATA(%r13), %r11
    cmpq (%r11,%rcx,8), %rax        # s[k]
    jne 7f
    testq %rcx, %rcx
    jz 6f
    movq -8(%r8,%rcx,8), %rsi       # p[k-1]
    movq (%r10,%rsi,8), %rdi        # a = v[p[k-1]]
    cmpb $SEA_EK_F64, SEA_ARR_EK(%r12)
    je 2f
    cmpq %rax, %rdi                 # i64: signed a vs b
    je 5f
    jl 3f
    jmp 4f
2:  movq %rdi, %xmm0
    movq %rax, %xmm1
    ucomisd %xmm1, %xmm0            # f64 (no NaN here): a vs b
    je 5f
    jb 3f
    jmp 4f
3:  cmpq $0, RT_V_DESC(%rsp)        # a < b: right ascending only
    je 6f
    jmp 7f
4:  cmpq $0, RT_V_DESC(%rsp)        # a > b: right descending only
    jne 6f
    jmp 7f
5:  cmpq %rdx, %rsi                 # equal: input order kept
    jae 7f
6:  incq %rcx
    jmp 1b
7:  movq $0, RT_V_OK(%rsp)
8:  movq %rbx, %rdi
    call putcstr
    cmpq $1, RT_V_OK(%rsp)
    CHECK e, ": ok"
    movq %r13, %rdi
    call sea_release
    movq %r14, %rdi
    call sea_release
    movq %r15, %rdi
    call sea_release
    addq $RT_V_FRAME, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

# llcg -- %edi = ek (SEA_EK_I64 or SEA_EK_F64): a new vector of RT_LCG_N
# elements from the 64-bit LCG x <- x * 6364136223846793005 +
# 1442695040888963407 (x0 = 1, one step per element): i64 x >> 52
# (logical: 0 .. 4095, many ties; bytes 2..7 of every key equal, so six
# radix passes are skipped), f64 (x >> 54, arithmetic) * 0.25 (-128 ..
# 127.75, exact). Clobbers caller-saved registers. Callee-saved used:
# %rbx = ek, %r12 = the vector. Frame 24 bytes.
    .p2align 4
llcg:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12                      # %rsp = 0 (mod 16)
    movl %edi, %ebx
    movl $1, %esi
    movl $RT_LCG_N, %edx
    movl $1, %ecx
    xorl %r8d, %r8d
    call sea_arr_new_u
    movq %rax, %r12
    movq SEA_ARR_DATA(%r12), %rdi
    movabsq $0x5851F42D4C957F2D, %r8 # 6364136223846793005
    movabsq $0x14057B7EF767814F, %r9 # 1442695040888963407
    movl $1, %eax                   # x
    xorl %ecx, %ecx                 # k
    movsd .Lquarter(%rip), %xmm1
1:  imulq %r8, %rax
    addq %r9, %rax                  # x = x * a + c (mod 2^64)
    movq %rax, %rdx
    cmpl $SEA_EK_I64, %ebx
    jne 2f
    shrq $52, %rdx
    jmp 3f
2:  sarq $54, %rdx
    cvtsi2sdq %rdx, %xmm0
    mulsd %xmm1, %xmm0
    movq %xmm0, %rdx
3:  movq %rdx, (%rdi,%rcx,8)
    incq %rcx
    cmpq $RT_LCG_N, %rcx
    jb 1b
    movq %r12, %rax
    popq %r12
    popq %rbx
    popq %rbp
    ret

    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    PROLOGUE
    leaq .Ltable(%rip), %rdi
    call runtable
    movl $SEA_EK_I64, %edi
    call llcg
    movq %rax, %rbx
    leaq .Ll_li_a(%rip), %rdi
    movq %rbx, %rsi
    xorl %edx, %edx
    call verify
    leaq .Ll_li_d(%rip), %rdi
    movq %rbx, %rsi
    movl $1, %edx
    call verify
    movq %rbx, %rdi
    call sea_release
    movl $SEA_EK_F64, %edi
    call llcg
    movq %rax, %rbx
    leaq .Ll_lf_a(%rip), %rdi
    movq %rbx, %rsi
    xorl %edx, %edx
    call verify
    leaq .Ll_lf_d(%rip), %rdi
    movq %rbx, %rsi
    movl $1, %edx
    call verify
    movq %rbx, %rdi
    call sea_release
    EPILOGUE

    .section .rodata
    .p2align 3
.Lquarter: .quad 0x3FD0000000000000 # 0.25
.Ll_ska:  .asciz "skip asc"
.Ll_skd:  .asciz "skip desc"
.Ll_eqa:  .asciz "equal asc"
.Ll_eqd:  .asciz "equal desc"
.Ll_ala:  .asciz "alt asc"
.Ll_ald:  .asciz "alt desc"
.Ll_li_a: .asciz "lcg i64 n5000 asc"
.Ll_li_d: .asciz "lcg i64 n5000 desc"
.Ll_lf_a: .asciz "lcg f64 n5000 asc"
.Ll_lf_d: .asciz "lcg f64 n5000 desc"

    .section .data.rel.ro,"aw",@progbits
    .p2align 3
.Ltable:
    .quad .Ll_ska, .Lv_skip, 0
    .quad .Ll_skd, .Lv_skip, 1
    .quad .Ll_eqa, .Lv_eq, 0
    .quad .Ll_eqd, .Lv_eq, 1
    .quad .Ll_ala, .Lv_alt, 0
    .quad .Ll_ald, .Lv_alt, 1
    .quad 0
    # (39 - i) * 256: the keys differ in byte 1 only (one pass, the others skipped)
    SARR .Lv_skip, SEA_EK_I64, 40
    .set .Lseq_i, 0
    .rept 40
    .quad (39 - .Lseq_i) * 256
    .set .Lseq_i, .Lseq_i + 1
    .endr
    # 40 times 3.5: every pass skipped
    SARR .Lv_eq, SEA_EK_F64, 40
    .rept 40
    .quad 0x400C000000000000
    .endr
    # 0, -1, 0, -1, ...: the keys differ in every byte (all 8 passes)
    SARR .Lv_alt, SEA_EK_I64, 40
    .rept 20
    .quad 0, -1
    .endr
    .p2align 3
    .globl sea_sites
sea_sites:
    .quad 0

    .section .note.GNU-stack,"",@progbits
