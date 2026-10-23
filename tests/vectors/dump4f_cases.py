"""Sub-phase 4f dump tests (DESIGN.md 6.2 "4f" dumps; 3.5.9 "What sealoop rewrites in 4f": L13,
L14 with R12-R16; 3.6.6 rules 23 and 24 and "Lowering of the sea.hirl records"; Decisions 38, 39).

Run with `timeout 120 uv run --no-project python tests/vectors/dump4f_cases.py [--out DIR]`. It
writes, in tests/passes/ (or DIR), for every test NAME below: NAME.sea, .ast, .res, .hir1, .hir,
.hirl, .lir1 and .out.

The tests: the agreed examples of 3.6.6 rules 23 and 24 as whole programs (lib_rule23: line 3 `let
s = sum(x)` with x in p1; lib_rule24: line 8 `let r = argsort(c, desc: true)` with c in p1; each
example appears in the .lir1 with exactly its registers, blocks, lines and sites), and the shapes of
6.2's 4f list without an agreed example: lib_mean_i64 (`sum` and `mean` of an i64 vector: isum,
R12 (b)), lib_variance (`variance` and `std`), lib_max (`max` of f64 and `argmin` of i64:
EMPTY_REDUCE, R15), lib_nnz (`nnz`, `any`, `all`), lib_sum_dim0 (`sum(A, dim: 0)` of a dynamic
matrix), lib_sum_dim1 (`sum(A, dim: 1)` of a fixed-size f64[2,3]: a fixed-size result, Decision 39),
lib_find (`find`), lib_find_first (`find_first`, `find_last`) and lib_sort_fixed (`sort` and
`argsort` of a fixed-size vector: the dyn of pass 2a rewritten by L10, R16, `desc:` inserted and
given as a run-time bool). One array operation per statement (3.6.6 "Phase-4 dump tests"); no
function is called from exactly one call site (3.6.6: no inlining before phase 6).

How each file is made (never by running seacheck, sealoop or sealower, which are written
concurrently with these goldens):
* `.ast`: pass 1 parses named arguments unchanged (4f adds only error 115 to it); the records are
  those seaparse writes for the source, reviewed against 3.4 (a `narg` at its name, its value its
  child) and checked against the source text by check_positions.
* `.res`: res_gen.py (the 3.4.1/3.4.2 oracle) with the phase-rule step 4e (dump4e_cases.res_gen4e:
  fixed-size types resolve); seaname reports nothing for a `narg` (the named options are seacheck's,
  2.6.2 "Readings fixed by 4f"); it cross-checks the lids against the .hir1.
* `.hir1`: by hand from 3.5.1-3.5.5 and 3.5.5's phase-4 notes as 4f reads them: a reduction with
  `dim:` is `lib name.dim` with the `ci` 0 or 1 at the position of the `dim:` value; `sort` and
  `argsort` have two children, the vector and the `desc:` value as written or the inserted `cb 0`
  at the call's position; a fixed-size `sort`/`argsort` operand gets a `dyn` to the dynamic vector
  type at the call's position (Decision 39); no `narg` survives. `.hir` = `.hir1` (no cref, nothing
  to fold, every function reachable; asserted).
* `.hirl`: from 3.5.9 with the helpers of dump4e_cases (loop(N; K), Ctx, L1, L2, L9 (a), make_hirl,
  number_locals) and the 4f helpers below (sum8, isum, the L13 and L14 rewrites), each written out
  record by record in the order its rule lists the statements; the `.l` locals numbered by
  number_locals as 3.5.9 "Locals" says; the appended types (tptr, and F8 = f64[8] of R14) in order of
  first reference.
* `.lir1`: by hand from 3.6.6, independently of the .hirl helpers: rule 23's sum8 spelled out by
  lsum8() from the rule's text, every other instruction written line by line with the derivation in
  comments; registers symbolic (`i.x`), numbered by number_regs (3.6.1).
* `.out`: from LANGUAGE.md 10.5, 10.6 and 11.1 by hand (the arithmetic in the comments).

The self-check at the end reads every written file back: the .hirl against include/passes.txt (sets
H HF HL, the enumeration wop with `and`) and 3.3, 3.5.4, 3.5.9 ("Types" with R14, "Locals", "What
the passes validate" with R1-R16 and R10), the .lir1 against passes.txt (set L) and the numbering
of 3.6.1-3.6.4, every rcall against rt.inc's entries (sea_sort and sea_argsort: site S, arguments
p i, result p), a count cross-check of the .hirl against the .lir1 (hloop and loop, if/ifx and
if, the F8 homes and the 64-byte slots, chk, chkb, the sort rcalls), and asserts that the agreed
examples of rules 23 and 24 appear in both their golden and DESIGN.md, compared directly.
"""

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def _segment(src, start, stop):
    """The lines of src from the line that starts with `start` to the line before the one that
    starts with `stop`; each marker must occur exactly once."""
    lns = src.split('\n')
    a = [k for k, ln in enumerate(lns) if ln.startswith(start)]
    b = [k for k, ln in enumerate(lns) if ln.startswith(stop)]
    assert len(a) == 1 and len(b) == 1 and a[0] < b[0], (start, stop)
    return '\n' * a[0] + '\n'.join(lns[a[0]:b[0]]) + '\n'


# The shared helpers of dump4e_cases.py (the HIR node helpers, Ctx with loop(N; K), L1-L4, L9 (a),
# make_hirl, number_locals, number_regs, res_gen4e, write_test, the passes.txt and rt.inc loaders,
# check_lir1, design_example and check_example) are executed here from its source; its tests and
# its run section are not.
_P4E = os.path.join(HERE, 'dump4e_cases.py')
with open(_P4E) as _fh:
    _SRC4E = _fh.read()
exec(compile(_segment(_SRC4E, 'import os', '# ================================================================ arr_rule20 '),
             _P4E, 'exec'))
exec(compile(_segment(_SRC4E, 'def L9a(', 'def hirl_arr_lit_fixed('), _P4E, 'exec'))
exec(compile(_segment(_SRC4E, '# ================================================================ writing the files',
                      'def check_hirl('), _P4E, 'exec'))
exec(compile(_segment(_SRC4E, 'def check_lir1(', '# ================================================================ run'),
             _P4E, 'exec'))
assert ('HL', 'wbin') in RECS and 'and' in ENUMS['wop'], 'passes.txt: wop and (R13)'
assert ENTS['sea_sort'] == (True, 'pi', 'p') and ENTS['sea_argsort'] == (True, 'pi', 'p'), \
    'rt.inc: the sort entries (4.8)'
assert ERRS['EMPTY_REDUCE'] == 1

NAN = '#7FF8000000000000'
ZERO = '#0000000000000000'
MZERO = '#8000000000000000'


# ================================================================ 4f HIR helpers
def ifx(P, ty, c, a, b):
    return N(cat(c, a, b) + ['ifx %s %d' % (P, ty)], ty)


def cvt(P, a):
    return N(cat(a) + ['cvt %s 4' % P], 4)


def cs(P, v):
    return N(['cs %s 5 %s' % (P, v)], 5)


def sum8(F, P, pre, nN, TP, F8, X, vV=None, dD=None):
    """sum8(X) of 3.5.9 L13: returns (the statement `tmp Z = ci 0`, the value `ifx P f64 (bin gt (lv
    N) (lv Z)) (xblk P f64 n { S }) (cf #0000000000000000)`). S in this order: `tmp H = anew P F8 0
    0` (R14); `tmp A = adat P ^f64 (lv H)` (R2); `tmp M = cf #8000000000000000`; `est P 8 0 (lv M)
    (lv A) (ci k)` for k = 0 ... 7 (R3); `tmp D = data(V)` (not in a dim: form, whose D is dD);
    `tmp Q = ci 7`; `tmp O = ci 1`; `tmp L = wbin sub (lv N) (lv O)`; `hloop K (lv Z) (lv L) (lv O)`
    { `tmp W = wbin and (lv K) (lv Q)` (R13); `bind G = eld P f64 8 0 (lv A) (lv W)`; X(K), whose
    value is `lv Y`; `asg set (lv G) (bin add (lv G) (lv Y))` (R8); `est P 8 0 (lv G) (lv A) (lv
    W)` }; `tmp A0` ... `tmp A7` = `eld P f64 8 0 (lv A) (ci k)`; T1 = A0 + A1, T2 = A2 + A3, T3 =
    T1 + T2, T4 = A4 + A5, T5 = A6 + A7, T6 = T4 + T5; value `bin add P f64 (lv T3) (lv T6)`.
    nN is `lv N` (the vector's extent tmp); X(s, k, d) returns (the statements of X(K), the node
    `lv Y`), s this sum8's Ctx, k `lv K`, d the data node."""
    s = Ctx(F, P, pre)
    z = s.tmp('Z', ci(P, 0))
    st = [s.tmp('H', anew(P, F8, 0, [])),
          s.tmp('A', adat(P, TP, s.lvl('H'))),
          s.tmp('M', cf(P, MZERO))]
    for k in range(8):
        st.append(est(P, 4, s.lvl('M'), s.lvl('A'), ci(P, k)))
    if dD is None:
        st.append(s.tmp('D', adat(P, TP, vV)))
        dD = s.lvl('D')
    st += [s.tmp('Q', ci(P, 7)), s.tmp('O', ci(P, 1)),
           s.tmp('L', wbin(P, 'sub', nN, s.lvl('O')))]
    body = [s.tmp('W', wbin(P, 'and', s.klv('K'), s.lvl('Q'))),
            s.bindl('G', eld(P, 4, s.lvl('A'), s.lvl('W')))]
    xs, y = X(s, s.klv('K'), dD)
    body += xs
    body += [asg(P, 'set', s.lvl('G'), bin_(P, 4, 'add', s.lvl('G'), y)),
             est(P, 4, s.lvl('G'), s.lvl('A'), s.lvl('W'))]
    st.append(s.hloop('K', s.lvl('Z'), s.lvl('L'), s.lvl('O'), body))
    for k in range(8):
        st.append(s.tmp('A%d' % k, eld(P, 4, s.lvl('A'), ci(P, k))))
    for t, a, b in (('T1', 'A0', 'A1'), ('T2', 'A2', 'A3'), ('T3', 'T1', 'T2'),
                    ('T4', 'A4', 'A5'), ('T5', 'A6', 'A7'), ('T6', 'T4', 'T5')):
        st.append(s.tmp(t, bin_(P, 4, 'add', s.lvl(a), s.lvl(b))))
    arm = xblk(P, st, bin_(P, 4, 'add', s.lvl('T3'), s.lvl('T6')))
    return z, ifx(P, 4, bin_(P, 2, 'gt', nN, s.lvl('Z')), arm, cf(P, ZERO))


def X_sum(P):
    """X(K) of sum: `tmp Y = eld P f64 8 0 (lv D) (lv K)`."""
    def X(s, k, d):
        return [s.tmp('Y', eld(P, 4, d, k))], s.lvl('Y')
    return X


def isum(x, P, TP, vV, n_loaded):
    """isum (3.5.9 L13): `bind R = ci 0`, `tmp D = data(V)`, then `tmp N = ext(V, 0)` if not yet
    loaded, loop(N; K) { `tmp Y = eld P i64 8 0 (lv D) (lv K)`; `asg set (lv R) (bin add (lv R) (lv
    Y))` } (rule 1: iaddc with P's line)."""
    st = [x.bindl('R', ci(P, 0)), x.tmp('D', adat(P, TP, vV))]
    if not n_loaded:
        st.append(x.tmp('N', ext(P, 0, vV)))
    st += x.loop('N', 'Zl', 'Ol', 'Ll', 'K', lambda: [
        x.tmp('Y', eld(P, 3, x.lvl('D'), x.klv('K'))),
        asg(P, 'set', x.lvl('R'), bin_(P, 3, 'add', x.lvl('R'), x.lvl('Y')))])
    return st


def variance_val(F, P, pre, x, TP, F8):
    """The value of L13's `variance` (f64 vector) after its `tmp N` and `tmp Z0` (in Ctx x): `ifx P
    f64 (bin eq (lv N) (lv Z0)) (cf NaN) (xblk P f64 { tmp O1 = ci 1; value ifx P f64 (bin eq (lv N)
    (lv O1)) (cf 0) (xblk P f64 { MEAN; DEV; tmp N1 = wbin sub (lv N) (lv O1); tmp F1 = cvt P f64
    (lv N1); value bin div P f64 (lv S2) (lv F1) }) })`. MEAN: sum8 with sum's X into `tmp S1`,
    `tmp F0 = cvt P f64 (lv N)`, `tmp Mn = bin div (lv S1) (lv F0)`; DEV: sum8 into `tmp S2` with
    X(K) = `tmp Y0 = eld P f64 8 0 (lv D) (lv K)`, `tmp Dv = bin sub P f64 (lv Y0) (lv Mn)`, `tmp Y
    = bin mul P f64 (lv Dv) (lv Dv)`. Each sum8 has its own home, Z, O and data load."""
    vV = x.lvl('V')
    z1, i1 = sum8(F, P, pre + 'a', x.lvl('N'), TP, F8, X_sum(P), vV=vV)
    mean = [z1, x.tmp('S1', i1), x.tmp('F0', cvt(P, x.lvl('N'))),
            x.tmp('Mn', bin_(P, 4, 'div', x.lvl('S1'), x.lvl('F0')))]

    def X_dev(s, k, d):
        return [s.tmp('Y0', eld(P, 4, d, k)),
                s.tmp('Dv', bin_(P, 4, 'sub', s.lvl('Y0'), x.lvl('Mn'))),
                s.tmp('Y', bin_(P, 4, 'mul', s.lvl('Dv'), s.lvl('Dv')))], s.lvl('Y')
    z2, i2 = sum8(F, P, pre + 'b', x.lvl('N'), TP, F8, X_dev, vV=vV)
    dev = [z2, x.tmp('S2', i2)]
    o1 = x.tmp('O1', ci(P, 1))
    inner = xblk(P, mean + dev + [x.tmp('N1', wbin(P, 'sub', x.lvl('N'), x.lvl('O1'))),
                                  x.tmp('F1', cvt(P, x.lvl('N1')))],
                 bin_(P, 4, 'div', x.lvl('S2'), x.lvl('F1')))
    mid = xblk(P, [o1], ifx(P, 4, bin_(P, 2, 'eq', x.lvl('N'), x.lvl('O1')), cf(P, ZERO), inner))
    return ifx(P, 4, bin_(P, 2, 'eq', x.lvl('N'), x.lvl('Z0')), cf(P, NAN), mid)


def maxmin(F, P, pre, name, E, TP, v):
    """L13 `max`, `min`, `argmax`, `argmin` of a vector v (element type E) of type T: `xblk P T n`
    with `tmp V = v`, `tmp N`, `tmp Z = ci 0`, `tmp Em = bin eq (lv N) (lv Z)`, `tmp Sn = cs P 5
    <name>`, `chk P EMPTY_REDUCE 1 (lv Em) (lv Sn)`, `bind R = cf NaN` (i64: `ci 0`), `bind Hv = cb
    0`, `bind X = ci 0`, `tmp D = data(V)`, loop(N; K) { `tmp Y = eld`; f64: `tmp U = lib isnan
    (lv Y)`, `tmp Kn = un not (lv U)`, `tmp G = bin cmp (lv Y) (lv R)`, `tmp Hn = un not (lv Hv)`,
    `tmp Tt = bin bor (lv Hn) (lv G)`, `tmp C = bin band (lv Kn) (lv Tt)`; i64: `tmp G`, `tmp Hn`,
    `tmp C = bin bor (lv Hn) (lv G)`; then `asg set (lv R) (lib where (lv C) (lv Y) (lv R))`, `asg
    set (lv X) (lib where (lv C) (lv K) (lv X))` (R15), `asg set (lv Hv) (bin bor (lv Hv) (lv C))`
    }; value `lv R` (max, min) or `lv X` (argmax, argmin). cmp is gt for max and argmax."""
    x = Ctx(F, P, pre)
    cmp = 'gt' if name in ('max', 'argmax') else 'lt'
    st = [x.tmp('V', v), x.tmp('N', ext(P, 0, x.lvl('V'))), x.tmp('Z', ci(P, 0)),
          x.tmp('Em', bin_(P, 2, 'eq', x.lvl('N'), x.lvl('Z'))),
          x.tmp('Sn', cs(P, name)),
          chk(P, 'EMPTY_REDUCE', x.lvl('Em'), [x.lvl('Sn')]),
          x.bindl('R', cf(P, NAN) if E == 4 else ci(P, 0)),
          x.bindl('Hv', cb(P, 0)),
          x.bindl('X', ci(P, 0)),
          x.tmp('D', adat(P, TP, x.lvl('V')))]

    def body():
        b = [x.tmp('Y', eld(P, E, x.lvl('D'), x.klv('K')))]
        if E == 4:
            b += [x.tmp('U', lib(P, 2, 'isnan', [x.lvl('Y')])),
                  x.tmp('Kn', un(P, 2, 'not', x.lvl('U'))),
                  x.tmp('G', bin_(P, 2, cmp, x.lvl('Y'), x.lvl('R'))),
                  x.tmp('Hn', un(P, 2, 'not', x.lvl('Hv'))),
                  x.tmp('Tt', bin_(P, 2, 'bor', x.lvl('Hn'), x.lvl('G'))),
                  x.tmp('C', bin_(P, 2, 'band', x.lvl('Kn'), x.lvl('Tt')))]
        else:
            b += [x.tmp('G', bin_(P, 2, cmp, x.lvl('Y'), x.lvl('R'))),
                  x.tmp('Hn', un(P, 2, 'not', x.lvl('Hv'))),
                  x.tmp('C', bin_(P, 2, 'bor', x.lvl('Hn'), x.lvl('G')))]
        b += [asg(P, 'set', x.lvl('R'), lib(P, E, 'where', [x.lvl('C'), x.lvl('Y'), x.lvl('R')])),
              asg(P, 'set', x.lvl('X'), lib(P, 3, 'where', [x.lvl('C'), x.klv('K'), x.lvl('X')])),
              asg(P, 'set', x.lvl('Hv'), bin_(P, 2, 'bor', x.lvl('Hv'), x.lvl('C')))]
        return b
    st += x.loop('N', 'Zl', 'Ol', 'Ll', 'K', body)
    return xblk(P, st, x.lvl('R') if name in ('max', 'min') else x.lvl('X'))


