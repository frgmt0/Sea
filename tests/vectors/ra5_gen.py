"""Sub-phase 5b pass-4 tests (DESIGN.md 6.2, "ra5_* pass-4 tests"): hand-written LIR for the
allocator and code selection of 4.9.2.

Run with `timeout 120 uv run --no-project python tests/vectors/ra5_gen.py`. It writes
tests/passes/ra5_*.lir (pass-4 tests: no .lir1, no .sea; stage.sh builds them with seagen_a64,
cross_pack.sh retargets them for seagen_x64) and their expected ra5_*.out, plus ra5_*.err and
ra5_*.status for the tests that end in a run-time error (a stale .err/.status is removed). The LIR
is built with lirkit.Test (numbering of DESIGN.md 3.6.1-3.6.3); the expected output is computed by
lirkit.Interp, an independent reading of the instruction semantics of 3.6.4 and of the printf
rules of LANGUAGE.md 11.1, from the LIR text alone, never by running a code generator. Which
interval is spilled is not visible in the output and is not tested (6.2).
"""
import os

from lirkit import Test, Interp, NAN, INF, w64, ifield

CCS = ['eq', 'ne', 'lt', 'le', 'gt', 'ge']
TESTS = []


def test(fn):
    TESTS.append(fn)
    return fn


def computed(f, v, name=None):
    """an i register holding v whose definition is not a li (so it is never an immediate)."""
    r = name or f.tmp('i')
    a = f.li(v - 1)
    b = f.li(1)
    f.e('iadd %s %s %s' % (r, a, b))
    return r


def fcomputed(f, x, name=None):
    """an f register holding x, computed by an fadd of a constant and 0.0 (bit-exact, -0 kept
    by adding -0.0 to it)."""
    r = name or f.tmp('f')
    a = f.lf(x)
    z = f.lf(-0.0)
    f.e('fadd %s %s %s' % (r, a, z))
    return r


# ------------------------------------------------------------------ spills, class i
@test
def ra5_spill_i():
    t = Test('ra5_spill_i')
    f = t.func('.main', 'main', line=1)
    N = 40
    v = ['i.v%d' % k for k in range(N)]
    for k in range(N):
        f.li((k + 1) * 1000003 - 7 * k * k, v[k])
    zero = f.li(0, 'i.zero')
    one = f.li(1, 'i.one')
    two = f.li(2, 'i.two')
    b = f.blk()
    f.e('loop %s i.k %s %s %s' % (b, zero, two, one))
    for k in range(N):
        f.e('iadd %s %s %s' % (v[k], v[k], v[(k + 1) % N]))
    f.e('ixor %s %s i.k' % (v[0], v[0]))
    f.e('endloop %s' % b)
    for j in range(4):
        f.show('a%d' % j, v[10 * j:10 * j + 10], 2)
    # straight-line work on spilled operands and destinations
    for k in range(N):
        f.e('imul %s %s %s' % (v[k], v[k], v[(k + 3) % N]))
    for k in range(N):
        f.e('isub %s %s %s' % (v[k], v[(k + 7) % N], v[k]))
    for j in range(4):
        f.show('b%d' % j, v[10 * j:10 * j + 10], 3)
    # spilled indices and spilled loaded destinations
    s = f.slot(8 * N)
    arr = 'p.arr'
    f.e('sa %s %s' % (arr, s))
    for k in range(N):
        f.e('sti %s %s - 0 %d' % (v[k], arr, 8 * k))
    x = ['i.x%d' % k for k in range(N)]
    for k in range(N):
        computed(f, N - 1 - k, x[k])
    u = ['i.u%d' % k for k in range(N)]
    for k in range(N):
        f.e('ldi %s %s %s 8 0' % (u[k], arr, x[k]))
    for k in range(N):
        f.e('iadd %s %s %s' % (u[k], u[k], x[k]))
    for j in range(4):
        f.show('c%d' % j, u[10 * j:10 * j + 10], 4)
    # thirty live addresses (class p shares the general registers) used as spilled bases
    Q = 30
    q = ['p.q%d' % k for k in range(Q)]
    for k in range(Q):
        sl = f.slot(16)
        f.e('sa %s %s' % (q[k], sl))
    for k in range(Q):
        f.e('sti %s %s - 0 8' % (u[k], q[k]))
        f.e('sti %s %s - 0 0' % (x[k], q[k]))
    tot = f.li(0, 'i.tot')
    for k in range(Q):
        f.e('ldi i.l%d %s - 0 8' % (k, q[Q - 1 - k]))
        f.e('ldi i.m%d %s %s 8 0' % (k, q[k], one))
        f.e('ixor i.l%d i.l%d i.m%d' % (k, k, k))
        f.e('iadd %s %s i.l%d' % (tot, tot, k))
    f.show('d', [tot] + u[:5] + x[:5], 5)
    f.e('ret 0')
    return t


# ------------------------------------------------------------------ spills, class f
@test
def ra5_spill_f():
    t = Test('ra5_spill_f')
    f = t.func('.main', 'main', line=1)
    N = 40
    v = ['f.v%d' % k for k in range(N)]
    for k in range(N):
        f.lf(k * 1.25 - 3.5, v[k])
    h = f.lf(0.5, 'f.h')
    four = f.lf(4.0, 'f.four')
    zero = f.li(0, 'i.zero')
    one = f.li(1, 'i.one')
    two = f.li(2, 'i.two')
    b = f.blk()
    f.e('loop %s i.k %s %s %s' % (b, zero, two, one))
    for k in range(N):
        f.e('fmul f.t %s %s' % (v[(k + 1) % N], h))
        f.e('fadd %s %s f.t' % (v[k], v[k]))
    f.e('itof f.kf i.k')
    f.e('fsub %s %s f.kf' % (v[0], v[0]))
    f.e('endloop %s' % b)
    for j in range(4):
        f.show('a%d' % j, v[10 * j:10 * j + 10], 2)
    for k in range(N):
        f.e('fsub %s %s %s' % (v[k], v[(k + 5) % N], v[k]))
    for k in range(N):
        f.e('fdiv %s %s %s' % (v[k], v[k], four))
    cnt = f.li(0, 'i.cnt')
    for k in range(N):
        f.e('fcmp lt i.c %s %s' % (v[k], v[(k + 1) % N]))
        f.e('iadd %s %s i.c' % (cnt, cnt))
    for j in range(4):
        f.show('b%d' % j, v[10 * j:10 * j + 10], 3)
    # every value still live: spilled operands of fmul in both positions, spilled destinations
    w = ['f.w%d' % k for k in range(N)]
    for k in range(N):
        f.e('fmul %s %s %s' % (w[k], v[k], v[N - 1 - k]))
    for k in range(N):
        f.e('fadd %s %s %s' % (w[k], w[k], v[k]))
    for j in range(4):
        f.show('c%d' % j, w[10 * j:10 * j + 10], 4)
    f.show('n', [cnt, v[0], v[39]], 5)
    f.e('ret 0')
    return t


# ------------------------------------------------------------------ values across calls
def clob_func(t):
    """a leaf that keeps 26 i and 30 f values live at once: it clobbers every caller-saved
    register and needs callee-saved ones of its own (saved by its prologue)."""
    f = t.func('clob', 'fn', params=['i.n'], rescls=['i', 'f'], line=20)
    NI, NF = 26, 30
    c = ['i.c%d' % k for k in range(NI)]
    for k in range(NI):
        kk = f.li(k)
        f.e('imul %s i.n %s' % (c[k], kk))
        k2 = f.li(k * k + 5)
        f.e('iadd %s %s %s' % (c[k], c[k], k2))
    q = f.lf(0.25, 'f.q')
    d = ['f.d%d' % k for k in range(NF)]
    for k in range(NF):
        f.e('itof %s %s' % (d[k], c[k % NI]))
        f.e('fmul %s %s %s' % (d[k], d[k], q))
    s = f.li(0, 'i.s')
    for k in range(NI):
        f.e('iadd i.s i.s %s' % c[NI - 1 - k])
    g = f.lf(0.0, 'f.g')
    for k in range(NF):
        f.e('fadd f.g f.g %s' % d[NF - 1 - k])
    for k in range(NI):
        f.e('ixor i.s i.s %s' % c[k])
    f.e('ret 2 i.s f.g')


