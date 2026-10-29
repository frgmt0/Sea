"""Sub-phase 6c dump goldens, package T2 (DESIGN.md 6.2 "Phase-6 tests": "6c, elemental functions"
(the `elem6_*` dumps) and the T2 item of "Existing tests that phase 6 changes"; 2.11.2's phase
rule, 2.11.3 `seaname`/`seacheck`/`seaexpand`, 2.11.4 L19 and L20, 3.5.3 the `inst` record, 3.5.7
step 3, 3.5.9; Decisions 84 and 92; lead decisions L-ck, L-cf, L-cg).

Run with `timeout 120 uv run --no-project python tests/vectors/dump6c_cases.py [--out DIR]
[--check]`. It writes in tests/passes/ (or DIR); with --check it writes nothing and only checks that
every file it owns is what it would write. (res6_class.res, whose rerr 259 `elemental functions`
6c removes, stays with dump6_cases.py, which writes it with res_gen6's 6c edit.)

Part 1, res_err_elemental (.sea .res): from 6c the `elemental fn` item is accepted (2.11.2's table:
`elemental functions` is no longer reported), so the .res has no rerr and keeps rfn's el 1
(3.4.1); the .sea's header comment says so (two lines, as before, so the .ast is unchanged).

Part 2, the elem6_* sources and the front-end goldens:
* elem6_vec: f(x, k) of a vector and a scalar (an emap of instance 1, k = 1) and of two scalars (an
  ordinary call, inlined by L20); .sea .ast .res .hir1 .hir .hirl .lir1 .out.
* elem6_k5: g(x) of five results applied to a vector under a tbind with two `_`, a tasg with
  three `skip`, and an eval (every result discarded): L19's statement forms for k = 5; .sea .ast
  .res .hir1 .hir .hirl .out.
* elem6_inst: pass 2b's step 3 for h(x, y, s): four instances numbered by first use, an `i64[]`
  argument converted to `f64[]` sharing instance 1, a matrix with a `.col` view, a fixed-size
  vector with a scalar (fixed-size result) and with a dynamic vector (dynamic result), the uniform
  `str` argument, a scalar call kept, the unreachable elemental function dropped, the instances'
  types numbered first (3.5.1, 3.5 "the body has up to four parts"); .sea .ast .res .hir1 .hir .out.
The .ast by hand from 3.4 (pass 1 is unchanged in 6c: row 6c of DESIGN 8 lists no seaparse work),
its positions checked against the source; the .res by res_gen6 (the spec oracle res_gen.py with
the 6b edits and 6c's, dump6_cases.py) with el 1 for the elemental functions (2.11.3); the .hir1 by
hand from 3.5.4-3.5.5 and 2.11.2's "Elemental calls" (kind `elem`; a call with an array argument
of an elemental parameter typed as the broadcast array, LANGUAGE.md 6.3; an `i64[]` argument of an
`f64` parameter under a `cvt` of the `f64` array type); the .hir from the .hir1 by 3.5.7: no
constant (step 1), nothing to fold (step 2: no `f64` operation of two constants), step 3 (each
`call` of an elemental function with an array argument becomes `emap P ty iid n`, the instance
for its argument types, 3.5.3), no `write_json` (step 4), step 5 (reachability through `call`
and `emap` instances; functions renumbered), and the type table renumbered by 3.5.1 with the
`inst` records first.

Part 3, the .hirl (3.5.9): .main of elem6_vec and elem6_k5 written by the model below, a direct
transcription of L19 (2.11.4), L20 (L18 with L20's differences), L1, L3 and the loop shorthand
loop(N; K) of 4e-0, every local numbered by 3.5.9 "Locals" (file order of the declaring records)
and every type by 3.5.9 "Types" (`tptr` appended). The elemental functions are dropped (L20, L-cg).

Part 4, elem6_vec.lir1: by hand from 3.6.6 ("Lowering of the sea.hirl records", T1-T3, rules
1, 2, 15, 16, 17, 18, 8, 37 and R26-R29), instruction by instruction, each derivation beside it.

Never derived by running a pass: the 6c passes are written concurrently. The committed passes serve
only as cross-checks where 6c does not change them (pass 1 for every .ast; sealower, whose 6c
change is validation only, for the .lir1 of the .hirl).
"""

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import dump6_cases as d6  # noqa: E402  (shares --out/--check, write, res_gen6, gen_res, CLASS)

CHECK = d6.CHECK
write = d6.write
read = d6.read


def dump(name, body):
    """A dump file: the three header records, the body lines (blank lines dropped), #end."""
    return ('#sea 1\n#target arm64-macos\n#file %s.sea\n' % name
            + '\n'.join(ln for ln in body.strip('\n').split('\n') if ln.strip()) + '\n#end\n')


# ================================================================ part 1: res_err_elemental
RES_ERR_ELEMENTAL_SEA = """// res_err_elemental -- from sub-phase 6c an elemental fn item is accepted: no rerr (6b reported
// 259 elemental functions at the item); rfn el 1 (DESIGN.md 3.4.1, 2.11.2, 2.11.3)
elemental fn sq(x: f64) -> f64 {
    return x * x
}
"""
# its .ast (unchanged since 4a: lines 3-5 keep their text; checked against the committed golden)
RES_ERR_ELEMENTAL_AST = """
type 0:3:20 f64 s 0
param 0:3:17 x 0 0
type 0:3:28 f64 s 0
name 0:4:12 x
name 0:4:16 x
bin 0:4:12 mul
return 0:4:5 1
block 0:3:32 1
fn 0:3:1 sq 1 1 1
prog 1
"""
# the .res by hand (3.4.1): the 6b golden without its rerr line; rfn el 1 (an elemental function)
RES_ERR_ELEMENTAL_RES = """
rtype 0:3:20 f64 s 0 4
param 0:3:17 x 0 0
rtype 0:3:28 f64 s 0 4
rname 0:4:12 x loc 1
rname 0:4:16 x loc 1
bin 0:4:12 mul
return 0:4:5 1
block 0:3:32 1
rfn 0:3:1 sq 1 1 1 2 4 4
prog 1
"""


def part1(rg):
    name = 'res_err_elemental'
    ast = dump(name, RES_ERR_ELEMENTAL_AST)
    assert read(os.path.join(d6.SRC_PASSES, name + '.ast')) == ast, 'the .ast must not change'
    d6.check_ast_positions(name, RES_ERR_ELEMENTAL_SEA, ast)
    d6.CLASS[name] = [('sq', 1, '(a) elemental')]
    res = d6.gen_res(rg, name, ast)
    assert res == dump(name, RES_ERR_ELEMENTAL_RES), res
    write(name + '.sea', RES_ERR_ELEMENTAL_SEA)
    write(name + '.res', res)
    return 2


# ================================================================ part 2: elem6_* front end
ELEM6_VEC_SEA = """// elem6_vec -- elemental functions (DESIGN.md 2.11, 3.5.7 step 3, 3.5.9 L19 and L20): f of a
// vector and a scalar is an emap of instance 1 (k = 1: one result array, the inline call in the
// loop body stored by est), f of two scalars an ordinary call that L20 inlines; f is dropped
elemental fn f(x: f64, k: f64) -> f64 {
    return x * k + 1.0
}
let v = zeros(3)
let w = f(v, 2.0)
let s = f(0.5, 4.0)
printf("%g %g\\n", w[2], s)
"""
# v = [0, 0, 0]; w = v * 2 + 1 element by element = [1, 1, 1]; s = 0.5 * 4 + 1 = 3 (LANGUAGE.md
# 8.5, 6.5); printf %g (10.9)
ELEM6_VEC_OUT = '1 3\n'

