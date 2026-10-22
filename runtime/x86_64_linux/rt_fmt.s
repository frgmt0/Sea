# =====================================================================
# sea/runtime/x86_64_linux/rt_fmt.s -- the pre-parsed printf engine
# (LANGUAGE.md 11.1; DESIGN.md 4.5, 4.7.1, 4.8).
# The x86_64-linux twin of runtime/arm64_macos/rt_fmt.s: the same
# algorithm step by step, so every byte is the same on both targets.
#
# Defines:
#   sea_printf   (global, SEA_ENT_PRINTF) format a pre-parsed format
#                (SEA_FMT_*) with its argument slots into the standard
#                output, through sea_out_bytes
#   sea_fmt_g    (.globl + .hidden: private to the runtime) an f64 as
#                Sea's printf("%g") prints it, for sea_err's `f`
#                arguments (DESIGN.md 2.6.2)
#   sea_error    (global, SEA_ENT_ERROR) format like sea_printf into the
#                sink, then sea_err(SEA_E_USER, site, {the text})
#   sea_fmt_sink (.globl + .hidden: private to the runtime) the growing
#                text buffer sea_error formats into (RTF_SINK_*)
# Uses:
#   sea_alloc, sea_free_block, sea_live (rt_mem.s) the sink's blocks and
#                sea_error's string object; sea_err (rt_err.s)
#   sea_out_bytes (rt_out.s) %rdi = bytes, %rsi = length (> 0), %rdx =
#                site index; appends to the standard-output buffer and
#                returns normally (a failed write is reported there)
#   sea_out_repeat, sea_out_fail (rt_out.s) padding and its failure
#   snprintf     (glibc, through the PLT) the digits of finite f64
#                conversions; variadic, so %al = 1 (one f64 in %xmm0)
#
# How each conversion is made (LANGUAGE.md 11.1, DESIGN.md 4.5):
#   * integers (i64, bool; %d of an integral f64 below 2^63) by own code;
#     %d of an integral f64 of magnitude >= 2^63 takes its exact digits
#     from snprintf("%.0f", |x|), which is exact for an integral value;
#   * finite f64 for f F e E g G (and %d of a non-integral f64, which is
#     %e with precision 6) through snprintf with a single-conversion C
#     format built from the piece: the flags + space #, the precision and
#     the letter. Width and the 0 and - flags are applied here, so a
#     width of any size costs no buffer;
#   * a precision above RTF_PREC_MAX is clamped for snprintf and the
#     missing digits are appended as zeros (before the exponent): the
#     exact decimal expansion of a binary64 has at most 767 significant
#     digits and at most 1074 digits after the point, so every digit
#     beyond RTF_PREC_MAX (of %f, %e, or %#g) is 0. %g without # strips
#     trailing zeros anyway, and the %g style choice (P > X) is the same
#     for every P > 308;
#   * NaN, Inf, -Inf in MATLAB spelling, never through C: NaN never
#     signed, +Inf as Inf, +Inf (flag +) or " Inf" (flag space), padded
#     with spaces only (0 and # and the precision are ignored);
#   * %s: the string's bytes, at most `precision` of them; width counts
#     bytes; padding with spaces.
# glibc's snprintf prints the exact decimal value of the binary64
# argument correctly rounded for every precision, as libSystem's does
# (DESIGN.md 4.7.1). The program never calls setlocale, so it runs in
# the C locale ('.' as the decimal point), in the default rounding mode.
# SSE2 only: the integral test of %d uses cvttsd2si / cvtsi2sd, not
# SSE4.1 roundsd.
# =====================================================================
.include "limits.inc"
.include "errors.inc"
.include "rt.inc"

# Size of the conversion buffer in sea_printf's frame. The longest text
# snprintf writes into it: %f with precision RTF_PREC_MAX of -DBL_MAX,
# 1 + 309 + 1 + RTF_PREC_MAX bytes + NUL = 1412 (see RTF_PREC_MAX).
.equ RTF_BUF,           1536
# Largest precision passed to snprintf (>= 1074 digits after the point
# and >= 767 significant digits: every digit beyond it is exactly 0).
.equ RTF_PREC_MAX,      1100
# C's default precision of f F e E g G.
.equ RTF_PREC_DEFAULT,  6
# Buffer of sea_fmt_g: "%g" text is at most 13 bytes ("-2.22507e-308").
.equ RTF_GBUF,          32
# Bits of +Inf shifted left by one: |bits| << 1 >= this means NaN or Inf.
.equ RTF_INF2,          0xFFE0000000000000
# The sink sea_fmt_sink (internal, DESIGN.md 4.5): a descriptor of three
# u64 words; the buffer is a block of rt_mem.s whose byte count is the
# capacity (a power of two, at least RTF_SINK_MIN), kept between uses.
.equ RTF_SINK_PTR,      0           # ptr  the block, 0 before the first use
.equ RTF_SINK_LEN,      8           # u64  bytes of text in it
.equ RTF_SINK_CAP,      16          # u64  its byte count (0 before the first use)
.equ RTF_SINK_SIZE,     24
.equ RTF_SINK_MIN,      256         # the first capacity

