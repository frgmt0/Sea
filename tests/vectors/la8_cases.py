"""Sub-phase 8b (work package T1, the `@` part): the programs and error tests of the matrix product.

DESIGN.md 2.13.8 ("8b, `@`"), 2.13.2 (exactness, empty and non-finite operands, run-time errors,
arguments and results), 2.13.3 (217, `cvt`, `dyn`), 2.13.4 (L21, R35), 2.13.5 (entries 51-53),
2.13.6 (GEMV, VECMAT, MATMUL), lead decisions L-ij, L-iq, L-iv, L-iw, L-iz; LANGUAGE.md 6.2, 6.8,
9.1, 9.2, 10.5, 10.8, 11.1.

Run (never `python3`; write into a scratch copy of tests/, never into the repo tree by hand):

    timeout 120 uv run --no-project python tests/vectors/la8_cases.py
        writes programs/la_{mv,vm,mm}_*.{sea,out}, errors/r_la_m{m,v}_shape and r_la_vm_shape
        (.sea .err .out .status), errors/err_la_{mm,mv}_static (.sea .err .status), and deletes the
        retired errors/err_ns_matmul.{sea,err,status} (DESIGN.md 2.13.3: `@` leaves the phase rule in
        8b, and no new test names a removed word, 6.2)
    timeout 120 uv run --no-project python tests/vectors/la8_cases.py --check
        regenerates everything in memory and compares it with the files on disk (exit 0 and
        "la8_cases: N files ok", else exit 1 and each difference); also requires the retired
        err_ns_matmul files to be absent

The 8c part (RCOND and eig, with the one-time SciPy check of 2.13.8) is added to this script by 8c's
T1; nothing here depends on it.

HOW EVERY EXPECTED BYTE IS DERIVED (never from a run of the compiler or of the runtime):

* Class E (LANGUAGE.md 6.8, 10.8; DESIGN.md 2.13.2). The three pinned orders are transcribed into
  Python `float` (IEEE binary64, round to nearest even; Python's `+ - * /` on floats are exactly the
  IEEE operations, and the builtin `sum` -- compensated since Python 3.12 -- is never used):
    - matrix @ vector, `gemv`: y[i] = A[i,0]*x[0], then y[i] = y[i] + A[i,j]*x[j], j ascending;
      the first term is the product itself (a row of -0 products gives -0); k = 0 gives +0;
    - vector @ matrix, `vecmat`: for each column j the pinned 8-lane sum of LANGUAGE.md 10.5
      (`sum8`: accumulators from -0.0, lane kk % 8, the final tree
      ((a0 + a1) + (a2 + a3)) + ((a4 + a5) + (a6 + a7))) over the rounded products x[kk]*A[kk,j];
      k = 0 gives +0 (the empty sum);
    - fixed-size matrix @ matrix, `matmul_e` (L21, Decision 125 (a)): c[i,j] = a[i,0]*b[0,j], then
      c[i,j] = c[i,j] + a[i,kk]*b[kk,j], kk ascending; k = 0 gives +0.
  `@` of two fixed-size operands is class E at every extent (L21: matrix @ vector and vector @
  matrix use the same orders as GEMV and VECMAT), so its results are printed raw with `%.17g`,
  the sign of a zero included. Every order-sensitive program asserts here that its data makes
  the pinned order differ from another order (a reversed or sequential sum) somewhere, so the test
  can tell the orders apart.
* Class R (matrix @ matrix with a dynamic operand, GEMM; DESIGN.md 2.13.2, 2.13.8): exact data
  only -- small integers, so every product and partial sum is an exact integer in every order and
  variant (Baysick DESIGN.md 6.6.4 rule 3), computed here in Python integers. The sign of a zero
  result of GEMM is unspecified (Baysick 6.6.4), so class-R results are printed as `x + 0.0`
  (-0 + 0.0 is +0 and every other value is unchanged), except the zeros of an empty inner extent,
  which no kernel computes (2.13.2 "Empty operands": +0, printed raw). `la_mm_nonfinite` uses only
  Baysick's rules 1 and 2 (a NaN term, or terms +inf and -inf: NaN; else an infinite term with the
  finite terms' magnitudes summing to at most 2^1023: that infinity), classified here exactly.
* Data built inside a program (helpers `mkq`, `vq`, `mki`, `vi` and fixed-size fills) is mirrored
  here by the same expressions: `f64` of an exact small `i64` (exact) and one correctly rounded
  division per element; `%` on non-negative `i64` is the floored modulo, as Python's `%`.
* Conversions (L-iq; LANGUAGE.md 4.2): an `i64` operand is converted element by element, rounding
  to nearest, ties to even (Python's `float(int)` does exactly that: 9007199254740993 -> 2^53).
* Printing (LANGUAGE.md 11.1) through the exact oracle tests/vectors/progfmt.py (`%.17g`, `%d`;
  NaN, Inf, -Inf, -0), never through Python's `%`.
* Errors: run-time `shape mismatch: %s vs %s` (LANGUAGE.md 9.2; code 2) with the operands' shapes in
  source order written as `RxC` and `N` (L-ij), at the line of the `@` (the call's site, L-iv),
  standard output flushed first (the `start` line), status 1; compile-time 217 `shape mismatch:
  %s vs %s` (DESIGN.md 2.6.2, `at` expr) when both operands are fixed-size, at the operator node,
  which stands at its left operand (DESIGN.md 3.3), status 1 (LANGUAGE.md 9.1). Line and column come
  from a marker in the source text.
"""

import math
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import progfmt  # noqa: E402  (the exact printf oracle; LANGUAGE.md 11.1)

TESTS = os.path.dirname(HERE)
PROGRAMS = os.path.join(TESTS, 'programs')
ERRORS = os.path.join(TESTS, 'errors')
RETIRED = [os.path.join(ERRORS, 'err_ns_matmul.' + x) for x in ('sea', 'err', 'status')]

OUT = {}        # path -> bytes, in generation order
NEG0 = -0.0
INF = float('inf')
NAN = float('nan')


# ============================================================ helpers: bits, printing, literals
def f2b(x):
    return struct.unpack('<Q', struct.pack('<d', x))[0]


def g17(x):
    return progfmt.format_all('%.17g', [('f', f2b(x))]).decode()


def lit(x):
    """A Sea expression denoting exactly the f64 x (LANGUAGE.md 3.4; inf and nan of 10.1)."""
    if x != x:
        return 'nan'
    if x == INF:
        return 'inf'
    if x == -INF:
        return '-inf'
    if x == 0.0:
        return '-0.0' if f2b(x) >> 63 else '0.0'
    t = repr(abs(x))
    if 'e' not in t and '.' not in t:
        t += '.0'
    assert float(t) == abs(x)
    return ('-' if x < 0 else '') + t


def mat_lit(A):
    """A matrix literal (rows separated by `;`): f64[r,c] when it has at most 256 elements. One row of
    scalars is a vector (LANGUAGE.md 6.9), so a one-row matrix is written as that vector's `.row` view
    (5.6: a 1 x n matrix)."""
    if len(A) == 1:
        return vec_lit(A[0]) + '.row'
    return '[' + '; '.join(', '.join(lit(v) for v in row) for row in A) + ']'


def vec_lit(v):
    return '[' + ', '.join(lit(x) for x in v) + ']'


def zero_norm(x):
    """`x + 0.0` in binary64: the printed form of a class-R result (see the module docstring)."""
    return x + 0.0


