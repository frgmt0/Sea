"""Sub-phase 6b dump goldens, package T2 (DESIGN.md 6.2 "Phase-6 tests": "Goldens that inlining
changes" (1) and (2), the T2 items of "Existing tests that phase 6 changes" and the T2 part of
"6b, calls"; 2.11.3 the 8.6 class, 2.11.4 L20, 2.11.5 R31 and R32; Decision 90, lead decisions
L-cf, L-cg, L-ch, L-ci, L-cj, L-cp, L-ct).

Run with `timeout 120 uv run --no-project python tests/vectors/dump6_cases.py [--out DIR]
[--check]`. It writes in tests/passes/ (or DIR); with --check it writes nothing and only checks that
every file it owns is what it would write.

Part 1, the re-derivation of DESIGN 6.2 (2): every `.res`, `.hir1` and `.hir` golden of a program
with a function that LANGUAGE.md 8.6 (b) or (c) covers. CLASS below is the classification of every
ordinary `fn` item of every dump test that has a `fn` item, done by hand on the source by 2.11.3's
rules: (b) exactly one `call` node of the whole stream names it (every function of the file,
reachable or not, its own body included, L-ch); (c) it lies on no cycle of the call graph (L-cj),
its body holds no `while` and no `for`, and it has at most SEA_LIM_INLINE_STMTS statements counted
one per Appendix A `statement` (L-ci). The class is el 2 in `rfn` and the kind `inl` in the HIR
`fn` record; nothing else of those files changes (3.4.1, 3.5.4: no other field depends on it). The
script applies exactly that edit to the committed golden, and checks that the golden differs from
the edited one in nothing else (so it is idempotent), and re-derives the class from the `.res` tree
by an independent count (classify_res) that must agree with CLASS. It also re-derives
res_err_default.res (6.2 "Existing tests that phase 6 changes", 6b, T2).

Part 2, res6_default and res6_class (.sea .ast .res): the .ast by hand (3.4), the .res by the
oracle res_gen.py with the 6b edits (res_gen6) and the 8.6 class, checked against CLASS and, for
res6_default, against a hand-written .res.

Part 3, inl6_* (6.2 "6b, calls"): inl6_count50/51 (the 50/51-statement limit of 8.6 (c), seen in
the .hirl), inl6_basic (el 2, kind inl, L20, R27, the dropped and renumbered functions), inl6_ref
(R31), inl6_agg (R32), inl6_seq_named (the seq of .t temporaries, L-cp, as an L6 mask, R11). The
HIR files by hand from 3.5.4-3.5.5, the .hirl by the L20 model of part 4b or by hand from 3.5.9's
templates, the .lir1 by hand instruction by instruction (each derivation beside its text), the
.out from LANGUAGE.md.

Part 4, Decision 90's 21 lowering dump tests: 4a the twelve call-boundary tests (a `while false
{}` loop made the first statement of each function 8.6 would inline, on its header line; every
golden re-derived), 4b the nine tests whose function is inlined (.hirl and .lir1 by the L20 model:
the callee's own pre-6b dumps, as committed at BASE, spliced into each call site by L20 and rule
37 with R26-R29, then renumbered by 3.5.9 "Locals"/"Types" and 3.6.1-3.6.4).

Never derived by running a pass: the 6b passes are written concurrently. The committed (pre-6b)
passes serve only as cross-checks where 6b does not change them (pass 1 for every .ast; sealower's
4h lowering of iblk/iret for the .lir1 of part 4b and inl6_basic; sealoop for inl6_seq_named).
"""

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
SRC_PASSES = os.path.join(os.path.dirname(HERE), 'passes')
PASSES = SRC_PASSES
if '--out' in sys.argv:
    PASSES = os.path.abspath(sys.argv[sys.argv.index('--out') + 1])
CHECK = '--check' in sys.argv


def equiv(fname, name):
    """The value of `.equiv NAME, v` in include/FNAME (the contract files, never a copy)."""
    with open(os.path.join(ROOT, 'include', fname)) as fh:
        for ln in fh:
            m = re.match(r'^\.equiv\s+(\w+),\s*(-?[0-9]+)', ln)
            if m and m.group(1) == name:
                return int(m.group(2))
    raise AssertionError(('no .equiv', fname, name))


SEA_LIM_INLINE_STMTS = equiv('limits.inc', 'SEA_LIM_INLINE_STMTS')
assert SEA_LIM_INLINE_STMTS == 50


def load_formats():
    """{set letter: {op: [field specs]}} and {op: pops expression} from include/passes.txt."""
    recs, pops = {}, {}
    with open(os.path.join(ROOT, 'include', 'passes.txt')) as fh:
        for ln in fh:
            p = ln.split()
            if len(p) >= 5 and p[0] == 'rec':
                recs.setdefault(p[1], {})[p[3]] = p[5:]
                pops[(p[1][0], p[3])] = p[4]
    return recs, pops


FMT, POPS = load_formats()


def fields_of(st, rec):
    """The named fields of a record of format set st ('A', 'H', 'L'), the counted ones as lists."""
    spec = None
    for s in FMT:
        if s[0] == st and rec[0] in FMT[s]:
            spec = FMT[s][rec[0]]
    assert spec is not None, ('no format', st, rec)
    d, k = {}, 1
    for f in spec:
        nm, kind = f.split(':', 1)
        if '*' in kind:
            cnt = int(d[kind.split('*')[1]])
            d[nm] = rec[k:k + cnt]
            k += cnt
        else:
            d[nm] = rec[k]
            k += 1
    assert k == len(rec), ('field count', rec)
    return d


def npops(st, rec, d):
    e = POPS[(st, rec[0])]
    env = {k: int(v) for k, v in d.items() if isinstance(v, str) and re.match(r'^-?[0-9]+$', v)}
    return int(eval(e, {}, env))


def read(path):
    with open(path) as fh:
        return fh.read()


def write(name, text):
    """Write tests/passes/NAME (or check it with --check)."""
    path = os.path.join(PASSES, name)
    if CHECK:
        assert read(os.path.join(SRC_PASSES, name)) == text, ('differs', name)
        return
    with open(path, 'w') as fh:
        fh.write(text)


# ================================================================ part 1: the 8.6 class (6.2 (2))
# test -> [(function, el, clause)], every ordinary fn item of the program's file in item order.
# el: 0 an ordinary function, 1 elemental (8.6 (a), 6c), 2 inlined by 8.6 (b) or (c). The counts
# are made on the source as written: "sites" the call nodes naming the function anywhere in the
# file, "stmts" the 2.11.3 count of its body. A test whose source Decision 90 changes (the twelve
# call-boundary tests, part 4) is classified on its new source.
CLASS = {
    # tests with a .res, .hir1 or .hir golden
    'arr_fixed': [('mk', 0, '2 sites, loop')],
    'arr_rule16': [('f', 0, '2 sites, loop')],
    'arr_rule18': [('g', 0, '2 sites, loop')],
    'arr_rule19': [('mk', 0, '2 sites, loop')],
    'arr_rule20': [('pick', 0, '2 sites, loop')],
    'arr_rule21': [('two', 0, '2 sites, loop')],
    'arr_rule22': [('twice', 0, '2 sites, loop')],
    'arr_rule25': [('hist', 0, '2 sites, loop')],
    'arr_rule28': [('flat_at', 0, '2 sites, loop')],
    'arr_rule30': [('walk', 0, '2 sites, loop')],
    'arr_rule31': [('mkv', 0, '2 sites, loop'), ('f', 0, '2 sites, loop')],
    'arr_rule36': [('dist', 0, '2 sites, loop')],
    'arr_tasg_l12': [('two', 0, '2 sites, loop')],
    'fn_multi': [('sums', 0, '3 sites, loop'), ('again', 0, '2 sites, recursive (calls itself)')],
    'fn_reach': [('unused', 2, '(c) 0 sites, 1 stmt'), ('leaf', 2, '(b) 1 site (in mid)'),
                 ('mid', 2, '(c) 2 sites, 1 stmt'), ('dead', 2, '(c) 0 sites, 1 stmt')],
    'fn_ref': [('bump', 0, '2 sites, loop'), ('bump2', 0, '2 sites, loop')],
    'fn_ref_order': [('g', 0, '5 sites, loop'), ('f', 0, '2 sites, loop')],
    'lib_rule23': [('total', 0, '2 sites, loop (Decision 90)')],
    'lib_rule24': [('top', 0, '2 sites, loop (Decision 90)')],
    'lib_sum_dim0': [('colsum', 2, '(c) 2 sites, 2 stmts')],
    'lib_sum_dim1': [('rowsum', 2, '(c) 2 sites, 2 stmts')],
    'lib_variance': [('spread', 2, '(c) 2 sites, 3 stmts')],
    'loop_ext': [('shape', 0, '2 sites, loop')],
    'loop_fill': [('grow', 0, '2 sites, loop'), ('count', 0, '2 sites, loop')],
    'loop_fore_exits': [('where_is', 0, '2 sites, loop'), ('sumto', 0, '2 sites, loop'),
                        ('pairs', 0, '2 sites, loop')],
    'lx': [('tri', 0, '2 sites, loop')],
    'match_l16': [('tag', 2, '(c) 2 sites, 1 stmt'), ('scan', 0, '2 sites, loop')],
    'op_shortcircuit': [('pick', 0, '2 sites, loop')],
    'res_arr_types': [('f', 2, '(b) 1 site (a for loop does not matter for (b))')],
    'res_err_array': [('f', 2, '(c) 0 sites, 1 stmt')],
    'res_err_default': [('f', 2, '(c) 0 sites, 1 stmt')],
    'res_err_dim': [('f', 2, '(c) 0 sites, 1 stmt')],
    'res_err_first_pos': [('f', 2, '(c) 0 sites, 1 stmt (the second f is not entered)')],
    'res_err_handle': [('f', 2, '(c) 0 sites, 1 stmt')],
    'res_err_param_redef': [('g', 2, '(c) 0 sites, 1 stmt')],
    'res_err_param_shadow': [('f', 2, '(c) 0 sites, 1 stmt')],
    'res_err_predeclared': [('sqrt', 2, '(b) 1 site (resolved to the entered item)')],
    'res_err_str_param': [('f', 2, '(c) 0 sites, 1 stmt')],
    'res_err_str_result': [('f', 2, '(c) 0 sites, 1 stmt')],
    'res_err_unknown_struct': [('f', 2, '(c) 0 sites, 1 stmt')],
    'res_names': [('f', 2, '(b) 1 site')],
    'res_noval_calltype': [('f', 2, '(b) 1 site (in a const)')],
    'res_noval_shortcircuit': [('f', 2, '(b) 1 site (in a const)')],
    'res_noval_userpow': [('pow', 2, '(b) 1 site (in a const)')],
    'res_powk_skip': [('g', 2, '(b) 1 site (the second g is not entered)'),
                      ('h', 2, '(c) 0 sites, 2 stmts')],
    'res_rt': [('first', 2, '(b) 1 site')],
    'res_rtst': [('mk', 2, '(c) 0 sites, 1 stmt')],
    'rs': [('split', 2, '(b) 1 site')],
    'sel_ref_store': [('setto', 0, '2 sites, loop')],
    'stmt_loops': [('walk', 0, '2 sites, loop')],
    'stmt_tasg': [('two', 0, '3 sites, loop'), ('bump', 0, '2 sites, loop'),
                  ('put', 0, '2 sites, loop')],
    'str_ew': [('ew', 2, '(c) 2 sites, 3 stmts')],
    'str_fill_flat': [('tile', 2, '(c) 2 sites, 3 stmts')],
    'str_fixed_self': [('show', 2, '(c) 2 sites, 1 stmt')],
    'str_l12': [('two', 0, '2 sites, loop (Decision 90)'), ('upd', 0, '2 sites, loop (Decision 90)')],
    'str_l17': [('put', 2, '(c) 2 sites, 4 stmts')],
    'str_ref_ln': [('f', 0, '2 sites, loop (Decision 90)')],
    'str_rule15': [('show', 0, '2 sites, loop (Decision 90)')],
    'str_rule32': [('less', 0, '3 sites, loop (Decision 90)')],
    'str_rule33': [('pick', 0, '3 sites, loop (Decision 90)'),
                   ('drive', 0, '2 sites, loop (Decision 90)')],
    'struct_l6_field': [('p', 0, '2 sites, loop (Decision 90)'), ('q', 0, '2 sites, loop (Decision 90)')],
    'struct_l12': [('two', 0, '2 sites, loop (Decision 90)'), ('mk', 0, '2 sites, loop (Decision 90)')],
    'struct_l17': [('edit', 2, '(c) 2 sites, 12 stmts')],
    'struct_l17_path': [('upd', 0, '2 sites, loop (Decision 90)')],
    'struct_rule18': [('nomOf', 0, '2 sites, loop (Decision 90)')],
    'struct_rule29': [('show', 0, '2 sites, loop (Decision 90)')],
    'type_cvt': [('widen', 2, '(b) 1 site'), ('scale', 2, '(b) 1 site')],
    'type_untyped': [('h', 2, '(b) 1 site')],
    'type_var_rule': [('half', 2, '(b) 1 site')],
    # the opt5_* tests (.lir1 .lir2 .lir only): every function has a loop and two or more sites
    # (DESIGN 6.2, 5c: written so that 8.6 requires no inlining); checked by classify_res on the
    # source's tree in --check-build mode only, since they have no .res golden
}
# tests with a fn item and only an .ast golden (no class-dependent file): ev, ex, lex_newline,
# stmt_grammar_full; and the res_err_elemental (el 1, 6c) and res_err_param_shadow cases above.

