"""Sub-phase 6d dump goldens, package T2 (DESIGN.md 6.2 "Phase-6 tests": "6d, write_json", the
`json6_*` dumps: the .hir of pass 2b's step 4 (the .j locals, the loops of a vector and a matrix of
structs, `dyn` under `jvec`), the .hirl, and the .lir1 of rule 39; 3.5.7 step 4, 3.5.5's `j*`
records, include/passes.txt HF 63-71, 2.11.4 "write_json (6d)", 2.11.5 rule 39's JSON rows, 4.8
entries 27-38; lead decisions L-ce, L-cu, L-cv).

Run with `timeout 120 uv run --no-project python tests/vectors/dump6d_cases.py [--out DIR]
[--check]`. It writes in tests/passes/ (or DIR); with --check it writes nothing and only checks that
every file it owns is what it would write.

The cases (each .sea .ast .res .hir1 .hir .hirl .out; .lir1 where named):
* json6_struct: a struct with an f64, an i64, a bool, a str, a fixed-size f64[3] and a dynamic
  f64[,] field: jobj, jkey + jval for each scalar, jvec (dyn e) for the fixed field (L-ce; the dyn
  rewritten by L10 in the .hirl), jmat, jend.
* json6_vecstruct: a vector of structs: jarr, fore over the elements (the .j3 loop variable; L4
  in the .hirl), jend; the struct has an f64, i64, bool, str, f64[] and f64[,] field, so its .lir1
  holds every j* record and every jval entry (rule 39: JSON_OPEN ... JSON_CLOSE, entries 27-38).
* json6_matstruct: a matrix of structs: the guard of L-cv and the two forr loops (.j3 the inner C,
  .j4 the outer R: their declaring records in file order, 3.5.4); .lir1 too (rule 4's forr, rule
  18's struct element field reads, rule 3's ||).

Sources of each golden (never the output of a 6d pass: the 6d passes are written concurrently):
* .ast and .res: passes 1 and 2a-seaname, which 6d does not change (DESIGN 8 row 6d lists no
  seaparse or seaname work), run once at commit 699c6d2 and embedded here; their positions are
  checked against the source below.
* .hir1: by hand from 3.5.4-3.5.5 and 2.11.2's "Library calls of phase 6" (`lib P 1 write_json 2`,
  the path a `cs`, the value unchanged, under an `eval`). Every other record was cross-checked
  against seacheck at 699c6d2 on the same program with the write_json line replaced by `let _ = v`.
* .hir: by the model of step 4 below (expand), a direct transcription of 3.5.7 step 4 by type,
  then the type table renumbered by 3.5.1 (step 5); steps 1-3 change nothing here (no cref, nothing
  to fold, no elemental call: checked).
* .hirl: by the sealoop model below (L1, L3, L4, L9 (a), (d), L10; the j* records kept with their
  children rewritten, 2.11.4), locals numbered by 3.5.9 "Locals" and tptr types by "Types". The
  parts outside the write_json block were cross-checked against sealoop at 699c6d2 on the program
  without the write_json line (they are unchanged by 6d).
* .lir1: by hand, instruction by instruction, each derivation beside it (3.6.1-3.6.4, 3.6.6 rules
  1-4, 7, 8, 15-18, 27 (e), 30, 38, 39, "Lowering of the sea.hirl records").
* .out: LANGUAGE.md 11.1 (the program prints `done`; the JSON file it writes into the run directory
  is T1's to check, tests/programs/json_*).
"""

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import dump6_cases as d6  # noqa: E402  (shares --out/--check, write, read, the passes.txt formats)

CHECK = d6.CHECK
write = d6.write


def dump(name, body):
    """A dump file: the three header records, the body lines (blank lines dropped), #end."""
    return ('#sea 1\n#target arm64-macos\n#file %s.sea\n' % name
            + '\n'.join(ln for ln in body.strip('\n').split('\n') if ln.strip()) + '\n#end\n')


def check_positions(name, src, text, skip=('fn', 'par', 'loc', 'end')):
    """Every positioned record of a dump names a token of the source: its line and column exist
    and the byte there is not a blank (3.3)."""
    sl = src.split('\n')
    for ln in text.split('\n'):
        p = ln.split(' ')
        if not ln or ln.startswith('#') or p[0] in skip:
            continue
        for f in p[1:]:
            m = re.match(r'^0:([0-9]+):([0-9]+)$', f)
            if m:
                l, c = int(m.group(1)), int(m.group(2))
                if (l, c) == (1, 1):
                    continue
                assert l <= len(sl) and c <= len(sl[l - 1]) and sl[l - 1][c - 1] != ' ', (name, ln)


# ================================================================ HIR trees and types
class Node:
    """A HIR record and its children (post-order in the file, 3.3). fields: the record's fields
    after the opcode; a field may be a Loc (a local created here, numbered when written) or a
    type key (a tuple, numbered when written)."""
    def __init__(self, op, fields, kids=()):
        self.op, self.fields, self.kids = op, list(fields), list(kids)


def N(op, *fields, kids=()):
    return Node(op, fields, kids)


class Loc:
    """A local pass 2b (`.j`) or sealoop (`.l`) creates: its type, mut and position."""
    def __init__(self, prefix, ty, mut, pos):
        self.prefix, self.ty, self.mut, self.pos, self.num = prefix, ty, mut, pos, None


def ty_index(op):
    """The indexes (in the field list after the opcode) of a HIR record's `ty` fields, and whether
    the record has a counted `ty*n` field (passes.txt)."""
    for s in d6.FMT:
        if s[0] == 'H' and op in d6.FMT[s]:
            spec = d6.FMT[s][op]
            break
    else:
        raise AssertionError(('no format', op))
    return [i for i, f in enumerate(spec) if f.split(':', 1)[1].split('*')[0].rstrip('?') == 'ty']


TABLE_OPS = ('tvec', 'tmat', 'tfvec', 'tfmat', 'tstruct', 'trec', 'fd', 'ttuple')


