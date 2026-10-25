"""Sub-phase 5c-1 dump tests of pass 3b (DESIGN.md 6.2 "Phase-5 tests", `opt5_*` dumps; 3.6.5
"Pass 3b from phase 5"; 5.8 T1 (with the facts F1-F6), T2, T3, T4 and T10; lead decisions L-ak,
L-al, L-am, L-ao, L-ap, L-au, L-av, L-ba, L-bb).

Run with `timeout 120 uv run --no-project python tests/vectors/dump5_cases.py [--out DIR]
[--check-build BUILD]`. It writes, in tests/passes/ (or DIR):

* the 5c-1 share of 6.2's `opt5_*` list, each NAME.sea with NAME.lir1 and NAME.lir: the stage pair
  `seaopt lir1 lir` of tests/stage.sh checks NAME.lir, and tests/run.sh checks `--emit lir1` and
  `--emit lir` of NAME.sea (built with --no-prelude):
  opt5_bce_range    T1 with F2 and F3: the ind of a loop over 0..n, 9..=0 step -1 and 0..10
                    step 3 in an array of n (10) elements, a constant index (deleted); 0..=m
                    and a repeated check whose F4 candidate is not comparable (kept)
  opt5_bce_dom      T1 with F5: dominating comparisons of a symbol with constants (its L, U),
                    the negation in an else part, and a non-symbol index narrowed by two tests
  opt5_bce_sym      T1 with L-au: symbol-symbol comparisons through constant bounds: an extent
                    loaded outside every loop (a symbol, L = 8) against 0 <= k < 8 (deleted),
                    k < 8 alone against zeros(n) (kept), 0 <= k < 7 against n >= 8 from an if
                    (deleted inside it, kept after it)
  opt5_bce_passed   T1 with F4: a check that passed proves the same index against the same
                    array (deleted) and nothing for another array (kept)
  opt5_bce_kept     T1: checks no fact proves (i + 1 and i - 1 over 0..n, 0..=n, a `ref` array)
  opt5_bce_scope    T1 with F3 and F6: the facts of a guard and of a do loop, not used after them
  opt5_bce_eq       T1 with F5's eq and ne and their negations in an else part, a missing
                    else part and an ifz part
  opt5_ovf          T1: iaddc, isubc, inegc, imulc made wrapping, and those that stay
  opt5_ovf_const    T1 with L-bb 6: adds of constants at and beyond +-2^52
  opt5_div          T2: integer % and idiv by each kind of constant divisor (1, 2^k, the magic
                    sequence with M < 2^63 and with M >= 2^63, s = 0 and s > 0; negative, zero
                    and non-constant divisors unchanged)
  opt5_fdiv         T2: f64 division by normal powers of two (2^1023 included: the subnormal
                    reciprocal), and by values that are not (unchanged)
  opt5_vn           T3 rule 1 with copy propagation (a chain in one pass), and an equal
                    instruction whose earlier result is overwritten between (not shared)
  opt5_rle          T3 rule 2: header loads, a private location read back from its store and
                    across a call, an element load not shared across the call
  opt5_ifconv       T4: if/else of one mov per part (isel, fsel), if of one mov (fsel), ifz of
                    one mov (`||`, isel); parts that are not one mov stay
  opt5_clean        T10: unused pure values and loads, mov R R, an if left empty, a retain
                    immediately followed by its release
  opt5_dead         L-bb 3: records after exit and ret, up to the end of their part, unchanged
* the re-derived golden of 3.6.5 / L-ak that T1-T4 and T10 change: lir4_seaopt.lir (T3 shares
  three `li` constants, T10 deletes `retain p5` / `release p5`; the lir1 is unchanged). The other
  seaopt golden, lx.lir (3.6.7, phase 1), is one T1-T4 and T10 leave unchanged: the self-check
  proves it and the file is not written. gen_arith.lir and the other hand-written pass-4 inputs
  are not seaopt goldens in 5c-1 (gen_arith is re-derived in 5c-2, 3.6.5).

How each file is made (never by running seaopt; WP-OPT writes it concurrently):
* NAME.sea: written for the case (each function has a loop and two call sites, so LANGUAGE.md
  8.6 requires no inlining, 3.6.6).
* NAME.lir1: the input side, `sea build --emit lir1 --no-prelude NAME.sea` of the phase-4
  passes (sealower is not changed by 5c-1), embedded below; --check-build BUILD compares it with
  BUILD/sea's output.
* NAME.lir: from NAME.lir1 by the model below, which applies 5.8's rules T1, T2, T3, T4, T10 in
  that order (5c-1's seaopt has no T5-T9) to each function and renumbers it (3.6.1, 3.6.4).
  What each rule does on each case is derived by hand (the note above each case) and written
  in EVENTS: every check T1 deletes and every checked instruction it makes wrapping, every
  division T2 rewrites, every load T3 replaces, every if T4 converts and every mov R R, empty if
  and retain/release pair T10 deletes; the self-check requires the model to do exactly those.

Decisions on cases 5.8 had left open, now normative in DESIGN.md (L-au, L-av, L-ba, L-bb):
* (L-au) T1 compares two different symbols or pseudo-symbols through their constant bounds:
  s + k <= t + m holds when U(s) + k <= L(t) + m (deletion, narrowing, joins); F2 narrows L(E),
  U(E) of a symbol extent E by rows(A)'s constant bounds (opt5_bce_sym).
* (L-av) F4 changes neither a symbol's interval nor its L, U; T2 writes `li S s` also when s = 0
  (T10 deletes it); T3's rules 1 and 2 take the nearest earlier qualifying instruction; `isub r c
  b` with only the minuend constant makes r unknown; with two non-constant operands T1's overflow
  test uses the constant bounds L and U give; a join's comparisons use the joined L, U.
* (L-ba) a pseudo-symbol comes only from a dynamic-array parameter: a `chkb` on an extent loaded
  from its header and an indexed access through its data address.
* (L-bb) seaopt's readings (5.8, "Readings fixed during the build"), among them: an earlier
  instruction that writes its own operand, base or idx does not qualify for T3; records after an
  exit, next or ret up to the end of their part are not transformed (opt5_dead); a constant
  outside -2^52 ... 2^52 has an unknown interval (opt5_ovf_const). One choice of this model that
  no case depends on: the reads of such dead records still count as reads for T10.

The self-check reads every written file back: each record against include/passes.txt set L,
the numbering of registers, blocks, slots and labels (3.6.1-3.6.4), the header and data records
and slots equal between NAME.lir1 and NAME.lir, the events of each case against EVENTS, T2's two
magic numbers against 5.8's text, lx.lir unchanged by the model and lir4_seaopt.lir equal to its
hand derivation below.
"""

import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
PASSES = os.path.join(os.path.dirname(HERE), 'passes')
if '--out' in sys.argv:
    PASSES = os.path.abspath(sys.argv[sys.argv.index('--out') + 1])
CHECK_BUILD = None
if '--check-build' in sys.argv:
    CHECK_BUILD = os.path.abspath(sys.argv[sys.argv.index('--check-build') + 1])


def equiv(fname, name):
    """The value of `.equiv NAME, v` in include/FNAME (the contract files, never a copy)."""
    with open(os.path.join(ROOT, 'include', fname)) as fh:
        for ln in fh:
            m = re.match(r'^\.equiv\s+(\w+),\s*(-?[0-9]+)', ln)
            if m and m.group(1) == name:
                return int(m.group(2))
    raise AssertionError(('no .equiv', fname, name))


SEA_ARR_RC = equiv('rt.inc', 'SEA_ARR_RC')
SEA_ARR_ROWS = equiv('rt.inc', 'SEA_ARR_ROWS')
SEA_ARR_COLS = equiv('rt.inc', 'SEA_ARR_COLS')
SEA_ARR_DATA = equiv('rt.inc', 'SEA_ARR_DATA')
SEA_LIM_EXTENT = equiv('limits.inc', 'SEA_LIM_EXTENT')
I64_MIN, I64_MAX = -2 ** 63, 2 ** 63 - 1
FLIM = 2 ** 52          # every constant of a fact lies in -2^52 ... 2^52 (5.8 "Facts", 2.8)


def load_formats():
    recs = {}
    with open(os.path.join(ROOT, 'include', 'passes.txt')) as fh:
        for ln in fh:
            p = ln.split()
            if len(p) >= 5 and p[0] == 'rec' and p[1] == 'L':
                recs[p[3]] = p[5:]
    return recs


FMT = load_formats()


def layout(rec):
    """[(field name, kind, token index)] of a LIR record, the counted fields expanded."""
    out, vals, k = [], {}, 1
    for f in FMT[rec[0]]:
        nm, kind = f.split(':')
        if '*' in kind:
            kind, cnt = kind.split('*')
            for _ in range(int(vals[cnt])):
                out.append((nm, kind, k))
                k += 1
            continue
        out.append((nm, kind.rstrip('?'), k))
        vals[nm] = rec[k]
        k += 1
    assert k == len(rec), ('field count', rec)
    return out


REGK = ('ri', 'rf', 'rp', 'reg')
BLOCK = ('loop', 'endloop', 'do', 'enddo', 'if', 'ifz', 'else', 'endif')
CUT = BLOCK + ('exit', 'next', 'ret')
LOADS = {'ldi': 'i', 'ldf': 'f', 'ldb': 'b', 'ldp': 'p'}
STORES = {'sti': 'i', 'stf': 'f', 'stb': 'b', 'stp': 'p'}
# 5.8 Terms: pure = all but the loads, the failing instructions and the effects
PURE = set('li lf la sa mov iadd isub imul ineg iand ior ixor ishl ishr isar bnot icmp fcmp '
           'isel fsel psel fadd fsub fmul fdiv fneg fabs fsqrt fmin fmax ffloor fceil ftrunc '
           'fround imulh itof fnan padd'.split())
ARR_ENTRIES = ('sea_arr_new', 'sea_arr_new_u', 'sea_arr_new_s', 'sea_sort', 'sea_argsort',
               'sea_args')
NEW_ENTRIES = ('sea_arr_new', 'sea_arr_new_u', 'sea_arr_new_s')
NOWRITE = ('func', 'slot', 'endfunc', 'mcopy', 'exit', 'next', 'ret', 'chkb', 'chk', 'retain',
           'release') + BLOCK


def writes(rec):
    """The registers a record writes (a `loop` writes its ind)."""
    if rec[0] == 'loop':
        return [rec[2]]
    if rec[0] in NOWRITE or rec[0] in STORES:
        return []
    return [rec[k] for nm, kind, k in layout(rec) if kind in REGK and nm in ('d', 'e')]


def reads(rec):
    """The token indices of the registers a record reads (mcopy's d and a store's s are read)."""
    if rec[0] in ('func', 'slot', 'endfunc'):
        return []
    w = set()
    if rec[0] == 'loop':
        w = {2}
    elif rec[0] != 'mcopy' and rec[0] not in STORES:
        w = {k for nm, kind, k in layout(rec) if kind in REGK and nm in ('d', 'e')}
    return [k for nm, kind, k in layout(rec) if kind in REGK and k not in w and rec[k] != '-']


def fmt_i(v):
    """3.1 field kind i."""
    if -10 ** 9 < v < 10 ** 9:
        return str(v)
    return '#%016X' % (v & (2 ** 64 - 1))


def parse_i(t):
    if t.startswith('#'):
        v = int(t[1:], 16)
        return v - 2 ** 64 if v >= 2 ** 63 else v
    return int(t)


def params_of(recs):
    f = recs[0]
    return f[5:5 + int(f[4])]


def rcall_args(x):
    return [x[k] for nm, kind, k in layout(x) if nm == 'a']


def rcall_res(x):
    return [x[k] for nm, kind, k in layout(x) if nm == 'd']


# ================================================================ 5.8 Terms
class Info:
    """Definitions, symbols, constants, array registers and their shapes, private bases."""

    def __init__(self, recs):
        self.recs = recs
        self.defs = {}
        for k, r in enumerate(recs):
            for x in (params_of(recs) if r[0] == 'func' else writes(r)):
                self.defs.setdefault(x, []).append(k)
        depth, self.depth = 0, []
        for r in recs:
            if r[0] in ('endloop', 'enddo'):
                depth -= 1
            self.depth.append(depth)
            if r[0] in ('loop', 'do'):
                depth += 1
        # a symbol: class i, one definition, outside every loop (a parameter never written);
        # a constant: a register whose only definition is one li (inside a loop or not)
        self.consts, self.syms = {}, set()
        for r, ds in self.defs.items():
            if not r.startswith('i') or len(ds) != 1:
                continue
            k = ds[0]
            if recs[k][0] == 'li':
                self.consts[r] = parse_i(recs[k][2])
            if recs[k][0] == 'func' or (self.depth[k] == 0 and recs[k][0] != 'loop'):
                self.syms.add(r)
        # array registers (a greatest fixed point)
        cand = {r for r, ds in self.defs.items() if r.startswith('p')
                and all(recs[k][0] in ('rcall', 'mov') for k in ds)}
        changed = True
        while changed:
            changed = False
            for r in sorted(cand):
                for k in self.defs[r]:
                    x = recs[k]
                    ok = ((x[0] == 'rcall' and x[1] in ARR_ENTRIES)
                          or (x[0] == 'rcall' and x[1] == 'sea_arr_unique'
                              and rcall_args(x)[0] in cand)
                          or (x[0] == 'mov' and x[2] in cand))
                    if not ok:
                        cand.discard(r)
                        changed = True
                        break
        self.arrays = cand
        # shapes: rows(A), cols(A) as a register (symbol or constant) or a pseudo-symbol
        self.rows, self.cols = {}, {}
        for a in sorted(cand):
            other = [k for k in self.defs[a] if not self.is_cow_mov(a, k)]
            if len(other) != 1:
                continue
            x = recs[other[0]]
            if x[0] == 'rcall' and x[1] in NEW_ENTRIES:
                ra, ca = rcall_args(x)[2], rcall_args(x)[3]
                if ra in self.syms and ca in self.syms:
                    self.rows[a], self.cols[a] = ra, ca
                    continue
            self.rows[a], self.cols[a] = ('<', a, 'rows'), ('<', a, 'cols')
        self.shape_stable = set(self.rows)
        for p in params_of(recs):
            if not p.startswith('p') or len(self.defs[p]) != 1:
                continue
            if any((r[0] in STORES and r[2] == p)
                   or (r[0] in ('call', 'mcopy') and p in [r[k] for k in reads(r)])
                   for r in recs[1:]):
                continue
            # L-ba: a dynamic-array parameter: a chkb on an extent loaded from its header and an
            # indexed access through its data address (rule 18)
            ext = {r[1] for r in recs if r[0] == 'ldi' and r[2] == p and r[3] == '-'
                   and int(r[5]) in (SEA_ARR_ROWS, SEA_ARR_COLS)}
            dat = {r[1] for r in recs if r[0] == 'ldp' and r[2] == p and r[3] == '-'
                   and int(r[5]) == SEA_ARR_DATA}
            if not (any(r[0] == 'chkb' and r[2] in ext for r in recs)
                    and any((r[0] in LOADS or r[0] in STORES) and r[2] in dat and r[3] != '-'
                            for r in recs)):
                continue
            self.rows[p], self.cols[p] = ('<', p, 'rows'), ('<', p, 'cols')
        # private bases
        self.private = set()
        for r, ds in self.defs.items():
            if not r.startswith('p'):
                continue
            if not (ds == [0] or (all(recs[k][0] == 'sa' for k in ds)
                                  and len({recs[k][2] for k in ds}) == 1)):
                continue
            if all((x[0] in LOADS or x[0] in STORES) and k == 2 and x[3] == '-'
                   for x in recs[1:] for k in reads(x) if x[k] == r):
                self.private.add(r)

    def is_cow_mov(self, a, k):
        """`mov A N` with N the result of `rcall sea_arr_unique ... N 1 A` (rule 19 on A)."""
        x = self.recs[k]
        if x[0] != 'mov' or x[1] != a:
            return False
        for j in self.defs.get(x[2], []):
            y = self.recs[j]
            if not (y[0] == 'rcall' and y[1] == 'sea_arr_unique' and rcall_args(y) == [a]
                    and rcall_res(y) == [x[2]]):
                return False
        return True


