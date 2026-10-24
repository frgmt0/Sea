"""Sub-phase 4h dump tests (DESIGN.md 6.2 "4h" dumps; 3.5.4 the `.i` locals and the renumbering of
functions; 3.5.9 "What sealoop rewrites in 4h": L18, the records `iblk` and `iret`, T1-T3 with the
refinements R26-R30 and "What the passes validate in 4h"; 3.6.6 rules 2, 3, 5, 12, 15, 16 and 37
and "Lowering of the sea.hirl records"; Decisions 53-57, lead decisions L-s ... L-ab).

Run with `timeout 120 uv run --no-project python tests/vectors/dump4h_cases.py [--out DIR]`. It
writes, in tests/passes/ (or DIR):

* the stage-only goldens of Decision 55 (a hand-written two-file NAME.hir, file 0 standing for
  the prelude, file 1 the program; then NAME.hirl and NAME.lir1; no NAME.sea, no NAME.hir1, so
  tests/stage.sh runs the pairs hir -> hirl (sealoop) and hirl -> lir1 (sealower) on them and
  skips hir1 -> hir):
  inl_half       rule 37's example; its .lir1 body is rule 37's text byte for byte
  inl_nested     a prelude function calling another twice (recursive inlining, Decision 55),
                 and `sq(hyp(...))`, a prelude argument that is itself an inline call
  inl_void       k = 0 under `eval`: an early `iret` with k 0 in an `if`, then the end of the
                 body block: `exit B` before `enddo B`
  inl_multi      k = 2 under a `tbind` with a `_`, under a `tasg` with a cv 1 component and a
                 `ref` parameter target, and under a `tret`
  inl_loop_ret   an `iret` inside the copy's element loop: L4's H and the copy's array local
                 released before `exit B` (R29), and the rule 16 (a) end of the body block
  inl_owned_arg  owned arguments (a fresh array) released after the `mov` of a `bind` and after
                 the `mov`s of a `tbind` (R26, R27); an owned result under `eval` released (R27)
  inl_dest       R27's destinations: a `tmp` (an inline call as the argument of another), a
                 `bind`, an `asg set` to a scalar local, to a reference local (release, mov) and
                 to a scalar `ref` parameter (stf), and an `ifx` arm register (rule 3)
  inl_rule12     rule 12 inside the inline `xblk` (R30): `cnt(v, grow(ref v))`, the reference
                 read protected (`mov T L`, `retain T`, released with the owned `tmp`s), and the
                 scalar read `add(n, bump(ref n))` copied into the parameter's register
  inl_scope      the `iblk` bound of R26 with an owned L16 `tmp` (a `match` scrutinee) written
                 directly in a block of the copy inside a loop (R11, R22): released at that
                 block's end and by the
                 `iret` that leaves it, while the inline `xblk` that encloses the call
                 releases only its own argument temporary

* the `NAME.prelude` dumps of 6.2 (Decision 57), built with the real prelude std/std.sea as
  WP-STD wrote it (file 0, its `#file` record written `#file std.sea`; the positions of the
  prelude function are found in that text, and the script stops if its lines change):
  prel_bincount        .sea .hir .hirl .lir1 .out .prelude: one call; the copy's filled (L2),
                       element loop (L4) and compound element store `c[v] += 1` (rule 19)
  prel_meshgrid_tbind  .sea .hirl .lir1 .out .prelude: a two-result inline call under a `tbind`
                       with two owned argument temporaries (R26, R27)
* res_noprelude_pnames (.sea .ast .res, --no-prelude): the four prelude names resolve as
  `rname ... none 0` (lead decision L-s), through tests/vectors/res_gen.py's PRELUDE_NAMES.

How each file is made (never by running a pass; the 4h passes are written concurrently):
* `.hir`: by hand from 3.5.4-3.5.5 (`.main` function 1 at 1:1:1, the prelude's functions next,
  then the program's, each body as pass 2a and 2b write it), with the positions of the source text
  given beside each test (file 0 is the prelude text, file 1 the program text; neither is a file
  of the corpus, Decision 55).
* `.hirl`: by hand from 3.5.9 L18 (1)-(5) and, for the copied constructs, L1-L17, record by
  record: every copied or written node at the call's position P, the arguments at their own
  positions; the `.l` locals numbered after the `.j` locals and the `.i` locals after the `.l`
  locals, each group in the order of its declaring records; prelude functions dropped and the
  rest renumbered.
* `.lir1`: by hand from 3.6.6, instruction by instruction, with the derivation in comments;
  registers written symbolically (`f.x`) and numbered by number_regs (3.6.1).

The self-check at the end reads every written file back: each record against include/passes.txt
(sets H HF for .hir, H HF HL for .hirl, L for .lir1) and the post-order of 3.3; in the HIR files
the function numbering, the locals (np par and nl loc records, every lid in range, the `.l` and
`.i` locals in the order of their declaring records, .l before .i), the 4h validation of 3.5.9
(`iblk` only as the value of an inline `xblk`, its child a block, k consistent with ty; `iret`
only inside an `iblk` with its k; no `ret`/`tret` inside an `iblk`; no prelude function left in
the .hirl; every position inside the copied code at P); in the LIR the numbering of registers,
blocks, slots and labels of 3.6.1-3.6.4; every .hir position against the source texts of the
test (SRC; std/std.sea for the prelude dumps); and inl_half.lir1 against rule 37's example text
in DESIGN.md.
"""

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
PASSES = os.path.join(os.path.dirname(HERE), 'passes')
if '--out' in sys.argv:
    PASSES = os.path.abspath(sys.argv[sys.argv.index('--out') + 1])


def lines(text):
    return [ln for ln in text.strip('\n').split('\n') if ln and not ln.startswith(';')]


def head2(name):
    """The header of 3.2 for a two-file stream: file 0 the prelude, file 1 the program."""
    return '#sea 1\n#target arm64-macos\n#file std.sea\n#file %s.sea\n' % name


def dump2(name, body):
    return head2(name) + '\n'.join(lines(body)) + '\n#end\n'


def number_regs(text):
    """3.6.1: registers numbered from 1 in order of first appearance in each function (record
    order, fields left to right), across all classes. A register is written `c.NAME`."""
    out, names = [], {}
    for ln in lines(text):
        if ln.startswith('func '):
            names = {}
        toks = ln.split(' ')
        for k, t in enumerate(toks):
            m = re.match(r'^([ifp])\.(\w+)$', t)
            if m:
                if t not in names:
                    names[t] = '%s%d' % (m.group(1), len(names) + 1)
                toks[k] = names[t]
        out.append(' '.join(toks))
    return '\n'.join(out) + '\n'


TESTS = {}          # name -> {'hir': text, 'hirl': text, 'lir1': text}
SRC = {}            # name -> (text of file 0, text of file 1): the positions of its .hir


def test(name, hir, hirl, lir1):
    TESTS[name] = {'hir': dump2(name, hir), 'hirl': dump2(name, hirl),
                   'lir1': dump2(name, number_regs(lir1))}


# ================================================================ inl_half (rule 37's example)
# file 0 (the prelude), line 1:  fn half(x: f64) -> f64 { return x / 2.0 }
#                                columns: fn 1, x 9, { 24, return 26, x 33, 2.0 37
# file 1 (the program), line 1:  let y = half(3.0)
#                                columns: let 1, y 5, half 9, 3.0 14
# 3.5.4: `.main` is function 1 (at 1:1:1, its body block there too), `half` function 2. A bin
# takes its left operand's position (3.5.5: the AST `bin` at the left operand's first token).
test('inl_half', """
fn 1 .main main 1 0 1 1:1:1
loc y 4 let 1:1:5
cf 1:1:14 4 #4008000000000000
call 1:1:9 4 2 1
bind 1:1:1 1
block 1:1:1 1
end
fn 2 half fn 4 1 0 0:1:1
par x 4 val
lv 0:1:33 4 1
cf 0:1:37 4 #4000000000000000
bin 0:1:33 4 div
ret 0:1:26 1
block 0:1:24 1
end
""",
# L18 at P = 1:1:9: `tmp .l1 = cf` (the argument at its own position, .l1 local 2 of pi's type,
# mut let, pos P), then the iblk (ty 4, k 1) over the copy of half's body block, every node at
# P: `lv .l1` (2), `cf 2.0`, `bin div`, `ret` -> `iret 1`; the xblk (ty 4, n 1). `half` dropped.
"""
fn 1 .main main 1 0 2 1:1:1
loc y 4 let 1:1:5
loc .l1 4 let 1:1:9
cf 1:1:14 4 #4008000000000000
tmp 1:1:9 2
lv 1:1:9 4 2
cf 1:1:9 4 #4000000000000000
bin 1:1:9 4 div
iret 1:1:9 1
block 1:1:9 1
iblk 1:1:9 4 1
xblk 1:1:9 4 1
bind 1:1:1 1
block 1:1:1 1
end
""",
# The xblk is the value of y's bind (a destination of rule 2). Its tmp by T1: the child cf is
# computed with .l1's register as destination (lf f.a). The iblk: do 1; the copy (lv .l1 is
# f.a, cf 2.0 a new lf, fdiv a new register); iret 1: mov R1 V1 (R1 numbered here), exit 1;
# enddo 1; then R27: a destination D of rule 2 receives `mov D R1` after enddo (y's register is
# first used here). .main ends with ret 0 (rule 6).
"""
func .main main 1:1:1 0 0
lf f.x #4008000000000000
do 1
lf f.two #4000000000000000
fdiv f.q f.x f.two
mov f.r1 f.q
exit 1
enddo 1
mov f.y f.r1
ret 0
endfunc
""")


SRC['inl_half'] = ("""fn half(x: f64) -> f64 { return x / 2.0 }
""", """let y = half(3.0)
""")


# ================================================================ inl_nested (recursive inlining)
# file 0, line 1:  fn sq(x: f64) -> f64 { return x * x }
#                  columns: fn 1, { 22, return 24, x 31, x 35
# file 0, line 2:  fn hyp(a: f64, b: f64) -> f64 { return sq(a) + sq(b) }
#                  columns: fn 1, { 31, return 33, sq 40, a 43, sq 48, b 51
# file 1, line 1:  let r = hyp(3.0, 4.0)          let 1, r 5, hyp 9, 3.0 13, 4.0 18
# file 1, line 2:  let z = sq(hyp(1.0, 2.0))      let 1, z 5, sq 9, hyp 12, 1.0 16, 2.0 21
# Functions: .main 1, sq 2, hyp 3 (the prelude's in stream order).
test('inl_nested', """
fn 1 .main main 1 0 2 1:1:1
loc r 4 let 1:1:5
loc z 4 let 1:2:5
cf 1:1:13 4 #4008000000000000
cf 1:1:18 4 #4010000000000000
call 1:1:9 4 3 2
bind 1:1:1 1
cf 1:2:16 4 #3FF0000000000000
cf 1:2:21 4 #4000000000000000
call 1:2:12 4 3 2
call 1:2:9 4 2 1
bind 1:2:1 2
block 1:1:1 2
end
fn 2 sq fn 4 1 0 0:1:1
par x 4 val
lv 0:1:31 4 1
lv 0:1:35 4 1
bin 0:1:31 4 mul
ret 0:1:24 1
block 0:1:22 1
end
fn 3 hyp fn 4 2 0 0:2:1
par a 4 val
par b 4 val
lv 0:2:43 4 1
call 0:2:40 4 2 1
lv 0:2:51 4 2
call 0:2:48 4 2 1
bin 0:2:40 4 add
ret 0:2:33 1
block 0:2:31 1
end
""",
# Line 1, P = 1:1:9: L18 of hyp: `tmp .l1 = 3.0`, `tmp .l2 = 4.0`; the copy of hyp's body at P,
# in which each call of sq is itself rewritten by L18 (5): its `tmp` binds the copied argument
# (`lv .l1`, `lv .l2`, at P), its copy reads that tmp (.l3, .l4). Line 2: the argument of the outer
# sq (P2 = 1:2:9) is the call of hyp at P3 = 1:2:12, the caller's own code, keeping its position
# and rewritten by L18 itself (.l5, .l6 its parameters, .l7, .l8 its inner sq calls); then the
# outer sq's `tmp .l9` of that inline xblk. The .l locals are numbered in the order of their
# tmp records (file order). Both prelude functions are dropped.
"""
fn 1 .main main 1 0 11 1:1:1
loc r 4 let 1:1:5
loc z 4 let 1:2:5
loc .l1 4 let 1:1:9
loc .l2 4 let 1:1:9
loc .l3 4 let 1:1:9
loc .l4 4 let 1:1:9
loc .l5 4 let 1:2:12
loc .l6 4 let 1:2:12
loc .l7 4 let 1:2:12
loc .l8 4 let 1:2:12
loc .l9 4 let 1:2:9
cf 1:1:13 4 #4008000000000000
tmp 1:1:9 3
cf 1:1:18 4 #4010000000000000
tmp 1:1:9 4
lv 1:1:9 4 3
tmp 1:1:9 5
lv 1:1:9 4 5
lv 1:1:9 4 5
bin 1:1:9 4 mul
iret 1:1:9 1
block 1:1:9 1
iblk 1:1:9 4 1
xblk 1:1:9 4 1
lv 1:1:9 4 4
tmp 1:1:9 6
lv 1:1:9 4 6
lv 1:1:9 4 6
bin 1:1:9 4 mul
iret 1:1:9 1
block 1:1:9 1
iblk 1:1:9 4 1
xblk 1:1:9 4 1
bin 1:1:9 4 add
iret 1:1:9 1
block 1:1:9 1
iblk 1:1:9 4 1
xblk 1:1:9 4 2
bind 1:1:1 1
cf 1:2:16 4 #3FF0000000000000
tmp 1:2:12 7
cf 1:2:21 4 #4000000000000000
tmp 1:2:12 8
lv 1:2:12 4 7
tmp 1:2:12 9
lv 1:2:12 4 9
lv 1:2:12 4 9
bin 1:2:12 4 mul
iret 1:2:12 1
block 1:2:12 1
iblk 1:2:12 4 1
xblk 1:2:12 4 1
lv 1:2:12 4 8
tmp 1:2:12 10
lv 1:2:12 4 10
lv 1:2:12 4 10
bin 1:2:12 4 mul
iret 1:2:12 1
block 1:2:12 1
iblk 1:2:12 4 1
xblk 1:2:12 4 1
bin 1:2:12 4 add
iret 1:2:12 1
block 1:2:12 1
iblk 1:2:12 4 1
xblk 1:2:12 4 2
tmp 1:2:9 11
lv 1:2:9 4 11
lv 1:2:9 4 11
bin 1:2:9 4 mul
iret 1:2:9 1
block 1:2:9 1
iblk 1:2:9 4 1
xblk 1:2:9 4 1
bind 1:2:1 2
block 1:1:1 2
end
""",
# Line 1: the tmps of 3.0 and 4.0 (lf into .l1, .l2); do 1 (hyp's iblk); the operands of `bin
# add` have no destination, so each inner inline xblk's value is its R1 with no mov (R27): its
# tmp of `lv .l1` is T1's alias of .l1 (no instruction), do 2, fmul, mov R1, exit 2, enddo 2;
# the same as do 3; fadd; hyp's iret (mov R1, exit 1); enddo 1; mov r R1 (bind, R27).
# Line 2: the outer sq's statement `tmp .l9 = ` the inline xblk of hyp: under a tmp, .l9 is
# another name for hyp's R1 (R27, no mov); hyp's blocks 4, 5, 6 (in opening order), then the
# outer sq's do 7 reading .l9, and mov z R1.
"""
func .main main 1:1:1 0 0
lf f.a #4008000000000000
lf f.b #4010000000000000
do 1
do 2
fmul f.sa f.a f.a
mov f.r2 f.sa
exit 2
enddo 2
do 3
fmul f.sb f.b f.b
mov f.r3 f.sb
exit 3
enddo 3
fadd f.h f.r2 f.r3
mov f.r1 f.h
exit 1
enddo 1
mov f.r f.r1
lf f.c #3FF0000000000000
lf f.d #4000000000000000
do 4
do 5
fmul f.sc f.c f.c
mov f.r5 f.sc
exit 5
enddo 5
do 6
fmul f.sd f.d f.d
mov f.r6 f.sd
exit 6
enddo 6
fadd f.h4 f.r5 f.r6
mov f.r4 f.h4
exit 4
enddo 4
do 7
fmul f.s7 f.r4 f.r4
mov f.r7 f.s7
exit 7
enddo 7
mov f.z f.r7
ret 0
endfunc
""")