def parse_hir(text):
    """(type keys by id, the records after the table as field lists). A type key is the type
    itself: 1-9 the predefined ids, ('vec', e), ('mat', e), ('fvec', e, n), ('fmat', e, r, c),
    ('struct', name, ((field, key), ...)), ('rec', ((field, key), ...)) (3.5.1)."""
    lines = [ln.split(' ') for ln in text.split('\n') if ln and not ln.startswith('#')]
    raw, i = {}, 0
    while lines[i][0] in TABLE_OPS:
        r = lines[i]
        if r[0] in ('tstruct', 'trec'):
            n = int(r[3] if r[0] == 'tstruct' else r[2])
            raw[r[1]] = (r, [lines[i + 1 + k] for k in range(n)])
            i += 1 + n
        else:
            raw[r[1]] = (r, [])
            i += 1
    keys = {str(k): k for k in range(1, 10)}

    def key(tid):
        if tid in keys:
            return keys[tid]
        r, fds = raw[tid]
        if r[0] == 'tvec':
            k = ('vec', key(r[2]))
        elif r[0] == 'tmat':
            k = ('mat', key(r[2]))
        elif r[0] == 'tfvec':
            k = ('fvec', key(r[2]), int(r[3]))
        elif r[0] == 'tfmat':
            k = ('fmat', key(r[2]), int(r[3]), int(r[4]))
        elif r[0] == 'tstruct':
            k = ('struct', r[2], tuple((f[1], key(f[2])) for f in fds))
        elif r[0] == 'trec':
            k = ('rec', tuple((f[1], key(f[2])) for f in fds))
        else:
            raise AssertionError(r)
        keys[tid] = k
        return k

    for tid in raw:
        key(tid)
    recs = []
    for r in lines[i:]:
        r = list(r)
        for j in ty_index(r[0]):
            r[1 + j] = keys[r[1 + j]]
        if r[0] == 'ttuple':
            raise AssertionError('no tuples here')
        recs.append(r)
    return keys, recs


def components(k):
    if isinstance(k, int):
        return []
    if k[0] in ('vec', 'mat', 'fvec', 'fmat'):
        return [k[1]]
    if k[0] == 'struct':
        return [t for _, t in k[2]]
    if k[0] == 'rec':
        return [t for _, t in k[1]]
    raise AssertionError(k)


def write_types(recs):
    """3.5.1 numbering: ids from 10 in order of first reference in the records after the table
    (file order, fields left to right), unnumbered components first, recursively; the table in id
    order, then the records with their type fields as ids."""
    ids, order = {}, []

    def number(k):
        if isinstance(k, int) or k in ids:
            return
        for c in components(k):
            number(c)
        ids[k] = 10 + len(order)
        order.append(k)

    out = []
    for r in recs:
        r = list(r)
        for j in ty_index(r[0]):
            if r[1 + j] != '-':
                number(r[1 + j])
                r[1 + j] = str(r[1 + j] if isinstance(r[1 + j], int) else ids[r[1 + j]])
        out.append(r)

    def tid(k):
        return str(k if isinstance(k, int) else ids[k])

    table = []
    for k in order:
        i = str(ids[k])
        if k[0] == 'vec':
            table.append('tvec %s %s' % (i, tid(k[1])))
        elif k[0] == 'mat':
            table.append('tmat %s %s' % (i, tid(k[1])))
        elif k[0] == 'fvec':
            table.append('tfvec %s %s %d' % (i, tid(k[1]), k[2]))
        elif k[0] == 'fmat':
            table.append('tfmat %s %s %d %d' % (i, tid(k[1]), k[2], k[3]))
        elif k[0] == 'struct':
            table.append('tstruct %s %s %d' % (i, k[1], len(k[2])))
            table += ['fd %s %s' % (f, tid(t)) for f, t in k[2]]
        else:
            table.append('trec %s %d' % (i, len(k[1])))
            table += ['fd %s %s' % (f, tid(t)) for f, t in k[1]]
    return table, [' '.join(str(x) for x in r) for r in out], ids


def tree(recs):
    """The post-order records as Nodes; returns the roots (3.3, passes.txt pops)."""
    stack = []
    for r in recs:
        d = d6.fields_of('H', [str(x) if not isinstance(x, tuple) else '10' for x in r])
        k = d6.npops('H', r, d) if r[0] not in ('fn', 'par', 'loc', 'end') else 0
        kids = stack[len(stack) - k:] if k else []
        if k:
            del stack[len(stack) - k:]
        stack.append(Node(r[0], r[1:], kids))
    return stack


def post(n, out):
    for k in n.kids:
        post(k, out)
    out.append(n)
    return out


def number_locals(nodes, first, prefix, decl):
    """Numbers the Locs of `prefix` that the declaring records `decl` bind (op -> index of the lid
    field), in file order (post-order), from `first`; returns them in order (3.5.4, 3.5.9)."""
    got = []
    for n in nodes:
        for m in post(n, []):
            if m.op in decl:
                x = m.fields[decl[m.op]]
                if isinstance(x, Loc) and x.prefix == prefix and x.num is None:
                    x.num = first + len(got)
                    got.append(x)
    return got


def fmt_field(v):
    return str(v.num) if isinstance(v, Loc) else v


def records(nodes):
    """The post-order record lines (fields as lists, Locs as numbers, type keys kept)."""
    out = []
    for n in nodes:
        for m in post(n, []):
            out.append([m.op] + [fmt_field(v) for v in m.fields])
    return out


# ================================================================ pass 2b, step 4 (3.5.7)
JSON_SCALARS = (2, 3, 4, 5)        # bool, i64, f64, str (L-cu: str counts with the scalars)


def fields_of_type(k):
    return k[2] if k[0] == 'struct' else k[1]