def pv_line(v):
    """The line Sea's helper pv prints: `N:` then ` %.17g` per element."""
    return '%d:%s\n' % (len(v), ''.join(' ' + g17(x) for x in v))


def pm_line(M, r, c):
    """The line Sea's helper pm prints: `RxC:` then, row by row, ` %.17g` per element and ` |`."""
    s = '%dx%d:' % (r, c)
    for i in range(r):
        for j in range(c):
            s += ' ' + g17(M[i][j])
        s += ' |'
    return s + '\n'


def zm(M):
    return [[zero_norm(v) for v in row] for row in M]


# ============================================================ the pinned orders (2.13.2)
def gemv(A, x):
    """matrix @ vector: A a list of r rows of k elements."""
    k = len(x)
    y = []
    for row in A:
        assert len(row) == k
        if k == 0:
            y.append(0.0)
            continue
        s = row[0] * x[0]
        for j in range(1, k):
            p = row[j] * x[j]
            s = s + p
        y.append(s)
    return y


def sum8(vals):
    """LANGUAGE.md 10.5's pinned 8-lane sum of a non-empty list; +0 for an empty one."""
    if not vals:
        return 0.0
    a = [NEG0] * 8
    for i, v in enumerate(vals):
        a[i % 8] = a[i % 8] + v
    return ((a[0] + a[1]) + (a[2] + a[3])) + ((a[4] + a[5]) + (a[6] + a[7]))


def vecmat(x, A):
    """vector @ matrix: A a list of k rows of c elements."""
    k = len(x)
    assert len(A) == k
    c = len(A[0]) if k else None
    return c, [sum8([x[kk] * A[kk][j] for kk in range(k)]) for j in range(c)]


def vecmat_c(x, A, c):
    """vecmat with the column count given (k may be 0)."""
    return [sum8([x[kk] * A[kk][j] for kk in range(len(x))]) for j in range(c)]


def matmul_e(A, B, r, k, c):
    """fixed-size matrix @ matrix, L21's chain."""
    C = []
    for i in range(r):
        row = []
        for j in range(c):
            if k == 0:
                row.append(0.0)
                continue
            s = A[i][0] * B[0][j]
            for kk in range(1, k):
                p = A[i][kk] * B[kk][j]
                s = s + p
            row.append(s)
        C.append(row)
    return C


def gemv_reversed(A, x):
    """another order (j descending), only to show that a test's data tells the orders apart"""
    y = []
    for row in A:
        k = len(row)
        s = row[k - 1] * x[k - 1]
        for j in range(k - 2, -1, -1):
            s = s + row[j] * x[j]
        y.append(s)
    return y


def seq_sum(vals):
    s = vals[0]
    for v in vals[1:]:
        s = s + v
    return s


def matmul_exact(A, B, r, k, c):
    """exact integer product (class R on exact data), as floats"""
    return [[float(sum_int(int(A[i][kk]) * int(B[kk][j]) for kk in range(k))) for j in range(c)] for i in range(r)]


def sum_int(it):
    t = 0
    for v in it:
        t += v
    return t


# ============================================================ in-program data (mirrors)
SEA_HELPERS = {
    'pv': '''fn pv(v: f64[]) {
    printf("%d:", len(v))
    for x in v {
        printf(" %.17g", x)
    }
    printf("\\n")
}''',
    'pvz': '''fn pvz(v: f64[]) {
    printf("%d:", len(v))
    for x in v {
        printf(" %.17g", x + 0.0)
    }
    printf("\\n")
}''',
    'pm': '''fn pm(M: f64[,]) {
    printf("%dx%d:", rows(M), cols(M))
    for i in 0..rows(M) {
        for j in 0..cols(M) {
            printf(" %.17g", M[i, j])
        }
        printf(" |")
    }
    printf("\\n")
}''',
    'pmz': '''fn pmz(M: f64[,]) {
    printf("%dx%d:", rows(M), cols(M))
    for i in 0..rows(M) {
        for j in 0..cols(M) {
            printf(" %.17g", M[i, j] + 0.0)
        }
        printf(" |")
    }
    printf("\\n")
}''',
    'mkq': '''fn mkq(r: i64, c: i64, s: i64) -> f64[,] {
    var A = zeros(r, c)
    for i in 0..r {
        for j in 0..c {
            A[i, j] = f64((i * 7 + j * 3 + s) % 11 - 5) / f64(i + 2 * j + s + 3)
        }
    }
    return A
}''',
    'vq': '''fn vq(n: i64, s: i64) -> f64[] {
    var v = zeros(n)
    for i in 0..n {
        v[i] = f64((i * 5 + s) % 9 - 4) / f64(i + s + 7)
    }
    return v
}''',
    'mki': '''fn mki(r: i64, c: i64, s: i64) -> f64[,] {
    var A = zeros(r, c)
    for i in 0..r {
        for j in 0..c {
            A[i, j] = f64((i * 3 + j * 5 + s) % 7 - 3)
        }
    }
    return A
}''',
    'vi': '''fn vi(n: i64, s: i64) -> f64[] {
    var v = zeros(n)
    for i in 0..n {
        v[i] = f64((i * 2 + s) % 5 - 2)
    }
    return v
}''',
}


def mkq(r, c, s):
    return [[float((i * 7 + j * 3 + s) % 11 - 5) / float(i + 2 * j + s + 3) for j in range(c)] for i in range(r)]


def vq(n, s):
    return [float((i * 5 + s) % 9 - 4) / float(i + s + 7) for i in range(n)]


def mki(r, c, s):
    return [[float((i * 3 + j * 5 + s) % 7 - 3) for j in range(c)] for i in range(r)]


def vi(n, s):
    return [float((i * 2 + s) % 5 - 2) for i in range(n)]


def transpose(A, r, c):
    return [[A[i][j] for i in range(r)] for j in range(c)]


def fixed_fill_q(name, r, c, s):
    """Sea lines filling a fixed-size f64[r,c] variable with mkq's formula (same values as mkq)."""
    return ['var %s: f64[%d,%d] = zeros(%d, %d)' % (name, r, c, r, c),
            'for i in 0..%d {' % r,
            '    for j in 0..%d {' % c,
            '        %s[i, j] = f64((i * 7 + j * 3 + %d) %% 11 - 5) / f64(i + 2 * j + %d + 3)' % (name, s, s),
            '    }',
            '}']


def fixed_fill_vq(name, n, s):
    return ['var %s: f64[%d] = zeros(%d)' % (name, n, n),
            'for i in 0..%d {' % n,
            '    %s[i] = f64((i * 5 + %d) %% 9 - 4) / f64(i + %d + 7)' % (name, s, s),
            '}']


def fixed_fill_i(name, r, c, s):
    return ['var %s: f64[%d,%d] = zeros(%d, %d)' % (name, r, c, r, c),
            'for i in 0..%d {' % r,
            '    for j in 0..%d {' % c,
            '        %s[i, j] = f64((i * 3 + j * 5 + %d) %% 7 - 3)' % (name, s),
            '    }',
            '}']


# ============================================================ writing
def emit(path, data):
    if isinstance(data, str):
        data = data.encode('ascii')
    assert path not in OUT, path
    OUT[path] = data


def header(name, lines):
    out = '// %s -- %s\n' % (name, lines[0])
    for ln in lines[1:]:
        out += '// ' + ln + '\n'
    return out


