"""Sub-phase Lc, T1: the generated tests of the text library (DESIGN.md 2.15.8, "The generator").

Run with `timeout 120 uv run --no-project python tests/vectors/libL_cases.py [--check]` (standard library
only). It writes

  tests/rt/arm64_macos/rt_lib_kat.out, tests/rt/x86_64_linux/rt_lib_kat.out   (identical)
        the known answers of the runtime tests rt_lib_kat.s: one case per line, sections in the order
        parse_i64, parse_f64, split, substr (format: `parse_i64 B "T" V`, `parse_f64 "T" HEX16`,
        `split "S" "P" C "F1" ...`, `substr "S" L H "R"`; texts are printable ASCII without `"` and `\\`)
  tests/programs/lib_parse_f64_kat.sea/.out   about 400 texts, each printed `str(parse_f64(t))`, then 20
        lines `parse_f64(t) == L` with L the same text as a Sea literal
  tests/programs/lib_parse_i64_kat.sea/.out   about 200 texts in bases 2-36, printed with `%d`
  tests/programs/lib_read_lines_big.files/big.txt, lib_read_lines_big.sea/.out   a 200 003-byte fixture
        whose CR at offset 65 535 is followed by its LF at 65 536, with lines crossing every 65 536-byte
        boundary

`--check` regenerates everything in memory and compares it with the files on disk (nothing is written);
exit 1 on a difference.

The oracle is independent of the runtime. A text is given to Python's float() / int(text, base) only if
this file's own transcription of LANGUAGE.md 10.9's grammar (`f64_grammar`, `i64_grammar`) accepts it
(Python's parsers accept more: blanks, `_`, `0x`, `infinity`, ...); that is asserted for every case, and the
transcription is itself tested against the rejected examples of LANGUAGE.md 10.9. Python's float() is
correctly rounded (ties to even, overflow to inf, underflow to subnormal or zero, the sign of zero kept),
int(text, base) is exact, and Python's `'%.17g' %` is correctly rounded as both C libraries' printf are
(which is what `str(x)` of an f64 writes, LANGUAGE.md 10.9, and `nan` / `inf` / `-inf` for the non-finite
values). The `parse_f64(t) == L` lines are a second, independent oracle: L is evaluated by the compiler's
own exact arithmetic (LANGUAGE.md 3.4).

Readings (reported): the f64 program holds 150 random doubles, each as `%.17g` and as the shortest
round-trip text (300 texts) beside about 110 special texts, so about 410 texts in all; every Sea program is
well inside the compiler limits (4096 bytes per source line, LANGUAGE.md 3.1; the longest line is the
800-digit text with its quotes), so no program is split.
"""

import os
import random
import struct
import sys
from decimal import Decimal, getcontext
from fractions import Fraction

HERE = os.path.dirname(os.path.abspath(__file__))
TESTS = os.path.dirname(HERE)
PROGRAMS = os.path.join(TESTS, 'programs')
RT = os.path.join(TESTS, 'rt')

getcontext().prec = 2000

FILES = {}      # absolute path -> bytes (regular files)


def put(path, data):
    if isinstance(data, str):
        data = data.encode('ascii')
    assert path not in FILES, path
    FILES[path] = data


# ---------------------------------------------------------------------------- the grammar (LANGUAGE.md 10.9)
WORDS_F64 = {'inf': 'inf', 'Inf': 'inf', '+inf': 'inf', '+Inf': 'inf', '-inf': '-inf', '-Inf': '-inf',
             'nan': 'nan', 'NaN': 'nan'}


def f64_grammar(t):
    """True iff t is, in full, one of the eight words or
    [+|-] (digits [. [digits]] | . digits) [(e|E) [+|-] digits]   (digits: one or more of 0-9)."""
    if t in WORDS_F64:
        return True
    i = 0
    n = len(t)
    if i < n and t[i] in '+-':
        i += 1
    j = i
    while j < n and '0' <= t[j] <= '9':
        j += 1
    int_digits = j - i
    i = j
    frac_digits = 0
    if i < n and t[i] == '.':
        i += 1
        j = i
        while j < n and '0' <= t[j] <= '9':
            j += 1
        frac_digits = j - i
        i = j
        if int_digits == 0 and frac_digits == 0:
            return False
    elif int_digits == 0:
        return False
    if i < n and t[i] in 'eE':
        i += 1
        if i < n and t[i] in '+-':
            i += 1
        j = i
        while j < n and '0' <= t[j] <= '9':
            j += 1
        if j == i:
            return False
        i = j
    return i == n