@test
def ra5_calls():
    t = Test('ra5_calls')
    f = t.func('.main', 'main', line=1)
    NA, NX = 16, 12
    a = ['i.a%d' % k for k in range(NA)]
    x = ['f.x%d' % k for k in range(NX)]
    for k in range(NA):
        f.li(100 + 7 * k, a[k])
    for k in range(NX):
        f.lf(k + 0.5, x[k])
    zero = f.li(0, 'i.zero')
    one = f.li(1, 'i.one')
    last = f.li(2, 'i.last')
    b = f.blk()
    f.e('loop %s i.k %s %s %s' % (b, zero, last, one))
    f.e('call clob 2 i.r f.s 1 i.k')
    for k in range(NA):
        f.e('iadd %s %s i.r' % (a[k], a[k]))
    for k in range(NX):
        f.e('fadd %s %s f.s' % (x[k], x[k]))
    f.show('it', ['i.k', 'i.r', 'f.s', a[0], x[0]], 3)
    ek = f.li(2)
    rk = f.li(1)
    rows = f.li(4)
    cols = f.li(1)
    f.e('rcall sea_arr_new 0:4 1 p.arr 4 %s %s %s %s' % (ek, rk, rows, cols))
    f.e('retain p.arr')
    f.e('release p.arr')
    f.e('ldi i.cnt p.arr - 0 0')
    f.e('release p.arr')
    f.e('iadd %s %s i.cnt' % (a[1], a[1]))
    for k in range(NA):
        f.e('iadd %s %s %s' % (a[k], a[k], a[(k + 1) % NA]))
    for k in range(NX):
        f.e('fadd %s %s %s' % (x[k], x[k], x[(k + 1) % NX]))
    f.e('endloop %s' % b)
    f.show('a', a, 5)
    f.show('x', x, 6)
    # a value defined before a call, read after a printf in the same straight line
    f.e('call clob 2 i.r2 f.s2 1 %s' % a[3])
    f.show('after', ['i.r2', 'f.s2', a[3], x[3], 'i.last'], 7)
    f.e('ret 0')
    clob_func(t)
    return t


# ------------------------------------------------------------------ callee-saved registers
@test
def ra5_callee():
    t = Test('ra5_callee')
    f = t.func('.main', 'main', line=1)
    NA, NX = 12, 10
    a = ['i.a%d' % k for k in range(NA)]
    x = ['f.x%d' % k for k in range(NX)]
    for k in range(NA):
        f.li(-50 + 11 * k, a[k])
    for k in range(NX):
        f.lf(0.125 * k - 1.0, x[k])
    n = f.li(6, 'i.n')
    y = f.lf(64.0, 'f.y')
    f.e('call rec 2 i.r f.s 2 %s %s' % (n, y))
    f.show('rec', ['i.r', 'f.s'], 3)
    f.show('a', a, 4)
    f.show('x', x, 5)
    f.e('call clob 2 i.r f.s 1 %s' % a[5])
    f.show('clob', ['i.r', 'f.s', a[0], a[11], x[0], x[9]], 6)
    f.e('ret 0')
    # rec(n, y): 12 i and 9 f values live across its own recursive call
    g = t.func('rec', 'fn', params=['i.n', 'f.y'], rescls=['i', 'f'], line=10)
    zero = g.li(0)
    g.e('icmp le i.c i.n %s' % zero)
    bb = g.blk()
    g.e('if %s i.c' % bb)
    g.li(1, 'i.base')
    g.e('ret 2 i.base f.y')
    g.e('endif %s' % bb)
    e = ['i.e%d' % k for k in range(12)]
    for k in range(12):
        kk = g.li(3 * k + 1)
        g.e('iadd %s i.n %s' % (e[k], kk))
    gg = ['f.g%d' % k for k in range(9)]
    for k in range(9):
        kk = g.lf(0.5 * k)
        g.e('fadd %s f.y %s' % (gg[k], kk))
    one = g.li(1)
    g.e('isub i.m i.n %s' % one)
    half = g.lf(0.5)
    g.e('fmul f.y2 f.y %s' % half)
    g.e('call rec 2 i.ri f.rf 2 i.m f.y2')
    three = g.li(3)
    for k in range(12):
        g.e('imul i.ri i.ri %s' % three)
        g.e('iadd i.ri i.ri %s' % e[k])
    for k in range(9):
        g.e('fadd f.rf f.rf %s' % gg[k])
    g.e('ret 2 i.ri f.rf')
    clob_func(t)
    return t


# ------------------------------------------------------------------ parallel moves
@test
def ra5_pmove():
    t = Test('ra5_pmove')
    f = t.func('.main', 'main', line=1)
    f.li(1, 'i.a')
    f.li(2, 'i.b')
    f.li(3, 'i.c')
    f.e('call swap2 2 i.a i.b 2 i.a i.b')
    f.show('swap', ['i.a', 'i.b'], 2)
    f.e('call swap2 2 i.b i.a 2 i.a i.b')
    f.show('same', ['i.a', 'i.b'], 3)
    f.lf(1.5, 'f.x')
    f.lf(-2.25, 'f.y')
    f.e('call fswap 2 f.x f.y 2 f.x f.y')
    f.show('fswap', ['f.x', 'f.y'], 4)
    f.e('call rot3 1 i.r 3 i.c i.a i.b')
    f.show('rot', ['i.r'], 5)
    # register pressure: 30 live i values and 16 live f values, permuted arguments and results
    N = 30
    p = ['i.p%d' % k for k in range(N)]
    for k in range(N):
        f.li(1000 + k, p[k])
    NF = 16
    g = ['f.g%d' % k for k in range(NF)]
    for k in range(NF):
        f.lf(0.5 + k, g[k])
    f.e('call mix4 4 %s %s %s %s 4 %s %s %s %s' % (p[0], p[1], p[2], p[3], p[0], p[1], p[2], p[3]))
    f.e('call mix4 4 %s %s %s %s 4 %s %s %s %s' % (p[5], p[6], p[7], p[4], p[4], p[5], p[6], p[7]))
    f.e('call mix4 4 %s %s %s %s 4 %s %s %s %s' % (p[29], p[8], p[28], p[9], p[8], p[29], p[9], p[28]))
    f.e('call mix4 4 %s %s %s %s 4 %s %s %s %s' % (p[10], p[11], p[12], p[13], p[10], p[10], p[11], p[10]))
    # twenty arguments (stack arguments on both targets) from spilled and register sources,
    # results written back over the same registers in another order
    args = []
    for k in range(10):
        args += [p[12 + k], g[k]]
    res = []
    for k in range(10):
        res += [p[21 - k], g[(k + 3) % 10]]
    f.e('call big 20 %s 20 %s' % (' '.join(res), ' '.join(args)))
    # the same call again with the results discarded, then with results into fresh registers
    f.e('call big 0 20 %s' % ' '.join(args))
    fresh = []
    for k in range(10):
        fresh += ['i.z%d' % k, 'f.z%d' % k]
    f.e('call big 20 %s 20 %s' % (' '.join(fresh), ' '.join(res)))
    for j in range(3):
        f.show('p%d' % j, p[10 * j:10 * j + 10], 6)
    f.show('g', g, 7)
    f.show('z', fresh, 8)
    f.e('ret 0')
    # callees
    s = t.func('swap2', 'fn', params=['i.a', 'i.b'], rescls=['i', 'i'], line=10)
    s.e('ret 2 i.b i.a')
    s = t.func('fswap', 'fn', params=['f.a', 'f.b'], rescls=['f', 'f'], line=11)
    s.e('ret 2 f.b f.a')
    s = t.func('tgt3', 'fn', params=['i.a', 'i.b', 'i.c'], rescls=['i'], line=12)
    h = s.li(100)
    tt = s.li(10000)
    s.e('imul i.b i.b %s' % h)
    s.e('imul i.c i.c %s' % tt)
    s.e('iadd i.a i.a i.b')
    s.e('iadd i.a i.a i.c')
    s.e('ret 1 i.a')
    s = t.func('rot3', 'fn', params=['i.a', 'i.b', 'i.c'], rescls=['i'], line=13)
    s.e('call tgt3 1 i.r 3 i.c i.a i.b')
    s.e('call tgt3 1 i.q 3 i.b i.c i.a')
    s.e('imul i.r i.r i.q')
    s.e('ret 1 i.r')
    s = t.func('mix4', 'fn', params=['i.a', 'i.b', 'i.c', 'i.d'], rescls=['i', 'i', 'i', 'i'], line=14)
    s.e('ret 4 i.d i.c i.b i.a')
    prm = []
    for k in range(10):
        prm += ['i.a%d' % k, 'f.b%d' % k]
    out = []
    for k in range(10):
        out += ['i.a%d' % (9 - k), 'f.b%d' % (9 - k)]
    s = t.func('big', 'fn', params=prm, rescls=['i', 'f'] * 10, line=15)
    s.e('ret 20 %s' % ' '.join(out))
    return t


