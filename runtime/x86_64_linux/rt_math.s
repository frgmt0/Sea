# =====================================================================
# sea/runtime/x86_64_linux/rt_math.s -- the elementary functions
# log exp sin cos pow hypot (LANGUAGE.md 10.4; DESIGN.md 4.10, 4.8
# entries 3-8, Decision 6).
#
# Defines (global, rt.inc SEA_ENT_LOG .. SEA_ENT_HYPOT):
#   sea_log sea_exp sea_sin sea_cos   %xmm0 = x          -> %xmm0
#   sea_pow sea_hypot                 %xmm0 = x, %xmm1 = y -> %xmm0
# Defines (global, rt.inc SEA_ENT_FMOD; DESIGN.md 2.11.6, 4.8 entry 26):
#   sea_fmod                          %xmm0 = a, %xmm1 = b -> %xmm0
#                  a % b of LANGUAGE.md 6.6 for f64 (floored, the sign of
#                  b): b = +-0 gives a's bits; else an infinite a or a NaN
#                  operand gives #7FF8000000000000; else r = glibc's
#                  fmod(a, b) (exact by IEEE 754), then r + b rounded once
#                  when r != 0 and r and b differ in sign (L-cm). It is
#                  not one of the elementary functions: an ordinary System V
#                  function that calls fmod through the PLT (libm, linked
#                  with -lm as every program is), the one exception to the
#                  "calls nothing outside this file" rule below.
# Defines (.globl + .hidden, internal, not contract; DESIGN.md 4.10.1):
#   sea_exp_core   e^(x + xt): %xmm0 = x (not NaN), %xmm1 = xt -> %xmm0
#   sea_log_core   ln of a positive normal pattern: %rax = ix
#                  -> %xmm0 = h, %xmm1 = l (h + l ~ ln x, h = RN(h + l))
#
# Every function is DESIGN.md 4.10.4 transcribed operation by operation:
# each `+ - * /` and sqrt of the text is one SSE2 scalar instruction on
# binary64, in the order the text gives (only commutative operands are
# swapped, which changes no bit), so the results equal the arm64 runtime's
# and the model's (tests/vectors/math_model.py) bit for bit. SSE2 only:
# no FMA, no roundsd, no x87; MXCSR is never changed. Integer steps are
# exact 64-bit operations; the Payne-Hanek products use mulq. Every NaN
# result is the pattern #7FF8000000000000 (NAN of sea_mt_const).
#
# ABI (DESIGN.md 4.10.1): System V AMD64 leaf code that may clobber
# %rax %rcx %rdx %rsi %rdi %r8-%r11, %xmm0-%xmm15 and the flags; it never
# touches %rbx %rbp %r12-%r15, uses at most 48 bytes below the return
# address (the internal calls and the frames of sea_pow and sea_sin/cos),
# references no symbol outside this file and calls nothing outside it.
#
# Notation in the comments: the names of DESIGN.md 4.10.4; `C(NAME)` is
# word NAME of sea_mt_const (include/math_tables.inc).
# =====================================================================
.include "rt.inc"
.include "math_tables.inc"

# Offsets of the 32 words of sea_mt_const (DESIGN.md 4.10.4, "Constants").
.equ MC_EXP_INVLN2N,    0*8
.equ MC_EXP_SHIFT,      1*8
.equ MC_EXP_NLN2HI_N,   2*8
.equ MC_EXP_NLN2LO_N,   3*8
.equ MC_EXP_C2,         4*8
.equ MC_EXP_C3,         5*8
.equ MC_EXP_C4,         6*8
.equ MC_EXP_C5,         7*8
.equ MC_LOG_LN2HI,      8*8
.equ MC_LOG_LN2LO,      9*8
.equ MC_LOG_A3,         10*8
.equ MC_LOG_A4,         11*8
.equ MC_LOG_A5,         12*8
.equ MC_LOG_A6,         13*8
.equ MC_LOG_A7,         14*8
.equ MC_LOG_A8,         15*8
.equ MC_LOG_A9,         16*8
.equ MC_TRIG_INVPIO2,   17*8
.equ MC_TRIG_P1,        18*8
.equ MC_TRIG_P2,        19*8
.equ MC_TRIG_P3,        20*8
.equ MC_TRIG_P4,        21*8
.equ MC_TRIG_PIO2_HI,   22*8
.equ MC_TRIG_PIO2_LO,   23*8
.equ MC_TRIG_S3,        24*8
.equ MC_TRIG_S5,        25*8
.equ MC_TRIG_S7,        26*8
.equ MC_TRIG_C2,        27*8
.equ MC_TRIG_C4,        28*8
.equ MC_TRIG_C6,        29*8
.equ MC_SPLIT,          30*8
.equ MC_NAN,            31*8

# Record sizes of the tables.
.equ MT_EXP_REC,        16          # EXP_TAIL, EXP_SBITS
.equ MT_LOG_REC,        24          # LOG_INVC, LOG_LOGC_HI, LOG_LOGC_LO
.equ MT_TRIG_REC,       32          # TRIG_SH, TRIG_SL, TRIG_CH, TRIG_CL

# Patterns written in the text of DESIGN.md 4.10.4.
.equ RTM_INF,           0x7FF0000000000000
.equ RTM_ONE,           0x3FF0000000000000
.equ RTM_MONE,          0xBFF0000000000000
.equ RTM_LOG_OFF,       0x3FE5F00000000000
.equ RTM_EXPMASK,       0xFFF0000000000000
.equ RTM_ZHI_MASK,      0xFFFFFFFFFC000000  # log_core: zhi, 27 significant bits
.equ RTM_HI27_MASK,     0xFFFFFFFFF8000000  # pow: yhi, lhi, 26 significant bits
.equ RTM_MANT,          0x000FFFFFFFFFFFFF
.equ RTM_SIN_TINY,      0x3E40000000000000  # 2^-27
.equ RTM_TRIG_R1_MAX,   0x4160000000000000  # 2^23
.equ RTM_HYP_BIG,       0x5F30000000000000  # 2^500
.equ RTM_HYP_SMALL,     0x20B0000000000000  # 2^-500
.equ RTM_HYP_SUBN,      0x2590000000000000  # 2^-422
# sea_fmod: the bits of +Inf shifted left by one (|bits| << 1 >= it: NaN or
# +-Inf; above it: NaN).
.equ RTM_INF2,          0xFFE0000000000000

# Local offsets into .Lrtm_k (the powers of two and small values of the text).
.equ K_ONE,             0*8         # 1.0
.equ K_TWO52,           1*8         # 2^52
.equ K_TWO1009,         2*8         # 2^1009
.equ K_TWOM1022,        3*8         # 2^-1022
.equ K_SIXTYFOUR,       4*8         # 64.0
.equ K_ONE64TH,         5*8         # 0.015625
.equ K_MHALF,           6*8         # -0.5
.equ K_TWOM53,          7*8         # 2^-53
.equ K_TWOM106,         8*8         # 2^-106
.equ K_TWOM159,         9*8         # 2^-159
.equ K_TWOM422,         10*8        # 2^-422
.equ K_TWO600,          11*8        # 2^600
.equ K_TWOM600,         12*8        # 2^-600
.equ K_INF,             13*8        # +Inf

