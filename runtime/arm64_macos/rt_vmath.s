// =====================================================================
// sea/runtime/arm64_macos/rt_vmath.s -- the 2-lane vector forms of the
// elementary functions (DESIGN.md 2.12.8, 4.10.1 "Vector forms"; rt.inc
// entries 39-44).
//
// Defines: _sea_log_x _sea_exp_x _sea_sin_x _sea_cos_x _sea_pow_x
//          _sea_hypot_x (rt.inc SEA_ENT_LOG_X .. SEA_ENT_HYPOT_X)
//
// Each lane of a result is exactly the scalar entry's result for that
// lane (sea_log .. sea_hypot of rt_math.s): every lane runs the operation
// sequence of DESIGN.md 4.10.4 with the same IEEE operations in the same
// order and with the same operand order (one rounded fadd, fsub, fmul,
// fdiv or fsqrt on .2d each; never fmla/fmls or any contraction, no
// approximate instruction), the branches of the scalar text become
// per-lane selects (bit/bif with an all-ones lane mask) and the table
// lookups per-lane loads (ld2/ld3/ld4 to one lane). The rare paths of
// 4.10 (special inputs, exp with |x| >= 512, the Payne-Hanek reduction
// for |x| >= 2^23, subnormal inputs; for hypot also every operand pair
// whose larger magnitude is below 2^-500, which holds its subnormal
// rounding; for pow every lane whose exponent product reaches
// |y ln x| >= 512) are found with vector compares into one lane mask
// (v7); such lanes are computed on a harmless stand-in value by the
// vector code, and if the mask is not all zero, Lrt_vmath_fix calls the
// scalar entry for each lane that needs it and replaces that lane. The
// common case calls nothing. NEON's missing 64 x 64-bit multiply is never
// needed outside Payne-Hanek, which is rare.
//
// The tables: rt_math.s's table labels are file-local (DESIGN.md
// 4.10.3), so this file emits its own copy with SEA_EMIT_MATH_TABLES
// (the same generated words, the same local labels sea_mt_*).
//
// ABI (DESIGN.md 2.12.8): the operands in v0 (and v1), the result in v0;
// may clobber x0-x17, v0-v7, v16-v31, the upper 64 bits of v8-v15, NZCV,
// the FPSR flags (what the scalar entries may); preserves x19-x29, sp,
// d8-d15, FPCR; never touches x18. Stack: none in the common case;
// Lrt_vmath_fix keeps a 96-byte frame and calls a scalar entry (at most
// 32 bytes of its own), well inside the 512-byte bound.
// Register use common to the routines: x15 = &sea_mt_const (constant
// word k at [x15, #8*k]), v31 = 2^27 + 1 where two_prod is used, v5 and
// v6 the original operands, v7 the rare-lane mask.
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
.equ MT_EXP_REC,      16            /* EXP_TAIL, EXP_SBITS */
.equ MT_LOG_REC,      24            /* LOG_INVC, LOG_LOGC_HI, LOG_LOGC_LO */
.equ MT_TRIG_REC,     32            /* TRIG_SH, TRIG_SL, TRIG_CH, TRIG_CL */

// ---- the exact primitives of DESIGN.md 4.10.2, two lanes -------------
// Operands are written in full (v16.2d). Every output and scratch
// register must differ from the inputs and from each other; each line is
// one rounded IEEE operation per lane, in the order of rt_math.s.

// two_sum: s = a + b; bb = s - a; e = (a - (s - bb)) + (b - bb)
.macro VTWO_SUM s, e, a, b, t1, t2
    fadd \s, \a, \b                 // s = a + b
    fsub \t1, \s, \a                // bb = s - a
    fsub \t2, \s, \t1               // s - bb
    fsub \t2, \a, \t2               // a - (s - bb)
    fsub \t1, \b, \t1               // b - bb
    fadd \e, \t2, \t1               // e
.endm

// fast_two_sum: s = a + b; e = b - (s - a)
.macro VFAST_TWO_SUM s, e, a, b, t1
    fadd \s, \a, \b                 // s = a + b
    fsub \t1, \s, \a                // s - a
    fsub \e, \b, \t1                // e = b - (s - a)
.endm

// split (v31 = 2^27 + 1 in both lanes): g = c * a; h = g - (g - a); l = a - h
.macro VSPLIT h, l, a, t
    fmul \t, v31.2d, \a             // g = 134217729.0 * a
    fsub \h, \t, \a                 // g - a
    fsub \h, \t, \h                 // h = g - (g - a)
    fsub \l, \a, \h                 // l = a - h
.endm

// two_prod: p = a * b; e = (((ah*bh - p) + ah*bl) + al*bh) + al*bl
.macro VTWO_PROD p, e, a, b, ah, al, bh, bl, t
    fmul \p, \a, \b                 // p = a * b
    VSPLIT \ah, \al, \a, \t
    VSPLIT \bh, \bl, \b, \t
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