# ------------------------------------------------------------------ fcmp and its fusions
@test
def ra5_fcmp():
    t = Test('ra5_fcmp')
    f = t.func('.main', 'main', line=1)
    pairs = [(NAN, 1.0), (1.0, NAN), (NAN, NAN), (1.0, 2.0), (2.0, 1.0), (1.0, 1.0),
             (-0.0, 0.0), (INF, -INF), ('same', NAN), ('same', 3.0)]
    ione = f.li(1, 'i.one')
    izero = f.li(0, 'i.zero')
    three = f.li(3, 'i.three')
    fone = f.lf(1.0, 'f.one')
    fzero = f.lf(0.0, 'f.zero')
    for pi, (pa, pb) in enumerate(pairs):
        if pa == 'same':
            a = fcomputed(f, pb)
            b = a
        else:
            a = fcomputed(f, pa)
            b = fcomputed(f, pb)
        outs = []
        for cc in CCS:
            m = f.tmp('i')
            f.e('fcmp %s %s %s %s' % (cc, m, a, b))
            outs.append(m)
        for cc in CCS:          # fused into if/else
            c = f.tmp('i')
            r = f.tmp('i')
            bb = f.blk()
            f.e('fcmp %s %s %s %s' % (cc, c, a, b))
            f.e('if %s %s' % (bb, c))
            f.li(1, r)
            f.e('else %s' % bb)
            f.li(0, r)
            f.e('endif %s' % bb)
            outs.append(r)
        for cc in CCS:          # fused into ifz without else
            c = f.tmp('i')
            r = f.tmp('i')
            f.li(5, r)
            bb = f.blk()
            f.e('fcmp %s %s %s %s' % (cc, c, a, b))
            f.e('ifz %s %s' % (bb, c))
            f.li(7, r)
            f.e('endif %s' % bb)
            outs.append(r)
        for cc in CCS:          # the one branch to exit (a do loop)
            n = f.tmp('i')
            f.li(0, n)
            bd = f.blk()
            f.e('do %s' % bd)
            f.e('iadd %s %s %s' % (n, n, ione))
            c = f.tmp('i')
            f.e('fcmp %s %s %s %s' % (cc, c, a, b))
            b2 = f.blk()
            f.e('if %s %s' % (b2, c))
            f.e('exit %s' % bd)
            f.e('endif %s' % b2)
            g = f.tmp('i')
            f.e('icmp ge %s %s %s' % (g, n, three))
            b3 = f.blk()
            f.e('if %s %s' % (b3, g))
            f.e('exit %s' % bd)
            f.e('endif %s' % b3)
            f.e('enddo %s' % bd)
            outs.append(n)
        for cc in CCS:          # the one branch to next (a counted loop of two iterations)
            n = f.tmp('i')
            f.li(0, n)
            bl = f.blk()
            ind = f.tmp('i')
            f.e('loop %s %s %s %s %s' % (bl, ind, izero, ione, ione))
            c = f.tmp('i')
            f.e('fcmp %s %s %s %s' % (cc, c, a, b))
            b2 = f.blk()
            f.e('if %s %s' % (b2, c))
            f.e('next %s' % bl)
            f.e('endif %s' % b2)
            f.e('iadd %s %s %s' % (n, n, ione))
            f.e('endloop %s' % bl)
            outs.append(n)
        for cc in CCS:          # selections
            c = f.tmp('i')
            r = f.tmp('i')
            f.e('fcmp %s %s %s %s' % (cc, c, a, b))
            f.e('isel %s %s %s %s' % (r, c, ione, izero))
            outs.append(r)
        fo = []
        for cc in CCS:
            c = f.tmp('i')
            r = f.tmp('f')
            f.e('fcmp %s %s %s %s' % (cc, c, a, b))
            f.e('fsel %s %s %s %s' % (r, c, fone, fzero))
            fo.append(r)
        pieces = ['pair%d' % pi]
        for k, o in enumerate(outs + fo):
            pieces.append(' ' if k % 6 else ' | ')
            pieces.append(('d', o[0], None))
        pieces.append('\n')
        f.printf(pieces, outs + fo, 2 + pi)
    f.e('ret 0')
    return t


# ------------------------------------------------------------------ icmp, immediates, fusions
def icmp_body(f, title, consts, line):
    ione = f.li(1)
    izero = f.li(0)
    three = f.li(3)
    s1 = f.slot(8)
    s0 = f.slot(8)
    pone = f.tmp('p')
    pzero = f.tmp('p')
    f.e('sa %s %s' % (pone, s1))
    f.e('sa %s %s' % (pzero, s0))
    f.e('sti %s %s - 0 0' % (ione, pone))
    f.e('sti %s %s - 0 0' % (izero, pzero))
    for ci, cv in enumerate(consts):
        for delta in (-1, 0, 1):
            av = w64(cv + delta)
            a = computed(f, av)
            outs = []
            for cc in CCS:          # materialized, constant second
                k = f.li(cv)
                m = f.tmp('i')
                f.e('icmp %s %s %s %s' % (cc, m, a, k))
                outs.append(m)
            for cc in CCS:          # materialized, constant first
                k = f.li(cv)
                m = f.tmp('i')
                f.e('icmp %s %s %s %s' % (cc, m, k, a))
                outs.append(m)
            for cc in CCS:          # fused into if/else
                k = f.li(cv)
                c = f.tmp('i')
                r = f.tmp('i')
                bb = f.blk()
                f.e('icmp %s %s %s %s' % (cc, c, a, k))
                f.e('if %s %s' % (bb, c))
                f.li(1, r)
                f.e('else %s' % bb)
                f.li(0, r)
                f.e('endif %s' % bb)
                outs.append(r)
            for cc in CCS:          # fused into isel and psel
                k = f.li(cv)
                c = f.tmp('i')
                r = f.tmp('i')
                f.e('icmp %s %s %s %s' % (cc, c, k, a))
                f.e('isel %s %s %s %s' % (r, c, ione, izero))
                k2 = f.li(cv)
                c2 = f.tmp('i')
                pp = f.tmp('p')
                r2 = f.tmp('i')
                f.e('icmp %s %s %s %s' % (cc, c2, a, k2))
                f.e('psel %s %s %s %s' % (pp, c2, pone, pzero))
                f.e('ldi %s %s - 0 0' % (r2, pp))
                f.e('iadd %s %s %s' % (r, r, r))
                f.e('iadd %s %s %s' % (r, r, r2))
                outs.append(r)
            for cc in CCS:          # the one branch to exit
                n = f.tmp('i')
                f.li(0, n)
                bd = f.blk()
                f.e('do %s' % bd)
                f.e('iadd %s %s %s' % (n, n, ione))
                k = f.li(cv)
                c = f.tmp('i')
                f.e('icmp %s %s %s %s' % (cc, c, a, k))
                b2 = f.blk()
                f.e('if %s %s' % (b2, c))
                f.e('exit %s' % bd)
                f.e('endif %s' % b2)
                g = f.tmp('i')
                f.e('icmp ge %s %s %s' % (g, n, three))
                b3 = f.blk()
                f.e('if %s %s' % (b3, g))
                f.e('exit %s' % bd)
                f.e('endif %s' % b3)
                f.e('enddo %s' % bd)
                outs.append(n)
            pieces = ['%s %d%+d' % (title, cv, delta)]
            for k, o in enumerate(outs):
                pieces.append(' ' if k % 6 else ' | ')
                pieces.append(('d', 'i', None))
            pieces.append('\n')
            f.printf(pieces, outs, line)