# ---------------------------------------------------------------------
# The shared primitives of DESIGN.md 4.10.2, on xmm registers. Every
# output and temporary must be distinct from the inputs and from each
# other; the inputs are left unchanged.
# ---------------------------------------------------------------------
# TWO_SUM a, b -> s, e (temps t, u):
#   s = a + b; bb = s - a; e = (a - (s - bb)) + (b - bb)
.macro TWO_SUM a, b, s, e, t, u
    movapd \a, \s
    addsd \b, \s                    # s = a + b
    movapd \s, \t
    subsd \a, \t                    # t = bb = s - a
    movapd \s, \u
    subsd \t, \u                    # u = s - bb
    movapd \a, \e
    subsd \u, \e                    # e = a - (s - bb)
    movapd \b, \u
    subsd \t, \u                    # u = b - bb
    addsd \u, \e                    # e = (a - (s - bb)) + (b - bb)
.endm
# FAST_TWO_SUM a, b -> s, e (temp t): s = a + b; e = b - (s - a)
.macro FAST_TWO_SUM a, b, s, e, t
    movapd \a, \s
    addsd \b, \s                    # s = a + b
    movapd \s, \t
    subsd \a, \t                    # t = s - a
    movapd \b, \e
    subsd \t, \e                    # e = b - (s - a)
.endm
# SPLIT a -> h, l (temp t): g = SPLIT * a; h = g - (g - a); l = a - h
.macro SPLIT a, h, l, t
    movsd sea_mt_const+MC_SPLIT(%rip), \t
    mulsd \a, \t                    # t = g = 134217729.0 * a
    movapd \t, \h
    subsd \a, \h                    # h = g - a
    subsd \h, \t                    # t = g - (g - a)
    movapd \t, \h                   # h
    movapd \a, \l
    subsd \h, \l                    # l = a - h
.endm
# TWO_PROD a, b -> p, e (temps ah, al, bh, bl, t):
#   p = a * b; e = (((ah * bh - p) + ah * bl) + al * bh) + al * bl
.macro TWO_PROD a, b, p, e, ah, al, bh, bl, t
    movapd \a, \p
    mulsd \b, \p                    # p = a * b
    SPLIT \a, \ah, \al, \t
    SPLIT \b, \bh, \bl, \t
    movapd \ah, \e
    mulsd \bh, \e
    subsd \p, \e                    # ah * bh - p
    movapd \ah, \t
    mulsd \bl, \t
    addsd \t, \e                    # + ah * bl
    movapd \al, \t
    mulsd \bh, \t
    addsd \t, \e                    # + al * bh
    movapd \al, \t
    mulsd \bl, \t
    addsd \t, \e                    # + al * bl
.endm
# NEG x: flip the sign bit (exact).
.macro NEG x
    xorpd .Lrtm_sign(%rip), \x
.endm

    .text

# ---------------------------------------------------------------------
# sea_exp_core -- e^(x + xt) (DESIGN.md 4.10.4, exp_core).
#   Inputs  : %xmm0 = x (not NaN), %xmm1 = xt (|xt| <= 2^-25 |x|; 0.0 for
#             exp; not read when |x| >= 1024)
#   Outputs : %xmm0 = the result
#   Clobbers: %rax %rcx %rdx %rsi %r8-%r10, %xmm0-%xmm10, flags
#   Callee-saved used: none
#   Frame   : none (leaf)
# ---------------------------------------------------------------------
    .globl sea_exp_core
    .hidden sea_exp_core
    .type sea_exp_core, @function
    .p2align 4
sea_exp_core:
    movq %xmm0, %rax
    movq %rax, %rcx
    shrq $52, %rcx
    andl $0x7FF, %ecx               # top
    cmpl $0x3C9, %ecx
    jae 1f
    # 1. |x| < 2^-54: 1.0 + x.
    movsd .Lrtm_k+K_ONE(%rip), %xmm2
    addsd %xmm0, %xmm2
    movapd %xmm2, %xmm0
    ret
1:  cmpl $0x409, %ecx
    jb 3f
    # 2. |x| >= 1024: +0.0 for x < 0, else +Inf.
    testq %rax, %rax
    js 2f
    movsd .Lrtm_k+K_INF(%rip), %xmm0
    ret
2:  xorpd %xmm0, %xmm0
    ret
3:  # 3. Reduction.
    movsd sea_mt_const+MC_EXP_INVLN2N(%rip), %xmm2
    mulsd %xmm0, %xmm2              # z = EXP_INVLN2N * x
    addsd sea_mt_const+MC_EXP_SHIFT(%rip), %xmm2  # kd = z + EXP_SHIFT
    movq %xmm2, %rdx                # ki
    subsd sea_mt_const+MC_EXP_SHIFT(%rip), %xmm2  # kd = kd - EXP_SHIFT
    movapd %xmm2, %xmm3
    mulsd sea_mt_const+MC_EXP_NLN2HI_N(%rip), %xmm3 # kd * EXP_NLN2HI_N
    movapd %xmm0, %xmm4
    addsd %xmm3, %xmm4              # x + kd * EXP_NLN2HI_N
    movapd %xmm2, %xmm3
    mulsd sea_mt_const+MC_EXP_NLN2LO_N(%rip), %xmm3 # kd * EXP_NLN2LO_N
    addsd %xmm3, %xmm4              # r
    addsd %xmm1, %xmm4              # r = r + xt
    # 4. Table: i = ki & 127; tail; sbits = EXP_SBITS[i] + (ki << 45).
    movl %edx, %esi
    andl $127, %esi
    shlq $4, %rsi                   # i * MT_EXP_REC
    leaq sea_mt_exp(%rip), %r8
    movsd (%r8,%rsi), %xmm5         # tail
    movq 8(%r8,%rsi), %r9
    movq %rdx, %r10
    shlq $45, %r10
    addq %r10, %r9                  # sbits
    # 5. Polynomial.
    movapd %xmm4, %xmm6
    mulsd %xmm4, %xmm6              # r2 = r * r
    movapd %xmm5, %xmm7
    addsd %xmm4, %xmm7              # tail + r
    movapd %xmm4, %xmm8
    mulsd sea_mt_const+MC_EXP_C3(%rip), %xmm8     # r * EXP_C3
    addsd sea_mt_const+MC_EXP_C2(%rip), %xmm8     # EXP_C2 + r * EXP_C3
    mulsd %xmm6, %xmm8              # r2 * (...)
    addsd %xmm8, %xmm7              # (tail + r) + r2 * (...)
    movapd %xmm4, %xmm9
    mulsd sea_mt_const+MC_EXP_C5(%rip), %xmm9     # r * EXP_C5
    addsd sea_mt_const+MC_EXP_C4(%rip), %xmm9     # EXP_C4 + r * EXP_C5
    movapd %xmm6, %xmm10
    mulsd %xmm6, %xmm10             # r2 * r2
    mulsd %xmm10, %xmm9             # (r2 * r2) * (...)
    addsd %xmm9, %xmm7              # tmp
    cmpl $0x408, %ecx
    jae 4f
    # 6. |x| < 512: scale + scale * tmp.
    movq %r9, %xmm0                 # scale
    movapd %xmm0, %xmm1
    mulsd %xmm7, %xmm1              # scale * tmp
    addsd %xmm1, %xmm0
    ret