# the twelve call-boundary tests of Decision 90 (part 4): their goldens are rewritten as a whole
BOUNDARY = ['lib_rule23', 'lib_rule24', 'str_rule15', 'str_rule32', 'str_rule33', 'struct_rule18',
            'struct_rule29', 'str_ref_ln', 'struct_l17_path', 'str_l12', 'struct_l12',
            'struct_l6_field']
# the nine tests whose function is inlined (part 4): .ast unchanged, .res .hir1 .hir by part 1,
# .hirl .lir1 re-derived with L20's form
INLINED = ['lib_sum_dim0', 'lib_sum_dim1', 'lib_variance', 'match_l16', 'str_ew', 'str_fill_flat',
           'str_fixed_self', 'str_l17', 'struct_l17']


def parse_tree(st, text):
    """The post-order records of a dump (3.3) as nodes {'rec', 'kids'}; returns the item list of
    `prog` for sea.ast / sea.res, or the list of root nodes."""
    stack, prog = [], None
    for ln in text.split('\n'):
        if not ln or ln.startswith('#'):
            continue
        rec = ln.split(' ')
        if rec[0] in ('rerr', 'rtup', 'rtvec', 'rtmat', 'rtfvec', 'rtfmat', 'rtst', 'rtfd'):
            continue
        d = fields_of(st, rec)
        k = npops(st, rec, d)
        kids = stack[len(stack) - k:] if k else []
        if k:
            del stack[len(stack) - k:]
        node = {'rec': rec, 'd': d, 'kids': kids}
        if rec[0] == 'prog':
            prog = kids
        else:
            stack.append(node)
    return prog if prog is not None else stack


def walk(n, parent=None):
    yield n, parent
    for c in n['kids']:
        yield from walk(c, n)


STMT_KINDS = ('let', 'var', 'asg', 'tasg', 'cstmt', 'while', 'for', 'rfor', 'match', 'break',
              'continue', 'return')


def stmt_count(body):
    """2.11.3 (c): one per Appendix A statement of a function's body block (L-ci)."""
    cnt = 0
    for n, p in walk(body):
        op = n['rec'][0]
        if op in STMT_KINDS:
            cnt += 1
        elif op == 'if':
            # an `if` that is the else child of an `if` (an `else if`) counts 0
            if not (p is not None and p['rec'][0] == 'if' and len(p['kids']) == 3
                    and p['kids'][2] is n):
                cnt += 1
        elif op == 'block' and p is not None and p['rec'][0] == 'block':
            cnt += 1
    return cnt


def classify_res(text):
    """[(name, el)] of the rfn records of a sea.res by 2.11.3, counted on its tree: a call names
    function F when its callee child is `rname ... fn F`."""
    items = parse_tree('A', text)
    fns = [it for it in items if it['rec'][0] == 'rfn']
    fids = {it['d']['fid']: it for it in fns}
    sites = {f: 0 for f in fids}
    edges = {f: set() for f in fids}
    edges['.main'] = set()
    for it in items:
        owner = it['d']['fid'] if it['rec'][0] == 'rfn' else '.main'
        for n, _ in walk(it):
            if n['rec'][0] == 'call' and n['kids'][0]['rec'][0] == 'rname':
                c = n['kids'][0]['d']
                if c['k'] == 'fn' and c['ref'] in sites:
                    sites[c['ref']] += 1
                    edges[owner].add(c['ref'])

    def on_cycle(f):
        seen, todo = set(), list(edges[f])
        while todo:
            x = todo.pop()
            if x == f:
                return True
            if x not in seen:
                seen.add(x)
                todo.extend(edges[x])
        return False

    out = []
    for f, it in fids.items():
        body = it['kids'][-1]
        loop = any(n['rec'][0] in ('while', 'for', 'rfor') for n, _ in walk(body))
        if it['d']['el'] == '1':
            el = 1
        elif sites[f] == 1 or (not on_cycle(f) and not loop
                               and stmt_count(body) <= SEA_LIM_INLINE_STMTS):
            el = 2
        else:
            el = 0
        out.append((it['d']['name'], el))
    return out


def reclass(text, kind, table):
    """Set rfn's el (kind 'res') or the HIR fn kind (kind 'hir1', 'hir') of every function of
    table to its class; nothing else changes."""
    want = {nm: el for nm, el, _ in table}
    out, seen = [], set()
    for ln in text.split('\n'):
        p = ln.split(' ')
        if kind == 'res' and p[0] == 'rfn':
            nm = p[2]
            assert nm in want and p[3] in ('0', '2'), ('rfn', ln)
            p[3] = str(want[nm])
            seen.add(nm)
        elif kind != 'res' and p[0] == 'fn' and p[3] != 'main':
            nm = p[2]
            assert nm in want and p[3] in ('fn', 'inl'), ('fn', ln)
            p[3] = 'inl' if want[nm] == 2 else 'fn'
            seen.add(nm)
        out.append(' '.join(p))
    return '\n'.join(out), seen


def part1():
    n = 0
    for test, table in sorted(CLASS.items()):
        if test in BOUNDARY or test.startswith(("res6_", "inl6_")):
            continue                    # rewritten as a whole by part 4
        for kind in ('res', 'hir1', 'hir'):
            src = os.path.join(SRC_PASSES, test + '.' + kind)
            if not os.path.exists(src):
                continue
            text = read(src)
            new, seen = reclass(text, kind, table)
            if kind == 'res':
                assert seen == {nm for nm, _, _ in table}, (test, seen)
                got = classify_res(new)
                assert got == [(nm, el) for nm, el, _ in table], (test, got)
            if test == 'res_err_default' and kind == 'res':
                new = RES_ERR_DEFAULT
                assert classify_res(new) == [('f', 2)]
            write(test + '.' + kind, new)
            n += 1
    return n


# ================================================================ res_err_default (6.2, T2)
# DESIGN 6.2 "Existing tests that phase 6 changes", 6b, T2: a default is no longer `not supported
# yet` (2.11.2's table, 6b), and from 6b a parameter default is a resolved region (3.4.1 as
# amended, Decision 91): its `name K` becomes `rname ... cst 1` (K is the only constant, cid 1,
# entered although it follows the function: 3.4.1 "Entered items"). No other error: K is a
# constant of type i64 and the parameter's type is i64 (seacheck's checks, not seaname's).
# Function f has no call site and one statement: el 2 (8.6 (c)). The .ast is unchanged (the
# header comment keeps its two lines).
RES_ERR_DEFAULT = """#sea 1
#target arm64-macos
#file res_err_default.sea
rtype 0:3:9 i64 s 0 3
rname 0:3:15 K cst 1
param 0:3:6 a 0 1
rtype 0:3:21 i64 s 0 3
rname 0:4:12 a loc 1
return 0:4:5 1
block 0:3:25 1
rfn 0:3:1 f 2 1 1 2 3 3
rint 0:6:11 1 #3FF0000000000000
rcni 0:6:1 K 0 1 1
prog 2
#end
"""
RES_ERR_DEFAULT_SEA = """// res_err_default -- from 6b a default is a resolved region: K resolves to an rname of the
// constant that follows the function (DESIGN.md 3.4.1, Decision 91); no rerr
fn f(a: i64 = K) -> i64 {
    return a
}
const K = 1
"""


# ================================================================ part 2: res6_* (6.2 "6b, calls")
# The .ast: pass 1 is unchanged in 6b (8, row 6b lists no seaparse work): the records of 3.4 for
# the source, written by hand below (each position the token 3.3/3.4 names: a param its name, a
# type its base, a bin its left operand's first token, a call its callee, an asg its target, an
# `if` its keyword, an `else if`'s `if` its keyword, a block its `{`). The .res: res_gen.py (the
# spec oracle of 3.4.1, 3.4.2) with the three edits of 6b (res_gen6): no 259 `default
# arguments` (2.11.2's table), a parameter default resolved like a const item's value with its
# `^` judged for rpowk (3.4.1 as amended by Decision 91), and rfn's el the 8.6 class (2.11.3),
# which must equal CLASS.

def res_gen6():
    """res_gen.py with the 6b edits; each replaced text must occur exactly once."""
    import types
    path = os.path.join(HERE, 'res_gen.py')
    src = read(path)
    edits = [
        ("""            if p.f[3] == '1':
                err(p.pos, 259, ['default arguments'])
""", ''),
        ("""        resolve(it.kids[-1], [psc], Fn(np_))
    nfn = len(powk_sites)
""", """        resolve(it.kids[-1], [psc], Fn(np_))
    for it in fns:
        for p in it.kids[:int(it.f[3])]:
            if p.f[3] == '1':
                resolve(p.kids[1], [], None)  # 6b: a default resolved like a const value
    nfn = len(powk_sites)
"""),
    ]
    for old, new in edits:
        assert src.count(old) == 1, old
        src = src.replace(old, new)
    mod = types.ModuleType('res_gen6')
    mod.__file__ = path
    sys.path.insert(0, HERE)
    exec(compile(src, path, 'exec'), mod.__dict__)
    return mod


def ast_text(name, body):
    return ('#sea 1\n#target arm64-macos\n#file %s.sea\n' % name
            + '\n'.join(ln.strip() for ln in body.strip('\n').split('\n') if ln.strip())
            + '\n#end\n')


def check_ast_positions(name, src, ast):
    """Every positioned record of the .ast names the token 3.4 gives it in the source."""
    sl = src.split('\n')
    tok = {'type': None, 'param': None, 'name': None, 'pname': None, 'int': None,
           'return': 'return', 'block': '{', 'fn': None, 'const': 'const', 'let': 'let',
           'var': 'var', 'while': 'while', 'for': 'for', 'if': 'if', 'true': 'true',
           'false': 'false', 'float': None, 'str': '"', 'narg': None, 'range': None,
           'asg': None, 'bin': None, 'call': None, 'cstmt': None, 'dot': None, 'index': None}
    for ln in ast.split('\n'):
        p = ln.split(' ')
        if not ln or ln.startswith('#') or p[0] == 'prog':
            continue
        f, l, c = (int(x) for x in p[1].split(':'))
        at = sl[l - 1][c - 1:]
        op = p[0]
        if op in ('type',):
            assert at.startswith(p[2]), (name, ln)
        elif op == 'param' and p[3] == '1':
            assert re.match(r'ref ' + re.escape(p[2]) + r'\b', at), (name, ln, at)
        elif op in ('param', 'name', 'pname', 'narg', 'init', 'field', 'slit'):
            assert re.match(re.escape(p[2]) + r'\b', at), (name, ln, at)
        elif op in ('ref', 'struct'):
            assert at.startswith(op + ' '), (name, ln, at)
        elif op == 'int':
            assert re.match(p[2] + r'\b', at), (name, ln)
        elif op == 'float':
            assert re.match(r'[0-9]+\.[0-9]+', at), (name, ln)
        elif op == 'fn':
            assert at.startswith('fn ' if p[3] == '0' else 'elemental fn '), (name, ln)
            assert re.match(r'(elemental )?fn ' + re.escape(p[2]) + r'\(', at), (name, ln)
        elif tok.get(op):
            assert at.startswith(tok[op]), (name, ln, at)
        else:
            # bin, range, asg, call, cstmt, dot, index: an operand, target, base or callee's first token
            assert re.match(r'[A-Za-z0-9(]', at), (name, ln)


RES6_DEFAULT_SEA = """// res6_default -- from 6b a parameter default is a resolved region (DESIGN.md 3.4.1, Decision
// 91): a constant name, the predeclared pi and an operator expression with a ^ (rpowk)
const N = 4
fn f(a: i64, b: i64 = N, c: f64 = pi, d: f64 = 2.0 * pi ^ 2) -> f64 {
    return a + b + c + d
}
printf("%g\\n", f(1))
printf("%g\\n", f(1, d: 0.5))
"""
RES6_DEFAULT_AST = """
int 0:3:11 4
const 0:3:1 N 0
type 0:4:9 i64 s 0
param 0:4:6 a 0 0
type 0:4:17 i64 s 0
name 0:4:23 N
param 0:4:14 b 0 1
type 0:4:29 f64 s 0
name 0:4:35 pi
param 0:4:26 c 0 1
type 0:4:42 f64 s 0
float 0:4:48 #4000000000000000
name 0:4:54 pi
int 0:4:59 2
bin 0:4:54 pow
bin 0:4:48 mul
param 0:4:39 d 0 1
type 0:4:65 f64 s 0
name 0:5:12 a
name 0:5:16 b
bin 0:5:12 add
name 0:5:20 c
bin 0:5:12 add
name 0:5:24 d
bin 0:5:12 add
return 0:5:5 1
block 0:4:69 1
fn 0:4:1 f 0 4 1
name 0:7:1 printf
str 0:7:8 %25g%0A
name 0:7:16 f
int 0:7:18 1
call 0:7:16 1
call 0:7:1 2
cstmt 0:7:1
name 0:8:1 printf
str 0:8:8 %25g%0A
name 0:8:16 f
int 0:8:18 1
float 0:8:24 #3FE0000000000000
narg 0:8:21 d
call 0:8:16 2
call 0:8:1 2
cstmt 0:8:1
prog 4
"""
# The expected res (3.4.1): N is constant 1 (rcni 4); f is function 2 with the types i64 (3) i64
# f64 (4) f64 and result f64; in the defaults N is `rname cst 1`, pi `rname pd 0`, and `pi ^ 2`
# is `rpowk 2` (an integer constant exponent, 3.4.1 "Constant exponents"); no rcn record for a
# default and no rerr; f has two call sites and one statement: el 2 (8.6 (c)).
RES6_DEFAULT_RES = """
rint 0:3:11 4 #4010000000000000
rcni 0:3:1 N 0 1 4
rtype 0:4:9 i64 s 0 3
param 0:4:6 a 0 0
rtype 0:4:17 i64 s 0 3
rname 0:4:23 N cst 1
param 0:4:14 b 0 1
rtype 0:4:29 f64 s 0 4
rname 0:4:35 pi pd 0
param 0:4:26 c 0 1
rtype 0:4:42 f64 s 0 4
float 0:4:48 #4000000000000000
rname 0:4:54 pi pd 0
rint 0:4:59 2 #4000000000000000
rpowk 0:4:54 2
bin 0:4:48 mul
param 0:4:39 d 0 1
rtype 0:4:65 f64 s 0 4
rname 0:5:12 a loc 1
rname 0:5:16 b loc 2
bin 0:5:12 add
rname 0:5:20 c loc 3
bin 0:5:12 add
rname 0:5:24 d loc 4
bin 0:5:12 add
return 0:5:5 1
block 0:4:69 1
rfn 0:4:1 f 2 4 1 2 4 3 3 4 4
rname 0:7:1 printf pd 0
str 0:7:8 %25g%0A
rname 0:7:16 f fn 2
rint 0:7:18 1 #3FF0000000000000
call 0:7:16 1
call 0:7:1 2
cstmt 0:7:1
rname 0:8:1 printf pd 0
str 0:8:8 %25g%0A
rname 0:8:16 f fn 2
rint 0:8:18 1 #3FF0000000000000
float 0:8:24 #3FE0000000000000
narg 0:8:21 d
call 0:8:16 2
call 0:8:1 2
cstmt 0:8:1
prog 4
"""


