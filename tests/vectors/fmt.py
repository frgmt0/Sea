"""Exact printf test vectors for Sea's runtime formatter (rt_fmt.s).

Run from anywhere with:  uv run python sea/tests/vectors/fmt.py

Writes, into sea/tests/rt/arm64_macos/ and (the same cases, x86_64 GNU as syntax, DESIGN.md
4.7.1) sea/tests/rt/x86_64_linux/, one runtime test per group:
  rt_fmt_<group>.s    an assembly _sea_main that calls _sea_printf (or
                      _sea_fmt_g) with hand-built pre-parsed formats
                      (SEA_FMT_* / SEA_FP_* layout, DESIGN.md 4.8) and
                      argument slots
  rt_fmt_<group>.out  the exact bytes LANGUAGE.md 11.1 requires (identical for both targets)
The outputs are committed; tests read only them (DESIGN.md 6.2).

The expected bytes are computed here from the spec, never from the
runtime: every finite f64 is taken as the exact rational value of its
bits (fractions.Fraction) and rounded to the requested decimal digits
with round-half-even (C99 7.19.6.1 / F.5: correctly rounded, the current
rounding mode being to-nearest-even), with C99's rules for flags, width,
precision and the %g style choice; non-finite values and %d of f64
follow LANGUAGE.md 11.1 (MATLAB spelling and rules). As an independent
sanity check, every finite float conversion with precision <= 300 is also
compared with Python's own %-formatting (correctly rounded too); a
mismatch aborts the script.
"""

from __future__ import annotations

import math
import os
import struct
import sys
from fractions import Fraction

HERE = os.path.dirname(os.path.abspath(__file__))
OUTDIR = os.path.normpath(os.path.join(HERE, "..", "rt", "arm64_macos"))
OUTDIR_X64 = os.path.normpath(os.path.join(HERE, "..", "rt", "x86_64_linux"))

INT64_MIN = -(1 << 63)
INT64_MAX = (1 << 63) - 1

# ---------------------------------------------------------------------------
# Values
# ---------------------------------------------------------------------------


def fbits(x: float) -> int:
    """Bits of a Python float as an unsigned 64-bit integer."""
    return struct.unpack("<Q", struct.pack("<d", x))[0]


def bits_f(b: int) -> float:
    return struct.unpack("<d", struct.pack("<Q", b))[0]


NAN = 0x7FF8000000000000
NEG_NAN = 0xFFF8000000000000
PINF = 0x7FF0000000000000
NINF = 0xFFF0000000000000
DBL_MAX = bits_f(0x7FEFFFFFFFFFFFFF)
DBL_TRUE_MIN = bits_f(1)              # 2^-1074, 4.94e-324
DBL_MIN = bits_f(0x0010000000000000)  # 2^-1022


# ---------------------------------------------------------------------------
# The exact formatter (the spec, written out)
# ---------------------------------------------------------------------------


def pad(body: str, sign_len: int, width: int, flags: str, zero_ok: bool) -> str:
    """Pad to the width: spaces left, spaces right with '-', zeros after the
    sign with '0' (when allowed and without '-')."""
    if width < 0 or len(body) >= width:
        return body
    n = width - len(body)
    if "-" in flags:
        return body + " " * n
    if "0" in flags and zero_ok:
        return body[:sign_len] + "0" * n + body[sign_len:]
    return " " * n + body


def sign_prefix(negative: bool, flags: str) -> str:
    if negative:
        return "-"
    if "+" in flags:
        return "+"
    if " " in flags:
        return " "
    return ""


def exp10_floor(v: Fraction) -> int:
    """Largest e with 10^e <= v, for v > 0."""
    e = math.floor(math.log10(v.numerator) - math.log10(v.denominator))
    while Fraction(10) ** e > v:
        e -= 1
    while Fraction(10) ** (e + 1) <= v:
        e += 1
    return e


def e_digits(v: Fraction, p: int) -> tuple[str, int]:
    """v >= 0 rounded to p+1 significant digits, ties to even:
    (digit string of length p+1, decimal exponent)."""
    if v == 0:
        return "0" * (p + 1), 0
    e = exp10_floor(v)
    n = round(v / Fraction(10) ** (e - p))  # Fraction.__round__: half even
    if n >= 10 ** (p + 1):
        n //= 10  # exactly 10^(p+1): the carry moved a decade up
        e += 1
    return str(n), e


def exp_text(e: int, upper: bool) -> str:
    return ("E" if upper else "e") + ("-" if e < 0 else "+") + "%02d" % abs(e)


def f_body(v: Fraction, p: int, alt: bool) -> str:
    n = round(v * Fraction(10) ** p)
    s = str(n).rjust(p + 1, "0")
    if p == 0:
        return s + ("." if alt else "")
    return s[:-p] + "." + s[-p:]


def e_body(v: Fraction, p: int, alt: bool, upper: bool) -> str:
    d, e = e_digits(v, p)
    m = d[0] + ("." + d[1:] if p > 0 else ("." if alt else ""))
    return m + exp_text(e, upper)