def emit(e, k, P, new_for, rng_ty):
    """emit(e) of 3.5.7 step 4 for a value of type k; e() makes a fresh copy of the expression (an
    `lv`, `fld` or `idx` path of locals, so reading it again has no effect). Returns the
    statements. new_for(k) makes the next `.j` loop local (mut `for`) of type k."""
    if k in JSON_SCALARS:
        return [N('jval', P, kids=[e()])]
    assert not isinstance(k, int), ('a handle type has no case', k)
    if k[0] in ('struct', 'rec'):
        out = [N('jobj', P)]
        for i, (f, t) in enumerate(fields_of_type(k)):
            out.append(N('jkey', P, f))
            out += emit(lambda i=i, t=t: N('fld', P, t, str(i), kids=[e()]), t, P, new_for, rng_ty)
        return out + [N('jend', P)]
    elt = k[1]
    if elt in JSON_SCALARS:
        if k[0] == 'vec':
            return [N('jvec', P, kids=[e()])]
        if k[0] == 'fvec':                            # L-ce: the dyn to the dynamic type
            return [N('jvec', P, kids=[N('dyn', P, ('vec', elt), kids=[e()])])]
        if k[0] == 'mat':
            return [N('jmat', P, kids=[e()])]
        return [N('jmat', P, kids=[N('dyn', P, ('mat', elt), kids=[e()])])]
    assert elt[0] in ('struct', 'rec'), k
    if k[0] in ('vec', 'fvec'):
        K = new_for(elt)
        body = emit(lambda: N('lv', P, elt, K), elt, P, new_for, rng_ty)
        return [N('jarr', P), N('fore', P, K, kids=[e(), N('block', P, str(len(body)), kids=body)]),
                N('jend', P)]
    # a matrix of structs or records: if (rows(e) == 0 || cols(e) == 0) { jarr; jend } else {
    # jarr; forr R in 0..rows(e) { jarr; forr C in 0..cols(e) { emit(idx e (lv R) (lv C)) };
    # jend }; jend }
    def ext(name):
        return N('lib', P, 3, name, '1', kids=[e()])

    def is0(name):
        return N('bin', P, 2, 'eq', kids=[ext(name), N('ci', P, 3, '0')])

    cond = N('bin', P, 2, 'or', kids=[is0('rows'), is0('cols')])
    then = N('block', P, '2', kids=[N('jarr', P), N('jend', P)])
    R = new_for(3)
    C = new_for(3)
    inner = emit(lambda: N('idx', P, elt, '2', kids=[e(), N('lv', P, 3, R), N('lv', P, 3, C)]), elt,
                 P, new_for, rng_ty)

    def rng(name):
        return N('rng', P, rng_ty, '0', '0', kids=[N('ci', P, 3, '0'), ext(name)])

    forc = N('forr', P, C, kids=[rng('cols'), N('block', P, str(len(inner)), kids=inner)])
    forr = N('forr', P, R, kids=[rng('rows'), N('block', P, '3', kids=[N('jarr', P), forc,
                                                                      N('jend', P)])])
    other = N('block', P, '3', kids=[N('jarr', P), forr, N('jend', P)])
    return [N('if', P, '1', kids=[cond, then, other])]


def expand(hir1):
    """sea.hir of a one-function sea.hir1 by 3.5.7: steps 1-3 change nothing (checked: no cref,
    no foldable node, no call); step 4 for each `eval` of `lib write_json`; step 5 keeps .main
    (the only function) and renumbers the types (3.5.1)."""
    keys, recs = parse_hir(hir1)
    ops = set(r[0] for r in recs)
    assert not ops & {'cref', 'cn', 'call', 'emap', 'un', 'bin', 'powk', 'cvt'}, ops
    roots = tree(recs)
    head = [n for n in roots if n.op in ('fn', 'par', 'loc')]
    assert [n.op for n in roots[len(head):]] == ['block', 'end'] and head[0].op == 'fn', roots
    body = roots[len(head)]
    nloc = len(head) - 1
    jlocs = []
    stmts = []
    for s in body.kids:
        if not (s.op == 'eval' and s.kids[0].op == 'lib' and s.kids[0].fields[2] == 'write_json'):
            stmts.append(s)
            continue
        P = s.fields[0]
        path, value = s.kids[0].kids
        vty = value.fields[1]
        J1 = Loc('.j', 5, 'let', P)                 # the path: mut let, the path's type (str)
        J2 = Loc('.j', vty, 'let', P)               # the value: mut let, the value's type
        jl = [J1, J2]

        def new_for(k, jl=jl, P=P):
            x = Loc('.j', k, 'for', P)
            jl.append(x)
            return x

        em = emit(lambda: N('lv', P, vty, J2), vty, P, new_for, ('vec', 3))
        blk = [N('bind', P, J1, kids=[path]), N('bind', P, J2, kids=[value]),
               N('jopen', P, kids=[N('lv', P, 5, J1)])] + em + [N('jclose', P)]
        stmts.append(N('block', P, str(len(blk)), kids=blk))
        jlocs += jl
    got = number_locals(stmts, nloc + 1, '.j', {'bind': 1, 'fore': 1, 'forr': 1})
    assert set(map(id, got)) == set(map(id, jlocs)), 'every .j local is declared'
    fn = head[0]
    fn.fields[5] = str(int(fn.fields[5]) + len(got))
    newbody = N('block', body.fields[0], str(len(stmts)), kids=stmts)
    out = records(head) + [['loc', '.j%d' % (i + 1), x.ty, x.mut, x.pos] for i, x in enumerate(got)]
    out += records([newbody]) + [['end']]
    table, lines, _ = write_types(out)
    return '\n'.join(table + lines)


# ================================================================ sealoop (3.5.9)
def layout(k):
    """(size, alignment, reference offsets) of a type by 4.8's struct layout rule."""
    if k in (3, 4):
        return 8, 8, []
    if k == 2:
        return 1, 1, []
    if k == 5 or (isinstance(k, tuple) and k[0] in ('vec', 'mat')):
        return 8, 8, [0]
    if k[0] in ('fvec', 'fmat'):
        n = k[2] if k[0] == 'fvec' else k[2] * k[3]
        s, a, r = layout(k[1])
        return s * n, a, [i * s + o for i in range(n) for o in r]
    off, al, refs = 0, 1, []
    for _, t in fields_of_type(k):
        s, a, r = layout(t)
        off = (off + a - 1) // a * a
        refs += [off + o for o in r]
        off += s
        al = max(al, a)
    return (off + al - 1) // al * al, al, refs


ESIZE = {4: 8, 3: 8, 2: 1}       # SEA_ESIZE_F64, SEA_ESIZE_I64, SEA_ESIZE_BOOL (4.8)


