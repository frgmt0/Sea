# sea/tests/rt/x86_64_linux/rt_la_gemm_empty.s -- the empty shortcuts of sea_matmul, sea_gemv and sea_vecmat (DESIGN.md 2.13.2 "Empty operands", 2.13.5; LANGUAGE.md 10.8): r x 0 @ 0 x c is the r x c matrix of +0, 0 x k @ k x c the empty 0 x c matrix and r x k @ k x 0 the r x 0 one, 0 x 0 @ 0 x 0 the 0 x 0 one; r x 0 @ (empty) is r times +0, 0 x k @ x the empty vector; (empty) @ 0 x c is c times +0, x @ k x 0 the empty vector. Before each call a freed block of the result's class is filled with 42.0, so a zero result that is not written shows it; the ownership check and the heap check as in rt_la_gemm_values.
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

# ---- test helpers (the same block in every rt_la_gemm test) -----------
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
# The release sequence of pass 4 (DESIGN.md 4.9) on the object in reg
# (not %rdi): the count drops by one unless static, sea_free at 0
# (caller-saved registers clobbered).
.macro REL reg
    movq \reg, %rdi
    movq (%rdi), %rax
    testq %rax, %rax
    jz .Lrel\@
    decq %rax
    movq %rax, (%rdi)
    jnz .Lrel\@
    call sea_free
.Lrel\@:
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
# The entries, by their index in the case tables.
.equ ENT_GEMV, 0
.equ ENT_VECMAT, 1
.equ ENT_MATMUL, 2
# The variant of the first pass: the baseline form of x86_64-linux.
.equ FIRST_VARIANT, SEA_VAR_SSE2

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

# puthex -- append %rdi as 16 upper-case hexadecimal digits. Clobbers
# caller-saved registers. Frame: 8 (%rbp) + 16 bytes.
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

# putf -- append the f64 bits in %rdi: `NaN` for every NaN (its bits are
# not observable, LANGUAGE.md 6.5), else the 16 hexadecimal digits.
# Clobbers caller-saved registers. Frame 8 bytes (%rbp).
    .p2align 4
putf:
    pushq %rbp
    movq %rsp, %rbp
    movq %rdi, %rax
    shlq $1, %rax                   # drop the sign
    movabsq $0xFFE0000000000000, %rcx   # the exponent all ones, shifted
    cmpq %rcx, %rax
    jbe 1f                          # not above +inf: a number
    TXT "NaN"
    jmp 2f
1:  call puthex
2:  popq %rbp
    ret

# mkarr -- a new dynamic f64 array (count 1) holding a copy of n doubles.
#   Inputs  : %rdi = rank, %rsi = rows, %rdx = cols (1 for a vector),
#             %rcx = the source doubles (rows * cols, column-major)
#   Outputs : %rax = the array
#   Clobbers: caller-saved registers
#   Callee-saved used: %rbx = the source, %r12 = the array. Frame 24 bytes.
    .p2align 4
mkarr:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12                      # %rsp = 0 (mod 16)
    movq %rcx, %rbx
    movq %rdx, %rcx                 # cols
    movq %rsi, %rdx                 # rows
    movq %rdi, %rsi                 # rank
    movl $SEA_EK_F64, %edi
    xorl %r8d, %r8d                 # site 0
    call sea_arr_new_u
    movq %rax, %r12
    movq SEA_ARR_ROWS(%r12), %rdx
    imulq SEA_ARR_COLS(%r12), %rdx
    shlq $3, %rdx                   # the bytes
    movq SEA_ARR_DATA(%r12), %rdi
    movq %rbx, %rsi
    call memcpy@PLT
    movq %r12, %rax
    popq %r12
    popq %rbx
    popq %rbp
    ret

# dirty -- leave a freed block of the class a result of this shape takes
# with every element 42.0 (#4045000000000000): the allocator hands the
# most recently freed block of a class out first, so a result that is not
# fully written shows it.
#   Inputs  : %rdi = rank, %rsi = rows, %rdx = cols
#   Clobbers: caller-saved registers
#   Callee-saved used: %rbx = the array. Frame 24 bytes.
    .p2align 4
dirty:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp
    movq %rdx, %rcx
    movq %rsi, %rdx
    movq %rdi, %rsi
    movl $SEA_EK_F64, %edi
    xorl %r8d, %r8d
    call sea_arr_new_u
    movq %rax, %rbx
    movq SEA_ARR_ROWS(%rbx), %rcx
    imulq SEA_ARR_COLS(%rbx), %rcx  # elements
    movq SEA_ARR_DATA(%rbx), %rdi
    movabsq $0x4045000000000000, %rax
    cld
    rep stosq
    REL %rbx                        # count 1 -> freed
    addq $8, %rsp
    popq %rbx
    popq %rbp
    ret

# callent -- call an entry by its table index.
#   Inputs  : %rdi = ENT_*, %rsi = the left operand, %rdx = the right one
#   Outputs : %rax = the entry's result
#   Clobbers: as the entries. Frame 8 bytes (%rbp).
    .p2align 4
