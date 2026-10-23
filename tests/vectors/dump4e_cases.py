"""Sub-phase 4e dump tests (DESIGN.md 6.2 "4e" Dumps, 3.5.9 L5-L11 with R1-R11, 3.6.6 rules 20-22,
25, 26 (numeric literals), 27 (fixed-size numeric part), 28, Decisions 31-36).

Run with `timeout 120 uv run --no-project python tests/vectors/dump4e_cases.py [--out DIR]`. It
writes, in tests/passes/ (or DIR), for every test NAME below: NAME.sea, .ast, .res, .hir1, .hir,
.hirl, .lir1 and .out; and it rewrites passes/res_err_array.res (6.2: from 4e seaname resolves the
fixed-size type of `fn f(v: f64[3], k: i64)`, so the rerr 259 `arrays` of 4d is gone; the test
gains a .hir1, since a .res without .hir1 is a program whose sea.res holds an rerr, 6.2).

The tests: the agreed examples of 3.6.6 rules 20, 21, 22, 25 and 28 as whole programs
(arr_rule20 ... arr_rule28: each example appears in the .lir1 with exactly its registers, blocks,
lines and sites, the program laid out so that the registers the example names hold its inputs),
and the 4e shapes without an example: sel_reads (a matrix selection with `:` and a scalar, an index
vector, a whole-matrix mask), sel_ref_store (a selection store into a ref parameter), sel_compound
(a compound `x[sel] += e`), ew_colrow (matrix broadcasting of `.col` with `.row`), arr_lit_fixed
(fixed vector and matrix literals, `[]` dynamic and fixed), arr_lit_dyn (dynamic constant literal
with cdat, dynamic non-constant literal), arr_lit_cat (vector and matrix concatenation), arr_views
(`.T` and `.flat` materialized), arr_dynfix (`dyn`, `fix`), arr_fixed (a fixed-size local with
element read and write, a fixed-size result) and ew_ind2sub (ind2sub of a vector).

How each file is made (never by running a pass of 2a, 2b or 3a):
* `.ast`: pass 1 is unchanged in 4e (8, row 4e lists no seaparse work), so the records are those
  seaparse writes for the source, reviewed against 3.4 and checked against the source text by
  check_positions; the 257-element literals of arr_lit_dyn are written by a loop from the source
  columns (3.4: one `int` per element at its first character).
* `.res`: res_gen.py (the 3.4.1/3.4.2 oracle) with the phase-rule step 4e applied (fixed-size
  array types resolve to rtfvec/rtfmat instead of 259 `arrays`; res_gen4e() below patches the
  two places of res_gen's text that step 4d fixed); it cross-checks the lids against the .hir1.
* `.hir1`: written by hand from 3.5.1-3.5.5 (types numbered by first reference, locals 3.5.4,
  node positions 3.5.5 "Positions of the nodes pass 2a writes", the phase-4 notes: types of the
  array nodes, implicit dyn/fix). `.hir` equals `.hir1` in every test (no cref, no foldable
  subtree, every function reachable: 3.5.6, 3.5.7); the script asserts the absence of each.
* `.hirl`: written from 3.5.9 with the helpers below, which spell out the notation of 3.5.9
  (loop(N; K), rloop, mloop, lin, ext(X, d), data(X), vchk, mchk, IX 1-4) record by record.
  Every rewrite is written out in the test's section, statement by statement in the order its
  L-rule lists them. The `.l` locals are written with symbolic names and numbered by
  number_locals() exactly as 3.5.9 "Locals" says (after the source, .t and .j locals, in the
  order of their declaring records tmp, bind, rcnt (l before e), hloop), each with the loc record
  (type, mut, position) the declaration gives; the self-check verifies the result independently.
* `.lir1`: written by hand, instruction by instruction, from 3.6.6 (rules 1-27 as they apply,
  "Lowering of the sea.hirl records"), with the derivation in comments. Registers are written
  with symbolic names (`i.lo`, `p.d`) and numbered by number_regs() in order of first appearance
  in the function (3.6.1); blocks, slots and labels are written as numbers and checked.
* `.out`: from LANGUAGE.md by hand (the arithmetic is in the comments).

The self-check at the end reads every written file back: the .hirl against include/passes.txt
(sets H HF HL) and 3.3, 3.5.4, 3.5.9 ("Types", "Locals", "What the passes validate", R1-R11:
the validation list of sealower and R10), the .lir1 against passes.txt (set L) and the numbering
of 3.6.1-3.6.4, and asserts that each agreed example of rules 20, 21, 22, 25 and 28 appears in
both its golden and DESIGN.md, compared directly (the docs now write rule 25's large constants
in the field encoding of 3.1, `#000000007FFFFFFE` and `#7FFFFFFFFFFFFFFF`; the check also asserts
that every `i`-like decimal of an example is within -10^9 < v < 10^9, so a decimal of that size
cannot come back unnoticed).
"""

import os
import re
import struct
import sys
import types

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
PASSES = os.path.join(os.path.dirname(HERE), 'passes')
if '--out' in sys.argv:
    PASSES = os.path.abspath(sys.argv[sys.argv.index('--out') + 1])
HEAD = '#sea 1\n#target arm64-macos\n#file %s.sea\n'


def read(fname):
    with open(os.path.join(PASSES, fname)) as fh:
        return fh.read()


def write(fname, text):
    with open(os.path.join(PASSES, fname), 'w') as fh:
        fh.write(text)


def dump(name, body):
    """A whole dump file: the header of 3.2 (one #file, --no-prelude), the body, #end."""
    return HEAD % name + body.strip('\n') + '\n#end\n'


def lines(text):
    return [ln for ln in text.strip('\n').split('\n') if ln]


# ================================================================ res_gen with the step 4e
def res_gen4e():
    """res_gen.py (3.4.1/3.4.2) with the phase-rule step 4e of 2.6.2: a fixed-size array type is no
    longer 259 `arrays` but resolves to its type, written rtfvec/rtfmat in the type table (3.4.2
    "The type table"). The two places of res_gen that hold the step-4d rule are replaced, each
    asserted to occur exactly once; everything else of the oracle is unchanged."""
    path = os.path.join(HERE, 'res_gen.py')
    with open(path) as fh:
        src = fh.read()
    edits = [
        ("""        if shape in ('fv', 'fm'):
            err(tn.pos, 259, ['arrays'])
            return None
""", ''),
        ("""        return bt if shape == 's' else (shape, bt)
""", """        return bt if shape == 's' else (shape, bt) + tuple(vals)
"""),
        ("""            out.append('%s %d %d' % ({'v': 'rtvec', 'm': 'rtmat'}[key[0]], 10 + i, key[1]))
""", """            rec = {'v': 'rtvec', 'm': 'rtmat', 'fv': 'rtfvec', 'fm': 'rtfmat'}[key[0]]
            out.append(' '.join([rec, str(10 + i)] + [str(x) for x in key[1:]]))
"""),
    ]
    for old, new in edits:
        assert src.count(old) == 1, old
        src = src.replace(old, new)
    mod = types.ModuleType('res_gen4e')
    mod.__file__ = path
    sys.path.insert(0, HERE)
    exec(compile(src, path, 'exec'), mod.__dict__)
    mod.PASSES = PASSES
    return mod


RG = res_gen4e()


# ================================================================ HIR records with symbolic .l locals
# A node is (records, type). The records of a subtree are its post-order (3.3). A `.l` local is a
# string '$NAME'; DECL[fn][NAME] = (type, mut, pos) is filled by the declaring helper (tmp, bind of
# a .l local, rcnt, hloop); number_locals() replaces the names by lids (3.5.9 "Locals").
ES = {4: 8, 3: 8, 2: 1}     # element sizes of 4.8: SEA_ESIZE_F64, SEA_ESIZE_I64, SEA_ESIZE_BOOL
SHAPE_VEC = -1              # SEA_SHAPE_VEC (include/rt.inc), read from the consts table (3.5.9 vchk)


class Fn:
    """The .l locals of one function being written."""

    def __init__(self):
        self.decl = {}

    def d(self, name, ty, mut, pos):
        assert name not in self.decl, name
        self.decl[name] = (ty, mut, pos)
        return '$' + name


def N(recs, ty):
    return (list(recs), ty)


def cat(*nodes):
    out = []
    for n in nodes:
        out += n[0]
    return out


def lv(P, ty, lid):
    return N(['lv %s %d %s' % (P, ty, lid)], ty)


def ci(P, v, ty=3):
    return N(['ci %s %d %s' % (P, ty, v)], ty)


def cf(P, bits):
    return N(['cf %s 4 %s' % (P, bits)], 4)


def cb(P, v):
    return N(['cb %s 2 %d' % (P, v)], 2)


def leaf(rec, ty):
    return N([rec], ty)


def bin_(P, ty, op, a, b):
    return N(cat(a, b) + ['bin %s %d %s' % (P, ty, op)], ty)


def un(P, ty, op, a):
    return N(cat(a) + ['un %s %d %s' % (P, ty, op)], ty)


def wbin(P, op, a, b):
    return N(cat(a, b) + ['wbin %s 3 %s' % (P, op)], 3)


def ext(P, d, a):
    return N(cat(a) + ['ext %s 3 %d' % (P, d)], 3)


def adat(P, tp, a):
    return N(cat(a) + ['adat %s %d' % (P, tp)], tp)


def eld(P, ty, a, i, off=0):
    return N(cat(a, i) + ['eld %s %d %d %d' % (P, ty, ES[ty], off)], ty)


def est(P, ty, v, a, i, off=0):
    """est of a value of element type ty (its size from ES)."""
    return N(cat(v, a, i) + ['est %s %d %d' % (P, ES[ty], off)], None)


def anew(P, ty, z, kids):
    return N(cat(*kids) + ['anew %s %d %d %d' % (P, ty, z, len(kids))], ty)


def lib(P, ty, name, kids):
    return N(cat(*kids) + ['lib %s %d %s %d' % (P, ty, name, len(kids))], ty)


def xblk(P, stmts, val):
    return N(cat(*stmts) + cat(val) + ['xblk %s %d %d' % (P, val[1], len(stmts))], val[1])


def block(P, stmts):
    return N(cat(*stmts) + ['block %s %d' % (P, len(stmts))], None)


def if_(P, c, blk, els=None):
    return N(cat(c, blk) + (cat(els) if els else []) + ['if %s %d' % (P, 1 if els else 0)], None)


def chkb(P, d, i, x):
    return N(cat(i, x) + ['chkb %s %d' % (P, d)], None)


def chk(P, err, c, args):
    return N(cat(c, *args) + ['chk %s %s %d' % (P, err, len(args))], None)


def cow(P, a):
    return N(cat(a) + ['cow %s' % P], None)


def mcpy(P, d, s, n):
    return N(cat(d, s, n) + ['mcpy %s' % P], None)


def cdat(P, tp, kids):
    return N(cat(*kids) + ['cdat %s %d %d' % (P, tp, len(kids))], tp)


def stmt(rec, *kids):
    return N(cat(*kids) + [rec], None)


def asg(P, op, t, v):
    return N(cat(t, v) + ['asg %s %s' % (P, op)], None)


class Ctx:
    """The shorthand of 3.5.9 for one rewrite in function F at the rewrite's position P. Every .l
    local the rewrite declares is named pre + NAME (unique in the function)."""

    def __init__(self, F, P, pre):
        self.F, self.P, self.pre = F, P, pre

    def n(self, name):
        return self.pre + name

    def tmp(self, name, child, pos=None):
        """`tmp L = child` (T1): declares the .l local L, mut let, the child's type."""
        lid = self.F.d(self.n(name), child[1], 'let', self.P)
        return N(cat(child) + ['tmp %s %s' % (pos or self.P, lid)], None)

    def bindl(self, name, child):
        """`bind L = child` of a .l local (R8): mut let, the value's type."""
        lid = self.F.d(self.n(name), child[1], 'let', self.P)
        return N(cat(child) + ['bind %s %s' % (self.P, lid)], None)

    def lvl(self, name):
        nm = self.n(name)
        return lv(self.P, self.F.decl[nm][0], '$' + nm)

    def rcnt(self, incl, l, e, lo, hi, st, rpos):
        """`rcnt incl L E (lv LO) (lv HI) (lv ST)` at the rng's position rpos; L (count - 1, type
        3) and E (not empty, type 2, R6) are declared at rpos (3.5.9 "Locals")."""
        L = self.F.d(self.n(l), 3, 'let', rpos)
        E = self.F.d(self.n(e), 2, 'let', rpos)
        return N(cat(self.lvl(lo), self.lvl(hi), self.lvl(st))
                 + ['rcnt %s %d %s %s' % (rpos, incl, L, E)], None)

    def hloop(self, k, start, last, step, body):
        """`hloop K start last step { body }`: K a .l local, mut for, type 3, declared by the hloop
        record (after the locals of its body); body a list of statements, one block. The caller
        refers to K in the body by klv(k) before this call."""
        recs = cat(start, last, step, block(self.P, body)) + ['hloop %s $%s' % (self.P, self.n(k))]
        self.F.d(self.n(k), 3, 'for', self.P)
        return N(recs, None)

    def klv(self, k):
        """lv K of an induction local (type 3) before its hloop declares it."""
        return lv(self.P, 3, '$' + self.n(k))

    def loop(self, n, z, o, l, k, body):
        """loop(N; K) { S } (3.5.9, 4e-0): `tmp Z = ci 0`, `if (bin gt (lv N) (lv Z))` { `tmp O =
        ci 1`; `tmp L = wbin sub (lv N) (lv O)`; `hloop K (lv Z) (lv L) (lv O)` { S } }. Returns
        the two statements; body is a function of nothing returning the statements S (written
        after Z, O and L are declared). n names a .l local of this rewrite, or is a node."""
        P = self.P
        s1 = self.tmp(z, ci(P, 0))
        nN = self.lvl(n) if isinstance(n, str) else n
        cond = bin_(P, 2, 'gt', nN, self.lvl(z))
        s2 = self.tmp(o, ci(P, 1))
        s3 = self.tmp(l, wbin(P, 'sub', nN, self.lvl(o)))
        S = body()
        s4 = self.hloop(k, self.lvl(z), self.lvl(l), self.lvl(o), S)
        return [s1, if_(P, cond, block(P, [s2, s3, s4]))]

    def rloop(self, e, lo, l, st, q, body):
        """rloop(E, LO, L, ST; K) { S }: `if (lv E)` { `hloop K (lv LO) (lv L) (lv ST)` { S } }."""
        P = self.P
        S = body()
        return if_(P, self.lvl(e), block(P, [self.hloop(q, self.lvl(lo), self.lvl(l),
                                                        self.lvl(st), S)]))

    def lin(self, i, j, r):
        """lin(I, J, R) = `wbin add (lv I) (wbin mul (lv J) (lv R))`; i, j, r are nodes."""
        P = self.P
        return wbin(P, 'add', i, wbin(P, 'mul', j, r))

    def plus_eq(self, x, e):
        """X += e: `asg set (lv X) (wbin add (lv X) e)` of a scalar .l local bound by bind (R8)."""
        P = self.P
        return asg(P, 'set', self.lvl(x), wbin(P, 'add', self.lvl(x), e))

    def vchk(self, err, s, a, b, v, first=True):
        """vchk(err; S, A, B): `tmp V = ci SEA_SHAPE_VEC` (only at the first vector check of the
        rewrite, first=True), then `chk err 4 (lv S) (lv A) (lv V) (lv B) (lv V)`."""
        out = []
        if first:
            out.append(self.tmp(v, ci(self.P, SHAPE_VEC)))
        out.append(chk(self.P, err, self.lvl(s), [self.lvl(a), self.lvl(v), self.lvl(b),
                                                   self.lvl(v)]))
        return out

    def mchk(self, err, s, r, c, r2, c2):
        """mchk(err; S, R, C, r, c) = `chk err 4 (lv S) (lv R) (lv C) (lv r) (lv c)`."""
        return chk(self.P, err, self.lvl(s), [self.lvl(r), self.lvl(c), self.lvl(r2),
                                               self.lvl(c2)])


def number_locals(fn_head, nsrc, F, recs):
    """3.5.9 "Locals": the .l locals of F numbered from nsrc + 1 in the order of their declaring
    records (tmp, bind, rcnt with l before e, hloop, L12's tbind) in recs; returns (the fn record with nl
    counting them, the loc records, recs with every $NAME replaced by its lid)."""
    order = []
    for r in recs:
        p = r.split(' ')
        if p[0] in ('tmp', 'bind', 'hloop') and p[2].startswith('$'):
            if p[2][1:] not in order:
                order.append(p[2][1:])
        elif p[0] == 'tbind' and any(x.startswith('$') for x in p[3:]):
            # L12's tbind of .l locals (R8): its components in order, `-` for a skip (the
            # Locals paragraph of 3.5.9 does not list tbind; it declares like bind)
            for x in p[3:]:
                if x != '-':
                    assert x.startswith('$') and x[1:] not in order, r
                    order.append(x[1:])
        elif p[0] == 'rcnt':
            for x in (p[3], p[4]):
                assert x.startswith('$') and x[1:] not in order, r
                order.append(x[1:])
    assert sorted(order) == sorted(F.decl), (sorted(order), sorted(F.decl))
    lid = {nm: nsrc + 1 + k for k, nm in enumerate(order)}
    locs = ['loc .l%d %d %s %s' % (k + 1, F.decl[nm][0], F.decl[nm][1], F.decl[nm][2])
            for k, nm in enumerate(order)]
    out = []
    for r in recs:
        out.append(re.sub(r'\$(\w+)', lambda m: str(lid[m.group(1)]), r))
    p = fn_head.split(' ')
    p[6] = str(int(p[6]) + len(order))
    return ' '.join(p), locs, out


# ================================================================ LIR with symbolic registers
def number_regs(text):
    """3.6.1: registers numbered from 1 in order of first appearance in each function (record
    order, fields left to right), across all classes. A register is written `c.NAME` (c the class
    letter); a field that is already `cN` is kept and must already be in that order."""
    out, names = [], {}
    for ln in lines(text):
        if ln.startswith('func '):
            names = {}
        toks = ln.split(' ')
        for k, t in enumerate(toks):
            m = re.match(r'^([ifp])\.(\w+)$', t)
            if m:
                key = t
                if key not in names:
                    names[key] = '%s%d' % (m.group(1), len(names) + 1)
                toks[k] = names[key]
        out.append(' '.join(toks))
    return '\n'.join(out) + '\n'


# ================================================================ the tests
SEA, AST, HIR1, HIRL, LIR1, OUT = {}, {}, {}, {}, {}, {}


def subtree_replace(body, old, new):
    """Replaces the contiguous records `old` (the post-order of one node or statement of the .hir,
    found exactly once) by `new`."""
    n = len(old)
    hits = [k for k in range(len(body) - n + 1) if body[k:k + n] == old]
    assert len(hits) == 1, ('subtree not found once', hits, old[:3])
    k = hits[0]
    return body[:k] + new + body[k + n:]


def make_hirl(hir_text, tptrs, edits):
    """sea.hirl from sea.hir (3.5.9): the type table of sea.hir with the tptr records appended
    ("Types"); in each function fid of `edits` = {fid: (F, [(old, new), ...])}, each rewritten
    subtree `old` (records of the .hir) replaced by `new` (records with symbolic .l locals), then
    the .l locals numbered (number_locals) and their loc records added after the function's loc
    records; every other function unchanged ("Unchanged functions")."""
    recs = lines(hir_text)
    out, k = [], 0
    while recs[k].split(' ')[0] in ('tvec', 'tmat', 'tfvec', 'tfmat', 'tstruct', 'trec', 'fd',
                                    'ttuple'):
        out.append(recs[k])
        k += 1
    out += tptrs
    while k < len(recs):
        assert recs[k].startswith('fn '), recs[k]
        head = recs[k]
        fid = int(head.split(' ')[1])
        k += 1
        decl = []
        while recs[k].split(' ')[0] in ('par', 'loc'):
            decl.append(recs[k])
            k += 1
        body = []
        while recs[k] != 'end':
            body.append(recs[k])
            k += 1
        body.append('end')
        k += 1
        if fid in edits:
            F, eds = edits[fid]
            for old, new in eds:
                body = subtree_replace(body, lines(old) if isinstance(old, str) else old, new)
            head, locs, body = number_locals(head, len(decl), F, body)
            decl += locs
        out += [head] + decl + body
    return '\n'.join(out) + '\n'


# ================================================================ rewrites of 4e-0 (L1-L4)
ONE_F64 = '#3FF0000000000000'


def L1(P, T, args):
    """L1: `lib zeros(r)` / `zeros(r, c)` of type T: `anew P T 1 k`, the arguments its children."""
    return anew(P, T, 1, args)


def L2(F, P, T, E, TP, pre, r, c=None, v=None):
    """L2: `ones(...)` (v None, always f64) or `filled(v, ...)` of type T (element type E, TP the
    tptr of E): `xblk P T n` with, in order: for filled `tmp V = v`; `tmp R = r`; for a matrix
    `tmp C = c`; `tmp A = anew P T 0 k (lv R [, lv C])`; for a matrix `tmp N = wbin mul (lv R)
    (lv C)` (a vector's N is R); for ones `tmp V = cf 1.0`; `tmp D = adat (lv A)`; loop(N; K) {
    `est P s 0 (lv V) (lv D) (lv K)` }; value `lv A`."""
    x = Ctx(F, P, pre)
    st = []
    if v is not None:
        st.append(x.tmp('V', v))
    st.append(x.tmp('R', r))
    if c is not None:
        st.append(x.tmp('C', c))
    st.append(x.tmp('A', anew(P, T, 0, [x.lvl('R')] + ([x.lvl('C')] if c is not None else []))))
    if c is not None:
        st.append(x.tmp('N', wbin(P, 'mul', x.lvl('R'), x.lvl('C'))))
    if v is None:
        assert E == 4
        st.append(x.tmp('V', cf(P, ONE_F64)))
    st.append(x.tmp('D', adat(P, TP, x.lvl('A'))))
    st += x.loop('N' if c is not None else 'R', 'Z', 'O', 'L', 'K',
                 lambda: [est(P, E, x.lvl('V'), x.lvl('D'), x.klv('K'))])
    return xblk(P, st, x.lvl('A'))


def L3(P, d, a):
    """L3: `len(a)`, `rows(a)` (d 0), `cols(a)` (d 1), `numel` of a vector: `ext P 3 d` of a."""
    return ext(P, d, a)


def L4(F, P, E, TP, pre, X, v, body):
    """L4: `fore X v body` (X the loop variable's lid, E its type): `block P 4` with `bind H = v`;
    `tmp N = ext P 3 0 (lv H)`; `tmp Z = ci 0`; `if (bin gt (lv N) (lv Z))` { `tmp D = adat (lv H)`;
    `tmp O = ci 1`; `tmp L = wbin sub (lv N) (lv O)`; `hloop K (lv Z) (lv L) (lv O)` { `tmp X =
    eld P E s 0 (lv D) (lv K)`; body } }. body: the records of the fore's own block, unchanged."""
    x = Ctx(F, P, pre)
    s = [x.bindl('H', v), x.tmp('N', ext(P, 0, x.lvl('H'))), x.tmp('Z', ci(P, 0))]
    cond = bin_(P, 2, 'gt', x.lvl('N'), x.lvl('Z'))
    inner = [x.tmp('D', adat(P, TP, x.lvl('H'))), x.tmp('O', ci(P, 1)),
             x.tmp('L', wbin(P, 'sub', x.lvl('N'), x.lvl('O')))]
    hb = [N(eld(P, E, x.lvl('D'), x.klv('K'))[0] + ['tmp %s %d' % (P, X)], None),
          N(lines(body), None)]
    inner.append(x.hloop('K', x.lvl('Z'), x.lvl('L'), x.lvl('O'), hb))
    s.append(if_(P, cond, block(P, inner)))
    return block(P, s)


def fmt_data(lab, pieces):
    """The fmt data record of rule 8 with its ftext/fconv records."""
    return ['fmt d%d %d' % (lab, len(pieces))] + pieces


NAMES = []


# ================================================================ arr_rule20 (rule 20)
# The example's u is p1, the parameter of pick; its statement is the first of pick, on line 30.
SEA['arr_rule20'] = '''var a = zeros(5)
a[2] = 2.0
a[3] = 3.0
printf("%g\\n", pick(a))
printf("%g\\n", pick(ones(5)))
// arr_rule20 -- DESIGN.md 3.6.6 rule 20 (selections, reads): its example verbatim on line 30,
// the first statement of pick, whose parameter u is the register p1 of the example.
//
// The selection u[0..$ step 2] is rewritten by sealoop as 3.5.9 L5: the base u is named by a
// tmp (an alias of p1), the range index is evaluated by IX 1 (lo, hi, step, then rcnt, which
// counts the range into the bool E and the last offset L; the $ in the range is the ext of
// the base at the $'s position), checked by IX 2 (the extent loaded once, then the first and
// the last position of a non-empty range against it), counted by IX 3 (where(E, L + 1, 0)),
// allocated (anew), and copied by IX 4 (rloop over the range, one est per element into the
// counter O of the result).
//
// The selection's value is moved into u1 (T3), which the element loop of line 32 then holds
// in a hidden local (L4) while it sums the selected elements; u1 is released by the return.
//
// pick is called from two sites and holds a loop, so LANGUAGE.md 8.6 requires no inlining
// (3.6.6 "Inlining is deferred"). In .main the vector a = [0, 0, 2, 3, 0] (two element stores,
// rule 19) gives the elements 0, 2 and 4: 0 + 2 + 0 = 2; ones(5) gives three ones: 3.
//
// Each statement holds at most one array operation (3.6.6 "Phase-4 dump tests").
//
// The comment fills the lines up to the function, so that the example's line is 30.
//
//
fn pick(u: f64[]) -> f64 {
    let u1 = u[0..$ step 2]
    var s = 0.0
    for x in u1 {
        s += x
    }
    return s
}
'''
AST['arr_rule20'] = '''
pname 0:1:5 a
name 0:1:9 zeros
int 0:1:15 5
call 0:1:9 1
var 0:1:1 0
name 0:2:1 a
int 0:2:3 2
index 0:2:1 1
float 0:2:8 #4000000000000000
asg 0:2:1 set
name 0:3:1 a
int 0:3:3 3
index 0:3:1 1
float 0:3:8 #4008000000000000
asg 0:3:1 set
name 0:4:1 printf
str 0:4:8 %25g%0A
name 0:4:16 pick
name 0:4:21 a
call 0:4:16 1
call 0:4:1 2
cstmt 0:4:1
name 0:5:1 printf
str 0:5:8 %25g%0A
name 0:5:16 pick
name 0:5:21 ones
int 0:5:26 5
call 0:5:21 1
call 0:5:16 1
call 0:5:1 2
cstmt 0:5:1
type 0:29:12 f64 v 0
param 0:29:9 u 0 0
type 0:29:22 f64 s 0
pname 0:30:9 u1
name 0:30:14 u
int 0:30:16 0
dollar 0:30:19
int 0:30:26 2
range 0:30:16 0 1
index 0:30:14 1
let 0:30:5 0
pname 0:31:9 s
float 0:31:13 #0000000000000000
var 0:31:5 0
name 0:32:14 u1
name 0:33:9 s
name 0:33:14 x
asg 0:33:9 add
block 0:32:17 1
for 0:32:5 x 0:32:9
name 0:35:12 s
return 0:35:5 1
block 0:29:26 4
fn 0:29:1 pick 0 1 1
prog 6
'''
# sea.hir1 (3.5): f64[] is type 10 (first referred to by `loc a`), i64[] type 11 (the rng of
# pick, 3.5.1: ranges have the type i64[]). The selection u[0..$ step 2] is an idx with one rng
# index whose hi is `dol 0` (the extent of dimension 0 of the innermost idx, 3.5.5); its type is
# the dynamic f64[] (a selection is always dynamic, 3.5.5 phase-4 notes).
HIR1['arr_rule20'] = '''
tvec 10 4
tvec 11 3
fn 1 .main main 1 0 1 0:1:1
loc a 10 var 0:1:5
ci 0:1:15 3 5
lib 0:1:9 10 zeros 1
bind 0:1:1 1
lv 0:2:1 10 1
ci 0:2:3 3 2
idx 0:2:1 4 1
cf 0:2:8 4 #4000000000000000
asg 0:2:1 set
lv 0:3:1 10 1
ci 0:3:3 3 3
idx 0:3:1 4 1
cf 0:3:8 4 #4008000000000000
asg 0:3:1 set
lv 0:4:21 10 1
call 0:4:16 4 2 1
fconv 0:4:8 1 - - - g
ftext 0:4:8 1 %0A
fmt 0:4:8 1 2
lib 0:4:1 1 printf 1
eval 0:4:1
ci 0:5:26 3 5
lib 0:5:21 10 ones 1
call 0:5:16 4 2 1
fconv 0:5:8 1 - - - g
ftext 0:5:8 1 %0A
fmt 0:5:8 1 2
lib 0:5:1 1 printf 1
eval 0:5:1
block 0:1:1 5
end
fn 2 pick fn 4 1 3 0:29:1
par u 10 val
loc u1 10 let 0:30:9
loc s 4 var 0:31:9
loc x 4 for 0:32:9
lv 0:30:14 10 1
ci 0:30:16 3 0
dol 0:30:19 3 0
ci 0:30:26 3 2
rng 0:30:16 11 0 1
idx 0:30:14 10 1
bind 0:30:5 2
cf 0:31:13 4 #0000000000000000
bind 0:31:5 3
lv 0:32:14 10 2
lv 0:33:9 4 3
lv 0:33:14 4 4
asg 0:33:9 add
block 0:32:17 1
fore 0:32:5 4
lv 0:35:12 4 3
ret 0:35:5 1
block 0:29:26 4
end
'''


def hirl_arr_rule20():
    """sea.hirl: tptr 12 4 (first referred to by the adat of ones(5) in .main). .main: zeros(5)
    is L1, ones(5) L2. pick: the selection is L5 (written out below), the for over u1 is L4."""
    F1, F2 = Fn(), Fn()
    m_zeros = (['ci 0:1:15 3 5', 'lib 0:1:9 10 zeros 1'],
               cat(L1('0:1:9', 10, [ci('0:1:15', 5)])))
    m_ones = (['ci 0:5:26 3 5', 'lib 0:5:21 10 ones 1'],
              cat(L2(F1, '0:5:21', 10, 4, 12, 'o', r=ci('0:5:26', 5))))
    # L5 of `u[0..$ step 2]`, P the idx's position (3.5.9 L5, IX 1-4):
    P = '0:30:14'
    x = Ctx(F2, P, 's')
    st = [x.tmp('B', lv('0:30:14', 10, 1))]                    # tmp B = the base (lv u)
    # IX 1 (R): tmp LO = lo, tmp HI = hi (the $ replaced by ext of B at the $'s position), tmp ST =
    # st, rcnt incl L E at the rng's position
    st += [x.tmp('LO', ci('0:30:16', 0)),
           x.tmp('HI', ext('0:30:19', 0, x.lvl('B'))),
           x.tmp('ST', ci('0:30:26', 2)),
           x.rcnt(0, 'L', 'E', 'LO', 'HI', 'ST', '0:30:16')]
    # IX 2 (R): tmp X = ext of dimension 0, then if (lv E) { chkb lo; chkb lo + L * st }
    st += [x.tmp('X', ext(P, 0, x.lvl('B'))),
           if_(P, x.lvl('E'), block(P, [
               chkb(P, 0, x.lvl('LO'), x.lvl('X')),
               chkb(P, 0, wbin(P, 'add', x.lvl('LO'), wbin(P, 'mul', x.lvl('L'), x.lvl('ST'))),
                    x.lvl('X'))]))]
    # IX 3 (R): the count where(E, L + 1, 0)
    st += [x.tmp('O1', ci(P, 1)),
           x.tmp('T', wbin(P, 'add', x.lvl('L'), x.lvl('O1'))),
           x.tmp('Z', ci(P, 0)),
           x.tmp('N', lib(P, 3, 'where', [x.lvl('E'), x.lvl('T'), x.lvl('Z')]))]
    # the result (one kept dimension: a vector), its data, the base's data, the counter O, One
    st += [x.tmp('R', anew(P, 10, 0, [x.lvl('N')])),
           x.tmp('DR', adat(P, 12, x.lvl('R'))),
           x.tmp('DB', adat(P, 12, x.lvl('B'))),
           x.bindl('O', ci(P, 0)),
           x.tmp('One', ci(P, 1))]
    # IX 4 (R): rloop(E, LO, L, ST; Q) { est (eld DB Q) DR O; O += One }
    st += [x.rloop('E', 'LO', 'L', 'ST', 'Q', lambda: [
        est(P, 4, eld(P, 4, x.lvl('DB'), x.klv('Q')), x.lvl('DR'), x.lvl('O')),
        x.plus_eq('O', x.lvl('One'))])]
    p_sel = ('''
lv 0:30:14 10 1
ci 0:30:16 3 0
dol 0:30:19 3 0
ci 0:30:26 3 2
rng 0:30:16 11 0 1
idx 0:30:14 10 1
''', cat(xblk(P, st, x.lvl('R'))))
    p_fore = ('''
lv 0:32:14 10 2
lv 0:33:9 4 3
lv 0:33:14 4 4
asg 0:33:9 add
block 0:32:17 1
fore 0:32:5 4
''', cat(L4(F2, '0:32:5', 4, 12, 'f', 4, lv('0:32:14', 10, 2), '''
lv 0:33:9 4 3
lv 0:33:14 4 4
asg 0:33:9 add
block 0:32:17 1
''')))
    return make_hirl(HIR1['arr_rule20'], ['tptr 12 4'],
                     {1: (F1, [m_zeros, m_ones]), 2: (F2, [p_sel, p_fore])})


HIRL['arr_rule20'] = hirl_arr_rule20
# sea.lir1. .main: zeros(5) is arrnewz (rule 17); a[2] = 2.0 and a[3] = 3.0 are rule 19 (the value,
# the index, the check, cow(a), data, the store); pick(a) passes a borrowed (rule 15 (c)); the L2
# xblk of ones(5) is an owned temporary of the call, released right after it (rule 15 (b), (k));
# a is released at the end of the body block (rule 16 (a)). pick: the example of rule 20 (lines
# 30), then var s, the element loop of L4 over u1 (rule 30: mov, retain, ..., release of the
# held vector) and the return (u1 released before ret, rule 16 (c)).
LIR1['arr_rule20'] = '''
func .main main 0:1:1 0 0
slot s1 8 8
slot s2 8 8
li i.n 5
li i.ek 1
li i.rk 1
li i.c 1
rcall sea_arr_new 0:1 1 p.a 4 i.ek i.rk i.n i.c
lf f.v2 #4000000000000000
li i.x2 2
ldi i.e2 p.a - 0 16
chkb i.x2 i.e2 0 0:2
ldi i.rc2 p.a - 0 0
li i.o2 1
icmp ne i.s2 i.rc2 i.o2
if 1 i.s2
rcall sea_arr_unique 0:2 1 p.u2 1 p.a
mov p.a p.u2
endif 1
ldp p.d2 p.a - 0 40
stf f.v2 p.d2 i.x2 8 0
lf f.v3 #4008000000000000
li i.x3 3
ldi i.e3 p.a - 0 16
chkb i.x3 i.e3 0 0:3
ldi i.rc3 p.a - 0 0
li i.o3 1
icmp ne i.s3 i.rc3 i.o3
if 2 i.s3
rcall sea_arr_unique 0:3 1 p.u3 1 p.a
mov p.a p.u3
endif 2
ldp p.d3 p.a - 0 40
stf f.v3 p.d3 i.x3 8 0
call pick 1 f.r4 1 p.a
sa p.s4 s1
stf f.r4 p.s4 - 0 0
la p.f4 d1
rcall sea_printf 0:4 0 2 p.f4 p.s4
li i.R 5
li i.ek5 1
li i.rk5 1
li i.c5 1
rcall sea_arr_new_u 0:5 1 p.A 4 i.ek5 i.rk5 i.R i.c5
lf f.V #3FF0000000000000
ldp p.D p.A - 0 40
li i.Z 0
icmp gt i.g i.R i.Z
if 3 i.g
li i.O 1
isub i.L i.R i.O
loop 4 i.K i.Z i.L i.O
stf f.V p.D i.K 8 0
endloop 4
endif 3
call pick 1 f.r5 1 p.A
release p.A
sa p.s5 s2
stf f.r5 p.s5 - 0 0
la p.f5 d2
rcall sea_printf 0:5 0 2 p.f5 p.s5
release p.a
ret 0
endfunc
func pick fn 0:29:1 1 p.u 1 f
li i.lo 0
ldi i.hi p.u - 0 16
li i.st 2
rcount i.L i.E i.lo i.hi i.st 0 0:30
ldi i.X p.u - 0 16
if 1 i.E
chkb i.lo i.X 0 0:30
imul i.m i.L i.st
iadd i.last i.lo i.m
chkb i.last i.X 0 0:30
endif 1
li i.O1 1
iadd i.T i.L i.O1
li i.Z 0
isel i.N i.E i.T i.Z
li i.ek 1
li i.rk 1
li i.c 1
rcall sea_arr_new_u 0:30 1 p.u1 4 i.ek i.rk i.N i.c
ldp p.DR p.u1 - 0 40
ldp p.DB p.u - 0 40
li i.O 0
li i.One 1
if 2 i.E
loop 3 i.Q i.lo i.L i.st
ldf f.el p.DB i.Q 8 0
stf f.el p.DR i.O 8 0
iadd i.O i.O i.One
endloop 3
endif 2
lf f.s #0000000000000000
mov p.H p.u1
retain p.H
ldi i.n p.H - 0 16
li i.z 0
icmp gt i.g i.n i.z
if 4 i.g
ldp p.d p.H - 0 40
li i.o 1
isub i.l i.n i.o
loop 5 i.k i.z i.l i.o
ldf f.x p.d i.k 8 0
fadd f.s f.s f.x
endloop 5
endif 4
release p.H
release p.u1
ret 1 f.s
endfunc
fmt d1 2
fconv - - - g f
ftext %0A
fmt d2 2
fconv - - - g f
ftext %0A
'''
# pick(a): a = [0, 0, 2, 3, 0], u1 = a[0..5 step 2] = [0, 2, 0], s = 2; pick(ones(5)): u1 = [1, 1, 1],
# s = 3 (%g of 2.0 and 3.0, LANGUAGE.md 11.1).
OUT['arr_rule20'] = '2\n3\n'
NAMES.append('arr_rule20')


