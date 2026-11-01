# sea/tests/rt/x86_64_linux/rt_la_gemm_values.s -- sea_gemv, sea_vecmat and sea_matmul on given data (DESIGN.md 2.13.2, 2.13.5, 2.13.6; LANGUAGE.md 10.5, 10.8): GEMV's pinned order (A[0,:] = [1e16, 1, -1e16] with x = [1, 1, 1] is 0), a row of -0 products gives -0, Inf, NaN and 0*Inf, row counts 1, 7, 19, 35 against every panel and tail; VECMAT's pinned 8-lane order with k = 19 on data where it differs from the sequential sum, -0 lanes, non-finite values, k = 1, 7, 8, 13, 16, 23 (tails and none); MATMUL on exact data (1x1, 3x5 @ 5x2, 2x3 @ 3x4 dyadic). Each case: fresh operands of count 1, a dirty freed block of the result's class, then the result's rank, shape and elements (f64 bits, NaN as NaN) and the ownership check (one new object of count 1, the operands' counts and bytes unchanged). The table runs twice, under the first variant of the target (x86_64: sse2) and under the selected one, with the same expected bytes; the heap check ends at 0 live objects. Expected values: DESIGN.md 2.13.2's orders transcribed into binary64 operations.
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
# sea_main -- the table twice: pass 1 under FIRST_VARIANT, pass 2 under
# the variant main selected. Callee-saved used: %rbx (the selected
# variant). Frame 56 bytes.
    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    PROLOGUE
    movq sea_variant(%rip), %rbx    # the selected variant
    movq $FIRST_VARIANT, sea_variant(%rip)
    TXT "pass 1\n"
    leaq cases(%rip), %rdi
    call runtable
    movq %rbx, sea_variant(%rip)    # back to the selected variant
    TXT "pass 2\n"
    leaq cases(%rip), %rdi
    call runtable
    EPILOGUE
    .size sea_main, . - sea_main

    .section .data.rel.ro,"aw",@progbits
    .p2align 3
.Lcv0_l:
    .quad 0x4341C37937E08000
    .quad 0x3FF0000000000000
    .quad 0xC341C37937E08000
.Lcv0_r:
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0                 /* (an operand with no element points here) */
.Lcv1_l:
    .quad 0x8000000000000000
    .quad 0x0000000000000000
    .quad 0x8000000000000000
    .quad 0x8000000000000000
    .quad 0x8000000000000000
    .quad 0x0000000000000000
.Lcv1_r:
    .quad 0x3FF0000000000000
    .quad 0x4000000000000000
    .quad 0x4008000000000000
    .quad 0                 /* (an operand with no element points here) */
.Lcv2_l:
    .quad 0x7FF0000000000000
    .quad 0x7FF0000000000000
    .quad 0x7FE1CCF385EBC8A0
    .quad 0x3FF0000000000000
    .quad 0xFFF0000000000000
    .quad 0x7FE1CCF385EBC8A0
.Lcv2_r:
    .quad 0x4000000000000000
    .quad 0x3FF0000000000000
    .quad 0                 /* (an operand with no element points here) */
.Lcv3_l:
    .quad 0x0000000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
.Lcv3_r:
    .quad 0x7FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0                 /* (an operand with no element points here) */
.Lcv4_l:
    .quad 0xBFEBF15F2E283A7F
.Lcv4_r:
    .quad 0x400BF1CB64658734
    .quad 0                 /* (an operand with no element points here) */
.Lcv5_l:
    .quad 0x4026FB9DB3D1CD2E
    .quad 0xBFAFD082B532EED2
    .quad 0x3FE3E56D36B1060D
    .quad 0x4025CA9BB28B9030
    .quad 0x3F8A6A6862CDCD1E
    .quad 0xC04AC613EEF42956
    .quad 0xBFD8DD4514F9E90C
    .quad 0xBF9BD0F6809BF2A8
    .quad 0xBFF882F1512E77C9
    .quad 0x3F9F017284C5F714
    .quad 0xBF7F739657EFCF1C
    .quad 0x3F5D2ED414E4FA17
    .quad 0xBFABD02EA3A4E75C
    .quad 0xBFA77EC2B7AC855F
    .quad 0xBFBC2564DECF1D3E
    .quad 0xBFDA60DB126A2712
    .quad 0x3FBE5DF4C431DFCC
    .quad 0x3FA49B8AAE4F11B1
    .quad 0x3F54269212C9E77A
    .quad 0xC00D90717DDBB699
    .quad 0xC01BE6F18232DB56
    .quad 0xC0307A8BD6F69C2C
    .quad 0x3F70CD6C5FDAD160
    .quad 0x3F7C0CC842879892
    .quad 0x400A10937386DEFD
    .quad 0x404F28A5EEF2C21C
    .quad 0x40245653B664F689
    .quad 0xBFAC14ACA24CCE4B
    .quad 0xBF77D0985EB7970E
    .quad 0x40211E6DA7774072
    .quad 0x3FF60F295E615B16
    .quad 0x3F73204C59E7B0FB
    .quad 0xBF82DC5C7BDB3B9F
    .quad 0xBFD3201B1C2C9E4A
    .quad 0x4031EE5DCFE2642F