def s_fn(name, L, n):
    """Source and .ast of a function of 8 + n statements at line L (2.11.3 (c), L-ci): var 1,
    the if ... else if ... else chain 1 (its else-if `if` 0), the three assignments in its
    branches 3, the bare block statement 1 and its assignment 1, n assignments, return 1."""
    src = ['fn %s(k: i64) -> i64 {' % name, '    var s = k', '    if s > 0 {', '        s += 1',
           '    } else if s < 0 {', '        s -= 1', '    } else {', '        s = 1', '    }',
           '    {', '        s += 2', '    }'] + ['    s += 1'] * n + ['    return s', '}']
    a = """type 0:{0}:11 i64 s 0
param 0:{0}:8 k 0 0
type 0:{0}:19 i64 s 0
pname 0:{1}:9 s
name 0:{1}:13 k
var 0:{1}:5 0
name 0:{2}:8 s
int 0:{2}:12 0
bin 0:{2}:8 gt
name 0:{3}:9 s
int 0:{3}:14 1
asg 0:{3}:9 add
block 0:{2}:14 1
name 0:{4}:15 s
int 0:{4}:19 0
bin 0:{4}:15 lt
name 0:{5}:9 s
int 0:{5}:14 1
asg 0:{5}:9 sub
block 0:{4}:21 1
name 0:{7}:9 s
int 0:{7}:13 1
asg 0:{7}:9 set
block 0:{6}:12 1
if 0:{4}:12 1
if 0:{2}:5 1
name 0:{10}:9 s
int 0:{10}:14 2
asg 0:{10}:9 add
block 0:{9}:5 1
""".format(*range(L, L + 11))
    for r in range(L + 12, L + 12 + n):
        a += 'name 0:%d:5 s\nint 0:%d:10 1\nasg 0:%d:5 add\n' % (r, r, r)
    ret = L + 12 + n
    a += 'name 0:%d:12 s\nreturn 0:%d:5 1\nblock 0:%d:23 %d\nfn 0:%d:1 %s 0 1 1\n' % (
        ret, ret, L, n + 4, L, name)
    return src, a


RES6_CLASS_HEAD = """// res6_class -- the 8.6 class in rfn's el (DESIGN.md 2.11.3, 3.4.1; LANGUAGE.md 8.6): sq 1
// (elemental; 259 until 6c), once 2 (one call site, a loop), twice 0 (a loop; two sites, one in
// unreached, which .main never reaches), unreached 2 (no site, one statement), s50 2 and s51 0
// (50 and 51 statements: the if chain 1, the bare block 1), even and odd 0 (a recursive pair)
elemental fn sq(x: f64) -> f64 {
    return x * x
}
fn once(k: i64) -> i64 {
    var s = 0
    for i in 0..k {
        s += i
    }
    return s
}
fn twice(k: i64) -> i64 {
    var s = 0
    while s < k {
        s += 1
    }
    return s
}
fn unreached() -> i64 {
    return twice(1)
}
fn even(n: i64) -> bool {
    if n == 0 {
        return true
    }
    return odd(n - 1)
}
fn odd(n: i64) -> bool {
    if n == 0 {
        return false
    }
    return even(n - 1)
}"""
RES6_CLASS_AST_HEAD = """
type 0:5:20 f64 s 0
param 0:5:17 x 0 0
type 0:5:28 f64 s 0
name 0:6:12 x
name 0:6:16 x
bin 0:6:12 mul
return 0:6:5 1
block 0:5:32 1
fn 0:5:1 sq 1 1 1
type 0:8:12 i64 s 0
param 0:8:9 k 0 0
type 0:8:20 i64 s 0
pname 0:9:9 s
int 0:9:13 0
var 0:9:5 0
int 0:10:14 0
name 0:10:17 k
range 0:10:14 0 0
name 0:11:9 s
name 0:11:14 i
asg 0:11:9 add
block 0:10:19 1
for 0:10:5 i 0:10:9
name 0:13:12 s
return 0:13:5 1
block 0:8:24 3
fn 0:8:1 once 0 1 1
type 0:15:13 i64 s 0
param 0:15:10 k 0 0
type 0:15:21 i64 s 0
pname 0:16:9 s
int 0:16:13 0
var 0:16:5 0
name 0:17:11 s
name 0:17:15 k
bin 0:17:11 lt
name 0:18:9 s
int 0:18:14 1
asg 0:18:9 add
block 0:17:17 1
while 0:17:5
name 0:20:12 s
return 0:20:5 1
block 0:15:25 3
fn 0:15:1 twice 0 1 1
type 0:22:19 i64 s 0
name 0:23:12 twice
int 0:23:18 1
call 0:23:12 1
return 0:23:5 1
block 0:22:23 1
fn 0:22:1 unreached 0 0 1
type 0:25:12 i64 s 0
param 0:25:9 n 0 0
type 0:25:20 bool s 0
name 0:26:8 n
int 0:26:13 0
bin 0:26:8 eq
true 0:27:16
return 0:27:9 1
block 0:26:15 1
if 0:26:5 0
name 0:29:12 odd
name 0:29:16 n
int 0:29:20 1
bin 0:29:16 sub
call 0:29:12 1
return 0:29:5 1
block 0:25:25 2
fn 0:25:1 even 0 1 1
type 0:31:11 i64 s 0
param 0:31:8 n 0 0
type 0:31:19 bool s 0
name 0:32:8 n
int 0:32:13 0
bin 0:32:8 eq
false 0:33:16
return 0:33:9 1
block 0:32:15 1
if 0:32:5 0
name 0:35:12 even
name 0:35:17 n
int 0:35:21 1
bin 0:35:17 sub
call 0:35:12 1
return 0:35:5 1
block 0:31:24 2
fn 0:31:1 odd 0 1 1
"""
RES6_CLASS_MAIN = ["let a = once(3) + twice(2)", "let b = s50(0) + s51(0) + s50(1) + s51(1)",
                   "let c = even(4) && odd(3)", "let d = sq(2.0)"]
RES6_CLASS_AST_MAIN = """
pname 0:{0}:5 a
name 0:{0}:9 once
int 0:{0}:14 3
call 0:{0}:9 1
name 0:{0}:19 twice
int 0:{0}:25 2
call 0:{0}:19 1
bin 0:{0}:9 add
let 0:{0}:1 0
pname 0:{1}:5 b
name 0:{1}:9 s50
int 0:{1}:13 0
call 0:{1}:9 1
name 0:{1}:18 s51
int 0:{1}:22 0
call 0:{1}:18 1
bin 0:{1}:9 add
name 0:{1}:27 s50
int 0:{1}:31 1
call 0:{1}:27 1
bin 0:{1}:9 add
name 0:{1}:36 s51
int 0:{1}:40 1
call 0:{1}:36 1
bin 0:{1}:9 add
let 0:{1}:1 0
pname 0:{2}:5 c
name 0:{2}:9 even
int 0:{2}:14 4
call 0:{2}:9 1
name 0:{2}:20 odd
int 0:{2}:24 3
call 0:{2}:20 1
bin 0:{2}:9 and
let 0:{2}:1 0
pname 0:{3}:5 d
name 0:{3}:9 sq
float 0:{3}:12 #4000000000000000
call 0:{3}:9 1
let 0:{3}:1 0
prog 12
"""


def res6_class():
    src = RES6_CLASS_HEAD.split('\n')
    s50, a50 = s_fn('s50', len(src) + 1, 42)
    src += s50
    s51, a51 = s_fn('s51', len(src) + 1, 43)
    src += s51
    m = len(src) + 1
    src += RES6_CLASS_MAIN
    ast = RES6_CLASS_AST_HEAD + a50 + a51 + RES6_CLASS_AST_MAIN.format(m, m + 1, m + 2, m + 3)
    return '\n'.join(src) + '\n', ast


CLASS['res6_default'] = [('f', 2, '(c) 2 sites, 1 stmt')]
CLASS['res6_class'] = [('sq', 1, '(a) elemental'), ('once', 2, '(b) 1 site, a loop'),
                       ('twice', 0, '2 sites (one in unreached), loop'),
                       ('unreached', 2, '(c) 0 sites, 1 stmt'),
                       ('even', 0, '2 sites, recursive (even-odd)'),
                       ('odd', 0, '2 sites, recursive (even-odd)'),
                       ('s50', 2, '(c) 2 sites, 50 stmts'), ('s51', 0, '2 sites, 51 stmts')]


def gen_res(rg, name, ast):
    """The .res of an .ast text by res_gen6, with rfn's el set to the 8.6 class."""
    path = os.path.join(SCRATCH_DIR, name + '.ast')
    with open(path, 'w') as fh:
        fh.write(ast)
    rg.CONST_POWK_POS.clear()
    head, prog = rg.read_ast(path)
    out = rg.seaname(prog)
    text = '\n'.join(head + out + ['#end']) + '\n'
    got = dict(classify_res(text))
    lines_ = []
    for ln in text.split('\n'):
        p = ln.split(' ')
        if p[0] == 'rfn':
            p[3] = str(got[p[2]])
        lines_.append(' '.join(p))
    text = '\n'.join(lines_)
    assert classify_res(text) == [(nm, el) for nm, el, _ in CLASS[name]], (name, classify_res(text))
    return text


def part2():
    rg = res_gen6()
    # res6_default
    ast = ast_text('res6_default', RES6_DEFAULT_AST)
    check_ast_positions('res6_default', RES6_DEFAULT_SEA, ast)
    res = gen_res(rg, 'res6_default', ast)
    assert res == ast_text('res6_default', RES6_DEFAULT_RES), res
    write('res6_default.sea', RES6_DEFAULT_SEA)
    write('res6_default.ast', ast)
    write('res6_default.res', res)
    # res6_class
    src, a = res6_class()
    ast = ast_text('res6_class', a)
    check_ast_positions('res6_class', src, ast)
    res = gen_res(rg, 'res6_class', ast)
    assert res.split('\n')[3] == 'rerr 0:5:1 259 1 elemental%20functions', res.split('\n')[3]
    write('res6_class.sea', src)
    write('res6_class.ast', ast)
    write('res6_class.res', res)
    return 6


# ================================================================ part 4a: the twelve call-boundary tests
# DESIGN 6.2 "Goldens that inlining changes" (1), Decision 90: the subject of each of these tests
# is a call boundary (a 3.6.6 rule's verbatim example inside a function, a `ref` parameter root, a
# multiple-result call bound by L12, calls inside a selection), so each function that 8.6 (b) or
# (c) would inline is made non-inlinable: a `while false` loop with an empty body as its first
# statement. Every such function already has two or more call sites (CLASS), so no second call
# site is added and every .out is unchanged. The loop is written on the function's header line,
# right after its `{` (` while false {}`; Appendix A: `block = "{" nl [statement {sep
# statement}] ...`, nl may be empty), so no line of the source moves and every other record of
# every golden keeps its position. Derivation of each golden, by hand from the rules:
# * .ast and .res (3.4, 3.4.1): before the first statement of the body block, `false P2`, `block
#   P3 0` (the empty body), `while P1` (post-order, 3.3); the body block's n grows by 1. P1 is the
#   `while` keyword, P2 the `false`, P3 the loop's `{`. Nothing to resolve (no name, no int).
# * .hir1, .hir, .hirl (3.5.5): `cb P2 2 0` (the bool constant false, type 2), `block P3 0`,
#   `while P1` at the same place; no local (the fn record's nl unchanged); pass 2b folds nothing
#   here (3.5.7 step 2 folds no comparison or logic) and keeps the function (reachable);
#   sealoop writes a function without its rewritten constructs unchanged (3.5.9 "Unchanged
#   functions": a scalar while is kept).
# * .lir1 (3.6.6 rule 4, rule 1): `while c body` is `do B`, c, `ifz B2 c`, `exit B`, `endif B2`,
#   body, `enddo B`; the cb is `li` into a new register R; the empty block emits nothing (rule 6,
#   rule 16: no bound local). As the function's first statement these six records stand right
#   after the func and slot records (3.6.3). Then 3.6.1 and 3.6.4: registers are numbered in order
#   of first appearance (the parameters first, in the func record), so R is n+1 for n parameters
#   and every later register moves up by 1; blocks are numbered from 1 in opening order, so the
#   loop's blocks are 1 and 2 and every later block moves up by 2. Slots and data labels do not
#   change (the loop has neither; data labels are numbered in order of first reference, and the
#   loop references none).
# The edit is applied to the committed golden once: a file that already holds the loop is only
# re-verified.