# sea_printf's locals, below the five saved registers (offsets from %rbp).
.equ RTF_W,             -48         # width (-1 absent)
.equ RTF_P,             -56         # precision (-1 absent)
.equ RTF_L,             -64         # conversion letter
.equ RTF_F,             -72         # flags (SEA_FF_*)
.equ RTF_C,             -80         # argument class (SEA_CLS_*)
.equ RTF_SL,            -88         # sign length (0 or 1) of an integer conversion
# Bytes subtracted from %rsp after the pushes: the locals (48), the
# conversion buffer and 8 bytes of pad, so that %rsp = 0 (mod 16) and
# the buffer is at 0(%rsp) .. RTF_BUF-1(%rsp).
.equ RTF_FRAME,         (48 + RTF_BUF + 8)

    .text

# RTF_INTSIGN -- the sign of an integer conversion (inline in
#   sea_printf, whose frame it uses).
#   Inputs : %ecx = negative (0/1); RTF_F(%rbp) = flags
#   Outputs: the sign byte at 0(%rsp) ('-', '+' or ' ') if any;
#            RTF_SL(%rbp) = its length (0 or 1)
#   Clobbers: %dl
.macro RTF_INTSIGN
    movq $0, RTF_SL(%rbp)
    testl %ecx, %ecx
    jz 1f
    movb $45, %dl                   # '-'
    jmp 3f
1:  testb $SEA_FF_PLUS, RTF_F(%rbp)
    jz 2f
    movb $43, %dl                   # '+'
    jmp 3f
2:  testb $SEA_FF_SPACE, RTF_F(%rbp)
    jz 4f
    movb $32, %dl                   # ' '
3:  movb %dl, (%rsp)
    movq $1, RTF_SL(%rbp)
4:
.endm

# ---------------------------------------------------------------------
# sea_printf -- format a pre-parsed format into the standard output.
#   Purpose : LANGUAGE.md 11.1; the entry PRINTF of DESIGN.md 4.8.
#   Inputs  : %rdi = pre-parsed format (SEA_FMT_*), %rsi = argument
#             slots (SEA_SLOT_SIZE each, one per conversion piece, in
#             order), %rdx = site index (passed to sea_out_bytes for the
#             error report of a failed write)
#   Outputs : none
#   Clobbers: all caller-saved registers, flags
#   Callee-saved used: %rbx = current piece, %r12 = pieces left,
#             %r13 = next argument slot, %r14 = site index, %r15 = the
#             argument slot value, %rbp = frame pointer (locals RTF_*)
#   Frame   : 48 bytes (%rbp %rbx %r12-%r15) + RTF_FRAME (locals,
#             conversion buffer at 0(%rsp), pad) = 1640 bytes
# ---------------------------------------------------------------------
    .globl sea_printf
    .type sea_printf, @function
    .p2align 4
sea_printf:
    pushq %rbp                      # %rsp = 0 (mod 16)
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15                      # %rsp = 8 (mod 16)
    subq $RTF_FRAME, %rsp           # %rsp = 0 (mod 16); buffer at 0(%rsp)
    movq SEA_FMT_NPIECE(%rdi), %r12 # pieces to go
    leaq SEA_FMT_PIECES(%rdi), %rbx # first piece
    movq %rsi, %r13                 # first argument slot
    movq %rdx, %r14                 # site index for write errors

.Lrt_fmt_printf_loop:
    testq %r12, %r12
    jz .Lrt_fmt_printf_done
    cmpb $SEA_FPK_CONV, SEA_FP_KIND(%rbx)
    je .Lrt_fmt_printf_conv
    # Text piece: its bytes as they are (%% is already a single %).
    movq SEA_FP_TEXT(%rbx), %rdi
    movq SEA_FP_TLEN(%rbx), %rsi
    movq %r14, %rdx
    call .Lrt_fmt_out
    jmp .Lrt_fmt_printf_next

.Lrt_fmt_printf_conv:
    # Load the piece's fields and consume one argument slot.
    movzbl SEA_FP_CONV(%rbx), %eax
    movq %rax, RTF_L(%rbp)
    movzbl SEA_FP_FLAGS(%rbx), %eax
    movq %rax, RTF_F(%rbp)
    movzbl SEA_FP_CLS(%rbx), %eax
    movq %rax, RTF_C(%rbp)
    movslq SEA_FP_WIDTH(%rbx), %rax
    movq %rax, RTF_W(%rbp)
    movslq SEA_FP_PREC(%rbx), %rax
    movq %rax, RTF_P(%rbp)
    movq (%r13), %r15
    addq $SEA_SLOT_SIZE, %r13
    # Dispatch on the letter: s, d/i, else the float letters f F e E g G
    # (pass 2 admits no other letter, LANGUAGE.md 11.1).
    movq RTF_L(%rbp), %rax
    cmpl $115, %eax                 # 's'
    je .Lrt_fmt_printf_str
    cmpl $100, %eax                 # 'd'
    je .Lrt_fmt_printf_int
    cmpl $105, %eax                 # 'i'
    je .Lrt_fmt_printf_int

    # ---- f F e E g G -------------------------------------------------
    # An i64 argument is converted (round to nearest, ties to even:
    # cvtsi2sd in the default MXCSR mode); it is always finite.
    cmpq $SEA_CLS_I, RTF_C(%rbp)
    jne 1f
    cvtsi2sdq %r15, %xmm0
    jmp .Lrt_fmt_printf_float
1:  movq %r15, %xmm0
    # Non-finite: |bits| << 1 >= the bits of Inf << 1.
    movq %r15, %rax
    shlq $1, %rax
    movabsq $RTF_INF2, %rcx
    cmpq %rcx, %rax
    jae .Lrt_fmt_printf_nonfinite

    # Finite f64 in %xmm0, letter RTF_L, precision RTF_P: digits by snprintf.
