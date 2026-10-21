# tests/vectors/math_vectors.py -- writes the elementary-function vectors (Sea DESIGN.md 4.10.6).
#
# usage: uv run --with mpmath python tests/vectors/math_vectors.py FN [FN...]
#        uv run --with mpmath python tests/vectors/math_vectors.py --accuracy N FN
#   FN is one of log exp sin cos pow hypot.
#
# Writes tests/math/<fn>.vec: one case per line, the argument patterns and the expected result
# pattern as 16 upper-case hexadecimal digits each, separated by one space, then LF; at most
# 10 000 cases. `pow` also writes tests/vectors/fepow.txt (`pow #X #Y #R` lines) for the f64emu
# harness. The expected bits come from the bit-exact model (math_model.py, the oracle for
# identity). Before a case is written it is checked with mpmath (the oracle for accuracy): the
# model's result is within 1 ulp of the exact value (ulp of the exact value's binade, 2^-1074 below
# 2^-1022; an exact value >= 2^1024 (1 - 2^-54) must give infinity), exactly representable
# results are exact, and special inputs give the C99 Annex F value. Any failure: status 1 and
# nothing written. The cases are deterministic (fixed seeds).
#
# --accuracy N measures instead the model's maximum error on N seeded random cases and on the
# hard-case set of FN, and writes nothing (DESIGN.md 4.10.7); never part of `make test`.
import os
import random
import sys
import time

import mpmath as mp

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import math_model as M  # noqa: E402

M64 = (1 << 64) - 1

HERE = os.path.dirname(os.path.abspath(__file__))
OUTDIR = os.path.join(HERE, '..', 'math')
MAXCASES = 10000
NANB = 0x7FF8000000000000
INFB = 0x7FF0000000000000
NINFB = 0xFFF0000000000000
PREC = 320
TWO = mp.mpf(2)
bits, f64 = M.bits, M.f64


# ---- reference values -----------------------------------------------------------------------
def exact(fn, args):
    """the exact value as an mpf (at least PREC bits), or 'nan' for a real-valued NaN result"""
    with mp.workprec(PREC):
        a = [mp.mpf(f64(v)) for v in args]
        if fn == 'exp':
            return mp.exp(a[0])
        if fn == 'log':
            return mp.log(a[0])
        if fn in ('sin', 'cos'):
            with mp.workprec(PREC + 1100):
                return +(mp.sin(a[0]) if fn == 'sin' else mp.cos(a[0]))
        if fn == 'pow':
            x, y = a
            if x < 0:
                if y != mp.floor(y):
                    return 'nan'
                v = mp.power(-x, y)
                return -v if int(y) % 2 else v
            with mp.workprec(PREC + 100):
                return +mp.power(x, y)
        if fn == 'hypot':
            return mp.sqrt(a[0] * a[0] + a[1] * a[1])
    raise ValueError(fn)


def ulp_of(v):
    av = abs(v)
    if av < TWO ** -1022:
        return TWO ** -1074
    e = int(mp.floor(mp.log(av, 2)))
    if TWO ** e > av:
        e -= 1
    if TWO ** (e + 1) <= av:
        e += 1
    return TWO ** (e - 52)


def ulp_err(got_bits, ex):
    """error in ulps of the exact value (infinity read as 2^1024 with DBL_MAX's ulp)"""
    with mp.workprec(PREC + 20):
        g = f64(got_bits)
        if g != g:
            return float('inf')
        big = TWO ** 1024 * (1 - TWO ** -54)
        if g in (float('inf'), float('-inf')):
            if abs(ex) >= big and (ex > 0) == (g > 0):
                return 0.0
            gv = TWO ** 1024 if g > 0 else -(TWO ** 1024)
            return float(abs(gv - ex) / TWO ** 971)
        if abs(ex) >= big:
            return float('inf')
        u = TWO ** 971 if abs(ex) >= TWO ** 1024 else ulp_of(ex)
        return float(abs(mp.mpf(g) - ex) / u)


# ---- C99 Annex F special values (independent of the model) -----------------------------------
def is_nan(b):
    return (b & 0x7FF0000000000000) == 0x7FF0000000000000 and (b & 0x000FFFFFFFFFFFFF) != 0


def is_inf(b):
    return (b & 0x7FFFFFFFFFFFFFFF) == INFB


def is_zero(b):
    return (b & 0x7FFFFFFFFFFFFFFF) == 0


def neg_b(b):
    return b ^ (1 << 63)