SRC['inl_nested'] = ("""fn sq(x: f64) -> f64 { return x * x }
fn hyp(a: f64, b: f64) -> f64 { return sq(a) + sq(b) }
""", """let r = hyp(3.0, 4.0)
let z = sq(hyp(1.0, 2.0))
""")


# ================================================================ inl_void (k = 0 under eval)
# file 0:  1 fn say(n: i64) {            fn 1, { 16
#          2     if n < 0 {              if 5, n 8, 0 12, { 14
#          3         return              return 9
#          4     }
#          5     printf("%d\n", n)       printf 5, " 12, n 20
#          6 }
# file 1:  1 say(7)                      say 1, 7 5
#          2 say(-1)                     say 1, -1 5 (pass 2b folded the negation, 3.5.7)
test('inl_void', """
fn 1 .main main 1 0 0 1:1:1
ci 1:1:5 3 7
call 1:1:1 1 2 1
eval 1:1:1
ci 1:2:5 3 -1
call 1:2:1 1 2 1
eval 1:2:1
block 1:1:1 2
end
fn 2 say fn 1 1 0 0:1:1
par n 3 val
lv 0:2:8 3 1
ci 0:2:12 3 0
bin 0:2:8 2 lt
ret 0:3:9 0
block 0:2:14 1
if 0:2:5 0
lv 0:5:20 3 1
fconv 0:5:12 1 - - - d
ftext 0:5:12 1 %0A
fmt 0:5:12 1 2
lib 0:5:5 1 printf 1
eval 0:5:5
block 0:1:16 2
end
""",
# Each call: xblk of type 1 (R26: only under eval) with the parameter's tmp, iblk ty 1 k 0;
# `ret 0` -> `iret 0`; the format pieces too take P.
"""
fn 1 .main main 1 0 2 1:1:1
loc .l1 3 let 1:1:1
loc .l2 3 let 1:2:1
ci 1:1:5 3 7
tmp 1:1:1 1
lv 1:1:1 3 1
ci 1:1:1 3 0
bin 1:1:1 2 lt
iret 1:1:1 0
block 1:1:1 1
if 1:1:1 0
lv 1:1:1 3 1
fconv 1:1:1 1 - - - d
ftext 1:1:1 1 %0A
fmt 1:1:1 1 2
lib 1:1:1 1 printf 1
eval 1:1:1
block 1:1:1 2
iblk 1:1:1 1 0
xblk 1:1:1 1 1
eval 1:1:1
ci 1:2:5 3 -1
tmp 1:2:1 2
lv 1:2:1 3 2
ci 1:2:1 3 0
bin 1:2:1 2 lt
iret 1:2:1 0
block 1:2:1 1
if 1:2:1 0
lv 1:2:1 3 2
fconv 1:2:1 1 - - - d
ftext 1:2:1 1 %0A
fmt 1:2:1 1 2
lib 1:2:1 1 printf 1
eval 1:2:1
block 1:2:1 2
iblk 1:2:1 1 0
xblk 1:2:1 1 1
eval 1:2:1
block 1:1:1 2
end
""",
# The tmp: li into .l1's register. do 1; the `if` (rule 4: block 2); the `iret 0`: no values, no
# releases (nothing inside the body holds counts), no mov, `exit 1` (R29; rule 37 (4)); the then
# block ends with the iret, so nothing follows it before `endif 2`. printf by rule 8 with the
# call's line as its site (every site of inlined code is the call's line, 3.6.4). The body
# block of a k = 0 iblk whose last statement is not an iret ends with its releases (none) and
# `exit 1`, then `enddo 1` (3.6.6 "Lowering of the sea.hirl records", 4h bullet). Under eval a
# void value needs nothing. Slots s1, s2 at the function's start (3.6.3); one fmt record per
# occurrence (rule 8), labels in order of first reference.
"""
func .main main 1:1:1 0 0
slot s1 8 8
slot s2 8 8
li i.n 7
do 1
li i.z 0
icmp lt i.c i.n i.z
if 2 i.c
exit 1
endif 2
sa p.s s1
sti i.n p.s - 0 0
la p.f d1
rcall sea_printf 1:1 0 2 p.f p.s
exit 1
enddo 1
li i.m -1
do 3
li i.z2 0
icmp lt i.c2 i.m i.z2
if 4 i.c2
exit 3
endif 4
sa p.s2 s2
sti i.m p.s2 - 0 0
la p.f2 d2
rcall sea_printf 1:2 0 2 p.f2 p.s2
exit 3
enddo 3
ret 0
endfunc
fmt d1 2
fconv - - - d i
ftext %0A
fmt d2 2
fconv - - - d i
ftext %0A
""")


SRC['inl_void'] = ("""fn say(n: i64) {
    if n < 0 {
        return
    }
    printf("%d\\n", n)
}
""", """say(7)
say(-1)
""")


# ================================================================ inl_multi (k = 2)
# file 0:  1 fn two(a: i64) -> (i64, i64) {      fn 1, { 30
#          2     return (a, a + 1)              return 5, a 13, a 16, 1 20
#          3 }
# file 1:  1 fn g(ref q: i64) -> (i64, i64) {    fn 1, q 10, { 32
#          2     var x = 0.0                    var 5, x 9, 0.0 13
#          3     (x, q) = two(5)                ( 5, x 6, q 9, two 14, 5 18
#          4     return two(q)                  return 5, two 12, q 16
#          5 }
#          6 let (a, _) = two(1)                let 1, a 6, _ 9, two 14, 1 18
#          7 var r = 0                          var 1, r 5, 0 9
#          8 let (c, d) = g(ref r)              let 1, c 6, d 9, g 14, ref 16, r 20
# Functions: .main 1, two 2, g 3 (in .hirl g becomes 2). Type 10 the ttuple (i64, i64).
test('inl_multi', """
ttuple 10 2 3 3
fn 1 .main main 1 0 4 1:1:1
loc a 3 let 1:6:6
loc r 3 var 1:7:5
loc c 3 let 1:8:6
loc d 3 let 1:8:9
ci 1:6:18 3 1
call 1:6:14 10 2 1
tbind 1:6:1 2 1 -
ci 1:7:9 3 0
bind 1:7:1 2
lv 1:8:20 3 2
rarg 1:8:16 3
call 1:8:14 10 3 1
tbind 1:8:1 2 3 4
block 1:1:1 3
end
fn 2 two fn 10 1 0 0:1:1
par a 3 val
lv 0:2:13 3 1
lv 0:2:16 3 1
ci 0:2:20 3 1
bin 0:2:16 3 add
ret 0:2:5 2
block 0:1:30 1
end
fn 3 g fn 10 1 1 1:1:1
par q 3 ref
loc x 4 var 1:2:9
cf 1:2:13 4 #0000000000000000
bind 1:2:5 2
lv 1:3:6 4 2
lv 1:3:9 3 1
ci 1:3:18 3 5
call 1:3:14 10 2 1
tasg 1:3:5 2 1 0
lv 1:4:16 3 1
call 1:4:12 10 2 1
tret 1:4:5
block 1:1:32 3
end
""",
# The inline xblks have the ttuple type 10 (R26: as the child of a tbind, a tasg and a tret);
# the iblk k 2; `ret 2` -> `iret 2`. The cv 1 component of the tasg stays (R10: a scalar cv 1).
# The call of g is renumbered 3 -> 2 (two dropped, L-v).
"""
ttuple 10 2 3 3
fn 1 .main main 1 0 5 1:1:1
loc a 3 let 1:6:6
loc r 3 var 1:7:5
loc c 3 let 1:8:6
loc d 3 let 1:8:9
loc .l1 3 let 1:6:14
ci 1:6:18 3 1
tmp 1:6:14 5
lv 1:6:14 3 5
lv 1:6:14 3 5
ci 1:6:14 3 1
bin 1:6:14 3 add
iret 1:6:14 2
block 1:6:14 1
iblk 1:6:14 10 2
xblk 1:6:14 10 1
tbind 1:6:1 2 1 -
ci 1:7:9 3 0
bind 1:7:1 2
lv 1:8:20 3 2
rarg 1:8:16 3
call 1:8:14 10 2 1
tbind 1:8:1 2 3 4
block 1:1:1 3
end
fn 2 g fn 10 1 3 1:1:1
par q 3 ref
loc x 4 var 1:2:9
loc .l1 3 let 1:3:14
loc .l2 3 let 1:4:12
cf 1:2:13 4 #0000000000000000
bind 1:2:5 2
lv 1:3:6 4 2
lv 1:3:9 3 1
ci 1:3:18 3 5
tmp 1:3:14 3
lv 1:3:14 3 3
lv 1:3:14 3 3
ci 1:3:14 3 1
bin 1:3:14 3 add
iret 1:3:14 2
block 1:3:14 1
iblk 1:3:14 10 2
xblk 1:3:14 10 1
tasg 1:3:5 2 1 0
lv 1:4:16 3 1
tmp 1:4:12 4
lv 1:4:12 3 4
lv 1:4:12 3 4
ci 1:4:12 3 1
bin 1:4:12 3 add
iret 1:4:12 2
block 1:4:12 1
iblk 1:4:12 10 2
xblk 1:4:12 10 1
tret 1:4:5
block 1:1:32 3
end
""",
# .main line 6: the tmp (li into .l1), do 1, the copy (iaddc with the call's line as site),
# iret 2: mov R1 V1, mov R2 V2 (R1, R2 numbered at the first mov), exit 1; enddo 1; under the
# tbind (R27) the movs into the locals first (a), the `_` an i64 that needs no release. Line 8
# is an ordinary call (rule 12: slot, store, call into c and d, reload).
# g line 3: the tasg (R27): the owned argument tmps released before the stores (none here),
# then each component stored as rule 2 (d) stores a call's new result register: cv 1 -> itof F
# R1, mov x F; the ref parameter q -> sti R2 q. Line 4: the tmp of `lv q` reads the ref
# parameter into .l2's register (T1: ldi); under the tret, the releases of rule 16 (c) (none:
# x is an f64), then ret 2 R1 R2. A function with results gets nothing after its last
# statement (rule 6).
"""
func .main main 1:1:1 0 0
slot s1 8 8
li i.a1 1
do 1
li i.o 1
iaddc i.s i.a1 i.o 1:6
mov i.R1 i.a1
mov i.R2 i.s
exit 1
enddo 1
mov i.a i.R1
li i.r 0
sa p.A s1
sti i.r p.A - 0 0
call g 2 i.c i.d 1 p.A
ldi i.r p.A - 0 0
ret 0
endfunc
func g fn 1:1:1 1 p.q 2 i i
lf f.x #0000000000000000
li i.five 5
do 1
li i.o 1
iaddc i.s i.five i.o 1:3
mov i.R1 i.five
mov i.R2 i.s
exit 1
enddo 1
itof f.F i.R1
mov f.x f.F
sti i.R2 p.q - 0 0
ldi i.b p.q - 0 0
do 2
li i.o2 1
iaddc i.s2 i.b i.o2 1:4
mov i.T1 i.b
mov i.T2 i.s2
exit 2
enddo 2
ret 2 i.T1 i.T2
endfunc
""")


SRC['inl_multi'] = ("""fn two(a: i64) -> (i64, i64) {
    return (a, a + 1)
}
""", """fn g(ref q: i64) -> (i64, i64) {
    var x = 0.0
    (x, q) = two(5)
    return two(q)
}
let (a, _) = two(1)
var r = 0
let (c, d) = g(ref r)
""")


