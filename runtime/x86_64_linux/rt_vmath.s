# =====================================================================
# sea/runtime/x86_64_linux/rt_vmath.s -- the vector forms of the
# elementary functions log exp sin cos pow hypot (DESIGN.md 2.12.8,
# 4.10.1 "Vector forms"; rt.inc entries 39-50, Decision 103).
#
# Defines (global, rt.inc SEA_ENT_LOG_X .. SEA_ENT_HYPOT_Y):
#   sea_log_x sea_exp_x sea_sin_x sea_cos_x  %xmm0 = x (2 lanes) -> %xmm0
#   sea_pow_x sea_hypot_x                    %xmm0 = x, %xmm1 = y -> %xmm0
#   sea_log_y sea_exp_y sea_sin_y sea_cos_y  %ymm0 = x (4 lanes) -> %ymm0
#   sea_pow_y sea_hypot_y                    %ymm0 = x, %ymm1 = y -> %ymm0
# Each lane of the result is exactly the scalar entry of rt_math.s
# (sea_log ... sea_hypot) applied to that lane: the vector code below is
# DESIGN.md 4.10.4 transcribed operation by operation, as rt_math.s is,
# with packed instructions (one `+ - * /` or sqrt of the text is one
# packed SSE2/AVX instruction on binary64, in the order of the text; only
# commutative operands are swapped). No FMA, no approximate instruction,
# no rounding instruction; MXCSR is never changed.
#
# How the text becomes vector code (DESIGN.md 2.12.8 "Algorithm"):
#   * a branch of the text that the common inputs can take is a per-lane
#     select (andpd/andnpd/orpd on SSE2, vblendvpd on AVX2) between the
#     two values, both computed in every lane: exp_core's |x| < 2^-54
#     (1.0 + x), sin/cos's |x| < 2^-27, the use_cos choice of the trig
#     table words and the sign of sin/cos, hypot's swap (max/min), ay = 0
#     and its three scale factors;
#   * a table lookup is a per-lane load (SSE2: the two indices moved to
#     %rax and %rcx, movsd + movhpd; AVX2: vgatherqpd);
#   * the *rare* lanes are found by one vector compare per condition
#     (movmskpd into a lane bit mask) and computed by calling the scalar
#     entry on that lane's operands (the common case calls nothing):
#       exp      NaN, |x| >= 512 (step 7 and the infinities)
#       log      NaN, x <= 0, +Inf, subnormal x
#       pow      x or y NaN, y = +-0 or +-Inf, x = +-0, +-Inf, x < 0,
#                subnormal x, and |ehi| >= 512 (exp_core steps 2 and 7)
#       sin/cos  NaN, +-Inf, |x| >= 2^23 (the Payne-Hanek reduction)
#       hypot    an infinite or NaN operand, the subnormal result of
#                step 6
#     Before the common computation a rare lane's operands are replaced
#     by a harmless value (0.0 or 1.0), so every table index stays in
#     range; its common result is then overwritten by the scalar one.
#   * the steps that need what SSE2 lacks are exact sequences: log_core's
#     k = t >>a 52 is the arithmetic 32-bit shift of t's upper half
#     (psrad 20) and itof(k) the exact 32-bit conversion cvtdq2pd; pow's
#     integer classification of y (variable shifts) belongs to its
#     x < 0 step only, which is a rare lane (see "pow" below).
#
# ABI (DESIGN.md 2.12.8, 4.10.1): may clobber %rax %rcx %rdx %rsi %rdi
# %r8-%r11, every vector register and the flags; preserves %rbx %rbp
# %r12-%r15, %rsp, the MXCSR control bits and the x87 state; the
# direction flag stays clear. The _y entries are called only from 4-lane
# code and return with the upper halves live: they execute no vzeroupper
# before returning; before calling a scalar entry for a rare lane they
# store their live ymm values in their frame and execute vzeroupper (the
# scalar entries are legacy SSE code). Stack: the frame of VFRAME bytes
# plus the scalar entry's call (8) and its at most 256 bytes (4.10.1):
# 216 + 8 + 256 = 480 <= 512 bytes below the return address.
#
# The _x entries use the x86-64 baseline (SSE2) only; the _y entries use
# AVX2 (DESIGN.md 2.12.8: named only by 4-lane code, which runs only when
# the CPU has AVX2, Decision 104). Both are instantiated from the same
# macros below (VW = 2 or 4 lanes, P = xmm or ymm).
#
# This file includes math_tables.inc and emits its own copy of the
# tables (the labels sea_mt_* are file-local in each including file);
# the constants of the text that are table words are broadcast from
# sea_mt_const (KB), the powers of two and masks written in the text are
# in .Lrvm_k, each replicated over four lanes.
#
# Notation in the comments: the names of DESIGN.md 4.10.4; Rn is %xmmn
# or %ymmn.
# =====================================================================
.include "rt.inc"
.include "math_tables.inc"

# Offsets of the words of sea_mt_const (DESIGN.md 4.10.4, "Constants").
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
.equ MC_TRIG_S3,        24*8
.equ MC_TRIG_S5,        25*8
.equ MC_TRIG_S7,        26*8
.equ MC_TRIG_C2,        27*8
.equ MC_TRIG_C4,        28*8
.equ MC_TRIG_C6,        29*8
.equ MC_SPLIT,          30*8

# Offsets into .Lrvm_k: 32-byte entries, each one pattern of the text
# replicated over four lanes (the SSE2 code reads the first 16 bytes).
.equ K_ONE,             0*32        # 1.0
.equ K_ABS,             1*32        # #7FFFFFFFFFFFFFFF: andpd clears the sign
.equ K_SIGN,            2*32        # #8000000000000000: the sign bit
.equ K_INF,             3*32        # +Inf
.equ K_512,             4*32        # 512.0: exp_core's top >= #408
.equ K_TWOM54,          5*32        # 2^-54: exp_core's top < #3C9
.equ K_DMIN,            6*32        # 2^-1022: the least normal value
.equ K_LOG_OFF,         7*32        # LOG_OFF #3FE5F00000000000
.equ K_EXPMASK,         8*32        # #FFF0000000000000
.equ K_ZHI,             9*32        # #FFFFFFFFFC000000: log_core's zhi
.equ K_HI27,            10*32       # #FFFFFFFFF8000000: pow's yhi, lhi
.equ K_I127,            11*32       # integer 127
.equ K_I255,            12*32       # integer #FF
.equ K_I3,              13*32       # integer 3
.equ K_I1,              14*32       # integer 1
.equ K_MHALF,           15*32       # -0.5
.equ K_SIXTYFOUR,       16*32       # 64.0
.equ K_ONE64TH,         17*32       # 0.015625
.equ K_TWO23,           18*32       # 2^23: the R1/R2 bound
.equ K_TWOM27,          19*32       # 2^-27: sin/cos's tiny bound
.equ K_TWO500,          20*32       # 2^500
.equ K_TWOM500,         21*32       # 2^-500
.equ K_TWO600,          22*32       # 2^600
.equ K_TWOM600,         23*32       # 2^-600
.equ K_TWOM422,         24*32       # 2^-422

# The frame of every entry (VFRAME bytes; %rsp = 0 (mod 16) inside it):
# the operands, four scratch slots of 32 bytes (one vector each), the
# rare-lane mask and the lane index of the fallback loop. The result is
# assembled in VRES (= VS0) by the fallback loop.
.equ VX,                0           # x, all lanes
.equ VY,                32          # y, all lanes (pow, hypot)
.equ VS0,               64
.equ VS1,               96
.equ VS2,               128
.equ VS3,               160
.equ VM,                192         # the rare lanes, bit i = lane i
.equ VL,                200         # the lane being done by the scalar entry
.equ VFRAME,            216
.equ VRES,              VS0