def yclass(y):
    """0 not an integer, 1 odd integer, 2 even integer (y finite)"""
    if y != int(y):
        return 0
    return 1 if int(y) % 2 else 2


def annexf(fn, args):
    """the expected pattern for a special input, or None for an ordinary one"""
    x = args[0]
    fx = f64(x)
    if fn == 'exp':
        if is_nan(x): return NANB
        if x == INFB: return INFB
        if x == NINFB: return 0
        if is_zero(x): return 0x3FF0000000000000
        return None
    if fn == 'log':
        if is_nan(x): return NANB
        if is_zero(x): return NINFB
        if x >> 63: return NANB
        if x == INFB: return INFB
        if x == 0x3FF0000000000000: return 0
        return None
    if fn in ('sin', 'cos'):
        if is_nan(x) or is_inf(x): return NANB
        if is_zero(x): return x if fn == 'sin' else 0x3FF0000000000000
        return None
    y = args[1]
    fy = f64(y)
    if fn == 'hypot':
        if is_inf(x) or is_inf(y): return INFB
        if is_nan(x) or is_nan(y): return NANB
        if is_zero(x) and is_zero(y): return 0
        if is_zero(y): return x & 0x7FFFFFFFFFFFFFFF
        if is_zero(x): return y & 0x7FFFFFFFFFFFFFFF
        return None
    # pow, C99 F.9.4.4
    if is_zero(y): return 0x3FF0000000000000
    if x == 0x3FF0000000000000: return 0x3FF0000000000000
    if is_nan(x) or is_nan(y): return NANB
    if is_inf(y):
        ax = abs(fx)
        if ax == 1.0: return 0x3FF0000000000000
        if (ax < 1.0) == (fy < 0): return INFB
        return 0
    yc = yclass(fy)
    if is_zero(x):
        if fy < 0:
            return NINFB if (yc == 1 and x >> 63) else INFB
        return x if yc == 1 else 0
    if is_inf(x):
        if x == INFB:
            return 0 if fy < 0 else INFB
        if fy < 0:
            return (1 << 63) if yc == 1 else 0
        return NINFB if yc == 1 else INFB
    if fx < 0 and yc == 0: return NANB
    return None


# ---- one case ---------------------------------------------------------------------------------
def check_case(fn, args):
    """returns (result bits, error in ulps or None for a special case); raises on a failure"""
    got = M.eval_bits(fn, args)
    sp = annexf(fn, args)
    if sp is not None:
        if got != sp:
            raise AssertionError('%s(%s): special value #%016X, Annex F #%016X' % (
                fn, ' '.join('%016X' % a for a in args), got, sp))
        return got, None
    ex = exact(fn, args)
    if isinstance(ex, str):
        if got != NANB:
            raise AssertionError('%s(%s): expected NaN, got #%016X' % (fn, ' '.join('%016X' % a for a in args), got))
        return got, None
    with mp.workprec(PREC):
        if ex != 0 and abs(ex) < TWO ** 1024:
            rep = bits(float(ex))   # nearest double (overflow impossible here)
            if mp.mpf(f64(rep)) == ex and got != rep:
                raise AssertionError('%s(%s): exact result #%016X, got #%016X' % (
                    fn, ' '.join('%016X' % a for a in args), rep, got))
    err = ulp_err(got, ex)
    if not err <= 1.0:
        raise AssertionError('%s(%s): error %.4f ulp (got #%016X)' % (
            fn, ' '.join('%016X' % a for a in args), err, got))
    return got, err


# ---- case sets --------------------------------------------------------------------------------
def rd(rng, emin, emax, sign=True):
    e = max(rng.randint(emin, emax), -1022)       # an exponent below -1022 is the lowest binade
    b = ((e + 1023) << 52) | rng.getrandbits(52)
    if sign and rng.random() < 0.5:
        b |= 1 << 63
    return b


def sub(rng):
    return rng.randint(1, (1 << 52) - 1)


SPECIAL_X = [0, 1 << 63, INFB, NINFB, NANB, 0xFFF8000000000000, 0x7FF0000000000001,
             0x3FF0000000000000, 0xBFF0000000000000, 1, 0x8000000000000001, 0x000FFFFFFFFFFFFF,
             0x0010000000000000, 0x7FEFFFFFFFFFFFFF, 0xFFEFFFFFFFFFFFFF, 0x3FE0000000000000,
             0xBFE0000000000000, 0x4000000000000000, 0xC000000000000000]


