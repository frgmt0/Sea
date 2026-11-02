"""Sub-phases 8b and 8c (work package T1): the programs and error tests of linear algebra.

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
        err_ns_matmul and err_ns_lib_solve files to be absent

The 8c part (DESIGN.md 2.13.8 "8c, factorizations and handles"; 2.13.2, 2.13.3, 2.13.5, 2.13.6, Decisions
121-123 and 129, lead decisions L-ij - L-jf) follows the 8b part and changes none of its files:
        programs/la_{lu,chol,solve,eig}_*.{sea,out}, errors/r_la_* (the 8c run-time errors, .sea .err .out
        .status) and errors/err_la_* and err_json_handle (compile time, .sea .err .status); it deletes the
        retired errors/err_ns_lib_solve.{sea,err,status} (2.13.3: the five library names leave the phase
        rule in 8c; tests/vectors/prel4h_cases.py no longer writes it)
Its RCOND transcription (rcond_est, 2.13.6's steps in binary64, one for one) is checked once against
SciPy's LAPACK dgecon by tests/vectors/la8_scipy_check.py (2.13.8: relative difference <= 1e-3 on 3 000
random matrices; a check of the transcription, never an expected value); `--check` needs no SciPy.

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

HOW THE 8c BYTES ARE DERIVED (the same rules; never from a run of the compiler or of the runtime):

* rcond (class R, but computed from the factors only, with no Baysick call): la_lu_rcond uses only
  matrices whose factors are exact in every order (the identity and power-of-two diagonal matrices:
  L and U off the diagonal are +-0, which change no magnitude, sign test or sum of the estimator);
  each value comes from rcond_est, 2.13.6's RCOND steps transcribed into Python floats one for one
  (`dlange`'s ||A||_1, the special values in Decision 129 (a)'s order, x <- U^-1 L^-1 x and
  x <- L^-T U^-T x unblocked and unscaled, each followed by the test that sum |x| is finite (else
  rcond 0 at once), sgn(v) = +1 for v >= 0, idamax's first largest index, SEA_RCOND_ITMAX and
  SEA_LA_NB read from include/rt.inc, step 3's alternating vector and t, step 4's 0 for an est that
  is +Inf, NaN or 0).
* Factorizations and solves (class R): exact data only, A = P L U (lucase) and A = R^T R (cholcase) with
  dyadic factors whose every product and partial sum, in any order or grouping, is a binary64 value
  (check_dyadic, check_sum_terms); an exact Fraction simulation of 2.13.6's LU (verify_lu_exact)
  shows partial pivoting picks exactly the built row order (the largest candidate unique at each step,
  |l| <= 1/2) and reproduces L and U, verify_chol_exact reproduces R (each pivot a power of four), and
  the solves give the integer X; for n <= SEA_LA_NB the binary64 transcriptions (lu_float,
  lu_solve_float, chol_float, chol_solve_float: one panel, every operation pinned, L-it) give the same
  bits. Results are printed as `x + 0.0` (the sign of an exact zero is left to the build) or as counts.
  Where a test compares solve(A, B) with solve(chol(A), B) bit for bit (DESIGN.md 2.13.6 SOLVE: "exactly
  what solve(chol(A), B) ... would give"), the generator asserts with the pinned one-panel
  transcriptions that the Cholesky and LU paths give different bits for that data.
* Non-finite cases: n = 2 (one panel, no kernel), the NaN or infinite results the same in any order.
* eig_sym: exact results only for diagonal matrices and pencils (tred1 leaves a zero off-diagonal
  scale's row unchanged and tql1 accepts each eigenvalue at once); otherwise the tolerance rule of
  2.13.8, |computed - exact| <= c * n * eps * scale written in the program as a printed bool (`%d`: 1),
  c and the scale in the header; the bounds (class E products of constants) computed here.
* Errors: LANGUAGE.md 9.2's texts with L-ij's shapes at the line of the call (the site, L-iv), each
  entry's checks in its row's order (DESIGN.md 2.13.5, L-ik); compile errors at DESIGN.md 2.6.2's `at`
  node (a call at its callee name, a `bin` at its left operand, an argument, a `ref` at the keyword, a
  `narg` at its name, a type node at its first token, an array literal at its `[`), with the texts of
  2.13.3 (243's types as written in source, 255 naming LANGUAGE.md 10.8's parameter `A`).
"""

import math
import os
import struct
import sys
from decimal import Decimal, getcontext
from fractions import Fraction

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import progfmt  # noqa: E402  (the exact printf oracle; LANGUAGE.md 11.1)

TESTS = os.path.dirname(HERE)
PROGRAMS = os.path.join(TESTS, 'programs')
ERRORS = os.path.join(TESTS, 'errors')
RETIRED = [os.path.join(ERRORS, n + '.' + x) for n in ('err_ns_matmul', 'err_ns_lib_solve')
           for x in ('sea', 'err', 'status')]

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



# ============================================================ 8c: contract constants
def rt_constant(name):
    """the value of `.equiv NAME, V` in include/rt.inc (the contract rule: no constant that has a name
    in an include file is hard-coded here)"""
    with open(os.path.join(os.path.dirname(TESTS), 'include', 'rt.inc')) as f:
        for ln in f:
            parts = ln.split()
            if len(parts) >= 3 and parts[0] == '.equiv' and parts[1] == name + ',':
                return int(parts[2])
    raise AssertionError(name)


RCOND_ITMAX = rt_constant('SEA_RCOND_ITMAX')
LA_NB = rt_constant('SEA_LA_NB')


# ============================================================ 8c: the pinned operations (2.13.6)
def la_norm1(A):
    """||A||_1 as LU computes it (2.13.6, `dlange`'s rule): s_j = |A[0,j]| + |A[1,j]| + ... in row
    order; the norm is s_0, then becomes s_j when s_j > norm or s_j is NaN; 0 for n = 0."""
    n = len(A)
    norm = 0.0
    for j in range(n):
        s = abs(A[0][j])
        for i in range(1, n):
            s = s + abs(A[i][j])
        if j == 0 or s > norm or s != s:
            norm = s
    return norm


def lu_float(A):
    """LU with partial pivoting (2.13.6 LU, one panel: the element sequences are those of every
    panel width, the trailing update's grouping aside); returns (F, piv, first zero pivot or -1),
    F as a list of rows in the pivoted order."""
    n = len(A)
    F = [list(r) for r in A]
    piv = []
    zp = -1
    for k in range(n):
        p, m = k, abs(F[k][k])
        for i in range(k + 1, n):
            if abs(F[i][k]) > m:          # a NaN never replaces (L-in, Decision 129 (a))
                p, m = i, abs(F[i][k])
        piv.append(p)
        if p != k:
            F[k], F[p] = F[p], F[k]
        if F[k][k] != 0.0:
            for i in range(k + 1, n):
                F[i][k] = F[i][k] / F[k][k]
        elif zp < 0:
            zp = k
        for c in range(k + 1, n):
            for i in range(k + 1, n):
                F[i][c] = F[i][c] - F[i][k] * F[k][c]
    return F, piv, zp


def lu_solve_float(F, piv, B):
    """2.13.6 "Triangular solves", unblocked (n <= SEA_LA_NB: one panel, no kernel); B a list of n
    rows of m elements; returns X the same way."""
    n = len(F)
    X = [list(r) for r in B]
    m = len(X[0]) if n else 0
    for k in range(n):
        if piv[k] != k:
            X[k], X[piv[k]] = X[piv[k]], X[k]
    for c in range(m):
        for k in range(n):
            for i in range(k + 1, n):
                X[i][c] = X[i][c] - F[i][k] * X[k][c]
        for k in range(n - 1, -1, -1):
            X[k][c] = X[k][c] / F[k][k]
            for i in range(k):
                X[i][c] = X[i][c] - F[i][k] * X[k][c]
    return X


def chol_float(A):
    """2.13.6 CHOL, one panel (n <= SEA_LA_NB): reads the upper triangle only; returns R (rows) or
    None when a pivot is not greater than 0."""
    n = len(A)
    R = [[A[i][j] if j >= i else 0.0 for j in range(n)] for i in range(n)]
    for j in range(n):
        d = R[j][j]
        for kk in range(j):
            d = d - R[kk][j] * R[kk][j]
        if not d > 0.0:
            return None
        R[j][j] = math.sqrt(d)
        for c in range(j + 1, n):
            s = R[j][c]
            for kk in range(j):
                s = s - R[kk][j] * R[kk][c]
            R[j][c] = s / R[j][j]
    return R


def chol_solve_float(R, B):
    """2.13.6 CHOL_SOLVE, one panel."""
    n = len(R)
    X = [list(r) for r in B]
    m = len(X[0]) if n else 0
    for c in range(m):
        for j in range(n):
            X[j][c] = X[j][c] / R[j][j]
            for i in range(j + 1, n):
                X[i][c] = X[i][c] - R[j][i] * X[j][c]
        for k in range(n - 1, -1, -1):
            X[k][c] = X[k][c] / R[k][k]
            for i in range(k):
                X[i][c] = X[i][c] - R[i][k] * X[k][c]
    return X


def is_sym(A):
    """Decision 123 (a): every pair equal by == or both NaN."""
    n = len(A)
    return all(A[i][j] == A[j][i] or (A[i][j] != A[i][j] and A[j][i] != A[j][i])
               for i in range(n) for j in range(i + 1, n))


def solve_path(A):
    """the path SOLVE takes (2.13.6): 'chol' or 'lu'"""
    n = len(A)
    if n > 0 and is_sym(A) and all(A[i][i] > 0.0 for i in range(n)) and chol_float(A) is not None:
        return 'chol'
    return 'lu'


def rcond_est(F, n, anorm, zp):
    """RCOND (2.13.6; LAPACK dgecon with dlacn2, no interchanges, unscaled solves) transcribed one for
    one into binary64: F the factor (rows: L strictly below the diagonal, unit diagonal not stored,
    U on and above), anorm ||A||_1 of the input, zp the first zero pivot or -1. After every solve of
    steps 1-3 (each x <- U^-1 L^-1 x and each x <- L^-T U^-T x) s = sum |x[i]| in index order is
    formed, and rcond is 0 at once when s is +Inf or NaN (the user's RCOND decision of 8c: an unscaled
    solve can overflow and then meet 0 * Inf = NaN, after which the literal steps could return a finite
    value, as diag(1, 2^-1070) did); step 4 gives 0 when est is +Inf, NaN or 0."""
    if n == 0:
        return INF                                   # L-io, Decision 129 (a): order 0
    if anorm != anorm:
        return NAN                                   # ||A||_1 NaN
    if zp >= 0:
        return 0.0                                   # a recorded zero pivot
    if anorm == 0.0 or anorm == INF:
        return 0.0

    class NonFinite(Exception):
        """a solve left sum |x| +Inf or NaN: rcond is 0"""

    def asum(x):                                     # sum of the magnitudes in index order
        s = abs(x[0])
        for v in x[1:]:
            s = s + abs(v)
        return s

    def checked(x):                                  # the test after every solve
        s = asum(x)
        if s == INF or s != s:
            raise NonFinite
        return s

    def solve_n(x):                                  # x <- U^-1 L^-1 x, then the test
        for k in range(n):
            for i in range(k + 1, n):
                x[i] = x[i] - F[i][k] * x[k]
        for k in range(n - 1, -1, -1):
            x[k] = x[k] / F[k][k]
            for i in range(k):
                x[i] = x[i] - F[i][k] * x[k]
        return checked(x)

    def solve_t(x):                                  # x <- L^-T U^-T x, then the test
        for k in range(n):
            s = x[k]
            for i in range(k):
                s = s - F[i][k] * x[i]
            x[k] = s / F[k][k]
        for k in range(n - 1, -1, -1):
            s = x[k]
            for i in range(k + 1, n):
                s = s - F[i][k] * x[i]
            x[k] = s
        return checked(x)

    def sgn(v):                                      # +1 for v >= 0 (-0 included), else -1 (NaN)
        return 1.0 if v >= 0.0 else -1.0

    def idamax(x):                                   # first index of largest |x[i]|
        j, m = 0, abs(x[0])
        for i in range(1, n):
            if abs(x[i]) > m:
                j, m = i, abs(x[i])
        return j

    def estimate():                                  # steps 1-3: est
        # step 1
        x = [1.0 / float(n)] * n
        s = solve_n(x)
        if n == 1:
            return abs(x[0])
        est = s
        xi = [sgn(v) for v in x]
        x = list(xi)
        solve_t(x)
        j = idamax(x)
        it = 2
        while True:                                  # step 2
            x = [0.0] * n
            x[j] = 1.0
            s = solve_n(x)
            estold = est
            est = s
            if all(sgn(x[i]) == xi[i] for i in range(n)):
                break
            if est <= estold:
                break
            xi = [sgn(v) for v in x]
            x = list(xi)
            solve_t(x)
            jlast = j
            j = idamax(x)
            if x[jlast] != abs(x[j]) and it < RCOND_ITMAX:
                it += 1
                continue
            break
        # step 3
        x = []
        sg = 1.0
        for i in range(n):
            x.append(sg * (1.0 + float(i) / float(n - 1)))
            sg = -sg
        t = 2.0 * (solve_n(x) / float(3 * n))
        if t > est:
            est = t
        return est

    try:
        est = estimate()
    except NonFinite:
        return 0.0
    # step 4
    if est == INF or est != est or est == 0.0:
        return 0.0
    return (1.0 / est) / anorm


