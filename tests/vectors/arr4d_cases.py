"""Sub-phase 4d corpus: programs/ and errors/ tests of the dynamic arrays core (DESIGN.md 6.2 "4d").

Run with `timeout 120 uv run --no-project python tests/vectors/arr4d_cases.py`. It writes the
programs/arr_*, programs/heap_*, errors/err_rt_arr_*, errors/err_ns_arr_str_elem and
errors/err_ns_lib_{max1,min1} tests below. Every expected output is written out by hand in this
file from LANGUAGE.md (4.5, 5, 7.3, 7.5, 7.7, 8.3, 9.2, 10.2, 10.4, 10.7, 11.1); the comment
beside each case gives the derivation. Nothing here runs the compiler. The run-time error line of
an errors/ test is the line of the source that holds the marker text given with it, and a compile
error's column is that of its marker inside that line (both computed from the source text, so
they cannot drift from it). The eight `arrays` phase-rule cases of 4d were retired by step 4e
(see the end of the file).
"""

import os

HERE = os.path.dirname(os.path.abspath(__file__))
TESTS = os.path.dirname(HERE)
PROGRAMS = os.path.join(TESTS, 'programs')
ERRORS = os.path.join(TESTS, 'errors')
COUNT = {'programs': 0, 'errors': 0}


def write(path, text):
    with open(path, 'w') as f:
        f.write(text)


def source(name, comment, body):
    head = ''.join('// %s\n' % c for c in comment)
    head = '// %s -- ' % name + head[3:]
    return head + body


def prog(name, comment, body, out):
    """comment: a list of comment lines (the first follows 'NAME -- ')."""
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


def err_c(name, comment, body, marker, col_text, msg):
    """A compile error at the first occurrence of col_text in the marker's line."""
    src = source(name, comment, body)
    ln, text = line_of(src, marker)
    col = text.index(col_text) + 1
    write(os.path.join(ERRORS, name + '.sea'), src)
    write(os.path.join(ERRORS, name + '.err'), '%s.sea:%d:%d: error: %s\n' % (name, ln, col, msg))
    write(os.path.join(ERRORS, name + '.status'), '1\n')
    COUNT['errors'] += 1


# ================================================================ construction and shape (10.2)
# zeros: +0.0 elements (%g prints 0); ones: 1.0; filled: v's type, an untyped integer is i64 (the
# `let k: i64 = fi[1]` compiles only for an i64 element); len/rows/cols/numel are i64; empty
# arrays are legal (4.5); numel(r x c) = r * c.
prog('arr_construct', ['zeros, ones, filled of f64, i64 and bool; len, rows, cols, numel, empty arrays',
                       '(LANGUAGE.md 4.5, 10.2)'], '''let z0 = zeros(0)
printf("%d %d\\n", len(z0), numel(z0))
let z3 = zeros(3)
printf("%d %g %g %g\\n", len(z3), z3[0], z3[1], z3[2])
let m30 = zeros(3, 0)
printf("%d %d %d\\n", rows(m30), cols(m30), numel(m30))
let m04 = zeros(0, 4)
printf("%d %d %d\\n", rows(m04), cols(m04), numel(m04))
let m23 = zeros(2, 3)
printf("%d %d %d %g\\n", rows(m23), cols(m23), numel(m23), m23[1, 2])
let o = ones(2)
printf("%d %g %g\\n", len(o), o[0], o[1])
let om = ones(2, 3)
printf("%d %d %g %g\\n", rows(om), cols(om), om[0, 0], om[1, 2])
let ff = filled(2.5, 3)
printf("%g %g %g\\n", ff[0], ff[1], ff[2])
let fi = filled(7, 2)
let k: i64 = fi[1]
printf("%d %d\\n", fi[0] + 1, k)
let fb = filled(true, 2, 2)
printf("%d %d %d %d\\n", rows(fb), cols(fb), fb[0, 0], fb[1, 1])
let fm = filled(-1.5, 1, 2)
printf("%d %d %g %g\\n", rows(fm), cols(fm), fm[0, 0], fm[0, 1])
let e = filled(false, 0)
printf("%d %d\\n", len(e), numel(e))
let n = 4
let zn = zeros(n - 1, n)
printf("%d %d %d\\n", rows(zn), cols(zn), numel(zn))
let fz = filled(0, 0, 3)
printf("%d %d %d\\n", rows(fz), cols(fz), numel(fz))
''', '''0 0
3 0 0 0
3 0 0
0 4 0
2 3 6 0
2 1 1
2 3 1 1
2.5 2.5 2.5
8 7
2 2 1 1
1 2 -1.5 -1.5
0 0
3 4 12
0 3 0
''')

# ARRAY_SIZE (9.2, 10.2): a negative extent, or one above 2^31 - 1, is `invalid array size %d` with
# that extent, at the constructor's line, after the output before it; rows are checked before
# cols (DESIGN.md 4.8 sea_arr_new), so the first bad extent in that order is named.
err_rt('err_rt_arr_size_neg', ['zeros(n) with n = -1: invalid array size -1 (LANGUAGE.md 10.2, 9.2)'],
       '''let n = 1 - 2
printf("before\\n")
let v = zeros(n)
printf("%d\\n", len(v))
''', 'let v = zeros(n)', 'invalid array size -1', 'before\n')
err_rt('err_rt_arr_size_big', ['ones(2^31): an extent above 2^31 - 1 is invalid array size 2147483648',
                               '(LANGUAGE.md 4.5, 10.2, 9.2)'],
       '''let n = 2147483648
let v = ones(n)
printf("%d\\n", len(v))
''', 'let v = ones(n)', 'invalid array size 2147483648')
err_rt('err_rt_arr_size_mat', ['filled(1.0, r, c) with a bad column extent -3 (LANGUAGE.md 10.2, 9.2)'],
       '''let c = 0 - 3
let A = filled(1.0, 2, c)
printf("%d\\n", rows(A))
''', 'let A = filled', 'invalid array size -3')
err_rt('err_rt_arr_size_order', ['zeros(-1, 2^31): rows are checked first, so -1 is named (LANGUAGE.md 10.2;',
                                 'DESIGN.md 4.8 sea_arr_new)'],
       '''let r = 0 - 1
let c = 2147483648
let A = zeros(r, c)
printf("%d\\n", rows(A))
''', 'let A = zeros', 'invalid array size -1')

