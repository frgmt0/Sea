"""Sub-phase 6b, T1: the calls-and-output tests of DESIGN.md 6.2 ("Phase-6 tests", "6b, calls").

Run with `timeout 120 uv run --no-project python tests/vectors/call6_cases.py` (after
`fmod6_cases.py`, which writes the `fmod_*` programs). It writes

  programs/call6_*   named and default arguments (LANGUAGE.md 8.1), also of prelude functions
  programs/inl_*     programs whose output proves LANGUAGE.md 8.6 inlining does not change meaning
  programs/fmt6_*    `format` of every conversion and flag of the printf tests, printed with `print`
  programs/print_*   `print` (LANGUAGE.md 11.2)
  programs/mkdir_*   `make_dir` (LANGUAGE.md 10.10)
  errors/err_call6_* compile errors 224-227, 236, 237, 254, 201, 260, 261, 200, 243, 210, 211, 233, 234
  errors/r_inl6_*    run-time errors inside inlined functions (DESIGN.md 3.6.4 "Sites")
  errors/r_mkdir_*, errors/r_print_flush, errors/err_ns_lib_write_json
  and re-derives the five L-by goldens, moves err_prel_named to programs/call6_prel_named and
  deletes the four retired phase-rule goldens (DESIGN.md 6.2 "Existing tests that phase 6 changes").

Every expected byte is derived from LANGUAGE.md and DESIGN.md, never from a run of the compiler:

* the values are computed here by a Python mirror of each program, written beside the program
  (exact integers for `i64`, IEEE binary64 for `f64`); every printed `f64` goes through the exact
  printf oracle of tests/vectors/progfmt.py (LANGUAGE.md 11.1), never through Python's `%`;
* `fmt6_*`: the cases of progfmt.py's generators are captured (progfmt.write_program is replaced
  by a recorder), and each one becomes two lines of a program, `printf(F, args)` and
  `print(format(F, args))`, so the output is the oracle's bytes twice (LANGUAGE.md 11.1: `format`
  is the str of what `printf` writes; DESIGN.md 4.8 entry FORMAT);
* error positions come from DESIGN.md 2.6.2 (the `at` column) and 3.3: a call at its callee name,
  an argument or a default at its first token, a `bin` at its left operand, a `narg` at its name,
  a `param` at its name; run-time lines are the line of the failing expression or statement inside
  the callee (an inlined function keeps its own sites, DESIGN.md 3.6.4), except an argument
  expression, a deferred `ref` argument's recheck and a failed `make_dir`, which are the caller's;
* the line or column of every error is computed from a marker in the source text.

Implementer readings (flagged in the T1 report): a record result of an inlined function (R32)
cannot be written (a record has no type syntax: every parameter and result type is written,
LANGUAGE.md 4.10), so `inl_result_*` cover struct, fixed-size and tuple results only.
"""

import math
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import progfmt  # noqa: E402  (the exact printf oracle; LANGUAGE.md 11.1)

TESTS = os.path.dirname(HERE)
PROGRAMS = os.path.join(TESTS, 'programs')
ERRORS = os.path.join(TESTS, 'errors')
COUNT = {'programs': 0, 'errors': 0}


# ---------------------------------------------------------------------------- helpers
def f2b(x):
    return struct.unpack('>Q', struct.pack('>d', x))[0]


def g17(x):
    """printf("%.17g") of an f64 (LANGUAGE.md 11.1), as text."""
    return progfmt.format_all('%.17g', [('f', f2b(x))]).decode()


def gg(x):
    """printf("%g") of an f64, as text."""
    return progfmt.format_all('%g', [('f', f2b(x))]).decode()


def gf(prec, x):
    return progfmt.format_all('%.' + str(prec) + 'f', [('f', f2b(x))]).decode()


def wbytes(path, data):
    if isinstance(data, str):
        data = data.encode('utf-8')
    with open(path, 'wb') as f:
        f.write(data)


def remove(path):
    if os.path.exists(path):
        os.remove(path)


def source(name, comment, body):
    head = '// %s -- %s' % (name, comment[0]) + ''.join('\n// %s' % c for c in comment[1:]) + '\n'
    src = head + body
    if not src.endswith('\n'):
        src += '\n'
    for ln in src.split('\n'):
        assert len(ln.encode('utf-8')) <= 4096, ln[:50]
    return src


def prog(name, comment, body, out):
    """programs/NAME.sea and NAME.out."""
    wbytes(os.path.join(PROGRAMS, name + '.sea'), source(name, comment, body))
    wbytes(os.path.join(PROGRAMS, name + '.out'), out)
    COUNT['programs'] += 1


def line_of(src, marker, nth=0):
    hits = [i + 1 for i, ln in enumerate(src.split('\n')) if marker in ln and not ln.startswith('//')]
    assert len(hits) > nth, (marker, hits)
    return hits[nth]


def err_c(name, comment, body, line_marker, col_text, msg, nth=0, col_off=0):
    """errors/NAME: a compile error `NAME.sea:LINE:COL: error: MSG`; LINE is the line holding
    line_marker (the nth hit), COL the 1-based column of col_text in that line (+ col_off)."""
    src = source(name, comment, body)
    ln = line_of(src, line_marker, nth)
    text = src.split('\n')[ln - 1]
    col = text.index(col_text) + 1 + col_off
    base = os.path.join(ERRORS, name)
    wbytes(base + '.sea', src)
    wbytes(base + '.err', '%s.sea:%d:%d: error: %s\n' % (name, ln, col, msg))
    wbytes(base + '.status', '1\n')
    COUNT['errors'] += 1


def err_r(name, comment, body, line_marker, msg, out=b'', files=None, nth=0):
    """errors/NAME: a run-time error `NAME.sea:LINE: error: MSG`, status 1, standard output OUT."""
    src = source(name, comment, body)
    ln = line_of(src, line_marker, nth)
    base = os.path.join(ERRORS, name)
    wbytes(base + '.sea', src)
    wbytes(base + '.err', '%s.sea:%d: error: %s\n' % (name, ln, msg))
    wbytes(base + '.status', '1\n')
    if out:
        wbytes(base + '.out', out)
    if files:
        os.makedirs(base + '.files', exist_ok=True)
        for fn, data in files.items():
            wbytes(os.path.join(base + '.files', fn), data)
    COUNT['errors'] += 1


PV = '''fn pv(v: f64[]) {
    printf("%d:", len(v))
    for x in v {
        printf(" %g", x)
    }
    printf("\\n")
}
'''
PVI = '''fn pvi(v: i64[]) {
    printf("%d:", len(v))
    for x in v {
        printf(" %d", x)
    }
    printf("\\n")
}
'''
TRACE = '''fn t(k: i64, v: i64) -> i64 {
    printf("eval %d\\n", k)
    return v
}
'''


# ---------------------------------------------------------------------------- call6: named arguments
def call6_named():
    body = TRACE + '''fn f(a: i64, b: i64, c: i64) -> i64 {
    return a * 100 + b * 10 + c
}
printf("%d\\n", f(t(1, 1), t(2, 2), t(3, 3)))
printf("%d\\n", f(a: t(1, 1), b: t(2, 2), c: t(3, 3)))
printf("%d\\n", f(a: t(1, 1), c: t(2, 3), b: t(3, 2)))
printf("%d\\n", f(b: t(1, 2), a: t(2, 1), c: t(3, 3)))
printf("%d\\n", f(b: t(1, 2), c: t(2, 3), a: t(3, 1)))
printf("%d\\n", f(c: t(1, 3), a: t(2, 1), b: t(3, 2)))
printf("%d\\n", f(c: t(1, 3), b: t(2, 2), a: t(3, 1)))
printf("%d\\n", f(t(1, 1), c: t(2, 3), b: t(3, 2)))
printf("%d\\n", f(t(1, 1), t(2, 2), c: t(3, 3)))
printf("%d\\n", f(c: t(v: 3, k: 1), a: t(k: 2, v: 1), b: t(v: 2, k: 3)))
'''
    # every call evaluates its arguments in source order (LANGUAGE.md 8.1, 6.8) and binds the values
    # to the parameters they name: a = 1, b = 2, c = 3 whatever the order, so every result is 123
    out = ''.join('eval 1\neval 2\neval 3\n123\n' for _ in range(10))
    prog('call6_named_order',
         ['named arguments in every order, with argument expressions that print (LANGUAGE.md 8.1: the arguments are',
          'evaluated in source order, named ones included, whatever order the parameters they name stand in; 6.8)'],
         body, out)


def call6_named_types():
    body = '''struct Pt { x: f64, y: f64 }
fn g(x: f64, flag: bool, name: str, n: i64) {
    printf("%s n=%d flag=%d x=%.2f\\n", name, n, flag, x)
}
fn h(v: f64[], scale: f64) -> f64 {
    return sum(v) * scale
}
fn norm1(p: Pt, w: f64) -> f64 {
    return (abs(p.x) + abs(p.y)) * w
}
g(1.5, true, "a", 2)
g(n: 3, name: "b", flag: false, x: 2.25)
g(0.5, n: 4, flag: true, name: "c")
g(name: "d", x: 7, flag: false, n: 1)
let k = 3
g(x: k, flag: true, name: "e", n: k)
let arr: f64[] = [1.0, 2.0, 3.0]
printf("%g\\n", h(scale: 2.0, v: arr))
printf("%g\\n", h(arr, scale: 0.5))
printf("%g\\n", norm1(w: 2.0, p: Pt { x: -1.0, y: 2.5 }))
'''
    out = ('a n=2 flag=1 x=1.50\nb n=3 flag=0 x=2.25\nc n=4 flag=1 x=0.50\nd n=1 flag=0 x=7.00\n'
           'e n=3 flag=1 x=3.00\n12\n3\n7\n')
    prog('call6_named_types',
         ['named arguments of every scalar type, a str, an array and a struct parameter, out of order; an untyped',
          'integer literal and an i64 value for an f64 parameter convert as any argument does (LANGUAGE.md 8.1, 4.2)'],
         body, out)


