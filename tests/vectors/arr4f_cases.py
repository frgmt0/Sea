"""Sub-phase 4f corpus: programs/ and errors/ tests of the reductions, sorting and searching
(DESIGN.md 6.2 "4f", 8 row 4f, work package T1).

Run with `timeout 120 uv run --no-project python tests/vectors/arr4f_cases.py`. It writes the
programs/red_*, programs/sort_*, programs/find_* and programs/heap_red_* tests, programs/w4_sor_reduce
(from programs/w4_sor_arrays.sea, its .out copied byte for byte), and the 4f errors/ tests: the
run-time errors of the reductions (r_red_*: `integer overflow` of an i64 sum, `%s of an empty
array`), and the compile errors of named options and overloads (err_red_*, err_sort_*, err_find_*:
115, 201, 217, 225, 237, 243, 262 and the phase-rule word `named arguments`). It deletes the four
goldens err_ns_lib_sum, err_ns_lib_max1, err_ns_lib_max1_fixed and err_ns_lib_min1 (DESIGN.md 6.2
"4f": their programs compile from 4f); their calls are checked by programs/red_former_ns.

Every expected output is derived here from LANGUAGE.md 8.1, 9.2, 10.5, 10.6 and 11.1 (and, for
messages, positions and orders, DESIGN.md 2.6.2 "Readings fixed by 4f", the error table and its `at`
column, 3.3 node positions, 3.6.6 rules 23 and 24); the comment beside each case gives the
derivation. Floating results are computed by the small model below, which is a line-by-line
transcription of LANGUAGE.md 10.5 (the pinned 8-lane order: eight accumulators starting at -0.0,
`a[i % 8] += x[i]` in index order, then `((a0 + a1) + (a2 + a3)) + ((a4 + a5) + (a6 + a7))`; the
empty sum +0; mean = sum / n; the two-pass variance; std = sqrt; max/min the first extreme in index
order ignoring NaN) evaluated with Python floats, which are IEEE binary64 with round to nearest even
for + - * / and a correctly rounded sqrt: a calculator for the specified order, never a run of the
compiler. Sorting is modelled by Python's stable `sorted` with the key of LANGUAGE.md 10.6 (-0 == +0,
every NaN equal to every NaN and after every number ascending, before every number descending).
The run-time error line of an errors/ test is the line holding its marker; a compile error's column
is that of its marker text inside that line (both computed from the source text).

Printing (v1 has no `print` until phase 6): vectors through the helpers of arr4e_cases.py, `n:` and
each element after one blank (`pf` %g, `pvi` %d, `pvb` %d of bool = 0 or 1, LANGUAGE.md 11.1); %g
prints `-0` for negative zero and `NaN`, `Inf`, `-Inf` for the non-finite values.
"""

import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
TESTS = os.path.dirname(HERE)
PROGRAMS = os.path.join(TESTS, 'programs')
ERRORS = os.path.join(TESTS, 'errors')
COUNT = {'programs': 0, 'errors': 0}

I64_MIN = -(1 << 63)
I64_MAX = (1 << 63) - 1


def write(path, text):
    with open(path, 'w') as f:
        f.write(text)


def source(name, comment, body):
    head = ''.join('// %s\n' % c for c in comment)
    head = '// %s -- ' % name + head[3:]
    return head + body


# ---------------------------------------------------------------------------- the model (LANGUAGE.md 10.5, 10.6)
def lit(tok):
    """The binary64 value of a Sea scalar literal token (3.4: nearest, ties to even, which Python's
    float() also gives; `-` is the operator, exact for every value; `nan`, `inf` are the constants
    of 10.1)."""
    neg = tok.startswith('-')
    t = tok[1:] if neg else tok
    v = {'nan': math.nan, 'inf': math.inf}.get(t)
    if v is None:
        v = float(t)
    return -v if neg else v


def sum8(xs):
    """LANGUAGE.md 10.5, the pinned 8-lane order; the empty sum is +0."""
    if not xs:
        return 0.0
    a = [-0.0] * 8
    for i, x in enumerate(xs):
        a[i % 8] = a[i % 8] + x
    return ((a[0] + a[1]) + (a[2] + a[3])) + ((a[4] + a[5]) + (a[6] + a[7]))


def l2r(xs):
    """Left-to-right summation from +0 (only to show in comments that the 8-lane result differs)."""
    s = 0.0
    for x in xs:
        s = s + x
    return s


class Overflow(Exception):
    pass


def isum(xs):
    """10.5 / Decision 42: index order from 0, every partial sum checked."""
    s = 0
    for x in xs:
        s += x
        if s < I64_MIN or s > I64_MAX:
            raise Overflow
    return s


def fdiv(a, b):
    """IEEE a / b (Python raises on a zero divisor; only 0/0 = NaN is needed here)."""
    if b == 0.0:
        assert a == 0.0 or math.isnan(a)
        return math.nan
    return a / b


def mean_f(xs):
    return fdiv(sum8(xs), float(len(xs)))


def mean_i(xs):
    return fdiv(float(isum(xs)), float(len(xs)))      # the i64 sum and n both converted (6.5)


def var_f(xs, m=None):
    n = len(xs)
    if n == 0:
        return math.nan
    if n == 1:
        return 0.0
    if m is None:
        m = mean_f(xs)
    return sum8([(y - m) * (y - m) for y in xs]) / float(n - 1)


def var_i(xs):
    n = len(xs)
    if n == 0:
        return math.nan
    if n == 1:
        return 0.0
    return var_f([float(y) for y in xs], mean_i(xs))  # the i64 mean, converted elements


def std(v):
    return math.sqrt(v) if not math.isnan(v) else v


def ext(xs, gt):
    """max (gt=True) / min: the first extreme in index order, NaN ignored; all NaN -> (NaN, 0)."""
    r, have, k = math.nan, False, 0
    for i, x in enumerate(xs):
        if isinstance(x, float) and math.isnan(x):
            continue
        if not have or (x > r if gt else x < r):
            r, have, k = x, True, i
    if not have and xs and isinstance(xs[0], int):
        raise AssertionError('i64 vectors have no NaN')
    return r, k


def sort_idx(xs, desc=False):
    """10.6: stable; -0 == +0; every NaN equal to every NaN, after every number ascending and before
    every number descending (desc is not a reversed ascending order: ties keep their input order)."""
    def isn(x):
        return isinstance(x, float) and math.isnan(x)
    if desc:
        key = lambda i: (0, 0) if isn(xs[i]) else (1, -xs[i])
    else:
        key = lambda i: (1, 0) if isn(xs[i]) else (0, xs[i])
    return sorted(range(len(xs)), key=key)


def g(x, conv='%g'):
    """printf of an f64 (11.1): C99 digits for finite values, NaN / Inf / -Inf otherwise."""
    if math.isnan(x):
        return 'NaN'
    if math.isinf(x):
        return 'Inf' if x > 0 else '-Inf'
    return conv % x


def g17(x):
    return g(x, '%.17g')


def sea_float(x):
    """A Sea float literal denoting exactly x (finite): Python's shortest round-trip digits, with a
    `.` or an exponent as 3.4 requires (`digits "." digits` or `digits exponent`)."""
    r = repr(abs(x))
    if 'e' in r:
        mant, ex = r.split('e')
        if '.' not in mant:
            mant += '.0'
        r = mant + 'e' + ex
    assert float(r) == abs(x)
    return ('-' if math.copysign(1.0, x) < 0 else '') + r


def vf(xs):
    return '%d:' % len(xs) + ''.join(' ' + g(x) for x in xs)


def vi(xs):
    return '%d:' % len(xs) + ''.join(' %d' % x for x in xs)


def vb(xs):
    return '%d:' % len(xs) + ''.join(' %d' % (1 if x else 0) for x in xs)


def seavec(toks):
    return '[' + ', '.join(toks) + ']'


def seamat(rows):
    return '[' + '; '.join(', '.join(r) for r in rows) + ']'


# ---------------------------------------------------------------------------- printing helpers
HELPERS = {
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
    'pvb': r'''fn pvb(v: bool[]) {
    printf("%d:", len(v))
    for x in v {
        printf(" %d", x)
    }
    printf("\n")
}
''',
}


def prog(name, comment, helpers, steps, fns=''):
    """A programs/ test. steps: (code, expected) pairs in program order; expected is the text the
    code prints (lines separated by LF, without the final LF) or None."""
    body = ''.join(HELPERS[h] for h in helpers) + fns
    body += ''.join(code + '\n' for code, _ in steps)
    out = ''.join(o + '\n' for _, o in steps if o is not None)
    write(os.path.join(PROGRAMS, name + '.sea'), source(name, comment, body))
    write(os.path.join(PROGRAMS, name + '.out'), out)
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
    elif os.path.exists(path):
        os.remove(path)
    COUNT['errors'] += 1


def err_c(name, comment, body, marker, col_text, msg, last=False):
    """A compile error at the first (last=True: the last) occurrence of col_text in the marker's line."""
    src = source(name, comment, body)
    ln, text = line_of(src, marker)
    col = (text.rindex(col_text) if last else text.index(col_text)) + 1
    write(os.path.join(ERRORS, name + '.sea'), src)
    write(os.path.join(ERRORS, name + '.err'), '%s.sea:%d:%d: error: %s\n' % (name, ln, col, msg))
    write(os.path.join(ERRORS, name + '.status'), '1\n')
    COUNT['errors'] += 1