def program(name, comment, helpers, body_lines, expected):
    src = header(name, comment)
    for h in helpers:
        src += SEA_HELPERS[h] + '\n'
    src += '\n'.join(body_lines) + '\n'
    emit(os.path.join(PROGRAMS, name + '.sea'), src)
    emit(os.path.join(PROGRAMS, name + '.out'), ''.join(expected))


def locate(src, marker, col_text):
    """1-based line of the line holding marker, and column of col_text inside that line"""
    lines = src.split('\n')
    hits = [i for i, ln in enumerate(lines) if marker in ln]
    assert len(hits) == 1, (marker, hits)
    ln = lines[hits[0]]
    col = ln.index(col_text) + 1
    return hits[0] + 1, col


def err_runtime(name, comment, body, marker, msg, out):
    src = header(name, comment) + body
    line, _ = locate(src, marker, marker)
    emit(os.path.join(ERRORS, name + '.sea'), src)
    emit(os.path.join(ERRORS, name + '.err'), '%s.sea:%d: error: %s\n' % (name, line, msg))
    emit(os.path.join(ERRORS, name + '.status'), '1\n')
    emit(os.path.join(ERRORS, name + '.out'), out)


def err_compile(name, comment, body, marker, col_text, msg):
    src = header(name, comment) + body
    line, col = locate(src, marker, col_text)
    emit(os.path.join(ERRORS, name + '.sea'), src)
    emit(os.path.join(ERRORS, name + '.err'), '%s.sea:%d:%d: error: %s\n' % (name, line, col, msg))
    emit(os.path.join(ERRORS, name + '.status'), '1\n')


# ============================================================ matrix @ vector
def la_mv_order():
    A = [[1e16, 1.0, -1e16], [1.0, 1e16, -1e16], [1e16, -1e16, 1.0], [0.1, 0.2, 0.3], [1.0, 1e16, 1.0]]
    x = [1.0, 1.0, 1.0]
    y1 = gemv(A, x)
    # 2.13.8: pinned value 0 (the exact sum is 1; (1e16 + -1e16) + 1, another order, is 1)
    assert y1[0] == 0.0 and (A[0][0] * x[0] + A[0][2] * x[2]) + A[0][1] * x[1] == 1.0
    Q = mkq(7, 9, 2)
    xq = vq(9, 1)
    y2 = gemv(Q, xq)
    assert y2 != gemv_reversed(Q, xq)
    body = ['let A: f64[,] = ' + mat_lit(A),
            'let x: f64[] = ' + vec_lit(x),
            'pv(A @ x)',
            'let Q = mkq(7, 9, 2)',
            'let xq = vq(9, 1)',
            'pv(Q @ xq)',
            'let y = Q @ xq',
            'printf("%.17g %.17g\\n", y[0], y[6])']
    program('la_mv_order',
            ['matrix @ vector in the pinned order (LANGUAGE.md 10.8, DESIGN.md 2.13.2, 2.13.6 GEMV): rows whose',
             'reassociated sum differs, A[0,:] = [1e16, 1, -1e16] with x = [1, 1, 1] giving 0 (the exact sum and',
             '(1e16 - 1e16) + 1 are 1), 0.1 + 0.2 + 0.3, and a 7 x 9 matrix of rounded quotients against a 9-vector',
             '(the reversed order differs there; class E, printed',
             'with %.17g); expected bytes from tests/vectors/la8_cases.py'],
            ['pv', 'mkq', 'vq'], body,
            [pv_line(y1), pv_line(y2), '%s %s\n' % (g17(y2[0]), g17(y2[6]))])


def la_mv_negzero():
    A = [[NEG0, NEG0, NEG0], [0.0, 0.0, 0.0], [NEG0, 0.0, NEG0], [1.0, -1.0, 0.0], [NEG0, NEG0, 0.0]]
    x = [1.0, 2.0, 3.0]
    xn = [-1.0, -2.0, -3.0]
    N = [[NEG0], [0.0]]
    x1 = [5.0]
    y1, y2, y3 = gemv(A, x), gemv(A, xn), gemv(N, x1)
    assert f2b(y1[0]) == f2b(NEG0) and f2b(y3[0]) == f2b(NEG0)
    body = ['let A: f64[,] = ' + mat_lit(A),
            'let x: f64[] = ' + vec_lit(x),
            'let xn: f64[] = ' + vec_lit(xn),
            'pv(A @ x)',
            'pv(A @ xn)',
            'let N: f64[,] = ' + mat_lit(N),
            'let x1: f64[] = ' + vec_lit(x1),
            'pv(N @ x1)']
    program('la_mv_negzero',
            ['the first term of each row is the product itself, never 0 + A[i,0]*x[0] (DESIGN.md 2.13.2): a row of',
             '-0 products gives -0 (also with one column), -0 + +0 is +0, products of -0 by negative x are +0;',
             'printed with %.17g (LANGUAGE.md 11.1: -0); expected bytes from tests/vectors/la8_cases.py'],
            ['pv'], body, [pv_line(y1), pv_line(y2), pv_line(y3)])


def la_mv_empty():
    body = ['let A = zeros(3, 0)',
            'let x = zeros(0)',
            'pv(A @ x)',
            'let B = zeros(0, 4)',
            'let y = ones(4)',
            'pv(B @ y)',
            'let C = zeros(0, 0)',
            'pv(C @ x)',
            'let r = A @ x',
            'printf("%d %.17g\\n", len(r), r[2])']
    program('la_mv_empty',
            ['empty operands of matrix @ vector (DESIGN.md 2.13.2 "Empty operands", LANGUAGE.md 10.8): r x 0 @ 0 is',
             'the vector of r zeros (+0, no kernel called), 0 x k @ k and 0 x 0 @ 0 the empty vector; by hand'],
            ['pv'], body,
            [pv_line([0.0, 0.0, 0.0]), pv_line([]), pv_line([]), '3 0\n'])


def k0_big_line(n):
    """`printf("%d %d %g\\n", len(y), nnz(y == 0.0), min(1.0 / y))` for y the n zeros (+0) of a k = 0
    product: every element is +0 (2.13.2 "Empty operands"), so all n compare equal to 0 and every
    1.0 / +0 is +inf (a -0 element would give -inf, the minimum)."""
    y = [0.0] * n
    q = [1.0 / v if v != 0.0 else math.copysign(INF, v) for v in y]
    m = q[0]
    for v in q[1:]:
        m = v if v < m else m
    return progfmt.format_all('%d %d %g\n', [('i', len(y)), ('i', sum(1 for v in y if v == 0.0)),
                                            ('f', f2b(m))]).decode()


def la_mv_k0_big():
    body = ['let Z: f64[300,0] = []',
            'let x: f64[0] = []',
            'let y = Z @ x',
            'printf("%d %d %g\\n", len(y), nnz(y == 0.0), min(1.0 / y))']
    program('la_mv_k0_big',
            ['a fixed-size matrix @ vector with k = 0 whose result has more than 256 elements (DESIGN.md 2.13.2,',
             'Decision 125 (a), L21): f64[300,0] @ f64[0] is the dynamic f64[] of 300 zeros, every one +0 (no',
             'product, no -0.0 accumulator): the length, the count equal to 0 and min(1.0 / y) = Inf (-Inf for any',
             '-0); expected bytes from tests/vectors/la8_cases.py'],
            [], body, [k0_big_line(300)])