.Lrt_fmt_printf_float:
    movl RTF_L(%rbp), %edi          # letter
    movl RTF_F(%rbp), %esi          # flags (+ space # are used)
    movq RTF_P(%rbp), %rdx          # precision
    movq %rsp, %rcx                 # into the conversion buffer
    movl $RTF_BUF, %r8d
    call .Lrt_fmt_float             # %rax len, %rdx zeros, %rcx split, %r8 sign len
    # Lay out: body at 0(%rsp), zeros inserted at the split, width/0/-.
    movq %rdx, %r9                  # zeros to insert (moved below)
    movq %rax, %rsi                 # body length
    movq %r8, %rdx                  # sign length
    movq %r9, %r8                   # zeros
    movq %rsp, %rdi                 # body (%rcx = split already)
    movq RTF_W(%rbp), %r9           # width
    movl RTF_F(%rbp), %r10d
    andl $(SEA_FF_LEFT | SEA_FF_ZERO), %r10d # 0 is honoured for finite floats
    movq %r14, %r11
    call .Lrt_fmt_emit
    jmp .Lrt_fmt_printf_next

    # ---- NaN, Inf, -Inf (bits in %r15) -------------------------------
.Lrt_fmt_printf_nonfinite:
    movq %rsp, %rdi
    movq %r15, %rsi
    movl RTF_F(%rbp), %edx
    call .Lrt_fmt_nonfinite         # %rax = length of the spelling at 0(%rsp)
    movq %rsp, %rdi
    movq %rax, %rsi                 # body length
    xorl %edx, %edx                 # no sign to keep in front of zeros
    movq %rax, %rcx                 # no split
    xorl %r8d, %r8d                 # no zeros inserted
    movq RTF_W(%rbp), %r9           # width
    movl RTF_F(%rbp), %r10d
    andl $SEA_FF_LEFT, %r10d        # spaces only: 0 and # are ignored
    movq %r14, %r11
    call .Lrt_fmt_emit
    jmp .Lrt_fmt_printf_next

    # ---- s ------------------------------------------------------------
.Lrt_fmt_printf_str:
    movq SEA_STR_LEN(%r15), %rsi    # bytes in the string
    movq RTF_P(%rbp), %rax
    testq %rax, %rax
    js 1f                           # no precision: all of them
    cmpq %rsi, %rax
    cmovbq %rax, %rsi               # precision truncates (in bytes)
1:  leaq SEA_STR_BYTES(%r15), %rdi
    xorl %edx, %edx
    movq %rsi, %rcx                 # no split
    xorl %r8d, %r8d
    movq RTF_W(%rbp), %r9           # width counts bytes
    movl RTF_F(%rbp), %r10d
    andl $SEA_FF_LEFT, %r10d        # spaces only
    movq %r14, %r11
    call .Lrt_fmt_emit
    jmp .Lrt_fmt_printf_next

    # ---- d i ------------------------------------------------------------
.Lrt_fmt_printf_int:
    cmpq $SEA_CLS_F, RTF_C(%rbp)
    je .Lrt_fmt_printf_intf
    # i64 (or bool, 0/1): magnitude as an unsigned 64-bit value, so
    # INT64_MIN's magnitude 2^63 is exact.
    movq %r15, %rax
    xorl %ecx, %ecx                 # negative?
    testq %rax, %rax
    jns .Lrt_fmt_printf_intu
    negq %rax                       # |value| (mod 2^64)
    movl $1, %ecx

    # Unsigned magnitude %rax, negative flag %ecx.
.Lrt_fmt_printf_intu:
    RTF_INTSIGN                     # sign at 0(%rsp); RTF_SL = sign length
    # C: precision 0 with the value 0 prints no digits.
    cmpq $0, RTF_P(%rbp)
    jne 5f
    testq %rax, %rax
    jnz 5f
    xorl %eax, %eax
    jmp .Lrt_fmt_printf_inttail
    # Digits right to left at the end of the buffer, then moved to
    # 0(%rsp) + sign length.
5:  leaq RTF_BUF(%rsp), %r8         # end of the buffer
    movl $10, %ecx
6:  xorl %edx, %edx
    divq %rcx                       # quotient; remainder = next digit
    addb $48, %dl                   # '0'
    decq %r8
    movb %dl, (%r8)
    testq %rax, %rax
    jnz 6b
    leaq RTF_BUF(%rsp), %rax
    subq %r8, %rax                  # number of digits (1 .. 20)
    movq RTF_SL(%rbp), %rdi
    addq %rsp, %rdi                 # destination after the sign
    movq %rax, %rcx
7:  movb (%r8), %dl
    movb %dl, (%rdi)
    incq %r8
    incq %rdi
    decq %rcx
    jnz 7b
    jmp .Lrt_fmt_printf_inttail

    # %d of an f64 (bits in %r15): MATLAB rule (LANGUAGE.md 11.1).
.Lrt_fmt_printf_intf:
    movq %r15, %rax
    shlq $1, %rax
    movabsq $RTF_INF2, %rcx
    cmpq %rcx, %rax
    jae .Lrt_fmt_printf_nonfinite   # NaN, Inf, -Inf
    movq %r15, %xmm0
    movq %r15, %rax
    btrq $63, %rax                  # the bits of |x|
    movabsq $0x4330000000000000, %rcx # the bits of 2^52
    cmpq %rcx, %rax
    jae 8f                          # |x| >= 2^52: integral
    # |x| < 2^52: truncation fits an i64; integral iff it converts back
    # to x (-0.0 compares equal to 0.0 and is the integer 0, no sign).
    cvttsd2si %xmm0, %rax
    cvtsi2sdq %rax, %xmm2
    ucomisd %xmm0, %xmm2
    jne .Lrt_fmt_printf_intnonint   # not integral: %e, precision 6
    jmp 9f
    # Integral, |x| >= 2^52. Below 2^63 in magnitude it converts
    # exactly to i64.