# ============================================================ red_sum: the pinned 8-lane order (10.5)
# B = 1e16 is exact (2^16 * 5^16 < 2^53 * 2^...: its binary64 neighbours are 2 apart), so B + 1 is a
# tie between B and B + 2 and rounds to the even significand, B; B + 2 and B + 4 are exact; -B + 1
# rounds to -B. Each vector below is chosen so the 8-lane result differs from left-to-right
# summation (asserted), printed with %.17g and compared with == to the exact literal.
B = '1e16'
ONE = '1.0'
SUMCASES = [
    # n = 7: lanes a0..a6 = x0..x6, a7 = -0. ((1 + 1) + (B + 1)) + ((-B + 1) + (1 + -0))
    #        = (2 + B) + (-B + 1) = (B + 2) + (-B) = 2; left to right 2, B + 2, B + 3 -> B + 4 (tie,
    #        even), B + 4 - B = 4, 5, 6.
    ('v7', [ONE, ONE, B, ONE, '-' + B, ONE, ONE]),
    # n = 8: ((B + 1) + (-B + 1)) + ((3 + 1) + (1 + 1)) = (B + -B) + (4 + 2) = 6; left to right
    #        B, 0, 1, 4, 5, 6, 7 = 7.
    ('v8', [B, ONE, '-' + B, ONE, '3.0', ONE, ONE, ONE]),
    # n = 9: a0 = (-0 + B) + -B = 0, a1..a7 = 1: ((0 + 1) + 2) + (2 + 2) = 7; left to right B stays
    #        B through the seven 1s, then B - B = 0.
    ('v9', [B] + [ONE] * 7 + ['-' + B]),
    # n = 17: a0 = (B + 1) + -B = 0 (B + 1 -> B), a1..a7 = 1 + 1 = 2: 0 + 2 + 4 + 8 = 14; left to
    #        right 0 as for n = 9.
    ('v17', [B] + [ONE] * 15 + ['-' + B]),
]


def red_sum():
    steps = []
    for name, toks in SUMCASES:
        xs = [lit(t) for t in toks]
        s, s2 = sum8(xs), l2r(xs)
        assert s != s2, (name, s, s2)
        steps.append(('let %s = %s' % (name, seavec(toks)), None))
        # the fixed-size vector and its dynamic copy (through an annotated binding, implicit dyn)
        steps.append(('let d%s: f64[] = %s' % (name[1:], name), None))
        steps.append(('printf("%%.17g %%d %%.17g\\n", sum(%s), sum(%s) == %s, sum(d%s))'
                      % (name, name, sea_float(s), name[1:]),
                      '%s 1 %s' % (g17(s), g17(s))))
    # 0 and 1 elements: the empty sum is +0 (printed `0`, not `-0`); sum([x]) = x exactly, -0.0
    # included (-0 + x = x for every x, the -0.0 start of 10.5).
    steps += [
        ('let e: f64[] = []', None),
        ('printf("%g %g\\n", sum(e), sum([-0.0]))', '0 -0'),
        ('printf("%.17g %d\\n", sum([0.1]), sum([0.1]) == 0.1)', '%s 1' % g17(0.1)),
        # zero signs: all -0 stays -0 (-0 + -0 = -0 in every lane and in the tree); one +0 makes +0
        ('printf("%g %g %g\\n", sum([-0.0, -0.0, -0.0]), sum([-0.0, 0.0]), sum([0.0, -0.0]))',
         '%s %s %s' % (g(sum8([-0.0] * 3)), g(sum8([-0.0, 0.0])), g(sum8([0.0, -0.0])))),
        ('let z9 = [-0.0, -0.0, -0.0, -0.0, -0.0, -0.0, -0.0, -0.0, -0.0]', None),
        ('printf("%g\\n", sum(z9))', g(sum8([-0.0] * 9))),
        # NaN and infinities: NaN propagates; inf + 1 = inf; inf + -inf = NaN; with four elements
        # ((1e308 + 1e308) + (-1e308 + -1e308)) = Inf + -Inf = NaN, where left to right gives Inf.
        ('printf("%g %g %g %g\\n", sum([1.0, nan, 2.0]), sum([inf, 1.0]), sum([inf, -inf]), sum([-inf, -1.0]))',
         ' '.join(g(sum8(x)) for x in ([1.0, math.nan, 2.0], [math.inf, 1.0], [math.inf, -math.inf],
                                       [-math.inf, -1.0]))),
        ('printf("%g\\n", sum([1e308, 1e308, -1e308, -1e308]))',
         g(sum8([1e308, 1e308, -1e308, -1e308]))),
        # 1.7976931348623157e308 twice overflows to Inf
        ('printf("%g\\n", sum([1.7976931348623157e308, 1.7976931348623157e308]))', 'Inf'),
    ]
    assert g(sum8([1e308, 1e308, -1e308, -1e308])) == 'NaN' and l2r([1e308, 1e308, -1e308, -1e308]) == math.inf
    prog('red_sum_f64', ['f64 sum (LANGUAGE.md 10.5): the pinned 8-lane order on 7, 8, 9 and 17 elements (each',
                         'differs from left-to-right summation), fixed and dynamic operands, 0 and 1 elements,',
                         'zero signs, NaN, infinities and overflow'], [], steps)

    # i64 sums (10.5, Decision 42): index order, every partial sum checked; totals at the limits.
    cases = [
        ('[9223372036854775807, -1, 1]', [I64_MAX, -1, 1]),           # max, max-1, max: 2^63 - 1
        ('[-4611686018427387904, -4611686018427387904]', [-(1 << 62)] * 2),   # -2^62, -2^63
        ('[-9223372036854775808, 9223372036854775807]', [I64_MIN, I64_MAX]),  # -1
        ('[9223372036854775807, -9223372036854775808, 9223372036854775807]',
         [I64_MAX, I64_MIN, I64_MAX]),                                       # max, -1, max - 1
    ]
    steps = [('printf("%%d\\n", sum(%s))' % code, '%d' % isum(xs)) for code, xs in cases]
    steps += [
        ('let ie: i64[] = []', None),
        ('printf("%d\\n", sum(ie))', '0'),                            # the accumulator starts at 0
        ('printf("%d\\n", sum([-7]))', '-7'),
        # 17 elements in index order (no lanes for i64): 1 + 2 + ... + 17 = 153
        ('let i17: i64[] = (1..=17)', None),
        ('printf("%d\\n", sum(i17))', '%d' % sum(range(1, 18))),
    ]
    prog('red_sum_i64', ['i64 sum (LANGUAGE.md 10.5, Decision 42): partial sums in index order that all fit, with totals',
                         'at 2^63 - 1 and -2^63, the empty sum 0, one element, 17 elements'], [], steps)


red_sum()


# ============================================================ red_mean_var (10.5)
def red_mean_var():
    steps = []
    a = [1.0, 2.0, 4.0]
    # mean = 7 / 3 rounded; variance: d = y - m for each, sum8 of the squares (3 elements: index
    # order), / 2; std its sqrt
    m = mean_f(a)
    steps += [
        ('let a = [1.0, 2.0, 4.0]', None),
        ('printf("%.17g %.17g %.17g\\n", mean(a), variance(a), std(a))',
         '%s %s %s' % (g17(m), g17(var_f(a)), g17(std(var_f(a))))),
        # the same values as i64: the exact sum 7 converted, / 3.0; the converted elements minus that
        # mean: the same bits as the f64 case
        ('let ai = [1, 2, 4]', None),
        ('printf("%.17g %.17g %.17g\\n", mean(ai), variance(ai), std(ai))',
         '%s %s %s' % (g17(mean_i([1, 2, 4])), g17(var_i([1, 2, 4])), g17(std(var_i([1, 2, 4]))))),
    ]
    assert var_i([1, 2, 4]) == var_f(a)
    # two-pass versus one-pass: 100000001, 100000002, 100000003: mean exactly 100000002 (the sum
    # 300000006 is exact), d = -1, 0, 1, variance (1 + 0 + 1) / 2 = 1, std 1; the one-pass formula
    # (sum of squares - n m^2) / (n - 1) loses everything to rounding of the 1e16-sized squares.
    b = [100000001.0, 100000002.0, 100000003.0]
    one_pass = (l2r([y * y for y in b]) - 3.0 * (mean_f(b) * mean_f(b))) / 2.0
    assert var_f(b) == 1.0 and one_pass != 1.0, one_pass
    steps += [
        ('let b: f64[] = [100000001.0, 100000002.0, 100000003.0]', None),
        ('printf("%.17g %.17g %.17g\\n", mean(b), variance(b), std(b))', '100000002 1 1'),
        ('let bi: i64[] = [100000001, 100000002, 100000003]', None),
        ('printf("%.17g %.17g %.17g\\n", mean(bi), variance(bi), std(bi))', '100000002 1 1'),
        # empty: mean 0/0 = NaN, variance NaN (n = 0), std NaN; f64 and i64
        ('let e: f64[] = []', None),
        ('let ie: i64[] = []', None),
        ('printf("%g %g %g %g %g %g\\n", mean(e), variance(e), std(e), mean(ie), variance(ie), std(ie))',
         'NaN NaN NaN NaN NaN NaN'),
        # one element: mean x, variance 0 whatever x (NaN and Inf too: n = 1 -> 0), std 0
        ('printf("%g %g %g\\n", mean([2.5]), variance([2.5]), std([2.5]))', '2.5 0 0'),
        ('printf("%g %g %g\\n", mean([nan]), variance([nan]), variance([inf]))', 'NaN 0 0'),
        ('printf("%g %g %g\\n", mean([-3]), variance([-3]), std([-3]))', '-3 0 0'),
        # mean of -0 alone: -0 / 1 = -0; NaN in a longer vector propagates
        ('printf("%g %g %g\\n", mean([-0.0]), mean([1.0, nan]), variance([1.0, nan, 2.0]))', '-0 NaN NaN'),
        # i64 mean near the limit: the sum 2^63 - 1 fits, converted to 2^63 (rounded), / 3
        ('printf("%.17g\\n", mean([9223372036854775807, -1, 1]))', g17(mean_i([I64_MAX, -1, 1]))),
    ]
    prog('red_mean_var', ['mean, variance (two-pass, N - 1), std of f64 and i64 vectors (LANGUAGE.md 10.5): a case',
                          'where the two-pass result differs from the one-pass formula, empty (NaN), one element',
                          '(variance 0, also of NaN), NaN propagation, an i64 mean near 2^63'], [], steps)