def la_mv_nonfinite():
    cases = [([[INF, 1.0]], [0.0, 1.0]),         # inf * 0 = NaN, NaN + 1
             ([[INF, -INF]], [1.0, 1.0]),        # inf + -inf = NaN
             ([[INF, 1.0], [1.0, -INF]], [1.0, 1.0]),
             ([[1e308, 1e308], [-1e308, -1e308], [1e308, -1e308]], [10.0, -10.0]),
             ([[1e308, 1e308], [-1e308, -1e308]], [1.0, 1.0]),
             ([[NAN, 0.0], [0.0, 0.0]], [1.0, INF]),
             ([[5e-324, 5e-324, 1.0], [2.2250738585072014e-308, -2.2250738585072014e-308, 0.0]], [0.5, 0.5, 0.0])]
    body = []
    exp = []
    for n, (A, x) in enumerate(cases):
        body.append('let A%d: f64[,] = %s' % (n, mat_lit(A)))
        body.append('let x%d: f64[] = %s' % (n, vec_lit(x)))
        body.append('pv(A%d @ x%d)' % (n, n))
        exp.append(pv_line(gemv(A, x)))
    program('la_mv_nonfinite',
            ['Inf and NaN propagate by IEEE rules through the pinned order (LANGUAGE.md 10.8, DESIGN.md 2.13.2):',
             '0 * inf, inf + -inf, a NaN element, products overflowing to +-inf and their sum, subnormal products',
             'rounding to 0; NaN printed NaN whatever its sign (11.1); expected bytes from tests/vectors/la8_cases.py'],
            ['pv'], body, exp)


def la_mv_i64():
    Ai = [[1, 2, 3], [4, 5, 6]]
    xf = [0.5, 0.25, 0.125]
    Af = [[0.5, 1.5], [2.5, 3.5]]
    xi = [9007199254740993, 3]
    xi2 = [1, -1, 2]
    fl = lambda M: [[float(v) for v in row] for row in M]
    y1 = gemv(fl(Ai), xf)
    y2 = gemv(Af, [float(v) for v in xi])
    assert float(9007199254740993) == 9007199254740992.0
    y3 = gemv(fl(Ai), [float(v) for v in xi2])
    Bi = [[3, -1], [2, 7], [-5, 4]]
    y4 = gemv(fl(Bi), [float(v) for v in xi2[:2]])
    body = ['let Ai: i64[,] = [1, 2, 3; 4, 5, 6]',
            'let xf: f64[] = ' + vec_lit(xf),
            'pv(Ai @ xf)',
            'let Af: f64[,] = ' + mat_lit(Af),
            'let xi: i64[] = [9007199254740993, 3]',
            'pv(Af @ xi)',
            'let xi2: i64[] = [1, -1, 2]',
            'pv(Ai @ xi2)',
            'let Bi = [3, -1; 2, 7; -5, 4]',
            'let xf2 = [1, -1]',
            'pv(Bi @ xf2)']
    program('la_mv_i64',
            ['an i64 operand of @ is converted to f64 element by element (LANGUAGE.md 6.2, 4.2; DESIGN.md 2.13.3,',
             'L-iq): i64 matrix @ f64 vector, f64 matrix @ i64 vector (9007199254740993 rounds to 2^53, ties to',
             'even), dynamic i64 @ i64, and fixed-size i64[3,2] @ i64[2] (L21 on converted operands, an f64 result);',
             'expected bytes from tests/vectors/la8_cases.py'],
            ['pv'], body, [pv_line(y1), pv_line(y2), pv_line(y3), pv_line(y4)])


def la_mv_fixed():
    A = [[1e16, 1.0, -1e16], [0.1, 0.2, 0.3]]
    x = [1.0, 1.0, 1.0]
    y1 = gemv(A, x)
    F = mkq(5, 7, 4)
    xv = vq(7, 3)
    y2 = gemv(F, xv)
    assert y2 != gemv_reversed(F, xv)
    G = mkq(16, 16, 1)
    xg = vq(16, 2)
    y3 = gemv(G, xg)
    assert y3 != gemv_reversed(G, xg)
    N = [[NEG0], [NEG0]]
    y4 = gemv(N, [5.0])
    body = (['let A = ' + mat_lit(A),
             'let x = ' + vec_lit(x),
             'let y: f64[2] = A @ x',
             'pv(y)']
            + fixed_fill_q('F', 5, 7, 4) + fixed_fill_vq('xv', 7, 3)
            + ['pv(F @ xv)']
            + fixed_fill_q('G', 16, 16, 1) + fixed_fill_vq('xg', 16, 2)
            + ['let yg: f64[16] = G @ xg',
               'pv(yg)',
               'let N = [-0.0; -0.0]',
               'pv(N @ [5.0])',
               'let Z: f64[2,0] = []',
               'let z: f64[0] = []',
               'pv(Z @ z)'])
    program('la_mv_fixed',
            ['@ of a fixed-size matrix and a fixed-size vector, inlined by L21 in the pinned chain (DESIGN.md',
             '2.13.4 L21, Decision 125 (a), L-iw; LANGUAGE.md 6.8: class E at every extent, result f64[r]): the',
             'order-sensitive rows of la_mv_order, 5 x 7 and 16 x 16 matrices of rounded quotients, a column of -0',
             'by 5 (the chain starts with the first product: -0), and k = 0 (f64[2,0] @ f64[0]: +0, no loop);',
             'expected bytes from tests/vectors/la8_cases.py'],
            ['pv'], body, [pv_line(y1), pv_line(y2), pv_line(y3), pv_line(y4), pv_line([0.0, 0.0])])


def la_mv_mixed():
    Q = mkq(6, 5, 3)
    xs = vq(5, 2)
    F = mkq(4, 6, 2)
    xd = vq(6, 4)
    y1, y2 = gemv(Q, xs), gemv(F, xd)
    assert y1 != gemv_reversed(Q, xs) or y2 != gemv_reversed(F, xd)
    body = (['let Q = mkq(6, 5, 3)']
            + fixed_fill_vq('xs', 5, 2)
            + ['pv(Q @ xs)']
            + fixed_fill_q('F', 4, 6, 2)
            + ['let xd = vq(6, 4)',
               'pv(F @ xd)'])
    program('la_mv_mixed',
            ['a dynamic matrix @ a fixed-size vector and a fixed-size matrix @ a dynamic vector: the fixed-size',
             'operand is made dynamic (dyn, DESIGN.md 2.13.3, L-iq) and the product is GEMV, class E in the pinned',
             'order (LANGUAGE.md 10.8); expected bytes from tests/vectors/la8_cases.py'],
            ['pv', 'mkq', 'vq'], body, [pv_line(y1), pv_line(y2)])