# ---------------------------------------------------------------------
# Width-generic operations. VW (2 or 4, set before each entry) selects
# legacy SSE2 code on %xmm or VEX AVX/AVX2 code on %ymm. Arguments are
# registers unless noted; "m" marks an operand that may be a memory
# operand (the 32-byte aligned .Lrvm_k entries, or a frame slot, 16-byte
# aligned). The SSE2 forms are two-operand: a destination equal to the
# second source of a non-commutative operation is rejected at assembly
# time, so every use below keeps the operation of the text exactly.
# ---------------------------------------------------------------------
# FOP2C op, a, b(m), d: d = a op b, op commutative (SSE2 may compute b op
# a, which is the same bits).
.macro FOP2C op, a, b, d
.if VW == 2
  .ifc \a,\d
    \op\()pd \b, \d
  .else
    .ifc \b,\d
      \op\()pd \a, \d
    .else
      movapd \a, \d
      \op\()pd \b, \d
    .endif
  .endif
.else
    v\op\()pd \b, \a, \d
.endif
.endm
# FOP2N op, a, b(m), d: d = a op b, op not commutative (d must not be b).
.macro FOP2N op, a, b, d
.if VW == 2
  .ifc \a,\d
    \op\()pd \b, \d
  .else
    .ifc \b,\d
      .error "FOP2N: the destination is the second source"
    .endif
    movapd \a, \d
    \op\()pd \b, \d
  .endif
.else
    v\op\()pd \b, \a, \d
.endif
.endm
.macro FADD a, b, d
    FOP2C add, \a, \b, \d
.endm
.macro FMUL a, b, d
    FOP2C mul, \a, \b, \d
.endm
.macro FSUB a, b, d
    FOP2N sub, \a, \b, \d
.endm
.macro FDIV a, b, d
    FOP2N div, \a, \b, \d
.endm
# Bit operations (exact; on f64 or integer lanes alike).
.macro FAND a, b, d
    FOP2C and, \a, \b, \d
.endm
.macro FOR a, b, d
    FOP2C or, \a, \b, \d
.endm
.macro FXOR a, b, d
    FOP2C xor, \a, \b, \d
.endm
# FANDN a, b(m), d: d = ~a & b.
.macro FANDN a, b, d
    FOP2N andn, \a, \b, \d
.endm
# FMAX/FMIN a, b, d: d = max/min(a, b) (inputs never NaN; equal inputs
# have equal bits, so the operand returned on equality does not matter).
.macro FMAX a, b, d
    FOP2N max, \a, \b, \d
.endm
.macro FMIN a, b, d
    FOP2N min, \a, \b, \d
.endm
# FSQRT a, d: d = sqrt(a), correctly rounded.
.macro FSQRT a, d
.if VW == 2
    sqrtpd \a, \d
.else
    vsqrtpd \a, \d
.endif
.endm
# FMOV a(m), d: copy a register, or load a .Lrvm_k entry or a frame slot.
.macro FMOV a, d
.if VW == 2
    movapd \a, \d
.else
    vmovupd \a, \d
.endif
.endm
# VST a, off: store all lanes of a at off(%rsp).
.macro VST a, off
.if VW == 2
    movapd \a, \off(%rsp)
.else
    vmovupd \a, \off(%rsp)
.endif
.endm
# VLD off, d: load all lanes from off(%rsp).
.macro VLD off, d
.if VW == 2
    movapd \off(%rsp), \d
.else
    vmovupd \off(%rsp), \d
.endif
.endm
# CMP pred, a, b(m), d: d = all ones where (a pred b), else zero; pred as
# cmppd: 0 eq, 1 lt, 2 le, 5 nlt (true for NaN), 6 nle (true for NaN).
.macro CMP pred, a, b, d
.if VW == 2
  .ifnc \a,\d
    .ifc \b,\d
      .error "CMP: the destination is the second source"
    .endif
    movapd \a, \d
  .endif
    cmppd $\pred, \b, \d
.else
    vcmppd $\pred, \b, \a, \d
.endif
.endm
# SEL m, a(m), b, d, t: d = a where m is all ones, b where m is zero
# (m a compare result). d may be b or m, not a; t is a distinct temp.
.macro SEL m, a, b, d, t
.if VW == 2
  .ifc \a,\d
    .error "SEL: the destination is the first source"
  .endif
    movapd \m, \t
    andnpd \b, \t                   # t = b & ~m
    movapd \m, \d
    andpd \a, \d                    # d = a & m
    orpd \t, \d
.else
    vblendvpd \m, \a, \b, \d
.endif
.endm
# Integer lanes (64-bit): IADD/ISUB a, b(m), d (mod 2^64); ISHL/ISHR n,
# a, d: d = a << n, d = a >> n (logical).
.macro IADD a, b, d
.if VW == 2
  .ifc \a,\d
    paddq \b, \d
  .else
    .ifc \b,\d
      paddq \a, \d
    .else
      movdqa \a, \d
      paddq \b, \d
    .endif
  .endif
.else
    vpaddq \b, \a, \d
.endif
.endm
.macro ISUB a, b, d
.if VW == 2
  .ifnc \a,\d
    .ifc \b,\d
      .error "ISUB: the destination is the second source"
    .endif
    movdqa \a, \d
  .endif
    psubq \b, \d
.else
    vpsubq \b, \a, \d
.endif
.endm
.macro ISHL n, a, d
.if VW == 2
  .ifnc \a,\d
    movdqa \a, \d
  .endif
    psllq $\n, \d
.else
    vpsllq $\n, \a, \d
.endif
.endm
.macro ISHR n, a, d
.if VW == 2
  .ifnc \a,\d
    movdqa \a, \d
  .endif
    psrlq $\n, \d
.else
    vpsrlq $\n, \a, \d
.endif
.endm
# KD_FROM_T t, d, dx: d = itof(t >>a 52) for every lane, where t >>a 52 fits
# 32 bits: the upper 32-bit half of each lane shifted right arithmetically
# by 20, converted exactly by cvtdq2pd (SSE2 has no 64-bit shift right
# arithmetic and no 64-bit packed conversion). d must differ from t; dx
# is d's 128-bit name (%xmmN for d = %ymmN), used by the AVX2 form.
.macro KD_FROM_T t, d, dx
.if VW == 2
    pshufd $0xDD, \t, \d            # the upper halves of both lanes, low
    psrad $20, \d                   # t >>a 52 (32 bits each)
    cvtdq2pd \d, \d                 # exact
.else
    vpshufd $0xDD, \t, \d           # per 128 bits: the two upper halves
    vpsrad $20, \d, \d
    vpermq $0x08, \d, \d            # the four results in the low 128 bits
    vcvtdq2pd \dx, \d
.endif
.endm
# KB off, d: broadcast word off of sea_mt_const to every lane of d.
.macro KB off, d
.if VW == 2
    movsd sea_mt_const+\off(%rip), \d
    unpcklpd \d, \d
.else
    vbroadcastsd sea_mt_const+\off(%rip), \d
.endif
.endm
# MOVMSK a, r32: the sign bits of a's lanes (bit i = lane i) into r32.
.macro MOVMSK a, r
.if VW == 2
    movmskpd \a, \r
.else
    vmovmskpd \a, \r
.endif
.endm
# INVMASK r32: flip the VW lane bits.
.macro INVMASK r
.if VW == 2
    xorl $3, \r
.else
    xorl $15, \r
