"""Sub-phase 6b: the vectors and the tests of `%` with an f64 operand (FMOD).

DESIGN.md 6.2 "Phase-6 tests" ("6b, calls", "Runtime tests"), 2.11.2, 4.8 (entry 26 `FMOD`),
lead decision L-cm; LANGUAGE.md 6.5, 6.6, 11.1, 10.9.

Run (never `python3`):

    timeout 120 uv run --no-project python tests/vectors/fmod6_cases.py
        self-checks the model, then writes programs/fmod_{scalar,str,random,array}.{sea,out}
    timeout 120 uv run --no-project python tests/vectors/fmod6_cases.py --emit-asm arm64_macos
    timeout 120 uv run --no-project python tests/vectors/fmod6_cases.py --emit-asm x86_64_linux
        print the vector table as assembler data (the runtime tests' table, below)
    timeout 120 uv run --no-project python tests/vectors/fmod6_cases.py --check-asm FILE
        checks the table between the two marker comments of FILE against this script's vectors
        (exit 0 and "ok", else exit 1 and the first difference)

THE MODEL.  `a % b` for f64 (LANGUAGE.md 6.6), in this order:
  1. b == 0 (either zero): the result is a, bit for bit (so inf % 0 is inf, nan % 0 is a NaN);
  2. else a infinite, or a NaN operand: NaN (the runtime entry returns #7FF8000000000000);
  3. else r = fmod(a, b) -- computed with `math.fmod`, which is the C library's exact `fmod`
     (exact by IEEE 754, the sign of a, a zero keeps a's sign); if r != 0 and the signs of r and b
     differ, r = r + b, rounded once. b = +-inf falls out (`-1 % inf` is inf, `1 % inf` is 1).
It is never computed with Python's `%`, which gives +0.0 for `-6.0 % 3.0` where LANGUAGE.md 6.6
gives -0.0. Self-checks (run on every invocation): `math.fmod` equals the exact rational
remainder a - b*trunc(a/b) (fractions.Fraction) for every finite vector; the adjusted sum equals
the exactly rounded rational r + b; Python's `%` agrees with the model on the value of every
finite result (only the sign of a zero may differ) -- a cross-check, never a source of a byte.

THE TABLE (`--emit-asm TARGET`).  Each vector is three raw 64-bit patterns: the dividend a, the
divisor b and the expected result e (IEEE binary64 bit patterns, so signed zeros and NaN
patterns are exact). A NaN result is always the pattern #7FF8000000000000 (entry FMOD's contract,
DESIGN.md 4.8); a result for b = +-0 is a's own bits, whatever they are (a NaN a with a payload
or a sign comes back unchanged). The text printed is, for arm64_macos (Apple `as`):

    // FMOD6-VECTORS-BEGIN arm64_macos
    // <explanatory comment lines>
        .pushsection __TEXT,__const
        .p2align 3
    Lfmod_vec_table:
        .quad N
        .quad 0x<a>, 0x<b>, 0x<e>        (one line per vector, N lines, 16 hex digits each)
        ...
        .popsection
    // FMOD6-VECTORS-END

and for x86_64_linux (GNU `as`; `#` comments, `.section .rodata`, `.Lfmod_vec_table`):

    # FMOD6-VECTORS-BEGIN x86_64_linux
    ...
    # FMOD6-VECTORS-END

so an assembly test reads: the count N at the table label, then N records of 24 bytes (a at +0,
b at +8, e at +16 of record i, which starts at table + 8 + 24*i). The runtime test loads a and b
into the argument registers (as `sea_fmod`'s f64 arguments), calls the entry, and compares the
bits of the result with e (`fmov x, d0` / `movq %xmm0, %rax`). The MARKER COMMENTS are exactly
the lines `// FMOD6-VECTORS-BEGIN <target>` and `// FMOD6-VECTORS-END` (arm64_macos) and
`# FMOD6-VECTORS-BEGIN <target>` and `# FMOD6-VECTORS-END` (x86_64_linux); `--check-asm FILE`
finds the BEGIN line (which names the target), requires the END line after it, and compares the
text from BEGIN through END, line by line, with what `--emit-asm <target>` prints. Everything
outside the markers is free.

THE TESTS.  The programs read their operands from arrays (a `const` operand pair is folded by
`seaname`, DESIGN.md 2.11.2, and would not reach the runtime): `fmod_scalar` (the special cases,
printed with `%.17g`: -0 for a negative zero, NaN, Inf, -Inf as LANGUAGE.md 11.1 spells them),
`fmod_str` (the same pairs printed with `str()`: -0, nan, inf, -inf as LANGUAGE.md 10.9 spells
them), `fmod_random` (deterministic pseudo-random pairs over the exponent range), `fmod_array`
(element-wise on vectors, matrices, with scalars, with `.col`/`.row` broadcasting, an `i64[]`
operand, empty and fixed-size arrays). Every expected byte is computed here from the model above
and the exact printf oracle of tests/vectors/progfmt.py, never from a run of the compiler.
"""