def la_mv_view():
    A = mkq(5, 4, 1)              # 5 x 4
    x5 = vq(5, 3)
    x4 = vq(4, 5)
    y1 = gemv(transpose(A, 5, 4), x5)           # A.T @ x5: 4 x 5 @ 5
    y2 = gemv(A[1:3], x4)                      # A[1..3, :] @ x4
    y3 = gemv([row[0:2] for row in A], x4[1:3])   # A[:, 0..2] @ x4[1..3]
    flat = [A[i][j] for j in range(4) for i in range(5)]   # A.flat, column-major
    B = mkq(3, 20, 6)
    y4 = gemv(B, flat)
    idx = [4, 0, 2]
    y5 = gemv([A[i] for i in idx], x4)          # A[[4, 0, 2], :] @ x4
    body = ['let A = mkq(5, 4, 1)',
            'let x5 = vq(5, 3)',
            'let x4 = vq(4, 5)',
            'pv(A.T @ x5)',
            'pv(A[1..3, :] @ x4)',
            'pv(A[:, 0..2] @ x4[1..3])',
            'let B = mkq(3, 20, 6)',
            'pv(B @ A.flat)',
            'pv(A[[4, 0, 2], :] @ x4)']
    program('la_mv_view',
            ['views and selections as operands of matrix @ vector (DESIGN.md 2.13.4 R35: the operand is',
             'materialized before the call; LANGUAGE.md 5.2, 5.6): A.T, a row range, a column range with a vector',
             'range, A.flat as the vector, an index-vector row selection; class E in the pinned order; expected',
             'bytes from tests/vectors/la8_cases.py'],
            ['pv', 'mkq', 'vq'], body, [pv_line(y1), pv_line(y2), pv_line(y3), pv_line(y4), pv_line(y5)])


def la_mv_tails():
    body = ['for k in [1, 2, 3, 7, 9, 17] {',
            '    let x = vq(k, k)',
            '    for r in 1..20 {',
            '        pv(mkq(r, k, r + k) @ x)',
            '    }',
            '}']
    exp = []
    differs = False
    for k in [1, 2, 3, 7, 9, 17]:
        x = vq(k, k)
        for r in range(1, 20):
            A = mkq(r, k, r + k)
            y = gemv(A, x)
            if k > 1 and y != gemv_reversed(A, x):
                differs = True
            exp.append(pv_line(y))
    assert differs
    program('la_mv_tails',
            ['matrix @ vector with 1 ... 19 rows for k = 1, 2, 3, 7, 9, 17, so every row panel of GEMV\'s forms',
             '(8 and 16 rows, 2.13.6) and every 2-lane and scalar tail is crossed (DESIGN.md 2.13.8); class E in',
             'the pinned order; expected bytes from tests/vectors/la8_cases.py'],
            ['pv', 'mkq', 'vq'], body, exp)


# ============================================================ vector @ matrix
def la_vm_order():
    k = 19
    xa = [1e16] + [1.0] * 7 + [-1e16] + [1.0] * 10
    Aa = [[1.0] for _ in range(k)]
    _, ya = vecmat(xa, Aa)
    seq = seq_sum([xa[kk] * Aa[kk][0] for kk in range(k)])
    assert ya[0] != seq          # the lanes: 1e16 and -1e16 meet in lane 0
    x = vq(k, 2)
    A = mkq(k, 3, 5)
    _, y = vecmat(x, A)
    assert any(y[j] != seq_sum([x[kk] * A[kk][j] for kk in range(k)]) for j in range(3))
    body = ['let xa: f64[] = ' + vec_lit(xa),
            'let Aa = ones(19, 1)',
            'pv(xa @ Aa)',
            'printf("%.17g\\n", sum(xa))',
            'let x = vq(19, 2)',
            'let A = mkq(19, 3, 5)',
            'pv(x @ A)']
    s8 = sum8(xa)
    assert s8 == ya[0]
    program('la_vm_order',
            ['vector @ matrix with k = 19: each y[j] is the pinned 8-lane sum (LANGUAGE.md 10.5, 10.8; DESIGN.md',
             '2.13.2, 2.13.6 VECMAT, L-iz) of the rounded products, derived lane by lane: x = [1e16, 1 (7 times),',
             '-1e16, 1 (10 times)] against a column of ones gives %s where the sequential sum gives %s' % (g17(ya[0]), g17(seq)),
             '(and equals sum(x)), and 19 x 3 rounded quotients; expected bytes from tests/vectors/la8_cases.py'],
            ['pv', 'mkq', 'vq'], body, [pv_line(ya), g17(s8) + '\n', pv_line(y)])


def la_vm_negzero():
    x = [NEG0, 0.0, 1.0]
    A = [[1.0, NEG0, 1.0, 0.0], [NEG0, 0.0, 1.0, 0.0], [NEG0, NEG0, -1.0, 0.0]]
    y = vecmat_c(x, A, 4)
    x1 = [NEG0]
    A1 = [[3.0, -3.0]]
    y1 = vecmat_c(x1, A1, 2)
    assert f2b(y1[0]) == f2b(NEG0) and f2b(y1[1]) == 0
    body = ['let x: f64[] = ' + vec_lit(x),
            'let A: f64[,] = ' + mat_lit(A),
            'pv(x @ A)',
            'let x1: f64[] = ' + vec_lit(x1),
            'let A1: f64[,] = ' + mat_lit(A1),
            'pv(x1 @ A1)']
    program('la_vm_negzero',
            ['vector @ matrix: the accumulators start at -0.0 (LANGUAGE.md 10.5, DESIGN.md 2.13.2), so a column of',
             '-0 products gives -0, one +0 product makes +0, -0 * -3 is +0; printed with %.17g; expected bytes',
             'from tests/vectors/la8_cases.py'],
            ['pv'], body, [pv_line(y), pv_line(y1)])


def la_vm_empty():
    body = ['let x = zeros(0)',
            'let A = zeros(0, 3)',
            'pv(x @ A)',
            'let y = ones(2)',
            'let B = zeros(2, 0)',
            'pv(y @ B)',
            'let C = zeros(0, 0)',
            'pv(x @ C)']
    program('la_vm_empty',
            ['empty operands of vector @ matrix (DESIGN.md 2.13.2 "Empty operands"): 0 @ 0 x c is the vector of c',
             'zeros (+0, the empty sum, not the -0.0 of the accumulators), k @ k x 0 and 0 @ 0 x 0 the empty vector;',
             'by hand'],
            ['pv'], body, [pv_line([0.0, 0.0, 0.0]), pv_line([]), pv_line([])])


def la_vm_k0_big():
    body = ['let x: f64[0] = []',
            'let Z: f64[0,300] = []',
            'let y = x @ Z',
            'printf("%d %d %g\\n", len(y), nnz(y == 0.0), min(1.0 / y))']
    program('la_vm_k0_big',
            ['a fixed-size vector @ matrix with k = 0 whose result has more than 256 elements (DESIGN.md 2.13.2,',
             'Decision 125 (a), L21): f64[0] @ f64[0,300] is the dynamic f64[] of 300 zeros, every one +0 (the',
             'empty sum, not the -0.0 of sum8\'s accumulators): the length, the count equal to 0 and',
             'min(1.0 / y) = Inf (-Inf for any -0); expected bytes from tests/vectors/la8_cases.py'],
            [], body, [k0_big_line(300)])