ELEM6_VEC_AST = """
type 0:4:19 f64 s 0
param 0:4:16 x 0 0
type 0:4:27 f64 s 0
param 0:4:24 k 0 0
type 0:4:35 f64 s 0
name 0:5:12 x
name 0:5:16 k
bin 0:5:12 mul
float 0:5:20 #3FF0000000000000
bin 0:5:12 add
return 0:5:5 1
block 0:4:39 1
fn 0:4:1 f 1 2 1
pname 0:7:5 v
name 0:7:9 zeros
int 0:7:15 3
call 0:7:9 1
let 0:7:1 0
pname 0:8:5 w
name 0:8:9 f
name 0:8:11 v
float 0:8:14 #4000000000000000
call 0:8:9 2
let 0:8:1 0
pname 0:9:5 s
name 0:9:9 f
float 0:9:11 #3FE0000000000000
float 0:9:16 #4010000000000000
call 0:9:9 2
let 0:9:1 0
name 0:10:1 printf
str 0:10:8 %25g%20%25g%0A
name 0:10:19 w
int 0:10:21 2
index 0:10:19 1
name 0:10:25 s
call 0:10:1 3
cstmt 0:10:1
prog 5
"""

# .hir1 (3.5.4, 3.5.5): f has kind elem (2.11.3); v is f64[] (zeros, type 10, the first type
# referred to after the table, by `loc v`); f(v, 2.0) has an array argument of an elemental
# parameter, so it is typed as the broadcast shape, the f64[] of v (2.11.2 "Elemental calls"),
# and written as a call; f(0.5, 4.0) is an ordinary call of type f64.
ELEM6_VEC_HIR1 = """
tvec 10 4
fn 1 .main main 1 0 3 0:1:1
loc v 10 let 0:7:5
loc w 10 let 0:8:5
loc s 4 let 0:9:5
ci 0:7:15 3 3
lib 0:7:9 10 zeros 1
bind 0:7:1 1
lv 0:8:11 10 1
cf 0:8:14 4 #4000000000000000
call 0:8:9 10 2 2
bind 0:8:1 2
cf 0:9:11 4 #3FE0000000000000
cf 0:9:16 4 #4010000000000000
call 0:9:9 4 2 2
bind 0:9:1 3
lv 0:10:19 10 2
ci 0:10:21 3 2
idx 0:10:19 4 1
fconv 0:10:8 1 - - - g
ftext 0:10:8 1 %20
lv 0:10:25 4 3
fconv 0:10:8 1 - - - g
ftext 0:10:8 1 %0A
fmt 0:10:8 1 4
lib 0:10:1 1 printf 1
eval 0:10:1
block 0:1:1 4
end
fn 2 f elem 4 2 0 0:4:1
par x 4 val
par k 4 val
lv 0:5:12 4 1
lv 0:5:16 4 2
bin 0:5:12 4 mul
cf 0:5:20 4 #3FF0000000000000
bin 0:5:12 4 add
ret 0:5:5 1
block 0:4:39 1
end
"""
# .hir (3.5.7): step 3 makes the array call an emap of instance 1 (f, rty f64[] = 10, the
# argument types f64[] and f64); the instance part stands between the type table and the
# functions (3.5); its rty is the first type referred to, f64[] again 10; f stays (reached by the
# scalar call and by instance 1), fid 2.
ELEM6_VEC_HIR_EDITS = [
    ('tvec 10 4\n', 'tvec 10 4\ninst 1 2 10 2 10 4\n'),
    ('call 0:8:9 10 2 2\n', 'emap 0:8:9 10 1 2\n'),
]

ELEM6_K5_SEA = """// elem6_k5 -- an elemental function of five results (W1's shape) applied to a vector (DESIGN.md
// 3.5.9 L19 with L11's statement forms for k = 5): a tbind with two results discarded (no array
// allocated for them), a tasg with three discarded, and an eval with every result discarded
elemental fn g(x: f64) -> (f64, f64, f64, f64, f64) {
    return (x, x + 1.0, x + 2.0, x + 3.0, x + 4.0)
}
let v = zeros(2)
let (a, _, c, _, e) = g(v)
var p = zeros(1)
var q = zeros(1)
(p, _, _, q, _) = g(v)
g(v)
printf("%g %g %g %g %g %d %d\\n", a[1], c[1], e[1], p[1], q[1], len(a), len(p))
"""
# v = [0, 0]; a = v, c = v + 2, e = v + 4; p = v (result 1), q = v + 3 (result 4); the eval
# changes nothing; len(a) = len(p) = 2 (p now holds the two-element result)
ELEM6_K5_OUT = '0 2 4 0 3 2 2\n'

ELEM6_K5_AST = """
type 0:4:19 f64 s 0
param 0:4:16 x 0 0
type 0:4:28 f64 s 0
type 0:4:33 f64 s 0
type 0:4:38 f64 s 0
type 0:4:43 f64 s 0
type 0:4:48 f64 s 0
name 0:5:13 x
name 0:5:16 x
float 0:5:20 #3FF0000000000000
bin 0:5:16 add
name 0:5:25 x
float 0:5:29 #4000000000000000
bin 0:5:25 add
name 0:5:34 x
float 0:5:38 #4008000000000000
bin 0:5:34 add
name 0:5:43 x
float 0:5:47 #4010000000000000
bin 0:5:43 add
return 0:5:5 5
block 0:4:53 1
fn 0:4:1 g 1 1 5
pname 0:7:5 v
name 0:7:9 zeros
int 0:7:15 2
call 0:7:9 1
let 0:7:1 0
pname 0:8:6 a
pskip 0:8:9
pname 0:8:12 c
pskip 0:8:15
pname 0:8:18 e
ptuple 0:8:5 5
name 0:8:23 g
name 0:8:25 v
call 0:8:23 1
let 0:8:1 0
pname 0:9:5 p
name 0:9:9 zeros
int 0:9:15 1
call 0:9:9 1
var 0:9:1 0
pname 0:10:5 q
name 0:10:9 zeros
int 0:10:15 1
call 0:10:9 1
var 0:10:1 0
name 0:11:2 p
pskip 0:11:5
pskip 0:11:8
name 0:11:11 q
pskip 0:11:14
name 0:11:19 g
name 0:11:21 v
call 0:11:19 1
tasg 0:11:1 5
name 0:12:1 g
name 0:12:3 v
call 0:12:1 1
cstmt 0:12:1
name 0:13:1 printf
str 0:13:8 %25g%20%25g%20%25g%20%25g%20%25g%20%25d%20%25d%0A
name 0:13:34 a
int 0:13:36 1
index 0:13:34 1
name 0:13:40 c
int 0:13:42 1
index 0:13:40 1
name 0:13:46 e
int 0:13:48 1
index 0:13:46 1
name 0:13:52 p
int 0:13:54 1
index 0:13:52 1
name 0:13:58 q
int 0:13:60 1
index 0:13:58 1
name 0:13:64 len
name 0:13:68 a
call 0:13:64 1
name 0:13:72 len
name 0:13:76 p
call 0:13:72 1
call 0:13:1 8
cstmt 0:13:1
prog 8
"""


def fmt_pieces(pos, convs):
    """The fconv/ftext pieces of a printf whose conversions are convs (each preceded by its
    argument's records), separated by spaces and ended by LF (3.5.5 `fmt`)."""
    out = []
    for i, (arg, conv) in enumerate(convs):
        out.append(arg)
        out.append('fconv %s 1 - - - %s' % (pos, conv))
        out.append('ftext %s 1 %s' % (pos, '%0A' if i == len(convs) - 1 else '%20'))
    return '\n'.join(out) + '\nfmt %s 1 %d' % (pos, 2 * len(convs))


