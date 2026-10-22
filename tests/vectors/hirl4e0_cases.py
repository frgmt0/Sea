"""Sub-phase 4e-0 tests of the pass-3a split (DESIGN.md 6.2 "Tests of the pass-3a split", 3.5.9,
Decisions 26-30): the sea.hirl goldens, the input stage.sh gives sealower, and the new loop_* dump
tests.

Run with `timeout 120 uv run --no-project python tests/vectors/hirl4e0_cases.py`. It writes, in
tests/passes/:

* NAME.hirl for the 17 dump tests with a .sea and a .lir1 (6.2): for the 11 tests without a
  construct sealoop rewrites, NAME.hirl is NAME.hir byte for byte (3.5.9 "Unchanged functions": a
  file without them is sea.hir byte for byte; the header records are copied unchanged by every
  pass, 3.2); the script copies the file and asserts the equality. For the 6 tests that use
  zeros, ones, len or a for over a vector (arr_rule16 17 18 19 30 31) every record is written by
  hand below from 3.5.9 (L1-L4, "Types", "Locals", "Positions"); arr_rule30's function walk is
  the worked example of 3.5.9 verbatim.
* the new dump tests loop_fore_exits, loop_fill and loop_ext (.sea .ast .res .hir1 .hir .hirl
  .lir1 .out). Their .hirl is written from 3.5.9 with the helpers below, which spell out the
  shorthand of L2/L4 and loop(N; K) record by record (each call names its position, types and
  the local ids it binds, chosen by hand by the numbering rule of 3.5.4/3.5.9; the self-check
  verifies that numbering independently). Their .lir1 is written by hand, instruction by
  instruction, from the agreed lowering of 3.6.6 (rules 1-17, 30, and "Lowering of the sea.hirl
  records"; the split is LIR-neutral, Decision 26), with the derivation in comments. Their .out
  is derived from LANGUAGE.md (the arithmetic is worked out in the comments). Their .ast, .hir1
  and .hir are the outputs of passes 1, 2a and 2b, which sub-phase 4e-0 does not change (8, row
  4e-0: "Not changed: ... passes 1, 2a, 2b"), reviewed against 3.4 and 3.5 (positions checked
  against the source by check_positions); their .res comes from res_gen.py (the 3.4.1/3.4.2
  oracle, which also cross-checks the lids against the .hir1).

No file is printed by sealoop or sealower. The self-check at the end reads every written .hirl and
.lir1 back and checks it against include/passes.txt (sets H HF HL; L) and the rules of 3.3, 3.5.4
and 3.5.9 ("What the passes validate"), and checks the 11 copies against their .hir.
"""

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import res_gen  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
PASSES = os.path.join(os.path.dirname(HERE), 'passes')
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


# ================================================================ the 11 copies (6.2)
# These tests hold no zeros/ones/filled/len/rows/cols/numel call and no for over a vector, so
# sealoop rewrites nothing: their sea.hirl is their sea.hir byte for byte (3.5.9 "Unchanged
# functions"), the header included (3.2: every later pass copies the header records unchanged).
COPIES = ['fn_multi', 'fn_printf', 'fn_ref', 'fn_ref_order', 'lx', 'math_lower', 'op_shortcircuit',
          'stmt_loops', 'stmt_tasg', 'type_ifx_arm', 'arr_rule36']
for nm in COPIES:
    hir = read(nm + '.hir')
    for ln in hir.split('\n'):
        op = ln.split(' ')[0]
        assert op != 'fore', (nm, ln)
        assert not (op == 'lib' and ln.split(' ')[4] in ('zeros', 'ones', 'filled', 'len', 'rows',
                                                         'cols', 'numel')), (nm, ln)
    write(nm + '.hirl', hir)
    assert read(nm + '.hirl') == read(nm + '.hir'), nm


# ================================================================ helpers for 3.5.9's shorthand
# Each helper returns the records (post-order, 3.3) of one rewrite. P is the position of the node
# the rewrite implements (3.5.9 "Positions": every node sealoop writes takes it; the nodes it
# keeps, the argument subtrees and the fore's body block, keep their own).
ES = {4: 8, 3: 8, 2: 1}     # element size s of 4.8: SEA_ESIZE_F64, SEA_ESIZE_I64, SEA_ESIZE_BOOL


def loop_nk(P, N, Z, O, L, K, S):
    """loop(N; K) { S } (3.5.9): the statements `tmp Z = ci 0` and `if` (e = 0) with the condition
    `bin gt (lv N) (lv Z)` (type 2) and the block { `tmp O = ci 1`; `tmp L = wbin sub (lv N)
    (lv O)`; `hloop K (lv Z) (lv L) (lv O)` with the block { S } }. S is a list of statements, each
    a list of records."""
    out = ['ci %s 3 0' % P, 'tmp %s %d' % (P, Z),
           'lv %s 3 %d' % (P, N), 'lv %s 3 %d' % (P, Z), 'bin %s 2 gt' % P,
           'ci %s 3 1' % P, 'tmp %s %d' % (P, O),
           'lv %s 3 %d' % (P, N), 'lv %s 3 %d' % (P, O), 'wbin %s 3 sub' % P, 'tmp %s %d' % (P, L),
           'lv %s 3 %d' % (P, Z), 'lv %s 3 %d' % (P, L), 'lv %s 3 %d' % (P, O)]
    for s in S:
        out += s
    out += ['block %s %d' % (P, len(S)), 'hloop %s %d' % (P, K), 'block %s 3' % P, 'if %s 0' % P]
    return out


def l1(P, T, k):
    """L1: `lib zeros(r)` / `zeros(r, c)` of type T is `anew P T 1 k`, the arguments its children
    (the caller writes the argument records before it)."""
    return ['anew %s %d 1 %d' % (P, T, k)]


def l2(P, T, E, TP, ids, v=None, r=None, c=None):
    """L2: `ones(...)` (v None) or `filled(v, ...)` of type T (element type E, TP the tptr of E):
    `xblk P T n` with, in order: for filled `tmp V = v`; `tmp R = r`; for a matrix `tmp C = c`;
    `tmp A = anew P T 0 k (lv R [, lv C])`; for a matrix `tmp N = wbin mul (lv R) (lv C)` (a
    vector's N is R); for ones `tmp V =` the constant 1 of E (ones is always f64: cf
    #3FF0000000000000); `tmp D = adat (lv A)`; loop(N; K) { `est P s 0 (lv V) (lv D) (lv K)` };
    value `lv A`. n = 6 for a vector, 8 for a matrix. v, r, c are the argument records."""
    out, n = [], 0
    if v is not None:
        out += v + ['tmp %s %d' % (P, ids['V'])]
        n += 1
    out += r + ['tmp %s %d' % (P, ids['R'])]
    n += 1
    if c is not None:
        out += c + ['tmp %s %d' % (P, ids['C'])]
        n += 1
    out += ['lv %s 3 %d' % (P, ids['R'])]
    if c is not None:
        out += ['lv %s 3 %d' % (P, ids['C'])]
    out += ['anew %s %d 0 %d' % (P, T, 2 if c is not None else 1), 'tmp %s %d' % (P, ids['A'])]
    n += 1
    if c is not None:
        out += ['lv %s 3 %d' % (P, ids['R']), 'lv %s 3 %d' % (P, ids['C']), 'wbin %s 3 mul' % P,
                'tmp %s %d' % (P, ids['N'])]
        n += 1
        N = ids['N']
    else:
        N = ids['R']
    if v is None:
        assert E == 4
        out += ['cf %s 4 #3FF0000000000000' % P, 'tmp %s %d' % (P, ids['V'])]
        n += 1
    out += ['lv %s %d %d' % (P, T, ids['A']), 'adat %s %d' % (P, TP), 'tmp %s %d' % (P, ids['D'])]
    n += 1
    est = ['lv %s %d %d' % (P, E, ids['V']), 'lv %s %d %d' % (P, TP, ids['D']),
           'lv %s 3 %d' % (P, ids['K']), 'est %s %d 0' % (P, ES[E])]
    out += loop_nk(P, N, ids['Z'], ids['O'], ids['L'], ids['K'], [est])
    n += 2
    out += ['lv %s %d %d' % (P, T, ids['A']), 'xblk %s %d %d' % (P, T, n)]
    assert n == (8 if c is not None else 6)
    return out


def l3(P, fn, a, ty, rank, A=None):
    """L3: `len(a)`/`rows(a)` `ext P 3 0`; `cols(a)` `ext P 3 1`; `numel(a)` of a vector
    `ext P 3 0`, of a matrix `xblk P 3 1` { `tmp A = a` } with the value `wbin P 3 mul (ext P 3
    0 (lv A)) (ext P 3 1 (lv A))`. a is the argument's records, ty its type."""
    if fn in ('len', 'rows') or (fn == 'numel' and rank == 1):
        return a + ['ext %s 3 0' % P]
    if fn == 'cols':
        return a + ['ext %s 3 1' % P]
    assert fn == 'numel' and rank == 2
    return a + ['tmp %s %d' % (P, A), 'lv %s %d %d' % (P, ty, A), 'ext %s 3 0' % P,
                'lv %s %d %d' % (P, ty, A), 'ext %s 3 1' % P, 'wbin %s 3 mul' % P,
                'xblk %s 3 1' % P]


def l4(P, VT, E, TP, ids, X, v, body):
    """L4: `fore X v body` is `block P 4` with `bind H = v`; `tmp N = ext P 3 0 (lv H)`; `tmp Z =
    ci 0`; `if` (e = 0) `bin gt (lv N) (lv Z)` with the block { `tmp D = adat (lv H)`; `tmp O = ci
    1`; `tmp L = wbin sub (lv N) (lv O)`; `hloop K (lv Z) (lv L) (lv O)` with the block { `tmp X =
    eld P E s 0 (lv D) (lv K)`; body } }. VT is v's type; v and body (the fore's own block,
    unchanged) are records."""
    H, N, Z, D, O, L, K = (ids[q] for q in 'HNZDOLK')
    return (v + ['bind %s %d' % (P, H),
                 'lv %s %d %d' % (P, VT, H), 'ext %s 3 0' % P, 'tmp %s %d' % (P, N),
                 'ci %s 3 0' % P, 'tmp %s %d' % (P, Z),
                 'lv %s 3 %d' % (P, N), 'lv %s 3 %d' % (P, Z), 'bin %s 2 gt' % P,
                 'lv %s %d %d' % (P, VT, H), 'adat %s %d' % (P, TP), 'tmp %s %d' % (P, D),
                 'ci %s 3 1' % P, 'tmp %s %d' % (P, O),
                 'lv %s 3 %d' % (P, N), 'lv %s 3 %d' % (P, O), 'wbin %s 3 sub' % P,
                 'tmp %s %d' % (P, L),
                 'lv %s 3 %d' % (P, Z), 'lv %s 3 %d' % (P, L), 'lv %s 3 %d' % (P, O),
                 'lv %s %d %d' % (P, TP, D), 'lv %s 3 %d' % (P, K),
                 'eld %s %d %d 0' % (P, E, ES[E]), 'tmp %s %d' % (P, X)]
            + body + ['block %s 2' % P, 'hloop %s %d' % (P, K), 'block %s 4' % P, 'if %s 0' % P,
                      'block %s 4' % P])


def locs(first, specs):
    """The loc records of the .l locals .l<first>, ... (3.5.9 "Locals"): specs are (type, mut,
    pos) in the order of their declaring records."""
    return ['loc .l%d %d %s %s' % (first + j, t, m, p) for j, (t, m, p) in enumerate(specs)]


def fill_locs(P, T, E, TP, kind, mat):
    """The loc specs of one L2 rewrite, in the order of its declaring records: filled: V R [C] A
    [N] D Z O L K; ones: R [C] A [N] V D Z O L K (the tmp records in L2's order, the hloop's K
    last)."""
    sp = []
    if kind == 'filled':
        sp.append((E, 'let', P))
    sp.append((3, 'let', P))
    if mat:
        sp.append((3, 'let', P))
    sp.append((T, 'let', P))
    if mat:
        sp.append((3, 'let', P))
    if kind == 'ones':
        sp.append((4, 'let', P))
    sp += [(TP, 'let', P), (3, 'let', P), (3, 'let', P), (3, 'let', P), (3, 'for', P)]
    return sp


def fill_ids(first, kind, mat):
    """The local ids of one L2 rewrite, from `first`, in the order of fill_locs."""
    names = (['V'] if kind == 'filled' else []) + ['R'] + (['C'] if mat else []) + ['A'] + \
        (['N'] if mat else []) + (['V'] if kind == 'ones' else []) + ['D', 'Z', 'O', 'L', 'K']
    return {q: first + j for j, q in enumerate(names)}


def fore_locs(P, VT, TP):
    """The loc specs of one L4 rewrite: H N Z D O L (let) and K (for)."""
    return [(VT, 'let', P), (3, 'let', P), (3, 'let', P), (TP, 'let', P), (3, 'let', P),
            (3, 'let', P), (3, 'for', P)]


def fore_ids(first):
    return {q: first + j for j, q in enumerate('HNZDOLK')}

# ================================================================ the 6 rewritten arr_rule tests
# Every record by hand from 3.5.9. Records sealoop keeps are those of the .hir unchanged.
HIRL = {}
# arr_rule16: line 4 `let v = zeros(n)`: L1, `lib 0:4:17 10 zeros 1` becomes `anew 0:4:17 10 1 1`
# (z 1: a cleared buffer; r 1; its child `lv n` kept). No adat, so no tptr; no new local.
HIRL['arr_rule16'] = '''
tvec 10 4
fn 1 .main main 1 0 0 0:1:1
ci 0:10:18 3 5
call 0:10:16 3 2 1
fconv 0:10:8 1 - - - d
ftext 0:10:8 1 %0A
fmt 0:10:8 1 2
lib 0:10:1 1 printf 1
eval 0:10:1
ci 0:11:18 3 2
call 0:11:16 3 2 1
fconv 0:11:8 1 - - - d
ftext 0:11:8 1 %0A
fmt 0:11:8 1 2
lib 0:11:1 1 printf 1
eval 0:11:1
block 0:1:1 2
end
fn 2 f fn 3 1 2 0:1:1
par n 3 val
loc k 3 var 0:2:9
loc v 10 let 0:4:13
ci 0:2:13 3 0
bind 0:2:5 2
lv 0:3:11 3 2
lv 0:3:15 3 1
bin 0:3:11 2 lt
lv 0:4:23 3 1
anew 0:4:17 10 1 1
bind 0:4:9 3
lv 0:5:12 3 2
ci 0:5:17 3 3
bin 0:5:12 2 eq
break 0:5:21
block 0:5:19 1
if 0:5:9 0
lv 0:6:9 3 2
ci 0:6:14 3 1
asg 0:6:9 add
block 0:3:17 3
while 0:3:5
lv 0:8:12 3 2
ret 0:8:5 1
block 0:1:21 3
end
'''
# arr_rule18: line 1 `var A = zeros(2, 3)`: L1, `lib 0:1:9 10 zeros 2` becomes `anew 0:1:9 10 1 2`
# (rank 2, its two ci children kept). Nothing else is rewritten (idx and dol are 4e's).
HIRL['arr_rule18'] = '''
tmat 10 4
fn 1 .main main 1 0 1 0:1:1
loc A 10 var 0:1:5
ci 0:1:15 3 2
ci 0:1:18 3 3
anew 0:1:9 10 1 2
bind 0:1:1 1
lv 0:2:1 10 1
ci 0:2:3 3 1
ci 0:2:6 3 2
idx 0:2:1 4 2
cf 0:2:11 4 #4014000000000000
asg 0:2:1 set
lv 0:3:18 10 1
ci 0:3:21 3 2
ci 0:3:24 3 2
call 0:3:16 4 2 3
fconv 0:3:8 1 - - - g
ftext 0:3:8 1 %0A
fmt 0:3:8 1 2
lib 0:3:1 1 printf 1
eval 0:3:1
lv 0:4:18 10 1
ci 0:4:21 3 0
ci 0:4:24 3 1
call 0:4:16 4 2 3
fconv 0:4:8 1 - - - g
ftext 0:4:8 1 %0A
fmt 0:4:8 1 2
lib 0:4:1 1 printf 1
eval 0:4:1
lv 0:5:16 10 1
dol 0:5:18 3 0
ci 0:5:22 3 1
bin 0:5:18 3 sub
dol 0:5:25 3 1
ci 0:5:29 3 1
bin 0:5:25 3 sub
idx 0:5:16 4 2
fconv 0:5:8 1 - - - g
ftext 0:5:8 1 %0A
fmt 0:5:8 1 2
lib 0:5:1 1 printf 1
eval 0:5:1
block 0:1:1 5
end
fn 2 g fn 4 3 1 0:6:1
par T 10 val
par i 3 val
par j 3 val
loc r 4 var 0:7:9
lv 0:7:13 10 1
lv 0:7:15 3 3
ci 0:7:17 3 1
bin 0:7:15 3 sub
lv 0:7:20 3 2
idx 0:7:13 4 2
bind 0:7:5 4
lv 0:8:11 4 4
cf 0:8:15 4 #0000000000000000
bin 0:8:11 2 lt
lv 0:9:9 4 4
cf 0:9:13 4 #0000000000000000
asg 0:9:9 set
block 0:8:19 1
while 0:8:5
lv 0:11:12 4 4
ret 0:11:5 1
block 0:6:40 3
end
'''
# arr_rule19: line 6 in mk `var A = zeros(2, 2)`: L1, `anew 0:6:13 10 1 2`. The element store
# and the forr stay (rule 19 is sealower's in 4e-0).
HIRL['arr_rule19'] = '''
tmat 10 4
tvec 11 3
fn 1 .main main 1 0 5 0:1:1
loc T 10 var 0:1:5
loc j 3 var 0:2:5
loc i 3 var 0:3:5
loc tn 4 let 0:4:5
loc U 10 let 0:14:5
call 0:1:9 10 2 0
bind 0:1:1 1
ci 0:2:9 3 1
bind 0:2:1 2
ci 0:3:9 3 0
bind 0:3:1 3
cf 0:4:10 4 #4004000000000000
bind 0:4:1 4
lv 0:12:1 10 1
lv 0:12:3 3 2
lv 0:12:6 3 3
idx 0:12:1 4 2
lv 0:12:11 4 4
asg 0:12:1 set
lv 0:13:16 10 1
ci 0:13:18 3 1
ci 0:13:21 3 0
idx 0:13:16 4 2
fconv 0:13:8 1 - - - g
ftext 0:13:8 1 %0A
fmt 0:13:8 1 2
lib 0:13:1 1 printf 1
eval 0:13:1
call 0:14:9 10 2 0
bind 0:14:1 5
lv 0:15:16 10 5
ci 0:15:18 3 1
ci 0:15:21 3 0
idx 0:15:16 4 2
fconv 0:15:8 1 - - - g
ftext 0:15:8 1 %0A
fmt 0:15:8 1 2
lib 0:15:1 1 printf 1
eval 0:15:1
block 0:1:1 8
end
fn 2 mk fn 10 0 2 0:5:1
loc A 10 var 0:6:9
loc k 3 for 0:7:9
ci 0:6:19 3 2
ci 0:6:22 3 2
anew 0:6:13 10 1 2
bind 0:6:5 1
ci 0:7:14 3 0
ci 0:7:17 3 2
rng 0:7:14 11 0 0
lv 0:8:9 10 1
lv 0:8:11 3 2
lv 0:8:14 3 2
idx 0:8:9 4 2
cf 0:8:19 4 #3FF0000000000000
asg 0:8:9 set
block 0:7:19 1
forr 0:7:5 2
lv 0:10:12 10 1
ret 0:10:5 1
block 0:5:19 3
end
'''
# arr_rule31: line 11 in mkv `var a = zeros(2)`: L1, `anew 0:11:13 10 1 1`; `lib f64` is not
# rewritten.
HIRL['arr_rule31'] = '''
tvec 10 4
tvec 11 3
fn 1 .main main 1 0 3 0:1:1
loc v 10 var 0:1:5
loc i 3 var 0:2:5
loc w 10 let 0:8:5
call 0:1:9 10 2 0
bind 0:1:1 1
ci 0:2:9 3 1
bind 0:2:1 2
lv 0:4:7 10 1
lv 0:4:9 3 2
idx 0:4:7 4 1
rarg 0:4:3 4
call 0:4:1 1 3 1
eval 0:4:1
lv 0:5:7 10 1
ci 0:5:9 3 0
idx 0:5:7 4 1
rarg 0:5:3 4
call 0:5:1 1 3 1
eval 0:5:1
lv 0:6:16 10 1
ci 0:6:18 3 0
idx 0:6:16 4 1
fconv 0:6:8 1 - - - g
ftext 0:6:8 1 %0A
fmt 0:6:8 1 2
lib 0:6:1 1 printf 1
eval 0:6:1
lv 0:7:16 10 1
ci 0:7:18 3 1
idx 0:7:16 4 1
fconv 0:7:8 1 - - - g
ftext 0:7:8 1 %0A
fmt 0:7:8 1 2
lib 0:7:1 1 printf 1
eval 0:7:1
call 0:8:9 10 2 0
bind 0:8:1 3
lv 0:9:16 10 3
ci 0:9:18 3 1
idx 0:9:16 4 1
fconv 0:9:8 1 - - - g
ftext 0:9:8 1 %0A
fmt 0:9:8 1 2
lib 0:9:1 1 printf 1
eval 0:9:1
block 0:1:1 8
end
fn 2 mkv fn 10 0 2 0:10:1
loc a 10 var 0:11:9
loc k 3 for 0:12:9
ci 0:11:19 3 2
anew 0:11:13 10 1 1
bind 0:11:5 1
ci 0:12:14 3 0
ci 0:12:17 3 2
rng 0:12:14 11 0 0
lv 0:13:9 10 1
lv 0:13:11 3 2
idx 0:13:9 4 1
lv 0:13:20 3 2
lib 0:13:16 4 f64 1
cf 0:13:25 4 #3FE0000000000000
bin 0:13:16 4 add
asg 0:13:9 set
block 0:12:19 1
forr 0:12:5 2
lv 0:15:12 10 1
ret 0:15:5 1
block 0:10:19 3
end
fn 3 f fn 1 1 1 0:17:1
par x 4 ref
loc k 3 for 0:18:9
ci 0:18:14 3 0
ci 0:18:17 3 2
rng 0:18:14 11 0 0
lv 0:19:9 4 1
cf 0:19:14 4 #3FF0000000000000
asg 0:19:9 add
block 0:18:19 1
forr 0:18:5 2
block 0:17:18 1
end
'''