def la_vm_fixed():
    k = 19
    x = vq(k, 4)
    A = mkq(k, 3, 2)
    y = vecmat_c(x, A, 3)
    assert any(y[j] != seq_sum([x[kk] * A[kk][j] for kk in range(k)]) for j in range(3))
    x8 = vq(8, 1)
    A8 = mkq(8, 5, 6)
    y8 = vecmat_c(x8, A8, 5)
    xs = [1e16, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, -1e16, 1.0]
    ys = vecmat_c(xs, [[1.0, -1.0] for _ in range(10)], 2)
    body = (fixed_fill_vq('x', k, 4) + fixed_fill_q('A', k, 3, 2)
            + ['let y: f64[3] = x @ A',
               'pv(y)']
            + fixed_fill_vq('x8', 8, 1) + fixed_fill_q('A8', 8, 5, 6)
            + ['pv(x8 @ A8)',
               'let xs = ' + vec_lit(xs),
               'let As = [' + '; '.join(['1.0, -1.0'] * 10) + ']',
               'pv(xs @ As)',
               'let z: f64[0] = []',
               'let Z: f64[0,2] = []',
               'pv(z @ Z)'])
    program('la_vm_fixed',
            ['@ of a fixed-size vector and a fixed-size matrix, inlined by L21 with L13\'s sum8 form (DESIGN.md',
             '2.13.4 L21, L-iw; LANGUAGE.md 6.8, 10.5): k = 19 (lanes 0-7 twice, then 0-2), k = 8, a k = 10 case',
             'whose lanes meet 1e16 and -1e16 in lane 0, and k = 0 (f64[0] @ f64[0,2]: +0); class E; expected bytes',
             'from tests/vectors/la8_cases.py'],
            ['pv'], body, [pv_line(y), pv_line(y8), pv_line(ys), pv_line([0.0, 0.0])])


# ============================================================ matrix @ matrix
def la_mm_exact():
    A1, B1 = [[3.0]], [[-7.0]]
    A2, B2 = mki(3, 5, 1), mki(5, 2, 4)
    C2 = matmul_exact(A2, B2, 3, 5, 2)
    A3, B3 = mki(70, 40, 2), mki(40, 65, 3)
    C3 = matmul_exact(A3, B3, 70, 40, 65)
    colsums = [sum8([zero_norm(C3[i][j]) * zero_norm(C3[i][j]) for i in range(70)]) for j in range(65)]
    body = ['var A1 = zeros(1, 1)',
            'A1[0, 0] = 3.0',
            'var B1 = zeros(1, 1)',
            'B1[0, 0] = -7.0',
            'pmz(A1 @ B1)',
            'pmz(mki(3, 5, 1) @ mki(5, 2, 4))',
            'let A3 = mki(70, 40, 2)',
            'let B3 = mki(40, 65, 3)',
            'let C3 = A3 @ B3',
            'printf("%dx%d\\n", rows(C3), cols(C3))',
            'var bad = 0',
            'for i in 0..70 {',
            '    for j in 0..65 {',
            '        var s = 0.0',
            '        for kk in 0..40 {',
            '            s = s + A3[i, kk] * B3[kk, j]',
            '        }',
            '        if s != C3[i, j] {',
            '            bad += 1',
            '        }',
            '    }',
            '}',
            'printf("%d\\n", bad)',
            'for j in 0..65 {',
            '    printf(" %.17g", sum(C3[:, j] * C3[:, j]))',
            '}',
            'printf("\\n")']
    exp = [pm_line([[-21.0]], 1, 1), pm_line(zm(C2), 3, 2), '70x65\n', '0\n',
           ''.join(' ' + g17(s) for s in colsums) + '\n']
    program('la_mm_exact',
            ['matrix @ matrix of dynamic matrices through GEMM (class R; LANGUAGE.md 10.8, DESIGN.md 2.13.6',
             'MATMUL) on exact data (integers in -3 .. 3, every product and partial sum exact in every order and',
             'variant, DESIGN.md 2.13.8): 1 x 1, 3 x 5 @ 5 x 2 element by element and 70 x 40 @ 40 x 65 against a',
             'scalar triple loop (0 mismatches) and by the sums of squares of its columns; results printed as x + 0.0 (GEMM leaves the',
             'sign of a zero open); the program tests/la/la_link.sh links; expected bytes from',
             'tests/vectors/la8_cases.py'],
            ['pmz', 'mki'], body, exp)


def la_mm_empty():
    body = ['let A = zeros(3, 0)',
            'let B = zeros(0, 2)',
            'pm(A @ B)',
            'pm(zeros(0, 4) @ zeros(4, 2))',
            'pm(zeros(2, 4) @ zeros(4, 0))',
            'pm(zeros(0, 0) @ zeros(0, 0))']
    program('la_mm_empty',
            ['empty operands of matrix @ matrix (DESIGN.md 2.13.2 "Empty operands", 2.13.5 MATMUL; LANGUAGE.md 10.8):',
             'r x 0 @ 0 x c is the r x c zero matrix of +0 (no kernel called, printed raw), 0 x k @ k x c is 0 x c,',
             'r x k @ k x 0 is r x 0, 0 x 0 @ 0 x 0 is 0 x 0; by hand'],
            ['pm'], body,
            [pm_line([[0.0, 0.0]] * 3, 3, 2), pm_line([], 0, 2), pm_line([[], []], 2, 0), pm_line([], 0, 0)])


def bsk_rule(terms):
    """Baysick DESIGN.md 6.6.4 rules 1 and 2 for one element of a GEMM (each term a product (a, b));
    returns the value, or None when rule 3 or 4 would apply (not used by la_mm_nonfinite's data)."""
    has_nan = False
    pinf = ninf = False
    S = 0.0
    for a, b in terms:
        if a != a or b != b or ((a == 0.0 and abs(b) == INF) or (b == 0.0 and abs(a) == INF)):
            has_nan = True
        elif abs(a) == INF or abs(b) == INF:
            if (a < 0) != (b < 0):
                ninf = True
            else:
                pinf = True
        else:
            S += abs(a * b)          # the data's finite products are small integers: exact
    if has_nan or (pinf and ninf):
        return NAN
    assert S <= 2.0 ** 1023
    if pinf:
        return INF
    if ninf:
        return -INF
    return None


def la_mm_nonfinite():
    A = [[INF, 1.0], [NAN, 2.0], [INF, INF], [-INF, 3.0]]
    B = [[1.0, 0.0, -1.0], [1.0, 1.0, -1.0]]
    C = []
    for i in range(4):
        row = []
        for j in range(3):
            v = bsk_rule([(A[i][kk], B[kk][j]) for kk in range(2)])
            assert v is not None, (i, j)
            row.append(v)
        C.append(row)
    body = ['let A: f64[,] = ' + mat_lit(A),
            'let B: f64[,] = ' + mat_lit(B),
            'pmz(A @ B)']
    program('la_mm_nonfinite',
            ['non-finite operands of matrix @ matrix (GEMM, class R) by Baysick DESIGN.md 6.6.4\'s IEEE rules 1 and 2',
             'only (DESIGN.md 2.13.2, 2.13.8): inf * 0 and a NaN factor give NaN, +inf and -inf terms give NaN, an',
             'infinite term with small finite ones gives that infinity; every element of the 4 x 3 result is one',
             'of those; expected bytes from tests/vectors/la8_cases.py'],
            ['pmz'], body, [pm_line(C, 4, 3)])