red_mean_var()


# ============================================================ red_sizes: every reduction on 0, 1, 7, 8, 9, 17
SIZE_F = {
    0: [],
    1: ['-2.5'],
    7: [ONE, ONE, B, ONE, '-' + B, ONE, ONE],
    8: [B, ONE, '-' + B, ONE, '3.0', ONE, ONE, ONE],
    9: ['0.5', B, '-0.25', '3.0', ONE, ONE, ONE, '-7.5', '-' + B],
    17: [B, '2.0', '-3.5', '0.125', '4.0', '-1.0', '6.0', '0.75', '-' + B,
         '2.0', '-3.5', '0.125', '4.0', '-1.0', '6.0', '0.75', '9.0'],
}
SIZE_I = {
    0: [],
    1: [-9],
    7: [3, -1, 4, -1, 5, -9, 2],
    8: [6, 5, -3, 5, 8, -9, 7, 9],
    9: [2, 7, -1, 8, -2, 8, 1, -8, 2],
    17: [5, -3, 9, 9, 0, -7, 4, -7, 1, 2, 9, 3, -5, 0, 8, -7, 6],
}
SIZE_B = {
    0: [],
    1: ['true'],
    7: ['false'] * 7,
    8: ['true'] * 8,
    9: ['true', 'false', 'true', 'true', 'false', 'false', 'true', 'false', 'true'],
    17: ['false'] * 16 + ['true'],
}


def red_sizes():
    fns = r'''fn stf(v: f64[]) {
    printf("%d %.17g %.17g %.17g %.17g", len(v), sum(v), mean(v), variance(v), std(v))
    if len(v) > 0 {
        printf(" %g %g %d %d", max(v), min(v), argmax(v), argmin(v))
    }
    printf("\n")
}
fn sti(v: i64[]) {
    printf("%d %d %.17g %.17g %.17g", len(v), sum(v), mean(v), variance(v), std(v))
    if len(v) > 0 {
        printf(" %d %d %d %d", max(v), min(v), argmax(v), argmin(v))
    }
    printf("\n")
}
fn stb(v: bool[]) {
    printf("%d %d %d %d\n", len(v), nnz(v), any(v), all(v))
}
'''
    steps = []
    for n in (0, 1, 7, 8, 9, 17):
        toks = SIZE_F[n]
        xs = [lit(t) for t in toks]
        assert len(xs) == n
        if n >= 4:
            assert sum8(xs) != l2r(xs), n
        line = '%d %s %s %s %s' % (n, g17(sum8(xs)), g17(mean_f(xs)), g17(var_f(xs)), g17(std(var_f(xs))))
        if n:
            mx, kx = ext(xs, True)
            mn, kn = ext(xs, False)
            line += ' %s %s %d %d' % (g(mx), g(mn), kx, kn)
        decl = 'let f%d: f64[] = %s' % (n, seavec(toks)) if n else 'let f0: f64[] = []'
        steps += [(decl, None), ('stf(f%d)' % n, line)]
    for n in (0, 1, 7, 8, 9, 17):
        xs = SIZE_I[n]
        line = '%d %d %s %s %s' % (n, isum(xs), g17(mean_i(xs)), g17(var_i(xs)), g17(std(var_i(xs))))
        if n:
            mx, kx = ext(xs, True)
            mn, kn = ext(xs, False)
            line += ' %d %d %d %d' % (mx, mn, kx, kn)
        decl = 'let i%d: i64[] = %s' % (n, seavec([str(x) for x in xs])) if n else 'let i0: i64[] = []'
        steps += [(decl, None), ('sti(i%d)' % n, line)]
    for n in (0, 1, 7, 8, 9, 17):
        bs = [t == 'true' for t in SIZE_B[n]]
        line = '%d %d %d %d' % (n, sum(bs), 1 if any(bs) else 0, 1 if all(bs) else 0)
        decl = 'let b%d: bool[] = %s' % (n, seavec(SIZE_B[n])) if n else 'let b0: bool[] = []'
        steps += [(decl, None), ('stb(b%d)' % n, line)]
    prog('red_sizes', ['every vector reduction on 0, 1, 7, 8, 9 and 17 elements (LANGUAGE.md 10.5): f64 sum, mean,',
                       'variance, std in the pinned 8-lane order (the f64 vectors of 7 or more elements are chosen',
                       'so it differs from left to right), max, min, argmax, argmin (not on the empty vector:',
                       'errors/r_red_*), the same for i64, and nnz, any, all of bool vectors (empty: 0, false, true)'],
         [], steps, fns=fns)


red_sizes()


# ============================================================ red_maxmin (10.5)
def red_maxmin():
    steps = []
    fcases = [
        ('[3.0, 7.0, 7.0, 1.0, 1.0]', 'ties: the first maximum (index 1) and the first minimum (index 3)'),
        ('[nan, 2.0, 5.0, 5.0]', 'NaN first: ignored'),
        ('[2.0, nan, 1.0]', 'NaN in the middle'),
        ('[2.0, 3.0, nan]', 'NaN last'),
        ('[nan, nan, nan]', 'all NaN: NaN, index 0'),
        ('[-0.0, 0.0]', '-0 then +0: equal, so the first (-0) for both'),
        ('[0.0, -0.0]', '+0 then -0: the first (+0) for both'),
        ('[-inf, -inf, 1.0, inf, inf]', 'infinities, ties'),
        ('[-inf, nan]', 'one number and a NaN'),
        ('[4.0]', 'one element'),
    ]
    for k, (code, why) in enumerate(fcases):
        xs = [lit(t.strip()) for t in code[1:-1].split(',')]
        mx, kx = ext(xs, True)
        mn, kn = ext(xs, False)
        steps.append(('let c%d = %s  // %s' % (k, code, why), None))      # a fixed-size f64[n]
        steps.append(('printf("%%g %%g %%d %%d\\n", max(c%d), min(c%d), argmax(c%d), argmin(c%d))'
                      % (k, k, k, k), '%s %s %d %d' % (g(mx), g(mn), kx, kn)))
    icases = [
        ('[5, -3, 9, 9, -3]', [5, -3, 9, 9, -3]),
        ('[9223372036854775807, -9223372036854775808, 9223372036854775807, -9223372036854775808]',
         [I64_MAX, I64_MIN, I64_MAX, I64_MIN]),
        ('[-9223372036854775808]', [I64_MIN]),
    ]
    for k, (code, xs) in enumerate(icases):
        mx, kx = ext(xs, True)
        mn, kn = ext(xs, False)
        steps.append(('let j%d = %s' % (k, code), None))
        steps.append(('printf("%%d %%d %%d %%d\\n", max(j%d), min(j%d), argmax(j%d), argmin(j%d))'
                      % (k, k, k, k), '%d %d %d %d' % (mx, mn, kx, kn)))
    # a dynamic operand of 9 elements with NaN in lane positions 0 and 8, the maximum repeated
    d = [math.nan, 1.5, -2.0, 6.0, 0.0, 6.0, -2.0, 3.0, math.nan]
    steps += [
        ('let d: f64[] = [nan, 1.5, -2.0, 6.0, 0.0, 6.0, -2.0, 3.0, nan]', None),
        ('printf("%g %g %d %d\\n", max(d), min(d), argmax(d), argmin(d))',
         '%s %s %d %d' % (g(ext(d, True)[0]), g(ext(d, False)[0]), ext(d, True)[1], ext(d, False)[1])),
        # the two-argument max and min stay the elemental functions of 10.4
        ('printf("%g %g\\n", max(1.0, 2.0), min(1.0, 2.0))', '2 1'),
    ]
    prog('red_maxmin', ['max, min, argmax, argmin (LANGUAGE.md 10.5): the first extreme in index order, NaN ignored,',
                        'all NaN -> NaN and index 0, -0/+0 in both orders (signs printed), infinities, i64 at the',
                        'limits, a dynamic operand; max/min of two arguments stay elemental (10.4)'], [], steps)