# arr_rule17: line 1 `let n = 3; let u = ones(n)`, the lib at P = 0:1:20 (type 10 f64[], E 4).
# L2 for a vector: tmp R = r (`lv 0:1:25 3 1`, n, kept); tmp A = anew P 10 0 1 (lv R); tmp V = cf
# 1.0 (ones); tmp D = adat (lv A); loop(R; K) { est P 8 0 (lv V) (lv D) (lv K) }; value lv A; n 6.
# Types: tvec 10 4, then tptr 11 4 (the first and only element type whose address is taken).
# Locals: n 1, u 2, then the .l locals in the order of their declaring records (3.5.9): .l1 R (3),
# .l2 A (4, type 10), .l3 V (5, type 4), .l4 D (6, type 11), .l5 Z (7), .l6 O (8), .l7 L (9), all
# mut let, and .l8 K (10, mut for, the hloop's), all at 0:1:20; nl 2 + 8 = 10.
# Line 2 `len(u)` (0:2:25): L3, `ext 0:2:25 3 0` of `lv 0:2:29 10 2`.
HIRL['arr_rule17'] = '''
tvec 10 4
tptr 11 4
fn 1 .main main 1 0 10 0:1:1
loc n 3 let 0:1:5
loc u 10 let 0:1:16
loc .l1 3 let 0:1:20
loc .l2 10 let 0:1:20
loc .l3 4 let 0:1:20
loc .l4 11 let 0:1:20
loc .l5 3 let 0:1:20
loc .l6 3 let 0:1:20
loc .l7 3 let 0:1:20
loc .l8 3 for 0:1:20
ci 0:1:9 3 3
bind 0:1:1 1
lv 0:1:25 3 1
tmp 0:1:20 3
lv 0:1:20 3 3
anew 0:1:20 10 0 1
tmp 0:1:20 4
cf 0:1:20 4 #3FF0000000000000
tmp 0:1:20 5
lv 0:1:20 10 4
adat 0:1:20 11
tmp 0:1:20 6
ci 0:1:20 3 0
tmp 0:1:20 7
lv 0:1:20 3 3
lv 0:1:20 3 7
bin 0:1:20 2 gt
ci 0:1:20 3 1
tmp 0:1:20 8
lv 0:1:20 3 3
lv 0:1:20 3 8
wbin 0:1:20 3 sub
tmp 0:1:20 9
lv 0:1:20 3 7
lv 0:1:20 3 9
lv 0:1:20 3 8
lv 0:1:20 4 5
lv 0:1:20 11 6
lv 0:1:20 3 10
est 0:1:20 8 0
block 0:1:20 1
hloop 0:1:20 10
block 0:1:20 3
if 0:1:20 0
lv 0:1:20 10 4
xblk 0:1:20 10 6
bind 0:1:12 2
lv 0:2:19 10 2
ci 0:2:21 3 2
idx 0:2:19 4 1
fconv 0:2:8 1 - - - g
ftext 0:2:8 1 %20
lv 0:2:29 10 2
ext 0:2:25 3 0
fconv 0:2:8 1 - - - d
ftext 0:2:8 1 %0A
fmt 0:2:8 1 4
lib 0:2:1 1 printf 1
eval 0:2:1
block 0:1:1 3
end
'''

# arr_rule30. .main: line 7 `walk(ones(3))`, the ones at P = 0:7:6: L2 as in arr_rule17 with r the
# constant `ci 0:7:11 3 3` (kept); .main has no locals of its own, so .l1 R (1), .l2 A (2), .l3 V
# (3), .l4 D (4, type 11), .l5 Z (5), .l6 O (6), .l7 L (7), .l8 K (8, for); nl 8. tptr 11 4 is
# first referenced here (`loc .l4 11`). Line 8 `walk(zeros(0))`: L1, `anew 0:8:6 10 1 1`.
# walk: the worked example of 3.5.9 verbatim (the fore at 0:3:5: v 1, x 2, .l1 H ... .l7 K 3 ... 9),
# then line 5 `len(v)` (0:5:27): L3, `ext 0:5:27 3 0`; the body block 0:2:19 as in sea.hir.
HIRL['arr_rule30'] = '''
tvec 10 4
tptr 11 4
fn 1 .main main 1 0 8 0:1:1
loc .l1 3 let 0:7:6
loc .l2 10 let 0:7:6
loc .l3 4 let 0:7:6
loc .l4 11 let 0:7:6
loc .l5 3 let 0:7:6
loc .l6 3 let 0:7:6
loc .l7 3 let 0:7:6
loc .l8 3 for 0:7:6
ci 0:7:11 3 3
tmp 0:7:6 1
lv 0:7:6 3 1
anew 0:7:6 10 0 1
tmp 0:7:6 2
cf 0:7:6 4 #3FF0000000000000
tmp 0:7:6 3
lv 0:7:6 10 2
adat 0:7:6 11
tmp 0:7:6 4
ci 0:7:6 3 0
tmp 0:7:6 5
lv 0:7:6 3 1
lv 0:7:6 3 5
bin 0:7:6 2 gt
ci 0:7:6 3 1
tmp 0:7:6 6
lv 0:7:6 3 1
lv 0:7:6 3 6
wbin 0:7:6 3 sub
tmp 0:7:6 7
lv 0:7:6 3 5
lv 0:7:6 3 7
lv 0:7:6 3 6
lv 0:7:6 4 3
lv 0:7:6 11 4
lv 0:7:6 3 8
est 0:7:6 8 0
block 0:7:6 1
hloop 0:7:6 8
block 0:7:6 3
if 0:7:6 0
lv 0:7:6 10 2
xblk 0:7:6 10 6
call 0:7:1 1 2 1
eval 0:7:1
ci 0:8:12 3 0
anew 0:8:6 10 1 1
call 0:8:1 1 2 1
eval 0:8:1
block 0:1:1 2
end
fn 2 walk fn 1 1 8 0:2:1
par v 10 val
loc x 4 for 0:3:9
loc .l1 10 let 0:3:5
loc .l2 3 let 0:3:5
loc .l3 3 let 0:3:5
loc .l4 11 let 0:3:5
loc .l5 3 let 0:3:5
loc .l6 3 let 0:3:5
loc .l7 3 for 0:3:5
lv 0:3:14 10 1
bind 0:3:5 3
lv 0:3:5 10 3
ext 0:3:5 3 0
tmp 0:3:5 4
ci 0:3:5 3 0
tmp 0:3:5 5
lv 0:3:5 3 4
lv 0:3:5 3 5
bin 0:3:5 2 gt
lv 0:3:5 10 3
adat 0:3:5 11
tmp 0:3:5 6
ci 0:3:5 3 1
tmp 0:3:5 7
lv 0:3:5 3 4
lv 0:3:5 3 7
wbin 0:3:5 3 sub
tmp 0:3:5 8
lv 0:3:5 3 5
lv 0:3:5 3 8
lv 0:3:5 3 7
lv 0:3:5 11 6
lv 0:3:5 3 9
eld 0:3:5 4 8 0
tmp 0:3:5 2
block 0:3:16 0
block 0:3:5 2
hloop 0:3:5 9
block 0:3:5 4
if 0:3:5 0
block 0:3:5 4
ftext 0:5:12 1 walked%20
lv 0:5:31 10 1
ext 0:5:27 3 0
fconv 0:5:12 1 - - - d
ftext 0:5:12 1 %0A
fmt 0:5:12 1 3
lib 0:5:5 1 printf 1
eval 0:5:5
block 0:2:19 2
end
'''

# The worked example of 3.5.9, as the spec prints it (from `fn 2 walk` through the L4 block): it
# must appear verbatim in arr_rule30.hirl.
EXAMPLE_3_5_9 = '''fn 2 walk fn 1 1 8 0:2:1
par v 10 val
loc x 4 for 0:3:9
loc .l1 10 let 0:3:5
loc .l2 3 let 0:3:5
loc .l3 3 let 0:3:5
loc .l4 11 let 0:3:5
loc .l5 3 let 0:3:5
loc .l6 3 let 0:3:5
loc .l7 3 for 0:3:5
lv 0:3:14 10 1
bind 0:3:5 3
lv 0:3:5 10 3
ext 0:3:5 3 0
tmp 0:3:5 4
ci 0:3:5 3 0
tmp 0:3:5 5
lv 0:3:5 3 4
lv 0:3:5 3 5
bin 0:3:5 2 gt
lv 0:3:5 10 3
adat 0:3:5 11
tmp 0:3:5 6
ci 0:3:5 3 1
tmp 0:3:5 7
lv 0:3:5 3 4
lv 0:3:5 3 7
wbin 0:3:5 3 sub
tmp 0:3:5 8
lv 0:3:5 3 5
lv 0:3:5 3 8
lv 0:3:5 3 7
lv 0:3:5 11 6
lv 0:3:5 3 9
eld 0:3:5 4 8 0
tmp 0:3:5 2
block 0:3:16 0
block 0:3:5 2
hloop 0:3:5 9
block 0:3:5 4
if 0:3:5 0
block 0:3:5 4
'''


def check_example():
    """The worked example is in arr_rule30.hirl verbatim, and DESIGN.md prints exactly it."""
    assert EXAMPLE_3_5_9 in read('arr_rule30.hirl')
    with open(os.path.join(ROOT, 'docs', 'DESIGN.md')) as fh:
        design = fh.read()
    assert '```\n' + EXAMPLE_3_5_9 + '```' in design, 'the 3.5.9 example in DESIGN.md changed'
    # the helpers spell L2 and L4 the same way as the hand-written records above
    walk_l4 = l4('0:3:5', 10, 4, 11, fore_ids(3), 2, ['lv 0:3:14 10 1'], ['block 0:3:16 0'])
    assert '\n'.join(walk_l4) + '\n' in EXAMPLE_3_5_9
    ones17 = l2('0:1:20', 10, 4, 11, fill_ids(3, 'ones', False), r=['lv 0:1:25 3 1'])
    assert '\n'.join(ones17) + '\n' in HIRL['arr_rule17']
    assert locs(1, fill_locs('0:1:20', 10, 4, 11, 'ones', False)) == \
        [ln for ln in HIRL['arr_rule17'].split('\n') if ln.startswith('loc .l')]


for nm in sorted(HIRL):
    write(nm + '.hirl', dump(nm, HIRL[nm]))
check_example()

