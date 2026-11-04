# =====================================================================
# sea/tests/rt/x86_64_linux/rt_lib_abi.s -- the ABI of the five text entries
# (DESIGN.md 2.15.5 "ABI", "Stack"): each case is called with %rbx %rbp %r12-%r15
# holding known patterns and the 128 KiB below %rsp guard-filled; afterwards those
# registers, %rsp and MXCSR's control bits must be unchanged, the direction flag clear,
# and the call, its callees included (open, read, memchr, strtod, sea_alloc, ...), must
# have written at most SEA_STACK_MARGIN bytes below %rsp. Cases: READ_LINES of a short
# file and of a 70000-byte one (the buffer doubled), SPLIT, PARSE_I64 (-2^63, base 36),
# PARSE_F64 (the frame buffer, a 300-byte text through the block, a word), SUBSTR (a
# range, an empty one). Each prints `<label>: ok` (an i64 result, or an f64 result's
# bits as a signed decimal, before the `ok`); an object result is released. A failure
# prints its error bits and exits 1. Fixtures: rt_lib_abi.files/. Heap check: 0 live.
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

# ---- the ABI check ----------------------------------------------------
.equ PAT_RBX, 0x5EA0000000000303
.equ PAT_RBP, 0x5EA0000000000505
.equ PAT_R12, 0x5EA0000000000C0C
.equ PAT_R13, 0x5EA0000000000D0D
.equ PAT_R14, 0x5EA0000000000E0E
.equ PAT_R15, 0x5EA0000000000F0F
.equ GUARD_BYTES, 131072            # guard-filled below the call's return slot
.equ GUARD_WORD, 0xC0FFEE5EA5EA5EA5 # the guard pattern
.equ MXCSR_CTL, 0xFFC0              # MXCSR's control bits (the flags may change)
.equ RFLAGS_DF, 0x400               # the direction flag
.if GUARD_BYTES <= SEA_STACK_MARGIN
    .error "the guard must reach below SEA_STACK_MARGIN"
.endif

    .data
    .p2align 3
.Lres:   .quad 0                    # %rax after the last call
.Lresx:  .quad 0                    # %xmm0's low 64 bits after it
.Lsp:    .quad 0                    # %rsp at the call site
.Lmx0:   .long 0                    # MXCSR before the call
.Lmx1:   .long 0                    # MXCSR after the call
    .p2align 3
depth:   .quad 0                    # the deepest write below a return slot so far
    .text

# probe -- call an entry under the ABI check.
#   Inputs  : %rdi = the entry, %rsi, %rdx, %rcx, %r8 = its first four integer
#             arguments (the site among them)
#   Outputs : %rax = 0, or the sum of: 1 %rsp changed, 2 MXCSR's control
#             bits changed, 4 one of %rbx %rbp %r12-%r15 changed, 8 the
#             direction flag set, 16 the call wrote more than
#             SEA_STACK_MARGIN bytes below its return slot; .Lres / .Lresx =
#             the results; depth = max(depth, the bytes written below the slot)
#   Clobbers: the caller-saved registers
#   Callee-saved used: all of them hold the test patterns during the call
#   Frame   : 8 (%rbp) + 40 (callee-saved) + 8
    .p2align 4
probe:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $8, %rsp                   # %rsp = 0 (mod 16): the call site
    movq %rdi, %r11                 # the entry
    movq %rsi, %r12                 # the arguments, kept across the fill
    movq %rdx, %r13
    movq %rcx, %r14
    movq %r8, %r15
    # The guard: GUARD_BYTES ending at -8(%rsp), the return address's slot.
    leaq -8-GUARD_BYTES(%rsp), %rdi
    movl $GUARD_BYTES/8, %ecx
    movabsq $GUARD_WORD, %rax
    cld
    rep stosq
    stmxcsr .Lmx0(%rip)
    movq %r12, %rdi
    movq %r13, %rsi
    movq %r14, %rdx
    movq %r15, %rcx
    movq %rsp, .Lsp(%rip)
    movabsq $PAT_RBX, %rbx
    movabsq $PAT_RBP, %rbp
    movabsq $PAT_R12, %r12
    movabsq $PAT_R13, %r13
    movabsq $PAT_R14, %r14
    movabsq $PAT_R15, %r15
    call *%r11
    movq %rax, .Lres(%rip)
    movq %xmm0, .Lresx(%rip)
    pushfq
    popq %r8                        # RFLAGS after the call
    stmxcsr .Lmx1(%rip)
    xorl %eax, %eax                 # the error bits
    movabsq $PAT_RBX, %rcx
    cmpq %rcx, %rbx
    jne 1f
    movabsq $PAT_RBP, %rcx
    cmpq %rcx, %rbp
    jne 1f
    movabsq $PAT_R12, %rcx
    cmpq %rcx, %r12
    jne 1f
    movabsq $PAT_R13, %rcx
    cmpq %rcx, %r13
    jne 1f
    movabsq $PAT_R14, %rcx
    cmpq %rcx, %r14
    jne 1f
    movabsq $PAT_R15, %rcx
    cmpq %rcx, %r15
    je 2f
1:  orl $4, %eax
2:  cmpq .Lsp(%rip), %rsp
    je 3f
    orl $1, %eax
    movq .Lsp(%rip), %rsp           # back to the call site's %rsp
3:  leaq 48(%rsp), %rbp             # the frame pointer back (8 + 40 above %rsp)
    movl .Lmx0(%rip), %ecx
    xorl .Lmx1(%rip), %ecx
    testl $MXCSR_CTL, %ecx
    jz 4f
    orl $2, %eax
4:  testq $RFLAGS_DF, %r8
    jz 5f
    orl $8, %eax
    cld
    # The depth: the lowest guard word changed, from the bottom up.