def g_body(v: Fraction, p: int, alt: bool, upper: bool) -> str:
    P = 6 if p < 0 else (1 if p == 0 else p)
    _, X = e_digits(v, P - 1)
    if P > X >= -4:
        s = f_body(v, P - 1 - X, alt)
        if not alt and "." in s:
            s = s.rstrip("0").rstrip(".")
        return s
    s = e_body(v, P - 1, alt, upper)
    if not alt:
        k = s.index("E" if upper else "e")
        m = s[:k]
        if "." in m:
            m = m.rstrip("0").rstrip(".")
        s = m + s[k:]
    return s


def nonfinite(bits: int, flags: str, width: int) -> str:
    """LANGUAGE.md 11.1: MATLAB spelling, spaces only."""
    if (bits << 1) & 0xFFFFFFFFFFFFFFFF > 0xFFE0000000000000:
        body = "NaN"  # never signed
    elif bits >> 63:
        body = "-Inf"
    else:
        body = sign_prefix(False, flags) + "Inf"
    return pad(body, 0, width, flags, zero_ok=False)


def is_nonfinite(bits: int) -> bool:
    return (bits << 1) & 0xFFFFFFFFFFFFFFFF >= 0xFFE0000000000000


def fmt_float(bits: int, conv: str, flags: str, width: int, prec: int) -> str:
    if is_nonfinite(bits):
        return nonfinite(bits, flags, width)
    x = bits_f(bits)
    negative = bool(bits >> 63)
    v = abs(Fraction(x))
    alt = "#" in flags
    p = 6 if prec < 0 else prec
    lc = conv.lower()
    if lc == "f":
        b = f_body(v, p, alt)
    elif lc == "e":
        b = e_body(v, p, alt, conv == "E")
    else:
        b = g_body(v, prec, alt, conv == "G")
    s = sign_prefix(negative, flags)
    out = pad(s + b, len(s), width, flags, zero_ok=True)
    if prec <= 300:
        cross_check(out, x, conv, flags, width, prec)
    return out


def cross_check(out: str, x: float, conv: str, flags: str, width: int, prec: int) -> None:
    pf = "%" + flags + (str(width) if width >= 0 else "") + ("." + str(prec) if prec >= 0 else "") + conv
    py = pf % x
    if py != out:
        sys.exit("fmt.py: exact formatter disagrees with Python for %r %% %r: %r vs %r" % (pf, x, out, py))


def fmt_int(value: int, flags: str, width: int, prec: int) -> str:
    """C99 %d of an integer: precision = minimum digits (0 with 0: none),
    the 0 flag ignored when a precision is given."""
    negative = value < 0
    digits = str(abs(value))
    if prec == 0 and value == 0:
        digits = ""
    if prec > len(digits):
        digits = "0" * (prec - len(digits)) + digits
    s = sign_prefix(negative, flags)
    return pad(s + digits, len(s), width, flags, zero_ok=prec < 0)


def fmt_d_f64(bits: int, flags: str, width: int, prec: int) -> str:
    """LANGUAGE.md 11.1, %d of an f64 (MATLAB rule)."""
    if is_nonfinite(bits):
        return nonfinite(bits, flags, width)
    x = bits_f(bits)
    if x == math.trunc(x):
        # the integer it is, exactly (-0.0 is the integer 0)
        return fmt_int(int(Fraction(x)), flags, width, prec)
    return fmt_float(bits, "e", flags, width, 6)


def fmt_s(data: bytes, flags: str, width: int, prec: int) -> bytes:
    if prec >= 0:
        data = data[:prec]
    if width > len(data):
        n = width - len(data)
        data = data + b" " * n if "-" in flags else b" " * n + data
    return data


# ---------------------------------------------------------------------------
# Test cases
# ---------------------------------------------------------------------------


class Conv:
    """One conversion piece and its argument.
    cls: 'i' (i64/bool value), 'f' (f64 bits), 'p' (str bytes)."""

    def __init__(self, conv: str, cls: str, value, flags: str = "", width: int = -1, prec: int = -1):
        self.conv, self.cls, self.value = conv, cls, value
        self.flags, self.width, self.prec = flags, width, prec

    def spelled(self) -> str:
        return ("%" + self.flags + (str(self.width) if self.width >= 0 else "")
                + ("." + str(self.prec) if self.prec >= 0 else "") + self.conv)

    def expected(self) -> bytes:
        c, f, w, p = self.conv, self.flags, self.width, self.prec
        if c == "s":
            return fmt_s(self.value, f, w, p)
        if c in "di":
            if self.cls == "i":
                return fmt_int(self.value, f, w, p).encode()
            return fmt_d_f64(self.value, f, w, p).encode()
        if self.cls == "i":
            # i64 argument of a float conversion: converted, ties to even
            # (Python's int -> float conversion is correctly rounded).
            return fmt_float(fbits(float(self.value)), c, f, w, p).encode()
        return fmt_float(self.value, c, f, w, p).encode()


def I(conv, value, flags="", width=-1, prec=-1):
    return Conv(conv, "i", value, flags, width, prec)