def rcond_of(A):
    """rcond(lu(A)) for a matrix whose factors are exact in every order (the diagonal matrices of
    la_lu_rcond; see there)"""
    F, _, zp = lu_float(A)
    return rcond_est(F, len(A), la_norm1(A), zp)


# ==================================================================================================
# ============================================================ sub-phase 8c (T1): RCOND, eig, the
# factorizations, the solves and the handles (DESIGN.md 2.13.8 "8c, factorizations and handles")
# ==================================================================================================
EPS = 2.0 ** -52                    # LANGUAGE.md 10.1: eps


def pf(fmt, *vals):
    """the bytes Sea's printf(fmt, vals...) writes (progfmt.py's exact oracle): an int is an i64, a
    bool prints as `%d` does (0/1, LANGUAGE.md 11.1), a float is an f64"""
    args = []
    for v in vals:
        if isinstance(v, bool):
            args.append(('i', int(v)))
        elif isinstance(v, int):
            args.append(('i', v))
        else:
            args.append(('f', f2b(v)))
    return progfmt.format_all(fmt, args).decode()


def zv(v):
    return [zero_norm(x) for x in v]


def col(v):
    """a vector as a list of n one-element rows (the B of the solve transcriptions)"""
    return [[x] for x in v]


def uncol(X):
    return [r[0] for r in X]


def diag(d):
    n = len(d)
    return [[d[i] if i == j else 0.0 for j in range(n)] for i in range(n)]


def matvec_exact(A, x):
    return [float(sum_frac(Fraction(A[i][k]) * Fraction(x[k]) for k in range(len(x)))) for i in range(len(A))]


def matmul_frac(A, B):
    """the exact product of two matrices of floats, as Fractions"""
    r, k, c = len(A), len(B), len(B[0])
    return [[sum_frac(Fraction(A[i][kk]) * Fraction(B[kk][j]) for kk in range(k)) for j in range(c)] for i in range(r)]


def sum_frac(it):
    t = Fraction(0)
    for v in it:
        t += v
    return t


def to_float_exact(v):
    """a Fraction that binary64 holds exactly, as that float"""
    f = float(v)
    assert Fraction(f) == v, v
    return f


def exactly(X, Y):
    """X == Y element by element with equal values (a zero of either sign equals a zero)"""
    return all(Fraction(a) == Fraction(b) for ra, rb in zip(X, Y) for a, b in zip(ra, rb))


# ------------------------------------------------------------ exact data and its derivation
# "Exact data" (2.13.8): every value a dyadic rational p / 2^e with |p| < 2^53, so it is a binary64
# value, and every product and every partial sum, in ANY order, is again such a value: then each
# IEEE operation of the factorizations, the solves and of Baysick's kernels (GEMM, gemm_sub; class R,
# any order, FMA or not) is exact and every target and variant gives the same bits. The generator
# checks this for every value with DYADIC_DEN and DYADIC_MAX below: a denominator dividing 16 and a
# magnitude below 2^40 (so any sum of at most 2^8 such terms, as a multiple of 1/16, stays below
# 2^53 / 16).
DYADIC_DEN = 16
DYADIC_MAX = Fraction(2) ** 40


def check_dyadic(v, what):
    v = Fraction(v)
    assert DYADIC_DEN % v.denominator == 0 and abs(v) < DYADIC_MAX, (what, v)


def check_sum_terms(terms, what):
    """every partial sum of these terms, in any order, is exact: each term dyadic and the sum of
    their magnitudes below DYADIC_MAX"""
    s = Fraction(0)
    for t in terms:
        check_dyadic(t, what)
        s += abs(Fraction(t))
    assert s < DYADIC_MAX, (what, s)


LU_LV = [0.0, 0.5, -0.25, 0.0, -0.5, 0.25, 0.0, 0.5, -0.5]
LU_DV = [2.0, -4.0, 1.0, 8.0, -2.0]


def lucase_parts(n):
    """the L, U and row order of `lucase(n)` (SEA_HELPERS['lucase']): L unit lower with entries in
    {0, +-1/2, +-1/4}, U upper with integer entries in -3 .. 3 and the power-of-two diagonal LU_DV,
    A[i, :] = (L @ U)[sigma(i), :] with sigma(i) = (17 i + 5) mod n (17 is prime to 3, 31, 32, 33,
    70, 5)"""
    L = [[1.0 if i == j else (LU_LV[(i * 7 + j * 13) % 9] if j < i else 0.0) for j in range(n)] for i in range(n)]
    U = [[LU_DV[i % 5] if i == j else (float((i * 5 + j * 3) % 7 - 3) if j > i else 0.0) for j in range(n)]
         for i in range(n)]
    sigma = [(17 * i + 5) % n for i in range(n)]
    assert sorted(sigma) == list(range(n))
    return L, U, sigma


def lucase(n):
    L, U, sigma = lucase_parts(n)
    for i in range(n):
        for j in range(n):
            check_sum_terms([Fraction(L[i][k]) * Fraction(U[k][j]) for k in range(n)], 'L @ U')
    M = matmul_frac(L, U)
    return [[to_float_exact(M[sigma[i]][j]) for j in range(n)] for i in range(n)]


def xint(n):
    return [float((i * 3) % 11 - 5) for i in range(n)]


def xmat(n, m):
    return [[float((i * 2 + c * 5) % 9 - 4) for c in range(m)] for i in range(n)]


CH_RD = [2.0, 1.0, 4.0, 0.5]
CH_RV = [0.0, 1.0, -0.5, 2.0, 0.0, -1.0, 0.5]


def cholcase_R(n):
    """the R of `cholcase(n)` (SEA_HELPERS['cholcase']): upper, diagonal CH_RD (powers of two, > 0, so
    R[j,j]^2 is a power of four whose sqrt is exact), above it CH_RV (dyadic)"""
    return [[CH_RD[i % 4] if i == j else (CH_RV[(i * 3 + j * 5) % 7] if j > i else 0.0) for j in range(n)]
            for i in range(n)]


def cholcase(n):
    R = cholcase_R(n)
    for i in range(n):
        for j in range(n):
            check_sum_terms([Fraction(R[k][i]) * Fraction(R[k][j]) for k in range(n)], 'R.T @ R')
    Rt = [[R[j][i] for j in range(n)] for i in range(n)]
    A = matmul_frac(Rt, R)
    return [[to_float_exact(v) for v in row] for row in A]


def verify_lu_exact(A, L, U, sigma):
    """An exact rational simulation (fractions.Fraction) of 2.13.6's LU on A = rows sigma of L U:
    at every step k the pivot candidate of largest magnitude is unique, nonzero and is the physical row
    that holds LU's row k (its value U[k,k] against L[r,k] U[k,k], |L[r,k]| <= 1/2, for the others),
    so partial pivoting picks exactly that order; the finished factor equals L and U. Every value an
    update produces for element (r, c) is A[r,c] minus a subset of the products L[r,k] U[k,c], i.e.
    the sum of the complementary subset, a multiple of 1/4 bounded by sum_k |L[r,k] U[k,c]|, which
    lucase() checked to be exact (check_sum_terms); so the blocked algorithm with any kernel, any
    grouping and FMA or not computes these bits. Returns piv."""
    n = len(A)
    F = [[Fraction(v) for v in row] for row in A]
    where = list(sigma)                        # where[i] = the LU row held by physical row i
    piv = []
    for k in range(n):
        mags = [abs(F[i][k]) for i in range(k, n)]
        m = max(mags)
        assert m != 0 and mags.count(m) == 1, ('pivot not unique', n, k)
        p = k + mags.index(m)
        assert where[p] == k, ('pivot is not LU row k', n, k)
        piv.append(p)
        F[k], F[p] = F[p], F[k]
        where[k], where[p] = where[p], where[k]
        for i in range(k + 1, n):
            F[i][k] = F[i][k] / F[k][k]
            check_dyadic(F[i][k], 'multiplier')
        for c in range(k + 1, n):
            fk = F[k][c]
            for i in range(k + 1, n):
                F[i][c] = F[i][c] - F[i][k] * fk
    for i in range(n):
        for j in range(n):
            want = L[i][j] if j < i else U[i][j]
            assert F[i][j] == Fraction(want), ('factor', n, i, j)
    # and the binary64 transcription of the same steps gives exactly these values
    Ff, pivf, zp = lu_float(A)
    assert pivf == piv and zp < 0 and exactly(Ff, [[float(v) for v in row] for row in F])
    return piv


def verify_solve_exact(L, U, piv, B, X, what):
    """2.13.6's triangular solves on the exact factor (L unit lower, U upper) with B = A X: forward,
    each partial value of row i is a subset sum of the products L[i,k] (U X)[k,c]; backward, of
    U[i,k] X[k,c]; both bounded and dyadic (check_sum_terms), so every order and kernel is exact; the
    Fraction simulation gives X, and for n <= SEA_LA_NB the binary64 transcription too"""
    n = len(L)
    m = len(B[0]) if n else 0
    UX = matmul_frac(U, X)
    for c in range(m):
        for i in range(n):
            check_sum_terms([Fraction(L[i][k]) * UX[k][c] for k in range(n)], what)
            check_sum_terms([Fraction(U[i][k]) * Fraction(X[k][c]) for k in range(n)], what)
    F = [[L[i][j] if j < i else U[i][j] for j in range(n)] for i in range(n)]
    Y = [[Fraction(v) for v in row] for row in B]
    for k in range(n):
        Y[k], Y[piv[k]] = Y[piv[k]], Y[k]
    for c in range(m):
        for k in range(n):
            for i in range(k + 1, n):
                Y[i][c] = Y[i][c] - Fraction(F[i][k]) * Y[k][c]
        for k in range(n - 1, -1, -1):
            Y[k][c] = Y[k][c] / Fraction(F[k][k])
            for i in range(k):
                Y[i][c] = Y[i][c] - Fraction(F[i][k]) * Y[k][c]
    assert all(Y[i][c] == Fraction(X[i][c]) for i in range(n) for c in range(m)), what
    if n <= LA_NB:
        assert exactly(lu_solve_float(F, piv, B), X), what


