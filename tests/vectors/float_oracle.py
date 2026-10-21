"""float_oracle.py -- exact IEEE-754 binary64 oracle for Sea's test corpus (WP12).

Everything here is exact integer / Fraction arithmetic: decimal-to-binary conversion of Sea
float literals (LANGUAGE.md 3.4: nearest binary64, ties to even, overflow is an error,
underflow gives the nearest subnormal or zero), the four basic operations with round to
nearest even (LANGUAGE.md 6.5, 6.8), i64 -> f64 conversion, and exact decimal expansion of a
binary64 value (for the printf generator, progfmt.py). Python's own float is used only as an
independent cross-check in the self-test, never as the source of an expected value.

Run:  uv run python tests/vectors/float_oracle.py
It runs the self-test and writes tests/vectors/float_oracle.out (the hard literal table that
tests/passes/lex_float_hard.ast is built from) and the lex_float_hard test files.
"""

import os
import re
import struct
import sys
from fractions import Fraction

HERE = os.path.dirname(os.path.abspath(__file__))
TESTS = os.path.dirname(HERE)

EXP_BIAS = 1023
MANT_BITS = 52
MIN_EXP = -1074          # weight of the least subnormal bit
POS_INF = 0x7FF0000000000000
NEG_ZERO = 0x8000000000000000


class Overflow(Exception):
    """The exact value rounds to infinity (float literal out of range)."""


def bits_to_frac(b):
    """The exact value of a finite binary64 bit pattern as (sign, Fraction |v|)."""
    sign = b >> 63
    e = (b >> 52) & 0x7FF
    m = b & ((1 << 52) - 1)
    if e == 0x7FF:
        raise ValueError("not finite")
    if e == 0:
        v = Fraction(m, 1 << 1074)
    else:
        v = Fraction((1 << 52) | m) * Fraction(2) ** (e - EXP_BIAS - MANT_BITS)
    return sign, v


def frac_to_bits(sign, q):
    """Round the exact |value| q >= 0 to nearest binary64, ties to even; raise Overflow."""
    if q == 0:
        return sign << 63
    n, d = q.numerator, q.denominator
    # exponent estimate: 2^e <= q < 2^(e+1)
    e = n.bit_length() - d.bit_length()
    if Fraction(n, d) < Fraction(2) ** e:
        e -= 1
    # quantum (weight of the last mantissa bit) for normal numbers, clamped for subnormals
    qexp = max(e - MANT_BITS, MIN_EXP)
    scaled = q / (Fraction(2) ** qexp)          # integer part = mantissa candidate
    m = scaled.numerator // scaled.denominator
    rem = scaled - m
    if rem > Fraction(1, 2) or (rem == Fraction(1, 2) and (m & 1)):
        m += 1
    # m * 2^qexp is the rounded value; normalise
    if m == 0:
        return sign << 63
    if m >= (1 << 53):        # carried into the next binade
        m >>= 1
        qexp += 1
    if m < (1 << 52):         # subnormal (qexp == MIN_EXP)
        assert qexp == MIN_EXP
        return (sign << 63) | m
    biased = qexp + MANT_BITS + EXP_BIAS
    if biased >= 0x7FF:
        raise Overflow()
    return (sign << 63) | (biased << 52) | (m - (1 << 52))


# ------------------------------------------------------------------ Sea float literals
FLOAT_RE = re.compile(r"^([0-9][0-9_]*)(?:\.([0-9][0-9_]*))?(?:[eE]([+-]?[0-9]+))?$")


def literal_value(text):
    """Exact Fraction of a Sea float_lit (LANGUAGE.md 3.4); underscores are separators."""
    m = FLOAT_RE.match(text)
    if not m or (m.group(2) is None and m.group(3) is None):
        raise ValueError("not a float_lit: " + text)
    ip = m.group(1).replace("_", "")
    fp = (m.group(2) or "").replace("_", "")
    ex = int(m.group(3) or "0")
    digits = int(ip + fp)
    scale = ex - len(fp)
    if scale >= 0:
        return Fraction(digits * 10 ** scale)
    return Fraction(digits, 10 ** (-scale))


def literal_bits(text):
    return frac_to_bits(0, literal_value(text))


def hexf(b):
    """The `f` field encoding of DESIGN.md 3.1."""
    return "#%016X" % b


def hexi(v):
    """The `i` field encoding of DESIGN.md 3.1."""
    if -10 ** 9 < v < 10 ** 9:
        return str(v)
    return "#%016X" % (v & 0xFFFFFFFFFFFFFFFF)


# ------------------------------------------------------------------ arithmetic (finite)
def _val(b):
    s, v = bits_to_frac(b)
    return -v if s else v


def _is_neg_zero(b):
    return b == NEG_ZERO


def _round_signed(q, zero_sign):
    if q == 0:
        return zero_sign << 63
    if q < 0:
        return frac_to_bits(1, -q)
    return frac_to_bits(0, q)


def f_add(a, b):
    q = _val(a) + _val(b)
    # exact zero sum: +0 under round to nearest, unless both operands are -0
    zs = 1 if (q == 0 and _is_neg_zero(a) and _is_neg_zero(b)) else 0
    return _round_signed(q, zs)


def f_sub(a, b):
    return f_add(a, b ^ (1 << 63))


def f_mul(a, b):
    q = _val(a) * _val(b)
    return _round_signed(q, (a >> 63) ^ (b >> 63))


def f_div(a, b):
    if _val(b) == 0:
        raise ZeroDivisionError("oracle: finite operands only")
    q = _val(a) / _val(b)
    return _round_signed(q, (a >> 63) ^ (b >> 63))


def f_neg(a):
    return a ^ (1 << 63)