class Loop:
    """The sealoop model: rewrites a .main body (Nodes of sea.hir with type keys) into sea.hirl."""
    def __init__(self):
        self.locs = []

    def tmp(self, P, ty, child):
        x = Loc('.l', ty, 'let', P)
        return N('tmp', P, x, kids=[child]), x

    def lv(self, P, x):
        return N('lv', P, x.ty, x)

    def stmt(self, n):
        if n.op == 'fore':
            return self.l4(n)
        return Node(n.op, n.fields, [self.any(k) for k in n.kids])

    def any(self, n):
        if n.op in ('block', 'if', 'forr', 'bind', 'eval', 'fore') or n.op.startswith('j'):
            return self.stmt(n) if n.op != 'block' else Node(n.op, n.fields,
                                                                [self.stmt(k) for k in n.kids])
        return self.expr(n)

    def expr(self, n):
        if n.op == 'arr':
            return self.l9(n)
        kids = [self.any(k) for k in n.kids]
        if n.op == 'lib' and n.fields[2] == 'zeros':                     # L1
            return N('anew', n.fields[0], n.fields[1], '1', str(len(kids)), kids=kids)
        if n.op == 'lib' and n.fields[2] in ('rows', 'cols', 'len'):     # L3
            return N('ext', n.fields[0], 3, '1' if n.fields[2] == 'cols' else '0', kids=kids)
        if n.op == 'dyn':
            return self.l10(n, kids[0])
        assert n.op in ('ci', 'cf', 'cb', 'cs', 'lv', 'fld', 'idx', 'slit', 'lib', 'fmt', 'ftext',
                        'fconv', 'bin', 'rng'), n.op
        if n.op == 'lib':
            assert n.fields[2] == 'printf', n.fields
        return Node(n.op, n.fields, kids)

    def l9(self, n):
        """L9 (a) a fixed-size literal of numeric scalars without concatenation; (d) `[]`."""
        P, T = n.fields[0], n.fields[1]
        if n.fields[2] == '0':                                         # (d) [] of a dynamic T
            assert T[0] in ('vec', 'mat'), T
            k = 1 if T[0] == 'vec' else 2
            return N('anew', P, T, '1', str(k), kids=[N('ci', P, 3, '0') for _ in range(k)])
        assert T[0] == 'fvec' and n.fields[2] == '1' and T[1] in ESIZE, T     # (a), one row
        elems = n.kids[0].kids
        assert all(e.op in ('ci', 'cf', 'cb') for e in elems)
        sh, h = self.tmp(P, T, N('anew', P, T, '0', '0'))
        sd, d = self.tmp(P, ('ptr', T[1]), N('adat', P, ('ptr', T[1]), kids=[self.lv(P, h)]))
        st = [sh, sd]
        for i, e in enumerate(elems):
            st.append(N('est', P, str(ESIZE[T[1]]), '0',
                        kids=[e, self.lv(P, d), N('ci', P, 3, str(i))]))
        return N('xblk', P, T, str(len(st)), kids=st + [self.lv(P, h)])

    def l10(self, n, opnd):
        """L10's `dyn` of a fixed-size vector of numeric elements: tmp S = the operand, tmp R =
        ext(S, 0), tmp A = anew P T 0 1 (lv R), tmp D = data(A), tmp N = ci bytes, mcpy (lv D)
        data(S) (lv N), value lv A."""
        P, T = n.fields[0], n.fields[1]
        F = opnd.fields[1]
        assert T[0] == 'vec' and F[0] == 'fvec' and F[1] in ESIZE, (T, F)
        ptr = ('ptr', F[1])
        ss, s = self.tmp(P, F, opnd)
        sr, r = self.tmp(P, 3, N('ext', P, 3, '0', kids=[self.lv(P, s)]))
        sa, a = self.tmp(P, T, N('anew', P, T, '0', '1', kids=[self.lv(P, r)]))
        sd, d = self.tmp(P, ptr, N('adat', P, ptr, kids=[self.lv(P, a)]))
        sn, nb = self.tmp(P, 3, N('ci', P, 3, str(F[2] * ESIZE[F[1]])))
        mc = N('mcpy', P, kids=[self.lv(P, d), N('adat', P, ptr, kids=[self.lv(P, s)]),
                                self.lv(P, nb)])
        st = [ss, sr, sa, sd, sn, mc]
        return N('xblk', P, T, str(len(st)), kids=st + [self.lv(P, a)])

    def l4(self, n):
        """L4 `fore X v body`: block P 4 { bind H = v; tmp N = ext(H, 0); tmp Z = ci 0; if (N > Z)
        { tmp D = data(H); tmp O = ci 1; tmp L = N - O (wbin); hloop K (Z) (L) (O) { tmp X = eld
        P E s 0 (lv D) (lv K); body } } }; a struct element: eld P S s(S) 0, its address (R18)."""
        P, X = n.fields[0], n.fields[1]
        v, body = self.expr(n.kids[0]), self.stmt(n.kids[1])
        V = v.fields[1]
        E = V[1]
        assert V[0] == 'vec' and isinstance(E, tuple) and E[0] in ('struct', 'rec'), V
        H = Loc('.l', V, 'let', P)
        bh = N('bind', P, H, kids=[v])
        sn, nn = self.tmp(P, 3, N('ext', P, 3, '0', kids=[self.lv(P, H)]))
        sz, z = self.tmp(P, 3, N('ci', P, 3, '0'))
        sd, d = self.tmp(P, ('ptr', E), N('adat', P, ('ptr', E), kids=[self.lv(P, H)]))
        so, o = self.tmp(P, 3, N('ci', P, 3, '1'))
        sl, l = self.tmp(P, 3, N('wbin', P, 3, 'sub', kids=[self.lv(P, nn), self.lv(P, o)]))
        K = Loc('.l', 3, 'for', P)
        sx = N('tmp', P, X, kids=[N('eld', P, E, str(layout(E)[0]), '0',
                                    kids=[self.lv(P, d), N('lv', P, 3, K)])])
        hl = N('hloop', P, K, kids=[self.lv(P, z), self.lv(P, l), self.lv(P, o),
                                    N('block', P, '2', kids=[sx, body])])
        cond = N('bin', P, 2, 'gt', kids=[self.lv(P, nn), self.lv(P, z)])
        iff = N('if', P, '0', kids=[cond, N('block', P, '4', kids=[sd, so, sl, hl])])
        return N('block', P, '4', kids=[bh, sn, sz, iff])


def sealoop(hir):
    """sea.hirl of a one-function sea.hir by the model above: the table kept, tptr appended."""
    keys, recs = parse_hir(hir)
    nhir = max(int(k) for k in keys)                # the last id of sea.hir's table
    roots = tree(recs)
    head = [n for n in roots if n.op in ('fn', 'par', 'loc')]
    body = roots[len(head)]
    lp = Loop()
    nb = Node('block', body.fields, [lp.stmt(s) for s in body.kids])
    got = number_locals([nb], len(head), '.l', {'tmp': 1, 'bind': 1, 'hloop': 1})
    fn = head[0]
    fn.fields[5] = str(int(fn.fields[5]) + len(got))
    out = records(head) + [['loc', '.l%d' % (i + 1), x.ty, x.mut, x.pos] for i, x in enumerate(got)]
    out += records([nb]) + [['end']]
    # sea.hir's ids carry over (its table is written as it is); tptr types numbered on from the
    # last id in order of first reference (file order, fields left to right)
    table, _, _ = write_types(recs)
    ids = {}
    for k, v in keys.items():
        if isinstance(v, tuple):
            ids[v] = int(k)
    ptrs = []
    lines = []
    for r in out:
        r = list(r)
        for j in ty_index(r[0]):
            t = r[1 + j]
            if isinstance(t, tuple) and t[0] == 'ptr':
                if t not in ids:
                    ids[t] = nhir + 1 + len(ptrs)
                    ptrs.append(t)
                r[1 + j] = str(ids[t])
            elif isinstance(t, tuple):
                r[1 + j] = str(ids[t])
            else:
                r[1 + j] = str(t)
        lines.append(' '.join(str(x) for x in r))
    ptab = ['tptr %d %s' % (ids[t], t[1] if isinstance(t[1], int) else ids[t[1]]) for t in ptrs]
    return '\n'.join(table + ptab + lines)