@test
def ra5_icmp():
    t = Test('ra5_icmp')
    f = t.func('.main', 'main', line=1)
    icmp_body(f, 'k', [0, 4096, -4096, 2**31, -2**31, -2**63], 2)
    # comparisons with 0 read only by an if (cbz / cbnz, testq), if and ifz on a register, bnot
    vals = [0, 1, -1, 2**63 - 1, -2**63]
    outs = []
    for v in vals:
        a = computed(f, v)
        for cc in ('eq', 'ne', 'lt', 'ge'):
            z = f.li(0)
            c = f.tmp('i')
            r = f.tmp('i')
            bb = f.blk()
            f.e('icmp %s %s %s %s' % (cc, c, a, z))
            f.e('if %s %s' % (bb, c))
            f.li(1, r)
            f.e('else %s' % bb)
            f.li(0, r)
            f.e('endif %s' % bb)
            outs.append(r)
        r = f.tmp('i')
        f.li(0, r)
        bb = f.blk()
        f.e('if %s %s' % (bb, a))
        f.li(1, r)
        f.e('endif %s' % bb)
        outs.append(r)
        r = f.tmp('i')
        f.li(0, r)
        bb = f.blk()
        f.e('ifz %s %s' % (bb, a))
        f.li(1, r)
        f.e('endif %s' % bb)
        outs.append(r)
        c = f.tmp('i')
        r = f.tmp('i')
        f.e('bnot %s %s' % (c, a))
        bb = f.blk()
        f.e('if %s %s' % (bb, c))
        f.li(1, r)
        f.e('else %s' % bb)
        f.li(0, r)
        f.e('endif %s' % bb)
        outs.append(r)
        c = f.tmp('i')
        f.e('bnot %s %s' % (c, a))
        outs.append(c)
    for j in range(len(vals)):
        f.show('z%d' % vals[j], outs[8 * j:8 * j + 8], 3)
    f.e('ret 0')
    return t


# ------------------------------------------------------------------ immediates at encoding limits
@test
def ra5_imm():
    t = Test('ra5_imm')
    f = t.func('.main', 'main', line=1)
    consts = [4095, 4096, 4097, -4095, -4096, -4097, 0xFFF000, 0xFFF001, 0x1000000,
              2**31 - 1, 2**31, -2**31, -2**31 - 1, 2**32, 2**63 - 1, -2**63]
    x = computed(f, 1000000007, 'i.x')
    three = computed(f, 3, 'i.three')
    sl = f.slot(16)
    base = 'p.base'
    f.e('sa %s %s' % (base, sl))
    st = f.li(77)
    f.e('sti %s %s - 0 0' % (st, base))
    for cv in consts:
        outs = []
        for op in ('iadd', 'isub', 'imul', 'iand', 'ior', 'ixor'):
            k = f.li(cv)
            r = f.tmp('i')
            f.e('%s %s %s %s' % (op, r, x, k))
            outs.append(r)
        k = f.li(cv)
        r = f.tmp('i')
        f.e('isub %s %s %s' % (r, k, x))       # the constant as first operand
        outs.append(r)
        small = cv if -2**62 < cv < 2**62 else cv // 4
        if small == cv:
            for op in ('iaddc', 'isubc'):
                k = f.li(cv)
                r = f.tmp('i')
                f.e('%s %s %s %s 0:2' % (op, r, three, k))
                outs.append(r)
            k = f.li(cv)
            r = f.tmp('i')
            f.e('imulc %s %s %s 0:2' % (r, three, k))
            outs.append(r)
        # padd with the constant and back, then a load through the result
        k = f.li(cv)
        kn = f.li(w64(-cv))
        p1 = f.tmp('p')
        p2 = f.tmp('p')
        f.e('padd %s %s %s' % (p1, base, k))
        f.e('padd %s %s %s' % (p2, p1, kn))
        r = f.tmp('i')
        f.e('ldi %s %s - 0 0' % (r, p2))
        outs.append(r)
        f.show('c%d' % cv, outs, 3)
    # logical immediates and shift amounts
    y = computed(f, -0x0123456789ABCDEF, 'i.y')
    outs = []
    for lv in (0xFF, 0x5555555555555555, -0x100000000, 0x123, -1, -2**63, 0x0F0F0F0F0F0F0F0F):
        for op in ('iand', 'ior', 'ixor'):
            k = f.li(w64(lv))
            r = f.tmp('i')
            f.e('%s %s %s %s' % (op, r, y, k))
            outs.append(r)
    f.show('logic', outs, 4)
    outs = []
    for sh in (0, 1, 31, 32, 63):
        for op in ('ishl', 'ishr', 'isar'):
            k = f.li(sh)
            r = f.tmp('i')
            f.e('%s %s %s %s' % (op, r, y, k))
            outs.append(r)
    f.show('shift', outs, 5)
    f.e('ret 0')
    return t


# ------------------------------------------------------------------ chkb with immediate indices
@test
def ra5_chkb():
    t = Test('ra5_chkb')
    f = t.func('.main', 'main', line=1)
    e4096 = computed(f, 4096)
    e4097 = computed(f, 4097)
    e1 = computed(f, 1)
    i4095 = f.li(4095)
    i4096 = f.li(4096)
    i0 = f.li(0)
    f.e('chkb %s %s 0 0:2' % (i4095, e4096))
    f.e('chkb %s %s 1 0:2' % (i4096, e4097))
    f.e('chkb %s %s 0 0:2' % (i0, e1))
    r4096 = computed(f, 4096)
    f.e('chkb %s %s 0 0:2' % (r4096, e4097))
    f.show('ok', [i4095, i4096, e4097], 3)
    e2g = computed(f, 2**31)
    i2g1 = f.li(2**31 - 1)
    f.e('chkb %s %s 0 0:4' % (i2g1, e2g))
    e2g1 = computed(f, 2**31 + 1)
    i2g = f.li(2**31)
    f.e('chkb %s %s 1 0:4' % (i2g, e2g1))
    f.show('ok', [i2g1, i2g], 5)
    i4096b = f.li(4096)
    f.e('chkb %s %s 1 0:9' % (i4096b, e4096))
    f.show('unreached', [i4096b], 10)
    f.e('ret 0')
    return t


@test
def ra5_chkb_neg():
    t = Test('ra5_chkb_neg')
    f = t.func('.main', 'main', line=1)
    e3 = computed(f, 3)
    i2 = f.li(2)
    f.e('chkb %s %s 0 0:2' % (i2, e3))
    f.show('ok', [i2, e3], 3)
    im1 = f.li(-1)
    f.e('chkb %s %s 0 0:6' % (im1, e3))
    f.show('unreached', [im1], 7)
    f.e('ret 0')
    return t