def i_to_f(i):
    """i64 -> f64, round to nearest even (LANGUAGE.md 4.2)."""
    if i == 0:
        return 0
    return frac_to_bits(1 if i < 0 else 0, Fraction(abs(i)))


def f_from_int_exact(i):
    b = i_to_f(i)
    assert _val(b) == i, "not exact in f64"
    return b


# ------------------------------------------------------------------ exact decimal
def exact_decimal(b):
    """(sign, N, k) with |value| = N / 10^k exactly, k >= 0, for a finite pattern."""
    s, v = bits_to_frac(b)
    d = v.denominator           # a power of two
    k = d.bit_length() - 1
    assert d == 1 << k
    return s, v.numerator * 5 ** k, k


# ------------------------------------------------------------------ self-test
def _py_bits(x):
    return struct.unpack(">Q", struct.pack(">d", x))[0]


HARD = [
    # (literal, comment)
    ("0.1", "the classic inexact decimal"),
    ("0.3", "0.1 + 0.2 != 0.3 operand"),
    ("1e23", "a classic hard case for naive strtod"),
    ("8.98846567431158e307", "2^1023 rounded at 15 digits"),
    ("9007199254740993.0", "2^53 + 1: exact tie, to even (2^53)"),
    ("9007199254740995.0", "2^53 + 3: exact tie, to even (2^53 + 4)"),
    ("1.7976931348623157e308", "the largest finite value"),
    ("1.7976931348623158e308", "below the overflow midpoint: still the largest finite value"),
    ("2.2250738585072011e-308", "just below the least normal: the largest subnormal"),
    ("2.2250738585072014e-308", "the least normal"),
    ("4.9406564584124654e-324", "the least subnormal"),
    ("2.4703282292062328e-324", "just above half the least subnormal: rounds up to it"),
    ("2.4703282292062327e-324", "just below half the least subnormal: rounds to zero"),
    ("1e-400", "far below: zero"),
    ("0.1000000000000000055511151231257827021181583404541015625", "0.1's exact binary value"),
    ("0.100000000000000012490009027033011079765856266021728515625",
     "the exact midpoint above 0.1's double (even mantissa): tie to even, stays"),
    ("0.100000000000000012490009027033011079765856266021728515626",
     "one unit past that midpoint: rounds up"),
    ("123456789012345678901234567890.0", "30 significant digits"),
    ("1_000.000_5", "digit-group separators"),
    ("5e-324", "short form of the least subnormal"),
]


def _midpoint_check():
    """The two midpoint literals of HARD are the exact midpoint (and one unit past it)."""
    s, v = bits_to_frac(literal_bits("0.1"))
    mid = v + Fraction(1, 2 ** 57)
    assert literal_value(HARD[15][0]) == mid
    assert literal_value(HARD[16][0]) == mid + Fraction(1, 10 ** 57)
    assert literal_bits(HARD[15][0]) == literal_bits("0.1")
    assert literal_bits(HARD[16][0]) == literal_bits("0.1") + 1


def self_test():
    _midpoint_check()
    for lit, _ in HARD:
        b = literal_bits(lit)
        assert b == _py_bits(float(lit.replace("_", ""))), lit
    # overflow
    for lit in ("1.7976931348623159e308", "1e309"):
        try:
            literal_bits(lit)
        except Overflow:
            pass
        else:
            raise AssertionError(lit)
    # arithmetic cross-check on a few values
    import random
    rnd = random.Random(12345)
    for _ in range(2000):
        x = rnd.uniform(-1e3, 1e3)
        y = rnd.uniform(-1e3, 1e3)
        a, b = _py_bits(x), _py_bits(y)
        assert f_add(a, b) == _py_bits(x + y)
        assert f_sub(a, b) == _py_bits(x - y)
        assert f_mul(a, b) == _py_bits(x * y)
        assert f_div(a, b) == _py_bits(x / y)
    assert f_add(NEG_ZERO, NEG_ZERO) == NEG_ZERO
    assert f_add(NEG_ZERO, 0) == 0
    assert i_to_f(9007199254740993) == _py_bits(9007199254740992.0)


# ------------------------------------------------------------------ lex_float_hard
def write_lex_float_hard():
    """Write tests/passes/lex_float_hard.{sea,ast}: one `let` per hard literal."""
    names = []
    src = ["// lex_float_hard -- float literals that need exact decimal-to-binary rounding",
           "// (LANGUAGE.md 3.4). Bits: tests/vectors/float_oracle.py."]
    ast = ["#sea 1", "#target arm64-macos", "#file lex_float_hard.sea"]
    for i, (lit, comment) in enumerate(HARD):
        line_no = len(src) + 1
        name = "h%d" % i
        line = "let %s = %s" % (name, lit)
        src.append(line)
        names.append(name)
        b = literal_bits(lit)
        ast.append("pname 0:%d:5 %s" % (line_no, name))
        ast.append("float 0:%d:%d %s" % (line_no, line.index(lit) + 1, hexf(b)))
        ast.append("let 0:%d:1 0" % line_no)
    ast.append("prog %d" % len(HARD))
    ast.append("#end")
    with open(os.path.join(TESTS, "passes", "lex_float_hard.sea"), "w") as f:
        f.write("\n".join(src) + "\n")
    with open(os.path.join(TESTS, "passes", "lex_float_hard.ast"), "w") as f:
        f.write("\n".join(ast) + "\n")
    with open(os.path.join(HERE, "float_oracle.out"), "w") as f:
        f.write("# literal bits comment (generated by float_oracle.py)\n")
        for lit, comment in HARD:
            f.write("%s %s %s\n" % (lit, hexf(literal_bits(lit)), comment))


if __name__ == "__main__":
    self_test()
    write_lex_float_hard()
    print("float_oracle: self-test passed; wrote lex_float_hard and float_oracle.out")
