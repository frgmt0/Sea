"""Sub-phase 6c, T1: the elemental-function tests of DESIGN.md 6.2 ("Phase-6 tests", "6c, elemental functions").

Run with `timeout 120 uv run --no-project python tests/vectors/elem6_cases.py`. It writes

  programs/elem_*          elemental functions (LANGUAGE.md 8.5, 6.3, 7.3): scalar calls, vectors, matrices,
                           broadcasting, fixed-size and mixed arguments, i64 arrays to f64 parameters, uniform
                           str/struct/array parameters, one and five results, results bound to `_`, tuple
                           assignment into selections, call statements, nesting, recursion through ordinary
                           functions, named and default arguments, empty arrays, no result (Decision 92)
  programs/ind2sub_arr_*   ind2sub with an array first argument (LANGUAGE.md 10.7; DESIGN.md 2.11.4, L-cl)
  errors/r_elem6_*         run-time errors: the first failing element in increasing linear order with the callee's
                           line, a shape mismatch at the call's line, and the order of the checks (L19)
  errors/err_elem6_*       compile errors 228, 232, 253, 202, 217, 201, each alone and, for the `_after` tests,
                           against an earlier error of the other program of pass 2a (DESIGN.md 2.6.2 "Order across
                           the two programs", L-cq)
  errors/err_merge_same_pos  re-derived (DESIGN.md 6.2 "Existing tests that phase 6 changes")
  and deletes the retired err_ns_elemental and err_ns_ind2sub_array.

Every expected byte is derived from LANGUAGE.md and DESIGN.md, never from a run of the compiler:

* the values come from a Python mirror of each program, written beside the program: exact integers for `i64`,
  IEEE binary64 for `f64` (every operation of the programs is one IEEE operation, so the mirror and the
  compiled program agree bit for bit, LANGUAGE.md 6.8); every printed `f64` goes through the exact printf oracle
  of tests/vectors/progfmt.py (LANGUAGE.md 11.1), never through Python's `%`;
* the mirror's broadcasting is LANGUAGE.md 6.3 (per dimension equal or one of them 1; a vector with a vector
  requires equal lengths), applied to the elemental arguments only; results come out in column-major order;
* error positions come from DESIGN.md 2.6.2 (the `at` column) and 3.3: a call at its callee name, an argument at
  its first token, a `ref` parameter's `param` node at its `ref` keyword, an `fn` item at its first token (an
  `elemental fn` at `elemental`), a `param` without `ref` at its name; run-time lines are the line of the failing
  `error` call or expression inside the callee (an elemental function inlined into the loop that applies it
  keeps its own sites, DESIGN.md 3.6.4 "Sites"), except a shape check and an argument expression, which are
  the call's line;
* the line or column of every error is computed from a marker in the source text.

Implementer readings (flagged in the T1 report): a record has no type syntax (LANGUAGE.md 4.6, 4.10: every
parameter type is written), so no parameter can be a record; `elem_uniform` covers the "record" case with a
struct that holds `str`, array and scalar fields (W1's `Params` shape), the one thing a record literal is for.
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import call6_cases as C  # noqa: E402  (the helpers of 6b: prog, err_c, err_r, source, remove, gg, gf, wbytes)

PROGRAMS = C.PROGRAMS
ERRORS = C.ERRORS
gg = C.gg
gf = C.gf
COUNT = C.COUNT


# ---------------------------------------------------------------------------- shared Sea helpers
PV = r'''fn pv(v: f64[]) {
    printf("%d:", len(v))
    for x in v {
        printf(" %g", x)
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
PVB = r'''fn pvb(v: bool[]) {
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
            printf(" %g", A[i, j])
        }
    }
    printf("\n")
}
'''
PMI = r'''fn pmi(A: i64[,]) {
    printf("%dx%d", rows(A), cols(A))
    for i in 0..rows(A) {
        printf(" |")
        for j in 0..cols(A) {
            printf(" %d", A[i, j])
        }
    }
    printf("\n")
}
'''
RAMP = r'''fn ramp(n: i64) -> f64[] {
    var v = zeros(n)
    for i in 0..n {
        v[i] = f64(i) * 0.5
    }
    return v
}
'''
GRID = r'''fn lattice(r: i64, c: i64) -> f64[,] {
    var A = zeros(r, c)
    for j in 0..c {
        for i in 0..r {
            A[i, j] = f64(i * 10 + j)
        }
    }
    return A
}
'''
SQ = r'''elemental fn sq(x: f64) -> f64 {
    return x * x
}
'''
F2 = r'''elemental fn f2(x: f64, y: f64) -> f64 {
    return x * 10.0 + y
}
'''
AXPY = r'''elemental fn axpy(a: f64, x: f64, y: f64) -> f64 {
    return a * x + y
}
'''
POSITIVE = r'''elemental fn positive(x: f64) -> bool {
    return x > 0.0
}
'''


# ---------------------------------------------------------------------------- the Python mirror
class Mat:
    """A matrix, column-major: element (i, j) is d[i + j * r]."""

    def __init__(self, r, c, d):
        assert len(d) == r * c
        self.r, self.c, self.d = r, c, list(d)

    def at(self, i, j):
        return self.d[i + j * self.r]

    def t(self):
        return Mat(self.c, self.r, [self.at(i, j) for i in range(self.r) for j in range(self.c)])


def ramp(n):
    return [float(i) * 0.5 for i in range(n)]


def lattice(r, c):
    return Mat(r, c, [float(i * 10 + j) for j in range(c) for i in range(r)])


def col(v):
    return Mat(len(v), 1, v)


def row(v):
    return Mat(1, len(v), v)


def shape_of(x):
    if isinstance(x, Mat):
        return ('m', x.r, x.c)
    if isinstance(x, list):
        return ('v', len(x))
    return None


def combine(shapes):
    """LANGUAGE.md 6.3: the shapes of the array arguments, left to right."""
    cur = None
    for s in shapes:
        if s is None:
            continue
        if cur is None:
            cur = s
            continue
        assert cur[0] == s[0], 'a vector with a matrix is an error'
        if s[0] == 'v':
            assert cur[1] == s[1]
        else:
            dims = []
            for a, b in ((cur[1], s[1]), (cur[2], s[2])):
                if a == b:
                    dims.append(a)
                else:
                    assert a == 1 or b == 1, 'shape mismatch'
                    dims.append(b if a == 1 else a)
            cur = ('m', dims[0], dims[1])
    return cur


def apply(f, *args):
    """Apply the scalar function f element by element over the broadcast shape of args.
    Returns (shape, results): results is a list of result tuples in column-major (linear) order."""
    shp = combine([shape_of(a) for a in args])
    if shp is None:
        r = f(*args)
        return None, [r if isinstance(r, tuple) else (r,)]
    out = []
    if shp[0] == 'v':
        for p in range(shp[1]):
            vals = [a[p] if isinstance(a, list) else a for a in args]
            r = f(*vals)
            out.append(r if isinstance(r, tuple) else (r,))
    else:
        for j in range(shp[2]):
            for i in range(shp[1]):
                vals = []
                for a in args:
                    if isinstance(a, Mat):
                        vals.append(a.at(i if a.r != 1 else 0, j if a.c != 1 else 0))
                    else:
                        vals.append(a)
                r = f(*vals)
                out.append(r if isinstance(r, tuple) else (r,))
    return shp, out


def res(f, *args, k=0):
    """The k-th result of the application: a scalar, a list (vector) or a Mat."""
    shp, out = apply(f, *args)
    comp = [t[k] for t in out]
    if shp is None:
        return comp[0]
    if shp[0] == 'v':
        return comp
    return Mat(shp[1], shp[2], comp)


def o_pv(v):
    return '%d:' % len(v) + ''.join(' ' + gg(float(x)) for x in v) + '\n'


def o_pvi(v):
    return '%d:' % len(v) + ''.join(' %d' % x for x in v) + '\n'


def o_pvb(v):
    return '%d:' % len(v) + ''.join(' %d' % (1 if x else 0) for x in v) + '\n'


def o_pm(M):
    return '%dx%d' % (M.r, M.c) + ''.join(
        ' |' + ''.join(' ' + gg(float(M.at(i, j))) for j in range(M.c)) for i in range(M.r)) + '\n'


def o_pmi(M):
    return '%dx%d' % (M.r, M.c) + ''.join(
        ' |' + ''.join(' %d' % M.at(i, j) for j in range(M.c)) for i in range(M.r)) + '\n'


# scalar mirrors of the Sea functions
def sq(x):
    return x * x


def f2(x, y):
    return x * 10.0 + y


def axpy(a, x, y):
    return a * x + y


def positive(x):
    return x > 0.0


# ---------------------------------------------------------------------------- writers
def prog(name, comment, body, out):
    C.prog(name, comment, body, out)


def prog_fail(name, comment, body, line_marker, msg, out, nth=0):
    """programs/NAME with a run-time error: .out (standard output before it), .err, .status 1 (no heap line:
    a status other than 0 has none, tests/run.sh)."""
    src = C.source(name, comment, body)
    ln = C.line_of(src, line_marker, nth)
    base = os.path.join(PROGRAMS, name)
    C.wbytes(base + '.sea', src)
    C.wbytes(base + '.out', out)
    C.wbytes(base + '.err', '%s.sea:%d: error: %s\n' % (name, ln, msg))
    C.wbytes(base + '.status', '1\n')
    COUNT['programs'] += 1


class B:
    """A program body (Sea source) with its expected standard output kept in step."""

    def __init__(self, head=''):
        self.src = head
        self.out = ''

    def s(self, text):
        self.src += text if text.endswith('\n') else text + '\n'

    def p(self, text, out):
        """A statement `text` that prints `out`."""
        self.s(text)
        self.out += out


# ---------------------------------------------------------------------------- programs
def elem_scalar():
    b = B(SQ + r'''elemental fn clampi(x: i64, lo: i64, hi: i64) -> i64 {
    if x < lo {
        return lo
    }
    if x > hi {
        return hi
    }
    return x
}
''' + POSITIVE + r'''elemental fn divmod(a: i64, b: i64) -> (i64, i64) {
    return (idiv(a, b), a % b)
}
elemental fn mix(a: f64, n: i64, flag: bool) -> f64 {
    if flag {
        return a * f64(n)
    }
    return a + f64(n)
}
''')

    def clampi(x, lo, hi):
        return lo if x < lo else (hi if x > hi else x)

    def mix(a, n, flag):
        return a * float(n) if flag else a + float(n)
    b.p('printf("%g\\n", sq(3.0))', gg(sq(3.0)) + '\n')
    b.p('printf("%g\\n", sq(-1.5))', gg(sq(-1.5)) + '\n')
    b.p('printf("%g\\n", sq(4))', gg(sq(4.0)) + '\n')
    b.s('let n = 7')
    b.p('printf("%g\\n", sq(n))', gg(sq(7.0)) + '\n')
    b.p('printf("%g\\n", sq(2.0) + sq(3.0))', gg(sq(2.0) + sq(3.0)) + '\n')
    b.p('printf("%d %d %d\\n", clampi(-5, 0, 10), clampi(15, 0, 10), clampi(7, 0, 10))',
        '%d %d %d\n' % (clampi(-5, 0, 10), clampi(15, 0, 10), clampi(7, 0, 10)))
    b.p('printf("%d %d %d\\n", positive(2.5), positive(-2.0), positive(0.0))',
        '%d %d %d\n' % (positive(2.5), positive(-2.0), positive(0.0)))
    # floored idiv and % (LANGUAGE.md 6.6): Python's // and % on ints are floored as well
    for idx, (a, c) in enumerate(((17, 5), (-17, 5), (17, -5), (-17, -5))):
        b.s('let (q%d, r%d) = divmod(%d, %d)' % (idx, idx, a, c))
        b.p('printf("%%d %%d\\n", q%d, r%d)' % (idx, idx), '%d %d\n' % (a // c, a % c))
    b.p('printf("%g %g\\n", mix(1.5, 4, true), mix(1.5, 4, false))',
        '%s %s\n' % (gg(mix(1.5, 4, True)), gg(mix(1.5, 4, False))))
    prog('elem_scalar',
         ['elemental functions called with scalars are ordinary calls (LANGUAGE.md 8.5): f64, i64 and bool',
          'parameters and results, an untyped literal and an i64 variable for an f64 parameter, floored idiv and %',
          'of a two-result function (LANGUAGE.md 6.6, 8.4)'],
         b.src, b.out)


def elem_vector():
    b = B(PV + PVI + PVB + RAMP + SQ + F2 + AXPY + POSITIVE + r'''elemental fn tri(i: i64) -> i64 {
    return idiv(i * (i + 1), 2)
}
''')
    tri = lambda i: (i * (i + 1)) // 2  # noqa: E731
    b.s('let v = ramp(5)')
    v = ramp(5)
    b.p('pv(sq(v))', o_pv(res(sq, v)))
    b.p('pv(axpy(2.0, v, v))', o_pv(res(axpy, 2.0, v, v)))
    b.p('pv(axpy(v, 3.0, 1.0))', o_pv(res(axpy, v, 3.0, 1.0)))
    b.p('pv(axpy(v, v, v))', o_pv(res(axpy, v, v, v)))
    b.p('pv(axpy(1.5, 2.0, v))', o_pv(res(axpy, 1.5, 2.0, v)))
    b.s('let w = ramp(5) * 2.0')
    w = [x * 2.0 for x in ramp(5)]
    b.p('pv(axpy(v, w, 0.25))', o_pv(res(axpy, v, w, 0.25)))
    b.p('pv(f2(w, v))', o_pv(res(f2, w, v)))
    b.p('pvb(positive(v - 1.0))', o_pvb(res(positive, [x - 1.0 for x in v])))
    b.p('pvb(positive(v))', o_pvb(res(positive, v)))
    b.p('pvi(tri((0..6)))', o_pvi(res(tri, list(range(6)))))
    b.s('let k = [3, 1, 2]')
    b.p('pvi(tri(k))', o_pvi(res(tri, [3, 1, 2])))
    b.p('pvi(tri(k * 2))', o_pvi(res(tri, [6, 2, 4])))
    b.s('let one = ramp(1)')
    b.p('pv(sq(one))', o_pv(res(sq, [0.0])))
    prog('elem_vector',
         ['an elemental function applied to a vector (LANGUAGE.md 8.5, 6.3): one, two and three array arguments,',
          'scalars mixed in, an f64 result vector, a bool result vector, an i64 function over a range value, a fixed i64',
          'vector and an expression, a vector of length 1'],
         b.src, b.out)


def elem_matrix():
    b = B(PM + GRID + SQ + F2 + AXPY + POSITIVE)
    A = lattice(3, 4)
    b.s('let A = lattice(3, 4)')
    b.p('pm(sq(A))', o_pm(res(sq, A)))
    b.p('pm(f2(A, A))', o_pm(res(f2, A, A)))
    b.p('pm(f2(A, 2.0))', o_pm(res(f2, A, 2.0)))
    b.p('pm(f2(0.5, A))', o_pm(res(f2, 0.5, A)))
    b.s('let B = lattice(3, 4) * 0.5')
    B_ = Mat(3, 4, [x * 0.5 for x in A.d])
    b.p('pm(f2(A, B))', o_pm(res(f2, A, B_)))
    b.p('pm(axpy(A, B, 1.0))', o_pm(res(axpy, A, B_, 1.0)))
    b.p('pm(axpy(2.0, A, B))', o_pm(res(axpy, 2.0, A, B_)))
    b.p('pm(sq(A.T))', o_pm(res(sq, A.t())))
    b.s('let C = lattice(4, 3)')
    b.p('pm(f2(A.T, C))', o_pm(res(f2, A.t(), lattice(4, 3))))
    b.p('pm(f2(A[1..3, 1..4], 1.0))', o_pm(res(f2, Mat(2, 3, [A.at(i, j) for j in range(1, 4) for i in range(1, 3)]), 1.0)))
    b.s('let one = ones(1, 1)')
    b.p('pm(f2(one, one))', o_pm(res(f2, Mat(1, 1, [1.0]), Mat(1, 1, [1.0]))))
    b.s('let mask = positive(A - 5.0)')
    b.p('printf("%d\\n", any(mask.flat))', '%d\n' % (1 if any(positive(x - 5.0) for x in A.d) else 0))
    prog('elem_matrix',
         ['an elemental function applied to matrices (LANGUAGE.md 8.5, 6.3): one, two and three matrix arguments,',
          'a scalar on either side, a transposed view, a slice of a matrix, a 1 x 1 matrix, a reduction of a bool',
          'matrix result; results are matrices of the broadcast shape'],
         b.src, b.out)


def elem_broadcast():
    b = B(PV + PM + RAMP + GRID + F2 + AXPY)
    a = ramp(3)
    bb = ramp(4)
    A = lattice(3, 4)
    b.s('let a = ramp(3)')
    b.s('let b = ramp(4)')
    b.s('let A = lattice(3, 4)')
    b.p('pm(f2(a.col, b.row))', o_pm(res(f2, col(a), row(bb))))
    b.p('pm(f2(b.row, a.col))', o_pm(res(f2, row(bb), col(a))))
    b.p('pm(f2(a.col, A))', o_pm(res(f2, col(a), A)))
    b.p('pm(f2(b.row, A))', o_pm(res(f2, row(bb), A)))
    b.p('pm(f2(A, a.col))', o_pm(res(f2, A, col(a))))
    b.p('pm(f2(A, b.row))', o_pm(res(f2, A, row(bb))))
    b.p('pm(f2(a.col, 1.0))', o_pm(res(f2, col(a), 1.0)))
    b.p('pm(f2(2.0, b.row))', o_pm(res(f2, 2.0, row(bb))))
    b.p('pm(axpy(a.col, 2.0, b.row))', o_pm(res(axpy, col(a), 2.0, row(bb))))
    b.p('pm(axpy(2.0, a.col, b.row))', o_pm(res(axpy, 2.0, col(a), row(bb))))
    b.p('pm(axpy(a.col, b.row, A))', o_pm(res(axpy, col(a), row(bb), A)))
    b.p('pm(axpy(A, a.col, b.row))', o_pm(res(axpy, A, col(a), row(bb))))
    b.s('let c = ramp(1)')
    b.p('pm(f2(c.col, A))', o_pm(res(f2, col([0.0]), A)))
    b.p('pm(f2(c.row, b.col))', o_pm(res(f2, row([0.0]), col(bb))))
    b.p('pv(f2(a, 1.0))', o_pv(res(f2, a, 1.0)))
    b.p('pv(f2(1.0, a))', o_pv(res(f2, 1.0, a)))
    b.p('pv(axpy(1.0, a, 2.0))', o_pv(res(axpy, 1.0, a, 2.0)))
    b.p('printf("%g\\n", f2(2.0, 3.0))', gg(f2(2.0, 3.0)) + '\n')
    prog('elem_broadcast',
         ['broadcasting of the elemental arguments (LANGUAGE.md 6.3, 8.5): a scalar with a vector, .col with .row in',
          'both orders, .col or .row with a matrix, three operands combined left to right with the scalars skipped,',
          'a 1 x 1 matrix, a 1-element vector as .col and .row'],
         b.src, b.out)


def elem_fixed():
    b = B(PV + PM + RAMP + F2 + r'''fn sum3(v: f64[3]) -> f64 {
    return v[0] + v[1] + v[2]
}
''')
    a = [1.0, 2.0, 3.0]
    bb = [0.5, 0.25, 0.125]
    b.s('let a = [1.0, 2.0, 3.0]')
    b.s('let b = [0.5, 0.25, 0.125]')
    b.s('let r: f64[3] = f2(a, b)')
    b.p('pv(r)', o_pv(res(f2, a, bb)))
    b.p('printf("%g\\n", sum3(f2(a, 1.0)))', gg(sum(res(f2, a, 1.0))) + '\n')
    b.p('printf("%g\\n", sum3(f2(0.5, b)))', gg(sum(res(f2, 0.5, bb))) + '\n')
    b.s('let M = [1.0, 2.0; 3.0, 4.0]')
    M = Mat(2, 2, [1.0, 3.0, 2.0, 4.0])
    b.s('let N: f64[2,2] = f2(M, M)')
    b.p('pm(N)', o_pm(res(f2, M, M)))
    b.s('let c = [1.0, 2.0]')
    b.s('let d = [10.0, 20.0, 30.0]')
    b.s('let P: f64[2,3] = f2(c.col, d.row)')
    b.p('pm(P)', o_pm(res(f2, col([1.0, 2.0]), row([10.0, 20.0, 30.0]))))
    b.s('let Q: f64[2,2] = f2(M, c.col)')
    b.p('pm(Q)', o_pm(res(f2, M, col([1.0, 2.0]))))
    # mixed fixed and dynamic: a dynamic result (the fixed-to-dynamic conversion of LANGUAGE.md 4.5)
    b.s('let dyn3 = ramp(3)')
    dyn3 = ramp(3)
    b.s('let m1 = f2(a, dyn3)')
    b.p('pv(m1)', o_pv(res(f2, a, dyn3)))
    b.p('printf("%d\\n", len(f2(dyn3, b)))', '3\n')
    b.s('let m2: f64[3] = f2(a, dyn3)')
    b.p('pv(m2)', o_pv(res(f2, a, dyn3)))
    b.s('let m3 = f2(M, ones(2, 2))')
    b.p('pm(m3)', o_pm(res(f2, M, Mat(2, 2, [1.0] * 4))))
    prog('elem_fixed',
         ['fixed-size elemental arguments give fixed-size results (the annotations f64[3], f64[2,2], f64[2,3] bind',
          'them; a result that were dynamic would still pass, so err_elem6_fixed_result proves it at compile time);',
          'a fixed and a dynamic argument give a dynamic result (r_elem6_mixed_dynamic proves it) (LANGUAGE.md 4.5, 8.5)'],
         b.src, b.out)


def elem_i64_to_f64():
    b = B(PV + PVI + PM + PMI + RAMP + r'''elemental fn halve(x: f64) -> f64 {
    return x / 2.0
}
elemental fn add2(x: f64, y: f64) -> f64 {
    return x + y
}
elemental fn cube(i: i64) -> i64 {
    return i * i * i
}
''')
    halve = lambda x: x / 2.0  # noqa: E731
    add2 = lambda x, y: x + y  # noqa: E731
    cube = lambda i: i * i * i  # noqa: E731
    r5 = [float(i) for i in range(5)]
    b.p('pv(halve((0..5)))', o_pv(res(halve, r5)))
    b.s('let k = [3, 1, 4]')
    kf = [3.0, 1.0, 4.0]
    b.p('pv(halve(k))', o_pv(res(halve, kf)))
    b.p('pv(add2(k, 0.5))', o_pv(res(add2, kf, 0.5)))
    b.p('pv(add2(k, ramp(3)))', o_pv(res(add2, kf, ramp(3))))
    b.p('pv(add2(2, k))', o_pv(res(add2, 2.0, kf)))
    b.s('let I = filled(0, 2, 3)')
    b.s('var J = filled(0, 2, 3)')
    b.s('for j in 0..3 {\n    for i in 0..2 {\n        J[i, j] = i * 3 + j\n    }\n}')
    Jm = Mat(2, 3, [float(i * 3 + j) for j in range(3) for i in range(2)])
    b.p('pm(halve(J))', o_pm(res(halve, Jm)))
    b.p('pm(add2(J, I))', o_pm(res(add2, Jm, Mat(2, 3, [0.0] * 6))))
    b.p('pm(add2(J, 0.25))', o_pm(res(add2, Jm, 0.25)))
    b.p('pvi(cube((0..5)))', o_pvi(res(cube, list(range(5)))))
    b.p('pv(halve(cube((0..4))))', o_pv(res(halve, [float(cube(i)) for i in range(4)])))
    prog('elem_i64_to_f64',
         ['an i64 array for an f64 elemental parameter converts element by element (LANGUAGE.md 4.2 (c), 8.5): a',
          'range value, a fixed i64 vector, an i64 matrix, mixed with f64 scalars and arrays; an i64 parameter given',
          'an i64 array is not converted'],
         b.src, b.out)


def elem_uniform():
    b = B(PV + PVI + RAMP + GRID + PM + r'''struct Params {
    ka: f64
    name: str
    w: f64[3]
}
elemental fn scale(x: f64, p: Params) -> f64 {
    return x * p.ka + p.w[1] + f64(len(p.name))
}
elemental fn tag_len(i: i64, s: str) -> i64 {
    return i + len(s)
}
elemental fn pick(i: i64, tbl: f64[]) -> f64 {
    return tbl[i] * 2.0
}
elemental fn pick3(i: i64, tbl: f64[3]) -> f64 {
    return tbl[i] + 1.0
}
elemental fn name_len(i: i64, names: str[]) -> i64 {
    return len(names[i])
}
elemental fn last_plus(x: f64, off: f64[]) -> f64 {
    return x + off[$ - 1]
}
''')
    b.s('let p = Params { ka: 2.0, name: "abc", w: [0.5, 1.5, 2.5] }')
    sc = lambda x: x * 2.0 + 1.5 + 3.0  # noqa: E731
    v = ramp(4)
    b.s('let v = ramp(4)')
    b.p('pv(scale(v, p))', o_pv(res(sc, v)))
    b.p('printf("%g\\n", scale(2.0, p))', gg(sc(2.0)) + '\n')
    b.p('pm(scale(lattice(2, 3), p))', o_pm(res(sc, lattice(2, 3))))
    tl = lambda i, s: i + len(s)  # noqa: E731
    b.p('pvi(tag_len((0..4), "abcd"))', o_pvi(res(tl, list(range(4)), "abcd")))
    b.p('printf("%d\\n", tag_len(3, "xy"))', '%d\n' % tl(3, "xy"))
    b.s('let tbl = [1.5, 2.5, 3.5, 4.5]')
    tbl = [1.5, 2.5, 3.5, 4.5]
    b.p('pv(pick((0..4), tbl))', o_pv(res(lambda i: tbl[i] * 2.0, list(range(4)))))
    b.p('pv(pick([3, 0, 2], tbl))', o_pv(res(lambda i: tbl[i] * 2.0, [3, 0, 2])))
    b.p('pv(pick3([2, 1, 0, 1], [1.0, 2.0, 3.0]))', o_pv(res(lambda i: [1.0, 2.0, 3.0][i] + 1.0, [2, 1, 0, 1])))
    b.s('let names = ["a", "bcd", "ef"]')
    b.p('pvi(name_len((0..3), names))', o_pvi([1, 3, 2]))
    b.p('pv(last_plus(v, tbl))', o_pv(res(lambda x: x + tbl[-1], v)))
    b.p('printf("%g\\n", last_plus(1.0, v))', gg(1.0 + v[-1]) + '\n')
    prog('elem_uniform',
         ['uniform parameters (LANGUAGE.md 8.5): a struct with str, array and scalar fields (W1\'s Params shape; a',
          'record has no type syntax, so no parameter is a record), a str, a dynamic array, a fixed-size array and a',
          'str[] are passed unchanged while the elemental arguments are broadcast; `$` in the body is the uniform array\'s',
          'extent'],
         b.src, b.out)


def elem_results():
    b = B(PV + PM + RAMP + GRID + r'''struct Params {
    ka: f64
    ke: f64
    sut: f64
    sy: f64
}
elemental fn shaft(d: f64, M: f64, T: f64, p: Params) -> (f64, f64, f64, f64, f64) {
    let a = d * p.ka
    let b = M * p.ke
    let c = T + p.sut
    return (a + b, a * b, c - d, p.sy / (d + 1.0), a + b + c)
}
elemental fn one(x: f64) -> f64 {
    return x + 1.0
}
elemental fn two(x: f64, y: f64) -> (f64, f64) {
    return (x + y, x - y)
}
''')

    def shaft(d, M, T, p=(2.0, 0.5, 100.0, 40.0)):
        ka, ke, sut, sy = p
        a = d * ka
        bq = M * ke
        c = T + sut
        return (a + bq, a * bq, c - d, sy / (d + 1.0), a + bq + c)
    b.s('let p = Params { ka: 2.0, ke: 0.5, sut: 100.0, sy: 40.0 }')
    # one result
    v = ramp(4)
    b.s('let v = ramp(4)')
    b.p('pv(one(v))', o_pv(res(lambda x: x + 1.0, v)))
    # five results, scalars (an ordinary call)
    b.s('let (s1, s2, s3, s4, s5) = shaft(0.5, 2.0, 4.0, p)')
    t = shaft(0.5, 2.0, 4.0)
    b.p('printf("%g %g %g %g %g\\n", s1, s2, s3, s4, s5)', ' '.join(gg(x) for x in t) + '\n')
    # five results, vectors (W1's sweep): d vector, M scalar, T vector
    T = [x * 2.0 for x in v]
    b.s('let T = v * 2.0')
    b.s('let (n1, n2, n3, n4, n5) = shaft(v, 2.0, T, p)')
    for k in range(1, 6):
        b.p('pv(n%d)' % k, o_pv(res(shaft, v, 2.0, T, k=k - 1)))
    # results bound to `_`: the kept ones keep their values
    b.s('let (k1, _, _, k4, _) = shaft(v, 2.0, T, p)')
    b.p('pv(k1)', o_pv(res(shaft, v, 2.0, T, k=0)))
    b.p('pv(k4)', o_pv(res(shaft, v, 2.0, T, k=3)))
    b.s('let (_, _, _, _, z5) = shaft(v, 2.0, T, p)')
    b.p('pv(z5)', o_pv(res(shaft, v, 2.0, T, k=4)))
    # every result discarded (no output, no leak; the heap check proves no allocation is left)
    b.s('let (_, _, _, _, _) = shaft(v, 2.0, T, p)')
    b.s('let _ = one(v)')
    b.s('let (_, _) = two(v, v)')
    # five results, matrices
    G = lattice(2, 3)
    b.s('let G = lattice(2, 3)')
    b.s('let (g1, g2, g3, g4, g5) = shaft(G, 1.0, 0.0, p)')
    for k in range(1, 6):
        b.p('pm(g%d)' % k, o_pm(res(shaft, G, 1.0, 0.0, k=k - 1)))
    # two results with a broadcast: .col with .row
    b.s('let (u1, u2) = two(ramp(2).col, ramp(3).row)')
    b.p('pm(u1)', o_pm(res(lambda x, y: (x + y, x - y), col(ramp(2)), row(ramp(3)), k=0)))
    b.p('pm(u2)', o_pm(res(lambda x, y: (x + y, x - y), col(ramp(2)), row(ramp(3)), k=1)))
    b.s('let (_, u3) = two(ramp(2).col, ramp(3).row)')
    b.p('pm(u3)', o_pm(res(lambda x, y: (x + y, x - y), col(ramp(2)), row(ramp(3)), k=1)))
    prog('elem_results',
         ['one result and five (W1\'s shaft_safety shape) (LANGUAGE.md 8.5, 2.1): scalars, vectors, matrices and a',
          'broadcast; results bound to `_` keep the others\' values and, bound all to `_`, produce no output and leave',
          'nothing live (the heap check, DESIGN.md 2.11.4 L19 step 3)'],
         b.src, b.out)


def elem_tuple_assign():
    b = B(PV + PM + RAMP + r'''elemental fn three(x: f64, s: f64) -> (f64, f64, f64) {
    return (x + s, x * s, x - s)
}
elemental fn mixr(i: i64) -> (i64, f64) {
    return (i * 2, f64(i) + 0.5)
}
elemental fn two(x: f64, y: f64) -> (f64, f64) {
    return (x + y, x - y)
}
''')
    three = lambda x, s: (x + s, x * s, x - s)  # noqa: E731
    v = ramp(3)
    b.s('var A = zeros(3, 3)')
    b.s('var B = zeros(3, 3)')
    b.s('let v = ramp(3)')
    A = [[0.0] * 3 for _ in range(3)]  # A[i][j]
    Bm = [[0.0] * 3 for _ in range(3)]
    r1, r2, r3 = res(three, v, 2.0, k=0), res(three, v, 2.0, k=1), res(three, v, 2.0, k=2)
    b.s('(A[1, :], B[:, 2], _) = three(v, 2.0)')
    for j in range(3):
        A[1][j] = r1[j]
    for i in range(3):
        Bm[i][2] = r2[i]

    def mat(X):
        return Mat(3, 3, [X[i][j] for j in range(3) for i in range(3)])
    b.p('pm(A)', o_pm(mat(A)))
    b.p('pm(B)', o_pm(mat(Bm)))
    w = [x + 1.0 for x in v]
    q1, q3 = res(three, w, 0.5, k=0), res(three, w, 0.5, k=2)
    b.s('(A[0, :], _, B[2, :]) = three(v + 1.0, 0.5)')
    for j in range(3):
        A[0][j] = q1[j]
        Bm[2][j] = q3[j]
    b.p('pm(A)', o_pm(mat(A)))
    b.p('pm(B)', o_pm(mat(Bm)))
    # a scalar call into element targets
    s1, s2, s3 = three(1.0, 2.0)
    b.s('(A[2, 0], _, B[0, 0]) = three(1.0, 2.0)')
    A[2][0] = s1
    Bm[0][0] = s3
    b.p('printf("%g %g\\n", A[2, 0], B[0, 0])', '%s %s\n' % (gg(A[2][0]), gg(Bm[0][0])))
    # whole-variable targets take the new value and shape; i64 results convert to the f64 target
    b.s('var P = zeros(2)')
    b.s('var Q = zeros(2)')
    b.s('(P, Q) = mixr((0..4))')
    b.p('pv(P)', o_pv([float(i * 2) for i in range(4)]))
    b.p('pv(Q)', o_pv([float(i) + 0.5 for i in range(4)]))
    b.s('var x1 = 0.0')
    b.s('var x2 = 0.0')
    b.s('(x1, x2) = two(1.0, 2.0)')
    b.p('printf("%g %g\\n", x1, x2)', '%s %s\n' % (gg(3.0), gg(-1.0)))
    b.s('(P, _) = mixr((0..2))')
    b.p('pv(P)', o_pv([0.0, 2.0]))
    # a selection target takes a scalar: stored into every selected element
    b.s('(_, B[1, :]) = two(1.0, 2.0)')
    Bm[1] = [-1.0, -1.0, -1.0]
    b.p('pm(B)', o_pm(mat(Bm)))
    prog('elem_tuple_assign',
         ['a tuple assignment of an elemental call\'s results into selection targets (LANGUAGE.md 7.3, 8.5):',
          '(A[1, :], B[:, 2], _) = f(...), element targets with a scalar call, whole-variable targets that take the',
          'results\' shape and convert i64 to f64 (4.2), `_` skipping a result, a scalar result stored into every',
          'element of a selection (5.5)'],
         b.src, b.out)


def elem_eval():
    b = B(PV + RAMP + SQ + r'''elemental fn two(x: f64, y: f64) -> (f64, f64) {
    return (x + y, x - y)
}
fn tv(k: i64, v: f64[]) -> f64[] {
    printf("eval %d\n", k)
    return v
}
''')
    b.s('let v = ramp(4)')
    b.s('sq(v)')
    b.s('two(v, 1.0)')
    b.s('sq(3.0)')
    b.s('let _ = sq(v)')
    b.s('let (_, _) = two(v, v)')
    b.p('sq(tv(1, v))', 'eval 1\n')
    b.p('let (_, _) = two(tv(2, v), tv(3, v))', 'eval 2\neval 3\n')
    b.p('printf("done\\n")', 'done\n')
    prog('elem_eval',
         ['an elemental call used as a statement, or with every result bound to `_`, has no effect but its errors',
          '(LANGUAGE.md 7.1, 7.2, 8.5): nothing is printed, and an argument expression is evaluated exactly once, in',
          'full, before the elements (DESIGN.md 2.11.4 L19 step 1, L-ck)'],
         b.src, b.out)


def elem_nested():
    b = B(PV + PVI + PM + RAMP + GRID + SQ + F2 + r'''fn poly(x: f64) -> f64 {
    return x * x * x - x
}
elemental fn hyp2(x: f64, y: f64) -> f64 {
    return sqrt(sq(x) + sq(y))
}
elemental fn twice(x: f64) -> f64 {
    return sq(sq(x))
}
elemental fn with_ord(x: f64) -> f64 {
    return poly(x) + f2(x, 1.0)
}
elemental fn tri(i: i64) -> i64 {
    return idiv(i * (i + 1), 2)
}
elemental fn tri_sq(i: i64) -> i64 {
    return tri(i) * tri(i)
}
''')
    v = ramp(5)
    b.s('let v = ramp(5)')
    b.p('pv(sq(sq(v)))', o_pv(res(sq, res(sq, v))))
    b.p('pv(twice(v))', o_pv(res(lambda x: sq(sq(x)), v)))
    b.s('let w = ramp(5) * 3.0')
    w = [x * 3.0 for x in v]
    b.p('pv(f2(sq(v), sq(w)))', o_pv(res(f2, res(sq, v), res(sq, w))))
    b.s('let a = [3.0, 5.0, 8.0]')
    b.s('let c = [4.0, 12.0, 15.0]')
    hyp2 = lambda x, y: math.sqrt(sq(x) + sq(y))  # noqa: E731
    b.p('pv(hyp2(a, c))', o_pv(res(hyp2, [3.0, 5.0, 8.0], [4.0, 12.0, 15.0])))
    b.p('pv(hyp2([3.0, 0.0, -3.0], 4.0))', o_pv(res(hyp2, [3.0, 0.0, -3.0], 4.0)))
    b.p('printf("%g\\n", hyp2(6.0, 8.0))', gg(hyp2(6.0, 8.0)) + '\n')
    poly = lambda x: x * x * x - x  # noqa: E731
    wo = lambda x: poly(x) + f2(x, 1.0)  # noqa: E731
    b.p('pv(with_ord(v))', o_pv(res(wo, v)))
    tri = lambda i: (i * (i + 1)) // 2  # noqa: E731
    b.p('pvi(tri_sq((0..6)))', o_pvi(res(lambda i: tri(i) * tri(i), list(range(6)))))
    b.s('let A = lattice(2, 3)')
    A = lattice(2, 3)
    b.p('pm(f2(sq(A), A))', o_pm(res(f2, res(sq, A), A)))
    b.p('pm(f2(sq(ramp(2).col), sq(ramp(3).row)))', o_pm(res(f2, res(sq, col(ramp(2))), res(sq, row(ramp(3))))))
    b.p('pm(sq(f2(A, A)))', o_pm(res(sq, res(f2, A, A))))
    b.p('printf("%g\\n", sq(sq(sq(2.0))))', gg(sq(sq(sq(2.0)))) + '\n')
    prog('elem_nested',
         ['nested elemental calls and an elemental function calling another elemental function or an ordinary',
          'function (LANGUAGE.md 8.5): sq(sq(v)), an elemental call as the argument of another with vectors, with',
          '.col and .row, with matrices; every call inlined into one loop, results unchanged'],
         b.src, b.out)


def elem_calls_recursive():
    b = B(PV + PVI + PVB + r'''fn fact(n: i64) -> i64 {
    if n <= 1 {
        return 1
    }
    return n * fact(n - 1)
}
fn fib(n: i64) -> i64 {
    if n < 2 {
        return n
    }
    return fib(n - 1) + fib(n - 2)
}
fn is_even(n: i64) -> bool {
    if n == 0 {
        return true
    }
    return is_odd(n - 1)
}
fn is_odd(n: i64) -> bool {
    if n == 0 {
        return false
    }
    return is_even(n - 1)
}
elemental fn fact_f(n: i64) -> f64 {
    return f64(fact(n))
}
elemental fn mixrec(n: i64, k: i64) -> i64 {
    return fib(n) + fact(k)
}
elemental fn fibsq(n: i64) -> i64 {
    let f = fib(n)
    return f * f
}
elemental fn parity(n: i64) -> bool {
    return is_even(n)
}
''')

    def fact(n):
        return 1 if n <= 1 else n * fact(n - 1)

    def fib(n):
        return n if n < 2 else fib(n - 1) + fib(n - 2)
    b.p('pv(fact_f((0..7)))', o_pv(res(lambda n: float(fact(n)), list(range(7)))))
    b.p('pvi(mixrec((0..6), 3))', o_pvi(res(lambda n, k: fib(n) + fact(k), list(range(6)), 3)))
    b.p('pvi(mixrec(10, (0..4)))', o_pvi(res(lambda n, k: fib(n) + fact(k), 10, list(range(4)))))
    b.p('printf("%d\\n", fibsq(10))', '%d\n' % (fib(10) ** 2))
    b.p('pvi(fibsq((1..8)))', o_pvi(res(lambda n: fib(n) ** 2, list(range(1, 8)))))
    b.p('printf("%d %d\\n", parity(10), parity(7))', '%d %d\n' % (1, 0))
    b.p('pvb(parity((0..6)))', o_pvb(res(lambda n: n % 2 == 0, list(range(6)))))
    prog('elem_calls_recursive',
         ['an elemental function may call an ordinary recursive function whose cycle it is not on (LANGUAGE.md 8.5',
          'as amended): factorial and Fibonacci (direct recursion), an even/odd pair (mutual recursion), called with',
          'scalars and with arrays; the recursive functions stay calls (8.6), the elemental one is inlined'],
         b.src, b.out)


def elem_named_default():
    b = B(PV + RAMP + r'''elemental fn lerp(a: f64, b: f64, t: f64 = 0.5) -> f64 {
    return a + (b - a) * t
}
elemental fn scaled(x: f64, k: f64 = 2.0, tag: str = "x", off: i64 = 1) -> f64 {
    return x * k + f64(off + len(tag))
}
fn tv(k: i64, v: f64[]) -> f64[] {
    printf("eval %d\n", k)
    return v
}
''')
    lerp = lambda a, bq, t=0.5: a + (bq - a) * t  # noqa: E731
    scaled = lambda x, k=2.0, tag="x", off=1: x * k + float(off + len(tag))  # noqa: E731
    v = ramp(4)
    w = [x * 4.0 for x in v]
    b.s('let v = ramp(4)')
    b.s('let w = ramp(4) * 4.0')
    b.p('printf("%g\\n", lerp(1.0, 3.0))', gg(lerp(1.0, 3.0)) + '\n')
    b.p('printf("%g\\n", lerp(1.0, 3.0, t: 0.25))', gg(lerp(1.0, 3.0, 0.25)) + '\n')
    b.p('pv(lerp(v, 3.0))', o_pv(res(lerp, v, 3.0)))
    b.p('pv(lerp(v, w, t: 0.25))', o_pv(res(lerp, v, w, 0.25)))
    b.p('pv(lerp(0.0, b: w, t: v))', o_pv(res(lerp, 0.0, w, v)))
    b.p('pv(lerp(b: w, a: 0.0, t: v))', o_pv(res(lambda bq, a, t: lerp(a, bq, t), w, 0.0, v)))
    b.p('pv(lerp(t: v, b: w, a: 1.0))', o_pv(res(lambda t, bq, a: lerp(a, bq, t), v, w, 1.0)))
    # named elemental arguments are evaluated in source order, once each, whatever the parameter order
    b.p('pv(lerp(a: tv(1, v), t: tv(2, w), b: tv(3, v)))',
        'eval 1\neval 2\neval 3\n' + o_pv(res(lambda a, t, bq: lerp(a, bq, t), v, w, v)))
    b.p('pv(lerp(tv(1, v), t: tv(2, w), b: tv(3, v)))',
        'eval 1\neval 2\neval 3\n' + o_pv(res(lambda a, t, bq: lerp(a, bq, t), v, w, v)))
    b.p('pv(scaled(v))', o_pv(res(scaled, v)))
    b.p('pv(scaled(v, tag: "abc"))', o_pv(res(lambda x: scaled(x, tag="abc"), v)))
    b.p('pv(scaled(v, off: 10, k: 4.0))', o_pv(res(lambda x: scaled(x, k=4.0, off=10), v)))
    b.p('pv(scaled(v, w))', o_pv(res(scaled, v, w)))
    b.p('pv(scaled(1.0, k: w))', o_pv(res(lambda k: scaled(1.0, k=k), w)))
    b.p('printf("%g\\n", scaled(1.5, tag: "ab", off: 0))', gg(scaled(1.5, tag="ab", off=0)) + '\n')
    prog('elem_named_default',
         ['named and default arguments of elemental functions (LANGUAGE.md 8.1, 8.5): defaults of f64, str and i64',
          'parameters, named arguments in any order with scalars and arrays, a default broadcast against an array,',
          'argument expressions evaluated once, in source order, before any element (DESIGN.md 2.11.4 L19, L-ck, L-cp)'],
         b.src, b.out)


def elem_empty():
    b = B(r'''elemental fn boom(x: f64) -> f64 {
    if x < 100.0 {
        error("boom %g", x)
    }
    return x
}
elemental fn boom2(x: f64, y: f64) -> (f64, f64) {
    if x < 100.0 {
        error("boom2 %g %g", x, y)
    }
    return (x, y)
}
elemental fn chk(x: f64) {
    if x < 100.0 {
        error("chk %g", x)
    }
}
elemental fn tri(i: i64) -> i64 {
    if i >= 0 {
        error("tri %d", i)
    }
    return i
}
''')
    b.s('let e = zeros(0)')
    b.p('printf("%d\\n", len(boom(e)))', '0\n')
    b.s('boom(e)')
    b.s('chk(e)')
    b.s('let M0 = zeros(0, 3)')
    b.s('let R0 = boom(M0)')
    b.p('printf("%dx%d\\n", rows(R0), cols(R0))', '0x3\n')
    b.s('chk(M0)')
    b.s('let (R1, _) = boom2(M0, ones(1, 3))')
    b.p('printf("%dx%d\\n", rows(R1), cols(R1))', '0x3\n')
    b.s('let (r1a, r1b) = boom2(M0, ones(1, 3))')
    b.p('printf("%dx%d %dx%d\\n", rows(r1a), cols(r1a), rows(r1b), cols(r1b))', '0x3 0x3\n')
    b.s('let (r2a, r2b) = boom2(e.col, ones(3).row)')
    b.p('printf("%dx%d %dx%d\\n", rows(r2a), cols(r2a), rows(r2b), cols(r2b))', '0x3 0x3\n')
    b.s('let (r3a, _) = boom2(zeros(3, 0), ones(3, 1))')
    b.p('printf("%dx%d\\n", rows(r3a), cols(r3a))', '3x0\n')
    b.s('let (p, q) = boom2(e, e)')
    b.p('printf("%d %d\\n", len(p), len(q))', '0 0\n')
    b.s('let (p2, _) = boom2(e, 1.0)')
    b.p('printf("%d\\n", len(p2))', '0\n')
    b.p('printf("%d\\n", len(tri((0..0))))', '0\n')
    b.p('printf("%d\\n", len(tri((5..2))))', '0\n')
    b.s('let (_, _) = boom2(e, e)')
    b.s('boom2(M0, ones(1, 3))')
    b.p('printf("end\\n")', 'end\n')
    prog('elem_empty',
         ['empty arrays run no element (LANGUAGE.md 8.5, 6.3, 5.1): every body here raises an error at once, so the',
          'program printing its results\' shapes shows no call ran; 0-element vectors, 0 x 3 and 3 x 0 matrices, 0 x 1',
          'with 1 x 3 broadcast to 0 x 3 (6.3: `0x3` with `1x3` is `0x3`), empty ranges, results bound to `_`, call',
          'statements, a function without results (DESIGN.md 2.11.4 L19: an empty broadcast shape runs no element)'],
         b.src, b.out)


def elem_noresult():
    b = B(PV + RAMP + GRID + r'''elemental fn check(x: f64) {
    if x < 0.0 {
        error("negative value %g", x)
    }
}
elemental fn check2(x: f64, lim: f64) {
    if x > lim {
        error("above %g: %g", lim, x)
    }
}
''')
    b.p('check(1.0)', '')
    b.p('printf("scalar ok\\n")', 'scalar ok\n')
    b.s('check(ramp(4))')
    b.p('printf("vector ok\\n")', 'vector ok\n')
    b.s('check2(lattice(2, 3), 100.0)')
    b.s('check2(lattice(2, 3).T, 100.0)')
    b.s('check2(ramp(3).col, 100.0)')
    b.p('printf("matrix ok\\n")', 'matrix ok\n')
    b.s('check(zeros(0))')
    b.s('check2(0.5, 1.0)')
    b.s('let w = [1.0, 2.0, -3.0, 4.0, -5.0]')
    b.p('printf("before\\n")', 'before\n')
    b.s('check(w)')
    b.p('printf("unreachable\\n")', '')
    out = 'scalar ok\nvector ok\nmatrix ok\nbefore\n'
    prog_fail('elem_noresult',
              ['an elemental function without results (Decision 92, LANGUAGE.md 8.5): called with scalars, vectors,',
               'matrices, empty arrays and broadcasts it is run for its errors only and prints nothing; `error` stops at',
               'the first failing element in increasing linear order: w[2] = -3 (not -5), at the error call\'s line;',
               'status 1, standard output flushed first (9.2)'],
              b.src, 'error("negative value', 'negative value -3', out)


def elem_bisect():
    b = B(r'''elemental fn resid(x: f64, t: f64) -> (f64, f64) {
    return (x * x - t, x)
}
let t = [2.0, 9.0, 16.0]
var lo = zeros(3)
var hi = filled(10.0, 3)
for it in 0..30 {
    let mid = 0.5 * (lo + hi)
    let (e, _) = resid(mid, t)
    let up = e < 0.0
    lo = where(up, mid, lo)
    hi = where(up, hi, mid)
}
let root = 0.5 * (lo + hi)
for i in 0..3 {
    printf("%.6f\n", root[i])
}
''')
    t = [2.0, 9.0, 16.0]
    lo = [0.0] * 3
    hi = [10.0] * 3
    for _ in range(30):
        mid = [0.5 * (a + c) for a, c in zip(lo, hi)]
        e = [m * m - tt for m, tt in zip(mid, t)]
        up = [x < 0.0 for x in e]
        lo = [m if u else a for u, m, a in zip(up, mid, lo)]
        hi = [c if u else m for u, c, m in zip(up, hi, mid)]
    root = [0.5 * (a + c) for a, c in zip(lo, hi)]
    out = ''.join(gf(6, x) + '\n' for x in root)
    b.out = out
    prog('elem_bisect',
         ['W1\'s vectorized bisection shape (LANGUAGE.md 2.1): a two-result elemental function applied to a vector in a',
          'loop with one result discarded, `where` selecting the new bounds; 30 halvings of [0, 10] for the square',
          'roots of 2, 9 and 16, printed with %.6f (the mirror performs the same IEEE operations in the same order)'],
         b.src, b.out)


def elem_expr():
    b = B(PV + PVB + RAMP + SQ + F2 + POSITIVE)
    v = ramp(5)
    b.s('let v = ramp(5)')
    b.p('printf("%g\\n", sum(sq(v)))', gg(sum(sq(x) for x in v)) + '\n')
    b.p('printf("%g\\n", max(sq(v)))', gg(max(sq(x) for x in v)) + '\n')
    b.p('pv(sq(v) + 1.0)', o_pv([sq(x) + 1.0 for x in v]))
    b.p('pv(sq(v) * f2(v, 1.0))', o_pv([sq(x) * f2(x, 1.0) for x in v]))
    b.p('pv(where(positive(v - 1.0), sq(v), v))', o_pv([sq(x) if positive(x - 1.0) else x for x in v]))
    b.p('pvb(sq(v) > 1.0)', o_pvb([sq(x) > 1.0 for x in v]))
    b.s('let s = sq(v)')
    b.p('printf("%g\\n", s[3])', gg(sq(v[3])) + '\n')
    b.s('for x in sq(v) {\n    printf(" %g", x)\n}')
    b.p('printf("\\n")', ''.join(' ' + gg(sq(x)) for x in v) + '\n')
    b.p('pv(sq(v[1..4]))', o_pv([sq(x) for x in v[1:4]]))
    b.s('var acc = zeros(5)')
    b.s('acc = sq(v)')
    b.s('acc += f2(v, v)')
    b.p('pv(acc)', o_pv([sq(x) + f2(x, x) for x in v]))
    prog('elem_expr',
         ['an elemental call inside larger expressions (LANGUAGE.md 8.5: calls fuse with the surrounding element-wise',
          'expression): a reduction, an operand of + and *, `where`, a comparison, an element loop, a slice, `=` and',
          '`+=` into a variable'],
         b.src, b.out)


# ---------------------------------------------------------------------------- ind2sub with an array r
def ind2sub_arr():
    def i2s(r, k):
        return (k % r, k // r)
    b = B(PVI + PMI)
    # scalar k
    b.s('let r = [3, 4, 5]')
    b.s('let (i, j) = ind2sub(r, 7)')
    b.p('pvi(i)', o_pvi(res(i2s, [3, 4, 5], 7, k=0)))
    b.p('pvi(j)', o_pvi(res(i2s, [3, 4, 5], 7, k=1)))
    b.s('let (a, c) = ind2sub(r, -1)')
    b.p('pvi(a)', o_pvi(res(i2s, [3, 4, 5], -1, k=0)))
    b.p('pvi(c)', o_pvi(res(i2s, [3, 4, 5], -1, k=1)))
    b.s('let rs = filled(3, 4)')
    b.s('let (i2, j2) = ind2sub(rs, 10)')
    b.p('pvi(i2)', o_pvi(res(i2s, [3] * 4, 10, k=0)))
    b.p('pvi(j2)', o_pvi(res(i2s, [3] * 4, 10, k=1)))
    b.s('let (i3, _) = ind2sub(r, 0)')
    b.p('pvi(i3)', o_pvi(res(i2s, [3, 4, 5], 0, k=0)))
    b.s('let (_, j3) = ind2sub((2..6), 11)')
    b.p('pvi(j3)', o_pvi(res(i2s, [2, 3, 4, 5], 11, k=1)))
    b.s('let R = [3, 4; 5, 6]')
    Rm = Mat(2, 2, [3, 5, 4, 6])
    b.s('let (Ri, Rj) = ind2sub(R, 17)')
    b.p('pmi(Ri)', o_pmi(res(i2s, Rm, 17, k=0)))
    b.p('pmi(Rj)', o_pmi(res(i2s, Rm, 17, k=1)))
    b.s('let (_, _) = ind2sub(r, 7)')
    b.s('let (e1, e2) = ind2sub(filled(3, 0), 5)')
    b.p('printf("%d %d\\n", len(e1), len(e2))', '0 0\n')
    prog('ind2sub_arr_scalar_k',
         ['ind2sub with an array r and a scalar k (LANGUAGE.md 10.7: (k % r, idiv(k, r)), elemental; DESIGN.md 2.11.4',
          'L-cl): a fixed vector, a dynamic vector, a range value, a matrix r, negative and zero k (floored, 6.6),',
          'a result bound to `_`, an empty r'],
         b.src, b.out)

    b = B(PVI + PMI)
    b.s('let r = [3, 4, 5]')
    b.s('let k = [7, 10, 24]')
    b.s('let (i, j) = ind2sub(r, k)')
    b.p('pvi(i)', o_pvi(res(i2s, [3, 4, 5], [7, 10, 24], k=0)))
    b.p('pvi(j)', o_pvi(res(i2s, [3, 4, 5], [7, 10, 24], k=1)))
    b.s('let (a, c) = ind2sub((3..6), (7..10))')
    b.p('pvi(a)', o_pvi(res(i2s, [3, 4, 5], [7, 8, 9], k=0)))
    b.p('pvi(c)', o_pvi(res(i2s, [3, 4, 5], [7, 8, 9], k=1)))
    b.s('let kn = [-1, -5, 0]')
    b.s('let (n1, n2) = ind2sub(r, kn)')
    b.p('pvi(n1)', o_pvi(res(i2s, [3, 4, 5], [-1, -5, 0], k=0)))
    b.p('pvi(n2)', o_pvi(res(i2s, [3, 4, 5], [-1, -5, 0], k=1)))
    b.s('let r3 = (3..6)')
    b.s('let k4 = [7, 8, 9, 10]')
    b.s('let (m1, m2) = ind2sub(r3.col, k4.row)')
    rc = col([3, 4, 5])
    kr = row([7, 8, 9, 10])
    b.p('pmi(m1)', o_pmi(res(i2s, rc, kr, k=0)))
    b.p('pmi(m2)', o_pmi(res(i2s, rc, kr, k=1)))
    b.s('let (p1, _) = ind2sub(r, k)')
    b.p('pvi(p1)', o_pvi(res(i2s, [3, 4, 5], [7, 10, 24], k=0)))
    b.s('let (_, p2) = ind2sub(r, k)')
    b.p('pvi(p2)', o_pvi(res(i2s, [3, 4, 5], [7, 10, 24], k=1)))
    b.s('var I = filled(0, 1)')
    b.s('var J = filled(0, 1)')
    b.s('(I, J) = ind2sub(r, k)')
    b.p('pvi(I)', o_pvi(res(i2s, [3, 4, 5], [7, 10, 24], k=0)))
    b.p('pvi(J)', o_pvi(res(i2s, [3, 4, 5], [7, 10, 24], k=1)))
    b.s('let Rm = [3, 4; 5, 6]')
    b.s('let Km = [7, 8; 9, 10]')
    b.s('let (q1, q2) = ind2sub(Rm, Km)')
    Rm = Mat(2, 2, [3, 5, 4, 6])
    Km = Mat(2, 2, [7, 9, 8, 10])
    b.p('pmi(q1)', o_pmi(res(i2s, Rm, Km, k=0)))
    b.p('pmi(q2)', o_pmi(res(i2s, Rm, Km, k=1)))
    b.s('let (_, _) = ind2sub(r, k)')
    prog('ind2sub_arr_array_k',
         ['ind2sub with an array r and an array k (LANGUAGE.md 10.7, 6.3; DESIGN.md 2.11.4 L-cl): element by element,',
          'a range value pair, negative and zero k, `.col` with `.row` broadcast to a matrix, two matrices, either',
          'result bound to `_`, a tuple assignment into whole-variable targets, both results discarded'],
         b.src, b.out)

    # a call statement: every result is discarded (L19 under an eval, applied to L-cl); nothing is printed, no error
    b = B()
    b.s('let r = [3, 4, 5]')
    b.s('let k = [7, 10, 24]')
    b.s('ind2sub(r, k)')
    b.p('printf("ok\\n")', 'ok\n')
    prog('ind2sub_arr_eval',
         ['ind2sub with an array r used as a call statement (LANGUAGE.md 7.1, 10.7; DESIGN.md 2.11.4 L19 "under an eval',
          'every result is discarded", L-cl): no effect and no output but the line after it'],
         b.src, b.out)

    # an r of 0 at a known element: integer division by zero at the call's line (LANGUAGE.md 6.6, 10.7)
    for name, kexpr, what in (('ind2sub_arr_zero_scalar_k', '7', 'a scalar k'),
                              ('ind2sub_arr_zero_array_k', '[1, 2, 3]', 'an array k')):
        b = B()
        b.s('let r = [3, 0, 5]')
        b.p('printf("start\\n")', 'start\n')
        b.s('let (i, j) = ind2sub(r, %s)' % kexpr)
        b.s('printf("unreachable\\n")')
        prog_fail(name,
                  ['ind2sub with an array r holding a 0 at element 1 and %s: integer division by zero (LANGUAGE.md 6.6,' % what,
                   '10.7), reported at the call\'s line (DESIGN.md 2.11.4: P\'s site for every check); status 1, standard',
                   'output flushed first (9.2)'],
                  b.src, 'ind2sub(r', 'integer division by zero', 'start\n')


# ---------------------------------------------------------------------------- run-time errors
def r_elem6():
    def rt(name, comment, body, marker, msg, out='', nth=0):
        C.err_r(name, comment, body, marker, msg, out=out.encode(), nth=nth)

    rt('r_elem6_error_vector',
       ['error() in an elemental body: the first failing element in increasing linear order (LANGUAGE.md 8.5):',
        'the elements 3, 4 and 5 fail the test, 3 is the first, at the error call\'s line in the callee'],
       r'''elemental fn gate(x: f64) -> f64 {
    if x > 2.5 {
        error("too large: %g", x)
    }
    return x * 2.0
}
let v = [1.0, 2.0, 3.0, 4.0, 5.0]
printf("start\n")
let r = gate(v)
printf("unreachable\n")
''', 'error("too large', 'too large: 3', 'start\n')
    rt('r_elem6_error_matrix_order',
       ['the first failing element is the first in column-major (linear) order (LANGUAGE.md 8.5, 4.5): in',
        '[1, 2; 3, 4; 5, 6] the elements above 1.5 are 3, 5, 2, 4, 6 in that order, so 3 fails (a row-major scan',
        'would meet 2)'],
       r'''elemental fn gate(x: f64) -> f64 {
    if x > 1.5 {
        error("bad %g", x)
    }
    return x
}
let A = [1.0, 2.0; 3.0, 4.0; 5.0, 6.0]
let R = gate(A)
''', 'error("bad', 'bad 3')
    rt('r_elem6_error_broadcast_order',
       ['the first failing element of a .col/.row broadcast is in column-major order (LANGUAGE.md 8.5, 6.3): the',
        'products x * y are 10, 20 (x = 2, y = 10), 20 (x = 1, y = 20), ...; the test x * y == 20 first holds at',
        '(1, 0), x = 2 and y = 10; a row-major scan would meet x = 1 and y = 20'],
       r'''elemental fn gate(x: f64, y: f64) -> f64 {
    if x * y == 20.0 {
        error("bad %g %g", x, y)
    }
    return x * y
}
let a = [1.0, 2.0]
let b = [10.0, 20.0, 30.0]
let R = gate(a.col, b.row)
''', 'error("bad', 'bad 2 10')
    rt('r_elem6_oob_index',
       ['an out-of-bounds index inside the body at a known element (LANGUAGE.md 5.4, 8.5): i = [0, 1, 7, 9] into a',
        '3-element table; element 2 fails first: index 7, at the callee\'s line'],
       r'''elemental fn pick(i: i64, tbl: f64[]) -> f64 {
    return tbl[i] * 2.0
}
let tbl = [1.0, 2.0, 3.0]
printf("start\n")
let r = pick([0, 1, 7, 9], tbl)
printf("unreachable\n")
''', 'return tbl[i]', 'index 7 out of bounds for dimension 0 of extent 3', 'start\n')
    rt('r_elem6_scalar_call',
       ['a scalar call of an elemental function is an ordinary call: the error is at the callee\'s line (LANGUAGE.md',
        '8.5, 9.3)'],
       r'''elemental fn gate(x: f64) -> f64 {
    if x > 2.5 {
        error("too large: %g", x)
    }
    return x
}
printf("%g\n", gate(1.0))
printf("%g\n", gate(3.5))
''', 'error("too large', 'too large: 3.5', '1\n')
    rt('r_elem6_nested',
       ['an error in an elemental function called by another elemental function is at the inner function\'s line',
        '(LANGUAGE.md 8.5; DESIGN.md 3.6.4 "Sites"); element 1 of [1, 3] fails'],
       r'''elemental fn inner(x: f64) -> f64 {
    if x > 2.0 {
        error("inner %g", x)
    }
    return x
}
elemental fn outer(x: f64) -> f64 {
    return inner(x) + 1.0
}
let r = outer([1.0, 3.0])
''', 'error("inner', 'inner 3')
    rt('r_elem6_shape_vectors',
       ['two dynamic vector arguments of 3 and 4 elements: shape mismatch 3 vs 4 at the call\'s line (LANGUAGE.md',
        '6.3, 8.5)'],
       r'''elemental fn add(x: f64, y: f64) -> f64 {
    return x + y
}
let x = zeros(3)
let y = zeros(4)
printf("start\n")
let r = add(x, y)
printf("unreachable\n")
''', 'let r = add', 'shape mismatch: 3 vs 4', 'start\n')
    rt('r_elem6_shape_matrices',
       ['dynamic 3 x 4 and 3 x 5 matrices: per dimension 3 = 3 and 4 vs 5 (neither is 1), shape mismatch 3x4 vs 3x5',
        'at the call\'s line (LANGUAGE.md 6.3)'],
       r'''elemental fn add(x: f64, y: f64) -> f64 {
    return x + y
}
let A = zeros(3, 4)
let B = zeros(3, 5)
let r = add(A, B)
''', 'let r = add', 'shape mismatch: 3x4 vs 3x5')
    rt('r_elem6_shape_three',
       ['three dynamic vectors of 5, 5 and 2: the shapes combine left to right and the mismatch reports the shape',
        'combined so far, then the operand\'s: 5 vs 2 (LANGUAGE.md 6.3)'],
       r'''elemental fn fma3(a: f64, b: f64, c: f64) -> f64 {
    return a * b + c
}
let a = zeros(5)
let b = zeros(5)
let c = zeros(2)
let r = fma3(a, b, c)
''', 'let r = fma3', 'shape mismatch: 5 vs 2')
    rt('r_elem6_shape_scalar_skipped',
       ['scalars are skipped when the shapes combine (LANGUAGE.md 6.3): a vector of 3, a scalar and a vector of 4',
        'report 3 vs 4'],
       r'''elemental fn fma3(a: f64, b: f64, c: f64) -> f64 {
    return a * b + c
}
let a = zeros(3)
let c = zeros(4)
let r = fma3(a, 2.0, c)
''', 'let r = fma3', 'shape mismatch: 3 vs 4')
    rt('r_elem6_shape_before_elements',
       ['the broadcast extents and their shape check come before any element is computed (DESIGN.md 2.11.4 L19 step',
        '2): the body would fail at its first element, but the program reports the shape mismatch 3 vs 2'],
       r'''elemental fn always(x: f64, y: f64) -> f64 {
    error("body ran")
    return x
}
let x = zeros(3)
let y = zeros(2)
let r = always(x, y)
''', 'let r = always', 'shape mismatch: 3 vs 2')
    rt('r_elem6_args_before_elements',
       ['the arguments are evaluated in full, in order, before any element (DESIGN.md 2.11.4 L19 step 1, L-ck): the',
        'second argument\'s index error (the call\'s line) is reported, not the body\'s error'],
       r'''elemental fn always(x: f64, y: f64) -> f64 {
    error("body ran")
    return x
}
let v = zeros(3)
let w = zeros(3)
let r = always(v, w[10])
''', 'let r = always', 'index 10 out of bounds for dimension 0 of extent 3')
    rt('r_elem6_discard_all_error',
       ['an elemental call whose every result is discarded still runs for its errors (DESIGN.md 2.11.4 L19 step 3,',
        'Decision 84): the first failing element, 2, at the error call\'s line'],
       r'''elemental fn two(x: f64) -> (f64, f64) {
    if x > 1.5 {
        error("two %g", x)
    }
    return (x, x)
}
printf("start\n")
let (_, _) = two([1.0, 2.0, 3.0])
printf("unreachable\n")
''', 'error("two', 'two 2', 'start\n')
    rt('r_elem6_eval_error',
       ['an elemental call used as a statement runs for its errors (LANGUAGE.md 7.1, 8.5): the first failing',
        'element, 3, at the error call\'s line'],
       r'''elemental fn gate(x: f64) -> f64 {
    if x > 2.5 {
        error("too large: %g", x)
    }
    return x
}
printf("start\n")
gate([1.0, 2.0, 3.0, 4.0])
printf("unreachable\n")
''', 'error("too large', 'too large: 3', 'start\n')
    rt('r_elem6_ind2sub_eval_zero',
       ['ind2sub with an array r holding a 0, used as a call statement: the call still runs for its errors (LANGUAGE.md',
        '6.6, 7.1, 10.7; DESIGN.md 2.11.4 L19, Decision 84): integer division by zero at the call\'s line'],
       r'''let r = [3, 4, 0]
let k = [7, 10, 24]
printf("start\n")
ind2sub(r, k)
printf("unreachable\n")
''', 'ind2sub(r', 'integer division by zero', 'start\n')
    rt('r_elem6_mixed_dynamic',
       ['a fixed and a dynamic argument give a dynamic result (LANGUAGE.md 4.5, 8.5; DESIGN.md 2.11.2 "Elemental',
        'calls"): bound to f64[4] the 3-element result passes the run-time shape check and fails it, `expected 4,',
        'got 3`, at the line of the binding (a fixed result would be a compile error: err_elem6_fixed_result)'],
       r'''elemental fn add(x: f64, y: f64) -> f64 {
    return x + y
}
let a = [1.0, 2.0, 3.0]
let d = zeros(3)
let r: f64[4] = add(a, d)
''', 'let r: f64[4]', 'shape mismatch: expected 4, got 3')
    rt('r_elem6_tuple_target',
       ['an error in the body while the results are bound by a tuple assignment into selection targets (LANGUAGE.md',
        '7.3, 8.5): nothing is stored, the callee\'s line is reported; earlier output is flushed'],
       r'''elemental fn three(x: f64) -> (f64, f64, f64) {
    if x > 0.75 {
        error("three %g", x)
    }
    return (x, x, x)
}
var A = zeros(2, 3)
var B = zeros(2, 3)
printf("start\n")
(A[0, :], B[1, :], _) = three([0.5, 1.0, 1.5])
printf("unreachable\n")
''', 'error("three', 'three 1', 'start\n')


# ---------------------------------------------------------------------------- compile errors
def err_c(name, comment, body, line_marker, col_text, msg, nth=0, col_off=0):
    C.err_c(name, comment, body, line_marker, col_text, msg, nth, col_off)


# The earlier error of the other program of pass 2a, for the `_after` tests: a seacheck error (a body or constant
# error) before a seaname error, and a seaname error (a signature or call pre-pass error) before a seacheck error.
EARLY_CHECK = 'let early: i64 = 1.5\n'
EARLY_MARKER = 'let early'
EARLY_CHECK_MSG = 'type mismatch: expected i64, found f64'


def err_elem6():
    sqf = SQ
    add = r'''elemental fn add(x: f64, y: f64) -> f64 {
    return x + y
}
'''
    fma3 = r'''elemental fn fma3(a: f64, b: f64, c: f64) -> f64 {
    return a * b + c
}
'''

    # ---- seaname's errors (228 and 232, 253): the `_after` test puts a seacheck error first
    def seaname_case(name, comment, body, marker, col_text, msg, nth=0):
        err_c(name, comment, body, marker, col_text, msg, nth)
        err_c(name + '_after',
              comment[:1] + ['the same program with an earlier error of seacheck (the first statement, `let early: i64 = 1.5`):',
                             'in source order the earlier one is reported (DESIGN.md 2.6.2 "Order across the two programs", L-cq)'],
              EARLY_CHECK + body, EARLY_MARKER, '1.5', EARLY_CHECK_MSG, 0)

    seaname_case('err_elem6_228_ref',
                 ['228 at a ref parameter of an elemental function, at the param node (its ref keyword); the signature',
                  'step of seaname (LANGUAGE.md 8.1, 8.5; DESIGN.md 2.11.2 L-cq)'],
                 r'''elemental fn bump(ref x: f64) -> f64 {
    return x
}
''', 'elemental fn bump', 'ref x', 'effects in elemental function')
    seaname_case('err_elem6_228_printf',
                 ['228 at a printf inside an elemental body: the call that has effects (LANGUAGE.md 8.1, 8.5; DESIGN.md',
                  '2.11.2 L-cq, the call pre-pass of seaname)'],
                 r'''elemental fn noisy(x: f64) -> f64 {
    printf("%g\n", x)
    return x
}
''', 'printf(', 'printf', 'effects in elemental function')
    seaname_case('err_elem6_228_call',
                 ['228 at a call of a function with effects inside an elemental body; two such calls, the first in source',
                  'order is reported (DESIGN.md 2.11.2 L-cq)'],
                 r'''fn report(x: f64) {
    printf("%g\n", x)
}
elemental fn noisy(x: f64) -> f64 {
    report(x)
    report(x + 1.0)
    return x
}
''', 'report(x)', 'report', 'effects in elemental function')
    seaname_case('err_elem6_228_transitive',
                 ['228 at a call of a function that calls a function with effects (transitive: LANGUAGE.md 8.1 "or calls a',
                  'function with effects"; DESIGN.md 2.11.2 L-cq, a fixpoint over the call graph): mid has effects through deep'],
                 r'''fn deep(x: f64) {
    printf("%g\n", x)
}
fn mid(x: f64) -> f64 {
    deep(x)
    return x
}
elemental fn top(x: f64) -> f64 {
    return mid(x) + 1.0
}
''', 'return mid(x)', 'mid', 'effects in elemental function')
    seaname_case('err_elem6_232_direct',
                 ['232 at the first call, in source order, of an elemental function to itself (LANGUAGE.md 8.5; DESIGN.md',
                  '2.11.2 L-cq): the call on line 4, not the one on line 6'],
                 r'''elemental fn f(x: f64) -> f64 {
    if x > 0.0 {
        return f(x - 1.0)
    }
    return f(x + 1.0)
}
''', 'return f(x - 1.0)', 'f(x - 1.0)', 'elemental function cannot be recursive')
    seaname_case('err_elem6_232_mutual',
                 ['232 for a cycle through an elemental function, mutual: the ordinary function b calls the elemental a, and',
                  'a calls b; the first call in source order on the cycle is b\'s call of a (DESIGN.md 2.11.2 L-cq)'],
                 r'''fn b(x: f64) -> f64 {
    return a(x - 1.0)
}
elemental fn a(x: f64) -> f64 {
    return b(x)
}
''', 'return a(x - 1.0)', 'a(x - 1.0)', 'elemental function cannot be recursive')
    seaname_case('err_elem6_253_str',
                 ['253 at the fn item (its first token, `elemental`) for a str result (LANGUAGE.md 8.5; DESIGN.md 2.11.2',
                  'L-cq: the signature step)'],
                 r'''elemental fn name(x: f64) -> str {
    return "a"
}
''', 'elemental fn name', 'elemental', 'elemental function result must be f64, i64 or bool')
    err_c('err_elem6_253_array',
          ['253 for an array result: results must be scalars (LANGUAGE.md 8.5), at the fn item'],
          r'''elemental fn name(x: f64) -> f64[] {
    return [x, x]
}
''', 'elemental fn name', 'elemental', 'elemental function result must be f64, i64 or bool')
    err_c('err_elem6_253_tuple',
          ['253 for a tuple with a str component (LANGUAGE.md 8.5), at the fn item'],
          r'''elemental fn name(x: f64) -> (f64, str) {
    return (x, "a")
}
''', 'elemental fn name', 'elemental', 'elemental function result must be f64, i64 or bool')

    # ---- ordering at one position: the pre-pass's 228 and 232 are found before seacheck's error at the same call
    err_c('err_elem6_228_same_pos',
          ['228 and seacheck\'s `missing argument` (226) stand at one call: the pre-pass is the first check a single',
           'program makes at a call node, so 228 is reported (DESIGN.md 2.11.2 L-cq)'],
          r'''fn report(a: f64) {
    printf("%g\n", a)
}
elemental fn noisy(x: f64) -> f64 {
    report()
    return x
}
''', 'report()', 'report', 'effects in elemental function')
    err_c('err_elem6_232_same_pos',
          ['232 and seacheck\'s `missing argument` (226) stand at one call: 232 is reported (DESIGN.md 2.11.2 L-cq)'],
          r'''elemental fn f(x: f64, y: f64) -> f64 {
    return f(x)
}
''', 'return f(x)', 'f(x)', 'elemental function cannot be recursive')

    # ---- seacheck's errors (202, 217, 201): the `_after` test puts a seaname error first
    def seacheck_case(name, comment, body, marker, col_text, msg, early, early_marker, early_col, early_msg, nth=0):
        err_c(name, comment, body, marker, col_text, msg, nth)
        err_c(name + '_after',
              comment[:1] + ['the same program after an earlier error of seaname (line 2, found in the signature step):',
                             'in source order the earlier one is reported (DESIGN.md 2.6.2 "Order across the two programs", L-cq)'],
              early + body, early_marker, early_col, early_msg, 0)

    E253 = 'elemental fn early(x: f64) -> str {\n    return "a"\n}\n'
    E236 = 'fn early(a: i64 = 1, b: i64) -> i64 {\n    return a + b\n}\n'
    E228 = 'elemental fn early(ref x: f64) -> f64 {\n    return x\n}\n'
    seacheck_case('err_elem6_202',
                  ['202 for a vector and a matrix elemental argument, at the call (LANGUAGE.md 6.3, 8.5; DESIGN.md 2.11.2',
                   '"Elemental calls")'],
                  add + r'''let v = zeros(3)
let A = zeros(3, 3)
let w = add(v, A)
''', 'let w = add', 'add', 'cannot combine a vector with a matrix: use .col or .row',
                  E253, 'elemental fn early', 'elemental', 'elemental function result must be f64, i64 or bool')
    seacheck_case('err_elem6_217',
                  ['217 for two fixed-size vectors of 3 and 2 elements with a scalar between them (scalars are skipped):',
                   'a mismatch of compile-time extents, at the call (LANGUAGE.md 6.3, 4.10; DESIGN.md 3.5.5 "Static shapes")'],
                  fma3 + r'''let w = fma3([1.0, 2.0, 3.0], 2.0, [1.0, 2.0])
''', 'let w = fma3', 'fma3', 'shape mismatch: 3 vs 2',
                  E236, 'fn early', 'b: i64', 'parameter needs a default value')
    err_c('err_elem6_217_matrix',
          ['217 for fixed-size matrices of 2 x 2 and 2 x 3: per dimension 2 = 2 and 2 vs 3 (neither is 1), at the call',
           '(LANGUAGE.md 6.3)'],
          add + r'''let w = add([1.0, 2.0; 3.0, 4.0], [1.0, 2.0, 3.0; 4.0, 5.0, 6.0])
''', 'let w = add', 'add', 'shape mismatch: 2x2 vs 2x3')
    err_c('err_elem6_fixed_result',
          ['two fixed-size arguments give a fixed-size result (DESIGN.md 2.11.2 "Elemental calls"): bound to f64[4] the',
           '3-element result is the static shape mismatch 4 vs 3 (the target\'s shape first, LANGUAGE.md 4.10), at the',
           'value (the call)'],
          add + r'''let r: f64[4] = add([1.0, 2.0, 3.0], [1.0, 2.0, 3.0])
''', 'let r: f64[4]', 'add', 'shape mismatch: 4 vs 3')
    seacheck_case('err_elem6_201',
                  ['201 at an argument: a str for an elemental f64 parameter (LANGUAGE.md 4.2, 8.5), at the argument'],
                  sqf + r'''let r = sq("abc")
''', 'let r = sq', '"abc"', 'type mismatch: expected f64, found str',
                  E228, 'elemental fn early', 'ref x', 'effects in elemental function')
    err_c('err_elem6_201_bool_array',
          ['201 at an argument: a bool array is not converted to f64 (LANGUAGE.md 4.2: bool converts to neither',
           'implicitly), at the argument'],
          sqf + r'''let r = sq([true, false])
''', 'let r = sq', '[true', 'type mismatch: expected f64, found bool[2]')
    err_c('err_elem6_201_f64_to_i64',
          ['201 at an argument: an f64 array for an i64 elemental parameter (LANGUAGE.md 4.2: no implicit f64 to i64)'],
          r'''elemental fn cube(i: i64) -> i64 {
    return i * i * i
}
let v = zeros(3)
let r = cube(v)
''', 'let r = cube', 'v)', 'type mismatch: expected i64, found f64[]', 0, 0)
    err_c('err_elem6_201_uniform',
          ['201 at an argument of a uniform parameter: an f64 scalar for an f64[] table, uniform parameters are passed',
           'unchanged (LANGUAGE.md 8.5), at the argument'],
          r'''elemental fn pick(i: i64, tbl: f64[]) -> f64 {
    return tbl[i]
}
let r = pick([0, 1, 2], 3.0)
''', 'let r = pick', '3.0', 'type mismatch: expected f64[], found f64')


# ---------------------------------------------------------------------------- the re-derived and retired goldens
def merge_same_pos():
    # DESIGN.md 6.2 "Existing tests that phase 6 changes": the function's result type is str, so 253 (seaname, at
    # the fn item, line 2 column 1) and `missing return` (seacheck, at the same fn) stand at one position and 253 wins
    src = C.source('err_merge_same_pos',
                   ['two errors at one fn item: seaname\'s 253 (a str result, found in the signature step) is found before seacheck\'s missing return (DESIGN.md 2.6.2, 3.4.1 rerr)'],
                   r'''elemental fn f(x: f64) -> str {
    if x > 0.0 {
        return "a"
    }
}
''')
    ln = C.line_of(src, 'elemental fn f')
    base = os.path.join(ERRORS, 'err_merge_same_pos')
    C.wbytes(base + '.sea', src)
    C.wbytes(base + '.err', 'err_merge_same_pos.sea:%d:1: error: elemental function result must be f64, i64 or bool\n' % ln)
    C.wbytes(base + '.status', '1\n')


def retire():
    for name in ('err_ns_elemental', 'err_ns_ind2sub_array'):
        for ext in ('.sea', '.err', '.status'):
            C.remove(os.path.join(ERRORS, name + ext))


def main():
    retire()
    merge_same_pos()
    elem_scalar()
    elem_vector()
    elem_matrix()
    elem_broadcast()
    elem_fixed()
    elem_i64_to_f64()
    elem_uniform()
    elem_results()
    elem_tuple_assign()
    elem_eval()
    elem_nested()
    elem_calls_recursive()
    elem_named_default()
    elem_empty()
    elem_noresult()
    elem_bisect()
    elem_expr()
    ind2sub_arr()
    r_elem6()
    err_elem6()
    print('elem6_cases: %d programs, %d errors written; err_merge_same_pos re-derived, 2 goldens retired'
          % (COUNT['programs'], COUNT['errors']))


if __name__ == '__main__':
    main()
