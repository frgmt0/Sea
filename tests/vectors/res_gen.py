"""Spec oracle for sea.res (DESIGN.md 3.4.1): turns a hand-derived sea.ast golden into its sea.res.

Run with `timeout 120 uv run python tests/vectors/res_gen.py [NAME...]` (default: every
tests/passes/NAME.ast that has a NAME.hir1, plus the res_* and rs tests). It writes
tests/passes/NAME.res. This is a second, independent reading of 3.4.1 (and of the scope rules of
LANGUAGE.md 3.3, 7.2, 7.5, the typing rules of 4.2 and 6, and the error table of DESIGN.md 2.6.2
for the declaration checks), written in Python from the spec only; it never runs the compiler.
Where a NAME.hir1 golden exists (itself derived by hand from 3.5), the script cross-checks what
the two files share: the lids of the declared locals (rpname/rfor against the loc records, by
name and position), every constant's value (rcni/rcnf/rcnb against the cn leaf), and the powk
decisions (each rpowk position must be a powk record of the hir1 and vice versa).

Decision 25 as refined (3.4.1 rule 2, 3.5.2): a call in a constant is evaluated only when its
callee is an `rname pd` naming pow or sqrt, so a call of a function item (also one the program
names pow or sqrt) makes the constant rcn, and so does naming such a constant; `&&`/`||` cannot
rescue it, because the whole expression is typed (static_kind) before it is evaluated.

Sub-phase 4d (3.4.2): every type node of an entered item and of a resolved region is an `rtype`
with its type (its dims resolved: rint, rname), after the constants; the type table holds the
rtvec/rtmat/rtup records in the order of creation of 3.4.2 (field types, signatures with a
tuple after its components, then every other rtype in file order); a type with an error is 0
and creates nothing; the phase rule of step 4d reports fixed-size array types (`arrays`), struct
types (`structs`) and handle types at the type node, a `str` parameter at its param node (type
0), a `str` result at its type node; a `for` over a vector is a resolved region.

Sub-phase 4g-1 (3.4.2 "`str` constants", lead decisions L-f and L-g): a constant whose value is a
`str` (a string literal, a constant naming one, `+` of such) is `rcns` with its bytes; a
comparison of two `str` constant expressions is a `bool` constant expression, byte-wise and
unsigned with a proper prefix the smaller (Python's bytes order is exactly that), so its constant
is `rcnb`; every `str` value computed while a constant is evaluated (a literal, a named constant,
each `+`) has at most SEA_LIM_LINE_BYTES bytes, a longer one being `program too large: strings`
at the constant's item, reported by seaname at once (status 10: the Capacity exception, no
sea.res is written). These evaluation rules hold in every step (no earlier golden has a `str`
constant); the phase-rule step 4g-1 itself (a `match` resolved, `str` in signatures) is applied
by the callers that patch this oracle (dump4g_cases.res_gen4g1), as step 4e is by dump4e_cases.
"""

import os
import sys
from fractions import Fraction

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import math_model as mm  # noqa: E402
from float_oracle import i_to_f  # noqa: E402
# IEEE binary64 with +-inf and NaN (DESIGN.md 2.8 NaN bits): the exact ops of f64emu.py
from f64emu import f_add, f_div, f_mul, f_sub  # noqa: E402
from f64emu import f_cmp as fe_cmp, f_mod as fe_mod, f_sqrt  # noqa: E402

PASSES = os.path.join(os.path.dirname(HERE), 'passes')
SIGN = 1 << 63
M64 = (1 << 64) - 1
I64_MIN, I64_MAX = -(1 << 63), (1 << 63) - 1
LIM_POWK = 4                      # SEA_LIM_POWK (include/limits.inc)
CONST_POWK, CONST_POWK_POS = set(), set()
# the tree is walked recursively; a 2000-deep else-if chain (stmt_else_if_2000) needs more than
# the default limit
sys.setrecursionlimit(200000)
PREDECLARED = set('''pi inf nan eps Figure Axes Lu Chol
abs all any args argmax argmin argsort axis_equal bar barh bincount ceil chol cols contour cos
eig_sym error exp figure filled find find_first find_last floor format grid hypot idiv image
ind2sub isnan legend len linspace log lower lu make_dir max mean meshgrid min nnz now numel ones
panel plot pow print printf rcond round rows save_svg setdiff sign sin solve sort sqrt std str
sub2ind sum title trunc twin_y variance where write_json x_ticks xlabel xline xlim y_reverse
y_ticks ylabel ylim zeros'''.split())
SCALAR_TY = {'bool': 2, 'i64': 3, 'f64': 4}
HANDLE_TY = {'Figure': 6, 'Axes': 7, 'Lu': 8, 'Chol': 9}
LIM_FIXED_ELEMS = 256             # SEA_LIM_FIXED_ELEMS (include/limits.inc)
LIM_LINE_BYTES = 4096             # SEA_LIM_LINE_BYTES (include/limits.inc): L-f's bound
F_CONST = {'pi': 0x400921FB54442D18, 'inf': 0x7FF0000000000000, 'nan': 0x7FF8000000000000,
           'eps': 0x3CB0000000000000}


