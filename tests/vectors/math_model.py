# tests/vectors/math_model.py -- the bit-exact model of Sea's elementary functions
# (Sea DESIGN.md 4.10.2 - 4.10.4), the oracle for the expected bits of tests/math/*.vec and
# tests/vectors/fepow.txt (DESIGN.md 4.10.6).
#
# DESIGN.md 4.10.4 transcribed operation by operation. Every float operation here is one IEEE
# binary64 operation, round to nearest even (Python floats; no FMA, no wider precision); integer
# steps are exact on 64-bit patterns, masked explicitly. The constants and tables are read from
# include/math_tables.inc, the file both runtimes assemble. Importable (sea_log, sea_exp, sea_sin,
# sea_cos, sea_pow, sea_hypot take and return floats; the *_bits variants take and return
# patterns); no third-party module is needed.
import math
import os
import struct

M64 = (1 << 64) - 1
HERE = os.path.dirname(os.path.abspath(__file__))
TABLES = os.path.join(HERE, '..', '..', 'include', 'math_tables.inc')


def bits(x):
    return struct.unpack('<Q', struct.pack('<d', x))[0]


def f64(u):
    return struct.unpack('<d', struct.pack('<Q', u & M64))[0]


def neg(x):
    return f64(bits(x) ^ (1 << 63))


def fabs(x):
    return f64(bits(x) & ~(1 << 63))


def s64(u):
    u &= M64
    return u - (1 << 64) if u >> 63 else u


def asr(u, n):
    """arithmetic shift right of a 64-bit pattern, as a signed integer"""
    return s64(u) >> n


def itof(i):
    """signed integer -> f64; every use is exact (|i| < 2^53)"""
    assert -(1 << 53) <= i <= (1 << 53)
    return float(i)


# ---- the tables of include/math_tables.inc (DESIGN.md 4.10.3) ----------------------------
def _read_tables(path):
    tabs = {}
    cur = None
    with open(path) as f:
        for line in f:
            line = line.rstrip('\n')
            if line.startswith('sea_mt_') and line.endswith(':'):
                cur = line[:-1]
                tabs[cur] = []
            elif line.startswith('    .quad 0x') and cur is not None:
                tabs[cur].append(int(line[12:], 16))
    sizes = {'sea_mt_const': 32, 'sea_mt_exp': 256, 'sea_mt_log': 384, 'sea_mt_trig': 208,
             'sea_mt_tpi': 20}
    for k, n in sizes.items():
        if len(tabs.get(k, ())) != n:
            raise ValueError('%s: %s has %d words, expected %d' % (path, k, len(tabs.get(k, ())), n))
    return tabs


_T = _read_tables(TABLES)
_C = [f64(w) for w in _T['sea_mt_const']]
(EXP_INVLN2N, EXP_SHIFT, EXP_NLN2HI_N, EXP_NLN2LO_N, EXP_C2, EXP_C3, EXP_C4, EXP_C5,
 LOG_LN2HI, LOG_LN2LO, LOG_A3, LOG_A4, LOG_A5, LOG_A6, LOG_A7, LOG_A8, LOG_A9,
 TRIG_INVPIO2, TRIG_P1, TRIG_P2, TRIG_P3, TRIG_P4, TRIG_PIO2_HI, TRIG_PIO2_LO,
 TRIG_S3, TRIG_S5, TRIG_S7, TRIG_C2, TRIG_C4, TRIG_C6, SPLIT, NAN) = _C

EXP_TAIL = [f64(_T['sea_mt_exp'][2 * i]) for i in range(128)]
EXP_SBITS = [_T['sea_mt_exp'][2 * i + 1] for i in range(128)]
LOG_INVC = [f64(_T['sea_mt_log'][3 * i]) for i in range(128)]
LOG_LOGC_HI = [f64(_T['sea_mt_log'][3 * i + 1]) for i in range(128)]
LOG_LOGC_LO = [f64(_T['sea_mt_log'][3 * i + 2]) for i in range(128)]
TRIG_SH = [f64(_T['sea_mt_trig'][4 * j]) for j in range(52)]
TRIG_SL = [f64(_T['sea_mt_trig'][4 * j + 1]) for j in range(52)]
TRIG_CH = [f64(_T['sea_mt_trig'][4 * j + 2]) for j in range(52)]
TRIG_CL = [f64(_T['sea_mt_trig'][4 * j + 3]) for j in range(52)]
TPI = list(_T['sea_mt_tpi'])

