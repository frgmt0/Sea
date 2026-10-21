"""Phase-2 corpus: LIR edge semantics that both targets must give byte for byte.

Run with `uv run python sea/tests/vectors/edges_gen.py`; it (re)writes the programs/ and errors/
tests below. Every operand is a local (`let`), so nothing is folded at compile time (DESIGN.md
3.5.7 folds constant subtrees only) and every operation runs in the compiled code. Expected values
come from LANGUAGE.md 6 by exact integer arithmetic and the exact binary64 oracle
(float_oracle.py), formatted by the printf oracle (progfmt.py), never from either target.

Not covered, because phase 1/2 reports them as `not supported yet` (DESIGN.md 2.6.2 phase rule):
min, max, floor, ceil, round, trunc, abs, sqrt (library functions other than printf, now, f64,
i64, idiv) and f64 `%`. Sea has no shift operators (LANGUAGE.md 6, Appendix B).
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import progfmt  # noqa: E402
from float_oracle import i_to_f, literal_bits  # noqa: E402

TESTS = os.path.dirname(HERE)
MIN = -(1 << 63)
MAX = (1 << 63) - 1


def write(sub, name, src, **files):
    d = os.path.join(TESTS, sub)
    with open(os.path.join(d, name + '.sea'), 'w') as f:
        f.write(src)
    for ext, text in files.items():
        with open(os.path.join(d, name + '.' + ext), 'w') as f:
            f.write(text)


def fmod(a, b):
    """i64 % (LANGUAGE.md 6.6): a - b * floor(a / b), exact."""
    return a - b * (a // b)


def idiv(a, b):
    """idiv (LANGUAGE.md 6.6): floor(a / b), exact."""
    return a // b


def chk(v):
    assert MIN <= v <= MAX, v
    return v


# ------------------------------------------------------------------ floored % and idiv
pairs = [(7, 2), (-7, 2), (7, -2), (-7, -2), (6, 3), (-6, 3), (6, -3), (-6, -3), (1, 7), (-1, 7),
         (1, -7), (-1, -7), (MIN, 2), (MIN, -1), (MIN, 3), (MIN, -3), (MIN, MAX), (MIN, MIN),
         (MAX, -2), (MAX, MIN), (MAX, MAX), (0, MIN)]
src = ['// op_mod_idiv_edges -- floored % and idiv with every sign combination and the i64 extremes',
       '// (LANGUAGE.md 6.6); all operands are locals, so the compiled code computes them']
out = []
for k, (a, b) in enumerate(pairs):
    src.append('let a%d = %s' % (k, a if a != MIN else '-9223372036854775808'))
    src.append('let b%d = %s' % (k, b if b != MIN else '-9223372036854775808'))
    src.append('printf("%%d %%d\\n", a%d %% b%d, idiv(a%d, b%d))' % (k, k, k, k))
    if (a, b) == (MIN, -1):
        # idiv(-2^63, -1) overflows (an error test covers it); % is 0 and exact
        src[-1] = 'printf("%%d\\n", a%d %% b%d)' % (k, k)
        out.append('%d' % chk(fmod(a, b)))
    else:
        out.append('%d %d' % (chk(fmod(a, b)), chk(idiv(a, b))))
write('programs', 'op_mod_idiv_edges', '\n'.join(src) + '\n', out='\n'.join(out) + '\n')

# % by zero is checked before anything else: -2^63 % 0 is a division by zero, not an overflow.
write('errors', 'err_rt_mod_zero_min',
      '// err_rt_mod_zero_min -- -2^63 % 0 is a division by zero (LANGUAGE.md 6.6)\n'
      'let m = -9223372036854775808\nlet z = 0\nprintf("%d\\n", m % z)\n',
      err='err_rt_mod_zero_min.sea:4: error: integer division by zero\n', status='1\n')
write('errors', 'err_rt_idiv_zero_min',
      '// err_rt_idiv_zero_min -- idiv(-2^63, 0) is a division by zero, not an overflow '
      '(LANGUAGE.md 6.6)\nlet m = -9223372036854775808\nlet z = 0\nprintf("%d\\n", idiv(m, z))\n',
      err='err_rt_idiv_zero_min.sea:4: error: integer division by zero\n', status='1\n')

# ------------------------------------------------------------------ f64 -> i64 at the edges
# i64(x) of an integral finite x in range is x exactly (LANGUAGE.md 10.1): -2^63, 2^63 - 1024 (the
# largest f64 below 2^63), -0.0 -> 0, 2^53 + 2, -(2^62).
vals = [('-9223372036854775808.0', MIN), ('9223372036854774784.0', (1 << 63) - 1024), ('-0.0', 0),
        ('9007199254740994.0', (1 << 53) + 2), ('-4611686018427387904.0', -(1 << 62))]
src = ['// op_ftoi_edges -- i64() of f64 values at the edges of the i64 range, and of -0.0',
       '// (LANGUAGE.md 10.1, 4.2)']
for k, (lit, v) in enumerate(vals):
    src.append('let x%d = %s' % (k, lit))
    if lit.startswith('-'):
        assert literal_bits(lit[1:]) ^ (1 << 63) == i_to_f(v) or v == 0
    else:
        assert literal_bits(lit) == i_to_f(v)
src.append('printf("' + ' '.join(['%d'] * len(vals)) + '\\n", '
           + ', '.join('i64(x%d)' % k for k in range(len(vals))) + ')')
write('programs', 'op_ftoi_edges', '\n'.join(src) + '\n',
      out=' '.join(str(v) for _, v in vals) + '\n')

# -2^63 - 2048 (the f64 below -2^63) is out of range: the message prints the value with Sea's %g
# (LANGUAGE.md 9.2): -9.22337e+18.
below = literal_bits('9223372036854777856.0') ^ (1 << 63)
assert progfmt.format_all('%g', [('f', below)]) == b'-9.22337e+18'
write('errors', 'err_rt_conv_below',
      '// err_rt_conv_below -- i64() of the f64 just below -2^63 is out of range (LANGUAGE.md 9.2)\n'
      'let x = -9223372036854777856.0\nprintf("%d\\n", i64(x))\n',
      err='err_rt_conv_below.sea:3: error: conversion to i64: -9.22337e+18 is not an integer\n',
      status='1\n')

# ------------------------------------------------------------------ i64 -> f64 rounding
# f64(n) rounds to nearest, ties to even (LANGUAGE.md 4.2): 2^53+1 -> 2^53 (tie); 2^53+3 -> 2^53+4
# (tie, even significand); 2^63-512 -> 2^63 (tie); 2^63-513 -> 2^63-1024; 2^63-1 -> 2^63;
# -2^63 exact; -(2^53+1) -> -2^53.
ints = [(1 << 53) + 1, (1 << 53) + 3, (1 << 63) - 512, (1 << 63) - 513, MAX, MIN, -((1 << 53) + 1)]
src = ['// op_itof_round -- f64() of i64 values rounds to nearest, ties to even (LANGUAGE.md 4.2, 10.1)']
for k, v in enumerate(ints):
    src.append('let n%d = %s' % (k, v if v != MIN else '-9223372036854775808'))
fmt = ' '.join(['%.17g'] * len(ints)) + '\\n'
src.append('printf("%s", %s)' % (fmt, ', '.join('f64(n%d)' % k for k in range(len(ints)))))
out = progfmt.format_all(' '.join(['%.17g'] * len(ints)) + '\n', [('f', i_to_f(v)) for v in ints])
write('programs', 'op_itof_round', '\n'.join(src) + '\n', out=out.decode())

# ------------------------------------------------------------------ comparisons with NaN and +-0
# IEEE (LANGUAGE.md 6.5): every ordered comparison with NaN is false, != is true; -0.0 == 0.0.
ops = ['==', '!=', '<', '<=', '>', '>=']
nan_one = [0, 1, 0, 0, 0, 0]
zeros = [1, 0, 0, 1, 0, 1]
src = ['// op_cmp_nan_zero -- the six comparisons with NaN on either side and between -0.0 and 0.0',
       '// (LANGUAGE.md 6.5); every operand is a local',
       'let n = nan', 'let one = 1.0', 'let mz = -0.0', 'let z = 0.0']
for lhs, rhs, want in (('n', 'one', nan_one), ('one', 'n', nan_one), ('n', 'n', nan_one),
                       ('mz', 'z', zeros), ('z', 'mz', zeros)):
    src.append('printf("%s\\n", %s)' % (' '.join(['%d'] * 6),
                                        ', '.join('%s %s %s' % (lhs, op, rhs) for op in ops)))
out = '\n'.join(' '.join(map(str, w)) for w in (nan_one, nan_one, nan_one, zeros, zeros)) + '\n'
write('programs', 'op_cmp_nan_zero', '\n'.join(src) + '\n', out=out)

# ------------------------------------------------------------------ unary minus of zeros
# Unary - flips the sign bit exactly (LANGUAGE.md 6.5): -(0.0) = -0.0, -(-0.0) = +0.0; 0.0 - 0.0 is
# +0.0 and 0.0 * -1.0 is -0.0 (IEEE). %g prints -0 / 0, %f -0.000000 / 0.000000 (C99).
src = ['// op_neg_zero -- unary minus and IEEE signs of zero computed at run time (LANGUAGE.md 6.5)',
       'let z = 0.0', 'let mz = -0.0', 'let m1 = -1.0',
       'printf("%g %g %g %g\\n", -z, -mz, z - z, z * m1)',
       'printf("%f %f\\n", -z, -mz)']
write('programs', 'op_neg_zero', '\n'.join(src) + '\n',
      out='-0 0 0 -0\n-0.000000 0.000000\n')

print('edges_gen: written')
