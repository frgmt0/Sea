"""Exact-arithmetic vectors for passes/lib/f64emu.bas and passes/lib/limb.bas (DESIGN.md 2.8).

Run from anywhere with `uv run python sea/tests/vectors/f64emu.py`; writes f64emu.txt and
limb.txt next to this file. Fields are separated by one space; an f64 or i64 bit pattern is
written `#` and 16 upper-case hex digits (the f field of DESIGN.md 3.1).

f64emu.txt (A, B, R are binary64 patterns, sign bit first):
  add|sub|mul|div A B R      IEEE-754 binary64, round to nearest even (LANGUAGE.md 6.5)
  fmod A B R                 C fmod, exact
  mod A B R                  Sea `%` on f64 (LANGUAGE.md 6.6)
  sqrt A R                   correctly rounded square root
  neg A R                    sign flip
  cmp A B C                  C = -1, 0, 1, or 2 when unordered (a NaN)
  cls A K S                  K: 0 zero, 1 subnormal, 2 normal, 3 infinity, 4 NaN; S sign bit
  fri I R X                  i64 pattern I -> f64 (ties to even); X = 1 if inexact
  toi A R E                  f64 -> i64: E = 0 ok, 1 not an integer or not finite, 2 out of range
  ton A E R                  f64 -> Baysick number -> f64: E = 1 for inf/NaN (R = 0); -0 gives +0
NaN results follow DESIGN.md 2.8 ("NaN bits", arm64 with FPCR.DN = 0): if an operand of add,
sub, mul, div, sqrt, fmod or mod is a NaN, the result is the first NaN operand (A, then B) with
its quiet bit (bit 51) set, sign and payload kept; otherwise an invalid operation (inf - inf,
0 * inf, 0 / 0, inf / inf, sqrt of a negative number, fmod of an infinite A or by a zero B, mod
of an infinite A) gives the default NaN #7FF8000000000000. neg flips the sign bit of any
pattern, and mod with B = 0 returns A unchanged, a NaN A included (LANGUAGE.md 6.6). Folding has
no guards any more (DESIGN.md 2.8: every operation folds), so there are no grd vectors.

limb.txt (i64 two's-complement patterns):
  add|sub|mul A B R V        R = result mod 2^64, V = 1 if the exact result is outside i64
  neg A R V
  div|mod A B R E            floored idiv / % (LANGUAGE.md 6.5, 6.6); E = 1 overflow
                             (idiv(-2^63, -1), R = -2^63), 2 division by zero (R = 0)
  cmp A B C                  signed, C = -1, 0, 1
  int LIT R E                int_lit (LANGUAGE.md 3.4): E = 0 ok, 1 the value 2^63, 2 too large,
                             3 not an int_lit (R = 0 for E >= 2)
  fmt A S                    the i field of DESIGN.md 3.1
  rd S R E                   reading an i field as DESIGN.md 3.1 writes it (decimal when
                             -10^9 < v < 10^9, else # and 16 hex): E = 1 malformed (R = 0)
  rf S R E                   reading an f field (# and 16 upper-case hex): E = 1 malformed
  ton A E R K                i64 -> Baysick number -> i64: E = 1 if |v| > 2^53 (R = 0); K = 0

The expected results come from the definitions, computed exactly with Python integers and
fractions.Fraction; every IEEE result Python's own float arithmetic can produce (no exception)
is cross-checked against it bit for bit (NaN: any NaN), and the generator stops on a mismatch.
"""

import math
import os
import random
import re
import struct
from fractions import Fraction

HERE = os.path.dirname(os.path.abspath(__file__))
NAN = 0x7FF8000000000000
QUIET = 1 << 51
INF = 0x7FF0000000000000
SIGN = 1 << 63
M64 = (1 << 64) - 1


# ---------------------------------------------------------------- binary64 from the definition

def cls(b):
    e = (b >> 52) & 0x7FF
    f = b & ((1 << 52) - 1)
    if e == 0x7FF:
        return 4 if f else 3
    if e == 0:
        return 1 if f else 0
    return 2


def sgn(b):
    return b >> 63


def val(b):
    """Exact value of a finite pattern."""
    e = (b >> 52) & 0x7FF
    f = b & ((1 << 52) - 1)
    m = f if e == 0 else f + (1 << 52)
    x = Fraction(m) * Fraction(2) ** ((e if e else 1) - 1075)
    return -x if sgn(b) else x