# ================================================================ element read and write (5.1-5.5)
# A[i, j] = f64(i + 10 * j) is read back at each position; column-major storage is not observable
# through scalar indices, which address (i, j) whatever the layout (4.5); i64 squares; bool
# elements print as 0/1 with %d (11.1).
prog('arr_rw', ['element read and write of f64[], i64[], bool[], f64[,], i64[,] and bool[,] by scalar',
                'indices (LANGUAGE.md 5.1, 5.2, 5.5)'], '''var v = zeros(4)
for i in 0..4 {
    v[i] = f64(i) * 0.5
}
printf("%g %g %g %g\\n", v[0], v[1], v[2], v[3])
var iv = filled(0, 4)
for i in 0..4 {
    iv[i] = i * i
}
printf("%d %d %d %d\\n", iv[0], iv[1], iv[2], iv[3])
var bv = filled(false, 3)
bv[1] = true
printf("%d %d %d\\n", bv[0], bv[1], bv[2])
if bv[1] && !bv[2] {
    printf("bool ok\\n")
}
var A = zeros(2, 3)
for j in 0..3 {
    for i in 0..2 {
        A[i, j] = f64(i + 10 * j)
    }
}
printf("%g %g %g %g %g %g\\n", A[0, 0], A[1, 0], A[0, 1], A[1, 1], A[0, 2], A[1, 2])
var M = filled(0, 3, 2)
M[2, 1] = -5
M[0, 1] = 9223372036854775807
printf("%d %d %d\\n", M[2, 1], M[0, 1], M[1, 0])
var B = filled(true, 2, 2)
B[1, 0] = false
printf("%d %d %d %d\\n", B[0, 0], B[1, 0], B[0, 1], B[1, 1])
let x = A[1, 2] + v[3]
printf("%g\\n", x)
''', '''0 0.5 1 1.5
0 1 4 9
0 1 0
bool ok
0 1 10 11 20 21
-5 9223372036854775807 0
1 0 1 1
22.5
''')

# $ (5.3) is the extent of the dimension it indexes; v has 5 elements 0..4 (v[i] = i), A is 3 x 4
# with A[i, j] = i + 10 j: v[$ - 1] = 4, v[$ - 5] = 0, A[$ - 1, 0] = A[2, 0] = 2, A[0, $ - 1] =
# A[0, 3] = 30, A[$ - 1, $ - 2] = A[2, 2] = 22; in v[w[$ - 1]] the $ is len(w) = 3, w[2] = 4, v[4]
# = 4; the store v[$ - 2] = 9 sets v[3]; A[$ - 1, $ - 1] += 1 makes A[2, 3] = 32 + 1 = 33.
prog('arr_dollar', ['$ in each dimension, in an arithmetic index, nested, in a store and in a compound',
                    'store (LANGUAGE.md 5.3)'], '''var v = zeros(5)
for i in 0..5 {
    v[i] = f64(i)
}
var A = zeros(3, 4)
for j in 0..4 {
    for i in 0..3 {
        A[i, j] = f64(i + 10 * j)
    }
}
printf("%g %g\\n", v[$ - 1], v[$ - 5])
printf("%g %g %g\\n", A[$ - 1, 0], A[0, $ - 1], A[$ - 1, $ - 2])
var w = filled(0, 3)
w[2] = 4
printf("%g\\n", v[w[$ - 1]])
v[$ - 2] = 9.0
printf("%g %g\\n", v[3], v[$ - 2])
A[$ - 1, $ - 1] += 1.0
printf("%g\\n", A[2, 3])
''', '''4 0
2 30 22
4
9 9
33
''')

# INDEX_OOB (5.4, 9.2): `index %d out of bounds for dimension %d of extent %d`, the dimension
# counted from 0 (0: a vector's only dimension and a matrix's rows, 1: the columns).
OOB = 'index %d out of bounds for dimension %d of extent %d'
err_rt('err_rt_arr_oob_neg', ['v[-1] is an error, not the last element (LANGUAGE.md 5.4)'],
       '''let v = zeros(3)
printf("%g\\n", v[-1])
''', 'v[-1]', OOB % (-1, 0, 3))
err_rt('err_rt_arr_oob_ext', ['v[3] of a 3-element vector: the extent is out of range (LANGUAGE.md 5.4)'],
       '''let v = ones(3)
printf("%g\\n", v[2])
printf("%g\\n", v[3])
''', 'v[3]', OOB % (3, 0, 3), '1\n')
err_rt('err_rt_arr_oob_row_neg', ['A[-1, 0]: dimension 0 (the rows) of a 2 x 3 matrix (LANGUAGE.md 5.4)'],
       '''let A = zeros(2, 3)
let x = A[-1, 0]
''', 'A[-1, 0]', OOB % (-1, 0, 2))
err_rt('err_rt_arr_oob_row_ext', ['A[2, 1] of a 2 x 3 matrix: the row extent 2 (LANGUAGE.md 5.4)'],
       '''let A = zeros(2, 3)
let x = A[2, 1]
''', 'A[2, 1]', OOB % (2, 0, 2))
err_rt('err_rt_arr_oob_col_neg', ['A[0, -1]: dimension 1 (the columns) of a 2 x 3 matrix (LANGUAGE.md 5.4)'],
       '''let A = zeros(2, 3)
let x = A[0, -1]
''', 'A[0, -1]', OOB % (-1, 1, 3))
err_rt('err_rt_arr_oob_col_ext', ['A[1, 3] of a 2 x 3 matrix: the column extent 3 (LANGUAGE.md 5.4)'],
       '''var A = zeros(2, 3)
A[1, 3] = 1.0
''', 'A[1, 3]', OOB % (3, 1, 3))
# C1: every index is evaluated (left to right) before any is checked, then the checks run left to
# right: ix(5) and ix(-1) both print, then row index 5 fails first.
err_rt('err_rt_arr_oob_order', ['all indices are evaluated before any check; the first failing check left to',
                                'right is reported (LANGUAGE.md 5.4, C1)'],
       '''fn ix(k: i64) -> i64 {
    printf("ix %d\\n", k)
    return k
}
let A = zeros(2, 3)
let x = A[ix(5), ix(-1)]
let y = A[ix(0), ix(0)]
''', 'let x = A[', OOB % (5, 0, 2), 'ix 5\nix -1\n')
# 5.5 (C4): `=` evaluates the value, then the indices left to right, then checks: val, ix 1, ix 3,
# then the column index 3 fails.
err_rt('err_rt_arr_oob_store_order', ['an element store evaluates the value, then the indices, then checks',
                                      '(LANGUAGE.md 5.5, C4)'],
       '''fn ix(k: i64) -> i64 {
    printf("ix %d\\n", k)
    return k
}
fn val() -> f64 {
    printf("val\\n")
    return 1.0
}
var A = zeros(2, 3)
A[ix(1), ix(3)] = val()
''', 'A[ix(1), ix(3)] = val()', OOB % (3, 1, 3), 'val\nix 1\nix 3\n')
# 5.5 (C6) / 7.3: `x[i] op= e` evaluates the index, reads the element (with its check), then e: the
# read of v[5] fails before val() runs.
err_rt('err_rt_arr_oob_compound_order', ['a compound element store checks its read before it evaluates the value',
                                         '(LANGUAGE.md 5.5 C6, 7.3)'],
       '''fn ix(k: i64) -> i64 {
    printf("ix %d\\n", k)
    return k
}
fn val() -> f64 {
    printf("val\\n")
    return 1.0
}
var v = zeros(3)
v[ix(5)] += val()
''', 'v[ix(5)] += val()', OOB % (5, 0, 3), 'ix 5\n')