# ======================================================== new dump tests: sources, pass 1-2b dumps
# The programs (6.2: loop_fore_exits, loop_fill, loop_ext). Every function has a loop and two call
# sites, so LANGUAGE.md 8.6 requires no inlining (3.6.6 "Inlining is deferred"), and each
# statement holds at most one loop nest except where 6.2 asks for a for over ones(3) (3.6.6
# "Phase-4 dump tests"). Their .ast/.hir1/.hir bodies are those of the unchanged passes 1, 2a and
# 2b (see the module docstring); .hir differs from .hir1 only by the folded negative literals of
# 3.5.7 (`-1.0`, `-1`, `-7`).
SEA, AST, HIR1, HIR = {}, {}, {}, {}
SEA['loop_fore_exits'] = '''\
fn where_is(v: f64[], t: f64) -> i64 {
    var i = 0
    for x in v {
        if x == t { return i }
        i += 1
    }
    return -1
}
fn sumto(ref v: f64[], cap: f64) -> f64 {
    var s = 0.0
    for x in v {
        if x < 0.0 { continue }
        if x > cap { break }
        s += x
    }
    return s
}
fn pairs(a: f64[], b: f64[]) -> i64 {
    var c = 0
    for x in a {
        for y in b {
            if x < y { c += 1 }
        }
    }
    return c
}
var a = filled(2.0, 4)
a[1] = -1.0
a[2] = 9.0
let b = zeros(2)
printf("%d %d\\n", where_is(a, 9.0), where_is(b, 1.0))
printf("%g %g\\n", sumto(ref a, 5.0), sumto(ref a, 10.0))
printf("%d %d\\n", pairs(a, a), pairs(b, a))
var n = 0.0
for x in ones(3) {
    n += x
}
let c = len(a) > 3
for x in if c { b } else { a } {
    n += x + 1.0
}
printf("%g\\n", n)
// loop_fore_exits -- DESIGN.md 3.5.9 L4 (a for over a vector made explicit by sealoop): return,
// continue and break inside element loops, nested element loops, a for over an owned vector
// (ones(3)), over a ref parameter of array type and over an if expression of two vectors
'''
AST['loop_fore_exits'] = '''
type 0:1:16 f64 v 0
param 0:1:13 v 0 0
type 0:1:26 f64 s 0
param 0:1:23 t 0 0
type 0:1:34 i64 s 0
pname 0:2:9 i
int 0:2:13 0
var 0:2:5 0
name 0:3:14 v
name 0:4:12 x
name 0:4:17 t
bin 0:4:12 eq
name 0:4:28 i
return 0:4:21 1
block 0:4:19 1
if 0:4:9 0
name 0:5:9 i
int 0:5:14 1
asg 0:5:9 add
block 0:3:16 2
for 0:3:5 x 0:3:9
int 0:7:13 1
neg 0:7:12
return 0:7:5 1
block 0:1:38 3
fn 0:1:1 where_is 0 2 1
type 0:9:17 f64 v 0
param 0:9:10 v 1 0
type 0:9:29 f64 s 0
param 0:9:24 cap 0 0
type 0:9:37 f64 s 0
pname 0:10:9 s
float 0:10:13 #0000000000000000
var 0:10:5 0
name 0:11:14 v
name 0:12:12 x
float 0:12:16 #0000000000000000
bin 0:12:12 lt
continue 0:12:22
block 0:12:20 1
if 0:12:9 0
name 0:13:12 x
name 0:13:16 cap
bin 0:13:12 gt
break 0:13:22
block 0:13:20 1
if 0:13:9 0
name 0:14:9 s
name 0:14:14 x
asg 0:14:9 add
block 0:11:16 3
for 0:11:5 x 0:11:9
name 0:16:12 s
return 0:16:5 1
block 0:9:41 3
fn 0:9:1 sumto 0 2 1
type 0:18:13 f64 v 0
param 0:18:10 a 0 0
type 0:18:23 f64 v 0
param 0:18:20 b 0 0
type 0:18:33 i64 s 0
pname 0:19:9 c
int 0:19:13 0
var 0:19:5 0
name 0:20:14 a
name 0:21:18 b
name 0:22:16 x
name 0:22:20 y
bin 0:22:16 lt
name 0:22:24 c
int 0:22:29 1
asg 0:22:24 add
block 0:22:22 1
if 0:22:13 0
block 0:21:20 1
for 0:21:9 y 0:21:13
block 0:20:16 1
for 0:20:5 x 0:20:9
name 0:25:12 c
return 0:25:5 1
block 0:18:37 3
fn 0:18:1 pairs 0 2 1
pname 0:27:5 a
name 0:27:9 filled
float 0:27:16 #4000000000000000
int 0:27:21 4
call 0:27:9 2
var 0:27:1 0
name 0:28:1 a
int 0:28:3 1
index 0:28:1 1
float 0:28:9 #3FF0000000000000
neg 0:28:8
asg 0:28:1 set
name 0:29:1 a
int 0:29:3 2
index 0:29:1 1
float 0:29:8 #4022000000000000
asg 0:29:1 set
pname 0:30:5 b
name 0:30:9 zeros
int 0:30:15 2
call 0:30:9 1
let 0:30:1 0
name 0:31:1 printf
str 0:31:8 %25d%20%25d%0A
name 0:31:19 where_is
name 0:31:28 a
float 0:31:31 #4022000000000000
call 0:31:19 2
name 0:31:37 where_is
name 0:31:46 b
float 0:31:49 #3FF0000000000000
call 0:31:37 2
call 0:31:1 3
cstmt 0:31:1
name 0:32:1 printf
str 0:32:8 %25g%20%25g%0A
name 0:32:19 sumto
name 0:32:29 a
ref 0:32:25
float 0:32:32 #4014000000000000
call 0:32:19 2
name 0:32:38 sumto
name 0:32:48 a
ref 0:32:44
float 0:32:51 #4024000000000000
call 0:32:38 2
call 0:32:1 3
cstmt 0:32:1
name 0:33:1 printf
str 0:33:8 %25d%20%25d%0A
name 0:33:19 pairs
name 0:33:25 a
name 0:33:28 a
call 0:33:19 2
name 0:33:32 pairs
name 0:33:38 b
name 0:33:41 a
call 0:33:32 2
call 0:33:1 3
cstmt 0:33:1
pname 0:34:5 n
float 0:34:9 #0000000000000000
var 0:34:1 0
name 0:35:10 ones
int 0:35:15 3
call 0:35:10 1
name 0:36:5 n
name 0:36:10 x
asg 0:36:5 add
block 0:35:18 1
for 0:35:1 x 0:35:5
pname 0:38:5 c
name 0:38:9 len
name 0:38:13 a
call 0:38:9 1
int 0:38:18 3
bin 0:38:9 gt
let 0:38:1 0
name 0:39:13 c
name 0:39:17 b
name 0:39:28 a
ifx 0:39:10
name 0:40:5 n
name 0:40:10 x
float 0:40:14 #3FF0000000000000
bin 0:40:10 add
asg 0:40:5 add
block 0:39:32 1
for 0:39:1 x 0:39:5
name 0:42:1 printf
str 0:42:8 %25g%0A
name 0:42:16 n
call 0:42:1 2
cstmt 0:42:1
prog 15
'''
HIR1['loop_fore_exits'] = '''
tvec 10 4
fn 1 .main main 1 0 6 0:1:1
loc a 10 var 0:27:5
loc b 10 let 0:30:5
loc n 4 var 0:34:5
loc x 4 for 0:35:5
loc c 2 let 0:38:5
loc x 4 for 0:39:5
cf 0:27:16 4 #4000000000000000
ci 0:27:21 3 4
lib 0:27:9 10 filled 2
bind 0:27:1 1
lv 0:28:1 10 1
ci 0:28:3 3 1
idx 0:28:1 4 1
cf 0:28:9 4 #3FF0000000000000
un 0:28:8 4 neg
asg 0:28:1 set
lv 0:29:1 10 1
ci 0:29:3 3 2
idx 0:29:1 4 1
cf 0:29:8 4 #4022000000000000
asg 0:29:1 set
ci 0:30:15 3 2
lib 0:30:9 10 zeros 1
bind 0:30:1 2
lv 0:31:28 10 1
cf 0:31:31 4 #4022000000000000
call 0:31:19 3 2 2
fconv 0:31:8 1 - - - d
ftext 0:31:8 1 %20
lv 0:31:46 10 2
cf 0:31:49 4 #3FF0000000000000
call 0:31:37 3 2 2
fconv 0:31:8 1 - - - d
ftext 0:31:8 1 %0A
fmt 0:31:8 1 4
lib 0:31:1 1 printf 1
eval 0:31:1
lv 0:32:29 10 1
rarg 0:32:25 10
cf 0:32:32 4 #4014000000000000
call 0:32:19 4 3 2
fconv 0:32:8 1 - - - g
ftext 0:32:8 1 %20
lv 0:32:48 10 1
rarg 0:32:44 10
cf 0:32:51 4 #4024000000000000
call 0:32:38 4 3 2
fconv 0:32:8 1 - - - g
ftext 0:32:8 1 %0A
fmt 0:32:8 1 4
lib 0:32:1 1 printf 1
eval 0:32:1
lv 0:33:25 10 1
lv 0:33:28 10 1
call 0:33:19 3 4 2
fconv 0:33:8 1 - - - d
ftext 0:33:8 1 %20
lv 0:33:38 10 2
lv 0:33:41 10 1
call 0:33:32 3 4 2
fconv 0:33:8 1 - - - d
ftext 0:33:8 1 %0A
fmt 0:33:8 1 4
lib 0:33:1 1 printf 1
eval 0:33:1
cf 0:34:9 4 #0000000000000000
bind 0:34:1 3
ci 0:35:15 3 3
lib 0:35:10 10 ones 1
lv 0:36:5 4 3
lv 0:36:10 4 4
asg 0:36:5 add
block 0:35:18 1
fore 0:35:1 4
lv 0:38:13 10 1
lib 0:38:9 3 len 1
ci 0:38:18 3 3
bin 0:38:9 2 gt
bind 0:38:1 5
lv 0:39:13 2 5
lv 0:39:17 10 2
lv 0:39:28 10 1
ifx 0:39:10 10
lv 0:40:5 4 3
lv 0:40:10 4 6
cf 0:40:14 4 #3FF0000000000000
bin 0:40:10 4 add
asg 0:40:5 add
block 0:39:32 1
fore 0:39:1 6
lv 0:42:16 4 3
fconv 0:42:8 1 - - - g
ftext 0:42:8 1 %0A
fmt 0:42:8 1 2
lib 0:42:1 1 printf 1
eval 0:42:1
block 0:1:1 12
end
fn 2 where_is fn 3 2 2 0:1:1
par v 10 val
par t 4 val
loc i 3 var 0:2:9
loc x 4 for 0:3:9
ci 0:2:13 3 0
bind 0:2:5 3
lv 0:3:14 10 1
lv 0:4:12 4 4
lv 0:4:17 4 2
bin 0:4:12 2 eq
lv 0:4:28 3 3
ret 0:4:21 1
block 0:4:19 1
if 0:4:9 0
lv 0:5:9 3 3
ci 0:5:14 3 1
asg 0:5:9 add
block 0:3:16 2
fore 0:3:5 4
ci 0:7:13 3 1
un 0:7:12 3 neg
ret 0:7:5 1
block 0:1:38 3
end
fn 3 sumto fn 4 2 2 0:9:1
par v 10 ref
par cap 4 val
loc s 4 var 0:10:9
loc x 4 for 0:11:9
cf 0:10:13 4 #0000000000000000
bind 0:10:5 3
lv 0:11:14 10 1
lv 0:12:12 4 4
cf 0:12:16 4 #0000000000000000
bin 0:12:12 2 lt
cont 0:12:22
block 0:12:20 1
if 0:12:9 0
lv 0:13:12 4 4
lv 0:13:16 4 2
bin 0:13:12 2 gt
break 0:13:22
block 0:13:20 1
if 0:13:9 0
lv 0:14:9 4 3
lv 0:14:14 4 4
asg 0:14:9 add
block 0:11:16 3
fore 0:11:5 4
lv 0:16:12 4 3
ret 0:16:5 1
block 0:9:41 3
end
fn 4 pairs fn 3 2 3 0:18:1
par a 10 val
par b 10 val
loc c 3 var 0:19:9
loc x 4 for 0:20:9
loc y 4 for 0:21:13
ci 0:19:13 3 0
bind 0:19:5 3
lv 0:20:14 10 1
lv 0:21:18 10 2
lv 0:22:16 4 4
lv 0:22:20 4 5
bin 0:22:16 2 lt
lv 0:22:24 3 3
ci 0:22:29 3 1
asg 0:22:24 add
block 0:22:22 1
if 0:22:13 0
block 0:21:20 1
fore 0:21:9 5
block 0:20:16 1
fore 0:20:5 4
lv 0:25:12 3 3
ret 0:25:5 1
block 0:18:37 3
end
'''
HIR['loop_fore_exits'] = '''
tvec 10 4
fn 1 .main main 1 0 6 0:1:1
loc a 10 var 0:27:5
loc b 10 let 0:30:5
loc n 4 var 0:34:5
loc x 4 for 0:35:5
loc c 2 let 0:38:5
loc x 4 for 0:39:5
cf 0:27:16 4 #4000000000000000
ci 0:27:21 3 4
lib 0:27:9 10 filled 2
bind 0:27:1 1
lv 0:28:1 10 1
ci 0:28:3 3 1
idx 0:28:1 4 1
cf 0:28:8 4 #BFF0000000000000
asg 0:28:1 set
lv 0:29:1 10 1
ci 0:29:3 3 2
idx 0:29:1 4 1
cf 0:29:8 4 #4022000000000000
asg 0:29:1 set
ci 0:30:15 3 2
lib 0:30:9 10 zeros 1
bind 0:30:1 2
lv 0:31:28 10 1
cf 0:31:31 4 #4022000000000000
call 0:31:19 3 2 2
fconv 0:31:8 1 - - - d
ftext 0:31:8 1 %20
lv 0:31:46 10 2
cf 0:31:49 4 #3FF0000000000000
call 0:31:37 3 2 2
fconv 0:31:8 1 - - - d
ftext 0:31:8 1 %0A
fmt 0:31:8 1 4
lib 0:31:1 1 printf 1
eval 0:31:1
lv 0:32:29 10 1
rarg 0:32:25 10
cf 0:32:32 4 #4014000000000000
call 0:32:19 4 3 2
fconv 0:32:8 1 - - - g
ftext 0:32:8 1 %20
lv 0:32:48 10 1
rarg 0:32:44 10
cf 0:32:51 4 #4024000000000000
call 0:32:38 4 3 2
fconv 0:32:8 1 - - - g
ftext 0:32:8 1 %0A
fmt 0:32:8 1 4
lib 0:32:1 1 printf 1
eval 0:32:1
lv 0:33:25 10 1
lv 0:33:28 10 1
call 0:33:19 3 4 2
fconv 0:33:8 1 - - - d
ftext 0:33:8 1 %20
lv 0:33:38 10 2
lv 0:33:41 10 1
call 0:33:32 3 4 2
fconv 0:33:8 1 - - - d
ftext 0:33:8 1 %0A
fmt 0:33:8 1 4
lib 0:33:1 1 printf 1
eval 0:33:1
cf 0:34:9 4 #0000000000000000
bind 0:34:1 3
ci 0:35:15 3 3
lib 0:35:10 10 ones 1
lv 0:36:5 4 3
lv 0:36:10 4 4
asg 0:36:5 add
block 0:35:18 1
fore 0:35:1 4
lv 0:38:13 10 1
lib 0:38:9 3 len 1
ci 0:38:18 3 3
bin 0:38:9 2 gt
bind 0:38:1 5
lv 0:39:13 2 5
lv 0:39:17 10 2
lv 0:39:28 10 1
ifx 0:39:10 10
lv 0:40:5 4 3
lv 0:40:10 4 6
cf 0:40:14 4 #3FF0000000000000
bin 0:40:10 4 add
asg 0:40:5 add
block 0:39:32 1
fore 0:39:1 6
lv 0:42:16 4 3
fconv 0:42:8 1 - - - g
ftext 0:42:8 1 %0A
fmt 0:42:8 1 2
lib 0:42:1 1 printf 1
eval 0:42:1
block 0:1:1 12
end
fn 2 where_is fn 3 2 2 0:1:1
par v 10 val
par t 4 val
loc i 3 var 0:2:9
loc x 4 for 0:3:9
ci 0:2:13 3 0
bind 0:2:5 3
lv 0:3:14 10 1
lv 0:4:12 4 4
lv 0:4:17 4 2
bin 0:4:12 2 eq
lv 0:4:28 3 3
ret 0:4:21 1
block 0:4:19 1
if 0:4:9 0
lv 0:5:9 3 3
ci 0:5:14 3 1
asg 0:5:9 add
block 0:3:16 2
fore 0:3:5 4
ci 0:7:12 3 -1
ret 0:7:5 1
block 0:1:38 3
end
fn 3 sumto fn 4 2 2 0:9:1
par v 10 ref
par cap 4 val
loc s 4 var 0:10:9
loc x 4 for 0:11:9
cf 0:10:13 4 #0000000000000000
bind 0:10:5 3
lv 0:11:14 10 1
lv 0:12:12 4 4
cf 0:12:16 4 #0000000000000000
bin 0:12:12 2 lt
cont 0:12:22
block 0:12:20 1
if 0:12:9 0
lv 0:13:12 4 4
lv 0:13:16 4 2
bin 0:13:12 2 gt
break 0:13:22
block 0:13:20 1
if 0:13:9 0
lv 0:14:9 4 3
lv 0:14:14 4 4
asg 0:14:9 add
block 0:11:16 3
fore 0:11:5 4
lv 0:16:12 4 3
ret 0:16:5 1
block 0:9:41 3
end
fn 4 pairs fn 3 2 3 0:18:1
par a 10 val
par b 10 val
loc c 3 var 0:19:9
loc x 4 for 0:20:9
loc y 4 for 0:21:13
ci 0:19:13 3 0
bind 0:19:5 3
lv 0:20:14 10 1
lv 0:21:18 10 2
lv 0:22:16 4 4
lv 0:22:20 4 5
bin 0:22:16 2 lt
lv 0:22:24 3 3
ci 0:22:29 3 1
asg 0:22:24 add
block 0:22:22 1
if 0:22:13 0
block 0:21:20 1
fore 0:21:9 5
block 0:20:16 1
fore 0:20:5 4
lv 0:25:12 3 3
ret 0:25:5 1
block 0:18:37 3
end
'''
SEA['loop_fill'] = '''\
fn grow(ref k: i64) -> i64 {
    for i in 0..2 {
        k += 1
    }
    return k
}
fn count(ref n: i64) -> f64 {
    let v = filled(0.5, n)
    var s = 0.0
    for x in v {
        s += x
    }
    return s
}
let vf = filled(2.5, 3)
let vi = filled(4, 2)
let vb = filled(true, 2)
printf("%g %d %d %d\\n", vf[2], vi[1], vb[0], len(vb))
let mf = filled(0.25, 2, 3)
let mi = filled(-7, 3, 1)
let mb = filled(false, 1, 2)
printf("%g %d %d\\n", mf[1, 2], mi[2, 0], mb[0, 1])
let mo = ones(2, 2)
let mz = zeros(3, 2)
printf("%g %g %d\\n", mo[1, 1], mz[2, 1], rows(mz))
var m = 4
printf("%g %g\\n", count(ref m), count(ref m))
var k = 1
let vk = filled(k, grow(ref k))
printf("%d %d %d\\n", vk[0], len(vk), k)
let c = k > 2
let vc = ones(if c { 2 } else { 3 })
let p = true
let q = k == 3
let vq = filled(p && q, m)
printf("%g %d %d %d\\n", vc[1], len(vc), vq[3], grow(ref m))
// loop_fill -- DESIGN.md 3.5.9 L1/L2 (zeros, ones, filled made explicit by sealoop): filled of
// f64, i64 and bool vectors and matrices, ones and zeros of a matrix, a count that is a ref
// parameter, filled(k, grow(ref k)) (rule 12 copies k), ones(ifx) and filled(p && q, m) (T1)
'''
AST['loop_fill'] = '''
type 0:1:16 i64 s 0
param 0:1:9 k 1 0
type 0:1:24 i64 s 0
int 0:2:14 0
int 0:2:17 2
range 0:2:14 0 0
name 0:3:9 k
int 0:3:14 1
asg 0:3:9 add
block 0:2:19 1
for 0:2:5 i 0:2:9
name 0:5:12 k
return 0:5:5 1
block 0:1:28 2
fn 0:1:1 grow 0 1 1
type 0:7:17 i64 s 0
param 0:7:10 n 1 0
type 0:7:25 f64 s 0
pname 0:8:9 v
name 0:8:13 filled
float 0:8:20 #3FE0000000000000
name 0:8:25 n
call 0:8:13 2
let 0:8:5 0
pname 0:9:9 s
float 0:9:13 #0000000000000000
var 0:9:5 0
name 0:10:14 v
name 0:11:9 s
name 0:11:14 x
asg 0:11:9 add
block 0:10:16 1
for 0:10:5 x 0:10:9
name 0:13:12 s
return 0:13:5 1
block 0:7:29 4
fn 0:7:1 count 0 1 1
pname 0:15:5 vf
name 0:15:10 filled
float 0:15:17 #4004000000000000
int 0:15:22 3
call 0:15:10 2
let 0:15:1 0
pname 0:16:5 vi
name 0:16:10 filled
int 0:16:17 4
int 0:16:20 2
call 0:16:10 2
let 0:16:1 0
pname 0:17:5 vb
name 0:17:10 filled
true 0:17:17
int 0:17:23 2
call 0:17:10 2
let 0:17:1 0
name 0:18:1 printf
str 0:18:8 %25g%20%25d%20%25d%20%25d%0A
name 0:18:25 vf
int 0:18:28 2
index 0:18:25 1
name 0:18:32 vi
int 0:18:35 1
index 0:18:32 1
name 0:18:39 vb
int 0:18:42 0
index 0:18:39 1
name 0:18:46 len
name 0:18:50 vb
call 0:18:46 1
call 0:18:1 5
cstmt 0:18:1
pname 0:19:5 mf
name 0:19:10 filled
float 0:19:17 #3FD0000000000000
int 0:19:23 2
int 0:19:26 3
call 0:19:10 3
let 0:19:1 0
pname 0:20:5 mi
name 0:20:10 filled
int 0:20:18 7
neg 0:20:17
int 0:20:21 3
int 0:20:24 1
call 0:20:10 3
let 0:20:1 0
pname 0:21:5 mb
name 0:21:10 filled
false 0:21:17
int 0:21:24 1
int 0:21:27 2
call 0:21:10 3
let 0:21:1 0
name 0:22:1 printf
str 0:22:8 %25g%20%25d%20%25d%0A
name 0:22:22 mf
int 0:22:25 1
int 0:22:28 2
index 0:22:22 2
name 0:22:32 mi
int 0:22:35 2
int 0:22:38 0
index 0:22:32 2
name 0:22:42 mb
int 0:22:45 0
int 0:22:48 1
index 0:22:42 2
call 0:22:1 4
cstmt 0:22:1
pname 0:23:5 mo
name 0:23:10 ones
int 0:23:15 2
int 0:23:18 2
call 0:23:10 2
let 0:23:1 0
pname 0:24:5 mz
name 0:24:10 zeros
int 0:24:16 3
int 0:24:19 2
call 0:24:10 2
let 0:24:1 0
name 0:25:1 printf
str 0:25:8 %25g%20%25g%20%25d%0A
name 0:25:22 mo
int 0:25:25 1
int 0:25:28 1
index 0:25:22 2
name 0:25:32 mz
int 0:25:35 2
int 0:25:38 1
index 0:25:32 2
name 0:25:42 rows
name 0:25:47 mz
call 0:25:42 1
call 0:25:1 4
cstmt 0:25:1
pname 0:26:5 m
int 0:26:9 4
var 0:26:1 0
name 0:27:1 printf
str 0:27:8 %25g%20%25g%0A
name 0:27:19 count
name 0:27:29 m
ref 0:27:25
call 0:27:19 1
name 0:27:33 count
name 0:27:43 m
ref 0:27:39
call 0:27:33 1
call 0:27:1 3
cstmt 0:27:1
pname 0:28:5 k
int 0:28:9 1
var 0:28:1 0
pname 0:29:5 vk
name 0:29:10 filled
name 0:29:17 k
name 0:29:20 grow
name 0:29:29 k
ref 0:29:25
call 0:29:20 1
call 0:29:10 2
let 0:29:1 0
name 0:30:1 printf
str 0:30:8 %25d%20%25d%20%25d%0A
name 0:30:22 vk
int 0:30:25 0
index 0:30:22 1
name 0:30:29 len
name 0:30:33 vk
call 0:30:29 1
name 0:30:38 k
call 0:30:1 4
cstmt 0:30:1
pname 0:31:5 c
name 0:31:9 k
int 0:31:13 2
bin 0:31:9 gt
let 0:31:1 0
pname 0:32:5 vc
name 0:32:10 ones
name 0:32:18 c
int 0:32:22 2
int 0:32:33 3
ifx 0:32:15
call 0:32:10 1
let 0:32:1 0
pname 0:33:5 p
true 0:33:9
let 0:33:1 0
pname 0:34:5 q
name 0:34:9 k
int 0:34:14 3
bin 0:34:9 eq
let 0:34:1 0
pname 0:35:5 vq
name 0:35:10 filled
name 0:35:17 p
name 0:35:22 q
bin 0:35:17 and
name 0:35:25 m
call 0:35:10 2
let 0:35:1 0
name 0:36:1 printf
str 0:36:8 %25g%20%25d%20%25d%20%25d%0A
name 0:36:25 vc
int 0:36:28 1
index 0:36:25 1
name 0:36:32 len
name 0:36:36 vc
call 0:36:32 1
name 0:36:41 vq
int 0:36:44 3
index 0:36:41 1
name 0:36:48 grow
name 0:36:57 m
ref 0:36:53
call 0:36:48 1
call 0:36:1 5
cstmt 0:36:1
prog 24
'''
HIR1['loop_fill'] = '''
tvec 10 4
tvec 11 3
tvec 12 2
tmat 13 4
tmat 14 3
tmat 15 2
fn 1 .main main 1 0 16 0:1:1
loc vf 10 let 0:15:5
loc vi 11 let 0:16:5
loc vb 12 let 0:17:5
loc mf 13 let 0:19:5
loc mi 14 let 0:20:5
loc mb 15 let 0:21:5
loc mo 13 let 0:23:5
loc mz 13 let 0:24:5
loc m 3 var 0:26:5
loc k 3 var 0:28:5
loc vk 11 let 0:29:5
loc c 2 let 0:31:5
loc vc 10 let 0:32:5
loc p 2 let 0:33:5
loc q 2 let 0:34:5
loc vq 12 let 0:35:5
cf 0:15:17 4 #4004000000000000
ci 0:15:22 3 3
lib 0:15:10 10 filled 2
bind 0:15:1 1
ci 0:16:17 3 4
ci 0:16:20 3 2
lib 0:16:10 11 filled 2
bind 0:16:1 2
cb 0:17:17 2 1
ci 0:17:23 3 2
lib 0:17:10 12 filled 2
bind 0:17:1 3
lv 0:18:25 10 1
ci 0:18:28 3 2
idx 0:18:25 4 1
fconv 0:18:8 1 - - - g
ftext 0:18:8 1 %20
lv 0:18:32 11 2
ci 0:18:35 3 1
idx 0:18:32 3 1
fconv 0:18:8 1 - - - d
ftext 0:18:8 1 %20
lv 0:18:39 12 3
ci 0:18:42 3 0
idx 0:18:39 2 1
fconv 0:18:8 1 - - - d
ftext 0:18:8 1 %20
lv 0:18:50 12 3
lib 0:18:46 3 len 1
fconv 0:18:8 1 - - - d
ftext 0:18:8 1 %0A
fmt 0:18:8 1 8
lib 0:18:1 1 printf 1
eval 0:18:1
cf 0:19:17 4 #3FD0000000000000
ci 0:19:23 3 2
ci 0:19:26 3 3
lib 0:19:10 13 filled 3
bind 0:19:1 4
ci 0:20:18 3 7
un 0:20:17 3 neg
ci 0:20:21 3 3
ci 0:20:24 3 1
lib 0:20:10 14 filled 3
bind 0:20:1 5
cb 0:21:17 2 0
ci 0:21:24 3 1
ci 0:21:27 3 2
lib 0:21:10 15 filled 3
bind 0:21:1 6
lv 0:22:22 13 4
ci 0:22:25 3 1
ci 0:22:28 3 2
idx 0:22:22 4 2
fconv 0:22:8 1 - - - g
ftext 0:22:8 1 %20
lv 0:22:32 14 5
ci 0:22:35 3 2
ci 0:22:38 3 0
idx 0:22:32 3 2
fconv 0:22:8 1 - - - d
ftext 0:22:8 1 %20
lv 0:22:42 15 6
ci 0:22:45 3 0
ci 0:22:48 3 1
idx 0:22:42 2 2
fconv 0:22:8 1 - - - d
ftext 0:22:8 1 %0A
fmt 0:22:8 1 6
lib 0:22:1 1 printf 1
eval 0:22:1
ci 0:23:15 3 2
ci 0:23:18 3 2
lib 0:23:10 13 ones 2
bind 0:23:1 7
ci 0:24:16 3 3
ci 0:24:19 3 2
lib 0:24:10 13 zeros 2
bind 0:24:1 8
lv 0:25:22 13 7
ci 0:25:25 3 1
ci 0:25:28 3 1
idx 0:25:22 4 2
fconv 0:25:8 1 - - - g
ftext 0:25:8 1 %20
lv 0:25:32 13 8
ci 0:25:35 3 2
ci 0:25:38 3 1
idx 0:25:32 4 2
fconv 0:25:8 1 - - - g
ftext 0:25:8 1 %20
lv 0:25:47 13 8
lib 0:25:42 3 rows 1
fconv 0:25:8 1 - - - d
ftext 0:25:8 1 %0A
fmt 0:25:8 1 6
lib 0:25:1 1 printf 1
eval 0:25:1
ci 0:26:9 3 4
bind 0:26:1 9
lv 0:27:29 3 9
rarg 0:27:25 3
call 0:27:19 4 3 1
fconv 0:27:8 1 - - - g
ftext 0:27:8 1 %20
lv 0:27:43 3 9
rarg 0:27:39 3
call 0:27:33 4 3 1
fconv 0:27:8 1 - - - g
ftext 0:27:8 1 %0A
fmt 0:27:8 1 4
lib 0:27:1 1 printf 1
eval 0:27:1
ci 0:28:9 3 1
bind 0:28:1 10
lv 0:29:17 3 10
lv 0:29:29 3 10
rarg 0:29:25 3
call 0:29:20 3 2 1
lib 0:29:10 11 filled 2
bind 0:29:1 11
lv 0:30:22 11 11
ci 0:30:25 3 0
idx 0:30:22 3 1
fconv 0:30:8 1 - - - d
ftext 0:30:8 1 %20
lv 0:30:33 11 11
lib 0:30:29 3 len 1
fconv 0:30:8 1 - - - d
ftext 0:30:8 1 %20
lv 0:30:38 3 10
fconv 0:30:8 1 - - - d
ftext 0:30:8 1 %0A
fmt 0:30:8 1 6
lib 0:30:1 1 printf 1
eval 0:30:1
lv 0:31:9 3 10
ci 0:31:13 3 2
bin 0:31:9 2 gt
bind 0:31:1 12
lv 0:32:18 2 12
ci 0:32:22 3 2
ci 0:32:33 3 3
ifx 0:32:15 3
lib 0:32:10 10 ones 1
bind 0:32:1 13
cb 0:33:9 2 1
bind 0:33:1 14
lv 0:34:9 3 10
ci 0:34:14 3 3
bin 0:34:9 2 eq
bind 0:34:1 15
lv 0:35:17 2 14
lv 0:35:22 2 15
bin 0:35:17 2 and
lv 0:35:25 3 9
lib 0:35:10 12 filled 2
bind 0:35:1 16
lv 0:36:25 10 13
ci 0:36:28 3 1
idx 0:36:25 4 1
fconv 0:36:8 1 - - - g
ftext 0:36:8 1 %20
lv 0:36:36 10 13
lib 0:36:32 3 len 1
fconv 0:36:8 1 - - - d
ftext 0:36:8 1 %20
lv 0:36:41 12 16
ci 0:36:44 3 3
idx 0:36:41 2 1
fconv 0:36:8 1 - - - d
ftext 0:36:8 1 %20
lv 0:36:57 3 9
rarg 0:36:53 3
call 0:36:48 3 2 1
fconv 0:36:8 1 - - - d
ftext 0:36:8 1 %0A
fmt 0:36:8 1 8
lib 0:36:1 1 printf 1
eval 0:36:1
block 0:1:1 22
end
fn 2 grow fn 3 1 1 0:1:1
par k 3 ref
loc i 3 for 0:2:9
ci 0:2:14 3 0
ci 0:2:17 3 2
rng 0:2:14 11 0 0
lv 0:3:9 3 1
ci 0:3:14 3 1
asg 0:3:9 add
block 0:2:19 1
forr 0:2:5 2
lv 0:5:12 3 1
ret 0:5:5 1
block 0:1:28 2
end
fn 3 count fn 4 1 3 0:7:1
par n 3 ref
loc v 10 let 0:8:9
loc s 4 var 0:9:9
loc x 4 for 0:10:9
cf 0:8:20 4 #3FE0000000000000
lv 0:8:25 3 1
lib 0:8:13 10 filled 2
bind 0:8:5 2
cf 0:9:13 4 #0000000000000000
bind 0:9:5 3
lv 0:10:14 10 2
lv 0:11:9 4 3
lv 0:11:14 4 4
asg 0:11:9 add
block 0:10:16 1
fore 0:10:5 4
lv 0:13:12 4 3
ret 0:13:5 1
block 0:7:29 4
end
'''
HIR['loop_fill'] = '''
tvec 10 4
tvec 11 3
tvec 12 2
tmat 13 4
tmat 14 3
tmat 15 2
fn 1 .main main 1 0 16 0:1:1
loc vf 10 let 0:15:5
loc vi 11 let 0:16:5
loc vb 12 let 0:17:5
loc mf 13 let 0:19:5
loc mi 14 let 0:20:5
loc mb 15 let 0:21:5
loc mo 13 let 0:23:5
loc mz 13 let 0:24:5
loc m 3 var 0:26:5
loc k 3 var 0:28:5
loc vk 11 let 0:29:5
loc c 2 let 0:31:5
loc vc 10 let 0:32:5
loc p 2 let 0:33:5
loc q 2 let 0:34:5
loc vq 12 let 0:35:5
cf 0:15:17 4 #4004000000000000
ci 0:15:22 3 3
lib 0:15:10 10 filled 2
bind 0:15:1 1
ci 0:16:17 3 4
ci 0:16:20 3 2
lib 0:16:10 11 filled 2
bind 0:16:1 2
cb 0:17:17 2 1
ci 0:17:23 3 2
lib 0:17:10 12 filled 2
bind 0:17:1 3
lv 0:18:25 10 1
ci 0:18:28 3 2
idx 0:18:25 4 1
fconv 0:18:8 1 - - - g
ftext 0:18:8 1 %20
lv 0:18:32 11 2
ci 0:18:35 3 1
idx 0:18:32 3 1
fconv 0:18:8 1 - - - d
ftext 0:18:8 1 %20
lv 0:18:39 12 3
ci 0:18:42 3 0
idx 0:18:39 2 1
fconv 0:18:8 1 - - - d
ftext 0:18:8 1 %20
lv 0:18:50 12 3
lib 0:18:46 3 len 1
fconv 0:18:8 1 - - - d
ftext 0:18:8 1 %0A
fmt 0:18:8 1 8
lib 0:18:1 1 printf 1
eval 0:18:1
cf 0:19:17 4 #3FD0000000000000
ci 0:19:23 3 2
ci 0:19:26 3 3
lib 0:19:10 13 filled 3
bind 0:19:1 4
ci 0:20:17 3 -7
ci 0:20:21 3 3
ci 0:20:24 3 1
lib 0:20:10 14 filled 3
bind 0:20:1 5
cb 0:21:17 2 0
ci 0:21:24 3 1
ci 0:21:27 3 2
lib 0:21:10 15 filled 3
bind 0:21:1 6
lv 0:22:22 13 4
ci 0:22:25 3 1
ci 0:22:28 3 2
idx 0:22:22 4 2
fconv 0:22:8 1 - - - g
ftext 0:22:8 1 %20
lv 0:22:32 14 5
ci 0:22:35 3 2
ci 0:22:38 3 0
idx 0:22:32 3 2
fconv 0:22:8 1 - - - d
ftext 0:22:8 1 %20
lv 0:22:42 15 6
ci 0:22:45 3 0
ci 0:22:48 3 1
idx 0:22:42 2 2
fconv 0:22:8 1 - - - d
ftext 0:22:8 1 %0A
fmt 0:22:8 1 6
lib 0:22:1 1 printf 1
eval 0:22:1
ci 0:23:15 3 2
ci 0:23:18 3 2
lib 0:23:10 13 ones 2
bind 0:23:1 7
ci 0:24:16 3 3
ci 0:24:19 3 2
lib 0:24:10 13 zeros 2
bind 0:24:1 8
lv 0:25:22 13 7
ci 0:25:25 3 1
ci 0:25:28 3 1
idx 0:25:22 4 2
fconv 0:25:8 1 - - - g
ftext 0:25:8 1 %20
lv 0:25:32 13 8
ci 0:25:35 3 2
ci 0:25:38 3 1
idx 0:25:32 4 2
fconv 0:25:8 1 - - - g
ftext 0:25:8 1 %20
lv 0:25:47 13 8
lib 0:25:42 3 rows 1
fconv 0:25:8 1 - - - d
ftext 0:25:8 1 %0A
fmt 0:25:8 1 6
lib 0:25:1 1 printf 1
eval 0:25:1
ci 0:26:9 3 4
bind 0:26:1 9
lv 0:27:29 3 9
rarg 0:27:25 3
call 0:27:19 4 3 1
fconv 0:27:8 1 - - - g
ftext 0:27:8 1 %20
lv 0:27:43 3 9
rarg 0:27:39 3
call 0:27:33 4 3 1
fconv 0:27:8 1 - - - g
ftext 0:27:8 1 %0A
fmt 0:27:8 1 4
lib 0:27:1 1 printf 1
eval 0:27:1
ci 0:28:9 3 1
bind 0:28:1 10
lv 0:29:17 3 10
lv 0:29:29 3 10
rarg 0:29:25 3
call 0:29:20 3 2 1
lib 0:29:10 11 filled 2
bind 0:29:1 11
lv 0:30:22 11 11
ci 0:30:25 3 0
idx 0:30:22 3 1
fconv 0:30:8 1 - - - d
ftext 0:30:8 1 %20
lv 0:30:33 11 11
lib 0:30:29 3 len 1
fconv 0:30:8 1 - - - d
ftext 0:30:8 1 %20
lv 0:30:38 3 10
fconv 0:30:8 1 - - - d
ftext 0:30:8 1 %0A
fmt 0:30:8 1 6
lib 0:30:1 1 printf 1
eval 0:30:1
lv 0:31:9 3 10
ci 0:31:13 3 2
bin 0:31:9 2 gt
bind 0:31:1 12
lv 0:32:18 2 12
ci 0:32:22 3 2
ci 0:32:33 3 3
ifx 0:32:15 3
lib 0:32:10 10 ones 1
bind 0:32:1 13
cb 0:33:9 2 1
bind 0:33:1 14
lv 0:34:9 3 10
ci 0:34:14 3 3
bin 0:34:9 2 eq
bind 0:34:1 15
lv 0:35:17 2 14
lv 0:35:22 2 15
bin 0:35:17 2 and
lv 0:35:25 3 9
lib 0:35:10 12 filled 2
bind 0:35:1 16
lv 0:36:25 10 13
ci 0:36:28 3 1
idx 0:36:25 4 1
fconv 0:36:8 1 - - - g
ftext 0:36:8 1 %20
lv 0:36:36 10 13
lib 0:36:32 3 len 1
fconv 0:36:8 1 - - - d
ftext 0:36:8 1 %20
lv 0:36:41 12 16
ci 0:36:44 3 3
idx 0:36:41 2 1
fconv 0:36:8 1 - - - d
ftext 0:36:8 1 %20
lv 0:36:57 3 9
rarg 0:36:53 3
call 0:36:48 3 2 1
fconv 0:36:8 1 - - - d
ftext 0:36:8 1 %0A
fmt 0:36:8 1 8
lib 0:36:1 1 printf 1
eval 0:36:1
block 0:1:1 22
end
fn 2 grow fn 3 1 1 0:1:1
par k 3 ref
loc i 3 for 0:2:9
ci 0:2:14 3 0
ci 0:2:17 3 2
rng 0:2:14 11 0 0
lv 0:3:9 3 1
ci 0:3:14 3 1
asg 0:3:9 add
block 0:2:19 1
forr 0:2:5 2
lv 0:5:12 3 1
ret 0:5:5 1
block 0:1:28 2
end
fn 3 count fn 4 1 3 0:7:1
par n 3 ref
loc v 10 let 0:8:9
loc s 4 var 0:9:9
loc x 4 for 0:10:9
cf 0:8:20 4 #3FE0000000000000
lv 0:8:25 3 1
lib 0:8:13 10 filled 2
bind 0:8:5 2
cf 0:9:13 4 #0000000000000000
bind 0:9:5 3
lv 0:10:14 10 2
lv 0:11:9 4 3
lv 0:11:14 4 4
asg 0:11:9 add
block 0:10:16 1
fore 0:10:5 4
lv 0:13:12 4 3
ret 0:13:5 1
block 0:7:29 4
end
'''
SEA['loop_ext'] = '''\
fn shape(ref A: f64[,], v: f64[]) -> i64 {
    var t = 0
    for i in 0..2 {
        t += rows(A) * cols(A) + len(v) + numel(v) + numel(A)
    }
    return t
}
let v = zeros(5)
let m1 = zeros(2, 3)
let m2 = ones(4, 1)
printf("%d %d %d %d %d\\n", len(v), numel(v), rows(m1), cols(m1), numel(m1))
var m = m2
printf("%d %d\\n", shape(ref m, v), shape(ref m, zeros(0)))
printf("%d %d\\n", len(ones(4)), numel(zeros(2, 3)))
printf("%d %d\\n", rows(zeros(2, 3)), cols(ones(1, 7)))
let c = rows(m1) > 2
printf("%d\\n", numel(if c { m1 } else { m2 }))
// loop_ext -- DESIGN.md 3.5.9 L3 (len, rows, cols, numel made explicit by sealoop): of locals,
// of ref and value parameters, and of temporaries (ones, zeros, an if expression of matrices)
'''
AST['loop_ext'] = '''
type 0:1:17 f64 m 0
param 0:1:10 A 1 0
type 0:1:28 f64 v 0
param 0:1:25 v 0 0
type 0:1:38 i64 s 0
pname 0:2:9 t
int 0:2:13 0
var 0:2:5 0
int 0:3:14 0
int 0:3:17 2
range 0:3:14 0 0
name 0:4:9 t
name 0:4:14 rows
name 0:4:19 A
call 0:4:14 1
name 0:4:24 cols
name 0:4:29 A
call 0:4:24 1
bin 0:4:14 mul
name 0:4:34 len
name 0:4:38 v
call 0:4:34 1
bin 0:4:14 add
name 0:4:43 numel
name 0:4:49 v
call 0:4:43 1
bin 0:4:14 add
name 0:4:54 numel
name 0:4:60 A
call 0:4:54 1
bin 0:4:14 add
asg 0:4:9 add
block 0:3:19 1
for 0:3:5 i 0:3:9
name 0:6:12 t
return 0:6:5 1
block 0:1:42 3
fn 0:1:1 shape 0 2 1
pname 0:8:5 v
name 0:8:9 zeros
int 0:8:15 5
call 0:8:9 1
let 0:8:1 0
pname 0:9:5 m1
name 0:9:10 zeros
int 0:9:16 2
int 0:9:19 3
call 0:9:10 2
let 0:9:1 0
pname 0:10:5 m2
name 0:10:10 ones
int 0:10:15 4
int 0:10:18 1
call 0:10:10 2
let 0:10:1 0
name 0:11:1 printf
str 0:11:8 %25d%20%25d%20%25d%20%25d%20%25d%0A
name 0:11:28 len
name 0:11:32 v
call 0:11:28 1
name 0:11:36 numel
name 0:11:42 v
call 0:11:36 1
name 0:11:46 rows
name 0:11:51 m1
call 0:11:46 1
name 0:11:56 cols
name 0:11:61 m1
call 0:11:56 1
name 0:11:66 numel
name 0:11:72 m1
call 0:11:66 1
call 0:11:1 6
cstmt 0:11:1
pname 0:12:5 m
name 0:12:9 m2
var 0:12:1 0
name 0:13:1 printf
str 0:13:8 %25d%20%25d%0A
name 0:13:19 shape
name 0:13:29 m
ref 0:13:25
name 0:13:32 v
call 0:13:19 2
name 0:13:36 shape
name 0:13:46 m
ref 0:13:42
name 0:13:49 zeros
int 0:13:55 0
call 0:13:49 1
call 0:13:36 2
call 0:13:1 3
cstmt 0:13:1
name 0:14:1 printf
str 0:14:8 %25d%20%25d%0A
name 0:14:19 len
name 0:14:23 ones
int 0:14:28 4
call 0:14:23 1
call 0:14:19 1
name 0:14:33 numel
name 0:14:39 zeros
int 0:14:45 2
int 0:14:48 3
call 0:14:39 2
call 0:14:33 1
call 0:14:1 3
cstmt 0:14:1
name 0:15:1 printf
str 0:15:8 %25d%20%25d%0A
name 0:15:19 rows
name 0:15:24 zeros
int 0:15:30 2
int 0:15:33 3
call 0:15:24 2
call 0:15:19 1
name 0:15:38 cols
name 0:15:43 ones
int 0:15:48 1
int 0:15:51 7
call 0:15:43 2
call 0:15:38 1
call 0:15:1 3
cstmt 0:15:1
pname 0:16:5 c
name 0:16:9 rows
name 0:16:14 m1
call 0:16:9 1
int 0:16:20 2
bin 0:16:9 gt
let 0:16:1 0
name 0:17:1 printf
str 0:17:8 %25d%0A
name 0:17:16 numel
name 0:17:25 c
name 0:17:29 m1
name 0:17:41 m2
ifx 0:17:22
call 0:17:16 1
call 0:17:1 2
cstmt 0:17:1
prog 11
'''
HIR1['loop_ext'] = '''
tvec 10 4
tmat 11 4
tvec 12 3
fn 1 .main main 1 0 5 0:1:1
loc v 10 let 0:8:5
loc m1 11 let 0:9:5
loc m2 11 let 0:10:5
loc m 11 var 0:12:5
loc c 2 let 0:16:5
ci 0:8:15 3 5
lib 0:8:9 10 zeros 1
bind 0:8:1 1
ci 0:9:16 3 2
ci 0:9:19 3 3
lib 0:9:10 11 zeros 2
bind 0:9:1 2
ci 0:10:15 3 4
ci 0:10:18 3 1
lib 0:10:10 11 ones 2
bind 0:10:1 3
lv 0:11:32 10 1
lib 0:11:28 3 len 1
fconv 0:11:8 1 - - - d
ftext 0:11:8 1 %20
lv 0:11:42 10 1
lib 0:11:36 3 numel 1
fconv 0:11:8 1 - - - d
ftext 0:11:8 1 %20
lv 0:11:51 11 2
lib 0:11:46 3 rows 1
fconv 0:11:8 1 - - - d
ftext 0:11:8 1 %20
lv 0:11:61 11 2
lib 0:11:56 3 cols 1
fconv 0:11:8 1 - - - d
ftext 0:11:8 1 %20
lv 0:11:72 11 2
lib 0:11:66 3 numel 1
fconv 0:11:8 1 - - - d
ftext 0:11:8 1 %0A
fmt 0:11:8 1 10
lib 0:11:1 1 printf 1
eval 0:11:1
lv 0:12:9 11 3
bind 0:12:1 4
lv 0:13:29 11 4
rarg 0:13:25 11
lv 0:13:32 10 1
call 0:13:19 3 2 2
fconv 0:13:8 1 - - - d
ftext 0:13:8 1 %20
lv 0:13:46 11 4
rarg 0:13:42 11
ci 0:13:55 3 0
lib 0:13:49 10 zeros 1
call 0:13:36 3 2 2
fconv 0:13:8 1 - - - d
ftext 0:13:8 1 %0A
fmt 0:13:8 1 4
lib 0:13:1 1 printf 1
eval 0:13:1
ci 0:14:28 3 4
lib 0:14:23 10 ones 1
lib 0:14:19 3 len 1
fconv 0:14:8 1 - - - d
ftext 0:14:8 1 %20
ci 0:14:45 3 2
ci 0:14:48 3 3
lib 0:14:39 11 zeros 2
lib 0:14:33 3 numel 1
fconv 0:14:8 1 - - - d
ftext 0:14:8 1 %0A
fmt 0:14:8 1 4
lib 0:14:1 1 printf 1
eval 0:14:1
ci 0:15:30 3 2
ci 0:15:33 3 3
lib 0:15:24 11 zeros 2
lib 0:15:19 3 rows 1
fconv 0:15:8 1 - - - d
ftext 0:15:8 1 %20
ci 0:15:48 3 1
ci 0:15:51 3 7
lib 0:15:43 11 ones 2
lib 0:15:38 3 cols 1
fconv 0:15:8 1 - - - d
ftext 0:15:8 1 %0A
fmt 0:15:8 1 4
lib 0:15:1 1 printf 1
eval 0:15:1
lv 0:16:14 11 2
lib 0:16:9 3 rows 1
ci 0:16:20 3 2
bin 0:16:9 2 gt
bind 0:16:1 5
lv 0:17:25 2 5
lv 0:17:29 11 2
lv 0:17:41 11 3
ifx 0:17:22 11
lib 0:17:16 3 numel 1
fconv 0:17:8 1 - - - d
ftext 0:17:8 1 %0A
fmt 0:17:8 1 2
lib 0:17:1 1 printf 1
eval 0:17:1
block 0:1:1 10
end
fn 2 shape fn 3 2 2 0:1:1
par A 11 ref
par v 10 val
loc t 3 var 0:2:9
loc i 3 for 0:3:9
ci 0:2:13 3 0
bind 0:2:5 3
ci 0:3:14 3 0
ci 0:3:17 3 2
rng 0:3:14 12 0 0
lv 0:4:9 3 3
lv 0:4:19 11 1
lib 0:4:14 3 rows 1
lv 0:4:29 11 1
lib 0:4:24 3 cols 1
bin 0:4:14 3 mul
lv 0:4:38 10 2
lib 0:4:34 3 len 1
bin 0:4:14 3 add
lv 0:4:49 10 2
lib 0:4:43 3 numel 1
bin 0:4:14 3 add
lv 0:4:60 11 1
lib 0:4:54 3 numel 1
bin 0:4:14 3 add
asg 0:4:9 add
block 0:3:19 1
forr 0:3:5 4
lv 0:6:12 3 3
ret 0:6:5 1
block 0:1:42 3
end
'''
HIR['loop_ext'] = '''
tvec 10 4
tmat 11 4
tvec 12 3
fn 1 .main main 1 0 5 0:1:1
loc v 10 let 0:8:5
loc m1 11 let 0:9:5
loc m2 11 let 0:10:5
loc m 11 var 0:12:5
loc c 2 let 0:16:5
ci 0:8:15 3 5
lib 0:8:9 10 zeros 1
bind 0:8:1 1
ci 0:9:16 3 2
ci 0:9:19 3 3
lib 0:9:10 11 zeros 2
bind 0:9:1 2
ci 0:10:15 3 4
ci 0:10:18 3 1
lib 0:10:10 11 ones 2
bind 0:10:1 3
lv 0:11:32 10 1
lib 0:11:28 3 len 1
fconv 0:11:8 1 - - - d
ftext 0:11:8 1 %20
lv 0:11:42 10 1
lib 0:11:36 3 numel 1
fconv 0:11:8 1 - - - d
ftext 0:11:8 1 %20
lv 0:11:51 11 2
lib 0:11:46 3 rows 1
fconv 0:11:8 1 - - - d
ftext 0:11:8 1 %20
lv 0:11:61 11 2
lib 0:11:56 3 cols 1
fconv 0:11:8 1 - - - d
ftext 0:11:8 1 %20
lv 0:11:72 11 2
lib 0:11:66 3 numel 1
fconv 0:11:8 1 - - - d
ftext 0:11:8 1 %0A
fmt 0:11:8 1 10
lib 0:11:1 1 printf 1
eval 0:11:1
lv 0:12:9 11 3
bind 0:12:1 4
lv 0:13:29 11 4
rarg 0:13:25 11
lv 0:13:32 10 1
call 0:13:19 3 2 2
fconv 0:13:8 1 - - - d
ftext 0:13:8 1 %20
lv 0:13:46 11 4
rarg 0:13:42 11
ci 0:13:55 3 0
lib 0:13:49 10 zeros 1
call 0:13:36 3 2 2
fconv 0:13:8 1 - - - d
ftext 0:13:8 1 %0A
fmt 0:13:8 1 4
lib 0:13:1 1 printf 1
eval 0:13:1
ci 0:14:28 3 4
lib 0:14:23 10 ones 1
lib 0:14:19 3 len 1
fconv 0:14:8 1 - - - d
ftext 0:14:8 1 %20
ci 0:14:45 3 2
ci 0:14:48 3 3
lib 0:14:39 11 zeros 2
lib 0:14:33 3 numel 1
fconv 0:14:8 1 - - - d
ftext 0:14:8 1 %0A
fmt 0:14:8 1 4
lib 0:14:1 1 printf 1
eval 0:14:1
ci 0:15:30 3 2
ci 0:15:33 3 3
lib 0:15:24 11 zeros 2
lib 0:15:19 3 rows 1
fconv 0:15:8 1 - - - d
ftext 0:15:8 1 %20
ci 0:15:48 3 1
ci 0:15:51 3 7
lib 0:15:43 11 ones 2
lib 0:15:38 3 cols 1
fconv 0:15:8 1 - - - d
ftext 0:15:8 1 %0A
fmt 0:15:8 1 4
lib 0:15:1 1 printf 1
eval 0:15:1
lv 0:16:14 11 2
lib 0:16:9 3 rows 1
ci 0:16:20 3 2
bin 0:16:9 2 gt
bind 0:16:1 5
lv 0:17:25 2 5
lv 0:17:29 11 2
lv 0:17:41 11 3
ifx 0:17:22 11
lib 0:17:16 3 numel 1
fconv 0:17:8 1 - - - d
ftext 0:17:8 1 %0A
fmt 0:17:8 1 2
lib 0:17:1 1 printf 1
eval 0:17:1
block 0:1:1 10
end
fn 2 shape fn 3 2 2 0:1:1
par A 11 ref
par v 10 val
loc t 3 var 0:2:9
loc i 3 for 0:3:9
ci 0:2:13 3 0
bind 0:2:5 3
ci 0:3:14 3 0
ci 0:3:17 3 2
rng 0:3:14 12 0 0
lv 0:4:9 3 3
lv 0:4:19 11 1
lib 0:4:14 3 rows 1
lv 0:4:29 11 1
lib 0:4:24 3 cols 1
bin 0:4:14 3 mul
lv 0:4:38 10 2
lib 0:4:34 3 len 1
bin 0:4:14 3 add
lv 0:4:49 10 2
lib 0:4:43 3 numel 1
bin 0:4:14 3 add
lv 0:4:60 11 1
lib 0:4:54 3 numel 1
bin 0:4:14 3 add
asg 0:4:9 add
block 0:3:19 1
forr 0:3:5 4
lv 0:6:12 3 3
ret 0:6:5 1
block 0:1:42 3
end
'''