def F(conv, x, flags="", width=-1, prec=-1):
    """f64 argument: a Python float, or raw bits given as ('bits', b)."""
    b = x[1] if isinstance(x, tuple) else fbits(x)
    return Conv(conv, "f", b, flags, width, prec)


def S(value: bytes, flags="", width=-1, prec=-1):
    return Conv("s", "p", value, flags, width, prec)


def B(b):
    return ("bits", b)


def bracket(c: Conv) -> list:
    """The usual test format: "[" conv "]\n"."""
    return [b"[", c, b"]\n"]


GROUPS: dict[str, list[list]] = {}

# ---- integers (i64, bool) -------------------------------------------------
_int = []
for v in (0, 1, -1, 42, -42, 1234567, INT64_MAX, INT64_MIN):
    for flags, width, prec in (("", -1, -1), ("", 5, -1), ("-", 5, -1), ("0", 5, -1),
                               ("+", -1, -1), (" ", -1, -1), ("+0", 8, -1), ("-+", 8, -1),
                               ("", -1, 3), ("", 8, 3), ("-", 8, 3), ("0", 8, 3),
                               ("", -1, 0), ("+", -1, 0), (" ", 4, 0), ("0", 25, -1),
                               ("", -1, 25), ("+", 30, 22), (" 0", 24, -1)):
        _int.append(bracket(I("d", v, flags, width, prec)))
_int.append(bracket(I("i", -77, "", 6)))
_int.append(bracket(I("i", 77, "-0", 6)))     # 0 ignored with -
_int.append(bracket(I("d", 1)))               # bool true
_int.append(bracket(I("d", 0, "", 3)))        # bool false, width 3
_int.append(bracket(I("d", 7, "", 300)))      # padding longer than one fill block
_int.append(bracket(I("d", -7, "-", 300)))
_int.append(bracket(I("d", -7, "0", 600)))
_int.append(bracket(I("d", 5, "", -1, 520)))  # precision zeros beyond one fill block
GROUPS["int"] = _int

# ---- %d of f64 (MATLAB rule) ---------------------------------------------
_df = []
for x in (0.0, -0.0, 1.0, -1.0, 7.0, 1e15, 1e20, -1e20, 2.0 ** 53 + 2, 123456789012345678.0,
          2.0 ** 63, -(2.0 ** 63), 2.0 ** 64, 1e308, DBL_MAX, -DBL_MAX):
    for flags, width, prec in (("", -1, -1), ("+", -1, -1), ("", 25, -1), ("-", 25, -1),
                               ("0", 25, -1), ("", -1, 3), (" ", 12, 5), ("0", 30, 25)):
        _df.append(bracket(F("d", x, flags, width, prec)))
for x in (1.5, -1.5, 0.1, -0.1, 2.5, 123.456, 1e-310, -DBL_TRUE_MIN, 4503599627370495.5):
    for flags, width, prec in (("", -1, -1), ("+", -1, -1), ("", 15, -1), ("-", 15, -1),
                               ("0", 15, -1), ("", -1, 2), (" ", -1, 10)):
        _df.append(bracket(F("d", x, flags, width, prec)))
for b in (NAN, NEG_NAN, PINF, NINF):
    for flags, width, prec in (("", -1, -1), ("", 8, -1), ("-", 8, -1), ("+", 8, -1),
                               (" ", -1, -1), ("0", 8, -1), ("+0", 8, 3), ("+-", 7, -1)):
        _df.append(bracket(F("d", B(b), flags, width, prec)))
_df.append(bracket(F("i", 42.0, "", 6)))
_df.append(bracket(F("i", 0.5)))
GROUPS["dfloat"] = _df

# ---- f F e E g G, finite -------------------------------------------------
_fl = []
# Exact ties, round half to even (LANGUAGE.md 11.1: %.2f of 0.125 is 0.12).
for x, p in ((0.125, 2), (0.375, 2), (0.625, 2), (2.5, 0), (3.5, 0), (0.5, 0), (1.5, 0),
             (-2.5, 0), (-0.5, 0), (1.25, 1), (1.35, 1), (2.675, 2), (1e22 + 0.0, 0),
             (0.0625, 3), (5e-324, 0)):
    _fl.append(bracket(F("f", x, "", -1, p)))
for x, p in ((15.0, 0), (25.0, 0), (35.0, 0), (0.25, 1), (1.125, 2), (9.999, 2), (9.995, 2),
             (125.0, 1), (5.0, 0)):
    _fl.append(bracket(F("e", x, "", -1, p)))
for x, p in ((0.5, 0), (2.5, 1), (25.0, 1), (35.0, 1), (0.000125, 2), (1234567.0, 6)):
    _fl.append(bracket(F("g", x, "", -1, p)))
# Values across the range, each under every letter with defaults.
VALS = (0.0, -0.0, 1.0, -1.0, 1.0 / 3.0, -2.0 / 3.0, 0.1, 100000.0, 999999.0, 999999.5,
        1e6, 1234567.0, 1e-4, 0.00009999995, 1e-5, 123.456, 1e100, -1e-100, 1e300, 1e-300,
        DBL_MAX, -DBL_MAX, DBL_MIN, DBL_TRUE_MIN, 2.2250738585072009e-308, 6.02214076e23,
        3.141592653589793, 2.0 ** 53, 1e15, 1e16, 1e17)