# ================================================================ compound element assignment
# v = [1, 2, 3]: v[0] += 2 -> 3, v[1] -= 0.5 -> 1.5, v[2] *= 4 -> 12, v[2] /= 8 -> 1.5; i64 elements
# [10, 10] with checked arithmetic: iv[0] = 10 + 5 = 15, iv[1] = 10 - 20 = -10, then -10 * -3 = 30;
# A[1, 0] += A[0, 1] reads both: A[0, 1] = 7, A[1, 0] = 1 + 7 = 8; iv[0] += iv[1] = 15 + 30 = 45.
# 5.5: v[sel] op= e is v[sel] = v[sel] op e.
prog('arr_compound', ['compound element assignment += -= *= /= on f64[], i64[] and f64[,] (LANGUAGE.md',
                      '5.5, 7.3)'], '''var v = filled(1.0, 3)
v[1] = 2.0
v[2] = 3.0
v[0] += 2.0
v[1] -= 0.5
v[2] *= 4.0
printf("%g %g %g\\n", v[0], v[1], v[2])
v[2] /= 8.0
printf("%g\\n", v[2])
var iv = filled(10, 2)
iv[0] += 5
iv[1] -= 20
iv[1] *= -3
printf("%d %d\\n", iv[0], iv[1])
var A = ones(2, 2)
A[0, 1] = 7.0
A[1, 0] += A[0, 1]
printf("%g %g\\n", A[1, 0], A[0, 1])
var k = 0
iv[k] += iv[k + 1]
printf("%d\\n", iv[0])
''', '''3 1.5 12
1.5
15 30
8 7
45
''')
err_rt('err_rt_arr_compound_ovf', ['an i64 compound element store overflows: integer overflow at its line',
                                   '(LANGUAGE.md 6.5, 5.5)'],
       '''var iv = filled(9223372036854775807, 2)
iv[0] -= 1
printf("%d\\n", iv[0])
iv[1] += 1
''', 'iv[1] += 1', 'integer overflow', '9223372036854775806\n')

# A compound store whose value replaces the array through a ref argument: the read sees the old
# element (1), e = 1.0, and the store goes to the new array (LANGUAGE.md 5.5: "a ref argument in e
# that changes x is seen by the store, not by the read"): v = [2, 10].
prog('arr_compound_ref', ['v[0] += g(ref v) where g replaces v: the read sees the old array, the store',
                          'the new one (LANGUAGE.md 5.5, 7.3, 8.3)'], '''fn repl(ref v: f64[]) -> f64 {
    v = filled(10.0, 2)
    return 1.0
}
var v = ones(1)
v[0] += repl(ref v)
printf("%d %g %g\\n", len(v), v[0], v[1])
v[1] += repl(ref v)
printf("%d %g %g\\n", len(v), v[0], v[1])
''', '''2 2 10
2 10 11
''')
err_rt('err_rt_arr_compound_ref_empty', ['v[0] += g(ref v) where g empties v: the store\'s repeated check fails',
                                         '(LANGUAGE.md 5.5, 8.3; DESIGN.md 3.6.6 rule 19)'],
       '''fn empty(ref v: f64[]) -> f64 {
    v = zeros(0)
    return 1.0
}
var v = ones(1)
v[0] += empty(ref v)
''', 'v[0] += empty', OOB % (0, 0, 0))

# ================================================================ locals, parameters, results
# total(v) sums in index order: [0, 1, 2] -> 3; scaled(v, 2) returns a new array [0, 2, 4]; split
# returns (the first half, the second half) of [0, 1, 2, 3]: lengths 2 and 2, elements 0 1 / 2 3;
# the same array may be both results (dup); a matrix parameter and result (tr: the transpose by
# loops) of a 2 x 3 matrix A[i, j] = i + 10 j: tr is 3 x 2 with T[2, 1] = A[1, 2] = 21.
prog('arr_locals_params', ['arrays as let and var locals, ordinary parameters, results (one and several),',
                           'matrices (LANGUAGE.md 4.5, 8.2, 8.4)'], '''fn total(v: f64[]) -> f64 {
    var s = 0.0
    for i in 0..len(v) {
        s += v[i]
    }
    return s
}
fn scaled(v: f64[], c: f64) -> f64[] {
    var w = zeros(len(v))
    for i in 0..len(v) {
        w[i] = c * v[i]
    }
    return w
}
fn split(v: f64[]) -> (f64[], f64[]) {
    let h = len(v) / 2
    var a = zeros(i64(h))
    var b = zeros(len(v) - i64(h))
    for i in 0..len(v) {
        if f64(i) < h {
            a[i] = v[i]
        } else {
            b[i - i64(h)] = v[i]
        }
    }
    return (a, b)
}
fn dup(v: i64[]) -> (i64[], i64[]) {
    return (v, v)
}
fn tr(A: f64[,]) -> f64[,] {
    var T = zeros(cols(A), rows(A))
    for i in 0..rows(A) {
        for j in 0..cols(A) {
            T[j, i] = A[i, j]
        }
    }
    return T
}
var v = zeros(3)
for i in 0..3 {
    v[i] = f64(i)
}
printf("%g\\n", total(v))
let w = scaled(v, 2.0)
printf("%g %g %g %g\\n", w[0], w[1], w[2], total(w))
var u = zeros(4)
for i in 0..4 {
    u[i] = f64(i)
}
let (p, q) = split(u)
printf("%d %d %g %g %g %g\\n", len(p), len(q), p[0], p[1], q[0], q[1])
let (d1, d2) = dup(filled(3, 2))
printf("%d %d\\n", d1[0], d2[1])
var A = zeros(2, 3)
for j in 0..3 {
    for i in 0..2 {
        A[i, j] = f64(i + 10 * j)
    }
}
let T = tr(A)
printf("%d %d %g %g\\n", rows(T), cols(T), T[2, 1], T[1, 0])
var x = v
x = scaled(x, 10.0)
printf("%g %g\\n", x[2], v[2])
''', '''3
0 2 4 6
2 2 0 1 2 3
3 3
3 2 21 10
20 2
''')