import math
import os
import random
import struct
import sys
from fractions import Fraction

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import progfmt  # noqa: E402  (the exact printf oracle; LANGUAGE.md 11.1)

PROGRAMS = os.path.join(os.path.dirname(HERE), 'programs')

QNAN = 0x7FF8000000000000       # the pattern every NaN result has (entry FMOD, DESIGN.md 4.8)
NQNAN = 0xFFF8000000000000      # -nan
INF = 0x7FF0000000000000
NINF = 0xFFF0000000000000
PZERO = 0
NZERO = 0x8000000000000000
MASK = (1 << 64) - 1


def f2b(x):
    return struct.unpack('>Q', struct.pack('>d', x))[0]


def b2f(b):
    return struct.unpack('>d', struct.pack('>Q', b))[0]


def is_nan(b):
    return (b & 0x7FF0000000000000) == 0x7FF0000000000000 and (b & 0x000FFFFFFFFFFFFF) != 0


def is_inf(b):
    return (b & 0x7FFFFFFFFFFFFFFF) == 0x7FF0000000000000


def is_zero(b):
    return (b & 0x7FFFFFFFFFFFFFFF) == 0


def sign(b):
    return b >> 63


# ---------------------------------------------------------------------------- the model
def fmod6(a, b):
    """a % b of LANGUAGE.md 6.6 for f64 bit patterns a and b; the result's bit pattern."""
    if is_zero(b):                                  # 1. b == 0: a unchanged
        return a
    if is_inf(a) or is_nan(a) or is_nan(b):         # 2. an infinite dividend or a NaN operand
        return QNAN
    r = math.fmod(b2f(a), b2f(b))                   # 3. exact; a zero result has a's sign
    rb = f2b(r)
    if not is_zero(rb) and sign(rb) != sign(b):
        rb = f2b(r + b2f(b))                        # rounded once
    return rb


def exact_check(a, b, e):
    """The independent checks of one vector with finite a and b (see the module docstring)."""
    if is_inf(b):                    # b = +-inf: fmod(a, b) is a; a + b is b when the signs differ
        want = b if (not is_zero(a) and sign(a) != sign(b)) else a
        assert e == want, (hex(a), hex(b))
        return
    fa, fb = Fraction(b2f(a)), Fraction(b2f(b))
    if b2f(b) == 0:
        return
    q = fa / fb
    t = q.numerator // q.denominator if q >= 0 else -((-q.numerator) // q.denominator)  # trunc
    r = fa - fb * t                                  # exact remainder, the sign of a (or zero)
    assert Fraction(math.fmod(b2f(a), b2f(b))) == r, (hex(a), hex(b))
    if r != 0 and ((r < 0) != (fb < 0)):
        r = r + fb
    want = float(r)                                  # Fraction -> float rounds once, to nearest even
    got = b2f(e)
    assert got == want, (hex(a), hex(b), got, want)
    if want == 0:                                    # the sign of a zero: a's (r was zero)
        assert sign(e) == sign(a), (hex(a), hex(b))
    assert math.copysign(1.0, got) == math.copysign(1.0, want) or want == 0


def python_cross(a, b, e):
    """Python's % agrees with the model on the value of a finite result (never a source)."""
    fa, fb = b2f(a), b2f(b)
    if math.isinf(fa) or math.isnan(fa) or math.isnan(fb) or fb == 0:
        return
    py = fa % fb
    assert py == b2f(e), (hex(a), hex(b), py, b2f(e))


# ---------------------------------------------------------------------------- the vectors
def num(x):
    return f2b(x)


def sub(k):
    """k * 2^-1074, a subnormal (k < 2^52)."""
    return k


