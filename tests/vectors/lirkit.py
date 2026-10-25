"""A builder for hand-written sea.lir tests and an independent interpreter of the LIR semantics
of DESIGN.md 3.6 (the subset the ra5_* tests of tests/vectors/ra5_gen.py use).

Test/Func write LIR with symbolic names (`i.x`, `B.b1`, `S.s1`, `D.l1`) that render() renumbers
as 3.6.1-3.6.3 require: registers from 1 per function in order of first appearance (parameters
first), blocks in opening order, slots in order, data labels d1, d2, ... in order of first
reference with the data records after the last function in label order; fields as 3.1 writes them.
Interp runs the rendered text: 3.6.4's instructions, loop/do/if/exit/next, call/ret, the entries
sea_printf (LANGUAGE.md 11.1: %d of i64 and of f64, %.17g, %s, MATLAB NaN/Inf spelling) and
sea_arr_new (4.8 layout), retain/release, and the run-time errors (`<file>:<line>: error: <text of
errors.inc>`, status 1). It computes the expected output from the LIR alone; it never runs a code
generator.
"""
import math
import re
import struct

M64 = (1 << 64) - 1


def w64(x):
    x &= M64
    return x - (1 << 64) if x >= (1 << 63) else x


def u64(x):
    return x & M64


def fbits(x):
    return struct.unpack('<Q', struct.pack('<d', x))[0]


def bitsf(b):
    return struct.unpack('<d', struct.pack('<Q', b & M64))[0]


def ifield(v):
    v = w64(v)
    if -10**9 < v < 10**9:
        return str(v)
    return '#%016X' % u64(v)


def ffield(x):
    if isinstance(x, int):
        return '#%016X' % x          # raw bits
    return '#%016X' % fbits(x)


def esc(s):
    out = []
    for ch in s.encode():
        if 0x21 <= ch <= 0x7E and ch != 0x25:
            out.append(chr(ch))
        else:
            out.append('%%%02X' % ch)
    return ''.join(out) if out else '%'


NAN = float('nan')
INF = float('inf')


# ---------------------------------------------------------------- builder
class Func:
    def __init__(self, test, name, kind, params, rescls, line):
        self.test = test
        self.name = name
        self.kind = kind
        self.params = params            # symbolic registers like 'i.a'
        self.rescls = rescls
        self.line = line
        self.slots = []
        self.body = []
        self.nslot = 0
        self.nblk = 0
        self.ntmp = 0

    def e(self, s):
        self.body.append(s)

    def slot(self, size, align=8):
        self.nslot += 1
        nm = 'S.s%d' % self.nslot
        self.slots.append('slot %s %d %d' % (nm, size, align))
        return nm

    def blk(self):
        self.nblk += 1
        return 'B.b%d' % self.nblk

    def tmp(self, cls):
        self.ntmp += 1
        return '%s.t%d' % (cls, self.ntmp)

    def li(self, v, r=None):
        r = r or self.tmp('i')
        self.e('li %s %s' % (r, ifield(v)))
        return r

    def lf(self, v, r=None):
        r = r or self.tmp('f')
        self.e('lf %s %s' % (r, ffield(v)))
        return r

    def printf(self, pieces, args, line):
        """pieces: list of strings (text) and (conv, cls, prec) tuples; args: registers."""
        n = max(1, len(args))
        s = self.slot(8 * n)
        p = self.tmp('p')
        self.e('sa %s %s' % (p, s))
        for k, a in enumerate(args):
            op = {'i': 'sti', 'f': 'stf', 'p': 'stp'}[a[0]]
            self.e('%s %s %s - 0 %d' % (op, a, p, 8 * k))
        lab = self.test.fmt(pieces)
        q = self.tmp('p')
        self.e('la %s %s' % (q, lab))
        self.e('rcall sea_printf 0:%d 0 2 %s %s' % (line, q, p))

    def show(self, title, args, line):
        """one output line: title, then each argument (i: %d, f: %.17g, p: %s)."""
        pieces = [title]
        for a in args:
            pieces.append(' ')
            if a[0] == 'i':
                pieces.append(('d', 'i', None))
            elif a[0] == 'f':
                pieces.append(('g', 'f', 17))
            else:
                pieces.append(('s', 'p', None))
        pieces.append('\n')
        self.printf(pieces, args, line)


