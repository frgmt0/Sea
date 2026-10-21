"""progfmt.py -- exact printf oracle and generator of Sea's printf tests (WP12).

Implements the printf conversions of LANGUAGE.md 11.1 from the exact decimal value of each
argument (float_oracle.exact_decimal), with the C99 rules for finite values (correct
rounding, exact ties to even, at least two exponent digits, %g's style choice and trailing
zero removal, the flags - + space 0 #), the MATLAB rule for %d on an f64, and Sea's
non-finite rule (Inf, +Inf, " Inf", -Inf, NaN never signed, 0/# and precision ignored).
Python's own '%' formatting is used only as a cross-check of the C99 part, never as the
source of an expected byte.

Run:  uv run python tests/vectors/progfmt.py
It writes tests/programs/fmt_{d,d_f64,f,e,g,s,pct,nonfinite}.{sea,out} and
op_f64_arith.{sea,out}, op_order.{sea,out}, lib_consts.{sea,out}, and checks itself.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import float_oracle as fo  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
PROGRAMS = os.path.join(os.path.dirname(HERE), "programs")

INF = 0x7FF0000000000000
NINF = 0xFFF0000000000000
QNAN = 0x7FF8000000000000          # nan (DESIGN.md 3.5.5)
NNAN = 0xFFF8000000000000          # -nan: the sign bit flipped (LANGUAGE.md 6.5)


class Spec:
    """One conversion %[flags][width][.precision]conv."""

    def __init__(self, text):
        assert text[0] == "%"
        i = 1
        self.flags = ""
        while text[i] in "-+ 0#":
            self.flags += text[i]
            i += 1
        w = ""
        while text[i].isdigit():
            w += text[i]
            i += 1
        self.width = int(w) if w else None
        self.prec = None
        if text[i] == ".":
            i += 1
            p = ""
            while text[i].isdigit():
                p += text[i]
                i += 1
            self.prec = int(p) if p else 0
        self.conv = text[i]
        assert i == len(text) - 1, text
        self.text = text

    def has(self, f):
        return f in self.flags


# ------------------------------------------------------------------ digit helpers
def round_div(n, d):
    """n / d rounded to nearest, ties to even (n, d > 0 integers)."""
    q, r = divmod(n, d)
    if 2 * r > d or (2 * r == d and q & 1):
        q += 1
    return q


def e_digits(N, k, prec):
    """For |v| = N/10^k > 0: (digits string of prec+1 digits, exponent X) rounded."""
    # exponent X with 10^X <= v < 10^(X+1)
    X = len(str(N)) - 1 - k
    # scaled = v / 10^(X - prec) = N * 10^(prec - X - k)
    sh = prec - X - k
    if sh >= 0:
        m = N * 10 ** sh
    else:
        m = round_div(N, 10 ** (-sh))
    if m >= 10 ** (prec + 1):           # rounding carried into a new digit
        X += 1
        sh = prec - X - k
        m = N * 10 ** sh if sh >= 0 else round_div(N, 10 ** (-sh))
    assert 10 ** prec <= m < 10 ** (prec + 1)
    return str(m), X


def f_digits(N, k, prec):
    """For |v| = N/10^k: the integer round(v * 10^prec), ties to even."""
    sh = prec - k
    if sh >= 0:
        return N * 10 ** sh
    return round_div(N, 10 ** (-sh))


def body_f(N, k, prec, alt):
    m = f_digits(N, k, prec)
    s = str(m).rjust(prec + 1, "0")
    ip, fp = s[: len(s) - prec], s[len(s) - prec:]
    if prec == 0:
        return ip + ("." if alt else "")
    return ip + "." + fp


def exp_text(X, upper):
    return ("E" if upper else "e") + ("-" if X < 0 else "+") + ("%02d" % abs(X))


def body_e(N, k, prec, alt, upper):
    if N == 0:
        d, X = "0" * (prec + 1), 0
    else:
        d, X = e_digits(N, k, prec)
    s = d[0]
    if prec > 0 or alt:
        s += "."
    s += d[1:]
    return s + exp_text(X, upper)


def body_g(N, k, prec, alt, upper):
    P = 6 if prec is None else (1 if prec == 0 else prec)
    if N == 0:
        X = 0
    else:
        X = e_digits(N, k, P - 1)[1]
    if P > X >= -4:
        s = body_f(N, k, P - 1 - X, alt)
    else:
        s = body_e(N, k, P - 1, alt, upper)
    if not alt:
        if "e" in s or "E" in s:
            mant, ex = s.split("E" if upper else "e")
            if "." in mant:
                mant = mant.rstrip("0").rstrip(".")
            s = mant + ("E" if upper else "e") + ex
        elif "." in s:
            s = s.rstrip("0").rstrip(".")
    return s


def pad(spec, sign, body, zero_ok):
    """Apply width with '-' and '0' (zeros go after the sign)."""
    w = spec.width or 0
    total = len(sign) + len(body)
    if total >= w:
        return sign + body
    if spec.has("-"):
        return sign + body + " " * (w - total)
    if spec.has("0") and zero_ok:
        return sign + "0" * (w - total) + body
    return " " * (w - total) + sign + body


def sign_text(spec, negative):
    if negative:
        return "-"
    if spec.has("+"):
        return "+"
    if spec.has(" "):
        return " "
    return ""


# ------------------------------------------------------------------ conversions
def fmt_float_bits(spec, b):
    """%f %F %e %E %g %G (and %d's fallback) of an f64 bit pattern."""
    e = (b >> 52) & 0x7FF
    if e == 0x7FF:
        return fmt_nonfinite(spec, b)
    s, N, k = fo.exact_decimal(b)
    conv = spec.conv
    prec = spec.prec
    alt = spec.has("#")
    if conv in "fF":
        body = body_f(N, k, 6 if prec is None else prec, alt)
    elif conv in "eE":
        body = body_e(N, k, 6 if prec is None else prec, alt, conv == "E")
    elif conv in "gG":
        body = body_g(N, k, prec, alt, conv == "G")
    else:
        raise ValueError(conv)
    return pad(spec, sign_text(spec, s == 1), body, True)


def fmt_nonfinite(spec, b):
    """LANGUAGE.md 11.1, "Non-finite values"."""
    m = b & ((1 << 52) - 1)
    if m != 0:
        body = "NaN"
    elif b >> 63:
        body = "-Inf"
    elif spec.has("+"):
        body = "+Inf"
    elif spec.has(" "):
        body = " Inf"
    else:
        body = "Inf"
    return pad(spec, "", body, False)


def fmt_int(spec, v):
    """%d %i of an i64 (no precision is used by the corpus)."""
    assert spec.prec is None
    return pad(spec, sign_text(spec, v < 0), str(abs(v)), True)


def fmt_d_f64(spec, b):
    """%d %i of an f64 (MATLAB rule, LANGUAGE.md 11.1)."""
    e = (b >> 52) & 0x7FF
    if e == 0x7FF:
        return fmt_nonfinite(spec, b)
    s, v = fo.bits_to_frac(b)
    if v.denominator == 1:
        assert not (v == 0 and s == 1), "the corpus avoids %d of -0.0 (doc gap)"
        iv = -v.numerator if s else v.numerator
        return pad(spec, sign_text(spec, iv < 0), str(abs(iv)), True)
    e_spec = Spec("%" + spec.flags + (str(spec.width) if spec.width else "") + ".6e")
    return fmt_float_bits(e_spec, b)


def fmt_str(spec, data):
    """%s of a byte string (bytes)."""
    if spec.prec is not None:
        data = data[: spec.prec]
    w = spec.width or 0
    if len(data) >= w:
        return data
    if spec.has("-"):
        return data + b" " * (w - len(data))
    return b" " * (w - len(data)) + data


def format_all(fmt, args):
    """Format a whole printf call: fmt is the unescaped format bytes (str of latin-1),
    args a list of ('i', int) | ('f', bits) | ('s', bytes)."""
    out = b""
    i = 0
    ai = 0
    while i < len(fmt):
        c = fmt[i]
        if c != "%":
            out += c.encode("latin-1")
            i += 1
            continue
        if fmt[i + 1] == "%":
            out += b"%"
            i += 2
            continue
        j = i + 1
        while fmt[j] not in "diufFeEgGs":
            j += 1
        spec = Spec(fmt[i: j + 1])
        kind, val = args[ai]
        ai += 1
        if spec.conv in "di":
            if kind == "i":
                out += fmt_int(spec, val).encode()
            else:
                out += fmt_d_f64(spec, val).encode()
        elif spec.conv == "s":
            out += fmt_str(spec, val)
        else:
            b = fo.i_to_f(val) if kind == "i" else val
            out += fmt_float_bits(spec, b).encode()
        i = j + 1
    assert ai == len(args)
    return out


# ------------------------------------------------------------------ cross-check
def cross_check():
    """The C99 part against Python's own formatting (an independent implementation)."""
    import random
    import struct
    rnd = random.Random(2026)
    specs = ["%f", "%.0f", "%.3f", "%e", "%.0e", "%.10e", "%g", "%.1g", "%.12g", "%#g",
             "%#.0f", "%#.0e", "%+.2e", "% g", "%012.4f", "%-12.3e", "%G", "%E", "%.17g"]
    vals = [0.0, -0.0, 0.5, 1.5, 2.5, 0.125, 1e-5, 1e-4, 123456.0, 1e21, 5e-324,
            1.7976931348623157e308, 9.9999996, 0.95, 99.5]
    for _ in range(300):
        vals.append(rnd.uniform(-1e6, 1e6) * 10 ** rnd.randint(-20, 20))
    for s in specs:
        for x in vals:
            b = struct.unpack(">Q", struct.pack(">d", x))[0]
            assert fmt_float_bits(Spec(s), b) == (s % x), (s, x)
    for s in ["%d", "%5d", "%-5d", "%05d", "%+d", "% d", "%+5d"]:
        for v in [0, 7, -7, 12345, -9223372036854775808, 9223372036854775807]:
            assert fmt_int(Spec(s), v) == (s % v), (s, v)


# ------------------------------------------------------------------ program writer
def sea_string(fmt_bytes):
    """A Sea string literal for format bytes: escapes for LF, TAB, quote, backslash."""
    out = ""
    for ch in fmt_bytes:
        if ch == "\n":
            out += "\\n"
        elif ch == "\t":
            out += "\\t"
        elif ch == '"':
            out += '\\"'
        elif ch == "\\":
            out += "\\\\"
        else:
            out += ch
    return out


def write_program(name, header, cases, prologue=()):
    """cases: list of (fmt, [(sea_expr, (kind, value)), ...]); one printf per case."""
    src = ["// %s -- %s" % (name, header[0])] + ["// " + h for h in header[1:]]
    src += list(prologue)
    out = b""
    for fmt, args in cases:
        call = 'printf("%s"' % sea_string(fmt)
        for expr, _ in args:
            call += ", " + expr
        call += ")"
        src.append(call)
        out += format_all(fmt, [a for _, a in args])
    with open(os.path.join(PROGRAMS, name + ".sea"), "w") as f:
        f.write("\n".join(src) + "\n")
    with open(os.path.join(PROGRAMS, name + ".out"), "wb") as f:
        f.write(out)


def L(text):
    """A Sea float literal argument: (source, ('f', bits))."""
    return (text, ("f", fo.literal_bits(text)))


def NL(text):
    """A negated Sea float literal: -(literal)."""
    return ("-" + text, ("f", fo.f_neg(fo.literal_bits(text))))


def I(v, src=None):
    return (src if src is not None else str(v), ("i", v))


def S(text):
    """A string literal argument; text is the Sea source between the quotes (no escapes
    other than those handled here)."""
    data = text.encode("utf-8").replace(b"\\t", b"\t").replace(b"\\n", b"\n")
    return ('"' + text + '"', ("s", data))


def B(src, bits):
    return (src, ("f", bits))


# ------------------------------------------------------------------ the tests
def gen_fmt_f():
    c = [
        ("[%f]\n", [L("0.0")]),
        ("[%f]\n", [NL("0.0")]),
        ("[%f]\n", [L("1.5")]),
        ("[%f]\n", [NL("2.75")]),
        ("[%.0f] [%.0f] [%.0f] [%.0f]\n", [L("0.5"), L("1.5"), L("2.5"), L("3.5")]),
        ("[%.2f] [%.2f] [%.2f]\n", [L("0.125"), L("0.375"), L("2.675")]),
        ("[%.1f] [%.1f]\n", [L("0.05"), L("0.25")]),
        ("[%.3f]\n", [L("1e-4")]),
        ("[%.20f]\n", [L("0.1")]),
        ("[%f]\n", [L("1e20")]),
        ("[%f]\n", [L("1.7976931348623157e308")]),
        ("[%f] [%.0f]\n", [L("5e-324"), L("5e-324")]),
        ("[%10.4f]\n", [L("3.14159265358979")]),
        ("[%-10.2f]\n", [L("3.14159265358979")]),
        ("[%+.3f] [% .3f] [%+.3f] [% .3f]\n", [L("2.0"), L("2.0"), NL("2.0"), NL("2.0")]),
        ("[%010.3f] [%010.3f]\n", [NL("3.14159"), L("3.14159")]),
        ("[%-010.3f]\n", [L("3.14159")]),
        ("[%#.0f] [%.0f]\n", [L("3.0"), L("3.0")]),
        ("[%F]\n", [L("1.25")]),
        ("[%5.1f]\n", [L("99.95")]),
        ("[%.1f]\n", [L("0.95")]),
        ("[%f] [%.0f]\n", [I(3), I(9007199254740993, "big")]),
        ("[%3f]\n", [L("12.5")]),
    ]
    write_program("fmt_f", ["printf %f and %F of f64 and i64 values (LANGUAGE.md 11.1, C99);",
                            "expected bytes from tests/vectors/progfmt.py (exact decimal)."], c,
                  ["let big = 9007199254740993   // an i64 that %f converts, rounding to even"])


def gen_fmt_e():
    c = [
        ("[%e]\n", [L("0.0")]),
        ("[%e]\n", [NL("0.0")]),
        ("[%e]\n", [L("1.0")]),
        ("[%e]\n", [L("123456.789")]),
        ("[%.2e] [%.2e]\n", [L("1.125"), L("1.135")]),
        ("[%.0e] [%#.0e]\n", [L("2.5"), L("2.5")]),
        ("[%E]\n", [L("1e-10")]),
        ("[%e] [%e]\n", [L("1e100"), L("1e-100")]),
        ("[%e]\n", [L("5e-324")]),
        ("[%e]\n", [L("1.7976931348623157e308")]),
        ("[%.16e]\n", [L("0.1")]),
        ("[%12.3e] [%-12.3e]\n", [NL("1234.5"), NL("1234.5")]),
        ("[%+e] [% e]\n", [L("1.5"), L("1.5")]),
        ("[%012.3e]\n", [L("1234.5")]),
        ("[%e]\n", [L("9.9999996")]),
        ("[%e] [%.3E]\n", [I(7), I(-1234567)]),
        ("[%.30e]\n", [L("1e23")]),
    ]
    write_program("fmt_e", ["printf %e and %E (LANGUAGE.md 11.1, C99: at least two exponent",
                            "digits); expected bytes from tests/vectors/progfmt.py."], c)


def gen_fmt_g():
    c = [
        ("[%g] [%g]\n", [L("0.0"), NL("0.0")]),
        ("[%g] [%g]\n", [L("100000.0"), L("1000000.0")]),
        ("[%g] [%g]\n", [L("1e-4"), L("1e-5")]),
        ("[%g]\n", [L("123456789.0")]),
        ("[%g] [%.17g]\n", [L("0.1"), L("0.1")]),
        ("[%g] [%#g]\n", [L("3.0"), L("3.0")]),
        ("[%G] [%G]\n", [L("1e-10"), L("1.5e20")]),
        ("[%.0g] [%.1g] [%.1g]\n", [L("2.5"), L("0.95"), L("0.96")]),
        ("[%.2g]\n", [L("99.5")]),
        ("[%10.4g] [%-10.4g]\n", [L("3.14159265358979"), L("3.14159265358979")]),
        ("[%+g] [% g]\n", [L("1.5"), L("1.5")]),
        ("[%010g]\n", [NL("1.5")]),
        ("[%.17g]\n", [L("1.7976931348623157e308")]),
        ("[%g]\n", [L("5e-324")]),
        ("[%g] [%g]\n", [I(1234567), I(-42)]),
        ("[%#.3g] [%.3g]\n", [L("1.0"), L("1.0")]),
        ("[%g]\n", [L("0.0001234567")]),
        ("[%.3g]\n", [L("1e-5")]),
    ]
    write_program("fmt_g", ["printf %g and %G (LANGUAGE.md 11.1, C99 style choice and",
                            "trailing-zero removal); expected bytes from tests/vectors/progfmt.py."],
                  c)


def gen_fmt_d():
    c = [
        ("[%d] [%d] [%d]\n", [I(0), I(42), I(-42, "-42")]),
        ("[%d]\n", [I(9223372036854775807)]),
        ("[%d]\n", [I(-9223372036854775808, "-9223372036854775808")]),
        ("[%5d] [%-5d] [%05d]\n", [I(42), I(42), I(-42, "-42")]),
        ("[%+d] [%+d] [% d] [% d]\n", [I(42), I(0), I(42), I(-42, "-42")]),
        ("[%+5d] [%-+5d]\n", [I(-3, "-3"), I(3)]),
        ("[%3d]\n", [I(12345)]),
        ("[%i] [%4i]\n", [I(7), I(-7, "-7")]),
        ("[%d]\n", [I(-6, "2 - 8")]),
        ("[%d]\n", [I(1000000, "1_000_000")]),
        ("[%d]\n", [I(255, "0xFF")]),
    ]
    write_program("fmt_d", ["printf %d and %i of i64 values with flags and width",
                            "(LANGUAGE.md 11.1); expected bytes from tests/vectors/progfmt.py."], c)


def gen_fmt_d_f64():
    c = [
        ("[%d] [%d]\n", [L("3.0"), NL("3.0")]),
        ("[%d]\n", [L("1e20")]),
        ("[%d]\n", [L("9223372036854775808.0")]),
        ("[%d]\n", [L("1.7976931348623157e308")]),
        ("[%5d] [%-5d] [%+d] [%05d]\n", [L("2.0"), L("2.0"), L("2.0"), NL("3.0")]),
        ("[%d]\n", [L("1.5")]),
        ("[%12d] [%14d]\n", [L("1.5"), NL("2.5")]),
        ("[%+d] [% d]\n", [L("0.1"), L("0.1")]),
        ("[%-15d]\n", [L("0.1")]),
        ("[%d]\n", [L("5e-324")]),
        ("[%i]\n", [L("1e-3")]),
    ]
    write_program("fmt_d_f64", ["printf %d of f64 values: the MATLAB rule (integral values as",
                                "the integer, others as %e with precision 6; LANGUAGE.md 11.1)."],
                  c)


def gen_fmt_s():
    c = [
        ("[%s]\n", [S("abc")]),
        ("[%5s] [%-5s]\n", [S("ab"), S("ab")]),
        ("[%.2s] [%5.1s]\n", [S("abcdef"), S("xyz")]),
        ("[%s]\n", [S("")]),
        ("[%4s]\n", [S("é")]),
        ("[%s]\n", [S("a\\tb")]),
        ("%s-%s\n", [S("left"), S("right")]),
        ("[%3s]\n", [S("abcdef")]),
    ]
    write_program("fmt_s", ["printf %s of string literals: bytes, width and precision count",
                            "bytes (LANGUAGE.md 11.1)."], c)


def gen_fmt_pct():
    c = [
        ("%%\n", []),
        ("100%%\n", []),
        ("%d%%\n", [I(50)]),
        ("%%d\n", []),
        ("[%%%d%%]\n", [I(7)]),
    ]
    write_program("fmt_pct", ["%% prints one percent sign (LANGUAGE.md 11.1)."], c)


def gen_fmt_nonfinite():
    c = [
        ("[%f] [%f] [%f]\n", [B("inf", INF), B("-inf", NINF), B("nan", QNAN)]),
        ("[%+f] [% f] [%+f] [% f]\n", [B("inf", INF), B("inf", INF), B("-inf", NINF),
                                        B("-inf", NINF)]),
        ("[%+f] [% f] [%f]\n", [B("nan", QNAN), B("nan", QNAN), B("-nan", NNAN)]),
        ("[%e] [%E] [%g] [%G] [%F]\n", [B("inf", INF), B("inf", INF), B("-inf", NINF),
                                        B("nan", QNAN), B("nan", QNAN)]),
        ("[%+8.2f]\n", [B("inf", INF)]),
        ("[%08d]\n", [B("nan", QNAN)]),
        ("[%08.3f] [%-8f] [%#g]\n", [B("inf", INF), B("-inf", NINF), B("inf", INF)]),
        ("[%d] [%5i] [%-6d]\n", [B("inf", INF), B("-inf", NINF), B("nan", QNAN)]),
        ("[%2f]\n", [B("-inf", NINF)]),
        ("[%f] [%f]\n", [B("1.0 / 0.0", INF), B("-1.0 / 0.0", NINF)]),
        ("[%f]\n", [B("0.0 / 0.0", QNAN | 0)]),
    ]
    write_program("fmt_nonfinite",
                  ["Inf, -Inf, NaN in every numeric conversion (LANGUAGE.md 11.1): the +",
                   "and space flags sign +Inf, NaN is never signed, 0/# and precision are",
                   "ignored, padding is with spaces."], c)


# ------------------------------------------------------------------ arithmetic and order
def gen_op_f64_arith():
    one = fo.literal_bits("0.1")
    two = fo.literal_bits("0.2")
    c = [
        ("%.17g\n", [B("0.1 + 0.2", fo.f_add(one, two))]),
        ("%.17g\n", [B("0.3 - 0.1", fo.f_sub(fo.literal_bits("0.3"), one))]),
        ("%.17g\n", [B("0.1 * 3.0", fo.f_mul(one, fo.literal_bits("3.0")))]),
        ("%.17g\n", [B("1.0 / 3.0", fo.f_div(fo.literal_bits("1.0"), fo.literal_bits("3.0")))]),
        ("%.17g\n", [B("2.0 / 3", fo.f_div(fo.literal_bits("2.0"), fo.f_from_int_exact(3)))]),
        ("%.17g\n", [B("7 / 2", fo.f_div(fo.f_from_int_exact(7), fo.f_from_int_exact(2)))]),
        ("%.17g\n", [B("1 / 3", fo.f_div(fo.f_from_int_exact(1), fo.f_from_int_exact(3)))]),
        ("%.17g\n", [B("-(0.5 - 0.5)", fo.f_neg(fo.f_sub(fo.literal_bits("0.5"),
                                                          fo.literal_bits("0.5"))))]),
        ("%g %g\n", [B("1e308 * 10.0", INF), B("-1e308 * 10.0", NINF)]),
        ("%g\n", [B("5e-324 / 2.0", 0)]),
        ("%g\n", [B("1.0 / 0.0 - 1.0 / 0.0", QNAN)]),
        ("%.17g\n", [B("1e16 + 1.0", fo.f_add(fo.literal_bits("1e16"), fo.literal_bits("1.0")))]),
        ("%.17g\n", [B("2.5e-324 + 2.5e-324",
                       fo.f_add(fo.literal_bits("2.5e-324"), fo.literal_bits("2.5e-324")))]),
        ("%.17g\n", [B("3 * 0.1", fo.f_mul(fo.f_from_int_exact(3), one))]),
    ]
    write_program("op_f64_arith",
                  ["f64 + - * / and unary - are single IEEE binary64 operations, round to",
                   "nearest even; / of two i64 divides in f64; Inf/NaN are values",
                   "(LANGUAGE.md 6.5, 6.8, 4.2); digits from tests/vectors/progfmt.py."], c)


def gen_op_order():
    """Left-to-right association and no contraction (LANGUAGE.md 6.1, 6.8)."""
    f = fo.literal_bits
    a, b, c_ = f("0.1"), f("0.2"), f("0.3")
    big, one = f("1e16"), f("1.0")
    rpm, two, pi, sixty = f("1500.0"), f("2.0"), 0x400921FB54442D18, fo.f_from_int_exact(60)
    x, y, z = f("1.1"), f("1.3"), fo.f_neg(f("1.43"))
    cases = [
        ("%.17g\n", [B("0.1 + 0.2 + 0.3", fo.f_add(fo.f_add(a, b), c_))]),
        ("%.17g\n", [B("0.1 + (0.2 + 0.3)", fo.f_add(a, fo.f_add(b, c_)))]),
        ("%.17g\n", [B("1e16 + 1.0 + 1.0", fo.f_add(fo.f_add(big, one), one))]),
        ("%.17g\n", [B("1e16 + (1.0 + 1.0)", fo.f_add(big, fo.f_add(one, one)))]),
        ("%.17g\n", [B("2 * pi * 1500.0 / 60",
                       fo.f_div(fo.f_mul(fo.f_mul(two, pi), rpm), sixty))]),
        ("%.17g\n", [B("1.1 * 1.3 + -1.43", fo.f_add(fo.f_mul(x, y), z))]),
        ("%.17g\n", [B("1.0 - 0.9 - 0.1", fo.f_sub(fo.f_sub(one, f("0.9")), a))]),
        ("%.17g\n", [B("1.0 / 3.0 * 3.0", fo.f_mul(fo.f_div(one, f("3.0")), f("3.0")))]),
        ("%.17g\n", [B("0.1 * 10.0 / 10.0", fo.f_div(fo.f_mul(a, f("10.0")), f("10.0")))]),
        ("%.17g\n", [B("0.7 / 0.1", fo.f_div(f("0.7"), a))]),
    ]
    write_program("op_order",
                  ["operation order: left associativity, parentheses, no reassociation and",
                   "no fused multiply-add (LANGUAGE.md 6.1, 6.8); digits from progfmt.py."],
                  cases)


def gen_lib_consts():
    pi, eps = 0x400921FB54442D18, 0x3CB0000000000000
    cases = [
        ("%.17g\n", [B("pi", pi)]),
        ("%.17g\n", [B("eps", eps)]),
        ("%g %g %g\n", [B("inf", INF), B("-inf", NINF), B("nan", QNAN)]),
        ("%.17g\n", [B("2.0 * pi", fo.f_mul(fo.literal_bits("2.0"), pi))]),
        ("%.17g\n", [B("1.0 + eps", fo.f_add(fo.literal_bits("1.0"), eps))]),
        ("%.17g\n", [B("1.0 + eps / 2.0", fo.f_add(fo.literal_bits("1.0"),
                                                   fo.f_div(eps, fo.literal_bits("2.0"))))]),
        ("%.17g\n", [B("TAU", fo.f_mul(pi, fo.literal_bits("2.0")))]),
        ("%d\n", [I(1000, "N")]),
        ("%d\n", [I(2000, "M")]),
        ("%.17g\n", [B("HALF", fo.literal_bits("0.5"))]),
        ("%.17g\n", [B("N * HALF", fo.f_mul(fo.f_from_int_exact(1000), fo.literal_bits("0.5")))]),
        ("%.17g\n", [B("K", fo.f_from_int_exact(3))]),
    ]
    prologue = ["const TAU = pi * 2.0",
                "const N = 1000",
                "const M = N * 2",
                "const HALF: f64 = 0.5",
                "const K: f64 = 3"]
    write_program("lib_consts",
                  ["pi inf nan eps (LANGUAGE.md 10.1; bits DESIGN.md 3.5.5) and const items",
                   "(LANGUAGE.md 7.2); digits from tests/vectors/progfmt.py."],
                  cases, prologue)


def gen_op_powk():
    """x ^ k for a constant integral |k| <= 4: the pinned multiplications (LANGUAGE.md 6.5).
    x = 1.1 is chosen so that (x*x)*(x*x) differs from ((x*x)*x)*x."""
    m, d = fo.f_mul, fo.f_div
    x = fo.literal_bits("1.1")
    one = fo.literal_bits("1.0")
    x2 = m(x, x)
    x3 = m(x2, x)
    x4 = m(x2, x2)
    assert x4 != m(x3, x)
    cases = [
        ("%.17g %.17g\n", [B("x ^ 0", one), B("x ^ 1", x)]),
        ("%.17g\n", [B("x ^ 2", x2)]),
        ("%.17g\n", [B("x ^ 3", x3)]),
        ("%.17g\n", [B("x ^ 4", x4)]),
        ("%.17g\n", [B("x * x * x * x", m(x3, x))]),
        ("%.17g\n", [B("x ^ -1", d(one, x))]),
        ("%.17g\n", [B("x ^ -2", d(one, x2))]),
        ("%.17g\n", [B("x ^ -3", d(one, x3))]),
        ("%.17g\n", [B("x ^ -4", d(one, x4))]),
        ("%.17g %.17g\n", [B("x ^ 2.0", x2), B("x ^ (6 % 4)", x2)]),
        ("%.17g\n", [B("x ^ K", x4)]),
        ("%g %g\n", [B("2 ^ 3", fo.literal_bits("8.0")), B("n ^ 2", fo.literal_bits("9.0"))]),
        ("%.17g\n", [B("-x ^ 2", fo.f_neg(x2))]),
        ("%g %g %g\n", [B("nan ^ 0", one), B("inf ^ -1", 0), B("0.0 ^ -1", INF)]),
        ("%g\n", [B("x ^ -0.0", one)]),
    ]
    write_program("op_powk",
                  ["x ^ k with a constant integral |k| <= 4 is x^0 = 1, x^1 = x, x^2 = x*x,",
                   "x^3 = (x*x)*x, x^4 = (x*x)*(x*x), x^-k = 1/(x^k) (LANGUAGE.md 6.5); the",
                   "result is f64; digits from tests/vectors/progfmt.py."],
                  cases, ["const K = 2 + 2", "let x = 1.1", "let n = 3"])


if __name__ == "__main__":
    cross_check()
    gen_fmt_f()
    gen_fmt_e()
    gen_fmt_g()
    gen_fmt_d()
    gen_fmt_d_f64()
    gen_fmt_s()
    gen_fmt_pct()
    gen_fmt_nonfinite()
    gen_op_f64_arith()
    gen_op_order()
    gen_lib_consts()
    gen_op_powk()
    print("progfmt: cross-check passed; programs written")
