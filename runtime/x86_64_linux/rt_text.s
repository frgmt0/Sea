# =====================================================================
# sea/runtime/x86_64_linux/rt_text.s -- the text entries of phase L
# (LANGUAGE.md 10.9; DESIGN.md 2.15.2, 2.15.5, 2.15.6; L-mh, L-mi, L-mj,
# L-mk). The x86_64-linux twin of runtime/arm64_macos/rt_text.s.
#
# Defines (global, rt.inc SEA_ENTRY_LIST):
#   sea_split     (s, sep, site) -> a new str[] of the fields of s
#   sea_parse_i64 (s, base, site) -> the i64 written in s
#   sea_parse_f64 (s, site) -> the f64 written in s, in %xmm0
#   sea_substr    (s, lo, hi, site) -> a new string of s's bytes lo..hi-1
# Uses: sea_str_make (rt_str.s), sea_arr_new (rt_arr.s), sea_alloc and
#   sea_free_block (rt_mem.s), sea_err (rt_err.s); glibc memchr, memcmp,
#   memcpy, strtod through the PLT.
#
# Every argument object is borrowed; every result object is new and
# owned (count 1, counted in sea_live): a string from sea_str_make, the
# vector from ARR_NEW(SEA_EK_STR, 1, count, 1, site), whose elements
# start null and are filled in order (an error part-way ends the
# process). Every failure is sea_err(code, site, slots) and never
# returns: SPLIT_SEP (no slot), ARRAY_SIZE (through ARR_NEW),
# PARSE_BASE {base}, PARSE_I64 {s, base}, PARSE_F64 {s}, INDEX_OOB
# {index, 0, len(s)}, OUT_OF_MEMORY (through sea_alloc / sea_str_make).
#
# SPLIT scans for the matches of sep with memchr (the next byte equal
# to sep's first) and memcmp (the rest), which finds the same leftmost
# match at or after i as the byte-by-byte scan of DESIGN.md 2.15.6, so
# the occurrences are non-overlapping and found left to right.
#
# PARSE_F64 checks the decimal grammar of LANGUAGE.md 10.9 itself, then
# converts with glibc's strtod in the C locale (the runtime never calls
# setlocale) on a NUL-terminated copy: in a RTT_FBUF-byte frame buffer
# when n < RTT_FBUF, else in an uncounted block of n + 1 bytes freed
# before the entry returns or reports. MXCSR is never changed, so strtod
# rounds to nearest (L-mj). The host's ERANGE is ignored.
# =====================================================================
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

# parse_f64's frame text buffer (L-mu: a local equate, no output depends
# on it).
.equ RTT_FBUF,          256
# The quiet NaN of Sea's `nan`, +Inf and -Inf (bits).
.equ RTT_NAN,           0x7FF8000000000000
.equ RTT_PINF,          0x7FF0000000000000
.equ RTT_NINF,          0xFFF0000000000000
# The word table: records of RTT_W_SIZE bytes, the length at 0, the
# bytes at 1 (up to 4), the result bits at 8.
.equ RTT_W_SIZE,        16
.equ RTT_W_COUNT,       8

    .text

# ---------------------------------------------------------------------
# .Lrt_text_raise -- sea_err(code, site, {a, b, c}); noreturn.
#   Inputs  : %edi = code, %rsi = site, %rdx, %rcx, %r8 = slots 0-2
#             (the ones the code's args letters do not name are unused)
#   Outputs : never returns
#   Frame   : 8 bytes (%rbp), %rsp rounded down to 16, a 32-byte slot
#             vector at 0(%rsp)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_text_raise:
    pushq %rbp
    movq %rsp, %rbp
    andq $-16, %rsp                 # noreturn: align however we came here
    subq $32, %rsp
    movq %rdx, 0(%rsp)              # slot 0
    movq %rcx, SEA_SLOT_SIZE(%rsp)  # slot 1
    movq %r8, 2*SEA_SLOT_SIZE(%rsp) # slot 2
    movq %rsp, %rdx
    call sea_err                    # noreturn
    ud2