# ================================================================ inl_loop_ret (iret in a loop)
# file 0:  1 fn firstneg(v: f64[]) -> f64 {     fn 1, { 30
#          2     let w = v                       let 5, w 9, v 13
#          3     for x in w {                    for 5, x 9, w 14, { 16
#          4         if x < 0.0 {                if 9, x 12, 0.0 16, { 20
#          5             return x                return 13, x 20
#          6         }
#          7     }
#          8     return 0.0                      return 5, 0.0 12
#          9 }
# file 1:  1 var u = zeros(3)                    var 1, u 5, zeros 9, 3 15
#          2 let m = firstneg(u)                 let 1, m 5, firstneg 9, u 18
test('inl_loop_ret', """
tvec 10 4
fn 1 .main main 1 0 2 1:1:1
loc u 10 var 1:1:5
loc m 4 let 1:2:5
ci 1:1:15 3 3
lib 1:1:9 10 zeros 1
bind 1:1:1 1
lv 1:2:18 10 1
call 1:2:9 4 2 1
bind 1:2:1 2
block 1:1:1 2
end
fn 2 firstneg fn 4 1 2 0:1:1
par v 10 val
loc w 10 let 0:2:9
loc x 4 for 0:3:9
lv 0:2:13 10 1
bind 0:2:5 2
lv 0:3:14 10 2
lv 0:4:12 4 3
cf 0:4:16 4 #0000000000000000
bin 0:4:12 2 lt
lv 0:5:20 4 3
ret 0:5:13 1
block 0:4:20 1
if 0:4:9 0
block 0:3:16 1
fore 0:3:5 3
cf 0:8:12 4 #0000000000000000
ret 0:8:5 1
block 0:1:30 3
end
""",
# P = 1:2:9. L1 rewrites zeros (anew, z 1). L18: `tmp .l1 = lv u`; the copy, with w and x
# replaced by the .i locals .i1 (its bind) and .i2 (the loop variable, which L4 binds by a tmp,
# R28), each of the local's type and mut at P; the copy's fore rewritten by L4 at P (H .l2, N
# .l3, Z .l4, D .l5, O .l6, L .l7, K .l8, in the order of their declaring records; tptr 11 4 for
# adat). The .l locals precede the .i locals (3.5.4).
"""
tvec 10 4
tptr 11 4
fn 1 .main main 1 0 12 1:1:1
loc u 10 var 1:1:5
loc m 4 let 1:2:5
loc .l1 10 let 1:2:9
loc .l2 10 let 1:2:9
loc .l3 3 let 1:2:9
loc .l4 3 let 1:2:9
loc .l5 11 let 1:2:9
loc .l6 3 let 1:2:9
loc .l7 3 let 1:2:9
loc .l8 3 for 1:2:9
loc .i1 10 let 1:2:9
loc .i2 4 for 1:2:9
ci 1:1:15 3 3
anew 1:1:9 10 1 1
bind 1:1:1 1
lv 1:2:18 10 1
tmp 1:2:9 3
lv 1:2:9 10 3
bind 1:2:9 11
lv 1:2:9 10 11
bind 1:2:9 4
lv 1:2:9 10 4
ext 1:2:9 3 0
tmp 1:2:9 5
ci 1:2:9 3 0
tmp 1:2:9 6
lv 1:2:9 3 5
lv 1:2:9 3 6
bin 1:2:9 2 gt
lv 1:2:9 10 4
adat 1:2:9 11
tmp 1:2:9 7
ci 1:2:9 3 1
tmp 1:2:9 8
lv 1:2:9 3 5
lv 1:2:9 3 8
wbin 1:2:9 3 sub
tmp 1:2:9 9
lv 1:2:9 3 6
lv 1:2:9 3 9
lv 1:2:9 3 8
lv 1:2:9 11 7
lv 1:2:9 3 10
eld 1:2:9 4 8 0
tmp 1:2:9 12
lv 1:2:9 4 12
cf 1:2:9 4 #0000000000000000
bin 1:2:9 2 lt
lv 1:2:9 4 12
iret 1:2:9 1
block 1:2:9 1
if 1:2:9 0
block 1:2:9 1
block 1:2:9 2
hloop 1:2:9 10
block 1:2:9 4
if 1:2:9 0
block 1:2:9 4
cf 1:2:9 4 #0000000000000000
iret 1:2:9 1
block 1:2:9 3
iblk 1:2:9 4 1
xblk 1:2:9 4 1
bind 1:2:1 2
block 1:1:1 2
end
""",
# zeros: arrnewz into u (rule 17). The inline xblk: `tmp .l1 = lv u` is T1's alias of u. do 1;
# `let w = v`: mov w u, retain w (rule 2, rule 15 (a)); L4 as rule 30's example: H held (mov,
# retain), the extent, the guard, the data, the loop (blocks 2, 3), x loaded; the `if` block 4;
# the iret inside the loop: its value is an f64; R29 releases the bound locals of every block
# it leaves inside the iblk, innermost first: H (L4's block), then w (the body block); then mov
# R1 x, exit 1. After the loop L4's block ends with the release of H. The last iret: the 0.0,
# the release of w (the body block, rule 16 (c)), mov R1 (the same R1: numbered at the iblk's
# first iret's mov), exit 1. No releases at the end of the body block of an iblk with k = 1
# (R29). Then mov m R1 (R27), and at the end of .main the release of u.
"""
func .main main 1:1:1 0 0
li i.three 3
li i.k 1
li i.rk 1
li i.c 1
rcall sea_arr_new 1:1 1 p.u 4 i.k i.rk i.three i.c
do 1
mov p.w p.u
retain p.w
mov p.H p.w
retain p.H
ldi i.N p.H - 0 16
li i.Z 0
icmp gt i.E i.N i.Z
if 2 i.E
ldp p.D p.H - 0 40
li i.O 1
isub i.L i.N i.O
loop 3 i.K i.Z i.L i.O
ldf f.x p.D i.K 8 0
lf f.z #0000000000000000
fcmp lt i.lt f.x f.z
if 4 i.lt
release p.H
release p.w
mov f.R1 f.x
exit 1
endif 4
endloop 3
endif 2
release p.H
lf f.z2 #0000000000000000
release p.w
mov f.R1 f.z2
exit 1
enddo 1
mov f.m f.R1
release p.u
ret 0
endfunc
""")


SRC['inl_loop_ret'] = ("""fn firstneg(v: f64[]) -> f64 {
    let w = v
    for x in w {
        if x < 0.0 {
            return x
        }
    }
    return 0.0
}
""", """var u = zeros(3)
let m = firstneg(u)
""")


# ================================================================ inl_owned_arg (owned arguments)
# file 0:  1 fn count(v: f64[]) -> i64 {          fn 1, { 27
#          2     return len(v)                     return 5, len 12, v 16
#          3 }
#          4 fn dims(v: f64[]) -> (i64, i64) {    fn 1, { 33
#          5     return (len(v), len(v) + 1)       return 5, len 13, v 17, len 21, v 25, 1 30
#          6 }
#          7 fn same(v: f64[]) -> f64[] {          fn 1, { 28
#          8     return v                          return 5, v 12
#          9 }
# file 1:  1 let n = count(zeros(2))              let 1, n 5, count 9, zeros 15, 2 21
#          2 let (r, c) = dims(zeros(3))          let 1, r 6, c 9, dims 14, zeros 19, 3 25
#          3 same(zeros(4))                       same 1, zeros 6, 4 12
# Functions: .main 1, count 2, dims 3, same 4. Types by first reference: 10 f64[], 11 the ttuple.
test('inl_owned_arg', """
tvec 10 4
ttuple 11 2 3 3
fn 1 .main main 1 0 3 1:1:1
loc n 3 let 1:1:5
loc r 3 let 1:2:6
loc c 3 let 1:2:9
ci 1:1:21 3 2
lib 1:1:15 10 zeros 1
call 1:1:9 3 2 1
bind 1:1:1 1
ci 1:2:25 3 3
lib 1:2:19 10 zeros 1
call 1:2:14 11 3 1
tbind 1:2:1 2 2 3
ci 1:3:12 3 4
lib 1:3:6 10 zeros 1
call 1:3:1 10 4 1
eval 1:3:1
block 1:1:1 3
end
fn 2 count fn 3 1 0 0:1:1
par v 10 val
lv 0:2:16 10 1
lib 0:2:12 3 len 1
ret 0:2:5 1
block 0:1:27 1
end
fn 3 dims fn 11 1 0 0:4:1
par v 10 val
lv 0:5:17 10 1
lib 0:5:13 3 len 1
lv 0:5:25 10 1
lib 0:5:21 3 len 1
ci 0:5:30 3 1
bin 0:5:21 3 add
ret 0:5:5 2
block 0:4:33 1
end
fn 4 same fn 10 1 0 0:7:1
par v 10 val
lv 0:8:12 10 1
ret 0:8:5 1
block 0:7:28 1
end
""",
# Each argument is `zeros` (L1: an owned anew) bound by the inline xblk's tmp; the copies' len
# by L3 (`ext P 3 0`). P1 = 1:1:9, P2 = 1:2:14, P3 = 1:3:1.
"""
tvec 10 4
ttuple 11 2 3 3
fn 1 .main main 1 0 6 1:1:1
loc n 3 let 1:1:5
loc r 3 let 1:2:6
loc c 3 let 1:2:9
loc .l1 10 let 1:1:9
loc .l2 10 let 1:2:14
loc .l3 10 let 1:3:1
ci 1:1:21 3 2
anew 1:1:15 10 1 1
tmp 1:1:9 4
lv 1:1:9 10 4
ext 1:1:9 3 0
iret 1:1:9 1
block 1:1:9 1
iblk 1:1:9 3 1
xblk 1:1:9 3 1
bind 1:1:1 1
ci 1:2:25 3 3
anew 1:2:19 10 1 1
tmp 1:2:14 5
lv 1:2:14 10 5
ext 1:2:14 3 0
lv 1:2:14 10 5
ext 1:2:14 3 0
ci 1:2:14 3 1
bin 1:2:14 3 add
iret 1:2:14 2
block 1:2:14 1
iblk 1:2:14 11 2
xblk 1:2:14 11 1
tbind 1:2:1 2 2 3
ci 1:3:12 3 4
anew 1:3:6 10 1 1
tmp 1:3:1 6
lv 1:3:1 10 6
iret 1:3:1 1
block 1:3:1 1
iblk 1:3:1 10 1
xblk 1:3:1 10 1
eval 1:3:1
block 1:1:1 3
end
""",
# Line 1: arrnewz into .l1's register (T1: the child with L's register as destination); do 1;
# the extent; iret (mov R1, exit 1); enddo 1; mov n R1 (the bind's destination, R27); then T2:
# the owned argument tmp released right after the xblk's value, after the mov (R26).
# Line 2: under the tbind the movs into r and c first, then the release of the argument (R27).
# Line 3: same's `return v` returns a borrowed parameter, so the iret owns it first (rule 15
# (a): retain), mov R1, exit 3; T2 releases the argument after the value; under the eval the
# owned R1 is released right after the statement (R27, rule 15 (h)).
"""
func .main main 1:1:1 0 0
li i.two 2
li i.k1 1
li i.n1 1
li i.c1 1
rcall sea_arr_new 1:1 1 p.a 4 i.k1 i.n1 i.two i.c1
do 1
ldi i.e p.a - 0 16
mov i.R1 i.e
exit 1
enddo 1
mov i.n i.R1
release p.a
li i.three 3
li i.k2 1
li i.n2 1
li i.c2 1
rcall sea_arr_new 1:2 1 p.b 4 i.k2 i.n2 i.three i.c2
do 2
ldi i.e1 p.b - 0 16
ldi i.e2 p.b - 0 16
li i.o 1
iaddc i.s i.e2 i.o 1:2
mov i.R1b i.e1
mov i.R2b i.s
exit 2
enddo 2
mov i.r i.R1b
mov i.c i.R2b
release p.b
li i.four 4
li i.k3 1
li i.n3 1
li i.c3 1
rcall sea_arr_new 1:3 1 p.d 4 i.k3 i.n3 i.four i.c3
do 3
retain p.d
mov p.R1c p.d
exit 3
enddo 3
release p.d
release p.R1c
ret 0
endfunc
""")


SRC['inl_owned_arg'] = ("""fn count(v: f64[]) -> i64 {
    return len(v)
}
fn dims(v: f64[]) -> (i64, i64) {
    return (len(v), len(v) + 1)
}
fn same(v: f64[]) -> f64[] {
    return v
}
""", """let n = count(zeros(2))
let (r, c) = dims(zeros(3))
same(zeros(4))
""")


