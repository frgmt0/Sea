"""Sub-phase 5c-1 corpus: the `opt_*` run tests of DESIGN.md 6.2 "Phase-5 tests" (work package T1 of
DESIGN.md 8 row 5c-1): programs whose output, error, error line or exit status would change if a
transformation of pass 3b (T1 checks and overflow, T2 division by constants, T3 value numbering, T4
if-conversion, T10 clean-up; and the loop transformations T5-T9 of 5c-2) were inexact. The section "5c-2
additions" (work package T1 of DESIGN.md 8 row 5c-2) adds adversarial cases for pass 3c `sealopt`: T5
promotion with exits, returns and calls, T6 versioning with shared and aliased arrays, T7 addresses near the
extents, T8 hoisting of failing or guarded work (error order and line, loops run zero times, L-at object
pointers), T9 unswitching on NaN comparisons, T4's L-bq/L-bn selections, and Decision 75's loop liveness.

Run with `timeout 120 uv run --no-project python tests/vectors/opt5c1_cases.py`. It writes
programs/opt_*.{sea,out} and errors/r_opt_*.{sea,err,status[,out]}.

Every expected byte is derived here from LANGUAGE.md, never from a run of the compiler:

* `i64` arithmetic exactly (Python integers), a result outside -2^63 .. 2^63 - 1 being the run-time
  error `integer overflow` (6.5); `%` and `idiv` floored (6.6: Python's `%` and `//` on integers
  are the floored modulo and quotient), a zero divisor `integer division by zero`, `idiv(-2^63, -1)`
  `integer overflow` while `-2^63 % -1` is 0;
* `f64` arithmetic as IEEE binary64 with round to nearest even (Python floats; `/` is the correctly
  rounded quotient, subnormals kept), the six comparisons by IEEE (6.4: with a NaN operand only `!=`
  holds), the `i64` operand of a mixed operation converted ties to even (4.2);
* printing as `printf` prints (11.1): `%d` of an `i64` in decimal and of a `bool` as 0 or 1, `%g` and
  `%.17g` as C99 (Python's `%` operator, which rounds correctly) with the non-finite values spelled
  `NaN`, `Inf`, `-Inf`; `str(x)` of an `f64` as `%.17g` with `nan`, `inf`, `-inf` (10.9);
* evaluation order left to right (6.8 rule 5), the operands of a binary operator before it, all the
  arguments of a call before the call, so a failing argument means the call never happens; the
  indices of an index expression and then their checks (5.4), the right side of an assignment
  before its target's checks (5.5), a compound assignment reading its target (with the check) before
  it evaluates the right side (5.5, 7.3); a range's bounds and step evaluated once (7.5), its length
  `max(0, ceil((b - a) / s))` (5.1); `while` testing before each iteration (7.4); `break` and
  `continue` of the innermost loop (7.5); a run-time error flushes standard output, writes
  `NAME.sea:LINE: error: MSG` and exits with status 1 (9.2), LINE being the line of the failing
  expression; the bounds message `index i out of bounds for dimension d of extent n` (5.4);
* value semantics of arrays (4.5: a store into one variable never changes another that shared its
  buffer), `ref` parameters as the caller's variable itself (8.3), a `ref` to an element the element
  of the caller's array as it is when the call is made.

The line of a run-time error is the line holding its marker (computed from the source text).
"""

import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
TESTS = os.path.dirname(HERE)
PROGRAMS = os.path.join(TESTS, 'programs')
ERRORS = os.path.join(TESTS, 'errors')
COUNT = {'programs': 0, 'errors': 0}

MIN = -2 ** 63
MAX = 2 ** 63 - 1
INF = float('inf')
NAN = float('nan')


def write(path, data):
    if isinstance(data, str):
        data = data.encode('ascii')
    with open(path, 'wb') as f:
        f.write(data)


def remove(path):
    if os.path.exists(path):
        os.remove(path)


def source(name, comment, body):
    head = '// %s -- ' % name + comment[0] + '\n' + ''.join('// %s\n' % c for c in comment[1:])
    src = head + body
    for ln in src.split('\n'):
        assert len(ln.encode('ascii')) <= 4096, ln[:40]                  # 3.1 line limit
        assert all(c == '\t' or 0x20 <= ord(c) < 0x7F for c in ln), ln   # 3.1 ASCII
    return src


def prog(name, comment, body, out):
    """A programs/ test: the source and its whole expected standard output."""
    write(os.path.join(PROGRAMS, name + '.sea'), source(name, comment, body))
    write(os.path.join(PROGRAMS, name + '.out'), out)
    for ext in ('.args', '.in', '.err', '.status', '.meta'):
        remove(os.path.join(PROGRAMS, name + ext))
    COUNT['programs'] += 1


def line_of(src, marker):
    lines = src.split('\n')
    hits = [i for i, ln in enumerate(lines) if marker in ln and not ln.startswith('//')]
    assert len(hits) == 1, (marker, hits)
    return hits[0] + 1


def err_rt(name, comment, body, marker, msg, out=''):
    """A run-time error: stderr `NAME.sea:LINE: error: MSG`, status 1, stdout `out`."""
    src = source(name, comment, body)
    ln = line_of(src, marker)
    write(os.path.join(ERRORS, name + '.sea'), src)
    write(os.path.join(ERRORS, name + '.err'), '%s.sea:%d: error: %s\n' % (name, ln, msg))
    write(os.path.join(ERRORS, name + '.status'), '1\n')
    path = os.path.join(ERRORS, name + '.out')
    if out:
        write(path, out)
    else:
        remove(path)
    for ext in ('.args', '.in', '.meta'):
        remove(os.path.join(ERRORS, name + ext))
    COUNT['errors'] += 1


# ---------------------------------------------------------------------------- the model
class Ovf(Exception):
    pass


class Oob(Exception):
    pass


def ck(v):
    """An exact i64 result (6.5)."""
    if v < MIN or v > MAX:
        raise Ovf()
    return v


def idx(n, i):
    """A scalar index check (5.4)."""
    if i < 0 or i >= n:
        raise Oob(i)
    return i


def oob(i, d, n):
    return 'index %d out of bounds for dimension %d of extent %d' % (i, d, n)


def nonfinite(x):
    if math.isnan(x):
        return 'NaN'
    if math.isinf(x):
        return 'Inf' if x > 0 else '-Inf'
    return None


def e17(x):
    """printf %.17g of an f64 (11.1)."""
    assert isinstance(x, float)
    return nonfinite(x) or '%.17g' % x


def g(x):
    """printf %g of an f64 (11.1)."""
    assert isinstance(x, float)
    return nonfinite(x) or '%g' % x


def sstr(x):
    """str(x) of an f64 (10.9)."""
    assert isinstance(x, float)
    if math.isnan(x):
        return 'nan'
    if math.isinf(x):
        return 'inf' if x > 0 else '-inf'
    return '%.17g' % x


def ilit(v):
    """An i64 as Sea source (3.4: -2^63 is unary minus of 2^63)."""
    assert MIN <= v <= MAX
    return str(v)


def flit(x):
    """A finite f64 as a Sea float literal denoting exactly x (3.4)."""
    assert not math.isinf(x) and not math.isnan(x)
    t = '%.17g' % x
    if '.' not in t and 'e' not in t:
        t += '.0'
    assert float(t) == x and math.copysign(1.0, float(t)) == math.copysign(1.0, x)
    return t


def fsrc(x):
    if math.isnan(x):
        return 'nan'
    if math.isinf(x):
        return 'inf' if x > 0 else '-inf'
    return flit(x)


def pvf(v):
    """The helper `pv` below: `n:` and ` %g` per element."""
    return '%d:' % len(v) + ''.join(' ' + g(x) for x in v) + '\n'


def pvi(v):
    return '%d:' % len(v) + ''.join(' %d' % x for x in v) + '\n'


PV = '''fn pv(v: f64[]) {
    printf("%d:", len(v))
    for x in v {
        printf(" %g", x)
    }
    printf("\\n")
}
'''
PVI = '''fn pvi(v: i64[]) {
    printf("%d:", len(v))
    for x in v {
        printf(" %d", x)
    }
    printf("\\n")
}
'''