def trig_hard():
    out = []
    with mp.workprec(3000):
        pio2 = mp.pi / 2
        for e in range(-1, 1024):
            xx = pio2 * mp.mpf(2) ** (52 - e)
            h0, h1 = 0, 1
            for _ in range(3000):
                ai = int(mp.floor(xx))
                h0, h1 = h1, ai * h1 + h0
                if h1 >= (1 << 53):
                    break
                if h1 >= (1 << 52):
                    out.append(bits(h1 * 2.0 ** (e - 52)))
                fr = xx - ai
                if fr == 0:
                    break
                xx = 1 / fr
    out.append(bits(6381956970095103 * 2.0 ** 797))
    res = []
    for v in out:
        res += [v - 1, v, v + 1]
    return res


def cases(fn):
    rng = random.Random({'log': 101, 'exp': 102, 'sin': 103, 'cos': 104, 'pow': 105, 'hypot': 106}[fn])
    special, exactc, hard, rand = [], [], [], []
    if fn in ('log', 'exp', 'sin', 'cos'):
        special = [(x,) for x in SPECIAL_X]
    if fn == 'log':
        exactc = [(0x3FF0000000000000,)] + [(bits(2.0 ** k),) for k in range(-1074, 1024)]
        for k in range(1, 1001):
            hard += [(0x3FF0000000000000 + k,), (0x3FF0000000000000 - k,)]
        for i in range(129):
            b = 0x3FE5F00000000000 + (i << 45)
            hard += [(b + d,) for d in (-1, 0, 1)]
        hard += [(sub(rng),) for _ in range(300)]

        def r():
            c = rng.random()
            if c < 0.5: return rd(rng, -1022, 1023, False)
            if c < 0.8: return bits(1.0 + rng.uniform(-1, 1) * 2.0 ** rng.randint(-53, -1))
            return bits(rng.uniform(0.5, 2.0))
    elif fn == 'exp':
        exactc = [(0,), (1 << 63,)]
        for c in (0x40862E42FEFA39EF, 0xC0874910D52D3051, 0xC0874385446D71C3, 0xC086232BDD7ABCD2):
            hard += [(c + d,) for d in range(-400, 401)]
        for k in range(-1080, 1030, 2):
            hard.append((bits(k * 0.6931471805599453),))
        hard += [(bits(rng.uniform(512, 709.8)),) for _ in range(200)]
        hard += [(bits(rng.uniform(-745.2, -512)),) for _ in range(300)]
        hard += [(bits(2.0 ** -54) + d,) for d in (-1, 0, 1)]

        def r():
            c = rng.random()
            if c < 0.5: return bits(rng.uniform(-745.2, 709.8))
            if c < 0.8: return rd(rng, -60, 9)
            return bits(rng.uniform(-1, 1))
    elif fn in ('sin', 'cos'):
        exactc = []
        hard = [(v,) for v in trig_hard()]
        for d in range(-50, 51):
            hard.append((0x4160000000000000 + d,))
            hard.append((0x3E40000000000000 + d,))
        for j in range(52):
            for q in range(4):
                hard.append((bits((j + 0.5) / 64 + q * 1.5707963267948966),))

        def r():
            c = rng.random()
            if c < 0.4: return bits(rng.uniform(-10, 10))
            if c < 0.7: return rd(rng, -27, 22)
            if c < 0.85: return rd(rng, 23, 1023)
            k = rng.randint(1, 1 << 20)
            return bits(k * 1.5707963267948966) + rng.randint(-4, 4)
    elif fn == 'hypot':
        sv = [0, 1 << 63, INFB, NINFB, NANB, 0x3FF0000000000000, 1, 0x7FEFFFFFFFFFFFFF]
        special = [(a, b) for a in sv for b in sv]
        for e in range(-1074, 1022, 3):
            a = 3 * 2.0 ** (e - 2) if e > -1072 else 3 * 2.0 ** -1074
            b = 4 * 2.0 ** (e - 2) if e > -1072 else 4 * 2.0 ** -1074
            exactc.append((bits(a), bits(b)))
        for t in ((5, 12), (8, 15), (7, 24), (20, 21), (9, 40)):
            exactc.append((bits(float(t[0])), bits(float(t[1]))))
        for c in (0x5F30000000000000, 0x20B0000000000000):
            for d in range(-20, 21):
                hard.append((c + d, c + d - (rng.randint(0, 1 << 40))))
        for _ in range(800):
            hard.append((sub(rng), sub(rng)))
            hard.append((rd(rng, 1015, 1023), rd(rng, 1015, 1023)))
            e = rng.randint(-1000, 1000)
            hard.append((rd(rng, e, e), bits(f64(rd(rng, e, e, False)) * 2.0 ** -rng.randint(20, 70))))

        def r():
            c = rng.random()
            if c < 0.4: return (rd(rng, -1022, 1023), rd(rng, -1022, 1023))
            e = rng.randint(-1022, 1020)
            return (rd(rng, e, e), rd(rng, e - rng.randint(0, 30), e))
    elif fn == 'pow':
        px = [0, 1 << 63, INFB, NINFB, NANB, 0x3FF0000000000000, 0xBFF0000000000000,
              0x3FE0000000000000, 0xBFE0000000000000, 0x4000000000000000, 0xC000000000000000,
              1, 0x7FEFFFFFFFFFFFFF]
        py = [0, 1 << 63, INFB, NINFB, NANB, 0x3FF0000000000000, 0xBFF0000000000000,
              0x4000000000000000, 0x4008000000000000, 0xC008000000000000, 0x3FE0000000000000,
              0x3FF8000000000000, 0x4340000000000000, 0x4340000000000001]
        special = [(a, b) for a in px for b in py]
        exactc = [(0x4000000000000000, bits(float(k))) for k in range(-1074, 1024)]
        exactc += [(0x4024000000000000, bits(float(k))) for k in range(0, 23)]
        exactc += [(bits(float(v * v)), 0x3FE0000000000000) for v in range(1, 40)]
        exactc += [(bits(-3.0), bits(float(k))) for k in range(-30, 31) if k != 0]
        for _ in range(250):
            x = bits(1.0 + rng.uniform(-1, 1) * 2.0 ** rng.randint(-53, -10))
            hard.append((x, rd(rng, 40, 62)))
        for _ in range(500):
            x = rng.uniform(1.0001, 1e6)
            t = rng.choice((709.78, -708.39, -745.13, -740.0, 600.0, -600.0))
            y = t / M.math.log(x)
            hard += [(bits(x), bits(y)), (bits(-x), bits(float(int(y))))]
        for _ in range(300):
            hard.append((sub(rng), bits(rng.uniform(-1.3, 1.3))))
        for _ in range(200):
            hard.append((bits(-rng.uniform(0.999, 1.001)), bits(float(2 * rng.randint(0, 1 << 52) + 1))))
        for _ in range(300):
            hard.append((rd(rng, -20, 20), bits(float(rng.randint(-60, 60)))))

        def r():
            c = rng.random()
            if c < 0.4: return (rd(rng, -1022, 1023, False), rd(rng, -20, 10))
            if c < 0.7: return (bits(rng.uniform(0, 10)), bits(rng.uniform(-100, 100)))
            return (bits(rng.uniform(0.5, 2)), bits(rng.uniform(-2000, 2000)))
    if fn in ('log', 'exp', 'sin', 'cos'):
        r1 = r
        r = lambda: (r1(),)  # noqa: E731
    out, seen = [], set()
    groups = {}
    for name, lst in (('special', special), ('exact', exactc), ('hard', hard)):
        for c in lst:
            c = canon(c)
            if c not in seen and len(out) < MAXCASES:
                seen.add(c)
                out.append(c)
                groups[c] = name
    while len(out) < MAXCASES:
        c = canon(r())
        if c not in seen:
            seen.add(c)
            out.append(c)
            groups[c] = 'random'
    return out, groups