# ================================================================ ref parameters (8.3)
# set0 stores through ref into a shared buffer (b shares a's after `let b = a`): copy on write
# copies it, so a = [5, 1, 1] and b stays [1, 1, 1]; resize assigns a whole new array through ref:
# the caller's c becomes length 5; a ref parameter passed on (pass) reaches the same variable.
prog('arr_ref_param', ['ref array parameters: an element store through ref copies a shared array (the',
                       "caller's other variable unchanged), a whole-array store, a ref passed on (LANGUAGE.md 8.3, 4.5)"],
     '''fn set0(ref v: f64[], x: f64) {
    v[0] = x
}
fn resize(ref v: f64[], n: i64) {
    v = filled(f64(n), n)
}
fn pass(ref v: f64[], x: f64) {
    set0(ref v, x)
    v[1] += 1.0
}
var a = ones(3)
let b = a
set0(ref a, 5.0)
printf("%g %g %g / %g %g %g\\n", a[0], a[1], a[2], b[0], b[1], b[2])
var c = zeros(2)
resize(ref c, 5)
printf("%d %g\\n", len(c), c[4])
pass(ref a, 7.0)
printf("%g %g %g\\n", a[0], a[1], b[1])
var m = zeros(2, 2)
var n = m
fn setm(ref A: f64[,]) {
    A[1, 1] = 4.0
}
setm(ref m)
printf("%g %g\\n", m[1, 1], n[1, 1])
''', '''5 1 1 / 1 1 1
5 5
7 2 1
4 0
''')

# ================================================================ element loops (7.5)
# The vector is evaluated once and held: reassigning v in the body does not change the elements
# visited (1, 2, 3: s = 6, n = 3) and v ends as zeros(1); loops over i64[], bool[], an empty vector
# (no iteration) and a fresh vector (zeros(3): three +0 elements).
prog('arr_fore', ['for over a vector: the vector is held (reassigning its variable in the body does not',
                  'change the iteration); i64[], bool[], empty and fresh vectors (LANGUAGE.md 7.5)'],
     '''var v = filled(1.0, 3)
v[1] = 2.0
v[2] = 3.0
var s = 0.0
var n = 0
for x in v {
    v = zeros(1)
    s += x
    n += 1
}
printf("%g %d %d\\n", s, n, len(v))
var iv = filled(0, 4)
for i in 0..4 {
    iv[i] = 10 * i
}
var t = 0
for k in iv {
    t += k
}
printf("%d\\n", t)
var bv = filled(false, 3)
bv[2] = true
var nt = 0
for b in bv {
    if b {
        nt += 1
    }
}
printf("%d\\n", nt)
for x in zeros(0) {
    printf("never\\n")
}
var c = 0
for x in zeros(3) {
    c += 1
    printf("%g ", x)
}
printf("%d\\n", c)
''', '''6 3 1
60
1
0 0 0 3
''')

# ================================================================ copy on write (4.5, 8.2)
# var b = a; b[0] = 1 leaves a = [2, 2, 2]; c = b then a loop of stores into c (the first store
# copies, the others write c's own buffer): c = [0, 10, 20], b unchanged [1, 2, 2]; a function that
# copies its parameter into a var and writes it leaves the caller's array; a matrix the same.
prog('arr_cow', ['copy on write: var b = a; b[0] = 1.0 leaves a; a store in a loop copies once; a var',
                 'copy of a parameter; a matrix (LANGUAGE.md 4.5, 8.2)'], '''let a = filled(2.0, 3)
var b = a
b[0] = 1.0
printf("%g %g / %g %g\\n", a[0], a[1], b[0], b[1])
var c = b
for i in 0..3 {
    c[i] = f64(i) * 10.0
}
printf("%g %g %g / %g %g %g\\n", c[0], c[1], c[2], b[0], b[1], b[2])
fn bumped(v: f64[]) -> f64[] {
    var w = v
    w[0] += 1.0
    return w
}
let d = bumped(a)
printf("%g %g\\n", d[0], a[0])
let M = ones(2, 2)
var N = M
N[0, 1] = 5.0
printf("%g %g\\n", M[0, 1], N[0, 1])
var e = c
e[2] = -1.0
e[2] = -2.0
printf("%g %g\\n", e[2], c[2])
''', '''2 2 / 1 2
0 10 20 / 1 2 2
3 2
1 5
-2 20
''')

