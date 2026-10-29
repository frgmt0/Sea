"""Sub-phase 4e corpus: programs/ and errors/ tests of the array expressions (DESIGN.md 6.2 "4e").

Run with `timeout 120 uv run --no-project python tests/vectors/arr4e_cases.py`. It writes the
programs/sel_*, programs/ew_*, programs/arr_* and programs/heap_* tests of sub-phase 4e listed
below, programs/w4_sor_arrays, and the 4e errors/ tests (run-time selection, shape, conversion and
range errors; the static shape errors of DESIGN.md 3.5.5; 201, 202, 218, 219, 220, 239, 252, 257 at
array constructs; the phase-rule words that remain after step 4e). It also deletes the ten 4d
errors/ goldens that step 4e makes obsolete (DESIGN.md 6.2 "4e": their programs now compile).

Every expected output is written out by hand in this file from LANGUAGE.md (4.5, 5, 6.3-6.9, 7.3,
7.5, 8.3, 9.2, 10.1-10.7, 11.1) and, where DESIGN.md defines a message order or a position, from
DESIGN.md 2.6.2 (the error table and its `at` column), 3.3 (node positions), 3.5.5 (static shapes,
implicit dyn/fix) and 3.6.6 rules 20-28 (the order of the run-time checks); the comment beside each
case gives the derivation. Nothing here runs the compiler. The run-time error line of an errors/
test is the line of the source that holds the marker text given with it, and a compile error's
column is that of its marker inside that line (both computed from the source text).

Printing: v1 has no `print` until phase 6 and no reductions until 4f, so the programs print arrays
with small helper functions (HELPERS below): a vector as `n:` and its elements, each after one
blank (`pf` %g for f64, `pvi` %d for i64, `pvb` %d for bool, which prints 0 or 1, LANGUAGE.md
11.1); a matrix as `RxC` and then, for each row, ` |` followed by its elements (`pmf`, `pmi`,
`pmb`). So `pf([1.0, 2.5])` prints `2: 1 2.5`, an empty vector `0:`, a 2 x 3 matrix
`2x3 | 1 2 3 | 4 5 6`, a 3 x 0 matrix `3x0 | | |`, a 0 x 3 matrix `0x3`. %g prints 6 significant
digits, `-0` for negative zero, and Sea's spellings `NaN`, `Inf`, `-Inf` (LANGUAGE.md 11.1).
"""

import os

HERE = os.path.dirname(os.path.abspath(__file__))
TESTS = os.path.dirname(HERE)
PROGRAMS = os.path.join(TESTS, 'programs')
ERRORS = os.path.join(TESTS, 'errors')
ACCEPT = os.path.join(TESTS, 'accept')
COUNT = {'programs': 0, 'errors': 0}


def write(path, text):
    with open(path, 'w') as f:
        f.write(text)