for x in VALS:
    for conv in ("f", "F", "e", "E", "g", "G"):
        _fl.append(bracket(F(conv, x)))
# Flags, width and precision.
for x in (3.14159265358979, -3.14159265358979, 0.0, -0.0, 1e-7, 12345.678, -1e10):
    for conv in ("f", "e", "g"):
        for flags, width, prec in (("+", -1, -1), (" ", -1, -1), ("+ ", -1, -1), ("", 15, 3),
                                   ("-", 15, 3), ("0", 15, 3), ("+0", 15, 3), ("-0", 15, 3),
                                   ("#", -1, 0), ("#", 12, -1), ("#0", 14, 2), (" 0", 12, 1),
                                   ("", -1, 17), ("", 3, 1)):
            _fl.append(bracket(F(conv, x, flags, width, prec)))
# %g style switch around P > X >= -4, and # keeping zeros.
for x in (0.0001, 0.00012345, 0.000099999, 0.0000999999, 123456.0, 1234567.0, 999999.4,
          9999995.0, 1e-10, 1.0, 10.0, 100.0):
    for flags, prec in (("", -1), ("#", -1), ("", 3), ("#", 3), ("", 0), ("#", 0), ("", 1), ("", 10)):
        _fl.append(bracket(F("g", x, flags, -1, prec)))
        _fl.append(bracket(F("G", x, flags, -1, prec)))
# Three-digit exponents and subnormals.
for x in (1e-100, 1e100, 1e-307, 1e-308, 1e-320, 4.9406564584124654e-324, 1.7976931348623157e308):
    for conv, prec in (("e", 3), ("E", 0), ("g", 4), ("e", 20), ("G", 17)):
        _fl.append(bracket(F(conv, x, "", 14, prec)))
# Negative values rounding to zero keep their sign (C99).
for x in (-0.0004, -1e-300, -0.49):
    _fl.append(bracket(F("f", x, "", -1, 3)))
    _fl.append(bracket(F("f", x, "", -1, 0)))
# i64 arguments of float conversions (converted, ties to even).
for v in (0, 3, -5, INT64_MAX, INT64_MIN, (1 << 53) + 1, (1 << 53) + 3, 123456789):
    for conv, flags, width, prec in (("f", "", -1, -1), ("e", "+", 16, 3), ("g", "", -1, -1),
                                     ("f", "", -1, 0), ("G", "#", -1, 12)):
        _fl.append(bracket(I(conv, v, flags, width, prec)))
GROUPS["float"] = _fl

# ---- NaN, Inf, -Inf under float conversions ------------------------------
_nf = []
for b in (NAN, NEG_NAN, 0x7FF0000000000001, 0xFFFFFFFFFFFFFFFF, PINF, NINF):
    for conv in ("f", "F", "e", "E", "g", "G"):
        for flags, width, prec in (("", -1, -1), ("+", -1, -1), (" ", -1, -1), ("+", 8, 2),
                                   ("-", 8, -1), ("0", 8, -1), ("#", -1, -1), ("", -1, 10),
                                   ("+-", 8, -1), (" 0", 6, 3), ("", 2, -1), ("#0+", 300, 5)):
            _nf.append(bracket(F(conv, B(b), flags, width, prec)))
GROUPS["nonfinite"] = _nf

# ---- %s, text pieces, several conversions ---------------------------------
_st = []
for data in (b"hello", b"", b"a", "h\u00e9llo w\u00f6rld".encode(), b"tab\there"):
    for flags, width, prec in (("", -1, -1), ("", 10, -1), ("-", 10, -1), ("", -1, 3),
                               ("", 10, 3), ("-", 10, 3), ("", -1, 0), ("", -1, 100),
                               ("", 2, -1), ("", 5, 2), ("-", 300, -1), ("", 300, 4)):
        _st.append(bracket(S(data, flags, width, prec)))
# Several pieces in one format; '%' in a text piece is a plain byte (the
# compiler has already turned %% into %).
_st.append([b"a=", I("d", 12), b" b=", F("f", 2.5, "", 6, 2), b" c=", S(b"xyz", "-", 5),
            b"| 100% ", F("e", 0.001), b" ", F("d", 3.0), b"\n"])
_st.append([I("d", 1), I("d", 2), I("d", -3), b"\n"])
_st.append([b"only text, no conversion\n"])
_st.append([])                          # empty format: prints nothing
_st.append([b"%%d %s literally\n"])
_st.append([S(b""), b"\n"])
_st.append([S(b"x" * 600, "", -1, 520), b"\n"])
GROUPS["str"] = _st