def verify_chol_exact(A, R, B, X, what):
    """Fraction simulation of 2.13.6's CHOL on A = R^T R: every pivot d is R[j,j]^2 > 0 (a power of
    four, so sqrt(d) is exact) and the factor equals R; every partial value of element (j, c) is a
    subset sum of the products R[kk,j] R[kk,c] (bounded and dyadic: cholcase() checked them). Then
    CHOL_SOLVE of B = A X: forward partial values are subset sums of R[j,i] (R X)[j,c], backward of
    R[i,k] X[k,c] (checked here); the result is X"""
    n = len(A)
    m = len(B[0]) if n else 0
    RX = matmul_frac(R, X)
    for c in range(m):
        for i in range(n):
            check_sum_terms([Fraction(R[j][i]) * RX[j][c] for j in range(n)], what)
            check_sum_terms([Fraction(R[i][k]) * Fraction(X[k][c]) for k in range(n)], what)
    W = [[Fraction(A[i][j]) if j >= i else Fraction(0) for j in range(n)] for i in range(n)]
    for j in range(n):
        d = W[j][j]
        for kk in range(j):
            d = d - W[kk][j] * W[kk][j]
        assert d > 0 and d == Fraction(R[j][j]) ** 2, (what, j, d)
        W[j][j] = Fraction(R[j][j])
        for c in range(j + 1, n):
            s = W[j][c]
            for kk in range(j):
                s = s - W[kk][j] * W[kk][c]
            W[j][c] = s / W[j][j]
            check_dyadic(W[j][c], what)
    assert all(W[i][j] == Fraction(R[i][j]) for i in range(n) for j in range(i, n)), what
    if n <= LA_NB:
        Rf = chol_float(A)
        assert Rf is not None and exactly(Rf, R), what
    Y = [[Fraction(v) for v in row] for row in B]
    for c in range(m):
        for j in range(n):
            Y[j][c] = Y[j][c] / W[j][j]
            for i in range(j + 1, n):
                Y[i][c] = Y[i][c] - W[j][i] * Y[j][c]
        for k in range(n - 1, -1, -1):
            Y[k][c] = Y[k][c] / W[k][k]
            for i in range(k):
                Y[i][c] = Y[i][c] - W[i][k] * Y[k][c]
    assert all(Y[i][c] == Fraction(X[i][c]) for i in range(n) for c in range(m)), what
    if n <= LA_NB:
        assert exactly(chol_solve_float(R, B), X), what


def exact_rhs(A, X):
    """B = A @ X on exact data (GEMV or GEMM, class E or R: exact in every order)"""
    for i in range(len(A)):
        for c in range(len(X[0])):
            check_sum_terms([Fraction(A[i][k]) * Fraction(X[k][c]) for k in range(len(X))], 'A @ X')
    return [[to_float_exact(v) for v in row] for row in matmul_frac(A, X)]


SEA_HELPERS['lucase'] = '''fn lucase(n: i64) -> f64[,] {
    let lv = [0.0, 0.5, -0.25, 0.0, -0.5, 0.25, 0.0, 0.5, -0.5]
    let dv = [2.0, -4.0, 1.0, 8.0, -2.0]
    var L = zeros(n, n)
    var U = zeros(n, n)
    for i in 0..n {
        L[i, i] = 1.0
        U[i, i] = dv[i % 5]
        for j in 0..i {
            L[i, j] = lv[(i * 7 + j * 13) % 9]
        }
        for j in i + 1..n {
            U[i, j] = f64((i * 5 + j * 3) % 7 - 3)
        }
    }
    let M = L @ U
    var A = zeros(n, n)
    for i in 0..n {
        A[i, :] = M[(17 * i + 5) % n, :]
    }
    return A
}'''
SEA_HELPERS['cholcase'] = '''fn cholcase(n: i64) -> f64[,] {
    let rd = [2.0, 1.0, 4.0, 0.5]
    let rv = [0.0, 1.0, -0.5, 2.0, 0.0, -1.0, 0.5]
    var R = zeros(n, n)
    for i in 0..n {
        R[i, i] = rd[i % 4]
        for j in i + 1..n {
            R[i, j] = rv[(i * 3 + j * 5) % 7]
        }
    }
    return R.T @ R
}'''
SEA_HELPERS['xint'] = '''fn xint(n: i64) -> f64[] {
    var x = zeros(n)
    for i in 0..n {
        x[i] = f64((i * 3) % 11 - 5)
    }
    return x
}'''
SEA_HELPERS['xmat'] = '''fn xmat(n: i64, m: i64) -> f64[,] {
    var X = zeros(n, m)
    for i in 0..n {
        for c in 0..m {
            X[i, c] = f64((i * 2 + c * 5) % 9 - 4)
        }
    }
    return X
}'''

EXACT_LINES = ['exact data (DESIGN.md 2.13.8): every value, product and partial sum is a binary64 dyadic in every',
               'order and grouping, so every target, variant and kernel gives these bits; checked by an exact Fraction',
               'simulation in tests/vectors/la8_cases.py']


# ------------------------------------------------------------ programs/la_lu_*
def la_lu_exact():
    ns = [3, 31, 32, 33, 70]
    exp = []
    for n in ns:
        L, U, sigma = lucase_parts(n)
        A = lucase(n)
        assert not is_sym(A)                       # solve(A, b) takes the LU path
        piv = verify_lu_exact(A, L, U, sigma)
        x, X = xint(n), xmat(n, 4)
        b = uncol(exact_rhs(A, col(x)))
        B = exact_rhs(A, X)
        verify_solve_exact(L, U, piv, col(b), col(x), 'la_lu_exact b')
        verify_solve_exact(L, U, piv, B, X, 'la_lu_exact B')
        exp.append(pf('%d %d %g %d %g %d %g\n', n, 0, 0.0, 0, 0.0, 0, 0.0))
    body = ['for n in [3, 31, 32, 33, 70] {',
            '    let A = lucase(n)',
            '    let x = xint(n)',
            '    let X = xmat(n, 4)',
            '    let b = A @ x',
            '    let B = A @ X',
            '    let F = lu(A)',
            '    let xh = solve(F, b)',
            '    let Xh = solve(F, B)',
            '    let xa = solve(A, b)',
            '    let Q = Xh != X',
            '    let E = abs(Xh - X)',
            '    printf("%d %d %g %d %g %d %g\\n", n, nnz(xh != x), max(abs(xh - x)), nnz(Q.flat), max(E.flat),',
            '           nnz(xa != x), max(abs(xa - x)))',
            '}']
    program('la_lu_exact',
            ['lu, solve(F, b), solve(F, B) and solve(A, b) on exact data (LANGUAGE.md 10.8; DESIGN.md 2.13.6 LU and the',
             'triangular solves, 2.13.8): A = P L U built by lucase(n) from a unit lower L with entries in {0, +-1/2,',
             '+-1/4}, an upper U with integer entries in -3 .. 3 and the power-of-two diagonal 2, -4, 1, 8, -2, and',
             'the fixed row order sigma(i) = (17 i + 5) mod n; b = A @ x and B = A @ X for integer x and X. At every',
             'step the pivot candidate of largest magnitude is unique and is LU\'s row k (|l| <= 1/2 < 1), so partial',
             'pivoting picks exactly that order, every elimination step is exact and the solutions are x and X: each',
             'line is n, then for solve(F, b), solve(F, B) and solve(A, b) (A is not symmetric: the LU path) the',
             'count of elements differing from x or X and the largest |difference|, all 0; n = 3, 31, 32, 33 and 70',
             'cross SEA_LA_NB - 1, SEA_LA_NB, SEA_LA_NB + 1 and two panels;'] + EXACT_LINES,
            ['lucase', 'xint', 'xmat'], body, exp)


def la_lu_rcond():
    specials = [('zeros(0, 0)', []),
                ('An', [[0.0, 1.0], [NAN, 1.0]]),
                ('Am', [[1.0, NAN], [0.0, 1.0]]),
                ('As', [[1.0, 2.0], [2.0, 4.0]]),
                ('Az', [[0.0] * 3 for _ in range(3)]),
                ('Ai', [[INF, 0.0], [0.0, 1.0]]),
                ('Au', [[5e-324, 0.0], [0.0, 1.0]]),
                ('Ab', [[1.0, 0.0], [0.0, 2.0 ** -1070]])]
    want = [INF, NAN, NAN, 0.0, 0.0, 0.0, 0.0, 0.0]
    exp = []
    body = []
    for (name, A), w in zip(specials, want):
        r = rcond_of(A)
        assert (r != r and w != w) or f2b(r) == f2b(w), (name, r)
        if name == 'Az':
            body.append('let Az = zeros(3, 3)')
        elif name != 'zeros(0, 0)':
            body.append('let %s = %s' % (name, mat_lit(A)))
        body.append('printf("%%g\\n", rcond(lu(%s)))' % name)
        exp.append(pf('%g\n', r))
    # the zero pivot and the NaN norm of An, the NaN U[1,1] of Am, the zero pivot of As (2 - 0.5*4)
    assert lu_float(specials[1][1])[2] == 0 and la_norm1(specials[1][1]) != la_norm1(specials[1][1])
    assert lu_float(specials[2][1])[2] < 0 and lu_float(specials[3][1])[2] == 1
    p2 = [0.125, 0.25, 0.5, 1.0, 2.0, 4.0, 8.0]
    ident_not_one = []
    for n in range(1, 81):
        I = diag([1.0] * n)
        D = diag([(-1.0 if i % 3 == 1 else 1.0) * p2[(3 * i) % 7] for i in range(n)])
        ri, rd = rcond_of(I), rcond_of(D)
        if ri != 1.0:
            ident_not_one.append(n)
        exp.append(pf('%d %.17g %.17g\n', n, ri, rd))
    # DESIGN.md 2.13.6 / 2.13.8: the identity's rcond is not 1 at these orders
    assert ident_not_one == [22, 26, 44, 60, 63, 68, 74, 77, 78], ident_not_one
    body += ['let p2 = [0.125, 0.25, 0.5, 1.0, 2.0, 4.0, 8.0]',
             'for n in 1..=80 {',
             '    var I = zeros(n, n)',
             '    var D = zeros(n, n)',
             '    for i in 0..n {',
             '        I[i, i] = 1.0',
             '        var d = p2[(3 * i) % 7]',
             '        if i % 3 == 1 {',
             '            d = -d',
             '        }',
             '        D[i, i] = d',
             '    }',
             '    printf("%d %.17g %.17g\\n", n, rcond(lu(I)), rcond(lu(D)))',
             '}']
    program('la_lu_rcond',
            ['rcond(lu(A)) (LANGUAGE.md 10.8; DESIGN.md 2.13.6 RCOND, L-io, L-je, Decision 129 (a)): first the special',
             'values in their order: order 0 is Inf; [0, 1; NaN, 1] has a zero pivot (the NaN never wins, L-in) and',
             '||A||_1 NaN: NaN, the NaN coming first; [1, NaN; 0, 1] (NaN norm, no zero pivot): NaN; the singular',
             '[1, 2; 2, 4] (pivot 2 - 0.5 * 4 = 0) and zeros(3, 3): 0; ||A||_1 = Inf ([Inf, 0; 0, 1]): 0;',
             'diag(5e-324, 1): step 1\'s first solve gives 0.5 / 5e-324 = Inf, so sum |x| is Inf and rcond 0 at',
             'once; diag(1, 2^-1070): step 1 is finite (2^1069), the L^-T U^-T solve gives 1 / 2^-1070 = Inf: 0 at',
             'once (without that test 0 * Inf = NaN would follow and the literal steps returned 1). Then, for',
             'n = 1 .. 80, the identity and the diagonal matrix of +-1/8 .. 8 (p2[(3 i) mod 7], negated when',
             'i mod 3 = 1): their factors are exact in every order (L and U off the diagonal are +-0, which no',
             'step of the estimator can see while x stays finite), and each value is',
             'computed from 2.13.6\'s steps transcribed into binary64 by tests/vectors/la8_cases.py (rcond_est),',
             'printed with %.17g: the identity gives 1 - 2^-52 at n = 22, 26, 44, 60, 68, 74, 77, 78 and',
             '1 - 2^-51 at n = 63 (step 3\'s rounded t exceeds 1), so no order is assumed exact'],
            [], body, exp)


def la_lu_singular():
    cases = [('A1', [[1.0, 2.0], [2.0, 4.0]]),
             ('A2', [[0.0] * 3 for _ in range(3)]),
             ('A3', [[1.0] * 4 for _ in range(4)]),
             ('A4', [[2.0, 0.0, 1.0], [1.0, 0.0, 3.0], [4.0, 0.0, 5.0]])]
    zps = [1, 0, 1, 1]
    body = []
    exp = []
    for (name, A), zp in zip(cases, zps):
        F, piv, z = lu_float(A)
        assert z == zp, (name, z)
        if name == 'A2':
            body.append('let A2 = zeros(3, 3)')
        elif name == 'A3':
            body.append('let A3 = ones(4, 4)')
        else:
            body.append('let %s = %s' % (name, mat_lit(A)))
        body += ['let F%s = lu(%s)' % (name[1], name),
                 'printf("lu %s done %%g\\n", rcond(F%s))' % (name, name[1])]
        exp.append(pf('lu %s done %%g\n' % name, rcond_est(F, len(A), la_norm1(A), z)))
    program('la_lu_singular',
            ['lu of a singular matrix completes (LANGUAGE.md 10.8; DESIGN.md 2.13.5 LU "never fails for a singular A",',
             'L-in: an exactly zero pivot leaves its column unscaled and the factorization continues): [1, 2; 2, 4]',
             '(zero pivot at k = 1), zeros(3, 3) (at k = 0), ones(4, 4) (at k = 1) and a matrix with a zero column (at',
             'k = 1); each handle exists and its rcond is 0 (L-io: a recorded zero pivot); by hand'],
            [], body, exp)