def boolred(F, P, pre, name, TP, v):
    """L13 `nnz`, `any`, `all`: `xblk P T n` with `tmp V = v`, `bind R = ci 0` (nnz), `cb 0` (any)
    or `cb 1` (all), `tmp D = data(V)`, `tmp N`, loop(N; K) { `tmp B = eld P bool 1 0 (lv D) (lv
    K)`; `asg set (lv R)` of `wbin add (lv R) (lv B)` (nnz, R7), `bin bor` (any) or `bin band`
    (all) }; value `lv R` (R12 (b))."""
    x = Ctx(F, P, pre)
    init = {'nnz': ci(P, 0), 'any': cb(P, 0), 'all': cb(P, 1)}[name]
    st = [x.tmp('V', v), x.bindl('R', init), x.tmp('D', adat(P, TP, x.lvl('V'))),
          x.tmp('N', ext(P, 0, x.lvl('V')))]

    def body():
        b = [x.tmp('B', eld(P, 2, x.lvl('D'), x.klv('K')))]
        if name == 'nnz':
            val = wbin(P, 'add', x.lvl('R'), x.lvl('B'))
        else:
            val = bin_(P, 2, 'bor' if name == 'any' else 'band', x.lvl('R'), x.lvl('B'))
        return b + [asg(P, 'set', x.lvl('R'), val)]
    st += x.loop('N', 'Zl', 'Ol', 'Ll', 'K', body)
    return xblk(P, st, x.lvl('R'))


def dyn_l10(F, P, pre, T, TP, s, n, nbytes):
    """L10's `dyn` of a fixed-size vector s of n elements (nbytes bytes) to the dynamic type T:
    `tmp S = s`, `tmp R = ext(S, 0)` (`li` of the static extent), `tmp A = anew P T 0 1 (lv R)`,
    `tmp D = data(A)`, `tmp N = ci bytes`, `mcpy (lv D) data(S) (lv N)`, value `lv A`."""
    x = Ctx(F, P, pre)
    st = [x.tmp('S', s), x.tmp('R', ext(P, 0, x.lvl('S'))),
          x.tmp('A', anew(P, T, 0, [x.lvl('R')])),
          x.tmp('D', adat(P, TP, x.lvl('A'))),
          x.tmp('N', ci(P, nbytes)),
          mcpy(P, x.lvl('D'), adat(P, TP, x.lvl('S')), x.lvl('N'))]
    return xblk(P, st, x.lvl('A'))


# ================================================================ 4f LIR helpers (3.6.6)
def lsum8(t, n, slot, B, data, elem, R):
    """Rule 23's sum8(load), spelled out: `li Z 0`, `icmp gt E n Z`, `if B E`, `sa A s` (64 bytes),
    `lf M #8000000000000000`, `stf M A - 0 8k` for k = 0 ... 7, data(V) (the lines `data`: `ldp D V
    - 0 40` of a dynamic vector, none for a fixed-size one or in a dim: form), `li Q 7`, `li O 1`,
    `isub L n O`, `loop B+1 K Z L O`, `iand W K Q`, `ldf a A W 8 0`, the element value x (elem(K)
    returns its lines and x), `fadd a a x`, `stf a A W 8 0`, `endloop B+1`, `ldf` of the eight words
    into a0 ... a7, `fadd` t1 = a0 + a1, t2 = a2 + a3, t3 = t1 + t2, t4 = a4 + a5, t5 = a6 + a7, t6
    = t4 + t5, R = t3 + t6, `else B`, `lf R #0000000000000000`, `endif B`. t names the registers."""
    r = lambda c, nm: '%s.%s%s' % (c, t, nm)
    L = ['li %s 0' % r('i', 'Z'), 'icmp gt %s %s %s' % (r('i', 'E'), n, r('i', 'Z')),
         'if %d %s' % (B, r('i', 'E')), 'sa %s s%d' % (r('p', 'A'), slot),
         'lf %s %s' % (r('f', 'M'), MZERO)]
    L += ['stf %s %s - 0 %d' % (r('f', 'M'), r('p', 'A'), 8 * k) for k in range(8)]
    L += data
    L += ['li %s 7' % r('i', 'Q'), 'li %s 1' % r('i', 'O'),
          'isub %s %s %s' % (r('i', 'L'), n, r('i', 'O')),
          'loop %d %s %s %s %s' % (B + 1, r('i', 'K'), r('i', 'Z'), r('i', 'L'), r('i', 'O')),
          'iand %s %s %s' % (r('i', 'W'), r('i', 'K'), r('i', 'Q')),
          'ldf %s %s %s 8 0' % (r('f', 'a'), r('p', 'A'), r('i', 'W'))]
    el, xr = elem(r('i', 'K'))
    L += el
    L += ['fadd %s %s %s' % (r('f', 'a'), r('f', 'a'), xr),
          'stf %s %s %s 8 0' % (r('f', 'a'), r('p', 'A'), r('i', 'W')), 'endloop %d' % (B + 1)]
    L += ['ldf %s %s - 0 %d' % (r('f', 'a%d' % k), r('p', 'A'), 8 * k) for k in range(8)]
    for d, a, b in (('t1', 'a0', 'a1'), ('t2', 'a2', 'a3'), ('t3', 't1', 't2'),
                    ('t4', 'a4', 'a5'), ('t5', 'a6', 'a7'), ('t6', 't4', 't5')):
        L.append('fadd %s %s %s' % (r('f', d), r('f', a), r('f', b)))
    L += ['fadd %s %s %s' % (R, r('f', 't3'), r('f', 't6')), 'else %d' % B,
          'lf %s %s' % (R, ZERO), 'endif %d' % B]
    return L


def lloop(t, n, B, K, body):
    """Rule 17's loop(N; K): `li Z 0`, `icmp gt E N Z`, `if B E`, `li O 1`, `isub L N O`, `loop B+1
    K Z L O`, the body, `endloop B+1`, `endif B`."""
    return ['li i.%sZ 0' % t, 'icmp gt i.%sE %s i.%sZ' % (t, n, t), 'if %d i.%sE' % (B, t),
            'li i.%sO 1' % t, 'isub i.%sL %s i.%sO' % (t, n, t),
            'loop %d %s i.%sZ i.%sL i.%sO' % (B + 1, K, t, t, t)] + body + \
        ['endloop %d' % (B + 1), 'endif %d' % B]


def lones(t, n, site, B):
    """`ones(n)` of a constant n (rule 17 / L2 of 4e-0): `li R n`, arrnew of f64 (`li K 1`, `li N
    1`, `li C 1`, `rcall sea_arr_new_u`), `lf V 1.0`, data, loop(R; K) { `stf V D K 8 0` }."""
    return ['li i.%sR %d' % (t, n), 'li i.%sek 1' % t, 'li i.%srk 1' % t, 'li i.%sc 1' % t,
            'rcall sea_arr_new_u %s 1 p.%sA 4 i.%sek i.%srk i.%sR i.%sc' % (site, t, t, t, t, t),
            'lf f.%sV #3FF0000000000000' % t, 'ldp p.%sD p.%sA - 0 40' % (t, t)] + \
        lloop(t, 'i.%sR' % t, B, 'i.%sK' % t, ['stf f.%sV p.%sD i.%sK 8 0' % (t, t, t)])


def lzeros(t, n, site):
    """`zeros(n)` (L1): `li X n`, arrnewz of f64 (`sea_arr_new`)."""
    return ['li i.%sR %d' % (t, n), 'li i.%sek 1' % t, 'li i.%srk 1' % t, 'li i.%sc 1' % t,
            'rcall sea_arr_new %s 1 p.%sA 4 i.%sek i.%srk i.%sR i.%sc' % (site, t, t, t, t, t)]


def lprintf1(t, cls, val, slot, lab, site):
    """Rule 8 for one argument: `sa S s` (8 bytes), its store, `la F dM`, `rcall sea_printf`."""
    st = {'f': 'stf', 'i': 'sti'}[cls]
    return ['sa p.%sS s%d' % (t, slot), '%s %s p.%sS - 0 0' % (st, val, t),
            'la p.%sF d%d' % (t, lab), 'rcall sea_printf %s 0 2 p.%sF p.%sS' % (site, t, t)]


def lfixlit(t, home, slot_l, slot_h, elems, size):
    """A fixed-size literal bound to a fixed-size local (rule 27 (b), rule 26 (a) / L9 (a)): `sa`
    of the local's slot, the literal's home slot (R1), each element's constant then its store at
    its offset (R3), `li N size`, `mcopy` into the local's home (no retains: no reference
    elements). elems: (kind, value, offset) with kind f (lf/stf), i (li/sti) or b (li/stb)."""
    L = ['sa %s s%d' % (home, slot_l), 'sa p.%sH s%d' % (t, slot_h)]
    for j, (k, v, off) in enumerate(elems):
        reg = '%s.%se%d' % ('f' if k == 'f' else 'i', t, j)
        L.append('%s %s %s' % ('lf' if k == 'f' else 'li', reg, v))
        L.append('%s %s p.%sH - 0 %d' % ({'f': 'stf', 'i': 'sti', 'b': 'stb'}[k], reg, t, off))
    L += ['li i.%sn %d' % (t, size), 'mcopy %s p.%sH i.%sn' % (home, t, t)]
    return L


def fmt_rec(lab, pieces):
    """A fmt data record with its pieces (rule 8, 3.6.2)."""
    return ['fmt d%d %d' % (lab, len(pieces))] + pieces


def J(*parts):
    out = []
    for p in parts:
        out += [p] if isinstance(p, str) else list(p)
    return '\n'.join(out) + '\n'


# ================================================================ lib_rule23 (rule 23)
SEA['lib_rule23'] = '''fn total(x: f64[]) -> f64 {
    // lib_rule23 -- DESIGN.md 3.6.6 rule 23 (reductions): its example verbatim on line 3 (x is p1)
    let s = sum(x)
    return s
}
printf("%g\\n", total(ones(9)))
printf("%g\\n", total(zeros(2)))
// 3.5.9 L13: sum of an f64 vector is sum8 (the accumulator home of the appended type f64[8], R14;
// the lane K & 7 by wbin and, R13), its ifx taking the register of s by R12 (a)
'''
AST['lib_rule23'] = '''
type 0:1:13 f64 v 0
param 0:1:10 x 0 0
type 0:1:23 f64 s 0
pname 0:3:9 s
name 0:3:13 sum
name 0:3:17 x
call 0:3:13 1
let 0:3:5 0
name 0:4:12 s
return 0:4:5 1
block 0:1:27 2
fn 0:1:1 total 0 1 1
name 0:6:1 printf
str 0:6:8 %25g%0A
name 0:6:16 total
name 0:6:22 ones
int 0:6:27 9
call 0:6:22 1
call 0:6:16 1
call 0:6:1 2
cstmt 0:6:1
name 0:7:1 printf
str 0:7:8 %25g%0A
name 0:7:16 total
name 0:7:22 zeros
int 0:7:28 2
call 0:7:22 1
call 0:7:16 1
call 0:7:1 2
cstmt 0:7:1
prog 3
'''
# sea.hir1: f64[] 10 (first referred to by the ones of .main: functions in fid order, 3.5.4);
# total is function 2 (two call sites: not inlined); sum(x) is `lib sum` of type f64 at the callee.
HIR1['lib_rule23'] = '''
tvec 10 4
fn 1 .main main 1 0 0 0:1:1
ci 0:6:27 3 9
lib 0:6:22 10 ones 1
call 0:6:16 4 2 1
fconv 0:6:8 1 - - - g
ftext 0:6:8 1 %0A
fmt 0:6:8 1 2
lib 0:6:1 1 printf 1
eval 0:6:1
ci 0:7:28 3 2
lib 0:7:22 10 zeros 1
call 0:7:16 4 2 1
fconv 0:7:8 1 - - - g
ftext 0:7:8 1 %0A
fmt 0:7:8 1 2
lib 0:7:1 1 printf 1
eval 0:7:1
block 0:1:1 2
end
fn 2 total fn 4 1 1 0:1:1
par x 10 val
loc s 4 let 0:3:9
lv 0:3:17 10 1
lib 0:3:13 4 sum 1
bind 0:3:5 2
lv 0:4:12 4 2
ret 0:4:5 1
block 0:1:27 2
end
'''


def hirl_lib_rule23():
    """sea.hirl: tptr 11 4 (first referred to by the adat of ones(9) in .main), then F8 = tfvec 12
    4 8 (R14: first referred to by sum8's home in total; sea.hir has no f64[8]). .main: ones(9) L2,
    zeros(2) L1. total: L13 sum (f64): `xblk P f64 3` with `tmp V = lv x`, `tmp N = ext(V, 0)`,
    sum8's `tmp Z`, value sum8's ifx (P the lib's position 0:3:13; lv x keeps 0:3:17)."""
    F1, F2 = Fn(), Fn()
    m = [(['ci 0:6:27 3 9', 'lib 0:6:22 10 ones 1'],
          cat(L2(F1, '0:6:22', 10, 4, 11, 'o', r=ci('0:6:27', 9)))),
         (['ci 0:7:28 3 2', 'lib 0:7:22 10 zeros 1'], cat(L1('0:7:22', 10, [ci('0:7:28', 2)])))]
    P = '0:3:13'
    x = Ctx(F2, P, 's')
    st = [x.tmp('V', lv('0:3:17', 10, 1)), x.tmp('N', ext(P, 0, x.lvl('V')))]
    z, val = sum8(F2, P, 'q', x.lvl('N'), 11, 12, X_sum(P), vV=x.lvl('V'))
    t = (['lv 0:3:17 10 1', 'lib 0:3:13 4 sum 1'], cat(xblk(P, st + [z], val)))
    return make_hirl(HIR1['lib_rule23'], ['tptr 11 4', 'tfvec 12 4 8'], {1: (F1, m), 2: (F2, [t])})


HIRL['lib_rule23'] = hirl_lib_rule23
# sea.lir1. .main: ones(9) (rule 17; an owned temporary of the call, released right after it), the
# printf of the result (slot s1); zeros(2) (arrnewz), the same (slot s2). total: rule 23's example,
# line 3: V is x (p1, T1's alias), N `ldi i2 p1 - 0 16`, sum8 with data `ldp p7 p1 - 0 40` and x =
# `ldf f14 p7 i11 8 0`, its R the register of s (R12 (a): f29, no mov); then `ret 1 f29` (a result
# function: no release, nothing after the ret).
LIR1['lib_rule23'] = J(
    'func .main main 0:1:1 0 0', 'slot s1 8 8', 'slot s2 8 8',
    lones('o', 9, '0:6', 1),
    'call total 1 f.r1 1 p.oA', 'release p.oA',
    lprintf1('a', 'f', 'f.r1', 1, 1, '0:6'),
    lzeros('z', 2, '0:7'),
    'call total 1 f.r2 1 p.zA', 'release p.zA',
    lprintf1('b', 'f', 'f.r2', 2, 2, '0:7'),
    'ret 0', 'endfunc',
    'func total fn 0:1:1 1 p.x 1 f', 'slot s1 64 8',
    'ldi i.N p.x - 0 16',
    lsum8('q', 'i.N', 1, 1, ['ldp p.qD p.x - 0 40'],
          lambda K: (['ldf f.qY p.qD %s 8 0' % K], 'f.qY'), 'f.s'),
    'ret 1 f.s', 'endfunc',
    fmt_rec(1, ['fconv - - - g f', 'ftext %0A']),
    fmt_rec(2, ['fconv - - - g f', 'ftext %0A']))