.Lcv5_r:
    .quad 0xC046FC09EA0F19E4
    .quad 0xBF987B769E4672D0
    .quad 0x401D9C938583D68D
    .quad 0x403B0FFBCF322A78
    .quad 0xC0103EF38C053CAA
    .quad 0                 /* (an operand with no element points here) */
.Lcv6_l:
    .quad 0xBF6205DC397B5FDE
    .quad 0x403CDC75C97320C8
    .quad 0x3F8545FA658F4AB2
    .quad 0x3FD534430EFDDE88
    .quad 0xC017980D9E189879
    .quad 0xBF78D7B444F65545
    .quad 0x3FF80F094D8DE7FE
    .quad 0xC03284B1CC82FAD0
    .quad 0x3FE3EEEF234297CD
    .quad 0x3F7710B44C97FAF2
    .quad 0x3F930CE282F1C751
    .quad 0xC012A4179CEB46C8
    .quad 0xBFB355A8C123B4A0
    .quad 0xC00E86E5705E4C33
    .quad 0x4036B935C04987D7
    .quad 0x3FBC0CA0CDFB526A
    .quad 0x3FAB876CB8580522
    .quad 0xC027B9C5B1CAC0B4
    .quad 0xBFC1431CE11C4661
    .quad 0xC036EEF3C2441C35
    .quad 0x3FD1BCE911688569
    .quad 0xBF87DAAE6D1951E9
    .quad 0xBF668C80238427EB
    .quad 0xBFB9E1ECC082E9B2
    .quad 0x3F96F1BA9F8BA5F4
    .quad 0xBF79E14A4C4B0790
    .quad 0xC0418FBDE33C8C16
    .quad 0x3FFFEDA744ADA7F2
    .quad 0xC014439F8E31C228
    .quad 0x403A461FD0204C2D
    .quad 0x3F55C9420C0E67AD
    .quad 0xC015E94F8A64540D
    .quad 0x3FB80182CC4BFED5
    .quad 0xBFBEE898D46F898C
    .quad 0xBF8DA0DE6B2D4723
    .quad 0xBF8038667307EBA3
    .quad 0x3FB2A0D0DA2410B1
    .quad 0xBFFB030D530C8D42
    .quad 0x3FE473633B3F7912
    .quad 0x3FCE8DE8ECBF655E
    .quad 0xBFCEB5AAFF036ADA
    .quad 0xC0383BFDD2BD352B
    .quad 0x3F8A210E6D73E0BD
    .quad 0x3FE52FD3233B316C
    .quad 0x402CE897A2D05557
    .quad 0x3F6112242E7FE3EB
    .quad 0xBF8DC072732FF08D
    .quad 0x3F58F8E00F0FC208
    .quad 0x403F9C03DD2F6B96
    .quad 0x4043B6C7FCB03D71
    .quad 0x3FFBF14F4F884C97
    .quad 0xBFCB2450F5079BF2
    .quad 0xBF6614A827A002EE
    .quad 0x401E39439D5EAB6E
    .quad 0x402923D9A5DE9514
    .quad 0x3F5508201BD56EF1
    .quad 0xC0484B03EA71F91E
.Lcv6_r:
    .quad 0x3F8206486FB8AC94
    .quad 0x40258769B286A4C6
    .quad 0x3FAEFD20B4621B32
    .quad 0                 /* (an operand with no element points here) */
