"""Float-literal conversion vectors for passes/lib/fltlit.bas (DESIGN.md 2.8, 6.2).

Run from anywhere with `uv run python sea/tests/vectors/float.py`; writes float.txt next to
this file. Each line is `literal #BITS status` (fields separated by one space):

* literal - the literal text as written in Sea source (digits, `_`, `.`, exponent);
* #BITS   - `#` and the 16 upper-case hex digits of the binary64 pattern (DESIGN.md 3.1);
* status  - FLCVT's status: 0 ok, 1 `float literal out of range` (bits of +inf),
            2 `invalid numeric literal` (bits 0) (LANGUAGE.md 3.4).

The expected value is derived from the definition (LANGUAGE.md 3.4): the exact decimal value
as a Fraction, rounded to the nearest binary64, ties to even, with subnormals; a value that
rounds to infinity is out of range. Every finite result is cross-checked against Python's
float() (correctly rounded strtod) and struct; the generator stops if they disagree.
"""

import os
import random
import re
import struct
from fractions import Fraction

HERE = os.path.dirname(os.path.abspath(__file__))
INF_BITS = 0x7FF0000000000000
MAX_BITS = 0x7FEFFFFFFFFFFFFF


def round_f64(x):
    """Nearest binary64 to the non-negative Fraction x, ties to even: (bits, overflowed)."""
    assert x >= 0
    if x == 0:
        return 0, False
    n, d = x.numerator, x.denominator
    e = n.bit_length() - d.bit_length()  # 2^e <= x < 2^(e+2)
    if (n << max(0, -e)) < (d << max(0, e)):
        e -= 1
    assert Fraction(2) ** e <= x < Fraction(2) ** (e + 1)
    last = max(e - 52, -1074)  # weight of the last place
    scaled = x / Fraction(2) ** last
    m = scaled.numerator // scaled.denominator
    rest = scaled - m
    if rest > Fraction(1, 2) or (rest == Fraction(1, 2) and m % 2 == 1):
        m += 1
    bits = ((last + 1074) << 52) + m  # m = 2^53 carries into the exponent
    if bits >= INF_BITS:
        return INF_BITS, True
    return bits, False


LIT = re.compile(r'^[0-9][0-9_]*(\.[0-9][0-9_]*)?([eE][+-]?[0-9]+)?$')


def valid(lit):
    """float_lit of LANGUAGE.md 3.4, with the `_` rules."""
    if not LIT.match(lit):
        return False
    if '.' not in lit and 'e' not in lit and 'E' not in lit:
        return False  # an int_lit
    if lit.endswith('_') or '_.' in lit or '_e' in lit or '_E' in lit:
        return False
    return True


def exact(lit):
    s = lit.replace('_', '')
    m = re.match(r'^([0-9]+)(?:\.([0-9]+))?(?:[eE]([+-]?[0-9]+))?$', s)
    ip, fp, ex = m.group(1), m.group(2) or '', m.group(3) or '0'
    digits = int(ip + fp)
    e10 = int(ex) - len(fp)
    if digits == 0:
        return Fraction(0)
    nd = len(str(digits))
    # far outside the binary64 range: decided without building 10^huge
    if nd + e10 <= -400:
        return Fraction(0)
    if nd - 1 + e10 >= 400:
        return None
    return Fraction(digits) * Fraction(10) ** e10


def expect(lit):
    if not valid(lit):
        return 0, 2
    x = exact(lit)
    if x is None:
        return INF_BITS, 1
    bits, ovf = round_f64(x)
    if ovf:
        assert float(lit.replace('_', '')) == float('inf')
        return INF_BITS, 1
    # cross-check with the host's correctly rounded conversion
    host = struct.unpack('<Q', struct.pack('<d', float(lit.replace('_', ''))))[0]
    if host != bits:
        raise SystemExit('oracle disagrees with float() for %s: %016X vs %016X' % (lit[:60], bits, host))
    return bits, 0


def dec_exact(fr):
    """Exact decimal expansion 'I.F' of a Fraction with a power-of-two denominator."""
    n, d = fr.numerator, fr.denominator
    assert d & (d - 1) == 0
    k = d.bit_length() - 1
    scaled = n * 5 ** k  # value = scaled / 10^k
    s = str(scaled).rjust(k + 1, '0')
    ip, fp = s[:len(s) - k] if k else s, s[len(s) - k:] if k else ''
    return ip, fp.rstrip('0') or '0'


def bits_value(b):
    e = (b >> 52) & 0x7FF
    f = b & ((1 << 52) - 1)
    if e == 0:
        return Fraction(f) / Fraction(2) ** 1074
    return Fraction(f + (1 << 52)) * Fraction(2) ** (e - 1075)


def midpoint(b):
    """Exact value halfway between pattern b and b+1."""
    return (bits_value(b) + bits_value(b + 1)) / 2 if b + 1 < INF_BITS else \
        bits_value(b) + (Fraction(2) ** 1024 - bits_value(b)) / 2


def lit_of(fr, ndigits=None):
    """A literal for the exact value fr (power-of-two denominator), in d.ddde-N form."""
    ip, fp = dec_exact(fr)
    if ip.strip('0') == '':
        z = len(fp) - len(fp.lstrip('0'))
        mant = fp.lstrip('0')
        e10 = -(z + 1)
    else:
        ip = ip.lstrip('0')
        mant = (ip + (fp if fp != '0' else '')).rstrip('0') or '0'
        e10 = len(ip) - 1
    if ndigits is not None and len(mant) < ndigits:
        mant = mant + '0' * (ndigits - len(mant))
    if len(mant) == 1:
        return mant + '.0e' + str(e10)
    return mant[0] + '.' + mant[1:] + 'e' + str(e10)


