"""Phase-7 dump goldens, part 1: sub-phase 7b, package T2 (DESIGN.md 6.2 "Phase-7 tests", "Neutral
7b": "the 6c `elem6_*` goldens given their `NAME.hirf` (L19's output now `seafuse`'s)"; 2.12.3
`sea.hirf` rules (1)-(5) and "L19 in `seafuse`"; 2.11.4 L19 and `ind2sub` with an array `r`;
3.5.9 "Types", "Locals", the 4e notation, L7 (rule 22's checks and nest), L11's statement forms;
Decision 109; lead decision L-ek). Part 4 (sub-phase 7c, package T2): the NAME.hirf of the
`fuse7_*` dumps (DESIGN.md 6.2 "`fuse7_*` dumps"; 2.12.4 F1-F5), see "part 4" below.

Run with `timeout 120 uv run --no-project python tests/vectors/dump7_cases.py [--out DIR]
[--check]`. It writes its goldens in tests/passes/ (or DIR); with --check it writes nothing and only
checks that every file it owns is what it would write. Its inputs are the committed goldens
NAME.hir (and, for the cross-check, NAME.hirl) of tests/passes/ and include/passes.txt.

Part 1, the scan: every tests/passes/*.hir is parsed (the record formats of passes.txt); a file that
holds an `emap` or a `lib ind2sub` whose first argument (r) is an array is one L19 rewrites, so its
test needs a NAME.hirf; every other file holds none of the constructs `seafuse` rewrites in 7b (7b's
`seafuse` performs no F1-F4, only L19), so its sea.hirf is its sea.hir byte for byte (2.12.3, L-ek)
and it gets no NAME.hirf (the fuse7_* files are part 4's and are not scanned; from 7c other tests
may have a NAME.hirf of F1-F4 that this generator does not own). The scan asserts that the files
needing one are exactly elem6_inst,
elem6_k5 and elem6_vec (ew_ind2sub's r is a scalar: L11, which stays `sealoop`'s).

Part 2, the NAME.hirf of elem6_k5 and elem6_vec (elem6_inst's NAME.hirf is 7c's, written by
hand with F1/F5 in 7c package T2b, so this generator no longer owns it): their NAME.hir with
* rule (1): no `inst` record (the instances were used by L19 only) and no `emap`: each `emap` and the
  statement holding it rewritten by L19 exactly as 2.11.4 specifies it (steps (1)-(5), L-ck, L-do),
  except that the per-element application is written as the `call P ty1 fid n` record of the
  elemental function (2.12.3 "L19 in seafuse": `sealoop`'s L20 inlines it later); the `fn` records
  of kind `elem` and every other `call` (a scalar application) stay;
* rule (2): of the HL records only `tptr xblk tmp hloop ext adat eld est anew wbin chk` occur;
* rule (3): `tptr` of each element type whose address the file takes appended to the type table,
  numbered on from sea.hir's last id in order of first reference (3.5.9 "Types");
* rule (4): the new locals are `.l` locals with `loc` records (3.5.9 "Locals": mut `let` for `tmp`,
  `bind`, `tbind`, `for` for an `hloop`; the value's type; the emap's position P), numbered per
  function after the source locals in the order of their declaring records in file order
  (post-order: a `tmp` after its child, an `hloop` after its block, a `tbind` after its value);
  implementer reading: 2.12.3 does not say how `seafuse` numbers its `.l` locals in `sea.hirf`
  (only that `sealoop` renumbers them in `sea.hirl`); this generator uses the canonical file-order
  numbering of 3.5.9 for `sea.hirf` too; the `fn` record's nl counts them;
* every construct that only `sealoop` rewrites (L1 `zeros`, L2 `filled`, L3 `len`, L7 of the `cvt`
  of an array, L9 of a literal, L10 of `.col`) left as it stands in sea.hir: L19 binds such an
  argument by its `tmp Ai` and `sealoop` rewrites the subtree under it later (2.12.3 "`sealoop`
  from 7b").
The L19 model below is a transcription of 2.11.4 L19 with 3.5.9 L7's forms (the vector checks,
the matrix checks with the combined shape, the strides SI/SJ, DR before the operands' data, the
loops loop(N; K) and mloop(R, C; I, J) of the 4e-0/4e notation), the fixed-size result of L-do
(every kept home first, the extents read from the first kept home) and L11's statement forms for
k >= 2 (a `tbind` replaced in its own block followed by the `bind`s of its locals from the Rj, a
`tasg` a new `block P n` ending in the `asg P set` of each target with cv 0, an `eval` a new `block
P n` with nothing allocated and the body `eval P` of the call).

Part 3, the cross-check (never a source of the goldens): each NAME.hirf written is read back and
rewritten by a model of the `sealoop` rewrites its records still need (L1 `zeros`, L3 `len`, L20 of
every `call` of an `elem` function: L18 with L20's differences, 2.11.4; then the `elem` functions
dropped, L-cg) followed by Decision 109's renumbering of every `.l` local in file order of the
declaring records; the result must be the committed NAME.hirl byte for byte (elem6_vec and
elem6_k5). elem6_inst has no committed NAME.hirl (6c gave it none: its subject is pass 2b's
step 3), and its arguments need L2, L7, L9 and L10, which this model does not hold; its L19 output
was cross-checked outside this generator (the T2 report of 7b).

Part 4 (7c): for each test of FUSE7 (tests/passes/fuse7_*.sea and fuse7c2_*.sea, written by hand),
its NAME.hirf from its committed NAME.hir by the F1-F5 transcription below; which rewrite applies
to which statement is decided by hand from 2.12.4 and stated in FUSE7; the readings taken where
2.12.4 does not pin a detail are READINGS (R-a ... R-r, R-T2b-1 ... R-T2b-5). The NAME.hirl and
NAME.lir1 of these tests follow from NAME.hirf by the rewrites and lowering that 7c leaves
unchanged (sealoop, sealower); they are not written here (they were checked by running the 7b
sealoop and sealower on NAME.hirf, and each program built from them prints NAME.out with no live
object left).
"""

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
SRC_PASSES = os.path.join(ROOT, 'tests', 'passes')
PASSES = SRC_PASSES
if '--out' in sys.argv:
    PASSES = os.path.abspath(sys.argv[sys.argv.index('--out') + 1])
CHECK = '--check' in sys.argv

ESIZE = {4: 8, 3: 8, 2: 1}                      # 4.8: SEA_ESIZE_F64, _I64, _BOOL by type id
SHAPE_VEC = -1                                  # rt.inc SEA_SHAPE_VEC (the consts table)
ELEMENTAL_TYPES = (2, 3, 4)                     # bool, i64, f64: the elemental parameter types


def read(path):
    with open(path) as fh:
        return fh.read()


def write(name, text):
    """Write tests/passes/NAME (or DIR/NAME with --out); with --check compare with the committed."""
    if CHECK:
        assert read(os.path.join(SRC_PASSES, name)) == text, ('differs', name)
        return
    with open(os.path.join(PASSES, name), 'w') as fh:
        fh.write(text)


# ================================================================ record formats (passes.txt)
def load_formats():
    """op -> (pops expression, [(field name, field type, repeat count name or None)])."""
    fm = {}
    for ln in read(os.path.join(ROOT, 'include', 'passes.txt')).split('\n'):
        w = ln.split()
        if len(w) < 5 or w[0] != 'rec' or not w[1].startswith('H'):
            continue
        fields = []
        for f in w[5:]:
            m = re.match(r'(\w+):(\w+)(\?)?(?:\*(\w+))?$', f)
            fields.append((m.group(1), m.group(2), m.group(4)))
        fm[w[3]] = (w[4], fields)
    return fm


FMT = load_formats()
NONNODE = {'tvec', 'tmat', 'tfvec', 'tfmat', 'tstruct', 'trec', 'fd', 'ttuple', 'cn', 'inst', 'fn',
           'par', 'loc', 'tptr'}


def field_types(op, vals):
    """The type of each value of a record (repeated fields expanded)."""
    out, named = [], {}
    i = 0
    for name, ty, rep in FMT[op][1]:
        cnt = int(named[rep]) if rep else 1
        for _ in range(cnt):
            out.append(ty)
            if not rep:
                named[name] = vals[i]
            i += 1
    assert i == len(vals), (op, vals)
    return out, named


def pops(op, vals):
    expr = FMT[op][0]
    _, named = field_types(op, vals)
    return eval(re.sub(r'[a-z]+', lambda m: str(int(named[m.group(0)])), expr))


# ================================================================ trees, locals, types
class Loc:
    """A `.l` local: numbered when its function is written (3.5.9 "Locals")."""
    def __init__(self, ty, mut, pos):
        self.ty, self.mut, self.pos = ty, mut, pos


class TP:
    """The `tptr` type of element type elt, numbered when the file is written (3.5.9 "Types")."""
    def __init__(self, elt):
        self.elt = elt


class Node:
    def __init__(self, op, fields, kids=()):
        self.op, self.f, self.kids = op, list(fields), list(kids)


def N(op, *fields, kids=()):
    return Node(op, fields, kids)


def postorder(n, out):
    for k in n.kids:
        postorder(k, out)
    out.append(n)
    return out


class Func:
    def __init__(self, rec):
        self.rec = rec                          # the fn record's values
        self.pars, self.locs, self.body = [], [], None

    @property
    def nsrc(self):
        return len(self.pars) + len([x for x in self.locs if not isinstance(x, Loc)])


class File:
    """A HIR file: header lines, type records (values), functions."""
    def __init__(self, text):
        lines = text.rstrip('\n').split('\n')
        assert lines[-1] == '#end'
        self.head = [ln for ln in lines if ln.startswith('#') and ln != '#end']
        self.types, self.funcs = [], []
        self.tptr = {}                          # elt -> id of the tptr records read
        stack, fn, lmap = [], None, {}
        for ln in lines:
            if ln.startswith('#'):
                continue
            w = ln.split(' ')
            op, vals = w[0], w[1:]
            if op == 'fn':
                fn, lmap, stack = Func(vals), {}, []
                self.funcs.append(fn)
            elif op == 'par':
                fn.pars.append(vals)
            elif op == 'loc':
                if vals[0].startswith('.l'):
                    x = Loc(int(vals[1]) if vals[1].isdigit() else vals[1], vals[2], vals[3])
                    fn.locs.append(x)
                    lmap[str(len(fn.pars) + len(fn.locs))] = x
                else:
                    fn.locs.append(vals)
            elif op == 'end':
                assert len(stack) == 1 and stack[0].op == 'block', ln
                fn.body, fn = stack.pop(), None
            elif op in NONNODE:
                assert fn is None, ln
                self.types.append([op] + vals)
                if op == 'tptr':
                    self.tptr[int(vals[1])] = int(vals[0])
            else:
                fts, _ = field_types(op, vals)
                vals = [lmap.get(v, v) if t == 'lid' else v for v, t in zip(vals, fts)]
                k = pops(op, w[1:])
                kids = stack[len(stack) - k:] if k else []
                del stack[len(stack) - k:]
                stack.append(Node(op, vals, kids))
        self.ty = {}                            # type id -> record values
        for t in self.types:
            if t[0] in ('tvec', 'tmat', 'tfvec', 'tfmat', 'ttuple', 'tptr'):
                self.ty[int(t[1])] = t
        self.last_id = max([int(t[1]) for t in self.types if t[0] not in ('fd', 'inst')] + [5])

    # ---- type queries
    def is_array(self, t):
        return t in self.ty and self.ty[t][0] in ('tvec', 'tmat', 'tfvec', 'tfmat')

    def rank(self, t):
        return 2 if self.ty[t][0] in ('tmat', 'tfmat') else 1

    def fixed(self, t):
        return self.ty[t][0] in ('tfvec', 'tfmat')

    def elt(self, t):
        return int(self.ty[t][2])

    def comps(self, t):
        """The result types of a function or emap type: a ttuple's components, else [t]."""
        if t in self.ty and self.ty[t][0] == 'ttuple':
            return [int(x) for x in self.ty[t][3:]]
        return [] if t == 1 else [t]

    def inst(self, iid):
        for t in self.types:
            if t[0] == 'inst' and t[1] == str(iid):
                return int(t[2]), [int(x) for x in t[5:]]
        raise KeyError(iid)

    def func(self, fid):
        return next(f for f in self.funcs if f.rec[0] == str(fid))

    # ---- writing
    def text(self, hirf=True):
        """The file: header, types (no `inst`), each new `tptr` appended in order of first
        reference, the functions with their `.l` locals numbered in file order of declaring
        records (post-order) and nl counting them."""
        tids = dict(self.tptr)
        nxt = [max([self.last_id] + list(tids.values())) + 1]
        newt = []

        def tyv(v):
            if isinstance(v, F8T):
                if "F8" not in tids:
                    tids["F8"] = nxt[0]
                    newt.append("tfvec %d 4 8" % nxt[0])
                    nxt[0] += 1
                return str(tids["F8"])
            if isinstance(v, TP):
                if v.elt not in tids:
                    tids[v.elt] = nxt[0]
                    newt.append('tptr %d %d' % (nxt[0], v.elt))
                    nxt[0] += 1
                return str(tids[v.elt])
            return str(v)

        body = []
        for fn in self.funcs:
            order = postorder(fn.body, [])
            num, newlocs = {}, []
            for n in order:
                if n.op in ('tmp', 'bind', 'hloop', 'tbind', 'rcnt'):
                    fts, _ = field_types(n.op, [str(v) if not isinstance(v, (Loc, TP, F8T)) else '0'
                                                for v in n.f])
                    for v, t in zip(n.f, fts):
                        if t == 'lid' and isinstance(v, Loc):
                            assert v not in num, 'a local declared twice'
                            num[v] = fn.nsrc + 1 + len(newlocs)
                            newlocs.append(v)
            for x in fn.locs:
                assert not isinstance(x, Loc) or x in num, 'an undeclared .l local'
            rec = list(fn.rec)
            rec[5] = str(fn.nsrc - len(fn.pars) + len(newlocs))
            body.append('fn ' + ' '.join(rec))
            body += ['par ' + ' '.join(p) for p in fn.pars]
            body += ['loc ' + ' '.join(x) for x in fn.locs if not isinstance(x, Loc)]
            for i, x in enumerate(newlocs):
                body.append('loc .l%d %s %s %s' % (i + 1, tyv(x.ty), x.mut, x.pos))
            for n in order:
                vals = []
                for v in n.f:
                    if isinstance(v, Loc):
                        assert v in num, (n.op, 'reads an undeclared local')
                        vals.append(str(num[v]))
                    else:
                        vals.append(tyv(v))
                body.append(' '.join([n.op] + vals))
            body.append('end')
        types = [' '.join(t) for t in self.types if not (hirf and t[0] == "inst")] + newt
        return '\n'.join(self.head + types + body + ['#end']) + '\n'