# ================================================================ sources and front-end goldens
SEA = {
    'json6_struct': """// json6_struct -- write_json of a struct (DESIGN.md 3.5.7 step 4): jobj, then a jkey and a jval
// for each scalar field (f64, i64, bool, str), jvec (dyn e) for the fixed-size field w (L-ce; the
// dyn rewritten by L10), jmat for the dynamic matrix m, and jend; .j1 the path, .j2 the value
struct P {
    x: f64
    n: i64
    ok: bool
    name: str
    w: f64[3]
    m: f64[,]
}
let p = P { x: 1.5, n: 7, ok: true, name: "a", w: [1.0, 2.0, 3.0], m: zeros(2, 2) }
write_json("p.json", p)
printf("done\\n")
""",
    'json6_vecstruct': """// json6_vecstruct -- write_json of a vector of structs (DESIGN.md 3.5.7 step 4): jarr, a fore
// over the elements (the .j3 loop variable; L4 in sealoop) whose body is the struct's jobj ...
// jend, then jend; every j* record and every jval entry (f64, i64, bool, str) lowered by rule
// 39 (2.11.5); the empty vector is written [] by the same code
struct P {
    x: f64
    n: i64
    ok: bool
    s: str
    v: f64[]
    m: f64[,]
}
let ps: P[] = []
write_json("ps.json", ps)
printf("done\\n")
""",
    'json6_matstruct': """// json6_matstruct -- write_json of a matrix of structs (DESIGN.md 3.5.7 step 4, L-cv): the guard
// if (rows(e) == 0 || cols(e) == 0) { jarr; jend } else { jarr; forr R { jarr; forr C { the
// struct of idx e R C }; jend }; jend }; the inner loop variable C is .j3 and R .j4 (declaring
// records in file order, 3.5.4); rows and cols become ext (L3), the forr loops stay
struct Q {
    a: f64
    b: str
}
let qm: Q[,] = []
write_json("qm.json", qm)
printf("done\\n")
""",
}

# pass 1 (seaparse) at 699c6d2, unchanged by 6d
AST = {
    'json6_struct': """
type 0:5:8 f64 s 0
field 0:5:5 x
type 0:6:8 i64 s 0
field 0:6:5 n
type 0:7:9 bool s 0
field 0:7:5 ok
type 0:8:11 str s 0
field 0:8:5 name
int 0:9:12 3
type 0:9:8 f64 fv 1
field 0:9:5 w
type 0:10:8 f64 m 0
field 0:10:5 m
struct 0:4:1 P 6
pname 0:12:5 p
float 0:12:16 #3FF8000000000000
init 0:12:13 x
int 0:12:24 7
init 0:12:21 n
true 0:12:31
init 0:12:27 ok
str 0:12:43 a
init 0:12:37 name
float 0:12:52 #3FF0000000000000
float 0:12:57 #4000000000000000
float 0:12:62 #4008000000000000
row 0:12:52 3
array 0:12:51 1
init 0:12:48 w
name 0:12:71 zeros
int 0:12:77 2
int 0:12:80 2
call 0:12:71 2
init 0:12:68 m
slit 0:12:9 P 6
let 0:12:1 0
name 0:13:1 write_json
str 0:13:12 p.json
name 0:13:22 p
call 0:13:1 2
cstmt 0:13:1
name 0:14:1 printf
str 0:14:8 done%0A
call 0:14:1 1
cstmt 0:14:1
prog 4
""",
    'json6_vecstruct': """
type 0:6:8 f64 s 0
field 0:6:5 x
type 0:7:8 i64 s 0
field 0:7:5 n
type 0:8:9 bool s 0
field 0:8:5 ok
type 0:9:8 str s 0
field 0:9:5 s
type 0:10:8 f64 v 0
field 0:10:5 v
type 0:11:8 f64 m 0
field 0:11:5 m
struct 0:5:1 P 6
pname 0:13:5 ps
type 0:13:9 P v 0
array 0:13:15 0
let 0:13:1 1
name 0:14:1 write_json
str 0:14:12 ps.json
name 0:14:23 ps
call 0:14:1 2
cstmt 0:14:1
name 0:15:1 printf
str 0:15:8 done%0A
call 0:15:1 1
cstmt 0:15:1
prog 4
""",
    'json6_matstruct': """
type 0:6:8 f64 s 0
field 0:6:5 a
type 0:7:8 str s 0
field 0:7:5 b
struct 0:5:1 Q 2
pname 0:9:5 qm
type 0:9:9 Q m 0
array 0:9:16 0
let 0:9:1 1
name 0:10:1 write_json
str 0:10:12 qm.json
name 0:10:23 qm
call 0:10:1 2
cstmt 0:10:1
name 0:11:1 printf
str 0:11:8 done%0A
call 0:11:1 1
cstmt 0:11:1
prog 4
""",
}

