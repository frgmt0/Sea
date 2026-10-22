"""Sub-phase 4c pass-4 tests (DESIGN.md 6.2): hand-written LIR of retain, release, mcopy, slay/soff.

Run with `timeout 120 uv run python tests/vectors/lir4_gen.py`. It writes tests/passes/lir4_*.lir
(pass-4 tests: no .lir1, no .sea; stage.sh builds them with seagen_a64, cross_pack.sh retargets
them for seagen_x64) and their expected standard output lir4_*.out. The LIR follows DESIGN.md
3.6 (records 3.6.2-3.6.4; registers numbered from 1 per function in order of first appearance,
3.6.1; data labels d1, d2, ... in order of first reference, data records after the last function
in label order); the expected output follows from the semantics of 3.6.4 (retain/release/mcopy),
the object layouts and entry contracts of 4.8 (ids 9-20), the allocator of 4.1 (LIFO free lists)
and the printf rules of LANGUAGE.md 11.1 (only %d of i64 values and %s here, so the text is
plain decimal).
"""

import os
import struct

HERE = os.path.dirname(os.path.abspath(__file__))
PASSES = os.path.join(os.path.dirname(HERE), 'passes')

# rt.inc values (DESIGN.md 4.8)
EK_F64, EK_I64, EK_BOOL, EK_STR, EK_STRUCT = 1, 2, 3, 4, 5
ARR_RC, ARR_EK, ARR_RANK, ARR_ROWS, ARR_COLS, ARR_CAP, ARR_DATA, ARR_ESIZE, ARR_SLAY = (
    0, 9, 10, 16, 24, 32, 40, 48, 56)
ARR_SIZE = 64
SL_SIZE, SL_NREF, SL_REFS = 0, 8, 16
STR_RC = 0


def enc_i(v):
    """An i field (DESIGN.md 3.1): decimal when |v| < 10^9, else # and 16 hex digits."""
    return str(v) if -10 ** 9 < v < 10 ** 9 else '#%016X' % (v & ((1 << 64) - 1))


def esc(s):
    out = []
    for ch in s.encode():
        out.append(chr(ch) if 0x21 <= ch <= 0x7E and ch != 0x25 else '%%%02X' % ch)
    return ''.join(out) if out else '%'


class Prog:
    def __init__(self, name):
        self.name = name
        self.funcs = []
        self.data = []          # (label, [records]) in label order
        self.nlab = 0
        self.out = ''           # the expected standard output

    def label(self, records):
        self.nlab += 1
        lab = 'd%d' % self.nlab
        self.data.append((lab, [r.replace('LAB', lab) for r in records]))
        return lab

    def write(self):
        lines = ['#sea 1', '#target arm64-macos', '#file %s.sea' % self.name]
        for f in self.funcs:
            lines += f.render()
        for _, recs in self.data:
            lines += recs
        lines.append('#end')
        with open(os.path.join(PASSES, self.name + '.lir'), 'w') as fh:
            fh.write('\n'.join(lines) + '\n')
        with open(os.path.join(PASSES, self.name + '.out'), 'w') as fh:
            fh.write(self.out)