.Lcv7_l:
    .quad 0xBFAD101ABF24F28E
    .quad 0xBFB9E868DDB352BD
    .quad 0x4016A687946D8F57
    .quad 0x3F849DEA6B702CDF
    .quad 0x3FB4C5B2D96363D4
    .quad 0xBF96E9549AF88135
    .quad 0xC01740CD8621E6F0
    .quad 0x3FD9386D186A02F7
    .quad 0x3FCF5AECF556B7D0
    .quad 0xBF5F1FF61469FED0
    .quad 0x3FA6A62EADF3BF87
    .quad 0xBFE8195B24F1937A
    .quad 0x3FBADB22DEA281E4
    .quad 0x3F658F0829101306
    .quad 0xBFA14D06A1C3F270
    .quad 0xBF9DB866898C7DC2
    .quad 0x3FA8B0E4AC7E2A78
    .quad 0x3FAAD800B5466FB6
    .quad 0xC02E5FA7AF6EA549
    .quad 0xBF504D7606AC81D1
    .quad 0x3FA792E0A09E2F7D
    .quad 0xBFDF3AD1033C07A6
    .quad 0x404C4B93E72D7E75
    .quad 0x3FE7B7113E7E3AD3
    .quad 0x4033D2E1CB906CEB
    .quad 0x3FA499EEA9A34D04
    .quad 0xBF5EC928101421A2
    .quad 0x4043C6A1E70E8199
    .quad 0xBFA0B6A6BDABED42
    .quad 0xC0436DD1F8C957E7
    .quad 0x3FA5835AB9BB7444
    .quad 0x3FA8B252BAE0F71E
    .quad 0xBFDD26A91CBCC20B
    .quad 0x3F9AB1168CB274CE
    .quad 0xBFD9535F06782A17
    .quad 0x4030E8F3DABA3706
    .quad 0x40160BF3881C6457
    .quad 0x3FAF7092A7C29B1E
    .quad 0xBF64C674264119A0
    .quad 0xBFB44910DA883219
    .quad 0x40335603CEEF1D3E
    .quad 0x3FDB384704E04BA7
    .quad 0x3F53022613B1D8AB
    .quad 0x3FFCA9915CFB30CB
    .quad 0x402F1983A6C6F660
    .quad 0x40330F2DC1E8571E
    .quad 0x3FBA66CCC25E20CC
    .quad 0x3FDAE4EF1589FDB6
    .quad 0x403E3551D3F4B266
    .quad 0xBFFE343D43B10CA3
    .quad 0x40310C53D7F27BE1
    .quad 0x3FC4A2E2EF43B81C
    .quad 0x401B8F5198574D81
    .quad 0x400F66436BC3503C
    .quad 0xBF584F520866B88E
    .quad 0x3FDADAB117F9CE69
    .quad 0xBFF6B39F498285E9
    .quad 0x3F90CA148D581958
    .quad 0xBF96A86C88CEA6BF
    .quad 0x4001F38D72F4A0AF
    .quad 0xBFAA4F00AB9CEC5F
    .quad 0x3FE6E4052B10D94C
    .quad 0xC01B1B1D8C1D9C29
    .quad 0x3FA9A906A48D4B27
    .quad 0xBF6A7198235DFCAA
    .quad 0xBFD10DE1114949D8
    .quad 0xC02D6F9DA97940C8
    .quad 0xBFE3183728AF18B6
    .quad 0x4013E285871CBE1C
    .quad 0x403E2D8FC1C923A1
    .quad 0xBFE864552C802361
    .quad 0x404D6F2DE16B1D64
    .quad 0x3FFECA4954E76C0D
    .quad 0xC03C00A5C5043CB7
    .quad 0x4041BD95ED309601
    .quad 0x3FCFD808E87078E5
    .quad 0xBFC0A3A2E224A65E
    .quad 0xBFE1C6CB3AFF8F10
    .quad 0xBFED933F2EE4527B
    .quad 0xBFFBD22F5663C114
    .quad 0xC038469BC046A9F6
    .quad 0x3FFA99475A59A70A
    .quad 0xBF82C57E741D66EC
    .quad 0x3FBD1044CDB81472
    .quad 0xBF96408E99A11147
    .quad 0x3F731FD256DCF9ED
    .quad 0x4041C071F7A8EA39
    .quad 0xBF51FF1A0BD454AA
    .quad 0x3FE6B4FB39799CC9
    .quad 0xC03A31A5D26AA465
    .quad 0xC034D9BFDAE3F88E
    .quad 0xBFEF04D13AF7090E
    .quad 0x403A9CE9D2F4837D
    .quad 0x3F8DD0106AF4110B
    .quad 0x3FB39430DCB777E0
    .quad 0xBF85ED366173691A
    .quad 0xBFC167CAF384CB6B
    .quad 0x3F968B4296A206DC
    .quad 0xC03C4073DD27246C
    .quad 0x402166D9BF8A0EF0
    .quad 0x3F8C624667112A23
    .quad 0xC02C6A77B42F9FBF
    .quad 0xBF7E061256186535
    .quad 0xBFFC8B435C47D1DA
    .quad 0xBFA4C940B605ED3E
    .quad 0xBF878D6A68E7A702
    .quad 0x401B888B933D6889
    .quad 0xBFD1C047137D48CA
    .quad 0xBF77A4DC58146ADD
    .quad 0x404F6909FF9ADFDC
    .quad 0x4014541798D9087B
    .quad 0xBF73291C530974DC
    .quad 0x3FF1C02141687A28
    .quad 0xBFC2AD60E44DB3EC
    .quad 0x3F9CD6EA9B57F768
    .quad 0x3F56D76C045A13D1
    .quad 0xC015AFF39BA473CF
    .quad 0x3F85760A7743C9B7
    .quad 0xBF8E148A7083B476
    .quad 0xBF55B23C082C1A94
    .quad 0xBF7CF0C24FFC3A8C
    .quad 0x3FADFF26AF78032D
    .quad 0xBFB93E20C65BC80F
    .quad 0x3FBA127ED63ED7B8
    .quad 0xBFD4DE010C4FCB9E
    .quad 0x3FFFF03148776424
    .quad 0xC04BCB63F369C86A
    .quad 0xBF8CA01668D43DF7
    .quad 0x40223EC9AA2DD74E
    .quad 0xC044AEC3E9FD60DA
    .quad 0xBF639A2628ACA601
    .quad 0xBFF642ED4480D6B4
    .quad 0xBFB6FAA8DC2EE16C
    .quad 0xBFB45AC0C0981476
    .quad 0xC0078FCD75FFC01B
    .quad 0xBFF0D3D34FF5DC79
    .quad 0xBFB1007CCC2169D2
    .quad 0xC0311E25C602DF86
    .quad 0x3FA252A8B72A4143
    .quad 0x3FC69DECF517FD79