# pass 2a seaname at 699c6d2, unchanged by 6d
RES = {
    'json6_struct': """
rtst 10 P 1 6
rtfd x 4
rtfd n 3
rtfd ok 2
rtfd name 5
rtfd w 11
rtfd m 12
rtfvec 11 4 3
rtmat 12 4
rtype 0:5:8 f64 s 0 4
field 0:5:5 x
rtype 0:6:8 i64 s 0 3
field 0:6:5 n
rtype 0:7:9 bool s 0 2
field 0:7:5 ok
rtype 0:8:11 str s 0 5
field 0:8:5 name
rint 0:9:12 3 #4008000000000000
rtype 0:9:8 f64 fv 1 11
field 0:9:5 w
rtype 0:10:8 f64 m 0 12
field 0:10:5 m
rst 0:4:1 P 6 1
rpname 0:12:5 p 1
float 0:12:16 #3FF8000000000000
init 0:12:13 x
rint 0:12:24 7 #401C000000000000
init 0:12:21 n
true 0:12:31
init 0:12:27 ok
str 0:12:43 a
init 0:12:37 name
float 0:12:52 #3FF0000000000000
float 0:12:57 #4000000000000000
float 0:12:62 #4008000000000000
row 0:12:52 3
array 0:12:51 1
init 0:12:48 w
rname 0:12:71 zeros pd 0
rint 0:12:77 2 #4000000000000000
rint 0:12:80 2 #4000000000000000
call 0:12:71 2
init 0:12:68 m
rslit 0:12:9 P 6 1
let 0:12:1 0
rname 0:13:1 write_json pd 0
str 0:13:12 p.json
rname 0:13:22 p loc 1
call 0:13:1 2
cstmt 0:13:1
rname 0:14:1 printf pd 0
str 0:14:8 done%0A
call 0:14:1 1
cstmt 0:14:1
prog 4
""",
    'json6_vecstruct': """
rtst 10 P 1 6
rtfd x 4
rtfd n 3
rtfd ok 2
rtfd s 5
rtfd v 11
rtfd m 12
rtvec 11 4
rtmat 12 4
rtvec 13 10
rtype 0:6:8 f64 s 0 4
field 0:6:5 x
rtype 0:7:8 i64 s 0 3
field 0:7:5 n
rtype 0:8:9 bool s 0 2
field 0:8:5 ok
rtype 0:9:8 str s 0 5
field 0:9:5 s
rtype 0:10:8 f64 v 0 11
field 0:10:5 v
rtype 0:11:8 f64 m 0 12
field 0:11:5 m
rst 0:5:1 P 6 1
rpname 0:13:5 ps 1
rtype 0:13:9 P v 0 13
array 0:13:15 0
let 0:13:1 1
rname 0:14:1 write_json pd 0
str 0:14:12 ps.json
rname 0:14:23 ps loc 1
call 0:14:1 2
cstmt 0:14:1
rname 0:15:1 printf pd 0
str 0:15:8 done%0A
call 0:15:1 1
cstmt 0:15:1
prog 4
""",
    'json6_matstruct': """
rtst 10 Q 1 2
rtfd a 4
rtfd b 5
rtmat 11 10
rtype 0:6:8 f64 s 0 4
field 0:6:5 a
rtype 0:7:8 str s 0 5
field 0:7:5 b
rst 0:5:1 Q 2 1
rpname 0:9:5 qm 1
rtype 0:9:9 Q m 0 11
array 0:9:16 0
let 0:9:1 1
rname 0:10:1 write_json pd 0
str 0:10:12 qm.json
rname 0:10:23 qm loc 1
call 0:10:1 2
cstmt 0:10:1
rname 0:11:1 printf pd 0
str 0:11:8 done%0A
call 0:11:1 1
cstmt 0:11:1
prog 4
""",
}


# .hir1 by hand (3.5.4, 3.5.5; 2.11.2 "Library calls of phase 6": `write_json(path, value)` is
# `lib P 1 write_json 2` (type void) with the path, a `cs` of type 5, and the value unchanged, the
# statement an `eval` at the cstmt's position). Types by first reference (3.5.1): the loc record
# of the value's local numbers the struct's array field types first, then the struct, then (for a
# vector or matrix of structs) the array type. The `cs` and `lib` add no type.
HIR1 = {
    'json6_struct': """
tfvec 10 4 3
tmat 11 4
tstruct 12 P 6
fd x 4
fd n 3
fd ok 2
fd name 5
fd w 10
fd m 11
fn 1 .main main 1 0 1 0:1:1
loc p 12 let 0:12:5
cf 0:12:16 4 #3FF8000000000000
ci 0:12:24 3 7
cb 0:12:31 2 1
cs 0:12:43 5 a
cf 0:12:52 4 #3FF0000000000000
cf 0:12:57 4 #4000000000000000
cf 0:12:62 4 #4008000000000000
row 0:12:52 10 3
arr 0:12:51 10 1
ci 0:12:77 3 2
ci 0:12:80 3 2
lib 0:12:71 11 zeros 2
slit 0:12:9 12 6
bind 0:12:1 1
cs 0:13:12 5 p.json
lv 0:13:22 12 1
lib 0:13:1 1 write_json 2
eval 0:13:1
ftext 0:14:8 1 done%0A
fmt 0:14:8 1 1
lib 0:14:1 1 printf 1
eval 0:14:1
block 0:1:1 3
end
""",
    'json6_vecstruct': """
tvec 10 4
tmat 11 4
tstruct 12 P 6
fd x 4
fd n 3
fd ok 2
fd s 5
fd v 10
fd m 11
tvec 13 12
fn 1 .main main 1 0 1 0:1:1
loc ps 13 let 0:13:5
arr 0:13:15 13 0
bind 0:13:1 1
cs 0:14:12 5 ps.json
lv 0:14:23 13 1
lib 0:14:1 1 write_json 2
eval 0:14:1
ftext 0:15:8 1 done%0A
fmt 0:15:8 1 1
lib 0:15:1 1 printf 1
eval 0:15:1
block 0:1:1 3
end
""",
    'json6_matstruct': """
tstruct 10 Q 2
fd a 4
fd b 5
tmat 11 10
fn 1 .main main 1 0 1 0:1:1
loc qm 11 let 0:9:5
arr 0:9:16 11 0
bind 0:9:1 1
cs 0:10:12 5 qm.json
lv 0:10:23 11 1
lib 0:10:1 1 write_json 2
eval 0:10:1
ftext 0:11:8 1 done%0A
fmt 0:11:8 1 1
lib 0:11:1 1 printf 1
eval 0:11:1
block 0:1:1 3
end
""",
}

# The expected .hir block of json6_matstruct, written out by hand from 3.5.7 step 4 as a check of
# the model (expand) on the form with the most structure: P = 0:10:1; .j1 the path (lid 2), .j2
# the value (3), the inner C (.j3, 4) and the outer R (.j4, 5) numbered at their forr records in
# file order (post-order: the inner forr's record comes first); i64[] (the ranges' type, 3.5.1) is
# a new type, 12.
MAT_BLOCK = """
cs 0:10:12 5 qm.json
bind 0:10:1 2
lv 0:10:23 11 1
bind 0:10:1 3
lv 0:10:1 5 2
jopen 0:10:1
lv 0:10:1 11 3
lib 0:10:1 3 rows 1
ci 0:10:1 3 0
bin 0:10:1 2 eq
lv 0:10:1 11 3
lib 0:10:1 3 cols 1
ci 0:10:1 3 0
bin 0:10:1 2 eq
bin 0:10:1 2 or
jarr 0:10:1
jend 0:10:1
block 0:10:1 2
jarr 0:10:1
ci 0:10:1 3 0
lv 0:10:1 11 3
lib 0:10:1 3 rows 1
rng 0:10:1 12 0 0
jarr 0:10:1
ci 0:10:1 3 0
lv 0:10:1 11 3
lib 0:10:1 3 cols 1
rng 0:10:1 12 0 0
jobj 0:10:1
jkey 0:10:1 a
lv 0:10:1 11 3
lv 0:10:1 3 5
lv 0:10:1 3 4
idx 0:10:1 10 2
fld 0:10:1 4 0
jval 0:10:1
jkey 0:10:1 b
lv 0:10:1 11 3
lv 0:10:1 3 5
lv 0:10:1 3 4
idx 0:10:1 10 2
fld 0:10:1 5 1
jval 0:10:1
jend 0:10:1
block 0:10:1 6
forr 0:10:1 4
jend 0:10:1
block 0:10:1 3
forr 0:10:1 5
jend 0:10:1
block 0:10:1 3
if 0:10:1 1
jclose 0:10:1
block 0:10:1 5
"""