callent:
    pushq %rbp
    movq %rsp, %rbp
    leaq entries(%rip), %rax
    movq (%rax,%rdi,8), %rax
    movq %rsi, %rdi
    movq %rdx, %rsi
    xorl %edx, %edx                 # site 0
    call *%rax
    popq %rbp
    ret
    .section .data.rel.ro,"aw",@progbits
    .p2align 3
entries:
    .quad sea_gemv, sea_vecmat, sea_matmul
    .text
# ---- end of the test helpers ------------------------------------------

# ---- the case table driver (rt_la_gemm_values, rt_la_gemm_empty) ------
# A case record (8-byte words): label, ENT_*, the left operand's rank,
# rows, cols, data, the right operand's rank, rows, cols, data, the
# expected result's rank, rows, cols. The table ends with a 0 label.
.equ CR_LABEL, 0
.equ CR_ENT, 8
.equ CR_L, 16
.equ CR_R, 48
.equ CR_RES, 80
.equ CR_SIZE, 104

# runcase -- one case: the operands as fresh dynamic arrays (count 1), a
# dirty freed block of the result's class, the call, then the line
# `<label>: <rank> <rows>x<cols> own ok|own BAD <elements>`. "own ok"
# means: the live count rose by exactly one, the result has count 1, tag
# SEA_TAG_ARRAY and ek SEA_EK_F64, and both operands still have count 1
# and their original bytes. Everything is released afterwards.
#   Inputs  : %rdi = the record
#   Clobbers: caller-saved registers
#   Callee-saved used: %rbx = record, %r12 = left, %r13 = right,
#             %r14 = result, %r15 = faults, then the element cursor;
#             0(%rsp) = the live count before the call, then elements left
#   Frame   : 56 bytes (PROLOGUE)
    .p2align 4
runcase:
    PROLOGUE
    movq %rdi, %rbx
    movq CR_L(%rbx), %rdi
    movq (CR_L + 8)(%rbx), %rsi
    movq (CR_L + 16)(%rbx), %rdx
    movq (CR_L + 24)(%rbx), %rcx
    call mkarr
    movq %rax, %r12
    movq CR_R(%rbx), %rdi
    movq (CR_R + 8)(%rbx), %rsi
    movq (CR_R + 16)(%rbx), %rdx
    movq (CR_R + 24)(%rbx), %rcx
    call mkarr
    movq %rax, %r13
    movq CR_RES(%rbx), %rdi
    movq (CR_RES + 8)(%rbx), %rsi
    movq (CR_RES + 16)(%rbx), %rdx
    call dirty
    movq sea_live(%rip), %rax
    movq %rax, (%rsp)
    movq CR_ENT(%rbx), %rdi
    movq %r12, %rsi
    movq %r13, %rdx
    call callent
    movq %rax, %r14
    # ownership
    xorl %r15d, %r15d
    movq (%rsp), %rax
    incq %rax
    cmpq sea_live(%rip), %rax
    setne %al
    movzbl %al, %eax
    addq %rax, %r15                 # exactly one new object
    cmpq $1, SEA_ARR_RC(%r14)
    setne %al
    addq %rax, %r15                 # owned: count 1
    cmpb $SEA_TAG_ARRAY, SEA_ARR_TAG(%r14)
    setne %al
    addq %rax, %r15
    cmpb $SEA_EK_F64, SEA_ARR_EK(%r14)
    setne %al
    addq %rax, %r15
    cmpq $1, SEA_ARR_RC(%r12)
    setne %al
    addq %rax, %r15                 # the operands borrowed: counts unchanged
    cmpq $1, SEA_ARR_RC(%r13)
    setne %al
    addq %rax, %r15
    movq SEA_ARR_DATA(%r12), %rdi   # and their bytes unchanged
    movq (CR_L + 24)(%rbx), %rsi
    movq SEA_ARR_ROWS(%r12), %rdx
    imulq SEA_ARR_COLS(%r12), %rdx
    shlq $3, %rdx
    call memcmp@PLT
    testl %eax, %eax
    setne %al
    movzbl %al, %eax
    addq %rax, %r15
    movq SEA_ARR_DATA(%r13), %rdi
    movq (CR_R + 24)(%rbx), %rsi
    movq SEA_ARR_ROWS(%r13), %rdx
    imulq SEA_ARR_COLS(%r13), %rdx
    shlq $3, %rdx
    call memcmp@PLT
    testl %eax, %eax
    setne %al
    movzbl %al, %eax
    addq %rax, %r15
    # the line
    movq CR_LABEL(%rbx), %rdi
    call putcstr
    TXT ": "
    movzbl SEA_ARR_RANK(%r14), %edi
    call putdec
    TXT " "
    movq SEA_ARR_ROWS(%r14), %rdi
    call putdec
    TXT "x"
    movq SEA_ARR_COLS(%r14), %rdi
    call putdec
    testq %r15, %r15
    jnz 1f
    TXT " own ok"
    jmp 2f
1:  TXT " own BAD"
2:  movq SEA_ARR_DATA(%r14), %r15
    movq SEA_ARR_ROWS(%r14), %rax
    imulq SEA_ARR_COLS(%r14), %rax
    movq %rax, (%rsp)