def call6_defaults():
    body = '''const K = 4
const NAME = "cfg"
fn d(n: i64 = K, x: f64 = pi, y: f64 = 2.0 * pi + 1.0, ok: bool = true, s: str = NAME, w: str = "x" + "y", z: f64 = -0.5, m: i64 = K * 2 + 1, h: f64 = 2) {
    printf("n=%d x=%.17g y=%.17g ok=%d s=%s w=%s z=%g m=%d h=%g\\n", n, x, y, ok, s, w, z, m, h)
}
d()
d(1)
d(1, 1.0)
d(2, 2.0, 3.0, false, "q", "r", 4.0, 5, 6.5)
d(m: 3)
d(s: "named", n: 0)
d(1, z: 9.0, x: 0.25)
d(ok: false, h: 0.125)
'''
    pi = math.pi
    y = 2.0 * pi + 1.0

    def line(n=4, x=pi, yy=y, ok=1, s='cfg', w='xy', z=-0.5, m=9, h=2.0):
        return 'n=%d x=%s y=%s ok=%d s=%s w=%s z=%s m=%d h=%s\n' % (n, g17(x), g17(yy), ok, s, w, gg(z), m, gg(h))
    out = (line() + line(n=1) + line(n=1, x=1.0) + line(2, 2.0, 3.0, 0, 'q', 'r', 4.0, 5, 6.5)
           + line(m=3) + line(n=0, s='named') + line(n=1, z=9.0, x=0.25) + line(ok=0, h=0.125))
    prog('call6_defaults',
         ['defaults of each scalar type and of str: a constant name (K, NAME), pi, an operator expression (2.0 * pi + 1.0,',
          'K * 2 + 1, "x" + "y"), a negative literal and an untyped integer for an f64 parameter; omitted, positional and',
          'named arguments mixed (LANGUAGE.md 8.1, 7.2: a default is a constant); %.17g shows pi and 2 * pi + 1 exactly'],
         body, out)


def call6_defaults_named():
    body = TRACE + '''fn j(a: i64, b: i64 = 10, c: i64 = 20, d: i64 = 30) {
    printf("%d %d %d %d\\n", a, b, c, d)
}
j(1)
j(1, 2)
j(1, d: 4)
j(1, c: 3)
j(d: 4, a: 1)
j(1, 2, d: 9)
j(c: 7, b: 8, a: 9)
j(d: 1, c: 2, b: 3, a: 4)
j(t(1, 1), d: t(2, 4), b: t(3, 2))
'''
    out = ('1 10 20 30\n1 2 20 30\n1 10 20 4\n1 10 3 30\n1 10 20 4\n1 2 20 9\n9 8 7 30\n4 3 2 1\n'
           'eval 1\neval 2\neval 3\n1 2 20 4\n')
    prog('call6_defaults_named',
         ['defaults with named arguments: a parameter skipped by name keeps its default, the others are given in any order,',
          'and the argument expressions still evaluate in source order (LANGUAGE.md 8.1)'],
         body, out)


def call6_default_ref():
    body = '''fn bump(ref x: i64, by: i64 = 1, times: i64 = 1) {
    for k in 0..times {
        x += by
    }
}
fn scale(ref a: f64[], k: f64 = 2.0) {
    for i in 0..len(a) {
        a[i] *= k
    }
}
var v = 0
bump(ref v)
printf("%d\\n", v)
bump(ref v, 5)
printf("%d\\n", v)
bump(ref v, times: 3, by: 2)
printf("%d\\n", v)
bump(ref v, times: 2)
printf("%d\\n", v)
var w: f64[] = [1.0, 2.0]
scale(ref w)
printf("%g %g\\n", w[0], w[1])
scale(ref w, k: 0.5)
printf("%g %g\\n", w[0], w[1])
'''
    out = '1\n6\n12\n14\n2 4\n1 2\n'
    prog('call6_default_ref',
         ['a ref parameter (given positionally only, never defaulted) followed by parameters with defaults, some given by',
          'name (LANGUAGE.md 8.1, 8.3)'], body, out)


def call6_defaults_const_late():
    body = '''fn f(n: i64 = LATER, m: i64 = LATER * 2) -> i64 {
    return n + m
}
const LATER = EARLY + 1
const EARLY = 41
printf("%d\\n", f())
printf("%d\\n", f(1))
printf("%d\\n", f(m: 0))
printf("%d\\n", f(n: 2, m: 3))
'''
    out = '126\n85\n42\n5\n'     # LATER = 42, m = 84
    prog('call6_defaults_const_late',
         ['a default naming constants that are declared after the function, one defined by another constant, and an',
          'operator expression of a constant (LANGUAGE.md 7.2: any order; 8.1)'], body, out)


def call6_default_recursive():
    body = '''fn sumto(n: i64, acc: i64 = 0) -> i64 {
    if n == 0 {
        return acc
    }
    return sumto(n - 1, acc: acc + n)
}
fn power(base: i64, e: i64 = 2, r: i64 = 1) -> i64 {
    if e == 0 {
        return r
    }
    return power(base, e: e - 1, r: r * base)
}
printf("%d\\n", sumto(10))
printf("%d\\n", sumto(100, acc: 1000))
printf("%d\\n", power(3))
printf("%d\\n", power(2, e: 10))
printf("%d\\n", power(e: 5, base: 2))
'''
    out = '55\n6050\n9\n1024\n32\n'
    prog('call6_default_recursive',
         ['a recursive function (it stays a call, LANGUAGE.md 8.6) with defaults and a named argument in its own body'],
         body, out)


def call6_prel():
    prog('call6_prel_named',
         ['a named argument of a prelude function: linspace(0.0, 1.0, n: 3) is legal from 6b (it was the phase-rule',
          'error err_prel_named until then); the values 0, 0.5 and 1 by LANGUAGE.md 10.3 (n1 = 2: d1 + (k * (d2 - d1)) / n1)'],
         '''let v = linspace(0.0, 1.0, n: 3)
printf("%d: %g %g %g\\n", len(v), v[0], v[1], v[2])
''', '3: 0 0.5 1\n')
    body = TRACE + '''fn tf(k: i64, v: f64) -> f64 {
    printf("eval %d\\n", k)
    return v
}
''' + PV + PVI + '''pv(linspace(n: 5, d2: 1.0, d1: 0.0))
pv(linspace(0.0, d2: 2.0, n: 3))
pv(linspace(d2: 1.0, d1: 0.0, n: 3))
pv(linspace(tf(1, 1.0), n: t(2, 4), d2: tf(3, 4.0)))
let xs: f64[] = [1.0, 2.0, 3.0]
let ys: f64[] = [10.0, 20.0]
let (X, Y) = meshgrid(y: ys, x: xs)
for i in 0..rows(X) {
    for j in 0..cols(X) {
        printf(" %g,%g", X[i, j], Y[i, j])
    }
    printf(" |")
}
printf("\\n")
let ids: i64[] = [0, 1, 1, 3, 3, 3]
pvi(bincount(n: 5, idx: ids))
let a: i64[] = [5, 1, 3, 3, 9]
let b: i64[] = [3, 9]
pvi(setdiff(b: b, a: a))
pvi(setdiff(b: a, a: b))
pvi(setdiff(a, b: b))
'''
    # linspace(n: 5, d2: 1, d1: 0): y[k] = 0 + (k * 1) / 4; (0, 2, 3): 0, 1, 2; (0, 1, 3): 0, .5, 1;
    # linspace(1, 4, n=4) = 1 + (k * 3) / 3 = 1 2 3 4; the order of evaluation is the source's: tf(1), t(2), tf(3)
    out = ('5: 0 0.25 0.5 0.75 1\n3: 0 1 2\n3: 0 0.5 1\neval 1\neval 2\neval 3\n4: 1 2 3 4\n'
           ' 1,10 2,10 3,10 | 1,20 2,20 3,20 |\n'
           '5: 1 2 0 3 0\n'
           '2: 1 5\n'    # setdiff(b: b, a: a) is setdiff(a, b): 1, 5
           '0:\n'        # setdiff(b: a, a: b) is setdiff(b, a): the values of b not in a: none
           '2: 1 5\n')
    prog('call6_prel_named_order',
         ['named arguments of the prelude functions linspace, meshgrid, bincount and setdiff in parameter order and not',
          '(LANGUAGE.md 10.3, 10.6, 10.7, 8.1: a prelude function is called like a user function, with its own parameter',
          'names); the argument expressions evaluate in source order'], body, out)


# ---------------------------------------------------------------------------- inl: semantics unchanged
def inl_single_loop():
    body = '''fn sumsq(n: i64) -> i64 {
    var s = 0
    for k in 1..=n {
        s += k * k
    }
    return s
}
fn first_over(limit: i64) -> i64 {
    var k = 1
    while k < 1000 {
        if k * k > limit {
            return k
        }
        k += 1
    }
    return -1
}
fn first_neg(v: f64[]) -> i64 {
    for i in 0..len(v) {
        if v[i] < 0.0 {
            return i
        }
    }
    return -1
}
fn count_skip(n: i64) -> i64 {
    var c = 0
    for k in 0..n {
        if k % 2 == 0 {
            continue
        }
        if k > 15 {
            break
        }
        c += k
    }
    return c
}
printf("%d\\n", sumsq(10))
printf("%d\\n", first_over(50))
let pos: f64[] = [1.0, 2.0]
printf("%d\\n", first_neg(pos))
printf("%d\\n", count_skip(20))
'''
    s = sum(k * k for k in range(1, 11))
    fo = next(k for k in range(1, 1000) if k * k > 50)
    cs = 0
    for k in range(20):
        if k % 2 == 0:
            continue
        if k > 15:
            break
        cs += k
    prog('inl_single_loop',
         ['functions with a loop called from exactly one call site (LANGUAGE.md 8.6 (b), inlined): a for loop, a while loop',
          'with an early return, a loop returning from inside, break and continue; the output is what a call would give'],
         body, '%d\n%d\n-1\n%d\n' % (s, fo, cs))