# ================================================================ nested ref calls (8.3; rules 12, 31)
# f(a, g(ref a)): f's first argument is read before g replaces a, so f sees the old [1, 1, 1]:
# 1 + 3 + 0.5 = 4.5; afterwards a = [9].
prog('arr_ref_nested_old', ['f(a, g(ref a)) where g replaces a: f sees the old array (LANGUAGE.md 6.8 rule 5,',
                            '8.3; DESIGN.md 3.6.6 rule 12 (a)), and nothing leaks'], '''fn g(ref v: f64[]) -> f64 {
    v = filled(9.0, 1)
    return 0.5
}
fn f(old: f64[], x: f64) -> f64 {
    return old[0] + f64(len(old)) + x
}
var a = ones(3)
let r = f(a, g(ref a))
printf("%g %d %g\\n", r, len(a), a[0])
let r2 = f(a, g(ref a))
printf("%g %d %g\\n", r2, len(a), a[0])
''', '''4.5 1 9
10.5 1 9
''')
# f(ref x, g(ref x)) with an i64: the deferred ref argument stores x after g ran (rule 31), so fi
# sees 11: k = 11 * 2 + 1 = 23. With an f64[] local: fa sees g's zeros(4) and writes b[2] = 7.
prog('arr_ref_nested_var', ['f(ref x, g(ref x)) for an i64 and an f64[] local: f sees g\'s update (LANGUAGE.md',
                            '8.3; DESIGN.md 3.6.6 rule 31, deferred ref arguments)'], '''fn gi(ref x: i64) -> i64 {
    x = x + 10
    return 1
}
fn fi(ref x: i64, d: i64) {
    x = x * 2 + d
}
var k = 1
fi(ref k, gi(ref k))
printf("%d\\n", k)
fn ga(ref v: f64[]) -> i64 {
    v = zeros(4)
    return 2
}
fn fa(ref v: f64[], i: i64) {
    v[i] = 7.0
}
var b = ones(2)
fa(ref b, ga(ref b))
printf("%d %g %g\\n", len(b), b[2], b[0])
''', '''23
4 7 0
''')
# f(ref v[0], g(ref v)) where g replaces v by a longer array: the element path is checked at its
# place (0 < 2), then again with the new extent after g, and f updates the new array's element 0:
# 3 + 1.5 = 4.5; w = [4.5, 3, 3, 3, 3]. The matrix m[1, 1] (checked against the old 2 x 2 at its
# place) is then the new 3 x 3 matrix's element: 1 + 2 = 3, m[2, 2] = 1.
prog('arr_ref_nested_elem', ['f(ref v[0], g(ref v)) where g replaces v by a longer array: f writes the new',
                             "array's element 0 (LANGUAGE.md 8.3; DESIGN.md 3.6.6 rule 31)"], '''fn grow(ref v: f64[]) -> f64 {
    v = filled(3.0, 5)
    return 1.5
}
fn put(ref e: f64, x: f64) {
    e = e + x
}
var w = ones(2)
put(ref w[0], grow(ref w))
printf("%d %g %g %g\\n", len(w), w[0], w[1], w[4])
var m = zeros(2, 2)
fn growm(ref A: f64[,]) -> f64 {
    A = filled(1.0, 3, 3)
    return 2.0
}
put(ref m[1, 1], growm(ref m))
printf("%d %g %g\\n", rows(m), m[1, 1], m[2, 2])
''', '''5 4.5 3 3
3 3 1
''')
err_rt('err_rt_arr_ref_nested_empty', ['f(ref v[0], g(ref v)) where g empties v: INDEX_OOB at the call\'s line',
                                       '(DESIGN.md 3.6.6 rule 31; LANGUAGE.md 5.4)'],
       '''fn shrink(ref v: f64[]) -> f64 {
    v = zeros(0)
    return 1.5
}
fn put(ref e: f64, x: f64) {
    e = e + x
}
var w = ones(2)
printf("%d\\n", len(w))
put(ref w[0], shrink(ref w))
''', 'put(ref w[0], shrink', OOB % (0, 0, 0), '2\n')

# ================================================================ exact math on scalars (10.4, 6.7)
# f64: abs clears the sign (abs(-0) = 0, abs(-inf) = Inf, abs(NaN) = NaN, never signed in printf,
# 11.1); sign is 1 / -1 / x itself (sign(-0.0) prints -0, sign(NaN) NaN); sqrt correctly rounded
# (sqrt(-0) = -0, sqrt(-1) = NaN, sqrt(inf) = Inf, sqrt(2) = 1.4142135623730951 with %.17g); floor
# ceil trunc round (round ties away: 2.5 -> 3, -2.5 -> -3, 0.49999999999999994 -> 0, -0.4 -> -0;
# ceil(-0.5) = -0); isnan; min/max: a NaN operand gives the other, equal operands the first
# (min(-0, 0) = -0, min(0, -0) = 0, max(-0, 0) = -0), an i64 with an f64 converts; where on scalars.
prog('arr_math_f64', ['the scalar exact math functions on f64 with +-0, NaN and +-inf (LANGUAGE.md 10.4,',
                      '6.7, 11.1)'], '''let pz = 0.0
let nz = -0.0
let pinf = inf
let ninf = -inf
let qn = nan
printf("%g %g %g %g %g\\n", abs(nz), abs(ninf), abs(-2.5), abs(qn), abs(3.0))
printf("%g %g %g %g %g %g\\n", sign(nz), sign(pz), sign(-3.5), sign(ninf), sign(qn), sign(pinf))
printf("%g %g %g %g %.17g\\n", sqrt(nz), sqrt(4.0), sqrt(-1.0), sqrt(pinf), sqrt(2.0))
printf("%g %g %g %g\\n", floor(-0.5), ceil(-0.5), trunc(-2.7), trunc(nz))
printf("%g %g %g %g\\n", round(2.5), round(-2.5), round(0.49999999999999994), round(-0.4))
printf("%g %g %g %g\\n", floor(pinf), ceil(qn), round(ninf), floor(2.0))
printf("%d %d %d\\n", isnan(qn), isnan(pinf), isnan(nz))
printf("%g %g %g\\n", min(1.0, qn), min(qn, 2.0), max(qn, qn))
printf("%g %g %g %g\\n", min(nz, pz), min(pz, nz), max(nz, pz), max(pz, nz))
printf("%g %g %g\\n", max(ninf, 3.0), min(2, 3.5), max(2, 3.5))
printf("%g %d %d\\n", where(true, 1.5, 2.5), where(false, 1, 2), where(1 > 2, true, false))
printf("%g\\n", where(pinf > 0.0, 1, 2.5))
''', '''0 Inf 2.5 NaN 3
-0 0 -1 -1 NaN 1
-0 2 NaN Inf 1.4142135623730951
-1 -0 -2 -0
3 -3 0 -0
Inf NaN -Inf 2
1 0 0
1 2 NaN
-0 0 -0 0
3 2 3.5
1.5 2 0
1
''')
# i64: abs and sign exact; abs(2^63 - 1) = 2^63 - 1, abs(-(2^63 - 1)) = 2^63 - 1; min/max of i64 and
# -2^63; abs(-2^63) is integer overflow (err_rt_arr_abs_min).
prog('arr_math_i64', ['abs, sign, min, max on i64 including the edge values (LANGUAGE.md 10.4)'],
     '''let lo = -9223372036854775807 - 1
let hi = 9223372036854775807
printf("%d %d %d %d\\n", abs(-5), abs(0), abs(hi), abs(-hi))
printf("%d %d %d %d %d\\n", sign(-7), sign(0), sign(42), sign(lo), sign(hi))
printf("%d %d %d %d\\n", min(3, -4), max(3, -4), min(lo, 0), max(lo, hi))
printf("%d %d\\n", min(lo, lo), max(hi, hi))
''', '''5 0 9223372036854775807 9223372036854775807
-1 0 1 -1 1
-4 3 -9223372036854775808 9223372036854775807
-9223372036854775808 9223372036854775807
''')
err_rt('err_rt_arr_abs_min', ['abs(-2^63) of an i64 is integer overflow (LANGUAGE.md 10.4, 6.5)'],
       '''let m = -9223372036854775808
printf("%d\\n", abs(m + 1))
printf("%d\\n", abs(m))
''', 'abs(m))', 'integer overflow', '9223372036854775807\n')