red_maxmin()


# ============================================================ red_bool (10.5)
prog('red_bool', ['nnz, any, all of bool vectors (LANGUAGE.md 10.5): empty (0, false, true), all true, all false,',
                  'mixed, a comparison result, fixed and dynamic operands'], [], [
    ('let e: bool[] = []', None),
    ('printf("%d %d %d\\n", nnz(e), any(e), all(e))', '0 0 1'),
    ('printf("%d %d %d\\n", nnz([true, true, true]), any([true, true, true]), all([true, true, true]))', '3 1 1'),
    ('printf("%d %d %d\\n", nnz([false, false]), any([false, false]), all([false, false]))', '0 0 0'),
    ('let m: bool[] = [false, true, false, true, true]', None),
    ('printf("%d %d %d\\n", nnz(m), any(m), all(m))', '3 1 0'),
    ('let v: f64[] = [1.0, -2.0, 3.0, nan]', None),
    # v > 0.0: T F T F (NaN compares false, 6.4); v == v: T T T F
    ('printf("%d %d %d %d\\n", nnz(v > 0.0), any(v < -1.0), all(v == v), all(v > -5.0 | v != v))', '2 1 0 1'),
])


# ============================================================ red_dim (10.5 dim:)
A_ROWS = [[B, ONE, '-' + B, ONE],
          ['2.0', '4.0', '8.0', '-0.5'],
          ['-3.0', '0.25', '1.5', '6.0']]
I_ROWS = [[5, -2, 7, 0], [1, 1, -9, 4], [3, 8, 2, 2]]
M_ROWS = [['true', 'false', 'true', 'false'], ['true', 'false', 'false', 'false'], ['true', 'false', 'true', 'true']]
C_ROWS = [[B, '0.5'], [ONE, '-0.25'], [ONE, '2.0'], [ONE, '0.125'], [ONE, '3.0'], [ONE, '-1.0'],
          [ONE, '4.0'], [ONE, '1.0'], ['-' + B, '8.0']]


def cols(rows):
    return [[r[j] for r in rows] for j in range(len(rows[0]))]


def red_dim():
    A = [[lit(t) for t in r] for r in A_ROWS]
    Ac, Ar = cols(A), A
    assert sum8(Ar[0]) != l2r(Ar[0])        # row 0 of 4: ((B + 1) + (-B + 1)) = 0, left to right 1
    fnames = [('sum', lambda v: g(sum8(v))), ('mean', lambda v: g(mean_f(v))),
              ('variance', lambda v: g(var_f(v))), ('std', lambda v: g(std(var_f(v)))),
              ('max', lambda v: g(ext(v, True)[0])), ('min', lambda v: g(ext(v, False)[0]))]
    steps = [('let A = %s' % seamat(A_ROWS), None),             # fixed f64[3,4]
             ('let D: f64[,] = A', None)]                         # its dynamic copy
    for fname, f in fnames:
        # %g prints 6 digits: the values are printed again with %.17g below for sum and mean
        steps.append(('pf(%s(A, dim: 0))' % fname, '4:' + ''.join(' ' + f(c) for c in Ac)))
        steps.append(('pf(%s(D, dim: 1))' % fname, '3:' + ''.join(' ' + f(r) for r in Ar)))
    # exact bits of the dim: 1 sums and variances (row 0 shows the 8-lane order: 0, not 1)
    fns = r'''fn pf17(v: f64[]) {
    printf("%d:", len(v))
    for x in v {
        printf(" %.17g", x)
    }
    printf("\n")
}
'''
    steps += [('pf17(sum(A, dim: 1))', '3:' + ''.join(' ' + g17(sum8(r)) for r in Ar)),
              ('pf17(sum(D, dim: 0))', '4:' + ''.join(' ' + g17(sum8(c)) for c in Ac)),
              ('pf17(variance(D, dim: 1))', '3:' + ''.join(' ' + g17(var_f(r)) for r in Ar)),
              ('pf17(std(A, dim: 0))', '4:' + ''.join(' ' + g17(std(var_f(c))) for c in Ac))]
    # the fixed-size results (Decision 39): sum(A, dim: 0) is an f64[4], sum(A, dim: 1) an f64[3]
    steps += [('let r4: f64[4] = sum(A, dim: 0)', None),
              ('let r3: f64[3] = mean(A, dim: 1)', None),
              ('printf("%g %g\\n", r4[3], r3[1])', '%s %s' % (g(sum8(Ac[3])), g(mean_f(Ar[1]))))]
    # i64: sum, max, min stay i64; mean, variance, std are f64
    I = I_ROWS
    Ic = cols(I)
    steps += [('let I = %s' % seamat([[str(x) for x in r] for r in I]), None),
              ('let J: i64[,] = I', None),
              ('pvi(sum(I, dim: 0))', vi([isum(c) for c in Ic])),
              ('pvi(sum(J, dim: 1))', vi([isum(r) for r in I])),
              ('pvi(max(J, dim: 0))', vi([ext(c, True)[0] for c in Ic])),
              ('pvi(min(I, dim: 1))', vi([ext(r, False)[0] for r in I])),
              ('pf17(mean(I, dim: 0))', '4:' + ''.join(' ' + g17(mean_i(c)) for c in Ic)),
              ('pf17(mean(J, dim: 1))', '3:' + ''.join(' ' + g17(mean_i(r)) for r in I)),
              ('pf17(variance(J, dim: 0))', '4:' + ''.join(' ' + g17(var_i(c)) for c in Ic)),
              ('pf17(std(I, dim: 1))', '3:' + ''.join(' ' + g17(std(var_i(r))) for r in I)),
              ('let m4: f64[4] = mean(I, dim: 0)', None),            # f64 elements, fixed (Decision 39)
              ('printf("%g\\n", m4[0])', g(mean_i(Ic[0])))]
    # bool: nnz (i64), any, all (bool)
    M = [[t == 'true' for t in r] for r in M_ROWS]
    Mc = cols(M)
    steps += [('let M = %s' % seamat(M_ROWS), None),
              ('let N: bool[,] = M', None),
              ('pvi(nnz(M, dim: 0))', vi([sum(c) for c in Mc])),
              ('pvi(nnz(N, dim: 1))', vi([sum(r) for r in M])),
              ('pvb(any(N, dim: 0))', vb([any(c) for c in Mc])),
              ('pvb(any(M, dim: 1))', vb([any(r) for r in M])),
              ('pvb(all(M, dim: 0))', vb([all(c) for c in Mc])),
              ('pvb(all(N, dim: 1))', vb([all(r) for r in M]))]
    # a 9 x 2 matrix: the columns of 9 elements use the lanes over the row index (a0 = x0 + x8)
    C = [[lit(t) for t in r] for r in C_ROWS]
    Cc = cols(C)
    assert sum8(Cc[0]) != l2r(Cc[0])           # (B + -B) + seven 1s = 7; left to right 0
    steps += [('let C: f64[,] = %s' % seamat(C_ROWS), None),
              ('pf17(sum(C, dim: 0))', '2:' + ''.join(' ' + g17(sum8(c)) for c in Cc)),
              ('pf17(sum(C.T, dim: 1))', '2:' + ''.join(' ' + g17(sum8(c)) for c in Cc)),   # a view operand
              ('pf17(mean(C, dim: 0))', '2:' + ''.join(' ' + g17(mean_f(c)) for c in Cc)),
              ('pf17(variance(C.T, dim: 1))', '2:' + ''.join(' ' + g17(var_f(c)) for c in Cc))]
    # NaN in a column: max/min ignore it, sum propagates it; a column of NaN only gives NaN
    steps += [('let Q: f64[,] = [nan, nan; 1.0, nan; -2.0, nan]', None),
              ('pf(max(Q, dim: 0))', '2: 1 NaN'),
              ('pf(min(Q, dim: 0))', '2: -2 NaN'),
              ('pf(sum(Q, dim: 0))', '2: NaN NaN'),
              ('pf(max(Q, dim: 1))', '3: NaN 1 -2')]
    # empty extents (10.5): with dim: 0 a 0 x 3 matrix reduces three columns of 0 elements (sum +0,
    # mean, variance, std NaN, nnz 0, any false, all true); a 3 x 0 matrix gives empty vectors (no
    # column is reduced, so max gives no error); with dim: 1 the roles swap. max/min of a column of
    # 0 elements is errors/r_red_max_dim_empty, r_red_min_dim1_empty.
    steps += [('let Z03 = zeros(0, 3)', None),
              ('let Z30 = zeros(3, 0)', None),
              ('pf(sum(Z03, dim: 0))', '3: 0 0 0'),
              ('pf(mean(Z03, dim: 0))', '3: NaN NaN NaN'),
              ('pf(variance(Z03, dim: 0))', '3: NaN NaN NaN'),
              ('pf(std(Z03, dim: 0))', '3: NaN NaN NaN'),
              ('pf(sum(Z30, dim: 0))', '0:'),
              ('pf(max(Z30, dim: 0))', '0:'),
              ('pf(min(Z30, dim: 0))', '0:'),
              ('pf(sum(Z30, dim: 1))', '3: 0 0 0'),
              ('pf(mean(Z30, dim: 1))', '3: NaN NaN NaN'),
              ('pf(max(Z03, dim: 1))', '0:'),
              ('pf(sum(Z03, dim: 1))', '0:'),
              ('let IZ = filled(0, 0, 3)', None),
              ('pvi(sum(IZ, dim: 0))', '3: 0 0 0'),
              ('pvi(max(IZ, dim: 1))', '0:'),
              ('let BZ = filled(false, 0, 3)', None),
              ('pvi(nnz(BZ, dim: 0))', '3: 0 0 0'),
              ('pvb(any(BZ, dim: 0))', '3: 0 0 0'),
              ('pvb(all(BZ, dim: 0))', '3: 1 1 1'),
              ('pvb(all(BZ, dim: 1))', '0:')]
    prog('red_dim', ['dim: 0 and dim: 1 reductions (LANGUAGE.md 10.5): the nine functions on 3 x 4 matrices (f64',
                     'fixed and dynamic, i64, bool), each element in the vector rule\'s order (a row of 4 and a',
                     'column of 9 where the 8-lane order differs from left to right), fixed-size results',
                     '(Decision 39), NaN, a view operand, and the empty extents 0 x 3 and 3 x 0'],
         ['pf', 'pvi', 'pvb'], steps, fns=fns)


