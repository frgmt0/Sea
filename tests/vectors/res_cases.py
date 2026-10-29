"""Phase-4a corpus for the pass-2a split (DESIGN.md 6.2 "Tests of the pass-2a split").

Run with `timeout 120 uv run python tests/vectors/res_cases.py`. It writes:
* tests/passes/res_*.sea and their sea.ast goldens, derived by hand from the record rules of
  DESIGN.md 3.4 (post-order; every position written out below and checked against the source
  text by `check_positions`); the matching .res files are written by res_gen.py, the spec
  oracle of 3.4.1, which this script calls last;
* tests/errors/err_merge_* (.sea .err .status): the order across seaname and seacheck
  (DESIGN.md 2.6.2 "Order across the two programs"), expected texts and positions from the error
  table of 2.6.2.
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import res_gen  # noqa: E402

TESTS = os.path.dirname(HERE)
PASSES = os.path.join(TESTS, 'passes')
ERRORS = os.path.join(TESTS, 'errors')

# keyword or text expected at a record's position, by opcode
KW = {'const': 'const', 'struct': 'struct', 'let': 'let', 'var': 'var', 'if': 'if',
      'while': 'while', 'for': 'for', 'match': 'match', 'return': 'return', 'block': '{',
      'str': '"', 'neg': '-', 'not': '!', 'true': 'true', 'false': 'false', 'array': '['}


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
        elif op in ('name', 'pname', 'field'):
            at(pos, p[2])
        elif op == 'param':
            at(pos, p[2])
        elif op == 'type':
            at(pos, p[2])
        elif op == 'fn':
            at(pos, 'elemental' if p[3] == '1' else 'fn')
        elif op == 'int':
            v = res_gen.dec_i(p[2]) & res_gen.M64
            at(pos, str(v))
        if op == 'for':
            at(p[3], p[2])


def ast_case(name, comment, body, recs):
    """comment: the two header lines (lines 1-2); body: the program from line 3."""
    src = '// %s -- %s\n// %s\n' % (name, comment[0], comment[1]) + body
    check_positions(name, src, recs)
    with open(os.path.join(PASSES, name + '.sea'), 'w') as f:
        f.write(src)
    with open(os.path.join(PASSES, name + '.ast'), 'w') as f:
        f.write('#sea 1\n#target arm64-macos\n#file %s.sea\n' % name + '\n'.join(recs)
                + '\n#end\n')


def err_case(name, comment, body, line, col, msg):
    with open(os.path.join(ERRORS, name + '.sea'), 'w') as f:
        f.write('// %s -- %s\n' % (name, comment) + body)
    with open(os.path.join(ERRORS, name + '.err'), 'w') as f:
        f.write('%s.sea:%d:%d: error: %s\n' % (name, line, col, msg))
    with open(os.path.join(ERRORS, name + '.status'), 'w') as f:
        f.write('1\n')


R = []


def case(name, comment, body, recs):
    ast_case(name, comment, body, recs.split('\n'))
    R.append(name)


# ---------------------------------------------------------------- rname of every kind
case('res_names', ('rname loc (a parameter, var lo = lo, a block scope shadowing, a loop',
                   'variable, an outer local read by a shadowing let), cst, fn, pd, none (DESIGN.md 3.4.1)'),
     '''const K = 2
fn f(lo: i64) -> i64 {
    var lo = lo
    if lo > K {
        let lo = 1
        return lo
    }
    return lo
}
let n = f(K)
for i in 0..n {
    let n = i + n
}
printf("%d\\n", n + z)
''', '''int 0:3:11 2
const 0:3:1 K 0
type 0:4:10 i64 s 0
param 0:4:6 lo 0 0
type 0:4:18 i64 s 0
pname 0:5:9 lo
name 0:5:14 lo
var 0:5:5 0
name 0:6:8 lo
name 0:6:13 K
bin 0:6:8 gt
pname 0:7:13 lo
int 0:7:18 1
let 0:7:9 0
name 0:8:16 lo
return 0:8:9 1
block 0:6:15 2
if 0:6:5 0
name 0:10:12 lo
return 0:10:5 1
block 0:4:22 3
fn 0:4:1 f 0 1 1
pname 0:12:5 n
name 0:12:9 f
name 0:12:11 K
call 0:12:9 1
let 0:12:1 0
int 0:13:10 0
name 0:13:13 n
range 0:13:10 0 0
pname 0:14:9 n
name 0:14:13 i
name 0:14:17 n
bin 0:14:13 add
let 0:14:5 0
block 0:13:15 1
for 0:13:1 i 0:13:5
name 0:16:1 printf
str 0:16:8 %25d%0A
name 0:16:16 n
name 0:16:20 z
bin 0:16:16 add
call 0:16:1 2
cstmt 0:16:1
prog 5''')

# ---------------------------------------------------------------- rint
case('res_rint', ('rint: fv - for 2^53 + 1 (not exact in f64), #C3E0000000000000 for the 2^63',
                  'literal under neg, an exact large value (DESIGN.md 3.4.1)'),
     '''let a = 9007199254740993
let b = -9223372036854775808
let c = 9007199254740992 * 4
''', '''pname 0:3:5 a
int 0:3:9 #0020000000000001
let 0:3:1 0
pname 0:4:5 b
int 0:4:10 #8000000000000000
neg 0:4:9
let 0:4:1 0
pname 0:5:5 c
int 0:5:9 #0020000000000000
int 0:5:28 4
bin 0:5:9 mul
let 0:5:1 0
prog 3''')

# ---------------------------------------------------------------- constant outcomes
case('res_consts', ('rcni, rcnf (an i64 value into an f64 annotation), rcnb, rcne ovf and div0,',
                    'rcn (cannot be typed; names a constant without a value; a cycle) (3.4.1)'),
     '''const I = 7 % 3 - 10
const F: f64 = I * 2
const B = F < 0.0 && !false
const O = 1 + 9223372036854775807 * 2
const D = 5 % (I + 9)
const N = now()
const M = N + 1
const P = Q * 2
const Q = P + 1
let x = I + M
''', '''int 0:3:11 7
int 0:3:15 3
bin 0:3:11 mod
int 0:3:19 10
bin 0:3:11 sub
const 0:3:1 I 0
type 0:4:10 f64 s 0
name 0:4:16 I
int 0:4:20 2
bin 0:4:16 mul
const 0:4:1 F 1
name 0:5:11 F
float 0:5:15 #0000000000000000
bin 0:5:11 lt
false 0:5:23
not 0:5:22
bin 0:5:11 and
const 0:5:1 B 0
int 0:6:11 1
int 0:6:15 #7FFFFFFFFFFFFFFF
int 0:6:37 2
bin 0:6:15 mul
bin 0:6:11 add
const 0:6:1 O 0
int 0:7:11 5
name 0:7:16 I
int 0:7:20 9
bin 0:7:16 add
bin 0:7:11 mod
const 0:7:1 D 0
name 0:8:11 now
call 0:8:11 0
const 0:8:1 N 0
name 0:9:11 N
int 0:9:15 1
bin 0:9:11 add
const 0:9:1 M 0
name 0:10:11 Q
int 0:10:15 2
bin 0:10:11 mul
const 0:10:1 P 0
name 0:11:11 P
int 0:11:15 1
bin 0:11:11 add
const 0:11:1 Q 0
pname 0:12:5 x
name 0:12:9 I
name 0:12:13 M
bin 0:12:9 add
let 0:12:1 0
prog 10''')

# ---------------------------------------------------------------- rpowk, skipped regions, rtup
case('res_powk_skip', ('rpowk from a constant, none where a local shadows it; rtup 10 reused; a',
                       'not-entered fn and a match copied unresolved, a for over an array resolved (3.4.1, 3.4.2)'),
     '''const K = 2
fn g(x: f64) -> (f64, i64) {
    return (x ^ K, 1)
}
fn h(x: f64) -> (f64, i64) {
    let K = 3
    return (x ^ K, K)
}
fn g(y: f64) -> f64 {
    return y ^ K
}
for e in [1, 2] {
    let w = e
}
match "a" {
    "a" => { let m = 1 }
    _ => { let m = 2 }
}
let t = g(2.0)
''', '''int 0:3:11 2
const 0:3:1 K 0
type 0:4:9 f64 s 0
param 0:4:6 x 0 0
type 0:4:18 f64 s 0
type 0:4:23 i64 s 0
name 0:5:13 x
name 0:5:17 K
bin 0:5:13 pow
int 0:5:20 1
return 0:5:5 2
block 0:4:28 1
fn 0:4:1 g 0 1 2
type 0:7:9 f64 s 0
param 0:7:6 x 0 0
type 0:7:18 f64 s 0
type 0:7:23 i64 s 0
pname 0:8:9 K
int 0:8:13 3
let 0:8:5 0
name 0:9:13 x
name 0:9:17 K
bin 0:9:13 pow
name 0:9:20 K
return 0:9:5 2
block 0:7:28 2
fn 0:7:1 h 0 1 2
type 0:11:9 f64 s 0
param 0:11:6 y 0 0
type 0:11:17 f64 s 0
name 0:12:12 y
name 0:12:16 K
bin 0:12:12 pow
return 0:12:5 1
block 0:11:21 1
fn 0:11:1 g 0 1 1
int 0:14:11 1
int 0:14:14 2
row 0:14:11 2
array 0:14:10 1
pname 0:15:9 w
name 0:15:13 e
let 0:15:5 0
block 0:14:17 1
for 0:14:1 e 0:14:5
str 0:17:7 a
str 0:18:5 a
pname 0:18:18 m
int 0:18:22 1
let 0:18:14 0
block 0:18:12 1
arm 0:18:5 1
pname 0:19:16 m
int 0:19:20 2
let 0:19:12 0
block 0:19:10 1
arm 0:19:5 0
match 0:17:1 2
pname 0:21:5 t
name 0:21:9 g
float 0:21:11 #4000000000000000
call 0:21:9 1
let 0:21:1 0
prog 7''')

# ---------------------------------------------------------------- an untyped % exponent
case('res_powk_mod', ('the operands of an untyped % are i64 (LANGUAGE.md 4.2): x ^ (6 % 4) is rpowk 2',
                      '(DESIGN.md 3.5.5); x ^ (5.0 % 3.0) is rpowk 2 by the exact f64 % (6.6)'),
     '''let x = 1.5
let a = x ^ (6 % 4)
let b = x ^ (5.0 % 3.0)
''', '''pname 0:3:5 x
float 0:3:9 #3FF8000000000000
let 0:3:1 0
pname 0:4:5 a
name 0:4:9 x
int 0:4:14 6
int 0:4:18 4
bin 0:4:14 mod
bin 0:4:9 pow
let 0:4:1 0
pname 0:5:5 b
name 0:5:9 x
float 0:5:14 #4014000000000000
float 0:5:20 #4008000000000000
bin 0:5:14 mod
bin 0:5:9 pow
let 0:5:1 0
prog 3''')

# ---------------------------------------------------------------- rst, rname st
case('res_struct', ('rst and rname st (a struct name used as a value); rerr not supported yet:',
                    'structs at the struct item (DESIGN.md 3.4.1, 2.6.2)'),
     '''struct P {
    x: f64
}
let q = P
''', '''type 0:4:8 f64 s 0
field 0:4:5 x
struct 0:3:1 P 1
pname 0:6:5 q
name 0:6:9 P
let 0:6:1 0
prog 2''')

# ---------------------------------------------------------------- rerr of each seaname error
case('res_err_predeclared', ('rerr 212 at an fn with a predeclared name; the item is entered and its',
                             'name resolves to it (DESIGN.md 3.4.1, 2.6.2)'),
     '''fn sqrt(x: f64) -> f64 {
    return x
}
let y = sqrt(2.0)
''', '''type 0:3:12 f64 s 0
param 0:3:9 x 0 0
type 0:3:20 f64 s 0
name 0:4:12 x
return 0:4:5 1
block 0:3:24 1
fn 0:3:1 sqrt 0 1 1
pname 0:6:5 y
name 0:6:9 sqrt
float 0:6:14 #4000000000000000
call 0:6:9 1
let 0:6:1 0
prog 2''')

case('res_err_redef_item', ('rerr 235 at the later of two items of one name; it is not entered and',
                            'is copied unresolved (DESIGN.md 3.4.1, 2.6.2)'),
     '''const A = 1
const A = A + 1
let b = A
''', '''int 0:3:11 1
const 0:3:1 A 0
name 0:4:11 A
int 0:4:15 1
bin 0:4:11 add
const 0:4:1 A 0
pname 0:5:5 b
name 0:5:9 A
let 0:5:1 0
prog 3''')

case('res_err_param_redef', ('rerr 235 at the later of two parameters of one name (DESIGN.md 3.4.1,',
                             '2.6.2)'),
     '''fn g(a: i64, a: i64) {
    printf("x\\n")
}
''', '''type 0:3:9 i64 s 0
param 0:3:6 a 0 0
type 0:3:17 i64 s 0
param 0:3:14 a 0 0
name 0:4:5 printf
str 0:4:12 x%0A
call 0:4:5 1
cstmt 0:4:5
block 0:3:22 1
fn 0:3:1 g 0 2 0
prog 1''')

case('res_err_param_shadow', ('two errors at one param node: 213 (shadows a predeclared name) is',
                              'found before 259 default arguments and is the rerr (3.4.1, 2.6.2)'),
     '''fn f(len: i64 = 1) -> i64 {
    return len
}
''', '''type 0:3:11 i64 s 0
int 0:3:17 1
param 0:3:6 len 0 1
type 0:3:23 i64 s 0
name 0:4:12 len
return 0:4:5 1
block 0:3:27 1
fn 0:3:1 f 0 1 1
prog 1''')

case('res_err_default', ('rerr 259 default arguments at the param; the default expression is',
                         'copied unresolved (DESIGN.md 3.4.1, 2.6.2)'),
     '''fn f(a: i64 = K) -> i64 {
    return a
}
const K = 1
''', '''type 0:3:9 i64 s 0
name 0:3:15 K
param 0:3:6 a 0 1
type 0:3:21 i64 s 0
name 0:4:12 a
return 0:4:5 1
block 0:3:25 1
fn 0:3:1 f 0 1 1
int 0:6:11 1
const 0:6:1 K 0
prog 2''')

case('res_err_str_param', ('rerr 259 strings at a str parameter (its param node); its type in rfn',
                           'is 0 (DESIGN.md 3.4.1, 2.6.2)'),
     '''fn f(s: str, n: i64) {
    printf("x\\n")
}
''', '''type 0:3:9 str s 0
param 0:3:6 s 0 0
type 0:3:17 i64 s 0
param 0:3:14 n 0 0
name 0:4:5 printf
str 0:4:12 x%0A
call 0:4:5 1
cstmt 0:4:5
block 0:3:22 1
fn 0:3:1 f 0 2 0
prog 1''')

case('res_err_str_result', ('rerr 259 strings at a str result type (its type node); rty 0 and no',
                            'rtup (DESIGN.md 3.4.1, 2.6.2)'),
     '''fn f() -> (i64, str) {
    return (1, 2)
}
''', '''type 0:3:12 i64 s 0
type 0:3:17 str s 0
int 0:4:13 1
int 0:4:16 2
return 0:4:5 2
block 0:3:22 1
fn 0:3:1 f 0 0 2
prog 1''')

case('res_err_array', ('rerr 259 arrays at a fixed-size array type of a signature (its type node,',
                       'still reported in 4d); its type is 0 (DESIGN.md 3.4.2, 2.6.2)'),
     '''fn f(v: f64[3], k: i64) -> i64 {
    return k
}
''', '''int 0:3:13 3
type 0:3:9 f64 fv 1
param 0:3:6 v 0 0
type 0:3:20 i64 s 0
param 0:3:17 k 0 0
type 0:3:28 i64 s 0
name 0:4:12 k
return 0:4:5 1
block 0:3:32 1
fn 0:3:1 f 0 2 1
prog 1''')

# ---------------------------------------------------------------- 4d: array types (3.4.2)
case('res_arr_types', ('rtype everywhere; rtvec/rtmat in the order of creation (signatures, a tuple after',
                       'its components, then the let annotations); an element loop resolved (DESIGN.md 3.4.2)'),
     '''fn f(a: f64[,], b: i64[]) -> (bool[], f64[,]) {
    var r = filled(true, len(b))
    for x in b {
        r[0] = x > 0
    }
    return (r, a)
}
let m: f64[,] = zeros(2, 2)
let v: i64[] = filled(1, 3)
let w: f64[] = zeros(1)
let (p, q) = f(m, v)
''', '''type 0:3:9 f64 m 0
param 0:3:6 a 0 0
type 0:3:20 i64 v 0
param 0:3:17 b 0 0
type 0:3:31 bool v 0
type 0:3:39 f64 m 0
pname 0:4:9 r
name 0:4:13 filled
true 0:4:20
name 0:4:26 len
name 0:4:30 b
call 0:4:26 1
call 0:4:13 2
var 0:4:5 0
name 0:5:14 b
name 0:6:9 r
int 0:6:11 0
index 0:6:9 1
name 0:6:16 x
int 0:6:20 0
bin 0:6:16 gt
asg 0:6:9 set
block 0:5:16 1
for 0:5:5 x 0:5:9
name 0:8:13 r
name 0:8:16 a
return 0:8:5 2
block 0:3:47 3
fn 0:3:1 f 0 2 2
pname 0:10:5 m
type 0:10:8 f64 m 0
name 0:10:17 zeros
int 0:10:23 2
int 0:10:26 2
call 0:10:17 2
let 0:10:1 1
pname 0:11:5 v
type 0:11:8 i64 v 0
name 0:11:16 filled
int 0:11:23 1
int 0:11:26 3
call 0:11:16 2
let 0:11:1 1
pname 0:12:5 w
type 0:12:8 f64 v 0
name 0:12:16 zeros
int 0:12:22 1
call 0:12:16 1
let 0:12:1 1
pname 0:13:6 p
pname 0:13:9 q
ptuple 0:13:5 2
name 0:13:14 f
name 0:13:16 m
name 0:13:19 v
call 0:13:14 2
let 0:13:1 0
prog 5''')

case('res_err_dim', ('rerr 200 at an undeclared dim name of a fixed-size type: the first error of the',
                     'node (base, dims, shape) wins over the phase rule; the dim is an rname none (DESIGN.md 3.4.2)'),
     '''fn f(v: f64[N]) -> i64 {
    return 1
}
''', '''name 0:3:13 N
type 0:3:9 f64 fv 1
param 0:3:6 v 0 0
type 0:3:20 i64 s 0
int 0:4:12 1
return 0:4:5 1
block 0:3:24 1
fn 0:3:1 f 0 1 1
prog 1''')

case('res_err_handle', ('rerr 259 handle types at a handle type of a signature (its type node)',
                        '(DESIGN.md 3.4.1, 2.6.2)'),
     '''fn f(a: Figure) {
    printf("x\\n")
}
''', '''type 0:3:9 Figure s 0
param 0:3:6 a 0 0
name 0:4:5 printf
str 0:4:12 x%0A
call 0:4:5 1
cstmt 0:4:5
block 0:3:17 1
fn 0:3:1 f 0 1 0
prog 1''')

case('res_err_unknown_struct', ('rerr 229 unknown struct type at an undeclared type name of a',
                                'signature (its type node) (DESIGN.md 3.4.1, 2.6.2)'),
     '''fn f(p: Q) {
    printf("x\\n")
}
''', '''type 0:3:9 Q s 0
param 0:3:6 p 0 0
name 0:4:5 printf
str 0:4:12 x%0A
call 0:4:5 1
cstmt 0:4:5
block 0:3:12 1
fn 0:3:1 f 0 1 0
prog 1''')

case('res_err_first_pos', ('two seaname errors: the item error (6:1) is found first, the signature',
                           'error (3:9, the unknown struct type Q) comes first in source order and is the rerr (3.4.1)'),
     '''fn f(s: Q) {
    printf("x\\n")
}
fn f() {
    printf("y\\n")
}
''', '''type 0:3:9 Q s 0
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
prog 2''')

# ---------------------------------------------------------------- Decision 25 refined (6.2)
# The programs of the three errors/ tests err_const_noval_{calltype,shortcircuit,userpow}, on
# lines 1-3 as 6.2 gives them, the comment after them. seaname writes rcn for each constant: a
# call of a function item (rname fn) is not a node it evaluates (3.4.1 "Constants"), and a
# constant naming one without a value is not evaluated (Decision 25).


def tail_case(name, comment, body, recs):
    src = body + '// %s -- %s\n' % (name, comment)
    recs = recs.split('\n')
    check_positions(name, src, recs)
    with open(os.path.join(PASSES, name + '.sea'), 'w') as f:
        f.write(src)
    with open(os.path.join(PASSES, name + '.ast'), 'w') as f:
        f.write('#sea 1\n#target arm64-macos\n#file %s.sea\n' % name + '\n'.join(recs)
                + '\n#end\n')
    R.append(name)


# from 4g-1 (DESIGN.md 6.2, lead decision L-i) the faulty signature has an undeclared struct type
# Q in place of str: unknown struct type (229) at the type node, found by seaname in the signature
NOVAL_CALLTYPE = 'const A: f64 = f()\nfn f() -> Q { return 1 }\n'
NOVAL_SHORT = ('const D = B || 9223372036854775807 + 1 > 0\n'
               'const B: bool = false && f() == 1.0\nfn f() -> Q { return 1 }\n')
NOVAL_USERPOW = 'const C = pow(2.0, 3.0)\nfn pow(x: f64, y: f64) -> f64 { return x }\n'
tail_case('res_noval_calltype', 'A calls a faulty f: rcn; rerr 229 unknown struct type at the result '
          'type Q (DESIGN.md 3.4.1, Decision 25 refined; 6.2 L-i)', NOVAL_CALLTYPE, """type 0:1:10 f64 s 0