8:  movabsq $0x43E0000000000000, %rcx # the bits of 2^63
    cmpq %rcx, %rax
    jae .Lrt_fmt_printf_intbig
    cvttsd2si %xmm0, %rax           # exact
9:  xorl %ecx, %ecx
    testq %rax, %rax
    jns .Lrt_fmt_printf_intu
    negq %rax
    movl $1, %ecx
    jmp .Lrt_fmt_printf_intu

    # |x| >= 2^63, integral: the exact digits of snprintf("%.0f", |x|).
.Lrt_fmt_printf_intbig:
    movq %r15, %rcx
    shrq $63, %rcx                  # negative? (x is not zero here)
    RTF_INTSIGN                     # sign at 0(%rsp); RTF_SL = sign length
    movq %r15, %rax
    btrq $63, %rax
    movq %rax, %xmm0                # |x|
    movl $102, %edi                 # 'f'
    xorl %esi, %esi                 # no flags: digits only
    xorl %edx, %edx                 # precision 0
    movq RTF_SL(%rbp), %rcx
    movl $RTF_BUF, %r8d
    subq %rcx, %r8                  # the room after the sign
    addq %rsp, %rcx                 # after the sign
    call .Lrt_fmt_float             # %rax = number of digits
    jmp .Lrt_fmt_printf_inttail

    # Non-integral f64 under %d: %e with the same flags and width and
    # precision 6 (%xmm0 still holds x).
.Lrt_fmt_printf_intnonint:
    movq $101, RTF_L(%rbp)          # 'e'
    movq $RTF_PREC_DEFAULT, RTF_P(%rbp)
    jmp .Lrt_fmt_printf_float

    # Integer layout: 0(%rsp) = sign (RTF_SL bytes) + %rax digits. The
    # precision is the minimum number of digits (zeros inserted after the
    # sign); with a precision the 0 flag is ignored (C99 7.19.6.1).
.Lrt_fmt_printf_inttail:
    movq RTF_P(%rbp), %r8
    subq %rax, %r8                  # zeros = precision - digits
    xorl %ecx, %ecx
    testq %r8, %r8
    cmovleq %rcx, %r8               # (none if <= 0 or no precision)
    movq RTF_SL(%rbp), %rdx         # sign stays in front
    leaq (%rdx,%rax), %rsi          # body length
    movq %rsp, %rdi
    movq %rdx, %rcx                 # zeros go right after the sign
    movq RTF_W(%rbp), %r9           # width
    movl RTF_F(%rbp), %r10d
    andl $(SEA_FF_LEFT | SEA_FF_ZERO), %r10d
    cmpq $0, RTF_P(%rbp)
    jl 1f
    andl $~SEA_FF_ZERO, %r10d       # a precision cancels the 0 flag
1:  movq %r14, %r11
    call .Lrt_fmt_emit

.Lrt_fmt_printf_next:
    addq $SEA_FP_SIZE, %rbx
    decq %r12
    jmp .Lrt_fmt_printf_loop

.Lrt_fmt_printf_done:
    addq $RTF_FRAME, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret
    .size sea_printf, . - sea_printf

# ---------------------------------------------------------------------
# .Lrt_fmt_nonfinite -- spell NaN, Inf or -Inf (LANGUAGE.md 11.1).
#   Inputs  : %rdi = destination (>= 4 bytes), %rsi = the f64's bits (NaN
#             or +-Inf), %edx = flags (only + and space are looked at)
#   Outputs : %rax = length written (3 or 4); no NUL
#   Clobbers: %rax %rcx %rsi %r8
#   Callee-saved used: none
#   Frame   : none (leaf)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_fmt_nonfinite:
    movq %rsi, %rax
    shlq $1, %rax
    movabsq $RTF_INF2, %rcx
    cmpq %rcx, %rax
    ja .Lrt_fmt_nonfinite_nan       # above Inf: NaN, never signed
    movq %rdi, %r8                  # cursor
    testq %rsi, %rsi
    js .Lrt_fmt_nonfinite_neg
    # +Inf: "+Inf" with +, " Inf" with space (C's sign rules), else "Inf".
    testl $SEA_FF_PLUS, %edx
    jz 1f
    movb $43, (%r8)                 # '+'
    incq %r8
    jmp .Lrt_fmt_nonfinite_inf
1:  testl $SEA_FF_SPACE, %edx
    jz .Lrt_fmt_nonfinite_inf
    movb $32, (%r8)                 # ' '
    incq %r8
    jmp .Lrt_fmt_nonfinite_inf
.Lrt_fmt_nonfinite_neg:
    movb $45, (%r8)                 # '-'
    incq %r8
.Lrt_fmt_nonfinite_inf:
    movb $73, (%r8)                 # 'I'
    movb $110, 1(%r8)               # 'n'
    movb $102, 2(%r8)               # 'f'
    leaq 3(%r8), %rax
    subq %rdi, %rax                 # length
    ret