class Func:
    def __init__(self, prog, name, kind, line, params=(), nres=0):
        self.prog, self.name, self.kind, self.line = prog, name, kind, line
        self.n = 0
        self.slots = []
        self.body = []
        self.params = [self.reg(c) for c in params]
        self.nres = nres
        prog.funcs.append(self)

    def reg(self, cls):
        self.n += 1
        return '%s%d' % (cls, self.n)

    def slot(self, size, align=8):
        self.slots.append((size, align))
        return 's%d' % len(self.slots)

    def ins(self, s):
        self.body.append(s)

    def render(self):
        head = 'func %s %s 0:%d:1 %d%s 0' % (self.name, self.kind, self.line, len(self.params),
                                            ''.join(' ' + p for p in self.params))
        out = [head]
        out += ['slot s%d %d %d' % (i + 1, sz, al) for i, (sz, al) in enumerate(self.slots)]
        return out + self.body + ['endfunc']

    # helpers -----------------------------------------------------------------------------
    def li(self, v):
        r = self.reg('i')
        self.ins('li %s %s' % (r, enc_i(v)))
        return r

    def ldi(self, base, off):
        r = self.reg('i')
        self.ins('ldi %s %s - 0 %d' % (r, base, off))
        return r

    def ldb(self, base, off):
        r = self.reg('i')
        self.ins('ldb %s %s - 0 %d' % (r, base, off))
        return r

    def addr_bits(self, p):
        """The address in p as an i64: stored to an 8-byte slot with stp, loaded with ldi."""
        s = self.slot(8)
        a = self.reg('p')
        self.ins('sa %s %s' % (a, s))
        self.ins('stp %s %s - 0 0' % (p, a))
        return self.ldi(a, 0)

    def arr_new(self, line, ek, rank, rows, cols):
        args = [self.li(v) for v in (ek, rank, rows, cols)]
        r = self.reg('p')
        self.ins('rcall sea_arr_new 0:%d 1 %s 4 %s' % (line, r, ' '.join(args)))
        return r

    def printf(self, line, pieces, args):
        """pieces: text strings and conversion tuples ('d'|'s',); args: registers in order."""
        recs = ['fmt LAB %d' % len(pieces)]
        for p in pieces:
            if isinstance(p, tuple):
                recs.append('fconv - - - %s %s' % (p[0], 'i' if p[0] == 'd' else 'p'))
            else:
                recs.append('ftext ' + esc(p))
        s = self.slot(8 * max(len(args), 1))
        sp = self.reg('p')
        self.ins('sa %s %s' % (sp, s))
        for j, a in enumerate(args):
            op = 'sti' if a[0] == 'i' else 'stp'
            self.ins('%s %s %s - 0 %d' % (op, a, sp, 8 * j))
        fp = self.reg('p')
        lab = self.prog.label(recs)
        self.ins('la %s %s' % (fp, lab))
        self.ins('rcall sea_printf 0:%d 0 2 %s %s' % (line, fp, sp))


D = ('d',)
S = ('s',)


# ---------------------------------------------------------------- retain / release
def retain_release():
    p = Prog('lir4_retain_release')
    m = Func(p, '.main', 'main', 1)
    # a fresh array: count 1 (4.8 ARR_NEW); retain counts one more, release one fewer (3.6.4)
    a = m.arr_new(2, EK_F64, 1, 3, 1)
    c = [m.ldi(a, ARR_RC)]
    m.ins('retain %s' % a)
    c.append(m.ldi(a, ARR_RC))
    m.ins('retain %s' % a)
    c.append(m.ldi(a, ARR_RC))
    m.printf(3, ['fresh ', D, ' retained ', D, ' ', D, '\n'], c)
    expect = 'fresh 1 retained 2 3\n'
    # a shared object (count 3, then 2): release only decrements, the object stays
    m.ins('release %s' % a)
    c1 = m.ldi(a, ARR_RC)
    m.ins('release %s' % a)
    c2 = m.ldi(a, ARR_RC)
    m.printf(4, ['shared released ', D, ' ', D, '\n'], [c1, c2])
    expect += 'shared released 2 1\n'
    # the last release frees the block (sea_free); its 128-byte class (64 + 3 * 8 = 88 bytes)
    # has a LIFO free list (4.1), so the next array of that class, with no allocation between,
    # is the same block, again with count 1 and zeroed elements
    ab = m.addr_bits(a)
    m.ins('release %s' % a)
    b = m.arr_new(5, EK_I64, 1, 3, 1)
    bb = m.addr_bits(b)
    same = m.reg('i')
    m.ins('icmp eq %s %s %s' % (same, ab, bb))
    cb = m.ldi(b, ARR_RC)
    ekb = m.ldb(b, ARR_EK)
    e0 = m.ldi(b, ARR_SIZE + 0)
    e2 = m.ldi(b, ARR_SIZE + 16)
    m.printf(6, ['freed, same block ', D, ' count ', D, ' ek ', D, ' elements ', D, ' ', D,
                 '\n'], [same, cb, ekb, e0, e2])
    expect += 'freed, same block 1 count 1 ek %d elements 0 0\n' % EK_I64
    m.ins('release %s' % b)
    # a static object (a str record, count SEA_RC_STATIC = 0): neither changes it (4.8)
    s = m.reg('p')
    lab = p.label(['str LAB static'])
    m.ins('la %s %s' % (s, lab))
    s0 = m.ldi(s, STR_RC)
    m.ins('retain %s' % s)
    s1 = m.ldi(s, STR_RC)
    m.ins('release %s' % s)
    m.ins('release %s' % s)
    s2 = m.ldi(s, STR_RC)
    m.printf(7, [S, ' count ', D, ' ', D, ' ', D, '\n'], [s, s0, s1, s2])
    expect += 'static count 0 0 0\n'
    # a fresh string (STR_I64): count 1, freed by its release
    v = m.li(-9223372036854775807 - 1)
    t = m.reg('p')
    m.ins('rcall sea_str_i64 0:8 1 %s 1 %s' % (t, v))
    m.ins('retain %s' % t)
    t1 = m.ldi(t, STR_RC)
    m.ins('release %s' % t)
    t2 = m.ldi(t, STR_RC)
    m.printf(9, [S, ' count ', D, ' ', D, '\n'], [t, t1, t2])
    expect += '-9223372036854775808 count 2 1\n'
    m.ins('release %s' % t)
    m.ins('ret 0')
    p.out = expect
    p.write()