.Lcv7_r:
    .quad 0x3FCD1086F5623F44
    .quad 0xBFB2935CC6C6D6BB
    .quad 0xC0405DADE3405FD7
    .quad 0x3F99E34A8816C727
    .quad 0                 /* (an operand with no element points here) */
.Lcv8_l:
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
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
.Lcv8_r:
    .quad 0x4341C37937E08000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0xC341C37937E08000
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
    .quad 0x0000000000000000
    .quad 0x3FB999999999999A
    .quad 0x3FC999999999999A
    .quad 0x3FD3333333333333
    .quad 0x3FD999999999999A
    .quad 0x3FE0000000000000
    .quad 0x3FE3333333333333
    .quad 0x3FE6666666666666
    .quad 0x3FE999999999999A
    .quad 0x3FECCCCCCCCCCCCD
    .quad 0x3FF0000000000000
    .quad 0x3FF199999999999A
    .quad 0x3FF3333333333333
    .quad 0x3FF4CCCCCCCCCCCD
    .quad 0x3FF6666666666666
    .quad 0x3FF8000000000000
    .quad 0x3FF999999999999A
    .quad 0x3FFB333333333333
    .quad 0x3FFCCCCCCCCCCCCD
    .quad 0                 /* (an operand with no element points here) */
.Lcv9_l:
    .quad 0x3FF0000000000000
.Lcv9_r:
    .quad 0x8000000000000000
    .quad 0x0000000000000000
    .quad 0                 /* (an operand with no element points here) */
.Lcv10_l:
    .quad 0xBFF0000000000000
    .quad 0x4000000000000000
.Lcv10_r:
    .quad 0x0000000000000000
    .quad 0x8000000000000000
    .quad 0                 /* (an operand with no element points here) */
.Lcv11_l:
    .quad 0x7FF0000000000000
    .quad 0x3FF0000000000000
.Lcv11_r:
    .quad 0x0000000000000000
    .quad 0x4014000000000000
    .quad 0x3FF0000000000000
    .quad 0x3FF0000000000000
    .quad 0                 /* (an operand with no element points here) */
.Lcv12_l:
    .quad 0x3F8A57D066C7F55E
.Lcv12_r:
    .quad 0xBF9A583C9D054213
    .quad 0                 /* (an operand with no element points here) */
.Lcv13_l:
    .quad 0xBFC5620EEC71880D
    .quad 0x400248017FB4E26B
    .quad 0xBFD1AAF10B5FB480
    .quad 0xBFFFEB254F029F9D
    .quad 0x3FAE32DCB3B9BEAC
    .quad 0x3FF776574B09E0AF
    .quad 0xBFF0CEEF4AC1DE7E
.Lcv13_r:
    .quad 0x3FE5627B22AED4C3
    .quad 0xC00AF2F568C86669
    .quad 0xBFFB62175A328500
    .quad 0x400530856BA939E5
    .quad 0xC0340767DCF12E38
    .quad 0x3FC658F8E3E30A2A
    .quad 0x40003F95649174F0
    .quad 0xBFDD0B711DE173B1
    .quad 0x4010EA0195D43963
    .quad 0x3F858FB66103A079
    .quad 0x3FBB5250D2C875EA
    .quad 0x3F9591D88799EE6C
    .quad 0xBFF72AA750211A9D
    .quad 0xBF5CFDAE140FF464
    .quad 0x4037A925C168EAFB
    .quad 0xC0222FD1AACAC6CA
    .quad 0xC0262F7FAC95EAC6
    .quad 0xBF6B98E62D7444E1
    .quad 0x3FA66A36BA2EAEF6
    .quad 0x3FC42C6AE2B75FA5
    .quad 0xBFDDD7510B41EFC8
    .quad 0                 /* (an operand with no element points here) */
.Lcv14_l:
    .quad 0x40006C4D721B1ABD
    .quad 0x3F9F53F493F51461
    .quad 0xBF630B7E3A3DF925
    .quad 0xBFAF54CCAB74EDF5
    .quad 0xC04B6081EF048A07
    .quad 0x402587F7A10C0C9E
    .quad 0x401000B38355DD70
    .quad 0xBFB58A02C3894C5C