4:  # 7. 512 <= |x| < 1024 (rare), by the sign of k (bit 31 of ki).
    btl $31, %edx
    jc 5f
    movabsq $(1009 << 52), %r10
    subq %r10, %r9
    movq %r9, %xmm0                 # scale = f64(sbits - (1009 << 52))
    movapd %xmm0, %xmm1
    mulsd %xmm7, %xmm1              # scale * tmp
    addsd %xmm1, %xmm0              # scale + scale * tmp
    mulsd .Lrtm_k+K_TWO1009(%rip), %xmm0          # 2^1009 * (...)
    ret
5:  movabsq $(1022 << 52), %r10
    addq %r10, %r9
    movq %r9, %xmm2                 # scale = f64(sbits + (1022 << 52))
    movapd %xmm2, %xmm3
    mulsd %xmm7, %xmm3              # scale * tmp
    movapd %xmm2, %xmm0
    addsd %xmm3, %xmm0              # y = scale + scale * tmp
    ucomisd .Lrtm_k+K_ONE(%rip), %xmm0
    jae 6f                          # y >= 1.0: no subnormal rounding
    movapd %xmm2, %xmm4
    subsd %xmm0, %xmm4              # scale - y
    addsd %xmm3, %xmm4              # lo = (scale - y) + scale * tmp
    movsd .Lrtm_k+K_ONE(%rip), %xmm5
    addsd %xmm0, %xmm5              # hi = 1.0 + y
    movsd .Lrtm_k+K_ONE(%rip), %xmm6
    subsd %xmm5, %xmm6              # 1.0 - hi
    addsd %xmm0, %xmm6              # (1.0 - hi) + y
    addsd %xmm4, %xmm6              # lo = ((1.0 - hi) + y) + lo
    movapd %xmm5, %xmm0
    addsd %xmm6, %xmm0              # hi + lo
    subsd .Lrtm_k+K_ONE(%rip), %xmm0              # y = (hi + lo) - 1.0
6:  mulsd .Lrtm_k+K_TWOM1022(%rip), %xmm0         # 2^-1022 * y
    ret
    .size sea_exp_core, . - sea_exp_core

# ---------------------------------------------------------------------
# sea_exp -- e^x (DESIGN.md 4.10.4, exp).
#   Inputs  : %xmm0 = x       Outputs: %xmm0
#   Clobbers: as sea_exp_core, %xmm1
#   Frame   : none (tail jump)
# ---------------------------------------------------------------------
    .globl sea_exp
    .type sea_exp, @function
    .p2align 4
sea_exp:
    movq %xmm0, %rax
    btrq $63, %rax
    movabsq $RTM_INF, %rcx
    cmpq %rcx, %rax
    ja .Lrtm_nan                    # 1. NaN
    xorpd %xmm1, %xmm1              # 2. exp_core(x, 0.0)
    jmp sea_exp_core
    .size sea_exp, . - sea_exp

# .Lrtm_nan -- return the NaN result (shared tail of every entry).
    .p2align 4
.Lrtm_nan:
    movsd sea_mt_const+MC_NAN(%rip), %xmm0
    ret

# ---------------------------------------------------------------------
# sea_log_core -- (h, l) with h + l ~ ln x (DESIGN.md 4.10.4, log_core).
#   Inputs  : %rax = ix, the pattern of a positive normal value (its
#             unbiased exponent may be below -1022 after the subnormal
#             step of the callers)
#   Outputs : %xmm0 = h, %xmm1 = l
#   Clobbers: %rax %rcx %rdx %rsi %rdi %r8 %r9, %xmm0-%xmm15, flags
#   Callee-saved used: none
#   Frame   : none (leaf)
# ---------------------------------------------------------------------
    .globl sea_log_core
    .hidden sea_log_core
    .type sea_log_core, @function
    .p2align 4
sea_log_core:
    # 1. t, i, k, iz, z.
    movabsq $RTM_LOG_OFF, %rcx
    movq %rax, %rdx
    subq %rcx, %rdx                 # t = ix - LOG_OFF
    movq %rdx, %rsi
    shrq $45, %rsi
    andl $127, %esi                 # i
    movq %rdx, %rdi
    sarq $52, %rdi                  # k
    movabsq $RTM_EXPMASK, %rcx
    andq %rcx, %rdx
    movq %rax, %r8
    subq %rdx, %r8                  # iz = ix - (t & #FFF0000000000000)
    movq %r8, %xmm2                 # z
    leaq (%rsi,%rsi,2), %rsi
    leaq sea_mt_log(%rip), %r9
    leaq (%r9,%rsi,8), %rsi         # the record: &LOG_INVC[i]
    # 2. invc, zhi, zlo, rhi, rlo; (rh, rl) = two_sum(rhi, rlo).
    movsd (%rsi), %xmm3             # invc
    movabsq $RTM_ZHI_MASK, %rcx
    andq %r8, %rcx
    movq %rcx, %xmm4                # zhi
    movapd %xmm2, %xmm5
    subsd %xmm4, %xmm5              # zlo = z - zhi
    mulsd %xmm3, %xmm4              # zhi * invc
    subsd .Lrtm_k+K_ONE(%rip), %xmm4               # rhi = zhi * invc - 1.0
    mulsd %xmm3, %xmm5              # rlo = zlo * invc
    TWO_SUM %xmm4, %xmm5, %xmm6, %xmm7, %xmm8, %xmm9    # rh = xmm6, rl = xmm7
    # 3. kd, t1; (t2, e1) = two_sum(t1, rh).
    cvtsi2sdq %rdi, %xmm8           # kd
    movapd %xmm8, %xmm9
    mulsd sea_mt_const+MC_LOG_LN2HI(%rip), %xmm9   # kd * LOG_LN2HI
    addsd 8(%rsi), %xmm9            # t1 = ... + LOG_LOGC_HI[i]
    TWO_SUM %xmm9, %xmm6, %xmm10, %xmm11, %xmm12, %xmm13 # t2 = xmm10, e1 = xmm11
    # 4. (s, se) = two_prod(rh, rh); hs = -0.5 * s; (t3, e2) = two_sum(t2, hs).
    TWO_PROD %xmm6, %xmm6, %xmm12, %xmm13, %xmm14, %xmm15, %xmm2, %xmm3, %xmm4 # s, se
    movsd .Lrtm_k+K_MHALF(%rip), %xmm14
    mulsd %xmm12, %xmm14            # hs = -0.5 * s
    TWO_SUM %xmm10, %xmm14, %xmm2, %xmm3, %xmm4, %xmm15  # t3 = xmm2, e2 = xmm3
    # 5. r2 = rh * rh; p = (rh * r2) * (A3 + rh * (A4 + ... (A8 + rh * A9))).
    movapd %xmm6, %xmm4
    mulsd %xmm6, %xmm4              # r2
    movapd %xmm6, %xmm5
    mulsd sea_mt_const+MC_LOG_A9(%rip), %xmm5      # rh * A9
    addsd sea_mt_const+MC_LOG_A8(%rip), %xmm5      # A8 + rh * A9
    mulsd %xmm6, %xmm5
    addsd sea_mt_const+MC_LOG_A7(%rip), %xmm5      # A7 + rh * (...)
    mulsd %xmm6, %xmm5
    addsd sea_mt_const+MC_LOG_A6(%rip), %xmm5      # A6 + rh * (...)
    mulsd %xmm6, %xmm5
    addsd sea_mt_const+MC_LOG_A5(%rip), %xmm5      # A5 + rh * (...)
    mulsd %xmm6, %xmm5
    addsd sea_mt_const+MC_LOG_A4(%rip), %xmm5      # A4 + rh * (...)
    mulsd %xmm6, %xmm5
    addsd sea_mt_const+MC_LOG_A3(%rip), %xmm5      # A3 + rh * (...)
    movapd %xmm6, %xmm9
    mulsd %xmm4, %xmm9              # rh * r2
    mulsd %xmm5, %xmm9              # p
    # 6. lo.
    movapd %xmm8, %xmm10
    mulsd sea_mt_const+MC_LOG_LN2LO(%rip), %xmm10  # kd * LOG_LN2LO
    addsd 16(%rsi), %xmm10          # + LOG_LOGC_LO[i]
    addsd %xmm7, %xmm10             # lo = (...) + rl
    movapd %xmm11, %xmm12
    addsd %xmm3, %xmm12             # e1 + e2
    addsd %xmm12, %xmm10            # lo = lo + (e1 + e2)
    movsd .Lrtm_k+K_MHALF(%rip), %xmm12
    mulsd %xmm13, %xmm12            # -0.5 * se
    movapd %xmm6, %xmm14
    mulsd %xmm7, %xmm14             # rh * rl
    subsd %xmm14, %xmm12            # (-0.5 * se) - rh * rl
    addsd %xmm12, %xmm10            # lo = lo + (...)
    addsd %xmm9, %xmm10             # lo = lo + p
    # 7. (h, l) = fast_two_sum(t3, lo).
    FAST_TWO_SUM %xmm2, %xmm10, %xmm0, %xmm1, %xmm12
    ret
    .size sea_log_core, . - sea_log_core