# ---------------------------------------------------------------------
# .Lrt_text_find -- the leftmost match of a separator at or after i.
#   Purpose : the least j >= i with j + m <= n and hay[j .. j+m-1] equal
#             to sep byte for byte, or -1 when there is none.
#   Inputs  : %rdi = hay's bytes, %rsi = n, %rdx = i (0 <= i <= n),
#             %rcx = sep's bytes, %r8 = m (>= 1)
#   Outputs : %rax = j, or -1
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = hay, %r12 = n, %r13 =
#             i, %r14 = sep, %r15 = m, %rbp = frame pointer
#   Frame   : 48 bytes (%rbp %rbx %r12-%r15) + 8 pad = 56 bytes
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_text_find:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $8, %rsp                   # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
    movq %rdx, %r13
    movq %rcx, %r14
    movq %r8, %r15
.Lrt_text_find_loop:
    # A match at i needs i + m <= n: else there is none.
    leaq (%r13,%r15), %rax
    cmpq %r12, %rax
    ja .Lrt_text_find_none
    # The next candidate: memchr(hay + i, sep[0], n - m + 1 - i).
    leaq (%rbx,%r13), %rdi
    movzbl (%r14), %esi
    movq %r12, %rdx
    subq %r15, %rdx
    incq %rdx
    subq %r13, %rdx                 # positions j with j + m <= n left
    call memchr@PLT
    testq %rax, %rax
    jz .Lrt_text_find_none
    subq %rbx, %rax
    movq %rax, %r13                 # i = the candidate's position
    # The other m - 1 bytes: memcmp(hay + i + 1, sep + 1, m - 1).
    leaq 1(%rbx,%r13), %rdi
    leaq 1(%r14), %rsi
    leaq -1(%r15), %rdx
    call memcmp@PLT                 # 0 for m = 1
    testl %eax, %eax
    jz .Lrt_text_find_hit
    incq %r13                       # no match at i: go on from i + 1
    jmp .Lrt_text_find_loop
.Lrt_text_find_hit:
    movq %r13, %rax
    jmp .Lrt_text_find_ret
.Lrt_text_find_none:
    movq $-1, %rax
.Lrt_text_find_ret:
    addq $8, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

# ---------------------------------------------------------------------
# sea_split -- entry SPLIT (DESIGN.md 2.15.5, 2.15.6; L-mh).
#   Purpose : m = len(sep) = 0 is SPLIT_SEP; else the non-overlapping
#             occurrences of sep in s, left to right, counted (c), the
#             vector of c + 1 elements (ARRAY_SIZE through ARR_NEW), and
#             each field (before the first occurrence, between two,
#             after the last; empty ones kept) a new string.
#   Inputs  : %rdi = s, %rsi = sep (both borrowed), %rdx = site
#   Outputs : %rax = the new str[] (count 1)
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = s, %r12 = sep, %r13 =
#             site, %r14 = the scan position / field start, %r15 = the
#             vector, %rbp = frame pointer; locals: 0(%rsp) = the
#             occurrence count / the element index, 8(%rsp) = the match
#   Frame   : 48 bytes (%rbp %rbx %r12-%r15) + 24 = 72 bytes
# ---------------------------------------------------------------------
    .globl sea_split
    .type sea_split, @function
    .p2align 4
sea_split:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    subq $24, %rsp                  # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
    movq %rdx, %r13
    cmpq $0, SEA_STR_LEN(%r12)
    je .Lrt_text_split_empty        # an empty separator
    # Pass 1: count the occurrences (c at 0(%rsp)), i in %r14.
    movq $0, 0(%rsp)
    xorl %r14d, %r14d
.Lrt_text_split_count:
    leaq SEA_STR_BYTES(%rbx), %rdi
    movq SEA_STR_LEN(%rbx), %rsi
    movq %r14, %rdx
    leaq SEA_STR_BYTES(%r12), %rcx
    movq SEA_STR_LEN(%r12), %r8
    call .Lrt_text_find
    testq %rax, %rax
    js 1f                           # no more occurrences
    incq 0(%rsp)                    # c + 1
    addq SEA_STR_LEN(%r12), %rax
    movq %rax, %r14                 # i = j + m
    jmp .Lrt_text_split_count
    # The vector of c + 1 elements (count > SEA_LIM_EXTENT: ARRAY_SIZE).
