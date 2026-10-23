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

The tests (one array operation per statement, no function called from exactly one call site,
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
def res_gen4g1():
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