# ================================================================ T1: the facts and the walk
def badd(b, d):
    """Bound b moved by d; a constant leaving -2^52 ... 2^52 makes it unknown."""
    if b is None:
        return None
    s, k = b
    k += d
    return (s, k) if -FLIM <= k <= FLIM else None


def cbound(v):
    return (None, v) if -FLIM <= v <= FLIM else None


class State:
    """Intervals of the registers that are not symbols, and L(s), U(s) of the symbols."""

    def __init__(self):
        self.iv, self.L, self.U = {}, {}, {}

    def copy(self):
        s = State()
        s.iv, s.L, s.U = dict(self.iv), dict(self.L), dict(self.U)
        return s

    def Lof(self, s):
        if s in self.L:
            return self.L[s]
        return 0 if isinstance(s, tuple) else None

    def Uof(self, s):
        if s in self.U:
            return self.U[s]
        return SEA_LIM_EXTENT if isinstance(s, tuple) else None

    def le(self, b1, b2):
        """Bound s + k <= bound t + m (5.8 "Facts")."""
        if b1 is None or b2 is None:
            return False
        (s, k), (t, m) = b1, b2
        if s == t:
            return k <= m
        if s is None:
            lt = self.Lof(t)
            return lt is not None and k <= lt + m
        if t is None:
            us = self.Uof(s)
            return us is not None and us + k <= m
        # L-au: two symbols through their constant bounds
        us, lt = self.Uof(s), self.Lof(t)
        return us is not None and lt is not None and us + k <= lt + m

    def comparable(self, a, b):
        return self.le(a, b) or self.le(b, a)

    def narrow_lo(self, cur, cand):
        if cand is None:
            return cur
        if cur is None:
            return cand
        return cand if self.le(cur, cand) else cur

    def narrow_hi(self, cur, cand):
        if cand is None:
            return cur
        if cur is None:
            return cand
        return cand if self.le(cand, cur) else cur


NEG = {'lt': 'ge', 'ge': 'lt', 'le': 'gt', 'gt': 'le', 'eq': 'ne', 'ne': 'eq'}


class T1:
    def __init__(self, recs, fn, log):
        self.recs, self.fn, self.log = recs, fn, log
        self.info = Info(recs)
        self.rc_iv = {}

    def ivl(self, st, r):
        inf = self.info
        if r in inf.consts:
            b = cbound(inf.consts[r])
            return (b, b)
        if r in inf.syms:
            return ((r, 0), (r, 0))
        return st.iv.get(r, (None, None))

    def setr(self, st, r, lo, hi):
        """A write of r with the bounds lo, hi (a symbol keeps [r, r]: constants to L, U)."""
        inf = self.info
        if r in inf.consts:
            return
        if r in inf.syms:
            if lo is not None and lo[0] is None:
                st.L[r] = lo[1]
            if hi is not None and hi[0] is None:
                st.U[r] = hi[1]
            return
        st.iv[r] = (lo, hi)

    def unknown(self, st, r):
        if r not in self.info.syms:
            st.iv.pop(r, None)

    def nsym_lo(self, st, s, c):
        if c is None or not -FLIM <= c <= FLIM:
            return
        cur = st.Lof(s)
        st.L[s] = c if cur is None else max(cur, c)

    def nsym_hi(self, st, s, c):
        if c is None or not -FLIM <= c <= FLIM:
            return
        cur = st.Uof(s)
        st.U[s] = c if cur is None else min(cur, c)

    def nlo(self, st, r, cand):
        """Narrow r's lower bound by cand; a symbol takes a constant candidate into L(r)."""
        inf = self.info
        if r in inf.consts or cand is None:
            return
        if r in inf.syms:
            if cand[0] is None:
                self.nsym_lo(st, r, cand[1])
            return
        lo, hi = st.iv.get(r, (None, None))
        st.iv[r] = (st.narrow_lo(lo, cand), hi)

    def nhi(self, st, r, cand):
        inf = self.info
        if r in inf.consts or cand is None:
            return
        if r in inf.syms:
            if cand[0] is None:
                self.nsym_hi(st, r, cand[1])
            return
        lo, hi = st.iv.get(r, (None, None))
        st.iv[r] = (lo, st.narrow_hi(hi, cand))

    def cmp_narrow(self, st, cc, A, B, at):
        """F5 in st for `A cc B`, the candidates taken from the state at the if."""
        alo, ahi = self.ivl(at, A)
        blo, bhi = self.ivl(at, B)
        if cc == 'lt':
            self.nhi(st, A, badd(bhi, -1))
            self.nlo(st, B, badd(alo, 1))
        elif cc == 'le':
            self.nhi(st, A, bhi)
            self.nlo(st, B, alo)
        elif cc == 'gt':
            self.nlo(st, A, badd(blo, 1))
            self.nhi(st, B, badd(ahi, -1))
        elif cc == 'ge':
            self.nlo(st, A, blo)
            self.nhi(st, B, ahi)
        elif cc == 'eq':
            self.nlo(st, A, blo)
            self.nhi(st, A, bhi)
            self.nlo(st, B, alo)
            self.nhi(st, B, ahi)
        elif cc == 'ne' and blo is not None and blo == bhi:
            if A in self.info.syms or A in self.info.consts:
                return
            lo, hi = st.iv.get(A, (None, None))
            st.iv[A] = (badd(blo, 1) if lo == blo else lo, badd(blo, -1) if hi == blo else hi)

    def join(self, a, b):
        out = State()
        for s in set(a.L) | set(b.L) | set(a.U) | set(b.U):
            la, lb, ua, ub = a.Lof(s), b.Lof(s), a.Uof(s), b.Uof(s)
            out.L[s] = None if la is None or lb is None else min(la, lb)
            out.U[s] = None if ua is None or ub is None else max(ua, ub)
        for r in set(a.iv) & set(b.iv):
            (alo, ahi), (blo, bhi) = a.iv[r], b.iv[r]
            lo = (blo if out.le(blo, alo) else alo) if out.comparable(alo, blo) else None
            hi = (bhi if out.le(ahi, bhi) else ahi) if out.comparable(ahi, bhi) else None
            out.iv[r] = (lo, hi)
        return out

    def fits_addk(self, st, lo, hi, k):
        """T1's no-overflow condition for a constant k added to [lo, hi]."""
        up = dn = False
        if hi is not None:
            s, c = hi
            if s is None:
                up = c + k <= I64_MAX
            else:
                us = st.Uof(s)
                up = c + k <= 0 or (us is not None and us + c + k <= I64_MAX)
        if lo is not None:
            s, c = lo
            if s is None:
                dn = c + k >= I64_MIN
            else:
                ls = st.Lof(s)
                dn = c + k >= 0 or (ls is not None and ls + c + k >= I64_MIN)
        return up and dn

    def est(self, st, b, upper):
        if b is None:
            return None
        s, c = b
        if s is None:
            return c
        v = st.Uof(s) if upper else st.Lof(s)
        return None if v is None else v + c

    def addsub(self, st, x):
        """F1 for iadd isub iaddc isubc: (lo, hi, exact result in i64, F1 applies)."""
        op, a, b = x[0], x[2], x[3]
        inf = self.info
        sub = op.startswith('isub')
        ka, kb = inf.consts.get(a), inf.consts.get(b)
        if kb is not None and -FLIM <= kb <= FLIM:
            k = -kb if sub else kb
            lo, hi = self.ivl(st, a)
            return badd(lo, k), badd(hi, k), self.fits_addk(st, lo, hi, k), True
        if ka is not None and not sub and -FLIM <= ka <= FLIM:
            lo, hi = self.ivl(st, b)
            return badd(lo, ka), badd(hi, ka), self.fits_addk(st, lo, hi, ka), True
        # no constant operand (or a constant minuend, L-av): only the overflow test, from the
        # operands' bounds made constant through L, U
        alo, ahi = self.ivl(st, a)
        blo, bhi = self.ivl(st, b)
        ea = (self.est(st, alo, False), self.est(st, ahi, True))
        eb = (self.est(st, blo, False), self.est(st, bhi, True))
        fits = False
        if None not in ea and None not in eb:
            if sub:
                fits = ea[1] - eb[0] <= I64_MAX and ea[0] - eb[1] >= I64_MIN
            else:
                fits = ea[1] + eb[1] <= I64_MAX and ea[0] + eb[0] >= I64_MIN
        return None, None, fits, False

    def guard_jbounds(self, k, at):
        """F3: when record k is the guard `if` of a loop in rule 4's or rule 17's pattern, the
        bounds of the loop's ind; else None."""
        recs = self.recs
        x = recs[k]
        if x[0] != 'if' or k + 1 >= len(recs):
            return None
        B, nx = int(x[1]), recs[k + 1]
        if k >= 1 and recs[k - 1][0] == 'rcount' and nx[0] == 'loop':
            rc = recs[k - 1]
            C, E, lo, stp, incl = rc[1], rc[2], rc[3], rc[5], int(rc[6])
            if x[2] == E and int(nx[1]) == B + 1 and nx[3] == lo and nx[4] == C \
                    and nx[5] == stp:
                t = self.info.consts.get(stp)
                if t is None or t == 0:
                    return None
                ilo, ihi = self.rc_iv[k - 1]
                if t > 0:
                    return ilo[0], badd(ihi[1], -1 + incl)
                return badd(ihi[0], 1 - incl), ilo[1]
        if 2 <= k and k + 3 < len(recs):
            z, c = recs[k - 2], recs[k - 1]
            o, l, lp = recs[k + 1], recs[k + 2], recs[k + 3]
            if (z[0] == 'li' and z[2] == '0' and c[:2] == ['icmp', 'gt'] and c[2] == x[2]
                    and c[4] == z[1] and o[0] == 'li' and o[2] == '1' and l[0] == 'isub'
                    and l[2] == c[3] and l[3] == o[1] and lp[0] == 'loop'
                    and int(lp[1]) == B + 1 and lp[3:6] == [z[1], l[1], o[1]]):
                return (None, 0), badd(self.ivl(at, c[3])[1], -1)
        return None

    def f5_rel(self, k):
        """F5: (cc, A, B) of the icmp whose result the if/ifz at k tests, in its region with A,
        B and the result not written between; else None."""
        recs = self.recs
        c = recs[k][2]
        j = k - 1
        while j >= 1 and recs[j][0] not in CUT:
            if c in writes(recs[j]):
                y = recs[j]
                if y[0] != 'icmp':
                    return None
                for m in range(j + 1, k):
                    if set(writes(recs[m])) & {y[3], y[4], c}:
                        return None
                return (y[1], y[3], y[4])
            j -= 1
        return None

    def run(self):
        recs = self.recs
        loopw, stack = {}, []
        for k, x in enumerate(recs):
            if x[0] in ('loop', 'do'):
                stack.append(k)
                loopw[k] = set()
            for s in stack:
                loopw[s].update(writes(x))
            if x[0] in ('endloop', 'enddo'):
                stack.pop()
        st, ctx, out = State(), [], []
        dead, last = False, None

        def part_state(c, first):
            s = c['at'].copy()
            if c['rel'] is not None:
                cc, A, B = c['rel']
                if first != (c['op'] == 'if'):
                    cc = NEG[cc]
                self.cmp_narrow(s, cc, A, B, c['at'])
            return s

        for k, x in enumerate(recs):
            op = x[0]
            if op in ('func', 'endfunc', 'slot'):
                out.append(x)
                continue
            ends = last in ('exit', 'next', 'ret') or dead
            if op in ('if', 'ifz'):
                c = {'op': op, 'at': st.copy(), 'rel': self.f5_rel(k), 'else': False,
                     'dead': dead}
                st = part_state(c, True)
                jb = self.guard_jbounds(k, c['at']) if op == 'if' else None
                if jb is not None and jb[0] is not None and jb[1] is not None:
                    lo, hi = jb          # the guard's first part: lo <= hi on a symbol
                    if lo[0] is None and hi[0] is not None:
                        self.nsym_lo(st, hi[0], lo[1] - hi[1])
                    elif hi[0] is None and lo[0] is not None:
                        self.nsym_hi(st, lo[0], hi[1] - lo[1])
                ctx.append(c)
            elif op == 'else':
                c = ctx[-1]
                c['then'], c['then_ends'], c['else'] = st, ends, True
                st, dead = part_state(c, False), c['dead']
            elif op == 'endif':
                c = ctx.pop()
                if c['else']:
                    p1, e1, p2, e2 = c['then'], c['then_ends'], st, ends
                else:
                    p1, e1, p2, e2 = st, ends, part_state(c, False), False
                if e1 and e2:
                    st = c['at']
                elif e1 or e2:
                    st = p2 if e1 else p1
                else:
                    st = self.join(p1, p2)
                dead = c['dead']
            elif op in ('loop', 'do'):
                c = {'entry': st.copy(), 'w': loopw[k], 'dead': dead}
                st = st.copy()
                for r in loopw[k]:
                    self.unknown(st, r)
                if op == 'loop' and recs[k - 1][0] == 'if' and ctx:
                    jb = self.guard_jbounds(k - 1, ctx[-1]['at'])
                    if jb is not None:
                        st.iv[x[2]] = jb
                ctx.append(c)
            elif op in ('endloop', 'enddo'):
                c = ctx.pop()
                st = c['entry'].copy()
                for r in c['w']:
                    self.unknown(st, r)
                dead = c['dead']
            elif op in ('exit', 'next', 'ret'):
                dead = True
            elif not dead:
                x = self.instr(st, x, k)
            last = op
            if x is not None:
                out.append(x)
        return out

    def instr(self, st, x, k):
        op, inf = x[0], self.info
        if op == 'chkb':
            I, E = x[1], x[2]
            ilo, ihi = self.ivl(st, I)
            elo, ehi = self.ivl(st, E)
            gone = st.le((None, 0), ilo) and st.le(ihi, badd(elo, -1))
            self.nlo(st, I, (None, 0))                      # F4
            self.nhi(st, I, badd(ehi, -1))
            if gone:
                self.log.append(('T1', self.fn, 'del', ' '.join(x)))
                return None
            return x
        if op == 'rcount':
            self.rc_iv[k] = (self.ivl(st, x[3]), self.ivl(st, x[4]))
            for r in writes(x):
                self.unknown(st, r)
            return x
        if op == 'li':
            b = cbound(parse_i(x[2]))
            self.setr(st, x[1], b, b)
            return x
        if op == 'mov' and x[1].startswith('i'):
            lo, hi = self.ivl(st, x[2])
            self.setr(st, x[1], lo, hi)
            return x
        if op in ('iadd', 'isub', 'iaddc', 'isubc'):
            checked = op.endswith('c')
            lo, hi, fits, f1 = self.addsub(st, x)
            nx = x
            if checked and fits:
                nx = [op[:-1]] + x[1:4]
                self.log.append(('T1', self.fn, 'wrap', ' '.join(x)))
            if f1 and (checked or fits):
                self.setr(st, x[1], lo, hi)
            else:
                self.unknown(st, x[1])
            return nx
        if op == 'inegc':
            lo, _ = self.ivl(st, x[2])
            fits = False
            if lo is not None:
                s, c = lo
                if s is None:
                    fits = -c <= I64_MAX
                else:
                    ls = st.Lof(s)
                    fits = c >= 1 or (ls is not None and ls + c >= I64_MIN + 1)
            self.unknown(st, x[1])
            if fits:
                self.log.append(('T1', self.fn, 'wrap', ' '.join(x)))
                return ['ineg', x[1], x[2]]
            return x
        if op == 'imulc':
            bs = self.ivl(st, x[2]) + self.ivl(st, x[3])
            fits = all(b is not None and b[0] is None for b in bs) and all(
                -FLIM <= p[1] * q[1] <= FLIM for p in bs[:2] for q in bs[2:])
            self.unknown(st, x[1])
            if fits:
                self.log.append(('T1', self.fn, 'wrap', ' '.join(x)))
                return ['imul'] + x[1:4]
            return x
        if op == 'ldi' and x[3] == '-' and x[2] in inf.rows \
                and int(x[5]) in (SEA_ARR_ROWS, SEA_ARR_COLS):          # F2
            sh = inf.rows[x[2]] if int(x[5]) == SEA_ARR_ROWS else inf.cols[x[2]]
            E = x[1]
            if E in inf.syms and E not in inf.consts:
                # E keeps [E, E]; L(E), U(E) narrowed by x's constant bounds (L-au)
                if isinstance(sh, str) and sh in inf.consts:
                    lo = hi = inf.consts[sh]
                else:
                    lo, hi = st.Lof(sh), st.Uof(sh)
                self.nsym_lo(st, E, lo)
                self.nsym_hi(st, E, hi)
                return x
            if isinstance(sh, tuple) or sh not in inf.consts:
                b = (sh, 0)
            else:
                b = cbound(inf.consts[sh])
            self.setr(st, E, b, b)
            return x
        for r in writes(x):
            self.unknown(st, r)
        if op == 'rcall' and x[1] in NEW_ENTRIES and rcall_res(x)[0] in inf.shape_stable:
            a = rcall_res(x)[0]
            for sh in (inf.rows[a], inf.cols[a]):                       # F2, second part
                if isinstance(sh, str) and sh not in inf.consts:
                    self.nsym_lo(st, sh, 0)
                    self.nsym_hi(st, sh, SEA_LIM_EXTENT)
        return x