.Lrt_fmt_nonfinite_nan:
    movb $78, (%rdi)                # 'N'
    movb $97, 1(%rdi)               # 'a'
    movb $78, 2(%rdi)               # 'N'
    movl $3, %eax
    ret

# ---------------------------------------------------------------------
# .Lrt_fmt_float -- the text of a finite f64 under one C conversion.
#   Purpose : snprintf(buf, size, "%[+][ ][#].<p><letter>", x), with the
#             precision clamped to RTF_PREC_MAX; reports how many zeros
#             the clamp left out and where they belong.
#   Inputs  : %xmm0 = x (finite), %edi = letter (f F e E g G), %esi =
#             flags (SEA_FF_PLUS, SEA_FF_SPACE, SEA_FF_ALT are used),
#             %rdx = precision (-1: absent, C's default 6), %rcx =
#             buffer, %r8 = its size (enough for the clamped text and a
#             NUL)
#   Outputs : (a local convention, four results) %rax = length of the
#             text in the buffer (no sign stripped), %rdx = zeros to
#             insert (precision beyond RTF_PREC_MAX of f F e E, and of
#             g G with #), %rcx = split: where the zeros go (the offset
#             of 'e'/'E', else the length), %r8 = sign length (1 if the
#             text starts with '-', '+' or ' ', else 0)
#   Clobbers: all caller-saved registers
#   Callee-saved used: %rbx = buffer, %r12 = letter, %r13 = zeros to
#             insert, %r14 = buffer size (all saved and restored),
#             %rbp = frame pointer
#   Frame   : 40 bytes (%rbp %rbx %r12-%r14) + 48 (digit scratch at
#             0(%rsp), C format at 16(%rsp)) = 88 bytes
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_fmt_float:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14                      # %rsp = 0 (mod 16)
    subq $48, %rsp
    movq %rcx, %rbx
    movl %edi, %r12d
    movq %r8, %r14
    # Absent precision: C's default.
    testq %rdx, %rdx
    jns 1f
    movl $RTF_PREC_DEFAULT, %edx
    # Clamp; the zeros left out are exact (see the file header).
1:  xorl %r13d, %r13d
    cmpq $RTF_PREC_MAX, %rdx
    jle 2f
    leaq -RTF_PREC_MAX(%rdx), %r13
    movl $RTF_PREC_MAX, %edx
2:  # g/G without # strips trailing zeros: nothing to insert.
    movl %r12d, %eax
    orl $0x20, %eax                 # lower-case letter
    cmpl $103, %eax                 # 'g'
    jne 3f
    testl $SEA_FF_ALT, %esi
    jnz 3f
    xorl %r13d, %r13d
3:  # Build the C format at 16(%rsp).
    leaq 16(%rsp), %rdi
    movb $37, (%rdi)                # '%'
    incq %rdi
    testl $SEA_FF_PLUS, %esi
    jz 4f
    movb $43, (%rdi)                # '+'
    incq %rdi
4:  testl $SEA_FF_SPACE, %esi
    jz 5f
    movb $32, (%rdi)                # ' '
    incq %rdi
5:  testl $SEA_FF_ALT, %esi
    jz 6f
    movb $35, (%rdi)                # '#'
    incq %rdi
6:  movb $46, (%rdi)                # '.'
    incq %rdi
    # Precision (0 .. RTF_PREC_MAX) in decimal: digits right to left in
    # the scratch 0(%rsp) .. 15(%rsp), then copied.
    movq %rdx, %rax
    leaq 16(%rsp), %r8              # one past the scratch digits
    movl $10, %ecx
7:  xorl %edx, %edx
    divq %rcx
    addb $48, %dl                   # '0'
    decq %r8
    movb %dl, (%r8)
    testq %rax, %rax
    jnz 7b
    leaq 16(%rsp), %r9
8:  movb (%r8), %al
    movb %al, (%rdi)
    incq %r8
    incq %rdi
    cmpq %r9, %r8
    jb 8b
    movb %r12b, (%rdi)              # the letter
    movb $0, 1(%rdi)                # NUL
    # snprintf(buffer, size, format, x): variadic, the double in %xmm0,
    # %al = 1 vector register used.
    movq %rbx, %rdi
    movq %r14, %rsi
    leaq 16(%rsp), %rdx
    movl $1, %eax
    call snprintf@PLT
    movslq %eax, %rax               # text length (fits: see RTF_BUF)
    # Split: the exponent letter, if any.
    xorl %ecx, %ecx
9:  cmpq %rax, %rcx
    je 10f
    movzbl (%rbx,%rcx), %edx
    orl $0x20, %edx
    cmpl $101, %edx                 # 'e'
    je 10f
    incq %rcx
    jmp 9b
10: # Sign length.
    xorl %r8d, %r8d
    movzbl (%rbx), %edx
    cmpl $45, %edx                  # '-'
    je 11f
    cmpl $43, %edx                  # '+'
    je 11f
    cmpl $32, %edx                  # ' '
    jne 12f