# ones(9): the lanes a0 = -0 + 1 + 1 = 2, a1 ... a7 = 1; ((2 + 1) + (1 + 1)) + ((1 + 1) + (1 + 1))
# = 9. zeros(2): a0 = a1 = -0 + 0 = +0, a2 ... a7 = -0; (0 + 0) + (-0 + -0) = +0, the other half
# -0, +0 + -0 = +0, printed 0.
OUT['lib_rule23'] = '9\n0\n'
NAMES.append('lib_rule23')

# ================================================================ lib_rule24 (rule 24)
SEA['lib_rule24'] = '''fn top(c: f64[]) -> i64 {
    // lib_rule24 -- DESIGN.md 3.6.6 rule 24 (sorting and searching): its example verbatim on
    // line 8, argsort with desc: true of c in p1. 3.5.9 L14 and R16: the lib argsort stays in
    // sea.hirl (this function is sea.hir unchanged) and is lowered to rcall sea_argsort with
    // the vector and the desc value as its two arguments; r[0], the index of the largest
    // element (the first of equal ones: the sort is stable), is read by rule 18 and returned
    // (r is released before the ret, rule 16 (c))
    let r = argsort(c, desc: true)
    return r[0]
}
printf("%d\\n", top(ones(3)))
printf("%d\\n", top(zeros(2)))
'''
AST['lib_rule24'] = '''
type 0:1:11 f64 v 0
param 0:1:8 c 0 0
type 0:1:21 i64 s 0
pname 0:8:9 r
name 0:8:13 argsort
name 0:8:21 c
true 0:8:30
narg 0:8:24 desc
call 0:8:13 2
let 0:8:5 0
name 0:9:12 r
int 0:9:14 0
index 0:9:12 1
return 0:9:5 1
block 0:1:25 2
fn 0:1:1 top 0 1 1
name 0:11:1 printf
str 0:11:8 %25d%0A
name 0:11:16 top
name 0:11:20 ones
int 0:11:25 3
call 0:11:20 1
call 0:11:16 1
call 0:11:1 2
cstmt 0:11:1
name 0:12:1 printf
str 0:12:8 %25d%0A
name 0:12:16 top
name 0:12:20 zeros
int 0:12:26 2
call 0:12:20 1
call 0:12:16 1
call 0:12:1 2
cstmt 0:12:1
prog 3
'''
# sea.hir1: f64[] 10 (the ones of .main), i64[] 11 (loc r of top). argsort(c, desc: true) is `lib
# argsort` with the vector and the desc: value as written (`cb` at the `true`, 0:8:30): no narg
# survives (3.5.5 phase-4 notes), and the written order is the source order (no seq).
HIR1['lib_rule24'] = '''
tvec 10 4
tvec 11 3
fn 1 .main main 1 0 0 0:1:1
ci 0:11:25 3 3
lib 0:11:20 10 ones 1
call 0:11:16 3 2 1
fconv 0:11:8 1 - - - d
ftext 0:11:8 1 %0A
fmt 0:11:8 1 2
lib 0:11:1 1 printf 1
eval 0:11:1
ci 0:12:26 3 2
lib 0:12:20 10 zeros 1
call 0:12:16 3 2 1
fconv 0:12:8 1 - - - d
ftext 0:12:8 1 %0A
fmt 0:12:8 1 2
lib 0:12:1 1 printf 1
eval 0:12:1
block 0:1:1 2
end
fn 2 top fn 3 1 1 0:1:1
par c 10 val
loc r 11 let 0:8:9
lv 0:8:21 10 1
cb 0:8:30 2 1
lib 0:8:13 11 argsort 2
bind 0:8:5 2
lv 0:9:12 11 2
ci 0:9:14 3 0
idx 0:9:12 3 1
ret 0:9:5 1
block 0:1:25 2
end
'''


def hirl_lib_rule24():
    """sea.hirl: tptr 12 4 (the adat of ones(3) in .main). .main: ones(3) L2, zeros(2) L1. top holds
    none of the rewritten constructs (R16: lib argsort stays; r[0] is a scalar idx), so it is written
    exactly as in sea.hir ("Unchanged functions")."""
    F1 = Fn()
    m = [(['ci 0:11:25 3 3', 'lib 0:11:20 10 ones 1'],
          cat(L2(F1, '0:11:20', 10, 4, 12, 'o', r=ci('0:11:25', 3)))),
         (['ci 0:12:26 3 2', 'lib 0:12:20 10 zeros 1'], cat(L1('0:12:20', 10, [ci('0:12:26', 2)])))]
    return make_hirl(HIR1['lib_rule24'], ['tptr 12 4'], {1: (F1, m)})


HIRL['lib_rule24'] = hirl_lib_rule24
# sea.lir1. .main as in lib_rule23 with top's i64 result (stored by sti, fconv class i). top: rule
# 24's example, line 8: the vector c (p1, an lv: no instruction), desc `cb 1` -> `li i2 1`, `rcall
# sea_argsort 0:8 1 p3 2 p1 i2` into r (rule 2's destination; owned, moved into r); line 9 r[0] by
# rule 18 (`li` of the index, ext(r, 0), chkb, data, ldi), then rule 16 (c): the value first, r
# released, `ret 1`.
LIR1['lib_rule24'] = J(
    'func .main main 0:1:1 0 0', 'slot s1 8 8', 'slot s2 8 8',
    lones('o', 3, '0:11', 1),
    'call top 1 i.r1 1 p.oA', 'release p.oA',
    lprintf1('a', 'i', 'i.r1', 1, 1, '0:11'),
    lzeros('z', 2, '0:12'),
    'call top 1 i.r2 1 p.zA', 'release p.zA',
    lprintf1('b', 'i', 'i.r2', 2, 2, '0:12'),
    'ret 0', 'endfunc',
    'func top fn 0:1:1 1 p.c 1 i',
    'li i.d 1',
    'rcall sea_argsort 0:8 1 p.r 2 p.c i.d',
    'li i.k 0', 'ldi i.e p.r - 0 16', 'chkb i.k i.e 0 0:9', 'ldp p.D p.r - 0 40',
    'ldi i.v p.D i.k 8 0',
    'release p.r', 'ret 1 i.v', 'endfunc',
    fmt_rec(1, ['fconv - - - d i', 'ftext %0A']),
    fmt_rec(2, ['fconv - - - d i', 'ftext %0A']))
# argsort of [1, 1, 1] descending is stable: [0, 1, 2], r[0] = 0; of [0, 0]: [0, 1], r[0] = 0.
OUT['lib_rule24'] = '0\n0\n'
NAMES.append('lib_rule24')

# ================================================================ lib_mean_i64 (L13 isum, mean of i64)
SEA['lib_mean_i64'] = '''let w = [3, 5, 9]
let t = sum(w)
let m = mean(w)
printf("%d %g\\n", t, m)
// lib_mean_i64 -- DESIGN.md 3.5.9 L13 on a fixed-size i64 vector: isum (the extent loaded after
// the data, iaddc with the call's line), sum's accumulator taking the register of t (R12 (b)),
// and mean converting the sum before n (rule 23)
'''
AST['lib_mean_i64'] = '''
pname 0:1:5 w
int 0:1:10 3
int 0:1:13 5
int 0:1:16 9
row 0:1:10 3
array 0:1:9 1
let 0:1:1 0
pname 0:2:5 t
name 0:2:9 sum
name 0:2:13 w
call 0:2:9 1
let 0:2:1 0
pname 0:3:5 m
name 0:3:9 mean
name 0:3:14 w
call 0:3:9 1
let 0:3:1 0
name 0:4:1 printf
str 0:4:8 %25d%20%25g%0A
name 0:4:19 t
name 0:4:22 m
call 0:4:1 3
cstmt 0:4:1
prog 4
'''
# sea.hir1: i64[3] 10 (loc w; also the row's type, the horizontal join of three i64). The literal is
# fixed-size (3 elements, LANGUAGE.md 6.9); sum of an i64 vector is i64, mean f64 (2.6.2 "Readings
# fixed by 4f"); a fixed-size argument of a reduction is passed as it is (no dyn).
HIR1['lib_mean_i64'] = '''
tfvec 10 3 3
fn 1 .main main 1 0 3 0:1:1
loc w 10 let 0:1:5
loc t 3 let 0:2:5
loc m 4 let 0:3:5
ci 0:1:10 3 3
ci 0:1:13 3 5
ci 0:1:16 3 9
row 0:1:10 10 3
arr 0:1:9 10 1
bind 0:1:1 1
lv 0:2:13 10 1
lib 0:2:9 3 sum 1
bind 0:2:1 2
lv 0:3:14 10 1
lib 0:3:9 4 mean 1
bind 0:3:1 3
lv 0:4:19 3 2
fconv 0:4:8 1 - - - d
ftext 0:4:8 1 %20
lv 0:4:22 4 3
fconv 0:4:8 1 - - - g
ftext 0:4:8 1 %0A
fmt 0:4:8 1 4
lib 0:4:1 1 printf 1
eval 0:4:1
block 0:1:1 4
end
'''


def hirl_lib_mean_i64():
    """sea.hirl: tptr 11 3 (the adat of the literal's home; isum's data is of the same element
    type). Line 1 L9 (a). Line 2 L13 sum (i64): `xblk P i64 n` with `tmp V = lv w` and isum, value
    `lv R` (R12 (b)). Line 3 L13 mean (i64): `tmp V`, isum, `tmp S = cvt P f64 (lv R)`, `tmp F =
    cvt P f64 (lv N)`, value `bin div P f64 (lv S) (lv F)`."""
    F = Fn()
    eds = [('''
ci 0:1:10 3 3
ci 0:1:13 3 5
ci 0:1:16 3 9
row 0:1:10 10 3
arr 0:1:9 10 1
''', cat(L9a(F, '0:1:9', 10, 3, 11, 'l', [((0, 0), ci('0:1:10', 3)), ((0, 1), ci('0:1:13', 5)),
                                          ((0, 2), ci('0:1:16', 9))], 1)))]
    P = '0:2:9'
    x = Ctx(F, P, 's')
    st = [x.tmp('V', lv('0:2:13', 10, 1))] + isum(x, P, 11, x.lvl('V'), False)
    eds.append((['lv 0:2:13 10 1', 'lib 0:2:9 3 sum 1'], cat(xblk(P, st, x.lvl('R')))))
    P = '0:3:9'
    x = Ctx(F, P, 'm')
    st = [x.tmp('V', lv('0:3:14', 10, 1))] + isum(x, P, 11, x.lvl('V'), False)
    st += [x.tmp('S', cvt(P, x.lvl('R'))), x.tmp('F', cvt(P, x.lvl('N')))]
    eds.append((['lv 0:3:14 10 1', 'lib 0:3:9 4 mean 1'],
                cat(xblk(P, st, bin_(P, 4, 'div', x.lvl('S'), x.lvl('F'))))))
    return make_hirl(HIR1['lib_mean_i64'], ['tptr 11 3'], {1: (F, eds)})


HIRL['lib_mean_i64'] = hirl_lib_mean_i64
# sea.lir1. Line 1: w's slot s1 (24 bytes), the literal's home s2, its stores, the copy (rule 27
# (b), (c)). Line 2, rule 23's i64 sum: `li R 0` into t (R12 (b): R is t's register), data (none:
# the home of a fixed-size vector, R2), n `li 3` (after the data), loop(n; K) with `ldi x D K 8 0`
# (D = w's home) and `iaddc t t x 0:2`. Line 3, mean: the same sum into its own R (the value is the
# fdiv), `itof S R` (the sum converted first), `itof F n`, `fdiv m S F` (rule 2: m's register).
# Line 4: printf slot s3 (two arguments).
LIR1['lib_mean_i64'] = J(
    'func .main main 0:1:1 0 0', 'slot s1 24 8', 'slot s2 24 8', 'slot s3 16 8',
    lfixlit('l', 'p.w', 1, 2, [('i', 3, 0), ('i', 5, 8), ('i', 9, 16)], 24),
    'li i.t 0', 'li i.sN 3',
    lloop('s', 'i.sN', 1, 'i.sK', ['ldi i.sY p.w i.sK 8 0', 'iaddc i.t i.t i.sY 0:2']),
    'li i.mR 0', 'li i.mN 3',
    lloop('m', 'i.mN', 3, 'i.mK', ['ldi i.mY p.w i.mK 8 0', 'iaddc i.mR i.mR i.mY 0:3']),
    'itof f.mS i.mR', 'itof f.mF i.mN', 'fdiv f.m f.mS f.mF',
    'sa p.S s3', 'sti i.t p.S - 0 0', 'stf f.m p.S - 0 8', 'la p.F d1',
    'rcall sea_printf 0:4 0 2 p.F p.S',
    'ret 0', 'endfunc',
    fmt_rec(1, ['fconv - - - d i', 'ftext %20', 'fconv - - - g f', 'ftext %0A']))
# sum = 3 + 5 + 9 = 17 (every partial sum fits); mean = 17.0 / 3.0 = 5.666666666666667 (%g: 6
# significant digits) -> 5.66667.
OUT['lib_mean_i64'] = '17 5.66667\n'
NAMES.append('lib_mean_i64')

# ================================================================ lib_variance (L13 variance, std)
SEA['lib_variance'] = '''fn spread(x: f64[]) {
    let v = variance(x)
    let d = std(x)
    printf("%g %g\\n", v, d)
}
spread(ones(3))
spread(zeros(0))
// lib_variance -- DESIGN.md 3.5.9 L13: variance (n = 0 NaN, n = 1 zero, else the two-pass
// mean and the deviations, each sum8 with its own home slot; the outer ifx takes the register of
// v by R12 (a), the inner one is its arm) and std (the variance xblk, then fsqrt)
'''
AST['lib_variance'] = '''
type 0:1:14 f64 v 0
param 0:1:11 x 0 0
pname 0:2:9 v
name 0:2:13 variance
name 0:2:22 x
call 0:2:13 1
let 0:2:5 0
pname 0:3:9 d
name 0:3:13 std
name 0:3:17 x
call 0:3:13 1
let 0:3:5 0
name 0:4:5 printf
str 0:4:12 %25g%20%25g%0A
name 0:4:23 v
name 0:4:26 d
call 0:4:5 3
cstmt 0:4:5
block 0:1:21 3
fn 0:1:1 spread 0 1 0
name 0:6:1 spread
name 0:6:8 ones
int 0:6:13 3
call 0:6:8 1
call 0:6:1 1
cstmt 0:6:1
name 0:7:1 spread
name 0:7:8 zeros
int 0:7:14 0
call 0:7:8 1
call 0:7:1 1
cstmt 0:7:1
prog 3
'''
# sea.hir1: f64[] 10; spread is function 2 (no result: rty 1), called twice (each an eval).
HIR1['lib_variance'] = '''
tvec 10 4
fn 1 .main main 1 0 0 0:1:1
ci 0:6:13 3 3
lib 0:6:8 10 ones 1
call 0:6:1 1 2 1
eval 0:6:1
ci 0:7:14 3 0
lib 0:7:8 10 zeros 1
call 0:7:1 1 2 1
eval 0:7:1
block 0:1:1 2
end
fn 2 spread fn 1 1 2 0:1:1
par x 10 val
loc v 4 let 0:2:9
loc d 4 let 0:3:9
lv 0:2:22 10 1
lib 0:2:13 4 variance 1
bind 0:2:5 2
lv 0:3:17 10 1
lib 0:3:13 4 std 1
bind 0:3:5 3
lv 0:4:23 4 2
fconv 0:4:12 1 - - - g
ftext 0:4:12 1 %20
lv 0:4:26 4 3
fconv 0:4:12 1 - - - g
ftext 0:4:12 1 %0A
fmt 0:4:12 1 4
lib 0:4:5 1 printf 1
eval 0:4:5
block 0:1:21 3
end
'''