# ================================================================ dead records (L-bb 3)
def dead_mask(recs):
    """True for the records after an exit, next or ret at a part's top level, up to the end of
    that part (its else, endif, endloop, enddo or endfunc): they never run, and no
    transformation changes them."""
    out, depth, level = [], 0, None
    for x in recs:
        op = x[0]
        if op in ('endif', 'endloop', 'enddo', 'else', 'endfunc'):
            depth -= 1
        if level is not None and depth < level:
            level = None
        out.append(level is not None)
        if op in ('loop', 'do', 'if', 'ifz', 'else', 'func'):
            depth += 1
        if level is None and op in ('exit', 'next', 'ret'):
            level = depth
    return out


# ================================================================ T2
def magic(c):
    """5.8 T2: Hacker's Delight 10-1 for 64-bit signed division by c >= 3, not a power of 2."""
    nc = 2 ** 63 - 1 - (2 ** 63 % c)
    p = 64
    while not 2 ** p > nc * (c - 2 ** p % c):
        p += 1
    M = (2 ** p + c - 2 ** p % c) // c
    assert M < 2 ** 64
    return M, p - 64


def t2(recs, fn, log):
    info = Info(recs)
    cnt = [0]

    def new(cls):
        cnt[0] += 1
        return '%s.t2_%d' % (cls, cnt[0])

    out = []
    dead = dead_mask(recs)
    for n, x in enumerate(recs):
        op = x[0]
        if dead[n]:
            out.append(x)
            continue
        if op in ('idivf', 'imodf') and info.consts.get(x[3], 0) >= 1:
            d, a, b = x[1], x[2], x[3]
            c = info.consts[b]
            log.append(('T2', fn, ' '.join(x)))
            if c == 1:
                out.append(['li', d, '0'] if op == 'imodf' else ['mov', d, a])
            elif c & (c - 1) == 0:
                m = new('i')
                if op == 'imodf':
                    out += [['li', m, fmt_i(c - 1)], ['iand', d, a, m]]
                else:
                    out += [['li', m, fmt_i(c.bit_length() - 1)], ['isar', d, a, m]]
            else:
                M, s = magic(c)
                Mr, H = new('i'), new('i')
                out += [['li', Mr, fmt_i(M - 2 ** 64 if M >= 2 ** 63 else M)],
                        ['imulh', H, a, Mr]]
                if M >= 2 ** 63:
                    H2 = new('i')
                    out.append(['iadd', H2, H, a])
                    H = H2
                S = new('i')
                out.append(['li', S, str(s)])                           # L-av: also when s = 0
                if s != 0:
                    Q = new('i')
                    out.append(['isar', Q, H, S])
                    H = Q
                K, N, Q2, P, R, A = (new('i') for _ in range(6))
                out += [['li', K, '63'], ['isar', N, a, K], ['isub', Q2, H, N],
                        ['imul', P, Q2, b], ['isub', R, a, P]]
                if op == 'imodf':
                    out.append(['iadd', A, R, b])
                else:
                    O = new('i')
                    out += [['li', O, '1'], ['isub', A, Q2, O]]
                Z, L = new('i'), new('i')
                out += [['li', Z, '0'], ['icmp', 'lt', L, R, Z],
                        ['isel', d, L, A, R if op == 'imodf' else Q2]]
            continue
        if op == 'fdiv':
            ds = info.defs.get(x[3], [])
            if len(ds) == 1 and recs[ds[0]][0] == 'lf':
                bits = int(recs[ds[0]][2][1:], 16)
                sign, ex = bits >> 63, (bits >> 52) & 0x7FF
                if bits & ((1 << 52) - 1) == 0 and 1 <= ex <= 2046:
                    e = ex - 1023
                    if e <= 1022:
                        rb = (sign << 63) | ((1023 - e) << 52)
                    else:                       # e = 1023: the subnormal 2^-1023
                        rb = (sign << 63) | (1 << 51)
                    R = new('f')
                    log.append(('T2', fn, ' '.join(x)))
                    out += [['lf', R, '#%016X' % rb], ['fmul', x[1], x[2], R]]
                    continue
        out.append(x)
    return out


# ================================================================ T3
def regions(recs):
    out, s = [], None
    for k, x in enumerate(recs):
        if x[0] in CUT or x[0] in ('func', 'endfunc', 'slot'):
            if s is not None:
                out.append((s, k))
            s = None
        elif s is None:
            s = k
    return out


def key_of(x):
    """Every field but the destination and the site."""
    return tuple([x[0]] + [x[k] for nm, kind, k in layout(x) if nm != 'd' and kind != 'site'])


def ld_key(x):
    return (LOADS.get(x[0]) or STORES.get(x[0]), x[2], x[3], x[4], x[5])


def t3(recs, fn, log):
    recs = [list(x) for x in recs]
    info = Info(recs)
    alive = [True] * len(recs)

    def written(r, a, b):
        return any(alive[m] and r in writes(recs[m]) for m in range(a + 1, b))

    def may_change(ld, X):
        base, off, opx = ld[2], int(ld[5]), X[0]
        if base in info.arrays and ld[3] == '-' and off in (SEA_ARR_ROWS, SEA_ARR_COLS,
                                                            SEA_ARR_DATA):
            return False
        if base in info.arrays and ld[3] == '-' and off == SEA_ARR_RC:
            return opx in ('retain', 'release', 'call', 'rcall')
        if base in info.private and ld[3] == '-':
            if opx in STORES and X[2] == base:
                sz, szx, ox = (1 if ld[0] == 'ldb' else 8), (1 if opx == 'stb' else 8), int(X[5])
                return ox < off + sz and off < ox + szx
            return False
        if opx in STORES and STORES[opx] == LOADS[ld[0]] and X[2] not in info.private:
            return True
        return opx in ('mcopy', 'call', 'rcall')

    def ndefs(r):
        return sum((params_of(recs).count(r) if y[0] == 'func' else writes(y).count(r))
                   for m, y in enumerate(recs) if alive[m])

    def readers(r):
        return [(m, k) for m, y in enumerate(recs) if alive[m] for k in reads(y) if y[k] == r]

    dead = dead_mask(recs)
    for (s, e) in regions(recs):
        if dead[s]:
            continue
        for j in range(s, e):
            x = recs[j]
            op = x[0]
            if op in PURE or op in ('iaddc', 'isubc', 'imulc', 'inegc'):
                kx, rd = key_of(x), [x[k] for k in reads(x)]
                for i in range(j - 1, s - 1, -1):
                    if not alive[i] or recs[i][0] != op or key_of(recs[i]) != kx:
                        continue
                    d0 = writes(recs[i])[0]
                    if any(written(r, i, j) for r in rd) or written(d0, i, j) or d0 in rd:
                        continue        # L-bb 1: an earlier one writing its own operand
                    recs[j] = x = ['mov', writes(x)[0], d0]
                    break
            elif op in LOADS:
                kx = ld_key(x)
                for i in range(j - 1, s - 1, -1):
                    y = recs[i]
                    if not alive[i] or not (y[0] in LOADS or y[0] in STORES) or ld_key(y) != kx:
                        continue
                    V = y[1]
                    if y[0] in LOADS and V in (x[2], x[3]):
                        continue        # L-bb 1: an earlier load writing its base or idx
                    if written(x[2], i, j) or (x[3] != '-' and written(x[3], i, j)) \
                            or written(V, i, j):
                        continue
                    if any(alive[m] and may_change(x, recs[m]) for m in range(i + 1, j)):
                        continue
                    log.append(('T3', fn, 'load', ' '.join(x), V))
                    recs[j] = x = ['mov', x[1], V]
                    break
            if x[0] == 'mov' and ndefs(x[1]) == 1:                     # copy propagation
                D, S = x[1], x[2]
                rs = readers(D)
                if all(j < m < e for m, _ in rs):
                    if not written(S, j, max([m for m, _ in rs], default=j)):
                        for m, kk in rs:
                            recs[m][kk] = S
                        alive[j] = False
    return [x for m, x in enumerate(recs) if alive[m]]


# ================================================================ T4
def t4(recs, fn, log):
    out, k = [], 0
    sel = {'i': 'isel', 'f': 'fsel', 'p': 'psel'}
    dead = dead_mask(recs)
    while k < len(recs):
        x = recs[k]
        if not dead[k] and x[0] in ('if', 'ifz') and k + 2 < len(recs) and recs[k + 1][0] == 'mov':
            B, c, R, S1 = x[1], x[2], recs[k + 1][1], recs[k + 1][2]
            if recs[k + 2] == ['endif', B]:
                a, b, n = (S1, R, 3) if x[0] == 'if' else (R, S1, 3)
            elif (k + 4 < len(recs) and recs[k + 2] == ['else', B] and recs[k + 3][0] == 'mov'
                  and recs[k + 3][1] == R and recs[k + 4] == ['endif', B]):
                S2 = recs[k + 3][2]
                a, b, n = (S1, S2, 5) if x[0] == 'if' else (S2, S1, 5)
            else:
                n = 0
            if n:
                out.append([sel[R[0]], R, c, a, b])
                log.append(('T4', fn, ' '.join(x)))
                k += n
                continue
        out.append(x)
        k += 1
    return out


# ================================================================ T10 and renumbering
def t10(recs, fn, log):
    recs = [list(x) for x in recs]
    changed = True
    while changed:
        changed = False
        rd = {y[k] for y in recs for k in reads(y)}
        dead = dead_mask(recs)
        out, k = [], 0
        while k < len(recs):
            x, op = recs[k], recs[k][0]
            n = 0
            if dead[k]:
                pass
            elif (op in PURE or op in LOADS) and writes(x)[0] not in rd:
                n = 1
            elif op == 'mov' and x[1] == x[2]:
                n, ev = 1, 'movRR'
            elif op in ('if', 'ifz') and recs[k + 1] == ['endif', x[1]]:
                n, ev = 2, 'if'
            elif op in ('if', 'ifz') and recs[k + 1] == ['else', x[1]] \
                    and recs[k + 2] == ['endif', x[1]]:
                n, ev = 3, 'if'
            elif op == 'retain' and recs[k + 1] == ['release', x[1]]:
                n, ev = 2, 'retain'
            if n:
                if n > 1 or op == 'mov' and x[1] == x[2]:
                    log.append(('T10', fn, ev, ' '.join(x)))
                changed = True
                k += n
                continue
            out.append(x)
            k += 1
        recs = out
    return recs


def renumber(recs):
    """3.6.1: registers by first appearance (the parameters first), blocks by opening record."""
    names, blocks, out = {}, {}, []
    for x in recs:
        y = list(x)
        if y[0] in ('loop', 'do', 'if', 'ifz'):
            blocks[y[1]] = str(len(blocks) + 1)
        if y[0] in BLOCK + ('exit', 'next'):
            y[1] = blocks[y[1]]
        if y[0] not in ('slot', 'endfunc'):
            for k in sorted({k for nm, kind, k in layout(y) if kind in REGK and y[k] != '-'}):
                if y[k] not in names:
                    names[y[k]] = '%s%d' % (y[k][0], len(names) + 1)
                y[k] = names[y[k]]
        out.append(y)
    return out


def optimize(text, log):
    """sea.lir1 -> sea.lir as 5c-1's seaopt writes it: T1, T2, T3, T4, T10, renumbered."""
    lines = text.rstrip('\n').split('\n')
    assert lines[-1] == '#end'
    out, fn = [], None
    for ln in lines[:-1]:
        t = ln.split(' ')
        if t[0] == 'func':
            fn = [t]
        elif fn is not None:
            fn.append(t)
            if t[0] == 'endfunc':
                name = fn[0][1]
                recs = T1(fn, name, log).run()
                for step in (t2, t3, t4, t10):
                    recs = step(recs, name, log)
                out += [' '.join(x) for x in renumber(recs)]
                fn = None
        else:
            out.append(ln)
    return '\n'.join(out + ['#end']) + '\n'


# ================================================================ the cases
# Each case: NAME.sea, its NAME.lir1 (the input, from the phase-4 passes) and EVENTS[NAME],
# the transformations derived by hand (5.8) that the model must make: T1 checks deleted
# (del) and checked arithmetic made wrapping (wrap), T2 divisions, T3 loads replaced by
# a register (load, with the register), T4 ifs converted, T10 deletions of a mov R R,
# an empty if or a retain/release pair. (T3 rule 1 sharing, copy propagation and T10
# deletions of unread values follow from these in each derivation note.)
CASES = {}
EVENTS = {}