B4A_FUNS = {
    'lib_rule23': ['total'], 'lib_rule24': ['top'], 'str_rule15': ['show'], 'str_rule32': ['less'],
    'str_rule33': ['pick', 'drive'], 'struct_rule18': ['nomOf'], 'struct_rule29': ['show'],
    'str_ref_ln': ['f'], 'struct_l17_path': ['upd'], 'str_l12': ['two', 'upd'],
    'struct_l12': ['two', 'mk'], 'struct_l6_field': ['p', 'q'],
}
B4A_LOOP = ' while false {}'
B4A_REG = re.compile(r'^[ifpxym][0-9]+$')
B4A_REGKINDS = ('reg', 'ri', 'rf', 'rm', 'rp', 'rx', 'ry')


def b4a_sea(text, funs):
    """The edited source, and {fn name: (line, col of while, col of false, col of its {)}."""
    out, where = [], {}
    for k, ln in enumerate(text.split('\n')):
        m = re.match(r'^fn (\w+)\(', ln)
        if m and m.group(1) in funs:
            if not ln.endswith(B4A_LOOP):
                assert ln.endswith('{'), ln
                ln = ln + B4A_LOOP
            c = len(ln) - len(B4A_LOOP)          # the column of the body's `{`
            where[m.group(1)] = (k + 1, c + 2, c + 8, c + 14)
        out.append(ln)
    assert set(where) == set(funs), (funs, where)
    return '\n'.join(out), where


def b4a_span_start(st, recs, b):
    """The index of the first record of the subtree whose root is recs[b] (post-order, 3.3)."""
    need, j = 1, b
    while True:
        r = recs[j].split(' ')
        need += npops(st, r, fields_of(st, r)) - 1
        if need == 0:
            return j
        j -= 1


def b4a_tree(text, kind, where):
    """.ast/.res (kind 'A') or HIR (kind 'H'): insert the loop before the body's first statement."""
    recs = text.split('\n')
    for name, (ln, cw, cf, cb) in where.items():
        P1, P2, P3 = ('0:%d:%d' % (ln, c) for c in (cw, cf, cb))
        if kind == 'A':
            fi = [i for i, r in enumerate(recs) if r.split(' ')[0] in ('fn', 'rfn')
                  and r.split(' ')[2] == name and r.split(' ')[1] == '0:%d:1' % ln]
            assert len(fi) == 1, (name, fi)
            b = fi[0] - 1
            new = ['false ' + P2, 'block %s 0' % P3, 'while ' + P1]
        else:
            fi = [i for i, r in enumerate(recs) if r.startswith('fn ') and r.split(' ')[2] == name]
            assert len(fi) == 1, (name, fi)
            b = next(i for i in range(fi[0], len(recs)) if recs[i] == 'end') - 1
            new = ['cb %s 2 0' % P2, 'block %s 0' % P3, 'while ' + P1]
        blk = recs[b].split(' ')
        assert blk[0] == 'block' and blk[1] == '0:%d:%d' % (ln, cw - 2), (name, recs[b])
        s = b4a_span_start(kind, recs, b)
        if recs[s:s + 3] == new:
            continue                        # already applied (the block's n counts the loop)
        recs[s:s] = new
        blk[2] = str(int(blk[2]) + 1)
        recs[b + 3] = ' '.join(blk)
    return '\n'.join(recs)


def b4a_lir(text, funs):
    recs = text.split('\n')
    for name in funs:
        f = [i for i, r in enumerate(recs) if r.startswith('func %s ' % name)]
        assert len(f) == 1, (name, f)
        f = f[0]
        np_ = int(recs[f].split(' ')[4])
        s = f + 1
        while recs[s].startswith('slot '):
            s += 1
        r = 'i%d' % (np_ + 1)
        new = ['do 1', 'li %s 0' % r, 'ifz 2 %s' % r, 'exit 1', 'endif 2', 'enddo 1']
        if recs[s:s + 6] == new:
            continue
        e = next(i for i in range(f, len(recs)) if recs[i] == 'endfunc')
        for i in range(s, e):
            p = recs[i].split(' ')
            for nm, kind, k in b4a_layout(p):
                if kind == 'blk':
                    p[k] = str(int(p[k]) + 2)
                elif kind in B4A_REGKINDS and B4A_REG.match(p[k]):
                    n = int(p[k][1:])
                    if n > np_:                         # a parameter keeps its number
                        p[k] = '%s%d' % (p[k][0], n + 1)
                elif kind in B4A_REGKINDS and p[k] != '-':
                    raise AssertionError(('register field', recs[i]))
            recs[i] = ' '.join(p)
        recs[s:s] = new
    return '\n'.join(recs)


def b4a_layout(rec):
    """[(field, kind, token index)] of a LIR record, the counted fields expanded (passes.txt L)."""
    spec = FMT['L'][rec[0]] if rec[0] in FMT['L'] else FMT['LF'][rec[0]]
    out, vals, k = [], {}, 1
    for f in spec:
        nm, kind = f.split(':', 1)
        if '*' in kind:
            kind, cnt = kind.split('*')
            for _ in range(int(vals[cnt])):
                out.append((nm, kind.rstrip('?'), k))
                k += 1
            continue
        out.append((nm, kind.rstrip('?'), k))
        vals[nm] = rec[k]
        k += 1
    assert k == len(rec), ('field count', rec)
    return out


def part4a():
    n = 0
    for test in BOUNDARY:
        funs = B4A_FUNS[test]
        sea, where = b4a_sea(read(os.path.join(SRC_PASSES, test + '.sea')), funs)
        write(test + '.sea', sea)
        n += 1
        for kind in ('ast', 'res', 'hir1', 'hir', 'hirl', 'lir1'):
            path = os.path.join(SRC_PASSES, test + '.' + kind)
            assert os.path.exists(path), path
            text = read(path)
            if kind in ('ast', 'res'):
                new = b4a_tree(text, 'A', where)
            elif kind == 'lir1':
                new = b4a_lir(text, funs)
            else:
                new = b4a_tree(text, 'H', where)
            if kind == 'res':
                got = classify_res(new)
                assert got == [(nm, el) for nm, el, _ in CLASS[test]], (test, got)
            write(test + '.' + kind, new)
            n += 1
    return n


# ================================================================ part 4b: L20 model (hirl, lir1)
# DESIGN 2.11.4 L20 and 2.11.5 with 3.5.9 (L18, R26-R30) and 3.6.6 rule 37 / "Lowering of the
# sea.hirl records". L20 copies the callee's body into an inline `xblk` of `tmp`s and an `iblk`
# and then rewrites the copy by L1-L17 like any code of the caller (2.11.4: as L18). Because the
# copied nodes keep their own positions (L20 (1), L-cf) and L1-L17 are local rewrites that write
# every node at the position of the node they implement, the rewritten copy of a body is the
# callee's own rewritten body (its `.hirl` function, derived by hand when its test was written)
# with: every `lv` of parameter p_i reading the `tmp` local A_i (L18 (2)); every `.l` local a new
# `.l` local of the caller, every other local of the callee a new `.i` local of the caller (L18
# (3)); every `ret P' k` an `iret P' k` (L18 (4), at its own position by L20 (1)); a `tret` as
# L20 (3) says; every `call` of an `elem`/`inl` function in it rewritten again (L20 (5)). The
# rewrites L1-L17 see only val parameters here, which no rewrite treats otherwise than a `let`
# local (a val parameter is immutable and borrowed, as a `tmp` local is, T1), so the equality
# holds; a `ref` parameter (R31) is handled where a test has one. The xblk, its tmps, the iblk and
# the `loc` records of the new `.l` (parameter) and `.i` locals take the call's position P
# (L-cf; 3.5.9 "Locals": a `.l` local's pos is that of the node its rewrite implements, the call
# for the parameter tmps). Locals are then numbered as 3.5.9 "Locals" says: the caller's
# parameters, source, `.t` and `.j` locals keep their ids, the `.l` locals follow in the order of
# their declaring records (tmp, bind, rcnt l then e, hloop, L12's tbind), the `.i` locals after
# them in the order of theirs (R28: bind, forr, tbind, a seq's bind, tmp). The `tptr` and F8
# types are renumbered in order of first reference (3.5.9 "Types"), the inlined functions dropped
# and the rest renumbered densely (L-cg).
#
# The .lir1 by the same reasoning (rule 37 with R26-R29 as "Lowering of the sea.hirl records"
# gives them): at each inlined call the arguments are lowered as before (T1: an `lv` argument
# aliases its register, any other argument computed into the tmp's register, which is what the
# call's argument register was), then `do B`, the callee's lowered body with its parameter
# registers replaced by the argument registers, new registers, blocks, slots and data records of
# its own (one data record per occurrence, 3.6.2), each `ret k V...` replaced by `mov R1 V1` ...
# `mov Rk Vk`, `exit B` (R1 ... Rk new registers numbered at the first such mov), a void body's
# final `ret 0` by `exit B` (its releases, rule 16 (a), already precede it), then `enddo B`; the
# call's result registers are then R1 ... Rk (no destination, R27), or a destination receives
# `mov D R1` after `enddo`; the owned argument temporaries are released right after, as after
# the call (T2, R26). Registers, blocks, slots and data labels are then renumbered as 3.6.1-3.6.4
# say. Which call sites have a destination is stated per test (DEST below), read off the
# source.

def h_fields(rec):
    """[(name, kind, token index)] of a HIR record (sets H H1 HF HL), counted fields expanded."""
    spec = None
    for s in ('H', 'H1', 'HF', 'HL'):
        if rec[0] in FMT.get(s, {}):
            spec = FMT[s][rec[0]]
    assert spec is not None, rec
    out, vals, k = [], {}, 1
    for f in spec:
        nm, kind = f.split(':', 1)
        if '*' in kind:
            kind, cnt = kind.split('*')
            for _ in range(int(vals[cnt])):
                out.append((nm, kind.rstrip('?'), k))
                k += 1
            continue
        out.append((nm, kind.rstrip('?'), k))
        vals[nm] = rec[k]
        k += 1
    assert k == len(rec), ('field count', rec)
    return out


def h_pops(rec):
    d = {nm: rec[k] for nm, _, k in h_fields(rec)}
    st = 'H'
    e = POPS.get(('H', rec[0]))
    env = {k: int(v) for k, v in d.items() if re.match(r'^-?[0-9]+$', v)}
    return int(eval(e, {}, env))


def h_split(text):
    """(header lines, type records, [function dicts]) of a HIR file."""
    lines_ = [ln for ln in text.split('\n') if ln]
    head = [ln for ln in lines_ if ln.startswith('#') and ln != '#end']
    body = [ln.split(' ') for ln in lines_ if not ln.startswith('#')]
    types, fns, cur = [], [], None
    for r in body:
        if r[0] == 'fn':
            cur = {'fn': r, 'par': [], 'loc': [], 'body': []}
            fns.append(cur)
        elif cur is None:
            types.append(r)
        elif r[0] == 'par':
            cur['par'].append(r)
        elif r[0] == 'loc':
            cur['loc'].append(r)
        elif r[0] == 'end':
            cur = None
        else:
            cur['body'].append(r)
    return head, types, fns


def h_span(recs, j):
    """Index of the first record of the subtree rooted at recs[j]."""
    need = 1
    while True:
        need += h_pops(recs[j]) - 1
        if need == 0:
            return j
        j -= 1


def h_kids(recs, j):
    """[(start, end)] spans of the children of recs[j], in order."""
    n = h_pops(recs[j])
    spans, e = [], j
    for _ in range(n):
        s = h_span(recs, e - 1)
        spans.append((s, e))
        e = s
    return spans[::-1]


DECL = ('tmp', 'bind', 'tbind', 'rcnt', 'hloop', 'forr', 'fore')