# ================================================================ arr_rule21 (rule 21)
# The example's v (a var f64[]) is p1 and m (a bool[]) p2: the tbind of line 1 gives the call the
# registers of its target locals (rule 2), the first two of .main; lines 2-4 are comments, so the
# store of line 5 starts with p1 and p2 and no other register.
SEA['arr_rule21'] = '''var (v, m) = two()
// arr_rule21 -- DESIGN.md 3.6.6 rule 21 (selection stores): its example verbatim on line 5,
// v[m] = 0.0 with v a var f64[] in p1 and m a bool[] in p2 (the two results of the call on
// line 1, written straight into the registers of v and m by the tbind, rule 2)
v[m] = 0.0
printf("%g %g %g\\n", v[0], v[1], v[2])
let (w, _) = two()
printf("%g\\n", w[3])
fn two() -> (f64[], bool[]) {
    var v = ones(4)
    var m = filled(true, 4)
    for k in 0..2 {
        m[2 * k + 1] = false
    }
    return (v, m)
}
// The store is 3.5.9 L6: the scalar value, the mask (a tmp naming m), the mask's shape check
// (vchk), the copy on write of v, the data of v and of m, and the masked loop of IX 4. The
// mask is T F T F, so v becomes 0 1 0 1; the _ component of line 7 is released after the tbind.
'''
AST['arr_rule21'] = '''
pname 0:1:6 v
pname 0:1:9 m
ptuple 0:1:5 2
name 0:1:14 two
call 0:1:14 0
var 0:1:1 0
name 0:5:1 v
name 0:5:3 m
index 0:5:1 1
float 0:5:8 #0000000000000000
asg 0:5:1 set
name 0:6:1 printf
str 0:6:8 %25g%20%25g%20%25g%0A
name 0:6:22 v
int 0:6:24 0
index 0:6:22 1
name 0:6:28 v
int 0:6:30 1
index 0:6:28 1
name 0:6:34 v
int 0:6:36 2
index 0:6:34 1
call 0:6:1 4
cstmt 0:6:1
pname 0:7:6 w
pskip 0:7:9
ptuple 0:7:5 2
name 0:7:14 two
call 0:7:14 0
let 0:7:1 0
name 0:8:1 printf
str 0:8:8 %25g%0A
name 0:8:16 w
int 0:8:18 3
index 0:8:16 1
call 0:8:1 2
cstmt 0:8:1
type 0:9:14 f64 v 0
type 0:9:21 bool v 0
pname 0:10:9 v
name 0:10:13 ones
int 0:10:18 4
call 0:10:13 1
var 0:10:5 0
pname 0:11:9 m
name 0:11:13 filled
true 0:11:20
int 0:11:26 4
call 0:11:13 2
var 0:11:5 0
int 0:12:14 0
int 0:12:17 2
range 0:12:14 0 0
name 0:13:9 m
int 0:13:11 2
name 0:13:15 k
bin 0:13:11 mul
int 0:13:19 1
bin 0:13:11 add
index 0:13:9 1
false 0:13:24
asg 0:13:9 set
block 0:12:19 1
for 0:12:5 k 0:12:9
name 0:15:13 v
name 0:15:16 m
return 0:15:5 2
block 0:9:29 4
fn 0:9:1 two 0 0 2
prog 6
'''
# sea.hir1: f64[] 10 and bool[] 11 (first referred to by `loc v`, `loc m`), the result tuple of two
# 12 (first referred to by the call of line 1), i64[] 13 (the rng of the for in two). `var (v, m)
# = two()` is a tbind of the locals 1 and 2 (3.5.5), `let (w, _)` one of 3 and `-`.
HIR1['arr_rule21'] = '''
tvec 10 4
tvec 11 2
ttuple 12 2 10 11
tvec 13 3
fn 1 .main main 1 0 3 0:1:1
loc v 10 var 0:1:6
loc m 11 var 0:1:9
loc w 10 let 0:7:6
call 0:1:14 12 2 0
tbind 0:1:1 2 1 2
lv 0:5:1 10 1
lv 0:5:3 11 2
idx 0:5:1 10 1
cf 0:5:8 4 #0000000000000000
asg 0:5:1 set
lv 0:6:22 10 1
ci 0:6:24 3 0
idx 0:6:22 4 1
fconv 0:6:8 1 - - - g
ftext 0:6:8 1 %20
lv 0:6:28 10 1
ci 0:6:30 3 1
idx 0:6:28 4 1
fconv 0:6:8 1 - - - g
ftext 0:6:8 1 %20
lv 0:6:34 10 1
ci 0:6:36 3 2
idx 0:6:34 4 1
fconv 0:6:8 1 - - - g
ftext 0:6:8 1 %0A
fmt 0:6:8 1 6
lib 0:6:1 1 printf 1
eval 0:6:1
call 0:7:14 12 2 0
tbind 0:7:1 2 3 -
lv 0:8:16 10 3
ci 0:8:18 3 3
idx 0:8:16 4 1
fconv 0:8:8 1 - - - g
ftext 0:8:8 1 %0A
fmt 0:8:8 1 2
lib 0:8:1 1 printf 1
eval 0:8:1
block 0:1:1 5
end
fn 2 two fn 12 0 3 0:9:1
loc v 10 var 0:10:9
loc m 11 var 0:11:9
loc k 3 for 0:12:9
ci 0:10:18 3 4
lib 0:10:13 10 ones 1
bind 0:10:5 1
cb 0:11:20 2 1
ci 0:11:26 3 4
lib 0:11:13 11 filled 2
bind 0:11:5 2
ci 0:12:14 3 0
ci 0:12:17 3 2
rng 0:12:14 13 0 0
lv 0:13:9 11 2
ci 0:13:11 3 2
lv 0:13:15 3 3
bin 0:13:11 3 mul
ci 0:13:19 3 1
bin 0:13:11 3 add
idx 0:13:9 2 1
cb 0:13:24 2 0
asg 0:13:9 set
block 0:12:19 1
forr 0:12:5 3
lv 0:15:13 10 1
lv 0:15:16 11 2
ret 0:15:5 2
block 0:9:29 4
end
'''


def hirl_arr_rule21():
    """sea.hirl: tptr 14 4 and tptr 15 2 (first referred to by the adat of v and of m in the L6
    block of line 5). .main: the store is L6 (written out below). two: ones(4) and filled(true, 4)
    are L2 (vectors)."""
    F1, F2 = Fn(), Fn()
    P = '0:5:1'                                    # the asg's position
    x = Ctx(F1, P, 's')
    T = lambda: lv(P, 10, 1)                       # lv v: the target's root, read afresh (IX)
    st = [x.tmp('Vv', cf('0:5:8', '#0000000000000000')),        # 1. a scalar value: tmp Vv
          x.tmp('M', lv('0:5:3', 11, 2))]                        # 2. IX 1 of the mask: tmp M
    # 3. IX 2, dimension 0, a mask M: tmp X = ext of the dimension, tmp NM = ext(M, 0), tmp S =
    # bin ne (lv X) (lv NM), vchk(SHAPE_MISMATCH; S, X, NM)
    st += [x.tmp('X', ext(P, 0, T())),
           x.tmp('NM', ext(P, 0, x.lvl('M'))),
           x.tmp('S', bin_(P, 2, 'ne', x.lvl('X'), x.lvl('NM')))]
    st += x.vchk('SHAPE_MISMATCH', 'S', 'X', 'NM', 'V')
    # 4. (a scalar value: no shape check); 5. cow (lv v); 6. tmp DT = data(T), the DM of the mask
    st += [cow(P, T()),
           x.tmp('DT', adat(P, 14, T())),
           x.tmp('DM', adat(P, 15, x.lvl('M')))]
    # 7. IX 4, M: loop(X; Q) { if (eld bool 1 0 (lv DM) (lv Q)) { est 8 0 (lv Vv) (lv DT) pos } },
    # pos = Q (a vector base)
    st += x.loop('X', 'Z', 'O', 'L', 'Q', lambda: [
        if_(P, eld(P, 2, x.lvl('DM'), x.klv('Q')),
            block(P, [est(P, 4, x.lvl('Vv'), x.lvl('DT'), x.klv('Q'))]))])
    m_store = ('''
lv 0:5:1 10 1
lv 0:5:3 11 2
idx 0:5:1 10 1
cf 0:5:8 4 #0000000000000000
asg 0:5:1 set
''', cat(block(P, st)))
    t_ones = (['ci 0:10:18 3 4', 'lib 0:10:13 10 ones 1'],
              cat(L2(F2, '0:10:13', 10, 4, 14, 'o', r=ci('0:10:18', 4))))
    t_fill = (['cb 0:11:20 2 1', 'ci 0:11:26 3 4', 'lib 0:11:13 11 filled 2'],
              cat(L2(F2, '0:11:13', 11, 2, 15, 'f', r=ci('0:11:26', 4), v=cb('0:11:20', 1))))
    return make_hirl(HIR1['arr_rule21'], ['tptr 14 4', 'tptr 15 2'],
                     {1: (F1, [m_store]), 2: (F2, [t_ones, t_fill])})


HIRL['arr_rule21'] = hirl_arr_rule21
# sea.lir1. .main: the call of line 1 into p1, p2 (rule 2); the example of rule 21 (line 5); the
# printf of three element reads (rule 18, rule 8: a slot of 24 bytes); `let (w, _) = two()`: the
# _ component's register released right after the statement (rule 15 (h)); at the end of the
# body block w, m, v released in reverse order of declaration (rule 16 (a)). two: ones(4) and
# filled(true, 4) (rule 17 by L2, each moved into its local by T3); the for loop (rule 4) with
# the element store m[2 * k + 1] = false (rule 19: the value, the index with imulc and iaddc, the
# check, cow(m), data, stb); return (v, m): both retained (rule 16 (c), 15 (a)), then the locals
# released in reverse order, then ret.
LIR1['arr_rule21'] = '''
func .main main 0:1:1 0 0
slot s1 24 8
slot s2 8 8
call two 2 p.v p.m 0
lf f.v0 #0000000000000000
ldi i.X p.v - 0 16
ldi i.NM p.m - 0 16
icmp ne i.S i.X i.NM
li i.V -1
chk i.S SHAPE_MISMATCH 0:5 4 i.X i.V i.NM i.V
ldi i.rc p.v - 0 0
li i.o 1
icmp ne i.sh i.rc i.o
if 1 i.sh
rcall sea_arr_unique 0:5 1 p.u 1 p.v
mov p.v p.u
endif 1
ldp p.DT p.v - 0 40
ldp p.DM p.m - 0 40
li i.Z 0
icmp gt i.g i.X i.Z
if 2 i.g
li i.O 1
isub i.L i.X i.O
loop 3 i.Q i.Z i.L i.O
ldb i.b p.DM i.Q 1 0
if 4 i.b
stf f.v0 p.DT i.Q 8 0
endif 4
endloop 3
endif 2
li i.k0 0
ldi i.e0 p.v - 0 16
chkb i.k0 i.e0 0 0:6
ldp p.d0 p.v - 0 40
ldf f.x0 p.d0 i.k0 8 0
li i.k1 1
ldi i.e1 p.v - 0 16
chkb i.k1 i.e1 0 0:6
ldp p.d1 p.v - 0 40
ldf f.x1 p.d1 i.k1 8 0
li i.k2 2
ldi i.e2 p.v - 0 16
chkb i.k2 i.e2 0 0:6
ldp p.d2 p.v - 0 40
ldf f.x2 p.d2 i.k2 8 0
sa p.s6 s1
stf f.x0 p.s6 - 0 0
stf f.x1 p.s6 - 0 8
stf f.x2 p.s6 - 0 16
la p.f6 d1
rcall sea_printf 0:6 0 2 p.f6 p.s6
call two 2 p.w p.skip 0
release p.skip
li i.k3 3
ldi i.e3 p.w - 0 16
chkb i.k3 i.e3 0 0:8
ldp p.d3 p.w - 0 40
ldf f.x3 p.d3 i.k3 8 0
sa p.s8 s2
stf f.x3 p.s8 - 0 0
la p.f8 d2
rcall sea_printf 0:8 0 2 p.f8 p.s8
release p.w
release p.m
release p.v
ret 0
endfunc
func two fn 0:9:1 0 2 p p
li i.R1 4
li i.ek1 1
li i.rk1 1
li i.c1 1
rcall sea_arr_new_u 0:10 1 p.v 4 i.ek1 i.rk1 i.R1 i.c1
lf f.V1 #3FF0000000000000
ldp p.D1 p.v - 0 40
li i.Z1 0
icmp gt i.g1 i.R1 i.Z1
if 1 i.g1
li i.O1 1
isub i.L1 i.R1 i.O1
loop 2 i.K1 i.Z1 i.L1 i.O1
stf f.V1 p.D1 i.K1 8 0
endloop 2
endif 1
li i.V2 1
li i.R2 4
li i.ek2 3
li i.rk2 1
li i.c2 1
rcall sea_arr_new_u 0:11 1 p.m 4 i.ek2 i.rk2 i.R2 i.c2
ldp p.D2 p.m - 0 40
li i.Z2 0
icmp gt i.g2 i.R2 i.Z2
if 3 i.g2
li i.O2 1
isub i.L2 i.R2 i.O2
loop 4 i.K2 i.Z2 i.L2 i.O2
stb i.V2 p.D2 i.K2 1 0
endloop 4
endif 3
li i.lo 0
li i.hi 2
li i.st 1
rcount i.C i.E i.lo i.hi i.st 0 0:12
if 5 i.E
loop 6 i.k i.lo i.C i.st
li i.f 0
li i.two 2
imulc i.m2 i.two i.k 0:13
li i.one 1
iaddc i.ix i.m2 i.one 0:13
ldi i.ex p.m - 0 16
chkb i.ix i.ex 0 0:13
ldi i.rc p.m - 0 0
li i.o 1
icmp ne i.sh i.rc i.o
if 7 i.sh
rcall sea_arr_unique 0:13 1 p.u 1 p.m
mov p.m p.u
endif 7
ldp p.dm p.m - 0 40
stb i.f p.dm i.ix 1 0
endloop 6
endif 5
retain p.v
retain p.m
release p.m
release p.v
ret 2 p.v p.m
endfunc
fmt d1 6
fconv - - - g f
ftext %20
fconv - - - g f
ftext %20
fconv - - - g f
ftext %0A
fmt d2 2
fconv - - - g f
ftext %0A
'''
# two() returns v = [1, 1, 1, 1] and m = [T, F, T, F] (the loop stores false at 1 and 3); v[m] =
# 0.0 stores at 0 and 2: v = [0, 1, 0, 1]; prints 0 1 0. The second call's w = [1, 1, 1, 1]: w[3] = 1.
OUT['arr_rule21'] = '0 1 0\n1\n'
NAMES.append('arr_rule21')

# ================================================================ arr_rule22 (rule 22)
# The example's x is p1, the parameter of twice; its statement is the first of twice, on line 2.
SEA['arr_rule22'] = '''fn twice(x: f64[]) -> f64 {
    let z = x * 2.0
    var s = 0.0
    for e in z {
        s += e
    }
    return s
}
printf("%g\\n", twice(ones(3)))
printf("%g\\n", twice(zeros(2)))
// arr_rule22 -- DESIGN.md 3.6.6 rule 22 (element-wise operations): its example verbatim on line
// 2, the first statement of twice (x is p1); 3.5.9 L7 with one array operand (no shape check)
'''
AST['arr_rule22'] = '''
type 0:1:13 f64 v 0
param 0:1:10 x 0 0
type 0:1:23 f64 s 0
pname 0:2:9 z
name 0:2:13 x
float 0:2:17 #4000000000000000
bin 0:2:13 mul
let 0:2:5 0
pname 0:3:9 s
float 0:3:13 #0000000000000000
var 0:3:5 0
name 0:4:14 z
name 0:5:9 s
name 0:5:14 e
asg 0:5:9 add
block 0:4:16 1
for 0:4:5 e 0:4:9
name 0:7:12 s
return 0:7:5 1
block 0:1:27 4
fn 0:1:1 twice 0 1 1
name 0:9:1 printf
str 0:9:8 %25g%0A
name 0:9:16 twice
name 0:9:22 ones
int 0:9:27 3
call 0:9:22 1
call 0:9:16 1
call 0:9:1 2
cstmt 0:9:1
name 0:10:1 printf
str 0:10:8 %25g%0A
name 0:10:16 twice
name 0:10:22 zeros
int 0:10:28 2
call 0:10:22 1
call 0:10:16 1
call 0:10:1 2
cstmt 0:10:1
prog 3
'''
# sea.hir1: f64[] 10 (first referred to by the ones of .main, which comes first in the file:
# functions are in fid order, 3.5.4). x * 2.0 is an element-wise bin of a dynamic f64[] (3.5.5).
HIR1['arr_rule22'] = '''
tvec 10 4
fn 1 .main main 1 0 0 0:1:1
ci 0:9:27 3 3
lib 0:9:22 10 ones 1
call 0:9:16 4 2 1
fconv 0:9:8 1 - - - g
ftext 0:9:8 1 %0A
fmt 0:9:8 1 2
lib 0:9:1 1 printf 1
eval 0:9:1
ci 0:10:28 3 2
lib 0:10:22 10 zeros 1
call 0:10:16 4 2 1
fconv 0:10:8 1 - - - g
ftext 0:10:8 1 %0A
fmt 0:10:8 1 2
lib 0:10:1 1 printf 1
eval 0:10:1
block 0:1:1 2
end
fn 2 twice fn 4 1 3 0:1:1
par x 10 val
loc z 10 let 0:2:9
loc s 4 var 0:3:9
loc e 4 for 0:4:9
lv 0:2:13 10 1
cf 0:2:17 4 #4000000000000000
bin 0:2:13 10 mul
bind 0:2:5 2
cf 0:3:13 4 #0000000000000000
bind 0:3:5 3
lv 0:4:14 10 2
lv 0:5:9 4 3
lv 0:5:14 4 4
asg 0:5:9 add
block 0:4:16 1
fore 0:4:5 4
lv 0:7:12 4 3
ret 0:7:5 1
block 0:1:27 4
end
'''


def hirl_arr_rule22():
    """sea.hirl: tptr 11 4 (first referred to by the adat of ones(3) in .main). .main: ones(3) is
    L2, zeros(2) L1. twice: x * 2.0 is L7 (written out below), the for over z L4."""
    F1, F2 = Fn(), Fn()
    m_ones = (['ci 0:9:27 3 3', 'lib 0:9:22 10 ones 1'],
              cat(L2(F1, '0:9:22', 10, 4, 11, 'o', r=ci('0:9:27', 3))))
    m_zeros = (['ci 0:10:28 3 2', 'lib 0:10:22 10 zeros 1'],
               cat(L1('0:10:22', 10, [ci('0:10:28', 2)])))
    P = '0:2:13'                                   # the bin's position
    x = Ctx(F2, P, 'e')
    # (1) tmp Ak = operand k, left to right (the scalar too)
    st = [x.tmp('A1', lv('0:2:13', 10, 1)),
          x.tmp('A2', cf('0:2:17', '#4000000000000000'))]
    # (2) a dynamic result: the extents of every array operand (one: N1); no check with one array
    # operand; (3) tmp RES = anew P T 0 1 (lv N1); (5) tmp DR = data(RES), tmp D1 = data(A1)
    st += [x.tmp('N1', ext(P, 0, x.lvl('A1'))),
           x.tmp('RES', anew(P, 10, 0, [x.lvl('N1')])),
           x.tmp('DR', adat(P, 11, x.lvl('RES'))),
           x.tmp('D1', adat(P, 11, x.lvl('A1')))]
    # (6) loop(N1; I) { est 8 0 F (lv DR) (lv I) }, F = the bin itself (its own position, now of the
    # element type) with the array operand replaced by its eld and the scalar by lv A2
    st += x.loop('N1', 'Z', 'O', 'L', 'I', lambda: [
        est(P, 4, bin_('0:2:13', 4, 'mul', eld(P, 4, x.lvl('D1'), x.klv('I')), x.lvl('A2')),
            x.lvl('DR'), x.klv('I'))])
    t_mul = (['lv 0:2:13 10 1', 'cf 0:2:17 4 #4000000000000000', 'bin 0:2:13 10 mul'],
             cat(xblk(P, st, x.lvl('RES'))))
    t_fore = ('''
lv 0:4:14 10 2
lv 0:5:9 4 3
lv 0:5:14 4 4
asg 0:5:9 add
block 0:4:16 1
fore 0:4:5 4
''', cat(L4(F2, '0:4:5', 4, 11, 'f', 4, lv('0:4:14', 10, 2), '''
lv 0:5:9 4 3
lv 0:5:14 4 4
asg 0:5:9 add
block 0:4:16 1
''')))
    return make_hirl(HIR1['arr_rule22'], ['tptr 11 4'],
                     {1: (F1, [m_ones, m_zeros]), 2: (F2, [t_mul, t_fore])})


HIRL['arr_rule22'] = hirl_arr_rule22
# sea.lir1. .main: ones(3) (L2, an owned temporary of the call, released after it), zeros(2)
# (arrnewz, the same). twice: the example of rule 22 (line 2), var s, the element loop over z
# (rule 30), z released before the ret (rule 16 (c)).
LIR1['arr_rule22'] = '''
func .main main 0:1:1 0 0
slot s1 8 8
slot s2 8 8
li i.R 3
li i.ek 1
li i.rk 1
li i.c 1
rcall sea_arr_new_u 0:9 1 p.A 4 i.ek i.rk i.R i.c
lf f.V #3FF0000000000000
ldp p.D p.A - 0 40
li i.Z 0
icmp gt i.g i.R i.Z
if 1 i.g
li i.O 1
isub i.L i.R i.O
loop 2 i.K i.Z i.L i.O
stf f.V p.D i.K 8 0
endloop 2
endif 1
call twice 1 f.r1 1 p.A
release p.A
sa p.s1 s1
stf f.r1 p.s1 - 0 0
la p.f1 d1
rcall sea_printf 0:9 0 2 p.f1 p.s1
li i.n2 2
li i.ek2 1
li i.rk2 1
li i.c2 1
rcall sea_arr_new 0:10 1 p.z2 4 i.ek2 i.rk2 i.n2 i.c2
call twice 1 f.r2 1 p.z2
release p.z2
sa p.s2 s2
stf f.r2 p.s2 - 0 0
la p.f2 d2
rcall sea_printf 0:10 0 2 p.f2 p.s2
ret 0
endfunc
func twice fn 0:1:1 1 p.x 1 f
lf f.two #4000000000000000
ldi i.N p.x - 0 16
li i.ek 1
li i.rk 1
li i.c 1
rcall sea_arr_new_u 0:2 1 p.z 4 i.ek i.rk i.N i.c
ldp p.DR p.z - 0 40
ldp p.D1 p.x - 0 40
li i.Z 0
icmp gt i.g i.N i.Z
if 1 i.g
li i.O 1
isub i.L i.N i.O
loop 2 i.I i.Z i.L i.O
ldf f.el p.D1 i.I 8 0
fmul f.pr f.el f.two
stf f.pr p.DR i.I 8 0
endloop 2
endif 1
lf f.s #0000000000000000
mov p.H p.z
retain p.H
ldi i.n p.H - 0 16
li i.z 0
icmp gt i.g2 i.n i.z
if 3 i.g2
ldp p.d p.H - 0 40
li i.o 1
isub i.l i.n i.o
loop 4 i.k i.z i.l i.o
ldf f.e p.d i.k 8 0
fadd f.s f.s f.e
endloop 4
endif 3
release p.H
release p.z
ret 1 f.s
endfunc
fmt d1 2
fconv - - - g f
ftext %0A
fmt d2 2
fconv - - - g f
ftext %0A
'''
# twice(ones(3)) = 2 + 2 + 2 = 6; twice(zeros(2)) = 0.
OUT['arr_rule22'] = '6\n0\n'
NAMES.append('arr_rule22')


# ================================================================ arr_rule25 (rule 25)
# The example's nBin is i1, the parameter of hist; lines 2-3 are comments, so the range value of
# line 4 is the first code of hist.
SEA['arr_rule25'] = '''fn hist(nBin: i64) -> i64 {
    // arr_rule25 -- DESIGN.md 3.6.6 rule 25 (range values): its example verbatim on line 4,
    // (0..=nBin) as a value with nBin in i1 (3.5.9 L8: rcnt, the length, the size check)
    let edges = (0..=nBin)
    var t = 0
    for e in edges {
        t += e
    }
    return t
}
printf("%d\\n", hist(3))
printf("%d\\n", hist(0))
// hist(3) sums 0, 1, 2, 3; hist(0) sums the one element 0
'''
AST['arr_rule25'] = '''
type 0:1:15 i64 s 0
param 0:1:9 nBin 0 0
type 0:1:23 i64 s 0
pname 0:4:9 edges
int 0:4:18 0
name 0:4:22 nBin
range 0:4:18 1 0
rangev 0:4:17
let 0:4:5 0
pname 0:5:9 t
int 0:5:13 0
var 0:5:5 0
name 0:6:14 edges
name 0:7:9 t
name 0:7:14 e
asg 0:7:9 add
block 0:6:20 1
for 0:6:5 e 0:6:9
name 0:9:12 t
return 0:9:5 1
block 0:1:27 4
fn 0:1:1 hist 0 1 1
name 0:11:1 printf
str 0:11:8 %25d%0A
name 0:11:16 hist
int 0:11:21 3
call 0:11:16 1
call 0:11:1 2
cstmt 0:11:1
name 0:12:1 printf
str 0:12:8 %25d%0A
name 0:12:16 hist
int 0:12:21 0
call 0:12:16 1
call 0:12:1 2
cstmt 0:12:1
prog 3
'''
# sea.hir1: i64[] 10 (first referred to by `loc edges`). (0..=nBin) is a rng used as a value, of
# type i64[] (3.5.5); the parentheses (the AST's rangev) write no node, and the rng takes the
# position of the AST range node it is made from (3.5.5: a node made from one AST node takes that
# node's position; parentheses are not part of the enclosed node's text, 3.3).
HIR1['arr_rule25'] = '''
tvec 10 3
fn 1 .main main 1 0 0 0:1:1
ci 0:11:21 3 3
call 0:11:16 3 2 1
fconv 0:11:8 1 - - - d
ftext 0:11:8 1 %0A
fmt 0:11:8 1 2
lib 0:11:1 1 printf 1
eval 0:11:1
ci 0:12:21 3 0
call 0:12:16 3 2 1
fconv 0:12:8 1 - - - d
ftext 0:12:8 1 %0A
fmt 0:12:8 1 2
lib 0:12:1 1 printf 1
eval 0:12:1
block 0:1:1 2
end
fn 2 hist fn 3 1 3 0:1:1
par nBin 3 val
loc edges 10 let 0:4:9
loc t 3 var 0:5:9
loc e 3 for 0:6:9
ci 0:4:18 3 0
lv 0:4:22 3 1
rng 0:4:18 10 1 0
bind 0:4:5 2
ci 0:5:13 3 0
bind 0:5:5 3
lv 0:6:14 10 2
lv 0:7:9 3 3
lv 0:7:14 3 4
asg 0:7:9 add
block 0:6:20 1
fore 0:6:5 4
lv 0:9:12 3 3
ret 0:9:5 1
block 0:1:27 4
end
'''


def hirl_arr_rule25():
    """sea.hirl: tptr 11 3 (first referred to by the adat of L8). hist: the range value is L8
    (written out below), the for over edges L4. .main is unchanged."""
    F2 = Fn()
    P = '0:4:18'                                   # the rng's position (P and every site)
    x = Ctx(F2, P, 'r')
    st = [x.tmp('LO', ci('0:4:18', 0)),
          x.tmp('HI', lv('0:4:22', 3, 1)),
          x.tmp('ST', ci(P, 1)),                   # no step: ci 1
          x.rcnt(1, 'L', 'E', 'LO', 'HI', 'ST', P),
          x.tmp('O1', ci(P, 1)),
          x.tmp('T', wbin(P, 'add', x.lvl('L'), x.lvl('O1'))),
          x.tmp('Z', ci(P, 0)),
          x.tmp('N', lib(P, 3, 'where', [x.lvl('E'), x.lvl('T'), x.lvl('Z')])),
          # SEA_LIM_EXTENT - 1 = 2147483646 and 9223372036854775807, each written as the field
          # text of type i (3.1: outside -10^9 < v < 10^9, # and 16 hex digits)
          x.tmp('X', ci(P, '#000000007FFFFFFE')),
          x.tmp('G', bin_(P, 2, 'gt', x.lvl('L'), x.lvl('X'))),
          x.tmp('U', bin_(P, 2, 'lt', x.lvl('L'), x.lvl('Z')))]
    st += [x.bindl('Bf', bin_(P, 2, 'bor', x.lvl('G'), x.lvl('U')))]
    st += [asg(P, 'set', x.lvl('Bf'), bin_(P, 2, 'band', x.lvl('Bf'), x.lvl('E'))),
           x.tmp('MX', ci(P, '#7FFFFFFFFFFFFFFF'))]
    st += [x.bindl('Ef', bin_(P, 2, 'eq', x.lvl('L'), x.lvl('MX')))]
    st += [asg(P, 'set', x.lvl('Ef'), bin_(P, 2, 'bor', x.lvl('Ef'), x.lvl('U'))),
           x.tmp('V', lib(P, 3, 'where', [x.lvl('Ef'), x.lvl('MX'), x.lvl('T')])),
           chk(P, 'ARRAY_SIZE', x.lvl('Bf'), [x.lvl('V')]),
           x.tmp('A', anew(P, 10, 0, [x.lvl('N')])),
           x.tmp('D', adat(P, 11, x.lvl('A')))]
    st += [x.bindl('Q', ci(P, 0))]
    st += [x.tmp('One', ci(P, 1)),
           x.rloop('E', 'LO', 'L', 'ST', 'K', lambda: [
               est(P, 3, x.klv('K'), x.lvl('D'), x.lvl('Q')),
               x.plus_eq('Q', x.lvl('One'))])]
    t_rng = (['ci 0:4:18 3 0', 'lv 0:4:22 3 1', 'rng 0:4:18 10 1 0'],
             cat(xblk(P, st, x.lvl('A'))))
    t_fore = ('''
lv 0:6:14 10 2
lv 0:7:9 3 3
lv 0:7:14 3 4
asg 0:7:9 add
block 0:6:20 1
fore 0:6:5 4
''', cat(L4(F2, '0:6:5', 3, 11, 'f', 4, lv('0:6:14', 10, 2), '''
lv 0:7:9 3 3
lv 0:7:14 3 4
asg 0:7:9 add
block 0:6:20 1
''')))
    return make_hirl(HIR1['arr_rule25'], ['tptr 11 3'], {2: (F2, [t_rng, t_fore])})


HIRL['arr_rule25'] = hirl_arr_rule25
# sea.lir1. hist: the example of rule 25 (line 4, its two large constants in the 3.1 encoding),
# moved into edges (T3); var t; the element loop over edges (rule 30) with t += e (iaddc, the
# asg's line); edges released before the ret.
LIR1['arr_rule25'] = '''
func .main main 0:1:1 0 0
slot s1 8 8
slot s2 8 8
li i.a 3
call hist 1 i.r1 1 i.a
sa p.s1 s1
sti i.r1 p.s1 - 0 0
la p.f1 d1
rcall sea_printf 0:11 0 2 p.f1 p.s1
li i.b 0
call hist 1 i.r2 1 i.b
sa p.s2 s2
sti i.r2 p.s2 - 0 0
la p.f2 d2
rcall sea_printf 0:12 0 2 p.f2 p.s2
ret 0
endfunc
func hist fn 0:1:1 1 i.nBin 1 i
li i.lo 0
li i.st 1
rcount i.L i.E i.lo i.nBin i.st 1 0:4
li i.O1 1
iadd i.T i.L i.O1
li i.Z 0
isel i.N i.E i.T i.Z
li i.X #000000007FFFFFFE
icmp gt i.G i.L i.X
icmp lt i.U i.L i.Z
ior i.Bf i.G i.U
iand i.Bf i.Bf i.E
li i.MX #7FFFFFFFFFFFFFFF
icmp eq i.Ef i.L i.MX
ior i.Ef i.Ef i.U
isel i.V i.Ef i.MX i.T
chk i.Bf ARRAY_SIZE 0:4 1 i.V
li i.ek 2
li i.rk 1
li i.c 1
rcall sea_arr_new_u 0:4 1 p.edges 4 i.ek i.rk i.N i.c
ldp p.D p.edges - 0 40
li i.Q 0
li i.One 1
if 1 i.E
loop 2 i.K i.lo i.L i.st
sti i.K p.D i.Q 8 0
iadd i.Q i.Q i.One
endloop 2
endif 1
li i.t 0
mov p.H p.edges
retain p.H
ldi i.n p.H - 0 16
li i.z 0
icmp gt i.g i.n i.z
if 3 i.g
ldp p.d p.H - 0 40
li i.o 1
isub i.l i.n i.o
loop 4 i.k i.z i.l i.o
ldi i.e p.d i.k 8 0
iaddc i.t i.t i.e 0:7
endloop 4
endif 3
release p.H
release p.edges
ret 1 i.t
endfunc
fmt d1 2
fconv - - - d i
ftext %0A
fmt d2 2
fconv - - - d i
ftext %0A
'''
# hist(3): edges = [0, 1, 2, 3], t = 6; hist(0): edges = [0], t = 0.
OUT['arr_rule25'] = '6\n0\n'
NAMES.append('arr_rule25')