11: movl $1, %r8d
12: movq %r13, %rdx                 # zeros to insert
    addq $48, %rsp
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_fmt_emit -- write a converted field with its padding.
#   Purpose : body = sign (signlen bytes) + rest; `zeros` zeros are
#             inserted at offset `split` (precision zeros); the field is
#             padded to the width: spaces on the left, or on the right
#             with SEA_FF_LEFT, or zeros after the sign with SEA_FF_ZERO
#             (ignored with SEA_FF_LEFT, as in C).
#   Inputs  : (a local convention) %rdi = body, %rsi = body length,
#             %rdx = sign length, %rcx = split (sign length <= split <=
#             body length), %r8 = zeros to insert, %r9 = width (-1:
#             absent), %r10d = flags (only SEA_FF_LEFT and SEA_FF_ZERO
#             are looked at), %r11 = site index
#   Outputs : none
#   Clobbers: all caller-saved registers, flags
#   Callee-saved used: %rbx = body, %r12 = body length, %r13 = sign
#             length, %r14 = site, %r15 = padding (all saved and
#             restored), %rbp = frame pointer; split, zeros and flags at
#             0, 8, 16(%rsp)
#   Frame   : 48 bytes (%rbp %rbx %r12-%r15) + 24 = 72 bytes
# ---------------------------------------------------------------------
.equ RTF_E_SPLIT,       0
.equ RTF_E_ZEROS,       8
.equ RTF_E_FLAGS,       16
    .p2align 4
.Lrt_fmt_emit:
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
    movq %r11, %r14
    movq %rcx, RTF_E_SPLIT(%rsp)
    movq %r8, RTF_E_ZEROS(%rsp)
    movq %r10, RTF_E_FLAGS(%rsp)
    # padding = width - (body + zeros), at least 0 (width -1: none).
    leaq (%rsi,%r8), %rax
    movq %r9, %r15
    subq %rax, %r15
    xorl %eax, %eax
    testq %r15, %r15
    cmovleq %rax, %r15
    # Leading spaces: neither - nor 0.
    testl $(SEA_FF_LEFT | SEA_FF_ZERO), RTF_E_FLAGS(%rsp)
    jnz 1f
    movq %r15, %rdi
    movl $32, %esi                  # ' '
    movq %r14, %rdx
    call .Lrt_fmt_fill
1:  # The sign.
    movq %rbx, %rdi
    movq %r13, %rsi
    movq %r14, %rdx
    call .Lrt_fmt_out
    # Zero padding: 0 without -.
    testl $SEA_FF_LEFT, RTF_E_FLAGS(%rsp)
    jnz 2f
    testl $SEA_FF_ZERO, RTF_E_FLAGS(%rsp)
    jz 2f
    movq %r15, %rdi
    movl $48, %esi                  # '0'
    movq %r14, %rdx
    call .Lrt_fmt_fill
2:  # Body up to the split, the inserted zeros, the rest.
    leaq (%rbx,%r13), %rdi
    movq RTF_E_SPLIT(%rsp), %rsi
    subq %r13, %rsi
    movq %r14, %rdx
    call .Lrt_fmt_out
    movq RTF_E_ZEROS(%rsp), %rdi
    movl $48, %esi                  # '0'
    movq %r14, %rdx
    call .Lrt_fmt_fill
    movq RTF_E_SPLIT(%rsp), %rax
    leaq (%rbx,%rax), %rdi
    movq %r12, %rsi
    subq %rax, %rsi
    movq %r14, %rdx
    call .Lrt_fmt_out
    # Trailing spaces with -.
    testl $SEA_FF_LEFT, RTF_E_FLAGS(%rsp)
    jz 3f
    movq %r15, %rdi
    movl $32, %esi                  # ' '
    movq %r14, %rdx
    call .Lrt_fmt_fill
3:  addq $24, %rsp
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_fmt_fill -- write `count` copies of a space or a zero.
#   Inputs  : %rdi = count (may be 0), %esi = ' ' or '0', %rdx = site
#   Outputs : none (a failed write is the run-time error at the site)
#   Clobbers: all caller-saved registers, flags (calls sea_out_repeat)
#   Callee-saved used: %rbx = site index (saved and restored), %rbp =
#             frame pointer
#   Frame   : 24 bytes (%rbp %rbx + 8 pad)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_fmt_fill:
    cmpq $0, .Lrt_fmt_tosink(%rip)
    jne .Lrt_fmt_sink_fill          # sea_error: into the sink (tail call)
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $8, %rsp                   # %rsp = 0 (mod 16)
    movq %rdx, %rbx                 # site
    movq %rdi, %rax
    movl %esi, %edi                 # the byte
    movq %rax, %rsi                 # the count
    call sea_out_repeat             # %rax = 0 or errno
    testq %rax, %rax
    jnz 1f
    addq $8, %rsp
    popq %rbx
    popq %rbp
    ret
1:  movq %rax, %rdi                 # errno
    movq %rbx, %rsi                 # site
    call sea_out_fail               # noreturn
    ud2

# ---------------------------------------------------------------------
# .Lrt_fmt_out -- sea_out_bytes unless the length is 0.
#   Inputs  : %rdi = bytes, %rsi = length, %rdx = site index
#   Outputs : none
#   Clobbers: as sea_out_bytes (all caller-saved registers, flags)
#   Callee-saved used: none
#   Frame   : none (tail jump or return)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_fmt_out:
    testq %rsi, %rsi
    jz 1f
    cmpq $0, .Lrt_fmt_tosink(%rip)
    jne .Lrt_fmt_sink_put           # sea_error: into the sink (tail call)
    jmp sea_out_bytes               # tail call: returns to our caller
1:  ret