def digit_value(c):
    if '0' <= c <= '9':
        return ord(c) - 48
    if 'a' <= c <= 'z':
        return ord(c) - 97 + 10
    if 'A' <= c <= 'Z':
        return ord(c) - 65 + 10
    return None


def i64_grammar(t, base):
    """True iff t is, in full, [+|-] one or more digits of the base, with a value in -2^63 ... 2^63 - 1."""
    assert 2 <= base <= 36
    i = 1 if t[:1] in ('+', '-') else 0
    if i == len(t):
        return False
    for c in t[i:]:
        d = digit_value(c)
        if d is None or d >= base:
            return False
    v = int(t, base)        # only reached for texts of the grammar: Python's int() agrees on those
    return -2 ** 63 <= v <= 2 ** 63 - 1


def selftest_grammar():
    # LANGUAGE.md 10.9: rejected and accepted examples
    for t in ('', '.', '1.2.3', ' 1', '1e', '0x1p3', 'Infinity', '-nan', '+nan', '1_0', '1.0 ', 'INF', 'e5', '.e5',
              '+', '-', '1e+', '1 ', '1,5', 'inF', '--1', '+-1', '1e5.5', '1.5e', 'nan ', ' nan', '١'):
        assert not f64_grammar(t), t
    for t in ('0', '-0', '1.5', '.5', '5.', '1e3', '1E-3', '+2.5', '5e-1', '1e309', '1700000000.123456', '5.e2',
              '.5e1', '0e0', 'inf', 'Inf', '+inf', '+Inf', '-inf', '-Inf', 'nan', 'NaN'):
        assert f64_grammar(t), t
    for t, b in (('', 10), ('+', 10), ('-', 10), (' 5', 10), ('5 ', 10), ('1_000', 10), ('0x1F', 16), ('12a', 10),
                 ('9223372036854775808', 10), ('-9223372036854775809', 10), ('1G', 16), ('2', 2), ('z', 35),
                 ('1.5', 10), ('--1', 10), ('+-1', 10)):
        assert not i64_grammar(t, b), (t, b)
    for t, b in (('-123', 10), ('18FF50E5', 16), ('ff', 16), ('-9223372036854775808', 10), ('101', 2), ('+0', 10),
                 ('Zz', 36), ('9223372036854775807', 10)):
        assert i64_grammar(t, b), (t, b)


# ---------------------------------------------------------------------------- the oracles
def oracle_f64(t):
    """The double Python's correctly rounded float() gives for a text of the grammar."""
    assert f64_grammar(t), t
    w = WORDS_F64.get(t)
    if w is not None:
        return float(w)
    return float(t)


def g17(x):
    """What `str(x)` writes for an f64 (LANGUAGE.md 10.9): %.17g, and nan / inf / -inf."""
    if x != x:
        return 'nan'
    if x == float('inf'):
        return 'inf'
    if x == float('-inf'):
        return '-inf'
    return '%.17g' % x


def bits(x):
    if x != x:
        return '7ff8000000000000'       # NaN payloads are not observable (DESIGN.md 2.15.2)
    return struct.pack('>d', x).hex()


def oracle_i64(t, base):
    assert i64_grammar(t, base), (t, base)
    return int(t, base)


def to_base(n, base):
    digits = '0123456789abcdefghijklmnopqrstuvwxyz'
    if n == 0:
        return '0'
    s = ''
    m = abs(n)
    while m:
        s = digits[m % base] + s
        m //= base
    return ('-' if n < 0 else '') + s


# ---------------------------------------------------------------------------- texts: parse_f64
def exact_decimal(fr):
    """The exact decimal text of a dyadic Fraction (finite)."""
    d = Decimal(fr.numerator) / Decimal(fr.denominator)
    assert Fraction(d) == fr        # exact at precision 2000
    s = format(d, 'f')
    if '.' in s:
        s = s.rstrip('0')
        if s.endswith('.'):
            s = s[:-1]
    return s


def next_up(x):
    b = struct.unpack('>q', struct.pack('>d', x))[0]
    return struct.unpack('>d', struct.pack('>q', b + 1))[0]


