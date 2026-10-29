"""Phase-7 dump goldens, part 1: sub-phase 7b, package T2 (DESIGN.md 6.2 "Phase-7 tests", "Neutral
7b": "the 6c `elem6_*` goldens given their `NAME.hirf` (L19's output now `seafuse`'s)"; 2.12.3
`sea.hirf` rules (1)-(5) and "L19 in `seafuse`"; 2.11.4 L19 and `ind2sub` with an array `r`;
3.5.9 "Types", "Locals", the 4e notation, L7 (rule 22's checks and nest), L11's statement forms;
Decision 109; lead decision L-ek). Sub-phase 7c extends this generator with the `fuse7_*` dumps.

Run with `timeout 120 uv run --no-project python tests/vectors/dump7_cases.py [--out DIR]
[--check]`. It writes its goldens in tests/passes/ (or DIR); with --check it writes nothing and only
checks that every file it owns is what it would write. Its inputs are the committed goldens
NAME.hir (and, for the cross-check, NAME.hirl) of tests/passes/ and include/passes.txt.

Part 1, the scan: every tests/passes/*.hir is parsed (the record formats of passes.txt); a file that
holds an `emap` or a `lib ind2sub` whose first argument (r) is an array is one L19 rewrites, so its
test needs a NAME.hirf; every other file holds none of the constructs `seafuse` rewrites in 7b (7b's
`seafuse` performs no F1-F4, only L19), so its sea.hirf is its sea.hir byte for byte (2.12.3, L-ek)
and it gets no NAME.hirf. The scan asserts that the files needing one are exactly elem6_inst,
elem6_k5 and elem6_vec (ew_ind2sub's r is a scalar: L11, which stays `sealoop`'s).

Part 2, the NAME.hirf of those three: their NAME.hir with
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
                    fts, _ = field_types(n.op, [str(v) if not isinstance(v, (Loc, TP)) else '0'
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
        if nm.endswith('.hir'):
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


def part2(found):
    out = {}
    for nm in sorted(found):
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


def main():
    found = part1()
    written = part2(found)
    n3 = part3(written)
    for nm in sorted(found):
        print('  %s.hirf: %s (%s)' % (nm, NOTES[nm], found[nm]))
    print('dump7_cases: part 1 (scan): %d of the .hir goldens need a .hirf; part 2 (.hirf): %d; '
          'part 3 (cross-check with the committed .hirl): %d; %s'
          % (len(found), len(written), n3, 'checked' if CHECK else 'written'))


if __name__ == '__main__':
    main()