# ================================================================ inl_dest (R27's destinations)
# file 0:  1 fn half(x: f64) -> f64 { return x / 2.0 }      { 24, return 26, x 33, 2.0 37
#          2 fn keep(v: f64[]) -> f64[] { return v }         { 28, return 30, v 37
# file 1:  1 fn setq(ref q: f64) {                fn 1, q 13, { 21
#          2     q = half(q)                       q 5, half 9, q 14
#          3 }
#          4 var x = half(half(8.0))              var 1, x 5, half 9, half 14, 8.0 19
#          5 x = half(x)                          x 1, half 5, x 10
#          6 let c = x > 1.0                      let 1, c 5, x 9, 1.0 13
#          7 let y = if c { half(x) } else { 0.0 }
#                                                 let 1, y 5, if 9, c 12, half 16, x 21, 0.0 33
#          8 var v = zeros(2)                     var 1, v 5, zeros 9, 2 15
#          9 v = keep(v)                          v 1, keep 5, v 10
#         10 setq(ref x)                          setq 1, ref 6, x 10
# Functions: .main 1, half 2, keep 3, setq 4 (setq becomes 2).
test('inl_dest', """
tvec 10 4
fn 1 .main main 1 0 4 1:1:1
loc x 4 var 1:4:5
loc c 2 let 1:6:5
loc y 4 let 1:7:5
loc v 10 var 1:8:5
cf 1:4:19 4 #4020000000000000
call 1:4:14 4 2 1
call 1:4:9 4 2 1
bind 1:4:1 1
lv 1:5:1 4 1
lv 1:5:10 4 1
call 1:5:5 4 2 1
asg 1:5:1 set
lv 1:6:9 4 1
cf 1:6:13 4 #3FF0000000000000
bin 1:6:9 2 gt
bind 1:6:1 2
lv 1:7:12 2 2
lv 1:7:21 4 1
call 1:7:16 4 2 1
cf 1:7:33 4 #0000000000000000
ifx 1:7:9 4
bind 1:7:1 3
ci 1:8:15 3 2
lib 1:8:9 10 zeros 1
bind 1:8:1 4
lv 1:9:1 10 4
lv 1:9:10 10 4
call 1:9:5 10 3 1
asg 1:9:1 set
lv 1:10:10 4 1
rarg 1:10:6 4
call 1:10:1 1 4 1
eval 1:10:1
block 1:1:1 7
end
fn 2 half fn 4 1 0 0:1:1
par x 4 val
lv 0:1:33 4 1
cf 0:1:37 4 #4000000000000000
bin 0:1:33 4 div
ret 0:1:26 1
block 0:1:24 1
end
fn 3 keep fn 10 1 0 0:2:1
par v 10 val
lv 0:2:37 10 1
ret 0:2:30 1
block 0:2:28 1
end
fn 4 setq fn 1 1 0 1:1:1
par q 4 ref
lv 1:2:5 4 1
lv 1:2:14 4 1
call 1:2:9 4 2 1
asg 1:2:5 set
block 1:1:21 1
end
""",
# Line 4: the inner call (P 1:4:14) is the outer's argument, rewritten by L18 first in file
# order (.l1), then the outer's tmp of it (.l2, P 1:4:9). Lines 5, 7, 9 and setq's line 2 each
# one inline call (.l3 at 1:5:5, .l4 at 1:7:16, .l5 at 1:9:5; setq's .l1 at 1:2:9).
"""
tvec 10 4
fn 1 .main main 1 0 9 1:1:1
loc x 4 var 1:4:5
loc c 2 let 1:6:5
loc y 4 let 1:7:5
loc v 10 var 1:8:5
loc .l1 4 let 1:4:14
loc .l2 4 let 1:4:9
loc .l3 4 let 1:5:5
loc .l4 4 let 1:7:16
loc .l5 10 let 1:9:5
cf 1:4:19 4 #4020000000000000
tmp 1:4:14 5
lv 1:4:14 4 5
cf 1:4:14 4 #4000000000000000
bin 1:4:14 4 div
iret 1:4:14 1
block 1:4:14 1
iblk 1:4:14 4 1
xblk 1:4:14 4 1
tmp 1:4:9 6
lv 1:4:9 4 6
cf 1:4:9 4 #4000000000000000
bin 1:4:9 4 div
iret 1:4:9 1
block 1:4:9 1
iblk 1:4:9 4 1
xblk 1:4:9 4 1
bind 1:4:1 1
lv 1:5:1 4 1
lv 1:5:10 4 1
tmp 1:5:5 7
lv 1:5:5 4 7
cf 1:5:5 4 #4000000000000000
bin 1:5:5 4 div
iret 1:5:5 1
block 1:5:5 1
iblk 1:5:5 4 1
xblk 1:5:5 4 1
asg 1:5:1 set
lv 1:6:9 4 1
cf 1:6:13 4 #3FF0000000000000
bin 1:6:9 2 gt
bind 1:6:1 2
lv 1:7:12 2 2
lv 1:7:21 4 1
tmp 1:7:16 8
lv 1:7:16 4 8
cf 1:7:16 4 #4000000000000000
bin 1:7:16 4 div
iret 1:7:16 1
block 1:7:16 1
iblk 1:7:16 4 1
xblk 1:7:16 4 1
cf 1:7:33 4 #0000000000000000
ifx 1:7:9 4
bind 1:7:1 3
ci 1:8:15 3 2
anew 1:8:9 10 1 1
bind 1:8:1 4
lv 1:9:1 10 4
lv 1:9:10 10 4
tmp 1:9:5 9
lv 1:9:5 10 9
iret 1:9:5 1
block 1:9:5 1
iblk 1:9:5 10 1
xblk 1:9:5 10 1
asg 1:9:1 set
lv 1:10:10 4 1
rarg 1:10:6 4
call 1:10:1 1 2 1
eval 1:10:1
block 1:1:1 7
end
fn 2 setq fn 1 1 1 1:1:1
par q 4 ref
loc .l1 4 let 1:2:9
lv 1:2:5 4 1
lv 1:2:14 4 1
tmp 1:2:9 2
lv 1:2:9 4 2
cf 1:2:9 4 #4000000000000000
bin 1:2:9 4 div
iret 1:2:9 1
block 1:2:9 1
iblk 1:2:9 4 1
xblk 1:2:9 4 1
asg 1:2:5 set
block 1:1:21 1
end
""",
# Line 4 (bind): the outer xblk's statement `tmp .l2 = ` the inner inline xblk: under a tmp,
# .l2 is another name for the inner R1, no mov (R27); the outer's iblk, then `mov x R1` (the
# bind's destination). Line 5 (asg set to a scalar local, rule 2's destination): `tmp .l3 =
# lv x` is T1's alias of x; mov x R1 after enddo. Line 6: fcmp into c. Line 7: the ifx root of
# y's bind is computed into its new register R (rule 3), then mov y R (rule 2); its then arm
# has the destination R: mov R R1 after enddo (R27); its else arm's constant is an lf into R.
# Line 9 (asg set to a reference local): the iret owns the borrowed parameter (retain), and
# rule 15 (d)'s new register V is R1: release v, mov v R1. Line 10: rule 12 (slot, stf, call,
# ldf). .main's end releases v (rule 16 (a)).
# setq: the tmp of `lv q` (a ref parameter) is its ldf into .l1's register (T1); the asg set
# to the scalar ref parameter stores R1 (stf R1 q, as rule 2 stores a call's result there).
"""
func .main main 1:1:1 0 0
slot s1 8 8
lf f.e #4020000000000000
do 1
lf f.t1 #4000000000000000
fdiv f.q1 f.e f.t1
mov f.R1 f.q1
exit 1
enddo 1
do 2
lf f.t2 #4000000000000000
fdiv f.q2 f.R1 f.t2
mov f.R2 f.q2
exit 2
enddo 2
mov f.x f.R2
do 3
lf f.t3 #4000000000000000
fdiv f.q3 f.x f.t3
mov f.R3 f.q3
exit 3
enddo 3
mov f.x f.R3
lf f.one #3FF0000000000000
fcmp gt i.c f.x f.one
if 4 i.c
do 5
lf f.t5 #4000000000000000
fdiv f.q5 f.x f.t5
mov f.R5 f.q5
exit 5
enddo 5
mov f.Rx f.R5
else 4
lf f.Rx #0000000000000000
endif 4
mov f.y f.Rx
li i.two 2
li i.k 1
li i.rk 1
li i.cc 1
rcall sea_arr_new 1:8 1 p.v 4 i.k i.rk i.two i.cc
do 6
retain p.v
mov p.R6 p.v
exit 6
enddo 6
release p.v
mov p.v p.R6
sa p.A s1
stf f.x p.A - 0 0
call setq 0 1 p.A
ldf f.x p.A - 0 0
release p.v
ret 0
endfunc
func setq fn 1:1:1 1 p.q 0
ldf f.a p.q - 0 0
do 1
lf f.t #4000000000000000
fdiv f.d f.a f.t
mov f.R f.d
exit 1
enddo 1
stf f.R p.q - 0 0
ret 0
endfunc
""")


SRC['inl_dest'] = ("""fn half(x: f64) -> f64 { return x / 2.0 }
fn keep(v: f64[]) -> f64[] { return v }
""", """fn setq(ref q: f64) {
    q = half(q)
}
var x = half(half(8.0))
x = half(x)
let c = x > 1.0
let y = if c { half(x) } else { 0.0 }
var v = zeros(2)
v = keep(v)
setq(ref x)
""")


# ================================================================ inl_rule12 (rule 12, R30)
# file 0:  1 fn cnt(a: f64[], b: i64) -> i64 { return len(a) + b }
#                        { 33, return 35, len 42, a 46, b 51
#          2 fn add(a: i64, b: i64) -> i64 { return a + b }     { 31, return 33, a 40, b 44
# file 1:  1 fn grow(ref w: f64[]) -> i64 {        fn 1, { 30
#          2     return 3                          return 5, 3 12
#          3 }
#          4 fn bump(ref k: i64) -> i64 {          fn 1, { 28
#          5     k += 1                            k 5, 1 10
#          6     return 10                         return 5, 10 12
#          7 }
#          8 var v = zeros(2)                     var 1, v 5, zeros 9, 2 15
#          9 let m = cnt(v, grow(ref v))          let 1, m 5, cnt 9, v 13, grow 16, ref 21, v 25
#         10 var n = 1                            var 1, n 5, 1 9
#         11 let s = add(n, bump(ref n))          let 1, s 5, add 9, n 13, bump 16, ref 21, n 25
# Functions: .main 1, cnt 2, add 3, grow 4, bump 5 (grow and bump become 2 and 3).
test('inl_rule12', """
tvec 10 4
fn 1 .main main 1 0 4 1:1:1
loc v 10 var 1:8:5
loc m 3 let 1:9:5
loc n 3 var 1:10:5
loc s 3 let 1:11:5
ci 1:8:15 3 2
lib 1:8:9 10 zeros 1
bind 1:8:1 1
lv 1:9:13 10 1
lv 1:9:25 10 1
rarg 1:9:21 10
call 1:9:16 3 4 1
call 1:9:9 3 2 2
bind 1:9:1 2
ci 1:10:9 3 1
bind 1:10:1 3
lv 1:11:13 3 3
lv 1:11:25 3 3
rarg 1:11:21 3
call 1:11:16 3 5 1
call 1:11:9 3 3 2
bind 1:11:1 4
block 1:1:1 4
end
fn 2 cnt fn 3 2 0 0:1:1
par a 10 val
par b 3 val
lv 0:1:46 10 1
lib 0:1:42 3 len 1
lv 0:1:51 3 2
bin 0:1:42 3 add
ret 0:1:35 1
block 0:1:33 1
end
fn 3 add fn 3 2 0 0:2:1
par a 3 val
par b 3 val
lv 0:2:40 3 1
lv 0:2:44 3 2
bin 0:2:40 3 add
ret 0:2:33 1
block 0:2:31 1
end
fn 4 grow fn 3 1 0 1:1:1
par w 10 ref
ci 1:2:12 3 3
ret 1:2:5 1
block 1:1:30 1
end
fn 5 bump fn 3 1 0 1:4:1
par k 3 ref
lv 1:5:5 3 1
ci 1:5:10 3 1
asg 1:5:5 add
ci 1:6:12 3 10
ret 1:6:5 1
block 1:4:28 2
end
""",
# L18 moves no call and no rarg: each argument, the call of grow (bump) included, is the child
# of its parameter's tmp, in order. P1 = 1:9:9 (.l1 a, .l2 b), P2 = 1:11:9 (.l3, .l4).
"""
tvec 10 4
fn 1 .main main 1 0 8 1:1:1
loc v 10 var 1:8:5
loc m 3 let 1:9:5
loc n 3 var 1:10:5
loc s 3 let 1:11:5
loc .l1 10 let 1:9:9
loc .l2 3 let 1:9:9
loc .l3 3 let 1:11:9
loc .l4 3 let 1:11:9
ci 1:8:15 3 2
anew 1:8:9 10 1 1
bind 1:8:1 1
lv 1:9:13 10 1
tmp 1:9:9 5
lv 1:9:25 10 1
rarg 1:9:21 10
call 1:9:16 3 2 1
tmp 1:9:9 6
lv 1:9:9 10 5
ext 1:9:9 3 0
lv 1:9:9 3 6
bin 1:9:9 3 add
iret 1:9:9 1
block 1:9:9 1
iblk 1:9:9 3 1
xblk 1:9:9 3 2
bind 1:9:1 2
ci 1:10:9 3 1
bind 1:10:1 3
lv 1:11:13 3 3
tmp 1:11:9 7
lv 1:11:25 3 3
rarg 1:11:21 3
call 1:11:16 3 3 1
tmp 1:11:9 8
lv 1:11:9 3 7
lv 1:11:9 3 8
bin 1:11:9 3 add
iret 1:11:9 1
block 1:11:9 1
iblk 1:11:9 3 1
xblk 1:11:9 3 2
bind 1:11:1 4
block 1:1:1 4
end
fn 2 grow fn 3 1 0 1:1:1
par w 10 ref
ci 1:2:12 3 3
ret 1:2:5 1
block 1:1:30 1
end
fn 3 bump fn 3 1 0 1:4:1
par k 3 ref
lv 1:5:5 3 1
ci 1:5:10 3 1
asg 1:5:5 add
ci 1:6:12 3 10
ret 1:6:5 1
block 1:4:28 2
end
""",
# Line 9: the read of v (the first parameter's tmp) comes before the later tmp's call, which
# passes v by ref, and is consumed after it (by the iblk): rule 12 (a) through R30: mov T v,
# retain T; the tmp names T (no T1 alias) and T is an owned tmp. The second tmp: rule 31's
# rarg of a reference local (slot, stp, call into .l2's register, ldp reload). The iblk reads
# the old v through T. After `mov m R1`, T2 releases the owned tmp T.
# Line 11: the scalar read of n before bump(ref n): rule 12's copy mov T n into the
# parameter's register; the call with its slot and reload; the copy sees the old n.
# grow and bump as written (grow ignores w; bump's `k += 1` loads, adds, stores; rule 12).
"""
func .main main 1:1:1 0 0
slot s1 8 8
slot s2 8 8
li i.two 2
li i.k 1
li i.rk 1
li i.c 1
rcall sea_arr_new 1:8 1 p.v 4 i.k i.rk i.two i.c
mov p.T p.v
retain p.T
sa p.A s1
stp p.v p.A - 0 0
call grow 1 i.g 1 p.A
ldp p.v p.A - 0 0
do 1
ldi i.e p.T - 0 16
iaddc i.s i.e i.g 1:9
mov i.R1 i.s
exit 1
enddo 1
mov i.m i.R1
release p.T
li i.n 1
mov i.T2 i.n
sa p.B s2
sti i.n p.B - 0 0
call bump 1 i.b 1 p.B
ldi i.n p.B - 0 0
do 2
iaddc i.s2 i.T2 i.b 1:11
mov i.R2 i.s2
exit 2
enddo 2
mov i.ss i.R2
release p.v
ret 0
endfunc
func grow fn 1:1:1 1 p.w 1 i
li i.three 3
ret 1 i.three
endfunc
func bump fn 1:4:1 1 p.k 1 i
ldi i.a p.k - 0 0
li i.o 1
iaddc i.b i.a i.o 1:5
sti i.b p.k - 0 0
li i.ten 10
ret 1 i.ten
endfunc
""")


SRC['inl_rule12'] = ("""fn cnt(a: f64[], b: i64) -> i64 { return len(a) + b }
fn add(a: i64, b: i64) -> i64 { return a + b }
""", """fn grow(ref w: f64[]) -> i64 {
    return 3
}
fn bump(ref k: i64) -> i64 {
    k += 1
    return 10
}
var v = zeros(2)
let m = cnt(v, grow(ref v))
var n = 1
let s = add(n, bump(ref n))
""")