name 0:1:16 f
call 0:1:16 0
const 0:1:1 A 1
type 0:2:11 Q s 0
int 0:2:22 1
return 0:2:15 1
block 0:2:13 1
fn 0:2:1 f 0 0 1
prog 2""")
tail_case('res_noval_shortcircuit', 'B holds a call of a faulty f behind false &&: rcn; D names B: '
          'rcn; rerr 229 unknown struct type (3.4.1, Decision 25 refined; 6.2 L-i)', NOVAL_SHORT, """name 0:1:11 B
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
prog 3""")
tail_case('res_noval_userpow', 'C calls the entered fn pow (rname fn), not the predeclared pow: '
          'rcn; rerr 212 (3.4.1, Decision 25 refined)', NOVAL_USERPOW, """name 0:1:11 pow
float 0:1:15 #4000000000000000
float 0:1:20 #4008000000000000
call 0:1:11 2
const 0:1:1 C 0
type 0:2:11 f64 s 0
param 0:2:8 x 0 0
type 0:2:19 f64 s 0
param 0:2:16 y 0 0
type 0:2:27 f64 s 0
name 0:2:40 x
return 0:2:33 1
block 0:2:31 1
fn 0:2:1 pow 0 2 1
prog 2""")


def tail_err(name, comment, body, line, col, msg):
    with open(os.path.join(ERRORS, name + '.sea'), 'w') as f:
        f.write(body + '// %s -- %s\n' % (name, comment))
    with open(os.path.join(ERRORS, name + '.err'), 'w') as f:
        f.write('%s.sea:%d:%d: error: %s\n' % (name, line, col, msg))
    with open(os.path.join(ERRORS, name + '.status'), 'w') as f:
        f.write('1\n')


tail_err('err_const_noval_calltype', 'A: f64 = f() with a faulty f: the undeclared struct type Q of '
         'its result is the error (229, seaname, in the signature), A is not evaluated (LANGUAGE.md '
         '7.2; DESIGN.md 6.2, Decision 25 refined, lead decision L-i)', NOVAL_CALLTYPE,
         2, 11, 'unknown struct type')
tail_err('err_const_noval_shortcircuit', 'B holds a faulty call behind false && and has no value, '
         'so D (first) is not evaluated and its overflow is not reported; the error is f\'s undeclared '
         'result type Q (LANGUAGE.md 7.2; DESIGN.md 6.2, Decision 25 refined, lead decision L-i)',
         NOVAL_SHORT, 3, 11, 'unknown struct type')
tail_err('err_const_noval_userpow', 'C calls the program\'s fn pow, itself an error: C is not '
         'evaluated (LANGUAGE.md 7.2; DESIGN.md 6.2, Decision 25 refined)', NOVAL_USERPOW, 2, 1,
         'redefinition of predeclared name')

# ---------------------------------------------------------------- errors/: the merge
err_case('err_merge_check_first', 'a seacheck error (undeclared, 2:9) before a seaname error (3:1) in '
         'source order is reported (DESIGN.md 2.6.2 order across the two programs)',
         'let x = y\nfn len() {\n    printf("x\\n")\n}\n', 2, 9, "undeclared name 'y'")
err_case('err_merge_name_first', 'a seaname error (2:1) before a seacheck error (5:9) in source order '
         'is reported (DESIGN.md 2.6.2 order across the two programs)',
         'fn len() {\n    printf("x\\n")\n}\nlet x = y\n', 2, 1, 'redefinition of predeclared name')
err_case('err_merge_const_first', 'a constant\'s integer overflow (rcne, 2:11) before a seaname error '
         '(3:1) is reported (DESIGN.md 2.6.2, 3.4.1)',
         'const A = 9223372036854775807 + 1\nfn len() {\n    printf("x\\n")\n}\n', 2, 11,
         'integer overflow')
err_case('err_merge_const_after', 'a seaname error (2:1) before a constant\'s integer overflow (5:11) '
         'is reported (DESIGN.md 2.6.2, 3.4.1)',
         'fn len() {\n    printf("x\\n")\n}\nconst A = 9223372036854775807 + 1\n', 2, 1,
         'redefinition of predeclared name')

for nm in R:
    res_gen.make(nm)
print('res_cases: %d dump tests, 5 merge tests, 3 noval tests' % len(R))