# .hir1: the call g(v) has the tuple of g's result types as arrays of v's shape, the ttuple of
# five f64[] (11, numbered at its first reference, the call in .main, its component f64[] already
# 10); g's own result type, the ttuple of five f64 (12), at its fn record. The tbind keeps `-` for
# a `_`, the tasg `skip` (type 1) and the cv 0 of five equal types; the statement g(v) is an eval.
ELEM6_K5_HIR1 = """
tvec 10 4
ttuple 11 5 10 10 10 10 10
ttuple 12 5 4 4 4 4 4
fn 1 .main main 1 0 6 0:1:1
loc v 10 let 0:7:5
loc a 10 let 0:8:6
loc c 10 let 0:8:12
loc e 10 let 0:8:18
loc p 10 var 0:9:5
loc q 10 var 0:10:5
ci 0:7:15 3 2
lib 0:7:9 10 zeros 1
bind 0:7:1 1
lv 0:8:25 10 1
call 0:8:23 11 2 1
tbind 0:8:1 5 2 - 3 - 4
ci 0:9:15 3 1
lib 0:9:9 10 zeros 1
bind 0:9:1 5
ci 0:10:15 3 1
lib 0:10:9 10 zeros 1
bind 0:10:1 6
lv 0:11:2 10 5
skip 0:11:5 1
skip 0:11:8 1
lv 0:11:11 10 6
skip 0:11:14 1
lv 0:11:21 10 1
call 0:11:19 11 2 1
tasg 0:11:1 5 0 0 0 0 0
lv 0:12:3 10 1
call 0:12:1 11 2 1
eval 0:12:1
""" + fmt_pieces('0:13:8', [
    ('lv 0:13:34 10 2\nci 0:13:36 3 1\nidx 0:13:34 4 1', 'g'),
    ('lv 0:13:40 10 3\nci 0:13:42 3 1\nidx 0:13:40 4 1', 'g'),
    ('lv 0:13:46 10 4\nci 0:13:48 3 1\nidx 0:13:46 4 1', 'g'),
    ('lv 0:13:52 10 5\nci 0:13:54 3 1\nidx 0:13:52 4 1', 'g'),
    ('lv 0:13:58 10 6\nci 0:13:60 3 1\nidx 0:13:58 4 1', 'g'),
    ('lv 0:13:68 10 2\nlib 0:13:64 3 len 1', 'd'),
    ('lv 0:13:76 10 5\nlib 0:13:72 3 len 1', 'd')]) + """
lib 0:13:1 1 printf 1
eval 0:13:1
block 0:1:1 7
end
fn 2 g elem 12 1 0 0:4:1
par x 4 val
lv 0:5:13 4 1
lv 0:5:16 4 1
cf 0:5:20 4 #3FF0000000000000
bin 0:5:16 4 add
lv 0:5:25 4 1
cf 0:5:29 4 #4000000000000000
bin 0:5:25 4 add
lv 0:5:34 4 1
cf 0:5:38 4 #4008000000000000
bin 0:5:34 4 add
lv 0:5:43 4 1
cf 0:5:47 4 #4010000000000000
bin 0:5:43 4 add
ret 0:5:5 5
block 0:4:53 1
end
"""
# .hir: the three calls become emaps of one instance (g with the argument type f64[]: the same
# fid and argument types share it, 3.5.3), rty the ttuple of five f64[]; numbered first, that
# ttuple's component f64[] is 10 and the ttuple 11, as in .hir1, and g's result type stays 12.
ELEM6_K5_HIR_EDITS = [
    ('ttuple 12 5 4 4 4 4 4\n', 'ttuple 12 5 4 4 4 4 4\ninst 1 2 11 1 10\n'),
    ('call 0:8:23 11 2 1\n', 'emap 0:8:23 11 1 1\n'),
    ('call 0:11:19 11 2 1\n', 'emap 0:11:19 11 1 1\n'),
    ('call 0:12:1 11 2 1\n', 'emap 0:12:1 11 1 1\n'),
]

ELEM6_INST_SEA = """// elem6_inst -- pass 2b's step 3 (DESIGN.md 3.5.3, 3.5.7): h's applications with array arguments
// become emaps of four instances, numbered by first use; an i64[] argument converted to f64[]
// shares instance 1; a vector .col with a matrix, a fixed-size vector with a scalar (a fixed-size
// result) and with a dynamic vector (a dynamic result); the uniform str argument unchanged; the
// scalar call stays a call; unused is unreachable and dropped, and the instances' types number
// first in sea.hir's type table
elemental fn h(x: f64, y: f64, s: str) -> f64 {
    return x * y
}
elemental fn unused(x: f64) -> f64 {
    return x
}
let a = filled(2.0, 2)
let k = filled(3, 2)
let m = zeros(2, 3)
let f = [1.5, 2.5]
let r1 = h(a, 2.0, "u")
let r2 = h(k, 2.0, "u")
let r3 = h(m, a.col, "u")
let r4 = h(f, 2.0, "u")
let r5 = h(f, a, "u")
let r6 = h(1.0, 2.0, "u")
printf("%g %g %g %g %g %g\\n", r1[1], r2[1], r3[1, 2], r4[1], r5[0], r6)
"""
# a = [2, 2], k = [3, 3], m the 2 x 3 zeros, f = [1.5, 2.5]: r1 = a * 2 = [4, 4]; r2 = k * 2 (k
# converted) = [6, 6]; r3 = m * a.col broadcast to 2 x 3 (LANGUAGE.md 6.3), all 0; r4 = f * 2 =
# [3, 5]; r5 = f * a = [3, 5]; r6 = 1 * 2 = 2
ELEM6_INST_OUT = '4 6 0 5 3 2\n'

ELEM6_INST_AST = """
type 0:7:19 f64 s 0
param 0:7:16 x 0 0
type 0:7:27 f64 s 0
param 0:7:24 y 0 0
type 0:7:35 str s 0
param 0:7:32 s 0 0
type 0:7:43 f64 s 0
name 0:8:12 x
name 0:8:16 y
bin 0:8:12 mul
return 0:8:5 1
block 0:7:47 1
fn 0:7:1 h 1 3 1
type 0:10:24 f64 s 0
param 0:10:21 x 0 0
type 0:10:32 f64 s 0
name 0:11:12 x
return 0:11:5 1
block 0:10:36 1
fn 0:10:1 unused 1 1 1
pname 0:13:5 a
name 0:13:9 filled
float 0:13:16 #4000000000000000
int 0:13:21 2
call 0:13:9 2
let 0:13:1 0
pname 0:14:5 k
name 0:14:9 filled
int 0:14:16 3
int 0:14:19 2
call 0:14:9 2
let 0:14:1 0
pname 0:15:5 m
name 0:15:9 zeros
int 0:15:15 2
int 0:15:18 3
call 0:15:9 2
let 0:15:1 0
pname 0:16:5 f
float 0:16:10 #3FF8000000000000
float 0:16:15 #4004000000000000
row 0:16:10 2
array 0:16:9 1
let 0:16:1 0
pname 0:17:5 r1
name 0:17:10 h
name 0:17:12 a
float 0:17:15 #4000000000000000
str 0:17:20 u
call 0:17:10 3
let 0:17:1 0
pname 0:18:5 r2
name 0:18:10 h
name 0:18:12 k
float 0:18:15 #4000000000000000
str 0:18:20 u
call 0:18:10 3
let 0:18:1 0
pname 0:19:5 r3
name 0:19:10 h
name 0:19:12 m
name 0:19:15 a
dot 0:19:15 col
str 0:19:22 u
call 0:19:10 3
let 0:19:1 0
pname 0:20:5 r4
name 0:20:10 h
name 0:20:12 f
float 0:20:15 #4000000000000000
str 0:20:20 u
call 0:20:10 3
let 0:20:1 0
pname 0:21:5 r5
name 0:21:10 h
name 0:21:12 f
name 0:21:15 a
str 0:21:18 u
call 0:21:10 3
let 0:21:1 0
pname 0:22:5 r6
name 0:22:10 h
float 0:22:12 #3FF0000000000000
float 0:22:17 #4000000000000000
str 0:22:22 u
call 0:22:10 3
let 0:22:1 0
name 0:23:1 printf
str 0:23:8 %25g%20%25g%20%25g%20%25g%20%25g%20%25g%0A
name 0:23:31 r1
int 0:23:34 1
index 0:23:31 1
name 0:23:38 r2
int 0:23:41 1
index 0:23:38 1
name 0:23:45 r3
int 0:23:48 1
int 0:23:51 2
index 0:23:45 2
name 0:23:55 r4
int 0:23:58 1
index 0:23:55 1
name 0:23:62 r5
int 0:23:65 0
index 0:23:62 1
name 0:23:69 r6
call 0:23:1 7
cstmt 0:23:1
prog 13
"""