def nodes_of(f):
    out = []
    for fn in f.funcs:
        postorder(fn.body, out)
    return out


def ntype(n):
    """The type of a value node (its second field)."""
    return int(n.f[1])


# ================================================================ part 1: the scan
def needs_hirf(f):
    for n in nodes_of(f):
        if n.op == 'emap':
            return 'emap'
        if n.op == 'lib' and n.f[2] == 'ind2sub' and f.is_array(ntype(n.kids[0])):
            return 'ind2sub with an array r'
    return None


def part1():
    found = {}
    for nm in sorted(os.listdir(SRC_PASSES)):
        if nm.endswith(".hir") and not nm.startswith("fuse7"):
            text = read(os.path.join(SRC_PASSES, nm))
            f = File(text)
            assert f.text(hirf=False) == text, (nm, "the reader and writer must keep a file byte for byte")
            why = needs_hirf(f)
            if why:
                found[nm[:-4]] = why
    assert sorted(found) == ['elem6_inst', 'elem6_k5', 'elem6_vec'], found
    return found


# ================================================================ part 2: L19 (2.11.4)
class Rewrite:
    """The nodes of one L19 rewrite at position P (every node and local it writes takes P)."""
    def __init__(self, P):
        self.P, self.stmts = P, []

    def tmp(self, ty, child):
        x = Loc(ty, 'let', self.P)
        self.stmts.append(N('tmp', self.P, x, kids=[child]))
        return x

    def lv(self, ty, x):
        return N('lv', self.P, ty, x)

    def ext(self, x, xty, d):
        return N('ext', self.P, 3, d, kids=[self.lv(xty, x)])

    def loop(self, n, body):
        """loop(N; K) { S } (3.5.9, 4e-0): `tmp Z = ci 0`; `if` (e = 0) `bin gt (lv N) (lv Z)`
        { `tmp O = ci 1`; `tmp L = wbin sub (lv N) (lv O)`; `hloop K (lv Z) (lv L) (lv O)` { S } };
        body(K) gives S. Returns the two statements."""
        P = self.P
        z = Loc(3, 'let', P)
        o = Loc(3, 'let', P)
        last = Loc(3, 'let', P)
        k = Loc(3, 'for', P)
        s = body(k)
        inner = [N('tmp', P, o, kids=[N('ci', P, 3, 1)]),
                 N('tmp', P, last, kids=[N('wbin', P, 3, 'sub', kids=[self.lv(3, n),
                                                                    self.lv(3, o)])]),
                 N('hloop', P, k, kids=[self.lv(3, z), self.lv(3, last), self.lv(3, o),
                                        N('block', P, len(s), kids=s)])]
        cond = N('bin', P, 2, 'gt', kids=[self.lv(3, n), self.lv(3, z)])
        return [N('tmp', P, z, kids=[N('ci', P, 3, 0)]),
                N('if', P, 0, kids=[cond, N('block', P, 3, kids=inner)])]


def l19(f, emap, kept):
    """L19 of `emap P T iid n` (2.11.4) with kept[j] for each of F's k results (False where the
    holding statement discards it). Returns (rewrite, [Rj or None], [type of Rj]).
    (1) `tmp Ai = ai` for every argument in order (L-ck), Ai of the argument's own type;
    (2) rule 22's extents and checks as L7 (2) writes them: for a dynamic result the extents of
        every array argument in order (a vector's `ext 0`, a matrix's `ext 0` and `ext 1`), then
        for vectors `tmp S = bin ne (lv N1) (lv Nk)` and vchk (its `tmp V = ci SEA_SHAPE_VEC`
        at the first check only) for each later array argument, for matrices `tmp O = ci 1`, the
        `bind a` / `bind a2` comparisons, `tmp S = un not (lv a)`, mchk and the combined shape
        (R', C') by `lib where`; for a fixed-size result the matrix arguments' extents only;
    (3) for each kept result j `tmp Rj = anew P Tj 0 r` of the broadcast extents (a fixed-size Tj:
        its home `anew P Tj 0 0`, every kept home first, then the extents read from the first
        kept home, L-do; with no kept result `tmp`s of `ci` of the static extents);
    (4) matrices: `tmp SI = bin ne (lv rX) (lv O)`, `tmp t = bin ne (lv cX) (lv O)`, `tmp SJ = wbin
        mul (lv t) (lv rX)` for each array argument X (`tmp O = ci 1` at its first use if (2)
        wrote none); `tmp DRj = adat` of each kept result in order, then `tmp Dk = adat` of each
        array argument in order (6c's implementer reading of L7 (5) for several results);
        loop(N; I) or mloop(R, C; I, J) with the per-element `call P ty1 fid n` (2.12.3: written,
        not inlined) of the element values: `eld P Ek sk 0 (lv Dk) idx` at an array argument
        (vector idx `lv I`, matrix `wbin add (wbin mul (lv I) (lv SIk)) (wbin mul (lv J) (lv
        SJk))`), `lv Ai` at a scalar argument and at every uniform parameter (L-dn); stored for
        k = 1 by `est P s 0 call (lv DR1) pos`, for k >= 2 a `block P m` of `tbind P k E1 ... Ek`
        (new `.l` locals, `-` for a discarded result) of the call and the `est` of every kept Ej;
        with every result discarded (or k = 0) the body is `eval P call`; pos is `lv I` or
        lin(I, J, R)."""
    P, T, iid = emap.f[0], int(emap.f[1]), int(emap.f[2])
    fid, ptys = f.inst(iid)
    F = f.func(fid)
    ty1 = int(F.rec[3])                         # F's result type
    rtys = f.comps(T)                           # the result types Tj
    etys = f.comps(ty1)                         # F's element result types
    k = len(etys)
    assert len(kept) == k and len(rtys) == k
    rw = Rewrite(P)
    # (1)
    args = [(rw.tmp(ntype(a), a), ntype(a)) for a in emap.kids]
    arrays = [int(par[1]) in ELEMENTAL_TYPES and f.is_array(pt) for par, pt in zip(F.pars, ptys)]
    xs = [(x, t) for (x, t), isa in zip(args, arrays) if isa]
    assert xs, 'an emap has an array argument'
    shape = rtys[0]
    rank, fixed = f.rank(shape), f.fixed(shape)
    assert all(f.rank(t) == rank for _, t in xs), 'mixed ranks are not in these dumps'
    assert all(f.rank(t) == rank and f.fixed(t) == fixed for t in rtys)
    one = [None]

    def O():
        if one[0] is None:
            one[0] = rw.tmp(3, N('ci', P, 3, 1))
        return one[0]
    # (2)
    exts = []                                   # per array argument: [N] or [R, C]
    if not fixed or rank == 2:
        for x, t in xs:
            exts.append([rw.tmp(3, rw.ext(x, t, d)) for d in range(rank)])
    shape_ext = None
    if not fixed:
        if rank == 1:
            v = None
            for nk in exts[1:]:
                s = rw.tmp(2, N('bin', P, 2, 'ne', kids=[rw.lv(3, exts[0][0]), rw.lv(3, nk[0])]))
                if v is None:
                    v = rw.tmp(3, N('ci', P, 3, SHAPE_VEC))
                rw.stmts.append(N('chk', P, 'SHAPE_MISMATCH', 4, kids=[
                    rw.lv(2, s), rw.lv(3, exts[0][0]), rw.lv(3, v), rw.lv(3, nk[0]),
                    rw.lv(3, v)]))
            shape_ext = [exts[0][0]]
        else:
            R, C = exts[0]
            for r, c in exts[1:]:
                o = O()
                eq = lambda a, b: N('bin', P, 2, 'eq', kids=[rw.lv(3, a), rw.lv(3, b)])  # noqa
                acc = []
                for big, small in ((R, r), (C, c)):
                    a = Loc(2, 'let', P)
                    rw.stmts.append(N('bind', P, a, kids=[eq(big, small)]))
                    b = rw.tmp(2, eq(big, o))
                    cc = rw.tmp(2, eq(small, o))
                    for y in (b, cc):
                        rw.stmts.append(N('asg', P, 'set', kids=[
                            rw.lv(2, a), N('bin', P, 2, 'bor', kids=[rw.lv(2, a), rw.lv(2, y)])]))
                    acc.append(a)
                rw.stmts.append(N('asg', P, 'set', kids=[
                    rw.lv(2, acc[0]), N('bin', P, 2, 'band', kids=[rw.lv(2, acc[0]),
                                                                   rw.lv(2, acc[1])])]))
                s = rw.tmp(2, N('un', P, 2, 'not', kids=[rw.lv(2, acc[0])]))
                rw.stmts.append(N('chk', P, 'SHAPE_MISMATCH', 4, kids=[
                    rw.lv(2, s), rw.lv(3, R), rw.lv(3, C), rw.lv(3, r), rw.lv(3, c)]))
                nr = rw.tmp(3, N('lib', P, 3, 'where', 3, kids=[eq(R, o), rw.lv(3, r),
                                                                 rw.lv(3, R)]))
                nc = rw.tmp(3, N('lib', P, 3, 'where', 3, kids=[eq(C, o), rw.lv(3, c),
                                                                 rw.lv(3, C)]))
                R, C = nr, nc
            shape_ext = [R, C]
    # (3)
    rs = []
    for j in range(k):
        if not kept[j]:
            rs.append(None)
        elif fixed:
            rs.append(rw.tmp(rtys[j], N('anew', P, rtys[j], 0, 0)))
        else:
            rs.append(rw.tmp(rtys[j], N('anew', P, rtys[j], 0, rank,
                                        kids=[rw.lv(3, e) for e in shape_ext])))
    if fixed:
        first = next((r for r in rs if r is not None), None)
        if first is not None:
            shape_ext = [rw.tmp(3, rw.ext(first, rtys[rs.index(first)], d)) for d in range(rank)]
        else:
            dims = [int(v) for v in f.ty[shape][3:]]
            shape_ext = [rw.tmp(3, N('ci', P, 3, d)) for d in dims]
    # (4) the strides of a matrix nest
    strides = []
    if rank == 2:
        for e in exts:
            r, c = e
            si = rw.tmp(2, N('bin', P, 2, 'ne', kids=[rw.lv(3, r), rw.lv(3, O())]))
            t = rw.tmp(2, N('bin', P, 2, 'ne', kids=[rw.lv(3, c), rw.lv(3, O())]))
            sj = rw.tmp(3, N('wbin', P, 3, 'mul', kids=[rw.lv(2, t), rw.lv(3, r)]))
            strides.append((si, sj))
    drs = [rw.tmp(TP(f.elt(rtys[j])), N('adat', P, TP(f.elt(rtys[j])), kids=[
        rw.lv(rtys[j], rs[j])])) if rs[j] is not None else None for j in range(k)]
    ds = [rw.tmp(TP(f.elt(t)), N('adat', P, TP(f.elt(t)), kids=[rw.lv(t, x)])) for x, t in xs]

    def body(idx):
        """The loop body at the position idx = (I,) or (I, J)."""
        eargs, ai = [], 0
        for (x, t), isa in zip(args, arrays):
            if not isa:
                eargs.append(rw.lv(t, x))
                continue
            e = f.elt(t)
            if rank == 1:
                ix = rw.lv(3, idx[0])
            else:
                si, sj = strides[ai]
                ix = N('wbin', P, 3, 'add', kids=[
                    N('wbin', P, 3, 'mul', kids=[rw.lv(3, idx[0]), rw.lv(2, si)]),
                    N('wbin', P, 3, 'mul', kids=[rw.lv(3, idx[1]), rw.lv(3, sj)])])
            eargs.append(N('eld', P, e, ESIZE[e], 0, kids=[rw.lv(TP(e), ds[ai]), ix]))
            ai += 1
        call = N('call', P, ty1, fid, len(eargs), kids=eargs)

        def pos():
            if rank == 1:
                return rw.lv(3, idx[0])
            return N('wbin', P, 3, 'add', kids=[rw.lv(3, idx[0]), N('wbin', P, 3, 'mul', kids=[
                rw.lv(3, idx[1]), rw.lv(3, shape_ext[0])])])

        def est(val, j):
            e = f.elt(rtys[j])
            return N('est', P, ESIZE[e], 0, kids=[val, rw.lv(TP(e), drs[j]), pos()])
        if not any(kept):
            return [N('eval', P, kids=[call])]
        if k == 1:
            return [est(call, 0)]
        es = [Loc(etys[j], 'let', P) if kept[j] else '-' for j in range(k)]
        inner = [N('tbind', P, k, *es, kids=[call])]
        inner += [est(rw.lv(etys[j], es[j]), j) for j in range(k) if kept[j]]
        return [N('block', P, len(inner), kids=inner)]

    if rank == 1:
        rw.stmts += rw.loop(shape_ext[0], lambda i: body((i,)))
    else:
        rw.stmts += rw.loop(shape_ext[1], lambda j: rw.loop(shape_ext[0],
                                                            lambda i: body((i, j))))
    return rw, rs, rtys