LOG_OFF = 0x3FE5F00000000000
INF = f64(0x7FF0000000000000)
P2_1009 = f64(0x7F00000000000000)
P2_M1022 = f64(0x0010000000000000)
P2_52 = f64(0x4330000000000000)
P2_M422 = f64(0x2590000000000000)
P2_600 = f64(0x6570000000000000)
P2_M600 = f64(0x1A70000000000000)
P2_M53 = f64(0x3CA0000000000000)
P2_M106 = f64(0x3950000000000000)
P2_M159 = f64(0x3600000000000000)


# ---- DESIGN.md 4.10.2: shared primitives ------------------------------------------------
def two_sum(a, b):
    s = a + b
    bb = s - a
    e = (a - (s - bb)) + (b - bb)
    return s, e


def fast_two_sum(a, b):
    s = a + b
    e = b - (s - a)
    return s, e


def split(a):
    g = SPLIT * a
    h = g - (g - a)
    l = a - h
    return h, l


def two_prod(a, b):
    p = a * b
    ah, al = split(a)
    bh, bl = split(b)
    e = (((ah * bh - p) + ah * bl) + al * bh) + al * bl
    return p, e


# ---- exp ------------------------------------------------------------------------------------
def exp_core(x, xt):
    top = (bits(x) >> 52) & 0x7FF
    if top < 0x3C9:                                   # step 1
        return 1.0 + x
    if top >= 0x409:                                  # step 2
        return 0.0 if bits(x) >> 63 else INF
    z = EXP_INVLN2N * x                               # step 3
    kd = z + EXP_SHIFT
    ki = bits(kd)
    kd = kd - EXP_SHIFT
    r = (x + kd * EXP_NLN2HI_N) + kd * EXP_NLN2LO_N
    r = r + xt
    i = ki & 127                                      # step 4
    tail = EXP_TAIL[i]
    sbits = (EXP_SBITS[i] + (ki << 45)) & M64
    r2 = r * r                                        # step 5
    tmp = ((tail + r) + r2 * (EXP_C2 + r * EXP_C3)) + (r2 * r2) * (EXP_C4 + r * EXP_C5)
    if top < 0x408:                                   # step 6
        scale = f64(sbits)
        return scale + scale * tmp
    if (ki >> 31) & 1 == 0:                           # step 7, k > 0
        scale = f64(sbits - (1009 << 52))
        return P2_1009 * (scale + scale * tmp)
    scale = f64(sbits + (1022 << 52))                 # step 7, k < 0
    y = scale + scale * tmp
    if y < 1.0:
        lo = (scale - y) + scale * tmp
        hi = 1.0 + y
        lo = ((1.0 - hi) + y) + lo
        y = (hi + lo) - 1.0
    return P2_M1022 * y


def sea_exp(x):
    if x != x:
        return NAN
    return exp_core(x, 0.0)


# ---- log ------------------------------------------------------------------------------------
def log_core(ix):
    t = (ix - LOG_OFF) & M64                          # step 1
    i = (t >> 45) & 127
    k = asr(t, 52)
    iz = (ix - (t & 0xFFF0000000000000)) & M64
    z = f64(iz)
    invc = LOG_INVC[i]                                # step 2
    zhi = f64(iz & 0xFFFFFFFFFC000000)
    zlo = z - zhi
    rhi = zhi * invc - 1.0
    rlo = zlo * invc
    rh, rl = two_sum(rhi, rlo)
    kd = itof(k)                                      # step 3
    t1 = kd * LOG_LN2HI + LOG_LOGC_HI[i]
    t2, e1 = two_sum(t1, rh)
    s, se = two_prod(rh, rh)                          # step 4
    hs = -0.5 * s
    t3, e2 = two_sum(t2, hs)
    r2 = rh * rh                                      # step 5
    p = (rh * r2) * (LOG_A3 + rh * (LOG_A4 + rh * (LOG_A5 + rh * (LOG_A6 + rh * (LOG_A7 + rh * (LOG_A8 + rh * LOG_A9))))))
    lo = (kd * LOG_LN2LO + LOG_LOGC_LO[i]) + rl       # step 6
    lo = lo + (e1 + e2)
    lo = lo + ((-0.5 * se) - rh * rl)
    lo = lo + p
    return fast_two_sum(t3, lo)                       # step 7