def build_special():
    """The hand-chosen vectors, each group with the clause that fixes it. (a, b) bit patterns."""
    V = []

    def add(a, b):
        V.append((a, b))

    n = num
    # ordinary values, all four sign combinations (6.6: the result has the sign of b)
    for a, b in ((5.5, 2.0), (-5.5, 2.0), (5.5, -2.0), (-5.5, -2.0), (7.0, 3.0), (-7.0, 3.0),
                 (7.0, -3.0), (-7.0, -3.0), (0.75, 0.5), (-0.75, 0.5), (0.75, -0.5), (-0.75, -0.5),
                 (3.0, 5.0), (-3.0, 5.0), (3.0, -5.0), (-3.0, -5.0), (1e10, 7.0), (-1e10, 7.0),
                 (2.5, 0.1), (-2.5, 0.1), (10.0, 2.5), (1.0, 3.0), (-1.0, 3.0), (4.0, 1.0),
                 (16807.0 * 2147483646.0, 2147483647.0), (1.0e300, 3.0), (-1.0e300, 3.0)):
        add(n(a), n(b))
    # signed zero results: fmod keeps a's sign and no adjustment applies (r == 0): -6 % 3 = -0.0,
    # 6 % -3 = +0.0 (6.6)
    for a, b in ((6.0, 3.0), (-6.0, 3.0), (6.0, -3.0), (-6.0, -3.0), (5.0, 5.0), (-5.0, 5.0),
                 (5.0, -5.0), (-5.0, -5.0), (0.0, 3.0), (-0.0, 3.0), (0.0, -3.0), (-0.0, -3.0),
                 (4.0, 0.5), (-4.0, 0.5), (1e300, 1e300), (-1e300, 1e300), (1.5, 0.5), (-1.5, 0.5)):
        add(n(a), n(b))
    # b = +-0: the result is a, bit for bit (6.6 step 1), whatever a is
    for a in (5.0, -5.0, 0.0, -0.0, 1e300, -1e-300, math.inf, -math.inf):
        for b in (0.0, -0.0):
            add(n(a), n(b))
    add(QNAN, PZERO)                                 # nan % 0 is NaN
    add(QNAN, NZERO)
    add(NQNAN, PZERO)
    add(0x7FF8000000000001, PZERO)                   # a NaN with a payload comes back unchanged
    add(0xFFF8000000000123, NZERO)                   # (the entry returns a's bits, DESIGN.md 4.8)
    add(0x7FF0000000000001, PZERO)                   # a signalling NaN a: b == 0 is checked first
    add(sub(1), PZERO)                               # a subnormal, b = 0
    # an infinite dividend (b not zero) is NaN; so is a NaN operand (6.6 step 2)
    for a in (INF, NINF):
        for b in (3.0, -3.0, 0.5, 1e300, 5e-324):
            add(a, n(b))
        for b in (INF, NINF, QNAN, NQNAN):
            add(a, b)
    for a in (5.0, -5.0, 0.0, -0.0, 5e-324, 1e300):
        for b in (QNAN, NQNAN, 0x7FF8000000000001, 0xFFF8000000000123, 0x7FF0000000000001):
            add(n(a), b)
    for b in (3.0, -3.0, 5e-324, 1e300):
        for a in (QNAN, NQNAN, 0x7FF8000000000001, 0xFFF8000000000123, 0x7FF0000000000001):
            add(a, n(b))
    add(QNAN, QNAN)
    add(NQNAN, 0x7FF8000000000001)
    add(0x7FF8000000000007, 0xFFF8000000000005)
    # b = +-inf with a finite a (6.6: falls out of the rule): -1 % inf = inf, 1 % inf = 1
    for a in (1.0, -1.0, 5.5, -5.5, 1e300, -1e300, 5e-324, -5e-324, 0.0, -0.0):
        for b in (INF, NINF):
            add(n(a), b)
    # r + b rounded once: the exact sum 1 - 1e-20 is not representable and rounds to 1.0, a result
    # equal to b; likewise with a tiny subnormal r and with b = -1 and a positive tiny a
    for a, b in ((-1e-20, 1.0), (1e-20, -1.0), (-5e-324, 1.0), (5e-324, -1.0), (-1e-300, 3.0),
                 (-2.0 ** -53, 1.0), (-2.0 ** -54, 1.0), (-2.0 ** -52, 1.0), (2.0 ** -53, -1.0),
                 (-1.0, 1.0 + 2.0 ** -52), (-3.0, 1.0 + 2.0 ** -52), (-1e308, 3e307)):
        add(n(a), n(b))
    # subnormals as dividend, divisor and both (exact fmod; the sum r + b exact or rounded)
    for ka, kb in ((7, 3), (-7, 3), (7, -3), (-7, -3), (1, 1), (-1, 1), (5, 2), (-5, 2),
                   ((1 << 52) - 1, 3), (-((1 << 52) - 1), 3), ((1 << 52) - 1, (1 << 51)),
                   (-((1 << 52) - 1), (1 << 51) + 1), (1 << 51, 1), (12345, 100), (-12345, 100)):
        sa, sb = (0 if ka > 0 else NZERO), (0 if kb > 0 else NZERO)
        add(sa | abs(ka), sb | abs(kb))
    for a, b in ((5.0, 5e-324), (-5.0, 5e-324), (1e-310, 3e-311), (-1e-310, 3e-311), (3e-311, -1e-310),
                 (2.2250738585072014e-308, 3e-310), (-2.2250738585072014e-308, 3e-310),
                 (2.2250738585072014e-308, 2.225073858507201e-308), (1e300, 5e-324),
                 (5e-324, 1e300), (-5e-324, 1e300), (5e-324, -1e300), (3e-324, 1.0)):
        add(n(a), n(b))
    # quotients near and beyond 2^1023 (the exact fmod, no overflow)
    mx = 1.7976931348623157e308
    tiny = 5e-324
    for a, b in ((mx, 3.0), (-mx, 3.0), (mx, -3.0), (mx, 7.0), (mx, 1e-300), (mx, tiny), (-mx, tiny),
                 (mx, 2.0 ** -1022), (mx, mx), (mx, -mx), (-mx, mx), (mx, mx / 2),
                 (mx, mx * 0.75), (mx, 2.0 ** 1023), (-mx, 2.0 ** 1023), (2.0 ** 1023, 3.0),
                 (2.0 ** 1023, 5.0), (-(2.0 ** 1023), 5.0), (2.0 ** 1023, 1.1), (2.0 ** 1022, 1e-5),
                 (mx, 1.0), (mx, 0.1), (-mx, 0.1), (mx, 123456789.0), (2.0 ** 1000, 2.0 ** 999 + 1.0),
                 (2.0 ** 1023 + 2.0 ** 970, 2.0 ** 1023), (1e308, 9.999999999999999e307)):
        add(n(a), n(b))
    # a smaller than |b| (fmod is a; the sign adjustment alone decides), and |a| == |b|
    for a, b in ((0.25, 1e10), (-0.25, 1e10), (0.25, -1e10), (-0.25, -1e10), (1e-300, 1e300),
                 (-1e-300, 1e300), (1e-300, -1e300), (-1e-300, -1e300)):
        add(n(a), n(b))
    # the workloads' uses of mod: mod(16807*s, 2147483647)'s shape, mod(I + J, 2)'s shape (exact)
    for a, b in ((16807.0, 2147483647.0), (16807.0 * 123456789.0, 2147483647.0), (3.0, 2.0),
                 (4.0, 2.0), (5.0, 2.0), (-1.0, 2.0), (-2.0, 2.0), (0.0, 2.0), (1.0, 2.0)):
        add(n(a), n(b))
    return V