red_dim()


# ============================================================ red_former_ns: the retired err_ns_lib_* calls
prog('red_former_ns', ['the calls of the four retired goldens err_ns_lib_sum, err_ns_lib_max1, err_ns_lib_max1_fixed',
                       'and err_ns_lib_min1 (DESIGN.md 6.2 "4f": they compile from 4f; LANGUAGE.md 10.5)'], [], [
    # zeros(3): a0..a2 = -0 + 0 = +0, a3..a7 = -0: (0 + 0) + (0 + -0) = 0, + (-0 + -0 ...) = +0
    ('printf("%g\\n", sum(zeros(3)))', '0'),
    ('let v = ones(3)', None),
    ('printf("%g\\n", max(v))', '1'),
    ('printf("%g\\n", max([1.0, 2.0]))', '2'),
    ('let m = min(v)', None),
    ('printf("%g\\n", m)', '1'),
])


# ============================================================ sort_* (10.6)
def sortcase(code, xs, kind, extra=''):
    """steps printing sort and argsort of `code` ascending and descending."""
    pv = 'pf' if kind == 'f' else 'pvi'
    fmt = vf if kind == 'f' else vi
    ia, idd = sort_idx(xs), sort_idx(xs, True)
    assert idd != list(reversed(ia)) or len(set(map(repr, xs))) == len(xs) or extra == 'any'
    return [('%s(sort(%s))' % (pv, code), fmt([xs[i] for i in ia])),
            ('pvi(argsort(%s))' % code, vi(ia)),
            ('%s(sort(%s, desc: true))' % (pv, code), fmt([xs[i] for i in idd])),
            ('pvi(argsort(%s, desc: true))' % code, vi(idd))]


def sort_f64():
    steps = []
    # -0/+0 interleaved: equal, so they keep their input order in both directions (signs printed);
    # descending is not a reversed ascending order (that would put index 4 before index 2)
    z = [-0.0, 1.0, 0.0, -1.0, -0.0]
    steps += [('let z: f64[] = [-0.0, 1.0, 0.0, -1.0, -0.0]', None)] + sortcase('z', z, 'f')
    assert vf([z[i] for i in sort_idx(z)]) == '5: -1 -0 0 -0 1'
    assert vi(sort_idx(z, True)) == '5: 1 0 2 4 3'
    # ties: 1s at 1 and 4, the 2 at 3, 3s at 0 and 2
    w = [3.0, 1.0, 3.0, 2.0, 1.0]
    steps += [('let w = [3.0, 1.0, 3.0, 2.0, 1.0]', None)] + sortcase('w', w, 'f')
    assert vi(sort_idx(w)) == '5: 1 4 3 0 2' and vi(sort_idx(w, True)) == '5: 0 2 3 1 4'
    # NaN: nan, -nan (sign bit set), and a NaN made at run time by 0.0 / 0.0 of a var (whatever bits
    # the target gives it): after every number ascending, before every number descending, in input
    # order among themselves both ways
    q = [math.nan, 1.0, math.nan, -math.inf, 2.0, math.nan]
    steps += [('var zz = 0.0', None),
              ('let q: f64[] = [nan, 1.0, -nan, -inf, 2.0, zz / zz]', None)] + sortcase('q', q, 'f')
    assert vi(sort_idx(q)) == '6: 3 1 4 0 2 5' and vi(sort_idx(q, True)) == '6: 0 2 5 4 1 3'
    # infinities with finite values; a fixed-size operand (copied to the heap, Decision 39)
    steps += sortcase('[inf, -inf, 0.0, -2.5]', [math.inf, -math.inf, 0.0, -2.5], 'f', 'any')
    # empty and one element
    steps += [('let e: f64[] = []', None)] + sortcase('e', [], 'f', 'any')
    steps += sortcase('[5.0]', [5.0], 'f', 'any')
    prog('sort_f64', ['sort and argsort of f64 vectors (LANGUAGE.md 10.6): stable in both directions, -0 == +0',
                      '(signs printed, input order kept), NaN after every number ascending and before every number',
                      'descending (nan, -nan and a run-time 0/0, in input order), ties, infinities, a fixed-size',
                      'operand, empty, one element'], ['pf', 'pvi'], steps)


sort_f64()


def sort_i64():
    steps = []
    x = [I64_MAX, I64_MIN, 0, -1, 1, 0]
    steps += [('let x = [9223372036854775807, -9223372036854775808, 0, -1, 1, 0]', None)] + sortcase('x', x, 'i')
    assert vi(sort_idx(x)) == '6: 1 3 2 5 4 0' and vi(sort_idx(x, True)) == '6: 0 4 2 5 3 1'
    t = [2, 2, 1, 2, 1]
    steps += [('let t: i64[] = [2, 2, 1, 2, 1]', None)] + sortcase('t', t, 'i')
    steps += [('let e: i64[] = []', None)] + sortcase('e', [], 'i', 'any')
    steps += sortcase('[-4]', [-4], 'i', 'any')
    prog('sort_i64', ['sort and argsort of i64 vectors (LANGUAGE.md 10.6): -2^63 and 2^63 - 1, ties in both',
                      'directions (stable, desc not a reversed ascending), empty, one element'], ['pvi'], steps)


sort_i64()


def sort_misc():
    """desc: as a run-time bool expression; Decision 39: sort and argsort of a fixed-size vector are
    dynamic (`r = zeros(5)` would be a run-time shape error for an f64[3] variable, 4.5); sizes 31,
    32, 33 (both sides of the insertion-sort limit, DESIGN.md 4.8) with many ties and -0."""
    steps = []
    v = [3.0, 1.0, 2.0]
    steps += [('let fx = [3.0, 1.0, 2.0]', None),
              ('var r = sort(fx)', None),
              ('pf(r)', '3: 1 2 3'),
              ('r = zeros(5)', None),
              ('printf("%d\\n", len(r))', '5'),
              ('var p = argsort(fx, desc: true)', None),
              ('pvi(p)', '3: 0 2 1'),
              ('p = filled(7, 4)', None),
              ('pvi(p)', '4: 7 7 7 7'),
              ('let d: f64[] = fx', None),
              ('pf(sort(d, desc: want(3)))', '3: 3 2 1'),        # want(3) = 3 > 2 = true
              ('pf(sort(d, desc: want(1)))', '3: 1 2 3'),
              ('pvi(argsort(d, desc: len(d) < 0))', '3: 1 2 0'),
              ('pvi(argsort(d, desc: !(len(d) < 0)))', '3: 0 2 1')]
    # vectors of n = 31, 32, 33: v[k] = f64((k * 13) % 7) - 3.0, with -0.0 where that is 0 and k is
    # odd; i64 vectors w[k] = (k * 5) % 4 - 1
    for n in (31, 32, 33):
        xs = []
        for k in range(n):
            val = float((k * 13) % 7) - 3.0
            if val == 0.0 and k % 2 == 1:
                val = -0.0
            xs.append(val)
        ws = [(k * 5) % 4 - 1 for k in range(n)]
        steps.append(('let v%d = mkf(%d)' % (n, n), None))
        steps += sortcase('v%d' % n, xs, 'f')
        steps.append(('let w%d = mki(%d)' % (n, n), None))
        steps += sortcase('w%d' % n, ws, 'i')
    fns = r'''fn want(k: i64) -> bool {
    return k > 2
}
fn mkf(n: i64) -> f64[] {
    var v = zeros(n)
    for k in 0..n {
        v[k] = f64((k * 13) % 7) - 3.0
        if (k * 13) % 7 == 3 && k % 2 == 1 {
            v[k] = -0.0
        }
    }
    return v
}
fn mki(n: i64) -> i64[] {
    var w = filled(0, n)
    for k in 0..n {
        w[k] = (k * 5) % 4 - 1
    }
    return w
}
'''
    prog('sort_misc', ['sort and argsort (LANGUAGE.md 10.6, Decision 39): a fixed-size operand gives a dynamic result,',
                       'desc: as a run-time bool expression, f64 and i64 vectors of 31, 32 and 33 elements with',
                       'many ties and -0 (both sides of the insertion-sort limit of DESIGN.md 4.8)'],
         ['pf', 'pvi'], steps, fns=fns)