# ================================================================ arr_rule28 (rule 28)
# The example's A is p1 and k i2, the parameters of flat_at; line 2 is a comment, so the folded
# view of line 3 is the first code of flat_at.
SEA['arr_rule28'] = '''fn flat_at(A: f64[,], k: i64) -> f64 {
    // arr_rule28 -- DESIGN.md 3.6.6 rule 28 (views): its example verbatim on line 3
    let e = A.flat[k]
    var s = e
    for i in 0..k {
        s += 1.0
    }
    return s
}
var M = zeros(2, 3)
M[0, 2] = 7.5
printf("%g\\n", flat_at(M, 4))
printf("%g\\n", flat_at(M, 1))
// A.flat[k] is a folded view (3.5.9 L5 with a view base and a scalar index): the extent of
// .flat is rows * cols, the element is read at the linear position k (M[0, 2] is position 4)
'''
AST['arr_rule28'] = '''
type 0:1:15 f64 m 0
param 0:1:12 A 0 0
type 0:1:26 i64 s 0
param 0:1:23 k 0 0
type 0:1:34 f64 s 0
pname 0:3:9 e
name 0:3:13 A
dot 0:3:13 flat
name 0:3:20 k
index 0:3:13 1
let 0:3:5 0
pname 0:4:9 s
name 0:4:13 e
var 0:4:5 0
int 0:5:14 0
name 0:5:17 k
range 0:5:14 0 0
name 0:6:9 s
float 0:6:14 #3FF0000000000000
asg 0:6:9 add
block 0:5:19 1
for 0:5:5 i 0:5:9
name 0:8:12 s
return 0:8:5 1
block 0:1:38 4
fn 0:1:1 flat_at 0 2 1
pname 0:10:5 M
name 0:10:9 zeros
int 0:10:15 2
int 0:10:18 3
call 0:10:9 2
var 0:10:1 0
name 0:11:1 M
int 0:11:3 0
int 0:11:6 2
index 0:11:1 2
float 0:11:11 #401E000000000000
asg 0:11:1 set
name 0:12:1 printf
str 0:12:8 %25g%0A
name 0:12:16 flat_at
name 0:12:24 M
int 0:12:27 4
call 0:12:16 2
call 0:12:1 2
cstmt 0:12:1
name 0:13:1 printf
str 0:13:8 %25g%0A
name 0:13:16 flat_at
name 0:13:24 M
int 0:13:27 1
call 0:13:16 2
call 0:13:1 2
cstmt 0:13:1
prog 5
'''
# sea.hir1: f64[,] 10 (`loc M` of .main), f64[] 11 (the view .flat of a dynamic matrix: a dynamic
# vector, 3.5.5 "A view is fixed exactly when its operand is"), i64[] 12 (the rng of the for).
# The view takes the position of the dot (3.5.5), the operand's first token.
HIR1['arr_rule28'] = '''
tmat 10 4
tvec 11 4
tvec 12 3
fn 1 .main main 1 0 1 0:1:1
loc M 10 var 0:10:5
ci 0:10:15 3 2
ci 0:10:18 3 3
lib 0:10:9 10 zeros 2
bind 0:10:1 1
lv 0:11:1 10 1
ci 0:11:3 3 0
ci 0:11:6 3 2
idx 0:11:1 4 2
cf 0:11:11 4 #401E000000000000
asg 0:11:1 set
lv 0:12:24 10 1
ci 0:12:27 3 4
call 0:12:16 4 2 2
fconv 0:12:8 1 - - - g
ftext 0:12:8 1 %0A
fmt 0:12:8 1 2
lib 0:12:1 1 printf 1
eval 0:12:1
lv 0:13:24 10 1
ci 0:13:27 3 1
call 0:13:16 4 2 2
fconv 0:13:8 1 - - - g
ftext 0:13:8 1 %0A
fmt 0:13:8 1 2
lib 0:13:1 1 printf 1
eval 0:13:1
block 0:1:1 4
end
fn 2 flat_at fn 4 2 3 0:1:1
par A 10 val
par k 3 val
loc e 4 let 0:3:9
loc s 4 var 0:4:9
loc i 3 for 0:5:9
lv 0:3:13 10 1
view 0:3:13 11 flat
lv 0:3:20 3 2
idx 0:3:13 4 1
bind 0:3:5 3
lv 0:4:13 4 3
bind 0:4:5 4
ci 0:5:14 3 0
lv 0:5:17 3 2
rng 0:5:14 12 0 0
lv 0:6:9 4 4
cf 0:6:14 4 #3FF0000000000000
asg 0:6:9 add
block 0:5:19 1
forr 0:5:5 5
lv 0:8:12 4 4
ret 0:8:5 1
block 0:1:38 4
end
'''


def hirl_arr_rule28():
    """sea.hirl: tptr 13 4 (first referred to by the adat of the folded read). .main: zeros(2, 3)
    is L1. flat_at: A.flat[k] is L5 with a view base and a scalar index (written out below)."""
    F1, F2 = Fn(), Fn()
    m_zeros = (['ci 0:10:15 3 2', 'ci 0:10:18 3 3', 'lib 0:10:9 10 zeros 2'],
               cat(L1('0:10:9', 10, [ci('0:10:15', 2), ci('0:10:18', 3)])))
    P = '0:3:13'                                   # the idx's position
    x = Ctx(F2, P, 'v')
    # tmp B = the view's operand; IX 1 (S): tmp I = the index; IX 2: the extent of the .flat's
    # dimension 0 (tmp R = ext(B, 0), tmp C = ext(B, 1), tmp X = wbin mul (lv R) (lv C)), chkb
    st = [x.tmp('B', lv('0:3:13', 10, 1)),
          x.tmp('I', lv('0:3:20', 3, 2)),
          x.tmp('R', ext(P, 0, x.lvl('B'))),
          x.tmp('C', ext(P, 1, x.lvl('B'))),
          x.tmp('X', wbin(P, 'mul', x.lvl('R'), x.lvl('C'))),
          chkb(P, 0, x.lvl('I'), x.lvl('X'))]
    # every index scalar: the value after IX 2 is `eld E s 0 data(B) pos`, pos = k (.flat maps k
    # to k)
    val = eld(P, 4, adat(P, 13, x.lvl('B')), x.lvl('I'))
    t_flat = (['lv 0:3:13 10 1', 'view 0:3:13 11 flat', 'lv 0:3:20 3 2', 'idx 0:3:13 4 1'],
              cat(xblk(P, st, val)))
    return make_hirl(HIR1['arr_rule28'], ['tptr 13 4'],
                     {1: (F1, [m_zeros]), 2: (F2, [t_flat])})


HIRL['arr_rule28'] = hirl_arr_rule28
# sea.lir1. .main: zeros(2, 3) (arrnewz), M[0, 2] = 7.5 (rule 19 on a matrix: the linear index
# imul, iadd), two calls. flat_at: the example of rule 28 (line 3), its eld into e (the xblk's
# destination, rule 2); var s = e (mov); the range loop (rule 4).
LIR1['arr_rule28'] = '''
func .main main 0:1:1 0 0
slot s1 8 8
slot s2 8 8
li i.r 2
li i.c 3
li i.ek 1
li i.rk 2
rcall sea_arr_new 0:10 1 p.M 4 i.ek i.rk i.r i.c
lf f.v #401E000000000000
li i.i0 0
li i.j0 2
ldi i.e0 p.M - 0 16
chkb i.i0 i.e0 0 0:11
ldi i.e1 p.M - 0 24
chkb i.j0 i.e1 1 0:11
ldi i.rc p.M - 0 0
li i.o 1
icmp ne i.sh i.rc i.o
if 1 i.sh
rcall sea_arr_unique 0:11 1 p.u 1 p.M
mov p.M p.u
endif 1
ldp p.d p.M - 0 40
imul i.t i.j0 i.e0
iadd i.x i.i0 i.t
stf f.v p.d i.x 8 0
li i.k1 4
call flat_at 1 f.r1 2 p.M i.k1
sa p.s1 s1
stf f.r1 p.s1 - 0 0
la p.f1 d1
rcall sea_printf 0:12 0 2 p.f1 p.s1
li i.k2 1
call flat_at 1 f.r2 2 p.M i.k2
sa p.s2 s2
stf f.r2 p.s2 - 0 0
la p.f2 d2
rcall sea_printf 0:13 0 2 p.f2 p.s2
release p.M
ret 0
endfunc
func flat_at fn 0:1:1 2 p.A i.k 1 f
ldi i.R p.A - 0 16
ldi i.C p.A - 0 24
imul i.X i.R i.C
chkb i.k i.X 0 0:3
ldp p.D p.A - 0 40
ldf f.e p.D i.k 8 0
mov f.s f.e
li i.lo 0
li i.st 1
rcount i.cnt i.E i.lo i.k i.st 0 0:5
if 1 i.E
loop 2 i.i i.lo i.cnt i.st
lf f.one #3FF0000000000000
fadd f.s f.s f.one
endloop 2
endif 1
ret 1 f.s
endfunc
fmt d1 2
fconv - - - g f
ftext %0A
fmt d2 2
fconv - - - g f
ftext %0A
'''
# M = [0 0 7.5; 0 0 0] (column-major: position 4 is M[0, 2]); flat_at(M, 4) = 7.5 + 4 * 1.0 = 11.5;
# flat_at(M, 1) = M[1, 0] + 1.0 = 1.
OUT['arr_rule28'] = '11.5\n1\n'
NAMES.append('arr_rule28')

# ================================================================ sel_reads (rule 20 / L5)
SEA['sel_reads'] = '''var A = zeros(2, 3)
A[0, 2] = 5.0
A[1, 2] = 6.0
let c = A[:, 2]
let w = filled(1, 2)
let r = c[w]
let M = A > 5.5
let s = A[M]
printf("%g %g %g %d %g\\n", c[0], c[1], r[0], len(r), s[0])
// sel_reads -- DESIGN.md 3.5.9 L5 (rule 20): a matrix selection with : and a scalar (line 4),
// an index vector with a repeat (line 6) and a whole-matrix mask (line 8, the mask computed by
// the element-wise comparison of line 7, 3.5.9 L7 of a matrix with a scalar)
'''
AST['sel_reads'] = '''
pname 0:1:5 A
name 0:1:9 zeros
int 0:1:15 2
int 0:1:18 3
call 0:1:9 2
var 0:1:1 0
name 0:2:1 A
int 0:2:3 0
int 0:2:6 2
index 0:2:1 2
float 0:2:11 #4014000000000000
asg 0:2:1 set
name 0:3:1 A
int 0:3:3 1
int 0:3:6 2
index 0:3:1 2
float 0:3:11 #4018000000000000
asg 0:3:1 set
pname 0:4:5 c
name 0:4:9 A
all 0:4:11
int 0:4:14 2
index 0:4:9 2
let 0:4:1 0
pname 0:5:5 w
name 0:5:9 filled
int 0:5:16 1
int 0:5:19 2
call 0:5:9 2
let 0:5:1 0
pname 0:6:5 r
name 0:6:9 c
name 0:6:11 w
index 0:6:9 1
let 0:6:1 0
pname 0:7:5 M
name 0:7:9 A
float 0:7:13 #4016000000000000
bin 0:7:9 gt
let 0:7:1 0
pname 0:8:5 s
name 0:8:9 A
name 0:8:11 M
index 0:8:9 1
let 0:8:1 0
name 0:9:1 printf
str 0:9:8 %25g%20%25g%20%25g%20%25d%20%25g%0A
name 0:9:28 c
int 0:9:30 0
index 0:9:28 1
name 0:9:34 c
int 0:9:36 1
index 0:9:34 1
name 0:9:40 r
int 0:9:42 0
index 0:9:40 1
name 0:9:46 len
name 0:9:50 r
call 0:9:46 1
name 0:9:54 s
int 0:9:56 0
index 0:9:54 1
call 0:9:1 6
cstmt 0:9:1
prog 9
'''
# sea.hir1: f64[,] 10, f64[] 11, i64[] 12, bool[,] 13 (first referred to by the loc records of
# A, c, w and M). A[:, 2] keeps one dimension (a vector, 3.5.5); c[w] and A[M] are vectors (a
# mask of a matrix selects a vector); A > 5.5 is an element-wise comparison of type bool[,];
# filled(1, 2) is an i64[] (an untyped integer value is i64, LANGUAGE.md 10.2).
HIR1['sel_reads'] = '''
tmat 10 4
tvec 11 4
tvec 12 3
tmat 13 2
fn 1 .main main 1 0 6 0:1:1
loc A 10 var 0:1:5
loc c 11 let 0:4:5
loc w 12 let 0:5:5
loc r 11 let 0:6:5
loc M 13 let 0:7:5
loc s 11 let 0:8:5
ci 0:1:15 3 2
ci 0:1:18 3 3
lib 0:1:9 10 zeros 2
bind 0:1:1 1
lv 0:2:1 10 1
ci 0:2:3 3 0
ci 0:2:6 3 2
idx 0:2:1 4 2
cf 0:2:11 4 #4014000000000000
asg 0:2:1 set
lv 0:3:1 10 1
ci 0:3:3 3 1
ci 0:3:6 3 2
idx 0:3:1 4 2
cf 0:3:11 4 #4018000000000000
asg 0:3:1 set
lv 0:4:9 10 1
all 0:4:11 1
ci 0:4:14 3 2
idx 0:4:9 11 2
bind 0:4:1 2
ci 0:5:16 3 1
ci 0:5:19 3 2
lib 0:5:9 12 filled 2
bind 0:5:1 3
lv 0:6:9 11 2
lv 0:6:11 12 3
idx 0:6:9 11 1
bind 0:6:1 4
lv 0:7:9 10 1
cf 0:7:13 4 #4016000000000000
bin 0:7:9 13 gt
bind 0:7:1 5
lv 0:8:9 10 1
lv 0:8:11 13 5
idx 0:8:9 11 1
bind 0:8:1 6
lv 0:9:28 11 2
ci 0:9:30 3 0
idx 0:9:28 4 1
fconv 0:9:8 1 - - - g
ftext 0:9:8 1 %20
lv 0:9:34 11 2
ci 0:9:36 3 1
idx 0:9:34 4 1
fconv 0:9:8 1 - - - g
ftext 0:9:8 1 %20
lv 0:9:40 11 4
ci 0:9:42 3 0
idx 0:9:40 4 1
fconv 0:9:8 1 - - - g
ftext 0:9:8 1 %20
lv 0:9:50 11 4
lib 0:9:46 3 len 1
fconv 0:9:8 1 - - - d
ftext 0:9:8 1 %20
lv 0:9:54 11 6
ci 0:9:56 3 0
idx 0:9:54 4 1
fconv 0:9:8 1 - - - g
ftext 0:9:8 1 %0A
fmt 0:9:8 1 10
lib 0:9:1 1 printf 1
eval 0:9:1
block 0:1:1 9
end
'''


def hirl_sel_reads():
    """sea.hirl: tptr 14 4 (the adat of the result of line 4), 15 3 (filled of line 5), 16 2 (the
    result of line 7). zeros is L1, filled L2, len L3; lines 4, 6 and 8 are L5, line 7 L7."""
    F = Fn()
    eds = [(['ci 0:1:15 3 2', 'ci 0:1:18 3 3', 'lib 0:1:9 10 zeros 2'],
            cat(L1('0:1:9', 10, [ci('0:1:15', 2), ci('0:1:18', 3)])))]
    # ---- line 4: A[:, 2], P the idx's position. Kinds: dimension 0 A, dimension 1 S.
    P = '0:4:9'
    x = Ctx(F, P, 'c')
    st = [x.tmp('B', lv('0:4:9', 10, 1)),
          x.tmp('I', ci('0:4:14', 2)),                          # IX 1: S tmp I; A nothing
          x.tmp('X0', ext(P, 0, x.lvl('B'))),                   # IX 2, d 0: tmp X0 (A: no more)
          x.tmp('X1', ext(P, 1, x.lvl('B'))),                   # d 1: tmp X1, chkb 1 I X1
          chkb(P, 1, x.lvl('I'), x.lvl('X1'))]
    # IX 3: A's kept extent X0; the vector result; data; O; One
    st += [x.tmp('R', anew(P, 11, 0, [x.lvl('X0')])),
           x.tmp('DR', adat(P, 14, x.lvl('R'))),
           x.tmp('DB', adat(P, 14, x.lvl('B'))),
           x.bindl('O', ci(P, 0)),
           x.tmp('One', ci(P, 1))]
    # IX 4: dimension 1 (S) no loop, its position I; dimension 0 (A) loop(X0; Q); pos = lin(Q, I,
    # X0) (a matrix base, X0 the rows extent of IX 2)
    st += x.loop('X0', 'Z', 'Oq', 'Lq', 'Q', lambda: [
        est(P, 4, eld(P, 4, x.lvl('DB'), x.lin(x.klv('Q'), x.lvl('I'), x.lvl('X0'))),
            x.lvl('DR'), x.lvl('O')),
        x.plus_eq('O', x.lvl('One'))])
    eds.append(('''
lv 0:4:9 10 1
all 0:4:11 1
ci 0:4:14 3 2
idx 0:4:9 11 2
''', cat(xblk(P, st, x.lvl('R')))))
    # ---- line 5: filled(1, 2), an i64[] (L2)
    eds.append((['ci 0:5:16 3 1', 'ci 0:5:19 3 2', 'lib 0:5:9 12 filled 2'],
                cat(L2(F, '0:5:9', 12, 3, 15, 'w', r=ci('0:5:19', 2), v=ci('0:5:16', 1)))))
    # ---- line 6: c[w], an index vector V of a vector base
    P = '0:6:9'
    x = Ctx(F, P, 'r')
    st = [x.tmp('B', lv('0:6:9', 11, 2)),
          x.tmp('W', lv('0:6:11', 12, 3)),                      # IX 1: V tmp W
          x.tmp('X', ext(P, 0, x.lvl('B'))),                    # IX 2: the extent first, then
          x.tmp('NW', ext(P, 0, x.lvl('W'))),                   # the length and data of W and
          x.tmp('DW', adat(P, 15, x.lvl('W')))]                 # the loop of checks
    st += x.loop('NW', 'Zc', 'Oc', 'Lc', 'Kc', lambda: [
        chkb(P, 0, eld(P, 3, x.lvl('DW'), x.klv('Kc')), x.lvl('X'))])
    # IX 3: V's NW; the result; DR, DB, the nest's DW (loaded again); O; One
    st += [x.tmp('R', anew(P, 11, 0, [x.lvl('NW')])),
           x.tmp('DR', adat(P, 14, x.lvl('R'))),
           x.tmp('DB', adat(P, 14, x.lvl('B'))),
           x.tmp('DW2', adat(P, 15, x.lvl('W'))),
           x.bindl('O', ci(P, 0)),
           x.tmp('One', ci(P, 1))]
    # IX 4: V loop(NW; K) { tmp Q = eld i64 8 0 (lv DW2) (lv K); est (eld DB Q) DR O; O += One }
    st += x.loop('NW', 'Zn', 'On', 'Ln', 'Kn', lambda: [
        x.tmp('Q', eld(P, 3, x.lvl('DW2'), x.klv('Kn'))),
        est(P, 4, eld(P, 4, x.lvl('DB'), x.lvl('Q')), x.lvl('DR'), x.lvl('O')),
        x.plus_eq('O', x.lvl('One'))])
    eds.append((['lv 0:6:9 11 2', 'lv 0:6:11 12 3', 'idx 0:6:9 11 1'],
                cat(xblk(P, st, x.lvl('R')))))
    # ---- line 7: A > 5.5, L7 of a matrix and a scalar (a dynamic bool[,] result)
    P = '0:7:9'
    x = Ctx(F, P, 'm')
    st = [x.tmp('A1', lv('0:7:9', 10, 1)),                      # (1) the operands
          x.tmp('A2', cf('0:7:13', '#4016000000000000')),
          x.tmp('R1', ext(P, 0, x.lvl('A1'))),                  # (2) the extents (one array
          x.tmp('C1', ext(P, 1, x.lvl('A1'))),                  # operand: no check)
          x.tmp('RES', anew(P, 13, 0, [x.lvl('R1'), x.lvl('C1')])),       # (3)
          x.tmp('O', ci(P, 1)),                                 # (4) O at its first use, the
          x.tmp('SI', bin_(P, 2, 'ne', x.lvl('R1'), x.lvl('O'))),          # strides of A1
          x.tmp('t', bin_(P, 2, 'ne', x.lvl('C1'), x.lvl('O'))),
          x.tmp('SJ', wbin(P, 'mul', x.lvl('t'), x.lvl('R1'))),
          x.tmp('DR', adat(P, 16, x.lvl('RES'))),               # (5)
          x.tmp('D1', adat(P, 14, x.lvl('A1')))]

    def body7():
        idx1 = wbin(P, 'add', wbin(P, 'mul', x.klv('I'), x.lvl('SI')),
                    wbin(P, 'mul', x.klv('J'), x.lvl('SJ')))
        F7 = bin_('0:7:9', 2, 'gt', eld(P, 4, x.lvl('D1'), idx1), x.lvl('A2'))
        return [est(P, 2, F7, x.lvl('DR'), x.lin(x.klv('I'), x.klv('J'), x.lvl('R1')))]
    # (6) mloop(R1, C1; I, J) = loop(C1; J) { loop(R1; I) { est 1 0 F DR lin(I, J, R1) } }
    st += x.loop('C1', 'Zj', 'Oj', 'Lj', 'J', lambda: x.loop('R1', 'Zi', 'Oi', 'Li', 'I', body7))
    eds.append((['lv 0:7:9 10 1', 'cf 0:7:13 4 #4016000000000000', 'bin 0:7:9 13 gt'],
                cat(xblk(P, st, x.lvl('RES')))))
    # ---- line 8: A[M], a whole-matrix mask MM
    P = '0:8:9'
    x = Ctx(F, P, 's')
    st = [x.tmp('B', lv('0:8:9', 10, 1)),
          x.tmp('M', lv('0:8:11', 13, 5)),                      # IX 1: tmp M
          x.tmp('X0', ext(P, 0, x.lvl('B'))),                   # IX 2, MM: both extents, the
          x.tmp('X1', ext(P, 1, x.lvl('B'))),                   # mask's, the comparisons, mchk,
          x.tmp('RM', ext(P, 0, x.lvl('M'))),                   # then NN
          x.tmp('CM', ext(P, 1, x.lvl('M'))),
          x.tmp('S0', bin_(P, 2, 'ne', x.lvl('X0'), x.lvl('RM'))),
          x.tmp('S1', bin_(P, 2, 'ne', x.lvl('X1'), x.lvl('CM'))),
          x.tmp('S', bin_(P, 2, 'bor', x.lvl('S0'), x.lvl('S1'))),
          x.mchk('SHAPE_MISMATCH', 'S', 'X0', 'X1', 'RM', 'CM'),
          x.tmp('NN', wbin(P, 'mul', x.lvl('X0'), x.lvl('X1')))]
    # IX 3, MM: bind N = ci 0, tmp DM = data(M), loop(NN; K) { N += eld bool 1 0 (lv DM) (lv K) }
    st += [x.bindl('N', ci(P, 0)),
           x.tmp('DM', adat(P, 16, x.lvl('M')))]
    st += x.loop('NN', 'Zc', 'Oc', 'Lc', 'Kc', lambda: [
        x.plus_eq('N', eld(P, 2, x.lvl('DM'), x.klv('Kc')))])
    st += [x.tmp('R', anew(P, 11, 0, [x.lvl('N')])),
           x.tmp('DR', adat(P, 14, x.lvl('R'))),
           x.tmp('DB', adat(P, 14, x.lvl('B'))),
           x.tmp('DM2', adat(P, 16, x.lvl('M'))),
           x.bindl('O', ci(P, 0)),
           x.tmp('One', ci(P, 1))]
    # IX 4, MM: one loop(NN; Q) over the linear positions with M's if; pos = Q
    st += x.loop('NN', 'Zn', 'On', 'Ln', 'Q', lambda: [
        if_(P, eld(P, 2, x.lvl('DM2'), x.klv('Q')), block(P, [
            est(P, 4, eld(P, 4, x.lvl('DB'), x.klv('Q')), x.lvl('DR'), x.lvl('O')),
            x.plus_eq('O', x.lvl('One'))]))])
    eds.append((['lv 0:8:9 10 1', 'lv 0:8:11 13 5', 'idx 0:8:9 11 1'],
                cat(xblk(P, st, x.lvl('R')))))
    # ---- line 9: len(r) is L3
    eds.append((['lv 0:9:50 11 4', 'lib 0:9:46 3 len 1'],
                cat(L3('0:9:46', 0, lv('0:9:50', 11, 4)))))
    return make_hirl(HIR1['sel_reads'], ['tptr 14 4', 'tptr 15 3', 'tptr 16 2'], {1: (F, eds)})


HIRL['sel_reads'] = hirl_sel_reads
# sea.lir1 (.main). Lines 2-3: rule 19 on a matrix. Line 4: L5 lowered (rule 20): li of the scalar
# index, the two extents, chkb of dimension 1, the result (one kept dimension: arrnew of the rows
# extent), data, O and One, the loop over the rows with the base element at lin(Q, I, X0) (imul,
# iadd right before the load). Line 5: filled (rule 17). Line 6: the index vector (the extent,
# its length and data, the check loop, the result of its length, data loaded again, the copy loop
# reading each index first). Line 7: rule 22 of a matrix and a scalar (no check; O at its first
# use; the strides SI, SJ; the nest loop(C; J) around loop(R; I), the operand's index before its
# load, the result's after the comparison). Line 8: the whole-matrix mask (rule 20 (2): both
# shapes compared, ior, chk; the count of true elements; the copy loop with the mask's if). Line
# 9: four element reads, len (ldi), the printf slot of 5 words; then the six locals released in
# reverse order of declaration (rule 16 (a)).
LIR1['sel_reads'] = '''
func .main main 0:1:1 0 0
slot s1 40 8
li i.r1 2
li i.c1 3
li i.ek1 1
li i.rk1 2
rcall sea_arr_new 0:1 1 p.A 4 i.ek1 i.rk1 i.r1 i.c1
lf f.v2 #4014000000000000
li i.i2 0
li i.j2 2
ldi i.e02 p.A - 0 16
chkb i.i2 i.e02 0 0:2
ldi i.e12 p.A - 0 24
chkb i.j2 i.e12 1 0:2
ldi i.rc2 p.A - 0 0
li i.o2 1
icmp ne i.sh2 i.rc2 i.o2
if 1 i.sh2
rcall sea_arr_unique 0:2 1 p.u2 1 p.A
mov p.A p.u2
endif 1
ldp p.d2 p.A - 0 40
imul i.t2 i.j2 i.e02
iadd i.x2 i.i2 i.t2
stf f.v2 p.d2 i.x2 8 0
lf f.v3 #4018000000000000
li i.i3 1
li i.j3 2
ldi i.e03 p.A - 0 16
chkb i.i3 i.e03 0 0:3
ldi i.e13 p.A - 0 24
chkb i.j3 i.e13 1 0:3
ldi i.rc3 p.A - 0 0
li i.o3 1
icmp ne i.sh3 i.rc3 i.o3
if 2 i.sh3
rcall sea_arr_unique 0:3 1 p.u3 1 p.A
mov p.A p.u3
endif 2
ldp p.d3 p.A - 0 40
imul i.t3 i.j3 i.e03
iadd i.x3 i.i3 i.t3
stf f.v3 p.d3 i.x3 8 0
li i.I4 2
ldi i.X04 p.A - 0 16
ldi i.X14 p.A - 0 24
chkb i.I4 i.X14 1 0:4
li i.ek4 1
li i.rk4 1
li i.cc4 1
rcall sea_arr_new_u 0:4 1 p.c 4 i.ek4 i.rk4 i.X04 i.cc4
ldp p.DR4 p.c - 0 40
ldp p.DB4 p.A - 0 40
li i.O4 0
li i.One4 1
li i.Z4 0
icmp gt i.g4 i.X04 i.Z4
if 3 i.g4
li i.o4 1
isub i.l4 i.X04 i.o4
loop 4 i.Q4 i.Z4 i.l4 i.o4
imul i.t4 i.I4 i.X04
iadd i.p4 i.Q4 i.t4
ldf f.e4 p.DB4 i.p4 8 0
stf f.e4 p.DR4 i.O4 8 0
iadd i.O4 i.O4 i.One4
endloop 4
endif 3
li i.V5 1
li i.R5 2
li i.ek5 2
li i.rk5 1
li i.cc5 1
rcall sea_arr_new_u 0:5 1 p.w 4 i.ek5 i.rk5 i.R5 i.cc5
ldp p.D5 p.w - 0 40
li i.Z5 0
icmp gt i.g5 i.R5 i.Z5
if 5 i.g5
li i.o5 1
isub i.l5 i.R5 i.o5
loop 6 i.K5 i.Z5 i.l5 i.o5
sti i.V5 p.D5 i.K5 8 0
endloop 6
endif 5
ldi i.X6 p.c - 0 16
ldi i.NW6 p.w - 0 16
ldp p.DW6 p.w - 0 40
li i.Z6 0
icmp gt i.g6 i.NW6 i.Z6
if 7 i.g6
li i.o6 1
isub i.l6 i.NW6 i.o6
loop 8 i.K6 i.Z6 i.l6 i.o6
ldi i.w6 p.DW6 i.K6 8 0
chkb i.w6 i.X6 0 0:6
endloop 8
endif 7
li i.ek6 1
li i.rk6 1
li i.cc6 1
rcall sea_arr_new_u 0:6 1 p.r 4 i.ek6 i.rk6 i.NW6 i.cc6
ldp p.DR6 p.r - 0 40
ldp p.DB6 p.c - 0 40
ldp p.DW6b p.w - 0 40
li i.O6 0
li i.One6 1
li i.Z6b 0
icmp gt i.g6b i.NW6 i.Z6b
if 9 i.g6b
li i.o6b 1
isub i.l6b i.NW6 i.o6b
loop 10 i.K6b i.Z6b i.l6b i.o6b
ldi i.Q6 p.DW6b i.K6b 8 0
ldf f.e6 p.DB6 i.Q6 8 0
stf f.e6 p.DR6 i.O6 8 0
iadd i.O6 i.O6 i.One6
endloop 10
endif 9
lf f.c7 #4016000000000000
ldi i.R7 p.A - 0 16
ldi i.C7 p.A - 0 24
li i.ek7 3
li i.rk7 2
rcall sea_arr_new_u 0:7 1 p.M 4 i.ek7 i.rk7 i.R7 i.C7
li i.O7 1
icmp ne i.SI7 i.R7 i.O7
icmp ne i.t7 i.C7 i.O7
imul i.SJ7 i.t7 i.R7
ldp p.DR7 p.M - 0 40
ldp p.D17 p.A - 0 40
li i.Zj7 0
icmp gt i.gj7 i.C7 i.Zj7
if 11 i.gj7
li i.oj7 1
isub i.lj7 i.C7 i.oj7
loop 12 i.J7 i.Zj7 i.lj7 i.oj7
li i.Zi7 0
icmp gt i.gi7 i.R7 i.Zi7
if 13 i.gi7
li i.oi7 1
isub i.li7 i.R7 i.oi7
loop 14 i.I7 i.Zi7 i.li7 i.oi7
imul i.a7 i.I7 i.SI7
imul i.b7 i.J7 i.SJ7
iadd i.x7 i.a7 i.b7
ldf f.e7 p.D17 i.x7 8 0
fcmp gt i.q7 f.e7 f.c7
imul i.tt7 i.J7 i.R7
iadd i.y7 i.I7 i.tt7
stb i.q7 p.DR7 i.y7 1 0
endloop 14
endif 13
endloop 12
endif 11
ldi i.X08 p.A - 0 16
ldi i.X18 p.A - 0 24
ldi i.RM8 p.M - 0 16
ldi i.CM8 p.M - 0 24
icmp ne i.S08 i.X08 i.RM8
icmp ne i.S18 i.X18 i.CM8
ior i.S8 i.S08 i.S18
chk i.S8 SHAPE_MISMATCH 0:8 4 i.X08 i.X18 i.RM8 i.CM8
imul i.NN8 i.X08 i.X18
li i.N8 0
ldp p.DM8 p.M - 0 40
li i.Z8 0
icmp gt i.g8 i.NN8 i.Z8
if 15 i.g8
li i.o8 1
isub i.l8 i.NN8 i.o8
loop 16 i.K8 i.Z8 i.l8 i.o8
ldb i.b8 p.DM8 i.K8 1 0
iadd i.N8 i.N8 i.b8
endloop 16
endif 15
li i.ek8 1
li i.rk8 1
li i.cc8 1
rcall sea_arr_new_u 0:8 1 p.s 4 i.ek8 i.rk8 i.N8 i.cc8
ldp p.DR8 p.s - 0 40
ldp p.DB8 p.A - 0 40
ldp p.DM8b p.M - 0 40
li i.O8 0
li i.One8 1
li i.Z8b 0
icmp gt i.g8b i.NN8 i.Z8b
if 17 i.g8b
li i.o8b 1
isub i.l8b i.NN8 i.o8b
loop 18 i.Q8 i.Z8b i.l8b i.o8b
ldb i.m8 p.DM8b i.Q8 1 0
if 19 i.m8
ldf f.e8 p.DB8 i.Q8 8 0
stf f.e8 p.DR8 i.O8 8 0
iadd i.O8 i.O8 i.One8
endif 19
endloop 18
endif 17
li i.k90 0
ldi i.e90 p.c - 0 16
chkb i.k90 i.e90 0 0:9
ldp p.d90 p.c - 0 40
ldf f.x90 p.d90 i.k90 8 0
li i.k91 1
ldi i.e91 p.c - 0 16
chkb i.k91 i.e91 0 0:9
ldp p.d91 p.c - 0 40
ldf f.x91 p.d91 i.k91 8 0
li i.k92 0
ldi i.e92 p.r - 0 16
chkb i.k92 i.e92 0 0:9
ldp p.d92 p.r - 0 40
ldf f.x92 p.d92 i.k92 8 0
ldi i.len9 p.r - 0 16
li i.k94 0
ldi i.e94 p.s - 0 16
chkb i.k94 i.e94 0 0:9
ldp p.d94 p.s - 0 40
ldf f.x94 p.d94 i.k94 8 0
sa p.s9 s1
stf f.x90 p.s9 - 0 0
stf f.x91 p.s9 - 0 8
stf f.x92 p.s9 - 0 16
sti i.len9 p.s9 - 0 24
stf f.x94 p.s9 - 0 32
la p.f9 d1
rcall sea_printf 0:9 0 2 p.f9 p.s9
release p.s
release p.M
release p.r
release p.w
release p.c
release p.A
ret 0
endfunc
fmt d1 10
fconv - - - g f
ftext %20
fconv - - - g f
ftext %20
fconv - - - g f
ftext %20
fconv - - - d i
ftext %20
fconv - - - g f
ftext %0A
'''
# A = [0 0 5; 0 0 6]; c = A[:, 2] = [5, 6]; w = [1, 1]; r = c[w] = [6, 6]; M = A > 5.5 is true at
# (1, 2) only (linear position 5); s = A[M] = [6]. Printed: 5 6 6 2 6.
OUT['sel_reads'] = '5 6 6 2 6\n'
NAMES.append('sel_reads')

# ================================================================ sel_ref_store (rule 21 / L6, a ref target)
SEA['sel_ref_store'] = '''fn setto(ref v: f64[], k: i64) {
    for i in 0..k {
        v[i..3] = 7.0
    }
}
var a = zeros(4)
setto(ref a, 2)
setto(ref a, 0)
printf("%g %g %g %g\\n", a[0], a[1], a[2], a[3])
// sel_ref_store -- DESIGN.md 3.5.9 L6 (rule 21): a selection store of a scalar into a ref
// parameter, whose array is loaded afresh for its extent, its copy on write (the memory form of
// rule 19) and its data; a range index whose lo is the loop variable
'''
AST['sel_ref_store'] = '''
type 0:1:17 f64 v 0
param 0:1:10 v 1 0
type 0:1:27 i64 s 0
param 0:1:24 k 0 0
int 0:2:14 0
name 0:2:17 k
range 0:2:14 0 0
name 0:3:9 v
name 0:3:11 i
int 0:3:14 3
range 0:3:11 0 0
index 0:3:9 1
float 0:3:19 #401C000000000000
asg 0:3:9 set
block 0:2:19 1
for 0:2:5 i 0:2:9
block 0:1:32 1
fn 0:1:1 setto 0 2 0
pname 0:6:5 a
name 0:6:9 zeros
int 0:6:15 4
call 0:6:9 1
var 0:6:1 0
name 0:7:1 setto
name 0:7:11 a
ref 0:7:7
int 0:7:14 2
call 0:7:1 2
cstmt 0:7:1
name 0:8:1 setto
name 0:8:11 a
ref 0:8:7
int 0:8:14 0
call 0:8:1 2
cstmt 0:8:1
name 0:9:1 printf
str 0:9:8 %25g%20%25g%20%25g%20%25g%0A
name 0:9:25 a
int 0:9:27 0
index 0:9:25 1
name 0:9:31 a
int 0:9:33 1
index 0:9:31 1
name 0:9:37 a
int 0:9:39 2
index 0:9:37 1
name 0:9:43 a
int 0:9:45 3
index 0:9:43 1
call 0:9:1 5
cstmt 0:9:1
prog 5
'''
# sea.hir1: f64[] 10 (`loc a`), i64[] 11 (the rng of the for in setto; the range index has the same
# type, 3.5.1). setto is function 2 (`par v 10 ref`); `setto(ref a, 2)` passes `rarg` of a.
HIR1['sel_ref_store'] = '''
tvec 10 4
tvec 11 3
fn 1 .main main 1 0 1 0:1:1
loc a 10 var 0:6:5
ci 0:6:15 3 4
lib 0:6:9 10 zeros 1
bind 0:6:1 1
lv 0:7:11 10 1
rarg 0:7:7 10
ci 0:7:14 3 2
call 0:7:1 1 2 2
eval 0:7:1
lv 0:8:11 10 1
rarg 0:8:7 10
ci 0:8:14 3 0
call 0:8:1 1 2 2
eval 0:8:1
lv 0:9:25 10 1
ci 0:9:27 3 0
idx 0:9:25 4 1
fconv 0:9:8 1 - - - g
ftext 0:9:8 1 %20
lv 0:9:31 10 1
ci 0:9:33 3 1
idx 0:9:31 4 1
fconv 0:9:8 1 - - - g
ftext 0:9:8 1 %20
lv 0:9:37 10 1
ci 0:9:39 3 2
idx 0:9:37 4 1
fconv 0:9:8 1 - - - g
ftext 0:9:8 1 %20
lv 0:9:43 10 1
ci 0:9:45 3 3
idx 0:9:43 4 1
fconv 0:9:8 1 - - - g
ftext 0:9:8 1 %0A
fmt 0:9:8 1 8
lib 0:9:1 1 printf 1
eval 0:9:1
block 0:1:1 4
end
fn 2 setto fn 1 2 1 0:1:1
par v 10 ref
par k 3 val
loc i 3 for 0:2:9
ci 0:2:14 3 0
lv 0:2:17 3 2
rng 0:2:14 11 0 0
lv 0:3:9 10 1
lv 0:3:11 3 3
ci 0:3:14 3 3
rng 0:3:11 11 0 0
idx 0:3:9 10 1
cf 0:3:19 4 #401C000000000000
asg 0:3:9 set
block 0:2:19 1
forr 0:2:5 3
block 0:1:32 1
end
'''