# ---------------------------------------------------------------------
# sea_log -- ln x (DESIGN.md 4.10.4, log).
#   Inputs  : %xmm0 = x       Outputs: %xmm0
#   Clobbers: as sea_log_core
#   Frame   : 8 bytes (the internal call's return address)
# ---------------------------------------------------------------------
    .globl sea_log
    .type sea_log, @function
    .p2align 4
sea_log:
    movq %xmm0, %rax                # ix
    movq %rax, %rcx
    btrq $63, %rcx                  # |x| pattern
    movabsq $RTM_INF, %rdx
    cmpq %rdx, %rcx
    ja .Lrtm_nan                    # NaN
    testq %rcx, %rcx
    jz 2f                           # +-0: -Inf
    testq %rax, %rax
    js .Lrtm_nan                    # x < 0 (-Inf included)
    cmpq %rdx, %rcx
    je 1f                           # +Inf: +Inf (x itself)
    movq %rax, %rcx
    shrq $52, %rcx
    jnz 3f
    # 2. Subnormal (rare): ix = bits(x * 2^52) - (52 << 52).
    mulsd .Lrtm_k+K_TWO52(%rip), %xmm0
    movq %xmm0, %rax
    movabsq $(52 << 52), %rcx
    subq %rcx, %rax
3:  call sea_log_core               # 3. h of log_core(ix)
1:  ret
2:  movsd .Lrtm_k+K_INF(%rip), %xmm0
    NEG %xmm0                       # -Inf
    ret
    .size sea_log, . - sea_log

# ---------------------------------------------------------------------
# sea_pow -- x^y (DESIGN.md 4.10.4, pow; C99 F.9.4.4).
#   Inputs  : %xmm0 = x, %xmm1 = y   Outputs: %xmm0
#   Clobbers: %rax %rcx %rdx %rsi %rdi %r8-%r10, %xmm0-%xmm15, flags
#   Callee-saved used: none
#   Frame   : 24 bytes (y's pattern at 0(%rsp), negate at 8(%rsp)) + the
#             internal calls' return address
# ---------------------------------------------------------------------
    .globl sea_pow
    .type sea_pow, @function
    .p2align 4
sea_pow:
    movq %xmm0, %rax                # ix
    movq %xmm1, %rdx                # iy
    movabsq $RTM_INF, %r9
    # 1. y = +-0: 1.0.
    movq %rdx, %rcx
    shlq $1, %rcx
    jz .Lrtm_pow_one
    # 2. x = +1.0: 1.0.
    movabsq $RTM_ONE, %rcx
    cmpq %rcx, %rax
    je .Lrtm_pow_one
    # 3. x or y NaN: NAN.
    movq %rax, %rsi
    btrq $63, %rsi                  # |x| pattern
    cmpq %r9, %rsi
    ja .Lrtm_nan
    movq %rdx, %rdi
    btrq $63, %rdi                  # |y| pattern
    cmpq %r9, %rdi
    ja .Lrtm_nan
    # 4. y = +-Inf.
    jne 4f
    movabsq $RTM_MONE, %rcx
    cmpq %rcx, %rax
    je .Lrtm_pow_one                # x = -1: 1.0
    movabsq $RTM_ONE, %rcx
    testq %rdx, %rdx
    js 1f
    cmpq %rcx, %rsi                 # y = +Inf: +Inf if |x| > 1
    ja .Lrtm_pow_inf
    jmp .Lrtm_pow_zero
1:  cmpq %rcx, %rsi                 # y = -Inf: +Inf if |x| < 1
    jb .Lrtm_pow_inf
    jmp .Lrtm_pow_zero
4:  # 5. Classify y: %r8 = 0 not an integer, 1 odd, 2 even.
    movq %rdx, %rcx
    shrq $52, %rcx
    andl $0x7FF, %ecx               # e
    xorl %r8d, %r8d
    cmpl $1023, %ecx
    jb 6f                           # not an integer
    movl $2, %r8d
    cmpl $1075, %ecx
    ja 6f                           # even integer
    negl %ecx
    addl $1075, %ecx                # b = 1075 - e (0 .. 52)
    movl $1, %r10d
    shlq %cl, %r10                  # bit b
    leaq -1(%r10), %rcx             # bits 0 .. b-1
    xorl %r8d, %r8d
    testq %rcx, %rdx
    jnz 6f                          # not an integer
    movl $2, %r8d
    testq %r10, %rdx
    jz 6f                           # even
    movl $1, %r8d                   # odd
6:  # 6. x = +-0.
    movq %rax, %rcx
    shlq $1, %rcx
    jnz 7f
    testq %rdx, %rdx
    jns 1f
    testq %rax, %rax                # y < 0
    jns .Lrtm_pow_inf
    cmpl $1, %r8d
    jne .Lrtm_pow_inf
    jmp .Lrtm_pow_ninf              # x = -0, y odd: -Inf