.endif
.endm
# Per-lane table loads. TBL_SETUP base, idx, t: idx holds per lane a word
# index (in 8-byte words) into the table at label base; SSE2 moves the two
# indices to %rax and %rcx (t a temp), both set %rdx = base. TBL_LOAD
# off, idx, d, m: d = per lane the word at base + off + 8 * index (m a
# temp mask for vgatherqpd, distinct from idx and d). Clobbers %rax %rcx
# %rdx.
.macro TBL_SETUP base, idx, t
    leaq \base(%rip), %rdx
.if VW == 2
    movq \idx, %rax                 # lane 0's index
    pshufd $0xEE, \idx, \t
    movq \t, %rcx                   # lane 1's index
.endif
.endm
.macro TBL_LOAD off, idx, d, m
.if VW == 2
    movsd \off(%rdx,%rax,8), \d
    movhpd \off(%rdx,%rcx,8), \d
.else
    vpcmpeqd \m, \m, \m             # gather every lane
    vgatherqpd \m, \off(%rdx,\idx,8), \d
.endif
.endm

# The shared primitives of DESIGN.md 4.10.2 on vectors (as rt_math.s's
# TWO_SUM ...: outputs and temporaries distinct from the inputs and from
# each other; the inputs are left unchanged).
# VTWO_SUM a, b -> s, e (temps t, u)
.macro VTWO_SUM a, b, s, e, t, u
    FADD \a, \b, \s                 # s = a + b
    FSUB \s, \a, \t                 # bb = s - a
    FSUB \s, \t, \u                 # s - bb
    FSUB \a, \u, \e                 # e = a - (s - bb)
    FSUB \b, \t, \u                 # b - bb
    FADD \e, \u, \e                 # e = (a - (s - bb)) + (b - bb)
.endm
# VFAST_TWO_SUM a, b -> s, e (temp t)
.macro VFAST_TWO_SUM a, b, s, e, t
    FADD \a, \b, \s                 # s = a + b
    FSUB \s, \a, \t                 # s - a
    FSUB \b, \t, \e                 # e = b - (s - a)
.endm
# VSPLIT a -> h, l (temp t)
.macro VSPLIT a, h, l, t
    KB MC_SPLIT, \t
    FMUL \t, \a, \t                 # g = SPLIT * a
    FSUB \t, \a, \h                 # g - a
    FSUB \t, \h, \t                 # g - (g - a)
    FMOV \t, \h                     # h
    FSUB \a, \h, \l                 # l = a - h
.endm
# VTWO_PROD a, b -> p, e (temps ah, al, bh, bl, t)
.macro VTWO_PROD a, b, p, e, ah, al, bh, bl, t
    FMUL \a, \b, \p                 # p = a * b
    VSPLIT \a, \ah, \al, \t
    VSPLIT \b, \bh, \bl, \t
    FMUL \ah, \bh, \e
    FSUB \e, \p, \e                 # ah * bh - p
    FMUL \ah, \bl, \t
    FADD \e, \t, \e                 # + ah * bl
    FMUL \al, \bh, \t
    FADD \e, \t, \e                 # + al * bh
    FMUL \al, \bl, \t
    FADD \e, \t, \e                 # + al * bl
.endm

# ---------------------------------------------------------------------
# VENTRY P, n: the prologue of every entry: the frame, the n operands
# (R0, R1) stored at VX, VY.
# VFINISH P, scalar, n: the epilogue. R0 holds the common result in every
# lane and VM(%rsp) the rare lanes. No rare lane: return R0. Otherwise
# store R0 at VRES (for _y: vzeroupper, after which only legacy SSE code
# runs until the reload), call the scalar entry with lane i's n operands
# for every rare lane i, store its result in lane i of VRES, and return
# VRES reloaded into R0 (the _y entries with the upper halves live).
# ---------------------------------------------------------------------
.macro VENTRY P, n
    subq $VFRAME, %rsp
    VST %\P\()0, VX
.if \n == 2
    VST %\P\()1, VY
.endif
.endm
.macro VFINISH P, scalar, n
    cmpq $0, VM(%rsp)
    jne .Lrvm_rare\@
    addq $VFRAME, %rsp              # the common case: no call
    ret
.Lrvm_rare\@:
    VST %\P\()0, VRES
.if VW == 4
    vzeroupper                      # the live ymm values are in the frame
.endif
.Lrvm_lane\@:
    movq VM(%rsp), %rax
    bsfq %rax, %rcx                 # the lowest rare lane
    btrq %rcx, %rax
    movq %rax, VM(%rsp)
    movq %rcx, VL(%rsp)
    movsd VX(%rsp,%rcx,8), %xmm0    # its x
.if \n == 2
    movsd VY(%rsp,%rcx,8), %xmm1    # its y
.endif
    call \scalar
    movq VL(%rsp), %rcx
    movsd %xmm0, VRES(%rsp,%rcx,8)  # lane i of the result
    cmpq $0, VM(%rsp)
    jne .Lrvm_lane\@
    VLD VRES, %\P\()0
    addq $VFRAME, %rsp
    ret
.endm

# ---------------------------------------------------------------------
# VEXP_CORE P -- exp_core steps 3-6 in every lane (DESIGN.md 4.10.4),
# for |x| < 512 (other lanes give garbage, never a fault).
#   Inputs : R0 = x, R1 = xt     Output: R0 = scale + scale * tmp
#   Clobbers: R0-R10, %rax %rcx %rdx
# ---------------------------------------------------------------------
.macro VEXP_CORE P
    # 3. Reduction.
    KB MC_EXP_INVLN2N, %\P\()2
    FMUL %\P\()2, %\P\()0, %\P\()2          # z = EXP_INVLN2N * x
    KB MC_EXP_SHIFT, %\P\()3
    FADD %\P\()2, %\P\()3, %\P\()2          # kd = z + EXP_SHIFT
    FMOV %\P\()2, %\P\()4                   # ki = bits(kd)
    FSUB %\P\()2, %\P\()3, %\P\()2          # kd = kd - EXP_SHIFT
    KB MC_EXP_NLN2HI_N, %\P\()5
    FMUL %\P\()5, %\P\()2, %\P\()5          # kd * EXP_NLN2HI_N
    FADD %\P\()0, %\P\()5, %\P\()5          # x + kd * EXP_NLN2HI_N
    KB MC_EXP_NLN2LO_N, %\P\()6
    FMUL %\P\()6, %\P\()2, %\P\()6          # kd * EXP_NLN2LO_N
    FADD %\P\()5, %\P\()6, %\P\()5          # r
    FADD %\P\()5, %\P\()1, %\P\()5          # r = r + xt
    # 4. Table: i = ki & 127 (word index 2i); tail; sbits.
    FAND %\P\()4, .Lrvm_k+K_I127(%rip), %\P\()6
    ISHL 1, %\P\()6, %\P\()6                # 2i
    ISHL 45, %\P\()4, %\P\()4               # ki << 45
    TBL_SETUP sea_mt_exp, %\P\()6, %\P\()7
    TBL_LOAD 0, %\P\()6, %\P\()7, %\P\()9   # tail
    TBL_LOAD 8, %\P\()6, %\P\()8, %\P\()9   # EXP_SBITS[i]
    IADD %\P\()8, %\P\()4, %\P\()8          # sbits = EXP_SBITS[i] + (ki << 45)
    # 5. Polynomial.
    FMUL %\P\()5, %\P\()5, %\P\()6          # r2 = r * r
    FADD %\P\()7, %\P\()5, %\P\()7          # tail + r
    KB MC_EXP_C3, %\P\()9
    FMUL %\P\()9, %\P\()5, %\P\()9          # r * EXP_C3
    KB MC_EXP_C2, %\P\()10
    FADD %\P\()9, %\P\()10, %\P\()9         # EXP_C2 + r * EXP_C3
    FMUL %\P\()9, %\P\()6, %\P\()9          # r2 * (...)
    FADD %\P\()7, %\P\()9, %\P\()7          # (tail + r) + r2 * (...)
    KB MC_EXP_C5, %\P\()9
    FMUL %\P\()9, %\P\()5, %\P\()9          # r * EXP_C5
    KB MC_EXP_C4, %\P\()10
    FADD %\P\()9, %\P\()10, %\P\()9         # EXP_C4 + r * EXP_C5
    FMUL %\P\()6, %\P\()6, %\P\()10         # r2 * r2
    FMUL %\P\()9, %\P\()10, %\P\()9         # (r2 * r2) * (...)
    FADD %\P\()7, %\P\()9, %\P\()7          # tmp
    # 6. scale + scale * tmp.
    FMUL %\P\()8, %\P\()7, %\P\()7          # scale * tmp
    FADD %\P\()8, %\P\()7, %\P\()0          # scale + scale * tmp