def la_lu_nonfinite():
    cases = [('Ab', [[2.0, 1.0], [1.0, 3.0]], [INF, 1.0], 'Ab'),
             ('Ab', None, [NAN, 1.0], 'Ab'),
             ('Ac', [[2.0, NAN], [1.0, 1.0]], [1.0, 1.0], 'Ac'),
             ('Ad', [[INF, 1.0], [1.0, 1.0]], [1.0, 2.0], 'Ad'),
             ('Ae', [[NAN, 1.0], [2.0, 1.0]], [1.0, 1.0], 'Ae')]
    mats = {}
    body = []
    exp = []
    for k, (name, A, b, _) in enumerate(cases):
        if A is not None:
            mats[name] = A
            body.append('let %s = %s' % (name, mat_lit(A)))
            body.append('let F%s = lu(%s)' % (name[1], name))
        A = mats[name]
        F, piv, zp = lu_float(A)
        assert zp < 0
        x = uncol(lu_solve_float(F, piv, col(b)))
        body.append('pvz(solve(F%s, %s))' % (name[1], vec_lit(b)))
        exp.append(pv_line(zv(x)))
    want = [[INF, -INF], [NAN, NAN], [NAN, NAN], [0.0, 2.0], [NAN, NAN]]
    for line, w in zip(exp, want):
        assert line == pv_line(w), (line, w)
    # rcond: NaN for Ac (||A||_1 NaN), 0 for Ad (||A||_1 Inf), NaN for Ae
    for name in ['Ac', 'Ad', 'Ae']:
        body.append('printf("%%g\\n", rcond(F%s))' % name[1])
        exp.append(pf('%g\n', rcond_of(mats[name])))
    assert exp[-3:] == ['NaN\n', '0\n', 'NaN\n']
    # solve(A, b) of the NaN-first column: not symmetric, LU, no singular error
    assert not is_sym(mats['Ae'])
    body.append('pvz(solve(Ae, [1.0, 1.0]))')
    exp.append(pv_line([NAN, NAN]))
    program('la_lu_nonfinite',
            ['Inf and NaN propagate through lu and solve (LANGUAGE.md 10.8; DESIGN.md 2.13.2 "Non-finite operands", L-in,',
             'L-io): [2, 1; 1, 3] with b = [Inf, 1] gives [Inf, -Inf] (Inf - 0.5 Inf, then (Inf + Inf) / 2) and with',
             'b = [NaN, 1] NaN NaN; [2, NaN; 1, 1] (U[1,1] = 1 - 0.5 NaN) NaN NaN; [Inf, 1; 1, 1] (l = 1 / Inf = 0) gives',
             '[-1 / Inf, 2], printed as x + 0.0: 0 2; [NaN, 1; 2, 1]: the NaN is the first candidate, so it is the pivot',
             '(Decision 129 (a): never chosen unless it is first), no zero pivot, NaN NaN for solve(F, b) and solve(A, b);',
             'rcond: NaN (||A||_1 NaN), 0 (||A||_1 Inf), NaN; n = 2: one panel, every operation pinned (2.13.6), the',
             'non-finite results the same in any order; by hand, checked by tests/vectors/la8_cases.py'],
            ['pvz'], body, exp)


def la_lu_empty():
    body = ['let F = lu(zeros(0, 0))',
            'printf("%g\\n", rcond(F))',
            'pv(solve(F, zeros(0)))',
            'pm(solve(F, zeros(0, 3)))',
            'let C = chol(zeros(0, 0))',
            'pv(solve(C, zeros(0)))',
            'pm(solve(C, zeros(0, 2)))',
            'pv(solve(zeros(0, 0), zeros(0)))',
            'pm(solve(zeros(0, 0), zeros(0, 4)))']
    program('la_lu_empty',
            ['order 0 (LANGUAGE.md 10.8; DESIGN.md 2.13.2 "Empty operands", L-ik, L-io): lu and chol of a 0 x 0 matrix',
             'give handles of order 0, rcond of the Lu is Inf, and solve with n = 0 (both handle forms and solve(A, B))',
             'gives the empty result of B\'s shape: 0 for a vector, 0 x m for a matrix; by hand'],
            ['pv', 'pm'], body,
            ['Inf\n', pv_line([]), pm_line([], 0, 3), pv_line([]), pm_line([], 0, 2), pv_line([]), pm_line([], 0, 4)])


def la_lu_share():
    A1 = [[4.0, 1.0], [2.0, 8.0]]
    A2 = [[2.0, 0.0], [0.0, 4.0]]
    b = [6.0, 18.0]

    def sol(A):
        F, piv, zp = lu_float(A)
        x = uncol(lu_solve_float(F, piv, col(b)))
        assert exactly(col(x), col(uncol(lu_solve_frac(A, b))))
        return pv_line(zv(x))

    x1, x2 = sol(A1), sol(A2)
    assert x1 == pv_line([1.0, 2.0]) and x2 == pv_line([3.0, 4.5])
    A6 = [[6.0, 0.0], [0.0, 12.0]]
    x6 = sol(A6)
    assert x6 == pv_line([1.0, 1.5])
    r2 = rcond_of(A2)
    assert r2 == 0.5
    body = ['struct Fac {',
            '    f: Lu',
            '    n: i64',
            '}',
            'fn make(A: f64[,]) -> Lu {',
            '    return lu(A)',
            '}',
            'fn apply(F: Lu, b: f64[]) -> f64[] {',
            '    return solve(F, b)',
            '}',
            'fn relay(F: Lu) -> Lu {',
            '    let G = F',
            '    return G',
            '}',
            'fn both(A: f64[,]) -> (Lu, f64) {',
            '    let F = lu(A)',
            '    return (F, rcond(F))',
            '}',
            'fn swap(ref a: Lu, ref b: Lu) {',
            '    let t = a',
            '    a = b',
            '    b = t',
            '}',
            'let b = [6.0, 18.0]',
            'let A1: f64[,] = %s' % mat_lit(A1),
            'var F = make(A1)',
            'let G = F',
            'let s = Fac { f: G, n: 2 }',
            'pvz(apply(F, b))',
            'F = lu(%s)' % mat_lit(A2),
            'pvz(apply(F, b))',
            'pvz(apply(G, b))',
            'pvz(solve(s.f, b))',
            'let H = relay(s.f)',
            'pvz(solve(H, b))',
            'var t = s',
            't.f = F',
            'pvz(solve(t.f, b))',
            'pvz(solve(s.f, b))',
            'let (K, r) = both(%s)' % mat_lit(A2),
            'printf("%.17g\\n", r)',
            'pvz(solve(K, b))',
            'var P = G',
            'var Q = F',
            'swap(ref P, ref Q)',
            'pvz(solve(P, b))',
            'pvz(solve(Q, b))',
            'for k in 0..3 {',
            '    F = lu(%s * f64(k + 1))' % mat_lit(A2),
            '}',
            'pvz(solve(F, b))',
            'let W = if s.n > 1 { s.f } else { F }',
            'pvz(solve(W, b))',
            'printf("%d\\n", s.n)']
    exp = [x1, x2, x1, x1, x1, x2, x1, pf('%.17g\n', r2), x2, x2, x1, x6, x1, '2\n']
    program('la_lu_share',
            ['handles are references (LANGUAGE.md 4.1; DESIGN.md 2.13.2 "Handles", 2.13.4 rules 15 and 16, L-is): an Lu',
             'returned by a function, copied, stored in a struct field, passed, returned again, put in a tuple with',
             'its rcond, swapped through ref parameters, reassigned in a loop and chosen by an if expression; each',
             'solve uses the factor its value refers to (reassigning F leaves G and s.f with the first one), and the',
             'heap check (every program runs with SEA_HEAP_CHECK=1) finds no live object at the end. [4, 1; 2, 8] and',
             'b = [6, 18]: pivot 4, l = 0.5, U[1,1] = 7.5, x = [1, 2]; diag(2, 4): [3, 4.5]; diag(6, 12): [1, 1.5];',
             'rcond(lu(diag(2, 4))) = (1 / 0.5) / 4 = 0.5 by 2.13.6\'s steps (est = 0.5, step 3\'s t = 1/3); exact',
             'data, printed as x + 0.0; by hand, checked by tests/vectors/la8_cases.py'],
            ['pvz'], body, exp)


def lu_solve_frac(A, b):
    """the exact solution of A x = b by Fractions (Gaussian elimination, any pivot): the check that the
    by-hand values above are the solutions"""
    n = len(A)
    M = [[Fraction(v) for v in A[i]] + [Fraction(b[i])] for i in range(n)]
    for k in range(n):
        p = next(i for i in range(k, n) if M[i][k] != 0)
        M[k], M[p] = M[p], M[k]
        for i in range(n):
            if i != k:
                f = M[i][k] / M[k][k]
                M[i] = [M[i][j] - f * M[k][j] for j in range(n + 1)]
    return [[M[i][n] / M[i][i]] for i in range(n)]


# ------------------------------------------------------------ programs/la_chol_*
def la_chol_exact():
    exp = []
    for n in [3, 70]:
        R = cholcase_R(n)
        A = cholcase(n)
        assert is_sym(A) and all(A[i][i] > 0.0 for i in range(n))     # solve(A, B): the Cholesky path
        X = xmat(n, 40)
        B = exact_rhs(A, X)
        verify_chol_exact(A, R, B, X, 'la_chol_exact %d' % n)
        exp.append(pf('%d %d %g %d %g\n', n, 0, 0.0, 0, 0.0))
    body = ['for n in [3, 70] {',
            '    let A = cholcase(n)',
            '    let X = xmat(n, 40)',
            '    let B = A @ X',
            '    let C = chol(A)',
            '    let Xc = solve(C, B)',
            '    let Xa = solve(A, B)',
            '    let Qc = Xc != X',
            '    let Ec = abs(Xc - X)',
            '    let Qa = Xa != X',
            '    let Ea = abs(Xa - X)',
            '    printf("%d %d %g %d %g\\n", n, nnz(Qc.flat), max(Ec.flat), nnz(Qa.flat), max(Ea.flat))',
            '}']
    program('la_chol_exact',
            ['chol and solve on exact data (LANGUAGE.md 10.8; DESIGN.md 2.13.6 CHOL, CHOL_SOLVE, SOLVE, 2.13.8): A = R^T R',
             'built by cholcase(n) from an upper R with the power-of-two diagonal 2, 1, 4, 1/2 (positive: each pivot',
             'd is the power of four R[j,j]^2 and sqrt(d) is exact) and dyadic entries in {0, +-1/2, +-1, 2} above it,',
             'B = A @ X for an integer X with 40 columns; chol(A) reproduces R exactly and solve(chol(A), B) and',
             'solve(A, B) (A exactly symmetric with a positive diagonal: the Cholesky path) give X: each line is n,',
             'then for both the count of differing elements and the largest |difference|, all 0; n = 3 and 70 (three',
             'panels, the trailing updates through gemm_sub with the transposed panel W);'] + EXACT_LINES,
            ['cholcase', 'xmat'], body, exp)