1:  cmpl $1, %r8d                   # y > 0
    jne .Lrtm_pow_zero
    ret                             # odd: x itself (+-0)
7:  # 7. x = +-Inf.
    cmpq %r9, %rsi
    jne 8f
    testq %rax, %rax
    js 1f
    testq %rdx, %rdx                # x = +Inf
    js .Lrtm_pow_zero
    jmp .Lrtm_pow_inf
1:  testq %rdx, %rdx                # x = -Inf
    jns 2f
    cmpl $1, %r8d                   # y < 0
    jne .Lrtm_pow_zero
    xorpd %xmm0, %xmm0
    NEG %xmm0                       # -0.0
    ret
2:  cmpl $1, %r8d                   # y > 0
    jne .Lrtm_pow_inf
    jmp .Lrtm_pow_ninf
8:  subq $24, %rsp                  # y and negate kept across the core calls
    movq %rdx, 0(%rsp)
    movq $0, 8(%rsp)
    # 8. x < 0 (finite).
    testq %rax, %rax
    jns 9f
    testl %r8d, %r8d
    jz .Lrtm_pow_nan_frame          # y not an integer: NAN
    cmpl $1, %r8d
    jne 1f
    movq $1, 8(%rsp)                # negate: y odd
1:  movq %rsi, %rax                 # clear bit 63 of ix
9:  # 9. Subnormal x (rare).
    movq %rax, %rcx
    shrq $52, %rcx
    jnz 1f
    movq %rax, %xmm0
    mulsd .Lrtm_k+K_TWO52(%rip), %xmm0
    movq %xmm0, %rax
    movabsq $(52 << 52), %rcx
    subq %rcx, %rax
1:  # 10. (lh, lt) = log_core(ix); the products with y.
    call sea_log_core               # %xmm0 = lh, %xmm1 = lt
    movq 0(%rsp), %rdx              # iy
    movq %rdx, %xmm2                # y
    movabsq $RTM_HI27_MASK, %rcx
    andq %rcx, %rdx
    movq %rdx, %xmm3                # yhi
    movapd %xmm2, %xmm4
    subsd %xmm3, %xmm4              # ylo = y - yhi
    movq %xmm0, %rdx
    andq %rcx, %rdx
    movq %rdx, %xmm5                # lhi
    movapd %xmm0, %xmm6
    subsd %xmm5, %xmm6              # lh - lhi
    addsd %xmm1, %xmm6              # llo = (lh - lhi) + lt
    movapd %xmm3, %xmm0
    mulsd %xmm5, %xmm0              # ehi = yhi * lhi
    movapd %xmm4, %xmm1
    mulsd %xmm5, %xmm1              # ylo * lhi
    mulsd %xmm6, %xmm2              # y * llo
    addsd %xmm2, %xmm1              # elo = (ylo * lhi) + (y * llo)
    # 11. v = exp_core(ehi, elo).
    call sea_exp_core
    # 12. neg(v) if negate.
    cmpq $0, 8(%rsp)
    je 1f
    NEG %xmm0
1:  addq $24, %rsp
    ret
.Lrtm_pow_nan_frame:
    addq $24, %rsp
    jmp .Lrtm_nan
.Lrtm_pow_one:
    movsd .Lrtm_k+K_ONE(%rip), %xmm0
    ret
.Lrtm_pow_inf:
    movsd .Lrtm_k+K_INF(%rip), %xmm0
    ret
.Lrtm_pow_ninf:
    movsd .Lrtm_k+K_INF(%rip), %xmm0
    NEG %xmm0
    ret
.Lrtm_pow_zero:
    xorpd %xmm0, %xmm0
    ret
    .size sea_pow, . - sea_pow

# ---------------------------------------------------------------------
# sea_sin, sea_cos -- sin x, cos x (DESIGN.md 4.10.4, sin and cos).
#   Inputs  : %xmm0 = x       Outputs: %xmm0
#   Clobbers: %rax %rcx %rdx %rsi %rdi %r8-%r11, %xmm0-%xmm15, flags
#   Callee-saved used: none
#   Frame   : 24 bytes (ix at 0(%rsp), the cos flag at 8(%rsp), q at
#             16(%rsp)); reduce and trig_core are inline
# ---------------------------------------------------------------------
    .globl sea_sin
    .type sea_sin, @function
    .p2align 4
sea_sin:
    xorl %edi, %edi                 # sin
    jmp .Lrtm_trig
    .size sea_sin, . - sea_sin

    .globl sea_cos
    .type sea_cos, @function
    .p2align 4
sea_cos:
    movl $1, %edi                   # cos
    jmp .Lrtm_trig
    .size sea_cos, . - sea_cos

    .p2align 4
.Lrtm_trig:
    movq %xmm0, %rax                # ix
    movq %rax, %rdx
    btrq $63, %rdx                  # bits(ax)
    # 1. |x| Inf or NaN: NAN.
    movabsq $RTM_INF, %rcx
    cmpq %rcx, %rdx
    jae .Lrtm_nan
    # 2. |x| < 2^-27: sin gives x, cos 1.0.
    movabsq $RTM_SIN_TINY, %rcx
    cmpq %rcx, %rdx
    jae 1f
    testl %edi, %edi
    jz 2f
    movsd .Lrtm_k+K_ONE(%rip), %xmm0
2:  ret
1:  subq $24, %rsp
    movq %rax, 0(%rsp)              # ix
    movq %rdi, 8(%rsp)              # 1 for cos
    movq %rdx, %xmm0                # ax
    # 3. (q, rh, rl) = reduce(ax).
    movabsq $RTM_TRIG_R1_MAX, %rcx
    cmpq %rcx, %rdx
    jae .Lrtm_trig_ph
    # R1, Cody-Waite (ax < 2^23).
    movsd sea_mt_const+MC_TRIG_INVPIO2(%rip), %xmm1
    mulsd %xmm0, %xmm1              # z = ax * TRIG_INVPIO2
    addsd sea_mt_const+MC_EXP_SHIFT(%rip), %xmm1  # kd = z + EXP_SHIFT
    movq %xmm1, %rcx
    andl $3, %ecx
    movq %rcx, 16(%rsp)             # q
    subsd sea_mt_const+MC_EXP_SHIFT(%rip), %xmm1  # kd = kd - EXP_SHIFT
    movapd %xmm1, %xmm2
    mulsd sea_mt_const+MC_TRIG_P1(%rip), %xmm2    # kd * TRIG_P1
    movapd %xmm0, %xmm3
    subsd %xmm2, %xmm3              # t1 = ax - kd * TRIG_P1
    movapd %xmm1, %xmm2
    mulsd sea_mt_const+MC_TRIG_P2(%rip), %xmm2
    NEG %xmm2                       # neg(kd * TRIG_P2)
    TWO_SUM %xmm3, %xmm2, %xmm4, %xmm5, %xmm6, %xmm7    # (s, e)
    movapd %xmm1, %xmm2
    mulsd sea_mt_const+MC_TRIG_P3(%rip), %xmm2
    NEG %xmm2                       # neg(kd * TRIG_P3)
    TWO_SUM %xmm4, %xmm2, %xmm6, %xmm7, %xmm8, %xmm9    # (h, l1)
    movapd %xmm1, %xmm2
    mulsd sea_mt_const+MC_TRIG_P4(%rip), %xmm2    # kd * TRIG_P4
    movapd %xmm5, %xmm3
    subsd %xmm2, %xmm3              # e - kd * TRIG_P4
    addsd %xmm3, %xmm7              # l = l1 + (...)
    TWO_SUM %xmm6, %xmm7, %xmm0, %xmm1, %xmm8, %xmm9    # (rh, rl)
    jmp .Lrtm_trig_core