# ---------------------------------------------------------------- field encodings (3.1)
def dec_i(t):
    if t.startswith('#'):
        v = int(t[1:], 16)
        return v - (1 << 64) if v >= SIGN else v
    return int(t)


def enc_i(v):
    if -10 ** 9 < v < 10 ** 9:
        return str(v)
    return '#%016X' % (v & M64)


def enc_f(b):
    return '#%016X' % b


def esc(s):
    return esc_b(s.encode())


def esc_b(b):
    """3.1 string escaping of a byte string: 0x21-0x7E except `%` as themselves, every other byte
    `%XX`; the empty string is the field `%` alone."""
    out = []
    for ch in b:
        out.append(chr(ch) if 0x21 <= ch <= 0x7E and ch != 0x25 else '%%%02X' % ch)
    return ''.join(out) if out else '%'


def unesc(t):
    """The bytes of an escaped string field (3.1): `%` alone is empty, `%XX` one byte."""
    if t == '%':
        return b''
    out, k = bytearray(), 0
    while k < len(t):
        if t[k] == '%':
            out.append(int(t[k + 1:k + 3], 16))
            k += 3
        else:
            out.append(ord(t[k]))
            k += 1
    return bytes(out)


class Capacity(Exception):
    """A capacity limit seaname reports at once (status 10, DESIGN.md 2.6.2 `here`): no sea.res."""

    def __init__(self, pos, word):
        Exception.__init__(self, 'program too large: %s at %s' % (word, pos))
        self.pos, self.word = pos, word


# ---------------------------------------------------------------- the tree of sea.ast (3.4)
def pops(op, f):
    g = lambda i: int(f[i])  # noqa: E731
    return {
        'prog': lambda: g(0), 'const': lambda: 1 + g(2), 'struct': lambda: g(2),
        'field': lambda: 1, 'fn': lambda: g(3) + g(4) + 1, 'param': lambda: 1 + g(3),
        'type': lambda: g(3), 'let': lambda: 2 + g(1), 'var': lambda: 2 + g(1),
        'ptuple': lambda: g(1), 'asg': lambda: 2, 'tasg': lambda: g(1) + 1, 'cstmt': lambda: 1,
        'if': lambda: 2 + g(1), 'while': lambda: 2, 'for': lambda: 2, 'match': lambda: g(1) + 1,
        'arm': lambda: g(1) + 1, 'return': lambda: g(1), 'block': lambda: g(1),
        'neg': lambda: 1, 'not': lambda: 1, 'bin': lambda: 2, 'call': lambda: g(1) + 1,
        'narg': lambda: 1, 'ref': lambda: 1, 'conv': lambda: 1, 'index': lambda: g(1) + 1,
        'range': lambda: 2 + g(2), 'rangev': lambda: 1, 'dot': lambda: 1, 'array': lambda: g(1),
        'row': lambda: g(1), 'slit': lambda: g(2), 'rlit': lambda: g(1), 'init': lambda: 1,
        'ifx': lambda: 3,
    }.get(op, lambda: 0)()


class Node:
    __slots__ = ('op', 'f', 'kids', 'rop', 'rf')

    def __init__(self, op, f, kids):
        self.op, self.f, self.kids = op, f, kids
        self.rop, self.rf = None, None          # replacement opcode and fields

    @property
    def pos(self):
        return self.f[0]


def read_ast(path):
    with open(path) as fh:
        lines = fh.read().split('\n')
    assert lines[-1] == '' and lines[-2] == '#end', path
    head = [ln for ln in lines if ln.startswith('#')][:-1]
    stack = []
    for ln in lines:
        if not ln or ln.startswith('#'):
            continue
        p = ln.split(' ')
        op, f = p[0], p[1:]
        n = pops(op, f)
        kids = stack[len(stack) - n:] if n else []
        del stack[len(stack) - n:]
        stack.append(Node(op, f, kids))
    assert len(stack) == 1 and stack[0].op == 'prog', path
    return head, stack[0]


def walk(n):
    """All nodes of a subtree in file (post-) order."""
    for k in n.kids:
        yield from walk(k)
    yield n


def emit(n, out):
    for k in n.kids:
        emit(k, out)
    if n.op == 'prog':
        out.append('prog ' + n.f[0])
    else:
        out.append(' '.join([n.rop or n.op] + (n.rf if n.rf is not None else n.f)))


# ---------------------------------------------------------------- typed constant evaluation
class Fail(Exception):
    """An evaluation that fails at run time: ovf or div0 at an operator."""

    def __init__(self, kind, pos):
        Exception.__init__(self, kind)
        self.kind, self.pos = kind, pos