def hirl_sel_ref_store():
    """sea.hirl: tptr 12 4 (the adat of the target in setto). .main: zeros(4) is L1. setto: the
    store is L6 with the target's root v a ref parameter: every `lv v` of IX 2, the cow and the
    data is a read of its own (3.5.9 IX: "read afresh at each use")."""
    F1, F2 = Fn(), Fn()
    m_zeros = (['ci 0:6:15 3 4', 'lib 0:6:9 10 zeros 1'], cat(L1('0:6:9', 10, [ci('0:6:15', 4)])))
    P = '0:3:9'
    x = Ctx(F2, P, 's')
    T = lambda: lv(P, 10, 1)
    st = [x.tmp('Vv', cf('0:3:19', '#401C000000000000')),        # 1. the scalar value
          x.tmp('LO', lv('0:3:11', 3, 3)),                        # 2. IX 1 (R): lo, hi, st,
          x.tmp('HI', ci('0:3:14', 3)),                           # rcnt at the rng's position
          x.tmp('ST', ci(P, 1)),
          x.rcnt(0, 'L', 'E', 'LO', 'HI', 'ST', '0:3:11'),
          x.tmp('X', ext(P, 0, T())),                             # 3. IX 2 (R)
          if_(P, x.lvl('E'), block(P, [
              chkb(P, 0, x.lvl('LO'), x.lvl('X')),
              chkb(P, 0, wbin(P, 'add', x.lvl('LO'), wbin(P, 'mul', x.lvl('L'), x.lvl('ST'))),
                   x.lvl('X'))])),
          cow(P, T()),                                            # 5. (a scalar value: no 4.)
          x.tmp('DT', adat(P, 12, T()))]                          # 6.
    # 7. IX 4 (R): rloop(E, LO, L, ST; Q) { est 8 0 (lv Vv) (lv DT) (lv Q) }
    st.append(x.rloop('E', 'LO', 'L', 'ST', 'Q', lambda: [
        est(P, 4, x.lvl('Vv'), x.lvl('DT'), x.klv('Q'))]))
    s_store = ('''
lv 0:3:9 10 1
lv 0:3:11 3 3
ci 0:3:14 3 3
rng 0:3:11 11 0 0
idx 0:3:9 10 1
cf 0:3:19 4 #401C000000000000
asg 0:3:9 set
''', cat(block(P, st)))
    return make_hirl(HIR1['sel_ref_store'], ['tptr 12 4'], {1: (F1, [m_zeros]), 2: (F2, [s_store])})


HIRL['sel_ref_store'] = hirl_sel_ref_store
# sea.lir1. .main: zeros(4) (arrnewz); each `setto(ref a, k)` is rule 31 for a local of a
# reference type: a new 8-byte slot, `stp a`, the call, `ldp a` (the reload); the printf of four
# element reads (a slot of 32 bytes); a released at the end. setto: the forr (rule 4) around the
# L6 block: the value `lf` first, the range's hi and st, rcount (lo is the loop variable's
# register: T1's alias), then the ref parameter loaded for the extent (`ldp`, `ldi`), the checks
# of the first and last position, loaded again for its copy on write (the memory form of rule 19:
# `stp` of the unique copy back into the caller's variable, then `mov`), loaded again for its
# data, and the range loop of stores.
LIR1['sel_ref_store'] = '''
func .main main 0:1:1 0 0
slot s1 8 8
slot s2 8 8
slot s3 32 8
li i.n 4
li i.ek 1
li i.rk 1
li i.c 1
rcall sea_arr_new 0:6 1 p.a 4 i.ek i.rk i.n i.c
sa p.s1 s1
stp p.a p.s1 - 0 0
li i.k1 2
call setto 0 2 p.s1 i.k1
ldp p.a p.s1 - 0 0
sa p.s2 s2
stp p.a p.s2 - 0 0
li i.k2 0
call setto 0 2 p.s2 i.k2
ldp p.a p.s2 - 0 0
li i.x0 0
ldi i.e0 p.a - 0 16
chkb i.x0 i.e0 0 0:9
ldp p.d0 p.a - 0 40
ldf f.r0 p.d0 i.x0 8 0
li i.x1 1
ldi i.e1 p.a - 0 16
chkb i.x1 i.e1 0 0:9
ldp p.d1 p.a - 0 40
ldf f.r1 p.d1 i.x1 8 0
li i.x2 2
ldi i.e2 p.a - 0 16
chkb i.x2 i.e2 0 0:9
ldp p.d2 p.a - 0 40
ldf f.r2 p.d2 i.x2 8 0
li i.x3 3
ldi i.e3 p.a - 0 16
chkb i.x3 i.e3 0 0:9
ldp p.d3 p.a - 0 40
ldf f.r3 p.d3 i.x3 8 0
sa p.s3 s3
stf f.r0 p.s3 - 0 0
stf f.r1 p.s3 - 0 8
stf f.r2 p.s3 - 0 16
stf f.r3 p.s3 - 0 24
la p.f d1
rcall sea_printf 0:9 0 2 p.f p.s3
release p.a
ret 0
endfunc
func setto fn 0:1:1 2 p.v i.k 0
li i.lo 0
li i.st 1
rcount i.C i.En i.lo i.k i.st 0 0:2
if 1 i.En
loop 2 i.i i.lo i.C i.st
lf f.Vv #401C000000000000
li i.HI 3
li i.ST 1
rcount i.L i.E i.i i.HI i.ST 0 0:3
ldp p.b1 p.v - 0 0
ldi i.X p.b1 - 0 16
if 3 i.E
chkb i.i i.X 0 0:3
imul i.m i.L i.ST
iadd i.last i.i i.m
chkb i.last i.X 0 0:3
endif 3
ldp p.A p.v - 0 0
ldi i.rc p.A - 0 0
li i.o 1
icmp ne i.sh i.rc i.o
if 4 i.sh
rcall sea_arr_unique 0:3 1 p.u 1 p.A
stp p.u p.v - 0 0
mov p.A p.u
endif 4
ldp p.b2 p.v - 0 0
ldp p.DT p.b2 - 0 40
if 5 i.E
loop 6 i.Q i.i i.L i.ST
stf f.Vv p.DT i.Q 8 0
endloop 6
endif 5
endloop 2
endif 1
ret 0
endfunc
fmt d1 8
fconv - - - g f
ftext %20
fconv - - - g f
ftext %20
fconv - - - g f
ftext %20
fconv - - - g f
ftext %0A
'''
# setto(ref a, 2): i = 0 stores 7 at 0, 1, 2; i = 1 at 1, 2; setto(ref a, 0) runs no iteration.
OUT['sel_ref_store'] = '7 7 7 0\n'
NAMES.append('sel_ref_store')

# ================================================================ sel_compound (rule 21 compound / L6)
SEA['sel_compound'] = '''var v = ones(4)
v[1..3] += 2.0
printf("%g %g %g %g\\n", v[0], v[1], v[2], v[3])
// sel_compound -- DESIGN.md 3.5.9 L6, compound form (rule 21): the indices, the selection read
// into a temporary G (L5), the operation (L7), then the checks, the shape check, the copy on
// write and the store of G's elements; G is released at the end of the block
'''
AST['sel_compound'] = '''
pname 0:1:5 v
name 0:1:9 ones
int 0:1:14 4
call 0:1:9 1
var 0:1:1 0
name 0:2:1 v
int 0:2:3 1
int 0:2:6 3
range 0:2:3 0 0
index 0:2:1 1
float 0:2:12 #4000000000000000
asg 0:2:1 add
name 0:3:1 printf
str 0:3:8 %25g%20%25g%20%25g%20%25g%0A
name 0:3:25 v
int 0:3:27 0
index 0:3:25 1
name 0:3:31 v
int 0:3:33 1
index 0:3:31 1
name 0:3:37 v
int 0:3:39 2
index 0:3:37 1
name 0:3:43 v
int 0:3:45 3
index 0:3:43 1
call 0:3:1 5
cstmt 0:3:1
prog 3
'''
# sea.hir1: f64[] 10 (`loc v`), i64[] 11 (the range index). The compound assignment keeps its op
# (`asg add`); its target is the selection v[1..3] (type f64[], 3.5.5 "Types of the array nodes").
HIR1['sel_compound'] = '''
tvec 10 4
tvec 11 3
fn 1 .main main 1 0 1 0:1:1
loc v 10 var 0:1:5
ci 0:1:14 3 4
lib 0:1:9 10 ones 1
bind 0:1:1 1
lv 0:2:1 10 1
ci 0:2:3 3 1
ci 0:2:6 3 3
rng 0:2:3 11 0 0
idx 0:2:1 10 1
cf 0:2:12 4 #4000000000000000
asg 0:2:1 add
lv 0:3:25 10 1
ci 0:3:27 3 0
idx 0:3:25 4 1
fconv 0:3:8 1 - - - g
ftext 0:3:8 1 %20
lv 0:3:31 10 1
ci 0:3:33 3 1
idx 0:3:31 4 1
fconv 0:3:8 1 - - - g
ftext 0:3:8 1 %20
lv 0:3:37 10 1
ci 0:3:39 3 2
idx 0:3:37 4 1
fconv 0:3:8 1 - - - g
ftext 0:3:8 1 %20
lv 0:3:43 10 1
ci 0:3:45 3 3
idx 0:3:43 4 1
fconv 0:3:8 1 - - - g
ftext 0:3:8 1 %0A
fmt 0:3:8 1 8
lib 0:3:1 1 printf 1
eval 0:3:1
block 0:1:1 3
end
'''


def hirl_sel_compound():
    """sea.hirl: tptr 12 4 (the adat of ones(4), L2). Line 2 is the compound form of L6: step 2
    (IX 1 of the range); `bind G = xblk` { IX 2-4 of L5 on the target (its base `lv v`, read
    afresh) into `tmp G0`; `tmp Vv = value`; the statements of L7 for `G0 add Vv` (its operands
    named `tmp A1 = lv G0`, `tmp A2 = lv Vv`, L7 (1)) into `tmp R0`; value `lv R0` }; then steps
    3-7 with step 2's tmps: IX 2 again, IX 3 again and the shape check against G, cow, the data
    of v and of G, and the range loop storing G's elements. The operation of the loop body is a
    `bin add` at the asg's position (the compound op has no node of its own)."""
    F = Fn()
    m_ones = (['ci 0:1:14 3 4', 'lib 0:1:9 10 ones 1'],
              cat(L2(F, '0:1:9', 10, 4, 12, 'o', r=ci('0:1:14', 4))))
    P = '0:2:1'
    x = Ctx(F, P, 'c')
    T = lambda: lv(P, 10, 1)

    def ix2(sfx):
        return [x.tmp('X' + sfx, ext(P, 0, T())),
                if_(P, x.lvl('E'), block(P, [
                    chkb(P, 0, x.lvl('LO'), x.lvl('X' + sfx)),
                    chkb(P, 0, wbin(P, 'add', x.lvl('LO'), wbin(P, 'mul', x.lvl('L'),
                                                                x.lvl('ST'))),
                         x.lvl('X' + sfx))]))]

    def ix3(sfx):
        return [x.tmp('O1' + sfx, ci(P, 1)),
                x.tmp('T' + sfx, wbin(P, 'add', x.lvl('L'), x.lvl('O1' + sfx))),
                x.tmp('Z' + sfx, ci(P, 0)),
                x.tmp('N' + sfx, lib(P, 3, 'where', [x.lvl('E'), x.lvl('T' + sfx),
                                                     x.lvl('Z' + sfx)]))]
    # step 2: IX 1 of the range
    st = [x.tmp('LO', ci('0:2:3', 1)),
          x.tmp('HI', ci('0:2:6', 3)),
          x.tmp('ST', ci(P, 1)),
          x.rcnt(0, 'L', 'E', 'LO', 'HI', 'ST', '0:2:3')]
    # G: the selection read (IX 2-4 of L5) into G0, the value, L7 of G0 add Vv into R0
    g = ix2('a') + ix3('a')
    g += [x.tmp('G0', anew(P, 10, 0, [x.lvl('Na')])),
          x.tmp('DR', adat(P, 12, x.lvl('G0'))),
          x.tmp('DB', adat(P, 12, T())),
          x.bindl('O', ci(P, 0)),
          x.tmp('One', ci(P, 1))]
    g.append(x.rloop('E', 'LO', 'L', 'ST', 'Q', lambda: [
        est(P, 4, eld(P, 4, x.lvl('DB'), x.klv('Q')), x.lvl('DR'), x.lvl('O')),
        x.plus_eq('O', x.lvl('One'))]))
    g.append(x.tmp('Vv', cf('0:2:12', '#4000000000000000')))
    # L7 of `bin add (lv G0) (lv Vv)` (one array operand: no shape check, no V)
    g += [x.tmp('A1', x.lvl('G0')),
          x.tmp('A2', x.lvl('Vv')),
          x.tmp('N1', ext(P, 0, x.lvl('A1'))),
          x.tmp('R0', anew(P, 10, 0, [x.lvl('N1')])),
          x.tmp('DR0', adat(P, 12, x.lvl('R0'))),
          x.tmp('D1', adat(P, 12, x.lvl('A1')))]
    g += x.loop('N1', 'Zl', 'Ol', 'Ll', 'I', lambda: [
        est(P, 4, bin_(P, 4, 'add', eld(P, 4, x.lvl('D1'), x.klv('I')), x.lvl('A2')),
            x.lvl('DR0'), x.klv('I'))])
    st.append(x.bindl('G', xblk(P, g, x.lvl('R0'))))
    # steps 3-7, storing G's elements
    st += ix2('b') + ix3('b')
    st += [x.tmp('NV', ext(P, 0, x.lvl('G'))),
           x.tmp('S', bin_(P, 2, 'ne', x.lvl('Nb'), x.lvl('NV')))]
    st += x.vchk('SHAPE_MISMATCH', 'S', 'Nb', 'NV', 'V')
    st += [cow(P, T()),
           x.tmp('DT', adat(P, 12, T())),
           x.tmp('DV', adat(P, 12, x.lvl('G'))),
           x.bindl('O2', ci(P, 0)),
           x.tmp('One2', ci(P, 1))]
    st.append(x.rloop('E', 'LO', 'L', 'ST', 'Q2', lambda: [
        est(P, 4, eld(P, 4, x.lvl('DV'), x.lvl('O2')), x.lvl('DT'), x.klv('Q2')),
        x.plus_eq('O2', x.lvl('One2'))]))
    c_store = ('''
lv 0:2:1 10 1
ci 0:2:3 3 1
ci 0:2:6 3 3
rng 0:2:3 11 0 0
idx 0:2:1 10 1
cf 0:2:12 4 #4000000000000000
asg 0:2:1 add
''', cat(block(P, st)))
    return make_hirl(HIR1['sel_compound'], ['tptr 12 4'], {1: (F, [m_ones, c_store])})


HIRL['sel_compound'] = hirl_sel_compound
# sea.lir1. ones(4) (rule 17 by L2, moved into v). Line 2, rule 21's compound form: the range's
# operands and rcount; the read of the selection (rule 20 (2)-(6): the extent, the checks, the
# count, the temporary G0, its loop); the value; the operation by rule 22 (the extent of G0, the
# result R0, which is G's register by T3, the loop with the fadd); G0 released right after the
# operation (T2); then the checks again, the count again, the shape check of the selection against
# G (`li V -1` between the icmp and the chk), cow(v), the data of v and of G, the loop storing G's
# elements; G released at the end of the block (rule 21 (8)). Then the printf; v released.
LIR1['sel_compound'] = '''
func .main main 0:1:1 0 0
slot s1 32 8
li i.R1 4
li i.ek1 1
li i.rk1 1
li i.c1 1
rcall sea_arr_new_u 0:1 1 p.v 4 i.ek1 i.rk1 i.R1 i.c1
lf f.V1 #3FF0000000000000
ldp p.D1 p.v - 0 40
li i.Z1 0
icmp gt i.g1 i.R1 i.Z1
if 1 i.g1
li i.O1 1
isub i.L1 i.R1 i.O1
loop 2 i.K1 i.Z1 i.L1 i.O1
stf f.V1 p.D1 i.K1 8 0
endloop 2
endif 1
li i.LO 1
li i.HI 3
li i.ST 1
rcount i.L i.E i.LO i.HI i.ST 0 0:2
ldi i.Xa p.v - 0 16
if 3 i.E
chkb i.LO i.Xa 0 0:2
imul i.ma i.L i.ST
iadd i.la i.LO i.ma
chkb i.la i.Xa 0 0:2
endif 3
li i.O1a 1
iadd i.Ta i.L i.O1a
li i.Za 0
isel i.Na i.E i.Ta i.Za
li i.eka 1
li i.rka 1
li i.ca 1
rcall sea_arr_new_u 0:2 1 p.G0 4 i.eka i.rka i.Na i.ca
ldp p.DR p.G0 - 0 40
ldp p.DB p.v - 0 40
li i.O 0
li i.One 1
if 4 i.E
loop 5 i.Q i.LO i.L i.ST
ldf f.el p.DB i.Q 8 0
stf f.el p.DR i.O 8 0
iadd i.O i.O i.One
endloop 5
endif 4
lf f.Vv #4000000000000000
ldi i.N1 p.G0 - 0 16
li i.ekr 1
li i.rkr 1
li i.cr 1
rcall sea_arr_new_u 0:2 1 p.G 4 i.ekr i.rkr i.N1 i.cr
ldp p.DR0 p.G - 0 40
ldp p.DA p.G0 - 0 40
li i.Zl 0
icmp gt i.gl i.N1 i.Zl
if 6 i.gl
li i.Ol 1
isub i.Ll i.N1 i.Ol
loop 7 i.I i.Zl i.Ll i.Ol
ldf f.a p.DA i.I 8 0
fadd f.s f.a f.Vv
stf f.s p.DR0 i.I 8 0
endloop 7
endif 6
release p.G0
ldi i.Xb p.v - 0 16
if 8 i.E
chkb i.LO i.Xb 0 0:2
imul i.mb i.L i.ST
iadd i.lb i.LO i.mb
chkb i.lb i.Xb 0 0:2
endif 8
li i.O1b 1
iadd i.Tb i.L i.O1b
li i.Zb 0
isel i.Nb i.E i.Tb i.Zb
ldi i.NV p.G - 0 16
icmp ne i.S i.Nb i.NV
li i.V -1
chk i.S SHAPE_MISMATCH 0:2 4 i.Nb i.V i.NV i.V
ldi i.rc p.v - 0 0
li i.o 1
icmp ne i.sh i.rc i.o
if 9 i.sh
rcall sea_arr_unique 0:2 1 p.u 1 p.v
mov p.v p.u
endif 9
ldp p.DT p.v - 0 40
ldp p.DV p.G - 0 40
li i.O2 0
li i.One2 1
if 10 i.E
loop 11 i.Q2 i.LO i.L i.ST
ldf f.e2 p.DV i.O2 8 0
stf f.e2 p.DT i.Q2 8 0
iadd i.O2 i.O2 i.One2
endloop 11
endif 10
release p.G
li i.x0 0
ldi i.e0 p.v - 0 16
chkb i.x0 i.e0 0 0:3
ldp p.d0 p.v - 0 40
ldf f.r0 p.d0 i.x0 8 0
li i.x1 1
ldi i.e1 p.v - 0 16
chkb i.x1 i.e1 0 0:3
ldp p.d1 p.v - 0 40
ldf f.r1 p.d1 i.x1 8 0
li i.x2 2
ldi i.e2 p.v - 0 16
chkb i.x2 i.e2 0 0:3
ldp p.d2 p.v - 0 40
ldf f.r2 p.d2 i.x2 8 0
li i.x3 3
ldi i.e3 p.v - 0 16
chkb i.x3 i.e3 0 0:3
ldp p.d3 p.v - 0 40
ldf f.r3 p.d3 i.x3 8 0
sa p.s s1
stf f.r0 p.s - 0 0
stf f.r1 p.s - 0 8
stf f.r2 p.s - 0 16
stf f.r3 p.s - 0 24
la p.f d1
rcall sea_printf 0:3 0 2 p.f p.s
release p.v
ret 0
endfunc
fmt d1 8
fconv - - - g f
ftext %20
fconv - - - g f
ftext %20
fconv - - - g f
ftext %20
fconv - - - g f
ftext %0A
'''
# v = [1, 1, 1, 1]; v[1..3] += 2.0 adds 2 to elements 1 and 2.
OUT['sel_compound'] = '1 3 3 1\n'
NAMES.append('sel_compound')

# ================================================================ ew_colrow (rule 22 / L7 of matrices, L10)
SEA['ew_colrow'] = '''var a = ones(2)
a[1] = 3.0
var b = ones(3)
b[2] = 5.0
let P = a.col * b.row
printf("%g %g %d %d\\n", P[1, 0], P[1, 2], rows(P), cols(P))
// ew_colrow -- DESIGN.md 3.5.9 L7 (rule 22) of two matrices with broadcasting: a.col (2 x 1)
// times b.row (1 x 3) is 2 x 3; both views are operands, not index bases, so each is
// materialized first (L10: anew and mcpy); the shape checks combine the extents (R, C)
'''
AST['ew_colrow'] = '''
pname 0:1:5 a
name 0:1:9 ones
int 0:1:14 2
call 0:1:9 1
var 0:1:1 0
name 0:2:1 a
int 0:2:3 1
index 0:2:1 1
float 0:2:8 #4008000000000000
asg 0:2:1 set
pname 0:3:5 b
name 0:3:9 ones
int 0:3:14 3
call 0:3:9 1
var 0:3:1 0
name 0:4:1 b
int 0:4:3 2
index 0:4:1 1
float 0:4:8 #4014000000000000
asg 0:4:1 set
pname 0:5:5 P
name 0:5:9 a
dot 0:5:9 col
name 0:5:17 b
dot 0:5:17 row
bin 0:5:9 mul
let 0:5:1 0
name 0:6:1 printf
str 0:6:8 %25g%20%25g%20%25d%20%25d%0A
name 0:6:25 P
int 0:6:27 1
int 0:6:30 0
index 0:6:25 2
name 0:6:34 P
int 0:6:36 1
int 0:6:39 2
index 0:6:34 2
name 0:6:43 rows
name 0:6:48 P
call 0:6:43 1
name 0:6:52 cols
name 0:6:57 P
call 0:6:52 1
call 0:6:1 5
cstmt 0:6:1
prog 6
'''
# sea.hir1: f64[] 10 (`loc a`), f64[,] 11 (`loc P`); the views and the product are f64[,] (5.6,
# 6.3: dynamic operands give a dynamic result).
HIR1['ew_colrow'] = '''
tvec 10 4
tmat 11 4
fn 1 .main main 1 0 3 0:1:1
loc a 10 var 0:1:5
loc b 10 var 0:3:5
loc P 11 let 0:5:5
ci 0:1:14 3 2
lib 0:1:9 10 ones 1
bind 0:1:1 1
lv 0:2:1 10 1
ci 0:2:3 3 1
idx 0:2:1 4 1
cf 0:2:8 4 #4008000000000000
asg 0:2:1 set
ci 0:3:14 3 3
lib 0:3:9 10 ones 1
bind 0:3:1 2
lv 0:4:1 10 2
ci 0:4:3 3 2
idx 0:4:1 4 1
cf 0:4:8 4 #4014000000000000
asg 0:4:1 set
lv 0:5:9 10 1
view 0:5:9 11 col
lv 0:5:17 10 2
view 0:5:17 11 row
bin 0:5:9 11 mul
bind 0:5:1 3
lv 0:6:25 11 3
ci 0:6:27 3 1
ci 0:6:30 3 0
idx 0:6:25 4 2
fconv 0:6:8 1 - - - g
ftext 0:6:8 1 %20
lv 0:6:34 11 3
ci 0:6:36 3 1
ci 0:6:39 3 2
idx 0:6:34 4 2
fconv 0:6:8 1 - - - g
ftext 0:6:8 1 %20
lv 0:6:48 11 3
lib 0:6:43 3 rows 1
fconv 0:6:8 1 - - - d
ftext 0:6:8 1 %20
lv 0:6:57 11 3
lib 0:6:52 3 cols 1
fconv 0:6:8 1 - - - d
ftext 0:6:8 1 %0A
fmt 0:6:8 1 8
lib 0:6:1 1 printf 1
eval 0:6:1
block 0:1:1 6
end
'''


def L10_colrow(F, P, T, TP, pre, a, kind):
    """L10 of `.col` / `.row` of a dynamic vector a: `tmp A = a`, `tmp R = ext(A, 0)`, `tmp V =
    anew P T 0 2` (.col: R, ci 1; .row: ci 1, R), `tmp D = data(V)`, `tmp S = data(A)`, `tmp NB =
    wbin mul (lv R) (ci 8)`, `mcpy (lv D) (lv S) (lv NB)`; value `lv V`."""
    x = Ctx(F, P, pre)
    st = [x.tmp('A', a), x.tmp('R', ext(P, 0, x.lvl('A')))]
    ex = [x.lvl('R'), ci(P, 1)] if kind == 'col' else [ci(P, 1), x.lvl('R')]
    st += [x.tmp('V', anew(P, T, 0, ex)),
           x.tmp('D', adat(P, TP, x.lvl('V'))),
           x.tmp('S', adat(P, TP, x.lvl('A'))),
           x.tmp('NB', wbin(P, 'mul', x.lvl('R'), ci(P, ES[4]))),
           mcpy(P, x.lvl('D'), x.lvl('S'), x.lvl('NB'))]
    return xblk(P, st, x.lvl('V'))


def hirl_ew_colrow():
    """sea.hirl: tptr 12 4 (the adat of ones(2), L2). Lines 1 and 3 are L2; line 5 is L7 of two
    matrix operands, each the L10 xblk of its view; line 6's rows and cols are L3."""
    F = Fn()
    eds = [(['ci 0:1:14 3 2', 'lib 0:1:9 10 ones 1'],
            cat(L2(F, '0:1:9', 10, 4, 12, 'a', r=ci('0:1:14', 2)))),
           (['ci 0:3:14 3 3', 'lib 0:3:9 10 ones 1'],
            cat(L2(F, '0:3:9', 10, 4, 12, 'b', r=ci('0:3:14', 3))))]
    P = '0:5:9'
    x = Ctx(F, P, 'm')
    # (1) the operands: the materialized views (L10 at each view's position)
    st = [x.tmp('A1', L10_colrow(F, '0:5:9', 11, 12, 'c', lv('0:5:9', 10, 1), 'col')),
          x.tmp('A2', L10_colrow(F, '0:5:17', 11, 12, 'r', lv('0:5:17', 10, 2), 'row'))]
    # (2) the extents of both operands, then the check of operand 2 against (R1, C1)
    st += [x.tmp('R1', ext(P, 0, x.lvl('A1'))),
           x.tmp('C1', ext(P, 1, x.lvl('A1'))),
           x.tmp('R2', ext(P, 0, x.lvl('A2'))),
           x.tmp('C2', ext(P, 1, x.lvl('A2'))),
           x.tmp('O', ci(P, 1)),
           x.bindl('a', bin_(P, 2, 'eq', x.lvl('R1'), x.lvl('R2'))),
           x.tmp('b', bin_(P, 2, 'eq', x.lvl('R1'), x.lvl('O'))),
           x.tmp('c', bin_(P, 2, 'eq', x.lvl('R2'), x.lvl('O'))),
           asg(P, 'set', x.lvl('a'), bin_(P, 2, 'bor', x.lvl('a'), x.lvl('b'))),
           asg(P, 'set', x.lvl('a'), bin_(P, 2, 'bor', x.lvl('a'), x.lvl('c'))),
           x.bindl('a2', bin_(P, 2, 'eq', x.lvl('C1'), x.lvl('C2'))),
           x.tmp('b2', bin_(P, 2, 'eq', x.lvl('C1'), x.lvl('O'))),
           x.tmp('c2', bin_(P, 2, 'eq', x.lvl('C2'), x.lvl('O'))),
           asg(P, 'set', x.lvl('a2'), bin_(P, 2, 'bor', x.lvl('a2'), x.lvl('b2'))),
           asg(P, 'set', x.lvl('a2'), bin_(P, 2, 'bor', x.lvl('a2'), x.lvl('c2'))),
           asg(P, 'set', x.lvl('a'), bin_(P, 2, 'band', x.lvl('a'), x.lvl('a2'))),
           x.tmp('S', un(P, 2, 'not', x.lvl('a'))),
           x.mchk('SHAPE_MISMATCH', 'S', 'R1', 'C1', 'R2', 'C2'),
           x.tmp('Rq', lib(P, 3, 'where', [bin_(P, 2, 'eq', x.lvl('R1'), x.lvl('O')),
                                           x.lvl('R2'), x.lvl('R1')])),
           x.tmp('Cq', lib(P, 3, 'where', [bin_(P, 2, 'eq', x.lvl('C1'), x.lvl('O')),
                                           x.lvl('C2'), x.lvl('C1')]))]
    # (3) the result; (4) the strides of each operand; (5) the data
    st += [x.tmp('RES', anew(P, 11, 0, [x.lvl('Rq'), x.lvl('Cq')]))]
    for k in ('1', '2'):
        st += [x.tmp('SI' + k, bin_(P, 2, 'ne', x.lvl('R' + k), x.lvl('O'))),
               x.tmp('t' + k, bin_(P, 2, 'ne', x.lvl('C' + k), x.lvl('O'))),
               x.tmp('SJ' + k, wbin(P, 'mul', x.lvl('t' + k), x.lvl('R' + k)))]
    st += [x.tmp('DR', adat(P, 12, x.lvl('RES'))),
           x.tmp('D1', adat(P, 12, x.lvl('A1'))),
           x.tmp('D2', adat(P, 12, x.lvl('A2')))]

    def opnd(k):
        return eld(P, 4, x.lvl('D' + k),
                   wbin(P, 'add', wbin(P, 'mul', x.klv('I'), x.lvl('SI' + k)),
                        wbin(P, 'mul', x.klv('J'), x.lvl('SJ' + k))))

    def body():
        Fn_ = bin_('0:5:9', 4, 'mul', opnd('1'), opnd('2'))
        return [est(P, 4, Fn_, x.lvl('DR'), x.lin(x.klv('I'), x.klv('J'), x.lvl('Rq')))]
    # (6) mloop(R, C; I, J) over the combined shape
    st += x.loop('Cq', 'Zj', 'Oj', 'Lj', 'J', lambda: x.loop('Rq', 'Zi', 'Oi', 'Li', 'I', body))
    eds.append(('''
lv 0:5:9 10 1
view 0:5:9 11 col
lv 0:5:17 10 2
view 0:5:17 11 row
bin 0:5:9 11 mul
''', cat(xblk(P, st, x.lvl('RES')))))
    eds.append((['lv 0:6:48 11 3', 'lib 0:6:43 3 rows 1'], cat(L3('0:6:43', 0, lv('0:6:48', 11, 3)))))
    eds.append((['lv 0:6:57 11 3', 'lib 0:6:52 3 cols 1'], cat(L3('0:6:52', 1, lv('0:6:57', 11, 3)))))
    return make_hirl(HIR1['ew_colrow'], ['tptr 12 4'], {1: (F, eds)})


HIRL['ew_colrow'] = hirl_ew_colrow
# sea.lir1. ones(2), a[1] = 3.0, ones(3), b[2] = 5.0 (rules 17, 19). Line 5: a.col materialized
# (rule 28: the extent, arrnew of n x 1, data of both, the byte count `li 8`, `imul`, mcopy), then
# b.row (1 x n); rule 22 of two matrices: the four extents, `li O 1`, the check of b.row against
# a.col (icmp eq, ior, ior per dimension, iand, bnot, chk), the combined extents by isel, arrnew of
# P, the strides of each operand, the data of P and of each operand, the nest loop(C; J) around
# loop(R; I) with each operand's index right before its load and the result's after the fmul;
# then the two materialized views released in operand order (T2, rule 22 (8)). Line 6: two
# matrix element reads (rule 18), rows and cols (ldi of the header), the printf slot of 32 bytes.
# P, b, a released at the end.
LIR1['ew_colrow'] = '''
func .main main 0:1:1 0 0
slot s1 32 8
li i.Ra 2
li i.eka 1
li i.rka 1
li i.ca 1
rcall sea_arr_new_u 0:1 1 p.a 4 i.eka i.rka i.Ra i.ca
lf f.Va #3FF0000000000000
ldp p.Da p.a - 0 40
li i.Za 0
icmp gt i.ga i.Ra i.Za
if 1 i.ga
li i.Oa 1
isub i.La i.Ra i.Oa
loop 2 i.Ka i.Za i.La i.Oa
stf f.Va p.Da i.Ka 8 0
endloop 2
endif 1
lf f.v2 #4008000000000000
li i.x2 1
ldi i.e2 p.a - 0 16
chkb i.x2 i.e2 0 0:2
ldi i.rc2 p.a - 0 0
li i.o2 1
icmp ne i.s2 i.rc2 i.o2
if 3 i.s2
rcall sea_arr_unique 0:2 1 p.u2 1 p.a
mov p.a p.u2
endif 3
ldp p.d2 p.a - 0 40
stf f.v2 p.d2 i.x2 8 0
li i.Rb 3
li i.ekb 1
li i.rkb 1
li i.cb 1
rcall sea_arr_new_u 0:3 1 p.b 4 i.ekb i.rkb i.Rb i.cb
lf f.Vb #3FF0000000000000
ldp p.Db p.b - 0 40
li i.Zb 0
icmp gt i.gb i.Rb i.Zb
if 4 i.gb
li i.Ob 1
isub i.Lb i.Rb i.Ob
loop 5 i.Kb i.Zb i.Lb i.Ob
stf f.Vb p.Db i.Kb 8 0
endloop 5
endif 4
lf f.v4 #4014000000000000
li i.x4 2
ldi i.e4 p.b - 0 16
chkb i.x4 i.e4 0 0:4
ldi i.rc4 p.b - 0 0
li i.o4 1
icmp ne i.s4 i.rc4 i.o4
if 6 i.s4
rcall sea_arr_unique 0:4 1 p.u4 1 p.b
mov p.b p.u4
endif 6
ldp p.d4 p.b - 0 40
stf f.v4 p.d4 i.x4 8 0
ldi i.Rc p.a - 0 16
li i.1c 1
li i.ekc 1
li i.rkc 2
rcall sea_arr_new_u 0:5 1 p.A1 4 i.ekc i.rkc i.Rc i.1c
ldp p.Dc p.A1 - 0 40
ldp p.Sc p.a - 0 40
li i.8c 8
imul i.NBc i.Rc i.8c
mcopy p.Dc p.Sc i.NBc
ldi i.Rr p.b - 0 16
li i.1r 1
li i.ekr 1
li i.rkr 2
rcall sea_arr_new_u 0:5 1 p.A2 4 i.ekr i.rkr i.1r i.Rr
ldp p.Dr p.A2 - 0 40
ldp p.Sr p.b - 0 40
li i.8r 8
imul i.NBr i.Rr i.8r
mcopy p.Dr p.Sr i.NBr
ldi i.R1 p.A1 - 0 16
ldi i.C1 p.A1 - 0 24
ldi i.R2 p.A2 - 0 16
ldi i.C2 p.A2 - 0 24
li i.O 1
icmp eq i.a i.R1 i.R2
icmp eq i.b i.R1 i.O
icmp eq i.c i.R2 i.O
ior i.a i.a i.b
ior i.a i.a i.c
icmp eq i.a2 i.C1 i.C2
icmp eq i.b2 i.C1 i.O
icmp eq i.c2 i.C2 i.O
ior i.a2 i.a2 i.b2
ior i.a2 i.a2 i.c2
iand i.a i.a i.a2
bnot i.S i.a
chk i.S SHAPE_MISMATCH 0:5 4 i.R1 i.C1 i.R2 i.C2
icmp eq i.q1 i.R1 i.O
isel i.Rq i.q1 i.R2 i.R1
icmp eq i.q2 i.C1 i.O
isel i.Cq i.q2 i.C2 i.C1
li i.ek 1
li i.rk 2
rcall sea_arr_new_u 0:5 1 p.P 4 i.ek i.rk i.Rq i.Cq
icmp ne i.SI1 i.R1 i.O
icmp ne i.t1 i.C1 i.O
imul i.SJ1 i.t1 i.R1
icmp ne i.SI2 i.R2 i.O
icmp ne i.t2 i.C2 i.O
imul i.SJ2 i.t2 i.R2
ldp p.DR p.P - 0 40
ldp p.D1 p.A1 - 0 40
ldp p.D2 p.A2 - 0 40
li i.Zj 0
icmp gt i.gj i.Cq i.Zj
if 7 i.gj
li i.Oj 1
isub i.Lj i.Cq i.Oj
loop 8 i.J i.Zj i.Lj i.Oj
li i.Zi 0
icmp gt i.gi i.Rq i.Zi
if 9 i.gi
li i.Oi 1
isub i.Li i.Rq i.Oi
loop 10 i.I i.Zi i.Li i.Oi
imul i.x1 i.I i.SI1
imul i.y1 i.J i.SJ1
iadd i.X1 i.x1 i.y1
ldf f.e1 p.D1 i.X1 8 0
imul i.xx2 i.I i.SI2
imul i.y2 i.J i.SJ2
iadd i.X2 i.xx2 i.y2
ldf f.e2 p.D2 i.X2 8 0
fmul f.p f.e1 f.e2
imul i.tt i.J i.Rq
iadd i.Y i.I i.tt
stf f.p p.DR i.Y 8 0
endloop 10
endif 9
endloop 8
endif 7
release p.A1
release p.A2
li i.i6 1
li i.j6 0
ldi i.r6 p.P - 0 16
chkb i.i6 i.r6 0 0:6
ldi i.c6 p.P - 0 24
chkb i.j6 i.c6 1 0:6
ldp p.d6 p.P - 0 40
imul i.t6 i.j6 i.r6
iadd i.k6 i.i6 i.t6
ldf f.p6 p.d6 i.k6 8 0
li i.i7 1
li i.j7 2
ldi i.r7 p.P - 0 16
chkb i.i7 i.r7 0 0:6
ldi i.c7 p.P - 0 24
chkb i.j7 i.c7 1 0:6
ldp p.d7 p.P - 0 40
imul i.t7 i.j7 i.r7
iadd i.k7 i.i7 i.t7
ldf f.p7 p.d7 i.k7 8 0
ldi i.rows p.P - 0 16
ldi i.cols p.P - 0 24
sa p.s s1
stf f.p6 p.s - 0 0
stf f.p7 p.s - 0 8
sti i.rows p.s - 0 16
sti i.cols p.s - 0 24
la p.f d1
rcall sea_printf 0:6 0 2 p.f p.s
release p.P
release p.b
release p.a
ret 0
endfunc
fmt d1 8
fconv - - - g f
ftext %20
fconv - - - g f
ftext %20
fconv - - - d i
ftext %20
fconv - - - d i
ftext %0A
'''
# a = [1, 3], b = [1, 1, 5]: P[i, j] = a[i] * b[j] is 2 x 3; P[1, 0] = 3, P[1, 2] = 15.
OUT['ew_colrow'] = '3 15 2 3\n'
NAMES.append('ew_colrow')