# ================================================================ the new dump tests: sea.hirl
# Each .hirl is the .hir with the rewrites of 3.5.9 applied at the sites listed below. An edit names
# the exact .hir records it replaces (asserted present, once) and the records that replace them;
# every new local id is given by hand, in the order of the declaring records (3.5.4: file order of
# the tmp, bind and hloop records; post-order puts a vector's own rewrite, an argument's xblk,
# before the bind or tmp that consumes it, and an inner fore's locals before the outer hloop).

def rewrite(name, hir, edits):
    lines = hir.strip('\n').split('\n')
    for old, new in edits:
        hits = [i for i in range(len(lines)) if lines[i:i + len(old)] == old]
        assert len(hits) == 1, (name, 'edit anchor', old, hits)
        i = hits[0]
        lines[i:i + len(old)] = new
    return '\n'.join(lines) + '\n'


def e_fn(fn_line, nl):
    """The fn record with nl counting the new .l locals too (3.5.9 "Locals")."""
    p = fn_line.split(' ')
    p[6] = str(nl)
    return ([fn_line], [' '.join(p)])


def e_locs(last_loc, new_locs):
    """The .l locals' loc records go after the function's other locals (3.5.4)."""
    return ([last_loc], [last_loc] + new_locs)


def e_zeros(old, P, T, k):
    """L1: the arguments (kept), then `lib P T zeros k` becomes `anew P T 1 k`."""
    assert old[-1] == 'lib %s %d zeros %d' % (P, T, k)
    return (old, old[:-1] + l1(P, T, k))