def rnd(x, neg_zero=False):
    """Nearest binary64 to the Fraction x, ties to even; a zero x gives -0 if neg_zero."""
    s = SIGN if (x < 0 or (x == 0 and neg_zero)) else 0
    a = abs(x)
    if a == 0:
        return s
    n, d = a.numerator, a.denominator
    e = n.bit_length() - d.bit_length()
    if Fraction(2) ** e > a:
        e -= 1
    last = max(e - 52, -1074)
    sc = a / Fraction(2) ** last
    m = sc.numerator // sc.denominator
    r = sc - m
    if r > Fraction(1, 2) or (r == Fraction(1, 2) and m % 2):
        m += 1
    bits = ((last + 1074) << 52) + m
    if bits >= INF:
        bits = INF
    return s | bits


def nanop(a, b=None):
    """The propagated NaN of DESIGN.md 2.8: the first NaN operand, quieted; None if neither."""
    if cls(a) == 4:
        return a | QUIET
    if b is not None and cls(b) == 4:
        return b | QUIET
    return None


def f_add(a, b):
    n = nanop(a, b)
    if n is not None:
        return n
    if cls(a) == 3 or cls(b) == 3:
        if cls(a) == 3 and cls(b) == 3:
            return a if sgn(a) == sgn(b) else NAN
        return a if cls(a) == 3 else b
    x = val(a) + val(b)
    if x == 0:
        both_neg_zero = cls(a) == 0 and cls(b) == 0 and sgn(a) and sgn(b)
        return SIGN if both_neg_zero else 0
    return rnd(x)


def f_neg(a):
    return a ^ SIGN


def f_sub(a, b):
    n = nanop(a, b)  # before the sign flip: a NaN b propagates with its own sign
    if n is not None:
        return n
    return f_add(a, f_neg(b))


def f_mul(a, b):
    s = sgn(a) ^ sgn(b)
    n = nanop(a, b)
    if n is not None:
        return n
    if cls(a) == 3 or cls(b) == 3:
        if cls(a) == 0 or cls(b) == 0:
            return NAN
        return INF | (s << 63)
    return rnd(val(a) * val(b), neg_zero=bool(s))


def f_div(a, b):
    s = sgn(a) ^ sgn(b)
    ka, kb = cls(a), cls(b)
    n = nanop(a, b)
    if n is not None:
        return n
    if ka == 3:
        return NAN if kb == 3 else INF | (s << 63)
    if kb == 3:
        return s << 63
    if kb == 0:
        return NAN if ka == 0 else INF | (s << 63)
    return rnd(val(a) / val(b), neg_zero=bool(s))


def f_sqrt(a):
    k = cls(a)
    if k == 4:
        return a | QUIET
    if k == 0:
        return a
    if sgn(a):
        return NAN
    if k == 3:
        return INF
    x = val(a)
    # floor(sqrt(x * 4^j)) with at least 56 bits, plus a sticky half for an inexact root
    j = 0
    while True:
        n = x * Fraction(4) ** j
        if n.denominator == 1 and n.numerator.bit_length() >= 112:
            break
        j += 1
    n = n.numerator
    q = math.isqrt(n)
    r = Fraction(2 * q + (1 if q * q != n else 0), 2) / Fraction(2) ** j
    return rnd(r)


def f_fmod(a, b):
    ka, kb = cls(a), cls(b)
    n = nanop(a, b)
    if n is not None:
        return n
    if ka == 3 or kb == 0:
        return NAN
    if kb == 3 or ka == 0:
        return a
    x, y = val(a), abs(val(b))
    q = abs(x) / y
    t = q.numerator // q.denominator  # trunc(|a| / |b|)
    r = abs(x) - t * y
    return rnd(-r if x < 0 else r, neg_zero=bool(sgn(a)))


def f_mod(a, b):
    ka, kb = cls(a), cls(b)
    if kb == 0:
        return a
    n = nanop(a, b)
    if n is not None:
        return n
    if ka == 3:
        return NAN
    r = f_fmod(a, b)
    if r & ~SIGN and sgn(r) != sgn(b):
        r = f_add(r, b)
    return r


def f_cmp(a, b):
    if cls(a) == 4 or cls(b) == 4:
        return 2
    def key(z):
        if cls(z) == 3:
            return (1 if not sgn(z) else -1, 0)
        return (0, val(z))
    ka, kb = key(a), key(b)
    return (ka > kb) - (ka < kb)