def l19_stmt(f, st):
    """L19 (5) for the statement st holding an emap: the statements that replace it."""
    if st.op == 'bind' and st.kids[0].op == 'emap':
        rw, rs, rtys = l19(f, st.kids[0], [True])
        P = rw.P
        assert len(rs) == 1, 'k = 1: the value lv R1, owned (T2 moves it out)'
        x = N('xblk', P, rtys[0], len(rw.stmts), kids=rw.stmts + [rw.lv(rtys[0], rs[0])])
        return [N('bind', *st.f, kids=[x])]
    if st.op == 'tbind' and st.kids[0].op == 'emap':
        comps = st.f[2:]
        rw, rs, rtys = l19(f, st.kids[0], [c != '-' for c in comps])
        out = list(rw.stmts)
        for c, r, t in zip(comps, rs, rtys):
            if c != '-':
                assert not f.fixed(t), 'a fixed-size result is bound by tmp (R8): not here'
                out.append(N('bind', rw.P, c, kids=[rw.lv(t, r)]))
        return out
    if st.op == 'tasg' and st.kids[-1].op == 'emap':
        n = int(st.f[1])
        targets = st.kids[:n]
        assert all(cv == '0' for cv in st.f[2:]), 'cv 0 only in these dumps'
        rw, rs, rtys = l19(f, st.kids[-1], [t.op != 'skip' for t in targets])
        out = list(rw.stmts)
        for t, r, ty in zip(targets, rs, rtys):
            if t.op != 'skip':
                out.append(N('asg', rw.P, 'set', kids=[t, rw.lv(ty, r)]))
        return [N('block', rw.P, len(out), kids=out)]
    if st.op == 'eval' and st.kids[0].op == 'emap':
        k = len(f.comps(int(st.kids[0].f[1])))
        rw, rs, rtys = l19(f, st.kids[0], [False] * k)
        return [N('block', rw.P, len(rw.stmts), kids=rw.stmts)]
    for n in postorder(st, []):
        assert n.op != 'emap', 'an emap in a position these dumps do not have'
    return [st]


def rewrite_block(f, blk):
    out = []
    for st in blk.kids:
        if st.op == 'block':
            rewrite_block(f, st)
        out += l19_stmt(f, st)
    blk.kids = out
    blk.f[1] = str(len(out))


def hirf(hir_text):
    f = File(hir_text)
    for fn in f.funcs:
        rewrite_block(f, fn.body)
    return f.text()


NOTES = {
    'elem6_vec': 'f(v, 2.0): k = 1, one array argument (no check), est of the call',
    'elem6_k5': "g(v) of five results under a tbind (results 2, 4 '-'), a tasg (3 skip) and an eval",
    'elem6_inst': 'instances 1 (twice, once of a cvt), 2 (matrices with .col: mchk), 3 (fixed '
                  'result), 4 (vchk)',
}


# From 7c elem6_inst.hirf is T2b's re-derivation with F1-F5 (Decision 97: its rewritten subject test
# has trees seafuse fuses besides its emaps), so part 2 no longer writes it; L19 alone is its 7b form.
PART2_7C = ("elem6_k5", "elem6_vec")


def part2(found):
    out = {}
    for nm in sorted(found):
        if nm not in PART2_7C:
            continue
        text = hirf(read(os.path.join(SRC_PASSES, nm + '.hir')))
        write(nm + '.hirf', text)
        out[nm] = text
    return out


# ================================================================ part 3: the cross-check
def copy_tree(n, pmap):
    """L20's copy of a callee body: own positions, a parameter read through its Ai, `ret` an
    `iret` (a callee with locals of its own would need `.i` locals: none here)."""
    kids = [copy_tree(k, pmap) for k in n.kids]
    if n.op == 'lv' and n.f[2] in pmap:
        return N('lv', n.f[0], n.f[1], pmap[n.f[2]])
    if n.op == 'ret':
        return Node('iret', n.f, kids)
    return Node(n.op, n.f, kids)


def sealoop_model(f):
    """L1, L3, L20 over every function, then the `elem` functions dropped (L-cg)."""
    elem = {fn.rec[0]: fn for fn in f.funcs if fn.rec[2] == 'elem'}
    for fn in elem.values():
        assert not fn.locs, 'an elemental function with locals of its own'

    def rw(n):
        n.kids = [rw(k) for k in n.kids]
        if n.op == 'lib' and n.f[2] == 'zeros':
            return Node('anew', [n.f[0], n.f[1], 1, n.f[3]], n.kids)
        if n.op == 'lib' and n.f[2] == 'len':
            assert f.rank(ntype(n.kids[0])) == 1
            return Node('ext', [n.f[0], 3, 0], n.kids)
        if n.op == 'call' and n.f[2] in elem:
            F = elem[n.f[2]]
            P, ty = n.f[0], int(n.f[1])
            stmts, pmap = [], {}
            for i, (par, a) in enumerate(zip(F.pars, n.kids)):
                x = Loc(int(par[1]), 'let', P)
                stmts.append(N('tmp', P, x, kids=[a]))
                pmap[str(i + 1)] = x
            body = rw(copy_tree(F.body, pmap))
            k = len(f.comps(ty))
            return N('xblk', P, ty, len(stmts), kids=stmts + [N('iblk', P, ty, k, kids=[body])])
        return n
    for fn in f.funcs:
        if fn.rec[2] != 'elem':
            fn.body = rw(fn.body)
    f.funcs = [fn for fn in f.funcs if fn.rec[2] != 'elem']
    assert [fn.rec[0] for fn in f.funcs] == ['1'], 'no fid to renumber in these dumps'
    return f.text()


def part3(written):
    n = 0
    for nm, text in sorted(written.items()):
        p = os.path.join(SRC_PASSES, nm + '.hirl')
        if not os.path.exists(p):
            continue
        got = sealoop_model(File(text))
        assert got == read(p), ('the committed .hirl is not what L1, L3, L20 make of', nm)
        n += 1
    return n


# ================================================================ part 4: the fuse7_* dumps (7c)
# Sub-phase 7c, package T2 (DESIGN.md 6.2 "`fuse7_*` dumps"): the NAME.hirf of every
# tests/passes/fuse7_*.sea test, written from its committed NAME.hir by a transcription of the
# fusion rewrites F1-F5 of 2.12.4 with 3.5.9's notation (loop(N; K), mloop, lin, vchk, mchk,
# data(X), ext(X, d)), IX 1-IX 4, the folded views, L6, L7 (2)-(6), L9 (c), L13 and L19 (2), (4).
# Which rewrite applies to which statement (a group, a barrier, a store in place or with RES) is
# decided by hand from 2.12.4 and stated per test in FUSE7 below; this code writes the records.
# The readings taken where 2.12.4 does not pin a detail are listed in READINGS (they are the
# implementer readings of the T2 report of 7c).

READINGS = """
R-a  Positions: every node a rewrite writes takes P, the position of the rewritten statement (the
     `bind`, `asg`, `ret`; for a group S1's), except: a `chk` or `chkb` record takes the position of
     the node whose check it is (the tree node, the `idx` of a folded selection, the `asg` of a
     target's own checks, the `lib` of EMPTY_REDUCE); an `rcnt` its `rng`'s; F1's RES `anew` the
     root's (F1 (6)); a stored group local's `anew` its statement's (F2 (b)); a per-element `call`
     of F5 the `emap`'s; and a concatenation rewritten as L9 (c) takes the `arr`'s position (L9's P).
R-b  The leaves and checks of a tree are taken in the reference order: at each node its operands
     left to right, a leaf evaluated as `tmp Lk`, an inner node recursively, then the node's L7 (2)
     extents and checks. `tmp V = ci SEA_SHAPE_VEC` is written once per rewrite, at its first vector
     check, and `tmp O = ci 1` once per rewrite at its first use (L7's "once").
R-c  A folded range or mask selection's kept extent (IX 3) is written where the node loads the
     extents of its operands (L7 (2)); its IX 1 and IX 2 are the leaf's evaluation.
R-d  The test Pl of a matrix space is written right before its `if`, after the data loads, as one
     `tmp` whose value folds `bin band` left to right over `bin eq (leaf extent) (space extent)`
     for every array leaf in leaf order, rows before columns; the plain copy's NN = R*C is written
     in its arm before its loop; the broadcast copy's strides (L7 (4)) in its arm before its mloop.
R-e  F2: the group's leaf and check phases (a) and its stored locals (b) stand directly in the
     enclosing block, each stored local bound there to its new array (`bind X = anew`), and the
     reuse prologues and the space test with both copies (c) form the `block P n`; F2 (d)'s binds
     cannot follow the nest inside that block (a `block` is a scope: a local bound in it would be
     released at its end while a later statement reads it). The space test compares S2 ... Sn with
     S1 (`bin eq (Si's extent) (S1's extent)`, folded by `bin band`). A read of a local bound by an
     earlier group statement is no leaf: its extents are that statement's root extents, its
     element that statement's scalar Ei. Each copy loads its own data: the fused nest first the
     data of every stored local and target in statement order, then of every array leaf in leaf
     order; the split copy per statement (its result, then its leaves), an unstored local stored
     into a `tmp` of a new array in the split copy's block (R11).
R-f  F2 (6) for a single statement (F1 (3)) is the `block P n` of its leaf and check phase, the
     prologue (`tmp X = ext(V, d)`, `tmp E = bin eq (lv X) (lv N)` per dimension folded by
     `bin band`), the data loads and the nest. O is always bound; data(O) is loaded (in leaf order,
     in place of the leaf's own data) only where the tree reads V.
R-g  F1 (3) in place for a selection target: L6 steps 2-5 after the value's leaf and check phase,
     the value's extent being the space's; step 6 loads data(T), then the leaves' data in leaf order,
     then `bind O = ci 0`, `tmp One = ci 1`; step 7's nest computes the element at the value index O.
R-h  F3 masked: `bind Q = ci 0` and `tmp One = ci 1` right after the data loads; the nest is
     loop(X; K) over the base with `if` of the mask element, Q replacing K in L13's body, and
     `Q += lv One` the last statement of the `if`'s block. The mask's data is loaded again for the
     nest (IX 4's new DM), after the base's data.
R-i  F5 with k = 1: the per-element `call` stands in the element expression in place of the
     `emap` (no `.l` local is bound for its one result).
R-j  F3's sum8 home type F8 (`tfvec` of `f64`, 8) is appended to `sea.hirf`'s type table as 3.5.9
     "Types" appends it to `sea.hirl`'s (2.12.3 (3) names only `tptr`).
R-k  F3 over `.flat` of a matrix tree: one loop over N = R*C at the linear position K (the tree
     has one array leaf, read whole at K); N's `tmp` is written after the leaf and check phase.
R-l  F3 sum masked: sum8's H, A, M and lane stores, the data loads, then `bind Qc = ci 0`,
     `tmp One = ci 1`, `tmp Q = ci 7`, then loop(X; K) { `if` (mask element at K) { W = Qc & Q;
     G; Y; `asg` G; `est`; Qc += One } } in place of sum8's direct `hloop` (the nest of R-h, the
     lane being the selected count Qc, L-et).
R-m  In a group, a `tbind` of a k >= 2 F5 element opens a `block` holding the rest of the element
     body (R8: a `tbind` of `.l` locals only as the first statement of a block); the split copy
     writes the statement in L19's block form.
R-n  A fixed-size in-place value's space extents are those of its first array leaf.
R-o  Matrix groups: the space test compares rows and columns of S2 ... Sn with S1's; the fused arm
     holds the test Pl with the plain and broadcast copies over all array leaves of the group (the
     reads of group-bound locals excluded); in the split copy each statement has its own F1 (4)
     nest, and a read of a group-bound local is a whole-array leaf of the earlier statement's split
     array.
R-p  A folded `.T` or selection leaf in a broadcast copy writes its SI and t (no SJ): it is read
     through its own map (D3).
R-q  A group's F3 accumulators stand in the enclosing block after (b); the reduction steps follow
     the stores in the nest; the finals are bound after the group's block (sum: `tmp Z`, `bind s =
     ifx(N > 0, xblk{A0..A7, T1..T6, add}, cf 0)`; max: `bind s = lv R`). A masked reduction's
     count and EMPTY_REDUCE stand in (a), its mask extent in the space test.
R-r  In a same-mask tree (`A[m] - B[m]`) the mask's data is loaded once, with the first mask leaf.
R-T2b-1  A bare leaf is not an element-wise tree: F1 and F3 need at least one fusible node; F2 (1)
     lists "folded selection or view" separately.
R-T2b-2  A group has one rank: a statement whose root has another rank ends the group.
R-T2b-3  `ind2sub` with a scalar `r` is not a fusible node.
R-T2b-4  Each extent of a folded `.col` or `.row` is a `tmp` loaded at its node: `.col` is
     `ext(B, 0)`, `ci 1`; `.row` is `ci 1`, `ext(B, 0)`. The folded leaf's `tmp Lk` is its base.
R-T2b-5  For a matrix space with a single dynamic array leaf, the always-true test Pl and the dead
     broadcast copy are kept, as the rule is literally written (`sel_reads`).
"""