def la_chol_upper():
    n = 5
    R = cholcase_R(n)
    A = cholcase(n)
    x = xint(n)
    b = uncol(exact_rhs(A, col(x)))
    verify_chol_exact(A, R, col(b), col(x), 'la_chol_upper')
    Anan = [[A[i][j] if j >= i else NAN for j in range(n)] for i in range(n)]
    assert exactly(chol_float(Anan), R)            # the strict lower triangle is never read
    body = ['var A = cholcase(5)',
            'for i in 0..5 {',
            '    for j in 0..i {',
            '        A[i, j] = nan',
            '    }',
            '}',
            'let x = xint(5)',
            'let b = cholcase(5) @ x',
            'let F = chol(A)',
            'let xh = solve(F, b)',
            'printf("%d %g\\n", nnz(xh != x), max(abs(xh - x)))',
            'pvz(xh)']
    program('la_chol_upper',
            ['chol reads the upper triangle of A only (LANGUAGE.md 10.8; DESIGN.md 2.13.6 CHOL, L-im, L-jf): cholcase(5)',
             'with NaN in every element below the diagonal still factors to R exactly, and solve(chol(A), b) with',
             'b = R^T R x gives x = [-5, -2, 1, 4, -4] (no NaN reaches the result);'] + EXACT_LINES,
            ['cholcase', 'xint', 'pvz'], body, [pf('%d %g\n', 0, 0.0), pv_line(zv(x))])


RHS_A = [[4.0, 2.0, 0.0], [2.0, 5.0, 2.0], [0.0, 2.0, 5.0]]
RHS_R = [[2.0, 1.0, 0.0], [0.0, 2.0, 1.0], [0.0, 0.0, 2.0]]


def la_chol_rhs():
    A, R = RHS_A, RHS_R
    x = [1.0, -1.0, 2.0]
    X2 = [[1.0, 0.0], [-1.0, 3.0], [2.0, -2.0]]
    b = uncol(exact_rhs(A, col(x)))
    B2 = exact_rhs(A, X2)
    assert b == [2.0, 1.0, 8.0] and B2 == [[2.0, 6.0], [1.0, 11.0], [8.0, -4.0]]
    verify_chol_exact(A, R, col(b), col(x), 'la_chol_rhs b')
    verify_chol_exact(A, R, B2, X2, 'la_chol_rhs B')
    body = ['let A = ' + mat_lit(A),
            'let F = chol(A)',
            'pvz(solve(F, ' + vec_lit(b) + '))',
            'pmz(solve(F, ' + mat_lit(col(b)) + '))',
            'pmz(solve(F, ' + mat_lit(B2) + '))',
            'pmz(solve(F, zeros(3, 0)))',
            'let b = ' + vec_lit(b),
            'let x = solve(F, b)',
            'printf("%d %.17g\\n", len(x), x[2])']
    program('la_chol_rhs',
            ['solve(F, B) of a Chol F with a vector and a matrix B (LANGUAGE.md 10.8: a vector gives a vector, a matrix',
             'a matrix, also with one column; DESIGN.md 2.13.5 CHOL_SOLVE, L-ik): A = [4, 2, 0; 2, 5, 2; 0, 2, 5] = R^T R',
             'with R = [2, 1, 0; 0, 2, 1; 0, 0, 2]; b = A [1, -1, 2] = [2, 1, 8]; B = [2, 6; 1, 11; 8, -4] = A [1, 0;',
             '-1, 3; 2, -2]; a 3 x 0 B gives the 3 x 0 result; exact data, printed as x + 0.0; by hand, checked by',
             'tests/vectors/la8_cases.py'],
            ['pvz', 'pmz'], body,
            [pv_line(x), pm_line(col(x), 3, 1), pm_line(zm(X2), 3, 2), pm_line([[], [], []], 3, 0),
             pf('%d %.17g\n', 3, 2.0)])


# ------------------------------------------------------------ programs/la_solve_*
def hilb4():
    return [[1.0 / float(i + j + 1) + (4.0 if i == j else 0.0) for j in range(4)] for i in range(4)]


def paths_differ(A, B):
    """the Cholesky and the LU paths, transcribed for n <= SEA_LA_NB (one panel, no kernel: every
    operation pinned, L-it), give different bits for this A and B, so a test comparing solve(A, B)
    with solve(chol(A), B) bit for bit can tell the paths apart"""
    R = chol_float(A)
    F, piv, zp = lu_float(A)
    Xc = chol_solve_float(R, B)
    Xl = lu_solve_float(F, piv, B)
    return any(f2b(a) != f2b(c) for ra, rc in zip(Xc, Xl) for a, c in zip(ra, rc))


def la_solve_sym():
    n = 6
    R = cholcase_R(n)
    A = cholcase(n)
    x = xint(n)
    b = uncol(exact_rhs(A, col(x)))
    verify_chol_exact(A, R, col(b), col(x), 'la_solve_sym')
    H = hilb4()
    hb = [1.0, 2.0, 3.0, 4.0]
    HB = [[1.0, 2.0], [3.0, 4.0], [5.0, 6.0], [7.0, 8.0]]
    assert solve_path(H) == 'chol' and paths_differ(H, col(hb)) and paths_differ(H, HB)
    body = ['let A = cholcase(6)',
            'let x = xint(6)',
            'let xa = solve(A, A @ x)',
            'printf("%d %g\\n", nnz(xa != x), max(abs(xa - x)))',
            'var H = zeros(4, 4)',
            'for i in 0..4 {',
            '    for j in 0..4 {',
            '        H[i, j] = 1.0 / f64(i + j + 1)',
            '    }',
            '    H[i, i] = H[i, i] + 4.0',
            '}',
            'let hb = ' + vec_lit(hb),
            'let C = chol(H)',
            'printf("%d\\n", nnz(solve(H, hb) != solve(C, hb)))',
            'let HB = ' + mat_lit(HB),
            'let Q = solve(H, HB) != solve(C, HB)',
            'printf("%d\\n", nnz(Q.flat))']
    program('la_solve_sym',
            ['solve(A, B) of an exactly symmetric A with a positive diagonal takes the Cholesky path (LANGUAGE.md 10.8;',
             'DESIGN.md 2.13.6 SOLVE: "exactly what solve(chol(A), B) would give for the path taken"): cholcase(6)',
             'with b = A @ x gives x exactly (0 differing, largest difference 0); the Hilbert matrix plus 4 I (n = 4)',
             'with a vector and a 4 x 2 B gives the bits of solve(chol(H), B) (0 differing elements); for H the',
             'Cholesky and LU paths of 2.13.6 (n <= SEA_LA_NB, every operation pinned) differ in the last bits, so the',
             'comparison tells the paths apart (asserted by tests/vectors/la8_cases.py)'],
            ['cholcase', 'xint'], body, [pf('%d %g\n', 0, 0.0), '0\n', '0\n'])


def la_solve_indef():
    A = [[1.0, 2.0], [2.0, 1.0]]
    b = [-1.0, 1.0]
    assert is_sym(A) and chol_float(A) is None and solve_path(A) == 'lu'
    F, piv, zp = lu_float(A)
    x = uncol(lu_solve_float(F, piv, col(b)))
    assert x == [1.0, -1.0]
    A3 = [[1.0, 0.5, 2.0], [0.5, 2.0, 1.0], [2.0, 1.0, 1.5]]
    assert is_sym(A3) and all(A3[i][i] > 0 for i in range(3)) and chol_float(A3) is None
    body = ['let A = ' + mat_lit(A),
            'let b = ' + vec_lit(b),
            'pvz(solve(A, b))',
            'printf("%d\\n", nnz(solve(A, b) != solve(lu(A), b)))',
            'let A3 = ' + mat_lit(A3),
            'let b3 = [1.0, -1.0, 2.0]',
            'printf("%d\\n", nnz(solve(A3, b3) != solve(lu(A3), b3)))']
    program('la_solve_indef',
            ['solve(A, B) of a symmetric matrix with a positive diagonal that is not positive definite falls back to LU',
             'without an error (LANGUAGE.md 10.8; DESIGN.md 2.13.6 SOLVE, L-jb): [1, 2; 2, 1] (the Cholesky attempt',
             'stops at d = 1 - 2 * 2 = -3) with b = [-1, 1] gives [1, -1] exactly (pivot 2, l = 0.5, U[1,1] = 1.5) and',
             'the bits of solve(lu(A), b); [1, 0.5, 2; 0.5, 2, 1; 2, 1, 1.5] stops at its third pivot (d = -2.5) and',
             'gives the bits of solve(lu(A), b) (0 differing elements); printed as x + 0.0; by hand, checked by',
             'tests/vectors/la8_cases.py'],
            ['pvz'], body, [pv_line(x), '0\n', '0\n'])


def la_solve_nonsym():
    n = 5
    L, U, sigma = lucase_parts(n)
    A = lucase(n)
    assert not is_sym(A)
    piv = verify_lu_exact(A, L, U, sigma)
    x, X = xint(n), xmat(n, 3)
    verify_solve_exact(L, U, piv, exact_rhs(A, col(x)), col(x), 'la_solve_nonsym x')
    verify_solve_exact(L, U, piv, exact_rhs(A, X), X, 'la_solve_nonsym X')
    Z = [[0.0, 1.0], [1.0, 0.0]]
    N = [[-2.0, 1.0], [1.0, -4.0]]
    res = []
    for M, bb in [(Z, [3.0, 5.0]), (N, [0.0, -7.0])]:
        assert is_sym(M) and solve_path(M) == 'lu'
        Fm, pm_, zp = lu_float(M)
        res.append(uncol(lu_solve_float(Fm, pm_, col(bb))))
    assert res == [[5.0, 3.0], [1.0, 2.0]]
    body = ['let A = lucase(5)',
            'let x = xint(5)',
            'let X = xmat(5, 3)',
            'let b = A @ x',
            'let xa = solve(A, b)',
            'printf("%d %g\\n", nnz(xa != x), max(abs(xa - x)))',
            'let Q = solve(A, A @ X) != X',
            'printf("%d\\n", nnz(Q.flat))',
            'printf("%d\\n", nnz(xa != solve(lu(A), b)))',
            'pvz(solve(' + mat_lit(Z) + ', [3.0, 5.0]))',
            'pvz(solve(' + mat_lit(N) + ', [0.0, -7.0]))']
    program('la_solve_nonsym',
            ['solve(A, B) takes LU at once when A is not symmetric or its diagonal is not positive (LANGUAGE.md 10.8;',
             'DESIGN.md 2.13.6 SOLVE): lucase(5) (not symmetric, exact as in la_lu_exact) with a vector and a 5 x 3 B',
             'gives x and X exactly and the bits of solve(lu(A), b); the symmetric [0, 1; 1, 0] (zero diagonal: rows',
             'exchanged, [5, 3]) and [-2, 1; 1, -4] (negative diagonal: l = -0.5, U[1,1] = -3.5, [1, 2]) go to LU too;',
             'printed as x + 0.0;'] + EXACT_LINES,
            ['lucase', 'xint', 'xmat', 'pvz'], body,
            [pf('%d %g\n', 0, 0.0), '0\n', '0\n', pv_line(res[0]), pv_line(res[1])])


def la_solve_zero_pair():
    A = [[4.0, 1.0, 0.0], [1.0, 3.0, 1.0], [NEG0, 1.0, 2.0]]
    b = [1.0, 2.0, 3.0]
    assert is_sym(A) and solve_path(A) == 'chol' and paths_differ(A, col(b))
    N = [[4.0, NAN], [NAN, 3.0]]
    assert is_sym(N) and chol_float(N) is None
    F, piv, zp = lu_float(N)
    xn = uncol(lu_solve_float(F, piv, col([1.0, 1.0])))
    assert all(v != v for v in xn)
    body = ['let A = ' + mat_lit(A),
            'let b = ' + vec_lit(b),
            'printf("%d\\n", nnz(solve(A, b) != solve(chol(A), b)))',
            'let N = ' + mat_lit(N),
            'pv(solve(N, [1.0, 1.0]))']
    program('la_solve_zero_pair',
            ['the symmetric test of solve(A, B) (LANGUAGE.md 10.8, Decision 123 (a): A[i,j] == A[j,i] or both NaN): a',
             'matrix whose only unequal-looking pair is +0 / -0 is symmetric and takes the Cholesky path, giving the',
             'bits of solve(chol(A), b) (the two paths differ for this A and b, asserted by',
             'tests/vectors/la8_cases.py); [4, NaN; NaN, 3] is symmetric (a NaN pair) with a positive diagonal, so',
             'the Cholesky attempt runs, stops at the NaN pivot 3 - NaN^2, and LU propagates the NaN: NaN NaN'],
            ['pv'], body, ['0\n', pv_line(xn)])