class Inliner:
    """L20 on one HIR (sea.hirl) file: CALLS of the functions named in `inl` are inlined."""

    def __init__(self, hirl_text, hir_text, inl):
        self.head, self.types, self.fns = h_split(hirl_text)
        _, hir_types, _ = h_split(hir_text)
        ids = [int(t[1]) for t in hir_types if t[0] != 'fd']
        self.hir_max = max(ids) if ids else 9
        self.byfid = {f['fn'][1]: f for f in self.fns}
        self.inl = {f['fn'][1] for f in self.fns if f['fn'][2] in inl}
        self.k = 0

    def fresh(self, cls):
        self.k += 1
        return '%s#%d' % (cls, self.k)

    def lname(self, f, lid):
        """('par'|'loc', loc record) of local lid of function f (1-based, params first)."""
        n = int(lid)
        if n <= len(f['par']):
            return 'par', f['par'][n - 1]
        return 'loc', f['loc'][n - len(f['par']) - 1]

    def copy_body(self, F, args, P, info):
        """The records of F's body block, copied for a call at P with tmp locals args."""
        m = {}
        for i in range(len(F['par'])):
            m[str(i + 1)] = args[i]
        for j, lr in enumerate(F['loc']):
            lid = str(len(F['par']) + j + 1)
            if lr[1].startswith('.l'):
                nl = self.fresh('L')
                info[nl] = (lr[2], lr[3], lr[4])            # own type, mut, pos
            else:
                nl = self.fresh('I')
                info[nl] = (lr[2], lr[3], P)                # L-cf: pos P
            m[lid] = nl
        out = []
        for r in F['body']:
            r = list(r)
            for nm, kind, k in h_fields(r):
                if kind == 'lid' and r[k] != '-':
                    r[k] = m[r[k]]
            if r[0] == 'ret':
                r[0] = 'iret'
            assert r[0] != 'tret', ('tret in an inlined body: not in these tests', r)
            out.append(r)
        return self.expand(out, P_outer=None, info=info)

    def expand(self, recs, P_outer, info):
        """Rewrite every call of an inlined function in recs (post-order), recursively."""
        j = 0
        recs = list(recs)
        while j < len(recs):
            r = recs[j]
            if r[0] == 'call' and r[3] in self.inl:
                P, ty, fid, n = r[1], r[2], r[3], int(r[4])
                F = self.byfid[fid]
                spans = h_kids(recs, j)
                new, args = [], []
                for (s, e), par in zip(spans, F['par']):
                    a = self.fresh('L')
                    info[a] = (par[2], 'let', P)
                    args.append(a)
                    new += recs[s:e] + [['tmp', P, a]]
                body = self.copy_body(F, args, P, info)
                rty = F['fn'][4]
                k = 0 if rty == '1' else (self.tuple_n(rty) or 1)
                new += body + [['iblk', P, ty, str(k)], ['xblk', P, ty, str(n)]]
                s0 = spans[0][0] if spans else j
                recs[s0:j + 1] = new
                j = s0 + len(new)
                continue
            j += 1
        return recs

    def tuple_n(self, ty):
        for t in self.types:
            if t[0] == 'ttuple' and t[1] == ty:
                return int(t[2])
        return 0

    def run(self):
        kept = [f for f in self.fns if f['fn'][1] not in self.inl]
        fidmap = {f['fn'][1]: str(i + 1) for i, f in enumerate(kept)}
        out_fns = []
        for f in kept:
            info = {}
            body = self.expand(f['body'], None, info)
            np_ = len(f['par'])
            fixed = [lr for lr in f['loc'] if not lr[1].startswith(('.l', '.i'))]
            base = np_ + len(fixed)
            # the caller's own .l locals become symbolic too, keeping their loc records
            old = {}
            for j, lr in enumerate(f['loc']):
                lid = str(np_ + j + 1)
                if lr[1].startswith(('.l', '.i')):
                    s = self.fresh(lr[1][1].upper())
                    info[s] = (lr[2], lr[3], lr[4])
                    old[lid] = s
            for r in body:
                for nm, kind, k in h_fields(r):
                    if kind == 'lid' and r[k] in old:
                        r[k] = old[r[k]]
            order = {'L': [], 'I': []}
            for r in body:
                if r[0] in DECL:
                    for nm, kind, k in h_fields(r):
                        if kind == 'lid' and '#' in r[k] and r[k] not in order[r[k][0]]:
                            order[r[k][0]].append(r[k])
            for s in info:
                assert s in order[s[0]], ('local never declared', s, info[s])
            num, locs = {}, list(fixed)
            for grp, pre in (('L', '.l'), ('I', '.i')):
                for i, s in enumerate(order[grp]):
                    num[s] = str(base + len(locs) - len(fixed) + 1)
                    t, mut, pos = info[s]
                    locs.append(['loc', '%s%d' % (pre, i + 1), t, mut, pos])
            for r in body:
                for nm, kind, k in h_fields(r):
                    if kind == 'lid' and r[k] in num:
                        r[k] = num[r[k]]
                    if kind == 'fid':
                        r[k] = fidmap[r[k]]
            fn = list(f['fn'])
            fn[1] = fidmap[fn[1]]
            fn[6] = str(len(locs))
            out_fns.append({'fn': fn, 'par': f['par'], 'loc': locs, 'body': body})
        # types: the appended tptr / F8 records renumbered in order of first reference
        appended = [t for t in self.types if t[0] != 'fd' and int(t[1]) > self.hir_max]
        tmap, seen = {}, []
        for f in out_fns:
            for r in f['loc'] + f['body']:
                for nm, kind, k in h_fields(r):
                    if kind == 'ty' and int(r[k]) > self.hir_max and r[k] not in seen:
                        seen.append(r[k])
        for t in appended:
            assert t[1] in seen, ('appended type no longer referenced', t)
        for i, old_id in enumerate(seen):
            tmap[old_id] = str(self.hir_max + 1 + i)
        types, inside = [], False
        for t in self.types:
            if t[0] != 'fd':
                inside = int(t[1]) <= self.hir_max
            if inside:
                types.append(t)
        for old_id in seen:
            t = list(next(t for t in appended if t[1] == old_id))
            t[1] = tmap[old_id]
            for nm, kind, k in h_fields(t):
                if kind == 'ty' and nm != 'id' and t[k] in tmap:
                    t[k] = tmap[t[k]]
            types.append(t)
        lines_ = list(self.head) + [' '.join(t) for t in types]
        for f in out_fns:
            for r in [f['fn']] + f['par'] + f['loc'] + f['body']:
                r = list(r)
                for nm, kind, k in h_fields(r):
                    if kind == 'ty' and r[k] in tmap:
                        r[k] = tmap[r[k]]
                lines_.append(' '.join(r))
            lines_.append('end')
        return '\n'.join(lines_) + '\n#end\n'


# ---------------------------------------------------------------- the .lir1 splice
def l_fields(rec):
    spec = FMT['L'][rec[0]] if rec[0] in FMT['L'] else FMT['LF'][rec[0]]
    out, vals, k = [], {}, 1
    for f in spec:
        nm, kind = f.split(':', 1)
        if '*' in kind:
            kind, cnt = kind.split('*')
            for _ in range(int(vals[cnt])):
                out.append((nm, kind.rstrip('?'), k))
                k += 1
            continue
        out.append((nm, kind.rstrip('?'), k))
        vals[nm] = rec[k]
        k += 1
    assert k == len(rec), ('field count', rec)
    return out


REGK = ('reg', 'ri', 'rf', 'rp', 'rx', 'ry', 'rm')


def l_split(text):
    lines_ = [ln.split(' ') for ln in text.split('\n') if ln]
    head = [' '.join(r) for r in lines_ if r[0].startswith('#') and r[0] != '#end']
    fns, data, cur = [], [], None
    for r in lines_:
        if r[0].startswith('#'):
            continue
        if r[0] == 'func':
            cur = {'func': r, 'slots': [], 'body': []}
            fns.append(cur)
        elif r[0] == 'endfunc':
            cur = None
        elif cur is None:
            data.append(r)
        elif r[0] == 'slot':
            cur['slots'].append(r)
        else:
            cur['body'].append(r)
    groups, g = [], None
    for r in data:
        if r[0] in ('str', 'fmt', 'dat', 'slay'):
            g = [r]
            groups.append(g)
        else:
            g.append(r)
    return head, fns, {g[0][1]: g for g in groups}


class LSplicer:
    def __init__(self, text):
        self.head, self.fns, self.data = l_split(text)
        self.byname = {f['func'][1]: f for f in self.fns}
        self.k = 0
        self.newdata = {}

    def fresh(self, c):
        self.k += 1
        return '%s#%d' % (c, self.k)

    def copy(self, F, argregs, dests):
        """The do-block for a call of F with argument registers argregs: (records, results)."""
        pars = F['func'][5:5 + int(F['func'][4])]
        rm = dict(zip(pars, argregs))
        sm, bm, dm = {}, {}, {}
        B = self.fresh('B')
        res = []
        out = [['do', B]]
        slots = {s[1]: s for s in F['slots']}
        body = F['body']
        for idx, r in enumerate(body):
            r = list(r)
            if r[0] == 'ret':
                n = int(r[1])
                vals = [rm.setdefault(v, self.fresh(v[0])) for v in r[2:2 + n]]
                if not res:
                    res = [self.fresh(v[0]) for v in vals]
                for R, V in zip(res, vals):
                    out.append(['mov', R, V])
                out.append(['exit', B])
                continue
            for nm, kind, k in l_fields(r):
                v = r[k]
                if v == '-':
                    continue
                if kind in REGK:
                    if v not in rm:
                        rm[v] = self.fresh(v[0])
                    r[k] = rm[v]
                elif kind == 'blk':
                    bm.setdefault(v, self.fresh('B'))
                    r[k] = bm[v]
                elif kind == 'slot':
                    if v not in sm:
                        sm[v] = self.fresh('S')
                        self.slotsize[sm[v]] = slots[v][2:]
                    r[k] = sm[v]
                elif kind == 'lab':
                    if v not in dm:
                        dm[v] = self.fresh('D')
                        self.newdata[dm[v]] = self.data[v]
                    r[k] = dm[v]
            out.append(r)
        out.append(['enddo', B])
        return out, res

    def run(self, inl, dest=None):
        dest = dest or {}
        lines_ = list(self.head)
        allbody = []
        kept = [f for f in self.fns if f['func'][1] not in inl]
        nth = {}
        for f in kept:
            self.slotsize = {s[1]: s[2:] for s in f['slots']}
            body, j = [], 0
            ren = {}
            for r in f['body']:
                r = [ren.get(t, t) for t in r]
                if r[0] == 'call' and r[1] in inl:
                    F = self.byname[r[1]]
                    nr = int(r[2])
                    d = r[3:3 + nr]
                    na = int(r[3 + nr])
                    a = r[4 + nr:4 + nr + na]
                    key = (f['func'][1], r[1])
                    nth[key] = nth.get(key, 0) + 1
                    blk, res = self.copy(F, a, d)
                    body += blk
                    if dest.get((key, nth[key])):
                        for D, R in zip(d, res):
                            body.append(['mov', D, R])
                    else:
                        for D, R in zip(d, res):
                            ren[D] = R
                    continue
                body.append(r)
            # renumber registers, blocks, slots of this function
            func = list(f['func'])
            regs = {}
            for p in func[5:5 + int(func[4])]:
                regs[p] = '%s%d' % (p[0], len(regs) + 1)
            blks, sls = {}, {}
            for r in body:
                for nm, kind, k in l_fields(r):
                    v = r[k]
                    if v == '-':
                        continue
                    if kind in REGK:
                        if v not in regs:
                            regs[v] = '%s%d' % (v[0], len(regs) + 1)
                        r[k] = regs[v]
                    elif kind == 'blk':
                        if v not in blks:
                            blks[v] = str(len(blks) + 1)
                        r[k] = blks[v]
                    elif kind == 'slot':
                        if v not in sls:
                            sls[v] = 's%d' % (len(sls) + 1)
                        r[k] = sls[v]
            slots = [['slot', sls[s]] + self.slotsize[s] for s in sorted(sls, key=lambda x: int(sls[x][1:]))]
            allbody.append((func, slots, body))
        # data labels in order of first reference over the file
        labs = {}
        for func, slots, body in allbody:
            for r in body:
                for nm, kind, k in l_fields(r):
                    if kind == 'lab':
                        if r[k] not in labs:
                            labs[r[k]] = 'd%d' % (len(labs) + 1)
                        r[k] = labs[r[k]]
        for func, slots, body in allbody:
            lines_ += [' '.join(x) for x in [func] + slots + body + [['endfunc']]]
        src = dict(self.data)
        src.update(self.newdata)
        for old, new in sorted(labs.items(), key=lambda x: int(x[1][1:])):
            g = [list(x) for x in src[old]]
            g[0][1] = new
            lines_ += [' '.join(x) for x in g]
        return '\n'.join(lines_) + '\n#end\n'


BASE = 'b89350d'      # the last commit before 6b's goldens: the pre-6b (callee-as-function) dumps


def base_golden(name):
    """tests/passes/NAME as committed at BASE (git), the input of the L20 model."""
    import subprocess
    return subprocess.run(['git', '-C', ROOT, 'show', '%s:tests/passes/%s' % (BASE, name)],
                          check=True, capture_output=True, text=True).stdout


# the nine tests of Decision 90 whose function is inlined: test -> inlined functions. Every call
# site of these has no destination (a printf operand, a match scrutinee's tmp, an eval), so no
# `mov D R1` follows an `enddo` (R27).
INL9 = {'lib_sum_dim0': ['colsum'], 'lib_sum_dim1': ['rowsum'], 'lib_variance': ['spread'],
        'match_l16': ['tag'], 'str_ew': ['ew'], 'str_fill_flat': ['tile'],
        'str_fixed_self': ['show'], 'str_l17': ['put'], 'struct_l17': ['edit']}
assert sorted(INL9) == sorted(INLINED)


def part4b():
    n = 0
    for t, fs in sorted(INL9.items()):
        assert [nm for nm, el, _ in CLASS[t] if el == 2] == fs, t
        h = Inliner(base_golden(t + '.hirl'), read(os.path.join(SRC_PASSES, t + '.hir')),
                    set(fs)).run()
        lr = LSplicer(base_golden(t + '.lir1')).run(set(fs))
        assert not any(ln.startswith('fn ') and ln.split(' ')[2] in fs for ln in h.split('\n'))
        write(t + '.hirl', h)
        write(t + '.lir1', lr)
        n += 2
    return n



# ================================================================ part 3: inl6_* (6.2 "6b, calls")
# inl6_count50 / inl6_count51 (2.11.3 (c) at SEA_LIM_INLINE_STMTS; L-ci): one function of 50 /
# 51 statements with two call sites and no loop, built by s_fn (part 2). Files: .sea, .hir1,
# .hir (by hand from 3.5.4-3.5.5: the scalar code of pass 2a, which pass 2b does not change: no
# constant folds here, the function reachable), .hirl (count50: L20 on both calls by the model of
# part 4b, the .hir standing for the pre-inline sea.hirl since sealoop rewrites none of its
# scalar records, 3.5.9 "Unchanged functions"; count51: the .hir byte for byte, nothing to
# rewrite), .out (LANGUAGE.md: c(0) = 0 -> 1 (else) -> 3 (block) -> 3 + n; c(5) = 6 -> 8 -> 8 + n).