# ---- very large precision and width --------------------------------------
_bg = []
for x, conv, flags, width, prec in (
        (DBL_TRUE_MIN, "f", "", -1, 1500),        # exact expansion: 1074 digits, then zeros
        (DBL_TRUE_MIN, "e", "", -1, 1200),
        (DBL_TRUE_MIN, "e", "", -1, 1100),
        (0.1, "e", "", -1, 1200),
        (0.1, "g", "", -1, 1200),                 # %g strips the zeros
        (0.1, "g", "#", -1, 1200),                # %#g keeps them
        (1e-5, "G", "#", -1, 1150),               # e style, zeros before the exponent
        (1.0 / 3.0, "e", "", -1, 1101),
        (1.0 / 3.0, "f", "+", -1, 1100),
        (-DBL_MAX, "f", "", -1, 1100),            # longest snprintf text (1411 bytes)
        (-DBL_MAX, "f", "", -1, 1101),
        (DBL_MAX, "f", "#", -1, 0),
        (2.5, "f", "", 1500, 3),
        (2.5, "f", "-", 1500, 3),
        (-2.5, "e", "0", 2000, 2),
        (-2.5, "e", "0", 2000, 1300),
        (123.0, "g", "0+", 700, 1200),
        (0.0, "g", "#", -1, 1105),
        (0.0, "f", "", -1, 1200),
        (1e300, "e", "", -1, 1105)):
    _bg.append(bracket(F(conv, x, flags, width, prec)))
_bg.append(bracket(F("d", 1e308, "", 2000, 1000)))
_bg.append(bracket(I("d", INT64_MIN, "", 1300, 1200)))
GROUPS["big"] = _bg

# ---- _sea_fmt_g (the %g spelling of _sea_err's f arguments) ---------------
GENTRY = [0.5, 100000.0, 1e6, 1.5e-5, 1e-4, 0.0, -0.0, 3.141592653589793, 123456789.0,
          -2.2250738585072014e-308, DBL_MAX, DBL_TRUE_MIN, 2.5e-5, 999999.5, B(NAN), B(NEG_NAN),
          B(PINF), B(NINF)]


def gentry_expected(x) -> bytes:
    b = x[1] if isinstance(x, tuple) else fbits(x)
    return fmt_float(b, "g", "", -1, -1).encode()


# ---------------------------------------------------------------------------
# Writers
# ---------------------------------------------------------------------------

HEADER = """\
// =====================================================================
// sea/tests/rt/arm64_macos/{name}.s -- runtime test of rt_fmt.s:
// {what}
// GENERATED by sea/tests/vectors/fmt.py (uv run python
// sea/tests/vectors/fmt.py); the expected bytes, {name}.out, are
// computed there from LANGUAGE.md 11.1 with exact arithmetic. Each call
// passes hand-built pre-parsed formats (SEA_FMT_*, SEA_FP_*) and
// argument slots (DESIGN.md 4.8); the site index is the case number k,
// and _sea_sites record k names line k+1 of "{name}.s" (a failed write
// of case k would be reported there). Run by tests/rt/run_rt.sh, linked
// with the arm64-macos runtime.
// =====================================================================
.include "limits.inc"
.include "rt.inc"
"""

FLAGBITS = {"-": "SEA_FF_LEFT", "+": "SEA_FF_PLUS", " ": "SEA_FF_SPACE", "0": "SEA_FF_ZERO", "#": "SEA_FF_ALT"}
CLSNAME = {"i": "SEA_CLS_I", "f": "SEA_CLS_F", "p": "SEA_CLS_P"}

WHAT = {
    "int": "%d/%i of i64 and bool: width, precision, flags - + space 0, INT64_MIN.",
    "dfloat": "%d/%i of f64 (MATLAB rule): integral values exact at any magnitude,\n// non-integral as %e precision 6, NaN/Inf padding.",
    "float": "%f %F %e %E %g %G of finite f64 and of i64: ties, %g style switch, %#g,\n// three-digit exponents, subnormals, -0.",
    "nonfinite": "NaN/Inf/-Inf under every float conversion with every flag.",
    "str": "%s precision/width in bytes, text pieces, several conversions, an empty format.",
    "big": "precisions beyond the snprintf clamp, widths beyond one fill block.",
}


def asm_bytes(data: bytes) -> list[str]:
    out = []
    for i in range(0, len(data), 16):
        out.append("    .byte " + ", ".join(str(c) for c in data[i:i + 16]))
    return out


def flag_expr(flags: str) -> str:
    names = [FLAGBITS[c] for c in "-+ 0#" if c in flags]
    return "(" + " | ".join(names) + ")" if names else "0"


def describe(pieces: list) -> str:
    s = ""
    for p in pieces:
        if isinstance(p, Conv):
            arg = p.value
            if p.cls == "f":
                arg = "bits 0x%016X (%r)" % (p.value, bits_f(p.value))
            elif p.cls == "p":
                arg = repr(p.value) if len(p.value) <= 20 else "%d bytes" % len(p.value)
            s += "{" + p.spelled() + " " + str(arg) + "}"
        else:
            s += p.decode("latin-1").replace("\n", "\\n").replace("\t", "\\t")
    return s