# ---------------------------------------------------------------------
# .Lrt_fmt_sink_room -- make room in the sink (sea_fmt_sink).
#   Purpose : grow the sink's buffer so that it holds at least `need`
#             bytes: the capacity doubles from RTF_SINK_MIN until it is
#             large enough (every capacity is a power of two, a class
#             size of rt_mem.s); the bytes so far are copied into the new
#             block and the old block is freed. A need above
#             SEA_LIM_STR_BYTES (the text could not become a str) is
#             `out of memory` at the site before anything is allocated,
#             and so is no memory.
#   Inputs  : %rdi = need (bytes in all), %rsi = site
#   Outputs : none; SINK_CAP >= need afterwards
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = need / the new
#             capacity, %r12 = site, %r13 = the new block, %rbp = frame
#             pointer
#   Frame   : 32 bytes (%rbp %rbx %r12 %r13) + 8 pad = 40 bytes
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_fmt_sink_room:
    cmpq $SEA_LIM_STR_BYTES, %rdi
    ja .Lrt_fmt_sink_oom            # longer than any str may be: out of memory at once
    leaq sea_fmt_sink(%rip), %rax
    cmpq RTF_SINK_CAP(%rax), %rdi
    ja 1f
    ret                             # it fits already
1:  pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    pushq %r13
    subq $8, %rsp                   # %rsp = 0 (mod 16)
    movq %rsi, %r12
    movq RTF_SINK_CAP(%rax), %rcx
    movl $RTF_SINK_MIN, %edx
    testq %rcx, %rcx
    cmovzq %rdx, %rcx               # no buffer yet: start at the minimum
2:  cmpq %rdi, %rcx
    jae 3f
    shlq $1, %rcx                   # double until need fits (need <= SEA_LIM_STR_BYTES:
    jmp 2b                          # no overflow)
3:  movq %rcx, %rbx                 # the new capacity
    movq %rbx, %rdi
    movq %r12, %rsi
    call sea_alloc                  # out of memory there
    movq %rax, %r13
    leaq sea_fmt_sink(%rip), %rax
    movq RTF_SINK_PTR(%rax), %rsi
    testq %rsi, %rsi
    jz 4f                           # nothing to keep
    movq %r13, %rdi
    movq RTF_SINK_LEN(%rax), %rdx
    call memcpy@PLT                 # the bytes so far
    leaq sea_fmt_sink(%rip), %rax
    movq RTF_SINK_PTR(%rax), %rdi
    movq RTF_SINK_CAP(%rax), %rsi
    call sea_free_block             # the old block
4:  leaq sea_fmt_sink(%rip), %rax
    movq %r13, RTF_SINK_PTR(%rax)
    movq %rbx, RTF_SINK_CAP(%rax)
    addq $8, %rsp
    popq %r13
    popq %r12
    popq %rbx
    popq %rbp
    ret
.Lrt_fmt_sink_oom:
    movl $SEA_E_OUT_OF_MEMORY, %edi # (%rsi = site)
    xorl %edx, %edx
    call sea_err                    # noreturn
    ud2

# ---------------------------------------------------------------------
# .Lrt_fmt_sink_put -- append bytes to the sink.
#   Inputs  : %rdi = bytes, %rsi = length (> 0), %rdx = site
#   Outputs : none
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = bytes, %r12 =
#             length, %rbp = frame pointer
#   Frame   : 24 bytes (%rbp %rbx %r12)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_fmt_sink_put:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12                      # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movq %rsi, %r12
    leaq sea_fmt_sink(%rip), %rax
    movq RTF_SINK_LEN(%rax), %rdi
    addq %r12, %rdi                 # need
    movq %rdx, %rsi
    call .Lrt_fmt_sink_room
    leaq sea_fmt_sink(%rip), %rax
    movq RTF_SINK_PTR(%rax), %rdi
    addq RTF_SINK_LEN(%rax), %rdi   # the end of the text so far
    addq %r12, RTF_SINK_LEN(%rax)
    movq %rbx, %rsi
    movq %r12, %rdx
    call memcpy@PLT
    popq %r12
    popq %rbx
    popq %rbp
    ret

# ---------------------------------------------------------------------
# .Lrt_fmt_sink_fill -- append `count` copies of a byte to the sink.
#   Inputs  : %rdi = count (may be 0), %esi = the byte, %rdx = site
#   Outputs : none
#   Clobbers: all caller-saved registers
#   Callee-saved used (saved and restored): %rbx = count, %r12 = the
#             byte, %rbp = frame pointer
#   Frame   : 24 bytes (%rbp %rbx %r12)
# ---------------------------------------------------------------------
    .p2align 4
.Lrt_fmt_sink_fill:
    testq %rdi, %rdi
    jnz 1f
    ret                             # nothing to append
1:  pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12                      # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    movl %esi, %r12d
    leaq sea_fmt_sink(%rip), %rax
    movq RTF_SINK_LEN(%rax), %rdi
    addq %rbx, %rdi                 # need
    movq %rdx, %rsi
    call .Lrt_fmt_sink_room
    leaq sea_fmt_sink(%rip), %rax
    movq RTF_SINK_PTR(%rax), %rdi
    addq RTF_SINK_LEN(%rax), %rdi
    addq %rbx, RTF_SINK_LEN(%rax)
    movl %r12d, %esi
    movq %rbx, %rdx
    call memset@PLT
    popq %r12
    popq %rbx
    popq %rbp
    ret

