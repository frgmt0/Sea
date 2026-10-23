"""Sub-phase 4g-1 corpus: programs/ and errors/ tests of strings, `match`, `error` and `args`
(DESIGN.md 6.2 "4g-1", 8 row 4g-1, work package T1a).

Run with `timeout 120 uv run --no-project python tests/vectors/str4g_cases.py`. It writes the
programs/str_*, programs/match_*, programs/args_*, programs/heap_str_* and programs/sort_str tests
(with their `.args` sidecars), the 4g-1 errors/ tests (r_str_*, r_args_*, r_error_*: run-time;
err_str_*, err_match_*, err_error_*, err_lower_*, err_args_*, err_const_str_*, err_ns_str_fixed_let:
compile time), re-derives the three Decision-25 goldens err_const_noval_{calltype,errtype,shortcircuit}
with an undeclared struct type `Q` in place of `str` (lead decision L-i), and deletes the five goldens
4g-1 retires (err_ns_string_let, err_ns_string_type, err_ns_str_literal, err_ns_arr_str_elem,
err_ns_match: their constructs compile from 4g-1 and are covered by the programs below). The goldens
err_ns_str_fixed_type, err_ns_struct and err_ns_record stay until 4g-2. (res_cases.py, arr4d_cases.py
and arr4e_cases.py still write their old versions of these goldens; run this script after them, as
arr4f_cases.py is run after arr4d_cases.py.)

Every expected byte is derived here from LANGUAGE.md 3.5, 4.4, 4.5, 4.8, 5, 6.2-6.4, 6.9, 6.10, 7.2,
7.3, 7.5, 7.6, 8.1-8.4, 9.1-9.4, 10.2, 10.6, 10.9, 10.10, 11.1 and, for messages, positions and orders,
DESIGN.md 2.6.2 (the error table and its `at` column, "Readings fixed by 4g", "Within one formatting
call", the phase-rule row 4g-1), 3.3 (node positions) and 3.4 (the AST node of each construct). The
model below is independent of the compiler: string values are Python `bytes`, decoded from the Sea
literal exactly as 3.5 says; `+` is bytes concatenation; the six comparisons are Python's bytes
comparison, which is byte-wise unsigned with a proper prefix the smaller and no blank padding (4.4);
`str(x)` of an i64 is its decimal digits, of an f64 C's `%.17g` (Python's `%` with `%.17g` rounds
correctly, as C99 does) and `nan`, `inf`, `-inf` for the non-finite values, of a bool `true`/`false`,
of a str the string itself (10.9); `lower` maps only the bytes A-Z (0x41-0x5A) to a-z (10.9); `%s`
pads with spaces to the width and truncates to the precision, both counted in bytes (11.1); sorting is
Python's stable `sorted` on bytes, descending with ties kept in input order (10.6, DESIGN.md 4.8
entry 21). The run-time error line of an errors/ test is the line holding its marker; a compile
error's column is that of its marker text inside that line (both computed from the source text).

Printing (v1 has no `print` until phase 6): `str` vectors through `ps` (`n:` and ` [s]` per element,
so empty strings and blanks are visible), `str` matrices through `pms` (`RxC`, ` |` per row, ` [s]`
per element), `bool` arrays through `pvb`/`pmb` (`%d` of a bool is 0 or 1, 11.1), `i64` vectors through
`pvi`.
"""

import functools
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
TESTS = os.path.dirname(HERE)
PROGRAMS = os.path.join(TESTS, 'programs')
ERRORS = os.path.join(TESTS, 'errors')
COUNT = {'programs': 0, 'errors': 0}


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
        assert len(ln.encode('ascii')) <= 4096, ln[:40]           # 3.1 line limit
        assert all(c == '\t' or 0x20 <= ord(c) < 0x7F for c in ln), ln  # 3.1: ASCII outside escapes
    return src


# ---------------------------------------------------------------------------- the model
def lit(s):
    """The bytes of a Sea string literal's contents (LANGUAGE.md 3.5): \\n \\t \\r \\0 \\\\ \\" \\xHH and
    \\u{H...} (UTF-8); every other byte is itself."""
    out = bytearray()
    i = 0
    while i < len(s):
        c = s[i]
        if c != '\\':
            out += c.encode('ascii')
            i += 1
            continue
        e = s[i + 1]
        if e in 'ntr0"\\':
            out += {'n': b'\n', 't': b'\t', 'r': b'\r', '0': b'\0', '"': b'"', '\\': b'\\'}[e]
            i += 2
        elif e == 'x':
            out.append(int(s[i + 2:i + 4], 16))
            i += 4
        elif e == 'u':
            j = s.index('}', i)
            out += chr(int(s[i + 3:j], 16)).encode('utf-8')
            i = j + 1
        else:
            raise AssertionError('invalid escape in a test literal')
    return bytes(out)


def q(b):
    """A Sea string literal denoting the bytes b (escapes for every byte outside 0x20-0x7E)."""
    r = '"'
    for c in b:
        ch = chr(c)
        if ch == '"':
            r += '\\"'
        elif ch == '\\':
            r += '\\\\'
        elif ch == '\n':
            r += '\\n'
        elif ch == '\t':
            r += '\\t'
        elif 0x20 <= c < 0x7F:
            r += ch
        else:
            r += '\\x%02X' % c
    r += '"'
    assert lit(r[1:-1]) == b
    return r


def lower(b):
    """10.9: ASCII lower case, only A-Z changed."""
    return bytes(c + 32 if 0x41 <= c <= 0x5A else c for c in b)


def str_i(n):
    return str(n).encode('ascii')


def str_f(x):
    """10.9: %.17g for a finite value, nan / inf / -inf (C's spelling) otherwise."""
    if math.isnan(x):
        return b'nan'
    if math.isinf(x):
        return b'inf' if x > 0 else b'-inf'
    return ('%.17g' % x).encode('ascii')


def str_b(v):
    return b'true' if v else b'false'


def pad(s, width=0, prec=None, left=False):
    """%s of 11.1: precision truncates to that many bytes, width pads with spaces (bytes)."""
    if prec is not None:
        s = s[:prec]
    fill = b' ' * max(0, width - len(s))
    return s + fill if left else fill + s


def d(v):
    """%d of a bool or an i64 (11.1)."""
    if isinstance(v, bool):
        return b'1' if v else b'0'
    return str(v).encode('ascii')


def cmp6(a, b):
    return b''.join(d(x) for x in (a == b, a != b, a < b, a <= b, a > b, a >= b))


def ps(v):
    return b'%d:' % len(v) + b''.join(b' [' + s + b']' for s in v)


def pms(rows):
    c = len(rows[0]) if rows else 0
    return b'%dx%d' % (len(rows), c) + b''.join(b' |' + b''.join(b' [' + s + b']' for s in r)
                                                 for r in rows)


def pvb(v):
    return b'%d:' % len(v) + b''.join(b' ' + d(x) for x in v)


def pmb(rows):
    c = len(rows[0]) if rows else 0
    return b'%dx%d' % (len(rows), c) + b''.join(b' |' + b''.join(b' ' + d(x) for x in r) for r in rows)


def pvi(v):
    return b'%d:' % len(v) + b''.join(b' %d' % x for x in v)


def argsort(v, desc=False):
    """10.6: stable; descending keeps equal elements in input order (not a reversed ascending order)."""
    if not desc:
        return sorted(range(len(v)), key=lambda i: v[i])
    return sorted(range(len(v)), key=functools.cmp_to_key(lambda i, j: (v[j] > v[i]) - (v[j] < v[i])))


def ew(f, a, b):
    """Element-wise with the broadcasting of 6.3 (matrices as lists of rows; a scalar is bytes)."""
    if isinstance(a, bytes) and isinstance(b, bytes):
        return f(a, b)
    if isinstance(a, bytes):
        return [ew(f, a, y) for y in b]
    if isinstance(b, bytes):
        return [ew(f, x, b) for x in a]
    assert len(a) == len(b) or len(a) == 1 or len(b) == 1
    n = max(len(a), len(b))
    return [ew(f, a[0 if len(a) == 1 else i], b[0 if len(b) == 1 else i]) for i in range(n)]


def col(v):
    return [[x] for x in v]


def row(v):
    return [list(v)]


