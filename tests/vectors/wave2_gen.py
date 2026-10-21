"""Phase-1 wave-2 corpus: the programs and error tests for the review fixes (U1, L1, seacheck).

Run with `uv run python sea/tests/vectors/wave2_gen.py`; it (re)writes the files listed in
TESTS below into tests/programs/ and tests/errors/. Every expected output is derived here from
LANGUAGE.md / DESIGN.md by hand or by exact arithmetic (the reasoning is in the comments next to
each test), never from what an implementation prints. Folded f64 values are checked with the
exact IEEE oracle of f64emu.py and float_oracle.py.
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from f64emu import f_add, f_div, f_mul, f_neg, f_sub  # noqa: E402
from float_oracle import literal_bits as L  # noqa: E402

TESTS = os.path.dirname(HERE)
INF = 0x7FF0000000000000
NAN = 0x7FF8000000000000


def cls_name(b):
    """How LANGUAGE.md 11.1 prints a non-finite f64 with %f (no flags)."""
    if (b >> 52) & 0x7FF == 0x7FF:
        if b & ((1 << 52) - 1):
            return 'NaN'
        return '-Inf' if b >> 63 else 'Inf'
    raise ValueError('finite')


def prog(name, header, body, out):
    src = '// %s -- %s\n%s' % (name, header, body)
    with open(os.path.join(TESTS, 'programs', name + '.sea'), 'w') as f:
        f.write(src)
    with open(os.path.join(TESTS, 'programs', name + '.out'), 'w') as f:
        f.write(out)


def err(name, header, body, line, col, msg, meta=None):
    """A compile-time error (col given) or a run-time error (col None; line None: no site)."""
    src = '// %s -- %s\n%s' % (name, header, body)
    if col is not None:
        text = '%s.sea:%d:%d: error: %s\n' % (name, line, col, msg)
    elif line is not None:
        text = '%s.sea:%d: error: %s\n' % (name, line, msg)
    else:
        text = 'error: %s\n' % msg
    d = os.path.join(TESTS, 'errors')
    with open(os.path.join(d, name + '.sea'), 'w') as f:
        f.write(src)
    with open(os.path.join(d, name + '.err'), 'w') as f:
        f.write(text)
    with open(os.path.join(d, name + '.status'), 'w') as f:
        f.write('1\n')
    if meta:
        with open(os.path.join(d, name + '.meta'), 'w') as f:
            f.write(meta)


def col_of(body_line, marker, occ=1):
    i = -1
    for _ in range(occ):
        i = body_line.index(marker, i + 1)
    return len(body_line[:i].encode()) + 1


# ------------------------------------------------------------------ U1: folding never guarded

# 16 constants, each the square of the previous: substituted without folding the tree of C16
# would hold 2^15 leaves; with U1 every constant folds to one literal (DESIGN.md 2.8, 3.5.7).
# 1e300^2 already overflows, so C2 .. C16 are +Inf; -C16 is -Inf (LANGUAGE.md 6.5, 11.1).
v = L('1e300')
lines = ['const C1 = 1e300']
for k in range(2, 17):
    lines.append('const C%d = C%d * C%d' % (k, k - 1, k - 1))
    v = f_mul(v, v)
lines.append('printf("%f %f\\n", C16, -C16)')
prog('fold_inf_chain', 'a 16-constant chain of squares overflows to Inf and folds (DESIGN.md 2.8 U1)',
     '\n'.join(lines) + '\n', '%s %s\n' % (cls_name(v), cls_name(f_neg(v))))

# A1 = 1.5, A(k) = A(k-1) + A(k-1): A13 = 1.5 * 2^12 = 6144 exactly (every sum exact); its
# unfolded tree has 2^12 leaves, and it is used 7 times: 7 * 6144 = 43008, %g prints 43008.
v = L('1.5')
lines = ['const A1 = 1.5']
for k in range(2, 14):
    lines.append('const A%d = A%d + A%d' % (k, k - 1, k - 1))
    v = f_add(v, v)
assert v == L('6144.0')
s = v
for _ in range(6):
    s = f_add(s, v)
assert s == L('43008.0')
lines.append('printf("%g\\n", A13 + A13 + A13 + A13 + A13 + A13 + A13)')
prog('fold_a13_chain', 'a chain of 13 doubling constants used 7 times folds to literals (DESIGN.md 2.8)',
     '\n'.join(lines) + '\n', '43008\n')

# Folded non-finite and subnormal values, printed (LANGUAGE.md 11.1 spelling; %g C99):
#   1e308 * 10.0 -> +Inf (overflow), -1.0 / 0.0 -> -Inf, 1e200 ^ 2 (powk 2, folded) -> +Inf
#   inf - inf, 0.0 * inf -> default NaN; -nan, nan + 1.0 -> NaN: all print NaN, never signed
#   -0.0 * 1.0 -> -0.0 (%g "-0"); 1e-320 * 1e-10 -> +0 (underflow, %g "0");
#   5e-324 * 1.5 -> 1.5 ulp of the least subnormal, a tie, to even: 2^-1073 = 9.88131...e-324
r1 = [f_mul(L('1e308'), L('10.0')), f_div(f_neg(L('1.0')), L('0.0')), f_mul(L('1e200'), L('1e200'))]
r2 = [f_sub(INF, INF), f_mul(L('0.0'), INF), f_neg(NAN), f_add(NAN, L('1.0'))]
assert f_mul(f_neg(L('0.0')), L('1.0')) == 1 << 63
assert f_mul(L('1e-320'), L('1e-10')) == 0
assert f_mul(L('5e-324'), L('1.5')) == 2
prog('fold_nonfinite', 'folded overflow, x / 0, inf and nan operands, -0 and subnormals print as at '
     'run time (DESIGN.md 2.8 U1; LANGUAGE.md 11.1)',
     'printf("%f %f %f\\n", 1e308 * 10.0, -1.0 / 0.0, 1e200 ^ 2)\n'
     'printf("%f %f %f %f\\n", inf - inf, 0.0 * inf, -nan, nan + 1.0)\n'
     'printf("%g %g %g\\n", -0.0 * 1.0, 1e-320 * 1e-10, 5e-324 * 1.5)\n',
     ' '.join(cls_name(b) for b in r1) + '\n' + ' '.join(cls_name(b) for b in r2) + '\n'
     + '-0 0 9.88131e-324\n')

# ------------------------------------------------------------------ seacheck: no recursion limits

# 2000 else-if links (DESIGN.md 2.7: the if after else adds no nesting); x = 1234 picks the link
# that prints 1234.
lines = ['let x = 1234', 'if x == 0 {', '    printf("%d\\n", 0)']
for k in range(1, 2000):
    lines += ['} else if x == %d {' % k, '    printf("%%d\\n", %d)' % k]
lines += ['} else {', '    printf("none\\n")', '}']
prog('stmt_else_if_2000', 'an else-if chain of 2000 links (DESIGN.md 2.7; seacheck iterates)',
     '\n'.join(lines) + '\n', '1234\n')

# 1000 constants declared in reverse order of use (LANGUAGE.md 7.2: visible before their
# declaration): K1000 = 0 and K(k) = K(k+1) + 1, so K1 = 999.
lines = ['const K%d = K%d + 1' % (k, k + 1) for k in range(1, 1000)] + ['const K1000 = 0',
                                                                        'printf("%d\\n", K1)']
prog('const_reverse_1000', 'a chain of 1000 constants written in reverse order (LANGUAGE.md 7.2)',
     '\n'.join(lines) + '\n', '999\n')

# ------------------------------------------------------------------ seacheck fixes

# Precision digits with leading zeros are decimal digits (LANGUAGE.md 11.1): .0000000005 is 5,
# .00 is 0 (%.0e of 2.5: a tie, to even: 2e+00), .000 on %d is precision 0 (7 prints 7),
# width 5 with precision .0000000002 of 3.14159: " 3.14".
prog('fmt_prec_zeros', 'precision digits may have leading zeros (LANGUAGE.md 11.1)',
     'printf("[%.0000000005f] [%.00e] [%.000d] [%5.0000000002f]\\n", 1.0, 2.5, 7, 3.14159)\n',
     '[1.00000] [2e+00] [7] [ 3.14]\n')

# A tuple assignment converts an i64 result to an f64 target (LANGUAGE.md 4.2 (b), 7.3):
# a = 3.0, b = 4.
prog('stmt_tasg_cvt', 'a tuple assignment converts an i64 component to an f64 target '
     '(LANGUAGE.md 4.2, 7.3)',
     'fn two(n: i64) -> (i64, i64) {\n    return (n, n + 1)\n}\n'
     'var a = 0.5\nvar b = 0\n(a, b) = two(3)\nprintf("%f %d\\n", a, b)\n',
     '3.000000 4\n')

# f64(x) of an f64 and i64(x) of an i64 return x; an untyped literal argument is i64
# (LANGUAGE.md 4.2, 10.1): f64(3) is 3.0, i64(3) is 3.
prog('lib_conv_identity', 'f64() of an f64 and i64() of an i64 are the identity; an untyped '
     'argument is i64 (LANGUAGE.md 10.1)',
     'let x = 2.5\nlet n = 7\nprintf("%f %d %f %d\\n", f64(x), i64(n), f64(3), i64(3))\n',
     '2.500000 7 3.000000 3\n')

# Two blanks between `for` and the loop variable (L1: npos is the name's own position).
prog('stmt_for_blanks', 'two blanks between for and the loop variable (LANGUAGE.md 7.5; L1)',
     'for  i in 0..3 {\n    printf("%d\\n", i)\n}\n', '0\n1\n2\n')

# ------------------------------------------------------------------ errors

body = 'fn f(ref x: i64) {\n    x += 1\n}\nf(ref f)\n'
err('err_ref_target_fn', 'a function name as a ref argument: at the ref (LANGUAGE.md 8.3)',
    body, 5, col_of('f(ref f)', 'ref'), 'ref argument must be a mutable variable, element or field')

body = 'fn two() -> (i64, i64) {\n    return (1, 2)\n}\nlet y: i64 = two()\n'
err('err_result_count_annot', 'an annotated let of a 2-result call: at the call, before any '
    'conversion (LANGUAGE.md 8.4)', body, 5, col_of('let y: i64 = two()', 'two'),
    'wrong number of results: expected 2, found 1')

body = 'fn p() {\n    printf("x\\n")\n}\nlet y = p()\n'
err('err_result_count_void_value', 'a call without results used as a value: at the call '
    '(LANGUAGE.md 8.4)', body, 5, col_of('let y = p()', 'p('),
    'wrong number of results: expected 0, found 1')

# DESIGN.md 2.6.2: `binding` of a loop variable is the `for` node (its pos, the keyword).
body = 'for  pi in 0..3 {\n    printf("%d\\n", pi)\n}\n'
err('err_shadow_for_blanks', 'a loop variable shadowing a predeclared name, two blanks after for: '
    'at the for node (DESIGN.md 2.6.2 binding)', body, 2, 1, 'local name shadows a predeclared name')

# DESIGN.md 2.6.2 expr: arms of an if expression whose types differ -> the else arm; the then
# arm's type is the one expected.
body = 'let n = 1\nlet x = if n > 0 { n } else { 2.5 }\n'
err('err_type_mismatch_ifx_arm', 'typed if-expression arms of different types: at the else arm '
    '(LANGUAGE.md 6.10; DESIGN.md 2.6.2)', body, 3,
    col_of('let x = if n > 0 { n } else { 2.5 }', '2.5'), 'type mismatch: expected i64, found f64')

body = 'fn f() -> i64 {\n    while true {\n        return 1\n    }\n}\nprintf("%d\\n", f())\n'
err('err_missing_return_while', 'a loop never ends every path, even while true (LANGUAGE.md 8.1)',
    body, 2, 1, 'missing return')

# The cycle A -> B -> A is found while checking A (first in source order); the name that closes
# it is the A in B's expression.
body = 'const A = B + 1\nconst B = A + 1\nlet x = A\n'
err('err_not_constant_cycle', 'a constant cycle through another constant: at the name that '
    'closes it (LANGUAGE.md 7.2)', body, 3, col_of('const B = A + 1', 'A'),
    'not a constant expression')

# The undeclared q and the + both start at column 9: the inner construct is reported
# (LANGUAGE.md 9.1).
body = 'let x = q + true\n'
err('err_same_pos_priority', 'two errors at one position: the inner one first (LANGUAGE.md 9.1)',
    body, 2, 9, "undeclared name 'q'")

body = 'var x = 1\nvar y = 2\nx + y = 3\n'
err('err_no_effect_asg', 'x + y = 3 is an expression statement (LANGUAGE.md 7.1)', body, 4, 1,
    'expression statement has no effect')

body = 'fn f(a: i64) -> i64 {\n    return a\n}\nf(1) = 3\n'
err('err_call_then_asg', "a call statement ends after the call: f(1) = 3 (LANGUAGE.md 7.1)", body,
    5, col_of('f(1) = 3', '='), "unexpected token '='")

body = 'let x = f64 + 1\n'
err('err_conv_no_paren', 'a conversion keyword without ( names the next token (LANGUAGE.md App. A)',
    body, 2, col_of('let x = f64 + 1', '+'), "unexpected token '+'")

# A closed standard output: the final flush fails with EBADF, reported without a site
# (DESIGN.md 4.6; errno text of id 18).
err('err_rt_stdout_closed', 'standard output closed (>&-): the final flush fails (LANGUAGE.md 9.2)',
    'printf("hello\\n")\n', None, None, "cannot write '<stdout>': Bad file descriptor",
    meta='stdout=closed\n')

print('wave2_gen: written')