def la_solve_fixed():
    c3 = [1.0, 2.0, 4.0]
    A3 = [[c * c, c, 1.0] for c in c3]
    J3 = [2.0, 3.0, 11.0]
    B2 = [[2.0, 1.0], [3.0, 1.0], [11.0, 1.0]]
    X2 = [[1.0, 0.0], [-2.0, 0.0], [3.0, 1.0]]
    assert not is_sym(A3)
    F, piv, zp = lu_float(A3)
    assert exactly(lu_solve_float(F, piv, col(J3)), col([1.0, -2.0, 3.0]))
    assert exactly(lu_solve_float(F, piv, B2), X2)
    for v in [x for row in F for x in row]:
        check_dyadic(v, 'la_solve_fixed factor')
    body = ['let c3 = [1.0, 2.0, 4.0]',
            'let A3 = [(c3 * c3).col, c3.col, [1.0, 1.0, 1.0].col]',
            'let J3 = ' + vec_lit(J3),
            'pvz(solve(A3, J3))',
            'let Fx = lu(A3)',
            'pvz(solve(Fx, J3))',
            'let B2 = ' + mat_lit(B2),
            'pmz(solve(A3, B2))',
            'let A3b: f64[3,3] = ' + mat_lit(A3),
            'pvz(solve(A3b, J3))']
    program('la_solve_fixed',
            ['W3\'s parabolic refinement [c3(:).^2, c3(:), ones(3, 1)] \\ J3(:) (DESIGN.md 2.13.1) from fixed-size values:',
             'a fixed-size f64[3,3] built by concatenating columns, and a fixed-size right-hand side, used as the',
             'dynamic arrays they equal (L-iq, dyn); the results are dynamic. c3 = [1, 2, 4] gives [1, 1, 1; 4, 2, 1;',
             '16, 4, 1] (not symmetric: LU); pivots 16 then 1 (l = 1/4, 1/16, 3/4, U[2,2] = 3/8), all dyadic, so J3 =',
             '[2, 3, 11] gives [1, -2, 3] exactly, by solve(A, b), solve(lu(A), b), a 3 x 2 B (second column A [0, 0,',
             '1]) and the literal form; printed as x + 0.0; by hand, checked by tests/vectors/la8_cases.py'],
            ['pvz', 'pmz'], body,
            [pv_line([1.0, -2.0, 3.0]), pv_line([1.0, -2.0, 3.0]), pm_line(zm(X2), 3, 2), pv_line([1.0, -2.0, 3.0])])


def la_solve_i64():
    Ai = [[4.0, 2.0], [2.0, 5.0]]
    assert solve_path(Ai) == 'chol'
    R = chol_float(Ai)
    assert R == [[2.0, 1.0], [0.0, 2.0]]
    assert chol_solve_float(R, col([2.0, -3.0])) == col([1.0, -1.0])
    F, piv, zp = lu_float(Ai)
    assert lu_solve_float(F, piv, col([2.0, -3.0])) == col([1.0, -1.0])
    big = float(9007199254740993)
    assert big == 2.0 ** 53
    Bi = [[big, 1.0], [0.0, 1.0]]
    assert solve_path(Bi) == 'lu'
    Fb, pb, zb = lu_float(Bi)
    xb = uncol(lu_solve_float(Fb, pb, col([float(9007199254740994), 0.0])))
    assert xb == [1.0 + 2.0 ** -52, 0.0]
    body = ['let Ai: i64[,] = [4, 2; 2, 5]',
            'let bi: i64[] = [2, -3]',
            'pvz(solve(Ai, bi))',
            'pvz(solve(lu(Ai), [2.0, -3.0]))',
            'pvz(solve(chol(Ai), bi))',
            'let Bi = [9007199254740993, 1; 0, 1]',
            'let ci = [9007199254740994, 0]',
            'pvz(solve(Bi, ci))',
            'pv(eig_sym([5, 0; 0, -3]))']
    program('la_solve_i64',
            ['i64 arguments of solve, lu, chol and eig_sym are converted to f64 (LANGUAGE.md 10.8, 4.2; DESIGN.md 2.13.2,',
             'L-iq; fixed-size ones also made dynamic): [4, 2; 2, 5] with b = [2, -3] gives [1, -1] by the Cholesky path',
             '(R = [2, 1; 0, 2]), by lu (pivot 4, U[1,1] = 4) and by chol; [9007199254740993, 1; 0, 1] converts to',
             '2^53 (ties to even) and [9007199254740994, 0] exactly, so x[0] = (2^53 + 2) / 2^53 = 1 + 2^-52 (with',
             'the unconverted 2^53 + 1 it would round to 1); eig_sym of the i64 diagonal [5, 0; 0, -3] is [-3, 5];',
             'exact data, printed as x + 0.0 (eig_sym raw); by hand, checked by tests/vectors/la8_cases.py'],
            ['pv', 'pvz'], body,
            [pv_line([1.0, -1.0])] * 3 + [pv_line(xb), pv_line([-3.0, 5.0])])


def la_solve_shapes():
    A, R = RHS_A, RHS_R
    x = [1.0, -1.0, 2.0]
    b = uncol(exact_rhs(A, col(x)))
    X2 = [[1.0, 0.0], [-1.0, 3.0], [2.0, -2.0]]
    B2 = exact_rhs(A, X2)
    verify_chol_exact(A, R, B2, X2, 'la_solve_shapes')
    body = ['let A = ' + mat_lit(A),
            'let b = ' + vec_lit(b),
            'pvz(solve(A, b))',
            'pmz(solve(A, ' + mat_lit(col(b)) + '))',
            'pmz(solve(A, ' + mat_lit(B2) + '))',
            'pmz(solve(A, zeros(3, 0)))',
            'pmz(solve(lu(A), zeros(3, 0)))',
            'pmz(solve(chol(A), zeros(3, 0)))',
            'pv(solve(zeros(0, 0), zeros(0)))',
            'pm(solve(zeros(0, 0), zeros(0, 2)))',
            'let y = solve(A, b)',
            'let Y = solve(A, ' + mat_lit(col(b)) + ')',
            'printf("%d %d %d\\n", len(y), rows(Y), cols(Y))']
    program('la_solve_shapes',
            ['the result of solve has B\'s rank and shape (LANGUAGE.md 10.8; DESIGN.md 2.13.2, L-ik): a vector b gives a',
             'vector, a 3 x 1 and a 3 x 2 matrix give matrices of that shape, a 3 x 0 B gives 3 x 0 (solve(A, B),',
             'solve(lu(A), B), solve(chol(A), B)), n = 0 gives 0 and 0 x 2; A = [4, 2, 0; 2, 5, 2; 0, 2, 5] (the',
             'Cholesky path, exact, R = [2, 1, 0; 0, 2, 1; 0, 0, 2]), b = [2, 1, 8] = A [1, -1, 2]; printed as x + 0.0;',
             'by hand, checked by tests/vectors/la8_cases.py'],
            ['pv', 'pm', 'pvz', 'pmz'], body,
            [pv_line(x), pm_line(col(x), 3, 1), pm_line(zm(X2), 3, 2)] + [pm_line([[], [], []], 3, 0)] * 3
            + [pv_line([]), pm_line([], 0, 2), '3 3 1\n'])


# ------------------------------------------------------------ programs/la_eig_*
def la_eig_diag():
    d = [3.0, -1.5, 0.25, 7.0, -1.5]
    body = ['var D = zeros(5, 5)',
            'let d = ' + vec_lit(d)]
    body += ['for i in 0..5 {',
             '    D[i, i] = d[i]',
             '}',
             'pv(eig_sym(D))',
             'pv(eig_sym([-2.0].row))',
             'pv(eig_sym([0.5, 0.0; 0.0, 0.5]))']
    program('la_eig_diag',
            ['eig_sym of a diagonal matrix is its diagonal sorted ascending, exactly (LANGUAGE.md 10.8; DESIGN.md 2.13.6',
             'EIG_SYM, 2.13.8): tred1 finds every row\'s off-diagonal scale 0 and leaves d the diagonal and e zero, so',
             'tql1 accepts each d[l] at once (e[l] negligible) and returns d[l] + 0; then the sort of 10.6. Duplicates',
             'kept ([3, -1.5, 0.25, 7, -1.5] gives -1.5 -1.5 0.25 3 7), a 1 x 1 matrix, a repeated eigenvalue; by hand'],
            ['pv'], body,
            [pv_line(sorted(d)), pv_line([-2.0]), pv_line([0.5, 0.5])])


def la_eig_2x2():
    bound = 8.0 * EPS * 3.0
    body = ['let A = [2.0, 1.0; 1.0, 2.0]',
            'let e = eig_sym(A)',
            'let bound = 8.0 * eps * 3.0',
            'printf("%d %.17g\\n", len(e), bound)',
            'printf("%d %d\\n", abs(e[0] - 1.0) <= bound, abs(e[1] - 3.0) <= bound)']
    program('la_eig_2x2',
            ['eig_sym([2, 1; 1, 2]) (LANGUAGE.md 10.8; DESIGN.md 2.13.6 EIG_SYM, 2.13.8) is [1, 3] within the tolerance',
             'rule |computed - exact| <= c * n * eps * scale with c = 4, n = 2 and the scale ||A||_2 = 3, i.e.',
             '8 * eps * 3 = %s (class R: a printed bool, 1 when the rule holds); the bound is' % g17(bound),
             'computed by tests/vectors/la8_cases.py (class E: one IEEE product chain, exact)'],
            [], body, [pf('%d %.17g\n', 2, bound), '1 1\n'])


def la_eig_tridiag():
    n = 10
    tol = 16.0 * 10.0 * EPS * 4.0
    ex = [2.0 - 2.0 * math.cos(float(k) * math.pi / 11.0) for k in range(1, n + 1)]
    gaps = [ex[i + 1] - ex[i] for i in range(n - 1)]
    assert min(gaps) > 1000 * tol                  # the sorted order pairs each value with its k
    body = ['var T = zeros(10, 10)',
            'for i in 0..10 {',
            '    T[i, i] = 2.0',
            '    if i > 0 {',
            '        T[i, i - 1] = -1.0',
            '        T[i - 1, i] = -1.0',
            '    }',
            '}',
            'let e = eig_sym(T)',
            'let tol = 16.0 * 10.0 * eps * 4.0',
            'printf("%d %.17g\\n", len(e), tol)',
            'for k in 1..=10 {',
            '    let ex = 2.0 - 2.0 * cos(f64(k) * pi / 11.0)',
            '    printf("%d %d\\n", k, abs(e[k - 1] - ex) <= tol)',
            '}']
    exp = [pf('%d %.17g\n', n, tol)] + ['%d 1\n' % k for k in range(1, n + 1)]
    program('la_eig_tridiag',
            ['eig_sym of the n = 10 matrix tridiag(-1, 2, -1) (LANGUAGE.md 10.8; DESIGN.md 2.13.8): eigenvalue k is',
             '2 - 2 cos(k pi / 11), ascending, each within the tolerance rule c * n * eps * scale with c = 16,',
             'n = 10 and the scale ||A||_2 < 4: 16 * 10 * eps * 4 = %s (a printed bool per k; Sea\'s cos' % g17(tol),
             'is within 1 ulp, far below the bound; the closest eigenvalues are %.3g apart); the bound by' % min(gaps),
             'tests/vectors/la8_cases.py'],
            [], body, exp)