class Test:
    def __init__(self, name):
        self.name = name
        self.funcs = []
        self.data = []      # (symbolic label, [records])
        self.nlab = 0

    def func(self, name, kind='fn', params=(), rescls=(), line=1):
        f = Func(self, name, kind, list(params), list(rescls), line)
        self.funcs.append(f)
        return f

    def fmt(self, pieces):
        recs = []
        for pc in pieces:
            if isinstance(pc, str):
                recs.append('ftext ' + esc(pc))
            else:
                conv, cls, prec = pc
                recs.append('fconv - - %s %s %s' % ('-' if prec is None else str(prec), conv, cls))
        self.nlab += 1
        lab = 'D.l%d' % self.nlab
        self.data.append((lab, ['fmt %s %d' % (lab, len(recs))] + recs))
        return lab

    def strlab(self, text):
        self.nlab += 1
        lab = 'D.l%d' % self.nlab
        self.data.append((lab, ['str %s %s' % (lab, esc(text))]))
        return lab

    def render(self, target='arm64-macos'):
        out = ['#sea 1', '#target ' + target, '#file %s.sea' % self.name]
        labmap = {}

        def lab(m):
            k = m.group(0)
            if k not in labmap:
                labmap[k] = 'd%d' % (len(labmap) + 1)
            return labmap[k]

        for f in self.funcs:
            regmap = {}
            blkmap = {}
            slotmap = {}

            def reg(m):
                k = m.group(0)
                if k not in regmap:
                    regmap[k] = '%s%d' % (m.group(1), len(regmap) + 1)
                return regmap[k]

            def blk(m):
                k = m.group(0)
                if k not in blkmap:
                    blkmap[k] = str(len(blkmap) + 1)
                return blkmap[k]

            def slt(m):
                k = m.group(0)
                if k not in slotmap:
                    slotmap[k] = 's%d' % (len(slotmap) + 1)
                return slotmap[k]

            hdr = 'func %s %s 0:%d:1 %d %s %d %s' % (
                f.name, f.kind, f.line, len(f.params), ' '.join(f.params), len(f.rescls),
                ' '.join(f.rescls))
            hdr = re.sub(r'\s+', ' ', hdr).strip()
            lines = [hdr] + f.slots + f.body
            for ln in lines:
                ln = re.sub(r'\b([ifp])\.[A-Za-z0-9_]+', reg, ln)
                ln = re.sub(r'\bB\.[A-Za-z0-9_]+', blk, ln)
                ln = re.sub(r'\bS\.[A-Za-z0-9_]+', slt, ln)
                ln = re.sub(r'\bD\.[A-Za-z0-9_]+', lab, ln)
                out.append(ln)
            out.append('endfunc')
        # data records in label order (unreferenced labels follow)
        order = sorted(self.data, key=lambda d: int(labmap[d[0]][1:]) if d[0] in labmap else 10**9)
        for sym, recs in order:
            if sym not in labmap:
                labmap[sym] = 'd%d' % (len(labmap) + 1)
            for r in recs:
                out.append(re.sub(r'\bD\.[A-Za-z0-9_]+', lambda m: labmap[m.group(0)], r))
        out.append('#end')
        return '\n'.join(out) + '\n'


# ---------------------------------------------------------------- interpreter
class SeaError(Exception):
    def __init__(self, line, msg):
        self.line = line
        self.msg = msg


class Region:
    def __init__(self, size, kind):
        self.b = bytearray(size)
        self.ptrs = {}
        self.kind = kind
        self.text = None
        self.fmt = None
        self.freed = False


def rd8(reg, off):
    p_region = reg
    if off < 0 or off + 8 > len(p_region.b):
        raise RuntimeError('load out of region at %d' % off)
    return int.from_bytes(p_region.b[off:off + 8], 'little', signed=True)