def f_fri(i):
    v = i - (1 << 64) if i >> 63 else i
    r = rnd(Fraction(v))
    return r, (0 if val(r) == v else 1)


def f_toi(a):
    if cls(a) >= 3:
        return 0, 1
    x = val(a)
    if x.denominator != 1:
        return 0, 1
    v = x.numerator
    if v < -(1 << 63) or v > (1 << 63) - 1:
        return 0, 2
    return v & M64, 0


def f_ton(a):
    if cls(a) >= 3:
        return 1, 0
    return 0, (0 if cls(a) == 0 else a)


def expo(b):
    """e with 2^e <= |x| < 2^(e+1) for finite nonzero x."""
    x = abs(val(b))
    n, d = x.numerator, x.denominator
    e = n.bit_length() - d.bit_length()
    if Fraction(2) ** e > x:
        e -= 1
    return e


# ---------------------------------------------------------------- cross-checks with host floats

def tof(b):
    return struct.unpack('<d', struct.pack('<Q', b))[0]


def tob(x):
    return struct.unpack('<Q', struct.pack('<d', x))[0]


def same(bits, x):
    if math.isnan(x):
        return cls(bits) == 4  # any NaN: the host's NaN bits are not the oracle (DESIGN.md 2.8)
    return tob(x) == bits


def check(op, a, b, r):
    fa, fb = tof(a), tof(b)
    try:
        if op == 'add':
            h = fa + fb
        elif op == 'sub':
            h = fa - fb
        elif op == 'mul':
            h = fa * fb
        elif op == 'div':
            h = fa / fb
        elif op == 'sqrt':
            h = math.sqrt(fa)
        elif op == 'fmod':
            h = math.fmod(fa, fb)
        elif op == 'mod':
            h = fa % fb
            if h == 0 or math.isnan(h):
                return  # Python gives zeros the sign of b; Sea keeps fmod's
        else:
            return
    except (ZeroDivisionError, ValueError):
        return
    if not same(r, h):
        raise SystemExit('oracle disagrees with host for %s %016X %016X: %016X vs %r'
                         % (op, a, b, r, h))


# ---------------------------------------------------------------- operands

def pat(x):
    return tob(x)


SPECIALS = [0, SIGN, 1, SIGN | 1, 0x000FFFFFFFFFFFFF, 0x0010000000000000, SIGN | 0x0010000000000000,
            pat(1.0), pat(-1.0), pat(2.0), pat(0.5), pat(3.0), pat(-3.0), pat(0.1), pat(10.0),
            pat(1.5), pat(-2.5), 0x7FEFFFFFFFFFFFFF, SIGN | 0x7FEFFFFFFFFFFFFF, 0x7FE0000000000000,
            INF, SIGN | INF, NAN, 0x7FF0000000000001, 0xFFF8000000000000, 0x7FF4000000000123,
            0xFFF0000000000005, 0x7FFFFFFFFFFFFFFF, pat(2.0 ** 53),
            pat(2.0 ** 63), pat(-(2.0 ** 63)), pat(1e300), pat(1e-300), pat(4.0), pat(6.0)]


def rand_pat(r):
    k = r.random()
    if k < 0.15:
        b = r.randrange(1, 1 << 52)
    elif k < 0.25:
        b = r.randrange(0x7FC0000000000000, 0x7FF0000000000000)
    elif k < 0.35:
        b = r.randrange(0x0010000000000000, 0x0040000000000000)
    elif k < 0.55:
        b = pat(float(r.randrange(-10 ** 6, 10 ** 6)) / r.choice([1, 2, 4, 8, 3, 10]))
        return b
    else:
        b = r.randrange(0x3C00000000000000, 0x4400000000000000)
    return b | (SIGN if r.random() < 0.4 else 0)