def hirl_lib_variance():
    """sea.hirl: tptr 11 4 (the adat of ones(3) in .main), F8 = tfvec 12 4 8 (first referred to by
    the first sum8 home in spread). .main: ones(3) L2, zeros(0) L1. spread: line 2 L13 variance:
    `xblk P f64 3` with `tmp V = lv x`, `tmp N`, `tmp Z0 = ci 0`, value variance_val (two sum8,
    each with its own home, Z, O and data load). Line 3 L13 std: `xblk P f64 2` with `tmp V = lv x`,
    `tmp Vr = ` the xblk of variance with this tmp V (`xblk P f64 2`: `tmp N`, `tmp Z0`, the same
    value), value `lib sqrt P f64 (lv Vr)`."""
    F1, F2 = Fn(), Fn()
    m = [(['ci 0:6:13 3 3', 'lib 0:6:8 10 ones 1'],
          cat(L2(F1, '0:6:8', 10, 4, 11, 'o', r=ci('0:6:13', 3)))),
         (['ci 0:7:14 3 0', 'lib 0:7:8 10 zeros 1'], cat(L1('0:7:8', 10, [ci('0:7:14', 0)])))]
    P = '0:2:13'
    x = Ctx(F2, P, 'v')
    st = [x.tmp('V', lv('0:2:22', 10, 1)), x.tmp('N', ext(P, 0, x.lvl('V'))),
          x.tmp('Z0', ci(P, 0))]
    t1 = (['lv 0:2:22 10 1', 'lib 0:2:13 4 variance 1'],
          cat(xblk(P, st, variance_val(F2, P, 'vs', x, 11, 12))))
    P = '0:3:13'
    x = Ctx(F2, P, 'd')
    v0 = x.tmp('V', lv('0:3:17', 10, 1))
    var = xblk(P, [x.tmp('N', ext(P, 0, x.lvl('V'))), x.tmp('Z0', ci(P, 0))],
               variance_val(F2, P, 'ds', x, 11, 12))
    st = [v0, x.tmp('Vr', var)]
    t2 = (['lv 0:3:17 10 1', 'lib 0:3:13 4 std 1'],
          cat(xblk(P, st, lib(P, 4, 'sqrt', [x.lvl('Vr')]))))
    return make_hirl(HIR1['lib_variance'], ['tptr 11 4', 'tfvec 12 4 8'],
                     {1: (F1, m), 2: (F2, [t1, t2])})


HIRL['lib_variance'] = hirl_lib_variance


def lvariance(t, R, B, s1):
    """Rule 23's variance of the f64 vector x (p.x) into R, blocks B ... B+5, slots s1, s1 + 1: `li
    Z 0`, `icmp eq E0 n Z`, `if B E0`, `lf R NaN`, `else B`, `li O 1`, `icmp eq E1 n O`, `if B+1
    E1`, `lf R 0`, `else B+1`, the mean m (sum8 with x = `ldf x D K 8 0`, `itof F n`, `fdiv m S
    F`), sum8 with x = `ldf y D K 8 0`, `fsub d y m`, `fmul x d d`, `isub N1 n O`, `itof F N1`,
    `fdiv R s F`, `endif B+1`, `endif B`; n = ext(x, 0) first (L13's tmp N, before its tmp Z0)."""
    n = 'i.%sN' % t
    L = ['ldi %s p.x - 0 16' % n, 'li i.%sZ0 0' % t, 'icmp eq i.%sE0 %s i.%sZ0' % (t, n, t),
         'if %d i.%sE0' % (B, t), 'lf %s %s' % (R, NAN), 'else %d' % B,
         'li i.%sO1 1' % t, 'icmp eq i.%sE1 %s i.%sO1' % (t, n, t), 'if %d i.%sE1' % (B + 1, t),
         'lf %s %s' % (R, ZERO), 'else %d' % (B + 1)]
    L += lsum8(t + 'a', n, s1, B + 2, ['ldp p.%saD p.x - 0 40' % t],
               lambda K: (['ldf f.%saY p.%saD %s 8 0' % (t, t, K)], 'f.%saY' % t), 'f.%sS1' % t)
    L += ['itof f.%sF0 %s' % (t, n), 'fdiv f.%sMn f.%sS1 f.%sF0' % (t, t, t)]
    L += lsum8(t + 'b', n, s1 + 1, B + 4, ['ldp p.%sbD p.x - 0 40' % t],
               lambda K: (['ldf f.%sY0 p.%sbD %s 8 0' % (t, t, K),
                           'fsub f.%sDv f.%sY0 f.%sMn' % (t, t, t),
                           'fmul f.%sbY f.%sDv f.%sDv' % (t, t, t)], 'f.%sbY' % t), 'f.%sS2' % t)
    L += ['isub i.%sN1 %s i.%sO1' % (t, n, t), 'itof f.%sF1 i.%sN1' % (t, t),
          'fdiv %s f.%sS2 f.%sF1' % (R, t, t), 'endif %d' % (B + 1), 'endif %d' % B]
    return L


# sea.lir1. .main: ones(3), `call spread 0 1 p` (an eval of a call without a result), the
# temporary released; zeros(0) the same. spread: line 2, the variance into v (R12 (a): the outer
# ifx's R is v's register; the inner ifx is its arm, so every write goes to v), blocks 1-6, slots
# s1, s2; line 3, std: the same variance into a new register (Vr; T1: a tmp has no old value), blocks
# 7-12, slots s3, s4, then `fsqrt d Vr` (rule 36, d's register by rule 2); line 4, printf (slot s5,
# two f64 words); `ret 0` (no result; v and d hold no counts).
LIR1['lib_variance'] = J(
    'func .main main 0:1:1 0 0',
    lones('o', 3, '0:6', 1),
    'call spread 0 1 p.oA', 'release p.oA',
    lzeros('z', 0, '0:7'),
    'call spread 0 1 p.zA', 'release p.zA',
    'ret 0', 'endfunc',
    'func spread fn 0:1:1 1 p.x 0',
    'slot s1 64 8', 'slot s2 64 8', 'slot s3 64 8', 'slot s4 64 8', 'slot s5 16 8',
    lvariance('v', 'f.v', 1, 1),
    lvariance('d', 'f.Vr', 7, 3),
    'fsqrt f.d f.Vr',
    'sa p.S s5', 'stf f.v p.S - 0 0', 'stf f.d p.S - 0 8', 'la p.F d1',
    'rcall sea_printf 0:4 0 2 p.F p.S',
    'ret 0', 'endfunc',
    fmt_rec(1, ['fconv - - - g f', 'ftext %20', 'fconv - - - g f', 'ftext %0A']))
# ones(3): n = 3; the mean's lanes a0 = a1 = a2 = 1, a3 ... a7 = -0: (2 + 1) + (-0 + -0) = 3, m =
# 3 / 3 = 1; the deviations (1 - 1) * (1 - 1) = +0, s = +0, variance 0 / 2 = 0, std sqrt(0) = 0.
# zeros(0): n = 0, variance NaN (the cf #7FF8000000000000), std sqrt(NaN) = NaN, printed NaN
# (LANGUAGE.md 11.1).
OUT['lib_variance'] = '0 0\nNaN NaN\n'
NAMES.append('lib_variance')

# ================================================================ lib_max (L13 max, argmin)
SEA['lib_max'] = '''let v = [2.5, nan, 7.0, 0.5, 7.0]
let w = [4, 1, 9, 1]
let a = max(v)
let b = argmin(w)
printf("%g %d\\n", a, b)
// lib_max -- DESIGN.md 3.5.9 L13 on fixed-size vectors: max of f64 (EMPTY_REDUCE with the
// function's name, NaN ignored, the first maximum; R15's where values) and argmin of i64
'''
AST['lib_max'] = '''
pname 0:1:5 v
float 0:1:10 #4004000000000000
name 0:1:15 nan
float 0:1:20 #401C000000000000
float 0:1:25 #3FE0000000000000
float 0:1:30 #401C000000000000
row 0:1:10 5
array 0:1:9 1
let 0:1:1 0
pname 0:2:5 w
int 0:2:10 4
int 0:2:13 1
int 0:2:16 9
int 0:2:19 1
row 0:2:10 4
array 0:2:9 1
let 0:2:1 0
pname 0:3:5 a
name 0:3:9 max
name 0:3:13 v
call 0:3:9 1
let 0:3:1 0
pname 0:4:5 b
name 0:4:9 argmin
name 0:4:16 w
call 0:4:9 1
let 0:4:1 0
name 0:5:1 printf
str 0:5:8 %25g%20%25d%0A
name 0:5:19 a
name 0:5:22 b
call 0:5:1 3
cstmt 0:5:1
prog 5
'''
# sea.hir1: f64[5] 10 (loc v), i64[4] 11 (loc w); nan is the cf #7FF8000000000000 at its name
# (3.5.5 cf row). max of one f64 vector is f64, argmin i64.
HIR1['lib_max'] = '''
tfvec 10 4 5
tfvec 11 3 4
fn 1 .main main 1 0 4 0:1:1
loc v 10 let 0:1:5
loc w 11 let 0:2:5
loc a 4 let 0:3:5
loc b 3 let 0:4:5
cf 0:1:10 4 #4004000000000000
cf 0:1:15 4 #7FF8000000000000
cf 0:1:20 4 #401C000000000000
cf 0:1:25 4 #3FE0000000000000
cf 0:1:30 4 #401C000000000000
row 0:1:10 10 5
arr 0:1:9 10 1
bind 0:1:1 1
ci 0:2:10 3 4
ci 0:2:13 3 1
ci 0:2:16 3 9
ci 0:2:19 3 1
row 0:2:10 11 4
arr 0:2:9 11 1
bind 0:2:1 2
lv 0:3:13 10 1
lib 0:3:9 4 max 1
bind 0:3:1 3
lv 0:4:16 11 2
lib 0:4:9 3 argmin 1
bind 0:4:1 4
lv 0:5:19 4 3
fconv 0:5:8 1 - - - g
ftext 0:5:8 1 %20
lv 0:5:22 3 4
fconv 0:5:8 1 - - - d
ftext 0:5:8 1 %0A
fmt 0:5:8 1 4
lib 0:5:1 1 printf 1
eval 0:5:1
block 0:1:1 5
end
'''


def hirl_lib_max():
    """sea.hirl: tptr 12 4 (v's literal), tptr 13 3 (w's literal). Lines 1-2 L9 (a); line 3 L13
    max (f64), line 4 L13 argmin (i64), each with its cs of the function's name (type 5)."""
    F = Fn()
    eds = [('''
cf 0:1:10 4 #4004000000000000
cf 0:1:15 4 #7FF8000000000000
cf 0:1:20 4 #401C000000000000
cf 0:1:25 4 #3FE0000000000000
cf 0:1:30 4 #401C000000000000
row 0:1:10 10 5
arr 0:1:9 10 1
''', cat(L9a(F, '0:1:9', 10, 4, 12, 'l', [
        ((0, 0), cf('0:1:10', '#4004000000000000')), ((0, 1), cf('0:1:15', NAN)),
        ((0, 2), cf('0:1:20', '#401C000000000000')), ((0, 3), cf('0:1:25', '#3FE0000000000000')),
        ((0, 4), cf('0:1:30', '#401C000000000000'))], 1))),
           ('''
ci 0:2:10 3 4
ci 0:2:13 3 1
ci 0:2:16 3 9
ci 0:2:19 3 1
row 0:2:10 11 4
arr 0:2:9 11 1
''', cat(L9a(F, '0:2:9', 11, 3, 13, 'k', [
        ((0, 0), ci('0:2:10', 4)), ((0, 1), ci('0:2:13', 1)), ((0, 2), ci('0:2:16', 9)),
        ((0, 3), ci('0:2:19', 1))], 1))),
           (['lv 0:3:13 10 1', 'lib 0:3:9 4 max 1'],
            cat(maxmin(F, '0:3:9', 'a', 'max', 4, 12, lv('0:3:13', 10, 1)))),
           (['lv 0:4:16 11 2', 'lib 0:4:9 3 argmin 1'],
            cat(maxmin(F, '0:4:9', 'b', 'argmin', 3, 13, lv('0:4:16', 11, 2))))]
    return make_hirl(HIR1['lib_max'], ['tptr 12 4', 'tptr 13 3'], {1: (F, eds)})


HIRL['lib_max'] = hirl_lib_max
# sea.lir1. Lines 1-2: the homes of v (s1, 40 bytes) and w (s3, 32 bytes) with their literals (s2,
# s4). Line 3, rule 23's max (f64): n `li 5` (a fixed-size extent), `li Z 0`, `icmp eq E n Z`, `la
# S d1` (str d1 max, rule 38), `chk E EMPTY_REDUCE 0:3 1 S`, `lf R NaN` into a (R12 (b): the
# value is lv R), `li H 0`, `li X 0`, data (none: the home), loop(n; K) with `ldf x v K 8 0`, `fnan
# u x`, `bnot k u`, `fcmp gt g x R`, `bnot h H`, `ior t h g`, `iand c k t`, `fsel R c x R`, `isel X
# c K X`, `ior H H c` (blocks 1, 2). Line 4, argmin (i64): the same with `la S d2` (str d2
# argmin), `li R 0`, X the register of b, `icmp lt g x R`, `bnot h H`, `ior c h g`, `isel R c x
# R` (blocks 3, 4). Line 5: printf (s5; fmt d3).
LIR1['lib_max'] = J(
    'func .main main 0:1:1 0 0',
    'slot s1 40 8', 'slot s2 40 8', 'slot s3 32 8', 'slot s4 32 8', 'slot s5 16 8',
    lfixlit('l', 'p.v', 1, 2, [('f', '#4004000000000000', 0), ('f', NAN, 8),
                               ('f', '#401C000000000000', 16), ('f', '#3FE0000000000000', 24),
                               ('f', '#401C000000000000', 32)], 40),
    lfixlit('k', 'p.w', 3, 4, [('i', 4, 0), ('i', 1, 8), ('i', 9, 16), ('i', 1, 24)], 32),
    'li i.aN 5', 'li i.aZ 0', 'icmp eq i.aEm i.aN i.aZ', 'la p.aSn d1',
    'chk i.aEm EMPTY_REDUCE 0:3 1 p.aSn',
    'lf f.a %s' % NAN, 'li i.aHv 0', 'li i.aX 0',
    lloop('al', 'i.aN', 1, 'i.aK', [
        'ldf f.aY p.v i.aK 8 0', 'fnan i.aU f.aY', 'bnot i.aKn i.aU', 'fcmp gt i.aG f.aY f.a',
        'bnot i.aHn i.aHv', 'ior i.aTt i.aHn i.aG', 'iand i.aC i.aKn i.aTt',
        'fsel f.a i.aC f.aY f.a', 'isel i.aX i.aC i.aK i.aX', 'ior i.aHv i.aHv i.aC']),
    'li i.bN 4', 'li i.bZ 0', 'icmp eq i.bEm i.bN i.bZ', 'la p.bSn d2',
    'chk i.bEm EMPTY_REDUCE 0:4 1 p.bSn',
    'li i.bR 0', 'li i.bHv 0', 'li i.b 0',
    lloop('bl', 'i.bN', 3, 'i.bK', [
        'ldi i.bY p.w i.bK 8 0', 'icmp lt i.bG i.bY i.bR', 'bnot i.bHn i.bHv',
        'ior i.bC i.bHn i.bG', 'isel i.bR i.bC i.bY i.bR', 'isel i.b i.bC i.bK i.b',
        'ior i.bHv i.bHv i.bC']),
    'sa p.S s5', 'stf f.a p.S - 0 0', 'sti i.b p.S - 0 8', 'la p.F d3',
    'rcall sea_printf 0:5 0 2 p.F p.S',
    'ret 0', 'endfunc',
    'str d1 max', 'str d2 argmin',
    fmt_rec(3, ['fconv - - - g f', 'ftext %20', 'fconv - - - d i', 'ftext %0A']))
# max([2.5, NaN, 7.0, 0.5, 7.0]): NaN ignored, the first maximum 7 (LANGUAGE.md 10.5); argmin([4,
# 1, 9, 1]): the first minimum, index 1.
OUT['lib_max'] = '7 1\n'
NAMES.append('lib_max')