def midpoint_text(x):
    """The exact decimal text of the midpoint between positive double x and the next double above it."""
    y = next_up(x)
    return exact_decimal((Fraction(x) + Fraction(y)) / 2)


def mantissa_text(rng, ndigits):
    ds = [str(rng.randrange(1, 10))] + [str(rng.randrange(10)) for _ in range(ndigits - 1)]
    return ''.join(ds)


def f64_special_texts():
    rng = random.Random(0x5EA1C)
    t = []
    # the eight words
    t += ['inf', 'Inf', '+inf', '+Inf', '-inf', '-Inf', 'nan', 'NaN']
    # zeros and plain forms (every shape of the grammar)
    t += ['0', '-0', '+0', '0.0', '-0.0', '00', '000.000', '0e0', '-0e-5', '0e+400', '.0', '0.', '-.0', '+.0e9',
          '1', '-1', '+1', '1.5', '-1.5', '.5', '-.5', '5.', '-5.', '+5.', '1e3', '1E3', '1e+3', '1e-3', '1E-3',
          '+2.5', '-2.5e+2', '5e-1', '.5e1', '5.e2', '0.1', '0.2', '0.3', '000123', '0.000001', '123456789',
          '3.14159265358979323846', '2.718281828459045', '1700000000.123456', '1e22', '1e23', '8.5e-5',
          '4.35', '5e-324', '1e-323']
    # halfway cases: integers around 2^53 and 2^54, and exact midpoints of doubles
    t += ['9007199254740992', '9007199254740993', '9007199254740994', '9007199254740995', '9007199254740996',
          '9007199254740993.0000001', '9007199254740992.9999999', '9007199254740993.5', '9007199254740992.5',
          '18014398509481985', '18014398509481986', '18014398509481987', '18014398509481984']
    for x in (1.0, 1.5, 3.141592653589793, 123456789.0, 0.1, 2.0 ** 100, 1e22, 1e-10, 1e300, 5e-324, 2.5e-320):
        m = midpoint_text(x)
        t += [m, m + '1', '-' + m]
    # the normal / subnormal boundary
    t += ['2.2250738585072011e-308', '2.2250738585072012e-308', '2.2250738585072014e-308',
          '2.2250738585072013e-308', '2.225073858507201e-308', '2.2250738585072009e-308']
    t.append(exact_decimal((Fraction(2) ** -1022 + Fraction(2) ** -1022 - Fraction(2) ** -1074) / 1) if False else
             exact_decimal(Fraction(2) ** -1022 - Fraction(2) ** -1075))     # halfway below 2^-1022
    # the subnormal edges
    t += ['4.9406564584124654e-324', '4.9406564584124653e-324', '2.4703282292062328e-324',
          '2.4703282292062327e-324', '2.4703282292062326e-324', '-2.4703282292062327e-324',
          '2.4703282292062329e-324', '7.4109846876186982e-324', '7.4109846876186981e-324', '1e-324', '3e-324',
          '1e-400', '123456789e-410', '-1e-400']
    half_min = exact_decimal(Fraction(2) ** -1075)      # exactly half of the smallest subnormal: ties to even = 0
    t += [half_min, half_min + '1']
    # the overflow edge
    t += ['1.7976931348623158e308', '1.7976931348623159e308', '1.7976931348623157e308', '1.7976931348623160e308',
          '-1.7976931348623159e308', '1.8e308', '1e309', '1e308']
    big_half = str(2 ** 1024 - 2 ** 970)                 # halfway between the largest double and 2^1024: to even = inf
    t += [big_half, str(2 ** 1024 - 2 ** 970 - 1), big_half + '.5', str(2 ** 1024 - 2 ** 970 + 1)]
    # mantissas of 17, 40 and 800 digits, with point and exponent placements
    for nd in (17, 40, 800):
        m = mantissa_text(rng, nd)
        t.append(m)
        t.append('0.' + m)
        t.append(m[:1] + '.' + m[1:] + 'e-' + str(nd))
        t.append('-' + m[:3] + '.' + m[3:] + 'e5')
        t.append(m + 'e-' + str(nd))
    t.append('0' * 30 + '1.5')
    t.append('0.' + '0' * 400 + '15e400')
    t.append('1' + '0' * 400 + 'e-400')
    t.append('1' + '0' * 330)                                 # an integer text beyond the range: +inf
    t.append('0.' + '9' * 800)
    t.append('1.' + '0' * 790 + '1')
    # exponents of +-400 and of 25 digits
    t += ['1e400', '1e-400', '1e+400', '-1e400', '1e-401', '0e400', '-0e-400', '0.0e400', '9e399', '9e-399',
          '1e0000000000000000000000005', '1e-0000000000000000000000001', '1e9999999999999999999999999',
          '1e-9999999999999999999999999', '0e9999999999999999999999999', '-0e-9999999999999999999999999',
          '12345.678e+0000000000000000000000002', '1E0000000000000000000000000', '5e-0000000000000000000000324']
    return t