def e_fill(old, kind, P, T, E, TP, ids, nv, nr):
    """L2 at `lib P T ones|filled n`: old is the argument records then the lib record; nv and nr
    are the record counts of v (filled only) and r; the rest before the lib is c."""
    mat = len(old) - 1 > nv + nr
    assert old[-1] == 'lib %s %d %s %d' % (P, T, kind, (1 if kind == 'ones' else 2) + mat)
    v = old[:nv] if kind == 'filled' else None
    r = old[nv:nv + nr]
    c = old[nv + nr:-1] if mat else None
    return (old, l2(P, T, E, TP, ids, v=v, r=r, c=c))


def e_ext(old, fn, P, ty, rank, A=None):
    """L3 at `lib P 3 len|rows|cols|numel 1`: old is the argument's records then the lib."""
    assert old[-1] == 'lib %s 3 %s 1' % (P, fn)
    return (old, l3(P, fn, old[:-1], ty, rank, A))


def e_fore(old, nv, P, VT, E, TP, ids, X, inner=None):
    """L4 at `fore P X`: old is v's records (nv of them), the body block's records, the fore.
    inner, when given, is an edit applied to the body first (a nested fore)."""
    assert old[-1] == 'fore %s %d' % (P, X)
    body = old[nv:-1]
    if inner is not None:
        i = [j for j in range(len(body)) if body[j:j + len(inner[0])] == inner[0]]
        assert len(i) == 1
        body = body[:i[0]] + inner[1] + body[i[0] + len(inner[0]):]
    return (old, l4(P, VT, E, TP, ids, X, old[:nv], body))


def lines(text):
    return text.strip('\n').split('\n')


NEW = ['loop_fore_exits', 'loop_fill', 'loop_ext']
HIRL_NEW = {}

# ---------------------------------------------------------------- loop_fore_exits.hirl
# Types: tvec 10 4 (sea.hir's table), then tptr 11 4 (f64, the only element type; first referenced
# by `.main`'s first adat). x of .main is local 4 (line 35) and 6 (line 39).
# .main (locals a 1, b 2, n 3, x 4, c 5, x 6; .l from 7):
#   line 27 `filled(2.0, 4)` at 0:27:9, L2 vector: V 7, R 8, A 9, D 10, Z 11, O 12, L 13, K 14
#   line 30 `zeros(2)` at 0:30:9: L1
#   line 35 `for x in ones(3)` at 0:35:1, L4 whose v is L2 `ones(3)` at 0:35:10 (R 15, A 16, V 17,
#     D 18, Z 19, O 20, L 21, K 22: its records come before L4's bind), then H 23, N 24, Z 25, D 26,
#     O 27, L 28, K 29
#   line 38 `len(a)` at 0:38:9: L3 `ext 0:38:9 3 0`
#   line 39 `for x in if c { b } else { a }` at 0:39:1, L4 with v the ifx: H 30 ... K 36
#   nl = 6 + 30 = 36
# where_is (v 1, t 2, i 3, x 4): the fore at 0:3:5, a `return` in its body: H 5 ... K 11; nl 9.
# sumto (v 1 a ref parameter, cap 2, s 3, x 4): the fore at 0:11:5 (continue, break): H 5 ... K 11.
# pairs (a 1, b 2, c 3, x 4, y 5): the outer fore at 0:20:5 binds H 6, N 7, Z 8, D 9, O 10, L 11;
#   then, inside its hloop's block, the inner fore at 0:21:9: H 12, N 13, Z 14, D 15, O 16, L 17,
#   K 18; the outer hloop's K is 19 (its record follows its block); nl 3 + 14 = 17.
FE = 'loop_fore_exits'
FE_BODY_35 = ['lv 0:36:5 4 3', 'lv 0:36:10 4 4', 'asg 0:36:5 add', 'block 0:35:18 1']
FE_BODY_39 = ['lv 0:40:5 4 3', 'lv 0:40:10 4 6', 'cf 0:40:14 4 #3FF0000000000000',
              'bin 0:40:10 4 add', 'asg 0:40:5 add', 'block 0:39:32 1']
FE_INNER = ['lv 0:21:18 10 2', 'lv 0:22:16 4 4', 'lv 0:22:20 4 5', 'bin 0:22:16 2 lt',
            'lv 0:22:24 3 3', 'ci 0:22:29 3 1', 'asg 0:22:24 add', 'block 0:22:22 1',
            'if 0:22:13 0', 'block 0:21:20 1', 'fore 0:21:9 5']
HIRL_NEW[FE] = rewrite(FE, HIR[FE], [
    (['tvec 10 4'], ['tvec 10 4', 'tptr 11 4']),
    e_fn('fn 1 .main main 1 0 6 0:1:1', 36),
    e_locs('loc x 4 for 0:39:5',
           locs(1, fill_locs('0:27:9', 10, 4, 11, 'filled', False)) +
           locs(9, fill_locs('0:35:10', 10, 4, 11, 'ones', False)) +
           locs(17, fore_locs('0:35:1', 10, 11)) + locs(24, fore_locs('0:39:1', 10, 11))),
    e_fill(['cf 0:27:16 4 #4000000000000000', 'ci 0:27:21 3 4', 'lib 0:27:9 10 filled 2'],
           'filled', '0:27:9', 10, 4, 11, fill_ids(7, 'filled', False), 1, 1),
    e_zeros(['ci 0:30:15 3 2', 'lib 0:30:9 10 zeros 1'], '0:30:9', 10, 1),
    (['ci 0:35:15 3 3', 'lib 0:35:10 10 ones 1'] + FE_BODY_35 + ['fore 0:35:1 4'],
     l4('0:35:1', 10, 4, 11, fore_ids(23), 4,
        l2('0:35:10', 10, 4, 11, fill_ids(15, 'ones', False), r=['ci 0:35:15 3 3']), FE_BODY_35)),
    e_ext(['lv 0:38:13 10 1', 'lib 0:38:9 3 len 1'], 'len', '0:38:9', 10, 1),
    e_fore(['lv 0:39:13 2 5', 'lv 0:39:17 10 2', 'lv 0:39:28 10 1', 'ifx 0:39:10 10'] +
           FE_BODY_39 + ['fore 0:39:1 6'], 4, '0:39:1', 10, 4, 11, fore_ids(30), 6),
    e_fn('fn 2 where_is fn 3 2 2 0:1:1', 9),
    e_locs('loc x 4 for 0:3:9', locs(1, fore_locs('0:3:5', 10, 11))),
    e_fore(['lv 0:3:14 10 1', 'lv 0:4:12 4 4', 'lv 0:4:17 4 2', 'bin 0:4:12 2 eq',
            'lv 0:4:28 3 3', 'ret 0:4:21 1', 'block 0:4:19 1', 'if 0:4:9 0', 'lv 0:5:9 3 3',
            'ci 0:5:14 3 1', 'asg 0:5:9 add', 'block 0:3:16 2', 'fore 0:3:5 4'],
           1, '0:3:5', 10, 4, 11, fore_ids(5), 4),
    e_fn('fn 3 sumto fn 4 2 2 0:9:1', 9),
    e_locs('loc x 4 for 0:11:9', locs(1, fore_locs('0:11:5', 10, 11))),
    e_fore(['lv 0:11:14 10 1', 'lv 0:12:12 4 4', 'cf 0:12:16 4 #0000000000000000',
            'bin 0:12:12 2 lt', 'cont 0:12:22', 'block 0:12:20 1', 'if 0:12:9 0',
            'lv 0:13:12 4 4', 'lv 0:13:16 4 2', 'bin 0:13:12 2 gt', 'break 0:13:22',
            'block 0:13:20 1', 'if 0:13:9 0', 'lv 0:14:9 4 3', 'lv 0:14:14 4 4',
            'asg 0:14:9 add', 'block 0:11:16 3', 'fore 0:11:5 4'],
           1, '0:11:5', 10, 4, 11, fore_ids(5), 4),
    e_fn('fn 4 pairs fn 3 2 3 0:18:1', 17),
    e_locs('loc y 4 for 0:21:13',
           locs(1, fore_locs('0:20:5', 10, 11)[:6]) + locs(7, fore_locs('0:21:9', 10, 11)) +
           locs(14, fore_locs('0:20:5', 10, 11)[6:])),
    e_fore(['lv 0:20:14 10 1'] + FE_INNER + ['block 0:20:16 1', 'fore 0:20:5 4'],
           1, '0:20:5', 10, 4, 11, dict(H=6, N=7, Z=8, D=9, O=10, L=11, K=19), 4,
           inner=e_fore(FE_INNER, 1, '0:21:9', 10, 4, 11, fore_ids(12), 5)),
])