# ================================================================ arr_lit_fixed (rule 26 (a), (d) / L9)
SEA['arr_lit_fixed'] = '''let f = [1.5, 2.5, 4.0]
let e: f64[] = []
let z: f64[0] = []
let m = [1, 2; 3, 4]
printf("%g %d %d %d\\n", f[1], len(e), len(z), m[1, 0])
// arr_lit_fixed -- DESIGN.md 3.5.9 L9 (rule 26 (a), (d)): fixed-size vector and matrix literals
// (a home slot, one est per element at its column-major offset), copied into the homes of the
// locals (rule 27 (b)); [] under a dynamic type (anew of extent 0) and under a fixed-size type
// without elements (a home slot, no store)
'''
AST['arr_lit_fixed'] = '''
pname 0:1:5 f
float 0:1:10 #3FF8000000000000
float 0:1:15 #4004000000000000
float 0:1:20 #4010000000000000
row 0:1:10 3
array 0:1:9 1
let 0:1:1 0
pname 0:2:5 e
type 0:2:8 f64 v 0
array 0:2:16 0
let 0:2:1 1
pname 0:3:5 z
int 0:3:12 0
type 0:3:8 f64 fv 1
array 0:3:17 0
let 0:3:1 1
pname 0:4:5 m
int 0:4:10 1
int 0:4:13 2
row 0:4:10 2
int 0:4:16 3
int 0:4:19 4
row 0:4:16 2
array 0:4:9 2
let 0:4:1 0
name 0:5:1 printf
str 0:5:8 %25g%20%25d%20%25d%20%25d%0A
name 0:5:25 f
int 0:5:27 1
index 0:5:25 1
name 0:5:31 len
name 0:5:35 e
call 0:5:31 1
name 0:5:39 len
name 0:5:43 z
call 0:5:39 1
name 0:5:47 m
int 0:5:49 1
int 0:5:52 0
index 0:5:47 2
call 0:5:1 5
cstmt 0:5:1
prog 5
'''
# sea.hir1: f64[3] 10, f64[] 11, f64[0] 12, i64[2,2] 13 (the loc records of f, e, z, m), i64[2] 14
# (each row of m: the type of its horizontal join, 3.5.5). Each [] takes its binding's declared
# type (LANGUAGE.md 6.9).
HIR1['arr_lit_fixed'] = '''
tfvec 10 4 3
tvec 11 4
tfvec 12 4 0
tfmat 13 3 2 2
tfvec 14 3 2
fn 1 .main main 1 0 4 0:1:1
loc f 10 let 0:1:5
loc e 11 let 0:2:5
loc z 12 let 0:3:5
loc m 13 let 0:4:5
cf 0:1:10 4 #3FF8000000000000
cf 0:1:15 4 #4004000000000000
cf 0:1:20 4 #4010000000000000
row 0:1:10 10 3
arr 0:1:9 10 1
bind 0:1:1 1
arr 0:2:16 11 0
bind 0:2:1 2
arr 0:3:17 12 0
bind 0:3:1 3
ci 0:4:10 3 1
ci 0:4:13 3 2
row 0:4:10 14 2
ci 0:4:16 3 3
ci 0:4:19 3 4
row 0:4:16 14 2
arr 0:4:9 13 2
bind 0:4:1 4
lv 0:5:25 10 1
ci 0:5:27 3 1
idx 0:5:25 4 1
fconv 0:5:8 1 - - - g
ftext 0:5:8 1 %20
lv 0:5:35 11 2
lib 0:5:31 3 len 1
fconv 0:5:8 1 - - - d
ftext 0:5:8 1 %20
lv 0:5:43 12 3
lib 0:5:39 3 len 1
fconv 0:5:8 1 - - - d
ftext 0:5:8 1 %20
lv 0:5:47 13 4
ci 0:5:49 3 1
ci 0:5:52 3 0
idx 0:5:47 3 2
fconv 0:5:8 1 - - - d
ftext 0:5:8 1 %0A
fmt 0:5:8 1 8
lib 0:5:1 1 printf 1
eval 0:5:1
block 0:1:1 5
end
'''


def L9a(F, P, T, E, TP, pre, elems, r):
    """L9 (a): a fixed-size literal without concatenation: `xblk P T n` with `tmp H = anew P T 0
    0`, `tmp D = data(H)`, then each element (i, j) in source order `est s 0 e (lv D) (ci k)`, k =
    i + j*r; elems the element nodes row by row, each with its (i, j)."""
    x = Ctx(F, P, pre)
    st = [x.tmp('H', anew(P, T, 0, [])), x.tmp('D', adat(P, TP, x.lvl('H')))]
    for (i, j), e in elems:
        st.append(est(P, E, e, x.lvl('D'), ci(P, i + j * r)))
    return xblk(P, st, x.lvl('H'))


def hirl_arr_lit_fixed():
    """sea.hirl: tptr 15 4 (the adat of f's literal), 16 3 (of m's). Lines 1 and 4 are L9 (a), the
    two [] L9 (d) (anew of a dynamic type with a `ci 0` extent; anew of a fixed-size type), the
    two len L3 (the second of a fixed-size vector)."""
    F = Fn()
    eds = [('''
cf 0:1:10 4 #3FF8000000000000
cf 0:1:15 4 #4004000000000000
cf 0:1:20 4 #4010000000000000
row 0:1:10 10 3
arr 0:1:9 10 1
''', cat(L9a(F, '0:1:9', 10, 4, 15, 'f', [
        ((0, 0), cf('0:1:10', '#3FF8000000000000')),
        ((0, 1), cf('0:1:15', '#4004000000000000')),
        ((0, 2), cf('0:1:20', '#4010000000000000'))], 1))),
           (['arr 0:2:16 11 0'], cat(anew('0:2:16', 11, 1, [ci('0:2:16', 0)]))),
           (['arr 0:3:17 12 0'], cat(anew('0:3:17', 12, 0, []))),
           ('''
ci 0:4:10 3 1
ci 0:4:13 3 2
row 0:4:10 14 2
ci 0:4:16 3 3
ci 0:4:19 3 4
row 0:4:16 14 2
arr 0:4:9 13 2
''', cat(L9a(F, '0:4:9', 13, 3, 16, 'm', [
        ((0, 0), ci('0:4:10', 1)), ((0, 1), ci('0:4:13', 2)),
        ((1, 0), ci('0:4:16', 3)), ((1, 1), ci('0:4:19', 4))], 2))),
           (['lv 0:5:35 11 2', 'lib 0:5:31 3 len 1'], cat(L3('0:5:31', 0, lv('0:5:35', 11, 2)))),
           (['lv 0:5:43 12 3', 'lib 0:5:39 3 len 1'], cat(L3('0:5:39', 0, lv('0:5:43', 12, 3))))]
    return make_hirl(HIR1['arr_lit_fixed'], ['tptr 15 4', 'tptr 16 3'], {1: (F, eds)})


HIRL['arr_lit_fixed'] = hirl_arr_lit_fixed
# sea.lir1. Line 1: the bind of the fixed-size local f (rule 27 (b)): `sa` of f's slot s1 (24
# bytes), then the value: the literal's home slot s2 (R1), each element stored right after its
# `lf` at its offset (R3: `- 0 off`), then the copy into f's home (`li 24`, mcopy; rule 27 (c),
# no retains: f64 elements). Line 2: arrnewz of extent 0 into e. Line 3: z's slot s3 and the 8-byte
# home s4 of `[]` under f64[0] (no store), copied with its size 0. Line 4: m's slot s5 (32 bytes),
# the home s6, the four i64 elements at 0, 16, 8, 24 (element (i, j) at (i + 2j) * 8), the copy.
# Line 5: f[1] (rule 18 on a fixed-size base: the extent `li 3`, the home address as data), len(e)
# (ldi), len(z) (`li 0`, its static extent), m[1, 0] (`li 2` for each extent), the printf slot s7
# of 32 bytes. Only e holds counts: released at the end.
LIR1['arr_lit_fixed'] = '''
func .main main 0:1:1 0 0
slot s1 24 8
slot s2 24 8
slot s3 8 8
slot s4 8 8
slot s5 32 8
slot s6 32 8
slot s7 32 8
sa p.f s1
sa p.H1 s2
lf f.a #3FF8000000000000
stf f.a p.H1 - 0 0
lf f.b #4004000000000000
stf f.b p.H1 - 0 8
lf f.c #4010000000000000
stf f.c p.H1 - 0 16
li i.n1 24
mcopy p.f p.H1 i.n1
li i.x2 0
li i.ek2 1
li i.rk2 1
li i.c2 1
rcall sea_arr_new 0:2 1 p.e 4 i.ek2 i.rk2 i.x2 i.c2
sa p.z s3
sa p.H3 s4
li i.n3 0
mcopy p.z p.H3 i.n3
sa p.m s5
sa p.H4 s6
li i.v1 1
sti i.v1 p.H4 - 0 0
li i.v2 2
sti i.v2 p.H4 - 0 16
li i.v3 3
sti i.v3 p.H4 - 0 8
li i.v4 4
sti i.v4 p.H4 - 0 24
li i.n4 32
mcopy p.m p.H4 i.n4
li i.k5 1
li i.x5 3
chkb i.k5 i.x5 0 0:5
ldf f.r5 p.f i.k5 8 0
ldi i.le p.e - 0 16
li i.lz 0
li i.i6 1
li i.j6 0
li i.r6 2
chkb i.i6 i.r6 0 0:5
li i.c6 2
chkb i.j6 i.c6 1 0:5
imul i.t6 i.j6 i.r6
iadd i.p6 i.i6 i.t6
ldi i.v6 p.m i.p6 8 0
sa p.s s7
stf f.r5 p.s - 0 0
sti i.le p.s - 0 8
sti i.lz p.s - 0 16
sti i.v6 p.s - 0 24
la p.fm d1
rcall sea_printf 0:5 0 2 p.fm p.s
release p.e
ret 0
endfunc
fmt d1 8
fconv - - - g f
ftext %20
fconv - - - d i
ftext %20
fconv - - - d i
ftext %20
fconv - - - d i
ftext %0A
'''
# f[1] = 2.5; len(e) = len(z) = 0; m = [1 2; 3 4], m[1, 0] = 3.
OUT['arr_lit_fixed'] = '2.5 0 0 3\n'
NAMES.append('arr_lit_fixed')

# ================================================================ arr_lit_dyn (rule 26 (b) / L9)
# Generated: lines 2 and 3 hold 257 elements each (LANGUAGE.md 6.9: more than 256 scalars make a
# dynamic literal). Every record of the four files is computed from the element columns.
DYN_BIG = [str(k) for k in range(257)]
DYN_MIX = ['x'] + [str(k) for k in range(1, 257)]
SEA['arr_lit_dyn'] = '''let x = 0.5
let big = [%s]
let mix = [%s]
printf("%%d %%g %%g %%d\\n", big[256], mix[0], mix[256], len(mix))
// arr_lit_dyn -- DESIGN.md 3.5.9 L9 (rule 26 (b)): dynamic literals of 257 elements (more than
// 256 scalars): of constants only (line 2, an i64[] filled from a cdat buffer by mcpy), and
// with a non-constant element (line 3, an f64[]: one est per element; its untyped integers are
// f64 constants, LANGUAGE.md 4.2)
''' % (', '.join(DYN_BIG), ', '.join(DYN_MIX))


def dyn_cols(line_no):
    """(column, text) of each element of the literal on line line_no of arr_lit_dyn."""
    s = SEA['arr_lit_dyn'].split('\n')[line_no - 1]
    k = s.index('[') + 1
    out = []
    for m in re.finditer(r'[^, \]]+', s[k:s.index(']')]):
        out.append((k + m.start() + 1, m.group(0)))
    assert len(out) == 257
    return out


def f64_bits(v):
    return '#%016X' % struct.unpack('>Q', struct.pack('>d', float(v)))[0]


def ast_arr_lit_dyn():
    out = ['pname 0:1:5 x', 'float 0:1:9 #3FE0000000000000', 'let 0:1:1 0', 'pname 0:2:5 big']
    out += ['int 0:2:%d %s' % (c, t) for c, t in dyn_cols(2)]
    out += ['row 0:2:12 257', 'array 0:2:11 1', 'let 0:2:1 0', 'pname 0:3:5 mix']
    out += [('name 0:3:%d x' if t == 'x' else 'int 0:3:%d ' + t) % c for c, t in dyn_cols(3)]
    out += ['row 0:3:12 257', 'array 0:3:11 1', 'let 0:3:1 0']
    out += lines('''
name 0:4:1 printf
str 0:4:8 %25d%20%25g%20%25g%20%25d%0A
name 0:4:25 big
int 0:4:29 256
index 0:4:25 1
name 0:4:35 mix
int 0:4:39 0
index 0:4:35 1
name 0:4:43 mix
int 0:4:47 256
index 0:4:43 1
name 0:4:53 len
name 0:4:57 mix
call 0:4:53 1
call 0:4:1 5
cstmt 0:4:1
prog 4
''')
    return out


AST['arr_lit_dyn'] = ast_arr_lit_dyn()


def dyn_elems(line_no):
    """The HIR element nodes of line 2 (ci) or 3 (lv x, then cf: untyped integers in an f64
    literal are f64 constants, 3.5.5)."""
    out = []
    for c, t in dyn_cols(line_no):
        P = '0:%d:%d' % (line_no, c)
        if t == 'x':
            out.append(lv(P, 4, 1))
        elif line_no == 2:
            out.append(ci(P, int(t)))
        else:
            out.append(cf(P, f64_bits(int(t))))
    return out


# sea.hir1: i64[] 10 (`loc big`), f64[] 11 (`loc mix`); each row of 257 scalars has the type of its
# horizontal join, the dynamic vector (6.9: more than 256 scalars).
HIR1['arr_lit_dyn'] = '\n' + '\n'.join(
    ['tvec 10 3', 'tvec 11 4', 'fn 1 .main main 1 0 3 0:1:1', 'loc x 4 let 0:1:5',
     'loc big 10 let 0:2:5', 'loc mix 11 let 0:3:5', 'cf 0:1:9 4 #3FE0000000000000',
     'bind 0:1:1 1'] + cat(*dyn_elems(2)) + ['row 0:2:12 10 257', 'arr 0:2:11 10 1', 'bind 0:2:1 2']
    + cat(*dyn_elems(3)) + ['row 0:3:12 11 257', 'arr 0:3:11 11 1', 'bind 0:3:1 3']
    + lines('''
lv 0:4:25 10 2
ci 0:4:29 3 256
idx 0:4:25 3 1
fconv 0:4:8 1 - - - d
ftext 0:4:8 1 %20
lv 0:4:35 11 3
ci 0:4:39 3 0
idx 0:4:35 4 1
fconv 0:4:8 1 - - - g
ftext 0:4:8 1 %20
lv 0:4:43 11 3
ci 0:4:47 3 256
idx 0:4:43 4 1
fconv 0:4:8 1 - - - g
ftext 0:4:8 1 %20
lv 0:4:57 11 3
lib 0:4:53 3 len 1
fconv 0:4:8 1 - - - d
ftext 0:4:8 1 %0A
fmt 0:4:8 1 8
lib 0:4:1 1 printf 1
eval 0:4:1
block 0:1:1 4
end
''')) + '\n'


def hirl_arr_lit_dyn():
    """sea.hirl: tptr 12 3 (the adat of big's array), 13 4 (of mix's). Line 2 is L9 (b) with
    constants only: `tmp R = ci 257`, anew, data, `tmp S = cdat` of the 257 constants (kept nodes:
    their own positions), `tmp B = ci 2056`, mcpy. Line 3 is L9 (b) with an `lv`: one est per
    element at `ci k`. len(mix) is L3."""
    F = Fn()
    P = '0:2:11'
    x = Ctx(F, P, 'b')
    e2 = dyn_elems(2)
    st = [x.tmp('R', ci(P, 257)),
          x.tmp('A', anew(P, 10, 0, [x.lvl('R')])),
          x.tmp('D', adat(P, 12, x.lvl('A'))),
          x.tmp('S', cdat(P, 12, e2)),
          x.tmp('B', ci(P, 257 * ES[3])),
          mcpy(P, x.lvl('D'), x.lvl('S'), x.lvl('B'))]
    big = (cat(*e2) + ['row 0:2:12 10 257', 'arr 0:2:11 10 1'], cat(xblk(P, st, x.lvl('A'))))
    P = '0:3:11'
    x = Ctx(F, P, 'm')
    e3 = dyn_elems(3)
    st = [x.tmp('R', ci(P, 257)),
          x.tmp('A', anew(P, 11, 0, [x.lvl('R')])),
          x.tmp('D', adat(P, 13, x.lvl('A')))]
    st += [est(P, 4, e, x.lvl('D'), ci(P, k)) for k, e in enumerate(e3)]
    mix = (cat(*e3) + ['row 0:3:12 11 257', 'arr 0:3:11 11 1'], cat(xblk(P, st, x.lvl('A'))))
    ln = (['lv 0:4:57 11 3', 'lib 0:4:53 3 len 1'], cat(L3('0:4:53', 0, lv('0:4:57', 11, 3))))
    return make_hirl(HIR1['arr_lit_dyn'], ['tptr 12 3', 'tptr 13 4'], {1: (F, [big, mix, ln])})


HIRL['arr_lit_dyn'] = hirl_arr_lit_dyn


def lir_arr_lit_dyn():
    """sea.lir1. x; big: `li 257`, arrnew (i64, not cleared), data, `la` of the dat buffer d1 (257
    dvi records, the constants in order, rule 26 (b)), `li 2056`, mcopy; mix: `li 257`, arrnew,
    data, then each element stored right after its evaluation at `- 0 8k` (x from its register,
    each constant by `lf`); the printf (big[256] by ldi, mix[0] and mix[256] by ldf, len(mix)),
    the slot of 32 bytes; mix and big released in reverse order of declaration."""
    out = lines('''
func .main main 0:1:1 0 0
slot s1 32 8
lf f.x #3FE0000000000000
li i.Rb 257
li i.ekb 2
li i.rkb 1
li i.cb 1
rcall sea_arr_new_u 0:2 1 p.big 4 i.ekb i.rkb i.Rb i.cb
ldp p.Db p.big - 0 40
la p.Sb d1
li i.Bb 2056
mcopy p.Db p.Sb i.Bb
li i.Rm 257
li i.ekm 1
li i.rkm 1
li i.cm 1
rcall sea_arr_new_u 0:3 1 p.mix 4 i.ekm i.rkm i.Rm i.cm
ldp p.Dm p.mix - 0 40
stf f.x p.Dm - 0 0
''')
    for k in range(1, 257):
        out += ['lf f.e%d %s' % (k, f64_bits(k)), 'stf f.e%d p.Dm - 0 %d' % (k, 8 * k)]
    out += lines('''
li i.k1 256
ldi i.x1 p.big - 0 16
chkb i.k1 i.x1 0 0:4
ldp p.d1 p.big - 0 40
ldi i.v1 p.d1 i.k1 8 0
li i.k2 0
ldi i.x2 p.mix - 0 16
chkb i.k2 i.x2 0 0:4
ldp p.d2 p.mix - 0 40
ldf f.v2 p.d2 i.k2 8 0
li i.k3 256
ldi i.x3 p.mix - 0 16
chkb i.k3 i.x3 0 0:4
ldp p.d3 p.mix - 0 40
ldf f.v3 p.d3 i.k3 8 0
ldi i.n4 p.mix - 0 16
sa p.s s1
sti i.v1 p.s - 0 0
stf f.v2 p.s - 0 8
stf f.v3 p.s - 0 16
sti i.n4 p.s - 0 24
la p.f d2
rcall sea_printf 0:4 0 2 p.f p.s
release p.mix
release p.big
ret 0
endfunc
dat d1 i64 257
''')
    out += ['dvi %d' % k for k in range(257)]
    out += lines('''
fmt d2 8
fconv - - - d i
ftext %20
fconv - - - g f
ftext %20
fconv - - - g f
ftext %20
fconv - - - d i
ftext %0A
''')
    return '\n' + '\n'.join(out) + '\n'


LIR1['arr_lit_dyn'] = lir_arr_lit_dyn()
# big[256] = 256; mix[0] = x = 0.5; mix[256] = 256; len(mix) = 257.
OUT['arr_lit_dyn'] = '256 0.5 256 257\n'
NAMES.append('arr_lit_dyn')

# ================================================================ arr_lit_cat (rule 26 (c) / L9)
SEA['arr_lit_cat'] = '''var a = ones(2)
a[1] = 3.0
let v = [a, 5.0, a]
var M = ones(2, 1)
M[1, 0] = 2.0
let W = [M, M]
printf("%g %g %d %g %d\\n", v[2], v[4], len(v), W[1, 1], cols(W))
// arr_lit_cat -- DESIGN.md 3.5.9 L9 (rule 26 (c)): a vector concatenation of vectors and a
// scalar (line 3, the lengths summed, no check) and a row of two matrices (line 6, the rows
// checked against the first part's, the columns summed); each part copied at its offsets
'''
AST['arr_lit_cat'] = '''
pname 0:1:5 a
name 0:1:9 ones
int 0:1:14 2
call 0:1:9 1
var 0:1:1 0
name 0:2:1 a
int 0:2:3 1
index 0:2:1 1
float 0:2:8 #4008000000000000
asg 0:2:1 set
pname 0:3:5 v
name 0:3:10 a
float 0:3:13 #4014000000000000
name 0:3:18 a
row 0:3:10 3
array 0:3:9 1
let 0:3:1 0
pname 0:4:5 M
name 0:4:9 ones
int 0:4:14 2
int 0:4:17 1
call 0:4:9 2
var 0:4:1 0
name 0:5:1 M
int 0:5:3 1
int 0:5:6 0
index 0:5:1 2
float 0:5:11 #4000000000000000
asg 0:5:1 set
pname 0:6:5 W
name 0:6:10 M
name 0:6:13 M
row 0:6:10 2
array 0:6:9 1
let 0:6:1 0
name 0:7:1 printf
str 0:7:8 %25g%20%25g%20%25d%20%25g%20%25d%0A
name 0:7:28 v
int 0:7:30 2
index 0:7:28 1
name 0:7:34 v
int 0:7:36 4
index 0:7:34 1
name 0:7:40 len
name 0:7:44 v
call 0:7:40 1
name 0:7:48 W
int 0:7:50 1
int 0:7:53 1
index 0:7:48 2
name 0:7:57 cols
name 0:7:62 W
call 0:7:57 1
call 0:7:1 6
cstmt 0:7:1
prog 7
'''
# sea.hir1: f64[] 10 (`loc a`), f64[,] 11 (`loc M`); the literal of line 3 and its row are f64[]
# (a row of a vector, a scalar and a vector joins into a vector), that of line 6 and its row
# f64[,] (dynamic parts give a dynamic result, LANGUAGE.md 6.9).
HIR1['arr_lit_cat'] = '''
tvec 10 4
tmat 11 4
fn 1 .main main 1 0 4 0:1:1
loc a 10 var 0:1:5
loc v 10 let 0:3:5
loc M 11 var 0:4:5
loc W 11 let 0:6:5
ci 0:1:14 3 2
lib 0:1:9 10 ones 1
bind 0:1:1 1
lv 0:2:1 10 1
ci 0:2:3 3 1
idx 0:2:1 4 1
cf 0:2:8 4 #4008000000000000
asg 0:2:1 set
lv 0:3:10 10 1
cf 0:3:13 4 #4014000000000000
lv 0:3:18 10 1
row 0:3:10 10 3
arr 0:3:9 10 1
bind 0:3:1 2
ci 0:4:14 3 2
ci 0:4:17 3 1
lib 0:4:9 11 ones 2
bind 0:4:1 3
lv 0:5:1 11 3
ci 0:5:3 3 1
ci 0:5:6 3 0
idx 0:5:1 4 2
cf 0:5:11 4 #4000000000000000
asg 0:5:1 set
lv 0:6:10 11 3
lv 0:6:13 11 3
row 0:6:10 11 2
arr 0:6:9 11 1
bind 0:6:1 4
lv 0:7:28 10 2
ci 0:7:30 3 2
idx 0:7:28 4 1
fconv 0:7:8 1 - - - g
ftext 0:7:8 1 %20
lv 0:7:34 10 2
ci 0:7:36 3 4
idx 0:7:34 4 1
fconv 0:7:8 1 - - - g
ftext 0:7:8 1 %20
lv 0:7:44 10 2
lib 0:7:40 3 len 1
fconv 0:7:8 1 - - - d
ftext 0:7:8 1 %20
lv 0:7:48 11 4
ci 0:7:50 3 1
ci 0:7:53 3 1
idx 0:7:48 4 2
fconv 0:7:8 1 - - - g
ftext 0:7:8 1 %20
lv 0:7:62 11 4
lib 0:7:57 3 cols 1
fconv 0:7:8 1 - - - d
ftext 0:7:8 1 %0A
fmt 0:7:8 1 10
lib 0:7:1 1 printf 1
eval 0:7:1
block 0:1:1 7
end
'''


def hirl_arr_lit_cat():
    """sea.hirl: tptr 12 4 (the adat of ones(2), L2). Lines 1 and 4 are L2, line 3 L9 (c) with a
    vector result, line 6 L9 (c) with one row of matrices, line 7's len and cols L3."""
    F = Fn()
    eds = [(['ci 0:1:14 3 2', 'lib 0:1:9 10 ones 1'],
            cat(L2(F, '0:1:9', 10, 4, 12, 'a', r=ci('0:1:14', 2)))),
           (['ci 0:4:14 3 2', 'ci 0:4:17 3 1', 'lib 0:4:9 11 ones 2'],
            cat(L2(F, '0:4:9', 11, 4, 12, 'o', r=ci('0:4:14', 2), c=ci('0:4:17', 1))))]
    # ---- line 3: [a, 5.0, a], a vector result
    P = '0:3:9'
    x = Ctx(F, P, 'v')
    st = [x.tmp('Q1', lv('0:3:10', 10, 1)),                       # the parts in source order
          x.tmp('Q2', cf('0:3:13', '#4014000000000000')),
          x.tmp('Q3', lv('0:3:18', 10, 1)),
          x.tmp('L1', ext(P, 0, x.lvl('Q1'))),                    # the lengths, summed
          x.tmp('L2', ci(P, 1)),
          x.tmp('N2', wbin(P, 'add', x.lvl('L1'), x.lvl('L2'))),
          x.tmp('L3', ext(P, 0, x.lvl('Q3'))),
          x.tmp('N3', wbin(P, 'add', x.lvl('N2'), x.lvl('L3'))),
          x.tmp('RES', anew(P, 10, 0, [x.lvl('N3')])),
          x.tmp('DR', adat(P, 12, x.lvl('RES')))]

    def vpart(k):
        return [x.tmp('Dq' + k, adat(P, 12, x.lvl('Q' + k)))] + x.loop(
            'L' + k, 'Z' + k, 'O' + k, 'M' + k, 'I' + k, lambda: [
                est(P, 4, eld(P, 4, x.lvl('Dq' + k), x.klv('I' + k)), x.lvl('DR'),
                    wbin(P, 'add', x.lvl('c' + k), x.klv('I' + k)))])
    st.append(x.tmp('c1', ci(P, 0)))
    st += vpart('1')
    st += [x.tmp('c2', wbin(P, 'add', x.lvl('c1'), x.lvl('L1'))),
           est(P, 4, x.lvl('Q2'), x.lvl('DR'), x.lvl('c2')),
           x.tmp('c3', wbin(P, 'add', x.lvl('c2'), x.lvl('L2')))]
    st += vpart('3')
    eds.append(('''
lv 0:3:10 10 1
cf 0:3:13 4 #4014000000000000
lv 0:3:18 10 1
row 0:3:10 10 3
arr 0:3:9 10 1
''', cat(xblk(P, st, x.lvl('RES')))))
    # ---- line 6: [M, M], one row of matrices
    P = '0:6:9'
    x = Ctx(F, P, 'w')
    st = [x.tmp('Q1', lv('0:6:10', 11, 3)),
          x.tmp('Q2', lv('0:6:13', 11, 3)),
          x.tmp('R1', ext(P, 0, x.lvl('Q1'))),                    # (Rr, Cr) = the first part's
          x.tmp('C1', ext(P, 1, x.lvl('Q1'))),
          x.tmp('R2', ext(P, 0, x.lvl('Q2'))),                    # the second part's, checked
          x.tmp('C2', ext(P, 1, x.lvl('Q2'))),
          x.tmp('S', bin_(P, 2, 'ne', x.lvl('R1'), x.lvl('R2'))),
          x.mchk('SHAPE_MISMATCH', 'S', 'R1', 'C1', 'R2', 'C2'),
          x.tmp('Cr', wbin(P, 'add', x.lvl('C1'), x.lvl('C2'))),
          x.tmp('RES', anew(P, 11, 0, [x.lvl('R1'), x.lvl('Cr')])),   # a single row: Rr, Cr
          x.tmp('DR', adat(P, 12, x.lvl('RES'))),
          x.tmp('r0', ci(P, 0))]

    def mpart(k):
        def body():
            src = eld(P, 4, x.lvl('Dq' + k), x.lin(x.klv('I' + k), x.klv('J' + k), x.lvl('R' + k)))
            dst = wbin(P, 'add', wbin(P, 'add', x.lvl('r0'), x.klv('I' + k)),
                       wbin(P, 'mul', wbin(P, 'add', x.lvl('c' + k), x.klv('J' + k)), x.lvl('R1')))
            return [est(P, 4, src, x.lvl('DR'), dst)]
        return [x.tmp('Dq' + k, adat(P, 12, x.lvl('Q' + k)))] + x.loop(
            'C' + k, 'Zj' + k, 'Oj' + k, 'Lj' + k, 'J' + k, lambda: x.loop(
                'R' + k, 'Zi' + k, 'Oi' + k, 'Li' + k, 'I' + k, body))
    st.append(x.tmp('c1', ci(P, 0)))
    st += mpart('1')
    st.append(x.tmp('c2', wbin(P, 'add', x.lvl('c1'), x.lvl('C1'))))
    st += mpart('2')
    eds.append(('''
lv 0:6:10 11 3
lv 0:6:13 11 3
row 0:6:10 11 2
arr 0:6:9 11 1
''', cat(xblk(P, st, x.lvl('RES')))))
    eds.append((['lv 0:7:44 10 2', 'lib 0:7:40 3 len 1'], cat(L3('0:7:40', 0, lv('0:7:44', 10, 2)))))
    eds.append((['lv 0:7:62 11 4', 'lib 0:7:57 3 cols 1'], cat(L3('0:7:57', 1, lv('0:7:62', 11, 4)))))
    return make_hirl(HIR1['arr_lit_cat'], ['tptr 12 4'], {1: (F, eds)})