sort_misc()


def sort_lcg():
    """1000-element vectors from the LCG x <- (1103515245 x + 12345) mod 2^31, x0 = 12345 (exact in
    i64: the product is below 2^62), u = idiv(x, 65536): f64 values u % 41 - 20 (many ties; -0.0
    where that is 0 and u is odd), i64 values u % 11 - 5, and wide values f64(x - 2^30) / 1024.0
    (exact) and the i64 x - 2^30 (radix path). Printed: checksums sum((k + 1) * idx[k]) of each
    argsort and sum((k + 1) * value) of each sort (i64; f64 values through i64(v * 1024.0) or i64(v),
    exact), first and last values; computed here with the stable model of 10.6."""
    n = 1000
    x = 12345
    fa, ia, fw, iw = [], [], [], []
    for _ in range(n):
        x = (1103515245 * x + 12345) % 2147483648
        u = x // 65536
        val = float(u % 41 - 20)
        if val == 0.0 and u % 2 == 1:
            val = -0.0
        fa.append(val)
        ia.append(u % 11 - 5)
        fw.append(float(x - 1073741824) / 1024.0)
        iw.append(x - 1073741824)
    steps = []

    def ck(idx):
        return sum((k + 1) * i for k, i in enumerate(idx))

    def ckv(vals, scale):
        return sum((k + 1) * int(v * scale) for k, v in enumerate(vals))

    for name, xs, kind, scale in (('fa', fa, 'f', 1.0), ('ia', ia, 'i', 1), ('fw', fw, 'f', 1024.0),
                                  ('iw', iw, 'i', 1)):
        for desc in (False, True):
            idx = sort_idx(xs, desc)
            vals = [xs[i] for i in idx]
            opt = ', desc: true' if desc else ''
            if kind == 'f':
                cv = 'cf(sort(%s%s), %s)' % (name, opt, sea_float(scale))
                ends = '%s %s' % (g17(vals[0]), g17(vals[-1]))
                endc = 'printf("%%.17g %%.17g\\n", sort(%s%s)[0], sort(%s%s)[%d])' % (name, opt, name, opt, n - 1)
            else:
                cv = 'ci(sort(%s%s))' % (name, opt)
                ends = '%d %d' % (vals[0], vals[-1])
                endc = 'printf("%%d %%d\\n", sort(%s%s)[0], sort(%s%s)[%d])' % (name, opt, name, opt, n - 1)
            steps.append(('printf("%%d %%d\\n", ck(argsort(%s%s)), %s)' % (name, opt, cv),
                          '%d %d' % (ck(idx), ckv(vals, scale))))
            steps.append((endc, ends))
    fns = r'''fn ck(idx: i64[]) -> i64 {
    var s = 0
    for k in 0..len(idx) {
        s += (k + 1) * idx[k]
    }
    return s
}
fn cf(v: f64[], scale: f64) -> i64 {
    var s = 0
    for k in 0..len(v) {
        s += (k + 1) * i64(v[k] * scale)
    }
    return s
}
fn ci(v: i64[]) -> i64 {
    var s = 0
    for k in 0..len(v) {
        s += (k + 1) * v[k]
    }
    return s
}
'''
    fill = r'''var fa = zeros(1000)
var ia = filled(0, 1000)
var fw = zeros(1000)
var iw = filled(0, 1000)
var x = 12345
for k in 0..1000 {
    x = (1103515245 * x + 12345) % 2147483648
    let u = idiv(x, 65536)
    fa[k] = f64(u % 41 - 20)
    if u % 41 - 20 == 0 && u % 2 == 1 {
        fa[k] = -0.0
    }
    ia[k] = u % 11 - 5
    fw[k] = f64(x - 1073741824) / 1024.0
    iw[k] = x - 1073741824
}'''
    prog('sort_lcg', ['sort and argsort of 1000-element f64 and i64 vectors from an LCG (LANGUAGE.md 10.6;',
                      'DESIGN.md 4.8 radix path): many ties and -0, and wide values; checksums of each permutation',
                      'and sorted vector, ascending and descending, derived from the stable model'],
         [], [(fill, None)] + steps, fns=fns)


sort_lcg()


# ============================================================ find_* (10.6)
prog('find_basic', ['find, find_first, find_last (LANGUAGE.md 10.6): none true (-1), all true, mixed, empty,',
                    'a comparison result, find(M.flat) in column-major order; find is always dynamic'],
     ['pvi'], [
    ('pvi(find([false, false, false]))', '0:'),
    ('printf("%d %d\\n", find_first([false, false, false]), find_last([false, false, false]))', '-1 -1'),
    ('pvi(find([true, true, true]))', '3: 0 1 2'),
    ('printf("%d %d\\n", find_first([true, true, true]), find_last([true, true, true]))', '0 2'),
    ('let m: bool[] = [false, true, false, true, true, false]', None),
    ('pvi(find(m))', '3: 1 3 4'),
    ('printf("%d %d\\n", find_first(m), find_last(m))', '1 4'),
    ('let e: bool[] = []', None),
    ('pvi(find(e))', '0:'),
    ('printf("%d %d\\n", find_first(e), find_last(e))', '-1 -1'),
    ('let v: f64[] = [0.5, 3.0, nan, 2.5, 7.0]', None),
    ('pvi(find(v > 2.0))', '3: 1 3 4'),                     # NaN > 2 is false (6.4)
    ('printf("%d %d\\n", find_first(v > 2.0), find_last(v < 1.0))', '1 0'),
    # M 2 x 3, column-major flat: M[0,0] T, M[1,0] F, M[0,1] F, M[1,1] T, M[0,2] T, M[1,2] T
    ('let M = [true, false, true; false, true, true]', None),
    ('pvi(find(M.flat))', '4: 0 3 4 5'),
    ('printf("%d %d\\n", find_first(M.flat), find_last(M.flat))', '0 5'),
    ('printf("%d\\n", find_first([false, true]))', '1'),
    # find of a fixed bool[3] is an i64[]: assigning a 5-element vector is allowed (Decision 39)
    ('var q = find([true, false, true])', None),
    ('pvi(q)', '2: 0 2'),
    ('q = filled(1, 5)', None),
    ('pvi(q)', '5: 1 1 1 1 1'),
])


# ============================================================ heap_red_* (DESIGN.md 3.6.6 rules 15, 21, 23, 24)
HFNS = r'''fn mk(n: i64) -> f64[] {
    var v = zeros(n)
    for i in 0..n {
        v[i] = f64(i)
    }
    return v
}
'''
prog('heap_red_temps', ['reductions, sort and find of owned operands (DESIGN.md 3.6.6 rules 15, 23, 24): element-wise',
                        'results, selections, views, call results, a fixed operand copied for argsort, in a loop;',
                        'the heap check finds no live object'], ['pf', 'pvi'], [
    ('let d: f64[] = [4.0, 1.0, 3.0, 2.0]', None),
    ('printf("%g\\n", sum(d * 2.0))', '20'),
    ('pf(sort(d[0..3]))', '3: 1 3 4'),                       # 4 1 3 sorted
    ('let A: f64[,] = [1.0, 5.0; 3.0, 2.0]', None),
    ('printf("%g\\n", max(A.flat))', '5'),                     # flat 1 3 5 2
    ('pvi(argsort([3.0, 1.0, 2.0]))', '3: 1 2 0'),
    ('printf("%g\\n", mean(d[d > 1.5]))', '3'),               # 4 3 2: (4 + 3) + 2 = 9, / 3
    ('printf("%d\\n", nnz(d > 2.0))', '2'),
    ('pvi(find(d < 3.0))', '2: 1 3'),
    ('printf("%d %d\\n", find_first(d > 2.5), find_last(d > 2.5))', '0 2'),
    ('pf(sum(A * 2.0, dim: 0))', '2: 8 14'),                  # columns (1 + 3) * 2, (5 + 2) * 2
    ('pf(max(A.T, dim: 1))', '2: 3 5'),                       # rows of A.T are A's columns
    ('printf("%g %g\\n", sum(mk(5)), variance(mk(3)))', '10 1'),   # 0 1 2: mean 1, (1 + 0 + 1) / 2
    ('printf("%d\\n", argmax(mk(4) * -1.0))', '0'),           # -0 -1 -2 -3: the first, -0
    ('pvi(argsort(mk(3), desc: true))', '3: 2 1 0'),
    ('pf(sort(mk(3) - 1.0, desc: true))', '3: 1 0 -1'),
    ('var s = 0.0', None),
    ('for i in 0..3 {\n    s += sum(d * f64(i)) + f64(len(sort(d))) + f64(nnz(d > f64(i)))\n}', None),
    # i = 0: 0 + 4 + 4; i = 1: 10 + 4 + 3; i = 2: 20 + 4 + 2 -> 8 + 17 + 26 = 51
    ('printf("%g\\n", s)', '51'),
    ('let _ = sort(d)', None),
], fns=HFNS)