.endm

# ---------------------------------------------------------------------
# VLOG_CORE P, shi, slo -- log_core in every lane (DESIGN.md 4.10.4).
#   Inputs : R0 = ix, the pattern of a positive normal value per lane
#            shi, slo: two frame slots (LOG_LOGC_HI[i], LOG_LOGC_LO[i])
#   Outputs: R0 = h, R1 = l
#   Clobbers: R0-R15, %rax %rcx %rdx
# ---------------------------------------------------------------------
.macro VLOG_CORE P, shi, slo
    # 1. t, i (word index 3i), k (kd = itof(k)), iz, z.
    ISUB %\P\()0, .Lrvm_k+K_LOG_OFF(%rip), %\P\()2   # t = ix - LOG_OFF
    ISHR 45, %\P\()2, %\P\()3
    FAND %\P\()3, .Lrvm_k+K_I127(%rip), %\P\()3      # i = (t >> 45) & 127
    ISHL 1, %\P\()3, %\P\()4
    IADD %\P\()4, %\P\()3, %\P\()3          # 3i
    FAND %\P\()2, .Lrvm_k+K_EXPMASK(%rip), %\P\()4   # t & #FFF0000000000000
    ISUB %\P\()0, %\P\()4, %\P\()5          # iz = ix - (...); z = f64(iz)
    KD_FROM_T %\P\()2, %\P\()6, %xmm6            # kd = itof(t >>a 52)
    TBL_SETUP sea_mt_log, %\P\()3, %\P\()7
    TBL_LOAD 0, %\P\()3, %\P\()7, %\P\()9   # invc
    TBL_LOAD 8, %\P\()3, %\P\()8, %\P\()9   # LOG_LOGC_HI[i]
    VST %\P\()8, \shi
    TBL_LOAD 16, %\P\()3, %\P\()8, %\P\()9  # LOG_LOGC_LO[i]
    VST %\P\()8, \slo
    # 2. zhi, zlo, rhi, rlo; (rh, rl) = two_sum(rhi, rlo).
    FAND %\P\()5, .Lrvm_k+K_ZHI(%rip), %\P\()8       # zhi
    FSUB %\P\()5, %\P\()8, %\P\()9          # zlo = z - zhi
    FMUL %\P\()8, %\P\()7, %\P\()8          # zhi * invc
    FSUB %\P\()8, .Lrvm_k+K_ONE(%rip), %\P\()8       # rhi = zhi * invc - 1.0
    FMUL %\P\()9, %\P\()7, %\P\()9          # rlo = zlo * invc
    VTWO_SUM %\P\()8, %\P\()9, %\P\()10, %\P\()11, %\P\()2, %\P\()3   # rh = R10, rl = R11
    # 3. t1 = kd * LOG_LN2HI + LOG_LOGC_HI[i]; (t2, e1) = two_sum(t1, rh).
    KB MC_LOG_LN2HI, %\P\()2
    FMUL %\P\()2, %\P\()6, %\P\()2          # kd * LOG_LN2HI
    FADD %\P\()2, \shi(%rsp), %\P\()2       # t1
    VTWO_SUM %\P\()2, %\P\()10, %\P\()3, %\P\()4, %\P\()5, %\P\()7    # t2 = R3, e1 = R4
    # 4. (s, se) = two_prod(rh, rh); hs = -0.5 * s; (t3, e2) = two_sum(t2, hs).
    VTWO_PROD %\P\()10, %\P\()10, %\P\()5, %\P\()7, %\P\()8, %\P\()9, %\P\()12, %\P\()13, %\P\()14 # s = R5, se = R7
    FMUL %\P\()5, .Lrvm_k+K_MHALF(%rip), %\P\()8     # hs = -0.5 * s
    VTWO_SUM %\P\()3, %\P\()8, %\P\()9, %\P\()12, %\P\()13, %\P\()14  # t3 = R9, e2 = R12
    # 5. r2 = rh * rh; p = (rh * r2) * (A3 + rh * (A4 + ... (A8 + rh * A9))).
    FMUL %\P\()10, %\P\()10, %\P\()0        # r2
    KB MC_LOG_A9, %\P\()1
    FMUL %\P\()1, %\P\()10, %\P\()1         # rh * A9
    KB MC_LOG_A8, %\P\()2
    FADD %\P\()1, %\P\()2, %\P\()1          # A8 + rh * A9
    FMUL %\P\()1, %\P\()10, %\P\()1
    KB MC_LOG_A7, %\P\()2
    FADD %\P\()1, %\P\()2, %\P\()1          # A7 + rh * (...)
    FMUL %\P\()1, %\P\()10, %\P\()1
    KB MC_LOG_A6, %\P\()2
    FADD %\P\()1, %\P\()2, %\P\()1          # A6 + rh * (...)
    FMUL %\P\()1, %\P\()10, %\P\()1
    KB MC_LOG_A5, %\P\()2
    FADD %\P\()1, %\P\()2, %\P\()1          # A5 + rh * (...)
    FMUL %\P\()1, %\P\()10, %\P\()1
    KB MC_LOG_A4, %\P\()2
    FADD %\P\()1, %\P\()2, %\P\()1          # A4 + rh * (...)
    FMUL %\P\()1, %\P\()10, %\P\()1
    KB MC_LOG_A3, %\P\()2
    FADD %\P\()1, %\P\()2, %\P\()1          # A3 + rh * (...)
    FMUL %\P\()10, %\P\()0, %\P\()3         # rh * r2
    FMUL %\P\()3, %\P\()1, %\P\()3          # p
    # 6. lo.
    KB MC_LOG_LN2LO, %\P\()2
    FMUL %\P\()2, %\P\()6, %\P\()2          # kd * LOG_LN2LO
    FADD %\P\()2, \slo(%rsp), %\P\()2       # + LOG_LOGC_LO[i]
    FADD %\P\()2, %\P\()11, %\P\()2         # lo = (...) + rl
    FADD %\P\()4, %\P\()12, %\P\()5         # e1 + e2
    FADD %\P\()2, %\P\()5, %\P\()2          # lo = lo + (e1 + e2)
    FMUL %\P\()7, .Lrvm_k+K_MHALF(%rip), %\P\()5     # -0.5 * se
    FMUL %\P\()10, %\P\()11, %\P\()8        # rh * rl
    FSUB %\P\()5, %\P\()8, %\P\()5          # (-0.5 * se) - rh * rl
    FADD %\P\()2, %\P\()5, %\P\()2          # lo = lo + (...)
    FADD %\P\()2, %\P\()3, %\P\()2          # lo = lo + p
    # 7. (h, l) = fast_two_sum(t3, lo).
    VFAST_TWO_SUM %\P\()9, %\P\()2, %\P\()0, %\P\()1, %\P\()5