# ================================================================ index utilities (10.7)
# ind2sub(r, k) = (k % r, idiv(k, r)), floored (6.6): (3, 7) -> (1, 2); (4, 0) -> (0, 0); (3, -1)
# -> (2, -1); sub2ind(r, i, j) = i + j r with i checked against r: (3, 1, 2) -> 7, (3, 2, 0) -> 2,
# (5, 0, 4) -> 20.
prog('arr_index_util', ['ind2sub and sub2ind on scalars (LANGUAGE.md 10.7, 6.6)'], '''let (i, j) = ind2sub(3, 7)
printf("%d %d\\n", i, j)
let (a, b) = ind2sub(4, 0)
printf("%d %d\\n", a, b)
let (c, d) = ind2sub(3, -1)
printf("%d %d\\n", c, d)
printf("%d %d %d\\n", sub2ind(3, 1, 2), sub2ind(3, 2, 0), sub2ind(5, 0, 4))
var A = zeros(3, 4)
A[2, 3] = 1.0
let (r, s) = ind2sub(rows(A), sub2ind(rows(A), 2, 3))
printf("%d %d %g\\n", r, s, A[r, s])
''', '''1 2
0 0
2 -1
7 2 20
2 3 1
''')
err_rt('err_rt_arr_sub2ind_oob', ['sub2ind(r, i, j) checks i against r: INDEX_OOB, dimension 0 (LANGUAGE.md',
                                  '10.7, 5.4)'],
       '''let r = 3
printf("%d\\n", sub2ind(r, 2, 1))
printf("%d\\n", sub2ind(r, 3, 0))
''', 'sub2ind(r, 3, 0)', OOB % (3, 0, 3), '5\n')
err_rt('err_rt_arr_ind2sub_zero', ['ind2sub(0, k) divides by zero (LANGUAGE.md 10.7, 6.6)'],
       '''let r = 0
let (i, j) = ind2sub(r, 5)
printf("%d %d\\n", i, j)
''', 'ind2sub(r, 5)', 'integer division by zero')

# a ref call inside an assignment target's own index (LANGUAGE.md 5.5 C4, C6; 7.3): the value (for
# `=`), then the target's indices, then the checks against the variable as it is then; a tasg runs its
# call first, then each target in order (7.3). grow3 makes its argument filled(2.0, 4) and returns 3.
# g[grow3(ref g)] = 5.0: g = [2, 2, 2, 2], g[3] = 5 -> "4 5 2". h[grow3(ref h)] += 1.0: the index
# first (h = [2, 2, 2, 2]), then the read h[3] = 2, 2 + 1 = 3 -> "4 3". (c[grow3(ref c)], d) =
# two(ref d): two makes d filled(3.0, 5) and returns (4, zeros(2)); then c[grow3(ref c)] = 4 (i64 to
# f64, 4.2 (b)) with c = [2, 2, 2, 2], then d = zeros(2) -> "4 4 2". viaref does the `=` case
# through a ref parameter p: r = [2, 2, 2, 5] -> "4 5". The heap check finds nothing live.
prog('arr_ref_in_target', ["a ref call in an assignment target's own index: the checks and the store use",
                           'the variable as the call left it (LANGUAGE.md 5.5, 7.3; DESIGN.md 3.6.6 rule 12)'], '''fn grow3(ref v: f64[]) -> i64 {
    v = filled(2.0, 4)
    return 3
}
fn two(ref v: f64[]) -> (i64, f64[]) {
    v = filled(3.0, 5)
    return (4, zeros(2))
}
fn viaref(ref p: f64[]) {
    p[grow3(ref p)] = 5.0
}
var g = ones(2)
g[grow3(ref g)] = 5.0
printf("%d %g %g\\n", len(g), g[3], g[0])
var h = ones(2)
h[grow3(ref h)] += 1.0
printf("%d %g\\n", len(h), h[3])
var c = ones(2)
var d = ones(2)
(c[grow3(ref c)], d) = two(ref d)
printf("%d %g %d\\n", len(c), c[3], len(d))
var r = ones(2)
viaref(ref r)
printf("%d %g\\n", len(r), r[3])
''', '''4 5 2
4 3
4 4 2
4 5
''')
# shrink makes h zeros(1) and returns 1: the value 5.0, the index 1, then the check against h as it
# is now (extent 1): INDEX_OOB, dimension 0 (5.4, 5.5 C4); the first printf ran ("2").
err_rt('err_rt_arr_ref_in_target_shrink', ["a ref call in an assignment target's index shrinks the array:",
                                           'the check uses the new extent (LANGUAGE.md 5.5, 5.4)'],
       '''fn shrink(ref v: f64[]) -> i64 {
    v = zeros(1)
    return 1
}
var h = ones(2)
printf("%d\\n", len(h))
h[shrink(ref h)] = 5.0
printf("%d\\n", len(h))
''', 'h[shrink(ref h)]', OOB % (1, 0, 1), '2\n')
# a tuple assignment from ind2sub (10.7: i = k mod r, j = k div r, floored): (3, 7) gives (1, 2); to
# elements of an f64[] the i64 results are converted (4.2 (b)): 1, 2; (4, 10) gives (2, 2), so
# w[2] = 2 and e = 2, w[0] stays 0; (3, -1) gives (2, -1), the first dropped by _, f = -1.
prog('arr_tasg_lib', ['a tuple assignment from ind2sub to scalars, to elements and with _',
                      '(LANGUAGE.md 10.7, 7.3, 4.2)'], '''var e = 0
var f = 0
(e, f) = ind2sub(3, 7)
printf("%d %d\\n", e, f)
var a = zeros(2)
(a[0], a[1]) = ind2sub(3, 7)
printf("%g %g\\n", a[0], a[1])
var w = filled(0, 3)
(w[2], e) = ind2sub(4, 10)
printf("%d %d %d\\n", w[2], e, w[0])
(_, f) = ind2sub(3, -1)
printf("%d\\n", f)
''', '''1 2
1 2
2 2 0
-1
''')