class F8T:
    """The type F8 of sum8's accumulator home (3.5.9 "Types", R14), numbered when written."""


F8 = F8T()


class FX:
    """The records of one fusion rewrite at position P."""
    def __init__(self, f, P):
        self.f, self.P = f, P
        self.st = []
        self.V = None                           # tmp V = ci SEA_SHAPE_VEC (R-b)
        self.one = None                         # tmp O = ci 1 (R-b)

    def tmp(self, ty, child):
        x = Loc(ty, 'let', self.P)
        self.st.append(N('tmp', self.P, x, kids=[child]))
        return x

    def bind(self, ty, child, pos=None):
        x = Loc(ty, 'let', pos or self.P)
        self.st.append(N('bind', pos or self.P, x, kids=[child]))
        return x

    def lv(self, ty, x):
        return N('lv', self.P, ty, x)

    def ci(self, v):
        return N('ci', self.P, 3, v)

    def ext(self, x, xty, d):
        return N('ext', self.P, 3, d, kids=[self.lv(xty, x)])

    def data(self, x, xty):
        e = TP(self.f.elt(xty))
        return self.tmp(e, N('adat', self.P, e, kids=[self.lv(xty, x)]))

    def wb(self, op, a, b):
        return N('wbin', self.P, 3, op, kids=[a, b])

    def bn(self, op, a, b):
        return N('bin', self.P, 2, op, kids=[a, b])

    def O(self):
        if self.one is None:
            self.one = self.tmp(3, self.ci(1))
        return self.one

    def inc(self, x, step):
        """X += lv step (3.5.9 notation)."""
        self.st.append(N('asg', self.P, 'set', kids=[
            self.lv(3, x), self.wb('add', self.lv(3, x), self.lv(3, step))]))

    def sub(self, fn):
        """The statements fn() writes, collected into a list (for a block)."""
        saved, sv, so = self.st, self.V, self.one
        self.st = []
        fn()
        out, self.st = self.st, saved
        if sv is None:                          # a tmp written in the block is not seen after it
            self.V = None
        if so is None:
            self.one = None
        return out

    def block(self, stmts):
        return N('block', self.P, len(stmts), kids=stmts)

    def if_(self, cond, then, els=None):
        kids = [cond, self.block(then)] + ([self.block(els)] if els is not None else [])
        self.st.append(N('if', self.P, 0 if els is None else 1, kids=kids))

    def loop(self, n, body):
        """loop(N; K) { S } with body(K) writing S."""
        P = self.P
        z = self.tmp(3, self.ci(0))
        k = Loc(3, 'for', P)

        def inner():
            o = self.tmp(3, self.ci(1))
            last = self.tmp(3, self.wb('sub', self.lv(3, n), self.lv(3, o)))
            s = self.sub(lambda: body(k))
            self.st.append(N('hloop', P, k, kids=[self.lv(3, z), self.lv(3, last), self.lv(3, o),
                                                  self.block(s)]))
        self.if_(self.bn('gt', self.lv(3, n), self.lv(3, z)), self.sub(inner))

    def rloop(self, e, lo, last, step, body):
        q = Loc(3, 'for', self.P)

        def inner():
            s = self.sub(lambda: body(q))
            self.st.append(N('hloop', self.P, q, kids=[self.lv(3, lo), self.lv(3, last),
                                                       self.lv(3, step), self.block(s)]))
        self.if_(self.lv(2, e), self.sub(inner))

    def mloop(self, r, c, body):
        self.loop(c, lambda j: self.loop(r, lambda i: body(i, j)))

    def lin(self, i, j, r):
        return self.wb('add', self.lv(3, i), self.wb('mul', self.lv(3, j), self.lv(3, r)))

    def vchk(self, pos, s, a, b):
        if self.V is None:
            self.V = self.tmp(3, self.ci(SHAPE_VEC))
        self.st.append(N('chk', pos, 'SHAPE_MISMATCH', 4, kids=[
            self.lv(2, s), self.lv(3, a), self.lv(3, self.V), self.lv(3, b), self.lv(3, self.V)]))


# ---- the tree of a statement's value (2.12.4 "Element-wise trees")
FUSIBLE_LIB = {'where', 'sqrt', 'abs', 'exp', 'log', 'sin', 'cos', 'pow', 'hypot', 'min', 'max',
               'floor', 'ceil', 'round', 'trunc', 'sign', 'isnan', 'f64', 'i64', 'idiv'}


class Leaf:
    """A leaf of a tree: kind 'a' (array), 's' (scalar), or a folded leaf: 'sel' (an `idx` whose
    indices are ranges and `:`), 'vec' (an index vector), 'mask' (M), 'mm' (MM), 'flat', 'T'.
    bb is the group statement whose local is the base of a folded mask selection (R-e), else None."""
    def __init__(self, kind, node, ty, bb=None):
        self.kind, self.node, self.ty, self.bb = kind, node, ty, bb
        self.ext, self.L, self.d, self.dm = None, None, None, None


class Inner:
    def __init__(self, node, ops):
        self.node, self.ops = node, ops
        self.ext = None                         # its combined shape: [N] or [R, C]


class Bound:
    """A read of a local bound by an earlier statement of the group (R-e): component comp."""
    def __init__(self, stmt, comp=0):
        self.stmt, self.comp = stmt, comp
        self.ext = None


def is_fusible(f, n):
    if n.op in ('bin', 'un', 'cvt', 'powk', 'emap') or (n.op == 'lib' and n.f[2] in FUSIBLE_LIB):
        if n.op == 'bin' and n.f[2] in ('matmul', 'cat'):
            return False
        return any(f.is_array(ntype(k)) for k in n.kids)
    return False


def fold_kind(f, n):
    """The folded leaf kind of a leaf expression (F4), or None."""
    if n.op == 'view' and n.kids[0].op == 'lv':
        return n.f[2]                           # 'flat' or 'T' in these dumps
    if n.op == 'idx' and n.kids[0].op == 'lv' and f.is_array(ntype(n)):
        ix = n.kids[1:]
        if all(i.op in ('rng', 'all') for i in ix):
            return 'sel'
        assert len(ix) == 1 and f.is_array(ntype(ix[0]))
        if f.elt(ntype(ix[0])) != 2:
            return 'vec'
        return 'mm' if f.rank(ntype(ix[0])) == 2 else 'mask'
    return None


def tree(f, n, barriers=(), bound=None):
    """The element-wise tree of n: an Inner, a Leaf or a Bound (bound maps a lid to (group
    statement, component))."""
    bound = bound or {}
    if n.op == 'lv' and n.f[2] in bound:
        return Bound(*bound[n.f[2]])
    if is_fusible(f, n) and n.f[0] not in barriers:
        return Inner(n, [tree(f, k, barriers, bound) for k in n.kids])
    t = ntype(n)
    k = fold_kind(f, n)
    if k:
        bb = bound.get(n.kids[0].f[2], (None,))[0] if k in ('mask', 'mm') else None
        return Leaf(k, n, t, bb)
    return Leaf('a' if f.is_array(t) else 's', n, t)


def leaves(t, out):
    if isinstance(t, Inner):
        for o in t.ops:
            leaves(o, out)
    elif isinstance(t, Leaf):
        out.append(t)
    return out


def arr_leaves(t):
    return [lf for lf in leaves(t, []) if lf.kind != 's']


def is_arr(f, t):
    if isinstance(t, Leaf):
        return f.is_array(t.ty)
    return True


def shape_ty(t):
    if isinstance(t, Inner):
        return ntype(t.node)
    if isinstance(t, Bound):
        return t.stmt.tys[t.comp]
    return t.ty


# ---- the leaf and check phase (F1 (1))
def eval_leaf(fx, lf):
    """A leaf's evaluation: `tmp Lk = leaf`, or for a folded leaf its base and IX 1, IX 2."""
    f, n = fx.f, lf.node
    if lf.kind in ('a', 's'):
        lf.L = fx.tmp(lf.ty, n)
        return
    if lf.kind in ('flat', 'T'):
        b = n.kids[0]
        lf.L = fx.tmp(ntype(b), b)
        return
    base, ixs = n.kids[0], n.kids[1:]
    bty = ntype(base)
    pos = n.f[0]                                # the idx's checks take its position (R-a)
    lf.bty = bty
    if lf.bb is None:
        lf.L = fx.tmp(bty, base)

    def bext(d):
        """The extent d of the base (a group-bound base: its statement's root extent, R-e)."""
        if lf.bb is not None:
            return lf.bb.shapes[0][d]
        return fx.tmp(3, fx.ext(lf.L, bty, d))
    if lf.kind == 'sel':
        lf.ix = []
        for ix in ixs:                          # IX 1, left to right
            if ix.op == 'all':
                lf.ix.append(None)
                continue
            r = type('R', (), {})()
            r.LO = fx.tmp(3, ix.kids[0])
            r.HI = fx.tmp(3, ix.kids[1])
            r.ST = fx.tmp(3, ix.kids[2] if ix.f[3] == '1' else fx.ci(1))
            r.Lc, r.E = Loc(3, 'let', ix.f[0]), Loc(2, 'let', ix.f[0])
            fx.st.append(N('rcnt', ix.f[0], ix.f[2], r.Lc, r.E, kids=[
                fx.lv(3, r.LO), fx.lv(3, r.HI), fx.lv(3, r.ST)]))
            lf.ix.append(r)
        lf.X = []
        for d, r in enumerate(lf.ix):           # IX 2, dimension by dimension
            x = fx.tmp(3, fx.ext(lf.L, bty, d))
            lf.X.append(x)
            if r is not None:
                fx.if_(fx.lv(2, r.E), [
                    N('chkb', pos, d, kids=[fx.lv(3, r.LO), fx.lv(3, x)]),
                    N('chkb', pos, d, kids=[fx.wb('add', fx.lv(3, r.LO), fx.wb(
                        'mul', fx.lv(3, r.Lc), fx.lv(3, r.ST))), fx.lv(3, x)])])
    elif lf.kind == 'vec':
        lf.W = fx.tmp(ntype(ixs[0]), ixs[0])
        lf.X = fx.tmp(3, fx.ext(lf.L, bty, 0))
        lf.NW = fx.tmp(3, fx.ext(lf.W, ntype(ixs[0]), 0))
        dw = fx.data(lf.W, ntype(ixs[0]))
        fx.loop(lf.NW, lambda k: fx.st.append(N('chkb', pos, 0, kids=[
            N('eld', fx.P, 3, 8, 0, kids=[fx.lv(TP(3), dw), fx.lv(3, k)]), fx.lv(3, lf.X)])))
    elif lf.kind == 'mask':
        lf.mty = ntype(ixs[0])
        lf.M = fx.tmp(lf.mty, ixs[0])
        lf.X = bext(0)
        nm = fx.tmp(3, fx.ext(lf.M, lf.mty, 0))
        lf.NM = nm
        s = fx.tmp(2, fx.bn('ne', fx.lv(3, lf.X), fx.lv(3, nm)))
        fx.vchk(pos, s, lf.X, nm)
        lf.dom = lf.X
    elif lf.kind == 'mm':
        lf.mty = ntype(ixs[0])
        lf.M = fx.tmp(lf.mty, ixs[0])
        x0, x1 = bext(0), bext(1)
        rm = fx.tmp(3, fx.ext(lf.M, lf.mty, 0))
        cm = fx.tmp(3, fx.ext(lf.M, lf.mty, 1))
        s0 = fx.tmp(2, fx.bn('ne', fx.lv(3, x0), fx.lv(3, rm)))
        s1 = fx.tmp(2, fx.bn('ne', fx.lv(3, x1), fx.lv(3, cm)))
        s = fx.tmp(2, fx.bn('bor', fx.lv(2, s0), fx.lv(2, s1)))
        fx.st.append(N('chk', pos, 'SHAPE_MISMATCH', 4, kids=[
            fx.lv(2, s), fx.lv(3, x0), fx.lv(3, x1), fx.lv(3, rm), fx.lv(3, cm)]))
        lf.dom = fx.tmp(3, fx.wb('mul', fx.lv(3, x0), fx.lv(3, x1)))


