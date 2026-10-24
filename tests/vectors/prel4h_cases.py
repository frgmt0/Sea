"""Sub-phase 4h corpus: programs/ and errors/ tests of the prelude functions `linspace`, `meshgrid`,
`setdiff` and `bincount`, the close-out tests of the after-phase-4 phase-rule rows, and the W5
acceptance program (DESIGN.md 6.2 "4h", 6.3, 8 row 4h, work package T1).

Run with `timeout 120 uv run --no-project python tests/vectors/prel4h_cases.py`. It writes
programs/prel_*, programs/heap_prel_*, errors/r_prel_* (run time), errors/err_prel_*,
errors/err_ns_matmul and errors/err_ns_lib_{format,solve,figure} (compile time), and
accept/w5_stats.{sea,keys,wl}.

Every expected byte is derived here from LANGUAGE.md and DESIGN.md, never from a run of the compiler:

* `linspace` by the three cases of LANGUAGE.md 10.3 in IEEE binary64 (Python floats are binary64;
  `+ - * /` round to nearest even; `n1 = n - 1` and `-n1 + 2k`, `k` converted exactly; in case 2 one
  quotient `d2 / n1` then one multiplication per element, then `y[0] = d1`, `y[n1] = d2` and, for an
  even n1, `y[n1 / 2] = 0` (+0); in case 3 multiply, divide, add, then every element d1 when
  `d1 == d2`, else the two ends); an n above 2^31 - 1 is `invalid array size n` (L-y);
* `setdiff` as the sorted list of the distinct values of a that are not in b (LANGUAGE.md 10.6);
* `bincount` by counting (LANGUAGE.md 10.7): n < 0 or above 2^31 - 1 is `invalid array size n`, made
  before any element is looked at (DESIGN.md 2.5: the result is allocated first); the first value v
  of idx outside 0 .. n-1 in index order is `index v out of bounds for dimension 0 of extent n`;
* `meshgrid` by indexing, X[i, j] = x[j], Y[i, j] = y[i], both len(y) x len(x), elements copied
  (-0.0, NaN), an i64 argument converted element by element with ties to even (LANGUAGE.md 4.2, 10.3);
* printing as Sea's `printf` prints (LANGUAGE.md 11.1): `%.17g` and `%g` as C99 (Python's `%`
  rounds correctly), non-finite values spelled `NaN`, `Inf`, `-Inf`; `%d` of an i64 in decimal;
* evaluation order (LANGUAGE.md 6.8 rule 5, 6.10, 6.4 short circuit; DESIGN.md 3.6.6 rule 12 and
  3.5.9 R30): arguments left to right, `setdiff(v, grow(ref v))` sees v as it was before `grow`;
* run-time errors at the line of the program's call (LANGUAGE.md 10, DESIGN.md 2.6.2 L-y), status 1,
  standard output flushed first; compile errors with the message of DESIGN.md 2.6.2's table at the
  node of its `at` column (a call at its callee name, an argument at its first token, a `bin` at its
  left operand, an item at its keyword, a binding at its name, a `ref` at the keyword, a `narg` at
  its name; DESIGN.md 3.3), L-s and L-t for the prelude names and calls, L-z for the close-out.

The line of a run-time error is the line holding its marker; a compile error's column is that of its
marker text inside the marker's line (both computed from the source text).

W5 (lead decision L-aa, DESIGN.md 6.3): accept/w5_stats.sea is LANGUAGE.md Appendix D's code,
copied verbatim for what the four keys `first_dev`, `mean_cold`, `std_cold`, `hist_counts` need (the
struct, `dims`, the constants, the validation `match`, the sampling loop, `uTop` and `Top`,
`stack_gap`, `lcg_fill`, the cold statistics, `binW`, `bin`, `inRange` and `counts`), each copied
block asserted against the Appendix text, followed by the printf JSON of DESIGN.md 6.3. Its expected
values are the committed MATLAB reference (workloads/reference/w5_tolerance_mc.json), compared by
tests/accept4.sh through `compare.py --keys`; nothing here computes them.
"""

import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
TESTS = os.path.dirname(HERE)
ROOT = os.path.dirname(TESTS)
PROGRAMS = os.path.join(TESTS, 'programs')
ERRORS = os.path.join(TESTS, 'errors')
ACCEPT = os.path.join(TESTS, 'accept')
COUNT = {'programs': 0, 'errors': 0}
MAXEXT = 2 ** 31 - 1        # LANGUAGE.md 4.5: extents are i64 in 0 .. 2^31 - 1


def write(path, data):
    if isinstance(data, str):
        data = data.encode('ascii')
    with open(path, 'wb') as f:
        f.write(data)


def remove(path):
    if os.path.exists(path):
        os.remove(path)


def source(name, comment, body):
    head = ''.join('// %s\n' % c for c in comment)
    head = '// %s -- ' % name + head[3:]
    src = head + body
    for ln in src.split('\n'):
        assert len(ln.encode('ascii')) <= 4096, ln[:40]                  # 3.1 line limit
        assert all(c == '\t' or 0x20 <= ord(c) < 0x7F for c in ln), ln   # 3.1 ASCII
    return src


# ---------------------------------------------------------------------------- the model
class SizeError(Exception):
    pass


class IndexOOB(Exception):
    pass