# ================================================================ lib_nnz (L13 nnz, any, all)
SEA['lib_nnz'] = '''let m = [true, false, true, true]
let n = nnz(m)
let y = any(m)
let z = all(m)
printf("%d %d %d\\n", n, y, z)
// lib_nnz -- DESIGN.md 3.5.9 L13: nnz (wbin add of a bool, R7), any and all of a fixed-size
// bool vector, each accumulator taking the register of its local (R12 (b))
'''
AST['lib_nnz'] = '''
pname 0:1:5 m
true 0:1:10
false 0:1:16
true 0:1:23
true 0:1:29
row 0:1:10 4
array 0:1:9 1
let 0:1:1 0
pname 0:2:5 n
name 0:2:9 nnz
name 0:2:13 m
call 0:2:9 1
let 0:2:1 0
pname 0:3:5 y
name 0:3:9 any
name 0:3:13 m
call 0:3:9 1
let 0:3:1 0
pname 0:4:5 z
name 0:4:9 all
name 0:4:13 m
call 0:4:9 1
let 0:4:1 0
name 0:5:1 printf
str 0:5:8 %25d%20%25d%20%25d%0A
name 0:5:22 n
name 0:5:25 y
name 0:5:28 z
call 0:5:1 4
cstmt 0:5:1
prog 5
'''
# sea.hir1: bool[4] 10 (loc m); nnz is i64, any and all bool (%d prints a bool as 0 or 1).
HIR1['lib_nnz'] = '''
tfvec 10 2 4
fn 1 .main main 1 0 4 0:1:1
loc m 10 let 0:1:5
loc n 3 let 0:2:5
loc y 2 let 0:3:5
loc z 2 let 0:4:5
cb 0:1:10 2 1
cb 0:1:16 2 0
cb 0:1:23 2 1
cb 0:1:29 2 1
row 0:1:10 10 4
arr 0:1:9 10 1
bind 0:1:1 1
lv 0:2:13 10 1
lib 0:2:9 3 nnz 1
bind 0:2:1 2
lv 0:3:13 10 1
lib 0:3:9 2 any 1
bind 0:3:1 3
lv 0:4:13 10 1
lib 0:4:9 2 all 1
bind 0:4:1 4
lv 0:5:22 3 2
fconv 0:5:8 1 - - - d
ftext 0:5:8 1 %20
lv 0:5:25 2 3
fconv 0:5:8 1 - - - d
ftext 0:5:8 1 %20
lv 0:5:28 2 4
fconv 0:5:8 1 - - - d
ftext 0:5:8 1 %0A
fmt 0:5:8 1 6
lib 0:5:1 1 printf 1
eval 0:5:1
block 0:1:1 5
end
'''


def hirl_lib_nnz():
    """sea.hirl: tptr 11 2 (the literal's home). Line 1 L9 (a) of bool elements (scale 1); lines
    2-4 L13 nnz, any, all."""
    F = Fn()
    eds = [('''
cb 0:1:10 2 1
cb 0:1:16 2 0
cb 0:1:23 2 1
cb 0:1:29 2 1
row 0:1:10 10 4
arr 0:1:9 10 1
''', cat(L9a(F, '0:1:9', 10, 2, 11, 'l', [((0, 0), cb('0:1:10', 1)), ((0, 1), cb('0:1:16', 0)),
                                          ((0, 2), cb('0:1:23', 1)), ((0, 3), cb('0:1:29', 1))],
             1)))]
    for ln, nm, ty, pre in ((2, 'nnz', 3, 'n'), (3, 'any', 2, 'y'), (4, 'all', 2, 'z')):
        P = '0:%d:9' % ln
        a = 'lv 0:%d:13 10 1' % ln
        eds.append(([a, 'lib %s %d %s 1' % (P, ty, nm)],
                    cat(boolred(F, P, pre, nm, 11, lv('0:%d:13' % ln, 10, 1)))))
    return make_hirl(HIR1['lib_nnz'], ['tptr 11 2'], {1: (F, eds)})


HIRL['lib_nnz'] = hirl_lib_nnz
# sea.lir1. Line 1: m's slot s1 and the literal's home s2 (bool[4]: 4 bytes, slots of 8, 4.8's
# layout rule and rule 27 (a)), each element `li` then `stb V H - 0 k` (scale 1), the copy of 4
# bytes. Lines 2-4, rule 23: nnz `li R 0` (n's register, R12 (b)), data (none), n `li 4`, loop with
# `ldb b m K 1 0`, `iadd R R b`; any `li R 0`, `ior R R b`; all `li R 1`, `iand R R b`. Line 5:
# printf (s3, three words).
LIR1['lib_nnz'] = J(
    'func .main main 0:1:1 0 0', 'slot s1 8 8', 'slot s2 8 8', 'slot s3 24 8',
    lfixlit('l', 'p.m', 1, 2, [('b', 1, 0), ('b', 0, 1), ('b', 1, 2), ('b', 1, 3)], 4),
    'li i.n 0', 'li i.nN 4',
    lloop('n', 'i.nN', 1, 'i.nK', ['ldb i.nB p.m i.nK 1 0', 'iadd i.n i.n i.nB']),
    'li i.y 0', 'li i.yN 4',
    lloop('y', 'i.yN', 3, 'i.yK', ['ldb i.yB p.m i.yK 1 0', 'ior i.y i.y i.yB']),
    'li i.z 1', 'li i.zN 4',
    lloop('z', 'i.zN', 5, 'i.zK', ['ldb i.zB p.m i.zK 1 0', 'iand i.z i.z i.zB']),
    'sa p.S s3', 'sti i.n p.S - 0 0', 'sti i.y p.S - 0 8', 'sti i.z p.S - 0 16', 'la p.F d1',
    'rcall sea_printf 0:5 0 2 p.F p.S',
    'ret 0', 'endfunc',
    fmt_rec(1, ['fconv - - - d i', 'ftext %20', 'fconv - - - d i', 'ftext %20',
                'fconv - - - d i', 'ftext %0A']))
# [true, false, true, true]: nnz 3, any true (1), all false (0).
OUT['lib_nnz'] = '3 1 0\n'
NAMES.append('lib_nnz')

# ================================================================ lib_sum_dim0 (L13 sum.dim, dim 0)
SEA['lib_sum_dim0'] = '''fn colsum(A: f64[,]) -> f64 {
    let s = sum(A, dim: 0)
    return s[0]
}
printf("%g\\n", colsum(ones(2, 3)))
printf("%g\\n", colsum(zeros(3, 1)))
// lib_sum_dim0 -- DESIGN.md 3.5.9 L13, the dim: forms: sum.dim with dim 0 of a dynamic matrix
// (the extents and data loaded once before the outer loop over the columns, one sum8 home slot
// for every column, the element at I + J * rows)
'''
AST['lib_sum_dim0'] = '''
type 0:1:14 f64 m 0
param 0:1:11 A 0 0
type 0:1:25 f64 s 0
pname 0:2:9 s
name 0:2:13 sum
name 0:2:17 A
int 0:2:25 0
narg 0:2:20 dim
call 0:2:13 2
let 0:2:5 0
name 0:3:12 s
int 0:3:14 0
index 0:3:12 1
return 0:3:5 1
block 0:1:29 2
fn 0:1:1 colsum 0 1 1
name 0:5:1 printf
str 0:5:8 %25g%0A
name 0:5:16 colsum
name 0:5:23 ones
int 0:5:28 2
int 0:5:31 3
call 0:5:23 2
call 0:5:16 1
call 0:5:1 2
cstmt 0:5:1
name 0:6:1 printf
str 0:6:8 %25g%0A
name 0:6:16 colsum
name 0:6:23 zeros
int 0:6:29 3
int 0:6:32 1
call 0:6:23 2
call 0:6:16 1
call 0:6:1 2
cstmt 0:6:1
prog 3
'''
# sea.hir1: f64[,] 10 (the ones of .main), f64[] 11 (loc s of colsum: the dim: form of a dynamic
# matrix is a dynamic vector). `sum(A, dim: 0)` is `lib sum.dim` with A and the `ci` 0 at the
# position of the dim: value (0:2:25); no narg survives.
HIR1['lib_sum_dim0'] = '''
tmat 10 4
tvec 11 4
fn 1 .main main 1 0 0 0:1:1
ci 0:5:28 3 2
ci 0:5:31 3 3
lib 0:5:23 10 ones 2
call 0:5:16 4 2 1
fconv 0:5:8 1 - - - g
ftext 0:5:8 1 %0A
fmt 0:5:8 1 2
lib 0:5:1 1 printf 1
eval 0:5:1
ci 0:6:29 3 3
ci 0:6:32 3 1
lib 0:6:23 10 zeros 2
call 0:6:16 4 2 1
fconv 0:6:8 1 - - - g
ftext 0:6:8 1 %0A
fmt 0:6:8 1 2
lib 0:6:1 1 printf 1
eval 0:6:1
block 0:1:1 2
end
fn 2 colsum fn 4 1 1 0:1:1
par A 10 val
loc s 11 let 0:2:9
lv 0:2:17 10 1
ci 0:2:25 3 0
lib 0:2:13 11 sum.dim 2
bind 0:2:5 2
lv 0:3:12 11 2
ci 0:3:14 3 0
idx 0:3:12 4 1
ret 0:3:5 1
block 0:1:29 2
end
'''


def sum_dim(F, P, pre, d, a, T, TP, F8, fixed):
    """L13's dim: form of `sum` (f64): `xblk P T n` with `tmp Am = a`, `tmp Rr = ext(Am, 0)`, `tmp
    Cc = ext(Am, 1)`, `tmp RES = anew P T 0 1 (lv Cc)` (d = 0) or `(lv Rr)` (d = 1) (fixed-size T:
    `anew P T 0 0`, R1), `tmp DR = data(RES)`, `tmp D = data(Am)`; d = 0: loop(Cc; J) { `tmp Y = `
    the vector rule (sum's xblk without tmp V, tmp N, tmp D: `xblk P f64 1 { tmp Z }` with sum8's
    ifx over n = Rr, induction I, element `lin(I, J, Rr)`); `est P 8 0 (lv Y) (lv DR) (lv J)` };
    d = 1: loop(Rr; I) { the same with n = Cc, induction J (the lane wbin and (lv J) (lv Q)),
    element `lin(I, J, Rr)`, stored at I }; value `lv RES`."""
    x = Ctx(F, P, pre)
    st = [x.tmp('Am', a), x.tmp('Rr', ext(P, 0, x.lvl('Am'))), x.tmp('Cc', ext(P, 1, x.lvl('Am')))]
    if fixed:
        st.append(x.tmp('RES', anew(P, T, 0, [])))
    else:
        st.append(x.tmp('RES', anew(P, T, 0, [x.lvl('Cc' if d == 0 else 'Rr')])))
    st += [x.tmp('DR', adat(P, TP, x.lvl('RES'))), x.tmp('D', adat(P, TP, x.lvl('Am')))]
    outer = 'J' if d == 0 else 'I'

    def X(s, k, dd):
        if d == 0:
            idx = x.lin(k, x.klv(outer), x.lvl('Rr'))
        else:
            idx = x.lin(x.klv(outer), k, x.lvl('Rr'))
        return [s.tmp('Y', eld(P, 4, dd, idx))], s.lvl('Y')

    def body():
        z, val = sum8(F, P, pre + 'q', x.lvl('Rr' if d == 0 else 'Cc'), TP, F8, X, dD=x.lvl('D'))
        return [x.tmp('Y', xblk(P, [z], val)),
                est(P, 4, x.lvl('Y'), x.lvl('DR'), x.klv(outer))]
    st += x.loop('Cc' if d == 0 else 'Rr', 'Zo', 'Oo', 'Lo', outer, body)
    return xblk(P, st, x.lvl('RES'))


def hirl_lib_sum_dim0():
    """sea.hirl: tptr 12 4 (the adat of ones(2, 3) in .main), F8 = tfvec 13 4 8 (the sum8 home in
    colsum). .main: ones(2, 3) L2 (a matrix), zeros(3, 1) L1. colsum: line 2 L13 sum.dim, d = 0."""
    F1, F2 = Fn(), Fn()
    m = [(['ci 0:5:28 3 2', 'ci 0:5:31 3 3', 'lib 0:5:23 10 ones 2'],
          cat(L2(F1, '0:5:23', 10, 4, 12, 'o', r=ci('0:5:28', 2), c=ci('0:5:31', 3)))),
         (['ci 0:6:29 3 3', 'ci 0:6:32 3 1', 'lib 0:6:23 10 zeros 2'],
          cat(L1('0:6:23', 10, [ci('0:6:29', 3), ci('0:6:32', 1)])))]
    t = (['lv 0:2:17 10 1', 'ci 0:2:25 3 0', 'lib 0:2:13 11 sum.dim 2'],
         cat(sum_dim(F2, '0:2:13', 's', 0, lv('0:2:17', 10, 1), 11, 12, 13, False)))
    return make_hirl(HIR1['lib_sum_dim0'], ['tptr 12 4', 'tfvec 13 4 8'], {1: (F1, m), 2: (F2, [t])})


HIRL['lib_sum_dim0'] = hirl_lib_sum_dim0
# sea.lir1. .main: ones(2, 3) (rule 17: the two extents, arrnew of rank 2 with no `li C 1`, `imul N
# R C`, `lf V`, data, the fill loop), the call, its release, printf (s1); zeros(3, 1) (arrnewz of
# rank 2), the same (s2). colsum: line 2, rule 23's name.dim with dim 0: Am is A (p1), r `ldi -
# 0 16`, c `ldi - 0 24`, arrnew of a vector of c into s (T3: RES is s), data of the result and of A
# (each once, before the outer loop), loop(c; J) (blocks 1, 2) around sum8 over I in 0 ... r - 1
# (blocks 3, 4; slot s1 reused by every column: its sa runs in each iteration), the element at I +
# J * r computed in the innermost body (`imul`, `iadd`, the ldf), the column's sum (a new register:
# the tmp Y of the vector rule) stored at J; line 3 s[0] (rule 18), s released, `ret 1`.
LIR1['lib_sum_dim0'] = J(
    'func .main main 0:1:1 0 0', 'slot s1 8 8', 'slot s2 8 8',
    'li i.oR 2', 'li i.oC 3', 'li i.oek 1', 'li i.ork 2',
    'rcall sea_arr_new_u 0:5 1 p.oA 4 i.oek i.ork i.oR i.oC',
    'imul i.oN i.oR i.oC', 'lf f.oV #3FF0000000000000', 'ldp p.oD p.oA - 0 40',
    lloop('o', 'i.oN', 1, 'i.oK', ['stf f.oV p.oD i.oK 8 0']),
    'call colsum 1 f.r1 1 p.oA', 'release p.oA',
    lprintf1('a', 'f', 'f.r1', 1, 1, '0:5'),
    'li i.zR 3', 'li i.zC 1', 'li i.zek 1', 'li i.zrk 2',
    'rcall sea_arr_new 0:6 1 p.zA 4 i.zek i.zrk i.zR i.zC',
    'call colsum 1 f.r2 1 p.zA', 'release p.zA',
    lprintf1('b', 'f', 'f.r2', 2, 2, '0:6'),
    'ret 0', 'endfunc',
    'func colsum fn 0:1:1 1 p.A 1 f', 'slot s1 64 8',
    'ldi i.Rr p.A - 0 16', 'ldi i.Cc p.A - 0 24',
    'li i.ek 1', 'li i.rk 1', 'li i.c1 1',
    'rcall sea_arr_new_u 0:2 1 p.s 4 i.ek i.rk i.Cc i.c1',
    'ldp p.DR p.s - 0 40', 'ldp p.D p.A - 0 40',
    lloop('o', 'i.Cc', 1, 'i.J', lsum8(
        'q', 'i.Rr', 1, 3, [],
        lambda K: (['imul i.qt i.J i.Rr', 'iadd i.qu %s i.qt' % K, 'ldf f.qY p.D i.qu 8 0'],
                   'f.qY'), 'f.Y') + ['stf f.Y p.DR i.J 8 0']),
    'li i.k 0', 'ldi i.e p.s - 0 16', 'chkb i.k i.e 0 0:3', 'ldp p.d p.s - 0 40',
    'ldf f.r p.d i.k 8 0',
    'release p.s', 'ret 1 f.r', 'endfunc',
    fmt_rec(1, ['fconv - - - g f', 'ftext %0A']),
    fmt_rec(2, ['fconv - - - g f', 'ftext %0A']))
# ones(2, 3): each column's lanes a0 = a1 = 1, the rest -0: (1 + 1) + (-0 + -0) = 2, ... -> 2;
# s[0] = 2. zeros(3, 1): one column of three +0 lanes and five -0: +0. s[0] = 0.
OUT['lib_sum_dim0'] = '2\n0\n'
NAMES.append('lib_sum_dim0')