def inl_many_calls():
    body = '''fn clamp(x: i64, lo: i64, hi: i64) -> i64 {
    if x < lo {
        return lo
    }
    if x > hi {
        return hi
    }
    return x
}
fn sq(x: f64) -> f64 {
    return x * x
}
fn hyp2(a: f64, b: f64) -> f64 {
    return sq(a) + sq(b)
}
var tot = 0
for k in -5..15 {
    tot += clamp(k, 0, 9)
}
printf("%d\\n", tot)
printf("%d %d %d\\n", clamp(-1, 0, 3), clamp(2, 0, 3), clamp(7, 0, 3))
printf("%g %g\\n", hyp2(3.0, 4.0), hyp2(0.5, 1.5))
var acc = 0.0
for k in 0..1000 {
    acc += sq(f64(k) * 0.5)
}
printf("%.17g\\n", acc)
'''
    cl = lambda x, lo, hi: lo if x < lo else (hi if x > hi else x)
    tot = sum(cl(k, 0, 9) for k in range(-5, 15))
    acc = 0.0
    for k in range(1000):
        v = float(k) * 0.5
        acc += v * v
    out = '%d\n%d %d %d\n%s %s\n%s\n' % (tot, cl(-1, 0, 3), cl(2, 0, 3), cl(7, 0, 3),
                                        gg(3.0 * 3.0 + 4.0 * 4.0), gg(0.5 * 0.5 + 1.5 * 1.5), g17(acc))
    prog('inl_many_calls',
         ['small non-recursive functions without a loop called from many sites, in a loop and outside it, one calling',
          'another (LANGUAGE.md 8.6 (c), inlined at every site)'], body, out)


def inl_nested():
    body = '''fn f0(x: i64) -> i64 {
    return x + 1
}
fn f1(x: i64) -> i64 {
    return f0(f0(x))
}
fn f2(x: i64) -> i64 {
    return f1(f1(x))
}
fn f3(x: i64) -> i64 {
    return f2(f2(x))
}
fn a(x: f64) -> f64 {
    return b(x) * 2.0
}
fn b(x: f64) -> f64 {
    return c(x) + 1.0
}
fn c(x: f64) -> f64 {
    return x * x
}
printf("%d %d %d %d\\n", f0(0), f1(0), f2(0), f3(0))
printf("%d\\n", f3(f3(f3(1))))
printf("%g %g\\n", a(3.0), c(b(a(1.0))))
'''
    # f_k adds 2^k; a(x) = (x*x + 1) * 2; c(b(a(1))) = ((a(1) * a(1)) + 1)^2 with a(1) = 4: b(4) = 17, c(17) = 289
    out = '1 2 4 8\n25\n20 289\n'
    prog('inl_nested',
         ['nested inlining: f1 calls f0 twice, f2 calls f1 twice, f3 calls f2 twice (each call site is inlined, so 8 copies',
          'of f0), a chain a -> b -> c, and calls nested in arguments (LANGUAGE.md 8.6 (c); DESIGN.md 2.11.4 L20 inlines',
          'recursively)'], body, out)


def inl_recursive_stays():
    body = '''fn fact(n: i64) -> i64 {
    if n <= 1 {
        return 1
    }
    return n * fact(n - 1)
}
fn is_even(n: i64) -> bool {
    if n == 0 {
        return true
    }
    return is_odd(n - 1)
}
fn is_odd(n: i64) -> bool {
    if n == 0 {
        return false
    }
    return is_even(n - 1)
}
fn depth(n: i64) -> i64 {
    if n == 0 {
        return 0
    }
    return 1 + depth(n - 1)
}
printf("%d %d\\n", fact(10), fact(20))
printf("%d %d %d\\n", is_even(10), is_odd(7), is_even(7))
printf("%d\\n", depth(20000))
'''
    out = '%d %d\n1 1 0\n20000\n' % (math.factorial(10), math.factorial(20))
    prog('inl_recursive_stays',
         ['recursive small functions stay calls (LANGUAGE.md 8.6: (c) needs a function that is not recursive; fact and the',
          'pair is_even/is_odd have two call sites each) and recursion 20000 deep works'], body, out)


def inl_mutual_single():
    body = '''fn a(n: i64) -> i64 {
    if n == 0 {
        return 0
    }
    return 1 + b(n - 1)
}
fn b(n: i64) -> i64 {
    if n == 0 {
        return 100
    }
    return 2 + a(n - 1)
}
printf("%d %d %d %d\\n", a(0), a(1), a(2), a(7))
'''

    def a(n):
        return 0 if n == 0 else 1 + b(n - 1)

    def b(n):
        return 100 if n == 0 else 2 + a(n - 1)
    out = '%d %d %d %d\n' % (a(0), a(1), a(2), a(7))
    prog('inl_mutual_single',
         ['a mutually recursive pair where b has exactly one call site (class (b), inlined into a: the recursion goes',
          'through the inlined body) and a has several (it stays a call); LANGUAGE.md 8.6, DESIGN.md 2.11.4 L20'],
         body, out)


def inl_ref_scalar():
    body = '''fn bump(ref x: i64) -> i64 {
    x += 10
    return x
}
fn addto(ref x: i64, y: i64) -> i64 {
    x += y
    return x
}
fn twice(ref x: i64) {
    x *= 2
}
fn quad(ref x: i64) {
    twice(ref x)
    twice(ref x)
}
fn show2(p: i64, q: i64) {
    printf("%d %d\\n", p, q)
}
var a = 1
let r1 = bump(ref a)
printf("%d %d\\n", a, r1)
a = 1
let y = a + bump(ref a)
printf("%d %d\\n", a, y)
a = 1
a += bump(ref a)
printf("%d\\n", a)
a = 1
let r2 = addto(ref a, bump(ref a))
printf("%d %d\\n", a, r2)
a = 1
show2(a, bump(ref a))
a = 1
show2(bump(ref a), a)
a = 3
twice(ref a)
twice(ref a)
printf("%d\\n", a)
quad(ref a)
printf("%d\\n", a)
'''
    out = ('11 11\n'          # bump: a = 11, result 11
           '11 12\n'          # y = (a read before the call: 1) + 11
           '12\n'             # a += bump(ref a): 1 + 11 stored last
           '22 22\n'          # deferred: bump leaves a = 11 and returns 11, addto then adds 11 to the updated a
           '1 11\n'           # the first argument was read before the call
           '11 11\n'          # read after the call sees the update
           '12\n'
           '48\n')
    prog('inl_ref_scalar',
         ['a ref scalar parameter of inlined functions (DESIGN.md 3.6.6 rule 12, 31, R31): the callee updates the caller\'s',
          'variable; a read evaluated before a ref call in the same statement keeps the old value (y = a + bump(ref a),',
          'a += bump(ref a), f(a, bump(ref a))); the deferred case f(ref a, g(ref a)) sees the variable as the inner',
          'call left it (LANGUAGE.md 8.3, 6.8); a ref parameter passed on to another inlined function'], body, out)


def inl_ref_elem():
    body = '''struct S { n: i64, w: f64 }
fn incr(ref x: f64) {
    x += 1.0
}
fn bumpn(ref n: i64) -> i64 {
    n += 1
    return n
}
fn setmax(ref m: f64, v: f64) {
    if v > m {
        m = v
    }
}
fn grow(ref v: f64[]) -> i64 {
    v = [9.0, 8.0, 7.0, 6.0, 5.0]
    return 5
}
fn addat(ref x: f64, k: i64) {
    x += f64(k)
}
fn twice_incr(ref x: f64) {
    incr(ref x)
    incr(ref x)
}
fn upd(ref s: S) {
    s.n += 1
    s.w *= 2.0
}
''' + PV + '''var v: f64[] = [1.0, 2.0, 3.0]
incr(ref v[1])
pv(v)
setmax(ref v[0], 4.5)
setmax(ref v[2], 1.0)
pv(v)
var s = S { n: 5, w: 0.5 }
let r = bumpn(ref s.n)
printf("%d %d %g\\n", s.n, r, s.w)
incr(ref s.w)
printf("%g\\n", s.w)
upd(ref s)
printf("%d %g\\n", s.n, s.w)
var ss = [S { n: 1, w: 1.0 }, S { n: 2, w: 2.0 }]
bumpn(ref ss[1].n)
upd(ref ss[0])
printf("%d %g %d %g\\n", ss[0].n, ss[0].w, ss[1].n, ss[1].w)
addat(ref v[0], grow(ref v))
pv(v)
twice_incr(ref v[4])
pv(v)
'''
    out = ('3: 1 3 3\n'
           '3: 4.5 3 3\n'
           '6 6 0.5\n'
           '1.5\n'
           '7 3\n'                  # upd: n 6 -> 7, w 1.5 -> 3
           '2 2 3 2\n'              # ss[0] = (1 -> 2, 1.0 -> 2.0); ss[1].n 2 -> 3, w 2.0
           '5: 14 8 7 6 5\n'        # deferred: v replaced by grow first, then v[0] = 9 + 5
           '5: 14 8 7 6 7\n')
    prog('inl_ref_elem',
         ['ref parameters bound to an element, a field and an element\'s field of inlined functions (rule 31: the path\'s',
          'checks, cows and address); a struct passed whole by ref; the deferred element case addat(ref v[0], grow(ref v)),',
          'where grow replaces v: the element is addressed in the new array (LANGUAGE.md 8.3; DESIGN.md 3.6.6 rule 31)'],
         body, out)


