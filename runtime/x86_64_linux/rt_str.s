# =====================================================================
# sea/runtime/x86_64_linux/rt_str.s -- string entries (DESIGN.md 4.1,
# 4.5, 4.7.1, 4.8 entries STR_CAT, STR_CMP, STR_LOWER, STR_I64, STR_F64;
# LANGUAGE.md 4.4, 9.2, 10.9). The x86_64-linux twin of
# runtime/arm64_macos/rt_str.s.
#
# Defines (global, rt.inc SEA_ENTRY_LIST):
#   sea_str_cat    (a, b, site) -> a new string: a's bytes, then b's
#   sea_str_cmp    (a, b) -> -1, 0, 1 (unsigned bytes; a proper prefix
#                  is the lesser)
#   sea_str_lower  (s, site) -> a new string, A-Z mapped to a-z
#   sea_str_i64    (v, site) -> a new string of v in decimal
#   sea_str_f64    (x in %xmm0, site in %rdi) -> a new string: nan, inf,
#                  -inf, or C's %.17g of x
# Uses: sea_alloc and sea_live (rt_mem.s), sea_err (rt_err.s), glibc
#   memcpy, memcmp, snprintf through the PLT.
#
# A string is one block of SEA_STR_BYTES + length bytes (DESIGN.md 4.1):
# count 1, SEA_TAG_STR, the other header bytes 0, the length, the bytes.
# Every string returned is new (count 1, counted in sea_live), even when
# an operand is empty. A length above SEA_LIM_STR_BYTES, or no memory, is
# sea_err(SEA_E_OUT_OF_MEMORY, site).
#
# The digits of sea_str_f64 come from glibc's snprintf("%.17g"), as the
# finite conversions of sea_printf do (rt_fmt.s; DESIGN.md 4.7.1: exact,
# correctly rounded, the C locale), so they are the arm64 runtime's
# bytes; the non-finite values are spelled by this file, never by C.
# =====================================================================
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

# Bytes of the text buffers: sea_str_i64 writes at most 20 bytes
# ("-9223372036854775808"); %.17g at most 24 ("-2.2250738585072014e-308")
# plus the NUL.
.equ RT_STR_TBUF,       32
# The bits of +Inf shifted left by one: |bits| << 1 above it is NaN,
# equal to it +-Inf.
.equ RT_STR_INF2,       0xFFE0000000000000

    .text

# ---------------------------------------------------------------------
# .Lrt_str_new -- a new string object of a given length.
#   Purpose : the length check, the block, the header (count 1,
#             SEA_TAG_STR, length), the live count + 1. The bytes are
#             left for the caller to write.
#   Inputs  : %rdi = length, %rsi = site
#   Outputs : %rax = the string
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = length (saved and restored), %rbp = frame
#             pointer
#   Frame   : 24 bytes (%rbp %rbx + 8 pad)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_str_new:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp                   # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    cmpq $SEA_LIM_STR_BYTES, %rbx
    ja .Lrt_str_new_oom             # longer than a str may be
    leaq SEA_STR_BYTES(%rbx), %rdi
    call sea_alloc                  # (%rsi = site); out of memory there
    movq $1, SEA_STR_RC(%rax)       # count 1
    movq $0, SEA_STR_TAG(%rax)      # tag and the 7 bytes after it 0 ...
    movb $SEA_TAG_STR, SEA_STR_TAG(%rax) # ... then the tag
    movq %rbx, SEA_STR_LEN(%rax)
    incq sea_live(%rip)             # one more live object
    addq $8, %rsp
    popq %rbx
    popq %rbp
    ret
.Lrt_str_new_oom:
    movl $SEA_E_OUT_OF_MEMORY, %edi
    xorl %edx, %edx                 # (%rsi = site)
    call sea_err                    # noreturn
    ud2

# ---------------------------------------------------------------------
# .Lrt_str_of -- a new string holding a copy of some bytes.
#   Inputs  : %rdi = bytes, %rsi = length, %rdx = site
#   Outputs : %rax = the string
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = bytes, %r12 = length,
#             %r13 = the string, %rbp = frame pointer
#   Frame   : 32 bytes (%rbp %rbx %r12 %r13); %rsp = 0 (mod 16) at calls
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_str_of:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    subq $8, %rsp                   # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
    movq %rsi, %rdi
    movq %rdx, %rsi
    call .Lrt_str_new
    movq %rax, %r13
    leaq SEA_STR_BYTES(%r13), %rdi
    movq %rbx, %rsi
    movq %r12, %rdx
    call memcpy@PLT                 # the bytes
    movq %r13, %rax
    addq $8, %rsp
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