HIRL['arr_lit_cat'] = hirl_arr_lit_cat
# sea.lir1. Line 3 (rule 26 (c)): the parts (a borrowed twice: no instruction; the scalar `lf`),
# the lengths joined by iadd from the first part's (the scalar `li 1`), no check, arrnew of the
# sum, data; each part at its offset: a's elements by a loop (read at I, stored at c0 + I), the
# scalar by one store, a again from the offset c0 + L1 + 1. Line 6: the extents of both parts,
# the row check (icmp ne, chk), the joined columns (iadd), arrnew of R1 x (C1 + C2), data, the row
# offset r0 and each part's column offset, each part by loop(C; J) around loop(R; I): read at
# I + J*Rq, stored at (r0 + I) + (c0 + J)*Rs. No part is owned: nothing is released after the
# copies. Line 7: the printf slot of 40 bytes. W, M, v, a released at the end.
LIR1['arr_lit_cat'] = '''
func .main main 0:1:1 0 0
slot s1 40 8
li i.Ra 2
li i.eka 1
li i.rka 1
li i.ca 1
rcall sea_arr_new_u 0:1 1 p.a 4 i.eka i.rka i.Ra i.ca
lf f.Va #3FF0000000000000
ldp p.Da p.a - 0 40
li i.Za 0
icmp gt i.ga i.Ra i.Za
if 1 i.ga
li i.Oa 1
isub i.La i.Ra i.Oa
loop 2 i.Ka i.Za i.La i.Oa
stf f.Va p.Da i.Ka 8 0
endloop 2
endif 1
lf f.v2 #4008000000000000
li i.x2 1
ldi i.e2 p.a - 0 16
chkb i.x2 i.e2 0 0:2
ldi i.rc2 p.a - 0 0
li i.o2 1
icmp ne i.s2 i.rc2 i.o2
if 3 i.s2
rcall sea_arr_unique 0:2 1 p.u2 1 p.a
mov p.a p.u2
endif 3
ldp p.d2 p.a - 0 40
stf f.v2 p.d2 i.x2 8 0
lf f.Q2 #4014000000000000
ldi i.L1 p.a - 0 16
li i.L2 1
iadd i.N2 i.L1 i.L2
ldi i.L3 p.a - 0 16
iadd i.N3 i.N2 i.L3
li i.ekv 1
li i.rkv 1
li i.cv 1
rcall sea_arr_new_u 0:3 1 p.v 4 i.ekv i.rkv i.N3 i.cv
ldp p.DR p.v - 0 40
li i.c1 0
ldp p.Dq1 p.a - 0 40
li i.Z1 0
icmp gt i.g1 i.L1 i.Z1
if 4 i.g1
li i.O1 1
isub i.M1 i.L1 i.O1
loop 5 i.I1 i.Z1 i.M1 i.O1
ldf f.e1 p.Dq1 i.I1 8 0
iadd i.y1 i.c1 i.I1
stf f.e1 p.DR i.y1 8 0
endloop 5
endif 4
iadd i.c2 i.c1 i.L1
stf f.Q2 p.DR i.c2 8 0
iadd i.c3 i.c2 i.L2
ldp p.Dq3 p.a - 0 40
li i.Z3 0
icmp gt i.g3 i.L3 i.Z3
if 6 i.g3
li i.O3 1
isub i.M3 i.L3 i.O3
loop 7 i.I3 i.Z3 i.M3 i.O3
ldf f.e3 p.Dq3 i.I3 8 0
iadd i.y3 i.c3 i.I3
stf f.e3 p.DR i.y3 8 0
endloop 7
endif 6
li i.Ro 2
li i.Co 1
li i.eko 1
li i.rko 2
rcall sea_arr_new_u 0:4 1 p.M 4 i.eko i.rko i.Ro i.Co
imul i.No i.Ro i.Co
lf f.Vo #3FF0000000000000
ldp p.Do p.M - 0 40
li i.Zo 0
icmp gt i.go i.No i.Zo
if 8 i.go
li i.Oo 1
isub i.Lo i.No i.Oo
loop 9 i.Ko i.Zo i.Lo i.Oo
stf f.Vo p.Do i.Ko 8 0
endloop 9
endif 8
lf f.v5 #4000000000000000
li i.i5 1
li i.j5 0
ldi i.r5 p.M - 0 16
chkb i.i5 i.r5 0 0:5
ldi i.k5 p.M - 0 24
chkb i.j5 i.k5 1 0:5
ldi i.rc5 p.M - 0 0
li i.o5 1
icmp ne i.s5 i.rc5 i.o5
if 10 i.s5
rcall sea_arr_unique 0:5 1 p.u5 1 p.M
mov p.M p.u5
endif 10
ldp p.d5 p.M - 0 40
imul i.t5 i.j5 i.r5
iadd i.p5 i.i5 i.t5
stf f.v5 p.d5 i.p5 8 0
ldi i.R1 p.M - 0 16
ldi i.C1 p.M - 0 24
ldi i.R2 p.M - 0 16
ldi i.C2 p.M - 0 24
icmp ne i.S i.R1 i.R2
chk i.S SHAPE_MISMATCH 0:6 4 i.R1 i.C1 i.R2 i.C2
iadd i.Cr i.C1 i.C2
li i.ekw 1
li i.rkw 2
rcall sea_arr_new_u 0:6 1 p.W 4 i.ekw i.rkw i.R1 i.Cr
ldp p.DW p.W - 0 40
li i.r0 0
li i.w1 0
ldp p.Dw1 p.M - 0 40
li i.Zj1 0
icmp gt i.gj1 i.C1 i.Zj1
if 11 i.gj1
li i.Oj1 1
isub i.Lj1 i.C1 i.Oj1
loop 12 i.J1 i.Zj1 i.Lj1 i.Oj1
li i.Zi1 0
icmp gt i.gi1 i.R1 i.Zi1
if 13 i.gi1
li i.Oi1 1
isub i.Li1 i.R1 i.Oi1
loop 14 i.I1w i.Zi1 i.Li1 i.Oi1
imul i.t1 i.J1 i.R1
iadd i.x1 i.I1w i.t1
ldf f.w1 p.Dw1 i.x1 8 0
iadd i.a1 i.r0 i.I1w
iadd i.b1 i.w1 i.J1
imul i.m1 i.b1 i.R1
iadd i.y1w i.a1 i.m1
stf f.w1 p.DW i.y1w 8 0
endloop 14
endif 13
endloop 12
endif 11
iadd i.w2 i.w1 i.C1
ldp p.Dw2 p.M - 0 40
li i.Zj2 0
icmp gt i.gj2 i.C2 i.Zj2
if 15 i.gj2
li i.Oj2 1
isub i.Lj2 i.C2 i.Oj2
loop 16 i.J2 i.Zj2 i.Lj2 i.Oj2
li i.Zi2 0
icmp gt i.gi2 i.R2 i.Zi2
if 17 i.gi2
li i.Oi2 1
isub i.Li2 i.R2 i.Oi2
loop 18 i.I2 i.Zi2 i.Li2 i.Oi2
imul i.t2 i.J2 i.R2
iadd i.x2w i.I2 i.t2
ldf f.w2 p.Dw2 i.x2w 8 0
iadd i.a2 i.r0 i.I2
iadd i.b2 i.w2 i.J2
imul i.m2 i.b2 i.R1
iadd i.y2 i.a2 i.m2
stf f.w2 p.DW i.y2 8 0
endloop 18
endif 17
endloop 16
endif 15
li i.k71 2
ldi i.e71 p.v - 0 16
chkb i.k71 i.e71 0 0:7
ldp p.d71 p.v - 0 40
ldf f.r71 p.d71 i.k71 8 0
li i.k72 4
ldi i.e72 p.v - 0 16
chkb i.k72 i.e72 0 0:7
ldp p.d72 p.v - 0 40
ldf f.r72 p.d72 i.k72 8 0
ldi i.n73 p.v - 0 16
li i.i74 1
li i.j74 1
ldi i.r74 p.W - 0 16
chkb i.i74 i.r74 0 0:7
ldi i.c74 p.W - 0 24
chkb i.j74 i.c74 1 0:7
ldp p.d74 p.W - 0 40
imul i.t74 i.j74 i.r74
iadd i.p74 i.i74 i.t74
ldf f.r74 p.d74 i.p74 8 0
ldi i.n75 p.W - 0 24
sa p.s s1
stf f.r71 p.s - 0 0
stf f.r72 p.s - 0 8
sti i.n73 p.s - 0 16
stf f.r74 p.s - 0 24
sti i.n75 p.s - 0 32
la p.f d1
rcall sea_printf 0:7 0 2 p.f p.s
release p.W
release p.M
release p.v
release p.a
ret 0
endfunc
fmt d1 10
fconv - - - g f
ftext %20
fconv - - - g f
ftext %20
fconv - - - d i
ftext %20
fconv - - - g f
ftext %20
fconv - - - d i
ftext %0A
'''
# a = [1, 3]: v = [1, 3, 5, 1, 3] (v[2] = 5, v[4] = 3, length 5); M = [1; 2]: W = [1 1; 2 2]
# (W[1, 1] = 2, 2 columns).
OUT['arr_lit_cat'] = '5 3 5 2 2\n'
NAMES.append('arr_lit_cat')

# ================================================================ arr_views (rule 28 materialized / L10)
SEA['arr_views'] = '''var A = zeros(2, 3)
A[1, 0] = 4.0
let B = A.T
let f = A.flat
printf("%g %d %g %d\\n", B[0, 1], rows(B), f[1], len(f))
// arr_views -- DESIGN.md 3.5.9 L10 (rule 28 materialized): .T copies by the loop nest (operand
// element (J, I) to result element (I, J)), .flat copies the bytes (mcpy)
'''
AST['arr_views'] = '''
pname 0:1:5 A
name 0:1:9 zeros
int 0:1:15 2
int 0:1:18 3
call 0:1:9 2
var 0:1:1 0
name 0:2:1 A
int 0:2:3 1
int 0:2:6 0
index 0:2:1 2
float 0:2:11 #4010000000000000
asg 0:2:1 set
pname 0:3:5 B
name 0:3:9 A
dot 0:3:9 T
let 0:3:1 0
pname 0:4:5 f
name 0:4:9 A
dot 0:4:9 flat
let 0:4:1 0
name 0:5:1 printf
str 0:5:8 %25g%20%25d%20%25g%20%25d%0A
name 0:5:25 B
int 0:5:27 0
int 0:5:30 1
index 0:5:25 2
name 0:5:34 rows
name 0:5:39 B
call 0:5:34 1
name 0:5:43 f
int 0:5:45 1
index 0:5:43 1
name 0:5:49 len
name 0:5:53 f
call 0:5:49 1
call 0:5:1 5
cstmt 0:5:1
prog 5
'''
# sea.hir1: f64[,] 10 (`loc A`, and B and A.T), f64[] 11 (`loc f`, A.flat).
HIR1['arr_views'] = '''
tmat 10 4
tvec 11 4
fn 1 .main main 1 0 3 0:1:1
loc A 10 var 0:1:5
loc B 10 let 0:3:5
loc f 11 let 0:4:5
ci 0:1:15 3 2
ci 0:1:18 3 3
lib 0:1:9 10 zeros 2
bind 0:1:1 1
lv 0:2:1 10 1
ci 0:2:3 3 1
ci 0:2:6 3 0
idx 0:2:1 4 2
cf 0:2:11 4 #4010000000000000
asg 0:2:1 set
lv 0:3:9 10 1
view 0:3:9 10 T
bind 0:3:1 2
lv 0:4:9 10 1
view 0:4:9 11 flat
bind 0:4:1 3
lv 0:5:25 10 2
ci 0:5:27 3 0
ci 0:5:30 3 1
idx 0:5:25 4 2
fconv 0:5:8 1 - - - g
ftext 0:5:8 1 %20
lv 0:5:39 10 2
lib 0:5:34 3 rows 1
fconv 0:5:8 1 - - - d
ftext 0:5:8 1 %20
lv 0:5:43 11 3
ci 0:5:45 3 1
idx 0:5:43 4 1
fconv 0:5:8 1 - - - g
ftext 0:5:8 1 %20
lv 0:5:53 11 3
lib 0:5:49 3 len 1
fconv 0:5:8 1 - - - d
ftext 0:5:8 1 %0A
fmt 0:5:8 1 8
lib 0:5:1 1 printf 1
eval 0:5:1
block 0:1:1 5
end
'''


def hirl_arr_views():
    """sea.hirl: tptr 12 4 (the adat of A.T's result). zeros is L1; line 3 is L10 of .T, line 4
    L10 of .flat; rows and len L3."""
    F = Fn()
    eds = [(['ci 0:1:15 3 2', 'ci 0:1:18 3 3', 'lib 0:1:9 10 zeros 2'],
            cat(L1('0:1:9', 10, [ci('0:1:15', 2), ci('0:1:18', 3)])))]
    P = '0:3:9'
    x = Ctx(F, P, 't')
    st = [x.tmp('A', lv('0:3:9', 10, 1)),
          x.tmp('R', ext(P, 1, x.lvl('A'))),
          x.tmp('C', ext(P, 0, x.lvl('A'))),
          x.tmp('V', anew(P, 10, 0, [x.lvl('R'), x.lvl('C')])),
          x.tmp('DV', adat(P, 12, x.lvl('V'))),
          x.tmp('DA', adat(P, 12, x.lvl('A')))]

    def body():
        return [est(P, 4, eld(P, 4, x.lvl('DA'), x.lin(x.klv('J'), x.klv('I'), x.lvl('C'))),
                    x.lvl('DV'), x.lin(x.klv('I'), x.klv('J'), x.lvl('R')))]
    st += x.loop('C', 'Zj', 'Oj', 'Lj', 'J', lambda: x.loop('R', 'Zi', 'Oi', 'Li', 'I', body))
    eds.append((['lv 0:3:9 10 1', 'view 0:3:9 10 T'], cat(xblk(P, st, x.lvl('V')))))
    P = '0:4:9'
    x = Ctx(F, P, 'f')
    st = [x.tmp('A', lv('0:4:9', 10, 1)),
          x.tmp('R', ext(P, 0, x.lvl('A'))),
          x.tmp('C', ext(P, 1, x.lvl('A'))),
          x.tmp('N', wbin(P, 'mul', x.lvl('R'), x.lvl('C'))),
          x.tmp('V', anew(P, 11, 0, [x.lvl('N')])),
          x.tmp('D', adat(P, 12, x.lvl('V'))),
          x.tmp('S', adat(P, 12, x.lvl('A'))),
          x.tmp('NB', wbin(P, 'mul', x.lvl('N'), ci(P, ES[4]))),
          mcpy(P, x.lvl('D'), x.lvl('S'), x.lvl('NB'))]
    eds.append((['lv 0:4:9 10 1', 'view 0:4:9 11 flat'], cat(xblk(P, st, x.lvl('V')))))
    eds.append((['lv 0:5:39 10 2', 'lib 0:5:34 3 rows 1'], cat(L3('0:5:34', 0, lv('0:5:39', 10, 2)))))
    eds.append((['lv 0:5:53 11 3', 'lib 0:5:49 3 len 1'], cat(L3('0:5:49', 0, lv('0:5:53', 11, 3)))))
    return make_hirl(HIR1['arr_views'], ['tptr 12 4'], {1: (F, eds)})


HIRL['arr_views'] = hirl_arr_views
# sea.lir1. zeros(2, 3) (arrnewz), A[1, 0] = 4.0 (rule 19). Line 3, A.T materialized (rule 28): the
# extents swapped (cols as the result's rows), arrnew into B (T3), data of B and of A, loop(C; J)
# around loop(R; I) reading A at J + I*C and storing at I + J*R. Line 4, A.flat: rows, cols,
# their product, arrnew into f, data of both, the byte count (`li 8`, imul), mcopy. Line 5: the
# printf slot of 32 bytes; f, B, A released at the end.
LIR1['arr_views'] = '''
func .main main 0:1:1 0 0
slot s1 32 8
li i.r1 2
li i.c1 3
li i.ek1 1
li i.rk1 2
rcall sea_arr_new 0:1 1 p.A 4 i.ek1 i.rk1 i.r1 i.c1
lf f.v2 #4010000000000000
li i.i2 1
li i.j2 0
ldi i.e02 p.A - 0 16
chkb i.i2 i.e02 0 0:2
ldi i.e12 p.A - 0 24
chkb i.j2 i.e12 1 0:2
ldi i.rc2 p.A - 0 0
li i.o2 1
icmp ne i.s2 i.rc2 i.o2
if 1 i.s2
rcall sea_arr_unique 0:2 1 p.u2 1 p.A
mov p.A p.u2
endif 1
ldp p.d2 p.A - 0 40
imul i.t2 i.j2 i.e02
iadd i.x2 i.i2 i.t2
stf f.v2 p.d2 i.x2 8 0
ldi i.R3 p.A - 0 24
ldi i.C3 p.A - 0 16
li i.ek3 1
li i.rk3 2
rcall sea_arr_new_u 0:3 1 p.B 4 i.ek3 i.rk3 i.R3 i.C3
ldp p.DV p.B - 0 40
ldp p.DA p.A - 0 40
li i.Zj 0
icmp gt i.gj i.C3 i.Zj
if 2 i.gj
li i.Oj 1
isub i.Lj i.C3 i.Oj
loop 3 i.J i.Zj i.Lj i.Oj
li i.Zi 0
icmp gt i.gi i.R3 i.Zi
if 4 i.gi
li i.Oi 1
isub i.Li i.R3 i.Oi
loop 5 i.I i.Zi i.Li i.Oi
imul i.ta i.I i.C3
iadd i.xa i.J i.ta
ldf f.e p.DA i.xa 8 0
imul i.tb i.J i.R3
iadd i.yb i.I i.tb
stf f.e p.DV i.yb 8 0
endloop 5
endif 4
endloop 3
endif 2
ldi i.R4 p.A - 0 16
ldi i.C4 p.A - 0 24
imul i.N4 i.R4 i.C4
li i.ek4 1
li i.rk4 1
li i.c4 1
rcall sea_arr_new_u 0:4 1 p.f 4 i.ek4 i.rk4 i.N4 i.c4
ldp p.D4 p.f - 0 40
ldp p.S4 p.A - 0 40
li i.s4 8
imul i.NB4 i.N4 i.s4
mcopy p.D4 p.S4 i.NB4
li i.i5 0
li i.j5 1
ldi i.r5 p.B - 0 16
chkb i.i5 i.r5 0 0:5
ldi i.c5 p.B - 0 24
chkb i.j5 i.c5 1 0:5
ldp p.d5 p.B - 0 40
imul i.t5 i.j5 i.r5
iadd i.p5 i.i5 i.t5
ldf f.b5 p.d5 i.p5 8 0
ldi i.rows p.B - 0 16
li i.k6 1
ldi i.e6 p.f - 0 16
chkb i.k6 i.e6 0 0:5
ldp p.d6 p.f - 0 40
ldf f.f6 p.d6 i.k6 8 0
ldi i.len p.f - 0 16
sa p.s s1
stf f.b5 p.s - 0 0
sti i.rows p.s - 0 8
stf f.f6 p.s - 0 16
sti i.len p.s - 0 24
la p.fm d1
rcall sea_printf 0:5 0 2 p.fm p.s
release p.f
release p.B
release p.A
ret 0
endfunc
fmt d1 8
fconv - - - g f
ftext %20
fconv - - - d i
ftext %20
fconv - - - g f
ftext %20
fconv - - - d i
ftext %0A
'''
# A = [0 0 0; 4 0 0]: B = A.T is 3 x 2 with B[0, 1] = A[1, 0] = 4; f = A.flat = [0, 4, 0, 0, 0, 0].
OUT['arr_views'] = '4 3 4 6\n'
NAMES.append('arr_views')

# ================================================================ arr_dynfix (rule 27 (i), (j) / L10)
SEA['arr_dynfix'] = '''let f = [1.5, 2.5]
let d: f64[] = f
let g: f64[2] = d
printf("%g %g %d\\n", d[1], g[0], len(d))
// arr_dynfix -- DESIGN.md 3.5.9 L10 (rule 27 (i), (j)): the implicit dyn of a fixed-size value
// bound to a dynamic local (line 2) and the implicit fix of a dynamic value bound to a
// fixed-size local (line 3, with its SHAPE_EXPECTED check)
'''
AST['arr_dynfix'] = '''
pname 0:1:5 f
float 0:1:10 #3FF8000000000000
float 0:1:15 #4004000000000000
row 0:1:10 2
array 0:1:9 1
let 0:1:1 0
pname 0:2:5 d
type 0:2:8 f64 v 0
name 0:2:16 f
let 0:2:1 1
pname 0:3:5 g
int 0:3:12 2
type 0:3:8 f64 fv 1
name 0:3:17 d
let 0:3:1 1
name 0:4:1 printf
str 0:4:8 %25g%20%25g%20%25d%0A
name 0:4:22 d
int 0:4:24 1
index 0:4:22 1
name 0:4:28 g
int 0:4:30 0
index 0:4:28 1
name 0:4:34 len
name 0:4:38 d
call 0:4:34 1
call 0:4:1 4
cstmt 0:4:1
prog 4
'''
# sea.hir1: f64[2] 10 (`loc f`, also g), f64[] 11 (`loc d`). seacheck writes the implicit `dyn`
# (line 2) and `fix` (line 3) at the position of the operand they convert (3.5.5).
HIR1['arr_dynfix'] = '''
tfvec 10 4 2
tvec 11 4
fn 1 .main main 1 0 3 0:1:1
loc f 10 let 0:1:5
loc d 11 let 0:2:5
loc g 10 let 0:3:5
cf 0:1:10 4 #3FF8000000000000
cf 0:1:15 4 #4004000000000000
row 0:1:10 10 2
arr 0:1:9 10 1
bind 0:1:1 1
lv 0:2:16 10 1
dyn 0:2:16 11
bind 0:2:1 2
lv 0:3:17 11 2
fix 0:3:17 10
bind 0:3:1 3
lv 0:4:22 11 2
ci 0:4:24 3 1
idx 0:4:22 4 1
fconv 0:4:8 1 - - - g
ftext 0:4:8 1 %20
lv 0:4:28 10 3
ci 0:4:30 3 0
idx 0:4:28 4 1
fconv 0:4:8 1 - - - g
ftext 0:4:8 1 %20
lv 0:4:38 11 2
lib 0:4:34 3 len 1
fconv 0:4:8 1 - - - d
ftext 0:4:8 1 %0A
fmt 0:4:8 1 6
lib 0:4:1 1 printf 1
eval 0:4:1
block 0:1:1 4
end
'''


def hirl_arr_dynfix():
    """sea.hirl: tptr 12 4 (the adat of the literal's home). Line 1 is L9 (a); line 2 L10's dyn
    (`tmp S = lv f`, its static extent, anew, data, `ci 16`, mcpy from data(S)); line 3 L10's fix
    of a vector (the extent, `ci 2`, the comparison, vchk(SHAPE_EXPECTED; S, En, R), the home,
    data, `ci 16`, mcpy into data(H)); len L3."""
    F = Fn()
    eds = [('''
cf 0:1:10 4 #3FF8000000000000
cf 0:1:15 4 #4004000000000000
row 0:1:10 10 2
arr 0:1:9 10 1
''', cat(L9a(F, '0:1:9', 10, 4, 12, 'l', [((0, 0), cf('0:1:10', '#3FF8000000000000')),
                                          ((0, 1), cf('0:1:15', '#4004000000000000'))], 1)))]
    P = '0:2:16'
    x = Ctx(F, P, 'd')
    st = [x.tmp('S', lv('0:2:16', 10, 1)),
          x.tmp('R', ext(P, 0, x.lvl('S'))),
          x.tmp('A', anew(P, 11, 0, [x.lvl('R')])),
          x.tmp('D', adat(P, 12, x.lvl('A'))),
          x.tmp('N', ci(P, 16)),
          mcpy(P, x.lvl('D'), adat(P, 12, x.lvl('S')), x.lvl('N'))]
    eds.append((['lv 0:2:16 10 1', 'dyn 0:2:16 11'], cat(xblk(P, st, x.lvl('A')))))
    P = '0:3:17'
    x = Ctx(F, P, 'f')
    st = [x.tmp('A', lv('0:3:17', 11, 2)),
          x.tmp('R', ext(P, 0, x.lvl('A'))),
          x.tmp('En', ci(P, 2)),
          x.tmp('S', bin_(P, 2, 'ne', x.lvl('R'), x.lvl('En')))]
    st += x.vchk('SHAPE_EXPECTED', 'S', 'En', 'R', 'V')
    st += [x.tmp('H', anew(P, 10, 0, [])),
           x.tmp('D', adat(P, 12, x.lvl('A'))),
           x.tmp('N', ci(P, 16)),
           mcpy(P, adat(P, 12, x.lvl('H')), x.lvl('D'), x.lvl('N'))]
    eds.append((['lv 0:3:17 11 2', 'fix 0:3:17 10'], cat(xblk(P, st, x.lvl('H')))))
    eds.append((['lv 0:4:38 11 2', 'lib 0:4:34 3 len 1'], cat(L3('0:4:34', 0, lv('0:4:38', 11, 2)))))
    return make_hirl(HIR1['arr_dynfix'], ['tptr 12 4'], {1: (F, eds)})


HIRL['arr_dynfix'] = hirl_arr_dynfix
# sea.lir1. Line 1: f's slot s1, the literal's home s2 and its stores, the copy (rule 27 (b)).
# Line 2, dyn (rule 27 (i)): the static extent `li 2`, arrnew into d, data, `li 16`, mcopy from f's
# home. Line 3: g's slot s3 first (rule 27 (b)), then the fix (rule 27 (j)): ext(d, 0), `li 2`,
# icmp ne, `li V -1`, chk SHAPE_EXPECTED (expected 2, got the extent), the home slot s4, data(d),
# `li 16`, mcopy into the home; then the copy into g. Line 4: d[1] (dynamic), g[0] (the extent `li
# 2`, the home address), len(d), the printf slot s5 of 24 bytes. Only d is released.
LIR1['arr_dynfix'] = '''
func .main main 0:1:1 0 0
slot s1 16 8
slot s2 16 8
slot s3 16 8
slot s4 16 8
slot s5 24 8
sa p.f s1
sa p.H1 s2
lf f.a #3FF8000000000000
stf f.a p.H1 - 0 0
lf f.b #4004000000000000
stf f.b p.H1 - 0 8
li i.n1 16
mcopy p.f p.H1 i.n1
li i.R2 2
li i.ek2 1
li i.rk2 1
li i.c2 1
rcall sea_arr_new_u 0:2 1 p.d 4 i.ek2 i.rk2 i.R2 i.c2
ldp p.D2 p.d - 0 40
li i.N2 16
mcopy p.D2 p.f i.N2
sa p.g s3
ldi i.R3 p.d - 0 16
li i.En 2
icmp ne i.S i.R3 i.En
li i.V -1
chk i.S SHAPE_EXPECTED 0:3 4 i.En i.V i.R3 i.V
sa p.H3 s4
ldp p.D3 p.d - 0 40
li i.N3 16
mcopy p.H3 p.D3 i.N3
li i.n3 16
mcopy p.g p.H3 i.n3
li i.k4 1
ldi i.e4 p.d - 0 16
chkb i.k4 i.e4 0 0:4
ldp p.d4 p.d - 0 40
ldf f.x4 p.d4 i.k4 8 0
li i.k5 0
li i.e5 2
chkb i.k5 i.e5 0 0:4
ldf f.x5 p.g i.k5 8 0
ldi i.len p.d - 0 16
sa p.s s5
stf f.x4 p.s - 0 0
stf f.x5 p.s - 0 8
sti i.len p.s - 0 16
la p.fm d1
rcall sea_printf 0:4 0 2 p.fm p.s
release p.d
ret 0
endfunc
fmt d1 6
fconv - - - g f
ftext %20
fconv - - - g f
ftext %20
fconv - - - d i
ftext %0A
'''
# d = [1.5, 2.5] (a heap copy), g = [1.5, 2.5] (checked: 2 elements).
OUT['arr_dynfix'] = '2.5 1.5 2\n'
NAMES.append('arr_dynfix')

# ================================================================ arr_fixed (rule 27, fixed-size arrays in memory)
SEA['arr_fixed'] = '''fn mk(a: f64) -> f64[2] {
    var r = [a, a]
    for k in 0..2 {
        r[k] = r[k] + 1.0
    }
    return r
}
let p = mk(1.5)
let q = mk(0.5)
printf("%g %g\\n", p[1], q[0])
// arr_fixed -- DESIGN.md 3.6.6 rule 27 (fixed-size arrays in memory, Decision 32): a fixed-size
// var local (its home slot) with element reads and writes (rules 18, 19 on a fixed-size base:
// static extents, no copy on write), and a fixed-size result written through the hidden result
// address, which the caller's bind passes as its local's slot
'''
AST['arr_fixed'] = '''
type 0:1:10 f64 s 0
param 0:1:7 a 0 0
int 0:1:22 2
type 0:1:18 f64 fv 1
pname 0:2:9 r
name 0:2:14 a
name 0:2:17 a
row 0:2:14 2
array 0:2:13 1
var 0:2:5 0
int 0:3:14 0
int 0:3:17 2
range 0:3:14 0 0
name 0:4:9 r
name 0:4:11 k
index 0:4:9 1
name 0:4:16 r
name 0:4:18 k
index 0:4:16 1
float 0:4:23 #3FF0000000000000
bin 0:4:16 add
asg 0:4:9 set
block 0:3:19 1
for 0:3:5 k 0:3:9
name 0:6:12 r
return 0:6:5 1
block 0:1:25 3
fn 0:1:1 mk 0 1 1
pname 0:8:5 p
name 0:8:9 mk
float 0:8:12 #3FF8000000000000
call 0:8:9 1
let 0:8:1 0
pname 0:9:5 q
name 0:9:9 mk
float 0:9:12 #3FE0000000000000
call 0:9:9 1
let 0:9:1 0
name 0:10:1 printf
str 0:10:8 %25g%20%25g%0A
name 0:10:19 p
int 0:10:21 1
index 0:10:19 1
name 0:10:25 q
int 0:10:27 0
index 0:10:25 1
call 0:10:1 3
cstmt 0:10:1
prog 4
'''
# sea.hir1: f64[2] 10 (`loc p`; mk's result, `loc r`, the literal and its row), i64[] 11 (the rng
# of the for in mk).
HIR1['arr_fixed'] = '''
tfvec 10 4 2
tvec 11 3
fn 1 .main main 1 0 2 0:1:1
loc p 10 let 0:8:5
loc q 10 let 0:9:5
cf 0:8:12 4 #3FF8000000000000
call 0:8:9 10 2 1
bind 0:8:1 1
cf 0:9:12 4 #3FE0000000000000
call 0:9:9 10 2 1
bind 0:9:1 2
lv 0:10:19 10 1
ci 0:10:21 3 1
idx 0:10:19 4 1
fconv 0:10:8 1 - - - g
ftext 0:10:8 1 %20
lv 0:10:25 10 2
ci 0:10:27 3 0
idx 0:10:25 4 1
fconv 0:10:8 1 - - - g
ftext 0:10:8 1 %0A
fmt 0:10:8 1 4
lib 0:10:1 1 printf 1
eval 0:10:1
block 0:1:1 3
end
fn 2 mk fn 10 1 2 0:1:1
par a 4 val
loc r 10 var 0:2:9
loc k 3 for 0:3:9
lv 0:2:14 4 1
lv 0:2:17 4 1
row 0:2:14 10 2
arr 0:2:13 10 1
bind 0:2:5 2
ci 0:3:14 3 0
ci 0:3:17 3 2
rng 0:3:14 11 0 0
lv 0:4:9 10 2
lv 0:4:11 3 3
idx 0:4:9 4 1
lv 0:4:16 10 2
lv 0:4:18 3 3
idx 0:4:16 4 1
cf 0:4:23 4 #3FF0000000000000
bin 0:4:16 4 add
asg 0:4:9 set
block 0:3:19 1
forr 0:3:5 3
lv 0:6:12 10 2
ret 0:6:5 1
block 0:1:25 3
end
'''


def hirl_arr_fixed():
    """sea.hirl: tptr 12 4 (the adat of mk's literal). .main holds no rewritten construct (written
    as in sea.hir); in mk the literal [a, a] is L9 (a). The element read and store of line 4 are
    rules 18 and 19 in sealower (scalar indices, no rewrite)."""
    F = Fn()
    lit = ('''
lv 0:2:14 4 1
lv 0:2:17 4 1
row 0:2:14 10 2
arr 0:2:13 10 1
''', cat(L9a(F, '0:2:13', 10, 4, 12, 'l', [((0, 0), lv('0:2:14', 4, 1)),
                                           ((0, 1), lv('0:2:17', 4, 1))], 1)))
    return make_hirl(HIR1['arr_fixed'], ['tptr 12 4'], {2: (F, [lit])})


HIRL['arr_fixed'] = hirl_arr_fixed
# sea.lir1. .main: each bind of a fixed-size local passes its slot as mk's hidden result address
# (rule 27 (b), (l); 3.6.3: the address in front of the other arguments, no register result);
# p[1] and q[0] read from the homes with the static extent `li 2` (rule 18); the printf slot s3.
# No local holds counts: nothing is released. mk: the hidden address p1, then a; r's slot s1 and
# the literal's home s2 (a stored twice from its register, R3), copied into r (rule 27 (b), (c));
# the for loop; r[k] = r[k] + 1.0: the read (the check against `li 2`, the load from r's home),
# the fadd, the store's check and the store (rule 19: no copy on write for a fixed-size base);
# `return r` copies r into the hidden address (rule 27 (h), (c)), then ret with no register.
LIR1['arr_fixed'] = '''
func .main main 0:1:1 0 0
slot s1 16 8
slot s2 16 8
slot s3 16 8
sa p.p s1
lf f.c1 #3FF8000000000000
call mk 0 2 p.p f.c1
sa p.q s2
lf f.c2 #3FE0000000000000
call mk 0 2 p.q f.c2
li i.k1 1
li i.e1 2
chkb i.k1 i.e1 0 0:10
ldf f.x1 p.p i.k1 8 0
li i.k2 0
li i.e2 2
chkb i.k2 i.e2 0 0:10
ldf f.x2 p.q i.k2 8 0
sa p.s s3
stf f.x1 p.s - 0 0
stf f.x2 p.s - 0 8
la p.f d1
rcall sea_printf 0:10 0 2 p.f p.s
ret 0
endfunc
func mk fn 0:1:1 2 p.res f.a 0
slot s1 16 8
slot s2 16 8
sa p.r s1
sa p.H s2
stf f.a p.H - 0 0
stf f.a p.H - 0 8
li i.n 16
mcopy p.r p.H i.n
li i.lo 0
li i.hi 2
li i.st 1
rcount i.C i.E i.lo i.hi i.st 0 0:3
if 1 i.E
loop 2 i.k i.lo i.C i.st
li i.e1 2
chkb i.k i.e1 0 0:4
ldf f.x p.r i.k 8 0
lf f.one #3FF0000000000000
fadd f.s f.x f.one
li i.e2 2
chkb i.k i.e2 0 0:4
stf f.s p.r i.k 8 0
endloop 2
endif 1
li i.nr 16
mcopy p.res p.r i.nr
ret 0
endfunc
fmt d1 4
fconv - - - g f
ftext %20
fconv - - - g f
ftext %0A
'''
# mk(1.5) = [2.5, 2.5], mk(0.5) = [1.5, 1.5].
OUT['arr_fixed'] = '2.5 1.5\n'
NAMES.append('arr_fixed')

# ================================================================ ew_ind2sub (Decision 33 / L11)
SEA['ew_ind2sub'] = '''var k = filled(7, 2)
k[1] = 2
let (i, j) = ind2sub(3, k)
printf("%d %d %d %d\\n", i[0], i[1], j[0], j[1])
// ew_ind2sub -- DESIGN.md 3.5.9 L11 (Decision 33): ind2sub of a scalar r and a vector k is two
// element-wise loops over held arguments, k % r and then idiv(k, r), in place of the tbind
'''
AST['ew_ind2sub'] = '''
pname 0:1:5 k
name 0:1:9 filled
int 0:1:16 7
int 0:1:19 2
call 0:1:9 2
var 0:1:1 0
name 0:2:1 k
int 0:2:3 1
index 0:2:1 1
int 0:2:8 2
asg 0:2:1 set
pname 0:3:6 i
pname 0:3:9 j
ptuple 0:3:5 2
name 0:3:14 ind2sub
int 0:3:22 3
name 0:3:25 k
call 0:3:14 2
let 0:3:1 0
name 0:4:1 printf
str 0:4:8 %25d%20%25d%20%25d%20%25d%0A
name 0:4:25 i
int 0:4:27 0
index 0:4:25 1
name 0:4:31 i
int 0:4:33 1
index 0:4:31 1
name 0:4:37 j
int 0:4:39 0
index 0:4:37 1
name 0:4:43 j
int 0:4:45 1
index 0:4:43 1
call 0:4:1 5
cstmt 0:4:1
prog 4
'''
# sea.hir1: i64[] 10 (`loc k`, also i and j), the tuple (i64[], i64[]) 11 of `lib ind2sub` with an
# array argument (3.5.5 "Multiple-result library calls").
HIR1['ew_ind2sub'] = '''
tvec 10 3
ttuple 11 2 10 10
fn 1 .main main 1 0 3 0:1:1
loc k 10 var 0:1:5
loc i 10 let 0:3:6
loc j 10 let 0:3:9
ci 0:1:16 3 7
ci 0:1:19 3 2
lib 0:1:9 10 filled 2
bind 0:1:1 1
lv 0:2:1 10 1
ci 0:2:3 3 1
idx 0:2:1 3 1
ci 0:2:8 3 2
asg 0:2:1 set
ci 0:3:22 3 3
lv 0:3:25 10 1
lib 0:3:14 11 ind2sub 2
tbind 0:3:1 2 2 3
lv 0:4:25 10 2
ci 0:4:27 3 0
idx 0:4:25 3 1
fconv 0:4:8 1 - - - d
ftext 0:4:8 1 %20
lv 0:4:31 10 2
ci 0:4:33 3 1
idx 0:4:31 3 1
fconv 0:4:8 1 - - - d
ftext 0:4:8 1 %20
lv 0:4:37 10 3
ci 0:4:39 3 0
idx 0:4:37 3 1
fconv 0:4:8 1 - - - d
ftext 0:4:8 1 %20
lv 0:4:43 10 3
ci 0:4:45 3 1
idx 0:4:43 3 1
fconv 0:4:8 1 - - - d
ftext 0:4:8 1 %0A
fmt 0:4:8 1 8
lib 0:4:1 1 printf 1
eval 0:4:1
block 0:1:1 4
end
'''


def hirl_ew_ind2sub():
    """sea.hirl: tptr 12 3 (the adat of filled(7, 2), L2). The tbind of line 3 is L11: in its place
    in the body block (whose n grows by 3), `bind R' = ci 3`, `bind K' = lv k` (held), `bind i =`
    the L7 xblk of `bin mod (lv K') (lv R')`, `bind j =` that of `lib idiv (lv K') (lv R')`; every
    node at the lib's position (the operations included: they have no node of their own)."""
    F = Fn()
    eds = [(['ci 0:1:16 3 7', 'ci 0:1:19 3 2', 'lib 0:1:9 10 filled 2'],
            cat(L2(F, '0:1:9', 10, 3, 12, 'f', r=ci('0:1:19', 2), v=ci('0:1:16', 7))))]
    P = '0:3:14'
    x = Ctx(F, P, 'x')

    def l7(pre, op):
        y = Ctx(F, P, pre)
        st = [y.tmp('A1', x.lvl('K')),
              y.tmp('A2', x.lvl('R')),
              y.tmp('N1', ext(P, 0, y.lvl('A1'))),
              y.tmp('RES', anew(P, 10, 0, [y.lvl('N1')])),
              y.tmp('DR', adat(P, 12, y.lvl('RES'))),
              y.tmp('D1', adat(P, 12, y.lvl('A1')))]

        def body():
            e = eld(P, 3, y.lvl('D1'), y.klv('I'))
            Fx = bin_(P, 3, 'mod', e, y.lvl('A2')) if op == 'mod' else lib(P, 3, 'idiv', [e, y.lvl('A2')])
            return [est(P, 3, Fx, y.lvl('DR'), y.klv('I'))]
        st += y.loop('N1', 'Z', 'O', 'L', 'I', body)
        return xblk(P, st, y.lvl('RES'))
    st = [x.bindl('R', ci('0:3:22', 3)),
          x.bindl('K', lv('0:3:25', 10, 1))]
    st += [N(cat(l7('m', 'mod')) + ['bind %s 2' % P], None),
           N(cat(l7('d', 'idiv')) + ['bind %s 3' % P], None)]
    eds.append((['ci 0:3:22 3 3', 'lv 0:3:25 10 1', 'lib 0:3:14 11 ind2sub 2', 'tbind 0:3:1 2 2 3'],
                cat(*st)))
    eds.append((['block 0:1:1 4'], ['block 0:1:1 7']))
    return make_hirl(HIR1['ew_ind2sub'], ['tptr 12 3'], {1: (F, eds)})