def source(name, comment, body):
    head = ''.join('// %s\n' % c for c in comment)
    head = '// %s -- ' % name + head[3:]
    return head + body


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
    'pmf': r'''fn pmf(A: f64[,]) {
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
    'pmi': r'''fn pmi(A: i64[,]) {
    printf("%dx%d", rows(A), cols(A))
    for i in 0..rows(A) {
        printf(" |")
        for j in 0..cols(A) {
            printf(" %d", A[i, j])
        }
    }
    printf("\n")
}
''',
    'pmb': r'''fn pmb(A: bool[,]) {
    printf("%dx%d", rows(A), cols(A))
    for i in 0..rows(A) {
        printf(" |")
        for j in 0..cols(A) {
            printf(" %d", A[i, j])
        }
    }
    printf("\n")
}
''',
}


def prog(name, comment, helpers, steps, fns=''):
    """A programs/ test. steps: (code, expected) pairs in program order; expected is the text the
    code prints (lines separated by LF, without the final LF) or None. fns: functions placed
    after the printing helpers."""
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


def int_literal(n, per_line=16):
    """`[0, 1, ..., n-1]` with newlines inside the brackets (ignored, LANGUAGE.md 6.9, 3.7)."""
    rows = []
    for s in range(0, n, per_line):
        rows.append('    ' + ', '.join(str(k) for k in range(s, min(n, s + per_line))))
    return '[\n' + ',\n'.join(rows) + '\n]'


# ============================================================ selections: reads (5.1-5.4, 6.1)
# v is a fixed f64[5] (one row of 5 scalars, 6.9) and d a dynamic f64[] of the same values; a
# selection is always dynamic (DESIGN.md 3.5.5) and is printed through pf's f64[] parameter.
prog('sel_vec_read', ['vector selections in reads: ranges, ..=, steps, negative steps, empty ranges, :, $,',
                      'index vectors with repeats, masks of both kinds, nested selections (LANGUAGE.md 5.1-5.4)'],
     ['pf', 'pvi', 'pvb'], [
    ('let v = [10.0, 11.0, 12.0, 13.0, 14.0]', None),
    ('var d = zeros(5)', None),
    ('for i in 0..5 {\n    d[i] = 10.0 + f64(i)\n}', None),          # d = 10 11 12 13 14
    ('pf(v[1..3])', '2: 11 12'),                  # half-open: positions 1, 2 (5.1)
    ('pf(v[1..=3])', '3: 11 12 13'),              # inclusive: 1, 2, 3
    ('pf(v[0..5 step 2])', '3: 10 12 14'),        # length ceil(5 / 2) = 3: 0, 2, 4
    ('pf(v[4..=0 step -2])', '3: 14 12 10'),      # counts down: 4, 2, 0
    ('pf(v[3..0 step -1])', '3: 13 12 11'),       # step -1 stops before 0: 3, 2, 1
    ('pf(v[2..2])', '0:'),                        # empty (a >= b)
    ('pf(v[9..2])', '0:'),                        # empty; an empty range never fails (5.4)
    ('pf(v[5..5])', '0:'),                        # empty at the extent: never checked
    ('pf(v[:])', '5: 10 11 12 13 14'),            # the whole dimension
    ('pf(v[1..$])', '4: 11 12 13 14'),            # $ = 5 (5.3)
    ('pf(v[0..$ step 2])', '3: 10 12 14'),
    ('pf(v[$ - 2..$])', '2: 13 14'),              # 3..5
    ('pf(v[[3, 0, 3]])', '3: 13 10 13'),          # an index vector: in order, repeats allowed (5.2)
    ('pf(v[[0, $ - 1]])', '2: 10 14'),            # $ in a literal inside an index is len(v) (5.3)
    ('pf(v[[true, false, true, false, true]])', '3: 10 12 14'),   # mask: true positions ascending
    ('pf(v[v > 11.5])', '3: 12 13 14'),           # mask of a comparison (12, 13, 14 > 11.5)
    ('pf(d[1..3])', '2: 11 12'),
    ('pf(d[(0..5 step 2)])', '3: 10 12 14'),      # a range value (the i64[] 0 2 4) as index vector
    ('let k = filled(4, 2)', None),               # i64[] 4 4 (untyped 4 is i64, 10.2)
    ('pf(d[k])', '2: 14 14'),
    ('let e: i64[] = []', None),                  # [] from the declared type: length 0 (6.9)
    ('pf(d[e])', '0:'),
    ('pf(d[d < 0.0])', '0:'),                     # a mask without a true element
    ('let w = d[1..4][1..3]', None),              # d[1..4] = 11 12 13, then [1..3] = 12 13
    ('pf(w)', '2: 12 13'),
    ('let iv = (0..3)', None),                    # i64[] 0 1 2
    ('let b = [false, true, false, true, true]', None),
    ('pvi(iv[b[0..3]])', '1: 1'),                 # b[0..3] = F T F masks iv: position 1, value 1
    ('pvb(b[[4, 0]])', '2: 1 0'),                 # b[4] = true, b[0] = false
    ('pvb(b[1..=3 step 2])', '2: 1 1'),           # positions 1, 3
])

# A[i, j] = 4i + j + 1 (a fixed f64[3,4]; rows written left to right, 6.9); D the same values in
# a dynamic f64[,]. A scalar index removes its dimension; every other index keeps it (5.2).
prog('sel_mat_read', ['matrix selections in reads: row, column, block, :, steps, negative steps, empty',
                      'ranges, index vectors, masks of one dimension and of the whole matrix (LANGUAGE.md 5.2)'],
     ['pf', 'pmf', 'pmi', 'pvb'], [
    ('let A = [1.0, 2.0, 3.0, 4.0; 5.0, 6.0, 7.0, 8.0; 9.0, 10.0, 11.0, 12.0]', None),
    ('var D = zeros(3, 4)', None),
    ('for i in 0..3 {\n    for j in 0..4 {\n        D[i, j] = f64(4 * i + j + 1)\n    }\n}', None),
    ('pf(A[1, :])', '4: 5 6 7 8'),                # a row: a vector
    ('pf(A[:, 2])', '3: 3 7 11'),                 # a column: a vector
    ('pmf(A[0..2, 1..3])', '2x2 | 2 3 | 6 7'),    # a block: rows 0 1, cols 1 2
    ('pmf(A[0..1, :])', '1x4 | 1 2 3 4'),         # a 1 x cols matrix (5.2)
    ('pmf(A[:, :])', '3x4 | 1 2 3 4 | 5 6 7 8 | 9 10 11 12'),
    ('pmf(A[0..3 step 2, 0..4 step 3])', '2x2 | 1 4 | 9 12'),       # rows 0 2; cols 0 3
    ('pf(A[2..=0 step -1, 1])', '3: 10 6 2'),     # rows 2 1 0 of column 1
    ('pmf(A[2..=0 step -2, 3..1 step -1])', '2x2 | 12 11 | 4 3'),   # rows 2 0; cols 3 2
    ('pmf(A[1..1, :])', '0x4'),                   # empty rows: 0 x 4
    ('pmf(A[:, 2..2])', '3x0 | | |'),             # empty columns: 3 x 0
    ('pmf(A[[2, 0], [1, 1, 3]])', '2x3 | 10 10 12 | 2 2 4'),        # index vectors in both dims
    ('pmf(A[[true, false, true], :])', '2x4 | 1 2 3 4 | 9 10 11 12'),   # a mask of the rows
    ('pf(A[1, [false, true, true, false]])', '2: 6 7'),             # a mask of the columns
    # A[M]: a vector of the elements where M is true in column-major order (5.2): column 0 gives
    # 9, column 1 gives 10, column 2 gives 7 11, column 3 gives 8 12 (the elements above 6.5)
    ('pf(A[A > 6.5])', '6: 9 10 7 11 8 12'),
    ('pf(D[D > 6.5])', '6: 9 10 7 11 8 12'),
    ('pmf(D[$ - 1..$, $ - 2..$])', '1x2 | 11 12'),  # $ is 3 in dim 0 (rows 2..3), 4 in dim 1
    ('pf(D[0, 1..$])', '3: 2 3 4'),
    ('pf(D[D > 100.0])', '0:'),
    ('pmf(D[(0..3), [3]])', '3x1 | 4 | 8 | 12'),  # an i64[] and an i64[1]: both keep their dim
    ('let B = [1, 2; 3, 4]', None),               # i64[2,2]
    ('pmi(B[:, [1, 0]])', '2x2 | 2 1 | 4 3'),
    ('let C = [true, false; false, true]', None),
    ('pvb(C[C])', '2: 1 1'),                      # the true elements of C, both true
    ('pvb(C[1, :])', '2: 0 1'),
])

# ============================================================ selections: stores (5.5)
# The value is evaluated first, then the indices, the checks, and the stores in increasing linear
# order of the selection; with a repeated position the last store wins (5.5).
prog('sel_vec_store', ['vector selection stores: ranges, steps, negative steps, empty selections, :, index',
                       'vectors with repeats (last store wins), masks with a scalar and with a vector (LANGUAGE.md 5.5)'],
     ['pf', 'pvi', 'pvb'], [
    ('var v = zeros(6)', None),
    ('v[1..3] = 5.0', None),                      # 0 5 5 0 0 0
    ('pf(v)', '6: 0 5 5 0 0 0'),
    ('v[3..6] = [1.0, 2.0, 3.0]', None),          # an array of the selected shape
    ('pf(v)', '6: 0 5 5 1 2 3'),
    ('v[5..=0 step -2] = [7.0, 8.0, 9.0]', None),  # positions 5 3 1 get 7 8 9
    ('pf(v)', '6: 0 9 5 8 2 7'),
    ('v[2..2] = 4.0', None),                      # an empty selection: nothing stored
    ('v[4..1] = []', None),                       # [] typed by the selection (f64[] of length 0, 6.9)
    ('pf(v)', '6: 0 9 5 8 2 7'),
    ('v[:] = 1.5', None),
    ('pf(v)', '6: 1.5 1.5 1.5 1.5 1.5 1.5'),
    ('v[[0, 2, 0]] = [10.0, 20.0, 30.0]', None),  # v[0] = 10, v[2] = 20, v[0] = 30: the last wins
    ('pf(v)', '6: 30 1.5 20 1.5 1.5 1.5'),
    ('v[v > 10.0] = 0.0', None),                  # mask T F T F F F (computed before the stores)
    ('pf(v)', '6: 0 1.5 0 1.5 1.5 1.5'),
    ('v[v == 1.5] = [1.0, 2.0, 3.0, 4.0]', None),  # nnz 4: positions 1 3 4 5 (5.5)
    ('pf(v)', '6: 0 1 0 2 3 4'),
    ('var w = filled(0, 4)', None),               # i64[] 0 0 0 0
    ('w[(0..4 step 3)] = 9', None),               # index vector 0 3
    ('pvi(w)', '4: 9 0 0 9'),
    ('w[[1, 2]] = (5..7)', None),                 # the value is the i64[] 5 6
    ('pvi(w)', '4: 9 5 6 9'),
    ('var b = filled(false, 3)', None),
    ('b[[true, false, true]] = true', None),
    ('pvb(b)', '3: 1 0 1'),
    ('var f = [1.0, 2.0, 3.0, 4.0]', None),       # a fixed f64[4] target
    ('f[1..3] = 0.0', None),
    ('pf(f)', '4: 1 0 0 4'),
    ('f[[3, 0]] = [8.0, 9.0]', None),             # f[3] = 8, f[0] = 9
    ('pf(f)', '4: 9 0 0 8'),
    ('f[$ - 1..$] = 7.0', None),                  # $ = 4: position 3
    ('pf(f)', '4: 9 0 0 7'),
])

prog('sel_mat_store', ['matrix selection stores: row, column, block, index vectors with repeats (stores in',
                       'the selection\'s column-major order), masks, negative steps, : (LANGUAGE.md 5.5)'],
     ['pmf', 'pmi', 'pmb'], [
    ('var A = zeros(3, 4)', None),
    ('A[1, :] = 1.0', None),                      # row 1 all 1
    ('A[:, 2] = [7.0, 8.0, 9.0]', None),          # column 2 = 7 8 9 (overwrites A[1, 2])
    ('pmf(A)', '3x4 | 0 0 7 0 | 1 1 8 1 | 0 0 9 0'),
    ('A[0..2, 0..2] = [1.0, 2.0; 3.0, 4.0]', None),   # a block from a 2 x 2 literal
    ('pmf(A)', '3x4 | 1 2 7 0 | 3 4 8 1 | 0 0 9 0'),
    ('A[2, 1..4] = [5.0, 6.0, 7.0]', None),       # part of row 2
    ('pmf(A)', '3x4 | 1 2 7 0 | 3 4 8 1 | 0 5 6 7'),
    # the selection rows 0 2, cols 3 3 is 2 x 2; its elements are stored in increasing linear
    # (column-major) order: sel(0,0) = 10 to A[0,3], sel(1,0) = 12 to A[2,3], sel(0,1) = 11 to
    # A[0,3], sel(1,1) = 13 to A[2,3]: the last stores win, A[0,3] = 11 and A[2,3] = 13
    ('A[[0, 2], [3, 3]] = [10.0, 11.0; 12.0, 13.0]', None),
    ('pmf(A)', '3x4 | 1 2 7 11 | 3 4 8 1 | 0 5 6 13'),
    ('A[A > 10.0] = 0.0', None),                  # 11 and 13
    ('pmf(A)', '3x4 | 1 2 7 0 | 3 4 8 1 | 0 5 6 0'),
    # the zeros in column-major order: (2,0) in column 0, then (0,3) and (2,3) in column 3
    ('A[A == 0.0] = [-1.0, -2.0, -3.0]', None),
    ('pmf(A)', '3x4 | 1 2 7 -2 | 3 4 8 1 | -1 5 6 -3'),
    ('A[[true, false, true], :] = 0.5', None),    # rows 0 and 2
    ('pmf(A)', '3x4 | 0.5 0.5 0.5 0.5 | 3 4 8 1 | 0.5 0.5 0.5 0.5'),
    ('A[1..=0 step -1, 0] = [5.0, 6.0]', None),   # positions 1 0 get 5 6
    ('pmf(A)', '3x4 | 6 0.5 0.5 0.5 | 5 4 8 1 | 0.5 0.5 0.5 0.5'),
    ('A[1..1, :] = 3.0', None),                   # empty: nothing stored
    ('A[:, :] = 2.0', None),
    ('pmf(A)', '3x4 | 2 2 2 2 | 2 2 2 2 | 2 2 2 2'),
    ('var B = filled(0, 2, 3)', None),            # i64[,]
    ('B[:, 1] = (4..6)', None),                   # column 1 = 4 5
    ('B[0, [true, false, true]] = 7', None),      # B[0,0] = B[0,2] = 7
    ('pmi(B)', '2x3 | 7 4 7 | 0 5 0'),
    ('var F = [1.0, 2.0; 3.0, 4.0]', None),       # a fixed f64[2,2] target
    ('F[:, 0] = [9.0, 8.0]', None),
    ('F[1, :] = 0.0', None),
    ('pmf(F)', '2x2 | 9 2 | 0 0'),
    ('var C = filled(false, 2, 2)', None),
    ('C[[1], :] = [true, true].row', None),       # a 1 x 2 selection from a 1 x 2 value
    ('pmb(C)', '2x2 | 0 0 | 1 1'),
])

# x[sel] op= e: indices, the read of the selected elements, e, the operation (the selection's
# shape as the left operand's, with broadcasting, 6.3), the store (5.5).
prog('sel_compound_ops', ['compound selection assignment on vectors and matrices: ranges, :, masks, index',
                          'vectors with repeats (gather, operate, scatter: the last store wins), broadcasting',
                          '(LANGUAGE.md 5.5, 6.3)'],
     ['pf', 'pvi', 'pmf'], [
    ('var v: f64[] = [1.0, 2.0, 3.0, 4.0, 5.0]', None),
    ('v[1..4] += 10.0', None),
    ('pf(v)', '5: 1 12 13 14 5'),
    ('v[0..2] -= [1.0, 2.0]', None),
    ('pf(v)', '5: 0 10 13 14 5'),
    ('v[[4, 4]] += [1.0, 2.0]', None),            # read 5 5, add 1 2: 6 7; v[4] = 6 then 7
    ('pf(v)', '5: 0 10 13 14 7'),
    ('v[v > 12.0] *= 2.0', None),                 # positions 2 3: 26 28
    ('pf(v)', '5: 0 10 26 28 7'),
    ('v[:] /= 2.0', None),
    ('pf(v)', '5: 0 5 13 14 3.5'),
    ('var w = filled(1, 4)', None),
    ('w[(0..4 step 2)] += 5', None),              # positions 0 2
    ('w[[3, 1]] *= [2, 3]', None),                # w[3] = 1 * 2, w[1] = 1 * 3
    ('pvi(w)', '4: 6 3 6 2'),
    ('var A = ones(2, 3)', None),
    ('A[0, :] += [1.0, 2.0, 3.0]', None),         # row 0: 2 3 4
    ('A[:, 1] *= 10.0', None),                    # column 1: 30 10
    ('A[0..2, 1..3] -= [1.0, 1.0; 2.0, 2.0]', None),  # 30-1, 4-1; 10-2, 1-2
    ('pmf(A)', '2x3 | 2 29 3 | 1 8 -1'),
    ('A[A < 2.0] += 100.0', None),                # A[1,0] = 1 and A[1,2] = -1: 101, 99
    ('pmf(A)', '2x3 | 2 29 3 | 101 8 99'),
    ('A.flat[[0, 5]] /= 4.0', None),              # flat 0 = A[0,0] = 2: 0.5; flat 5 = A[1,2]: 24.75
    ('pmf(A)', '2x3 | 0.5 29 3 | 101 8 24.75'),
    ('A[:, 0..2] *= [2.0; 3.0]', None),           # 2 x 2 times a 2 x 1 column (6.3): row 0 x2, row 1 x3
    ('pmf(A)', '2x3 | 1 58 3 | 303 24 24.75'),
    ('A[0..1, :] += [1.0, 2.0, 3.0].row', None),  # 1 x 3 plus 1 x 3
    ('pmf(A)', '2x3 | 2 60 6 | 303 24 24.75'),
    ('var K = zeros(3, 3)', None),
    ('let ke = [1.0, 2.0; 3.0, 4.0]', None),
    ('K[[0, 2], [0, 2]] += ke', None),            # K[0,0] 1, K[0,2] 2, K[2,0] 3, K[2,2] 4
    # a repeated index (W2's K[idx, idx] += ke): the 2 x 2 read is four copies of K[1,1] = 0; plus
    # ke gives 1 2; 3 4, scattered in column-major order 1, 3, 2, 4 to K[1,1]: the last, 4, wins
    ('K[[1, 1], [1, 1]] += ke', None),
    ('pmf(K)', '3x3 | 1 0 2 | 0 4 0 | 3 0 4'),
])

# `a += b` of whole arrays is `a = a + b` (7.3); assigning a whole array to a var replaces its
# value and its shape (7.3), so the dynamic 1 x 3 m becomes 2 x 3 (6.3: per dimension, 1 and 3
# give 3, 1 and 2 give 2).
prog('ew_compound', ['compound assignment of whole arrays (a += b; LANGUAGE.md 7.3, 6.3; DESIGN.md 3.6.6',
                     'rule 15 (i)), a dynamic matrix whose shape changes by broadcasting, fixed and i64 operands'],
     ['pf', 'pvi', 'pmf'], [
    ('var a = zeros(3)', None),
    ('a += ones(3)', None),                       # 1 1 1
    ('a *= 2.0', None),                           # 2 2 2
    ('a -= [0.5, 1.0, 1.5]', None),               # 1.5 1 0.5
    ('pf(a)', '3: 1.5 1 0.5'),
    ('var m = zeros(1, 3)', None),
    ('m += ones(2, 1)', None),
    ('pmf(m)', '2x3 | 1 1 1 | 1 1 1'),
    ('var f = [1.0, 2.0]', None),                 # fixed f64[2]
    ('f += [10.0, 20.0]', None),                  # 11 22
    ('f /= 2.0', None),                           # 5.5 11
    ('pf(f)', '2: 5.5 11'),
    ('var n = filled(3, 2)', None),               # i64[] 3 3
    ('n *= n', None),                             # 9 9
    ('pvi(n)', '2: 9 9'),
])

# Aliasing (5.5): an assignment behaves as if its right side were computed into a temporary first.
prog('sel_alias', ['aliasing: selection stores whose value reads the target (shifts, reversal, swap,',
                   'a fixed-size value that is the target itself; LANGUAGE.md 5.5 "Aliasing")'],
     ['pf', 'pvi', 'pmf'], [
    ('var v: f64[] = [1.0, 2.0, 3.0, 4.0, 5.0]', None),
    ('let n = len(v)', None),
    ('v[1..n] = v[0..n-1]', None),                # shift right: 1 1 2 3 4
    ('pf(v)', '5: 1 1 2 3 4'),
    ('v[0..n-1] = v[1..n]', None),                # shift left: 1 2 3 4 4
    ('pf(v)', '5: 1 2 3 4 4'),
    ('v[:] = v[$ - 1..=0 step -1]', None),        # reversed: 4 4 3 2 1
    ('pf(v)', '5: 4 4 3 2 1'),
    ('v[[2, 3]] = v[[3, 2]]', None),              # swap: v[2] = old v[3] = 2, v[3] = old v[2] = 3
    ('pf(v)', '5: 4 4 2 3 1'),
    ('v[1..4] = v[0..3] * 2.0 + v[2..5]', None),  # 8 8 4 + 2 3 1 = 10 11 5 (old values)
    ('pf(v)', '5: 4 10 11 5 1'),
    ('var A: f64[,] = [1.0, 2.0; 3.0, 4.0; 5.0, 6.0]', None),
    ('A[1..3, :] = A[0..2, :]', None),            # rows 1 2 become old rows 0 1
    ('pmf(A)', '3x2 | 1 2 | 1 2 | 3 4'),
    ('A[:, 0] = A[:, 1] + A[:, 0]', None),        # 2+1, 2+1, 4+3
    ('pmf(A)', '3x2 | 3 2 | 3 2 | 7 4'),
    # flat (column-major) 3 3 7 2 2 4 shifted by one: 3 3 3 7 2 2, so column 0 is 3 3 3 and
    # column 1 is 7 2 2
    ('A.flat[1..6] = A.flat[0..5]', None),
    ('pmf(A)', '3x2 | 3 7 | 3 2 | 3 2'),
    ('A = A.T', None),                            # a whole assignment from a view of itself
    ('pmf(A)', '2x3 | 3 3 3 | 7 2 2'),
    ('var F = [1, 2, 3, 4]', None),               # fixed i64[4]
    ('F[1..4] = F[0..3]', None),                  # 1 1 2 3
    ('pvi(F)', '4: 1 1 2 3'),
    ('F[[3, 2, 1, 0]] = F', None),                # F[3] = 1, F[2] = 1, F[1] = 2, F[0] = 3 (old F)
    ('pvi(F)', '4: 3 2 1 1'),
])

# Decision 34 (DESIGN.md 9): the indices are evaluated before any element is stored (5.5).
prog('sel_alias_index', ['an index vector that is the target itself (Decision 34; LANGUAGE.md 5.5): v[v] = 5',
                         'stores at 2 0 1; w[w] += 10 reads 2 0 1 and stores w[1] = 12, w[2] = 10, w[0] = 11; the',
                         'same on fixed-size i64[3] locals'],
     ['pvi'], [
    ('var v: i64[] = [2, 0, 1]', None),           # the i64[3] literal converted by dyn
    ('v[v] = 5', None),                           # positions 2 0 1, each 5
    ('pvi(v)', '3: 5 5 5'),
    ('var w: i64[] = [1, 2, 0]', None),
    # indices 1 2 0; read w[1] w[2] w[0] = 2 0 1; plus 10: 12 10 11; stores w[1] = 12, w[2] = 10,
    # w[0] = 11
    ('w[w] += 10', None),
    ('pvi(w)', '3: 11 12 10'),
    ('var f = [2, 0, 1]', None),                  # fixed i64[3]
    ('f[f] = 5', None),
    ('pvi(f)', '3: 5 5 5'),
    ('var g = [1, 2, 0]', None),
    ('g[g] += 10', None),
    ('pvi(g)', '3: 11 12 10'),
])

# g adds 1 to k and returns the new k. LANGUAGE.md 5.5: for `=` the value first, then the indices
# left to right; for op= the indices, the read, then e (the store uses the indices evaluated once).
prog('sel_ref_reads', ['ref calls inside selection stores (LANGUAGE.md 5.5, 8.3; DESIGN.md 3.6.6 rule 12 across',
                       'an L6 block): v[0..g(ref k)] = k stores the old k; B[i, g(ref i)..3] = 0.0 uses the',
                       'old i as the row; A.flat[m] += g(ref m) updates element old m'],
     ['pf', 'pmf'], [
    ('var v = zeros(4)', None),
    ('var k = 2', None),
    ('v[0..g(ref k)] = k', None),                 # value 2 (old k), then g: k = 3, range 0..3
    ('pf(v)', '4: 2 2 2 0'),
    ('printf("%d\\n", k)', '3'),
    ('var B = ones(2, 3)', None),
    ('var i = 0', None),
    ('B[i, g(ref i)..3] = 0.0', None),            # row index i = 0 first, then g: i = 1, cols 1..3
    ('pmf(B)', '2x3 | 1 0 0 | 1 1 1'),
    ('printf("%d\\n", i)', '1'),
    ('var A = zeros(2, 2)', None),
    ('var m = 1', None),
    ('A.flat[m] += g(ref m)', None),              # index 1 (old m); read 0; g gives 2: A.flat[1] = 2
    ('pmf(A)', '2x2 | 0 0 | 2 0'),                # flat 1 is A[1, 0]
    ('printf("%d\\n", m)', '2'),
], fns=r'''fn g(ref k: i64) -> i64 {
    k += 1
    return k
}
''')

prog('sel_mask_scalar', ['a whole-matrix mask store of a scalar (T[T > 100.0] = 100.0; LANGUAGE.md 5.2, 5.5),',
                         'on a dynamic and on a fixed-size matrix'],
     ['pmf'], [
    ('var T: f64[,] = [50.0, 150.0, 99.0; 101.0, 100.0, 300.0]', None),
    ('T[T > 100.0] = 100.0', None),               # 150, 101 and 300 become 100
    ('pmf(T)', '2x3 | 50 100 99 | 100 100 100'),
    ('var F = [120.0, 80.0; 100.5, 100.0]', None),
    ('F[F > 100.0] = 100.0', None),               # 120 and 100.5
    ('pmf(F)', '2x2 | 100 80 | 100 100'),
])

# 5.5: x[sel] op= e reads x before it evaluates e, and a ref argument in e that changes x is seen
# by the store, not by the read; `=` evaluates the value first, then the indices left to right.
prog('sel_order', ['evaluation order of selection stores (LANGUAGE.md 5.5, 6.8 rule 5): x[sel] op= e with a',
                   'ref argument in e that replaces x; the value, range bounds and index-vector elements in order'],
     ['pf', 'pmf'], [
    ('var v: f64[] = [1.0, 2.0, 3.0]', None),
    # indices 0..2; read the old v: 1 2; e: grow makes v 10 20 30 40 and gives 1; 2 3 stored into
    # the new v
    ('v[0..2] += grow(ref v)', None),
    ('pf(v)', '4: 2 3 30 40'),
    ('var A = zeros(3, 3)', None),
    ('A[ix(0)..ix(2), ix(1)] = val(5.0)', 'val 5\nix 0\nix 2\nix 1'),   # value, then lo, hi, col
    ('A[ix(1), ix(0)..ix(3)] += val(1.0)', 'ix 1\nix 0\nix 3\nval 1'),  # indices, read, then e
    ('pmf(A)', '3x3 | 0 5 0 | 1 6 1 | 0 0 0'),   # A[0,1] = A[1,1] = 5; row 1 + 1
    ('var w = zeros(3)', None),
    ('w[[ix(2), ix(0)]] = [val(7.0), val(8.0)]', 'val 7\nval 8\nix 2\nix 0'),   # w[2] = 7, w[0] = 8
    ('pf(w)', '3: 8 0 7'),
], fns=r'''fn grow(ref v: f64[]) -> f64 {
    v = [10.0, 20.0, 30.0, 40.0]
    return 1.0
}
fn ix(k: i64) -> i64 {
    printf("ix %d\n", k)
    return k
}
fn val(x: f64) -> f64 {
    printf("val %g\n", x)
    return x
}
''')

# Views (5.6): .T (i, j) is (j, i); .flat is column-major order; .col is n x 1, .row 1 x n.
prog('sel_views', ['views read (.T, .flat, .col, .row; folded into an index and materialized), nested',
                   'views, .flat written by element, range, mask and compound stores (LANGUAGE.md 5.6, 7.3)'],
     ['pf', 'pmf', 'pmi', 'pvb'], [
    ('let A = [1.0, 2.0, 3.0; 4.0, 5.0, 6.0]', None),   # fixed f64[2,3]
    ('pmf(A.T)', '3x2 | 1 4 | 2 5 | 3 6'),
    ('pf(A.flat)', '6: 1 4 2 5 3 6'),             # column-major
    ('let v = [1.0, 2.0, 3.0]', None),
    ('pmf(v.col)', '3x1 | 1 | 2 | 3'),
    ('pmf(v.row)', '1x3 | 1 2 3'),
    # A.T[2, 1] = A[1, 2] = 6; A.flat[3] = 5; A.T is 1 4; 2 5; 3 6, its flat 1 2 3 4 5 6, [3] = 4;
    # v.row[0, 2] = v[2] = 3; v.col[1, 0] = v[1] = 2
    ('printf("%g %g %g %g %g\\n", A.T[2, 1], A.flat[3], A.T.flat[3], v.row[0, 2], v.col[1, 0])', '6 5 4 3 2'),
    ('pf(A.T[1, :])', '2: 2 5'),                  # row 1 of A.T is column 1 of A
    ('let D = A.T', None),
    ('printf("%d %d %g\\n", rows(D), cols(D), D[0, 1])', '3 2 4'),
    ('var M = zeros(2, 3)', None),
    ('M.flat[0..6] = A.flat', None),              # M = A
    ('pmf(M)', '2x3 | 1 2 3 | 4 5 6'),
    ('M.flat[4] = 9.0', None),                    # linear 4 = (0, 2) of a 2-row matrix
    # flat is now 1 4 2 5 9 6; the elements above 4.5 are at 3 4 5: flat 1 4 2 0 0 0
    ('M.flat[M.flat > 4.5] = 0.0', None),
    ('pmf(M)', '2x3 | 1 2 0 | 4 0 0'),
    ('M.flat[[5, 0]] += [1.0, 2.0]', None),       # flat 5 = M[1,2]: 0 + 1; flat 0 = M[0,0]: 1 + 2
    ('pmf(M)', '2x3 | 3 2 0 | 4 0 1'),
    ('pmf(M.T)', '3x2 | 3 4 | 2 0 | 0 1'),
    ('pf(M.T.flat)', '6: 3 2 0 4 0 1'),           # columns of M.T: 3 2 0 and 4 0 1
    ('pmf(M.T.T)', '2x3 | 3 2 0 | 4 0 1'),
    ('pmf(v.row.T)', '3x1 | 1 | 2 | 3'),
    ('pmf(zeros(4).row)', '1x4 | 0 0 0 0'),
    ('let E = zeros(0, 3)', None),
    ('pmf(E.T)', '3x0 | | |'),
    ('pf(E.flat)', '0:'),
    ('pmi([1, 2; 3, 4].T)', '2x2 | 1 3 | 2 4'),
    ('pvb([true, false; false, false].flat)', '4: 1 0 0 0'),   # (0,0) (1,0) (0,1) (1,1)
    ('pf(zeros(3).col.flat)', '3: 0 0 0'),
    ('M.flat[1..3] = 7.0', None),                 # flat 1 = M[1,0], flat 2 = M[0,1]
    ('pmf(M)', '2x3 | 3 7 0 | 7 0 1'),
])

prog('sel_ref_param', ['selection stores into ref parameters (LANGUAGE.md 8.3, 5.5, 4.5): the caller\'s other',
                       'variable sharing the array is unchanged (copy on write); a compound row store; a mask store'],
     ['pf', 'pmf'], [
    ('var a = ones(4)', None),
    ('let b = a', None),
    ('clear(ref a, 2)', None),                    # a[0..2] = 0.0 through the ref parameter
    ('pf(a)', '4: 0 0 1 1'),
    ('pf(b)', '4: 1 1 1 1'),                      # b shares the old buffer: unchanged (4.5)
    ('var A = zeros(2, 3)', None),
    ('addrow(ref A, 1, [1.0, 2.0, 3.0])', None),
    ('pmf(A)', '2x3 | 0 0 0 | 1 2 3'),
    ('var c: f64[] = [-1.0, 2.0, -3.0]', None),
    ('clip(ref c)', None),
    ('pf(c)', '3: 0 2 0'),
], fns=r'''fn clear(ref v: f64[], k: i64) {
    v[0..k] = 0.0
}
fn addrow(ref A: f64[,], r: i64, x: f64[]) {
    A[r, :] += x
}
fn clip(ref v: f64[]) {
    v[v < 0.0] = 0.0
}
''')

# ============================================================ element-wise operators (6.2-6.5)
prog('ew_arith_f64', ['element-wise f64 arithmetic: + - * / ^ and unary -, scalar with array both ways,',
                      'i64 operands converted, pinned powers and pow, IEEE Inf/NaN/-0 (LANGUAGE.md 6.2, 6.3, 6.5)'],
     ['pf', 'pmf'], [
    ('let a = [1.0, 2.0, 4.0]', None),
    ('let b = [0.5, -1.0, 8.0]', None),
    ('pf(a + b)', '3: 1.5 1 12'),
    ('pf(a - b)', '3: 0.5 3 -4'),
    ('pf(a * b)', '3: 0.5 -2 32'),
    ('pf(a / b)', '3: 2 -2 0.5'),
    ('pf(a ^ 2)', '3: 1 4 16'),                   # x*x (6.5)
    ('pf(a ^ 4)', '3: 1 16 256'),                 # (x*x)*(x*x)
    ('pf(a ^ -1)', '3: 1 0.5 0.25'),              # 1/x
    ('pf(b ^ 3)', '3: 0.125 -1 512'),             # (x*x)*x
    ('pf(b ^ 0)', '3: 1 1 1'),
    ('pf(-a)', '3: -1 -2 -4'),
    ('pf(2.0 * a)', '3: 2 4 8'),
    ('pf(a - 1)', '3: 0 1 3'),                    # the untyped 1 is f64 (4.2 (a))
    ('pf(1.0 / a)', '3: 1 0.5 0.25'),
    ('pf(a ^ 0.5)', '3: 1 1.41421 2'),            # pow; sqrt(2) = 1.41421356... at %g
    ('pf(2.0 ^ a)', '3: 2 4 16'),                 # pow(2, x)
    ('pf(a ^ a)', '3: 1 4 256'),                  # pow(1,1), pow(2,2), pow(4,4)
    ('let n = [1, 2, 3]', None),                  # i64[3]
    ('pf(a + n)', '3: 2 4 7'),                    # the i64 elements converted (4.2 (a))
    ('pf(n / 2)', '3: 0.5 1 1.5'),                # i64 / i64 is f64 (6.5)
    ('pf(n * 0.5)', '3: 0.5 1 1.5'),
    ('let z = zeros(3)', None),
    ('pf(-z)', '3: -0 -0 -0'),                    # unary - flips the sign bit (6.5)
    ('pf(a / z)', '3: Inf Inf Inf'),              # 11.1 spelling
    ('pf(z / z)', '3: NaN NaN NaN'),
    ('pf(a + z)', '3: 1 2 4'),                    # fixed with dynamic
    ('let big = (0..300) * 1.5', None),           # 300 elements 0, 1.5, ..., 448.5
    ('printf("%d %g %g\\n", len(big), big[0], big[299])', '300 0 448.5'),
    ('pmf([1.0, 2.0; 3.0, 4.0] * [2.0, 0.5; -1.0, 0.25])', '2x2 | 2 1 | -3 1'),
])

prog('ew_arith_i64', ['element-wise i64 arithmetic: + - * % unary -, idiv, / gives f64, abs sign min max on',
                      'i64 arrays, range values in arithmetic (LANGUAGE.md 6.3, 6.5, 6.6, 10.4)'],
     ['pf', 'pvi', 'pmi'], [
    ('let a = [7, -7, 3]', None),
    ('let b = [2, 2, -2]', None),
    ('pvi(a + b)', '3: 9 -5 1'),
    ('pvi(a - b)', '3: 5 -9 5'),
    ('pvi(a * b)', '3: 14 -14 -6'),
    # floored modulo a - b * floor(a / b): 7 % 2 = 1; -7 % 2 = -7 + 8 = 1; 3 % -2 = 3 - 4 = -1
    ('pvi(a % b)', '3: 1 1 -1'),
    ('pvi(-a)', '3: -7 7 -3'),
    ('pvi(a % 3)', '3: 1 2 0'),                   # -7 % 3 = -7 + 9 = 2
    ('pvi(idiv(a, b))', '3: 3 -4 -2'),            # floor(3.5), floor(-3.5), floor(-1.5)
    ('pvi(a * 2)', '3: 14 -14 6'),
    ('pvi(abs(a))', '3: 7 7 3'),
    ('pvi(sign(a))', '3: 1 -1 1'),
    ('pvi(min(a, b))', '3: 2 -7 -2'),
    ('pvi(max(a, 0))', '3: 7 0 3'),
    ('let r = (0..5)', None),
    ('pvi(r * r)', '5: 0 1 4 9 16'),
    ('pvi((1..=4) * 10)', '4: 10 20 30 40'),
    ('pf(a / b)', '3: 3.5 -3.5 -1.5'),
    ('let m = [1, 2; 3, 4]', None),
    ('pmi(m * m)', '2x2 | 1 4 | 9 16'),
    ('pmi(m - [1, 1; 1, 1])', '2x2 | 0 1 | 2 3'),
])

prog('ew_cmp_logic', ['element-wise comparisons and logic: NaN and -0 cases, mixed i64/f64, bool ==, !=, & | !',
                      'on bool arrays, matrices, broadcasting (LANGUAGE.md 6.3, 6.4)'],
     ['pvb', 'pmb'], [
    ('let a = [1.0, nan, 3.0, -0.0]', None),
    ('let b = [1.0, 2.0, nan, 0.0]', None),
    ('pvb(a == b)', '4: 1 0 0 1'),                # NaN compares false; -0 == 0
    ('pvb(a != b)', '4: 0 1 1 0'),                # != is true with NaN
    ('pvb(a < b)', '4: 0 0 0 0'),
    ('pvb(a <= b)', '4: 1 0 0 1'),
    ('pvb(a > 2.0)', '4: 0 0 1 0'),
    ('pvb(a >= 1)', '4: 1 0 1 0'),                # the untyped 1 is f64
    ('let n = [1, 5, 3]', None),
    ('pvb(n == 3)', '3: 0 0 1'),
    ('pvb(n < [2.0, 5.0, 2.5])', '3: 1 0 0'),     # 1 < 2, 5 < 5, 3 < 2.5
    ('let p = [true, true, false, false]', None),
    ('let q = [true, false, true, false]', None),
    ('pvb(p & q)', '4: 1 0 0 0'),
    ('pvb(p | q)', '4: 1 1 1 0'),
    ('pvb(!p)', '4: 0 0 1 1'),
    ('pvb(p == q)', '4: 1 0 0 1'),
    ('pvb(p != q)', '4: 0 1 1 0'),
    ('pvb(p & true)', '4: 1 1 0 0'),
    ('pvb(false | q)', '4: 1 0 1 0'),
    ('pvb(isnan(a))', '4: 0 1 0 0'),
    ('let M = [1.0, 2.0; 3.0, 4.0] > 2.5', None),
    ('pmb(M)', '2x2 | 0 0 | 1 1'),
    ('pmb(!M | [true, false; false, false])', '2x2 | 1 1 | 0 0'),   # (!M) | X: ! binds tighter
    ('let g = zeros(3) >= 0.0', None),            # dynamic, all true
    ('pvb(g & [true, false, true])', '3: 1 0 1'),
    ('pmb([1, 2].col < [1.5, 2.5].row)', '2x2 | 1 1 | 0 1'),   # 1<1.5 1<2.5; 2<1.5 2<2.5
])

prog('ew_broadcast', ['broadcasting (LANGUAGE.md 6.3): column with row, matrix with row, column and 1 x 1,',
                      'scalars, extent 0 with extent 1 (0x3 with 1x3 is 0x3), dynamic with fixed'],
     ['pf', 'pmf'], [
    ('let c = [1.0, 2.0, 3.0].col', None),        # 3 x 1
    ('let r = [10.0, 20.0].row', None),           # 1 x 2
    ('pmf(c + r)', '3x2 | 11 21 | 12 22 | 13 23'),  # (i, j) = c[i] + r[j]
    ('pmf(c * r)', '3x2 | 10 20 | 20 40 | 30 60'),
    ('pmf(r - c)', '3x2 | 9 19 | 8 18 | 7 17'),
    ('let A = [1.0, 2.0; 3.0, 4.0; 5.0, 6.0]', None),
    ('pmf(A + r)', '3x2 | 11 22 | 13 24 | 15 26'),
    ('pmf(A * c)', '3x2 | 1 2 | 6 8 | 15 18'),    # row i times c[i]
    ('pmf(A - [1.0].row)', '3x2 | 0 1 | 2 3 | 4 5'),   # a 1 x 1 matrix
    ('pmf(A / 2.0)', '3x2 | 0.5 1 | 1.5 2 | 2.5 3'),
    ('pmf(10.0 - A)', '3x2 | 9 8 | 7 6 | 5 4'),
    ('let E = zeros(0, 3)', None),
    ('let o = ones(1, 3)', None),
    ('pmf(E + o)', '0x3'),                        # rows 0 and 1 give 0 (6.3)
    ('pmf(o + E)', '0x3'),
    ('pmf(zeros(0, 1) + zeros(1, 0))', '0x0'),    # per dimension: 0 with 1, 1 with 0
    ('pmf(zeros(2, 1) + ones(1, 4))', '2x4 | 1 1 1 1 | 1 1 1 1'),
    ('var u = zeros(3)', None),
    ('for i in 0..3 {\n    u[i] = f64(i)\n}', None),
    ('pmf(u.col * u.row)', '3x3 | 0 0 0 | 0 1 2 | 0 2 4'),   # the outer product
    ('pf(u + 1.0)', '3: 1 2 3'),
    ('pmf(ones(1, 1) + A)', '3x2 | 2 3 | 4 5 | 6 7'),
    ('pmf([1, 2].col + [0.5, 0.25].row)', '2x2 | 1.5 1.25 | 2.5 2.25'),   # i64 converted
    ('pmf(zeros(3, 1) + r)', '3x2 | 10 20 | 10 20 | 10 20'),
])

prog('ew_where', ['where on arrays (LANGUAGE.md 10.4, 6.3): array and scalar arms, i64 with f64, bool',
                  'arms, matrix broadcasting, the arguments evaluated in full left to right'],
     ['pf', 'pvi', 'pvb', 'pmf'], [
    ('let v = [1.0, 5.0, 3.0, 7.0]', None),
    ('pf(where(v > 4.0, v, 0.0))', '4: 0 5 0 7'),
    ('pf(where(v > 4.0, 1.0, -1.0))', '4: -1 1 -1 1'),   # scalar arms, the shape of c
    ('pvi(where([true, false, true], 1, [7, 8, 9]))', '3: 1 8 1'),
    ('pf(where([true, false], [1, 2], [0.5, 0.25]))', '2: 1 0.25'),   # i64 with f64 converts
    ('let c = [true, false].col', None),
    ('pmf(where(c, [1.0, 2.0, 3.0].row, 0.0))', '2x3 | 1 2 3 | 0 0 0'),
    ('pmf(where(c, 1.0, [10.0, 20.0].row))', '2x2 | 1 1 | 10 20'),
    ('pvb(where(v > 2.0, v < 6.0, false))', '4: 0 1 1 0'),   # F T T T selects T T T F, else F
    ('pf(where(pc(), pa(), pb()))', 'c\na\nb\n2: 1 4'),      # c a b evaluated in order
], fns=r'''fn pc() -> bool[] {
    printf("c\n")
    return [true, false]
}
fn pa() -> f64[] {
    printf("a\n")
    return [1.0, 2.0]
}
fn pb() -> f64[] {
    printf("b\n")
    return [3.0, 4.0]
}
''')

prog('ew_math', ['the elemental library functions on arrays (LANGUAGE.md 10.4, 6.7, 10.1): abs sign floor ceil',
                 'trunc round isnan sqrt min max log exp sin cos pow hypot, NaN and -0; array and scalar forms',
                 'give identical bits'],
     ['pf', 'pvb'], [
    ('let x = [-1.5, -0.0, 0.5, 2.5, nan]', None),
    ('pf(abs(x))', '5: 1.5 0 0.5 2.5 NaN'),
    ('pf(sign(x))', '5: -1 -0 1 1 NaN'),          # sign(+-0) and NaN are x itself (10.4)
    ('pf(floor(x))', '5: -2 -0 0 2 NaN'),
    ('pf(ceil(x))', '5: -1 -0 1 3 NaN'),
    ('pf(trunc(x))', '5: -1 -0 0 2 NaN'),
    ('pf(round(x))', '5: -2 -0 1 3 NaN'),         # ties away from zero (6.7)
    ('pvb(isnan(x))', '5: 0 0 0 0 1'),
    ('pf(sqrt([4.0, 2.25, 0.0, -0.0]))', '4: 2 1.5 0 -0'),
    ('pf(sqrt([4, 9]))', '2: 2 3'),               # i64 elements converted
    # min: -1.5; min(-0, +0) is the first argument, -0; 0; 0; NaN gives the other, 0
    ('pf(min(x, 0.0))', '5: -1.5 -0 0 0 0'),
    ('pf(max(x, 1.0))', '5: 1 1 1 2.5 1'),
    ('pf(max([1.0, nan], [nan, 2.0]))', '2: 1 2'),
    ('pf(exp(zeros(2)))', '2: 1 1'),
    ('pf(log([1.0, 0.0]))', '2: 0 -Inf'),
    ('pf(sin([0.0, -0.0]))', '2: 0 -0'),
    ('pf(cos(zeros(2)))', '2: 1 1'),
    ('pf(pow([2.0, 3.0], [10.0, 2.0]))', '2: 1024 9'),
    ('pf(hypot([3.0, 5.0], [4.0, 12.0]))', '2: 5 13'),
    ('let s = sin([0.5, 1.0, 2.0])', None),
    ('let l = log([0.5, 3.0])', None),
    ('let e = exp([0.5, -3.0])', None),
    ('let c = cos([0.5, 3.0])', None),
    ('let p = pow([1.5, 2.5], 0.3)', None),
    ('let h = hypot([1.5, 2.0], 2.5)', None),
    ('printf("%d %d %d\\n", s[0] == sin(0.5), s[1] == sin(1.0), s[2] == sin(2.0))', '1 1 1'),
    ('printf("%d %d %d %d\\n", l[0] == log(0.5), l[1] == log(3.0), e[0] == exp(0.5), e[1] == exp(-3.0))',
     '1 1 1 1'),
    ('printf("%d %d %d %d\\n", c[0] == cos(0.5), c[1] == cos(3.0), p[0] == pow(1.5, 0.3), p[1] == pow(2.5, 0.3))',
     '1 1 1 1'),
    ('printf("%d %d\\n", h[0] == hypot(1.5, 2.5), h[1] == hypot(2.0, 2.5))', '1 1'),
])

prog('ew_cvt', ['array conversions f64(a), i64(a) of i64, f64 and bool arrays, the identities, implicit',
                'i64[] -> f64[] conversion of arguments and bindings (LANGUAGE.md 4.2, 10.1)'],
     ['pf', 'pvi', 'pmf'], [
    ('let n = [1, -2, 3]', None),
    ('pf(f64(n))', '3: 1 -2 3'),
    ('let x = [2.0, -0.0, 1e15]', None),
    ('pvi(i64(x))', '3: 2 0 1000000000000000'),   # integral values; -0.0 is the integer 0
    ('let b = [true, false, true]', None),
    ('pf(f64(b))', '3: 1 0 1'),
    ('pvi(i64(b))', '3: 1 0 1'),
    ('pvi(i64(n))', '3: 1 -2 3'),                 # i64 of i64: unchanged
    ('pf(f64(x))', '3: 2 -0 1e+15'),              # f64 of f64: unchanged
    ('printf("%g\\n", tot(n))', '2'),             # i64[3] converted for the f64[] parameter: 1-2+3
    ('pmf(f64([1, 2; 3, 4]))', '2x2 | 1 2 | 3 4'),
    ('let d: f64[] = (0..3)', None),              # an i64[] converted for an f64[] binding
    ('pf(d)', '3: 0 1 2'),
    ('let m: f64[,] = [1, 2; 3, 4]', None),       # untyped elements in an f64 context
    ('pmf(m)', '2x2 | 1 2 | 3 4'),
    ('pvi(i64(zeros(0)))', '0:'),
], fns=r'''fn tot(v: f64[]) -> f64 {
    var s = 0.0
    for e in v {
        s += e
    }
    return s
}
''')

# ind2sub(r, k) = (k % r, idiv(k, r)) floored; sub2ind(r, i, j) = i + j * r (10.7), elemental.
prog('ew_index_util', ['ind2sub with a scalar r and a vector k, sub2ind on vectors with broadcasting, their round',
                       'trip, an empty k, a tuple assignment to array variables (LANGUAGE.md 10.7, 6.6; Decision 33)'],
     ['pvi'], [
    ('let k = [0, 4, 7, -1, 8]', None),
    ('let (i, j) = ind2sub(3, k)', None),
    ('pvi(i)', '5: 0 1 1 2 2'),                   # -1 % 3 = 2, 8 % 3 = 2
    ('pvi(j)', '5: 0 1 2 -1 2'),                  # idiv(-1, 3) = -1
    ('pvi(sub2ind(3, i, j))', '5: 0 4 7 -1 8'),   # 2 + 3 * (-1) = -1
    ('pvi(sub2ind(4, [0, 3], 2))', '2: 8 11'),
    ('let (ei, ej) = ind2sub(3, (0..0))', None),
    ('printf("%d %d\\n", len(ei), len(ej))', '0 0'),
    ('let kd: i64[] = k', None),
    ('var i2 = filled(0, 0)', None),
    ('var j2 = filled(0, 0)', None),
    ('(i2, j2) = ind2sub(2, kd)', None),
    ('pvi(i2)', '5: 0 0 1 1 0'),                  # -1 % 2 = 1
    ('pvi(j2)', '5: 0 2 3 -1 4'),
    ('let (si, sj) = ind2sub(3, 5)', None),
    ('printf("%d %d\\n", si, sj)', '2 1'),
])

# ============================================================ literals, ranges, fixed arrays
LIT256 = int_literal(256)
LIT257 = int_literal(257)
prog('arr_literals', ['array literals (LANGUAGE.md 6.9, 4.5): fixed vectors and matrices of each scalar kind,',
                      'untyped elements, trailing separators and newlines, 256 (fixed) and 257 (dynamic)',
                      'elements, vector and matrix concatenation, [] under each context that types it'],
     ['pf', 'pvi', 'pvb', 'pmf', 'pmi'], [
    ('let a = [0.135, 2.5, 50, 97.5, 99.865]', None),    # f64[5]; the untyped 50 is f64
    ('pf(a)', '5: 0.135 2.5 50 97.5 99.865'),
    ('let i = 3', None),
    ('let idx = [2 * i, 2 * i + 1, 2 * 0, 1]', None),    # i64[4]
    ('pvi(idx)', '4: 6 7 0 1'),
    ('let b = [true, false, ]', None),
    ('pvb(b)', '2: 1 0'),
    ('let m = [1, 2, 3;\n    4, 5, 6;]', None),          # newline inside, trailing ;: i64[2,3]
    ('pmi(m)', '2x3 | 1 2 3 | 4 5 6'),
    ('let mf = [1, 2.5; -3, 4]', None),                  # common type f64
    ('pmf(mf)', '2x2 | 1 2.5 | -3 4'),
    ('let col = [1.0; 2.0; 3.0]', None),                 # f64[3,1]
    ('pmf(col)', '3x1 | 1 | 2 | 3'),
    ('printf("%d %d %d %d\\n", len(a), rows(m), cols(m), numel(col))', '5 2 3 3'),
    ('let f256 = ' + LIT256, None),                      # 256 scalars: fixed i64[256]
    ('let g: i64[256] = f256', None),
    ('printf("%d %d\\n", len(g), g[255])', '256 255'),
    ('let d257 = ' + LIT257, None),                      # 257 scalars: dynamic i64[]
    ('printf("%d %d\\n", len(d257), d257[256])', '257 256'),
    ('let v = [1.0, 2.0]', None),
    ('var w = zeros(3)', None),
    ('pf([v, 3.0])', '3: 1 2 3'),                        # scalars and vectors join into a vector
    ('pf([0.0, v, w])', '6: 0 1 2 0 0 0'),
    ('pf([1, v])', '3: 1 1 2'),                          # the untyped 1 is f64 (4.2 (c))
    ('pf([(0..2), 0.5])', '3: 0 1 0.5'),                 # an i64[] part converted
    ('pvi([(0..3), 10, (5..7)])', '6: 0 1 2 10 5 6'),
    ('let A = [1.0, 2.0; 3.0, 4.0]', None),
    ('let B = [5.0; 6.0]', None),                        # 2 x 1
    ('pmf([A, B])', '2x3 | 1 2 5 | 3 4 6'),
    ('pmf([A; [7.0, 8.0]])', '3x2 | 1 2 | 3 4 | 7 8'),   # a vector row counts as 1 x n
    ('pmf([v; v])', '2x2 | 1 2 | 1 2'),
    ('pmf([A, B; v.row, 9.0])', '3x3 | 1 2 5 | 3 4 6 | 1 2 9'),   # a scalar is 1 x 1 in a matrix row
    ('pmf([zeros(2, 1), A])', '2x3 | 0 1 2 | 0 3 4'),
    ('pmf([A; ones(1, 2)])', '3x2 | 1 2 | 3 4 | 1 1'),
    ('pf([zeros(0), v])', '2: 1 2'),
    ('pmf([zeros(0, 2); A])', '2x2 | 1 2 | 3 4'),
    ('pvb([b, true])', '3: 1 0 1'),
    ('pf([v])', '2: 1 2'),
    ('let e: f64[] = []', None),                         # [] typed by the declared type (6.9)
    ('pf(e)', '0:'),
    ('let em: f64[,] = []', None),                       # under a matrix type: 0 x 0
    ('pmf(em)', '0x0'),
    ('let e0: f64[0] = []', None),                       # a fixed type without elements
    ('printf("%d\\n", len(e0))', '0'),
    ('let e03: i64[0,3] = []', None),
    ('printf("%d %d\\n", rows(e03), cols(e03))', '0 3'),
    ('var x: f64[] = [1.0]', None),
    ('x = []', None),                                    # typed by the assignment target
    ('pf(x)', '0:'),
    ('var y = ones(3)', None),
    ('y[1..1] = []', None),                              # typed by the selection: f64[], length 0
    ('pf(y)', '3: 1 1 1'),
    ('printf("%d\\n", cnt([]))', '0'),                   # typed by a user function's parameter
    ('printf("%d\\n", len(none()))', '0'),               # typed by the return's result type
    ('let c = len(y) > 5', None),
    ('pf(if c { w } else { [] })', '0:'),                # typed by the other arm (f64[])
], fns=r'''fn cnt(v: i64[]) -> i64 {
    return len(v)
}
fn none() -> bool[] {
    return []
}
''')

# A range value (5.1, 6.1 item 11) is the i64[] of its positions; length max(0, ceil((b - a) / s))
# computed exactly in integers.
prog('arr_ranges', ['range values (LANGUAGE.md 5.1, 6.1): steps, negative steps, empty ranges, exact lengths',
                    'at the i64 limits, arithmetic on them, for over (range) and over an expression of one'],
     ['pf', 'pvi'], [
    ('pvi((0..5))', '5: 0 1 2 3 4'),
    ('let r = (2..=6 step 2)', None),
    ('pvi(r)', '3: 2 4 6'),
    ('pvi((5..0 step -2))', '3: 5 3 1'),
    ('pvi((9..=0 step -3))', '4: 9 6 3 0'),
    ('pvi((3..3))', '0:'),
    ('pvi((4..1))', '0:'),
    ('pvi((0..7 step 3))', '3: 0 3 6'),           # ceil(7 / 3) = 3
    ('pvi((0..-3 step -1))', '3: 0 -1 -2'),
    ('pf((0..=4) * 0.5)', '5: 0 0.5 1 1.5 2'),
    ('pvi((9223372036854775806..=9223372036854775807))', '2: 9223372036854775806 9223372036854775807'),
    ('pvi((-9223372036854775808..-9223372036854775806))', '2: -9223372036854775808 -9223372036854775807'),
    # ceil((2^63 - 1) / 2^62) = 2 positions: 0 and 2^62
    ('pvi((0..9223372036854775807 step 4611686018427387904))', '2: 0 4611686018427387904'),
    ('for x in (0..3) {\n    printf("%d ", x)\n}\nprintf("\\n")', '0 1 2 '),
    ('for x in (10..0 step -4) {\n    printf("%d ", x)\n}\nprintf("\\n")', '10 6 2 '),
    ('var s = 0', None),
    ('let n = 4', None),
    ('for x in (0..n) * 2 {\n    s += x\n}', None),  # 0 2 4 6
    ('printf("%d\\n", s)', '12'),
    ('var t = 0', None),
    ('for x in (5..5) {\n    t += 1\n}', None),
    ('printf("%d\\n", t)', '0'),
])

prog('arr_fixed_vals', ['fixed-size arrays (LANGUAGE.md 4.5; Decision 32): locals, value semantics, parameters,',
                        'results, tuple components, ref parameters, matrices, for, $, len rows cols numel'],
     ['pf', 'pvi', 'pvb', 'pmf'], [
    ('let a: f64[3] = [1.0, 2.0, 3.0]', None),
    ('printf("%g\\n", sum3(a))', '6'),
    ('var b = a', None),
    ('b[0] = 9.0', None),
    ('printf("%g %g\\n", a[0], b[0])', '1 9'),           # a value: a is unchanged
    ('let s = scale2([1.5, 2.0], 2.0)', None),
    ('printf("%g %g %d\\n", s[0], s[1], len(s))', '3 4 2'),
    ('let (lo, hi) = split([1, 2, 3, 4])', None),
    ('printf("%d %d %d %d\\n", lo[0], lo[1], hi[0], hi[1])', '1 2 3 4'),
    ('var p = [0, 0]', None),
    ('var q = [0, 0]', None),
    ('(p, q) = split([5, 6, 7, 8])', None),
    ('printf("%d %d %d %d\\n", p[0], p[1], q[0], q[1])', '5 6 7 8'),
    ('let (_, h2) = split([1, 1, 2, 9])', None),
    ('printf("%d\\n", h2[1])', '9'),
    ('var c = [1.0, 2.0, 3.0]', None),
    ('bump(ref c)', None),                               # 2 2 3, then doubled
    ('pf(c)', '3: 4 4 6'),
    ('var M = eye2()', None),
    ('M[0, 1] = 5.0', None),
    ('pmf(M)', '2x2 | 1 5 | 0 1'),
    ('printf("%d %d %d %g\\n", rows(M), cols(M), numel(M), mid(M))', '2 2 4 5'),   # 5 + 0
    ('var t = 0.0', None),
    ('for x in a {\n    t += x\n}', None),
    ('printf("%g %g\\n", t, a[$ - 1])', '6 3'),
    ('var f: i64[3] = [0, 0, 0]', None),
    ('for i in 0..3 {\n    f[i] = i * i\n}', None),
    ('pvi(f)', '3: 0 1 4'),
    ('var g = [true, false]', None),
    ('g[1] = true', None),
    ('pvb(g)', '2: 1 1'),
    ('let fm: f64[2,3] = [1, 2, 3; 4, 5, 6]', None),
    ('printf("%g\\n", fm[1, 2])', '6'),
    ('var e = [1.0, 2.0]', None),
    ('let e2 = e', None),
    ('e[0] = 0.0', None),
    ('printf("%g %g\\n", e[0], e2[0])', '0 1'),
], fns=r'''fn sum3(v: f64[3]) -> f64 {
    return v[0] + v[1] + v[2]
}
fn scale2(v: f64[2], k: f64) -> f64[2] {
    return v * k
}
fn split(v: i64[4]) -> (i64[2], i64[2]) {
    return ([v[0], v[1]], [v[2], v[3]])
}
fn bump(ref v: f64[3]) {
    v[0] += 1.0
    v = v * 2.0
}
fn eye2() -> f64[2,2] {
    return [1.0, 0.0; 0.0, 1.0]
}
fn mid(M: f64[2,2]) -> f64 {
    return M[0, 1] + M[1, 0]
}
''')

# Implicit dyn and fix (LANGUAGE.md 4.5; DESIGN.md 3.5.5): a fixed-size array converts to the
# dynamic type of its rank; a dynamic one to a fixed-size type after the run-time shape check.
prog('arr_fixdyn_conv', ['implicit dyn and fix (LANGUAGE.md 4.5; DESIGN.md 3.5.5): bindings, assignments,',
                         'arguments, returns, if expressions with fixed and dynamic arms, matrices'],
     ['pf', 'pmf'], [
    ('var d: f64[] = [1.0, 2.0]', None),                 # dyn at a binding
    ('printf("%d %g\\n", len(d), total(d))', '2 3'),
    ('d = [5.0, 6.0, 7.0]', None),                       # dyn at an assignment: the shape changes
    ('printf("%d %g\\n", len(d), total([1.0, 2.0, 3.0]))', '3 6'),   # dyn at an argument
    ('let f: f64[3] = d', None),                         # fix at a binding (3 = 3)
    ('printf("%g\\n", first3(f))', '567'),               # 5 * 100 + 6 * 10 + 7
    ('printf("%g\\n", first3(zeros(3) + 1.0))', '111'),  # fix at an argument
    ('pf(mkdyn())', '4: 1 2 3 4'),                       # dyn at a return
    ('let g = mkfix()', None),                           # fix at a return
    ('printf("%g %g\\n", g[0], g[1])', '1 1'),
    ('var e = [1.0, 2.0]', None),
    ('e = d[0..2]', None),                               # fix at an assignment from a selection
    ('pf(e)', '2: 5 6'),
    ('let c = len(d) > 2', None),                        # true
    ('let h = if c { [1.0, 2.0] } else { [3.0, 4.0, 5.0] }', None),   # shapes differ: dynamic
    ('printf("%d\\n", len(h))', '2'),
    ('let k = if c { d } else { [0.0] }', None),         # a dynamic arm: dynamic
    ('printf("%d\\n", len(k))', '3'),
    ('let q = if c { [1.0, 2.0] } else { [3.0, 4.0] }', None),   # one fixed shape
    ('pf(q)', '2: 1 2'),
    ('var m: f64[,] = [1.0, 2.0; 3.0, 4.0]', None),
    ('m = zeros(1, 3)', None),
    ('pmf(m)', '1x3 | 0 0 0'),
    ('let fm: f64[1,3] = m', None),
    ('pmf(fm)', '1x3 | 0 0 0'),
], fns=r'''fn total(v: f64[]) -> f64 {
    var s = 0.0
    for x in v {
        s += x
    }
    return s
}
fn first3(v: f64[3]) -> f64 {
    return v[0] * 100.0 + v[1] * 10.0 + v[2]
}
fn mkdyn() -> f64[] {
    return [1.0, 2.0, 3.0, 4.0]
}
fn mkfix() -> f64[2] {
    return ones(2)
}
''')

# ============================================================ heap (DESIGN.md 3.6.6 rules 15, 16, 20-22)
# Each would leave a live object under a missing release (the runner's heap check, DESIGN.md 6.2).
MKFNS = r'''fn mk(n: i64) -> f64[] {
    var v = zeros(n)
    for i in 0..n {
        v[i] = f64(i)
    }
    return v
}
fn mki(n: i64) -> i64[] {
    return (0..n) * 2
}
fn mkm() -> f64[,] {
    return [1.0, 2.0; 3.0, 4.0]
}
'''
# mk(n) = 0 1 ... n-1; mki(n) = 0 2 ... 2(n-1); mkm() = 1 2; 3 4 (dynamic)
prog('heap_sel_temps', ['selections of temporaries: a call result sliced, masked and indexed by temporary index',
                        'vectors, nested selections, views of temporaries, a selection held per iteration and',
                        'one discarded (DESIGN.md 3.6.6 rules 15, 20, 28)'],
     ['pf', 'pmf'], [
    ('pf(mk(5)[1..3])', '2: 1 2'),
    ('pf(mk(5)[mki(2)])', '2: 0 2'),              # index vector 0 2
    ('pf(mk(4)[mk(4) > 1.5])', '2: 2 3'),
    ('pf(mk(6)[1..5][[0, 3]])', '2: 1 4'),        # 1 2 3 4, then positions 0 3
    ('printf("%g\\n", mk(3)[1..3][1])', '2'),     # 1 2, then element 1
    ('pf(mkm()[:, 1])', '2: 2 4'),
    ('pmf(mkm().T)', '2x2 | 1 3 | 2 4'),
    ('printf("%g\\n", mkm().flat[2])', '2'),      # flat 1 3 2 4
    ('var acc = 0.0', None),
    ('for i in 0..3 {\n    let s = mk(4)[i..4]\n    acc += s[0]\n}', None),   # s[0] = i
    ('printf("%g\\n", acc)', '3'),
    ('let _ = mk(3)[0..2]', None),
    ('printf("%d\\n", len(mk(7)[mki(3)]))', '3'),
], fns=MKFNS)

prog('heap_sel_store', ['selection stores with temporary values, index vectors and masks, copy on write of a',
                        'shared target, a compound store in a loop, matrix stores of views of temporaries',
                        '(DESIGN.md 3.6.6 rules 15, 19, 21)'],
     ['pf', 'pmf'], [
    ('var v = zeros(6)', None),
    ('v[mki(3)] = mk(3)', None),                  # positions 0 2 4 get 0 1 2
    ('pf(v)', '6: 0 0 1 0 2 0'),
    ('v[mk(6) > 3.5] = 9.0', None),               # positions 4 5
    ('pf(v)', '6: 0 0 1 0 9 9'),
    ('v[1..3] += mk(2)', None),                   # 0 + 0, 1 + 1
    ('pf(v)', '6: 0 0 2 0 9 9'),
    ('var w = v', None),
    ('w[mki(2)] = 5.0', None),                    # w copies on write; v unchanged
    ('pf(w)', '6: 5 0 5 0 9 9'),
    ('pf(v)', '6: 0 0 2 0 9 9'),
    ('for k in 0..3 {\n    v[mki(1)] += 1.0\n}', None),   # v[0] += 1 three times
    ('pf(v)', '6: 3 0 2 0 9 9'),
    ('var A = zeros(2, 2)', None),
    ('A[mki(1), :] = mk(2).row', None),           # row 0 = 0 1
    ('A[:, mki(1)] += mk(2).col', None),          # column 0 += 0; 1
    ('pmf(A)', '2x2 | 0 1 | 1 0'),
    ('var x: f64[] = [1.0, 2.0, 3.0]', None),
    ('x[x > 1.5] = mk(2)', None),                 # positions 1 2 get 0 1
    ('pf(x)', '3: 1 0 1'),
], fns=MKFNS)

prog('heap_ew_temps', ['element-wise operations, broadcasting, conversions, concatenations, where and ind2sub',
                       'on temporaries; reassignment and whole-array compound assignment in a loop',
                       '(DESIGN.md 3.6.6 rules 15, 22, 26)'],
     ['pf', 'pvi', 'pvb', 'pmf'], [
    ('pf(mk(3) + mk(3) * 2.0)', '3: 0 3 6'),
    ('pmf(mk(2).col * mk(3).row)', '2x3 | 0 0 0 | 0 1 2'),
    ('pf(f64(mki(3)) + 0.5)', '3: 0.5 2.5 4.5'),
    ('pf([mk(2), mk(3)])', '5: 0 1 0 1 2'),
    ('pmf([mkm(), mkm()])', '2x4 | 1 2 1 2 | 3 4 3 4'),
    ('pvb(mk(3) > 1.0 | mk(3) < 0.5)', '3: 1 0 1'),   # F F T | T F F
    ('pf(where(mk(3) > 0.5, mk(3), -1.0))', '3: -1 1 2'),
    ('pf(sqrt(mk(3) * mk(3)))', '3: 0 1 2'),
    ('var s = mk(2)', None),
    ('for i in 0..3 {\n    s = s + mk(2)\n}', None),      # 0 1 plus three times 0 1
    ('pf(s)', '2: 0 4'),
    ('var t = mk(3)', None),
    ('t += mk(3)', None),                         # 0 2 4
    ('t *= 2.0', None),                           # 0 4 8
    ('pf(t)', '3: 0 4 8'),
    ('let d: f64[] = [1.0, 2.0] + mk(2)', None),  # fixed with dynamic: 1 3
    ('pf(d)', '2: 1 3'),
    ('let (i, j) = ind2sub(2, mki(3))', None),    # k = 0 2 4
    ('pvi(i)', '3: 0 0 0'),
    ('pvi(j)', '3: 0 1 2'),
], fns=MKFNS)

prog('heap_early_exit', ['early exits while array temporaries are held: return from an element loop over a',
                         'selection, break and continue in a loop over a range value expression, returns of',
                         'selections and of element-wise results, break out of a while (DESIGN.md 3.6.6 rule 16)'],
     ['pf'], [
    # firstbig(0 1 2 3 4, 2.5): the selection 3 4, return 3; firstbig(0 1 2, 5.0): empty, -1
    ('printf("%g %g\\n", firstbig(mk(5), 2.5), firstbig(mk(3), 5.0))', '3 -1'),
    # (0..5) * 2 = 0 2 4 6 8: without a stop 0 + 4 + 6 + 8 = 18 (2 skipped); stop at 6: 0 + 4
    ('printf("%d %d\\n", sumto(5, 100), sumto(5, 6))', '18 4'),
    ('pf(pick(true))', '2: 2 4'),                 # a = 0 2 4; a[1..3]
    ('pf(pick(false))', '2: 9 10'),               # 9 8 + 0 2
    ('var n = 0', None),
    ('while true {\n    let w = mk(4)[1..4] + 1.0\n    n += 1\n    if n == 2 {\n        break\n    }\n}', None),
    ('printf("%d\\n", n)', '2'),
], fns=MKFNS + r'''fn firstbig(v: f64[], lim: f64) -> f64 {
    for x in v[v > lim] {
        return x
    }
    return -1.0
}
fn sumto(n: i64, stop: i64) -> i64 {
    var s = 0
    for x in (0..n) * 2 {
        if x == stop {
            break
        }
        if x == 2 {
            continue
        }
        s += x
    }
    return s
}
fn pick(c: bool) -> f64[] {
    let a = mk(3) * 2.0
    let b = [9.0, 8.0]
    if c {
        return a[1..3]
    }
    return b + a[0..2]
}
''')

prog('heap_fixed', ['fixed-size arrays made from and turned into dynamic ones (fix at a return from a',
                    'selection, dyn at a return and a binding, if expressions with a dynamic arm; DESIGN.md',
                    '3.6.6 rule 27 (i), (j), (k))'],
     ['pf'], [
    ('var f = tofix(mk(4))', None),               # 0 1
    ('pf(todyn(f))', '2: 0 1'),
    ('var d = todyn([5.0, 6.0])', None),
    ('d = d * 2.0', None),
    ('pf(d)', '2: 10 12'),
    ('let c = len(d) > 1', None),                 # true
    ('let e = if c { d } else { [1.0, 2.0] }', None),
    ('pf(e)', '2: 10 12'),
    ('let g: f64[2] = if c { [3.0, 4.0] } else { d[0..2] }', None),   # a dynamic if, then fix
    ('pf(g)', '2: 3 4'),
], fns=MKFNS + r'''fn tofix(v: f64[]) -> f64[2] {
    return v[0..2]
}
fn todyn(v: f64[2]) -> f64[] {
    return v
}
''')


# ============================================================ programs/w4_sor_arrays (DESIGN.md 6.2)
def w4_sor_arrays():
    """tests/accept/w4_sor.sea with its set-up written as whole-array code (DESIGN.md 6.2 "4e"); the
    rest of the program is copied unchanged. Every set-up element is the same IEEE operations in
    the same order as the scalar loops (LANGUAGE.md 6.8): (0..nx) * h is f64(i) * h; the squares
    are powk 2 (one multiplication); Tbot0 + (Tbot1 - Tbot0) * x / W parses as
    Tbot0 + ((Tbot1 - Tbot0) * x[i]) / W; x.row (1 x nx) with y.col (ny x 1) broadcasts to element
    (j, i) (6.3); & gives the values of &&; fixed = hole, then rows 0 and ny - 1 true, is
    hole[j, i] || j == 0 || j == ny - 1; T's rows 0 and ny - 1 are set before the hole as in the
    scalar loops. So the solver starts from bit-identical arrays and prints 4d's W4 line: the
    reference output it_sor 832, T_max 160.76267159277148 (tests/CORPUS.md, accept/w4_sor: the IEEE
    mirror of the scalar port and workloads/reference/w4_heat_plate.json, whose values are these)."""
    src = open(os.path.join(ACCEPT, 'w4_sor.sea')).read()
    head_end = src.index('// inputs\n')
    a = src.index('var x = zeros(nx)\n')
    b = src.index('// relaxation factor')
    old_setup = src[a:b]
    # the replaced region is exactly the scalar set-up of 4d (asserted, so a change of w4_sor.sea
    # cannot silently change what this test compares)
    for needle in ('x[i] = f64(i) * h', 'y[j] = f64(j) * h', 'let holeR2 = holeR ^ 2',
                   'let srcVal = h ^ 2 * qSrc / kCond',
                   'hole[j, i] = (x[i] - holeCx) ^ 2 + (y[j] - holeCy) ^ 2 <= holeR2',
                   'if x[i] >= srcX0 && x[i] <= srcX1 && y[j] >= srcY0 && y[j] <= srcY1 {',
                   'fixed[j, i] = hole[j, i] || j == 0 || j == ny - 1',
                   'var T = filled(Ttop, ny, nx)', 'T[0, i] = Tbot0 + (Tbot1 - Tbot0) * x[i] / W',
                   'T[ny - 1, i] = Ttop', 'T[j, i] = Thole'):
        assert needle in old_setup, needle
    header = '''// w4_sor_arrays -- tests/accept/w4_sor.sea (W4's scalar SOR, DESIGN.md 6.3) with its set-up