5:  movq .Lsp(%rip), %rdx
    leaq -8-GUARD_BYTES(%rdx), %rdi # the lowest guard word
    leaq -8(%rdx), %rsi             # the return address's slot (excluded)
    movabsq $GUARD_WORD, %rcx
6:  cmpq %rsi, %rdi
    jae 7f
    cmpq (%rdi), %rcx
    jne 7f
    addq $8, %rdi
    jmp 6b
7:  subq %rdi, %rsi                 # 0 when nothing was written
    cmpq depth(%rip), %rsi
    jbe 8f
    movq %rsi, depth(%rip)
8:  cmpq $SEA_STACK_MARGIN, %rsi
    jbe 9f
    orl $16, %eax
9:  addq $8, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

# The case table: label, entry, four arguments, the result kind (0 a value in
# %rax, 1 an object in %rax to release, 2 a value in %xmm0).
.equ CR_LABEL, 0
.equ CR_ENTRY, 8
.equ CR_A0, 16
.equ CR_KIND, 48
.equ CR_SIZE, 56

    .text
    .globl sea_main
    .type sea_main, @function
    .p2align 4
sea_main:
    PROLOGUE
    leaq cases(%rip), %rbx
1:  cmpq $0, CR_LABEL(%rbx)
    je 5f
    movq CR_ENTRY(%rbx), %rdi
    movq CR_A0(%rbx), %rsi
    movq CR_A0+8(%rbx), %rdx
    movq CR_A0+16(%rbx), %rcx
    movq CR_A0+24(%rbx), %r8
    call probe
    movq %rax, %r12                 # the error bits
    movq CR_LABEL(%rbx), %rdi       # `<label>: `
    leaq SEA_STR_BYTES(%rdi), %rdi
    movq CR_LABEL(%rbx), %rax
    movq SEA_STR_LEN(%rax), %rsi
    call sea_out_write
    TXT ": "
    cmpq $1, CR_KIND(%rbx)
    jne 2f
    REL .Lres(%rip)                 # an object: released
    jmp 3f
2:  cmpq $2, CR_KIND(%rbx)
    jne 21f
    movq .Lresx(%rip), %rdi         # an f64: its bits
    jmp 22f
21: movq .Lres(%rip), %rdi          # an i64
22: call put_dec
    TXT " "
3:  testq %r12, %r12
    jnz 4f
    TXT "ok\n"
    addq $CR_SIZE, %rbx
    jmp 1b
4:  TXT "BAD "
    movq %r12, %rdi
    call put_dec
    TXT "\n"
    movl $1, %edi
    call exit@PLT
5:  EPILOGUE

# CASE label, entry, a0, a1, a2, a3, kind
.macro CASE label, entry, a0, a1, a2, a3, kind
    .quad \label, \entry, \a0, \a1, \a2, \a3, \kind
.endm
    .section .data.rel.ro,"aw",@progbits
    .p2align 3
cases:
    CASE .Ln_rl1, sea_read_lines, .Lp_in, 0, 0, 0, 1
    CASE .Ln_rl2, sea_read_lines, .Lp_mid, 0, 0, 0, 1
    CASE .Ln_sp1, sea_split, .Ls_csv, .Lcomma, 0, 0, 1
    CASE .Ln_sp2, sea_split, .Ls_aaa, .Ls_aa, 0, 0, 1
    CASE .Ln_pi1, sea_parse_i64, .Ls_min, 10, 0, 0, 0
    CASE .Ln_pi2, sea_parse_i64, .Ls_zz, 36, 0, 0, 0
    CASE .Ln_pf1, sea_parse_f64, .Ls_15, 0, 0, 0, 2
    CASE .Ln_pf2, sea_parse_f64, .Ls_long, 0, 0, 0, 2
    CASE .Ln_pf3, sea_parse_f64, .Ls_inf, 0, 0, 0, 2
    CASE .Ln_ss1, sea_substr, .Ls_hello, 1, 4, 0, 1
    CASE .Ln_ss2, sea_substr, .Ls_hello, 3, 1, 0, 1
    .quad 0
    SSTR .Ln_rl1, "read_lines in.txt"
    SSTR .Ln_rl2, "read_lines mid.txt"
    SSTR .Ln_sp1, "split a;b;;c"
    SSTR .Ln_sp2, "split aaa aa"
    SSTR .Ln_pi1, "parse_i64 -2^63"
    SSTR .Ln_pi2, "parse_i64 zz base 36"
    SSTR .Ln_pf1, "parse_f64 1.5"
    SSTR .Ln_pf2, "parse_f64 300 digits"
    SSTR .Ln_pf3, "parse_f64 inf"
    SSTR .Ln_ss1, "substr hello 1 4"
    SSTR .Ln_ss2, "substr hello 3 1"
    SSTR .Lp_in, "in.txt"
    SSTR .Lp_mid, "mid.txt"
    SSTR .Ls_csv, "a,b,,c"
    SSTR .Lcomma, ","
    SSTR .Ls_aaa, "aaa"
    SSTR .Ls_aa, "aa"
    SSTR .Ls_min, "-9223372036854775808"
    SSTR .Ls_zz, "zz"
    SSTR .Ls_15, "1.5"
    SSTR .Ls_inf, "inf"
    SSTR .Ls_hello, "hello"
    .p2align 3
.Ls_long:                           # "1" then 299 "0": 1e299, through the block
    .quad SEA_RC_STATIC
    .byte SEA_TAG_STR
    .space 7, 0
    .quad 300
    .ascii "1"
    .fill 299, 1, 0x30
    SSTR .Lfile, "m.sea"
    .p2align 3
    .globl sea_sites
sea_sites:
    .quad .Lfile, 1                 # site 0

    .section .note.GNU-stack,"",@progbits