HIRL['ew_ind2sub'] = hirl_ew_ind2sub
# sea.lir1. filled(7, 2) (rule 17 by L2) and k[1] = 2 (rule 19). Line 3 (rule 22 by L11): r into its
# register, k held (`mov`, `retain`: a borrowed local, rule 30 (1)); the loop of k % r into i
# (imodf with the line's site) and the loop of idiv(k, r) into j (idivf), each by rule 22 with one
# array operand (no check). Line 4: four element reads, the printf slot of 32 bytes. At the end
# of the block the bound locals that hold counts in reverse order of their declaring records
# (rule 16 (a)): j, i, the held k, then k.
LIR1['ew_ind2sub'] = '''
func .main main 0:1:1 0 0
slot s1 32 8
li i.V1 7
li i.R1 2
li i.ek1 2
li i.rk1 1
li i.c1 1
rcall sea_arr_new_u 0:1 1 p.k 4 i.ek1 i.rk1 i.R1 i.c1
ldp p.D1 p.k - 0 40
li i.Z1 0
icmp gt i.g1 i.R1 i.Z1
if 1 i.g1
li i.O1 1
isub i.L1 i.R1 i.O1
loop 2 i.K1 i.Z1 i.L1 i.O1
sti i.V1 p.D1 i.K1 8 0
endloop 2
endif 1
li i.v2 2
li i.x2 1
ldi i.e2 p.k - 0 16
chkb i.x2 i.e2 0 0:2
ldi i.rc2 p.k - 0 0
li i.o2 1
icmp ne i.s2 i.rc2 i.o2
if 3 i.s2
rcall sea_arr_unique 0:2 1 p.u2 1 p.k
mov p.k p.u2
endif 3
ldp p.d2 p.k - 0 40
sti i.v2 p.d2 i.x2 8 0
li i.r 3
mov p.H p.k
retain p.H
ldi i.Nm p.H - 0 16
li i.ekm 2
li i.rkm 1
li i.cm 1
rcall sea_arr_new_u 0:3 1 p.i 4 i.ekm i.rkm i.Nm i.cm
ldp p.DRm p.i - 0 40
ldp p.D1m p.H - 0 40
li i.Zm 0
icmp gt i.gm i.Nm i.Zm
if 4 i.gm
li i.Om 1
isub i.Lm i.Nm i.Om
loop 5 i.Im i.Zm i.Lm i.Om
ldi i.em p.D1m i.Im 8 0
imodf i.mm i.em i.r 0:3
sti i.mm p.DRm i.Im 8 0
endloop 5
endif 4
ldi i.Nd p.H - 0 16
li i.ekd 2
li i.rkd 1
li i.cd 1
rcall sea_arr_new_u 0:3 1 p.j 4 i.ekd i.rkd i.Nd i.cd
ldp p.DRd p.j - 0 40
ldp p.D1d p.H - 0 40
li i.Zd 0
icmp gt i.gd i.Nd i.Zd
if 6 i.gd
li i.Od 1
isub i.Ld i.Nd i.Od
loop 7 i.Id i.Zd i.Ld i.Od
ldi i.ed p.D1d i.Id 8 0
idivf i.qd i.ed i.r 0:3
sti i.qd p.DRd i.Id 8 0
endloop 7
endif 6
li i.k0 0
ldi i.e0 p.i - 0 16
chkb i.k0 i.e0 0 0:4
ldp p.d0 p.i - 0 40
ldi i.v0 p.d0 i.k0 8 0
li i.k1 1
ldi i.e1 p.i - 0 16
chkb i.k1 i.e1 0 0:4
ldp p.d1 p.i - 0 40
ldi i.v1 p.d1 i.k1 8 0
li i.k2 0
ldi i.e2b p.j - 0 16
chkb i.k2 i.e2b 0 0:4
ldp p.d2b p.j - 0 40
ldi i.v2b p.d2b i.k2 8 0
li i.k3 1
ldi i.e3 p.j - 0 16
chkb i.k3 i.e3 0 0:4
ldp p.d3 p.j - 0 40
ldi i.v3 p.d3 i.k3 8 0
sa p.s s1
sti i.v0 p.s - 0 0
sti i.v1 p.s - 0 8
sti i.v2b p.s - 0 16
sti i.v3 p.s - 0 24
la p.f d1
rcall sea_printf 0:4 0 2 p.f p.s
release p.j
release p.i
release p.H
release p.k
ret 0
endfunc
fmt d1 8
fconv - - - d i
ftext %20
fconv - - - d i
ftext %20
fconv - - - d i
ftext %20
fconv - - - d i
ftext %0A
'''
# k = [7, 2]: i = k % 3 = [1, 2], j = idiv(k, 3) = [2, 0].
OUT['ew_ind2sub'] = '1 2 2 0\n'
NAMES.append('ew_ind2sub')

# ================================================================ arr_tasg_l12 (Decision 37 / L12)
SEA['arr_tasg_l12'] = '''var v = zeros(4)
var d = zeros(1)
(v[1..3], d) = two(1.5)
let (p, q) = two(0.5)
printf("%g %g %g %d %g\\n", v[1], v[3], d[1], len(d), q[0])
// arr_tasg_l12 -- DESIGN.md 3.5.9 L12 (Decision 37): a tuple assignment with a selection target
// (an L6 store of the fixed-size first result) and a converting component (the fixed-size second
// result stored into the dynamic d through a dyn, L10), both results first bound by one tbind
fn two(a: f64) -> (f64[2], f64[2]) {
    var r = [a, a]
    for k in 0..2 {
        r[k] = r[k] + 1.0
    }
    return (r, r)
}
'''
AST['arr_tasg_l12'] = '''
pname 0:1:5 v
name 0:1:9 zeros
int 0:1:15 4
call 0:1:9 1
var 0:1:1 0
pname 0:2:5 d
name 0:2:9 zeros
int 0:2:15 1
call 0:2:9 1
var 0:2:1 0
name 0:3:2 v
int 0:3:4 1
int 0:3:7 3
range 0:3:4 0 0
index 0:3:2 1
name 0:3:11 d
name 0:3:16 two
float 0:3:20 #3FF8000000000000
call 0:3:16 1
tasg 0:3:1 2
pname 0:4:6 p
pname 0:4:9 q
ptuple 0:4:5 2
name 0:4:14 two
float 0:4:18 #3FE0000000000000
call 0:4:14 1
let 0:4:1 0
name 0:5:1 printf
str 0:5:8 %25g%20%25g%20%25g%20%25d%20%25g%0A
name 0:5:28 v
int 0:5:30 1
index 0:5:28 1
name 0:5:34 v
int 0:5:36 3
index 0:5:34 1
name 0:5:40 d
int 0:5:42 1
index 0:5:40 1
name 0:5:46 len
name 0:5:50 d
call 0:5:46 1
name 0:5:54 q
int 0:5:56 0
index 0:5:54 1
call 0:5:1 6
cstmt 0:5:1
type 0:9:11 f64 s 0
param 0:9:8 a 0 0
int 0:9:24 2
type 0:9:20 f64 fv 1
int 0:9:32 2
type 0:9:28 f64 fv 1
pname 0:10:9 r
name 0:10:14 a
name 0:10:17 a
row 0:10:14 2
array 0:10:13 1
var 0:10:5 0
int 0:11:14 0
int 0:11:17 2
range 0:11:14 0 0
name 0:12:9 r
name 0:12:11 k
index 0:12:9 1
name 0:12:16 r
name 0:12:18 k
index 0:12:16 1
float 0:12:23 #3FF0000000000000
bin 0:12:16 add
asg 0:12:9 set
block 0:11:19 1
for 0:11:5 k 0:11:9
name 0:14:13 r
name 0:14:16 r
return 0:14:5 2
block 0:9:36 3
fn 0:9:1 two 0 1 2
prog 6
'''

# sea.hir1: f64[] 10 (`loc v`, d), f64[2] 11 (`loc p`, q), i64[] 12 (the range index of line 3),
# the tuple (f64[2], f64[2]) 13 of two (its call on line 3). The tasg of line 3 has the cv bits
# 0 (a selection target contributes no 2 or 4) and 2 (the fixed-size result into the dynamic d,
# a dyn), 3.5.5 `tasg`; seacheck writes no dyn node for it.
HIR1['arr_tasg_l12'] = '''
tvec 10 4
tfvec 11 4 2
tvec 12 3
ttuple 13 2 11 11
fn 1 .main main 1 0 4 0:1:1
loc v 10 var 0:1:5
loc d 10 var 0:2:5
loc p 11 let 0:4:6
loc q 11 let 0:4:9
ci 0:1:15 3 4
lib 0:1:9 10 zeros 1
bind 0:1:1 1
ci 0:2:15 3 1
lib 0:2:9 10 zeros 1
bind 0:2:1 2
lv 0:3:2 10 1
ci 0:3:4 3 1
ci 0:3:7 3 3
rng 0:3:4 12 0 0
idx 0:3:2 10 1
lv 0:3:11 10 2
cf 0:3:20 4 #3FF8000000000000
call 0:3:16 13 2 1
tasg 0:3:1 2 0 2
cf 0:4:18 4 #3FE0000000000000
call 0:4:14 13 2 1
tbind 0:4:1 2 3 4
lv 0:5:28 10 1
ci 0:5:30 3 1
idx 0:5:28 4 1
fconv 0:5:8 1 - - - g
ftext 0:5:8 1 %20
lv 0:5:34 10 1
ci 0:5:36 3 3
idx 0:5:34 4 1
fconv 0:5:8 1 - - - g
ftext 0:5:8 1 %20
lv 0:5:40 10 2
ci 0:5:42 3 1
idx 0:5:40 4 1
fconv 0:5:8 1 - - - g
ftext 0:5:8 1 %20
lv 0:5:50 10 2
lib 0:5:46 3 len 1
fconv 0:5:8 1 - - - d
ftext 0:5:8 1 %20
lv 0:5:54 11 4
ci 0:5:56 3 0
idx 0:5:54 4 1
fconv 0:5:8 1 - - - g
ftext 0:5:8 1 %0A
fmt 0:5:8 1 10
lib 0:5:1 1 printf 1
eval 0:5:1
block 0:1:1 5
end
fn 2 two fn 13 1 2 0:9:1
par a 4 val
loc r 11 var 0:10:9
loc k 3 for 0:11:9
lv 0:10:14 4 1
lv 0:10:17 4 1
row 0:10:14 11 2
arr 0:10:13 11 1
bind 0:10:5 2
ci 0:11:14 3 0
ci 0:11:17 3 2
rng 0:11:14 12 0 0
lv 0:12:9 11 2
lv 0:12:11 3 3
idx 0:12:9 4 1
lv 0:12:16 11 2
lv 0:12:18 3 3
idx 0:12:16 4 1
cf 0:12:23 4 #3FF0000000000000
bin 0:12:16 4 add
asg 0:12:9 set
block 0:11:19 1
forr 0:11:5 3
lv 0:14:13 11 2
lv 0:14:16 11 2
ret 0:14:5 2
block 0:9:36 3
end
'''


def hirl_arr_tasg_l12():
    """sea.hirl: tptr 14 4 (the adat of v in the L6 store). .main: both zeros are L1; the tasg of
    line 3 is L12: `block P 3` (P the tasg's position, every written node at P) with (1) `tbind P
    2 L1 L2 = call` (no cv), L1 and L2 .l locals of the results' type f64[2]; (2) `asg set
    (v[1..3]) (lv L1)` rewritten by L6 (a fixed-size value: `tmp Vv = lv L1`, R9; the range IX,
    the checks, the count and the shape check against ext(Vv, 0), cow, the data, the range loop
    of stores with the counter O); (3) `asg set (lv d) (dyn (lv L2))`, the asg kept (rule 15 (d))
    and its dyn rewritten by L10. two: the literal is L9 (a)."""
    F1, F2 = Fn(), Fn()
    eds = [(['ci 0:1:15 3 4', 'lib 0:1:9 10 zeros 1'], cat(L1('0:1:9', 10, [ci('0:1:15', 4)]))),
           (['ci 0:2:15 3 1', 'lib 0:2:9 10 zeros 1'], cat(L1('0:2:9', 10, [ci('0:2:15', 1)])))]
    P = '0:3:1'
    L1v = F1.d('L1', 11, 'let', P)
    L2v = F1.d('L2', 11, 'let', P)
    s1 = N(['cf 0:3:20 4 #3FF8000000000000', 'call 0:3:16 13 2 1',
            'tbind %s 2 %s %s' % (P, L1v, L2v)], None)
    # (2) the L6 store of lv L1 into v[1..3]
    x = Ctx(F1, P, 's')
    T = lambda: lv(P, 10, 1)
    st = [x.tmp('Vv', lv(P, 11, L1v)),
          x.tmp('LO', ci('0:3:4', 1)),
          x.tmp('HI', ci('0:3:7', 3)),
          x.tmp('ST', ci(P, 1)),
          x.rcnt(0, 'L', 'E', 'LO', 'HI', 'ST', '0:3:4'),
          x.tmp('X', ext(P, 0, T())),
          if_(P, x.lvl('E'), block(P, [
              chkb(P, 0, x.lvl('LO'), x.lvl('X')),
              chkb(P, 0, wbin(P, 'add', x.lvl('LO'), wbin(P, 'mul', x.lvl('L'), x.lvl('ST'))),
                   x.lvl('X'))])),
          x.tmp('O1', ci(P, 1)),
          x.tmp('T', wbin(P, 'add', x.lvl('L'), x.lvl('O1'))),
          x.tmp('Z', ci(P, 0)),
          x.tmp('N', lib(P, 3, 'where', [x.lvl('E'), x.lvl('T'), x.lvl('Z')])),
          x.tmp('NV', ext(P, 0, x.lvl('Vv'))),
          x.tmp('S', bin_(P, 2, 'ne', x.lvl('N'), x.lvl('NV')))]
    st += x.vchk('SHAPE_MISMATCH', 'S', 'N', 'NV', 'V')
    st += [cow(P, T()),
           x.tmp('DT', adat(P, 14, T())),
           x.tmp('DV', adat(P, 14, x.lvl('Vv'))),
           x.bindl('O', ci(P, 0)),
           x.tmp('One', ci(P, 1))]
    st.append(x.rloop('E', 'LO', 'L', 'ST', 'Q', lambda: [
        est(P, 4, eld(P, 4, x.lvl('DV'), x.lvl('O')), x.lvl('DT'), x.klv('Q')),
        x.plus_eq('O', x.lvl('One'))]))
    s2 = block(P, st)
    # (3) asg set (lv d) (dyn (lv L2)): L10's dyn
    y = Ctx(F1, P, 'y')
    dy = [y.tmp('S', lv(P, 11, L2v)),
          y.tmp('R', ext(P, 0, y.lvl('S'))),
          y.tmp('A', anew(P, 10, 0, [y.lvl('R')])),
          y.tmp('D', adat(P, 14, y.lvl('A'))),
          y.tmp('N', ci(P, 16)),
          mcpy(P, y.lvl('D'), adat(P, 14, y.lvl('S')), y.lvl('N'))]
    s3 = asg(P, 'set', lv('0:3:11', 10, 2), xblk(P, dy, y.lvl('A')))
    eds.append(('''
lv 0:3:2 10 1
ci 0:3:4 3 1
ci 0:3:7 3 3
rng 0:3:4 12 0 0
idx 0:3:2 10 1
lv 0:3:11 10 2
cf 0:3:20 4 #3FF8000000000000
call 0:3:16 13 2 1
tasg 0:3:1 2 0 2
''', cat(block(P, [s1, s2, s3]))))
    lit = ('''
lv 0:10:14 4 1
lv 0:10:17 4 1
row 0:10:14 11 2
arr 0:10:13 11 1
''', cat(L9a(F2, '0:10:13', 11, 4, 14, 'l', [((0, 0), lv('0:10:14', 4, 1)),
                                             ((0, 1), lv('0:10:17', 4, 1))], 1)))
    eds.append((['lv 0:5:50 10 2', 'lib 0:5:46 3 len 1'], cat(L3('0:5:46', 0, lv('0:5:50', 10, 2)))))
    return make_hirl(HIR1['arr_tasg_l12'], ['tptr 14 4'], {1: (F1, eds), 2: (F2, [lit])})


HIRL['arr_tasg_l12'] = hirl_arr_tasg_l12
# sea.lir1. .main: zeros(4), zeros(1) (arrnewz). Line 3, rule 15 (j) by L12: the tbind of the two
# fixed-size .l locals passes their slots s1, s2 as the hidden result addresses (rule 27 (b), (l):
# each sa before the call, the argument after them); then the first target, rule 21: the range
# (li, rcount), ext(v, 0), the checks, the count (isel), the shape check against the static extent
# `li 2` of L1 (`li V -1` between icmp and chk), cow(v), data(v) (L1's data is its home), the range
# loop storing L1's elements at the counter O; then the second target, rule 15 (d) of the dyn
# (rule 27 (i): `li 2`, arrnew, data, `li 16`, mcopy from L2's home) into a new register, `release
# d`, `mov d`. The fixed-size .l locals hold no counts: nothing at the block's end. Line 4: the
# tbind of p and q passes their slots. Line 5: the printf slot s5 of 40 bytes; d and v released
# (p, q hold no counts). two: the hidden addresses p1, p2 in front of a; r's slot and the
# literal's home, the copy, the loop (rules 18, 19 on a fixed-size base), `return (r, r)` copies r
# into each hidden address (rule 27 (h), (l)), `ret 0`.
LIR1['arr_tasg_l12'] = '''
func .main main 0:1:1 0 0
slot s1 16 8
slot s2 16 8
slot s3 16 8
slot s4 16 8
slot s5 40 8
li i.n1 4
li i.ek1 1
li i.rk1 1
li i.c1 1
rcall sea_arr_new 0:1 1 p.v 4 i.ek1 i.rk1 i.n1 i.c1
li i.n2 1
li i.ek2 1
li i.rk2 1
li i.c2 1
rcall sea_arr_new 0:2 1 p.d 4 i.ek2 i.rk2 i.n2 i.c2
sa p.L1 s1
sa p.L2 s2
lf f.a3 #3FF8000000000000
call two 0 3 p.L1 p.L2 f.a3
li i.LO 1
li i.HI 3
li i.ST 1
rcount i.L i.E i.LO i.HI i.ST 0 0:3
ldi i.X p.v - 0 16
if 1 i.E
chkb i.LO i.X 0 0:3
imul i.m i.L i.ST
iadd i.la i.LO i.m
chkb i.la i.X 0 0:3
endif 1
li i.O1 1
iadd i.T i.L i.O1
li i.Z 0
isel i.N i.E i.T i.Z
li i.NV 2
icmp ne i.S i.N i.NV
li i.V -1
chk i.S SHAPE_MISMATCH 0:3 4 i.N i.V i.NV i.V
ldi i.rc p.v - 0 0
li i.o 1
icmp ne i.sh i.rc i.o
if 2 i.sh
rcall sea_arr_unique 0:3 1 p.u 1 p.v
mov p.v p.u
endif 2
ldp p.DT p.v - 0 40
li i.O 0
li i.One 1
if 3 i.E
loop 4 i.Q i.LO i.L i.ST
ldf f.e p.L1 i.O 8 0
stf f.e p.DT i.Q 8 0
iadd i.O i.O i.One
endloop 4
endif 3
li i.Ry 2
li i.eky 1
li i.rky 1
li i.cy 1
rcall sea_arr_new_u 0:3 1 p.A 4 i.eky i.rky i.Ry i.cy
ldp p.Dy p.A - 0 40
li i.Ny 16
mcopy p.Dy p.L2 i.Ny
release p.d
mov p.d p.A
sa p.p s3
sa p.q s4
lf f.a4 #3FE0000000000000
call two 0 3 p.p p.q f.a4
li i.k1 1
ldi i.e1 p.v - 0 16
chkb i.k1 i.e1 0 0:5
ldp p.d1 p.v - 0 40
ldf f.x1 p.d1 i.k1 8 0
li i.k2 3
ldi i.e2 p.v - 0 16
chkb i.k2 i.e2 0 0:5
ldp p.d2 p.v - 0 40
ldf f.x2 p.d2 i.k2 8 0
li i.k3 1
ldi i.e3 p.d - 0 16
chkb i.k3 i.e3 0 0:5
ldp p.d3 p.d - 0 40
ldf f.x3 p.d3 i.k3 8 0
ldi i.len p.d - 0 16
li i.k5 0
li i.e5 2
chkb i.k5 i.e5 0 0:5
ldf f.x5 p.q i.k5 8 0
sa p.s s5
stf f.x1 p.s - 0 0
stf f.x2 p.s - 0 8
stf f.x3 p.s - 0 16
sti i.len p.s - 0 24
stf f.x5 p.s - 0 32
la p.f d1
rcall sea_printf 0:5 0 2 p.f p.s
release p.d
release p.v
ret 0
endfunc
func two fn 0:9:1 3 p.h1 p.h2 f.a 0
slot s1 16 8
slot s2 16 8
sa p.r s1
sa p.H s2
stf f.a p.H - 0 0
stf f.a p.H - 0 8
li i.n 16
mcopy p.r p.H i.n
li i.lo 0
li i.hi 2
li i.st 1
rcount i.C i.E i.lo i.hi i.st 0 0:11
if 1 i.E
loop 2 i.k i.lo i.C i.st
li i.e1 2
chkb i.k i.e1 0 0:12
ldf f.x p.r i.k 8 0
lf f.one #3FF0000000000000
fadd f.s f.x f.one
li i.e2 2
chkb i.k i.e2 0 0:12
stf f.s p.r i.k 8 0
endloop 2
endif 1
li i.n1 16
mcopy p.h1 p.r i.n1
li i.n2 16
mcopy p.h2 p.r i.n2
ret 0
endfunc
fmt d1 10
fconv - - - g f
ftext %20
fconv - - - g f
ftext %20
fconv - - - g f
ftext %20
fconv - - - d i
ftext %20
fconv - - - g f
ftext %0A
'''
# two(1.5) = ([2.5, 2.5], [2.5, 2.5]): v = [0, 2.5, 2.5, 0], d = [2.5, 2.5]; q = [1.5, 1.5].
OUT['arr_tasg_l12'] = '2.5 0 2.5 2 1.5\n'
NAMES.append('arr_tasg_l12')

# ================================================================ arr_lit_cat_fixed (L9 (c), every part fixed)
SEA['arr_lit_cat_fixed'] = '''let a = [1.5, 2.5]
let v = [a, 4.0, a]
let m = [1.0, 2.0; 3.0, 4.0]
let W = [m, m]
printf("%g %g %d %g %d\\n", v[2], v[4], len(v), W[1, 3], cols(W))
// arr_lit_cat_fixed -- DESIGN.md 3.5.9 L9 (c) with every part fixed-size: a home slot for the
// result, the length and column sums still written (no check: the row check of line 4 dropped),
// every offset a constant, the parts' extents their static values
'''
AST['arr_lit_cat_fixed'] = '''
pname 0:1:5 a
float 0:1:10 #3FF8000000000000
float 0:1:15 #4004000000000000
row 0:1:10 2
array 0:1:9 1
let 0:1:1 0
pname 0:2:5 v
name 0:2:10 a
float 0:2:13 #4010000000000000
name 0:2:18 a
row 0:2:10 3
array 0:2:9 1
let 0:2:1 0
pname 0:3:5 m
float 0:3:10 #3FF0000000000000
float 0:3:15 #4000000000000000
row 0:3:10 2
float 0:3:20 #4008000000000000
float 0:3:25 #4010000000000000
row 0:3:20 2
array 0:3:9 2
let 0:3:1 0
pname 0:4:5 W
name 0:4:10 m
name 0:4:13 m
row 0:4:10 2
array 0:4:9 1
let 0:4:1 0
name 0:5:1 printf
str 0:5:8 %25g%20%25g%20%25d%20%25g%20%25d%0A
name 0:5:28 v
int 0:5:30 2
index 0:5:28 1
name 0:5:34 v
int 0:5:36 4
index 0:5:34 1
name 0:5:40 len
name 0:5:44 v
call 0:5:40 1
name 0:5:48 W
int 0:5:50 1
int 0:5:53 3
index 0:5:48 2
name 0:5:57 cols
name 0:5:62 W
call 0:5:57 1
call 0:5:1 6
cstmt 0:5:1
prog 5
'''

# sea.hir1: f64[2] 10 (`loc a`; also each row of m), f64[5] 11 (`loc v`: a row of fixed parts and a
# scalar joins into a fixed vector, LANGUAGE.md 6.9), f64[2,2] 12 (`loc m`), f64[2,4] 13 (`loc W`).
HIR1['arr_lit_cat_fixed'] = '''
tfvec 10 4 2
tfvec 11 4 5
tfmat 12 4 2 2
tfmat 13 4 2 4
fn 1 .main main 1 0 4 0:1:1
loc a 10 let 0:1:5
loc v 11 let 0:2:5
loc m 12 let 0:3:5
loc W 13 let 0:4:5
cf 0:1:10 4 #3FF8000000000000
cf 0:1:15 4 #4004000000000000
row 0:1:10 10 2
arr 0:1:9 10 1
bind 0:1:1 1
lv 0:2:10 10 1
cf 0:2:13 4 #4010000000000000
lv 0:2:18 10 1
row 0:2:10 11 3
arr 0:2:9 11 1
bind 0:2:1 2
cf 0:3:10 4 #3FF0000000000000
cf 0:3:15 4 #4000000000000000
row 0:3:10 10 2
cf 0:3:20 4 #4008000000000000
cf 0:3:25 4 #4010000000000000
row 0:3:20 10 2
arr 0:3:9 12 2
bind 0:3:1 3
lv 0:4:10 12 3
lv 0:4:13 12 3
row 0:4:10 13 2
arr 0:4:9 13 1
bind 0:4:1 4
lv 0:5:28 11 2
ci 0:5:30 3 2
idx 0:5:28 4 1
fconv 0:5:8 1 - - - g
ftext 0:5:8 1 %20
lv 0:5:34 11 2
ci 0:5:36 3 4
idx 0:5:34 4 1
fconv 0:5:8 1 - - - g
ftext 0:5:8 1 %20
lv 0:5:44 11 2
lib 0:5:40 3 len 1
fconv 0:5:8 1 - - - d
ftext 0:5:8 1 %20
lv 0:5:48 13 4
ci 0:5:50 3 1
ci 0:5:53 3 3
idx 0:5:48 4 2
fconv 0:5:8 1 - - - g
ftext 0:5:8 1 %20
lv 0:5:62 13 4
lib 0:5:57 3 cols 1
fconv 0:5:8 1 - - - d
ftext 0:5:8 1 %0A
fmt 0:5:8 1 10
lib 0:5:1 1 printf 1
eval 0:5:1
block 0:1:1 5
end
'''


def hirl_arr_lit_cat_fixed():
    """sea.hirl: tptr 14 4 (the adat of a's literal). Lines 1 and 3 are L9 (a); lines 2 and 4 L9
    (c) with every part fixed-size: `anew P T 0 0`, the lengths and the column sum still written
    (`tmp Nk = wbin add`, `tmp Cr = wbin add`), no `tmp S` and no mchk, every offset `tmp = ci` of
    its static value; len and cols are L3 of fixed-size arrays."""
    F = Fn()
    eds = [('''
cf 0:1:10 4 #3FF8000000000000
cf 0:1:15 4 #4004000000000000
row 0:1:10 10 2
arr 0:1:9 10 1
''', cat(L9a(F, '0:1:9', 10, 4, 14, 'a', [((0, 0), cf('0:1:10', '#3FF8000000000000')),
                                          ((0, 1), cf('0:1:15', '#4004000000000000'))], 1)))]
    # ---- line 2: [a, 4.0, a], a fixed f64[5]
    P = '0:2:9'
    x = Ctx(F, P, 'v')
    st = [x.tmp('Q1', lv('0:2:10', 10, 1)),
          x.tmp('Q2', cf('0:2:13', '#4010000000000000')),
          x.tmp('Q3', lv('0:2:18', 10, 1)),
          x.tmp('L1', ext(P, 0, x.lvl('Q1'))),
          x.tmp('L2', ci(P, 1)),
          x.tmp('N2', wbin(P, 'add', x.lvl('L1'), x.lvl('L2'))),
          x.tmp('L3', ext(P, 0, x.lvl('Q3'))),
          x.tmp('N3', wbin(P, 'add', x.lvl('N2'), x.lvl('L3'))),
          x.tmp('RES', anew(P, 11, 0, [])),
          x.tmp('DR', adat(P, 14, x.lvl('RES')))]

    def vpart(k):
        return [x.tmp('Dq' + k, adat(P, 14, x.lvl('Q' + k)))] + x.loop(
            'L' + k, 'Z' + k, 'O' + k, 'M' + k, 'I' + k, lambda: [
                est(P, 4, eld(P, 4, x.lvl('Dq' + k), x.klv('I' + k)), x.lvl('DR'),
                    wbin(P, 'add', x.lvl('c' + k), x.klv('I' + k)))])
    st.append(x.tmp('c1', ci(P, 0)))
    st += vpart('1')
    st += [x.tmp('c2', ci(P, 2)),
           est(P, 4, x.lvl('Q2'), x.lvl('DR'), x.lvl('c2')),
           x.tmp('c3', ci(P, 3))]
    st += vpart('3')
    eds.append(('''
lv 0:2:10 10 1
cf 0:2:13 4 #4010000000000000
lv 0:2:18 10 1
row 0:2:10 11 3
arr 0:2:9 11 1
''', cat(xblk(P, st, x.lvl('RES')))))
    eds.append(('''
cf 0:3:10 4 #3FF0000000000000
cf 0:3:15 4 #4000000000000000
row 0:3:10 10 2
cf 0:3:20 4 #4008000000000000
cf 0:3:25 4 #4010000000000000
row 0:3:20 10 2
arr 0:3:9 12 2
''', cat(L9a(F, '0:3:9', 12, 4, 14, 'm', [
        ((0, 0), cf('0:3:10', '#3FF0000000000000')), ((0, 1), cf('0:3:15', '#4000000000000000')),
        ((1, 0), cf('0:3:20', '#4008000000000000')), ((1, 1), cf('0:3:25', '#4010000000000000'))],
        2))))
    # ---- line 4: [m, m], a fixed f64[2,4]
    P = '0:4:9'
    x = Ctx(F, P, 'w')
    st = [x.tmp('Q1', lv('0:4:10', 12, 3)),
          x.tmp('Q2', lv('0:4:13', 12, 3)),
          x.tmp('R1', ext(P, 0, x.lvl('Q1'))),
          x.tmp('C1', ext(P, 1, x.lvl('Q1'))),
          x.tmp('R2', ext(P, 0, x.lvl('Q2'))),
          x.tmp('C2', ext(P, 1, x.lvl('Q2'))),
          x.tmp('Cr', wbin(P, 'add', x.lvl('C1'), x.lvl('C2'))),
          x.tmp('RES', anew(P, 13, 0, [])),
          x.tmp('DR', adat(P, 14, x.lvl('RES'))),
          x.tmp('r0', ci(P, 0))]

    def mpart(k):
        def body():
            src = eld(P, 4, x.lvl('Dq' + k), x.lin(x.klv('I' + k), x.klv('J' + k), x.lvl('R' + k)))
            dst = wbin(P, 'add', wbin(P, 'add', x.lvl('r0'), x.klv('I' + k)),
                       wbin(P, 'mul', wbin(P, 'add', x.lvl('c' + k), x.klv('J' + k)), x.lvl('R1')))
            return [est(P, 4, src, x.lvl('DR'), dst)]
        return [x.tmp('Dq' + k, adat(P, 14, x.lvl('Q' + k)))] + x.loop(
            'C' + k, 'Zj' + k, 'Oj' + k, 'Lj' + k, 'J' + k, lambda: x.loop(
                'R' + k, 'Zi' + k, 'Oi' + k, 'Li' + k, 'I' + k, body))
    st.append(x.tmp('c1', ci(P, 0)))
    st += mpart('1')
    st.append(x.tmp('c2', ci(P, 2)))
    st += mpart('2')
    eds.append(('''
lv 0:4:10 12 3
lv 0:4:13 12 3
row 0:4:10 13 2
arr 0:4:9 13 1
''', cat(xblk(P, st, x.lvl('RES')))))
    eds.append((['lv 0:5:44 11 2', 'lib 0:5:40 3 len 1'], cat(L3('0:5:40', 0, lv('0:5:44', 11, 2)))))
    eds.append((['lv 0:5:62 13 4', 'lib 0:5:57 3 cols 1'], cat(L3('0:5:57', 1, lv('0:5:62', 13, 4)))))
    return make_hirl(HIR1['arr_lit_cat_fixed'], ['tptr 14 4'], {1: (F, eds)})


HIRL['arr_lit_cat_fixed'] = hirl_arr_lit_cat_fixed
# sea.lir1. Each bind of a fixed-size local: its slot first, the value, the copy (rule 27 (b)).
# Line 2 (rule 26 (c), every part fixed): the scalar part `lf`; the lengths `li 2`, `li 1`, `li 2`
# joined by iadd (no check); the result's home slot s4 (no arrnew); each part copied at its
# constant offset (`li 0`, `li 2`, `li 3`): a's elements by a loop reading its home, the scalar by
# one store. Line 4: the four static extents (`li 2`), the column sum (iadd; the row check
# dropped), the home s8, the row offset and each part's column offset, each part by the nest
# (read at I + J*2, stored at (r0 + I) + (c0 + J)*R1). Line 5: element reads of fixed-size homes
# with static extents, len(v) `li 5`, cols(W) `li 4`, the printf slot s9 of 40 bytes. No local
# holds counts: nothing is released.
LIR1['arr_lit_cat_fixed'] = '''
func .main main 0:1:1 0 0
slot s1 16 8
slot s2 16 8
slot s3 40 8
slot s4 40 8
slot s5 32 8
slot s6 32 8
slot s7 64 8
slot s8 64 8
slot s9 40 8
sa p.a s1
sa p.H1 s2
lf f.a1 #3FF8000000000000
stf f.a1 p.H1 - 0 0
lf f.a2 #4004000000000000
stf f.a2 p.H1 - 0 8
li i.n1 16
mcopy p.a p.H1 i.n1
sa p.v s3
lf f.Q2 #4010000000000000
li i.L1 2
li i.L2 1
iadd i.N2 i.L1 i.L2
li i.L3 2
iadd i.N3 i.N2 i.L3
sa p.RV s4
li i.c1 0
li i.Z1 0
icmp gt i.g1 i.L1 i.Z1
if 1 i.g1
li i.O1 1
isub i.M1 i.L1 i.O1
loop 2 i.I1 i.Z1 i.M1 i.O1
ldf f.e1 p.a i.I1 8 0
iadd i.y1 i.c1 i.I1
stf f.e1 p.RV i.y1 8 0
endloop 2
endif 1
li i.c2 2
stf f.Q2 p.RV i.c2 8 0
li i.c3 3
li i.Z3 0
icmp gt i.g3 i.L3 i.Z3
if 3 i.g3
li i.O3 1
isub i.M3 i.L3 i.O3
loop 4 i.I3 i.Z3 i.M3 i.O3
ldf f.e3 p.a i.I3 8 0
iadd i.y3 i.c3 i.I3
stf f.e3 p.RV i.y3 8 0
endloop 4
endif 3
li i.n2 40
mcopy p.v p.RV i.n2
sa p.m s5
sa p.H3 s6
lf f.m1 #3FF0000000000000
stf f.m1 p.H3 - 0 0
lf f.m2 #4000000000000000
stf f.m2 p.H3 - 0 16
lf f.m3 #4008000000000000
stf f.m3 p.H3 - 0 8
lf f.m4 #4010000000000000
stf f.m4 p.H3 - 0 24
li i.n3 32
mcopy p.m p.H3 i.n3
sa p.W s7
li i.R1 2
li i.C1 2
li i.R2 2
li i.C2 2
iadd i.Cr i.C1 i.C2
sa p.RW s8
li i.r0 0
li i.w1 0
li i.Zj1 0
icmp gt i.gj1 i.C1 i.Zj1
if 5 i.gj1
li i.Oj1 1
isub i.Lj1 i.C1 i.Oj1
loop 6 i.J1 i.Zj1 i.Lj1 i.Oj1
li i.Zi1 0
icmp gt i.gi1 i.R1 i.Zi1
if 7 i.gi1
li i.Oi1 1
isub i.Li1 i.R1 i.Oi1
loop 8 i.I1w i.Zi1 i.Li1 i.Oi1
imul i.t1 i.J1 i.R1
iadd i.x1 i.I1w i.t1
ldf f.w1 p.m i.x1 8 0
iadd i.a1 i.r0 i.I1w
iadd i.b1 i.w1 i.J1
imul i.mm1 i.b1 i.R1
iadd i.y1w i.a1 i.mm1
stf f.w1 p.RW i.y1w 8 0
endloop 8
endif 7
endloop 6
endif 5
li i.w2 2
li i.Zj2 0
icmp gt i.gj2 i.C2 i.Zj2
if 9 i.gj2
li i.Oj2 1
isub i.Lj2 i.C2 i.Oj2
loop 10 i.J2 i.Zj2 i.Lj2 i.Oj2
li i.Zi2 0
icmp gt i.gi2 i.R2 i.Zi2
if 11 i.gi2
li i.Oi2 1
isub i.Li2 i.R2 i.Oi2
loop 12 i.I2 i.Zi2 i.Li2 i.Oi2
imul i.t2 i.J2 i.R2
iadd i.x2w i.I2 i.t2
ldf f.w2 p.m i.x2w 8 0
iadd i.a2 i.r0 i.I2
iadd i.b2 i.w2 i.J2
imul i.mm2 i.b2 i.R1
iadd i.y2 i.a2 i.mm2
stf f.w2 p.RW i.y2 8 0
endloop 12
endif 11
endloop 10
endif 9
li i.n4 64
mcopy p.W p.RW i.n4
li i.k51 2
li i.e51 5
chkb i.k51 i.e51 0 0:5
ldf f.r51 p.v i.k51 8 0
li i.k52 4
li i.e52 5
chkb i.k52 i.e52 0 0:5
ldf f.r52 p.v i.k52 8 0
li i.n53 5
li i.i54 1
li i.j54 3
li i.r54 2
chkb i.i54 i.r54 0 0:5
li i.c54 4
chkb i.j54 i.c54 1 0:5
imul i.t54 i.j54 i.r54
iadd i.p54 i.i54 i.t54
ldf f.r54 p.W i.p54 8 0
li i.n55 4
sa p.s s9
stf f.r51 p.s - 0 0
stf f.r52 p.s - 0 8
sti i.n53 p.s - 0 16
stf f.r54 p.s - 0 24
sti i.n55 p.s - 0 32
la p.f d1
rcall sea_printf 0:5 0 2 p.f p.s
ret 0
endfunc
fmt d1 10
fconv - - - g f
ftext %20
fconv - - - g f
ftext %20
fconv - - - d i
ftext %20
fconv - - - g f
ftext %20
fconv - - - d i
ftext %0A
'''
# v = [1.5, 2.5, 4, 1.5, 2.5] (v[2] = 4, v[4] = 2.5, length 5); m = [1 2; 3 4], W = [1 2 1 2; 3 4 3 4]
# (W[1, 3] = 4, 4 columns).
OUT['arr_lit_cat_fixed'] = '4 2.5 5 4 4\n'
NAMES.append('arr_lit_cat_fixed')