def tie_pairs(r):
    """Operand pairs whose exact sum or product lies halfway between two doubles."""
    out = []
    for _ in range(40):  # products of two odd 27-bit significands with 54 bits
        while True:
            m1 = r.randrange(1 << 26, 1 << 27) | 1
            m2 = r.randrange(1 << 26, 1 << 27) | 1
            if (m1 * m2).bit_length() == 54:
                break
        e1, e2 = r.randrange(-60, 60), r.randrange(-60, 60)
        out.append(('mul', pat(m1 * 2.0 ** e1), pat(m2 * 2.0 ** e2)))
    for _ in range(30):  # products that land halfway in the subnormal range
        m1 = r.randrange(1, 1 << 20) | 1
        out.append(('mul', pat(m1 * 2.0 ** -1074), pat(0.5)))
        out.append(('mul', pat(m1 * 2.0 ** -1060), pat(2.0 ** -15)))
    for _ in range(40):  # a + half an ulp of a
        m = r.randrange(1 << 52, 1 << 53)
        e = r.randrange(-80, 80)
        a = m * 2.0 ** e
        out.append(('add', pat(a), pat(2.0 ** (e - 1))))
        out.append(('add', pat(-a), pat(-(2.0 ** (e - 1)))))
        out.append(('sub', pat(a), pat(2.0 ** (e - 1))))
    for _ in range(30):  # cancellation into subnormals
        m = r.randrange(1 << 52, 1 << 53)
        a = m * 2.0 ** -1074 * 2 ** 2
        out.append(('sub', pat(a), pat(a + 2.0 ** -1072 * r.randrange(1, 9))))
    out.append(('add', pat(1.0), pat(2.0 ** -53)))
    out.append(('add', pat(1.0 + 2.0 ** -52), pat(2.0 ** -53)))
    out.append(('mul', pat(2.0 ** -1074), pat(0.5)))
    out.append(('mul', pat(3 * 2.0 ** -1074), pat(0.5)))
    out.append(('div', pat(2.0 ** -1074), pat(2.0)))
    out.append(('div', pat(1.0), pat(3.0)))
    out.append(('div', pat(1e308), pat(1e-308)))
    out.append(('mul', pat(1e308), pat(10.0)))
    out.append(('sub', pat(1.0), pat(1.0)))
    out.append(('sub', SIGN, SIGN))
    out.append(('add', SIGN, SIGN))
    out.append(('add', SIGN, 0))
    out.append(('sub', SIGN, 0))
    out.append(('sub', pat(-1.0), pat(-1.0)))
    out.append(('fmod', pat(1e300), pat(3.0)))
    out.append(('fmod', pat(1e308), pat(2.0 ** -1074)))
    out.append(('fmod', pat(-6.0), pat(3.0)))
    out.append(('mod', pat(-6.0), pat(3.0)))
    out.append(('mod', pat(-1.0), INF))
    out.append(('mod', pat(1.0), SIGN | INF))
    out.append(('mod', pat(-5.5), pat(2.0)))
    out.append(('mod', pat(5.5), pat(-2.0)))
    out.append(('mod', pat(6.0), pat(4.0)))
    out.append(('mod', pat(1e-310), pat(-3.0)))
    return out