# ============================================================ opt_div_const (T2)
def dividends(c):
    """-2^63, -2^63 + 1, -1, 0, 1, 2^63 - 1 and multiples of |c| +- 1 (the small ones, k = +-1, +-3,
    and the extreme ones nearest the i64 bounds), in range, without repeats."""
    a = abs(c)
    vals = [MIN, MIN + 1, -1, 0, 1, MAX]
    for k in (1, 3, -1, -3):
        vals += [k * a - 1, k * a, k * a + 1]
    top = (MAX // a) * a
    bot = -((2 ** 63) // a) * a
    vals += [top - 1, top, top + 1, bot - 1, bot, bot + 1]
    out = []
    for v in vals:
        if MIN <= v <= MAX and v not in out:
            out.append(v)
    if c == -1:
        out.remove(MIN)            # idiv(-2^63, -1) overflows: r_opt_idiv_min
    return out


def opt_div_const():
    divisors = [1, 2, 3, 6, 7, 10, 11, 2147483647, 2 ** 62, 2 ** 62 + 1,
                -1, -2, -7, -10, -2147483647, -(2 ** 62)]
    body, out = '', ''
    for n, c in enumerate(divisors):
        ds = dividends(c)
        assert len(ds) <= 256
        cs = ilit(c)
        body += 'let d%d = [%s]\n' % (n, ', '.join(ilit(v) for v in ds))
        body += 'for x in d%d {\n    printf("%s %%d %%d %%d\\n", x, x %% %s, idiv(x, %s))\n}\n' % (n, cs, cs, cs)
        for x in ds:
            out += '%s %d %d %d\n' % (cs, x, x % c, x // c)
    # a const and a let as the divisor (each a constant register: one li)
    ds = dividends(11)
    body += 'const C11 = 11\nlet six = 6\n'
    body += 'for x in d6 {\n    printf("c %d %d %d %d %d\\n", x, x % C11, idiv(x, C11), x % six, idiv(x, six))\n}\n'
    for x in ds:
        out += 'c %d %d %d %d %d\n' % (x, x % 11, x // 11, x % 6, x // 6)
    # -2^63 % -1 is 0 (6.6), and the % and idiv by 1 of the extremes
    body += 'let mins = [-9223372036854775808, 9223372036854775807]\nfor x in mins {\n'
    body += '    printf("m %d %d %d\\n", x % -1, x % 1, idiv(x, 1))\n}\n'
    for x in (MIN, MAX):
        out += 'm %d %d %d\n' % (x % -1, x % 1, x // 1)
    # sweeps over -13 .. 13 for small divisors, both signs
    for c in (2, 3, 4, 6, 7, 8, -3, -4, -6):
        cs = ilit(c)
        body += 'for x in -13..=13 {\n    printf(" %%d,%%d", x %% %s, idiv(x, %s))\n}\nprintf("\\n")\n' % (cs, cs)
        out += ''.join(' %d,%d' % (x % c, x // c) for x in range(-13, 14)) + '\n'
    prog('opt_div_const', ['floored % and idiv by constant divisors (T2): 1, powers of two, 3, 6, 7, 10, 11,',
                           '2147483647, 2^62, 2^62 + 1 and negative ones (left unchanged by T2), on -2^63, -2^63 + 1,',
                           '-1, 0, 1, 2^63 - 1 and multiples of the divisor +-1; a const and a let divisor;',
                           'sweeps over -13 .. 13 (LANGUAGE.md 6.6; DESIGN.md 5.8 T2)'], body, out)


# ============================================================ opt_fdiv_const (T2, f64)
def opt_fdiv_const():
    xs = [1.0, -1.0, 10.0, 0.0, -0.0, 5e-324, -5e-324, 1.5e-323, 2.0 ** -1022, 1e308, -1e308,
          1.7976931348623157e308, 3.0, 0.1, INF, -INF, NAN]
    divs = [('4.0', 4.0), ('0.5', 0.5), ('-2.0', -2.0), (flit(2.0 ** 1023), 2.0 ** 1023),
            (flit(2.0 ** -1022), 2.0 ** -1022), ('3.0', 3.0), ('0.25', 0.25), ('4', 4.0),
            ('-' + flit(2.0 ** 1023), -(2.0 ** 1023))]
    body = 'let xs = [%s]\n' % ', '.join(fsrc(x) for x in xs)
    out = ''
    for n, (src, d) in enumerate(divs):
        body += 'for x in xs {\n    let y = x / %s\n    printf("q%d %%.17g %%s\\n", y, str(y))\n}\n' % (src, n)
        for x in xs:
            y = x / d
            out += 'q%d %s %s\n' % (n, e17(y), sstr(y))
    body += 'const Q = 0.5\nfor x in xs {\n    let y = x / Q\n    printf("c %.17g %s\\n", y, str(y))\n}\n'
    for x in xs:
        y = x / 0.5
        out += 'c %s %s\n' % (e17(y), sstr(y))
    # i64 / constant: both converted to f64, then one division (6.5)
    ns = [7, -9, 9007199254740993, MIN, MAX]
    body += 'let ns = [%s]\nfor k in ns {\n    let y = k / 4\n    printf("i %%.17g %%s\\n", y, str(y))\n}\n' % ', '.join(ilit(v) for v in ns)
    for k in ns:
        y = float(k) / 4.0
        out += 'i %s %s\n' % (e17(y), sstr(y))
    # the results the spec asks for are present: normal, subnormal, overflow, signed zero
    allq = [x / d for _, d in divs for x in xs]
    assert any(q != 0 and abs(q) < 2.0 ** -1022 for q in allq)
    assert any(math.isinf(q) for q, x in zip(allq, xs * len(divs)) if not math.isinf(x))
    assert any(q == 0 and math.copysign(1.0, q) < 0 for q in allq)
    prog('opt_fdiv_const', ['f64 division by the constants 4.0, 0.5, -2.0, 2^1023, 2^-1022, 3.0, 0.25, an untyped 4,',
                            '-2^1023 and a const 0.5 on values giving normal, subnormal, overflowing and signed-zero',
                            'results, Inf and NaN; i64 / 4; printed with %.17g and str() (LANGUAGE.md 6.5, 6.8 rule 2,',
                            '10.9, 11.1; DESIGN.md 5.8 T2)'], body, out)


# ============================================================ opt_ifconv (T4)
def opt_ifconv():
    vs = [3, -1, 7, 0, 5, 2]
    fs = [2.5, -0.0, NAN, 0.0, -3.5, INF]
    ss = ['a', 'bb', 'ccc', '', 'ee', 'f']
    body = 'let vs = [%s]\n' % ', '.join(ilit(v) for v in vs)
    body += 'let fs = [%s]\n' % ', '.join(fsrc(x) for x in fs)
    body += 'let ss = [%s]\n' % ', '.join('"%s"' % s for s in ss)
    body += '''let hundred = 100
let gg = 9.5
let hh = -0.0
let other = "zz"
var c = -4
var flag = false
for i in 0..6 {
    let a = vs[i]
    let f = fs[i]
    let s = ss[i]
    var m = a
    if a > 2 {
        m = hundred
    }
    let p = if f < 1.0 { f } else { gg }
    let q = if !(f < 1.0) { f } else { gg }
    var t = s
    if len(s) == 2 {
        t = other
    }
    var w = f
    if f >= 0.0 {
        w = hh
    } else {
        w = gg
    }
    if i % 2 == 0 {
        c = a
    }
    if f != f {
        flag = true
    }
    let z = if f == 0.0 { f } else { hh }
    printf("%d %d %.17g %.17g %s %.17g %d %d %.17g\\n", i, m, p, q, t, w, c, flag, z)
}
'''
    out = ''
    c, flag = -4, False
    for i in range(6):
        a, f, s = vs[i], fs[i], ss[i]
        m = 100 if a > 2 else a
        p = f if f < 1.0 else 9.5
        q = f if not (f < 1.0) else 9.5
        t = 'zz' if len(s) == 2 else s
        w = -0.0 if f >= 0.0 else 9.5
        if i % 2 == 0:
            c = a
        if f != f:
            flag = True
        z = f if f == 0.0 else -0.0
        out += '%d %d %s %s %s %s %d %d %s\n' % (i, m, e17(p), e17(q), t, e17(w), c, int(flag), e17(z))
    prog('opt_ifconv', ['if statements with one assignment per arm and if expressions selecting a value, of',
                        'i64, f64, str and bool, with NaN, -0.0 and Inf conditions, an ifz-shaped !(f < 1.0), and a',
                        'variable selected against its own old value (LANGUAGE.md 6.4, 6.10, 7.4; DESIGN.md 5.8 T4)'],
         body, out)


# ============================================================ opt_nan_cmp
OPS = [('==', lambda a, b: a == b), ('!=', lambda a, b: a != b), ('<', lambda a, b: a < b),
       ('<=', lambda a, b: a <= b), ('>', lambda a, b: a > b), ('>=', lambda a, b: a >= b)]


def opt_nan_cmp():
    xs = [NAN, 1.0, NAN, -0.0, 2.0]
    ys = [1.0, NAN, NAN, 0.0, 2.0]
    body = 'let xs = [%s]\nlet ys = [%s]\n' % (', '.join(fsrc(x) for x in xs), ', '.join(fsrc(y) for y in ys))
    body += 'for k in 0..5 {\n    let a = xs[k]\n    let b = ys[k]\n'
    # in an if
    for op, _ in OPS:
        body += '    if a %s b {\n        printf(" T")\n    } else {\n        printf(" F")\n    }\n' % op
    body += '    printf(" |")\n'
    # as a selected value
    for n, (op, _) in enumerate(OPS):
        body += '    let s%d = if a %s b { 1 } else { 0 }\n' % (n, op)
    body += '    printf(" %d%d%d%d%d%d |", s0, s1, s2, s3, s4, s5)\n'
    # as a bool value
    body += '    printf(" %d%d%d%d%d%d |", ' + ', '.join('a %s b' % op for op, _ in OPS) + ')\n'
    # as a loop exit: a while condition, and a break
    for n, (op, _) in enumerate(OPS):
        body += '    var w%d = 0\n    while a %s b && w%d < 3 {\n        w%d += 1\n    }\n' % (n, op, n, n)
    body += '    printf(" %d%d%d%d%d%d |", w0, w1, w2, w3, w4, w5)\n'
    for n, (op, _) in enumerate(OPS):
        body += '    var u%d = 0\n    while u%d < 3 {\n        if a %s b {\n            break\n        }\n        u%d += 1\n    }\n' % (n, n, op, n)
    body += '    printf(" %d%d%d%d%d%d |", u0, u1, u2, u3, u4, u5)\n'
    # !(a < b) against a >= b; a mixed i64 operand
    body += '    let nlt = if !(a < b) { 1 } else { 0 }\n    let ge = if a >= b { 1 } else { 0 }\n'
    body += '    printf(" %d%d %d%d%d\\n", nlt, ge, k == a, k != a, k < b)\n}\n'
    out = ''
    for k in range(5):
        a, b = xs[k], ys[k]
        out += ''.join(' T' if f(a, b) else ' F' for _, f in OPS) + ' |'
        out += ' ' + ''.join('1' if f(a, b) else '0' for _, f in OPS) + ' |'
        out += ' ' + ''.join('1' if f(a, b) else '0' for _, f in OPS) + ' |'
        out += ' ' + ''.join('3' if f(a, b) else '0' for _, f in OPS) + ' |'
        out += ' ' + ''.join('0' if f(a, b) else '3' for _, f in OPS) + ' |'
        nlt = 1 if not (a < b) else 0
        ge = 1 if a >= b else 0
        out += ' %d%d %d%d%d\n' % (nlt, ge, float(k) == a, float(k) != a, float(k) < b)
    assert ' 0100' in out
    prog('opt_nan_cmp', ['the six f64 comparisons with a NaN operand (left, right, both), -0.0 against 0.0 and equal',
                         'values: in an if, as a selected value, as a bool, as a while condition and as a break test',
                         '(only != holds with NaN); !(a < b) against a >= b; i64 against f64 (LANGUAGE.md 6.4, 4.2)'],
         body, out)


# ============================================================ opt_live_calls
def opt_live_calls():
    body = '''fn note(k: i64) -> i64 {
    var t = 0
    for j in 0..k {
        t += j
    }
    printf("note %d %d\\n", k, t)
    return t
}
fn mix(n: i64, s: f64) -> f64 {
    let p = s * 3.0
    let q = s + 1.0
    let r = n * 5
    var tot = 0.0
    for i in 0..n {
        let t = note(i)
        tot = tot + p * f64(t) + q - f64(r)
    }
    return tot + p + q
}
let seed = 12345
let a1 = seed * 3 + 1
let a2 = seed - 77
let a3 = a1 * a2 % 1000003
let a4 = idiv(a3, 7)
let a5 = a1 + a2 + a3 + a4
let a6 = a5 % 11
let a7 = -a6 + a1
let a8 = a7 * 2
let f1 = f64(seed) / 7.0
let f2 = f1 * f1
let f3 = f2 - 0.1
let f4 = f3 / 3.0
let f5 = f1 + f4
let f6 = -f5
let f7 = f6 * 0.5
let f8 = f7 + f2
var acc = 0
var facc = 0.0
for i in 0..4 {
    printf("it %d\\n", i)
    let t = note(i)
    acc = acc + a1 + a2 + a3 + a4 + a5 + a6 + a7 + a8 + t + i
    facc = facc + f1 + f2 + f3 + f4 + f5 + f6 + f7 + f8
    printf("%d %.17g\\n", acc, facc)
}
note(5)
printf("%d %d %d %d %d %d %d %d\\n", a1, a2, a3, a4, a5, a6, a7, a8)
printf("%.17g %.17g %.17g %.17g\\n", f1, f2, f3, f4)
printf("%.17g %.17g %.17g %.17g\\n", f5, f6, f7, f8)
printf("%.17g\\n", mix(3, 0.5))
printf("%.17g\\n", mix(4, -2.25))
'''
    out = []

    def note(k):
        t = sum(range(k))
        out.append('note %d %d\n' % (k, t))
        return t

    def mix(n, s):
        p = s * 3.0
        q = s + 1.0
        r = n * 5
        tot = 0.0
        for i in range(n):
            t = note(i)
            tot = tot + p * float(t) + q - float(r)
        return tot + p + q

    seed = 12345
    a1 = seed * 3 + 1
    a2 = seed - 77
    a3 = a1 * a2 % 1000003
    a4 = a3 // 7
    a5 = a1 + a2 + a3 + a4
    a6 = a5 % 11
    a7 = -a6 + a1
    a8 = a7 * 2
    f1 = float(seed) / 7.0
    f2 = f1 * f1
    f3 = f2 - 0.1
    f4 = f3 / 3.0
    f5 = f1 + f4
    f6 = -f5
    f7 = f6 * 0.5
    f8 = f7 + f2
    acc, facc = 0, 0.0
    for i in range(4):
        out.append('it %d\n' % i)
        t = note(i)
        acc = acc + a1 + a2 + a3 + a4 + a5 + a6 + a7 + a8 + t + i
        facc = facc + f1 + f2 + f3 + f4 + f5 + f6 + f7 + f8
        out.append('%d %s\n' % (acc, e17(facc)))
    note(5)
    out.append('%d %d %d %d %d %d %d %d\n' % (a1, a2, a3, a4, a5, a6, a7, a8))
    out.append('%s %s %s %s\n' % tuple(e17(x) for x in (f1, f2, f3, f4)))
    out.append('%s %s %s %s\n' % tuple(e17(x) for x in (f5, f6, f7, f8)))
    v = mix(3, 0.5)
    out.append(e17(v) + '\n')
    v = mix(4, -2.25)
    out.append(e17(v) + '\n')
    prog('opt_live_calls', ['values computed before a loop and read after calls inside it (printf and a user',
                            'function with a loop, so a real call): eight i64 and eight f64 values in the main',
                            'program, three in a function (LANGUAGE.md 6.5, 6.8, 8.1)'], body, ''.join(out))


# ============================================================ opt_ref_scalar (T5)
def opt_ref_scalar():
    body = '''fn count_up(ref s: i64, n: i64) {
    for i in 0..n {
        s += i
    }
}
fn skip_some(ref s: i64, n: i64) {
    for i in 0..n {
        var j = 0
        while j < 4 {
            j += 1
            if j == 2 {
                continue
            }
            s += j * 10 + i
        }
        if i % 2 == 1 {
            continue
        }
        s += 1000
    }
}
fn until(ref s: i64, lim: i64) -> i64 {
    for i in 0..100 {
        s += i
        if s > lim {
            return i
        }
    }
    return -1
}
fn scale_loop(ref x: f64, n: i64) {
    var k = 0
    while k < n {
        x = x * 1.5 - 0.25
        k += 1
        if x > 100.0 {
            break
        }
    }
}
fn bump(ref s: i64) {
    s += 1
}
fn with_call(ref s: i64, n: i64) {
    for i in 0..n {
        s += 2
        bump(ref s)
        printf("w %d\\n", s)
    }
}
fn nested(ref s: i64, n: i64) -> i64 {
    var hits = 0
    for i in 0..n {
        for j in 0..n {
            if j > i {
                break
            }
            s += i * j
            if s > 40 {
                return hits
            }
            hits += 1
        }
    }
    return hits
}
var t = 5
count_up(ref t, 4)
printf("%d\\n", t)
for k in 0..3 {
    count_up(ref t, k)
    printf("%d\\n", t)
}
skip_some(ref t, 3)
printf("%d\\n", t)
var u = 0
let r = until(ref u, 20)
printf("%d %d\\n", r, u)
var u2 = 0
let r2 = until(ref u2, 100000)
printf("%d %d\\n", r2, u2)
var y = 1.0
scale_loop(ref y, 20)
printf("%.17g\\n", y)
var y2 = 1.0
scale_loop(ref y2, 3)
printf("%.17g\\n", y2)
with_call(ref t, 3)
printf("%d\\n", t)
var z = 0
for i in 0..5 {
    if i == 1 {
        continue
    }
    count_up(ref z, i)
    if i == 3 {
        continue
    }
    z += 100
}
printf("%d\\n", z)
var hz = 0
let h1 = nested(ref hz, 3)
printf("%d %d\\n", h1, hz)
var hz2 = 30
let h2 = nested(ref hz2, 4)
printf("%d %d\\n", h2, hz2)
'''
    out = []
    S = {}

    def count_up(v, n):
        for i in range(n):
            v = ck(v + i)
        return v

    def skip_some(s, n):
        for i in range(n):
            j = 0
            while j < 4:
                j += 1
                if j == 2:
                    continue
                s += j * 10 + i
            if i % 2 == 1:
                continue
            s += 1000
        return s

    def until(s, lim):
        for i in range(100):
            s += i
            if s > lim:
                return i, s
        return -1, s

    def scale_loop(x, n):
        k = 0
        while k < n:
            x = x * 1.5 - 0.25
            k += 1
            if x > 100.0:
                break
        return x

    def with_call(s, n):
        for i in range(n):
            s += 2
            s += 1
            out.append('w %d\n' % s)
        return s

    def nested(s, n):
        hits = 0
        for i in range(n):
            for j in range(n):
                if j > i:
                    break
                s += i * j
                if s > 40:
                    return hits, s
                hits += 1
        return hits, s

    t = count_up(5, 4)
    out.append('%d\n' % t)
    for k in range(3):
        t = count_up(t, k)
        out.append('%d\n' % t)
    t = skip_some(t, 3)
    out.append('%d\n' % t)
    r, u = until(0, 20)
    out.append('%d %d\n' % (r, u))
    r, u = until(0, 100000)
    out.append('%d %d\n' % (r, u))
    out.append(e17(scale_loop(1.0, 20)) + '\n')
    out.append(e17(scale_loop(1.0, 3)) + '\n')
    t = with_call(t, 3)
    out.append('%d\n' % t)
    z = 0
    for i in range(5):
        if i == 1:
            continue
        z = count_up(z, i)
        if i == 3:
            continue
        z += 100
    out.append('%d\n' % z)
    h, s = nested(0, 3)
    out.append('%d %d\n' % (h, s))
    h, s = nested(30, 4)
    out.append('%d %d\n' % (h, s))
    assert r == -1
    prog('opt_ref_scalar', ['a ref scalar updated in a loop and read by the caller afterwards: in a for loop, with a',
                            'continue of the inner while and of the outer for, with a return inside the loop (taken',
                            'and not), a break, an f64, passed on as ref to another function inside the loop, a',
                            'return from a nested loop, and calls inside the caller\'s loops (LANGUAGE.md 8.3, 7.5)'],
         body, ''.join(out))


# ============================================================ opt_ref_elem
def opt_ref_elem():
    body = PV + PVI + '''fn bump_all(ref x: f64, w: f64[], n: i64) {
    for i in 0..n {
        x = x + w[i]
        printf("%g %g\\n", x, w[3])
    }
}
fn twice(ref x: i64, src: i64[]) {
    for k in 0..len(src) {
        x = x * 2 + src[k]
    }
}
fn addto(ref x: f64, k: f64) {
    for j in 0..3 {
        x += k
    }
}
var v = zeros(5)
for i in 0..5 {
    v[i] = f64(i + 1)
}
let v2 = v
bump_all(ref v[3], v2, 3)
pv(v)
pv(v2)
var iv = filled(1, 4)
let iv2 = iv
for i in 0..4 {
    twice(ref iv[i], iv2)
}
pvi(iv)
pvi(iv2)
var M = zeros(2, 2)
let M2 = M
addto(ref M[1, 0], 0.5)
printf("%g %g %g %g / %g\\n", M[0, 0], M[1, 0], M[0, 1], M[1, 1], M2[1, 0])
'''
    out = ''
    v = [float(i + 1) for i in range(5)]
    v2 = list(v)
    x = v[3]
    for i in range(3):
        x = x + v2[i]
        out += '%s %s\n' % (g(x), g(v2[3]))
    v[3] = x
    out += pvf(v) + pvf(v2)
    iv = [1] * 4
    iv2 = list(iv)
    for i in range(4):
        x = iv[i]
        for k in range(len(iv2)):
            x = x * 2 + iv2[k]
        iv[i] = x
    out += pvi(iv) + pvi(iv2)
    m10 = 0.0
    for _ in range(3):
        m10 += 0.5
    out += '0 %s 0 0 / 0\n' % g(m10)
    prog('opt_ref_elem', ['a ref to an element of an array that another variable shares, with the other variable',
                          'passed beside it: f(ref v[3], v2) updating the element in a loop while reading v2, one',
                          'call per element in a loop, a matrix element; both arrays printed afterwards',
                          '(LANGUAGE.md 8.3, 4.5)'], body, out)


# ============================================================ opt_cow_loops
def opt_cow_loops():
    body = PV + '''fn ident(a: f64[]) -> f64[] {
    return a
}
fn fill_ref(ref v: f64[], k: f64) {
    for i in 0..len(v) {
        v[i] = v[i] + k
    }
}
fn total(a: f64[]) -> f64 {
    var t = 0.0
    for x in a {
        t += x
    }
    return t
}
var a = filled(1.0, 4)
var b = a
for i in 0..4 {
    b[i] = f64(i) * 2.0
}
pv(a)
pv(b)
var c = b
for i in 0..4 {
    if c[i] > 100.0 {
        c[i] = 0.0
    }
}
pv(c)
c[1] = -1.0
pv(c)
pv(b)
var d = b
let dsave = d
fill_ref(ref d, 0.5)
pv(d)
pv(dsave)
pv(b)
var u = zeros(3)
var snap = zeros(0)
for i in 0..3 {
    u[i] = f64(i + 1) * 10.0
    pv(snap)
    printf("%g\\n", total(u))
    snap = ident(u)
}
u[0] = -5.0
pv(u)
pv(snap)
var e = filled(3.0, 3)
let ecopy = e
for i in 0..3 {
    e[i] = f64(-i)
    printf("%g\\n", total(ecopy))
}
pv(e)
pv(ecopy)
var M = ones(2, 3)
let M0 = M
for j in 0..3 {
    M[1, j] = f64(j) + 0.25
}
printf("%g %g %g / %g %g %g\\n", M[1, 0], M[1, 1], M[1, 2], M0[1, 0], M0[1, 1], M0[1, 2])
'''
    out = ''
    a = [1.0] * 4
    b = [float(i) * 2.0 for i in range(4)]
    out += pvf(a) + pvf(b)
    c = list(b)
    out += pvf(c)
    c[1] = -1.0
    out += pvf(c) + pvf(b)
    d = [x + 0.5 for x in b]
    out += pvf(d) + pvf(b) + pvf(b)
    u = [0.0] * 3
    snap = []
    for i in range(3):
        u[i] = float(i + 1) * 10.0
        out += pvf(snap)
        t = 0.0
        for x in u:
            t += x
        out += g(t) + '\n'
        snap = list(u)
    u[0] = -5.0
    out += pvf(u) + pvf(snap)
    e = [3.0] * 3
    ecopy = list(e)
    for i in range(3):
        e[i] = float(-i)
        out += g(sum(ecopy)) + '\n'
    out += pvf(e) + pvf(ecopy)
    out += '%s %s %s / 1 1 1\n' % tuple(g(float(j) + 0.25) for j in range(3))
    prog('opt_cow_loops', ['copy on write in loops: a loop storing into an array another variable shares, a loop',
                           'whose stores are all skipped, a ref array parameter updated in a loop while the caller',
                           'keeps a copy, a loop storing into an array it also passes to functions (one returns it',
                           'and the result is kept), a copy made before a loop passed to a function inside it, a',
                           'matrix row (LANGUAGE.md 4.5, 8.2, 8.3)'], body, out)


# ============================================================ opt_dead_checks
def opt_dead_checks():
    body = '''fn probe(v: i64[], bad: i64, flag: bool, z: i64) -> i64 {
    var t = 0
    for i in 0..len(v) {
        if i > 100 {
            t += v[i + bad]
        }
        if flag {
            t += v[bad]
            t += idiv(1, z)
            t += bad * 9223372036854775807
        }
        t += v[i]
    }
    return t
}
let w = [1, 2, 3]
printf("%d\\n", probe(w, 7, false, 0))
printf("%d\\n", probe(w, -1, false, 0))
let never = len(w) > 10
var k = 0
while k < 3 {
    if never {
        printf("%d\\n", w[k + 50])
    }
    printf("k %d\\n", k)
    k += 1
}
let big = 9223372036854775807
for i in 0..4 {
    if never {
        printf("%d\\n", big + i)
    }
    if i < 0 {
        printf("%d\\n", w[i])
    }
}
printf("done\\n")
'''
    out = '6\n6\nk 0\nk 1\nk 2\ndone\n'
    prog('opt_dead_checks', ['checks inside if arms that never run: an arm whose condition is false at every',
                             'iteration and one whose condition is loop-invariant and false (an index out of bounds,',
                             'a division by zero, an overflow), in for and while loops: no error (LANGUAGE.md 5.4,',
                             '6.5, 6.6; DESIGN.md 5.8 T1, T8, T9)'], body, out)


# ============================================================ opt_index_pm1
def opt_index_pm1():
    body = PVI + '''fn neighbours(v: i64[], n: i64) -> i64 {
    var t = 0
    for j in 1..n - 1 {
        t += v[j - 1] * 100 + v[j + 1]
    }
    return t
}
let n = 6
var v = filled(0, n)
for i in 0..n {
    v[i] = i * i
}
for j in 1..n - 1 {
    printf(" %d", v[j - 1] + v[j + 1])
}
printf("\\n")
for j in 1..=n - 2 {
    printf(" %d", v[j + 1] - v[j - 1])
}
printf("\\n")
for i in n - 1..=0 step -1 {
    printf(" %d", v[i])
}
printf("\\n")
for i in 0..n step 2 {
    printf(" %d", v[i] + v[i + 1])
}
printf("\\n")
for i in n - 1..0 step -2 {
    printf(" %d", v[i] - v[i - 1])
}
printf("\\n")
for i in 0..n - 1 step 3 {
    printf(" %d", v[i + 2])
}
printf("\\n")
printf("%d %d %d\\n", neighbours(v, n), neighbours(v, 1), neighbours(v, 0))
let e = filled(0, 0)
printf("%d\\n", neighbours(e, 0))
for i in 9223372036854775805..=9223372036854775807 {
    printf(" %d", i - 9223372036854775800)
}
printf("\\n")
for i in -9223372036854775808..-9223372036854775805 {
    printf(" %d", i + 9223372036854775807)
}
printf("\\n")
for i in 9223372036854775806..=9223372036854775807 {
    printf(" %d", i + 0)
}
printf("\\n")
for i in -9223372036854775806..-9223372036854775808 step -1 {
    printf(" %d", -i)
}
printf("\\n")
for i in 0..4 {
    printf(" %d", (i + 9223372036854775803) - 9223372036854775800)
}
printf("\\n")
'''
    n = 6
    v = [i * i for i in range(n)]
    out = ''.join(' %d' % (v[j - 1] + v[j + 1]) for j in range(1, n - 1)) + '\n'
    out += ''.join(' %d' % (v[j + 1] - v[j - 1]) for j in range(1, n - 1)) + '\n'
    out += ''.join(' %d' % v[i] for i in range(n - 1, -1, -1)) + '\n'
    out += ''.join(' %d' % (v[i] + v[i + 1]) for i in range(0, n, 2)) + '\n'
    out += ''.join(' %d' % (v[i] - v[i - 1]) for i in range(n - 1, 0, -2)) + '\n'
    out += ''.join(' %d' % v[i + 2] for i in range(0, n - 1, 3)) + '\n'

    def nb(v, n):
        return sum(v[j - 1] * 100 + v[j + 1] for j in range(1, n - 1))
    out += '%d %d %d\n' % (nb(v, n), nb(v, 1), nb(v, 0))
    out += '0\n'
    out += ''.join(' %d' % (i - 9223372036854775800) for i in range(MAX - 2, MAX + 1)) + '\n'
    out += ''.join(' %d' % (i + MAX) for i in range(MIN, MIN + 3)) + '\n'
    out += ''.join(' %d' % i for i in range(MAX - 1, MAX + 1)) + '\n'
    out += ''.join(' %d' % ck(-i) for i in range(MIN + 2, MIN, -1)) + '\n'
    out += ''.join(' %d' % (ck(i + 9223372036854775803) - 9223372036854775800) for i in range(4)) + '\n'
    prog('opt_index_pm1', ['j - 1 and j + 1 over 1 .. n-1 and 1 ..= n-2, negative steps and steps 2 and 3, a',
                           'function called with n = 6, 1 and 0 (an empty array), ranges ending at 2^63 - 1 and',
                           'starting at -2^63 whose bodies stay in range: no error (LANGUAGE.md 5.1, 5.4, 6.5, 7.5;',
                           'DESIGN.md 5.8 T1)'], body, out)


# ============================================================ opt_while_zero
def opt_while_zero():
    body = '''fn trial(lim: i64, q: i64) -> i64 {
    var x = 1
    var i = 10
    while i < lim {
        x = q
        i += 1
    }
    return x
}
fn ftrial(lim: f64) -> f64 {
    var t = 2.5
    let inv = lim * 4.0
    while t > lim {
        t = inv
    }
    return t
}
printf("%d %d\\n", trial(3, 42), trial(12, 42))
printf("%g %g\\n", ftrial(10.0), ftrial(-1.0))
let z = 0
var y = 5
var k = 0
let inv = 7 * 3
while k < z {
    y = inv
    k += 1
}
printf("%d %d\\n", y, k)
var y2 = 6
for j in 0..z {
    y2 = inv + j
}
printf("%d\\n", y2)
let empty = zeros(0)
var y3 = 1.5
var c = 0
while c < len(empty) {
    y3 = empty[0]
    c += 1
}
printf("%g\\n", y3)
var y4 = -1
for j in 3..3 {
    y4 = j
}
for j in 3..=2 {
    y4 = j
}
for j in 0..5 step -1 {
    y4 = j
}
printf("%d\\n", y4)
'''
    # ftrial(10.0): t = 2.5 > 10.0 false: 2.5; ftrial(-1.0): 2.5 > -1.0, t = -4.0, -4.0 > -1.0 false
    out = '1 42\n2.5 -4\n5 0\n6\n1.5\n-1\n'
    prog('opt_while_zero', ['loops that run zero times assigning a loop-invariant value to a variable printed after',
                            'them (the old value is printed): while loops in functions and in the main program, an',
                            'empty for range, a while whose body reads an element of an empty array, empty and',
                            'wrong-direction ranges (LANGUAGE.md 7.4, 7.5, 5.1; DESIGN.md 5.8 T8)'], body, out)


# ============================================================ opt_facts
def opt_facts():
    body = '''fn at(v: i64[], k: i64) -> i64 {
    if k >= 0 {
        if k < len(v) {
            return v[k]
        }
    }
    return -1
}
fn clamp_at(v: i64[], k: i64) -> i64 {
    var j = k
    if k < 0 {
        j = 0
    } else if k > len(v) - 1 {
        j = len(v) - 1
    }
    return v[j]
}
fn early(v: i64[], k: i64) -> i64 {
    if k < 0 {
        return -2
    }
    if k >= len(v) {
        return -3
    }
    return v[k] * 2
}
let w = [10, 20, 30]
for k in -2..=4 {
    printf(" %d %d %d", at(w, k), clamp_at(w, k), early(w, k))
}
printf("\\n")
var m = 0
for k in -3..6 {
    if k >= 0 && k < 3 {
        m += w[k]
    }
    if k < 0 || k > 2 {
        continue
    }
    m += w[2 - k] * 1000
}
printf("%d\\n", m)
'''
    w = [10, 20, 30]
    out = ''
    for k in range(-2, 5):
        a = w[k] if 0 <= k < 3 else -1
        c = w[min(max(k, 0), 2)]
        e = -2 if k < 0 else (-3 if k >= 3 else w[k] * 2)
        out += ' %d %d %d' % (a, c, e)
    out += '\n'
    m = 0
    for k in range(-3, 6):
        if 0 <= k < 3:
            m += w[k]
        if k < 0 or k > 2:
            continue
        m += w[2 - k] * 1000
    out += '%d\n' % m
    prog('opt_facts', ['indices proved by dominating guards on parameters (nested ifs, else if, early returns,',
                       '&&, || with continue), each guard followed by code its facts do not cover, with indices on',
                       'both sides of every bound (LANGUAGE.md 5.4, 6.4; DESIGN.md 5.8 F5, F6)'], body, out)


# ============================================================ opt_vn (T3)
def opt_vn():
    body = PV + '''struct P {
    a: i64
    b: f64
}
fn alias_rd(ref a: f64[], b: f64[]) {
    let t = b[0]
    a[0] = 9.0
    let u = b[0]
    let s = a[0]
    printf("%g %g %g\\n", t, u, s)
}
fn ref_two(ref s: i64, ref t: i64) {
    s = 1
    t = 2
    let r1 = s + t
    s = 10
    let r2 = s + t
    printf("%d %d\\n", r1, r2)
}
fn setf(ref z: i64) {
    z = 42
}
var x = 5
let p = x * 3 + 1
x = x + 1
let q = x * 3 + 1
printf("%d %d\\n", p, q)
printf("%d %d %d\\n", x + 1, x + 1, (x + 1) * (x + 1))
let d1 = idiv(x, 7) + x % 7
x = x + 10
let d2 = idiv(x, 7) + x % 7
printf("%d %d\\n", d1, d2)
var v = zeros(3)
v[1] = 2.5
let a1 = v[1]
v[1] = a1 * 2.0
let a2 = v[1]
let a3 = v[1] + v[1]
printf("%g %g %g\\n", a1, a2, a3)
let w = v
v[1] = -1.0
printf("%g %g\\n", w[1], v[1])
var m = filled(4.0, 2)
let m2 = m
alias_rd(ref m, m2)
pv(m)
pv(m2)
var s1 = 0
var s2 = 0
ref_two(ref s1, ref s2)
printf("%d %d\\n", s1, s2)
var pt = P { a: 3, b: 1.5 }
let pa = pt.a
pt.a = pa + 4
let pb = pt.a
printf("%d %d\\n", pa, pb)
setf(ref pt.a)
printf("%d %d %g\\n", pt.a, pt.a + pt.a, pt.b)
var v2 = filled(0.5, 3)
let v3 = v2
for i in 0..3 {
    let r = v2[i]
    v2[i] = r + 1.0
    let r2 = v2[i]
    printf("%g %g %g\\n", r, r2, v3[i])
}
var n1 = 7
let c1 = n1 + 1000
n1 = -n1
let c2 = n1 + 1000
printf("%d %d\\n", c1, c2)
'''
    out = '16 19\n7 7 49\n'
    x = 6
    d1 = x // 7 + x % 7
    x += 10
    d2 = x // 7 + x % 7
    out += '%d %d\n' % (d1, d2)
    out += '2.5 5 10\n5 -1\n'
    out += '4 4 9\n' + pvf([9.0, 4.0]) + pvf([4.0, 4.0])
    out += '3 12\n10 2\n'
    out += '3 7\n42 84 1.5\n'
    for i in range(3):
        out += '0.5 1.5 0.5\n'
    out += '1007 993\n'
    prog('opt_vn', ['equal expressions and repeated loads around writes: a variable reassigned between two',
                    'equal expressions, equal operands in one call, a load after a store to its element, a',
                    'store into a shared array read through the other name, a ref array parameter and a value',
                    'parameter sharing one buffer, two ref scalars, a struct field stored, passed by ref and',
                    'reread, loads and stores of one element in a loop (LANGUAGE.md 4.5, 8.3; DESIGN.md 5.8 T3)'],
         body, out)


# ============================================================ struct fields and fixed-size array elements
FIELD_FNS = '''struct S {
    a: f64
    c: i64
}
fn next(p: S, n: i64) -> i64 {
    var t = 0
    for k in 0..n {
        t += k
    }
    return p.c + 1 + t
}
fn nexta(v: i64[3], n: i64) -> i64 {
    var t = 0
    for k in 0..n {
        t += k
    }
    return v[2] + 1 + t
}
'''


def opt_fields():
    body = FIELD_FNS + '''fn small(p: S) -> i64 {
    return p.c + 1
}
fn ops(p: S, v: i64[3]) {
    printf("%d %d %d %d\\n", p.c - 1, -p.c, v[0] * 2, v[1] - 1)
}
fn sweep(p: S, v: i64[3], n: i64) {
    for i in 0..n {
        printf(" %d %d", p.c + i, v[2] + i)
    }
    printf("\\n")
}
let s1 = S { a: 1.5, c: 41 }
let s2 = S { a: 0.5, c: 9223372036854775806 }
let s3 = S { a: 2.5, c: -9223372036854775807 }
let v1 = [1, 2, 9223372036854775806]
let v2 = [4611686018427387903, -9223372036854775807, -5]
printf("%d %d %d\\n", next(s1, 0), next(s1, 3), next(s2, 0))
printf("%d %d %d\\n", nexta(v1, 0), nexta(v2, 4), small(s2))
printf("%d %d\\n", small(s1), small(s3))
ops(s3, v2)
ops(s1, v1)
sweep(s2, v1, 2)
sweep(s1, v2, 3)
'''
    out = '%d %d %d\n' % (42, 42 + 3, MAX)
    out += '%d %d %d\n' % (MAX, -5 + 1 + 6, MAX)
    out += '%d %d\n' % (42, -9223372036854775806)
    out += '%d %d %d %d\n' % (ck(-9223372036854775807 - 1), ck(9223372036854775807), ck(4611686018427387903 * 2),
                              ck(-9223372036854775807 - 1))
    out += '%d %d %d %d\n' % (40, -41, 2, 1)
    out += ''.join(' %d %d' % (ck(9223372036854775806 + i), ck(9223372036854775806 + i)) for i in range(2)) + '\n'
    out += ''.join(' %d %d' % (41 + i, -5 + i) for i in range(3)) + '\n'
    prog('opt_fields', ['checked arithmetic on an i64 field of a struct parameter and on an element of a fixed-size',
                        'array parameter, in functions called for real and inlined, with results at the ends of the',
                        'i64 range but inside it: no error (LANGUAGE.md 6.5, 4.5, 4.6, 8.2; DESIGN.md 5.8 T1)'],
         body, out)


def field_errors():
    err_rt('r_opt_struct_ovf', ['p.c + 1 on the i64 field of a struct parameter holding 2^63 - 1: integer overflow at',
                                'that line, after a call that does not overflow (LANGUAGE.md 6.5, 4.6, 8.2)'],
           FIELD_FNS + 'let ok = S { a: 1.5, c: 41 }\nprintf("%d\\n", next(ok, 2))\n'
           'let big = S { a: 0.5, c: 9223372036854775807 }\nprintf("%d\\n", next(big, 0))\nprintf("never\\n")\n',
           'return p.c + 1', 'integer overflow', '%d\n' % (41 + 1 + 1))
    err_rt('r_opt_fixarr_ovf', ['v[2] + 1 on an element of a fixed-size i64[3] parameter holding 2^63 - 1: integer',
                                'overflow at that line, after a call that does not overflow (6.5, 4.5, 8.2)'],
           FIELD_FNS + 'let ok = [1, 2, 3]\nprintf("%d\\n", nexta(ok, 3))\n'
           'let big = [1, 2, 9223372036854775807]\nprintf("%d\\n", nexta(big, 0))\nprintf("never\\n")\n',
           'return v[2] + 1', 'integer overflow', '%d\n' % (3 + 1 + 3))


# ============================================================ == and != guards
# Facts of `==` and `!=` comparisons: in the part where the comparison fails (an else part, the code
# after an if whose part ends in return/break/continue, the first part of an ifz) a == b gives nothing
# beyond a != b, and a != b gives a == b (DESIGN.md 5.8 F5); each function below reads an element or
# adds 1 there with a value that fails.
EQ_FNS = {
    'inc': '''fn inc(x: i64) -> i64 {
    if x == 0 {
        return -1
    }
    return x + 1
}
''',
    'get': '''fn get(k: i64) -> i64 {
    let v = [10, 20, 30]
    if k < 0 {
        return -1
    }
    if k == 2 {
        return -2
    }
    return v[k]
}
''',
    'getd': '''fn getd(k: i64) -> i64 {
    let v = filled(10, 3)
    if k < 0 {
        return -1
    }
    if k == 2 {
        return -2
    }
    return v[k]
}
''',
    'dec': '''fn dec(x: i64) -> i64 {
    if x != -9223372036854775808 {
        return x
    } else {
        return x - 1
    }
}
''',
    'get2': '''fn get2(k: i64) -> f64 {
    let v = zeros(3)
    if k >= 3 {
        return -1.0
    }
    if k != -1 {
        return -2.0
    }
    return v[k]
}
''',
    'sel': '''fn sel(k: i64) -> f64 {
    let v = filled(1.5, 3)
    var r = 0.0
    if k < 0 {
        return -1.0
    }
    if k == 2 {
        r = -2.0
    } else {
        r = v[k]
    }
    return r
}
''',
    'show': '''fn show(k: i64) {
    let v = zeros(3)
    if k >= 0 {
        if !(k == 2) {
            printf("%d %g\\n", k, v[k])
        }
    }
}
''',
    'orf': '''fn orf(k: i64) -> f64 {
    let v = zeros(3)
    if k == 2 || k < 0 {
        return -1.0
    }
    return v[k]
}
''',
    'pick': '''fn pick(k: i64, n: i64) -> f64 {
    let v = zeros(3)
    var t = 0.0
    for i in 0..n {
        t += 1.0
    }
    if k < 0 {
        return -1.0
    }
    if k == 2 {
        return -2.0
    }
    return v[k] + t
}
''',
}
LOOP_EQ = '''let v = zeros(3)
var k = %d
while true {
    if k == %d {
        break
    }
    if k >= 0 {
        printf("%%d %%g\\n", k, v[k])
    }
    k += %d
}
'''
LOOP_EQ_ELSE = '''let v = zeros(3)
var k = %d
while true {
    if k == %d {
        break
    } else {
        if k >= 0 {
            printf("%%d %%g\\n", k, v[k])
        }
    }
    k += %d
}
'''
LOOP_NE_ELSE = '''let v = zeros(3)
var k = %d
while k < 3 {
    if k != %d {
        printf("%%d skip\\n", k)
    } else {
        printf("%%g\\n", v[k])
    }
    k += 1
}
'''
LOOP_NE_CONT = '''let v = zeros(3)
for i in %d..=0 step -1 {
    let k = i - 1
    if k != %d {
        printf("%%d\\n", k)
        continue
    }
    printf("%%g\\n", v[k])
}
'''


def opt_eq_guards():
    body = ''.join(EQ_FNS.values())
    body += 'printf("%d %d %d %d\\n", inc(5), inc(0), inc(-9223372036854775808), inc(9223372036854775806))\n'
    body += 'for k in -2..=2 {\n    printf(" %d %d %g %g", get(k), getd(k), sel(k), orf(k))\n}\nprintf("\\n")\n'
    body += 'let ks = [-2, 0, 1, 2, 3, 7]\nfor k in ks {\n    printf(" %g", get2(k))\n}\nprintf("\\n")\n'
    body += 'printf("%d %d %d\\n", dec(5), dec(-9223372036854775807), dec(9223372036854775807))\n'
    body += 'for k in -1..=2 {\n    show(k)\n    printf("%g\\n", pick(k, k + 2))\n}\n'
    body += '{\n' + LOOP_EQ % (0, 3, 1) + '}\n'
    body += '{\n' + LOOP_EQ_ELSE % (-1, 3, 2) + '}\n'
    body += '{\n' + LOOP_NE_ELSE % (-2, 1) + '}\n'
    body += '{\n' + LOOP_NE_CONT % (3, 1) + '}\n'
    out = '6 -1 %d %d\n' % (MIN + 1, MAX)
    for k in range(-2, 3):
        a = -1 if k < 0 else (-2 if k == 2 else [10, 20, 30][k])
        b = -1 if k < 0 else (-2 if k == 2 else 10)
        d = -1.0 if k < 0 else (-2.0 if k == 2 else 1.5)
        e = -1.0 if (k == 2 or k < 0) else 0.0
        out += ' %d %d %s %s' % (a, b, g(d), g(e))
    out += '\n'
    for k in (-2, 0, 1, 2, 3, 7):
        assert k != -1                                  # get2 reads v[-1] exactly when k == -1
        out += ' ' + g(-1.0 if k >= 3 else -2.0)
    out += '\n'
    out += '5 %d %d\n' % (MIN + 1, MAX)
    for k in range(-1, 3):
        if k >= 0 and not (k == 2):
            out += '%d 0\n' % k
        t = float(max(k + 2, 0))
        out += g(-1.0 if k < 0 else (-2.0 if k == 2 else 0.0 + t)) + '\n'
    out += '0 0\n1 0\n2 0\n'                          # LOOP_EQ: k = 0, 1, 2, then k == 3 breaks
    out += '1 0\n'                                    # LOOP_EQ_ELSE: k = -1 not printed, 1, then 3 breaks
    out += '-2 skip\n-1 skip\n0 skip\n0\n2 skip\n'    # LOOP_NE_ELSE: k == 1 reads v[1]
    out += '2\n0\n0\n-1\n'                            # LOOP_NE_CONT: k = 2, 1 (reads v[1]), 0, -1
    prog('opt_eq_guards', ['== and != guards whose failing part is used: an early return after x == 0, k == 2 after',
                           'k < 0 (fixed and dynamic arrays), an explicit else, !(k == 2), k == 2 || k < 0, a != whose',
                           'else adds or reads, a function with two call sites and a loop, loops left by break after',
                           '== and continued after !=: every access in range (LANGUAGE.md 5.4, 6.4, 6.5; DESIGN.md 5.8 F5)'],
         body, out)


def eq_errors():
    def fn_test(name, comment, fn, calls, marker, msg, out):
        err_rt(name, comment, EQ_FNS[fn] + calls, marker, msg, out)

    fn_test('r_opt_eq_ovf', ['x + 1 after an early return on x == 0: 2^63 - 1 is not 0, so the add overflows (6.5)'],
            'inc', 'printf("%d\\n", inc(5))\nprintf("%d\\n", inc(0))\nprintf("%d\\n", inc(9223372036854775807))\n',
            'return x + 1', 'integer overflow', '6\n-1\n')
    fn_test('r_opt_eq_oob', ['v[k] of a fixed [10, 20, 30] after the early returns k < 0 and k == 2: k = 7 (5.4)'],
            'get', 'printf("%d %d %d\\n", get(1), get(2), get(-3))\nprintf("%d\\n", get(7))\n',
            'return v[k]', oob(7, 0, 3), '20 -2 -1\n')
    fn_test('r_opt_eq_oob_dyn', ['the same with filled(10, 3): k = 3 (5.4)'],
            'getd', 'printf("%d %d %d\\n", getd(1), getd(2), getd(-3))\nprintf("%d\\n", getd(3))\n',
            'return v[k]', oob(3, 0, 3), '10 -2 -1\n')
    fn_test('r_opt_ne_ovf', ['x - 1 in the else part of x != -2^63 (so x is -2^63 there): integer overflow (6.5)'],
            'dec', 'printf("%d\\n", dec(5))\nprintf("%d\\n", dec(-9223372036854775808))\n',
            'return x - 1', 'integer overflow', '5\n')
    fn_test('r_opt_ne_oob', ['v[k] after k >= 3 and k != -1 returned: k is -1 there (5.4)'],
            'get2', 'printf("%g %g\\n", get2(1), get2(5))\nprintf("%g\\n", get2(-1))\n',
            'return v[k]', oob(-1, 0, 3), '-2 -1\n')
    fn_test('r_opt_eq_else', ['v[k] in the explicit else part of k == 2 (after k < 0 returned): k = 4 (5.4)'],
            'sel', 'printf("%g %g\\n", sel(1), sel(2))\nprintf("%g\\n", sel(4))\n',
            'r = v[k]', oob(4, 0, 3), '1.5 -2\n')
    fn_test('r_opt_eq_ifz', ['v[k] under k >= 0 and !(k == 2): k = 4 (5.4)'],
            'show', 'show(1)\nshow(2)\nshow(4)\nprintf("never\\n")\n',
            'v[k])', oob(4, 0, 3), '1 0\n')
    fn_test('r_opt_eq_or', ['v[k] after k == 2 || k < 0 returned: k = 5 (5.4, 6.4 short circuit)'],
            'orf', 'printf("%g %g %g\\n", orf(1), orf(2), orf(-4))\nprintf("%g\\n", orf(5))\n',
            'return v[k]', oob(5, 0, 3), '0 -1 -1\n')
    fn_test('r_opt_eq_call', ['the early returns k < 0 and k == 2 in a function with a loop and three call sites',
                              '(a real call, LANGUAGE.md 8.6): k = 5 (5.4)'],
            'pick', 'printf("%g\\n", pick(1, 2))\nprintf("%g\\n", pick(2, 0))\nprintf("%g\\n", pick(5, 1))\n',
            'return v[k] + t', oob(5, 0, 3), '2\n-2\n')
    err_rt('r_opt_ne_loop', ['a while true loop left by break on k == 2, reading v[k] under k >= 0 with k = 1, 3: the',
                             'second read fails (5.4, 7.4)'],
           LOOP_EQ % (1, 2, 2), 'v[k])', oob(3, 0, 3), '1 0\n')
    err_rt('r_opt_eq_loop_else', ['the same with the read in the explicit else part of k == 2 (5.4)'],
           LOOP_EQ_ELSE % (1, 2, 2), 'v[k])', oob(3, 0, 3), '1 0\n')
    err_rt('r_opt_ne_loop_else', ['while k < 3 reading v[k] in the else part of k != -1, k from -3: v[-1] (5.4)'],
           LOOP_NE_ELSE % (-3, -1), 'v[k])', oob(-1, 0, 3), '-3 skip\n-2 skip\n')
    err_rt('r_opt_ne_cont', ['k = i - 1 for i in 2 ..= 0 step -1: k != -1 prints and continues, then v[k] with',
                             'k = -1 (5.4, 7.5)'],
           LOOP_NE_CONT % (2, -1), 'v[k])', oob(-1, 0, 3), '1\n0\n')


def errors():
    # a loop printing a line per iteration, then out of bounds at a known iteration (a matrix column)
    out = ''.join('col %d\n1\n' % j for j in range(4)) + 'col 4\n'
    err_rt('r_opt_oob_iter', ['a loop prints a line per iteration, then A[1, j] is out of bounds at j = 4 (dimension 1,',
                              'extent 4): the lines before, then the error (LANGUAGE.md 5.4, 9.2)'],
           'let A = ones(3, 4)\nfor j in 0..6 {\n    printf("col %d\\n", j)\n    printf("%g\\n", A[1, j])\n}\n',
           'A[1, j]', oob(4, 1, 4), out)
    out = ''.join('%s\n' % g(i * 0.5) for i in range(4))
    err_rt('r_opt_oob_while', ['a while loop storing v[i] and printing it: the store at i = 4 fails (5.4, 5.5)'],
           'var v = zeros(4)\nvar i = 0\nwhile i < 10 {\n    v[i] = f64(i) * 0.5\n    printf("%g\\n", v[i])\n    i += 1\n}\n',
           'v[i] = f64(i)', oob(4, 0, 4), out)
    # an overflow and an out-of-bounds index in the same iteration, both orders
    x = MAX - 3
    out = ''.join('%d 1\n' % (x + i) for i in range(4))
    err_rt('r_opt_ovf_then_oob', ['x + i overflows and v[i] is out of bounds at the same iteration i = 4; the overflow',
                                  'comes first in the body, so it is reported (5.4, 6.5, 6.8 rule 5)'],
           'let v = filled(1, 4)\nlet x = %s\nfor i in 0..6 {\n    let t = x + i\n    let u = v[i]\n'
           '    printf("%%d %%d\\n", t, u)\n}\n' % ilit(x), 'let t = x + i', 'integer overflow', out)
    err_rt('r_opt_oob_then_ovf', ['the same with v[i] first in the body: the index error is reported (5.4, 6.5)'],
           'let v = filled(1, 4)\nlet x = %s\nfor i in 0..6 {\n    let u = v[i]\n    let t = x + i\n'
           '    printf("%%d %%d\\n", t, u)\n}\n' % ilit(x), 'let u = v[i]', oob(4, 0, 4), out)
    x = MAX - 3
    out = ''.join('%d\n' % (x + i) for i in range(4))
    err_rt('r_opt_ovf_oob_expr', ['(x + i) + v[i] in one expression: at i = 4 the left operand overflows before the',
                                  'index is evaluated (6.8 rule 5)'],
           'let v = filled(0, 4)\nlet x = %s\nfor i in 0..6 {\n    printf("%%d\\n", (x + i) + v[i])\n}\n' % ilit(x),
           '(x + i) + v[i]', 'integer overflow', out)
    err_rt('r_opt_oob_ovf_expr', ['v[i] + (x + i): at i = 4 the index of the left operand fails first (6.8 rule 5)'],
           'let v = filled(0, 4)\nlet x = %s\nfor i in 0..6 {\n    printf("%%d\\n", v[i] + (x + i))\n}\n' % ilit(x),
           'v[i] + (x + i)', oob(4, 0, 4), out)
    # j + 1 over 0..n fails at its last iteration; j - 1 over 0..n at its first
    err_rt('r_opt_jp1_last', ['v[j] + v[j + 1] over 0 .. n: j + 1 = n at the last iteration (5.4, 7.5)'],
           'let n = 5\nlet v = filled(2, n)\nfor j in 0..n {\n    printf("%d\\n", v[j] + v[j + 1])\n}\n',
           'v[j + 1]', oob(5, 0, 5), '4\n' * 4)
    err_rt('r_opt_jm1_first', ['v[j] - v[j - 1] over 0 .. n in a function with a parameter n: j - 1 = -1 at the first',
                               'iteration, after the output of an earlier call with an empty range (5.4, 7.5)'],
           'fn diffs(v: i64[], n: i64) {\n    for j in 0..n {\n        printf("%d\\n", v[j] - v[j - 1])\n    }\n'
           '    printf("end %d\\n", n)\n}\nlet w = [5, 7, 9]\ndiffs(w, 0)\ndiffs(w, 3)\n',
           'v[j - 1]', oob(-1, 0, 3), 'end 0\n')
    # ranges at the ends of the i64 range: the check of i + 1 / i - 1 stays
    out = '%d\n%d\n' % (MAX - 1, MAX)
    err_rt('r_opt_range_max', ['for i in 2^63 - 3 ..= 2^63 - 1 printing i + 1: integer overflow at the last iteration',
                               '(5.1, 6.5; DESIGN.md 5.8 T1 must keep this check)'],
           'for i in 9223372036854775805..=9223372036854775807 {\n    printf("%d\\n", i + 1)\n}\n',
           'i + 1', 'integer overflow', out)
    out = '%d\n%d\n' % (MIN + 1, MIN)
    err_rt('r_opt_range_min', ['a range counting down to -2^63 with step -1 printing i - 1: integer overflow at the',
                               'last iteration (5.1, 6.5)'],
           'for i in -9223372036854775806..=-9223372036854775808 step -1 {\n    printf("%d\\n", i - 1)\n}\n',
           'i - 1', 'integer overflow', out)
    sq = [i * i for i in (3037000498, 3037000499)]
    assert all(s <= MAX for s in sq) and 3037000500 ** 2 > MAX
    err_rt('r_opt_mul_last', ['i * i over 3037000498 ..= 3037000500: the last square exceeds 2^63 - 1 (6.5)'],
           'for i in 3037000498..=3037000500 {\n    printf("%d\\n", i * i)\n}\n',
           'i * i', 'integer overflow', ''.join('%d\n' % s for s in sq))
    err_rt('r_opt_neg_min', ['-x over the elements 5, -2^63 + 1, -2^63, 7: unary minus of -2^63 overflows (6.5)'],
           'let vals = [5, -9223372036854775807, -9223372036854775808, 7]\nfor x in vals {\n    printf("%d\\n", -x)\n}\n',
           '-x)', 'integer overflow', '-5\n9223372036854775807\n')
    # step 2 and a negative step failing at their last iterations
    err_rt('r_opt_step2_last', ['for i in 0 ..= 6 step 2 over a 6-element vector: i = 6 fails (5.1, 5.4)'],
           'let v = zeros(6)\nfor i in 0..=6 step 2 {\n    printf("%d %g\\n", i, v[i])\n}\n',
           'v[i])', oob(6, 0, 6), '0 0\n2 0\n4 0\n')
    err_rt('r_opt_stepneg_last', ['for i in 3 ..= -1 step -1 over a 4-element vector: i = -1 fails after four lines (5.1)'],
           'var v = zeros(4)\nfor i in 0..4 {\n    v[i] = f64(10 * (i + 1))\n}\nfor i in 3..=-1 step -1 {\n'
           '    printf("%g\\n", v[i])\n}\n', 'printf("%g\\n", v[i])', oob(-1, 0, 4), '40\n30\n20\n10\n')
    # facts that hold only inside a guard or a loop are not used after it
    err_rt('r_opt_empty_fact', ['a[n - 1] after an empty for i in 0 .. n with n = 0 (in a function whose earlier call',
                                'with n = 3 succeeds): index -1 of extent 0 (5.4, 7.5; DESIGN.md 5.8 F3, F6)'],
           'fn tail(n: i64) -> f64 {\n    let a = zeros(n)\n    var t = 0.0\n    for i in 0..n {\n        t += a[i]\n    }\n'
           '    return t + a[n - 1]\n}\nprintf("%g\\n", tail(3))\nprintf("%g\\n", tail(0))\n',
           'a[n - 1]', oob(-1, 0, 0), '0\n')
    err_rt('r_opt_empty_fact0', ['the same in the main program with the constant n = 0: the loop never runs, then',
                                 'a[n - 1] is index -1 of extent 0 (5.4)'],
           'let n = 0\nlet a = zeros(n)\nvar t = 0.0\nfor i in 0..n {\n    t += a[i]\n}\nprintf("%g\\n", t)\n'
           'printf("%g\\n", a[n - 1])\n', 'a[n - 1]', oob(-1, 0, 0), '0\n')
    err_rt('r_opt_break_fact', ['an index narrowed by two break tests inside a while true loop (0 <= k < len(v) in the',
                                'body), used after the loop with the value k = len(v) that the tests excluded (5.4, 7.5)'],
           'fn scan(v: i64[], start: i64) -> i64 {\n    var k = start\n    var acc = 0\n    while true {\n'
           '        if k < 0 {\n            break\n        }\n        if k >= len(v) {\n            break\n        }\n'
           '        acc += v[k]\n        k += 1\n    }\n    printf("acc %d\\n", acc)\n    return v[k]\n}\n'
           'let w = [1, 2, 3]\nprintf("%d\\n", scan(w, 1))\n', 'return v[k]', oob(3, 0, 3), 'acc 5\n')
    err_rt('r_opt_guard_fact', ['a dominating comparison on a parameter: v[k] proved inside if k >= 0 { if k < len(v)',
                                '{ ... } }, then read after both endifs with k = len(v); an early-return guard before',
                                'it works for every k (5.4, 6.4; DESIGN.md 5.8 F5, F6)'],
           'fn safe(v: i64[], k: i64) -> i64 {\n    if k < 0 {\n        return -1\n    }\n    if k >= len(v) {\n'
           '        return -1\n    }\n    return v[k]\n}\nfn pick(v: i64[], k: i64) -> i64 {\n    var t = 0\n'
           '    if k >= 0 {\n        if k < len(v) {\n            t = v[k]\n        }\n    }\n    printf("t %d\\n", t)\n'
           '    return t + v[k]\n}\nlet w = [4, 5, 6]\nprintf("%d %d %d\\n", safe(w, 2), safe(w, 3), safe(w, -1))\n'
           'printf("%d\\n", pick(w, 2))\nprintf("%d\\n", pick(w, 3))\n',
           'return t + v[k]', oob(3, 0, 3), '6 -1 -1\nt 6\n12\nt 0\n')
    err_rt('r_opt_guard_wide', ['a guard k >= 0 && k < 10 around v[k] for a 4-element v: the constant bound does not',
                                'cover the extent, so k = 4 fails inside the guard (5.4; DESIGN.md 5.8 F5)'],
           'let v = zeros(4)\nfor k in 2..8 {\n    if k >= 0 && k < 10 {\n        printf("%d %g\\n", k, v[k])\n    }\n}\n',
           'v[k])', oob(4, 0, 4), '2 0\n3 0\n')
    err_rt('r_opt_loop_fact', ['j = i inside a for over 0 .. len(v), then v[j + 1] after the loop with j = 4 (5.4)'],
           'let v = filled(7, 5)\nvar j = 0\nfor i in 0..len(v) {\n    j = i\n    printf("%d\\n", v[j])\n}\n'
           'printf("%d\\n", v[j + 1])\n', 'v[j + 1]', oob(5, 0, 5), '7\n' * 5)
    err_rt('r_opt_inv_arm', ['a check in an if arm whose condition is loop-invariant and true: it fails at the first',
                             'iteration after that iteration\'s line, never before it (DESIGN.md 5.8 T8, T9)'],
           'let v = zeros(3)\nlet bad = len(v) + 2\nlet flag = bad > 4\nvar i = 0\nwhile i < 3 {\n'
           '    printf("iter %d\\n", i)\n    if flag {\n        printf("%g\\n", v[bad])\n    }\n    i += 1\n}\n',
           'v[bad]', oob(5, 0, 3), 'iter 0\n')
    # a ref scalar updated in a loop with an error part-way
    err_rt('r_opt_ref_err', ['a ref scalar updated in a loop that prints it, with an index error part-way: the lines',
                             'before the error are what counts (8.3, 9.2; DESIGN.md 5.8 T5, L-ag)'],
           'fn accum(ref s: i64, v: i64[], n: i64) {\n    for i in 0..n {\n        s += v[i]\n        printf("%d\\n", s)\n'
           '    }\n}\nvar t = 100\nlet v = [1, 2, 3]\naccum(ref t, v, 2)\nprintf("t %d\\n", t)\naccum(ref t, v, 5)\n'
           'printf("t %d\\n", t)\n', 's += v[i]', oob(3, 0, 3), '101\n103\nt 103\n104\n106\n109\n')
    err_rt('r_opt_cow_err', ['a loop storing into an array another variable shares, printing both, with an index',
                             'error at i = 3: the other variable kept its values (4.5, 5.5)'],
           'var a = filled(1.0, 3)\nvar b = a\nfor i in 0..5 {\n    b[i] = f64(i) + 0.5\n    printf("%g %g\\n", a[i], b[i])\n}\n',
           'b[i] = f64(i)', oob(3, 0, 3), '1 0.5\n1 1.5\n1 2.5\n')
    # % 0 and idiv(x, 0) with a constant 0; idiv(-2^63, -1)
    err_rt('r_opt_mod_zero', ['x % 0 with the constant 0 after x % 3 loops: integer division by zero at its line (6.6)'],
           'let xs = [7, -7, 3]\nfor x in xs {\n    printf("%d\\n", x % 3)\n}\nfor x in xs {\n    printf("%d\\n", x % 0)\n}\n',
           'x % 0', 'integer division by zero', '1\n2\n0\n')
    err_rt('r_opt_idiv_zero', ['idiv(x, 0) with the constant 0 after idiv(x, 2): integer division by zero (6.6)'],
           'let xs = [7, -7, 3]\nfor x in xs {\n    printf("%d\\n", idiv(x, 2))\n}\nfor x in xs {\n'
           '    printf("%d\\n", idiv(x, 0))\n}\n', 'idiv(x, 0)', 'integer division by zero', '3\n-4\n1\n')
    err_rt('r_opt_idiv_min', ['x % -1 and idiv(x, -1) over 9, -2^63 + 1, -2^63: the % is 0, then idiv(-2^63, -1)',
                              'overflows (6.6)'],
           'let xs = [9, -9223372036854775807, -9223372036854775808]\nfor x in xs {\n'
           '    printf("%d %d\\n", x % -1, idiv(x, -1))\n}\n', 'idiv(x, -1)', 'integer overflow',
           '0 -9\n0 9223372036854775807\n')
    # two equal additions, the first of which overflows: the first one's line
    big = MAX - 7
    out = 'start\n%d\n%d\n' % (big + 3, big + 4 + 3)
    err_rt('r_opt_vn_ovf', ['two equal checked additions after the variable changed: the first overflowing one is',
                            'reported at its own line (6.5; DESIGN.md 5.8 T3)'],
           'var big = %s\nprintf("start\\n")\nlet p1 = big + 3\nprintf("%%d\\n", p1)\nbig = big + 4\nlet p2 = big + 3\n'
           'printf("%%d\\n", p2)\nlet p3 = big + 4\nlet p4 = big + 4\nprintf("%%d %%d\\n", p3, p4)\n' % ilit(big),
           'let p3 = big + 4', 'integer overflow', out)


# ============================================================================ 5c-2 additions
# Adversarial run tests for the loop transformations of pass 3c (DESIGN.md 5.8 T5 promotion, T6 copy-on-write
# versioning, T7 strength reduction, T8 hoisting with anticipation and object pointers (L-at), T9 unswitching
# with the placement of L-bm, T10's deletion of dead selections (L-bn), T4's self-reading selection (L-bq)) and
# the allocator's loop liveness (Decision 75). Every expected byte comes from the model below (LANGUAGE.md
# semantics), never from a run of the compiler.

class Acc:
    def __init__(self, total, count, hist):
        self.total, self.count, self.hist = total, count, list(hist)

    def copy(self):
        return Acc(self.total, self.count, self.hist)


# ============================================================ opt_promote_exits (T5)
def opt_promote_exits():
    body = '''struct Acc {
    total: i64
    count: i64
    hist: i64[4]
}
fn tally(ref a: Acc, v: i64[]) -> i64 {
    for i in 0..len(v) {
        if v[i] < 0 {
            return i
        }
        a.total += v[i]
        a.count += 1
        a.hist[v[i] % 4] += 1
    }
    return -1
}
fn pacc(a: Acc) {
    printf("%d %d [%d %d %d %d]\\n", a.total, a.count, a.hist[0], a.hist[1], a.hist[2], a.hist[3])
}
fn inner_ret(ref s: i64, n: i64) -> i64 {
    var rounds = 0
    for i in 0..n {
        var j = 0
        while true {
            if j >= i {
                break
            }
            s += j
            j += 1
            if s > 50 {
                return rounds
            }
        }
        rounds += 1
        if i % 3 == 0 {
            continue
        }
        s = s * 2 - 1
    }
    return rounds
}
fn mix(ref q: i64[3], ks: i64[]) {
    for k in ks {
        q[1] += 10
        q[k] += 1
        q[2] = q[1] + q[k]
    }
}
fn local_acc(v: i64[]) -> i64 {
    var acc = [0, 0, 0]
    for i in 0..len(v) {
        acc[0] += v[i]
        acc[i % 3] += 1
        acc[2] = acc[0] - acc[1]
    }
    return acc[0] * 10000 + acc[1] * 100 + acc[2]
}
fn peek(x: i64) -> i64 {
    return x * 3
}
fn with_peek(ref s: i64, n: i64) {
    for i in 0..n {
        s += i
        printf("p %d %d\\n", s, peek(s))
    }
}
fn relax(ref x: f64, lim: f64) -> i64 {
    var k = 0
    while x < lim {
        x = x * 2.0 + 1.0
        k += 1
    }
    return k
}
fn grid_sum(ref s: i64, m: i64[,]) -> i64 {
    for j in 0..cols(m) {
        for i in 0..rows(m) {
            if m[i, j] == 0 {
                break
            }
            s += m[i, j]
        }
        s *= 2
        if s > 1000 {
            return j
        }
    }
    return -1
}
fn twice_ref(ref s: i64, ref t: i64, n: i64) {
    for i in 0..n {
        s += 1
        t += s
        if t > 20 {
            s = 0
        }
    }
}
var a = Acc { total: 0, count: 0, hist: [0, 0, 0, 0] }
let r1 = tally(ref a, [3, 5, 2, 7, 8])
printf("%d\\n", r1)
pacc(a)
let r2 = tally(ref a, [1, 6, -4, 9])
printf("%d\\n", r2)
pacc(a)
var accs = filled(a, 3)
let r3 = tally(ref accs[1], [10, 11, -1])
printf("%d\\n", r3)
for k in 0..3 {
    pacc(accs[k])
}
var s = 0
let k1 = inner_ret(ref s, 10)
printf("%d %d\\n", k1, s)
var s2 = 0
let k2 = inner_ret(ref s2, 4)
printf("%d %d\\n", k2, s2)
var q = [1, 2, 3]
mix(ref q, [0, 1, 2, 1, 1, 0])
printf("%d %d %d\\n", q[0], q[1], q[2])
printf("%d\\n", local_acc([5, 7, 9, 11, 13]))
var s3 = 7
with_peek(ref s3, 4)
printf("%d\\n", s3)
var x1 = 1.0
let n1 = relax(ref x1, 100.0)
printf("%d %g\\n", n1, x1)
var x2 = 1.0
let n2 = relax(ref x2, nan)
printf("%d %g\\n", n2, x2)
var x3 = nan
let n3 = relax(ref x3, 5.0)
printf("%d %g\\n", n3, x3)
var m = filled(0, 3, 4)
for j in 0..4 {
    for i in 0..3 {
        m[i, j] = i + 2 * j + 1
    }
}
m[1, 2] = 0
var gs = 0
let g1 = grid_sum(ref gs, m)
printf("%d %d\\n", g1, gs)
var gs2 = 300
let g2 = grid_sum(ref gs2, m)
printf("%d %d\\n", g2, gs2)
var p1 = 0
var p2 = 0
twice_ref(ref p1, ref p2, 8)
printf("%d %d\\n", p1, p2)
'''
    out = []

    def tally(a, v):
        for i, x in enumerate(v):
            if x < 0:
                return i
            a.total = ck(a.total + x)
            a.count += 1
            a.hist[x % 4] += 1
        return -1

    def pacc(a):
        out.append('%d %d [%d %d %d %d]\n' % ((a.total, a.count) + tuple(a.hist)))

    def inner_ret(s, n):
        rounds = 0
        for i in range(n):
            j = 0
            while True:
                if j >= i:
                    break
                s += j
                j += 1
                if s > 50:
                    return rounds, s
            rounds += 1
            if i % 3 == 0:
                continue
            s = s * 2 - 1
        return rounds, s

    a = Acc(0, 0, [0, 0, 0, 0])
    out.append('%d\n' % tally(a, [3, 5, 2, 7, 8]))
    pacc(a)
    out.append('%d\n' % tally(a, [1, 6, -4, 9]))
    pacc(a)
    accs = [a.copy() for _ in range(3)]
    out.append('%d\n' % tally(accs[1], [10, 11, -1]))
    for k in range(3):
        pacc(accs[k])
    out.append('%d %d\n' % inner_ret(0, 10))
    out.append('%d %d\n' % inner_ret(0, 4))
    q = [1, 2, 3]
    for k in [0, 1, 2, 1, 1, 0]:
        q[1] += 10
        q[k] += 1
        q[2] = q[1] + q[k]
    out.append('%d %d %d\n' % tuple(q))
    acc = [0, 0, 0]
    v = [5, 7, 9, 11, 13]
    for i in range(len(v)):
        acc[0] += v[i]
        acc[i % 3] += 1
        acc[2] = acc[0] - acc[1]
    out.append('%d\n' % (acc[0] * 10000 + acc[1] * 100 + acc[2]))
    s3 = 7
    for i in range(4):
        s3 += i
        out.append('p %d %d\n' % (s3, s3 * 3))
    out.append('%d\n' % s3)
    for x, lim in ((1.0, 100.0), (1.0, NAN), (NAN, 5.0)):
        k = 0
        while x < lim:
            x = x * 2.0 + 1.0
            k += 1
        out.append('%d %s\n' % (k, g(x)))
    mm = [[i + 2 * j + 1 for j in range(4)] for i in range(3)]
    mm[1][2] = 0

    def grid_sum(s):
        for j in range(4):
            for i in range(3):
                if mm[i][j] == 0:
                    break
                s += mm[i][j]
            s *= 2
            if s > 1000:
                return j, s
        return -1, s
    out.append('%d %d\n' % grid_sum(0))
    out.append('%d %d\n' % grid_sum(300))
    s, t = 0, 0
    for i in range(8):
        s += 1
        t += s
        if t > 20:
            s = 0
    out.append('%d %d\n' % (s, t))
    prog('opt_promote_exits', ['ref scalars, ref struct fields and fixed-size array elements updated in loops (DESIGN.md',
                               '5.8 T5): a return inside the loop taken and not, a ref element of a struct array, a',
                               'return from an inner while, continue of the outer loop, a ref fixed-size array updated at',
                               'a constant and a variable index that meet, a local fixed-size array, a value passed to a',
                               'call inside the loop, a while left at once by a NaN bound, a ref read after a nested',
                               'loop with break, two ref parameters (LANGUAGE.md 8.3, 7.5, 4.5, 4.6)'],
         body, ''.join(out))


# ============================================================ opt_cow_alias (T6)
def opt_cow_alias():
    body = PV + '''struct Holder {
    data: f64[]
    tag: i64
}
fn modify_copy(a: f64[]) -> f64 {
    var w = a
    for i in 0..len(w) {
        w[i] = w[i] * 10.0 + 1.0
    }
    return w[0] + w[len(w) - 1]
}
fn negate(a: f64[]) -> f64[] {
    var a = a
    for i in 0..len(a) {
        a[i] = -a[i]
    }
    return a
}
fn ref_and_val(ref d: f64[], e: f64[]) {
    let n = len(d)
    for i in 0..n {
        d[i] = e[(i + 1) % n] + 100.0
    }
}
fn ret_inside(a: f64[], stop: i64) -> f64[] {
    var b = a
    for i in 0..len(b) {
        b[i] = f64(i) + 0.5
        if i == stop {
            return b
        }
    }
    return b
}
fn bump_all(ref v: f64[], k: f64) {
    for i in 0..len(v) {
        v[i] += k
    }
}
fn fill_holder(ref h: Holder) {
    for i in 0..len(h.data) {
        h.data[i] = f64(h.tag + i)
    }
}
fn two(ref p: f64[], ref q: f64[]) {
    for i in 0..len(p) {
        p[i] = f64(i) + 1.0
        q[i] = f64(i) * 2.0 + 0.5
    }
}
var base = zeros(4)
for i in 0..4 {
    base[i] = f64(i + 1)
}
printf("%g\\n", modify_copy(base))
pv(base)
let neg = negate(base)
pv(neg)
pv(base)
var d = base
let e = d
ref_and_val(ref d, e)
pv(d)
pv(e)
pv(base)
var d2 = zeros(3)
let e2 = ones(3)
ref_and_val(ref d2, e2)
pv(d2)
var ra = zeros(4)
var snap = ra
for i in 0..4 {
    snap = ra
    ra[i] = f64(i) * 3.0 + 1.0
    printf("%g %g\\n", snap[i], ra[i])
}
pv(snap)
pv(ra)
var a2 = zeros(4)
var keep = zeros(0)
for i in 0..4 {
    a2[i] = f64(i) + 0.5
    if i == 1 {
        keep = a2
    }
}
pv(keep)
pv(a2)
var h = Holder { data: zeros(0), tag: 0 }
var c = zeros(3)
for i in 0..3 {
    c[i] = f64(i) + 7.0
    if i == 0 {
        h.data = c
        h.tag = 9
    }
}
pv(h.data)
pv(c)
printf("%d\\n", h.tag)
pv(ret_inside(base, 1))
pv(ret_inside(base, 10))
pv(base)
var z = base
let nz = 0
for i in 0..nz {
    z[i] = 9.0
}
var kz = 5
while kz < 3 {
    z[kz] = 1.0
    kz += 1
}
z[0] = 42.0
pv(z)
pv(base)
var p = zeros(3)
var q = zeros(3)
let pkeep = p
two(ref p, ref q)
pv(p)
pv(q)
pv(pkeep)
var p2 = zeros(2)
var q2 = zeros(2)
let qkeep = q2
two(ref p2, ref q2)
pv(p2)
pv(q2)
pv(qkeep)
var p3 = zeros(2)
var q3 = zeros(2)
two(ref p3, ref q3)
pv(p3)
pv(q3)
var u1 = zeros(3)
bump_all(ref u1, 1.0)
let u1save = u1
bump_all(ref u1, 2.0)
pv(u1)
pv(u1save)
var hs = filled(Holder { data: zeros(3), tag: 1 }, 2)
for i in 0..3 {
    hs[0].data[i] = f64(i) + 0.25
}
pv(hs[0].data)
pv(hs[1].data)
var h2 = Holder { data: zeros(3), tag: 5 }
let h2save = h2
fill_holder(ref h2)
pv(h2.data)
pv(h2save.data)
var h3 = Holder { data: zeros(2), tag: -3 }
fill_holder(ref h3)
pv(h3.data)
var M = zeros(2, 3)
let M0 = M
for j in 0..3 {
    for i in 0..2 {
        M[i, j] = f64(i * 10 + j)
    }
}
pv(M.flat)
pv(M0.flat)
'''
    out = ''
    base = [float(i + 1) for i in range(4)]
    w = [x * 10.0 + 1.0 for x in base]
    out += g(w[0] + w[-1]) + '\n' + pvf(base)
    out += pvf([-x for x in base]) + pvf(base)
    e = list(base)
    d = [e[(i + 1) % 4] + 100.0 for i in range(4)]
    out += pvf(d) + pvf(e) + pvf(base)
    out += pvf([1.0 + 100.0] * 3)
    ra = [0.0] * 4
    snap = list(ra)
    for i in range(4):
        snap = list(ra)
        ra[i] = float(i) * 3.0 + 1.0
        out += '%s %s\n' % (g(snap[i]), g(ra[i]))
    out += pvf(snap) + pvf(ra)
    a2 = [0.0] * 4
    keep = []
    for i in range(4):
        a2[i] = float(i) + 0.5
        if i == 1:
            keep = list(a2)
    out += pvf(keep) + pvf(a2)
    c = [0.0] * 3
    hdata, htag = [], 0
    for i in range(3):
        c[i] = float(i) + 7.0
        if i == 0:
            hdata, htag = list(c), 9
    out += pvf(hdata) + pvf(c) + '%d\n' % htag
    for stop in (1, 10):
        b = list(base)
        for i in range(4):
            b[i] = float(i) + 0.5
            if i == stop:
                break
        out += pvf(b)
    out += pvf(base)
    z = list(base)
    z[0] = 42.0
    out += pvf(z) + pvf(base)

    def two(n):
        return [float(i) + 1.0 for i in range(n)], [float(i) * 2.0 + 0.5 for i in range(n)]
    p, q = two(3)
    out += pvf(p) + pvf(q) + pvf([0.0] * 3)
    p, q = two(2)
    out += pvf(p) + pvf(q) + pvf([0.0] * 2)
    out += pvf(p) + pvf(q)
    out += pvf([3.0] * 3) + pvf([1.0] * 3)
    out += pvf([float(i) + 0.25 for i in range(3)]) + pvf([0.0] * 3)
    out += pvf([float(5 + i) for i in range(3)]) + pvf([0.0] * 3)
    out += pvf([float(-3 + i) for i in range(2)])
    Mf = [0.0] * 6
    for j in range(3):
        for i in range(2):
            Mf[i + 2 * j] = float(i * 10 + j)
    out += pvf(Mf) + pvf([0.0] * 6)
    prog('opt_cow_alias', ['copy on write in loops with aliases (DESIGN.md 5.8 T6): a var copy of a parameter stored in',
                           'a loop (the caller keeps its values), a parameter shadowed by var, a ref array and a value',
                           'parameter sharing one buffer, a copy retained inside the loop at every iteration and at one,',
                           'the array stored into a struct field inside the loop, returned inside the loop, loops run',
                           'zero times, two arrays stored in one loop with either or neither shared, a ref array shared',
                           'only at the second call, an array field shared by filled() elements, a ref struct\'s array',
                           'field, a matrix stored column by column (LANGUAGE.md 4.5, 4.6, 8.2, 8.3)'], body, out)


# ============================================================ opt_hoist_guard (T8)
def opt_hoist_guard():
    body = '''struct Box {
    vals: f64[]
    scale: f64
    n: i64
}
fn zero_trip(v: f64[], bad: i64, big: i64, z: i64, n: i64, f: f64) -> i64 {
    var t = 0
    for i in 0..n {
        t += i64(v[bad]) + (big + 100) + idiv(7, z) + i64(f)
    }
    var k = 0
    while k < n {
        t += idiv(big, z) + i64(v[bad + 1])
        k += 1
    }
    for x in v[0..n] {
        t += i64(x) + (big + 100)
    }
    return t
}
fn early(v: f64[], bad: i64, big: i64, z: i64) -> i64 {
    var t = 0
    for i in 0..5 {
        if i >= 0 {
            break
        }
        t += i64(v[bad]) + big * 2 + idiv(1, z)
    }
    for i in 0..5 {
        t += i
        if i < 10 {
            continue
        }
        t += i64(v[bad]) + (big + 1) + idiv(1, z)
    }
    var j = 0
    while j < 4 {
        j += 1
        if j > 0 {
            return t * 100 + j
        }
        t += i64(v[bad])
    }
    return -1
}
fn box_sum(b: Box, reps: i64) -> f64 {
    var t = 0.0
    for r in 0..reps {
        for i in 0..b.n {
            t += b.vals[i] * b.scale
        }
    }
    return t
}
fn box_grow(ref b: Box, reps: i64) {
    for r in 0..reps {
        b.scale = b.scale * 2.0
        b.n = b.n + 1
        printf("%g %d %d\\n", b.scale, b.n, len(b.vals))
    }
}
fn guarded(v: f64[], k: i64, n: i64) -> f64 {
    var t = 0.0
    for i in 0..n {
        if k < len(v) {
            t += v[k]
        } else {
            t -= 1.0
        }
    }
    return t
}
let v = [1.0, 2.0, 3.0]
printf("%d\\n", zero_trip(v, 0, 5, 1, 2, 3.0))
printf("%d\\n", zero_trip(v, 1000000000, 9223372036854775807, 0, 0, 2.5))
printf("%d\\n", early(v, 99, 9223372036854775807, 0))
let b1 = Box { vals: [1.0, 2.0, 3.0], scale: 0.5, n: 3 }
printf("%g\\n", box_sum(b1, 2))
let b2 = Box { vals: zeros(0), scale: nan, n: 99 }
printf("%g\\n", box_sum(b2, 0))
let b3 = Box { vals: zeros(0), scale: 2.0, n: 0 }
printf("%g\\n", box_sum(b3, 4))
let b4 = Box { vals: [4.0, 8.0, 16.0], scale: 0.25, n: 2 }
printf("%g\\n", box_sum(b4, 3))
var bx = Box { vals: ones(2), scale: 1.5, n: 0 }
box_grow(ref bx, 3)
box_grow(ref bx, 0)
printf("%g %d\\n", bx.scale, bx.n)
printf("%g\\n", guarded(zeros(0), 5, 3))
printf("%g\\n", guarded(v, 2, 4))
printf("%g\\n", guarded(zeros(0), 0, 2))
printf("%g\\n", guarded(v, 3, 0))
'''
    out = ''
    vv = [1.0, 2.0, 3.0]
    t = 0
    for i in range(2):
        t += int(vv[0]) + (5 + 100) + 7 // 1 + 3
    for k in range(2):
        t += 5 // 1 + int(vv[1])
    for x in vv[0:2]:
        t += int(x) + 105
    out += '%d\n' % t
    out += '0\n'
    t = sum(range(5))
    out += '%d\n' % (t * 100 + 1)
    out += g(2 * sum(x * 0.5 for x in vv)) + '\n'
    out += g(0.0) + '\n' + g(0.0) + '\n'
    tt = 0.0
    for r in range(3):
        for i in range(2):
            tt += [4.0, 8.0, 16.0][i] * 0.25
    out += g(tt) + '\n'
    sc, n = 1.5, 0
    for r in range(3):
        sc *= 2.0
        n += 1
        out += '%s %d %d\n' % (g(sc), n, 2)
    out += '%s %d\n' % (g(sc), n)
    out += g(-3.0) + '\n'
    out += g(3.0 * 4) + '\n'
    out += g(-2.0) + '\n'
    out += g(0.0) + '\n'
    prog('opt_hoist_guard', ['loop-invariant failing operations that must not run (DESIGN.md 5.8 T8): an index far out',
                             'of bounds, an overflow, a zero divisor and a conversion of 2.5 in loops run zero times',
                             '(for, while, an element loop over an empty slice), after a break taken at once, after a',
                             'continue taken at every iteration, after a return; struct fields read through a parameter',
                             'in loops run zero times with a count field the array does not cover, a ref struct whose',
                             'fields change in the loop, an element read under an invariant guard on an empty array',
                             '(LANGUAGE.md 5.4, 6.5, 6.6, 7.4, 7.5, 9.2)'], body, out)


def hoist_errors():
    err_rt('r_opt_hoist_after', ['v[bad] inside a loop run zero times and again after it: the error is the one after the',
                                 'loop, at its line, after the loop\'s output (DESIGN.md 5.8 T8; LANGUAGE.md 5.4, 9.2)'],
           'fn tailread(v: f64[], bad: i64, n: i64) -> f64 {\n    var t = 0.0\n    for i in 0..n {\n        t += v[bad]\n'
           '    }\n    printf("loop done %g\\n", t)\n    return t + v[bad]\n}\nlet v = zeros(3)\n'
           'printf("%g\\n", tailread(v, 1, 2))\nprintf("%g\\n", tailread(v, 7, 0))\n',
           'return t + v[bad]', oob(7, 0, 3), 'loop done 0\n0\nloop done 0\n')
    err_rt('r_opt_hoist_far', ['a loop-invariant constant index 10^9 into a 3-element vector, after the iteration\'s line:',
                               'the first iteration prints, then the index error (the load is never made before its check)'],
           'let v = zeros(3)\nvar t = 0.0\nfor i in 0..4 {\n    printf("iter %d\\n", i)\n    t += v[1000000000]\n}\n'
           'printf("%g\\n", t)\n', 't += v[1000000000]', oob(1000000000, 0, 3), 'iter 0\n')
    err_rt('r_opt_hoist_empty', ['e[k] with an invariant k in a loop, on a 4-element parameter and then on an empty one:',
                                 'the empty array fails at the first iteration, after its line (5.4; T8 L-at)'],
           'fn sum_at(e: f64[], k: i64, n: i64) -> f64 {\n    var s = 0.0\n    for i in 0..n {\n        printf("i %d\\n", i)\n'
           '        s += e[k]\n    }\n    return s\n}\nlet full = ones(4)\nprintf("%g\\n", sum_at(full, 3, 2))\n'
           'let e = zeros(0)\nprintf("%g\\n", sum_at(e, 2, 3))\n',
           's += e[k]', oob(2, 0, 0), 'i 0\ni 1\n2\ni 0\n')
    err_rt('r_opt_hoist_ovf', ['a loop-invariant big + 100 overflowing in a while loop after the iteration\'s line (6.5)'],
           'let big = 9223372036854775800\nvar t = 0\nvar i = 0\nwhile i < 3 {\n    printf("w %d\\n", i)\n'
           '    t = big + 100\n    i += 1\n}\nprintf("%d\\n", t)\n', 't = big + 100', 'integer overflow', 'w 0\n')
    err_rt('r_opt_hoist_div', ['loop-invariant idiv(a, z) and a % z, with z = 5 and then z = 0: the second call fails at its',
                               'first iteration, after the iteration\'s line (6.6)'],
           'fn ratio(a: i64, z: i64, n: i64) -> i64 {\n    var t = 0\n    for i in 0..n {\n        printf("r %d\\n", i)\n'
           '        t += idiv(a, z) + a % z\n    }\n    return t\n}\nprintf("%d\\n", ratio(17, 5, 2))\n'
           'printf("%d\\n", ratio(17, 0, 2))\n', 't += idiv(a, z)', 'integer division by zero',
           'r 0\nr 1\n%d\n' % (2 * (17 // 5 + 17 % 5)) + 'r 0\n')
    err_rt('r_opt_hoist_ftoi', ['a loop-invariant i64(x): 4.0 converts, 2.5 in a loop run zero times does not fail, 2.5 in',
                                'a loop of three fails at the first iteration after its line (LANGUAGE.md 9.2)'],
           'fn conv(x: f64, n: i64) -> i64 {\n    var t = 0\n    for i in 0..n {\n        printf("c %d\\n", i)\n'
           '        t += i64(x) * i\n    }\n    return t\n}\nprintf("%d\\n", conv(4.0, 3))\nprintf("%d\\n", conv(2.5, 0))\n'
           'printf("%d\\n", conv(2.5, 3))\n', 't += i64(x) * i', 'conversion to i64: 2.5 is not an integer',
           'c 0\nc 1\nc 2\n12\n0\nc 0\n')
    err_rt('r_opt_hoist_field', ['b.vals[k] with an invariant k through a ref struct parameter whose scale field the loop',
                                 'writes: k = 2 works, k = 5 fails at the first iteration after its line (5.4; T8 L-at)'],
           'struct Box {\n    vals: f64[]\n    scale: f64\n}\nfn probe(ref b: Box, k: i64, n: i64) {\n    for i in 0..n {\n'
           '        printf("b %d %g\\n", i, b.scale)\n        b.scale = b.vals[k] + 1.0\n    }\n}\n'
           'var bx = Box { vals: ones(3), scale: 0.5 }\nprobe(ref bx, 2, 2)\nprintf("%g\\n", bx.scale)\nprobe(ref bx, 5, 3)\n',
           'b.scale = b.vals[k]', oob(5, 0, 3), 'b 0 0.5\nb 1 2\n2\nb 0 2\n')
    err_rt('r_opt_hoist_order1', ['two loop-invariant failing operations, v[bad] before big + 1: when both fail the index',
                                  'error is reported, at the first iteration after its line (6.8 rule 5)'],
           'fn both(v: f64[], bad: i64, big: i64) {\n    for i in 0..3 {\n        printf("o %d\\n", i)\n'
           '        let a = v[bad]\n        let b = big + 1\n        printf("%g %d\\n", a, b)\n    }\n}\n'
           'both(ones(2), 1, 5)\nboth(ones(2), 2, 9223372036854775807)\n',
           'let a = v[bad]', oob(2, 0, 2), 'o 0\n1 6\no 1\n1 6\no 2\n1 6\no 0\n')
    err_rt('r_opt_hoist_order2', ['the same with big + 1 before v[bad]: the overflow is reported (6.8 rule 5)'],
           'fn both(v: f64[], bad: i64, big: i64) {\n    for i in 0..3 {\n        printf("o %d\\n", i)\n'
           '        let b = big + 1\n        let a = v[bad]\n        printf("%g %d\\n", a, b)\n    }\n}\n'
           'both(ones(2), 1, 5)\nboth(ones(2), 2, 9223372036854775807)\n',
           'let b = big + 1', 'integer overflow', 'o 0\n1 6\no 1\n1 6\no 2\n1 6\no 0\n')


# ============================================================ opt_unswitch_nan (T9)
def opt_unswitch_nan():
    body = PV + '''fn classify(v: f64[], a: f64, b: f64) -> f64 {
    var t = 0.0
    let c1 = a < b
    let c2 = a != b
    for i in 0..len(v) {
        if c1 {
            t += v[i]
        } else {
            t -= v[i] * 0.5
        }
        if !c2 {
            t += 100.0
        }
        if a >= b {
            t *= 2.0
        }
    }
    return t
}
fn stencil(T: f64[,]) -> f64[,] {
    let nx = cols(T)
    let ny = rows(T)
    var R = zeros(ny, nx)
    for i in 0..nx {
        for j in 0..ny {
            let w = if i == 0 { T[j, i] } else { T[j, i - 1] }
            let e = if i == nx - 1 { T[j, i] } else { T[j, i + 1] }
            R[j, i] = (w + e) * 0.5 + T[j, i]
        }
    }
    return R
}
fn pick(v: f64[], a: f64, b: f64) -> f64 {
    var t = 0.0
    for i in 0..len(v) {
        t += if a == b { v[i] } else { v[i] * 2.0 }
    }
    return t
}
fn count_above(v: f64[], lim: f64) -> i64 {
    var n = 0
    for x in v {
        if lim <= lim {
            if x > lim {
                n += 1
            }
        } else {
            n += 100
        }
    }
    return n
}
let v = [1.0, 2.0, 4.0]
printf("%.17g\\n", classify(v, 1.0, 2.0))
printf("%.17g\\n", classify(v, 2.0, 1.0))
printf("%.17g\\n", classify(v, 1.0, 1.0))
printf("%.17g\\n", classify(v, nan, 1.0))
printf("%.17g\\n", classify(v, 1.0, nan))
printf("%.17g\\n", classify(v, nan, nan))
printf("%.17g\\n", classify(v, -0.0, 0.0))
printf("%.17g\\n", classify(v, inf, inf))
printf("%.17g\\n", classify(zeros(0), nan, 1.0))
printf("%g %g %g %g\\n", pick(v, 1.0, 1.0), pick(v, nan, nan), pick(v, 0.0, -0.0), pick(v, inf, -inf))
printf("%d %d %d\\n", count_above(v, 1.5), count_above(v, nan), count_above(zeros(0), nan))
var T1 = zeros(3, 4)
for i in 0..4 {
    for j in 0..3 {
        T1[j, i] = f64(j) * 1.5 + f64(i * i)
    }
}
pv(stencil(T1).flat)
var T2 = zeros(2, 1)
T2[0, 0] = 3.0
T2[1, 0] = -1.0
pv(stencil(T2).flat)
var T3 = zeros(1, 3)
for i in 0..3 {
    T3[0, i] = f64(i) + 0.5
}
pv(stencil(T3).flat)
pv(stencil(zeros(0, 3)).flat)
'''
    out = ''
    vv = [1.0, 2.0, 4.0]

    def classify(v, a, b):
        t = 0.0
        c1 = a < b
        c2 = a != b
        for x in v:
            if c1:
                t += x
            else:
                t -= x * 0.5
            if not c2:
                t += 100.0
            if a >= b:
                t *= 2.0
        return t
    for a, b in ((1.0, 2.0), (2.0, 1.0), (1.0, 1.0), (NAN, 1.0), (1.0, NAN), (NAN, NAN), (-0.0, 0.0), (INF, INF)):
        out += e17(classify(vv, a, b)) + '\n'
    out += e17(classify([], NAN, 1.0)) + '\n'

    def pick(v, a, b):
        t = 0.0
        for x in v:
            t += x if a == b else x * 2.0
        return t
    out += ' '.join(g(pick(vv, a, b)) for a, b in ((1.0, 1.0), (NAN, NAN), (0.0, -0.0), (INF, -INF))) + '\n'

    def count_above(v, lim):
        n = 0
        for x in v:
            if lim <= lim:
                if x > lim:
                    n += 1
            else:
                n += 100
        return n
    out += '%d %d %d\n' % (count_above(vv, 1.5), count_above(vv, NAN), count_above([], NAN))

    def stencil(T, ny, nx):
        R = [0.0] * (ny * nx)
        for i in range(nx):
            for j in range(ny):
                w = T[j + ny * i] if i == 0 else T[j + ny * (i - 1)]
                e = T[j + ny * i] if i == nx - 1 else T[j + ny * (i + 1)]
                R[j + ny * i] = (w + e) * 0.5 + T[j + ny * i]
        return R
    T1 = [0.0] * 12
    for i in range(4):
        for j in range(3):
            T1[j + 3 * i] = float(j) * 1.5 + float(i * i)
    out += pvf(stencil(T1, 3, 4))
    out += pvf(stencil([3.0, -1.0], 2, 1))
    out += pvf(stencil([float(i) + 0.5 for i in range(3)], 1, 3))
    out += pvf([])
    prog('opt_unswitch_nan', ['loop-invariant conditions (DESIGN.md 5.8 T9): two bool conditions, one negated, and a',
                              'third invariant comparison in one loop, with NaN, signed-zero and infinite operands (only',
                              '!= holds with NaN); an if expression selecting on an invariant == ; an invariant self-',
                              'comparison lim <= lim (false for NaN) around a nested if; a stencil whose column tests',
                              'i == 0 and i == nx - 1 are invariant in the inner loop and guard index arms that would',
                              'fail if evaluated (one column: both hold); empty matrices (LANGUAGE.md 6.4, 6.10, 4.5)'],
         body, out)


def unswitch_errors():
    err_rt('r_opt_unswitch_nan', ['an if expression on an invariant a == b in a loop: with a = b = 1 the first arm runs,',
                                  'with a = b = NaN (== false) the second, whose v[i + 2] fails at i = 2 (6.4, 6.10)'],
           'fn pick(v: f64[], a: f64, b: f64) {\n    for i in 0..len(v) {\n'
           '        let x = if a == b { v[i] } else { v[i + 2] }\n        printf("%g\\n", x)\n    }\n}\n'
           'let v = [1.0, 2.0, 3.0, 4.0]\npick(v, 1.0, 1.0)\npick(v, nan, nan)\n',
           'v[i + 2] }', oob(4, 0, 4), '1\n2\n3\n4\n3\n4\n')
    err_rt('r_opt_unswitch_ne', ['an if on an invariant a != b with a nested invariant flag: NaN != NaN holds, so the arm',
                                 'with w[i + k] runs and fails at i = 1 after the iteration\'s line (6.4)'],
           'fn walk(w: i64[], a: f64, b: f64, k: i64, flag: bool) {\n    for i in 0..len(w) {\n        printf("i %d\\n", i)\n'
           '        if a != b {\n            if flag {\n                printf("%d\\n", w[i + k])\n            }\n'
           '        } else {\n            printf("%d\\n", w[i])\n        }\n    }\n}\nlet w = [7, 8, 9]\n'
           'walk(w, 1.0, 1.0, 5, true)\nwalk(w, nan, nan, 5, false)\nwalk(w, nan, nan, 1, true)\n',
           'w[i + k]', oob(3, 0, 3), 'i 0\n7\ni 1\n8\ni 2\n9\ni 0\ni 1\ni 2\ni 0\n8\ni 1\n9\ni 2\n')
    err_rt('r_opt_ifexpr_arm', ['an if expression in a loop selecting v[(i + 1) % n] or v[i + 1] on an invariant bool: the',
                                'wrapping arm runs for every i, the other fails at the last i (6.10)'],
           'fn nb(v: f64[], wrap: bool) {\n    for i in 0..len(v) {\n'
           '        let x = if wrap { v[(i + 1) % len(v)] } else { v[i + 1] }\n        printf("%g\\n", x)\n    }\n}\n'
           'let v = [1.0, 2.0, 3.0]\nnb(v, true)\nnb(v, false)\n',
           'v[i + 1] }', oob(3, 0, 3), '2\n3\n1\n2\n3\n')


# ============================================================ opt_sr_extents (T7)
def opt_sr_extents():
    body = PV + PVI + '''fn rowdot(A: f64[,], i: i64) -> f64 {
    var t = 0.0
    for j in 0..cols(A) {
        t += A[i, j] * f64(j + 1)
    }
    return t
}
fn coldot(A: f64[,], j: i64) -> f64 {
    var t = 0.0
    for i in 0..rows(A) {
        t += A[i, j] * f64(i + 1)
    }
    return t
}
fn odd_sum(v: i64[]) -> i64 {
    var t = 0
    for j in 0..idiv(len(v), 2) {
        t += v[2 * j + 1] * (j + 1)
    }
    return t
}
fn rev_dot(v: i64[]) -> i64 {
    let n = len(v)
    var t = 0
    for j in 0..n {
        t += v[n - 1 - j] * (j + 1)
    }
    return t
}
fn shifted(v: i64[], t: i64) -> i64 {
    var s = 0
    for j in 0..len(v) - t {
        s += v[j + t] * (j + 1)
    }
    for j in t..len(v) {
        s += v[j - t] * 1000
    }
    return s
}
fn down(A: f64[,]) -> f64 {
    var s = 0.0
    for j in cols(A) - 1..=0 step -3 {
        s += A[rows(A) - 1, j] * f64(j)
        s += A[0, j]
    }
    return s
}
fn kth(v: i64[], k: i64, c: i64) -> i64 {
    var s = 0
    var j = 0
    while j * k + c < len(v) {
        s += v[j * k + c]
        j += 1
    }
    for m in 0..3 {
        s += v[m * k + c] * 100
    }
    return s
}
fn transpose(A: f64[,]) -> f64[,] {
    var B = zeros(cols(A), rows(A))
    for i in 0..rows(A) {
        for j in 0..cols(A) {
            B[j, i] = A[i, j]
        }
    }
    return B
}
fn diag(A: f64[,]) -> f64 {
    var s = 0.0
    for j in 0..min(rows(A), cols(A)) {
        s += A[j, j] * f64(j + 1)
    }
    return s
}
fn stores(n: i64) -> i64[] {
    var v = filled(0, 3 * n + 2)
    for j in 0..n {
        v[3 * j + 2] = j + 1
        v[3 * j] = -(j + 1)
    }
    for j in 0..=n step 2 {
        v[j + 1] += 100
    }
    return v
}
fn show(A: f64[,]) {
    printf("%d %d", rows(A), cols(A))
    for i in 0..rows(A) {
        printf(" |")
        for j in 0..cols(A) {
            printf(" %g", A[i, j])
        }
    }
    printf("\\n")
}
var A = zeros(3, 5)
for j in 0..5 {
    for i in 0..3 {
        A[i, j] = f64(i * 10 + j) + 0.5
    }
}
for i in 0..3 {
    printf("%g\\n", rowdot(A, i))
}
for j in 0..5 {
    printf("%g\\n", coldot(A, j))
}
printf("%g %g\\n", down(A), diag(A))
show(transpose(A))
pv(transpose(A).flat)
var R1 = zeros(1, 4)
for j in 0..4 {
    R1[0, j] = f64(j) - 1.5
}
var C1 = zeros(4, 1)
for i in 0..4 {
    C1[i, 0] = f64(i * i)
}
printf("%g %g %g %g\\n", rowdot(R1, 0), coldot(C1, 0), down(R1), diag(C1))
show(transpose(R1))
show(transpose(C1))
printf("%g %g\\n", down(zeros(2, 1)), diag(zeros(0, 0)))
var w = filled(0, 7)
for i in 0..7 {
    w[i] = i * i + 1
}
printf("%d %d\\n", odd_sum(w), rev_dot(w))
printf("%d %d %d\\n", shifted(w, 2), shifted(w, 0), shifted(w, 7))
printf("%d %d\\n", kth(w, 2, 1), kth(w, 3, 0))
pvi(stores(3))
pvi(stores(0))
pvi(stores(4))
'''
    out = ''
    A = [[float(i * 10 + j) + 0.5 for j in range(5)] for i in range(3)]

    def rowdot(M, i):
        t = 0.0
        for j in range(len(M[0])):
            t += M[i][j] * float(j + 1)
        return t

    def coldot(M, j):
        t = 0.0
        for i in range(len(M)):
            t += M[i][j] * float(i + 1)
        return t

    def down(M, r, c):
        s = 0.0
        for j in range(c - 1, -1, -3):
            s += M[r - 1][j] * float(j)
            s += M[0][j]
        return s

    def diag(M, r, c):
        s = 0.0
        for j in range(min(r, c)):
            s += M[j][j] * float(j + 1)
        return s

    def show(M, r, c):
        s = '%d %d' % (r, c)
        for i in range(r):
            s += ' |' + ''.join(' ' + g(M[i][j]) for j in range(c))
        return s + '\n'

    def tr(M, r, c):
        return [[M[i][j] for i in range(r)] for j in range(c)]
    for i in range(3):
        out += g(rowdot(A, i)) + '\n'
    for j in range(5):
        out += g(coldot(A, j)) + '\n'
    out += '%s %s\n' % (g(down(A, 3, 5)), g(diag(A, 3, 5)))
    At = tr(A, 3, 5)
    out += show(At, 5, 3)
    out += pvf([At[i][j] for j in range(3) for i in range(5)])
    R1 = [[float(j) - 1.5 for j in range(4)]]
    C1 = [[float(i * i)] for i in range(4)]
    out += '%s %s %s %s\n' % (g(rowdot(R1, 0)), g(coldot(C1, 0)), g(down(R1, 1, 4)), g(diag(C1, 4, 1)))
    out += show(tr(R1, 1, 4), 4, 1) + show(tr(C1, 4, 1), 1, 4)
    out += '%s %s\n' % (g(0.0), g(0.0))
    w = [i * i + 1 for i in range(7)]
    out += '%d %d\n' % (sum(w[2 * j + 1] * (j + 1) for j in range(len(w) // 2)),
                        sum(w[len(w) - 1 - j] * (j + 1) for j in range(len(w))))

    def shifted(v, t):
        s = 0
        for j in range(0, len(v) - t):
            s += v[j + t] * (j + 1)
        for j in range(t, len(v)):
            s += v[j - t] * 1000
        return s
    out += '%d %d %d\n' % (shifted(w, 2), shifted(w, 0), shifted(w, 7))

    def kth(v, k, c):
        s = 0
        j = 0
        while j * k + c < len(v):
            s += v[j * k + c]
            j += 1
        for m in range(3):
            s += v[m * k + c] * 100
        return s
    out += '%d %d\n' % (kth(w, 2, 1), kth(w, 3, 0))

    def stores(n):
        v = [0] * (3 * n + 2)
        for j in range(n):
            v[3 * j + 2] = j + 1
            v[3 * j] = -(j + 1)
        for j in range(0, n + 1, 2):
            v[j + 1] += 100
        return v
    out += pvi(stores(3)) + pvi(stores(0)) + pvi(stores(4))
    prog('opt_sr_extents', ['addresses of loop accesses near the extents (DESIGN.md 5.8 T7): a matrix row with the',
                            'column stride rows(A) and a column with unit stride, 2j + 1, n - 1 - j, j + t and j - t',
                            'with an invariant t (0 and the whole length included), a range counting down by 3 to 0,',
                            'an invariant register stride j * k + c in a while and a for, a transpose stored column',
                            'by column, the diagonal, stores at 3j + 2, 3j and j + 1 with step 2 reaching the last',
                            'element, 1 x n, n x 1 and empty matrices (LANGUAGE.md 4.5, 5.1, 5.4)'], body, out)


def sr_errors():
    err_rt('r_opt_sr_stride', ['A[2, 2 * j + 1] over a 3 x 6 matrix: the column 7 at j = 3 (dimension 1), after the lines',
                               'of j = 0, 1, 2 (DESIGN.md 5.8 T7; LANGUAGE.md 5.4)'],
           'let A = zeros(3, 6)\nfor j in 0..5 {\n    printf("%d %g\\n", j, A[2, 2 * j + 1])\n}\n',
           'A[2, 2 * j + 1]', oob(7, 1, 6), '0 0\n1 0\n2 0\n')
    err_rt('r_opt_sr_rev', ['v[n - 1 - j] over 0 ..= n: index -1 at the last iteration, after the four elements (5.4)'],
           'fn back(v: i64[]) {\n    let n = len(v)\n    for j in 0..=n {\n        printf("%d\\n", v[n - 1 - j])\n    }\n}\n'
           'back([4, 3, 2, 1])\n', 'v[n - 1 - j]', oob(-1, 0, 4), '1\n2\n3\n4\n')
    err_rt('r_opt_sr_wrap', ['w[j + t - t] with t = 2^63 - 3: j + t overflows at j = 3 although the index would be 3;',
                             'the lines of j = 0, 1, 2 first (6.5, 6.8 rule 5; a checked chain is not reduced)'],
           'let t = 9223372036854775805\nvar w = filled(0, 4)\nfor i in 0..4 {\n    w[i] = 10 * i\n}\n'
           'for j in 0..4 {\n    printf("%d\\n", w[j + t - t])\n}\n', 'w[j + t - t]', 'integer overflow', '0\n10\n20\n')
    err_rt('r_opt_sr_kstride', ['v[j * k + 1] with an invariant register k = 3 over an 8-element vector: index 10 at j = 3',
                                '(5.4)'],
           'fn every(v: i64[], k: i64) {\n    for j in 0..10 {\n        printf("%d\\n", v[j * k + 1])\n    }\n}\n'
           'var v = filled(0, 8)\nfor i in 0..8 {\n    v[i] = i * 11\n}\nevery(v, 3)\n', 'v[j * k + 1]', oob(10, 0, 8),
           '11\n44\n77\n')
    err_rt('r_opt_sr_step_neg', ['A[1, j] for j in 10 ..= -2 step -3 over 11 columns: j = -2 fails after 10, 7, 4, 1 (5.1)'],
           'var A = zeros(2, 11)\nfor j in 0..11 {\n    A[1, j] = f64(j)\n}\nfor j in 10..=-2 step -3 {\n'
           '    printf("%g\\n", A[1, j])\n}\n', 'printf("%g\\n", A[1, j])', oob(-2, 1, 11), '10\n7\n4\n1\n')
    err_rt('r_opt_sr_row', ['A[j + 1, i] in nested loops over a 4 x 3 matrix: row 4 at j = 3 of the first column',
                            '(dimension 0), after three lines (5.4)'],
           'var A = zeros(4, 3)\nfor i in 0..3 {\n    for j in 0..4 {\n        A[j, i] = f64(j * 10 + i)\n    }\n}\n'
           'for i in 0..3 {\n    for j in 0..4 {\n        printf("%g\\n", A[j + 1, i])\n    }\n}\n',
           'A[j + 1, i])', oob(4, 0, 4), '10\n20\n30\n')
    err_rt('r_opt_sr_store', ['v[2 * j] = j over a 5-element vector: the store at j = 3 (index 6) fails after the line',
                              'of that iteration; the elements stored before are printed first (5.5)'],
           'var v = filled(-1, 5)\nfor j in 0..4 {\n    printf("j %d %d %d\\n", j, v[0], v[4])\n    v[2 * j] = j\n}\n',
           'v[2 * j] = j', oob(6, 0, 5), 'j 0 -1 -1\nj 1 0 -1\nj 2 0 -1\nj 3 0 2\n')


# ============================================================ opt_live_ifs (Decision 75), opt_ifexpr_loops (T4)
def opt_live_ifs():
    body = '''fn churn(n: i64) -> i64 {
    var a0 = 1
    var a1 = 2
    var a2 = 3
    var a3 = 4
    var a4 = 5
    var a5 = 6
    var a6 = 7
    var a7 = 8
    var a8 = 9
    var a9 = 10
    var a10 = 11
    var a11 = 12
    let k0 = n * 3 + 1
    let k1 = n * 5 + 2
    var f0 = 0.5
    var f1 = 1.25
    for i in 0..n {
        if i % 2 == 0 {
            let t1 = a0 + a1
            let t2 = a2 * 2 + a3
            let t3 = a4 + a5 + a6
            a0 = t1 % 1000
            a2 = (t2 + t3) % 997
            a4 = (t3 * 3) % 991
            f0 = f0 * 1.5 + f64(t1)
        } else {
            let u1 = a7 + a8
            let u2 = a9 + a10 + a11
            a7 = u1 % 983
            a9 = (u1 + u2) % 977
            f1 = f1 * 0.5 + f64(u2)
        }
        if i % 3 == 0 {
            printf("c %d %d %d %d\\n", i, a0, a2, a9)
        }
        var both = 0
        if a5 > a6 {
            both = a5 - a6
        } else {
            both = a6 - a5
        }
        a5 = (a5 + both + i) % 971
        a6 = (a6 * 2 + 1) % 967
        a1 = (a1 + a3 + k0) % 953
        a3 = (a3 + a10 + k1) % 947
        a8 = (a8 + a11 + i) % 941
        a10 = (a10 + a0) % 937
        a11 = (a11 + a2 + a4) % 929
    }
    printf("%d %d %d %d %d %d %d %d %d %d %d %d\\n", a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11)
    printf("%.17g %.17g\\n", f0, f1)
    return k0 + k1
}
fn carry(v: f64[]) -> f64 {
    var acc = 0.0
    var last = -1.0
    var i = 0
    while i < len(v) {
        if v[i] > 0.0 {
            last = v[i]
            acc += last
        } else {
            acc -= last
        }
        printf("%g %g\\n", acc, last)
        i += 1
    }
    return acc + last
}
fn nest_calls(n: i64) -> i64 {
    let base = n * 7 + 3
    let off = n - 2
    var s = 0
    for i in 0..n {
        var j = 0
        while j < i {
            if (i + j) % 2 == 0 {
                s += base - j
            } else {
                s -= off + j
            }
            j += 1
        }
        printf("n %d %d %d %d\\n", i, s, base, off)
    }
    return s + base + off
}
printf("%d\\n", churn(0))
printf("%d\\n", churn(1))
printf("%d\\n", churn(7))
printf("%d\\n", churn(20))
printf("%g\\n", carry([2.0, -1.0, 0.0, 3.5, nan, -4.0]))
printf("%g\\n", carry(zeros(0)))
printf("%d\\n", nest_calls(5))
printf("%d\\n", nest_calls(0))
'''
    out = []

    def churn(n):
        a = list(range(1, 13))
        k0 = n * 3 + 1
        k1 = n * 5 + 2
        f0, f1 = 0.5, 1.25
        for i in range(n):
            if i % 2 == 0:
                t1 = a[0] + a[1]
                t2 = a[2] * 2 + a[3]
                t3 = a[4] + a[5] + a[6]
                a[0] = t1 % 1000
                a[2] = (t2 + t3) % 997
                a[4] = (t3 * 3) % 991
                f0 = f0 * 1.5 + float(t1)
            else:
                u1 = a[7] + a[8]
                u2 = a[9] + a[10] + a[11]
                a[7] = u1 % 983
                a[9] = (u1 + u2) % 977
                f1 = f1 * 0.5 + float(u2)
            if i % 3 == 0:
                out.append('c %d %d %d %d\n' % (i, a[0], a[2], a[9]))
            both = a[5] - a[6] if a[5] > a[6] else a[6] - a[5]
            a[5] = (a[5] + both + i) % 971
            a[6] = (a[6] * 2 + 1) % 967
            a[1] = (a[1] + a[3] + k0) % 953
            a[3] = (a[3] + a[10] + k1) % 947
            a[8] = (a[8] + a[11] + i) % 941
            a[10] = (a[10] + a[0]) % 937
            a[11] = (a[11] + a[2] + a[4]) % 929
        out.append(' '.join('%d' % x for x in a) + '\n')
        out.append('%s %s\n' % (e17(f0), e17(f1)))
        return k0 + k1
    for n in (0, 1, 7, 20):
        r = churn(n)
        out.append('%d\n' % r)

    def carry(v):
        acc, last = 0.0, -1.0
        for x in v:
            if x > 0.0:
                last = x
                acc += last
            else:
                acc -= last
            out.append('%s %s\n' % (g(acc), g(last)))
        return acc + last
    r = carry([2.0, -1.0, 0.0, 3.5, NAN, -4.0])
    out.append(g(r) + '\n')
    r = carry([])
    out.append(g(r) + '\n')

    def nest_calls(n):
        base, off, s = n * 7 + 3, n - 2, 0
        for i in range(n):
            for j in range(i):
                if (i + j) % 2 == 0:
                    s += base - j
                else:
                    s -= off + j
            out.append('n %d %d %d %d\n' % (i, s, base, off))
        return s + base + off
    r = nest_calls(5)
    out.append('%d\n' % r)
    r = nest_calls(0)
    out.append('%d\n' % r)
    prog('opt_live_ifs', ['values live across calls in loops whose if parts compute temporaries (DESIGN.md 4.9.2,',
                          'Decision 75): twelve i64 and two f64 variables carried around a loop with a printf in some',
                          'iterations, temporaries local to each part of an if, a value written in both parts and read',
                          'after them, two values computed before the loop and read after it; a value carried around a',
                          'while loop inside one part only (NaN elements take the else part); an inner while in a for',
                          'whose invariant values are printed in every outer iteration (LANGUAGE.md 6.5, 7.4, 7.5)'],
         body, ''.join(out))


def opt_ifexpr_loops():
    body = '''fn track(v: f64[]) -> f64 {
    var m = -inf
    var neg = 0.0
    for x in v {
        var r = 0.0
        if x > m {
            m = x
        }
        if x < 0.0 {
            r = x
        }
        neg += r
    }
    printf("%g %g\\n", m, neg)
    return m
}
fn best_at(v: i64[], n: i64) -> i64 {
    var best = -7
    for i in 0..n {
        if v[i] > 3 {
            best = i
        }
    }
    return best
}
fn absdiff(a: i64[], b: i64[]) -> i64 {
    var s = 0
    for i in 0..len(a) {
        let d = if a[i] > b[i] { a[i] - b[i] } else { b[i] - a[i] }
        s += d * (if i % 2 == 0 { 1 } else { -1 })
    }
    return s
}
fn nexts(v: f64[]) -> f64 {
    var t = 0.0
    for i in 0..len(v) {
        t += if i + 1 < len(v) { v[i + 1] } else { v[0] }
    }
    return t
}
fn clampsum(v: i64[], lo: i64, hi: i64) -> i64 {
    var s = 0
    var i = 0
    while i < len(v) {
        let c = if v[i] < lo { lo } else if v[i] > hi { hi } else { v[i] }
        s = s * 3 + c
        i += 1
    }
    return s
}
fn sel_f(v: f64[], w: f64) -> f64 {
    var t = 1.0
    for x in v {
        let y = if x != x { w } else if x < w { x } else { w - x }
        t = t * 0.5 + y
    }
    return t
}
printf("%g\\n", track([nan, 3.0, -2.0, nan, 5.0, -7.0]))
printf("%g\\n", track(zeros(0)))
printf("%g\\n", track([nan, nan]))
let iv = [1, 5, 2, 9, 0, 4]
printf("%d %d %d %d\\n", best_at(iv, 6), best_at(iv, 2), best_at(iv, 0), best_at(iv, 1))
printf("%d\\n", absdiff([5, 1, 7, 7, -3], [2, 4, 7, 9, 3]))
printf("%g %g\\n", nexts([1.0, 10.0, 100.0]), nexts([2.5]))
printf("%d %d\\n", clampsum([-5, 0, 3, 8, 12, 2], 0, 9), clampsum([1, 2], 5, 4))
printf("%.17g %.17g\\n", sel_f([0.5, nan, 3.0, -1.0, inf], 2.0), sel_f([1.0, 2.0], nan))
'''
    out = ''

    def track(v):
        m, neg = -INF, 0.0
        o = ''
        for x in v:
            r = 0.0
            if x > m:
                m = x
            if x < 0.0:
                r = x
            neg += r
        return m, '%s %s\n' % (g(m), g(neg))
    for v in ([NAN, 3.0, -2.0, NAN, 5.0, -7.0], [], [NAN, NAN]):
        m, o = track(v)
        out += o + g(m) + '\n'
    iv = [1, 5, 2, 9, 0, 4]

    def best_at(n):
        best = -7
        for i in range(n):
            if iv[i] > 3:
                best = i
        return best
    out += '%d %d %d %d\n' % (best_at(6), best_at(2), best_at(0), best_at(1))
    a, b = [5, 1, 7, 7, -3], [2, 4, 7, 9, 3]
    out += '%d\n' % sum(abs(a[i] - b[i]) * (1 if i % 2 == 0 else -1) for i in range(5))

    def nexts(v):
        t = 0.0
        for i in range(len(v)):
            t += v[i + 1] if i + 1 < len(v) else v[0]
        return t
    out += '%s %s\n' % (g(nexts([1.0, 10.0, 100.0])), g(nexts([2.5])))

    def clampsum(v, lo, hi):
        s = 0
        for x in v:
            c = lo if x < lo else (hi if x > hi else x)
            s = s * 3 + c
        return s
    out += '%d %d\n' % (clampsum([-5, 0, 3, 8, 12, 2], 0, 9), clampsum([1, 2], 5, 4))

    def sel_f(v, w):
        t = 1.0
        for x in v:
            y = w if x != x else (x if x < w else w - x)
            t = t * 0.5 + y
        return t
    out += '%s %s\n' % (e17(sel_f([0.5, NAN, 3.0, -1.0, INF], 2.0)), e17(sel_f([1.0, 2.0], NAN)))
    prog('opt_ifexpr_loops', ['if statements with one assignment and if expressions inside loops (DESIGN.md 5.8 T4, L-bq,',
                              'L-bn): a running maximum from -inf over NaN elements, a variable declared in the body and',
                              'assigned in an if, a variable written only in an if and read after a loop run zero times,',
                              'if expressions whose arms index (never speculated: the unselected arm would fail), an else',
                              'if chain in a while, f64 selections on NaN, < and infinities (LANGUAGE.md 6.4, 6.10, 7.4)'],
         body, out)


def promote_errors():
    err_rt('r_opt_promote_struct', ['ref struct fields updated and printed in a loop, the second call failing at i = 2 on',
                                    'v[i]: every line before it, the fields as stored (8.3, 9.2; DESIGN.md 5.8 T5, L-ag)'],
           'struct Acc {\n    total: i64\n    count: i64\n}\nfn run(ref a: Acc, v: i64[], n: i64) {\n    for i in 0..n {\n'
           '        a.total += v[i]\n        a.count += 1\n        printf("%d %d\\n", a.total, a.count)\n    }\n}\n'
           'var a = Acc { total: 0, count: 0 }\nrun(ref a, [4, 5, 6], 3)\nprintf("after %d %d\\n", a.total, a.count)\n'
           'run(ref a, [1, 2], 4)\n', 'a.total += v[i]', oob(2, 0, 2),
           '4 1\n9 2\n15 3\nafter 15 3\n16 4\n18 5\n')
    out, s, fail = '', 1, False
    lines = []
    for n in (3, 40):
        try:
            for i in range(n):
                for j in range(n):
                    s = ck(ck(s * 2) + j)
                lines.append('%d\n' % s)
        except Ovf:
            fail = True
            break
        if n == 3:
            lines.append('s %d\n' % s)
    assert fail
    err_rt('r_opt_promote_ovf', ['a ref scalar doubled in a nested loop and printed after each inner loop: the second call',
                                 'overflows part-way; the lines before it (6.5, 8.3; DESIGN.md 5.8 T5)'],
           'fn grow(ref s: i64, n: i64) {\n    for i in 0..n {\n        for j in 0..n {\n            s = s * 2 + j\n'
           '        }\n        printf("%d\\n", s)\n    }\n}\nvar s = 1\ngrow(ref s, 3)\nprintf("s %d\\n", s)\ngrow(ref s, 40)\n',
           's = s * 2 + j', 'integer overflow', ''.join(lines))
    err_rt('r_opt_cow_ver_err', ['a ref array filled in a loop, unshared at the first call and shared with a let at the',
                                 'second, which prints both arrays and fails at i = 3 (4.5, 8.3; DESIGN.md 5.8 T6)'],
           'fn fill(ref v: f64[], e: f64[], n: i64) {\n    for i in 0..n {\n        v[i] = f64(i) * 2.0 + 1.0\n'
           '        printf("%g %g\\n", v[i], e[i])\n    }\n}\nvar a = zeros(3)\nlet z = zeros(3)\nfill(ref a, z, 2)\n'
           'let keep = a\nfill(ref a, keep, 5)\n', 'v[i] = f64(i)', oob(3, 0, 3),
           '1 0\n3 0\n1 1\n3 3\n5 0\n')

# ============================================================ opt_dead_label (regression)
def opt_dead_label():
    """Unused str bindings at the end of their scope (a loop body, an if part, a block, the main program, as
    tests/passes/lex_string.sea and lex_column.sea do): seaopt's T10 deletes the adjacent retain/release pairs
    and then each `la` of a string label, so sea.lir2 holds `str` labels nothing references; sealopt must read
    and write them (a regression: it reported `internal error: bad record`)."""
    body = """fn weigh(n: i64) -> i64 {
    var total = 0
    for i in 0..n {
        total += i * i
        let tag = "loop tag"
        let tag2 = "second\\ttag"
    }
    if total > 10 {
        let big = "big"
    }
    return total
}
let label = "unused label"
printf("%d %d\\n", weigh(4), weigh(0))
{
    let inner = "inner block"
}
printf("%s\\n", "done")
let trailing = "trailing"
let empty = ""
"""
    def weigh(n):
        return sum(i * i for i in range(n))
    out = '%d %d\n' % (weigh(4), weigh(0)) + 'done\n'
    prog('opt_dead_label', ['unused str bindings at the end of a loop body, an if part, a block and the main program,',
                            'built with the prelude: their labels are left unreferenced once their loads are deleted',
                            '(DESIGN.md 5.8 T10; regression for sealopt reading an unused label; LANGUAGE.md 7.2, 7.7)'],
         body, out)



# ============================================================ opt_destrew_* (regression: T5 destination rewrite)
def opt_destrew():
    """T5 (promotion) destination rewriting: a value computed into a temporary and copied to a promoted
    location must still be what the later reads see when the location is stored again in between.  A later
    store to the location (or its field) must not make an earlier read of the old value, or a recomputation
    of the same expression, observe the later value (LANGUAGE.md 6.8 rule 5, 7.1, 8.3 `ref` parameters)."""
    cm = ['T5 destination rewriting: the promoted location is stored again before the value it first received is',
          'read; each read sees the most recent store in program order (LANGUAGE.md 6.8, 7.1, 8.3)']
    # s = t*3; s = s+1; u = t*3 : the store of s+1 must not change u
    prog('opt_destrew_ref_i64', cm, """fn f(ref s: i64, t: i64, n: i64) -> i64 {
    var u = 0
    for i in 0..n {
        s = t * 3
        s = s + 1
        u = t * 3
    }
    return u
}
var s = 0
let u = f(ref s, 5, 2)
printf("%d %d\\n", s, u)
""", '%d %d\n' % (5 * 3 + 1, 5 * 3))
    # s = a+b; let t = s; s = 0; w += t : t must be 7 each iteration, s ends 0
    prog('opt_destrew_ref_later_store', cm, """fn upd2(ref s: i64, a: i64, b: i64, n: i64) -> i64 {
    var w = 0
    for i in 0..n {
        s = a + b
        let t = s
        s = 0
        w += t
    }
    return w
}
var s = 9
let w = upd2(ref s, 3, 4, 5)
printf("%d %d\\n", w, s)
""", '%d %d\n' % (5 * (3 + 4), 0))
    # f64 field of a ref struct: out sums v*2; st.x ends as the last v*2+1
    v = [1.0, 2.0, 3.0]
    x = 0.0
    out = 0.0
    for e in v:
        x = e * 2.0
        x = x + 1.0
        out += e * 2.0
    prog('opt_destrew_ref_field_f64', cm, """struct St {
    x: f64
    n: i64
}
fn upd(ref st: St, v: f64[]) -> f64 {
    var out = 0.0
    for i in 0..len(v) {
        st.x = v[i] * 2.0
        st.x = st.x + 1.0
        out += v[i] * 2.0
    }
    return out
}
var st = St { x: 0.0, n: 0 }
let o = upd(ref st, [1.0, 2.0, 3.0])
printf("%g %g\\n", o, st.x)
""", '%g %g\n' % (out, x))
    # intervening use between the stores and the recomputation
    acc = 0
    for i in range(3):
        s = 5 * 3 + 1
        acc += s
        u = 5 * 3
        acc += u
    prog('opt_destrew_intervening_use', cm, """fn g(ref s: i64, t: i64, n: i64) -> i64 {
    var u = 0
    var acc = 0
    for i in 0..n {
        s = t * 3
        s = s + 1
        acc += s
        u = t * 3
        acc += u
    }
    return acc
}
var s = 0
let acc = g(ref s, 5, 3)
printf("%d %d\\n", acc, s)
""", '%d %d\n' % (acc, 5 * 3 + 1))
    # f64 scalar through ref
    prog('opt_destrew_ref_f64', cm, """fn h(ref s: f64, t: f64, n: i64) -> f64 {
    var u = 0.0
    for i in 0..n {
        s = t * 3.0
        s = s + 1.0
        u = t * 3.0
    }
    return u
}
var s = 0.0
let u = h(ref s, 2.5, 2)
printf("%g %g\\n", s, u)
""", '%g %g\n' % (2.5 * 3.0 + 1.0, 2.5 * 3.0))
    # i64 field of a ref struct, with a use of the recomputed value after the second store
    prog('opt_destrew_ref_field_i64', cm, """struct P {
    x: f64
    n: i64
}
fn bump(ref p: P, a: i64, b: i64, k: i64) -> i64 {
    var w = 0
    for i in 0..k {
        p.n = a + b
        p.n = p.n * 2
        w += a + b
    }
    return w
}
var p = P { x: 0.0, n: 0 }
let w = bump(ref p, 3, 4, 4)
printf("%d %d\\n", w, p.n)
""", '%d %d\n' % (4 * 7, 14))


# ============================================================ opt_many_stores (regression: scratch tables)
def opt_many_stores():
    """More than 1700 element stores `a[k] = a[k] + f64(i + k)` in one loop body over a dynamic array: sealopt's
    per-function scratch tables (copy-on-write sites, promoted locations) must not overlap or overflow.
    a[k] receives sum(i + k for i in 0..n) = n*(n-1)/2 + n*k, exact in f64 (LANGUAGE.md 5.5, 6.4, 7.3)."""
    cm = ['1700 stores of one loop body into a dynamic array whose buffer a second binding shares (every store',
          'is a copy-on-write candidate): the scratch tables of the optimiser are not overrun (LANGUAGE.md 4.5, 5.5, 7.3)']
    K = 1700
    n = 3
    a = [0.0] * 1800
    for i in range(n):
        for k in range(K):
            a[k] = a[k] + float(i + k)
    stores = ''.join('        a[%d] = a[%d] + f64(i + %d)\n' % (k, k, k) for k in range(K))
    t = 0.0
    for k in range(1800):
        t = t * 0.5 + a[k]
    # keep shares a's buffer before the loop, so every store is a copy-on-write candidate; keep stays all zero
    body = ('fn f(n: i64) -> f64 {\n    var a = zeros(1800)\n    let keep = a\n    for i in 0..n {\n' + stores
            + '    }\n    var t = 0.0\n    var z = 0.0\n    for k in 0..1800 {\n        t = t * 0.5 + a[k]\n'
            '        z += keep[k]\n    }\n    return t + z\n}\n')
    prog('opt_many_stores', cm, body + 'printf("%.17g\\n", f(3))\n', '%.17g\n' % t)



opt_div_const()
opt_fdiv_const()
opt_ifconv()
opt_nan_cmp()
opt_live_calls()
opt_ref_scalar()
opt_ref_elem()
opt_cow_loops()
opt_dead_checks()
opt_index_pm1()
opt_while_zero()
opt_facts()
opt_vn()
opt_fields()
opt_eq_guards()
errors()
field_errors()
eq_errors()
opt_promote_exits()
opt_cow_alias()
opt_hoist_guard()
opt_unswitch_nan()
opt_sr_extents()
opt_live_ifs()
opt_ifexpr_loops()
hoist_errors()
unswitch_errors()
sr_errors()
promote_errors()
opt_dead_label()
opt_destrew()
opt_many_stores()
print('opt5c1_cases: %d programs, %d errors' % (COUNT['programs'], COUNT['errors']))