def canon(c):
    """a case as a tuple of 64-bit patterns; anything else is a generator bug"""
    for v in c:
        if not (isinstance(v, int) and 0 <= v <= M64):
            raise AssertionError('case %r: not a 64-bit pattern' % (c,))
    return tuple(c)


def hex16(v):
    if not (0 <= v <= M64):
        raise AssertionError('pattern %r outside 64 bits' % v)
    return '%016X' % v


HEXD = set('0123456789ABCDEF')


def check_format(fn, lines, fepow=False):
    """every field exactly 16 upper-case hex digits (fepow: '#' first), right field count"""
    n = M.ARITY['pow'] + 1 if fepow else M.ARITY[fn] + 1
    for k, line in enumerate(lines, 1):
        if not line.endswith('\n') or '\r' in line:
            raise AssertionError('%s line %d: bad line end' % (fn, k))
        f = line[:-1].split(' ')
        if fepow:
            if f[0] != 'pow':
                raise AssertionError('fepow line %d: %r' % (k, line))
            f = f[1:]
            if any(not x.startswith('#') for x in f):
                raise AssertionError('fepow line %d: %r' % (k, line))
            f = [x[1:] for x in f]
        if len(f) != n or any(len(x) != 16 or not set(x) <= HEXD for x in f):
            raise AssertionError('%s line %d: bad format %r' % (fn, k, line))