def sea_log(x):
    ix = bits(x)
    if x != x:
        return NAN
    if x == 0.0:
        return neg(INF)
    if ix >> 63:
        return NAN
    if ix == 0x7FF0000000000000:
        return INF
    if ix >> 52 == 0:
        ix = (bits(x * P2_52) - (52 << 52)) & M64
    h, l = log_core(ix)
    return h


# ---- pow ------------------------------------------------------------------------------------
NOT_INT, ODD, EVEN = 0, 1, 2


def _yclass(iy):
    e = (iy >> 52) & 0x7FF
    if e < 1023:
        return NOT_INT
    if e > 1075:
        return EVEN
    b = 1075 - e
    if iy & ((1 << b) - 1):
        return NOT_INT
    return ODD if (iy >> b) & 1 else EVEN


def sea_pow(x, y):
    ix, iy = bits(x), bits(y)
    if (iy << 1) & M64 == 0:                          # 1
        return 1.0
    if ix == 0x3FF0000000000000:                      # 2
        return 1.0
    if x != x or y != y:                              # 3
        return NAN
    if (iy << 1) & M64 == 0xFFE0000000000000:         # 4
        if ix == 0xBFF0000000000000:
            return 1.0
        ax = fabs(x)
        if (ax < 1.0 and iy >> 63) or (ax > 1.0 and not iy >> 63):
            return INF
        return 0.0
    yc = _yclass(iy)                                  # 5
    if (ix << 1) & M64 == 0:                          # 6
        if iy >> 63:
            return neg(INF) if (ix >> 63 and yc == ODD) else INF
        return x if yc == ODD else 0.0
    if (ix << 1) & M64 == 0xFFE0000000000000:         # 7
        if not ix >> 63:
            return 0.0 if iy >> 63 else INF
        if iy >> 63:
            return neg(0.0) if yc == ODD else 0.0
        return neg(INF) if yc == ODD else INF
    negate = False
    if ix >> 63:                                      # 8
        if yc == NOT_INT:
            return NAN
        negate = yc == ODD
        ix &= ~(1 << 63)
    if ix >> 52 == 0:                                 # 9
        ix = (bits(f64(ix) * P2_52) - (52 << 52)) & M64
    lh, lt = log_core(ix)                             # 10
    yhi = f64(iy & 0xFFFFFFFFF8000000)
    ylo = y - yhi
    lhi = f64(bits(lh) & 0xFFFFFFFFF8000000)
    llo = (lh - lhi) + lt
    ehi = yhi * lhi
    elo = (ylo * lhi) + (y * llo)                     # unread by exp_core when |ehi| >= 1024
    v = exp_core(ehi, elo)                            # 11
    return neg(v) if negate else v                    # 12


# ---- sin / cos ------------------------------------------------------------------------------
def _reduce(ax):
    if bits(ax) < 0x4160000000000000:                 # R1
        z = ax * TRIG_INVPIO2
        kd = z + EXP_SHIFT
        q = bits(kd) & 3
        kd = kd - EXP_SHIFT
        t1 = ax - kd * TRIG_P1
        s, e = two_sum(t1, neg(kd * TRIG_P2))
        h, l1 = two_sum(s, neg(kd * TRIG_P3))
        l = l1 + (e - kd * TRIG_P4)
        rh, rl = two_sum(h, l)
        return q, rh, rl
    ib = bits(ax)                                     # R2
    m = (ib & 0x000FFFFFFFFFFFFF) | 0x0010000000000000
    E = ((ib >> 52) & 0x7FF) - 1075
    G = E + 62
    w = G >> 6
    sh = G & 63

    def word(n):
        return ((TPI[n] << sh) & M64) | ((TPI[n + 1] >> 1) >> (63 - sh))
    W2, W1, W0 = word(w), word(w + 1), word(w + 2)
    p0, p1, p2 = m * W0, m * W1, m * W2
    c0, a0 = p0 >> 64, p0 & M64
    c1, a1 = p1 >> 64, p1 & M64
    a2 = p2 & M64
    P0 = a0
    P1 = (c0 + a1) & M64
    k1 = 1 if P1 < a1 else 0
    P2 = (c1 + a2 + k1) & M64
    q = ((P2 >> 62) + ((P2 >> 61) & 1)) & 3
    T2 = ((P2 << 2) | (P1 >> 62)) & M64
    T1 = ((P1 << 2) | (P0 >> 62)) & M64
    T0 = (P0 << 2) & M64
    A = asr(T2, 11)
    B = ((T2 & 0x7FF) << 42) | (T1 >> 22)
    C = ((T1 & 0x3FFFFF) << 31) | (T0 >> 33)
    a = itof(A) * P2_M53
    b = itof(B) * P2_M106
    c = itof(C) * P2_M159
    h, l = two_sum(a, b)
    h, t = two_sum(h, c)
    l = l + t
    p, pe = two_prod(h, TRIG_PIO2_HI)
    pl = pe + ((h * TRIG_PIO2_LO) + (l * TRIG_PIO2_HI))
    rh, rl = fast_two_sum(p, pl)
    return q, rh, rl