def is_exact_f(v):
    return v == 0 or ((-(1 << 1024) < v < (1 << 1024))
                      and Fraction(f_val(i_to_f(v))) == v)


def f_val(b):
    """Exact value of finite f64 bits as a Fraction."""
    s = -1 if b & SIGN else 1
    e = (b >> 52) & 0x7FF
    m = b & ((1 << 52) - 1)
    if e == 0:
        return s * Fraction(m, 1 << 1074)
    return s * Fraction(m | (1 << 52)) * Fraction(2) ** (e - 1075)


def f_is_nan(b):
    return (b & 0x7FFFFFFFFFFFFFFF) > 0x7FF0000000000000


def f_is_inf(b):
    return (b & 0x7FFFFFFFFFFFFFFF) == 0x7FF0000000000000


class Ctx:
    """Per-file state for the evaluation of constants and exponents."""

    def __init__(self):
        self.cvals = {}       # cid -> ('i'|'f'|'b'|'s', value) for constants that have a value
        self.item_pos = None  # the constant being evaluated (L-f reports at its item)


def static_kind(n, ctx):
    """'u' (an untyped integer constant expression), 'i', 'f', 'b', 's' (a `str`, 4g-1), or None
    when seaname cannot type it (3.4.1 'Constants': only literals, true/false, neg, not, bin,
    names of constants or of pi inf nan eps, calls of pow and sqrt with positional arguments;
    3.4.2: `+` of two `str` is a `str`, a comparison of two `str` a `bool`, L-g)."""
    op = n.op
    if op == 'int':
        return 'u'
    if op == 'float':
        return 'f'
    if op == 'str':
        return 's'
    if op in ('true', 'false'):
        return 'b'
    if op == 'name':
        k, ref = n.rf[2], n.rf[3]
        if k == 'cst':
            v = ctx.cvals.get(int(ref))
            return v[0] if v else None
        if k == 'pd' and n.f[1] in F_CONST:
            return 'f'
        return None
    if op == 'neg':
        k = static_kind(n.kids[0], ctx)
        return k if k in ('u', 'i', 'f') else None
    if op == 'not':
        return 'b' if static_kind(n.kids[0], ctx) == 'b' else None
    if op == 'bin':
        o = n.f[1]
        a, b = static_kind(n.kids[0], ctx), static_kind(n.kids[1], ctx)
        if a is None or b is None:
            return None
        num = ('u', 'i', 'f')
        if a == 's' or b == 's':
            # LANGUAGE.md 4.4, 6.4: `+` and the six comparisons of two str (L-g); every other
            # operator, and a str with a non-str operand, is not typable here (240 in seacheck)
            if a == b == 's':
                if o == 'add':
                    return 's'
                if o in ('eq', 'ne', 'lt', 'le', 'gt', 'ge'):
                    return 'b'
            return None
        if o in ('add', 'sub', 'mul'):
            if a in num and b in num:
                if 'f' in (a, b):
                    return 'f'
                return 'u' if a == b == 'u' else 'i'
            return None
        if o == 'div':
            return 'f' if a in num and b in num else None
        if o == 'mod':
            if a in num and b in num:
                return 'f' if 'f' in (a, b) else 'i'
            return None
        if o == 'pow':
            return 'f' if a in num and b in num else None
        if o in ('eq', 'ne', 'lt', 'le', 'gt', 'ge'):
            if a in num and b in num:
                return 'b'
            if a == b == 'b' and o in ('eq', 'ne'):
                return 'b'
            return None
        if o in ('and', 'or', 'band', 'bor'):
            return 'b' if a == b == 'b' else None
        return None
    if op == 'call':
        callee, args = n.kids[0], n.kids[1:]
        if callee.op != 'name' or callee.rf is None or callee.rf[2] != 'pd':
            return None
        if any(a.op in ('narg', 'ref') for a in args):
            return None
        want = {'pow': 2, 'sqrt': 1}.get(callee.f[1])
        if want is None or len(args) != want:
            return None
        if all(static_kind(a, ctx) in ('u', 'i', 'f') for a in args):
            return 'f'
        return None
    return None


def to_f(kind, v):
    """An i64/untyped value as f64 bits (rounded, LANGUAGE.md 4.2)."""
    return v if kind == 'f' else i_to_f(v)