def la_mm_fixed():
    A = [[1e16, 1.0, -1e16, 0.5], [0.1, 0.2, 0.3, 0.4], [NEG0, NEG0, NEG0, NEG0]]
    B = [[1.0, NEG0], [1.0, 2.0], [1.0, -3.0], [1.0, 0.25]]
    C1 = matmul_e(A, B, 3, 4, 2)
    assert C1[0][0] == 0.5 and f2b(C1[2][0]) == f2b(NEG0)
    P, Qm = mkq(7, 8, 3), mkq(8, 6, 1)
    C2 = matmul_e(P, Qm, 7, 8, 6)
    rev = [[seq_sum([P[i][kk] * Qm[kk][j] for kk in range(7, -1, -1)]) for j in range(6)] for i in range(7)]
    assert C2 != rev
    G, H = mki(16, 16, 2), mki(16, 16, 5)
    C3 = matmul_e(G, H, 16, 16, 16)
    assert C3 == matmul_exact(G, H, 16, 16, 16)
    col3 = [sum8([C3[i][j] for i in range(16)]) for j in range(16)]
    U, V = mkq(17, 8, 2), mkq(8, 17, 4)
    C4 = matmul_e(U, V, 17, 8, 17)
    flat4 = [C4[i][j] for j in range(17) for i in range(17)]
    body = (['let A = ' + mat_lit(A),
             'let B = ' + mat_lit(B),
             'let C: f64[3,2] = A @ B',
             'pm(C)']
            + fixed_fill_q('P', 7, 8, 3) + fixed_fill_q('Q', 8, 6, 1)
            + ['pm(P @ Q)']
            + fixed_fill_i('G', 16, 16, 2) + fixed_fill_i('H', 16, 16, 5)
            + ['let GH: f64[16,16] = G @ H',
               'printf("%.17g %.17g %.17g\\n", GH[0, 0], GH[15, 15], GH[3, 11])',
               'for j in 0..16 {',
               '    printf(" %.17g", sum(GH[:, j]))',
               '}',
               'printf("\\n")',
               'let Z: f64[2,0] = []',
               'let W: f64[0,3] = []',
               'pm(Z @ W)']
            + fixed_fill_q('U', 17, 8, 2) + fixed_fill_q('V', 8, 17, 4)
            + ['let D = U @ V',
               'printf("%dx%d %.17g %.17g %.17g\\n", rows(D), cols(D), D[0, 0], D[16, 3], sum(D.flat))'])
    exp = [pm_line(C1, 3, 2), pm_line(C2, 7, 6),
           '%s %s %s\n' % (g17(C3[0][0]), g17(C3[15][15]), g17(C3[3][11])),
           ''.join(' ' + g17(s) for s in col3) + '\n',
           pm_line([[0.0] * 3, [0.0] * 3], 2, 3),
           '17x17 %s %s %s\n' % (g17(C4[0][0]), g17(C4[16][3]), g17(sum8(flat4)))]
    program('la_mm_fixed',
            ['@ of two fixed-size matrices, inlined by L21 (DESIGN.md 2.13.4, Decision 125 (a), L-iw; LANGUAGE.md',
             '6.8: class E at every extent, the chain c[i,j] = (...(a[i,0]*b[0,j] + a[i,1]*b[1,j]) ...)):',
             'order-sensitive 3 x 4 @ 4 x 2 data (1e16 + 1 - 1e16 + 0.5 is 0.5; a row of -0 products is -0), 7 x 8 @',
             '8 x 6 rounded quotients, a 16 x 16 product on exact integer data (256 elements: fixed-size), k = 0',
             '(f64[2,0] @ f64[0,3]: +0), and 17 x 8 @ 8 x 17 whose 289 elements exceed 256, so the result is a',
             'dynamic matrix, still class E (2.13.2); all printed raw; expected bytes from tests/vectors/la8_cases.py'],
            ['pm'], body, exp)


def la_mm_mixed():
    F = mki(3, 4, 1)
    D = mki(4, 2, 2)
    C1 = matmul_exact(F, D, 3, 4, 2)
    E = mki(2, 4, 3)
    G = mki(4, 3, 4)
    C2 = matmul_exact(E, G, 2, 4, 3)
    body = (fixed_fill_i('F', 3, 4, 1)
            + ['let D = mki(4, 2, 2)',
               'pmz(F @ D)',
               'let E = mki(2, 4, 3)']
            + fixed_fill_i('G', 4, 3, 4)
            + ['pmz(E @ G)'])
    program('la_mm_mixed',
            ['a fixed-size matrix @ a dynamic one and a dynamic matrix @ a fixed-size one: the fixed-size operand is',
             'used as the dynamic matrix it equals (dyn; DESIGN.md 2.13.2, 2.13.3, Decision 125 (a)) and the product',
             'is GEMM, class R, so the data is exact (integers); printed as x + 0.0; expected bytes from',
             'tests/vectors/la8_cases.py'],
            ['pmz', 'mki'], body, [pm_line(zm(C1), 3, 2), pm_line(zm(C2), 2, 3)])


def la_mm_i64():
    Ai = [[1, -2, 3], [4, 0, -6]]
    Bf = mki(3, 2, 1)
    fl = lambda M: [[float(v) for v in row] for row in M]
    C1 = matmul_exact(fl(Ai), Bf, 2, 3, 2)
    Bi = [[2, 1, 0, -1], [3, -3, 5, 1], [-4, 2, 2, 7]]
    C2 = matmul_exact(fl(Ai), fl(Bi), 2, 3, 4)
    Af = mki(2, 3, 5)
    C3 = matmul_exact(Af, fl(Bi), 2, 3, 4)
    Ki = [[9007199254740993, 1], [2, 3]]
    Kf = [[1.0, 0.0], [0.0, 1.0]]
    C4 = matmul_e(fl(Ki), Kf, 2, 2, 2)
    assert C4[0][0] == 9007199254740992.0
    body = ['let Ai: i64[,] = [1, -2, 3; 4, 0, -6]',
            'let Bf = mki(3, 2, 1)',
            'pmz(Ai @ Bf)',
            'let Bi: i64[,] = [2, 1, 0, -1; 3, -3, 5, 1; -4, 2, 2, 7]',
            'pmz(Ai @ Bi)',
            'pmz(mki(2, 3, 5) @ Bi)',
            'let Ki = [9007199254740993, 1; 2, 3]',
            'let Kf = [1.0, 0.0; 0.0, 1.0]',
            'pm(Ki @ Kf)']
    program('la_mm_i64',
            ['i64 operands of matrix @ matrix converted to f64 (LANGUAGE.md 6.2, 4.2; DESIGN.md 2.13.3, L-iq): i64 @',
             'f64, i64 @ i64, f64 @ i64 (dynamic: GEMM on exact data, printed as x + 0.0), and the fixed-size i64[2,2]',
             '@ f64[2,2] of L21 (9007199254740993 converted to 2^53, class E, printed raw); expected bytes from',
             'tests/vectors/la8_cases.py'],
            ['pm', 'pmz', 'mki'], body,
            [pm_line(zm(C1), 2, 2), pm_line(zm(C2), 2, 4), pm_line(zm(C3), 2, 4), pm_line(C4, 2, 2)])