def inl_ref_array():
    body = '''fn fill(ref v: f64[], x: f64) {
    for i in 0..len(v) {
        v[i] = x
    }
}
fn rev(ref v: f64[]) {
    let n = len(v)
    for i in 0..idiv(n, 2) {
        let t = v[i]
        v[i] = v[n - 1 - i]
        v[n - 1 - i] = t
    }
}
fn first_to(ref v: f64[], x: f64) -> f64 {
    let old = v[0]
    v[0] = x
    return old
}
fn zap(ref v: f64[]) -> f64 {
    v = zeros(1)
    return 1.0
}
fn sum_with(v: f64[], k: f64) -> f64 {
    return sum(v) + k
}
''' + PV + '''var a: f64[] = [1.0, 2.0, 3.0]
var b = a
fill(ref b, 7.0)
pv(a)
pv(b)
rev(ref a)
pv(a)
let old = first_to(ref a, 100.0)
printf("%g\\n", old)
pv(a)
a[1] = 2.5
printf("%g\\n", sum_with(a, zap(ref a)))
pv(a)
printf("%g\\n", sum_with(a, 0.5))
'''
    # a = [1 2 3], b shares the buffer: fill(ref b) copies on write, a unchanged
    # rev: [3 2 1]; first_to returns 3 and stores 100: [100 2 1]; a[1] = 2.5: [100 2.5 1]
    # sum_with(a, zap(ref a)): a is read before zap and keeps its value: 103.5 + 1 = 104.5; then a = [0]
    out = ('3: 1 2 3\n'
           '3: 7 7 7\n'
           '3: 3 2 1\n'
           '3\n'
           '3: 100 2 1\n'
           '104.5\n'
           '1: 0\n'
           '0.5\n')
    prog('inl_ref_array',
         ['array ref parameters of inlined functions: an element store through ref copies a shared buffer (the other',
          'variable is unchanged), an in-place reversal, a whole-array replacement, and a value read before a ref call',
          'that replaces it (sum_with(a, zap(ref a)) sees the old array; rule 12 (a), R30, R31)'], body, out)


def inl_result_struct():
    body = '''struct P { x: f64, y: f64, n: i64 }
struct R { name: str, v: f64[], p: P }
fn mkp(a: f64, n: i64) -> P {
    return P { x: a, y: a * 2.0, n: n }
}
fn scalep(p: P, k: f64) -> P {
    var q = p
    q.x *= k
    q.y *= k
    return q
}
fn mkr(name: str, n: i64) -> R {
    return R { name: name + "!", v: [f64(n), f64(n) * 2.0], p: mkp(0.5, n) }
}
fn ident(r: R) -> R {
    return r
}
fn both(n: i64) -> (P, R) {
    return (mkp(f64(n), n), mkr("t", n))
}
fn pr(r: R) {
    printf("%s [%g %g] %g %g %d\\n", r.name, r.v[0], r.v[1], r.p.x, r.p.y, r.p.n)
}
let p = mkp(1.5, 3)
let q = scalep(p, 2.0)
printf("%g %g %d | %g %g %d\\n", p.x, p.y, p.n, q.x, q.y, q.n)
var r = mkr("a", 1)
pr(r)
r = mkr("b", 2)
pr(r)
let r2 = ident(r)
pr(r2)
pr(mkr("c", 3))
let (bp, br) = both(4)
printf("%g %d\\n", bp.x, bp.n)
pr(br)
'''
    out = ('1.5 3 3 | 3 6 3\n'
           'a! [1 2] 0.5 1 1\n'
           'b! [2 4] 0.5 1 2\n'
           'b! [2 4] 0.5 1 2\n'
           'c! [3 6] 0.5 1 3\n'
           '4 4\n'
           't! [4 8] 0.5 1 4\n')
    prog('inl_result_struct',
         ['struct results of inlined functions (R32: the result lives in a home the caller provides), a struct with str,',
          'array and nested struct fields, a result assigned over a var of the same type (the old value released: the heap',
          'check), a parameter returned unchanged, a tuple with a struct component bound by let (a record has no type',
          'syntax, so no function returns one: LANGUAGE.md 4.10)'], body, out)


def inl_result_fixed():
    body = '''struct P { x: f64, n: i64 }
fn f3(a: f64) -> f64[3] {
    return [a, a * 2.0, a * 3.0]
}
fn m22(a: f64) -> f64[2,2] {
    return [a, 0.0; 0.0, a + 1.0]
}
fn two(a: f64) -> P[2] {
    return [P { x: a, n: 1 }, P { x: a * 2.0, n: 2 }]
}
fn mix(a: f64) -> (f64[3], f64) {
    return (f3(a), a)
}
let u = f3(1.0)
printf("%g %g %g\\n", u[0], u[1], u[2])
var w = f3(2.0)
w = f3(w[1])
printf("%g %g %g\\n", w[0], w[1], w[2])
let M = m22(5.0)
printf("%g %g %g %g\\n", M[0, 0], M[0, 1], M[1, 0], M[1, 1])
let (t, s) = mix(2.0)
printf("%g %g %g %g\\n", t[0], t[1], t[2], s)
let ps = two(1.5)
printf("%g %d %g %d\\n", ps[0].x, ps[0].n, ps[1].x, ps[1].n)
'''
    out = '1 2 3\n4 8 12\n5 0 0 6\n2 4 6 2\n1.5 1 3 2\n'
    prog('inl_result_fixed',
         ['fixed-size results of inlined functions (R32): a vector, a matrix, an array of structs and a tuple holding one;',
          'a result assigned over a var whose old value feeds the call (w = f3(w[1]))'], body, out)


def inl_return_multi():
    body = '''fn two(x: i64) -> (i64, i64) {
    return (x, x * 2)
}
fn pass(x: i64) -> (i64, i64) {
    return two(x + 1)
}
fn mixed(x: f64) -> (f64, i64, str) {
    return (x * 2.0, 3, "s")
}
fn passm(x: f64) -> (f64, i64, str) {
    return mixed(x)
}
let (a, b) = pass(5)
printf("%d %d\\n", a, b)
let (c, d, e) = passm(1.5)
printf("%g %d %s\\n", c, d, e)
pass(1)
let (_, z) = pass(9)
printf("%d\\n", z)
let (p, _) = pass(0)
printf("%d\\n", p)
'''
    out = '6 12\n3 3 s\n20\n1\n'
    prog('inl_return_multi',
         ['return f(...) of a multiple-result call inside an inlined function (LANGUAGE.md 8.4: the results are returned',
          'unchanged), bound by let, discarded as a statement, and bound with _'], body, out)


def inl_calls_prelude():
    body = '''fn ramp_mean(n: i64) -> f64 {
    let v = linspace(0.0, 1.0, n)
    return sum(v) / f64(n)
}
fn ramp_named(n: i64) -> f64[] {
    return linspace(n: n, d2: 2.0, d1: 1.0)
}
fn count_vals(v: i64[], n: i64) -> i64[] {
    return bincount(v, n)
}
fn diffset(a: i64[], b: i64[]) -> i64[] {
    return setdiff(a, b)
}
''' + PV + PVI + '''printf("%.17g %.17g\\n", ramp_mean(5), ramp_mean(1))
pv(ramp_named(3))
let ids: i64[] = [0, 1, 1, 3, 3, 3]
pvi(count_vals(ids, 5))
pvi(diffset([5, 1, 3, 3, 9], [3, 9]))
'''
    # linspace(0, 1, 5) = 0 .25 .5 .75 1, sum 2.5 exactly, / 5 = 0.5; linspace(0, 1, 1) = [1], sum 1, / 1 = 1;
    # linspace(1, 2, 3) = 1 + (k * 1) / 2
    out = '0.5 1\n3: 1 1.5 2\n5: 1 2 0 3 0\n2: 1 5\n'
    prog('inl_calls_prelude',
         ['inlined functions that call prelude functions (linspace, bincount, setdiff, rule 37 inlines those: an inlined',
          'body holding an inlined body; LANGUAGE.md 10.3, 10.6, 10.7, 8.6)'], body, out)


def inl_two_sites_unreachable():
    body = '''fn tri(n: i64) -> i64 {
    var s = 0
    for k in 1..=n {
        s += k
    }
    return s
}
fn never() -> i64 {
    return tri(3)
}
fn once(n: i64) -> i64 {
    var s = 0
    for k in 0..n {
        s += k
    }
    return s
}
fn never2() -> i64 {
    return once(2)
}
printf("%d\\n", tri(4))
printf("%d\\n", once(5))
'''
    out = '10\n10\n'
    prog('inl_two_sites_unreachable',
         ['functions with a loop and two call sites, one of them in a function .main never reaches: not class (b), they',
          'stay calls (LANGUAGE.md 8.6: a call site is a call written anywhere in the file); the output is the same'],
         body, out)


def inl_stmt_forms():
    body = '''fn grade(x: i64) -> i64 {
    var r = 0
    if x < 10 {
        r = 1
    } else if x < 20 {
        r = 2
    } else {
        r = 3
    }
    {
        r += 10
        r *= 2
    }
    return r
}
fn kind(s: str) -> i64 {
    var r = -1
    match s {
        "a" | "b" => { r = 1 }
        "c" => {
            r = 2
            r += 1
        }
        _ => { r = 0 }
    }
    return r
}
printf("%d %d %d\\n", grade(5), grade(15), grade(25))
printf("%d %d %d %d\\n", kind("a"), kind("b"), kind("c"), kind("zz"))
'''
    out = '22 24 26\n1 1 3 0\n'
    prog('inl_stmt_forms',
         ['statement forms inside inlined functions: an if / else if / else chain, a bare block, a match with several',
          'patterns and a multi-statement arm (LANGUAGE.md 8.6 counts these statements; the dumps are T2\'s inl6_count*)'],
         body, out)


def inl_strings():
    body = '''fn shout(s: str) -> str {
    return s + "!"
}
fn label(k: i64) -> str {
    return "DG-" + str(k)
}
fn join3(a: str, b: str, c: str) -> str {
    return a + "/" + b + "/" + c
}
fn keep(ref s: str) {
    s += "?"
}
printf("%s %s\\n", shout("hi"), shout(shout("yo")))
printf("%s %s %s\\n", label(1), label(22), label(-3))
printf("%s\\n", join3(label(7), shout("x"), "z"))
var t = "q"
keep(ref t)
keep(ref t)
printf("%s %d\\n", t, len(t))
let s = shout("a")
let u = s + s
printf("%s %s\\n", s, u)
'''
    out = 'hi! yo!!\nDG-1 DG-22 DG--3\nDG-7/x!/z\nq?? 3\na! a!a!\n'
    prog('inl_strings',
         ['str parameters, results and a ref parameter of inlined functions (references retained and released: the heap',
          'check proves no leak)'], body, out)