def kept_extents(fx, kinds_ix, X):
    """IX 3 of the indices R and A: per dimension R: O1, T, Z, N; A: its X."""
    out = []
    for r, x in zip(kinds_ix, X):
        if r is None:
            out.append(x)
            continue
        o1 = fx.tmp(3, fx.ci(1))
        t = fx.tmp(3, fx.wb('add', fx.lv(3, r.Lc), fx.lv(3, o1)))
        z = fx.tmp(3, fx.ci(0))
        out.append(fx.tmp(3, N('lib', fx.P, 3, 'where', 3, kids=[
            fx.lv(2, r.E), fx.lv(3, t), fx.lv(3, z)])))
    return out


def leaf_extents(fx, lf):
    """The extents of an array leaf, loaded where its node loads them (R-c)."""
    f = fx.f
    if lf.kind == 'a':
        return [fx.tmp(3, fx.ext(lf.L, lf.ty, d)) for d in range(f.rank(lf.ty))]
    if lf.kind == 'flat':
        bty = ntype(lf.node.kids[0])
        r = fx.tmp(3, fx.ext(lf.L, bty, 0))
        c = fx.tmp(3, fx.ext(lf.L, bty, 1))
        return [fx.tmp(3, fx.wb('mul', fx.lv(3, r), fx.lv(3, c)))]
    if lf.kind == 'T':
        bty = ntype(lf.node.kids[0])
        x1 = fx.tmp(3, fx.ext(lf.L, bty, 1))
        x0 = fx.tmp(3, fx.ext(lf.L, bty, 0))
        lf.X1 = x0                              # B's rows: the view's dimension-1 extent
        return [x1, x0]
    if lf.kind == 'sel':
        return kept_extents(fx, lf.ix, lf.X)
    if lf.kind == 'vec':
        return [lf.NW]
    if lf.kind in ('mask', 'mm'):
        cnt = fx.bind(3, fx.ci(0))
        dm = fx.data(lf.M, lf.mty)
        fx.loop(lf.dom, lambda k: fx.inc_bool(cnt, dm, k))
        return [cnt]
    raise AssertionError(lf.kind)


def _inc_bool(self, cnt, dm, k):
    self.st.append(N('asg', self.P, 'set', kids=[self.lv(3, cnt), self.wb(
        'add', self.lv(3, cnt), N('eld', self.P, 2, 1, 0, kids=[self.lv(TP(2), dm),
                                                              self.lv(3, k)]))]))


FX.inc_bool = _inc_bool


def phase(fx, t):
    """F1 (1) for the subtree t (reference order, R-b); returns its shape (extent tmps)."""
    f = fx.f
    if isinstance(t, Bound):
        t.ext = t.stmt.shapes[t.comp]
        return t.ext
    if isinstance(t, Leaf):                     # a statement whose value is a folded leaf
        eval_leaf(fx, t)
        t.ext = leaf_extents(fx, t)
        return t.ext
    n = t.node
    for o in t.ops:
        if isinstance(o, Leaf):
            eval_leaf(fx, o)
        else:
            phase(fx, o)
    T = ntype(n)
    fixed = f.fixed(T)
    rank = f.rank(T)
    exts = []
    for o in t.ops:
        if not is_arr(f, o) or (fixed and f.rank(shape_ty(o)) == 1 and rank == 1):
            continue
        if isinstance(o, Leaf):
            o.ext = leaf_extents(fx, o)
        exts.append(o.ext)
    if fixed:
        t.ext = None
        return None
    pos = n.f[0]
    if rank == 1:
        for nk in exts[1:]:
            s = fx.tmp(2, fx.bn('ne', fx.lv(3, exts[0][0]), fx.lv(3, nk[0])))
            fx.vchk(pos, s, exts[0][0], nk[0])
        t.ext = [exts[0][0]]
        return t.ext
    R, C = exts[0]
    for r, c in exts[1:]:
        o = fx.O()
        eq = lambda a, b: fx.bn('eq', fx.lv(3, a), fx.lv(3, b))  # noqa
        acc = []
        for big, small in ((R, r), (C, c)):
            a = fx.bind(2, eq(big, small))
            b = fx.tmp(2, eq(big, o))
            cc = fx.tmp(2, eq(small, o))
            for y in (b, cc):
                fx.st.append(N('asg', fx.P, 'set', kids=[
                    fx.lv(2, a), fx.bn('bor', fx.lv(2, a), fx.lv(2, y))]))
            acc.append(a)
        fx.st.append(N('asg', fx.P, 'set', kids=[
            fx.lv(2, acc[0]), fx.bn('band', fx.lv(2, acc[0]), fx.lv(2, acc[1]))]))
        s = fx.tmp(2, N('un', fx.P, 2, 'not', kids=[fx.lv(2, acc[0])]))
        fx.st.append(N('chk', pos, 'SHAPE_MISMATCH', 4, kids=[
            fx.lv(2, s), fx.lv(3, R), fx.lv(3, C), fx.lv(3, r), fx.lv(3, c)]))
        nr = fx.tmp(3, N('lib', fx.P, 3, 'where', 3, kids=[eq(R, o), fx.lv(3, r), fx.lv(3, R)]))
        nc = fx.tmp(3, N('lib', fx.P, 3, 'where', 3, kids=[eq(C, o), fx.lv(3, c), fx.lv(3, C)]))
        R, C = nr, nc
    t.ext = [R, C]
    return t.ext


# ---- element expressions (F1 (4))
def leaf_data(fx, lf, via=None, mask=True):
    """The data tmps of an array leaf (its base's; an index vector or mask also its own, R-h);
    mask False: a later same-mask leaf, whose mask's data is not loaded again (R-r)."""
    if lf.kind in ('a', 'flat', 'T'):
        src = via if via is not None else lf.L
        lf.d = fx.data(src, ntype(lf.node.kids[0]) if lf.kind in ('flat', 'T') else lf.ty)
        return
    if lf.L is not None:
        lf.d = fx.data(lf.L, lf.bty)
    if lf.kind == 'vec':
        lf.dw = fx.data(lf.W, ntype(lf.node.kids[1]))
    elif lf.kind in ('mask', 'mm') and mask:
        lf.dm = fx.data(lf.M, lf.mty)


def sel_index(fx, r, k):
    """The base index of selection dimension r at the selection index k (a node): lo + k*st
    for R, k for A."""
    if r is None:
        return k
    return fx.wb('add', fx.lv(3, r.LO), fx.wb('mul', k, fx.lv(3, r.ST)))


def elt_read(fx, lf, idx):
    """The element of leaf lf at idx: ('lin', K) a linear index; ('ij', I, J, R) a position of a
    matrix space (R its rows); ('bc', I, J, SI, SJ) L7's broadcast index; ('bcf', I, J, SI, T) a
    folded leaf's broadcast position, row I*SI and column J*T (D3)."""
    f = fx.f
    if lf.kind == 's':
        return fx.lv(lf.ty, lf.L)
    e = f.elt(lf.ty)
    s = ESIZE[e]
    if idx[0] in ('ij', 'bcf') and lf.kind in ('T', 'sel'):
        i, j = fx.lv(3, idx[1]), fx.lv(3, idx[2])
        if idx[0] == 'bcf':
            i = fx.wb('mul', i, fx.lv(2, idx[3]))
            j = fx.wb('mul', j, fx.lv(2, idx[4]))
        if lf.kind == 'T':
            ix = fx.wb('add', j, fx.wb('mul', i, fx.lv(3, lf.X1)))
        else:
            ix = fx.wb('add', sel_index(fx, lf.ix[0], i), fx.wb(
                'mul', sel_index(fx, lf.ix[1], j), fx.lv(3, lf.X[0])))
    elif idx[0] == 'lin':
        k = idx[1]
        if lf.kind == 'sel':
            ix = sel_index(fx, lf.ix[0], k)
        elif lf.kind == 'vec':
            ix = N('eld', fx.P, 3, 8, 0, kids=[fx.lv(TP(3), lf.dw), k])
        else:
            ix = k
    elif idx[0] == 'ij':
        _, i, j, r = idx
        ix = fx.lin(i, j, r)
    else:
        _, i, j, si, sj = idx
        ix = fx.wb('add', fx.wb('mul', fx.lv(3, i), fx.lv(2, si)),
                   fx.wb('mul', fx.lv(3, j), fx.lv(3, sj)))
    return N('eld', fx.P, e, s, 0, kids=[fx.lv(TP(e), lf.d), ix])


def element(fx, t, rd):
    """The element expression F of t: rd(leaf or Bound) gives a leaf's element."""
    f = fx.f
    if isinstance(t, (Leaf, Bound)):
        return rd(t)
    n = t.node
    kids = [element(fx, o, rd) for o in t.ops]
    T = ntype(n)
    if n.op == 'emap':
        fid, _ = f.inst(int(n.f[2]))
        F = f.func(fid)
        return N('call', n.f[0], int(F.rec[3]), fid, len(kids), kids=kids)
    return Node(n.op, [n.f[0], f.elt(T)] + n.f[2:], kids)


def leaf_rd(fx, idx_of):
    """The element reader of a single tree: idx_of(leaf) gives the index form of elt_read."""
    def rd(lf):
        return elt_read(fx, lf, idx_of(lf))
    return rd


def nest(fx, lvs, sp, rank, fixed, body):
    """F1 (4): the iteration over the space sp with the array leaves lvs; body(ix, sidx) writes
    the element statements, ix(leaf) giving a leaf's index form and sidx the store index."""
    if rank == 1:
        fx.loop(sp[0], lambda i: body(lambda lf: ('lin', fx.lv(3, i)), fx.lv(3, i)))
        return
    R, C = sp
    folded = any(lf.kind not in ('a', 's') for lf in lvs)

    def plain():
        if folded:
            fx.mloop(R, C, lambda i, j: body(lambda lf: ('ij', i, j, R), fx.lin(i, j, R)))
        else:
            nn = fx.tmp(3, fx.wb('mul', fx.lv(3, R), fx.lv(3, C)))
            fx.loop(nn, lambda i: body(lambda lf: ('lin', fx.lv(3, i)), fx.lv(3, i)))
    if fixed:
        plain()
        return

    def broadcast():
        strides = {}
        for lf in lvs:
            r, c = lf.ext
            si = fx.tmp(2, fx.bn('ne', fx.lv(3, r), fx.lv(3, fx.O())))
            tt = fx.tmp(2, fx.bn('ne', fx.lv(3, c), fx.lv(3, fx.O())))
            if lf.kind in ('T', 'sel'):         # D3: its own map at I*[rows != 1], J*[cols != 1]
                strides[id(lf)] = ('bcf', si, tt)
            else:
                sj = fx.tmp(3, fx.wb('mul', fx.lv(2, tt), fx.lv(3, r)))
                strides[id(lf)] = ('bc', si, sj)

        def ix(i, j):
            def g(lf):
                k, a, b = strides.get(id(lf), ('bc', None, None))
                return (k, i, j, a, b)
            return g
        fx.mloop(R, C, lambda i, j: body(ix(i, j), fx.lin(i, j, R)))
    cond = None
    for lf in lvs:
        for x, s in zip(lf.ext, (R, C)):
            q = fx.bn('eq', fx.lv(3, x), fx.lv(3, s))
            cond = q if cond is None else fx.bn('band', cond, q)
    pl = fx.tmp(2, cond)
    fx.if_(fx.lv(2, pl), fx.sub(plain), fx.sub(broadcast))


# ---- F1 on one statement value
def f1_value(f, P, E, barriers=()):
    """F1 of the value E written at P: returns the `xblk` (F1 (3) RES, (4), (6))."""
    fx = FX(f, P)
    t = tree(f, E, barriers)
    phase(fx, t)
    T = ntype(E)
    rank, fixed = f.rank(T), f.fixed(T)
    e = f.elt(T)
    if fixed:
        res = fx.tmp(T, N('anew', E.f[0], T, 0, 0))
        sp = [fx.tmp(3, fx.ext(res, T, d)) for d in range(rank)]
    else:
        sp = t.ext
        res = fx.tmp(T, N('anew', E.f[0], T, 0, rank, kids=[fx.lv(3, x) for x in sp]))
    lvs = arr_leaves(t)
    dr = fx.data(res, T)
    for lf in lvs:
        leaf_data(fx, lf)

    def body(ix, sidx):
        fx.st.append(N('est', fx.P, ESIZE[e], 0, kids=[
            element(fx, t, leaf_rd(fx, ix)), fx.lv(TP(e), dr), sidx]))
    nest(fx, lvs, sp, rank, fixed, body)
    return N('xblk', P, T, len(fx.st), kids=fx.st + [fx.lv(T, res)])