# ---------------------------------------------------------------------------- printing helpers
HELPERS = {
    'ps': r'''fn ps(v: str[]) {
    printf("%d:", len(v))
    for s in v {
        printf(" [%s]", s)
    }
    printf("\n")
}
''',
    'pms': r'''fn pms(A: str[,]) {
    printf("%dx%d", rows(A), cols(A))
    for i in 0..rows(A) {
        printf(" |")
        for j in 0..cols(A) {
            printf(" [%s]", A[i, j])
        }
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
    'pvi': r'''fn pvi(v: i64[]) {
    printf("%d:", len(v))
    for x in v {
        printf(" %d", x)
    }
    printf("\n")
}
''',
}


def prog(name, comment, helpers, steps, fns='', argv=None):
    """A programs/ test. steps: (code, expected) pairs in program order; expected is the bytes the
    code prints, lines separated by LF, without the final LF (None: prints nothing). argv: the
    lines of NAME.args (one argument per line), or None for no sidecar."""
    body = ''.join(HELPERS[h] for h in helpers) + fns
    body += ''.join(code + '\n' for code, _ in steps)
    out = b''.join(o + b'\n' for _, o in steps if o is not None)
    write(os.path.join(PROGRAMS, name + '.sea'), source(name, comment, body))
    write(os.path.join(PROGRAMS, name + '.out'), out)
    apath = os.path.join(PROGRAMS, name + '.args')
    if argv is None:
        remove(apath)
    else:
        write(apath, b''.join(a + b'\n' for a in argv))
    COUNT['programs'] += 1


def line_of(src, marker):
    lines = src.split('\n')
    hits = [i for i, ln in enumerate(lines) if marker in ln and not ln.startswith('//')]
    assert len(hits) == 1, (marker, hits)
    return hits[0] + 1, lines[hits[0]]


def err_rt(name, comment, body, marker, msg, out=b''):
    """A run-time error: stderr `NAME.sea:LINE: error: MSG`, status 1, stdout `out`."""
    src = source(name, comment, body)
    ln, _ = line_of(src, marker)
    write(os.path.join(ERRORS, name + '.sea'), src)
    write(os.path.join(ERRORS, name + '.err'), b'%s.sea:%d: error: ' % (name.encode(), ln) + msg + b'\n')
    write(os.path.join(ERRORS, name + '.status'), '1\n')
    path = os.path.join(ERRORS, name + '.out')
    if out:
        write(path, out)
    else:
        remove(path)
    COUNT['errors'] += 1


def err_c(name, comment, body, marker, col_text, msg, last=False):
    """A compile error at the first (last=True: the last) occurrence of col_text in the marker's line."""
    src = source(name, comment, body)
    ln, text = line_of(src, marker)
    col = (text.rindex(col_text) if last else text.index(col_text)) + 1
    write(os.path.join(ERRORS, name + '.sea'), src)
    write(os.path.join(ERRORS, name + '.err'), '%s.sea:%d:%d: error: %s\n' % (name, ln, col, msg))
    write(os.path.join(ERRORS, name + '.status'), '1\n')
    remove(os.path.join(ERRORS, name + '.out'))
    COUNT['errors'] += 1


# ============================================================ str_basic (4.4, 6.4, 7.2, 8.2-8.4, 11.1)
def str_basic():
    fns = r'''fn greet(name: str) -> str {
    return "hello, " + name
}
fn app(ref s: str, t: str) {
    s += t
}
fn split2(s: str) -> (str, i64) {
    return (s + s, len(s))
}
fn cmp6(a: str, b: str) {
    printf("%d%d%d%d%d%d\n", a == b, a != b, a < b, a <= b, a > b, a >= b)
}
const S = "a" + "b"
const S2 = S + "c" + S
const T: str = S + "!"
const B = "a" < "b"
const P = "ab" < "abc"
const E = S == "ab"
const H = "\x80" > "z"
const N = "a" != "a "
const F0 = "b" <= "a"
'''
    a, e = b'abc', b''
    steps = [
        # locals, the empty string, len in bytes (a \u{E9} is the two bytes C3 A9, 3.5)
        ('let a = "abc"', None),
        ('let e = ""', None),
        (r'printf("[%s] [%s] %d %d %d\n", a, e, len(a), len(e), len("\u{E9}"))',
         b'[abc] [] 3 0 2'),
        # a borrowed parameter and an owned result
        ('let g = greet(a)', None),
        (r'printf("%s %d\n", g, len(g))', b'%s %d' % (b'hello, ' + a, len(b'hello, ' + a))),
        # + and += on a var, a ref parameter (s += t changes the caller's s at once, 8.3)
        ('var s = "x"', None),
        ('s += "y"', None),
        ('s = s + "z"', None),
        ('app(ref s, "!")', None),
        (r'printf("%s\n", s)', b'xyz!'),
        # tuple components: a str and an i64, bound and assigned
        ('let (dd, n) = split2("ab")', None),
        (r'printf("%s %d\n", dd, n)', b'abab 2'),
        ('var d2 = ""', None),
        ('var n2 = 0', None),
        ('(d2, n2) = split2(s)', None),
        (r'printf("%s %d\n", d2, n2)', b'xyz!xyz! 4'),
        # an annotated binding, an if expression with str arms (6.10), a while on a str length
        ('let s3: str = "q" + e', None),
        ('let k = -1', None),
        ('let word = if k < 0 { "neg" } else { "pos" }', None),
        ('var dots = s3', None),
        ('while len(dots) < 4 {\n    dots += "."\n}', None),
        (r'printf("%s %s %s\n", s3, word, dots)', b'q neg q...'),
        # shadowing a str in an inner block (7.2): the outer binding is unchanged afterwards
        ('{\n    let a = a + "!"\n    printf("%s\\n", a)\n}', b'abc!'),
        (r'printf("%s\n", a)', b'abc'),
    ]
    # the six comparisons (4.4): byte-wise, unsigned, a proper prefix the smaller, no padding
    pairs = [(b'abc', b'abd'), (b'ab', b'abc'), (b'abc', b'ab'), (b'', b'a'), (b'', b''),
             (b'a', b'a '), (b'\x80', b'\x7f'), (b'\xff', b'a'), (b'abc', b'abc'), (b'B', b'a'),
             (b'a\x00', b'a')]
    for x, y in pairs:
        steps.append(('cmp6(%s, %s)' % (q(x), q(y)), cmp6(x, y)))
    # comparisons of locals (run time) in a condition
    steps.append(('if a < "abd" && a >= "ab" && e < a {\n    printf("ordered\\n")\n}', b'ordered'))
    # %s of dynamic strings with width, precision and - (11.1): bytes are counted
    w, w3, pc = b'ab', b'xyz', b'100%'
    steps += [
        ('let w = "ab"', None),
        ('let w3 = "xyz"', None),
        ('let pc = "100%"', None),
        (r'printf("[%5s][%-5s][%.1s][%5.2s][%-4.3s][%s][%.0s][%s]\n", w, w, w3, w3, w3 + w, e, w, pc)',
         b''.join(b'[' + x + b']' for x in (pad(w, 5), pad(w, 5, left=True), pad(w3, prec=1),
                                             pad(w3, 5, 2), pad(w3 + w, 4, 3, True), e, pad(w, prec=0),
                                             pc))),
        (r'printf("[%3s][%-1s]\n", g, "\u{E9}" + w)', b'[' + pad(b'hello, abc', 3) + b'][' +
         pad(lit(r'\u{E9}') + w, 1, left=True) + b']'),
    ]
    # str constants (7.2; L-f, L-g): + of constants, one naming another, an annotated one, and
    # the bool constants of comparisons (byte-wise, prefix, a byte >= 0x80 above "z", "a" != "a ")
    steps.append((r'printf("%s %s %s %d %d %d %d %d %d\n", S, S2, T, B, P, E, H, N, F0)',
                  b' '.join([b'ab', b'abcab', b'ab!'] + [d(v) for v in (b'a' < b'b', b'ab' < b'abc',
                                                                        b'ab' == b'ab', b'\x80' > b'z',
                                                                        b'a' != b'a ', b'b' <= b'a')])))
    steps.append(('let sc = S2 + a', None))
    steps.append((r'printf("%s %d\n", sc, sc == "abcababc")', b'abcababc 1'))
    prog('str_basic', ['str locals, parameters (borrowed), results (owned), ref parameters and tuple components;',
                       '+ and +=; the six comparisons (byte-wise unsigned, a proper prefix the smaller, empty',
                       'strings, "a" != "a "); len; printf %s of dynamic strings with width, precision and -;',
                       'str constants (LANGUAGE.md 4.4, 6.4, 7.2, 8.3, 8.4, 11.1; lead decisions L-f, L-g)'],
         [], steps, fns)


str_basic()


# ============================================================ str_conv (10.9, Decision 46)
def str_conv():
    I64_MIN, I64_MAX = -(1 << 63), (1 << 63) - 1
    steps = [
        (r'printf("%s|%s|%s\n", str(0), str(-9223372036854775808), str(9223372036854775807))',
         b'|'.join([str_i(0), str_i(I64_MIN), str_i(I64_MAX)])),
        ('let k = -42', None),
        (r'printf("%s %d\n", str(k), len(str(k)))', b'-42 3'),
        # f64: %.17g (0.1 shows its binary value, -0.0 keeps its sign, 100 has no point)
        (r'printf("%s|%s|%s|%s|%s\n", str(0.1), str(-0.0), str(100.0), str(1e300), str(5e-324))',
         b'|'.join(str_f(x) for x in (0.1, -0.0, 100.0, 1e300, 5e-324))),
        # the non-finite values in C's spelling, whatever the NaN's sign (-nan flips the sign bit)
        (r'printf("%s|%s|%s|%s\n", str(nan), str(-nan), str(inf), str(-inf))', b'nan|nan|inf|-inf'),
        ('let z = 0.0', None),
        (r'printf("%s|%s|%s|%s\n", str(1.0 / z), str(-1.0 / z), str(z / z), str(-(z / z)))',
         b'inf|-inf|nan|nan'),
        ('let x = 2.5', None),
        (r'printf("%s %s %s\n", str(x), str(x * 3.0), str(f64(k)))',
         b' '.join([str_f(2.5), str_f(7.5), str_f(-42.0)])),
        # bool
        (r'printf("%s|%s|%s\n", str(true), str(1 < 0), str(k < 0))', b'true|false|true'),
        # str of a str is the string itself (Decision 46)
        ('let s = "Keep"', None),
        (r'printf("%s|%s|%s\n", str(s), str("lit"), str(s + "!"))', b'Keep|lit|Keep!'),
        # lower: only A-Z change; @ [ ` and every byte >= 0x80 are kept; the empty string
        (r'printf("[%s][%s][%s]\n", lower("Hello, WORLD [@Z`az]"), lower(""), lower("\xC3\x89\x80\xFFAZ"))',
         b'[' + lower(b'Hello, WORLD [@Z`az]') + b'][' + lower(b'') + b'][' +
         lower(b'\xC3\x89\x80\xFFAZ') + b']'),
        ('let u = "MiXeD 09"', None),
        (r'printf("%s %s %d\n", lower(u), u, lower(u) == "mixed 09")', lower(b'MiXeD 09') + b' MiXeD 09 1'),
        (r'printf("%s\n", lower(str(true) + "TRUE"))', b'truetrue'),
    ]
    assert str_f(0.1) == b'0.10000000000000001' and str_f(-0.0) == b'-0' and str_f(100.0) == b'100'
    assert str_f(1e300) == b'1.0000000000000001e+300' and str_f(5e-324) == b'4.9406564584124654e-324'
    prog('str_conv', ['str(x) of i64 (0, -2^63, 2^63 - 1), f64 (%.17g: 0.1, -0.0, 100.0, 1e300, 5e-324; nan of',
                      'both signs, inf, -inf), bool and str (unchanged); lower (only A-Z, bytes >= 0x80 kept, the',
                      'empty string) (LANGUAGE.md 10.9, Decision 46)'], [], steps)


str_conv()


# ============================================================ str_arrays (4.5, 4.8, 5, 6.9, 7.3, 7.5, 10.2)
def str_arrays():
    fns = r'''fn two() -> (str, i64) {
    return ("two", 2)
}
'''
    names = [b'ann', b'bob', b'cy']
    v = list(names)
    v[0] = b'zed'
    v[2] = v[2] + b'x'
    v1 = list(v)
    v1[1] = v1[1] + v1[0]
    w0 = [b'a', b'b', b'c', b'd']
    w1 = [w0[0], b'S', b'S', w0[3]]
    w2 = [b'p', b'S', b'S', b'q']
    w3 = [b'm' if s == b'S' else s for s in w2]
    M = [[b'a', b'b', b'c'], [b'd', b'e', b'f']]
    MT = [[M[i][j] for i in range(2)] for j in range(3)]
    Mflat = [M[i][j] for j in range(3) for i in range(2)]
    v2 = list(v1)
    v2[1] = b'two'
    steps = [
        ('let names = ["ann", "bob", "cy"]', None),
        ('ps(names)', ps(names)),
        (r'printf("%s %d %d\n", names[1], len(names), len(names[0]))', b'bob 3 3'),
        # copy on write: v shares names' buffer; the stores leave names unchanged (4.5)
        ('var v = names', None),
        ('v[0] = "zed"', None),
        ('v[2] += "x"', None),
        ('ps(v)', ps(v)),
        ('ps(names)', ps(names)),
        ('let i = 1', None),
        ('v[i] = v[i] + v[0]', None),
        ('ps(v)', ps(v1)),
        # selections read: a range, an index vector, a mask (5.2)
        ('ps(v[1..3])', ps(v1[1:3])),
        ('ps(v[[2, 0, 2]])', ps([v1[2], v1[0], v1[2]])),
        ('ps(names[names != "bob"])', ps([s for s in names if s != b'bob'])),
        # selections stored: a scalar into a range, an array into an index vector, a mask (5.5)
        ('var w = ["a", "b", "c", "d"]', None),
        ('w[1..3] = "S"', None),
        ('ps(w)', ps(w1)),
        ('w[[0, 3]] = ["p", "q"]', None),
        ('ps(w)', ps(w2)),
        ('w[w == "S"] = "m"', None),
        ('ps(w)', ps(w3)),
        # concatenation (6.9): scalars and vectors join into a str[]
        ('let c = [names, "x"]', None),
        ('ps(c)', ps(names + [b'x'])),
        ('ps(["<", names, names[0], w[1..2]])', ps([b'<'] + names + [names[0]] + w3[1:2])),
        # filled (10.2)
        ('ps(filled("", 2))', ps([b'', b''])),
        ('pms(filled("ab", 2, 3))', pms([[b'ab'] * 3] * 2)),
        ('ps(filled("z", 0))', ps([])),
        # a str[,] literal, its .T and .flat (column-major), .col and .row of a str[]
        ('let M = ["a", "b", "c"; "d", "e", "f"]', None),
        ('pms(M)', pms(M)),
        ('pms(M.T)', pms(MT)),
        ('ps(M.flat)', ps(Mflat)),
        ('pms(names.col)', pms(col(names))),
        ('pms(names.row)', pms(row(names))),
        (r'printf("%s %s %d %d\n", M[1, 0], M.T[2, 1], rows(M), cols(M))', b'd f 2 3'),
        # element loops (7.5): over a str[] and over a .flat
        ('for s in names {\n    printf("<%s>", s)\n}\nprintf("\\n")', b''.join(b'<' + s + b'>' for s in names)),
        ('for s in M.flat {\n    printf("%s", s)\n}\nprintf("\\n")', b''.join(Mflat)),
        # the vector is evaluated once: reassigning it inside the loop changes nothing visited
        ('var lv = ["1", "2"]', None),
        ('for s in lv {\n    lv = [lv, s + "!"]\n}', None),
        ('ps(lv)', ps([b'1', b'2', b'1!', b'2!'])),
        # [] under a str[] annotation (6.9), len, a concatenation onto it
        ('let em: str[] = []', None),
        ('ps(em)', ps([])),
        ('var t = em', None),
        ('t = [t, "only"]', None),
        (r'printf("%d %d\n", len(em), len(t))', b'0 1'),
        ('ps(t)', ps([b'only'])),
        # a tuple assignment with a str element target (7.3; L12, R25)
        ('var kk = 0', None),
        ('(v[1], kk) = two()', None),
        ('ps(v)', ps(v2)),
        (r'printf("%d\n", kk)', b'2'),
    ]
    prog('str_arrays', ['str[] and str[,]: literals, element reads and replacing stores (=, +=), selections read and',
                        'stored (a scalar, an array, a mask), [v, "x"], filled, for over a str[] and a .flat,',
                        '.T, .flat, .col, .row, len, [] under a str[] annotation, copy on write, (v[i], k) = two()',
                        '(LANGUAGE.md 4.5, 4.8, 5.2, 5.5, 5.6, 6.9, 7.3, 7.5, 10.2)'],
         ['ps', 'pms'], steps, fns)


str_arrays()


# ============================================================ str_ew (6.2-6.4, Decision 45)
def str_ew():
    names = [b'x', b'y', b'x', b'xx']
    a = [b'a', b'b', b'c']
    b = [b'b', b'b', b'a']
    M = [[b'a', b'b', b'c'], [b'd', b'e', b'f']]
    r = [b'1', b'2']
    qv = [b'X', b'Y', b'Z']
    cat = lambda x, y: x + y
    hi = [b'\x80', b'a', b'b']
    acc = [b'p', b'q']
    acc = ew(cat, acc, b'!')
    acc = ew(cat, acc, [b'1', b'2'])
    acc2 = ew(cat, acc, acc)
    steps = [
        ('let names = ["x", "y", "x", "xx"]', None),
        ('pvb(names == "x")', pvb(ew(lambda x, y: x == y, names, b'x'))),
        ('pvb("x" < names)', pvb(ew(lambda x, y: x < y, b'x', names))),
        ('let a = ["a", "b", "c"]', None),
        ('let b = ["b", "b", "a"]', None),
        ('pvb(a < b)', pvb(ew(lambda x, y: x < y, a, b))),
        ('pvb(a >= b)', pvb(ew(lambda x, y: x >= y, a, b))),
        ('pvb(a != b)', pvb(ew(lambda x, y: x != y, a, b))),
        ('pvb(a <= b)', pvb(ew(lambda x, y: x <= y, a, b))),
        ('pvb(a > b)', pvb(ew(lambda x, y: x > y, a, b))),
        ('pvb(a == b)', pvb(ew(lambda x, y: x == y, a, b))),
        ('pvb(["\\x80", "a", "b"] > "a")', pvb(ew(lambda x, y: x > y, hi, b'a'))),
        # + appends to every element, or joins two str[] element by element
        ('ps(names + "!")', ps(ew(cat, names, b'!'))),
        ('ps("<" + names)', ps(ew(cat, b'<', names))),
        ('ps(a + b)', ps(ew(cat, a, b))),
        ('ps(a + b + a)', ps(ew(cat, ew(cat, a, b), a))),
        # a str[,] broadcast against a .col (2 x 1) and a .row (1 x 3), and both together (6.3)
        ('let M = ["a", "b", "c"; "d", "e", "f"]', None),
        ('let r = ["1", "2"]', None),
        ('let q = ["X", "Y", "Z"]', None),
        ('pms(M + r.col)', pms(ew(cat, M, col(r)))),
        ('pms(q.row + M)', pms(ew(cat, row(qv), M))),
        ('pms(r.col + q.row)', pms(ew(cat, col(r), row(qv)))),
        ('pmb(M < "c")', pmb(ew(lambda x, y: x < y, M, b'c'))),
        ('pmb(M == q.row + "")', pmb(ew(lambda x, y: x == y, M, ew(cat, row(qv), b'')))),
        ('pmb(r.col != M.T.T)', pmb(ew(lambda x, y: x != y, col(r), M))),
        # += of a str[] local: element-wise with a str and with a str[] (rule 15 (i))
        ('var acc = ["p", "q"]', None),
        ('acc += "!"', None),
        ('acc += ["1", "2"]', None),
        ('ps(acc)', ps(acc)),
        ('acc += acc', None),
        ('ps(acc)', ps(acc2)),
        # an empty operand gives an empty result
        ('let e: str[] = []', None),
        ('ps(e + "x")', ps([])),
        ('pvb(e == e)', pvb([])),
    ]
    prog('str_ew', ['element-wise str operators (Decision 45): the six comparisons and + of a str[] with a str and',
                    'with another str[], a str[,] broadcast against a .col and a .row, += of a str[] local, empty',
                    'operands (LANGUAGE.md 6.2-6.4)'], ['ps', 'pms', 'pvb', 'pmb'], steps)


str_ew()

err_rt('r_str_ew_shape', ['two str[] of lengths 3 and 2 joined by +: shape mismatch: 3 vs 2 at the operator\'s line',
                          '(LANGUAGE.md 6.3, 9.2; Decision 45)'],
       'let a = ["x", "y", "z"]\nlet b = ["p", "q"]\nprintf("before\\n")\nlet c = a + b\nprintf("%d\\n", len(c))\n',
       'let c', b'shape mismatch: 3 vs 2', out=b'before\n')


# ============================================================ sort_str (10.6, Decision 40)
def sort_str():
    v = [b'pear', b'apple', b'', b'app', b'Zeta', b'\x80x', b'apple', b'b', b'', b'\x7f', b'App']
    src = '[' + ', '.join(q(s) for s in v) + ']'
    one = [b'only']
    w = [b'b', b'a', b'b', b'a', b'b']
    steps = [
        ('let v = ' + src, None),
        ('ps(sort(v))', ps([v[i] for i in argsort(v)])),
        ('ps(sort(v, desc: true))', ps([v[i] for i in argsort(v, True)])),
        ('pvi(argsort(v))', pvi(argsort(v))),
        ('pvi(argsort(v, desc: true))', pvi(argsort(v, True))),
        # ties keep their input order in both directions
        ('let w = ["b", "a", "b", "a", "b"]', None),
        ('pvi(argsort(w))', pvi(argsort(w))),
        ('pvi(argsort(w, desc: true))', pvi(argsort(w, True))),
        ('let up = false', None),
        ('ps(sort(w, desc: !up))', ps([w[i] for i in argsort(w, True)])),
        # one element, an empty vector, an owned operand (an element-wise result, a selection)
        ('ps(sort(["only"]))', ps(one)),
        ('let e: str[] = []', None),
        ('ps(sort(e))', ps([])),
        ('pvi(argsort(e, desc: true))', pvi([])),
        ('ps(sort(v[0..4] + "!"))', ps(sorted([s + b'!' for s in v[0:4]]))),
        ('pvi(argsort(lower_all(v[3..5])))', pvi(argsort([lower(s) for s in v[3:5]]))),
        # the operand is unchanged
        ('ps(v)', ps(v)),
    ]
    assert argsort(v) == [2, 8, 10, 4, 3, 1, 6, 7, 0, 9, 5]
    fns = r'''fn lower_all(v: str[]) -> str[] {
    var r = v
    for i in 0..len(v) {
        r[i] = lower(v[i])
    }
    return r
}
'''
    prog('sort_str', ['sort and argsort of a dynamic str vector (Decision 40): ascending and descending, byte-wise',
                      'with prefixes, upper case before lower, bytes >= 0x80 last, ties in input order in both',
                      'directions, empty strings, one element, an empty vector, owned operands (LANGUAGE.md 10.6)'],
         ['ps', 'pvi'], steps, fns)


sort_str()


# ============================================================ match_basic (7.6)
def match_basic():
    fns = r'''fn classify(s: str) -> i64 {
    var r = -1
    match s {
        "ground" => { r = 1 }
        "machined" | "cut" => { r = 2 }
        "hot-rolled" | "rolled" | "hr" => { r = 3 }
        "skip" => {}
        "a" => { r = 4 }, "a " => { r = 5 }
        "tab\there" => { r = 6 }
        _ => { r = 0 }
    }
    return r
}
fn bump(ref s: str) {
    match s {
        "a" => { s = "b" }
        _ => { s += "?" }
    }
}
fn first_long(v: str[]) -> str {
    for w in v {
        match lower(w) {
            "" => { continue }
            "end" => { return "(end)" }
            _ => {
                if len(w) > 2 {
                    return w
                }
            }
        }
    }
    return "-"
}
'''

    def classify(s):
        return {b'ground': 1, b'machined': 2, b'cut': 2, b'hot-rolled': 3, b'rolled': 3, b'hr': 3,
                b'skip': -1, b'a': 4, b'a ': 5, b'tab\there': 6}.get(s, 0)

    words = [b'ground', b'cut', b'machined', b'rolled', b'hr', b'hot-rolled', b'skip', b'a', b'a ',
             b'tab\there', b'Ground', b'', b'groundx']
    wsrc = '[' + ', '.join(q(s) for s in words) + ']'
    arg0 = b'Machined'

    loop_words = [b'one', b'SKIP', b'two', b'Stop', b'three']
    loop_out = b''
    n = 0
    for x in loop_words:
        lx = lower(x)
        if lx == b'stop':
            break
        if lx == b'skip':
            continue
        n += 1
        loop_out += b'[' + x + b']'

    def first_long(v):
        for x in v:
            lx = lower(x)
            if lx == b'':
                continue
            if lx == b'end':
                return b'(end)'
            if len(x) > 2:
                return x
        return b'-'

    fl_cases = [[b'', b'ab', b'abcd'], [b'', b'END', b'abcd'], [b'x', b'y'], []]
    steps = [
        # several patterns per arm, the matching arm runs, an empty arm body, arms separated by ","
        ('let words = ' + wsrc, None),
        ('for w in words {\n    printf(" %d", classify(w))\n}\nprintf("\\n")',
         b''.join(b' %d' % classify(x) for x in words)),
        # scrutinee a local with a match of only _
        ('let lone = "anything"', None),
        ('match lone {\n    _ => { printf("only _\\n") }\n}', b'only _'),
        # scrutinee a ref parameter (assigned inside its own match)
        ('var s = "a"', None),
        ('bump(ref s)', None),
        ('bump(ref s)', None),
        (r'printf("%s\n", s)', b'b?'),
        # scrutinee a call's result (owned) and an element
        ('match lower("HR") {\n    "hr" => { printf("hr\\n") }\n    _ => { printf("other\\n") }\n}', b'hr'),
        ('match words[2] {\n    "cut" => { printf("c\\n") }\n    "machined" => { printf("m\\n") }\n'
         '    _ => { printf("?\\n") }\n}', b'm'),
        # scrutinee args()[0] (the first argument, from match_basic.args)
        ('match args()[0] {\n    "machined" => { printf("lower\\n") }\n    "Machined" => { printf("upper\\n") }\n'
         '    _ => { printf("none\\n") }\n}', b'upper' if arg0 == b'Machined' else None),
        ('match lower(args()[0]) {\n    "machined" => { printf("%d\\n", classify(lower(args()[0]))) }\n'
         '    _ => { printf("none\\n") }\n}', b'%d' % classify(lower(arg0))),
        # break and continue inside arms with an owned scrutinee
        ('var n = 0', None),
        ('for w in ["one", "SKIP", "two", "Stop", "three"] {\n    match lower(w) {\n        "stop" => { break }\n'
         '        "skip" => { continue }\n        _ => { n += 1 }\n    }\n    printf("[%s]", w)\n}\n'
         'printf(" %d\\n", n)', loop_out + b' %d' % n),
        # return inside an arm with an owned scrutinee, from a loop
        ('let e: str[] = []', None),
        (r'printf("%s %s %s %s\n", first_long(["", "ab", "abcd"]), first_long(["", "END", "abcd"]), '
         r'first_long(["x", "y"]), first_long(e))',
         b' '.join(first_long(c) for c in fl_cases)),
        # nested matches; the arms run nothing else (no fall through)
        ('for w in ["a", "b", "c"] {\n    match w {\n        "a" | "b" => {\n            match w {\n'
         '                "b" => { printf("B") }\n                _ => { printf("A") }\n            }\n'
         '        }\n        _ => { printf("C") }\n    }\n}\nprintf("\\n")', b'ABC'),
    ]
    prog('match_basic', ['match (LANGUAGE.md 7.6): several patterns per arm, empty arm bodies, a match with only _,',
                         'scrutinee a local, a ref parameter, a call\'s result (owned), args()[0] (match_basic.args),',
                         'an element; break, continue and return inside arms with an owned scrutinee; nesting'],
         [], steps, fns, argv=[arg0])


match_basic()


# ============================================================ args (10.10, Decision 14)
ARGS_BODY = r'''let a = args()
printf("%d %d\n", len(a), len(args()))
for s in args() {
    printf("[%s] %d\n", s, len(s))
}
var i = 0
while i < len(a) {
    printf("%s|", a[i])
    i += 1
}
printf("\n")
'''


def args_out(argv):
    out = b'%d %d\n' % (len(argv), len(argv))
    for s in argv:
        out += b'[' + s + b'] %d\n' % len(s)
    out += b''.join(s + b'|' for s in argv) + b'\n'
    return out


def args_prog(name, comment, argv):
    write(os.path.join(PROGRAMS, name + '.sea'), source(name, comment, ARGS_BODY))
    write(os.path.join(PROGRAMS, name + '.out'), args_out(argv))
    apath = os.path.join(PROGRAMS, name + '.args')
    if argv is None or not argv:
        remove(apath)
    else:
        write(apath, b''.join(s + b'\n' for s in argv))
    COUNT['programs'] += 1


args_prog('args_basic', ['args() with several arguments (args_basic.args): an empty argument, one with inner, leading',
                         'and trailing blanks; for a in args(), len(args()), indexing (LANGUAGE.md 10.10)'],
          [b'first', b'', b'two words', b'  lead', b'tail ', b'x'])
args_prog('args_one', ['args() with one argument (LANGUAGE.md 10.10)'], [b'solo'])
args_prog('args_none', ['args() without arguments: the empty str[] (LANGUAGE.md 10.10)'], [])

err_rt('r_args_oob', ['args()[0] without arguments: index 0 out of bounds for dimension 0 of extent 0 at its line',
                      '(LANGUAGE.md 5.4, 9.2, 10.10)'],
       'printf("start\\n")\nlet first = args()[0]\nprintf("%s\\n", first)\n', 'let first',
       b'index 0 out of bounds for dimension 0 of extent 0', out=b'start\n')


# ============================================================ error (9.2-9.4)
err_rt('r_error_after_output', ['error after printed output: standard output flushed first (with no extra newline),',
                                'then the message; status 1 (LANGUAGE.md 9.2, 9.3)'],
       'printf("before\\n")\nprintf("partial")\nerror("stopped at %d", 3)\nprintf("never\\n")\n',
       'error(', b'stopped at 3', out=b'before\npartial')
err_rt('r_error_in_fn', ['error inside a function: the line of the error call (LANGUAGE.md 9.3)'],
       'fn check(x: i64) -> i64 {\n    if x < 0 {\n        error("negative: %d", x)\n    }\n    return x * 2\n}\n'
       'printf("%d\\n", check(4))\nprintf("%d\\n", check(-3))\nprintf("never\\n")\n',
       'error(', b'negative: -3', out=b'8\n')
err_rt('r_error_fmt', ['error formats like format: %s of dynamic strings with width and -, numeric conversions, NaN',
                       'and %% (LANGUAGE.md 9.3, 11.1)'],
       'let s = "abc" + "def"\nlet x = 2.5\nlet z = 0.0\n'
       'error("bad %s [%5s|%-4s] %d %.3f %g %e %%", s, lower("AB"), "x", -7, x, z / z, 1500.0)\n',
       'error(', b'bad abcdef [' + pad(b'ab', 5) + b'|' + pad(b'x', 4, left=True) + b'] -7 2.500 NaN 1.500000e+03 %')
err_rt('r_error_match_arm', ['error in a _ arm, with a \\" in its format (LANGUAGE.md 7.6, 9.3)'],
       'let finish = lower("Polished")\nmatch finish {\n    "ground" => { printf("g\\n") }\n'
       '    _ => { error("unknown surface finish \\"%s\\"", finish) }\n}\n',
       'error(', b'unknown surface finish "polished"')
err_rt('r_error_plain', ['error with no conversion argument, in a loop after output (LANGUAGE.md 9.3)'],
       'for i in 0..5 {\n    printf("%d\\n", i)\n    if i == 2 {\n        error("plain")\n    }\n}\n',
       'error(', b'plain', out=b'0\n1\n2\n')


# ============================================================ heap_str_* (DESIGN.md 6.2 4g-1; rules 15, 31)
def heap_str():
    argv = [b'alpha', b'Beta']
    loop = b''
    for i in range(3):
        loop += b'b' if lower(argv[i % 2]) == b'beta' else b'-'
    steps = [
        (r'printf("%s\n", args()[0])', argv[0]),
        ('let s = args()[0]', None),
        (r'printf("%s %d\n", s, len(s))', argv[0] + b' %d' % len(argv[0])),
        ('match args()[1] {\n    "Beta" => { printf("B\\n") }\n    _ => { printf("?\\n") }\n}', b'B'),
        ('for i in 0..3 {\n    match lower(args()[i % 2]) {\n        "beta" => { printf("b") }\n'
         '        _ => { printf("-") }\n    }\n}\nprintf("\\n")', loop),
        ('for i in 0..4 {\n    let t = args()[i % 2] + str(i)\n    if t == "Beta3" {\n        printf("%s\\n", t)\n'
         '    }\n}', b'Beta3'),
    ]
    prog('heap_str_args', ['owned str values from args() (heap_str_args.args): printf("%s\\n", args()[0]), let s =',
                           'args()[0], match args()[1] (rule 15 (f)), lower(args()[k]) in a loop; heap check 0',
                           '(DESIGN.md 3.6.6 rules 15, 33, 35)'], [], steps, argv=argv)

    fns = r'''fn mk(n: i64) -> str {
    return "v" + str(n)
}
fn two(a: str) -> (str, i64) {
    return (a + "!", len(a))
}
fn g(ref v: str[]) -> str {
    v[0] = "changed" + v[1]
    return "g"
}
fn f(a: str, b: str) {
    printf("%s %s\n", a, b)
}
'''
    v = [b'p', b'q', b'r']
    v[1], x = b'w!', 1
    vl = list(v)
    out_loop = []
    for i in range(3):
        vl[i], x = vl[i] + b'!', len(vl[i])
    first = vl[0]
    vg = list(vl)
    vg[0] = b'changed' + vg[1]
    steps = [
        # eval of calls returning a str, and a call of a tuple result as a statement
        ('mk(1)', None),
        ('for i in 0..3 {\n    mk(i)\n    two(mk(i))\n}', None),
        ('let _ = mk(5)', None),
        # a _ component of a str result
        ('let (_, k) = two("abc")', None),
        (r'printf("%d\n", k)', b'3'),
        # filled of an owned str
        ('let fl = filled("a" + mk(7), 3)', None),
        ('ps(fl)', ps([b'av7'] * 3)),
        # (v[i], x) = two() with str results (L12, R25)
        ('var v = ["p", "q", "r"]', None),
        ('var x = 0', None),
        ('(v[1], x) = two("w")', None),
        ('ps(v)', ps(v)),
        (r'printf("%d\n", x)', b'1'),
        ('for i in 0..3 {\n    (v[i], x) = two(v[i])\n}', None),
        ('ps(v)', ps(vl)),
        (r'printf("%d\n", x)', b'%d' % x),
        # f(v[0], g(ref v)): v[0] is evaluated first, a borrowed element that g then replaces (rule 31)
        ('f(v[0], g(ref v))', first + b' g'),
        ('ps(v)', ps(vg)),
        # strings in a function's locals on early exits
        ('var acc = ""', None),
        ('for i in 0..6 {\n    let piece = mk(i)\n    if i == 4 {\n        break\n    }\n    if i == 1 {\n'
         '        continue\n    }\n    acc = acc + piece + ","\n}', None),
        (r'printf("%s\n", acc)', b'v0,v2,v3,'),
    ]
    prog('heap_str_misc', ['discarded str results (a call statement, let _ =), a _ component of a str result, filled of',
                           'an owned str, (v[i], x) = two() with str results, f(v[0], g(ref v)) with a borrowed str',
                           'element, str locals on break and continue; heap check 0 (DESIGN.md 3.6.6 rules 15, 31;',
                           'L12, R25)'], ['ps'], steps, fns)

    fns = r'''fn mk(n: i64) -> str {
    return "v" + str(n)
}
fn find_tag(v: str[], t: str) -> i64 {
    var i = 0
    for s in v {
        let u = lower(s)
        if u == t {
            return i
        }
        i += 1
    }
    return -1
}
'''
    cnt = 0
    for i in range(4):
        if lower(b'v' + str_i(i)) == b'v2':
            cnt += 1
        if str_i(i) + b'x' < b'2':
            cnt += 10
    names = [b'Alpha', b'beta', b'GAMMA']
    steps = [
        ('var acc = ""', None),
        ('for i in 0..5 {\n    acc = acc + str(i)\n    acc += ","\n}', None),
        (r'printf("%s\n", acc)', b'0,1,2,3,4,'),
        ('var cnt = 0', None),
        ('for i in 0..4 {\n    if lower(mk(i)) == "v2" {\n        cnt += 1\n    }\n    if str(i) + "x" < "2" {\n'
         '        cnt += 10\n    }\n}', None),
        (r'printf("%d\n", cnt)', b'%d' % cnt),
        ('let names = ["Alpha", "beta", "GAMMA"]', None),
        (r'printf("%d %d %d\n", find_tag(names, "gamma"), find_tag(names, "beta"), find_tag(names, "x"))',
         b'2 1 -1'),
        # element-wise temporaries: owned operands of comparisons and +, discarded in a loop
        ('var hits = 0', None),
        ('for i in 0..3 {\n    let m = (names + str(i)) == "beta1"\n    hits += nnz(m)\n    let z = "<" + names + ">"\n'
         '    hits += len(z) - 3\n}', None),
        (r'printf("%d\n", hits)', b'1'),
        ('var tbl = filled("", 3)', None),
        ('for i in 0..3 {\n    tbl[i] = mk(i) + tbl[i]\n    tbl = tbl + ""\n}', None),
        ('ps(tbl)', ps([b'v0', b'v1', b'v2'])),
        ('ps(sort(names + "") + lower(names[0]))', ps([s + lower(b'Alpha') for s in sorted(names)])),
    ]
    prog('heap_str_temps', ['owned str temporaries (concatenations, str(), lower) in loops and conditions, str locals',
                            'on return, element-wise str results discarded, element stores of owned values; heap',
                            'check 0 (DESIGN.md 3.6.6 rules 15, 16, 32)'], ['ps'], steps, fns)


heap_str()


# ============================================================ heap_str_views (review of 4g-1)
def heap_str_views():
    """Elements of views of owned temporaries, L17 compound stores whose value passes the root by
    ref, and view element reads passed before a ref call. Every value follows from value semantics
    (4.5, 8.2), left-to-right evaluation of arguments (6.8 rule 5), the order of a compound store
    (5.5, 7.3: the element is read before e is evaluated, and the store, made after e, sees what a
    ref argument in e did to the variable) and the views of 5.6 (A.T[i, j] = A[j, i]; A.flat[k] the
    column-major element k; v.col[i, 0] = v.row[0, i] = v[i]). g and gm replace the whole root and
    then allocate and print new strings, so a value read from the released old root would show."""
    fns = r'''fn g(ref v: str[]) -> str {
    v = ["F" + str(len(v)), "G" + ""]
    let k1 = "Z" + "Z"
    let k2 = "Y" + "Y"
    let k3 = "X" + "X"
    printf("%s%s%s ", k1, k2, k3)
    return "g"
}
fn gm(ref M: str[,]) -> str {
    M = ["n" + "", "o" + ""; "p" + "", "q" + ""]
    let k1 = "W" + "W"
    let k2 = "V" + "V"
    printf("%s%s ", k1, k2)
    return "gm"
}
fn f2(a: str, b: str) {
    printf("%s %s\n", a, b)
}
fn inner(ref v: str[], k: i64) {
    f2(v.col[1, 0], g(ref v))
    f2(v.row[0, k], g(ref v))
}
fn innerm(ref M: str[,]) {
    f2(M.T[0, 1], gm(ref M))
    f2(M.flat[2], gm(ref M))
    f2(M.T.T[1, 1], gm(ref M))
}
'''
    G_OUT = b'ZZYYXX '        # what g prints before its caller's call runs (arguments first, 6.8)
    GM_OUT = b'WWVV '
    GM_NEW = [[b'n', b'o'], [b'p', b'q']]

    def T(A):
        return [[A[i][j] for i in range(len(A))] for j in range(len(A[0]))]

    def flat(A):
        return [A[i][j] for j in range(len(A[0])) for i in range(len(A))]

    v = [b'p', b'q']
    M = [[b'a', b'b'], [b'c', b'd']]
    P = [[b'ab', b'c'], [b'de', b'f']]
    # (2) compound stores: old element read first, op after e, store into the root e left
    w_new = [b'F2', b'G']                    # g's new root (len of the old root is 2)
    w_new[0] = b'aa' + b'g'
    N_old = [[b'aa', b'bb'], [b'c', b'd']]
    N1 = [list(r) for r in GM_NEW]
    N1[1][0] = N_old[1][0] + b'gm'
    N2 = [list(r) for r in GM_NEW]
    N2[0][1] = flat(N_old)[2] + b'gm'        # flat index 2 of a 2 x 2 matrix is element (0, 1)
    assert flat(N_old)[2] == b'bb'
    steps = [
        # (1) an element of a view of an owned temporary, used after other strings are made
        ('let v = ["p" + "", "q" + ""]', None),
        ('let e = (v + "3").col[1, 0]', None),
        ('let z = ["W" + "W", "V" + "V"]', None),
        (r'printf("%s %s\n", e, z[0])', [x + b'3' for x in v][1] + b' WW'),
        ('let M = ["a" + "", "b" + ""; "c" + "", "d" + ""]', None),
        ('let x = (M + "1").T[0, 1]', None),
        ('let y = ["Q" + "Q", "R" + "R", "S" + "S", "T" + "T"]', None),
        (r'printf("%s %s %s\n", x, (M + "2").flat[3], y[3])',
         T(ew(lambda a, b: a + b, M, b'1'))[0][1] + b' ' + flat(ew(lambda a, b: a + b, M, b'2'))[3] + b' TT'),
        ('match (v + "x").col[1, 0] {\n    "qx" => { printf("ok\\n") }\n    _ => { printf("no\\n") }\n}', b'ok'),
        (r'printf("%d\n", (M + "1").T[0, 1] == "c1")', d(T(ew(lambda a, b: a + b, M, b'1'))[0][1] == b'c1')),
        # (2) an L17 compound store whose value passes the root by ref
        ('var w = ["a" + "a", "b" + "b"]', None),
        ('w[0] += g(ref w)', None),
        (r'printf("%s %s\n", w[0], w[1])', G_OUT + b' '.join(w_new)),
        ('var N = ["a" + "a", "b" + "b"; "c" + "", "d" + ""]', None),
        ('N[1, 0] += gm(ref N)', None),
        (r'printf("%s %s %s %s\n", N[0, 0], N[1, 0], N[0, 1], N[1, 1])',
         GM_OUT + b' '.join([N1[0][0], N1[1][0], N1[0][1], N1[1][1]])),
        ('N = ["a" + "a", "b" + "b"; "c" + "", "d" + ""]', None),
        ('N.flat[2] += gm(ref N)', None),
        (r'printf("%s %s %s %s\n", N[0, 0], N[1, 0], N[0, 1], N[1, 1])',
         GM_OUT + b' '.join([N2[0][0], N2[1][0], N2[0][1], N2[1][1]])),
        # (3) scalar-indexed view element reads passed before a ref call: the element is the old one
        ('var u = ["u" + "0", "u" + "1"]', None),
        ('f2(u.col[1, 0], g(ref u))', G_OUT + b'u1 g'),
        ('u = ["u" + "0", "u" + "1"]', None),
        ('let k = 1', None),
        ('f2(u.row[0, k], g(ref u))', G_OUT + b'u1 g'),
        ('var P = ["a" + "b", "c" + ""; "d" + "e", "f" + ""]', None),
        ('f2(P.T[0, 1], gm(ref P))', GM_OUT + T(P)[0][1] + b' gm'),
        ('P = ["a" + "b", "c" + ""; "d" + "e", "f" + ""]', None),
        ('f2(P.flat[2], gm(ref P))', GM_OUT + flat(P)[2] + b' gm'),
        ('P = ["a" + "b", "c" + ""; "d" + "e", "f" + ""]', None),
        ('f2(P.T.T[1, 1], gm(ref P))', GM_OUT + T(T(P))[1][1] + b' gm'),
        # the same reads through a ref-parameter root; the second read sees g's first new root
        ('u = ["u" + "0", "u" + "1"]', None),
        ('inner(ref u, 1)', G_OUT + b'u1 g\n' + G_OUT + b'G g'),
        ('P = ["a" + "b", "c" + ""; "d" + "e", "f" + ""]', None),
        ('innerm(ref P)', GM_OUT + T(P)[0][1] + b' gm\n' + GM_OUT + flat(GM_NEW)[2] + b' gm\n' +
         GM_OUT + T(T(GM_NEW))[1][1] + b' gm'),
        (r'printf("%s %s\n", u[0], P[1, 1])', b'F2 q'),
    ]
    prog('heap_str_views', ['use-after-free probes of 4g-1: elements of views of owned temporaries ((v + "3").col[1, 0],',
                            '(M + "1").T[0, 1], a match scrutinee, a comparison); compound stores v[0] += g(ref v),',
                            'M[i, j] += and M.flat[k] += whose value replaces the root by ref; view element reads',
                            '(.col, .row, .T, .flat, .T.T) passed before a ref call, also through a ref parameter;',
                            'heap check 0 (LANGUAGE.md 4.5, 5.5, 5.6, 6.8, 7.3, 8.2, 8.3)'], [], steps, fns)


heap_str_views()


# ============================================================ compile errors (DESIGN.md 2.6.2)
TM = 'type mismatch: expected %s, found %s'
OP2 = "operator '%s' cannot be applied to %s and %s"
NO = "no overload of '%s' accepts (%s)"

err_c('err_str_let_int', ['let s: str = 1: type mismatch at the value (201; LANGUAGE.md 4.10)'],
      'let s: str = 1\n', 'let s', '1', TM % ('str', 'i64'))
err_c('err_match_scrut_type', ['a match scrutinee that is not a str: 201 at the scrutinee (DESIGN.md 2.6.2 "Readings fixed',
                               'by 4g", L-a)'],
      'let n = 3\nmatch n {\n    _ => { printf("x\\n") }\n}\n', 'match n', 'n', TM % ('str', 'i64'), last=True)
err_c('err_str_sub', ['"a" - "b": - does not apply to str (240 at the operator node, at its left operand, DESIGN.md',
                      '3.3; LANGUAGE.md 6.2)'],
      'let d = "a" - "b"\n', 'let d', '"a"', OP2 % ('-', 'str', 'str'))
err_c('err_str_mul', ['s * 2 of a str local: 240 with the operand types (the untyped 2 is i64, LANGUAGE.md 4.2)'],
      'let s = "ab"\nlet t = s * 2\n', 'let t', 's *', OP2 % ('*', 'str', 'i64'))
err_c('err_str_add_int', ['"a" + 1: + of a str with a non-str operand is 240 (DESIGN.md 2.6.2 "Readings fixed by 4g")'],
      'let t = "a" + 1\n', 'let t', '"a"', OP2 % ('+', 'str', 'i64'))
err_c('err_str_ew_cmp_f64', ['names == 1.0 of a str[]: a str operand combines only with a str operand (240; LANGUAGE.md',
                             '6.3, Decision 45)'],
      'let names = ["a", "b"]\nlet m = names == 1.0\n', 'let m', 'names', OP2 % ('==', 'str[]', 'f64'))
err_c('err_str_neg', ['unary - of a str: 241 at the neg node (LANGUAGE.md 6.2; DESIGN.md 2.6.2)'],
      'let s = "a"\nlet t = -s\n', 'let t', '-', "operator '-' cannot be applied to str")
err_c('err_match_no_wild', ['a match without a _ arm: match is not exhaustive (207) at the match (LANGUAGE.md 7.6)'],
      'let s = "a"\nmatch s {\n    "a" => { printf("a\\n") }\n}\n', 'match s', 'match', 'match is not exhaustive')
err_c('err_match_wild_not_last', ['_ followed by a string arm: 207 at the match, which comes before the arm\'s 208',
                                  '(LANGUAGE.md 7.6; L-a)'],
      'let s = "a"\nmatch s {\n    _ => { printf("x\\n") }\n    "a" => { printf("a\\n") }\n}\n',
      'match s', 'match', 'match is not exhaustive')
err_c('err_match_no_arms', ['a match with no arm is not exhaustive (207; LANGUAGE.md 7.6)'],
      'let s = "a"\nmatch s {\n}\n', 'match s', 'match', 'match is not exhaustive')
err_c('err_match_before_scrut', ['207 at the match keyword is reported before an error in the scrutinee that follows',
                                 'it (an undeclared name; lead decision L-a)'],
      'match qq {\n    "a" => { printf("a\\n") }\n}\n', 'match qq', 'match', 'match is not exhaustive')
err_c('err_match_dup_in_arm', ['a pattern repeated within one arm: unreachable pattern (208) at the arm, its first',
                               'pattern (LANGUAGE.md 7.6)'],
      'let s = "a"\nmatch s {\n    "x" => { printf("x\\n") }\n    "a" | "b" | "a" => { printf("a\\n") }\n'
      '    _ => { printf("_\\n") }\n}\n', '"a" | "b"', '"a"', 'unreachable pattern')
err_c('err_match_dup_across', ['a pattern of an earlier arm repeated in a later arm: 208 at the later arm (LANGUAGE.md',
                               '7.6)'],
      'let s = "a"\nmatch s {\n    "a" | "b" => { printf("ab\\n") }\n    "c" | "b" => { printf("cb\\n") }\n'
      '    _ => { printf("_\\n") }\n}\n', '"c" | "b"', '"c"', 'unreachable pattern')
err_c('err_match_after_wild', ['a string arm after a _ arm in a match that ends with _: 208 at that arm (LANGUAGE.md',
                               '7.6)'],
      'let s = "a"\nmatch s {\n    "a" => { printf("a\\n") }\n    _ => { printf("_\\n") }\n'
      '    "b" => { printf("b\\n") }\n    _ => { printf("again\\n") }\n}\n', '"b" =>', '"b"', 'unreachable pattern')
err_c('err_match_second_wild', ['a second _ arm: 208 at it (LANGUAGE.md 7.6)'],
      'let s = "a"\nmatch s {\n    "a" => { printf("a\\n") }\n    _ => { printf("_\\n") }\n'
      '    _ => { printf("again\\n") }\n}\n', 'again', '_', 'unreachable pattern')
err_c('err_error_fmt_literal', ['error with a str local as its format: format must be a string literal (233) at the',
                                'argument (LANGUAGE.md 11.1; DESIGN.md 2.6.2 L-d)'],
      'let f = "x %d"\nerror(f, 1)\n', 'error(', 'f', 'format must be a string literal', last=True)
err_c('err_error_fmt_arg', ['error("bad %d", "x"): format "%d" expects an integer or f64, found str (210) at the',
                            'argument'],
      'error("bad %d", "x")\n', 'error(', '"x"', 'format "%d" expects an integer or f64, found str')
err_c('err_error_fmt_count', ['error with one argument for two conversions: 211 at the call (DESIGN.md 2.6.2)'],
      'error("%s and %s", "a")\n', 'error(', 'error', 'format "%s and %s" expects 2 arguments, found 1')
err_c('err_lower_int', ['lower(1): lower takes one str (243; Decision 46)'],
      'let t = lower(1)\n', 'let t', 'lower', NO % ('lower', 'i64'))
err_c('err_lower_array', ['lower of a str[]: scalars only, an array is 243 (Decision 46)'],
      'let names = ["A"]\nlet t = lower(names)\n', 'let t', 'lower', NO % ('lower', 'str[]'))
err_c('err_lower_none', ['lower(): no argument is 243 (L-d)'],
      'let t = lower()\n', 'let t', 'lower', NO % ('lower', ''))
err_c('err_lower_two', ['lower("a", "b"): two arguments are 243 (L-d)'],
      'let t = lower("a", "b")\n', 'let t', 'lower', NO % ('lower', 'str, str'))
err_c('err_str_array', ['str(v) of an f64[]: str takes scalars only (243 at the conversion node; Decision 46)'],
      'let v = zeros(2)\nlet s = str(v)\n', 'let s', 'str', NO % ('str', 'f64[]'))
err_c('err_str_noarg', ['str(): the grammar\'s conv_type "(" expr ")" needs an expression, so pass 1 reports',
                        'unexpected token \')\' at the ) (LANGUAGE.md Appendix A; DESIGN.md 3.4 conv pops 1)'],
      'let s = str()\n', 'let s', ')', "unexpected token ')'")
err_c('err_args_arg', ['args(1): args takes no argument (243, as now(1); L-d)'],
      'let a = args(1)\n', 'let a', 'args', NO % ('args', 'i64'))
err_c('err_error_missing_return', ['error does not end a path (LANGUAGE.md 8.1): fn f() -> i64 { error("x") } is missing',
                                   'return (223) at the fn (DESIGN.md 0, the information item of 4g)'],
      'fn f() -> i64 {\n    error("x")\n}\nprintf("%d\\n", f())\n', 'fn f', 'fn', 'missing return')
LONG_A = 'a' * 2100
LONG_B = 'b' * 2100
err_c('err_const_str_too_long', ['a str constant joining two literals of 2 100 bytes each is longer than 4 096 bytes:',
                                 'program too large: strings (400) at the const (LANGUAGE.md 7.2; lead decision L-f)'],
      'const S = "%s" +\n    "%s"\nprintf("%%s\\n", S)\n' % (LONG_A, LONG_B), 'const S', 'const',
      'program too large: strings')
err_c('err_const_str_part_too_long', ['L-f covers every str value computed while evaluating a constant: a part of 4 200',
                                      'bytes whose comparison is a bool constant is 400 at the const'],
      'const B = "%s" +\n    "%s" < "c"\nprintf("%%d\\n", B)\n' % (LONG_A, LONG_B), 'const B', 'const',
      'program too large: strings')
err_c('err_ns_str_fixed_let', ['a fixed-size str type in a let annotation is still strings until 4g-2, at its type node',
                               '(DESIGN.md 2.6.2 phase-rule row 4g-1)'],
      'let a: str[3] = ["a", "b", "c"]\n', 'let a', 'str[3]', 'not supported yet: strings')


# ============================================================ re-derived Decision-25 goldens (L-i)
def tail_err(name, comment, body, line, col, msg):
    """The layout of res_cases.py's tail_err: the program on lines 1-3, the comment after it."""
    write(os.path.join(ERRORS, name + '.sea'), body + '// %s -- %s\n' % (name, comment))
    write(os.path.join(ERRORS, name + '.err'), '%s.sea:%d:%d: error: %s\n' % (name, line, col, msg))
    write(os.path.join(ERRORS, name + '.status'), '1\n')
    COUNT['errors'] += 1


def type_col(body, line, text):
    return body.split('\n')[line - 1].index(text) + 1


UNK = 'unknown struct type'
NOVAL_CALLTYPE = 'const A: f64 = f()\nfn f() -> Q { return 1 }\n'
NOVAL_ERRTYPE = 'const B = A + 1 % 0\nconst A = f()\nfn f() -> Q { return 1 }\n'
NOVAL_SHORT = ('const D = B || 9223372036854775807 + 1 > 0\n'
               'const B: bool = false && f() == 1.0\nfn f() -> Q { return 1 }\n')
tail_err('err_const_noval_calltype', 'A: f64 = f() with a faulty f: the undeclared struct type Q of its result is the '
         'error (229, seaname, in the signature), A is not evaluated (LANGUAGE.md 7.2; DESIGN.md 6.2, Decision 25 '
         'refined, lead decision L-i)', NOVAL_CALLTYPE, 2, type_col(NOVAL_CALLTYPE, 2, 'Q'), UNK)
tail_err('err_const_noval_errtype', 'A has the error type and no value, so B is not evaluated and its 1 % 0 reports '
         'nothing; the undeclared struct type Q of f\'s result is the first error (LANGUAGE.md 7.2; DESIGN.md 3.5.2, '
         'Decision 25, lead decision L-i)', NOVAL_ERRTYPE, 3, type_col(NOVAL_ERRTYPE, 3, 'Q'), UNK)
tail_err('err_const_noval_shortcircuit', 'B holds a faulty call behind false && and has no value, so D (first) is not '
         'evaluated and its overflow is not reported; the error is f\'s undeclared result type Q (LANGUAGE.md 7.2; '
         'DESIGN.md 6.2, Decision 25 refined, lead decision L-i)', NOVAL_SHORT, 3, type_col(NOVAL_SHORT, 3, 'Q'), UNK)
assert type_col(NOVAL_CALLTYPE, 2, 'Q') == 11

# ============================================================ the goldens step 4g-1 retires (DESIGN.md 6.2)
for old in ('err_ns_string_let', 'err_ns_string_type', 'err_ns_str_literal', 'err_ns_arr_str_elem', 'err_ns_match'):
    for ext_ in ('.sea', '.err', '.status', '.out'):
        remove(os.path.join(ERRORS, old + ext_))

print('str4g_cases: %d programs, %d errors' % (COUNT['programs'], COUNT['errors']))