def check_file(path, fn, fepow=False):
    with open(path) as fh:
        check_format(fn, fh.readlines(), fepow)


def write_fn(fn):
    t0 = time.time()
    cs, groups = cases(fn)
    lines, worst, wc = [], 0.0, None
    for c in cs:
        got, err = check_case(fn, c)
        if err is not None and err > worst:
            worst, wc = err, c
        lines.append(' '.join(hex16(v) for v in c) + ' ' + hex16(got) + '\n')
    check_format(fn, lines)
    os.makedirs(OUTDIR, exist_ok=True)
    with open(os.path.join(OUTDIR, fn + '.vec'), 'w') as f:
        f.writelines(lines)
    cnt = {}
    for c in cs:
        cnt[groups[c]] = cnt.get(groups[c], 0) + 1
    print('%s.vec: %d cases (%s); max error %.4f ulp at %s; %.1fs' % (
        fn, len(cs), ', '.join('%s %d' % kv for kv in sorted(cnt.items())), worst,
        ' '.join('%016X' % v for v in wc), time.time() - t0))
    if fn == 'pow':
        write_fepow(cs, groups, lines)


def write_fepow(cs, groups, lines):
    rng = random.Random(205)
    pick = []
    others = []
    for i, c in enumerate(cs):
        g = groups[c]
        if g == 'special':
            pick.append(i)
        elif g == 'exact':
            if c[0] == 0x4000000000000000:
                k = int(f64(c[1]))
                if k % 16 == 0 or k in (-1074, 1023):
                    pick.append(i)
            else:
                pick.append(i)
        else:
            others.append(i)
    # 500 others: every rare path represented (subnormal x, |ehi| >= 512 results, negative x)
    rare = [i for i in others if (cs[i][0] >> 52) == 0 or (cs[i][0] >> 63)]
    big = [i for i in others if i not in set(rare)]
    chosen = rng.sample(rare, min(100, len(rare)))
    chosen += rng.sample(big, 500 - len(chosen))
    pick = sorted(set(pick) | set(chosen))
    assert len(pick) <= 1500, len(pick)
    out = []
    for i in pick:
        x, y, rr = lines[i].split()
        out.append('pow #%s #%s #%s\n' % (x, y, rr))
    check_format('pow', out, fepow=True)
    with open(os.path.join(HERE, 'fepow.txt'), 'w') as f:
        f.writelines(out)
    print('fepow.txt: %d cases' % len(pick))


def accuracy(fn, n):
    cs, groups = cases(fn)
    hardset = [c for c in cs if groups[c] in ('hard', 'exact')]
    w, wc = 0.0, None
    for c in hardset:
        got, err = check_case(fn, c)
        if err is not None and err > w:
            w, wc = err, c
    print('%s hard: n=%d max %.6f ulp at %s' % (fn, len(hardset), w, ' '.join('%016X' % v for v in wc)))
    rng = random.Random(9000 + n)
    w, wc = 0.0, None
    for _ in range(n):
        if fn in ('log', 'exp', 'sin', 'cos'):
            c = (rng.getrandbits(64) if rng.random() < 0.3 else rd(rng, -60, 60),)
        elif fn == 'pow':
            c = (rd(rng, -60, 60), rd(rng, -10, 6))
        else:
            c = (rd(rng, -1022, 1023), rd(rng, -1022, 1023))
        got, err = check_case(fn, c)
        if err is not None and err > w:
            w, wc = err, c
    print('%s random: n=%d max %.6f ulp at %s' % (fn, n, w, ' '.join('%016X' % v for v in wc)))


def main(argv):
    try:
        if argv[:1] == ['--check-format']:
            for fn in M.FUNCS:
                check_file(os.path.join(OUTDIR, fn + '.vec'), fn)
            check_file(os.path.join(HERE, 'fepow.txt'), 'pow', fepow=True)
            print('math_vectors.py: every .vec and fepow.txt is well formed')
            return 0
        if argv[:1] == ['--accuracy']:
            accuracy(argv[2], int(argv[1]))
            return 0
        if not argv or any(a not in M.FUNCS for a in argv):
            print('usage: math_vectors.py FN... | --accuracy N FN  (FN: log exp sin cos pow hypot)',
                  file=sys.stderr)
            return 2
        for fn in argv:
            write_fn(fn)
    except AssertionError as e:
        print('math_vectors.py: %s' % e, file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