def sites_block(name: str, n: int) -> list[str]:
    """_sea_sites (SEA_SITE_* records): site k is line k+1 of NAME.s."""
    fname = (name + ".s").encode()
    out = ["", "// The error-site table: one record per case.", "    .globl _sea_sites", "    .p2align 3",
           "_sea_sites:"]
    for k in range(n):
        out.append("    .quad Ltf_sitefile, %d" % (k + 1))
    out += ["    .p2align 3", "Ltf_sitefile:", "    .quad SEA_RC_STATIC",
            "    .byte SEA_TAG_STR, 0, 0, 0, 0, 0, 0, 0", "    .quad %d" % len(fname)] + asm_bytes(fname)
    return out


def write_printf_test(group: str, cases: list[list]) -> None:
    name = "rt_fmt_" + group
    text = [HEADER.format(name=name, what=WHAT[group]), "    .section __TEXT,__text,regular,pure_instructions",
            "", "// _sea_main -- one _sea_printf call per case, in order.",
            "//   Frame: 16 bytes (frame record); callee-saved used: none",
            "    .globl _sea_main", "    .p2align 2", "_sea_main:",
            "    stp x29, x30, [sp, #-16]!", "    mov x29, sp"]
    data = ["", "    .section __DATA,__const"]
    expected = b""
    for k, pieces in enumerate(cases):
        text.append("    // case %d: %s" % (k, describe(pieces)[:200]))
        text += ["    adrp x0, Ltf_fmt_%d@PAGE" % k, "    add x0, x0, Ltf_fmt_%d@PAGEOFF" % k,
                 "    adrp x1, Ltf_slots_%d@PAGE" % k, "    add x1, x1, Ltf_slots_%d@PAGEOFF" % k,
                 "    mov x2, #%d" % k, "    bl _sea_printf"]
        convs = [p for p in pieces if isinstance(p, Conv)]
        data += ["    .p2align 3", "Ltf_fmt_%d:" % k,
                 "    .quad %d    // SEA_FMT_NPIECE" % len(pieces),
                 "    .quad %d    // SEA_FMT_NCONV" % len(convs)]
        extra = []
        for j, p in enumerate(pieces):
            if isinstance(p, Conv):
                data += ["    .byte SEA_FPK_CONV, '%s', %s, %s" % (p.conv, flag_expr(p.flags), CLSNAME[p.cls]),
                         "    .long %d, %d, 0" % (p.width, p.prec),
                         "    .quad 0, 0"]
                expected += p.expected()
            else:
                data += ["    .byte SEA_FPK_TEXT, 0, 0, 0", "    .long -1, -1, 0",
                         "    .quad Ltf_text_%d_%d, %d" % (k, j, len(p))]
                extra += ["Ltf_text_%d_%d:" % (k, j)] + asm_bytes(p)
                expected += p
        data += ["    .p2align 3", "Ltf_slots_%d:" % k]
        if not convs:
            data.append("    .quad 0    // one unused slot (8 * max(n, 1) bytes)")
        for j, p in enumerate(convs):
            if p.cls == "p":
                data.append("    .quad Ltf_str_%d_%d" % (k, j))
                extra += ["    .p2align 3", "Ltf_str_%d_%d:" % (k, j),
                          "    .quad SEA_RC_STATIC", "    .byte SEA_TAG_STR, 0, 0, 0, 0, 0, 0, 0",
                          "    .quad %d" % len(p.value)] + asm_bytes(p.value)
            elif p.cls == "i":
                data.append("    .quad %d" % p.value)
            else:
                data.append("    .quad 0x%016X" % p.value)
        data += extra
    data += sites_block(name, len(cases))
    text += ["    ldp x29, x30, [sp], #16", "    ret"]
    with open(os.path.join(OUTDIR, name + ".s"), "w") as fh:
        fh.write("\n".join(text + data) + "\n")
    with open(os.path.join(OUTDIR, name + ".out"), "wb") as fh:
        fh.write(expected)


def write_gentry_test() -> None:
    name = "rt_fmt_gentry"
    text = [HEADER.format(name=name, what="_sea_fmt_g (Sea's %g spelling for _sea_err's f arguments),\n// each value then a newline, written with _sea_out_bytes."),
            "    .section __TEXT,__text,regular,pure_instructions", "",
            "// _sea_main -- _sea_fmt_g into a 16-byte buffer per value, then out.",
            "//   Frame: 16 bytes (frame record) + 16 (buffer at [sp]) = 32 bytes",
            "//   Callee-saved used: none",
            "    .globl _sea_main", "    .p2align 2", "_sea_main:",
            "    stp x29, x30, [sp, #-16]!", "    mov x29, sp", "    sub sp, sp, #16"]
    data = ["", "    .section __DATA,__const", "    .p2align 3"]
    expected = b""
    for k, x in enumerate(GENTRY):
        b = x[1] if isinstance(x, tuple) else fbits(x)
        text += ["    // case %d: bits 0x%016X (%r)" % (k, b, bits_f(b)),
                 "    adrp x9, Ltg_val_%d@PAGE" % k, "    ldr d0, [x9, Ltg_val_%d@PAGEOFF]" % k,
                 "    mov x0, sp", "    bl _sea_fmt_g",
                 "    mov x1, x0", "    mov x0, sp", "    mov x2, #%d" % k, "    bl _sea_out_bytes",
                 "    adrp x0, Ltg_nl@PAGE", "    add x0, x0, Ltg_nl@PAGEOFF",
                 "    mov x1, #1", "    mov x2, #%d" % k, "    bl _sea_out_bytes"]
        data += ["Ltg_val_%d:" % k, "    .quad 0x%016X" % b]
        expected += gentry_expected(x) + b"\n"
    data += ["Ltg_nl:", "    .byte 10"]
    data += sites_block(name, len(GENTRY))
    text += ["    add sp, sp, #16", "    ldp x29, x30, [sp], #16", "    ret"]
    with open(os.path.join(OUTDIR, name + ".s"), "w") as fh:
        fh.write("\n".join(text + data) + "\n")
    with open(os.path.join(OUTDIR, name + ".out"), "wb") as fh:
        fh.write(expected)