.endm

# ---------------------------------------------------------------------
# VEXP P -- exp in every lane. Rare lanes: NaN, |x| >= 512.
# ---------------------------------------------------------------------
.macro VEXP P
    VENTRY \P, 1
    FAND %\P\()0, .Lrvm_k+K_ABS(%rip), %\P\()2       # |x|
    CMP 5, %\P\()2, .Lrvm_k+K_512(%rip), %\P\()3     # rare: |x| >= 512 or NaN
    MOVMSK %\P\()3, %eax
    movq %rax, VM(%rsp)
    FANDN %\P\()3, %\P\()0, %\P\()3         # x, 0.0 in the rare lanes
    FMOV %\P\()3, %\P\()0
    FXOR %\P\()1, %\P\()1, %\P\()1          # xt = 0.0
    VEXP_CORE \P
    # exp_core step 1: |x| < 2^-54 gives 1.0 + x.
    VLD VX, %\P\()1
    FAND %\P\()1, .Lrvm_k+K_ABS(%rip), %\P\()2
    CMP 1, %\P\()2, .Lrvm_k+K_TWOM54(%rip), %\P\()2  # |x| < 2^-54
    FMOV .Lrvm_k+K_ONE(%rip), %\P\()3
    FADD %\P\()3, %\P\()1, %\P\()3          # 1.0 + x
    SEL %\P\()2, %\P\()3, %\P\()0, %\P\()0, %\P\()4
    VFINISH \P, sea_exp, 1
.endm

# ---------------------------------------------------------------------
# VLOG P -- log in every lane. Common lanes: 2^-1022 <= x < +Inf (step 3
# directly); rare: NaN, x <= 0 (-0 and -Inf included), +Inf, subnormal.
# ---------------------------------------------------------------------
.macro VLOG P
    VENTRY \P, 1
    CMP 5, %\P\()0, .Lrvm_k+K_DMIN(%rip), %\P\()1    # x >= 2^-1022 or NaN
    CMP 1, %\P\()0, .Lrvm_k+K_INF(%rip), %\P\()2     # x < +Inf (not NaN)
    FAND %\P\()1, %\P\()2, %\P\()1          # common
    MOVMSK %\P\()1, %eax
    INVMASK %eax
    movq %rax, VM(%rsp)                     # rare = not common
    FMOV .Lrvm_k+K_ONE(%rip), %\P\()2
    SEL %\P\()1, %\P\()0, %\P\()2, %\P\()2, %\P\()3  # x, 1.0 in the rare lanes
    FMOV %\P\()2, %\P\()0                   # ix
    VLOG_CORE \P, VS1, VS2                  # h of log_core(ix)
    VFINISH \P, sea_log, 1
.endm

# ---------------------------------------------------------------------
# VPOW P -- pow in every lane (DESIGN.md 4.10.4, steps 10-12). Common
# lanes: 2^-1022 <= x < +Inf and 0 < |y| < +Inf (steps 1-9 then do
# nothing: y is not +-0 or +-Inf, nothing is NaN, x is not +-0, +-Inf,
# negative or subnormal; x = +1.0 needs no step 2 here, as log_core(1)
# = (+0, +0) gives ehi = +-0, elo = +-0 and exp_core's 1.0 + ehi = 1.0).
# Every other lane is rare, x < 0 included (implementer reading of
# 2.12.8's "special inputs": step 8's integer classification of y needs
# per-lane variable shifts, which SSE2 lacks), as are the lanes with
# |ehi| >= 512, where exp_core takes its steps 2 or 7.
# ---------------------------------------------------------------------
.macro VPOW P
    VENTRY \P, 2
    CMP 5, %\P\()0, .Lrvm_k+K_DMIN(%rip), %\P\()2    # x >= 2^-1022 or NaN
    CMP 1, %\P\()0, .Lrvm_k+K_INF(%rip), %\P\()3     # x < +Inf
    FAND %\P\()2, %\P\()3, %\P\()2
    FAND %\P\()1, .Lrvm_k+K_ABS(%rip), %\P\()3       # |y|
    CMP 1, %\P\()3, .Lrvm_k+K_INF(%rip), %\P\()4     # |y| < +Inf
    FAND %\P\()2, %\P\()4, %\P\()2
    FXOR %\P\()4, %\P\()4, %\P\()4
    CMP 1, %\P\()4, %\P\()3, %\P\()4        # 0 < |y|
    FAND %\P\()2, %\P\()4, %\P\()2          # common
    MOVMSK %\P\()2, %eax
    INVMASK %eax
    movq %rax, VM(%rsp)
    FMOV .Lrvm_k+K_ONE(%rip), %\P\()3
    SEL %\P\()2, %\P\()0, %\P\()3, %\P\()3, %\P\()4  # x, 1.0 in the rare lanes
    FMOV .Lrvm_k+K_ONE(%rip), %\P\()5
    SEL %\P\()2, %\P\()1, %\P\()5, %\P\()5, %\P\()4  # y, 1.0 in the rare lanes
    VST %\P\()5, VS3
    FMOV %\P\()3, %\P\()0                   # ix
    # 10. (lh, lt) = log_core(ix); the products with y.
    VLOG_CORE \P, VS1, VS2                  # R0 = lh, R1 = lt
    VLD VS3, %\P\()2                        # y
    FAND %\P\()2, .Lrvm_k+K_HI27(%rip), %\P\()3      # yhi
    FSUB %\P\()2, %\P\()3, %\P\()4          # ylo = y - yhi
    FAND %\P\()0, .Lrvm_k+K_HI27(%rip), %\P\()5      # lhi
    FSUB %\P\()0, %\P\()5, %\P\()6          # lh - lhi
    FADD %\P\()6, %\P\()1, %\P\()6          # llo = (lh - lhi) + lt
    FMUL %\P\()3, %\P\()5, %\P\()0          # ehi = yhi * lhi
    FMUL %\P\()4, %\P\()5, %\P\()1          # ylo * lhi
    FMUL %\P\()2, %\P\()6, %\P\()2          # y * llo
    FADD %\P\()1, %\P\()2, %\P\()1          # elo = (ylo * lhi) + (y * llo)
    # 11. v = exp_core(ehi, elo): |ehi| >= 512 is rare, |ehi| < 2^-54 a select.
    VST %\P\()0, VS1
    FAND %\P\()0, .Lrvm_k+K_ABS(%rip), %\P\()7       # |ehi|
    CMP 5, %\P\()7, .Lrvm_k+K_512(%rip), %\P\()8     # |ehi| >= 512
    MOVMSK %\P\()8, %ecx
    orq %rcx, VM(%rsp)
    CMP 1, %\P\()7, .Lrvm_k+K_TWOM54(%rip), %\P\()7  # |ehi| < 2^-54
    VST %\P\()7, VS2
    VEXP_CORE \P
    VLD VS1, %\P\()1                        # ehi
    FMOV .Lrvm_k+K_ONE(%rip), %\P\()2
    FADD %\P\()2, %\P\()1, %\P\()2          # 1.0 + ehi
    VLD VS2, %\P\()3
    SEL %\P\()3, %\P\()2, %\P\()0, %\P\()0, %\P\()4
    # 12. x > 0 in the common lanes: no negation.
    VFINISH \P, sea_pow, 2