# .hir1: types by first reference (the locs of .main): a f64[] 10, k i64[] 11, m f64[,] 12, f
# f64[2] 13 (one row of scalars: a fixed-size vector, LANGUAGE.md 6.9). The applications' types
# (2.11.2 "Elemental calls", LANGUAGE.md 6.3, combined left to right, scalars skipped): (a, 2.0)
# f64[]; (k converted, 2.0) f64[] (the i64[] argument of the f64 parameter x under a cvt of type
# f64[], at the argument's position); (m, a.col) f64[,] (a .col view is a dynamic n x 1 matrix,
# broadcast with 2 x 3); (f, 2.0) the fixed-size f64[2] (every array argument of an elemental
# parameter fixed-size); (f, a) the dynamic f64[] (a is dynamic; no compile-time extents to
# compare, so no 217); (1.0, 2.0) all scalars, an ordinary call of type f64. The uniform str
# argument "u" is a cs of type 5, unchanged. unused is fn 3, kind elem, never called.
ELEM6_INST_HIR1 = """
tvec 10 4
tvec 11 3
tmat 12 4
tfvec 13 4 2
fn 1 .main main 1 0 10 0:1:1
loc a 10 let 0:13:5
loc k 11 let 0:14:5
loc m 12 let 0:15:5
loc f 13 let 0:16:5
loc r1 10 let 0:17:5
loc r2 10 let 0:18:5
loc r3 12 let 0:19:5
loc r4 13 let 0:20:5
loc r5 10 let 0:21:5
loc r6 4 let 0:22:5
cf 0:13:16 4 #4000000000000000
ci 0:13:21 3 2
lib 0:13:9 10 filled 2
bind 0:13:1 1
ci 0:14:16 3 3
ci 0:14:19 3 2
lib 0:14:9 11 filled 2
bind 0:14:1 2
ci 0:15:15 3 2
ci 0:15:18 3 3
lib 0:15:9 12 zeros 2
bind 0:15:1 3
cf 0:16:10 4 #3FF8000000000000
cf 0:16:15 4 #4004000000000000
row 0:16:10 13 2
arr 0:16:9 13 1
bind 0:16:1 4
lv 0:17:12 10 1
cf 0:17:15 4 #4000000000000000
cs 0:17:20 5 u
call 0:17:10 10 2 3
bind 0:17:1 5
lv 0:18:12 11 2
cvt 0:18:12 10
cf 0:18:15 4 #4000000000000000
cs 0:18:20 5 u
call 0:18:10 10 2 3
bind 0:18:1 6
lv 0:19:12 12 3
lv 0:19:15 10 1
view 0:19:15 12 col
cs 0:19:22 5 u
call 0:19:10 12 2 3
bind 0:19:1 7
lv 0:20:12 13 4
cf 0:20:15 4 #4000000000000000
cs 0:20:20 5 u
call 0:20:10 13 2 3
bind 0:20:1 8
lv 0:21:12 13 4
lv 0:21:15 10 1
cs 0:21:18 5 u
call 0:21:10 10 2 3
bind 0:21:1 9
cf 0:22:12 4 #3FF0000000000000
cf 0:22:17 4 #4000000000000000
cs 0:22:22 5 u
call 0:22:10 4 2 3
bind 0:22:1 10
""" + fmt_pieces('0:23:8', [
    ('lv 0:23:31 10 5\nci 0:23:34 3 1\nidx 0:23:31 4 1', 'g'),
    ('lv 0:23:38 10 6\nci 0:23:41 3 1\nidx 0:23:38 4 1', 'g'),
    ('lv 0:23:45 12 7\nci 0:23:48 3 1\nci 0:23:51 3 2\nidx 0:23:45 4 2', 'g'),
    ('lv 0:23:55 13 8\nci 0:23:58 3 1\nidx 0:23:55 4 1', 'g'),
    ('lv 0:23:62 10 9\nci 0:23:65 3 0\nidx 0:23:62 4 1', 'g'),
    ('lv 0:23:69 4 10', 'g')]) + """
lib 0:23:1 1 printf 1
eval 0:23:1
block 0:1:1 11
end
fn 2 h elem 4 3 0 0:7:1
par x 4 val
par y 4 val
par s 5 val
lv 0:8:12 4 1
lv 0:8:16 4 2
bin 0:8:12 4 mul
ret 0:8:5 1
block 0:7:47 1
end
fn 3 unused elem 4 1 0 0:10:1
par x 4 val
lv 0:11:12 4 1
ret 0:11:5 1
block 0:10:36 1
end
"""
# .hir: the five array applications become emaps (3.5.7 step 3); instances by first reference in
# file order: 1 (h; f64[], f64, str) for r1 and r2 (r2's argument is the cvt's f64[]: the types
# after the conversions, 3.5.3), 2 (h; f64[,], f64[,], str), 3 (h; f64[2], f64, str), 4 (h;
# f64[2], f64[], str). Types renumbered (3.5.1): the instance records come first, so inst 1
# numbers f64[] 10, inst 2 f64[,] 11, inst 3 f64[2] 12, and i64[] (first referred to by loc k)
# 13. unused is reached by no call and no instance: dropped (step 5).
ELEM6_INST_TYPES = {'10': '10', '11': '13', '12': '11', '13': '12'}
ELEM6_INST_HIR_HEAD = """
tvec 10 4
tmat 11 4
tfvec 12 4 2
tvec 13 3
inst 1 2 10 3 10 4 5
inst 2 2 11 3 11 11 5
inst 3 2 12 3 12 4 5
inst 4 2 10 3 12 10 5
"""
ELEM6_INST_EMAPS = {'0:17:10': 1, '0:18:10': 1, '0:19:10': 2, '0:20:10': 3, '0:21:10': 4}


def ty_fields(rec):
    """The indexes of the `ty` fields of a HIR record (passes.txt), for renumbering types."""
    for s in d6.FMT:
        if s[0] == 'H' and rec[0] in d6.FMT[s]:
            spec = d6.FMT[s][rec[0]]
            break
    else:
        raise AssertionError(('no format', rec))
    idx, k = [], 1
    for f in spec:
        nm, kind = f.split(':', 1)
        if '*' in kind:
            raise AssertionError(('counted field', rec))
        if kind.rstrip('?') == 'ty':
            idx.append(k)
        k += 1
    return idx


def elem6_inst_hir(hir1):
    """The .hir of elem6_inst from its .hir1 by 3.5.7 (see the comment above)."""
    lines = hir1.strip('\n').split('\n')
    body = []
    j = lines.index('fn 1 .main main 1 0 10 0:1:1')
    k = lines.index('fn 3 unused elem 4 1 0 0:10:1')
    for ln in lines[j:k]:
        p = ln.split(' ')
        if p[0] == 'call' and p[1] in ELEM6_INST_EMAPS:
            p = ['emap', p[1], p[2], str(ELEM6_INST_EMAPS[p[1]]), p[4]]
        for i in ty_fields(p):
            p[i] = ELEM6_INST_TYPES.get(p[i], p[i])
        body.append(' '.join(p))
    return dump('elem6_inst', ELEM6_INST_HIR_HEAD + '\n'.join(body))