# ---------------------------------------------------------------- opt5_bce_range
# fill: u = zeros(n) is shape-stable with rows(u) = n (i1, a symbol; its other definitions are
# the cows' movs), so F2 gives the in-loop extent i13 = [i1, i1]; F3 gives the ind of 0..n
# [0, i1 - 1]: chkb i11 i13 deleted (T1). In 0..=m the ind is [0, i2] and i2 is not i1: kept;
# F4's candidate i1 - 1 is not comparable with i2, so the repeated check after the add stays too.
# back: rows(w) = 10 (i2, a constant): 9..=0 step -1 gives [0, 9], 0..10 step 3 gives [0, 9]
# (both checks of w[j] deleted), and the constant index 9 against the symbol i36 with L(i36) = 10
# (F2's constant) is deleted. T3 rule 2: the second header load of the region (i29) is i24 / i25
# (an array register's header never changes). T10: the dead header loads, `retain p6` /
# `release p6` before `ret 1 p6`.
CASES['opt5_bce_range'] = (r"""fn fill(n: i64, m: i64) -> f64[] {
    var u = zeros(n)
    for i in 0..n {
        u[i] = 1.5
    }
    for i in 0..=m {
        u[i] = u[i] + 2.0
    }
    return u
}
fn back(k: f64) -> f64 {
    var w = zeros(10)
    for i in 9..=0 step -1 {
        w[i] = k
    }
    for j in 0..10 step 3 {
        w[j] = w[j] * k
    }
    return w[9]
}
let a = fill(4, 2)
let b = fill(6, 5)
printf("%g %g %g %g\n", a[0], b[5], back(2.0), back(0.5))
// opt5_bce_range -- DESIGN.md 5.8 T1 with the facts F2 (rows of zeros(n)) and F3 (a loop's ind
// in its range): deleted for 0..n over zeros(n), 9..=0 step -1, 0..10 step 3 and the constant
// index 9 of zeros(10); kept for 0..=m (m is not n), and the repeated check of u[i] in that
// loop (F4's candidate n - 1 is not comparable with m: the old bound stays)
""", r"""#sea 1
#target arm64-macos
#file opt5_bce_range.sea
func .main main 0:1:1 0 0
slot s1 32 8
li i1 4
li i2 2
call fill 1 p3 2 i1 i2
li i4 6
li i5 5
call fill 1 p6 2 i4 i5
li i7 0
ldi i8 p3 - 0 16
chkb i7 i8 0 0:23
ldp p9 p3 - 0 40
ldf f10 p9 i7 8 0
li i11 5
ldi i12 p6 - 0 16
chkb i11 i12 0 0:23
ldp p13 p6 - 0 40
ldf f14 p13 i11 8 0
lf f15 #4000000000000000
call back 1 f16 1 f15
lf f17 #3FE0000000000000
call back 1 f18 1 f17
sa p19 s1
stf f10 p19 - 0 0
stf f14 p19 - 0 8
stf f16 p19 - 0 16
stf f18 p19 - 0 24
la p20 d1
rcall sea_printf 0:23 0 2 p20 p19
release p6
release p3
ret 0
endfunc
func fill fn 0:1:1 2 i1 i2 1 p
li i3 1
li i4 1
li i5 1
rcall sea_arr_new 0:2 1 p6 4 i3 i4 i1 i5
li i7 0
li i8 1
rcount i9 i10 i7 i1 i8 0 0:3
if 1 i10
loop 2 i11 i7 i9 i8
lf f12 #3FF8000000000000
ldi i13 p6 - 0 16
chkb i11 i13 0 0:4
ldi i14 p6 - 0 0
li i15 1
icmp ne i16 i14 i15
if 3 i16
rcall sea_arr_unique 0:4 1 p17 1 p6
mov p6 p17
endif 3
ldp p18 p6 - 0 40
stf f12 p18 i11 8 0
endloop 2
endif 1
li i19 0
li i20 1
rcount i21 i22 i19 i2 i20 1 0:6
if 4 i22
loop 5 i23 i19 i21 i20
ldi i24 p6 - 0 16
chkb i23 i24 0 0:7
ldp p25 p6 - 0 40
ldf f26 p25 i23 8 0
lf f27 #4000000000000000
fadd f28 f26 f27
ldi i29 p6 - 0 16
chkb i23 i29 0 0:7
ldi i30 p6 - 0 0
li i31 1
icmp ne i32 i30 i31
if 6 i32
rcall sea_arr_unique 0:7 1 p33 1 p6
mov p6 p33
endif 6
ldp p34 p6 - 0 40
stf f28 p34 i23 8 0
endloop 5
endif 4
retain p6
release p6
ret 1 p6
endfunc
func back fn 0:11:1 1 f1 1 f
li i2 10
li i3 1
li i4 1
li i5 1
rcall sea_arr_new 0:12 1 p6 4 i3 i4 i2 i5
li i7 9
li i8 0
li i9 -1
rcount i10 i11 i7 i8 i9 1 0:13
if 1 i11
loop 2 i12 i7 i10 i9
ldi i13 p6 - 0 16
chkb i12 i13 0 0:14
ldi i14 p6 - 0 0
li i15 1
icmp ne i16 i14 i15
if 3 i16
rcall sea_arr_unique 0:14 1 p17 1 p6
mov p6 p17
endif 3
ldp p18 p6 - 0 40
stf f1 p18 i12 8 0
endloop 2
endif 1
li i19 0
li i20 10
li i21 3
rcount i22 i23 i19 i20 i21 0 0:16
if 4 i23
loop 5 i24 i19 i22 i21
ldi i25 p6 - 0 16
chkb i24 i25 0 0:17
ldp p26 p6 - 0 40
ldf f27 p26 i24 8 0
fmul f28 f27 f1
ldi i29 p6 - 0 16
chkb i24 i29 0 0:17
ldi i30 p6 - 0 0
li i31 1
icmp ne i32 i30 i31
if 6 i32
rcall sea_arr_unique 0:17 1 p33 1 p6
mov p6 p33
endif 6
ldp p34 p6 - 0 40
stf f28 p34 i24 8 0
endloop 5
endif 4
li i35 9
ldi i36 p6 - 0 16
chkb i35 i36 0 0:19
ldp p37 p6 - 0 40
ldf f38 p37 i35 8 0
release p6
ret 1 f38
endfunc
fmt d1 8
fconv - - - g f
ftext %20
fconv - - - g f
ftext %20
fconv - - - g f
ftext %20
fconv - - - g f
ftext %0A
#end
""")
EVENTS['opt5_bce_range'] = [
    ('T1', 'fill', 'del', 'chkb i11 i13 0 0:4'),
    ('T3', 'fill', 'load', 'ldi i29 p6 - 0 16', 'i24'),
    ('T10', 'fill', 'retain', 'retain p6'),
    ('T1', 'back', 'del', 'chkb i12 i13 0 0:14'),
    ('T1', 'back', 'del', 'chkb i24 i25 0 0:17'),
    ('T1', 'back', 'del', 'chkb i24 i29 0 0:17'),
    ('T1', 'back', 'del', 'chkb i35 i36 0 0:19'),
    ('T3', 'back', 'load', 'ldi i29 p6 - 0 16', 'i25'),
]


# ---------------------------------------------------------------- opt5_bce_dom
# pick, in the loop: `k >= 0` (F5 ge, k the symbol i1, a constant candidate) gives L(i1) = 0 in
# if 3, `k < 8` gives U(i1) = 7 in if 4: chkb i1 i18 against [8, 8] (an in-loop extent of
# zeros(8)) deleted. `if k < 0 ... else`: the else part has the negation ge 0, then `k <= 7`:
# chkb i1 i25 deleted. After those endifs the narrowings are joined away; `if k < 8` alone gives no
# lower bound: chkb i1 i30 kept. j = i34 (imulc of the ind: unknown) narrowed by j < 8 and
# j >= 0 to [0, 7]: chkb i34 i39 deleted.
CASES['opt5_bce_dom'] = (r"""fn pick(k: i64, n: i64) -> f64 {
    var v = zeros(8)
    var s = 0.0
    for i in 0..n {
        if k >= 0 {
            if k < 8 {
                s = s + v[k]
            }
        }
        if k < 0 {
            s = 1.0
        } else {
            if k <= 7 {
                s = s + v[k]
            }
        }
        if k < 8 {
            s = s + v[k]
        }
        let j = i * 3
        if j < 8 {
            if j >= 0 {
                s = s + v[j]
            }
        }
    }
    return s
}
let a = pick(3, 2)
let b = pick(5, 3)
printf("%g %g\n", a, b)
// opt5_bce_dom -- DESIGN.md 5.8 T1 with F5 (dominating comparisons): k >= 0 and k < 8 narrow
// L(k), U(k) of the parameter k (deleted), the else part of `if k < 0` gives k >= 0 (deleted),
// `k < 8` alone gives no lower bound (kept); j = i * 3 (not a symbol) narrowed by j < 8 and
// j >= 0 (deleted). The accesses stand in a loop, where the extent register is not a symbol.
""", r"""#sea 1
#target arm64-macos
#file opt5_bce_dom.sea
func .main main 0:1:1 0 0
slot s1 16 8
li i1 3
li i2 2
call pick 1 f3 2 i1 i2
li i4 5
li i5 3
call pick 1 f6 2 i4 i5
sa p7 s1
stf f3 p7 - 0 0
stf f6 p7 - 0 8
la p8 d1
rcall sea_printf 0:31 0 2 p8 p7
ret 0
endfunc
func pick fn 0:1:1 2 i1 i2 1 f
li i3 8
li i4 1
li i5 1
li i6 1
rcall sea_arr_new 0:2 1 p7 4 i4 i5 i3 i6
lf f8 #0000000000000000
li i9 0
li i10 1
rcount i11 i12 i9 i2 i10 0 0:4
if 1 i12
loop 2 i13 i9 i11 i10
li i14 0
icmp ge i15 i1 i14
if 3 i15
li i16 8
icmp lt i17 i1 i16
if 4 i17
ldi i18 p7 - 0 16
chkb i1 i18 0 0:7
ldp p19 p7 - 0 40
ldf f20 p19 i1 8 0
fadd f8 f8 f20
endif 4
endif 3
li i21 0
icmp lt i22 i1 i21
if 5 i22
lf f8 #3FF0000000000000
else 5
li i23 7
icmp le i24 i1 i23
if 6 i24
ldi i25 p7 - 0 16
chkb i1 i25 0 0:14
ldp p26 p7 - 0 40
ldf f27 p26 i1 8 0
fadd f8 f8 f27
endif 6
endif 5
li i28 8
icmp lt i29 i1 i28
if 7 i29
ldi i30 p7 - 0 16
chkb i1 i30 0 0:18
ldp p31 p7 - 0 40
ldf f32 p31 i1 8 0
fadd f8 f8 f32
endif 7
li i33 3
imulc i34 i13 i33 0:20
li i35 8
icmp lt i36 i34 i35
if 8 i36
li i37 0
icmp ge i38 i34 i37
if 9 i38
ldi i39 p7 - 0 16
chkb i34 i39 0 0:23
ldp p40 p7 - 0 40
ldf f41 p40 i34 8 0
fadd f8 f8 f41
endif 9
endif 8
endloop 2
endif 1
release p7
ret 1 f8
endfunc
fmt d1 4
fconv - - - g f
ftext %20
fconv - - - g f
ftext %0A
#end
""")
EVENTS['opt5_bce_dom'] = [
    ('T1', 'pick', 'del', 'chkb i1 i18 0 0:7'),
    ('T1', 'pick', 'del', 'chkb i1 i25 0 0:14'),
    ('T1', 'pick', 'del', 'chkb i34 i39 0 0:23'),
]


# ---------------------------------------------------------------- opt5_bce_sym
# sym: v = zeros(8) has rows i4 (a constant); its extent i18 is loaded outside every loop, so it
# is a symbol with the interval [i18, i18] and L(i18) = U(i18) = 8 (F2's constant). Under `k >= 0`
# and `k < 8` (F5: L(i1) = 0, U(i1) = 7) chkb i1 i18 is deleted by L-au: U(i1) + 0 <= L(i18) - 1.
# Under `k < 8` alone, chkb i1 i23 against w = zeros(n) (i23 a symbol, F2's extent i2 not a
# constant): L(i1) unknown, kept. Under `k >= 0`, `k < 7` (U(i1) = 6), in the loop the extent
# i37 of w is not a symbol: F2 gives [i2, i2]; inside `if n >= 8` (L(i2) = 8) chkb i1 i37 is
# deleted (6 <= 8 - 1, L-au); after that endif L(i2) is 0 again (from the rcall, F2): chkb i1 i40
# kept.
CASES['opt5_bce_sym'] = (r"""fn sym(k: i64, n: i64, m: i64) -> f64 {
    let v = zeros(8)
    let w = zeros(n)
    var s = 0.0
    if k >= 0 {
        if k < 8 {
            s = s + v[k]
        }
    }
    if k < 8 {
        s = s + w[k]
    }
    if k >= 0 {
        if k < 7 {
            for i in 0..m {
                if n >= 8 {
                    s = s + w[k]
                }
                s = s + w[k]
            }
        }
    }
    return s
}
printf("%g %g\n", sym(3, 9, 2), sym(6, 10, 1))
// opt5_bce_sym -- DESIGN.md 5.8 T1 with L-au (two symbols compared through their constant
// bounds): v[k] under 0 <= k < 8 with v = zeros(8), its extent loaded outside every loop (a
// symbol with L = 8): deleted; w[k] under k < 8 alone, w = zeros(n): kept; w[k] under
// 0 <= k < 7 in a loop, inside `if n >= 8` (L(n) = 8 > U(k) = 6): deleted, after that if: kept
""", r"""#sea 1
#target arm64-macos
#file opt5_bce_sym.sea
func .main main 0:1:1 0 0
slot s1 16 8
li i1 3
li i2 9
li i3 2
call sym 1 f4 3 i1 i2 i3
li i5 6
li i6 10
li i7 1
call sym 1 f8 3 i5 i6 i7
sa p9 s1
stf f4 p9 - 0 0
stf f8 p9 - 0 8
la p10 d1
rcall sea_printf 0:25 0 2 p10 p9
ret 0
endfunc
func sym fn 0:1:1 3 i1 i2 i3 1 f
li i4 8
li i5 1
li i6 1
li i7 1
rcall sea_arr_new 0:2 1 p8 4 i5 i6 i4 i7
li i9 1
li i10 1
li i11 1
rcall sea_arr_new 0:3 1 p12 4 i9 i10 i2 i11
lf f13 #0000000000000000
li i14 0
icmp ge i15 i1 i14
if 1 i15
li i16 8
icmp lt i17 i1 i16
if 2 i17
ldi i18 p8 - 0 16
chkb i1 i18 0 0:7
ldp p19 p8 - 0 40
ldf f20 p19 i1 8 0
fadd f13 f13 f20
endif 2
endif 1
li i21 8
icmp lt i22 i1 i21
if 3 i22
ldi i23 p12 - 0 16
chkb i1 i23 0 0:11
ldp p24 p12 - 0 40
ldf f25 p24 i1 8 0
fadd f13 f13 f25
endif 3
li i26 0
icmp ge i27 i1 i26
if 4 i27
li i28 7
icmp lt i29 i1 i28
if 5 i29
li i30 0
li i31 1
rcount i32 i33 i30 i3 i31 0 0:15
if 6 i33
loop 7 i34 i30 i32 i31
li i35 8
icmp ge i36 i2 i35
if 8 i36
ldi i37 p12 - 0 16
chkb i1 i37 0 0:17
ldp p38 p12 - 0 40
ldf f39 p38 i1 8 0
fadd f13 f13 f39
endif 8
ldi i40 p12 - 0 16
chkb i1 i40 0 0:19
ldp p41 p12 - 0 40
ldf f42 p41 i1 8 0
fadd f13 f13 f42
endloop 7
endif 6
endif 5
endif 4
release p12
release p8
ret 1 f13
endfunc
fmt d1 4
fconv - - - g f
ftext %20
fconv - - - g f
ftext %0A
#end
""")
EVENTS['opt5_bce_sym'] = [
    ('T1', 'sym', 'del', 'chkb i1 i18 0 0:7'),
    ('T1', 'sym', 'del', 'chkb i1 i37 0 0:17'),
]