# ---------------------------------------------------------------- release in a leaf function
def release_leaf():
    p = Prog('lir4_release_leaf')
    m = Func(p, '.main', 'main', 1)
    drop = Func(p, 'drop', 'fn', 10, params=('p',))
    # drop has no call: its release alone makes it non-leaf (4.9: frame record, the 4.6 stack
    # check), so its `bl _sea_free` returns to drop and drop returns to its caller
    drop.ins('release %s' % drop.params[0])
    drop.ins('ret 0')
    a = m.arr_new(2, EK_STR, 1, 2, 1)
    m.ins('retain %s' % a)
    m.ins('call drop 0 1 %s' % a)          # count 2 -> 1: no free
    c = m.ldi(a, ARR_RC)
    m.printf(3, ['after one drop ', D, '\n'], [c])
    m.ins('call drop 0 1 %s' % a)          # count 1 -> 0: sea_free called from drop
    v = m.li(7)
    t = m.reg('p')
    m.ins('rcall sea_str_i64 0:4 1 %s 1 %s' % (t, v))
    m.printf(5, ['freed in drop, then ', S, '\n'], [t])
    m.ins('call drop 0 1 %s' % t)          # a string freed the same way
    m.printf(6, ['ok\n'], [])
    m.ins('ret 0')
    p.out = 'after one drop 1\nfreed in drop, then 7\nok\n'
    p.write()


# ---------------------------------------------------------------- mcopy
def mcopy():
    p = Prog('lir4_mcopy')
    m = Func(p, '.main', 'main', 1)
    src = bytes((k * 37 + 11) % 256 for k in range(128))
    words = struct.unpack('<16q', src)
    lab = p.label(['dat LAB i64 16'] + ['dvi ' + enc_i(w) for w in words])
    base = m.reg('p')
    m.ins('la %s %s' % (base, lab))
    soff, doff = 5, 3                       # unaligned source and destination (dat is 64-aligned)
    expect = ''
    for line, n in ((2, 0), (3, 7), (4, 8), (5, 9), (6, 100)):
        sl = m.slot(128, 8)
        d0 = m.reg('p')
        m.ins('sa %s %s' % (d0, sl))
        z = m.li(0)
        for w in range(16):                 # a known destination: 128 zero bytes
            m.ins('sti %s %s - 0 %d' % (z, d0, 8 * w))
        k = m.li(doff)
        d = m.reg('p')
        m.ins('padd %s %s %s' % (d, d0, k))
        k2 = m.li(soff)
        s = m.reg('p')
        m.ins('padd %s %s %s' % (s, base, k2))
        nn = m.li(n)
        m.ins('mcopy %s %s %s' % (d, s, nn))
        ws = [m.ldi(d0, 8 * w) for w in range(16)]
        m.printf(line, ['%d:' % n] + sum(([' ', D] for _ in range(16)), []) + ['\n'], ws)
        dst = bytearray(128)
        dst[doff:doff + n] = src[soff:soff + n]
        expect += '%d:' % n + ''.join(' %d' % w for w in struct.unpack('<16q', bytes(dst))) + '\n'
    m.ins('ret 0')
    p.out = expect
    p.write()