prog('heap_red_store', ['an owned index vector of a selection store (DESIGN.md 3.6.6 rule 21): v[argsort(w, desc:',
                        'true)] = 0.0 released at the end of its block, a selection of it, in a loop, on a fixed',
                        'target; the heap check finds no live object'], ['pf'], [
    ('var v: f64[] = [10.0, 20.0, 30.0, 40.0, 50.0]', None),
    ('let w: f64[] = [0.5, 2.5, 1.5]', None),
    ('v[argsort(w, desc: true)] = 0.0', None),                # indices 1 2 0
    ('pf(v)', '5: 0 0 0 40 50'),
    ('var u: f64[] = [1.0, 2.0, 3.0]', None),
    ('u[argsort(w, desc: true)[0..2]] = -1.0', None),         # indices 1 2
    ('pf(u)', '3: 1 -1 -1'),
    ('for k in 0..3 {\n    v[argsort(w)] = f64(k)\n}', None),  # indices 0 2 1, last k = 2
    ('pf(v)', '5: 2 2 2 40 50'),
    ('var f = [1.0, 2.0, 3.0, 4.0]', None),
    ('f[find(w > 1.0)] = 9.0', None),                         # w > 1: F T T -> indices 1 2
    ('pf(f)', '4: 1 9 9 4'),
    ('let g = v', None),
    ('v[argsort(w)[1..3]] += 1.0', None),                     # indices 2 1: copy on write, g unchanged
    ('pf(v)', '5: 2 3 3 40 50'),
    ('pf(g)', '5: 2 2 2 40 50'),
])


# ============================================================ programs/w4_sor_reduce (DESIGN.md 6.2)
def w4_sor_reduce():
    """programs/w4_sor_arrays.sea with the scalar loop for Tmax replaced by `var Thot = T`,
    `Thot[fixed] = -inf`, `let Tmax = max(Thot.flat)`. The scalar loop takes, over i (columns) then
    j (rows), i.e. column-major order, the first T[j, i] > Tmax among the unknown nodes starting from
    -inf; max(Thot.flat) is the first maximal element in column-major order (10.5) with the fixed
    nodes at -inf, which is the same value (the maximum of the unknown nodes is above -inf), so the
    program prints w4_sor_arrays.out byte for byte."""
    src = open(os.path.join(PROGRAMS, 'w4_sor_arrays.sea')).read()
    a = src.index('// the hot spot over the solved')
    b = src.index('printf("{\\"it_sor\\"')
    old = src[a:b]
    assert old == '''// the hot spot over the solved (non-Dirichlet) nodes, first maximum in column-major order
var Tmax = -inf
for i in 0..nx {
    for j in 0..ny {
        if !fixed[j, i] && T[j, i] > Tmax {
            Tmax = T[j, i]
        }
    }
}

''', old
    head_end = src.index('// inputs\n')
    header = '''// w4_sor_reduce -- programs/w4_sor_arrays.sea (W4's SOR with a whole-array set-up) with the scalar
// loop for the hot spot replaced by a reduction (DESIGN.md 6.2 "4f"): the Dirichlet nodes set to -inf
// in a copy of T, then the first maximum of its column-major flat view (LANGUAGE.md 10.5), the same
// value as the loop's, so the program prints the bytes of w4_sor_arrays.out.

'''
    new = '''// the hot spot over the solved (non-Dirichlet) nodes: the fixed nodes at -inf, then the first
// maximum in column-major order
var Thot = T
Thot[fixed] = -inf
let Tmax = max(Thot.flat)

'''
    write(os.path.join(PROGRAMS, 'w4_sor_reduce.sea'), header + src[head_end:a] + new + src[b:])
    write(os.path.join(PROGRAMS, 'w4_sor_reduce.out'), open(os.path.join(PROGRAMS, 'w4_sor_arrays.out')).read())
    COUNT['programs'] += 1


w4_sor_reduce()


# ============================================================ errors: run time (10.5, 9.2)
EO = 'integer overflow'
err_rt('r_red_sum_ovf', ['i64 sum of 2^62, 2^62, -2^62: the total 2^62 fits, but the second partial sum 2^63',
                         'overflows (LANGUAGE.md 10.5, Decision 42): integer overflow at the call\'s line, the',
                         'line printed before it flushed'],
       'printf("start\\n")\nlet v = [4611686018427387904, 4611686018427387904, -4611686018427387904]\n'
       'printf("%d\\n", sum(v))\n', 'sum(v)', EO, out='start\n')
err_rt('r_red_mean_ovf', ['mean of the same i64 vector: its sum is checked the same way (LANGUAGE.md 10.5)'],
       'let v: i64[] = [4611686018427387904, 4611686018427387904, -4611686018427387904]\n'
       'let m = mean(v)\nprintf("%g\\n", m)\n', 'mean(v)', EO)
err_rt('r_red_sum_ovf_neg', ['-2^62, -2^62, -1, 1: the partial sum -2^63 fits, the third -2^63 - 1 overflows',
                             '(LANGUAGE.md 10.5)'],
       'let v = [-4611686018427387904, -4611686018427387904, -1, 1]\nlet s = sum(v)\nprintf("%d\\n", s)\n',
       'sum(v)', EO)
err_rt('r_red_var_ovf', ['variance of an i64 vector uses the i64 mean, whose checked sum overflows (LANGUAGE.md',
                         '10.5)'],
       'let v = [9223372036854775807, 1, -1]\nprintf("%g\\n", variance(v))\n', 'variance(v)', EO)
err_rt('r_red_sum_dim_ovf', ['sum(I, dim: 1): row 0 fits (1), row 1 overflows at its second element; every',
                             'element of a dim: result follows the vector rule (LANGUAGE.md 10.5)'],
       'let I: i64[,] = [1, 0; 9223372036854775807, 1]\nlet r = sum(I, dim: 1)\nprintf("%d\\n", r[0])\n',
       'sum(I', EO)
err_rt('r_red_max_empty', ['max of an empty vector (LANGUAGE.md 10.5, 9.2): `max of an empty array`'],
       'printf("before\\n")\nlet e: f64[] = []\nprintf("%g\\n", max(e))\n', 'max(e)', 'max of an empty array',
       out='before\n')
err_rt('r_red_argmin_empty', ['argmin of an empty vector: the function\'s name in the message (DESIGN.md 2.6.2)'],
       'let e: f64[] = []\nlet k = argmin(e)\nprintf("%d\\n", k)\n', 'argmin(e)', 'argmin of an empty array')
err_rt('r_red_min_empty', ['min of an empty i64 vector (LANGUAGE.md 10.5)'],
       'let e: i64[] = []\nlet k = min(e)\nprintf("%d\\n", k)\n', 'min(e)', 'min of an empty array')
err_rt('r_red_argmax_empty', ['argmax of an empty vector made at run time (a selection of nothing)'],
       'let v: f64[] = [1.0, 2.0]\nlet k = argmax(v[v > 5.0])\nprintf("%d\\n", k)\n', 'argmax(', 'argmax of an empty array')
err_rt('r_red_max_dim_empty', ['max(Z, dim: 0) of a 0 x 3 matrix: each column has 0 elements, the vector rule\'s',
                               'error (LANGUAGE.md 10.5)'],
       'let Z = zeros(0, 3)\nlet r = max(Z, dim: 0)\nprintf("%d\\n", len(r))\n', 'max(Z', 'max of an empty array')
err_rt('r_red_min_dim1_empty', ['min(Z, dim: 1) of a 3 x 0 matrix: each row has 0 elements (LANGUAGE.md 10.5)'],
       'let Z = filled(0, 3, 0)\nlet r = min(Z, dim: 1)\nprintf("%d\\n", len(r))\n', 'min(Z', 'min of an empty array')

# ============================================================ errors: compile time (8.1; DESIGN.md 2.6.2 "Readings fixed by 4f")
NO = "no overload of '%s' accepts (%s)"
NA = 'not supported yet: named arguments'
DIMV = 'dim must be 0 or 1'
NC = 'not a constant expression'
TM = 'type mismatch: expected %s, found %s'
VDECL = 'let v: f64[] = [1.0, 2.0]\nlet A: f64[,] = [1.0, 2.0; 3.0, 4.0]\n'

# 115 (pass 1): at the first token of the first positional argument after a named one
err_c('err_sort_positional_after_named', ['sort(desc: true, v): a positional argument after a named one, 115 of',
                                          'pass 1 at that argument (LANGUAGE.md 8.1, Decision 41)'],
      VDECL + 'let s = sort(desc: true, v)\n', 'let s', 'v)', 'positional argument after a named argument')
err_c('err_sort_positional_first', ['115 is pass 1\'s: reported before a pass-2 error earlier in the source (an',
                                    'undeclared name on line 3; LANGUAGE.md 9.1, DESIGN.md 2.6.2)'],
      'let a = undeclaredName\nlet v: f64[] = [1.0]\nlet s = argsort(desc: false, v + 1.0)\n', 'let s', 'v + 1.0',
      'positional argument after a named argument')
# 225 at the second narg of a repeated name the function takes
err_c('err_red_dim_twice', ['a repeated dim: is parameter given twice (225) at the second narg (DESIGN.md 2.6.2)'],
      VDECL + 'let s = sum(A, dim: 0, dim: 1)\n', 'let s', 'dim: 1', 'parameter given twice')
err_c('err_sort_desc_twice', ['a repeated desc: is 225 at the second narg'],
      VDECL + 'let s = sort(v, desc: true, desc: false)\n', 'let s', 'desc: false', 'parameter given twice')