# ================================================================ inl_scope (the iblk bound, R26)
# file 0:  1 fn find1(v: f64[]) -> i64 {          fn 1, { 27
#          2     for k in 0..len(v) {             for 5, k 9, 0 14, len 17, v 21, { 24
#          3         match str(k) {               match 9, str 15, k 19
#          4             "1" => { return k }      "1" 13, { 20, return 22, k 29
#          5             _ => { }                 _ 13, { 18
#          6         }
#          7     }
#          8     return 0                         return 5, 0 12
#          9 }
# file 1:  1 let j = find1(zeros(3))              let 1, j 5, find1 9, zeros 15, 3 21
# Types by first reference: 10 f64[] (.main's zeros), 11 i64[] (the range of the for).
test('inl_scope', """
tvec 10 4
tvec 11 3
fn 1 .main main 1 0 1 1:1:1
loc j 3 let 1:1:5
ci 1:1:21 3 3
lib 1:1:15 10 zeros 1
call 1:1:9 3 2 1
bind 1:1:1 1
block 1:1:1 1
end
fn 2 find1 fn 3 1 1 0:1:1
par v 10 val
loc k 3 for 0:2:9
ci 0:2:14 3 0
lv 0:2:21 10 1
lib 0:2:17 3 len 1
rng 0:2:14 11 0 0
lv 0:3:19 3 2
lib 0:3:15 5 str 1
cs 0:4:13 5 1
lv 0:4:29 3 2
ret 0:4:22 1
block 0:4:20 1
arm 0:4:13 1
block 0:5:18 0
arm 0:5:13 0
match 0:3:9 2
block 0:2:24 1
forr 0:2:5 2
ci 0:8:12 3 0
ret 0:8:5 1
block 0:1:27 2
end
""",
# P = 1:1:9. L18: `tmp .l1 = ` the zeros (L1); in the copy the loop variable k becomes .i1
# (declared by the forr), the range's len is L3's ext, and the match is L16's `block P 2` {
# `tmp .l2 = lib str (lv .i1)`; `if P 1` (bin eq of .l2 and the cs) with the arm's block and
# the `_` arm's block as its else }.
"""
tvec 10 4
tvec 11 3
fn 1 .main main 1 0 4 1:1:1
loc j 3 let 1:1:5
loc .l1 10 let 1:1:9
loc .l2 5 let 1:1:9
loc .i1 3 for 1:1:9
ci 1:1:21 3 3
anew 1:1:15 10 1 1
tmp 1:1:9 2
ci 1:1:9 3 0
lv 1:1:9 10 2
ext 1:1:9 3 0
rng 1:1:9 11 0 0
lv 1:1:9 3 4
lib 1:1:9 5 str 1
tmp 1:1:9 3
lv 1:1:9 5 3
cs 1:1:9 5 1
bin 1:1:9 2 eq
lv 1:1:9 3 4
iret 1:1:9 1
block 1:1:9 1
block 1:1:9 0
if 1:1:9 1
block 1:1:9 2
block 1:1:9 1
forr 1:1:9 4
ci 1:1:9 3 0
iret 1:1:9 1
block 1:1:9 2
iblk 1:1:9 3 1
xblk 1:1:9 3 1
bind 1:1:1 1
block 1:1:1 1
end
""",
# zeros into .l1's register (T1). do 1; the forr (rule 4: rcount with the call's line, if 2,
# loop 3); L16's tmp .l2: the owned rcall sea_str_i64. Because the iblk bounds the search
# (R26), .l2 is a temporary of L16's block inside the body (R11, R22), not of the inline xblk
# around the call: the comparison (rule 32), if 4; the iret leaves L16's block, so it releases
# .l2 (R29: the owned tmps of the blocks it leaves inside the iblk), then mov R1 k, exit 1; the
# `_` arm is empty; after endif 4 the end of L16's block releases .l2 (R11). The last iret: mov
# R1 (the same R1), exit 1. Then mov j R1, and the inline xblk releases only its own owned tmp
# .l1 (T2).
"""
func .main main 1:1:1 0 0
li i.three 3
li i.k1 1
li i.n1 1
li i.c1 1
rcall sea_arr_new 1:1 1 p.a 4 i.k1 i.n1 i.three i.c1
do 1
li i.lo 0
ldi i.hi p.a - 0 16
li i.st 1
rcount i.C i.E i.lo i.hi i.st 0 1:1
if 2 i.E
loop 3 i.k i.lo i.C i.st
rcall sea_str_i64 1:1 1 p.s 1 i.k
la p.d d1
rcall sea_str_cmp - 1 i.q 2 p.s p.d
li i.z 0
icmp eq i.eq i.q i.z
if 4 i.eq
release p.s
mov i.R1 i.k
exit 1
else 4
endif 4
release p.s
endloop 3
endif 2
li i.zero 0
mov i.R1 i.zero
exit 1
enddo 1
mov i.j i.R1
release p.a
ret 0
endfunc
str d1 1
""")


SRC['inl_scope'] = ("""fn find1(v: f64[]) -> i64 {
    for k in 0..len(v) {
        match str(k) {
            "1" => { return k }
            _ => { }
        }
    }
    return 0
}
""", """let j = find1(zeros(3))
""")


# ================================================================ the NAME.prelude dumps (Decision 57)
# Built with the real prelude: file 0 is std/std.sea as committed by WP-STD (its `#file` record
# written `#file std.sea`, 6.2), file 1 the program. Pass 2b keeps only the prelude functions
# the program reaches and renumbers them (3.5.7 step 5), so each .hir holds .main and the one
# prelude function called, at its positions in std.sea; the .hirl drops it (L18).
with open(os.path.join(ROOT, 'std', 'std.sea')) as _fh:
    STD = _fh.read()
PRELUDE = {}        # name -> (program text, kinds written, expected output)


def std_line(text):
    """The line number of `text` in std.sea (it must occur exactly once)."""
    ls = STD.split('\n')
    hits = [k + 1 for k, ln in enumerate(ls) if ln == text]
    assert len(hits) == 1, text
    return hits[0]


def prelude_test(name, sea, kinds, out, hir, hirl, lir1):
    TESTS[name] = {'hir': dump2(name, hir), 'hirl': dump2(name, hirl),
                   'lir1': dump2(name, number_regs(lir1))}
    SRC[name] = (STD, sea)
    PRELUDE[name] = (sea, kinds, out)


# ---------------------------------------------------------------- prel_bincount
# std.sea (the lines found below):  fn bincount(idx: i64[], n: i64) -> i64[] {     fn 1, { 42
#                                       var c = filled(0, n)                        var 5, c 9, filled 13, 0 20, n 23
#                                       for v in idx {                              for 5, v 9, idx 14, { 18
#                                           c[v] += 1                               c 9, v 11, 1 17
#                                       }
#                                       return c                                    return 5, c 12
#                                   }
# program:  4 let v = filled(2, 2)                      let 1, v 5, filled 9, 2 16, 2 19
#           5 let c = bincount(v, 3)                    let 1, c 5, bincount 9, v 18, 3 21
#           6 printf("%d %d %d\n", c[0], c[1], c[2])    printf 1, " 8, c 22 (0 24), c 28 (1 30),
#                                                       c 34 (2 36)
BC = std_line('fn bincount(idx: i64[], n: i64) -> i64[] {')
assert STD.split('\n')[BC:BC + 6] == ['    var c = filled(0, n)', '    for v in idx {',
                                      '        c[v] += 1', '    }', '    return c', '}']
prelude_test('prel_bincount', """// prel_bincount -- DESIGN.md 6.2 (4h, NAME.prelude): one call of the prelude's bincount, inlined
// by 3.6.6 rule 37: in its copy filled (L2), the element loop over idx (L4) and the compound
// element store c[v] += 1 (rule 19); counts of [2, 2] in 0 ... 2
let v = filled(2, 2)
let c = bincount(v, 3)
printf("%d %d %d\\n", c[0], c[1], c[2])
""", ('hir', 'hirl', 'lir1'), '0 0 2\n', """
tvec 10 3
fn 1 .main main 1 0 2 1:1:1
loc v 10 let 1:4:5
loc c 10 let 1:5:5
ci 1:4:16 3 2
ci 1:4:19 3 2
lib 1:4:9 10 filled 2
bind 1:4:1 1
lv 1:5:18 10 1
ci 1:5:21 3 3
call 1:5:9 10 2 2
bind 1:5:1 2
lv 1:6:22 10 2
ci 1:6:24 3 0
idx 1:6:22 3 1
fconv 1:6:8 1 - - - d
ftext 1:6:8 1 %20
lv 1:6:28 10 2
ci 1:6:30 3 1
idx 1:6:28 3 1
fconv 1:6:8 1 - - - d
ftext 1:6:8 1 %20
lv 1:6:34 10 2
ci 1:6:36 3 2
idx 1:6:34 3 1
fconv 1:6:8 1 - - - d
ftext 1:6:8 1 %0A
fmt 1:6:8 1 6
lib 1:6:1 1 printf 1
eval 1:6:1
block 1:1:1 3
end
fn 2 bincount fn 10 2 2 0:{0}:1
par idx 10 val
par n 3 val
loc c 10 var 0:{1}:9
loc v 3 for 0:{2}:9
ci 0:{1}:20 3 0
lv 0:{1}:23 3 2
lib 0:{1}:13 10 filled 2
bind 0:{1}:5 3
lv 0:{2}:14 10 1
lv 0:{3}:9 10 3
lv 0:{3}:11 3 4
idx 0:{3}:9 3 1
ci 0:{3}:17 3 1
asg 0:{3}:9 add
block 0:{2}:18 1
fore 0:{2}:5 4
lv 0:{5}:12 10 3
ret 0:{5}:5 1
block 0:{0}:42 3
end
""".format(BC, BC + 1, BC + 2, BC + 3, BC + 4, BC + 5),
# Line 4: L2 of filled(2, 2) at 1:4:9 (V .l1, R .l2, A .l3, D .l4, Z .l5, O .l6, L .l7, K .l8;
# tptr 11 3). Line 5: L18 at P = 1:5:9: `tmp .l9 = lv v` (idx), `tmp .l10 = 3` (n); the copy:
# c's bind (.i1) of L2's xblk for filled(0, n) (.l11 ... .l18, R the lv of .l10); the fore by L4
# (H .l19 held from .l9, N .l20, Z .l21, D .l22, O .l23, L .l24, K .l25, the loop variable v the
# .i local .i2 bound by L4's tmp, R28) with the fore's block, whose `c[v] += 1` stays an asg of a
# numeric element by a scalar index (sealower's rule 19); `return c` -> `iret 1`. Line 6 is kept.
"""
tvec 10 3
tptr 11 3
fn 1 .main main 1 0 29 1:1:1
loc v 10 let 1:4:5
loc c 10 let 1:5:5
loc .l1 3 let 1:4:9
loc .l2 3 let 1:4:9
loc .l3 10 let 1:4:9
loc .l4 11 let 1:4:9
loc .l5 3 let 1:4:9
loc .l6 3 let 1:4:9
loc .l7 3 let 1:4:9
loc .l8 3 for 1:4:9
loc .l9 10 let 1:5:9
loc .l10 3 let 1:5:9
loc .l11 3 let 1:5:9
loc .l12 3 let 1:5:9
loc .l13 10 let 1:5:9
loc .l14 11 let 1:5:9
loc .l15 3 let 1:5:9
loc .l16 3 let 1:5:9
loc .l17 3 let 1:5:9
loc .l18 3 for 1:5:9
loc .l19 10 let 1:5:9
loc .l20 3 let 1:5:9
loc .l21 3 let 1:5:9
loc .l22 11 let 1:5:9
loc .l23 3 let 1:5:9
loc .l24 3 let 1:5:9
loc .l25 3 for 1:5:9
loc .i1 10 var 1:5:9
loc .i2 3 for 1:5:9
ci 1:4:16 3 2
tmp 1:4:9 3
ci 1:4:19 3 2
tmp 1:4:9 4
lv 1:4:9 3 4
anew 1:4:9 10 0 1
tmp 1:4:9 5
lv 1:4:9 10 5
adat 1:4:9 11
tmp 1:4:9 6
ci 1:4:9 3 0
tmp 1:4:9 7
lv 1:4:9 3 4
lv 1:4:9 3 7
bin 1:4:9 2 gt
ci 1:4:9 3 1
tmp 1:4:9 8
lv 1:4:9 3 4
lv 1:4:9 3 8
wbin 1:4:9 3 sub
tmp 1:4:9 9
lv 1:4:9 3 7
lv 1:4:9 3 9
lv 1:4:9 3 8
lv 1:4:9 3 3
lv 1:4:9 11 6
lv 1:4:9 3 10
est 1:4:9 8 0
block 1:4:9 1
hloop 1:4:9 10
block 1:4:9 3
if 1:4:9 0
lv 1:4:9 10 5
xblk 1:4:9 10 6
bind 1:4:1 1
lv 1:5:18 10 1
tmp 1:5:9 11
ci 1:5:21 3 3
tmp 1:5:9 12
ci 1:5:9 3 0
tmp 1:5:9 13
lv 1:5:9 3 12
tmp 1:5:9 14
lv 1:5:9 3 14
anew 1:5:9 10 0 1
tmp 1:5:9 15
lv 1:5:9 10 15
adat 1:5:9 11
tmp 1:5:9 16
ci 1:5:9 3 0
tmp 1:5:9 17
lv 1:5:9 3 14
lv 1:5:9 3 17
bin 1:5:9 2 gt
ci 1:5:9 3 1
tmp 1:5:9 18
lv 1:5:9 3 14
lv 1:5:9 3 18
wbin 1:5:9 3 sub
tmp 1:5:9 19
lv 1:5:9 3 17
lv 1:5:9 3 19
lv 1:5:9 3 18
lv 1:5:9 3 13
lv 1:5:9 11 16
lv 1:5:9 3 20
est 1:5:9 8 0
block 1:5:9 1
hloop 1:5:9 20
block 1:5:9 3
if 1:5:9 0
lv 1:5:9 10 15
xblk 1:5:9 10 6
bind 1:5:9 28
lv 1:5:9 10 11
bind 1:5:9 21
lv 1:5:9 10 21
ext 1:5:9 3 0
tmp 1:5:9 22
ci 1:5:9 3 0
tmp 1:5:9 23
lv 1:5:9 3 22
lv 1:5:9 3 23
bin 1:5:9 2 gt
lv 1:5:9 10 21
adat 1:5:9 11
tmp 1:5:9 24
ci 1:5:9 3 1
tmp 1:5:9 25
lv 1:5:9 3 22
lv 1:5:9 3 25
wbin 1:5:9 3 sub
tmp 1:5:9 26
lv 1:5:9 3 23
lv 1:5:9 3 26
lv 1:5:9 3 25
lv 1:5:9 11 24
lv 1:5:9 3 27
eld 1:5:9 3 8 0
tmp 1:5:9 29
lv 1:5:9 10 28
lv 1:5:9 3 29
idx 1:5:9 3 1
ci 1:5:9 3 1
asg 1:5:9 add
block 1:5:9 1
block 1:5:9 2
hloop 1:5:9 27
block 1:5:9 4
if 1:5:9 0
block 1:5:9 4
lv 1:5:9 10 28
iret 1:5:9 1
block 1:5:9 3
iblk 1:5:9 10 1
xblk 1:5:9 10 2
bind 1:5:1 2
lv 1:6:22 10 2
ci 1:6:24 3 0
idx 1:6:22 3 1
fconv 1:6:8 1 - - - d
ftext 1:6:8 1 %20
lv 1:6:28 10 2
ci 1:6:30 3 1
idx 1:6:28 3 1
fconv 1:6:8 1 - - - d
ftext 1:6:8 1 %20
lv 1:6:34 10 2
ci 1:6:36 3 2
idx 1:6:34 3 1
fconv 1:6:8 1 - - - d
ftext 1:6:8 1 %0A
fmt 1:6:8 1 6
lib 1:6:1 1 printf 1
eval 1:6:1
block 1:1:1 3
end
""",
# Line 4: L2 as rule 17 with sea_arr_new_u of ek 2 (i64) into v (T3), its fill loop (blocks 1, 2).
# Line 5: the tmps (.l9 T1's alias of v, .l10 an li); do 3; L2 into c (.i1, T3; its R the alias
# of .l10), blocks 4, 5; L4 (H held: mov, retain; blocks 6, 7), x loaded into v (.i2); the
# compound element store by rule 19: the read by rule 18 (ext, chkb, data, ldi), the 1, iaddc
# with the call's line, the checks again, cow(c) (block 8), data, sti. The end of L4's block
# releases H. `return c`: the borrowed c owned (retain), the body block's bound local c
# released (R29), mov R1, exit 3; enddo 3; mov c R1 (the bind, R27); no owned argument tmp.
# Line 6: three element reads by rule 18, printf by rule 8; .main's end releases c, then v.
"""
func .main main 1:1:1 0 0
slot s1 24 8
li i.two 2
li i.n 2
li i.ek 2
li i.rk 1
li i.one 1
rcall sea_arr_new_u 1:4 1 p.v 4 i.ek i.rk i.n i.one
ldp p.D p.v - 0 40
li i.Z 0
icmp gt i.E i.n i.Z
if 1 i.E
li i.O 1
isub i.L i.n i.O
loop 2 i.K i.Z i.L i.O
sti i.two p.D i.K 8 0
endloop 2
endif 1
li i.n3 3
do 3
li i.zero 0
li i.ek2 2
li i.rk2 1
li i.one2 1
rcall sea_arr_new_u 1:5 1 p.c 4 i.ek2 i.rk2 i.n3 i.one2
ldp p.D2 p.c - 0 40
li i.Z2 0
icmp gt i.E2 i.n3 i.Z2
if 4 i.E2
li i.O2 1
isub i.L2 i.n3 i.O2
loop 5 i.K2 i.Z2 i.L2 i.O2
sti i.zero p.D2 i.K2 8 0
endloop 5
endif 4
mov p.H p.v
retain p.H
ldi i.N p.H - 0 16
li i.Z3 0
icmp gt i.E3 i.N i.Z3
if 6 i.E3
ldp p.DH p.H - 0 40
li i.O3 1
isub i.L3 i.N i.O3
loop 7 i.K3 i.Z3 i.L3 i.O3
ldi i.x p.DH i.K3 8 0
ldi i.e1 p.c - 0 16
chkb i.x i.e1 0 1:5
ldp p.d1 p.c - 0 40
ldi i.t p.d1 i.x 8 0
li i.inc 1
iaddc i.r i.t i.inc 1:5
ldi i.e2 p.c - 0 16
chkb i.x i.e2 0 1:5
ldi i.cnt p.c - 0 0
li i.o1 1
icmp ne i.s i.cnt i.o1
if 8 i.s
rcall sea_arr_unique 1:5 1 p.u 1 p.c
mov p.c p.u
endif 8
ldp p.d2 p.c - 0 40
sti i.r p.d2 i.x 8 0
endloop 7
endif 6
release p.H
retain p.c
release p.c
mov p.R1 p.c
exit 3
enddo 3
mov p.cm p.R1
li i.a0 0
ldi i.x0 p.cm - 0 16
chkb i.a0 i.x0 0 1:6
ldp p.d0 p.cm - 0 40
ldi i.v0 p.d0 i.a0 8 0
li i.a1 1
ldi i.x1 p.cm - 0 16
chkb i.a1 i.x1 0 1:6
ldp p.dd1 p.cm - 0 40
ldi i.v1 p.dd1 i.a1 8 0
li i.a2 2
ldi i.x2 p.cm - 0 16
chkb i.a2 i.x2 0 1:6
ldp p.dd2 p.cm - 0 40
ldi i.v2 p.dd2 i.a2 8 0
sa p.S s1
sti i.v0 p.S - 0 0
sti i.v1 p.S - 0 8
sti i.v2 p.S - 0 16
la p.F d1
rcall sea_printf 1:6 0 2 p.F p.S
release p.cm
release p.v
ret 0
endfunc
fmt d1 6
fconv - - - d i
ftext %20
fconv - - - d i
ftext %20
fconv - - - d i
ftext %0A
""")