def hir_sfn(L, n):
    """The body records (3.5.5) of s_fn's function at line L with n repeated statements; the
    parameter k is local 1, s local 2."""
    h = """lv 0:{1}:13 3 1
bind 0:{1}:5 2
lv 0:{2}:8 3 2
ci 0:{2}:12 3 0
bin 0:{2}:8 2 gt
lv 0:{3}:9 3 2
ci 0:{3}:14 3 1
asg 0:{3}:9 add
block 0:{2}:14 1
lv 0:{4}:15 3 2
ci 0:{4}:19 3 0
bin 0:{4}:15 2 lt
lv 0:{5}:9 3 2
ci 0:{5}:14 3 1
asg 0:{5}:9 sub
block 0:{4}:21 1
lv 0:{7}:9 3 2
ci 0:{7}:13 3 1
asg 0:{7}:9 set
block 0:{6}:12 1
if 0:{4}:12 1
if 0:{2}:5 1
lv 0:{10}:9 3 2
ci 0:{10}:14 3 2
asg 0:{10}:9 add
block 0:{9}:5 1
""".format(*range(L, L + 11))
    for r in range(L + 12, L + 12 + n):
        h += 'lv 0:%d:5 3 2\nci 0:%d:10 3 1\nasg 0:%d:5 add\n' % (r, r, r)
    ret = L + 12 + n
    h += 'lv 0:%d:12 3 2\nret 0:%d:5 1\nblock 0:%d:23 %d\n' % (ret, ret, L, n + 4)
    return h


def inl6_count(nst):
    name = 'inl6_count%d' % nst
    fname = 'c%d' % nst
    n = nst - 8
    head = ['// %s -- 8.6 (c) at its limit (DESIGN.md 2.11.3, L-ci): %s has two call sites, no'
            % (name, fname),
            '// loop and %d statements (the if ... else if ... else chain 1, its branches 3, the bare'
            % nst,
            '// block 1 and its statement 1), so %s' % (
                'both calls are inlined by L20 (kind inl; the .hirl keeps the copied nodes\' own'
                if nst <= SEA_LIM_INLINE_STMTS else
                'it stays a call (kind fn; the .hirl is the .hir: nothing to rewrite)'),
            '// %s' % ('positions, the tmps, iblk and xblk at the call, and drops ' + fname
                       if nst <= SEA_LIM_INLINE_STMTS else
                       'one statement over SEA_LIM_INLINE_STMTS, LANGUAGE.md 8.6')]
    L = len(head) + 1
    src, _ = s_fn(fname, L, n)
    m = L + len(src)
    main = 'printf("%%d %%d\\n", %s(0), %s(5))' % (fname, fname)
    sea = '\n'.join(head + src + [main]) + '\n'
    kind = 'inl' if nst <= SEA_LIM_INLINE_STMTS else 'fn'
    hir = ('#sea 1\n#target arm64-macos\n#file %s.sea\n' % name
           + 'fn 1 .main main 1 0 0 0:1:1\n'
           + 'ci 0:{0}:23 3 0\ncall 0:{0}:19 3 2 1\nfconv 0:{0}:8 1 - - - d\nftext 0:{0}:8 1 %20\n'
             'ci 0:{0}:31 3 5\ncall 0:{0}:27 3 2 1\nfconv 0:{0}:8 1 - - - d\n'
             'ftext 0:{0}:8 1 %0A\nfmt 0:{0}:8 1 4\nlib 0:{0}:1 1 printf 1\neval 0:{0}:1\n'
             'block 0:1:1 1\nend\n'.format(m)
           + 'fn 2 %s %s 3 1 1 0:%d:1\npar k 3 val\nloc s 3 var 0:%d:9\n' % (fname, kind, L, L + 1)
           + hir_sfn(L, n) + 'end\n#end\n')
    check_hir_positions(name, sea, hir)
    if kind == 'inl':
        hirl = Inliner(hir, hir, {fname}).run()
    else:
        hirl = hir
    out = '%d %d\n' % (3 + n, 8 + n)
    write(name + '.sea', sea)
    write(name + '.hir1', hir)
    write(name + '.hir', hir)
    write(name + '.hirl', hirl)
    write(name + '.out', out)
    return 5


def check_hir_positions(name, src, hir):
    """Every positioned HIR record names the token 3.5.5 gives it (lv/ci their token, a bin or
    asg its left operand / target, a call its callee, if/ret/bind their keyword (bind: let/var),
    block its `{` or 1:1 for .main, fmt pieces the format string)."""
    sl = src.split('\n')
    for ln in hir.split('\n'):
        p = ln.split(' ')
        if not ln or ln.startswith('#') or p[0] in ('fn', 'par', 'loc', 'end'):
            continue
        f, l, c = (int(x) for x in p[1].split(':'))
        if (l, c) == (1, 1):
            continue
        at = sl[l - 1][c - 1:]
        op = p[0]
        if op == 'ci':
            assert re.match(p[3] + r'\b', at), (name, ln, at)
        elif op in ('lv', 'bin', 'asg', 'call', 'lib', 'eval'):
            assert re.match(r'[A-Za-z_]', at), (name, ln, at)
        elif op in ('fconv', 'ftext', 'fmt'):
            assert at.startswith('"'), (name, ln)
        elif op == 'block':
            assert at.startswith('{'), (name, ln, at)
        elif op == 'bind':
            assert at.startswith(('let ', 'var ')), (name, ln)
        elif op == 'ret':
            assert at.startswith('return'), (name, ln)
        elif op == 'if':
            assert at.startswith('if '), (name, ln)
        else:
            raise AssertionError((name, ln))



# inl6_basic, inl6_ref, inl6_agg (6.2 "6b, calls": `.res` showing el 2, `.hir1` with the kind
# inl, `.hirl` of L20 with its kept positions, `.lir1` with R31's slot and reload after `enddo`
# and R32's home, the dropped functions). Each file by hand: the .ast from 3.4, the .res by
# res_gen6 (part 2), the .hir (= .hir1: no constant, no fold, every function reachable) from
# 3.5.4-3.5.5, the .hirl by the L20 model (part 4b) on the .hir (sealoop rewrites none of these
# records but the calls: scalars, a struct literal and a field read are kept, 3.5.9), the .lir1
# instruction by instruction below with its derivation, the .out from LANGUAGE.md.

INL6_BASIC_SEA = """// inl6_basic -- 8.6 inlining by L20 (DESIGN.md 2.11.3-2.11.5): twice (two call sites, one
// statement) has el 2 and kind inl; its calls become inline xblks whose copied nodes keep their
// own positions (line 6 sites); a bind destination receives mov after enddo (R27), an operand
// takes R1 itself; twice is dropped and keep (a loop, two sites) renumbered from 3 to 2
fn twice(x: f64) -> f64 {
    return x * 2.0
}
fn keep(n: i64) -> i64 {
    var s = 0
    for i in 0..n {
        s += i
    }
    return s
}
let a = twice(1.5)
let b = twice(a) + 1.0
printf("%g %g %d %d\\n", a, b, keep(3), keep(4))
"""
INL6_BASIC_AST = """
type 0:5:13 f64 s 0
param 0:5:10 x 0 0
type 0:5:21 f64 s 0
name 0:6:12 x
float 0:6:16 #4000000000000000
bin 0:6:12 mul
return 0:6:5 1
block 0:5:25 1
fn 0:5:1 twice 0 1 1
type 0:8:12 i64 s 0
param 0:8:9 n 0 0
type 0:8:20 i64 s 0
pname 0:9:9 s
int 0:9:13 0
var 0:9:5 0
int 0:10:14 0
name 0:10:17 n
range 0:10:14 0 0
name 0:11:9 s
name 0:11:14 i
asg 0:11:9 add
block 0:10:19 1
for 0:10:5 i 0:10:9
name 0:13:12 s
return 0:13:5 1
block 0:8:24 3
fn 0:8:1 keep 0 1 1
pname 0:15:5 a
name 0:15:9 twice
float 0:15:15 #3FF8000000000000
call 0:15:9 1
let 0:15:1 0
pname 0:16:5 b
name 0:16:9 twice
name 0:16:15 a
call 0:16:9 1
float 0:16:20 #3FF0000000000000
bin 0:16:9 add
let 0:16:1 0
name 0:17:1 printf
str 0:17:8 %25g%20%25g%20%25d%20%25d%0A
name 0:17:25 a
name 0:17:28 b
name 0:17:31 keep
int 0:17:36 3
call 0:17:31 1
name 0:17:40 keep
int 0:17:45 4
call 0:17:40 1
call 0:17:1 5
cstmt 0:17:1
prog 5
"""
# 3.5.4: .main 1, twice 2 (kind inl), keep 3; the range's type i64[] is 10 (3.5.1); each record
# at the position 3.5.5 gives it.
INL6_BASIC_HIR = """
tvec 10 3
fn 1 .main main 1 0 2 0:1:1
loc a 4 let 0:15:5
loc b 4 let 0:16:5
cf 0:15:15 4 #3FF8000000000000
call 0:15:9 4 2 1
bind 0:15:1 1
lv 0:16:15 4 1
call 0:16:9 4 2 1
cf 0:16:20 4 #3FF0000000000000
bin 0:16:9 4 add
bind 0:16:1 2
lv 0:17:25 4 1
fconv 0:17:8 1 - - - g
ftext 0:17:8 1 %20
lv 0:17:28 4 2
fconv 0:17:8 1 - - - g
ftext 0:17:8 1 %20
ci 0:17:36 3 3
call 0:17:31 3 3 1
fconv 0:17:8 1 - - - d
ftext 0:17:8 1 %20
ci 0:17:45 3 4
call 0:17:40 3 3 1
fconv 0:17:8 1 - - - d
ftext 0:17:8 1 %0A
fmt 0:17:8 1 8
lib 0:17:1 1 printf 1
eval 0:17:1
block 0:1:1 3
end
fn 2 twice inl 4 1 0 0:5:1
par x 4 val
lv 0:6:12 4 1
cf 0:6:16 4 #4000000000000000
bin 0:6:12 4 mul
ret 0:6:5 1
block 0:5:25 1
end
fn 3 keep fn 3 1 2 0:8:1
par n 3 val
loc s 3 var 0:9:9
loc i 3 for 0:10:9
ci 0:9:13 3 0
bind 0:9:5 2
ci 0:10:14 3 0
lv 0:10:17 3 1
rng 0:10:14 10 0 0
lv 0:11:9 3 2
lv 0:11:14 3 3
asg 0:11:9 add
block 0:10:19 1
forr 0:10:5 3
lv 0:13:12 3 2
ret 0:13:5 1
block 0:8:24 3
end
"""
# .lir1 (3.6.6): line 15: the tmp of x is cf 1.5 computed into its register (T1) f1; do 1; the
# copy: cf 2.0 lf f2, bin mul fmul into a new register f3 (no site: f64), the iret mov R1 = f4,
# exit 1, enddo 1; the bind of a is R27's destination: mov f5 f4 (a = f5). Line 16: the tmp of x
# is `lv a`, an alias of f5 (T1); do 2 ... R1 = f8; the bin add is the root of b's bind and writes
# b's register (rule 2), its left operand the iblk's R1 with no mov (R27, no destination): b =
# f10. Line 17: printf's arguments left to right (rule 8): a, b (lv: nothing), the two calls of
# keep (now function 2 of the .hirl, still `call keep` by name), then the slot of 4 words, the
# stores, the format d1. keep: rule 4's forr with rcount, its body iaddc at line 11's site.
INL6_BASIC_LIR1 = """
func .main main 0:1:1 0 0
slot s1 32 8
lf f1 #3FF8000000000000
do 1
lf f2 #4000000000000000
fmul f3 f1 f2
mov f4 f3
exit 1
enddo 1
mov f5 f4
do 2
lf f6 #4000000000000000
fmul f7 f5 f6
mov f8 f7
exit 2
enddo 2
lf f9 #3FF0000000000000
fadd f10 f8 f9
li i11 3
call keep 1 i12 1 i11
li i13 4
call keep 1 i14 1 i13
sa p15 s1
stf f5 p15 - 0 0
stf f10 p15 - 0 8
sti i12 p15 - 0 16
sti i14 p15 - 0 24
la p16 d1
rcall sea_printf 0:17 0 2 p16 p15
ret 0
endfunc
func keep fn 0:8:1 1 i1 1 i
li i2 0
li i3 0
li i4 1
rcount i5 i6 i3 i1 i4 0 0:10
if 1 i6
loop 2 i7 i3 i5 i4
iaddc i2 i2 i7 0:11
endloop 2
endif 1
ret 1 i2
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
"""