# ---------------------------------------------------------------------------
# x86_64-linux writers (GNU as, AT&T syntax, SysV ABI; DESIGN.md 4.7.1): the same cases in the
# same order and the same expected bytes as the arm64 files above.
# ---------------------------------------------------------------------------

def header_x64(name: str, what: str) -> str:
    what = what.replace("\n// ", "\n# ").replace("_sea_", "sea_")
    return """\
# =====================================================================
# sea/tests/rt/x86_64_linux/{name}.s -- runtime test of rt_fmt.s:
# {what}
# GENERATED by sea/tests/vectors/fmt.py (uv run python
# sea/tests/vectors/fmt.py); the expected bytes, {name}.out, are
# computed there from LANGUAGE.md 11.1 with exact arithmetic. Each call
# passes hand-built pre-parsed formats (SEA_FMT_*, SEA_FP_*) and
# argument slots (DESIGN.md 4.8); the site index is the case number k,
# and sea_sites record k names line k+1 of "{name}.s" (a failed write
# of case k would be reported there). Run by tests/rt/run_rt_linux.sh, linked
# with the x86_64-linux runtime. The x86_64 port of
# tests/rt/arm64_macos/{name}.s (the same cases in the same order, the
# same expected bytes).
# =====================================================================
.include "limits.inc"
.include "rt.inc"
""".format(name=name, what=what)


def sites_block_x64(name: str, n: int) -> list[str]:
    fname = (name + ".s").encode()
    out = ["", "# The error-site table: one record per case.", "    .globl sea_sites", "    .p2align 3",
           "sea_sites:"]
    for k in range(n):
        out.append("    .quad .Ltf_sitefile, %d" % (k + 1))
    out += ["    .p2align 3", ".Ltf_sitefile:", "    .quad SEA_RC_STATIC",
            "    .byte SEA_TAG_STR, 0, 0, 0, 0, 0, 0, 0", "    .quad %d" % len(fname)] + asm_bytes(fname)
    return out


def write_printf_test_x64(group: str, cases: list[list]) -> bytes:
    name = "rt_fmt_" + group
    text = [header_x64(name, WHAT[group]), "    .text",
            "", "# sea_main -- one sea_printf call per case, in order.",
            "#   Frame: 16 bytes (%rbp); callee-saved used: none",
            "    .globl sea_main", "    .type sea_main, @function", "    .p2align 4", "sea_main:",
            "    pushq %rbp", "    movq %rsp, %rbp"]
    data = ["", '    .section .data.rel.ro,"aw",@progbits']
    expected = b""
    for k, pieces in enumerate(cases):
        text.append("    # case %d: %s" % (k, describe(pieces)[:200]))
        text += ["    leaq .Ltf_fmt_%d(%%rip), %%rdi" % k, "    leaq .Ltf_slots_%d(%%rip), %%rsi" % k,
                 "    movq $%d, %%rdx" % k, "    call sea_printf"]
        convs = [p for p in pieces if isinstance(p, Conv)]
        data += ["    .p2align 3", ".Ltf_fmt_%d:" % k,
                 "    .quad %d    # SEA_FMT_NPIECE" % len(pieces),
                 "    .quad %d    # SEA_FMT_NCONV" % len(convs)]
        extra = []
        for j, p in enumerate(pieces):
            if isinstance(p, Conv):
                data += ["    .byte SEA_FPK_CONV, '%s', %s, %s" % (p.conv, flag_expr(p.flags), CLSNAME[p.cls]),
                         "    .long %d, %d, 0" % (p.width, p.prec),
                         "    .quad 0, 0"]
                expected += p.expected()
            else:
                data += ["    .byte SEA_FPK_TEXT, 0, 0, 0", "    .long -1, -1, 0",
                         "    .quad .Ltf_text_%d_%d, %d" % (k, j, len(p))]
                extra += [".Ltf_text_%d_%d:" % (k, j)] + asm_bytes(p)
                expected += p
        data += ["    .p2align 3", ".Ltf_slots_%d:" % k]
        if not convs:
            data.append("    .quad 0    # one unused slot (8 * max(n, 1) bytes)")
        for j, p in enumerate(convs):
            if p.cls == "p":
                data.append("    .quad .Ltf_str_%d_%d" % (k, j))
                extra += ["    .p2align 3", ".Ltf_str_%d_%d:" % (k, j),
                          "    .quad SEA_RC_STATIC", "    .byte SEA_TAG_STR, 0, 0, 0, 0, 0, 0, 0",
                          "    .quad %d" % len(p.value)] + asm_bytes(p.value)
            elif p.cls == "i":
                data.append("    .quad %d" % p.value)
            else:
                data.append("    .quad 0x%016X" % p.value)
        data += extra
    data += sites_block_x64(name, len(cases))
    text += ["    popq %rbp", "    ret"]
    with open(os.path.join(OUTDIR_X64, name + ".s"), "w") as fh:
        fh.write("\n".join(text + data) + "\n")
    with open(os.path.join(OUTDIR_X64, name + ".out"), "wb") as fh:
        fh.write(expected)
    return expected