1:  movl $SEA_EK_STR, %edi
    movl $1, %esi
    movq 0(%rsp), %rdx
    incq %rdx
    movl $1, %ecx
    movq %r13, %r8
    call sea_arr_new
    movq %rax, %r15
    # Pass 2: b (field start) in %r14, the element index at 0(%rsp).
    movq $0, 0(%rsp)
    xorl %r14d, %r14d
.Lrt_text_split_fill:
    leaq SEA_STR_BYTES(%rbx), %rdi
    movq SEA_STR_LEN(%rbx), %rsi
    movq %r14, %rdx
    leaq SEA_STR_BYTES(%r12), %rcx
    movq SEA_STR_LEN(%r12), %r8
    call .Lrt_text_find
    testq %rax, %rax
    js 2f                           # the last field follows
    movq %rax, 8(%rsp)              # the match j
    leaq SEA_STR_BYTES(%rbx,%r14), %rdi
    movq %rax, %rsi
    subq %r14, %rsi                 # s[b .. j-1] (empty when b = j)
    movq %r13, %rdx
    call sea_str_make
    movq SEA_ARR_DATA(%r15), %rcx
    movq 0(%rsp), %rdx
    movq %rax, (%rcx,%rdx,8)        # the next element
    incq 0(%rsp)
    movq 8(%rsp), %r14
    addq SEA_STR_LEN(%r12), %r14    # b = j + m
    jmp .Lrt_text_split_fill
    # The last field s[b .. n-1], a new string also when it is all of s.
2:  leaq SEA_STR_BYTES(%rbx,%r14), %rdi
    movq SEA_STR_LEN(%rbx), %rsi
    subq %r14, %rsi
    movq %r13, %rdx
    call sea_str_make
    movq SEA_ARR_DATA(%r15), %rcx
    movq 0(%rsp), %rdx
    movq %rax, (%rcx,%rdx,8)
    movq %r15, %rax
    addq $24, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret
.Lrt_text_split_empty:
    movl $SEA_E_SPLIT_SEP, %edi
    movq %r13, %rsi
    call .Lrt_text_raise            # noreturn
    ud2
    .size sea_split, . - sea_split

# ---------------------------------------------------------------------
# sea_substr -- entry SUBSTR (DESIGN.md 2.15.5, 2.15.6; L-mk).
#   Purpose : lo >= hi: a new empty string, whatever lo and hi are; else
#             lo outside 0 .. n-1 is INDEX_OOB {lo, 0, n}, then hi - 1
#             >= n is INDEX_OOB {hi - 1, 0, n} (hi - 1 cannot overflow:
#             hi > lo >= 0); else a new string of s[lo .. hi-1].
#   Inputs  : %rdi = s (borrowed), %rsi = lo, %rdx = hi, %rcx = site
#   Outputs : %rax = the new string
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbp = frame pointer
#   Frame   : 8 bytes (%rbp); %rsp = 0 (mod 16) at the call
# ---------------------------------------------------------------------
    .globl sea_substr
    .type sea_substr, @function
    .p2align 4
sea_substr:
    pushq %rbp
    movq %rsp, %rbp
    cmpq %rdx, %rsi
    jge .Lrt_text_substr_empty      # an empty range never fails
    movq SEA_STR_LEN(%rdi), %r9     # n
    testq %rsi, %rsi
    js .Lrt_text_substr_lo          # lo < 0
    cmpq %r9, %rsi
    jge .Lrt_text_substr_lo         # lo >= n
    leaq -1(%rdx), %rax
    cmpq %r9, %rax
    jge .Lrt_text_substr_hi         # hi - 1 >= n
    # s[lo .. hi-1]: sea_str_make(bytes + lo, hi - lo, site).
    subq %rsi, %rdx
    leaq SEA_STR_BYTES(%rdi,%rsi), %rdi
    movq %rdx, %rsi
    movq %rcx, %rdx
    call sea_str_make
    popq %rbp
    ret
.Lrt_text_substr_empty:
    leaq SEA_STR_BYTES(%rdi), %rdi  # no byte is read
    xorl %esi, %esi
    movq %rcx, %rdx
    call sea_str_make
    popq %rbp
    ret
.Lrt_text_substr_lo:
    movq %rsi, %rdx                 # slot 0: lo
    jmp 1f
.Lrt_text_substr_hi:
    movq %rax, %rdx                 # slot 0: hi - 1