# ================================================================ heap: every exit path (7.7)
# Each program allocates array locals on the exit path it names; the runner's heap check (DESIGN.md
# 6.2, SEA_HEAP_CHECK=1) fails the test if any is not released.
prog('heap_break', ['array locals of the blocks a break leaves are released (LANGUAGE.md 7.7; DESIGN.md',
                    '3.6.6 rule 16 (b))'], '''var total = 0.0
var k = 0
while true {
    let v = filled(1.0, 4)
    if k == 2 {
        let w = zeros(3)
        if w[0] == 0.0 {
            let x = ones(2)
            break
        }
    }
    total += v[0]
    k += 1
}
printf("%g %d\\n", total, k)
for i in 0..10 {
    let a = zeros(i + 1)
    for j in 0..10 {
        let b = ones(j + 1)
        if j == 1 {
            break
        }
    }
    if i == 2 {
        break
    }
}
printf("done\\n")
''', '''2 2
done
''')
prog('heap_continue', ['array locals of the blocks a continue leaves are released (LANGUAGE.md 7.7;',
                       'DESIGN.md 3.6.6 rule 16 (b))'], '''var s = 0.0
for i in 0..4 {
    let v = filled(f64(i), 2)
    if i % 2 == 0 {
        let w = ones(1)
        continue
    }
    s += v[1]
}
printf("%g\\n", s)
var n = 0
while n < 3 {
    let a = zeros(2)
    n += 1
    if n == 2 {
        let b = zeros(1)
        continue
    }
    printf("n %d\\n", n)
}
''', '''4
n 1
n 3
''')
# findpair(5): the first i * j == 6 with j < i is i = 3, j = 2 -> 32; findpair(3): none -> -1.
prog('heap_return', ['a return from nested blocks and loops releases every enclosing array local',
                     '(LANGUAGE.md 7.7; DESIGN.md 3.6.6 rule 16 (c))'], '''fn findpair(n: i64) -> i64 {
    let a = zeros(n)
    for i in 0..n {
        let b = ones(i + 1)
        for j in 0..i {
            let c = filled(j, 2)
            if i * j == 6 {
                let d = zeros(1)
                return i * 10 + j
            }
        }
    }
    return -1
}
fn early(c: bool) -> f64 {
    let a = ones(2)
    if c {
        let b = zeros(2)
        return b[0]
    }
    return a[0]
}
printf("%d %d\\n", findpair(5), findpair(3))
printf("%g %g\\n", early(true), early(false))
''', '''32 -1
0 1
''')
prog('heap_pick', ['a function returning one of two array locals: the returned one survives, the other is',
                   'released (LANGUAGE.md 7.7; DESIGN.md 3.6.6 rules 15 (a), 16 (c))'], '''fn pick(c: bool) -> f64[] {
    let a = filled(1.0, 2)
    let b = filled(2.0, 3)
    if c {
        return a
    }
    return b
}
fn first(c: bool, v: f64[], w: f64[]) -> f64[] {
    if c {
        return v
    }
    return w
}
let x = pick(true)
let y = pick(false)
printf("%d %d %g %g\\n", len(x), len(y), x[0], y[0])
let z = first(false, x, y)
printf("%d\\n", len(z))
printf("%d\\n", len(first(true, pick(false), pick(true))))
''', '''2 3 1 2
3
3
''')
# for x in v (v = [0, 0, -1, 0]): firstneg returns 2 from inside the loop (the held vector released
# by the return), the break leaves after 2 elements (the held vector released at the end of the loop
# construct), the continue keeps iterating over a fresh vector.
prog('heap_fore_exit', ['the vector an element loop holds is released after the loop, by a return inside it,',
                        'and not twice on break or continue (LANGUAGE.md 7.5, 7.7; DESIGN.md 3.6.6 rules 16 (f), 30)'],
     '''fn firstneg(v: f64[]) -> i64 {
    var k = 0
    for x in v {
        let t = zeros(1)
        if x < 0.0 {
            return k
        }
        k += 1
    }
    return -1
}
var v = zeros(4)
v[2] = -1.0
printf("%d %d\\n", firstneg(v), firstneg(zeros(2)))
var n = 0
for x in v {
    if x < 0.0 {
        break
    }
    n += 1
}
printf("%d\\n", n)
var m = 0
for x in ones(4) {
    m += 1
    if m % 2 == 1 {
        continue
    }
    printf("m %d\\n", m)
}
for x in v {
    for y in ones(2) {
        if x < 0.0 {
            break
        }
    }
}
printf("end\\n")
''', '''2 -1
2
m 2
m 4
end
''')
# Temporaries: an array result consumed by an index, by len, by a parameter, discarded by a call
# statement and by let _ (DESIGN.md 3.6.6 rule 15 (b), (h)).
prog('heap_temps', ['array temporaries: a call result indexed, measured, passed and discarded are released',
                    '(LANGUAGE.md 7.7; DESIGN.md 3.6.6 rule 15 (b), (h))'], '''fn make(n: i64) -> f64[] {
    var v = zeros(n)
    for i in 0..n {
        v[i] = f64(i) + 0.5
    }
    return v
}
fn total(v: f64[]) -> f64 {
    var s = 0.0
    for x in v {
        s += x
    }
    return s
}
printf("%g %d %g\\n", make(3)[1], len(make(4)), total(make(2)))
make(5)
let _ = make(6)
printf("%g %d\\n", ones(2)[0], numel(zeros(2, 3)))
fn two(n: i64) -> (f64[], i64[]) {
    return (zeros(n), filled(n, n))
}
let (a, _) = two(3)
let (_, b) = two(2)
printf("%d %d\\n", len(a), b[1])
two(1)
''', '''1.5 4 2
1 6
3 2
''')
# Reassignment releases the old value (rule 15 (d)); a = a keeps it alive (retain before release);
# a ref parameter's whole-array store releases the old array (rule 31).
prog('heap_reassign', ['assigning a new array to an array variable releases the old one, also a = a, in a',
                       'loop and through ref (LANGUAGE.md 7.7; DESIGN.md 3.6.6 rules 15 (d), 31)'], '''var a = zeros(3)
a = ones(2)
a = a
printf("%d %g\\n", len(a), a[1])
for i in 0..5 {
    a = filled(f64(i), i + 1)
}
printf("%d %g\\n", len(a), a[4])
fn reset(ref v: f64[], n: i64) {
    v = zeros(n)
    v = ones(n)
}
reset(ref a, 2)
printf("%d %g\\n", len(a), a[0])
let b = a
a = zeros(1)
printf("%d %d %g\\n", len(a), len(b), b[1])
var M = zeros(2, 2)
M = filled(3.0, 1, 1)
printf("%g\\n", M[0, 0])
''', '''2 1
5 4
2 1
1 2 1
3
''')
# if expressions of an array type: each arm owned (a fresh array moved, a borrowed local retained).
prog('heap_ifx', ['if expressions of an array type: fresh and borrowed arms (DESIGN.md 3.6.6 rules 3, 15 (b))'],
     '''fn choose(c: bool, v: f64[]) -> f64[] {
    return if c { v } else { ones(1) }
}
let z = zeros(2)
let a = if len(z) > 1 { z } else { ones(3) }
let b = if len(z) > 5 { z } else { ones(3) }
printf("%d %d\\n", len(a), len(b))
printf("%d %d\\n", len(choose(true, z)), len(choose(false, z)))
let c = if len(a) == 2 { filled(4.0, 1) } else { a }
printf("%g\\n", c[0])
''', '''2 3
2 1
4
''')