def apply_edits(text, edits):
    for old, new in edits:
        assert text.count(old) == 1, old
        text = text.replace(old, new)
    return text


def check_inst(hir):
    """The instance records of a .hir against its emaps (3.5.3): each emap's iid names an instance
    whose rty is the emap's ty and whose argument types are the emap's children's; the instances
    numbered from 1 in order of first reference."""
    recs = [ln.split(' ') for ln in hir.split('\n') if ln and not ln.startswith('#')]
    inst = {r[1]: r for r in recs if r[0] == 'inst'}
    stack, order = [], []
    for r in recs:
        if r[0] in ('inst', 'fn', 'par', 'loc') or r[0].startswith('t') and r[0] in (
                'tvec', 'tmat', 'tfvec', 'tfmat', 'ttuple', 'tstruct', 'trec') or r[0] == 'fd':
            continue
        d = d6.fields_of('H', r)
        n = d6.npops('H', r, d)
        kids = stack[len(stack) - n:] if n else []
        del stack[len(stack) - n:]
        if r[0] == 'emap':
            ins = inst[r[3]]
            assert ins[3] == r[2] and ins[5:] == [kd[2] for kd in kids], (r, ins, kids)
            if r[3] not in order:
                order.append(r[3])
        stack.append(r)
    assert order == [str(i + 1) for i in range(len(inst))], order


def check_ast(name, src, ast):
    """dump6_cases.check_ast_positions, with the records it does not know checked here: pskip
    its `_`, ptuple and tasg their `(`, array its `[`, row and dot their first operand's token."""
    sl = src.split('\n')
    rest = []
    for ln in ast.split('\n'):
        p = ln.split(' ')
        if p[0] in ('pskip', 'ptuple', 'tasg', 'array', 'row', 'dot'):
            f, l, c = (int(x) for x in p[1].split(':'))
            at = sl[l - 1][c - 1:]
            want = {'pskip': '_', 'ptuple': '(', 'tasg': '(', 'array': '['}.get(p[0])
            assert (at.startswith(want) if want else re.match(r'[A-Za-z0-9]', at)), (name, ln)
        else:
            rest.append(ln)
    d6.check_ast_positions(name, src, '\n'.join(rest))


def part2(rg):
    n = 0
    for name, sea, ast_body, hir1_body, out in (
            ('elem6_vec', ELEM6_VEC_SEA, ELEM6_VEC_AST, ELEM6_VEC_HIR1, ELEM6_VEC_OUT),
            ('elem6_k5', ELEM6_K5_SEA, ELEM6_K5_AST, ELEM6_K5_HIR1, ELEM6_K5_OUT),
            ('elem6_inst', ELEM6_INST_SEA, ELEM6_INST_AST, ELEM6_INST_HIR1, ELEM6_INST_OUT)):
        ast = dump(name, ast_body)
        check_ast(name, sea, ast)
        fname = {'elem6_vec': 'f', 'elem6_k5': 'g', 'elem6_inst': None}[name]
        d6.CLASS[name] = ([(fname, 1, '(a) elemental')] if fname else
                          [('h', 1, '(a) elemental'), ('unused', 1, '(a) elemental')])
        res = d6.gen_res(rg, name, ast)
        assert 'rerr' not in res, (name, [l for l in res.split('\n') if 'rerr' in l])
        hir1 = dump(name, hir1_body)
        check_hir_positions(name, sea, hir1)
        if name == 'elem6_vec':
            hir = apply_edits(hir1, ELEM6_VEC_HIR_EDITS)
        elif name == 'elem6_k5':
            hir = apply_edits(hir1, ELEM6_K5_HIR_EDITS)
        else:
            hir = elem6_inst_hir(hir1)
        check_inst(hir)
        for x, text in (('sea', sea), ('ast', ast), ('res', res), ('hir1', hir1), ('hir', hir),
                        ('out', out)):
            write(name + '.' + x, text)
            n += 1
    return n


def check_hir_positions(name, src, hir):
    """Every positioned HIR record names the token 3.5.5 gives it: an lv/ci/cf/cs its token, a
    bin its left operand's first token, a call its callee, a lib its name, an idx/cvt/view its
    operand, a bind its let/var, a tbind its let, a tasg its `(`, a skip its `_`, an eval its
    statement's first token, a ret its return, a block its `{` (1:1 for .main), fmt pieces the
    format string, row/arr their first element / `[`."""
    sl = src.split('\n')
    for ln in hir.split('\n'):
        p = ln.split(' ')
        if not ln or ln.startswith('#') or p[0] in ('fn', 'par', 'loc', 'end', 'inst', 'tvec',
                                                     'tmat', 'tfvec', 'ttuple'):
            continue
        f, l, c = (int(x) for x in p[1].split(':'))
        if (l, c) == (1, 1):
            assert p[0] == 'block', ln
            continue
        at = sl[l - 1][c - 1:]
        op = p[0]
        if op == 'ci':
            assert re.match(p[3] + r'\b', at), (name, ln, at)
        elif op == 'cf':
            assert re.match(r'[0-9]+\.[0-9]+', at), (name, ln, at)
        elif op == 'cs':
            assert at.startswith('"' + p[3] + '"'), (name, ln, at)
        elif op in ('lv', 'bin', 'call', 'emap', 'lib', 'eval', 'idx', 'cvt', 'view', 'row'):
            assert re.match(r'[A-Za-z_0-9]', at), (name, ln, at)
        elif op == 'arr':
            assert at.startswith('['), (name, ln)
        elif op in ('fconv', 'ftext', 'fmt'):
            assert at.startswith('"'), (name, ln)
        elif op == 'block':
            assert at.startswith('{'), (name, ln, at)
        elif op == 'bind':
            assert at.startswith(('let ', 'var ')), (name, ln)
        elif op == 'tbind':
            assert at.startswith('let ('), (name, ln)
        elif op == 'tasg':
            assert at.startswith('('), (name, ln)
        elif op == 'skip':
            assert at.startswith('_'), (name, ln)
        elif op == 'ret':
            assert at.startswith('return'), (name, ln)
        else:
            raise AssertionError((name, ln))


def res_gen6c():
    """res_gen.py (the spec oracle of 3.4.1, 3.4.2) with the edits of the phase-rule steps a
    program of 6c needs: 4g-1's `str` parameter and result types (no 259 `strings`, the three
    str edits of dump4g_cases.res_gen4g1), 6b's (dump6_cases.res_gen6: no 259 `default
    arguments`, a default resolved like a const value) and 6c's (no 259 `elemental functions`,
    2.11.2). Each replaced text must occur exactly once."""
    import types
    path = os.path.join(HERE, 'res_gen.py')
    src = read(path)
    edits = [
        ("""            if p.kids[0].f[1] == 'str':
                err(p.pos, 259, ['strings'])
""", ''),
        ("""            if tn.f[1] == 'str':
                err(tn.pos, 259, ['strings'])
            keys[id(tn)] = resolve_type(tn, [], False)
""", """            keys[id(tn)] = resolve_type(tn, [], False)
"""),
        ("""        if bt == 5 and not str_ok:
            return None                       # a str parameter (reported at its param node)
""", """        if bt == 5 and shape in ('fv', 'fm'):
            err(tn.pos, 259, ['strings'])
            return None
"""),
        ("""            if p.f[3] == '1':
                err(p.pos, 259, ['default arguments'])
""", ''),
        ("""        if it.op == 'fn' and it.f[2] == '1':
            err(it.pos, 259, ['elemental functions'])
""", ''),
        ("""        resolve(it.kids[-1], [psc], Fn(np_))
    nfn = len(powk_sites)
""", """        resolve(it.kids[-1], [psc], Fn(np_))
    for it in fns:
        for p in it.kids[:int(it.f[3])]:
            if p.f[3] == '1':
                resolve(p.kids[1], [], None)
    nfn = len(powk_sites)
"""),
    ]
    for old, new in edits:
        assert src.count(old) == 1, old
        src = src.replace(old, new)
    mod = types.ModuleType('res_gen6c')
    mod.__file__ = path
    exec(compile(src, path, 'exec'), mod.__dict__)
    return mod