# ---- F1 (3) with F2 (6): an asg set to a whole dynamic array, a group of one (R-f)
def prologue(fx, vlid, VT, sp):
    """F2 (6)'s reuse prologue of the target V over the space sp; returns O."""
    f = fx.f
    cond = None
    for d, s in enumerate(sp):
        x = fx.tmp(3, N('ext', fx.P, 3, d, kids=[fx.lv(VT, vlid)]))
        q = fx.bn('eq', fx.lv(3, x), fx.lv(3, s))
        cond = q if cond is None else fx.bn('band', cond, q)
    e = fx.tmp(2, cond)
    fx.if_(fx.lv(2, e), [N('cow', fx.P, kids=[fx.lv(VT, vlid)])])
    o = fx.bind(VT, fx.lv(VT, vlid))
    fx.if_(N('un', fx.P, 2, 'not', kids=[fx.lv(2, e)]), [N('asg', fx.P, 'set', kids=[
        fx.lv(VT, vlid), N('anew', fx.P, VT, 0, f.rank(VT), kids=[fx.lv(3, x) for x in sp])])])
    return o


def reads_local(lf, lid):
    return lf.kind == 'a' and lf.node.op == 'lv' and lf.node.f[2] == lid


def f1_reuse(f, st):
    """`asg set (lv V) E` of a dynamic array V: one `block P n`."""
    P = st.f[0]
    tgt, E = st.kids
    vlid, VT = tgt.f[2], ntype(tgt)
    fx = FX(f, P)
    t = tree(f, E)
    sp = phase(fx, t)
    o = prologue(fx, vlid, VT, sp)
    e = f.elt(VT)
    dr = fx.data(vlid, VT)
    lvs = arr_leaves(t)
    for lf in lvs:
        leaf_data(fx, lf, via=o if reads_local(lf, vlid) else None)

    def body(ix, sidx):
        fx.st.append(N('est', fx.P, ESIZE[e], 0, kids=[
            element(fx, t, leaf_rd(fx, ix)), fx.lv(TP(e), dr), sidx]))
    nest(fx, lvs, sp, f.rank(VT), False, body)
    return [fx.block(fx.st)]


# ---- F1 (3) in place for a selection target (R-g): kinds R, A, M, MM
def f1_sel_inplace(f, st):
    P = st.f[0]
    tgt, E = st.kids
    base, ixs = tgt.kids[0], tgt.kids[1:]
    vlid, VT = base.f[2], ntype(base)
    e = f.elt(VT)
    fx = FX(f, P)
    t = tree(f, E)
    sp = phase(fx, t)
    VTy = ntype(E)
    lvs = arr_leaves(t)
    if f.fixed(VTy):                            # R-n: a fixed-size space's extents are the
        sp = lvs[0].ext                         # first array leaf's
    # L6 step 2: IX 1 of the target (every index a tmp)
    kinds = []
    for ix in ixs:
        if ix.op == 'all':
            kinds.append(None)
        elif ix.op == 'rng':
            r = type('R', (), {})()
            r.LO = fx.tmp(3, ix.kids[0])
            r.HI = fx.tmp(3, ix.kids[1])
            r.ST = fx.tmp(3, ix.kids[2] if ix.f[3] == '1' else fx.ci(1))
            r.Lc, r.E = Loc(3, 'let', ix.f[0]), Loc(2, 'let', ix.f[0])
            fx.st.append(N('rcnt', ix.f[0], ix.f[2], r.Lc, r.E, kids=[
                fx.lv(3, r.LO), fx.lv(3, r.HI), fx.lv(3, r.ST)]))
            kinds.append(r)
        else:
            m = type('M', (), {})()
            m.ty = ntype(ix)
            m.M = fx.tmp(m.ty, ix)
            m.mm = f.rank(m.ty) == 2
            kinds.append(m)
    # step 3: IX 2, the target read afresh
    X = []
    msk = kinds[0] if hasattr(kinds[0], 'M') else None
    if msk is None:
        for d, r in enumerate(kinds):
            x = fx.tmp(3, N('ext', P, 3, d, kids=[fx.lv(VT, vlid)]))
            X.append(x)
            if r is not None:
                fx.if_(fx.lv(2, r.E), [
                    N('chkb', P, d, kids=[fx.lv(3, r.LO), fx.lv(3, x)]),
                    N('chkb', P, d, kids=[fx.wb('add', fx.lv(3, r.LO), fx.wb(
                        'mul', fx.lv(3, r.Lc), fx.lv(3, r.ST))), fx.lv(3, x)])])
    elif not msk.mm:
        x = fx.tmp(3, N('ext', P, 3, 0, kids=[fx.lv(VT, vlid)]))
        X.append(x)
        nm = fx.tmp(3, fx.ext(msk.M, msk.ty, 0))
        s = fx.tmp(2, fx.bn('ne', fx.lv(3, x), fx.lv(3, nm)))
        fx.vchk(P, s, x, nm)
        dom = x
    else:
        x0 = fx.tmp(3, N('ext', P, 3, 0, kids=[fx.lv(VT, vlid)]))
        x1 = fx.tmp(3, N('ext', P, 3, 1, kids=[fx.lv(VT, vlid)]))
        X += [x0, x1]
        rm = fx.tmp(3, fx.ext(msk.M, msk.ty, 0))
        cm = fx.tmp(3, fx.ext(msk.M, msk.ty, 1))
        s0 = fx.tmp(2, fx.bn('ne', fx.lv(3, x0), fx.lv(3, rm)))
        s1 = fx.tmp(2, fx.bn('ne', fx.lv(3, x1), fx.lv(3, cm)))
        s = fx.tmp(2, fx.bn('bor', fx.lv(2, s0), fx.lv(2, s1)))
        fx.st.append(N('chk', P, 'SHAPE_MISMATCH', 4, kids=[
            fx.lv(2, s), fx.lv(3, x0), fx.lv(3, x1), fx.lv(3, rm), fx.lv(3, cm)]))
        dom = fx.tmp(3, fx.wb('mul', fx.lv(3, x0), fx.lv(3, x1)))
    # step 4: IX 3 and the shape check (the value's extents are the space's)
    if msk is None:
        kept = kept_extents(fx, kinds, X)
    else:
        cnt = fx.bind(3, fx.ci(0))
        dm0 = fx.data(msk.M, msk.ty)
        fx.loop(dom, lambda k: fx.inc_bool(cnt, dm0, k))
        kept = [cnt]
    if len(kept) == 1:
        s = fx.tmp(2, fx.bn('ne', fx.lv(3, kept[0]), fx.lv(3, sp[0])))
        fx.vchk(P, s, kept[0], sp[0])
    else:
        s0 = fx.tmp(2, fx.bn('ne', fx.lv(3, kept[0]), fx.lv(3, sp[0])))
        s1 = fx.tmp(2, fx.bn('ne', fx.lv(3, kept[1]), fx.lv(3, sp[1])))
        s = fx.tmp(2, fx.bn('bor', fx.lv(2, s0), fx.lv(2, s1)))
        fx.st.append(N('chk', P, 'SHAPE_MISMATCH', 4, kids=[
            fx.lv(2, s), fx.lv(3, kept[0]), fx.lv(3, kept[1]), fx.lv(3, sp[0]),
            fx.lv(3, sp[1])]))
    # step 5: cow; step 6: data, the masks' data, the value counter
    fx.st.append(N('cow', P, kids=[fx.lv(VT, vlid)]))
    dt = fx.data(vlid, VT)
    for lf in lvs:
        leaf_data(fx, lf)
    dm = fx.data(msk.M, msk.ty) if msk is not None else None
    oc = fx.bind(3, fx.ci(0))
    one = fx.tmp(3, fx.ci(1))

    def store(pos):
        F = element(fx, t, leaf_rd(fx, lambda lf: ('lin', fx.lv(3, oc))))
        fx.st.append(N('est', P, ESIZE[e], 0, kids=[F, fx.lv(TP(e), dt), pos]))
        fx.inc(oc, one)
    # step 7: IX 4, dimension 1 outside, dimension 0 inside
    if msk is not None:
        fx.loop(dom, lambda q: fx.if_(N('eld', P, 2, 1, 0, kids=[
            fx.lv(TP(2), dm), fx.lv(3, q)]), fx.sub(lambda: store(fx.lv(3, q)))))
    elif len(kinds) == 1:
        fx.rloop(kinds[0].E, kinds[0].LO, kinds[0].Lc, kinds[0].ST,
                 lambda q: store(fx.lv(3, q)))
    else:
        def dim(d, inner):
            r = kinds[d]
            if r is None:
                fx.loop(X[d], inner)
            else:
                fx.rloop(r.E, r.LO, r.Lc, r.ST, inner)
        dim(1, lambda q1: dim(0, lambda q0: store(fx.lin(q0, q1, X[0]))))
    return [fx.block(fx.st)]


# ---- F3: sum (sum8 over the tree; masked: R-l), max / argmax over a mask selection (R-h)
def f3_arg(f, fx, arg, bound=None):
    """The F3 argument's tree, its leaf and check phase, its count N, its iteration domain and
    its mask leaf (or None): a tree, `.flat` of a matrix tree (R-k) or a mask selection tree."""
    flat = arg.op == 'view' and arg.f[2] == 'flat' and arg.kids[0].op != 'lv'
    t = tree(f, arg.kids[0] if flat else arg, bound=bound)
    sp = phase(fx, t)
    msk = next((lf for lf in leaves(t, []) if lf.kind in ('mask', 'mm')), None)
    if flat:
        n = fx.tmp(3, fx.wb('mul', fx.lv(3, sp[0]), fx.lv(3, sp[1])))
        return t, n, n, None
    if msk is not None:
        return t, sp[0], msk.dom, msk
    return t, sp[0], sp[0], None


def mask_data(fx, t, via=None):
    """The data of the array leaves; a mask's data once, with the first mask leaf (R-r)."""
    seen = False
    for lf in arr_leaves(t):
        leaf_data(fx, lf, via=via(lf) if via else None,
                  mask=not (seen and lf.kind in ('mask', 'mm')))
        seen = seen or lf.kind in ('mask', 'mm')


def sum8_init(fx, P):
    """sum8's home, its address, its eight lanes set to -0 (3.5.9 sum8)."""
    a8 = TP(4)
    h = fx.tmp(F8, N('anew', P, F8, 0, 0))
    a = fx.tmp(a8, N('adat', P, a8, kids=[fx.lv(F8, h)]))
    m = fx.tmp(4, N('cf', P, 4, '#8000000000000000'))
    for k in range(8):
        fx.st.append(N('est', P, 8, 0, kids=[fx.lv(4, m), fx.lv(a8, a), fx.ci(k)]))
    return a


def sum8_step(fx, P, a, q, k, val):
    """One sum8 step at lane k & 7 (k the position, or the selected count Q): val() writes the
    element value and returns its local."""
    a8 = TP(4)
    w = fx.tmp(3, fx.wb('and', fx.lv(3, k), fx.lv(3, q)))
    g = fx.bind(4, N('eld', P, 4, 8, 0, kids=[fx.lv(a8, a), fx.lv(3, w)]))
    y = val()
    fx.st.append(N('asg', P, 'set', kids=[fx.lv(4, g), N('bin', P, 4, 'add', kids=[
        fx.lv(4, g), fx.lv(4, y)])]))
    fx.st.append(N('est', P, 8, 0, kids=[fx.lv(4, g), fx.lv(a8, a), fx.lv(3, w)]))


def sum8_final(fx, P, a):
    """sum8's eight lanes read and combined in its fixed tree; returns the value node."""
    a8 = TP(4)
    ak = [fx.tmp(4, N('eld', P, 4, 8, 0, kids=[fx.lv(a8, a), fx.ci(i)])) for i in range(8)]

    def add(x, y):
        return N('bin', P, 4, 'add', kids=[fx.lv(4, x), fx.lv(4, y)])
    t1 = fx.tmp(4, add(ak[0], ak[1]))
    t2 = fx.tmp(4, add(ak[2], ak[3]))
    t3 = fx.tmp(4, add(t1, t2))
    t4 = fx.tmp(4, add(ak[4], ak[5]))
    t5 = fx.tmp(4, add(ak[6], ak[7]))
    t6 = fx.tmp(4, add(t4, t5))
    return add(t3, t6)


def f3_sum(f, st):
    P = st.f[0]
    lib = st.kids[0]
    fx = FX(f, P)
    t, n, dom, msk = f3_arg(f, fx, lib.kids[0])
    z = fx.tmp(3, fx.ci(0))

    def s8():
        a = sum8_init(fx, P)
        mask_data(fx, t)

        def val(k):
            return lambda: fx.tmp(4, element(fx, t, leaf_rd(fx, lambda lf: ('lin', fx.lv(3, k)))))
        if msk is None:
            q = fx.tmp(3, fx.ci(7))
            o = fx.tmp(3, fx.ci(1))
            last = fx.tmp(3, fx.wb('sub', fx.lv(3, n), fx.lv(3, o)))
            k = Loc(3, 'for', P)
            blk = fx.sub(lambda: sum8_step(fx, P, a, q, k, val(k)))
            fx.st.append(N('hloop', P, k, kids=[fx.lv(3, z), fx.lv(3, last), fx.lv(3, o),
                                                fx.block(blk)]))
        else:
            qc = fx.bind(3, fx.ci(0))
            one = fx.tmp(3, fx.ci(1))
            q = fx.tmp(3, fx.ci(7))

            def body(k):
                def sel():
                    sum8_step(fx, P, a, q, qc, val(k))
                    fx.inc(qc, one)
                fx.if_(N('eld', P, 2, 1, 0, kids=[fx.lv(TP(2), msk.dm), fx.lv(3, k)]),
                       fx.sub(sel))
            fx.loop(dom, body)
        return sum8_final(fx, P, a)
    inner = []
    saved = fx.st
    fx.st = inner
    val = s8()
    fx.st = saved
    ifx = N('ifx', P, 4, kids=[fx.bn('gt', fx.lv(3, n), fx.lv(3, z)),
                               N('xblk', P, 4, len(inner), kids=inner + [val]),
                               N('cf', P, 4, '#0000000000000000')])
    return [N('bind', *st.f, kids=[N('xblk', P, 4, len(fx.st), kids=fx.st + [ifx])])]