def gen_f64(r):
    lines = []

    def emit(op, a, b=None):
        if op == 'add':
            res = f_add(a, b)
        elif op == 'sub':
            res = f_sub(a, b)
        elif op == 'mul':
            res = f_mul(a, b)
        elif op == 'div':
            res = f_div(a, b)
        elif op == 'fmod':
            res = f_fmod(a, b)
        elif op == 'mod':
            res = f_mod(a, b)
        elif op == 'sqrt':
            res = f_sqrt(a)
        elif op == 'neg':
            res = f_neg(a)
        elif op == 'cmp':
            c = f_cmp(a, b)
            fa, fb = tof(a), tof(b)
            host = 2 if (math.isnan(fa) or math.isnan(fb)) else (fa > fb) - (fa < fb)
            assert host == c, (a, b)
            lines.append('cmp #%016X #%016X %d' % (a, b, c))
            return
        if op in ('sqrt', 'neg'):
            check(op, a, 0, res)
            lines.append('%s #%016X #%016X' % (op, a, res))
        else:
            check(op, a, b, res)
            lines.append('%s #%016X #%016X #%016X' % (op, a, b, res))

    binops = ['add', 'sub', 'mul', 'div', 'fmod', 'mod', 'cmp']
    for op in binops:
        for a in SPECIALS:
            for b in SPECIALS:
                emit(op, a, b)
    for op in binops:
        for _ in range(250):
            a = rand_pat(r)
            b = rand_pat(r) if r.random() < 0.7 else (a + r.randrange(-3, 4)) & M64
            emit(op, a, b)
    for op, a, b in tie_pairs(r):
        emit(op, a, b)
    for a in SPECIALS + [rand_pat(r) for _ in range(300)] + [pat(float(k)) for k in range(2, 50)]:
        emit('sqrt', a)
        emit('neg', a)
        k = cls(a)
        lines.append('cls #%016X %d %d' % (a, k, sgn(a)))
        rr, e = f_toi(a)
        x = tof(a)
        if math.isfinite(x) and x.is_integer() and -2.0 ** 63 <= x < 2.0 ** 63:
            assert e == 0 and rr == int(x) & M64
        else:
            assert e != 0
        lines.append('toi #%016X #%016X %d' % (a, rr, e))
        e, rr = f_ton(a)
        lines.append('ton #%016X %d #%016X' % (a, e, rr))
    # toi edges
    for x in [2.0 ** 63, -(2.0 ** 63), 2.0 ** 62 * 1.5, -(2.0 ** 63) * (1 - 2.0 ** -53), 0.5, -0.5,
              4503599627370497.0, 2.0 ** 52 + 0.5, 1e19, -1e19, 2.0 ** 64]:
        rr, e = f_toi(pat(x))
        lines.append('toi #%016X #%016X %d' % (pat(x), rr, e))
    # i64 -> f64
    ints = [0, 1, -1, 2 ** 53, 2 ** 53 + 1, 2 ** 53 + 2, 2 ** 53 + 3, 2 ** 54 + 2, 2 ** 54 + 6,
            -(2 ** 53 + 1), 2 ** 63 - 1, -(2 ** 63), -(2 ** 63) + 1, 2 ** 62 + 2 ** 9, 2 ** 62 + 2 ** 9 + 1,
            123456789, -987654321, 2 ** 60 - 1]
    ints += [r.randrange(-(2 ** 63), 2 ** 63) for _ in range(150)]
    ints += [r.randrange(-(2 ** 55), 2 ** 55) for _ in range(100)]
    for v in ints:
        i = v & M64
        res, x = f_fri(i)
        assert tob(float(v)) == res
        lines.append('fri #%016X #%016X %d' % (i, res, x))
    return lines


# ---------------------------------------------------------------- i64

def s64(u):
    return u - (1 << 64) if u >> 63 else u


def fmt_i(u):
    v = s64(u)
    if -10 ** 9 < v < 10 ** 9:
        return str(v)
    return '#%016X' % u


INT_DEC = re.compile(r'^[0-9][0-9_]*$')
INT_HEX = re.compile(r'^0x[0-9a-fA-F][0-9a-fA-F_]*$')


def int_lit(s):
    if s.endswith('_'):
        return 0, 3
    if INT_HEX.match(s):
        v = int(s[2:].replace('_', ''), 16)
    elif INT_DEC.match(s):
        v = int(s.replace('_', ''))
    else:
        return 0, 3
    if v <= 2 ** 63 - 1:
        return v, 0
    if v == 2 ** 63:
        return v, 1
    return 0, 2


def rf(s):
    if re.fullmatch(r'#[0-9A-F]{16}', s):
        return int(s[1:], 16), 0
    return 0, 1


def rd(s):
    if s.startswith('#'):
        v, e = rf(s)
        if e or -10 ** 9 < s64(v) < 10 ** 9:
            return 0, 1  # only the canonical form: small values are decimal
        return v, 0
    if re.fullmatch(r'-?(0|[1-9][0-9]{0,8})', s) and s != '-0':
        return int(s) & M64, 0
    return 0, 1