# ================================================================ part 3: the .hirl (3.5.9)
# A node is (op, fields, kids); a field may be a Loc, a local sealoop creates, whose number is
# given when the file is written: 3.5.9 "Locals": the `.l` locals are numbered after the source
# locals in the order of their declaring records in file order (post-order: a `tmp` after its
# child, an `hloop` after its block, a `tbind` after its value, its locals in component order),
# so an `hloop`'s induction local is numbered after every local its body declares, and an `lv` of
# it may precede its `hloop`. Each has a `loc` record: mut `let` (`tmp`, `tbind`) or `for` (an
# `hloop`), the type of the value it names, and the position P of the node the rewrite implements
# (L20, L-cf: the call's for the `tmp`s of an inline xblk; L19: the emap's, which is also that of
# the call L19 writes).

class Loc:
    def __init__(self, ty, mut, pos):
        self.ty, self.mut, self.pos, self.num = ty, mut, pos, None


def N(op, *fields, kids=()):
    return (op, list(fields), list(kids))


def RAW(text):
    """Records the rewrite keeps, written as they stand in sea.hir (source locals only)."""
    return ('raw', text.strip('\n').split('\n'), [])


def hirl_main(name, nloc, ntypes_head, body, nstmt):
    """The records of .main: its fn record (nl counting the new locals), its loc records, the
    body; the source locals are the first nloc lines of locs of sea.hir."""
    order = []

    def post(n):
        op, f, kids = n
        for k in kids:
            post(k)
        order.append(n)

    for s in body:
        post(s)
    post(N('block', '0:1:1', nstmt, kids=[]))      # placeholder for the body block record
    order.pop()
    nxt = [nloc + 1]
    newlocs = []

    def declare(x):
        assert isinstance(x, Loc) and x.num is None, x
        x.num = nxt[0]
        nxt[0] += 1
        newlocs.append(x)

    for op, f, kids in order:
        if op in ('tmp', 'hloop', 'bind') and isinstance(f[1], Loc):
            declare(f[1])
        elif op == 'tbind':
            for x in f[2:]:
                if isinstance(x, Loc):
                    declare(x)
    out = []
    for op, f, kids in order:
        if op == 'raw':
            out.extend(f)
            continue
        vals = []
        for v in f:
            if isinstance(v, Loc):
                assert v.num is not None, (op, f)
                vals.append(str(v.num))
            else:
                vals.append(str(v))
        out.append(' '.join([op] + vals))
    out.append('block 0:1:1 %d' % nstmt)
    locs = ['loc .l%d %s %s %s' % (i + 1, x.ty, x.mut, x.pos) for i, x in enumerate(newlocs)]
    return locs, out, len(newlocs)


def lv(pos, ty, x):
    return N('lv', pos, ty, x)


def tmp(P, ty, child):
    """`tmp L = child` of a new `.l` local L of type ty; returns (statement, L)."""
    x = Loc(ty, 'let', P)
    return N('tmp', P, x, kids=[child]), x


def loop(P, n, body):
    """loop(N; K) { S } of 4e-0 (3.5.9): `tmp Z = ci 0`; `if` (e = 0) `bin gt (lv N) (lv Z)` {
    `tmp O = ci 1`; `tmp L = wbin sub (lv N) (lv O)`; `hloop K (lv Z) (lv L) (lv O)` { S } };
    body(K) gives the statements S."""
    sz, z = tmp(P, 3, N('ci', P, 3, 0))
    so, o = tmp(P, 3, N('ci', P, 3, 1))
    sl, l = tmp(P, 3, N('wbin', P, 3, 'sub', kids=[lv(P, 3, n), lv(P, 3, o)]))
    k = Loc(3, 'for', P)
    stmts = body(k)
    hl = N('hloop', P, k, kids=[lv(P, 3, z), lv(P, 3, l), lv(P, 3, o),
                                N('block', P, len(stmts), kids=stmts)])
    cond = N('bin', P, 2, 'gt', kids=[lv(P, 3, n), lv(P, 3, z)])
    return [sz, N('if', P, 0, kids=[cond, N('block', P, 3, kids=[so, sl, hl])])]


def inline(P, ty, k, ptys, args, body):
    """L20 (L18 with L20's differences) of `call P ty fid n` of an elemental function: `xblk P ty
    n` with `tmp Ai = ai` (Ai a new `.l` local of pi's type, at P) and the value `iblk P ty k`
    whose child is the callee's body block copied with its own positions, every `lv` of pi
    reading Ai, every `ret` an `iret` at its own position (body(A) writes that copy)."""
    stmts, a = [], []
    for t, arg in zip(ptys, args):
        s, x = tmp(P, t, arg)
        stmts.append(s)
        a.append(x)
    return N('xblk', P, ty, len(stmts), kids=stmts + [N('iblk', P, ty, k, kids=[body(a)])])


def body_f(a):
    """f's body (elem6_vec line 5) as L20 copies it: `return x * k + 1.0`, own positions."""
    x, k = a
    e = N('bin', '0:5:12', 4, 'add', kids=[
        N('bin', '0:5:12', 4, 'mul', kids=[lv('0:5:12', 4, x), lv('0:5:16', 4, k)]),
        N('cf', '0:5:20', 4, '#3FF0000000000000')])
    return N('block', '0:4:39', 1, kids=[N('iret', '0:5:5', 1, kids=[e])])


def body_g(a):
    """g's body (elem6_k5 line 5): `return (x, x + 1.0, x + 2.0, x + 3.0, x + 4.0)`."""
    (x,) = a
    vals = [lv('0:5:13', 4, x)]
    for col, c, cf in ((16, 20, '#3FF0000000000000'), (25, 29, '#4000000000000000'),
                       (34, 38, '#4008000000000000'), (43, 47, '#4010000000000000')):
        p = '0:5:%d' % col
        vals.append(N('bin', p, 4, 'add', kids=[lv(p, 4, x), N('cf', '0:5:%d' % c, 4, cf)]))
    return N('block', '0:4:53', 1, kids=[N('iret', '0:5:5', 5, kids=vals)])