.Lrtm_trig_ph:
    # R2, Payne-Hanek (rare, ax >= 2^23). %rdx = bits(ax).
    # 1. m, E, G, w, sh.
    movabsq $RTM_MANT, %rsi
    andq %rdx, %rsi
    btsq $52, %rsi                  # m
    shrq $52, %rdx
    subq $(1075 - 62), %rdx         # G = E + 62, E = exponent - 1075
    movl %edx, %ecx
    andl $63, %ecx                  # sh
    shrq $6, %rdx                   # w
    leaq sea_mt_tpi(%rip), %r8
    leaq (%r8,%rdx,8), %r8          # &TPI[w]
    # 2. word(n) = (TPI[n] << sh) | ((TPI[n+1] >> 1) >> (63 - sh)).
.macro RTM_PH_WORD off, dst
    movq \off(%r8), \dst
    shlq %cl, \dst                  # TPI[n] << sh
    movq \off+8(%r8), %rax
    shrq $1, %rax                   # TPI[n+1] >> 1
    xorl $63, %ecx                  # cl = 63 - sh (sh in 0 .. 63)
    shrq %cl, %rax
    xorl $63, %ecx                  # cl = sh again
    orq %rax, \dst
.endm
    RTM_PH_WORD 0, %r9              # W2
    RTM_PH_WORD 8, %rdi             # W1
    RTM_PH_WORD 16, %r10            # W0
    # 3. P2:P1:P0 = m * window mod 2^192.
    movq %rsi, %rax
    mulq %r10                       # m * W0 = (c0, a0)
    movq %rax, %r10                 # P0 = a0
    movq %rdx, %r11                 # c0
    movq %rsi, %rax
    mulq %rdi                       # m * W1 = (c1, a1)
    addq %rax, %r11                 # P1 = c0 + a1, carry = k1 = (P1 < a1)
    adcq $0, %rdx                   # c1 + k1
    imulq %rsi, %r9                 # a2 = low half of m * W2
    addq %rdx, %r9                  # P2 = c1 + a2 + k1
    # 4. q; T2, T1, T0.
    movq %r9, %rax
    shrq $62, %rax
    movq %r9, %rdx
    shrq $61, %rdx
    andl $1, %edx
    addq %rdx, %rax
    andl $3, %eax
    movq %rax, 16(%rsp)             # q
    movq %r9, %rax
    shlq $2, %rax
    movq %r11, %rdx
    shrq $62, %rdx
    orq %rdx, %rax                  # T2 = (P2 << 2) | (P1 >> 62)
    movq %r11, %rsi
    shlq $2, %rsi
    movq %r10, %rdx
    shrq $62, %rdx
    orq %rdx, %rsi                  # T1 = (P1 << 2) | (P0 >> 62)
    shlq $2, %r10                   # T0 = P0 << 2
    # 5. A, B, C; a, b, c; (h, l).
    movq %rax, %rdx
    sarq $11, %rdx                  # A = T2 >>a 11
    cvtsi2sdq %rdx, %xmm2
    mulsd .Lrtm_k+K_TWOM53(%rip), %xmm2           # a
    andl $0x7FF, %eax
    shlq $42, %rax
    movq %rsi, %rdx
    shrq $22, %rdx
    orq %rdx, %rax                  # B
    cvtsi2sdq %rax, %xmm3
    mulsd .Lrtm_k+K_TWOM106(%rip), %xmm3          # b
    andl $0x3FFFFF, %esi
    shlq $31, %rsi
    shrq $33, %r10
    orq %r10, %rsi                  # C
    cvtsi2sdq %rsi, %xmm4
    mulsd .Lrtm_k+K_TWOM159(%rip), %xmm4          # c
    TWO_SUM %xmm2, %xmm3, %xmm5, %xmm6, %xmm7, %xmm8    # (h, l) = two_sum(a, b)
    TWO_SUM %xmm5, %xmm4, %xmm9, %xmm10, %xmm7, %xmm8   # (h, t) = two_sum(h, c)
    addsd %xmm10, %xmm6             # l = l + t
    # 6. r = f * pi/2.
    movsd sea_mt_const+MC_TRIG_PIO2_HI(%rip), %xmm11
    TWO_PROD %xmm9, %xmm11, %xmm12, %xmm13, %xmm2, %xmm3, %xmm4, %xmm5, %xmm7 # (p, pe)
    movapd %xmm9, %xmm2
    mulsd sea_mt_const+MC_TRIG_PIO2_LO(%rip), %xmm2 # h * TRIG_PIO2_LO
    movapd %xmm6, %xmm3
    mulsd %xmm11, %xmm3             # l * TRIG_PIO2_HI
    addsd %xmm3, %xmm2              # (h * PIO2_LO) + (l * PIO2_HI)
    addsd %xmm2, %xmm13             # pl = pe + (...)
    FAST_TWO_SUM %xmm12, %xmm13, %xmm0, %xmm1, %xmm2    # (rh, rl)

.Lrtm_trig_core:
    # 4. use_cos: sin q & 1, cos 1 - (q & 1). %rsi = use_cos.
    movq 16(%rsp), %rsi
    andl $1, %esi
    xorl 8(%rsp), %esi              # (q & 1) ^ cos
    # trig_core(rh = xmm0, rl = xmm1, use_cos); sr in %r8.
    # 1. ar, al.
    movq %xmm0, %r8
    shrq $63, %r8                   # sr
    movapd %xmm0, %xmm2
    andpd .Lrtm_abs(%rip), %xmm2    # ar = abs(rh)
    movapd %xmm1, %xmm3             # al = rl ...
    testq %r8, %r8
    jz 1f
    NEG %xmm3                       # ... or neg(rl) if sr