def _trig_core(rh, rl, use_cos):
    sr = bits(rh) >> 63
    ar = fabs(rh)                                     # 1
    al = neg(rl) if sr else rl
    jd = ar * 64.0 + EXP_SHIFT                        # 2
    j = bits(jd) & 0xFF
    jd = jd - EXP_SHIFT
    th = ar - jd * 0.015625
    t2 = th * th                                      # 3
    sinp = (th * t2) * (TRIG_S3 + t2 * (TRIG_S5 + t2 * TRIG_S7))
    cosp = t2 * (TRIG_C2 + t2 * (TRIG_C4 + t2 * TRIG_C6))
    if use_cos:                                       # 4
        A, AL, B, BL = TRIG_CH[j], TRIG_CL[j], neg(TRIG_SH[j]), neg(TRIG_SL[j])
    else:
        A, AL, B, BL = TRIG_SH[j], TRIG_SL[j], TRIG_CH[j], TRIG_CL[j]
    p, pe = two_prod(B, th)                           # 5
    h, e = fast_two_sum(A, p)
    lo = (e + pe) + (AL + BL * th)
    lo = lo + B * (sinp + al)
    lo = lo + A * (cosp - al * th)
    return h + lo, sr


def _sincos(x, is_cos):
    ix = bits(x)
    aix = ix & 0x7FFFFFFFFFFFFFFF
    if aix >= 0x7FF0000000000000:                     # 1
        return NAN
    if aix < 0x3E40000000000000:                      # 2
        return 1.0 if is_cos else x
    q, rh, rl = _reduce(f64(aix))                     # 3
    use_cos = (1 - (q & 1)) if is_cos else (q & 1)    # 4
    v, sr = _trig_core(rh, rl, use_cos)
    odd = sr & (1 - use_cos)                          # 5
    if is_cos:
        negate = (((q + 1) >> 1) & 1) ^ odd
    else:
        negate = (q >> 1) ^ odd ^ (ix >> 63)
    return neg(v) if negate else v


def sea_sin(x):
    return _sincos(x, False)


def sea_cos(x):
    return _sincos(x, True)


# ---- hypot ----------------------------------------------------------------------------------
def sea_hypot(x, y):
    if fabs(x) == INF or fabs(y) == INF:              # 1
        return INF
    if x != x or y != y:
        return NAN
    ax, ay = fabs(x), fabs(y)                         # 2
    if bits(ax) < bits(ay):
        ax, ay = ay, ax
    if ay == 0.0:
        return ax
    scale = 1.0                                       # 3
    if bits(ax) > 0x5F30000000000000:
        ax, ay, scale = ax * P2_M600, ay * P2_M600, P2_600
    elif bits(ax) < 0x20B0000000000000:
        ax, ay, scale = ax * P2_600, ay * P2_600, P2_M600
    p, pe = two_prod(ax, ax)                          # 4
    q, qe = two_prod(ay, ay)
    sh, sl = two_sum(p, q)
    sl = sl + (pe + qe)
    sh, sl = fast_two_sum(sh, sl)
    h = math.sqrt(sh)                                 # 5
    hh, he = two_prod(h, h)
    d = ((sh - hh) - he) + sl
    corr = d / (h + h)
    if scale == P2_M600 and bits(h) < 0x2590000000000000:   # 6
        u, ue = two_sum(P2_M422, h)
        lo = ue + corr
        return ((u + lo) - P2_M422) * P2_M600
    return (h + corr) * scale


FUNCS = {'log': sea_log, 'exp': sea_exp, 'sin': sea_sin, 'cos': sea_cos, 'pow': sea_pow,
         'hypot': sea_hypot}
ARITY = {'log': 1, 'exp': 1, 'sin': 1, 'cos': 1, 'pow': 2, 'hypot': 2}


def eval_bits(fn, args):
    """args and result as 64-bit patterns"""
    return bits(FUNCS[fn](*[f64(a) for a in args]))