def build_random(count=160, seed=6):
    """Deterministic pseudo-random pairs over most of the exponent range, both signs; with the
    divisor's exponent near and far from the dividend's (random.Random is the Mersenne Twister
    with a fixed seed: the same vectors on every run and host)."""
    rnd = random.Random(seed)
    V = []
    for i in range(count):
        ea = rnd.randint(-1000, 1000)
        eb = ea + rnd.randint(-60, 60) if i % 2 == 0 else rnd.randint(-1000, 1000)
        eb = max(-1070, min(1020, eb))
        fa = math.ldexp(rnd.random() + 0.5, ea) * (-1 if rnd.random() < 0.5 else 1)
        fb = math.ldexp(rnd.random() + 0.5, eb) * (-1 if rnd.random() < 0.5 else 1)
        if math.isinf(fa) or math.isinf(fb) or fb == 0.0:
            continue
        V.append((f2b(fa), f2b(fb)))
    return V


def with_expected(pairs):
    return [(a, b, fmod6(a, b)) for a, b in pairs]


def all_vectors():
    """The runtime test's table: the special vectors, then the random ones (nothing twice)."""
    seen = set()
    out = []
    for a, b in build_special() + build_random():
        if (a, b) in seen:
            continue
        seen.add((a, b))
        out.append((a, b, fmod6(a, b)))
    return out