# ------------------------------------------------------------------ staged templates
def staged_section(f, tag, line):
    # idivf, imodf: d separate, d = a, d = b, d = a = b
    pairs = [(7, 2), (-7, 2), (7, -2), (-7, -2), (-2**63, 1), (2**63 - 1, -1), (-2**63, 2**63 - 1),
             (13, 13), (-1, 2**63 - 1)]
    for op in ('idivf', 'imodf'):
        outs = []
        for av, bv in pairs:
            a = computed(f, av)
            b = computed(f, bv)
            r = f.tmp('i')
            f.e('%s %s %s %s 0:%d' % (op, r, a, b, line))
            outs.append(r)
            ra = f.tmp('i')
            f.e('mov %s %s' % (ra, a))
            f.e('%s %s %s %s 0:%d' % (op, ra, ra, b, line))
            outs.append(ra)
            rb = f.tmp('i')
            f.e('mov %s %s' % (rb, b))
            f.e('%s %s %s %s 0:%d' % (op, rb, a, rb, line))
            outs.append(rb)
            rr = f.tmp('i')
            f.e('mov %s %s' % (rr, a))
            f.e('%s %s %s %s 0:%d' % (op, rr, rr, rr, line))
            outs.append(rr)
        f.show('%s %s' % (tag, op), outs, line)
    # rcount with destinations sharing registers with operands
    rng = [(0, 10, 3, 0), (10, 0, -3, 1), (5, 5, 1, 0), (5, 5, 1, 1), (-2**63, 2**63 - 1, 1, 1),
           (0, -2**63, -2**63, 1), (-2**63, 2**63 - 1, 2**62, 0), (3, -7, -1, 0)]
    outs = []
    for lo, hi, stp, incl in rng:
        L = computed(f, lo)
        H = computed(f, hi)
        S = computed(f, stp)
        d = f.tmp('i')
        e = f.tmp('i')
        f.e('rcount %s %s %s %s %s %d 0:%d' % (d, e, L, H, S, incl, line))
        outs += [d, e]
        L2 = f.tmp('i')
        H2 = f.tmp('i')
        f.e('mov %s %s' % (L2, L))
        f.e('mov %s %s' % (H2, H))
        f.e('rcount %s %s %s %s %s %d 0:%d' % (L2, H2, L2, H2, S, incl, line))
        outs += [L2, H2]
        S2 = f.tmp('i')
        L3 = f.tmp('i')
        f.e('mov %s %s' % (S2, S))
        f.e('mov %s %s' % (L3, L))
        f.e('rcount %s %s %s %s %s %d 0:%d' % (S2, L3, L3, H, S2, incl, line))
        outs += [S2, L3]
    f.show('%s rcount' % tag, outs, line)
    # ftoi
    outs = []
    for xv in (3.0, -0.0, -2.0**63, 2.0**53 + 2, 1e18, -7.0):
        a = fcomputed(f, xv)
        r = f.tmp('i')
        f.e('ftoi %s %s 0:%d' % (r, a, line))
        outs.append(r)
    f.show('%s ftoi' % tag, outs, line)
    # fmin, fmax
    fp = [(1.0, 2.0), (2.0, 1.0), (NAN, 1.0), (1.0, NAN), (-0.0, 0.0), (0.0, -0.0), (NAN, NAN),
          (-INF, 3.0)]
    for op in ('fmin', 'fmax'):
        outs = []
        for av, bv in fp:
            a = fcomputed(f, av)
            b = fcomputed(f, bv)
            r = f.tmp('f')
            f.e('%s %s %s %s' % (op, r, a, b))
            ra = f.tmp('f')
            f.e('mov %s %s' % (ra, a))
            f.e('%s %s %s %s' % (op, ra, ra, b))
            rb = f.tmp('f')
            f.e('mov %s %s' % (rb, b))
            f.e('%s %s %s %s' % (op, rb, a, rb))
            outs += [r, ra, rb]
        f.show('%s %s' % (tag, op), outs, line)
    # ffloor, fceil, ftrunc, fround
    xs = [2.5, -2.5, 0.5, -0.5, 1.5, -1.5, 0.49999999999999994, -0.49999999999999994,
          4503599627370497.0, -4503599627370495.5, 1e300, -0.0, INF, -INF, NAN, 0.7, -0.7,
          2251799813685248.5, -2251799813685248.5]
    for op in ('ffloor', 'fceil', 'ftrunc', 'fround'):
        outs = []
        for xv in xs:
            a = fcomputed(f, xv)
            r = f.tmp('f')
            f.e('%s %s %s' % (op, r, a))
            f.e('%s %s %s' % (op, a, a))
            outs += [r, a]
        f.show('%s %s' % (tag, op), outs, line)
    # mcopy
    src = f.slot(32)
    dst = f.slot(32)
    ps = f.tmp('p')
    pd = f.tmp('p')
    f.e('sa %s %s' % (ps, src))
    f.e('sa %s %s' % (pd, dst))
    for k in range(4):
        v = f.li(0x0101010101010101 * (k + 1) + k)
        f.e('sti %s %s - 0 %d' % (v, ps, 8 * k))
    z = f.li(0)
    for k in range(4):
        f.e('sti %s %s - 0 %d' % (z, pd, 8 * k))
    outs = []
    for n, so, do in ((0, 0, 0), (13, 1, 2), (24, 8, 0), (8, 24, 24)):
        nn = computed(f, n)
        o1 = f.li(so)
        o2 = f.li(do)
        a1 = f.tmp('p')
        a2 = f.tmp('p')
        f.e('padd %s %s %s' % (a1, ps, o1))
        f.e('padd %s %s %s' % (a2, pd, o2))
        f.e('mcopy %s %s %s' % (a2, a1, nn))
        for k in range(4):
            r = f.tmp('i')
            f.e('ldi %s %s - 0 %d' % (r, pd, 8 * k))
            outs.append(r)
    f.show('%s mcopy' % tag, outs, line)


@test
def ra5_staged():
    t = Test('ra5_staged')
    f = t.func('.main', 'main', line=1)
    staged_section(f, 'free', 2)
    # the same under register pressure: 30 i and 32 f values live across every staged sequence
    NI, NF = 30, 32
    hi = ['i.h%d' % k for k in range(NI)]
    hf = ['f.h%d' % k for k in range(NF)]
    for k in range(NI):
        computed(f, 3 * k - 40, hi[k])
    for k in range(NF):
        fcomputed(f, 0.25 * k - 2.0, hf[k])
    staged_section(f, 'busy', 3)
    for k in range(NI):
        f.e('iadd %s %s %s' % (hi[k], hi[k], hi[(k + 1) % NI]))
    for k in range(NF):
        f.e('fadd %s %s %s' % (hf[k], hf[k], hf[(k + 1) % NF]))
    f.show('hi', hi, 4)
    f.show('hf', hf, 5)
    f.e('ret 0')
    return t


# ------------------------------------------------------------------ loops
@test
def ra5_loops():
    t = Test('ra5_loops')
    f = t.func('.main', 'main', line=1)
    zero = f.li(0, 'i.zero')
    one = f.li(1, 'i.one')
    # (a) ind not read after the loop
    nine = f.li(9)
    s = f.li(0, 'i.sa')
    b = f.blk()
    f.e('loop %s i.ka %s %s %s' % (b, zero, nine, one))
    f.e('iadd i.sa i.sa i.ka')
    f.e('endloop %s' % b)
    f.show('a', [s], 2)
    # (b) ind read after the loop (implementer reading: it holds start + last * step)
    st = f.li(3)
    l5 = f.li(5)
    s4 = f.li(4)
    f.li(0, 'i.sb')
    b = f.blk()
    f.e('loop %s i.kb %s %s %s' % (b, st, l5, s4))
    f.e('iadd i.sb i.sb i.kb')
    f.e('endloop %s' % b)
    f.show('b', ['i.sb', 'i.kb'], 3)
    # (c) a loop of 2^64 iterations left by exit, ind read after; and the same, ind not read
    lo = f.li(-2**63)
    lmax = f.li(-1)
    stop = f.li(-2**63 + 4)
    f.li(0, 'i.nc')
    b = f.blk()
    f.e('loop %s i.kc %s %s %s' % (b, lo, lmax, one))
    f.e('iadd i.nc i.nc %s' % one)
    f.e('icmp eq i.cc i.kc %s' % stop)
    b2 = f.blk()
    f.e('if %s i.cc' % b2)
    f.e('exit %s' % b)
    f.e('endif %s' % b2)
    f.e('endloop %s' % b)
    f.show('c', ['i.nc', 'i.kc'], 4)
    f.li(0, 'i.nd')
    seven = f.li(7)
    b = f.blk()
    f.e('loop %s i.kd %s %s %s' % (b, lo, lmax, one))
    f.e('iadd i.nd i.nd %s' % one)
    f.e('icmp ge i.cd i.nd %s' % seven)
    b2 = f.blk()
    f.e('if %s i.cd' % b2)
    f.e('exit %s' % b)
    f.e('endif %s' % b2)
    f.e('endloop %s' % b)
    f.show('d', ['i.nd'], 5)
    # (e) start, last and step registers written inside the loop (read once on entry)
    computed(f, 10, 'i.st')
    computed(f, 4, 'i.la')
    computed(f, -3, 'i.sp')
    f.li(0, 'i.se')
    b = f.blk()
    f.e('loop %s i.ke i.st i.la i.sp' % b)
    f.e('iadd i.se i.se i.ke')
    f.e('iadd i.sp i.sp %s' % one)
    f.e('iadd i.st i.st %s' % one)
    f.e('isub i.la i.la %s' % one)
    f.show('e-in', ['i.ke', 'i.sp', 'i.st', 'i.la'], 6)
    f.e('endloop %s' % b)
    f.show('e', ['i.se', 'i.sp', 'i.st', 'i.la'], 7)
    # (f) wrapping induction values, an rcall in the body
    computed(f, 2**63 - 2, 'i.sf')
    l3 = f.li(3)
    b = f.blk()
    f.e('loop %s i.kf i.sf %s %s' % (b, l3, one))
    f.show('f', ['i.kf'], 8)
    f.e('endloop %s' % b)
    big = f.li(2**62)
    f.li(0, 'i.sg')
    b = f.blk()
    f.e('loop %s i.kg %s %s %s' % (b, zero, l3, big))
    f.e('ixor i.sg i.sg i.kg')
    f.show('g', ['i.kg'], 9)
    f.e('endloop %s' % b)
    f.show('g', ['i.sg', 'i.kg'], 10)
    # (h) one iteration; next and exit of an outer loop from an inner one
    f.li(0, 'i.sh')
    b = f.blk()
    f.e('loop %s i.kh %s %s %s' % (b, seven, zero, one))
    f.e('iadd i.sh i.sh i.kh')
    f.e('endloop %s' % b)
    f.show('h', ['i.sh', 'i.kh'], 11)
    f.li(0, 'i.acc')
    f.li(100, 'i.carry')
    four = f.li(4)
    bo = f.blk()
    f.e('loop %s i.ko %s %s %s' % (bo, zero, four, one))
    f.e('iadd i.carry i.carry i.ko')
    bi = f.blk()
    f.e('loop %s i.ki %s %s %s' % (bi, zero, four, one))
    f.e('icmp eq i.c1 i.ki i.ko')
    b2 = f.blk()
    f.e('if %s i.c1' % b2)
    f.e('next %s' % bo)
    f.e('endif %s' % b2)
    f.e('icmp eq i.c2 i.ko %s' % l3)
    b3 = f.blk()
    f.e('if %s i.c2' % b3)
    f.e('exit %s' % bo)
    f.e('endif %s' % b3)
    f.e('imul i.t i.ko %s' % four)
    f.e('iadd i.t i.t i.ki')
    f.e('ior i.acc i.acc i.t')
    f.e('iadd i.carry i.carry i.t')
    f.e('endloop %s' % bi)
    f.e('endloop %s' % bo)
    f.show('i', ['i.acc', 'i.carry', 'i.ko'], 12)
    # (j) the canonical form over an empty range and over a negative step
    computed(f, 5, 'i.lo')
    computed(f, 5, 'i.hi')
    f.e('rcount i.rl i.re i.lo i.hi %s 0 0:13' % one)
    f.li(0, 'i.sj')
    bb = f.blk()
    f.e('if %s i.re' % bb)
    b = f.blk()
    f.e('loop %s i.kj i.lo i.rl %s' % (b, one))
    f.e('iadd i.sj i.sj %s' % one)
    f.e('endloop %s' % b)
    f.e('endif %s' % bb)
    mthree = f.li(-3)
    computed(f, -1, 'i.hi2')
    f.e('rcount i.rl i.re i.hi i.hi2 %s 1 0:13' % mthree)
    bb = f.blk()
    f.e('if %s i.re' % bb)
    b = f.blk()
    f.e('loop %s i.kk i.hi i.rl %s' % (b, mthree))
    f.e('imul i.sj i.sj %s' % seven)
    f.e('iadd i.sj i.sj i.kk')
    f.e('endloop %s' % b)
    f.e('endif %s' % bb)
    f.show('j', ['i.sj', 'i.rl', 'i.re'], 14)
    # (k) a do loop with next, values carried around it
    f.li(0, 'i.n')
    f.li(1, 'i.prod')
    bd = f.blk()
    f.e('do %s' % bd)
    f.e('iadd i.n i.n %s' % one)
    f.e('icmp gt i.c3 i.n %s' % seven)
    b2 = f.blk()
    f.e('if %s i.c3' % b2)
    f.e('exit %s' % bd)
    f.e('endif %s' % b2)
    two = f.li(2)
    f.e('imodf i.m i.n %s 0:15' % two)
    b3 = f.blk()
    f.e('if %s i.m' % b3)
    f.e('next %s' % bd)
    f.e('endif %s' % b3)
    f.e('imul i.prod i.prod i.n')
    f.e('enddo %s' % bd)
    f.show('k', ['i.n', 'i.prod'], 16)
    f.e('ret 0')
    return t