// written as whole-array code (DESIGN.md 6.2 "4e"): range values, .row/.col broadcasting,
// element-wise comparisons and &, a mask store of a scalar, row stores and copy on write
// (`fixed` starts as `hole`'s buffer). Every element of the set-up is computed by the same IEEE
// operations in the same order as in the scalar loops (LANGUAGE.md 6.8), so the solver starts from
// bit-identical arrays and the program prints the same line as 4d's W4 program.

'''
    setup = '''let x = (0..nx) * h
let y = (0..ny) * h

// the coolant channel, the heat source term and the Dirichlet nodes
let holeR2 = holeR ^ 2
let srcVal = h ^ 2 * qSrc / kCond
let hole = (x.row - holeCx) ^ 2 + (y.col - holeCy) ^ 2 <= holeR2
let inSrc = x.row >= srcX0 & x.row <= srcX1 & y.col >= srcY0 & y.col <= srcY1
var src = zeros(ny, nx)
src[inSrc] = srcVal
var fixed = hole
fixed[0, :] = true
fixed[ny - 1, :] = true

// the initial temperatures
var T = filled(Ttop, ny, nx)
T[0, :] = Tbot0 + (Tbot1 - Tbot0) * x / W
T[ny - 1, :] = Ttop
T[hole] = Thole