INL6_REF_SEA = """// inl6_ref -- R31 (DESIGN.md 2.11.5): inc (two call sites, two statements) is inlined with
// a ref scalar parameter: its tmp binds the rarg (the slot sa and the store of n), inside the
// iblk c is read and written through that address, and n is reloaded right after enddo; the
// read of n before the call on line 10 is copied (rule 12, R30 extended); line 11 under eval
fn inc(ref c: i64, d: i64) -> i64 {
    c += d
    return c
}
var n = 1
let m = n + inc(ref n, 10)
inc(ref n, 100)
printf("%d %d\\n", n, m)
"""
INL6_REF_HIR = """
fn 1 .main main 1 0 2 0:1:1
loc n 3 var 0:9:5
loc m 3 let 0:10:5
ci 0:9:9 3 1
bind 0:9:1 1
lv 0:10:9 3 1
lv 0:10:21 3 1
rarg 0:10:17 3
ci 0:10:24 3 10
call 0:10:13 3 2 2
bin 0:10:9 3 add
bind 0:10:1 2
lv 0:11:9 3 1
rarg 0:11:5 3
ci 0:11:12 3 100
call 0:11:1 3 2 2
eval 0:11:1
lv 0:12:19 3 1
fconv 0:12:8 1 - - - d
ftext 0:12:8 1 %20
lv 0:12:22 3 2
fconv 0:12:8 1 - - - d
ftext 0:12:8 1 %0A
fmt 0:12:8 1 4
lib 0:12:1 1 printf 1
eval 0:12:1
block 0:1:1 4
end
fn 2 inc inl 3 2 0 0:5:1
par c 3 ref
par d 3 val
lv 0:6:5 3 1
lv 0:6:10 3 2
asg 0:6:5 add
lv 0:7:12 3 1
ret 0:7:5 1
block 0:5:35 2
end
"""
# .lir1: n = i1 (rule 2). Line 10, left to right: the read of n precedes a call passing n by ref
# (the inline xblk is that call, R31), so it is copied: mov i2 i1 (rule 12); the tmp of c binds
# the rarg: sa p3 s1, sti i1 p3 (rule 12's slot and store; the ref local is p3); the tmp of d is
# ci 10 into its register i4; do 1; `c += d`: c's current value loaded (ldi i5 p3), the operation
# into a new register (iaddc i6, line 6's site: the callee's own, L-cf), the store (sti i6 p3);
# `return c`: ldi i7 p3, the iret's mov R1 = i8, exit 1; enddo 1; the reload ldi i1 p3 right
# after enddo (R31); the bin add, root of m's bind, writes m = i9 from the copy i2 and R1 i8.
# Line 11: the same with slot s2, 100 in i11, R1 = i15 unused (eval of a scalar: nothing to
# release, R27); reload. Line 12: printf.
INL6_REF_LIR1 = """
func .main main 0:1:1 0 0
slot s1 8 8
slot s2 8 8
slot s3 16 8
li i1 1
mov i2 i1
sa p3 s1
sti i1 p3 - 0 0
li i4 10
do 1
ldi i5 p3 - 0 0
iaddc i6 i5 i4 0:6
sti i6 p3 - 0 0
ldi i7 p3 - 0 0
mov i8 i7
exit 1
enddo 1
ldi i1 p3 - 0 0
iaddc i9 i2 i8 0:10
sa p10 s2
sti i1 p10 - 0 0
li i11 100
do 2
ldi i12 p10 - 0 0
iaddc i13 i12 i11 0:6
sti i13 p10 - 0 0
ldi i14 p10 - 0 0
mov i15 i14
exit 2
enddo 2
ldi i1 p10 - 0 0
sa p16 s3
sti i1 p16 - 0 0
sti i9 p16 - 0 8
la p17 d1
rcall sea_printf 0:12 0 2 p17 p16
ret 0
endfunc
fmt d1 4
fconv - - - d i
ftext %20
fconv - - - d i
ftext %0A
"""

INL6_AGG_SEA = """// inl6_agg -- R32 (DESIGN.md 2.11.5): mk (two call sites, one statement) returns a struct and
// is inlined: each iblk gets a new home H before do, the iret stores the struct literal's own
// home into H (rule 27 (d): an owned value moved, li and mcopy) and exits, and the field read
// takes H; P holds no reference field, so no retain or release appears
fn mk(x: f64) -> P {
    return P { x: x, y: x * 2.0 }
}
printf("%g %g\\n", mk(1.5).x, mk(2.0).y)
struct P {
    x: f64
    y: f64
}
"""
INL6_AGG_HIR = """
tstruct 10 P 2
fd x 4
fd y 4
fn 1 .main main 1 0 0 0:1:1
cf 0:8:22 4 #3FF8000000000000
call 0:8:19 10 2 1
fld 0:8:19 4 0
fconv 0:8:8 1 - - - g
ftext 0:8:8 1 %20
cf 0:8:33 4 #4000000000000000
call 0:8:30 10 2 1
fld 0:8:30 4 1
fconv 0:8:8 1 - - - g
ftext 0:8:8 1 %0A
fmt 0:8:8 1 4
lib 0:8:1 1 printf 1
eval 0:8:1
block 0:1:1 1
end
fn 2 mk inl 10 1 0 0:5:1
par x 4 val
lv 0:6:19 4 1
lv 0:6:25 4 1
cf 0:6:29 4 #4000000000000000
bin 0:6:25 4 mul
slit 0:6:12 10 2
ret 0:6:5 1
block 0:5:20 1
end
"""
# .lir1 (P: size 16, x@0, y@8, no reference field): printf's first argument, the fld of the
# inline xblk: the tmp of x, cf 1.5 into f1 (T1); R32's home H before do: sa p2 s1 (rule 27 (a),
# slot 16); do 1; the iret's value, the slit, in its own temporary home V (rule 27 (a), (g)): sa
# p3 s2, x stored, x * 2.0 computed and stored; the iret stores V into H by rule 27 (d): V owned
# (moved: no retain), H's old reference fields none, li i6 16, mcopy p2 p3 i6; exit 1 (no mov:
# the iblk's value is H); enddo 1; the field read ldf f7 p2 (rule 27 (e)); H, owned, holds no
# reference field, so rule 15 (g) releases nothing. The second argument alike (slots s3, s4, y at
# offset 8), then the printf slot s5.
INL6_AGG_LIR1 = """
func .main main 0:1:1 0 0
slot s1 16 8
slot s2 16 8
slot s3 16 8
slot s4 16 8
slot s5 16 8
lf f1 #3FF8000000000000
sa p2 s1
do 1
sa p3 s2
stf f1 p3 - 0 0
lf f4 #4000000000000000
fmul f5 f1 f4
stf f5 p3 - 0 8
li i6 16
mcopy p2 p3 i6
exit 1
enddo 1
ldf f7 p2 - 0 0
lf f8 #4000000000000000
sa p9 s3
do 2
sa p10 s4
stf f8 p10 - 0 0
lf f11 #4000000000000000
fmul f12 f8 f11
stf f12 p10 - 0 8
li i13 16
mcopy p9 p10 i13
exit 2
enddo 2
ldf f14 p9 - 0 8
sa p15 s5
stf f7 p15 - 0 0
stf f14 p15 - 0 8
la p16 d1
rcall sea_printf 0:8 0 2 p16 p15
ret 0
endfunc
fmt d1 4
fconv - - - g f
ftext %20
fconv - - - g f
ftext %0A
"""

CLASS['inl6_basic'] = [('twice', 2, '(c) 2 sites, 1 stmt'), ('keep', 0, '2 sites, loop')]


def lines_dump(name, body):
    return ('#sea 1\n#target arm64-macos\n#file %s.sea\n' % name
            + '\n'.join(ln for ln in body.strip('\n').split('\n') if ln) + '\n#end\n')


def inl6_dumps(rg):
    n = 0
    for name, sea, ast, hir, lir1, inl, out in (
            ('inl6_basic', INL6_BASIC_SEA, INL6_BASIC_AST, INL6_BASIC_HIR, INL6_BASIC_LIR1,
             {'twice'}, '3 7 3 6\n'),
            ('inl6_ref', INL6_REF_SEA, None, INL6_REF_HIR, INL6_REF_LIR1, {'inc'}, '111 12\n'),
            ('inl6_agg', INL6_AGG_SEA, None, INL6_AGG_HIR, INL6_AGG_LIR1, {'mk'}, '1.5 4\n')):
        hirt = lines_dump(name, hir)
        hirl = Inliner(hirt, hirt, inl).run()
        write(name + '.sea', sea)
        if ast is not None:
            a = lines_dump(name, ast)
            check_ast_positions(name, sea, a)
            write(name + '.ast', a)
            write(name + '.res', gen_res(rg, name, a))
            n += 2
        write(name + '.hir1', hirt)
        write(name + '.hir', hirt)
        write(name + '.hirl', hirl)
        write(name + '.lir1', lines_dump(name, lir1))
        write(name + '.out', out)
        n += 6
    return n



# inl6_seq_named (6.2 "6b, calls"; L-cp, R11): .sea .hir1 .hir .hirl .out. Pass 2a writes pick's
# arguments in parameter order (a, b) and keeps the source order (b's m2 first) by 3.5.5
# "Evaluation order": both are non-constant expressions, bound in source order to .t1 (m2) and .t2
# (m1), each `bind` and `lv .tn` at the expression's position, `loc .tn` at that position too,
# the call the value of a `seq` at the call's position. The `seq` is the mask of the L6 store of
# line 12 (3.5.9 L6 step 2: a mask is a `tmp`; R11's `seq` case: the .t locals are released at
# the block's end right after the mask's own release, which the .lir1 would show; this test's
# dumps stop at the .hirl). pick keeps its calls: a loop (`while false {}`) and two call sites
# (el 0, kind fn, 8.6). The .hirl: L2 for each `filled` (the template FILLED below, the form of
# loop_fill's goldens), L6 for line 12 (the template of arr_rule21's mask store, the mask's child
# now the seq, kept as written: sealoop rewrites nothing in it), `len` of a vector as `ext`
# (str_fill_flat), the scalar element reads kept; the tptr types numbered 12 (f64) and 13
# (bool) at their first reference (3.5.9 "Types"), the .l locals in the order of their declaring
# records.
SEQ_SEA = """// inl6_seq_named -- named arguments out of parameter order (DESIGN.md 3.5.5 "Evaluation
// order", L-cp): m2 and m1 are bound in source order to .t1 and .t2 and pick gets lv .t2, lv .t1
// in a seq; the seq is the mask of an L6 store, a tmp of its block (R11's seq case); pick keeps
// its calls (a loop and two call sites, LANGUAGE.md 8.6)
fn pick(a: bool[], b: bool[]) -> bool[] { while false {}
    printf("pick %d %d\\n", len(a), len(b))
    return a
}
var v = filled(1.0, 3)
let m1 = filled(true, 3)
let m2 = filled(false, 2)
v[pick(b: m2, a: m1)] = 0.0
let w = pick(m2, m1)
printf("%g %g %g %d\\n", v[0], v[1], v[2], len(w))
"""
SEQ_HIR_MAIN_HEAD = """
tvec 10 4
tvec 11 2
fn 1 .main main 1 0 {nl} 0:1:1
loc v 10 var 0:9:5
loc m1 11 let 0:10:5
loc m2 11 let 0:11:5
loc w 11 let 0:13:5
loc .t1 11 let 0:12:11
loc .t2 11 let 0:12:18
"""
SEQ_SEQ = """lv 0:12:11 11 3
bind 0:12:11 5
lv 0:12:18 11 2
bind 0:12:18 6
lv 0:12:18 11 6
lv 0:12:11 11 5
call 0:12:3 11 2 2
seq 0:12:3 11 2
"""
SEQ_TAIL = """lv 0:13:14 11 3
lv 0:13:18 11 2
call 0:13:9 11 2 2
bind 0:13:1 4
lv 0:14:25 10 1
ci 0:14:27 3 0
idx 0:14:25 4 1
fconv 0:14:8 1 - - - g
ftext 0:14:8 1 %20
lv 0:14:31 10 1
ci 0:14:33 3 1
idx 0:14:31 4 1
fconv 0:14:8 1 - - - g
ftext 0:14:8 1 %20
lv 0:14:37 10 1
ci 0:14:39 3 2
idx 0:14:37 4 1
fconv 0:14:8 1 - - - g
ftext 0:14:8 1 %20
lv 0:14:47 11 4
{len}
fconv 0:14:8 1 - - - d
ftext 0:14:8 1 %0A
fmt 0:14:8 1 8
lib 0:14:1 1 printf 1
eval 0:14:1
block 0:1:1 6
end
fn 2 pick fn 11 2 0 0:5:1
par a 11 val
par b 11 val
cb 0:5:49 2 0
block 0:5:55 0
while 0:5:43
ftext 0:6:12 1 pick%20
lv 0:6:32 11 1
{lena}
fconv 0:6:12 1 - - - d
ftext 0:6:12 1 %20
lv 0:6:40 11 2
{lenb}
fconv 0:6:12 1 - - - d
ftext 0:6:12 1 %0A
fmt 0:6:12 1 5
lib 0:6:5 1 printf 1
eval 0:6:5
lv 0:7:12 11 1
ret 0:7:5 1
block 0:5:41 3
end
"""
SEQ_HIR_INIT = """cf 0:9:16 4 #3FF0000000000000
ci 0:9:21 3 3
lib 0:9:9 10 filled 2
bind 0:9:1 1
cb 0:10:17 2 1
ci 0:10:23 3 3
lib 0:10:10 11 filled 2
bind 0:10:1 2
cb 0:11:17 2 0
ci 0:11:24 3 2
lib 0:11:10 11 filled 2
bind 0:11:1 3
lv 0:12:1 10 1
""" + SEQ_SEQ + """idx 0:12:1 10 1
cf 0:12:25 4 #0000000000000000
asg 0:12:1 set
"""