.Lcv14_r:
    .quad 0xC0206CB9A8586773
    .quad 0x3F87FEE87D08985F
    .quad 0xBF9CC2A48910C9A5
    .quad 0x3FB49A2CC81B883D
    .quad 0x3FD1350D183BF993
    .quad 0x3FE46A9939E53619
    .quad 0x401F71599D2573E2
    .quad 0xBF83BF2C69C87BD8
    .quad 0x400C55FF67E85966
    .quad 0xBF6D9EF828D5A457
    .quad 0x3FCEEB9CFDCA6E1F
    .quad 0x3F5B071C0FA03B1E
    .quad 0x400EB0216D9FE7E1
    .quad 0x3FB405D0CCC1BB37
    .quad 0xBFA23CF6A2E35594
    .quad 0x4003DB97665BF222
    .quad 0                 /* (an operand with no element points here) */
.Lcv15_l:
    .quad 0x404B768BF7C4AD6D
    .quad 0xC02C5FE7A8354657
    .quad 0xC0046C0B691C3DCB
    .quad 0xBF5EBE7407E73C4D
    .quad 0x3FE88E272A4F5562
    .quad 0x40439997F70E388E
    .quad 0x402F3277BBE9DC62
    .quad 0x3F5C3DBE0F705484
    .quad 0x3FE192D72A1FF7F6
    .quad 0x404FB887E29E257C
    .quad 0x3F7AA3285C077199
    .quad 0x3F8EADFE7530926A
    .quad 0xBF5611E80596868D
.Lcv15_r:
    .quad 0xBF6B76F82E01FA23
    .quad 0xC0150ADB9148CA55
    .quad 0xC02E2331B7EF0E4A
    .quad 0x3F6403D4248DD695
    .quad 0x3F7E62B25386C4EE
    .quad 0x40127C398FE76209
    .quad 0xC03EA31DD5B972D4
    .quad 0x402A72E7B5AF8400
    .quad 0xBFE7C1FD39FC796A
    .quad 0xC045AE39F0A7A835
    .quad 0xBFE284E928CC6655
    .quad 0xC0107C5F97A687CF
    .quad 0x4016359B8B1EB525
    .quad 0x401B0DF38573820B
    .quad 0xC01CD0C7845DC02D
    .quad 0xBFE5875D21ED1D7A
    .quad 0xC010826F94E23572
    .quad 0x3F61D55C346BA2E7
    .quad 0x3F70A34C56D36CC5
    .quad 0xC006E96F6B882ADE
    .quad 0x3F69834029AD43EF
    .quad 0x401A89AD86261ECA
    .quad 0x40446611F9F0AE0D
    .quad 0xC0094CBF607B16C1
    .quad 0x3FAC91B6B59DEB00
    .quad 0xBFBFF08EC59124E0
    .quad 0x3FFD74C754B663FF
    .quad 0x402B0253ACAC0753
    .quad 0x3FEA23BD242A7251
    .quad 0x40027C5F716C61FA
    .quad 0x3FF779F55A16DD1A
    .quad 0xC01B11B1906F08AA
    .quad 0xC0231D1FAD30A356
    .quad 0xC02AD71BB9738B14
    .quad 0x403006A1C0A5AEE7
    .quad 0x3F8CC5B669569B45
    .quad 0xBF7E14DA48D055CD
    .quad 0xBFD67FDD0DFC8FCF
    .quad 0xBFE877B920F41677
    .quad 0                 /* (an operand with no element points here) */
.Lcv16_l:
    .quad 0xBF8680CA7D6E401D
    .quad 0x3FA96BDABC75784D
    .quad 0xBF95CC9897FA8270
    .quad 0xC00E281B64598AA5
    .quad 0xBF85BBCC659A20BD
    .quad 0x3F71AB384D10647D
    .quad 0xC04E643BF47DDB53
    .quad 0x3FF2F1795B575CAB
    .quad 0x3FCCFED4FC3417F9
    .quad 0x4027C7C9AA70295A
    .quad 0x3F9E3C74870969CE
    .quad 0xC0442341FD36DF1C
    .quad 0x3F6D9762231553D1
    .quad 0xBF52E88618B39E21
    .quad 0x3F75A70052068703
    .quad 0x401019E598C95A87