def wr8(region, off, v):
    if off < 0 or off + 8 > len(region.b):
        raise RuntimeError('store out of region at %d' % off)
    region.b[off:off + 8] = u64(v).to_bytes(8, 'little')
    region.ptrs.pop(off, None)


def fdiv(a, b):
    if b == 0.0:
        if a != a or a == 0.0:
            return NAN
        neg = (math.copysign(1, a) < 0) != (math.copysign(1, b) < 0)
        return -INF if neg else INF
    return a / b


def fround_like(x, mode):
    if x != x or x in (INF, -INF) or abs(x) >= 2.0**52:
        return x
    if mode == 'floor':
        r = float(math.floor(x))
    elif mode == 'ceil':
        r = float(math.ceil(x))
    elif mode == 'trunc':
        r = float(math.trunc(x))
    else:   # round half away from zero
        t = math.floor(abs(x))
        if abs(x) - t >= 0.5:
            t += 1
        r = float(t)
        r = -r if x < 0 else r
    if r == 0.0:
        r = math.copysign(0.0, x)
    return r


def fmt_g17(x):
    if x != x:
        return 'NaN'
    if x == INF:
        return 'Inf'
    if x == -INF:
        return '-Inf'
    return '%.17g' % x


def fmt_d_f(x):
    if x != x:
        return 'NaN'
    if x == INF:
        return 'Inf'
    if x == -INF:
        return '-Inf'
    if x == math.floor(x):
        return str(int(x))
    return '%e' % x


def unesc(s):
    if s == '%':
        return ''
    out = bytearray()
    i = 0
    while i < len(s):
        if s[i] == '%':
            out.append(int(s[i + 1:i + 3], 16))
            i += 3
        else:
            out.append(ord(s[i]))
            i += 1
    return out.decode()


def parse_i(t):
    if t.startswith('#'):
        return w64(int(t[1:], 16))
    return int(t)


def parse_f(t):
    return bitsf(int(t[1:], 16))