# ================================================================ lib_sum_dim1 (L13 sum.dim, dim 1, fixed)
SEA['lib_sum_dim1'] = '''fn rowsum(A: f64[2,3], k: i64) -> f64 {
    let s = sum(A, dim: 1)
    return s[k]
}
let M = [1.0, 2.0, 3.0; 4.0, 5.0, 6.0]
printf("%g\\n", rowsum(M, 0))
printf("%g\\n", rowsum(M, 1))
// lib_sum_dim1 -- DESIGN.md 3.5.9 L13, the dim: forms: sum.dim with dim 1 of a fixed-size
// f64[2,3], whose result is the fixed-size f64[2] (Decision 39: a home slot, copied into the
// home of s), the lane wbin and of J
'''
AST['lib_sum_dim1'] = '''
int 0:1:18 2
int 0:1:20 3
type 0:1:14 f64 fm 2
param 0:1:11 A 0 0
type 0:1:27 i64 s 0
param 0:1:24 k 0 0
type 0:1:35 f64 s 0
pname 0:2:9 s
name 0:2:13 sum
name 0:2:17 A
int 0:2:25 1
narg 0:2:20 dim
call 0:2:13 2
let 0:2:5 0
name 0:3:12 s
name 0:3:14 k
index 0:3:12 1
return 0:3:5 1
block 0:1:39 2
fn 0:1:1 rowsum 0 2 1
pname 0:5:5 M
float 0:5:10 #3FF0000000000000
float 0:5:15 #4000000000000000
float 0:5:20 #4008000000000000
row 0:5:10 3
float 0:5:25 #4010000000000000
float 0:5:30 #4014000000000000
float 0:5:35 #4018000000000000
row 0:5:25 3
array 0:5:9 2
let 0:5:1 0
name 0:6:1 printf
str 0:6:8 %25g%0A
name 0:6:16 rowsum
name 0:6:23 M
int 0:6:26 0
call 0:6:16 2
call 0:6:1 2
cstmt 0:6:1
name 0:7:1 printf
str 0:7:8 %25g%0A
name 0:7:16 rowsum
name 0:7:23 M
int 0:7:26 1
call 0:7:16 2
call 0:7:1 2
cstmt 0:7:1
prog 4
'''
# sea.hir1: f64[2,3] 10 (loc M), f64[3] 11 (each row of the literal), f64[2] 12 (loc s of rowsum:
# the dim: 1 form of a fixed-size T[r,c] is the fixed-size vector of r elements, Decision 39). M is
# passed by address as it is (the parameter's type).
HIR1['lib_sum_dim1'] = '''
tfmat 10 4 2 3
tfvec 11 4 3
tfvec 12 4 2
fn 1 .main main 1 0 1 0:1:1
loc M 10 let 0:5:5
cf 0:5:10 4 #3FF0000000000000
cf 0:5:15 4 #4000000000000000
cf 0:5:20 4 #4008000000000000
row 0:5:10 11 3
cf 0:5:25 4 #4010000000000000
cf 0:5:30 4 #4014000000000000
cf 0:5:35 4 #4018000000000000
row 0:5:25 11 3
arr 0:5:9 10 2
bind 0:5:1 1
lv 0:6:23 10 1
ci 0:6:26 3 0
call 0:6:16 4 2 2
fconv 0:6:8 1 - - - g
ftext 0:6:8 1 %0A
fmt 0:6:8 1 2
lib 0:6:1 1 printf 1
eval 0:6:1
lv 0:7:23 10 1
ci 0:7:26 3 1
call 0:7:16 4 2 2
fconv 0:7:8 1 - - - g
ftext 0:7:8 1 %0A
fmt 0:7:8 1 2
lib 0:7:1 1 printf 1
eval 0:7:1
block 0:1:1 3
end
fn 2 rowsum fn 4 2 1 0:1:1
par A 10 val
par k 3 val
loc s 12 let 0:2:9
lv 0:2:17 10 1
ci 0:2:25 3 1
lib 0:2:13 12 sum.dim 2
bind 0:2:5 3
lv 0:3:12 12 3
lv 0:3:14 3 2
idx 0:3:12 4 1
ret 0:3:5 1
block 0:1:39 2
end
'''


# M's elements in source order: ((i, j), position, bits); element (i, j) at k = i + 2j.
DIM1_ELS = [((0, 0), '0:5:10', '#3FF0000000000000'), ((0, 1), '0:5:15', '#4000000000000000'),
            ((0, 2), '0:5:20', '#4008000000000000'), ((1, 0), '0:5:25', '#4010000000000000'),
            ((1, 1), '0:5:30', '#4014000000000000'), ((1, 2), '0:5:35', '#4018000000000000')]


def hirl_lib_sum_dim1():
    """sea.hirl: tptr 13 4 (the adat of M's literal in .main), F8 = tfvec 14 4 8 (the sum8 home in
    rowsum). .main: line 5 L9 (a) of a 2 x 3 matrix (element (i, j) at k = i + 2j). rowsum: line 2
    L13 sum.dim, d = 1, of a fixed-size matrix: the extents are static, RES a home (anew P 12 0 0,
    R1), its data and A's data the home addresses (R2)."""
    F1, F2 = Fn(), Fn()
    els = DIM1_ELS
    m = [('''
cf 0:5:10 4 #3FF0000000000000
cf 0:5:15 4 #4000000000000000
cf 0:5:20 4 #4008000000000000
row 0:5:10 11 3
cf 0:5:25 4 #4010000000000000
cf 0:5:30 4 #4014000000000000
cf 0:5:35 4 #4018000000000000
row 0:5:25 11 3
arr 0:5:9 10 2
''', cat(L9a(F1, '0:5:9', 10, 4, 13, 'l', [(ij, cf(p, b)) for ij, p, b in els], 2)))]
    t = (['lv 0:2:17 10 1', 'ci 0:2:25 3 1', 'lib 0:2:13 12 sum.dim 2'],
         cat(sum_dim(F2, '0:2:13', 's', 1, lv('0:2:17', 10, 1), 12, 13, 14, True)))
    return make_hirl(HIR1['lib_sum_dim1'], ['tptr 13 4', 'tfvec 14 4 8'],
                     {1: (F1, m), 2: (F2, [t])})


HIRL['lib_sum_dim1'] = hirl_lib_sum_dim1
# sea.lir1. .main: M's slot s1 (48 bytes), the literal's home s2 with the six elements at (i + 2j)
# * 8 in source order (0, 16, 32, 8, 24, 40), the copy; each call passes M's home address (rule 27
# (h)) and `li` of k; printf (s3, s4). rowsum: line 2: the bind of the fixed-size local s (rule 27
# (b)): `sa` of s's slot s1 first, then the value: r and c `li 2`, `li 3` (static extents), the
# result's home s2 (R1: `sa`), its data and A's the home addresses (no instruction), loop(r; I)
# (blocks 1, 2) around sum8 over J in 0 ... c - 1 (blocks 3, 4; slot s3; the lane `iand W J Q`),
# the element at I + J * r (`imul t J r`, `iadd u I t`, `ldf y A u 8 0`), the row's sum stored at
# I (`stf Y RES I 8 0`); then the copy into s (`li 16`, mcopy; rule 27 (c), R9); line 3 s[k]
# (rule 18 on a fixed-size base: `li 2`, chkb, the home as data), `ret 1` (nothing to release).
LIR1['lib_sum_dim1'] = J(
    'func .main main 0:1:1 0 0', 'slot s1 48 8', 'slot s2 48 8', 'slot s3 8 8', 'slot s4 8 8',
    lfixlit('l', 'p.M', 1, 2, [('f', b, 8 * (i + 2 * j)) for (i, j), _, b in DIM1_ELS], 48),
    'li i.k1 0', 'call rowsum 1 f.r1 2 p.M i.k1',
    lprintf1('a', 'f', 'f.r1', 3, 1, '0:6'),
    'li i.k2 1', 'call rowsum 1 f.r2 2 p.M i.k2',
    lprintf1('b', 'f', 'f.r2', 4, 2, '0:7'),
    'ret 0', 'endfunc',
    'func rowsum fn 0:1:1 2 p.A i.k 1 f', 'slot s1 16 8', 'slot s2 16 8', 'slot s3 64 8',
    'sa p.s s1',
    'li i.Rr 2', 'li i.Cc 3', 'sa p.RES s2',
    lloop('o', 'i.Rr', 1, 'i.I', lsum8(
        'q', 'i.Cc', 3, 3, [],
        lambda K: (['imul i.qt %s i.Rr' % K, 'iadd i.qu i.I i.qt', 'ldf f.qY p.A i.qu 8 0'],
                   'f.qY'), 'f.Y') + ['stf f.Y p.RES i.I 8 0']),
    'li i.n 16', 'mcopy p.s p.RES i.n',
    'li i.e 2', 'chkb i.k i.e 0 0:3', 'ldf f.r p.s i.k 8 0',
    'ret 1 f.r', 'endfunc',
    fmt_rec(1, ['fconv - - - g f', 'ftext %0A']),
    fmt_rec(2, ['fconv - - - g f', 'ftext %0A']))
# Row 0 = [1, 2, 3]: lanes 1, 2, 3, the rest -0: ((1 + 2) + (3 + -0)) + ((-0 + -0) + (-0 + -0)) =
# 6; row 1 = [4, 5, 6]: 15.
OUT['lib_sum_dim1'] = '6\n15\n'
NAMES.append('lib_sum_dim1')

# ================================================================ lib_find (L14 find)
SEA['lib_find'] = '''let m = [false, true, true, false, true]
let f = find(m)
printf("%d %d\\n", len(f), f[2])
// lib_find -- DESIGN.md 3.5.9 L14: find of a fixed-size bool vector (the count, the new i64[]
// of that length, the indices stored in order); the result is dynamic (Decision 39)
'''
AST['lib_find'] = '''
pname 0:1:5 m
false 0:1:10
true 0:1:17
true 0:1:23
false 0:1:29
true 0:1:36
row 0:1:10 5
array 0:1:9 1
let 0:1:1 0
pname 0:2:5 f
name 0:2:9 find
name 0:2:14 m
call 0:2:9 1
let 0:2:1 0
name 0:3:1 printf
str 0:3:8 %25d%20%25d%0A
name 0:3:19 len
name 0:3:23 f
call 0:3:19 1
name 0:3:27 f
int 0:3:29 2
index 0:3:27 1
call 0:3:1 3
cstmt 0:3:1
prog 3
'''
# sea.hir1: bool[5] 10 (loc m), i64[] 11 (loc f: find always returns a dynamic i64[]).
HIR1['lib_find'] = '''
tfvec 10 2 5
tvec 11 3
fn 1 .main main 1 0 2 0:1:1
loc m 10 let 0:1:5
loc f 11 let 0:2:5
cb 0:1:10 2 0
cb 0:1:17 2 1
cb 0:1:23 2 1
cb 0:1:29 2 0
cb 0:1:36 2 1
row 0:1:10 10 5
arr 0:1:9 10 1
bind 0:1:1 1
lv 0:2:14 10 1
lib 0:2:9 11 find 1
bind 0:2:1 2
lv 0:3:23 11 2
lib 0:3:19 3 len 1
fconv 0:3:8 1 - - - d
ftext 0:3:8 1 %20
lv 0:3:27 11 2
ci 0:3:29 3 2
idx 0:3:27 3 1
fconv 0:3:8 1 - - - d
ftext 0:3:8 1 %0A
fmt 0:3:8 1 4
lib 0:3:1 1 printf 1
eval 0:3:1
block 0:1:1 3
end
'''


def hirl_lib_find():
    """sea.hirl: tptr 12 2 (the literal's home and m's data), tptr 13 3 (the data of find's result).
    Line 1 L9 (a); line 2 L14 find: `xblk P i64[] n` with `tmp M = lv m`, `tmp X = ext(M, 0)`, `bind
    C = ci 0`, `tmp DM = data(M)`, loop(X; K) { `asg set (lv C) (wbin add (lv C) (eld P bool 1 0 (lv
    DM) (lv K)))` }, `tmp RES = anew P i64[] 0 1 (lv C)`, `tmp DR = data(RES)`, `tmp DM2 = data(M)`,
    `bind O = ci 0`, `tmp One = ci 1`, loop(X; K2) { `tmp B = eld P bool 1 0 (lv DM2) (lv K2)`; `if
    (lv B)` { `est P 8 0 (lv K2) (lv DR) (lv O)`; O += `lv One` } }; value `lv RES`. Line 3: len L3."""
    F = Fn()
    eds = [('''
cb 0:1:10 2 0
cb 0:1:17 2 1
cb 0:1:23 2 1
cb 0:1:29 2 0
cb 0:1:36 2 1
row 0:1:10 10 5
arr 0:1:9 10 1
''', cat(L9a(F, '0:1:9', 10, 2, 12, 'l', [
        ((0, 0), cb('0:1:10', 0)), ((0, 1), cb('0:1:17', 1)), ((0, 2), cb('0:1:23', 1)),
        ((0, 3), cb('0:1:29', 0)), ((0, 4), cb('0:1:36', 1))], 1)))]
    P = '0:2:9'
    x = Ctx(F, P, 'f')
    st = [x.tmp('M', lv('0:2:14', 10, 1)), x.tmp('X', ext(P, 0, x.lvl('M'))),
          x.bindl('C', ci(P, 0)), x.tmp('DM', adat(P, 12, x.lvl('M')))]
    st += x.loop('X', 'Z1', 'O1', 'L1', 'K', lambda: [
        asg(P, 'set', x.lvl('C'), wbin(P, 'add', x.lvl('C'), eld(P, 2, x.lvl('DM'), x.klv('K'))))])
    st += [x.tmp('RES', anew(P, 11, 0, [x.lvl('C')])), x.tmp('DR', adat(P, 13, x.lvl('RES'))),
           x.tmp('DM2', adat(P, 12, x.lvl('M'))), x.bindl('O', ci(P, 0)), x.tmp('One', ci(P, 1))]
    st += x.loop('X', 'Z2', 'O2', 'L2', 'K2', lambda: [
        x.tmp('B', eld(P, 2, x.lvl('DM2'), x.klv('K2'))),
        if_(P, x.lvl('B'), block(P, [est(P, 3, x.klv('K2'), x.lvl('DR'), x.lvl('O')),
                                     x.plus_eq('O', x.lvl('One'))]))])
    eds.append((['lv 0:2:14 10 1', 'lib 0:2:9 11 find 1'], cat(xblk(P, st, x.lvl('RES')))))
    eds.append((['lv 0:3:23 11 2', 'lib 0:3:19 3 len 1'], cat(L3('0:3:19', 0, lv('0:3:23', 11, 2)))))
    return make_hirl(HIR1['lib_find'], ['tptr 12 2', 'tptr 13 3'], {1: (F, eds)})


HIRL['lib_find'] = hirl_lib_find
# sea.lir1. Line 1: m's slot s1 and the literal's home s2 (5 bytes: slots of 8), five stb, the
# copy of 5 bytes. Line 2, rule 24's find: m (its home), n `li 5`, the count of rule 20 (3) (`li C
# 0`, loop(n; K) with `ldb`, `iadd C C b`; blocks 1, 2), arrnew of an i64 vector of C into f (T3),
# the data of the result (`ldp`) and of m (none: the home), `li O 0`, `li One 1`, loop(n; K) with
# `ldb b m K 1 0`, `if 5 b`, `sti K DR O 8 0`, `iadd O O One`, `endif 5` (blocks 3-5). Line 3:
# len(f) (ext), f[2] (rule 18), printf (s3); f released at the end of .main's block.
LIR1['lib_find'] = J(
    'func .main main 0:1:1 0 0', 'slot s1 8 8', 'slot s2 8 8', 'slot s3 16 8',
    lfixlit('l', 'p.m', 1, 2, [('b', 0, 0), ('b', 1, 1), ('b', 1, 2), ('b', 0, 3), ('b', 1, 4)], 5),
    'li i.X 5', 'li i.C 0',
    lloop('a', 'i.X', 1, 'i.K', ['ldb i.e p.m i.K 1 0', 'iadd i.C i.C i.e']),
    'li i.ek 2', 'li i.rk 1', 'li i.c1 1',
    'rcall sea_arr_new_u 0:2 1 p.f 4 i.ek i.rk i.C i.c1',
    'ldp p.DR p.f - 0 40', 'li i.O 0', 'li i.One 1',
    lloop('b', 'i.X', 3, 'i.K2', ['ldb i.B p.m i.K2 1 0', 'if 5 i.B', 'sti i.K2 p.DR i.O 8 0',
                                  'iadd i.O i.O i.One', 'endif 5']),
    'ldi i.le p.f - 0 16',
    'li i.k 2', 'ldi i.e3 p.f - 0 16', 'chkb i.k i.e3 0 0:3', 'ldp p.d3 p.f - 0 40',
    'ldi i.v p.d3 i.k 8 0',
    'sa p.S s3', 'sti i.le p.S - 0 0', 'sti i.v p.S - 0 8', 'la p.F d1',
    'rcall sea_printf 0:3 0 2 p.F p.S',
    'release p.f', 'ret 0', 'endfunc',
    fmt_rec(1, ['fconv - - - d i', 'ftext %20', 'fconv - - - d i', 'ftext %0A']))
# find([false, true, true, false, true]) = [1, 2, 4]: len 3, f[2] = 4.
OUT['lib_find'] = '3 4\n'
NAMES.append('lib_find')