# ---------------------------------------------------------------- opt5_bce_passed
# twice: j = i13 (imodf by the loaded length: unknown); the first chkb i13 i14 stays and F4
# narrows i13 to [0, <p1,rows> - 1] (p1 a parameter never written, never stored into, never an
# operand of call or mcopy: its extent is the pseudo-symbol); the second chkb against
# i17 = [<p1,rows>] is deleted; chkb i13 i21 against <p2,rows> is not comparable: kept. T3 rule 2
# (p1 is a private base): the header loads i14, i17 are i12, the data address p18 is p15, then
# ldf f19 = f16 (no store between), so the product reads f16 twice.
CASES['opt5_bce_passed'] = (r"""fn twice(v: f64[], w: f64[], n: i64) -> f64 {
    var s = 0.0
    for i in 0..n {
        let j = i * 5 % len(v)
        s = s + v[j] * v[j]
        s = s + w[j]
    }
    return s
}
let a = [1.0, 2.0, 3.0]
let b = [4.0, 5.0, 6.0, 7.0]
printf("%g %g\n", twice(a, b, 4), twice(b, b, 2))
// opt5_bce_passed -- DESIGN.md 5.8 T1 with F4: the first check of v[j] (j unknown) stays and
// proves the second (deleted); it proves nothing for w[j] (another array: kept). T2 leaves the
// `%` by a non-constant; T3 then shares the header and element loads (p1 is a private base).
""", r"""#sea 1
#target arm64-macos
#file opt5_bce_passed.sea
func .main main 0:1:1 0 0
slot s1 24 8
slot s2 24 8
slot s3 32 8
slot s4 32 8
slot s5 16 8
sa p1 s1
sa p2 s2
lf f3 #3FF0000000000000
stf f3 p2 - 0 0
lf f4 #4000000000000000
stf f4 p2 - 0 8
lf f5 #4008000000000000
stf f5 p2 - 0 16
li i6 24
mcopy p1 p2 i6
sa p7 s3
sa p8 s4
lf f9 #4010000000000000
stf f9 p8 - 0 0
lf f10 #4014000000000000
stf f10 p8 - 0 8
lf f11 #4018000000000000
stf f11 p8 - 0 16
lf f12 #401C000000000000
stf f12 p8 - 0 24
li i13 32
mcopy p7 p8 i13
li i14 3
li i15 1
li i16 1
li i17 1
rcall sea_arr_new_u 0:12 1 p18 4 i15 i16 i14 i17
ldp p19 p18 - 0 40
li i20 24
mcopy p19 p1 i20
li i21 4
li i22 1
li i23 1
li i24 1
rcall sea_arr_new_u 0:12 1 p25 4 i22 i23 i21 i24
ldp p26 p25 - 0 40
li i27 32
mcopy p26 p7 i27
li i28 4
call twice 1 f29 3 p18 p25 i28
release p18
release p25
li i30 4
li i31 1
li i32 1
li i33 1
rcall sea_arr_new_u 0:12 1 p34 4 i31 i32 i30 i33
ldp p35 p34 - 0 40
li i36 32
mcopy p35 p7 i36
li i37 4
li i38 1
li i39 1
li i40 1
rcall sea_arr_new_u 0:12 1 p41 4 i38 i39 i37 i40
ldp p42 p41 - 0 40
li i43 32
mcopy p42 p7 i43
li i44 2
call twice 1 f45 3 p34 p41 i44
release p34
release p41
sa p46 s5
stf f29 p46 - 0 0
stf f45 p46 - 0 8
la p47 d1
rcall sea_printf 0:12 0 2 p47 p46
ret 0
endfunc
func twice fn 0:1:1 3 p1 p2 i3 1 f
lf f4 #0000000000000000
li i5 0
li i6 1
rcount i7 i8 i5 i3 i6 0 0:3
if 1 i8
loop 2 i9 i5 i7 i6
li i10 5
imulc i11 i9 i10 0:4
ldi i12 p1 - 0 16
imodf i13 i11 i12 0:4
ldi i14 p1 - 0 16
chkb i13 i14 0 0:5
ldp p15 p1 - 0 40
ldf f16 p15 i13 8 0
ldi i17 p1 - 0 16
chkb i13 i17 0 0:5
ldp p18 p1 - 0 40
ldf f19 p18 i13 8 0
fmul f20 f16 f19
fadd f4 f4 f20
ldi i21 p2 - 0 16
chkb i13 i21 0 0:6
ldp p22 p2 - 0 40
ldf f23 p22 i13 8 0
fadd f4 f4 f23
endloop 2
endif 1
ret 1 f4
endfunc
fmt d1 4
fconv - - - g f
ftext %20
fconv - - - g f
ftext %0A
#end
""")
EVENTS['opt5_bce_passed'] = [
    ('T1', 'twice', 'del', 'chkb i13 i17 0 0:5'),
    ('T3', 'twice', 'load', 'ldi i14 p1 - 0 16', 'i12'),
    ('T3', 'twice', 'load', 'ldi i17 p1 - 0 16', 'i12'),
    ('T3', 'twice', 'load', 'ldp p18 p1 - 0 40', 'p15'),
    ('T3', 'twice', 'load', 'ldf f19 p15 i13 8 0', 'f16'),
]


# ---------------------------------------------------------------- opt5_bce_kept
# edges: over 1..n the ind is [1, i2 - 1], so i + 1 is [2, i2] (c + k = 0: iaddc -> iadd)
# and i - 1 is [0, i2 - 2] (isubc -> isub), but neither index is proved (i2 and <p1,rows> are not
# comparable): both checks kept; 0..=n's chkb kept. T3: the header and data loads of p1 shared.
# grow: u is a `ref` parameter: every extent is loaded through `ldp ... p1 - 0 0` (not an array
# register: no facts), so all three checks stay; T3 rule 2 shares the loads of the private
# location (p1, 0) (the third becomes `mov p17 p9`, p17 having two definitions) and the second
# extent load (i16 = i10).
CASES['opt5_bce_kept'] = (r"""fn edges(v: f64[], n: i64) -> f64 {
    var s = 0.0
    for i in 1..n {
        s = s + v[i + 1] - v[i - 1]
    }
    for i in 0..=n {
        s = s + v[i]
    }
    return s
}
fn grow(ref u: f64[], k: i64) -> f64 {
    var t = 0.0
    for i in 0..k {
        u[i] += 1.5
        t = t + u[i]
    }
    return t
}
var x: f64[] = [1.0, 2.0, 3.0, 4.0, 5.0]
printf("%g %g\n", edges(x, 3), edges(x, 2))
printf("%g %g\n", grow(ref x, 5), grow(ref x, 2))
// opt5_bce_kept -- DESIGN.md 5.8 T1: checks that stay: v[i + 1] and v[i - 1] over 1..n (the
// adds become wrapping, the checks stay), v[i] over 0..=n, and the repeated checks of a `ref`
// array's element in a compound assignment (rule 19: no facts on a loaded extent)
""", r"""#sea 1
#target arm64-macos
#file opt5_bce_kept.sea
func .main main 0:1:1 0 0
slot s1 40 8
slot s2 16 8
slot s3 8 8
slot s4 8 8
slot s5 16 8
sa p1 s1
lf f2 #3FF0000000000000
stf f2 p1 - 0 0
lf f3 #4000000000000000
stf f3 p1 - 0 8
lf f4 #4008000000000000
stf f4 p1 - 0 16
lf f5 #4010000000000000
stf f5 p1 - 0 24
lf f6 #4014000000000000
stf f6 p1 - 0 32
li i7 5
li i8 1
li i9 1
li i10 1
rcall sea_arr_new_u 0:19 1 p11 4 i8 i9 i7 i10
ldp p12 p11 - 0 40
li i13 40
mcopy p12 p1 i13
li i14 3
call edges 1 f15 2 p11 i14
li i16 2
call edges 1 f17 2 p11 i16
sa p18 s2
stf f15 p18 - 0 0
stf f17 p18 - 0 8
la p19 d1
rcall sea_printf 0:20 0 2 p19 p18
sa p20 s3
stp p11 p20 - 0 0
li i21 5
call grow 1 f22 2 p20 i21
ldp p11 p20 - 0 0
sa p23 s4
stp p11 p23 - 0 0
li i24 2
call grow 1 f25 2 p23 i24
ldp p11 p23 - 0 0
sa p26 s5
stf f22 p26 - 0 0
stf f25 p26 - 0 8
la p27 d2
rcall sea_printf 0:21 0 2 p27 p26
release p11
ret 0
endfunc
func edges fn 0:1:1 2 p1 i2 1 f
lf f3 #0000000000000000
li i4 1
li i5 1
rcount i6 i7 i4 i2 i5 0 0:3
if 1 i7
loop 2 i8 i4 i6 i5
li i9 1
iaddc i10 i8 i9 0:4
ldi i11 p1 - 0 16
chkb i10 i11 0 0:4
ldp p12 p1 - 0 40
ldf f13 p12 i10 8 0
fadd f14 f3 f13
li i15 1
isubc i16 i8 i15 0:4
ldi i17 p1 - 0 16
chkb i16 i17 0 0:4
ldp p18 p1 - 0 40
ldf f19 p18 i16 8 0
fsub f3 f14 f19
endloop 2
endif 1
li i20 0
li i21 1
rcount i22 i23 i20 i2 i21 1 0:6
if 3 i23
loop 4 i24 i20 i22 i21
ldi i25 p1 - 0 16
chkb i24 i25 0 0:7
ldp p26 p1 - 0 40
ldf f27 p26 i24 8 0
fadd f3 f3 f27
endloop 4
endif 3
ret 1 f3
endfunc
func grow fn 0:11:1 2 p1 i2 1 f
lf f3 #0000000000000000
li i4 0
li i5 1
rcount i6 i7 i4 i2 i5 0 0:13
if 1 i7
loop 2 i8 i4 i6 i5
ldp p9 p1 - 0 0
ldi i10 p9 - 0 16
chkb i8 i10 0 0:14
ldp p11 p9 - 0 40
ldf f12 p11 i8 8 0
lf f13 #3FF8000000000000
fadd f14 f12 f13
ldp p15 p1 - 0 0
ldi i16 p15 - 0 16
chkb i8 i16 0 0:14
ldp p17 p1 - 0 0
ldi i18 p17 - 0 0
li i19 1
icmp ne i20 i18 i19
if 3 i20
rcall sea_arr_unique 0:14 1 p21 1 p17
stp p21 p1 - 0 0
mov p17 p21
endif 3
ldp p22 p17 - 0 40
stf f14 p22 i8 8 0
ldp p23 p1 - 0 0
ldi i24 p23 - 0 16
chkb i8 i24 0 0:15
ldp p25 p23 - 0 40
ldf f26 p25 i8 8 0
fadd f3 f3 f26
endloop 2
endif 1
ret 1 f3
endfunc
fmt d1 4
fconv - - - g f
ftext %20
fconv - - - g f
ftext %0A
fmt d2 4
fconv - - - g f
ftext %20
fconv - - - g f
ftext %0A
#end
""")
EVENTS['opt5_bce_kept'] = [
    ('T1', 'edges', 'wrap', 'iaddc i10 i8 i9 0:4'),
    ('T1', 'edges', 'wrap', 'isubc i16 i8 i15 0:4'),
    ('T3', 'edges', 'load', 'ldi i17 p1 - 0 16', 'i11'),
    ('T3', 'edges', 'load', 'ldp p18 p1 - 0 40', 'p12'),
    ('T3', 'grow', 'load', 'ldp p15 p1 - 0 0', 'p9'),
    ('T3', 'grow', 'load', 'ldi i16 p9 - 0 16', 'i10'),
    ('T3', 'grow', 'load', 'ldp p17 p1 - 0 0', 'p9'),
]


# ---------------------------------------------------------------- opt5_bce_scope
# scope: in `if k >= 0` (L(i1) = 0) the guard of k..8 gives the ind [i1, 7] and the
# non-emptiness i1 <= 7 (U(i1) = 7): chkb i1 i15 and chkb i14 i19 deleted; after the guard's endif
# U(i1) is unknown again: chkb i1 i22 kept. In the do loop, `if j >= 5 { exit }` leaves j < 5 and
# `if j < 0 { exit }` leaves j >= 0: chkb i25 i33 deleted; after enddo j is unknown: chkb i25 i36
# kept. T3: in the loop body the second header load (i19 = i15) and data address (p20 = p16).
CASES['opt5_bce_scope'] = (r"""fn scope(k: i64) -> f64 {
    var v = zeros(8)
    var s = 0.0
    if k >= 0 {
        for i in k..8 {
            s = s + v[k] + v[i]
        }
        s = s + v[k]
    }
    var j = 0
    while j < 100 {
        j = j + 1
        if j >= 5 {
            break
        }
        if j < 0 {
            break
        }
        s = s + v[j]
    }
    s = s + v[j]
    return s
}
printf("%g %g\n", scope(2), scope(7))
// opt5_bce_scope -- DESIGN.md 5.8 F3 and F6: a guard's non-emptiness k <= 7 proves v[k] and v[i]
// inside its loop but not after its endif (kept); two break tests narrow j inside the do loop
// (deleted), and after the loop j is unknown again (kept)
""", r"""#sea 1
#target arm64-macos
#file opt5_bce_scope.sea
func .main main 0:1:1 0 0
slot s1 16 8
li i1 2
call scope 1 f2 1 i1
li i3 7
call scope 1 f4 1 i3
sa p5 s1
stf f2 p5 - 0 0
stf f4 p5 - 0 8
la p6 d1
rcall sea_printf 0:24 0 2 p6 p5
ret 0
endfunc
func scope fn 0:1:1 1 i1 1 f
li i2 8
li i3 1
li i4 1
li i5 1
rcall sea_arr_new 0:2 1 p6 4 i3 i4 i2 i5
lf f7 #0000000000000000
li i8 0
icmp ge i9 i1 i8
if 1 i9
li i10 8
li i11 1
rcount i12 i13 i1 i10 i11 0 0:5
if 2 i13
loop 3 i14 i1 i12 i11
ldi i15 p6 - 0 16
chkb i1 i15 0 0:6
ldp p16 p6 - 0 40
ldf f17 p16 i1 8 0
fadd f18 f7 f17
ldi i19 p6 - 0 16
chkb i14 i19 0 0:6
ldp p20 p6 - 0 40
ldf f21 p20 i14 8 0
fadd f7 f18 f21
endloop 3
endif 2
ldi i22 p6 - 0 16
chkb i1 i22 0 0:8
ldp p23 p6 - 0 40
ldf f24 p23 i1 8 0
fadd f7 f7 f24
endif 1
li i25 0
do 4
li i26 100
icmp lt i27 i25 i26
ifz 5 i27
exit 4
endif 5
li i28 1
iaddc i25 i25 i28 0:12
li i29 5
icmp ge i30 i25 i29
if 6 i30
exit 4
endif 6
li i31 0
icmp lt i32 i25 i31
if 7 i32
exit 4
endif 7
ldi i33 p6 - 0 16
chkb i25 i33 0 0:19
ldp p34 p6 - 0 40
ldf f35 p34 i25 8 0
fadd f7 f7 f35
enddo 4
ldi i36 p6 - 0 16
chkb i25 i36 0 0:21
ldp p37 p6 - 0 40
ldf f38 p37 i25 8 0
fadd f7 f7 f38
release p6
ret 1 f7
endfunc
fmt d1 4
fconv - - - g f
ftext %20
fconv - - - g f
ftext %0A
#end
""")
EVENTS['opt5_bce_scope'] = [
    ('T1', 'scope', 'del', 'chkb i1 i15 0 0:6'),
    ('T1', 'scope', 'del', 'chkb i14 i19 0 0:6'),
    ('T1', 'scope', 'del', 'chkb i25 i33 0 0:19'),
    ('T3', 'scope', 'load', 'ldi i19 p6 - 0 16', 'i15'),
    ('T3', 'scope', 'load', 'ldp p20 p6 - 0 40', 'p16'),
]