.Lcv16_r:
    .quad 0x3FA68136B3AB8CD3
    .quad 0x3FA216CEA588FC4A
    .quad 0xBFCF83BEE6CD52F0
    .quad 0x40136D7B810024ED
    .quad 0xC01B90578ED19049
    .quad 0x40408DD9E5E98DF8
    .quad 0x3F5DD4E20E4D71C6
    .quad 0x3FD126A301968C27
    .quad 0x3FD32DFB0C10996E
    .quad 0x402DBD7BB879AC13
    .quad 0xBFF61E3553CE5E8A
    .quad 0xBFD5F1A31FACD481
    .quad 0xC02DBB15A89D8269
    .quad 0xBF6216163E2548DF
    .quad 0x3F87649865D82AC6
    .quad 0x3FB73322DD7E48D2
    .quad 0x401DABE789085AC8
    .quad 0xBFE4F39737E751EA
    .quad 0x3FEDBFD72525CBAC
    .quad 0xC02047F1AFF0907A
    .quad 0x402F5937B8E2EE03
    .quad 0xBF51E9D01C48D487
    .quad 0xC02A2525BD9A0498
    .quad 0x403721E3DE7667E2
    .quad 0x404972DDE1A2B1F7
    .quad 0x3FEAA93322E96A54
    .quad 0xC01AAE31818DF98B
    .quad 0xBF7EDB4E4F0CE0FA
    .quad 0x3F7696C453A49D6A
    .quad 0x401BA4119A156DB5
    .quad 0x3F57340E07C3E9B1
    .quad 0x3FBDDAB4C0EBABBC
    .quad 0                 /* (an operand with no element points here) */
.Lcv17_l:
    .quad 0x3FD18B090317D2CD
    .quad 0xC03677CDD0B5AA42
    .quad 0xC0372D25C6D8C715
    .quad 0xBFBD91C2C0CBD8FC
    .quad 0x4022E971A0E4EC18
    .quad 0xBFAFBCD8A312906C
    .quad 0x3F6D96002D11DA45
    .quad 0xBFA9A534A73E64D3
    .quad 0xBFB86AD2CE4837FD
    .quad 0xC00FD70B72422D38
    .quad 0xBFA1D5C0B20B6203
    .quad 0xC0199885853D2BCE
    .quad 0x3F751CDC40942115
    .quad 0xBFB9F0A8D16564F4
    .quad 0xBFE03AD13380F19C
    .quad 0xBFF1C5AB545A85DF
    .quad 0x3F56A2841E47EA81
    .quad 0xBFB042C4DF12A3D8
    .quad 0xBFFBB6295B4B1823
    .quad 0x3FE0BB913B914522
    .quad 0x3FFD9A7B57222869
    .quad 0xBF57BC700CDC8C80
    .quad 0xBFD14081131D8CF6