def random_f64_values():
    rng = random.Random(20241104)
    vals = []
    while len(vals) < 100:                                   # uniform bit patterns: every exponent
        b = rng.getrandbits(64)
        x = struct.unpack('>d', struct.pack('>Q', b))[0]
        if x != x or x in (float('inf'), float('-inf')):
            continue
        vals.append(x)
    while len(vals) < 150:                                   # human-looking: 1 to 17 digits, exponent -30 ... 30
        nd = rng.randrange(1, 18)
        m = int(mantissa_text(rng, nd))
        e = rng.randrange(-30, 31)
        s = rng.choice('+-' if False else ('', '-'))
        vals.append(float(s + str(m) + 'e' + str(e)))
    return vals


def f64_texts():
    seen = set()
    out = []
    for t in f64_special_texts():
        if t not in seen:
            seen.add(t)
            out.append(t)
    for x in random_f64_values():
        for t in ('%.17g' % x, repr(x)):
            if t not in seen:
                seen.add(t)
                out.append(t)
    for t in out:
        assert f64_grammar(t), t
        assert all(0x20 <= ord(c) < 0x7F and c not in '"\\' for c in t), t
    return out


# literal texts for `parse_f64(t) == L`: also valid float_lit (LANGUAGE.md 3.4: digits "." digits [exp] | digits exp)
LITERAL_TEXTS = [
    '0.1', '0.3', '1700000000.123456', '9007199254740993.0', '9007199254740995.0', '3.14159265358979323846',
    '2.2250738585072011e-308', '2.2250738585072014e-308', '4.9406564584124654e-324', '2.4703282292062328e-324',
    '2.4703282292062327e-324', '1.7976931348623158e308', '1.7976931348623157e308', '5e-324', '1e22', '1e23',
    '8.5e-5', '123456789012345678901234567890e-10', '0.30000000000000004', '4.35',
]


# ---------------------------------------------------------------------------- texts: parse_i64
def i64_cases_rt():
    """(base, text) pairs for the runtime known answers: about 100."""
    rng = random.Random(0x164)
    c = []
    for b in range(2, 37):
        v = rng.randrange(0, 2 ** rng.randrange(1, 63))
        c.append((b, to_base(v, b)))
    for b in (2, 3, 7, 8, 10, 16, 32, 36):
        c.append((b, to_base(2 ** 63 - 1, b)))
        c.append((b, to_base(-2 ** 63, b)))
    c += [(10, '0'), (10, '-0'), (10, '+0'), (10, '+5'), (10, '-5'), (10, '007'), (10, '-007'), (10, '+007'),
          (2, '0' * 70 + '1'), (10, '0' * 40 + '123'), (16, '0' * 30 + 'ff'), (16, '-' + '0' * 30 + '1'),
          (16, 'ff'), (16, 'FF'), (16, 'Ff'), (16, 'fF'), (16, 'deadBEEF'), (16, '18FF50E5'), (16, '-DEADbeef'),
          (16, '+7fffffffffffffff'), (16, '-8000000000000000'), (16, '7FFFFFFFFFFFFFFF'),
          (36, 'zz'), (36, 'ZZ'), (36, 'Zz'), (36, 'zZ'), (36, 'z'), (36, 'Z'), (36, '0z'), (36, '-a'), (36, '+A'),
          (36, '1y2p0ij32e8e7'), (36, '-1Y2P0IJ32E8E8'),
          (10, '9223372036854775807'), (10, '-9223372036854775808'), (10, '+9223372036854775807'),
          (10, '1000000000000000000'), (10, '9999999999999999999'[:18]), (10, '-1'), (10, '1'), (10, '-123'),
          (2, '101'), (2, '-101'), (2, '1' * 63), (2, '-1' + '0' * 63), (8, '777'), (8, '-1000000'),
          (8, '777777777777777777777'), (3, '2'), (3, '-2222'), (5, '4'), (35, 'y'), (35, 'Y'), (9, '88888'),
          (11, 'a'), (11, 'A'), (11, '-aaaa'), (12, 'b9'), (13, 'C'), (17, 'g'), (18, 'H'), (20, 'j'), (25, 'o')]
    return c