# ---------------------------------------------------------------- loop_fill.hirl
# Types: sea.hir's tvec 10 4, tvec 11 3, tvec 12 2, tmat 13 4, tmat 14 3, tmat 15 2, then the tptrs
# in order of first reference: 16 (f64, line 15), 17 (i64, line 16), 18 (bool, line 17).
# .main (locals vf 1 ... vq 16; .l from 17), the L2 sites in file order, each with its locals in
# L2's order (filled: V R [C] A [N] D Z O L K; ones: R [C] A [N] V D Z O L K):
#   line 15 filled(2.5, 3)        0:15:10  T 10 E f64   17-24
#   line 16 filled(4, 2)          0:16:10  T 11 E i64   25-32
#   line 17 filled(true, 2)       0:17:10  T 12 E bool  33-40   (est scale 1, SEA_ESIZE_BOOL)
#   line 18 len(vb)               0:18:46  L3
#   line 19 filled(0.25, 2, 3)    0:19:10  T 13 E f64   41-50   (matrix: N = wbin mul R C)
#   line 20 filled(-7, 3, 1)      0:20:10  T 14 E i64   51-60
#   line 21 filled(false, 1, 2)   0:21:10  T 15 E bool  61-70
#   line 23 ones(2, 2)            0:23:10  T 13 E f64   71-80   (V the cf 1.0 after N)
#   line 24 zeros(3, 2)           0:24:10  L1 anew 13 1 2
#   line 25 rows(mz)              0:25:42  L3
#   line 29 filled(k, grow(ref k)) 0:29:10 T 11 E i64   81-88   (V's child `lv k`, R's the call)
#   line 30 len(vk)               0:30:29  L3
#   line 32 ones(if c {2} else {3}) 0:32:10 T 10 E f64  89-96   (R's child the ifx)
#   line 35 filled(p && q, m)     0:35:10  T 12 E bool  97-104  (V's child the and, R's `lv m`)
#   line 36 len(vc)               0:36:32  L3
#   nl = 16 + 88 = 104.
# grow holds no rewritten construct (a forr): unchanged. count (n 1 a ref parameter, v 2, s 3, x
# 4): line 8 filled(0.5, n) at 0:8:13 (V 5 ... K 12; R's child `lv n` of the ref parameter), then
# the fore at 0:10:5: H 13 ... K 19; nl 3 + 15 = 18.
FL = 'loop_fill'
FL_SITES = [  # (records of the arguments and the lib, kind, P, T, E, TP, first lid, nv, nr)
    (['cf 0:15:17 4 #4004000000000000', 'ci 0:15:22 3 3', 'lib 0:15:10 10 filled 2'],
     'filled', '0:15:10', 10, 4, 16, 17, 1, 1),
    (['ci 0:16:17 3 4', 'ci 0:16:20 3 2', 'lib 0:16:10 11 filled 2'],
     'filled', '0:16:10', 11, 3, 17, 25, 1, 1),
    (['cb 0:17:17 2 1', 'ci 0:17:23 3 2', 'lib 0:17:10 12 filled 2'],
     'filled', '0:17:10', 12, 2, 18, 33, 1, 1),
    (['cf 0:19:17 4 #3FD0000000000000', 'ci 0:19:23 3 2', 'ci 0:19:26 3 3',
      'lib 0:19:10 13 filled 3'], 'filled', '0:19:10', 13, 4, 16, 41, 1, 1),
    (['ci 0:20:17 3 -7', 'ci 0:20:21 3 3', 'ci 0:20:24 3 1', 'lib 0:20:10 14 filled 3'],
     'filled', '0:20:10', 14, 3, 17, 51, 1, 1),
    (['cb 0:21:17 2 0', 'ci 0:21:24 3 1', 'ci 0:21:27 3 2', 'lib 0:21:10 15 filled 3'],
     'filled', '0:21:10', 15, 2, 18, 61, 1, 1),
    (['ci 0:23:15 3 2', 'ci 0:23:18 3 2', 'lib 0:23:10 13 ones 2'],
     'ones', '0:23:10', 13, 4, 16, 71, 0, 1),
    (['lv 0:29:17 3 10', 'lv 0:29:29 3 10', 'rarg 0:29:25 3', 'call 0:29:20 3 2 1',
      'lib 0:29:10 11 filled 2'], 'filled', '0:29:10', 11, 3, 17, 81, 1, 3),
    (['lv 0:32:18 2 12', 'ci 0:32:22 3 2', 'ci 0:32:33 3 3', 'ifx 0:32:15 3',
      'lib 0:32:10 10 ones 1'], 'ones', '0:32:10', 10, 4, 16, 89, 0, 4),
    (['lv 0:35:17 2 14', 'lv 0:35:22 2 15', 'bin 0:35:17 2 and', 'lv 0:35:25 3 9',
      'lib 0:35:10 12 filled 2'], 'filled', '0:35:10', 12, 2, 18, 97, 3, 1),
]


def fill_site(s):
    old, kind, P, T, E, TP, first, nv, nr = s
    mat = len(old) - 1 > nv + nr
    return e_fill(old, kind, P, T, E, TP, fill_ids(first, kind, mat), nv, nr)


def fill_site_locs(s):
    old, kind, P, T, E, TP, first, nv, nr = s
    return fill_locs(P, T, E, TP, kind, len(old) - 1 > nv + nr)


FL_LOCS = []
for s in FL_SITES:
    FL_LOCS += fill_site_locs(s)
assert len(FL_LOCS) == 88
FL_COUNT_FILL = (['cf 0:8:20 4 #3FE0000000000000', 'lv 0:8:25 3 1', 'lib 0:8:13 10 filled 2'],
                 'filled', '0:8:13', 10, 4, 16, 5, 1, 1)
HIRL_NEW[FL] = rewrite(FL, HIR[FL], [
    (['tmat 15 2'], ['tmat 15 2', 'tptr 16 4', 'tptr 17 3', 'tptr 18 2']),
    e_fn('fn 1 .main main 1 0 16 0:1:1', 104),
    e_locs('loc vq 12 let 0:35:5', locs(1, FL_LOCS)),
    ] + [fill_site(s) for s in FL_SITES] + [
    e_ext(['lv 0:18:50 12 3', 'lib 0:18:46 3 len 1'], 'len', '0:18:46', 12, 1),
    e_zeros(['ci 0:24:16 3 3', 'ci 0:24:19 3 2', 'lib 0:24:10 13 zeros 2'], '0:24:10', 13, 2),
    e_ext(['lv 0:25:47 13 8', 'lib 0:25:42 3 rows 1'], 'rows', '0:25:42', 13, 2),
    e_ext(['lv 0:30:33 11 11', 'lib 0:30:29 3 len 1'], 'len', '0:30:29', 11, 1),
    e_ext(['lv 0:36:36 10 13', 'lib 0:36:32 3 len 1'], 'len', '0:36:32', 10, 1),
    e_fn('fn 3 count fn 4 1 3 0:7:1', 18),
    e_locs('loc x 4 for 0:10:9', locs(1, fill_site_locs(FL_COUNT_FILL)) +
           locs(9, fore_locs('0:10:5', 10, 16))),
    fill_site(FL_COUNT_FILL),
    e_fore(['lv 0:10:14 10 2', 'lv 0:11:9 4 3', 'lv 0:11:14 4 4', 'asg 0:11:9 add',
            'block 0:10:16 1', 'fore 0:10:5 4'], 1, '0:10:5', 10, 4, 16, fore_ids(13), 4),
])

# ---------------------------------------------------------------- loop_ext.hirl
# Types: tvec 10 4, tmat 11 4, tvec 12 3 (the range of shape's forr), then tptr 13 4 (f64; first
# referenced by line 10's ones).
# .main (v 1, m1 2, m2 3, m 4, c 5; .l from 6):
#   line 8 zeros(5), line 9 zeros(2, 3): L1
#   line 10 ones(4, 1) at 0:10:10, L2 matrix: R 6, C 7, A 8, N 9, V 10, D 11, Z 12, O 13, L 14, K 15
#   line 11 len(v), numel(v) (a vector: ext 0), rows(m1), cols(m1) (ext 1): L3 ext; numel(m1) at
#     0:11:66: L3's xblk with tmp A 16 = `lv m1`
#   line 13 zeros(0) (a value argument of shape): L1
#   line 14 len(ones(4)): L2 vector at 0:14:23 (R 17, A 18, V 19, D 20, Z 21, O 22, L 23, K 24)
#     under `ext 0:14:19 3 0`; numel(zeros(2, 3)) at 0:14:33: L1 `anew 0:14:39 11 1 2` as the child
#     of L3's tmp A 25
#   line 15 rows(zeros(2, 3)): L1 under ext 0; cols(ones(1, 7)): L2 matrix at 0:15:43 (R 26, C 27,
#     A 28, N 29, V 30, D 31, Z 32, O 33, L 34, K 35) under ext 1
#   line 16 rows(m1): ext
#   line 17 numel(if c { m1 } else { m2 }) at 0:17:16: L3's xblk, tmp A 36 = the ifx
#   nl = 5 + 31 = 36.
# shape (A 1 a ref parameter of type f64[,], v 2, t 3, i 4): line 4 rows(A), cols(A), len(v),
#   numel(v): ext; numel(A) at 0:4:54: xblk with tmp A 5 = `lv A` (the ref parameter); nl 2 + 1 = 3.
XT = 'loop_ext'
XT_ONES4 = l2('0:14:23', 10, 4, 13, fill_ids(17, 'ones', False), r=['ci 0:14:28 3 4'])
XT_ONES17 = l2('0:15:43', 11, 4, 13, fill_ids(26, 'ones', True), r=['ci 0:15:48 3 1'],
               c=['ci 0:15:51 3 7'])
HIRL_NEW[XT] = rewrite(XT, HIR[XT], [
    (['tvec 12 3'], ['tvec 12 3', 'tptr 13 4']),
    e_fn('fn 1 .main main 1 0 5 0:1:1', 36),
    e_locs('loc c 2 let 0:16:5',
           locs(1, fill_locs('0:10:10', 11, 4, 13, 'ones', True)) +
           locs(11, [(11, 'let', '0:11:66')]) +
           locs(12, fill_locs('0:14:23', 10, 4, 13, 'ones', False)) +
           locs(20, [(11, 'let', '0:14:33')]) +
           locs(21, fill_locs('0:15:43', 11, 4, 13, 'ones', True)) +
           locs(31, [(11, 'let', '0:17:16')])),
    e_zeros(['ci 0:8:15 3 5', 'lib 0:8:9 10 zeros 1'], '0:8:9', 10, 1),
    e_zeros(['ci 0:9:16 3 2', 'ci 0:9:19 3 3', 'lib 0:9:10 11 zeros 2'], '0:9:10', 11, 2),
    e_fill(['ci 0:10:15 3 4', 'ci 0:10:18 3 1', 'lib 0:10:10 11 ones 2'], 'ones', '0:10:10', 11,
           4, 13, fill_ids(6, 'ones', True), 0, 1),
    e_ext(['lv 0:11:32 10 1', 'lib 0:11:28 3 len 1'], 'len', '0:11:28', 10, 1),
    e_ext(['lv 0:11:42 10 1', 'lib 0:11:36 3 numel 1'], 'numel', '0:11:36', 10, 1),
    e_ext(['lv 0:11:51 11 2', 'lib 0:11:46 3 rows 1'], 'rows', '0:11:46', 11, 2),
    e_ext(['lv 0:11:61 11 2', 'lib 0:11:56 3 cols 1'], 'cols', '0:11:56', 11, 2),
    e_ext(['lv 0:11:72 11 2', 'lib 0:11:66 3 numel 1'], 'numel', '0:11:66', 11, 2, A=16),
    e_zeros(['ci 0:13:55 3 0', 'lib 0:13:49 10 zeros 1'], '0:13:49', 10, 1),
    (['ci 0:14:28 3 4', 'lib 0:14:23 10 ones 1', 'lib 0:14:19 3 len 1'],
     l3('0:14:19', 'len', XT_ONES4, 10, 1)),
    (['ci 0:14:45 3 2', 'ci 0:14:48 3 3', 'lib 0:14:39 11 zeros 2', 'lib 0:14:33 3 numel 1'],
     l3('0:14:33', 'numel', ['ci 0:14:45 3 2', 'ci 0:14:48 3 3'] + l1('0:14:39', 11, 2), 11, 2,
        A=25)),
    (['ci 0:15:30 3 2', 'ci 0:15:33 3 3', 'lib 0:15:24 11 zeros 2', 'lib 0:15:19 3 rows 1'],
     l3('0:15:19', 'rows', ['ci 0:15:30 3 2', 'ci 0:15:33 3 3'] + l1('0:15:24', 11, 2), 11, 2)),
    (['ci 0:15:48 3 1', 'ci 0:15:51 3 7', 'lib 0:15:43 11 ones 2', 'lib 0:15:38 3 cols 1'],
     l3('0:15:38', 'cols', XT_ONES17, 11, 2)),
    e_ext(['lv 0:16:14 11 2', 'lib 0:16:9 3 rows 1'], 'rows', '0:16:9', 11, 2),
    e_ext(['lv 0:17:25 2 5', 'lv 0:17:29 11 2', 'lv 0:17:41 11 3', 'ifx 0:17:22 11',
           'lib 0:17:16 3 numel 1'], 'numel', '0:17:16', 11, 2, A=36),
    e_fn('fn 2 shape fn 3 2 2 0:1:1', 3),
    e_locs('loc i 3 for 0:3:9', locs(1, [(11, 'let', '0:4:54')])),
    e_ext(['lv 0:4:19 11 1', 'lib 0:4:14 3 rows 1'], 'rows', '0:4:14', 11, 2),
    e_ext(['lv 0:4:29 11 1', 'lib 0:4:24 3 cols 1'], 'cols', '0:4:24', 11, 2),
    e_ext(['lv 0:4:38 10 2', 'lib 0:4:34 3 len 1'], 'len', '0:4:34', 10, 1),
    e_ext(['lv 0:4:49 10 2', 'lib 0:4:43 3 numel 1'], 'numel', '0:4:43', 10, 1),
    e_ext(['lv 0:4:60 11 1', 'lib 0:4:54 3 numel 1'], 'numel', '0:4:54', 11, 2, A=5),
])

# ================================================================ the new dump tests: sea.lir1
# Written by hand from 3.6.6 (the 4d rules, unchanged by 4e-0: the split is LIR-neutral), each
# instruction in the order the rules give, registers numbered by first appearance (3.6.1), blocks
# in the order they open, slots in sa order, labels in la order. Notation below: rN rule N.
#
# loop_fore_exits, .main:
#   l.27 `var a = filled(2.0, 4)`: r17 filled (T3: a's register is A's, p6): V `lf f1`, R `li i2`,
#     arrnew (`li` ek 1, rank 1, C 1; sea_arr_new_u), data `ldp p7`, loop(N; K) blocks 1/2, `stf`.
#   l.28, l.29 `a[i] = c`: r19 (value, index, ext+chkb, cow(a) block 3 / 4, data, `stf`).
#   l.30 `let b = zeros(2)`: r17 arrnewz (sea_arr_new) into b (p33).
#   l.31 printf of two calls (r5, r8: slot s1 of 16 bytes, d1).
#   l.32 `sumto(ref a, ...)` twice: r31 (a reference local: `sa`, `stp` before, `ldp` reload after).
#   l.34 `var n = 0.0` (f52); l.35 L4 over ones(3): r30 (1) the owned ones value is H itself
#     (p57; its fill loop blocks 5/6), (2) ext, `li Z`, `icmp gt`, `if 7`, data, `li O`, `isub`,
#     `loop 8`, `ldf` into x (f72), the body `fadd f52`, (3) `release p57` (r16 (a): H is bound in
#     L4's block).
#   l.38 `let c = len(a) > 3`: r17 ext, r1 into c (i75).
#   l.39 L4 over `if c { b } else { a }`: r3 into its own register p76, each arm owned (r15 (a),
#     (b): `mov`, `retain`; block 9), held as H with no further mov (3.5.9 L4), loop blocks 10/11.
#   l.42 printf; the end of the body block releases b, a (r16 (a), reverse order), `ret 0` (r6).
# where_is: L4 over the parameter v (borrowed: `mov p4 p1`, `retain p4`); `return i` inside the
#   loop releases H first (r16 (c): every enclosing hidden local), then `ret 1 i3`; after the
#   loop `release p4`; `return -1` (folded constant, 3.5.7).
# sumto: v is a ref parameter: H = `ldp p4 p1 - 0 0`, `mov p5 p4`, `retain p5` (3.5.9 L4);
#   `continue` is `next 2` and `break` `exit 2` of the hloop's loop, neither releases H (r16 (f)).
# pairs: two nested L4 loops (blocks 1/2 outer, 3/4 inner); the inner H (p13) is released at the
#   end of the inner L4 block, inside the outer loop body; `c += 1` is `iaddc` (r1, site 0:22).
LIR1 = {}
LIR1['loop_fore_exits'] = '''
func .main main 0:1:1 0 0
slot s1 16 8
slot s2 8 8
slot s3 8 8
slot s4 16 8
slot s5 16 8
slot s6 8 8
lf f1 #4000000000000000
li i2 4
li i3 1
li i4 1
li i5 1
rcall sea_arr_new_u 0:27 1 p6 4 i3 i4 i2 i5
ldp p7 p6 - 0 40
li i8 0
icmp gt i9 i2 i8
if 1 i9
li i10 1
isub i11 i2 i10
loop 2 i12 i8 i11 i10
stf f1 p7 i12 8 0
endloop 2
endif 1
lf f13 #BFF0000000000000
li i14 1
ldi i15 p6 - 0 16
chkb i14 i15 0 0:28
ldi i16 p6 - 0 0
li i17 1
icmp ne i18 i16 i17
if 3 i18
rcall sea_arr_unique 0:28 1 p19 1 p6
mov p6 p19
endif 3
ldp p20 p6 - 0 40
stf f13 p20 i14 8 0
lf f21 #4022000000000000
li i22 2
ldi i23 p6 - 0 16
chkb i22 i23 0 0:29
ldi i24 p6 - 0 0
li i25 1
icmp ne i26 i24 i25
if 4 i26
rcall sea_arr_unique 0:29 1 p27 1 p6
mov p6 p27
endif 4
ldp p28 p6 - 0 40
stf f21 p28 i22 8 0
li i29 2
li i30 1
li i31 1
li i32 1
rcall sea_arr_new 0:30 1 p33 4 i30 i31 i29 i32
lf f34 #4022000000000000
call where_is 1 i35 2 p6 f34
lf f36 #3FF0000000000000
call where_is 1 i37 2 p33 f36
sa p38 s1
sti i35 p38 - 0 0
sti i37 p38 - 0 8
la p39 d1
rcall sea_printf 0:31 0 2 p39 p38
sa p40 s2
stp p6 p40 - 0 0
lf f41 #4014000000000000
call sumto 1 f42 2 p40 f41
ldp p6 p40 - 0 0
sa p43 s3
stp p6 p43 - 0 0
lf f44 #4024000000000000
call sumto 1 f45 2 p43 f44
ldp p6 p43 - 0 0
sa p46 s4
stf f42 p46 - 0 0
stf f45 p46 - 0 8
la p47 d2
rcall sea_printf 0:32 0 2 p47 p46
call pairs 1 i48 2 p6 p6
call pairs 1 i49 2 p33 p6
sa p50 s5
sti i48 p50 - 0 0
sti i49 p50 - 0 8
la p51 d3
rcall sea_printf 0:33 0 2 p51 p50
lf f52 #0000000000000000
li i53 3
li i54 1
li i55 1
li i56 1
rcall sea_arr_new_u 0:35 1 p57 4 i54 i55 i53 i56
lf f58 #3FF0000000000000
ldp p59 p57 - 0 40
li i60 0
icmp gt i61 i53 i60
if 5 i61
li i62 1
isub i63 i53 i62
loop 6 i64 i60 i63 i62
stf f58 p59 i64 8 0
endloop 6
endif 5
ldi i65 p57 - 0 16
li i66 0
icmp gt i67 i65 i66
if 7 i67
ldp p68 p57 - 0 40
li i69 1
isub i70 i65 i69
loop 8 i71 i66 i70 i69
ldf f72 p68 i71 8 0
fadd f52 f52 f72
endloop 8
endif 7
release p57
ldi i73 p6 - 0 16
li i74 3
icmp gt i75 i73 i74
if 9 i75
mov p76 p33
retain p76
else 9
mov p76 p6
retain p76
endif 9
ldi i77 p76 - 0 16
li i78 0
icmp gt i79 i77 i78
if 10 i79
ldp p80 p76 - 0 40
li i81 1
isub i82 i77 i81
loop 11 i83 i78 i82 i81
ldf f84 p80 i83 8 0
lf f85 #3FF0000000000000
fadd f86 f84 f85
fadd f52 f52 f86
endloop 11
endif 10
release p76
sa p87 s6
stf f52 p87 - 0 0
la p88 d4
rcall sea_printf 0:42 0 2 p88 p87
release p33
release p6
ret 0
endfunc
func where_is fn 0:1:1 2 p1 f2 1 i
li i3 0
mov p4 p1
retain p4
ldi i5 p4 - 0 16
li i6 0
icmp gt i7 i5 i6
if 1 i7
ldp p8 p4 - 0 40
li i9 1
isub i10 i5 i9
loop 2 i11 i6 i10 i9
ldf f12 p8 i11 8 0
fcmp eq i13 f12 f2
if 3 i13
release p4
ret 1 i3
endif 3
li i14 1
iaddc i3 i3 i14 0:5
endloop 2
endif 1
release p4
li i15 -1
ret 1 i15
endfunc
func sumto fn 0:9:1 2 p1 f2 1 f
lf f3 #0000000000000000
ldp p4 p1 - 0 0
mov p5 p4
retain p5
ldi i6 p5 - 0 16
li i7 0
icmp gt i8 i6 i7
if 1 i8
ldp p9 p5 - 0 40
li i10 1
isub i11 i6 i10
loop 2 i12 i7 i11 i10
ldf f13 p9 i12 8 0
lf f14 #0000000000000000
fcmp lt i15 f13 f14
if 3 i15
next 2
endif 3
fcmp gt i16 f13 f2
if 4 i16
exit 2
endif 4
fadd f3 f3 f13
endloop 2
endif 1
release p5
ret 1 f3
endfunc
func pairs fn 0:18:1 2 p1 p2 1 i
li i3 0
mov p4 p1
retain p4
ldi i5 p4 - 0 16
li i6 0
icmp gt i7 i5 i6
if 1 i7
ldp p8 p4 - 0 40
li i9 1
isub i10 i5 i9
loop 2 i11 i6 i10 i9
ldf f12 p8 i11 8 0
mov p13 p2
retain p13
ldi i14 p13 - 0 16
li i15 0
icmp gt i16 i14 i15
if 3 i16
ldp p17 p13 - 0 40
li i18 1
isub i19 i14 i18
loop 4 i20 i15 i19 i18
ldf f21 p17 i20 8 0
fcmp lt i22 f12 f21
if 5 i22
li i23 1
iaddc i3 i3 i23 0:22
endif 5
endloop 4
endif 3
release p13
endloop 2
endif 1
release p4
ret 1 i3
endfunc
fmt d1 4
fconv - - - d i
ftext %20
fconv - - - d i
ftext %0A
fmt d2 4
fconv - - - g f
ftext %20
fconv - - - g f
ftext %0A
fmt d3 4
fconv - - - d i
ftext %20
fconv - - - d i
ftext %0A
fmt d4 2
fconv - - - g f
ftext %0A
'''