err_c('err_red_dim_twice_value_first', ['the arguments are checked in source order, each value before its narg:',
                                        'the second dim:\'s value qq is undeclared (200) before that narg\'s 225',
                                        '(DESIGN.md 2.6.2)'],
      VDECL + 'let s = sum(A, dim: 0, dim: qq)\n', 'let s', 'qq', "undeclared name 'qq'")
err_c('err_red_desc_twice_unknown', ['a repeated name the function does not take is the phase rule\'s word at its',
                                     'first narg (DESIGN.md 2.6.2)'],
      VDECL + 'let s = sum(v, desc: true, desc: true)\n', 'let s', 'desc', NA)
# dim: values: 201, then 237, then 262, at the value
err_c('err_red_dim_value', ['dim: 2 is dim must be 0 or 1 (262) at the value (LANGUAGE.md 10.5)'],
      VDECL + 'let s = sum(A, dim: 2)\n', 'let s', '2)', DIMV)
err_c('err_red_dim_value_expr', ['dim: 1 + 1 is the constant 2: 262 at the value, the + node at its first token',
                                 '(DESIGN.md 3.3)'],
      VDECL + 'let s = mean(A, dim: 1 + 1)\n', 'let s', '1 + 1', DIMV)
err_c('err_red_dim_value_const', ['dim: D with const D = -1: a constant expression of the wrong value, 262'],
      'const D = -1\n' + VDECL + 'let s = max(A, dim: D)\n', 'let s', 'D)', DIMV)
err_c('err_red_dim_not_const', ['dim: k with a local k (= 0): not a constant expression (237) at the value'],
      VDECL + 'let k = 0\nlet s = sum(A, dim: k)\n', 'let s', 'k)', NC)
err_c('err_red_dim_f64', ['dim: 0.0: type mismatch, expected i64 (201) at the value (LANGUAGE.md 10.5)'],
      VDECL + 'let s = sum(A, dim: 0.0)\n', 'let s', '0.0', TM % ('i64', 'f64'))
err_c('err_red_dim_bool', ['dim: true: 201, expected i64, found bool'],
      VDECL + 'let s = nnz(A > 1.0, dim: true)\n', 'let s', 'true', TM % ('i64', 'bool'))
err_c('err_red_dim_order_201_237', ['dim: x with an f64 local x: not constant and not i64; the type (201) is',
                                    'checked first (LANGUAGE.md 10.5, DESIGN.md 2.6.2)'],
      VDECL + 'var x = 2.5\nlet s = variance(A, dim: x)\n', 'let s', 'x)', TM % ('i64', 'f64'))
err_c('err_red_dim_order_201_262', ['dim: 2.0: of the wrong type and value: 201 first'],
      VDECL + 'let s = std(A, dim: 2.0)\n', 'let s', '2.0', TM % ('i64', 'f64'))
err_c('err_red_dim_order_237_262', ['dim: k with a local k = 5: not constant and not 0 or 1: 237 before 262'],
      VDECL + 'let k = 5\nlet s = min(A, dim: k)\n', 'let s', 'k)', NC)
err_c('err_red_dim_value_before_call', ['sum(v, dim: 2) of a vector: the arguments are checked before the call, so',
                                        'the value\'s 262 comes before the call\'s 243 (DESIGN.md 2.6.2)'],
      VDECL + 'let s = sum(v, dim: 2)\n', 'let s', '2)', DIMV)
# names the function does not take: the phase rule's word at the narg
err_c('err_red_desc_unknown', ['sum(v, desc: true): desc is not a name of sum: not supported yet: named arguments',
                               'at the narg (DESIGN.md 2.6.2 step 4f)'],
      VDECL + 'let s = sum(v, desc: true)\n', 'let s', 'desc', NA)
err_c('err_red_argmax_dim', ['argmax(A, dim: 0): argmax takes no dim:, so the phase rule\'s word at the narg,',
                             'never 243 (LANGUAGE.md 10.5, DESIGN.md 2.6.2)'],
      VDECL + 'let k = argmax(A, dim: 0)\n', 'let k', 'dim', NA)
err_c('err_sort_dim_unknown', ['sort(v, dim: 0): dim is not a name of sort'],
      VDECL + 'let s = sort(v, dim: 0)\n', 'let s', 'dim', NA)
err_c('err_find_desc_unknown', ['find(m, desc: true): find takes no named argument'],
      'let m: bool[] = [true]\nlet r = find(m, desc: true)\n', 'let r', 'desc', NA)
# 243 at the call, the types in call order, a named argument written name: T
err_c('err_sort_positional_option', ['sort(v, true): options are given only by name (LANGUAGE.md 8.1, Decision 43)'],
      VDECL + 'let s = sort(v, true)\n', 'let s', 'sort', NO % ('sort', 'f64[], bool'))
err_c('err_red_dim_vector', ['sum(v, dim: 0) of a vector: dim: goes with a matrix only (LANGUAGE.md 10.5)'],
      VDECL + 'let s = sum(v, dim: 0)\n', 'let s', 'sum', NO % ('sum', 'f64[], dim: i64'))
err_c('err_red_dim_vector_fixed', ['max of a fixed f64[3] with dim: 1: the fixed type spelled f64[3]'],
      'let s = max([1.0, 2.0, 3.0], dim: 1)\n', 'let s', 'max', NO % ('max', 'f64[3], dim: i64'))
err_c('err_red_sum_bool', ['sum of a bool vector (LANGUAGE.md 10.5: f64 and i64 vectors only)'],
      'let b: bool[] = [true, false]\nlet s = sum(b)\n', 'let s', 'sum', NO % ('sum', 'bool[]'))
err_c('err_red_nnz_f64', ['nnz of an f64 vector (bool vectors only)'],
      VDECL + 'let s = nnz(v)\n', 'let s', 'nnz', NO % ('nnz', 'f64[]'))
err_c('err_red_matrix_nodim', ['sum of a matrix without dim: (reduce it with dim: or through A.flat)'],
      VDECL + 'let s = sum(A)\n', 'let s', 'sum', NO % ('sum', 'f64[,]'))
err_c('err_red_two_positional', ['mean(v, v): a second positional argument'],
      VDECL + 'let s = mean(v, v)\n', 'let s', 'mean', NO % ('mean', 'f64[], f64[]'))
err_c('err_red_no_arg', ['any(): no argument'],
      'let s = any()\n', 'let s', 'any', NO % ('any', ''))
err_c('err_sort_matrix', ['sort of a matrix (vectors only, LANGUAGE.md 10.6)'],
      VDECL + 'let s = sort(A)\n', 'let s', 'sort', NO % ('sort', 'f64[,]'))
err_c('err_sort_bool', ['argsort of a bool vector (f64, i64 and str vectors only, LANGUAGE.md 10.6)'],
      'let b: bool[] = [true, false]\nlet s = argsort(b, desc: true)\n', 'let s', 'argsort',
      NO % ('argsort', 'bool[], desc: bool'))
err_c('err_find_f64', ['find of an f64 vector (bool vectors only, LANGUAGE.md 10.6)'],
      VDECL + 'let s = find_last(v)\n', 'let s', 'find_last', NO % ('find_last', 'f64[]'))
err_c('err_sort_desc_type', ['desc: 1 is not a bool: 201 at the value (LANGUAGE.md 10.6, DESIGN.md 2.6.2)'],
      VDECL + 'let s = sort(v, desc: 1)\n', 'let s', '1)', TM % ('bool', 'i64'))
# Decision 39: a dim: reduction of a fixed f64[3,4] is a fixed vector of 4 (dim: 0) with the result
# element type, so a mismatching fixed binding is the compile-time shape mismatch (217, the target's
# shape first, at the value) or type mismatch (201)
FIXED34 = 'let F = [1.0, 2.0, 3.0, 4.0; 5.0, 6.0, 7.0, 8.0; 9.0, 10.0, 11.0, 12.0]\n'
err_c('err_red_dim_fixed_shape', ['sum(F, dim: 0) of a fixed f64[3,4] is an f64[4]: bound to f64[3] it is the',
                                  'static shape mismatch 3 vs 4 at the value (Decision 39, DESIGN.md 3.5.5)'],
      FIXED34 + 'let s: f64[3] = sum(F, dim: 0)\n', 'let s', 'sum', 'shape mismatch: 3 vs 4')
err_c('err_red_dim_fixed_type', ['mean(I, dim: 1) of a fixed i64[2,3] is an f64[2]: bound to i64[2] it is 201',
                                 '(Decision 39: the function\'s result element type)'],
      'let I = [1, 2, 3; 4, 5, 6]\nlet m: i64[2] = mean(I, dim: 1)\n', 'let m', 'mean',
      TM % ('i64[2]', 'f64[2]'))

# ============================================================ the goldens step 4f retires (DESIGN.md 6.2)
for old in ('err_ns_lib_sum', 'err_ns_lib_max1', 'err_ns_lib_max1_fixed', 'err_ns_lib_min1'):
    for ext_ in ('.sea', '.err', '.status', '.out'):
        p = os.path.join(ERRORS, old + ext_)
        if os.path.exists(p):
            os.remove(p)

print('arr4f_cases: %d programs, %d errors' % (COUNT['programs'], COUNT['errors']))