def la_eig_gen():
    Kd = diag([3.0, -5.0, 12.0])
    Md = diag([4.0, 0.25, 16.0])
    ev = sorted([3.0 / 4.0, -5.0 / 0.25, 12.0 / 16.0])
    # W3's pencil (workloads/w3_quarter_car.m: ms 380, mu 42, ks 24e3, kt 210e3)
    qa = 380.0 * 42.0
    qb = 24000.0 * 42.0 + 234000.0 * 380.0
    qc = 24000.0 * 234000.0 - 24000.0 * 24000.0
    sq = math.sqrt(qb * qb - 4.0 * qa * qc)
    l2 = (qb + sq) / (2.0 * qa)
    l1 = (2.0 * qc) / (qb + sq)
    tol = 64.0 * 2.0 * EPS * l2
    # exact roots of 15960 l^2 - 89928000 l + 5040000000 = 0 to 50 digits, against the double closed form
    getcontext().prec = 50
    da, db, dc = Decimal(15960), Decimal(89928000), Decimal(5040000000)
    dd = (db * db - 4 * da * dc).sqrt()
    r2 = (db + dd) / (2 * da)
    r1 = (2 * dc) / (db + dd)
    assert abs(Decimal(l1) - r1) < Decimal(tol) / 100 and abs(Decimal(l2) - r2) < Decimal(tol) / 100
    body = ['let K = ' + mat_lit(Kd),
            'let M = ' + mat_lit(Md),
            'pv(eig_sym(K, M))',
            'let Klin = [24000.0, -24000.0; -24000.0, 234000.0]',
            'let Mlin = [380.0, 0.0; 0.0, 42.0]',
            'let lam = eig_sym(Klin, Mlin)',
            'let qa = 380.0 * 42.0',
            'let qb = 24000.0 * 42.0 + 234000.0 * 380.0',
            'let qc = 24000.0 * 234000.0 - 24000.0 * 24000.0',
            'let sq = sqrt(qb * qb - 4.0 * qa * qc)',
            'let l2 = (qb + sq) / (2.0 * qa)',
            'let l1 = (2.0 * qc) / (qb + sq)',
            'let tol = 64.0 * 2.0 * eps * l2',
            'printf("%d %d %d\\n", len(lam), abs(lam[0] - l1) <= tol, abs(lam[1] - l2) <= tol)']
    program('la_eig_gen',
            ['eig_sym(K, M) (LANGUAGE.md 10.8; DESIGN.md 2.13.6 EIG_SYM_GEN, 2.13.8): a diagonal K = diag(3, -5, 12) and',
             'the power-of-four M = diag(4, 1/4, 16): R = chol(M) = diag(2, 1/2, 4) exactly, Z = R^-T K and C = Z R^-1',
             'are diagonal and exact (off the diagonal +-0), and tred1/tql1 return the diagonal (see la_eig_diag):',
             '[-20, 0.75, 0.75] exactly. W3\'s pencil (DESIGN.md 2.13.1, the fixed-size literals of L-iq) Klin =',
             '[24000, -24000; -24000, 234000], Mlin = [380, 0; 0, 42]: its eigenvalues are the roots of 15960 l^2 -',
             '89928000 l + 5040000000 = 0 (det(K - l M) = 0), computed in the program as (qb + sq) / (2 qa) and the',
             'cancellation-free 2 qc / (qb + sq) (qb^2 and 4 qa qc are integers below 2^53: exact; one sqrt);',
             'tolerance rule c * n * eps * scale with c = 64, n = 2, scale = the larger eigenvalue (||C||_2 of the',
             'reduced matrix): a printed bool for each; the closed form is within 1/100 of the bound of the 50-digit',
             'roots (tests/vectors/la8_cases.py)'],
            ['pv'], body, [pv_line(ev), '2 1 1\n'])


def la_eig_empty():
    body = ['pv(eig_sym(zeros(0, 0)))',
            'pv(eig_sym(zeros(0, 0), zeros(0, 0)))',
            'let e = eig_sym(zeros(0, 0))',
            'printf("%d\\n", len(e))']
    program('la_eig_empty',
            ['eig_sym of a 0 x 0 matrix, and of a 0 x 0 pencil, is the empty vector (LANGUAGE.md 10.8; DESIGN.md 2.13.2',
             '"Empty operands", L-ip, L-iy); by hand'],
            ['pv'], body, [pv_line([]), pv_line([]), '0\n'])


def la_eig_nonfinite():
    cases = [[[1.0, INF], [INF, 2.0]],
             [[NAN, 1.0], [1.0, 2.0]],
             [[1.0, NAN], [NAN, 1.0]],
             [[-INF, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 2.0]]]
    body = []
    exp = []
    for A in cases:
        assert is_sym(A)
        body.append('pv(eig_sym(%s))' % mat_lit(A))
        exp.append(pv_line([NAN] * len(A)))
    program('la_eig_nonfinite',
            ['eig_sym of a symmetric matrix with an element that is not finite returns n NaN (LANGUAGE.md 10.8; DESIGN.md',
             '2.13.6 EIG_SYM, L-ip): +Inf off the diagonal, NaN on it, a NaN pair (symmetric by Decision 123 (a), so',
             'no symmetry error), -Inf on the diagonal of a 3 x 3; NaN printed NaN; by hand'],
            ['pv'], body, exp)


def la_eig_gen_nonfinite():
    I2 = [[1.0, 0.0], [0.0, 1.0]]
    cases = [(I2, [[INF, 0.0], [0.0, 1.0]]),
             ([[NAN, 0.0], [0.0, 1.0]], I2),
             ([[1e300, 0.0], [0.0, 1e300]], [[1e-300, 0.0], [0.0, 1e-300]]),
             (I2, [[INF, 0.0], [0.0, -1.0]])]
    # case 3: M is positive definite, R[j,j] = sqrt(1e-300) ~ 1e-150, and Z[0,0] = 1e300 / 1e-150 overflows
    R = chol_float(cases[2][1])
    assert R is not None and 1e300 / R[0][0] == INF
    assert chol_float(cases[3][1]) is None         # not positive definite: the Inf test comes first (L-iy)
    body = ['let I2 = ' + mat_lit(I2)]
    exp = []
    for K, M in cases:
        assert is_sym(K) and is_sym(M)
        ks = 'I2' if K is I2 else mat_lit(K)
        ms = 'I2' if M is I2 else mat_lit(M)
        body.append('pv(eig_sym(%s, %s))' % (ks, ms))
        exp.append(pv_line([NAN, NAN]))
    program('la_eig_gen_nonfinite',
            ['eig_sym(K, M) gives n NaN in L-iy\'s three cases (LANGUAGE.md 10.8; DESIGN.md 2.13.6 EIG_SYM_GEN): +Inf',
             'on M\'s diagonal (before the Cholesky of M), NaN in K, and finite K = 1e300 I, M = 1e-300 I whose',
             'reduction overflows (R = sqrt(1e-300) I, Z = 1e300 / 1e-150 = Inf: n NaN before tred1); and an M with',
             '+Inf that is also not positive definite (diag(Inf, -1)): n NaN, no error, the non-finite test coming',
             'before the Cholesky of M; by hand'],
            ['pv'], body, exp)