def i64_cases_prog():
    """(base, text) pairs for lib_parse_i64_kat: about 200."""
    rng = random.Random(0x64B)
    c = []
    for b in range(2, 37):
        mx = to_base(2 ** 63 - 1, b)
        mn = to_base(-2 ** 63, b)
        c.append((b, mx))
        c.append((b, mn))
        c.append((b, '+' + mx))
        for _ in range(2):
            v = rng.randrange(0, 2 ** rng.randrange(1, 64))
            if rng.random() < 0.5:
                v = -v
            s = to_base(v, b)
            if rng.random() < 0.5:
                s = s.upper()
            c.append((b, s))
    c += [(10, '0'), (10, '-0'), (10, '+0'), (10, '00000000000000000000000000000000000000001'),
          (10, '-00000000000000000000000000000000000000001'), (16, 'ff'), (16, 'FF'), (16, 'aBcDeF'),
          (16, '-8000000000000000'), (16, '7fffffffffffffff'), (36, 'zZzZ'), (2, '0' * 100 + '1')]
    return c


# ---------------------------------------------------------------------------- texts: split, substr
def split_model(s, p):
    """LANGUAGE.md 10.9: occurrences of p found left to right without overlap; one more field than occurrences."""
    assert p
    out = []
    cur = 0
    i = 0
    while i + len(p) <= len(s):
        if s[i:i + len(p)] == p:
            out.append(s[cur:i])
            i += len(p)
            cur = i
        else:
            i += 1
    out.append(s[cur:])
    assert out == s.split(p)        # Python's split agrees (non-empty separator)
    return out


def substr_model(s, lo, hi):
    """LANGUAGE.md 10.9; None when the call is a run-time error (these never go to the known answers)."""
    if lo >= hi:
        return ''
    n = len(s)
    if not 0 <= lo < n:
        return None
    if not 0 <= hi - 1 < n:
        return None
    return s[lo:hi]


SPLIT_CASES = [
    ('a,,b', ','), (',a,', ','), ('', ','), ('abc', ','), ('aaa', 'aa'), ('a::b', '::'),
    ('a b c', ' '), ('a  b', ' '), ('  ', ' '), (' ', ' '), ('x', 'x'), ('abc', 'abc'), ('abc', 'abcd'),
    ('ab', 'abc'), ('', 'abc'), ('abab', 'ab'), ('ababab', 'bab'), ('aXbX', 'X'), ('XaXbX', 'X'), ('XX', 'X'),
    ('abcab', 'cab'), ('abca', 'cab'), ('abcabc', 'cabc'), ('aabaab', 'aab'), ('aaaa', 'aa'), ('aaaaa', 'aa'),
    ('1700000000.123456 can0 123#DEADBEEF', ' '), ('can0 123#DEADBEEF', '#'), ('a,b;c,d', ';'),
    ('one::two::::three', '::'), ('end::', '::'), ('::', '::'), (':::', '::'), ('a-->b-->', '-->'),
    ('ab-', '-->'), ('ab--', '-->'), ('a=b=c', '=')]

SUBSTR_CASES = [
    ('hello', 0, 5), ('hello', 0, 1), ('hello', 4, 5), ('hello', 1, 4), ('hello', 2, 2), ('hello', 3, 3),
    ('hello', 0, 0), ('hello', 5, 5), ('hello', 4, 2), ('hello', 9, 2), ('hello', -3, -5), ('hello', 100, -100),
    ('hello', -1, 0), ('hello', 2, 1), ('', 0, 0), ('', 3, 1), ('', 5, 5), ('(1.5)', 1, 4), ('(1.5)', 0, 1),
    ('(1.5)', 4, 5), ('a', 0, 1), ('a', 0, 0), ('ab', 0, 2), ('ab', 1, 2), ('ab', 0, 1), ('ab', 2, 0),
    ('1700000000.123456', 0, 10), ('1700000000.123456', 11, 17), ('can0 123#DEADBEEF', 9, 17),
    ('DEADBEEF', 2, 4), ('DEADBEEF', 6, 8), ('a b', 1, 2), ('x y z', 2, 3), ('abc', 1, 1), ('abc', 7, 7)]