def write_gentry_test_x64() -> bytes:
    name = "rt_fmt_gentry"
    what = "_sea_fmt_g (Sea's %g spelling for _sea_err's f arguments),\n// each value then a newline, written with _sea_out_bytes."
    text = [header_x64(name, what), "    .text", "",
            "# sea_main -- sea_fmt_g into a 16-byte buffer per value, then out.",
            "#   Frame: 16 bytes (%rbp) + 16 (buffer at 0(%rsp)) = 32 bytes",
            "#   Callee-saved used: none",
            "    .globl sea_main", "    .type sea_main, @function", "    .p2align 4", "sea_main:",
            "    pushq %rbp", "    movq %rsp, %rbp", "    subq $16, %rsp"]
    data = ["", '    .section .data.rel.ro,"aw",@progbits', "    .p2align 3"]
    expected = b""
    for k, x in enumerate(GENTRY):
        b = x[1] if isinstance(x, tuple) else fbits(x)
        text += ["    # case %d: bits 0x%016X (%r)" % (k, b, bits_f(b)),
                 "    movsd .Ltg_val_%d(%%rip), %%xmm0" % k,
                 "    movq %rsp, %rdi", "    call sea_fmt_g",
                 "    movq %rax, %rsi", "    movq %rsp, %rdi", "    movq $%d, %%rdx" % k, "    call sea_out_bytes",
                 "    leaq .Ltg_nl(%rip), %rdi", "    movq $1, %rsi", "    movq $%d, %%rdx" % k,
                 "    call sea_out_bytes"]
        data += [".Ltg_val_%d:" % k, "    .quad 0x%016X" % b]
        expected += gentry_expected(x) + b"\n"
    data += [".Ltg_nl:", "    .byte 10"]
    data += sites_block_x64(name, len(GENTRY))
    text += ["    addq $16, %rsp", "    popq %rbp", "    ret"]
    with open(os.path.join(OUTDIR_X64, name + ".s"), "w") as fh:
        fh.write("\n".join(text + data) + "\n")
    with open(os.path.join(OUTDIR_X64, name + ".out"), "wb") as fh:
        fh.write(expected)
    return expected


def self_test() -> None:
    """Spot values written out by hand from LANGUAGE.md 11.1 and C99."""
    checks = [
        (F("f", 0.125, "", -1, 2), b"0.12"),
        (F("f", 2.5, "", -1, 0), b"2"),
        (F("f", B(PINF), "+", 8, 2), b"    +Inf"),
        (F("d", B(NAN), "0", 8), b"     NaN"),
        (F("d", 1.5), b"1.500000e+00"),
        (F("d", 1e20), b"100000000000000000000"),
        (F("g", 1e6), b"1e+06"),
        (F("g", 100000.0), b"100000"),
        (F("g", 1.0, "#"), b"1.00000"),
        (F("e", DBL_TRUE_MIN), b"4.940656e-324"),
        (I("d", INT64_MIN), b"-9223372036854775808"),
        (I("d", 0, "", -1, 0), b""),
        (F("e", B(NEG_NAN), "+"), b"NaN"),
        (F("e", B(PINF), " "), b" Inf"),
        (S(b"hello", "", 8, 3), b"     hel"),
    ]
    for c, want in checks:
        got = c.expected()
        if got != want:
            sys.exit("fmt.py: self-test failed for %s: %r, want %r" % (c.spelled(), got, want))


def main() -> None:
    self_test()
    os.makedirs(OUTDIR, exist_ok=True)
    os.makedirs(OUTDIR_X64, exist_ok=True)
    for group, cases in GROUPS.items():
        write_printf_test(group, cases)
        write_printf_test_x64(group, cases)
    write_gentry_test()
    write_gentry_test_x64()
    for f in sorted(os.listdir(OUTDIR)):
        if f.startswith("rt_fmt_") and f.endswith(".out"):
            with open(os.path.join(OUTDIR, f), "rb") as a, open(os.path.join(OUTDIR_X64, f), "rb") as b:
                if a.read() != b.read():
                    sys.exit("fmt.py: %s differs between the targets" % f)
    total = sum(len(c) for c in GROUPS.values()) + len(GENTRY)
    print("fmt.py: wrote %d groups + gentry, %d cases, into %s and %s"
          % (len(GROUPS), total, OUTDIR, OUTDIR_X64))


if __name__ == "__main__":
    main()