def self_check(vectors):
    for a, b, e in vectors:
        assert 0 <= a <= MASK and 0 <= b <= MASK and 0 <= e <= MASK
        if is_zero(b):
            assert e == a                                       # step 1
        elif is_inf(a) or is_nan(a) or is_nan(b):
            assert e == QNAN                                    # step 2
        else:
            exact_check(a, b, e)
            python_cross(a, b, e)
    # the signed zeros the spec names, and the infinite divisor (LANGUAGE.md 6.6)
    assert fmod6(f2b(-6.0), f2b(3.0)) == NZERO
    assert fmod6(f2b(6.0), f2b(-3.0)) == PZERO
    assert fmod6(f2b(-1.0), INF) == INF
    assert fmod6(f2b(1.0), INF) == f2b(1.0)
    assert fmod6(INF, PZERO) == INF and fmod6(QNAN, PZERO) == QNAN
    assert (-6.0) % 3.0 == 0.0 and math.copysign(1.0, (-6.0) % 3.0) == 1.0   # Python gives +0.0 ...
    assert b2f(fmod6(f2b(-6.0), f2b(3.0))) == 0.0 and sign(fmod6(f2b(-6.0), f2b(3.0))) == 1  # ... not -0.0


# ---------------------------------------------------------------------------- assembler data
MARKERS = {
    'arm64_macos': ('//', '__TEXT,__const', 'Lfmod_vec_table'),
    'x86_64_linux': ('#', '.rodata', '.Lfmod_vec_table'),
}


def emit_asm(target):
    """The table as assembler text for a target: a list of lines (the BEGIN and END markers
    included)."""
    cm, section, label = MARKERS[target]
    V = all_vectors()
    L = ['%s FMOD6-VECTORS-BEGIN %s' % (cm, target)]
    L.append('%s GENERATED by tests/vectors/fmod6_cases.py --emit-asm %s: do not edit; '
             '`fmod6_cases.py --check-asm` checks this block.' % (cm, target))
    L.append('%s Layout: %s: .quad N, then N records of three .quad (the raw bit patterns of the '
             'dividend a, the divisor b' % (cm, label))
    L.append('%s and the expected result e of LANGUAGE.md 6.6), record i at %s + 8 + 24*i; '
             'a NaN result is #7FF8000000000000.' % (cm, label))
    if target == 'arm64_macos':
        L.append('    .pushsection %s' % section)
    else:
        L.append('    .pushsection %s' % section)
    L.append('    .p2align 3')
    L.append('%s:' % label)
    L.append('    .quad %d' % len(V))
    for a, b, e in V:
        L.append('    .quad 0x%016X, 0x%016X, 0x%016X' % (a, b, e))
    L.append('    .popsection')
    L.append('%s FMOD6-VECTORS-END' % cm)
    return L


def check_asm(path):
    """Compare the block between the markers of FILE with the table of its target."""
    with open(path, 'r') as f:
        lines = f.read().split('\n')
    begin = None
    for i, ln in enumerate(lines):
        for target, (cm, _, _) in MARKERS.items():
            if ln == '%s FMOD6-VECTORS-BEGIN %s' % (cm, target):
                begin = (i, target)
        if begin:
            break
    if not begin:
        return 'no line "// FMOD6-VECTORS-BEGIN <target>" or "# FMOD6-VECTORS-BEGIN <target>" in %s' % path
    i0, target = begin
    cm = MARKERS[target][0]
    end = '%s FMOD6-VECTORS-END' % cm
    try:
        i1 = lines.index(end, i0 + 1)
    except ValueError:
        return 'no "%s" line after the BEGIN marker in %s' % (end, path)
    got = lines[i0:i1 + 1]
    want = emit_asm(target)
    for k in range(max(len(got), len(want))):
        g = got[k] if k < len(got) else '<missing>'
        w = want[k] if k < len(want) else '<extra>'
        if g != w:
            return ('%s: table differs from fmod6_cases.py --emit-asm %s at block line %d (file line %d):\n'
                    '  file: %s\n  want: %s' % (path, target, k + 1, i0 + k + 1, g, w))
    return None