def max_check(fx, lib, n, name):
    """L13's EMPTY_REDUCE check of max/min/argmax/argmin."""
    P = fx.P
    z = fx.tmp(3, fx.ci(0))
    em = fx.tmp(2, fx.bn('eq', fx.lv(3, n), fx.lv(3, z)))
    sn = fx.tmp(5, N('cs', P, 5, name))
    fx.st.append(N('chk', lib.f[0], 'EMPTY_REDUCE', 1, kids=[fx.lv(2, em), fx.lv(5, sn)]))


def max_acc(fx):
    """L13's accumulators of max/argmax (f64) and the selected count (R-h)."""
    P = fx.P
    r = fx.bind(4, N('cf', P, 4, '#7FF8000000000000'))
    hv = fx.bind(2, N('cb', P, 2, 0))
    xi = fx.bind(3, fx.ci(0))
    return r, hv, xi


def max_step(fx, acc, q, y):
    """L13's max/argmax body (f64, cmp gt) on the element local y at position q."""
    P = fx.P
    r, hv, xi = acc
    u = fx.tmp(2, N('lib', P, 2, 'isnan', 1, kids=[fx.lv(4, y)]))
    kn = fx.tmp(2, N('un', P, 2, 'not', kids=[fx.lv(2, u)]))
    g = fx.tmp(2, fx.bn('gt', fx.lv(4, y), fx.lv(4, r)))
    hn = fx.tmp(2, N('un', P, 2, 'not', kids=[fx.lv(2, hv)]))
    tt = fx.tmp(2, fx.bn('bor', fx.lv(2, hn), fx.lv(2, g)))
    c = fx.tmp(2, fx.bn('band', fx.lv(2, kn), fx.lv(2, tt)))
    fx.st.append(N('asg', P, 'set', kids=[fx.lv(4, r), N('lib', P, 4, 'where', 3, kids=[
        fx.lv(2, c), fx.lv(4, y), fx.lv(4, r)])]))
    fx.st.append(N('asg', P, 'set', kids=[fx.lv(3, xi), N('lib', P, 3, 'where', 3, kids=[
        fx.lv(2, c), fx.lv(3, q), fx.lv(3, xi)])]))
    fx.st.append(N('asg', P, 'set', kids=[fx.lv(2, hv), fx.bn('bor', fx.lv(2, hv),
                                                               fx.lv(2, c))]))


def f3_maxmask(f, st, name):
    P = st.f[0]
    lib = st.kids[0]
    fx = FX(f, P)
    t, n, dom, msk = f3_arg(f, fx, lib.kids[0])
    max_check(fx, lib, n, name)
    acc = max_acc(fx)
    mask_data(fx, t)
    q = fx.bind(3, fx.ci(0))
    one = fx.tmp(3, fx.ci(1))

    def body(k):
        def sel():
            y = fx.tmp(4, element(fx, t, leaf_rd(fx, lambda lf: ('lin', fx.lv(3, k)))))
            max_step(fx, acc, q, y)
            fx.inc(q, one)
        fx.if_(N('eld', P, 2, 1, 0, kids=[fx.lv(TP(2), msk.dm), fx.lv(3, k)]), fx.sub(sel))
    fx.loop(dom, body)
    rt = 4 if name == 'max' else 3
    val = fx.lv(4, acc[0]) if name == 'max' else fx.lv(3, acc[2])
    return [N('bind', *st.f, kids=[N('xblk', P, rt, len(fx.st), kids=fx.st + [val])])]


# ---- F4: concatenation parts copied from their bases (L9 (c), L-eu)
def f4_cat(f, st):
    arr = st.kids[0]
    P = arr.f[0]
    T = ntype(arr)
    fx = FX(f, P)
    row = arr.kids[0]
    rank = f.rank(T)
    parts = []
    for p in row.kids:
        k = fold_kind(f, p)
        if k:
            lf = Leaf(k, p, ntype(p))
            eval_leaf(fx, lf)
            parts.append(lf)
        else:
            parts.append(('s', fx.tmp(ntype(p), p)))
    e = f.elt(T)
    if rank == 1:                               # a row of scalars and vectors
        lens, tot = [], None
        for p in parts:
            ln = leaf_extents(fx, p)[0] if isinstance(p, Leaf) else fx.tmp(3, fx.ci(1))
            lens.append(ln)
            if tot is None:
                tot = ln
            else:
                tot = fx.tmp(3, fx.wb('add', fx.lv(3, tot), fx.lv(3, ln)))
        res = fx.tmp(T, N('anew', P, T, 0, 1, kids=[fx.lv(3, tot)]))
        dr = fx.data(res, T)
        off = None
        for i, p in enumerate(parts):
            off = fx.tmp(3, fx.ci(0)) if off is None else fx.tmp(3, fx.wb(
                'add', fx.lv(3, off), fx.lv(3, lens[i - 1])))
            if isinstance(p, Leaf):
                leaf_data(fx, p)
                c0 = off
                fx.loop(lens[i], lambda q: fx.st.append(N('est', P, ESIZE[e], 0, kids=[
                    elt_read(fx, p, ('lin', fx.lv(3, q))), fx.lv(TP(e), dr),
                    fx.wb('add', fx.lv(3, c0), fx.lv(3, q))])))
            else:
                fx.st.append(N('est', P, ESIZE[e], 0, kids=[fx.lv(ntype(row.kids[i]), p[1]),
                                                           fx.lv(TP(e), dr), fx.lv(3, off)]))
    else:                                       # one row of matrices (folded parts only here)
        exts = []
        for i, p in enumerate(parts):
            assert isinstance(p, Leaf)
            ex = leaf_extents(fx, p)
            exts.append(ex)
            if i == 0:
                rr, cr = ex
                continue
            s = fx.tmp(2, fx.bn('ne', fx.lv(3, rr), fx.lv(3, ex[0])))
            fx.st.append(N('chk', P, 'SHAPE_MISMATCH', 4, kids=[
                fx.lv(2, s), fx.lv(3, rr), fx.lv(3, cr), fx.lv(3, ex[0]), fx.lv(3, ex[1])]))
            cr = fx.tmp(3, fx.wb('add', fx.lv(3, cr), fx.lv(3, ex[1])))
        res = fx.tmp(T, N('anew', P, T, 0, 2, kids=[fx.lv(3, rr), fx.lv(3, cr)]))
        dr = fx.data(res, T)
        r0 = fx.tmp(3, fx.ci(0))
        off = None
        for i, p in enumerate(parts):
            off = fx.tmp(3, fx.ci(0)) if off is None else fx.tmp(3, fx.wb(
                'add', fx.lv(3, off), fx.lv(3, exts[i - 1][1])))
            leaf_data(fx, p)
            c0 = off
            fx.mloop(exts[i][0], exts[i][1], lambda a, b: fx.st.append(N(
                'est', P, ESIZE[e], 0, kids=[elt_read(fx, p, ('ij', a, b, None)), fx.lv(TP(e), dr),
                                             fx.wb('add', fx.wb('add', fx.lv(3, r0), fx.lv(3, a)),
                                                   fx.wb('mul', fx.wb('add', fx.lv(3, c0),
                                                                      fx.lv(3, b)),
                                                         fx.lv(3, rr)))])))
    return [N('bind', *st.f, kids=[N('xblk', P, T, len(fx.st), kids=fx.st + [fx.lv(T, res)])])]


# ---- F2: a group (R-e; F3 members R-q; a tbind of an F5 result R-m; matrix spaces R-o)
class GS:
    def __init__(self, f, st):
        self.st, self.pos = st, st.f[0]
        self.kind = st.op
        if st.op == 'bind' and st.kids[0].op == 'lib' and st.kids[0].f[2] in ('sum', 'max'):
            self.kind = 'red'
            self.lib = st.kids[0]
            self.lids, self.E = [st.f[1]], st.kids[0]
            self.tys = [ntype(st.kids[0])]
        elif st.op == 'bind':
            self.lids, self.E = [st.f[1]], st.kids[0]
            self.tys = [ntype(self.E)]
        elif st.op == 'tbind':
            self.lids, self.E = list(st.f[2:]), st.kids[0]
            self.tys = f.comps(ntype(self.E))
        else:
            tgt = st.kids[0]
            self.lids, self.E = [tgt.f[2]], st.kids[1]
            self.tys = [ntype(tgt)]
        self.target = st.op == 'asg'
        self.etys = [f.elt(t) if f.is_array(t) else t for t in self.tys]


def reads_after(blk_stmts, lid):
    for st in blk_stmts:
        for n in postorder(st, []):
            if n.op == 'lv' and n.f[2] == lid:
                return True
    return False