def l19_vec(P, args, arrays, ptys, kept, rty_arr, call_ty, k, body, tp):
    """L19 (2.11.4) of `emap P T iid n` whose array arguments are dynamic vectors of f64 (the
    only case of these dumps). args: the argument nodes a1 ... an as written; arrays: which are
    arrays; ptys: F's parameter types; kept: for each of F's k results, whether the enclosing
    statement keeps it; rty_arr: the array type Tj of a result (all f64[] here); call_ty: F's
    result type ty1; body: F's body copier for inline(); tp: the tptr of f64.
    Returns (statements, [Rj or None per result]) with:
    (1) `tmp Ai = ai` for every argument in order (L-ck);
    (2) rule 22's extents of the array arguments in order, `tmp Nk = ext P 3 0 (lv Ak)` (L7 (2),
        a dynamic result), and with more than one array argument L7's vector checks (none here:
        each emap of these dumps has one array argument, so no check and no V);
    (3) `tmp Rj = anew P Tj 0 1 (lv N1)` for each kept result j, in result order;
    (4) rule 22's nest (L7 (5), (6)): `tmp DRj = adat P ^f64 (lv Rj)` for each kept result in
        order, then `tmp Dk = adat P ^f64 (lv Ak)` for each array argument in order (implementer
        reading: L7 (5)'s `tmp DR = data(RES)` once per allocated result, before the operands'
        data); loop(N1; I) { body } with the call `call P ty1 fid n` of the element values (`eld P
        f64 8 0 (lv Dk) (lv I)` at an array argument, `lv Ai` at a scalar one), rewritten by L20:
        for k = 1 the body is `est P 8 0 <inline call> (lv DR1) (lv I)`; for k >= 2 a `block P m`
        whose first statement is `tbind P k E1 ... Ek` (a new f64 `.l` local per kept result,
        `-` for a discarded one) of the inline call, followed by `est P 8 0 (lv Ej) (lv DRj) (lv
        I)` for each kept j in order; when every result is discarded the body is `eval P` of the
        inline call and nothing is allocated."""
    stmts, a = [], []
    for t_arr, arg in zip(rty_arr_args(args, arrays, ptys), args):
        s, x = tmp(P, t_arr, arg)
        stmts.append(s)
        a.append(x)
    ns = []
    for x, is_arr in zip(a, arrays):
        if is_arr:
            s, nk = tmp(P, 3, N('ext', P, 3, 0, kids=[lv(P, x.ty, x)]))
            stmts.append(s)
            ns.append(nk)
    assert len(ns) == 1
    n1 = ns[0]
    rs = []
    for j in range(k):
        if kept[j]:
            s, r = tmp(P, rty_arr, N('anew', P, rty_arr, 0, 1, kids=[lv(P, 3, n1)]))
            stmts.append(s)
            rs.append(r)
        else:
            rs.append(None)
    drs = []
    for r in rs:
        if r is not None:
            s, dr = tmp(P, tp, N('adat', P, tp, kids=[lv(P, rty_arr, r)]))
            stmts.append(s)
            drs.append(dr)
        else:
            drs.append(None)
    ds = []
    for x, is_arr in zip(a, arrays):
        if is_arr:
            s, d = tmp(P, tp, N('adat', P, tp, kids=[lv(P, x.ty, x)]))
            stmts.append(s)
            ds.append(d)
        else:
            ds.append(None)

    def lbody(i):
        eargs = [N('eld', P, 4, 8, 0, kids=[lv(P, tp, d), lv(P, 3, i)]) if d is not None
                 else lv(P, x.ty, x) for x, d in zip(a, ds)]
        call = inline(P, call_ty, k, ptys, eargs, body)
        if not any(kept):
            return [N('eval', P, kids=[call])]
        if k == 1:
            return [N('est', P, 8, 0, kids=[call, lv(P, tp, drs[0]), lv(P, 3, i)])]
        es = [Loc(4, 'let', P) if kept[j] else '-' for j in range(k)]
        inner = [N('tbind', P, k, *es, kids=[call])]
        for j in range(k):
            if kept[j]:
                inner.append(N('est', P, 8, 0, kids=[lv(P, 4, es[j]), lv(P, tp, drs[j]),
                                                     lv(P, 3, i)]))
        return [N('block', P, len(inner), kids=inner)]

    stmts += loop(P, n1, lbody)
    return stmts, rs


def rty_arr_args(args, arrays, ptys):
    """The types of the argument `tmp`s: each argument's own type (an array argument f64[] = 10
    in these dumps, a scalar its parameter's type)."""
    return [10 if is_arr else t for is_arr, t in zip(arrays, ptys)]


def elem6_vec_hirl(hir):
    P = '0:8:9'
    tp = 11                                     # tptr 11 4, appended (3.5.9 "Types")
    # line 7: L1, zeros(3) is `anew P T 1 1` with its argument
    s1 = RAW('ci 0:7:15 3 3\nanew 0:7:9 10 1 1\nbind 0:7:1 1')
    # line 8: L19, k = 1: `xblk P 10 n` with the statements of (1)-(4), value `lv R1` (owned:
    # T2 moves it out), held by w's bind
    st, rs = l19_vec(P, [N('lv', '0:8:11', 10, 1), N('cf', '0:8:14', 4, '#4000000000000000')],
                     [True, False], [4, 4], [True], 10, 4, 1, body_f, tp)
    s2 = [N('xblk', P, 10, len(st), kids=st + [lv(P, 10, rs[0])]), N('bind', '0:8:1', 2)]
    # line 9: L20 of the scalar call f(0.5, 4.0) at 0:9:9, held by s's bind
    c = inline('0:9:9', 4, 1, [4, 4], [N('cf', '0:9:11', 4, '#3FE0000000000000'),
                                       N('cf', '0:9:16', 4, '#4010000000000000')], body_f)
    s3 = [c, N('bind', '0:9:1', 3)]
    # line 10: printf, unchanged (a scalar idx is lowered by sealower, rule 18)
    hl = hir.split('\n')
    s4 = RAW('\n'.join(hl[hl.index('lv 0:10:19 10 2'):hl.index('eval 0:10:1') + 1]))
    body = [s1] + s2 + s3 + [s4]
    locs, out, nl = hirl_main('elem6_vec', 3, None, body, 4)
    text = ('tvec 10 4\ntptr 11 4\nfn 1 .main main 1 0 %d 0:1:1\n' % (3 + nl)
            + 'loc v 10 let 0:7:5\nloc w 10 let 0:8:5\nloc s 4 let 0:9:5\n'
            + '\n'.join(locs + out) + '\nend\n')
    return dump('elem6_vec', text)


def elem6_k5_hirl(hir):
    tp = 13                                     # tptr 13 4 after tvec 10, ttuple 11, ttuple 12
    hl = hir.split('\n')
    lvv = lambda pos: N('lv', pos, 10, 1)      # noqa: E731  (the argument v, own position)
    body = []
    # line 7: L1
    body.append(RAW('ci 0:7:15 3 2\nanew 0:7:9 10 1 1\nbind 0:7:1 1'))
    # line 8: `let (a, _, c, _, e) = g(v)`: L19 in place of the tbind in .main's block (L11's
    # tbind form: not a block of its own), results 1, 3, 5 kept (2 and 4 are `-`: not
    # allocated, Decision 84), then the tbind's locals bound from the Rj, `bind P a = lv R1`
    # ... (every node L11 writes takes P, the emap's position)
    P = '0:8:23'
    st, rs = l19_vec(P, [lvv('0:8:25')], [True], [4], [True, False, True, False, True], 10, 12, 5,
                     body_g, tp)
    body += st
    for lid, r in ((2, rs[0]), (3, rs[2]), (4, rs[4])):
        body.append(N('bind', P, lid, kids=[lv(P, 10, r)]))
    # lines 9, 10: L1
    body.append(RAW('ci 0:9:15 3 1\nanew 0:9:9 10 1 1\nbind 0:9:1 5'))
    body.append(RAW('ci 0:10:15 3 1\nanew 0:10:9 10 1 1\nbind 0:10:1 6'))
    # line 11: `(p, _, _, q, _) = g(v)`: L11's tasg form, a new `block P n` with L19's statements
    # (results 1 and 4 kept) and the stores of rule 15 (j) in target order with their cv 0:
    # `asg P set (lv p) (lv R1)`, `asg P set (lv q) (lv R4)` (the targets keep their positions)
    P = '0:11:19'
    st, rs = l19_vec(P, [lvv('0:11:21')], [True], [4], [True, False, False, True, False], 10, 12,
                     5, body_g, tp)
    st.append(N('asg', P, 'set', kids=[N('lv', '0:11:2', 10, 5), lv(P, 10, rs[0])]))
    st.append(N('asg', P, 'set', kids=[N('lv', '0:11:11', 10, 6), lv(P, 10, rs[3])]))
    body.append(N('block', P, len(st), kids=st))
    # line 12: `g(v)`: an eval, every result discarded: a new `block P n` (nothing kept), no
    # result allocated, the loop body the inline call as a statement (`eval P`)
    P = '0:12:1'
    st, rs = l19_vec(P, [lvv('0:12:3')], [True], [4], [False] * 5, 10, 12, 5, body_g, tp)
    body.append(N('block', P, len(st), kids=st))
    # line 13: printf; len(a), len(p) are L3's `ext P 3 0` of their argument
    pr = '\n'.join(hl[hl.index('lv 0:13:34 10 2'):hl.index('eval 0:13:1') + 1])
    pr = apply_edits(pr, [('lib 0:13:64 3 len 1', 'ext 0:13:64 3 0'),
                          ('lib 0:13:72 3 len 1', 'ext 0:13:72 3 0')])
    body.append(RAW(pr))
    nstmt = len(body)
    locs, out, nl = hirl_main('elem6_k5', 6, None, body, nstmt)
    text = ('tvec 10 4\nttuple 11 5 10 10 10 10 10\nttuple 12 5 4 4 4 4 4\ntptr 13 4\n'
            + 'fn 1 .main main 1 0 %d 0:1:1\n' % (6 + nl)
            + 'loc v 10 let 0:7:5\nloc a 10 let 0:8:6\nloc c 10 let 0:8:12\nloc e 10 let 0:8:18\n'
            + 'loc p 10 var 0:9:5\nloc q 10 var 0:10:5\n'
            + '\n'.join(locs + out) + '\nend\n')
    return dump('elem6_k5', text)