# ---------------------------------------------------------------- opt5_bce_eq
# eqs: `k == 5` (F5 eq on the symbol i1 with a constant) gives L(i1) = U(i1) = 5 in if 1; the
# extent i16 of v = zeros(8), loaded there (a symbol), has L = U = 8 (F2, L-au): chkb i1 i16
# deleted. The missing else part has the negation `k != 5`, which narrows nothing for a symbol, so
# after endif 1 L(i1), U(i1) are unknown: chkb i1 i19 kept. The else part of `k != 5` (if 2) has
# `k == 5`: chkb i1 i25 deleted. `k != 5 || ...` is `icmp ne i29`, `ifz 3 i29`: the ifz part has
# the negation eq: chkb i1 i30 deleted. In the loop j = i42 (imodf: unknown; T2 then makes it
# `iand` by 7): `j < 0` and `j > 7` exits leave [0, 7]; `if j == 7 { exit }` leaves the missing
# else part's `j != 7`, which lowers j.hi = 7 to 6: chkb i42 i49 against [7, 7] deleted.
CASES['opt5_bce_eq'] = (r"""fn eqs(k: i64, n: i64) -> f64 {
    let v = zeros(8)
    let w = zeros(7)
    var s = 0.0
    if k == 5 {
        s = s + v[k]
    }
    s = s + v[k]
    if k != 5 {
        s = s + 1.0
    } else {
        s = s + v[k]
    }
    let q = k != 5 || v[k] > 0.0
    if q {
        s = s + 2.0
    }
    for i in 0..n {
        let j = i % 8
        if j < 0 {
            break
        }
        if j > 7 {
            break
        }
        if j == 7 {
            break
        }
        s = s + w[j]
    }
    return s
}
printf("%g %g\n", eqs(5, 3), eqs(2, 9))
// opt5_bce_eq -- DESIGN.md 5.8 F5 with eq and ne and their negations: v[k] under `k == 5`
// (deleted); after that if the missing else part's `k != 5` gives a symbol nothing (kept); the
// else part of `k != 5` gives k == 5 (deleted); `k != 5 || v[k] > 0.0` evaluates v[k] in an ifz
// part, where k == 5 (deleted); j in [0, 7] after two break tests, then `if j == 7 { break }`
// leaves j != 7, so j <= 6 (w of 7 elements: deleted)
""", r"""#sea 1
#target arm64-macos
#file opt5_bce_eq.sea
func .main main 0:1:1 0 0
slot s1 16 8
li i1 5
li i2 3
call eqs 1 f3 2 i1 i2
li i4 2
li i5 9
call eqs 1 f6 2 i4 i5
sa p7 s1
stf f3 p7 - 0 0
stf f6 p7 - 0 8
la p8 d1
rcall sea_printf 0:33 0 2 p8 p7
ret 0
endfunc
func eqs fn 0:1:1 2 i1 i2 1 f
li i3 8
li i4 1
li i5 1
li i6 1
rcall sea_arr_new 0:2 1 p7 4 i4 i5 i3 i6
li i8 7
li i9 1
li i10 1
li i11 1
rcall sea_arr_new 0:3 1 p12 4 i9 i10 i8 i11
lf f13 #0000000000000000
li i14 5
icmp eq i15 i1 i14
if 1 i15
ldi i16 p7 - 0 16
chkb i1 i16 0 0:6
ldp p17 p7 - 0 40
ldf f18 p17 i1 8 0
fadd f13 f13 f18
endif 1
ldi i19 p7 - 0 16
chkb i1 i19 0 0:8
ldp p20 p7 - 0 40
ldf f21 p20 i1 8 0
fadd f13 f13 f21
li i22 5
icmp ne i23 i1 i22
if 2 i23
lf f24 #3FF0000000000000
fadd f13 f13 f24
else 2
ldi i25 p7 - 0 16
chkb i1 i25 0 0:12
ldp p26 p7 - 0 40
ldf f27 p26 i1 8 0
fadd f13 f13 f27
endif 2
li i28 5
icmp ne i29 i1 i28
ifz 3 i29
ldi i30 p7 - 0 16
chkb i1 i30 0 0:14
ldp p31 p7 - 0 40
ldf f32 p31 i1 8 0
lf f33 #0000000000000000
fcmp gt i29 f32 f33
endif 3
mov i34 i29
if 4 i34
lf f35 #4000000000000000
fadd f13 f13 f35
endif 4
li i36 0
li i37 1
rcount i38 i39 i36 i2 i37 0 0:18
if 5 i39
loop 6 i40 i36 i38 i37
li i41 8
imodf i42 i40 i41 0:19
li i43 0
icmp lt i44 i42 i43
if 7 i44
exit 6
endif 7
li i45 7
icmp gt i46 i42 i45
if 8 i46
exit 6
endif 8
li i47 7
icmp eq i48 i42 i47
if 9 i48
exit 6
endif 9
ldi i49 p12 - 0 16
chkb i42 i49 0 0:29
ldp p50 p12 - 0 40
ldf f51 p50 i42 8 0
fadd f13 f13 f51
endloop 6
endif 5
release p12
release p7
ret 1 f13
endfunc
fmt d1 4
fconv - - - g f
ftext %20
fconv - - - g f
ftext %0A
#end
""")
EVENTS['opt5_bce_eq'] = [
    ('T1', 'eqs', 'del', 'chkb i1 i16 0 0:6'),
    ('T1', 'eqs', 'del', 'chkb i1 i25 0 0:12'),
    ('T1', 'eqs', 'del', 'chkb i1 i30 0 0:14'),
    ('T1', 'eqs', 'del', 'chkb i42 i49 0 0:29'),
    ('T2', 'eqs', 'imodf i42 i40 i41 0:19'),
]


# ---------------------------------------------------------------- opt5_ovf
# ovf: over 0..n (ind [0, i1 - 1]): i + 1 (iaddc -> iadd), -i (inegc -> ineg, lower bound 0);
# (i + 1) * (-i) has a symbolic bound (imulc kept). Over 0..10 ([0, 9]): i * 3 (constant bounds,
# products within 2^52: imul), i - 1 (isub). Over 0..=n: i + 1 is [1, i1 + 1], U(i1) unknown: kept.
# Over n..=2^63-1: the upper bound 2^63 - 1 is outside -2^52 ... 2^52 (unknown): i + 1 kept. Under
# `n < 100` (U(i1) = 99): n + 1 (iadd). n * 2 and every update of s keep their checks.
CASES['opt5_ovf'] = (r"""fn ovf(n: i64) -> i64 {
    var s = 0
    for i in 0..n {
        s = s + (i + 1) * (-i)
    }
    for i in 0..10 {
        s = s + i * 3 - (i - 1)
    }
    for i in 0..=n {
        s = s + (i + 1)
    }
    for i in n..=9223372036854775807 {
        s = s + (i + 1)
        break
    }
    if n < 100 {
        s = s + (n + 1)
    }
    return s + n * 2
}
printf("%d %d\n", ovf(4), ovf(7))
// opt5_ovf -- DESIGN.md 5.8 T1: iaddc, inegc, isubc and imulc that become wrapping (i + 1 and
// -i over 0..n, i * 3 and i - 1 over 0..10, n + 1 under n < 100) and those that stay (a product
// with a symbolic bound, i + 1 over 0..=n and up to 2^63 - 1, n * 2, the sums of s)
""", r"""#sea 1
#target arm64-macos
#file opt5_ovf.sea
func .main main 0:1:1 0 0
slot s1 16 8
li i1 4
call ovf 1 i2 1 i1
li i3 7
call ovf 1 i4 1 i3
sa p5 s1
sti i2 p5 - 0 0
sti i4 p5 - 0 8
la p6 d1
rcall sea_printf 0:21 0 2 p6 p5
ret 0
endfunc
func ovf fn 0:1:1 1 i1 1 i
li i2 0
li i3 0
li i4 1
rcount i5 i6 i3 i1 i4 0 0:3
if 1 i6
loop 2 i7 i3 i5 i4
li i8 1
iaddc i9 i7 i8 0:4
inegc i10 i7 0:4
imulc i11 i9 i10 0:4
iaddc i2 i2 i11 0:4
endloop 2
endif 1
li i12 0
li i13 10
li i14 1
rcount i15 i16 i12 i13 i14 0 0:6
if 3 i16
loop 4 i17 i12 i15 i14
li i18 3
imulc i19 i17 i18 0:7
iaddc i20 i2 i19 0:7
li i21 1
isubc i22 i17 i21 0:7
isubc i2 i20 i22 0:7
endloop 4
endif 3
li i23 0
li i24 1
rcount i25 i26 i23 i1 i24 1 0:9
if 5 i26
loop 6 i27 i23 i25 i24
li i28 1
iaddc i29 i27 i28 0:10
iaddc i2 i2 i29 0:10
endloop 6
endif 5
li i30 #7FFFFFFFFFFFFFFF
li i31 1
rcount i32 i33 i1 i30 i31 1 0:12
if 7 i33
loop 8 i34 i1 i32 i31
li i35 1
iaddc i36 i34 i35 0:13
iaddc i2 i2 i36 0:13
exit 8
endloop 8
endif 7
li i37 100
icmp lt i38 i1 i37
if 9 i38
li i39 1
iaddc i40 i1 i39 0:17
iaddc i2 i2 i40 0:17
endif 9
li i41 2
imulc i42 i1 i41 0:19
iaddc i43 i2 i42 0:19
ret 1 i43
endfunc
fmt d1 4
fconv - - - d i
ftext %20
fconv - - - d i
ftext %0A
#end
""")
EVENTS['opt5_ovf'] = [
    ('T1', 'ovf', 'wrap', 'iaddc i9 i7 i8 0:4'),
    ('T1', 'ovf', 'wrap', 'inegc i10 i7 0:4'),
    ('T1', 'ovf', 'wrap', 'imulc i19 i17 i18 0:7'),
    ('T1', 'ovf', 'wrap', 'isubc i22 i17 i21 0:7'),
    ('T1', 'ovf', 'wrap', 'iaddc i40 i1 i39 0:17'),
]


# ---------------------------------------------------------------- opt5_ovf_const
# big: in the loop, under `k >= 0`, `k < 10` (L(i1) = 0, U(i1) = 9): m + k with m = 80000000000
# (#00000012A05F2000), 2^52 (#0010000000000000) and -2^52 (#FFF0000000000000), constants within
# -2^52 ... 2^52, pass T1's test (upper side U(i1) + v <= 2^63 - 1, lower side c + v >= 0 or
# L(i1) + v >= -2^63): iaddc -> iadd. 2^52 + 1 and -2^52 - 1 lie outside, so their interval is
# unknown (L-bb 6): those adds keep their checks, and so does every update of s.
CASES['opt5_ovf_const'] = (r"""fn big(k: i64, n: i64) -> i64 {
    let m = 80000000000
    let p = 4503599627370496
    let q = 4503599627370497
    let r = -4503599627370496
    let t = -4503599627370497
    var s = 0
    for i in 0..n {
        if k >= 0 {
            if k < 10 {
                s = s + (m + k)
                s = s + (p + k)
                s = s + (q + k)
                s = s + (r + k)
                s = s + (t + k)
            }
        }
    }
    return s
}
printf("%d %d\n", big(3, 1), big(9, 2))
// opt5_ovf_const -- DESIGN.md 5.8 T1 and L-bb reading 6: under 0 <= k < 10 (U(k) = 9),
// m + k becomes iadd for the constants 80000000000, 2^52 and -2^52 (each within -2^52 ... 2^52:
// an interval [v, v]); 2^52 + 1 and -2^52 - 1 have an unknown interval: their adds stay checked
""", r"""#sea 1
#target arm64-macos
#file opt5_ovf_const.sea
func .main main 0:1:1 0 0
slot s1 16 8
li i1 3
li i2 1
call big 1 i3 2 i1 i2
li i4 9
li i5 2
call big 1 i6 2 i4 i5
sa p7 s1
sti i3 p7 - 0 0
sti i6 p7 - 0 8
la p8 d1
rcall sea_printf 0:21 0 2 p8 p7
ret 0
endfunc
func big fn 0:1:1 2 i1 i2 1 i
li i3 #00000012A05F2000
li i4 #0010000000000000
li i5 #0010000000000001
li i6 #FFF0000000000000
li i7 #FFEFFFFFFFFFFFFF
li i8 0
li i9 0
li i10 1
rcount i11 i12 i9 i2 i10 0 0:8
if 1 i12
loop 2 i13 i9 i11 i10
li i14 0
icmp ge i15 i1 i14
if 3 i15
li i16 10
icmp lt i17 i1 i16
if 4 i17
iaddc i18 i3 i1 0:11
iaddc i8 i8 i18 0:11
iaddc i19 i4 i1 0:12
iaddc i8 i8 i19 0:12
iaddc i20 i5 i1 0:13
iaddc i8 i8 i20 0:13
iaddc i21 i6 i1 0:14
iaddc i8 i8 i21 0:14
iaddc i22 i7 i1 0:15
iaddc i8 i8 i22 0:15
endif 4
endif 3
endloop 2
endif 1
ret 1 i8
endfunc
fmt d1 4
fconv - - - d i
ftext %20
fconv - - - d i
ftext %0A
#end
""")
EVENTS['opt5_ovf_const'] = [
    ('T1', 'big', 'wrap', 'iaddc i18 i3 i1 0:11'),
    ('T1', 'big', 'wrap', 'iaddc i19 i4 i1 0:12'),
    ('T1', 'big', 'wrap', 'iaddc i21 i6 i1 0:14'),
]


# ---------------------------------------------------------------- opt5_div
# divs: % 1 -> li d 0; idiv by 1 -> mov d a; % 8 -> li 7, iand; idiv by 8 -> li 3, isar; 10
# (M = #6666666666666667 < 2^63, s = 2), 3 (M = #5555555555555556, s = 0: no isar) and
# 2147483647 (M = #8000000100000003 >= 2^63: the iadd; s = 30): the sequence for % then idiv, whose
# li M, imulh, li s, isar, li 63, isar, isub, imul, isub, icmp T3 shares with the % sequence's in
# the region (and every `li 0`, `li 1`, `li 3`, `li 2` with the first one of the region). -3, 0
# (in its own if), b and i + 1 (that add made wrapping by T1) keep idivf/imodf. T10: the dead
# `li 8` divisor.
CASES['opt5_div'] = (r"""fn divs(a: i64, b: i64) -> i64 {
    var s = 0
    for i in 0..b {
        s = s + a % 1 + idiv(a, 1)
        s = s + a % 8 + idiv(a, 8)
        s = s + a % 10 + idiv(a, 10)
        s = s + a % 3 + idiv(a, 3)
        s = s + a % 2147483647 + idiv(a, 2147483647)
        s = s + a % -3 + idiv(a, -3)
        s = s + a % b + idiv(a, i + 1)
        if b < 0 {
            s = s + a % 0 + idiv(a, 0)
        }
    }
    return s
}
printf("%d %d\n", divs(-123456789, 2), divs(987654321, 3))
// opt5_div -- DESIGN.md 5.8 T2: % and idiv by 1, by 8 (2^3), by 10 (M < 2^63, s = 2), by 3
// (s = 0: no isar) and by 2147483647 (M >= 2^63: the iadd); by -3, by 0, by b and by i + 1
// unchanged; T3 then shares the sequences' common instructions in the region
""", r"""#sea 1
#target arm64-macos
#file opt5_div.sea
func .main main 0:1:1 0 0
slot s1 16 8
li i1 -123456789
li i2 2
call divs 1 i3 2 i1 i2
li i4 987654321
li i5 3
call divs 1 i6 2 i4 i5
sa p7 s1
sti i3 p7 - 0 0
sti i6 p7 - 0 8
la p8 d1
rcall sea_printf 0:17 0 2 p8 p7
ret 0
endfunc
func divs fn 0:1:1 2 i1 i2 1 i
li i3 0
li i4 0
li i5 1
rcount i6 i7 i4 i2 i5 0 0:3
if 1 i7
loop 2 i8 i4 i6 i5
li i9 1
imodf i10 i1 i9 0:4
iaddc i11 i3 i10 0:4
li i12 1
idivf i13 i1 i12 0:4
iaddc i3 i11 i13 0:4
li i14 8
imodf i15 i1 i14 0:5
iaddc i16 i3 i15 0:5
li i17 8
idivf i18 i1 i17 0:5
iaddc i3 i16 i18 0:5
li i19 10
imodf i20 i1 i19 0:6
iaddc i21 i3 i20 0:6
li i22 10
idivf i23 i1 i22 0:6
iaddc i3 i21 i23 0:6
li i24 3
imodf i25 i1 i24 0:7
iaddc i26 i3 i25 0:7
li i27 3
idivf i28 i1 i27 0:7
iaddc i3 i26 i28 0:7
li i29 #000000007FFFFFFF
imodf i30 i1 i29 0:8
iaddc i31 i3 i30 0:8
li i32 #000000007FFFFFFF
idivf i33 i1 i32 0:8
iaddc i3 i31 i33 0:8
li i34 -3
imodf i35 i1 i34 0:9
iaddc i36 i3 i35 0:9
li i37 -3
idivf i38 i1 i37 0:9
iaddc i3 i36 i38 0:9
imodf i39 i1 i2 0:10
iaddc i40 i3 i39 0:10
li i41 1
iaddc i42 i8 i41 0:10
idivf i43 i1 i42 0:10
iaddc i3 i40 i43 0:10
li i44 0
icmp lt i45 i2 i44
if 3 i45
li i46 0
imodf i47 i1 i46 0:12
iaddc i48 i3 i47 0:12
li i49 0
idivf i50 i1 i49 0:12
iaddc i3 i48 i50 0:12
endif 3
endloop 2
endif 1
ret 1 i3
endfunc
fmt d1 4
fconv - - - d i
ftext %20
fconv - - - d i
ftext %0A
#end
""")
EVENTS['opt5_div'] = [
    ('T1', 'divs', 'wrap', 'iaddc i42 i8 i41 0:10'),
    ('T2', 'divs', 'imodf i10 i1 i9 0:4'),
    ('T2', 'divs', 'idivf i13 i1 i12 0:4'),
    ('T2', 'divs', 'imodf i15 i1 i14 0:5'),
    ('T2', 'divs', 'idivf i18 i1 i17 0:5'),
    ('T2', 'divs', 'imodf i20 i1 i19 0:6'),
    ('T2', 'divs', 'idivf i23 i1 i22 0:6'),
    ('T2', 'divs', 'imodf i25 i1 i24 0:7'),
    ('T2', 'divs', 'idivf i28 i1 i27 0:7'),
    ('T2', 'divs', 'imodf i30 i1 i29 0:8'),
    ('T2', 'divs', 'idivf i33 i1 i32 0:8'),
]