# loop_fill, .main (each constructor's value moved into its local by T3, r17):
#   l.15-17 filled vectors of f64 (`stf` scale 8), i64 (`sti` 8), bool (`stb` 1; ek 3), blocks 1-6.
#   l.18 element reads (r18: index, ext, chkb, data, load), len (ext), printf slot s1 of 32 bytes.
#   l.19-21 filled matrices: arrnew with R, C (no `li C 1`), N = `imul` (wbin mul), blocks 7-12.
#   l.22 matrix element reads (r18: both checks, `imul T I1 E0`, `iadd X I0 T`).
#   l.23 ones(2, 2): arrnew, N, then V `lf #3FF0...` (r17's order), blocks 13/14.
#   l.24 zeros(3, 2): arrnewz. l.25 reads and rows(mz).
#   l.27 count(ref m) twice: r12 scalar ref arguments (slot, `sti`, call, `ldi` reload).
#   l.29 `filled(k, grow(ref k))`: V's `lv k` is read before the call that passes k by ref, so r12
#     copies it: `mov i162 i161` into V's register (T1); R is the call's result register (i164);
#     the fill stores V (the old k, 1), blocks 15/16.
#   l.31 `let c = k > 2`; l.32 `ones(if c {2} else {3})`: the ifx is R's child, computed into its
#     own register i184 by r3 (block 17), R another name for it (T1); fill blocks 18/19.
#   l.33-35 `filled(p && q, m)`: the and is V's child: r3 into its own register i199 (`mov i199
#     i196`, `if 20`, `mov i199 i198`); R is another name for m (i154); bool fill blocks 21/22.
#   l.36 reads, len, grow(ref m) (r12), printf; then the 11 array locals released in reverse
#     declaration order (r16 (a)).
# grow: forr (r4: rcount, blocks 1/2); `k += 1` on a ref parameter (r12: load, value, `iaddc`,
#   store); `return k` loads it.
# count: filled(0.5, n) with n a ref parameter: R is n's `ldi i3 p1 - 0 0` (T1: a ref parameter is
#   not aliased; the child is computed into R's register); then the borrowed v held by L4
#   (`mov p15 p7`, `retain p15`, released after the loop); `return s` releases v (r16 (c)).
LIR1['loop_fill'] = '''
func .main main 0:1:1 0 0
slot s1 32 8
slot s2 24 8
slot s3 24 8
slot s4 8 8
slot s5 8 8
slot s6 16 8
slot s7 8 8
slot s8 24 8
slot s9 8 8
slot s10 32 8
lf f1 #4004000000000000
li i2 3
li i3 1
li i4 1
li i5 1
rcall sea_arr_new_u 0:15 1 p6 4 i3 i4 i2 i5
ldp p7 p6 - 0 40
li i8 0
icmp gt i9 i2 i8
if 1 i9
li i10 1
isub i11 i2 i10
loop 2 i12 i8 i11 i10
stf f1 p7 i12 8 0
endloop 2
endif 1
li i13 4
li i14 2
li i15 2
li i16 1
li i17 1
rcall sea_arr_new_u 0:16 1 p18 4 i15 i16 i14 i17
ldp p19 p18 - 0 40
li i20 0
icmp gt i21 i14 i20
if 3 i21
li i22 1
isub i23 i14 i22
loop 4 i24 i20 i23 i22
sti i13 p19 i24 8 0
endloop 4
endif 3
li i25 1
li i26 2
li i27 3
li i28 1
li i29 1
rcall sea_arr_new_u 0:17 1 p30 4 i27 i28 i26 i29
ldp p31 p30 - 0 40
li i32 0
icmp gt i33 i26 i32
if 5 i33
li i34 1
isub i35 i26 i34
loop 6 i36 i32 i35 i34
stb i25 p31 i36 1 0
endloop 6
endif 5
li i37 2
ldi i38 p6 - 0 16
chkb i37 i38 0 0:18
ldp p39 p6 - 0 40
ldf f40 p39 i37 8 0
li i41 1
ldi i42 p18 - 0 16
chkb i41 i42 0 0:18
ldp p43 p18 - 0 40
ldi i44 p43 i41 8 0
li i45 0
ldi i46 p30 - 0 16
chkb i45 i46 0 0:18
ldp p47 p30 - 0 40
ldb i48 p47 i45 1 0
ldi i49 p30 - 0 16
sa p50 s1
stf f40 p50 - 0 0
sti i44 p50 - 0 8
sti i48 p50 - 0 16
sti i49 p50 - 0 24
la p51 d1
rcall sea_printf 0:18 0 2 p51 p50
lf f52 #3FD0000000000000
li i53 2
li i54 3
li i55 1
li i56 2
rcall sea_arr_new_u 0:19 1 p57 4 i55 i56 i53 i54
imul i58 i53 i54
ldp p59 p57 - 0 40
li i60 0
icmp gt i61 i58 i60
if 7 i61
li i62 1
isub i63 i58 i62
loop 8 i64 i60 i63 i62
stf f52 p59 i64 8 0
endloop 8
endif 7
li i65 -7
li i66 3
li i67 1
li i68 2
li i69 2
rcall sea_arr_new_u 0:20 1 p70 4 i68 i69 i66 i67
imul i71 i66 i67
ldp p72 p70 - 0 40
li i73 0
icmp gt i74 i71 i73
if 9 i74
li i75 1
isub i76 i71 i75
loop 10 i77 i73 i76 i75
sti i65 p72 i77 8 0
endloop 10
endif 9
li i78 0
li i79 1
li i80 2
li i81 3
li i82 2
rcall sea_arr_new_u 0:21 1 p83 4 i81 i82 i79 i80
imul i84 i79 i80
ldp p85 p83 - 0 40
li i86 0
icmp gt i87 i84 i86
if 11 i87
li i88 1
isub i89 i84 i88
loop 12 i90 i86 i89 i88
stb i78 p85 i90 1 0
endloop 12
endif 11
li i91 1
li i92 2
ldi i93 p57 - 0 16
chkb i91 i93 0 0:22
ldi i94 p57 - 0 24
chkb i92 i94 1 0:22
ldp p95 p57 - 0 40
imul i96 i92 i93
iadd i97 i91 i96
ldf f98 p95 i97 8 0
li i99 2
li i100 0
ldi i101 p70 - 0 16
chkb i99 i101 0 0:22
ldi i102 p70 - 0 24
chkb i100 i102 1 0:22
ldp p103 p70 - 0 40
imul i104 i100 i101
iadd i105 i99 i104
ldi i106 p103 i105 8 0
li i107 0
li i108 1
ldi i109 p83 - 0 16
chkb i107 i109 0 0:22
ldi i110 p83 - 0 24
chkb i108 i110 1 0:22
ldp p111 p83 - 0 40
imul i112 i108 i109
iadd i113 i107 i112
ldb i114 p111 i113 1 0
sa p115 s2
stf f98 p115 - 0 0
sti i106 p115 - 0 8
sti i114 p115 - 0 16
la p116 d2
rcall sea_printf 0:22 0 2 p116 p115
li i117 2
li i118 2
li i119 1
li i120 2
rcall sea_arr_new_u 0:23 1 p121 4 i119 i120 i117 i118
imul i122 i117 i118
lf f123 #3FF0000000000000
ldp p124 p121 - 0 40
li i125 0
icmp gt i126 i122 i125
if 13 i126
li i127 1
isub i128 i122 i127
loop 14 i129 i125 i128 i127
stf f123 p124 i129 8 0
endloop 14
endif 13
li i130 3
li i131 2
li i132 1
li i133 2
rcall sea_arr_new 0:24 1 p134 4 i132 i133 i130 i131
li i135 1
li i136 1
ldi i137 p121 - 0 16
chkb i135 i137 0 0:25
ldi i138 p121 - 0 24
chkb i136 i138 1 0:25
ldp p139 p121 - 0 40
imul i140 i136 i137
iadd i141 i135 i140
ldf f142 p139 i141 8 0
li i143 2
li i144 1
ldi i145 p134 - 0 16
chkb i143 i145 0 0:25
ldi i146 p134 - 0 24
chkb i144 i146 1 0:25
ldp p147 p134 - 0 40
imul i148 i144 i145
iadd i149 i143 i148
ldf f150 p147 i149 8 0
ldi i151 p134 - 0 16
sa p152 s3
stf f142 p152 - 0 0
stf f150 p152 - 0 8
sti i151 p152 - 0 16
la p153 d3
rcall sea_printf 0:25 0 2 p153 p152
li i154 4
sa p155 s4
sti i154 p155 - 0 0
call count 1 f156 1 p155
ldi i154 p155 - 0 0
sa p157 s5
sti i154 p157 - 0 0
call count 1 f158 1 p157
ldi i154 p157 - 0 0
sa p159 s6
stf f156 p159 - 0 0
stf f158 p159 - 0 8
la p160 d4
rcall sea_printf 0:27 0 2 p160 p159
li i161 1
mov i162 i161
sa p163 s7
sti i161 p163 - 0 0
call grow 1 i164 1 p163
ldi i161 p163 - 0 0
li i165 2
li i166 1
li i167 1
rcall sea_arr_new_u 0:29 1 p168 4 i165 i166 i164 i167
ldp p169 p168 - 0 40
li i170 0
icmp gt i171 i164 i170
if 15 i171
li i172 1
isub i173 i164 i172
loop 16 i174 i170 i173 i172
sti i162 p169 i174 8 0
endloop 16
endif 15
li i175 0
ldi i176 p168 - 0 16
chkb i175 i176 0 0:30
ldp p177 p168 - 0 40
ldi i178 p177 i175 8 0
ldi i179 p168 - 0 16
sa p180 s8
sti i178 p180 - 0 0
sti i179 p180 - 0 8
sti i161 p180 - 0 16
la p181 d5
rcall sea_printf 0:30 0 2 p181 p180
li i182 2
icmp gt i183 i161 i182
if 17 i183
li i184 2
else 17
li i184 3
endif 17
li i185 1
li i186 1
li i187 1
rcall sea_arr_new_u 0:32 1 p188 4 i185 i186 i184 i187
lf f189 #3FF0000000000000
ldp p190 p188 - 0 40
li i191 0
icmp gt i192 i184 i191
if 18 i192
li i193 1
isub i194 i184 i193
loop 19 i195 i191 i194 i193
stf f189 p190 i195 8 0
endloop 19
endif 18
li i196 1
li i197 3
icmp eq i198 i161 i197
mov i199 i196
if 20 i199
mov i199 i198
endif 20
li i200 3
li i201 1
li i202 1
rcall sea_arr_new_u 0:35 1 p203 4 i200 i201 i154 i202
ldp p204 p203 - 0 40
li i205 0
icmp gt i206 i154 i205
if 21 i206
li i207 1
isub i208 i154 i207
loop 22 i209 i205 i208 i207
stb i199 p204 i209 1 0
endloop 22
endif 21
li i210 1
ldi i211 p188 - 0 16
chkb i210 i211 0 0:36
ldp p212 p188 - 0 40
ldf f213 p212 i210 8 0
ldi i214 p188 - 0 16
li i215 3
ldi i216 p203 - 0 16
chkb i215 i216 0 0:36
ldp p217 p203 - 0 40
ldb i218 p217 i215 1 0
sa p219 s9
sti i154 p219 - 0 0
call grow 1 i220 1 p219
ldi i154 p219 - 0 0
sa p221 s10
stf f213 p221 - 0 0
sti i214 p221 - 0 8
sti i218 p221 - 0 16
sti i220 p221 - 0 24
la p222 d6
rcall sea_printf 0:36 0 2 p222 p221
release p203
release p188
release p168
release p134
release p121
release p83
release p70
release p57
release p30
release p18
release p6
ret 0
endfunc
func grow fn 0:1:1 1 p1 1 i
li i2 0
li i3 2
li i4 1
rcount i5 i6 i2 i3 i4 0 0:2
if 1 i6
loop 2 i7 i2 i5 i4
ldi i8 p1 - 0 0
li i9 1
iaddc i10 i8 i9 0:3
sti i10 p1 - 0 0
endloop 2
endif 1
ldi i11 p1 - 0 0
ret 1 i11
endfunc
func count fn 0:7:1 1 p1 1 f
lf f2 #3FE0000000000000
ldi i3 p1 - 0 0
li i4 1
li i5 1
li i6 1
rcall sea_arr_new_u 0:8 1 p7 4 i4 i5 i3 i6
ldp p8 p7 - 0 40
li i9 0
icmp gt i10 i3 i9
if 1 i10
li i11 1
isub i12 i3 i11
loop 2 i13 i9 i12 i11
stf f2 p8 i13 8 0
endloop 2
endif 1
lf f14 #0000000000000000
mov p15 p7
retain p15
ldi i16 p15 - 0 16
li i17 0
icmp gt i18 i16 i17
if 3 i18
ldp p19 p15 - 0 40
li i20 1
isub i21 i16 i20
loop 4 i22 i17 i21 i20
ldf f23 p19 i22 8 0
fadd f14 f14 f23
endloop 4
endif 3
release p15
release p7
ret 1 f14
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
fmt d2 6
fconv - - - g f
ftext %20
fconv - - - d i
ftext %20
fconv - - - d i
ftext %0A
fmt d3 6
fconv - - - g f
ftext %20
fconv - - - g f
ftext %20
fconv - - - d i
ftext %0A
fmt d4 4
fconv - - - g f
ftext %20
fconv - - - g f
ftext %0A
fmt d5 6
fconv - - - d i
ftext %20
fconv - - - d i
ftext %20
fconv - - - d i
ftext %0A
fmt d6 8
fconv - - - g f
ftext %20
fconv - - - d i
ftext %20
fconv - - - d i
ftext %20
fconv - - - d i
ftext %0A
'''

