# sea/tests/rt/x86_64_linux/rt_sort_scratch.s -- the scratch block of sea_sort and sea_argsort (DESIGN.md 4.8 "Scratch"): for the insertion (f64, n = 4: 12n bytes), radix (i64, n = 40: 24n + 16384 bytes) and str (n = 4: 8n bytes) paths, the entry adds exactly one live object (the result) and gives its scratch block back before it returns (the block it took, the head of the request's class after a prior allocate and free, is handed out again afterwards); live count back to 0 (heap check)
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

# scratch's locals (offsets from %rsp after its prologue).
.equ RT_S_RES,   0                  # the result
.equ RT_S_LIVE,  8                  # the live count before the entry
.equ RT_S_FRAME, 24

# scratch -- %rdi = label, %rsi = v, %rdx = the scratch request DESIGN.md
# 4.8 states for v (in bytes), %rcx = 0 for sea_sort, 1 for sea_argsort.
# A block X of that request is allocated and freed first, so it heads its
# class (DESIGN.md 4.1: the most recently freed block is handed out first;
# the result's class differs from the scratch's for the vectors used
# here). Then the entry runs: the live count must grow by exactly one (the
# result, "<label>: one new object"), and after the result's release the
# next allocation of that request must be X again ("<label>: scratch block
# given back"): the entry took X as its scratch and freed it. Clobbers
# caller-saved registers. Callee-saved used: %rbx = label, %r12 = v,
# %r13 = bytes, %r14 = mode, %r15 = X; locals RT_S_*. Frame 48 +
# RT_S_FRAME = 72 bytes.
    .p2align 4
scratch:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15                      # %rsp = 8 (mod 16)
    subq $RT_S_FRAME, %rsp          # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
    movq %rdx, %r13
    movq %rcx, %r14
    movq %r13, %rdi
    xorl %esi, %esi
    call sea_alloc
    movq %rax, %r15                 # X
    movq %r15, %rdi
    movq %r13, %rsi
    call sea_free_block             # X heads its class
    movq sea_live(%rip), %rax
    movq %rax, RT_S_LIVE(%rsp)
    movq %r12, %rdi
    xorl %esi, %esi
    xorl %edx, %edx
    testq %r14, %r14
    jnz 1f
    call sea_sort
    jmp 2f
1:  call sea_argsort
2:  movq %rax, RT_S_RES(%rsp)
    movq %rbx, %rdi
    call putcstr
    movq RT_S_LIVE(%rsp), %rax
    incq %rax
    cmpq sea_live(%rip), %rax
    CHECK e, ": one new object"
    movq RT_S_RES(%rsp), %rdi
    call sea_release
    movq %r13, %rdi
    xorl %esi, %esi
    call sea_alloc
    movq %rax, RT_S_RES(%rsp)       # Y: X again?
    movq %rbx, %rdi
    call putcstr
    cmpq %r15, RT_S_RES(%rsp)
    CHECK e, ": scratch block given back"
    movq RT_S_RES(%rsp), %rdi
    movq %r13, %rsi
    call sea_free_block
    addq $RT_S_FRAME, %rsp
    popq %r15
    popq %r14
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
    leaq .Ltable(%rip), %rbx
1:  movq (%rbx), %rdi
    testq %rdi, %rdi
    jz 2f
    movq 8(%rbx), %rsi
    movq 16(%rbx), %rdx
    movq 24(%rbx), %rcx
    call scratch
    addq $32, %rbx
    jmp 1b
2:  EPILOGUE

    .section .rodata
.Ll_fs:   .asciz "f64 n4 sort"
.Ll_fa:   .asciz "f64 n4 argsort"
.Ll_is:   .asciz "i64 n40 sort"
.Ll_ia:   .asciz "i64 n40 argsort"
.Ll_ss:   .asciz "str n4 sort"
.Ll_sa:   .asciz "str n4 argsort"

    .section .data.rel.ro,"aw",@progbits
    .p2align 3
.Ltable:                            # label, v, scratch bytes, mode
    .quad .Ll_fs, .Lv_f4, 12 * 4, 0 # insertion: 12n rounded up to 8
    .quad .Ll_fa, .Lv_f4, 12 * 4, 1
    .quad .Ll_is, .Lv_i40, 24 * 40 + 16384, 0 # radix: 24n + 16384
    .quad .Ll_ia, .Lv_i40, 24 * 40 + 16384, 1
    .quad .Ll_ss, .Lv_s4, 8 * 4, 0  # str: 8n
    .quad .Ll_sa, .Lv_s4, 8 * 4, 1
    .quad 0
    SSTR .Ls_x, 1, "x"
    SSTR .Ls_y, 1, "y"
    SARR .Lv_f4, SEA_EK_F64, 4      # 3.0, 1.0, 2.0, 0.5
    .quad 0x4008000000000000, 0x3FF0000000000000, 0x4000000000000000, 0x3FE0000000000000
    SARR .Lv_i40, SEA_EK_I64, 40    # 39, 38, ..., 0
    .set .Lseq_i, 0
    .rept 40
    .quad 39 - .Lseq_i
    .set .Lseq_i, .Lseq_i + 1
    .endr
    SARR .Lv_s4, SEA_EK_STR, 4      # y, x, y, x
    .quad .Ls_y, .Ls_x, .Ls_y, .Ls_x
    .p2align 3
    .globl sea_sites
sea_sites:
    .quad 0

    .section .note.GNU-stack,"",@progbits