# ------------------------------------------------------------------ x86_64 two-address forms
@test
def ra5_forms():
    t = Test('ra5_forms')
    f = t.func('.main', 'main', line=1)
    av, bv = -123456789, 987654
    for op in ('iadd', 'isub', 'imul', 'iand', 'ior', 'ixor', 'ishl', 'ishr', 'isar', 'imulh'):
        a = computed(f, av if op not in ('ishl', 'ishr', 'isar') else -0x0123456789ABCDEF)
        b = computed(f, bv if op not in ('ishl', 'ishr', 'isar') else 5)
        outs = []
        r = f.tmp('i')
        f.e('%s %s %s %s' % (op, r, a, b))
        outs.append(r)
        ra = f.tmp('i')
        f.e('mov %s %s' % (ra, a))
        f.e('%s %s %s %s' % (op, ra, ra, b))
        outs.append(ra)
        rb = f.tmp('i')
        f.e('mov %s %s' % (rb, b))
        f.e('%s %s %s %s' % (op, rb, a, rb))
        outs.append(rb)
        if op in ('ishl', 'ishr', 'isar'):
            c = computed(f, 7)
        else:
            c = computed(f, av)
        rr = f.tmp('i')
        f.e('mov %s %s' % (rr, c))
        f.e('%s %s %s %s' % (op, rr, rr, rr))
        outs.append(rr)
        f.show(op, outs, 2)
    for op in ('iaddc', 'isubc', 'imulc'):
        a = computed(f, 3037000499 if op == 'imulc' else 2**62)
        b = computed(f, 3037000499 if op == 'imulc' else 2**62 - 1)
        outs = []
        ra = f.tmp('i')
        f.e('mov %s %s' % (ra, a))
        f.e('%s %s %s %s 0:3' % (op, ra, ra, b))
        rb = f.tmp('i')
        f.e('mov %s %s' % (rb, b))
        f.e('%s %s %s %s 0:3' % (op, rb, a, rb))
        r = f.tmp('i')
        f.e('%s %s %s %s 0:3' % (op, r, a, b))
        f.show(op, [ra, rb, r], 3)
    a = computed(f, -2**63 + 1)
    r = f.tmp('i')
    f.e('mov %s %s' % (r, a))
    f.e('inegc %s %s 0:4' % (r, r))
    r2 = f.tmp('i')
    f.e('ineg %s %s' % (r2, a))
    r3 = computed(f, -2**63)
    f.e('ineg %s %s' % (r3, r3))
    f.show('neg', [r, r2, r3], 4)
    # immediates with d != a (leaq, imulq $v), padd with an immediate
    a = computed(f, 5000)
    outs = []
    for v in (12, -12, 2**31 - 1, -2**31, 2**31):
        k = f.li(v)
        r = f.tmp('i')
        f.e('iadd %s %s %s' % (r, a, k))
        outs.append(r)
        k = f.li(v)
        r = f.tmp('i')
        f.e('imul %s %s %s' % (r, a, k))
        outs.append(r)
        k = f.li(v)
        r = f.tmp('i')
        f.e('imulc %s %s %s 0:5' % (r, a, k))
        outs.append(r)
    f.show('imm', outs, 5)
    sl = f.slot(64)
    p0 = f.tmp('p')
    f.e('sa %s %s' % (p0, sl))
    for k in range(8):
        v = f.li(11 * (k + 1))
        f.e('sti %s %s - 0 %d' % (v, p0, 8 * k))
    k24 = f.li(24)
    p1 = f.tmp('p')
    f.e('padd %s %s %s' % (p1, p0, k24))
    k8 = f.li(8)
    f.e('padd %s %s %s' % (p1, p1, k8))
    r1 = f.tmp('i')
    f.e('ldi %s %s - 0 0' % (r1, p1))
    m16 = f.li(-16)
    p2 = f.tmp('p')
    f.e('padd %s %s %s' % (p2, p1, m16))
    r2 = f.tmp('i')
    f.e('ldi %s %s - 0 8' % (r2, p2))
    f.show('padd', [r1, r2], 6)
    # itof: d holds an older value first
    outs = []
    for v in (-3, 2**53 + 1, 2**63 - 1, -2**63, 0, 2**53 + 3):
        a = computed(f, v)
        d = f.lf(99.0)
        f.e('itof %s %s' % (d, a))
        outs.append(d)
    f.show('itof', outs, 7)
    # fabs, fneg, d = a and d separate
    outs = []
    for xv in (-0.0, 0.0, -1.5, 2.5, INF, -INF, NAN):
        a = fcomputed(f, xv)
        for op in ('fabs', 'fneg'):
            r = f.tmp('f')
            f.e('%s %s %s' % (op, r, a))
            outs.append(r)
        r = f.tmp('f')
        f.e('mov %s %s' % (r, a))
        f.e('fneg %s %s' % (r, r))
        f.e('fabs %s %s' % (r, r))
        outs.append(r)
        r = f.tmp('f')
        f.e('mov %s %s' % (r, a))
        f.e('fneg %s %s' % (r, r))
        outs.append(r)
    f.show('fabs-fneg', outs, 8)
    # f64 two-address cases
    for op in ('fadd', 'fsub', 'fmul', 'fdiv'):
        a = fcomputed(f, 7.5)
        b = fcomputed(f, -2.0)
        r = f.tmp('f')
        f.e('%s %s %s %s' % (op, r, a, b))
        ra = f.tmp('f')
        f.e('mov %s %s' % (ra, a))
        f.e('%s %s %s %s' % (op, ra, ra, b))
        rb = f.tmp('f')
        f.e('mov %s %s' % (rb, b))
        f.e('%s %s %s %s' % (op, rb, a, rb))
        rr = f.tmp('f')
        f.e('mov %s %s' % (rr, a))
        f.e('%s %s %s %s' % (op, rr, rr, rr))
        f.show(op, [r, ra, rb, rr], 9)
    fs = fcomputed(f, 2.25)
    r = f.tmp('f')
    f.e('fsqrt %s %s' % (r, fs))
    f.e('fsqrt %s %s' % (fs, fs))
    f.show('fsqrt', [r, fs], 9)
    # selections: condition fused (icmp, fcmp) or a register; d = a, d = b, d separate
    for cval in (0, 1):
        outs = []
        c = computed(f, cval)
        a = computed(f, 111)
        b = computed(f, 222)
        fa = fcomputed(f, 1.25)
        fb = fcomputed(f, -8.5)
        sl1 = f.slot(8)
        sl2 = f.slot(8)
        pa = f.tmp('p')
        pb = f.tmp('p')
        f.e('sa %s %s' % (pa, sl1))
        f.e('sa %s %s' % (pb, sl2))
        f.e('sti %s %s - 0 0' % (a, pa))
        f.e('sti %s %s - 0 0' % (b, pb))
        for form in ('reg', 'icmp', 'fcmpgt', 'fcmpeq', 'fcmpne'):
            for dk in ('new', 'a', 'b'):
                for cls in ('i', 'f', 'p'):
                    if form == 'reg':
                        cc = c
                    else:
                        cc = f.tmp('i')
                        if form == 'icmp':
                            z = f.li(0)
                            f.e('icmp ne %s %s %s' % (cc, c, z))
                        else:
                            fc = f.tmp('f')
                            f.e('itof %s %s' % (fc, c))
                            ref = fcomputed(f, {'fcmpgt': 0.5, 'fcmpeq': 1.0, 'fcmpne': 0.0}[form])
                            f.e('fcmp %s %s %s %s' % (form[4:], cc, fc, ref))
                    x, y = {'i': (a, b), 'f': (fa, fb), 'p': (pa, pb)}[cls]
                    d = f.tmp(cls)
                    if dk == 'a':
                        f.e('mov %s %s' % (d, x))
                        x = d
                    elif dk == 'b':
                        f.e('mov %s %s' % (d, y))
                        y = d
                    f.e('%ssel %s %s %s %s' % (cls, d, cc, x, y))
                    if cls == 'p':
                        r = f.tmp('i')
                        f.e('ldi %s %s - 0 0' % (r, d))
                        outs.append(r)
                    else:
                        outs.append(d)
        f.show('sel%d' % cval, outs, 10)
    f.e('ret 0')
    return t