# ================================================================ lib_find_first (L14 find_first, find_last)
SEA['lib_find_first'] = '''let m = [false, true, true, false]
let a = find_first(m)
let b = find_last(m)
printf("%d %d\\n", a, b)
// lib_find_first -- DESIGN.md 3.5.9 L14: find_first (the first true: where of a counter, R15)
// and find_last of a fixed-size bool vector
'''
AST['lib_find_first'] = '''
pname 0:1:5 m
false 0:1:10
true 0:1:17
true 0:1:23
false 0:1:29
row 0:1:10 4
array 0:1:9 1
let 0:1:1 0
pname 0:2:5 a
name 0:2:9 find_first
name 0:2:20 m
call 0:2:9 1
let 0:2:1 0
pname 0:3:5 b
name 0:3:9 find_last
name 0:3:19 m
call 0:3:9 1
let 0:3:1 0
name 0:4:1 printf
str 0:4:8 %25d%20%25d%0A
name 0:4:19 a
name 0:4:22 b
call 0:4:1 3
cstmt 0:4:1
prog 4
'''
HIR1['lib_find_first'] = '''
tfvec 10 2 4
fn 1 .main main 1 0 3 0:1:1
loc m 10 let 0:1:5
loc a 3 let 0:2:5
loc b 3 let 0:3:5
cb 0:1:10 2 0
cb 0:1:17 2 1
cb 0:1:23 2 1
cb 0:1:29 2 0
row 0:1:10 10 4
arr 0:1:9 10 1
bind 0:1:1 1
lv 0:2:20 10 1
lib 0:2:9 3 find_first 1
bind 0:2:1 2
lv 0:3:19 10 1
lib 0:3:9 3 find_last 1
bind 0:3:1 3
lv 0:4:19 3 2
fconv 0:4:8 1 - - - d
ftext 0:4:8 1 %20
lv 0:4:22 3 3
fconv 0:4:8 1 - - - d
ftext 0:4:8 1 %0A
fmt 0:4:8 1 4
lib 0:4:1 1 printf 1
eval 0:4:1
block 0:1:1 4
end
'''


def hirl_lib_find_first():
    """sea.hirl: tptr 11 2. Line 1 L9 (a); line 2 L14 find_first: `xblk P i64 n` with `tmp M = lv
    m`, `tmp X = ext(M, 0)`, `bind R = ci -1`, `tmp U = ci -1`, `tmp D = data(M)`, loop(X; K) { `tmp
    B = eld P bool 1 0 (lv D) (lv K)`; `tmp Uq = bin eq (lv R) (lv U)`; `tmp C = bin band (lv B) (lv
    Uq)`; `asg set (lv R) (lib where (lv C) (lv K) (lv R))` (R15) }; value `lv R`. Line 3 L14
    find_last: `tmp M`, `tmp X`, `bind R = ci -1`, `tmp D`, loop(X; K) { `tmp B`; `asg set (lv R)
    (lib where (lv B) (lv K) (lv R))` }; value `lv R`."""
    F = Fn()
    eds = [('''
cb 0:1:10 2 0
cb 0:1:17 2 1
cb 0:1:23 2 1
cb 0:1:29 2 0
row 0:1:10 10 4
arr 0:1:9 10 1
''', cat(L9a(F, '0:1:9', 10, 2, 11, 'l', [((0, 0), cb('0:1:10', 0)), ((0, 1), cb('0:1:17', 1)),
                                          ((0, 2), cb('0:1:23', 1)), ((0, 3), cb('0:1:29', 0))],
             1)))]
    P = '0:2:9'
    x = Ctx(F, P, 'a')
    st = [x.tmp('M', lv('0:2:20', 10, 1)), x.tmp('X', ext(P, 0, x.lvl('M'))),
          x.bindl('R', ci(P, -1)), x.tmp('U', ci(P, -1)), x.tmp('D', adat(P, 11, x.lvl('M')))]
    st += x.loop('X', 'Zl', 'Ol', 'Ll', 'K', lambda: [
        x.tmp('B', eld(P, 2, x.lvl('D'), x.klv('K'))),
        x.tmp('Uq', bin_(P, 2, 'eq', x.lvl('R'), x.lvl('U'))),
        x.tmp('C', bin_(P, 2, 'band', x.lvl('B'), x.lvl('Uq'))),
        asg(P, 'set', x.lvl('R'), lib(P, 3, 'where', [x.lvl('C'), x.klv('K'), x.lvl('R')]))])
    eds.append((['lv 0:2:20 10 1', 'lib 0:2:9 3 find_first 1'], cat(xblk(P, st, x.lvl('R')))))
    P = '0:3:9'
    x = Ctx(F, P, 'b')
    st = [x.tmp('M', lv('0:3:19', 10, 1)), x.tmp('X', ext(P, 0, x.lvl('M'))),
          x.bindl('R', ci(P, -1)), x.tmp('D', adat(P, 11, x.lvl('M')))]
    st += x.loop('X', 'Zl', 'Ol', 'Ll', 'K', lambda: [
        x.tmp('B', eld(P, 2, x.lvl('D'), x.klv('K'))),
        asg(P, 'set', x.lvl('R'), lib(P, 3, 'where', [x.lvl('B'), x.klv('K'), x.lvl('R')]))])
    eds.append((['lv 0:3:19 10 1', 'lib 0:3:9 3 find_last 1'], cat(xblk(P, st, x.lvl('R')))))
    return make_hirl(HIR1['lib_find_first'], ['tptr 11 2'], {1: (F, eds)})


HIRL['lib_find_first'] = hirl_lib_find_first
# sea.lir1. Line 1: m (s1) and its literal (s2), four stb, the copy of 4 bytes. Line 2, rule 24's
# find_first: n `li 4`, `li R -1` into a (R12 (b)), `li U -1`, data (none), loop(n; K) with `ldb b
# m K 1 0`, `icmp eq u R U`, `iand c b u`, `isel R c K R` (blocks 1, 2). Line 3, find_last: n,
# `li R -1` into b, loop with `ldb`, `isel R b K R` (blocks 3, 4). Line 4: printf (s3).
LIR1['lib_find_first'] = J(
    'func .main main 0:1:1 0 0', 'slot s1 8 8', 'slot s2 8 8', 'slot s3 16 8',
    lfixlit('l', 'p.m', 1, 2, [('b', 0, 0), ('b', 1, 1), ('b', 1, 2), ('b', 0, 3)], 4),
    'li i.aX 4', 'li i.a -1', 'li i.aU -1',
    lloop('al', 'i.aX', 1, 'i.aK', ['ldb i.aB p.m i.aK 1 0', 'icmp eq i.aUq i.a i.aU',
                                    'iand i.aC i.aB i.aUq', 'isel i.a i.aC i.aK i.a']),
    'li i.bX 4', 'li i.b -1',
    lloop('bl', 'i.bX', 3, 'i.bK', ['ldb i.bB p.m i.bK 1 0', 'isel i.b i.bB i.bK i.b']),
    'sa p.S s3', 'sti i.a p.S - 0 0', 'sti i.b p.S - 0 8', 'la p.F d1',
    'rcall sea_printf 0:4 0 2 p.F p.S',
    'ret 0', 'endfunc',
    fmt_rec(1, ['fconv - - - d i', 'ftext %20', 'fconv - - - d i', 'ftext %0A']))
# [false, true, true, false]: the first true at 1, the last at 2.
OUT['lib_find_first'] = '1 2\n'
NAMES.append('lib_find_first')

# ================================================================ lib_sort_fixed (L14 sort, argsort; R16; Decision 39)
SEA['lib_sort_fixed'] = '''let f = [3.0, 0.5, 2.0]
let s = sort(f)
let d = s[0] < 1.0
let r = argsort(f, desc: d)
printf("%g %d\\n", s[2], r[0])
// lib_sort_fixed -- DESIGN.md 3.5.9 L14, R16, Decision 39: sort and argsort of a fixed-size
// vector (the dyn pass 2a writes at the call's position, rewritten by L10, released right after
// the rcall), desc: inserted as false and given as a run-time bool
'''
AST['lib_sort_fixed'] = '''
pname 0:1:5 f
float 0:1:10 #4008000000000000
float 0:1:15 #3FE0000000000000
float 0:1:20 #4000000000000000
row 0:1:10 3
array 0:1:9 1
let 0:1:1 0
pname 0:2:5 s
name 0:2:9 sort
name 0:2:14 f
call 0:2:9 1
let 0:2:1 0
pname 0:3:5 d
name 0:3:9 s
int 0:3:11 0
index 0:3:9 1
float 0:3:16 #3FF0000000000000
bin 0:3:9 lt
let 0:3:1 0
pname 0:4:5 r
name 0:4:9 argsort
name 0:4:17 f
name 0:4:26 d
narg 0:4:20 desc
call 0:4:9 2
let 0:4:1 0
name 0:5:1 printf
str 0:5:8 %25g%20%25d%0A
name 0:5:19 s
int 0:5:21 2
index 0:5:19 1
name 0:5:25 r
int 0:5:27 0
index 0:5:25 1
call 0:5:1 3
cstmt 0:5:1
prog 5
'''
# sea.hir1: f64[3] 10 (loc f and its row), f64[] 11 (loc s), i64[] 12 (loc r). sort(f): the
# fixed-size operand under a `dyn` to f64[] at the call's position (0:2:9, Decision 39, 3.5.5),
# then the inserted `cb 0` at the call's position; argsort(f, desc: d): the dyn, then `lv d` as
# written (the written order is the source order: no seq).
HIR1['lib_sort_fixed'] = '''
tfvec 10 4 3
tvec 11 4
tvec 12 3
fn 1 .main main 1 0 4 0:1:1
loc f 10 let 0:1:5
loc s 11 let 0:2:5
loc d 2 let 0:3:5
loc r 12 let 0:4:5
cf 0:1:10 4 #4008000000000000
cf 0:1:15 4 #3FE0000000000000
cf 0:1:20 4 #4000000000000000
row 0:1:10 10 3
arr 0:1:9 10 1
bind 0:1:1 1
lv 0:2:14 10 1
dyn 0:2:9 11
cb 0:2:9 2 0
lib 0:2:9 11 sort 2
bind 0:2:1 2
lv 0:3:9 11 2
ci 0:3:11 3 0
idx 0:3:9 4 1
cf 0:3:16 4 #3FF0000000000000
bin 0:3:9 2 lt
bind 0:3:1 3
lv 0:4:17 10 1
dyn 0:4:9 11
lv 0:4:26 2 3
lib 0:4:9 12 argsort 2
bind 0:4:1 4
lv 0:5:19 11 2
ci 0:5:21 3 2
idx 0:5:19 4 1
fconv 0:5:8 1 - - - g
ftext 0:5:8 1 %20
lv 0:5:25 12 4
ci 0:5:27 3 0
idx 0:5:25 3 1
fconv 0:5:8 1 - - - d
ftext 0:5:8 1 %0A
fmt 0:5:8 1 4
lib 0:5:1 1 printf 1
eval 0:5:1
block 0:1:1 5
end
'''


def hirl_lib_sort_fixed():
    """sea.hirl: tptr 13 4 (f's literal; the dyn copies' data). Line 1 L9 (a); lines 2 and 4: the
    dyn of each sort/argsort operand rewritten by L10 (P the dyn's position, the call's), the lib
    sort / lib argsort kept with that xblk and the desc child (R16); lines 3 and 5 unchanged."""
    F = Fn()
    eds = [('''
cf 0:1:10 4 #4008000000000000
cf 0:1:15 4 #3FE0000000000000
cf 0:1:20 4 #4000000000000000
row 0:1:10 10 3
arr 0:1:9 10 1
''', cat(L9a(F, '0:1:9', 10, 4, 13, 'l', [
        ((0, 0), cf('0:1:10', '#4008000000000000')), ((0, 1), cf('0:1:15', '#3FE0000000000000')),
        ((0, 2), cf('0:1:20', '#4000000000000000'))], 1))),
           (['lv 0:2:14 10 1', 'dyn 0:2:9 11'],
            cat(dyn_l10(F, '0:2:9', 'y', 11, 13, lv('0:2:14', 10, 1), 3, 24))),
           (['lv 0:4:17 10 1', 'dyn 0:4:9 11'],
            cat(dyn_l10(F, '0:4:9', 'z', 11, 13, lv('0:4:17', 10, 1), 3, 24)))]
    return make_hirl(HIR1['lib_sort_fixed'], ['tptr 13 4'], {1: (F, eds)})


HIRL['lib_sort_fixed'] = hirl_lib_sort_fixed
# sea.lir1. Line 1: f (s1) and its literal (s2). Line 2: the dyn (rule 27 (i): the static extent `li
# 3`, arrnew, data, `li 24`, mcopy from f's home), desc `li 0` (the inserted cb 0), `rcall sea_sort
# 0:2 1 s 2 A desc` into s (rule 24, rule 2), A released right after the rcall (R16, rule 15 (b)).
# Line 3: s[0] (rule 18), `lf 1.0`, `fcmp lt` into d. Line 4: the dyn, `rcall sea_argsort 0:4 1 r 2 A
# d` (d an lv: no instruction), A released. Line 5: s[2], r[0], printf (s3); at the end of the block
# r, then s released (rule 16 (a), reverse order of declaration; f and d hold no counts).
LIR1['lib_sort_fixed'] = J(
    'func .main main 0:1:1 0 0', 'slot s1 24 8', 'slot s2 24 8', 'slot s3 16 8',
    lfixlit('l', 'p.f', 1, 2, [('f', '#4008000000000000', 0), ('f', '#3FE0000000000000', 8),
                               ('f', '#4000000000000000', 16)], 24),
    'li i.yR 3', 'li i.yek 1', 'li i.yrk 1', 'li i.yc 1',
    'rcall sea_arr_new_u 0:2 1 p.yA 4 i.yek i.yrk i.yR i.yc',
    'ldp p.yD p.yA - 0 40', 'li i.yN 24', 'mcopy p.yD p.f i.yN',
    'li i.ds 0', 'rcall sea_sort 0:2 1 p.s 2 p.yA i.ds', 'release p.yA',
    'li i.k3 0', 'ldi i.e3 p.s - 0 16', 'chkb i.k3 i.e3 0 0:3', 'ldp p.d3 p.s - 0 40',
    'ldf f.x3 p.d3 i.k3 8 0', 'lf f.one #3FF0000000000000', 'fcmp lt i.d f.x3 f.one',
    'li i.zR 3', 'li i.zek 1', 'li i.zrk 1', 'li i.zc 1',
    'rcall sea_arr_new_u 0:4 1 p.zA 4 i.zek i.zrk i.zR i.zc',
    'ldp p.zD p.zA - 0 40', 'li i.zN 24', 'mcopy p.zD p.f i.zN',
    'rcall sea_argsort 0:4 1 p.r 2 p.zA i.d', 'release p.zA',
    'li i.k5 2', 'ldi i.e5 p.s - 0 16', 'chkb i.k5 i.e5 0 0:5', 'ldp p.d5 p.s - 0 40',
    'ldf f.x5 p.d5 i.k5 8 0',
    'li i.k6 0', 'ldi i.e6 p.r - 0 16', 'chkb i.k6 i.e6 0 0:5', 'ldp p.d6 p.r - 0 40',
    'ldi i.x6 p.d6 i.k6 8 0',
    'sa p.S s3', 'stf f.x5 p.S - 0 0', 'sti i.x6 p.S - 0 8', 'la p.F d1',
    'rcall sea_printf 0:5 0 2 p.F p.S',
    'release p.r', 'release p.s', 'ret 0', 'endfunc',
    fmt_rec(1, ['fconv - - - g f', 'ftext %20', 'fconv - - - d i', 'ftext %0A']))
# sort([3, 0.5, 2]) = [0.5, 2, 3]; d = 0.5 < 1.0 = true; argsort([3, 0.5, 2], desc: true) = [0, 2,
# 1] (3 > 2 > 0.5); s[2] = 3, r[0] = 0 (ascending it would be 1).
OUT['lib_sort_fixed'] = '3 0\n'
NAMES.append('lib_sort_fixed')


# ================================================================ the self-check (4f)
# check_hirl of dump4e_cases with the 4f items of 3.5.9 "What the passes validate": no lib of a
# reduction, find, find_first, find_last and no name.dim (R10); lib sort/argsort with exactly two
# children, a dynamic vector of f64, i64 or str and a type-2 desc, its type the vector's (sort) or
# i64[] (argsort) (R16); wbin and only of two type-3 operands (R13); an asg to a .l local with a
# wbin, bin or un value or a scalar lib where (R8, R15); at most one appended tfvec, of f64 with n 8,
# only when sea.hir's table has none, numbered with the tptr records by first reference (R14).
REWRITTEN_LIB4F = {'zeros', 'ones', 'filled', 'len', 'rows', 'cols', 'numel',       # L1-L3
                   'sum', 'mean', 'variance', 'std', 'max', 'min', 'argmax', 'argmin', 'nnz',
                   'any', 'all', 'find', 'find_first', 'find_last'}                 # L13, L14