.Lcv17_r:
    .quad 0xBFE18B7539551F83
    .quad 0x402F22C1B9C92E40
    .quad 0x3F50E44C15AB9795
    .quad 0x3FB2D722DD727344
    .quad 0x3FB8BDFCCA1C5BA4
    .quad 0xBF6E9F7A3BEBB9E7
    .quad 0xBF7D06A646E170B8
    .quad 0xBF77DA5E4D7D944F
    .quad 0x3FBE99F8DE24B971
    .quad 0x4015CCBD804BAFF1
    .quad 0xC009B7817ED056BF
    .quad 0xBFAB66E6A7B32133
    .quad 0xC035408FC61C4FAD
    .quad 0xBFC91E38F6D70FB3
    .quad 0xBFF1F8694752955F
    .quad 0xBF98DEE8990F7429
    .quad 0x400AD55F7D2E801E
    .quad 0x3F6811D23B6300ED
    .quad 0xC04ADC61F3782A94
    .quad 0x4049A673F458F616
    .quad 0xBFF52F2F48189816
    .quad 0xBFA949F2B26B8A44
    .quad 0x401FE43981435B23
    .quad 0xBF74F7085C71B902
    .quad 0x3FD654050DA778ED
    .quad 0xC01561D78041AFC8
    .quad 0x4027E79BAE658F18
    .quad 0xBFC2B448F16DBAA1
    .quad 0x401309CB831EC884
    .quad 0xC034CBC3C2BE796F
    .quad 0x3FA6EE26B570F648
    .quad 0x4040A3B7F1684ECE
    .quad 0xBF7D676C4E1229C3
    .quad 0xBFE2681729F96197
    .quad 0xBFC76BA2F73B74CF
    .quad 0x3FEE26D138BB3209
    .quad 0x4024EB1FA4C0FD1A
    .quad 0xC02F5AE7B768AB88
    .quad 0xBFC91DDAF6F75792
    .quad 0xBFC62A88E261C400
    .quad 0x3FB97CDEC60D2902
    .quad 0xBFC9984CF43A21EE
    .quad 0x3FB57C7ECECE50BE
    .quad 0xBFA1ECCAA0FAEA02
    .quad 0x400480C562AD6A7C
    .quad 0x3F61C35E3F9ABD62
    .quad 0xC0032E4F66933C46
    .quad 0x40422B81EB04198C
    .quad 0xC031476DCA43AD8F
    .quad 0xBF75178C540BB2E1
    .quad 0xC01CDE4F86672C67
    .quad 0x3F8C02C069900AC0
    .quad 0xBFC13972E887EDCE
    .quad 0xC023162DB7CB6A51
    .quad 0xBFEB53FD23F63E26
    .quad 0xC006FA1F67E392E8
    .quad 0x3FC47798E0C01ECF
    .quad 0xBFBDC712DFC0DD03
    .quad 0x3F721A3A4A38B5D0
    .quad 0xBFCC2104F40B26F6
    .quad 0x3FCA6860E8459CB4
    .quad 0x3F7B887C463FDC2B
    .quad 0xC01C0C85816CE378
    .quad 0x3FD3BBEB1CA38605
    .quad 0x3FC6061EEBE0A4A4
    .quad 0x40441A73FF64BF68
    .quad 0x3FC603FCEF464F7C
    .quad 0xBFCECA0EE6B80BD9
    .quad 0xBF55C618174A5552
    .quad 0x3FFFF1B553ADFB42
    .quad 0x3FF558594E16AEFF
    .quad 0x3FF730175FC12B5A
    .quad 0xC01687C98A2DB774
    .quad 0xBF5C818606E21FA6
    .quad 0x3F9DED369CFD206F
    .quad 0xBF6B51383B75911C
    .quad 0xC04AADBFEA884E4C
    .quad 0xBFDECED31538BE6A
    .quad 0xBFB611B4D2F02FFF
    .quad 0x40490FEDE3486DD9
    .quad 0xBFEA25752152B022
    .quad 0xBFF97CA94324B9CF
    .quad 0xBF640D8C32BF242D
    .quad 0x3F866A34661768F4
    .quad 0xC04BE29BEBE1A6C7
    .quad 0x3FB31F4AC5067AF9
    .quad 0xBFCB9174E6EF123C
    .quad 0xC00B965379B2BAF7
    .quad 0x3F56185412785812
    .quad 0x3FC37706EB749077
    .quad 0xBF94BF5A91A03ABA
    .quad 0xBF8722C66591F015
    .quad 0x401D57D18B0BF665
    .quad 0x3F5A18A60EB134C1
    .quad 0xBFF6E2F946702DFA
    .quad 0x3F7D47C05E2FD2A7
    .quad 0xBF993C909E417928
    .quad 0xBF76D9E0504B3CB3
    .quad 0x3FE8D2C53A95389A
    .quad 0xBF6996F03B2FFDB2
    .quad 0xC03B54F5D435DD4C
    .quad 0xBFD5A6251CD0EE16
    .quad 0xBFE59999223797FE
    .quad 0xC0295A77AF98975E
    .quad 0x3FDB1E1F06A96DC9
    .quad 0x3F50A59608E33E17
    .quad 0xBFCC23BCF954F6D2
    .quad 0x3FC0B4A2EB12B380
    .quad 0x3FCBF860FEAE941F
    .quad 0xBF97DB7A9CDFF7CD
    .quad 0x3FA85D40A242B18A
    .quad 0xBFC0E320F54BDE10
    .quad 0x3F956AE88504B0D7
    .quad 0xBFFD7C5348C14AB7
    .quad 0x3F9E16389C2B62E4
    .quad 0                 /* (an operand with no element points here) */
.Lcv18_l:
    .quad 0x4008000000000000
.Lcv18_r:
    .quad 0x4010000000000000
    .quad 0                 /* (an operand with no element points here) */
.Lcv19_l:
    .quad 0xC000000000000000
    .quad 0x4014000000000000
    .quad 0x3FF0000000000000
    .quad 0xC008000000000000
    .quad 0x4010000000000000
    .quad 0x0000000000000000
    .quad 0xC010000000000000
    .quad 0x4008000000000000
    .quad 0xBFF0000000000000
    .quad 0xC014000000000000
    .quad 0x4000000000000000
    .quad 0xC000000000000000
    .quad 0x4014000000000000
    .quad 0x3FF0000000000000
    .quad 0xC008000000000000
.Lcv19_r:
    .quad 0xC008000000000000
    .quad 0x4000000000000000
    .quad 0xC000000000000000
    .quad 0x4008000000000000
    .quad 0xBFF0000000000000
    .quad 0x4010000000000000
    .quad 0x0000000000000000
    .quad 0xC010000000000000
    .quad 0x3FF0000000000000
    .quad 0xC008000000000000
    .quad 0                 /* (an operand with no element points here) */
.Lcv20_l:
    .quad 0x3FE0000000000000
    .quad 0xBFD0000000000000
    .quad 0x4000000000000000
    .quad 0x3FF8000000000000
    .quad 0xC008000000000000
    .quad 0x3FC0000000000000
.Lcv20_r:
    .quad 0x3FF0000000000000
    .quad 0x4000000000000000
    .quad 0xBFE0000000000000
    .quad 0x4010000000000000
    .quad 0x3FD0000000000000
    .quad 0xBFF0000000000000
    .quad 0x4020000000000000
    .quad 0xC000000000000000
    .quad 0x3FE0000000000000
    .quad 0x4008000000000000
    .quad 0xC010000000000000
    .quad 0x3FF0000000000000
    .quad 0                 /* (an operand with no element points here) */
    .p2align 3