# ---------------------------------------------------------------- slay / soff
def slay():
    p = Prog('lir4_slay')
    m = Func(p, '.main', 'main', 1)
    expect = ''
    # a struct of three numeric fields (size 24, no reference field)
    la = m.reg('p')
    l0 = p.label(['slay LAB 24 0'])
    m.ins('la %s %s' % (la, l0))
    ds = [m.ldi(la, SL_SIZE), m.ldi(la, SL_NREF)]
    m.printf(2, ['slay ', D, ' ', D, '\n'], ds)
    expect += 'slay 24 0\n'
    args = [m.li(v) for v in (1, 2, 1)]
    a = m.reg('p')
    m.ins('rcall sea_arr_new_s 0:3 1 %s 4 %s %s' % (a, la, ' '.join(args)))
    hdr = [m.ldi(a, ARR_RC), m.ldb(a, ARR_EK), m.ldb(a, ARR_RANK), m.ldi(a, ARR_ROWS),
           m.ldi(a, ARR_COLS), m.ldi(a, ARR_CAP), m.ldi(a, ARR_ESIZE)]
    lab_bits = m.addr_bits(la)
    sl_bits = m.ldi(a, ARR_SLAY)
    same_sl = m.reg('i')
    m.ins('icmp eq %s %s %s' % (same_sl, lab_bits, sl_bits))
    a_bits = m.addr_bits(a)
    k64 = m.li(ARR_SIZE)
    want_data = m.reg('i')
    m.ins('iadd %s %s %s' % (want_data, a_bits, k64))
    data_bits = m.ldi(a, ARR_DATA)
    same_data = m.reg('i')
    m.ins('icmp eq %s %s %s' % (same_data, want_data, data_bits))
    m.printf(4, ['count ', D, ' ek ', D, ' rank ', D, ' rows ', D, ' cols ', D, ' cap ', D,
                 ' esize ', D, ' slay ', D, ' data ', D, '\n'], hdr + [same_sl, same_data])
    expect += 'count 1 ek 5 rank 1 rows 2 cols 1 cap 2 esize 24 slay 1 data 1\n'
    el = [m.ldi(a, ARR_SIZE + 8 * w) for w in range(6)]   # 2 elements of 24 bytes, zeroed
    m.printf(5, ['zero'] + sum(([' ', D] for _ in range(6)), []) + ['\n'], el)
    expect += 'zero 0 0 0 0 0 0\n'
    m.ins('release %s' % a)
    # a struct of size 40 with three reference fields at 0, 16 and 32 (str, f64, str, i64, str)
    lb = m.reg('p')
    l1 = p.label(['slay LAB 40 3', 'soff 0', 'soff 16', 'soff 32'])
    m.ins('la %s %s' % (lb, l1))
    ds = [m.ldi(lb, SL_SIZE), m.ldi(lb, SL_NREF)] + [m.ldi(lb, SL_REFS + 8 * j) for j in range(3)]
    m.printf(6, ['slay ', D, ' ', D, ' refs ', D, ' ', D, ' ', D, '\n'], ds)
    expect += 'slay 40 3 refs 0 16 32\n'
    args = [m.li(v) for v in (2, 1, 2)]
    b = m.reg('p')
    m.ins('rcall sea_arr_new_s 0:7 1 %s 4 %s %s' % (b, lb, ' '.join(args)))
    hdr = [m.ldb(b, ARR_EK), m.ldb(b, ARR_RANK), m.ldi(b, ARR_ROWS), m.ldi(b, ARR_COLS),
           m.ldi(b, ARR_CAP), m.ldi(b, ARR_ESIZE)]
    m.printf(8, ['ek ', D, ' rank ', D, ' rows ', D, ' cols ', D, ' cap ', D, ' esize ', D,
                 '\n'], hdr)
    expect += 'ek 5 rank 2 rows 1 cols 2 cap 2 esize 40\n'
    # a string (count 1) stored, with a retain each, into element 0 field 0 and element 1
    # field 16: count 3; releasing the array (count 1 -> 0, sea_free) releases the non-null
    # reference fields of each element by the descriptor's offsets: count 1 again
    v = m.li(42)
    s = m.reg('p')
    m.ins('rcall sea_str_i64 0:9 1 %s 1 %s' % (s, v))
    dp = m.reg('p')
    m.ins('ldp %s %s - 0 %d' % (dp, b, ARR_DATA))
    m.ins('retain %s' % s)
    m.ins('stp %s %s - 0 0' % (s, dp))
    m.ins('retain %s' % s)
    m.ins('stp %s %s - 0 %d' % (s, dp, 40 + 16))
    f = m.reg('f')
    m.ins('lf %s #4004000000000000' % f)
    m.ins('stf %s %s - 0 8' % (f, dp))
    c3 = m.ldi(s, STR_RC)
    m.ins('release %s' % b)
    c1 = m.ldi(s, STR_RC)
    m.printf(10, [S, ' count ', D, ' after the array ', D, '\n'], [s, c3, c1])
    expect += '42 count 3 after the array 1\n'
    m.ins('release %s' % s)
    m.ins('ret 0')
    p.out = expect
    p.write()