# ---------------------------------------------------------------------------- Sea programs
def lit(b):
    """A Sea expression for the bit pattern b (only the NaNs `nan` and `-nan`)."""
    if is_nan(b):
        assert b in (QNAN, NQNAN), hex(b)
        return 'nan' if b == QNAN else '-nan'
    if is_inf(b):
        return 'inf' if b == INF else '-inf'
    x = b2f(b)
    if b == NZERO:
        return '-0.0'
    t = repr(abs(x))
    assert 'e' in t or '.' in t, t
    if 'inf' in t or 'nan' in t:
        raise ValueError(t)
    return ('-' + t) if sign(b) else t


def arr_lit(items, per=3, indent='    '):
    rows = []
    for i in range(0, len(items), per):
        rows.append(indent + ', '.join(items[i:i + per]))
    return '[\n' + ',\n'.join(rows) + ',\n]'


def printf_g(fmt, bits_list):
    return progfmt.format_all(fmt, [('f', b) for b in bits_list])


def str_f64(b):
    """str(x) of an f64 (LANGUAGE.md 10.9): nan, inf, -inf, else %.17g."""
    if is_nan(b):
        return b'nan'
    if is_inf(b):
        return b'inf' if b == INF else b'-inf'
    return printf_g('%.17g', [b])


def write(name, text, out):
    assert text.isascii()
    for ln in text.split('\n'):
        assert len(ln) <= 4096
    with open(os.path.join(PROGRAMS, name + '.sea'), 'w') as f:
        f.write(text)
    with open(os.path.join(PROGRAMS, name + '.out'), 'wb') as f:
        f.write(out)


def special_sea_pairs():
    """The special vectors a Sea program can spell: NaN only as nan / -nan."""
    return [(a, b) for a, b in build_special()
            if (not is_nan(a) or a in (QNAN, NQNAN)) and (not is_nan(b) or b in (QNAN, NQNAN))]


def gen_scalar():
    P = special_sea_pairs()
    A = arr_lit([lit(a) for a, _ in P])
    B = arr_lit([lit(b) for _, b in P])
    src = ('// fmod_scalar -- f64 %% at run time (the FMOD entry, DESIGN.md 4.8, L-cm): the special cases of LANGUAGE.md 6.6\n'
           '// (b = +-0 gives a, an infinite a or a NaN gives NaN, -6.0 %% 3.0 is -0.0 and 6.0 %% -3.0 is +0.0, -1 %% inf is inf,\n'
           '// subnormals, quotients near 2^1023, one rounding of r + b); operands come from arrays so nothing is folded;\n'
           '// printed with %%.17g (-0, NaN, Inf, -Inf as LANGUAGE.md 11.1 spells them); expected bytes from\n'
           '// tests/vectors/fmod6_cases.py (math.fmod and the sign adjustment, never Python\'s %%)\n'
           'let A: f64[] = %s\n'
           'let B: f64[] = %s\n'
           'for k in 0..len(A) {\n'
           '    printf("%%.17g %%%% %%.17g = %%.17g\\n", A[k], B[k], A[k] %% B[k])\n'
           '}\n') % (A, B)
    out = b''
    for a, b in P:
        out += printf_g('%.17g %% %.17g = %.17g\n', [a, b, fmod6(a, b)])
    write('fmod_scalar', src, out)
    return len(P)


def gen_str():
    P = special_sea_pairs()
    A = arr_lit([lit(a) for a, _ in P])
    B = arr_lit([lit(b) for _, b in P])
    src = ('// fmod_str -- f64 %% at run time printed with str() (LANGUAGE.md 10.9: %%.17g for a finite value, nan, inf, -inf\n'
           '// for the others, -0 for a negative zero): the pairs of fmod_scalar; expected bytes from\n'
           '// tests/vectors/fmod6_cases.py (math.fmod and the sign adjustment, never Python\'s %%)\n'
           'let A: f64[] = %s\n'
           'let B: f64[] = %s\n'
           'for k in 0..len(A) {\n'
           '    print(str(A[k]) + " %% " + str(B[k]) + " = " + str(A[k] %% B[k]) + "\\n")\n'
           '}\n') % (A, B)
    out = b''
    for a, b in P:
        out += str_f64(a) + b' % ' + str_f64(b) + b' = ' + str_f64(fmod6(a, b)) + b'\n'
    write('fmod_str', src, out)