# ---------------------------------------------------------------------------- the rt known answers
def rt_kat():
    selftest_grammar()
    lines = []
    for b, t in i64_cases_rt():
        lines.append('parse_i64 %d "%s" %d' % (b, t, oracle_i64(t, b)))
    rng = random.Random(0xF64)
    texts = [t for t in f64_special_texts()]
    # about 150 texts: every kind of the special list, then random doubles
    keep = []
    seen = set()
    for t in texts:
        if t not in seen:
            seen.add(t)
            keep.append(t)
    rvals = random_f64_values()
    for x in rvals[:20]:
        for t in ('%.17g' % x, repr(x)):
            if t not in seen:
                seen.add(t)
                keep.append(t)
    for t in keep:
        lines.append('parse_f64 "%s" %s' % (t, bits(oracle_f64(t))))
    for s, p in SPLIT_CASES:
        fields = split_model(s, p)
        for x in (s, p) + tuple(fields):
            assert all(0x20 <= ord(c) < 0x7F and c not in '"\\' for c in x), x
        lines.append('split "%s" "%s" %d %s' % (s, p, len(fields), ' '.join('"%s"' % f for f in fields)))
    rows = 0
    for s, lo, hi in SUBSTR_CASES:
        r = substr_model(s, lo, hi)
        if r is None:
            continue
        rows += 1
        lines.append('substr "%s" %d %d "%s"' % (s, lo, hi, r))
    assert rows >= 30, rows
    out = '\n'.join(lines) + '\n'
    assert all(len(l) < 6000 for l in lines)
    return out


# ---------------------------------------------------------------------------- Sea programs
def sea_source(name, comment, body):
    head = '// %s -- %s\n' % (name, comment[0]) + ''.join('// %s\n' % c for c in comment[1:])
    src = head + body
    for ln in src.split('\n'):
        assert len(ln.encode('ascii')) <= 4096, ln[:40]       # LANGUAGE.md 3.1
        assert all(c == '\t' or 0x20 <= ord(c) < 0x7F for c in ln), ln
    return src


def sea_str_array(name, items):
    return 'let %s: str[] = [\n%s\n]\n' % (name, ',\n'.join('    "%s"' % t for t in items))


def f64_program():
    texts = f64_texts()
    assert 380 <= len(texts) <= 460, len(texts)
    body = sea_str_array('texts', texts)
    body += 'for t in texts {\n    printf("%s\\n", str(parse_f64(t)))\n}\n'
    outs = []
    for t in texts:
        outs.append(g17(oracle_f64(t)))
    for t in LITERAL_TEXTS:
        assert f64_grammar(t)
        # the second oracle, as Python sees it: the literal text and the parsed text are the same decimal value
        assert oracle_f64(t) == float(t)
        body += 'printf("%%d\\n", parse_f64("%s") == %s)\n' % (t, t)
        outs.append('1')
    comment = ['parse_f64 against Python\'s correctly rounded float() (LANGUAGE.md 10.9, 3.4; DESIGN.md 2.15.8):',
               '%d texts (halfway cases, the subnormal and overflow edges, mantissas of 17, 40 and 800 digits, exponents'
               % len(texts),
               'of +-400 and of 25 digits, 150 random doubles as %.17g and as their shortest round-trip text), each printed',
               'as str(parse_f64(t)) (%%.17g, nan, inf, -inf); then %d lines parse_f64(t) == L with L the same text as a'
               % len(LITERAL_TEXTS),
               'Sea literal (the compiler\'s own exact arithmetic): 1 each. Generated by tests/vectors/libL_cases.py']
    put(os.path.join(PROGRAMS, 'lib_parse_f64_kat.sea'), sea_source('lib_parse_f64_kat', comment, body))
    put(os.path.join(PROGRAMS, 'lib_parse_f64_kat.out'), '\n'.join(outs) + '\n')