# ---------------------------------------------------------------- opt5_fdiv
# fdivs: 4.0 -> lf #3FD0000000000000 (0.25), fmul; 0.5 -> 2.0; -2.0 -> -0.5; 2^1023 -> the
# subnormal #0008000000000000; 2^-1022 -> 2^1022 (#7FD0000000000000), each lf placed just before
# its fmul; T10 deletes the divisors' lf. 3.0 (mantissa not 0), 2^-1074 (exponent field 0) and d
# (two definitions) unchanged. T3: the later `lf 2.0` of d * 2.0 is the reciprocal of 0.5.
CASES['opt5_fdiv'] = (r"""fn fdivs(x: f64, n: i64) -> f64 {
    var s = 0.0
    var d = 2.0
    for i in 0..n {
        s = s + x / 4.0 + x / 0.5 + x / -2.0
        s = s + x / 8.98846567431158e307 + x / 2.2250738585072014e-308 + x / 3.0
        s = s + x / 4.9406564584124654e-324 + x / d
        d = d * 2.0
    }
    return s
}
printf("%g %g\n", fdivs(3.0, 2), fdivs(-1.5, 3))
// opt5_fdiv -- DESIGN.md 5.8 T2: f64 division by 4.0, 0.5, -2.0, 2^1023 (reciprocal the
// subnormal 2^-1023) and 2^-1022 becomes a multiplication; by 3.0, by the subnormal 2^-1074 and
// by a variable it stays
""", r"""#sea 1
#target arm64-macos
#file opt5_fdiv.sea
func .main main 0:1:1 0 0
slot s1 16 8
lf f1 #4008000000000000
li i2 2
call fdivs 1 f3 2 f1 i2
lf f4 #BFF8000000000000
li i5 3
call fdivs 1 f6 2 f4 i5
sa p7 s1
stf f3 p7 - 0 0
stf f6 p7 - 0 8
la p8 d1
rcall sea_printf 0:12 0 2 p8 p7
ret 0
endfunc
func fdivs fn 0:1:1 2 f1 i2 1 f
lf f3 #0000000000000000
lf f4 #4000000000000000
li i5 0
li i6 1
rcount i7 i8 i5 i2 i6 0 0:4
if 1 i8
loop 2 i9 i5 i7 i6
lf f10 #4010000000000000
fdiv f11 f1 f10
fadd f12 f3 f11
lf f13 #3FE0000000000000
fdiv f14 f1 f13
fadd f15 f12 f14
lf f16 #C000000000000000
fdiv f17 f1 f16
fadd f3 f15 f17
lf f18 #7FE0000000000000
fdiv f19 f1 f18
fadd f20 f3 f19
lf f21 #0010000000000000
fdiv f22 f1 f21
fadd f23 f20 f22
lf f24 #4008000000000000
fdiv f25 f1 f24
fadd f3 f23 f25
lf f26 #0000000000000001
fdiv f27 f1 f26
fadd f28 f3 f27
fdiv f29 f1 f4
fadd f3 f28 f29
lf f30 #4000000000000000
fmul f4 f4 f30
endloop 2
endif 1
ret 1 f3
endfunc
fmt d1 4
fconv - - - g f
ftext %20
fconv - - - g f
ftext %0A
#end
""")
EVENTS['opt5_fdiv'] = [
    ('T2', 'fdivs', 'fdiv f11 f1 f10'),
    ('T2', 'fdivs', 'fdiv f14 f1 f13'),
    ('T2', 'fdivs', 'fdiv f17 f1 f16'),
    ('T2', 'fdivs', 'fdiv f19 f1 f18'),
    ('T2', 'fdivs', 'fdiv f22 f1 f21'),
]


# ---------------------------------------------------------------- opt5_vn
# vn: the second a * b (imulc i14) is i12, then (a * b + i) (iaddc i15, its operands rewritten)
# is i13, so the product reads i13 twice; x * x (f18) is f17; c = a * b (i22) is i12. i + a
# (i25) equals i23's instruction but i23 is written between (e = e + 1): not shared.
CASES['opt5_vn'] = (r"""fn vn(a: i64, b: i64, x: f64, n: i64) -> f64 {
    var s = 0.0
    var t = 0
    for i in 0..n {
        t = t + (a * b + i) * (a * b + i)
        s = s + x * x / (x * x + 1.0)
        let c = a * b
        var e = i + a
        e = e + 1
        t = t + (i + a) + e + c
    }
    return s + t
}
printf("%g %g\n", vn(3, 4, 0.5, 2), vn(-1, 7, 2.0, 3))
// opt5_vn -- DESIGN.md 5.8 T3 rule 1 and copy propagation: a * b three times, (a * b + i) twice
// (a chain), x * x twice; i + a not shared when its first result e is written between
""", r"""#sea 1
#target arm64-macos
#file opt5_vn.sea
func .main main 0:1:1 0 0
slot s1 16 8
li i1 3
li i2 4
lf f3 #3FE0000000000000
li i4 2
call vn 1 f5 4 i1 i2 f3 i4
li i6 -1
li i7 7
lf f8 #4000000000000000
li i9 3
call vn 1 f10 4 i6 i7 f8 i9
sa p11 s1
stf f5 p11 - 0 0
stf f10 p11 - 0 8
la p12 d1
rcall sea_printf 0:14 0 2 p12 p11
ret 0
endfunc
func vn fn 0:1:1 4 i1 i2 f3 i4 1 f
lf f5 #0000000000000000
li i6 0
li i7 0
li i8 1
rcount i9 i10 i7 i4 i8 0 0:4
if 1 i10
loop 2 i11 i7 i9 i8
imulc i12 i1 i2 0:5
iaddc i13 i12 i11 0:5
imulc i14 i1 i2 0:5
iaddc i15 i14 i11 0:5
imulc i16 i13 i15 0:5
iaddc i6 i6 i16 0:5
fmul f17 f3 f3
fmul f18 f3 f3
lf f19 #3FF0000000000000
fadd f20 f18 f19
fdiv f21 f17 f20
fadd f5 f5 f21
imulc i22 i1 i2 0:7
iaddc i23 i11 i1 0:8
li i24 1
iaddc i23 i23 i24 0:9
iaddc i25 i11 i1 0:10
iaddc i26 i6 i25 0:10
iaddc i27 i26 i23 0:10
iaddc i6 i27 i22 0:10
endloop 2
endif 1
itof f28 i6
fadd f29 f5 f28
ret 1 f29
endfunc
fmt d1 4
fconv - - - g f
ftext %20
fconv - - - g f
ftext %0A
#end
""")
EVENTS['opt5_vn'] = [
]


# ---------------------------------------------------------------- opt5_rle
# rle: len(v) twice and v[0]'s extent: the private location (p1, 16) loaded once (i13, i17 and
# after the call i33 are i10); m = (p2, 0) private: the loads after `sti i16 p2` read i16 (i17,
# i21, and i24 after the printf: a call does not change a private location); v[0]'s data address
# (p34 = p18, private) is shared but its element load after the printf is not (an rcall may
# change it). Both checks of v[0] stay (0 against <p1,rows> - 1 is not proved).
CASES['opt5_rle'] = (r"""fn rle(v: f64[], ref m: i64, n: i64) -> f64 {
    var s = 0.0
    for i in 0..n {
        s = s + len(v) + len(v) + v[0]
        m = m + i
        s = s + m * 2
        printf("%d\n", m)
        s = s + m + v[0]
    }
    return s
}
var k = 1
let w = [1.0, 2.0]
printf("%g\n", rle(w, ref k, 2))
printf("%g\n", rle(w, ref k, 3))
// opt5_rle -- DESIGN.md 5.8 T3 rule 2: len(v) loaded once; m (a `ref` parameter, a private
// location) read back from its store and across the printf call; v[0]'s element load is not
// shared across the call (it may change it), its header and data address are
""", r"""#sea 1
#target arm64-macos
#file opt5_rle.sea
func .main main 0:1:1 0 0
slot s1 16 8
slot s2 16 8
slot s3 8 8
slot s4 8 8
slot s5 8 8
slot s6 8 8
li i1 1
sa p2 s1
sa p3 s2
lf f4 #3FF0000000000000
stf f4 p3 - 0 0
lf f5 #4000000000000000
stf f5 p3 - 0 8
li i6 16
mcopy p2 p3 i6
li i7 2
li i8 1
li i9 1
li i10 1
rcall sea_arr_new_u 0:14 1 p11 4 i8 i9 i7 i10
ldp p12 p11 - 0 40
li i13 16
mcopy p12 p2 i13
sa p14 s3
sti i1 p14 - 0 0
li i15 2
call rle 1 f16 3 p11 p14 i15
ldi i1 p14 - 0 0
release p11
sa p17 s4
stf f16 p17 - 0 0
la p18 d1
rcall sea_printf 0:14 0 2 p18 p17
li i19 2
li i20 1
li i21 1
li i22 1
rcall sea_arr_new_u 0:15 1 p23 4 i20 i21 i19 i22
ldp p24 p23 - 0 40
li i25 16
mcopy p24 p2 i25
sa p26 s5
sti i1 p26 - 0 0
li i27 3
call rle 1 f28 3 p23 p26 i27
ldi i1 p26 - 0 0
release p23
sa p29 s6
stf f28 p29 - 0 0
la p30 d2
rcall sea_printf 0:15 0 2 p30 p29
ret 0
endfunc
func rle fn 0:1:1 3 p1 p2 i3 1 f
slot s1 8 8
lf f4 #0000000000000000
li i5 0
li i6 1
rcount i7 i8 i5 i3 i6 0 0:3
if 1 i8
loop 2 i9 i5 i7 i6
ldi i10 p1 - 0 16
itof f11 i10
fadd f12 f4 f11
ldi i13 p1 - 0 16
itof f14 i13
fadd f15 f12 f14
li i16 0
ldi i17 p1 - 0 16
chkb i16 i17 0 0:4
ldp p18 p1 - 0 40
ldf f19 p18 i16 8 0
fadd f4 f15 f19
ldi i20 p2 - 0 0
iaddc i21 i20 i9 0:5
sti i21 p2 - 0 0
ldi i22 p2 - 0 0
li i23 2
imulc i24 i22 i23 0:6
itof f25 i24
fadd f4 f4 f25
ldi i26 p2 - 0 0
sa p27 s1
sti i26 p27 - 0 0
la p28 d3
rcall sea_printf 0:7 0 2 p28 p27
ldi i29 p2 - 0 0
itof f30 i29
fadd f31 f4 f30
li i32 0
ldi i33 p1 - 0 16
chkb i32 i33 0 0:8
ldp p34 p1 - 0 40
ldf f35 p34 i32 8 0
fadd f4 f31 f35
endloop 2
endif 1
ret 1 f4
endfunc
fmt d1 2
fconv - - - g f
ftext %0A
fmt d2 2
fconv - - - g f
ftext %0A
fmt d3 2
fconv - - - d i
ftext %0A
#end
""")
EVENTS['opt5_rle'] = [
    ('T3', 'rle', 'load', 'ldi i13 p1 - 0 16', 'i10'),
    ('T3', 'rle', 'load', 'ldi i17 p1 - 0 16', 'i10'),
    ('T3', 'rle', 'load', 'ldi i22 p2 - 0 0', 'i21'),
    ('T3', 'rle', 'load', 'ldi i26 p2 - 0 0', 'i21'),
    ('T3', 'rle', 'load', 'ldi i29 p2 - 0 0', 'i21'),
    ('T3', 'rle', 'load', 'ldi i33 p1 - 0 16', 'i10'),
    ('T3', 'rle', 'load', 'ldp p34 p1 - 0 40', 'p18'),
]


# ---------------------------------------------------------------- opt5_ifconv
# sel: `if a < b { a } else { b }` -> isel; `if x > y ...` -> fsel; `if i > a { w = y }` ->
# fsel w c y w; `i > 2 || p` (ifz on the result, one mov of p) -> isel r c r p; the ifx whose else
# arm is an lf, and the two ifs whose parts are an add, stay.
CASES['opt5_ifconv'] = (r"""fn sel(a: i64, b: i64, x: f64, y: f64, n: i64) -> f64 {
    var s = 0.0
    var t = 0
    let p = a > 0
    for i in 0..n {
        let m = if a < b { a } else { b }
        let z = if x > y { x } else { y }
        var w = x
        if i > a {
            w = y
        }
        let q = i > 2 || p
        let r = if x < y { x } else { 1.5 }
        if i < b {
            t = t + 1
        }
        s = s + z + w + r
        t = t + m
        if q {
            t = t + 1
        }
    }
    return s + t
}
printf("%g %g\n", sel(1, 2, 0.5, 1.5, 3), sel(4, 3, -1.0, -2.0, 2))
// opt5_ifconv -- DESIGN.md 5.8 T4: an ifx of two locals (i64 and f64: isel, fsel), an `if` with
// one mov (fsel), `||` with a local (ifz: isel); an arm that is not one mov (lf) and two ifs
// whose part is an add stay
""", r"""#sea 1
#target arm64-macos
#file opt5_ifconv.sea
func .main main 0:1:1 0 0
slot s1 16 8
li i1 1
li i2 2
lf f3 #3FE0000000000000
lf f4 #3FF8000000000000
li i5 3
call sel 1 f6 5 i1 i2 f3 f4 i5
li i7 4
li i8 3
lf f9 #BFF0000000000000
lf f10 #C000000000000000
li i11 2
call sel 1 f12 5 i7 i8 f9 f10 i11
sa p13 s1
stf f6 p13 - 0 0
stf f12 p13 - 0 8
la p14 d1
rcall sea_printf 0:25 0 2 p14 p13
ret 0
endfunc
func sel fn 0:1:1 5 i1 i2 f3 f4 i5 1 f
lf f6 #0000000000000000
li i7 0
li i8 0
icmp gt i9 i1 i8
li i10 0
li i11 1
rcount i12 i13 i10 i5 i11 0 0:5
if 1 i13
loop 2 i14 i10 i12 i11
icmp lt i15 i1 i2
if 3 i15
mov i16 i1
else 3
mov i16 i2
endif 3
mov i17 i16
fcmp gt i18 f3 f4
if 4 i18
mov f19 f3
else 4
mov f19 f4
endif 4
mov f20 f19
mov f21 f3
icmp gt i22 i14 i1
if 5 i22
mov f21 f4
endif 5
li i23 2
icmp gt i24 i14 i23
ifz 6 i24
mov i24 i9
endif 6
mov i25 i24
fcmp lt i26 f3 f4
if 7 i26
mov f27 f3
else 7
lf f27 #3FF8000000000000
endif 7
mov f28 f27
icmp lt i29 i14 i2
if 8 i29
li i30 1
iaddc i7 i7 i30 0:15
endif 8
fadd f31 f6 f20
fadd f32 f31 f21
fadd f6 f32 f28
iaddc i7 i7 i17 0:18
if 9 i25
li i33 1
iaddc i7 i7 i33 0:20
endif 9
endloop 2
endif 1
itof f34 i7
fadd f35 f6 f34
ret 1 f35
endfunc
fmt d1 4
fconv - - - g f
ftext %20
fconv - - - g f
ftext %0A
#end
""")
EVENTS['opt5_ifconv'] = [
    ('T4', 'sel', 'if 3 i15'),
    ('T4', 'sel', 'if 4 i18'),
    ('T4', 'sel', 'if 5 i22'),
    ('T4', 'sel', 'ifz 6 i24'),
]