// vN = the constant word at byte offset off of sea_mt_const, in both lanes
// (n is the register number).
.macro VK n, off
    ldr d\n, [x15, #\off]
    dup v\n\().2d, v\n\().d[0]
.endm

// vN = the 64-bit pattern hi16 << 48 in both lanes (x9 clobbered).
.macro VTOP n, hi16
    movz x9, #\hi16, lsl #48
    dup v\n\().2d, x9
.endm

// The end of every entry: if the rare mask v7 has a set lane, tail-branch
// to Lrt_vmath_fix with x9 = the scalar entry sym; otherwise return.
.macro RARE_TAIL sym
    addp d16, v7.2d                 // lane 0 + lane 1 (each 0 or all ones)
    fmov x9, d16
    cbnz x9, 1f
    ret
1:  adrp x9, \sym@PAGE
    add x9, x9, \sym@PAGEOFF
    b Lrt_vmath_fix
.endm

// ---------------------------------------------------------------------
// VEXP_CORE -- e^(x + xt) per lane (DESIGN.md 4.10.4 exp_core, steps 1,
//   3-6), for lanes whose |x| < 512 or that the caller marks rare.
//   Inputs  : v16 = x (no NaN), v17 = xt, x15 = &sea_mt_const
//   Outputs : v0 = the result (step 1's 1.0 + x selected in the lanes
//             with |x| < 2^-54)
//   Clobbers: x9-x12, v16-v30 (v16, v17 preserved), v0
// ---------------------------------------------------------------------
.macro VEXP_CORE
    // 1. the lanes with top < #3C9 (|x| < 2^-54)
    fabs v18.2d, v16.2d             // abs(x)
    VTOP 19, 0x3C90
    cmhi v19.2d, v19.2d, v18.2d     // tiny lanes
    // 3. reduction
    VK 20, MC_EXP_INVLN2N
    fmul v20.2d, v20.2d, v16.2d     // z = EXP_INVLN2N * x
    VK 21, MC_EXP_SHIFT
    fadd v22.2d, v20.2d, v21.2d     // kd = z + EXP_SHIFT; ki = bits(kd)
    fsub v23.2d, v22.2d, v21.2d     // kd = kd - EXP_SHIFT
    VK 24, MC_EXP_NLN2HI_N
    fmul v24.2d, v23.2d, v24.2d     // kd * EXP_NLN2HI_N
    fadd v24.2d, v16.2d, v24.2d     // x + kd * EXP_NLN2HI_N
    VK 25, MC_EXP_NLN2LO_N
    fmul v25.2d, v23.2d, v25.2d     // kd * EXP_NLN2LO_N
    fadd v24.2d, v24.2d, v25.2d     // r
    fadd v24.2d, v24.2d, v17.2d     // r = r + xt
    // 4. table: record ki & 127 of each lane
    umov x10, v22.d[0]
    umov x11, v22.d[1]
    and x10, x10, #127              // i, lane 0
    and x11, x11, #127              // i, lane 1
    adrp x12, sea_mt_exp@PAGE
    add x12, x12, sea_mt_exp@PAGEOFF
    add x10, x12, x10, lsl #4       // record i (MT_EXP_REC bytes)
    add x11, x12, x11, lsl #4
    ld2 {v26.d, v27.d}[0], [x10]    // EXP_TAIL[i], EXP_SBITS[i], lane 0
    ld2 {v26.d, v27.d}[1], [x11]    // lane 1
    shl v25.2d, v22.2d, #45         // ki << 45
    add v27.2d, v27.2d, v25.2d      // sbits = EXP_SBITS[i] + (ki << 45)
    // 5. polynomial
    fmul v28.2d, v24.2d, v24.2d     // r2 = r * r
    fadd v29.2d, v26.2d, v24.2d     // tail + r
    VK 20, MC_EXP_C3
    fmul v20.2d, v24.2d, v20.2d     // r * EXP_C3
    VK 21, MC_EXP_C2
    fadd v20.2d, v21.2d, v20.2d     // EXP_C2 + r * EXP_C3
    fmul v20.2d, v28.2d, v20.2d     // r2 * (...)
    fadd v29.2d, v29.2d, v20.2d     // (tail + r) + r2 * (...)
    VK 20, MC_EXP_C5
    fmul v20.2d, v24.2d, v20.2d     // r * EXP_C5
    VK 21, MC_EXP_C4
    fadd v20.2d, v21.2d, v20.2d     // EXP_C4 + r * EXP_C5
    fmul v30.2d, v28.2d, v28.2d     // r2 * r2
    fmul v20.2d, v30.2d, v20.2d     // (r2 * r2) * (...)
    fadd v29.2d, v29.2d, v20.2d     // tmp
    // 6. scale + scale * tmp (scale = f64(sbits))
    fmul v20.2d, v27.2d, v29.2d     // scale * tmp
    fadd v0.2d, v27.2d, v20.2d      // scale + scale * tmp
    // 1. the tiny lanes: 1.0 + x
    fmov v21.2d, #1.0
    fadd v21.2d, v21.2d, v16.2d     // 1.0 + x
    bit v0.16b, v21.16b, v19.16b    // selected where tiny
.endm

// ---------------------------------------------------------------------
// VLOG_CORE -- (h, l) with h + l ~ ln x per lane (DESIGN.md 4.10.4
//   log_core, steps 1-7).
//   Inputs  : v16 = ix, the pattern of a positive normal value in every
//             lane, x15 = &sea_mt_const
//   Outputs : v0 = h, v1 = l
//   Clobbers: x10-x13, v16-v31 (v31 = 2^27 + 1), v0, v1
// ---------------------------------------------------------------------
.macro VLOG_CORE
    VK 31, MC_SPLIT                 // 2^27 + 1 for two_prod
    // 1. t, i, k, iz, z
    movz x10, #0x3FE5, lsl #48
    movk x10, #0xF000, lsl #32      // LOG_OFF = #3FE5F00000000000
    dup v17.2d, x10
    sub v17.2d, v16.2d, v17.2d      // t = ix - LOG_OFF
    ushr v18.2d, v17.2d, #45        // t >> 45 (the index before & 127)
    umov x10, v18.d[0]
    umov x11, v18.d[1]
    and x10, x10, #127              // i, lane 0
    and x11, x11, #127              // i, lane 1
    adrp x12, sea_mt_log@PAGE
    add x12, x12, sea_mt_log@PAGEOFF
    mov x13, #MT_LOG_REC
    madd x10, x10, x13, x12         // record i, lane 0
    madd x11, x11, x13, x12         // record i, lane 1
    ld3 {v18.d, v19.d, v20.d}[0], [x10]     // invc, LOGC_HI, LOGC_LO lane 0
    ld3 {v18.d, v19.d, v20.d}[1], [x11]     // lane 1
    sshr v21.2d, v17.2d, #52        // k = t >>a 52
    ushr v17.2d, v17.2d, #52
    shl v17.2d, v17.2d, #52         // t & #FFF0000000000000
    sub v17.2d, v16.2d, v17.2d      // iz = ix - (...); z = f64(iz)
    // 2. r = z * invc - 1 = rh + rl
    ushr v16.2d, v17.2d, #26
    shl v16.2d, v16.2d, #26         // zhi = f64(iz & #FFFFFFFFFC000000)
    fsub v17.2d, v17.2d, v16.2d     // zlo = z - zhi
    fmul v16.2d, v16.2d, v18.2d     // zhi * invc
    fmov v22.2d, #1.0
    fsub v16.2d, v16.2d, v22.2d     // rhi = zhi * invc - 1.0
    fmul v17.2d, v17.2d, v18.2d     // rlo = zlo * invc
    VTWO_SUM v18.2d, v22.2d, v16.2d, v17.2d, v23.2d, v24.2d   // (rh, rl)
    // 3. t1 and (t2, e1)
    scvtf v21.2d, v21.2d            // kd = itof(k)
    VK 16, MC_LOG_LN2HI
    fmul v16.2d, v21.2d, v16.2d     // kd * LOG_LN2HI
    fadd v16.2d, v16.2d, v19.2d     // t1 = kd * LOG_LN2HI + LOGC_HI
    VTWO_SUM v17.2d, v19.2d, v16.2d, v18.2d, v23.2d, v24.2d   // (t2, e1) = two_sum(t1, rh)
    // 4. (s, se) = two_prod(rh, rh); hs; (t3, e2)
    VTWO_PROD v23.2d, v24.2d, v18.2d, v18.2d, v16.2d, v25.2d, v26.2d, v27.2d, v28.2d
    fmov v16.2d, #-0.5
    fmul v16.2d, v16.2d, v23.2d     // hs = -0.5 * s
    VTWO_SUM v25.2d, v26.2d, v17.2d, v16.2d, v27.2d, v28.2d   // (t3, e2) = two_sum(t2, hs)
    // 5. the polynomial p
    fmul v16.2d, v18.2d, v18.2d     // r2 = rh * rh
    VK 17, MC_LOG_A9
    fmul v17.2d, v18.2d, v17.2d     // rh * A9
    VK 23, MC_LOG_A8
    fadd v17.2d, v23.2d, v17.2d     // A8 + rh * A9
    fmul v17.2d, v18.2d, v17.2d
    VK 23, MC_LOG_A7
    fadd v17.2d, v23.2d, v17.2d     // A7 + rh * (...)
    fmul v17.2d, v18.2d, v17.2d
    VK 23, MC_LOG_A6
    fadd v17.2d, v23.2d, v17.2d     // A6 + rh * (...)
    fmul v17.2d, v18.2d, v17.2d
    VK 23, MC_LOG_A5
    fadd v17.2d, v23.2d, v17.2d     // A5 + rh * (...)
    fmul v17.2d, v18.2d, v17.2d
    VK 23, MC_LOG_A4
    fadd v17.2d, v23.2d, v17.2d     // A4 + rh * (...)
    fmul v17.2d, v18.2d, v17.2d
    VK 23, MC_LOG_A3
    fadd v17.2d, v23.2d, v17.2d     // A3 + rh * (...)
    fmul v23.2d, v18.2d, v16.2d     // rh * r2
    fmul v17.2d, v23.2d, v17.2d     // p
    // 6. lo
    VK 23, MC_LOG_LN2LO
    fmul v23.2d, v21.2d, v23.2d     // kd * LOG_LN2LO
    fadd v23.2d, v23.2d, v20.2d     // + LOGC_LO
    fadd v23.2d, v23.2d, v22.2d     // + rl
    fadd v27.2d, v19.2d, v26.2d     // e1 + e2
    fadd v23.2d, v23.2d, v27.2d     // lo = lo + (e1 + e2)
    fmov v27.2d, #-0.5
    fmul v27.2d, v27.2d, v24.2d     // -0.5 * se
    fmul v28.2d, v18.2d, v22.2d     // rh * rl
    fsub v27.2d, v27.2d, v28.2d     // (-0.5 * se) - rh * rl
    fadd v23.2d, v23.2d, v27.2d     // lo = lo + (...)
    fadd v23.2d, v23.2d, v17.2d     // lo = lo + p
    // 7. (h, l) = fast_two_sum(t3, lo)
    VFAST_TWO_SUM v0.2d, v1.2d, v25.2d, v23.2d, v27.2d
.endm

    .section __TEXT,__text,regular,pure_instructions

// ---------------------------------------------------------------------
// Lrt_vmath_fix -- replace the rare lanes by the scalar entry's results.
//   Purpose : for each lane whose mask is set, call the scalar entry on
//             that lane's operands and store its result in that lane.
//   Inputs  : v0 = the vector result (valid in the lanes not marked),
//             v5 = x, v6 = y (ignored by the one-operand entries),
//             v7 = the rare-lane mask, x9 = the scalar entry's address;
//             entered by tail branch from an entry (x30 = its caller)
//   Outputs : v0 = the result, every lane
//   Clobbers: what the scalar entries may (x0-x17, v0-v7, v16-v31, the
//             upper halves of v8-v15, NZCV, FPSR)
//   Callee-saved used: none
//   Frame   : 96 bytes: frame record, [sp+16] the entry's address,
//             [sp+32] result, [sp+48] x, [sp+64] y, [sp+80] mask
// ---------------------------------------------------------------------
    .p2align 2
Lrt_vmath_fix:
    stp x29, x30, [sp, #-96]!
    mov x29, sp
    str x9, [sp, #16]               // the scalar entry
    stp q0, q5, [sp, #32]           // result, x
    stp q6, q7, [sp, #64]           // y, mask
    // lane 0
    ldr x10, [sp, #80]
    cbz x10, 1f                     // lane 0 is not rare
    ldr d0, [sp, #48]               // x, lane 0
    ldr d1, [sp, #64]               // y, lane 0
    ldr x9, [sp, #16]
    blr x9
    str d0, [sp, #32]               // result lane 0
1:  // lane 1
    ldr x10, [sp, #88]
    cbz x10, 2f                     // lane 1 is not rare
    ldr d0, [sp, #56]               // x, lane 1
    ldr d1, [sp, #72]               // y, lane 1
    ldr x9, [sp, #16]
    blr x9
    str d0, [sp, #40]               // result lane 1
2:  ldr q0, [sp, #32]               // both lanes
    ldp x29, x30, [sp], #96
    ret

// ---------------------------------------------------------------------
// _sea_exp_x -- e^x in each lane (DESIGN.md 2.12.8 EXP_X; 4.10.4 exp).
//   Purpose : rare lanes: NaN or |x| >= 512 (top >= #408, the infinities
//             included); the others exp_core(x, 0.0).
//   Inputs  : v0 = x (2 lanes)
//   Outputs : v0 = e^x per lane
//   Clobbers: x9-x15, v0-v7, v16-v30, NZCV (more on the rare path)
//   Callee-saved used: none
//   Frame   : none (leaf; tail branch to Lrt_vmath_fix for rare lanes)
// ---------------------------------------------------------------------
    .globl _sea_exp_x
    .p2align 2
_sea_exp_x:
    CONST_BASE
    mov v5.16b, v0.16b              // x, for the rare lanes
    fabs v16.2d, v0.2d              // abs(x) (a NaN stays above +inf)
    VTOP 17, 0x4080
    cmhs v7.2d, v16.2d, v17.2d      // rare: bits(|x|) >= bits(512)
    bic v16.16b, v0.16b, v7.16b     // x, +0.0 in the rare lanes
    movi v17.2d, #0                 // xt = +0.0
    VEXP_CORE
    RARE_TAIL _sea_exp

// ---------------------------------------------------------------------
// _sea_log_x -- ln x in each lane (DESIGN.md 2.12.8 LOG_X; 4.10.4 log).
//   Purpose : rare lanes: +-0, subnormal, negative, +inf, NaN, i.e.
//             bits(x) - 2^-1022's bits >= #7FE0000000000000 unsigned;
//             the others h of log_core.
//   Inputs  : v0 = x (2 lanes)
//   Outputs : v0 = ln x per lane
//   Clobbers: x9-x15, v0-v7, v16-v31, NZCV (more on the rare path)
//   Callee-saved used: none
//   Frame   : none (leaf; tail branch to Lrt_vmath_fix for rare lanes)
// ---------------------------------------------------------------------
    .globl _sea_log_x
    .p2align 2
_sea_log_x:
    CONST_BASE
    mov v5.16b, v0.16b              // x, for the rare lanes
    VTOP 16, 0x0010
    sub v17.2d, v0.2d, v16.2d       // ix - bits(2^-1022)
    VTOP 18, 0x7FE0
    cmhs v7.2d, v17.2d, v18.2d      // rare lanes
    fmov v16.2d, #1.0
    bif v16.16b, v0.16b, v7.16b     // ix, 1.0 in the rare lanes
    VLOG_CORE
    RARE_TAIL _sea_log

// ---------------------------------------------------------------------
// _sea_sin_x, _sea_cos_x -- sin x, cos x in each lane (DESIGN.md 2.12.8
//   SIN_X, COS_X; 4.10.4 sin and cos).
//   Purpose : set x14 (0 sin, 1 cos) and enter Lrt_vmath_trig.
//   Inputs  : v0 = x (2 lanes)
//   Outputs : v0 = sin x / cos x per lane
//   Clobbers: x9-x15, v0-v7, v16-v31, NZCV (more on the rare path)
//   Callee-saved used: none
//   Frame   : none (leaf; tail branch to Lrt_vmath_fix for rare lanes)
// ---------------------------------------------------------------------
    .globl _sea_sin_x
    .p2align 2
_sea_sin_x:
    mov x14, #0
    b Lrt_vmath_trig

    .globl _sea_cos_x
    .p2align 2
_sea_cos_x:
    mov x14, #1

// Lrt_vmath_trig -- v0 = x, x14 = 0 (sin) or 1 (cos); output v0.
// Rare lanes: |x| >= 2^23 (Payne-Hanek), +-inf, NaN. The lanes with
// |x| < 2^-27 take step 2's value by select. Registers: v20 = q, v21/v22
// = rh/rl, v18 = the use_cos mask, v4 = the tiny lanes.
Lrt_vmath_trig:
    CONST_BASE
    mov v5.16b, v0.16b              // x (sign of ix, the tiny result, rare lanes)
    fabs v16.2d, v0.2d              // ax
    VTOP 17, 0x4160
    cmhs v7.2d, v16.2d, v17.2d      // rare: bits(ax) >= bits(2^23)
    VTOP 17, 0x3E40
    cmhi v4.2d, v17.2d, v16.2d      // tiny: bits(ax) < bits(2^-27)
    fmov v17.2d, #1.0
    bit v16.16b, v17.16b, v7.16b    // ax = 1.0 in the rare lanes
    // 3. R1, Cody-Waite
    VK 17, MC_TRIG_INVPIO2
    fmul v17.2d, v16.2d, v17.2d     // z = ax * TRIG_INVPIO2
    VK 18, MC_EXP_SHIFT
    fadd v19.2d, v17.2d, v18.2d     // kd = z + EXP_SHIFT
    mov x10, #3
    dup v20.2d, x10
    and v20.16b, v19.16b, v20.16b   // q = bits(kd) & 3
    fsub v19.2d, v19.2d, v18.2d     // kd = kd - EXP_SHIFT
    VK 17, MC_TRIG_P1
    fmul v17.2d, v19.2d, v17.2d     // kd * TRIG_P1
    fsub v17.2d, v16.2d, v17.2d     // t1 = ax - kd * TRIG_P1
    VK 18, MC_TRIG_P2
    fmul v18.2d, v19.2d, v18.2d
    fneg v18.2d, v18.2d             // neg(kd * TRIG_P2)
    VTWO_SUM v21.2d, v22.2d, v17.2d, v18.2d, v23.2d, v24.2d   // (s, e)
    VK 18, MC_TRIG_P3
    fmul v18.2d, v19.2d, v18.2d
    fneg v18.2d, v18.2d             // neg(kd * TRIG_P3)
    VTWO_SUM v17.2d, v25.2d, v21.2d, v18.2d, v23.2d, v24.2d   // (h, l1)
    VK 18, MC_TRIG_P4
    fmul v18.2d, v19.2d, v18.2d     // kd * TRIG_P4
    fsub v18.2d, v22.2d, v18.2d     // e - kd * TRIG_P4
    fadd v18.2d, v25.2d, v18.2d     // l = l1 + (...)
    VTWO_SUM v21.2d, v22.2d, v17.2d, v18.2d, v23.2d, v24.2d   // (rh, rl) = two_sum(h, l)
    // 4. use_cos: sin q & 1, cos 1 - (q & 1) = (q & 1) xor flag, as a mask
    mov x10, #1
    dup v16.2d, x10                 // 1 per lane (kept for step 5)
    dup v17.2d, x14                 // the flag
    and v18.16b, v20.16b, v16.16b   // q & 1
    eor v18.16b, v18.16b, v17.16b   // use_cos (0 or 1)
    neg v18.2d, v18.2d              // use_cos mask
    // trig_core 1. sr, ar, al
    sshr v19.2d, v21.2d, #63        // sr mask
    VTOP 23, 0x8000                 // the sign bit (kept)
    and v24.16b, v21.16b, v23.16b   // sign of rh
    eor v24.16b, v22.16b, v24.16b   // al = neg(rl) if sr, else rl
    fabs v25.2d, v21.2d             // ar = abs(rh)
    // 2. jd, j, th
    VTOP 26, 0x4050                 // 64.0
    fmul v26.2d, v25.2d, v26.2d     // ar * 64.0
    VK 27, MC_EXP_SHIFT
    fadd v26.2d, v26.2d, v27.2d     // jd = ar * 64.0 + EXP_SHIFT
    umov x10, v26.d[0]
    umov x11, v26.d[1]
    fsub v26.2d, v26.2d, v27.2d     // jd = jd - EXP_SHIFT
    VTOP 27, 0x3F90                 // 0.015625
    fmul v26.2d, v26.2d, v27.2d     // jd * 0.015625
    fsub v26.2d, v25.2d, v26.2d     // th = ar - jd * 0.015625
    and x10, x10, #0xFF             // j, lane 0
    and x11, x11, #0xFF             // j, lane 1
    adrp x12, sea_mt_trig@PAGE
    add x12, x12, sea_mt_trig@PAGEOFF
    add x10, x12, x10, lsl #5       // record j (MT_TRIG_REC bytes)
    add x11, x12, x11, lsl #5
    ld4 {v28.d, v29.d, v30.d, v31.d}[0], [x10]  // SH, SL, CH, CL lane 0
    ld4 {v28.d, v29.d, v30.d, v31.d}[1], [x11]  // lane 1
    // 3. t2, sinp, cosp
    fmul v27.2d, v26.2d, v26.2d     // t2 = th * th
    VK 21, MC_TRIG_S7
    fmul v21.2d, v27.2d, v21.2d     // t2 * S7
    VK 22, MC_TRIG_S5
    fadd v21.2d, v22.2d, v21.2d     // S5 + t2 * S7
    fmul v21.2d, v27.2d, v21.2d
    VK 22, MC_TRIG_S3
    fadd v21.2d, v22.2d, v21.2d     // S3 + t2 * (...)
    fmul v22.2d, v26.2d, v27.2d     // th * t2
    fmul v21.2d, v22.2d, v21.2d     // sinp
    VK 22, MC_TRIG_C6
    fmul v22.2d, v27.2d, v22.2d     // t2 * C6
    VK 25, MC_TRIG_C4
    fadd v22.2d, v25.2d, v22.2d     // C4 + t2 * C6
    fmul v22.2d, v27.2d, v22.2d
    VK 25, MC_TRIG_C2
    fadd v22.2d, v25.2d, v22.2d     // C2 + t2 * (...)
    fmul v22.2d, v27.2d, v22.2d     // cosp
    // 4. (A, AL, B, BL) by use_cos
    mov v0.16b, v28.16b
    bit v0.16b, v30.16b, v18.16b    // A = SH, or CH
    mov v1.16b, v29.16b
    bit v1.16b, v31.16b, v18.16b    // AL = SL, or CL
    fneg v25.2d, v28.2d             // neg(SH)
    mov v2.16b, v30.16b
    bit v2.16b, v25.16b, v18.16b    // B = CH, or neg(SH)
    fneg v25.2d, v29.2d             // neg(SL)
    mov v3.16b, v31.16b
    bit v3.16b, v25.16b, v18.16b    // BL = CL, or neg(SL)
    // 5. the sum
    VK 31, MC_SPLIT                 // 2^27 + 1 for two_prod
    VTWO_PROD v25.2d, v27.2d, v2.2d, v26.2d, v28.2d, v29.2d, v30.2d, v6.2d, v17.2d  // (p, pe) = two_prod(B, th)
    VFAST_TWO_SUM v28.2d, v29.2d, v0.2d, v25.2d, v30.2d    // (h, e) = fast_two_sum(A, p)
    fadd v30.2d, v29.2d, v27.2d     // e + pe
    fmul v6.2d, v3.2d, v26.2d       // BL * th
    fadd v6.2d, v1.2d, v6.2d        // AL + BL * th
    fadd v30.2d, v30.2d, v6.2d      // lo
    fadd v6.2d, v21.2d, v24.2d      // sinp + al
    fmul v6.2d, v2.2d, v6.2d        // B * (...)
    fadd v30.2d, v30.2d, v6.2d      // lo = lo + B * (sinp + al)
    fmul v6.2d, v24.2d, v26.2d      // al * th
    fsub v6.2d, v22.2d, v6.2d       // cosp - al * th
    fmul v6.2d, v0.2d, v6.2d        // A * (...)
    fadd v30.2d, v30.2d, v6.2d      // lo = lo + A * (...)
    fadd v0.2d, v28.2d, v30.2d      // v = h + lo
    // 5 (sin/cos). negate = (((q + flag) >> 1) & 1) xor odd xor
    // (sin only) bit 63 of ix; odd = sr and not use_cos
    bic v19.16b, v19.16b, v18.16b   // odd mask
    dup v17.2d, x14                 // the flag
    add v25.2d, v20.2d, v17.2d      // q + flag (sin q, cos q + 1)
    ushr v25.2d, v25.2d, #1
    and v25.16b, v25.16b, v16.16b   // ((q + flag) >> 1) & 1
    neg v25.2d, v25.2d              // as a mask
    eor v25.16b, v25.16b, v19.16b   // xor odd
    sshr v27.2d, v5.2d, #63         // bit 63 of ix, as a mask
    neg v17.2d, v17.2d              // the flag as a mask (cos)
    bic v27.16b, v27.16b, v17.16b   // the sign of x counts for sin only
    eor v25.16b, v25.16b, v27.16b   // negate mask
    and v25.16b, v25.16b, v23.16b   // the sign bit where negate
    eor v0.16b, v0.16b, v25.16b     // neg(v) if negate
    // 2. the tiny lanes: sin x itself, cos 1.0
    fmov v25.2d, #1.0
    mov v27.16b, v5.16b
    bit v27.16b, v25.16b, v17.16b   // x (sin) or 1.0 (cos)
    bit v0.16b, v27.16b, v4.16b     // selected where tiny
    cbnz x14, Lrt_vmath_cos_tail
    RARE_TAIL _sea_sin
Lrt_vmath_cos_tail:
    RARE_TAIL _sea_cos

// ---------------------------------------------------------------------
// _sea_pow_x -- x^y in each lane (DESIGN.md 2.12.8 POW_X; 4.10.4 pow).
//   Purpose : lanes with y = +-0 or x = +1.0 give 1.0 by select (steps
//             1, 2). Rare lanes (the others among): a NaN, y = +-inf,
//             x = +-0, +-inf or subnormal, x < 0 with y not an integer
//             (steps 3-9's special results), and |ehi| >= 512 after step
//             10 (exp_core's huge and big paths). The rest: x < 0 with an
//             integer y clears the sign and negates an odd y's result
//             (step 8), then steps 10-12.
//   Inputs  : v0 = x, v1 = y (2 lanes each)
//   Outputs : v0 = x^y per lane
//   Clobbers: x9-x15, v0-v7, v16-v31, NZCV (more on the rare path)
//   Callee-saved used: none
//   Frame   : none (leaf; tail branch to Lrt_vmath_fix for rare lanes)
//   Registers: v2 = negate mask, v3 = the 1.0 lanes, v5/v6 = x/y,
//             v7 = rare mask
// ---------------------------------------------------------------------
    .globl _sea_pow_x
    .p2align 2
_sea_pow_x:
    CONST_BASE
    mov v5.16b, v0.16b              // x
    mov v6.16b, v1.16b              // y
    // 1, 2. y = +-0 or x = +1.0: 1.0
    shl v16.2d, v1.2d, #1
    cmeq v16.2d, v16.2d, #0         // y = +-0
    VTOP 17, 0x3FF0
    cmeq v18.2d, v0.2d, v17.2d      // ix = bits(1.0)
    orr v3.16b, v16.16b, v18.16b    // the 1.0 lanes
    // 3, 6, 7, 9. x NaN, +-0, +-inf or subnormal: bits(|x|) - 2^52 >=
    // #7FE0000000000000 unsigned
    shl v16.2d, v0.2d, #1
    ushr v16.2d, v16.2d, #1         // bits(|x|)
    VTOP 17, 0x0010
    sub v17.2d, v16.2d, v17.2d
    VTOP 18, 0x7FE0
    cmhs v7.2d, v17.2d, v18.2d      // x special
    // 3, 4. y NaN or +-inf: bits(|y|) >= bits(+inf)
    shl v17.2d, v1.2d, #1
    ushr v17.2d, v17.2d, #1         // bits(|y|)
    VTOP 18, 0x7FF0
    cmhs v18.2d, v17.2d, v18.2d
    orr v7.16b, v7.16b, v18.16b     // or y special
    // 5. classify y: e = bits(|y|) >> 52, b = 1075 - e
    ushr v17.2d, v17.2d, #52        // e
    mov x10, #1075
    dup v18.2d, x10
    sub v19.2d, v18.2d, v17.2d      // b (meaningful for 1023 <= e <= 1075)
    mov x10, #1
    dup v20.2d, x10
    ushl v21.2d, v20.2d, v19.2d     // 1 << b
    sub v22.2d, v21.2d, v20.2d      // bits 0 .. b-1
    cmtst v22.2d, v1.2d, v22.2d     // a fraction bit set
    cmtst v21.2d, v1.2d, v21.2d     // bit b set
    cmhi v18.2d, v17.2d, v18.2d     // e > 1075: even integer
    mov x10, #1023
    dup v19.2d, x10
    cmhi v19.2d, v19.2d, v17.2d     // e < 1023: not an integer
    bic v22.16b, v22.16b, v18.16b   // fraction bits count only for e <= 1075
    orr v22.16b, v22.16b, v19.16b   // not an integer
    bic v21.16b, v21.16b, v18.16b
    bic v21.16b, v21.16b, v22.16b   // odd integer
    // 8. x < 0: y not an integer is rare (NAN); negate for an odd y
    sshr v23.2d, v0.2d, #63         // x < 0
    and v24.16b, v23.16b, v22.16b
    orr v7.16b, v7.16b, v24.16b     // x < 0 and y not an integer
    and v2.16b, v23.16b, v21.16b    // negate
    bic v7.16b, v7.16b, v3.16b      // the 1.0 lanes are not rare
    // ix = bits(|x|) (bit 63 cleared), 1.0 in the rare and 1.0 lanes
    orr v24.16b, v7.16b, v3.16b
    fmov v17.2d, #1.0
    bit v16.16b, v17.16b, v24.16b
    // 10. (lh, lt) = log_core(ix)
    VLOG_CORE                       // v0 = lh, v1 = lt
    ushr v16.2d, v6.2d, #27
    shl v16.2d, v16.2d, #27         // yhi = f64(iy & #FFFFFFFFF8000000)
    fsub v17.2d, v6.2d, v16.2d      // ylo = y - yhi
    ushr v18.2d, v0.2d, #27
    shl v18.2d, v18.2d, #27         // lhi = f64(bits(lh) & #FFFFFFFFF8000000)
    fsub v19.2d, v0.2d, v18.2d      // lh - lhi
    fadd v19.2d, v19.2d, v1.2d      // llo = (lh - lhi) + lt
    fmul v20.2d, v16.2d, v18.2d     // ehi = yhi * lhi
    fmul v21.2d, v17.2d, v18.2d     // ylo * lhi
    fmul v22.2d, v6.2d, v19.2d      // y * llo
    fadd v17.2d, v21.2d, v22.2d     // elo
    mov v16.16b, v20.16b            // exp_core's x
    // 11. |ehi| >= 512 (top >= #408) is rare
    shl v18.2d, v16.2d, #1
    ushr v18.2d, v18.2d, #1         // bits(|ehi|)
    VTOP 19, 0x4080
    cmhs v18.2d, v18.2d, v19.2d
    bic v18.16b, v18.16b, v3.16b    // not in the 1.0 lanes
    orr v7.16b, v7.16b, v18.16b
    VEXP_CORE                       // v0 = v
    // 12. neg(v) if negate; the 1.0 lanes
    VTOP 16, 0x8000
    and v16.16b, v16.16b, v2.16b
    eor v0.16b, v0.16b, v16.16b     // neg(v) where negate
    fmov v16.2d, #1.0
    bit v0.16b, v16.16b, v3.16b     // 1.0 where y = +-0 or x = +1.0
    RARE_TAIL _sea_pow

// ---------------------------------------------------------------------
// _sea_hypot_x -- sqrt(x^2 + y^2) in each lane (DESIGN.md 2.12.8
//   HYPOT_X; 4.10.4 hypot).
//   Purpose : rare lanes: an infinity or NaN (step 1), or a larger
//             magnitude below 2^-500 (step 3's scaling up, which holds
//             step 6's subnormal rounding; both operands zero included).
//             The rest: ordering by select, ay = 0 gives ax by select,
//             the scaling down by 2^-600 for ax > 2^500 by select (the
//             other lanes multiply by 1.0, which is exact, and the
//             scalar text multiplies by scale = 1.0 at the end too).
//   Inputs  : v0 = x, v1 = y (2 lanes each)
//   Outputs : v0 = hypot(x, y) per lane
//   Clobbers: x9-x15, v0-v7, v16-v31, NZCV (more on the rare path)
//   Callee-saved used: none
//   Frame   : none (leaf; tail branch to Lrt_vmath_fix for rare lanes)
// ---------------------------------------------------------------------
    .globl _sea_hypot_x
    .p2align 2
_sea_hypot_x:
    CONST_BASE
    mov v5.16b, v0.16b              // x
    mov v6.16b, v1.16b              // y
    // 2. ax = abs(x), ay = abs(y), swapped so that ax >= ay (bits)
    fabs v16.2d, v0.2d
    fabs v17.2d, v1.2d
    cmhi v18.2d, v17.2d, v16.2d     // bits(ax) < bits(ay): swap
    mov v19.16b, v16.16b
    bit v19.16b, v17.16b, v18.16b   // ax (the larger)
    mov v20.16b, v17.16b
    bit v20.16b, v16.16b, v18.16b   // ay (the smaller)
    // 1. an infinity or NaN; 3. ax < 2^-500: rare
    VTOP 21, 0x7FF0
    cmhs v7.2d, v19.2d, v21.2d      // bits(ax) >= bits(+inf)
    VTOP 21, 0x20B0
    cmhi v21.2d, v21.2d, v19.2d     // bits(ax) < bits(2^-500)
    orr v7.16b, v7.16b, v21.16b
    cmeq v4.2d, v20.2d, #0          // ay = 0: the result is ax
    fmov v21.2d, #1.0
    bit v19.16b, v21.16b, v7.16b    // 1.0 in the rare lanes
    bit v20.16b, v21.16b, v7.16b
    mov v3.16b, v19.16b             // ax unscaled (the ay = 0 result)
    // 3. scale down where bits(ax) > #5F30000000000000
    VTOP 22, 0x5F30
    cmhi v22.2d, v19.2d, v22.2d     // ax > 2^500
    VTOP 23, 0x1A70                 // 2^-600
    mov v24.16b, v21.16b
    bit v24.16b, v23.16b, v22.16b   // the factor: 2^-600 or 1.0
    VTOP 23, 0x6570                 // 2^600
    mov v2.16b, v21.16b
    bit v2.16b, v23.16b, v22.16b    // scale: 2^600 or 1.0
    fmul v19.2d, v19.2d, v24.2d     // ax = ax * factor
    fmul v20.2d, v20.2d, v24.2d     // ay = ay * factor
    // 4. sh + sl = ax^2 + ay^2
    VK 31, MC_SPLIT
    VTWO_PROD v16.2d, v17.2d, v19.2d, v19.2d, v21.2d, v22.2d, v23.2d, v24.2d, v25.2d  // (p, pe)
    VTWO_PROD v18.2d, v26.2d, v20.2d, v20.2d, v21.2d, v22.2d, v23.2d, v24.2d, v25.2d  // (q, qe)
    VTWO_SUM v27.2d, v28.2d, v16.2d, v18.2d, v21.2d, v22.2d    // (sh, sl)
    fadd v21.2d, v17.2d, v26.2d     // pe + qe
    fadd v28.2d, v28.2d, v21.2d     // sl = sl + (pe + qe)
    VFAST_TWO_SUM v29.2d, v30.2d, v27.2d, v28.2d, v21.2d   // (sh, sl)
    // 5. the root and its correction
    fsqrt v16.2d, v29.2d            // h = sqrt(sh)
    VTWO_PROD v17.2d, v18.2d, v16.2d, v16.2d, v21.2d, v22.2d, v23.2d, v24.2d, v25.2d  // (hh, he)
    fsub v19.2d, v29.2d, v17.2d     // sh - hh
    fsub v19.2d, v19.2d, v18.2d     // (sh - hh) - he
    fadd v19.2d, v19.2d, v30.2d     // d = ... + sl
    fadd v20.2d, v16.2d, v16.2d     // h + h
    fdiv v19.2d, v19.2d, v20.2d     // corr = d / (h + h)
    // 6. (h + corr) * scale
    fadd v0.2d, v16.2d, v19.2d      // h + corr
    fmul v0.2d, v0.2d, v2.2d        // * scale
    bit v0.16b, v3.16b, v4.16b      // ay = 0: ax
    RARE_TAIL _sea_hypot

// ---------------------------------------------------------------------
// The constants and tables (include/math_tables.inc, DESIGN.md 4.10.3):
// this file's own copy, under the same file-local labels.
// ---------------------------------------------------------------------
    .section __TEXT,__const
    SEA_EMIT_MATH_TABLES