def main():
    rnd = random.Random(19640501)
    lits = []
    # the hard cases named for this module
    lits += ['0.1', '1e23', '2.4703282292062327e-324', '2.4703282292062328e-324',
             '2.2250738585072011e-308', '2.2250738585072012e-308',
             '1.7976931348623157e308', '1.7976931348623158e308', '1.7976931348623159e308',
             '9007199254740993.0', '9007199254740995.0', '9007199254740993e0',
             '1_000.5', '4.9406564584124654e-324', '5e-324', '2.5e-324', '1e-324',
             '4.9e-324', '1.0', '0.0', '000.000e-5', '0e999999999999', '1e400', '1e-400',
             '1e99999999999999999', '1e-99999999999999999', '123456789012345678901234567890.0',
             '0.30000000000000004', '3.141592653589793', '2.718281828459045', '1e0', '1E+2',
             '1.5e-0', '1__0.5', '6.02214076e23', '1.0e308', '1e308', '1e309', '8.98846567431158e307',
             '2.2250738585072014e-308', '2.225073858507201e-308', '0.000001', '100000000000000000000000.0']
    # the first value that rounds to infinity (the midpoint of max and 2^1024) and its neighbours
    mid = midpoint(MAX_BITS)
    ip, fp = dec_exact(mid)
    assert fp == '0'
    lits += [ip + '.0', str(int(ip) - 1) + '.0', str(int(ip) + 1) + '.0',
             ip[:1] + '.' + ip[1:] + 'e308']
    # syntax: invalid literals (status 2)
    lits += ['1.', '1._5', '1_.5', '_1.0', '1.0_', '1e_5', '1e', '1e+', '1.5e3_', '123', '0x1.0',
             '1.5.5', '1.e5', '1e5.0', '1_e5', '1.5e+-3', '1ee5', '12a.0', '1.0f']
    # 4000-digit mantissas around a halfway point (subnormal and normal)
    for b in (0x0000000000000003, 0x000FEDCBA9876543, 0x0010000000000000, 0x3FF0000000000001):
        m = midpoint(b)
        base = lit_of(m)
        mant, e = base.split('e')
        digits = mant.replace('.', '')
        assert len(digits) < 3990, len(digits)
        tie = digits + '0' * (4000 - len(digits))
        up = tie[:-1] + '1'
        down = str(int(tie) - 1)
        for d in (tie, up, down):
            lits.append(d[0] + '.' + d[1:] + 'e' + e)
    # the longest mantissas a 4096-byte source line holds, scaled to the extremes of the range
    # (dividing by 10^4400 and so on), and a 4000-zero run between two nonzero digits
    for e10 in (-311, -4, 300, 308):
        d = '9' + ''.join(rnd.choice('0123456789') for _ in range(4088))
        lits.append(d[0] + '.' + d[1:] + 'e' + str(e10))
    d = '1' + '0' * 4000 + '1'
    lits += [d[0] + '.' + d[1:] + 'e-320', d[0] + '.' + d[1:] + 'e308', '0.' + '0' * 4000 + '1e3990']
    # digit separators around a tie
    lits.append('9_007_199_254_740_993.0')
    # random doubles: shortest repr, 17 digits, and exact halfway points
    for _ in range(300):
        kind = rnd.random()
        if kind < 0.1:
            b = rnd.randrange(1, 1 << 52)  # subnormal
        elif kind < 0.2:
            b = rnd.choice([rnd.randrange(0x7FE0000000000000, MAX_BITS + 1),
                            rnd.randrange(0x0010000000000000, 0x0020000000000000)])
        else:
            b = rnd.randrange(0x0010000000000000, MAX_BITS + 1)
        v = struct.unpack('<d', struct.pack('<Q', b))[0]
        lits.append(repr(v) if 'e' in repr(v) or '.' in repr(v) else repr(v) + '.0')
        lits.append('%.16e' % v)
        if b < MAX_BITS:
            lits.append(lit_of(midpoint(b)))
    # random decimal strings of every length up to 60 digits, all exponents
    for _ in range(400):
        nd = rnd.randrange(1, 61)
        digs = ''.join(rnd.choice('0123456789') for _ in range(nd))
        if digs[0] == '0' and rnd.random() < 0.7:
            digs = str(rnd.randrange(1, 10)) + digs[1:]
        pt = rnd.randrange(1, nd + 1)
        e10 = rnd.randrange(-345, 330)
        frac = digs[pt:] or '0'
        lit = digs[:pt] + '.' + frac
        if rnd.random() < 0.8:
            sign = '-' if e10 < 0 else rnd.choice(['', '+'])
            lit += rnd.choice('eE') + sign + str(abs(e10))
        if rnd.random() < 0.15:
            # a digit separator between two mantissa digits
            places = [i for i in range(1, lit.find('.')) if lit[i - 1].isdigit() and lit[i].isdigit()]
            if places:
                i = rnd.choice(places)
                lit = lit[:i] + '_' + lit[i:]
        lits.append(lit)
    seen = set()
    out = []
    for lit in lits:
        if lit in seen:
            continue
        seen.add(lit)
        bits, st = expect(lit)
        out.append('%s #%016X %d' % (lit, bits, st))
    with open(os.path.join(HERE, 'float.txt'), 'w') as f:
        f.write('\n'.join(out) + '\n')
    print('float.txt: %d vectors' % len(out))


if __name__ == '__main__':
    main()