def part3():
    n = 0
    for name, fn in (('elem6_vec', elem6_vec_hirl), ('elem6_k5', elem6_k5_hirl)):
        hir = read(os.path.join(d6.PASSES if not CHECK else d6.SRC_PASSES, name + '.hir'))
        write(name + '.hirl', fn(hir))
        n += 1
    return n


# ================================================================ part 4: elem6_vec.lir1 (3.6)
# By hand, each line's derivation beside it. Registers numbered on first appearance (3.6.1), the
# locals' registers being the registers their binding rules give them; blocks numbered from 1 in
# opening order (3.6.4); sites the line of the node's position (3.6.4).
ELEM6_VEC_LIR1 = [
    ('func .main main 0:1:1 0 0', 'the main function (3.6.3)'),
    ('slot s1 16 8', "rule 8: printf's argument slot, two 8-byte values"),
    # line 7, L1's anew z 1, r 1 (rule 22's allocation: sea_arr_new with the element size code,
    # rank and extents, here 1, 1, n, 1 as in every 4e golden), into v's register (bind, rule 30)
    ('li i1 3', 'the extent ci 3'),
    ('li i2 1', 'anew: the allocation arguments (4.8 sea_arr_new)'),
    ('li i3 1', ''),
    ('li i4 1', ''),
    ('rcall sea_arr_new 0:7 1 p5 4 i2 i3 i1 i4', 'z 1: cleared; p5 is v (owned, moved into v)'),
    # line 8, L19's xblk with destination w (T3: its value is lv R1 of its own tmp)
    ('lf f6 #4000000000000000', 'tmp A2 = cf 2.0 (T1: a constant into the local); A1 = v (alias)'),
    ('ldi i7 p5 - 0 16', 'tmp N1 = ext of A1, the extent field (4.8)'),
    ('li i8 1', 'tmp R1 = anew 0 1 (lv N1): sea_arr_new_u, not cleared'),
    ('li i9 1', ''),
    ('li i10 1', ''),
    ('rcall sea_arr_new_u 0:8 1 p11 4 i8 i9 i7 i10', "R1's register is w's (T3)"),
    ('ldp p12 p11 - 0 40', 'tmp DR1 = adat of R1, the data field (4.8)'),
    ('ldp p13 p5 - 0 40', 'tmp D1 = adat of A1'),
    ('li i14 0', 'loop(N1; I) (rule 17): tmp Z'),
    ('icmp gt i15 i7 i14', 'N1 > Z'),
    ('if 1 i15', ''),
    ('li i16 1', 'tmp O'),
    ('isub i17 i7 i16', 'tmp L = wbin sub'),
    ('loop 2 i18 i14 i17 i16', 'hloop I from Z, last L, step O'),
    ('ldf f19 p13 i18 8 0', "the inline xblk's tmp X = eld f64 8 0 (D1, I); tmp K = A2 (alias)"),
    ('do 3', 'the iblk (R26, rule 37)'),
    ('fmul f20 f19 f6', 'x * k (line 5, rule 1)'),
    ('lf f21 #3FF0000000000000', '1.0'),
    ('fadd f22 f20 f21', '+'),
    ('mov f23 f22', 'iret: mov R1 V1'),
    ('exit 3', ''),
    ('enddo 3', "the iblk's value R1 = f23 (R27: an est operand, no destination)"),
    ('stf f23 p12 i18 8 0', 'est P 8 0 into DR1 at I'),
    ('endloop 2', ''),
    ('endif 1', 'xblk value lv R1: w (no instruction; A1 borrowed, nothing to release)'),
    # line 9, L20 of f(0.5, 4.0) bound to s (R27: a destination receives mov after enddo)
    ('lf f24 #3FE0000000000000', 'tmp = cf 0.5'),
    ('lf f25 #4010000000000000', 'tmp = cf 4.0'),
    ('do 4', ''),
    ('fmul f26 f24 f25', ''),
    ('lf f27 #3FF0000000000000', ''),
    ('fadd f28 f26 f27', ''),
    ('mov f29 f28', 'iret'),
    ('exit 4', ''),
    ('enddo 4', ''),
    ('mov f30 f29', "s's register receives R1 (R27)"),
    # line 10, rule 18 (w[2], a scalar index, checked) and rule 8 (printf)
    ('li i31 2', 'the index'),
    ('ldi i32 p11 - 0 16', 'the extent of w'),
    ('chkb i31 i32 0 0:10', 'bounds check of dimension 0'),
    ('ldp p33 p11 - 0 40', 'the data'),
    ('ldf f34 p33 i31 8 0', 'the element'),
    ('sa p35 s1', ''),
    ('stf f34 p35 - 0 0', ''),
    ('stf f30 p35 - 0 8', ''),
    ('la p36 d1', ''),
    ('rcall sea_printf 0:10 0 2 p36 p35', ''),
    ('release p11', 'rule 16: the locals holding counts at the end of .main, in reverse order: w'),
    ('release p5', 'v'),
    ('ret 0', ''),
    ('endfunc', ''),
    ('fmt d1 4', "the format's data record (rule 8)"),
    ('fconv - - - g f', ''),
    ('ftext %20', ''),
    ('fconv - - - g f', ''),
    ('ftext %0A', ''),
]


def part4():
    write('elem6_vec.lir1', dump('elem6_vec', '\n'.join(ln for ln, _ in ELEM6_VEC_LIR1)))
    return 1


def main():
    import shutil
    import tempfile
    d6.SCRATCH_DIR = tempfile.mkdtemp(prefix='dump6c.')    # res_gen reads its .ast from a file
    try:
        rg = res_gen6c()
        n1 = part1(rg)
        n2 = part2(rg)
        n3 = part3()
        n4 = part4()
    finally:
        shutil.rmtree(d6.SCRATCH_DIR)
    print('dump6c_cases: part 1 (res_err_elemental): %d goldens; part 2 (elem6_* front end): %d; '
          'part 3 (.hirl): %d; part 4 (.lir1): %d; %s' % (n1, n2, n3, n4, 'checked' if CHECK else 'written'))


if __name__ == '__main__':
    main()