# ---------------------------------------------------------------------
# sea_error -- entry ERROR (DESIGN.md 4.8; LANGUAGE.md 9.3).
#   Purpose : format exactly as sea_printf does, into the sink
#             sea_fmt_sink instead of standard output (sea_printf's
#             output primitives .Lrt_fmt_out and .Lrt_fmt_fill test
#             .Lrt_fmt_tosink), make a string object of the bytes (count
#             1, counted in sea_live) and call sea_err(SEA_E_USER, site,
#             {that string}), which flushes standard output and reports
#             the message. A text longer than SEA_LIM_STR_BYTES (stopped by
#             .Lrt_fmt_sink_room as soon as it is needed), or no memory, is
#             `out of memory` at the site.
#   Inputs  : %rdi = pre-parsed format, %rsi = argument slots, %rdx =
#             site
#   Outputs : never returns
#   Clobbers: everything
#   Callee-saved used (not restored: it never returns): %rbx = site,
#             %r12 = the string, %rbp = frame pointer; the slot at
#             0(%rsp)
#   Frame   : 24 bytes (%rbp %rbx %r12) + 16 (slot, pad) = 40 bytes
# ---------------------------------------------------------------------
    .globl sea_error
    .type sea_error, @function
    .p2align 4
sea_error:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    pushq %r12
    subq $16, %rsp                  # %rsp = 0 (mod 16); the slot at 0(%rsp)
    movq %rdx, %rbx
    leaq sea_fmt_sink(%rip), %rax
    movq $0, RTF_SINK_LEN(%rax)     # an empty text
    movq $1, .Lrt_fmt_tosink(%rip)
    call sea_printf                 # (%rdi, %rsi, %rdx as given) into the sink
    movq $0, .Lrt_fmt_tosink(%rip)
    # The string object of the text.
    leaq sea_fmt_sink(%rip), %rax
    movq RTF_SINK_LEN(%rax), %r12   # <= SEA_LIM_STR_BYTES (.Lrt_fmt_sink_room)
    leaq SEA_STR_BYTES(%r12), %rdi
    movq %rbx, %rsi
    call sea_alloc
    movq $1, SEA_STR_RC(%rax)       # count 1
    movq $0, SEA_STR_TAG(%rax)      # the tag and the 7 bytes after it
    movb $SEA_TAG_STR, SEA_STR_TAG(%rax)
    movq %r12, SEA_STR_LEN(%rax)
    incq sea_live(%rip)             # one more live object
    movq %rax, 0(%rsp)              # the USER error's slot
    testq %r12, %r12
    jz 1f                           # an empty message: no bytes to copy
    leaq SEA_STR_BYTES(%rax), %rdi
    leaq sea_fmt_sink(%rip), %rcx
    movq RTF_SINK_PTR(%rcx), %rsi
    movq %r12, %rdx
    call memcpy@PLT
1:  movl $SEA_E_USER, %edi
    movq %rbx, %rsi
    movq %rsp, %rdx
    call sea_err                    # noreturn
    ud2
    .size sea_error, . - sea_error

# ---------------------------------------------------------------------
# sea_fmt_g -- an f64 as Sea's printf("%g") prints it.
#   Purpose : the spelling of sea_err's `f` arguments (DESIGN.md 2.6.2):
#             C's %g (precision 6) for finite values, NaN, Inf, -Inf
#             otherwise (LANGUAGE.md 11.1).
#   Inputs  : %rdi = destination (at least 16 bytes; at most 13 are
#             written, no NUL), %xmm0 = the value
#   Outputs : %rax = number of bytes written
#   Clobbers: all caller-saved registers, flags
#   Callee-saved used: %rbx = destination (saved and restored), %rbp =
#             frame pointer
#   Frame   : 16 bytes (%rbp %rbx) + 8 pad + RTF_GBUF (text at 0(%rsp))
#             = 56 bytes
# ---------------------------------------------------------------------
    .globl sea_fmt_g
    .hidden sea_fmt_g
    .type sea_fmt_g, @function
    .p2align 4
sea_fmt_g:
    pushq %rbp
    movq %rsp, %rbp
    pushq %rbx
    subq $(RTF_GBUF + 8), %rsp      # %rsp = 0 (mod 16)
    movq %rdi, %rbx
    # Non-finite: the MATLAB spelling, straight into the destination.
    movq %xmm0, %rsi
    movq %rsi, %rax
    shlq $1, %rax
    movabsq $RTF_INF2, %rcx
    cmpq %rcx, %rax
    jb 1f
    movq %rbx, %rdi
    xorl %edx, %edx                 # no flags
    call .Lrt_fmt_nonfinite         # %rax = length
    jmp 3f
1:  # Finite: snprintf "%g" into the local buffer, then copy.
    movl $103, %edi                 # 'g'
    xorl %esi, %esi
    movq $-1, %rdx                  # default precision 6
    movq %rsp, %rcx
    movl $RTF_GBUF, %r8d
    call .Lrt_fmt_float             # %rax = length
    xorl %ecx, %ecx
2:  movb (%rsp,%rcx), %dl
    movb %dl, (%rbx,%rcx)
    incq %rcx
    cmpq %rax, %rcx
    jb 2b
3:  addq $(RTF_GBUF + 8), %rsp
    popq %rbx
    popq %rbp
    ret
    .size sea_fmt_g, . - sea_fmt_g

    .bss
    .p2align 3
    .globl sea_fmt_sink
    .hidden sea_fmt_sink
    .type sea_fmt_sink, @object
    .size sea_fmt_sink, RTF_SINK_SIZE
sea_fmt_sink:
    .zero RTF_SINK_SIZE             # the growing text buffer: block, length, capacity
.Lrt_fmt_tosink:
    .zero 8                         # 1 while sea_error formats into the sink

    .section .note.GNU-stack,"",@progbits
