"""Sub-phase 6d, T1: the write_json program and error tests of DESIGN.md 6.2 ("Phase-6 tests", "6d, write_json").

Run with `timeout 120 uv run --no-project python tests/vectors/json6_cases.py` (after `call6_cases.py`, whose helpers
it imports). It writes

  programs/json_*        write_json (LANGUAGE.md 11.4; DESIGN.md 2.11.6, 3.5.7 step 4): each program prints what it
                         prints (usually `done`) and leaves JSON files; every file is in NAME.expect/ (compared
                         byte for byte by tests/run.sh, which also fails on any file that is not expected)
  errors/r_json_*        run-time errors of write_json: a path in a missing directory, a path that is a directory
                         (a fixture and `.`), an empty path, a path below a file, a run-time error after a
                         completed write_json (the file stays complete), a failing second call, an error in the
                         value or the path expression (no file is created: pass 2b binds the path and the value
                         before `jopen`, DESIGN.md 3.5.7 step 4)
  errors/err_json_*      243 of write_json: no value, no argument, an extra argument, a path that is not a str
  and deletes the retired errors/err_ns_lib_write_json.

Every expected byte is derived from LANGUAGE.md 11.4 and DESIGN.md 2.11.6, never from a run of the compiler: each
program has a Python mirror beside it. The mirror builds the JSON value tree in Python (exact integers for `i64`,
IEEE binary64 floats for `f64`, byte strings for `str`, tuples of pairs for structs and records, lists for
arrays; a matrix with a zero extent is the empty list) and `encode` writes it by the layout of 2.11.6: two spaces of
indentation per level, one member or element per line, `"key": value`, `{}` and `[]` for the empty cases, LF after
the top value. A finite `f64` is the exact printf `%.17g` of tests/vectors/progfmt.py (also compared with Python's
own `%.17g`, which is an exact conversion too), NaN and the infinities are `null`, `-0.0` is `-0`; a `str` is
written with `"`, `\\` and the bytes below 0x20 escaped (`\\n`, `\\t`, `\\u00xx` with lowercase hex digits), every
other byte as it is. The Sea literals of the f64 and i64 values are generated from the same Python values.

Implementer readings (flagged in the T1 report): the keys are the field names in declaration order, whatever the
order of a struct literal; a struct with no fields is `{}` and an array of them has one `{}` per element (a
non-empty array, LANGUAGE.md 11.4 "an empty object is {}"); a fixed-size vector or matrix of structs (a type that
exists by annotation only, LANGUAGE.md 4.5) is written like the dynamic one (L-ce names the scalar kinds; the
struct arrays are the same loop over a path of locals); `write_json("", v)` fails with ENOENT on both libcs
(`open("")`), the spec naming no empty path.
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import call6_cases as C  # noqa: E402  (the helpers of 6b: source, err_r, line_of, wbytes, remove, g17)

PROGRAMS = C.PROGRAMS
ERRORS = C.ERRORS
COUNT = C.COUNT
INF = math.inf
NAN = math.nan


# ---------------------------------------------------------------------------- the JSON mirror
class O:
    """A struct or record: (key, value) pairs in declaration order."""

    def __init__(self, *pairs):
        self.pairs = list(pairs)


def mat(r, c, rows):
    """A matrix value: an array of rows, `[]` when it has no element (also r x 0)."""
    if r == 0 or c == 0:
        assert not any(rows) or rows == []
        return []
    assert len(rows) == r and all(len(x) == c for x in rows)
    return [list(x) for x in rows]


def transpose(rows):
    return [list(x) for x in zip(*rows)]


def jnum(x):
    if math.isnan(x) or math.isinf(x):
        return b'null'
    s = C.g17(x)
    assert s == '%.17g' % x, (s, '%.17g' % x)
    return s.encode()


def jstr(b):
    out = bytearray(b'"')
    for ch in b:
        if ch == 0x22:
            out += b'\\"'
        elif ch == 0x5C:
            out += b'\\\\'
        elif ch == 0x0A:
            out += b'\\n'
        elif ch == 0x09:
            out += b'\\t'
        elif ch < 0x20:
            out += b'\\u%04x' % ch
        else:
            out.append(ch)
    out += b'"'
    return bytes(out)


def enc(v, d=0):
    """The value at depth d, without a trailing LF (DESIGN.md 2.11.6 "Layout")."""
    ind = b'  ' * (d + 1)
    if isinstance(v, bool):
        return b'true' if v else b'false'
    if isinstance(v, int):
        assert -2 ** 63 <= v < 2 ** 63
        return str(v).encode()
    if isinstance(v, float):
        return jnum(v)
    if isinstance(v, bytes):
        return jstr(v)
    if isinstance(v, O):
        if not v.pairs:
            return b'{}'
        body = b',\n'.join(ind + jstr(k.encode()) + b': ' + enc(x, d + 1) for k, x in v.pairs)
        return b'{\n' + body + b'\n' + b'  ' * d + b'}'
    assert isinstance(v, list)
    if not v:
        return b'[]'
    body = b',\n'.join(ind + enc(x, d + 1) for x in v)
    return b'[\n' + body + b'\n' + b'  ' * d + b']'


def top(v):
    return enc(v, 0) + b'\n'


# ---------------------------------------------------------------------------- Sea literal helpers
def fl(x):
    """An f64 literal of the Python float x (the nearest double of the text is x)."""
    if x != x:
        return 'nan'
    if x == INF:
        return 'inf'
    if x == -INF:
        return '(-inf)'
    r = repr(abs(x))
    if 'e' not in r and '.' not in r:
        r += '.0'
    s = ('-' if math.copysign(1.0, x) < 0 else '') + r
    assert float(s) == x or (x == 0.0 and float(s) == 0.0)
    return s


def il(n):
    return str(n)


def bl(b):
    return 'true' if b else 'false'


def ssrc(b):
    """A Sea string literal for the bytes b (LANGUAGE.md 3.5)."""
    out = '"'
    for ch in b:
        if ch == 0x22:
            out += '\\"'
        elif ch == 0x5C:
            out += '\\\\'
        elif ch == 0x0A:
            out += '\\n'
        elif ch == 0x09:
            out += '\\t'
        elif 0x20 <= ch < 0x7F:
            out += chr(ch)
        else:
            out += '\\x%02x' % ch
    return out + '"'


def vec(items):
    return '[' + ', '.join(items) + ']'


def rowsrc(rows, f):
    return '[' + '; '.join(', '.join(f(x) for x in r) for r in rows) + ']'


def record(fields, indent=''):
    """A multi-line record literal of (name, source) pairs."""
    return '{\n' + ''.join('%s    %s: %s,\n' % (indent, k, s) for k, s in fields) + indent + '}'


# ---------------------------------------------------------------------------- writers
def jprog(name, comment, body, out, files):
    """programs/NAME.sea, NAME.out and NAME.expect/<file> for every (path, bytes) of files."""
    C.prog(name, comment, body, out)
    base = os.path.join(PROGRAMS, name + '.expect')
    put_expect(base, files)


def put_expect(base, files):
    for path, data in files.items():
        full = os.path.join(base, path)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        C.wbytes(full, data)


def clean_expect(name):
    """Remove a stale NAME.expect/ of an earlier run before it is written again."""
    for root in (PROGRAMS, ERRORS):
        d = os.path.join(root, name + '.expect')
        if os.path.isdir(d):
            for dp, dn, fn in os.walk(d, topdown=False):
                for f in fn:
                    os.remove(os.path.join(dp, f))
                for x in dn:
                    os.rmdir(os.path.join(dp, x))
            os.rmdir(d)


DONE = 'printf("done\\n")\n'
DONE_OUT = 'done\n'


# ---------------------------------------------------------------------------- shared values
F64_LIST = [0.1, -0.0, 1e22, NAN, INF, -INF, 100.0, 1.0 / 3.0, 5e-324, -2.5]
I64_LIST = [0, 1, -1, 9223372036854775807, -9223372036854775808, 9007199254740993, 1000000]
STR_LIST = [b'a', b'b"c', b'', b'd\ne', b'\\']
M23 = [[1.0, 2.0, 3.0], [4.0, 5.5, -6.0]]


# ---------------------------------------------------------------------------- programs
def json_top_scalar():
    items = [
        ('f.json', '1.5', 1.5),
        ('i.json', '42', 42),
        ('b.json', 'true', True),
        ('s.json', '"text"', b'text'),
        ('n.json', 'nan', NAN),
        ('neg.json', '-inf', -INF),
        ('pos.json', 'inf', INF),
        ('nz.json', '-0.0', -0.0),
        ('h.json', '100.0', 100.0),
        ('big.json', '1e22', 1e22),
        ('min.json', '-9223372036854775808', -9223372036854775808),
        ('max.json', '9223372036854775807', 9223372036854775807),
        ('pi.json', 'pi', math.pi),
        ('third.json', '1.0 / 3.0', 1.0 / 3.0),
        ('tenth.json', '0.1', 0.1),
        ('false.json', 'false', False),
        ('empty.json', '""', b''),
    ]
    body = ''.join('write_json("%s", %s)\n' % (p, s) for p, s, _ in items) + DONE
    jprog('json_top_scalar',
          ['write_json of a top-level scalar of each type, one file each: the value then one LF (LANGUAGE.md 11.4); finite f64',
           'as %.17g (0.1, 1/3, pi, 100 as `100`, 1e22 as `1e+22`, -0.0 as `-0`), NaN and the infinities as null, i64 -2^63',
           'and 2^63-1, a bool, a str, the empty str'],
          body, DONE_OUT, {p: top(v) for p, _, v in items})


def json_f64_values():
    zero = 0.0
    fields = [
        ('zero', '0.0', 0.0),
        ('negzero', '-0.0', -0.0),
        ('one', '1.0', 1.0),
        ('hundred', '100.0', 100.0),
        ('neg', '-2.5', -2.5),
        ('tenth', '0.1', 0.1),
        ('fifth', '0.2', 0.2),
        ('sum', '0.1 + 0.2', 0.1 + 0.2),
        ('third', '1.0 / 3.0', 1.0 / 3.0),
        ('twothirds', '2.0 / 3.0', 2.0 / 3.0),
        ('pi', 'pi', math.pi),
        ('eps', 'eps', 2.0 ** -52),
        ('p53', '9007199254740992.0', 9007199254740992.0),
        ('e16', '1e16', 1e16),
        ('e17', '1e17', 1e17),
        ('e22', '1e22', 1e22),
        ('e300', '1e300', 1e300),
        ('em5', '1e-5', 1e-5),
        ('em300', '1e-300', 1e-300),
        ('quarter', '123456789.125', 123456789.125),
        ('long', '123456789012345678.0', 123456789012345678.0),
        ('tiny', '5e-324', 5e-324),
        ('minnorm', '2.2250738585072014e-308', 2.2250738585072014e-308),
        ('huge', '1.7976931348623157e308', 1.7976931348623157e308),
        ('nan', 'nan', NAN),
        ('inf', 'inf', INF),
        ('ninf', '-inf', -INF),
        ('div_pos', '1.0 / zero', INF),
        ('div_neg', '-1.0 / zero', -INF),
        ('div_nan', 'zero / zero', NAN),
        ('overflow', 'huge_in * 10.0', INF),
    ]
    body = ('let zero = 0.0\nlet huge_in = 1e308\nlet r = ' + record([(k, s) for k, s, _ in fields])
            + '\nwrite_json("f64.json", r)\n' + DONE)
    jprog('json_f64_values',
          ['a record of f64 fields written as %.17g (LANGUAGE.md 11.4): values that need 17 digits (0.1, 0.1 + 0.2, 1/3, 2/3,',
           'pi), integral values without a point (`100`, 2^53, 1e16), exponent forms (`1e+17`, `1e-05` written with two',
           'digits, subnormals, the largest double), -0.0 as `-0`, NaN and the infinities as null (also computed ones)'],
          body, DONE_OUT, {'f64.json': top(O(*[(k, v) for k, _, v in fields]))})
    del zero


def json_i64_values():
    k = 3037000499
    fields = [
        ('zero', '0', 0),
        ('one', '1', 1),
        ('minus_one', '-1', -1),
        ('max', '9223372036854775807', 9223372036854775807),
        ('min', '-9223372036854775808', -9223372036854775808),
        ('above_2p53', '9007199254740993', 9007199254740993),
        ('million', '1_000_000', 1000000),
        ('neg_million', '-1000000', -1000000),
        ('half_range', '4611686018427387904', 4611686018427387904),
        ('square', 'k * k', k * k),
        ('diff', '7 - 10', -3),
        ('hex', '0xFF', 255),
    ]
    body = ('let k = 3037000499\nlet r = ' + record([(a, s) for a, s, _ in fields])
            + '\nwrite_json("i64.json", r)\n' + DONE)
    jprog('json_i64_values',
          ['a record of i64 fields written in decimal (LANGUAGE.md 11.4): 0, negative values, -2^63 and 2^63-1, 2^53 + 1 (exact:',
           'an i64 is never written through f64), a digit-grouped and a hexadecimal literal, a computed product'],
          body, DONE_OUT, {'i64.json': top(O(*[(a, v) for a, _, v in fields]))})


ALL_CTL = bytes(range(0x20))
HIGH = bytes(range(0x80, 0x100))


def json_strings():
    runtime_src = 'format("k%d\\t%s", 7, "q\\"")'
    runtime_val = b'k7\tq"'
    fields = [
        ('plain', '"plain text"', b'plain text'),
        ('empty', '""', b''),
        ('quote', ssrc(b'say "hi"'), b'say "hi"'),
        ('backslash', ssrc(b'a\\b\\\\c'), b'a\\b\\\\c'),
        ('lf', ssrc(b'one\ntwo\n'), b'one\ntwo\n'),
        ('tab', ssrc(b'a\tb'), b'a\tb'),
        ('cr', ssrc(b'a\rb'), b'a\rb'),
        ('nul', ssrc(b'a\x00b'), b'a\x00b'),
        ('ctl01', ssrc(b'x\x01y'), b'x\x01y'),
        ('ctl1f', ssrc(b'x\x1fy'), b'x\x1fy'),
        ('ctl_all', ssrc(ALL_CTL), ALL_CTL),
        ('del7f', ssrc(b'x\x7fy'), b'x\x7fy'),
        ('space_tilde', ssrc(b' ~ /'), b' ~ /'),
        ('high', ssrc(HIGH), HIGH),
        ('utf8', ssrc('café € \U0001F600'.encode('utf-8')), 'café € \U0001F600'.encode('utf-8')),
        ('utf8_escape', '"\\u{e9}\\u{20AC}\\u{1F600}"', 'é€\U0001F600'.encode('utf-8')),
        ('runtime', runtime_src, runtime_val),
        ('concat', '"a" + "\\n" + "b\\"c"', b'a\nb"c'),
    ]
    sv = [b'p', b'q"r', b'', b'\\', b'x\ty\n', b'\x01\xff']
    body = ('let r = ' + record([(k, s) for k, s, _ in fields])
            + '\nwrite_json("strings.json", r)\n'
            + 'write_json("top.json", %s)\n' % ssrc(ALL_CTL + b'"\\' + HIGH)
            + 'let list = ' + vec(ssrc(x) for x in sv) + '\nwrite_json("list.json", list)\n' + DONE)
    jprog('json_strings',
          ['str values with every kind of byte (LANGUAGE.md 11.4): `"`, `\\`, LF and TAB as `\\n` `\\t`, the other bytes below 0x20',
           '(NUL, CR, 0x01, 0x1F, all 32 of them) as `\\u00xx` with lowercase hex digits, 0x7F, a space, `~` and `/` as they are,',
           'bytes 0x80-0xFF and valid UTF-8 unchanged (never decoded); strings built at run time (`format`, `+`); a top-level',
           'str and a str[] with the same bytes'],
          body, DONE_OUT,
          {'strings.json': top(O(*[(k, v) for k, _, v in fields])),
           'top.json': top(ALL_CTL + b'"\\' + HIGH),
           'list.json': top(sv)})


def json_vectors():
    a = F64_LIST
    b = I64_LIST
    c = [True, False, True]
    s = STR_LIST
    scaled = [x * 2.0 for x in a]
    fields = [
        ('a', 'a', a), ('b', 'b', b), ('c', 'c', c), ('d', 'd', s),
        ('ea', 'ea', []), ('ei', 'ei', []), ('eb', 'eb', []), ('es', 'es', []),
        ('one', 'one', [2.5]),
        ('z', 'zeros(3)', [0.0, 0.0, 0.0]),
        ('o', 'ones(2)', [1.0, 1.0]),
        ('fi', 'filled(7, 2)', [7, 7]),
        ('fb', 'filled(true, 2)', [True, True]),
        ('fs', 'filled("x", 2)', [b'x', b'x']),
        ('scaled', 'a * 2.0', scaled),
    ]
    body = ('let a: f64[] = ' + vec(fl(x) for x in a) + '\n'
            + 'let b: i64[] = ' + vec(il(x) for x in b) + '\n'
            + 'let c: bool[] = ' + vec(bl(x) for x in c) + '\n'
            + 'let d: str[] = ' + vec(ssrc(x) for x in s) + '\n'
            + 'let ea: f64[] = []\nlet ei: i64[] = []\nlet eb: bool[] = []\nlet es: str[] = []\n'
            + 'let one: f64[] = [2.5]\n'
            + 'write_json("vec_f64.json", a)\nwrite_json("vec_i64.json", b)\nwrite_json("vec_bool.json", c)\n'
            + 'write_json("vec_str.json", d)\nwrite_json("vec_empty.json", ea)\n'
            + 'let r = ' + record([(k, e) for k, e, _ in fields]) + '\nwrite_json("vectors.json", r)\n' + DONE)
    files = {'vec_f64.json': top(a), 'vec_i64.json': top(b), 'vec_bool.json': top(c), 'vec_str.json': top(s),
             'vec_empty.json': top([]), 'vectors.json': top(O(*[(k, v) for k, _, v in fields]))}
    jprog('json_vectors',
          ['dynamic vectors of every element type as flat arrays, one element per line (LANGUAGE.md 11.4): f64 (0.1, -0.0, 1e22,',
           'NaN and the infinities as null, 100 as `100`), i64 (the extremes, 2^53 + 1), bool, str (with escapes); empty vectors',
           'of each type and a vector of length 1 as `[]` / one line; zeros, ones and filled; an elemental result; each as a',
           'top-level value and as a record field (depth 1)'],
          body, DONE_OUT, files)


def json_matrices():
    mi = [[1, 2], [3, 4], [5, 6]]
    mb = [[True, False], [False, True]]
    ms = [[b'a', b'b'], [b'c', b'd\n']]
    mn = [[NAN, INF], [-INF, 0.0]]
    scaled = [[x * 2.0 for x in r] for r in M23]
    fields = [
        ('m23', 'm23', mat(2, 3, M23)),
        ('mi', 'mi', mat(3, 2, mi)),
        ('mb', 'mb', mat(2, 2, mb)),
        ('ms', 'ms', mat(2, 2, ms)),
        ('mn', 'mn', mat(2, 2, mn)),
        ('m11', 'filled(7.0, 1, 1)', [[7.0]]),
        ('t', 'm23.T', mat(3, 2, transpose(M23))),
        ('z03', 'zeros(0, 3)', []),
        ('z30', 'zeros(3, 0)', []),
        ('i03', 'filled(0, 0, 3)', []),
        ('i30', 'filled(1, 3, 0)', []),
        ('b03', 'filled(true, 0, 3)', []),
        ('b30', 'filled(false, 3, 0)', []),
        ('s03', 'filled("", 0, 3)', []),
        ('s30', 'filled("", 3, 0)', []),
        ('z00', 'zeros(0, 0)', []),
        ('scaled', 'm23 * 2.0', mat(2, 3, scaled)),
    ]
    body = ('let m23: f64[,] = ' + rowsrc(M23, fl) + '\n'
            + 'let mi: i64[,] = ' + rowsrc(mi, il) + '\n'
            + 'let mb: bool[,] = ' + rowsrc(mb, bl) + '\n'
            + 'let ms: str[,] = ' + rowsrc(ms, ssrc) + '\n'
            + 'let mn: f64[,] = ' + rowsrc(mn, fl) + '\n'
            + 'write_json("mat23.json", m23)\nwrite_json("mat_i64.json", mi)\nwrite_json("mat_str.json", ms)\n'
            + 'write_json("mat_empty.json", zeros(0, 3))\n'
            + 'let r = ' + record([(k, e) for k, e, _ in fields]) + '\nwrite_json("matrices.json", r)\n' + DONE)
    files = {'mat23.json': top(mat(2, 3, M23)), 'mat_i64.json': top(mat(3, 2, mi)), 'mat_str.json': top(mat(2, 2, ms)),
             'mat_empty.json': top([]), 'matrices.json': top(O(*[(k, v) for k, _, v in fields]))}
    jprog('json_matrices',
          ['matrices as arrays of rows, element (i, j) at position j of row i (LANGUAGE.md 11.4; DESIGN.md 2.11.6): 2 x 3 f64,',
           '3 x 2 i64, 2 x 2 bool and str, NaN and infinities as null, 1 x 1, the transpose view m23.T (3 rows), an',
           'elemental result, and the matrices with no element (0 x 3, 3 x 0, 0 x 0 of f64, i64, bool and str) as `[]`;',
           'each as a top-level value and as a record field'],
          body, DONE_OUT, files)


STRUCT_DECLS = r'''struct Scalars {
    f: f64
    n: i64
    b: bool
    s: str
}
struct Inner {
    v: f64
    tag: str
}
struct Mid {
    id: i64
    inner: Inner
    ok: bool
}
struct Outer {
    name: str
    mid: Mid
    extra: Inner
}
'''


def json_struct():
    sc = O(('f', 0.1), ('n', -7), ('b', True), ('s', b'hello'))
    inner1 = O(('v', 2.5), ('tag', b'one'))
    inner2 = O(('v', -0.0), ('tag', b'two "2"'))
    outer = O(('name', b'outer'), ('mid', O(('id', 9), ('inner', inner1), ('ok', False))), ('extra', inner2))
    rec = O(('a', 1), ('b', 2.5), ('c', b'x'), ('d', False),
            ('inner', O(('p', 1.0), ('q', O(('r', b'deep'), ('s', INF))))))
    body = (STRUCT_DECLS
            + 'write_json("scalars.json", Scalars { f: 0.1, n: -7, b: true, s: "hello" })\n'
            + '// the fields come out in declaration order, not in the order of the literal\n'
            + 'write_json("reordered.json", Scalars { s: "hello", b: true, n: -7, f: 0.1 })\n'
            + 'let o = Outer {\n'
            + '    extra: Inner { tag: "two \\"2\\"", v: -0.0 },\n'
            + '    mid: Mid { ok: false, inner: Inner { v: 2.5, tag: "one" }, id: 9 },\n'
            + '    name: "outer",\n'
            + '}\n'
            + 'write_json("nested.json", o)\n'
            + 'write_json("record.json", { a: 1, b: 2.5, c: "x", d: false, inner: { p: 1.0, q: { r: "deep", s: inf } } })\n'
            + DONE)
    jprog('json_struct',
          ['a struct of each scalar type, the same struct written from a literal in another field order (keys are in declaration',
           'order), nested structs three levels deep (indentation 2 per level, LANGUAGE.md 11.4) with a NaN-free negative',
           'zero, and a record literal with nested records (keys in the order written)'],
          body, DONE_OUT,
          {'scalars.json': top(sc), 'reordered.json': top(sc), 'nested.json': top(outer), 'record.json': top(rec)})


def json_record_arrays():
    counts = [3, 0, 12, 5]
    pct = [0.135, 2.5, 50.0, 97.5, 99.865]
    dev = [[0.5, -0.25], [1.5, 2.0], [-3.0, NAN]]
    names = [b'bottom chord', b'top chord']
    lim = O(('lo', 0.0), ('hi', 1.0), ('grid', [1.5, 2.5]))
    out = O(('workload', b'w5_tolerance_mc'), ('n_sample', 100000), ('lcg_final', 6364136223846793005),
            ('yield', 0.987654321), ('hist_counts', counts), ('pct', pct), ('first_dev', mat(3, 2, dev)),
            ('names', names), ('limits', lim), ('rank', [3, 1, 2]), ('empty_f', []), ('empty_m', []))
    body = ('let counts: i64[] = ' + vec(il(x) for x in counts) + '\n'
            + 'let dev: f64[,] = ' + rowsrc(dev, fl) + '\n'
            + 'let names = ' + vec(ssrc(x) for x in names) + '\n'
            + 'let ef: f64[] = []\n'
            + 'let rnk: i64[] = [2, 0, 1]\n'
            + 'let out = {\n'
            + '    workload: "w5_tolerance_mc",\n'
            + '    n_sample: 100000,\n'
            + '    lcg_final: 6364136223846793005,\n'
            + '    yield: 0.987654321,\n'
            + '    hist_counts: counts,\n'
            + '    pct: [0.135, 2.5, 50.0, 97.5, 99.865],\n'
            + '    first_dev: dev,\n'
            + '    names: names,\n'
            + '    limits: { lo: 0.0, hi: 1.0, grid: [1.5, 2.5] },\n'
            + '    rank: rnk + 1,\n'
            + '    empty_f: ef,\n'
            + '    empty_m: zeros(0, 4),\n'
            + '}\n'
            + 'write_json("w5_shape.json", out)\n' + DONE)
    jprog('json_record_arrays',
          ['W5\'s export shape (LANGUAGE.md 2.5 Appendix D, 11.4): one record of scalars, a dynamic i64 vector, a fixed-size f64',
           'vector (a literal), a 3 x 2 matrix with a NaN, a str[], a nested record with a fixed vector, an i64 expression',
           '(rnk + 1), an empty vector and a 0 x 4 matrix (both `[]`), the field named `yield`'],
          body, DONE_OUT, {'w5_shape.json': top(out)})


def json_struct_empty():
    rec = O(('e', O()), ('n', 1), ('list', [O(), O()]), ('none', []), ('grid', [[O(), O()], [O(), O()]]))
    body = (r'''struct E {}
let two = [E {}, E {}]
let none: E[] = []
write_json("top.json", E {})
write_json("vec.json", two)
write_json("none.json", none)
let r = {
    e: E {},
    n: 1,
    list: two,
    none: none,
    grid: filled(E {}, 2, 2),
}
write_json("rec.json", r)
''' + DONE)
    jprog('json_struct_empty',
          ['a struct with no fields is `{}` (LANGUAGE.md 4.6, 11.4: an empty object is `{}`): as the top value, as a member, as the',
           'elements of a vector (one `{}` per element, a non-empty array), as an empty vector `[]` and as the elements of a 2 x 2',
           'matrix (array of rows)'],
          body, DONE_OUT,
          {'top.json': top(O()), 'vec.json': top([O(), O()]), 'none.json': top([]), 'rec.json': top(rec)})


PDECL = r'''struct P {
    id: i64
    name: str
    w: f64
}
struct Q {
    k: i64
    vals: f64[]
    grid: f64[,]
}
'''


def p_src(i, name, w):
    return 'P { id: %d, name: %s, w: %s }' % (i, ssrc(name), fl(w))


def p_val(i, name, w):
    return O(('id', i), ('name', name), ('w', w))


def json_struct_arrays():
    p = [(1, b'one', 0.5), (2, b'tw"o', -1.5), (3, b'', NAN)]
    ps = [p_val(*x) for x in p]
    grid = [[(10 * i + j, b'g%d%d' % (i, j), i + j / 4.0) for j in range(3)] for i in range(2)]
    gv = [[p_val(*x) for x in r] for r in grid]
    q0 = O(('k', 1), ('vals', [0.5, 1.5]), ('grid', mat(2, 2, [[1.0, 2.0], [3.0, 4.0]])))
    q1 = O(('k', 2), ('vals', []), ('grid', []))
    recs = [O(('a', 1), ('b', b'x')), O(('a', 2), ('b', b'y'))]
    fields = [
        ('items', 'ps', ps), ('grid', 'm', mat(2, 3, gv)), ('one', 'one', [ps[0]]), ('none', 'none', []),
        ('g20', 'filled(pp, 2, 0)', []), ('g03', 'filled(pp, 0, 3)', []), ('qs', 'qs', [q0, q1]),
        ('recs', 'recs', recs),
    ]
    body = (PDECL
            + 'let ps = ' + vec(p_src(*x) for x in p) + '\n'
            + 'let pp = ' + p_src(*p[0]) + '\n'
            + 'let one = [pp]\nlet none: P[] = []\n'
            + 'let m = [' + '; '.join(', '.join(p_src(*x) for x in r) for r in grid) + ']\n'
            + 'let qs = [Q { k: 1, vals: [0.5, 1.5], grid: [1.0, 2.0; 3.0, 4.0] }, Q { k: 2, vals: zeros(0), grid: zeros(0, 2) }]\n'
            + 'let recs = [{ a: 1, b: "x" }, { a: 2, b: "y" }]\n'
            + 'write_json("vec.json", ps)\nwrite_json("mat.json", m)\nwrite_json("recs.json", recs)\n'
            + 'write_json("one.json", one)\nwrite_json("none.json", none)\n'
            + 'write_json("g20.json", filled(pp, 2, 0))\nwrite_json("g03.json", filled(pp, 0, 3))\n'
            + 'let r = ' + record([(k, e) for k, e, _ in fields]) + '\nwrite_json("rec.json", r)\n' + DONE)
    files = {'vec.json': top(ps), 'mat.json': top(mat(2, 3, gv)), 'recs.json': top(recs), 'one.json': top([ps[0]]),
             'none.json': top([]), 'g20.json': top([]), 'g03.json': top([]),
             'rec.json': top(O(*[(k, v) for k, _, v in fields]))}
    jprog('json_struct_arrays',
          ['arrays of structs and records (LANGUAGE.md 11.4): a vector of 3 structs (one str with a quote, a NaN field as null), a',
           '2 x 3 matrix of structs (array of rows, element (i, j) at position j of row i), a vector of 1, an empty vector, the 2 x 0',
           'and 0 x 3 matrices of structs (both `[]`), a vector of structs with a vector and a matrix field (empty ones `[]`),',
           'a vector of records; each top-level and as a record field (one level deeper)'],
          body, DONE_OUT, files)


FXDECL = r'''struct Fx {
    v: f64[3]
    k: i64[2]
    flags: bool[2]
    m: f64[2, 2]
    names: str[2]
    e: f64[0]
}
'''


def json_fixed():
    fx = O(('v', [1.0, 2.5, -0.0]), ('k', [4, 5]), ('flags', [True, False]), ('m', [[1.0, 2.0], [3.0, 4.0]]),
           ('names', [b'p', b'q\t']), ('e', []))
    rec = O(('pos', [1.0, 2.0]), ('grid', [[1, 2, 3], [4, 5, 6]]), ('fx', fx))
    body = (FXDECL
            + 'let fx = Fx { v: [1.0, 2.5, -0.0], k: [4, 5], flags: [true, false], m: [1.0, 2.0; 3.0, 4.0], names: ["p", "q\\t"], e: [] }\n'
            + 'write_json("fx.json", fx)\n'
            + 'write_json("v3.json", [1.0, 2.0, 3.0])\n'
            + 'write_json("k2.json", [1, -2])\n'
            + 'write_json("b2.json", [true, false])\n'
            + 'write_json("m22.json", [1.0, 2.0; 3.0, 4.0])\n'
            + 'write_json("m23.json", [1, 2, 3; 4, 5, 6])\n'
            + 'write_json("mb.json", [true, false; false, true])\n'
            + 'let ns: str[3] = ["a", "b\\n", "c"]\n'
            + 'write_json("str3.json", ns)\n'
            + 'let nm: str[2, 2] = ["a", "b"; "c", "d"]\n'
            + 'write_json("str22.json", nm)\n'
            + 'let z: f64[0] = []\nlet z2: f64[2, 0] = []\nlet z3: i64[0, 3] = []\n'
            + 'write_json("z.json", z)\nwrite_json("z2.json", z2)\nwrite_json("z3.json", z3)\n'
            + 'write_json("rec.json", { pos: [1.0, 2.0], grid: [1, 2, 3; 4, 5, 6], fx: fx })\n'
            + DONE)
    files = {'fx.json': top(fx), 'v3.json': top([1.0, 2.0, 3.0]), 'k2.json': top([1, -2]),
             'b2.json': top([True, False]), 'm22.json': top([[1.0, 2.0], [3.0, 4.0]]),
             'm23.json': top([[1, 2, 3], [4, 5, 6]]), 'mb.json': top([[True, False], [False, True]]),
             'str3.json': top([b'a', b'b\n', b'c']), 'str22.json': top([[b'a', b'b'], [b'c', b'd']]),
             'z.json': top([]), 'z2.json': top([]), 'z3.json': top([]), 'rec.json': top(rec)}
    jprog('json_fixed',
          ['fixed-size values and fields (LANGUAGE.md 4.5, 11.4; DESIGN.md 3.5.7 step 4, L-ce: `dyn` of the value under jvec / jmat):',
           'a struct with f64[3], i64[2], bool[2], f64[2,2], str[2] and f64[0] fields, fixed vectors and matrices as top-level',
           'values (f64, i64, bool), a fixed str[3] and str[2,2] by annotation, fixed arrays without elements (`[]`: f64[0],',
           'f64[2,0], i64[0,3]), fixed-size values as record fields; written exactly like dynamic arrays'],
          body, DONE_OUT, files)


def json_fixed_structs():
    p = [(1, b'a', 0.25), (2, b'b', 0.75), (3, b'c', 1.25), (4, b'd', 1.75)]
    pv = [p_val(*x) for x in p]
    body = (PDECL
            + 'let fv: P[2] = [' + ', '.join(p_src(*x) for x in p[:2]) + ']\n'
            + 'let fm: P[2, 2] = [' + p_src(*p[0]) + ', ' + p_src(*p[1]) + '; ' + p_src(*p[2]) + ', ' + p_src(*p[3]) + ']\n'
            + 'write_json("fv.json", fv)\nwrite_json("fm.json", fm)\n'
            + 'write_json("rec.json", { fv: fv, fm: fm })\n' + DONE)
    files = {'fv.json': top(pv[:2]), 'fm.json': top([[pv[0], pv[1]], [pv[2], pv[3]]]),
             'rec.json': top(O(('fv', pv[:2]), ('fm', [[pv[0], pv[1]], [pv[2], pv[3]]])))}
    jprog('json_fixed_structs',
          ['a fixed-size vector P[2] and matrix P[2,2] of structs (a type that exists by annotation only, LANGUAGE.md 4.5) are',
           'written like the dynamic arrays of structs: an array of objects, an array of rows (implementer reading, isolated in',
           'its own test), at the top level and as record fields'],
          body, DONE_OUT, files)


STRDECL = r'''struct Lab {
    name: str
    tags: str[]
    trio: str[3]
}
'''


def json_str_fields():
    lab = O(('name', b'lab "1"'), ('tags', [b't1', b'', b't3\n']), ('trio', [b'x', b'y', b'z']))
    lab2 = O(('name', b'lab-2'), ('tags', []), ('trio', [b'', b'', b'']))
    rec = O(('label', b'top'), ('tags', [b'a', b'b']), ('trio', [b'u\t', b'v', b'w']), ('labs', [lab, lab2]))
    body = (STRDECL
            + 'let l1 = Lab { name: "lab \\"1\\"", tags: ["t1", "", "t3\\n"], trio: ["x", "y", "z"] }\n'
            + 'let e: str[] = []\n'
            + 'let l2 = Lab { name: format("lab-%d", 2), tags: e, trio: ["", "", ""] }\n'
            + 'write_json("lab.json", l1)\n'
            + 'let trio: str[3] = ["u\\t", "v", "w"]\n'
            + 'write_json("trio.json", trio)\n'
            + 'write_json("rec.json", { label: "top", tags: ["a", "b"], trio: trio, labs: [l1, l2] })\n' + DONE)
    files = {'lab.json': top(lab), 'trio.json': top([b'u\t', b'v', b'w']), 'rec.json': top(rec)}
    jprog('json_str_fields',
          ['str members and arrays of str inside structs (LANGUAGE.md 4.4, 4.8, 11.4): a str field with quotes, a dynamic str[]',
           'field (with an empty string and an LF; and an empty one), a fixed str[3] field, a fixed str[3] value, a run-time',
           '`format` string, and a vector of such structs inside a record'],
          body, DONE_OUT, files)


def json_depth():
    m = [[1.0, 2.0], [3.0, 4.0]]
    d = O(('l1', O(('l2', O(('l3', O(('l4', [
        O(('l5', O(('l6', [1.5, 2.5]), ('m', mat(2, 2, m))))),
        O(('l5', O(('l6', [3.5, 4.5]), ('m', mat(2, 2, m))))),
    ]))))))))
    body = ('let m: f64[,] = ' + rowsrc(m, fl) + '\n'
            + 'let d = { l1: { l2: { l3: { l4: [{ l5: { l6: [1.5, 2.5], m: m } }, { l5: { l6: [3.5, 4.5], m: m } }] } } } }\n'
            + 'write_json("depth.json", d)\n' + DONE)
    jprog('json_depth',
          ['eight levels of nesting: records inside records, an array of records, a record with a fixed vector and a matrix at',
           'depth 7 (each level indented by two more spaces, closing brackets at the indentation of their opening line, LANGUAGE.md',
           '11.4 "Layout promised"; DESIGN.md 2.11.6, no depth limit)'],
          body, DONE_OUT, {'depth.json': top(d)})


def json_replace():
    first = O(('long', [1.5, 2.5, 3.5, 4.5, 5.5, 6.5, 7.5, 8.5, 9.5]), ('text', b'a rather long first version'))
    body = ('write_json("r.json", { long: [1.5, 2.5, 3.5, 4.5, 5.5, 6.5, 7.5, 8.5, 9.5], text: "a rather long first version" })\n'
            'write_json("r.json", 7)\n'
            'for k in 0..3 {\n'
            '    write_json("loop.json", { k: k, pad: "xxxxxxxxxxxxxxxxxxxx" })\n'
            '}\n'
            'write_json("loop.json", [k0()])\n'
            'fn k0() -> i64 {\n'
            '    return 0\n'
            '}\n' + DONE)
    del first
    jprog('json_replace',
          ['two write_json calls to one path: the second replaces the first (the file is truncated, not overwritten in place: the',
           'second version is shorter), a loop writing one path three times (the last version stays), and the same path written',
           'once more after the loop by a shorter value (LANGUAGE.md 11.4, 11.3)'],
          body, DONE_OUT, {'r.json': top(7), 'loop.json': top([0])})


def json_two_paths():
    body = ('let v: f64[] = [1.5, 2.5]\n'
            'write_json("one.json", v)\n'
            'write_json("two.json", { n: len(v), v: v })\n'
            'write_json("one.json", v)\n' + DONE)
    jprog('json_two_paths',
          ['two paths written in turn, the first one written again (the same bytes): both files stay complete and independent',
           '(LANGUAGE.md 11.4: one file per call)'],
          body, DONE_OUT, {'one.json': top([1.5, 2.5]), 'two.json': top(O(('n', 2), ('v', [1.5, 2.5])))})


def json_into_new_dir():
    body = ('make_dir("out")\n'
            'write_json("out/a.json", { ok: true })\n'
            'make_dir("out/sub")\n'
            'write_json("out/sub/b.json", [1, 2, 3])\n'
            'make_dir("out")\n'
            'write_json("out/a.json", { ok: false, n: 2 })\n' + DONE)
    jprog('json_into_new_dir',
          ['make_dir then write_json into the new directory and into a directory created below it (LANGUAGE.md 10.10, 11.3, 11.4);',
           'make_dir of the existing directory is no error and leaves the file, which the last write_json replaces'],
          body, DONE_OUT,
          {'out/a.json': top(O(('ok', False), ('n', 2))), 'out/sub/b.json': top([1, 2, 3])})


def json_arg_forms():
    rs = [O(('k', 1), ('s', b'item-1')), O(('k', 2), ('s', b'item-2'))]
    a = [[1.0, 2.5], [4.0, 0.5]]
    body = (r'''struct R {
    k: i64
    s: str
}
fn make(k: i64) -> R {
    printf("make %d\n", k)
    return R { k: k, s: format("item-%d", k) }
}
fn path(k: i64) -> str {
    printf("path %d\n", k)
    return format("p%d.json", k)
}
fn write_all(v: f64[], name: str) {
    write_json(name, v)
}
write_json(path(1), make(1))
for k in 0..3 {
    write_json(format("loop%d.json", k), { k: k, sq: k * k })
}
write_all([1.5, 2.5], "wa.json")
write_all(zeros(2), "wb.json")
let rs = [make(1), make(2)]
write_json("elem.json", rs[1])
let A: f64[,] = [1.0, 2.5; 4.0, 0.5]
write_json("col.json", A[:, 1])
write_json("row.json", A[0, :])
write_json("sum.json", sum(A.flat))
write_json("cat.json", "a" + "b")
write_json("expr.json", A * 2.0 + 1.0)
if len(rs) == 2 {
    write_json("if.json", true)
}
''' + DONE)
    files = {
        'p1.json': top(O(('k', 1), ('s', b'item-1'))),
        'loop0.json': top(O(('k', 0), ('sq', 0))),
        'loop1.json': top(O(('k', 1), ('sq', 1))),
        'loop2.json': top(O(('k', 2), ('sq', 4))),
        'wa.json': top([1.5, 2.5]),
        'wb.json': top([0.0, 0.0]),
        'elem.json': top(rs[1]),
        'col.json': top([a[0][1], a[1][1]]),
        'row.json': top(a[0]),
        'sum.json': top(a[0][0] + a[0][1] + a[1][0] + a[1][1]),
        'cat.json': top(b'ab'),
        'expr.json': top([[x * 2.0 + 1.0 for x in r] for r in a]),
        'if.json': top(True),
    }
    out = 'path 1\nmake 1\nmake 1\nmake 2\n' + DONE_OUT
    jprog('json_arg_forms',
          ['the forms of the arguments (LANGUAGE.md 11.4; DESIGN.md 3.5.7 step 4: the path and the value are bound once, in this',
           'order, before the file is opened): call results with effects (path before value, each called once: `path 1`,',
           '`make 1`), a path from `format` in a loop, a vector parameter written inside a function, an element, a column and a',
           'row slice, a reduction, a `str` concatenation, a matrix expression, a call inside an `if`'],
          body, out, files)


def json_big():
    n_i = 4000
    n_f = 2500
    iv = [k * 1000003 - 3000000000 for k in range(n_i)]
    fv = [k / 7.0 for k in range(n_f)]
    out = O(('n', n_i), ('a', iv), ('x', fv), ('tail', b'end'))
    body = ('var a = filled(0, %d)\n' % n_i
            + 'for k in 0..%d {\n    a[k] = k * 1000003 - 3000000000\n}\n' % n_i
            + 'var x = zeros(%d)\n' % n_f
            + 'for k in 0..%d {\n    x[k] = f64(k) / 7.0\n}\n' % n_f
            + 'write_json("big.json", { n: len(a), a: a, x: x, tail: "end" })\n' + DONE)
    jprog('json_big',
          ['a file of about 120 KB: an i64 vector of %d values and an f64 vector of %d values (k / 7, 17 digits) inside a record,' % (n_i, n_f),
           'so the 64 KiB buffer is flushed at least once in the middle of the numbers (LANGUAGE.md 11.4, DESIGN.md 2.11.6)'],
          body, DONE_OUT, {'big.json': top(out)})


def json_big_str():
    piece = b'ab"c\\d\n\te\x01'
    s = piece * 4096
    out = O(('s', s), ('n', len(s)))
    body = ('var s = ' + ssrc(piece) + '\n'
            + 'for k in 0..12 {\n    s = s + s\n}\n'
            + 'write_json("bigstr.json", { s: s, n: len(s) })\n' + DONE)
    jprog('json_big_str',
          ['one str of %d bytes whose escaped form is %d bytes (every 10-byte piece has a quote, a backslash, LF, TAB and 0x01,' % (len(s), len(jstr(s))),
           'written as 19 bytes), so the 64 KiB buffer boundary falls inside the escapes (LANGUAGE.md 11.4; DESIGN.md 2.11.6)'],
          body, DONE_OUT, {'bigstr.json': top(out)})


# ---------------------------------------------------------------------------- run-time errors
def r_expect(name, files):
    put_expect(os.path.join(ERRORS, name + '.expect'), files)


def r_json():
    C.err_r('r_json_missing_dir',
            ['write_json of a path in a missing directory: no directory is created, "No such file or directory" at the call\'s',
             'line; output printed before it is flushed first (LANGUAGE.md 11.4, 9.2; errors.inc CANNOT_OPEN)'],
            '''printf("start\\n")
write_json("nodir/a.json", 1.5)
printf("never\\n")
''', 'write_json("nodir/a.json"', "cannot open 'nodir/a.json': No such file or directory", out=b'start\n')

    C.err_r('r_json_is_dir',
            ['write_json of a path that is an existing directory (a fixture with a file inside): "Is a directory" (LANGUAGE.md',
             '11.4, 9.2); the fixture is untouched'],
            '''printf("before\\n")
write_json("d", [1, 2])
printf("after\\n")
''', 'write_json("d"', "cannot open 'd': Is a directory", out=b'before\n')
    os.makedirs(os.path.join(ERRORS, 'r_json_is_dir.files', 'd'), exist_ok=True)
    C.wbytes(os.path.join(ERRORS, 'r_json_is_dir.files', 'd', 'keep.txt'), b'kept\n')

    C.err_r('r_json_dot',
            ['write_json(".", v): the working directory is a directory, "Is a directory" (LANGUAGE.md 11.4, 9.2; git keeps no empty',
             'directory, so no fixture is used)'],
            '''write_json(".", { a: 1 })
''', 'write_json(".",', "cannot open '.': Is a directory")

    C.err_r('r_json_empty_path',
            ['write_json("") fails like open("") on both targets: "No such file or directory" (LANGUAGE.md 11.4, 9.2; unsure: the',
             'spec names no empty path, both libcs give ENOENT)'],
            '''write_json("", 1)
''', 'write_json("",', "cannot open '': No such file or directory")

    C.err_r('r_json_parent_is_file',
            ['write_json below a path that is a file: "Not a directory" (LANGUAGE.md 11.4, 9.2: the reason from the errno table)'],
            '''write_json("x/y.json", 1)
''', 'write_json("x/y.json"', "cannot open 'x/y.json': Not a directory", files={'x': b'data\n'})

    # a run-time error after a completed write_json: the file stays complete (LANGUAGE.md 9.2 step 3)
    v = [1.5, 2.5, -0.0]
    C.err_r('r_json_after_write',
            ['a run-time error after a completed write_json: standard output is flushed, the line goes to standard error and the',
             'file written before it stays complete, byte for byte (LANGUAGE.md 9.2 steps 1-3, 11.4)'],
            '''printf("written\\n")
write_json("ok.json", { v: [1.5, 2.5, -0.0], s: "kept" })
printf("now the error\\n")
error("boom %d", 7)
''', 'error("boom', 'boom 7', out=b'written\nnow the error\n')
    r_expect('r_json_after_write', {'ok.json': top(O(('v', v), ('s', b'kept')))})

    C.err_r('r_json_after_index',
            ['an index out of bounds after a completed write_json of a larger value: the earlier file is complete, the error is',
             'the original one (LANGUAGE.md 5.4, 9.2 step 3, 11.4)'],
            '''let v: f64[] = [1.0, 2.0]
write_json("v.json", v)
let k = 5
printf("%g\\n", v[k])
''', 'printf("%g\\n", v[k])', 'index 5 out of bounds for dimension 0 of extent 2')
    r_expect('r_json_after_index', {'v.json': top([1.0, 2.0])})

    C.err_r('r_json_second_fails',
            ['the first write_json completes, the second names a missing directory: the first file stays complete and the error',
             'names the second path (LANGUAGE.md 11.4, 9.2)'],
            '''write_json("first.json", [1, 2, 3])
printf("first done\\n")
write_json("missing/second.json", [4, 5])
''', 'write_json("missing/second.json"', "cannot open 'missing/second.json': No such file or directory",
            out=b'first done\n')
    r_expect('r_json_second_fails', {'first.json': top([1, 2, 3])})

    C.err_r('r_json_value_error',
            ['an error while the value is evaluated: the path and the value are bound before the file is opened (DESIGN.md 3.5.7',
             'step 4), so no file is created; the index error is at the write_json line'],
            '''let v: i64[] = [1, 2]
let k = 5
write_json("never.json", v[k])
''', 'write_json("never.json"', 'index 5 out of bounds for dimension 0 of extent 2')

    C.err_r('r_json_call_error',
            ['an error inside a function called as the value: reported at its own line, and no file is created (DESIGN.md 3.5.7',
             'step 4; LANGUAGE.md 9.3)'],
            '''fn bad() -> f64 {
    error("bad value")
    return 0.0
}
write_json("never.json", bad())
''', 'error("bad value")', 'bad value')

    C.err_r('r_json_path_error_first',
            ['the path is evaluated before the value: both fail, the path\'s error is the one reported, and no file is created',
             '(DESIGN.md 3.5.7 step 4: `bind J1 = path; bind J2 = value`)'],
            '''let names: str[] = ["a.json"]
let v: i64[] = [1, 2]
let k = 5
write_json(names[3], v[k])
''', 'write_json(names[3]', 'index 3 out of bounds for dimension 0 of extent 1')


def err_json():
    """243 of write_json (DESIGN.md 2.11.2 "Library calls of phase 6"): the wrong number or types of arguments, at the call."""
    def e(name, comment, body, marker, msg):
        C.err_c(name, comment, body, marker, 'write_json(', msg)
    e('err_json_one_arg', ['write_json without its value: 243 at the call (DESIGN.md 2.11.2; LANGUAGE.md 11.4)'],
      'write_json("a.json")\n', 'write_json("a.json")', "no overload of 'write_json' accepts (str)")
    e('err_json_no_arg', ['write_json without arguments: 243 at the call'],
      'write_json()\n', 'write_json()', "no overload of 'write_json' accepts ()")
    e('err_json_three_args', ['write_json with an extra argument: 243 at the call, the types spelled in order'],
      'write_json("a.json", 1.5, true)\n', 'write_json(', "no overload of 'write_json' accepts (str, f64, bool)")
    e('err_json_path_i64', ['a path that is not a str: 243 at the call (both arguments spelled)'],
      'write_json(1, 2)\n', 'write_json(1, 2)', "no overload of 'write_json' accepts (i64, i64)")
    e('err_json_path_array', ['a path that is a vector, with a fixed-size vector value: 243 at the call'],
      'let p: str[] = ["a.json"]\nwrite_json(p, [1, 2])\n', 'write_json(p', "no overload of 'write_json' accepts (str[], i64[2])")


def retire():
    for ext in ('.sea', '.err', '.status'):
        C.remove(os.path.join(ERRORS, 'err_ns_lib_write_json' + ext))


def main():
    for name in ('json_top_scalar', 'json_f64_values', 'json_i64_values', 'json_strings', 'json_vectors',
                 'json_matrices', 'json_struct', 'json_record_arrays', 'json_struct_empty', 'json_struct_arrays',
                 'json_fixed', 'json_fixed_structs', 'json_str_fields', 'json_depth', 'json_replace', 'json_two_paths',
                 'json_into_new_dir', 'json_arg_forms', 'json_big', 'json_big_str',
                 'r_json_after_write', 'r_json_after_index', 'r_json_second_fails'):
        clean_expect(name)
    retire()
    json_top_scalar()
    json_f64_values()
    json_i64_values()
    json_strings()
    json_vectors()
    json_matrices()
    json_struct()
    json_record_arrays()
    json_struct_empty()
    json_struct_arrays()
    json_fixed()
    json_fixed_structs()
    json_str_fields()
    json_depth()
    json_replace()
    json_two_paths()
    json_into_new_dir()
    json_arg_forms()
    json_big()
    json_big_str()
    r_json()
    err_json()
    print('json6_cases: %d programs, %d errors written; err_ns_lib_write_json retired'
          % (COUNT['programs'], COUNT['errors']))


if __name__ == '__main__':
    main()