3:  cmpq $0, (%rsp)
    je 4f
    TXT " "
    movq (%r15), %rdi
    addq $8, %r15
    call putf
    decq (%rsp)
    jmp 3b
4:  TXT "\n"
    REL %r14
    REL %r12
    REL %r13
    EPILOGUE

# runtable -- every record of a table. %rdi = the table. Clobbers
# caller-saved registers. Callee-saved used: %rbx (the record). Frame 24.
    .p2align 4
runtable:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp
    movq %rdi, %rbx
1:  cmpq $0, CR_LABEL(%rbx)
    je 2f
    movq %rbx, %rdi
    call runcase
    addq $CR_SIZE, %rbx
    jmp 1b
2:  addq $8, %rsp
    popq %rbx
    popq %rbp
    ret

# ---- the test ---------------------------------------------------------
# sea_main -- the table once, under the variant main selected. Frame 56.
    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    PROLOGUE
    TXT "pass 1\n"
    leaq cases(%rip), %rdi
    call runtable
    EPILOGUE
    .size sea_main, . - sea_main

    .section .data.rel.ro,"aw",@progbits
    .p2align 3
.Lce0_l:
.Lce0_r:
    .quad 0                 /* (an operand with no element points here) */
.Lce1_l:
.Lce1_r:
    .quad 0                 /* (an operand with no element points here) */
.Lce2_l:
.Lce2_r:
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0                 /* (an operand with no element points here) */
.Lce3_l:
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
.Lce3_r:
    .quad 0                 /* (an operand with no element points here) */
.Lce4_l:
.Lce4_r:
    .quad 0                 /* (an operand with no element points here) */
.Lce5_l:
.Lce5_r:
    .quad 0                 /* (an operand with no element points here) */
.Lce6_l:
.Lce6_r:
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0                 /* (an operand with no element points here) */
.Lce7_l:
.Lce7_r:
    .quad 0                 /* (an operand with no element points here) */
.Lce8_l:
.Lce8_r:
    .quad 0                 /* (an operand with no element points here) */
.Lce9_l:
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
.Lce9_r:
    .quad 0                 /* (an operand with no element points here) */
.Lce10_l:
.Lce10_r:
    .quad 0                 /* (an operand with no element points here) */
    .p2align 3
cases:
    .quad .Lcne0, ENT_MATMUL, 2, 3, 0, .Lce0_l, 2, 0, 2, .Lce0_r, 2, 3, 2
    .quad .Lcne1, ENT_MATMUL, 2, 1, 0, .Lce1_l, 2, 0, 1, .Lce1_r, 2, 1, 1
    .quad .Lcne2, ENT_MATMUL, 2, 0, 4, .Lce2_l, 2, 4, 2, .Lce2_r, 2, 0, 2
    .quad .Lcne3, ENT_MATMUL, 2, 3, 4, .Lce3_l, 2, 4, 0, .Lce3_r, 2, 3, 0
    .quad .Lcne4, ENT_MATMUL, 2, 0, 0, .Lce4_l, 2, 0, 0, .Lce4_r, 2, 0, 0
    .quad .Lcne5, ENT_GEMV, 2, 3, 0, .Lce5_l, 1, 0, 1, .Lce5_r, 1, 3, 1
    .quad .Lcne6, ENT_GEMV, 2, 0, 4, .Lce6_l, 1, 4, 1, .Lce6_r, 1, 0, 1
    .quad .Lcne7, ENT_GEMV, 2, 0, 0, .Lce7_l, 1, 0, 1, .Lce7_r, 1, 0, 1
    .quad .Lcne8, ENT_VECMAT, 1, 0, 1, .Lce8_l, 2, 0, 3, .Lce8_r, 1, 3, 1
    .quad .Lcne9, ENT_VECMAT, 1, 4, 1, .Lce9_l, 2, 4, 0, .Lce9_r, 1, 0, 1
    .quad .Lcne10, ENT_VECMAT, 1, 0, 1, .Lce10_l, 2, 0, 0, .Lce10_r, 1, 0, 1
    .quad 0                     /* end of the table */
.Lcne0: .asciz "mm 3x0 @ 0x2"
.Lcne1: .asciz "mm 1x0 @ 0x1"
.Lcne2: .asciz "mm 0x4 @ 4x2"
.Lcne3: .asciz "mm 3x4 @ 4x0"
.Lcne4: .asciz "mm 0x0 @ 0x0"
.Lcne5: .asciz "mv 3x0 @ 0"
.Lcne6: .asciz "mv 0x4 @ 4"
.Lcne7: .asciz "mv 0x0 @ 0"
.Lcne8: .asciz "vm 0 @ 0x3"
.Lcne9: .asciz "vm 4 @ 4x0"
.Lcne10: .asciz "vm 0 @ 0x0"
    .p2align 3
    .globl sea_sites
sea_sites:
    .quad .Lsite_file
    .quad 1
.Lsite_file:
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 6
    .ascii "la.sea"

    .section .note.GNU-stack,"",@progbits