1:  # 2. jd, j, th.
    movapd %xmm2, %xmm4
    mulsd .Lrtm_k+K_SIXTYFOUR(%rip), %xmm4        # ar * 64.0
    addsd sea_mt_const+MC_EXP_SHIFT(%rip), %xmm4  # jd = ... + EXP_SHIFT
    movq %xmm4, %rcx
    andl $0xFF, %ecx                # j
    subsd sea_mt_const+MC_EXP_SHIFT(%rip), %xmm4  # jd = jd - EXP_SHIFT
    mulsd .Lrtm_k+K_ONE64TH(%rip), %xmm4          # jd * 0.015625
    movapd %xmm2, %xmm5
    subsd %xmm4, %xmm5              # th = ar - jd * 0.015625
    # 3. t2, sinp, cosp.
    movapd %xmm5, %xmm6
    mulsd %xmm5, %xmm6              # t2 = th * th
    movapd %xmm6, %xmm7
    mulsd sea_mt_const+MC_TRIG_S7(%rip), %xmm7    # t2 * TRIG_S7
    addsd sea_mt_const+MC_TRIG_S5(%rip), %xmm7    # TRIG_S5 + ...
    mulsd %xmm6, %xmm7              # t2 * (...)
    addsd sea_mt_const+MC_TRIG_S3(%rip), %xmm7    # TRIG_S3 + ...
    movapd %xmm5, %xmm8
    mulsd %xmm6, %xmm8              # th * t2
    mulsd %xmm7, %xmm8              # sinp
    movapd %xmm6, %xmm7
    mulsd sea_mt_const+MC_TRIG_C6(%rip), %xmm7    # t2 * TRIG_C6
    addsd sea_mt_const+MC_TRIG_C4(%rip), %xmm7    # TRIG_C4 + ...
    mulsd %xmm6, %xmm7              # t2 * (...)
    addsd sea_mt_const+MC_TRIG_C2(%rip), %xmm7    # TRIG_C2 + ...
    mulsd %xmm6, %xmm7              # cosp = t2 * (...)
    # 4. A (xmm9), AL (xmm10), B (xmm11), BL (xmm12).
    shlq $5, %rcx                   # j * MT_TRIG_REC
    leaq sea_mt_trig(%rip), %rdx
    addq %rcx, %rdx
    testl %esi, %esi
    jnz 2f
    movsd 0(%rdx), %xmm9            # TRIG_SH
    movsd 8(%rdx), %xmm10           # TRIG_SL
    movsd 16(%rdx), %xmm11          # TRIG_CH
    movsd 24(%rdx), %xmm12          # TRIG_CL
    jmp 3f
2:  movsd 16(%rdx), %xmm9           # TRIG_CH
    movsd 24(%rdx), %xmm10          # TRIG_CL
    movsd 0(%rdx), %xmm11
    NEG %xmm11                      # neg(TRIG_SH)
    movsd 8(%rdx), %xmm12
    NEG %xmm12                      # neg(TRIG_SL)
3:  # 5. (p, pe) = two_prod(B, th); (h, e) = fast_two_sum(A, p); lo; v.
    TWO_PROD %xmm11, %xmm5, %xmm13, %xmm14, %xmm0, %xmm1, %xmm2, %xmm4, %xmm6 # p, pe
    FAST_TWO_SUM %xmm9, %xmm13, %xmm15, %xmm0, %xmm1    # h = xmm15, e = xmm0
    addsd %xmm14, %xmm0             # e + pe
    movapd %xmm12, %xmm1
    mulsd %xmm5, %xmm1              # BL * th
    addsd %xmm10, %xmm1             # AL + BL * th
    addsd %xmm1, %xmm0              # lo = (e + pe) + (AL + BL * th)
    movapd %xmm8, %xmm1
    addsd %xmm3, %xmm1              # sinp + al
    mulsd %xmm11, %xmm1             # B * (sinp + al)
    addsd %xmm1, %xmm0              # lo = lo + ...
    movapd %xmm3, %xmm1
    mulsd %xmm5, %xmm1              # al * th
    movapd %xmm7, %xmm2
    subsd %xmm1, %xmm2              # cosp - al * th
    mulsd %xmm9, %xmm2              # A * (...)
    addsd %xmm2, %xmm0              # lo = lo + ...
    addsd %xmm0, %xmm15             # v = h + lo
    movapd %xmm15, %xmm0
    # 5. (of sin/cos) The sign. odd = sr & !use_cos.
    xorl $1, %esi
    andl %esi, %r8d                 # odd
    movq 16(%rsp), %rax             # q
    cmpq $0, 8(%rsp)
    jne 4f
    shrl $1, %eax                   # sin: (q >> 1) ^ odd ^ sign(ix)
    xorl %r8d, %eax
    movq 0(%rsp), %rdx
    shrq $63, %rdx
    xorl %edx, %eax
    jmp 5f
4:  incl %eax                       # cos: (((q + 1) >> 1) & 1) ^ odd
    shrl $1, %eax
    andl $1, %eax
    xorl %r8d, %eax
5:  testl $1, %eax
    jz 6f
    NEG %xmm0
6:  addq $24, %rsp
    ret

# ---------------------------------------------------------------------
# sea_hypot -- sqrt(x^2 + y^2) (DESIGN.md 4.10.4, hypot).
#   Inputs  : %xmm0 = x, %xmm1 = y   Outputs: %xmm0
#   Clobbers: %rax %rcx %rdx %r8, %xmm0-%xmm15, flags
#   Callee-saved used: none
#   Frame   : none (leaf)
# ---------------------------------------------------------------------
    .globl sea_hypot
    .type sea_hypot, @function
    .p2align 4
sea_hypot:
    # 1. An infinity: +Inf; then a NaN: NAN.
    movq %xmm0, %rax
    btrq $63, %rax                  # bits(ax)
    movq %xmm1, %rdx
    btrq $63, %rdx                  # bits(ay)
    movabsq $RTM_INF, %rcx
    cmpq %rcx, %rax
    je 1f
    cmpq %rcx, %rdx
    je 1f
    cmpq %rcx, %rax
    ja .Lrtm_nan
    cmpq %rcx, %rdx
    ja .Lrtm_nan
    # 2. ax >= ay; ay = 0: ax.
    cmpq %rdx, %rax
    jae 2f
    xchgq %rax, %rdx
2:  movq %rax, %xmm0                # ax
    movq %rdx, %xmm1                # ay
    testq %rdx, %rdx
    jnz 3f
    ret
1:  movsd .Lrtm_k+K_INF(%rip), %xmm0
    ret
3:  # 3. Scale: %r8 = 0 (1.0), 1 (2^600), 2 (2^-600).
    xorl %r8d, %r8d
    movabsq $RTM_HYP_BIG, %rcx
    cmpq %rcx, %rax
    jbe 4f
    movsd .Lrtm_k+K_TWOM600(%rip), %xmm2
    mulsd %xmm2, %xmm0              # ax * 2^-600
    mulsd %xmm2, %xmm1              # ay * 2^-600
    movl $1, %r8d
    jmp 5f
4:  movabsq $RTM_HYP_SMALL, %rcx
    cmpq %rcx, %rax
    jae 5f
    movsd .Lrtm_k+K_TWO600(%rip), %xmm2
    mulsd %xmm2, %xmm0              # ax * 2^600
    mulsd %xmm2, %xmm1              # ay * 2^600
    movl $2, %r8d