.endm

# ---------------------------------------------------------------------
# VTRIG P, cos -- sin (cos = 0) or cos (cos = 1) in every lane: step 2
# as a select, R1 (Cody-Waite) and trig_core with the use_cos choice and
# the sign per lane. Rare lanes: NaN, +-Inf, |x| >= 2^23 (R2).
# Frame slots: VS1 = q, VS2 = sr (the sign bit of rh), VS3 = use_cos mask.
# ---------------------------------------------------------------------
.macro VTRIG P, cos
    VENTRY \P, 1
    FAND %\P\()0, .Lrvm_k+K_ABS(%rip), %\P\()1       # ax
    CMP 5, %\P\()1, .Lrvm_k+K_TWO23(%rip), %\P\()2   # rare: ax >= 2^23 or NaN
    MOVMSK %\P\()2, %eax
    movq %rax, VM(%rsp)
    FANDN %\P\()2, %\P\()1, %\P\()2         # ax, 0.0 in the rare lanes
    # 3. R1: (q, rh, rl) = reduce(ax).
    KB MC_TRIG_INVPIO2, %\P\()3
    FMUL %\P\()3, %\P\()2, %\P\()3          # z = ax * TRIG_INVPIO2
    KB MC_EXP_SHIFT, %\P\()4
    FADD %\P\()3, %\P\()4, %\P\()3          # kd = z + EXP_SHIFT
    FAND %\P\()3, .Lrvm_k+K_I3(%rip), %\P\()5        # q = bits(kd) & 3
    VST %\P\()5, VS1
    FSUB %\P\()3, %\P\()4, %\P\()3          # kd = kd - EXP_SHIFT
    KB MC_TRIG_P1, %\P\()6
    FMUL %\P\()6, %\P\()3, %\P\()6          # kd * TRIG_P1
    FSUB %\P\()2, %\P\()6, %\P\()7          # t1 = ax - kd * TRIG_P1
    KB MC_TRIG_P2, %\P\()6
    FMUL %\P\()6, %\P\()3, %\P\()6
    FXOR %\P\()6, .Lrvm_k+K_SIGN(%rip), %\P\()6      # neg(kd * TRIG_P2)
    VTWO_SUM %\P\()7, %\P\()6, %\P\()8, %\P\()9, %\P\()10, %\P\()11   # (s, e)
    KB MC_TRIG_P3, %\P\()6
    FMUL %\P\()6, %\P\()3, %\P\()6
    FXOR %\P\()6, .Lrvm_k+K_SIGN(%rip), %\P\()6      # neg(kd * TRIG_P3)
    VTWO_SUM %\P\()8, %\P\()6, %\P\()10, %\P\()11, %\P\()12, %\P\()13 # (h, l1)
    KB MC_TRIG_P4, %\P\()6
    FMUL %\P\()6, %\P\()3, %\P\()6          # kd * TRIG_P4
    FSUB %\P\()9, %\P\()6, %\P\()9          # e - kd * TRIG_P4
    FADD %\P\()11, %\P\()9, %\P\()11        # l = l1 + (...)
    VTWO_SUM %\P\()10, %\P\()11, %\P\()0, %\P\()1, %\P\()12, %\P\()13 # (rh, rl)
    # trig_core 1. sr, ar, al = neg(rl) if sr, else rl.
    FAND %\P\()0, .Lrvm_k+K_SIGN(%rip), %\P\()2      # sr (as the sign bit)
    VST %\P\()2, VS2
    FAND %\P\()0, .Lrvm_k+K_ABS(%rip), %\P\()3       # ar = abs(rh)
    FXOR %\P\()1, %\P\()2, %\P\()4          # al
    # 2. jd, j, th.
    FMUL %\P\()3, .Lrvm_k+K_SIXTYFOUR(%rip), %\P\()5 # ar * 64.0
    KB MC_EXP_SHIFT, %\P\()6
    FADD %\P\()5, %\P\()6, %\P\()5          # jd = ... + EXP_SHIFT
    FAND %\P\()5, .Lrvm_k+K_I255(%rip), %\P\()7      # j = bits(jd) & #FF
    FSUB %\P\()5, %\P\()6, %\P\()5          # jd = jd - EXP_SHIFT
    FMUL %\P\()5, .Lrvm_k+K_ONE64TH(%rip), %\P\()5   # jd * 0.015625
    FSUB %\P\()3, %\P\()5, %\P\()8          # th = ar - jd * 0.015625
    # 3. t2, sinp, cosp.
    FMUL %\P\()8, %\P\()8, %\P\()6          # t2 = th * th
    KB MC_TRIG_S7, %\P\()9
    FMUL %\P\()9, %\P\()6, %\P\()9          # t2 * TRIG_S7
    KB MC_TRIG_S5, %\P\()10
    FADD %\P\()9, %\P\()10, %\P\()9         # TRIG_S5 + ...
    FMUL %\P\()9, %\P\()6, %\P\()9          # t2 * (...)
    KB MC_TRIG_S3, %\P\()10
    FADD %\P\()9, %\P\()10, %\P\()9         # TRIG_S3 + ...
    FMUL %\P\()8, %\P\()6, %\P\()10         # th * t2
    FMUL %\P\()10, %\P\()9, %\P\()10        # sinp = R10
    KB MC_TRIG_C6, %\P\()9
    FMUL %\P\()9, %\P\()6, %\P\()9          # t2 * TRIG_C6
    KB MC_TRIG_C4, %\P\()11
    FADD %\P\()9, %\P\()11, %\P\()9         # TRIG_C4 + ...
    FMUL %\P\()9, %\P\()6, %\P\()9          # t2 * (...)
    KB MC_TRIG_C2, %\P\()11
    FADD %\P\()9, %\P\()11, %\P\()9         # TRIG_C2 + ...
    FMUL %\P\()9, %\P\()6, %\P\()9          # cosp = R9
    # 4. The table words of j (word index 4j) and the use_cos choice.
    ISHL 2, %\P\()7, %\P\()7
    TBL_SETUP sea_mt_trig, %\P\()7, %\P\()0
    TBL_LOAD 0, %\P\()7, %\P\()11, %\P\()0  # TRIG_SH
    TBL_LOAD 8, %\P\()7, %\P\()12, %\P\()0  # TRIG_SL
    TBL_LOAD 16, %\P\()7, %\P\()13, %\P\()0 # TRIG_CH
    TBL_LOAD 24, %\P\()7, %\P\()14, %\P\()0 # TRIG_CL
    VLD VS1, %\P\()0                        # q
    FAND %\P\()0, .Lrvm_k+K_I1(%rip), %\P\()1        # q & 1
.if \cos
    ISUB %\P\()1, .Lrvm_k+K_I1(%rip), %\P\()2        # use_cos = 1 - (q & 1): mask (q & 1) - 1
.else
    FXOR %\P\()2, %\P\()2, %\P\()2
    ISUB %\P\()2, %\P\()1, %\P\()2          # use_cos = q & 1: mask 0 - (q & 1)