def gen_random():
    P = build_random(count=120, seed=61)
    P = [(a, b) for a, b in P]
    A = arr_lit([lit(a) for a, _ in P], per=2)
    B = arr_lit([lit(b) for _, b in P], per=2)
    src = ('// fmod_random -- f64 %% at run time over deterministic pseudo-random pairs (random.Random(61), both signs, exponents\n'
           '// -1000 .. 1000, divisor near and far from the dividend): printed with %%.17g; expected bytes from\n'
           '// tests/vectors/fmod6_cases.py (math.fmod and the sign adjustment, never Python\'s %%)\n'
           'let A: f64[] = %s\n'
           'let B: f64[] = %s\n'
           'for k in 0..len(A) {\n'
           '    printf("%%.17g\\n", A[k] %% B[k])\n'
           '}\n') % (A, B)
    out = b''.join(printf_g('%.17g\n', [fmod6(a, b)]) for a, b in P)
    write('fmod_random', src, out)
    return len(P)


def gen_array():
    """Element-wise f64 % on arrays (LANGUAGE.md 6.2, 6.3; DESIGN.md 2.11.4 L7)."""
    n = num
    va = [n(x) for x in (7.5, -7.5, 7.5, -7.5, 6.0, -6.0, 6.0, -6.0, 0.0, -0.0, 1e300)] + [INF, NINF, QNAN]
    vb = [n(x) for x in (2.0, 2.0, -2.0, -2.0, 3.0, 3.0, -3.0, -3.0, 5.0, 5.0, 7.0, 3.0, 3.0, 3.0)]
    assert len(va) == len(vb)
    sc = n(2.5)                                         # the scalar operand
    src = []
    out = b''

    def pv(bits):
        s = ('%d:' % len(bits)).encode()
        for b in bits:
            s += b' ' + printf_g('%.17g', [b])
        return s + b'\n'

    src.append('// fmod_array -- f64 % element-wise (LANGUAGE.md 6.2, 6.3, 6.5, 6.6; DESIGN.md 2.11.4 L7, rule 39): vector with vector,')
    src.append('// with a scalar either way, an untyped integer literal and an i64 variable as the scalar (converted), an i64[] with an')
    src.append('// f64 scalar, matrix with matrix, with a scalar, with .row and .col broadcasting, empty and fixed-size arrays; each')
    src.append('// element is the scalar rule of fmod_scalar; printed with %.17g; expected bytes from tests/vectors/fmod6_cases.py')
    src.append('fn pv(v: f64[]) {')
    src.append('    printf("%d:", len(v))')
    src.append('    for x in v {')
    src.append('        printf(" %.17g", x)')
    src.append('    }')
    src.append('    printf("\\n")')
    src.append('}')
    src.append('fn pm(M: f64[,]) {')
    src.append('    for i in 0..rows(M) {')
    src.append('        for j in 0..cols(M) {')
    src.append('            printf(" %.17g", M[i, j])')
    src.append('        }')
    src.append('        printf(" |")')
    src.append('    }')
    src.append('    printf("\\n")')
    src.append('}')
    src.append('let V: f64[] = ' + arr_lit([lit(b) for b in va]))
    src.append('let W: f64[] = ' + arr_lit([lit(b) for b in vb]))
    # 1. vector % vector
    src.append('pv(V % W)')
    out += pv([fmod6(a, b) for a, b in zip(va, vb)])
    # 2. vector % scalar, scalar % vector
    src.append('pv(V % 2.5)')
    out += pv([fmod6(a, sc) for a in va])
    src.append('pv(2.5 % W)')
    out += pv([fmod6(sc, b) for b in vb])
    # 3. an untyped integer literal and an i64 variable (converted to f64: LANGUAGE.md 4.2, 6.5)
    src.append('pv(V % 3)')
    out += pv([fmod6(a, n(3.0)) for a in va])
    src.append('let k7 = 7')
    src.append('pv(k7 % W)')
    out += pv([fmod6(n(7.0), b) for b in vb])
    # 4. an i64[] with an f64 scalar (each element converted)
    iv = [5, -5, 7, -7, 0, 3]
    src.append('let I: i64[] = [5, -5, 7, -7, 0, 3]')
    src.append('pv(I % 2.5)')
    out += pv([fmod6(n(float(x)), sc) for x in iv])
    # 5. matrix % matrix, matrix % scalar (matrices 2x3, column-major storage is invisible)
    m1 = [[7.5, -7.5, 6.0], [-6.0, 0.5, -0.5]]
    m2 = [[2.0, 2.0, -3.0], [3.0, -0.25, 0.25]]
    src.append('let M: f64[,] = [7.5, -7.5, 6.0; -6.0, 0.5, -0.5]')
    src.append('let N: f64[,] = [2.0, 2.0, -3.0; 3.0, -0.25, 0.25]')

    def pmat(rowsb):
        s = b''
        for r in rowsb:
            for b in r:
                s += b' ' + printf_g('%.17g', [b])
            s += b' |'
        return s + b'\n'
    src.append('pm(M % N)')
    out += pmat([[fmod6(n(a), n(b)) for a, b in zip(r1, r2)] for r1, r2 in zip(m1, m2)])
    src.append('pm(M % 2.0)')
    out += pmat([[fmod6(n(a), n(2.0)) for a in r1] for r1 in m1])
    # 6. broadcasting: .row (1x3) and .col (2x1) against the 2x3 matrix (6.3)
    rv = [2.0, -4.0, 0.5]
    cv = [4.0, -1.5]
    src.append('let rv: f64[] = [2.0, -4.0, 0.5]')
    src.append('let cv: f64[] = [4.0, -1.5]')
    src.append('pm(M % rv.row)')
    out += pmat([[fmod6(n(a), n(rv[j])) for j, a in enumerate(r1)] for r1 in m1])
    src.append('pm(M % cv.col)')
    out += pmat([[fmod6(n(a), n(cv[i])) for a in r1] for i, r1 in enumerate(m1)])
    # 7. a dividend column against a divisor row: 2x1 % 1x3 -> 2x3
    src.append('pm(cv.col % rv.row)')
    out += pmat([[fmod6(n(c), n(r)) for r in rv] for c in cv])
    # 8. empty arrays: the result is empty, no element is computed
    src.append('let E = zeros(0)')
    src.append('pv(E % E)')
    out += pv([])
    src.append('pv(E % 3.0)')
    out += pv([])
    # 9. a fixed-size array (the result is fixed-size with the same extent)
    fx = [5.0, -5.0, 2.0, -2.0]
    src.append('let F: f64[4] = [5.0, -5.0, 2.0, -2.0]')
    src.append('let G: f64[4] = F % 3.0')
    src.append('pv(G)')
    out += pv([fmod6(n(a), n(3.0)) for a in fx])
    # 10. the result used in a larger element-wise expression and reduced (both are exact operations)
    src.append('printf("%.17g\\n", sum(F % 3.0 + 1.0))')
    # sum of an array: pinned 8-lane order of LANGUAGE.md 10.5; for four elements: lane k holds
    # element k, then the lanes are combined pairwise (-0.0 start); every value here is exact so
    # any order gives one result: (5%3 = 2, -5%3 = 1, 2%3 = 2, -2%3 = 1; each + 1.0)
    vals = [b2f(fmod6(n(a), n(3.0))) + 1.0 for a in fx]
    assert vals == [3.0, 2.0, 3.0, 2.0] and sum(vals) == 10.0
    out += printf_g('%.17g\n', [n(10.0)])
    text = '\n'.join(src) + '\n'
    write('fmod_array', text, out)


def main():
    V = all_vectors()
    self_check(V)
    ns = gen_scalar()
    gen_str()
    nr = gen_random()
    gen_array()
    print('fmod6_cases: self-check passed (%d vectors); programs fmod_scalar (%d pairs), fmod_str, '
          'fmod_random (%d pairs), fmod_array written' % (len(V), ns, nr))


if __name__ == '__main__':
    argv = sys.argv[1:]
    if argv[:1] == ['--emit-asm'] and len(argv) == 2 and argv[1] in MARKERS:
        self_check(all_vectors())
        sys.stdout.write('\n'.join(emit_asm(argv[1])) + '\n')
    elif argv[:1] == ['--check-asm'] and len(argv) == 2:
        self_check(all_vectors())
        err = check_asm(argv[1])
        if err:
            sys.stderr.write('fmod6_cases: ' + err + '\n')
            sys.exit(1)
        print('fmod6_cases: ok (%s)' % argv[1])
    elif not argv:
        main()
    else:
        sys.stderr.write('usage: fmod6_cases.py [--emit-asm arm64_macos|x86_64_linux | --check-asm FILE]\n')
        sys.exit(2)