def filled(P, val, n, T, elt, TP, sc, lid):
    """L2 of `filled(val, n)`, a vector of type T (3.5.9 L2, the form of loop_fill.hirl): the
    records, its loc records and the next free lid. The locals: A the value, N the count, R the
    array, D its data, Z 0, One 1, Last N - 1, K the induction local."""
    A, N, R, D, Z, One, Last, K = range(lid, lid + 8)
    recs = """{val}
tmp {P} {A}
{n}
tmp {P} {N}
lv {P} 3 {N}
anew {P} {T} 0 1
tmp {P} {R}
lv {P} {T} {R}
adat {P} {TP}
tmp {P} {D}
ci {P} 3 0
tmp {P} {Z}
lv {P} 3 {N}
lv {P} 3 {Z}
bin {P} 2 gt
ci {P} 3 1
tmp {P} {One}
lv {P} 3 {N}
lv {P} 3 {One}
wbin {P} 3 sub
tmp {P} {Last}
lv {P} 3 {Z}
lv {P} 3 {Last}
lv {P} 3 {One}
lv {P} {elt} {A}
lv {P} {TP} {D}
lv {P} 3 {K}
est {P} {sc} 0
block {P} 1
hloop {P} {K}
block {P} 3
if {P} 0
lv {P} {T} {R}
xblk {P} {T} 6
""".format(**locals())
    locs = [(elt, 'let'), ('3', 'let'), (T, 'let'), (TP, 'let'), ('3', 'let'), ('3', 'let'),
            ('3', 'let'), ('3', 'for')]
    return recs, [(t, m, P) for t, m in locs], lid + 8


def l6_mask(P, value, target, mask, T, Tm, TPt, TPm, lid):
    """L6 of `asg set` to `idx target[mask]` with a scalar f64 value (3.5.9 L6, the form of
    arr_rule21.hirl line 5): Vv the value, M the mask, N, NM the extents, S, Neg the shape check,
    DT, DM the data, Z, One, Last, Q the loop."""
    Vv, M, N, NM, S, Neg, DT, DM, Z, One, Last, Q = range(lid, lid + 12)
    recs = """{value}tmp {P} {Vv}
{mask}tmp {P} {M}
lv {P} {T} {target}
ext {P} 3 0
tmp {P} {N}
lv {P} {Tm} {M}
ext {P} 3 0
tmp {P} {NM}
lv {P} 3 {N}
lv {P} 3 {NM}
bin {P} 2 ne
tmp {P} {S}
ci {P} 3 -1
tmp {P} {Neg}
lv {P} 2 {S}
lv {P} 3 {N}
lv {P} 3 {Neg}
lv {P} 3 {NM}
lv {P} 3 {Neg}
chk {P} SHAPE_MISMATCH 4
lv {P} {T} {target}
cow {P}
lv {P} {T} {target}
adat {P} {TPt}
tmp {P} {DT}
lv {P} {Tm} {M}
adat {P} {TPm}
tmp {P} {DM}
ci {P} 3 0
tmp {P} {Z}
lv {P} 3 {N}
lv {P} 3 {Z}
bin {P} 2 gt
ci {P} 3 1
tmp {P} {One}
lv {P} 3 {N}
lv {P} 3 {One}
wbin {P} 3 sub
tmp {P} {Last}
lv {P} 3 {Z}
lv {P} 3 {Last}
lv {P} 3 {One}
lv {P} {TPm} {DM}
lv {P} 3 {Q}
eld {P} 2 1 0
lv {P} 4 {Vv}
lv {P} {TPt} {DT}
lv {P} 3 {Q}
est {P} 8 0
block {P} 1
if {P} 0
block {P} 1
hloop {P} {Q}
block {P} 3
if {P} 0
block {P} 12
""".format(**locals())
    locs = [('4', 'let'), (Tm, 'let'), ('3', 'let'), ('3', 'let'), ('2', 'let'), ('3', 'let'),
            (TPt, 'let'), (TPm, 'let'), ('3', 'let'), ('3', 'let'), ('3', 'let'), ('3', 'for')]
    return recs, [(t, m, P) for t, m in locs], lid + 12


def inl6_seq_named():
    name = 'inl6_seq_named'
    head = SEQ_HIR_MAIN_HEAD.strip('\n')
    lib_len = lambda P: 'lib %s 3 len 1' % P
    hir = (head.format(nl=6) + '\n' + SEQ_HIR_INIT
           + SEQ_TAIL.format(len=lib_len('0:14:43'), lena=lib_len('0:6:28'), lenb=lib_len('0:6:36')))
    hirt = lines_dump(name, hir)
    # .hirl: lids 1-6 the source and .t locals, the .l locals from 7
    lid, locs, body = 7, [], ''
    for P, val, n, T, elt, TP, sc, bindrec in (
            ('0:9:9', 'cf 0:9:16 4 #3FF0000000000000', 'ci 0:9:21 3 3', '10', '4', '12', '8',
             'bind 0:9:1 1'),
            ('0:10:10', 'cb 0:10:17 2 1', 'ci 0:10:23 3 3', '11', '2', '13', '1', 'bind 0:10:1 2'),
            ('0:11:10', 'cb 0:11:17 2 0', 'ci 0:11:24 3 2', '11', '2', '13', '1', 'bind 0:11:1 3')):
        r, lc, lid = filled(P, val, n, T, elt, TP, sc, lid)
        body += r + bindrec + '\n'
        locs += lc
    r, lc, lid = l6_mask('0:12:1', 'cf 0:12:25 4 #0000000000000000\n', '1', SEQ_SEQ, '10', '11',
                         '12', '13', lid)
    body += r
    locs += lc
    ext = lambda P: 'ext %s 3 0' % P
    tail = SEQ_TAIL.format(len=ext('0:14:43'), lena=ext('0:6:28'), lenb=ext('0:6:36'))
    loc_recs = ''.join('loc .l%d %s %s %s\n' % (i + 1, t, m, P) for i, (t, m, P) in enumerate(locs))
    hirl = ('tvec 10 4\ntvec 11 2\ntptr 12 4\ntptr 13 2\n'
            + '\n'.join(head.split('\n')[2:]).format(nl=6 + len(locs)) + '\n' + loc_recs + body + tail)
    hirlt = lines_dump(name, hirl)
    check_hir_seq(SEQ_SEA, hirt)
    write(name + '.sea', SEQ_SEA)
    write(name + '.hir1', hirt)
    write(name + '.hir', hirt)
    write(name + '.hirl', hirlt)
    # pick prints its extents (3 2, then 2 3); the mask m1 = T T T zeroes v; len(w) = len(m2)
    write(name + '.out', 'pick 3 2\npick 2 3\n0 0 0 2\n')
    return 5


def check_hir_seq(src, hir):
    """The .t binds, their lv and the seq at the positions 3.5.5 gives them."""
    sl = src.split('\n')
    for ln in hir.split('\n'):
        p = ln.split(' ')
        if p[0] in ('bind', 'seq', 'call', 'loc') and p[-1].startswith('0:12:') or \
                (p[0] in ('bind', 'seq') and p[1].startswith('0:12:')):
            pos = p[-1] if p[0] == 'loc' else p[1]
            _, l, c = (int(x) for x in pos.split(':'))
            at = sl[l - 1][c - 1:]
            assert re.match(r'(m2|m1|pick)\b', at), (ln, at)



# The .ast and .res of the inl6_* tests that have a .hir1 (tests/stage.sh runs seacheck on the
# golden .res): the .ast by hand (3.4), the .res by res_gen6 (part 2; for inl6_agg with its
# STRUCTS flag, the 4g-2 resolution of struct items, types and literals), el the 8.6 class.
INL6_REF_AST = """
type 0:5:15 i64 s 0
param 0:5:8 c 1 0
type 0:5:23 i64 s 0
param 0:5:20 d 0 0
type 0:5:31 i64 s 0
name 0:6:5 c
name 0:6:10 d
asg 0:6:5 add
name 0:7:12 c
return 0:7:5 1
block 0:5:35 2
fn 0:5:1 inc 0 2 1
pname 0:9:5 n
int 0:9:9 1
var 0:9:1 0
pname 0:10:5 m
name 0:10:9 n
name 0:10:13 inc
name 0:10:21 n
ref 0:10:17
int 0:10:24 10
call 0:10:13 2
bin 0:10:9 add
let 0:10:1 0
name 0:11:1 inc
name 0:11:9 n
ref 0:11:5
int 0:11:12 100
call 0:11:1 2
cstmt 0:11:1
name 0:12:1 printf
str 0:12:8 %25d%20%25d%0A
name 0:12:19 n
name 0:12:22 m
call 0:12:1 3
cstmt 0:12:1
prog 5
"""
INL6_AGG_AST = """
type 0:5:10 f64 s 0
param 0:5:7 x 0 0
type 0:5:18 P s 0
name 0:6:19 x
init 0:6:16 x
name 0:6:25 x
float 0:6:29 #4000000000000000
bin 0:6:25 mul
init 0:6:22 y
slit 0:6:12 P 2
return 0:6:5 1
block 0:5:20 1
fn 0:5:1 mk 0 1 1
name 0:8:1 printf
str 0:8:8 %25g%20%25g%0A
name 0:8:19 mk
float 0:8:22 #3FF8000000000000
call 0:8:19 1
dot 0:8:19 x
name 0:8:30 mk
float 0:8:33 #4000000000000000
call 0:8:30 1
dot 0:8:30 y
call 0:8:1 3
cstmt 0:8:1
type 0:10:8 f64 s 0
field 0:10:5 x
type 0:11:8 f64 s 0
field 0:11:5 y
struct 0:9:1 P 2
prog 3
"""
SEQ_AST = """
type 0:5:12 bool v 0
param 0:5:9 a 0 0
type 0:5:23 bool v 0
param 0:5:20 b 0 0
type 0:5:34 bool v 0
false 0:5:49
block 0:5:55 0
while 0:5:43
name 0:6:5 printf
str 0:6:12 pick%20%25d%20%25d%0A
name 0:6:28 len
name 0:6:32 a
call 0:6:28 1
name 0:6:36 len
name 0:6:40 b
call 0:6:36 1
call 0:6:5 3
cstmt 0:6:5
name 0:7:12 a
return 0:7:5 1
block 0:5:41 3
fn 0:5:1 pick 0 2 1
pname 0:9:5 v
name 0:9:9 filled
float 0:9:16 #3FF0000000000000
int 0:9:21 3
call 0:9:9 2
var 0:9:1 0
pname 0:10:5 m1
name 0:10:10 filled
true 0:10:17
int 0:10:23 3
call 0:10:10 2
let 0:10:1 0
pname 0:11:5 m2
name 0:11:10 filled
false 0:11:17
int 0:11:24 2
call 0:11:10 2
let 0:11:1 0
name 0:12:1 v
name 0:12:3 pick
name 0:12:11 m2
narg 0:12:8 b
name 0:12:18 m1
narg 0:12:15 a
call 0:12:3 2
index 0:12:1 1
float 0:12:25 #0000000000000000
asg 0:12:1 set
pname 0:13:5 w
name 0:13:9 pick
name 0:13:14 m2
name 0:13:18 m1
call 0:13:9 2
let 0:13:1 0
name 0:14:1 printf
str 0:14:8 %25g%20%25g%20%25g%20%25d%0A
name 0:14:25 v
int 0:14:27 0
index 0:14:25 1
name 0:14:31 v
int 0:14:33 1
index 0:14:31 1
name 0:14:37 v
int 0:14:39 2
index 0:14:37 1
name 0:14:43 len
name 0:14:47 w
call 0:14:43 1
call 0:14:1 5
cstmt 0:14:1
prog 7
"""
CLASS['inl6_count50'] = [('c50', 2, '(c) 2 sites, 50 stmts')]
CLASS['inl6_count51'] = [('c51', 0, '2 sites, 51 stmts')]
CLASS['inl6_ref'] = [('inc', 2, '(c) 2 sites, 2 stmts')]
CLASS['inl6_agg'] = [('mk', 2, '(c) 2 sites, 1 stmt')]
CLASS['inl6_seq_named'] = [('pick', 0, '2 sites, loop')]


def count_ast(nst):
    name = 'inl6_count%d' % nst
    L = 5
    _, a = s_fn('c%d' % nst, L, nst - 8)
    m = L + (nst - 8) + 14
    a += """name 0:{0}:1 printf
str 0:{0}:8 %25d%20%25d%0A
name 0:{0}:19 c{1}
int 0:{0}:23 0
call 0:{0}:19 1
name 0:{0}:27 c{1}
int 0:{0}:31 5
call 0:{0}:27 1
call 0:{0}:1 3
cstmt 0:{0}:1
prog 2
""".format(m, nst)
    return a


def inl6_res(rg):
    n = 0
    for name, ast, structs in (('inl6_count50', count_ast(50), False),
                               ('inl6_count51', count_ast(51), False),
                               ('inl6_ref', INL6_REF_AST, False),
                               ('inl6_agg', INL6_AGG_AST, True),
                               ('inl6_seq_named', SEQ_AST, False)):
        a = lines_dump(name, ast)
        check_ast_positions(name, read(os.path.join(PASSES, name + '.sea')), a)
        rg.STRUCTS = structs
        write(name + '.ast', a)
        write(name + '.res', gen_res(rg, name, a))
        rg.STRUCTS = False
        n += 2
    return n


def part3():
    n = inl6_count(50) + inl6_count(51)
    n += inl6_dumps(res_gen6())
    n += inl6_seq_named()
    n += inl6_res(res_gen6())
    return n


def main():
    import shutil
    import tempfile
    global SCRATCH_DIR
    SCRATCH_DIR = tempfile.mkdtemp(prefix='dump6.')     # res_gen reads its .ast from a file
    try:
        n1 = part1()
        write('res_err_default.sea', RES_ERR_DEFAULT_SEA)
        n2 = part2()
        n3 = part3()
        n4a = part4a()
        n4b = part4b()
    finally:
        shutil.rmtree(SCRATCH_DIR)
    print('dump6_cases: part 1 (el 2 / inl): %d goldens; part 2 (res6_*): %d; part 3 (inl6_*): %d; '
          'part 4a (call-boundary tests): %d; part 4b (inlined tests): %d; %s'
          % (n1, n2, n3, n4a, n4b, 'checked' if CHECK else 'written'))


if __name__ == '__main__':
    main()