def ev(n, ctx, fctx):
    """Evaluate a node whose static kind is not None; fctx: an untyped subexpression is in an
    f64 context (LANGUAGE.md 4.2 (a)-(e)). Returns (kind, value) with kind 'i', 'f' or 'b'."""
    op = n.op
    if op == 'int':
        v = dec_i(n.f[1])
        if v < 0:
            v += 1 << 64                     # 2^63 is written #8000000000000000
        if fctx:
            return ('f', i_to_f(v))
        return ('i', v)                      # range checked by the consumer (neg allows 2^63)
    if op == 'float':
        return ('f', dec_i(n.f[1]) & M64)
    if op == 'str':
        return ('s', str_val(unesc(n.f[1]), ctx))
    if op in ('true', 'false'):
        return ('b', 1 if op == 'true' else 0)
    if op == 'name':
        if n.rf[2] == 'cst':
            v = ctx.cvals[int(n.rf[3])]
            if v[0] == 's':
                str_val(v[1], ctx)               # L-f: the value of a named constant
            return v
        return ('f', F_CONST[n.f[1]])
    if op == 'neg':
        k, v = ev(n.kids[0], ctx, fctx)
        if k == 'f':
            return ('f', v ^ SIGN)
        r = -v
        if r < I64_MIN or r > I64_MAX:
            raise Fail('ovf', n.pos)
        return ('i', r)
    if op == 'not':
        return ('b', 1 - ev(n.kids[0], ctx, fctx)[1])
    if op == 'call':
        name = n.kids[0].f[1]
        vals = [ev(a, ctx, True) for a in n.kids[1:]]
        vals = [to_f(k, v) for k, v in vals]
        if name == 'sqrt':
            return ('f', f_sqrt(vals[0]))
        return ('f', mm.eval_bits('pow', vals))
    # bin
    o = n.f[1]
    sk = static_kind(n, ctx)
    ka, kb = static_kind(n.kids[0], ctx), static_kind(n.kids[1], ctx)
    if o in ('and', 'or'):
        a = ev(n.kids[0], ctx, fctx)[1]
        if (o == 'and' and a == 0) or (o == 'or' and a == 1):
            return ('b', a)
        return ('b', ev(n.kids[1], ctx, fctx)[1])
    if o in ('band', 'bor'):
        a = ev(n.kids[0], ctx, fctx)[1]
        b = ev(n.kids[1], ctx, fctx)[1]
        return ('b', (a & b) if o == 'band' else (a | b))
    if o == 'pow':
        a = to_f(*ev(n.kids[0], ctx, True))
        k = powk_of(n.kids[1], ctx)
        if k is not None:
            return ('f', powk_mul(a, k))
        b = to_f(*ev(n.kids[1], ctx, True))
        return ('f', mm.eval_bits('pow', [a, b]))
    if o in ('eq', 'ne', 'lt', 'le', 'gt', 'ge') and ka == kb == 'b':
        a, b = ev(n.kids[0], ctx, fctx)[1], ev(n.kids[1], ctx, fctx)[1]
        return ('b', int((a == b) == (o == 'eq')))
    if ka == kb == 's':
        # 3.4.2: `+` concatenates (L-f on the result); a comparison is byte-wise, unsigned, a
        # proper prefix the smaller (L-g, the order of rule 32's sea_str_cmp, LANGUAGE.md 4.4):
        # exactly the order of Python bytes
        a, b = ev(n.kids[0], ctx, fctx)[1], ev(n.kids[1], ctx, fctx)[1]
        if o == 'add':
            return ('s', str_val(a + b, ctx))
        r = {'eq': a == b, 'ne': a != b, 'lt': a < b, 'le': a <= b, 'gt': a > b, 'ge': a >= b}[o]
        return ('b', int(r))
    # an untyped operand is f64 only next to an f64 operand, or when this node is itself an
    # untyped + - * expression in an f64 context; otherwise it is i64 (LANGUAGE.md 4.2), so
    # the operands of an untyped `6 % 4` are i64 even inside an exponent
    sub_f = ('f' in (ka, kb)) or (sk == 'u' and fctx)
    a = ev(n.kids[0], ctx, sub_f)
    b = ev(n.kids[1], ctx, sub_f)
    if o in ('eq', 'ne', 'lt', 'le', 'gt', 'ge'):
        if a[0] == b[0] == 'i':
            c = (a[1] > b[1]) - (a[1] < b[1])
        else:
            c = fe_cmp(to_f(*a), to_f(*b))   # 2: unordered (a NaN)
        r = {'eq': c == 0, 'ne': c != 0, 'lt': c == -1, 'le': c in (-1, 0),
             'gt': c == 1, 'ge': c in (0, 1)}[o]
        return ('b', int(r))
    if o == 'div':
        return ('f', f_div(to_f(*a), to_f(*b)))
    if a[0] == 'f' or b[0] == 'f':
        x, y = to_f(*a), to_f(*b)
        if o == 'mod':
            return ('f', fe_mod(x, y))       # the exact f64 % of LANGUAGE.md 6.6
        return ('f', {'add': f_add, 'sub': f_sub, 'mul': f_mul}[o](x, y))
    x, y = a[1], b[1]
    for v in (x, y):
        if v > I64_MAX:
            raise Fail('ovf', n.pos)         # a bare 2^63 literal
    if o == 'mod':
        if y == 0:
            raise Fail('div0', n.pos)
        r = x - y * (x // y)                 # floored (LANGUAGE.md 6.6)
    else:
        r = {'add': x + y, 'sub': x - y, 'mul': x * y}[o]
    if r < I64_MIN or r > I64_MAX:
        raise Fail('ovf', n.pos)
    return ('i', r)


def str_val(b, ctx):
    """L-f (3.4.2): a str value computed while evaluating a constant has at most
    SEA_LIM_LINE_BYTES bytes, else `program too large: strings` at the constant's item."""
    if len(b) > LIM_LINE_BYTES:
        raise Capacity(ctx.item_pos, 'strings')
    return b


def powk_mul(xb, k):
    one = 0x3FF0000000000000
    if k == 0:
        return one
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
    return f_div(one, t) if k < 0 else t


def contains_call_or_pow(n, ctx):
    """An exponent that contains a call, or a ^ that is itself not a powk, is never integral
    (LANGUAGE.md 6.5; DESIGN.md 3.5.5)."""
    if n.op in ('call', 'conv'):
        return True
    if n.op == 'bin' and n.f[1] == 'pow' and powk_of(n.kids[1], ctx) is None:
        return True
    return any(contains_call_or_pow(k, ctx) for k in n.kids)


def powk_of(e, ctx):
    """k when the exponent e is a constant whose value is an integer with |k| <= LIM_POWK."""
    if contains_call_or_pow(e, ctx):
        return None
    if static_kind(e, ctx) not in ('u', 'i', 'f'):
        return None
    try:
        k, v = ev(e, ctx, True)              # an untyped exponent is taken as f64 (6.5)
    except Fail:
        return None
    if k == 'i':
        if v > I64_MAX:
            return None
        v = i_to_f(v)
    if f_is_nan(v) or f_is_inf(v):
        return None
    q = f_val(v)
    if q.denominator != 1 or abs(q) > LIM_POWK:
        return None
    return int(q)


def eval_const(cn, ctx):
    """The outcome of an entered constant: ('i'|'f'|'b', v), ('e', kind, pos) or None (rcn)."""
    t = int(cn.f[2])
    expr = cn.kids[-1]
    ann = cn.kids[0].f[1] if t else None
    if t and (cn.kids[0].f[2] != 's' or (ann not in SCALAR_TY and ann != 'str')):
        return None
    sk = static_kind(expr, ctx)
    if sk is None:
        return None
    ctx.item_pos = cn.pos                    # L-f reports at the constant's item
    if ann == 'str' or sk == 's':
        # 4g-1: a str constant (an annotation `str` takes only a str value, LANGUAGE.md 7.2)
        if ann not in (None, 'str') or sk != 's':
            return None
        return ev(expr, ctx, False)
    try:
        if sk == 'u' and ann == 'f64':
            # each literal must be exact in f64 (LANGUAGE.md 4.2), then f64 arithmetic
            for x in walk(expr):
                if x.op == 'int':
                    v = dec_i(x.f[1]) & M64
                    if not is_exact_f(v):
                        return None
            k, v = ev(expr, ctx, True)
        else:
            k, v = ev(expr, ctx, False)
    except Fail as e:
        return ('e', e.kind, e.pos)
    if k == 'i' and v > I64_MAX:
        return ('e', 'ovf', expr.pos)        # cannot happen for a well-formed AST (3.4)
    if ann is None:
        return (k, v)
    if ann == 'f64':
        return ('f', to_f(k, v)) if k in ('i', 'f') else None
    if ann == 'i64':
        return (k, v) if k == 'i' else None
    return (k, v) if k == 'b' else None


# ---------------------------------------------------------------- seaname

def seaname(prog):
    items = [k for k in prog.kids if k.op in ('fn', 'const', 'struct')]
    stmts = [k for k in prog.kids if k.op not in ('fn', 'const', 'struct')]
    errors = []                               # (pos tuple, order, pos, code, args)

    def err(pos, code, args):
        errors.append((tuple(int(x) for x in pos.split(':')), len(errors), pos, code, args))

    # entered items (3.4.1); item errors in stream order
    seen, entered = set(), []
    for it in items:
        name = it.f[1]
        if name in seen:
            err(it.pos, 235, [name])
            continue
        seen.add(name)
        if name in PREDECLARED:
            err(it.pos, 212, [])
        entered.append(it)
        if it.op == 'fn' and it.f[2] == '1':
            err(it.pos, 259, ['elemental functions'])
        if it.op == 'struct':
            err(it.pos, 259, ['structs'])
    fns = [it for it in entered if it.op == 'fn']
    sts = [it for it in entered if it.op == 'struct']
    cns = [it for it in entered if it.op == 'const']
    fid = {it.f[1]: i + 2 for i, it in enumerate(fns)}
    sid = {it.f[1]: i + 1 for i, it in enumerate(sts)}
    cid = {it.f[1]: i + 1 for i, it in enumerate(cns)}

    # signatures, in item order: the parameter checks of 3.4.1 (the type nodes are resolved
    # after the constants, 3.4.2); a str parameter is `strings` at its param node and has type 0
    for it in fns:
        np_ = int(it.f[3])
        pnames = set()
        for p in it.kids[:np_]:
            if p.f[1] in pnames:
                err(p.pos, 235, [p.f[1]])
            pnames.add(p.f[1])
            if p.f[1] in PREDECLARED:
                err(p.pos, 213, [])
            if p.f[3] == '1':
                err(p.pos, 259, ['default arguments'])
            if p.kids[0].f[1] == 'str':
                err(p.pos, 259, ['strings'])
    for it in sts:
        it.rop, it.rf = 'rst', it.f + [str(sid[it.f[1]])]

    # every int of the file becomes rint (3.4.1)
    for x in walk(prog):
        if x.op == 'int':
            v = dec_i(x.f[1]) & M64
            if v == SIGN:
                fv = '#C3E0000000000000'
            elif is_exact_f(v):
                fv = enc_f(i_to_f(v))
            else:
                fv = '-'
            x.rop, x.rf = 'rint', x.f + [fv]

    # name resolution in the resolved regions
    items_by_name = {}
    for it in entered:
        items_by_name[it.f[1]] = it

    def lookup(name, scopes):
        for sc in reversed(scopes):
            if name in sc:
                return ('loc', sc[name])
        it = items_by_name.get(name)
        if it is not None:
            if it.op == 'const':
                return ('cst', cid[name])
            if it.op == 'fn':
                return ('fn', fid[name])
            return ('st', sid[name])
        if name in PREDECLARED:
            return ('pd', 0)
        return ('none', 0)

    powk_sites = []                           # bin pow nodes of the resolved regions
    local_types = []                          # (type node, scopes) of let/var annotations

    class Fn:
        def __init__(self, np_):
            self.next = np_ + 1

    def resolve(n, scopes, fn):
        op = n.op
        if op == 'name':
            k, ref = lookup(n.f[1], scopes)
            n.rop, n.rf = 'rname', n.f + [k, str(ref)]
            return
        if op == 'match':
            return                            # skipped region
        if op == 'for':
            # from 4d an element loop is a resolved region too (3.4.2 "Skipped regions")
            resolve(n.kids[0], scopes, fn)
            lid = fn.next
            fn.next += 1
            n.rop, n.rf = 'rfor', n.f + [str(lid)]
            resolve(n.kids[1], scopes + [{n.f[1]: lid}], fn)
            return
        if op == 'block':
            sc = {}
            for k in n.kids:
                resolve_stmt(k, scopes + [sc], fn, sc)
            return
        if op in ('type', 'param'):
            return
        for k in n.kids:
            resolve(k, scopes, fn)
        if op == 'bin' and n.f[1] == 'pow':
            powk_sites.append(n)

    def declare(pat, fn, sc):
        if pat.op == 'pname':
            lid = fn.next
            fn.next += 1
            pat.rop, pat.rf = 'rpname', pat.f + [str(lid)]
            sc[pat.f[1]] = lid
        elif pat.op == 'ptuple':
            for k in pat.kids:
                declare(k, fn, sc)

    def resolve_stmt(s, scopes, fn, sc):
        if s.op in ('let', 'var'):
            if s.f[1] == '1':                 # the annotation: resolved after the constants
                local_types.append((s.kids[1], [dict(d) for d in scopes]))
            resolve(s.kids[-1], scopes, fn)   # visible from the statement after it (7.2)
            declare(s.kids[0], fn, sc)
        else:
            resolve(s, scopes, fn)

    # .main: the top-level statements
    main_sc = {}
    mfn = Fn(0)
    for s in stmts:
        resolve_stmt(s, [main_sc], mfn, main_sc)
    for it in fns:
        np_ = int(it.f[3])
        psc = {}
        for i, p in enumerate(it.kids[:np_]):
            psc[p.f[1]] = i + 1
        resolve(it.kids[-1], [psc], Fn(np_))
    nfn = len(powk_sites)
    for it in cns:
        resolve(it.kids[-1], [], None)
    global CONST_POWK
    CONST_POWK = set(id(n) for n in powk_sites[nfn:])

    # constants: the constant order, evaluation on the well-typed path (3.4.1)
    ctx = Ctx()
    state = {}
    outcome = {}

    def visit(c):
        stack = [(c, iter(list(walk(c.kids[-1]))))]
        state[c.f[1]] = 'waiting'
        while stack:
            cur, it = stack[-1]
            pushed = False
            for x in it:
                if x.op == 'name' and x.rf[2] == 'cst':
                    tgt = cns[int(x.rf[3]) - 1]
                    if tgt.f[1] not in state:
                        state[tgt.f[1]] = 'waiting'
                        stack.append((tgt, iter(list(walk(tgt.kids[-1])))))
                        pushed = True
                        break
            if pushed:
                continue
            stack.pop()
            # Decision 25: a constant that names a constant without a value (or a waiting one)
            names = [x for x in walk(cur.kids[-1]) if x.op == 'name' and x.rf[2] == 'cst']
            if any(int(x.rf[3]) not in ctx.cvals for x in names):
                out = None
            else:
                out = eval_const(cur, ctx)
            outcome[cur.f[1]] = out
            if out is not None and out[0] in ('i', 'f', 'b', 's'):
                ctx.cvals[cid[cur.f[1]]] = out
            state[cur.f[1]] = 'done'

    for c in cns:
        if c.f[1] not in state:
            visit(c)
    for c in cns:
        out = outcome[c.f[1]]
        base = c.f + [str(cid[c.f[1]])]
        if out is None:
            c.rop, c.rf = 'rcn', base
        elif out[0] == 'e':
            c.rop, c.rf = 'rcne', base + [out[1], out[2]]
        elif out[0] == 'i':
            c.rop, c.rf = 'rcni', base + [enc_i(out[1])]
        elif out[0] == 'f':
            c.rop, c.rf = 'rcnf', base + [enc_f(out[1])]
        elif out[0] == 's':
            c.rop, c.rf = 'rcns', base + [esc_b(out[1])]
        else:
            c.rop, c.rf = 'rcnb', base + [str(out[1])]

    # type nodes (3.4.2): resolved after the constants; then the type table, in the order of
    # creation of 3.4.2 (field types, signatures, every other rtype node in file order)
    def outcome_of(cid_):
        return outcome[cns[cid_ - 1].f[1]]

    def resolve_type(tn, scopes, str_ok):
        for d in tn.kids:
            if d.op == 'name':
                k, ref = lookup(d.f[1], scopes)
                d.rop, d.rf = 'rname', d.f + [k, str(ref)]
        tn.rop = 'rtype'
        base, shape = tn.f[1], tn.f[2]
        if base in SCALAR_TY:
            bt = SCALAR_TY[base]
        elif base == 'str':
            bt = 5
        elif base in HANDLE_TY:
            bt = HANDLE_TY[base]
        else:
            k, ref = lookup(base, scopes)
            if k != 'st':
                err(tn.pos, 229, [])
                return None
            bt = ('st', ref)
        vals = []
        for d in tn.kids:
            if d.op == 'int':
                vals.append(dec_i(d.f[1]))
                continue
            k = d.rf[2]
            if k == 'cst':
                out = outcome_of(int(d.rf[3]))
                if out is not None and out[0] == 'i':
                    vals.append(out[1])
                    continue
                if out is not None and out[0] in ('f', 'b', 's'):
                    err(d.pos, 201, ['i64', {'f': 'f64', 'b': 'bool', 's': 'str'}[out[0]]])
                return None                   # rcne/rcn: type 0, the constant's own error
            if k == 'none':
                err(d.pos, 200, [d.f[1]])
            else:
                err(d.pos, 237, [])
            return None
        if shape in ('fv', 'fm'):
            for d, v in zip(tn.kids, vals):
                if v < 0:
                    err(d.pos, 263, [str(v)])
                    return None
            prod = 1
            for v in vals:
                prod *= v
            if prod > LIM_FIXED_ELEMS:
                err(tn.pos, 216, [])
                return None
        if shape != 's' and bt in HANDLE_TY.values():
            err(tn.pos, 258, [base])
            return None
        # the phase rule of sub-phase 4d (2.6.2): fixed-size arrays, structs, handle types
        if shape in ('fv', 'fm'):
            err(tn.pos, 259, ['arrays'])
            return None
        if isinstance(bt, tuple):
            err(tn.pos, 259, ['structs'])
            return None
        if bt in HANDLE_TY.values():
            err(tn.pos, 259, ['handle types'])
            return None
        if bt == 5 and not str_ok:
            return None                       # a str parameter (reported at its param node)
        return bt if shape == 's' else (shape, bt)

    keys = {}
    for c in cns:
        if c.f[2] == '1':
            keys[id(c.kids[0])] = resolve_type(c.kids[0], [], True)
    for st in sts:
        for fd in st.kids:
            keys[id(fd.kids[0])] = resolve_type(fd.kids[0], [], True)
    for it in fns:
        np_, nr = int(it.f[3]), int(it.f[4])
        for p in it.kids[:np_]:
            keys[id(p.kids[0])] = resolve_type(p.kids[0], [], False)
        for tn in it.kids[np_:np_ + nr]:
            if tn.f[1] == 'str':
                err(tn.pos, 259, ['strings'])
            keys[id(tn)] = resolve_type(tn, [], False)
    for tn, scopes in local_types:
        keys[id(tn)] = resolve_type(tn, scopes, True)

    table, tids = [], {}

    def mk(key):
        if key is None:
            return 0
        if isinstance(key, int):
            return key
        if key not in tids:
            tids[key] = 10 + len(table)
            table.append(key)
        return tids[key]

    def typed(tn):
        ty = mk(keys[id(tn)])
        tn.rf = tn.f + [str(ty)]
        return ty

    for st in sts:
        for fd in st.kids:
            typed(fd.kids[0])
    for it in fns:
        np_, nr = int(it.f[3]), int(it.f[4])
        ts = [typed(p.kids[0]) for p in it.kids[:np_]]
        rs = [typed(t) for t in it.kids[np_:np_ + nr]]
        if nr == 0:
            rty = 1
        elif nr == 1:
            rty = rs[0]
        elif 0 in rs:
            rty = 0
        else:
            rty = mk(('t', tuple(rs)))
        it.rop = 'rfn'
        it.rf = it.f + [str(fid[it.f[1]]), str(rty)] + [str(t) for t in ts]
    for x in walk(prog):
        if x.rop == 'rtype' and x.rf is None:
            typed(x)

    # constant exponents (3.4.1, 3.5.5)
    for n in powk_sites:
        k = powk_of(n.kids[1], ctx)
        if k is not None:
            n.rop, n.rf = 'rpowk', [n.f[0], enc_i(k)]
            if id(n) in CONST_POWK:
                CONST_POWK_POS.add(n.f[0])

    out = []
    if errors:
        e = min(errors)
        out.append(' '.join(['rerr', e[2], str(e[3]), str(len(e[4]))] + [esc(a) for a in e[4]]))
    for i, key in enumerate(table):
        if key[0] == 't':
            out.append(' '.join(['rtup', str(10 + i), str(len(key[1]))] + [str(t) for t in key[1]]))
        else:
            out.append('%s %d %d' % ({'v': 'rtvec', 'm': 'rtmat'}[key[0]], 10 + i, key[1]))
    emit(prog, out)
    return out


# ---------------------------------------------------------------- cross-check with sea.hir1
def cross_check(name, res):
    path = os.path.join(PASSES, name + '.hir1')
    if not os.path.exists(path):
        return
    with open(path) as fh:
        hir = [ln.split(' ') for ln in fh.read().split('\n') if ln and not ln.startswith('#')]
    # locals: the loc records give lids np+1, ... with name and pos; a declaration's (name, pos) is
    # unique in the file, so the two files are compared as one map (the top-level statements of
    # .main may stand between the functions in sea.res)
    hlocs = {}
    for r in hir:
        if r[0] == 'fn':
            cnt = int(r[5])
        elif r[0] == 'loc' and not r[1].startswith('.'):
            cnt += 1
            hlocs[(r[1], r[4])] = cnt
    rlocs = {}
    for ln in res:
        r = ln.split(' ')
        if r[0] == 'rpname':
            rlocs[(r[2], r[1])] = int(r[3])
        elif r[0] == 'rfor':
            rlocs[(r[2], r[3])] = int(r[4])
    assert rlocs == hlocs, (name, rlocs, hlocs)
    # constants
    hc = {}
    prev = None
    for r in hir:
        if r[0] == 'cn':
            hc[r[2]] = prev
        prev = r
    for ln in res:
        r = ln.split(' ')
        if r[0] in ('rcni', 'rcnf', 'rcnb', 'rcns'):
            leaf = hc[r[2]]
            if r[0] == 'rcni':
                assert leaf[0] == 'ci' and dec_i(leaf[3]) == dec_i(r[5]), (name, r, leaf)
            elif r[0] == 'rcns':
                assert leaf[0] == 'cs' and leaf[3] == r[5], (name, r, leaf)
            elif r[0] == 'rcnf':
                assert leaf[0] == 'cf' and leaf[3] == r[5], (name, r, leaf)
            else:
                assert leaf[0] == 'cb' and leaf[3] == r[5], (name, r, leaf)
        elif r[0] in ('rcn', 'rcne'):
            raise AssertionError((name, 'a hir1 test with a constant without a value', r))
    hp = sorted((r[1], r[3]) for r in hir if r[0] == 'powk')
    rrecs = (ln.split(" ") for ln in res)
    rp = sorted((r[1], r[2]) for r in rrecs if r[0] == "rpowk" and r[1] not in CONST_POWK_POS)
    assert hp == rp, (name, hp, rp)


def make(name):
    CONST_POWK_POS.clear()
    head, prog = read_ast(os.path.join(PASSES, name + '.ast'))
    res = seaname(prog)
    with open(os.path.join(PASSES, name + '.res'), 'w') as fh:
        fh.write('\n'.join(head + res + ['#end']) + '\n')
    cross_check(name, res)
    return res


if __name__ == '__main__':
    names = sys.argv[1:]
    if not names:
        names = sorted(os.path.splitext(f)[0] for f in os.listdir(PASSES)
                       if f.endswith('.hir1') or (f.startswith('res_') and f.endswith('.ast')))
    for nm in names:
        make(nm)
    print('res_gen: %d files' % len(names))