# ================================================================ .lir1 by hand (3.6)
# Registers numbered on first appearance (3.6.1); blocks from 1 in opening order (3.6.4); sites
# the line of the node's position; data labels by first reference (3.6.2: a new `str` record per
# occurrence, one `slay` per struct type). Rule 39 (2.11.5): the operands by rule 1, then `rcall
# <symbol> <site> 0 <na> <args>` (every JSON entry has Site S and no result, 4.8 entries 27-38);
# a jkey's operand is `la` of a new `str` record of its key (rule 7); borrowed operands (an `lv`,
# a field loaded by `ldp`) are not retained or released.
VEC_LIR1 = [
    ('func .main main 0:1:1 0 0', ''),
    ('slot s1 8 8', "rule 8: printf's argument slot, 8 * max(0, 1) bytes"),
    ('li i1 0', 'line 13, L9 (d): anew P P[] 1 1 (ci 0), arrnewz of struct elements (rule 17)'),
    ('la p2 d1', 'the slay of P (rule 38): size 48, its references at 24 (s), 32 (v), 40 (m)'),
    ('li i3 1', 'rank'),
    ('li i4 1', 'C of a vector'),
    ('rcall sea_arr_new_s 0:13 1 p5 4 p2 i3 i1 i4', 'ps is p5 (bind, rule 2)'),
    ('la p6 d2', 'line 14, the block of step 4: bind .j1 = cs (rule 7 into its register)'),
    ('retain p6', 'rule 15 (a): a borrowed value stored into a local'),
    ('mov p7 p5', 'bind .j2 = lv ps (rule 2)'),
    ('retain p7', 'rule 15 (a)'),
    ('rcall sea_json_open 0:14 0 1 p6', 'jopen (lv .j1): JSON_OPEN, the path borrowed'),
    ('rcall sea_json_arr 0:14 0 0', 'jarr: JSON_ARR'),
    ('mov p8 p7', "L4's bind H = lv .j2: rule 30 (1), a borrowed vector held"),
    ('retain p8', ''),
    ('ldi i9 p8 - 0 16', 'tmp N = ext(H, 0)'),
    ('li i10 0', 'tmp Z'),
    ('icmp gt i11 i9 i10', ''),
    ('if 1 i11', ''),
    ('ldp p12 p8 - 0 40', 'tmp D = data(H)'),
    ('li i13 1', 'tmp O'),
    ('isub i14 i9 i13', 'tmp L'),
    ('loop 2 i15 i10 i14 i13', 'hloop K'),
    ('li i16 48', 'tmp .j3 = eld P P 48 0: the element address (R18, rule 30 (2))'),
    ('imul i17 i15 i16', ''),
    ('padd p18 p12 i17', '.j3 is p18 (T1)'),
    ('rcall sea_json_obj 0:14 0 0', 'jobj'),
    ('la p19 d3', 'jkey x: la of a new str record (rule 7)'),
    ('rcall sea_json_key 0:14 0 1 p19', ''),
    ('ldf f20 p18 - 0 0', 'jval (fld .j3 0): an f64 field (rule 27 (e))'),
    ('rcall sea_json_f64 0:14 0 1 f20', 'JSON_F64'),
    ('la p21 d4', 'jkey n'),
    ('rcall sea_json_key 0:14 0 1 p21', ''),
    ('ldi i22 p18 - 0 8', 'jval (fld .j3 1): i64 at 8'),
    ('rcall sea_json_i64 0:14 0 1 i22', 'JSON_I64'),
    ('la p23 d5', 'jkey ok'),
    ('rcall sea_json_key 0:14 0 1 p23', ''),
    ('ldb i24 p18 - 0 16', 'jval (fld .j3 2): bool at 16'),
    ('rcall sea_json_bool 0:14 0 1 i24', 'JSON_BOOL'),
    ('la p25 d6', 'jkey s'),
    ('rcall sea_json_key 0:14 0 1 p25', ''),
    ('ldp p26 p18 - 0 24', 'jval (fld .j3 3): str at 24, borrowed'),
    ('rcall sea_json_str 0:14 0 1 p26', 'JSON_STR'),
    ('la p27 d7', 'jkey v'),
    ('rcall sea_json_key 0:14 0 1 p27', ''),
    ('ldp p28 p18 - 0 32', 'jvec (fld .j3 4): f64[] at 32, borrowed'),
    ('rcall sea_json_vec 0:14 0 1 p28', 'JSON_VEC'),
    ('la p29 d8', 'jkey m'),
    ('rcall sea_json_key 0:14 0 1 p29', ''),
    ('ldp p30 p18 - 0 40', 'jmat (fld .j3 5): f64[,] at 40, borrowed'),
    ('rcall sea_json_mat 0:14 0 1 p30', 'JSON_MAT'),
    ('rcall sea_json_end 0:14 0 0', 'jend of the object'),
    ('endloop 2', ''),
    ('endif 1', ''),
    ('release p8', "the end of L4's block: H (rule 16 (a), (f))"),
    ('rcall sea_json_end 0:14 0 0', 'jend of the array'),
    ('rcall sea_json_close 0:14 0 0', 'jclose: JSON_CLOSE'),
    ('release p7', 'the end of the block: .j2, then .j1 (rule 16 (a), reverse declaration order)'),
    ('release p6', ''),
    ('sa p31 s1', 'line 15, rule 8'),
    ('la p32 d9', ''),
    ('rcall sea_printf 0:15 0 2 p32 p31', ''),
    ('release p5', 'the end of .main: ps'),
    ('ret 0', ''),
    ('endfunc', ''),
    ('slay d1 48 3', ''),
    ('soff 24', ''),
    ('soff 32', ''),
    ('soff 40', ''),
    ('str d2 ps.json', ''),
    ('str d3 x', ''),
    ('str d4 n', ''),
    ('str d5 ok', ''),
    ('str d6 s', ''),
    ('str d7 v', ''),
    ('str d8 m', ''),
    ('fmt d9 1', ''),
    ('ftext done%0A', ''),
]