def inl_array_params():
    body = '''fn dbl(v: f64[]) -> f64[] {
    return v * 2.0
}
fn ramp(n: i64) -> f64[] {
    var v = zeros(n)
    for k in 0..n {
        v[k] = f64(k) * 0.5
    }
    return v
}
fn total(v: f64[]) -> f64 {
    return sum(v)
}
fn msum(M: f64[,]) -> f64 {
    return sum(M.flat)
}
''' + PV + '''let a = ramp(4)
let b = dbl(a)
pv(a)
pv(b)
printf("%g %g\\n", total(a), total(dbl(b)))
let m: f64[,] = [1.0, 2.0; 3.0, 4.5]
printf("%g %g\\n", msum(m), msum(m * 2.0))
'''
    out = '4: 0 0.5 1 1.5\n4: 0 1 2 3\n3 12\n10.5 21\n'
    prog('inl_array_params',
         ['array and matrix arguments and results of inlined functions: the argument is unchanged after the call (value',
          'semantics), a call as an argument of another (LANGUAGE.md 8.2, 4.5)'], body, out)


def inl_eval_order():
    body = TRACE + '''fn use2(x: i64) -> i64 {
    return x + x
}
fn ignore(x: i64) -> i64 {
    return 7
}
fn sub(a: i64, b: i64) -> i64 {
    let r = b * 10
    return r + a
}
printf("%d\\n", use2(t(1, 5)))
printf("%d\\n", ignore(t(2, 5)))
printf("%d\\n", sub(t(3, 1), t(4, 2)))
printf("%d\\n", sub(b: t(5, 2), a: t(6, 1)))
printf("%d\\n", use2(use2(t(7, 3))))
'''
    out = ('eval 1\n10\n'            # the argument is evaluated once, though the callee reads it twice
           'eval 2\n7\n'             # an unused parameter's argument is still evaluated
           'eval 3\neval 4\n21\n'    # source order, whatever order the callee reads the parameters in
           'eval 5\neval 6\n21\n'
           'eval 7\n12\n')
    prog('inl_eval_order',
         ['inlining evaluates every argument once, in source order, also an argument the callee ignores or reads twice',
          'or in the other order (LANGUAGE.md 8.1, 6.8)'], body, out)


def inl_hygiene():
    body = '''fn f(x: i64) -> i64 {
    let y = x * 2
    var z = y + 1
    z += x
    return z
}
let x = 100
let y = 200
var z = 300
let w = f(x + 1)
printf("%d %d %d %d\\n", x, y, z, w)
z = f(z)
printf("%d\\n", z)
printf("%d\\n", f(f(1)))
'''
    f = lambda x: (x * 2 + 1) + x
    out = '100 200 300 %d\n%d\n%d\n' % (f(101), f(300), f(f(1)))
    prog('inl_hygiene',
         ['an inlined function whose parameter and locals have the names of the caller\'s variables: no capture, the',
          'caller\'s variables are unchanged (LANGUAGE.md 7.2 scopes)'], body, out)


def inl_return_branches():
    body = '''fn sign3(x: i64) -> i64 {
    if x < 0 {
        return -1
    } else if x > 0 {
        return 1
    }
    return 0
}
fn pick(a: i64, b: i64) -> i64 {
    if a > b {
        return a
    } else {
        if b > 100 {
            return 100
        }
        return b
    }
}
printf("%d %d %d\\n", sign3(-5), sign3(0), sign3(9))
printf("%d %d %d\\n", pick(3, 2), pick(2, 3), pick(2, 500))
let s = sign3(-1) + sign3(1) * 10 + pick(1, 2) * 100
printf("%d\\n", s)
'''
    out = '-1 0 1\n3 3 100\n%d\n' % (-1 + 10 + 200)
    prog('inl_return_branches',
         ['inlined functions that return from several branches and from a nested else block (LANGUAGE.md 8.1: a statement',
          'ends every path); the call is an operand of an expression'], body, out)


def inl_void():
    body = '''fn log_if(x: i64) {
    if x < 0 {
        return
    }
    printf("v%d\\n", x)
}
log_if(-1)
log_if(0)
log_if(3)
for k in -2..3 {
    log_if(k)
}
'''
    out = 'v0\nv3\nv0\nv1\nv2\n'
    prog('inl_void',
         ['an inlined function without a result and with an early return (LANGUAGE.md 8.1, 8.6)'], body, out)


def inl_conditional_context():
    body = '''fn probe(k: i64) -> i64 {
    printf("p%d ", k)
    return k * k
}
var k = 0
while probe(k) < 20 {
    k += 1
}
printf("\\n")
printf("k=%d\\n", k)
let on = true
let off = false
if on && probe(7) > 40 {
    printf("A\\n")
}
if off && probe(8) > 0 {
    printf("never\\n")
}
if off || probe(9) > 80 {
    printf("B\\n")
}
let z = if k > 3 { probe(1) } else { probe(2) }
printf("z=%d\\n", z)
for j in 0..4 {
    if probe(j) > 3 {
        break
    }
}
printf("\\n")
'''
    out = ('p0 p1 p2 p3 p4 p5 \nk=5\n'          # the call in the while condition runs at every test
           'p7 A\n'                            # && evaluates its right operand only when the left is true
           'p9 B\n'                            # || only when the left is false
           'p1 z=1\n'                          # only the arm taken
           'p0 p1 p2 \n')                      # break after probe(2) = 4 > 3
    prog('inl_conditional_context',
         ['an inlined call in a while condition (re-evaluated at every test), in the right operand of && and || (only when',
          'reached), in the arms of an if expression (only the arm taken) and in an if condition inside a loop with break',
          '(LANGUAGE.md 6.4, 6.8, 6.10)'], body, out)


# ---------------------------------------------------------------------------- fmt6, print, mkdir
def fmt6_from_progfmt():
    """Capture progfmt's cases and write fmt6_* programs: printf and print(format()) of each case."""
    captured = {}

    def recorder(name, header, cases, prologue=()):
        captured[name] = (header, cases, list(prologue))
    orig = progfmt.write_program
    progfmt.write_program = recorder
    try:
        for fn in (progfmt.gen_fmt_f, progfmt.gen_fmt_e, progfmt.gen_fmt_g, progfmt.gen_fmt_d,
                   progfmt.gen_fmt_d_f64, progfmt.gen_fmt_s, progfmt.gen_fmt_pct, progfmt.gen_fmt_nonfinite):
            fn()
    finally:
        progfmt.write_program = orig
    for name, (header, cases, prologue) in sorted(captured.items()):
        lines = list(prologue)
        out = b''
        for fmt, args in cases:
            argtxt = ''.join(', ' + e for e, _ in args)
            fs = progfmt.sea_string(fmt)
            lines.append('printf("%s"%s)' % (fs, argtxt))
            lines.append('print(format("%s"%s))' % (fs, argtxt))
            one = progfmt.format_all(fmt, [a for _, a in args])
            out += one + one
        new = 'fmt6' + name[3:]
        prog(new, ['format of the cases of %s.sea, printed with print and byte-equal to the printf line of the same' % name,
                   'arguments (LANGUAGE.md 11.1, 10.9: format(F, ...) is the str that printf(F, ...) writes); the',
                   'expected bytes are progfmt.py\'s exact decimal oracle, each case twice'] + [],
             '\n'.join(lines) + '\n', out)


def fmt6_from_files():
    """fmt_d_ext and fmt_prec_zeros: each printf line gets its print(format()) twin."""
    for src_name, new in (('fmt_d_ext', 'fmt6_d_ext'), ('fmt_prec_zeros', 'fmt6_prec_zeros')):
        with open(os.path.join(PROGRAMS, src_name + '.sea'), 'rb') as f:
            text = f.read().decode('utf-8')
        with open(os.path.join(PROGRAMS, src_name + '.out'), 'rb') as f:
            outl = f.read().decode('utf-8').split('\n')[:-1]
        lines = [ln for ln in text.split('\n') if ln.startswith('printf(')]
        assert len(lines) == len(outl), src_name          # one output line per printf (each ends in \n)
        body = ''
        out = ''
        for ln, o in zip(lines, outl):
            body += ln + '\n' + 'print(format(' + ln[len('printf('):] + ')\n'
            out += o + '\n' + o + '\n'
        prog(new, ['the printf lines of %s.sea, each followed by print(format(...)) of the same arguments, byte-equal' % src_name,
                   '(LANGUAGE.md 11.1: %d of a bool, of -0.0, C integer rules for an integral f64, %e for a non-integral one)'],
             body, out)