5:  # 4. (p, pe), (q, qe), (sh, sl).
    TWO_PROD %xmm0, %xmm0, %xmm2, %xmm3, %xmm8, %xmm9, %xmm10, %xmm11, %xmm12 # p, pe
    TWO_PROD %xmm1, %xmm1, %xmm4, %xmm5, %xmm8, %xmm9, %xmm10, %xmm11, %xmm12 # q, qe
    TWO_SUM %xmm2, %xmm4, %xmm6, %xmm7, %xmm8, %xmm9    # (sh, sl)
    movapd %xmm3, %xmm8
    addsd %xmm5, %xmm8              # pe + qe
    addsd %xmm8, %xmm7              # sl = sl + (pe + qe)
    FAST_TWO_SUM %xmm6, %xmm7, %xmm0, %xmm1, %xmm8      # (sh, sl) = xmm0, xmm1
    # 5. h, (hh, he), d, corr.
    sqrtsd %xmm0, %xmm2             # h = sqrt(sh)
    TWO_PROD %xmm2, %xmm2, %xmm3, %xmm4, %xmm8, %xmm9, %xmm10, %xmm11, %xmm12 # hh, he
    movapd %xmm0, %xmm5
    subsd %xmm3, %xmm5              # sh - hh
    subsd %xmm4, %xmm5              # (sh - hh) - he
    addsd %xmm1, %xmm5              # d = ... + sl
    movapd %xmm2, %xmm6
    addsd %xmm2, %xmm6              # h + h
    divsd %xmm6, %xmm5              # corr = d / (h + h)
    # 6. The result.
    cmpl $2, %r8d
    jne 6f
    movq %xmm2, %rax
    movabsq $RTM_HYP_SUBN, %rcx
    cmpq %rcx, %rax
    jae 7f
    # Subnormal result (rare): round once at the subnormal precision.
    movsd .Lrtm_k+K_TWOM422(%rip), %xmm7
    TWO_SUM %xmm7, %xmm2, %xmm8, %xmm9, %xmm10, %xmm11  # (u, ue) = two_sum(2^-422, h)
    addsd %xmm5, %xmm9              # lo = ue + corr
    addsd %xmm9, %xmm8              # u + lo
    subsd %xmm7, %xmm8              # (u + lo) - 2^-422
    mulsd .Lrtm_k+K_TWOM600(%rip), %xmm8          # * 2^-600
    movapd %xmm8, %xmm0
    ret
7:  addsd %xmm5, %xmm2              # h + corr
    mulsd .Lrtm_k+K_TWOM600(%rip), %xmm2          # * scale (2^-600)
    movapd %xmm2, %xmm0
    ret
6:  addsd %xmm5, %xmm2              # h + corr
    movsd .Lrtm_k+K_ONE(%rip), %xmm3
    cmpl $1, %r8d
    jne 8f
    movsd .Lrtm_k+K_TWO600(%rip), %xmm3
8:  mulsd %xmm3, %xmm2              # (h + corr) * scale
    movapd %xmm2, %xmm0
    ret
    .size sea_hypot, . - sea_hypot

# ---------------------------------------------------------------------
# sea_fmod -- a % b for f64 (entry FMOD; LANGUAGE.md 6.6; DESIGN.md 4.8
#   entry 26, L-cm).
#   Purpose : the floored remainder, in the order of LANGUAGE.md 6.6:
#             (1) b = +-0: a unchanged (inf % 0 = inf, nan % 0 = NaN with
#             a's payload); (2) a = +-Inf or a NaN or b NaN:
#             #7FF8000000000000; (3) r = fmod(a, b), exact, the sign of a
#             (a zero keeps it: -6 % 3 = -0); (4) if r != +-0 and the sign
#             bits of r and b differ, r = r + b (one rounding). b = +-Inf
#             falls out of (3)-(4): fmod gives a, then a + b = b when the
#             signs differ (-1 % inf = inf).
#   Inputs  : %xmm0 = a, %xmm1 = b
#   Outputs : %xmm0 = the result
#   Clobbers: all caller-saved registers (fmod is a C function), flags
#   Callee-saved used: %rbp = frame pointer
#   Frame   : 8 bytes (%rbp) + 16 (b at 0(%rsp)); cannot fail
# ---------------------------------------------------------------------
    .globl sea_fmod
    .type sea_fmod, @function
    .p2align 4
sea_fmod:
    movq %xmm1, %rcx                # bits(b)
    movq %rcx, %rdx
    shlq $1, %rdx                   # |b| << 1
    jz .Lrtm_fmod_ret               # (1) b = +-0: a's bits, unchanged
    movabsq $RTM_INF2, %r8
    cmpq %r8, %rdx
    ja .Lrtm_fmod_nan               # (2) b is NaN
    movq %xmm0, %rax
    shlq $1, %rax                   # |a| << 1
    cmpq %r8, %rax
    jae .Lrtm_fmod_nan              # (2) a is +-Inf or NaN
    # (3) r = fmod(a, b): exact, so glibc gives the bits Apple's libm does.
    pushq %rbp                      # %rsp = 0 (mod 16)
    movq %rsp, %rbp
    subq $16, %rsp                  # b kept at 0(%rsp) across the call
    movsd %xmm1, 0(%rsp)
    call fmod@PLT                   # %xmm0 = r
    movq %xmm0, %rax
    movq %rax, %rdx
    shlq $1, %rdx
    jz 1f                           # r = +-0: kept, with the sign of a
    xorq 0(%rsp), %rax              # sign(r) XOR sign(b) in bit 63
    jns 1f                          # same sign: r is the result
    addsd 0(%rsp), %xmm0            # (4) r + b, rounded once
1:  movq %rbp, %rsp
    popq %rbp
.Lrtm_fmod_ret:
    ret
.Lrtm_fmod_nan:
    movsd sea_mt_const+MC_NAN(%rip), %xmm0   # the NaN of .Lrtm_nan
    ret
    .size sea_fmod, . - sea_fmod

# ---------------------------------------------------------------------
# Read-only data: the tables (include/math_tables.inc) and the local
# constants of the text.
# ---------------------------------------------------------------------
    .section .rodata
    SEA_EMIT_MATH_TABLES
    .p2align 4
.Lrtm_sign:
    .quad 0x8000000000000000, 0     # xorpd mask: flip the sign of the low lane
.Lrtm_abs:
    .quad 0x7FFFFFFFFFFFFFFF, 0     # andpd mask: clear the sign of the low lane
.Lrtm_k:
    .quad 0x3FF0000000000000        # K_ONE       1.0
    .quad 0x4330000000000000        # K_TWO52     2^52
    .quad 0x7F00000000000000        # K_TWO1009   2^1009
    .quad 0x0010000000000000        # K_TWOM1022  2^-1022
    .quad 0x4050000000000000        # K_SIXTYFOUR 64.0
    .quad 0x3F90000000000000        # K_ONE64TH   0.015625
    .quad 0xBFE0000000000000        # K_MHALF     -0.5
    .quad 0x3CA0000000000000        # K_TWOM53    2^-53
    .quad 0x3950000000000000        # K_TWOM106   2^-106
    .quad 0x3600000000000000        # K_TWOM159   2^-159
    .quad 0x2590000000000000        # K_TWOM422   2^-422
    .quad 0x6570000000000000        # K_TWO600    2^600
    .quad 0x1A70000000000000        # K_TWOM600   2^-600
    .quad 0x7FF0000000000000        # K_INF       +Inf

    .section .note.GNU-stack,"",@progbits