# ================================================================ res_err_array (6.2)
# From 4e seaname resolves the fixed-size type f64[3] of the signature (3.4.2: the phase rule of
# step 4e no longer reports fixed-size array types), so the rerr 259 `arrays` of 4d is gone: the
# .res holds `rtfvec 10 4 3` and the type 10 in the rtype and the rfn record. The source keeps its
# lines (only its comment, lines 1-2, says so now); with no rerr, the test gains a .hir1 (6.2: a
# .res without .hir1 is a program whose sea.res holds an rerr). sea.hir1: f is function 2, never
# called (reachability is pass 2b's, 3.5.7; sea.hir1 has every function); its parameter type
# f64[3] is type 10 (first referred to by `par v`); .main's body is empty.
SEA['res_err_array'] = '''// res_err_array -- from sub-phase 4e seaname resolves a fixed-size array type of a signature:
// no rerr (4d reported 259 arrays here); the parameter's type is rtfvec 10 (DESIGN.md 3.4.2)
fn f(v: f64[3], k: i64) -> i64 {
    return k
}
'''
RES_ERR_ARRAY_HIR1 = '''
tfvec 10 4 3
fn 1 .main main 1 0 0 0:1:1
block 0:1:1 0
end
fn 2 f fn 3 2 0 0:3:1
par v 10 val
par k 3 val
lv 0:4:12 3 2
ret 0:4:5 1
block 0:3:32 1
end
'''


# ================================================================ writing the files
def write_test(nm):
    src = SEA[nm]
    ast = lines(AST[nm]) if isinstance(AST[nm], str) else AST[nm]
    check_positions(nm, src, ast)
    hir1 = HIR1[nm]
    for ln in lines(hir1):
        op = ln.split(' ')[0]
        # .hir = .hir1: no cref or cn (3.5.7 step 1), no constant-only subtree that step 2 folds
        # (checked: no cvt, un or arithmetic bin whose operands are all ci/cf), every function
        # reachable (each is called, checked below)
        assert op not in ('cref', 'cn'), (nm, ln)
    recs = lines(hir1)
    for k, ln in enumerate(recs):
        op = ln.split(' ')[0]
        if op in ('cvt', 'un') and recs[k - 1].split(' ')[0] in ('ci', 'cf'):
            raise AssertionError((nm, 'foldable', ln))
        if op == 'bin' and ln.split(' ')[3] in ('add', 'sub', 'mul', 'div') and \
                recs[k - 1].split(' ')[0] in ('ci', 'cf') and recs[k - 2].split(' ')[0] in ('ci', 'cf'):
            raise AssertionError((nm, 'foldable', ln))
        if op == 'powk' and recs[k - 1].split(' ')[0] == 'cf':
            raise AssertionError((nm, 'foldable', ln))
        if op == 'lib' and ln.split(' ')[3] == 'sqrt' and recs[k - 1].split(' ')[0] == 'cf':
            raise AssertionError((nm, 'foldable', ln))
    tree_check(nm, recs, 'H H1'.split())
    type_order_check(nm, recs)
    fids = {int(ln.split(' ')[1]) for ln in recs if ln.startswith('fn ')}
    called = {1} | {int(ln.split(' ')[3]) for ln in recs if ln.startswith('call ')}
    assert fids == called, (nm, 'unreachable function', fids, called)
    write(nm + '.sea', src)
    write(nm + '.ast', dump(nm, '\n'.join(ast)))
    write(nm + '.hir1', dump(nm, hir1))
    write(nm + '.hir', dump(nm, hir1))
    write(nm + '.hirl', dump(nm, HIRL[nm]()))
    write(nm + '.lir1', dump(nm, number_regs(LIR1[nm])))
    write(nm + '.out', OUT[nm])
    RG.make(nm)


KW = {'let': 'let', 'var': 'var', 'if': 'if', 'while': 'while', 'for': 'for', 'return': 'return',
      'block': '{', 'str': '"', 'break': 'break', 'continue': 'continue', 'ref': 'ref',
      'dollar': '$', 'ifx': 'if', 'true': 'true', 'false': 'false', 'neg': '-', 'all': ':',
      'array': '[', 'rangev': '('}


def check_positions(name, src, recs):
    """3.3 positions: each record's position is the first token of its source text."""
    src_lines = src.split('\n')

    def at(pos, text):
        _, ln, col = (int(x) for x in pos.split(':'))
        s = src_lines[ln - 1][col - 1:]
        assert s.startswith(text), (name, pos, text, s)

    for r in recs:
        p = r.split(' ')
        op = p[0]
        if op == 'prog':
            continue
        pos = p[1]
        if op in KW:
            at(pos, KW[op])
        elif op in ('name', 'pname', 'type'):
            at(pos, p[2])
        elif op == 'param':
            at(pos, 'ref' if p[3] == '1' else p[2])
        elif op == 'fn':
            at(pos, 'fn')
        elif op == 'int':
            at(pos, str(int(p[2])))
        elif op == 'float':
            assert src_lines[int(pos.split(':')[1]) - 1][int(pos.split(':')[2]) - 1].isdigit(), r
        elif op in ('call', 'index', 'bin', 'asg', 'cstmt', 'dot', 'row', 'range', 'pskip',
                    'ptuple'):
            c = src_lines[int(pos.split(':')[1]) - 1][int(pos.split(':')[2]) - 1]
            assert c != ' ', r
            if op == 'ptuple':
                assert c == '(', r
            if op == 'pskip':
                assert c == '_', r
        if op == 'for':
            at(p[3], p[2])


def tree_check(nm, recs, sets):
    """3.3: every record against passes.txt, the post-order stack; per function the locals
    and their types (each lv of a declared local with its type)."""
    stack, nloc, lt = [], 0, {}
    for ln in recs:
        op, v, pops = parse_rec(nm, sets, ln)
        if op in NOT_NODES:
            if op == 'fn':
                lt = {}
            if op in ('par', 'loc'):
                lt[len(lt) + 1] = int(v['ty'])
            continue
        if op == 'lv':
            assert lt[int(v['lid'])] == int(v['ty']), (nm, 'lv type', ln)
        assert len(stack) >= pops, (nm, 'stack underflow', ln)
        del stack[len(stack) - pops:]
        if op in ('end', 'cn'):
            assert not stack, (nm, ln)
            continue
        stack.append(op)
    assert not stack, nm


def type_order_check(nm, recs):
    """3.5.1 "Numbering": the type ids from 10 in order of first reference by the records after
    the table (fields left to right), a type's components numbered first; only referenced types."""
    tab, k = {}, 0
    while recs[k].split(' ')[0] in TYPE_RECS | {'fd'}:
        p = recs[k].split(' ')
        if p[0] in ('tvec', 'tmat'):
            tab[int(p[1])] = [int(p[2])]
        elif p[0] in ('tfvec', 'tfmat'):
            tab[int(p[1])] = [int(p[2])]
        elif p[0] == 'ttuple':
            tab[int(p[1])] = [int(t) for t in p[3:]]
        k += 1
    order = []

    def number(t):
        if t < 10 or t in order:
            return
        for c in tab[t]:
            number(c)
        order.append(t)

    for ln in recs[k:]:
        op = ln.split(' ')[0]
        fmt = None
        for s in ('H', 'H1', 'HF'):
            if (s, op) in RECS:
                fmt = RECS[(s, op)][1]
        vals = ln.split(' ')[1:]
        j = 0
        cnts = {}
        for fname, typ, _, cnt in fmt:
            n = 1 if cnt is None else int(cnts[cnt])
            for _ in range(n):
                if typ == 'ty' and vals[j] != '-':
                    number(int(vals[j]))
                if typ == 'u':
                    cnts[fname] = vals[j]
                j += 1
    assert order == sorted(tab) == list(range(10, 10 + len(tab))), (nm, 'type numbering', order)


def main_write():
    for nm in NAMES:
        write_test(nm)
    write('res_err_array.sea', SEA['res_err_array'])
    old = read('res_err_array.ast')
    write('res_err_array.hir1', dump('res_err_array', RES_ERR_ARRAY_HIR1))
    RG.make('res_err_array')
    assert read('res_err_array.ast') == old, 'res_err_array.ast changes with its comment only'


# ================================================================ the self-check
# Every .hirl and .lir1 this script writes is read back and checked against include/passes.txt
# (sets H HF HL for .hirl, L for .lir1: fields, field types, enumeration words, counts) and the
# rules of DESIGN.md 3.3 (post-order trees), 3.5.1, 3.5.4 and 3.5.9 (types, locals, positions,
# "What the passes validate" with R1-R11 and R10), and for .lir1 the numbering of 3.6.1
# (registers), 3.6.2 (labels), 3.6.3 (slots) and 3.6.4 (blocks), the rcall entries of rt.inc and
# the calls against their func records. This is a check of the hand-written files, not a
# derivation of them.
NOT_NODES = {'tvec', 'tmat', 'tfvec', 'tfmat', 'tstruct', 'trec', 'ttuple', 'tptr', 'fd', 'inst',
             'fn', 'par', 'loc'}                                   # DESIGN.md 3.3
REWRITTEN_LIB = {'zeros', 'ones', 'filled', 'len', 'rows', 'cols', 'numel'}   # 3.5.9 L1-L3
TYPE_RECS = {'tvec', 'tmat', 'tfvec', 'tfmat', 'tstruct', 'trec', 'ttuple'}


def load_formats():
    recs, enums = {}, {}
    with open(os.path.join(ROOT, 'include', 'passes.txt')) as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith(';'):
                continue
            p = line.split(' ')
            if p[0] == 'enum':
                enums[p[1]] = set(p[2:])
            elif p[0] == 'rec':
                fields = []
                for f in p[5:]:
                    nm, typ = f.split(':')
                    cnt = None
                    if '*' in typ:
                        typ, cnt = typ.split('*')
                    opt = typ.endswith('?')
                    fields.append((nm, typ.rstrip('?'), opt, cnt))
                recs[(p[1], p[3])] = (p[4], fields)
    return recs, enums


def load_errors():
    """Run-time errors of include/errors.inc: code name -> number of argument slots (an `h`
    shape takes 2 slots, every other letter 1: 2.6.2, 4.8)."""
    errs = {}
    with open(os.path.join(ROOT, 'include', 'errors.inc')) as fh:
        for line in fh:
            m = re.match(r'^    \\m (\d+), (\w+), (\w+), [^,]+, ([a-z-]+), ', line)
            if m and m.group(3) == 'R':
                args = m.group(4)
                errs[m.group(2)] = 0 if args == '-' else sum(2 if ch == 'h' else 1 for ch in args)
    return errs


def load_entries():
    ents = {}
    with open(os.path.join(ROOT, 'include', 'rt.inc')) as fh:
        for line in fh:
            m = re.match(r'^    \\m \d+, \w+, (\w+), ([S-]), ([a-z-]+), ([a-z-]+)$', line.rstrip())
            if m:
                ents[m.group(1)] = (m.group(2) == 'S', '' if m.group(3) == '-' else m.group(3),
                                    '' if m.group(4) == '-' else m.group(4))
    return ents


RECS, ENUMS = load_formats()
ERRS = load_errors()
ENTS = load_entries()
assert ERRS['SHAPE_MISMATCH'] == 4 and ERRS['ARRAY_SIZE'] == 1 and ENTS['sea_arr_new_u'][0]
RE_U = re.compile(r'^(0|[1-9][0-9]{0,8})$')
RE_I = re.compile(r'^(0|-?[1-9][0-9]{0,8}|#[0-9A-F]{16})$')
RE_F = re.compile(r'^#[0-9A-F]{16}$')
RE_POS = re.compile(r'^0:[1-9][0-9]*:[1-9][0-9]*$')
RE_SITE = re.compile(r'^0:[1-9][0-9]*$')
RE_REG = {'ri': r'i', 'rf': r'f', 'rp': r'p', 'rx': r'x', 'ry': r'y', 'rm': r'm',
          'reg': r'[ifpxym]'}


def field_ok(typ, v):
    if typ == 'u':
        return RE_U.match(v)
    if typ == 'i':
        return RE_I.match(v)
    if typ == 'f':
        return RE_F.match(v)
    if typ == 'pos':
        return RE_POS.match(v)
    if typ == 'site':
        return RE_SITE.match(v)
    if typ in ('ty', 'lid', 'fid', 'cid', 'iid', 'blk'):
        return RE_U.match(v) and v != '0'
    if typ == 's':
        return v == '%' or re.match(r'^([\x21-\x24\x26-\x7e]|%[0-9A-F]{2})+$', v)
    if typ == 'fl':
        return v == '-' or re.match(r'^l?p?s?z?a?$', v)
    if typ == 'lab':
        return re.match(r'^d[1-9][0-9]*$', v)
    if typ == 'slot':
        return re.match(r'^s[1-9][0-9]*$', v)
    if typ in RE_REG:
        return re.match('^' + RE_REG[typ] + r'[1-9][0-9]*$', v)
    if typ in ENUMS:
        return v in ENUMS[typ]
    raise AssertionError('unknown field type ' + typ)


def parse_rec(name, sets, line):
    """Checks one body record against passes.txt; returns (op, {field: value or list}, pops)."""
    p = line.split(' ')
    op = p[0]
    fmt = None
    for s in sets:
        if (s, op) in RECS:
            fmt = RECS[(s, op)]
            break
    assert fmt is not None, (name, 'record not in sets %s' % sets, line)
    vals, k = {}, 1
    for fname, typ, opt, cnt in fmt[1]:
        n = 1 if cnt is None else int(vals[cnt])
        got = []
        for _ in range(n):
            assert k < len(p), (name, 'missing field ' + fname, line)
            v = p[k]
            k += 1
            assert (opt and v == '-') or field_ok(typ, v), \
                (name, 'bad field %s:%s' % (fname, typ), line)
            got.append(v)
        vals[fname] = got[0] if cnt is None else got
    assert k == len(p), (name, 'extra fields', line)
    pops = 0
    for t in fmt[0].split('+'):
        pops += int(t) if t.isdigit() else int(vals[t])
    return op, vals, pops


def split_file(name, text, src_lines):
    lns = text.split('\n')
    assert lns[-1] == '' and lns[-2] == '#end', (name, 'no #end')
    head = lns[:3]
    assert head == ['#sea 1', '#target arm64-macos', '#file %s.sea' % name], (name, head)
    body = lns[3:-2]
    for ln in body:
        assert ln and ' ' not in (ln[0], ln[-1]) and '  ' not in ln, (name, ln)
        assert all(0x20 <= ord(ch) <= 0x7E for ch in ln), (name, ln)
        for m in re.finditer(r'\b0:([0-9]+):([0-9]+)\b', ln):
            ln_no, col = int(m.group(1)), int(m.group(2))
            assert ln_no <= len(src_lines), (name, ln)
            assert col <= len(src_lines[ln_no - 1]), (name, 'column beyond its line', ln)
    return body


class Node:
    def __init__(self, op, v, kids, idx, parent=None):
        self.op, self.v, self.kids, self.idx, self.parent = op, v, kids, idx, parent


def check_hirl(name):
    """DESIGN.md 3.5.9 "What the passes validate" (sealower's list, R1-R11, R10) and 3.5.4/3.5.9
    numbering, on the written NAME.hirl."""
    text = read(name + '.hirl')
    src = read(name + '.sea').split('\n')
    hir = read(name + '.hir')
    body = split_file(name, text, src)
    assert text.split('\n')[:3] == hir.split('\n')[:3], (name, 'header not copied (3.2)')
    hir_types = [ln for ln in hir.split('\n')[3:] if ln.split(' ')[0] in TYPE_RECS | {'fd'}]
    types = {1: ('void',), 2: ('s',), 3: ('s',), 4: ('s',), 5: ('str',)}
    for t in range(6, 10):
        types[t] = ('h',)
    i = 0
    while i < len(body) and body[i].split(' ')[0] in TYPE_RECS | {'fd', 'tptr'}:
        i += 1
    table, rest = body[:i], body[i:]
    ntab = len(hir_types)
    assert table[:ntab] == hir_types, (name, 'type table differs from sea.hir')
    last = 9
    for ln in table:
        op, v, _ = parse_rec(name, 'H HF HL'.split(), ln)
        if op in ('tvec', 'tmat'):
            types[int(v['id'])] = ({'tvec': 'v', 'tmat': 'm'}[op], int(v['elt']))
        elif op == 'tfvec':
            types[int(v['id'])] = ('fv', int(v['elt']), int(v['n']))
        elif op == 'tfmat':
            types[int(v['id'])] = ('fm', int(v['elt']), int(v['r']), int(v['c']))
        elif op == 'ttuple':
            types[int(v['id'])] = ('t', [int(x) for x in v['t']])
        elif op == 'tptr':
            types[int(v['id'])] = ('ptr', int(v['elt']))
        if op != 'fd':
            assert int(v['id']) == last + 1, (name, 'type ids not consecutive', ln)
            last = int(v['id'])
    tptrs = [int(ln.split(' ')[1]) for ln in table[ntab:]]
    assert all(ln.startswith('tptr ') for ln in table[ntab:]), name
    elts = [types[t][1] for t in tptrs]
    assert len(set(elts)) == len(elts), (name, 'one tptr per element type')

    def rank(t):
        return {'v': 1, 'fv': 1, 'm': 2, 'fm': 2}.get(types[t][0], 0)

    def is_arr(t):
        return types[t][0] in ('v', 'm', 'fv', 'fm')

    def is_dyn(t):
        return types[t][0] in ('v', 'm')

    def is_scalar(t):
        return t in (2, 3, 4)

    first_ref = []
    stack, fn, out_fns = [], None, []
    hir_fns = {}
    cur = None
    for ln in hir.split('\n')[3:]:
        if ln.startswith('fn '):
            cur = int(ln.split(' ')[1])
            hir_fns[cur] = []
        if cur is not None and ln and ln != '#end':
            hir_fns[cur].append(ln)
    hirl_fns = {}
    cur = None
    for ln in rest:
        if ln.startswith('fn '):
            cur = int(ln.split(' ')[1])
            hirl_fns[cur] = []
        hirl_fns[cur].append(ln)
    for k, ln in enumerate(rest):
        op, v, pops = parse_rec(name, 'H HF HL'.split(), ln)
        assert op != 'fore', (name, 'fore in sea.hirl', ln)
        assert not (op == 'lib' and v['name'] in REWRITTEN_LIB), (name, 'rewritten lib', ln)
        assert op not in ('view', 'arr', 'row', 'dyn', 'fix', 'all'), (name, 'R10', ln)
        fmt = None
        for s in ('H', 'HF', 'HL'):
            if (s, op) in RECS:
                fmt = RECS[(s, op)][1]
        for fname, typ, _, cnt in fmt:
            vs = v[fname] if cnt else [v[fname]]
            for x in vs:
                if typ == 'ty' and x != '-' and int(x) in tptrs and int(x) not in first_ref:
                    first_ref.append(int(x))
        if op == 'fn':
            fn = {'np': int(v['np']), 'nl': int(v['nl']), 'locs': [], 'nodes': [],
                  'fid': int(v['fid'])}
            out_fns.append(fn)
            continue
        if op == 'par':
            fn['locs'].append((v['name'], int(v['ty']), v['mode'], None))
            continue
        if op == 'loc':
            fn['locs'].append((v['name'], int(v['ty']), v['mut'], v['pos']))
            continue
        assert op not in NOT_NODES, (name, ln)
        kids = stack[len(stack) - pops:] if pops else []
        assert len(kids) == pops, (name, 'stack underflow', ln)
        del stack[len(stack) - pops:]
        node = Node(op, v, kids, k)
        for c in kids:
            c.parent = node
        fn['nodes'].append(node)
        if op == 'end':
            assert not stack and kids[0].op == 'block', (name, 'end', ln)
            fn['body'] = kids[0]
            continue
        stack.append(node)
    assert not stack, name
    assert first_ref == tptrs, (name, 'tptr ids not in order of first reference', first_ref, tptrs)

    nchanged = 0
    for fn in out_fns:
        locs = fn['locs']
        assert len(locs) == fn['np'] + fn['nl'], (name, 'np/nl')
        lnames = [x[0] for x in locs]
        ls = [j for j, x in enumerate(lnames) if x.startswith('.l')]
        hl_ops = {o for (st_, o) in RECS if st_ == 'HL'}
        if not ls and not any(r.split(' ')[0] in hl_ops for r in hirl_fns[fn['fid']]):
            assert hirl_fns[fn['fid']] == hir_fns[fn['fid']], (name, 'unchanged function differs')
        else:
            nchanged += 1
        if ls:
            assert ls == list(range(ls[0], len(locs))), (name, '.l locals last (3.5.4)')
            assert [lnames[j] for j in ls] == ['.l%d' % (q + 1) for q in range(len(ls))], name
        lt = {j + 1: x[1] for j, x in enumerate(locs)}
        is_ref = {j + 1: x[2] == 'ref' for j, x in enumerate(locs)}

        def ty_of(n):
            if n.op == 'lv':
                assert int(n.v['ty']) == lt[int(n.v['lid'])], (name, 'lv type', n.v)
            return int(n.v['ty']) if 'ty' in n.v and n.v['ty'] != '-' else None

        def isl(lid):
            return lnames[lid - 1].startswith('.l')

        tmp_bound, decl, assigned, rcnt_locals, bind_l = {}, [], {}, set(), set()
        for n in fn['nodes']:
            t = ty_of(n)
            kt = [ty_of(c) for c in n.kids]
            if n.op == 'tmp':
                L = int(n.v['lid'])
                assert L not in tmp_bound, (name, 'tmp bound twice', L)
                tmp_bound[L] = n.idx
                assert lt[L] == kt[0], (name, 'tmp type != child type', n.v)
                if types.get(lt[L], ('',))[0] == 'ptr':
                    assert n.kids[0].op in ('adat', 'cdat'), (name, 'tptr tmp', n.v)
                if isl(L):
                    decl.append((L, 'let', n.v['pos']))
            elif n.op == 'bind' and isl(int(n.v['lid'])):
                L = int(n.v['lid'])
                decl.append((L, 'let', n.v['pos']))
                bind_l.add(L)
                assert lt[L] == kt[0], (name, 'bind type', n.v)
                if is_arr(lt[L]):                     # R8: an array .l local only in a block
                    assert is_dyn(lt[L]), (name, 'R8: a fixed-size .l local bound by bind', n.v)
                    assert n.parent.op == 'block', (name, 'R8: array .l bind outside a block')
            elif n.op == 'tbind' and any(x != '-' and isl(int(x)) for x in n.v['lid']):
                # R8: a tbind of .l locals only as the first statement of an L12 block, each
                # local of its result's type
                assert n.parent.op == 'block' and n.parent.kids[0] is n, (name, 'R8 tbind', n.v)
                comps = types[kt[0]][1]
                for x, ct in zip(n.v['lid'], comps):
                    if x != '-':
                        assert isl(int(x)) and lt[int(x)] == ct, (name, 'tbind .l type', n.v)
                        decl.append((int(x), 'let', n.v['pos']))
            elif n.op == 'tasg':
                # R10: no tasg with an L6 target or a cv other than 0 or a scalar 1
                for c, cv in zip(n.kids[:-1], n.v['cv']):
                    assert int(cv) == 0 or (int(cv) == 1 and is_scalar(ty_of(c))), (name, 'R10 cv')
                    assert not (c.op == 'idx' and not all(is_scalar(ty_of(i)) for i in c.kids[1:])), \
                        (name, 'R10 tasg selection target')
            elif n.op == 'rcnt':
                Ll, Le = int(n.v['l']), int(n.v['e'])
                assert lt[Ll] == 3 and lt[Le] == 2, (name, 'rcnt local types (R6)', n.v)
                assert kt == [3, 3, 3], (name, 'rcnt children')
                rcnt_locals |= {Ll, Le}
                decl.append((Ll, 'let', n.v['pos']))
                decl.append((Le, 'let', n.v['pos']))
            elif n.op == 'hloop':
                K = int(n.v['lid'])
                assert locs[K - 1][2] == 'for' and lt[K] == 3, (name, 'hloop local', n.v)
                assert kt[:3] == [3, 3, 3], (name, 'hloop range')
                assert n.kids[3].op == 'block', name
                decl.append((K, 'for', n.v['pos']))
            elif n.op == 'ext':
                a = kt[0]
                assert t == 3 and (is_arr(a) or a == 5), (name, 'ext', n.v)
                assert int(n.v['dim']) < max(rank(a), 1), (name, 'ext dim', n.v)
            elif n.op == 'adat':
                a = kt[0]
                assert is_arr(a) and types[t] == ('ptr', types[a][1]), (name, 'adat', n.v)
            elif n.op == 'eld':
                assert types[kt[0]] == ('ptr', t) and kt[1] == 3, (name, 'eld', n.v)
                assert int(n.v['sc']) == ES[t], (name, 'eld scale')
            elif n.op == 'est':
                assert types[kt[1]] == ('ptr', kt[0]), (name, 'est', n.v)
                assert kt[2] == 3 and int(n.v['sc']) == ES[kt[0]], (name, 'est index/scale')
            elif n.op == 'anew':
                if is_dyn(t):
                    assert rank(t) == int(n.v['r']) and all(x == 3 for x in kt), (name, 'anew')
                else:
                    assert is_arr(t) and n.v['r'] == '0' and n.v['z'] == '0', (name, 'anew R1')
            elif n.op == 'wbin':
                assert t == 3 and all(x in (2, 3) for x in kt), (name, 'wbin (R7)', n.v)
            elif n.op == 'chkb':
                assert kt == [3, 3], (name, 'chkb')
            elif n.op == 'chk':
                assert kt[0] == 2 and n.v['err'] in ERRS, (name, 'chk', n.v)
                assert ERRS[n.v['err']] == int(n.v['n']), (name, 'chk slots', n.v)
            elif n.op == 'cow':
                c = n.kids[0]
                assert c.op == 'lv' and is_dyn(kt[0]) and not isl(int(c.v['lid'])), (name, 'cow')
            elif n.op == 'mcpy':
                assert types[kt[0]][0] == 'ptr' and types[kt[1]][0] == 'ptr' and kt[2] == 3, \
                    (name, 'mcpy')
            elif n.op == 'cdat':
                assert int(n.v['n']) >= 1 and types[t][0] == 'ptr', (name, 'cdat')
                for c in n.kids:
                    assert c.op in ('ci', 'cf', 'cb') and ty_of(c) == types[t][1], (name, 'cdat')
            elif n.op == 'xblk':
                assert t == kt[-1], (name, 'xblk type', n.v)
            elif n.op == 'rng':
                assert n.parent is None or True
            elif n.op == 'idx':
                assert n.kids[0].op != 'view' and all(x == 3 for x in kt[1:]), (name, 'R10 idx')
            elif n.op in ('bin', 'un', 'cvt', 'powk', 'emap'):
                assert all(x is None or not is_arr(x) for x in kt), (name, 'R10 array op', n.v)
            elif n.op == 'lib':
                assert all(x is None or not is_arr(x) for x in kt) or \
                    n.v['name'] in ('printf',), (name, 'R10 array lib', n.v)
            if n.op == 'asg':
                tg = n.kids[0]
                if n.v['op'] != 'set':
                    assert not is_arr(kt[0]), (name, 'R10 compound array asg')
                if tg.op == 'lv' and isl(int(tg.v['lid'])):
                    L = int(tg.v['lid'])
                    assert n.v['op'] == 'set' and is_scalar(lt[L]) and L in bind_l, \
                        (name, 'asg to a .l local (R8)', n.v)
            if n.op in ('bind', 'forr'):
                assigned.setdefault(int(n.v['lid']), []).append(n.op)
            elif n.op == 'tbind':
                for x in n.v['lid']:
                    if x != '-':
                        assigned.setdefault(int(x), []).append('tbind')
            elif n.op in ('asg', 'tasg', 'rarg'):
                for c in n.kids:
                    if c.op == 'lv':
                        assigned.setdefault(int(c.v['lid']), []).append(n.op)
                    if n.op != 'tasg':
                        break
        for n in fn['nodes']:
            if n.op == 'rng':
                assert n.parent.op == 'forr' and n.parent.kids[0] is n, (name, 'R10 rng')
            if n.op == 'lv' and int(n.v['lid']) in tmp_bound:
                assert tmp_bound[int(n.v['lid'])] < n.idx, (name, 'lv before its tmp', n.v)
            if n.op in ('tbind', 'tasg', 'tret') and n.kids[-1].op == 'lib':
                assert n.kids[-1].v['name'] != 'ind2sub' or \
                    not any(is_arr(ty_of(c)) for c in n.kids[-1].kids), (name, 'R10 ind2sub')
        assert not (set(assigned) & set(tmp_bound)), (name, 'a tmp local is assigned')
        for L in rcnt_locals:
            assert L not in assigned, (name, 'an rcnt local is written elsewhere', L)
        ldecl = [d for d in decl if isl(d[0])]
        assert [d[0] for d in ldecl] == [j + 1 for j in ls], (name, '.l order', ldecl, ls)
        for L, mut, pos in ldecl:
            assert locs[L - 1][2] == mut and locs[L - 1][3] == pos, (name, '.l loc', L, locs[L - 1])
    return len(body), nchanged


def check_lir1(name):
    """passes.txt set L; registers (3.6.1), labels (3.6.2), slots (3.6.3) and blocks (3.6.4)
    numbered in order; rcall against rt.inc's entries, call against the func records, chk slots."""
    text = read(name + '.lir1')
    body = split_file(name, text, read(name + '.sea').split('\n'))
    funcs = {}
    for ln in body:
        if ln.startswith('func '):
            op, v, _ = parse_rec(name, ['L'], ln)
            funcs[v['name']] = ([x[0] for x in v['par']], v['cls'])
    labels, nlab = [], 0
    infunc = False
    for ln in body:
        op, v, _ = parse_rec(name, ['L'], ln)
        if op == 'func':
            infunc, seen, slots, nslot = True, 0, [], 0
            regs, blocks, open_ = set(), 0, []
            nres = len(v['cls'])
        if infunc:
            for tok in ln.split(' ')[1:]:
                if re.match(r'^[ifpxym][1-9][0-9]*$', tok) and tok[1:] not in regs:
                    seen += 1
                    assert int(tok[1:]) == seen, (name, 'register numbering', ln)
                    regs.add(tok[1:])
                if re.match(r'^d[1-9][0-9]*$', tok) and op == 'la' and tok not in labels:
                    labels.append(tok)
                    assert tok == 'd%d' % len(labels), (name, 'label numbering', ln)
            if op == 'slot':
                nslot += 1
                assert v['id'] == 's%d' % nslot, (name, 'slot numbering', ln)
            if op == 'sa':
                slots.append(v['slot'])
                assert slots[-1] == 's%d' % len(slots), (name, 'sa order', ln)
            if op in ('loop', 'do', 'if', 'ifz'):
                blocks += 1
                assert int(v['b']) == blocks, (name, 'block numbering', ln)
                open_.append((op, blocks))
            elif op in ('endloop', 'enddo', 'endif'):
                want = {'endloop': ('loop',), 'enddo': ('do',), 'endif': ('if', 'ifz')}[op]
                assert open_ and open_[-1][0] in want and open_[-1][1] == int(v['b']), \
                    (name, 'block nesting', ln)
                open_.pop()
            elif op == 'else':
                assert open_[-1][0] in ('if', 'ifz') and open_[-1][1] == int(v['b']), (name, ln)
            elif op in ('exit', 'next'):
                assert any(b == int(v['b']) and o in ('loop', 'do') for o, b in open_), (name, ln)
            elif op == 'ret':
                assert int(v['n']) == nres, (name, 'ret count', ln)
            elif op == 'rcall':
                site, ar, rs = ENTS[v['entry']]
                assert (v['site'] != '-') == site, (name, 'rcall site', ln)
                assert ''.join(r[0] for r in v['a']) == ar, (name, 'rcall args', ln)
                assert int(v['nr']) in (0, len(rs)) and \
                    ''.join(r[0] for r in v['d']) == rs[:int(v['nr'])], (name, 'rcall results', ln)
            elif op == 'call':
                pc, rc = funcs[v['name']]
                assert ''.join(r[0] for r in v['a']) == ''.join(pc), (name, 'call args', ln)
                assert int(v['nr']) in (0, len(rc)) and \
                    [r[0] for r in v['d']] == rc[:int(v['nr'])], (name, 'call results', ln)
            elif op == 'chk':
                assert ERRS[v['err']] == int(v['n']), (name, 'chk slots', ln)
        if op == 'endfunc':
            assert len(slots) == nslot and not open_, (name, 'slots/blocks', nslot, slots)
            infunc = False
        if op in ('str', 'fmt', 'dat', 'slay'):
            nlab += 1
            assert v['lab'] == 'd%d' % nlab, (name, 'data record order', ln)
    assert nlab == len(labels), (name, 'labels')
    return len(body)


# ================================================================ the agreed examples (6.2)
def design_example(rule):
    """The first code block of 3.6.6 rule `rule` in DESIGN.md, as written."""
    with open(os.path.join(ROOT, 'docs', 'DESIGN.md')) as fh:
        doc = fh.read().split('\n')
    lo = doc.index('#### 3.6.6 Canonical lowering of scalar code')
    hi = doc.index('#### 3.6.7 Example')
    start = [k for k in range(lo, hi) if re.match(r'^%d\. \*\*' % rule, doc[k])]
    assert len(start) == 1, rule
    k = start[0]
    while doc[k].strip() != '```':
        k += 1
    k += 1
    block_ = []
    while doc[k].strip() != '```':
        block_.append(doc[k].strip())
        k += 1
    for ln in block_:
        for tok in ln.split(' '):
            # 3.1 field type i: a decimal is written only for -10^9 < v < 10^9
            assert not (re.match(r'^-?[0-9]+$', tok) and not -10 ** 9 < int(tok) < 10 ** 9), \
                ('rule %d example: a decimal outside the 3.1 range' % rule, ln)
    return block_


def check_example(rule, nm):
    ex = design_example(rule)
    lir = read(nm + '.lir1').split('\n')
    n = len(ex)
    hits = [k for k in range(len(lir) - n + 1) if lir[k:k + n] == ex]
    assert len(hits) == 1, (nm, 'rule %d example not verbatim in the golden' % rule)


# ================================================================ run
main_write()
nrec, nhirl, nch = 0, 0, 0
for nm in NAMES:
    a, b = check_hirl(nm)
    nrec += a
    nch += b
    nrec += check_lir1(nm)
    nhirl += 1
for rule in (20, 21, 22, 25, 28):
    check_example(rule, 'arr_rule%d' % rule)
print('dump4e_cases: %d dump tests (%d functions rewritten), %d records checked; agreed examples '
      'verbatim: arr_rule20 arr_rule21 arr_rule22 arr_rule25 arr_rule28; res_err_array rewritten'
      % (len(NAMES), nch, nrec))