def i64_program():
    cases = i64_cases_prog()
    assert 180 <= len(cases) <= 240, len(cases)
    body = sea_str_array('texts', [t for _, t in cases])
    body += 'let bases: i64[] = [\n%s\n]\n' % ',\n'.join('    %d' % b for b, _ in cases)
    body += 'for k in 0..len(texts) {\n    printf("%d\\n", parse_i64(texts[k], base: bases[k]))\n}\n'
    outs = ['%d' % oracle_i64(t, b) for b, t in cases]
    comment = ['parse_i64 against Python\'s int(text, base) (LANGUAGE.md 10.9; DESIGN.md 2.15.8):',
               '%d texts in bases 2 ... 36 (both range ends in every base, with and without a plus sign, random values in'
               % len(cases),
               'both letter cases, signs, leading zeros), each printed with %d. Generated by tests/vectors/libL_cases.py']
    put(os.path.join(PROGRAMS, 'lib_parse_i64_kat.sea'), sea_source('lib_parse_i64_kat', comment, body))
    put(os.path.join(PROGRAMS, 'lib_parse_i64_kat.out'), '\n'.join(outs) + '\n')


def read_lines_rule(data):
    """DESIGN.md 2.15.2: the lines of a file, a straight transcription (LF ends a line, one CR before it goes,
    and one CR at the very end of the file goes too)."""
    lines = []
    cur = bytearray()
    i = 0
    n = len(data)
    while i < n:
        b = data[i]
        if b == 0x0A:
            if cur and cur[-1] == 0x0D:
                cur.pop()
            lines.append(bytes(cur))
            cur = bytearray()
        else:
            cur.append(b)
        i += 1
    if cur:
        if cur[-1] == 0x0D:
            cur.pop()
        lines.append(bytes(cur))
    return lines


def big_fixture():
    rng = random.Random(0xB16)
    total = 200003
    pieces = []             # (content bytes, terminator bytes)
    pos = 0
    printable = bytes(range(0x20, 0x7F))
    odd = bytes([0x00, 0xFF, 0x80, 0xEF, 0xBB, 0xBF, 0x0D, 0x09])

    def content(n, plain=False):
        if plain:
            return bytes(printable[rng.randrange(len(printable))] for _ in range(n))
        return bytes((odd if rng.random() < 0.04 else printable)[rng.randrange(len(odd) if False else 8 if False else 1)]
                     if False else (odd[rng.randrange(len(odd))] if rng.random() < 0.04
                                    else printable[rng.randrange(len(printable))]) for _ in range(n))

    def add(c, term):
        nonlocal pos
        if term == b'\n' and c.endswith(b'\r'):
            c = c + b'x'            # a CR at the end of a line ended by a bare LF would be taken as part of CRLF
        pieces.append((c, term))
        pos += len(c) + len(term)

    marks = {}
    boundary_targets = [65536, 131072, 196608]
    # the first line is short and printable; the last is printable and has no terminator
    add(b'first line', b'\n')
    for bi, bnd in enumerate(boundary_targets):
        while pos < bnd - 700:
            n = rng.randrange(0, 301)
            add(content(n), rng.choice([b'\n', b'\r\n', b'\n']))
        # a printable line that crosses the boundary: starts before it, ends after it
        if bi == 0:
            # the CR at offset 65 535, its LF at 65 536: the content fills exactly up to offset 65 535
            n = (bnd - 1) - pos
            assert 0 < n < 800, n
            marks[bnd] = len(pieces)
            add(content(n, True), b'\r\n')
            assert pos == bnd + 1
        else:
            n = (bnd - pos) + rng.randrange(5, 60)
            marks[bnd] = len(pieces)
            add(content(n, True), rng.choice([b'\n', b'\r\n']))
    while pos < total - 700:
        n = rng.randrange(0, 301)
        add(content(n), rng.choice([b'\n', b'\r\n', b'\n']))
    # a line ending in a CR before CRLF ("a\r\r\n" is "a\r"), an empty line and a lone-CR line near the end
    add(b'ends with CR\r', b'\r\n')
    add(b'', b'\n')
    add(b'a\rb', b'\r\n')
    last_len = total - pos
    assert last_len >= 1, last_len
    pieces.append((bytes(printable[(7 * k) % len(printable)] for k in range(last_len)), b''))
    data = b''.join(c + t for c, t in pieces)
    assert len(data) == total, len(data)
    assert data[65535] == 0x0D and data[65536] == 0x0A
    lines = read_lines_rule(data)
    # the independent construction: the pieces themselves (a trailing CR kept by CRLF stays in the content)
    built = [c for c, _ in pieces]
    assert lines == built, (len(lines), len(built))
    # starts of the lines, to verify that a line crosses each boundary
    starts = []
    p = 0
    for c, t in pieces:
        starts.append(p)
        p += len(c) + len(t)
    for bnd in boundary_targets:
        k = marks[bnd]
        assert starts[k] < bnd - 1 or bnd == 65536, bnd
        end = starts[k] + len(pieces[k][0]) + len(pieces[k][1])
        assert starts[k] < bnd <= end, (bnd, starts[k], end)
    return data, lines, marks