.endif
    VST %\P\()2, VS3
    SEL %\P\()2, %\P\()13, %\P\()11, %\P\()3, %\P\()5   # A = CH or SH
    SEL %\P\()2, %\P\()14, %\P\()12, %\P\()6, %\P\()5   # AL = CL or SL
    FXOR %\P\()11, .Lrvm_k+K_SIGN(%rip), %\P\()11    # neg(TRIG_SH)
    FXOR %\P\()12, .Lrvm_k+K_SIGN(%rip), %\P\()12    # neg(TRIG_SL)
    SEL %\P\()2, %\P\()11, %\P\()13, %\P\()13, %\P\()5  # B = neg(SH) or CH
    SEL %\P\()2, %\P\()12, %\P\()14, %\P\()14, %\P\()5  # BL = neg(SL) or CL
    # 5. (p, pe) = two_prod(B, th); (h, e) = fast_two_sum(A, p); lo; v.
    VTWO_PROD %\P\()13, %\P\()8, %\P\()0, %\P\()1, %\P\()5, %\P\()7, %\P\()11, %\P\()12, %\P\()15 # p, pe
    VFAST_TWO_SUM %\P\()3, %\P\()0, %\P\()5, %\P\()7, %\P\()11   # h = R5, e = R7
    FADD %\P\()7, %\P\()1, %\P\()7          # e + pe
    FMUL %\P\()14, %\P\()8, %\P\()11        # BL * th
    FADD %\P\()11, %\P\()6, %\P\()11        # AL + BL * th
    FADD %\P\()7, %\P\()11, %\P\()7         # lo = (e + pe) + (AL + BL * th)
    FADD %\P\()10, %\P\()4, %\P\()11        # sinp + al
    FMUL %\P\()11, %\P\()13, %\P\()11       # B * (sinp + al)
    FADD %\P\()7, %\P\()11, %\P\()7         # lo = lo + ...
    FMUL %\P\()4, %\P\()8, %\P\()11         # al * th
    FSUB %\P\()9, %\P\()11, %\P\()12        # cosp - al * th
    FMUL %\P\()12, %\P\()3, %\P\()12        # A * (...)
    FADD %\P\()7, %\P\()12, %\P\()7         # lo = lo + ...
    FADD %\P\()5, %\P\()7, %\P\()5          # v = h + lo
    # sin/cos 5. The sign, as bit 63: odd = sr & !use_cos.
    VLD VS3, %\P\()0                        # use_cos mask
    VLD VS2, %\P\()1                        # sr
    FANDN %\P\()0, %\P\()1, %\P\()2         # odd
    VLD VS1, %\P\()3                        # q
.if \cos
    IADD %\P\()3, .Lrvm_k+K_I1(%rip), %\P\()3        # q + 1
    ISHL 62, %\P\()3, %\P\()3               # bit 1 of q + 1 at bit 63
    FAND %\P\()3, .Lrvm_k+K_SIGN(%rip), %\P\()3
    FXOR %\P\()3, %\P\()2, %\P\()3          # negate = ((q + 1) >> 1) & 1 ^ odd
.else
    ISHL 62, %\P\()3, %\P\()3               # bit 1 of q at bit 63
    FAND %\P\()3, .Lrvm_k+K_SIGN(%rip), %\P\()3
    FXOR %\P\()3, %\P\()2, %\P\()3          # (q >> 1) ^ odd
    VLD VX, %\P\()4
    FAND %\P\()4, .Lrvm_k+K_SIGN(%rip), %\P\()4      # bit 63 of ix
    FXOR %\P\()3, %\P\()4, %\P\()3          # negate
.endif
    FXOR %\P\()5, %\P\()3, %\P\()5          # neg(v) if negate
    # 2. |x| < 2^-27: sin gives x, cos 1.0.
    VLD VX, %\P\()1
    FAND %\P\()1, .Lrvm_k+K_ABS(%rip), %\P\()2
    CMP 1, %\P\()2, .Lrvm_k+K_TWOM27(%rip), %\P\()2  # |x| < 2^-27
.if \cos
    SEL %\P\()2, .Lrvm_k+K_ONE(%rip), %\P\()5, %\P\()0, %\P\()3
.else
    SEL %\P\()2, %\P\()1, %\P\()5, %\P\()0, %\P\()3
.endif
.if \cos
    VFINISH \P, sea_cos, 1
.else
    VFINISH \P, sea_sin, 1
.endif
.endm

# ---------------------------------------------------------------------
# VHYPOT P -- hypot in every lane. Rare lanes: an infinite or NaN
# operand (step 1), and the subnormal result of step 6.
# Frame slots: VS0 = the output scale, VS1 = the ay = 0 mask, VS2 = ax
# (after the swap), VS3 = the 2^-600 scale mask.
# ---------------------------------------------------------------------
.macro VHYPOT P
    VENTRY \P, 2
    FAND %\P\()0, .Lrvm_k+K_ABS(%rip), %\P\()2       # ax
    FAND %\P\()1, .Lrvm_k+K_ABS(%rip), %\P\()3       # ay
    CMP 5, %\P\()2, .Lrvm_k+K_INF(%rip), %\P\()4     # ax Inf or NaN
    CMP 5, %\P\()3, .Lrvm_k+K_INF(%rip), %\P\()5     # ay Inf or NaN
    FOR %\P\()4, %\P\()5, %\P\()4           # rare (step 1)
    MOVMSK %\P\()4, %eax
    movq %rax, VM(%rsp)
    FANDN %\P\()4, %\P\()2, %\P\()5         # ax, 0.0 in the rare lanes
    FANDN %\P\()4, %\P\()3, %\P\()4         # ay, 0.0 in the rare lanes
    # 2. ax >= ay (the swap); ay = 0 gives ax.
    FMAX %\P\()5, %\P\()4, %\P\()2          # ax
    FMIN %\P\()5, %\P\()4, %\P\()3          # ay
    VST %\P\()2, VS2
    FXOR %\P\()6, %\P\()6, %\P\()6
    CMP 0, %\P\()6, %\P\()3, %\P\()6        # ay = 0
    VST %\P\()6, VS1
    # 3. Scale: ax > 2^500: 2^-600 in, 2^600 out; ax < 2^-500: 2^600 in,
    #    2^-600 out; else 1.0 (a product with 1.0 is exact).
    CMP 6, %\P\()2, .Lrvm_k+K_TWO500(%rip), %\P\()7  # big
    CMP 1, %\P\()2, .Lrvm_k+K_TWOM500(%rip), %\P\()8 # small
    VST %\P\()8, VS3
    FMOV .Lrvm_k+K_ONE(%rip), %\P\()9
    SEL %\P\()8, .Lrvm_k+K_TWO600(%rip), %\P\()9, %\P\()9, %\P\()10
    SEL %\P\()7, .Lrvm_k+K_TWOM600(%rip), %\P\()9, %\P\()9, %\P\()10
    FMUL %\P\()2, %\P\()9, %\P\()2          # ax * factor
    FMUL %\P\()3, %\P\()9, %\P\()3          # ay * factor
    FMOV .Lrvm_k+K_ONE(%rip), %\P\()9
    SEL %\P\()8, .Lrvm_k+K_TWOM600(%rip), %\P\()9, %\P\()9, %\P\()10
    SEL %\P\()7, .Lrvm_k+K_TWO600(%rip), %\P\()9, %\P\()9, %\P\()10
    VST %\P\()9, VS0                        # scale
    # 4. (p, pe), (q, qe), (sh, sl).
    VTWO_PROD %\P\()2, %\P\()2, %\P\()4, %\P\()5, %\P\()6, %\P\()7, %\P\()8, %\P\()10, %\P\()11 # p, pe
    VTWO_PROD %\P\()3, %\P\()3, %\P\()6, %\P\()7, %\P\()8, %\P\()10, %\P\()11, %\P\()12, %\P\()13 # q, qe
    VTWO_SUM %\P\()4, %\P\()6, %\P\()8, %\P\()10, %\P\()11, %\P\()12  # (sh, sl)
    FADD %\P\()5, %\P\()7, %\P\()11         # pe + qe
    FADD %\P\()10, %\P\()11, %\P\()10       # sl = sl + (pe + qe)
    VFAST_TWO_SUM %\P\()8, %\P\()10, %\P\()0, %\P\()1, %\P\()11  # (sh, sl) = R0, R1
    # 5. h, (hh, he), d, corr.
    FSQRT %\P\()0, %\P\()2                  # h = sqrt(sh)
    VTWO_PROD %\P\()2, %\P\()2, %\P\()3, %\P\()4, %\P\()5, %\P\()6, %\P\()7, %\P\()8, %\P\()10 # hh, he
    FSUB %\P\()0, %\P\()3, %\P\()5          # sh - hh
    FSUB %\P\()5, %\P\()4, %\P\()5          # (sh - hh) - he
    FADD %\P\()5, %\P\()1, %\P\()5          # d = ... + sl
    FADD %\P\()2, %\P\()2, %\P\()6          # h + h
    FDIV %\P\()5, %\P\()6, %\P\()5          # corr = d / (h + h)
    # 6. Scale 2^-600 and h < 2^-422 (ay != 0): the subnormal result, rare.
    CMP 1, %\P\()2, .Lrvm_k+K_TWOM422(%rip), %\P\()6
    VLD VS3, %\P\()7
    FAND %\P\()6, %\P\()7, %\P\()6
    VLD VS1, %\P\()7
    FANDN %\P\()7, %\P\()6, %\P\()7
    MOVMSK %\P\()7, %ecx
    orq %rcx, VM(%rsp)
    FADD %\P\()2, %\P\()5, %\P\()2          # h + corr
    FMUL %\P\()2, VS0(%rsp), %\P\()2        # (h + corr) * scale
    VLD VS1, %\P\()3
    VLD VS2, %\P\()4
    SEL %\P\()3, %\P\()4, %\P\()2, %\P\()0, %\P\()5  # ay = 0: ax
    VFINISH \P, sea_hypot, 2