def linspace(d1, d2, n):
    """LANGUAGE.md 10.3, case by case, in binary64."""
    assert isinstance(d1, float) and isinstance(d2, float) and isinstance(n, int)
    if n > MAXEXT:
        raise SizeError(n)
    if n < 1:
        return []
    if n == 1:
        return [d2]
    n1 = n - 1
    if d1 == -d2 and n > 2:
        q = d2 / float(n1)
        y = [float(-n1 + 2 * k) * q for k in range(n)]
        y[0] = d1
        y[n1] = d2
        if n1 % 2 == 0:
            y[n1 // 2] = 0.0
        return y
    y = [d1 + (float(k) * (d2 - d1)) / float(n1) for k in range(n)]
    if d1 == d2:
        return [d1] * n
    y[0] = d1
    y[n1] = d2
    return y


def setdiff(a, b):
    return sorted(set(a) - set(b))


def bincount(idx, n):
    if n < 0 or n > MAXEXT:
        raise SizeError(n)
    c = [0] * n
    for v in idx:
        if v < 0 or v >= n:
            raise IndexOOB(v)
        c[v] += 1
    return c


def meshgrid(x, y):
    X = [[float(x[j]) for j in range(len(x))] for _ in range(len(y))]
    Y = [[float(y[i]) for _ in range(len(x))] for i in range(len(y))]
    return X, Y


def nonfinite(x):
    if math.isnan(x):
        return 'NaN'
    if math.isinf(x):
        return 'Inf' if x > 0 else '-Inf'
    return None


def e17(x):
    """%.17g of an f64 (11.1)."""
    assert isinstance(x, float)
    return nonfinite(x) or '%.17g' % x


def g(x):
    """%g of an f64 (11.1)."""
    assert isinstance(x, float)
    return nonfinite(x) or '%g' % x


def pe(v):
    return '%d:' % len(v) + ''.join(' ' + e17(x) for x in v)


def pf(v):
    return '%d:' % len(v) + ''.join(' ' + g(x) for x in v)


def pvi(v):
    return '%d:' % len(v) + ''.join(' %d' % x for x in v)


def pm(A, cols):
    """`RxC`, then ` |` and ` %g` per element for each row (the column count is passed: a 2 x 0 matrix
    has rows without elements)."""
    return '%dx%d' % (len(A), cols) + ''.join(' |' + ''.join(' ' + g(x) for x in r) for r in A)


HELPERS = {
    'pe': r'''fn pe(v: f64[]) {
    printf("%d:", len(v))
    for x in v {
        printf(" %.17g", x)
    }
    printf("\n")
}
''',
    'pf': r'''fn pf(v: f64[]) {
    printf("%d:", len(v))
    for x in v {
        printf(" %g", x)
    }
    printf("\n")
}
''',
    'pvi': r'''fn pvi(v: i64[]) {
    printf("%d:", len(v))
    for x in v {
        printf(" %d", x)
    }
    printf("\n")
}
''',
    'pm': r'''fn pm(A: f64[,]) {
    printf("%dx%d", rows(A), cols(A))
    for i in 0..rows(A) {
        printf(" |")
        for j in 0..cols(A) {
            printf(" %g", A[i, j])
        }
    }
    printf("\n")
}
''',
}


def prog(name, comment, helpers, steps, fns=''):
    """A programs/ test. steps: (code, expected) pairs in program order; expected is the text the
    code prints, lines separated by LF, without the final LF (None: prints nothing)."""
    body = ''.join(HELPERS[h] for h in helpers) + fns
    body += ''.join(code + '\n' for code, _ in steps)
    out = ''.join(o + '\n' for _, o in steps if o is not None)
    write(os.path.join(PROGRAMS, name + '.sea'), source(name, comment, body))
    write(os.path.join(PROGRAMS, name + '.out'), out)
    for ext in ('.args', '.in', '.err', '.status', '.meta'):
        remove(os.path.join(PROGRAMS, name + ext))
    COUNT['programs'] += 1


def line_of(src, marker):
    lines = src.split('\n')
    hits = [i for i, ln in enumerate(lines) if marker in ln and not ln.startswith('//')]
    assert len(hits) == 1, (marker, hits)
    return hits[0] + 1, lines[hits[0]]


def err_rt(name, comment, body, marker, msg, out=''):
    """A run-time error: stderr `NAME.sea:LINE: error: MSG`, status 1, stdout `out`."""
    src = source(name, comment, body)
    ln, _ = line_of(src, marker)
    write(os.path.join(ERRORS, name + '.sea'), src)
    write(os.path.join(ERRORS, name + '.err'), '%s.sea:%d: error: %s\n' % (name, ln, msg))
    write(os.path.join(ERRORS, name + '.status'), '1\n')
    path = os.path.join(ERRORS, name + '.out')
    if out:
        write(path, out)
    else:
        remove(path)
    COUNT['errors'] += 1


def err_c(name, comment, body, marker, col_text, msg):
    """A compile error at the first occurrence of col_text in the marker's line."""
    src = source(name, comment, body)
    ln, text = line_of(src, marker)
    col = text.index(col_text) + 1
    write(os.path.join(ERRORS, name + '.sea'), src)
    write(os.path.join(ERRORS, name + '.err'), '%s.sea:%d:%d: error: %s\n' % (name, ln, col, msg))
    write(os.path.join(ERRORS, name + '.status'), '1\n')
    remove(os.path.join(ERRORS, name + '.out'))
    COUNT['errors'] += 1


def raises(exc, fn, *args):
    try:
        fn(*args)
    except exc as e:
        return e.args[0]
    raise AssertionError('no %s from %s%r' % (exc.__name__, fn.__name__, args))


INF = float('inf')
NAN = float('nan')

# ============================================================ prel_linspace (10.3)
def prel_linspace():
    S = []

    def L(args, d1, d2, n, note=None):
        S.append(('pe(linspace(%s))' % args, pe(linspace(d1, d2, n))))

    L('0.0, 1.0, 0', 0.0, 1.0, 0)                 # rule 1: n < 1 is empty
    L('0.0, 1.0, -3', 0.0, 1.0, -3)
    L('5.0, 7.0, 1', 5.0, 7.0, 1)                 # n == 1: [d2]
    L('-1.0, 1.0, 5', -1.0, 1.0, 5)               # rule 2, n1 = 4 even: the middle set to +0
    L('-1.0, 1.0, 4', -1.0, 1.0, 4)               # rule 2, n1 = 3 odd: (-3 + 2k) * (1/3)
    L('0.0, 0.0, 4', 0.0, 0.0, 4)                 # rule 2 (0 == -0): (-1) * 0 = -0 survives
    L('-0.0, -0.0, 3', -0.0, -0.0, 3)             # rule 2: ends -0, middle +0
    L('-1.0, 1.0, 2', -1.0, 1.0, 2)               # n = 2: rule 3 even though d1 == -d2
    L('2.5, 2.5, 3', 2.5, 2.5, 3)                 # rule 3, d1 == d2
    L('inf, inf, 3', INF, INF, 3)                 # rule 3, d1 == d2: every y[k] = d1 (no NaN)
    L('0.0, 1.0, 11', 0.0, 1.0, 11)               # rule 3, general (0.30000000000000004 ...)
    L('1.0, 0.0, 4', 1.0, 0.0, 4)                 # decreasing
    L('-inf, inf, 3', -INF, INF, 3)               # rule 2: -Inf, NaN replaced by +0, Inf
    L('0.1, 0.7, 7', 0.1, 0.7, 7)                 # rule 3 order: multiply, divide, add
    L('-3.0, 7.0, 6', -3.0, 7.0, 6)
    L('0.4, 1.6, 25', 0.4, 1.6, 25)               # W5's tolerance scale
    S.append(('pe(linspace(0, 10, 5))', pe(linspace(0.0, 10.0, 5))))   # untyped literals -> f64
    S.append(('let a = 1\nlet b = 4\nlet n = 4\npe(linspace(a, b, n))', pe(linspace(1.0, 4.0, 4))))  # i64 -> f64
    S.append(('let m = 3\npe(linspace(-2.0, 2.0, m))', pe(linspace(-2.0, 2.0, 3))))
    S.append(('let sc = linspace(0.4, 1.6, 25)\nprintf("%d %.17g %.17g %.17g\\n", len(sc), sc[1], sc[12], sc[24])',
              (lambda v: '%d %s %s %s' % (len(v), e17(v[1]), e17(v[12]), e17(v[24])))(linspace(0.4, 1.6, 25))))
    # (0.0, 0.0, 4) prints `0 -0 0 0` (DESIGN.md 0 and 9, the note after the 4h lead decisions; 6.2)
    assert pe(linspace(0.0, 0.0, 4)) == '4: 0 -0 0 0'
    assert pe(linspace(-INF, INF, 3)) == '3: -Inf 0 Inf'
    assert pe(linspace(-1.0, 1.0, 5)) == '5: -1 -0.5 0 0.5 1'
    prog('prel_linspace', ['linspace (LANGUAGE.md 10.3; DESIGN.md 6.2 "4h"): n < 1 empty, n = 1 [d2], the symmetric',
                           'branch with n1 even and odd and with zeros, d1 == d2 (also infinite), the general formula,',
                           '(-inf, inf, 3), W5\'s scale, untyped and i64 arguments converted; printed with %.17g'],
         ['pe'], S)


# ============================================================ prel_bincount (10.7)
def prel_bincount():
    S = []
    S.append(('pvi(bincount([2, 0, 2, 2, 1], 4))', pvi(bincount([2, 0, 2, 2, 1], 4))))   # repeats, a zero count
    S.append(('pvi(bincount([], 3))', pvi(bincount([], 3))))                              # empty idx
    S.append(('pvi(bincount([], 0))', pvi(bincount([], 0))))                              # n = 0
    S.append(('let fixed = [1, 1, 0]\npvi(bincount(fixed, 2))', pvi(bincount([1, 1, 0], 2))))  # i64[3] -> dyn
    S.append(('pvi(bincount([3], 4))', pvi(bincount([3], 4))))                            # the last bin
    c = bincount(setdiff([4, 0, 4], [9]), 5)
    c[1] += 10
    S.append(('var c = bincount(setdiff([4, 0, 4], [9]), 5)\nc[1] += 10\npvi(c)', pvi(c)))   # owned arg, result modified
    S.append(('let d = bincount(c, 11)\npvi(d)', pvi(bincount(c, 11))))                   # a var argument
    v = [0.2, 1.7, 1.2, 2.9]
    S.append(('let v = [0.2, 1.7, 1.2, 2.9]\npvi(bincount(i64(floor(v)), 3))',
              pvi(bincount([int(math.floor(x)) for x in v], 3))))                         # W5's form
    big = bincount([1] * 1000, 2)
    S.append(('let big = bincount(filled(1, 1000), 2)\nprintf("%d %d %d\\n", len(big), big[0], big[1])',
              '%d %d %d' % (len(big), big[0], big[1])))
    prog('prel_bincount', ['bincount (LANGUAGE.md 10.7; DESIGN.md 6.2 "4h"): repeats, an empty idx, n = 0, a fixed-size',
                           'literal argument converted, an owned argument, the result modified afterwards'],
         ['pvi'], S)


# ============================================================ prel_setdiff (10.6)
def prel_setdiff():
    S = []

    def D(code, a, b):
        S.append(('pvi(setdiff(%s))' % code, pvi(setdiff(a, b))))

    D('[3, 1, 3, 2, 1], [2]', [3, 1, 3, 2, 1], [2])          # duplicates
    D('[-5, 3, -1, 0], [0]', [-5, 3, -1, 0], [0])            # negatives
    D('[9, 4, 7, 4], [8]', [9, 4, 7, 4], [8])                # unsorted, b not in a
    D('[], [1, 2]', [], [1, 2])                               # empty a
    D('[4, 2, 4], []', [4, 2, 4], [])                         # empty b written []
    D('(0..6), [0, 5]', list(range(0, 6)), [0, 5])              # a range argument: the value form "(" range ")" (Appendix A)
    D('[1, 2], [2, 1, 7]', [1, 2], [2, 1, 7])                 # everything removed
    D('[9223372036854775807, -9223372036854775807, 0, 5], [5]',
      [9223372036854775807, -9223372036854775807, 0, 5], [5])
    S.append(('var a = setdiff([5, 3], [])\na[0] = 100\npvi(a)', pvi([100, 5])))
    S.append(('pvi(setdiff(a, a))', pvi(setdiff([100, 5], [100, 5]))))
    S.append(('pvi(setdiff(a, [5]))', pvi(setdiff([100, 5], [5]))))
    assert pvi(setdiff(list(range(6)), [0, 5])) == '4: 1 2 3 4'
    prog('prel_setdiff', ['setdiff (LANGUAGE.md 10.6; DESIGN.md 6.2 "4h"): duplicates, negatives, unsorted input, an',
                          'empty a, an empty b written [], a range argument, everything removed, i64 extremes'],
         ['pvi'], S)


# ============================================================ prel_meshgrid (10.3, Decision 54)
def prel_meshgrid():
    S = []
    x = [-0.0, 1.5, NAN]
    yi = [7, -3]
    X, Y = meshgrid(x, yi)
    S.append(('let x = [-0.0, 1.5, nan]\nvar yi = filled(0, 2)\nyi[0] = 7\nyi[1] = -3\n'
              'let (X, Y) = meshgrid(x, yi)\npm(X)\npm(Y)', pm(X, 3) + '\n' + pm(Y, 3)))
    EX, EY = meshgrid([], [1.0, 2.0])
    S.append(('let e: f64[] = []\nlet (EX, EY) = meshgrid(e, [1.0, 2.0])\npm(EX)\npm(EY)',
              pm(EX, 0) + '\n' + pm(EY, 0)))
    FX, FY = meshgrid([1.0], [])
    S.append(('let (FX, FY) = meshgrid([1.0], e)\npm(FX)\npm(FY)', pm(FX, 1) + '\n' + pm(FY, 1)))
    A, B = meshgrid([1.0, 2.0], [3.0])
    S.append(('var A = zeros(1, 1)\nvar B = ones(3, 3)\n(A, B) = meshgrid([1.0, 2.0], [3.0])\npm(A)\npm(B)',
              pm(A, 2) + '\n' + pm(B, 2)))
    M1, M2 = meshgrid([0.5, 0.25], [1.0, 2.0, 3.0])
    S.append(('let (M1, M2) = mg([0.5, 0.25], [1.0, 2.0, 3.0])\npm(M1)\npm(M2)', pm(M1, 2) + '\n' + pm(M2, 2)))
    X2, _ = meshgrid([4.0], [1.0, 2.0])
    S.append(('let (X2, _) = meshgrid([4.0], [1.0, 2.0])\npm(X2)', pm(X2, 1)))
    _, Y3 = meshgrid([0.5], [1, 2])
    S.append(('let yf = [1, 2]\nlet (_, Y3) = meshgrid([0.5], yf)\npm(Y3)', pm(Y3, 1)))      # fixed i64[2]
    _, Yb = meshgrid([0.0], [9007199254740993])
    S.append(('let yb = filled(9007199254740993, 1)\nlet (_, Yb) = meshgrid([0.0], yb)\nprintf("%.17g\\n", Yb[0, 0])',
              e17(Yb[0][0])))                     # 2^53 + 1 converts to 2^53 (ties to even)
    S.append(('printf("%g %g %g\\n", x[0], X[1, 0], Y[0, 2])', '%s %s %s' % (g(-0.0), g(X[1][0]), g(Y[0][2]))))
    assert e17(Yb[0][0]) == '9007199254740992'
    fns = r'''fn mg(x: f64[], y: f64[]) -> (f64[,], f64[,]) {
    return meshgrid(x, y)
}
'''
    prog('prel_meshgrid', ['meshgrid (LANGUAGE.md 10.3; DESIGN.md 6.2 "4h", Decision 54): -0.0 and nan copied, an i64[] y',
                           'converted (dynamic, fixed, and 2^53 + 1 rounding to even), empty x and y, a tuple assignment',
                           'into existing vars, return meshgrid(...) from a user function, _ components'],
         ['pm'], S, fns)


# ============================================================ prel_ctx (6.8, 6.10, R30)
def prel_ctx():
    S = []
    S.append(('setdiff([1, 2], [2])\nprintf("eval\\n")', 'eval'))
    S.append(('printf("%g %d\\n", linspace(0.0, 1.0, 5)[3], bincount([0, 0, 1], 2)[0])',
              '%s %d' % (g(linspace(0.0, 1.0, 5)[3]), bincount([0, 0, 1], 2)[0])))
    S.append(('printf("for")\nfor x in linspace(1.0, 2.0, 3) {\n    printf(" %g", x)\n}\nprintf("\\n")',
              'for' + ''.join(' ' + g(t) for t in linspace(1.0, 2.0, 3))))
    # if-expression arms: only the selected arm runs (6.10); f() would print "f "
    S.append(('let w = if len(setdiff([1, 2, 3], [9])) == 3 { linspace(0.0, 1.0, 3) } else { linspace(f(), 1.0, 2) }\npf(w)',
              pf(linspace(0.0, 1.0, 3))))
    S.append(('let no = len(w) > 5\nlet w2 = if no { linspace(f(), 1.0, 2) } else { linspace(g(), 2.0, 2) }\npf(w2)',
              'g ' + pf(linspace(1.0, 2.0, 2))))
    # a while condition re-run every iteration
    done = []
    it = 0
    while len(setdiff([1, 2, 3], done)) > 0:
        it += 1
        done = done + [it]
    S.append(('var done: i64[] = []\nvar it = 0\nwhile len(setdiff([1, 2, 3], done)) > 0 {\n    it += 1\n'
              '    done = [done, it]\n}\nprintf("while %d %d\\n", it, len(done))', 'while %d %d' % (it, len(done))))
    # two in one expression
    S.append(('printf("%d\\n", len(linspace(0.0, 1.0, 4)) + len(setdiff((0..5), [1])))',
              '%d' % (len(linspace(0.0, 1.0, 4)) + len(setdiff(list(range(5)), [1])))))
    s1 = sum(linspace(0.0, 1.0, 5))                 # 0 .25 .5 .75 1: exact in any order
    assert s1 == 2.5
    S.append(('printf("%g\\n", sum(linspace(0.0, 1.0, 5)) + sum(bincount([0, 1, 1], 3)))',
              g(s1 + float(sum(bincount([0, 1, 1], 3))))))
    # inside a user function
    def spread(n):
        v = linspace(0.0, 10.0, n)
        return v[n - 1] - v[0]
    S.append(('printf("%g %g\\n", spread(3), spread(1))', '%s %s' % (g(spread(3)), g(spread(1)))))
    # inside a loop left by break
    brk = None
    for k in range(10):
        cc = bincount([k % 3], 3)
        if cc[2] == 1:
            brk = k
            break
    S.append(('for k in 0..10 {\n    let c = bincount([k % 3], 3)\n    if c[2] == 1 {\n        printf("break %d\\n", k)\n'
              '        break\n    }\n}', 'break %d' % brk))
    # argument order: f g h, then the result
    S.append(('pe(linspace(f(), g(), h()))', 'f g h ' + pe(linspace(0.0, 1.0, 3))))
    # rule 12 / R30: the first argument is v before grow appends 9 to it
    v_old = [1, 2, 3]
    v_new = v_old + [9]
    S.append(('var v: i64[] = [1, 2, 3]\npvi(setdiff(v, grow(ref v)))\npvi(v)',
              'grow ' + pvi(setdiff(v_old, [2])) + '\n' + pvi(v_new)))
    assert pvi(setdiff(v_old, [2])) == '2: 1 3'
    # short-circuit operands (6.4): the right operand runs only when needed
    S.append(('let yes = len(v) == 4\nif !yes && len(linspace(f(), 1.0, 2)) == 2 {\n    printf("no\\n")\n}\n'
              'if yes || len(linspace(f(), 1.0, 2)) == 2 {\n    printf("or\\n")\n}\n'
              'if yes && len(linspace(g(), 1.0, 2)) == 2 {\n    printf("and\\n")\n}', 'or\ng and'))
    # a match scrutinee holding a prelude call, and one in an arm
    n2 = len(setdiff([5, 6, 7], [6]))
    assert n2 == 2
    S.append(('match str(len(setdiff([5, 6, 7], [6]))) {\n    "2" => {\n        printf("match two\\n")\n'
              '        pvi(bincount([1], 2))\n    }\n    _ => { printf("match other\\n") }\n}',
              'match two\n' + pvi(bincount([1], 2))))
    # nested prelude calls
    S.append(('pvi(bincount(setdiff([3, 1, 3, 0], [1]), 4))', pvi(bincount(setdiff([3, 1, 3, 0], [1]), 4))))
    S.append(('pe(linspace(0.0, f64(len(setdiff([4, 4, 5], []))), 3))',
              pe(linspace(0.0, float(len(setdiff([4, 4, 5], []))), 3))))
    # if statement: a call in the condition and in the arms
    S.append(('if len(linspace(0.0, 1.0, 3)) == 3 {\n    let q = setdiff([2, 1], [1])\n    pvi(q)\n} else {\n'
              '    pvi(setdiff([9], []))\n}', pvi(setdiff([2, 1], [1]))))
    # a tuple assignment from a call whose argument is another call
    P, Q = meshgrid(linspace(0.0, 1.0, 2), [5.0])
    S.append(('var P = zeros(1, 1)\nvar Q = zeros(1, 1)\n(P, Q) = meshgrid(linspace(0.0, 1.0, 2), [5.0])\n'
              'printf("%d %d %g %g\\n", rows(P), cols(P), P[0, 1], Q[0, 0])',
              '%d %d %s %s' % (len(P), len(P[0]), g(P[0][1]), g(Q[0][0]))))
    fns = r'''fn f() -> f64 {
    printf("f ")
    return 0.0
}
fn g() -> f64 {
    printf("g ")
    return 1.0
}
fn h() -> i64 {
    printf("h ")
    return 3
}
fn grow(ref v: i64[]) -> i64[] {
    printf("grow ")
    v = [v, 9]
    return [2]
}
fn spread(n: i64) -> f64 {
    let v = linspace(0.0, 10.0, n)
    return v[n - 1] - v[0]
}
'''
    prog('prel_ctx', ['prelude calls in every context (DESIGN.md 6.2 "4h"; LANGUAGE.md 6.4, 6.8 rule 5, 6.10, 7.3-7.6):',
                      'an eval statement, an index base, a for vector, if-expression arms (only the selected one runs),',
                      'a while condition, two in one expression, a user function, a loop left by break, the argument',
                      'order f g h, setdiff(v, grow(ref v)) seeing the old v (rule 12, R30), short-circuit operands,',
                      'a match scrutinee and arm, nested calls, if arms, a tuple assignment'],
         ['pe', 'pf', 'pvi'], S, fns)


# ============================================================ heap_prel_args, heap_prel_exits
def heap_prel_args():
    S = []
    a = [5, 1, 5, 3]
    S.append(('let a = [5, 1, 5, 3]\npvi(setdiff(setdiff(a, [1]), [3]))', pvi(setdiff(setdiff(a, [1]), [3]))))
    v = linspace(0.0, 2.0, 5)
    S.append(('let v = linspace(0.0, 2.0, 5)\npvi(bincount(i64(v * 2.0), 5))',
              pvi(bincount([int(x * 2.0) for x in v], 5))))
    X, Y = meshgrid(linspace(0.0, 1.0, 2), linspace(2.0, 3.0, 3))
    S.append(('let (X, Y) = meshgrid(linspace(0.0, 1.0, 2), linspace(2.0, 3.0, 3))\n'
              'printf("%dx%d %g %g\\n", rows(X), cols(X), X[2, 1], Y[2, 1])',
              '%dx%d %s %s' % (len(X), len(X[0]), g(X[2][1]), g(Y[2][1]))))
    S.append(('linspace(0.0, 1.0, 3)\nmeshgrid(v, v)\nsetdiff(a, [5])\nbincount([0, 1], 2)\nprintf("evals\\n")', 'evals'))
    _, Y2 = meshgrid([1.0], [7.0, 8.0])
    S.append(('let (_, Y2) = meshgrid([1.0], [7.0, 8.0])\npm(Y2)', pm(Y2, 1)))
    S.append(('let (_, _) = meshgrid(v, [1.0])\nprintf("discarded\\n")', 'discarded'))
    _, B = meshgrid([1.0, 2.0], [4.0])
    S.append(('var B = zeros(1, 1)\n(_, B) = meshgrid([1.0, 2.0], [4.0])\npm(B)', pm(B, 2)))
    outs = []
    for i in range(3):
        outs.append(pvi(setdiff(setdiff([i, 1, 2], [1]), [])))
    S.append(('for i in 0..3 {\n    let w = setdiff(setdiff([i, 1, 2], [1]), [])\n    pvi(w)\n}', '\n'.join(outs)))
    r = linspace(0.0, 1.0, 2)
    for _ in range(3):
        r = linspace(r[1], 2.0, 3)
    S.append(('var r = linspace(0.0, 1.0, 2)\nfor i in 0..3 {\n    r = linspace(r[1], 2.0, 3)\n}\npe(r)', pe(r)))
    prog('heap_prel_args', ['owned argument temporaries of prelude calls, an eval of each function, _ components and',
                            'results replaced in a loop (DESIGN.md 3.5.9 R26, R27; 3.6.6 rules 15, 37); heap check 0'],
         ['pe', 'pvi', 'pm'], S)


def heap_prel_exits():
    S = []
    S.append(('for n in -1..3 {\n    let v = linspace(5.0, 6.0, n)\n    pe(v)\n}',
              '\n'.join(pe(linspace(5.0, 6.0, n)) for n in range(-1, 3))))
    brk = None
    for k in range(5):
        c = bincount([k], 5)
        s = setdiff(list(range(5)), [k])
        if k == 2:
            brk = 'break %d %d' % (c[2], len(s))
            break
    S.append(('for k in 0..5 {\n    let c = bincount([k], 5)\n    let s = setdiff((0..5), [k])\n    if k == 2 {\n'
              '        printf("break %d %d\\n", c[2], len(s))\n        break\n    }\n}', brk))
    m = 0
    wl = None
    while True:
        m += 1
        X, Y = meshgrid(linspace(0.0, 1.0, m), [1.0])
        if m % 2 == 1:
            continue
        if len(X[0]) >= 4:
            wl = 'while %d %s' % (m, g(Y[0][0]))
            break
    S.append(('var m = 0\nwhile true {\n    m += 1\n    let (X, Y) = meshgrid(linspace(0.0, 1.0, m), [1.0])\n'
              '    if m % 2 == 1 {\n        continue\n    }\n    if cols(X) >= 4 {\n'
              '        printf("while %d %g\\n", m, Y[0, 0])\n        break\n    }\n}', wl))

    def firstv(n):
        for k in range(n):
            v = linspace(1.0, 2.0, k + 2)
            if len(v) == 3:
                return v[1]
        return -1.0
    S.append(('printf("%g %g\\n", firstv(5), firstv(1))', '%s %s' % (g(firstv(5)), g(firstv(1)))))
    fns = r'''fn firstv(n: i64) -> f64 {
    for k in 0..n {
        let v = linspace(1.0, 2.0, k + 2)
        if len(v) == 3 {
            return v[1]
        }
    }
    return -1.0
}
'''
    prog('heap_prel_exits', ['the early returns of linspace (n < 1, n = 1) and exits around prelude calls: a loop left by',
                             'break, continue, a return from inside a loop (DESIGN.md 3.5.9 R29; rule 16); heap check 0'],
         ['pe'], S, fns)


# ============================================================ run-time errors (L-y)
def runtime_errors():
    e = raises(IndexOOB, bincount, [0, 1, 3], 2)
    err_rt('r_prel_bincount_oob', ['a bincount value outside 0 .. n-1 after printed output: INDEX_OOB with the value,',
                                   'dimension 0 and extent n, at the line of the call (LANGUAGE.md 10.7; DESIGN.md 2.6.2)'],
           'let idx = [0, 1, 3]\nprintf("start\\n")\nlet c = bincount(idx, 2)\nprintf("%d\\n", c[0])\n',
           'let c = bincount(', 'index %d out of bounds for dimension 0 of extent 2' % e, 'start\n')
    e = raises(IndexOOB, bincount, [1, -1, 5], 2)
    err_rt('r_prel_bincount_neg_idx', ['a negative bincount value, the first bad one in index order (LANGUAGE.md 10.7)'],
           'printf("start\\n")\nlet c = bincount([1, -1, 5], 2)\nprintf("%d\\n", c[0])\n',
           'let c = bincount(', 'index %d out of bounds for dimension 0 of extent 2' % e, 'start\n')
    e = raises(IndexOOB, bincount, [2], 2)
    err_rt('r_prel_bincount_fn', ['bincount called inside a user function: the line of that call, never a line of the',
                                  'prelude (LANGUAGE.md 10; DESIGN.md 2.6.2 L-y)'],
           'fn counts(v: i64[]) -> i64[] {\n    return bincount(v, 2)\n}\nprintf("%d\\n", len(counts([0, 1])))\n'
           'printf("%d\\n", len(counts([2])))\nprintf("never\\n")\n',
           'return bincount(', 'index %d out of bounds for dimension 0 of extent 2' % e,
           '%d\n' % len(bincount([0, 1], 2)))
    e = raises(SizeError, bincount, [0], -2)
    err_rt('r_prel_bincount_size', ['bincount with n = -2: invalid array size -2, from the allocation of the result (L-y)'],
           'printf("start\\n")\nlet c = bincount([0], -2)\nprintf("%d\\n", len(c))\n',
           'let c = bincount(', 'invalid array size %d' % e, 'start\n')
    e = raises(SizeError, bincount, [5], 3000000000)
    err_rt('r_prel_bincount_size_big', ['bincount with n = 3 000 000 000 > 2^31 - 1: invalid array size, reported before the',
                                        'out-of-range value 5 is looked at (the result is allocated first, DESIGN.md 2.5)'],
           'printf("start\\n")\nlet c = bincount([5], 3000000000)\nprintf("%d\\n", len(c))\n',
           'let c = bincount(', 'invalid array size %d' % e, 'start\n')
    e = raises(SizeError, linspace, 0.0, 1.0, 3000000000)
    err_rt('r_prel_linspace_size', ['linspace with n = 3 000 000 000 > 2^31 - 1: invalid array size (LANGUAGE.md 10.3, L-y)'],
           'printf("start\\n")\nlet v = linspace(0.0, 1.0, 3000000000)\nprintf("%d\\n", len(v))\n',
           'let v = linspace(', 'invalid array size %d' % e, 'start\n')
    err_rt('r_prel_meshgrid_oom', ['meshgrid results of 10^7 x 10^7 elements (8e14 bytes each) cannot be allocated: out of',
                                   'memory at the line of the call (LANGUAGE.md 10.3; DESIGN.md 2.6.2 L-y)'],
           'let x = zeros(10000000)\nprintf("start\\n")\nlet (X, Y) = meshgrid(x, x)\nprintf("%d\\n", rows(X))\n',
           'meshgrid(x, x)', 'out of memory', 'start\n')


# ============================================================ compile errors (L-s, L-t, L-z)
def compile_errors():
    err_c('err_prel_missing_arg', ['linspace with two arguments: missing argument (226) at the call (L-t; LANGUAGE.md 10)'],
          'let v = linspace(0.0, 1.0)\n', 'linspace(', 'linspace', 'missing argument')
    err_c('err_prel_too_many', ['linspace with four arguments: too many arguments (242) at the call (L-t)'],
          'let v = linspace(0.0, 1.0, 2, 3)\n', 'linspace(', 'linspace', 'too many arguments')
    err_c('err_prel_linspace_n_f64', ['an f64 n of linspace: type mismatch (201) at the argument, never no overload (L-t)'],
          'let v = linspace(0.0, 1.0, 2.5)\n', 'linspace(', '2.5', 'type mismatch: expected i64, found f64')
    err_c('err_prel_bincount_f64', ['bincount([1.0], 2): the literal is a fixed-size f64[1] (LANGUAGE.md 4.5), 201 at it (L-t)'],
          'let c = bincount([1.0], 2)\n', 'bincount(', '[1.0]', 'type mismatch: expected i64[], found f64[1]')
    err_c('err_prel_setdiff_f64', ['setdiff([1.5], [1]): 201 at the f64[1] literal (L-t)'],
          'let d = setdiff([1.5], [1])\n', 'setdiff(', '[1.5]', 'type mismatch: expected i64[], found f64[1]')
    err_c('err_prel_meshgrid_matrix', ['meshgrid of a matrix: 201 at the argument, f64[,] for f64[] (L-t, Decision 54)'],
          'let A = zeros(2, 2)\nlet y = zeros(2)\nlet (X, Y) = meshgrid(A, y)\n', 'meshgrid(', 'A, y',
          'type mismatch: expected f64[], found f64[,]')
    err_c('err_prel_ref', ['bincount(ref v, 2): the parameter as LANGUAGE.md 10 names it, 255 at the ref (L-t)'],
          'var v: i64[] = [1]\nlet c = bincount(ref v, 2)\n', 'bincount(', 'ref', "'idx' is not a ref parameter")
    err_c('err_prel_named', ['a named argument of a prelude function: the phase-rule word until phase 6, at the narg (L-t)'],
          'let v = linspace(0.0, 1.0, n: 3)\n', 'linspace(', 'n: 3', 'not supported yet: named arguments')
    err_c('err_prel_redef_fn', ['a program fn bincount: 212 at the item, the prelude\'s own items being exempt (L-s;',
                                'LANGUAGE.md 3.3)'],
          'fn bincount(v: i64[], n: i64) -> i64[] {\n    return v\n}\n', 'fn bincount', 'fn', 'redefinition of predeclared name')
    err_c('err_prel_redef_const', ['a program const linspace: 212 at the item (L-s)'],
          'const linspace = 3\n', 'const linspace', 'const', 'redefinition of predeclared name')
    err_c('err_prel_shadow_local', ['let setdiff = 1: 213 at the binding (L-s; LANGUAGE.md 3.3)'],
          'let setdiff = 1\n', 'let setdiff', 'setdiff', 'local name shadows a predeclared name')
    err_c('err_prel_shadow_param', ['a parameter named meshgrid: 213 at the param (L-s)'],
          'fn f(n: i64, meshgrid: i64) -> i64 {\n    return n\n}\n', 'fn f(', 'meshgrid', 'local name shadows a predeclared name')
    err_c('err_prel_shadow_for', ['a loop variable named bincount: 213 at the for node (L-s)'],
          'for bincount in 0..3 {\n    printf("%d\\n", bincount)\n}\n', 'for bincount', 'for', 'local name shadows a predeclared name')
    # the close-out (L-z): one test per after-phase-4 row that had none
    err_c('err_ns_matmul', ['A @ B of two matrices: not supported yet: @ until phase 8, at the operator node, which',
                            'stands at its left operand (DESIGN.md 2.6.2 after-phase-4 table, 3.3; L-z)'],
          'let A = zeros(2, 2)\nlet B = zeros(2, 2)\nlet C = A @ B\n', 'let C', 'A @', 'not supported yet: @')
    err_c('err_ns_lib_format', ['a call of format: its name until phase 6, at the call (DESIGN.md 2.6.2; L-z)'],
          'let s = format("%d", 3)\n', 'format(', 'format', 'not supported yet: format')
    err_c('err_ns_lib_solve', ['a call of solve: its name until phase 8, at the call (DESIGN.md 2.6.2; L-z)'],
          'let A = ones(2, 2)\nlet b = ones(2)\nlet x = solve(A, b)\n', 'solve(', 'solve', 'not supported yet: solve')
    err_c('err_ns_lib_figure', ['a call of figure: its name until phase 9, at the call (DESIGN.md 2.6.2; L-z)'],
          'let fig = figure(1, 1)\n', 'figure(', 'figure', 'not supported yet: figure')


# ============================================================ W5 acceptance (L-aa, 6.3)
W5_HEAD = '''// w5_stats -- the phase-4 acceptance program of sub-phase 4h (DESIGN.md 6.3, Decision 19, lead decision
// L-aa): W5's sampling and statistics. The code below is LANGUAGE.md Appendix D's port of
// workloads/w5_tolerance_mc.m, copied verbatim for what the four keys first_dev, mean_cold, std_cold
// and hist_counts need (the Dim struct and table, the inputs, the validation match, the sampling loop,
// uTop and Top, stack_gap, the cold statistics, the histogram by bincount, lcg_fill), followed by the
// JSON subset of DESIGN.md 6.3 written with printf; nothing else is written to standard output.
'''

W5_JSON = r'''
// ---------------------------------------------------------------- JSON subset (DESIGN.md 6.3)
printf("{\"first_dev\": [")
for i in 0..10 {
    if i > 0 { printf(", ") }
    printf("[")
    for j in 0..nDim {
        if j > 0 { printf(", ") }
        printf("%.17g", dev[i, j])
    }
    printf("]")
}
printf("], \"mean_cold\": %.17g, \"std_cold\": %.17g, \"hist_counts\": [", muC, sdC)
for k in 0..nBin {
    if k > 0 { printf(", ") }
    printf("%d", counts[k])
}
printf("]}\n")
'''


def appendix_d_code():
    with open(os.path.join(ROOT, 'docs', 'LANGUAGE.md'), encoding='utf-8') as f:
        text = f.read()
    start = text.index('### Appendix D.')
    body = text[start:]
    open_ = body.index('```sea\n') + len('```sea\n')
    close = body.index('\n```', open_)
    return body[open_:close + 1].split('\n')[:-1]


def block(lines, first, last, startswith=False):
    """lines[first .. last] inclusive, both given by their exact text (last: the first match after
    first; startswith: last is matched as a prefix)."""
    i = lines.index(first)
    for j in range(i, len(lines)):
        if (lines[j].startswith(last) if startswith else lines[j] == last):
            return lines[i:j + 1]
    raise AssertionError(last)


def w5_stats():
    L = appendix_d_code()
    parts = [
        block(L, 'struct Dim {', '}'),
        [''],
        block(L, '// ---------------------------------------------------------------- inputs', ']'),
        block(L, 'let nSample = 1_000_000      // Monte Carlo samples [-]', 'let yieldTarget = 0.9973'),
        [''],
        block(L, 'let nDim = len(dims)', '}'),
        [''],
        block(L, '// ---------------------------------------------------------------- sampling',
              'let Top = Tlo + (Thi - Tlo) * uTop'),
        [''],
        block(L, 'let nom = dims.nom', 'let (gapCold, gapHot) = stack_gap(', startswith=True),
        [''],
        block(L, '// ---------------------------------------------------------------- statistics',
              'let sdC = std(gapCold)'),
        [''],
        block(L, 'let binW = (histHi - histLo) / nBin', 'let counts = bincount(', startswith=True),
    ]
    fns = block(L, '// ================================================================ functions',
                '    return (gapCold, gapHot)') + ['}']
    # every copied line is a line of Appendix D, in Appendix D's order
    copied = [ln for p in parts for ln in p if ln != ''] + fns
    pos = -1
    for ln in copied:
        pos = L.index(ln, pos + 1)
    # the blocks that L-aa names are all there, and nothing the four keys do not need
    text = '\n'.join(copied)
    for need in ('struct Dim {', 'let dims = [', 'let scale = linspace(0.4, 1.6, 25)', 'match dims[d].dist {',
                 'var dev = zeros(nSample, nDim)', 'let uTop = lcg_fill(ref s, nSample)',
                 'let Top = Tlo + (Thi - Tlo) * uTop', 'fn stack_gap(', 'fn lcg_fill(',
                 'let muC = mean(gapCold)', 'let sdC = std(gapCold)', 'let bin = floor(',
                 'let inRange = bin >= 0 & bin < nBin', 'let counts = bincount(i64(bin[inRange]), nBin)'):
        assert need in text, need
    for omit in ('args()', 'now()', 'printf', 'write_json', 'figure', 'prctile_mid', 'lcgFinal', 'sigmaDim'):
        assert omit not in text, omit
    src = W5_HEAD + '\n' + '\n'.join(ln for p in parts for ln in p) + '\n' + W5_JSON + '\n' + '\n'.join(fns) + '\n'
    assert src.isascii()
    write(os.path.join(ACCEPT, 'w5_stats.sea'), src)
    write(os.path.join(ACCEPT, 'w5_stats.keys'), 'first_dev,mean_cold,std_cold,hist_counts\n')
    write(os.path.join(ACCEPT, 'w5_stats.wl'), 'w5_tolerance_mc\n')


prel_linspace()
prel_bincount()
prel_setdiff()
prel_meshgrid()
prel_ctx()
heap_prel_args()
heap_prel_exits()
runtime_errors()
compile_errors()
w5_stats()
print('prel4h_cases: %d programs, %d errors, accept/w5_stats' % (COUNT['programs'], COUNT['errors']))
