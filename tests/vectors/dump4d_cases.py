"""Sub-phase 4d dump tests: the 4d-compilable examples of DESIGN.md 3.6.6 rules 16, 17, 18 (the
first), 19, 30 (the second), 31 and 36 as whole programs (DESIGN.md 6.2 "4d", 3.6.6 "Phase-4 dump
tests", G13).

Run with `timeout 120 uv run --no-project python tests/vectors/dump4d_cases.py`. It writes
tests/passes/arr_rule<N>.{sea,ast,res,hir1,hir,lir1,out}. Every record below is written by hand:
`.ast` from DESIGN.md 3.4 (post-order, positions 3.3; checked against the source text by
check_positions), `.hir1` from 3.5 (types numbered by first reference 3.5.1, locals 3.5.4, node
positions 3.5.5), `.hir` equal to `.hir1` (no constant, no foldable subtree, every function
reachable: 3.5.6, 3.5.7), `.lir1` from 3.6 and the canonical lowering of 3.6.6 (registers 3.6.1,
blocks and labels 3.6.2/3.6.4), `.out` from LANGUAGE.md. The `.res` comes from res_gen.py (the
3.4.1/3.4.2 oracle), which also cross-checks the lids against the `.hir1`.

Each program is laid out so that the rule's example appears in it with exactly the example's
registers, blocks and lines (rules 16, 17, 18, 19, 30, 31, 36): the registers that the example
says hold its inputs are the first ones of their function. Every function contains a loop and is
called from two sites, so LANGUAGE.md 8.6 requires no inlining (3.6.6 "Inlining is deferred").
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import res_gen  # noqa: E402

PASSES = os.path.join(os.path.dirname(HERE), 'passes')
KW = {'let': 'let', 'var': 'var', 'if': 'if', 'while': 'while', 'for': 'for', 'return': 'return',
      'block': '{', 'str': '"', 'break': 'break', 'ref': 'ref', 'dollar': '$'}


def check_positions(name, src, recs):
    lines = src.split('\n')

    def at(pos, text):
        f, ln, col = (int(x) for x in pos.split(':'))
        s = lines[ln - 1][col - 1:]
        assert s.startswith(text), (name, pos, text, s)

    for r in recs:
        p = r.split(' ')
        op = p[0]
        if op == 'prog':
            continue
        pos = p[1]
        if op in KW:
            at(pos, KW[op])
        elif op in ('name', 'pname', 'param', 'type'):
            at(pos, 'ref' if op == 'param' and p[3] == '1' else p[2])
        elif op == 'fn':
            at(pos, 'fn')
        elif op == 'int':
            at(pos, p[2])
        elif op == 'conv':
            at(pos, p[2])
        elif op == 'float':
            assert lines[int(pos.split(':')[1]) - 1][int(pos.split(':')[2]) - 1].isdigit(), r
        elif op in ('call', 'index', 'bin', 'asg', 'cstmt'):
            assert lines[int(pos.split(':')[1]) - 1][int(pos.split(':')[2]) - 1] != ' ', r
        if op == 'for':
            at(p[3], p[2])


HEAD = '#sea 1\n#target arm64-macos\n#file %s.sea\n'


def case(name, src, ast, hir, lir, out):
    ast_l = ast.strip('\n').split('\n')
    check_positions(name, src, ast_l)
    files = {'sea': src, 'ast': HEAD % name + '\n'.join(ast_l) + '\n#end\n',
             'hir1': HEAD % name + hir.strip('\n') + '\n#end\n',
             'hir': HEAD % name + hir.strip('\n') + '\n#end\n',
             'lir1': HEAD % name + lir.strip('\n') + '\n#end\n', 'out': out}
    for ext, text in files.items():
        with open(os.path.join(PASSES, name + '.' + ext), 'w') as f:
            f.write(text)
    res_gen.make(name)


# ================================================================ rule 16: scopes and exits
# The example function verbatim (lines 1-9), called twice (lines 10, 11): f(5) leaves the loop by
# the break at k = 3, f(2) by the condition at k = 2.
case('arr_rule16', '''fn f(n: i64) -> i64 {
    var k = 0
    while k < n {
        let v = zeros(n)
        if k == 3 { break }
        k += 1
    }
    return k
}
printf("%d\\n", f(5))
printf("%d\\n", f(2))
// arr_rule16 -- DESIGN.md 3.6.6 rule 16 (scopes and exits): its example function verbatim; the
// array local v is released by the break and at the end of the loop body
''', '''
type 0:1:9 i64 s 0
param 0:1:6 n 0 0
type 0:1:17 i64 s 0
pname 0:2:9 k
int 0:2:13 0
var 0:2:5 0
name 0:3:11 k
name 0:3:15 n
bin 0:3:11 lt
pname 0:4:13 v
name 0:4:17 zeros
name 0:4:23 n
call 0:4:17 1
let 0:4:9 0
name 0:5:12 k
int 0:5:17 3
bin 0:5:12 eq
break 0:5:21
block 0:5:19 1
if 0:5:9 0
name 0:6:9 k
int 0:6:14 1
asg 0:6:9 add
block 0:3:17 3
while 0:3:5
name 0:8:12 k
return 0:8:5 1
block 0:1:21 3
fn 0:1:1 f 0 1 1
name 0:10:1 printf
str 0:10:8 %25d%0A
name 0:10:16 f
int 0:10:18 5
call 0:10:16 1
call 0:10:1 2
cstmt 0:10:1
name 0:11:1 printf
str 0:11:8 %25d%0A
name 0:11:16 f
int 0:11:18 2
call 0:11:16 1
call 0:11:1 2
cstmt 0:11:1
prog 3
''', '''
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
lib 0:4:17 10 zeros 1
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
''', '''
func .main main 0:1:1 0 0
slot s1 8 8
slot s2 8 8
li i1 5
call f 1 i2 1 i1
sa p3 s1
sti i2 p3 - 0 0
la p4 d1
rcall sea_printf 0:10 0 2 p4 p3
li i5 2
call f 1 i6 1 i5
sa p7 s2
sti i6 p7 - 0 0
la p8 d2
rcall sea_printf 0:11 0 2 p8 p7
ret 0
endfunc
func f fn 0:1:1 1 i1 1 i
li i2 0
do 1
icmp lt i3 i2 i1
ifz 2 i3
exit 1
endif 2
li i4 1
li i5 1
li i6 1
rcall sea_arr_new 0:4 1 p7 4 i4 i5 i1 i6
li i8 3
icmp eq i9 i2 i8
if 3 i9
release p7
exit 1
endif 3
li i10 1
iaddc i2 i2 i10 0:6
release p7
enddo 1
ret 1 i2
endfunc
fmt d1 2
fconv - - - d i
ftext %0A
fmt d2 2
fconv - - - d i
ftext %0A
''', '3\n2\n')

# ================================================================ rule 17: allocation (ones)
# `let u = ones(n)` on line 1 with n in i1 (the first statement of line 1 binds it): the example
# verbatim; line 2 reads u[2] (rule 18) and len(u) (rule 17); u is released at the end of .main.
case('arr_rule17', '''let n = 3; let u = ones(n)
printf("%g %d\\n", u[2], len(u))
// arr_rule17 -- DESIGN.md 3.6.6 rule 17 (array headers and allocation): its example verbatim
// (ones: arrnew with sea_arr_new_u, then the fill loop), then rule 18 and len
''', '''
pname 0:1:5 n
int 0:1:9 3
let 0:1:1 0
pname 0:1:16 u
name 0:1:20 ones
name 0:1:25 n
call 0:1:20 1
let 0:1:12 0
name 0:2:1 printf
str 0:2:8 %25g%20%25d%0A
name 0:2:19 u
int 0:2:21 2
index 0:2:19 1
name 0:2:25 len
name 0:2:29 u
call 0:2:25 1
call 0:2:1 3
cstmt 0:2:1
prog 3
''', '''
tvec 10 4
fn 1 .main main 1 0 2 0:1:1
loc n 3 let 0:1:5
loc u 10 let 0:1:16
ci 0:1:9 3 3
bind 0:1:1 1
lv 0:1:25 3 1
lib 0:1:20 10 ones 1
bind 0:1:12 2
lv 0:2:19 10 2
ci 0:2:21 3 2
idx 0:2:19 4 1
fconv 0:2:8 1 - - - g
ftext 0:2:8 1 %20
lv 0:2:29 10 2
lib 0:2:25 3 len 1
fconv 0:2:8 1 - - - d
ftext 0:2:8 1 %0A
fmt 0:2:8 1 4
lib 0:2:1 1 printf 1
eval 0:2:1
block 0:1:1 3
end
''', '''
func .main main 0:1:1 0 0
slot s1 16 8
li i1 3
li i2 1
li i3 1
li i4 1
rcall sea_arr_new_u 0:1 1 p5 4 i2 i3 i1 i4
lf f6 #3FF0000000000000
ldp p7 p5 - 0 40
li i8 0
icmp gt i9 i1 i8
if 1 i9
li i10 1
isub i11 i1 i10
loop 2 i12 i8 i11 i10
stf f6 p7 i12 8 0
endloop 2
endif 1
li i13 2
ldi i14 p5 - 0 16
chkb i13 i14 0 0:2
ldp p15 p5 - 0 40
ldf f16 p15 i13 8 0
ldi i17 p5 - 0 16
sa p18 s1
stf f16 p18 - 0 0
sti i17 p18 - 0 8
la p19 d1
rcall sea_printf 0:2 0 2 p19 p18
release p5
ret 0
endfunc
fmt d1 4
fconv - - - g f
ftext %20
fconv - - - d i
ftext %0A
''', '1 3\n')

# ================================================================ rule 18: element reads, $
# g's parameters T, i, j are p1, i2, i3 and its line 7 reads T[j-1, i] into r: the example
# verbatim (f11 is r, rule 2). .main stores A[1, 2] = 5 (rule 19) and reads A[$ - 1, $ - 1] (dol:
# each $ is ext(B, dim) into a new register at its place). g(A, 2, 2) = A[1, 2] = 5, g(A, 0, 1) =
# A[0, 0] = 0, A[1, 2] = 5.
case('arr_rule18', '''var A = zeros(2, 3)
A[1, 2] = 5.0
printf("%g\\n", g(A, 2, 2))
printf("%g\\n", g(A, 0, 1))
printf("%g\\n", A[$ - 1, $ - 1])
fn g(T: f64[,], i: i64, j: i64) -> f64 {
    var r = T[j-1, i]
    while r < 0.0 {
        r = 0.0
    }
    return r
}
// arr_rule18 -- DESIGN.md 3.6.6 rule 18 (element reads by scalar indices, $): the first example
// verbatim in g (line 7); $ in both dimensions and an element store (rule 19) in .main
''', '''
pname 0:1:5 A
name 0:1:9 zeros
int 0:1:15 2
int 0:1:18 3
call 0:1:9 2
var 0:1:1 0
name 0:2:1 A
int 0:2:3 1
int 0:2:6 2
index 0:2:1 2
float 0:2:11 #4014000000000000
asg 0:2:1 set
name 0:3:1 printf
str 0:3:8 %25g%0A
name 0:3:16 g
name 0:3:18 A
int 0:3:21 2
int 0:3:24 2
call 0:3:16 3
call 0:3:1 2
cstmt 0:3:1
name 0:4:1 printf
str 0:4:8 %25g%0A
name 0:4:16 g
name 0:4:18 A
int 0:4:21 0
int 0:4:24 1
call 0:4:16 3
call 0:4:1 2
cstmt 0:4:1
name 0:5:1 printf
str 0:5:8 %25g%0A
name 0:5:16 A
dollar 0:5:18
int 0:5:22 1
bin 0:5:18 sub
dollar 0:5:25
int 0:5:29 1
bin 0:5:25 sub
index 0:5:16 2
call 0:5:1 2
cstmt 0:5:1
type 0:6:9 f64 m 0
param 0:6:6 T 0 0
type 0:6:20 i64 s 0
param 0:6:17 i 0 0
type 0:6:28 i64 s 0
param 0:6:25 j 0 0
type 0:6:36 f64 s 0
pname 0:7:9 r
name 0:7:13 T
name 0:7:15 j
int 0:7:17 1
bin 0:7:15 sub
name 0:7:20 i
index 0:7:13 2
var 0:7:5 0
name 0:8:11 r
float 0:8:15 #0000000000000000
bin 0:8:11 lt
name 0:9:9 r
float 0:9:13 #0000000000000000
asg 0:9:9 set
block 0:8:19 1
while 0:8:5
name 0:11:12 r
return 0:11:5 1
block 0:6:40 3
fn 0:6:1 g 0 3 1
prog 6
''', '''
tmat 10 4
fn 1 .main main 1 0 1 0:1:1
loc A 10 var 0:1:5
ci 0:1:15 3 2
ci 0:1:18 3 3
lib 0:1:9 10 zeros 2
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
''', '''
func .main main 0:1:1 0 0
slot s1 8 8
slot s2 8 8
slot s3 8 8
li i1 2
li i2 3
li i3 1
li i4 2
rcall sea_arr_new 0:1 1 p5 4 i3 i4 i1 i2
lf f6 #4014000000000000
li i7 1
li i8 2
ldi i9 p5 - 0 16
chkb i7 i9 0 0:2
ldi i10 p5 - 0 24
chkb i8 i10 1 0:2
ldi i11 p5 - 0 0
li i12 1
icmp ne i13 i11 i12
if 1 i13
rcall sea_arr_unique 0:2 1 p14 1 p5
mov p5 p14
endif 1
ldp p15 p5 - 0 40
imul i16 i8 i9
iadd i17 i7 i16
stf f6 p15 i17 8 0
li i18 2
li i19 2
call g 1 f20 3 p5 i18 i19
sa p21 s1
stf f20 p21 - 0 0
la p22 d1
rcall sea_printf 0:3 0 2 p22 p21
li i23 0
li i24 1
call g 1 f25 3 p5 i23 i24
sa p26 s2
stf f25 p26 - 0 0
la p27 d2
rcall sea_printf 0:4 0 2 p27 p26
ldi i28 p5 - 0 16
li i29 1
isubc i30 i28 i29 0:5
ldi i31 p5 - 0 24
li i32 1
isubc i33 i31 i32 0:5
ldi i34 p5 - 0 16
chkb i30 i34 0 0:5
ldi i35 p5 - 0 24
chkb i33 i35 1 0:5
ldp p36 p5 - 0 40
imul i37 i33 i34
iadd i38 i30 i37
ldf f39 p36 i38 8 0
sa p40 s3
stf f39 p40 - 0 0
la p41 d3
rcall sea_printf 0:5 0 2 p41 p40
release p5
ret 0
endfunc
func g fn 0:6:1 3 p1 i2 i3 1 f
li i4 1
isubc i5 i3 i4 0:7
ldi i6 p1 - 0 16
chkb i5 i6 0 0:7
ldi i7 p1 - 0 24
chkb i2 i7 1 0:7
ldp p8 p1 - 0 40
imul i9 i2 i6
iadd i10 i5 i9
ldf f11 p8 i10 8 0
do 1
lf f12 #0000000000000000
fcmp lt i13 f11 f12
ifz 2 i13
exit 1
endif 2
lf f11 #0000000000000000
enddo 1
ret 1 f11
endfunc
fmt d1 2
fconv - - - g f
ftext %0A
fmt d2 2
fconv - - - g f
ftext %0A
fmt d3 2
fconv - - - g f
ftext %0A
''', '5\n0\n5\n')

# ================================================================ rule 19: element stores, cow
# T = mk() is the first register of .main (p1), then j, i, tn (i2, i3, f4); line 12 is the example
# verbatim. mk fills its own fresh array (the cow test finds count 1 at run time) and returns it
# (rule 15 (a): retain the borrowed local, rule 16 (c): release it, ret). T[1, 0] = 2.5 after the
# store; U = mk() is the identity's [1 0; 0 1], U[1, 0] = 0.
case('arr_rule19', '''var T = mk()
var j = 1
var i = 0
let tn = 2.5
fn mk() -> f64[,] {
    var A = zeros(2, 2)
    for k in 0..2 {
        A[k, k] = 1.0
    }
    return A
}
T[j, i] = tn
printf("%g\\n", T[1, 0])
let U = mk()
printf("%g\\n", U[1, 0])
// arr_rule19 -- DESIGN.md 3.6.6 rule 19 (element stores by scalar indices, copy on write): its
// example verbatim on line 12; a store in a loop and an array result (rules 15 (a), 16 (c)) in mk
''', '''
pname 0:1:5 T
name 0:1:9 mk
call 0:1:9 0
var 0:1:1 0
pname 0:2:5 j
int 0:2:9 1
var 0:2:1 0
pname 0:3:5 i
int 0:3:9 0
var 0:3:1 0
pname 0:4:5 tn
float 0:4:10 #4004000000000000
let 0:4:1 0
type 0:5:12 f64 m 0
pname 0:6:9 A
name 0:6:13 zeros
int 0:6:19 2
int 0:6:22 2
call 0:6:13 2
var 0:6:5 0
int 0:7:14 0
int 0:7:17 2
range 0:7:14 0 0
name 0:8:9 A
name 0:8:11 k
name 0:8:14 k
index 0:8:9 2
float 0:8:19 #3FF0000000000000
asg 0:8:9 set
block 0:7:19 1
for 0:7:5 k 0:7:9
name 0:10:12 A
return 0:10:5 1
block 0:5:19 3
fn 0:5:1 mk 0 0 1
name 0:12:1 T
name 0:12:3 j
name 0:12:6 i
index 0:12:1 2
name 0:12:11 tn
asg 0:12:1 set
name 0:13:1 printf
str 0:13:8 %25g%0A
name 0:13:16 T
int 0:13:18 1
int 0:13:21 0
index 0:13:16 2
call 0:13:1 2
cstmt 0:13:1
pname 0:14:5 U
name 0:14:9 mk
call 0:14:9 0
let 0:14:1 0
name 0:15:1 printf
str 0:15:8 %25g%0A
name 0:15:16 U
int 0:15:18 1
int 0:15:21 0
index 0:15:16 2
call 0:15:1 2
cstmt 0:15:1
prog 9
''', '''
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
lib 0:6:13 10 zeros 2
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
''', '''
func .main main 0:1:1 0 0
slot s1 8 8
slot s2 8 8
call mk 1 p1 0
li i2 1
li i3 0
lf f4 #4004000000000000
ldi i5 p1 - 0 16
chkb i2 i5 0 0:12
ldi i6 p1 - 0 24
chkb i3 i6 1 0:12
ldi i7 p1 - 0 0
li i8 1
icmp ne i9 i7 i8
if 1 i9
rcall sea_arr_unique 0:12 1 p10 1 p1
mov p1 p10
endif 1
ldp p11 p1 - 0 40
imul i12 i3 i5
iadd i13 i2 i12
stf f4 p11 i13 8 0
li i14 1
li i15 0
ldi i16 p1 - 0 16
chkb i14 i16 0 0:13
ldi i17 p1 - 0 24
chkb i15 i17 1 0:13
ldp p18 p1 - 0 40
imul i19 i15 i16
iadd i20 i14 i19
ldf f21 p18 i20 8 0
sa p22 s1
stf f21 p22 - 0 0
la p23 d1
rcall sea_printf 0:13 0 2 p23 p22
call mk 1 p24 0
li i25 1
li i26 0
ldi i27 p24 - 0 16
chkb i25 i27 0 0:15
ldi i28 p24 - 0 24
chkb i26 i28 1 0:15
ldp p29 p24 - 0 40
imul i30 i26 i27
iadd i31 i25 i30
ldf f32 p29 i31 8 0
sa p33 s2
stf f32 p33 - 0 0
la p34 d2
rcall sea_printf 0:15 0 2 p34 p33
release p24
release p1
ret 0
endfunc
func mk fn 0:5:1 0 1 p
li i1 2
li i2 2
li i3 1
li i4 2
rcall sea_arr_new 0:6 1 p5 4 i3 i4 i1 i2
li i6 0
li i7 2
li i8 1
rcount i9 i10 i6 i7 i8 0 0:7
if 1 i10
loop 2 i11 i6 i9 i8
lf f12 #3FF0000000000000
ldi i13 p5 - 0 16
chkb i11 i13 0 0:8
ldi i14 p5 - 0 24
chkb i11 i14 1 0:8
ldi i15 p5 - 0 0
li i16 1
icmp ne i17 i15 i16
if 3 i17
rcall sea_arr_unique 0:8 1 p18 1 p5
mov p5 p18
endif 3
ldp p19 p5 - 0 40
imul i20 i11 i13
iadd i21 i11 i20
stf f12 p19 i21 8 0
endloop 2
endif 1
retain p5
release p5
ret 1 p5
endfunc
fmt d1 2
fconv - - - g f
ftext %0A
fmt d2 2
fconv - - - g f
ftext %0A
''', '2.5\n0\n')

# ================================================================ rule 30: element loops
# walk's parameter v is p1 and line 3 is `for x in v {` with an empty body: the second example
# verbatim (the borrowed vector held in p2: mov, retain, ..., release); then printf of len(v).
case('arr_rule30', '''// arr_rule30 -- DESIGN.md 3.6.6 rule 30 (element loops): the second example verbatim on line 3
fn walk(v: f64[]) {
    for x in v {
    }
    printf("walked %d\\n", len(v))
}
walk(ones(3))
walk(zeros(0))
// a borrowed vector (a parameter) is held in a hidden local, retained before and released after
// the loop; the loop variable x is loaded from the held vector's data
''', '''
type 0:2:12 f64 v 0
param 0:2:9 v 0 0
name 0:3:14 v
block 0:3:16 0
for 0:3:5 x 0:3:9
name 0:5:5 printf
str 0:5:12 walked%20%25d%0A
name 0:5:27 len
name 0:5:31 v
call 0:5:27 1
call 0:5:5 2
cstmt 0:5:5
block 0:2:19 2
fn 0:2:1 walk 0 1 0
name 0:7:1 walk
name 0:7:6 ones
int 0:7:11 3
call 0:7:6 1
call 0:7:1 1
cstmt 0:7:1
name 0:8:1 walk
name 0:8:6 zeros
int 0:8:12 0
call 0:8:6 1
call 0:8:1 1
cstmt 0:8:1
prog 3
''', '''
tvec 10 4
fn 1 .main main 1 0 0 0:1:1
ci 0:7:11 3 3
lib 0:7:6 10 ones 1
call 0:7:1 1 2 1
eval 0:7:1
ci 0:8:12 3 0
lib 0:8:6 10 zeros 1
call 0:8:1 1 2 1
eval 0:8:1
block 0:1:1 2
end
fn 2 walk fn 1 1 1 0:2:1
par v 10 val
loc x 4 for 0:3:9
lv 0:3:14 10 1
block 0:3:16 0
fore 0:3:5 2
ftext 0:5:12 1 walked%20
lv 0:5:31 10 1
lib 0:5:27 3 len 1
fconv 0:5:12 1 - - - d
ftext 0:5:12 1 %0A
fmt 0:5:12 1 3
lib 0:5:5 1 printf 1
eval 0:5:5
block 0:2:19 2
end
''', '''
func .main main 0:1:1 0 0
li i1 3
li i2 1
li i3 1
li i4 1
rcall sea_arr_new_u 0:7 1 p5 4 i2 i3 i1 i4
lf f6 #3FF0000000000000
ldp p7 p5 - 0 40
li i8 0
icmp gt i9 i1 i8
if 1 i9
li i10 1
isub i11 i1 i10
loop 2 i12 i8 i11 i10
stf f6 p7 i12 8 0
endloop 2
endif 1
call walk 0 1 p5
release p5
li i13 0
li i14 1
li i15 1
li i16 1
rcall sea_arr_new 0:8 1 p17 4 i14 i15 i13 i16
call walk 0 1 p17
release p17
ret 0
endfunc
func walk fn 0:2:1 1 p1 0
slot s1 8 8
mov p2 p1
retain p2
ldi i3 p2 - 0 16
li i4 0
icmp gt i5 i3 i4
if 1 i5
ldp p6 p2 - 0 40
li i7 1
isub i8 i3 i7
loop 2 i9 i4 i8 i7
ldf f10 p6 i9 8 0
endloop 2
endif 1
release p2
ldi i11 p1 - 0 16
sa p12 s1
sti i11 p12 - 0 0
la p13 d1
rcall sea_printf 0:5 0 2 p13 p12
ret 0
endfunc
fmt d1 3
ftext walked%20
fconv - - - d i
ftext %0A
''', 'walked 3\nwalked 0\n')

# ================================================================ rule 31: ref element arguments
# v = mkv() is p1 and i is i2; line 4 `f(ref v[i])` is the example verbatim (check, cow, address).
# mkv returns [0.5, 1.5]; f adds 1 twice through its ref parameter: v = [2.5, 3.5]; w = mkv() is a
# new [0.5, 1.5].
case('arr_rule31', '''var v = mkv()
var i = 1
// arr_rule31 -- DESIGN.md 3.6.6 rule 31 (ref arguments of elements): its example verbatim on line 4
f(ref v[i])
f(ref v[0])
printf("%g\\n", v[0])
printf("%g\\n", v[1])
let w = mkv()
printf("%g\\n", w[1])
fn mkv() -> f64[] {
    var a = zeros(2)
    for k in 0..2 {
        a[k] = f64(k) + 0.5
    }
    return a
}
fn f(ref x: f64) {
    for k in 0..2 {
        x += 1.0
    }
}
// the element's address is the argument (no reload); the callee's compound store through the f64
// ref parameter loads, adds and stores (rule 12)
''', '''
pname 0:1:5 v
name 0:1:9 mkv
call 0:1:9 0
var 0:1:1 0
pname 0:2:5 i
int 0:2:9 1
var 0:2:1 0
name 0:4:1 f
name 0:4:7 v
name 0:4:9 i
index 0:4:7 1
ref 0:4:3
call 0:4:1 1
cstmt 0:4:1
name 0:5:1 f
name 0:5:7 v
int 0:5:9 0
index 0:5:7 1
ref 0:5:3
call 0:5:1 1
cstmt 0:5:1
name 0:6:1 printf
str 0:6:8 %25g%0A
name 0:6:16 v
int 0:6:18 0
index 0:6:16 1
call 0:6:1 2
cstmt 0:6:1
name 0:7:1 printf
str 0:7:8 %25g%0A
name 0:7:16 v
int 0:7:18 1
index 0:7:16 1
call 0:7:1 2
cstmt 0:7:1
pname 0:8:5 w
name 0:8:9 mkv
call 0:8:9 0
let 0:8:1 0
name 0:9:1 printf
str 0:9:8 %25g%0A
name 0:9:16 w
int 0:9:18 1
index 0:9:16 1
call 0:9:1 2
cstmt 0:9:1
type 0:10:13 f64 v 0
pname 0:11:9 a
name 0:11:13 zeros
int 0:11:19 2
call 0:11:13 1
var 0:11:5 0
int 0:12:14 0
int 0:12:17 2
range 0:12:14 0 0
name 0:13:9 a
name 0:13:11 k
index 0:13:9 1
name 0:13:20 k
conv 0:13:16 f64
float 0:13:25 #3FE0000000000000
bin 0:13:16 add
asg 0:13:9 set
block 0:12:19 1
for 0:12:5 k 0:12:9
name 0:15:12 a
return 0:15:5 1
block 0:10:19 3
fn 0:10:1 mkv 0 0 1
type 0:17:13 f64 s 0
param 0:17:6 x 1 0
int 0:18:14 0
int 0:18:17 2
range 0:18:14 0 0
name 0:19:9 x
float 0:19:14 #3FF0000000000000
asg 0:19:9 add
block 0:18:19 1
for 0:18:5 k 0:18:9
block 0:17:18 1
fn 0:17:1 f 0 1 0
prog 10
''', '''
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
lib 0:11:13 10 zeros 1
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
''', '''
func .main main 0:1:1 0 0
slot s1 8 8
slot s2 8 8
slot s3 8 8
call mkv 1 p1 0
li i2 1
ldi i3 p1 - 0 16
chkb i2 i3 0 0:4
ldi i4 p1 - 0 0
li i5 1
icmp ne i6 i4 i5
if 1 i6
rcall sea_arr_unique 0:4 1 p7 1 p1
mov p1 p7
endif 1
ldp p8 p1 - 0 40
li i9 8
imul i10 i2 i9
padd p11 p8 i10
call f 0 1 p11
li i12 0
ldi i13 p1 - 0 16
chkb i12 i13 0 0:5
ldi i14 p1 - 0 0
li i15 1
icmp ne i16 i14 i15
if 2 i16
rcall sea_arr_unique 0:5 1 p17 1 p1
mov p1 p17
endif 2
ldp p18 p1 - 0 40
li i19 8
imul i20 i12 i19
padd p21 p18 i20
call f 0 1 p21
li i22 0
ldi i23 p1 - 0 16
chkb i22 i23 0 0:6
ldp p24 p1 - 0 40
ldf f25 p24 i22 8 0
sa p26 s1
stf f25 p26 - 0 0
la p27 d1
rcall sea_printf 0:6 0 2 p27 p26
li i28 1
ldi i29 p1 - 0 16
chkb i28 i29 0 0:7
ldp p30 p1 - 0 40
ldf f31 p30 i28 8 0
sa p32 s2
stf f31 p32 - 0 0
la p33 d2
rcall sea_printf 0:7 0 2 p33 p32
call mkv 1 p34 0
li i35 1
ldi i36 p34 - 0 16
chkb i35 i36 0 0:9
ldp p37 p34 - 0 40
ldf f38 p37 i35 8 0
sa p39 s3
stf f38 p39 - 0 0
la p40 d3
rcall sea_printf 0:9 0 2 p40 p39
release p34
release p1
ret 0
endfunc
func mkv fn 0:10:1 0 1 p
li i1 2
li i2 1
li i3 1
li i4 1
rcall sea_arr_new 0:11 1 p5 4 i2 i3 i1 i4
li i6 0
li i7 2
li i8 1
rcount i9 i10 i6 i7 i8 0 0:12
if 1 i10
loop 2 i11 i6 i9 i8
itof f12 i11
lf f13 #3FE0000000000000
fadd f14 f12 f13
ldi i15 p5 - 0 16
chkb i11 i15 0 0:13
ldi i16 p5 - 0 0
li i17 1
icmp ne i18 i16 i17
if 3 i18
rcall sea_arr_unique 0:13 1 p19 1 p5
mov p5 p19
endif 3
ldp p20 p5 - 0 40
stf f14 p20 i11 8 0
endloop 2
endif 1
retain p5
release p5
ret 1 p5
endfunc
func f fn 0:17:1 1 p1 0
li i2 0
li i3 2
li i4 1
rcount i5 i6 i2 i3 i4 0 0:18
if 1 i6
loop 2 i7 i2 i5 i4
ldf f8 p1 - 0 0
lf f9 #3FF0000000000000
fadd f10 f8 f9
stf f10 p1 - 0 0
endloop 2
endif 1
ret 0
endfunc
fmt d1 2
fconv - - - g f
ftext %0A
fmt d2 2
fconv - - - g f
ftext %0A
fmt d3 2
fconv - - - g f
ftext %0A
''', '2.5\n3.5\n1.5\n')

# ================================================================ rule 36: exact math on scalars
# dist's parameters tn, t are f1, f2 and line 6 is `let d = abs(tn - t)`: the example verbatim
# (fsub, fabs; d is f4); `var r = d` is mov (rule 2). dist(0.5, 2.0): d = 1.5, halved once: 0.75;
# dist(4.0, 1.5): d = 2.5, halved twice: 0.625.
case('arr_rule36', '''printf("%g\\n", dist(0.5, 2.0))
printf("%g\\n", dist(4.0, 1.5))
// arr_rule36 -- DESIGN.md 3.6.6 rule 36 (exact math functions on scalars): its example verbatim
// on line 6 (f64 abs is fabs, its destination d's register)
fn dist(tn: f64, t: f64) -> f64 {
    let d = abs(tn - t)
    var r = d
    while r > 1.0 {
        r = r / 2.0
    }
    return r
}
''', '''
name 0:1:1 printf
str 0:1:8 %25g%0A
name 0:1:16 dist
float 0:1:21 #3FE0000000000000
float 0:1:26 #4000000000000000
call 0:1:16 2
call 0:1:1 2
cstmt 0:1:1
name 0:2:1 printf
str 0:2:8 %25g%0A
name 0:2:16 dist
float 0:2:21 #4010000000000000
float 0:2:26 #3FF8000000000000
call 0:2:16 2
call 0:2:1 2
cstmt 0:2:1
type 0:5:13 f64 s 0
param 0:5:9 tn 0 0
type 0:5:21 f64 s 0
param 0:5:18 t 0 0
type 0:5:29 f64 s 0
pname 0:6:9 d
name 0:6:13 abs
name 0:6:17 tn
name 0:6:22 t
bin 0:6:17 sub
call 0:6:13 1
let 0:6:5 0
pname 0:7:9 r
name 0:7:13 d
var 0:7:5 0
name 0:8:11 r
float 0:8:15 #3FF0000000000000
bin 0:8:11 gt
name 0:9:9 r
name 0:9:13 r
float 0:9:17 #4000000000000000
bin 0:9:13 div
asg 0:9:9 set
block 0:8:19 1
while 0:8:5
name 0:11:12 r
return 0:11:5 1
block 0:5:33 4
fn 0:5:1 dist 0 2 1
prog 3
''', '''
fn 1 .main main 1 0 0 0:1:1
cf 0:1:21 4 #3FE0000000000000
cf 0:1:26 4 #4000000000000000
call 0:1:16 4 2 2
fconv 0:1:8 1 - - - g
ftext 0:1:8 1 %0A
fmt 0:1:8 1 2
lib 0:1:1 1 printf 1
eval 0:1:1
cf 0:2:21 4 #4010000000000000
cf 0:2:26 4 #3FF8000000000000
call 0:2:16 4 2 2
fconv 0:2:8 1 - - - g
ftext 0:2:8 1 %0A
fmt 0:2:8 1 2
lib 0:2:1 1 printf 1
eval 0:2:1
block 0:1:1 2
end
fn 2 dist fn 4 2 2 0:5:1
par tn 4 val
par t 4 val
loc d 4 let 0:6:9
loc r 4 var 0:7:9
lv 0:6:17 4 1
lv 0:6:22 4 2
bin 0:6:17 4 sub
lib 0:6:13 4 abs 1
bind 0:6:5 3
lv 0:7:13 4 3
bind 0:7:5 4
lv 0:8:11 4 4
cf 0:8:15 4 #3FF0000000000000
bin 0:8:11 2 gt
lv 0:9:9 4 4
lv 0:9:13 4 4
cf 0:9:17 4 #4000000000000000
bin 0:9:13 4 div
asg 0:9:9 set
block 0:8:19 1
while 0:8:5
lv 0:11:12 4 4
ret 0:11:5 1
block 0:5:33 4
end
''', '''
func .main main 0:1:1 0 0
slot s1 8 8
slot s2 8 8
lf f1 #3FE0000000000000
lf f2 #4000000000000000
call dist 1 f3 2 f1 f2
sa p4 s1
stf f3 p4 - 0 0
la p5 d1
rcall sea_printf 0:1 0 2 p5 p4
lf f6 #4010000000000000
lf f7 #3FF8000000000000
call dist 1 f8 2 f6 f7
sa p9 s2
stf f8 p9 - 0 0
la p10 d2
rcall sea_printf 0:2 0 2 p10 p9
ret 0
endfunc
func dist fn 0:5:1 2 f1 f2 1 f
fsub f3 f1 f2
fabs f4 f3
mov f5 f4
do 1
lf f6 #3FF0000000000000
fcmp gt i7 f5 f6
ifz 2 i7
exit 1
endif 2
lf f8 #4000000000000000
fdiv f5 f5 f8
enddo 1
ret 1 f5
endfunc
fmt d1 2
fconv - - - g f
ftext %0A
fmt d2 2
fconv - - - g f
ftext %0A
''', '0.75\n0.625\n')

print('dump4d_cases: 7 dump tests')