def fmt6_misc():
    body = TRACE + '''let s = format("%d-%s", 5, "ab")
printf("%s|%d\\n", s, len(s))
let tg = format("DG-%03d", 7)
let u = s + "/" + tg
print(u + "\\n")
for k in 0..3 {
    print(format("DG-%03d,", k + 1))
}
print("\\n")
printf("%d\\n", len(format("")))
printf("%s\\n", format("%%"))
let lbl = format("%5.1f|%-6d|%+d", 3.14159, 42, 7)
printf("%s\\n", lbl)
if format("%d", 10) == "10" {
    printf("eq\\n")
}
printf("%d\\n", len(format("%s%s", s, tg)))
let big = 2 ^ 10
printf("%s\\n", format("%d %.3f %s", i64(big), 0.5, str(1.25)))
'''
    out = ('5-ab|4\n'
           '5-ab/DG-007\n'
           'DG-001,DG-002,DG-003,\n'
           '0\n'
           '%\n'
           '  3.1|42    |+7\n'
           'eq\n'
           '10\n'
           '1024 0.500 1.25\n')
    prog('fmt6_basic',
         ['format returns a str: used in concatenation, with len, ==, as a printf argument and in a loop (W1\'s DG-%03d',
          'labels); the empty format, %% and mixed conversions (LANGUAGE.md 10.9, 11.1)'], body, out)

    body = TRACE + '''printf("%s\\n", format("%d %d %d", t(1, 10), t(2, 20), t(3, 30)))
printf("%s\\n", format("[%s]", format("%d", t(4, 5))))
printf("%s\\n", format("%s %s", format("%d", t(5, 1)), format("%d", t(6, 2))))
'''
    out = ('eval 1\neval 2\neval 3\n10 20 30\n'
           'eval 4\n[5]\n'
           'eval 5\neval 6\n1 2\n')
    prog('fmt6_order',
         ['the arguments of format evaluate left to right, also in nested format calls (LANGUAGE.md 6.8 rule 5, 11.1)'],
         body, out)

    body = '''var s = "ab"
for k in 0..10 {
    s = s + s
}
printf("%d\\n", len(s))
printf("%d\\n", len(format("%s", s)))
if format("%s", s) == s {
    printf("same\\n")
}
printf("%d\\n", len(format("%100000d", 5)))
printf("%d\\n", len(format("%.5000f", 1.0)))
printf("%d\\n", len(format("%-70000s|", "x")))
printf("[%s]\\n", format("%.3s", s))
'''
    out = '2048\n2048\nsame\n100000\n5002\n70001\n[aba]\n'
    prog('fmt6_big',
         ['format results of 2 KiB, 70 KB (past the 64 KiB output buffer) and 100 KB: lengths by LANGUAGE.md 11.1 (width',
          'counts bytes; %.5000f of 1.0 is "1." and 5000 zeros) and a str copied through %s'], body, out)

    body = '''print("[" + format("") + "]\\n")
print("[" + format("%s", "") + "]\\n")
print("[" + format("%5s", "") + "]\\n")
print("[" + format("%-5s", "") + "]\\n")
print("[" + format("%.0s", "abc") + "]\\n")
print("[" + format("%3s", "abcdef") + "]\\n")
printf("%d %d\\n", len(format("")), len(format("%.0s", "zz")))
'''
    out = '[]\n[]\n[     ]\n[     ]\n[]\n[abcdef]\n0 0\n'
    prog('fmt6_empty',
         ['empty results and padding of format: %s of "", width without argument bytes, precision 0, a width smaller than',
          'the argument (LANGUAGE.md 11.1)'], body, out)

    body = '''print(format("%s|", "\\xFF\\xFE\\x80"))
print(format("%4s|", "\\u{e9}"))
print(format("%-4s|", "\\u{20ac}"))
print(format("%.2s|", "\\u{1F600}"))
let z = format("%s", "a\\0b")
printf("%d\\n", len(z))
print(z)
print("\\n")
print(format("%s%s", "\\xC3", "\\xA9"))
print("\\n")
'''
    out = (b'\xff\xfe\x80|' + b'  \xc3\xa9|' + b'\xe2\x82\xac |' + b'\xf0\x9f|' + b'3\n' + b'a\x00b' + b'\n'
           + b'\xc3\xa9' + b'\n')
    prog('fmt6_bytes',
         ['%s of strings holding bytes 0x80-0xFF, UTF-8 text and a NUL: width and precision count bytes (so %4s of the two',
          'bytes of e-acute pads two spaces, %.2s of a 4-byte code point keeps its first two bytes); the str keeps a NUL',
          '(LANGUAGE.md 11.1 "s: the bytes", 3.5, 4.4)'], body, out)


def print_tests():
    body = '''print("hello")
print(", ")
print("world\\n")
print("a\\tb\\n")
let name = "str"
print(name)
print(" " + str(42) + "|" + str(-7) + "|" + str(1.5) + "|" + str(true) + "\\n")
print("no newline at the end")
'''
    out = 'hello, world\na\tb\nstr 42|-7|1.5|true\nno newline at the end'
    prog('print_basic',
         ['print writes the bytes of its str and nothing else: no newline is added, pieces join (LANGUAGE.md 11.2, 10.9)'],
         body, out)

    body = '''print("")
print("")
print("a")
print("")
let e = ""
print(e + e)
print("b\\n")
print(format(""))
printf("")
print("c\\n")
'''
    prog('print_empty', ['print of empty strings writes nothing (LANGUAGE.md 11.2)'], body, 'ab\nc\n')

    hi = ''.join('\\x%02X' % b for b in range(0x80, 0x100))
    lo = ''.join('\\x%02x' % b for b in range(0x01, 0x20) if b != 0x0A)
    body = ('print("%s\\n")\n' % hi + 'print("%s\\n")\n' % lo +
            'print("a\\0b\\n")\n'
            'print("\\u{e9} \\u{20ac} \\u{1F600}\\n")\n'
            'print("café ☕\\n")\n'
            'print("\\x7f\\x00\\n")\n')
    out = (bytes(range(0x80, 0x100)) + b'\n' + bytes(b for b in range(0x01, 0x20) if b != 0x0A) + b'\n'
           + b'a\x00b\n' + b'\xc3\xa9 \xe2\x82\xac \xf0\x9f\x98\x80\n' + 'café ☕\n'.encode('utf-8')
           + b'\x7f\x00\n')
    prog('print_bytes',
         ['print writes every byte of a str: 0x80-0xFF, the control bytes 0x01-0x1F, 0x7F, a NUL, UTF-8 from \\u{...} and',
          'raw UTF-8 in the source (LANGUAGE.md 11.2, 3.5, 3.1)'], body, out)

    body = '''printf("a")
print("b")
printf("%s", "c")
print("d\\n")
for k in 0..3000 {
    print("0123456789")
    printf("%s", "abcdefghij")
    print("xyz\\n")
}
printf("end\\n")
'''
    out = 'abcd\n' + '0123456789abcdefghijxyz\n' * 3000 + 'end\n'
    prog('print_mixed',
         ['print and printf share one buffer and interleave in program order, across the 64 KiB flush (72 000 bytes are',
          'written; LANGUAGE.md 11.2, 11.3; DESIGN.md 4.8 PRINT, L-cd)'], body, out)

    body = '''let big = format("%70000s", "x")
print(big)
print("\\n")
printf("%d\\n", len(big))
'''
    out = ' ' * 69999 + 'x\n' + '70000\n'
    prog('print_large',
         ['print of one 70 000-byte str (more than the 64 KiB buffer holds: written through, LANGUAGE.md 11.2, 11.3)'],
         body, out)


def mkdir_tests():
    body = '''make_dir("d")
make_dir("d")
make_dir("d")
printf("ok\\n")
'''
    prog('mkdir_twice',
         ['make_dir of the same path twice: an existing directory is not an error (LANGUAGE.md 10.10)'], body, 'ok\n')

    body = '''make_dir("d")
make_dir("d/e")
make_dir("d/e")
make_dir("d/e/f")
printf("nested\\n")
'''
    prog('mkdir_nested',
         ['make_dir("d") then make_dir("d/e") and "d/e/f": each succeeds only because its parent was created before (no',
          'parent is created: LANGUAGE.md 10.10); a failure would be "No such file or directory" and status 1'],
         body, 'nested\n')

    body = '''make_dir("/")
make_dir(".")
make_dir("./sub")
make_dir("./sub")
make_dir(".")
printf("done\\n")
'''
    prog('mkdir_root_dot',
         ['make_dir("/") and make_dir(".") name existing directories (no error on either target: DESIGN.md 4.8 MAKE_DIR',
          'tests the path for a directory after a failed mkdir), "./sub" is created once and found again'],
         body, 'done\n')

    body = '''make_dir("dir")
make_dir("dir/")
printf("kept\\n")
'''
    base = os.path.join(PROGRAMS, 'mkdir_existing_dir')
    prog('mkdir_existing_dir',
         ['make_dir of a directory that exists before the program starts (a fixture with a file inside): not an error, the',
          'file is untouched (LANGUAGE.md 10.10)'], body, 'kept\n')
    os.makedirs(base + '.files/dir', exist_ok=True)
    wbytes(base + '.files/dir/keep.txt', 'kept\n')

    body = '''for k in 0..10 {
    make_dir(format("d%d", k))
}
for k in 0..10 {
    make_dir(format("d%d/s", k))
}
for k in 0..10 {
    make_dir(format("d%d", k))
}
printf("%d\\n", 10)
'''
    prog('mkdir_many',
         ['ten directories created through format, a sub-directory in each (it exists only if the parent does), then all of',
          'the ten again (LANGUAGE.md 10.10, 10.9)'], body, '10\n')