# ---------------------------------------------------------------- prel_meshgrid_tbind
# std.sea:  fn meshgrid(x: f64[], y: f64[]) -> (f64[,], f64[,]) {   fn 1, { 53
#               let r = len(y)                  let 5, r 9, len 13, y 17
#               let c = len(x)                  let 5, c 9, len 13, x 17
#               var X = zeros(r, c)             var 5, X 9, zeros 13, r 19, c 22
#               var Y = zeros(r, c)             (the same)
#               for j in 0..c {                 for 5, j 9, 0 14, c 17, { 19
#                   let xj = x[j]               let 9, xj 13, x 18, j 20
#                   for i in 0..r {             for 9, i 13, 0 18, r 21, { 23
#                       X[i, j] = xj            X 13, i 15, j 18, xj 23
#                       Y[i, j] = y[i]          Y 13, i 15, j 18, y 23, i 25
#                   }
#               }
#               return (X, Y)                   return 5, X 13, Y 16
#           }
# program:  4 let (X, Y) = meshgrid(filled(2.5, 2), ones(3))
#                 let 1, X 6, Y 9, meshgrid 14, filled 23, 2.5 30, 2 35, ones 39, 3 44
#           5 printf("%d %d %g %g\n", rows(X), cols(X), X[2, 1], Y[2, 1])
#                 printf 1, " 8, rows 25, X 30, cols 34, X 39, X 43 (2 45, 1 48), Y 52 (2 54, 1 57)
# Types by first reference: 10 f64[,] (the loc of X), 11 f64[] (filled), 12 the ttuple, 13 i64[]
# (meshgrid's ranges); the .hirl appends tptr 14 4.
MG = std_line('fn meshgrid(x: f64[], y: f64[]) -> (f64[,], f64[,]) {')
assert STD.split('\n')[MG:MG + 13] == [
    '    let r = len(y)', '    let c = len(x)', '    var X = zeros(r, c)', '    var Y = zeros(r, c)',
    '    for j in 0..c {', '        let xj = x[j]', '        for i in 0..r {',
    '            X[i, j] = xj', '            Y[i, j] = y[i]', '        }', '    }',
    '    return (X, Y)', '}']