# ------------------------------------------------------------------ address forms
@test
def ra5_addr():
    t = Test('ra5_addr')
    f = t.func('.main', 'main', line=1)
    NEL = 5200
    ek = f.li(2)
    rk = f.li(1)
    rows = f.li(NEL)
    cols = f.li(1)
    f.e('rcall sea_arr_new 0:2 1 p.arr 4 %s %s %s %s' % (ek, rk, rows, cols))
    f.e('ldp p.d p.arr - 0 40')
    # fill element k with 3k + 1 through an index register of scale 8
    one = f.li(1)
    zero = f.li(0)
    last = f.li(NEL - 1)
    three = f.li(3)
    b = f.blk()
    f.e('loop %s i.k %s %s %s' % (b, zero, last, one))
    f.e('imul i.v i.k %s' % three)
    f.e('iadd i.v i.v %s' % one)
    f.e('sti i.v p.d i.k 8 0')
    f.e('endloop %s' % b)
    outs = []
    # offsets only: 0, 8, 32760 (4095 * 8), 32768, 33592
    for off in (0, 8, 32760, 32768, 33592, 4096, 4095 * 8 + 8):
        r = f.tmp('i')
        f.e('ldi %s p.d - 0 %d' % (r, off))
        outs.append(r)
    f.show('off', outs, 3)
    # negative offsets from a moved base
    k32 = f.li(32768)
    f.e('padd p.m p.d %s' % k32)
    outs = []
    for off in (-8, -256, -264, -4096, -4104, -32768):
        r = f.tmp('i')
        f.e('ldi %s p.m - 0 %d' % (r, off))
        outs.append(r)
    f.show('neg', outs, 4)
    # index with scales 1, 2, 3, 8, 16, 24 and offsets
    outs = []
    for idx, scale, off in ((16, 1, 0), (8, 2, 8), (40, 3, 0), (100, 8, 0), (100, 8, 16),
                            (50, 16, 8), (5, 24, 4096), (7, 24, 0), (1000, 8, 32768), (-3, 8, 32),
                            (-1, 24, 48)):
        x = computed(f, idx)
        r = f.tmp('i')
        f.e('ldi %s p.d %s %d %d' % (r, x, scale, off))
        outs.append(r)
    f.show('idx', outs, 5)
    # offsets beyond 32 bits: a base moved by -(2^31 + 16), resp. -(2^31 - 8), loaded back
    kbig = f.li(-(2**31 + 16))
    f.e('padd p.f p.d %s' % kbig)
    ksmall = f.li(-(2**31 - 8))
    f.e('padd p.g p.d %s' % ksmall)
    x9 = computed(f, 9)
    outs = []
    f.e('ldi i.b1 p.f - 0 %s' % (ifield(2**31 + 16)))
    f.e('ldi i.b2 p.g - 0 %s' % (ifield(2**31 - 8)))
    f.e('ldi i.b3 p.f %s 8 %s' % (x9, ifield(2**31 + 16)))
    f.e('ldi i.b4 p.g %s 8 %s' % (x9, ifield(2**31 - 8)))
    f.e('ldi i.b5 p.f %s 24 %s' % (x9, ifield(2**31 + 16)))
    outs += ['i.b1', 'i.b2', 'i.b3', 'i.b4', 'i.b5']
    f.show('big', outs, 6)
    # stores in the same forms, read back plainly
    vals = []
    for n, (idx, scale, off) in enumerate(((3, 24, 4096), (2, 16, 32768), (11, 8, 0), (None, 0, 33592))):
        v = f.li(-1000 - n)
        if idx is None:
            f.e('sti %s p.d - 0 %s' % (v, off))
        else:
            x = computed(f, idx)
            f.e('sti %s p.d %s %d %s' % (v, x, scale, off))
    f.e('sti %s p.f %s 8 %s' % (f.li(-2000), x9, ifield(2**31 + 16)))
    f.e('sti %s p.g - 0 %s' % (f.li(-2001), ifield(2**31)))
    for off in (3 * 24 + 4096, 2 * 16 + 32768, 88, 33592, 72, 16):
        r = f.tmp('i')
        f.e('ldi %s p.d - 0 %d' % (r, off))
        vals.append(r)
    f.show('st', vals, 7)
    # bytes and f64 through the same forms
    by = f.li(0x1FE)
    x5 = computed(f, 5)
    f.e('stb %s p.d %s 1 8' % (by, x5))
    f.e('ldb i.c1 p.d %s 1 8' % x5)
    f.e('ldb i.c2 p.d - 0 13')
    f.e('ldb i.c3 p.d - 0 14')
    f.e('ldi i.c4 p.d - 0 8')
    fv = f.lf(-6.5)
    f.e('stf %s p.d %s 24 %d' % (fv, x5, 32768))
    f.e('ldf f.c5 p.d - 0 %d' % (5 * 24 + 32768))
    f.e('ldf f.c6 p.m %s 24 0' % x5)
    f.show('byte', ['i.c1', 'i.c2', 'i.c3', 'i.c4', 'f.c5', 'f.c6'], 8)
    f.e('release p.arr')
    f.e('ret 0')
    return t