def la_mm_operands():
    A, B, C = mki(3, 4, 1), mki(3, 4, 2), mki(4, 2, 3)
    D = mki(2, 5, 4)
    S = [[A[i][j] + B[i][j] for j in range(4)] for i in range(3)]
    r1 = matmul_exact(S, C, 3, 4, 2)                              # (A + B) @ C
    AC = matmul_exact(A, C, 3, 4, 2)
    r2 = matmul_exact(AC, D, 3, 2, 5)                             # A @ C @ D = (A @ C) @ D
    At = transpose(A, 3, 4)                                       # 4 x 3
    r3 = matmul_exact(At, B, 4, 3, 4)                             # A.T @ B
    r4 = matmul_exact(A[0:2], C, 2, 4, 2)                         # A[0..2, :] @ C
    A2 = [[2.0 * v for v in row] for row in A]
    r5 = matmul_exact(A2, C, 3, 4, 2)                             # 2.0 * A @ C = (2.0 * A) @ C
    r6 = [[v * 2.0 for v in row] for row in AC]                   # A @ C * 2.0 = (A @ C) * 2.0
    An = [[-v for v in row] for row in A]
    r7 = matmul_exact(An, C, 3, 4, 2)                             # -A @ C = (-A) @ C
    x = vi(5, 1)
    r8 = gemv(r2, x)                                              # A @ C @ D @ x: GEMV of the exact product
    Dx = gemv(D, x)
    r9 = gemv(AC, Dx)                                             # (A @ C) @ (D @ x)
    body = ['let A = mki(3, 4, 1)',
            'let B = mki(3, 4, 2)',
            'let C = mki(4, 2, 3)',
            'let D = mki(2, 5, 4)',
            'pmz((A + B) @ C)',
            'pmz(A @ C @ D)',
            'pmz(A.T @ B)',
            'pmz(A[0..2, :] @ C)',
            'pmz(2.0 * A @ C)',
            'pmz(A @ C * 2.0)',
            'pmz(-A @ C)',
            'let x = vi(5, 1)',
            'pvz(A @ C @ D @ x)',
            'pvz((A @ C) @ (D @ x))']
    program('la_mm_operands',
            ['operands and chains of @ (LANGUAGE.md 6.1: @ shares the precedence of * and is left-associative;',
             'DESIGN.md 2.13.4: @ is a seafuse barrier whose operands are fused trees, L-ix): (A + B) @ C, A @ C @ D,',
             'A.T @ B, a row range, 2.0 * A @ C = (2.0 * A) @ C, A @ C * 2.0 = (A @ C) * 2.0, -A @ C, and two chains',
             'ending in matrix @ vector; exact integer data (GEMM, class R), printed as x + 0.0; expected bytes from',
             'tests/vectors/la8_cases.py'],
            ['pmz', 'pvz', 'mki', 'vi'], body,
            [pm_line(zm(r1), 3, 2), pm_line(zm(r2), 3, 5), pm_line(zm(r3), 4, 4), pm_line(zm(r4), 2, 2),
             pm_line(zm(r5), 3, 2), pm_line(zm(r6), 3, 2), pm_line(zm(r7), 3, 2),
             pv_line([zero_norm(v) for v in r8]), pv_line([zero_norm(v) for v in r9])])


# ============================================================ errors
def errors():
    err_runtime('r_la_mm_shape',
                ['matrix @ matrix of dynamic 2 x 3 and 4 x 2 matrices: shape mismatch with the operands\' shapes in',
                 'source order (LANGUAGE.md 9.2, 10.8; DESIGN.md 2.13.2, 2.13.5 MATMUL, L-ij, L-iv), at the line of',
                 'the @, after the start line is flushed'],
                'let A = zeros(2, 3)\nlet B = zeros(4, 2)\nprintf("start\\n")\nlet C = A @ B\nprintf("%d\\n", rows(C))\n',
                'let C = A @ B', 'shape mismatch: 2x3 vs 4x2', 'start\n')
    err_runtime('r_la_mv_shape',
                ['dynamic 2 x 3 matrix @ vector of 4: shape mismatch (LANGUAGE.md 9.2; DESIGN.md 2.13.2, 2.13.5',
                 'GEMV, L-ij: a vector\'s shape is its length), at the line of the @'],
                'let A = zeros(2, 3)\nlet x = zeros(4)\nprintf("start\\n")\nlet y = A @ x\nprintf("%d\\n", len(y))\n',
                'let y = A @ x', 'shape mismatch: 2x3 vs 4', 'start\n')
    err_runtime('r_la_vm_shape',
                ['vector of 3 @ dynamic 4 x 2 matrix: shape mismatch with the vector\'s shape first (DESIGN.md 2.13.2,',
                 '2.13.5 VECMAT, L-ij), at the line of the @'],
                'let x = zeros(3)\nlet A = zeros(4, 2)\nprintf("start\\n")\nlet y = x @ A\nprintf("%d\\n", len(y))\n',
                'let y = x @ A', 'shape mismatch: 3 vs 4x2', 'start\n')
    err_compile('err_la_mm_static',
                ['@ of fixed-size 2 x 3 and 4 x 2 matrices: both inner extents are constants, so the mismatch is the',
                 'compile error 217 (DESIGN.md 2.13.3, 2.6.2; L-ij) at the operator node, which stands at its left',
                 'operand (DESIGN.md 3.3)'],
                'let A = [1.0, 2.0, 3.0; 4.0, 5.0, 6.0]\nlet B = [1.0, 2.0; 3.0, 4.0; 5.0, 6.0; 7.0, 8.0]\n'
                'let C = A @ B\nprintf("%g\\n", C[0, 0])\n',
                'let C = A @ B', 'A @', 'shape mismatch: 2x3 vs 4x2')
    err_compile('err_la_mv_static',
                ['@ of a fixed-size 2 x 3 matrix and a vector literal of 4: 217 with the shapes 2x3 and 4 (DESIGN.md',
                 '2.13.3, L-ij), at the left operand'],
                'let A = [1.0, 2.0, 3.0; 4.0, 5.0, 6.0]\nlet y = 2.0 * (A @ [1.0, 2.0, 3.0, 4.0])\nprintf("%g\\n", y[0])\n',
                'let y = 2.0', 'A @', 'shape mismatch: 2x3 vs 4')


GENERATORS = [la_mv_order, la_mv_negzero, la_mv_empty, la_mv_k0_big, la_mv_nonfinite, la_mv_i64, la_mv_fixed, la_mv_mixed,
              la_mv_view, la_mv_tails, la_vm_order, la_vm_negzero, la_vm_empty, la_vm_k0_big, la_vm_fixed, la_mm_exact,
              la_mm_empty, la_mm_nonfinite, la_mm_fixed, la_mm_mixed, la_mm_i64, la_mm_operands, errors]


def generate():
    OUT.clear()
    for g in GENERATORS:
        g()


def main(argv):
    generate()
    if argv == ['--check']:
        bad = 0
        for path, data in OUT.items():
            try:
                with open(path, 'rb') as f:
                    have = f.read()
            except OSError:
                print('la8_cases: missing %s' % os.path.relpath(path, TESTS))
                bad += 1
                continue
            if have != data:
                print('la8_cases: differs: %s' % os.path.relpath(path, TESTS))
                bad += 1
        for path in RETIRED:
            if os.path.exists(path):
                print('la8_cases: retired test still present: %s' % os.path.relpath(path, TESTS))
                bad += 1
        if bad:
            return 1
        print('la8_cases: %d files ok' % len(OUT))
        return 0
    if argv:
        sys.stderr.write('usage: la8_cases.py [--check]\n')
        return 2
    for path, data in OUT.items():
        with open(path, 'wb') as f:
            f.write(data)
    for path in RETIRED:
        if os.path.exists(path):
            os.remove(path)
    print('la8_cases: wrote %d files (%d programs, %d errors); removed the retired err_ns_matmul'
          % (len(OUT), sum(1 for p in OUT if p.endswith('.sea') and p.startswith(PROGRAMS)),
             sum(1 for p in OUT if p.endswith('.sea') and p.startswith(ERRORS))))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