# The value of an element assignment is evaluated before its indices (LANGUAGE.md 5.5, 7.3; DESIGN.md
# 3.5.5 G1, 3.6.6 rule 12): v[bump(ref x)] = x stores x as it was (1), then bump makes x 11 and the
# index 1. A tuple assignment calls first, then its targets in order: (a, w[bump(ref k)]) = h2(k)
# calls h2(1) = (1, 2), a = 1, then the index bump(ref k) = 1 (k 11), w[1] = 2; (y, u[i]) = hr(ref i)
# calls hr (i becomes 1) = (5, 7), y = 5, then the index i reads 1, u[1] = 7, u[0] stays 0.
prog('arr_eval_order_ref', ['a ref call in the index of an element target runs after the value (asg) or after',
                            'the call (tasg) is evaluated (LANGUAGE.md 5.5, 7.3; DESIGN.md 3.5.5 G1, 3.6.6',
                            'rule 12)'],
     '''fn bump(ref s: f64) -> i64 {
    s = s + 10.0
    return 1
}
fn h2(n: f64) -> (f64, f64) {
    return (n, n * 2.0)
}
fn hr(ref j: i64) -> (f64, f64) {
    j = j + 1
    return (5.0, 7.0)
}
var v = zeros(3)
var x = 1.0
v[bump(ref x)] = x
printf("%g %g\\n", v[1], x)
var w = zeros(3)
var k = 1.0
var a = 0.0
(a, w[bump(ref k)]) = h2(k)
printf("%g %g %g\\n", a, w[1], k)
var u = zeros(2)
var i = 0
var y = 0.0
(y, u[i]) = hr(ref i)
printf("%g %g %g %d\\n", y, u[1], u[0], i)
''', '''1 11
1 2 11
5 7 0 1
''')
# Rule 12 (a): in return (b, g(ref b)) the read of b comes before the ref call, so it is copied and
# retained; g gives b a new zeros(5) and releases its count on the old array, which the copy keeps.
# The function returns the old array (3 elements, all 1.0) and 9, and releases b (the zeros(5)) on
# return: len(r) 3, c 9, r[0] 1; nothing is left on the heap.
prog('heap_rule12_stale', ['an array read before a ref call that replaces it is the old array, held by its',
                           'retained copy (DESIGN.md 3.6.6 rules 12 (a), 15, 16 (c))'],
     '''fn mk(n: i64) -> f64[] {
    return ones(n)
}
fn g(ref v: f64[]) -> i64 {
    v = zeros(5)
    return 9
}
fn k(n: i64) -> (f64[], i64) {
    var b = mk(n)
    return (b, g(ref b))
}
let (r, c) = k(3)
printf("%d %d %g\\n", len(r), c, r[0])
''', '''3 9 1
''')

# ================================================================ phase-rule errors of step 4d (2.6.2)
# (the eight `arrays` cases of 4d, err_ns_arr_{range_index,all_index,view,ew,elem_arg,max2,cvt,
# fixed_local}, were retired by step 4e: their programs compile from 4e, DESIGN.md 6.2 "4e";
# arr4e_cases.py deletes their goldens and tests the constructs instead)
NS = 'not supported yet: %s'
err_c('err_ns_lib_max1', ['4d: max(v) of one vector (a reduction, 4f) is still the name max, at the call',
                          '(DESIGN.md 2.6.2 step 4d)'],
      'let v = ones(3)\nprintf("%g\\n", max(v))\n', 'printf', 'max', NS % 'max')
err_c('err_ns_lib_min1', ['4d: min(v) of one vector is still the name min, at the call (DESIGN.md 2.6.2',
                          'step 4d)'],
      'let v = ones(3)\nlet m = min(v)\n', 'let m', 'min', NS % 'min')
err_c('err_ns_arr_str_elem', ['4d: str[] is still strings, at the parameter (DESIGN.md 2.6.2 step 4d)'],
      'fn f(s: str[]) -> i64 {\n    return 1\n}\n', 'fn f', 's: str[]', NS % 'strings')

print('arr4d_cases: %d programs, %d errors' % (COUNT['programs'], COUNT['errors']))