# ---------------------------------------------------------------- the other phase-4 entries
def entries():
    """Every entry of ids 9-20 that returns (sea_error, which ends the program, is in rt/)
    called through pass 4, with the expected results of the 4.8 contracts."""
    p = Prog('lir4_entries')
    m = Func(p, '.main', 'main', 1)
    expect = ''

    def static(text):
        r = m.reg('p')
        lab = p.label(['str LAB ' + esc(text)])
        m.ins('la %s %s' % (r, lab))
        return r

    # sea_str_f64 (x in d0, the site first integer argument): C's %.17g, nan/inf/-inf (4.8,
    # LANGUAGE.md 10.9)
    line = 2
    for bits, text in ((0x3FB999999999999A, '0.10000000000000001'), (0x8000000000000000, '-0'),
                       (0x4059000000000000, '100'), (0x7E37E43C8800759C, '1.0000000000000001e+300'),
                       (0xFFF8000000000001, 'nan'), (0x7FF8000000000000, 'nan'),
                       (0x7FF0000000000000, 'inf'), (0xFFF0000000000000, '-inf')):
        f = m.reg('f')
        m.ins('lf %s #%016X' % (f, bits))
        r = m.reg('p')
        m.ins('rcall sea_str_f64 0:%d 1 %s 1 %s' % (line, r, f))
        c = m.ldi(r, STR_RC)
        n = m.ldi(r, 16)
        m.printf(line, ['[', S, '] ', D, ' ', D, '\n'], [r, c, n])
        expect += '[%s] 1 %d\n' % (text, len(text))
        m.ins('release %s' % r)
        line += 1
    # sea_str_cmp: unsigned bytes, a proper prefix the lesser (no site)
    pairs = (('abc', 'abd', -1), ('abd', 'abc', 1), ('ab', 'abc', -1), ('abc', 'abc', 0),
             ('', '', 0), ('\x80', '\x7f', 1))
    res = []
    for a_, b_, want in pairs:
        a = static(a_)
        b = static(b_)
        r = m.reg('i')
        m.ins('rcall sea_str_cmp - 1 %s 2 %s %s' % (r, a, b))
        res.append(r)
    m.printf(line, ['cmp'] + sum(([' ', D] for _ in pairs), []) + ['\n'], res)
    expect += 'cmp' + ''.join(' %d' % w for _, _, w in pairs) + '\n'
    line += 1
    # sea_str_cat: always a new string; with an empty operand too
    a = static('Hello, ')
    b = static('World')
    c = m.reg('p')
    m.ins('rcall sea_str_cat 0:%d 1 %s 2 %s %s' % (line, c, a, b))
    e = static('')
    d = m.reg('p')
    m.ins('rcall sea_str_cat 0:%d 1 %s 2 %s %s' % (line, d, e, e))
    dl = m.ldi(d, 16)
    dc = m.ldi(d, STR_RC)
    m.printf(line, ['[', S, '] [', S, '] ', D, ' ', D, '\n'], [c, d, dl, dc])
    expect += '[Hello, World] [] 0 1\n'
    m.ins('release %s' % c)
    m.ins('release %s' % d)
    line += 1
    # sea_str_lower: only A-Z (0x41-0x5A) change
    a = static('MiXeD-Z@[`{AZ}')
    r = m.reg('p')
    m.ins('rcall sea_str_lower 0:%d 1 %s 1 %s' % (line, r, a))
    m.printf(line, ['[', S, ']\n'], [r])
    expect += '[mixed-z@[`{az}]\n'
    m.ins('release %s' % r)
    line += 1
    # sea_arr_new_u: the header as sea_arr_new (contents unspecified, not read)
    args = [m.li(v) for v in (EK_F64, 2, 2, 3)]
    u = m.reg('p')
    m.ins('rcall sea_arr_new_u 0:%d 1 %s 4 %s' % (line, u, ' '.join(args)))
    hdr = [m.ldi(u, ARR_RC), m.ldb(u, ARR_EK), m.ldb(u, ARR_RANK), m.ldi(u, ARR_ROWS),
           m.ldi(u, ARR_COLS), m.ldi(u, ARR_CAP), m.ldi(u, ARR_ESIZE), m.ldi(u, ARR_SLAY)]
    m.printf(line, ['new_u'] + sum(([' ', D] for _ in hdr), []) + ['\n'], hdr)
    expect += 'new_u 1 1 2 2 3 6 8 0\n'
    m.ins('release %s' % u)
    line += 1
    # sea_arr_unique: count 1 -> the same array; count 2 -> a copy (count 1, the same
    # elements), the old count dropped to 1; a store into the copy leaves the old array
    args = [m.li(v) for v in (EK_I64, 1, 3, 1)]
    a = m.reg('p')
    m.ins('rcall sea_arr_new_u 0:%d 1 %s 4 %s' % (line, a, ' '.join(args)))
    dp = m.reg('p')
    m.ins('ldp %s %s - 0 %d' % (dp, a, ARR_DATA))
    for j, v in enumerate((10, 20, 30)):
        x = m.li(v)
        m.ins('sti %s %s - 0 %d' % (x, dp, 8 * j))
    ab = m.addr_bits(a)
    q = m.reg('p')
    m.ins('rcall sea_arr_unique 0:%d 1 %s 1 %s' % (line, q, a))
    qb = m.addr_bits(q)
    same1 = m.reg('i')
    m.ins('icmp eq %s %s %s' % (same1, ab, qb))
    c1 = m.ldi(a, ARR_RC)
    m.ins('retain %s' % a)
    b = m.reg('p')
    m.ins('rcall sea_arr_unique 0:%d 1 %s 1 %s' % (line, b, a))
    bb = m.addr_bits(b)
    same2 = m.reg('i')
    m.ins('icmp eq %s %s %s' % (same2, ab, bb))
    ca = m.ldi(a, ARR_RC)
    cb = m.ldi(b, ARR_RC)
    ek = m.ldb(b, ARR_EK)
    rows = m.ldi(b, ARR_ROWS)
    bd = m.reg('p')
    m.ins('ldp %s %s - 0 %d' % (bd, b, ARR_DATA))
    n99 = m.li(99)
    m.ins('sti %s %s - 0 0' % (n99, bd))
    el = [m.ldi(bd, 8 * j) for j in range(3)] + [m.ldi(dp, 8 * j) for j in range(3)]
    m.printf(line, ['unique same ', D, ' count ', D, '; shared: same ', D, ' counts ', D, ' ',
                    D, ' ek ', D, ' rows ', D, ' copy', ' ', D, ' ', D, ' ', D, ' old ', D, ' ',
                    D, ' ', D, '\n'], [same1, c1, same2, ca, cb, ek, rows] + el)
    expect += ('unique same 1 count 1; shared: same 0 counts 1 1 ek %d rows 3 copy 99 20 30 '
               'old 10 20 30\n' % EK_I64)
    m.ins('release %s' % a)
    m.ins('release %s' % b)
    line += 1
    # sea_args: the arguments after the program name (LANGUAGE.md 10.10): none here
    g = m.reg('p')
    m.ins('rcall sea_args 0:%d 1 %s 0' % (line, g))
    hdr = [m.ldi(g, ARR_RC), m.ldb(g, ARR_EK), m.ldb(g, ARR_RANK), m.ldi(g, ARR_ROWS),
           m.ldi(g, ARR_COLS)]
    m.printf(line, ['args count ', D, ' ek ', D, ' rank ', D, ' len ', D, ' cols ', D, '\n'], hdr)
    expect += 'args count 1 ek %d rank 1 len 0 cols 1\n' % EK_STR
    m.ins('release %s' % g)
    m.ins('ret 0')
    p.out = expect
    p.write()


retain_release()
release_leaf()
mcopy()
slay()
entries()
print('lir4_gen: 5 pass-4 tests')