# ------------------------------------------------------------------ checked multiply, d = a, overflow
@test
def ra5_ovf():
    t = Test('ra5_ovf')
    f = t.func('.main', 'main', line=1)
    a = computed(f, 2**31, 'i.a')
    b = computed(f, 2**31 - 1, 'i.b')
    f.e('imulc i.a i.a i.b 0:2')
    f.show('ok', ['i.a', 'i.b'], 3)
    f.e('imulc i.b i.a i.b 0:5')
    f.show('unreached', ['i.b'], 6)
    f.e('ret 0')
    return t


# ------------------------------------------------------------------ Decision 75: loop liveness
# The ra5_live_* tests (DESIGN.md 6.2, from 5c-2): loops whose values are live only inside one
# iteration (temporaries of if parts, values written in both parts of an if, the temporaries of
# sibling copies of a loop) and values carried around a loop inside an if part. Each has more
# such values than x86_64's 10 allocatable general registers would hold if they were extended
# over the loop (4.9.2's first rule), and its measured loop must have no frame access in the -S
# text of both targets; the .out checks the values.
LIVE_N = 200


def live_chain(f, seed, k, n, tag):
    """n temporaries of one if part, computed from k and each read soon after it is written
    (at most three live at once); returns the last one."""
    prev = seed
    for j in range(n):
        r = 'i.%s%d' % (tag, j)
        m = j % 4
        if m == 0:
            f.e('imul %s %s %s' % (r, prev, f.li(3 + 2 * j)))
        elif m == 1:
            f.e('iadd %s %s %s' % (r, prev, k))
        elif m == 2:
            f.e('ixor %s %s %s' % (r, prev, f.li(0x5A5A + 97 * j)))
        else:
            f.e('isar %s %s %s' % (r, prev, f.li(1 + j % 5)))
        prev = r
    return prev


@test
def ra5_live_ifs():
    """a loop whose if parts compute temporaries: 12 in the first part, 12 in the else part."""
    t = Test('ra5_live_ifs')
    f = t.func('.main', 'main', line=1)
    f.li(0, 'i.zero')
    f.li(1, 'i.one')
    f.li(LIVE_N - 1, 'i.last')
    f.li(0, 'i.acc')
    b = f.blk()
    c = f.blk()
    f.e('loop %s i.k i.zero i.last i.one' % b)
    f.e('iand i.c i.k i.one')
    f.e('if %s i.c' % c)
    r = live_chain(f, 'i.k', 'i.k', 12, 'a')
    f.e('iadd i.acc i.acc %s' % r)
    f.e('else %s' % c)
    r = live_chain(f, 'i.k', 'i.k', 12, 'b')
    f.e('ixor i.acc i.acc %s' % r)
    f.e('endif %s' % c)
    f.e('endloop %s' % b)
    f.show('acc', ['i.acc'], 2)
    f.e('ret 0')
    return t


@test
def ra5_live_carry():
    """values carried around the loop inside if parts (m, p, read before they are written in
    the iteration), among 20 temporaries of the same parts."""
    t = Test('ra5_live_carry')
    f = t.func('.main', 'main', line=1)
    f.li(0, 'i.zero')
    f.li(1, 'i.one')
    f.li(LIVE_N - 1, 'i.last')
    f.li(7, 'i.m')
    f.li(-3, 'i.p')
    f.li(0, 'i.acc')
    b = f.blk()
    c1 = f.blk()
    c2 = f.blk()
    f.e('loop %s i.k i.zero i.last i.one' % b)
    f.e('iand i.c i.k %s' % f.li(3))
    f.e('ifz %s i.c' % c1)
    r = live_chain(f, 'i.m', 'i.k', 10, 'a')
    f.e('iadd i.m i.m %s' % r)
    f.e('endif %s' % c1)
    f.e('iand i.d i.k i.one')
    f.e('if %s i.d' % c2)
    r = live_chain(f, 'i.p', 'i.k', 10, 'b')
    f.e('ixor i.p i.p %s' % r)
    f.e('endif %s' % c2)
    f.e('iadd i.acc i.acc i.c')
    f.e('endloop %s' % b)
    f.show('carry', ['i.m', 'i.p', 'i.acc'], 2)
    f.e('ret 0')
    return t


@test
def ra5_live_both():
    """12 values each written in both parts of an if and read after its endif (L-bh)."""
    t = Test('ra5_live_both')
    f = t.func('.main', 'main', line=1)
    f.li(0, 'i.zero')
    f.li(1, 'i.one')
    f.li(LIVE_N - 1, 'i.last')
    f.li(0, 'i.acc')
    b = f.blk()
    f.e('loop %s i.k i.zero i.last i.one' % b)
    for j in range(12):
        c = f.blk()
        x = 'i.x%d' % j
        f.e('ishr i.s%d i.k %s' % (j, f.li(j % 6)))
        f.e('iand i.c%d i.s%d i.one' % (j, j))
        f.e('%s %s i.c%d' % ('if' if j % 2 == 0 else 'ifz', c, j))
        f.e('iadd %s i.k %s' % (x, f.li(11 * j + 5)))
        f.e('else %s' % c)
        f.e('imul %s i.k %s' % (x, f.li(j + 2)))
        f.e('endif %s' % c)
        f.e('%s i.acc i.acc %s' % ('iadd' if j % 3 else 'ixor', x))
    f.e('endloop %s' % b)
    f.show('both', ['i.acc'], 2)
    f.e('ret 0')
    return t


@test
def ra5_live_copies():
    """two sibling copies of an inner loop inside an outer loop, as T6 and T9 make them (L-bl:
    each copy's local registers numbered apart; the values written before the copies shared;
    each copy's pointer computed in its own arm, L-bm)."""
    t = Test('ra5_live_copies')
    f = t.func('.main', 'main', line=1)
    n = 16
    s = f.slot(8 * (n + 1))
    f.e('sa p.base %s' % s)
    for j in range(n + 1):
        f.e('sti %s p.base - 0 %d' % (f.li(1000 * j + 37 * j * j - 500), 8 * j))
    f.li(0, 'i.zero')
    f.li(1, 'i.one')
    f.li(n - 1, 'i.nl')
    f.li(9, 'i.rl')
    f.li(0, 'i.acc')
    bo = f.blk()
    bc = f.blk()
    f.e('loop %s i.r i.zero i.rl i.one' % bo)
    f.e('iand i.f i.r i.one')
    f.e('if %s i.f' % bc)
    f.e('sa p.a1 %s' % s)
    b1 = f.blk()
    f.e('loop %s i.j1 i.zero i.nl i.one' % b1)
    f.e('ldi i.v1 p.a1 i.j1 8 0')
    r = live_chain(f, 'i.v1', 'i.j1', 12, 'a')
    f.e('iadd i.acc i.acc %s' % r)
    f.e('endloop %s' % b1)
    f.e('else %s' % bc)
    f.e('sa p.a2 %s' % s)
    f.e('padd p.a3 p.a2 %s' % f.li(8))
    b2 = f.blk()
    f.e('loop %s i.j2 i.zero i.nl i.one' % b2)
    f.e('ldi i.v2 p.a3 i.j2 8 0')
    r = live_chain(f, 'i.v2', 'i.j2', 12, 'b')
    f.e('ixor i.acc i.acc %s' % r)
    f.e('endloop %s' % b2)
    f.e('endif %s' % bc)
    f.e('endloop %s' % bo)
    f.show('copies', ['i.acc'], 2)
    f.e('ret 0')
    return t


HERE = os.path.dirname(os.path.abspath(__file__))
PASSES = os.path.join(os.path.dirname(HERE), 'passes')


def main():
    outdir = PASSES
    for fn in TESTS:
        t = fn()
        text = t.render()
        out, err, status = Interp(text).run()
        base = os.path.join(outdir, t.name)
        with open(base + '.lir', 'w') as fh:
            fh.write(text)
        with open(base + '.out', 'w') as fh:
            fh.write(out)
        for ext, content, present in (('.err', err, bool(err)), ('.status', '%d\n' % status, status != 0)):
            if present:
                with open(base + ext, 'w') as fh:
                    fh.write(content)
            elif os.path.exists(base + ext):
                os.remove(base + ext)
        print('%-16s %6d lines  status %d' % (t.name, text.count('\n'), status))


if __name__ == '__main__':
    main()