def gen_limb(r):
    lines = []
    sp = [0, 1, -1, 2, -2, 3, -7, 2 ** 15, 2 ** 16, 2 ** 31, 2 ** 32 - 1, 2 ** 32, -(2 ** 32), 2 ** 53,
          2 ** 62, -(2 ** 62), 2 ** 63 - 1, -(2 ** 63), -(2 ** 63) + 1, 3037000499, 3037000500,
          -3037000500, 4294967296, 10 ** 9, -(10 ** 9)]
    vals = [v & M64 for v in sp]
    rv = [r.randrange(0, 1 << 64) for _ in range(60)] + \
         [r.randrange(-(2 ** 33), 2 ** 33) & M64 for _ in range(60)]

    def ok(v):
        return -(2 ** 63) <= v <= 2 ** 63 - 1

    def emit(op, a, b):
        x, y = s64(a), s64(b)
        if op in ('add', 'sub', 'mul'):
            z = x + y if op == 'add' else x - y if op == 'sub' else x * y
            lines.append('%s #%016X #%016X #%016X %d' % (op, a, b, z & M64, 0 if ok(z) else 1))
        elif op in ('div', 'mod'):
            if y == 0:
                lines.append('%s #%016X #%016X #%016X 2' % (op, a, b, 0))
                return
            z = x // y if op == 'div' else x % y
            lines.append('%s #%016X #%016X #%016X %d' % (op, a, b, z & M64, 0 if ok(z) else 1))
        else:
            lines.append('cmp #%016X #%016X %d' % (a, b, (x > y) - (x < y)))

    for op in ('add', 'sub', 'mul', 'div', 'mod', 'cmp'):
        for a in vals:
            for b in vals:
                emit(op, a, b)
        for _ in range(200):
            emit(op, r.choice(rv + vals), r.choice(rv + vals))
    for a in vals + rv:
        z = -s64(a)
        lines.append('neg #%016X #%016X %d' % (a, z & M64, 0 if ok(z) else 1))
        lines.append('fmt #%016X %s' % (a, fmt_i(a)))
        e = 0 if abs(s64(a)) <= 2 ** 53 else 1
        lines.append('ton #%016X %d #%016X 0' % (a, e, a if e == 0 else 0))
    for v in [999999999, -999999999, 10 ** 9, -(10 ** 9), 10 ** 9 + 1, 2 ** 53, 2 ** 53 + 1, -(2 ** 53),
              -(2 ** 53) - 1, 2 ** 52 + 12345]:
        u = v & M64
        lines.append('fmt #%016X %s' % (u, fmt_i(u)))
        e = 0 if abs(v) <= 2 ** 53 else 1
        lines.append('ton #%016X %d #%016X 0' % (u, e, u if e == 0 else 0))
    lits = ['0', '7', '00012', '1_000_000', '9223372036854775807', '9223372036854775808',
            '9223372036854775809', '18446744073709551615', '18446744073709551616',
            '99999999999999999999999999', '0x0', '0x7FFFFFFFFFFFFFFF', '0x7fff_ffff_ffff_ffff',
            '0x8000000000000000', '0x8000000000000001', '0xFFFFFFFFFFFFFFFF', '0x1_0000_0000_0000_0000',
            '0x00ff', '0xDeadBeef', '_1', '1_', '0x_1', '0x', '0X10', '12a', '1.0', '0x1g', '1__2',
            '1' * 1000, '0' * 900 + '9223372036854775807', '0x' + '0' * 300 + '1', '-1', '+1', 'x']
    lits += [str(r.randrange(0, 2 ** 64)) for _ in range(40)] + \
            ['0x%X' % r.randrange(0, 2 ** 64) for _ in range(40)]
    for s in lits:
        v, e = int_lit(s)
        lines.append('int %s #%016X %d' % (s, v if e < 2 else 0, e))
    for s in ['0', '-1', '999999999', '-999999999', '1000000000', '#FFFFFFFFC4653600', '#ffffffffc4653600',
              '-0', '01', '#123', '+1', '1a', '#7FF8000000000000', '#0000000000000000', '-', '#',
              '12345678', '#FFFFFFFFFFFFFFFFF', '#FFFFFFFFFFFFFFF', '#0000000000000005',
              '#FFFFFFFFFFFFFFFF', '#000000003B9AC9FF', '#000000003B9ACA00', '#FFFFFFFFC4653601',
              '#8000000000000000', '#7FFFFFFFFFFFFFFF', '#3FF0000000000000']:
        v, e = rd(s)
        lines.append('rd %s #%016X %d' % (s, v, e))
        v, e = rf(s)
        lines.append('rf %s #%016X %d' % (s, v, e))
    return lines


def main():
    r = random.Random(20261020)
    f = gen_f64(r)
    with open(os.path.join(HERE, 'f64emu.txt'), 'w') as fo:
        fo.write('\n'.join(f) + '\n')
    l = gen_limb(random.Random(20261021))  # its own stream: f64 vector changes leave limb.txt alone
    with open(os.path.join(HERE, 'limb.txt'), 'w') as fo:
        fo.write('\n'.join(l) + '\n')
    print('f64emu.txt: %d vectors, limb.txt: %d vectors' % (len(f), len(l)))


if __name__ == '__main__':
    main()