# ---------------------------------------------------------------------
# sea_str_cat -- entry STR_CAT (DESIGN.md 4.8).
#   Purpose : a new string of a's bytes followed by b's.
#   Inputs  : %rdi = a, %rsi = b, %rdx = site
#   Outputs : %rax = the new string
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = a, %r12 = b, %r13 =
#             the new string, %rbp = frame pointer
#   Frame   : 32 bytes (%rbp %rbx %r12 %r13) + 8 pad = 40 bytes
# ---------------------------------------------------------------------
    .globl sea_str_cat
    .type sea_str_cat, @function
    .p2align 4
sea_str_cat:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    subq $8, %rsp                   # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
    movq SEA_STR_LEN(%rbx), %rdi
    addq SEA_STR_LEN(%r12), %rdi    # the sum (each <= 2^31 - 1: no wrap)
    movq %rdx, %rsi
    call .Lrt_str_new               # longer than SEA_LIM_STR_BYTES: out of memory
    movq %rax, %r13
    leaq SEA_STR_BYTES(%r13), %rdi  # a's bytes first
    leaq SEA_STR_BYTES(%rbx), %rsi
    movq SEA_STR_LEN(%rbx), %rdx
    call memcpy@PLT
    leaq SEA_STR_BYTES(%r13), %rdi  # then b's
    addq SEA_STR_LEN(%rbx), %rdi
    leaq SEA_STR_BYTES(%r12), %rsi
    movq SEA_STR_LEN(%r12), %rdx
    call memcpy@PLT
    movq %r13, %rax
    addq $8, %rsp
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret
    .size sea_str_cat, . - sea_str_cat

# ---------------------------------------------------------------------
# sea_str_cmp -- entry STR_CMP (DESIGN.md 4.8, LANGUAGE.md 4.4).
#   Purpose : compare the bytes as unsigned values (memcmp over the
#             shorter length); equal so far, the shorter string is the
#             lesser (no padding).
#   Inputs  : %rdi = a, %rsi = b
#   Outputs : %rax = -1, 0 or 1 as a < b, a = b, a > b
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = a, %r12 = b, %rbp =
#             frame pointer
#   Frame   : 24 bytes (%rbp %rbx %r12)
# ---------------------------------------------------------------------
    .globl sea_str_cmp
    .type sea_str_cmp, @function
    .p2align 4
sea_str_cmp:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12                      # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
    movq SEA_STR_LEN(%rbx), %rdx
    cmpq SEA_STR_LEN(%r12), %rdx
    cmovaq SEA_STR_LEN(%r12), %rdx  # n = min(len a, len b)
    leaq SEA_STR_BYTES(%rbx), %rdi
    leaq SEA_STR_BYTES(%r12), %rsi
    call memcmp@PLT                 # unsigned-char order; 0 for n = 0
    testl %eax, %eax
    jnz 1f
    movq SEA_STR_LEN(%rbx), %rax    # a common prefix: the lengths decide
    cmpq SEA_STR_LEN(%r12), %rax
    movl $0, %eax
    movl $-1, %ecx
    movl $1, %edx
    cmovbl %ecx, %eax               # a shorter: -1
    cmoval %edx, %eax               # a longer: 1
    movslq %eax, %rax
    jmp 2f
1:  movl $-1, %ecx                  # the sign of memcmp's result
    movl $1, %edx
    cmovsl %ecx, %eax               # (testl set SF)
    cmovgl %edx, %eax
    movslq %eax, %rax
2:  popq %r12
    popq %rbx
    popq %rbp
    ret
    .size sea_str_cmp, . - sea_str_cmp

# ---------------------------------------------------------------------
# sea_str_lower -- entry STR_LOWER (DESIGN.md 4.8, LANGUAGE.md 10.9).
#   Purpose : a new string, the bytes 0x41-0x5A (A-Z) replaced by
#             0x61-0x7A (a-z), every other byte unchanged.
#   Inputs  : %rdi = s, %rsi = site
#   Outputs : %rax = the new string
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = s (saved and restored), %rbp = frame
#             pointer
#   Frame   : 24 bytes (%rbp %rbx + 8 pad)
# ---------------------------------------------------------------------
    .globl sea_str_lower
    .type sea_str_lower, @function
    .p2align 4
sea_str_lower:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp                   # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq SEA_STR_LEN(%rbx), %rdi
    call .Lrt_str_new               # (%rsi = site)
    movq SEA_STR_LEN(%rbx), %rcx    # bytes left
    leaq SEA_STR_BYTES(%rbx), %rsi  # source
    leaq SEA_STR_BYTES(%rax), %rdi  # destination
1:  testq %rcx, %rcx
    jz 3f
    movzbl (%rsi), %edx
    leal -65(%rdx), %r8d            # byte - 'A'
    cmpl $25, %r8d
    ja 2f                           # not A-Z (unsigned: below 'A' too)
    addl $32, %edx                  # to lower case
2:  movb %dl, (%rdi)
    incq %rsi
    incq %rdi
    decq %rcx
    jmp 1b