# ------------------------------------------------------------ errors (8c)
def errors_8c():
    I2 = '[1.0, 0.0; 0.0, 1.0]'
    I3 = '[1.0, 0.0, 0.0; 0.0, 1.0, 0.0; 0.0, 0.0, 1.0]'
    S = 'printf("start\\n")\n'
    rt = [
        ('r_la_lu_square', ['lu of a 2 x 3 matrix: matrix is not square with its shape (LANGUAGE.md 9.2, 10.8; DESIGN.md',
                            '2.13.5 LU, L-ij, L-iv), at the line of the call, after start is written'],
         'let A = zeros(2, 3)\n' + S + 'let F = lu(A)\nprintf("%g\\n", rcond(F))\n',
         'let F = lu(A)', 'matrix is not square (2x3)', 'start\n'),
        ('r_la_lu_nanpivot', ['lu([0, 1; NaN, 1]) completes with a zero pivot (the NaN never wins the pivot search unless',
                              'it is first, Decision 129 (a), L-in), so solve(F, b) is matrix is singular, at its line'],
         'let A = [0.0, 1.0; nan, 1.0]\nlet b = [1.0, 1.0]\nlet F = lu(A)\nprintf("lu done\\n")\n'
         'let x = solve(F, b)\nprintf("%d\\n", len(x))\n',
         'let x = solve(F, b)', 'matrix is singular', 'lu done\n'),
        ('r_la_chol_posdef', ['chol([1, 2; 2, 1]): the second pivot 1 - 2 * 2 = -3 is not greater than 0 (DESIGN.md 2.13.5',
                              'CHOL, L-im)'],
         S + 'let C = chol([1.0, 2.0; 2.0, 1.0])\nprintf("%d\\n", 1)\n',
         'let C = chol(', 'matrix is not positive definite', 'start\n'),
        ('r_la_chol_nan', ['chol([1, NaN; NaN, 1]): R[0,1] = NaN, the pivot 1 - NaN^2 is NaN, which is not greater than 0',
                           '(LANGUAGE.md 10.8: a NaN pivot included; L-im)'],
         S + 'let C = chol([1.0, nan; nan, 1.0])\nprintf("%d\\n", 1)\n',
         'let C = chol(', 'matrix is not positive definite', 'start\n'),
        ('r_la_chol_square', ['chol of a 3 x 2 matrix: matrix is not square (DESIGN.md 2.13.5 CHOL, L-ij)'],
         'let A = zeros(3, 2)\n' + S + 'let C = chol(A)\nprintf("%d\\n", 1)\n',
         'let C = chol(A)', 'matrix is not square (3x2)', 'start\n'),
        ('r_la_solve_singular', ['solve(F, b) with F = lu([1, 2; 2, 4]) (zero pivot 2 - 0.5 * 4): matrix is singular, at',
                                 'the line of solve (LANGUAGE.md 9.2 "either form", L-il)'],
         'let F = lu([1.0, 2.0; 2.0, 4.0])\nprintf("lu done\\n")\nlet x = solve(F, [1.0, 1.0])\nprintf("%d\\n", len(x))\n',
         'let x = solve(F', 'matrix is singular', 'lu done\n'),
        ('r_la_solve_singular_a', ['solve(A, b) of [1, 1; 1, 1]: symmetric with a positive diagonal, so the Cholesky',
                                   'attempt runs and stops at the pivot 1 - 1 = 0, then LU finds the zero pivot 1 - 1 = 0',
                                   '(DESIGN.md 2.13.6 SOLVE): matrix is singular'],
         S + 'let x = solve([1.0, 1.0; 1.0, 1.0], [1.0, 2.0])\nprintf("%d\\n", len(x))\n',
         'let x = solve(', 'matrix is singular', 'start\n'),
        ('r_la_solve_singular_m0', ['solve(A, B) of the singular [1, 2; 2, 4] with a 2 x 0 B: matrix is singular, never',
                                    'the empty result (LANGUAGE.md 10.8 "also when B has no column", L-ik)'],
         'let A = [1.0, 2.0; 2.0, 4.0]\nlet B = zeros(2, 0)\n' + S + 'let X = solve(A, B)\nprintf("%d\\n", cols(X))\n',
         'let X = solve(A, B)', 'matrix is singular', 'start\n'),
        ('r_la_solve_shape', ['solve(A, B) of a 3 x 3 A and a 4 x 2 B: shape mismatch, n x n of A then B\'s shape (L-ij)'],
         'let A = [2.0, 0.0, 0.0; 0.0, 2.0, 0.0; 0.0, 0.0, 2.0]\nlet B = zeros(4, 2)\n' + S
         + 'let X = solve(A, B)\nprintf("%d\\n", cols(X))\n',
         'let X = solve(A, B)', 'shape mismatch: 3x3 vs 4x2', 'start\n'),
        ('r_la_solve_square', ['solve(A, b) of a 2 x 3 A: matrix is not square (DESIGN.md 2.13.5 SOLVE)'],
         'let A = zeros(2, 3)\n' + S + 'let x = solve(A, zeros(2))\nprintf("%d\\n", len(x))\n',
         'let x = solve(A', 'matrix is not square (2x3)', 'start\n'),
        ('r_la_chol_solve_shape', ['solve(F, b) of a Chol of order 2 and a vector of 3: shape mismatch 2x2 vs 3',
                                   '(DESIGN.md 2.13.5 CHOL_SOLVE "the shape check as LU_SOLVE", L-ij)'],
         'let C = chol(' + I2 + ')\n' + S + 'let x = solve(C, zeros(3))\nprintf("%d\\n", len(x))\n',
         'let x = solve(C', 'shape mismatch: 2x2 vs 3', 'start\n'),
        ('r_la_eig_square', ['eig_sym of a 2 x 3 matrix: matrix is not square (DESIGN.md 2.13.5 EIG_SYM)'],
         'let A = zeros(2, 3)\n' + S + 'let e = eig_sym(A)\nprintf("%d\\n", len(e))\n',
         'let e = eig_sym(A)', 'matrix is not square (2x3)', 'start\n'),
        ('r_la_eig_symmetric', ['eig_sym([1, 2; 3, 1]): matrix is not symmetric (LANGUAGE.md 9.2; Decision 123 (a))'],
         S + 'let e = eig_sym([1.0, 2.0; 3.0, 1.0])\nprintf("%d\\n", len(e))\n',
         'let e = eig_sym(', 'matrix is not symmetric', 'start\n'),
        ('r_la_eig_gen_shape', ['eig_sym(K, M) of a 3 x 3 K and a 2 x 2 M: shape mismatch, K\'s shape then M\'s (L-ij)'],
         S + 'let e = eig_sym(' + I3 + ', ' + I2 + ')\nprintf("%d\\n", len(e))\n',
         'let e = eig_sym(', 'shape mismatch: 3x3 vs 2x2', 'start\n'),
        ('r_la_eig_gen_posdef', ['eig_sym(I, [1, 2; 2, 1]): M is not positive definite (DESIGN.md 2.13.5 EIG_SYM_GEN)'],
         S + 'let e = eig_sym(' + I2 + ', [1.0, 2.0; 2.0, 1.0])\nprintf("%d\\n", len(e))\n',
         'let e = eig_sym(', 'matrix is not positive definite', 'start\n'),
        ('r_la_eig_gen_sym_m', ['eig_sym(I, [2, 1; 0, 2]): K symmetric, M not: matrix is not symmetric (EIG_SYM_GEN)'],
         S + 'let e = eig_sym(' + I2 + ', [2.0, 1.0; 0.0, 2.0])\nprintf("%d\\n", len(e))\n',
         'let e = eig_sym(', 'matrix is not symmetric', 'start\n'),
        # check order (L-ik: each entry checks in its row's order, DESIGN.md 2.13.5)
        ('r_la_chol_order', ['check order of CHOL (DESIGN.md 2.13.5, L-ik): a 2 x 3 matrix whose first pivot -1 would',
                             'also fail the positive-definite test: matrix is not square comes first'],
         S + 'let C = chol([-1.0, 0.0, 0.0; 0.0, -1.0, 0.0])\nprintf("%d\\n", 1)\n',
         'let C = chol(', 'matrix is not square (2x3)', 'start\n'),
        ('r_la_solve_order_f', ['check order of LU_SOLVE (L-ik): a singular factor of order 2 and a vector of 3: the',
                                'shape check comes before matrix is singular'],
         'let F = lu([1.0, 2.0; 2.0, 4.0])\n' + S + 'let x = solve(F, zeros(3))\nprintf("%d\\n", len(x))\n',
         'let x = solve(F', 'shape mismatch: 2x2 vs 3', 'start\n'),
        ('r_la_solve_order_sq', ['check order of SOLVE (L-ik): a 2 x 3 A and a vector of 5: matrix is not square before',
                                 'the shape check'],
         S + 'let x = solve(zeros(2, 3), zeros(5))\nprintf("%d\\n", len(x))\n',
         'let x = solve(', 'matrix is not square (2x3)', 'start\n'),
        ('r_la_solve_order_shape', ['check order of SOLVE (L-ik): the singular [1, 2; 2, 4] and a vector of 3: the shape',
                                    'check before the factorization\'s matrix is singular'],
         S + 'let x = solve([1.0, 2.0; 2.0, 4.0], zeros(3))\nprintf("%d\\n", len(x))\n',
         'let x = solve(', 'shape mismatch: 2x2 vs 3', 'start\n'),
        ('r_la_eig_order', ['check order of EIG_SYM (L-ik): a non-square matrix holding NaN and unequal pairs: matrix is',
                            'not square before the symmetric test (and no NaN result)'],
         S + 'let e = eig_sym([nan, 1.0, 2.0; 3.0, nan, 4.0])\nprintf("%d\\n", len(e))\n',
         'let e = eig_sym(', 'matrix is not square (2x3)', 'start\n'),
        ('r_la_eig_gen_order_k', ['check order of EIG_SYM_GEN (DESIGN.md 2.13.5): K 2 x 3 and M 3 x 2 both not square: K\'s',
                                  'shape is reported'],
         S + 'let e = eig_sym(zeros(2, 3), zeros(3, 2))\nprintf("%d\\n", len(e))\n',
         'let e = eig_sym(', 'matrix is not square (2x3)', 'start\n'),
        ('r_la_eig_gen_order_m', ['check order of EIG_SYM_GEN: a square non-symmetric K and a 3 x 2 M: M\'s not square',
                                  'comes before the shape check and the symmetric tests'],
         S + 'let e = eig_sym([1.0, 2.0; 3.0, 4.0], zeros(3, 2))\nprintf("%d\\n", len(e))\n',
         'let e = eig_sym(', 'matrix is not square (3x2)', 'start\n'),
        ('r_la_eig_gen_order_shape', ['check order of EIG_SYM_GEN: a non-symmetric 2 x 2 K and the 3 x 3 identity M: the',
                                      'shape mismatch comes before the symmetric test'],
         S + 'let e = eig_sym([1.0, 2.0; 3.0, 4.0], ' + I3 + ')\nprintf("%d\\n", len(e))\n',
         'let e = eig_sym(', 'shape mismatch: 2x2 vs 3x3', 'start\n'),
        ('r_la_eig_gen_order_ksym', ['check order of EIG_SYM_GEN: a non-symmetric K and an M that is not positive definite:',
                                     'matrix is not symmetric (K) before the Cholesky of M'],
         S + 'let e = eig_sym([1.0, 2.0; 3.0, 4.0], [1.0, 2.0; 2.0, 1.0])\nprintf("%d\\n", len(e))\n',
         'let e = eig_sym(', 'matrix is not symmetric', 'start\n'),
        ('r_la_eig_gen_order_sym', ['check order of EIG_SYM_GEN: the identity K and an M that is neither symmetric nor',
                                    'positive definite ([-1, 2; 3, 1]): matrix is not symmetric (M) before its Cholesky'],
         S + 'let e = eig_sym(' + I2 + ', [-1.0, 2.0; 3.0, 1.0])\nprintf("%d\\n", len(e))\n',
         'let e = eig_sym(', 'matrix is not symmetric', 'start\n'),
    ]
    for name, comment, body, marker, msg, out in rt:
        err_runtime(name, comment, body, marker, msg, out)

    LU = 'let A = ones(2, 2)\nlet F = lu(A)\n'
    ct = [
        ('err_la_lu_vector', ['lu of a vector: 243 at the call, the argument type spelled (DESIGN.md 2.13.3 ck_lib)'],
         'let v = zeros(3)\nlet F = lu(v)\n', 'let F = lu(v)', 'lu(', "no overload of 'lu' accepts (f64[])"),
        ('err_la_rcond_chol', ['rcond of a Chol: 243 (DESIGN.md 2.13.3: rcond takes an Lu only)'],
         'let A = ones(2, 2)\nlet C = chol(A)\nlet r = rcond(C)\n', 'let r = rcond(C)', 'rcond(',
         "no overload of 'rcond' accepts (Chol)"),
        ('err_la_solve_args', ['solve with a scalar B: 243 with both argument types (DESIGN.md 2.13.3: B a numeric vector or',
                               'matrix)'],
         'let A = ones(2, 2)\nlet x = solve(A, 2.0)\n', 'let x = solve(', 'solve(',
         "no overload of 'solve' accepts (f64[,], f64)"),
        ('err_la_solve_bool', ['solve with a bool vector B: 243 (a bool element type is not numeric)'],
         'let A = ones(2, 2)\nlet b = filled(true, 2)\nlet x = solve(A, b)\n', 'let x = solve(', 'solve(',
         "no overload of 'solve' accepts (f64[,], bool[])"),
        ('err_la_eig_args', ['eig_sym with three matrices: 243 with the three types (no overload takes three arguments)'],
         'let A = ones(2, 2)\nlet e = eig_sym(A, A, A)\n', 'let e = eig_sym(', 'eig_sym(',
         "no overload of 'eig_sym' accepts (f64[,], f64[,], f64[,])"),
        ('err_la_handle_array', ['an array type of a handle type: 258 at the type node (LANGUAGE.md 4.1; DESIGN.md 2.13.3,',
                                 'L-ir)'],
         'fn first(v: Lu[]) -> i64 {\n    return len(v)\n}\n', 'fn first(', 'Lu[]', 'arrays cannot hold Lu'),
        ('err_la_handle_struct_array', ['an array of a struct holding a handle two struct levels down: 258 naming the handle',
                                        'type at the array type node (LANGUAGE.md 4.1 "at any depth"; L-ir)'],
         'struct Inner {\n    f: Lu\n    k: i64\n}\nstruct Outer {\n    s: Inner\n    w: f64\n}\n'
         'fn total(v: Outer[]) -> i64 {\n    return len(v)\n}\n', 'fn total(', 'Outer[]', 'arrays cannot hold Lu'),
        ('err_la_handle_literal', ['an array literal of handles: 258 at the literal (L-ir)'],
         LU + 'let v = [F, F]\n', 'let v = [', '[F', 'arrays cannot hold Lu'),
        ('err_la_handle_filled', ['filled of a handle: 258 at the call (L-ir)'],
         LU + 'let v = filled(F, 3)\n', 'let v = filled(', 'filled(', 'arrays cannot hold Lu'),
        ('err_la_handle_eq', ['== of two handles: 240 at the operator node, its left operand (LANGUAGE.md 4.1: handles',
                              'cannot be compared; DESIGN.md 2.13.3, 3.3)'],
         LU + 'let G = F\nlet same = F == G\n', 'let same', 'F ==', "operator '==' cannot be applied to Lu and Lu"),
        ('err_la_handle_printf', ['a handle argument of printf: 210 at the argument (DESIGN.md 2.13.3)'],
         LU + 'printf("%g\\n", F)\n', 'printf(', 'F)', 'format "%g" expects an integer or f64, found Lu'),
        ('err_json_handle', ['write_json of a handle: 243 at the call (DESIGN.md 0 decision 2, 2.13.3; the case 6d could not',
                             'test: the handle types row reported first until 8c)'],
         LU + 'write_json("h.json", F)\n', 'write_json(', 'write_json', "no overload of 'write_json' accepts (str, Lu)"),
        ('err_la_ref_arg', ['a ref argument of lu: 255 at the ref, naming the parameter as LANGUAGE.md 10.8 writes it (A),',
                            'not the variable (DESIGN.md 2.13.3)'],
         'var M = ones(2, 2)\nlet F = lu(ref M)\n', 'let F = lu(', 'ref', "'A' is not a ref parameter"),
        ('err_la_named', ['a named argument of lu, even with the parameter\'s own name: 224 at the narg (DESIGN.md 2.13.3:',
                          'every named argument of the five functions is 224, they have no option)'],
         'let B = ones(2, 2)\nlet F = lu(A: B)\n', 'let F = lu(', 'A: B', 'unknown parameter'),
    ]
    for name, comment, body, marker, col_text, msg in ct:
        err_compile(name, comment, body, marker, col_text, msg)


GENERATORS_8C = [la_lu_exact, la_lu_rcond, la_lu_singular, la_lu_nonfinite, la_lu_empty, la_lu_share, la_chol_exact,
                 la_chol_upper, la_chol_rhs, la_solve_sym, la_solve_indef, la_solve_nonsym, la_solve_zero_pair,
                 la_solve_fixed, la_solve_i64, la_solve_shapes, la_eig_diag, la_eig_2x2, la_eig_tridiag, la_eig_gen,
                 la_eig_empty, la_eig_nonfinite, la_eig_gen_nonfinite, errors_8c]


GENERATORS = [la_mv_order, la_mv_negzero, la_mv_empty, la_mv_k0_big, la_mv_nonfinite, la_mv_i64, la_mv_fixed, la_mv_mixed,
              la_mv_view, la_mv_tails, la_vm_order, la_vm_negzero, la_vm_empty, la_vm_k0_big, la_vm_fixed, la_mm_exact,
              la_mm_empty, la_mm_nonfinite, la_mm_fixed, la_mm_mixed, la_mm_i64, la_mm_operands, errors] + GENERATORS_8C


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
    print('la8_cases: wrote %d files (%d programs, %d errors); removed the retired err_ns_matmul and err_ns_lib_solve'
          % (len(OUT), sum(1 for p in OUT if p.endswith('.sea') and p.startswith(PROGRAMS)),
             sum(1 for p in OUT if p.endswith('.sea') and p.startswith(ERRORS))))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