def check_hirl4f(name):
    text = read(name + '.hirl')
    src = read(name + '.sea').split('\n')
    hir = read(name + '.hir')
    body = split_file(name, text, src)
    assert text.split('\n')[:3] == hir.split('\n')[:3], (name, 'header not copied (3.2)')
    hir_types = [ln for ln in hir.split('\n')[3:] if ln.split(' ')[0] in TYPE_RECS | {'fd'}]
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
        if op in ('tvec', 'tmat'):
            types[int(v['id'])] = ({'tvec': 'v', 'tmat': 'm'}[op], int(v['elt']))
        elif op == 'tfvec':
            types[int(v['id'])] = ('fv', int(v['elt']), int(v['n']))
        elif op == 'tfmat':
            types[int(v['id'])] = ('fm', int(v['elt']), int(v['r']), int(v['c']))
        elif op == 'ttuple':
            types[int(v['id'])] = ('t', [int(x) for x in v['t']])
        elif op == 'tptr':
            types[int(v['id'])] = ('ptr', int(v['elt']))
        if op != 'fd':
            assert int(v['id']) == last + 1, (name, 'type ids not consecutive', ln)
            last = int(v['id'])
    appended = table[ntab:]
    tptrs = [int(ln.split(' ')[1]) for ln in appended]
    f8 = [ln for ln in appended if not ln.startswith('tptr ')]
    assert len(f8) <= 1 and all(re.match(r'^tfvec \d+ 4 8$', ln) for ln in f8), (name, 'R14', f8)
    assert not (f8 and any(re.match(r'^tfvec \d+ 4 8$', ln) for ln in hir_types)), \
        (name, 'R14: F8 appended although sea.hir has an f64[8]')
    F8 = int(f8[0].split(' ')[1]) if f8 else None
    elts = [types[t][1] for t in tptrs if t != F8]
    assert len(set(elts)) == len(elts), (name, 'one tptr per element type')

    def rank(t):
        return {'v': 1, 'fv': 1, 'm': 2, 'fm': 2}.get(types[t][0], 0)

    def is_arr(t):
        return types[t][0] in ('v', 'm', 'fv', 'fm')

    def is_dyn(t):
        return types[t][0] in ('v', 'm')

    def is_scalar(t):
        return t in (2, 3, 4)

    first_ref = []
    stack, fn, out_fns = [], None, []
    hir_fns, cur = {}, None
    for ln in hir.split('\n')[3:]:
        if ln.startswith('fn '):
            cur = int(ln.split(' ')[1])
            hir_fns[cur] = []
        if cur is not None and ln and ln != '#end':
            hir_fns[cur].append(ln)
    hirl_fns, cur = {}, None
    for ln in rest:
        if ln.startswith('fn '):
            cur = int(ln.split(' ')[1])
            hirl_fns[cur] = []
        hirl_fns[cur].append(ln)
    for k, ln in enumerate(rest):
        op, v, pops = parse_rec(name, 'H HF HL'.split(), ln)
        assert op != 'fore', (name, 'fore in sea.hirl', ln)
        if op == 'lib':
            assert v['name'] not in REWRITTEN_LIB4F and not v['name'].endswith('.dim'), \
                (name, 'R10: a rewritten lib', ln)
        assert op not in ('view', 'arr', 'row', 'dyn', 'fix', 'all'), (name, 'R10', ln)
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
            fn = {'np': int(v['np']), 'nl': int(v['nl']), 'locs': [], 'nodes': [],
                  'fid': int(v['fid'])}
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
        for c in kids:
            c.parent = node
        fn['nodes'].append(node)
        if op == 'end':
            assert not stack and kids[0].op == 'block', (name, 'end', ln)
            fn['body'] = kids[0]
            continue
        stack.append(node)
    assert not stack, name
    assert first_ref == tptrs, (name, 'appended types not in order of first reference', first_ref,
                                tptrs)

    nchanged = 0
    for fn in out_fns:
        locs = fn['locs']
        assert len(locs) == fn['np'] + fn['nl'], (name, 'np/nl')
        lnames = [x[0] for x in locs]
        ls = [j for j, x in enumerate(lnames) if x.startswith('.l')]
        hl_ops = {o for (st_, o) in RECS if st_ == 'HL'}
        if not ls and not any(r.split(' ')[0] in hl_ops for r in hirl_fns[fn['fid']]):
            assert hirl_fns[fn['fid']] == hir_fns[fn['fid']], (name, 'unchanged function differs')
        else:
            nchanged += 1
        if ls:
            assert ls == list(range(ls[0], len(locs))), (name, '.l locals last (3.5.4)')
            assert [lnames[j] for j in ls] == ['.l%d' % (q + 1) for q in range(len(ls))], name
        lt = {j + 1: x[1] for j, x in enumerate(locs)}

        def ty_of(n):
            if n.op == 'lv':
                assert int(n.v['ty']) == lt[int(n.v['lid'])], (name, 'lv type', n.v)
            return int(n.v['ty']) if 'ty' in n.v and n.v['ty'] != '-' else None

        def isl(lid):
            return lnames[lid - 1].startswith('.l')

        tmp_bound, decl, assigned, rcnt_locals, bind_l = {}, [], {}, set(), set()
        for n in fn['nodes']:
            t = ty_of(n)
            kt = [ty_of(c) for c in n.kids]
            if n.op == 'tmp':
                L = int(n.v['lid'])
                assert L not in tmp_bound, (name, 'tmp bound twice', L)
                tmp_bound[L] = n.idx
                assert lt[L] == kt[0], (name, 'tmp type != child type', n.v)
                if types.get(lt[L], ('',))[0] == 'ptr':
                    assert n.kids[0].op in ('adat', 'cdat'), (name, 'tptr tmp', n.v)
                if isl(L):
                    decl.append((L, 'let', n.v['pos']))
            elif n.op == 'bind' and isl(int(n.v['lid'])):
                L = int(n.v['lid'])
                decl.append((L, 'let', n.v['pos']))
                bind_l.add(L)
                assert lt[L] == kt[0], (name, 'bind type', n.v)
                if is_arr(lt[L]):                     # R8: an array .l local only in a block
                    assert is_dyn(lt[L]), (name, 'R8: a fixed-size .l local bound by bind', n.v)
                    assert n.parent.op == 'block', (name, 'R8: array .l bind outside a block')
            elif n.op == 'tbind' and any(x != '-' and isl(int(x)) for x in n.v['lid']):
                assert n.parent.op == 'block' and n.parent.kids[0] is n, (name, 'R8 tbind', n.v)
                comps = types[kt[0]][1]
                for x, ct in zip(n.v['lid'], comps):
                    if x != '-':
                        assert isl(int(x)) and lt[int(x)] == ct, (name, 'tbind .l type', n.v)
                        decl.append((int(x), 'let', n.v['pos']))
            elif n.op == 'tasg':
                for c, cv in zip(n.kids[:-1], n.v['cv']):
                    assert int(cv) == 0 or (int(cv) == 1 and is_scalar(ty_of(c))), (name, 'R10 cv')
            elif n.op == 'rcnt':
                Ll, Le = int(n.v['l']), int(n.v['e'])
                assert lt[Ll] == 3 and lt[Le] == 2, (name, 'rcnt local types (R6)', n.v)
                assert kt == [3, 3, 3], (name, 'rcnt children')
                rcnt_locals |= {Ll, Le}
                decl.append((Ll, 'let', n.v['pos']))
                decl.append((Le, 'let', n.v['pos']))
            elif n.op == 'hloop':
                K = int(n.v['lid'])
                assert locs[K - 1][2] == 'for' and lt[K] == 3, (name, 'hloop local', n.v)
                assert kt[:3] == [3, 3, 3], (name, 'hloop range')
                assert n.kids[3].op == 'block', name
                decl.append((K, 'for', n.v['pos']))
            elif n.op == 'ext':
                a = kt[0]
                assert t == 3 and (is_arr(a) or a == 5), (name, 'ext', n.v)
                assert int(n.v['dim']) < max(rank(a), 1), (name, 'ext dim', n.v)
            elif n.op == 'adat':
                a = kt[0]
                assert is_arr(a) and types[t] == ('ptr', types[a][1]), (name, 'adat', n.v)
            elif n.op == 'eld':
                assert types[kt[0]] == ('ptr', t) and kt[1] == 3, (name, 'eld', n.v)
                assert int(n.v['sc']) == ES[t], (name, 'eld scale')
            elif n.op == 'est':
                assert types[kt[1]] == ('ptr', kt[0]), (name, 'est', n.v)
                assert kt[2] == 3 and int(n.v['sc']) == ES[kt[0]], (name, 'est index/scale')
            elif n.op == 'anew':
                if is_dyn(t):
                    assert rank(t) == int(n.v['r']) and all(x == 3 for x in kt), (name, 'anew')
                else:
                    assert is_arr(t) and n.v['r'] == '0' and n.v['z'] == '0', (name, 'anew R1')
            elif n.op == 'wbin':
                assert t == 3, (name, 'wbin type', n.v)
                if n.v['op'] == 'and':
                    assert kt == [3, 3], (name, 'R13: wbin and of two i64 operands', n.v)
                else:
                    assert all(x in (2, 3) for x in kt), (name, 'wbin (R7)', n.v)
            elif n.op == 'chkb':
                assert kt == [3, 3], (name, 'chkb')
            elif n.op == 'chk':
                assert kt[0] == 2 and n.v['err'] in ERRS, (name, 'chk', n.v)
                assert ERRS[n.v['err']] == int(n.v['n']), (name, 'chk slots', n.v)
            elif n.op == 'cow':
                c = n.kids[0]
                assert c.op == 'lv' and is_dyn(kt[0]) and not isl(int(c.v['lid'])), (name, 'cow')
            elif n.op == 'mcpy':
                assert types[kt[0]][0] == 'ptr' and types[kt[1]][0] == 'ptr' and kt[2] == 3, \
                    (name, 'mcpy')
            elif n.op == 'cdat':
                assert int(n.v['n']) >= 1 and types[t][0] == 'ptr', (name, 'cdat')
                for c in n.kids:
                    assert c.op in ('ci', 'cf', 'cb') and ty_of(c) == types[t][1], (name, 'cdat')
            elif n.op == 'xblk':
                assert t == kt[-1], (name, 'xblk type', n.v)
            elif n.op == 'idx':
                assert n.kids[0].op != 'view' and all(x == 3 for x in kt[1:]), (name, 'R10 idx')
            elif n.op in ('bin', 'un', 'cvt', 'powk', 'emap'):
                assert all(x is None or not is_arr(x) for x in kt), (name, 'R10 array op', n.v)
            elif n.op == 'lib':
                if n.v['name'] in ('sort', 'argsort'):          # R16
                    assert len(n.kids) == 2 and kt[1] == 2, (name, 'R16 children', n.v)
                    vt = kt[0]
                    assert types[vt][0] == 'v' and types[vt][1] in (3, 4, 5), (name, 'R16 vec')
                    if n.v['name'] == 'sort':
                        assert t == vt, (name, 'R16 sort type', n.v)
                    else:
                        assert types[t] == ('v', 3), (name, 'R16 argsort type', n.v)
                else:
                    assert all(x is None or not is_arr(x) for x in kt) or \
                        n.v['name'] in ('printf',), (name, 'R10 array lib', n.v)
            if n.op == 'asg':
                tg = n.kids[0]
                if n.v['op'] != 'set':
                    assert not is_arr(kt[0]), (name, 'R10 compound array asg')
                if tg.op == 'lv' and isl(int(tg.v['lid'])):
                    L = int(tg.v['lid'])
                    assert n.v['op'] == 'set' and is_scalar(lt[L]) and L in bind_l, \
                        (name, 'asg to a .l local (R8)', n.v)
                    vl = n.kids[1]
                    assert vl.op in ('wbin', 'bin', 'un') or \
                        (vl.op == 'lib' and vl.v['name'] == 'where' and is_scalar(kt[1])), \
                        (name, 'R8/R15: the value of an asg to a .l local', n.v)
            if n.op in ('bind', 'forr'):
                assigned.setdefault(int(n.v['lid']), []).append(n.op)
            elif n.op == 'tbind':
                for x in n.v['lid']:
                    if x != '-':
                        assigned.setdefault(int(x), []).append('tbind')
            elif n.op in ('asg', 'tasg', 'rarg'):
                for c in n.kids:
                    if c.op == 'lv':
                        assigned.setdefault(int(c.v['lid']), []).append(n.op)
                    if n.op != 'tasg':
                        break
        for n in fn['nodes']:
            if n.op == 'rng':
                assert n.parent.op == 'forr' and n.parent.kids[0] is n, (name, 'R10 rng')
            if n.op == 'lv' and int(n.v['lid']) in tmp_bound:
                assert tmp_bound[int(n.v['lid'])] < n.idx, (name, 'lv before its tmp', n.v)
            if n.op == 'ifx' and n.parent is not None and n.parent.op == 'xblk' and \
                    n.parent.kids[-1] is n:
                # R12 (a): only the xblks L13 writes have an ifx value (sum8's and variance's):
                # an f64 value whose condition compares an i64 extent with a constant tmp
                assert ty_of(n) == 4 and n.kids[0].op == 'bin' and \
                    n.kids[0].v['op'] in ('gt', 'eq'), (name, 'R12 (a)', n.v)
        assert not (set(assigned) & set(tmp_bound)), (name, 'a tmp local is assigned')
        for L in rcnt_locals:
            assert L not in assigned, (name, 'an rcnt local is written elsewhere', L)
        ldecl = [d for d in decl if isl(d[0])]
        assert [d[0] for d in ldecl] == [j + 1 for j in ls], (name, '.l order', ldecl, ls)
        for L, mut, pos in ldecl:
            assert locs[L - 1][2] == mut and locs[L - 1][3] == pos, (name, '.l loc', L, locs[L - 1])
    return len(body), nchanged


def cross_counts(name):
    """Counts the .hirl and the .lir1 must agree on (each record of 3.6.6 "Lowering of the sea.hirl
    records" writes one of these LIR instructions): hloop and loop; if (also the e = 1 form) plus
    ifx and if; anew of F8 and 64-byte slots; chk and chk; chkb and chkb; lib sort/argsort and
    rcall sea_sort/sea_argsort; mcpy and mcopy (plus the copies of fixed-size binds: one per bind of
    a fixed-size source local)."""
    hl = lines(read(name + '.hirl'))[3:-1]
    lr = lines(read(name + '.lir1'))[3:-1]
    ops = lambda recs, o: sum(1 for r in recs if r.split(' ')[0] == o)
    f8 = [r.split(' ')[1] for r in hl if re.match(r'^tfvec \d+ 4 8$', r)]
    n_f8 = sum(1 for r in hl if f8 and re.match(r'^anew \S+ %s 0 0$' % f8[0], r))
    assert ops(hl, 'hloop') == ops(lr, 'loop'), (name, 'hloop/loop')
    assert ops(hl, 'if') + ops(hl, 'ifx') == ops(lr, 'if') + ops(lr, 'ifz'), (name, 'if')
    assert n_f8 == sum(1 for r in lr if re.match(r'^slot s\d+ 64 8$', r)), (name, 'F8 homes')
    assert ops(hl, 'chk') == ops(lr, 'chk') and ops(hl, 'chkb') + ops(hl, 'idx') == \
        ops(lr, 'chkb'), (name, 'chk/chkb')
    nsort = sum(1 for r in hl if re.match(r'^lib \S+ \d+ (sort|argsort) 2$', r))
    assert nsort == sum(1 for r in lr if re.match(r'^rcall sea_(arg)?sort ', r)), (name, 'sort')
    for r in lr:
        if r.startswith('rcall sea_sort ') or r.startswith('rcall sea_argsort '):
            p = r.split(' ')
            # rt.inc: site S, one p result, arguments p (v) and i (desc)
            assert re.match(r'^0:\d+$', p[2]) and p[3] == '1' and p[4][0] == 'p' and \
                p[5] == '2' and p[6][0] == 'p' and p[7][0] == 'i' and len(p) == 8, (name, r)


# ================================================================ run
for nm in NAMES:
    write_test(nm)
nrec, nch = 0, 0
for nm in NAMES:
    a, b = check_hirl4f(nm)
    nrec += a
    nch += b
    nrec += check_lir1(nm)
    cross_counts(nm)
check_example(23, 'lib_rule23')
check_example(24, 'lib_rule24')
print('dump4f_cases: %d dump tests (%d functions rewritten), %d records checked; agreed examples '
      'verbatim: lib_rule23 lib_rule24' % (len(NAMES), nch, nrec))