# ---------------------------------------------------------------- opt5_clean
# clean: x * 2.0 + v[0] unused: fadd, fmul, the lf, the element load and the data address
# deleted (the chkb and the extent load stay); a + 1 unused but checked (iaddc stays); `k = k`
# (mov i10 i10) deleted, then k's `mov i10 i2`; `if a > i { z = x + 1.0 }`: fadd and lf deleted,
# then the empty if and its icmp; `retain p8` / `release p8` before `ret 1 p8`. s (f9) stays: its
# add reads it.
CASES['opt5_clean'] = (r"""fn clean(v: f64[], a: i64, x: f64, n: i64) -> f64[] {
    var u = zeros(n)
    var s = x
    var k = a
    for i in 0..n {
        let unused = x * 2.0 + v[0]
        let fat = a + 1
        k = k
        if a > i {
            let z = x + 1.0
        }
        s = s + x
    }
    return u
}
let w = [1.0]
let p = clean(w, 1, 0.5, 2)
let q = clean(w, 2, 1.5, 3)
printf("%d %d\n", len(p), len(q))
// opt5_clean -- DESIGN.md 5.8 T10: unused pure values and loads deleted (the check and the
// checked add stay), `k = k` (mov R R) and then k's mov, an if whose part becomes empty, and
// the retain/release pair of `return u`; s, read only by its own add, stays
""", r"""#sea 1
#target arm64-macos
#file opt5_clean.sea
func .main main 0:1:1 0 0
slot s1 8 8
slot s2 8 8
slot s3 16 8
sa p1 s1
sa p2 s2
lf f3 #3FF0000000000000
stf f3 p2 - 0 0
li i4 8
mcopy p1 p2 i4
li i5 1
li i6 1
li i7 1
li i8 1
rcall sea_arr_new_u 0:17 1 p9 4 i6 i7 i5 i8
ldp p10 p9 - 0 40
li i11 8
mcopy p10 p1 i11
li i12 1
lf f13 #3FE0000000000000
li i14 2
call clean 1 p15 4 p9 i12 f13 i14
release p9
li i16 1
li i17 1
li i18 1
li i19 1
rcall sea_arr_new_u 0:18 1 p20 4 i17 i18 i16 i19
ldp p21 p20 - 0 40
li i22 8
mcopy p21 p1 i22
li i23 2
lf f24 #3FF8000000000000
li i25 3
call clean 1 p26 4 p20 i23 f24 i25
release p20
ldi i27 p15 - 0 16
ldi i28 p26 - 0 16
sa p29 s3
sti i27 p29 - 0 0
sti i28 p29 - 0 8
la p30 d1
rcall sea_printf 0:19 0 2 p30 p29
release p26
release p15
ret 0
endfunc
func clean fn 0:1:1 4 p1 i2 f3 i4 1 p
li i5 1
li i6 1
li i7 1
rcall sea_arr_new 0:2 1 p8 4 i5 i6 i4 i7
mov f9 f3
mov i10 i2
li i11 0
li i12 1
rcount i13 i14 i11 i4 i12 0 0:5
if 1 i14
loop 2 i15 i11 i13 i12
lf f16 #4000000000000000
fmul f17 f3 f16
li i18 0
ldi i19 p1 - 0 16
chkb i18 i19 0 0:6
ldp p20 p1 - 0 40
ldf f21 p20 i18 8 0
fadd f22 f17 f21
li i23 1
iaddc i24 i2 i23 0:7
mov i10 i10
icmp gt i25 i2 i15
if 3 i25
lf f26 #3FF0000000000000
fadd f27 f3 f26
endif 3
fadd f9 f9 f3
endloop 2
endif 1
retain p8
release p8
ret 1 p8
endfunc
fmt d1 4
fconv - - - d i
ftext %20
fconv - - - d i
ftext %0A
#end
""")
EVENTS['opt5_clean'] = [
    ('T10', 'clean', 'movRR', 'mov i10 i10'),
    ('T10', 'clean', 'retain', 'retain p8'),
    ('T10', 'clean', 'if', 'if 3 i25'),
]


# ---------------------------------------------------------------- opt5_dead
# dead: the records after `exit 2` up to `endif 3`, after `ret 1 f4` up to `endif 4` and after
# the last `ret` up to `endfunc` never run (L-bb 3): their duplicate lf and fmul are not shared by
# T3 and their unused fadd, fmul and lf are not deleted by T10; no event. The live
# `t + x * 2.0 + x * 2.0` before the last ret: T3 shares the second lf and fmul (copy propagation),
# so the second fadd reads the first fmul twice. (Their reads count as reads for T10: here they
# read only the parameter x and their own registers.)
CASES['opt5_dead'] = (r"""fn dead(a: i64, x: f64, n: i64) -> f64 {
    var t = 0.0
    for i in 0..n {
        t = t + x * 2.0
        if t > 100.0 {
            break
            t = x * 3.0 + x * 3.0
        }
    }
    if a > 5 {
        return t
        t = x * 4.0 + x * 4.0
    }
    return t + x * 2.0 + x * 2.0
    let u = x * 5.0 + x * 5.0
}
printf("%g %g\n", dead(1, 0.5, 3), dead(9, 60.0, 4))
// opt5_dead -- DESIGN.md 5.8 and L-bb reading 3: the records after `break` (exit), after a
// `return` in an if and after the last `return` never run and stay as they are (duplicate
// x * 3.0, x * 4.0, x * 5.0 and their unused results: no T3, no T10); the live x * 2.0 + x * 2.0
// before the last return is shared by T3
""", r"""#sea 1
#target arm64-macos
#file opt5_dead.sea
func .main main 0:1:1 0 0
slot s1 16 8
li i1 1
lf f2 #3FE0000000000000
li i3 3
call dead 1 f4 3 i1 f2 i3
li i5 9
lf f6 #404E000000000000
li i7 4
call dead 1 f8 3 i5 f6 i7
sa p9 s1
stf f4 p9 - 0 0
stf f8 p9 - 0 8
la p10 d1
rcall sea_printf 0:17 0 2 p10 p9
ret 0
endfunc
func dead fn 0:1:1 3 i1 f2 i3 1 f
lf f4 #0000000000000000
li i5 0
li i6 1
rcount i7 i8 i5 i3 i6 0 0:3
if 1 i8
loop 2 i9 i5 i7 i6
lf f10 #4000000000000000
fmul f11 f2 f10
fadd f4 f4 f11
lf f12 #4059000000000000
fcmp gt i13 f4 f12
if 3 i13
exit 2
lf f14 #4008000000000000
fmul f15 f2 f14
lf f16 #4008000000000000
fmul f17 f2 f16
fadd f4 f15 f17
endif 3
endloop 2
endif 1
li i18 5
icmp gt i19 i1 i18
if 4 i19
ret 1 f4
lf f20 #4010000000000000
fmul f21 f2 f20
lf f22 #4010000000000000
fmul f23 f2 f22
fadd f4 f21 f23
endif 4
lf f24 #4000000000000000
fmul f25 f2 f24
fadd f26 f4 f25
lf f27 #4000000000000000
fmul f28 f2 f27
fadd f29 f26 f28
ret 1 f29
lf f30 #4014000000000000
fmul f31 f2 f30
lf f32 #4014000000000000
fmul f33 f2 f32
fadd f34 f31 f33
endfunc
fmt d1 4
fconv - - - g f
ftext %20
fconv - - - g f
ftext %0A
#end
""")
EVENTS['opt5_dead'] = [
]


# ================================================================ lir4_seaopt (re-derived, L-ak)
# Its lir1 (tests/passes/lir4_seaopt.lir1, hand-written in 4c) is one region. T1: no chkb, no
# checked arithmetic; T2: no division. T3 rule 1: `li i4 1` = `li i2 1` -> mov i4 i2, propagated
# into the rcall (i4 has one definition, read only later in the region) and deleted; likewise
# `li i10 2` -> i3 and `li i11 1` -> i2. T4: no if. T10: `retain p5` immediately followed by
# `release p5` deleted. Renumbered: p5 -> p4, p6 -> p5, p7 -> p6, i8 -> i7, p9 -> p8, i12 -> i9,
# p13 -> p10; the data records unchanged.
LIR4_SEAOPT_LIR = """#sea 1
#target arm64-macos
#file lir4_seaopt.sea
func .main main 0:1:1 0 0
la p1 d1
li i2 1
li i3 2
rcall sea_arr_new_s 0:2 1 p4 4 p1 i2 i3 i2
ldp p5 p4 - 0 40
la p6 d2
li i7 16
mcopy p5 p6 i7
release p4
la p8 d3
li i9 3
rcall sea_arr_new_s 0:3 1 p10 4 p8 i3 i2 i9
release p10
ret 0
endfunc
slay d1 8 0
dat d2 i64 2
dvi 7
dvi -7
slay d3 24 2
soff 0
soff 16
#end
"""


# ================================================================ writing the files
def main_write():
    for nm, (sea, lir1) in CASES.items():
        for ext, text in (('sea', sea), ('lir1', lir1), ('lir', LIR[nm])):
            with open(os.path.join(PASSES, '%s.%s' % (nm, ext)), 'w') as fh:
                fh.write(text)
    with open(os.path.join(PASSES, 'lir4_seaopt.lir'), 'w') as fh:
        fh.write(LIR4_SEAOPT_LIR)


# ================================================================ the self-check
def check_lir(name, text, strict):
    """passes.txt set L; registers (3.6.1), labels (3.6.2), slots (3.6.3), blocks (3.6.4)."""
    ls = text.split('\n')
    assert ls[-1] == '' and ls[-2] == '#end', (name, 'end')
    assert ls[0] == '#sea 1' and ls[1].startswith('#target ') and ls[2].startswith('#file '), name
    body = ls[3:-2]
    labels, nlab, infunc = [], 0, False
    for ln in body:
        rec = ln.split(' ')
        op = rec[0]
        assert op in FMT, (name, 'record', ln)
        layout(rec)
        if op == 'func':
            infunc, seen, regs, blocks, open_, nslot, slots = True, 0, {}, 0, [], 0, []
        if infunc:
            for tok in rec[1:]:
                m = re.match(r'^([ifp])([1-9][0-9]*)$', tok)
                if m and m.group(2) not in regs:
                    seen += 1
                    assert int(m.group(2)) == seen, (name, 'register numbering', ln)
                    regs[m.group(2)] = m.group(1)
                elif m:
                    assert regs[m.group(2)] == m.group(1), (name, 'register class', ln)
                if op == 'la' and re.match(r'^d[1-9][0-9]*$', tok) and tok not in labels:
                    labels.append(tok)
                    assert strict is False or tok == 'd%d' % len(labels), \
                        (name, 'label numbering', ln)
            if op == 'slot':
                nslot += 1
                assert rec[1] == 's%d' % nslot, (name, 'slot numbering', ln)
            if op in ('loop', 'do', 'if', 'ifz'):
                blocks += 1
                assert int(rec[1]) == blocks, (name, 'block numbering', ln)
                open_.append((op, blocks))
            elif op in ('endloop', 'enddo', 'endif'):
                want = {'endloop': ('loop',), 'enddo': ('do',), 'endif': ('if', 'ifz')}[op]
                assert open_ and open_[-1][0] in want and open_[-1][1] == int(rec[1]), \
                    (name, 'block nesting', ln)
                open_.pop()
            elif op == 'else':
                assert open_[-1][0] in ('if', 'ifz') and open_[-1][1] == int(rec[1]), (name, ln)
            elif op in ('exit', 'next'):
                assert any(x == int(rec[1]) and o in ('loop', 'do') for o, x in open_), (name, ln)
        if op == 'endfunc':
            assert not open_, (name, 'blocks')
            infunc = False
        if op in ('str', 'fmt', 'dat', 'slay'):
            nlab += 1
            assert rec[1] == 'd%d' % nlab, (name, 'data record order', ln)
    # sea.lir keeps every label and data record, referenced or not (3.6.2)
    assert (nlab == len(labels)) if strict else all(int(t[1:]) <= nlab for t in labels), \
        (name, 'labels')
    return len(body)


def outside(text):
    """The header, slot and data records: equal in sea.lir1 and sea.lir (3.6.5)."""
    keep, infn = [], False
    for ln in text.split('\n'):
        op = ln.split(' ')[0]
        if op == 'func':
            infn = True
            keep.append(' '.join(ln.split(' ')[:2]))
        if not infn or op == 'slot':
            keep.append(ln)
        if op == 'endfunc':
            infn = False
    return keep


def design_magic():
    """5.8 T2's sentence with the two magic numbers, as DESIGN.md writes it."""
    with open(os.path.join(ROOT, 'docs', 'DESIGN.md')) as fh:
        doc = ' '.join(fh.read().split())
    m = re.search(r'For c = 2147483647, M = #([0-9A-F]{16}) and s = ([0-9]+); for c = 10, '
                  r'M = #([0-9A-F]{16}) and s = ([0-9]+)\.', doc)
    assert m, 'DESIGN.md 5.8 T2: the magic-number sentence'
    return {2147483647: (int(m.group(1), 16), int(m.group(2))),
            10: (int(m.group(3), 16), int(m.group(4)))}


def check_build():
    import tempfile
    for nm, (sea, lir1) in CASES.items():
        with tempfile.TemporaryDirectory() as d:
            with open(os.path.join(d, nm + '.sea'), 'w') as fh:
                fh.write(sea)
            r = subprocess.run([os.path.join(CHECK_BUILD, 'sea'), 'build', '--emit', 'lir1',
                                '--no-prelude', nm + '.sea', '-o', nm + '.lir1'], cwd=d,
                               capture_output=True, text=True, timeout=60)
            assert r.returncode == 0 and r.stderr == '', (nm, r.stderr)
            with open(os.path.join(d, nm + '.lir1')) as fh:
                assert fh.read() == lir1, (nm, 'embedded lir1 differs from the build')


def run():
    for c, mv in design_magic().items():
        assert magic(c) == mv, ('magic', c, magic(c), mv)
    nrec, nev = 0, 0
    for nm, (sea, lir1) in CASES.items():
        log = []
        LIR[nm] = optimize(lir1, log)
        assert log == EVENTS[nm], (nm, 'events', log)
        nev += len(log)
    main_write()
    for nm, (sea, lir1) in CASES.items():
        for ext in ('lir1', 'lir'):
            with open(os.path.join(PASSES, '%s.%s' % (nm, ext))) as fh:
                nrec += check_lir('%s.%s' % (nm, ext), fh.read(), ext == 'lir1')
        assert outside(lir1) == outside(LIR[nm]), (nm, 'header, slots or data changed')
        assert lir1.split('\n')[2] == '#file %s.sea' % nm, nm
    src = os.path.join(os.path.dirname(HERE), 'passes')
    with open(os.path.join(src, 'lx.lir1')) as fh:
        lx1 = fh.read()
    with open(os.path.join(src, 'lx.lir')) as fh:
        assert optimize(lx1, []) == fh.read(), 'lx.lir is changed by T1-T4, T10'
    with open(os.path.join(src, 'lir4_seaopt.lir1')) as fh:
        l4 = fh.read()
    l4log = []
    assert optimize(l4, l4log) == LIR4_SEAOPT_LIR, 'lir4_seaopt.lir != its hand derivation'
    assert l4log == [('T10', '.main', 'retain', 'retain p5')], l4log
    with open(os.path.join(PASSES, 'lir4_seaopt.lir')) as fh:
        nrec += check_lir('lir4_seaopt.lir', fh.read(), False)
    if CHECK_BUILD:
        check_build()
    print('dump5_cases: %d opt5 dumps (%d events as derived), lir4_seaopt.lir re-derived, lx.lir '
          'unchanged; %d records checked; T2\'s magic numbers equal 5.8\'s%s'
          % (len(CASES), nev, nrec, '; embedded lir1 equal to the build' if CHECK_BUILD else ''))


LIR = {}

if __name__ == '__main__':
    run()