.endm

    .text

# ---------------------------------------------------------------------
# The 2-lane entries (SSE2). Each:
#   Inputs  : %xmm0 = x (and %xmm1 = y for pow, hypot), two lanes
#   Outputs : %xmm0 = the scalar entry's result in each lane
#   Clobbers: %rax %rcx %rdx %rsi %rdi %r8-%r11, %xmm0-%xmm15, flags
#             (a rare lane calls the scalar entry)
#   Callee-saved used: none
#   Frame   : VFRAME = 216 bytes (operands, scratch slots, the rare-lane
#             mask); at most 480 bytes below the return address
# ---------------------------------------------------------------------
    .set VW, 2

    .globl sea_exp_x
    .type sea_exp_x, @function
    .p2align 4
sea_exp_x:
    VEXP xmm
    .size sea_exp_x, . - sea_exp_x

    .globl sea_log_x
    .type sea_log_x, @function
    .p2align 4
sea_log_x:
    VLOG xmm
    .size sea_log_x, . - sea_log_x

    .globl sea_pow_x
    .type sea_pow_x, @function
    .p2align 4
sea_pow_x:
    VPOW xmm
    .size sea_pow_x, . - sea_pow_x

    .globl sea_sin_x
    .type sea_sin_x, @function
    .p2align 4
sea_sin_x:
    VTRIG xmm, 0
    .size sea_sin_x, . - sea_sin_x

    .globl sea_cos_x
    .type sea_cos_x, @function
    .p2align 4
sea_cos_x:
    VTRIG xmm, 1
    .size sea_cos_x, . - sea_cos_x

    .globl sea_hypot_x
    .type sea_hypot_x, @function
    .p2align 4
sea_hypot_x:
    VHYPOT xmm
    .size sea_hypot_x, . - sea_hypot_x

# ---------------------------------------------------------------------
# The 4-lane entries (AVX2; called only from 4-lane code). Each:
#   Inputs  : %ymm0 = x (and %ymm1 = y for pow, hypot), four lanes
#   Outputs : %ymm0 = the scalar entry's result in each lane, the upper
#             halves live (no vzeroupper before the return)
#   Clobbers: %rax %rcx %rdx %rsi %rdi %r8-%r11, %ymm0-%ymm15, flags
#             (a rare lane calls the scalar entry after storing the live
#             ymm values and vzeroupper)
#   Callee-saved used: none
#   Frame   : VFRAME = 216 bytes, as the 2-lane entries
# ---------------------------------------------------------------------
    .set VW, 4

    .globl sea_exp_y
    .type sea_exp_y, @function
    .p2align 4
sea_exp_y:
    VEXP ymm
    .size sea_exp_y, . - sea_exp_y

    .globl sea_log_y
    .type sea_log_y, @function
    .p2align 4
sea_log_y:
    VLOG ymm
    .size sea_log_y, . - sea_log_y

    .globl sea_pow_y
    .type sea_pow_y, @function
    .p2align 4
sea_pow_y:
    VPOW ymm
    .size sea_pow_y, . - sea_pow_y

    .globl sea_sin_y
    .type sea_sin_y, @function
    .p2align 4
sea_sin_y:
    VTRIG ymm, 0
    .size sea_sin_y, . - sea_sin_y

    .globl sea_cos_y
    .type sea_cos_y, @function
    .p2align 4
sea_cos_y:
    VTRIG ymm, 1
    .size sea_cos_y, . - sea_cos_y

    .globl sea_hypot_y
    .type sea_hypot_y, @function
    .p2align 4
sea_hypot_y:
    VHYPOT ymm
    .size sea_hypot_y, . - sea_hypot_y

# ---------------------------------------------------------------------
# Read-only data: this file's copy of the tables (include/math_tables.inc)
# and the patterns of the text, each replicated over four lanes.
# ---------------------------------------------------------------------
.macro KQ v
    .quad \v, \v, \v, \v
.endm
    .section .rodata
    SEA_EMIT_MATH_TABLES
    .p2align 5
.Lrvm_k:
    KQ 0x3FF0000000000000           # K_ONE       1.0
    KQ 0x7FFFFFFFFFFFFFFF           # K_ABS
    KQ 0x8000000000000000           # K_SIGN
    KQ 0x7FF0000000000000           # K_INF       +Inf
    KQ 0x4080000000000000           # K_512       512.0
    KQ 0x3C90000000000000           # K_TWOM54    2^-54
    KQ 0x0010000000000000           # K_DMIN      2^-1022
    KQ 0x3FE5F00000000000           # K_LOG_OFF   LOG_OFF
    KQ 0xFFF0000000000000           # K_EXPMASK
    KQ 0xFFFFFFFFFC000000           # K_ZHI
    KQ 0xFFFFFFFFF8000000           # K_HI27
    KQ 127                          # K_I127
    KQ 0xFF                         # K_I255
    KQ 3                            # K_I3
    KQ 1                            # K_I1
    KQ 0xBFE0000000000000           # K_MHALF     -0.5
    KQ 0x4050000000000000           # K_SIXTYFOUR 64.0
    KQ 0x3F90000000000000           # K_ONE64TH   0.015625
    KQ 0x4160000000000000           # K_TWO23     2^23
    KQ 0x3E40000000000000           # K_TWOM27    2^-27
    KQ 0x5F30000000000000           # K_TWO500    2^500
    KQ 0x20B0000000000000           # K_TWOM500   2^-500
    KQ 0x6570000000000000           # K_TWO600    2^600
    KQ 0x1A70000000000000           # K_TWOM600   2^-600
    KQ 0x2590000000000000           # K_TWOM422   2^-422

    .section .note.GNU-stack,"",@progbits