def f2_group(f, stmts, after):
    """The group S1 ... Sn (R-e): the statements that replace it in the enclosing block."""
    gs = [GS(f, s) for s in stmts]
    P = gs[0].pos
    fx = FX(f, P)
    bound = {}
    # (a) the leaf and check phases in statement order (a masked reduction's count and check)
    for g in gs:
        if g.kind == 'red':
            g.t, g.n, g.dom, g.msk = f3_arg(f, fx, g.lib.kids[0], bound)
            g.shapes = [[g.dom if g.msk is None else g.msk.X]]
            if g.lib.f[2] == 'max':
                max_check(fx, g.lib, g.n, 'max')
        else:
            g.t = tree(f, g.E, bound=bound)
            sh = phase(fx, g.t)
            g.shapes = [sh] * len(g.lids)
        g.stored = [g.target or (lid != '-' and g.kind != 'red' and reads_after(after, lid))
                    for lid in g.lids]
        if not g.target:
            for c, lid in enumerate(g.lids):
                if lid != '-':
                    bound[lid] = (g, c)
    S1 = gs[0].shapes[0]
    rank = len(S1)
    # (b) the stored locals' arrays; the reductions' accumulators (R-q)
    for g in gs:
        for c, lid in enumerate(g.lids):
            if g.stored[c] and not g.target:
                fx.st.append(N('bind', g.pos, lid, kids=[N('anew', g.pos, g.tys[c], 0, rank,
                                                           kids=[fx.lv(3, x) for x in g.shapes[c]])]))
    for g in gs:
        if g.kind == 'red' and g.lib.f[2] == 'sum':
            g.a = sum8_init(fx, P)
            g.q = fx.tmp(3, fx.ci(7))
        elif g.kind == 'red':
            g.acc = max_acc(fx)
            g.qc = fx.bind(3, fx.ci(0))
            g.one = fx.tmp(3, fx.ci(1))
    spliced, fx.st = fx.st, []
    # (c) the reuse prologues, the space test, the fused nest and the split copy
    for g in gs:
        g.O = prologue(fx, g.lids[0], g.tys[0], g.shapes[0]) if g.target else None
    cond = None
    for g in gs[1:]:
        tests = list(g.shapes[0])
        if g.kind == 'red' and g.msk is not None:
            tests.append(g.msk.NM)
        for d, x in enumerate(tests):
            q = fx.bn('eq', fx.lv(3, x), fx.lv(3, S1[min(d, rank - 1)]))
            cond = q if cond is None else fx.bn('band', cond, q)
    gtest = fx.tmp(2, cond)

    def via(lf):
        return next((h.O for h in gs if h.target and reads_local(lf, h.lids[0])), None)

    def fused():
        drs = {}
        for g in gs:
            for c, lid in enumerate(g.lids):
                if g.stored[c]:
                    drs[(id(g), c)] = fx.data(lid, g.tys[c])
        lvs = []
        for g in gs:
            mask_data(fx, g.t, via)
            lvs += [lf for lf in arr_leaves(g.t) if lf.bb is None or lf.kind not in ('mask', 'mm')]

        def body(ix, sidx):
            def rd(x):
                if isinstance(x, Bound):
                    return fx.lv(x.stmt.etys[x.comp], x.stmt.Ei[x.comp])
                if x.kind in ('mask', 'mm') and x.bb is not None:
                    return fx.lv(x.bb.etys[0], x.bb.Ei[0])
                return elt_read(fx, x, ix(x))
            rest = []
            for g in gs:
                if g.kind == 'tbind':           # R-m: the tbind opens a block of the rest
                    fid, _ = f.inst(int(g.E.f[2]))
                    g.Ei = [Loc(et, 'let', P) if lid != '-' else '-'
                            for lid, et in zip(g.lids, f.comps(int(f.func(fid).rec[3])))]
                    call = element(fx, g.t, rd)
                    blk = [N('tbind', P, len(g.lids), *g.Ei, kids=[call])]
                    rest.append((fx.st, blk))
                    fx.st = blk
                else:
                    g.Ei = [fx.bind(g.etys[0], element(fx, g.t, rd))]
            for g in gs:
                for c in range(len(g.lids)):
                    if g.stored[c]:
                        fx.st.append(N('est', P, ESIZE[g.etys[c]], 0, kids=[
                            fx.lv(g.etys[c], g.Ei[c]), fx.lv(TP(g.etys[c]), drs[(id(g), c)]),
                            sidx]))
            for g in gs:
                if g.kind == 'red' and g.lib.f[2] == 'sum':
                    sum8_step(fx, P, g.a, g.q, ix(None)[1].f[2], lambda g=g: g.Ei[0])
                elif g.kind == 'red':
                    k = ix(None)[1].f[2]

                    def sel(g=g):
                        max_step(fx, g.acc, g.qc, g.Ei[0])
                        fx.inc(g.qc, g.one)
                    fx.if_(N('eld', P, 2, 1, 0, kids=[fx.lv(TP(2), g.msk.dm), fx.lv(3, k)]),
                           fx.sub(sel))
            for outer, blk in reversed(rest):
                fx.st = outer
                fx.st.append(fx.block(blk))
        nest(fx, lvs, S1, rank, False, body)

    def split():
        for g in gs:
            arrs = []
            if g.kind != 'red':
                for c, lid in enumerate(g.lids):
                    if lid == '-':
                        arrs.append(None)
                    elif g.stored[c]:
                        arrs.append(lid)
                    else:
                        arrs.append(fx.tmp(g.tys[c], N('anew', P, g.tys[c], 0, rank, kids=[
                            fx.lv(3, x) for x in g.shapes[c]])))
                g.split = arrs
                drs = [fx.data(x, g.tys[c]) if x is not None else None
                       for c, x in enumerate(arrs)]
            # a group-bound read is a whole array of the earlier statement here (R-e, R-o)
            pseudo = {}
            for b in [x for x in all_nodes(g.t) if isinstance(x, Bound)]:
                lf = Leaf('a', None, b.stmt.tys[b.comp])
                lf.L, lf.ext = b.stmt.split[b.comp], b.ext
                pseudo[id(b)] = lf
            for lf in arr_leaves(g.t):
                if lf.bb is not None:
                    lf.L, lf.bty = lf.bb.split[0], lf.bb.tys[0]
            order = []
            for x in all_nodes(g.t):
                if isinstance(x, Bound):
                    order.append(pseudo[id(x)])
                elif isinstance(x, Leaf) and x.kind != 's':
                    order.append(x)
            for lf in order:
                if lf.node is None:
                    lf.d = fx.data(lf.L, lf.ty)
                else:
                    leaf_data(fx, lf, via=via(lf))

            def rd_of(ix):
                def rd(x):
                    if isinstance(x, Bound):
                        return elt_read(fx, pseudo[id(x)], ix(pseudo[id(x)]))
                    return elt_read(fx, x, ix(x))
                return rd
            sh = g.shapes[0]
            if g.kind == 'red' and g.lib.f[2] == 'sum':
                fx.loop(g.n, lambda i, g=g: sum8_step(fx, P, g.a, g.q, i, lambda: fx.tmp(
                    4, element(fx, g.t, rd_of(lambda lf: ('lin', fx.lv(3, i)))))))
            elif g.kind == 'red':
                def body(k, g=g):
                    def sel():
                        y = fx.tmp(4, element(fx, g.t, rd_of(lambda lf: ('lin', fx.lv(3, k)))))
                        max_step(fx, g.acc, g.qc, y)
                        fx.inc(g.qc, g.one)
                    fx.if_(N('eld', P, 2, 1, 0, kids=[fx.lv(TP(2), g.msk.dm), fx.lv(3, k)]),
                           fx.sub(sel))
                fx.loop(g.dom, body)
            elif g.kind == 'tbind':
                fid, _ = f.inst(int(g.E.f[2]))
                etys = f.comps(int(f.func(fid).rec[3]))

                def body(ix, sidx, g=g, drs=drs, etys=etys):
                    es = [Loc(et, 'let', P) if lid != '-' else '-'
                          for lid, et in zip(g.lids, etys)]
                    blk = [N('tbind', P, len(es), *es, kids=[element(fx, g.t, rd_of(ix))])]
                    for c, x in enumerate(es):
                        if x != '-':
                            blk.append(N('est', P, ESIZE[etys[c]], 0, kids=[
                                fx.lv(etys[c], x), fx.lv(TP(etys[c]), drs[c]), sidx]))
                    fx.st.append(fx.block(blk))
                nest(fx, [lf for lf in order], sh, rank, False, body)
            else:
                def body(ix, sidx, g=g, drs=drs):
                    fx.st.append(N('est', P, ESIZE[g.etys[0]], 0, kids=[
                        element(fx, g.t, rd_of(ix)), fx.lv(TP(g.etys[0]), drs[0]), sidx]))
                nest(fx, order, sh, rank, False, body)
    fx.if_(fx.lv(2, gtest), fx.sub(fused), fx.sub(split))
    out = spliced + [fx.block(fx.st)]
    # (d) the reductions' final values, bound after the group's block (R-e, R-q)
    fx.st = []
    for g in gs:
        if g.kind == 'red' and g.lib.f[2] == 'sum':
            z = fx.tmp(3, fx.ci(0))
            inner = []
            saved, fx.st = fx.st, inner
            val = sum8_final(fx, P, g.a)
            fx.st = saved
            fx.st.append(N('bind', g.pos, g.lids[0], kids=[N('ifx', P, 4, kids=[
                fx.bn('gt', fx.lv(3, g.n), fx.lv(3, z)),
                N('xblk', P, 4, len(inner), kids=inner + [val]),
                N('cf', P, 4, '#0000000000000000')])]))
        elif g.kind == 'red':
            fx.st.append(N('bind', g.pos, g.lids[0], kids=[fx.lv(4, g.acc[0])]))
    return out + fx.st


def all_nodes(t):
    """The tree's leaves and group reads in operand order."""
    if isinstance(t, Inner):
        out = []
        for o in t.ops:
            out += all_nodes(o)
        return out
    return [t]


# ---- the tests: which rewrite applies to which statement (decided by hand from 2.12.4)
def failing_i64_nodes(f, n):
    """The positions of the i64 `+ - *` nodes under n (failing, 2.12.2)."""
    return [m.f[0] for m in postorder(n, []) if m.op == 'bin' and m.f[2] in ('add', 'sub', 'mul')
            and f.is_array(ntype(m)) and f.elt(ntype(m)) == 3]


def op_f1(f, st):
    E = st.kids[0]
    st.kids = [f1_value(f, st.f[0], E, failing_i64_nodes(f, E))]
    return [st]


def op_selres(f, st):
    st.kids[1] = f1_value(f, st.f[0], st.kids[1])
    return [st]


FUSE7 = {
    # name: (description, [(statement indices of .main, rewrite)]); an inl body: its ret (fuse7_hirf)
    'fuse7_f1_vec': ('F1 on a vector tree of two fusible nodes', [([1], op_f1)]),
    'fuse7_f1_mat': ('F1 on a dynamic matrix tree: plain and broadcast copies', [([1], op_f1)]),
    'fuse7_f1_fixed': ('F1 on a fixed-size matrix tree: one copy', [([1], op_f1)]),
    'fuse7_f1_mat1': ('F1 on a one-node matrix tree (Decision 111)', [([1], op_f1)]),
    'fuse7_f1_asg1': ('F1 (3) with F2 (6): a one-node asg set value, reuse prologue',
                      [([1], f1_reuse)]),
    'fuse7_f1_sel_inplace': ('F1 (3) a selection store in place', [([2], f1_sel_inplace)]),
    'fuse7_f1_sel_res': ('F1 (5) a selection store with RES (shifted read)', [([1], op_selres)]),
    'fuse7_f1_barrier': ('F1 (2) a failing inner node made a leaf', [([2], op_f1)]),
    'fuse7_f2_group': ('F2 a group with its space test and split copy, two stored locals',
                       [([2, 3], 'group')]),
    'fuse7_f2_end': ('F2 (3) a group ended at a dependence; an unstored and a stored local',
                     [([1, 2], 'group'), ([3], op_f1)]),
    'fuse7_f2_reuse': ('F2 (6) buffer reuse in a group', [([2, 3], 'group')]),
    'fuse7_f3_sum': ('F3 sum (sum8) over a tree', [([1], f3_sum)]),
    'fuse7_f3_max_mask': ('F3 max over a same-mask selection tree',
                          [([2], lambda f, s: f3_maxmask(f, s, 'max'))]),
    'fuse7_f3_argmax_mask': ('F3 argmax over a same-mask selection',
                             [([2], lambda f, s: f3_maxmask(f, s, 'argmax'))]),
    'fuse7_f4_flat': ('F4 .flat folded', [([1], op_f1)]),
    'fuse7_f4_t': ('F4 .T folded (fixed-size)', [([1], op_f1)]),
    'fuse7_f4_range': ('F4 a range selection folded', [([1], op_f1)]),
    'fuse7_f4_idxvec': ('F4 an index vector folded', [([2], op_f1)]),
    'fuse7_f4_cat': ('F4 a concatenation part copied from its base', [([1], f4_cat)]),
    'fuse7_f5_tree': ('F5 an elemental application inside a tree', [([1], op_f1)]),
    'fuse7_inl': ('an inl function whose body was fused (L20 copies the HL records)', []),
    'fuse7_prel': ('a prelude call as a leaf of a fused tree', [([0], op_f1)]),
    'fuse7c2_grp_sum': ('F2 with an F3 sum over a tree reading the group local', [([1, 2], 'group')]),
    'fuse7c2_grp_mask': ('F2 with a masked F3 max over the group local', [([2, 3], 'group')]),
    'fuse7c2_f3_flat': ('F3 sum over .flat of a matrix tree', [([1], f3_sum)]),
    'fuse7c2_mm_sum': ('F3 sum over a same-mask MM selection tree A[m] - B[m]',
                       [([4], f3_sum), ([6], f3_sum)]),
    'fuse7c2_msum': ('F3 masked sum alone: the mask tptr numbered before F8', [([2], f3_sum)]),
    'fuse7c2_grp_tbind': ('F2 with a tbind of a two-result elemental function (W1 shape)',
                          [([2, 3, 4, 5], 'group')]),
    'fuse7c2_sel_ra': ('F1 (3) in-place store of kinds R and A on a matrix', [([4], f1_sel_inplace)]),
    'fuse7c2_sel_m': ('F1 (3) in-place mask store (M)', [([3], f1_sel_inplace)]),
    'fuse7c2_sel_mm': ('F1 (3) in-place whole-matrix mask store (MM)', [([3], f1_sel_inplace)]),
    'fuse7c2_cat_mat': ('F4 a matrix concatenation of a view and a selection part', [([2], f4_cat)]),
    'fuse7c2_grp_mat': ('F2 a matrix group whose first statement is a folded selection',
                        [([1, 2], 'group')]),
    'fuse7c2_bcast_fold': ('F1 (4) a folded .T read in the broadcast copy (D3)', [([5], op_f1)]),
}


def fuse7_hirf(nm, hir_text):
    f = File(hir_text)
    _, ops = FUSE7[nm]
    main = next(fn for fn in f.funcs if fn.rec[2] == 'main')
    body = main.body.kids
    repl = {}
    for idx, op in ops:
        after = body[idx[-1] + 1:]
        if op == 'group':
            repl[idx[0]] = f2_group(f, [body[i] for i in idx], after)
        else:
            repl[idx[0]] = op(f, body[idx[0]])
        for i in idx[1:]:
            repl[i] = []
    out = []
    for i, st in enumerate(body):
        out += repl.get(i, [st])
    main.body.kids = out
    main.body.f[1] = str(len(out))
    for fn in f.funcs:
        if fn.rec[2] == 'inl':                  # the body of an inl function: its ret's tree
            for st in fn.body.kids:
                if st.op == 'ret':
                    st.kids = [f1_value(f, st.f[0], st.kids[0])]
    return f.text()


def part4():
    out = {}
    for nm in sorted(FUSE7):
        text = fuse7_hirf(nm, read(os.path.join(SRC_PASSES, nm + '.hir')))
        write(nm + '.hirf', text)
        out[nm] = text
    return out


def main():
    found = part1()
    written = part2(found)
    n3 = part3(written)
    w4 = part4()
    for nm in sorted(found):
        if nm in written:
            print("  %s.hirf: %s (%s)" % (nm, NOTES[nm], found[nm]))
    for nm in sorted(w4):
        print("  %s.hirf: %s" % (nm, FUSE7[nm][0]))
    print('dump7_cases: part 1 (scan): %d of the .hir goldens need a .hirf; part 2 (.hirf): %d; '
          'part 3 (cross-check with the committed .hirl): %d; part 4 (fuse7_* .hirf): %d; %s'
          % (len(found), len(written), n3, len(w4), 'checked' if CHECK else 'written'))


if __name__ == '__main__':
    main()
