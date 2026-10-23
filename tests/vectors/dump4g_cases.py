"""Sub-phase 4g-1 dump tests (DESIGN.md 6.2 "4g-1" dumps and changed goldens; 3.4.2 "`str`
constants" with lead decisions L-f and L-g; 3.5.9 "What sealoop rewrites in 4g": L16, L17 for `str`
elements, the `str` cases of L2, L4, L7, L9, L10 and L12 with R17, R20, R22 and R25; 3.6.6 rules
15, 16, 26, 30, 32, 33 and 35 and "Lowering of the sea.hirl records"; Decisions 44-47).

Run with `timeout 120 uv run --no-project python tests/vectors/dump4g_cases.py [--out DIR]`. It
writes, in tests/passes/ (or DIR), for every dump test NAME below: NAME.sea, .ast, .res, .hir1,
.hir, .hirl, .lir1 and .out (res_str_consts: .sea, .ast, .res, .hir1, .hir and .out); and the
changed `res_*` goldens of 6.2 (lead decision L-i), each re-derived from the spec:
res_noval_calltype, res_noval_shortcircuit and res_err_first_pos (an undeclared struct type `Q` in
place of `str` in the faulty signature: .sea, .ast, .res), res_err_str_param and
res_err_str_result (no rerr, the `str` types in rfn: .res), res_powk_skip (its `match` resolved:
.res, and its comment, which said the match was copied unresolved; its .ast is unchanged).

Sub-phase 4g-2 (DESIGN.md 6.2 "4g-2" dumps; 3.4.2 rtst/rtfd and rslit; 3.5.9 L15, L17's field
paths and aggregates, L6 with a field root, R17-R25; 3.6.6 rules 15 (g), 16, 18, 19, 26, 27, 29,
30, 31 and 38; lead decisions L-h, L-j, L-m, L-n) is the section "sub-phase 4g-2 (T2b)" below,
with its own description of the tests and of how each file is made; the same run writes its
files too (struct_rule18, struct_rule27, struct_rule29, struct_l17, struct_l17_path, struct_cow2,
str_ref_ln, str_fixed_self, struct_l6_field, struct_l12, rec_slay with every file; res_rt and
res_rtst with .sea, .ast, .res (res_rt also .out); the changed res_struct .sea and .res).

The tests of 4g-1 (one array operation per statement, no function called from exactly one call site,
3.6.6 "Phase-4 dump tests"):
* the agreed examples of 3.6.6 as whole programs, each appearing in the .lir1 with exactly its
  registers, blocks, labels and sites: str_rule15 (rule 15: `let s = a + b`, `let t = s`,
  `printf("%s\\n", a + b)` on lines 4-6, a and b the parameters p1 and p2), str_rule26 (rule 26:
  `let names = ["a", "bc"]` on line 1), str_rule30 (rule 30's first example, `for a in args() {`
  on line 3, which is also rule 35's `rcall sea_args`), str_rule32 (rule 32: `if a < b {` on line
  2), str_rule33 (rule 33: the `match` of `"x" | "y"` and `_`, a in p1, n a var in i2; the
  example's instructions carry no site, so its lines in the program do not show in it);
* the .hirl shapes of 6.2 without an agreed example: match_l16 (L16 with one-pattern arms, a
  `match` with only `_`, an owned scrutinee left by a `break`: R11, R22), str_l17 (L17 of a `str`
  element, `=` and `+=`: R17 (a) and (b)), str_fill_flat (L2's `filled` of a `str` matrix and
  L10's `.flat` of a `str[,]` with R20's element count and retain loop), str_ew (L7 with `bin cat`
  and a `str` comparison), str_l12 (L12 with an L17 target `names[i]`: R25's move of the `.l`
  local), and res_str_consts (3.4.2: an rcns with `+`, an rcns naming one, an annotated rcns, and
  rcnb from `str` comparisons, L-g; its .hir1 holds the `cs` leaves of the `cn` records and its
  .hir the `cs` that constant substitution puts in place of each `cref`).

How each file is made (never by running a pass; the passes of 4g-1 are written concurrently):
* `.ast`: pass 1 is unchanged in 4g-1 (8, row 4g-1 lists no seaparse work): the records seaparse
  writes for the source by 3.4, written by hand and checked against the source text by
  check_positions (a `match` at its keyword, an `arm` at its first pattern or `_`).
* `.res`: res_gen.py with the phase-rule steps 4e (dump4e_cases.res_gen4e's edits) and 4g-1
  (res_gen4g1 below: a `match` is a resolved region, a `str` parameter or result has its type, a
  fixed-size `str` type is 259 `strings` at its type node until 4g-2); res_gen.py itself evaluates
  the `str` constants (rcns, L-f, L-g). It cross-checks the lids and the constants against the
  .hir1.
* `.hir1`: by hand from 3.5.1-3.5.5 and the readings of 2.6.2 "Readings fixed by 4g" (`+` of two
  `str` is `bin cat`, the comparisons `bool`, `str(i64)` `lib str`, `args()` a `str[]`, a `match`
  with its `cs` patterns). `.hir` = `.hir1` except in res_str_consts (constant substitution,
  3.5.7 step 1).
* `.hirl`: from 3.5.9 with the helpers of dump4e_cases (Ctx, loop(N; K), L2, L4, make_hirl,
  number_locals) and the 4g-1 rewrites below (L16, L17, the `str` forms of L2, L7, L9, L10, L12),
  each written out record by record in the order its rule lists the statements.
* `.lir1`: by hand from 3.6.6, instruction by instruction, independently of the .hirl helpers,
  with the derivation in comments; registers symbolic, numbered by number_regs (3.6.1).
* `.out`: from LANGUAGE.md by hand (4.4: byte-wise comparison; 10.9: `str(i64)` decimal,
  `lower` ASCII; 7.6: the first equal pattern; 11.1: `%s`, `%d`).

The self-check at the end reads every written file back: the .hirl against include/passes.txt
(sets H HF HL) and 3.3, 3.5.4, 3.5.9 ("Types", "Locals", "What the passes validate" with the 4g
items: no `match`, `arm` or `proj`, no asg or tasg whose target L17 rewrites, R17's replacing and
moving stores, R20's counted mcpy, R22's block temporaries, R25's moves), the .lir1 against
passes.txt (set L) and the numbering of 3.6.1-3.6.4 and the rt.inc entries, a count cross-check of
the .hirl against the .lir1, and the agreed examples of rules 15, 26, 30, 32, 33 and 35 found
verbatim in both their golden and DESIGN.md.
"""

import os
import re
import sys
import types

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_PASSES = os.path.join(os.path.dirname(HERE), 'passes')


def _segment(src, start, stop):
    """The lines of src from the line that starts with `start` to the line before the one that
    starts with `stop`; each marker must occur exactly once."""
    lns = src.split('\n')
    a = [k for k, ln in enumerate(lns) if ln.startswith(start)]
    b = [k for k, ln in enumerate(lns) if ln.startswith(stop)]
    assert len(a) == 1 and len(b) == 1 and a[0] < b[0], (start, stop)
    return '\n' * a[0] + '\n'.join(lns[a[0]:b[0]]) + '\n'


# The shared helpers of dump4e_cases.py (the HIR node helpers, Ctx with loop(N; K), L1-L4,
# make_hirl, number_locals, number_regs, res_gen4e, check_positions, tree_check, type_order_check,
# the passes.txt, errors.inc and rt.inc loaders, parse_rec, split_file, check_lir1, design_example)
# and the 4f helpers of dump4f_cases.py (ifx, cvt, cs, lloop, fmt_rec, J) are executed here from
# their sources; their tests and their run sections are not.
_P4E = os.path.join(HERE, 'dump4e_cases.py')
with open(_P4E) as _fh:
    _SRC4E = _fh.read()
exec(compile(_segment(_SRC4E, 'import os', '# ================================================================ arr_rule20 '),
             _P4E, 'exec'))
exec(compile(_segment(_SRC4E, '# ================================================================ writing the files',
                      'def check_hirl('), _P4E, 'exec'))
exec(compile(_segment(_SRC4E, 'def check_lir1(', '# ================================================================ run'),
             _P4E, 'exec'))
_P4F = os.path.join(HERE, 'dump4f_cases.py')
with open(_P4F) as _fh:
    _SRC4F = _fh.read()
exec(compile(_segment(_SRC4F, "NAN = '#7FF8000000000000'", '# ================================================================ lib_rule23 '),
             _P4F, 'exec'))

# 4.8: the element size of a `str` element (a string object pointer, SEA_EK_STR) is 8
ES[5] = 8
assert ENTS['sea_str_cat'] == (True, 'pp', 'p') and ENTS['sea_str_cmp'] == (False, 'pp', 'i')
assert ENTS['sea_args'] == (True, '', 'p') and ENTS['sea_str_i64'] == (True, 'i', 'p')
assert ENTS['sea_str_lower'] == (True, 'p', 'p') and ENTS['sea_arr_new'] == (True, 'iiii', 'p')
assert ERRS['INDEX_OOB'] == 3


# ================================================================ res_gen with the steps 4e and 4g-1
def res_gen4g1(fixed_str=False):
    """res_gen.py (3.4.1/3.4.2) with the phase-rule steps 4e (the three edits of
    dump4e_cases.res_gen4e: fixed-size array types resolve) and 4g-1 of 2.6.2 and 3.4.2: a `match`
    is a resolved region like any other statement (3.4.2 "Skipped regions"); a `str` parameter or
    result type has its type wherever it stands, with no phase-rule error (3.4.2 "the phase rule";
    2.6.2 "Which program reports it": from 4g-1 only a fixed-size `str` type, at its `type` node,
    until 4g-2); a fixed-size type of `str` elements is 259 `strings` at its type node, found
    after every other error of the node. Each replaced text is asserted to occur exactly once."""
    path = os.path.join(HERE, 'res_gen.py')
    with open(path) as fh:
        src = fh.read()
    edits = [
        # step 4e (dump4e_cases.res_gen4e)
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
        # step 4g-1: a match is resolved
        ("""        if op == 'match':
            return                            # skipped region
""", ''),
        # step 4g-1: no `strings` at a str parameter or result
        ("""            if p.kids[0].f[1] == 'str':
                err(p.pos, 259, ['strings'])
""", ''),
        ("""            if tn.f[1] == 'str':
                err(tn.pos, 259, ['strings'])
            keys[id(tn)] = resolve_type(tn, [], False)
""", """            keys[id(tn)] = resolve_type(tn, [], False)
"""),
        # step 4g-1: a str type has its type everywhere; a fixed-size str type is `strings`
        ("""        if bt == 5 and not str_ok:
            return None                       # a str parameter (reported at its param node)
""", """        if bt == 5 and shape in ('fv', 'fm'):
            err(tn.pos, 259, ['strings'])
            return None
"""),
    ]
    if fixed_str:
        # step 4g-2 (2.6.2, 3.4.2 "the phase rule"): a fixed-size `str` type resolves too
        edits[-1] = (edits[-1][0], '')
    for old, new in edits:
        assert src.count(old) == 1, old
        src = src.replace(old, new)
    mod = types.ModuleType('res_gen4g1')
    mod.__file__ = path
    sys.path.insert(0, HERE)
    exec(compile(src, path, 'exec'), mod.__dict__)
    mod.PASSES = PASSES
    return mod


RG1 = res_gen4g1()


# ================================================================ positions in the .ast (3.3, 3.4)
KW4G = dict(KW)
KW4G.update({'match': 'match', 'cstmt': None, 'conv': None})


def check_positions4g(name, src, recs):
    """3.3 positions, as dump4e_cases.check_positions, with the records of 4g-1: a `match` at its
    keyword, an `arm` at its first pattern (`"`) or `_`, a `conv` at its type keyword (`str(`), an
    `int` written in the `#` encoding of 3.1 by its decimal value."""
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
        if op == 'arm':
            _, ln, col = (int(x) for x in pos.split(':'))
            assert src_lines[ln - 1][col - 1] in '"_', (name, r)
        elif op == 'conv':
            at(pos, p[2] + '(')
        elif op == 'int':
            v = int(p[2][1:], 16) if p[2].startswith('#') else int(p[2])
            at(pos, str(v))
        elif op in KW4G and KW4G[op] is not None:
            at(pos, KW4G[op])
        elif op in ('name', 'pname', 'type'):
            at(pos, p[2])
        elif op == 'param':
            at(pos, 'ref' if p[3] == '1' else p[2])
        elif op == 'fn':
            at(pos, 'fn')
        elif op == 'const':
            at(pos, 'const')
        elif op == 'float':
            assert src_lines[int(pos.split(':')[1]) - 1][int(pos.split(':')[2]) - 1].isdigit(), r
        elif op in ('call', 'index', 'bin', 'asg', 'cstmt', 'dot', 'row', 'range', 'pskip',
                    'ptuple', 'tasg'):
            c = src_lines[int(pos.split(':')[1]) - 1][int(pos.split(':')[2]) - 1]
            assert c != ' ', r
            if op in ('ptuple', 'tasg'):
                assert c == '(', r
            if op == 'pskip':
                assert c == '_', r
        if op == 'for':
            at(p[3], p[2])


def read_repo(fname):
    with open(os.path.join(REPO_PASSES, fname)) as fh:
        return fh.read()


# ================================================================ the changed res_* goldens (6.2, L-i)
# res_noval_calltype, res_noval_shortcircuit, res_err_first_pos: "keep their intent with an
# undeclared struct type Q in place of str in the faulty signature (fn f() -> Q, fn f(s: Q)):
# unknown struct type (229) at the type node, found by seaname in the signature as strings was;
# in res_err_first_pos the signature error then stands at the type node, still before the item
# error in source order" (6.2). Each .ast is written by hand (3.4); `Q` is one byte where `str`
# was three, so the positions after it on its line move left by 2.
RES_SEA, RES_AST = {}, {}
RES_SEA['res_noval_calltype'] = '''const A: f64 = f()
fn f() -> Q { return 1 }
// res_noval_calltype -- A calls a faulty f: rcn; rerr 229 unknown struct type at the result type Q (DESIGN.md 3.4.1, Decision 25 refined; 6.2 L-i)
'''
RES_AST['res_noval_calltype'] = '''
type 0:1:10 f64 s 0
name 0:1:16 f
call 0:1:16 0
const 0:1:1 A 1
type 0:2:11 Q s 0
int 0:2:22 1
return 0:2:15 1
block 0:2:13 1
fn 0:2:1 f 0 0 1
prog 2
'''
RES_SEA['res_noval_shortcircuit'] = '''const D = B || 9223372036854775807 + 1 > 0
const B: bool = false && f() == 1.0
fn f() -> Q { return 1 }
// res_noval_shortcircuit -- B holds a call of a faulty f behind false &&: rcn; D names B: rcn; rerr 229 unknown struct type (3.4.1, Decision 25 refined; 6.2 L-i)
'''
RES_AST['res_noval_shortcircuit'] = '''
name 0:1:11 B
int 0:1:16 #7FFFFFFFFFFFFFFF
int 0:1:38 1
bin 0:1:16 add
int 0:1:42 0
bin 0:1:16 gt
bin 0:1:11 or
const 0:1:1 D 0
type 0:2:10 bool s 0
false 0:2:17
name 0:2:26 f
call 0:2:26 0
float 0:2:33 #3FF0000000000000
bin 0:2:26 eq
bin 0:2:17 and
const 0:2:1 B 1
type 0:3:11 Q s 0
int 0:3:22 1
return 0:3:15 1
block 0:3:13 1
fn 0:3:1 f 0 0 1
prog 3
'''
RES_SEA['res_err_first_pos'] = '''// res_err_first_pos -- two seaname errors: the item error (6:1) is found first, the signature
// error (3:9, the unknown struct type Q) comes first in source order and is the rerr (3.4.1)
fn f(s: Q) {
    printf("x\\n")
}
fn f() {
    printf("y\\n")
}
'''
RES_AST['res_err_first_pos'] = '''
type 0:3:9 Q s 0
param 0:3:6 s 0 0
name 0:4:5 printf
str 0:4:12 x%0A
call 0:4:5 1
cstmt 0:4:5
block 0:3:12 1
fn 0:3:1 f 0 1 0
name 0:7:5 printf
str 0:7:12 y%0A
call 0:7:5 1
cstmt 0:7:5
block 0:6:8 1
fn 0:6:1 f 0 0 0
prog 2
'''
# res_err_str_param, res_err_str_result and res_powk_skip keep their programs (their .ast is
# asserted unchanged); only the comment lines that described the 4d result are rewritten, on the
# same lines, so that no position moves.
RES_COMMENT = {
    'res_err_str_param': (
        ['// res_err_str_param -- rerr 259 strings at a str parameter (its param node); its type in rfn',
         '// is 0 (DESIGN.md 3.4.1, 2.6.2)'],
        ['// res_err_str_param -- from 4g-1 a str parameter has its type: no rerr, the rtype and its slot',
         '// in rfn are 5 (DESIGN.md 3.4.2, 2.6.2; 6.2 L-i: re-derived)']),
    'res_err_str_result': (
        ['// res_err_str_result -- rerr 259 strings at a str result type (its type node); rty 0 and no',
         '// rtup (DESIGN.md 3.4.1, 2.6.2)'],
        ['// res_err_str_result -- from 4g-1 a str result type has its type: no rerr; rty the rtup 10',
         '// of (i64, str) (DESIGN.md 3.4.2, 2.6.2; 6.2 L-i: re-derived)']),
    'res_powk_skip': (
        ['// not-entered fn and a match copied unresolved, a for over an array resolved (3.4.1, 3.4.2)'],
        ['// not-entered fn copied unresolved; a match and a for over an array resolved (3.4.1, 3.4.2)']),
}


def write_changed_res():
    for nm in ('res_noval_calltype', 'res_noval_shortcircuit', 'res_err_first_pos'):
        src = RES_SEA[nm]
        ast = lines(RES_AST[nm])
        check_positions4g(nm, src, ast)
        write(nm + '.sea', src)
        write(nm + '.ast', dump(nm, '\n'.join(ast)))
        RG1.make(nm)
    for nm, (old, new) in RES_COMMENT.items():
        src = read_repo(nm + '.sea')
        o, n = '\n'.join(old) + '\n', '\n'.join(new) + '\n'
        if o in src:
            src = src.replace(o, n)
        assert n in src, (nm, 'comment')
        write(nm + '.sea', src)
        ast = read_repo(nm + '.ast')
        write(nm + '.ast', ast)
        RG1.make(nm)
        assert read(nm + '.ast') == ast, (nm, '.ast changes with its comment only')




# ================================================================ writing the dump tests
HIR = {}          # NAME -> sea.hir when it differs from sea.hir1 (res_str_consts only)
NAMES4G = []      # the dump tests with a .hirl and a .lir1
CONSTS4G = []     # the tests without (res_str_consts)


def write_test4g(nm):
    """Writes NAME.sea/.ast/.hir1/.hir (+ .hirl/.lir1/.out) and the .res through RG1, with the
    checks of dump4e_cases.write_test: positions (3.3), the tree against passes.txt (3.3), the
    type numbering (3.5.1), every function reachable (3.5.7 step 5: .hir keeps them all), and,
    where .hir = .hir1, no cref or cn and no subtree that 3.5.7 step 2 folds."""
    src = SEA[nm]
    ast = lines(AST[nm])
    check_positions4g(nm, src, ast)
    hir1 = HIR1[nm]
    recs = lines(hir1)
    tree_check(nm, recs, 'H H1'.split())
    type_order_check(nm, recs)
    hir = HIR.get(nm, hir1)
    hrecs = lines(hir)
    tree_check(nm, hrecs, 'H HF'.split())
    type_order_check(nm, hrecs)
    if nm not in HIR:
        for k, ln in enumerate(recs):
            op = ln.split(' ')[0]
            assert op not in ('cref', 'cn'), (nm, ln)
            prev = [recs[k - j].split(' ')[0] for j in (1, 2)]
            if op in ('cvt', 'un', 'powk') and prev[0] in ('ci', 'cf'):
                raise AssertionError((nm, 'foldable', ln))
            if op == 'bin' and ln.split(' ')[3] in ('add', 'sub', 'mul', 'div') and \
                    prev[0] in ('ci', 'cf') and prev[1] in ('ci', 'cf'):
                raise AssertionError((nm, 'foldable', ln))
    fids = {int(ln.split(' ')[1]) for ln in recs if ln.startswith('fn ')}
    called = {1} | {int(ln.split(' ')[3]) for ln in recs if ln.startswith('call ')}
    assert fids == called, (nm, 'unreachable function', fids, called)
    for f in fids - {1}:
        ncall = sum(1 for ln in recs if ln.startswith('call ') and int(ln.split(' ')[3]) == f)
        assert ncall >= 2, (nm, 'a function called from one call site (3.6.6: no inlining '
                                'before phase 6)', f)
    write(nm + '.sea', src)
    write(nm + '.ast', dump(nm, '\n'.join(ast)))
    write(nm + '.hir1', dump(nm, hir1))
    write(nm + '.hir', dump(nm, hir))
    if nm in HIRL:
        write(nm + '.hirl', dump(nm, HIRL[nm]()))
        write(nm + '.lir1', dump(nm, number_regs(LIR1[nm])))
    write(nm + '.out', OUT[nm])
    RG1.make(nm)


def same_hirl(nm):
    """3.5.9 "Unchanged functions": a file without a rewritten construct is sea.hir byte for byte."""
    return lambda: HIR.get(nm, HIR1[nm])


# ================================================================ res_str_consts (3.4.2, L-g)
SEA['res_str_consts'] = '''// res_str_consts -- DESIGN.md 3.4.2: rcns of + (A), naming another (B), annotated (T); rcnb of
// str comparisons (L-g: a proper prefix is the smaller; bytes compare unsigned, 0xC3 > z)
const A = "ab" + "c"
const B = A + "%"
const T: str = "x"
const L = A < B
const U = "\\xC3\\xA9" > "z"
printf("%s %s %s\\n", A, B, T)
if L && U {
    printf("lt\\n")
}
'''
AST['res_str_consts'] = '''
str 0:3:11 ab
str 0:3:18 c
bin 0:3:11 add
const 0:3:1 A 0
name 0:4:11 A
str 0:4:15 %25
bin 0:4:11 add
const 0:4:1 B 0
type 0:5:10 str s 0
str 0:5:16 x
const 0:5:1 T 1
name 0:6:11 A
name 0:6:15 B
bin 0:6:11 lt
const 0:6:1 L 0
str 0:7:11 %C3%A9
str 0:7:24 z
bin 0:7:11 gt
const 0:7:1 U 0
name 0:8:1 printf
str 0:8:8 %25s%20%25s%20%25s%0A
name 0:8:22 A
name 0:8:25 B
name 0:8:28 T
call 0:8:1 4
cstmt 0:8:1
name 0:9:4 L
name 0:9:9 U
bin 0:9:4 and
name 0:10:5 printf
str 0:10:12 lt%0A
call 0:10:5 1
cstmt 0:10:5
block 0:9:11 1
if 0:9:1 0
prog 7
'''
# sea.hir1 (3.5.2): one cn per constant, each preceded by its value as one leaf at the position
# of its expression's root: A "abc" (the bin at 0:3:11), B "abc%" (0:4:11), T "x" (the literal,
# 0:5:16), L true ("abc" is a proper prefix of "abc%", L-g), U true (0xC3 > 0x7A, unsigned). No
# type above 9 is referred to, so there is no type table. Each use is a cref of its type.
HIR1['res_str_consts'] = '''
cs 0:3:11 5 abc
cn 1 A 5 0:3:1
cs 0:4:11 5 abc%25
cn 2 B 5 0:4:1
cs 0:5:16 5 x
cn 3 T 5 0:5:1
cb 0:6:11 2 1
cn 4 L 2 0:6:1
cb 0:7:11 2 1
cn 5 U 2 0:7:1
fn 1 .main main 1 0 0 0:1:1
cref 0:8:22 5 1
fconv 0:8:8 1 - - - s
ftext 0:8:8 1 %20
cref 0:8:25 5 2
fconv 0:8:8 1 - - - s
ftext 0:8:8 1 %20
cref 0:8:28 5 3
fconv 0:8:8 1 - - - s
ftext 0:8:8 1 %0A
fmt 0:8:8 1 6
lib 0:8:1 1 printf 1
eval 0:8:1
cref 0:9:4 2 4
cref 0:9:9 2 5
bin 0:9:4 2 and
ftext 0:10:12 1 lt%0A
fmt 0:10:12 1 1
lib 0:10:5 1 printf 1
eval 0:10:5
block 0:9:11 1
if 0:9:1 0
block 0:1:1 2
end
'''
# sea.hir (3.5.7): step 1 puts a copy of each constant's leaf at the position of its cref and
# drops the cn records; step 2 folds no comparison or logic, so `true && true` stays a bin and.
HIR['res_str_consts'] = '''
fn 1 .main main 1 0 0 0:1:1
cs 0:8:22 5 abc
fconv 0:8:8 1 - - - s
ftext 0:8:8 1 %20
cs 0:8:25 5 abc%25
fconv 0:8:8 1 - - - s
ftext 0:8:8 1 %20
cs 0:8:28 5 x
fconv 0:8:8 1 - - - s
ftext 0:8:8 1 %0A
fmt 0:8:8 1 6
lib 0:8:1 1 printf 1
eval 0:8:1
cb 0:9:4 2 1
cb 0:9:9 2 1
bin 0:9:4 2 and
ftext 0:10:12 1 lt%0A
fmt 0:10:12 1 1
lib 0:10:5 1 printf 1
eval 0:10:5
block 0:9:11 1
if 0:9:1 0
block 0:1:1 2
end
'''
OUT['res_str_consts'] = 'abc abc% x\nlt\n'
CONSTS4G.append('res_str_consts')


# ================================================================ str_rule15 (rule 15)
SEA['str_rule15'] = '''// str_rule15 -- DESIGN.md 3.6.6 rule 15 (owned and borrowed reference values): its example on
// lines 4-6, a and b the parameters p1 and p2 of show (line 3)
fn show(a: str, b: str) {
    let s = a + b
    let t = s
    printf("%s\\n", a + b)
    printf("%s %s\\n", s, t)
}
let x = str(12)
let y = str(7)
show(x, y)
show(y, x)
'''
AST['str_rule15'] = '''
type 0:3:12 str s 0
param 0:3:9 a 0 0
type 0:3:20 str s 0
param 0:3:17 b 0 0
pname 0:4:9 s
name 0:4:13 a
name 0:4:17 b
bin 0:4:13 add
let 0:4:5 0
pname 0:5:9 t
name 0:5:13 s
let 0:5:5 0
name 0:6:5 printf
str 0:6:12 %25s%0A
name 0:6:20 a
name 0:6:24 b
bin 0:6:20 add
call 0:6:5 2
cstmt 0:6:5
name 0:7:5 printf
str 0:7:12 %25s%20%25s%0A
name 0:7:23 s
name 0:7:26 t
call 0:7:5 3
cstmt 0:7:5
block 0:3:25 4
fn 0:3:1 show 0 2 0
pname 0:9:5 x
int 0:9:13 12
conv 0:9:9 str
let 0:9:1 0
pname 0:10:5 y
int 0:10:13 7
conv 0:10:9 str
let 0:10:1 0
name 0:11:1 show
name 0:11:6 x
name 0:11:9 y
call 0:11:1 2
cstmt 0:11:1
name 0:12:1 show
name 0:12:6 y
name 0:12:9 x
call 0:12:1 2
cstmt 0:12:1
prog 5
'''
# sea.hir1: `+` of two str is bin cat of type str (2.6.2 "Readings fixed by 4g"); str(i64) is
# lib str at the conv's position (3.5.5); show is function 2 (two call sites, not inlined).
HIR1['str_rule15'] = '''
fn 1 .main main 1 0 2 0:1:1
loc x 5 let 0:9:5
loc y 5 let 0:10:5
ci 0:9:13 3 12
lib 0:9:9 5 str 1
bind 0:9:1 1
ci 0:10:13 3 7
lib 0:10:9 5 str 1
bind 0:10:1 2
lv 0:11:6 5 1
lv 0:11:9 5 2
call 0:11:1 1 2 2
eval 0:11:1
lv 0:12:6 5 2
lv 0:12:9 5 1
call 0:12:1 1 2 2
eval 0:12:1
block 0:1:1 4
end
fn 2 show fn 1 2 2 0:3:1
par a 5 val
par b 5 val
loc s 5 let 0:4:9
loc t 5 let 0:5:9
lv 0:4:13 5 1
lv 0:4:17 5 2
bin 0:4:13 5 cat
bind 0:4:5 3
lv 0:5:13 5 3
bind 0:5:5 4
lv 0:6:20 5 1
lv 0:6:24 5 2
bin 0:6:20 5 cat
fconv 0:6:12 1 - - - s
ftext 0:6:12 1 %0A
fmt 0:6:12 1 2
lib 0:6:5 1 printf 1
eval 0:6:5
lv 0:7:23 5 3
fconv 0:7:12 1 - - - s
ftext 0:7:12 1 %20
lv 0:7:26 5 4
fconv 0:7:12 1 - - - s
ftext 0:7:12 1 %0A
fmt 0:7:12 1 4
lib 0:7:5 1 printf 1
eval 0:7:5
block 0:3:25 4
end
'''
# sea.hirl = sea.hir: bin cat of scalars and lib str are no construct sealoop rewrites.
HIRL['str_rule15'] = same_hirl('str_rule15')
# sea.lir1. .main has no data label, so the fmt of line 6 is d1 as the example has it: x and y
# are `rcall sea_str_i64` straight into their registers (rule 32, rule 2's destination: owned);
# the calls (rule 5, nr 0); x and y released at the end in reverse order (rule 16 (a)). show:
# rule 15's example exactly (line 4: the cat into s's register p3; line 5: `mov p4 p3`, borrowed,
# so `retain p4`; line 6: the cat a temporary p5, the printf slot s1 and `release p5` after the
# printf that consumes it); line 7 stores s and t (borrowed: the slot holds no count); t and s
# released in reverse order at the end of the body block, then `ret 0` (rules 16 (a), 6).
LIR1['str_rule15'] = J(
    'func .main main 0:1:1 0 0',
    'li i.c12 12', 'rcall sea_str_i64 0:9 1 p.x 1 i.c12',
    'li i.c7 7', 'rcall sea_str_i64 0:10 1 p.y 1 i.c7',
    'call show 0 2 p.x p.y', 'call show 0 2 p.y p.x',
    'release p.y', 'release p.x', 'ret 0', 'endfunc',
    'func show fn 0:3:1 2 p.a p.b 0', 'slot s1 8 8', 'slot s2 16 8',
    'rcall sea_str_cat 0:4 1 p.s 2 p.a p.b',
    'mov p.t p.s', 'retain p.t',
    'rcall sea_str_cat 0:6 1 p.c 2 p.a p.b',
    'sa p.S1 s1', 'stp p.c p.S1 - 0 0', 'la p.F1 d1', 'rcall sea_printf 0:6 0 2 p.F1 p.S1',
    'release p.c',
    'sa p.S2 s2', 'stp p.s p.S2 - 0 0', 'stp p.t p.S2 - 0 8', 'la p.F2 d2',
    'rcall sea_printf 0:7 0 2 p.F2 p.S2',
    'release p.t', 'release p.s', 'ret 0', 'endfunc',
    fmt_rec(1, ['fconv - - - s p', 'ftext %0A']),
    fmt_rec(2, ['fconv - - - s p', 'ftext %20', 'fconv - - - s p', 'ftext %0A']))
OUT['str_rule15'] = '127\n127 127\n712\n712 712\n'
NAMES4G.append('str_rule15')


# ================================================================ 4g-1 HIR helpers (3.5.9)
def cs_(P, v):
    """A `str` constant (3.5.5 `cs`), v its escaped field."""
    return N(['cs %s 5 %s' % (P, v)], 5)


def L9b_str(F, P, T, TP, pre, elems):
    """L9 (b) for one row of `str` elements (4g-1): `xblk P T 5` ... with `tmp R = ci n`, `tmp A =
    anew P T 0 1 (lv R)` (lowered with sea_arr_new whatever z, R21), `tmp D = data(A)`, then each
    element in source order `est 8 0 e (lv D) (ci k)` (an initializing store into a fresh address,
    R5: a borrowed element retained, R3: the constant index folded into the offset); value `lv
    A`. elems: the element nodes in source order."""
    x = Ctx(F, P, pre)
    st = [x.tmp('R', ci(P, len(elems))),
          x.tmp('A', anew(P, T, 0, [x.lvl('R')])),
          x.tmp('D', adat(P, TP, x.lvl('A')))]
    for k, e in enumerate(elems):
        st.append(est(P, 5, e, x.lvl('D'), ci(P, k)))
    return xblk(P, st, x.lvl('A'))


def hir_block(text):
    """The records of a block (or any subtree) of the .hir, kept unchanged in the .hirl."""
    return N(lines(text), None)


# ================================================================ str_rule26 (rule 26)
SEA['str_rule26'] = '''let names = ["a", "bc"]
for n in names {
    printf("%s\\n", n)
}
// str_rule26 -- DESIGN.md 3.6.6 rule 26 (array literals): its example `let names = ["a", "bc"]`
// on line 1 (3.5.9 L9 (b) with str elements, R21's sea_arr_new); an element loop over it (L4 with
// X = eld str, rule 30: names borrowed, so held by mov and retain)
'''
AST['str_rule26'] = '''
pname 0:1:5 names
str 0:1:14 a
str 0:1:19 bc
row 0:1:14 2
array 0:1:13 1
let 0:1:1 0
name 0:2:10 names
name 0:3:5 printf
str 0:3:12 %25s%0A
name 0:3:20 n
call 0:3:5 2
cstmt 0:3:5
block 0:2:16 1
for 0:2:1 n 0:2:5
prog 2
'''
# sea.hir1: str[] 10 (`loc names`). A literal of str elements is dynamic whatever its size (6.9,
# Decision 20); its one row has the type of its horizontal join, which for str elements is the
# same dynamic str[] (the reading dump4e_cases takes for a row of 257 scalars: the row of a
# dynamic literal has the literal's dynamic vector type, so no fixed-size str type is named).
HIR1['str_rule26'] = '''
tvec 10 5
fn 1 .main main 1 0 2 0:1:1
loc names 10 let 0:1:5
loc n 5 for 0:2:5
cs 0:1:14 5 a
cs 0:1:19 5 bc
row 0:1:14 10 2
arr 0:1:13 10 1
bind 0:1:1 1
lv 0:2:10 10 1
lv 0:3:20 5 2
fconv 0:3:12 1 - - - s
ftext 0:3:12 1 %0A
fmt 0:3:12 1 2
lib 0:3:5 1 printf 1
eval 0:3:5
block 0:2:16 1
fore 0:2:1 2
block 0:1:1 2
end
'''


def hirl_str_rule26():
    """sea.hirl: tptr 11 5 (first referred to by the literal's adat). .main: the literal is L9 (b)
    (P its `[`, 0:1:13; the elements keep their positions); the fore is L4 (P 0:2:1) with X =
    `eld P str 8 0` (4g-1, rule 30) and the body block unchanged."""
    F = Fn()
    lit = L9b_str(F, '0:1:13', 10, 11, 'l', [cs_('0:1:14', 'a'), cs_('0:1:19', 'bc')])
    body = '''
lv 0:3:20 5 2
fconv 0:3:12 1 - - - s
ftext 0:3:12 1 %0A
fmt 0:3:12 1 2
lib 0:3:5 1 printf 1
eval 0:3:5
block 0:2:16 1
'''
    fore = L4(F, '0:2:1', 5, 11, 'f', 2, lv('0:2:10', 10, 1), body)
    eds = [(['cs 0:1:14 5 a', 'cs 0:1:19 5 bc', 'row 0:1:14 10 2', 'arr 0:1:13 10 1'], cat(lit)),
           (['lv 0:2:10 10 1'] + lines(body) + ['fore 0:2:1 2'], cat(fore))]
    return make_hirl(HIR1['str_rule26'], ['tptr 11 5'], {1: (F, eds)})


HIRL['str_rule26'] = hirl_str_rule26
# sea.lir1. Line 1 is rule 26's example exactly: `tmp R = ci 2` (`li i1 2`), the anew of a str[]
# (arrnew: `li K 4`, `li N 1`, `li C 1`, `rcall sea_arr_new`, R21) into names's register p5 (T3),
# data, and each element's `la` retained by its initializing store (`stp` at offsets 0 and 8,
# R3). Lines 2-4, rule 30 (second form): names is borrowed, so H is `mov`, `retain`; the extent,
# the loop, the element `ldp` into n (borrowed, never retained), the printf; H released at the end
# of L4's block, names at the end of .main (rule 16 (a)).
LIR1['str_rule26'] = J(
    'func .main main 0:1:1 0 0', 'slot s1 8 8',
    'li i.R 2', 'li i.ek 4', 'li i.rk 1', 'li i.C 1',
    'rcall sea_arr_new 0:1 1 p.names 4 i.ek i.rk i.R i.C',
    'ldp p.D p.names - 0 40',
    'la p.a d1', 'retain p.a', 'stp p.a p.D - 0 0',
    'la p.bc d2', 'retain p.bc', 'stp p.bc p.D - 0 8',
    'mov p.H p.names', 'retain p.H',
    'ldi i.N p.H - 0 16', 'li i.Z 0', 'icmp gt i.E i.N i.Z', 'if 1 i.E',
    'ldp p.DH p.H - 0 40', 'li i.O 1', 'isub i.L i.N i.O', 'loop 2 i.K i.Z i.L i.O',
    'ldp p.n p.DH i.K 8 0',
    'sa p.S s1', 'stp p.n p.S - 0 0', 'la p.F d3', 'rcall sea_printf 0:3 0 2 p.F p.S',
    'endloop 2', 'endif 1',
    'release p.H', 'release p.names', 'ret 0', 'endfunc',
    'str d1 a', 'str d2 bc',
    fmt_rec(3, ['fconv - - - s p', 'ftext %0A']))
OUT['str_rule26'] = 'a\nbc\n'
NAMES4G.append('str_rule26')


# ================================================================ str_rule30 (rules 30 and 35)
SEA['str_rule30'] = '''// str_rule30 -- DESIGN.md 3.6.6 rule 30 (element loops): its first example `for a in args() {`
// on line 3 (body empty), the held vector the owned result of rule 35's rcall sea_args
for a in args() { }
let k = len(args())
printf("%d\\n", k)
'''
AST['str_rule30'] = '''
name 0:3:10 args
call 0:3:10 0
block 0:3:17 0
for 0:3:1 a 0:3:5
pname 0:4:5 k
name 0:4:9 len
name 0:4:13 args
call 0:4:13 0
call 0:4:9 1
let 0:4:1 0
name 0:5:1 printf
str 0:5:8 %25d%0A
name 0:5:16 k
call 0:5:1 2
cstmt 0:5:1
prog 3
'''
# sea.hir1: args() is lib args of type str[] (10), no argument (LANGUAGE.md 10.10, 2.6.2).
HIR1['str_rule30'] = '''
tvec 10 5
fn 1 .main main 1 0 2 0:1:1
loc a 5 for 0:3:5
loc k 3 let 0:4:5
lib 0:3:10 10 args 0
block 0:3:17 0
fore 0:3:1 1
lib 0:4:13 10 args 0
lib 0:4:9 3 len 1
bind 0:4:1 2
lv 0:5:16 3 2
fconv 0:5:8 1 - - - d
ftext 0:5:8 1 %0A
fmt 0:5:8 1 2
lib 0:5:1 1 printf 1
eval 0:5:1
block 0:1:1 3
end
'''


def hirl_str_rule30():
    """sea.hirl: tptr 11 5 (L4's adat). The fore is L4 (P 0:3:1) over the lib args (kept: R10 does
    not concern it, 3.5.9 "What sealoop rewrites in 4g") with X = `eld P str 8 0`; len is L3, `ext
    0:4:9 3 0` of the second lib args."""
    F = Fn()
    fore = L4(F, '0:3:1', 5, 11, 'f', 1, lib('0:3:10', 10, 'args', []), 'block 0:3:17 0')
    eds = [(['lib 0:3:10 10 args 0', 'block 0:3:17 0', 'fore 0:3:1 1'], cat(fore)),
           (['lib 0:4:13 10 args 0', 'lib 0:4:9 3 len 1'],
            cat(L3('0:4:9', 0, lib('0:4:13', 10, 'args', []))))]
    return make_hirl(HIR1['str_rule30'], ['tptr 11 5'], {1: (F, eds)})


HIRL['str_rule30'] = hirl_str_rule30
# sea.lir1. Line 3 is rule 30's first example exactly: `rcall sea_args 0:3 1 p1 0` (rule 35; an
# owned value, so it is H with no instruction, rule 30 (1)), the extent, the loop, `ldp p9 p5 i8 8
# 0` into a (borrowed), and `release p1` after the construct. Line 4: rule 35 again, a temporary
# consumed by the ext (`ldi` into k's register, rule 2) and released right after it (rule 15 (k));
# line 5 the printf (rule 8).
LIR1['str_rule30'] = J(
    'func .main main 0:1:1 0 0', 'slot s1 8 8',
    'rcall sea_args 0:3 1 p.H 0',
    'ldi i.N p.H - 0 16', 'li i.Z 0', 'icmp gt i.E i.N i.Z', 'if 1 i.E',
    'ldp p.D p.H - 0 40', 'li i.O 1', 'isub i.L i.N i.O', 'loop 2 i.K i.Z i.L i.O',
    'ldp p.a p.D i.K 8 0', 'endloop 2', 'endif 1', 'release p.H',
    'rcall sea_args 0:4 1 p.A 0', 'ldi i.k p.A - 0 16', 'release p.A',
    'sa p.S s1', 'sti i.k p.S - 0 0', 'la p.F d1', 'rcall sea_printf 0:5 0 2 p.F p.S',
    'ret 0', 'endfunc',
    fmt_rec(1, ['fconv - - - d i', 'ftext %0A']))
OUT['str_rule30'] = '0\n'
NAMES4G.append('str_rule30')


def L16(F, P, pre, scrut, arms):
    """L16 (rule 33): `match S a1 ... an` at P: `block P 2` { `tmp S0 = S`; C(1) } where C(i), for a
    pattern arm with patterns p1 ... pk, is `if P 1` with cond_i, the arm's block and as its else
    part C(i + 1), and for the `_` arm its block; cond_i is `bin eq P bool (lv S0) (cs p1)` for k =
    1, and for k >= 2 `xblk P bool k` with `tmp Qj = bin eq P bool (lv S0) (cs pj)` and the value
    `bin bor P bool (... (bin bor (lv Q1) (lv Q2)) ...) (lv Qk)`. The patterns and the arm blocks
    keep their own positions (L-l). arms: [(pattern nodes, block node)], the last with no
    patterns (`_`); the Qj of arm i are named Q<i>_<j>."""
    x = Ctx(F, P, pre)
    s0 = x.tmp('S0', scrut)

    def C(i):
        pats, blk = arms[i]
        if not pats:
            return blk
        if len(pats) == 1:
            cond = bin_(P, 2, 'eq', x.lvl('S0'), pats[0])
        else:
            st = [x.tmp('Q%d_%d' % (i + 1, j + 1), bin_(P, 2, 'eq', x.lvl('S0'), p))
                  for j, p in enumerate(pats)]
            val = x.lvl('Q%d_1' % (i + 1))
            for j in range(1, len(pats)):
                val = bin_(P, 2, 'bor', val, x.lvl('Q%d_%d' % (i + 1, j + 1)))
            cond = xblk(P, st, val)
        return if_(P, cond, blk, C(i + 1))

    return block(P, [s0, C(0)])


# ================================================================ str_rule32 (rule 32)
SEA['str_rule32'] = '''fn less(a: str, b: str) {
    if a < b {
        printf("lt\\n")
    } else {
        printf("ge\\n")
    }
    printf("%s %d %s\\n", lower(a), len(a), str(a < b))
}
less("ab", "b")
less("b", "ab")
less("Ab", "a")
// str_rule32 -- DESIGN.md 3.6.6 rule 32 (strings): its example `if a < b {` on line 2, a and b the
// parameters p1 and p2; lower (an owned temporary), len (3.5.9 L3 of a str) and str of a bool
// (la of true and false, psel: borrowed) on line 7
'''
AST['str_rule32'] = '''
type 0:1:12 str s 0
param 0:1:9 a 0 0
type 0:1:20 str s 0
param 0:1:17 b 0 0
name 0:2:8 a
name 0:2:12 b
bin 0:2:8 lt
name 0:3:9 printf
str 0:3:16 lt%0A
call 0:3:9 1
cstmt 0:3:9
block 0:2:14 1
name 0:5:9 printf
str 0:5:16 ge%0A
call 0:5:9 1
cstmt 0:5:9
block 0:4:12 1
if 0:2:5 1
name 0:7:5 printf
str 0:7:12 %25s%20%25d%20%25s%0A
name 0:7:26 lower
name 0:7:32 a
call 0:7:26 1
name 0:7:36 len
name 0:7:40 a
call 0:7:36 1
name 0:7:48 a
name 0:7:52 b
bin 0:7:48 lt
conv 0:7:44 str
call 0:7:5 4
cstmt 0:7:5
block 0:1:25 2
fn 0:1:1 less 0 2 0
name 0:9:1 less
str 0:9:6 ab
str 0:9:12 b
call 0:9:1 2
cstmt 0:9:1
name 0:10:1 less
str 0:10:6 b
str 0:10:11 ab
call 0:10:1 2
cstmt 0:10:1
name 0:11:1 less
str 0:11:6 Ab
str 0:11:12 a
call 0:11:1 2
cstmt 0:11:1
prog 4
'''
# sea.hir1: `a < b` of two str is bin lt of type bool; lower(a) lib lower (str), len(a) lib len
# (i64), str(a < b) lib str of a bool at the conv's position (2.6.2 "Readings fixed by 4g").
HIR1['str_rule32'] = '''
fn 1 .main main 1 0 0 0:1:1
cs 0:9:6 5 ab
cs 0:9:12 5 b
call 0:9:1 1 2 2
eval 0:9:1
cs 0:10:6 5 b
cs 0:10:11 5 ab
call 0:10:1 1 2 2
eval 0:10:1
cs 0:11:6 5 Ab
cs 0:11:12 5 a
call 0:11:1 1 2 2
eval 0:11:1
block 0:1:1 3
end
fn 2 less fn 1 2 0 0:1:1
par a 5 val
par b 5 val
lv 0:2:8 5 1
lv 0:2:12 5 2
bin 0:2:8 2 lt
ftext 0:3:16 1 lt%0A
fmt 0:3:16 1 1
lib 0:3:9 1 printf 1
eval 0:3:9
block 0:2:14 1
ftext 0:5:16 1 ge%0A
fmt 0:5:16 1 1
lib 0:5:9 1 printf 1
eval 0:5:9
block 0:4:12 1
if 0:2:5 1
lv 0:7:32 5 1
lib 0:7:26 5 lower 1
fconv 0:7:12 1 - - - s
ftext 0:7:12 1 %20
lv 0:7:40 5 1
lib 0:7:36 3 len 1
fconv 0:7:12 1 - - - d
ftext 0:7:12 1 %20
lv 0:7:48 5 1
lv 0:7:52 5 2
bin 0:7:48 2 lt
lib 0:7:44 5 str 1
fconv 0:7:12 1 - - - s
ftext 0:7:12 1 %0A
fmt 0:7:12 1 6
lib 0:7:5 1 printf 1
eval 0:7:5
block 0:1:25 2
end
'''


def hirl_str_rule32():
    """sea.hirl: only len(a) is rewritten, L3 of a str (4g-1): `ext 0:7:36 3 0` of `lv a`; lower and
    str stay lib nodes (3.5.9 "What sealoop rewrites in 4g"). No tptr, no .l local."""
    eds = [(['lv 0:7:40 5 1', 'lib 0:7:36 3 len 1'], cat(L3('0:7:36', 0, lv('0:7:40', 5, 1))))]
    return make_hirl(HIR1['str_rule32'], [], {2: (Fn(), eds)})


HIRL['str_rule32'] = hirl_str_rule32
# sea.lir1. .main: each str literal argument a `la` (rule 7, borrowed; labels d1-d6 in order of
# reference), the calls (rule 5). less: line 2 is rule 32's example exactly (`rcall sea_str_cmp -
# 1 i3 2 p1 p2`, `li i4 0`, `icmp lt i5 i3 i4`, `if 1 i5`); the two printf calls of no conversion
# (an 8-byte slot each, rule 8). Line 7, the arguments left to right: lower(a) `rcall
# sea_str_lower` (owned, a temporary), len(a) `ldi D a - 0 16` (rule 32), str(a < b) the
# comparison then `la T d9` (true), `la F d10` (false), `psel` (borrowed); the 24-byte slot, the
# stores by class, the printf, then `release` of lower's result (rule 15 (b)).
LIR1['str_rule32'] = J(
    'func .main main 0:1:1 0 0',
    'la p.a1 d1', 'la p.b1 d2', 'call less 0 2 p.a1 p.b1',
    'la p.a2 d3', 'la p.b2 d4', 'call less 0 2 p.a2 p.b2',
    'la p.a3 d5', 'la p.b3 d6', 'call less 0 2 p.a3 p.b3',
    'ret 0', 'endfunc',
    'func less fn 0:1:1 2 p.a p.b 0', 'slot s1 8 8', 'slot s2 8 8', 'slot s3 24 8',
    'rcall sea_str_cmp - 1 i.C 2 p.a p.b', 'li i.Z 0', 'icmp lt i.L i.C i.Z', 'if 1 i.L',
    'sa p.S1 s1', 'la p.F1 d7', 'rcall sea_printf 0:3 0 2 p.F1 p.S1',
    'else 1',
    'sa p.S2 s2', 'la p.F2 d8', 'rcall sea_printf 0:5 0 2 p.F2 p.S2',
    'endif 1',
    'rcall sea_str_lower 0:7 1 p.low 1 p.a',
    'ldi i.len p.a - 0 16',
    'rcall sea_str_cmp - 1 i.C2 2 p.a p.b', 'li i.Z2 0', 'icmp lt i.L2 i.C2 i.Z2',
    'la p.T d9', 'la p.Fa d10', 'psel p.bs i.L2 p.T p.Fa',
    'sa p.S3 s3', 'stp p.low p.S3 - 0 0', 'sti i.len p.S3 - 0 8', 'stp p.bs p.S3 - 0 16',
    'la p.F3 d11', 'rcall sea_printf 0:7 0 2 p.F3 p.S3',
    'release p.low', 'ret 0', 'endfunc',
    'str d1 ab', 'str d2 b', 'str d3 b', 'str d4 ab', 'str d5 Ab', 'str d6 a',
    fmt_rec(7, ['ftext lt%0A']), fmt_rec(8, ['ftext ge%0A']),
    'str d9 true', 'str d10 false',
    fmt_rec(11, ['fconv - - - s p', 'ftext %20', 'fconv - - - d i', 'ftext %20',
                 'fconv - - - s p', 'ftext %0A']))
# "ab" < "b" (0x61 < 0x62): lt; "b" < "ab" no: ge; "Ab" < "a" (0x41 < 0x61): lt (LANGUAGE.md 4.4).
# lower("Ab") = "ab" (ASCII, 10.9).
OUT['str_rule32'] = 'lt\nab 2 true\nge\nb 1 false\nlt\nab 2 true\n'
NAMES4G.append('str_rule32')


# ================================================================ str_rule33 (rule 33, L16)
SEA['str_rule33'] = '''fn pick(a: str) {
    var n = 0
    match a {
        "x" | "y" => { n = 1 }
        _ => { n = 2 }
    }
    printf("%d\\n", n)
}
fn drive() {
    pick("x")
    pick("y")
    pick("z")
}
drive()
drive()
// str_rule33 -- DESIGN.md 3.6.6 rule 33 (match): its example (the match of lines 3-6, a in p1, n
// a var in i2; the example's instructions carry no site), 3.5.9 L16 with a two-pattern arm; drive
// comes after pick so that the patterns are the labels d1 and d2
'''
AST['str_rule33'] = '''
type 0:1:12 str s 0
param 0:1:9 a 0 0
pname 0:2:9 n
int 0:2:13 0
var 0:2:5 0
name 0:3:11 a
str 0:4:9 x
str 0:4:15 y
name 0:4:24 n
int 0:4:28 1
asg 0:4:24 set
block 0:4:22 1
arm 0:4:9 2
name 0:5:16 n
int 0:5:20 2
asg 0:5:16 set
block 0:5:14 1
arm 0:5:9 0
match 0:3:5 2
name 0:7:5 printf
str 0:7:12 %25d%0A
name 0:7:20 n
call 0:7:5 2
cstmt 0:7:5
block 0:1:17 3
fn 0:1:1 pick 0 1 0
name 0:10:5 pick
str 0:10:10 x
call 0:10:5 1
cstmt 0:10:5
name 0:11:5 pick
str 0:11:10 y
call 0:11:5 1
cstmt 0:11:5
name 0:12:5 pick
str 0:12:10 z
call 0:12:5 1
cstmt 0:12:5
block 0:9:12 3
fn 0:9:1 drive 0 0 0
name 0:14:1 drive
call 0:14:1 0
cstmt 0:14:1
name 0:15:1 drive
call 0:15:1 0
cstmt 0:15:1
prog 4
'''
HIR1['str_rule33'] = '''
fn 1 .main main 1 0 0 0:1:1
call 0:14:1 1 3 0
eval 0:14:1
call 0:15:1 1 3 0
eval 0:15:1
block 0:1:1 2
end
fn 2 pick fn 1 1 1 0:1:1
par a 5 val
loc n 3 var 0:2:9
ci 0:2:13 3 0
bind 0:2:5 2
lv 0:3:11 5 1
cs 0:4:9 5 x
cs 0:4:15 5 y
lv 0:4:24 3 2
ci 0:4:28 3 1
asg 0:4:24 set
block 0:4:22 1
arm 0:4:9 2
lv 0:5:16 3 2
ci 0:5:20 3 2
asg 0:5:16 set
block 0:5:14 1
arm 0:5:9 0
match 0:3:5 2
lv 0:7:20 3 2
fconv 0:7:12 1 - - - d
ftext 0:7:12 1 %0A
fmt 0:7:12 1 2
lib 0:7:5 1 printf 1
eval 0:7:5
block 0:1:17 3
end
fn 3 drive fn 1 0 0 0:9:1
cs 0:10:10 5 x
call 0:10:5 1 2 1
eval 0:10:5
cs 0:11:10 5 y
call 0:11:5 1 2 1
eval 0:11:5
cs 0:12:10 5 z
call 0:12:5 1 2 1
eval 0:12:5
block 0:9:12 3
end
'''


def hirl_str_rule33():
    """sea.hirl: the match of pick is L16 (P 0:3:5): `tmp S0 = lv a`, then `if P 1` whose condition
    is the xblk of `tmp Q1 = bin eq (lv S0) (cs x)`, `tmp Q2 = ... (cs y)` and `bin bor (lv Q1)
    (lv Q2)`, the first arm's block, and as its else part the `_` arm's block. No tptr."""
    F = Fn()
    P = '0:3:5'
    arm1 = hir_block('''
lv 0:4:24 3 2
ci 0:4:28 3 1
asg 0:4:24 set
block 0:4:22 1
''')
    arm2 = hir_block('''
lv 0:5:16 3 2
ci 0:5:20 3 2
asg 0:5:16 set
block 0:5:14 1
''')
    m = L16(F, P, 'm', lv('0:3:11', 5, 1),
            [([cs_('0:4:9', 'x'), cs_('0:4:15', 'y')], arm1), ([], arm2)])
    old = ['lv 0:3:11 5 1', 'cs 0:4:9 5 x', 'cs 0:4:15 5 y'] + arm1[0] + ['arm 0:4:9 2'] + \
        arm2[0] + ['arm 0:5:9 0', 'match 0:3:5 2']
    return make_hirl(HIR1['str_rule33'], [], {2: (F, [(old, cat(m))])})


HIRL['str_rule33'] = hirl_str_rule33
# sea.lir1. .main: the two calls. pick: `var n = 0` (`li i2 0`), then rule 33's example exactly:
# S0 is T1's alias of a (p1, no instruction); each pattern `la` then sea_str_cmp, `li 0`, `icmp
# eq` into its Q's register; `ior` of the two into a new register (the condition of the if: no
# destination); `if 1`, `li i2 1` (rule 2), `else 1`, `li i2 2`, `endif 1`. Then the printf of n.
# drive: the three literal arguments d4-d6 and calls.
LIR1['str_rule33'] = J(
    'func .main main 0:1:1 0 0', 'call drive 0 0', 'call drive 0 0', 'ret 0', 'endfunc',
    'func pick fn 0:1:1 1 p.a 0', 'slot s1 8 8',
    'li i.n 0',
    'la p.x d1', 'rcall sea_str_cmp - 1 i.C1 2 p.a p.x', 'li i.Z1 0', 'icmp eq i.Q1 i.C1 i.Z1',
    'la p.y d2', 'rcall sea_str_cmp - 1 i.C2 2 p.a p.y', 'li i.Z2 0', 'icmp eq i.Q2 i.C2 i.Z2',
    'ior i.Q i.Q1 i.Q2', 'if 1 i.Q', 'li i.n 1', 'else 1', 'li i.n 2', 'endif 1',
    'sa p.S s1', 'sti i.n p.S - 0 0', 'la p.F d3', 'rcall sea_printf 0:7 0 2 p.F p.S',
    'ret 0', 'endfunc',
    'func drive fn 0:9:1 0 0',
    'la p.s1 d4', 'call pick 0 1 p.s1', 'la p.s2 d5', 'call pick 0 1 p.s2',
    'la p.s3 d6', 'call pick 0 1 p.s3', 'ret 0', 'endfunc',
    'str d1 x', 'str d2 y', fmt_rec(3, ['fconv - - - d i', 'ftext %0A']),
    'str d4 x', 'str d5 y', 'str d6 z')
OUT['str_rule33'] = '1\n1\n2\n1\n1\n2\n'
NAMES4G.append('str_rule33')


# ================================================================ match_l16 (L16, R11, R22)
SEA['match_l16'] = '''fn tag(k: i64) -> str {
    return str(k)
}
fn scan(n: i64) {
    var i = 0
    while i < n {
        match tag(i) {
            "2" | "9" => { break }
            "0" => { printf("zero\\n") }
            _ => { printf("%d\\n", i) }
        }
        i += 1
    }
    match tag(n) {
        _ => { printf("end\\n") }
    }
}
scan(5)
scan(1)
// match_l16 -- DESIGN.md 3.5.9 L16: a two-pattern arm, a one-pattern arm and `_` (line 7), and a
// match with only `_` (line 14); each scrutinee is a call (owned), so it is a temporary of L16's
// block, released after the last endif (R11) and, by the break of line 8, before the exit (R22,
// rule 16 (b), (f))
'''
AST['match_l16'] = '''
type 0:1:11 i64 s 0
param 0:1:8 k 0 0
type 0:1:19 str s 0
name 0:2:16 k
conv 0:2:12 str
return 0:2:5 1
block 0:1:23 1
fn 0:1:1 tag 0 1 1
type 0:4:12 i64 s 0
param 0:4:9 n 0 0
pname 0:5:9 i
int 0:5:13 0
var 0:5:5 0
name 0:6:11 i
name 0:6:15 n
bin 0:6:11 lt
name 0:7:15 tag
name 0:7:19 i
call 0:7:15 1
str 0:8:13 2
str 0:8:19 9
break 0:8:28
block 0:8:26 1
arm 0:8:13 2
str 0:9:13 0
name 0:9:22 printf
str 0:9:29 zero%0A
call 0:9:22 1
cstmt 0:9:22
block 0:9:20 1
arm 0:9:13 1
name 0:10:20 printf
str 0:10:27 %25d%0A
name 0:10:35 i
call 0:10:20 2
cstmt 0:10:20
block 0:10:18 1
arm 0:10:13 0
match 0:7:9 3
name 0:12:9 i
int 0:12:14 1
asg 0:12:9 add
block 0:6:17 2
while 0:6:5
name 0:14:11 tag
name 0:14:15 n
call 0:14:11 1
name 0:15:16 printf
str 0:15:23 end%0A
call 0:15:16 1
cstmt 0:15:16
block 0:15:14 1
arm 0:15:9 0
match 0:14:5 1
block 0:4:17 3
fn 0:4:1 scan 0 1 0
name 0:18:1 scan
int 0:18:6 5
call 0:18:1 1
cstmt 0:18:1
name 0:19:1 scan
int 0:19:6 1
call 0:19:1 1
cstmt 0:19:1
prog 4
'''
# sea.hir1: tag is function 2 (result str, 5), scan function 3; the matches keep their cs
# patterns and arms (3.5.5, 2.6.2 "Readings fixed by 4g").
HIR1['match_l16'] = '''
fn 1 .main main 1 0 0 0:1:1
ci 0:18:6 3 5
call 0:18:1 1 3 1
eval 0:18:1
ci 0:19:6 3 1
call 0:19:1 1 3 1
eval 0:19:1
block 0:1:1 2
end
fn 2 tag fn 5 1 0 0:1:1
par k 3 val
lv 0:2:16 3 1
lib 0:2:12 5 str 1
ret 0:2:5 1
block 0:1:23 1
end
fn 3 scan fn 1 1 1 0:4:1
par n 3 val
loc i 3 var 0:5:9
ci 0:5:13 3 0
bind 0:5:5 2
lv 0:6:11 3 2
lv 0:6:15 3 1
bin 0:6:11 2 lt
lv 0:7:19 3 2
call 0:7:15 5 2 1
cs 0:8:13 5 2
cs 0:8:19 5 9
break 0:8:28
block 0:8:26 1
arm 0:8:13 2
cs 0:9:13 5 0
ftext 0:9:29 1 zero%0A
fmt 0:9:29 1 1
lib 0:9:22 1 printf 1
eval 0:9:22
block 0:9:20 1
arm 0:9:13 1
lv 0:10:35 3 2
fconv 0:10:27 1 - - - d
ftext 0:10:27 1 %0A
fmt 0:10:27 1 2
lib 0:10:20 1 printf 1
eval 0:10:20
block 0:10:18 1
arm 0:10:13 0
match 0:7:9 3
lv 0:12:9 3 2
ci 0:12:14 3 1
asg 0:12:9 add
block 0:6:17 2
while 0:6:5
lv 0:14:15 3 1
call 0:14:11 5 2 1
ftext 0:15:23 1 end%0A
fmt 0:15:23 1 1
lib 0:15:16 1 printf 1
eval 0:15:16
block 0:15:14 1
arm 0:15:9 0
match 0:14:5 1
block 0:4:17 3
end
'''


def hirl_match_l16():
    """sea.hirl of scan: the match of line 7 is L16 (P 0:7:9): `tmp S0 = call tag`, `if P 1` on the
    xblk of Q1 (`cs 2`), Q2 (`cs 9`) and their bor with the first arm's block, whose else part is
    `if P 1` on `bin eq (lv S0) (cs 0)` with the second arm's block and, as its else part, the `_`
    arm's block; the match of line 14 is `block 0:14:5 2` { `tmp S0 = call tag`; the `_` arm's
    block }. Locals .l1 (S0, str), .l2, .l3 (Q1, Q2, bool), .l4 (the second S0). No tptr."""
    F = Fn()
    a1 = hir_block('break 0:8:28\nblock 0:8:26 1')
    a2 = hir_block('''
ftext 0:9:29 1 zero%0A
fmt 0:9:29 1 1
lib 0:9:22 1 printf 1
eval 0:9:22
block 0:9:20 1
''')
    a3 = hir_block('''
lv 0:10:35 3 2
fconv 0:10:27 1 - - - d
ftext 0:10:27 1 %0A
fmt 0:10:27 1 2
lib 0:10:20 1 printf 1
eval 0:10:20
block 0:10:18 1
''')
    sc1 = N(['lv 0:7:19 3 2', 'call 0:7:15 5 2 1'], 5)
    m1 = L16(F, '0:7:9', 'm', sc1,
             [([cs_('0:8:13', '2'), cs_('0:8:19', '9')], a1), ([cs_('0:9:13', '0')], a2),
              ([], a3)])
    old1 = sc1[0] + ['cs 0:8:13 5 2', 'cs 0:8:19 5 9'] + a1[0] + ['arm 0:8:13 2',
                                                               'cs 0:9:13 5 0'] + a2[0] + \
        ['arm 0:9:13 1'] + a3[0] + ['arm 0:10:13 0', 'match 0:7:9 3']
    a4 = hir_block('''
ftext 0:15:23 1 end%0A
fmt 0:15:23 1 1
lib 0:15:16 1 printf 1
eval 0:15:16
block 0:15:14 1
''')
    sc2 = N(['lv 0:14:15 3 1', 'call 0:14:11 5 2 1'], 5)
    m2 = L16(F, '0:14:5', 'n', sc2, [([], a4)])
    old2 = sc2[0] + a4[0] + ['arm 0:15:9 0', 'match 0:14:5 1']
    return make_hirl(HIR1['match_l16'], [], {3: (F, [(old1, cat(m1)), (old2, cat(m2))])})


HIRL['match_l16'] = hirl_match_l16
# sea.lir1. .main: the two calls (rule 5). tag: str(k) `rcall sea_str_i64` (rule 32, owned),
# moved by the `ret` (rules 15 (a), 5; nothing after it, rule 6). scan: `var i = 0`; the while
# (rule 4: do 1, ifz 2, exit 1, endif 2). Line 7: S0 is the call's result register (owned: the
# block's temporary); the first arm's condition as in rule 33's example (`la`, sea_str_cmp, `li
# 0`, `icmp eq` for "2" and for "9", `ior`), `if 3`; its block is the break: the hidden local S0
# released, then `exit 1` (R22, rule 16 (b), (f)); `else 3`, the second arm's single comparison
# (`la` of "0") and `if 4`, the printf of "zero", `else 4`, the `_` arm's printf of i, `endif 4`,
# `endif 3`, then S0 released after the last endif (R11); `i += 1` (rule 4's checked add). Line
# 14: the call into S0 (block 2 of 3.5.9: no if), the printf, S0 released (R11); `ret 0`
# (rule 6). Labels in order of first `la`: d1 "2", d2 "9", d3 "0", d4-d6 the fmt records.
LIR1['match_l16'] = J(
    'func .main main 0:1:1 0 0',
    'li i.c5 5', 'call scan 0 1 i.c5', 'li i.c1 1', 'call scan 0 1 i.c1', 'ret 0', 'endfunc',
    'func tag fn 0:1:1 1 i.k 1 p',
    'rcall sea_str_i64 0:2 1 p.r 1 i.k', 'ret 1 p.r', 'endfunc',
    'func scan fn 0:4:1 1 i.n 0', 'slot s1 8 8', 'slot s2 8 8', 'slot s3 8 8',
    'li i.i 0',
    'do 1', 'icmp lt i.w i.i i.n', 'ifz 2 i.w', 'exit 1', 'endif 2',
    'call tag 1 p.S 1 i.i',
    'la p.p2 d1', 'rcall sea_str_cmp - 1 i.C1 2 p.S p.p2', 'li i.Z1 0',
    'icmp eq i.Q1 i.C1 i.Z1',
    'la p.p9 d2', 'rcall sea_str_cmp - 1 i.C2 2 p.S p.p9', 'li i.Z2 0',
    'icmp eq i.Q2 i.C2 i.Z2',
    'ior i.Q i.Q1 i.Q2', 'if 3 i.Q',
    'release p.S', 'exit 1',
    'else 3',
    'la p.p0 d3', 'rcall sea_str_cmp - 1 i.C3 2 p.S p.p0', 'li i.Z3 0',
    'icmp eq i.E i.C3 i.Z3', 'if 4 i.E',
    'sa p.S1 s1', 'la p.F1 d4', 'rcall sea_printf 0:9 0 2 p.F1 p.S1',
    'else 4',
    'sa p.S2 s2', 'sti i.i p.S2 - 0 0', 'la p.F2 d5', 'rcall sea_printf 0:10 0 2 p.F2 p.S2',
    'endif 4', 'endif 3', 'release p.S',
    'li i.one 1', 'iaddc i.i i.i i.one 0:12', 'enddo 1',
    'call tag 1 p.T 1 i.n',
    'sa p.S3 s3', 'la p.F3 d6', 'rcall sea_printf 0:15 0 2 p.F3 p.S3',
    'release p.T', 'ret 0', 'endfunc',
    'str d1 2', 'str d2 9', 'str d3 0',
    fmt_rec(4, ['ftext zero%0A']), fmt_rec(5, ['fconv - - - d i', 'ftext %0A']),
    fmt_rec(6, ['ftext end%0A']))
# scan(5): "0" zero, "1" the `_` arm, "2" the first arm's break; then tag(5) "end". scan(1): zero,
# the loop ends at i = 1, end (LANGUAGE.md 7.6: the first arm with an equal pattern).
OUT['match_l16'] = 'zero\n1\nend\nzero\nend\n'
NAMES4G.append('match_l16')


def idx1(P, ty, base, i):
    """`idx P ty 1` of a vector base by one scalar index (3.5.5)."""
    return N(cat(base, i) + ['idx %s %d 1' % (P, ty)], ty)


def L17_str(F, P, pre, root, TP, index, value, read_pos=None):
    """L17 for a `str` element of a dynamic vector local `root` (an lv node) by one scalar index.
    op `set` (read_pos None): `block P 6` { `tmp V = value`; `tmp I = index`; `tmp X = ext P 3 0
    root`; `chkb P 0 (lv I) (lv X)`; `cow P root`; `est P 8 0 (lv V) (adat P TP root) (lv I)` }
    (steps 1, 3, 4, 5, 6; a local root needs no step 2). op `add` (`+=`, read_pos the target idx's
    position): `block P 6` { `tmp I = index`; `tmp R = xblk P str 2` { `tmp T = idx read_pos str 1
    root (lv I)`; `tmp V = value`; value `bin cat P str (lv T) (lv V)` (rule 32: `+` of two str is
    cat, 3.5.5) }; then steps 4, 5 and 6 storing `lv R` (R17 (b): moved)."""
    x = Ctx(F, P, pre)
    if read_pos is None:
        st = [x.tmp('V', value), x.tmp('I', index)]
        sv = 'V'
    else:
        st = [x.tmp('I', index)]
        rd = x.tmp('T', idx1(read_pos, 5, root, x.lvl('I')))
        vv = x.tmp('V', value)
        st.append(x.tmp('R', xblk(P, [rd, vv], bin_(P, 5, 'cat', x.lvl('T'), x.lvl('V')))))
        sv = 'R'
    st += [x.tmp('X', ext(P, 0, root)), chkb(P, 0, x.lvl('I'), x.lvl('X')), cow(P, root),
           est(P, 5, x.lvl(sv), adat(P, TP, root), x.lvl('I'))]
    return block(P, st)


# ================================================================ str_l17 (L17, R17)
SEA['str_l17'] = '''fn put(i: i64, s: str) {
    var names = ["p", "q", "r"]
    names[i] = s
    names[i] += "!"
    printf("%s %s %s\\n", names[0], names[1], names[2])
}
put(0, "a")
put(2, "b")
// str_l17 -- DESIGN.md 3.5.9 L17 of a str element by a scalar index: `=` (line 3: R17 (a), the
// borrowed parameter s retained at the replacing store) and `+=` (line 4: the read, the cat and
// R17 (b)'s moved store); the reads of line 5 are rule 18's ldp (borrowed)
'''
AST['str_l17'] = '''
type 0:1:11 i64 s 0
param 0:1:8 i 0 0
type 0:1:19 str s 0
param 0:1:16 s 0 0
pname 0:2:9 names
str 0:2:18 p
str 0:2:23 q
str 0:2:28 r
row 0:2:18 3
array 0:2:17 1
var 0:2:5 0
name 0:3:5 names
name 0:3:11 i
index 0:3:5 1
name 0:3:16 s
asg 0:3:5 set
name 0:4:5 names
name 0:4:11 i
index 0:4:5 1
str 0:4:17 !
asg 0:4:5 add
name 0:5:5 printf
str 0:5:12 %25s%20%25s%20%25s%0A
name 0:5:26 names
int 0:5:32 0
index 0:5:26 1
name 0:5:36 names
int 0:5:42 1
index 0:5:36 1
name 0:5:46 names
int 0:5:52 2
index 0:5:46 1
call 0:5:5 4
cstmt 0:5:5
block 0:1:24 4
fn 0:1:1 put 0 2 0
name 0:7:1 put
int 0:7:5 0
str 0:7:8 a
call 0:7:1 2
cstmt 0:7:1
name 0:8:1 put
int 0:8:5 2
str 0:8:8 b
call 0:8:1 2
cstmt 0:8:1
prog 3
'''
# sea.hir1: names a var str[] (10, the dynamic literal of str_rule26's reading); the element
# targets are idx of type str; `+=` stays `asg add` (2.6.2: `x += e` of a str element is `+`).
HIR1['str_l17'] = '''
tvec 10 5
fn 1 .main main 1 0 0 0:1:1
ci 0:7:5 3 0
cs 0:7:8 5 a
call 0:7:1 1 2 2
eval 0:7:1
ci 0:8:5 3 2
cs 0:8:8 5 b
call 0:8:1 1 2 2
eval 0:8:1
block 0:1:1 2
end
fn 2 put fn 1 2 1 0:1:1
par i 3 val
par s 5 val
loc names 10 var 0:2:9
cs 0:2:18 5 p
cs 0:2:23 5 q
cs 0:2:28 5 r
row 0:2:18 10 3
arr 0:2:17 10 1
bind 0:2:5 3
lv 0:3:5 10 3
lv 0:3:11 3 1
idx 0:3:5 5 1
lv 0:3:16 5 2
asg 0:3:5 set
lv 0:4:5 10 3
lv 0:4:11 3 1
idx 0:4:5 5 1
cs 0:4:17 5 !
asg 0:4:5 add
lv 0:5:26 10 3
ci 0:5:32 3 0
idx 0:5:26 5 1
fconv 0:5:12 1 - - - s
ftext 0:5:12 1 %20
lv 0:5:36 10 3
ci 0:5:42 3 1
idx 0:5:36 5 1
fconv 0:5:12 1 - - - s
ftext 0:5:12 1 %20
lv 0:5:46 10 3
ci 0:5:52 3 2
idx 0:5:46 5 1
fconv 0:5:12 1 - - - s
ftext 0:5:12 1 %0A
fmt 0:5:12 1 6
lib 0:5:5 1 printf 1
eval 0:5:5
block 0:1:24 4
end
'''


def hirl_str_l17():
    """sea.hirl of put: tptr 11 5; the literal L9 (b) (P 0:2:17); line 3 L17 `set` (P 0:3:5, the
    value `lv s` keeps its position); line 4 L17 `add` (P 0:4:5; the read idx at the target's
    position 0:4:5); the reads of line 5 stay idx (rule 18 lowers them)."""
    F = Fn()
    lit = L9b_str(F, '0:2:17', 10, 11, 'l', [cs_('0:2:18', 'p'), cs_('0:2:23', 'q'),
                                              cs_('0:2:28', 'r')])
    s3 = L17_str(F, '0:3:5', 'a', lv('0:3:5', 10, 3), 11, lv('0:3:11', 3, 1),
                 lv('0:3:16', 5, 2))
    s4 = L17_str(F, '0:4:5', 'b', lv('0:4:5', 10, 3), 11, lv('0:4:11', 3, 1),
                 cs_('0:4:17', '!'), read_pos='0:4:5')
    eds = [(['cs 0:2:18 5 p', 'cs 0:2:23 5 q', 'cs 0:2:28 5 r', 'row 0:2:18 10 3',
             'arr 0:2:17 10 1'], cat(lit)),
           (['lv 0:3:5 10 3', 'lv 0:3:11 3 1', 'idx 0:3:5 5 1', 'lv 0:3:16 5 2',
             'asg 0:3:5 set'], cat(s3)),
           (['lv 0:4:5 10 3', 'lv 0:4:11 3 1', 'idx 0:4:5 5 1', 'cs 0:4:17 5 !',
             'asg 0:4:5 add'], cat(s4))]
    return make_hirl(HIR1['str_l17'], ['tptr 11 5'], {2: (F, eds)})


HIRL['str_l17'] = hirl_str_l17
# sea.lir1. .main: the arguments (`li`, `la` d1/d2), the calls. put, line 2: rule 26 as in
# str_rule26 (sea_arr_new ek 4, R21; each `la` retained by its initializing store, R3's offsets
# 0, 8, 16) into names's register (T3). Line 3 (L17 set): V and I are the aliases p.s and i (T1);
# the check (`ldi` extent, `chkb` d 0), the cow (rule 19 (4): count, `icmp ne`, sea_arr_unique,
# `mov`), the adat `ldp` (R23: after the cow), then R17 (a): `retain` of the borrowed s right
# before `ldp O`, `stp`, `release O`. Line 4 (L17 add): I the alias; the read (rule 18: extent,
# chkb, data, `ldp` borrowed), the `la` of "!", the cat (rule 32, owned, the asg's line); the
# checks and cow again, the adat, and the moved store (R17 (b): no retain, R0 not released). Line
# 5: three rule-18 reads with constant indices (`li`), borrowed, stored into the 24-byte slot
# (rule 8); names released at the end (rule 16 (a)).
LIR1['str_l17'] = J(
    'func .main main 0:1:1 0 0',
    'li i.z 0', 'la p.a d1', 'call put 0 2 i.z p.a',
    'li i.t 2', 'la p.b d2', 'call put 0 2 i.t p.b', 'ret 0', 'endfunc',
    'func put fn 0:1:1 2 i.i p.s 0', 'slot s1 24 8',
    'li i.R 3', 'li i.ek 4', 'li i.rk 1', 'li i.C 1',
    'rcall sea_arr_new 0:2 1 p.names 4 i.ek i.rk i.R i.C',
    'ldp p.D p.names - 0 40',
    'la p.p d3', 'retain p.p', 'stp p.p p.D - 0 0',
    'la p.q d4', 'retain p.q', 'stp p.q p.D - 0 8',
    'la p.r d5', 'retain p.r', 'stp p.r p.D - 0 16',
    'ldi i.X1 p.names - 0 16', 'chkb i.i i.X1 0 0:3',
    'ldi i.n1 p.names - 0 0', 'li i.o1 1', 'icmp ne i.u1 i.n1 i.o1', 'if 1 i.u1',
    'rcall sea_arr_unique 0:3 1 p.U1 1 p.names', 'mov p.names p.U1', 'endif 1',
    'ldp p.D1 p.names - 0 40',
    'retain p.s', 'ldp p.O1 p.D1 i.i 8 0', 'stp p.s p.D1 i.i 8 0', 'release p.O1',
    'ldi i.X2 p.names - 0 16', 'chkb i.i i.X2 0 0:4', 'ldp p.DR p.names - 0 40',
    'ldp p.T0 p.DR i.i 8 0', 'la p.ex d6', 'rcall sea_str_cat 0:4 1 p.R0 2 p.T0 p.ex',
    'ldi i.X3 p.names - 0 16', 'chkb i.i i.X3 0 0:4',
    'ldi i.n2 p.names - 0 0', 'li i.o2 1', 'icmp ne i.u2 i.n2 i.o2', 'if 2 i.u2',
    'rcall sea_arr_unique 0:4 1 p.U2 1 p.names', 'mov p.names p.U2', 'endif 2',
    'ldp p.D2 p.names - 0 40',
    'ldp p.O2 p.D2 i.i 8 0', 'stp p.R0 p.D2 i.i 8 0', 'release p.O2',
    'li i.k0 0', 'ldi i.e0 p.names - 0 16', 'chkb i.k0 i.e0 0 0:5', 'ldp p.d0 p.names - 0 40',
    'ldp p.v0 p.d0 i.k0 8 0',
    'li i.k1 1', 'ldi i.e1 p.names - 0 16', 'chkb i.k1 i.e1 0 0:5', 'ldp p.d1 p.names - 0 40',
    'ldp p.v1 p.d1 i.k1 8 0',
    'li i.k2 2', 'ldi i.e2 p.names - 0 16', 'chkb i.k2 i.e2 0 0:5', 'ldp p.d2 p.names - 0 40',
    'ldp p.v2 p.d2 i.k2 8 0',
    'sa p.S s1', 'stp p.v0 p.S - 0 0', 'stp p.v1 p.S - 0 8', 'stp p.v2 p.S - 0 16',
    'la p.F d7', 'rcall sea_printf 0:5 0 2 p.F p.S',
    'release p.names', 'ret 0', 'endfunc',
    'str d1 a', 'str d2 b', 'str d3 p', 'str d4 q', 'str d5 r', 'str d6 !',
    fmt_rec(7, ['fconv - - - s p', 'ftext %20', 'fconv - - - s p', 'ftext %20',
                'fconv - - - s p', 'ftext %0A']))
# put(0, "a"): names[0] = "a", then "a" + "!" (LANGUAGE.md 4.4); put(2, "b") likewise at 2.
OUT['str_l17'] = 'a! q r\np q b!\n'
NAMES4G.append('str_l17')


# ================================================================ str_fill_flat (L2, L10, R20)
SEA['str_fill_flat'] = '''fn tile(s: str, r: i64) {
    let m = filled(s, r, 2)
    let f = m.flat
    printf("%d %s\\n", len(f), f[1])
}
tile("ab", 2)
tile("c", 1)
// str_fill_flat -- DESIGN.md 3.5.9 L2 of `filled` with a str value (line 2: the borrowed s
// retained before each store) and L10 of a dynamic `.flat` of a str[,] (line 3: R20's mcpy with
// the element count and the retain loop over the copied elements)
'''
AST['str_fill_flat'] = '''
type 0:1:12 str s 0
param 0:1:9 s 0 0
type 0:1:20 i64 s 0
param 0:1:17 r 0 0
pname 0:2:9 m
name 0:2:13 filled
name 0:2:20 s
name 0:2:23 r
int 0:2:26 2
call 0:2:13 3
let 0:2:5 0
pname 0:3:9 f
name 0:3:13 m
dot 0:3:13 flat
let 0:3:5 0
name 0:4:5 printf
str 0:4:12 %25d%20%25s%0A
name 0:4:23 len
name 0:4:27 f
call 0:4:23 1
name 0:4:31 f
int 0:4:33 1
index 0:4:31 1
call 0:4:5 3
cstmt 0:4:5
block 0:1:25 3
fn 0:1:1 tile 0 2 0
name 0:6:1 tile
str 0:6:6 ab
int 0:6:12 2
call 0:6:1 2
cstmt 0:6:1
name 0:7:1 tile
str 0:7:6 c
int 0:7:11 1
call 0:7:1 2
cstmt 0:7:1
prog 3
'''
# sea.hir1: str[,] 10 (`loc m`; filled with a str value and two extents, 2.6.2 "Strings
# elsewhere"), str[] 11 (`loc f`, the view .flat of a dynamic matrix).
HIR1['str_fill_flat'] = '''
tmat 10 5
tvec 11 5
fn 1 .main main 1 0 0 0:1:1
cs 0:6:6 5 ab
ci 0:6:12 3 2
call 0:6:1 1 2 2
eval 0:6:1
cs 0:7:6 5 c
ci 0:7:11 3 1
call 0:7:1 1 2 2
eval 0:7:1
block 0:1:1 2
end
fn 2 tile fn 1 2 2 0:1:1
par s 5 val
par r 3 val
loc m 10 let 0:2:9
loc f 11 let 0:3:9
lv 0:2:20 5 1
lv 0:2:23 3 2
ci 0:2:26 3 2
lib 0:2:13 10 filled 3
bind 0:2:5 3
lv 0:3:13 10 3
view 0:3:13 11 flat
bind 0:3:5 4
lv 0:4:27 11 4
lib 0:4:23 3 len 1
fconv 0:4:12 1 - - - d
ftext 0:4:12 1 %20
lv 0:4:31 11 4
ci 0:4:33 3 1
idx 0:4:31 5 1
fconv 0:4:12 1 - - - s
ftext 0:4:12 1 %0A
fmt 0:4:12 1 4
lib 0:4:5 1 printf 1
eval 0:4:5
block 0:1:25 3
end
'''


def hirl_str_fill_flat():
    """sea.hirl of tile: tptr 12 5 (first referred to by L2's adat). Line 2 is L2 (P 0:2:13; E str:
    `est 8 0 (lv V) (lv D) (lv K)`); line 3 is L10 of `.flat` (P 0:3:13) with R20: the mcpy's third
    child is the element count `lv N` (the type-3 expression of R20, so no byte-count NB); len(f)
    is L3; f[1] stays an idx."""
    F = Fn()
    l2 = L2(F, '0:2:13', 10, 5, 12, 'a', r=lv('0:2:23', 3, 2), c=ci('0:2:26', 2),
            v=lv('0:2:20', 5, 1))
    P = '0:3:13'
    x = Ctx(F, P, 'f')
    st = [x.tmp('A', lv('0:3:13', 10, 3)),
          x.tmp('R', ext(P, 0, x.lvl('A'))),
          x.tmp('C', ext(P, 1, x.lvl('A'))),
          x.tmp('N', wbin(P, 'mul', x.lvl('R'), x.lvl('C'))),
          x.tmp('V', anew(P, 11, 0, [x.lvl('N')])),
          x.tmp('D', adat(P, 12, x.lvl('V'))),
          x.tmp('S', adat(P, 12, x.lvl('A'))),
          mcpy(P, x.lvl('D'), x.lvl('S'), x.lvl('N'))]
    eds = [(['lv 0:2:20 5 1', 'lv 0:2:23 3 2', 'ci 0:2:26 3 2', 'lib 0:2:13 10 filled 3'],
            cat(l2)),
           (['lv 0:3:13 10 3', 'view 0:3:13 11 flat'], cat(xblk(P, st, x.lvl('V')))),
           (['lv 0:4:27 11 4', 'lib 0:4:23 3 len 1'], cat(L3('0:4:23', 0, lv('0:4:27', 11, 4))))]
    return make_hirl(HIR1['str_fill_flat'], ['tptr 12 5'], {2: (F, eds)})


HIRL['str_fill_flat'] = hirl_str_fill_flat
# sea.lir1. .main: the arguments and calls. tile, line 2 (L2): V and R the aliases p.s and r
# (T1), C `li 2`, the anew of a str[,] by sea_arr_new (ek 4, rank 2, R21: whatever z) into m's
# register (T3), N `imul` (wbin), D, loop(N; K) whose body is the initializing store of the
# borrowed V: `retain p.s` before each `stp` (the L2 row of 3.5.9's 4g table; no `ldp O`: a fresh
# address, R5). Line 3 (L10 .flat): the extents, N, the anew of a str[] (ek 4, rank 1, `li 1`)
# into f's register, the two data pointers, then R20: `li S 8`, `imul B N S`, `mcopy D S B`, and
# loop(N; K) { `ldp R D K 8 0`, `retain R` } on the destination. Line 4: len(f) the `ldi` (L3,
# rule 32), f[1] rule 18 (borrowed `ldp`); the 16-byte slot; f and m released in reverse order.
LIR1['str_fill_flat'] = J(
    'func .main main 0:1:1 0 0',
    'la p.a d1', 'li i.c2 2', 'call tile 0 2 p.a i.c2',
    'la p.b d2', 'li i.c1 1', 'call tile 0 2 p.b i.c1', 'ret 0', 'endfunc',
    'func tile fn 0:1:1 2 p.s i.r 0', 'slot s1 16 8',
    'li i.C 2', 'li i.ek 4', 'li i.rk 2', 'rcall sea_arr_new 0:2 1 p.m 4 i.ek i.rk i.r i.C',
    'imul i.N i.r i.C', 'ldp p.D p.m - 0 40',
    'li i.Z 0', 'icmp gt i.g i.N i.Z', 'if 1 i.g', 'li i.O 1', 'isub i.L i.N i.O',
    'loop 2 i.K i.Z i.L i.O', 'retain p.s', 'stp p.s p.D i.K 8 0', 'endloop 2', 'endif 1',
    'ldi i.R3 p.m - 0 16', 'ldi i.C3 p.m - 0 24', 'imul i.N3 i.R3 i.C3',
    'li i.ek3 4', 'li i.rk3 1', 'li i.one3 1',
    'rcall sea_arr_new 0:3 1 p.f 4 i.ek3 i.rk3 i.N3 i.one3',
    'ldp p.D3 p.f - 0 40', 'ldp p.S3 p.m - 0 40',
    'li i.sz 8', 'imul i.B i.N3 i.sz', 'mcopy p.D3 p.S3 i.B',
    'li i.Z3 0', 'icmp gt i.g3 i.N3 i.Z3', 'if 3 i.g3', 'li i.O3 1', 'isub i.L3 i.N3 i.O3',
    'loop 4 i.K3 i.Z3 i.L3 i.O3', 'ldp p.e p.D3 i.K3 8 0', 'retain p.e', 'endloop 4', 'endif 3',
    'ldi i.len p.f - 0 16',
    'li i.k 1', 'ldi i.x p.f - 0 16', 'chkb i.k i.x 0 0:4', 'ldp p.d p.f - 0 40',
    'ldp p.v p.d i.k 8 0',
    'sa p.S s1', 'sti i.len p.S - 0 0', 'stp p.v p.S - 0 8', 'la p.F d3',
    'rcall sea_printf 0:4 0 2 p.F p.S',
    'release p.f', 'release p.m', 'ret 0', 'endfunc',
    'str d1 ab', 'str d2 c',
    fmt_rec(3, ['fconv - - - d i', 'ftext %20', 'fconv - - - s p', 'ftext %0A']))
# tile("ab", 2): a 2 x 2 matrix of "ab", its .flat 4 elements (LANGUAGE.md 4.7), f[1] "ab";
# tile("c", 1): 1 x 2, 2 elements, f[1] "c".
OUT['str_fill_flat'] = '4 ab\n2 c\n'
NAMES4G.append('str_fill_flat')


def L7_vs(F, P, T, E, TPR, TPA, pre, a1, a2, op):
    """L7 of a `bin` of a dynamic `str[]` operand a1 and a scalar `str` operand a2 (4g-1, Decision
    45), result T (element type E, its tptr TPR; TPA the tptr of str): `xblk P T 8` with `tmp A1 =
    a1`, `tmp A2 = a2` (1); `tmp N1 = ext(A1, 0)` (2; one array operand, so no check); `tmp RES =
    anew P T 0 1 (lv N1)` (3); `tmp DR = data(RES)`, `tmp D1 = data(A1)` (5); loop(N1; I) { `est s
    0 F (lv DR) (lv I)` } with F = `bin op P E (eld P str 8 0 (lv D1) (lv I)) (lv A2)` (6); value
    `lv RES`."""
    x = Ctx(F, P, pre)
    st = [x.tmp('A1', a1), x.tmp('A2', a2), x.tmp('N1', ext(P, 0, x.lvl('A1'))),
          x.tmp('RES', anew(P, T, 0, [x.lvl('N1')])),
          x.tmp('DR', adat(P, TPR, x.lvl('RES'))),
          x.tmp('D1', adat(P, TPA, x.lvl('A1')))]
    st += x.loop('N1', 'Z', 'O', 'L', 'I',
                 lambda: [est(P, E, bin_(P, E, op, eld(P, 5, x.lvl('D1'), x.klv('I')),
                                         x.lvl('A2')), x.lvl('DR'), x.klv('I'))])
    return xblk(P, st, x.lvl('RES'))


# ================================================================ str_ew (L7 of str, Decision 45)
SEA['str_ew'] = '''fn ew(v: str[]) {
    let c = v + "!"
    let e = v == "b"
    printf("%s %s %s\\n", c[0], c[1], str(e[1]))
}
ew(["a", "b"])
ew(["b", "c", "d"])
// str_ew -- DESIGN.md 3.5.9 L7 with str operands (Decision 45): the element-wise cat of line 2
// (each element read borrowed by eld, the owned cat moved by the initializing est) and the
// element-wise comparison of line 3 (a bool[] by sea_str_cmp); the arguments are L9 (b) literals
'''
AST['str_ew'] = '''
type 0:1:10 str v 0
param 0:1:7 v 0 0
pname 0:2:9 c
name 0:2:13 v
str 0:2:17 !
bin 0:2:13 add
let 0:2:5 0
pname 0:3:9 e
name 0:3:13 v
str 0:3:18 b
bin 0:3:13 eq
let 0:3:5 0
name 0:4:5 printf
str 0:4:12 %25s%20%25s%20%25s%0A
name 0:4:26 c
int 0:4:28 0
index 0:4:26 1
name 0:4:32 c
int 0:4:34 1
index 0:4:32 1
name 0:4:42 e
int 0:4:44 1
index 0:4:42 1
conv 0:4:38 str
call 0:4:5 4
cstmt 0:4:5
block 0:1:17 3
fn 0:1:1 ew 0 1 0
name 0:6:1 ew
str 0:6:5 a
str 0:6:10 b
row 0:6:5 2
array 0:6:4 1
call 0:6:1 1
cstmt 0:6:1
name 0:7:1 ew
str 0:7:5 b
str 0:7:10 c
str 0:7:15 d
row 0:7:5 3
array 0:7:4 1
call 0:7:1 1
cstmt 0:7:1
prog 3
'''
# sea.hir1: str[] 10 (the literals of .main, first), bool[] 11 (`loc e`). v + "!" is bin cat of
# type str[] and v == "b" bin eq of type bool[] (2.6.2 "str operators": element-wise, dynamic).
HIR1['str_ew'] = '''
tvec 10 5
tvec 11 2
fn 1 .main main 1 0 0 0:1:1
cs 0:6:5 5 a
cs 0:6:10 5 b
row 0:6:5 10 2
arr 0:6:4 10 1
call 0:6:1 1 2 1
eval 0:6:1
cs 0:7:5 5 b
cs 0:7:10 5 c
cs 0:7:15 5 d
row 0:7:5 10 3
arr 0:7:4 10 1
call 0:7:1 1 2 1
eval 0:7:1
block 0:1:1 2
end
fn 2 ew fn 1 1 2 0:1:1
par v 10 val
loc c 10 let 0:2:9
loc e 11 let 0:3:9
lv 0:2:13 10 1
cs 0:2:17 5 !
bin 0:2:13 10 cat
bind 0:2:5 2
lv 0:3:13 10 1
cs 0:3:18 5 b
bin 0:3:13 11 eq
bind 0:3:5 3
lv 0:4:26 10 2
ci 0:4:28 3 0
idx 0:4:26 5 1
fconv 0:4:12 1 - - - s
ftext 0:4:12 1 %20
lv 0:4:32 10 2
ci 0:4:34 3 1
idx 0:4:32 5 1
fconv 0:4:12 1 - - - s
ftext 0:4:12 1 %20
lv 0:4:42 11 3
ci 0:4:44 3 1
idx 0:4:42 2 1
lib 0:4:38 5 str 1
fconv 0:4:12 1 - - - s
ftext 0:4:12 1 %0A
fmt 0:4:12 1 6
lib 0:4:5 1 printf 1
eval 0:4:5
block 0:1:17 3
end
'''


def hirl_str_ew():
    """sea.hirl: tptr 12 5 (the adat of .main's first literal), tptr 13 2 (line 3's result data).
    .main: each literal argument L9 (b). ew: line 2 L7 (P 0:2:13, F bin cat, est 8 0), line 3 L7
    (P 0:3:13, F bin eq of type bool, est 1 0); the reads of line 4 stay idx."""
    F1 = Fn()
    l1 = L9b_str(F1, '0:6:4', 10, 12, 'a', [cs_('0:6:5', 'a'), cs_('0:6:10', 'b')])
    l2 = L9b_str(F1, '0:7:4', 10, 12, 'b', [cs_('0:7:5', 'b'), cs_('0:7:10', 'c'),
                                            cs_('0:7:15', 'd')])
    e1 = [(['cs 0:6:5 5 a', 'cs 0:6:10 5 b', 'row 0:6:5 10 2', 'arr 0:6:4 10 1'], cat(l1)),
          (['cs 0:7:5 5 b', 'cs 0:7:10 5 c', 'cs 0:7:15 5 d', 'row 0:7:5 10 3',
            'arr 0:7:4 10 1'], cat(l2))]
    F2 = Fn()
    w2 = L7_vs(F2, '0:2:13', 10, 5, 12, 12, 'c', lv('0:2:13', 10, 1), cs_('0:2:17', '!'), 'cat')
    w3 = L7_vs(F2, '0:3:13', 11, 2, 13, 12, 'e', lv('0:3:13', 10, 1), cs_('0:3:18', 'b'), 'eq')
    e2 = [(['lv 0:2:13 10 1', 'cs 0:2:17 5 !', 'bin 0:2:13 10 cat'], cat(w2)),
          (['lv 0:3:13 10 1', 'cs 0:3:18 5 b', 'bin 0:3:13 11 eq'], cat(w3))]
    return make_hirl(HIR1['str_ew'], ['tptr 12 5', 'tptr 13 2'], {1: (F1, e1), 2: (F2, e2)})


HIRL['str_ew'] = hirl_str_ew
# sea.lir1. .main: each literal as rule 26 (sea_arr_new ek 4; each `la` retained by its store),
# the call, and the literal released right after the call that consumes it (an owned temporary,
# rule 15 (b)). ew, line 2: A1 the alias of v, A2 the `la` of "!" (borrowed), N1, the anew of a
# str[] into c's register (T3), the two data pointers, loop(N1; I) { `ldp` of the element
# (borrowed), `rcall sea_str_cat` (owned, the line of the bin), `stp` with no retain (moved by the
# initializing store, the L7 row of 3.5.9's 4g table) }. Line 3: the same with the anew of a bool[]
# (sea_arr_new_u, ek 3) into e's register and the comparison (rule 32: sea_str_cmp, `li 0`, `icmp
# eq`) stored by `stb`. Line 4: c[0], c[1] (rule 18, `ldp` borrowed), e[1] (`ldb`) and str of it
# (rule 32: `la` true, `la` false, `psel`, borrowed); the 24-byte slot; e and c released in
# reverse order.
LIR1['str_ew'] = J(
    'func .main main 0:1:1 0 0',
    'li i.R1 2', 'li i.ek1 4', 'li i.rk1 1', 'li i.C1 1',
    'rcall sea_arr_new 0:6 1 p.A1 4 i.ek1 i.rk1 i.R1 i.C1', 'ldp p.D1 p.A1 - 0 40',
    'la p.a d1', 'retain p.a', 'stp p.a p.D1 - 0 0',
    'la p.b d2', 'retain p.b', 'stp p.b p.D1 - 0 8',
    'call ew 0 1 p.A1', 'release p.A1',
    'li i.R2 3', 'li i.ek2 4', 'li i.rk2 1', 'li i.C2 1',
    'rcall sea_arr_new 0:7 1 p.A2 4 i.ek2 i.rk2 i.R2 i.C2', 'ldp p.D2 p.A2 - 0 40',
    'la p.b2 d3', 'retain p.b2', 'stp p.b2 p.D2 - 0 0',
    'la p.c2 d4', 'retain p.c2', 'stp p.c2 p.D2 - 0 8',
    'la p.d2 d5', 'retain p.d2', 'stp p.d2 p.D2 - 0 16',
    'call ew 0 1 p.A2', 'release p.A2', 'ret 0', 'endfunc',
    'func ew fn 0:1:1 1 p.v 0', 'slot s1 24 8',
    'la p.ex d6', 'ldi i.N1 p.v - 0 16', 'li i.ekc 4', 'li i.rkc 1', 'li i.onec 1',
    'rcall sea_arr_new 0:2 1 p.c 4 i.ekc i.rkc i.N1 i.onec',
    'ldp p.DR p.c - 0 40', 'ldp p.DA p.v - 0 40',
    'li i.Z 0', 'icmp gt i.g i.N1 i.Z', 'if 1 i.g', 'li i.O 1', 'isub i.L i.N1 i.O',
    'loop 2 i.I i.Z i.L i.O', 'ldp p.x p.DA i.I 8 0', 'rcall sea_str_cat 0:2 1 p.r 2 p.x p.ex',
    'stp p.r p.DR i.I 8 0', 'endloop 2', 'endif 1',
    'la p.bb d7', 'ldi i.N2 p.v - 0 16', 'li i.eke 3', 'li i.rke 1', 'li i.onee 1',
    'rcall sea_arr_new_u 0:3 1 p.e 4 i.eke i.rke i.N2 i.onee',
    'ldp p.DRe p.e - 0 40', 'ldp p.DAe p.v - 0 40',
    'li i.Z2 0', 'icmp gt i.g2 i.N2 i.Z2', 'if 3 i.g2', 'li i.O2 1', 'isub i.L2 i.N2 i.O2',
    'loop 4 i.I2 i.Z2 i.L2 i.O2', 'ldp p.y p.DAe i.I2 8 0',
    'rcall sea_str_cmp - 1 i.C 2 p.y p.bb', 'li i.Zc 0',
    'icmp eq i.q i.C i.Zc', 'stb i.q p.DRe i.I2 1 0', 'endloop 4', 'endif 3',
    'li i.k0 0', 'ldi i.x0 p.c - 0 16', 'chkb i.k0 i.x0 0 0:4', 'ldp p.d0 p.c - 0 40',
    'ldp p.v0 p.d0 i.k0 8 0',
    'li i.k1 1', 'ldi i.x1 p.c - 0 16', 'chkb i.k1 i.x1 0 0:4', 'ldp p.d1 p.c - 0 40',
    'ldp p.v1 p.d1 i.k1 8 0',
    'li i.k2 1', 'ldi i.x2 p.e - 0 16', 'chkb i.k2 i.x2 0 0:4', 'ldp p.d2e p.e - 0 40',
    'ldb i.bv p.d2e i.k2 1 0',
    'la p.T d8', 'la p.Fa d9', 'psel p.bs i.bv p.T p.Fa',
    'sa p.S s1', 'stp p.v0 p.S - 0 0', 'stp p.v1 p.S - 0 8', 'stp p.bs p.S - 0 16',
    'la p.F d10', 'rcall sea_printf 0:4 0 2 p.F p.S',
    'release p.e', 'release p.c', 'ret 0', 'endfunc',
    'str d1 a', 'str d2 b', 'str d3 b', 'str d4 c', 'str d5 d', 'str d6 !', 'str d7 b',
    'str d8 true', 'str d9 false',
    fmt_rec(10, ['fconv - - - s p', 'ftext %20', 'fconv - - - s p', 'ftext %20',
                 'fconv - - - s p', 'ftext %0A']))
# ew(["a", "b"]): c = ["a!", "b!"], e = [false, true]; ew(["b", "c", "d"]): c = ["b!", "c!",
# "d!"], e = [true, false, false] (LANGUAGE.md 4.4, Decision 45; str(bool) 10.9).
OUT['str_ew'] = 'a! b! true\nb! c! false\n'
NAMES4G.append('str_ew')


# ================================================================ str_l12 (L12 + L17, R25)
SEA['str_l12'] = '''fn two(n: i64) -> (str, i64) {
    return (str(n), n + 1)
}
fn upd(i: i64) {
    var names = ["x", "y"]
    var k = 0
    (names[i], k) = two(i + 5)
    printf("%s %s %d\\n", names[0], names[1], k)
}
let (a, b) = two(1)
printf("%s %d\\n", a, b)
upd(0)
upd(1)
// str_l12 -- DESIGN.md 3.5.9 L12 with a target that L17 rewrites (line 7, `names[i]`, a str
// element): L17's block directly in the L12 block, with no `tmp Vv` and its est storing `lv L1`
// itself, which R25 moves (no retain; L1 dropped from rule 16's releases at the block's end); the
// scalar target k stays an asg
'''
AST['str_l12'] = '''
type 0:1:11 i64 s 0
param 0:1:8 n 0 0
type 0:1:20 str s 0
type 0:1:25 i64 s 0
name 0:2:17 n
conv 0:2:13 str
name 0:2:21 n
int 0:2:25 1
bin 0:2:21 add
return 0:2:5 2
block 0:1:30 1
fn 0:1:1 two 0 1 2
type 0:4:11 i64 s 0
param 0:4:8 i 0 0
pname 0:5:9 names
str 0:5:18 x
str 0:5:23 y
row 0:5:18 2
array 0:5:17 1
var 0:5:5 0
pname 0:6:9 k
int 0:6:13 0
var 0:6:5 0
name 0:7:6 names
name 0:7:12 i
index 0:7:6 1
name 0:7:16 k
name 0:7:21 two
name 0:7:25 i
int 0:7:29 5
bin 0:7:25 add
call 0:7:21 1
tasg 0:7:5 2
name 0:8:5 printf
str 0:8:12 %25s%20%25s%20%25d%0A
name 0:8:26 names
int 0:8:32 0
index 0:8:26 1
name 0:8:36 names
int 0:8:42 1
index 0:8:36 1
name 0:8:46 k
call 0:8:5 4
cstmt 0:8:5
block 0:4:16 4
fn 0:4:1 upd 0 1 0
pname 0:10:6 a
pname 0:10:9 b
ptuple 0:10:5 2
name 0:10:14 two
int 0:10:18 1
call 0:10:14 1
let 0:10:1 0
name 0:11:1 printf
str 0:11:8 %25s%20%25d%0A
name 0:11:19 a
name 0:11:22 b
call 0:11:1 3
cstmt 0:11:1
name 0:12:1 upd
int 0:12:5 0
call 0:12:1 1
cstmt 0:12:1
name 0:13:1 upd
int 0:13:5 1
call 0:13:1 1
cstmt 0:13:1
prog 6
'''
# sea.hir1: (str, i64) 10 (the call of .main, first), str[] 11 (`loc names`). The tasg of line 7
# has no cv (both components unconverted).
HIR1['str_l12'] = '''
ttuple 10 2 5 3
tvec 11 5
fn 1 .main main 1 0 2 0:1:1
loc a 5 let 0:10:6
loc b 3 let 0:10:9
ci 0:10:18 3 1
call 0:10:14 10 2 1
tbind 0:10:1 2 1 2
lv 0:11:19 5 1
fconv 0:11:8 1 - - - s
ftext 0:11:8 1 %20
lv 0:11:22 3 2
fconv 0:11:8 1 - - - d
ftext 0:11:8 1 %0A
fmt 0:11:8 1 4
lib 0:11:1 1 printf 1
eval 0:11:1
ci 0:12:5 3 0
call 0:12:1 1 3 1
eval 0:12:1
ci 0:13:5 3 1
call 0:13:1 1 3 1
eval 0:13:1
block 0:1:1 4
end
fn 2 two fn 10 1 0 0:1:1
par n 3 val
lv 0:2:17 3 1
lib 0:2:13 5 str 1
lv 0:2:21 3 1
ci 0:2:25 3 1
bin 0:2:21 3 add
ret 0:2:5 2
block 0:1:30 1
end
fn 3 upd fn 1 1 2 0:4:1
par i 3 val
loc names 11 var 0:5:9
loc k 3 var 0:6:9
cs 0:5:18 5 x
cs 0:5:23 5 y
row 0:5:18 11 2
arr 0:5:17 11 1
bind 0:5:5 2
ci 0:6:13 3 0
bind 0:6:5 3
lv 0:7:6 11 2
lv 0:7:12 3 1
idx 0:7:6 5 1
lv 0:7:16 3 3
lv 0:7:25 3 1
ci 0:7:29 3 5
bin 0:7:25 3 add
call 0:7:21 10 2 1
tasg 0:7:5 2 0 0
lv 0:8:26 11 2
ci 0:8:32 3 0
idx 0:8:26 5 1
fconv 0:8:12 1 - - - s
ftext 0:8:12 1 %20
lv 0:8:36 11 2
ci 0:8:42 3 1
idx 0:8:36 5 1
fconv 0:8:12 1 - - - s
ftext 0:8:12 1 %20
lv 0:8:46 3 3
fconv 0:8:12 1 - - - d
ftext 0:8:12 1 %0A
fmt 0:8:12 1 6
lib 0:8:5 1 printf 1
eval 0:8:5
block 0:4:16 4
end
'''


def hirl_str_l12():
    """sea.hirl of upd: tptr 12 5. Line 5 is L9 (b) (P 0:5:17). Line 7 is L12 (P 0:7:5, the tasg's
    position, which every node L12 writes takes): `block P 3` { `tbind P 2 L1 L2` of the call
    (kept); the L17 block of `names[i]` at P with no `tmp Vv` (L17 step 1's exception) and the est
    storing `lv L1` (R25); `asg P set (lv k) (lv L2)` (a scalar asg stays, rule 2) }. The L17
    block's root `lv names` nodes are written at P, as L6 writes them; the index keeps its own
    position."""
    F = Fn()
    lit = L9b_str(F, '0:5:17', 11, 12, 'l', [cs_('0:5:18', 'x'), cs_('0:5:23', 'y')])
    P = '0:7:5'
    call = ['lv 0:7:25 3 1', 'ci 0:7:29 3 5', 'bin 0:7:25 3 add', 'call 0:7:21 10 2 1']
    L1 = F.d('L1', 5, 'let', P)
    L2 = F.d('L2', 3, 'let', P)
    tb = N(call + ['tbind %s 2 %s %s' % (P, L1, L2)], None)
    x = Ctx(F, P, 't')
    root = lv(P, 11, 2)
    l17 = block(P, [x.tmp('I', lv('0:7:12', 3, 1)), x.tmp('X', ext(P, 0, root)),
                    chkb(P, 0, x.lvl('I'), x.lvl('X')), cow(P, root),
                    est(P, 5, lv(P, 5, L1), adat(P, 12, root), x.lvl('I'))])
    sk = asg(P, 'set', lv('0:7:16', 3, 3), lv(P, 3, L2))
    l12 = block(P, [tb, l17, sk])
    eds = [(['cs 0:5:18 5 x', 'cs 0:5:23 5 y', 'row 0:5:18 11 2', 'arr 0:5:17 11 1'], cat(lit)),
           (['lv 0:7:6 11 2', 'lv 0:7:12 3 1', 'idx 0:7:6 5 1', 'lv 0:7:16 3 3'] + call +
            ['tasg 0:7:5 2 0 0'], cat(l12))]
    return make_hirl(HIR1['str_l12'], ['tptr 12 5'], {3: (F, eds)})


HIRL['str_l12'] = hirl_str_l12
# sea.lir1. .main: the call with its two result registers straight into a and b (the tbind, rule
# 2), the printf (16-byte slot), the two calls of upd, a released at the end (rule 16 (a)). two:
# str(n) (rule 32, owned), n + 1 (checked add), `ret 2` (rule 5; the str moved, rule 15 (a)).
# upd: line 5 rule 26 into names's register; line 6 `li`; line 7: the argument, the call into L1
# and L2 (the tbind, rule 2), then the L17 block: I the alias of i, the check, the cow, the adat,
# and R25's move of L1: `ldp O`, `stp L1`, `release O` with no `retain`; `mov k L2` (rule 2); no
# release of L1 at the L12 block's end (R25). Line 8: two rule-18 reads, k, the 24-byte slot;
# names released at the end.
LIR1['str_l12'] = J(
    'func .main main 0:1:1 0 0', 'slot s1 16 8',
    'li i.one 1', 'call two 2 p.a i.b 1 i.one',
    'sa p.S s1', 'stp p.a p.S - 0 0', 'sti i.b p.S - 0 8', 'la p.F d1',
    'rcall sea_printf 0:11 0 2 p.F p.S',
    'li i.z 0', 'call upd 0 1 i.z', 'li i.o 1', 'call upd 0 1 i.o',
    'release p.a', 'ret 0', 'endfunc',
    'func two fn 0:1:1 1 i.n 2 p i',
    'rcall sea_str_i64 0:2 1 p.s 1 i.n', 'li i.c 1', 'iaddc i.m i.n i.c 0:2', 'ret 2 p.s i.m',
    'endfunc',
    'func upd fn 0:4:1 1 i.i 0', 'slot s1 24 8',
    'li i.R 2', 'li i.ek 4', 'li i.rk 1', 'li i.C 1',
    'rcall sea_arr_new 0:5 1 p.names 4 i.ek i.rk i.R i.C', 'ldp p.D p.names - 0 40',
    'la p.x d2', 'retain p.x', 'stp p.x p.D - 0 0',
    'la p.y d3', 'retain p.y', 'stp p.y p.D - 0 8',
    'li i.k 0',
    'li i.five 5', 'iaddc i.arg i.i i.five 0:7', 'call two 2 p.L1 i.L2 1 i.arg',
    'ldi i.X p.names - 0 16', 'chkb i.i i.X 0 0:7',
    'ldi i.rc p.names - 0 0', 'li i.ro 1', 'icmp ne i.u i.rc i.ro', 'if 1 i.u',
    'rcall sea_arr_unique 0:7 1 p.U 1 p.names', 'mov p.names p.U', 'endif 1',
    'ldp p.D2 p.names - 0 40',
    'ldp p.O p.D2 i.i 8 0', 'stp p.L1 p.D2 i.i 8 0', 'release p.O',
    'mov i.k i.L2',
    'li i.k0 0', 'ldi i.e0 p.names - 0 16', 'chkb i.k0 i.e0 0 0:8', 'ldp p.d0 p.names - 0 40',
    'ldp p.v0 p.d0 i.k0 8 0',
    'li i.k1 1', 'ldi i.e1 p.names - 0 16', 'chkb i.k1 i.e1 0 0:8', 'ldp p.d1 p.names - 0 40',
    'ldp p.v1 p.d1 i.k1 8 0',
    'sa p.S2 s1', 'stp p.v0 p.S2 - 0 0', 'stp p.v1 p.S2 - 0 8', 'sti i.k p.S2 - 0 16',
    'la p.F2 d4', 'rcall sea_printf 0:8 0 2 p.F2 p.S2',
    'release p.names', 'ret 0', 'endfunc',
    fmt_rec(1, ['fconv - - - s p', 'ftext %20', 'fconv - - - d i', 'ftext %0A']),
    'str d2 x', 'str d3 y',
    fmt_rec(4, ['fconv - - - s p', 'ftext %20', 'fconv - - - s p', 'ftext %20',
                'fconv - - - d i', 'ftext %0A']))
# two(1) = ("1", 2); upd(0): two(5) = ("5", 6) into names[0] and k; upd(1): two(6) = ("6", 7)
# into names[1] and k (LANGUAGE.md 7.3: the call first, then the targets in order).
OUT['str_l12'] = '1 2\n5 y 6\nx 6 7\n'
NAMES4G.append('str_l12')


# ================================================================ the self-check (4g-1)
# check_hirl4f of dump4f_cases (the 4e and 4f items of 3.5.9 "What the passes validate") is
# executed from its source; check_hirl4g adds the 4g-1 items.
exec(compile(_segment(_SRC4F, 'REWRITTEN_LIB4F = ', 'def cross_counts('), _P4F, 'exec'))


def hirl_trees(name):
    """The functions of NAME.hirl as lists of nodes (post-order), each node (op, v, kids, parent)."""
    text = read(name + '.hirl')
    fns, stack, cur = [], [], None
    for ln in lines(text)[3:-1]:
        op, v, pops = parse_rec(name, 'H HF HL'.split(), ln)
        if op in NOT_NODES or op in ('par', 'loc'):
            if op == 'fn':
                cur = {'locs': [], 'nodes': []}
                fns.append(cur)
            elif op in ('par', 'loc'):
                cur['locs'].append((v['name'], int(v['ty'])))
            continue
        if op == 'fn':
            cur = {'locs': [], 'nodes': []}
            fns.append(cur)
            continue
        kids = stack[len(stack) - pops:] if pops else []
        del stack[len(stack) - pops:]
        node = {'op': op, 'v': v, 'kids': kids, 'parent': None}
        for c in kids:
            c['parent'] = node
        cur['nodes'].append(node)
        if op != 'end':
            stack.append(node)
    assert not stack, name
    return fns


def tptr_str(name):
    """The `tptr` type of `str` that NAME.hirl appends, if any (3.5.9 "Types")."""
    return {int(r.split(' ')[1]) for r in lines(read(name + '.hirl')) if re.match(r'^tptr \d+ 5$', r)}


def check_hirl4g(name):
    """check_hirl4f, then the 4g-1 items of 3.5.9 "What the passes validate": no `match`, `arm`,
    `proj` or `fld` (L15, L16; no struct in 4g-1); no `asg` whose target is an element of a type
    that holds counts (L17 rewrites it); R20: an `mcpy` into a `tptr` of `str` has a type-3 count
    (a `ci` or an `lv`), never a byte count; R25: an `est` whose value is `lv` of a `.l` local of
    a `tbind` stands in a `block` directly in the L12 block that the `tbind` begins, and each such
    local is moved at most once."""
    nrec, nch = check_hirl4f(name)
    TPTR_STR = tptr_str(name)
    for fn in hirl_trees(name):
        lt = {k + 1: t for k, (_, t) in enumerate(fn['locs'])}
        isl = {k + 1: nm.startswith('.l') for k, (nm, _) in enumerate(fn['locs'])}
        moved = []
        for n in fn['nodes']:
            op, v, kids = n['op'], n['v'], n['kids']
            assert op not in ('match', 'arm', 'proj', 'fld'), (name, '4g-1: left for sealower', op)
            if op == 'asg':
                tg = kids[0]
                assert not (tg['op'] == 'idx' and int(tg['v']['ty']) == 5), \
                    (name, 'L17: an asg of a str element reaches sealower')
            if op == 'mcpy':
                d = kids[0]
                if d['op'] == 'lv' and lt[int(d['v']['lid'])] in TPTR_STR:
                    c = kids[2]
                    assert c['op'] in ('ci', 'lv') and int(c['v']['ty']) == 3, \
                        (name, 'R20: the count of a counted copy', c['op'])
            if op == 'est':
                val = kids[0]
                if val['op'] == 'lv' and isl[int(val['v']['lid'])]:
                    L = val['v']['lid']
                    tb = [m for m in fn['nodes'] if m['op'] == 'tbind' and L in m['v']['lid']]
                    if tb:
                        b17 = n['parent']
                        assert b17['op'] == 'block' and b17['parent']['op'] == 'block' and \
                            b17['parent']['kids'][0] is tb[0], (name, 'R25: the move form')
                        assert L not in moved, (name, 'R25: a local moved twice')
                        moved.append(L)
    return nrec, nch


def cross_counts4g(name):
    """Counts the .hirl and the .lir1 must agree on (3.6.6 "Lowering of the sea.hirl records" and
    rules 4, 18, 19, 32, 33): `loop` = hloop + forr + R20's retain loops (an mcpy into a str tptr
    with an lv count, R20); `if` + `ifz` = if + ifx + while + cow + R20's loops; `chkb` = chkb + idx;
    `rcall sea_arr_unique` = cow; `mcopy` = mcpy; `rcall sea_str_cat` = `bin cat`; `rcall
    sea_args` = `lib args`; `rcall sea_str_lower` = `lib lower`."""
    hl = lines(read(name + '.hirl'))[3:-1]
    lr = lines(read(name + '.lir1'))[3:-1]
    ops = lambda recs, o: sum(1 for r in recs if r.split(' ')[0] == o)
    pre = lambda recs, p: sum(1 for r in recs if r.startswith(p))
    r20 = 0
    TPTR_STR = tptr_str(name)
    for fn in hirl_trees(name):
        lt = {k + 1: t for k, (_, t) in enumerate(fn['locs'])}
        for n in fn['nodes']:
            if n['op'] == 'mcpy' and n['kids'][0]['op'] == 'lv' and \
                    lt[int(n['kids'][0]['v']['lid'])] in TPTR_STR and n['kids'][2]['op'] == 'lv':
                r20 += 1
    assert ops(lr, 'loop') == ops(hl, 'hloop') + ops(hl, 'forr') + r20, (name, 'loops')
    assert ops(lr, 'if') + ops(lr, 'ifz') == ops(hl, 'if') + ops(hl, 'ifx') + ops(hl, 'while') + \
        ops(hl, 'cow') + r20, (name, 'ifs')
    assert ops(lr, 'chkb') == ops(hl, 'chkb') + ops(hl, 'idx'), (name, 'chkb')
    assert pre(lr, 'rcall sea_arr_unique ') == ops(hl, 'cow'), (name, 'cow')
    assert ops(lr, 'mcopy') == ops(hl, 'mcpy'), (name, 'mcpy')
    assert pre(lr, 'rcall sea_str_cat ') == sum(1 for r in hl if re.match(r'^bin \S+ 5 cat$', r)), \
        (name, 'cat')
    for lb in ('args', 'lower'):
        assert pre(lr, 'rcall sea_%s ' % ('args' if lb == 'args' else 'str_lower')) == \
            sum(1 for r in hl if re.match(r'^lib \S+ \d+ %s ' % lb, r)), (name, lb)


def check_examples():
    """The agreed examples of 3.6.6 rules 15, 26, 30 (its first), 32 and 33 verbatim in their
    goldens (check_example of dump4e_cases: the first code block of the rule in DESIGN.md, found
    exactly once); rule 35 has no code block, so its instruction `rcall sea_args site 1 R 0` is
    checked in its text and, with str_rule30's registers, in that golden."""
    for rule in (15, 26, 30, 32, 33):
        check_example(rule, 'str_rule%d' % rule)
    with open(os.path.join(ROOT, 'docs', 'DESIGN.md')) as fh:
        doc = fh.read()
    assert re.search(r'^35\. \*\*`args`\.\*\* `lib args\(\)` is `rcall sea_args site 1 R 0`',
                     doc, re.M), 'rule 35 text'
    assert 'rcall sea_args 0:3 1 p1 0' in lines(read('str_rule30.lir1')), 'rule 35 in str_rule30'



# ================================================================================================
# ================================================================ sub-phase 4g-2 (T2b)
# ================================================================================================
# DESIGN.md 6.2 "4g-2" dumps; 3.4.2 (`rtst`/`rtfd`, `rslit`, the struct declaration checks);
# 3.5.9 L15, L17's field paths and aggregates, L6 with a field root, the struct cases of L2, L4,
# L9, L10 and L12, R17-R25; 3.6.6 rules 15 (g), 16, 18 (its second example), 19, 26, 27 (its
# example), 29 (its example), 30, 31, 38 and "Lowering of the sea.hirl records" (4g); lead
# decisions L-h, L-j, L-m, L-n; Decisions 44, 47, 48.
#
# The tests (one array operation per statement, every function called from two call sites at
# least, 3.6.6 "Phase-4 dump tests"):
# * res_rt: 3.4.2's example rt.sea verbatim; its .res is the documented one, compared directly.
# * res_rtst: the order of the type table (3.4.2: the struct types first in sid order, each rtst
#   followed by its rtfd records, a field naming a later id, then the field types, the signature
#   types and the other type nodes) and two rslit with sid 0 (an undeclared struct name, and a
#   struct name hidden by a local).
# * res_struct (changed golden, 6.2 L-i): no rerr; `let q = P` is seacheck's `undeclared name`.
# * struct_rule18, struct_rule27, struct_rule29: the agreed examples of rules 18 (the second), 27
#   and 29 as whole programs, each verbatim in its .lir1.
# * struct_l17: L17 on a struct local: a scalar field, a compound store, a `str` field (R17), a
#   nested field (R24's summed offset), an element of an array field (R23's cow of the field), a
#   struct field stored from a slit by the copy form (R19, rule 27 (d)).
# * struct_l17_path: L17 through elements with a `ref` root: a path through two arrays (the cows
#   of R23, lead decision L-n), a field at an offset of an element (`ds[i].lim = T { ... }`, sc
#   the element stride 32, off 16, a slit stored by the copy form), a nested numeric field, a
#   `str` field of an element; the literal of line 8 written in place (R19).
# * struct_cow2: 6.2's two array-field levels (`a[0].w[0].v[0] = 9.0` after `let b = a`, printing
#   `1 9`): each cow reads the array the cow before left.
# * str_ref_ln: R23's reuse of the cow's register for a `ref` parameter root (lead decision L-n):
#   `fn f(ref v: str[], i: i64) { v[i] = "x" }`, the est address is the cow's A, no second ldp.
# * str_fixed_self: a `str[3]` local (L10's fix by R20's static count), `a[:] = a` (L6's counted
#   self-copy: `mcpy data(Vv) data(V0) (ci 3)`, the unrolled retains, the home released at the
#   block's end), an element store into a fixed-size home (L17, R17, no cow).
# * struct_l6_field: L6 with a field root, `dims[p()].v[q()..3] = 0.0` (the order of rule 19).
# * struct_l12: L12 with a field target (`(s.name, k) = two(7)`) and an aggregate element target
#   (`(ps[0], k) = mk(k)`), both moved out of their .l locals (R25); a slit stored into an
#   existing element (R19, rule 27 (d): the old reference field released).
# * rec_slay: an array literal of records (L9, a sea_arr_new_s with the slay of the record type,
#   lead decision L-m) and an element loop over it (L4: the element's address, R18).
#
# How each file is made: as for 4g-1 (the module docstring), with these 4g-2 additions:
# * `.res`: res_gen.py with STRUCTS set (its 4g-2 part: rtst/rtfd, rslit, the declaration checks)
#   on top of the steps 4e and 4g-1 (res_gen4g2 below).
# * struct layouts (sizes, alignments, field offsets, reference offsets) are computed by layout()
#   below from 4.8's struct layout rule, by hand in Python; passes/lib/layout.bas is not used.
# * `.hir1`: struct types `tstruct` with their `fd` records numbered by first reference (3.5.1:
#   a type's field types numbered before it), records `trec`; `slit` values in declaration order
#   (no seq when it equals the source order), `fld i`, `proj i` (3.5.5).

def res_gen4g2():
    """res_gen.py with the steps 4e, 4g-1 (res_gen4g1's edits, with the 4g-2 step that a fixed-size
    `str` type resolves) and 4g-2 (its STRUCTS part: struct declarations and literals)."""
    mod = res_gen4g1(fixed_str=True)
    mod.STRUCTS = True
    return mod


RG2 = res_gen4g2()
SEA2, AST2, HIR12, HIRL2, LIR12, OUT2 = {}, {}, {}, {}, {}, {}
NAMES4G2 = []     # the 4g-2 dump tests with every file
RES4G2 = []       # the 4g-2 res tests (.sea .ast .res [+ .out])


# ---------------------------------------------------------------- struct layouts (4.8)
def type_table(text):
    """The type records of a HIR file: id -> ('st', [(name, ty)]) for tstruct and trec, ('v'|'m',
    elt), ('fv', elt, n), ('fm', elt, r, c), ('t', [ty]), ('ptr', elt)."""
    tab, cur = {}, None
    for ln in lines(text):
        p = ln.split(' ')
        if p[0] in ('tstruct', 'trec'):
            cur = []
            tab[int(p[1])] = ('st', cur, p[2] if p[0] == 'tstruct' else None)
        elif p[0] == 'fd':
            cur.append((p[1], int(p[2])))
        elif p[0] in ('tvec', 'tmat'):
            tab[int(p[1])] = ({'tvec': 'v', 'tmat': 'm'}[p[0]], int(p[2]))
        elif p[0] == 'tfvec':
            tab[int(p[1])] = ('fv', int(p[2]), int(p[3]))
        elif p[0] == 'tfmat':
            tab[int(p[1])] = ('fm', int(p[2]), int(p[3]), int(p[4]))
        elif p[0] == 'ttuple':
            tab[int(p[1])] = ('t', [int(x) for x in p[3:]])
        elif p[0] == 'tptr':
            tab[int(p[1])] = ('ptr', int(p[2]))
    return tab


def layout(tab, t):
    """4.8 "Struct layout rule": (size, alignment, the ascending reference offsets) of type t.
    f64, i64 and reference values (str, dynamic arrays, handles) size 8 align 8, bool size 1
    align 1; T[n] / T[r,c] n or r*c elements of T inline with T's alignment; a struct its fields
    in declaration order, each at the next multiple of its alignment, its alignment the largest
    of its fields' (1 with none), its size rounded up to it."""
    if t in (3, 4):
        return 8, 8, []
    if t == 2:
        return 1, 1, []
    if t == 5 or 6 <= t <= 9:
        return 8, 8, [0]
    k = tab[t]
    if k[0] in ('v', 'm'):
        return 8, 8, [0]
    if k[0] in ('fv', 'fm'):
        n = k[2] if k[0] == 'fv' else k[2] * k[3]
        s, a, r = layout(tab, k[1])
        return s * n, a, [j * s + o for j in range(n) for o in r]
    assert k[0] == 'st', k
    off, al, refs = 0, 1, []
    for _, ft in k[1]:
        s, a, r = layout(tab, ft)
        off = (off + a - 1) // a * a
        refs += [off + o for o in r]
        off += s
        al = max(al, a)
    return (off + al - 1) // al * al, al, refs


def field_off(tab, t, path):
    """off(S, f) of 3.5.9 "Notation": the offset of the field path (names) in struct t, the sum
    along the path, and the field's type."""
    off = 0
    for nm in path:
        k = tab[t]
        o = 0
        found = None
        for fname, ft in k[1]:
            s, a, _ = layout(tab, ft)
            o = (o + a - 1) // a * a
            if fname == nm:
                found = ft
                break
            o += s
        assert found is not None, (t, nm)
        off += o
        t = found
    return off, t


def slot_size(tab, t):
    """3.6.6 rule 27 (a): a slot's size, the type's rounded up to a multiple of 8, at least 8."""
    s = layout(tab, t)[0]
    return max(8, (s + 7) // 8 * 8)


# ---------------------------------------------------------------- 4g-2 HIR helpers
def fld(P, ty, i, a):
    """`fld P ty i` of a struct or record value (3.5.5)."""
    return N(cat(a) + ['fld %s %d %d' % (P, ty, i)], ty)


def eldS(P, ty, sc, off, a, i):
    """`eld P ty sc off` with an explicit stride and offset (R18, R24)."""
    return N(cat(a, i) + ['eld %s %d %d %d' % (P, ty, sc, off)], ty)


def estS(P, sc, off, v, a, i):
    """`est P sc off` with an explicit stride and offset (R17, R19, R24)."""
    return N(cat(v, a, i) + ['est %s %d %d' % (P, sc, off)], None)


def cowS(P, a):
    return N(cat(a) + ['cow %s' % P], None)


def L9b_any(F, P, T, TP, pre, sc, elems, cdat_=None):
    """L9 (b) for one row of n elements of size sc (4g-1's L9b_str with any element type):
    `tmp R = ci n`, `tmp A = anew P T 0 1 (lv R)` (R21: sea_arr_new or sea_arr_new_s whatever z),
    `tmp D = data(A)`, each element in source order `est P sc 0 e (lv D) (ci k)` (R3; a struct or
    record element by R19: a slit written in place at the fresh address); value `lv A`."""
    x = Ctx(F, P, pre)
    st = [x.tmp('R', ci(P, len(elems))),
          x.tmp('A', anew(P, T, 0, [x.lvl('R')])),
          x.tmp('D', adat(P, TP, x.lvl('A')))]
    for k, e in enumerate(elems):
        st.append(estS(P, sc, 0, e, x.lvl('D'), ci(P, k)))
    return xblk(P, st, x.lvl('A'))


def type_order_check4g2(nm, recs):
    """3.5.1 "Numbering" with struct and record types: a tstruct/trec's components are its field
    types (declaration order), numbered before it."""
    tab, k, cur = {}, 0, None
    while recs[k].split(' ')[0] in TYPE_RECS | {'fd'}:
        p = recs[k].split(' ')
        if p[0] in ('tvec', 'tmat', 'tfvec', 'tfmat'):
            tab[int(p[1])] = [int(p[2])]
        elif p[0] == 'ttuple':
            tab[int(p[1])] = [int(t) for t in p[3:]]
        elif p[0] in ('tstruct', 'trec'):
            cur = []
            tab[int(p[1])] = cur
        elif p[0] == 'fd':
            cur.append(int(p[2]))
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


KW4G2 = dict(KW4G)
KW4G2.update({'struct': 'struct', 'rlit': '{'})


def check_positions4g2(name, src, recs):
    """check_positions4g, and the struct records of 3.4: `struct` at its keyword, `field` and
    `init` at their name, `slit` at its struct name, `rlit` at its `{`."""
    check_positions4g(name, src, [r for r in recs if r.split(' ')[0] not in
                                  ('struct', 'field', 'init', 'slit', 'rlit')])
    src_lines = src.split('\n')
    for r in recs:
        p = r.split(' ')
        if p[0] not in ('struct', 'field', 'init', 'slit', 'rlit'):
            continue
        _, ln, col = (int(x) for x in p[1].split(':'))
        s = src_lines[ln - 1][col - 1:]
        want = {'struct': 'struct', 'rlit': '{'}.get(p[0], p[2] if len(p) > 2 else None)
        assert s.startswith(want), (name, r, s)


def write_test4g2(nm):
    """As write_test4g, for the 4g-2 tables (SEA2 ... OUT2) and res_gen4g2."""
    src = SEA2[nm]
    ast = lines(AST2[nm])
    check_positions4g2(nm, src, ast)
    write(nm + '.sea', src)
    write(nm + '.ast', dump(nm, '\n'.join(ast)))
    if nm in HIR12:
        hir1 = HIR12[nm]
        recs = lines(hir1)
        tree_check(nm, recs, 'H H1'.split())
        type_order_check4g2(nm, recs)
        for k, ln in enumerate(recs):
            op = ln.split(' ')[0]
            assert op not in ('cref', 'cn'), (nm, ln)
            prev = [recs[k - j].split(' ')[0] for j in (1, 2)]
            if op in ('cvt', 'un', 'powk') and prev[0] in ('ci', 'cf'):
                raise AssertionError((nm, 'foldable', ln))
            if op == 'bin' and ln.split(' ')[3] in ('add', 'sub', 'mul', 'div') and \
                    prev[0] in ('ci', 'cf') and prev[1] in ('ci', 'cf'):
                raise AssertionError((nm, 'foldable', ln))
        fids = {int(ln.split(' ')[1]) for ln in recs if ln.startswith('fn ')}
        called = {1} | {int(ln.split(' ')[3]) for ln in recs if ln.startswith('call ')}
        assert fids == called, (nm, 'unreachable function', fids, called)
        for f in fids - {1}:
            ncall = sum(1 for ln in recs if ln.startswith('call ') and int(ln.split(' ')[3]) == f)
            assert ncall >= 2, (nm, 'a function called from one call site', f)
        write(nm + '.hir1', dump(nm, hir1))
        write(nm + '.hir', dump(nm, hir1))
        write(nm + '.hirl', dump(nm, HIRL2[nm]()))
        write(nm + '.lir1', dump(nm, number_regs(LIR12[nm])))
    if nm in OUT2:
        write(nm + '.out', OUT2[nm])
    RG2.make(nm)


def same_hirl2(nm):
    return lambda: HIR12[nm]


# ================================================================ res_rt (3.4.2's example)
SEA2['res_rt'] = '''const N = 2
struct P {
    v: f64[N]
}
fn first(ps: P[]) -> f64 {
    return ps[0].v[0]
}
let a = [P { v: [1.5, 2.5] }]
printf("%g\\n", first(a))
// res_rt -- DESIGN.md 3.4.2's example rt.sea verbatim (lines 1-9): its sea.res is the documented one
'''
AST2['res_rt'] = '''
int 0:1:11 2
const 0:1:1 N 0
name 0:3:12 N
type 0:3:8 f64 fv 1
field 0:3:5 v
struct 0:2:1 P 1
type 0:5:14 P v 0
param 0:5:10 ps 0 0
type 0:5:22 f64 s 0
name 0:6:12 ps
int 0:6:15 0
index 0:6:12 1
dot 0:6:12 v
int 0:6:20 0
index 0:6:12 1
return 0:6:5 1
block 0:5:26 1
fn 0:5:1 first 0 1 1
pname 0:8:5 a
float 0:8:18 #3FF8000000000000
float 0:8:23 #4004000000000000
row 0:8:18 2
array 0:8:17 1
init 0:8:14 v
slit 0:8:10 P 1
row 0:8:10 1
array 0:8:9 1
let 0:8:1 0
name 0:9:1 printf
str 0:9:8 %25g%0A
name 0:9:16 first
name 0:9:22 a
call 0:9:16 1
call 0:9:1 2
cstmt 0:9:1
prog 5
'''
# a[0].v[0] is 1.5 (LANGUAGE.md 11.1: %g)
OUT2['res_rt'] = '1.5\n'
RES4G2.append('res_rt')


def check_res_rt():
    """The body of res_rt.res equals 3.4.2's documented sea.res of rt.sea, record for record."""
    with open(os.path.join(ROOT, 'docs', 'DESIGN.md')) as fh:
        doc = fh.read().split('\n')
    k = doc.index('`sea build --emit res --no-prelude rt.sea`:')
    while doc[k].strip() != '```':
        k += 1
    k += 1
    blk = []
    while doc[k].strip() != '```':
        blk.append(doc[k])
        k += 1
    assert blk[:3] == ['#sea 1', '#target arm64-macos', '#file rt.sea'] and blk[-1] == '#end'
    got = read('res_rt.res').split('\n')
    assert got[-2:] == ['#end', ''] and got[3:-2] == blk[3:-1], \
        'res_rt.res differs from DESIGN.md 3.4.2'


# ================================================================ res_rtst (3.4.2: the type table, rslit 0)
SEA2['res_rtst'] = '''// res_rtst -- DESIGN.md 3.4.2: the type table (rtst B, A by sid with their rtfd, a field naming a later id,
// then the field types, the signature types, the other type nodes) and rslit with sid 0 (lines 17, 18)
struct B {
    a: A
    w: f64[]
    t: A[2]
}
struct A {
    x: i64
    s: str
}
fn mk(b: B, k: i64[,]) -> A[] {
    return [b.a]
}
let v: B[] = []
let A = 2
let q = A { x: 1, s: "" }
let r = Q { x: 1 }
'''
AST2['res_rtst'] = '''
type 0:4:8 A s 0
field 0:4:5 a
type 0:5:8 f64 v 0
field 0:5:5 w
int 0:6:10 2
type 0:6:8 A fv 1
field 0:6:5 t
struct 0:3:1 B 3
type 0:9:8 i64 s 0
field 0:9:5 x
type 0:10:8 str s 0
field 0:10:5 s
struct 0:8:1 A 2
type 0:12:10 B s 0
param 0:12:7 b 0 0
type 0:12:16 i64 m 0
param 0:12:13 k 0 0
type 0:12:27 A v 0
name 0:13:13 b
dot 0:13:13 a
row 0:13:13 1
array 0:13:12 1
return 0:13:5 1
block 0:12:31 1
fn 0:12:1 mk 0 2 1
pname 0:15:5 v
type 0:15:8 B v 0
array 0:15:14 0
let 0:15:1 1
pname 0:16:5 A
int 0:16:9 2
let 0:16:1 0
pname 0:17:5 q
int 0:17:16 1
init 0:17:13 x
str 0:17:22 %
init 0:17:19 s
slit 0:17:9 A 2
let 0:17:1 0
pname 0:18:5 r
int 0:18:16 1
init 0:18:13 x
slit 0:18:9 Q 1
let 0:18:1 0
prog 7
'''
RES4G2.append('res_rtst')

# ================================================================ res_struct (changed golden, 6.2 L-i)
RES_STRUCT_COMMENT = (
    ['// res_struct -- rst and rname st (a struct name used as a value); rerr not supported yet:',
     '// structs at the struct item (DESIGN.md 3.4.1, 2.6.2)'],
    ['// res_struct -- rtst/rtfd, rst and rname st (a struct name used as a value); from 4g-2 no',
     "// rerr: `let q = P` is seacheck's undeclared name 'P' (DESIGN.md 3.4.2, 6.2 L-i: re-derived)"])


def write_res_struct():
    src = read_repo('res_struct.sea')
    o, n = '\n'.join(RES_STRUCT_COMMENT[0]) + '\n', '\n'.join(RES_STRUCT_COMMENT[1]) + '\n'
    if o in src:
        src = src.replace(o, n)
    assert n in src, 'res_struct comment'
    write('res_struct.sea', src)
    ast = read_repo('res_struct.ast')
    write('res_struct.ast', ast)
    RG2.make('res_struct')
    assert read('res_struct.ast') == ast


# ================================================================ struct_rule27 (rule 27's example)
SEA2['struct_rule27'] = '''let p = P { x: 1.5, n: 3 }
let y = p.x
printf("%g %d\\n", y, p.n)
struct P {
    x: f64
    n: i64
}
// struct_rule27 -- DESIGN.md 3.6.6 rule 27's example on lines 1-2 (p in p1, its slot s1 of 16
// bytes, y in f4): the bind of a struct local writes the slit's fields into its slot (27 (b),
// (g)), a scalar field read is one load (27 (e)); sealoop rewrites nothing (the .hirl is the .hir)
'''
AST2['struct_rule27'] = '''
pname 0:1:5 p
float 0:1:16 #3FF8000000000000
init 0:1:13 x
int 0:1:24 3
init 0:1:21 n
slit 0:1:9 P 2
let 0:1:1 0
pname 0:2:5 y
name 0:2:9 p
dot 0:2:9 x
let 0:2:1 0
name 0:3:1 printf
str 0:3:8 %25g%20%25d%0A
name 0:3:19 y
name 0:3:22 p
dot 0:3:22 n
call 0:3:1 3
cstmt 0:3:1
type 0:5:8 f64 s 0
field 0:5:5 x
type 0:6:8 i64 s 0
field 0:6:5 n
struct 0:4:1 P 2
prog 4
'''
# sea.hir1: P is type 10 (first referred to by `loc p`); the slit's values in declaration order
# (x, n), which is the source order, so no seq (3.5.5 "Evaluation order"); `p.x`, `p.n` are fld 0
# and fld 1 at the dot's position.
HIR12['struct_rule27'] = '''
tstruct 10 P 2
fd x 4
fd n 3
fn 1 .main main 1 0 2 0:1:1
loc p 10 let 0:1:5
loc y 4 let 0:2:5
cf 0:1:16 4 #3FF8000000000000
ci 0:1:24 3 3
slit 0:1:9 10 2
bind 0:1:1 1
lv 0:2:9 10 1
fld 0:2:9 4 0
bind 0:2:1 2
lv 0:3:19 4 2
fconv 0:3:8 1 - - - g
ftext 0:3:8 1 %20
lv 0:3:22 10 1
fld 0:3:22 3 1
fconv 0:3:8 1 - - - d
ftext 0:3:8 1 %0A
fmt 0:3:8 1 4
lib 0:3:1 1 printf 1
eval 0:3:1
block 0:1:1 3
end
'''
# sea.hirl = sea.hir: a slit bound to a struct local and fld reads are sealower's (3.5.9 "What
# sealoop rewrites in 4g": rule 27's example is sealower's alone).
HIRL2['struct_rule27'] = same_hirl2('struct_rule27')
# sea.lir1: rule 27's example exactly: the bind (27 (b)): `sa` of p's slot s1 (16 bytes: P's size
# by 4.8, x at 0, n at 8), the slit's values each stored right after it is evaluated (27 (g));
# `let y = p.x`: the scalar field load straight into y's register (rule 2, 27 (e)). Line 3: the
# printf arguments (y; p.n `ldi` into a new register), the slot s2 of 16 bytes (rule 8). P holds
# no reference, so nothing is released.
LIR12['struct_rule27'] = J(
    'func .main main 0:1:1 0 0', 'slot s1 16 8', 'slot s2 16 8',
    'sa p.p s1', 'lf f.x #3FF8000000000000', 'stf f.x p.p - 0 0', 'li i.c 3', 'sti i.c p.p - 0 8',
    'ldf f.y p.p - 0 0',
    'ldi i.n p.p - 0 8', 'sa p.S s2', 'stf f.y p.S - 0 0', 'sti i.n p.S - 0 8', 'la p.F d1',
    'rcall sea_printf 0:3 0 2 p.F p.S', 'ret 0', 'endfunc',
    fmt_rec(1, ['fconv - - - g f', 'ftext %20', 'fconv - - - d i', 'ftext %0A']))
OUT2['struct_rule27'] = '1.5 3\n'
NAMES4G2.append('struct_rule27')


# ================================================================ struct_rule18 (rule 18's second example)
DIM_DECL = '''struct Dim {
    name: str
    nom: f64      // nominal length [mm]
    tol: f64      // symmetric tolerance [mm]
    dist: str     // "normal" | "uniform" | "triangular"
    sign: i64     // +1 opens the gap, -1 closes it
    alpha: f64    // thermal expansion coefficient [1/K]
}
'''
DIM_FD = '''
tstruct 10 Dim 6
fd name 5
fd nom 4
fd tol 4
fd dist 5
fd sign 3
fd alpha 4
'''
SEA2['struct_rule18'] = '''fn nomOf(dims: Dim[], d: i64) -> f64 {
    // struct_rule18 -- DESIGN.md 3.6.6 rule 18's second example on line 9: dims[d].nom with dims
    // a Dim[] in p1 (size 48, nom at 8) and d in i2, the fld of the idx folded into one load;
    // Dim is LANGUAGE.md Appendix D's. The literal of line 11 is L9 (b) with struct elements
    // written in place (R19, rule 26 (b)) into a sea_arr_new_s array (R21) whose descriptor is
    // the slay of Dim (rule 38: size 48, its str fields at 0 and 24)
    //
    //
    return dims[d].nom
}
let dims = [Dim { name: "a", nom: 1.5, tol: 0.5, dist: "n", sign: 1, alpha: 0.0 }, Dim { name: "b", nom: 2.5, tol: 0.25, dist: "u", sign: 2, alpha: 0.0 }]
printf("%g %g\\n", nomOf(dims, 0), nomOf(dims, 1))
''' + DIM_DECL
AST2['struct_rule18'] = '''
type 0:1:16 Dim v 0
param 0:1:10 dims 0 0
type 0:1:26 i64 s 0
param 0:1:23 d 0 0
type 0:1:34 f64 s 0
name 0:9:12 dims
name 0:9:17 d
index 0:9:12 1
dot 0:9:12 nom
return 0:9:5 1
block 0:1:38 1
fn 0:1:1 nomOf 0 2 1
pname 0:11:5 dims
str 0:11:25 a
init 0:11:19 name
float 0:11:35 #3FF8000000000000
init 0:11:30 nom
float 0:11:45 #3FE0000000000000
init 0:11:40 tol
str 0:11:56 n
init 0:11:50 dist
int 0:11:67 1
init 0:11:61 sign
float 0:11:77 #0000000000000000
init 0:11:70 alpha
slit 0:11:13 Dim 6
str 0:11:96 b
init 0:11:90 name
float 0:11:106 #4004000000000000
init 0:11:101 nom
float 0:11:116 #3FD0000000000000
init 0:11:111 tol
str 0:11:128 u
init 0:11:122 dist
int 0:11:139 2
init 0:11:133 sign
float 0:11:149 #0000000000000000
init 0:11:142 alpha
slit 0:11:84 Dim 6
row 0:11:13 2
array 0:11:12 1
let 0:11:1 0
name 0:12:1 printf
str 0:12:8 %25g%20%25g%0A
name 0:12:19 nomOf
name 0:12:25 dims
int 0:12:31 0
call 0:12:19 2
name 0:12:35 nomOf
name 0:12:41 dims
int 0:12:47 1
call 0:12:35 2
call 0:12:1 3
cstmt 0:12:1
type 0:14:11 str s 0
field 0:14:5 name
type 0:15:10 f64 s 0
field 0:15:5 nom
type 0:16:10 f64 s 0
field 0:16:5 tol
type 0:17:11 str s 0
field 0:17:5 dist
type 0:18:11 i64 s 0
field 0:18:5 sign
type 0:19:12 f64 s 0
field 0:19:5 alpha
struct 0:13:1 Dim 6
prog 4
'''
# sea.hir1: Dim 10 (its field types predefined), Dim[] 11 (`loc dims`); the literal of struct
# elements is a dynamic Dim[] (LANGUAGE.md 6.9, Decision 20), its row of the same type (3.5.5:
# the type of the row's join, dynamic as the literal is); each slit's values in declaration order
# (= source order: no seq); nomOf is function 2 (two call sites, not inlined).
HIR12['struct_rule18'] = DIM_FD + '''tvec 11 10
fn 1 .main main 1 0 1 0:1:1
loc dims 11 let 0:11:5
cs 0:11:25 5 a
cf 0:11:35 4 #3FF8000000000000
cf 0:11:45 4 #3FE0000000000000
cs 0:11:56 5 n
ci 0:11:67 3 1
cf 0:11:77 4 #0000000000000000
slit 0:11:13 10 6
cs 0:11:96 5 b
cf 0:11:106 4 #4004000000000000
cf 0:11:116 4 #3FD0000000000000
cs 0:11:128 5 u
ci 0:11:139 3 2
cf 0:11:149 4 #0000000000000000
slit 0:11:84 10 6
row 0:11:13 11 2
arr 0:11:12 11 1
bind 0:11:1 1
lv 0:12:25 11 1
ci 0:12:31 3 0
call 0:12:19 4 2 2
fconv 0:12:8 1 - - - g
ftext 0:12:8 1 %20
lv 0:12:41 11 1
ci 0:12:47 3 1
call 0:12:35 4 2 2
fconv 0:12:8 1 - - - g
ftext 0:12:8 1 %0A
fmt 0:12:8 1 4
lib 0:12:1 1 printf 1
eval 0:12:1
block 0:1:1 2
end
fn 2 nomOf fn 4 2 0 0:1:1
par dims 11 val
par d 3 val
lv 0:9:12 11 1
lv 0:9:17 3 2
idx 0:9:12 10 1
fld 0:9:12 4 1
ret 0:9:5 1
block 0:1:38 1
end
'''


def slit_recs(nm, pos):
    """The records of the slit at pos in HIR12[nm] (its post-order subtree, kept by sealoop)."""
    recs = lines(HIR12[nm])
    k = [j for j, r in enumerate(recs) if r.startswith('slit %s ' % pos)]
    assert len(k) == 1, (nm, pos)
    k = k[0]
    n = int(recs[k].split(' ')[3])
    # each value of these slits is one leaf record
    return recs[k - n:k + 1]


def hirl_struct_rule18():
    """sea.hirl: tptr 12 10 (the data of the Dim[] literal); .main's literal is L9 (b) (P the
    arr's position 0:11:12; each slit kept with its own nodes, R19 writes it in place at the
    fresh address); nomOf unchanged (rule 18 is sealower's)."""
    F = Fn()
    P = '0:11:12'
    tab = type_table(HIR12['struct_rule18'])
    s = layout(tab, 10)[0]
    assert s == 48 and field_off(tab, 10, ['nom']) == (8, 4) and layout(tab, 10)[2] == [0, 24]
    e1 = N(slit_recs('struct_rule18', '0:11:13'), 10)
    e2 = N(slit_recs('struct_rule18', '0:11:84'), 10)
    lit = L9b_any(F, P, 11, 12, 'l', s, [e1, e2])
    old = lines(HIR12['struct_rule18'])
    a = old.index('cs 0:11:25 5 a')
    b = old.index('arr 0:11:12 11 1')
    return make_hirl(HIR12['struct_rule18'], ['tptr 12 10'], {1: (F, [(old[a:b + 1], cat(lit))])})


HIRL2['struct_rule18'] = hirl_struct_rule18
# sea.lir1. .main, line 11: L9 (b): `tmp R = ci 2` (`li`), the anew of a Dim[] (R21: rule 17's
# arrnew with `la` of Dim's slay in place of `li K ek`, then the rank and `li C 1`, sea_arr_new_s
# whatever z) into dims's register (T3), the data; then each element (R19 into a fresh address):
# the element's address with the constant index k (`li O off+k*48`, `padd E D O`), then the
# slit's fields written in place in their written order, each right after its value (rule 27 (g)):
# a str `la` retained (rule 15 (a): a field of a struct literal holds a count), the numbers
# `stf`/`sti` at their offsets 0 8 16 24 32 40 (4.8). Line 12: the two calls, the printf slot
# s1 of 16 bytes; dims released at the end (rule 16 (a)). nomOf: rule 18's second example
# exactly, then `ret 1 f5`. Data: the slay of Dim first (its label at its first la, rule 38).
LIR12['struct_rule18'] = J(
    'func .main main 0:1:1 0 0', 'slot s1 16 8',
    'li i.R 2', 'la p.L d1', 'li i.rk 1', 'li i.C 1',
    'rcall sea_arr_new_s 0:11 1 p.dims 4 p.L i.rk i.R i.C',
    'ldp p.D p.dims - 0 40',
    'li i.O0 0', 'padd p.E0 p.D i.O0',
    'la p.a d2', 'retain p.a', 'stp p.a p.E0 - 0 0',
    'lf f.n0 #3FF8000000000000', 'stf f.n0 p.E0 - 0 8',
    'lf f.t0 #3FE0000000000000', 'stf f.t0 p.E0 - 0 16',
    'la p.d0 d3', 'retain p.d0', 'stp p.d0 p.E0 - 0 24',
    'li i.g0 1', 'sti i.g0 p.E0 - 0 32',
    'lf f.a0 #0000000000000000', 'stf f.a0 p.E0 - 0 40',
    'li i.O1 48', 'padd p.E1 p.D i.O1',
    'la p.b d4', 'retain p.b', 'stp p.b p.E1 - 0 0',
    'lf f.n1 #4004000000000000', 'stf f.n1 p.E1 - 0 8',
    'lf f.t1 #3FD0000000000000', 'stf f.t1 p.E1 - 0 16',
    'la p.d1 d5', 'retain p.d1', 'stp p.d1 p.E1 - 0 24',
    'li i.g1 2', 'sti i.g1 p.E1 - 0 32',
    'lf f.a1 #0000000000000000', 'stf f.a1 p.E1 - 0 40',
    'li i.k0 0', 'call nomOf 1 f.r0 2 p.dims i.k0',
    'li i.k1 1', 'call nomOf 1 f.r1 2 p.dims i.k1',
    'sa p.S s1', 'stf f.r0 p.S - 0 0', 'stf f.r1 p.S - 0 8', 'la p.F d6',
    'rcall sea_printf 0:12 0 2 p.F p.S', 'release p.dims', 'ret 0', 'endfunc',
    'func nomOf fn 0:1:1 2 p.dims i.d 1 f',
    'ldi i.X p.dims - 0 16', 'chkb i.d i.X 0 0:9', 'ldp p.D p.dims - 0 40',
    'ldf f.v p.D i.d 48 8', 'ret 1 f.v', 'endfunc',
    'slay d1 48 2', 'soff 0', 'soff 24', 'str d2 a', 'str d3 n', 'str d4 b', 'str d5 u',
    fmt_rec(6, ['fconv - - - g f', 'ftext %20', 'fconv - - - g f', 'ftext %0A']))
OUT2['struct_rule18'] = '1.5 2.5\n'
NAMES4G2.append('struct_rule18')


# ================================================================ struct_rule29 (rule 29's example, L15)
SEA2['struct_rule29'] = '''fn show(dims: Dim[]) {
    let nom = dims.nom
    let names = dims.name
    printf("%s %g %s %g\\n", names[0], nom[0], names[1], nom[1])
}
let d = Dim { name: "a", nom: 1.5, tol: 0.5, dist: "n", sign: 1, alpha: 0.0 }
let dims = filled(d, 2)
show(dims)
show(dims)
''' + DIM_DECL + '''// struct_rule29 -- DESIGN.md 3.6.6 rule 29's example on line 2 (dims a Dim[] in p1): L15 of an
// f64 field; line 3 the projection of a str field (sea_arr_new, R21; each borrowed ldp retained
// by its initializing store, R5); line 7 L2's filled of a struct value (R19: copied into each
// element with the retains of the borrowed source, rule 17)
'''
AST2['struct_rule29'] = '''
type 0:1:15 Dim v 0
param 0:1:9 dims 0 0
pname 0:2:9 nom
name 0:2:15 dims
dot 0:2:15 nom
let 0:2:5 0
pname 0:3:9 names
name 0:3:17 dims
dot 0:3:17 name
let 0:3:5 0
name 0:4:5 printf
str 0:4:12 %25s%20%25g%20%25s%20%25g%0A
name 0:4:29 names
int 0:4:35 0
index 0:4:29 1
name 0:4:39 nom
int 0:4:43 0
index 0:4:39 1
name 0:4:47 names
int 0:4:53 1
index 0:4:47 1
name 0:4:57 nom
int 0:4:61 1
index 0:4:57 1
call 0:4:5 5
cstmt 0:4:5
block 0:1:22 3
fn 0:1:1 show 0 1 0
pname 0:6:5 d
str 0:6:21 a
init 0:6:15 name
float 0:6:31 #3FF8000000000000
init 0:6:26 nom
float 0:6:41 #3FE0000000000000
init 0:6:36 tol
str 0:6:52 n
init 0:6:46 dist
int 0:6:63 1
init 0:6:57 sign
float 0:6:73 #0000000000000000
init 0:6:66 alpha
slit 0:6:9 Dim 6
let 0:6:1 0
pname 0:7:5 dims
name 0:7:12 filled
name 0:7:19 d
int 0:7:22 2
call 0:7:12 2
let 0:7:1 0
name 0:8:1 show
name 0:8:6 dims
call 0:8:1 1
cstmt 0:8:1
name 0:9:1 show
name 0:9:6 dims
call 0:9:1 1
cstmt 0:9:1
type 0:11:11 str s 0
field 0:11:5 name
type 0:12:10 f64 s 0
field 0:12:5 nom
type 0:13:10 f64 s 0
field 0:13:5 tol
type 0:14:11 str s 0
field 0:14:5 dist
type 0:15:11 i64 s 0
field 0:15:5 sign
type 0:16:12 f64 s 0
field 0:16:5 alpha
struct 0:10:1 Dim 6
prog 6
'''
# sea.hir1: Dim 10 (`loc d`), Dim[] 11 (`loc dims`), in show f64[] 12 (`loc nom`) and str[] 13
# (`loc names`); `filled(d, 2)` is `lib filled` of type Dim[] (2.6.2 "Readings fixed by 4g");
# `dims.nom` and `dims.name` are proj 1 and proj 0 (fields of scalar and str type, LANGUAGE.md
# 4.7) at the dot's position, of types f64[] and str[].
HIR12['struct_rule29'] = DIM_FD + '''tvec 11 10
tvec 12 4
tvec 13 5
fn 1 .main main 1 0 2 0:1:1
loc d 10 let 0:6:5
loc dims 11 let 0:7:5
cs 0:6:21 5 a
cf 0:6:31 4 #3FF8000000000000
cf 0:6:41 4 #3FE0000000000000
cs 0:6:52 5 n
ci 0:6:63 3 1
cf 0:6:73 4 #0000000000000000
slit 0:6:9 10 6
bind 0:6:1 1
lv 0:7:19 10 1
ci 0:7:22 3 2
lib 0:7:12 11 filled 2
bind 0:7:1 2
lv 0:8:6 11 2
call 0:8:1 1 2 1
eval 0:8:1
lv 0:9:6 11 2
call 0:9:1 1 2 1
eval 0:9:1
block 0:1:1 4
end
fn 2 show fn 1 1 2 0:1:1
par dims 11 val
loc nom 12 let 0:2:9
loc names 13 let 0:3:9
lv 0:2:15 11 1
proj 0:2:15 12 1
bind 0:2:5 2
lv 0:3:17 11 1
proj 0:3:17 13 0
bind 0:3:5 3
lv 0:4:29 13 3
ci 0:4:35 3 0
idx 0:4:29 5 1
fconv 0:4:12 1 - - - s
ftext 0:4:12 1 %20
lv 0:4:39 12 2
ci 0:4:43 3 0
idx 0:4:39 4 1
fconv 0:4:12 1 - - - g
ftext 0:4:12 1 %20
lv 0:4:47 13 3
ci 0:4:53 3 1
idx 0:4:47 5 1
fconv 0:4:12 1 - - - s
ftext 0:4:12 1 %20
lv 0:4:57 12 2
ci 0:4:61 3 1
idx 0:4:57 4 1
fconv 0:4:12 1 - - - g
ftext 0:4:12 1 %0A
fmt 0:4:12 1 8
lib 0:4:5 1 printf 1
eval 0:4:5
block 0:1:22 3
end
'''


def L15(F, P, pre, v, FT, TF, sF, TPF, TPS, sS, off):
    """L15 (rule 29) `proj` of a vector v of structs (element size sS, field at off of type TF,
    element size sF): `xblk P FT n` with `tmp V = v`; `tmp N = ext(V, 0)`; `tmp R = anew P FT 0 1
    (lv N)`; `tmp DR = data(R)` (TPF the tptr of the field type); `tmp DV = data(V)` (TPS the tptr
    of the struct); loop(N; K) { `est P sF 0 (eld P TF sS off (lv DV) (lv K)) (lv DR) (lv K)` }
    (R24); value `lv R`."""
    x = Ctx(F, P, pre)
    st = [x.tmp('V', v), x.tmp('N', ext(P, 0, x.lvl('V'))),
          x.tmp('R', anew(P, FT, 0, [x.lvl('N')])),
          x.tmp('DR', adat(P, TPF, x.lvl('R'))), x.tmp('DV', adat(P, TPS, x.lvl('V')))]
    st += x.loop('N', 'Z', 'O', 'L', 'K', lambda: [
        estS(P, sF, 0, eldS(P, TF, sS, off, x.lvl('DV'), x.klv('K')), x.lvl('DR'), x.klv('K'))])
    return xblk(P, st, x.lvl('R'))


def hirl_struct_rule29():
    """sea.hirl: tptr 14 10 (filled's data in .main), 15 4 and 16 5 (the data of the projected
    f64[] and str[] in show, in order of first reference). .main: L2 of filled with a struct value
    (`tmp V = lv d`, `tmp R`, `tmp A`, `tmp D`, loop(R; K) { `est 48 0 (lv V) (lv D) (lv K)` }, R19's
    copy into a fresh address). show: L15 for `dims.nom` (P 0:2:15) and `dims.name` (P 0:3:17)."""
    tab = type_table(HIR12['struct_rule29'])
    s = layout(tab, 10)[0]
    F1, F2 = Fn(), Fn()
    P = '0:7:12'
    x = Ctx(F1, P, 'f')
    st = [x.tmp('V', lv('0:7:19', 10, 1)), x.tmp('R', ci('0:7:22', 2)),
          x.tmp('A', anew(P, 11, 0, [x.lvl('R')])), x.tmp('D', adat(P, 14, x.lvl('A')))]
    st += x.loop('R', 'Z', 'O', 'L', 'K', lambda: [
        estS(P, s, 0, x.lvl('V'), x.lvl('D'), x.klv('K'))])
    fill = xblk(P, st, x.lvl('A'))
    e_main = [(['lv 0:7:19 10 1', 'ci 0:7:22 3 2', 'lib 0:7:12 11 filled 2'], cat(fill))]
    off_nom, t_nom = field_off(tab, 10, ['nom'])
    off_name, t_name = field_off(tab, 10, ['name'])
    p1 = L15(F2, '0:2:15', 'n', lv('0:2:15', 11, 1), 12, t_nom, 8, 15, 14, s, off_nom)
    p2 = L15(F2, '0:3:17', 'm', lv('0:3:17', 11, 1), 13, t_name, 8, 16, 14, s, off_name)
    e_show = [(['lv 0:2:15 11 1', 'proj 0:2:15 12 1'], cat(p1)),
              (['lv 0:3:17 11 1', 'proj 0:3:17 13 0'], cat(p2))]
    return make_hirl(HIR12['struct_rule29'], ['tptr 14 10', 'tptr 15 4', 'tptr 16 5'],
                     {1: (F1, e_main), 2: (F2, e_show)})


HIRL2['struct_rule29'] = hirl_struct_rule29
# sea.lir1. .main: d's slot s1 (48 bytes) and the slit written into it (27 (b), (g); each str
# `la` retained). Line 7, L2 (rule 17's struct filled): V the alias of d's home (T1), `li R 2`,
# the arrnew of Dim[] (la of the slay, rank, `li C 1`, sea_arr_new_s) into dims (T3), the data,
# loop(R; K) { R19's copy into a fresh address: `li S 48`, `imul T K S`, `padd E D T`, `li N 48`,
# `mcopy E V N`, then V borrowed: `ldp R E - 0 o`, `retain R` for o = 0, 24 }; nothing after
# `endif` (V borrowed). The two calls; at the end dims released, then d's reference fields
# (rule 16 (a), reverse order of declaration; 15 (g)'s ascending offsets). show: rule 29's
# example exactly (line 2), then L15 of the str field (line 3: sea_arr_new with ek 4, R21; `ldp`
# of the field at off 0 with sc 48, retained before its initializing `stp`, R5); line 4 four rule
# 18 reads (constant indices by `li`), the slot s1 of 32 bytes; names and nom released (rule 16).
LIR12['struct_rule29'] = J(
    'func .main main 0:1:1 0 0', 'slot s1 48 8',
    'sa p.d s1',
    'la p.a d1', 'retain p.a', 'stp p.a p.d - 0 0',
    'lf f.n #3FF8000000000000', 'stf f.n p.d - 0 8',
    'lf f.t #3FE0000000000000', 'stf f.t p.d - 0 16',
    'la p.s d2', 'retain p.s', 'stp p.s p.d - 0 24',
    'li i.g 1', 'sti i.g p.d - 0 32',
    'lf f.al #0000000000000000', 'stf f.al p.d - 0 40',
    'li i.R 2', 'la p.L d3', 'li i.rk 1', 'li i.C 1',
    'rcall sea_arr_new_s 0:7 1 p.dims 4 p.L i.rk i.R i.C',
    'ldp p.D p.dims - 0 40',
    'li i.Z 0', 'icmp gt i.gt i.R i.Z', 'if 1 i.gt', 'li i.O 1', 'isub i.Lst i.R i.O',
    'loop 2 i.K i.Z i.Lst i.O',
    'li i.S 48', 'imul i.T i.K i.S', 'padd p.E p.D i.T', 'li i.Nb 48', 'mcopy p.E p.d i.Nb',
    'ldp p.r0 p.E - 0 0', 'retain p.r0', 'ldp p.r1 p.E - 0 24', 'retain p.r1',
    'endloop 2', 'endif 1',
    'call show 0 1 p.dims', 'call show 0 1 p.dims',
    'release p.dims', 'ldp p.x0 p.d - 0 0', 'release p.x0', 'ldp p.x1 p.d - 0 24',
    'release p.x1', 'ret 0', 'endfunc',
    'func show fn 0:1:1 1 p.dims 0', 'slot s1 32 8',
    'ldi i.N p.dims - 0 16', 'li i.ek 1', 'li i.rk 1', 'li i.C 1',
    'rcall sea_arr_new_u 0:2 1 p.nom 4 i.ek i.rk i.N i.C', 'ldp p.DR p.nom - 0 40',
    'ldp p.DV p.dims - 0 40',
    'li i.Z 0', 'icmp gt i.g i.N i.Z', 'if 1 i.g', 'li i.O 1', 'isub i.L i.N i.O',
    'loop 2 i.K i.Z i.L i.O', 'ldf f.x p.DV i.K 48 8', 'stf f.x p.DR i.K 8 0', 'endloop 2',
    'endif 1',
    'ldi i.N2 p.dims - 0 16', 'li i.ek2 4', 'li i.rk2 1', 'li i.C2 1',
    'rcall sea_arr_new 0:3 1 p.names 4 i.ek2 i.rk2 i.N2 i.C2',
    'ldp p.DR2 p.names - 0 40', 'ldp p.DV2 p.dims - 0 40',
    'li i.Z2 0', 'icmp gt i.g2 i.N2 i.Z2', 'if 3 i.g2', 'li i.O2 1', 'isub i.L2 i.N2 i.O2',
    'loop 4 i.K2 i.Z2 i.L2 i.O2', 'ldp p.v2 p.DV2 i.K2 48 0', 'retain p.v2',
    'stp p.v2 p.DR2 i.K2 8 0', 'endloop 4', 'endif 3',
    'li i.k0 0', 'ldi i.e0 p.names - 0 16', 'chkb i.k0 i.e0 0 0:4', 'ldp p.d0 p.names - 0 40',
    'ldp p.v0 p.d0 i.k0 8 0',
    'li i.k1 0', 'ldi i.e1 p.nom - 0 16', 'chkb i.k1 i.e1 0 0:4', 'ldp p.d1 p.nom - 0 40',
    'ldf f.v1 p.d1 i.k1 8 0',
    'li i.k2 1', 'ldi i.e2 p.names - 0 16', 'chkb i.k2 i.e2 0 0:4', 'ldp p.d2 p.names - 0 40',
    'ldp p.v3 p.d2 i.k2 8 0',
    'li i.k3 1', 'ldi i.e3 p.nom - 0 16', 'chkb i.k3 i.e3 0 0:4', 'ldp p.d3 p.nom - 0 40',
    'ldf f.v4 p.d3 i.k3 8 0',
    'sa p.S s1', 'stp p.v0 p.S - 0 0', 'stf f.v1 p.S - 0 8', 'stp p.v3 p.S - 0 16',
    'stf f.v4 p.S - 0 24', 'la p.F d4', 'rcall sea_printf 0:4 0 2 p.F p.S',
    'release p.names', 'release p.nom', 'ret 0', 'endfunc',
    'str d1 a', 'str d2 n', 'slay d3 48 2', 'soff 0', 'soff 24',
    fmt_rec(4, ['fconv - - - s p', 'ftext %20', 'fconv - - - g f', 'ftext %20', 'fconv - - - s p',
                'ftext %20', 'fconv - - - g f', 'ftext %0A']))
OUT2['struct_rule29'] = 'a 1.5 a 1.5\na 1.5 a 1.5\n'
NAMES4G2.append('struct_rule29')


# ================================================================ struct_l17 (L17 on a struct local)
SEA2['struct_l17'] = '''fn edit(k: i64) -> i64 {
    let l0 = Lim { lo: 0.0, hi: 1.0 }
    var s = S { n: k, name: "a", v: zeros(2), lim: l0 }
    s.n = s.n + 1
    s.n += 2
    s.name = "b"
    s.lim.hi = 3.0
    s.v[k] = 9.0
    let l1 = s.lim
    s.lim = Lim { lo: 0.5, hi: 0.75 }
    let l2 = s.lim
    printf("%d %s %g %g %g %g\\n", s.n, s.name, s.v[0], s.v[1], l1.hi, l2.lo)
    return s.n
}
printf("%d\\n", edit(0))
printf("%d\\n", edit(1))
struct Lim {
    lo: f64
    hi: f64
}
struct S {
    n: i64
    name: str
    v: f64[]
    lim: Lim
}
// struct_l17 -- DESIGN.md 3.5.9 L17 on a struct local s (S: size 40, n@0 name@8 v@16 lim@24): a
// scalar field (line 4), the compound form (line 5), a str field (line 6, R17), a nested field
// (line 7, R24's summed offset 32), an element of an array field (line 8: R23's memory form of cow
// at s+16, the est's adat that cow's register), a struct field from a slit (line 10: the slit its
// own temporary home, rule 27 (d)'s copy, R19); lines 9 and 11 copy the field lim (rule 27 (b))
'''
AST2['struct_l17'] = '''
type 0:1:12 i64 s 0
param 0:1:9 k 0 0
type 0:1:20 i64 s 0
pname 0:2:9 l0
float 0:2:24 #0000000000000000
init 0:2:20 lo
float 0:2:33 #3FF0000000000000
init 0:2:29 hi
slit 0:2:14 Lim 2
let 0:2:5 0
pname 0:3:9 s
name 0:3:20 k
init 0:3:17 n
str 0:3:29 a
init 0:3:23 name
name 0:3:37 zeros
int 0:3:43 2
call 0:3:37 1
init 0:3:34 v
name 0:3:52 l0
init 0:3:47 lim
slit 0:3:13 S 4
var 0:3:5 0
name 0:4:5 s
dot 0:4:5 n
name 0:4:11 s
dot 0:4:11 n
int 0:4:17 1
bin 0:4:11 add
asg 0:4:5 set
name 0:5:5 s
dot 0:5:5 n
int 0:5:12 2
asg 0:5:5 add
name 0:6:5 s
dot 0:6:5 name
str 0:6:14 b
asg 0:6:5 set
name 0:7:5 s
dot 0:7:5 lim
dot 0:7:5 hi
float 0:7:16 #4008000000000000
asg 0:7:5 set
name 0:8:5 s
dot 0:8:5 v
name 0:8:9 k
index 0:8:5 1
float 0:8:14 #4022000000000000
asg 0:8:5 set
pname 0:9:9 l1
name 0:9:14 s
dot 0:9:14 lim
let 0:9:5 0
name 0:10:5 s
dot 0:10:5 lim
float 0:10:23 #3FE0000000000000
init 0:10:19 lo
float 0:10:32 #3FE8000000000000
init 0:10:28 hi
slit 0:10:13 Lim 2
asg 0:10:5 set
pname 0:11:9 l2
name 0:11:14 s
dot 0:11:14 lim
let 0:11:5 0
name 0:12:5 printf
str 0:12:12 %25d%20%25s%20%25g%20%25g%20%25g%20%25g%0A
name 0:12:35 s
dot 0:12:35 n
name 0:12:40 s
dot 0:12:40 name
name 0:12:48 s
dot 0:12:48 v
int 0:12:52 0
index 0:12:48 1
name 0:12:56 s
dot 0:12:56 v
int 0:12:60 1
index 0:12:56 1
name 0:12:64 l1
dot 0:12:64 hi
name 0:12:71 l2
dot 0:12:71 lo
call 0:12:5 7
cstmt 0:12:5
name 0:13:12 s
dot 0:13:12 n
return 0:13:5 1
block 0:1:24 12
fn 0:1:1 edit 0 1 1
name 0:15:1 printf
str 0:15:8 %25d%0A
name 0:15:16 edit
int 0:15:21 0
call 0:15:16 1
call 0:15:1 2
cstmt 0:15:1
name 0:16:1 printf
str 0:16:8 %25d%0A
name 0:16:16 edit
int 0:16:21 1
call 0:16:16 1
call 0:16:1 2
cstmt 0:16:1
type 0:18:9 f64 s 0
field 0:18:5 lo
type 0:19:9 f64 s 0
field 0:19:5 hi
struct 0:17:1 Lim 2
type 0:22:8 i64 s 0
field 0:22:5 n
type 0:23:11 str s 0
field 0:23:5 name
type 0:24:8 f64 v 0
field 0:24:5 v
type 0:25:10 Lim s 0
field 0:25:5 lim
struct 0:21:1 S 4
prog 5
'''
# sea.hir1: Lim 10 (`loc l0`), f64[] 11 and S 12 (`loc s`; its field types first, 3.5.1); every
# slit's values in declaration order (= source order: no seq); the targets are fld chains (and the
# idx of line 8) of the dot positions; `zeros(2)` is `lib zeros` (L1 rewrites it).
HIR12['struct_l17'] = '''
tstruct 10 Lim 2
fd lo 4
fd hi 4
tvec 11 4
tstruct 12 S 4
fd n 3
fd name 5
fd v 11
fd lim 10
fn 1 .main main 1 0 0 0:1:1
ci 0:15:21 3 0
call 0:15:16 3 2 1
fconv 0:15:8 1 - - - d
ftext 0:15:8 1 %0A
fmt 0:15:8 1 2
lib 0:15:1 1 printf 1
eval 0:15:1
ci 0:16:21 3 1
call 0:16:16 3 2 1
fconv 0:16:8 1 - - - d
ftext 0:16:8 1 %0A
fmt 0:16:8 1 2
lib 0:16:1 1 printf 1
eval 0:16:1
block 0:1:1 2
end
fn 2 edit fn 3 1 4 0:1:1
par k 3 val
loc l0 10 let 0:2:9
loc s 12 var 0:3:9
loc l1 10 let 0:9:9
loc l2 10 let 0:11:9
cf 0:2:24 4 #0000000000000000
cf 0:2:33 4 #3FF0000000000000
slit 0:2:14 10 2
bind 0:2:5 2
lv 0:3:20 3 1
cs 0:3:29 5 a
ci 0:3:43 3 2
lib 0:3:37 11 zeros 1
lv 0:3:52 10 2
slit 0:3:13 12 4
bind 0:3:5 3
lv 0:4:5 12 3
fld 0:4:5 3 0
lv 0:4:11 12 3
fld 0:4:11 3 0
ci 0:4:17 3 1
bin 0:4:11 3 add
asg 0:4:5 set
lv 0:5:5 12 3
fld 0:5:5 3 0
ci 0:5:12 3 2
asg 0:5:5 add
lv 0:6:5 12 3
fld 0:6:5 5 1
cs 0:6:14 5 b
asg 0:6:5 set
lv 0:7:5 12 3
fld 0:7:5 10 3
fld 0:7:5 4 1
cf 0:7:16 4 #4008000000000000
asg 0:7:5 set
lv 0:8:5 12 3
fld 0:8:5 11 2
lv 0:8:9 3 1
idx 0:8:5 4 1
cf 0:8:14 4 #4022000000000000
asg 0:8:5 set
lv 0:9:14 12 3
fld 0:9:14 10 3
bind 0:9:5 4
lv 0:10:5 12 3
fld 0:10:5 10 3
cf 0:10:23 4 #3FE0000000000000
cf 0:10:32 4 #3FE8000000000000
slit 0:10:13 10 2
asg 0:10:5 set
lv 0:11:14 12 3
fld 0:11:14 10 3
bind 0:11:5 5
lv 0:12:35 12 3
fld 0:12:35 3 0
fconv 0:12:12 1 - - - d
ftext 0:12:12 1 %20
lv 0:12:40 12 3
fld 0:12:40 5 1
fconv 0:12:12 1 - - - s
ftext 0:12:12 1 %20
lv 0:12:48 12 3
fld 0:12:48 11 2
ci 0:12:52 3 0
idx 0:12:48 4 1
fconv 0:12:12 1 - - - g
ftext 0:12:12 1 %20
lv 0:12:56 12 3
fld 0:12:56 11 2
ci 0:12:60 3 1
idx 0:12:56 4 1
fconv 0:12:12 1 - - - g
ftext 0:12:12 1 %20
lv 0:12:64 10 4
fld 0:12:64 4 1
fconv 0:12:12 1 - - - g
ftext 0:12:12 1 %20
lv 0:12:71 10 5
fld 0:12:71 4 0
fconv 0:12:12 1 - - - g
ftext 0:12:12 1 %0A
fmt 0:12:12 1 12
lib 0:12:5 1 printf 1
eval 0:12:5
lv 0:13:12 12 3
fld 0:13:12 3 0
ret 0:13:5 1
block 0:1:24 12
end
'''


def hirl_struct_l17():
    """sea.hirl: tptr 13 12 (the home of s, line 4's adat) and 14 4 (the data of the field v, line
    8). Line 3: L1 of zeros (P the lib's position). Lines 4-8 and 10: L17 (P the asg's position)
    with the struct root s (no root array, no step 2): step 6's address `adat (lv s)` (R21) with
    X `ci 0` and R24's sc = s(S) = 40, off the field's offset (line 7: 24 + 8); line 5 the compound
    form; line 8 the field array as `tmp B1 = fld (lv s) v` for the check (step 4), `cow (fld (lv s)
    v)` (step 5, R23) and the est's `adat (fld (lv s) v)` right after it; line 10 the slit as its
    own temporary home `tmp Vv` (step 1)."""
    F = Fn()
    tab = type_table(HIR12['struct_l17'])
    sS = layout(tab, 12)[0]
    assert sS == 40 and layout(tab, 12)[2] == [8, 16] and layout(tab, 10)[0] == 16
    o_n, _ = field_off(tab, 12, ['n'])
    o_name, _ = field_off(tab, 12, ['name'])
    o_v, _ = field_off(tab, 12, ['v'])
    o_lim, _ = field_off(tab, 12, ['lim'])
    o_hi, _ = field_off(tab, 12, ['lim', 'hi'])
    assert (o_n, o_name, o_v, o_lim, o_hi) == (0, 8, 16, 24, 32)

    def s_(P):
        return lv(P, 12, 3)

    def home(P):
        return adat(P, 13, s_(P))

    def simple(P, pre, value, off):
        x = Ctx(F, P, pre)
        return block(P, [x.tmp('Vv', value), estS(P, sS, off, x.lvl('Vv'), home(P), ci(P, 0))])

    eds = [(['ci 0:3:43 3 2', 'lib 0:3:37 11 zeros 1'], cat(anew('0:3:37', 11, 1, [ci('0:3:43', 2)])))]
    P = '0:4:5'
    v4 = bin_('0:4:11', 3, 'add', fld('0:4:11', 3, 0, lv('0:4:11', 12, 3)), ci('0:4:17', 1))
    eds.append((lines(HIR12['struct_l17'])[lines(HIR12['struct_l17']).index('lv 0:4:5 12 3'):
                                            lines(HIR12['struct_l17']).index('asg 0:4:5 set') + 1],
                cat(simple(P, 'a', v4, o_n))))
    P = '0:5:5'
    x = Ctx(F, P, 'b')
    rd = x.tmp('T0', fld(P, 3, 0, s_(P)))
    vv = x.tmp('Vv', ci('0:5:12', 2))
    r0 = x.tmp('R0', xblk(P, [rd, vv], bin_(P, 3, 'add', x.lvl('T0'), x.lvl('Vv'))))
    eds.append((['lv 0:5:5 12 3', 'fld 0:5:5 3 0', 'ci 0:5:12 3 2', 'asg 0:5:5 add'],
                cat(block(P, [r0, estS(P, sS, o_n, x.lvl('R0'), home(P), ci(P, 0))]))))
    eds.append((['lv 0:6:5 12 3', 'fld 0:6:5 5 1', 'cs 0:6:14 5 b', 'asg 0:6:5 set'],
                cat(simple('0:6:5', 'c', cs_('0:6:14', 'b'), o_name))))
    eds.append((['lv 0:7:5 12 3', 'fld 0:7:5 10 3', 'fld 0:7:5 4 1', 'cf 0:7:16 4 #4008000000000000',
                 'asg 0:7:5 set'], cat(simple('0:7:5', 'd', cf('0:7:16', '#4008000000000000'), o_hi))))
    P = '0:8:5'
    x = Ctx(F, P, 'e')
    fv = lambda: fld(P, 11, 2, s_(P))
    st = [x.tmp('Vv', cf('0:8:14', '#4022000000000000')), x.tmp('I0', lv('0:8:9', 3, 1)),
          x.tmp('B1', fv()), x.tmp('X0', ext(P, 0, x.lvl('B1'))),
          chkb(P, 0, x.lvl('I0'), x.lvl('X0')), cowS(P, fv()),
          estS(P, 8, 0, x.lvl('Vv'), adat(P, 14, fv()), x.lvl('I0'))]
    eds.append((['lv 0:8:5 12 3', 'fld 0:8:5 11 2', 'lv 0:8:9 3 1', 'idx 0:8:5 4 1',
                 'cf 0:8:14 4 #4022000000000000', 'asg 0:8:5 set'], cat(block(P, st))))
    sl = N(['cf 0:10:23 4 #3FE0000000000000', 'cf 0:10:32 4 #3FE8000000000000',
            'slit 0:10:13 10 2'], 10)
    eds.append((['lv 0:10:5 12 3', 'fld 0:10:5 10 3'] + sl[0] + ['asg 0:10:5 set'],
                cat(simple('0:10:5', 'f', sl, o_lim))))
    return make_hirl(HIR12['struct_l17'], ['tptr 13 12', 'tptr 14 4'], {2: (F, eds)})


HIRL2['struct_l17'] = hirl_struct_l17
# sea.lir1. .main: each argument `li`, the call (one i64 result), a printf slot of 8 bytes. edit:
# line 2 rule 27 (b), (g) into l0's slot s1 (16 bytes); line 3 into s's slot s2 (40 bytes): n
# `sti` of k, name `la` retained (rule 15 (a)), v L1's anew (arrnewz: `li 2` first, then `li K 1`,
# rank, `li C 1`, sea_arr_new; owned, moved by its stp), lim the borrowed l0 copied at its field's
# address (`li O 24`, `padd`, `li N 16`, `mcopy`; Lim holds no reference, so no retains). Line 4:
# s.n (27 (e)), `iaddc` (rule 1, checked), then the est with a `ci 0` index at s's home (R3, R24):
# `sti V s - 0 0`. Line 5: the read T0, `li 2`, `iaddc` into R0, the store. Line 6: R17 (a): "b"
# retained right before `ldp O s - 0 8`, `stp`, `release O`. Line 7: `stf V s - 0 32`. Line 8:
# Vv's `lf`, I0 the alias of k, B1 `ldp B s - 0 16`, its extent, `chkb` d 0, the memory form of
# cow at s+16 (R23: `ldp A`, count, `icmp ne`, `if 1`, sea_arr_unique, `stp N s - 0 16`, `mov`),
# the est's data from A (R23: the adat right after its cow), `stf V D k 8 0`. Line 9: `sa` of l1's
# slot s3, the field's address (27 (e)), `li N 16`, `mcopy` (27 (b), (c); no retains). Line 10:
# the slit in its own temporary slot s4 (27 (a), (g)), then R19 into a home that is not fresh:
# E = s + 24 (`li O 24`, `padd`), the owned slit moved (no retains), no old reference to release
# (Lim has none), `li N 16`, `mcopy`. Line 11 as line 9 (slot s5). Line 12: the six arguments
# (s.v[k] by rule 18: the field `ldp`, the index `li`, extent, `chkb`, data, `ldf`), the slot s6 of
# 48 bytes. Line 13: s.n, then rule 16 (c): l2, l1, s, l0 in reverse order, only s holds counts
# (`ldp`/`release` of name and v, ascending offsets, 15 (g)), `ret 1`.
LIR12['struct_l17'] = J(
    'func .main main 0:1:1 0 0', 'slot s1 8 8', 'slot s2 8 8',
    'li i.z 0', 'call edit 1 i.r1 1 i.z', 'sa p.S1 s1', 'sti i.r1 p.S1 - 0 0', 'la p.F1 d1',
    'rcall sea_printf 0:15 0 2 p.F1 p.S1',
    'li i.o 1', 'call edit 1 i.r2 1 i.o', 'sa p.S2 s2', 'sti i.r2 p.S2 - 0 0', 'la p.F2 d2',
    'rcall sea_printf 0:16 0 2 p.F2 p.S2', 'ret 0', 'endfunc',
    'func edit fn 0:1:1 1 i.k 1 i',
    'slot s1 16 8', 'slot s2 40 8', 'slot s3 16 8', 'slot s4 16 8', 'slot s5 16 8', 'slot s6 48 8',
    'sa p.l0 s1', 'lf f.lo #0000000000000000', 'stf f.lo p.l0 - 0 0',
    'lf f.hi #3FF0000000000000', 'stf f.hi p.l0 - 0 8',
    'sa p.s s2', 'sti i.k p.s - 0 0', 'la p.a d3', 'retain p.a', 'stp p.a p.s - 0 8',
    'li i.two 2', 'li i.ek 1', 'li i.rk 1', 'li i.C 1',
    'rcall sea_arr_new 0:3 1 p.v 4 i.ek i.rk i.two i.C', 'stp p.v p.s - 0 16',
    'li i.Ol 24', 'padd p.El p.s i.Ol', 'li i.Nl 16', 'mcopy p.El p.l0 i.Nl',
    'ldi i.n4 p.s - 0 0', 'li i.one 1', 'iaddc i.V4 i.n4 i.one 0:4', 'sti i.V4 p.s - 0 0',
    'ldi i.T5 p.s - 0 0', 'li i.c2 2', 'iaddc i.R5 i.T5 i.c2 0:5', 'sti i.R5 p.s - 0 0',
    'la p.b d4', 'retain p.b', 'ldp p.O6 p.s - 0 8', 'stp p.b p.s - 0 8', 'release p.O6',
    'lf f.h7 #4008000000000000', 'stf f.h7 p.s - 0 32',
    'lf f.e8 #4022000000000000', 'ldp p.B8 p.s - 0 16', 'ldi i.X8 p.B8 - 0 16',
    'chkb i.k i.X8 0 0:8',
    'ldp p.A8 p.s - 0 16', 'ldi i.C8 p.A8 - 0 0', 'li i.O8 1', 'icmp ne i.S8 i.C8 i.O8',
    'if 1 i.S8', 'rcall sea_arr_unique 0:8 1 p.N8 1 p.A8', 'stp p.N8 p.s - 0 16',
    'mov p.A8 p.N8', 'endif 1', 'ldp p.D8 p.A8 - 0 40', 'stf f.e8 p.D8 i.k 8 0',
    'sa p.l1 s3', 'li i.O9 24', 'padd p.R9 p.s i.O9', 'li i.N9 16', 'mcopy p.l1 p.R9 i.N9',
    'sa p.V10 s4', 'lf f.lo10 #3FE0000000000000', 'stf f.lo10 p.V10 - 0 0',
    'lf f.hi10 #3FE8000000000000', 'stf f.hi10 p.V10 - 0 8',
    'li i.O10 24', 'padd p.E10 p.s i.O10', 'li i.N10 16', 'mcopy p.E10 p.V10 i.N10',
    'sa p.l2 s5', 'li i.O11 24', 'padd p.R11 p.s i.O11', 'li i.N11 16', 'mcopy p.l2 p.R11 i.N11',
    'ldi i.a12 p.s - 0 0', 'ldp p.b12 p.s - 0 8',
    'ldp p.B12 p.s - 0 16', 'li i.k0 0', 'ldi i.e0 p.B12 - 0 16', 'chkb i.k0 i.e0 0 0:12',
    'ldp p.d0 p.B12 - 0 40', 'ldf f.v0 p.d0 i.k0 8 0',
    'ldp p.B13 p.s - 0 16', 'li i.k1 1', 'ldi i.e1 p.B13 - 0 16', 'chkb i.k1 i.e1 0 0:12',
    'ldp p.d1 p.B13 - 0 40', 'ldf f.v1 p.d1 i.k1 8 0',
    'ldf f.h12 p.l1 - 0 8', 'ldf f.lo12 p.l2 - 0 0',
    'sa p.S s6', 'sti i.a12 p.S - 0 0', 'stp p.b12 p.S - 0 8', 'stf f.v0 p.S - 0 16',
    'stf f.v1 p.S - 0 24', 'stf f.h12 p.S - 0 32', 'stf f.lo12 p.S - 0 40', 'la p.F d5',
    'rcall sea_printf 0:12 0 2 p.F p.S',
    'ldi i.r13 p.s - 0 0', 'ldp p.x0 p.s - 0 8', 'release p.x0', 'ldp p.x1 p.s - 0 16',
    'release p.x1', 'ret 1 i.r13', 'endfunc',
    fmt_rec(1, ['fconv - - - d i', 'ftext %0A']), fmt_rec(2, ['fconv - - - d i', 'ftext %0A']),
    'str d3 a', 'str d4 b',
    fmt_rec(5, ['fconv - - - d i', 'ftext %20', 'fconv - - - s p', 'ftext %20', 'fconv - - - g f',
                'ftext %20', 'fconv - - - g f', 'ftext %20', 'fconv - - - g f', 'ftext %20',
                'fconv - - - g f', 'ftext %0A']))
# edit(0): n 0 -> 1 -> 3, name "b", lim.hi 3, v[0] = 9; l1 = {0, 3}; lim = {0.5, 0.75}, l2.lo 0.5
# (LANGUAGE.md 4.6: a struct is a value, l1 keeps the copy); edit(1) the same with n 4 and v[1].
OUT2['struct_l17'] = '3 b 9 0 3 0.5\n3\n4 b 0 9 3 0.5\n4\n'
NAMES4G2.append('struct_l17')


# ================================================================ struct_l17_path (L17 through elements, a ref root)
SEA2['struct_l17_path'] = '''fn upd(ref ds: D[], i: i64, x: f64) {
    ds[i].w[0] = x
    ds[i].lim = T { lo: x, hi: 2.0 }
    ds[i].lim.hi = x + 1.0
    ds[i].name = "z"
}
let t0 = T { lo: 0.0, hi: 1.0 }
var ds = [D { name: "a", w: zeros(1), lim: t0 }, D { name: "b", w: zeros(1), lim: t0 }]
let keep = ds
upd(ref ds, 1, 7.0)
upd(ref ds, 0, 8.0)
printf("%s %g %g %g\\n", ds[1].name, ds[1].w[0], ds[1].lim.lo, ds[1].lim.hi)
printf("%s %g %s\\n", keep[1].name, keep[1].w[0], ds[0].name)
struct T {
    lo: f64
    hi: f64
}
struct D {
    name: str
    w: f64[]
    lim: T
}
// struct_l17_path -- DESIGN.md 3.5.9 L17 through the elements of a ref parameter ds (D: size 32,
// name@0 w@8 lim@16): line 2 a path through two arrays (step 2's `tmp B = lv ds`, the checks with
// the element's address and the field array, the cow of ds, then D' and E' from that cow's
// register, lead decision L-n, and R23's cow of the field w at E'+8); line 3 a slit into a field at
// an offset of an element (R19: sc 32, off 16, the copy form); line 4 a nested numeric field
// (R24's sc 32, off 24); line 5 a str field (R17); `keep` holds the old elements (LANGUAGE.md 4.6)
'''
AST2['struct_l17_path'] = '''
type 0:1:16 D v 0
param 0:1:8 ds 1 0
type 0:1:24 i64 s 0
param 0:1:21 i 0 0
type 0:1:32 f64 s 0
param 0:1:29 x 0 0
name 0:2:5 ds
name 0:2:8 i
index 0:2:5 1
dot 0:2:5 w
int 0:2:13 0
index 0:2:5 1
name 0:2:18 x
asg 0:2:5 set
name 0:3:5 ds
name 0:3:8 i
index 0:3:5 1
dot 0:3:5 lim
name 0:3:25 x
init 0:3:21 lo
float 0:3:32 #4000000000000000
init 0:3:28 hi
slit 0:3:17 T 2
asg 0:3:5 set
name 0:4:5 ds
name 0:4:8 i
index 0:4:5 1
dot 0:4:5 lim
dot 0:4:5 hi
name 0:4:20 x
float 0:4:24 #3FF0000000000000
bin 0:4:20 add
asg 0:4:5 set
name 0:5:5 ds
name 0:5:8 i
index 0:5:5 1
dot 0:5:5 name
str 0:5:18 z
asg 0:5:5 set
block 0:1:37 4
fn 0:1:1 upd 0 3 0
pname 0:7:5 t0
float 0:7:18 #0000000000000000
init 0:7:14 lo
float 0:7:27 #3FF0000000000000
init 0:7:23 hi
slit 0:7:10 T 2
let 0:7:1 0
pname 0:8:5 ds
str 0:8:21 a
init 0:8:15 name
name 0:8:29 zeros
int 0:8:35 1
call 0:8:29 1
init 0:8:26 w
name 0:8:44 t0
init 0:8:39 lim
slit 0:8:11 D 3
str 0:8:60 b
init 0:8:54 name
name 0:8:68 zeros
int 0:8:74 1
call 0:8:68 1
init 0:8:65 w
name 0:8:83 t0
init 0:8:78 lim
slit 0:8:50 D 3
row 0:8:11 2
array 0:8:10 1
var 0:8:1 0
pname 0:9:5 keep
name 0:9:12 ds
let 0:9:1 0
name 0:10:1 upd
name 0:10:9 ds
ref 0:10:5
int 0:10:13 1
float 0:10:16 #401C000000000000
call 0:10:1 3
cstmt 0:10:1
name 0:11:1 upd
name 0:11:9 ds
ref 0:11:5
int 0:11:13 0
float 0:11:16 #4020000000000000
call 0:11:1 3
cstmt 0:11:1
name 0:12:1 printf
str 0:12:8 %25s%20%25g%20%25g%20%25g%0A
name 0:12:25 ds
int 0:12:28 1
index 0:12:25 1
dot 0:12:25 name
name 0:12:37 ds
int 0:12:40 1
index 0:12:37 1
dot 0:12:37 w
int 0:12:45 0
index 0:12:37 1
name 0:12:49 ds
int 0:12:52 1
index 0:12:49 1
dot 0:12:49 lim
dot 0:12:49 lo
name 0:12:63 ds
int 0:12:66 1
index 0:12:63 1
dot 0:12:63 lim
dot 0:12:63 hi
call 0:12:1 5
cstmt 0:12:1
name 0:13:1 printf
str 0:13:8 %25s%20%25g%20%25s%0A
name 0:13:22 keep
int 0:13:27 1
index 0:13:22 1
dot 0:13:22 name
name 0:13:36 keep
int 0:13:41 1
index 0:13:36 1
dot 0:13:36 w
int 0:13:46 0
index 0:13:36 1
name 0:13:50 ds
int 0:13:53 0
index 0:13:50 1
dot 0:13:50 name
call 0:13:1 4
cstmt 0:13:1
type 0:15:9 f64 s 0
field 0:15:5 lo
type 0:16:9 f64 s 0
field 0:16:5 hi
struct 0:14:1 T 2
type 0:19:11 str s 0
field 0:19:5 name
type 0:20:8 f64 v 0
field 0:20:5 w
type 0:21:10 T s 0
field 0:21:5 lim
struct 0:18:1 D 3
prog 10
'''
# sea.hir1: T 10 (`loc t0`), f64[] 11, D 12 and D[] 13 (`loc ds`); upd's ds a `ref` parameter
# (`par ds 13 ref`); `ref ds` a rarg at the `ref` keyword; each target the idx/fld chain of the
# dot and index positions; the reads of lines 12-13 stay idx/fld (rule 18).
HIR12['struct_l17_path'] = '''
tstruct 10 T 2
fd lo 4
fd hi 4
tvec 11 4
tstruct 12 D 3
fd name 5
fd w 11
fd lim 10
tvec 13 12
fn 1 .main main 1 0 3 0:1:1
loc t0 10 let 0:7:5
loc ds 13 var 0:8:5
loc keep 13 let 0:9:5
cf 0:7:18 4 #0000000000000000
cf 0:7:27 4 #3FF0000000000000
slit 0:7:10 10 2
bind 0:7:1 1
cs 0:8:21 5 a
ci 0:8:35 3 1
lib 0:8:29 11 zeros 1
lv 0:8:44 10 1
slit 0:8:11 12 3
cs 0:8:60 5 b
ci 0:8:74 3 1
lib 0:8:68 11 zeros 1
lv 0:8:83 10 1
slit 0:8:50 12 3
row 0:8:11 13 2
arr 0:8:10 13 1
bind 0:8:1 2
lv 0:9:12 13 2
bind 0:9:1 3
lv 0:10:9 13 2
rarg 0:10:5 13
ci 0:10:13 3 1
cf 0:10:16 4 #401C000000000000
call 0:10:1 1 2 3
eval 0:10:1
lv 0:11:9 13 2
rarg 0:11:5 13
ci 0:11:13 3 0
cf 0:11:16 4 #4020000000000000
call 0:11:1 1 2 3
eval 0:11:1
lv 0:12:25 13 2
ci 0:12:28 3 1
idx 0:12:25 12 1
fld 0:12:25 5 0
fconv 0:12:8 1 - - - s
ftext 0:12:8 1 %20
lv 0:12:37 13 2
ci 0:12:40 3 1
idx 0:12:37 12 1
fld 0:12:37 11 1
ci 0:12:45 3 0
idx 0:12:37 4 1
fconv 0:12:8 1 - - - g
ftext 0:12:8 1 %20
lv 0:12:49 13 2
ci 0:12:52 3 1
idx 0:12:49 12 1
fld 0:12:49 10 2
fld 0:12:49 4 0
fconv 0:12:8 1 - - - g
ftext 0:12:8 1 %20
lv 0:12:63 13 2
ci 0:12:66 3 1
idx 0:12:63 12 1
fld 0:12:63 10 2
fld 0:12:63 4 1
fconv 0:12:8 1 - - - g
ftext 0:12:8 1 %0A
fmt 0:12:8 1 8
lib 0:12:1 1 printf 1
eval 0:12:1
lv 0:13:22 13 3
ci 0:13:27 3 1
idx 0:13:22 12 1
fld 0:13:22 5 0
fconv 0:13:8 1 - - - s
ftext 0:13:8 1 %20
lv 0:13:36 13 3
ci 0:13:41 3 1
idx 0:13:36 12 1
fld 0:13:36 11 1
ci 0:13:46 3 0
idx 0:13:36 4 1
fconv 0:13:8 1 - - - g
ftext 0:13:8 1 %20
lv 0:13:50 13 2
ci 0:13:53 3 0
idx 0:13:50 12 1
fld 0:13:50 5 0
fconv 0:13:8 1 - - - s
ftext 0:13:8 1 %0A
fmt 0:13:8 1 6
lib 0:13:1 1 printf 1
eval 0:13:1
block 0:1:1 7
end
fn 2 upd fn 1 3 0 0:1:1
par ds 13 ref
par i 3 val
par x 4 val
lv 0:2:5 13 1
lv 0:2:8 3 2
idx 0:2:5 12 1
fld 0:2:5 11 1
ci 0:2:13 3 0
idx 0:2:5 4 1
lv 0:2:18 4 3
asg 0:2:5 set
lv 0:3:5 13 1
lv 0:3:8 3 2
idx 0:3:5 12 1
fld 0:3:5 10 2
lv 0:3:25 4 3
cf 0:3:32 4 #4000000000000000
slit 0:3:17 10 2
asg 0:3:5 set
lv 0:4:5 13 1
lv 0:4:8 3 2
idx 0:4:5 12 1
fld 0:4:5 10 2
fld 0:4:5 4 1
lv 0:4:20 4 3
cf 0:4:24 4 #3FF0000000000000
bin 0:4:20 4 add
asg 0:4:5 set
lv 0:5:5 13 1
lv 0:5:8 3 2
idx 0:5:5 12 1
fld 0:5:5 5 0
cs 0:5:18 5 z
asg 0:5:5 set
block 0:1:37 4
end
'''


def hirl_struct_l17_path():
    """sea.hirl: tptr 14 12 (the data of D[], first in .main's literal), 15 4 (the data of the
    field w, upd line 2). .main: the literal L9 (b) (P 0:8:10) with each slit written in place
    (R19), its zeros by L1. upd: L17 (P the asg's position) with the ref root ds: step 2's `tmp B0 =
    lv ds`; line 2: I0 = lv i, I1 = ci 0 (step 3), the checks (X0, D0 = data(B0), E0 the element's
    address by R18, B1 = fld (lv E0) w, X1), `cow (lv ds)`, D' = adat (lv ds) right after it, E',
    `cow (fld (lv E') w)`, est 8 0 into `adat (fld (lv E') w)` at I1; lines 3-5: the check of
    ds, `cow (lv ds)`, est at `adat (lv ds)` with I0, sc = s(D) = 32 and off the field's offset
    (16, 16 + 8, 0); no D'/E' (the path has no field array after ds)."""
    tab = type_table(HIR12['struct_l17_path'])
    sD = layout(tab, 12)[0]
    assert sD == 32 and layout(tab, 12)[2] == [0, 8]
    assert [field_off(tab, 12, p)[0] for p in (['name'], ['w'], ['lim'], ['lim', 'hi'])] == \
        [0, 8, 16, 24]
    F1, F2 = Fn(), Fn()
    e1 = N(['cs 0:8:21 5 a', 'ci 0:8:35 3 1', 'anew 0:8:29 11 1 1', 'lv 0:8:44 10 1',
            'slit 0:8:11 12 3'], 12)
    e2 = N(['cs 0:8:60 5 b', 'ci 0:8:74 3 1', 'anew 0:8:68 11 1 1', 'lv 0:8:83 10 1',
            'slit 0:8:50 12 3'], 12)
    lit = L9b_any(F1, '0:8:10', 13, 14, 'l', sD, [e1, e2])
    old = lines(HIR12['struct_l17_path'])
    a = old.index('cs 0:8:21 5 a')
    b = old.index('arr 0:8:10 13 1')
    e_main = [(old[a:b + 1], cat(lit))]

    def span(first, last):
        return old[old.index(first):old.index(last) + 1]

    P = '0:2:5'
    x = Ctx(F2, P, 'a')
    ds = lambda: lv(P, 13, 1)
    st = [x.tmp('Vv', lv('0:2:18', 4, 3)), x.tmp('B0', ds()), x.tmp('I0', lv('0:2:8', 3, 2)),
          x.tmp('I1', ci('0:2:13', 0)), x.tmp('X0', ext(P, 0, x.lvl('B0'))),
          chkb(P, 0, x.lvl('I0'), x.lvl('X0')), x.tmp('D0', adat(P, 14, x.lvl('B0'))),
          x.tmp('E0', eldS(P, 12, sD, 0, x.lvl('D0'), x.lvl('I0'))),
          x.tmp('B1', fld(P, 11, 1, x.lvl('E0'))), x.tmp('X1', ext(P, 0, x.lvl('B1'))),
          chkb(P, 0, x.lvl('I1'), x.lvl('X1')), cowS(P, ds()),
          x.tmp('Dp', adat(P, 14, ds())),
          x.tmp('Ep', eldS(P, 12, sD, 0, x.lvl('Dp'), x.lvl('I0'))),
          cowS(P, fld(P, 11, 1, x.lvl('Ep'))),
          estS(P, 8, 0, x.lvl('Vv'), adat(P, 15, fld(P, 11, 1, x.lvl('Ep'))), x.lvl('I1'))]
    e_upd = [(span('lv 0:2:5 13 1', 'asg 0:2:5 set'), cat(block(P, st)))]

    def one(P, pre, value, off, first, last):
        x = Ctx(F2, P, pre)
        ds = lambda: lv(P, 13, 1)
        st = [x.tmp('Vv', value), x.tmp('B0', ds()), x.tmp('I0', lv(P[:-1] + '8', 3, 2)),
              x.tmp('X0', ext(P, 0, x.lvl('B0'))), chkb(P, 0, x.lvl('I0'), x.lvl('X0')),
              cowS(P, ds()), estS(P, sD, off, x.lvl('Vv'), adat(P, 14, ds()), x.lvl('I0'))]
        return (span(first, last), cat(block(P, st)))

    sl = N(['lv 0:3:25 4 3', 'cf 0:3:32 4 #4000000000000000', 'slit 0:3:17 10 2'], 10)
    e_upd.append(one('0:3:5', 'b', sl, 16, 'lv 0:3:5 13 1', 'asg 0:3:5 set'))
    v4 = bin_('0:4:20', 4, 'add', lv('0:4:20', 4, 3), cf('0:4:24', '#3FF0000000000000'))
    e_upd.append(one('0:4:5', 'c', v4, 24, 'lv 0:4:5 13 1', 'asg 0:4:5 set'))
    e_upd.append(one('0:5:5', 'd', cs_('0:5:18', 'z'), 0, 'lv 0:5:5 13 1', 'asg 0:5:5 set'))
    return make_hirl(HIR12['struct_l17_path'], ['tptr 14 12', 'tptr 15 4'],
                     {1: (F1, e_main), 2: (F2, e_upd)})


HIRL2['struct_l17_path'] = hirl_struct_l17_path
# sea.lir1. .main: t0 into its slot s1 (27 (b), (g)). Line 8: L9 (b): `li R 2`, the arrnew of D[]
# (R21: `la` of D's slay d1, rank, `li C 1`, sea_arr_new_s) into ds's register (T3), the data; each
# element (R19, a fresh address): E = D + k*32 (`li O`, `padd`), the slit's fields in place: name
# `la` retained, w L1's arrnewz moved by its stp, lim the borrowed t0 copied at E + 16 (`li O 16`,
# `padd`, `li N 16`, `mcopy`; T holds no reference). Line 9: `mov`, `retain` (rule 15 (a)). Lines
# 10-11: rule 12 (`sa` of a new 8-byte slot, `stp`, the call, `ldp`). Lines 12-13: rule 18's reads
# (`li` of each constant index, extent, `chkb`, data, then one load at sc 32 and the field's offset;
# w's element read through the loaded field), the slots s4 (32) and s5 (24); keep and ds released
# at the end (rule 16 (a): reverse order; t0 holds no reference). upd, line 2: Vv the alias of x,
# B0 `ldp B ds - 0 0` (step 2: a ref parameter's lv), I1 `li 0`, the check of ds, D0, E0 (R18:
# `li S 32`, `imul`, `padd`), B1 `ldp B E0 - 0 8`, its check; the memory form of cow at ds (`if 1`),
# D' from that cow's register A (L-n: no `ldp` of ds again), E', the memory form of cow at E' + 8
# (`if 2`), the est's data from its A (R23), `stf x D I1 8 0`. Line 3: the slit in the temporary
# slot s1 (27 (a), (g)), B0, the check, the cow (`if 3`), the data from A, R19 into a home that is
# not fresh: E (`li S 32`, `imul`, `padd E D T`, then `li O 16`, `padd E E O`), the owned slit
# moved, no old reference (T has none), `li N 16`, `mcopy`. Line 4: `lf`, `fadd` (rule 1), B0,
# the check, the cow (`if 4`), `stf V D i 32 24` (R24). Line 5: `la` of "z", B0, the check, the cow
# (`if 5`), the data, then R17 (a): `retain`, `ldp O D i 32 0`, `stp`, `release O`.
LIR12['struct_l17_path'] = J(
    'func .main main 0:1:1 0 0',
    'slot s1 16 8', 'slot s2 8 8', 'slot s3 8 8', 'slot s4 32 8', 'slot s5 24 8',
    'sa p.t0 s1', 'lf f.lo #0000000000000000', 'stf f.lo p.t0 - 0 0',
    'lf f.hi #3FF0000000000000', 'stf f.hi p.t0 - 0 8',
    'li i.R 2', 'la p.L d1', 'li i.rk 1', 'li i.C 1',
    'rcall sea_arr_new_s 0:8 1 p.ds 4 p.L i.rk i.R i.C', 'ldp p.D p.ds - 0 40',
    'li i.O0 0', 'padd p.E0 p.D i.O0', 'la p.a d2', 'retain p.a', 'stp p.a p.E0 - 0 0',
    'li i.w0 1', 'li i.ek0 1', 'li i.rk0 1', 'li i.C0 1',
    'rcall sea_arr_new 0:8 1 p.w0 4 i.ek0 i.rk0 i.w0 i.C0', 'stp p.w0 p.E0 - 0 8',
    'li i.Q0 16', 'padd p.F0 p.E0 i.Q0', 'li i.N0 16', 'mcopy p.F0 p.t0 i.N0',
    'li i.O1 32', 'padd p.E1 p.D i.O1', 'la p.b d3', 'retain p.b', 'stp p.b p.E1 - 0 0',
    'li i.w1 1', 'li i.ek1 1', 'li i.rk1 1', 'li i.C1 1',
    'rcall sea_arr_new 0:8 1 p.w1 4 i.ek1 i.rk1 i.w1 i.C1', 'stp p.w1 p.E1 - 0 8',
    'li i.Q1 16', 'padd p.F1 p.E1 i.Q1', 'li i.N1 16', 'mcopy p.F1 p.t0 i.N1',
    'mov p.keep p.ds', 'retain p.keep',
    'sa p.A1 s2', 'stp p.ds p.A1 - 0 0', 'li i.one 1', 'lf f.x1 #401C000000000000',
    'call upd 0 3 p.A1 i.one f.x1', 'ldp p.ds p.A1 - 0 0',
    'sa p.A2 s3', 'stp p.ds p.A2 - 0 0', 'li i.zero 0', 'lf f.x2 #4020000000000000',
    'call upd 0 3 p.A2 i.zero f.x2', 'ldp p.ds p.A2 - 0 0',
    'li i.a1 1', 'ldi i.e1 p.ds - 0 16', 'chkb i.a1 i.e1 0 0:12', 'ldp p.d1 p.ds - 0 40',
    'ldp p.n1 p.d1 i.a1 32 0',
    'li i.a2 1', 'ldi i.e2 p.ds - 0 16', 'chkb i.a2 i.e2 0 0:12', 'ldp p.d2 p.ds - 0 40',
    'ldp p.W2 p.d2 i.a2 32 8', 'li i.b2 0', 'ldi i.f2 p.W2 - 0 16', 'chkb i.b2 i.f2 0 0:12',
    'ldp p.g2 p.W2 - 0 40', 'ldf f.v2 p.g2 i.b2 8 0',
    'li i.a3 1', 'ldi i.e3 p.ds - 0 16', 'chkb i.a3 i.e3 0 0:12', 'ldp p.d3 p.ds - 0 40',
    'ldf f.v3 p.d3 i.a3 32 16',
    'li i.a4 1', 'ldi i.e4 p.ds - 0 16', 'chkb i.a4 i.e4 0 0:12', 'ldp p.d4 p.ds - 0 40',
    'ldf f.v4 p.d4 i.a4 32 24',
    'sa p.S1 s4', 'stp p.n1 p.S1 - 0 0', 'stf f.v2 p.S1 - 0 8', 'stf f.v3 p.S1 - 0 16',
    'stf f.v4 p.S1 - 0 24', 'la p.Fm1 d4', 'rcall sea_printf 0:12 0 2 p.Fm1 p.S1',
    'li i.a5 1', 'ldi i.e5 p.keep - 0 16', 'chkb i.a5 i.e5 0 0:13', 'ldp p.d5 p.keep - 0 40',
    'ldp p.n5 p.d5 i.a5 32 0',
    'li i.a6 1', 'ldi i.e6 p.keep - 0 16', 'chkb i.a6 i.e6 0 0:13', 'ldp p.d6 p.keep - 0 40',
    'ldp p.W6 p.d6 i.a6 32 8', 'li i.b6 0', 'ldi i.f6 p.W6 - 0 16', 'chkb i.b6 i.f6 0 0:13',
    'ldp p.g6 p.W6 - 0 40', 'ldf f.v6 p.g6 i.b6 8 0',
    'li i.a7 0', 'ldi i.e7 p.ds - 0 16', 'chkb i.a7 i.e7 0 0:13', 'ldp p.d7 p.ds - 0 40',
    'ldp p.n7 p.d7 i.a7 32 0',
    'sa p.S2 s5', 'stp p.n5 p.S2 - 0 0', 'stf f.v6 p.S2 - 0 8', 'stp p.n7 p.S2 - 0 16',
    'la p.Fm2 d5', 'rcall sea_printf 0:13 0 2 p.Fm2 p.S2',
    'release p.keep', 'release p.ds', 'ret 0', 'endfunc',
    'func upd fn 0:1:1 3 p.ds i.i f.x 0', 'slot s1 16 8',
    'ldp p.B2 p.ds - 0 0', 'li i.I1 0', 'ldi i.X0 p.B2 - 0 16', 'chkb i.i i.X0 0 0:2',
    'ldp p.D0 p.B2 - 0 40', 'li i.S0 32', 'imul i.T0 i.i i.S0', 'padd p.E0 p.D0 i.T0',
    'ldp p.B1 p.E0 - 0 8', 'ldi i.X1 p.B1 - 0 16', 'chkb i.I1 i.X1 0 0:2',
    'ldp p.A0 p.ds - 0 0', 'ldi i.C0 p.A0 - 0 0', 'li i.O0 1', 'icmp ne i.U0 i.C0 i.O0',
    'if 1 i.U0', 'rcall sea_arr_unique 0:2 1 p.N0 1 p.A0', 'stp p.N0 p.ds - 0 0',
    'mov p.A0 p.N0', 'endif 1',
    'ldp p.Dp p.A0 - 0 40', 'li i.S1 32', 'imul i.T1 i.i i.S1', 'padd p.Ep p.Dp i.T1',
    'ldp p.A1 p.Ep - 0 8', 'ldi i.C1 p.A1 - 0 0', 'li i.O1 1', 'icmp ne i.U1 i.C1 i.O1',
    'if 2 i.U1', 'rcall sea_arr_unique 0:2 1 p.N1 1 p.A1', 'stp p.N1 p.Ep - 0 8',
    'mov p.A1 p.N1', 'endif 2', 'ldp p.Dw p.A1 - 0 40', 'stf f.x p.Dw i.I1 8 0',
    'sa p.V3 s1', 'stf f.x p.V3 - 0 0', 'lf f.h3 #4000000000000000', 'stf f.h3 p.V3 - 0 8',
    'ldp p.B3 p.ds - 0 0', 'ldi i.X3 p.B3 - 0 16', 'chkb i.i i.X3 0 0:3',
    'ldp p.A3 p.ds - 0 0', 'ldi i.C3 p.A3 - 0 0', 'li i.O3 1', 'icmp ne i.U3 i.C3 i.O3',
    'if 3 i.U3', 'rcall sea_arr_unique 0:3 1 p.N3 1 p.A3', 'stp p.N3 p.ds - 0 0',
    'mov p.A3 p.N3', 'endif 3', 'ldp p.D3 p.A3 - 0 40',
    'li i.S3 32', 'imul i.T3 i.i i.S3', 'padd p.E3 p.D3 i.T3', 'li i.F3 16',
    'padd p.E3 p.E3 i.F3', 'li i.N3b 16', 'mcopy p.E3 p.V3 i.N3b',
    'lf f.c4 #3FF0000000000000', 'fadd f.V4 f.x f.c4',
    'ldp p.B4 p.ds - 0 0', 'ldi i.X4 p.B4 - 0 16', 'chkb i.i i.X4 0 0:4',
    'ldp p.A4 p.ds - 0 0', 'ldi i.C4 p.A4 - 0 0', 'li i.O4 1', 'icmp ne i.U4 i.C4 i.O4',
    'if 4 i.U4', 'rcall sea_arr_unique 0:4 1 p.N4 1 p.A4', 'stp p.N4 p.ds - 0 0',
    'mov p.A4 p.N4', 'endif 4', 'ldp p.D4 p.A4 - 0 40', 'stf f.V4 p.D4 i.i 32 24',
    'la p.z5 d6', 'ldp p.B5 p.ds - 0 0', 'ldi i.X5 p.B5 - 0 16', 'chkb i.i i.X5 0 0:5',
    'ldp p.A5 p.ds - 0 0', 'ldi i.C5 p.A5 - 0 0', 'li i.O5 1', 'icmp ne i.U5 i.C5 i.O5',
    'if 5 i.U5', 'rcall sea_arr_unique 0:5 1 p.N5 1 p.A5', 'stp p.N5 p.ds - 0 0',
    'mov p.A5 p.N5', 'endif 5', 'ldp p.D5 p.A5 - 0 40',
    'retain p.z5', 'ldp p.O5 p.D5 i.i 32 0', 'stp p.z5 p.D5 i.i 32 0', 'release p.O5',
    'ret 0', 'endfunc',
    'slay d1 32 2', 'soff 0', 'soff 8', 'str d2 a', 'str d3 b',
    fmt_rec(4, ['fconv - - - s p', 'ftext %20', 'fconv - - - g f', 'ftext %20', 'fconv - - - g f',
                'ftext %20', 'fconv - - - g f', 'ftext %0A']),
    fmt_rec(5, ['fconv - - - s p', 'ftext %20', 'fconv - - - g f', 'ftext %20', 'fconv - - - s p',
                'ftext %0A']),
    'str d6 z')
# upd(ref ds, 1, 7.0): ds[1].w[0] 7, lim {7, 2}, lim.hi 8, name "z"; upd(ref ds, 0, 8.0) likewise
# for ds[0]; keep shares the old array, whose elements and w the cows left unchanged (LANGUAGE.md
# 4.6, 8.3): "z 7 7 8", "b 0 z".
OUT2['struct_l17_path'] = 'z 7 7 8\nb 0 z\n'
NAMES4G2.append('struct_l17_path')


def L9a(F, P, T, E, TP, pre, elems, r):
    """L9 (a) (dump4e_cases.L9a, whose test section is not loaded here): a fixed-size literal
    without concatenation: `xblk P T n` with `tmp H = anew P T 0 0`, `tmp D = data(H)`, then each
    element (i, j) in source order `est s 0 e (lv D) (ci k)`, k = i + j*r."""
    x = Ctx(F, P, pre)
    st = [x.tmp('H', anew(P, T, 0, [])), x.tmp('D', adat(P, TP, x.lvl('H')))]
    for (i, j), e in elems:
        st.append(est(P, E, e, x.lvl('D'), ci(P, i + j * r)))
    return xblk(P, st, x.lvl('H'))


# ================================================================ struct_cow2 (two array-field levels)
SEA2['struct_cow2'] = '''struct T {
    v: f64[]
}
struct S {
    w: T[]
}
var a = [S { w: [T { v: [1.0] }] }]
let b = a
a[0].w[0].v[0] = 9.0
printf("%g %g\\n", b[0].w[0].v[0], a[0].w[0].v[0])
// struct_cow2 -- DESIGN.md 6.2 (4g-2): two array-field levels, `a[0].w[0].v[0] = 9.0` after
// `let b = a` prints `1 9`: L17 copies a, then the w of a's copy (R23 at E'+0), then that w's
// element's v (R23 at E''+0), each element address from the register its cow left (step 5); the
// literal of line 7 nests L9 (b) (S[] and T[] by sea_arr_new_s with their slays, R21) around
// L10's dyn of the fixed f64[1] literal [1.0] (L9 (a)) for the f64[] field v (LANGUAGE.md 6.9, 4.5)
'''
AST2['struct_cow2'] = '''
type 0:2:8 f64 v 0
field 0:2:5 v
struct 0:1:1 T 1
type 0:5:8 T v 0
field 0:5:5 w
struct 0:4:1 S 1
pname 0:7:5 a
float 0:7:26 #3FF0000000000000
row 0:7:26 1
array 0:7:25 1
init 0:7:22 v
slit 0:7:18 T 1
row 0:7:18 1
array 0:7:17 1
init 0:7:14 w
slit 0:7:10 S 1
row 0:7:10 1
array 0:7:9 1
var 0:7:1 0
pname 0:8:5 b
name 0:8:9 a
let 0:8:1 0
name 0:9:1 a
int 0:9:3 0
index 0:9:1 1
dot 0:9:1 w
int 0:9:8 0
index 0:9:1 1
dot 0:9:1 v
int 0:9:13 0
index 0:9:1 1
float 0:9:18 #4022000000000000
asg 0:9:1 set
name 0:10:1 printf
str 0:10:8 %25g%20%25g%0A
name 0:10:19 b
int 0:10:21 0
index 0:10:19 1
dot 0:10:19 w
int 0:10:26 0
index 0:10:19 1
dot 0:10:19 v
int 0:10:31 0
index 0:10:19 1
name 0:10:35 a
int 0:10:37 0
index 0:10:35 1
dot 0:10:35 w
int 0:10:42 0
index 0:10:35 1
dot 0:10:35 v
int 0:10:47 0
index 0:10:35 1
call 0:10:1 3
cstmt 0:10:1
prog 6
'''
# sea.hir1: `loc a` numbers f64[] 10, T 11, T[] 12, S 13, S[] 14 (3.5.1: components first); the
# literal [1.0] is the fixed f64[1] 15 (LANGUAGE.md 6.9: one row of scalars), converted to the
# field's f64[] by an implicit dyn at its position (2.6.2, as a binding's); each struct literal a
# dynamic S[] / T[] (6.9: struct elements); the target an idx/fld chain at the asg's position.
HIR12['struct_cow2'] = '''
tvec 10 4
tstruct 11 T 1
fd v 10
tvec 12 11
tstruct 13 S 1
fd w 12
tvec 14 13
tfvec 15 4 1
fn 1 .main main 1 0 2 0:1:1
loc a 14 var 0:7:5
loc b 14 let 0:8:5
cf 0:7:26 4 #3FF0000000000000
row 0:7:26 15 1
arr 0:7:25 15 1
dyn 0:7:25 10
slit 0:7:18 11 1
row 0:7:18 12 1
arr 0:7:17 12 1
slit 0:7:10 13 1
row 0:7:10 14 1
arr 0:7:9 14 1
bind 0:7:1 1
lv 0:8:9 14 1
bind 0:8:1 2
lv 0:9:1 14 1
ci 0:9:3 3 0
idx 0:9:1 13 1
fld 0:9:1 12 0
ci 0:9:8 3 0
idx 0:9:1 11 1
fld 0:9:1 10 0
ci 0:9:13 3 0
idx 0:9:1 4 1
cf 0:9:18 4 #4022000000000000
asg 0:9:1 set
lv 0:10:19 14 2
ci 0:10:21 3 0
idx 0:10:19 13 1
fld 0:10:19 12 0
ci 0:10:26 3 0
idx 0:10:19 11 1
fld 0:10:19 10 0
ci 0:10:31 3 0
idx 0:10:19 4 1
fconv 0:10:8 1 - - - g
ftext 0:10:8 1 %20
lv 0:10:35 14 1
ci 0:10:37 3 0
idx 0:10:35 13 1
fld 0:10:35 12 0
ci 0:10:42 3 0
idx 0:10:35 11 1
fld 0:10:35 10 0
ci 0:10:47 3 0
idx 0:10:35 4 1
fconv 0:10:8 1 - - - g
ftext 0:10:8 1 %0A
fmt 0:10:8 1 4
lib 0:10:1 1 printf 1
eval 0:10:1
block 0:1:1 4
end
'''


def hirl_struct_cow2():
    """sea.hirl: tptr 16 13, 17 11, 18 4 (in order of first reference: the outer literal's data,
    the inner's, the fixed literal's home). Line 7: L9 (b) of S[] (P 0:7:9) whose one slit holds
    L9 (b) of T[] (P 0:7:17) whose one slit holds L10's dyn (P 0:7:25) of L9 (a)'s home; each slit
    written in place (R19). Line 9: L17 (P 0:9:1): Vv, the three constant indices (step 3), the
    checks through E0, B1 = fld (lv E0) w, E1, B2 = fld (lv E1) v (step 4), then `cow (lv a)`, D',
    E', `cow (fld (lv E') w)`, D'', E'', `cow (fld (lv E'') v)` (step 5), and the est into `adat
    (fld (lv E'') v)` (step 6)."""
    tab = type_table(HIR12['struct_cow2'])
    assert layout(tab, 13)[:3] == (8, 8, [0]) and layout(tab, 11)[:3] == (8, 8, [0])
    F = Fn()
    P = '0:7:25'
    l9a = L9a(F, P, 15, 4, 18, 'h', [((0, 0), cf('0:7:26', '#3FF0000000000000'))], 1)
    y = Ctx(F, P, 'y')
    st = [y.tmp('S', l9a), y.tmp('R', ext(P, 0, y.lvl('S'))),
          y.tmp('A', anew(P, 10, 0, [y.lvl('R')])), y.tmp('D', adat(P, 18, y.lvl('A'))),
          y.tmp('N', ci(P, 8)), mcpy(P, y.lvl('D'), adat(P, 18, y.lvl('S')), y.lvl('N'))]
    dynx = xblk(P, st, y.lvl('A'))
    slitT = N(cat(dynx) + ['slit 0:7:18 11 1'], 11)
    inner = L9b_any(F, '0:7:17', 12, 17, 'm', 8, [slitT])
    slitS = N(cat(inner) + ['slit 0:7:10 13 1'], 13)
    outer = L9b_any(F, '0:7:9', 14, 16, 'l', 8, [slitS])
    old = lines(HIR12['struct_cow2'])
    eds = [(old[old.index('cf 0:7:26 4 #3FF0000000000000'):old.index('arr 0:7:9 14 1') + 1],
            cat(outer))]
    P = '0:9:1'
    x = Ctx(F, P, 'c')
    a = lambda: lv(P, 14, 1)
    st = [x.tmp('Vv', cf('0:9:18', '#4022000000000000')), x.tmp('I0', ci('0:9:3', 0)),
          x.tmp('I1', ci('0:9:8', 0)), x.tmp('I2', ci('0:9:13', 0)),
          x.tmp('X0', ext(P, 0, a())), chkb(P, 0, x.lvl('I0'), x.lvl('X0')),
          x.tmp('D0', adat(P, 16, a())), x.tmp('E0', eldS(P, 13, 8, 0, x.lvl('D0'), x.lvl('I0'))),
          x.tmp('B1', fld(P, 12, 0, x.lvl('E0'))), x.tmp('X1', ext(P, 0, x.lvl('B1'))),
          chkb(P, 0, x.lvl('I1'), x.lvl('X1')),
          x.tmp('D1', adat(P, 17, x.lvl('B1'))), x.tmp('E1', eldS(P, 11, 8, 0, x.lvl('D1'), x.lvl('I1'))),
          x.tmp('B2', fld(P, 10, 0, x.lvl('E1'))), x.tmp('X2', ext(P, 0, x.lvl('B2'))),
          chkb(P, 0, x.lvl('I2'), x.lvl('X2')),
          cowS(P, a()), x.tmp('Dp', adat(P, 16, a())),
          x.tmp('Ep', eldS(P, 13, 8, 0, x.lvl('Dp'), x.lvl('I0'))),
          cowS(P, fld(P, 12, 0, x.lvl('Ep'))), x.tmp('Dq', adat(P, 17, fld(P, 12, 0, x.lvl('Ep')))),
          x.tmp('Eq', eldS(P, 11, 8, 0, x.lvl('Dq'), x.lvl('I1'))),
          cowS(P, fld(P, 10, 0, x.lvl('Eq'))),
          estS(P, 8, 0, x.lvl('Vv'), adat(P, 18, fld(P, 10, 0, x.lvl('Eq'))), x.lvl('I2'))]
    eds.append((old[old.index('lv 0:9:1 14 1'):old.index('asg 0:9:1 set') + 1], cat(block(P, st))))
    return make_hirl(HIR12['struct_cow2'], ['tptr 16 13', 'tptr 17 11', 'tptr 18 4'], {1: (F, eds)})


HIRL2['struct_cow2'] = hirl_struct_cow2
# sea.lir1. Line 7: the outer L9 (b): `li 1`, arrnew of S[] (`la` of S's slay d1, sea_arr_new_s)
# into a (T3), its data, E = D + 0 (R19); the slit's w is the inner L9 (b) (T's slay d2), E2, and
# its slit's v is the dyn (rule 27 (i)) of the fixed literal: its home s1 and the store (L9 (a)),
# the static extent `li 1`, arrnew (sea_arr_new_u), data, `li 8`, `mcopy` (the home holds no
# counts: nothing released); each owned array moved by its `stp` into the fresh element. Line 8:
# `mov`, `retain`. Line 9: `lf`, the indices `li 0` (three), the checks of a, of a[0].w (`ldp B1 E0
# - 0 0`) and of a[0].w[0].v (`ldp B2 E1 - 0 0`), each element address R18's `li S 8`, `imul`,
# `padd`; cow(a) (rule 19, register form, `if 1`), D' from a, E', the memory form of cow at E'
# (`if 2`), D'' from that cow's A (R23), E'', the memory form at E'' (`if 3`), the data from its A,
# `stf`. Line 10: rule 18's reads (each struct element's field one `ldp` at sc 8, off 0), the slot
# s2; b and a released at the end (rule 16 (a)).
LIR12['struct_cow2'] = J(
    'func .main main 0:1:1 0 0', 'slot s1 8 8', 'slot s2 16 8',
    'li i.R1 1', 'la p.LS d1', 'li i.rk1 1', 'li i.C1 1',
    'rcall sea_arr_new_s 0:7 1 p.a 4 p.LS i.rk1 i.R1 i.C1', 'ldp p.D1 p.a - 0 40',
    'li i.O1 0', 'padd p.E1 p.D1 i.O1',
    'li i.R2 1', 'la p.LT d2', 'li i.rk2 1', 'li i.C2 1',
    'rcall sea_arr_new_s 0:7 1 p.W 4 p.LT i.rk2 i.R2 i.C2', 'ldp p.D2 p.W - 0 40',
    'li i.O2 0', 'padd p.E2 p.D2 i.O2',
    'sa p.H s1', 'lf f.one #3FF0000000000000', 'stf f.one p.H - 0 0',
    'li i.R3 1', 'li i.ek3 1', 'li i.rk3 1', 'li i.C3 1',
    'rcall sea_arr_new_u 0:7 1 p.V 4 i.ek3 i.rk3 i.R3 i.C3', 'ldp p.D3 p.V - 0 40',
    'li i.N3 8', 'mcopy p.D3 p.H i.N3', 'stp p.V p.E2 - 0 0', 'stp p.W p.E1 - 0 0',
    'mov p.b p.a', 'retain p.b',
    'lf f.n #4022000000000000', 'li i.I0 0', 'li i.I1 0', 'li i.I2 0',
    'ldi i.X0 p.a - 0 16', 'chkb i.I0 i.X0 0 0:9', 'ldp p.d0 p.a - 0 40',
    'li i.S0 8', 'imul i.T0 i.I0 i.S0', 'padd p.e0 p.d0 i.T0', 'ldp p.B1 p.e0 - 0 0',
    'ldi i.X1 p.B1 - 0 16', 'chkb i.I1 i.X1 0 0:9', 'ldp p.d1 p.B1 - 0 40',
    'li i.S1 8', 'imul i.T1 i.I1 i.S1', 'padd p.e1 p.d1 i.T1', 'ldp p.B2 p.e1 - 0 0',
    'ldi i.X2 p.B2 - 0 16', 'chkb i.I2 i.X2 0 0:9',
    'ldi i.c0 p.a - 0 0', 'li i.o0 1', 'icmp ne i.u0 i.c0 i.o0', 'if 1 i.u0',
    'rcall sea_arr_unique 0:9 1 p.n0 1 p.a', 'mov p.a p.n0', 'endif 1',
    'ldp p.Dp p.a - 0 40', 'li i.Sp 8', 'imul i.Tp i.I0 i.Sp', 'padd p.Ep p.Dp i.Tp',
    'ldp p.A1 p.Ep - 0 0', 'ldi i.c1 p.A1 - 0 0', 'li i.o1 1', 'icmp ne i.u1 i.c1 i.o1',
    'if 2 i.u1', 'rcall sea_arr_unique 0:9 1 p.n1 1 p.A1', 'stp p.n1 p.Ep - 0 0',
    'mov p.A1 p.n1', 'endif 2',
    'ldp p.Dq p.A1 - 0 40', 'li i.Sq 8', 'imul i.Tq i.I1 i.Sq', 'padd p.Eq p.Dq i.Tq',
    'ldp p.A2 p.Eq - 0 0', 'ldi i.c2 p.A2 - 0 0', 'li i.o2 1', 'icmp ne i.u2 i.c2 i.o2',
    'if 3 i.u2', 'rcall sea_arr_unique 0:9 1 p.n2 1 p.A2', 'stp p.n2 p.Eq - 0 0',
    'mov p.A2 p.n2', 'endif 3', 'ldp p.Dr p.A2 - 0 40', 'stf f.n p.Dr i.I2 8 0',
    'li i.k0 0', 'ldi i.x0 p.b - 0 16', 'chkb i.k0 i.x0 0 0:10', 'ldp p.g0 p.b - 0 40',
    'ldp p.w0 p.g0 i.k0 8 0', 'li i.k1 0', 'ldi i.x1 p.w0 - 0 16', 'chkb i.k1 i.x1 0 0:10',
    'ldp p.g1 p.w0 - 0 40', 'ldp p.v1 p.g1 i.k1 8 0', 'li i.k2 0', 'ldi i.x2 p.v1 - 0 16',
    'chkb i.k2 i.x2 0 0:10', 'ldp p.g2 p.v1 - 0 40', 'ldf f.r0 p.g2 i.k2 8 0',
    'li i.k3 0', 'ldi i.x3 p.a - 0 16', 'chkb i.k3 i.x3 0 0:10', 'ldp p.g3 p.a - 0 40',
    'ldp p.w3 p.g3 i.k3 8 0', 'li i.k4 0', 'ldi i.x4 p.w3 - 0 16', 'chkb i.k4 i.x4 0 0:10',
    'ldp p.g4 p.w3 - 0 40', 'ldp p.v4 p.g4 i.k4 8 0', 'li i.k5 0', 'ldi i.x5 p.v4 - 0 16',
    'chkb i.k5 i.x5 0 0:10', 'ldp p.g5 p.v4 - 0 40', 'ldf f.r1 p.g5 i.k5 8 0',
    'sa p.P s2', 'stf f.r0 p.P - 0 0', 'stf f.r1 p.P - 0 8', 'la p.F d3',
    'rcall sea_printf 0:10 0 2 p.F p.P', 'release p.b', 'release p.a', 'ret 0', 'endfunc',
    'slay d1 8 1', 'soff 0', 'slay d2 8 1', 'soff 0',
    fmt_rec(3, ['fconv - - - g f', 'ftext %20', 'fconv - - - g f', 'ftext %0A']))
# b keeps the old a, whose w and v the three cows left untouched (LANGUAGE.md 4.6): 1, then 9.
OUT2['struct_cow2'] = '1 9\n'
NAMES4G2.append('struct_cow2')


# ================================================================ str_ref_ln (R23 with L-n)
SEA2['str_ref_ln'] = '''fn f(ref v: str[], i: i64) {
    v[i] = "x"
}
var names = ["a", "b"]
f(ref names, 0)
f(ref names, 1)
printf("%s %s\\n", names[0], names[1])
// str_ref_ln -- DESIGN.md 3.5.9 R23 from 4g-2 (lead decision L-n): L17 of a str element of a ref
// parameter root: step 2's `tmp B = lv v` (`ldp B v - 0 0`) for the check, the memory form of cow
// at v, and the est's address `adat (lv v)` right after that cow is the cow's register A (`ldp D A
// - 0 40`, no second `ldp` of v); R17 (a)'s replacing store
'''
AST2['str_ref_ln'] = '''
type 0:1:13 str v 0
param 0:1:6 v 1 0
type 0:1:23 i64 s 0
param 0:1:20 i 0 0
name 0:2:5 v
name 0:2:7 i
index 0:2:5 1
str 0:2:12 x
asg 0:2:5 set
block 0:1:28 1
fn 0:1:1 f 0 2 0
pname 0:4:5 names
str 0:4:14 a
str 0:4:19 b
row 0:4:14 2
array 0:4:13 1
var 0:4:1 0
name 0:5:1 f
name 0:5:7 names
ref 0:5:3
int 0:5:14 0
call 0:5:1 2
cstmt 0:5:1
name 0:6:1 f
name 0:6:7 names
ref 0:6:3
int 0:6:14 1
call 0:6:1 2
cstmt 0:6:1
name 0:7:1 printf
str 0:7:8 %25s%20%25s%0A
name 0:7:19 names
int 0:7:25 0
index 0:7:19 1
name 0:7:29 names
int 0:7:35 1
index 0:7:29 1
call 0:7:1 3
cstmt 0:7:1
prog 5
'''
HIR12['str_ref_ln'] = '''
tvec 10 5
fn 1 .main main 1 0 1 0:1:1
loc names 10 var 0:4:5
cs 0:4:14 5 a
cs 0:4:19 5 b
row 0:4:14 10 2
arr 0:4:13 10 1
bind 0:4:1 1
lv 0:5:7 10 1
rarg 0:5:3 10
ci 0:5:14 3 0
call 0:5:1 1 2 2
eval 0:5:1
lv 0:6:7 10 1
rarg 0:6:3 10
ci 0:6:14 3 1
call 0:6:1 1 2 2
eval 0:6:1
lv 0:7:19 10 1
ci 0:7:25 3 0
idx 0:7:19 5 1
fconv 0:7:8 1 - - - s
ftext 0:7:8 1 %20
lv 0:7:29 10 1
ci 0:7:35 3 1
idx 0:7:29 5 1
fconv 0:7:8 1 - - - s
ftext 0:7:8 1 %0A
fmt 0:7:8 1 4
lib 0:7:1 1 printf 1
eval 0:7:1
block 0:1:1 4
end
fn 2 f fn 1 2 0 0:1:1
par v 10 ref
par i 3 val
lv 0:2:5 10 1
lv 0:2:7 3 2
idx 0:2:5 5 1
cs 0:2:12 5 x
asg 0:2:5 set
block 0:1:28 1
end
'''


def hirl_str_ref_ln():
    """sea.hirl: tptr 11 5. .main: the literal L9 (b) (P 0:4:13). f: L17 (P 0:2:5) with the ref
    root v: `tmp Vv = cs x`, `tmp B0 = lv v` (step 2), `tmp I0 = lv i`, X0, chkb, `cow (lv v)`,
    `est 8 0 (lv Vv) (adat (lv v)) (lv I0)` (step 6, the adat right after the cow: L-n)."""
    F1, F2 = Fn(), Fn()
    lit = L9b_str(F1, '0:4:13', 10, 11, 'l', [cs_('0:4:14', 'a'), cs_('0:4:19', 'b')])
    P = '0:2:5'
    x = Ctx(F2, P, 'a')
    v = lambda: lv(P, 10, 1)
    st = [x.tmp('Vv', cs_('0:2:12', 'x')), x.tmp('B0', v()), x.tmp('I0', lv('0:2:7', 3, 2)),
          x.tmp('X0', ext(P, 0, x.lvl('B0'))), chkb(P, 0, x.lvl('I0'), x.lvl('X0')),
          cow(P, v()), estS(P, 8, 0, x.lvl('Vv'), adat(P, 11, v()), x.lvl('I0'))]
    return make_hirl(HIR12['str_ref_ln'], ['tptr 11 5'], {
        1: (F1, [(['cs 0:4:14 5 a', 'cs 0:4:19 5 b', 'row 0:4:14 10 2', 'arr 0:4:13 10 1'],
                  cat(lit))]),
        2: (F2, [(['lv 0:2:5 10 1', 'lv 0:2:7 3 2', 'idx 0:2:5 5 1', 'cs 0:2:12 5 x',
                   'asg 0:2:5 set'], cat(block(P, st)))])})


HIRL2['str_ref_ln'] = hirl_str_ref_ln
# sea.lir1. .main: rule 26 (b) as in str_rule26; lines 5-6 rule 12 (slots s1, s2); line 7 two rule
# 18 reads, the slot s3; names released. f: the lead decision L-n golden: `la` of "x" (Vv), B0
# `ldp B v - 0 0` (step 2), the extent and `chkb`, the memory form of cow at v (`ldp A v - 0 0`,
# count, `icmp ne`, `if 1`, sea_arr_unique, `stp N v - 0 0`, `mov A N`, `endif 1`), then the data
# from A (`ldp D A - 0 40`: no `ldp` of v again, R23), R17 (a): `retain`, `ldp O`, `stp`,
# `release O`.
LIR12['str_ref_ln'] = J(
    'func .main main 0:1:1 0 0', 'slot s1 8 8', 'slot s2 8 8', 'slot s3 16 8',
    'li i.R 2', 'li i.ek 4', 'li i.rk 1', 'li i.C 1',
    'rcall sea_arr_new 0:4 1 p.names 4 i.ek i.rk i.R i.C', 'ldp p.D p.names - 0 40',
    'la p.a d1', 'retain p.a', 'stp p.a p.D - 0 0', 'la p.b d2', 'retain p.b',
    'stp p.b p.D - 0 8',
    'sa p.A1 s1', 'stp p.names p.A1 - 0 0', 'li i.z 0', 'call f 0 2 p.A1 i.z',
    'ldp p.names p.A1 - 0 0',
    'sa p.A2 s2', 'stp p.names p.A2 - 0 0', 'li i.o 1', 'call f 0 2 p.A2 i.o',
    'ldp p.names p.A2 - 0 0',
    'li i.k0 0', 'ldi i.e0 p.names - 0 16', 'chkb i.k0 i.e0 0 0:7', 'ldp p.d0 p.names - 0 40',
    'ldp p.v0 p.d0 i.k0 8 0',
    'li i.k1 1', 'ldi i.e1 p.names - 0 16', 'chkb i.k1 i.e1 0 0:7', 'ldp p.d1 p.names - 0 40',
    'ldp p.v1 p.d1 i.k1 8 0',
    'sa p.S s3', 'stp p.v0 p.S - 0 0', 'stp p.v1 p.S - 0 8', 'la p.F d3',
    'rcall sea_printf 0:7 0 2 p.F p.S', 'release p.names', 'ret 0', 'endfunc',
    'func f fn 0:1:1 2 p.v i.i 0',
    'la p.x d4', 'ldp p.B p.v - 0 0', 'ldi i.X p.B - 0 16', 'chkb i.i i.X 0 0:2',
    'ldp p.A p.v - 0 0', 'ldi i.C p.A - 0 0', 'li i.O 1', 'icmp ne i.U i.C i.O', 'if 1 i.U',
    'rcall sea_arr_unique 0:2 1 p.N 1 p.A', 'stp p.N p.v - 0 0', 'mov p.A p.N', 'endif 1',
    'ldp p.Dd p.A - 0 40', 'retain p.x', 'ldp p.Old p.Dd i.i 8 0', 'stp p.x p.Dd i.i 8 0',
    'release p.Old', 'ret 0', 'endfunc',
    'str d1 a', 'str d2 b', fmt_rec(3, ['fconv - - - s p', 'ftext %20', 'fconv - - - s p',
                                         'ftext %0A']), 'str d4 x')
OUT2['str_ref_ln'] = 'x x\n'
NAMES4G2.append('str_ref_ln')


# ================================================================ str_fixed_self (str[3]: L10 fix, L6 a[:] = a, L17)
SEA2['str_fixed_self'] = '''fn show(a: str[3]) {
    printf("%s %s %s\\n", a[0], a[1], a[2])
}
var a: str[3] = ["x", "y", "z"]
a[:] = a
show(a)
a[0] = "w"
show(a)
// str_fixed_self -- DESIGN.md 3.5.9 for a str[3] local (a home that holds counts, R1 as amended):
// line 4 L10's fix of the dynamic str[] literal by R20 (`mcpy` with the static count `ci 3`, the
// unrolled retains, the literal released); line 5 L6's counted self-copy (step 1: `mcpy data(Vv)
// data(V0) (ci 3)` with the retains of the borrowed root, R17's replacing stores in the `:` loop,
// Vv released by rule 15 (g) at the block's end, R11); line 7 L17 of an element of a fixed-size
// home (R17, no cow); the home released at the end (rule 16)
'''
AST2['str_fixed_self'] = '''
int 0:1:16 3
type 0:1:12 str fv 1
param 0:1:9 a 0 0
name 0:2:5 printf
str 0:2:12 %25s%20%25s%20%25s%0A
name 0:2:26 a
int 0:2:28 0
index 0:2:26 1
name 0:2:32 a
int 0:2:34 1
index 0:2:32 1
name 0:2:38 a
int 0:2:40 2
index 0:2:38 1
call 0:2:5 4
cstmt 0:2:5
block 0:1:20 1
fn 0:1:1 show 0 1 0
pname 0:4:5 a
int 0:4:12 3
type 0:4:8 str fv 1
str 0:4:18 x
str 0:4:23 y
str 0:4:28 z
row 0:4:18 3
array 0:4:17 1
var 0:4:1 1
name 0:5:1 a
all 0:5:3
index 0:5:1 1
name 0:5:8 a
asg 0:5:1 set
name 0:6:1 show
name 0:6:6 a
call 0:6:1 1
cstmt 0:6:1
name 0:7:1 a
int 0:7:3 0
index 0:7:1 1
str 0:7:8 w
asg 0:7:1 set
name 0:8:1 show
name 0:8:6 a
call 0:8:1 1
cstmt 0:8:1
prog 6
'''
# sea.hir1: str[3] 10 (`loc a`), the literal str[] 11 (LANGUAGE.md 6.9: dynamic whatever its size)
# with the implicit fix of the annotated binding at its position; `a[:]` an idx with `all` of
# type str[] (a selection of rank 1, LANGUAGE.md 5.5); the value `lv a` unconverted (L6 copies it).
HIR12['str_fixed_self'] = '''
tfvec 10 5 3
tvec 11 5
fn 1 .main main 1 0 1 0:1:1
loc a 10 var 0:4:5
cs 0:4:18 5 x
cs 0:4:23 5 y
cs 0:4:28 5 z
row 0:4:18 11 3
arr 0:4:17 11 1
fix 0:4:17 10
bind 0:4:1 1
lv 0:5:1 10 1
all 0:5:3 1
idx 0:5:1 11 1
lv 0:5:8 10 1
asg 0:5:1 set
lv 0:6:6 10 1
call 0:6:1 1 2 1
eval 0:6:1
lv 0:7:1 10 1
ci 0:7:3 3 0
idx 0:7:1 5 1
cs 0:7:8 5 w
asg 0:7:1 set
lv 0:8:6 10 1
call 0:8:1 1 2 1
eval 0:8:1
block 0:1:1 5
end
fn 2 show fn 1 1 0 0:1:1
par a 10 val
lv 0:2:26 10 1
ci 0:2:28 3 0
idx 0:2:26 5 1
fconv 0:2:12 1 - - - s
ftext 0:2:12 1 %20
lv 0:2:32 10 1
ci 0:2:34 3 1
idx 0:2:32 5 1
fconv 0:2:12 1 - - - s
ftext 0:2:12 1 %20
lv 0:2:38 10 1
ci 0:2:40 3 2
idx 0:2:38 5 1
fconv 0:2:12 1 - - - s
ftext 0:2:12 1 %0A
fmt 0:2:12 1 6
lib 0:2:5 1 printf 1
eval 0:2:5
block 0:1:20 1
end
'''


def hirl_str_fixed_self():
    """sea.hirl: tptr 12 5. Line 4: L10's fix (P 0:4:17) of the L9 (b) literal: `tmp A`, its extent
    R, `tmp En = ci 3`, `tmp S = bin ne`, vchk(SHAPE_EXPECTED; S, En, R), `tmp H = anew 10 0 0`,
    `tmp D = data(A)`, `mcpy data(H) (lv D) (ci 3)` (R20: the element count as the ci child); value
    `lv H`. Line 5: L6 (P 0:5:1): step 1 `tmp V0 = lv a`, `tmp Vv = anew 10 0 0`, `mcpy data(Vv)
    data(V0) (ci 3)`; step 3 `tmp X = ext(a, 0)`; step 4 NV, S, vchk(SHAPE_MISMATCH; S, X, NV);
    no cow (fixed-size); step 6 DT, DV, `bind O = ci 0`, One; step 7 loop(X; Q) { `est 8 0 (eld
    str 8 0 (lv DV) (lv O)) (lv DT) (lv Q)`; O += One }. Line 7: L17 (P 0:7:1): Vv, I0 = ci 0, X0,
    chkb, no cow, `est 8 0 (lv Vv) (adat (lv a)) (lv I0)`. show: the reads stay idx (rule 18)."""
    F = Fn()
    lit = L9b_str(F, '0:4:17', 11, 12, 'l', [cs_('0:4:18', 'x'), cs_('0:4:23', 'y'),
                                              cs_('0:4:28', 'z')])
    P = '0:4:17'
    x = Ctx(F, P, 'f')
    st = [x.tmp('A', lit), x.tmp('R', ext(P, 0, x.lvl('A'))), x.tmp('En', ci(P, 3)),
          x.tmp('S', bin_(P, 2, 'ne', x.lvl('R'), x.lvl('En')))]
    st += x.vchk('SHAPE_EXPECTED', 'S', 'En', 'R', 'V')
    st += [x.tmp('H', anew(P, 10, 0, [])), x.tmp('D', adat(P, 12, x.lvl('A'))),
           mcpy(P, adat(P, 12, x.lvl('H')), x.lvl('D'), ci(P, 3))]
    eds = [(['cs 0:4:18 5 x', 'cs 0:4:23 5 y', 'cs 0:4:28 5 z', 'row 0:4:18 11 3',
             'arr 0:4:17 11 1', 'fix 0:4:17 10'], cat(xblk(P, st, x.lvl('H'))))]
    P = '0:5:1'
    x = Ctx(F, P, 's')
    T = lambda: lv(P, 10, 1)
    st = [x.tmp('V0', lv('0:5:8', 10, 1)), x.tmp('Vv', anew(P, 10, 0, [])),
          mcpy(P, adat(P, 12, x.lvl('Vv')), adat(P, 12, x.lvl('V0')), ci(P, 3)),
          x.tmp('X', ext(P, 0, T())), x.tmp('NV', ext(P, 0, x.lvl('Vv'))),
          x.tmp('S', bin_(P, 2, 'ne', x.lvl('X'), x.lvl('NV')))]
    st += x.vchk('SHAPE_MISMATCH', 'S', 'X', 'NV', 'V')
    st += [x.tmp('DT', adat(P, 12, T())), x.tmp('DV', adat(P, 12, x.lvl('Vv'))),
           x.bindl('O', ci(P, 0)), x.tmp('One', ci(P, 1))]
    st += x.loop('X', 'Z', 'O1', 'L', 'Q', lambda: [
        estS(P, 8, 0, eldS(P, 5, 8, 0, x.lvl('DV'), x.lvl('O')), x.lvl('DT'), x.klv('Q')),
        x.plus_eq('O', x.lvl('One'))])
    eds.append((['lv 0:5:1 10 1', 'all 0:5:3 1', 'idx 0:5:1 11 1', 'lv 0:5:8 10 1',
                 'asg 0:5:1 set'], cat(block(P, st))))
    P = '0:7:1'
    x = Ctx(F, P, 'e')
    st = [x.tmp('Vv', cs_('0:7:8', 'w')), x.tmp('I0', ci('0:7:3', 0)),
          x.tmp('X0', ext(P, 0, lv(P, 10, 1))), chkb(P, 0, x.lvl('I0'), x.lvl('X0')),
          estS(P, 8, 0, x.lvl('Vv'), adat(P, 12, lv(P, 10, 1)), x.lvl('I0'))]
    eds.append((['lv 0:7:1 10 1', 'ci 0:7:3 3 0', 'idx 0:7:1 5 1', 'cs 0:7:8 5 w',
                 'asg 0:7:1 set'], cat(block(P, st))))
    return make_hirl(HIR12['str_fixed_self'], ['tptr 12 5'], {1: (F, eds)})


HIRL2['str_fixed_self'] = hirl_str_fixed_self
# sea.lir1. .main, line 4: `sa` of a's slot s1 (rule 27 (b)), the literal (rule 26 (b): sea_arr_new
# ek 4, each `la` retained), the fix (rule 27 (j)): extent, `li 3`, `icmp ne`, `li -1`, `chk
# SHAPE_EXPECTED`, the home s2, data(A), R20's `li B 24` (3 x 8), `mcopy`, the unrolled retains at
# 0, 8, 16 (A borrowed through its data), A released after the xblk's value (T2), then the copy
# into a (27 (c): the owned home moved, no retains). Line 5 (L6): V0 the alias of a, Vv's home s3,
# R20's copy with the retains (the root borrowed), X and NV `li 3` (static extents), the shape
# check, DT and DV the homes, O and One, loop(X; Q) { the borrowed `ldp` of DV at O, R17 (a):
# `retain`, `ldp O`, `stp`, `release O`; O += 1 }, then Vv released by rule 15 (g) (ascending
# offsets). Line 6: the home's address as the argument (27 (h)). Line 7 (L17): `la`, `li 0`, `li 3`,
# `chkb`, R17 (a) into a's home. At the end a released by rule 16 (its three elements). show: three
# rule 18 reads of the fixed-size base (`li 3` extents, no data load), the slot s1 of 24 bytes.
LIR12['str_fixed_self'] = J(
    'func .main main 0:1:1 0 0', 'slot s1 24 8', 'slot s2 24 8', 'slot s3 24 8',
    'sa p.a s1',
    'li i.R 3', 'li i.ek 4', 'li i.rk 1', 'li i.C 1',
    'rcall sea_arr_new 0:4 1 p.A 4 i.ek i.rk i.R i.C', 'ldp p.D p.A - 0 40',
    'la p.x d1', 'retain p.x', 'stp p.x p.D - 0 0', 'la p.y d2', 'retain p.y', 'stp p.y p.D - 0 8',
    'la p.z d3', 'retain p.z', 'stp p.z p.D - 0 16',
    'ldi i.R4 p.A - 0 16', 'li i.En 3', 'icmp ne i.S4 i.R4 i.En', 'li i.V4 -1',
    'chk i.S4 SHAPE_EXPECTED 0:4 4 i.En i.V4 i.R4 i.V4',
    'sa p.H s2', 'ldp p.D4 p.A - 0 40', 'li i.B4 24', 'mcopy p.H p.D4 i.B4',
    'ldp p.h0 p.H - 0 0', 'retain p.h0', 'ldp p.h1 p.H - 0 8', 'retain p.h1',
    'ldp p.h2 p.H - 0 16', 'retain p.h2', 'release p.A', 'li i.N4 24', 'mcopy p.a p.H i.N4',
    'sa p.Vv s3', 'li i.B5 24', 'mcopy p.Vv p.a i.B5',
    'ldp p.q0 p.Vv - 0 0', 'retain p.q0', 'ldp p.q1 p.Vv - 0 8', 'retain p.q1',
    'ldp p.q2 p.Vv - 0 16', 'retain p.q2',
    'li i.X5 3', 'li i.NV 3', 'icmp ne i.S5 i.X5 i.NV', 'li i.V5 -1',
    'chk i.S5 SHAPE_MISMATCH 0:5 4 i.X5 i.V5 i.NV i.V5',
    'li i.O 0', 'li i.One 1',
    'li i.Z 0', 'icmp gt i.g i.X5 i.Z', 'if 1 i.g', 'li i.O1 1', 'isub i.L i.X5 i.O1',
    'loop 2 i.Q i.Z i.L i.O1', 'ldp p.e p.Vv i.O 8 0', 'retain p.e', 'ldp p.old p.a i.Q 8 0',
    'stp p.e p.a i.Q 8 0', 'release p.old', 'iadd i.O i.O i.One', 'endloop 2', 'endif 1',
    'ldp p.t0 p.Vv - 0 0', 'release p.t0', 'ldp p.t1 p.Vv - 0 8', 'release p.t1',
    'ldp p.t2 p.Vv - 0 16', 'release p.t2',
    'call show 0 1 p.a',
    'la p.w d4', 'li i.I7 0', 'li i.X7 3', 'chkb i.I7 i.X7 0 0:7', 'retain p.w',
    'ldp p.o7 p.a i.I7 8 0', 'stp p.w p.a i.I7 8 0', 'release p.o7',
    'call show 0 1 p.a',
    'ldp p.y0 p.a - 0 0', 'release p.y0', 'ldp p.y1 p.a - 0 8', 'release p.y1',
    'ldp p.y2 p.a - 0 16', 'release p.y2', 'ret 0', 'endfunc',
    'func show fn 0:1:1 1 p.a 0', 'slot s1 24 8',
    'li i.k0 0', 'li i.e0 3', 'chkb i.k0 i.e0 0 0:2', 'ldp p.v0 p.a i.k0 8 0',
    'li i.k1 1', 'li i.e1 3', 'chkb i.k1 i.e1 0 0:2', 'ldp p.v1 p.a i.k1 8 0',
    'li i.k2 2', 'li i.e2 3', 'chkb i.k2 i.e2 0 0:2', 'ldp p.v2 p.a i.k2 8 0',
    'sa p.S s1', 'stp p.v0 p.S - 0 0', 'stp p.v1 p.S - 0 8', 'stp p.v2 p.S - 0 16', 'la p.F d5',
    'rcall sea_printf 0:2 0 2 p.F p.S', 'ret 0', 'endfunc',
    'str d1 x', 'str d2 y', 'str d3 z', 'str d4 w',
    fmt_rec(5, ['fconv - - - s p', 'ftext %20', 'fconv - - - s p', 'ftext %20', 'fconv - - - s p',
                'ftext %0A']))
# a[:] = a leaves a unchanged (LANGUAGE.md 5.5 "Aliasing"); a[0] = "w" then.
OUT2['str_fixed_self'] = 'x y z\nw y z\n'
NAMES4G2.append('str_fixed_self')


# ================================================================ struct_l6_field (L6 with a field root)
SEA2['struct_l6_field'] = '''fn p() -> i64 {
    return 0
}
fn q() -> i64 {
    return 1
}
var dims = [G { v: ones(4) }]
dims[p()].v[q()..3] = 0.0
printf("%g %g %d %d\\n", dims[0].v[1], dims[0].v[3], p(), q())
struct G {
    v: f64[]
}
// struct_l6_field -- DESIGN.md 3.5.9 L6 with a field root (the 4g-2 row of L6): the value, then
// p() (L17 step 3) and q() with the range (L6 step 2) in source order, the path's check and the
// element address E0, IX 2 on the field `fld (lv E0) v` (read afresh), the cows of dims and of
// the field at E' (R23), DT right after the last cow (its register), and the range loop
'''
AST2['struct_l6_field'] = '''
type 0:1:11 i64 s 0
int 0:2:12 0
return 0:2:5 1
block 0:1:15 1
fn 0:1:1 p 0 0 1
type 0:4:11 i64 s 0
int 0:5:12 1
return 0:5:5 1
block 0:4:15 1
fn 0:4:1 q 0 0 1
pname 0:7:5 dims
name 0:7:20 ones
int 0:7:25 4
call 0:7:20 1
init 0:7:17 v
slit 0:7:13 G 1
row 0:7:13 1
array 0:7:12 1
var 0:7:1 0
name 0:8:1 dims
name 0:8:6 p
call 0:8:6 0
index 0:8:1 1
dot 0:8:1 v
name 0:8:13 q
call 0:8:13 0
int 0:8:18 3
range 0:8:13 0 0
index 0:8:1 1
float 0:8:23 #0000000000000000
asg 0:8:1 set
name 0:9:1 printf
str 0:9:8 %25g%20%25g%20%25d%20%25d%0A
name 0:9:25 dims
int 0:9:30 0
index 0:9:25 1
dot 0:9:25 v
int 0:9:35 1
index 0:9:25 1
name 0:9:39 dims
int 0:9:44 0
index 0:9:39 1
dot 0:9:39 v
int 0:9:49 3
index 0:9:39 1
name 0:9:53 p
call 0:9:53 0
name 0:9:58 q
call 0:9:58 0
call 0:9:1 5
cstmt 0:9:1
type 0:11:8 f64 v 0
field 0:11:5 v
struct 0:10:1 G 1
prog 6
'''
# sea.hir1: `loc dims` numbers f64[] 10, G 11, G[] 12; the range index's type i64[] 13 (as a rng
# index of 4e); p and q (two call sites each) are functions 2 and 3.
HIR12['struct_l6_field'] = '''
tvec 10 4
tstruct 11 G 1
fd v 10
tvec 12 11
tvec 13 3
fn 1 .main main 1 0 1 0:1:1
loc dims 12 var 0:7:5
ci 0:7:25 3 4
lib 0:7:20 10 ones 1
slit 0:7:13 11 1
row 0:7:13 12 1
arr 0:7:12 12 1
bind 0:7:1 1
lv 0:8:1 12 1
call 0:8:6 3 2 0
idx 0:8:1 11 1
fld 0:8:1 10 0
call 0:8:13 3 3 0
ci 0:8:18 3 3
rng 0:8:13 13 0 0
idx 0:8:1 10 1
cf 0:8:23 4 #0000000000000000
asg 0:8:1 set
lv 0:9:25 12 1
ci 0:9:30 3 0
idx 0:9:25 11 1
fld 0:9:25 10 0
ci 0:9:35 3 1
idx 0:9:25 4 1
fconv 0:9:8 1 - - - g
ftext 0:9:8 1 %20
lv 0:9:39 12 1
ci 0:9:44 3 0
idx 0:9:39 11 1
fld 0:9:39 10 0
ci 0:9:49 3 3
idx 0:9:39 4 1
fconv 0:9:8 1 - - - g
ftext 0:9:8 1 %20
call 0:9:53 3 2 0
fconv 0:9:8 1 - - - d
ftext 0:9:8 1 %20
call 0:9:58 3 3 0
fconv 0:9:8 1 - - - d
ftext 0:9:8 1 %0A
fmt 0:9:8 1 8
lib 0:9:1 1 printf 1
eval 0:9:1
block 0:1:1 3
end
fn 2 p fn 3 0 0 0:1:1
ci 0:2:12 3 0
ret 0:2:5 1
block 0:1:15 1
end
fn 3 q fn 3 0 0 0:4:1
ci 0:5:12 3 1
ret 0:5:5 1
block 0:4:15 1
end
'''


def hirl_struct_l6_field():
    """sea.hirl: tptr 14 11 (the literal's data), 15 4 (ones's data). Line 7: L9 (b) (P 0:7:12)
    with the slit written in place, its ones L2 (P 0:7:20). Line 8: L6 with a field root (P
    0:8:1): `tmp Vv = cf 0.0` (step 1); `tmp I0 = call p` (L17 step 3), LO = call q, HI, ST, rcnt
    at the rng's position (IX 1); X0, chkb, D0, E0 (L17 step 4); `tmp X = ext (fld (lv E0) v)` and
    the range's checks under `if (lv E)` (IX 2 on the field array, read afresh); no shape check (a
    scalar value); `cow (lv dims)`, D', E', `cow (fld (lv E') v)` (L17 step 5); `tmp DT = adat (fld
    (lv E') v)` (L6 step 6, right after the last cow); rloop(E, LO, L, ST; Q) { `est 8 0 (lv Vv)
    (lv DT) (lv Q)` }."""
    F = Fn()
    tab = type_table(HIR12['struct_l6_field'])
    assert layout(tab, 11)[:3] == (8, 8, [0])
    ones = L2(F, '0:7:20', 10, 4, 15, 'o', ci('0:7:25', 4))
    sl = N(cat(ones) + ['slit 0:7:13 11 1'], 11)
    lit = L9b_any(F, '0:7:12', 12, 14, 'l', 8, [sl])
    eds = [(['ci 0:7:25 3 4', 'lib 0:7:20 10 ones 1', 'slit 0:7:13 11 1', 'row 0:7:13 12 1',
             'arr 0:7:12 12 1'], cat(lit))]
    P = '0:8:1'
    x = Ctx(F, P, 's')
    d = lambda: lv(P, 12, 1)
    st = [x.tmp('Vv', cf('0:8:23', '#0000000000000000')),
          x.tmp('I0', N(['call 0:8:6 3 2 0'], 3)),
          x.tmp('LO', N(['call 0:8:13 3 3 0'], 3)), x.tmp('HI', ci('0:8:18', 3)),
          x.tmp('ST', ci(P, 1)), x.rcnt(0, 'L', 'E', 'LO', 'HI', 'ST', '0:8:13'),
          x.tmp('X0', ext(P, 0, d())), chkb(P, 0, x.lvl('I0'), x.lvl('X0')),
          x.tmp('D0', adat(P, 14, d())), x.tmp('E0', eldS(P, 11, 8, 0, x.lvl('D0'), x.lvl('I0'))),
          x.tmp('X', ext(P, 0, fld(P, 10, 0, x.lvl('E0')))),
          if_(P, x.lvl('E'), block(P, [
              chkb(P, 0, x.lvl('LO'), x.lvl('X')),
              chkb(P, 0, wbin(P, 'add', x.lvl('LO'), wbin(P, 'mul', x.lvl('L'), x.lvl('ST'))),
                   x.lvl('X'))])),
          cowS(P, d()), x.tmp('Dp', adat(P, 14, d())),
          x.tmp('Ep', eldS(P, 11, 8, 0, x.lvl('Dp'), x.lvl('I0'))),
          cowS(P, fld(P, 10, 0, x.lvl('Ep'))),
          x.tmp('DT', adat(P, 15, fld(P, 10, 0, x.lvl('Ep'))))]
    st.append(x.rloop('E', 'LO', 'L', 'ST', 'Q', lambda: [
        est(P, 4, x.lvl('Vv'), x.lvl('DT'), x.klv('Q'))]))
    old = lines(HIR12['struct_l6_field'])
    eds.append((old[old.index('lv 0:8:1 12 1'):old.index('asg 0:8:1 set') + 1], cat(block(P, st))))
    return make_hirl(HIR12['struct_l6_field'], ['tptr 14 11', 'tptr 15 4'], {1: (F, eds)})


HIRL2['struct_l6_field'] = hirl_struct_l6_field
# sea.lir1. .main, line 7: L9 (b) of G[] (G's slay d1, sea_arr_new_s) into dims, E = D + 0, the
# slit's v the ones (rule 17's example: `li 4`, arrnew sea_arr_new_u, `lf 1.0`, data, loop(N; K)
# `stf`; `if 1`/`loop 2`) moved by its `stp`. Line 8: `lf 0.0`; `call p`; `call q`, `li 3`, `li 1`,
# `rcount` (the rng's line); dims's extent and `chkb`, its data, E0 (R18); the field `ldp` at E0
# and its extent; the range checks under `if 3` (rule 21: lo, then lo + L*st); cow(dims) (`if 4`),
# D', E', the memory form of cow at E' (`if 5`), DT the data of that cow's A (R23); the range loop
# (`if 6`, `loop 7`) storing at Q. Line 9: rule 18's reads, p and q, the slot s1 of 32 bytes;
# dims released (rule 16 (a)). p, q: `li`, `ret 1`.
LIR12['struct_l6_field'] = J(
    'func .main main 0:1:1 0 0', 'slot s1 32 8',
    'li i.R 1', 'la p.L d1', 'li i.rk 1', 'li i.C 1',
    'rcall sea_arr_new_s 0:7 1 p.dims 4 p.L i.rk i.R i.C', 'ldp p.D p.dims - 0 40',
    'li i.O0 0', 'padd p.E0 p.D i.O0',
    'li i.R2 4', 'li i.ek 1', 'li i.rk2 1', 'li i.C2 1',
    'rcall sea_arr_new_u 0:7 1 p.A 4 i.ek i.rk2 i.R2 i.C2', 'lf f.one #3FF0000000000000',
    'ldp p.DA p.A - 0 40', 'li i.Z 0', 'icmp gt i.g i.R2 i.Z', 'if 1 i.g', 'li i.O 1',
    'isub i.Lq i.R2 i.O', 'loop 2 i.K i.Z i.Lq i.O', 'stf f.one p.DA i.K 8 0', 'endloop 2',
    'endif 1', 'stp p.A p.E0 - 0 0',
    'lf f.z #0000000000000000', 'call p 1 i.I0 0', 'call q 1 i.LO 0', 'li i.HI 3', 'li i.ST 1',
    'rcount i.L i.E i.LO i.HI i.ST 0 0:8',
    'ldi i.X0 p.dims - 0 16', 'chkb i.I0 i.X0 0 0:8', 'ldp p.D0 p.dims - 0 40',
    'li i.S0 8', 'imul i.T0 i.I0 i.S0', 'padd p.e0 p.D0 i.T0',
    'ldp p.F0 p.e0 - 0 0', 'ldi i.X p.F0 - 0 16',
    'if 3 i.E', 'chkb i.LO i.X 0 0:8', 'imul i.m i.L i.ST', 'iadd i.h i.LO i.m',
    'chkb i.h i.X 0 0:8', 'endif 3',
    'ldi i.c0 p.dims - 0 0', 'li i.o0 1', 'icmp ne i.u0 i.c0 i.o0', 'if 4 i.u0',
    'rcall sea_arr_unique 0:8 1 p.n0 1 p.dims', 'mov p.dims p.n0', 'endif 4',
    'ldp p.Dp p.dims - 0 40', 'li i.Sp 8', 'imul i.Tp i.I0 i.Sp', 'padd p.Ep p.Dp i.Tp',
    'ldp p.A1 p.Ep - 0 0', 'ldi i.c1 p.A1 - 0 0', 'li i.o1 1', 'icmp ne i.u1 i.c1 i.o1',
    'if 5 i.u1', 'rcall sea_arr_unique 0:8 1 p.n1 1 p.A1', 'stp p.n1 p.Ep - 0 0',
    'mov p.A1 p.n1', 'endif 5', 'ldp p.DT p.A1 - 0 40',
    'if 6 i.E', 'loop 7 i.Q i.LO i.L i.ST', 'stf f.z p.DT i.Q 8 0', 'endloop 7', 'endif 6',
    'li i.a1 0', 'ldi i.e1 p.dims - 0 16', 'chkb i.a1 i.e1 0 0:9', 'ldp p.d1 p.dims - 0 40',
    'ldp p.w1 p.d1 i.a1 8 0', 'li i.b1 1', 'ldi i.f1 p.w1 - 0 16', 'chkb i.b1 i.f1 0 0:9',
    'ldp p.g1 p.w1 - 0 40', 'ldf f.v1 p.g1 i.b1 8 0',
    'li i.a2 0', 'ldi i.e2 p.dims - 0 16', 'chkb i.a2 i.e2 0 0:9', 'ldp p.d2 p.dims - 0 40',
    'ldp p.w2 p.d2 i.a2 8 0', 'li i.b2 3', 'ldi i.f2 p.w2 - 0 16', 'chkb i.b2 i.f2 0 0:9',
    'ldp p.g2 p.w2 - 0 40', 'ldf f.v2 p.g2 i.b2 8 0',
    'call p 1 i.pp 0', 'call q 1 i.qq 0',
    'sa p.S s1', 'stf f.v1 p.S - 0 0', 'stf f.v2 p.S - 0 8', 'sti i.pp p.S - 0 16',
    'sti i.qq p.S - 0 24', 'la p.F d2', 'rcall sea_printf 0:9 0 2 p.F p.S',
    'release p.dims', 'ret 0', 'endfunc',
    'func p fn 0:1:1 0 1 i', 'li i.r 0', 'ret 1 i.r', 'endfunc',
    'func q fn 0:4:1 0 1 i', 'li i.r 1', 'ret 1 i.r', 'endfunc',
    'slay d1 8 1', 'soff 0',
    fmt_rec(2, ['fconv - - - g f', 'ftext %20', 'fconv - - - g f', 'ftext %20', 'fconv - - - d i',
                'ftext %20', 'fconv - - - d i', 'ftext %0A']))
# v = [1, 1, 1, 1]; v[1..3] = 0.0 sets v[1] and v[2] (LANGUAGE.md 5.4: `..` excludes hi): 0, 1.
OUT2['struct_l6_field'] = '0 1 0 1\n'
NAMES4G2.append('struct_l6_field')


# ================================================================ rec_slay (records: L9 with the slay, L4)
SEA2['rec_slay'] = '''let rs = [{ a: 1, b: "x" }, { a: 2, b: "y" }]
var t = 0
for r in rs {
    t += r.a
    printf("%s\\n", r.b)
}
printf("%d\\n", t)
// rec_slay -- DESIGN.md 3.6.6 rule 38 for a record type (lead decision L-m): the literal of line 1
// is L9 (b) with record elements (sea_arr_new_s with the record's slay: size 16, its str at 8,
// R21; each record literal written in place, R19); line 3 L4 over records (X the element's
// address, R18), the fields read through it (rule 27 (e))
'''
AST2['rec_slay'] = '''
pname 0:1:5 rs
int 0:1:16 1
init 0:1:13 a
str 0:1:22 x
init 0:1:19 b
rlit 0:1:11 2
int 0:1:34 2
init 0:1:31 a
str 0:1:40 y
init 0:1:37 b
rlit 0:1:29 2
row 0:1:11 2
array 0:1:10 1
let 0:1:1 0
pname 0:2:5 t
int 0:2:9 0
var 0:2:1 0
name 0:3:10 rs
name 0:4:5 t
name 0:4:10 r
dot 0:4:10 a
asg 0:4:5 add
name 0:5:5 printf
str 0:5:12 %25s%0A
name 0:5:20 r
dot 0:5:20 b
call 0:5:5 2
cstmt 0:5:5
block 0:3:13 2
for 0:3:1 r 0:3:5
name 0:7:1 printf
str 0:7:8 %25d%0A
name 0:7:16 t
call 0:7:1 2
cstmt 0:7:1
prog 4
'''
# sea.hir1: the record type {a: i64, b: str} 10 (`trec`, fields in written order, LANGUAGE.md 4.6),
# its vector 11; the record literals are slit of type 10 at their `{`.
HIR12['rec_slay'] = '''
trec 10 2
fd a 3
fd b 5
tvec 11 10
fn 1 .main main 1 0 3 0:1:1
loc rs 11 let 0:1:5
loc t 3 var 0:2:5
loc r 10 for 0:3:5
ci 0:1:16 3 1
cs 0:1:22 5 x
slit 0:1:11 10 2
ci 0:1:34 3 2
cs 0:1:40 5 y
slit 0:1:29 10 2
row 0:1:11 11 2
arr 0:1:10 11 1
bind 0:1:1 1
ci 0:2:9 3 0
bind 0:2:1 2
lv 0:3:10 11 1
lv 0:4:5 3 2
lv 0:4:10 10 3
fld 0:4:10 3 0
asg 0:4:5 add
lv 0:5:20 10 3
fld 0:5:20 5 1
fconv 0:5:12 1 - - - s
ftext 0:5:12 1 %0A
fmt 0:5:12 1 2
lib 0:5:5 1 printf 1
eval 0:5:5
block 0:3:13 2
fore 0:3:1 3
lv 0:7:16 3 2
fconv 0:7:8 1 - - - d
ftext 0:7:8 1 %0A
fmt 0:7:8 1 2
lib 0:7:1 1 printf 1
eval 0:7:1
block 0:1:1 4
end
'''


def hirl_rec_slay():
    """sea.hirl: tptr 12 10. Line 1: L9 (b) (P 0:1:10), each record literal kept and written in
    place (R19). Line 3: L4 (P 0:3:1) with `bind H = lv rs` and X = `eld P 10 16 0 (lv D) (lv K)`
    (4g-2: the element's address, R18) bound to r by its `tmp`; the body unchanged."""
    F = Fn()
    tab = type_table(HIR12['rec_slay'])
    assert layout(tab, 10)[:3] == (16, 8, [8])
    lit = L9b_any(F, '0:1:10', 11, 12, 'l', 16, [
        N(['ci 0:1:16 3 1', 'cs 0:1:22 5 x', 'slit 0:1:11 10 2'], 10),
        N(['ci 0:1:34 3 2', 'cs 0:1:40 5 y', 'slit 0:1:29 10 2'], 10)])
    old = lines(HIR12['rec_slay'])
    body = old[old.index('lv 0:4:5 3 2'):old.index('block 0:3:13 2') + 1]
    P = '0:3:1'
    x = Ctx(F, P, 'f')
    s = [x.bindl('H', lv('0:3:10', 11, 1)), x.tmp('N', ext(P, 0, x.lvl('H'))), x.tmp('Z', ci(P, 0))]
    cond = bin_(P, 2, 'gt', x.lvl('N'), x.lvl('Z'))
    inner = [x.tmp('D', adat(P, 12, x.lvl('H'))), x.tmp('O', ci(P, 1)),
             x.tmp('L', wbin(P, 'sub', x.lvl('N'), x.lvl('O')))]
    hb = [N(eldS(P, 10, 16, 0, x.lvl('D'), x.klv('K'))[0] + ['tmp %s 3' % P], None), N(body, None)]
    inner.append(x.hloop('K', x.lvl('Z'), x.lvl('L'), x.lvl('O'), hb))
    s.append(if_(P, cond, block(P, inner)))
    eds = [(old[old.index('ci 0:1:16 3 1'):old.index('arr 0:1:10 11 1') + 1], cat(lit)),
           (old[old.index('lv 0:3:10 11 1'):old.index('fore 0:3:1 3') + 1], cat(block(P, s)))]
    return make_hirl(HIR12['rec_slay'], ['tptr 12 10'], {1: (F, eds)})


HIRL2['rec_slay'] = hirl_rec_slay
# sea.lir1. Line 1: `li 2`, arrnew with `la` of the record's slay d1 (rule 38, L-m: 16 bytes, one
# reference at 8; sea_arr_new_s, R21) into rs (T3), the data; each record (R19 into a fresh address:
# `li O k*16`, `padd`) its a `sti` at 0, its b `la` retained and `stp` at 8 (rule 27 (g), 15 (a)).
# Line 2: t's `li`. Line 3: L4 (rule 30): H `mov`, `retain` (rs borrowed), the extent, loop(N; K)
# with r the element's address (`li S 16`, `imul`, `padd`, R18); `t += r.a`: `ldi` of the field
# (27 (e)), `iaddc` into t (rule 1); the printf of `r.b` (`ldp`, borrowed) with its slot s1; H
# released after the construct. Line 7: the printf (slot s2); rs released at the end.
LIR12['rec_slay'] = J(
    'func .main main 0:1:1 0 0', 'slot s1 8 8', 'slot s2 8 8',
    'li i.R 2', 'la p.L d1', 'li i.rk 1', 'li i.C 1',
    'rcall sea_arr_new_s 0:1 1 p.rs 4 p.L i.rk i.R i.C', 'ldp p.D p.rs - 0 40',
    'li i.O0 0', 'padd p.E0 p.D i.O0', 'li i.a0 1', 'sti i.a0 p.E0 - 0 0',
    'la p.x d2', 'retain p.x', 'stp p.x p.E0 - 0 8',
    'li i.O1 16', 'padd p.E1 p.D i.O1', 'li i.a1 2', 'sti i.a1 p.E1 - 0 0',
    'la p.y d3', 'retain p.y', 'stp p.y p.E1 - 0 8',
    'li i.t 0',
    'mov p.H p.rs', 'retain p.H', 'ldi i.N p.H - 0 16', 'li i.Z 0', 'icmp gt i.E i.N i.Z',
    'if 1 i.E', 'ldp p.DH p.H - 0 40', 'li i.O 1', 'isub i.L i.N i.O', 'loop 2 i.K i.Z i.L i.O',
    'li i.S 16', 'imul i.T i.K i.S', 'padd p.r p.DH i.T',
    'ldi i.ra p.r - 0 0', 'iaddc i.t i.t i.ra 0:4',
    'ldp p.rb p.r - 0 8', 'sa p.P s1', 'stp p.rb p.P - 0 0', 'la p.F d4',
    'rcall sea_printf 0:5 0 2 p.F p.P', 'endloop 2', 'endif 1', 'release p.H',
    'sa p.P2 s2', 'sti i.t p.P2 - 0 0', 'la p.F2 d5', 'rcall sea_printf 0:7 0 2 p.F2 p.P2',
    'release p.rs', 'ret 0', 'endfunc',
    'slay d1 16 1', 'soff 8', 'str d2 x', 'str d3 y',
    fmt_rec(4, ['fconv - - - s p', 'ftext %0A']), fmt_rec(5, ['fconv - - - d i', 'ftext %0A']))
OUT2['rec_slay'] = 'x\ny\n3\n'
NAMES4G2.append('rec_slay')


# ================================================================ struct_l12 (L12 with field and aggregate targets)
SEA2['struct_l12'] = '''fn two(k: i64) -> (str, i64) {
    return (str(k), k + 1)
}
fn mk(k: i64) -> (P, i64) {
    return (P { name: str(k), x: 1.5 }, k)
}
var s = P { name: "a", x: 0.5 }
var ps = [P { name: "b", x: 2.5 }]
var k = 0
(s.name, k) = two(7)
(ps[0], k) = mk(k)
printf("%s %d %s %g\\n", s.name, k, ps[0].name, ps[0].x)
ps[0] = P { name: "c", x: 3.5 }
let (t, j) = two(3)
let (q, m) = mk(4)
printf("%s %d %s %d %s\\n", t, j, q.name, m, ps[0].name)
struct P {
    name: str
    x: f64
}
// struct_l12 -- DESIGN.md 3.5.9 L12 with a field target (line 10, `s.name`) and an aggregate
// element target (line 11, `ps[0]`): L17's block directly in the L12 block, no `tmp Vv`, its est
// storing the .l local itself, which R25 moves (R17's stp; R19's copy with no retains, the old
// name released); line 13 a slit into an existing element (R19, rule 27 (d): its own temporary
// home, the old reference field released); lines 14-15 tbinds (a struct result into q's slot)
'''
AST2['struct_l12'] = '''
type 0:1:11 i64 s 0
param 0:1:8 k 0 0
type 0:1:20 str s 0
type 0:1:25 i64 s 0
name 0:2:17 k
conv 0:2:13 str
name 0:2:21 k
int 0:2:25 1
bin 0:2:21 add
return 0:2:5 2
block 0:1:30 1
fn 0:1:1 two 0 1 2
type 0:4:10 i64 s 0
param 0:4:7 k 0 0
type 0:4:19 P s 0
type 0:4:22 i64 s 0
name 0:5:27 k
conv 0:5:23 str
init 0:5:17 name
float 0:5:34 #3FF8000000000000
init 0:5:31 x
slit 0:5:13 P 2
name 0:5:41 k
return 0:5:5 2
block 0:4:27 1
fn 0:4:1 mk 0 1 2
pname 0:7:5 s
str 0:7:19 a
init 0:7:13 name
float 0:7:27 #3FE0000000000000
init 0:7:24 x
slit 0:7:9 P 2
var 0:7:1 0
pname 0:8:5 ps
str 0:8:21 b
init 0:8:15 name
float 0:8:29 #4004000000000000
init 0:8:26 x
slit 0:8:11 P 2
row 0:8:11 1
array 0:8:10 1
var 0:8:1 0
pname 0:9:5 k
int 0:9:9 0
var 0:9:1 0
name 0:10:2 s
dot 0:10:2 name
name 0:10:10 k
name 0:10:15 two
int 0:10:19 7
call 0:10:15 1
tasg 0:10:1 2
name 0:11:2 ps
int 0:11:5 0
index 0:11:2 1
name 0:11:9 k
name 0:11:14 mk
name 0:11:17 k
call 0:11:14 1
tasg 0:11:1 2
name 0:12:1 printf
str 0:12:8 %25s%20%25d%20%25s%20%25g%0A
name 0:12:25 s
dot 0:12:25 name
name 0:12:33 k
name 0:12:36 ps
int 0:12:39 0
index 0:12:36 1
dot 0:12:36 name
name 0:12:48 ps
int 0:12:51 0
index 0:12:48 1
dot 0:12:48 x
call 0:12:1 5
cstmt 0:12:1
name 0:13:1 ps
int 0:13:4 0
index 0:13:1 1
str 0:13:19 c
init 0:13:13 name
float 0:13:27 #400C000000000000
init 0:13:24 x
slit 0:13:9 P 2
asg 0:13:1 set
pname 0:14:6 t
pname 0:14:9 j
ptuple 0:14:5 2
name 0:14:14 two
int 0:14:18 3
call 0:14:14 1
let 0:14:1 0
pname 0:15:6 q
pname 0:15:9 m
ptuple 0:15:5 2
name 0:15:14 mk
int 0:15:17 4
call 0:15:14 1
let 0:15:1 0
name 0:16:1 printf
str 0:16:8 %25s%20%25d%20%25s%20%25d%20%25s%0A
name 0:16:28 t
name 0:16:31 j
name 0:16:34 q
dot 0:16:34 name
name 0:16:42 m
name 0:16:45 ps
int 0:16:48 0
index 0:16:45 1
dot 0:16:45 name
call 0:16:1 6
cstmt 0:16:1
type 0:18:11 str s 0
field 0:18:5 name
type 0:19:8 f64 s 0
field 0:19:5 x
struct 0:17:1 P 2
prog 13
'''
# sea.hir1: P 10 (`loc s`), P[] 11 (`loc ps`), the result tuples (str, i64) 12 and (P, i64) 13 at
# the calls of lines 10 and 11; each tasg its targets, then the call, no cv.
HIR12['struct_l12'] = '''
tstruct 10 P 2
fd name 5
fd x 4
tvec 11 10
ttuple 12 2 5 3
ttuple 13 2 10 3
fn 1 .main main 1 0 7 0:1:1
loc s 10 var 0:7:5
loc ps 11 var 0:8:5
loc k 3 var 0:9:5
loc t 5 let 0:14:6
loc j 3 let 0:14:9
loc q 10 let 0:15:6
loc m 3 let 0:15:9
cs 0:7:19 5 a
cf 0:7:27 4 #3FE0000000000000
slit 0:7:9 10 2
bind 0:7:1 1
cs 0:8:21 5 b
cf 0:8:29 4 #4004000000000000
slit 0:8:11 10 2
row 0:8:11 11 1
arr 0:8:10 11 1
bind 0:8:1 2
ci 0:9:9 3 0
bind 0:9:1 3
lv 0:10:2 10 1
fld 0:10:2 5 0
lv 0:10:10 3 3
ci 0:10:19 3 7
call 0:10:15 12 2 1
tasg 0:10:1 2 0 0
lv 0:11:2 11 2
ci 0:11:5 3 0
idx 0:11:2 10 1
lv 0:11:9 3 3
lv 0:11:17 3 3
call 0:11:14 13 3 1
tasg 0:11:1 2 0 0
lv 0:12:25 10 1
fld 0:12:25 5 0
fconv 0:12:8 1 - - - s
ftext 0:12:8 1 %20
lv 0:12:33 3 3
fconv 0:12:8 1 - - - d
ftext 0:12:8 1 %20
lv 0:12:36 11 2
ci 0:12:39 3 0
idx 0:12:36 10 1
fld 0:12:36 5 0
fconv 0:12:8 1 - - - s
ftext 0:12:8 1 %20
lv 0:12:48 11 2
ci 0:12:51 3 0
idx 0:12:48 10 1
fld 0:12:48 4 1
fconv 0:12:8 1 - - - g
ftext 0:12:8 1 %0A
fmt 0:12:8 1 8
lib 0:12:1 1 printf 1
eval 0:12:1
lv 0:13:1 11 2
ci 0:13:4 3 0
idx 0:13:1 10 1
cs 0:13:19 5 c
cf 0:13:27 4 #400C000000000000
slit 0:13:9 10 2
asg 0:13:1 set
ci 0:14:18 3 3
call 0:14:14 12 2 1
tbind 0:14:1 2 4 5
ci 0:15:17 3 4
call 0:15:14 13 3 1
tbind 0:15:1 2 6 7
lv 0:16:28 5 4
fconv 0:16:8 1 - - - s
ftext 0:16:8 1 %20
lv 0:16:31 3 5
fconv 0:16:8 1 - - - d
ftext 0:16:8 1 %20
lv 0:16:34 10 6
fld 0:16:34 5 0
fconv 0:16:8 1 - - - s
ftext 0:16:8 1 %20
lv 0:16:42 3 7
fconv 0:16:8 1 - - - d
ftext 0:16:8 1 %20
lv 0:16:45 11 2
ci 0:16:48 3 0
idx 0:16:45 10 1
fld 0:16:45 5 0
fconv 0:16:8 1 - - - s
ftext 0:16:8 1 %0A
fmt 0:16:8 1 10
lib 0:16:1 1 printf 1
eval 0:16:1
block 0:1:1 10
end
fn 2 two fn 12 1 0 0:1:1
par k 3 val
lv 0:2:17 3 1
lib 0:2:13 5 str 1
lv 0:2:21 3 1
ci 0:2:25 3 1
bin 0:2:21 3 add
ret 0:2:5 2
block 0:1:30 1
end
fn 3 mk fn 13 1 0 0:4:1
par k 3 val
lv 0:5:27 3 1
lib 0:5:23 5 str 1
cf 0:5:34 4 #3FF8000000000000
slit 0:5:13 10 2
lv 0:5:41 3 1
ret 0:5:5 2
block 0:4:27 1
end
'''


def hirl_struct_l12():
    """sea.hirl: tptr 14 10. Line 8: L9 (b) (P 0:8:10). Line 10: L12 (P 0:10:1) `block P 3` {
    `tbind P 2 L1 L2` of the call; the L17 block of `s.name` (a struct root: no indices, checks or
    cows) with only its est `est 16 0 (lv L1) (adat (lv s)) (ci 0)` (step 1's exception); `asg set
    (lv k) (lv L2)` }. Line 11: the same with `tbind P 2 L3 L4` (L3 of type P) and the L17 block of
    `ps[0]` (I0 = ci 0, X0, chkb, `cow (lv ps)`, `est 16 0 (lv L3) (adat (lv ps)) (lv I0)`). Line
    13: L17 (P 0:13:1) with the slit as `tmp Vv`. The root lv nodes L12's L17 blocks write take P
    (as str_l12's)."""
    F = Fn()
    tab = type_table(HIR12['struct_l12'])
    assert layout(tab, 10)[:3] == (16, 8, [0])
    lit = L9b_any(F, '0:8:10', 11, 14, 'l', 16, [
        N(['cs 0:8:21 5 b', 'cf 0:8:29 4 #4004000000000000', 'slit 0:8:11 10 2'], 10)])
    eds = [(['cs 0:8:21 5 b', 'cf 0:8:29 4 #4004000000000000', 'slit 0:8:11 10 2',
             'row 0:8:11 11 1', 'arr 0:8:10 11 1'], cat(lit))]
    P = '0:10:1'
    L1 = F.d('L1', 5, 'let', P)
    L2 = F.d('L2', 3, 'let', P)
    tb = N(['ci 0:10:19 3 7', 'call 0:10:15 12 2 1', 'tbind %s 2 %s %s' % (P, L1, L2)], None)
    l17 = block(P, [estS(P, 16, 0, lv(P, 5, L1), adat(P, 14, lv(P, 10, 1)), ci(P, 0))])
    sk = asg(P, 'set', lv('0:10:10', 3, 3), lv(P, 3, L2))
    eds.append((['lv 0:10:2 10 1', 'fld 0:10:2 5 0', 'lv 0:10:10 3 3', 'ci 0:10:19 3 7',
                 'call 0:10:15 12 2 1', 'tasg 0:10:1 2 0 0'], cat(block(P, [tb, l17, sk]))))
    P = '0:11:1'
    L3 = F.d('L3', 10, 'let', P)
    L4 = F.d('L4', 3, 'let', P)
    tb = N(['lv 0:11:17 3 3', 'call 0:11:14 13 3 1', 'tbind %s 2 %s %s' % (P, L3, L4)], None)
    x = Ctx(F, P, 'b')
    ps = lambda: lv(P, 11, 2)
    l17 = block(P, [x.tmp('I0', ci('0:11:5', 0)), x.tmp('X0', ext(P, 0, ps())),
                    chkb(P, 0, x.lvl('I0'), x.lvl('X0')), cow(P, ps()),
                    estS(P, 16, 0, lv(P, 10, L3), adat(P, 14, ps()), x.lvl('I0'))])
    sk = asg(P, 'set', lv('0:11:9', 3, 3), lv(P, 3, L4))
    eds.append((['lv 0:11:2 11 2', 'ci 0:11:5 3 0', 'idx 0:11:2 10 1', 'lv 0:11:9 3 3',
                 'lv 0:11:17 3 3', 'call 0:11:14 13 3 1', 'tasg 0:11:1 2 0 0'],
                cat(block(P, [tb, l17, sk]))))
    P = '0:13:1'
    x = Ctx(F, P, 'c')
    ps = lambda: lv(P, 11, 2)
    sl = N(['cs 0:13:19 5 c', 'cf 0:13:27 4 #400C000000000000', 'slit 0:13:9 10 2'], 10)
    st = [x.tmp('Vv', sl), x.tmp('I0', ci('0:13:4', 0)), x.tmp('X0', ext(P, 0, ps())),
          chkb(P, 0, x.lvl('I0'), x.lvl('X0')), cow(P, ps()),
          estS(P, 16, 0, x.lvl('Vv'), adat(P, 14, ps()), x.lvl('I0'))]
    eds.append((['lv 0:13:1 11 2', 'ci 0:13:4 3 0', 'idx 0:13:1 10 1'] + sl[0] + ['asg 0:13:1 set'],
                cat(block(P, st))))
    return make_hirl(HIR12['struct_l12'], ['tptr 14 10'], {1: (F, eds)})


HIRL2['struct_l12'] = hirl_struct_l12
# sea.lir1. .main: line 7 rule 27 (b), (g) into s's slot s1; line 8 L9 (b) (P's slay d2) with the
# slit in place; line 9 `li`. Line 10 (L12): `li 7`, the call into L1 and L2 (rule 2), the L17
# block's est R17 at s + 0 with R25's move (`ldp O`, `stp L1`, `release O`, no retain), `mov k
# L2`; no release of L1 at the block's end. Line 11: L3's slot s2 passed as mk's hidden result
# address (rule 27 (l), (b)), L4 the register result; the L17 block: `li 0`, the check, cow(ps)
# (`if 1`), the data, R19 into an element that is not fresh with R25's move: E (`li S 16`, `imul`,
# `padd`), no retains, the old name released (`ldp O E - 0 0`, `release`), `li N 16`, `mcopy E
# L3 N`; `mov k L4`. Line 12: rule 27 (e) and rule 18 reads (one load at sc 16 and the field's
# offset), the slot s3. Line 13 (L17): the slit in its temporary slot s4 ("c" retained, 15 (a)),
# `li 0`, the check, the cow (`if 2`), the data, R19 (27 (d)): E, the owned slit moved, the old
# name released, `mcopy`. Line 14: the call into t and j; line 15: `sa` of q's slot s5 (the result
# written in place, 27 (l)). Line 16: the slot s6 of 40 bytes. At the end (rule 16 (a), reverse
# order): q's name, t, ps, s's name. two: rule 32's `str(k)`, the checked add, `ret 2`. mk: the
# hidden address first (3.6.3), the slit written there directly (27 (h): str(k) moved, 1.5), `ret
# 1` with k.
LIR12['struct_l12'] = J(
    'func .main main 0:1:1 0 0',
    'slot s1 16 8', 'slot s2 16 8', 'slot s3 32 8', 'slot s4 16 8', 'slot s5 16 8',
    'slot s6 40 8',
    'sa p.s s1', 'la p.a d1', 'retain p.a', 'stp p.a p.s - 0 0', 'lf f.h #3FE0000000000000',
    'stf f.h p.s - 0 8',
    'li i.R 1', 'la p.L d2', 'li i.rk 1', 'li i.C 1',
    'rcall sea_arr_new_s 0:8 1 p.ps 4 p.L i.rk i.R i.C', 'ldp p.D p.ps - 0 40',
    'li i.O0 0', 'padd p.E0 p.D i.O0', 'la p.b d3', 'retain p.b', 'stp p.b p.E0 - 0 0',
    'lf f.x0 #4004000000000000', 'stf f.x0 p.E0 - 0 8',
    'li i.k 0',
    'li i.c7 7', 'call two 2 p.L1 i.L2 1 i.c7',
    'ldp p.O10 p.s - 0 0', 'stp p.L1 p.s - 0 0', 'release p.O10', 'mov i.k i.L2',
    'sa p.L3 s2', 'call mk 1 i.L4 2 p.L3 i.k',
    'li i.I11 0', 'ldi i.X11 p.ps - 0 16', 'chkb i.I11 i.X11 0 0:11',
    'ldi i.c11 p.ps - 0 0', 'li i.o11 1', 'icmp ne i.u11 i.c11 i.o11', 'if 1 i.u11',
    'rcall sea_arr_unique 0:11 1 p.n11 1 p.ps', 'mov p.ps p.n11', 'endif 1',
    'ldp p.D11 p.ps - 0 40', 'li i.S11 16', 'imul i.T11 i.I11 i.S11', 'padd p.E11 p.D11 i.T11',
    'ldp p.o11 p.E11 - 0 0', 'release p.o11', 'li i.N11 16', 'mcopy p.E11 p.L3 i.N11',
    'mov i.k i.L4',
    'ldp p.n12 p.s - 0 0',
    'li i.a12 0', 'ldi i.e12 p.ps - 0 16', 'chkb i.a12 i.e12 0 0:12', 'ldp p.d12 p.ps - 0 40',
    'ldp p.pn12 p.d12 i.a12 16 0',
    'li i.b12 0', 'ldi i.f12 p.ps - 0 16', 'chkb i.b12 i.f12 0 0:12', 'ldp p.g12 p.ps - 0 40',
    'ldf f.px12 p.g12 i.b12 16 8',
    'sa p.S12 s3', 'stp p.n12 p.S12 - 0 0', 'sti i.k p.S12 - 0 8', 'stp p.pn12 p.S12 - 0 16',
    'stf f.px12 p.S12 - 0 24', 'la p.F12 d4', 'rcall sea_printf 0:12 0 2 p.F12 p.S12',
    'sa p.V13 s4', 'la p.c d5', 'retain p.c', 'stp p.c p.V13 - 0 0',
    'lf f.x13 #400C000000000000', 'stf f.x13 p.V13 - 0 8',
    'li i.I13 0', 'ldi i.X13 p.ps - 0 16', 'chkb i.I13 i.X13 0 0:13',
    'ldi i.c13 p.ps - 0 0', 'li i.o13 1', 'icmp ne i.u13 i.c13 i.o13', 'if 2 i.u13',
    'rcall sea_arr_unique 0:13 1 p.n13 1 p.ps', 'mov p.ps p.n13', 'endif 2',
    'ldp p.D13 p.ps - 0 40', 'li i.S13 16', 'imul i.T13 i.I13 i.S13', 'padd p.E13 p.D13 i.T13',
    'ldp p.o13 p.E13 - 0 0', 'release p.o13', 'li i.N13 16', 'mcopy p.E13 p.V13 i.N13',
    'li i.c3 3', 'call two 2 p.t i.j 1 i.c3',
    'sa p.q s5', 'li i.c4 4', 'call mk 1 i.m 2 p.q i.c4',
    'ldp p.qn p.q - 0 0',
    'li i.a16 0', 'ldi i.e16 p.ps - 0 16', 'chkb i.a16 i.e16 0 0:16', 'ldp p.d16 p.ps - 0 40',
    'ldp p.pn16 p.d16 i.a16 16 0',
    'sa p.S16 s6', 'stp p.t p.S16 - 0 0', 'sti i.j p.S16 - 0 8', 'stp p.qn p.S16 - 0 16',
    'sti i.m p.S16 - 0 24', 'stp p.pn16 p.S16 - 0 32', 'la p.F16 d6',
    'rcall sea_printf 0:16 0 2 p.F16 p.S16',
    'ldp p.r0 p.q - 0 0', 'release p.r0', 'release p.t', 'release p.ps', 'ldp p.r1 p.s - 0 0',
    'release p.r1', 'ret 0', 'endfunc',
    'func two fn 0:1:1 1 i.k 2 p i',
    'rcall sea_str_i64 0:2 1 p.s 1 i.k', 'li i.c 1', 'iaddc i.n i.k i.c 0:2', 'ret 2 p.s i.n',
    'endfunc',
    'func mk fn 0:4:1 2 p.res i.k 1 i',
    'rcall sea_str_i64 0:5 1 p.nm 1 i.k', 'stp p.nm p.res - 0 0',
    'lf f.x #3FF8000000000000', 'stf f.x p.res - 0 8', 'ret 1 i.k', 'endfunc',
    'str d1 a', 'slay d2 16 1', 'soff 0', 'str d3 b',
    fmt_rec(4, ['fconv - - - s p', 'ftext %20', 'fconv - - - d i', 'ftext %20', 'fconv - - - s p',
                'ftext %20', 'fconv - - - g f', 'ftext %0A']),
    'str d5 c',
    fmt_rec(6, ['fconv - - - s p', 'ftext %20', 'fconv - - - d i', 'ftext %20', 'fconv - - - s p',
                'ftext %20', 'fconv - - - d i', 'ftext %20', 'fconv - - - s p', 'ftext %0A']))
# two(7) = ("7", 8): s.name "7", k 8; mk(8) = ({"8", 1.5}, 8) into ps[0] and k (LANGUAGE.md 7.3);
# ps[0] = {"c", 3.5}; two(3) = ("3", 4); mk(4) = ({"4", 1.5}, 4).
OUT2['struct_l12'] = '7 8 8 1.5\n3 4 4 4 c\n'
NAMES4G2.append('struct_l12')


# ================================================================ the self-check (4g-2)
def check_hirl4g2(name):
    """3.5.9 "What the passes validate" and "What the passes validate in 4g", on NAME.hirl with
    the struct and record types: passes.txt (sets H HF HL); the type table of sea.hir with tptr
    records appended in order of first reference; the .l locals numbered last in the order of
    their declaring records with their loc records (mut, position); per node: no fore, proj,
    match, arm, view, arr, row, dyn, fix, all, no rewritten lib; each tmp bound once before its
    uses, of its child's type, a tptr tmp only of adat or cdat; no asg whose target holds a fld or
    is an element whose type holds counts or is a struct (L17); eld/est of a scalar or str at sc
    = its element size, of a struct, record or fixed-size whole element at sc = its size and off
    0 through the tptr of that type (R18, R19), a field through the tptr of a struct S at sc =
    s(S) and off = the field's offset (R24), each size and offset by layout(); a slit est value
    only into a fresh address (R19); anew of a dynamic type with r = its rank, of a fixed-size,
    struct or record type with r = 0 and z = 0 (R1, R21); adat of an array, a struct or record
    home or a fld chain; cow of the lv of a dynamic array local or ref parameter, or of a fld
    chain naming a dynamic array field (R23); an mcpy into a tptr whose element holds counts with
    a type-3 count that is a ci or an lv (R20); an xblk of its last child's type."""
    text = read(name + '.hirl')
    src = read(name + '.sea').split('\n')
    hir = read(name + '.hir')
    body = split_file(name, text, src)
    assert text.split('\n')[:3] == hir.split('\n')[:3], name
    hir_types = [ln for ln in hir.split('\n')[3:] if ln.split(' ')[0] in TYPE_RECS | {'fd'}]
    i = 0
    while i < len(body) and body[i].split(' ')[0] in TYPE_RECS | {'fd', 'tptr'}:
        i += 1
    table, rest = body[:i], body[i:]
    assert table[:len(hir_types)] == hir_types, (name, 'type table differs from sea.hir')
    assert all(ln.startswith('tptr ') for ln in table[len(hir_types):]), name
    tab = type_table('\n'.join(table))
    ids = sorted(tab)
    assert ids == list(range(10, 10 + len(ids))), (name, 'type ids')
    tptrs = [int(ln.split(' ')[1]) for ln in table[len(hir_types):]]
    assert len({tab[t][1] for t in tptrs}) == len(tptrs), (name, 'one tptr per element type')
    first_ref = []
    for ln in rest:
        op, v, _ = parse_rec(name, 'H HF HL'.split(), ln)
        fmt = None
        for s_ in ('H', 'HF', 'HL'):
            if (s_, op) in RECS:
                fmt = RECS[(s_, op)][1]
        for fname, typ, _, cnt in fmt:
            for x in (v[fname] if cnt else [v[fname]]):
                if typ == 'ty' and x != '-' and int(x) in tptrs and int(x) not in first_ref:
                    first_ref.append(int(x))
    assert first_ref == tptrs, (name, 'tptr order', first_ref, tptrs)

    def kind(t):
        if t in (2, 3, 4):
            return 's'
        if t == 5:
            return 'str'
        if t == 1 or t is None:
            return 'void'
        return tab[t][0]

    def holds(t):
        return t not in (None, 1) and bool(layout(tab, t)[2])

    def esize(t):
        return layout(tab, t)[0]

    def field_paths(t, base=0):
        """(offset, type) of every field of struct t, nested ones included."""
        out = []
        o = 0
        for fname, ft in tab[t][1]:
            s_, a, _ = layout(tab, ft)
            o = (o + a - 1) // a * a
            out.append((base + o, ft))
            if kind(ft) == 'st':
                out += field_paths(ft, base + o)
            o += s_
        return out

    nch = 0
    for fn in hirl_trees(name):
        locs = fn['locs']
        lnames = [nm for nm, _ in locs]
        lt = {k + 1: t for k, (_, t) in enumerate(locs)}
        ls = [j for j, nm in enumerate(lnames) if nm.startswith('.l')]
        if ls:
            nch += 1
            assert ls == list(range(ls[0], len(locs))), (name, '.l locals last')
            assert [lnames[j] for j in ls] == ['.l%d' % (q + 1) for q in range(len(ls))], name
        isl = {k + 1: nm.startswith('.l') for k, nm in enumerate(lnames)}

        def ty(n):
            if n['op'] == 'lv':
                assert int(n['v']['ty']) == lt[int(n['v']['lid'])], (name, 'lv type', n['v'])
            t = n['v'].get('ty')
            return int(t) if t not in (None, '-') else None

        def fresh(addr, nodes_before):
            """3.5.9: lv D of a tmp D = adat (lv A) whose tmp A = anew lies in the same xblk or
            block (checked here: the anew tmp exists in the function)."""
            if addr['op'] != 'lv':
                return False
            L = addr['v']['lid']
            for m in nodes_before:
                if m['op'] == 'tmp' and m['v']['lid'] == L:
                    c = m['kids'][0]
                    if c['op'] != 'adat' or c['kids'][0]['op'] != 'lv':
                        return False
                    A = c['kids'][0]['v']['lid']
                    return any(q['op'] == 'tmp' and q['v']['lid'] == A and
                               q['kids'][0]['op'] == 'anew' for q in nodes_before)
            return False

        bound = {}
        for k, n in enumerate(fn['nodes']):
            op, v, kids = n['op'], n['v'], n['kids']
            assert op not in ('fore', 'proj', 'match', 'arm', 'view', 'arr', 'row', 'dyn', 'fix',
                              'all'), (name, 'R10', op)
            assert not (op == 'lib' and v['name'] in REWRITTEN_LIB), (name, op, v)
            t = ty(n)
            kt = [ty(c) for c in kids]
            if op == 'tmp':
                L = int(v['lid'])
                assert L not in bound, (name, 'tmp bound twice', L)
                bound[L] = k
                assert lt[L] == kt[0], (name, 'tmp type', v, lt[L], kt[0])
                if kind(lt[L]) == 'ptr':
                    assert kids[0]['op'] in ('adat', 'cdat'), (name, 'tptr tmp')
            elif op == 'lv' and int(v['lid']) in bound:
                pass
            elif op == 'asg':
                tg = kids[0]
                stack_ = [tg]
                while stack_:
                    m = stack_.pop()
                    assert m['op'] != 'fld', (name, 'L17: a fld in an asg target')
                    if m['op'] == 'idx':
                        stack_.append(m['kids'][0])
                if tg['op'] == 'idx':
                    et = ty(tg)
                    assert not (holds(et) or kind(et) == 'st'), (name, 'L17: element target', et)
            elif op in ('eld', 'est'):
                a = kids[0] if op == 'eld' else kids[1]
                at = ty(a)
                vt = t if op == 'eld' else kt[0]
                assert kind(at) == 'ptr', (name, op, 'address', v)
                elt = tab[at][1]
                sc, off = int(v['sc']), int(v['off'])
                ix = kids[1] if op == 'eld' else kids[2]
                assert ty(ix) == 3, (name, op, 'index type')
                if elt == vt:
                    assert sc == esize(elt) and off == 0, (name, op, 'whole element', v)
                else:
                    assert kind(elt) == 'st' and sc == esize(elt) and \
                        (off, vt) in field_paths(elt), (name, op, 'R24 field', v)
                if op == 'est' and kids[0]['op'] == 'slit':
                    assert fresh(kids[1], fn['nodes'][:k]), (name, 'R19: a slit into a fresh address')
            elif op == 'anew':
                if kind(t) in ('v', 'm'):
                    assert int(v['r']) == {'v': 1, 'm': 2}[kind(t)] and all(x == 3 for x in kt), \
                        (name, 'anew', v)
                else:
                    assert kind(t) in ('fv', 'fm', 'st') and v['r'] == '0' and v['z'] == '0', \
                        (name, 'anew R1/R21', v)
            elif op == 'adat':
                c = kt[0]
                if kind(c) in ('v', 'm', 'fv', 'fm'):
                    assert tab[t] == ('ptr', tab[c][1]), (name, 'adat', v)
                else:
                    assert kind(c) == 'st' and tab[t] == ('ptr', c), (name, 'adat of a home', v)
            elif op == 'cow':
                c = kids[0]
                if c['op'] == 'lv':
                    assert kind(kt[0]) in ('v', 'm') and not isl[int(c['v']['lid'])], (name, 'cow')
                else:
                    assert c['op'] == 'fld' and kind(kt[0]) in ('v', 'm'), (name, 'R23 cow', c['op'])
                    r = c
                    while r['op'] == 'fld':
                        r = r['kids'][0]
                    assert r['op'] == 'lv', (name, 'R23 root')
            elif op == 'mcpy':
                d, s_, c = kt
                assert kind(d) == 'ptr' and kind(s_) == 'ptr' and c == 3, (name, 'mcpy')
                if holds(tab[d][1]):
                    assert kids[2]['op'] in ('ci', 'lv'), (name, 'R20 count')
            elif op == 'xblk':
                assert t == kt[-1], (name, 'xblk type')
            elif op == 'hloop':
                assert lt[int(v['lid'])] == 3 and kt[:3] == [3, 3, 3], (name, 'hloop')
            elif op == 'idx':
                assert all(x == 3 for x in kt[1:]), (name, 'R10 idx')
        for j, n in enumerate(fn['nodes']):
            if n['op'] == 'lv' and int(n['v']['lid']) in bound:
                assert bound[int(n['v']['lid'])] < j, (name, 'lv before tmp')
    # the .l locals: order and loc records (number_locals wrote them; checked independently)
    fns, cur = [], None
    for ln in rest:
        p = ln.split(' ')
        if p[0] == 'fn':
            cur = {'locs': [], 'decl': []}
            fns.append(cur)
        elif p[0] in ('par', 'loc'):
            cur['locs'].append(p)
        elif p[0] in ('tmp', 'bind', 'hloop'):
            cur['decl'].append((int(p[2]), 'for' if p[0] == 'hloop' else 'let', p[1]))
        elif p[0] == 'rcnt':
            cur['decl'] += [(int(p[3]), 'let', p[1]), (int(p[4]), 'let', p[1])]
        elif p[0] == 'tbind':
            cur['decl'] += [(int(x), 'let', p[1]) for x in p[3:] if x != '-']
    for f in fns:
        names_ = [l[1] for l in f['locs']]
        seen_ = []
        for L, mut, pos in f['decl']:
            if names_[L - 1].startswith('.l') and L not in seen_:
                seen_.append(L)
                loc = f['locs'][L - 1]
                assert loc[3] == mut and loc[4] == pos, (name, 'loc of a .l local', loc, mut, pos)
        assert seen_ == [j + 1 for j, nm in enumerate(names_) if nm.startswith('.l')], \
            (name, '.l order')
    return len(body), nch


def cross_counts4g2(name):
    """Counts the .hirl and the .lir1 agree on (3.6.6 "Lowering of the sea.hirl records", rules
    4, 18, 19, 20, 27): `loop` = hloop + forr + R20 retain loops (an mcpy into counted elements
    with an lv count); `if` + `ifz` = if + ifx + while + cow + those loops; `chkb` = chkb + the
    indices of every idx; `rcall sea_arr_unique` = cow."""
    hl = lines(read(name + '.hirl'))[3:-1]
    lr = lines(read(name + '.lir1'))[3:-1]
    ops = lambda recs, o: sum(1 for r in recs if r.split(' ')[0] == o)
    tab = type_table(read(name + '.hirl'))
    r20 = 0
    nidx = 0
    for fn in hirl_trees(name):
        lt = {k + 1: t for k, (_, t) in enumerate(fn['locs'])}
        for n in fn['nodes']:
            if n['op'] == 'mcpy' and n['kids'][2]['op'] == 'lv':
                d = n['kids'][0]
                dt = int(d['v']['ty'])
                if layout(tab, tab[dt][1])[2]:
                    r20 += 1
            if n['op'] == 'idx':
                nidx += int(n['v']['n'])
    assert ops(lr, 'loop') == ops(hl, 'hloop') + ops(hl, 'forr') + r20, (name, 'loops')
    assert ops(lr, 'if') + ops(lr, 'ifz') == ops(hl, 'if') + ops(hl, 'ifx') + ops(hl, 'while') + \
        ops(hl, 'cow') + r20, (name, 'ifs')
    assert ops(lr, 'chkb') == ops(hl, 'chkb') + nidx, (name, 'chkb')
    assert sum(1 for r in lr if r.startswith('rcall sea_arr_unique ')) == ops(hl, 'cow'), \
        (name, 'cow')


def design_example_k(rule, k):
    """The k-th code block (from 1) of 3.6.6 rule `rule` in DESIGN.md."""
    with open(os.path.join(ROOT, 'docs', 'DESIGN.md')) as fh:
        doc = fh.read().split('\n')
    lo = doc.index('#### 3.6.6 Canonical lowering of scalar code')
    hi = doc.index('#### 3.6.7 Example')
    start = [j for j in range(lo, hi) if re.match(r'^%d\. \*\*' % rule, doc[j])]
    assert len(start) == 1, rule
    j = start[0]
    nxt = [q for q in range(j + 1, hi) if re.match(r'^%d\. \*\*' % (rule + 1), doc[q])][0]
    blocks, cur = [], None
    for q in range(j, nxt):
        if doc[q].strip() == '```':
            if cur is None:
                cur = []
            else:
                blocks.append(cur)
                cur = None
        elif cur is not None:
            cur.append(doc[q].strip())
    return blocks[k - 1]


def check_examples4g2():
    """The agreed examples of rules 18 (its second code block), 27 and 29 verbatim in their
    goldens, each found exactly once."""
    for rule, k, nm in ((18, 2, 'struct_rule18'), (27, 1, 'struct_rule27'),
                        (29, 1, 'struct_rule29')):
        ex = design_example_k(rule, k)
        lir = read(nm + '.lir1').split('\n')
        n = len(ex)
        hits = [j for j in range(len(lir) - n + 1) if lir[j:j + n] == ex]
        assert len(hits) == 1, (nm, 'rule %d example not verbatim' % rule)


def run4g2():
    write_res_struct()
    for nm in RES4G2:
        write_test4g2(nm)
    check_res_rt()
    for nm in NAMES4G2:
        write_test4g2(nm)
    nrec, nch = 0, 0
    for nm in NAMES4G2:
        a, b = check_hirl4g2(nm)
        nrec += a
        nch += b
        nrec += check_lir1(nm)
        cross_counts4g2(nm)
    check_examples4g2()
    return nrec, nch


# ================================================================ run
write_changed_res()
for nm in CONSTS4G + NAMES4G:
    write_test4g(nm)
_nrec, _nch = 0, 0
for nm in NAMES4G:
    _a, _b = check_hirl4g(nm)
    _nrec += _a
    _nch += _b
    _nrec += check_lir1(nm)
    cross_counts4g(nm)
check_examples()
print('dump4g_cases: %d dump tests (%d functions rewritten), %d records checked; agreed examples '
      'verbatim: str_rule15 str_rule26 str_rule30 str_rule32 str_rule33 (rule 35 in str_rule30); '
      'res goldens: %s' % (len(CONSTS4G + NAMES4G), _nch, _nrec, ' '.join(sorted(RES_SEA) +
                                                                          sorted(RES_COMMENT))))
_nrec2, _nch2 = run4g2()
print('dump4g_cases (4g-2): %d dump tests (%d functions rewritten), %d records checked; agreed '
      'examples verbatim: struct_rule18 (rule 18, its second) struct_rule27 struct_rule29; res '
      'goldens: %s res_struct' % (len(NAMES4G2), _nch2, _nrec2, ' '.join(RES4G2)))