cases:
    .quad .Lcnv0, ENT_GEMV, 2, 1, 3, .Lcv0_l, 1, 3, 1, .Lcv0_r, 1, 1, 1
    .quad .Lcnv1, ENT_GEMV, 2, 2, 3, .Lcv1_l, 1, 3, 1, .Lcv1_r, 1, 2, 1
    .quad .Lcnv2, ENT_GEMV, 2, 3, 2, .Lcv2_l, 1, 2, 1, .Lcv2_r, 1, 3, 1
    .quad .Lcnv3, ENT_GEMV, 2, 2, 2, .Lcv3_l, 1, 2, 1, .Lcv3_r, 1, 2, 1
    .quad .Lcnv4, ENT_GEMV, 2, 1, 1, .Lcv4_l, 1, 1, 1, .Lcv4_r, 1, 1, 1
    .quad .Lcnv5, ENT_GEMV, 2, 7, 5, .Lcv5_l, 1, 5, 1, .Lcv5_r, 1, 7, 1
    .quad .Lcnv6, ENT_GEMV, 2, 19, 3, .Lcv6_l, 1, 3, 1, .Lcv6_r, 1, 19, 1
    .quad .Lcnv7, ENT_GEMV, 2, 35, 4, .Lcv7_l, 1, 4, 1, .Lcv7_r, 1, 35, 1
    .quad .Lcnv8, ENT_VECMAT, 1, 19, 1, .Lcv8_l, 2, 19, 2, .Lcv8_r, 1, 2, 1
    .quad .Lcnv9, ENT_VECMAT, 1, 1, 1, .Lcv9_l, 2, 1, 2, .Lcv9_r, 1, 2, 1
    .quad .Lcnv10, ENT_VECMAT, 1, 2, 1, .Lcv10_l, 2, 2, 1, .Lcv10_r, 1, 1, 1
    .quad .Lcnv11, ENT_VECMAT, 1, 2, 1, .Lcv11_l, 2, 2, 2, .Lcv11_r, 1, 2, 1
    .quad .Lcnv12, ENT_VECMAT, 1, 1, 1, .Lcv12_l, 2, 1, 1, .Lcv12_r, 1, 1, 1
    .quad .Lcnv13, ENT_VECMAT, 1, 7, 1, .Lcv13_l, 2, 7, 3, .Lcv13_r, 1, 3, 1
    .quad .Lcnv14, ENT_VECMAT, 1, 8, 1, .Lcv14_l, 2, 8, 2, .Lcv14_r, 1, 2, 1
    .quad .Lcnv15, ENT_VECMAT, 1, 13, 1, .Lcv15_l, 2, 13, 3, .Lcv15_r, 1, 3, 1
    .quad .Lcnv16, ENT_VECMAT, 1, 16, 1, .Lcv16_l, 2, 16, 2, .Lcv16_r, 1, 2, 1
    .quad .Lcnv17, ENT_VECMAT, 1, 23, 1, .Lcv17_l, 2, 23, 5, .Lcv17_r, 1, 5, 1
    .quad .Lcnv18, ENT_MATMUL, 2, 1, 1, .Lcv18_l, 2, 1, 1, .Lcv18_r, 2, 1, 1
    .quad .Lcnv19, ENT_MATMUL, 2, 3, 5, .Lcv19_l, 2, 5, 2, .Lcv19_r, 2, 3, 2
    .quad .Lcnv20, ENT_MATMUL, 2, 2, 3, .Lcv20_l, 2, 3, 4, .Lcv20_r, 2, 2, 4
    .quad 0                     /* end of the table */
.Lcnv0: .asciz "mv order"
.Lcnv1: .asciz "mv negzero"
.Lcnv2: .asciz "mv nonfinite"
.Lcnv3: .asciz "mv zero inf"
.Lcnv4: .asciz "mv 1x1"
.Lcnv5: .asciz "mv 7x5"
.Lcnv6: .asciz "mv 19x3"
.Lcnv7: .asciz "mv 35x4"
.Lcnv8: .asciz "vm order"
.Lcnv9: .asciz "vm negzero"
.Lcnv10: .asciz "vm negzero2"
.Lcnv11: .asciz "vm nonfinite"
.Lcnv12: .asciz "vm 1x1"
.Lcnv13: .asciz "vm 7x3"
.Lcnv14: .asciz "vm 8x2"
.Lcnv15: .asciz "vm 13x3"
.Lcnv16: .asciz "vm 16x2"
.Lcnv17: .asciz "vm 23x5"
.Lcnv18: .asciz "mm 1x1"
.Lcnv19: .asciz "mm 3x5x2"
.Lcnv20: .asciz "mm 2x3x4"
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