'''
    text = header + src[head_end:a] + setup + src[b:]
    write(os.path.join(PROGRAMS, 'w4_sor_arrays.sea'), text)
    write(os.path.join(PROGRAMS, 'w4_sor_arrays.out'), '{"it_sor": 832, "T_max": 160.76267159277148}\n')
    COUNT['programs'] += 1


w4_sor_arrays()

# ============================================================ errors: selection bounds and order (5.4, 5.5)
IOOB = 'index %d out of bounds for dimension %d of extent %d'
SM = 'shape mismatch: %s vs %s'
SE = 'shape mismatch: expected %s, got %s'
V5 = 'var v = zeros(5)\n'

# 5.4: for a non-empty range, its first position if out of range, else its last a + (n - 1) s
err_rt('err_rt_sel_range_last', ['v[2..10] on a 5-element vector reports the last position 9 (LANGUAGE.md 5.4)'],
       V5 + 'let w = v[2..10]\nprintf("%d\\n", len(w))\n', 'let w', IOOB % (9, 0, 5))
err_rt('err_rt_sel_range_first', ['v[7..9] reports its first position 7 (LANGUAGE.md 5.4)'],
       V5 + 'let w = v[7..9]\nprintf("%d\\n", len(w))\n', 'let w', IOOB % (7, 0, 5))
err_rt('err_rt_sel_range_step', ['v[1..=5 step 2]: positions 1 3 5, the last is out of range (LANGUAGE.md 5.4)'],
       V5 + 'let w = v[1..=5 step 2]\nprintf("%d\\n", len(w))\n', 'let w', IOOB % (5, 0, 5))
err_rt('err_rt_sel_range_negstep', ['v[4..=-2 step -3]: positions 4 1 -2, the last -2 (LANGUAGE.md 5.1, 5.4)'],
       V5 + 'let w = v[4..=-2 step -3]\nprintf("%d\\n", len(w))\n', 'let w', IOOB % (-2, 0, 5))
err_rt('err_rt_sel_dollar', ['v[$ - 2..$ + 1] is 3..6: the last position 5 (LANGUAGE.md 5.3, 5.4)'],
       V5 + 'let w = v[$ - 2..$ + 1]\nprintf("%d\\n", len(w))\n', 'let w', IOOB % (5, 0, 5))
err_rt('err_rt_sel_ivec', ['an index vector reports its first element out of range, in order: 7 (LANGUAGE.md 5.4)'],
       V5 + 'let w = v[[0, 7, -1]]\nprintf("%d\\n", len(w))\n', 'let w', IOOB % (7, 0, 5))
err_rt('err_rt_sel_ivec_dyn', ['a dynamic index vector 3 4 5 6 7: the first bad element 5 (LANGUAGE.md 5.4)'],
       V5 + 'let k = (3..8)\nlet w = v[k]\nprintf("%d\\n", len(w))\n', 'let w', IOOB % (5, 0, 5))
err_rt('err_rt_sel_mat_col', ['A[0..2, 1..5] on a 2 x 3 matrix: dimension 1, last position 4 (LANGUAGE.md 5.4)'],
       'let A = zeros(2, 3)\nlet B = A[0..2, 1..5]\nprintf("%d\\n", rows(B))\n', 'let B', IOOB % (4, 1, 3))
err_rt('err_rt_sel_mat_order', ['A[0..5, 0..9]: dimension 0 is checked before dimension 1 (LANGUAGE.md 5.4)'],
       'let A = zeros(2, 3)\nlet B = A[0..5, 0..9]\nprintf("%d\\n", rows(B))\n', 'let B', IOOB % (4, 0, 2))
err_rt('err_rt_sel_check_order_mask', ['A[m, 9] with a mask of the wrong extent: the mask is dimension 0\'s check,',
                                       'made before dimension 1 (LANGUAGE.md 5.2, 5.4): 3 vs 2'],
       'let A = zeros(3, 4)\nlet m = filled(true, 2)\nlet c = A[m, 9]\nprintf("%d\\n", len(c))\n',
       'let c', SM % ('3', '2'))
err_rt('err_rt_sel_check_order_idx', ['A[9, m]: the scalar index of dimension 0 is checked before the mask',
                                      '(LANGUAGE.md 5.4)'],
       'let A = zeros(3, 4)\nlet m = filled(true, 2)\nlet c = A[9, m]\nprintf("%d\\n", len(c))\n',
       'let c', IOOB % (9, 0, 3))
err_rt('err_rt_sel_mask_vec', ['v[m] with a 5-element v and a 4-element m: shape mismatch: 5 vs 4 (LANGUAGE.md 5.2)'],
       V5 + 'let m = filled(true, 4)\nlet w = v[m]\nprintf("%d\\n", len(w))\n', 'let w', SM % ('5', '4'))
err_rt('err_rt_sel_mask_mat', ['A[M] with A 3 x 4 and M 4 x 3: shape mismatch: 3x4 vs 4x3 (LANGUAGE.md 5.2)'],
       'let A = zeros(3, 4)\nlet M = filled(true, 4, 3)\nlet w = A[M]\nprintf("%d\\n", len(w))\n',
       'let w', SM % ('3x4', '4x3'))
err_rt('err_rt_sel_mask_dim', ['A[m, :]: the dimension\'s extent as a vector shape, then len(m) (LANGUAGE.md 5.2)'],
       'let A = zeros(3, 4)\nlet m = filled(false, 2)\nlet B = A[m, :]\nprintf("%d\\n", rows(B))\n',
       'let B', SM % ('3', '2'))
err_rt('err_rt_sel_store_idx_first', ['v[0..9] = val(): the value is evaluated first, then the index check fails',
                                      'before the shape check (LANGUAGE.md 5.5): index 8'],
       'fn val() -> f64[] {\n    printf("val\\n")\n    return [1.0, 2.0]\n}\n' + V5 + 'v[0..9] = val()\n',
       'v[0..9] = val()', IOOB % (8, 0, 5), 'val\n')
err_rt('err_rt_sel_store_shape', ['v[0..3] = [1.0, 2.0]: shape mismatch: 3 vs 2, the selection first',
                                  '(LANGUAGE.md 5.5)'],
       V5 + 'v[0..3] = [1.0, 2.0]\n', 'v[0..3]', SM % ('3', '2'))
err_rt('err_rt_sel_store_shape_fixed', ['a fixed-size v with a constant range: the selection\'s shape is a run-time',
                                        'value, so the check is made at run time (LANGUAGE.md 5.5)'],
       'var f = [1.0, 2.0, 3.0, 4.0]\nf[0..3] = [1.0, 2.0]\n', 'f[0..3]', SM % ('3', '2'))
err_rt('err_rt_sel_store_shape_mat', ['A[0..2, :] = zeros(3, 3) on a 2 x 3 matrix: shape mismatch: 2x3 vs 3x3',
                                      '(LANGUAGE.md 5.5)'],
       'var A = zeros(2, 3)\nA[0..2, :] = zeros(3, 3)\n', 'A[0..2', SM % ('2x3', '3x3'))
err_rt('err_rt_sel_mask_store_count', ['v[m] = [1.0, 2.0] with nnz(m) = 3: shape mismatch: 3 vs 2 (LANGUAGE.md 5.5)'],
       'var v = zeros(4)\nlet m = [true, false, true, true]\nv[m] = [1.0, 2.0]\n', 'v[m]', SM % ('3', '2'))
err_rt('err_rt_sel_compound_order', ['v[0..9] += val(): the read and its checks come before e, so val is never',
                                     'called (LANGUAGE.md 5.5)'],
       'fn val() -> f64 {\n    printf("val\\n")\n    return 1.0\n}\n' + V5 + 'v[0..9] += val()\n',
       'v[0..9] += val()', IOOB % (8, 0, 5))
err_rt('err_rt_sel_compound_shape', ['v[0..3] += [1.0, 2.0]: the operation\'s check, the selection as the left',
                                     'operand (LANGUAGE.md 5.5, 6.3): 3 vs 2'],
       V5 + 'v[0..3] += [1.0, 2.0]\n', 'v[0..3]', SM % ('3', '2'))
err_rt('err_rt_sel_compound_bcast', ['A[0..1, :] += [1.0; 2.0]: 1x3 plus 2x1 broadcasts to 2x3, then the store\'s',
                                     'check, the selection first: 1x3 vs 2x3 (LANGUAGE.md 5.5, 6.3)'],
       'var A = zeros(2, 3)\nA[0..1, :] += [1.0; 2.0]\n', 'A[0..1', SM % ('1x3', '2x3'))
err_rt('err_rt_sel_step_zero', ['a range index with step 0: range step is zero (LANGUAGE.md 5.1)'],
       V5 + 'let s = 0\nlet w = v[0..5 step s]\nprintf("%d\\n", len(w))\n', 'let w', 'range step is zero')
err_rt('err_rt_flat_oob', ['A.flat[6] on a 2 x 3 matrix: the view\'s extent 6, dimension 0 (LANGUAGE.md 5.6, 5.4)'],
       'let A = zeros(2, 3)\nprintf("%g\\n", A.flat[6])\n', 'A.flat[6]', IOOB % (6, 0, 6))
err_rt('err_rt_flat_store_oob', ['A.flat[[0, 9]] = 1.0: the index vector\'s first bad element 9 (LANGUAGE.md 5.6)'],
       'var A = zeros(2, 3)\nA.flat[[0, 9]] = 1.0\n', 'A.flat', IOOB % (9, 0, 6))

# ============================================================ errors: element-wise shapes (6.3)
err_rt('err_rt_ew_vec', ['vectors of 3 and 4 elements: shape mismatch: 3 vs 4 (LANGUAGE.md 6.3)'],
       'let a = zeros(3)\nlet b = zeros(4)\nlet c = a + b\nprintf("%d\\n", len(c))\n', 'let c', SM % ('3', '4'))
err_rt('err_rt_ew_mat', ['2x3 with 3x2: neither extent is 1 in either dimension (LANGUAGE.md 6.3)'],
       'let a = zeros(2, 3)\nlet b = ones(3, 2)\nlet c = a * b\nprintf("%d\\n", rows(c))\n', 'let c',
       SM % ('2x3', '3x2'))
err_rt('err_rt_ew_zero_bcast', ['0x3 with 2x3: 0 and 2 differ and neither is 1 (LANGUAGE.md 6.3)'],
       'let a = zeros(0, 3)\nlet b = zeros(2, 3)\nlet c = a - b\nprintf("%d\\n", rows(c))\n', 'let c',
       SM % ('0x3', '2x3'))
err_rt('err_rt_ew_where_vec', ['where(c, a, b) with c and a of 3 and b of 2: the shape combined so far, then',
                               'b\'s (LANGUAGE.md 6.3): 3 vs 2'],
       'let c = filled(true, 3)\nlet a = zeros(3)\nlet b = zeros(2)\nlet w = where(c, a, b)\n'
       'printf("%d\\n", len(w))\n', 'let w', SM % ('3', '2'))
err_rt('err_rt_ew_where_mat', ['where(c, a, b) with c 1x4, a 3x1, b 2x4: c with a combine to 3x4, then b',
                               '(LANGUAGE.md 6.3): 3x4 vs 2x4'],
       'let c = filled(true, 1, 4)\nlet a = zeros(3, 1)\nlet b = zeros(2, 4)\nlet w = where(c, a, b)\n'
       'printf("%d\\n", rows(w))\n', 'let w', SM % ('3x4', '2x4'))
err_rt('err_rt_ew_elem_call', ['an elemental call with arrays of 3 and 2 elements (LANGUAGE.md 6.3, 10.4)'],
       'let w = hypot(zeros(3), ones(2))\nprintf("%d\\n", len(w))\n', 'let w', SM % ('3', '2'))
err_rt('err_rt_ew_i64_overflow', ['element-wise i64 + overflows: integer overflow (LANGUAGE.md 6.5)'],
       'let a = filled(9223372036854775807, 2)\nlet b = a + 1\nprintf("%d\\n", b[0])\n', 'let b',
       'integer overflow')
err_rt('err_rt_ew_i64_neg', ['element-wise unary - of -2^63: integer overflow (LANGUAGE.md 6.5)'],
       'let a = filled(-9223372036854775808, 2)\nlet b = -a\nprintf("%d\\n", b[0])\n', 'let b', 'integer overflow')
err_rt('err_rt_ew_i64_mod_zero', ['element-wise i64 % with a zero element: integer division by zero (LANGUAGE.md 6.6)'],
       'let a = [5, 6]\nlet b = filled(0, 2)\nlet c = a % b\nprintf("%d\\n", c[0])\n', 'let c',
       'integer division by zero')
err_rt('err_rt_ew_idiv_zero', ['element-wise idiv with a zero divisor: integer division by zero (LANGUAGE.md 6.6)'],
       'let a = [5, 6]\nlet z = 0\nlet c = idiv(a, z)\nprintf("%d\\n", c[0])\n', 'let c',
       'integer division by zero')

# ============================================================ errors: conversions (10.1)
err_rt('err_rt_cvt_first_bad', ['i64 of 1.0 2.5 3.5: the first element that is not an integer, 2.5 (LANGUAGE.md',
                                '10.1, 9.2; %g spelling)'],
       'var v = zeros(3)\nv[0] = 1.0\nv[1] = 2.5\nv[2] = 3.5\nlet n = i64(v)\nprintf("%d\\n", n[0])\n',
       'let n', 'conversion to i64: 2.5 is not an integer')
err_rt('err_rt_cvt_nan_elem', ['i64 of 4.0 NaN: NaN is not an integer (LANGUAGE.md 10.1, 11.1 spelling)'],
       'let n = i64([4.0, nan])\nprintf("%d\\n", n[0])\n', 'let n', 'conversion to i64: NaN is not an integer')

# ============================================================ errors: fix (4.5)
err_rt('err_rt_fix_bind', ['a dynamic array of 5 bound to f64[4]: shape mismatch: expected 4, got 5 (LANGUAGE.md 4.5)'],
       'let f: f64[4] = zeros(5)\nprintf("%g\\n", f[0])\n', 'let f', SE % ('4', '5'))
err_rt('err_rt_fix_assign', ['assignment from a dynamic array to a fixed-size variable (LANGUAGE.md 4.5)'],
       'var f = [1.0, 2.0, 3.0, 4.0]\nf = zeros(5)\nprintf("%g\\n", f[0])\n', 'f = zeros', SE % ('4', '5'))
err_rt('err_rt_fix_arg', ['a dynamic argument for an f64[4] parameter (LANGUAGE.md 4.5)'],
       'fn s4(v: f64[4]) -> f64 {\n    return v[0]\n}\nprintf("%g\\n", s4(zeros(3)))\n', 'printf',
       SE % ('4', '3'))
err_rt('err_rt_fix_return', ['a dynamic array returned as f64[2] (LANGUAGE.md 4.5)'],
       'fn mk() -> f64[2] {\n    return zeros(3)\n}\nlet a = mk()\nprintf("%g\\n", a[0])\n', 'return zeros',
       SE % ('2', '3'))
err_rt('err_rt_fix_mat', ['a 3 x 2 dynamic matrix bound to f64[2,2]: expected 2x2, got 3x2 (LANGUAGE.md 4.5)'],
       'let M: f64[2,2] = zeros(3, 2)\nprintf("%g\\n", M[0, 0])\n', 'let M', SE % ('2x2', '3x2'))
err_rt('err_rt_fix_ew', ['a fixed f64[3] times a dynamic vector is dynamic (DESIGN.md 3.5.5), so binding it to',
                         'f64[2] is the run-time check (LANGUAGE.md 4.5)'],
       'let s: f64[2] = [1.0, 2.0, 3.0] * zeros(3)\nprintf("%g\\n", s[0])\n', 'let s', SE % ('2', '3'))
err_rt('err_rt_fix_lit257', ['a literal of 257 scalars is dynamic (LANGUAGE.md 4.5, 6.9): binding it to i64[4] is',
                             'the run-time check, expected 4, got 257'],
       'let g: i64[4] = ' + LIT257 + '\nprintf("%d\\n", g[0])\n', 'let g', SE % ('4', '257'))

# ============================================================ errors: concatenation at run time
# DESIGN.md 3.6.6 rule 26 (c): a row of matrices checks each part against the row's joined shape so
# far; rows are checked against the stack so far, a vector row counting as 1 x n.
err_rt('err_rt_cat_rows', ['joining a 2x2 and a 3x1 dynamic matrix: the joined shape so far first',
                           '(LANGUAGE.md 6.9; DESIGN.md 3.6.6 rule 26 (c)): 2x2 vs 3x1'],
       'let C = [zeros(2, 2), zeros(3, 1)]\nprintf("%d\\n", rows(C))\n', 'let C', SM % ('2x2', '3x1'))
err_rt('err_rt_cat_stack', ['stacking vector rows of 2 and 3 elements: 1x2 vs 1x3 (LANGUAGE.md 6.9; DESIGN.md',
                            '3.6.6 rule 26 (c))'],
       'let C = [zeros(2); zeros(3)]\nprintf("%d\\n", rows(C))\n', 'let C', SM % ('1x2', '1x3'))

# ============================================================ errors: range values (5.1)
err_rt('err_rt_range_size', ['a range value of 3000000000 positions: invalid array size 3000000000 (LANGUAGE.md 5.1)'],
       'let r = (0..3000000000)\nprintf("%d\\n", len(r))\n', 'let r', 'invalid array size 3000000000')
err_rt('err_rt_range_size_sat', ['-2^63..=2^63-1 has 2^64 positions, beyond i64: the saturated text',
                                 'invalid array size 9223372036854775807 (LANGUAGE.md 5.1)'],
       'let r = (-9223372036854775808..=9223372036854775807)\nprintf("%d\\n", len(r))\n', 'let r',
       'invalid array size 9223372036854775807')
err_rt('err_rt_range_size_sat2', ['0..=2^63-1 has 2^63 positions, beyond i64: the saturated text (LANGUAGE.md 5.1)'],
       'let r = (0..=9223372036854775807)\nprintf("%d\\n", len(r))\n', 'let r',
       'invalid array size 9223372036854775807')
err_rt('err_rt_range_step_zero', ['a range value with step 0: range step is zero (LANGUAGE.md 5.1)'],
       'let s = 0\nlet r = (0..5 step s) * 2\nprintf("%d\\n", len(r))\n', 'let r', 'range step is zero')

# ============================================================ errors: index utilities (10.7)
err_rt('err_rt_ind2sub_zero_vec', ['ind2sub(0, k) with a vector k: integer division by zero at the call\'s line',
                                   '(LANGUAGE.md 10.7, 6.6; Decision 33)'],
       'let r = 0\nlet k = (0..3)\nlet (i, j) = ind2sub(r, k)\nprintf("%d\\n", len(i))\n', 'ind2sub',
       'integer division by zero')
err_rt('err_rt_sub2ind_vec_oob', ['sub2ind(3, i, j) with i = 0 3 5: the first bad element 3, dimension 0, extent 3',
                                  '(LANGUAGE.md 10.7; DESIGN.md 2.6.2)'],
       'let w = sub2ind(3, [0, 3, 5], [0, 0, 0])\nprintf("%d\\n", len(w))\n', 'let w', IOOB % (3, 0, 3))

# ============================================================ errors: static shapes (DESIGN.md 3.5.5)
# 217 `shape mismatch: %s vs %s` at the operator node (the position of its left operand, 3.3), the
# call, the mask index, the concatenation part, or the stored value (2.6.2 `expr`).
err_c('err_shape_static_ew', ['fixed operands of 3 and 2 elements: the compile-time shape mismatch at the',
                              'operator node, its left operand\'s start (LANGUAGE.md 4.10, 6.3; DESIGN.md 3.5.5)'],
      'let a = [1.0, 2.0, 3.0]\nlet b = [1.0, 2.0]\nlet c = a + b\n', 'let c', 'a + b', SM % ('3', '2'))
err_c('err_shape_static_ew_mat', ['fixed 2x2 and 3x2 operands (DESIGN.md 3.5.5)'],
      'let A = [1.0, 2.0; 3.0, 4.0]\nlet B = [1.0, 2.0; 3.0, 4.0; 5.0, 6.0]\nlet C = A * B\n', 'let C',
      'A * B', SM % ('2x2', '3x2'))
err_c('err_shape_static_where', ['where(a, b, c) with fixed a 1x4, b 3x1, c 2x4: 3x4 vs 2x4 at the call',
                                 '(DESIGN.md 3.5.5, its example)'],
      'let a = [true, false, true, false].row\nlet b = [1.0; 2.0; 3.0]\n'
      'let c = [1.0, 2.0, 3.0, 4.0; 5.0, 6.0, 7.0, 8.0]\nlet w = where(a, b, c)\n', 'let w', 'where',
      SM % ('3x4', '2x4'))
err_c('err_shape_static_where_dyn', ['where(a3, c, b4) with a dynamic c: the combined extent 3 stays known, then',
                                     'b4 (DESIGN.md 3.5.5, its example): 3 vs 4'],
      'let a3 = [true, false, true]\nlet c = zeros(3)\nlet b4 = [1.0, 2.0, 3.0, 4.0]\nlet w = where(a3, c, b4)\n',
      'let w', 'where', SM % ('3', '4'))
err_c('err_shape_static_ew_result', ['an element-wise result of fixed operands is fixed (f64[3]), so binding it to',
                                     'f64[2] is 217 at the value, the target first (DESIGN.md 3.5.5, 2.6.2)'],
      'let a = [1.0, 2.0, 3.0]\nlet s: f64[2] = a * 2.0\n', 'let s', 'a * 2.0', SM % ('2', '3'))
err_c('err_shape_static_mask', ['a fixed mask of 2 on a fixed vector of 3: at the mask index, what it selects',
                                'from first (LANGUAGE.md 5.2; DESIGN.md 3.5.5)'],
      'let v = [1.0, 2.0, 3.0]\nlet m = [true, false]\nlet w = v[m]\n', 'let w', 'm]', SM % ('3', '2'))
err_c('err_shape_static_mask_mat', ['a fixed 3x2 whole-matrix mask on a fixed 2x3 matrix (LANGUAGE.md 5.2)'],
      'let A = [1.0, 2.0, 3.0; 4.0, 5.0, 6.0]\nlet M = [true, false; true, false; true, true]\nlet s = A[M]\n',
      'let s', 'M]', SM % ('2x3', '3x2'))
err_c('err_shape_static_mask_dim', ['a fixed mask of 3 for the 2 rows of a fixed matrix: the dimension\'s extent',
                                    'as a vector shape, then len(m) (LANGUAGE.md 5.2)'],
      'let A = [1.0, 2.0, 3.0; 4.0, 5.0, 6.0]\nlet B = A[[true, false, true], :]\n', 'let B', '[true',
      SM % ('2', '3'))
err_c('err_shape_static_cat', ['joining fixed 2x2 and 3x1 matrices: at the part, the joined shape so far first',
                               '(LANGUAGE.md 6.9; DESIGN.md 3.5.5)'],
      'let A = [1.0, 2.0; 3.0, 4.0]\nlet B = [5.0; 6.0; 7.0]\nlet C = [A, B]\n', 'let C', 'B]',
      SM % ('2x2', '3x1'))
err_c('err_shape_static_bind', ['let a: f64[4] = [1.0, 2.0, 3.0]: at the value, the target\'s shape first',
                                '(DESIGN.md 2.6.2 `expr`)'],
      'let a: f64[4] = [1.0, 2.0, 3.0]\n', 'let a', '[1.0', SM % ('4', '3'))
err_c('err_shape_static_assign', ['a fixed value of 3 assigned to a fixed variable of 2 (DESIGN.md 3.5.5)'],
      'var a = [1.0, 2.0]\na = [1.0, 2.0, 3.0]\n', 'a = [1.0, 2.0, 3.0]', '[1.0', SM % ('2', '3'))
err_c('err_shape_static_arg', ['a fixed argument of 3 for an f64[2] parameter (DESIGN.md 3.5.5)'],
      'fn f(v: f64[2]) -> f64 {\n    return v[0]\n}\nlet x = f([1.0, 2.0, 3.0])\n', 'let x', '[1.0',
      SM % ('2', '3'))
err_c('err_shape_static_return', ['a fixed value of 3 returned as f64[2] (DESIGN.md 3.5.5)'],
      'fn g() -> f64[2] {\n    return [1.0, 2.0, 3.0]\n}\nlet y = g()\n', 'return', '[1.0', SM % ('2', '3'))
err_c('err_shape_static_mat_bind', ['a fixed 2x3 literal bound to f64[2,2] (DESIGN.md 3.5.5)'],
      'let M: f64[2,2] = [1.0, 2.0, 3.0; 4.0, 5.0, 6.0]\n', 'let M', '[1.0', SM % ('2x2', '2x3'))
err_c('err_shape_static_empty', ['[] under a fixed-size type with elements: shape mismatch, the target\'s shape',
                                 'first, [] the vector of length 0 (LANGUAGE.md 6.9)'],
      'let a: f64[2] = []\n', 'let a', '[]', SM % ('2', '0'))
err_c('err_shape_static_lit256', ['a literal of 256 scalars is fixed (i64[256], LANGUAGE.md 4.5): binding it to',
                                  'i64[4] is the compile error (compare err_rt_fix_lit257)'],
      'let g: i64[4] = ' + LIT256 + '\n', 'let g', '[', SM % ('4', '256'), last=True)

# ============================================================ errors: other v1 errors at array constructs
err_c('err_type_mismatch_lit', ['[true, 1]: no common element type, at the first element that does not combine',
                                '(LANGUAGE.md 6.9; DESIGN.md 3.5.5)'],
      'let x = [true, 1]\n', 'let x', '1]', 'type mismatch: expected bool, found i64')
err_c('err_vec_mat', ['a vector with a matrix operand (LANGUAGE.md 6.3): at the operator node'],
      'let v = zeros(3)\nlet A = zeros(3, 3)\nlet w = v + A\n', 'let w', 'v + A',
      'cannot combine a vector with a matrix: use .col or .row')
INFER = 'type cannot be inferred: add a type annotation'
err_c('err_cannot_infer_let', ['let x = []: no type from the context, 252 at the [ (LANGUAGE.md 6.9; Decision 36)'],
      'let x = []\n', 'let x', '[]', INFER)
err_c('err_cannot_infer_len', ['len([]): a library argument gives no type (LANGUAGE.md 6.9; Decision 36)'],
      'printf("%d\\n", len([]))\n', 'printf', '[]', INFER)
err_c('err_cannot_infer_add', ['[] + v with v an f64[]: an operand gives no type (LANGUAGE.md 6.9; Decision 36)'],
      'let v = zeros(2)\nlet w = [] + v\n', 'let w', '[]', INFER)
err_c('err_no_transpose', ['.T of a vector, at the dot node (the operand\'s start; LANGUAGE.md 5.6)'],
      'let v = zeros(3)\nlet w = v.T\n', 'let w', 'v.T', 'vector has no transpose: use .row or .col')
err_c('err_ragged', ['rows of 2 and 1 scalars: at the first row whose length differs (LANGUAGE.md 6.9)'],
      'let A = [1, 2; 3]\n', 'let A', '3]', 'ragged matrix literal')
err_c('err_use_row_col', ['a row joining a vector and a matrix, at the row (its first element; LANGUAGE.md 6.9)'],
      'let v = [1.0, 2.0]\nlet A = [1.0, 2.0; 3.0, 4.0]\nlet B = [v, A]\n', 'let B', 'v, A', 'use .row or .col')
err_c('err_bad_target_view_t', ['an element of A.T as an assignment target (LANGUAGE.md 5.6, 7.3: only .flat is a',
                                'target), at the target'],
      'var A = zeros(2, 2)\nA.T[0, 1] = 5.0\n', 'A.T[0', 'A.T', 'invalid assignment target')
err_c('err_bad_target_view_row', ['v.row as an assignment target (LANGUAGE.md 5.6, 7.3), at the target'],
      'var v = zeros(2)\nv.row[0, 1] = 1.0\n', 'v.row[0', 'v.row', 'invalid assignment target')
err_c('err_view_rank_col', ['.col of a matrix (LANGUAGE.md 5.6), at the dot node'],
      'let A = zeros(2, 2)\nlet c = A.col\n', 'let c', 'A.col', 'view .col is not defined for f64[,]')
err_c('err_view_rank_flat', ['.flat of a vector (LANGUAGE.md 5.6), at the dot node'],
      'let v = zeros(2)\nlet f = v.flat\n', 'let f', 'v.flat', 'view .flat is not defined for f64[]')
err_c('err_view_rank_fixed', ['.row of a fixed matrix: the type written as in Sea source (DESIGN.md 2.6.2)'],
      'let A = [1, 2; 3, 4]\nlet r = A.row\n', 'let r', 'A.row', 'view .row is not defined for i64[2,2]')

# ============================================================ errors: phase-rule words after step 4e (2.6.2)
NS = 'not supported yet: %s'
err_c('err_ns_str_literal', ['a literal of str elements is strings, at the array node (DESIGN.md 2.6.2 step 4e)'],
      'let names = ["a", "b"]\n', 'let names', '[', NS % 'strings')
err_c('err_ns_str_fixed_type', ['a fixed-size type of str elements is strings, at its type node (DESIGN.md 2.6.2',
                                'step 4e)'],
      'fn f() -> str[2] {\n    return ["a", "b"]\n}\n', 'fn f', 'str[2]', NS % 'strings')
err_c('err_ns_lib_max1_fixed', ['max of one fixed vector is still the name max until 4f, at the call (DESIGN.md',
                                '2.6.2 step 4e)'],
      'printf("%g\\n", max([1.0, 2.0]))\n', 'printf', 'max', NS % 'max')

# ============================================================ tuple assignment (7.3, Decision 37)
# LANGUAGE.md 7.3 (as amended by Decision 37): the call first, then each target in order, each
# stored exactly as `ti = ri` would store result i, with the conversions of assignment (i64 -> f64
# element by element, fixed -> dynamic, dynamic -> fixed with its run-time check, 4.5); a selection
# target takes any array of its rank, checked at run time (5.5).
prog('sel_tasg', ['tuple assignment to selection, .flat and converting targets (LANGUAGE.md 7.3 as amended by',
                  'Decision 37, 4.2, 4.5, 5.5, 10.7): selection and .flat targets, fixed <-> dynamic, i64[] ->',
                  'f64[], ind2sub into dynamic and selection targets, the last store wins, a ref call in a target'],
     ['pf', 'pvi', 'pmf', 'pmi'], [
    ('var v = zeros(5)', None),
    ('var x = 0.0', None),
    ('(v[1..4], x) = two()', None),               # v[1..4] = 7 8 9 (dynamic result), x = 5
    ('pf(v)', '5: 0 7 8 9 0'),
    ('printf("%g\\n", x)', '5'),
    ('var A = zeros(2, 3)', None),
    ('(A.flat[3], x) = sc()', None),              # flat 3 of a 2-row matrix is A[1, 1] = 4; x = 6
    ('pmf(A)', '2x3 | 0 0 0 | 0 4 0'),
    ('printf("%g\\n", x)', '6'),
    ('var B = zeros(2, 2)', None),
    ('(B[0, :], x) = fx()', None),                # the fixed f64[2] result 1 2 into row 0; x = 3
    ('pmf(B)', '2x2 | 1 2 | 0 0'),
    ('printf("%g\\n", x)', '3'),
    ('var d = zeros(5)', None),                   # a dynamic f64[] target
    ('var k = 0', None),
    ('(d, k) = fk()', None),                      # fixed f64[2] -> dynamic (dyn): d becomes 1.5 2.5
    ('pf(d)', '2: 1.5 2.5'),
    ('printf("%d\\n", k)', '7'),
    ('var f = [0.0, 0.0]', None),                 # a fixed f64[2] target
    ('(f, k) = dk()', None),                      # dynamic ones(2) -> fixed (fix, 2 = 2); k = 3
    ('pf(f)', '2: 1 1'),
    ('printf("%d\\n", k)', '3'),
    ('(d, k) = ik()', None),                      # the i64[] 0 1 2 converted element by element; k = 4
    ('pf(d)', '3: 0 1 2'),
    ('printf("%d\\n", k)', '4'),
    ('var I = filled(0, 0)', None),
    ('var J = filled(0, 0)', None),
    # ind2sub(3, k) for k = 4 5 7: k % 3 = 1 2 1, idiv(k, 3) = 1 1 2 (fixed results, dyn into I, J)
    ('(I, J) = ind2sub(3, [4, 5, 7])', None),
    ('pvi(I)', '3: 1 2 1'),
    ('pvi(J)', '3: 1 1 2'),
    ('var P = filled(0, 5)', None),
    ('var Q = filled(0, 0)', None),
    ('let kk = (3..6)', None),                    # 3 4 5
    ('(P[1..4], Q) = ind2sub(2, kk)', None),      # k % 2 = 1 0 1 into P[1..4]; idiv(k, 2) = 1 2 2
    ('pvi(P)', '5: 0 1 0 1 0'),
    ('pvi(Q)', '3: 1 2 2'),
    ('var M = filled(0, 2, 2)', None),
    ('(M[0, :], M[1, :]) = ind2sub(3, [4, 5])', None),   # rows 4 % 3, 5 % 3 = 1 2 and idiv = 1 1
    ('pmi(M)', '2x2 | 1 2 | 1 1'),
    ('var u = zeros(3)', None),
    ('(u[0..2], u[1]) = lw()', None),             # u[0..2] = 1 2, then u[1] = 9: the last store wins
    ('pf(u)', '3: 1 9 0'),
    ('var w = zeros(3)', None),
    ('var j = 0', None),
    # the call first; target 1 (value, then indices): g makes j = 1, u2[1..3] = 1 2; target 2
    # reads the new j: w[1] = 9
    ('var u2 = zeros(3)', None),
    ('(u2[g(ref j)..3], w[j]) = lw()', None),
    ('pf(u2)', '3: 0 1 2'),
    ('pf(w)', '3: 0 9 0'),
    ('printf("%d\\n", j)', '1'),
], fns=r'''fn two() -> (f64[], f64) {
    return ([7.0, 8.0, 9.0], 5.0)
}
fn sc() -> (f64, f64) {
    return (4.0, 6.0)
}
fn fx() -> (f64[2], f64) {
    return ([1.0, 2.0], 3.0)
}
fn fk() -> (f64[2], i64) {
    return ([1.5, 2.5], 7)
}
fn dk() -> (f64[], i64) {
    return (ones(2), 3)
}
fn ik() -> (i64[], i64) {
    return ((0..3), 4)
}
fn lw() -> (f64[], f64) {
    return ([1.0, 2.0], 9.0)
}
fn g(ref k: i64) -> i64 {
    k += 1
    return k
}
''')

prog('heap_tasg', ['tuple assignments that discard or replace dynamic results (LANGUAGE.md 7.3; DESIGN.md',
                   '3.5.9 L12, 3.6.6 rules 15 (h), (j), 16): `_` with a dynamic result, converted and selection',
                   'targets in a loop'],
     ['pf'], [
    ('var x = 0.0', None),
    ('var d = zeros(1)', None),
    ('var v = zeros(4)', None),
    ('for i in 0..3 {\n    (_, x) = two()\n    (d, _) = two()\n    (v[1..4], x) = two()\n}', None),
    ('printf("%g\\n", x)', '5'),
    ('pf(d)', '3: 7 8 9'),
    ('pf(v)', '4: 0 7 8 9'),
    ('let (_, y) = two()', None),
    ('printf("%g\\n", y)', '5'),
], fns=r'''fn two() -> (f64[], f64) {
    return ([7.0, 8.0, 9.0], 5.0)
}
''')

# Rule-12 regressions for range indices (DESIGN.md 6.2): g adds 1 to k and returns the new k. For
# op= the indices (both bounds of a range) come first, then the read, then e (LANGUAGE.md 5.5); for
# `=` the value, then the indices left to right.
prog('sel_ref_range', ['ref calls beside range indices (LANGUAGE.md 5.5, 8.3; DESIGN.md 3.6.6 rule 12, 6.2):',
                       'v[k..k+2] += f64(g(ref k)) selects from the old k, on a dynamic and a fixed vector;',
                       'A[k, 0..2] += f64(g(ref k)); A[k..1, g(ref k)..3] = 9.0 takes its rows from the old k'],
     ['pf', 'pmf'], [
    ('var v: f64[] = [1.0, 1.0, 0.0, 0.0]', None),
    ('var k = 0', None),
    ('v[k..k+2] += f64(g(ref k))', None),         # 0..2 (old k); read 1 1; g gives 1: 2 2
    ('pf(v)', '4: 2 2 0 0'),
    ('printf("%d\\n", k)', '1'),
    ('var f = [1.0, 1.0, 0.0, 0.0]', None),       # fixed f64[4]
    ('k = 0', None),
    ('f[k..k+2] += f64(g(ref k))', None),
    ('pf(f)', '4: 2 2 0 0'),
    ('var A: f64[,] = [1.0, 1.0; 0.0, 0.0]', None),
    ('k = 0', None),
    ('A[k, 0..2] += f64(g(ref k))', None),        # row 0 (old k), cols 0 1: 1 1 + 1
    ('pmf(A)', '2x2 | 2 2 | 0 0'),
    ('var C = zeros(3, 3)', None),
    ('k = 0', None),
    ('C[k..1, g(ref k)..3] = 9.0', None),         # rows 0..1 (old k = 0), then g: cols 1..3
    ('pmf(C)', '3x3 | 0 9 9 | 0 0 0 | 0 0 0'),
    ('printf("%d\\n", k)', '1'),
], fns=r'''fn g(ref k: i64) -> i64 {
    k += 1
    return k
}
''')

err_rt('err_rt_tasg_fix', ['a dynamic result of 3 elements into a fixed f64[2] target of a tuple assignment: the',
                           'run-time check of 4.5 at the statement\'s line (LANGUAGE.md 7.3 as amended by Decision',
                           '37; the earlier target k is stored first)'],
       'fn dy() -> (i64, f64[]) {\n    return (1, zeros(3))\n}\nvar k = 0\nvar f = [0.0, 0.0]\n(k, f) = dy()\n'
       'printf("%d\\n", k)\n', '(k, f)', SE % ('2', '3'))
err_c('err_tasg_shape_static', ['a fixed f64[3] result into a fixed f64[2] target: 217 at the target, the target\'s',
                                'shape first (DESIGN.md 3.5.5, Decision 37)'],
      'fn fx() -> (f64[3], i64) {\n    return ([1.0, 2.0, 3.0], 1)\n}\nvar f = [0.0, 0.0]\nvar k = 0\n(f, k) = fx()\n',
      '(f, k)', 'f, k', SM % ('2', '3'))
err_c('err_tasg_type', ['a bool[] result into an f64[] target: 201 at the target, expected the target\'s type',
                        '(DESIGN.md 3.5.5, Decision 37)'],
      'fn bv() -> (bool[], i64) {\n    return (filled(true, 2), 1)\n}\nvar d = zeros(2)\nvar k = 0\n(d, k) = bv()\n',
      '(d, k)', 'd, k', 'type mismatch: expected f64[], found bool[]')

# Converting components (LANGUAGE.md 7.3, 4.2 (b), (c), 4.5): each target stored as `ti = ri`.
prog('sel_tasg_cvt', ['converting tuple-assignment components (LANGUAGE.md 7.3 as amended by Decision 37,',
                      '4.2, 4.5, 5.5): a fixed i64[3] result into an f64[] target, a dynamic i64[] result into',
                      'an f64[3] target, scalar f64 and i64 results into selection targets'],
     ['pf'], [
    ('var d = zeros(1)', None),
    ('var k = 0', None),
    ('(d, k) = fi()', None),                      # 1 2 3 converted to f64 and made dynamic; k = 4
    ('pf(d)', '3: 1 2 3'),
    ('printf("%d\\n", k)', '4'),
    ('var f = [0.0, 0.0, 0.0]', None),            # fixed f64[3]
    ('(f, k) = di()', None),                      # (5..8) = 5 6 7: length 3 checked, converted; k = 1
    ('pf(f)', '3: 5 6 7'),
    ('printf("%d\\n", k)', '1'),
    ('var v = zeros(4)', None),
    ('(v[0..2], k) = sf()', None),                # the scalar 2.5 stored into both elements; k = 6
    ('pf(v)', '4: 2.5 2.5 0 0'),
    ('printf("%d\\n", k)', '6'),
    ('(v[2..4], k) = si()', None),                # the i64 7 converted to 7.0 into both; k = 8
    ('pf(v)', '4: 2.5 2.5 7 7'),
    ('printf("%d\\n", k)', '8'),
], fns=r'''fn fi() -> (i64[3], i64) {
    return ([1, 2, 3], 4)
}
fn di() -> (i64[], i64) {
    return ((5..8), 1)
}
fn sf() -> (f64, i64) {
    return (2.5, 6)
}
fn si() -> (i64, i64) {
    return (7, 8)
}
''')

err_rt('err_rt_tasg_fix_cvt', ['a dynamic i64[] result of 4 elements into a fixed f64[3] target of a tuple',
                               'assignment: the run-time shape check of 4.5 at the statement\'s line (the',
                               'conversion of 4.2 (c) cannot fail; LANGUAGE.md 7.3 as amended by Decision 37)'],
       'fn d4() -> (i64[], i64) {\n    return ((0..4), 1)\n}\nvar f = [0.0, 0.0, 0.0]\nvar k = 0\n(f, k) = d4()\n'
       'printf("%g\\n", f[0])\n', '(f, k)', SE % ('3', '4'))

# ============================================================ the 4d goldens step 4e retires (6.2)
for old in ('err_ns_arr_all_index', 'err_ns_arr_cvt', 'err_ns_arr_elem_arg', 'err_ns_arr_ew',
            'err_ns_arr_fixed_local', 'err_ns_arr_max2', 'err_ns_arr_range_index', 'err_ns_arr_view',
            'err_ns_array_literal', 'err_ns_array_type'):
    for ext in ('.sea', '.err', '.status', '.out'):
        p = os.path.join(ERRORS, old + ext)
        if os.path.exists(p):
            os.remove(p)

print('arr4e_cases: %d programs, %d errors' % (COUNT['programs'], COUNT['errors']))
