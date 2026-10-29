// =====================================================================
// sea/runtime/arm64_macos/rt_math.s -- the elementary functions log exp
// sin cos pow hypot (LANGUAGE.md 10.4; DESIGN.md 4.10, 4.8 entries 3-8)
// and f64 % (entry 26, FMOD).
//
// Defines: _sea_log _sea_exp _sea_sin _sea_cos _sea_pow _sea_hypot
//          (rt.inc SEA_ENT_LOG .. SEA_ENT_HYPOT, symbols sea_log ..)
//          and _sea_fmod (SEA_ENT_FMOD: f64 %, LANGUAGE.md 6.6), which
//          calls the C library's fmod and keeps the ordinary AAPCS64
//          clobbers (it is not one of the 4.10 functions)
//
// Every result is the bit pattern of DESIGN.md 4.10.4: each step below is
// the IEEE operation the text lists, in its order (one rounded fadd, fsub,
// fmul, fdiv or fsqrt each; never fmadd/fmsub or any contraction), so the
// two runtimes, the Python model and the compile-time pow agree on every
// bit. Integer steps are exact 64-bit operations. Every NaN result is
// #7FF8000000000000 (constant word 31). FPCR is never changed.
//
// ABI (DESIGN.md 4.10.1): x in d0 (y in d1), result in d0; may clobber
// x0-x17, v0-v7, v16-v31 and the flags; preserves x19-x29, sp, d8-d15;
// never touches x18. Register use common to the routines: x15 holds the
// address of sea_mt_const (the constant word k is [x15, #8*k]), d31 the
// splitting constant 2^27 + 1 where two_prod is used. The entries call
// only the internal cores of this file (Lrt_math_exp_core,
// Lrt_math_log_core), by tail branch, except pow, which keeps a frame.
// =====================================================================
.include "rt.inc"
.include "math_tables.inc"

// Word offsets into sea_mt_const (DESIGN.md 4.10.4, constant table).
.equ MC_EXP_INVLN2N,  0*8
.equ MC_EXP_SHIFT,    1*8
.equ MC_EXP_NLN2HI_N, 2*8
.equ MC_EXP_NLN2LO_N, 3*8
.equ MC_EXP_C2,       4*8
.equ MC_EXP_C3,       5*8
.equ MC_EXP_C4,       6*8
.equ MC_EXP_C5,       7*8
.equ MC_LOG_LN2HI,    8*8
.equ MC_LOG_LN2LO,    9*8
.equ MC_LOG_A3,       10*8
.equ MC_LOG_A4,       11*8
.equ MC_LOG_A5,       12*8
.equ MC_LOG_A6,       13*8
.equ MC_LOG_A7,       14*8
.equ MC_LOG_A8,       15*8
.equ MC_LOG_A9,       16*8
.equ MC_TRIG_INVPIO2, 17*8
.equ MC_TRIG_P1,      18*8
.equ MC_TRIG_P2,      19*8
.equ MC_TRIG_P3,      20*8
.equ MC_TRIG_P4,      21*8
.equ MC_PIO2_HI,      22*8
.equ MC_PIO2_LO,      23*8
.equ MC_TRIG_S3,      24*8
.equ MC_TRIG_S5,      25*8
.equ MC_TRIG_S7,      26*8
.equ MC_TRIG_C2,      27*8
.equ MC_TRIG_C4,      28*8
.equ MC_TRIG_C6,      29*8
.equ MC_SPLIT,        30*8
.equ MC_NAN,          31*8

// Record sizes of the tables (DESIGN.md 4.10.3).
.equ MT_LOG_REC,      24            /* LOG_INVC, LOG_LOGC_HI, LOG_LOGC_LO */

// ---- the exact primitives of DESIGN.md 4.10.2 -----------------------
// Every output and scratch register must differ from the inputs and from
// each other; each line is one rounded IEEE operation.

// two_sum: s = a + b; bb = s - a; e = (a - (s - bb)) + (b - bb)
.macro TWO_SUM s, e, a, b, t1, t2
    fadd \s, \a, \b                 // s = a + b
    fsub \t1, \s, \a                // bb = s - a
    fsub \t2, \s, \t1               // s - bb
    fsub \t2, \a, \t2               // a - (s - bb)
    fsub \t1, \b, \t1               // b - bb
    fadd \e, \t2, \t1               // e
.endm

// fast_two_sum: s = a + b; e = b - (s - a)
.macro FAST_TWO_SUM s, e, a, b, t1
    fadd \s, \a, \b                 // s = a + b
    fsub \t1, \s, \a                // s - a
    fsub \e, \b, \t1                // e = b - (s - a)
.endm

// split (d31 = 2^27 + 1): g = c * a; h = g - (g - a); l = a - h
.macro SPLIT h, l, a, t
    fmul \t, d31, \a                // g = 134217729.0 * a
    fsub \h, \t, \a                 // g - a
    fsub \h, \t, \h                 // h = g - (g - a)
    fsub \l, \a, \h                 // l = a - h
.endm

// two_prod: p = a * b; e = (((ah*bh - p) + ah*bl) + al*bh) + al*bl
.macro TWO_PROD p, e, a, b, ah, al, bh, bl, t
    fmul \p, \a, \b                 // p = a * b
    SPLIT \ah, \al, \a, \t
    SPLIT \bh, \bl, \b, \t
    fmul \e, \ah, \bh               // ah * bh
    fsub \e, \e, \p                 // ah*bh - p
    fmul \t, \ah, \bl
    fadd \e, \e, \t                 // + ah*bl
    fmul \t, \al, \bh
    fadd \e, \e, \t                 // + al*bh
    fmul \t, \al, \bl
    fadd \e, \e, \t                 // + al*bl