prelude_test('prel_meshgrid_tbind', """// prel_meshgrid_tbind -- DESIGN.md 6.2 (4h, NAME.prelude): a two-result inline call under a
// tbind (3.5.9 R27): meshgrid's copy returns (X, Y) as R1 and R2, moved into the locals, then the
// owned argument temporaries (the filled and ones vectors) are released (R26)
let (X, Y) = meshgrid(filled(2.5, 2), ones(3))
printf("%d %d %g %g\\n", rows(X), cols(X), X[2, 1], Y[2, 1])
""", ('hirl', 'lir1'), '3 2 2.5 1\n', """
tmat 10 4
tvec 11 4
ttuple 12 2 10 10
tvec 13 3
fn 1 .main main 1 0 2 1:1:1
loc X 10 let 1:4:6
loc Y 10 let 1:4:9
cf 1:4:30 4 #4004000000000000
ci 1:4:35 3 2
lib 1:4:23 11 filled 2
ci 1:4:44 3 3
lib 1:4:39 11 ones 1
call 1:4:14 12 2 2
tbind 1:4:1 2 1 2
lv 1:5:30 10 1
lib 1:5:25 3 rows 1
fconv 1:5:8 1 - - - d
ftext 1:5:8 1 %20
lv 1:5:39 10 1
lib 1:5:34 3 cols 1
fconv 1:5:8 1 - - - d
ftext 1:5:8 1 %20
lv 1:5:43 10 1
ci 1:5:45 3 2
ci 1:5:48 3 1
idx 1:5:43 4 2
fconv 1:5:8 1 - - - g
ftext 1:5:8 1 %20
lv 1:5:52 10 2
ci 1:5:54 3 2
ci 1:5:57 3 1
idx 1:5:52 4 2
fconv 1:5:8 1 - - - g
ftext 1:5:8 1 %0A
fmt 1:5:8 1 8
lib 1:5:1 1 printf 1
eval 1:5:1
block 1:1:1 2
end
fn 2 meshgrid fn 12 2 7 0:{0}:1
par x 11 val
par y 11 val
loc r 3 let 0:{1}:9
loc c 3 let 0:{2}:9
loc X 10 var 0:{3}:9
loc Y 10 var 0:{4}:9
loc j 3 for 0:{5}:9
loc xj 4 let 0:{6}:13
loc i 3 for 0:{7}:13
lv 0:{1}:17 11 2
lib 0:{1}:13 3 len 1
bind 0:{1}:5 3
lv 0:{2}:17 11 1
lib 0:{2}:13 3 len 1
bind 0:{2}:5 4
lv 0:{3}:19 3 3
lv 0:{3}:22 3 4
lib 0:{3}:13 10 zeros 2
bind 0:{3}:5 5
lv 0:{4}:19 3 3
lv 0:{4}:22 3 4
lib 0:{4}:13 10 zeros 2
bind 0:{4}:5 6
ci 0:{5}:14 3 0
lv 0:{5}:17 3 4
rng 0:{5}:14 13 0 0
lv 0:{6}:18 11 1
lv 0:{6}:20 3 7
idx 0:{6}:18 4 1
bind 0:{6}:9 8
ci 0:{7}:18 3 0
lv 0:{7}:21 3 3
rng 0:{7}:18 13 0 0
lv 0:{8}:13 10 5
lv 0:{8}:15 3 9
lv 0:{8}:18 3 7
idx 0:{8}:13 4 2
lv 0:{8}:23 4 8
asg 0:{8}:13 set
lv 0:{9}:13 10 6
lv 0:{9}:15 3 9
lv 0:{9}:18 3 7
idx 0:{9}:13 4 2
lv 0:{9}:23 11 2
lv 0:{9}:25 3 9
idx 0:{9}:23 4 1
asg 0:{9}:13 set
block 0:{7}:23 2
forr 0:{7}:9 9
block 0:{5}:19 2
forr 0:{5}:5 7
lv 0:{10}:13 10 5
lv 0:{10}:16 10 6
ret 0:{10}:5 2
block 0:{0}:53 6
end
""".format(MG, MG + 1, MG + 2, MG + 3, MG + 4, MG + 5, MG + 6, MG + 7, MG + 8, MG + 9, MG + 12),
# P = 1:4:14. The arguments (the caller's code, at their own positions): filled by L2 at 1:4:23
# (V .l1, R .l2, A .l3, D .l4, Z .l5, O .l6, L .l7, K .l8) under `tmp .l9` (x), ones by L2 at
# 1:4:39 (R .l10, A .l11, V .l12, D .l13, Z .l14, O .l15, L .l16, K .l17) under `tmp .l18` (y).
# The copy at P: the len reads by L3, the zeros by L1 (anew z 1, two extents); the scalar element
# reads and stores stay (rules 18, 19); the .i locals in the order of their declaring records:
# r .i1, c .i2, X .i3, Y .i4 (binds), xj .i5 (bind), i .i6 (its forr record), j .i7 (its forr
# record, after the inner loop's); `return (X, Y)` -> `iret 2`; the xblk of the ttuple 12 under
# the tbind (R26). The printf's rows and cols by L3.
"""
tmat 10 4
tvec 11 4
ttuple 12 2 10 10
tvec 13 3
tptr 14 4
fn 1 .main main 1 0 27 1:1:1
loc X 10 let 1:4:6
loc Y 10 let 1:4:9
loc .l1 4 let 1:4:23
loc .l2 3 let 1:4:23
loc .l3 11 let 1:4:23
loc .l4 14 let 1:4:23
loc .l5 3 let 1:4:23
loc .l6 3 let 1:4:23
loc .l7 3 let 1:4:23
loc .l8 3 for 1:4:23
loc .l9 11 let 1:4:14
loc .l10 3 let 1:4:39
loc .l11 11 let 1:4:39
loc .l12 4 let 1:4:39
loc .l13 14 let 1:4:39
loc .l14 3 let 1:4:39
loc .l15 3 let 1:4:39
loc .l16 3 let 1:4:39
loc .l17 3 for 1:4:39
loc .l18 11 let 1:4:14
loc .i1 3 let 1:4:14
loc .i2 3 let 1:4:14
loc .i3 10 var 1:4:14
loc .i4 10 var 1:4:14
loc .i5 4 let 1:4:14
loc .i6 3 for 1:4:14
loc .i7 3 for 1:4:14
cf 1:4:30 4 #4004000000000000
tmp 1:4:23 3
ci 1:4:35 3 2
tmp 1:4:23 4
lv 1:4:23 3 4
anew 1:4:23 11 0 1
tmp 1:4:23 5
lv 1:4:23 11 5
adat 1:4:23 14
tmp 1:4:23 6
ci 1:4:23 3 0
tmp 1:4:23 7
lv 1:4:23 3 4
lv 1:4:23 3 7
bin 1:4:23 2 gt
ci 1:4:23 3 1
tmp 1:4:23 8
lv 1:4:23 3 4
lv 1:4:23 3 8
wbin 1:4:23 3 sub
tmp 1:4:23 9
lv 1:4:23 3 7
lv 1:4:23 3 9
lv 1:4:23 3 8
lv 1:4:23 4 3
lv 1:4:23 14 6
lv 1:4:23 3 10
est 1:4:23 8 0
block 1:4:23 1
hloop 1:4:23 10
block 1:4:23 3
if 1:4:23 0
lv 1:4:23 11 5
xblk 1:4:23 11 6
tmp 1:4:14 11
ci 1:4:44 3 3
tmp 1:4:39 12
lv 1:4:39 3 12
anew 1:4:39 11 0 1
tmp 1:4:39 13
cf 1:4:39 4 #3FF0000000000000
tmp 1:4:39 14
lv 1:4:39 11 13
adat 1:4:39 14
tmp 1:4:39 15
ci 1:4:39 3 0
tmp 1:4:39 16
lv 1:4:39 3 12
lv 1:4:39 3 16
bin 1:4:39 2 gt
ci 1:4:39 3 1
tmp 1:4:39 17
lv 1:4:39 3 12
lv 1:4:39 3 17
wbin 1:4:39 3 sub
tmp 1:4:39 18
lv 1:4:39 3 16
lv 1:4:39 3 18
lv 1:4:39 3 17
lv 1:4:39 4 14
lv 1:4:39 14 15
lv 1:4:39 3 19
est 1:4:39 8 0
block 1:4:39 1
hloop 1:4:39 19
block 1:4:39 3
if 1:4:39 0
lv 1:4:39 11 13
xblk 1:4:39 11 6
tmp 1:4:14 20
lv 1:4:14 11 20
ext 1:4:14 3 0
bind 1:4:14 21
lv 1:4:14 11 11
ext 1:4:14 3 0
bind 1:4:14 22
lv 1:4:14 3 21
lv 1:4:14 3 22
anew 1:4:14 10 1 2
bind 1:4:14 23
lv 1:4:14 3 21
lv 1:4:14 3 22
anew 1:4:14 10 1 2
bind 1:4:14 24
ci 1:4:14 3 0
lv 1:4:14 3 22
rng 1:4:14 13 0 0
lv 1:4:14 11 11
lv 1:4:14 3 27
idx 1:4:14 4 1
bind 1:4:14 25
ci 1:4:14 3 0
lv 1:4:14 3 21
rng 1:4:14 13 0 0
lv 1:4:14 10 23
lv 1:4:14 3 26
lv 1:4:14 3 27
idx 1:4:14 4 2
lv 1:4:14 4 25
asg 1:4:14 set
lv 1:4:14 10 24
lv 1:4:14 3 26
lv 1:4:14 3 27
idx 1:4:14 4 2
lv 1:4:14 11 20
lv 1:4:14 3 26
idx 1:4:14 4 1
asg 1:4:14 set
block 1:4:14 2
forr 1:4:14 26
block 1:4:14 2
forr 1:4:14 27
lv 1:4:14 10 23
lv 1:4:14 10 24
iret 1:4:14 2
block 1:4:14 6
iblk 1:4:14 12 2
xblk 1:4:14 12 2
tbind 1:4:1 2 1 2
lv 1:5:30 10 1
ext 1:5:25 3 0
fconv 1:5:8 1 - - - d
ftext 1:5:8 1 %20
lv 1:5:39 10 1
ext 1:5:34 3 1
fconv 1:5:8 1 - - - d
ftext 1:5:8 1 %20
lv 1:5:43 10 1
ci 1:5:45 3 2
ci 1:5:48 3 1
idx 1:5:43 4 2
fconv 1:5:8 1 - - - g
ftext 1:5:8 1 %20
lv 1:5:52 10 2
ci 1:5:54 3 2
ci 1:5:57 3 1
idx 1:5:52 4 2
fconv 1:5:8 1 - - - g
ftext 1:5:8 1 %0A
fmt 1:5:8 1 8
lib 1:5:1 1 printf 1
eval 1:5:1
block 1:1:1 2
end
""",
# The two argument tmps: each L2 xblk computed into its tmp's register (T1; T3 names A by it):
# filled's arrnew (ek 1, blocks 1, 2) into x, ones' arrnew, its 1.0, its fill loop (blocks 3, 4)
# into y. do 5; r and c by ext (rule 17) into their registers; X and Y by arrnewz of a matrix;
# the range loops (rule 4: blocks 6, 7 and 8, 9); xj by rule 18; X[i, j] = xj by rule 19 (both
# checks, cow block 10, the linear index, stf); Y[i, j] = y[i]: the value read first (rule 18),
# then the store (cow block 11). The iret: X and Y owned (retain each), the body block's bound
# locals released in reverse order (Y, X; R29), mov R1 X, mov R2 Y, exit 5; enddo 5. Under the
# tbind (R27): the movs into X and Y first, then T2 releases the owned argument tmps x, y in
# the order of their tmp records. Line 5: rows and cols (rule 17), the two matrix reads (rule
# 18), printf (slot of 32 bytes); .main's end releases Y, then X.
"""
func .main main 1:1:1 0 0
slot s1 32 8
lf f.V #4004000000000000
li i.R 2
li i.ek 1
li i.rk 1
li i.C 1
rcall sea_arr_new_u 1:4 1 p.x 4 i.ek i.rk i.R i.C
ldp p.D p.x - 0 40
li i.Z 0
icmp gt i.E i.R i.Z
if 1 i.E
li i.O 1
isub i.L i.R i.O
loop 2 i.K i.Z i.L i.O
stf f.V p.D i.K 8 0
endloop 2
endif 1
li i.R2 3
li i.ek2 1
li i.rk2 1
li i.C2 1
rcall sea_arr_new_u 1:4 1 p.y 4 i.ek2 i.rk2 i.R2 i.C2
lf f.one #3FF0000000000000
ldp p.D2 p.y - 0 40
li i.Z2 0
icmp gt i.E2 i.R2 i.Z2
if 3 i.E2
li i.O2 1
isub i.L2 i.R2 i.O2
loop 4 i.K2 i.Z2 i.L2 i.O2
stf f.one p.D2 i.K2 8 0
endloop 4
endif 3
do 5
ldi i.r p.y - 0 16
ldi i.c p.x - 0 16
li i.ekX 1
li i.rkX 2
rcall sea_arr_new 1:4 1 p.X 4 i.ekX i.rkX i.r i.c
li i.ekY 1
li i.rkY 2
rcall sea_arr_new 1:4 1 p.Y 4 i.ekY i.rkY i.r i.c
li i.lo 0
li i.st 1
rcount i.Cj i.Ej i.lo i.c i.st 0 1:4
if 6 i.Ej
loop 7 i.j i.lo i.Cj i.st
ldi i.ex p.x - 0 16
chkb i.j i.ex 0 1:4
ldp p.dx p.x - 0 40
ldf f.xj p.dx i.j 8 0
li i.lo2 0
li i.st2 1
rcount i.Ci i.Ei i.lo2 i.r i.st2 0 1:4
if 8 i.Ei
loop 9 i.i i.lo2 i.Ci i.st2
ldi i.e0 p.X - 0 16
chkb i.i i.e0 0 1:4
ldi i.e1 p.X - 0 24
chkb i.j i.e1 1 1:4
ldi i.cx p.X - 0 0
li i.ox 1
icmp ne i.sx i.cx i.ox
if 10 i.sx
rcall sea_arr_unique 1:4 1 p.ux 1 p.X
mov p.X p.ux
endif 10
ldp p.dX p.X - 0 40
imul i.tx i.j i.e0
iadd i.lx i.i i.tx
stf f.xj p.dX i.lx 8 0
ldi i.ey p.y - 0 16
chkb i.i i.ey 0 1:4
ldp p.dy p.y - 0 40
ldf f.yi p.dy i.i 8 0
ldi i.f0 p.Y - 0 16
chkb i.i i.f0 0 1:4
ldi i.f1 p.Y - 0 24
chkb i.j i.f1 1 1:4
ldi i.cy p.Y - 0 0
li i.oy 1
icmp ne i.sy i.cy i.oy
if 11 i.sy
rcall sea_arr_unique 1:4 1 p.uy 1 p.Y
mov p.Y p.uy
endif 11
ldp p.dY p.Y - 0 40
imul i.ty i.j i.f0
iadd i.ly i.i i.ty
stf f.yi p.dY i.ly 8 0
endloop 9
endif 8
endloop 7
endif 6
retain p.X
retain p.Y
release p.Y
release p.X
mov p.R1 p.X
mov p.R2 p.Y
exit 5
enddo 5
mov p.Xm p.R1
mov p.Ym p.R2
release p.x
release p.y
ldi i.rows p.Xm - 0 16
ldi i.cols p.Xm - 0 24
li i.a 2
li i.b 1
ldi i.g0 p.Xm - 0 16
chkb i.a i.g0 0 1:5
ldi i.g1 p.Xm - 0 24
chkb i.b i.g1 1 1:5
ldp p.gd p.Xm - 0 40
imul i.gt i.b i.g0
iadd i.gl i.a i.gt
ldf f.v1 p.gd i.gl 8 0
li i.a2 2
li i.b2 1
ldi i.h0 p.Ym - 0 16
chkb i.a2 i.h0 0 1:5
ldi i.h1 p.Ym - 0 24
chkb i.b2 i.h1 1 1:5
ldp p.hd p.Ym - 0 40
imul i.ht i.b2 i.h0
iadd i.hl i.a2 i.ht
ldf f.v2 p.hd i.hl 8 0
sa p.S s1
sti i.rows p.S - 0 0
sti i.cols p.S - 0 8
stf f.v1 p.S - 0 16
stf f.v2 p.S - 0 24
la p.F d1
rcall sea_printf 1:5 0 2 p.F p.S
release p.Ym
release p.Xm
ret 0
endfunc
fmt d1 8
fconv - - - d i
ftext %20
fconv - - - d i
ftext %20
fconv - - - g f
ftext %20
fconv - - - g f
ftext %0A
""")


# ================================================================ res_noprelude_pnames (L-s)
# Built with --no-prelude like every res_* dump: the four prelude names resolve as `none`, the
# other predeclared names (printf, len, zeros) as `pd` (3.4.1 "Names", `rname`; 2.6.2 "Readings
# fixed by 4h"). seaname reports nothing for a `none` name (undeclared name is seacheck's, 2.6.2
# "Which program reports it"), so the .res is written. The .ast: pass 1 is unchanged in 4h (8,
# row 4h lists no seaparse work): the records of 3.4 for the source, written by hand and checked
# against the source text by check_ast_positions. The .res: res_gen.py with PRELUDE_NAMES; no
# later phase-rule step of res_gen's callers applies (no fixed-size type, `str` signature,
# `match` or struct).
PNAMES_SEA = """// res_noprelude_pnames -- without the prelude the names linspace, meshgrid, setdiff and
// bincount are not predeclared (lead decision L-s; DESIGN.md 3.4.1): each resolves as none;
// printf, len and zeros still resolve as pd
let a = linspace(0, 1, 3)
let b = meshgrid
setdiff(bincount)
printf("%d\\n", len(zeros(2)))
"""
PNAMES_AST = """
pname 0:4:5 a
name 0:4:9 linspace
int 0:4:18 0
int 0:4:21 1
int 0:4:24 3
call 0:4:9 3
let 0:4:1 0
pname 0:5:5 b
name 0:5:9 meshgrid
let 0:5:1 0
name 0:6:1 setdiff
name 0:6:9 bincount
call 0:6:1 1
cstmt 0:6:1
name 0:7:1 printf
str 0:7:8 %25d%0A
name 0:7:16 len
name 0:7:20 zeros
int 0:7:26 2
call 0:7:20 1
call 0:7:16 1
call 0:7:1 2
cstmt 0:7:1
prog 4
"""


def check_ast_positions(src, ast):
    """Each record's position names the source token 3.4 gives it: a name or pname its name, an
    int its digits, a str its opening quote, a call its callee's first token, a let the keyword,
    a cstmt its first token."""
    sl = src.split('\n')
    for rec in lines(ast):
        p = rec.split(' ')
        if p[0] == 'prog':
            continue
        f, ln, col = (int(x) for x in p[1].split(':'))
        assert f == 0
        at = sl[ln - 1][col - 1:]
        if p[0] in ('name', 'pname'):
            assert re.match(re.escape(p[2]) + r'\b', at), rec
        elif p[0] == 'int':
            assert re.match(p[2] + r'\b', at), rec
        elif p[0] == 'str':
            assert at.startswith('"'), rec
        elif p[0] == 'let':
            assert at.startswith('let '), rec
        elif p[0] in ('call', 'cstmt'):
            assert re.match(r'[a-z]', at), rec
        else:
            raise AssertionError(rec)


def write_pnames():
    with open(os.path.join(PASSES, 'res_noprelude_pnames.sea'), 'w') as fh:
        fh.write(PNAMES_SEA)
    with open(os.path.join(PASSES, 'res_noprelude_pnames.ast'), 'w') as fh:
        fh.write('#sea 1\n#target arm64-macos\n#file res_noprelude_pnames.sea\n'
                 + '\n'.join(lines(PNAMES_AST)) + '\n#end\n')
    check_ast_positions(PNAMES_SEA, PNAMES_AST)
    sys.path.insert(0, HERE)
    import res_gen
    res_gen.PASSES = PASSES
    res = res_gen.make('res_noprelude_pnames')
    want = {('linspace', 'none'), ('meshgrid', 'none'), ('setdiff', 'none'),
            ('bincount', 'none'), ('printf', 'pd'), ('len', 'pd'), ('zeros', 'pd')}
    got = {(r.split(' ')[2], r.split(' ')[3]) for r in res if r.startswith('rname ')}
    assert got == want, got
    assert not any(r.startswith('rerr ') for r in res), res


