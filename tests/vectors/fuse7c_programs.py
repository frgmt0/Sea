"""Sub-phase 7c, T1: the fusion tests of DESIGN.md 6.2 ("Phase-7 tests", the bullets "`fuse_*` programs" and
"`r_fuse_*` errors").

Run with `timeout 120 uv run --no-project python tests/vectors/fuse7c_programs.py --out DIR`. It writes

  DIR/programs/fuse_*    programs whose output would change if a fusion (DESIGN.md 2.12.4, F1-F5) were inexact:
                         every element of every result printed with %.17g, values chosen so that a reassociated,
                         reordered, wrongly broadcast or wrongly aliased evaluation prints other bytes
  DIR/errors/r_fuse_*    run-time errors: the first failing check in reference order (DESIGN.md 2.12.2 (2),
                         F1 (2), F2 (4), L-en), each with the output written before it

and nothing else (copy the files into tests/ by hand; never run it into the repo tree).

Phase 7 changes no program's behaviour (DESIGN.md 2.12.2: "a fused or vectorized program has exactly the
observable behaviour of the same program compiled without them"), so every expected byte is the behaviour
LANGUAGE.md gives the program, operator by operator, and is derived here, never from a run of the compiler:

* the values come from a Python mirror of each program, written beside the program: exact integers for `i64`
  (a result outside -2^63 .. 2^63-1 is `integer overflow`, LANGUAGE.md 6.5), IEEE binary64 for `f64` (every
  `+ - * /` one Python float operation, in the order of the parse tree, LANGUAGE.md 6.8; `sqrt` correctly
  rounded; `x ^ k` for a constant |k| <= 4 the pinned multiplications of 6.5; `exp log sin cos pow hypot` the
  bit-exact model tests/vectors/math_model.py of DESIGN.md 4.10.6, which is Sea's definition of those
  functions, Decision 6); `min`/`max` of two values as LANGUAGE.md 10.4 (a NaN gives the other, a tie the
  first argument); broadcasting as 6.3; masks and `.flat` in column-major order (5.2, 5.6);
* reductions as LANGUAGE.md 10.5: `sum`'s eight lanes starting at -0.0 with the pinned final tree and +0 for
  the empty sum; `mean` = sum / n; `variance` two-pass with the 8-lane sum of squared deviations over n - 1
  (n = 1 gives 0, n = 0 NaN); `std` its correctly rounded square root; `max min argmax argmin` the first extreme
  in index order with NaN ignored (all NaN: NaN and index 0); `i64` sums in index order, each partial sum
  checked; over a mask selection the positions are those of the selection (5.2: the selection is a vector);
* every printed `f64` goes through the exact printf oracle tests/vectors/progfmt.py (LANGUAGE.md 11.1);
* the run-time errors follow LANGUAGE.md 5.4, 5.5, 6.3, 9.2 and the reference order of DESIGN.md 2.12.2 (2):
  an element-wise tree evaluated node by node in post-order (each node's operands left to right, then its
  shape check, then its element loop), a statement's store after its value; statements in order. Messages
  from the error table (LANGUAGE.md 9.2), lines from a marker in the source text (the line of the failing
  node or statement; every statement whose node fails stands on one line, except where two lines are the
  point of the test).

Where the bullet names a value (`argmax(v[m])` with v = [9, 1, 5], m = [false, true, true] is 1; `v[w] = v[w] *
2.0 + 1.0` with w = [0, 0] leaves v[0] = 3) the mirror asserts it. The data of the `sum` cases are chosen (and
asserted) so that the 8-lane result differs from left-to-right summation and, for a mask selection, from lanes
counted by the position in the whole vector.
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import call6_cases as C  # noqa: E402  (helpers of 6b: prog, err_r, source, g17 through progfmt)
import math_model as MM  # noqa: E402  (Sea's exp log sin cos pow hypot, DESIGN.md 4.10.6)

INF = math.inf
NAN = math.nan
I64_MIN = -(1 << 63)
I64_MAX = (1 << 63) - 1


# ---------------------------------------------------------------------------- output helpers
def g17(x):
    return C.g17(float(x))


def out_v(v):
    """pv(v): `n:` and every element with %.17g."""
    return '%d:' % len(v) + ''.join(' ' + g17(x) for x in v) + '\n'


def out_iv(v):
    """pvi(v) / pvb(v): `n:` and every element with %d (bool as 0 or 1)."""
    return '%d:' % len(v) + ''.join(' %d' % int(x) for x in v) + '\n'


def out_m(M):
    """pm(A): `RxC`, then ` |` and the elements of each row with %.17g."""
    s = '%dx%d' % (M.r, M.c)
    for i in range(M.r):
        s += ' |' + ''.join(' ' + g17(M.at(i, j)) for j in range(M.c))
    return s + '\n'


# ---------------------------------------------------------------------------- Sea helpers
PV = r'''fn pv(v: f64[]) {
    printf("%d:", len(v))
    for x in v {
        printf(" %.17g", x)
    }
    printf("\n")
}
'''
PVI = r'''fn pvi(v: i64[]) {
    printf("%d:", len(v))
    for x in v {
        printf(" %d", x)
    }
    printf("\n")
}
'''
PM = r'''fn pm(A: f64[,]) {
    printf("%dx%d", rows(A), cols(A))
    for i in 0..rows(A) {
        printf(" |")
        for j in 0..cols(A) {
            printf(" %.17g", A[i, j])
        }
    }
    printf("\n")
}
'''


# ---------------------------------------------------------------------------- literals
def lit(x):
    """A Sea expression with exactly the f64 value x (a float_lit is correctly rounded, LANGUAGE.md 3.4)."""
    x = float(x)
    if x != x:
        return 'nan'
    if x == INF:
        return 'inf'
    if x == -INF:
        return '-inf'
    s = repr(x)
    assert float(s) == x and (math.copysign(1.0, float(s)) == math.copysign(1.0, x))
    return s


def ilit(i):
    assert I64_MIN <= i <= I64_MAX
    return '-9223372036854775807 - 1' if i == I64_MIN else str(i)


def vlit(xs):
    return '[' + ', '.join(lit(x) for x in xs) + ']'


def ivlit(xs):
    return '[' + ', '.join(ilit(x) for x in xs) + ']'


def bvlit(xs):
    return '[' + ', '.join('true' if b else 'false' for b in xs) + ']'


def mlit(M):
    return '[' + '; '.join(', '.join(lit(M.at(i, j)) for j in range(M.c)) for i in range(M.r)) + ']'


def imlit(M):
    return '[' + '; '.join(', '.join(ilit(M.at(i, j)) for j in range(M.c)) for i in range(M.r)) + ']'


def bmlit(M):
    return '[' + '; '.join(', '.join('true' if M.at(i, j) else 'false' for j in range(M.c))
                           for i in range(M.r)) + ']'


# ---------------------------------------------------------------------------- the Python mirror
class Mat:
    """A matrix, column-major: element (i, j) is d[i + j * r] (LANGUAGE.md 4.5)."""

    def __init__(self, r, c, d):
        assert len(d) == r * c
        self.r, self.c, self.d = r, c, list(d)

    @staticmethod
    def rows(rs):
        r, c = len(rs), len(rs[0])
        return Mat(r, c, [rs[i][j] for j in range(c) for i in range(r)])

    @staticmethod
    def fn(r, c, f):
        return Mat(r, c, [f(i, j) for j in range(c) for i in range(r)])

    def at(self, i, j):
        return self.d[i + j * self.r]

    def T(self):
        return Mat.fn(self.c, self.r, lambda i, j: self.at(j, i))

    def flat(self):
        return list(self.d)

    def sub(self, ri, ci):
        return Mat.fn(len(ri), len(ci), lambda i, j: self.at(ri[i], ci[j]))

    def mask(self, M):
        return [x for x, b in zip(self.d, M.d) if b]


def col(v):
    return Mat(len(v), 1, v)


def row(v):
    return Mat(1, len(v), v)


def _shape(x):
    if isinstance(x, Mat):
        return ('m', x.r, x.c)
    if isinstance(x, list):
        return ('v', len(x))
    return None


def ew(f, *ops):
    """f applied element by element with the broadcasting of LANGUAGE.md 6.3 (scalars skipped, the shapes
    combined left to right); the mirrors here never mismatch, which this asserts."""
    shp = None
    for o in ops:
        s = _shape(o)
        if s is None:
            continue
        if shp is None:
            shp = s
        elif s[0] == 'v':
            assert shp == s, (shp, s)
        else:
            assert shp[0] == 'm'
            r = shp[1] if shp[1] == s[1] else (s[1] if shp[1] == 1 else shp[1])
            c = shp[2] if shp[2] == s[2] else (s[2] if shp[2] == 1 else shp[2])
            assert shp[1] in (s[1], 1) or s[1] == 1
            assert shp[2] in (s[2], 1) or s[2] == 1
            shp = ('m', r, c)
    if shp is None:
        return f(*ops)
    if shp[0] == 'v':
        return [f(*[o[k] if isinstance(o, list) else o for o in ops]) for k in range(shp[1])]

    def el(o, i, j):
        if isinstance(o, Mat):
            return o.at(i if o.r > 1 else 0, j if o.c > 1 else 0)
        return o
    return Mat.fn(shp[1], shp[2], lambda i, j: f(*[el(o, i, j) for o in ops]))


def fabs(x):
    return MM.fabs(x)


def fmin(a, b):
    """min(a, b) of LANGUAGE.md 10.4: a NaN gives the other operand; a tie (-0, +0) the first."""
    if a != a:
        return b
    if b != b:
        return a
    return b if b < a else a


def fmax(a, b):
    if a != a:
        return b
    if b != b:
        return a
    return b if b > a else a


def chk(x):
    """An exact i64 result, or the run-time error `integer overflow` (LANGUAGE.md 6.5)."""
    assert I64_MIN <= x <= I64_MAX, 'integer overflow'
    return x


def sum8(xs):
    """sum of LANGUAGE.md 10.5: eight lanes from -0.0, the pinned final tree; the empty sum +0."""
    if not xs:
        return 0.0
    a = [-0.0] * 8
    for i, x in enumerate(xs):
        a[i % 8] = a[i % 8] + x
    return ((a[0] + a[1]) + (a[2] + a[3])) + ((a[4] + a[5]) + (a[6] + a[7]))


def sum_seq(xs):
    s = -0.0
    for x in xs:
        s = s + x
    return s


def mean(xs):
    return sum8(xs) / len(xs) if xs else NAN


def variance(xs):
    n = len(xs)
    if n == 0:
        return NAN
    if n == 1:
        return 0.0
    m = mean(xs)
    return sum8([(x - m) * (x - m) for x in xs]) / (n - 1)


def std(xs):
    v = variance(xs)
    return math.sqrt(v) if v == v else NAN


def rmax(xs, gt=True):
    """(value, index) of max/argmax (min/argmin with gt=False): the first extreme in index order, NaN
    ignored; all NaN: (NaN, 0); empty: the run-time error."""
    assert xs, 'empty'
    best, bi = NAN, 0
    for i, x in enumerate(xs):
        if x != x:
            continue
        if best != best or (x > best if gt else x < best):
            best, bi = x, i
    return best, bi


def isum(xs):
    s = 0
    for x in xs:
        s = chk(s + x)
    return s


def imean(xs):
    return float(isum(xs)) / float(len(xs)) if xs else NAN


def ivariance(xs):
    """variance of an i64 vector (LANGUAGE.md 10.5): the mean of the checked i64 sum, then the converted
    elements in the f64 rule (n = 1 gives 0, n = 0 NaN)."""
    n = len(xs)
    if n == 0:
        return NAN
    if n == 1:
        return 0.0
    m = imean(xs)
    return sum8([(float(x) - m) * (float(x) - m) for x in xs]) / (n - 1)


def imax(xs, gt=True):
    best, bi = xs[0], 0
    for i, x in enumerate(xs):
        if (x > best if gt else x < best):
            best, bi = x, i
    return best, bi


def powk2(x):
    return x * x


def pi_d3(d):
    return math.pi * ((d * d) * d)


# ============================================================================ F1-F5, one program each
SPLIT2 = r'''elemental fn split2(x: f64, y: f64) -> (f64, f64) {
    let s = x + y
    return (s * 0.5, s - x)
}
'''
DAMP = r'''elemental fn damp(x: f64, k: i64) -> f64 {
    return if x > 0.25 { x / f64(k) } else { x * 3.0 - 0.1 }
}
'''
COEF = r'''struct Coef {
    a: f64
    b: f64
}
elemental fn lin2(x: f64, y: f64, c: Coef) -> (f64, f64) {
    let p = c.a * x + y
    return (p, p * c.b - x)
}
'''


def m_split2(x, y):
    s = x + y
    return (s * 0.5, s - x)


def m_lin2(x, y, ca, cb):
    p = ca * x + y
    return (p, p * cb - x)


def fuse_f1_tree():
    """F1: one vector tree and two matrix trees mixing scalars, vectors, matrices, broadcasting in each
    dimension, fixed-size and dynamic operands, `where`, conversions, elementary functions and elemental
    functions (one of two results discarded)."""
    w = [3, -1, 4, -1, 5, -9, 2, -6, 5]
    m = [True, False, True, True, False, False, True, False, True]
    rowv = [0.5, -2.0, 1e-17, 7.25]
    F = Mat.rows([[1.0, 2.0, 3.0, 4.0], [-1.0, -2.0, -3.0, -4.0], [0.1, 0.2, 0.3, 0.4]])
    K = Mat.rows([[1, 2, 3, 4], [5, 6, 7, 8], [9, 10, 11, 12]])
    body = PV + PM + SPLIT2 + DAMP + '''var u = zeros(9)
for i in 0..9 {
    u[i] = f64(i) * 0.1 - 0.35
}
let w = %s
let m = %s
let c = 1.0e16
let (h, _) = split2(u, f64(w) * 0.25)
let r = sqrt(abs(u * c + f64(w))) - c * 1e-16 + where(m, exp(u), f64(w) / 3.0) * damp(h, 2) + min(u, 0.0) ^ 2
pv(h)
pv(r)
var A = zeros(3, 4)
for j in 0..4 {
    for i in 0..3 {
        A[i, j] = f64(i * 4 + j) * 0.3 - 1.1
    }
}
let rowv = %s
var colv = zeros(3)
for i in 0..3 {
    colv[i] = 1.0 / f64(i + 3)
}
let F = %s
let K = %s
let M = A * rowv.row + colv.col * rowv.row - F / 3.0 + where(A > 0.0, hypot(A, F), -A) + f64(K) * 1e-3
pm(M)
let (G, _) = split2(A * c, colv.col)
let N = G - A * c + log(abs(A) + 1.0) * cos(F)
pm(N)
''' % (ivlit(w), bvlit(m), vlit(rowv), mlit(F), imlit(K))
    u = [float(i) * 0.1 - 0.35 for i in range(9)]
    c = 1.0e16
    h = [m_split2(x, float(k) * 0.25)[0] for x, k in zip(u, w)]
    r = []
    for i in range(9):
        x, wf, hv = u[i], float(w[i]), h[i]
        a1 = math.sqrt(fabs(x * c + wf)) - c * 1e-16
        wh = MM.sea_exp(x) if m[i] else wf / 3.0
        dm = hv / 2.0 if hv > 0.25 else hv * 3.0 - 0.1
        mn = fmin(x, 0.0)
        r.append((a1 + wh * dm) + mn * mn)
    A = Mat.fn(3, 4, lambda i, j: float(i * 4 + j) * 0.3 - 1.1)
    colv = [1.0 / float(i + 3) for i in range(3)]
    M = ew(lambda a, rv, cv, f, k: ((((a * rv) + (cv * rv)) - (f / 3.0))
                                    + (MM.sea_hypot(a, f) if a > 0.0 else -a)) + float(k) * 1e-3,
           A, row(rowv), col(colv), F, K)
    G = ew(lambda a, cv: m_split2(a * c, cv)[0], A, col(colv))
    N = ew(lambda g, a, f: (g - a * c) + MM.sea_log(fabs(a) + 1.0) * MM.sea_cos(f), G, A, F)
    out = out_v(h) + out_v(r) + out_m(M) + out_m(N)
    C.prog('fuse_f1_tree', ['F1 (DESIGN.md 2.12.4): a vector tree and matrix trees of every fusible node kind: '
                            'scalars, dynamic and', 'fixed-size vectors and matrices, `.row` and `.col` '
                            'broadcast in each dimension, `where`, `f64()`, `sqrt abs exp min',
                            'hypot log cos`, `^ 2`, elemental functions (one of two results discarded); '
                            'u * c + f64(w) with c = 1e16 shows any reassociation'], body, out)


def fuse_f2_group():
    """F2: a vector group (stored local, unstored locals, an F5 node, a reused target) and a matrix group
    with broadcast inputs, an F5 node, a target and a reduction as its last statement."""
    x = [0.3, -1.25, 2.5, 7.0, -0.001, 1e-3]
    y = [7, -3, 12, 0, 5, -8]
    rowv = [0.25, -4.0, 1e-9]
    colv = [3.0, -0.5]
    body = PV + PM + COEF + '''let cf = Coef { a: 1e16, b: 0.5 }
let x: f64[] = %s
let y = %s
var lo = filled(0.5, 6)
let a = x * 1e16 + f64(y)
let b = a - x * 1e16
let (e, _) = lin2(b, x, cf)
lo = where(e > 1.0, e, lo - 1.0) + sqrt(abs(x))
pv(a)
pv(lo)
var A = zeros(2, 3)
for j in 0..3 {
    for i in 0..2 {
        A[i, j] = f64(i - j) * 0.7 + 0.05
    }
}
let rowv = %s
let colv: f64[] = %s
var P = filled(1.0, 2, 3)
let G1 = A * rowv.row + 0.25
let G2 = sqrt(abs(G1)) - colv.col
let (_, G3) = lin2(G2, G1, cf)
P = G3 * P - G1
let tot = sum((G3 - P).flat)
pm(G1)
pm(P)
printf("%%.17g\\n", tot)
''' % (vlit(x), ivlit(y), vlit(rowv), vlit(colv))
    a = [xi * 1e16 + float(yi) for xi, yi in zip(x, y)]
    b = [ai - xi * 1e16 for ai, xi in zip(a, x)]
    e = [m_lin2(bi, xi, 1e16, 0.5)[0] for bi, xi in zip(b, x)]
    lo = [(ei if ei > 1.0 else 0.5 - 1.0) + math.sqrt(fabs(xi)) for ei, xi in zip(e, x)]
    A = Mat.fn(2, 3, lambda i, j: float(i - j) * 0.7 + 0.05)
    G1 = ew(lambda av, rv: av * rv + 0.25, A, row(rowv))
    G2 = ew(lambda g, cv: math.sqrt(fabs(g)) - cv, G1, col(colv))
    G3 = ew(lambda g2, g1: m_lin2(g2, g1, 1e16, 0.5)[1], G2, G1)
    P = ew(lambda g3, g1: g3 * 1.0 - g1, G3, G1)
    tot = sum8([g3 - p for g3, p in zip(G3.flat(), P.flat())])
    out = out_v(a) + out_v(lo) + out_m(G1) + out_m(P) + g17(tot) + '\n'
    C.prog('fuse_f2_group', ['F2 (DESIGN.md 2.12.4): two groups of adjacent element-wise statements: a stored '
                             'local read after the group,', 'unstored locals, an elemental application '
                             'with a discarded result, `where` into a reused target; a matrix group',
                             'over broadcast inputs ending in a target and `sum` of a `.flat` tree; '
                             'x * 1e16 + f64(y) - x * 1e16 shows reassociation'], body, out)


def fuse_f3_reduce():
    """F3: every reduction over a tree, over `.flat` of a matrix tree and over a same-mask selection."""
    x = [0.5, -1e16, 3.25, 1.0, 1e16, 7.5, 2.0, -0.75, 1e15, 4.0, -2.5]
    z = [0.1, 2.0, -3.0, 0.5, 1.5, -1.0, 2.5, 3.0, -0.5, 1.25, 0.75]
    y = [5, -3, 12, 7, 12, -8, 0, 4, 12, -1, 3]
    m = [True, True, False, True, True, True, True, False, True, True, True]
    A = Mat.rows([[0.125, 0.25, -3.5, 2.0], [7.0, -1e16, 1e16, 9.5], [-0.5, 3.0, 1e15, -2.25]])
    B = Mat.rows([[0.5, 1.0, -1.0, 2.5], [6.5, 0.0, 0.5, 9.5], [1.0, -3.0, 2.0, -2.0]])
    K = Mat.rows([[4, -7, 0, 2], [9, 1, -5, 3], [8, 8, -2, 6]])
    body = PV + '''let x: f64[] = %s
let z = %s
let y = %s
let m = %s
let A: f64[,] = %s
let B = %s
let K: i64[,] = %s
printf("sum %%.17g %%.17g %%.17g\\n", sum(x * 3.0 + z * z - 0.5), sum((A * 2.0 - B).flat), sum(x[m] * 2.0 - z[m]))
printf("mean %%.17g %%.17g %%.17g\\n", mean(x * 3.0 + z * z - 0.5), mean((A * 2.0 - B).flat), mean(x[m] * 2.0 - z[m]))
printf("variance %%.17g %%.17g %%.17g\\n", variance(x * 3.0 + z * z - 0.5), variance((A * 2.0 - B).flat), variance(x[m] * 2.0 - z[m]))
printf("std %%.17g %%.17g %%.17g\\n", std(x * 3.0 + z * z - 0.5), std((A * 2.0 - B).flat), std(x[m] * 2.0 - z[m]))
printf("max %%.17g %%.17g %%.17g\\n", max(x * 3.0 + z * z - 0.5), max((A * 2.0 - B).flat), max(x[m] * 2.0 - z[m]))
printf("min %%.17g %%.17g %%.17g\\n", min(x * 3.0 + z * z - 0.5), min((A * 2.0 - B).flat), min(x[m] * 2.0 - z[m]))
printf("argmax %%d %%d %%d\\n", argmax(x * 3.0 + z * z - 0.5), argmax((A * 2.0 - B).flat), argmax(x[m] * 2.0 - z[m]))
printf("argmin %%d %%d %%d\\n", argmin(x * 3.0 + z * z - 0.5), argmin((A * 2.0 - B).flat), argmin(x[m] * 2.0 - z[m]))
printf("isum %%d %%d %%d\\n", sum(y * 3 - 2), sum((K * 2 + 1).flat), sum(y[m] * 3 - 2))
printf("imean %%.17g %%.17g %%.17g\\n", mean(y * 3 - 2), mean((K * 2 + 1).flat), mean(y[m] * 3 - 2))
printf("ivariance %%.17g %%.17g %%.17g\\n", variance(y * 3 - 2), variance((K * 2 + 1).flat), variance(y[m] * 3 - 2))
printf("imax %%d %%d %%d\\n", max(y * 3 - 2), max((K * 2 + 1).flat), max(y[m] * 3 - 2))
printf("imin %%d %%d %%d\\n", min(y * 3 - 2), min((K * 2 + 1).flat), min(y[m] * 3 - 2))
printf("iargmax %%d %%d %%d\\n", argmax(y * 3 - 2), argmax((K * 2 + 1).flat), argmax(y[m] * 3 - 2))
printf("iargmin %%d %%d %%d\\n", argmin(y * 3 - 2), argmin((K * 2 + 1).flat), argmin(y[m] * 3 - 2))
printf("nnz %%d %%d %%d\\n", nnz(x > z), nnz((A > B).flat), nnz(x[m] > z[m]))
printf("any %%d %%d %%d\\n", any(x > z + 1e17), any((A > B + 1e17).flat), any(x[m] > z[m] + 1e17))
printf("all %%d %%d %%d\\n", all(x > z - 1e17), all((A > B - 1e17).flat), all(x[m] > z[m] - 1e17))
printf("any2 %%d %%d %%d\\n", any(x > z), any((A > B).flat), any(x[m] > z[m]))
printf("all2 %%d %%d %%d\\n", all(x > z), all((A > B).flat), all(x[m] > z[m]))
''' % (vlit(x), vlit(z), ivlit(y), bvlit(m), mlit(A), mlit(B), imlit(K))
    t1 = [xi * 3.0 + zi * zi - 0.5 for xi, zi in zip(x, z)]
    t2 = [a * 2.0 - b for a, b in zip(A.flat(), B.flat())]
    t3 = [xi * 2.0 - zi for xi, zi, mi in zip(x, z, m) if mi]
    # the data separate the pinned order from others (asserted, not required by the test's meaning)
    assert sum8(t1) != sum_seq(t1) and sum8(t2) != sum_seq(t2)
    tk = [-0.0] * 8
    for k, (xi, zi, mi) in enumerate(zip(x, z, m)):
        if mi:
            tk[k % 8] = tk[k % 8] + (xi * 2.0 - zi)
    assert sum8(t3) != ((tk[0] + tk[1]) + (tk[2] + tk[3])) + ((tk[4] + tk[5]) + (tk[6] + tk[7]))
    ts = (t1, t2, t3)
    i1 = [chk(chk(yi * 3) - 2) for yi in y]
    i2 = [chk(chk(k * 2) + 1) for k in K.flat()]
    i3 = [chk(chk(yi * 3) - 2) for yi, mi in zip(y, m) if mi]
    iss = (i1, i2, i3)
    b1 = [xi > zi for xi, zi in zip(x, z)]
    b2 = [a > b for a, b in zip(A.flat(), B.flat())]
    b3 = [xi > zi for xi, zi, mi in zip(x, z, m) if mi]
    bs = (b1, b2, b3)
    any_big = ([xi > zi + 1e17 for xi, zi in zip(x, z)], [a > b + 1e17 for a, b in zip(A.flat(), B.flat())],
               [xi > zi + 1e17 for xi, zi, mi in zip(x, z, m) if mi])
    all_small = ([xi > zi - 1e17 for xi, zi in zip(x, z)], [a > b - 1e17 for a, b in zip(A.flat(), B.flat())],
                 [xi > zi - 1e17 for xi, zi, mi in zip(x, z, m) if mi])
    o = ''
    o += 'sum ' + ' '.join(g17(sum8(t)) for t in ts) + '\n'
    o += 'mean ' + ' '.join(g17(mean(t)) for t in ts) + '\n'
    o += 'variance ' + ' '.join(g17(variance(t)) for t in ts) + '\n'
    o += 'std ' + ' '.join(g17(std(t)) for t in ts) + '\n'
    o += 'max ' + ' '.join(g17(rmax(t)[0]) for t in ts) + '\n'
    o += 'min ' + ' '.join(g17(rmax(t, False)[0]) for t in ts) + '\n'
    o += 'argmax ' + ' '.join('%d' % rmax(t)[1] for t in ts) + '\n'
    o += 'argmin ' + ' '.join('%d' % rmax(t, False)[1] for t in ts) + '\n'
    o += 'isum ' + ' '.join('%d' % isum(t) for t in iss) + '\n'
    o += 'imean ' + ' '.join(g17(imean(t)) for t in iss) + '\n'
    o += 'ivariance ' + ' '.join(g17(ivariance(t)) for t in iss) + '\n'
    o += 'imax ' + ' '.join('%d' % imax(t)[0] for t in iss) + '\n'
    o += 'imin ' + ' '.join('%d' % imax(t, False)[0] for t in iss) + '\n'
    o += 'iargmax ' + ' '.join('%d' % imax(t)[1] for t in iss) + '\n'
    o += 'iargmin ' + ' '.join('%d' % imax(t, False)[1] for t in iss) + '\n'
    o += 'nnz ' + ' '.join('%d' % sum(1 for b in t if b) for t in bs) + '\n'
    o += 'any ' + ' '.join('%d' % any(t) for t in any_big) + '\n'
    o += 'all ' + ' '.join('%d' % all(t) for t in all_small) + '\n'
    o += 'any2 ' + ' '.join('%d' % any(t) for t in bs) + '\n'
    o += 'all2 ' + ' '.join('%d' % all(t) for t in bs) + '\n'
    assert [any(t) for t in any_big] == [False] * 3 and [all(t) for t in all_small] == [True] * 3
    C.prog('fuse_f3_reduce', ['F3 (DESIGN.md 2.12.4): sum mean variance std max min argmax argmin over an '
                              'f64 tree, over `.flat` of a', 'matrix tree and over a same-mask selection '
                              '`x[m] * 2.0 - z[m]` (9 of 11 selected: lanes and indices by position in',
                              'the selection); the i64 forms and nnz any all over bool trees (LANGUAGE.md '
                              '10.5); data whose 8-lane sums differ', 'from left-to-right sums'], body, o)


def fuse_f4_views():
    """F4: folded views (.T .flat .col .row), range and `:` selections with steps, an index vector and same-mask
    selections as leaves of trees."""
    A = Mat.rows([[1.5, -2.0, 3.25, 0.5], [7.0, 1e-3, -0.75, 11.0], [-4.5, 6.0, 2.5, -8.0]])
    B = Mat.rows([[0.25, 9.0, -1.0], [3.5, -6.5, 2.0], [1e16, 0.5, 4.0], [-2.0, 7.5, -0.125]])
    v = [2.0, -3.5, 0.125, 10.0]
    u = [1.0, -1.0, 4.0]
    u2 = [0.5, 1.5, -2.5, 3.5]
    m = [True, False, True, True]
    w = [3, 0, 0, 2]
    Mk = Mat.rows([[True, False, True, False], [False, True, True, False], [True, True, False, True]])
    body = PV + PM + '''let A: f64[,] = %s
let B: f64[,] = %s
let v: f64[] = %s
let u = %s
let u2: f64[] = %s
let m = %s
let w: i64[] = %s
let M = %s
let P = A * B.T + v.row - u.col * 0.5
let q = A.flat * 2.0 - B.T.flat
let s = A[1, :] * v + A[2, 0..4] - v[w]
let t = A[0..3 step 2, 1..3] * 10.0 + B[1..3, 0..2].T
let k = v[m] * 3.0 - u2[m]
let mm = A[M] + B.T[M]
let cc = A[:, 3] - A.T[1, 0..3] + A[$-1..=0 step -1, 0]
pm(P)
pv(q)
pv(s)
pm(t)
pv(k)
pv(mm)
pv(cc)
''' % (mlit(A), mlit(B), vlit(v), vlit(u), vlit(u2), bvlit(m), ivlit(w), bmlit(Mk))
    BT = B.T()
    P = ew(lambda a, bt, vr, uc: (a * bt + vr) - uc * 0.5, A, BT, row(v), col(u))
    q = [a * 2.0 - b for a, b in zip(A.flat(), BT.flat())]
    s = [(A.at(1, j) * v[j] + A.at(2, j)) - v[w[j]] for j in range(4)]
    Bs = B.sub([1, 2], [0, 1]).T()
    t = ew(lambda a, b: a * 10.0 + b, A.sub([0, 2], [1, 2]), Bs)
    k = [vi * 3.0 - ui for vi, ui, mi in zip(v, u2, m) if mi]
    mm = [a + b for a, b in zip(A.mask(Mk), BT.mask(Mk))]
    # A.T[1, 0..3] is column 1 of A; A[$-1..=0 step -1, 0] is column 0 bottom up
    cc = [(A.at(i, 3) - A.T().at(1, i)) + A.at(2 - i, 0) for i in range(3)]
    out = out_m(P) + out_v(q) + out_v(s) + out_m(t) + out_v(k) + out_v(mm) + out_v(cc)
    C.prog('fuse_f4_views', ['F4 (DESIGN.md 2.12.4): folded leaves: `.T`, `.flat`, `.row`, `.col`, a row, a '
                             'column and a reversed', 'range, ranges with a step, a view of a selection, '
                             'an index vector with a repeat, same-mask selections of a vector', 'and of '
                             'a matrix and its transpose (LANGUAGE.md 5.2, 5.6): every leaf read at its '
                             'own index map'], body, out)


def fuse_f5_elemental():
    """F5: elemental applications as k-result nodes: results discarded, broadcast, i64 arrays to f64 parameters,
    a uniform struct parameter, one-result applications inside trees."""
    v = [0.5, -1.25, 3.0, 1e-8, 2.75]
    k = [3, -2, 7, 1, 4]
    on = [True, False, True, True, False]
    A = Mat.rows([[1.5, -0.5, 4.0], [-2.25, 0.125, 6.5]])
    rowv = [1.5, -0.25, 1e-8]
    body = PV + PM + COEF + '''elemental fn sq(x: f64) -> f64 {
    return x * x
}
elemental fn mix(x: f64, n: i64, on: bool) -> f64 {
    return if on { x * f64(n) } else { x / f64(n) - x }
}
let cf = Coef { a: 1e16, b: 0.5 }
let v: f64[] = %s
let k = %s
let on = %s
let (r1, _) = lin2(v * 2.0, k, cf)
let A: f64[,] = %s
let rowv = %s
let (_, r2) = lin2(A, rowv.row, cf)
let z = sq(v) - mix(v, k, on) * 2.0 + sq(r1 - v * 2e16)
let Z = sq(A * rowv.row) + mix(A, 3, A > 0.0) / 3.0
pv(r1)
pm(r2)
pv(z)
pm(Z)
''' % (vlit(v), ivlit(k), bvlit(on), mlit(A), vlit(rowv))

    def mix(x, n, o):
        return x * float(n) if o else x / float(n) - x
    r1 = [m_lin2(vi * 2.0, float(ki), 1e16, 0.5)[0] for vi, ki in zip(v, k)]
    r2 = ew(lambda a, rv: m_lin2(a, rv, 1e16, 0.5)[1], A, row(rowv))
    z = [(vi * vi - mix(vi, ki, oi) * 2.0) + powk2(ri - vi * 2e16) for vi, ki, oi, ri in zip(v, k, on, r1)]
    Z = ew(lambda a, rv: powk2(a * rv) + mix(a, 3, a > 0.0) / 3.0, A, row(rowv))
    out = out_v(r1) + out_m(r2) + out_v(z) + out_m(Z)
    C.prog('fuse_f5_elemental', ['F5 (DESIGN.md 2.12.4): elemental applications as nodes of trees and groups: '
                                 'two results with either one', 'discarded, an `i64` array for an `f64` '
                                 'parameter, a uniform struct, a `.row` broadcast against a matrix, an `i64`',
                                 'scalar and a `bool` matrix argument, one-result applications inside '
                                 'larger trees (LANGUAGE.md 8.5)'], body, out)


# ============================================================================ groups
def fuse_group_locals():
    x = [0.1, -2.5, 3.75, 1e-3, 42.0]
    z = [7.0, 0.3, -1.5, 2.0, -0.25]
    body = PV + '''let x: f64[] = %s
let z: f64[] = %s
let a = x * 1e16 + z
let t = a - x * 1e16
let u = t * t - z
let v = where(u > 0.0, sqrt(u), u * 3.0)
pv(a)
pv(v)
''' % (vlit(x), vlit(z))
    a = [xi * 1e16 + zi for xi, zi in zip(x, z)]
    t = [ai - xi * 1e16 for ai, xi in zip(a, x)]
    u = [ti * ti - zi for ti, zi in zip(t, z)]
    v = [math.sqrt(ui) if ui > 0.0 else ui * 3.0 for ui in u]
    C.prog('fuse_group_locals', ['F2 (DESIGN.md 2.12.4, L-es): a group of four `let`s: `a` stored (read after '
                                 'the group), `t` and `u` read', 'only inside the group (never stored), `v` '
                                 'stored; each later statement reads the earlier locals at the same element'],
           body, out_v(a) + out_v(v))


def fuse_group_reuse():
    x = [0.5, 1.5, -2.0, 4.0, 1e-8]
    Cm = Mat.rows([[1.0, -2.5, 0.75], [3.0, 1e16, -0.5]])
    body = PV + PM + '''let x: f64[] = %s
var lo = zeros(5)
var hi = filled(9.0, 3)
for it in 0..4 {
    let mid = x * f64(it) + 0.125
    lo = lo + mid * 1e-3
    hi = mid - lo * 3.0
    pv(hi)
}
pv(lo)
var B = zeros(2, 2)
let Cm: f64[,] = %s
B = Cm * 2.0 + 1.0
pm(B)
B = B * B - Cm
pm(B)
''' % (vlit(x), mlit(Cm))
    lo = [0.0] * 5
    o = ''
    for it in range(4):
        mid = [xi * float(it) + 0.125 for xi in x]
        lo = [li + mi * 1e-3 for li, mi in zip(lo, mid)]
        hi = [mi - li * 3.0 for mi, li in zip(mid, lo)]
        o += out_v(hi)
    o += out_v(lo)
    B = ew(lambda cc: cc * 2.0 + 1.0, Cm)
    o += out_m(B)
    B = ew(lambda b, cc: b * b - cc, B, Cm)
    o += out_m(B)
    C.prog('fuse_group_reuse', ['F2 (6) buffer reuse (DESIGN.md 2.12.4): `lo` reused in every iteration (same '
                                'shape), `hi` of length 3', 'replaced by length 5 in the first iteration (the '
                                'fallback allocation) and reused after; a 2 x 2 matrix target', 'replaced by '
                                'a 2 x 3 value, then updated in place'], body, o)


def fuse_group_shared():
    x = [1.0, -0.5, 2.25, 1e16, 3.0]
    p = [4.0, 0.25, -7.5, 1.0, 1e-3]
    body = PV + '''let x: f64[] = %s
var p: f64[] = %s
let keep = p
var p2 = p
p = p * 3.0 + x
let s = p - keep
pv(p)
pv(keep)
pv(p2)
pv(s)
p2 = p2 - 1.0
pv(p2)
pv(keep)
''' % (vlit(x), vlit(p))
    pn = [pi * 3.0 + xi for pi, xi in zip(p, x)]
    s = [a - b for a, b in zip(pn, p)]
    p2 = [pi - 1.0 for pi in p]
    o = out_v(pn) + out_v(p) + out_v(p) + out_v(s) + out_v(p2) + out_v(p)
    C.prog('fuse_group_shared', ['F2 (6) with a shared buffer (LANGUAGE.md 4.5, DESIGN.md 2.12.4): `p` shares '
                                 'its buffer with `keep` and `p2`', 'before the group `p = p * 3.0 + x; let s '
                                 '= p - keep`: `keep` and `p2` keep the old values, `s` reads both'], body, o)


def fuse_group_ref():
    x = [0.5, -1.0, 2.0, 1e16, 0.125]
    T0 = [1.0, 2.0, -3.0, 4.5, 1e-3]
    M0 = Mat.rows([[1.0, 2.0, 3.0], [-4.0, 0.5, 1e16]])
    rv = [0.25, -1.5, 1e15]
    body = PV + PM + '''fn advance(ref T: f64[], x: f64[], w: f64) -> f64 {
    let g = x * w + 1.0
    T = T * 0.5 + g
    let d = sum(T - g)
    return d
}
fn advancem(ref M: f64[,], r: f64[]) {
    let h = M * 2.0
    M = h - r.row
}
var T: f64[] = %s
let keep = T
let x: f64[] = %s
let d1 = advance(ref T, x, 0.25)
pv(T)
pv(keep)
let d2 = advance(ref T, x, -3.0)
pv(T)
printf("%%.17g %%.17g\\n", d1, d2)
var M: f64[,] = %s
let keepM = M
advancem(ref M, %s)
pm(M)
pm(keepM)
''' % (vlit(T0), vlit(x), mlit(M0), vlit(rv))

    def step(T, w):
        g = [xi * w + 1.0 for xi in x]
        T = [ti * 0.5 + gi for ti, gi in zip(T, g)]
        return T, sum8([ti - gi for ti, gi in zip(T, g)])
    T1, d1 = step(T0, 0.25)
    T2, d2 = step(T1, -3.0)
    M1 = ew(lambda mv, r: mv * 2.0 - r, M0, row(rv))
    o = out_v(T1) + out_v(T0) + out_v(T2) + g17(d1) + ' ' + g17(d2) + '\n' + out_m(M1) + out_m(M0)
    C.prog('fuse_group_ref', ['F2 with `ref` array parameter targets (LANGUAGE.md 8.3, DESIGN.md 2.12.4 F2 (1), '
                              '(6)): `T = T * 0.5 + g` after', '`let g` and before `sum(T - g)`, called '
                              'twice; a matrix `M = h - r.row`; the caller\'s other copies keep the old',
                              'values'], body, o)


def fuse_group_fixed():
    q = [1.5, -2.0, 1e16, 0.25]
    f = [3.0, 0.5, -1.0, 8.0]
    Q = Mat.rows([[1.0, 2.0], [3.0, 4.0]])
    FF = Mat.rows([[0.5, -1.0], [2.0, 1e-3]])
    body = PV + PM + '''var q: f64[4] = %s
let f: f64[4] = %s
let a = q * f + 0.5
q = a * a - q
let r = q + f * 1e-16
pv(q)
pv(r)
var Q: f64[2,2] = %s
let FF = %s
Q = Q * FF - 1.0
let R = Q * Q + FF
pm(Q)
pm(R)
''' % (vlit(q), vlit(f), mlit(Q), mlit(FF))
    a = [qi * fi + 0.5 for qi, fi in zip(q, f)]
    qn = [ai * ai - qi for ai, qi in zip(a, q)]
    r = [qi + fi * 1e-16 for qi, fi in zip(qn, f)]
    Qn = ew(lambda a1, b1: a1 * b1 - 1.0, Q, FF)
    R = ew(lambda a1, b1: a1 * a1 + b1, Qn, FF)
    C.prog('fuse_group_fixed', ['F2 with fixed-size operands and targets (LANGUAGE.md 4.5, DESIGN.md 2.12.4 F2 '
                                '(2), (6)): `q: f64[4]` and', '`Q: f64[2,2]` written in place by groups whose '
                                'roots all have one static shape (no space test, no split copy)'],
           body, out_v(qn) + out_v(r) + out_m(Qn) + out_m(R))


def fuse_group_split_vec():
    x = [0.1, 0.2, 0.3]
    y = [1.0, 1e16, -2.5, 3.0]
    body = PV + '''let x: f64[] = %s
let y: f64[] = %s
let a = x * 2.0
let b = y * 3.0
let c = a * a + 0.1
pv(a)
pv(b)
pv(c)
''' % (vlit(x), vlit(y))
    a = [xi * 2.0 for xi in x]
    b = [yi * 3.0 for yi in y]
    c = [ai * ai + 0.1 for ai in a]
    C.prog('fuse_group_split_vec', ['F2 (2) the split copy (DESIGN.md 2.12.4, L-eq): `let a = x * 2.0; let b = '
                                    'y * 3.0` with lengths 3 and 4', 'and `let c = a * a + 0.1`: no error, '
                                    'each statement over its own space'], body, out_v(a) + out_v(b) + out_v(c))


def fuse_group_split_bcast():
    R = [0.5, -1.25, 1e16]
    M = Mat.rows([[1.0, 2.0, 3.0], [-0.5, 1e-3, 7.75]])
    body = PM + '''var R = zeros(1, 3)
let rv = %s
for j in 0..3 {
    R[0, j] = rv[j]
}
let M: f64[,] = %s
let a = R * 2.0 + 0.5
let b = R - M * 0.25
let c = b * b
pm(a)
pm(b)
pm(c)
''' % (vlit(R), mlit(M))
    Rm = row(R)
    a = ew(lambda r: r * 2.0 + 0.5, Rm)
    b = ew(lambda r, mv: r - mv * 0.25, Rm, M)
    c = ew(lambda bb: bb * bb, b)
    C.prog('fuse_group_split_bcast', ['F2 (2) the split copy (DESIGN.md 2.12.4, L-eq): a group over a 1 x 3 '
                                      'operand (`a`, space 1 x 3) and', 'the same operand broadcast against a '
                                      '2 x 3 matrix (`b`, `c`, space 2 x 3): no error, each statement over',
                                      'its own space'], body, out_m(a) + out_m(b) + out_m(c))


# ============================================================================ W1 and W4 in miniature
def fuse_w1_bisect():
    ka, Sut, Sy, aP, Kt = 0.82, 620e6, 530e6, 0.00025, 1.9
    nT = 2.2
    body = PM + '''struct Params {
    ka: f64
    Sut: f64
    Sy: f64
    a: f64
    Kt: f64
}
elemental fn safety(d: f64, Mx: f64, T: f64, p: Params) -> (f64, f64, f64) {
    let dmm = d * 1e3
    let kb = if dmm > 2.79 && dmm <= 51 { 1.24 * dmm ^ -0.107 }
             else if dmm > 51 { 1.51 * min(dmm, 254) ^ -0.157 }
             else { 1.0 }
    let Se = p.ka * kb * p.Sut * 0.5
    let q = 1 / (1 + p.a / d)
    let Kf = 1 + q * (p.Kt - 1)
    let c32 = 32 / (pi * d ^ 3)
    let sb = c32 * Kf * Mx
    let nf = Se / sb
    let st = 16 / (pi * d ^ 3) * T
    let ny = p.Sy / sqrt(sb ^ 2 + 3 * st ^ 2)
    return (nf, ny, Kf)
}
let pr = Params { ka: 0.82, Sut: 620e6, Sy: 530e6, a: 0.00025, Kt: 1.9 }
let nT = 2.2
var MG = zeros(3, 4)
var TG = zeros(3, 4)
for j in 0..4 {
    for i in 0..3 {
        MG[i, j] = 120.0 + f64(i * 4 + j) * 23.5
        TG[i, j] = 60.0 + f64(j * 3 + i) * 11.25
    }
}
var lo = filled(0.005, 3, 4)
var hi = filled(0.2, 3, 4)
for it in 0..40 {
    let mid = 0.5 * (lo + hi)
    let (nfv, nyv, _) = safety(mid, MG, TG, pr)
    let up = min(nfv, nyv) < nT
    lo = where(up, mid, lo)
    hi = where(up, hi, mid)
}
pm(lo)
pm(hi)
let (nf, _, Kf) = safety(lo, MG, TG, pr)
pm(nf)
pm(Kf)
'''

    def safety(d, Mx, T):
        dmm = d * 1e3
        if dmm > 2.79 and dmm <= 51.0:
            kb = 1.24 * MM.sea_pow(dmm, -0.107)
        elif dmm > 51.0:
            kb = 1.51 * MM.sea_pow(fmin(dmm, 254.0), -0.157)
        else:
            kb = 1.0
        Se = ((ka * kb) * Sut) * 0.5
        q = 1.0 / (1.0 + aP / d)
        Kf = 1.0 + q * (Kt - 1.0)
        c32 = 32.0 / pi_d3(d)
        sb = (c32 * Kf) * Mx
        nf = Se / sb
        st = (16.0 / pi_d3(d)) * T
        ny = Sy / math.sqrt(sb * sb + 3.0 * (st * st))
        return nf, ny, Kf
    MG = Mat.fn(3, 4, lambda i, j: 120.0 + float(i * 4 + j) * 23.5)
    TG = Mat.fn(3, 4, lambda i, j: 60.0 + float(j * 3 + i) * 11.25)
    lo = Mat(3, 4, [0.005] * 12)
    hi = Mat(3, 4, [0.2] * 12)
    for it in range(40):
        mid = ew(lambda a, b: 0.5 * (a + b), lo, hi)
        res = ew(lambda d, mx, t: safety(d, mx, t), mid, MG, TG)
        up = ew(lambda r: fmin(r[0], r[1]) < nT, res)
        lo = ew(lambda u, md, l1: md if u else l1, up, mid, lo)
        hi = ew(lambda u, h1, md: h1 if u else md, up, hi, mid)
    res = ew(lambda d, mx, t: safety(d, mx, t), lo, MG, TG)
    nf = ew(lambda r: r[0], res)
    Kf = ew(lambda r: r[2], res)
    # the bisection is meaningful: some grid points settle strictly inside (0.005, 0.2)
    assert all(0.005 < v < 0.2 for v in lo.d)
    o = out_m(lo) + out_m(hi) + out_m(nf) + out_m(Kf)
    C.prog('fuse_w1_bisect', ['W1\'s grid bisection in miniature (LANGUAGE.md 2.1; DESIGN.md 2.12.4 "Example"): '
                              'a three-result elemental', 'function with `if` expressions, `min`, `sqrt`, '
                              '`^ -0.107` (pow) and `^ 3` over a 3 x 4 grid, results discarded, `where`',
                              'into reused targets, 40 iterations; the final bounds and two results printed'],
           body, o)


def fuse_w4_rb():
    body = PM + '''fn rb_half_sweep(ref T: f64[,], src: f64[,], colorIn: bool[,], omega: f64) -> f64 {
    let ny = rows(T)
    let Tp = [T[1..ny-1, 1..2], T[1..ny-1, :], T[1..ny-1, $-2..$-1]]
    let Tc = T[1..ny-1, :]
    let tgs = (Tp[:, 0..$-2] + Tp[:, 2..$] + T[0..ny-2, :] + T[2..ny, :] + src[1..ny-1, :]) / 4
    let Tn = Tc + omega * (tgs - Tc)
    let dMax = max(abs(Tn[colorIn] - Tc[colorIn]))
    T[1..ny-1, :] = where(colorIn, Tn, Tc)
    return dMax
}
var T = zeros(6, 5)
var src = zeros(6, 5)
for j in 0..5 {
    T[0, j] = 100.0
    T[5, j] = 20.0 + 3.0 * f64(j)
    for i in 1..5 {
        T[i, j] = f64(i * 7 + j * 3) * 0.5
    }
    for i in 0..6 {
        src[i, j] = 0.25 * f64((i + 2 * j) % 5) - 0.3
    }
}
var redIn = filled(false, 4, 5)
for j in 0..5 {
    for i in 0..4 {
        redIn[i, j] = (i + 1 + j) % 2 == 0
    }
}
let blackIn = !redIn
for it in 0..3 {
    let d1 = rb_half_sweep(ref T, src, redIn, 1.6)
    let d2 = rb_half_sweep(ref T, src, blackIn, 1.6)
    printf("%d %.17g %.17g\\n", it, d1, d2)
}
pm(T)
'''
    T = [[0.0] * 5 for _ in range(6)]
    src = [[0.0] * 5 for _ in range(6)]
    for j in range(5):
        T[0][j] = 100.0
        T[5][j] = 20.0 + 3.0 * float(j)
        for i in range(1, 5):
            T[i][j] = float(i * 7 + j * 3) * 0.5
        for i in range(6):
            src[i][j] = 0.25 * float((i + 2 * j) % 5) - 0.3
    red = [[(i + 1 + j) % 2 == 0 for j in range(5)] for i in range(4)]
    black = [[not b for b in rr] for rr in red]

    def sweep(T, color, omega):
        ny = 6
        Tp = [[T[i + 1][1]] + [T[i + 1][j] for j in range(5)] + [T[i + 1][3]] for i in range(ny - 2)]
        Tc = [[T[i + 1][j] for j in range(5)] for i in range(ny - 2)]
        tgs = [[((((Tp[i][j] + Tp[i][j + 2]) + T[i][j]) + T[i + 2][j]) + src[i + 1][j]) / 4.0
                for j in range(5)] for i in range(ny - 2)]
        Tn = [[Tc[i][j] + omega * (tgs[i][j] - Tc[i][j]) for j in range(5)] for i in range(ny - 2)]
        sel = [fabs(Tn[i][j] - Tc[i][j]) for j in range(5) for i in range(ny - 2) if color[i][j]]
        d = rmax(sel)[0]
        T2 = [list(rr) for rr in T]
        for i in range(ny - 2):
            for j in range(5):
                T2[i + 1][j] = Tn[i][j] if color[i][j] else Tc[i][j]
        return T2, d
    o = ''
    for it in range(3):
        T, d1 = sweep(T, red, 1.6)
        T, d2 = sweep(T, black, 1.6)
        o += '%d %s %s\n' % (it, g17(d1), g17(d2))
    o += out_m(Mat.rows(T))
    C.prog('fuse_w4_rb', ['W4\'s red-black half sweep in miniature (LANGUAGE.md 2.4, verbatim `rb_half_sweep`): '
                          'a 6 x 5 plate, a', 'concatenation of slices, shifted slices, `max` of a same-mask '
                          'selection tree and a `where` into a', '`ref` parameter\'s selection; three red '
                          'and black sweeps, dMax and the plate printed'], body, o)


# ============================================================================ reductions
def _pick(seed, pal, n):
    s = seed
    out = []
    for _ in range(n):
        s = (s * 1103515245 + 12345) % (1 << 31)
        out.append(pal[(s >> 8) % len(pal)])
    return out


def fuse_red_sum_lanes():
    pal_v = [1e16, -1e16, 0.5, 1.0, 1.5, 3.0, 2.5e15, -7.25, 1e-3, -2.0e16]
    pal_w = [0.0, 0.25, 1.0, -0.5, 0.125]
    decl = []
    prn = []
    o = ''
    for k in (1, 7, 8, 9, 15, 16, 17):
        n = k + (k + 1) // 2 + 1             # the whole vector: k selected, the rest interleaved
        seed = 0
        while True:
            seed += 1
            xs = _pick(seed, pal_v, k)
            ys = _pick(seed + 7919, pal_w, k)
            vs = _pick(seed + 104729, pal_v, n)
            ws = _pick(seed + 1299709, pal_w, n)
            # mask: unselected at 0 and after every second selected element, until k are selected
            ms = [False] * n
            cnt, pos = 0, 1
            while cnt < k:
                ms[pos] = True
                cnt += 1
                pos += 2 if cnt % 2 == 0 else 1
            assert sum(ms) == k
            t = [x * 2.0 - y for x, y in zip(xs, ys)]
            tm = [v * 2.0 - w for v, w, mm in zip(vs, ws, ms) if mm]
            if k >= 9 and sum8(t) == sum_seq(t):
                continue
            if k >= 7:
                lk = [-0.0] * 8
                for idx, (v, w, mm) in enumerate(zip(vs, ws, ms)):
                    if mm:
                        lk[idx % 8] = lk[idx % 8] + (v * 2.0 - w)
                bykp = ((lk[0] + lk[1]) + (lk[2] + lk[3])) + ((lk[4] + lk[5]) + (lk[6] + lk[7]))
                if sum8(tm) == bykp:
                    continue
                if k >= 9 and sum8(tm) == sum_seq(tm):
                    continue
            break
        dyn = k % 2 == 1
        ann = ': f64[]' if dyn else ''
        decl.append('let x%d%s = %s' % (k, ann, vlit(xs)))
        decl.append('let y%d%s = %s' % (k, ann, vlit(ys)))
        decl.append('let v%d%s = %s' % (k, ann, vlit(vs)))
        decl.append('let w%d = %s' % (k, vlit(ws)))
        decl.append('let m%d = %s' % (k, bvlit(ms)))
        prn.append('printf("%%d %%.17g %%.17g\\n", %d, sum(x%d * 2.0 - y%d), sum(v%d[m%d] * 2.0 - w%d[m%d]))'
                   % (k, k, k, k, k, k, k))
        o += '%d %s %s\n' % (k, g17(sum8(t)), g17(sum8(tm)))
    body = '\n'.join(decl + prn) + '\n'
    C.prog('fuse_red_sum_lanes', ['F3 `sum` (LANGUAGE.md 10.5, DESIGN.md 2.12.4 F3, L-et): the pinned 8 lanes '
                                  'over a tree of k = 1, 7, 8, 9,', '15, 16, 17 elements and over a same-mask '
                                  'selection tree with k selected elements interleaved with unselected',
                                  'ones; the data make the 8-lane result differ from left-to-right summation '
                                  'and, for the selection,', 'from lanes counted by the position in the whole '
                                  'vector'], body, o)


def fuse_red_max_special():
    a1 = [INF, 1.5, 3.0, -0.5, 0.0, 2.5, 1.0, -0.5]
    b1 = [-INF, 0.0, 1.0, 0.0, NAN, 2.0, 0.0, 0.0]
    a2 = [-0.0, 0.0, -2.0, -0.0]
    b2 = [-0.0, -0.0, -1.0, -0.0]
    a3 = [0.0, -0.0, 0.0]
    b3 = [0.0, -0.0, -0.0]
    a4 = [NAN, INF]
    b4 = [1.0, -INF]
    m1 = [True, True, False, True, True, True, True, True]
    Am = Mat(2, 4, a1)
    Bm = Mat(2, 4, b1)
    body = '''let a1: f64[] = %s
let b1: f64[] = %s
let a2 = %s
let b2 = %s
let a3: f64[] = %s
let b3: f64[] = %s
let a4 = %s
let b4 = %s
let m1 = %s
let Am: f64[,] = %s
let Bm = %s
printf("t1 %%.17g %%d %%.17g %%d\\n", max(a1 * 2.0 + b1), argmax(a1 * 2.0 + b1), min(a1 * 2.0 + b1), argmin(a1 * 2.0 + b1))
printf("t2 %%.17g %%d %%.17g %%d\\n", max(a2 * 2.0 + b2), argmax(a2 * 2.0 + b2), min(a2 * 2.0 + b2), argmin(a2 * 2.0 + b2))
printf("t3 %%.17g %%d %%.17g %%d\\n", max(a3 * 2.0 + b3), argmax(a3 * 2.0 + b3), min(a3 * 2.0 + b3), argmin(a3 * 2.0 + b3))
printf("t4 %%.17g %%d %%.17g %%d\\n", max(a4 * 2.0 + b4), argmax(a4 * 2.0 + b4), min(a4 * 2.0 + b4), argmin(a4 * 2.0 + b4))
printf("flat %%.17g %%d %%.17g %%d\\n", max((Am * 2.0 + Bm).flat), argmax((Am * 2.0 + Bm).flat), min((Am * 2.0 + Bm).flat), argmin((Am * 2.0 + Bm).flat))
printf("mask %%.17g %%d %%.17g %%d\\n", max(a1[m1] * 2.0 + b1[m1]), argmax(a1[m1] * 2.0 + b1[m1]), min(a1[m1] * 2.0 + b1[m1]), argmin(a1[m1] * 2.0 + b1[m1]))
''' % (vlit(a1), vlit(b1), vlit(a2), vlit(b2), vlit(a3), vlit(b3), vlit(a4), vlit(b4), bvlit(m1),
       mlit(Am), mlit(Bm))
    o = ''
    cases = [('t1', [x * 2.0 + y for x, y in zip(a1, b1)]),
             ('t2', [x * 2.0 + y for x, y in zip(a2, b2)]),
             ('t3', [x * 2.0 + y for x, y in zip(a3, b3)]),
             ('t4', [x * 2.0 + y for x, y in zip(a4, b4)]),
             ('flat', [x * 2.0 + y for x, y in zip(Am.flat(), Bm.flat())]),
             ('mask', [x * 2.0 + y for x, y, mm in zip(a1, b1, m1) if mm])]
    for name, t in cases:
        mx, ix = rmax(t)
        mn, jn = rmax(t, False)
        o += '%s %s %d %s %d\n' % (name, g17(mx), ix, g17(mn), jn)
    # the cases the bullet names: ties (first wins), NaN ignored, -0 before +0 (and +0 before -0), all NaN
    assert o.split('\n')[0] == 't1 7 2 -1 3' and o.split('\n')[1] == 't2 -0 0 -5 2'
    assert o.split('\n')[2] == 't3 0 0 0 0' and o.split('\n')[3] == 't4 NaN 0 NaN 0'
    assert o.split('\n')[5] == 'mask 7 4 -1 2'
    C.prog('fuse_red_max_special', ['F3 `max min argmax argmin` over trees whose values hold ties, NaN and '
                                    'signed zeros (LANGUAGE.md 10.5:', 'the first extreme in index order, NaN '
                                    'ignored, all NaN gives NaN and 0; -0 and +0 compare equal), over a',
                                    '`.flat` matrix tree and over a same-mask selection (the index in the '
                                    'selection)'], body, o)


def fuse_red_argmax_mask():
    body = '''let v = [9.0, 1.0, 5.0]
let m = [false, true, true]
printf("%d\\n", argmax(v[m]))
let w = [0.0, 4.0, 0.5]
printf("%d %d %.17g %.17g\\n", argmin(v[m]), argmax(v[m] * 2.0 - w[m]), max(v[m] * 2.0 - w[m]), min(v[m]))
let iv: i64[] = [9, 1, 5]
printf("%d %d %d\\n", argmax(iv[m] * 2 - 1), argmin(iv[m] * 2 - 1), max(iv[m] * 2 - 1))
let A: f64[,] = [9.0, 2.0; 1.0, 8.0]
let B = [0.0, 0.5; 0.25, 0.0]
let M = [false, true; true, true]
printf("%d %.17g\\n", argmax(A[M] + B[M]), max(A[M] + B[M]))
'''
    v = [9.0, 1.0, 5.0]
    m = [False, True, True]
    w = [0.0, 4.0, 0.5]
    sel = [x for x, b in zip(v, m) if b]
    assert rmax(sel)[1] == 1                   # the bullet's value
    t = [x * 2.0 - y for x, y, b in zip(v, w, m) if b]
    o = '%d\n' % rmax(sel)[1]
    o += '%d %d %s %s\n' % (rmax(sel, False)[1], rmax(t)[1], g17(rmax(t)[0]), g17(rmax(sel, False)[0]))
    it = [x * 2 - 1 for x, b in zip([9, 1, 5], m) if b]
    o += '%d %d %d\n' % (imax(it)[1], imax(it, False)[1], imax(it)[0])
    A = Mat.rows([[9.0, 2.0], [1.0, 8.0]])
    B = Mat.rows([[0.0, 0.5], [0.25, 0.0]])
    Mk = Mat.rows([[False, True], [True, True]])
    tm = [a + b for a, b in zip(A.mask(Mk), B.mask(Mk))]
    o += '%d %s\n' % (rmax(tm)[1], g17(rmax(tm)[0]))
    C.prog('fuse_red_argmax_mask', ['F3 over a same-mask selection (DESIGN.md 2.12.4 F3, L-et): `argmax(v[m])` '
                                    'with v = [9, 1, 5],', 'm = [false, true, true] is 1, the position in the '
                                    'selection; argmin, max, min of selection trees, the `i64`', 'forms and a '
                                    'matrix mask (column-major selection order)'], body, o)


def fuse_red_variance():
    x = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
    y = [0.1, 0.7, 0.3, 0.9, 0.2, 0.4, 0.8, 0.6, 0.5, 0.05]
    A = Mat.rows([[1e8, 3e8, 5e8], [2e8, 4e8, 6e8]])
    B = Mat.rows([[0.3, 0.1, 0.4], [0.1, 0.5, 0.9]])
    iv = [7, -3, 12, 5, 0]
    body = '''let x: f64[] = %s
let y: f64[] = %s
let A: f64[,] = %s
let B = %s
let iv = %s
let v = variance(x * 1e9 + y)
let s = std(x * 1e9 + y)
printf("%%.17g %%.17g %%.17g\\n", v, s, mean(x * 1e9 + y))
printf("%%.17g %%.17g\\n", variance((A * 3.0 + B).flat), std((A * 3.0 + B).flat))
printf("%%.17g %%.17g\\n", variance(iv * 3 - 1), std(iv * 3 - 1))
printf("%%.17g %%.17g\\n", variance(x[0..1] * 2.0 + y[0..1]), variance(x[0..0] * 2.0 + y[0..0]))
''' % (vlit(x), vlit(y), mlit(A), mlit(B), ivlit(iv))
    t = [xi * 1e9 + yi for xi, yi in zip(x, y)]
    tf = [a * 3.0 + b for a, b in zip(A.flat(), B.flat())]
    vi = ivariance([chk(chk(k * 3) - 1) for k in iv])
    o = '%s %s %s\n' % (g17(variance(t)), g17(std(t)), g17(mean(t)))
    o += '%s %s\n' % (g17(variance(tf)), g17(std(tf)))
    o += '%s %s\n' % (g17(vi), g17(math.sqrt(vi)))
    o += '%s %s\n' % (g17(variance([x[0] * 2.0 + y[0]])), g17(variance([])))
    C.prog('fuse_red_variance', ['F3 `variance` and `std` of trees (standalone, DESIGN.md 2.12.4 F2 (1), F3): '
                                 'two passes over x * 1e9 + y', '(the mean first, LANGUAGE.md 10.5), of a '
                                 '`.flat` matrix tree, of an `i64` tree, of one element (0) and none (NaN)'],
           body, o)


# ============================================================================ concatenation
def fuse_cat_parts():
    v = [0.5, 1.5, 2.5, 3.5, 4.5, 5.5, 6.5, 7.5]
    B = Mat.rows([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0], [7.0, 8.0, 9.0], [10.0, 11.0, 12.0]])
    body = PV + PM + '''let v: f64[] = %s
var A = zeros(3, 4)
for j in 0..4 {
    for i in 0..3 {
        A[i, j] = f64(10 * i + j) + 0.25
    }
}
let B = %s
let c = [v[1..4], A.flat, 2.5, v[0..$ step 3], B.T.flat, A[1, :], A[:, 2], v[$-1..=0 step -2]]
pv(c)
let Cm = [A[:, 0..2], B.T, B[0..3, 1..3], A[:, 3].col]
pm(Cm)
let D = [A[0..2, :]; v[0..4].row; B.T[1..3, :]]
pm(D)
let e = [v[2..5] * 2.0, 1e16, A.T.flat + 1.0]
pv(e)
''' % (vlit(v), mlit(B))
    A = Mat.fn(3, 4, lambda i, j: float(10 * i + j) + 0.25)
    BT = B.T()
    c = (v[1:4] + A.flat() + [2.5] + v[0::3] + BT.flat() + [A.at(1, j) for j in range(4)]
         + [A.at(i, 2) for i in range(3)] + [v[7], v[5], v[3], v[1]])
    cols = ([[A.at(i, j) for i in range(3)] for j in range(2)] + [[BT.at(i, j) for i in range(3)] for j in range(4)]
            + [[B.at(i, j) for i in range(3)] for j in (1, 2)] + [[A.at(i, 3) for i in range(3)]])
    Cm = Mat(3, len(cols), [x for cc in cols for x in cc])
    rows_ = ([[A.at(i, j) for j in range(4)] for i in range(2)] + [v[0:4]]
             + [[BT.at(i, j) for j in range(4)] for i in (1, 2)])
    D = Mat.rows(rows_)
    e = [x * 2.0 for x in v[2:5]] + [1e16] + [x + 1.0 for x in A.T().flat()]
    C.prog('fuse_cat_parts', ['F4 concatenation parts (DESIGN.md 2.12.4 F4, L-eu; LANGUAGE.md 6.9): range '
                              'selections with steps (also', 'reversed), `.flat` of a matrix and of a '
                              'transpose, a row, a column, a scalar; matrix parts side by side',
                              '(slices, `.T`, `.col`) and stacked (`.row`); trees as parts'],
           body, out_v(c) + out_m(Cm) + out_m(D) + out_v(e))


# ============================================================================ aliasing
def fuse_alias_inplace():
    x = [0.1, 2.5, -3.0, 1e16, 0.7, -0.0]
    A0 = Mat.rows([[1.5, -2.0, 0.25], [3.0, 1e8, -0.5]])
    q = [1.0, 2.0, 3.0]
    body = PV + PM + '''var x: f64[] = %s
x = x + 1.0
pv(x)
x = x * x - x * 0.5
pv(x)
var A: f64[,] = %s
A = A * A + 1.0
pm(A)
var q: f64[3] = %s
q = q + q * 0.5
pv(q)
''' % (vlit(x), mlit(A0), vlit(q))
    x1 = [xi + 1.0 for xi in x]
    x2 = [xi * xi - xi * 0.5 for xi in x1]
    A1 = ew(lambda a: a * a + 1.0, A0)
    q1 = [qi + qi * 0.5 for qi in q]
    C.prog('fuse_alias_inplace', ['F1 (5) in place (DESIGN.md 2.12.4; LANGUAGE.md 5.5): `x = x + 1.0`, `x = x '
                                  '* x - x * 0.5`, a matrix and a', 'fixed-size vector updated from their own '
                                  'elements at the element being written'],
           body, out_v(x1) + out_v(x2) + out_m(A1) + out_v(q1))


def fuse_alias_shift():
    v = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]
    A0 = Mat.rows([[1.0, 2.0, 4.0, 8.0], [-1.0, 0.5, 0.25, 3.0]])
    body = PV + PM + '''var v: f64[] = %s
let n = len(v)
v[1..n] = v[0..n-1] * 2
pv(v)
v[0..n-1] = v[1..n] * 0.5 - v[0..n-1]
pv(v)
var A: f64[,] = %s
let c = cols(A)
A[:, 1..c] = A[:, 0..c-1] + 1.0
pm(A)
''' % (vlit(v), mlit(A0))
    v1 = [v[0]] + [x * 2.0 for x in v[0:5]]
    assert v1 == [1.0, 2.0, 4.0, 6.0, 8.0, 10.0]
    v2 = [v1[i + 1] * 0.5 - v1[i] for i in range(5)] + [v1[5]]
    A1 = Mat.fn(2, 4, lambda i, j: A0.at(i, 0) if j == 0 else A0.at(i, j - 1) + 1.0)
    C.prog('fuse_alias_shift', ['F1 (5) shifted (DESIGN.md 2.12.4; LANGUAGE.md 5.5): `v[1..n] = v[0..n-1] * 2` '
                                'reads every old element (the', 'reference\'s temporary: [1, 2, 4, 6, 8, 10], '
                                'not a running doubling), a backward shift, and a column shift of', 'a matrix'],
           body, out_v(v1) + out_v(v2) + out_m(A1))


def fuse_alias_rows():
    body = PM + '''elemental fn avg(a: f64, b: f64) -> f64 {
    return (a + b) * 0.5
}
var T = zeros(5, 3)
for j in 0..3 {
    for i in 0..5 {
        T[i, j] = f64(i * i * 3 + j) + 0.125
    }
}
let r = rows(T)
T[1..r-1, :] = avg(T[0..r-2, :], T[2..r, :])
pm(T)
T[1..r-1, :] = T[0..r-2, :] * 0.25 + T[1..r-1, :] - T[2..r, :] * 0.5
pm(T)
'''
    T = Mat.fn(5, 3, lambda i, j: float(i * i * 3 + j) + 0.125)
    T1 = Mat.fn(5, 3, lambda i, j: T.at(i, j) if i in (0, 4) else (T.at(i - 1, j) + T.at(i + 1, j)) * 0.5)
    T2 = Mat.fn(5, 3, lambda i, j: T1.at(i, j) if i in (0, 4) else
                (T1.at(i - 1, j) * 0.25 + T1.at(i, j)) - T1.at(i + 1, j) * 0.5)
    C.prog('fuse_alias_rows', ['F1 (5) and F4 (DESIGN.md 2.12.4; LANGUAGE.md 5.5): `T[1..r-1, :] = '
                               'avg(T[0..r-2, :], T[2..r, :])` with an', 'elemental function reads the old rows '
                               '(the reference\'s temporary); then the rows above, at and below'],
           body, out_m(T1) + out_m(T2))


def fuse_alias_index_vec():
    body = PV + '''var v: f64[] = [1.0, 10.0, 100.0]
let w = [0, 0]
v[w] = v[w] * 2.0 + 1.0
pv(v)
let w3 = [1, 2, 1]
v[w3] = v[w3] * 10.0
pv(v)
'''
    v = [1.0, 10.0, 100.0]
    val = [v[0] * 2.0 + 1.0, v[0] * 2.0 + 1.0]
    for i, k in enumerate([0, 0]):
        v[k] = val[i]
    assert v[0] == 3.0                       # the bullet's value
    o = out_v(v)
    val = [v[k] * 10.0 for k in [1, 2, 1]]
    for i, k in enumerate([1, 2, 1]):
        v[k] = val[i]
    o += out_v(v)
    C.prog('fuse_alias_index_vec', ['F1 (5) (i) (DESIGN.md 2.12.4; LANGUAGE.md 5.5): an index-vector target '
                                    'is never written in place:', '`v[w] = v[w] * 2.0 + 1.0` with w = [0, 0] '
                                    'leaves v[0] = 3; `v[w3] = v[w3] * 10.0` with w3 = [1, 2, 1] reads',
                                    'every old element, the last store winning'], body, o)


def fuse_alias_field():
    body = PV + '''struct S {
    v: f64[]
    n: i64
}
var s = S { v: [1.0, 5.0, 9.0, 13.0, 17.0], n: 5 }
var s2 = s
s.v[1..3] = s.v[0..2] + 1.0
pv(s.v)
pv(s2.v)
s.v = s.v * 2.0 - s2.v
pv(s.v)
'''
    v = [1.0, 5.0, 9.0, 13.0, 17.0]
    v1 = [v[0], v[0] + 1.0, v[1] + 1.0, v[3], v[4]]
    v2 = [a * 2.0 - b for a, b in zip(v1, v)]
    C.prog('fuse_alias_field', ['F1 (5) on a root path (DESIGN.md 2.12.4, L-fe): `s.v[1..3] = s.v[0..2] + 1.0` '
                                'on a struct field reads the old', 'elements; the copy `s2` keeps its values; '
                                '`s.v = s.v * 2.0 - s2.v` reads the field at the element written'],
           body, out_v(v1) + out_v(v) + out_v(v2))


def fuse_alias_group_same():
    x = [0.5, -1.0, 3.0, 1e16, 0.25]
    z = [2.0, 0.125, -4.0, 1.0, 1e-3]
    body = PV + '''var x: f64[] = %s
let z: f64[] = %s
x = x * 2.0 + z
let y = x * x - z
let u = y + x
pv(x)
pv(y)
pv(u)
''' % (vlit(x), vlit(z))
    x1 = [xi * 2.0 + zi for xi, zi in zip(x, z)]
    y = [xi * xi - zi for xi, zi in zip(x1, z)]
    u = [yi + xi for yi, xi in zip(y, x1)]
    C.prog('fuse_alias_group_same', ['F2 (3) (DESIGN.md 2.12.4): a group whose later statements read the target '
                                     'of an earlier one at the', 'same element: `y` and `u` see the new `x`'],
           body, out_v(x1) + out_v(y) + out_v(u))


def fuse_alias_group_shift():
    x = [0.5, -1.0, 3.0, 1e16, 0.25, 7.0]
    body = PV + '''var x: f64[] = %s
x = x * 2.0 + 1.0
let y = x[1..6] - x[0..5]
let u = y * 0.5
pv(x)
pv(y)
pv(u)
''' % vlit(x)
    x1 = [xi * 2.0 + 1.0 for xi in x]
    y = [x1[i + 1] - x1[i] for i in range(5)]
    u = [yi * 0.5 for yi in y]
    C.prog('fuse_alias_group_shift', ['F2 (3), L-er (DESIGN.md 2.12.4): a later statement reads the target of an '
                                      'earlier one shifted', '(`x[1..6] - x[0..5]`), so the group ends before '
                                      'it; it reads the new `x` everywhere'],
           body, out_v(x1) + out_v(y) + out_v(u))


# ============================================================================ r_fuse_* errors
def r_fuse():
    E = C.err_r
    E('r_fuse_shape_before_index',
      ['the first failing check in reference order (DESIGN.md 2.12.2 (2)): in `(a + b) * v[99]` the shape check '
       'of a + b', '(lengths 3 and 4) comes before the leaf v[99] is evaluated, so `shape mismatch: 3 vs 4`, not '
       'the index'],
      '''let a = zeros(3) + 1.5
let b = zeros(4) + 2.0
let v = zeros(5)
printf("start %.17g\\n", a[0] + b[3])
let r = (a + b) * v[99]
printf("%.17g\\n", r[0])
''', 'let r = (a + b)', 'shape mismatch: 3 vs 4', out='start 3.5\n')

    E('r_fuse_inner_overflow',
      ['a failing inner node is a barrier (DESIGN.md 2.12.4 F1 (2)): in `(i + j) + k` the loop of i + j overflows at '
       'element 3', 'before k (length 4 against 5) is checked: `integer overflow`'],
      '''var i = filled(0, 5)
var j = filled(0, 5)
i[3] = 4611686018427387904
j[3] = 4611686018427387904
let k = filled(1, 4)
printf("start %d\\n", i[3] - j[3] + len(k))
let r = (i + j) + k
printf("%d\\n", r[0])
''', 'let r = (i + j) + k', 'integer overflow', out='start 4\n')

    E('r_fuse_empty_bcast_overflow',
      ['a failing node below an empty broadcast space (DESIGN.md 2.12.4 F1 (2)): `f64(a * 2) + z` with a an '
       'i64[1,3] whose', 'first element overflows and z an f64[0,1] (result 0 x 3): the loop of a * 2 runs over '
       'its own 3 elements first'],
      '''let a = [4611686018427387904, 1, 2].row
let z = zeros(0, 1)
printf("start %d %d\\n", rows(z), cols(a))
let r = f64(a * 2) + z
printf("%d\\n", rows(r))
''', 'let r = f64(a * 2) + z', 'integer overflow', out='start 0 3\n')

    E('r_fuse_root_before_sel',
      ['a failing root before a selection store (DESIGN.md 2.12.4 F1 (2), L-en; LANGUAGE.md 5.5: the right side '
       'first):', '`v[0..5] = f64(a + 1) * 2.0` with v of length 3 and a + 1 overflowing at element 0: '
       '`integer overflow`, not the index'],
      '''var v = zeros(3)
var a = filled(1, 5)
a[0] = 9223372036854775807
printf("start %.17g\\n", v[2])
v[0..5] = f64(a + 1) * 2.0
printf("%.17g\\n", v[0])
''', 'v[0..5] = ', 'integer overflow', out='start 0\n')

    E('r_fuse_abs_min',
      ['`abs` of the i64 -2^63 inside a tree (LANGUAGE.md 10.4: `integer overflow`; DESIGN.md 2.12.2 "failing"): '
       'its loop', 'runs before the shape check of the `+` (3 against 4) that follows it in reference order'],
      '''let a: i64[] = [5, -9223372036854775807 - 1, 7]
let x = zeros(4)
printf("start %d\\n", a[0])
let r = f64(abs(a)) * 0.5 + x
printf("%.17g\\n", r[0])
''', 'let r = f64(abs(a))', 'integer overflow', out='start 5\n')

    E('r_fuse_group_isum',
      ['an `i64` `sum` overflowing in a group (DESIGN.md 2.12.4 F2 (4), F3; LANGUAGE.md 10.5: every partial sum '
       'checked):', 'where(m, a, c) = [2^62, 2^62, 3, 3] overflows at its second element, before the next '
       'statement\'s shape mismatch'],
      '''let a: i64[] = [4611686018427387904, 4611686018427387904, -4611686018427387904, 3]
let c: i64[] = [1, 2, 3, 4]
let m = [true, true, false, true]
let x = zeros(3)
let y = zeros(2)
printf("start %d\\n", c[3])
let s = sum(where(m, a, c))
let d = x * 2.0 + y
printf("%d %.17g\\n", s, d[0])
''', 'let s = sum(', 'integer overflow', out='start 4\n')

    E('r_fuse_two_failing',
      ['two failing nodes (DESIGN.md 2.12.2 (2), F1 (2)): `idiv(a, b) + idiv(c, d)`; the first loop overflows at '
       'element 1', '(idiv(-2^63, -1)) before the second divides by zero at element 0: `integer overflow` at the '
       'first call\'s line'],
      '''let a: i64[] = [7, -9223372036854775807 - 1, 3]
let b: i64[] = [2, -1, 1]
let c: i64[] = [1, 2, 3]
let d: i64[] = [0, 1, 1]
printf("start %d\\n", a[0] + d[0])
let r = (idiv(a, b)
    + idiv(c, d))
printf("%d\\n", r[0])
''', 'let r = (idiv(a, b)', 'integer overflow', out='start 7\n')

    E('r_fuse_elem_error_group',
      ['an elemental function calling `error` at element 5 of a group (DESIGN.md 2.12.4 F2 (4); LANGUAGE.md 8.5: '
       'the first', 'failing element in linear order): reported before the next statement\'s shape mismatch, at '
       'the `error` call\'s line'],
      '''elemental fn chk(x: f64) -> f64 {
    if x > 4.5 {
        error("bad element %g", x)
    }
    return x * 2.0
}
var v = zeros(9)
for i in 0..9 {
    v[i] = f64(i)
}
let p = zeros(3)
let q = zeros(4)
printf("start %g\\n", v[8])
let a = chk(v)
let b = p + q
printf("%g %g\\n", a[0], b[0])
''', 'error("bad element', 'bad element 5', out='start 8\n')

    E('r_fuse_group_printf',
      ['a statement with an effect ends a group (DESIGN.md 2.12.2 (3), F2 (1)): the `printf` between `let a` and '
       '`let b`', 'writes its line before `let b`\'s shape mismatch (3 against 2) is reported'],
      '''let x: f64[] = [1.0, 2.0, 3.0]
let y: f64[] = [1.0, 2.0]
let a = x * 2.0 + 0.5
printf("a1 %.17g\\n", a[1])
let b = a + y
printf("%.17g\\n", b[0])
''', 'let b = a + y', 'shape mismatch: 3 vs 2', out='a1 4.5\n')

    E('r_fuse_mask_empty_max',
      ['`max` of an empty same-mask selection inside a group (DESIGN.md 2.12.4 F3: EMPTY_REDUCE where L13 checks '
       'it;', 'LANGUAGE.md 10.5): `max of an empty array` before the next statement\'s shape mismatch'],
      '''let Tc: f64[] = [1.0, 2.0, 3.0]
let m = [false, false, false]
let y: f64[] = [1.0, 2.0]
printf("start %d\\n", len(Tc))
let Tn = Tc * 2.0 + 1.0
let d = max(abs(Tn[m] - Tc[m]))
let e = Tn + y
printf("%.17g %.17g\\n", d, e[0])
''', 'let d = max(', 'max of an empty array', out='start 3\n')

    E('r_fuse_sel_bad_index',
      ['a selection store with a bad index after a fused value (LANGUAGE.md 5.4, 5.5: the value first, then the '
       'index', 'checks; nothing stored): v[2..6] on a length-4 v names its last position 5'],
      PV + '''var v: f64[] = [1.0, 2.0, 3.0, 4.0]
let a: f64[] = [0.5, 1.5, 2.5, 3.5]
let b: f64[] = [1.0, 1.0, 1.0, 1.0]
pv(v)
v[2..6] = a * 2.0 + b
pv(v)
''', 'v[2..6] = ', 'index 5 out of bounds for dimension 0 of extent 4', out='4: 1 2 3 4\n')


# ============================================================================ main
PROGRAMS = [fuse_f1_tree, fuse_f2_group, fuse_f3_reduce, fuse_f4_views, fuse_f5_elemental,
            fuse_group_locals, fuse_group_reuse, fuse_group_shared, fuse_group_ref, fuse_group_fixed,
            fuse_group_split_vec, fuse_group_split_bcast, fuse_w1_bisect, fuse_w4_rb,
            fuse_red_sum_lanes, fuse_red_max_special, fuse_red_argmax_mask, fuse_red_variance,
            fuse_cat_parts, fuse_alias_inplace, fuse_alias_shift, fuse_alias_rows, fuse_alias_index_vec,
            fuse_alias_field, fuse_alias_group_same, fuse_alias_group_shift]


def main():
    args = sys.argv[1:]
    if len(args) != 2 or args[0] != '--out':
        sys.exit('usage: fuse7c_programs.py --out DIR')
    out = os.path.abspath(args[1])
    tests = os.path.abspath(os.path.join(HERE, '..'))
    if out == tests or out.startswith(tests + os.sep):
        sys.exit('fuse7c_programs.py: write into a scratch directory, not the repo tree')
    C.PROGRAMS = os.path.join(out, 'programs')
    C.ERRORS = os.path.join(out, 'errors')
    os.makedirs(C.PROGRAMS, exist_ok=True)
    os.makedirs(C.ERRORS, exist_ok=True)
    for f in PROGRAMS:
        f()
    r_fuse()
    print('fuse7c_programs: %d programs, %d errors written into %s' % (C.COUNT['programs'], C.COUNT['errors'], out))


if __name__ == '__main__':
    main()