# ---------------------------------------------------------------------------- run-time errors
def r_inl6():
    err_r('r_inl6_single_site',
          ['a run-time error inside a single-site inlined function with a loop reports the callee\'s line, not the call\'s',
           '(DESIGN.md 3.6.4 "Sites": inlined code keeps its own sites; LANGUAGE.md 9.2, 5.4)'],
          '''fn scan(v: i64[]) -> i64 {
    var s = 0
    for k in 0..4 {
        s += v[k]
    }
    return s
}
let a: i64[] = [1, 2, 3]
printf("start\\n")
printf("%d\\n", scan(a))
''', 's += v[k]', 'index 3 out of bounds for dimension 0 of extent 3', out=b'start\n')
    err_r('r_inl6_small_many',
          ['a small function called from two sites: the error is at the callee\'s line (LANGUAGE.md 6.6, 9.2)'],
          '''fn ratio(a: i64, b: i64) -> i64 {
    return a % b
}
printf("%d\\n", ratio(7, 3))
printf("%d\\n", ratio(7, 0))
''', 'return a % b', 'integer division by zero', out=b'1\n')
    err_r('r_inl6_nested',
          ['an error in the inner function of two nested inlined calls is at the inner function\'s line (LANGUAGE.md 6.5)'],
          '''fn inner(x: i64) -> i64 {
    return 1000000000000 * x * x
}
fn outer(x: i64) -> i64 {
    return inner(x) + 1
}
printf("%d\\n", outer(3))
printf("%d\\n", outer(100000))
''', 'return 1000000000000 * x * x', 'integer overflow', out=b'9000000000001\n')
    err_r('r_inl6_ref_param',
          ['an element store through a ref parameter of an inlined function: the callee\'s line (LANGUAGE.md 8.3, 5.4)'],
          '''fn store(ref v: f64[], k: i64) {
    v[k] = 1.0
}
var a: f64[] = [0.0, 0.0]
store(ref a, 1)
printf("%g %g\\n", a[0], a[1])
store(ref a, 2)
''', 'v[k] = 1.0', 'index 2 out of bounds for dimension 0 of extent 2', out=b'0 1\n')
    err_r('r_inl6_error_stmt',
          ['error() inside an inlined function: its own line (LANGUAGE.md 9.3: the location is the error call)'],
          '''fn check(x: i64) -> i64 {
    if x < 0 {
        error("negative: %d", x)
    }
    return x
}
printf("%d\\n", check(1))
printf("%d\\n", check(-4))
''', 'error("negative', 'negative: -4', out=b'1\n')
    err_r('r_inl6_conv',
          ['i64(x) of a non-integral value inside an inlined function: the callee\'s line (LANGUAGE.md 4.2, 9.2)'],
          '''fn whole(x: f64) -> i64 {
    return i64(x)
}
printf("%d\\n", whole(4.0))
printf("%d\\n", whole(2.5))
''', 'return i64(x)', 'conversion to i64: 2.5 is not an integer', out=b'4\n')
    err_r('r_inl6_arg_error',
          ['an argument expression that fails belongs to the caller: its own line even when the callee is inlined (the',
           'call is on line 8 here, the callee is lines 2 to 4; DESIGN.md 3.6.4 "Sites")'],
          '''fn id(x: i64) -> i64 {
    return x
}
let a: i64[] = [1, 2]
printf("%d\\n", id(a[1]))
printf("%d\\n", id(a[5]))
''', 'id(a[5])', 'index 5 out of bounds for dimension 0 of extent 2', out=b'2\n')
    err_r('r_inl6_deferred_oob',
          ['the deferred ref argument of rule 31: addat(ref v[2], shrink(ref v)) checks v[2] at its place (ok, 3 elements),',
           'shrink then replaces v by a 1-element array, and the recheck before the call fails with the CALL\'s line (the',
           'argument path belongs to the caller; DESIGN.md 3.6.6 rule 31, R31)'],
          '''fn addat(ref x: f64, k: i64) {
    x += f64(k)
}
fn shrink(ref v: f64[]) -> i64 {
    v = zeros(1)
    return 1
}
var v: f64[] = [1.0, 2.0, 3.0]
printf("before\\n")
addat(ref v[2], shrink(ref v))
printf("after\\n")
''', 'addat(ref v[2]', 'index 2 out of bounds for dimension 0 of extent 1', out=b'before\n')
    err_r('r_inl6_multiline_call',
          ['a call written over several lines whose inlined callee fails: the callee\'s line (DESIGN.md 3.6.4)'],
          '''fn quot(a: i64,
        b: i64) -> i64 {
    return a % b
}
let r = quot(1,
             3)
printf("%d\\n", r)
let q = quot(1,
             0)
''', 'return a % b', 'integer division by zero', out=b'1\n')
    err_r('r_inl6_default_arg',
          ['an omitted default and a named argument reach an inlined callee that fails at its own line (LANGUAGE.md 8.1)'],
          '''fn rem(a: i64, b: i64 = 0) -> i64 {
    return a % b
}
printf("%d\\n", rem(7, b: 4))
printf("%d\\n", rem(5))
''', 'return a % b', 'integer division by zero', out=b'3\n')
    err_r('r_inl6_loop_in_caller',
          ['an inlined small function called in a loop of the caller fails on a later iteration: the output of the earlier',
           'iterations is flushed first, the line is the callee\'s (LANGUAGE.md 9.2)'],
          '''fn inv(k: i64) -> i64 {
    return 12 % k
}
for k in 3..=0 step -1 {
    printf("%d\\n", inv(k))
}
''', 'return 12 % k', 'integer division by zero', out=b'0\n0\n0\n')


def r_mkdir_print():
    err_r('r_mkdir_file_exists',
          ['make_dir of a path that is an existing file (a fixture): "File exists", status 1 (LANGUAGE.md 10.10, 9.2;',
           'DESIGN.md 4.8 MAKE_DIR: the saved errno, the path is not a directory)'],
          '''printf("before\\n")
make_dir("x")
printf("after\\n")
''', 'make_dir("x")', "cannot create directory 'x': File exists", out=b'before\n', files={'x': b'data\n'})
    err_r('r_mkdir_missing_parent',
          ['make_dir of a path whose parent does not exist: no parent is created, "No such file or directory" (LANGUAGE.md',
           '10.10); output printed before it is flushed first'],
          '''printf("start\\n")
make_dir("nodir/sub")
printf("never\\n")
''', 'make_dir("nodir/sub")', "cannot create directory 'nodir/sub': No such file or directory", out=b'start\n')
    err_r('r_mkdir_parent_is_file',
          ['make_dir below a path that is a file: "Not a directory" (LANGUAGE.md 10.10: any other failure)'],
          '''make_dir("x/y")
''', 'make_dir("x/y")', "cannot create directory 'x/y': Not a directory", files={'x': b'data\n'})
    err_r('r_mkdir_empty_path',
          ['make_dir("") fails like mkdir("") on both targets: "No such file or directory" (LANGUAGE.md 10.10: any other',
           'failure; unsure: the spec names no empty path, both libcs give ENOENT)'],
          '''make_dir("")
''', 'make_dir("")', "cannot create directory '': No such file or directory")
    err_r('r_mkdir_second_fails',
          ['the first make_dir creates "d", the second names a missing grandparent: the error names its own path',
           '(LANGUAGE.md 10.10, 9.2)'],
          '''make_dir("d")
printf("created\\n")
make_dir("a/b/c")
''', 'make_dir("a/b/c")', "cannot create directory 'a/b/c': No such file or directory", out=b'created\n')
    err_r('r_print_flush',
          ['print writes no newline: a run-time error flushes standard output as it is, with no extra newline, then reports',
           '(LANGUAGE.md 9.2 step 1, 11.2)'],
          '''print("partial")
error("boom")
''', 'error("boom")', 'boom', out=b'partial')


# ---------------------------------------------------------------------------- compile errors
F1 = '''fn f(a: i64) -> i64 {
    return a
}
'''