def big_program():
    data, lines, marks = big_fixture()
    put(os.path.join(PROGRAMS, 'lib_read_lines_big.files', 'big.txt'), data)
    total = sum(len(l) for l in lines)
    probes = [marks[b] for b in (65536, 131072, 196608)]
    for k in probes:
        assert all(0x20 <= c < 0x7F and c not in b'%' for c in lines[k]) or True
        assert all(0x20 <= c < 0x7F for c in lines[k]), k
    assert all(0x20 <= c < 0x7F for c in lines[0]) and all(0x20 <= c < 0x7F for c in lines[-1])
    body = 'let lines = read_lines("big.txt")\n'
    body += 'var total = 0\nfor ln in lines {\n    total = total + len(ln)\n}\n'
    body += 'printf("lines %d\\ntotal %d\\n", len(lines), total)\n'
    body += 'printf("first [%s]\\nlast [%s]\\n", lines[0], lines[len(lines) - 1])\n'
    outs = ['lines %d' % len(lines), 'total %d' % total, 'first [%s]' % lines[0].decode('ascii'),
            'last [%s]' % lines[-1].decode('ascii')]
    for k in probes:
        body += 'printf("line %%d len %%d [%%s]\\n", %d, len(lines[%d]), lines[%d])\n' % (k, k, k)
        outs.append('line %d len %d [%s]' % (k, len(lines[k]), lines[k].decode('ascii')))
    # the CRLF split across the first chunk boundary: the lines on both sides
    k = probes[0]
    for j in (k - 1, k + 1):
        body += 'printf("line %%d len %%d\\n", %d, len(lines[%d]))\n' % (j, j)
        outs.append('line %d len %d' % (j, len(lines[j])))
    # the tail: the CR-before-CRLF line, the empty line, the lone CR line (printed by length)
    n = len(lines)
    for j in (n - 4, n - 3, n - 2):
        body += 'printf("line %%d len %%d\\n", %d, len(lines[%d]))\n' % (j, j)
        outs.append('line %d len %d' % (j, len(lines[j])))
    comment = ['read_lines of a generated 200 003-byte file (DESIGN.md 2.15.2, 2.15.8): the CR at offset 65 535 is followed by its',
               'LF at 65 536 (a CRLF split by the first 64 KiB chunk), one line crosses each of the offsets 65 536, 131 072',
               'and 196 608, there are NUL, 0xFF, BOM bytes and lone CRs inside lines, a line ends in CR before CRLF',
               '("x\\r\\r\\n" is "x\\r"), and the last line has no terminator. Prints the line count, the sum of the lengths, the',
               'first and last lines, and the lines at the boundaries. Fixture and output written by tests/vectors/libL_cases.py']
    put(os.path.join(PROGRAMS, 'lib_read_lines_big.sea'), sea_source('lib_read_lines_big', comment, body))
    put(os.path.join(PROGRAMS, 'lib_read_lines_big.out'), '\n'.join(outs) + '\n')


# ---------------------------------------------------------------------------- main
def generate():
    FILES.clear()
    selftest_grammar()
    kat = rt_kat()
    put(os.path.join(RT, 'arm64_macos', 'rt_lib_kat.out'), kat)
    put(os.path.join(RT, 'x86_64_linux', 'rt_lib_kat.out'), kat)
    f64_program()
    i64_program()
    big_program()
    return dict(FILES)


def main(argv):
    check = '--check' in argv
    files = generate()
    if check:
        bad = 0
        for path, data in sorted(files.items()):
            try:
                with open(path, 'rb') as f:
                    old = f.read()
            except OSError:
                old = None
            if old != data:
                print('libL_cases: differs: %s' % os.path.relpath(path, TESTS))
                bad += 1
        if bad:
            return 1
        print('libL_cases: %d files up to date' % len(files))
        return 0
    for path, data in sorted(files.items()):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'wb') as f:
            f.write(data)
    print('libL_cases: %d files written' % len(files))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