def rcount_n(lo, hi, st, incl):
    if st > 0:
        if incl:
            return (hi - lo) // st + 1 if hi >= lo else 0
        return -((lo - hi) // st) if hi > lo else 0
    else:
        if incl:
            return (lo - hi) // (-st) + 1 if lo >= hi else 0
        return -((hi - lo) // (-st)) if lo > hi else 0


class Interp:
    def __init__(self, text):
        self.lines = text.split('\n')
        self.funcs = {}
        self.labels = {}
        self.out = []
        self.filename = None
        self.parse()

    def parse(self):
        i = 0
        L = self.lines
        while i < len(L):
            ln = L[i]
            t = ln.split()
            if not t:
                i += 1
                continue
            if t[0] == '#file':
                self.filename = t[1]
            elif t[0] == 'func':
                np_ = int(t[4])
                params = t[5:5 + np_]
                nr = int(t[5 + np_])
                body = []
                slots = {}
                i += 1
                while L[i].split()[0] != 'endfunc':
                    tt = L[i].split()
                    if tt[0] == 'slot':
                        slots[tt[1]] = int(tt[2])
                    else:
                        body.append(tt)
                    i += 1
                self.funcs[t[1]] = (params, nr, slots, body, self.structure(body))
            elif t[0] in ('fmt',):
                lab = t[1]
                k = int(t[2])
                pieces = []
                for j in range(k):
                    i += 1
                    tt = L[i].split()
                    if tt[0] == 'ftext':
                        pieces.append(unesc(tt[1]))
                    else:
                        pieces.append((tt[1], tt[2], tt[3], tt[4], tt[5]))
                r = Region(8, 'fmt')
                r.fmt = pieces
                self.labels[lab] = r
            elif t[0] == 'str':
                txt = unesc(t[2])
                r = Region(24 + len(txt.encode()), 'str')
                r.text = txt
                wr8(r, 0, 0)
                r.b[8] = 2
                wr8(r, 16, len(txt.encode()))
                self.labels[t[1]] = r
            elif t[0] == 'dat':
                lab = t[1]
                n = int(t[3])
                r = Region(8 * max(n, 1), 'dat')
                for j in range(n):
                    i += 1
                    tt = L[i].split()
                    if tt[0] == 'dvi':
                        wr8(r, 8 * j, parse_i(tt[1]))
                    else:
                        wr8(r, 8 * j, int(tt[1][1:], 16))
                self.labels[lab] = r
            i += 1

    @staticmethod
    def structure(body):
        opn, els, end, kind = {}, {}, {}, {}
        for idx, t in enumerate(body):
            op = t[0]
            if op in ('loop', 'do', 'if', 'ifz'):
                opn[t[1]] = idx
                kind[t[1]] = op
            elif op == 'else':
                els[t[1]] = idx
            elif op in ('endloop', 'enddo', 'endif'):
                end[t[1]] = idx
        return opn, els, end, kind

    def err(self, site, msg):
        raise SeaError(int(site.split(':')[1]), msg)

    def run(self):
        try:
            self.call('.main', [])
            return ''.join(self.out), '', 0
        except SeaError as e:
            return ''.join(self.out), '%s:%d: error: %s\n' % (self.filename, e.line, e.msg), 1

    def call(self, name, args):
        params, nr, slots, body, (opn, els, end, kind) = self.funcs[name]
        R = {}
        for p, a in zip(params, args):
            R[p] = a
        S = {s: Region(sz, 'slot') for s, sz in slots.items()}
        LS = {}
        pc = 0
        while True:
            t = body[pc]
            op = t[0]
            pc += 1
            if op == 'li':
                R[t[1]] = parse_i(t[2])
            elif op == 'lf':
                R[t[1]] = parse_f(t[2])
            elif op == 'la':
                R[t[1]] = (self.labels[t[2]], 0)
            elif op == 'sa':
                R[t[1]] = (S[t[2]], 0)
            elif op == 'mov':
                R[t[1]] = R[t[2]]
            elif op in ('iadd', 'isub', 'imul', 'iand', 'ior', 'ixor', 'imulh', 'ishl', 'ishr', 'isar'):
                a, b = R[t[2]], R[t[3]]
                if op == 'iadd':
                    v = a + b
                elif op == 'isub':
                    v = a - b
                elif op == 'imul':
                    v = a * b
                elif op == 'iand':
                    v = a & b
                elif op == 'ior':
                    v = a | b
                elif op == 'ixor':
                    v = a ^ b
                elif op == 'imulh':
                    v = (a * b) >> 64
                elif op == 'ishl':
                    assert 0 <= b <= 63
                    v = a << b
                elif op == 'ishr':
                    assert 0 <= b <= 63
                    v = u64(a) >> b
                else:
                    assert 0 <= b <= 63
                    v = a >> b
                R[t[1]] = w64(v)
            elif op in ('iaddc', 'isubc', 'imulc'):
                a, b = R[t[2]], R[t[3]]
                v = a + b if op == 'iaddc' else a - b if op == 'isubc' else a * b
                if v != w64(v):
                    self.err(t[4], 'integer overflow')
                R[t[1]] = v
            elif op == 'ineg':
                R[t[1]] = w64(-R[t[2]])
            elif op == 'inegc':
                v = -R[t[2]]
                if v != w64(v):
                    self.err(t[3], 'integer overflow')
                R[t[1]] = v
            elif op in ('idivf', 'imodf'):
                a, b = R[t[2]], R[t[3]]
                if b == 0:
                    self.err(t[4], 'integer division by zero')
                if op == 'idivf':
                    q = a // b
                    if q != w64(q):
                        self.err(t[4], 'integer overflow')
                    R[t[1]] = q
                else:
                    R[t[1]] = a % b
            elif op == 'bnot':
                R[t[1]] = 1 if R[t[2]] == 0 else 0
            elif op == 'icmp':
                a, b = R[t[3]], R[t[4]]
                R[t[2]] = int({'eq': a == b, 'ne': a != b, 'lt': a < b, 'le': a <= b,
                               'gt': a > b, 'ge': a >= b}[t[1]])
            elif op == 'fcmp':
                a, b = R[t[3]], R[t[4]]
                R[t[2]] = int({'eq': a == b, 'ne': a != b, 'lt': a < b, 'le': a <= b,
                               'gt': a > b, 'ge': a >= b}[t[1]])
            elif op in ('isel', 'fsel', 'psel'):
                R[t[1]] = R[t[3]] if R[t[2]] != 0 else R[t[4]]
            elif op == 'rcount':
                lo, hi, st, incl = R[t[3]], R[t[4]], R[t[5]], int(t[6])
                if st == 0:
                    self.err(t[7], 'range step is zero')
                n = rcount_n(lo, hi, st, incl)
                assert 0 <= n <= (1 << 64)
                R[t[1]] = w64(n - 1) if n > 0 else 0
                R[t[2]] = 1 if n > 0 else 0
            elif op in ('fadd', 'fsub', 'fmul', 'fdiv'):
                a, b = R[t[2]], R[t[3]]
                if op == 'fadd':
                    v = a + b
                elif op == 'fsub':
                    v = a - b
                elif op == 'fmul':
                    v = a * b
                else:
                    v = fdiv(a, b)
                R[t[1]] = v
            elif op == 'fneg':
                R[t[1]] = -R[t[2]]
            elif op == 'fabs':
                R[t[1]] = abs(R[t[2]])
            elif op == 'fsqrt':
                a = R[t[2]]
                R[t[1]] = math.sqrt(a) if a >= 0 or a != a else NAN
                if a != a:
                    R[t[1]] = NAN
            elif op in ('fmin', 'fmax'):
                a, b = R[t[2]], R[t[3]]
                if a != a:
                    v = b
                elif b != b:
                    v = a
                elif op == 'fmin':
                    v = b if b < a else a
                else:
                    v = b if b > a else a
                R[t[1]] = v
            elif op in ('ffloor', 'fceil', 'ftrunc', 'fround'):
                R[t[1]] = fround_like(R[t[2]], op[1:])
            elif op == 'fnan':
                a = R[t[2]]
                R[t[1]] = 1 if a != a else 0
            elif op == 'itof':
                R[t[1]] = float(R[t[2]])
            elif op == 'ftoi':
                a = R[t[2]]
                if a != a or a in (INF, -INF) or a != math.floor(a) or not (-2.0**63 <= a < 2.0**63):
                    self.err(t[3], 'conversion to i64: %g is not an integer' % a)
                R[t[1]] = int(a)
            elif op == 'padd':
                reg, off = R[t[2]]
                R[t[1]] = (reg, w64(off + R[t[3]]))
            elif op in ('ldi', 'ldb', 'ldf', 'ldp', 'sti', 'stb', 'stf', 'stp'):
                reg, off = R[t[2]]
                idx = 0 if t[3] == '-' else R[t[3]]
                a = w64(off + idx * int(t[4]) + parse_i(t[5]))
                if op == 'ldi':
                    R[t[1]] = rd8(reg, a)
                elif op == 'ldb':
                    R[t[1]] = reg.b[a]
                elif op == 'ldf':
                    R[t[1]] = bitsf(rd8(reg, a))
                elif op == 'ldp':
                    R[t[1]] = reg.ptrs[a]
                elif op == 'sti':
                    wr8(reg, a, R[t[1]])
                elif op == 'stb':
                    reg.b[a] = R[t[1]] & 255
                    for o in list(reg.ptrs):
                        if o <= a < o + 8:
                            del reg.ptrs[o]
                elif op == 'stf':
                    wr8(reg, a, fbits(R[t[1]]))
                else:
                    wr8(reg, a, 0)
                    reg.ptrs[a] = R[t[1]]
            elif op == 'mcopy':
                dr, do = R[t[1]]
                sr, so = R[t[2]]
                n = R[t[3]]
                dr.b[do:do + n] = sr.b[so:so + n]
                for o, p in list(sr.ptrs.items()):
                    if so <= o and o + 8 <= so + n:
                        dr.ptrs[do + o - so] = p
            elif op == 'loop':
                b, ind = t[1], t[2]
                LS[b] = [0, u64(R[t[4]]), R[t[3]], R[t[5]], ind]
                R[ind] = R[t[3]]
            elif op == 'endloop':
                st = LS[t[1]]
                if st[0] == st[1]:
                    pass
                else:
                    st[0] += 1
                    R[st[4]] = w64(st[2] + st[0] * st[3])
                    pc = opn[t[1]] + 1
            elif op == 'next':
                b = t[1]
                if kind[b] == 'loop':
                    pc = end[b]
                else:
                    pc = opn[b] + 1
            elif op == 'exit':
                pc = end[t[1]] + 1
            elif op == 'do':
                pass
            elif op == 'enddo':
                pc = opn[t[1]] + 1
            elif op in ('if', 'ifz'):
                c = R[t[2]] != 0
                if op == 'ifz':
                    c = not c
                if not c:
                    b = t[1]
                    pc = (els[b] + 1) if b in els else end[b] + 1
            elif op == 'else':
                pc = end[t[1]] + 1
            elif op == 'endif':
                pass
            elif op == 'ret':
                n = int(t[1])
                return [R[x] for x in t[2:2 + n]]
            elif op == 'call':
                nr = int(t[2])
                ds = t[3:3 + nr]
                na = int(t[3 + nr])
                avals = [R[x] for x in t[4 + nr:4 + nr + na]]
                res = self.call(t[1], avals)
                for d, v in zip(ds, res):
                    R[d] = v
            elif op == 'rcall':
                ent = t[1]
                k = 2
                site = None
                if ent in ('sea_printf', 'sea_arr_new', 'sea_str_i64'):
                    site = t[2]
                    k = 3
                nr = int(t[k])
                ds = t[k + 1:k + 1 + nr]
                na = int(t[k + 1 + nr])
                avals = [R[x] for x in t[k + 2 + nr:k + 2 + nr + na]]
                res = self.rcall(ent, avals)
                for d, v in zip(ds, res):
                    R[d] = v
            elif op == 'chkb':
                idx, ext = R[t[1]], R[t[2]]
                if idx < 0 or idx >= ext:
                    self.err(t[4], 'index %d out of bounds for dimension %s of extent %d' % (idx, t[3], ext))
            elif op == 'retain':
                reg, off = R[t[1]]
                assert off == 0 and not reg.freed
                c = rd8(reg, 0)
                if c != 0:
                    wr8(reg, 0, c + 1)
            elif op == 'release':
                reg, off = R[t[1]]
                assert off == 0 and not reg.freed
                c = rd8(reg, 0)
                if c != 0:
                    wr8(reg, 0, c - 1)
                    if c == 1:
                        reg.freed = True
            else:
                raise RuntimeError('interp: unsupported %s' % op)

    def rcall(self, ent, a):
        if ent == 'sea_printf':
            fr, _ = a[0]
            ar, ao = a[1]
            s = []
            k = 0
            for pc in fr.fmt:
                if isinstance(pc, str):
                    s.append(pc)
                    continue
                fl, wd, pr, conv, cls = pc
                assert fl == '-' and wd == '-'
                if cls == 'i':
                    v = rd8(ar, ao + 8 * k)
                    assert conv == 'd' and pr == '-'
                    s.append(str(v))
                elif cls == 'f':
                    v = bitsf(rd8(ar, ao + 8 * k))
                    if conv == 'd':
                        s.append(fmt_d_f(v))
                    else:
                        assert conv == 'g' and pr == '17'
                        s.append(fmt_g17(v))
                else:
                    reg = ar.ptrs[ao + 8 * k][0]
                    s.append(reg.text)
                k += 1
            self.out.append(''.join(s))
            return []
        if ent == 'sea_arr_new':
            ek, rank, rows, cols = a
            es = {1: 8, 2: 8, 3: 1, 4: 8}[ek]
            r = Region(64 + rows * cols * es, 'arr')
            wr8(r, 0, 1)
            r.b[8] = 1
            r.b[9] = ek
            r.b[10] = rank
            wr8(r, 16, rows)
            wr8(r, 24, cols)
            wr8(r, 32, rows * cols)
            wr8(r, 40, 0)
            r.ptrs[40] = (r, 64)
            wr8(r, 48, es)
            wr8(r, 56, 0)
            return [(r, 0)]
        raise RuntimeError('interp: rcall %s' % ent)