def err_call6():
    err_c('err_call6_unknown_user',
          ['a name the function does not take is 224 at the narg (LANGUAGE.md 8.1; DESIGN.md 2.11.2)'],
          F1 + 'printf("%d\\n", f(1, zz: 2))\n', 'f(1, zz: 2)', 'zz', 'unknown parameter')
    err_c('err_call6_unknown_only_named',
          ['a call whose only argument is an unknown name: 224 at the narg, before the missing argument of the call'],
          F1 + 'printf("%d\\n", f(zz: 2))\n', 'f(zz: 2)', 'zz', 'unknown parameter')
    err_c('err_call6_unknown_lib',
          ['sqrt(x: 2.0): a library function\'s positional parameter is not a name: 224 at the narg (DESIGN.md 2.11.2, L-by)'],
          'let r = sqrt(x: 2.0)\n', 'sqrt(x: 2.0)', 'x:', 'unknown parameter')
    err_c('err_call6_unknown_prel',
          ['linspace(0.0, 1.0, m: 3): a prelude function takes the names of LANGUAGE.md 10.3 only: 224 at the narg'],
          'let v = linspace(0.0, 1.0, m: 3)\n', 'linspace(0.0', 'm:', 'unknown parameter')
    err_c('err_call6_twice_pos',
          ['a parameter given positionally and by name: 225 at the narg (LANGUAGE.md 8.1)'],
          F1 + 'printf("%d\\n", f(1, a: 2))\n', 'f(1, a: 2)', 'a:', 'parameter given twice', col_off=0)
    err_c('err_call6_twice_named',
          ['a name given twice: 225 at the second narg'],
          F1 + 'printf("%d\\n", f(a: 1, a: 2))\n', 'f(a: 1, a: 2)', 'a: 2', 'parameter given twice')
    err_c('err_call6_twice_prel',
          ['linspace(0.0, 1.0, 3, n: 2): n is given positionally and by name: 225 at the narg'],
          'let v = linspace(0.0, 1.0, 3, n: 2)\n', 'linspace(0.0', 'n:', 'parameter given twice')
    err_c('err_call6_missing_skip',
          ['a parameter without a default skipped by name: 226 at the call (LANGUAGE.md 8.1: b is neither given nor defaulted)'],
          '''fn f(a: i64, b: i64, c: i64 = 0) -> i64 {
    return a + b + c
}
printf("%d\\n", f(1, c: 3))
''', 'f(1, c: 3)', 'f(1', 'missing argument')
    err_c('err_call6_default_order',
          ['a parameter after one with a default must have a default: 236 at the param node (its name; LANGUAGE.md 8.1)'],
          '''fn f(a: i64 = 1, b: i64) -> i64 {
    return a + b
}
printf("%d\\n", f(1, 2))
''', 'fn f(a: i64 = 1', 'b: i64)', 'parameter needs a default value')
    err_c('err_call6_ref_default',
          ['a ref parameter cannot have a default: 227 at the default expression (LANGUAGE.md 8.1; DESIGN.md 2.11.2, L-bw)'],
          '''fn f(ref x: i64 = 1) {
    x += 1
}
var v = 0
f(ref v)
''', 'fn f(ref x', '1)', 'ref argument must be a mutable variable, element or field')
    err_c('err_call6_ref_named',
          ['a named argument for a ref parameter: 254 at its value, "name: ref x" does not parse (Decision 93, LANGUAGE.md 8.1)'],
          '''fn bump(ref x: i64) {
    x += 1
}
var v = 0
bump(x: v)
''', 'bump(x: v)', 'v)', "argument for ref parameter 'x' must be marked ref")
    err_c('err_call6_default_not_const',
          ['a default that is not a constant expression: 237 at the call node (seacheck, as a const item\'s value; Decision 91)'],
          '''fn f(a: f64 = now()) -> f64 {
    return a
}
printf("%g\\n", f(1.0))
''', 'fn f(a: f64', 'now()', 'not a constant expression')
    err_c('err_call6_default_type',
          ['a default of the wrong type: 201 at the default expression (as a const item annotated with the parameter\'s type)'],
          '''fn f(a: i64 = 1.5) -> i64 {
    return a
}
printf("%d\\n", f(1))
''', 'fn f(a: i64', '1.5', 'type mismatch: expected i64, found f64')
    err_c('err_call6_default_type_str',
          ['a str parameter with an integer default: 201 at the default'],
          '''fn f(s: str = 5) {
    printf("%s\\n", s)
}
f("a")
''', 'fn f(s: str', '5)', 'type mismatch: expected str, found i64')
    err_c('err_call6_default_overflow',
          ['a default whose i64 evaluation overflows: 260 at the operator node (its left operand), as for a const item'],
          '''fn f(a: i64 = 9223372036854775807 + 1) -> i64 {
    return a
}
printf("%d\\n", f(1))
''', 'fn f(a: i64', '9223372036854775807', 'integer overflow')
    err_c('err_call6_default_divzero',
          ['a default that divides by zero: 261 at the operator node (its left operand)'],
          '''fn f(a: i64 = 7 % (2 - 2)) -> i64 {
    return a
}
printf("%d\\n", f(1))
''', 'fn f(a: i64', '7 %', 'integer division by zero')
    err_c('err_call6_default_undeclared',
          ['a default that names an undeclared name: 200 at the name'],
          '''fn f(a: i64 = ZZ) -> i64 {
    return a
}
printf("%d\\n", f(1))
''', 'fn f(a: i64', 'ZZ', "undeclared name 'ZZ'")
    err_c('err_call6_default_const_order',
          ['Decision 91: a default\'s error on a later line than a constant item\'s error loses; the constant\'s 260 on line 2',
           'is reported, not the default\'s 201 on line 3 (DESIGN.md 2.11.2: every error competes in source order)'],
          '''const A = 9223372036854775807 + 1
fn f(a: i64 = 1.5) -> i64 {
    return a
}
printf("%d\\n", f(1))
''', 'const A', '9223372036854775807', 'integer overflow')
    err_c('err_call6_default_const_order2',
          ['the reverse: a default\'s 201 on line 2 comes before a constant item\'s 260 on line 5 and is reported'],
          '''fn f(a: i64 = 1.5) -> i64 {
    return a
}
printf("%d\\n", f(1))
const A = 9223372036854775807 + 1
''', 'fn f(a: i64', '1.5', 'type mismatch: expected i64, found f64')
    err_c('err_call6_order_value_first',
          ['the arguments are checked in source order, each value before its narg: the type mismatch of a: "x" (201, line 5)',
           'comes before the unknown name zz after it (224)'],
          F1 + 'printf("%d\\n", f(a: "x", zz: 1))\n', 'f(a: "x"', '"x"', 'type mismatch: expected i64, found str')
    err_c('err_call6_order_narg_first',
          ['the unknown name zz comes first in source order: 224 at it, before the mismatch of a: "x" after it'],
          F1 + 'printf("%d\\n", f(zz: 1, a: "x"))\n', 'f(zz: 1', 'zz', 'unknown parameter')
    # 243: print, make_dir, format with the wrong arguments (LANGUAGE.md 10.9, 10.10, 11.2; DESIGN.md 2.11.2)
    err_c('err_call6_print_i64',
          ['print takes one str: 243 at the call, the arguments\' types written (DESIGN.md 2.6.2)'],
          'print(5)\n', 'print(5)', 'print(5)', "no overload of 'print' accepts (i64)")
    err_c('err_call6_print_two',
          ['print of two arguments: 243'],
          'print("a", "b")\n', 'print("a"', 'print(', "no overload of 'print' accepts (str, str)")
    err_c('err_call6_print_none',
          ['print without an argument: 243'],
          'print()\n', 'print()', 'print(', "no overload of 'print' accepts ()")
    err_c('err_call6_mkdir_i64',
          ['make_dir takes one str: 243 at the call'],
          'make_dir(3)\n', 'make_dir(3)', 'make_dir(', "no overload of 'make_dir' accepts (i64)")
    err_c('err_call6_mkdir_two',
          ['make_dir of two arguments: 243'],
          'make_dir("a", "b")\n', 'make_dir("a"', 'make_dir(', "no overload of 'make_dir' accepts (str, str)")
    # format as a formatting call (DESIGN.md 2.6.2 "Within one formatting call")
    err_c('err_call6_format_arg',
          ['format checks its arguments like printf: %d of a str is 210 at the argument (LANGUAGE.md 11.1, 9.1)'],
          'let s = format("%d", "x")\n', 'format("%d"', '"x"', 'format "%d" expects an integer or f64, found str')
    err_c('err_call6_format_count',
          ['format with fewer arguments than conversions: 211 at the call (LANGUAGE.md 11.1)'],
          'let s = format("%d %d", 1)\n', 'format("%d %d"', 'format(', 'format "%d %d" expects 2 arguments, found 1')
    err_c('err_call6_format_literal',
          ['the format of format must be a string literal: 233 at the argument (LANGUAGE.md 11.1)'],
          'let fm = "%d"\nlet s = format(fm, 1)\n', 'format(fm', 'fm,', 'format must be a string literal')
    err_c('err_call6_format_bad',
          ['an unknown conversion in format: 234 at the literal (LANGUAGE.md 11.1)'],
          'let s = format("%q", 1)\n', 'format("%q"', '"%q"', 'invalid format conversion "%q"')
    err_c('err_call6_format_bad_flag',
          ['# with %d is undefined in C and an error in Sea: 234 at the literal, the conversion written through its letter'],
          'let s = format("%#d", 1)\n', 'format("%#d"', '"%#d"', 'invalid format conversion "%#d"')


def ns_golden():
    err_c('err_ns_lib_write_json',
          ['write_json is the phase-rule word until 6d: "not supported yet: write_json" at the call (DESIGN.md 2.11.2: the',
           'library-names row loses format, print and make_dir in 6b and write_json in 6d)'],
          'write_json("out.json", 1.5)\n', 'write_json(', 'write_json(', 'not supported yet: write_json')


def l_by_rederived():
    """The five goldens whose name a library function does not take: 224 at the same narg."""
    def put(name, src, err):
        wbytes(os.path.join(ERRORS, name + '.sea'), src)
        wbytes(os.path.join(ERRORS, name + '.err'), err)
        wbytes(os.path.join(ERRORS, name + '.status'), '1\n')
    put('err_find_desc_unknown',
        '// err_find_desc_unknown -- find(m, desc: true): find takes no named argument: unknown parameter (224, L-by) at the narg\n'
        'let m: bool[] = [true]\n'
        'let r = find(m, desc: true)\n',
        'err_find_desc_unknown.sea:3:17: error: unknown parameter\n')
    put('err_red_argmax_dim',
        '// err_red_argmax_dim -- argmax(A, dim: 0): argmax takes no dim:, so unknown parameter (224, L-by) at the narg,\n'
        '// never 243 (LANGUAGE.md 10.5, DESIGN.md 2.11.2)\n'
        'let v: f64[] = [1.0, 2.0]\n'
        'let A: f64[,] = [1.0, 2.0; 3.0, 4.0]\n'
        'let k = argmax(A, dim: 0)\n',
        'err_red_argmax_dim.sea:5:19: error: unknown parameter\n')
    put('err_red_desc_unknown',
        '// err_red_desc_unknown -- sum(v, desc: true): desc is not a name of sum: unknown parameter (224, L-by)\n'
        '// at the narg (DESIGN.md 2.11.2)\n'
        'let v: f64[] = [1.0, 2.0]\n'
        'let A: f64[,] = [1.0, 2.0; 3.0, 4.0]\n'
        'let s = sum(v, desc: true)\n',
        'err_red_desc_unknown.sea:5:16: error: unknown parameter\n')
    put('err_red_desc_twice_unknown',
        '// err_red_desc_twice_unknown -- a repeated name the function does not take is unknown parameter (224, L-by) at its\n'
        '// first narg, which precedes the second one\'s 225 (DESIGN.md 2.11.2)\n'
        'let v: f64[] = [1.0, 2.0]\n'
        'let A: f64[,] = [1.0, 2.0; 3.0, 4.0]\n'
        'let s = sum(v, desc: true, desc: true)\n',
        'err_red_desc_twice_unknown.sea:5:16: error: unknown parameter\n')
    put('err_sort_dim_unknown',
        '// err_sort_dim_unknown -- sort(v, dim: 0): dim is not a name of sort: unknown parameter (224, L-by) at the narg\n'
        'let v: f64[] = [1.0, 2.0]\n'
        'let A: f64[,] = [1.0, 2.0; 3.0, 4.0]\n'
        'let s = sort(v, dim: 0)\n',
        'err_sort_dim_unknown.sea:4:17: error: unknown parameter\n')


def retire():
    for name in ('err_ns_named_arg', 'err_ns_default_arg', 'err_ns_f64_mod', 'err_ns_lib_format', 'err_prel_named'):
        for ext in ('.sea', '.err', '.status'):
            remove(os.path.join(ERRORS, name + ext))


def main():
    retire()
    l_by_rederived()
    call6_named()
    call6_named_types()
    call6_defaults()
    call6_defaults_named()
    call6_default_ref()
    call6_defaults_const_late()
    call6_default_recursive()
    call6_prel()
    inl_single_loop()
    inl_many_calls()
    inl_nested()
    inl_recursive_stays()
    inl_mutual_single()
    inl_ref_scalar()
    inl_ref_elem()
    inl_ref_array()
    inl_result_struct()
    inl_result_fixed()
    inl_return_multi()
    inl_calls_prelude()
    inl_two_sites_unreachable()
    inl_stmt_forms()
    inl_strings()
    inl_array_params()
    inl_eval_order()
    inl_hygiene()
    inl_return_branches()
    inl_void()
    inl_conditional_context()
    fmt6_from_progfmt()
    fmt6_from_files()
    fmt6_misc()
    print_tests()
    mkdir_tests()
    r_inl6()
    r_mkdir_print()
    err_call6()
    ns_golden()
    print('call6_cases: %d programs, %d errors written; 5 goldens re-derived, 5 retired or moved'
          % (COUNT['programs'], COUNT['errors']))


if __name__ == '__main__':
    main()