MAT_LIR1 = [
    ('func .main main 0:1:1 0 0', ''),
    ('slot s1 8 8', ''),
    ('li i1 0', 'line 9, L9 (d): anew P Q[,] 1 2 (ci 0) (ci 0), arrnewz of struct elements'),
    ('li i2 0', ''),
    ('la p3 d1', 'the slay of Q: size 16, its str at 8'),
    ('li i4 2', 'rank'),
    ('rcall sea_arr_new_s 0:9 1 p5 4 p3 i4 i1 i2', 'qm is p5'),
    ('la p6 d2', 'line 10: bind .j1 = cs'),
    ('retain p6', ''),
    ('mov p7 p5', 'bind .j2 = lv qm'),
    ('retain p7', ''),
    ('rcall sea_json_open 0:10 0 1 p6', 'jopen'),
    ('ldi i8 p7 - 0 16', 'the guard: rule 3 for ||; ext(.j2, 0) (L3 of rows)'),
    ('li i9 0', ''),
    ('icmp eq i10 i8 i9', 'a with destination R (i10)'),
    ('ifz 1 i10', ''),
    ('ldi i11 p7 - 0 24', 'ext(.j2, 1) (L3 of cols)'),
    ('li i12 0', ''),
    ('icmp eq i10 i11 i12', 'b with destination R'),
    ('endif 1', ''),
    ('if 2 i10', 'rule 4: if with else'),
    ('rcall sea_json_arr 0:10 0 0', 'the empty matrix: jarr, jend'),
    ('rcall sea_json_end 0:10 0 0', ''),
    ('else 2', ''),
    ('rcall sea_json_arr 0:10 0 0', 'jarr'),
    ('li i13 0', 'forr R (rule 4): lo'),
    ('ldi i14 p7 - 0 16', 'hi: ext(.j2, 0)'),
    ('li i15 1', 'no step: li 1'),
    ('rcount i16 i17 i13 i14 i15 0 0:10', ''),
    ('if 3 i17', ''),
    ('loop 4 i18 i13 i16 i15', 'R (.j4) is i18'),
    ('rcall sea_json_arr 0:10 0 0', 'jarr of the row'),
    ('li i19 0', 'forr C: lo'),
    ('ldi i20 p7 - 0 24', 'hi: ext(.j2, 1)'),
    ('li i21 1', ''),
    ('rcount i22 i23 i19 i20 i21 0 0:10', ''),
    ('if 5 i23', ''),
    ('loop 6 i24 i19 i22 i21', 'C (.j3) is i24'),
    ('rcall sea_json_obj 0:10 0 0', 'jobj'),
    ('la p25 d3', 'jkey a'),
    ('rcall sea_json_key 0:10 0 1 p25', ''),
    ('ldi i26 p7 - 0 16', 'jval (fld (idx .j2 R C) 0): rule 18, ext and check of each dimension'),
    ('chkb i18 i26 0 0:10', ''),
    ('ldi i27 p7 - 0 24', ''),
    ('chkb i24 i27 1 0:10', ''),
    ('ldp p28 p7 - 0 40', 'data'),
    ('imul i29 i24 i26', 'the linear index'),
    ('iadd i30 i18 i29', ''),
    ('ldf f31 p28 i30 16 0', 'one load: scale the struct size 16, a at 0'),
    ('rcall sea_json_f64 0:10 0 1 f31', ''),
    ('la p32 d4', 'jkey b'),
    ('rcall sea_json_key 0:10 0 1 p32', ''),
    ('ldi i33 p7 - 0 16', 'jval (fld (idx .j2 R C) 1): the idx read again, its own checks'),
    ('chkb i18 i33 0 0:10', ''),
    ('ldi i34 p7 - 0 24', ''),
    ('chkb i24 i34 1 0:10', ''),
    ('ldp p35 p7 - 0 40', ''),
    ('imul i36 i24 i33', ''),
    ('iadd i37 i18 i36', ''),
    ('ldp p38 p35 i37 16 8', 'b at 8, borrowed'),
    ('rcall sea_json_str 0:10 0 1 p38', ''),
    ('rcall sea_json_end 0:10 0 0', 'jend of the object'),
    ('endloop 6', ''),
    ('endif 5', ''),
    ('rcall sea_json_end 0:10 0 0', 'jend of the row'),
    ('endloop 4', ''),
    ('endif 3', ''),
    ('rcall sea_json_end 0:10 0 0', 'jend of the matrix'),
    ('endif 2', ''),
    ('rcall sea_json_close 0:10 0 0', 'jclose'),
    ('release p7', '.j2, .j1'),
    ('release p6', ''),
    ('sa p39 s1', 'line 11'),
    ('la p40 d5', ''),
    ('rcall sea_printf 0:11 0 2 p40 p39', ''),
    ('release p5', 'qm'),
    ('ret 0', ''),
    ('endfunc', ''),
    ('slay d1 16 1', ''),
    ('soff 8', ''),
    ('str d2 qm.json', ''),
    ('str d3 a', ''),
    ('str d4 b', ''),
    ('fmt d5 1', ''),
    ('ftext done%0A', ''),
]

OUT = 'done\n'          # LANGUAGE.md 11.1: printf("done\n")


def main():
    n = 0
    for name in ('json6_struct', 'json6_vecstruct', 'json6_matstruct'):
        src = SEA[name]
        ast, res, hir1 = (dump(name, AST[name]), dump(name, RES[name]), dump(name, HIR1[name]))
        for t in (ast, res, hir1):
            check_positions(name, src, t)
        hir = dump(name, expand(hir1))
        hirl = dump(name, sealoop(hir))
        check_positions(name, src, hir)
        check_positions(name, src, hirl)
        if name == 'json6_matstruct':
            assert MAT_BLOCK.strip('\n') in hir, 'the model agrees with the hand-written block'
        files = [('sea', src), ('ast', ast), ('res', res), ('hir1', hir1), ('hir', hir),
                 ('hirl', hirl), ('out', OUT)]
        if name == 'json6_vecstruct':
            files.append(('lir1', dump(name, '\n'.join(ln for ln, _ in VEC_LIR1))))
        if name == 'json6_matstruct':
            files.append(('lir1', dump(name, '\n'.join(ln for ln, _ in MAT_LIR1))))
        for x, text in files:
            write(name + '.' + x, text)
            n += 1
    print('dump6d_cases: %d goldens %s' % (n, 'checked' if CHECK else 'written'))


if __name__ == '__main__':
    main()