# ================================================================ writing the files
def main_write():
    for nm, t in TESTS.items():
        kinds = ('hir', 'hirl', 'lir1')
        if nm in PRELUDE:
            sea, kinds, out = PRELUDE[nm]
            for ext, text in (('sea', sea), ('out', out), ('prelude', '')):
                with open(os.path.join(PASSES, '%s.%s' % (nm, ext)), 'w') as fh:
                    fh.write(text)
        for kind in kinds:
            with open(os.path.join(PASSES, '%s.%s' % (nm, kind)), 'w') as fh:
                fh.write(t[kind])
    write_pnames()


# ================================================================ the self-check
def load_formats():
    recs = {}
    with open(os.path.join(ROOT, 'include', 'passes.txt')) as fh:
        for ln in fh:
            p = ln.split()
            if len(p) >= 5 and p[0] == 'rec':
                recs.setdefault(p[1], {})[p[3]] = (p[4], p[5:])
    return recs


FORMATS = load_formats()


def fields(sets, rec):
    op = rec.split(' ')[0]
    for s in sets:
        if op in FORMATS.get(s, {}):
            return FORMATS[s][op]
    raise AssertionError(('record not in sets', sets, rec))


def pops_of(sets, rec):
    pops, flds = fields(sets, rec)
    toks = rec.split(' ')[1:]
    vals = {}
    k = 0
    for f in flds:
        nm = f.split(':')[0]
        if '*' in f:
            cnt = int(vals[f.split("*")[1]])
            k += cnt
            continue
        vals[nm] = toks[k]
        k += 1
    assert k == len(toks), ('field count', rec)
    env = {}
    for nm, v in vals.items():
        if re.match(r'^-?[0-9]+$', v):
            env[nm] = int(v)
    return eval(pops, {}, env), vals


def body_of(text):
    ls = text.split('\n')
    assert ls[-1] == '' and ls[-2] == '#end', 'end'
    k = 0
    while ls[k].startswith('#'):
        k += 1
    return ls[k:-2]


def check_hir(name, kind):
    """passes.txt sets and post-order; functions, locals, the 4h validation of 3.5.9."""
    text = TESTS[name][kind]
    sets = ['H', 'HF'] + (['HL'] if kind == 'hirl' else [])
    body = body_of(text)
    nfn = 0
    k = 0
    while body[k].split(' ')[0] in ('tvec', 'tmat', 'tfvec', 'tfmat', 'tstruct', 'trec', 'fd',
                                    'ttuple', 'tptr'):
        if body[k].startswith('ttuple '):
            TUPLES.setdefault(name, {})[int(body[k].split(' ')[1])] = int(body[k].split(' ')[2])
        k += 1
    nodes = 0
    while k < len(body):
        hd = body[k].split(' ')
        assert hd[0] == 'fn', (name, body[k])
        nfn += 1
        assert int(hd[1]) == nfn, (name, 'fid', body[k])
        np_, nl = int(hd[5]), int(hd[6])
        fpos = hd[7]
        if kind == 'hirl':
            assert not fpos.startswith('0:'), (name, 'a prelude function left in the .hirl')
        k += 1
        locs = []
        for _ in range(np_):
            assert body[k].startswith('par '), (name, body[k])
            locs.append(body[k].split(' '))
            k += 1
        for _ in range(nl):
            assert body[k].startswith('loc '), (name, body[k])
            locs.append(body[k].split(' '))
            k += 1
        stack = []          # (op, rec, children)
        decl = []
        while body[k] != 'end':
            rec = body[k]
            op = rec.split(' ')[0]
            n, vals = pops_of(sets, rec)
            assert len(stack) >= n, (name, 'stack underflow', rec)
            kids = stack[len(stack) - n:]
            del stack[len(stack) - n:]
            for fld in ('lid', 'l', 'e'):
                if fld in vals and vals[fld] != '-' and (fld == 'lid' or op == 'rcnt'):
                    assert 1 <= int(vals[fld]) <= len(locs), (name, 'lid range', rec)
            if op in ('tmp', 'bind', 'forr', 'fore', 'hloop'):
                decl.append(int(vals['lid']))
            elif op == 'rcnt':
                decl += [int(vals['l']), int(vals['e'])]
            elif op == 'tbind':
                decl += [int(x) for x in rec.split(' ')[3:] if x != '-']
            if op == 'iblk':
                ty, kk = int(vals['ty']), int(vals['k'])
                assert len(kids) == 1 and kids[0][0] == 'block', (name, 'iblk child', rec)
                tup = TUPLES.get(name, {}).get(ty)
                assert kk == (0 if ty == 1 else (tup if tup else 1)), (name, 'iblk k', rec)
                # every iret inside (not inside a nested iblk) has this k
                check_irets(name, kids[0], kk)
            if op == 'xblk' and kids and kids[-1][0] == 'iblk':
                for st in kids[:-1]:
                    assert st[0] == 'tmp', (name, 'inline xblk statement', rec)
            stack.append((op, rec, kids))
            nodes += 1
            k += 1
        assert len(stack) == 1 and stack[0][0] == 'block', (name, 'function body', stack)
        check_no_ret_in_iblk(name, stack[0], False)
        k += 1
        # locals: every declared lid once at most for .l/.i; .l in order, .i in order, .l < .i
        dl = [d for d in dict.fromkeys(decl)]
        for prefix in ('.l', '.i'):
            mine = [d for d in dl if locs[d - 1][1].startswith(prefix)]
            want = [i + 1 for i, lc in enumerate(locs) if lc[1].startswith(prefix)]
            assert mine == want, (name, kind, prefix, 'locals order', mine, want)
            for j, d in enumerate(want):
                assert locs[d - 1][1] == '%s%d' % (prefix, j + 1), (name, 'local name', locs[d - 1])
        li = [i for i, lc in enumerate(locs) if lc[1].startswith('.i')]
        ll = [i for i, lc in enumerate(locs) if lc[1].startswith('.l')]
        if li and ll:
            assert max(ll) < min(li), (name, '.l before .i')
    return nodes


TUPLES = {}         # name -> {ttuple id: m}


def check_irets(name, node, kk):
    op, rec, kids = node
    if op == 'iblk':
        return
    if op == 'iret':
        assert int(rec.split(' ')[2]) == kk, (name, 'iret k', rec)
    for c in kids:
        check_irets(name, c, kk)


def check_no_ret_in_iblk(name, node, inside):
    op, rec, kids = node
    if inside:
        assert op not in ('ret', 'tret'), (name, 'ret inside an iblk', rec)
    if op == 'iret':
        assert inside, (name, 'iret outside an iblk', rec)
    for c in kids:
        check_no_ret_in_iblk(name, c, inside or op == 'iblk')


def check_positions(name):
    """3.5.9 Positions: every node of an iblk's subtree (the copy) is at the position of its
    xblk, which is the position of the call it inlines; L18's tmps at P too."""
    body = body_of(TESTS[name]['hirl'])
    sets = ['H', 'HF', 'HL']
    stack = []
    for rec in body:
        op = rec.split(' ')[0]
        if op in ('fn', 'par', 'loc', 'end', 'tvec', 'tmat', 'tfvec', 'tfmat', 'tstruct', 'trec',
                  'fd', 'ttuple', 'tptr'):
            stack = []
            continue
        n, vals = pops_of(sets, rec)
        kids = stack[len(stack) - n:]
        del stack[len(stack) - n:]
        node = (op, rec, kids)
        if op == 'xblk' and kids and kids[-1][0] == 'iblk':
            P = vals['pos']
            for st in kids[:-1]:
                assert st[1].split(' ')[1] == P, (name, 'inline tmp position', st[1])
            assert kids[-1][1].split(' ')[1] == P, (name, 'iblk position')
            all_at(name, kids[-1], P)
        stack.append(node)


def all_at(name, node, P):
    op, rec, kids = node
    assert rec.split(' ')[1] == P, (name, 'copied node not at P', P, rec)
    for c in kids:
        all_at(name, c, P)


def check_src_positions(name):
    """3.5.5 "Positions of the nodes pass 2a writes" against the source texts of the test: every
    record of the .hir names the token its rule gives (a local's name for lv and loc, the callee
    for call and lib, the keyword for fn, bind, ret, if, for, match, the opening quote for a format
    piece or a string, `{` for a block, ...). `.main` and its body block are at 1:1:1."""
    src = [s.split('\n') for s in SRC[name]]
    body = body_of(TESTS[name]['hir'])
    names = []
    kw = {'fn': ('fn',), 'bind': ('let', 'var'), 'tbind': ('let',), 'ret': ('return',),
          'tret': ('return',), 'if': ('if',), 'ifx': ('if',), 'forr': ('for',),
          'fore': ('for',), 'match': ('match',), 'block': ('{',), 'rarg': ('ref',),
          'fmt': ('"',), 'ftext': ('"',), 'fconv': ('"',), 'cs': ('"',), 'tasg': ('(',)}
    for rec in body:
        p = rec.split(' ')
        op = p[0]
        if op in ('tvec', 'tmat', 'tfvec', 'tfmat', 'ttuple', 'end', 'tstruct', 'trec', 'fd'):
            continue
        if op == 'fn':
            names = []
        if op == 'par':
            names.append(p[1])
            continue
        pos = p[4] if op == 'loc' else (p[7] if op == 'fn' else p[1])
        if pos == '1:1:1' and op in ('fn', 'block'):
            continue
        f, ln, col = (int(x) for x in pos.split(':'))
        at = src[f][ln - 1][col - 1:]
        if op == 'loc':
            names.append(p[1])
            want = (p[1],)
        elif op == 'lv':
            want = (names[int(p[3]) - 1],)
        elif op in ('call', 'lib'):
            want = None
            assert re.match(r'[a-z_][a-z0-9_]*\(', at), (name, rec, at)
            if op == 'lib':
                assert at.startswith(p[3].split('.')[0] + '('), (name, rec, at)
        elif op == 'ci':
            want = (p[3],)
        elif op == 'cf' or op == 'rng':
            want = None
            assert re.match(r'[0-9]', at), (name, rec, at)
        elif op in ('idx', 'asg', 'bin', 'eval', 'arm', 'skip'):
            want = None
            assert re.match(r'[A-Za-z_"0-9]', at), (name, rec, at)
        else:
            want = kw[op]
        if want is not None:
            assert any(at.startswith(w) and (not re.match(r'\w', w[-1]) or
                                             not re.match(r'\w', at[len(w):len(w) + 1]))
                       for w in want), (name, 'position', rec, at[:20])


def check_lir1(name):
    """passes.txt set L; registers (3.6.1), labels (3.6.2), slots (3.6.3), blocks (3.6.4)."""
    body = body_of(TESTS[name]['lir1'])
    labels, nlab = [], 0
    infunc = False
    for ln in body:
        op = ln.split(' ')[0]
        fields(['L'], ln)
        if op == 'func':
            infunc, seen, regs, blocks, open_, nslot, slots = True, 0, {}, 0, [], 0, []
        if infunc:
            for tok in ln.split(' ')[1:]:
                m = re.match(r'^([ifp])([1-9][0-9]*)$', tok)
                if m and m.group(2) not in regs:
                    seen += 1
                    assert int(m.group(2)) == seen, (name, 'register numbering', ln)
                    regs[m.group(2)] = m.group(1)
                elif m:
                    assert regs[m.group(2)] == m.group(1), (name, 'register class', ln)
                if re.match(r'^d[1-9][0-9]*$', tok) and op == 'la' and tok not in labels:
                    labels.append(tok)
                    assert tok == 'd%d' % len(labels), (name, 'label numbering', ln)
            if op == 'slot':
                nslot += 1
                assert ln.split(' ')[1] == 's%d' % nslot, (name, 'slot numbering', ln)
            if op == 'sa':
                slots.append(ln.split(' ')[2])
                assert slots[-1] == 's%d' % len(slots), (name, 'sa order', ln)
            b = ln.split(' ')[1] if len(ln.split(' ')) > 1 else None
            if op in ('loop', 'do', 'if', 'ifz'):
                blocks += 1
                assert int(b) == blocks, (name, 'block numbering', ln)
                open_.append((op, blocks))
            elif op in ('endloop', 'enddo', 'endif'):
                want = {'endloop': ('loop',), 'enddo': ('do',), 'endif': ('if', 'ifz')}[op]
                assert open_ and open_[-1][0] in want and open_[-1][1] == int(b), \
                    (name, 'block nesting', ln)
                open_.pop()
            elif op == 'else':
                assert open_[-1][0] in ('if', 'ifz') and open_[-1][1] == int(b), (name, ln)
            elif op in ('exit', 'next'):
                assert any(x == int(b) and o in ('loop', 'do') for o, x in open_), (name, ln)
        if op == 'endfunc':
            assert len(slots) == nslot and not open_, (name, 'slots/blocks')
            infunc = False
        if op in ('str', 'fmt', 'dat', 'slay'):
            nlab += 1
            assert ln.split(' ')[1] == 'd%d' % nlab, (name, 'data record order', ln)
    assert nlab == len(labels), (name, 'labels')
    return len(body)


def design_example37():
    """The code block of 3.6.6 rule 37 in DESIGN.md, as written."""
    with open(os.path.join(ROOT, 'docs', 'DESIGN.md')) as fh:
        doc = fh.read().split('\n')
    lo = doc.index('#### 3.6.6 Canonical lowering of scalar code')
    hi = doc.index('#### 3.6.7 Example')
    start = [k for k in range(lo, hi) if re.match(r'^37\. \*\*', doc[k])]
    assert len(start) == 1
    k = start[0]
    while doc[k].strip() != '```':
        k += 1
    k += 1
    out = []
    while doc[k].strip() != '```':
        out.append(doc[k].strip())
        k += 1
    return out


def run():
    main_write()
    nrec = 0
    for nm in TESTS:
        nrec += check_hir(nm, 'hir') + check_hir(nm, 'hirl')
        check_positions(nm)
        check_src_positions(nm)
        nrec += check_lir1(nm)
    assert body_of(TESTS['inl_half']['lir1']) == design_example37(), 'inl_half != rule 37'
    print('dump4h_cases: %d stage-only tests, %d prelude dumps, res_noprelude_pnames; %d records '
          'checked; inl_half.lir1 is rule 37\'s example byte for byte'
          % (len(TESTS) - len(PRELUDE), len(PRELUDE), nrec))


if __name__ == '__main__':
    run()