# loop_ext, .main:
#   l.8, l.9 zeros: arrnewz; l.10 ones(4, 1): arrnew, `imul`, V, data, loop blocks 1/2.
#   l.11 len(v), numel(v) of a vector, rows(m1), cols(m1): one `ldi` each (ext 0 at 16, ext 1 at
#     24); numel(m1): L3's xblk, its tmp an alias of m1 (T1): `ldi`, `ldi`, `imul` (r17).
#   l.12 `var m = m2`: r2 `mov`, r15 (a) `retain`.
#   l.13 shape(ref m, v) and shape(ref m, zeros(0)): r31 slot/`stp`/reload; the zeros temporary is
#     released right after the call that consumes it (r15 (b)), after the call's reload.
#   l.14 len(ones(4)): the xblk's value (moved out, T2) is consumed by ext, then released (r15 (k));
#     numel(zeros(2, 3)): xblk with tmp A = the anew (owned): the value's `imul`, then A released
#     right after the xblk's value (T2).
#   l.15 rows(zeros(2, 3)) and cols(ones(1, 7)): ext of an owned operand, then its release.
#   l.16 `let c = rows(m1) > 2`; l.17 numel(ifx): the ifx computed into its own register p93 by r3
#     (each arm `mov`, `retain`; block 7), the xblk's temporary, released after the `imul`.
#   the end of the body block: m, m2, m1, v released (r16 (a)).
# shape: A is a ref parameter of type f64[,]: each use is `ldp` of its value (r12, r31; borrowed,
#   never released): rows(A), cols(A) one load each, numel(A) one load (the xblk's tmp, T1) for
#   both extents; the i64 `* +` are `imulc`/`iaddc` with site 0:4; `t +=` (r2).
LIR1['loop_ext'] = '''
func .main main 0:1:1 0 0
slot s1 40 8
slot s2 8 8
slot s3 8 8
slot s4 16 8
slot s5 16 8
slot s6 16 8
slot s7 8 8
li i1 5
li i2 1
li i3 1
li i4 1
rcall sea_arr_new 0:8 1 p5 4 i2 i3 i1 i4
li i6 2
li i7 3
li i8 1
li i9 2
rcall sea_arr_new 0:9 1 p10 4 i8 i9 i6 i7
li i11 4
li i12 1
li i13 1
li i14 2
rcall sea_arr_new_u 0:10 1 p15 4 i13 i14 i11 i12
imul i16 i11 i12
lf f17 #3FF0000000000000
ldp p18 p15 - 0 40
li i19 0
icmp gt i20 i16 i19
if 1 i20
li i21 1
isub i22 i16 i21
loop 2 i23 i19 i22 i21
stf f17 p18 i23 8 0
endloop 2
endif 1
ldi i24 p5 - 0 16
ldi i25 p5 - 0 16
ldi i26 p10 - 0 16
ldi i27 p10 - 0 24
ldi i28 p10 - 0 16
ldi i29 p10 - 0 24
imul i30 i28 i29
sa p31 s1
sti i24 p31 - 0 0
sti i25 p31 - 0 8
sti i26 p31 - 0 16
sti i27 p31 - 0 24
sti i30 p31 - 0 32
la p32 d1
rcall sea_printf 0:11 0 2 p32 p31
mov p33 p15
retain p33
sa p34 s2
stp p33 p34 - 0 0
call shape 1 i35 2 p34 p5
ldp p33 p34 - 0 0
sa p36 s3
stp p33 p36 - 0 0
li i37 0
li i38 1
li i39 1
li i40 1
rcall sea_arr_new 0:13 1 p41 4 i38 i39 i37 i40
call shape 1 i42 2 p36 p41
ldp p33 p36 - 0 0
release p41
sa p43 s4
sti i35 p43 - 0 0
sti i42 p43 - 0 8
la p44 d2
rcall sea_printf 0:13 0 2 p44 p43
li i45 4
li i46 1
li i47 1
li i48 1
rcall sea_arr_new_u 0:14 1 p49 4 i46 i47 i45 i48
lf f50 #3FF0000000000000
ldp p51 p49 - 0 40
li i52 0
icmp gt i53 i45 i52
if 3 i53
li i54 1
isub i55 i45 i54
loop 4 i56 i52 i55 i54
stf f50 p51 i56 8 0
endloop 4
endif 3
ldi i57 p49 - 0 16
release p49
li i58 2
li i59 3
li i60 1
li i61 2
rcall sea_arr_new 0:14 1 p62 4 i60 i61 i58 i59
ldi i63 p62 - 0 16
ldi i64 p62 - 0 24
imul i65 i63 i64
release p62
sa p66 s5
sti i57 p66 - 0 0
sti i65 p66 - 0 8
la p67 d3
rcall sea_printf 0:14 0 2 p67 p66
li i68 2
li i69 3
li i70 1
li i71 2
rcall sea_arr_new 0:15 1 p72 4 i70 i71 i68 i69
ldi i73 p72 - 0 16
release p72
li i74 1
li i75 7
li i76 1
li i77 2
rcall sea_arr_new_u 0:15 1 p78 4 i76 i77 i74 i75
imul i79 i74 i75
lf f80 #3FF0000000000000
ldp p81 p78 - 0 40
li i82 0
icmp gt i83 i79 i82
if 5 i83
li i84 1
isub i85 i79 i84
loop 6 i86 i82 i85 i84
stf f80 p81 i86 8 0
endloop 6
endif 5
ldi i87 p78 - 0 24
release p78
sa p88 s6
sti i73 p88 - 0 0
sti i87 p88 - 0 8
la p89 d4
rcall sea_printf 0:15 0 2 p89 p88
ldi i90 p10 - 0 16
li i91 2
icmp gt i92 i90 i91
if 7 i92
mov p93 p10
retain p93
else 7
mov p93 p15
retain p93
endif 7
ldi i94 p93 - 0 16
ldi i95 p93 - 0 24
imul i96 i94 i95
release p93
sa p97 s7
sti i96 p97 - 0 0
la p98 d5
rcall sea_printf 0:17 0 2 p98 p97
release p33
release p15
release p10
release p5
ret 0
endfunc
func shape fn 0:1:1 2 p1 p2 1 i
li i3 0
li i4 0
li i5 2
li i6 1
rcount i7 i8 i4 i5 i6 0 0:3
if 1 i8
loop 2 i9 i4 i7 i6
ldp p10 p1 - 0 0
ldi i11 p10 - 0 16
ldp p12 p1 - 0 0
ldi i13 p12 - 0 24
imulc i14 i11 i13 0:4
ldi i15 p2 - 0 16
iaddc i16 i14 i15 0:4
ldi i17 p2 - 0 16
iaddc i18 i16 i17 0:4
ldp p19 p1 - 0 0
ldi i20 p19 - 0 16
ldi i21 p19 - 0 24
imul i22 i20 i21
iaddc i23 i18 i22 0:4
iaddc i3 i3 i23 0:4
endloop 2
endif 1
ret 1 i3
endfunc
fmt d1 10
fconv - - - d i
ftext %20
fconv - - - d i
ftext %20
fconv - - - d i
ftext %20
fconv - - - d i
ftext %20
fconv - - - d i
ftext %0A
fmt d2 4
fconv - - - d i
ftext %20
fconv - - - d i
ftext %0A
fmt d3 4
fconv - - - d i
ftext %20
fconv - - - d i
ftext %0A
fmt d4 4
fconv - - - d i
ftext %20
fconv - - - d i
ftext %0A
fmt d5 2
fconv - - - d i
ftext %0A
'''

# ================================================================ the new dump tests: .out
# From LANGUAGE.md (7.5 element loops: the vector evaluated once, x a copy of each element in index
# order, break/continue of the innermost loop; 8.3 ref; 6.10 if expressions; 10.2 constructors and
# shapes; 11.1 printf %d of a bool prints 0 or 1, %g of an integral f64 prints no point).
# loop_fore_exits: a = [2, -1, 9, 2] (filled(2.0, 4), then a[1] = -1.0, a[2] = 9.0), b = [0, 0].
#   where_is(a, 9.0) = 2 (the return at the third element); where_is(b, 1.0) = -1.
#   sumto(ref a, 5.0): 2, -1 skipped by continue, 9 > 5 breaks: 2; sumto(ref a, 10.0): 2 + 9 + 2
#   = 13 (exact).
#   pairs(a, a): pairs x < y: x=2: {9}; x=-1: {2, 9, 2}; x=9: none; x=2: {9}: 5. pairs(b, a): each
#   0 is below 2, 9, 2: 6.
#   n: 1 + 1 + 1 over ones(3) = 3; c = len(a) > 3 is true, so the loop runs over b: n += 0 + 1
#   twice: 5.
# loop_fill: l.18 vf[2] 2.5, vi[1] 4, vb[0] true (1), len(vb) 2; l.22 mf[1, 2] 0.25, mi[2, 0] -7,
#   mb[0, 1] false (0); l.25 mo[1, 1] 1, mz[2, 1] 0, rows(mz) 3; l.27 count(ref m) with m = 4:
#   0.5 * 4 = 2 (exact), twice; l.29 k = 1: filled's v is evaluated first (1), then grow(ref k)
#   adds 1 twice and returns k = 3: vk = [1, 1, 1]; l.30: 1 3 3; l.31 c = 3 > 2 true, vc =
#   ones(2); q = k == 3 true, vq = filled(true, 4); l.36 vc[1] 1, len(vc) 2, vq[3] 1, grow(ref m)
#   6 (m is still 4: count does not assign n).
# loop_ext: v 5 elements, m1 2 x 3, m2 4 x 1. l.11: 5 5 2 3 6. l.13 m = m2: shape adds, twice,
#   rows * cols + len(v) + numel(v) + numel(A) = 4 + 5 + 5 + 4 = 18, so 36; with zeros(0):
#   4 + 0 + 0 + 4 = 8, so 16. l.14: len(ones(4)) 4, numel(zeros(2, 3)) 6. l.15: rows 2, cols 7.
#   l.16 c = rows(m1) > 2 is false: numel(m2) = 4.
OUT = {
    'loop_fore_exits': '2 -1\n2 13\n5 6\n5\n',
    'loop_fill': '2.5 4 1 2\n0.25 -7 0\n1 0 3\n2 2\n1 3 3\n1 2 1 6\n',
    'loop_ext': '5 5 2 3 6\n36 16\n4 6\n2 7\n4\n',
}

# the positions of the .ast against the source text (as dump4d_cases.check_positions does)
KW = {'let': 'let', 'var': 'var', 'if': 'if', 'while': 'while', 'for': 'for', 'return': 'return',
      'block': '{', 'str': '"', 'break': 'break', 'continue': 'continue', 'ref': 'ref',
      'dollar': '$', 'ifx': 'if', 'true': 'true', 'false': 'false', 'neg': '-'}


def check_positions(name, src, recs):
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
            at(pos, p[2])
        elif op == 'float':
            assert src_lines[int(pos.split(':')[1]) - 1][int(pos.split(':')[2]) - 1].isdigit(), r
        elif op in ('call', 'index', 'bin', 'asg', 'cstmt', 'un', 'and', 'or'):
            assert src_lines[int(pos.split(':')[1]) - 1][int(pos.split(':')[2]) - 1] != ' ', r
        if op == 'for':
            at(p[3], p[2])


for nm in NEW:
    check_positions(nm, SEA[nm], lines(AST[nm]))
    write(nm + '.sea', SEA[nm])
    write(nm + '.ast', dump(nm, AST[nm]))
    write(nm + '.hir1', dump(nm, HIR1[nm]))
    write(nm + '.hir', dump(nm, HIR[nm]))
    write(nm + '.hirl', dump(nm, HIRL_NEW[nm]))
    write(nm + '.lir1', dump(nm, LIR1[nm]))
    write(nm + '.out', OUT[nm])
    res_gen.make(nm)
# ================================================================ the self-check
# Every .hirl and .lir1 this script writes is read back and checked against include/passes.txt
# (record sets H HF HL for .hirl, L for .lir1: fields, field types, enumeration words, counts) and
# against the rules of DESIGN.md 3.3 (post-order trees), 3.5.1 and 3.5.9 (types, locals,
# positions, the validation list of "What the passes validate"), and for .lir1 the numbering of
# 3.6.1 (registers), 3.6.2 (labels) and 3.6.3 (slots). This is a check of the hand-written files,
# not a derivation of them.

NOT_NODES = {'tvec', 'tmat', 'tfvec', 'tfmat', 'tstruct', 'trec', 'ttuple', 'tptr', 'fd', 'inst',
             'fn', 'par', 'loc'}                                   # DESIGN.md 3.3
REWRITTEN_LIB = {'zeros', 'ones', 'filled', 'len', 'rows', 'cols', 'numel'}   # 3.5.9
FROM_4E = {'chkb', 'chk', 'rcnt', 'cow', 'mcpy', 'cdat'}           # codes 82-87, not in 4e-0
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
                    name, typ = f.split(':')
                    cnt = None
                    if '*' in typ:
                        typ, cnt = typ.split('*')
                    opt = typ.endswith('?')
                    fields.append((name, typ.rstrip('?'), opt, cnt))
                recs[(p[1], p[3])] = (p[4], fields)
    return recs, enums


RECS, ENUMS = load_formats()
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
    """Checks one body record against passes.txt; returns (op, {field: value or list})."""
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
    lines = text.split('\n')
    assert lines[-1] == '' and lines[-2] == '#end', (name, 'no #end')
    head = lines[:3]
    assert head == ['#sea 1', '#target arm64-macos', '#file %s.sea' % name], (name, head)
    body = lines[3:-2]
    for ln in body:
        assert ln and ' ' not in (ln[0], ln[-1]) and '  ' not in ln, (name, ln)
        for m in re.finditer(r'\b0:([0-9]+):([0-9]+)\b', ln):
            assert int(m.group(1)) <= len(src_lines), (name, ln)
    return body


class Node:
    def __init__(self, op, v, kids, idx):
        self.op, self.v, self.kids, self.idx = op, v, kids, idx


def check_hirl(name):
    """DESIGN.md 3.5.9 "What the passes validate" (sealower's list) and 3.5.4/3.5.9 numbering."""
    text = read(name + '.hirl')
    src = read(name + '.sea').split('\n')
    hir = read(name + '.hir')
    body = split_file(name, text, src)
    assert text.split('\n')[:3] == hir.split('\n')[:3], (name, 'header not copied (3.2)')
    # the type table: sea.hir's, then the tptr types (3.5.9 "Types")
    hir_types = [ln for ln in hir.split('\n')[3:] if ln.split(' ')[0] in TYPE_RECS or
                 ln.split(' ')[0] == 'fd']
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
        if op in ('tvec', 'tmat', 'tfvec', 'tfmat'):
            types[int(v['id'])] = ({'tvec': 'v', 'tmat': 'm', 'tfvec': 'fv', 'tfmat': 'fm'}[op],
                                   int(v['elt']))
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
        k = types[t][0]
        return {'v': 1, 'fv': 1, 'm': 2, 'fm': 2}.get(k, 0)

    def is_arr(t):
        return types[t][0] in ('v', 'm', 'fv', 'fm')

    first_ref = []
    stack, fn, out_fns = [], None, []
    for k, ln in enumerate(rest):
        op, v, pops = parse_rec(name, 'H HF HL'.split(), ln)
        assert op not in FROM_4E, (name, 'record of 4e in 4e-0', ln)
        assert op != 'fore', (name, 'fore in sea.hirl', ln)
        assert not (op == 'lib' and v['name'] in REWRITTEN_LIB), (name, 'rewritten lib', ln)
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
            fn = {'np': int(v['np']), 'nl': int(v['nl']), 'locs': [], 'nodes': []}
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
        fn['nodes'].append(node)
        if op == 'end':
            assert not stack and kids[0].op == 'block', (name, 'end', ln)
            fn['body'] = kids[0]
            continue
        stack.append(node)
    assert not stack, name
    assert first_ref == tptrs, (name, 'tptr ids not in order of first reference', first_ref, tptrs)

    for fn in out_fns:
        locs = fn['locs']
        assert len(locs) == fn['np'] + fn['nl'], (name, 'np/nl')
        lnames = [x[0] for x in locs]
        ls = [j for j, x in enumerate(lnames) if x.startswith('.l')]
        if ls:
            assert ls == list(range(ls[0], len(locs))), (name, '.l locals last (3.5.4)')
            assert [lnames[j] for j in ls] == ['.l%d' % (q + 1) for q in range(len(ls))], name
        lt = {j + 1: x[1] for j, x in enumerate(locs)}

        def ty_of(n):
            if n.op == 'lv':
                assert int(n.v['ty']) == lt[int(n.v['lid'])], (name, 'lv type', n.v)
            return int(n.v['ty']) if 'ty' in n.v and n.v['ty'] != '-' else None

        tmp_bound, decl = {}, []
        assigned = set()
        for n in fn['nodes']:
            t = ty_of(n)
            if n.op == 'tmp':
                L = int(n.v['lid'])
                assert L not in tmp_bound, (name, 'tmp bound twice', L)
                tmp_bound[L] = n.idx
                assert lt[L] == ty_of(n.kids[0]), (name, 'tmp type != child type', n.v)
                if types.get(lt[L], ('',))[0] == 'ptr':
                    assert n.kids[0].op in ('adat', 'cdat'), (name, 'tptr tmp', n.v)
                decl.append((L, 'let', n.v['pos']))
            elif n.op == 'bind' and lnames[int(n.v['lid']) - 1].startswith('.l'):
                decl.append((int(n.v['lid']), 'let', n.v['pos']))
            elif n.op == 'hloop':
                K = int(n.v['lid'])
                assert locs[K - 1][2] == 'for' and lt[K] == 3, (name, 'hloop local', n.v)
                assert [ty_of(c) for c in n.kids[:3]] == [3, 3, 3], (name, 'hloop range')
                assert n.kids[3].op == 'block', name
                decl.append((K, 'for', n.v['pos']))
            elif n.op == 'ext':
                a = ty_of(n.kids[0])
                assert t == 3 and (is_arr(a) or a == 5), (name, 'ext', n.v)
                assert int(n.v['dim']) < max(rank(a), 1), (name, 'ext dim', n.v)
            elif n.op == 'adat':
                a = ty_of(n.kids[0])
                assert is_arr(a) and types[t] == ('ptr', types[a][1]), (name, 'adat', n.v)
            elif n.op == 'eld':
                d = ty_of(n.kids[0])
                assert types[d] == ('ptr', t) and ty_of(n.kids[1]) == 3, (name, 'eld', n.v)
            elif n.op == 'est':
                d = ty_of(n.kids[1])
                assert types[d] == ('ptr', ty_of(n.kids[0])), (name, 'est', n.v)
                assert ty_of(n.kids[2]) == 3, (name, 'est index')
            elif n.op == 'anew':
                assert is_arr(t) and rank(t) == int(n.v['r']), (name, 'anew', n.v)
                assert all(ty_of(c) == 3 for c in n.kids), (name, 'anew extents')
            elif n.op == 'wbin':
                assert t == 3 and [ty_of(c) for c in n.kids] == [3, 3], (name, 'wbin', n.v)
            elif n.op == 'xblk':
                assert t == ty_of(n.kids[-1]), (name, 'xblk type', n.v)
            if n.op in ('bind', 'asg', 'tasg', 'rarg', 'forr', 'tbind'):
                if n.op in ('bind', 'forr'):
                    assigned.add(int(n.v['lid']))
                elif n.op == 'tbind':
                    assigned.update(int(x) for x in n.v['lid'] if x != '-')
                elif n.kids and n.kids[0].op == 'lv':
                    assigned.add(int(n.kids[0].v['lid']))
        for n in fn['nodes']:
            if n.op == 'lv' and int(n.v['lid']) in tmp_bound:
                assert tmp_bound[int(n.v['lid'])] < n.idx, (name, 'lv before its tmp', n.v)
        assert not (assigned & set(tmp_bound)), (name, 'a tmp local is assigned')
        # the .l locals: numbered in the order of their declaring records, loc mut and pos (3.5.9)
        ldecl = [d for d in decl if lnames[d[0] - 1].startswith('.l')]
        assert [d[0] for d in ldecl] == [j + 1 for j in ls], (name, '.l order', ldecl, ls)
        for L, mut, pos in ldecl:
            assert locs[L - 1][2] == mut and locs[L - 1][3] == pos, (name, '.l loc', L)

        # a bind of a .l local only as the first statement of a block (L4)
        def walk(n):
            for j, c in enumerate(n.kids):
                if c.op == 'bind' and lnames[int(c.v['lid']) - 1].startswith('.l'):
                    assert n.op == 'block' and j == 0, (name, '.l bind not first in a block')
                walk(c)
        walk(fn['body'])
    return len(body)


def check_lir1(name):
    """passes.txt set L, registers (3.6.1), labels (3.6.2) and slots (3.6.3) numbered in order."""
    text = read(name + '.lir1')
    body = split_file(name, text, read(name + '.sea').split('\n'))
    labels, nlab = [], 0
    infunc = False
    for ln in body:
        op, v, _ = parse_rec(name, ['L'], ln)
        if op == 'func':
            infunc, seen, slots, nslot = True, 0, [], 0
            regs = set()
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
        if op == 'endfunc':
            assert len(slots) == nslot, (name, 'slots', nslot, slots)
            infunc = False
        if op in ('str', 'fmt', 'dat', 'slay'):
            nlab += 1
            assert v['lab'] == 'd%d' % nlab, (name, 'data record order', ln)
    assert nlab == len(labels), (name, 'labels')
    return len(body)


# ================================================================ run the self-check
NAMES = COPIES + sorted(HIRL) + NEW
nrec = 0
for nm in NAMES:
    nrec += check_hirl(nm)
    assert os.path.exists(os.path.join(PASSES, nm + '.lir1')), nm
for nm in NEW:
    nrec += check_lir1(nm)
for nm in COPIES:
    assert read(nm + '.hirl') == read(nm + '.hir'), nm
print('hirl4e0_cases: %d .hirl (%d copies), %d new dump tests, %d records checked'
      % (len(NAMES), len(COPIES), len(NEW), nrec))
