"""Phase-3 corpus: Sea programs calling log exp sin cos pow hypot, and const pow tests.

Run with `timeout 120 uv run python sea/tests/vectors/math_progs.py`; it (re)writes
tests/programs/lib_math_*.{sea,out} and the phase-3 tests/errors/ cases below. Each expected
result is the bit pattern of the model tests/vectors/math_model.py (DESIGN.md 4.10.6: the oracle
for identity; FEPOW in constants has the same bits, DESIGN.md 4.10.5) for the argument bits that
LANGUAGE.md gives the source (float literals through float_oracle.py, i64 and untyped integer
arguments converted exactly, LANGUAGE.md 4.2), formatted with %.17g by the exact printf oracle
progfmt.py (LANGUAGE.md 11.1: NaN, Inf, -Inf spelled as MATLAB does).
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import math_model as mm  # noqa: E402
import progfmt  # noqa: E402
from float_oracle import i_to_f, literal_bits  # noqa: E402

TESTS = os.path.dirname(HERE)
SIGN = 1 << 63
PI = 0x400921FB54442D18     # Sea's pi (DESIGN.md 3.5.5)
INF = 0x7FF0000000000000
NAN = 0x7FF8000000000000


def arg(a):
    """The f64 bits of one source argument: a float literal text (optionally '-'), 'pi', 'inf',
    'nan', or an int (an i64 or untyped integer argument, converted per LANGUAGE.md 4.2)."""
    if isinstance(a, int):
        assert -(1 << 53) <= a <= (1 << 53)
        return i_to_f(a)
    neg = a.startswith('-')
    t = a[1:] if neg else a
    b = {'pi': PI, 'inf': INF, 'nan': NAN}.get(t)
    if b is None:
        b = literal_bits(t)
    return b ^ SIGN if neg else b


def src_arg(a):
    return str(a) if isinstance(a, int) else a


def g17(b):
    return progfmt.format_all('%.17g\n', [('f', b)]).decode()


def call(fn, args):
    return mm.eval_bits(fn, [arg(a) for a in args])


def prog(name, header, lines, out):
    with open(os.path.join(TESTS, 'programs', name + '.sea'), 'w') as f:
        f.write('// %s -- %s\n' % (name, header) + '\n'.join(lines) + '\n')
    with open(os.path.join(TESTS, 'programs', name + '.out'), 'w') as f:
        f.write(out)


def err(name, header, body, line, col, msg):
    d = os.path.join(TESTS, 'errors')
    with open(os.path.join(d, name + '.sea'), 'w') as f:
        f.write('// %s -- %s\n' % (name, header) + body)
    with open(os.path.join(d, name + '.err'), 'w') as f:
        f.write('%s.sea:%d:%d: error: %s\n' % (name, line, col, msg))
    with open(os.path.join(d, name + '.status'), 'w') as f:
        f.write('1\n')


def calls_program(fn, header, cases, lets=()):
    """cases: list of argument tuples; an argument may also name a local declared in lets
    (name, value), whose value is used for the expected bits."""
    env = dict(lets)
    lines = ['let %s = %s' % (n, src_arg(v)) for n, v in lets]
    out = ''
    for args in cases:
        lines.append('printf("%%.17g\\n", %s(%s))' % (fn, ', '.join(
            a if isinstance(a, str) and a in env else src_arg(a) for a in args)))
        vals = [env.get(a, a) if isinstance(a, str) else a for a in args]
        out += g17(call(fn, vals))
    prog('lib_math_' + fn, header, lines, out)


# log: exact log(1), log(2), log(10) by an i64 local, an untyped 1, the special values of C99
# Annex F (log(+-0) = -Inf, log(x < 0) = NaN, log(Inf) = Inf, log(NaN) = NaN), a subnormal.
calls_program('log', 'log of ordinary, i64, untyped and special arguments (LANGUAGE.md 10.4; '
              'DESIGN.md 4.10)',
              [('1.0',), ('2.0',), ('n',), (1,), ('0.5',), ('1e-300',), ('5e-324',), ('0.0',),
               ('-0.0',), ('-1.0',), ('inf',), ('-inf',), ('nan',), ('1.7976931348623157e308',)],
              lets=[('n', 10)])
# exp: exp(+-0) = 1, exp(1), exp(-1), the overflow and underflow ends, +-Inf, NaN, i64 argument.
calls_program('exp', 'exp of ordinary, i64 and special arguments, overflow and underflow '
              '(LANGUAGE.md 10.4; DESIGN.md 4.10)',
              [('0.0',), ('-0.0',), ('1.0',), ('-1.0',), ('k',), (2,), ('709.7',), ('710.0',),
               ('-745.0',), ('-746.0',), ('inf',), ('-inf',), ('nan',), ('1e-20',)],
              lets=[('k', 3)])
# sin and cos: zeros keep their sign in sin, pi, a huge argument (Payne-Hanek path), Inf -> NaN.
calls_program('sin', 'sin of ordinary, huge, i64 and special arguments (LANGUAGE.md 10.4; '
              'DESIGN.md 4.10)',
              [('0.0',), ('-0.0',), ('1.0',), ('pi',), ('-pi',), ('1e22',), ('1e300',), ('n',),
               ('1e-310',), ('inf',), ('-inf',), ('nan',)], lets=[('n', 7)])
calls_program('cos', 'cos of ordinary, huge, i64 and special arguments (LANGUAGE.md 10.4; '
              'DESIGN.md 4.10)',
              [('0.0',), ('-0.0',), ('1.0',), ('pi',), ('1e22',), ('1e300',), ('n',), (3,),
               ('inf',), ('-inf',), ('nan',)], lets=[('n', 7)])
# hypot: Pythagorean triples, i64 arguments, Inf beats NaN (Annex F), signed zeros, scaling ends.
calls_program('hypot', 'hypot of ordinary, i64, huge, tiny and special arguments (LANGUAGE.md '
              '10.4; DESIGN.md 4.10)',
              [('3.0', '4.0'), (5, 12), ('a', 'b'), ('-0.0', '0.0'), ('inf', 'nan'), ('nan', '-inf'),
               ('nan', '1.0'), ('1e308', '1e308'), ('5e-324', '5e-324'), ('1e-300', '1.0')],
              lets=[('a', 8), ('b', 15)])

# pow: calls and ^ with a non-integral (or |k| > 4) exponent, which is pow (LANGUAGE.md 6.5).
pow_cases = [('2.0', '0.5'), (2, 10), ('10.0', '22.0'), ('-2.0', '3.0'), ('-8.0', '0.3333333333333333'),
             ('0.0', '-1.0'), ('-0.0', '-1.0'), ('-0.0', '-2.0'), ('1.0', 'nan'), ('nan', '0.0'),
             ('-1.0', 'inf'), ('0.5', 'inf'), ('2.0', '-inf'), ('-inf', '3.0'), ('-inf', '-3.0'),
             ('inf', '0.5'), ('1e300', '2.5'), ('2.0', '-1074.0')]
lines = ['let x = 2.0', 'let n = 3']
out = ''
for a, b in pow_cases:
    lines.append('printf("%%.17g\\n", pow(%s, %s))' % (src_arg(a), src_arg(b)))
    out += g17(call('pow', (a, b)))
# x ^ 0.5, x ^ 5 (|k| > 4: pow), n ^ 2.5 (i64 base converted), 2 ^ 0.5 (untyped base), x ^ -0.5,
# x ^ i64(2.0) (an exponent containing a call is never a powk, LANGUAGE.md 6.5: pow(2, 2))
for expr, (a, b) in (('x ^ 0.5', ('2.0', '0.5')), ('x ^ 5', ('2.0', 5)), ('n ^ 2.5', (3, '2.5')),
                     ('2 ^ 0.5', (2, '0.5')), ('x ^ -0.5', ('2.0', '-0.5')),
                     ('x ^ i64(2.0)', ('2.0', '2.0'))):
    lines.append('printf("%%.17g\\n", %s)' % expr)
    out += g17(call('pow', (a, b)))
prog('lib_math_pow', 'pow calls and ^ with a non-powk exponent, special values of C99 Annex F, i64 '
     'and untyped operands (LANGUAGE.md 6.5, 10.4)', lines, out)

# ------------------------------------------------------------------ pow in constants
# DESIGN.md 4.10.5: a const ^ that is not a powk and a const pow call are evaluated with FEPOW,
# the bits of the model; a powk ^ in a const is the pinned multiplication (LANGUAGE.md 6.5):
# 3.0 ^ 2 = 9.0 exactly. Each constant is printed next to the same operation at run time.
c1 = call('pow', ('2.0', '0.5'))
c2 = call('pow', (10, -2))
c3 = call('pow', ('2.0', ('1.5')))
sq = mm.bits(mm.f64(arg('3.0')) * mm.f64(arg('3.0')))
assert sq == arg('9.0')
lines = ['const C = 2.0 ^ 0.5', 'const P = pow(10, -2)', 'const Q = 2 ^ (3.0 / 2.0)',
         'const K = 3.0 ^ 2', 'let x = 2.0',
         'printf("%.17g %.17g\\n", C, x ^ 0.5)', 'printf("%.17g\\n", P)', 'printf("%.17g\\n", Q)',
         'printf("%.17g\\n", K)']
out = g17(c1)[:-1] + ' ' + g17(c1) + g17(c2) + g17(c3) + g17(sq)
prog('lib_math_const', 'pow in constants is evaluated at compile time with the run time\'s bits '
     '(LANGUAGE.md 7.2; DESIGN.md 4.10.5)', lines, out)

# ------------------------------------------------------------------ errors
err('err_const_log', 'log is not a constant expression (LANGUAGE.md 7.2; DESIGN.md 4.10.5)',
    'const L = log(2.0)\nprintf("%g\\n", L)\n', 2, 11, 'not a constant expression')
# A non-constant call inside a larger constant expression: reported at the expression itself,
# the whole initialiser (DESIGN.md 2.6.2 expr row), column 11.
err('err_const_sin', 'sin inside a constant expression is not constant: at the whole initialiser '
    '(LANGUAGE.md 7.2; DESIGN.md 2.6.2 expr)', 'const S = 2.0 * sin(1.0)\nprintf("%g\\n", S)\n',
    2, 11, 'not a constant expression')
err('err_no_overload_hypot', 'hypot takes two arguments: no overload for one (LANGUAGE.md 10.4)',
    'let h = hypot(1.0)\n', 2, 9, "no overload of 'hypot' accepts (f64)")
# sqrt is still outside the phase-3 library (DESIGN.md 2.6.2 phase rule: only printf now f64 i64
# idiv and the six of 4.10.5), also inside a const.
err('err_const_sqrt', 'sqrt in a constant: phase 3 still reports it under the phase rule '
    '(DESIGN.md 2.6.2)', 'const S = sqrt(2.0)\nprintf("%g\\n", S)\n', 2, 11,
    'not supported yet: sqrt')

print('math_progs: written')

# ------------------------------------------------------------------ powk versus pow (DESIGN.md 4.10.6)
# x ^ k with a constant integral |k| <= 4 is the pinned multiplications (LANGUAGE.md 6.5), each
# product rounded (float_oracle f_mul / f_div); an exponent that contains a call (f64(3)) is never
# integral, so it is pow, the model's result (<= 1 ulp). The x values were chosen with
# the model so that the two differ in the last bit; the assert keeps the test discriminating.
from float_oracle import f_div, f_mul  # noqa: E402

ONE = arg('1.0')


def powk_bits(xb, k):
    if k == 0:
        return ONE
    a = abs(k)
    if a == 1:
        t = xb
    elif a == 2:
        t = f_mul(xb, xb)
    elif a == 3:
        t = f_mul(f_mul(xb, xb), xb)
    else:
        s = f_mul(xb, xb)
        t = f_mul(s, s)
    return f_div(ONE, t) if k < 0 else t


lines = ['let x = 1.3', 'let y = 1.2', 'let z = 2.3']
out = ''
for v, k, ktext in (('x', 3, '3'), ('z', 3, '3'), ('y', -2, '-2')):
    xb = arg({'x': '1.3', 'y': '1.2', 'z': '2.3'}[v])
    pk = powk_bits(xb, k)
    pw = mm.eval_bits('pow', [xb, i_to_f(k)])
    assert pk != pw, (v, k)
    lines.append('printf("%%.17g %%.17g %%.17g\\n", %s ^ %s, %s ^ f64(%s), pow(%s, %s.0))'
                 % (v, ktext, v, ktext, v, ktext))
    out += g17(pk)[:-1] + ' ' + g17(pw)[:-1] + ' ' + g17(pw)
prog('lib_math_powk_vs_pow', 'x ^ k (powk, pinned multiplications) next to x ^ f64(k) and pow(x, k) '
     '(an exponent with a call is pow) for x where the bits differ (LANGUAGE.md 6.5; DESIGN.md '
     '4.10.6)', lines, out)

# A const defined with pow counts by its value: K = pow(9.0, 0.5) = 3.0 (FEPOW = the model) makes
# x ^ K the powk 3; N = -pow(4.0, 0.5) = -2.0 makes y ^ N the powk -2 (DESIGN.md 3.5.5 "Constant
# exponents", Decision 8 of phase 3: judged on the exponent as written, K contains no call). k = 2
# cannot discriminate (one rounding of x*x is the correctly rounded square), hence 3 and -2.
kb = mm.eval_bits('pow', [arg('9.0'), arg('0.5')])
nb = mm.eval_bits('pow', [arg('4.0'), arg('0.5')]) ^ SIGN
assert kb == arg('3.0') and nb == arg('-2.0')
xb, yb = arg('1.3'), arg('1.2')
lines = ['const K = pow(9.0, 0.5)', 'const N = -pow(4.0, 0.5)', 'let x = 1.3', 'let y = 1.2',
         'printf("%.17g %.17g\\n", x ^ K, pow(x, K))', 'printf("%.17g %.17g\\n", y ^ N, pow(y, N))']
out = (g17(powk_bits(xb, 3))[:-1] + ' ' + g17(mm.eval_bits('pow', [xb, kb]))
       + g17(powk_bits(yb, -2))[:-1] + ' ' + g17(mm.eval_bits('pow', [yb, nb])))
assert powk_bits(xb, 3) != mm.eval_bits('pow', [xb, kb])
assert powk_bits(yb, -2) != mm.eval_bits('pow', [yb, nb])
prog('lib_math_const_powk', 'a const defined with pow whose value is an integer makes x ^ K a powk '
     '(LANGUAGE.md 6.5; DESIGN.md 3.5.5)', lines, out)

# ------------------------------------------------------------------ dump goldens (tests/passes/)


def hexb(b):
    return '#%016X' % b


def passes_file(name, ext, records):
    with open(os.path.join(TESTS, 'passes', name + '.' + ext), 'w') as f:
        f.write('#sea 1\n#target arm64-macos\n#file %s.sea\n' % name + '\n'.join(records)
                + '\n#end\n')


# math_lower: canonical lowering, DESIGN.md 3.6.6 rule 14 (rcall sea_<fn> - 1 d n args, no site),
# rule 2 (the rcall writes the bound local's register), rule 1 (cf -> lf, cvt -> itof), rule 10
# (f64() of an i64 is itof); registers numbered by first appearance (3.6.1). Pass 2b folds none of
# these (3.5.7).
with open(os.path.join(TESTS, 'passes', 'math_lower.sea'), 'w') as f:
    f.write('// math_lower -- log exp sin cos pow hypot and a ^ that is not a powk lower to rcall\n'
            '// sea_<fn> - 1 d n args with no site (DESIGN.md 3.6.6 rules 1, 2, 10, 14)\n'
            'let x = 0.5\nlet y = 2.0\nlet n = 3\nlet a = log(x)\nlet b = exp(x)\n'
            'let c = sin(n)\nlet d = cos(x)\nlet e = pow(x, y)\nlet h = hypot(x, 4.0)\n'
            'let p = x ^ 0.5\nlet q = x ^ y\nlet r = log(2.0) + exp(y)\nlet s = n ^ f64(3)\n')
H = hexb
passes_file('math_lower', 'lir1', [
    'func .main main 0:1:1 0 0',
    'lf f1 ' + H(arg('0.5')), 'lf f2 ' + H(arg('2.0')), 'li i3 3',
    'rcall sea_log - 1 f4 1 f1', 'rcall sea_exp - 1 f5 1 f1',
    'itof f6 i3', 'rcall sea_sin - 1 f7 1 f6', 'rcall sea_cos - 1 f8 1 f1',
    'rcall sea_pow - 1 f9 2 f1 f2',
    'lf f10 ' + H(arg('4.0')), 'rcall sea_hypot - 1 f11 2 f1 f10',
    'lf f12 ' + H(arg('0.5')), 'rcall sea_pow - 1 f13 2 f1 f12',
    'rcall sea_pow - 1 f14 2 f1 f2',
    'lf f15 ' + H(arg('2.0')), 'rcall sea_log - 1 f16 1 f15', 'rcall sea_exp - 1 f17 1 f2',
    'fadd f18 f16 f17',
    'itof f19 i3', 'li i20 3', 'itof f21 i20', 'rcall sea_pow - 1 f22 2 f19 f21',
    'ret 0', 'endfunc'])

# const_pow: each const's leaf in sea.hir1 is its value (3.5.2), at the position of the root of
# its expression (a bin at its left operand, a lib call at its name); ^ non-powk and pow by FEPOW =
# the model's bits (4.10.5), NaN included (#7FF8000000000000); 3.0 ^ 2 is the powk 9.0; x ^ K with
# K = pow(9.0, 0.5) is powk 3 (3.5.5), x ^ C stays bin pow with its cref.
with open(os.path.join(TESTS, 'passes', 'const_pow.sea'), 'w') as f:
    f.write('// const_pow -- consts using pow and a non-powk ^ are folded to the model\'s bits (FEPOW);\n'
            '// a pow-defined const of integral value makes x ^ K a powk (DESIGN.md 3.5.2, 3.5.5, 4.10.5)\n'
            'const C = 2.0 ^ 0.5\nconst P = pow(10, -2)\nconst Q = 2 ^ (3.0 / 2.0)\n'
            'const K = pow(9.0, 0.5)\nconst Z = pow(-8.0, 0.5)\nconst W = 3.0 ^ 2\n'
            'let x = 1.3\nlet a = C\nlet b = P + Q\nlet e = x ^ K\nlet f = x ^ C\nlet z = Z\n'
            'let w = W\n')
cz = mm.eval_bits('pow', [arg('-8.0'), arg('0.5')])
assert cz == NAN
cq = mm.eval_bits('pow', [i_to_f(2), f_div(arg('3.0'), arg('2.0'))])
passes_file('const_pow', 'hir1', [
    'cf 0:3:11 4 ' + H(call('pow', ('2.0', '0.5'))), 'cn 1 C 4 0:3:1',
    'cf 0:4:11 4 ' + H(call('pow', (10, -2))), 'cn 2 P 4 0:4:1',
    'cf 0:5:11 4 ' + H(cq), 'cn 3 Q 4 0:5:1',
    'cf 0:6:11 4 ' + H(kb), 'cn 4 K 4 0:6:1',
    'cf 0:7:11 4 ' + H(cz), 'cn 5 Z 4 0:7:1',
    'cf 0:8:11 4 ' + H(powk_bits(arg('3.0'), 2)), 'cn 6 W 4 0:8:1',
    'fn 1 .main main 1 0 7 0:1:1',
    'loc x 4 let 0:9:5', 'loc a 4 let 0:10:5', 'loc b 4 let 0:11:5', 'loc e 4 let 0:12:5',
    'loc f 4 let 0:13:5', 'loc z 4 let 0:14:5', 'loc w 4 let 0:15:5',
    'cf 0:9:9 4 ' + H(arg('1.3')), 'bind 0:9:1 1',
    'cref 0:10:9 4 1', 'bind 0:10:1 2',
    'cref 0:11:9 4 2', 'cref 0:11:13 4 3', 'bin 0:11:9 4 add', 'bind 0:11:1 3',
    'lv 0:12:9 4 1', 'powk 0:12:9 4 3', 'bind 0:12:1 4',
    'lv 0:13:9 4 1', 'cref 0:13:13 4 1', 'bin 0:13:9 4 pow', 'bind 0:13:1 5',
    'cref 0:14:9 4 5', 'bind 0:14:1 6',
    'cref 0:15:9 4 6', 'bind 0:15:1 7',
    'block 0:1:1 7', 'end'])


# Stage inputs (tests/stage.sh runs each pass on the previous pass's golden): const_pow.ast for
# pass 2a and math_lower.hir for pass 3a, derived by hand like every other golden: the AST by the
# record rules of DESIGN.md 3.4 (post-order; a bin at its left operand, a call at its callee name,
# neg before its operand's column), the HIR by 3.5 (2a's records; pass 2b changes nothing here:
# no cref, nothing it folds, 3.5.7).
F = lambda t: H(arg(t))  # noqa: E731
passes_file('const_pow', 'ast', [
    'float 0:3:11 ' + F('2.0'), 'float 0:3:17 ' + F('0.5'), 'bin 0:3:11 pow', 'const 0:3:1 C 0',
    'name 0:4:11 pow', 'int 0:4:15 10', 'int 0:4:20 2', 'neg 0:4:19', 'call 0:4:11 2',
    'const 0:4:1 P 0',
    'int 0:5:11 2', 'float 0:5:16 ' + F('3.0'), 'float 0:5:22 ' + F('2.0'), 'bin 0:5:16 div',
    'bin 0:5:11 pow', 'const 0:5:1 Q 0',
    'name 0:6:11 pow', 'float 0:6:15 ' + F('9.0'), 'float 0:6:20 ' + F('0.5'), 'call 0:6:11 2',
    'const 0:6:1 K 0',
    'name 0:7:11 pow', 'float 0:7:16 ' + F('8.0'), 'neg 0:7:15', 'float 0:7:21 ' + F('0.5'),
    'call 0:7:11 2', 'const 0:7:1 Z 0',
    'float 0:8:11 ' + F('3.0'), 'int 0:8:17 2', 'bin 0:8:11 pow', 'const 0:8:1 W 0',
    'pname 0:9:5 x', 'float 0:9:9 ' + F('1.3'), 'let 0:9:1 0',
    'pname 0:10:5 a', 'name 0:10:9 C', 'let 0:10:1 0',
    'pname 0:11:5 b', 'name 0:11:9 P', 'name 0:11:13 Q', 'bin 0:11:9 add', 'let 0:11:1 0',
    'pname 0:12:5 e', 'name 0:12:9 x', 'name 0:12:13 K', 'bin 0:12:9 pow', 'let 0:12:1 0',
    'pname 0:13:5 f', 'name 0:13:9 x', 'name 0:13:13 C', 'bin 0:13:9 pow', 'let 0:13:1 0',
    'pname 0:14:5 z', 'name 0:14:9 Z', 'let 0:14:1 0',
    'pname 0:15:5 w', 'name 0:15:9 W', 'let 0:15:1 0',
    'prog 13'])
locs = [('x', 4), ('y', 4), ('n', 3), ('a', 4), ('b', 4), ('c', 4), ('d', 4), ('e', 4), ('h', 4),
        ('p', 4), ('q', 4), ('r', 4), ('s', 4)]
passes_file('math_lower', 'hir', [
    'fn 1 .main main 1 0 13 0:1:1'] + ['loc %s %d let 0:%d:5' % (v, t, i + 3)
                                       for i, (v, t) in enumerate(locs)] + [
    'cf 0:3:9 4 ' + F('0.5'), 'bind 0:3:1 1',
    'cf 0:4:9 4 ' + F('2.0'), 'bind 0:4:1 2',
    'ci 0:5:9 3 3', 'bind 0:5:1 3',
    'lv 0:6:13 4 1', 'lib 0:6:9 4 log 1', 'bind 0:6:1 4',
    'lv 0:7:13 4 1', 'lib 0:7:9 4 exp 1', 'bind 0:7:1 5',
    'lv 0:8:13 3 3', 'cvt 0:8:13 4', 'lib 0:8:9 4 sin 1', 'bind 0:8:1 6',
    'lv 0:9:13 4 1', 'lib 0:9:9 4 cos 1', 'bind 0:9:1 7',
    'lv 0:10:13 4 1', 'lv 0:10:16 4 2', 'lib 0:10:9 4 pow 2', 'bind 0:10:1 8',
    'lv 0:11:15 4 1', 'cf 0:11:18 4 ' + F('4.0'), 'lib 0:11:9 4 hypot 2', 'bind 0:11:1 9',
    'lv 0:12:9 4 1', 'cf 0:12:13 4 ' + F('0.5'), 'bin 0:12:9 4 pow', 'bind 0:12:1 10',
    'lv 0:13:9 4 1', 'lv 0:13:13 4 2', 'bin 0:13:9 4 pow', 'bind 0:13:1 11',
    'cf 0:14:13 4 ' + F('2.0'), 'lib 0:14:9 4 log 1', 'lv 0:14:24 4 2', 'lib 0:14:20 4 exp 1',
    'bin 0:14:9 4 add', 'bind 0:14:1 12',
    'lv 0:15:9 3 3', 'cvt 0:15:9 4', 'ci 0:15:17 3 3', 'lib 0:15:13 4 f64 1',
    'bin 0:15:9 4 pow', 'bind 0:15:1 13',
    'block 0:1:1 13', 'end'])
# math_lower.hir1 equals its .hir (pass 2b has nothing to substitute or fold, 3.5.7), and
# math_lower.ast completes the chain for stage.sh (3.4: a call's callee name, its arguments, then
# `call` at the name; `f64(3)` is a `conv` after its argument).
with open(os.path.join(TESTS, 'passes', 'math_lower.hir')) as f:
    hir = f.read()
with open(os.path.join(TESTS, 'passes', 'math_lower.hir1'), 'w') as f:
    f.write(hir)
ast = []
for i, (v, lit) in enumerate((('x', 'float ' + F('0.5')), ('y', 'float ' + F('2.0')), ('n', 'int'))):
    ln = i + 3
    ast += ['pname 0:%d:5 %s' % (ln, v),
            ('int 0:%d:9 3' % ln) if lit == 'int' else '%s' % lit.replace('float ', 'float 0:%d:9 ' % ln),
            'let 0:%d:1 0' % ln]
for ln, v, fn, a in ((6, 'a', 'log', 'x'), (7, 'b', 'exp', 'x'), (8, 'c', 'sin', 'n'),
                     (9, 'd', 'cos', 'x')):
    ast += ['pname 0:%d:5 %s' % (ln, v), 'name 0:%d:9 %s' % (ln, fn), 'name 0:%d:13 %s' % (ln, a),
            'call 0:%d:9 1' % ln, 'let 0:%d:1 0' % ln]
ast += ['pname 0:10:5 e', 'name 0:10:9 pow', 'name 0:10:13 x', 'name 0:10:16 y', 'call 0:10:9 2',
        'let 0:10:1 0',
        'pname 0:11:5 h', 'name 0:11:9 hypot', 'name 0:11:15 x', 'float 0:11:18 ' + F('4.0'),
        'call 0:11:9 2', 'let 0:11:1 0',
        'pname 0:12:5 p', 'name 0:12:9 x', 'float 0:12:13 ' + F('0.5'), 'bin 0:12:9 pow',
        'let 0:12:1 0',
        'pname 0:13:5 q', 'name 0:13:9 x', 'name 0:13:13 y', 'bin 0:13:9 pow', 'let 0:13:1 0',
        'pname 0:14:5 r', 'name 0:14:9 log', 'float 0:14:13 ' + F('2.0'), 'call 0:14:9 1',
        'name 0:14:20 exp', 'name 0:14:24 y', 'call 0:14:20 1', 'bin 0:14:9 add', 'let 0:14:1 0',
        'pname 0:15:5 s', 'name 0:15:9 n', 'int 0:15:17 3', 'conv 0:15:13 f64', 'bin 0:15:9 pow',
        'let 0:15:1 0', 'prog 13']
passes_file('math_lower', 'ast', ast)
print('math_progs: powk/pow, dump goldens and stage inputs written')