.endm

// x15 = &sea_mt_const
.macro CONST_BASE
    adrp x15, sea_mt_const@PAGE
    add x15, x15, sea_mt_const@PAGEOFF
.endm

    .section __TEXT,__text,regular,pure_instructions

// ---------------------------------------------------------------------
// _sea_exp -- e^x (DESIGN.md 4.10.4 exp).
//   Purpose : NaN gives NAN; otherwise exp_core(x, 0.0).
//   Inputs  : d0 = x
//   Outputs : d0 = e^x
//   Clobbers: x0-x7, x15, d0-d7, d16-d31, NZCV
//   Callee-saved used: none
//   Frame   : none (leaf; tail branch into the core)
// ---------------------------------------------------------------------
    .globl _sea_exp
    .p2align 2
_sea_exp:
    CONST_BASE
    fcmp d0, d0
    b.vs Lrt_math_nan               // x is NaN
    movi d1, #0                     // xt = +0.0
    b Lrt_math_exp_core

// ---------------------------------------------------------------------
// Lrt_math_exp_core -- e^(x + xt) for x not NaN, |xt| <= 2^-25 |x|.
//   Purpose : DESIGN.md 4.10.4 exp_core, steps 1-7.
//   Inputs  : d0 = x, d1 = xt, x15 = &sea_mt_const
//   Outputs : d0 = the result
//   Clobbers: x0-x7, d0-d7, d16-d30, NZCV
//   Callee-saved used: none
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_math_exp_core:
    fmov x0, d0                     // bits(x)
    ubfx x1, x0, #52, #11           // top
    cmp x1, #0x3C9
    b.lo Lrt_math_exp_tiny          // |x| < 2^-54
    cmp x1, #0x409
    b.hs Lrt_math_exp_huge          // |x| >= 1024, +-inf included
    // 3. reduction
    ldr d2, [x15, #MC_EXP_INVLN2N]
    fmul d3, d2, d0                 // z = EXP_INVLN2N * x
    ldr d4, [x15, #MC_EXP_SHIFT]
    fadd d5, d3, d4                 // kd = z + EXP_SHIFT
    fmov x2, d5                     // ki = bits(kd)
    fsub d5, d5, d4                 // kd = kd - EXP_SHIFT
    ldr d6, [x15, #MC_EXP_NLN2HI_N]
    fmul d7, d5, d6                 // kd * EXP_NLN2HI_N
    fadd d7, d0, d7                 // x + kd * EXP_NLN2HI_N
    ldr d6, [x15, #MC_EXP_NLN2LO_N]
    fmul d16, d5, d6                // kd * EXP_NLN2LO_N
    fadd d7, d7, d16                // r
    fadd d7, d7, d1                 // r = r + xt
    // 4. table
    and x3, x2, #127                // i
    adrp x4, sea_mt_exp@PAGE
    add x4, x4, sea_mt_exp@PAGEOFF
    add x4, x4, x3, lsl #4          // record i (2 words)
    ldp x5, x6, [x4]                // EXP_TAIL[i], EXP_SBITS[i]
    fmov d17, x5                    // tail
    add x6, x6, x2, lsl #45         // sbits = EXP_SBITS[i] + (ki << 45)
    // 5. polynomial
    fmul d18, d7, d7                // r2 = r * r
    fadd d19, d17, d7               // tail + r
    ldr d20, [x15, #MC_EXP_C2]
    ldr d21, [x15, #MC_EXP_C3]
    fmul d22, d7, d21               // r * EXP_C3
    fadd d22, d20, d22              // EXP_C2 + r * EXP_C3
    fmul d22, d18, d22              // r2 * (...)
    fadd d19, d19, d22              // (tail + r) + r2 * (...)
    ldr d20, [x15, #MC_EXP_C4]
    ldr d21, [x15, #MC_EXP_C5]
    fmul d22, d7, d21               // r * EXP_C5
    fadd d22, d20, d22              // EXP_C4 + r * EXP_C5
    fmul d23, d18, d18              // r2 * r2
    fmul d22, d23, d22              // (r2 * r2) * (...)
    fadd d19, d19, d22              // tmp
    cmp x1, #0x408
    b.hs Lrt_math_exp_big           // 512 <= |x| < 1024 (rare)
    // 6. scale + scale * tmp
    fmov d24, x6                    // scale
    fmul d25, d24, d19              // scale * tmp
    fadd d0, d24, d25
    ret
Lrt_math_exp_big:
    tbnz x2, #31, Lrt_math_exp_neg  // bit 31 of ki: k < 0
    movz x7, #0x3F10, lsl #48       // 1009 << 52
    sub x6, x6, x7
    fmov d24, x6                    // scale = f64(sbits - (1009 << 52))
    fmul d25, d24, d19              // scale * tmp
    fadd d26, d24, d25              // scale + scale * tmp
    movz x7, #0x7F00, lsl #48       // 2^1009
    fmov d27, x7
    fmul d0, d27, d26               // 2^1009 * (...)
    ret
Lrt_math_exp_neg:
    movz x7, #0x3FE0, lsl #48       // 1022 << 52
    add x6, x6, x7
    fmov d24, x6                    // scale = f64(sbits + (1022 << 52))
    fmul d25, d24, d19              // scale * tmp
    fadd d26, d24, d25              // y = scale + scale * tmp
    fmov d28, #1.0
    fcmp d26, d28
    b.ge Lrt_math_exp_neg_done      // y >= 1.0: no subnormal rounding
    fsub d29, d24, d26              // scale - y
    fadd d29, d29, d25              // lo = (scale - y) + scale * tmp
    fadd d30, d28, d26              // hi = 1.0 + y
    fsub d27, d28, d30              // 1.0 - hi
    fadd d27, d27, d26              // (1.0 - hi) + y
    fadd d29, d27, d29              // lo = ((1.0 - hi) + y) + lo
    fadd d26, d30, d29              // hi + lo
    fsub d26, d26, d28              // y = (hi + lo) - 1.0
Lrt_math_exp_neg_done:
    movz x7, #0x0010, lsl #48       // 2^-1022
    fmov d27, x7
    fmul d0, d27, d26               // 2^-1022 * y
    ret
Lrt_math_exp_tiny:
    fmov d2, #1.0
    fadd d0, d2, d0                 // 1.0 + x
    ret
Lrt_math_exp_huge:
    movi d0, #0                     // +0.0 for x < 0
    tbnz x0, #63, 1f
    movz x7, #0x7FF0, lsl #48       // +inf
    fmov d0, x7
1:  ret

// The NaN result (x15 = &sea_mt_const).
Lrt_math_nan:
    ldr d0, [x15, #MC_NAN]
    ret

// ---------------------------------------------------------------------
// _sea_log -- ln x (DESIGN.md 4.10.4 log).
//   Purpose : the special values, the subnormal rescaling, then h of
//             log_core.
//   Inputs  : d0 = x
//   Outputs : d0 = ln x
//   Clobbers: x0-x9, x15, d0-d7, d16-d31, NZCV
//   Callee-saved used: none
//   Frame   : none (leaf; tail branch into the core)
// ---------------------------------------------------------------------
    .globl _sea_log
    .p2align 2
_sea_log:
    CONST_BASE
    fcmp d0, d0
    b.vs Lrt_math_nan               // NaN
    fmov x0, d0                     // ix
    lsl x1, x0, #1
    cbz x1, Lrt_math_log_zero       // +-0: -inf
    tbnz x0, #63, Lrt_math_nan      // x < 0 (-inf included)
    movz x1, #0x7FF0, lsl #48
    cmp x0, x1
    b.eq Lrt_math_ret               // +inf: +inf
    lsr x1, x0, #52
    cbnz x1, Lrt_math_log_core      // normal: h of log_core (d0)
    movz x1, #0x4330, lsl #48       // 2^52
    fmov d1, x1
    fmul d0, d0, d1                 // x * 2^52
    fmov x0, d0
    movz x1, #0x0340, lsl #48       // 52 << 52
    sub x0, x0, x1                  // ix = bits(x * 2^52) - (52 << 52)
    b Lrt_math_log_core
Lrt_math_log_zero:
    movz x1, #0xFFF0, lsl #48       // -inf
    fmov d0, x1
Lrt_math_ret:
    ret

// ---------------------------------------------------------------------
// Lrt_math_log_core -- (h, l) with h + l ~ ln x (DESIGN.md 4.10.4).
//   Purpose : log_core steps 1-7 for the pattern of a positive normal
//             value (exponent possibly below -1022 after rescaling).
//   Inputs  : x0 = ix, x15 = &sea_mt_const
//   Outputs : d0 = h, d1 = l
//   Clobbers: x1-x9, d0-d7, d16-d31, NZCV (d31 = 2^27 + 1)
//   Callee-saved used: none
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .p2align 2
Lrt_math_log_core:
    ldr d31, [x15, #MC_SPLIT]
    // 1. t, i, k, iz, z
    movz x1, #0x3FE5, lsl #48
    movk x1, #0xF000, lsl #32       // LOG_OFF = #3FE5F00000000000
    sub x2, x0, x1                  // t = ix - LOG_OFF
    ubfx x3, x2, #45, #7            // i = (t >> 45) & 127
    asr x4, x2, #52                 // k = t >>a 52
    and x5, x2, #0xFFF0000000000000
    sub x5, x0, x5                  // iz = ix - (t & #FFF0000000000000)
    fmov d2, x5                     // z
    // 2. the table and r = z * invc - 1 = rh + rl
    adrp x6, sea_mt_log@PAGE
    add x6, x6, sea_mt_log@PAGEOFF
    mov x7, #MT_LOG_REC
    madd x6, x3, x7, x6             // record i
    ldr d3, [x6]                    // invc
    ldr d16, [x6, #8]               // LOG_LOGC_HI[i]
    ldr d17, [x6, #16]              // LOG_LOGC_LO[i]
    and x9, x5, #0xFFFFFFFFFC000000
    fmov d4, x9                     // zhi
    fsub d5, d2, d4                 // zlo = z - zhi
    fmul d6, d4, d3                 // zhi * invc
    fmov d7, #1.0
    fsub d6, d6, d7                 // rhi = zhi * invc - 1.0
    fmul d18, d5, d3                // rlo = zlo * invc
    TWO_SUM d19, d20, d6, d18, d21, d22     // (rh, rl)
    // 3. t1 and (t2, e1)
    scvtf d23, x4                   // kd = itof(k)
    ldr d24, [x15, #MC_LOG_LN2HI]
    fmul d25, d23, d24              // kd * LOG_LN2HI
    fadd d25, d25, d16              // t1 = kd * LOG_LN2HI + LOGC_HI
    TWO_SUM d26, d27, d25, d19, d21, d22    // (t2, e1) = two_sum(t1, rh)
    // 4. (s, se) = two_prod(rh, rh); hs; (t3, e2)
    TWO_PROD d28, d29, d19, d19, d0, d1, d2, d4, d5
    fmov d30, #-0.5
    fmul d30, d30, d28              // hs = -0.5 * s
    TWO_SUM d6, d7, d26, d30, d21, d22      // (t3, e2) = two_sum(t2, hs)
    // 5. the polynomial p
    fmul d2, d19, d19               // r2 = rh * rh
    ldr d4, [x15, #MC_LOG_A9]
    fmul d4, d19, d4                // rh * A9
    ldr d5, [x15, #MC_LOG_A8]
    fadd d4, d5, d4                 // A8 + rh * A9
    fmul d4, d19, d4
    ldr d5, [x15, #MC_LOG_A7]
    fadd d4, d5, d4                 // A7 + rh * (...)
    fmul d4, d19, d4
    ldr d5, [x15, #MC_LOG_A6]
    fadd d4, d5, d4                 // A6 + rh * (...)
    fmul d4, d19, d4
    ldr d5, [x15, #MC_LOG_A5]
    fadd d4, d5, d4                 // A5 + rh * (...)
    fmul d4, d19, d4
    ldr d5, [x15, #MC_LOG_A4]
    fadd d4, d5, d4                 // A4 + rh * (...)
    fmul d4, d19, d4
    ldr d5, [x15, #MC_LOG_A3]
    fadd d4, d5, d4                 // A3 + rh * (...)
    fmul d5, d19, d2                // rh * r2
    fmul d4, d5, d4                 // p
    // 6. lo
    ldr d5, [x15, #MC_LOG_LN2LO]
    fmul d5, d23, d5                // kd * LOG_LN2LO
    fadd d5, d5, d17                // + LOGC_LO
    fadd d5, d5, d20                // + rl
    fadd d21, d27, d7               // e1 + e2
    fadd d5, d5, d21                // lo = lo + (e1 + e2)
    fmov d21, #-0.5
    fmul d21, d21, d29              // -0.5 * se
    fmul d22, d19, d20              // rh * rl
    fsub d21, d21, d22              // (-0.5 * se) - rh * rl
    fadd d5, d5, d21                // lo = lo + (...)
    fadd d5, d5, d4                 // lo = lo + p
    // 7. (h, l) = fast_two_sum(t3, lo)
    FAST_TWO_SUM d0, d1, d6, d5, d21
    ret

// ---------------------------------------------------------------------
// _sea_pow -- x^y (DESIGN.md 4.10.4 pow, C99 F.9.4.4).
//   Purpose : the special cases (steps 1-9), then e^(y ln x) through
//             log_core and exp_core with the split product of step 10.
//   Inputs  : d0 = x, d1 = y
//   Outputs : d0 = x^y
//   Clobbers: x0-x9, x15, d0-d7, d16-d31, NZCV
//   Callee-saved used: none
//   Frame   : 32 bytes (frame record; [sp+16] bits(y), [sp+24] negate)
// ---------------------------------------------------------------------
    .globl _sea_pow
    .p2align 2
_sea_pow:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    CONST_BASE
    fmov x0, d0                     // ix
    fmov x1, d1                     // iy
    fmov d7, #1.0
    // 1. y = +-0: 1.0
    lsl x2, x1, #1
    cbz x2, Lrt_math_pow_one
    // 2. x = +1.0: 1.0
    movz x2, #0x3FF0, lsl #48
    cmp x0, x2
    b.eq Lrt_math_pow_one
    // 3. a NaN: NAN
    fcmp d0, d0
    b.vs Lrt_math_pow_nan
    fcmp d1, d1
    b.vs Lrt_math_pow_nan
    // 4. y = +-inf
    and x3, x1, #0x7FFFFFFFFFFFFFFF
    movz x4, #0x7FF0, lsl #48       // bits(+inf)
    cmp x3, x4
    b.ne Lrt_math_pow_class
    movz x5, #0xBFF0, lsl #48       // bits(-1.0)
    cmp x0, x5
    b.eq Lrt_math_pow_one           // x = -1: 1.0
    and x5, x0, #0x7FFFFFFFFFFFFFFF // bits(|x|)
    cmp x5, x2                      // |x| against 1.0 (|x| = 1 is handled)
    b.hi 1f
    tbnz x1, #63, Lrt_math_pow_inf  // |x| < 1, y = -inf: +inf
    b Lrt_math_pow_pzero
1:  tbz x1, #63, Lrt_math_pow_inf   // |x| > 1, y = +inf: +inf
    b Lrt_math_pow_pzero
    // 5. classify y: x6 = 0 not an integer, 1 odd, 2 even
Lrt_math_pow_class:
    ubfx x3, x1, #52, #11           // e
    mov x6, #0
    cmp x3, #1023
    b.lo 2f                         // e < 1023: not an integer
    mov x6, #2
    cmp x3, #1075
    b.hi 2f                         // e > 1075: even
    mov x7, #1075
    sub x7, x7, x3                  // b = 1075 - e (0 .. 52)
    mov x8, #1
    lsl x8, x8, x7                  // 1 << b
    sub x9, x8, #1                  // bits 0 .. b-1
    tst x1, x9
    mov x6, #0
    b.ne 2f                         // a fraction bit: not an integer
    mov x6, #2
    tst x1, x8
    b.eq 2f                         // bit b clear: even
    mov x6, #1                      // odd
2:
    // 6. x = +-0
    lsl x2, x0, #1
    cbnz x2, Lrt_math_pow_xinf
    tbz x1, #63, 3f                 // y > 0
    cmp x6, #1
    b.ne Lrt_math_pow_inf
    tbnz x0, #63, Lrt_math_pow_ninf // x = -0, y an odd integer: -inf
    b Lrt_math_pow_inf
3:  cmp x6, #1
    b.eq Lrt_math_pow_done          // y odd: x itself (d0)
    b Lrt_math_pow_pzero
    // 7. x = +-inf
Lrt_math_pow_xinf:
    and x5, x0, #0x7FFFFFFFFFFFFFFF
    cmp x5, x4
    b.ne Lrt_math_pow_neg
    tbnz x0, #63, 4f                // x = -inf
    tbnz x1, #63, Lrt_math_pow_pzero
    b Lrt_math_pow_inf
4:  tbz x1, #63, 5f                 // y > 0
    cmp x6, #1
    b.ne Lrt_math_pow_pzero
    movz x2, #0x8000, lsl #48       // -0.0
    fmov d0, x2
    b Lrt_math_pow_done
5:  cmp x6, #1
    b.eq Lrt_math_pow_ninf
    b Lrt_math_pow_inf
    // 8. x < 0: y must be an integer; negate for an odd one
Lrt_math_pow_neg:
    mov x7, #0                      // negate
    tbz x0, #63, 6f
    cbz x6, Lrt_math_pow_nan
    cmp x6, #1
    cset x7, eq
    and x0, x0, #0x7FFFFFFFFFFFFFFF // clear bit 63 of ix
6:
    // 9. x subnormal
    lsr x2, x0, #52
    cbnz x2, 7f
    fmov d2, x0
    movz x2, #0x4330, lsl #48       // 2^52
    fmov d3, x2
    fmul d2, d2, d3                 // f64(ix) * 2^52
    fmov x0, d2
    movz x2, #0x0340, lsl #48       // 52 << 52
    sub x0, x0, x2
7:
    // 10. (lh, lt) = log_core(ix); the split product y * (lh + lt)
    stp x1, x7, [sp, #16]           // bits(y), negate
    bl Lrt_math_log_core            // d0 = lh, d1 = lt
    ldp x1, x7, [sp, #16]
    and x2, x1, #0xFFFFFFFFF8000000
    fmov d2, x2                     // yhi
    fmov d3, x1                     // y
    fsub d4, d3, d2                 // ylo = y - yhi
    fmov x4, d0
    and x4, x4, #0xFFFFFFFFF8000000
    fmov d5, x4                     // lhi
    fsub d6, d0, d5                 // lh - lhi
    fadd d6, d6, d1                 // llo = (lh - lhi) + lt
    fmul d0, d2, d5                 // ehi = yhi * lhi
    fmul d16, d4, d5                // ylo * lhi
    fmul d17, d3, d6                // y * llo
    fadd d1, d16, d17               // elo
    // 11. v = exp_core(ehi, elo)
    str x7, [sp, #24]
    bl Lrt_math_exp_core
    ldr x7, [sp, #24]
    // 12. neg(v) if negate
    cbz x7, Lrt_math_pow_done
    fneg d0, d0
    b Lrt_math_pow_done
Lrt_math_pow_one:
    fmov d0, d7                     // 1.0
    b Lrt_math_pow_done
Lrt_math_pow_nan:
    ldr d0, [x15, #MC_NAN]
    b Lrt_math_pow_done
Lrt_math_pow_inf:
    movz x2, #0x7FF0, lsl #48       // +inf
    fmov d0, x2
    b Lrt_math_pow_done
Lrt_math_pow_ninf:
    movz x2, #0xFFF0, lsl #48       // -inf
    fmov d0, x2
    b Lrt_math_pow_done
Lrt_math_pow_pzero:
    movi d0, #0                     // +0.0
Lrt_math_pow_done:
    ldp x29, x30, [sp], #32
    ret

// ---------------------------------------------------------------------
// _sea_sin, _sea_cos -- sin x, cos x (DESIGN.md 4.10.4 sin and cos).
//   Purpose : set x14 (0 sin, 1 cos) and enter Lrt_math_trig.
//   Inputs  : d0 = x
//   Outputs : d0 = sin x / cos x
//   Clobbers: x0-x17, d0-d7, d16-d31, NZCV
//   Callee-saved used: none
//   Frame   : none (leaf); 16 bytes below sp during Payne-Hanek
// ---------------------------------------------------------------------
    .globl _sea_sin
    .p2align 2
_sea_sin:
    mov x14, #0
    b Lrt_math_trig

    .globl _sea_cos
    .p2align 2
_sea_cos:
    mov x14, #1

// Lrt_math_trig -- inputs d0 = x, x14 = 0 (sin) or 1 (cos); output d0.
// Registers: x0 = ix, x1 = bits(ax), x2 = q, rh in d21, rl in d22.
Lrt_math_trig:
    CONST_BASE
    fmov x0, d0                     // ix
    and x1, x0, #0x7FFFFFFFFFFFFFFF // bits(ax)
    // 1. inf or NaN: NAN
    movz x2, #0x7FF0, lsl #48
    cmp x1, x2
    b.hs Lrt_math_nan
    // 2. |x| < 2^-27: sin x = x, cos x = 1.0
    movz x2, #0x3E40, lsl #48
    cmp x1, x2
    b.hs 1f
    cbz x14, Lrt_math_ret           // sin: x itself
    fmov d0, #1.0                   // cos: 1.0
    ret
1:  ldr d31, [x15, #MC_SPLIT]
    fmov d2, x1                     // ax
    movz x2, #0x4160, lsl #48       // 2^23
    cmp x1, x2
    b.hs Lrt_math_trig_r2
    // 3. R1, Cody-Waite (ax < 2^23)
    ldr d3, [x15, #MC_TRIG_INVPIO2]
    fmul d3, d2, d3                 // z = ax * TRIG_INVPIO2
    ldr d16, [x15, #MC_EXP_SHIFT]
    fadd d4, d3, d16                // kd = z + EXP_SHIFT
    fmov x2, d4
    and x2, x2, #3                  // q = bits(kd) & 3
    fsub d4, d4, d16                // kd = kd - EXP_SHIFT
    ldr d5, [x15, #MC_TRIG_P1]
    fmul d5, d4, d5                 // kd * TRIG_P1
    fsub d5, d2, d5                 // t1 = ax - kd * TRIG_P1
    ldr d6, [x15, #MC_TRIG_P2]
    fmul d6, d4, d6
    fneg d6, d6                     // neg(kd * TRIG_P2)
    TWO_SUM d7, d16, d5, d6, d17, d18       // (s, e)
    ldr d6, [x15, #MC_TRIG_P3]
    fmul d6, d4, d6
    fneg d6, d6                     // neg(kd * TRIG_P3)
    TWO_SUM d19, d20, d7, d6, d17, d18      // (h, l1)
    ldr d6, [x15, #MC_TRIG_P4]
    fmul d6, d4, d6                 // kd * TRIG_P4
    fsub d6, d16, d6                // e - kd * TRIG_P4
    fadd d6, d20, d6                // l = l1 + (...)
    TWO_SUM d21, d22, d19, d6, d17, d18     // (rh, rl) = two_sum(h, l)
    b Lrt_math_trig_core

    // R2, Payne-Hanek (ax >= 2^23, rare)
Lrt_math_trig_r2:
    stp x0, x14, [sp, #-16]!        // ix and the sin/cos flag
    and x3, x1, #0x000FFFFFFFFFFFFF
    orr x3, x3, #0x0010000000000000 // m
    lsr x4, x1, #52
    sub x4, x4, #1075               // E
    add x4, x4, #62                 // G = E + 62
    lsr x5, x4, #6                  // w = G >> 6
    and x6, x4, #63                 // sh = G & 63
    adrp x7, sea_mt_tpi@PAGE
    add x7, x7, sea_mt_tpi@PAGEOFF
    add x7, x7, x5, lsl #3          // &TPI[w]
    mov x8, #63
    sub x8, x8, x6                  // 63 - sh
    ldp x9, x10, [x7]               // TPI[w], TPI[w+1]
    ldp x12, x13, [x7, #16]         // TPI[w+2], TPI[w+3]
    // W2 = word(w)
    lsl x9, x9, x6
    lsr x11, x10, #1
    lsr x11, x11, x8
    orr x9, x9, x11
    // W1 = word(w+1)
    lsl x10, x10, x6
    lsr x11, x12, #1
    lsr x11, x11, x8
    orr x10, x10, x11
    // W0 = word(w+2)
    lsl x12, x12, x6
    lsr x11, x13, #1
    lsr x11, x11, x8
    orr x12, x12, x11
    // 3. the 192-bit product mod 2^192: P2:P1:P0
    umulh x13, x3, x12              // c0
    mul x14, x3, x12                // a0 = P0
    umulh x16, x3, x10              // c1
    mul x17, x3, x10                // a1
    mul x9, x3, x9                  // a2 (low half of m * W2)
    adds x13, x13, x17              // P1 = c0 + a1; carry = k1
    adc x16, x16, x9                // P2 = c1 + a2 + k1
    // 4. quadrant and the shifted fraction T2:T1:T0
    lsr x2, x16, #62
    ubfx x4, x16, #61, #1
    add x2, x2, x4
    and x2, x2, #3                  // q
    lsl x4, x16, #2
    orr x4, x4, x13, lsr #62        // T2
    lsl x5, x13, #2
    orr x5, x5, x14, lsr #62        // T1
    lsl x6, x14, #2                 // T0
    // 5. three 53-bit pieces
    asr x7, x4, #11                 // A = T2 >>a 11
    and x8, x4, #0x7FF
    lsl x8, x8, #42
    orr x8, x8, x5, lsr #22         // B
    and x9, x5, #0x3FFFFF
    lsl x9, x9, #31
    orr x9, x9, x6, lsr #33         // C
    scvtf d2, x7
    movz x10, #0x3CA0, lsl #48      // 2^-53
    fmov d3, x10
    fmul d2, d2, d3                 // a
    scvtf d4, x8
    movz x10, #0x3950, lsl #48      // 2^-106
    fmov d3, x10
    fmul d4, d4, d3                 // b
    scvtf d5, x9
    movz x10, #0x3600, lsl #48      // 2^-159
    fmov d3, x10
    fmul d5, d5, d3                 // c
    TWO_SUM d6, d7, d2, d4, d17, d18        // (h, l) = two_sum(a, b)
    TWO_SUM d19, d20, d6, d5, d17, d18      // (h, t) = two_sum(h, c)
    fadd d7, d7, d20                // l = l + t
    // 6. r = f * pi/2
    ldr d16, [x15, #MC_PIO2_HI]
    TWO_PROD d21, d22, d19, d16, d23, d24, d25, d26, d27   // (p, pe)
    ldr d23, [x15, #MC_PIO2_LO]
    fmul d23, d19, d23              // h * TRIG_PIO2_LO
    fmul d24, d7, d16               // l * TRIG_PIO2_HI
    fadd d23, d23, d24
    fadd d23, d22, d23              // pl = pe + (...)
    FAST_TWO_SUM d24, d22, d21, d23, d25    // (rh, rl) = fast_two_sum(p, pl)
    fmov d21, d24                   // rh
    ldp x0, x14, [sp], #16

    // trig_core(rh, rl, use_cos) and the sign (steps 4-5)
Lrt_math_trig_core:
    and x3, x2, #1
    eor x3, x3, x14                 // use_cos: sin q & 1, cos 1 - (q & 1)
    fmov x4, d21
    lsr x4, x4, #63                 // sr
    fabs d2, d21                    // ar = abs(rh)
    fmov d3, d22                    // al = rl
    cbz x4, 1f
    fneg d3, d22                    // al = neg(rl) when sr
1:  movz x5, #0x4050, lsl #48       // 64.0
    fmov d4, x5
    fmul d4, d2, d4                 // ar * 64.0
    ldr d16, [x15, #MC_EXP_SHIFT]
    fadd d4, d4, d16                // jd = ar * 64.0 + EXP_SHIFT
    fmov x5, d4
    and x5, x5, #0xFF               // j
    fsub d4, d4, d16                // jd = jd - EXP_SHIFT
    movz x6, #0x3F90, lsl #48       // 0.015625
    fmov d5, x6
    fmul d5, d4, d5                 // jd * 0.015625
    fsub d5, d2, d5                 // th = ar - jd * 0.015625
    fmul d6, d5, d5                 // t2 = th * th
    ldr d7, [x15, #MC_TRIG_S7]
    fmul d7, d6, d7                 // t2 * S7
    ldr d16, [x15, #MC_TRIG_S5]
    fadd d7, d16, d7                // S5 + t2 * S7
    fmul d7, d6, d7
    ldr d16, [x15, #MC_TRIG_S3]
    fadd d7, d16, d7                // S3 + t2 * (...)
    fmul d16, d5, d6                // th * t2
    fmul d7, d16, d7                // sinp
    ldr d16, [x15, #MC_TRIG_C6]
    fmul d16, d6, d16               // t2 * C6
    ldr d17, [x15, #MC_TRIG_C4]
    fadd d16, d17, d16              // C4 + t2 * C6
    fmul d16, d6, d16
    ldr d17, [x15, #MC_TRIG_C2]
    fadd d16, d17, d16              // C2 + t2 * (...)
    fmul d16, d6, d16               // cosp
    adrp x6, sea_mt_trig@PAGE
    add x6, x6, sea_mt_trig@PAGEOFF
    add x6, x6, x5, lsl #5          // record j (4 words)
    ldp d17, d18, [x6]              // TRIG_SH[j], TRIG_SL[j]
    ldp d19, d20, [x6, #16]         // TRIG_CH[j], TRIG_CL[j]
    cbnz x3, 2f
    fmov d23, d17                   // A = SH
    fmov d24, d18                   // AL = SL
    fmov d25, d19                   // B = CH
    fmov d26, d20                   // BL = CL
    b 3f
2:  fmov d23, d19                   // A = CH
    fmov d24, d20                   // AL = CL
    fneg d25, d17                   // B = neg(SH)
    fneg d26, d18                   // BL = neg(SL)
3:  TWO_PROD d27, d28, d25, d5, d29, d30, d0, d1, d4   // (p, pe) = two_prod(B, th)
    FAST_TWO_SUM d0, d1, d23, d27, d4       // (h, e) = fast_two_sum(A, p)
    fadd d2, d1, d28                // e + pe
    fmul d4, d26, d5                // BL * th
    fadd d4, d24, d4                // AL + BL * th
    fadd d2, d2, d4                 // lo
    fadd d4, d7, d3                 // sinp + al
    fmul d4, d25, d4                // B * (...)
    fadd d2, d2, d4                 // lo = lo + B * (sinp + al)
    fmul d4, d3, d5                 // al * th
    fsub d4, d16, d4                // cosp - al * th
    fmul d4, d23, d4                // A * (...)
    fadd d2, d2, d4                 // lo = lo + A * (...)
    fadd d0, d0, d2                 // v = h + lo
    bic x7, x4, x3                  // odd = sr and not use_cos
    cbnz x14, 4f
    lsr x8, x2, #1                  // sin: q >> 1
    eor x8, x8, x7
    eor x8, x8, x0, lsr #63         // ... xor bit 63 of ix
    b 5f
4:  add x8, x2, #1                  // cos: ((q + 1) >> 1) & 1
    ubfx x8, x8, #1, #1
    eor x8, x8, x7
5:  tbz x8, #0, 6f
    fneg d0, d0                     // neg(v)
6:  ret

// ---------------------------------------------------------------------
// _sea_hypot -- sqrt(x^2 + y^2) (DESIGN.md 4.10.4 hypot, C99 F.9.4.3).
//   Purpose : the special values, ordering, scaling, the double-length
//             sum of squares, its root with one correction, the
//             subnormal rounding.
//   Inputs  : d0 = x, d1 = y
//   Outputs : d0 = hypot(x, y)
//   Clobbers: x0-x5, x15, d0-d7, d16-d31, NZCV
//   Callee-saved used: none
//   Frame   : none (leaf)
// ---------------------------------------------------------------------
    .globl _sea_hypot
    .p2align 2
_sea_hypot:
    CONST_BASE
    fmov x0, d0
    fmov x1, d1
    and x2, x0, #0x7FFFFFFFFFFFFFFF // bits(ax)
    and x3, x1, #0x7FFFFFFFFFFFFFFF // bits(ay)
    // 1. an infinity: +inf; else a NaN: NAN
    movz x4, #0x7FF0, lsl #48
    cmp x2, x4
    b.eq Lrt_math_hypot_inf
    cmp x3, x4
    b.eq Lrt_math_hypot_inf
    cmp x2, x4
    b.hi Lrt_math_nan
    cmp x3, x4
    b.hi Lrt_math_nan
    // 2. ax >= ay; ay = 0: ax
    cmp x2, x3
    b.hs 1f
    mov x5, x2
    mov x2, x3
    mov x3, x5                      // swap
1:  fmov d2, x2                     // ax
    fmov d3, x3                     // ay
    fmov d0, d2
    cbz x3, Lrt_math_ret            // ay = 0: ax
    // 3. scale: x5 = 0 (none), 1 (by 2^-600), 2 (by 2^600)
    mov x5, #0
    fmov d30, #1.0                  // scale
    movz x4, #0x5F30, lsl #48       // 2^500
    cmp x2, x4
    b.ls 2f
    movz x4, #0x1A70, lsl #48       // 2^-600
    fmov d4, x4
    fmul d2, d2, d4
    fmul d3, d3, d4
    movz x4, #0x6570, lsl #48       // scale = 2^600
    fmov d30, x4
    mov x5, #1
    b 3f
2:  movz x4, #0x20B0, lsl #48       // 2^-500
    cmp x2, x4
    b.hs 3f
    movz x4, #0x6570, lsl #48       // 2^600
    fmov d4, x4
    fmul d2, d2, d4
    fmul d3, d3, d4
    movz x4, #0x1A70, lsl #48       // scale = 2^-600
    fmov d30, x4
    mov x5, #2
3:  ldr d31, [x15, #MC_SPLIT]
    // 4. sh + sl = ax^2 + ay^2
    TWO_PROD d4, d5, d2, d2, d16, d17, d18, d19, d20    // (p, pe)
    TWO_PROD d6, d7, d3, d3, d16, d17, d18, d19, d20    // (q, qe)
    TWO_SUM d21, d22, d4, d6, d16, d17                  // (sh, sl)
    fadd d16, d5, d7                // pe + qe
    fadd d22, d22, d16              // sl = sl + (pe + qe)
    FAST_TWO_SUM d23, d24, d21, d22, d16                // (sh, sl)
    // 5. the root and its correction
    fsqrt d25, d23                  // h = sqrt(sh)
    TWO_PROD d26, d27, d25, d25, d16, d17, d18, d19, d20   // (hh, he)
    fsub d28, d23, d26              // sh - hh
    fsub d28, d28, d27              // (sh - hh) - he
    fadd d28, d28, d24              // d = ... + sl
    fadd d29, d25, d25              // h + h
    fdiv d29, d28, d29              // corr = d / (h + h)
    // 6. the subnormal rounding, or (h + corr) * scale
    cmp x5, #2
    b.ne 4f
    fmov x4, d25
    movz x3, #0x2590, lsl #48       // 2^-422
    cmp x4, x3
    b.hs 4f
    fmov d16, x3                    // 2^-422
    TWO_SUM d17, d18, d16, d25, d19, d20                // (u, ue)
    fadd d18, d18, d29              // lo = ue + corr
    fadd d17, d17, d18              // u + lo
    fsub d17, d17, d16              // (u + lo) - 2^-422
    fmul d0, d17, d30               // * 2^-600
    ret
4:  fadd d0, d25, d29               // h + corr
    fmul d0, d0, d30                // * scale
    ret
Lrt_math_hypot_inf:
    movz x4, #0x7FF0, lsl #48
    fmov d0, x4
    ret

// ---------------------------------------------------------------------
// _sea_fmod -- a % b for f64 (LANGUAGE.md 6.6; DESIGN.md 4.8 entry FMOD,
//   2.11.6, L-cm).
//   Purpose : in this order: b = +-0 gives a's bits unchanged; else an
//             infinite a or a NaN operand gives #7FF8000000000000; else
//             r = the C library's fmod(a, b) (exact by IEEE 754, so the
//             same bits from Apple's libm and glibc), and r + b (one
//             rounded fadd) when r != 0 and r and b differ in sign. A
//             zero r keeps the sign fmod gives it (the sign of a).
//   Inputs  : d0 = a, d1 = b
//   Outputs : d0 = a % b
//   Clobbers: x0-x17, x15, d0-d7, d16-d31, NZCV (calls libm's fmod: the
//             ordinary AAPCS64 clobbers, not the narrower set of 4.10.1)
//   Callee-saved used: d8 = b across the call
//   Frame   : 32 bytes (frame record + d8, pad)
// ---------------------------------------------------------------------
    .globl _sea_fmod
    .p2align 2
_sea_fmod:
    // b = +-0 (an ordered compare: a NaN b is not equal to 0): a as it is.
    fcmp d1, #0.0
    b.eq Lrt_math_fmod_ret
    // A NaN a or b: the compare of a with b is unordered.
    fcmp d0, d1
    b.vs Lrt_math_fmod_nan
    // An infinite a: |a| bits << 1 equal Inf's bits << 1 (NaN is gone).
    fmov x9, d0
    lsl x9, x9, #1
    movz x10, #0xFFE0, lsl #48      // Inf's bits << 1
    cmp x9, x10
    b.eq Lrt_math_fmod_nan
    stp x29, x30, [sp, #-32]!       // frame record
    mov x29, sp
    str d8, [sp, #16]
    fmov d8, d1                     // keep b across the call
    bl _fmod                        // d0 = r = fmod(a, b), exact
    // r != 0 and sign(r) != sign(b): r + b, rounded once.
    fcmp d0, #0.0
    b.eq 1f                         // r = +-0: kept as fmod gives it
    fmov x9, d0
    fmov x10, d8
    eor x9, x9, x10                 // bit 63: the signs differ
    tbz x9, #63, 1f
    fadd d0, d0, d8                 // r + b
1:  ldr d8, [sp, #16]
    ldp x29, x30, [sp], #32
Lrt_math_fmod_ret:
    ret
Lrt_math_fmod_nan:
    CONST_BASE
    ldr d0, [x15, #MC_NAN]          // #7FF8000000000000, constant word 31
    ret

// ---------------------------------------------------------------------
// The constants and tables (include/math_tables.inc, DESIGN.md 4.10.3).
// ---------------------------------------------------------------------
    .section __TEXT,__const
    SEA_EMIT_MATH_TABLES
