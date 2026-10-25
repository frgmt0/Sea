"""Sub-phase 5c-1 corpus: the `opt_*` run tests of DESIGN.md 6.2 "Phase-5 tests" (work package T1 of
DESIGN.md 8 row 5c-1): programs whose output, error, error line or exit status would change if a
transformation of pass 3b (T1 checks and overflow, T2 division by constants, T3 value numbering, T4
if-conversion, T10 clean-up; and the loop transformations T5-T9 of 5c-2) were inexact.

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
print('opt5c1_cases: %d programs, %d errors' % (COUNT['programs'], COUNT['errors']))