1:  movq %rcx, %rsi                 # site
    xorl %ecx, %ecx                 # slot 1: dimension 0
    movq %r9, %r8                   # slot 2: the extent n
    movl $SEA_E_INDEX_OOB, %edi
    call .Lrt_text_raise            # noreturn
    ud2
    .size sea_substr, . - sea_substr

# ---------------------------------------------------------------------
# sea_parse_i64 -- entry PARSE_I64 (DESIGN.md 2.15.5, 2.15.6; L-mi).
#   Purpose : base outside 2 .. 36 is PARSE_BASE {base}; then s must be
#             an optional + or - and one or more digits of the base
#             (0-9, a-z, A-Z as 0-35), the value in -2^63 .. 2^63 - 1;
#             else PARSE_I64 {s, base}. The magnitude is accumulated
#             negatively (a = a * base - d), each step tested first:
#             a < ceil((-2^63 + d) / base) = -((2^63 - d) div base)
#             (unsigned division) is out of range; so -2^63 is exact.
#   Inputs  : %rdi = s (borrowed), %rsi = base, %rdx = site
#   Outputs : %rax = the value
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbp = frame pointer; -8(%rbp) = s (for the
#             error)
#   Frame   : 24 bytes (%rbp, s, 8 pad); the error paths call
#             .Lrt_text_raise
# ---------------------------------------------------------------------
    .globl sea_parse_i64
    .type sea_parse_i64, @function
    .p2align 4
sea_parse_i64:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rdi                      # s at -8(%rbp), for the error
    subq $8, %rsp                   # %rsp = 0 (mod 16)
    movq %rdx, %r11                 # site
    leaq -2(%rsi), %rax
    cmpq $34, %rax
    ja .Lrt_text_pi_base            # base - 2 above 34 (unsigned): not 2 .. 36
    movq SEA_STR_LEN(%rdi), %r8     # n
    leaq SEA_STR_BYTES(%rdi), %r9   # the byte cursor
    leaq (%r9,%r8), %r10            # the end
    xorl %ecx, %ecx                 # %rcx = 1 for a '-'
    cmpq %r10, %r9
    je .Lrt_text_pi_bad             # "": no digit
    movzbl (%r9), %eax
    cmpl $43, %eax                  # '+'
    je 1f
    cmpl $45, %eax                  # '-'
    jne 2f
    movl $1, %ecx
1:  incq %r9                        # past the sign
    cmpq %r10, %r9
    je .Lrt_text_pi_bad             # a sign alone: no digit
2:  xorl %edi, %edi                 # a = 0 (minus the magnitude)
.Lrt_text_pi_loop:
    cmpq %r10, %r9
    je .Lrt_text_pi_done
    movzbl (%r9), %eax
    # The digit value: 0-9, a-z, A-Z; anything else has none (36).
    leal -48(%rax), %r8d            # c - '0'
    cmpl $9, %r8d
    jbe 3f
    leal -97(%rax), %r8d            # c - 'a'
    cmpl $25, %r8d
    jbe 4f
    leal -65(%rax), %r8d            # c - 'A'
    cmpl $25, %r8d
    ja .Lrt_text_pi_bad
4:  addl $10, %r8d                  # a-z, A-Z: 10-35
3:  movslq %r8d, %r8                # d
    cmpq %rsi, %r8
    jae .Lrt_text_pi_bad            # d >= base
    # The pre-test: lim = -((2^63 - d) div base); a < lim is out of range.
    movabsq $0x8000000000000000, %rax
    subq %r8, %rax                  # 2^63 - d (unsigned)
    xorl %edx, %edx
    divq %rsi
    negq %rax                       # lim
    cmpq %rax, %rdi
    jl .Lrt_text_pi_bad             # a < lim
    imulq %rsi, %rdi
    subq %r8, %rdi                  # a = a * base - d (>= -2^63)
    incq %r9
    jmp .Lrt_text_pi_loop
.Lrt_text_pi_done:
    movq %rdi, %rax
    testl %ecx, %ecx
    jnz 5f                          # '-': the value is a
    movabsq $0x8000000000000000, %r8
    cmpq %r8, %rax
    je .Lrt_text_pi_bad             # 2^63 without '-': out of range
    negq %rax                       # else -a
5:  movq %rbp, %rsp
    popq %rbp
    ret
.Lrt_text_pi_bad:
    movq -8(%rbp), %rdx             # slot 0: s
    movq %rsi, %rcx                 # slot 1: the base
    movq %r11, %rsi
    movl $SEA_E_PARSE_I64, %edi
    call .Lrt_text_raise            # noreturn
    ud2
.Lrt_text_pi_base:
    movq %rsi, %rdx                 # slot 0: the base
    movq %r11, %rsi
    movl $SEA_E_PARSE_BASE, %edi
    call .Lrt_text_raise            # noreturn
    ud2
    .size sea_parse_i64, . - sea_parse_i64

# ---------------------------------------------------------------------
# .Lrt_text_digits -- skip a run of decimal digits.
#   Inputs  : %rsi = cursor, %rdx = end
#   Outputs : %rsi = past the run, %rax = the number of digits
#   Clobbers: %rax, %rcx (a leaf: no frame)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_text_digits:
    xorl %eax, %eax
1:  cmpq %rdx, %rsi
    je 2f
    movzbl (%rsi), %ecx
    subl $48, %ecx                  # c - '0'
    cmpl $9, %ecx
    ja 2f                           # not 0-9
    incq %rsi
    incq %rax
    jmp 1b
2:  ret

# ---------------------------------------------------------------------
# sea_parse_f64 -- entry PARSE_F64 (DESIGN.md 2.15.5, 2.15.6; L-mj).
#   Purpose : (1) the eight words (length first, then the bytes): +Inf,
#             -Inf or the quiet NaN 0x7FF8000000000000; (2) else the
#             decimal grammar of LANGUAGE.md 10.9 over all n bytes,
#               [ "+" | "-" ] ( digits [ "." [ digits ] ] | "." digits )
#               [ ( "e" | "E" ) [ "+" | "-" ] digits ]
#             a failure is PARSE_F64 {s}; (3) a NUL-terminated copy (the
#             frame buffer when n < RTT_FBUF, else an uncounted block of
#             n + 1 bytes), x = strtod(copy, &end), end = copy + n checked
#             (a guard: PARSE_F64), the block freed, x returned.
#   Inputs  : %rdi = s (borrowed), %rsi = site
#   Outputs : %xmm0 = the value
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = s, %r12 = site, %r13
#             = the copy, %r14 = the block's size (0: the frame buffer),
#             %rbp = frame pointer; locals: 0(%rsp) = the copy's end
#             from strtod, 8(%rsp) = x, 16(%rsp) .. = the text buffer
#   Frame   : 40 bytes (%rbp %rbx %r12-%r14) + 16 + RTT_FBUF = 312 bytes
# ---------------------------------------------------------------------
    .globl sea_parse_f64
    .type sea_parse_f64, @function
    .p2align 4
sea_parse_f64:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    subq $(RTT_FBUF + 16), %rsp     # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
    # (1) The words: each record's length, then its bytes.
    movq SEA_STR_LEN(%rbx), %r9     # n
    leaq .Lrt_text_words(%rip), %r8
    movl $RTT_W_COUNT, %r10d
.Lrt_text_pf_word:
    movzbl (%r8), %ecx              # the word's length
    cmpq %rcx, %r9
    jne 2f
    xorl %edx, %edx                 # compare its bytes
1:  cmpq %rcx, %rdx
    je .Lrt_text_pf_wordhit
    movzbl SEA_STR_BYTES(%rbx,%rdx), %eax
    cmpb 1(%r8,%rdx), %al
    jne 2f
    incq %rdx
    jmp 1b
2:  addq $RTT_W_SIZE, %r8
    decl %r10d
    jnz .Lrt_text_pf_word
    # (2) The decimal grammar: %rsi = cursor, %rdx = end.
    leaq SEA_STR_BYTES(%rbx), %rsi
    leaq (%rsi,%r9), %rdx
    cmpq %rdx, %rsi
    je .Lrt_text_pf_bad             # ""
    movzbl (%rsi), %eax
    cmpl $43, %eax                  # an optional '+' ...
    je 3f
    cmpl $45, %eax                  # ... or '-'
    jne 4f
3:  incq %rsi
4:  call .Lrt_text_digits           # digits before a '.'
    movq %rax, %r10                 # their number
    cmpq %rdx, %rsi
    je 5f
    cmpb $46, (%rsi)                # '.'
    jne 5f
    incq %rsi
    call .Lrt_text_digits           # digits after it
    addq %rax, %r10                 # some digit on either side
5:  testq %r10, %r10
    jz .Lrt_text_pf_bad             # no digit in the mantissa
    cmpq %rdx, %rsi
    je .Lrt_text_pf_ok              # the whole text read
    movzbl (%rsi), %eax
    orl $32, %eax                   # 'E' -> 'e'
    cmpl $101, %eax                 # 'e'
    jne .Lrt_text_pf_bad
    incq %rsi
    cmpq %rdx, %rsi
    je .Lrt_text_pf_bad             # "1e"
    movzbl (%rsi), %eax
    cmpl $43, %eax                  # an optional exponent sign
    je 6f
    cmpl $45, %eax
    jne 7f
6:  incq %rsi
7:  call .Lrt_text_digits
    testq %rax, %rax
    jz .Lrt_text_pf_bad             # no exponent digit
    cmpq %rdx, %rsi
    jne .Lrt_text_pf_bad            # bytes left over
.Lrt_text_pf_ok:
    # (3) The NUL-terminated copy.
    leaq 16(%rsp), %r13             # the frame buffer ...
    xorl %r14d, %r14d
    cmpq $RTT_FBUF, %r9
    jb 8f
    leaq 1(%r9), %r14               # ... or a block of n + 1 bytes
    movq %r14, %rdi
    movq %r12, %rsi
    call sea_alloc                  # out of memory at the site
    movq %rax, %r13
8:  movq %r13, %rdi
    leaq SEA_STR_BYTES(%rbx), %rsi
    movq SEA_STR_LEN(%rbx), %rdx
    call memcpy@PLT
    movq SEA_STR_LEN(%rbx), %rax
    movb $0, (%r13,%rax)            # the NUL
    movq %r13, %rdi
    movq %rsp, %rsi                 # &end
    call strtod@PLT                 # x in %xmm0 (C locale, round to nearest)
    movsd %xmm0, 8(%rsp)
    testq %r14, %r14
    jz 9f
    movq %r13, %rdi
    movq %r14, %rsi
    call sea_free_block             # the block, freed before return or report
9:  movq SEA_STR_LEN(%rbx), %rax
    addq %r13, %rax
    cmpq %rax, 0(%rsp)
    jne .Lrt_text_pf_bad            # strtod stopped early: the guard
    movsd 8(%rsp), %xmm0
    jmp .Lrt_text_pf_ret
.Lrt_text_pf_wordhit:
    movq 8(%r8), %xmm0              # the word's value
.Lrt_text_pf_ret:
    addq $(RTT_FBUF + 16), %rsp
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret
.Lrt_text_pf_bad:
    movl $SEA_E_PARSE_F64, %edi
    movq %r12, %rsi
    movq %rbx, %rdx                 # slot 0: s
    call .Lrt_text_raise            # noreturn
    ud2
    .size sea_parse_f64, . - sea_parse_f64

# ---------------------------------------------------------------------
# Constant data: the eight words of parse_f64 (length, bytes, bits).
# ---------------------------------------------------------------------
    .section .rodata
    .p2align 4
.macro RTT_WORD len, text, bits
    .byte \len
    .ascii "\text"
    .space 7 - \len, 0
    .quad \bits
.endm
.Lrt_text_words:
    RTT_WORD 3, "inf", RTT_PINF
    RTT_WORD 3, "Inf", RTT_PINF
    RTT_WORD 4, "+inf", RTT_PINF
    RTT_WORD 4, "+Inf", RTT_PINF
    RTT_WORD 4, "-inf", RTT_NINF
    RTT_WORD 4, "-Inf", RTT_NINF
    RTT_WORD 3, "nan", RTT_NAN
    RTT_WORD 3, "NaN", RTT_NAN
.if (. - .Lrt_text_words) != RTT_W_SIZE * RTT_W_COUNT
    .error "rt_text: the word table's records are not RTT_W_SIZE bytes"
.endif

    .section .note.GNU-stack,"",@progbits