3:  addq $8, %rsp
    popq %rbx
    popq %rbp
    ret
    .size sea_str_lower, . - sea_str_lower

# ---------------------------------------------------------------------
# sea_str_i64 -- entry STR_I64 (DESIGN.md 4.8, LANGUAGE.md 10.9).
#   Purpose : a new string of v in decimal: '-' before a negative value,
#             no leading zeros, -9223372036854775808 for -2^63.
#   Inputs  : %rdi = v, %rsi = site
#   Outputs : %rax = the new string
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbp = frame pointer
#   Frame   : 8 bytes (%rbp) + RT_STR_TBUF (digits at 0(%rsp)) = 40 bytes
# ---------------------------------------------------------------------
    .globl sea_str_i64
    .type sea_str_i64, @function
    .p2align 4
sea_str_i64:
    pushq %rbp
    movq %rsp, %rbp
    subq $RT_STR_TBUF, %rsp         # %rsp = 0 (mod 16)
    movq %rsi, %r9                  # site
    leaq RT_STR_TBUF(%rsp), %r8     # digits right to left from the end
    movq %rdi, %rax
    xorl %r10d, %r10d               # negative?
    testq %rax, %rax
    jns 1f
    negq %rax                       # magnitude as unsigned (2^63 stays exact)
    movl $1, %r10d
1:  movl $10, %ecx
2:  xorl %edx, %edx
    divq %rcx                       # %rdx = the next digit
    addb $48, %dl                   # '0'
    decq %r8
    movb %dl, (%r8)
    testq %rax, %rax
    jnz 2b
    testl %r10d, %r10d
    jz 3f
    decq %r8
    movb $45, (%r8)                 # '-'
3:  movq %r8, %rdi                  # the text
    leaq RT_STR_TBUF(%rsp), %rsi
    subq %r8, %rsi                  # its length
    movq %r9, %rdx
    call .Lrt_str_of
    movq %rbp, %rsp
    popq %rbp
    ret
    .size sea_str_i64, . - sea_str_i64

# ---------------------------------------------------------------------
# sea_str_f64 -- entry STR_F64 (DESIGN.md 4.8, LANGUAGE.md 10.9).
#   Purpose : a new string: `nan` for every NaN (any sign or payload),
#             `inf` for +Inf, `-inf` for -Inf, otherwise C's %.17g of x
#             (snprintf; `0.10000000000000001`, `-0`, `100`).
#   Inputs  : %xmm0 = x, %rdi = site
#   Outputs : %rax = the new string
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = site (saved and restored), %rbp = frame
#             pointer
#   Frame   : 16 bytes (%rbp %rbx) + 8 pad + RT_STR_TBUF (text at
#             0(%rsp)) = 56 bytes
# ---------------------------------------------------------------------
    .globl sea_str_f64
    .type sea_str_f64, @function
    .p2align 4
sea_str_f64:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $(RT_STR_TBUF + 8), %rsp   # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %xmm0, %rax
    movq %rax, %rcx
    shlq $1, %rcx                   # |bits| << 1
    movabsq $RT_STR_INF2, %rdx
    cmpq %rdx, %rcx
    jb .Lrt_str_f64_finite
    ja .Lrt_str_f64_nan             # above Inf: NaN
    testq %rax, %rax
    js .Lrt_str_f64_neginf
    leaq .Lrt_str_s_inf(%rip), %rdi # +Inf
    movl $3, %esi
    jmp .Lrt_str_f64_make
.Lrt_str_f64_neginf:
    leaq .Lrt_str_s_neginf(%rip), %rdi
    movl $4, %esi
    jmp .Lrt_str_f64_make
.Lrt_str_f64_nan:
    leaq .Lrt_str_s_nan(%rip), %rdi
    movl $3, %esi
    jmp .Lrt_str_f64_make
.Lrt_str_f64_finite:
    # snprintf(buf, RT_STR_TBUF, "%.17g", x): variadic, one vector
    # register used (%al = 1), x still in %xmm0.
    movq %rsp, %rdi
    movl $RT_STR_TBUF, %esi
    leaq .Lrt_str_s_g17(%rip), %rdx
    movl $1, %eax
    call snprintf@PLT
    movq %rsp, %rdi
    movslq %eax, %rsi               # the text's length (<= 24)
.Lrt_str_f64_make:
    movq %rbx, %rdx
    call .Lrt_str_of
    addq $(RT_STR_TBUF + 8), %rsp
    popq %rbx
    popq %rbp
    ret
    .size sea_str_f64, . - sea_str_f64

    .section .rodata
.Lrt_str_s_g17:     .asciz "%.17g"
.Lrt_str_s_nan:     .ascii "nan"
.Lrt_str_s_inf:     .ascii "inf"
.Lrt_str_s_neginf:  .ascii "-inf"

    .section .note.GNU-stack,"",@progbits
