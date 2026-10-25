"""Sub-phase 5c-1 and 5c-2 dump tests of passes 3b and 3c (DESIGN.md 6.2 "Phase-5 tests", `opt5_*`
dumps; 3.6.5 "Pass 3b from phase 5" and "Pass 3c"; 5.8 T1 (with the facts F1-F6) to T10; lead
decisions L-ak, L-al, L-am, L-ao, L-ap, L-au, L-av, L-ba, L-bb, L-be, L-bj, L-bl, L-bm, L-bn,
L-bq; Decision 74).

Run with `timeout 120 uv run --no-project python tests/vectors/dump5_cases.py [--out DIR]
[--check-build BUILD]`. It writes, in tests/passes/ (or DIR), for each case NAME.sea, NAME.lir1,
NAME.lir2 (seaopt's output) and NAME.lir (sealopt's): the stage pairs `seaopt lir1 lir2` and
`sealopt lir2 lir` of tests/stage.sh check them, and tests/run.sh checks `--emit lir1`, `--emit
lir2` and `--emit lir` of NAME.sea (built with --no-prelude):

* 5c-1's share of 6.2's `opt5_*` list (their .lir2 is 5c-1's .lir renamed, Decision 74; only
  opt5_clean's changes, by L-bn: its s, read only by its own add, is deleted):
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
                    immediately followed by its release; a value read only by its own add (L-bn)
  opt5_dead         L-bb 3: records after exit and ret, up to the end of their part, unchanged
  Their .lir shows what T5-T10 do to them (L-ak): versioning, promotion, hoisting, reduction and
  unswitching, in the note after each case's EVENTS.
* 5c-2's share:
  opt5_promote      T5: a `ref` scalar and two struct fields of a slot promoted (pre-loads,
                    destination rewriting, post-stores), read-only locations; a `ref` passed to
                    a call (kept)
  opt5_promote_exit T5 with a `return` inside the loop (post-store before the ret; promoted in
                    the enclosing loop, not again in the inner one), a `break` and the loop's own
                    `continue` (the post-stores after the closing record), a `continue` of the
                    enclosing loop after it
  opt5_cow          T6, register form: two cowed arrays (iand), an alias used as a base only; an
                    outer loop versioned for a cow in its inner loop
  opt5_cow_ref      T6, memory form (a `ref` array): versioned, T3's mov part of the cow (L-bs)
  opt5_cow_kept     T6's conditions: the array or a copy of it passed to a call (kept); the inner
                    loop versioned when the outer one passes the array on
  opt5_sr_unit      T7, unit stride: constant offsets, invariant terms with the signs + and -,
                    2-D columns (scale 1 and 8); checked chains and X = J unchanged
  opt5_sr_stride    T7, invariant stride: constant k with the start folded (step 2 too) and with
                    a start that is not a constant; a register k (matrix rows) from start 0 and
                    from a register start; two accesses sharing their start term after T8
  opt5_licm_hdr     T8 (b): an array register's header loads hoisted from an if part; an array
                    written in the loop (kept)
  opt5_licm_param   T8 (a): a parameter base hoisted only when anticipated (not in an if part,
                    not after a `break` test)
  opt5_unswitch     T9: two invariant conditions of three (four copies), renumbering of the
                    copies (L-bl), placement into the arms (L-bm); one condition, nothing placed
  opt5_lcg          W5's lcg_fill with a two-line main: its .lir loop equals 5.8's W5 text
  opt5_sor          W4's SOR loop over a 5 x 6 grid: T6 on T, T8, T7, T8, T9's four copies of the
                    j loop with their pointers placed (L-bm)
* the re-derived goldens of 3.6.5 / L-ak / L-bj: lir4_seaopt.lir2 (5c-1's lir4_seaopt.lir
  renamed: T3 shares three `li` constants, T10 deletes `retain p5` / `release p5`; its lir1 is
  unchanged; a hand-written seaopt test gets no .lir, and the old one is removed), and lx.lir2
  and lx.lir (3.6.7, phase 1): T1-T10 leave lx unchanged, so both equal 5c-1's lx.lir. gen_arith
  and ra5_* are pass-4 tests: not written (L-bj).

How each file is made (never by running seaopt or sealopt; WP-LOPT writes sealopt concurrently):
* NAME.sea: written for the case (each function has a loop and two call sites, so LANGUAGE.md
  8.6 requires no inlining, 3.6.6).
* NAME.lir1: the input side, `sea build --emit lir1 --no-prelude NAME.sea` of the phase-4
  passes (sealower is not changed in phase 5), embedded below; --check-build BUILD compares it
  with BUILD/sea's output.
* NAME.lir2: from NAME.lir1 by the model of seaopt below, which applies 5.8's rules T1, T2, T3,
  T4 (with L-bq's condition) and T10 (with L-bn) in that order to each function and renumbers it
  (3.6.1, 3.6.4). What each rule does on each case is derived by hand (the note above each case)
  and written in EVENTS; the self-check requires the model to do exactly those.
* NAME.lir: from NAME.lir2 by the model of sealopt, T5, T6, T8, T7, T8, T9 (with L-bl's renaming
  and L-bm's placement) and T10, renumbered; its events are written in EVENTS2 (the notes after
  the EVENTS of the 5c-1 cases, before those of the 5c-2 cases).

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

Readings of 5.8's T5-T9 this model takes (lead decisions and implementer readings of 5c-2):
* (L-br, L-bs, L-bt, lead decisions of 5c-2) T7's start and step are constants when their only
  definition is an `li` or a `mov` whose source's only definition is an `li` (T3 leaves a loop's
  `li 1` step as `mov i12 i10`); the constant c and a constant k of the index stay as the Terms
  define them. T6's memory form counts the cow's leading load of A, or the `mov` T3 made of it,
  as part of the cow (deleting the cow keeps it). T9 splits a copy on c2 only when it still
  tests c2 after the first split (opt5_ovf_const: three copies).
* T7's index forms: J, constants and invariant registers combined by wrapping `iadd`/`isub` (J
  never subtracted) and J * k as one `imul` of J; no case has a start term, t term and e that
  all vanish (Q would be D: the model stops if one does).
* T8's "I's block" is I's part (4.9.2): the two readings differ only for a read of D in the other
  part of I's if, which no case has (asserted); "the instructions standing there" before an
  opening record are those T5, T7 and T8 put there: before a `do` they may follow other
  instructions, which no case lets T8 common (asserted).
* T6's cow: the `li` of the 1 may be missing (T3 shared it with an earlier `li 1`); the memory
  form's P must be a private base, as T5's.
* T5: an access of the location of the other class (ldi and stf at one offset) is another
  overlapping access (no case has one).
* T4 (L-bq): "read nowhere after the block" is: no record after the `endif` reads R.

The self-check reads every written file back: each record against include/passes.txt set L,
the numbering of registers, blocks, slots and labels (3.6.1-3.6.4), no write of a loop's ind in
the loop, the header and data records and slots equal between NAME.lir1, NAME.lir2 and NAME.lir,
the events of each case against EVENTS and EVENTS2, T2's two magic numbers against 5.8's text,
opt5_lcg.lir's fast loop against 5.8's W5 text (names bound one to one, the constants, U and the
pre-load and single post-store of S where 5.8 puts them), lx unchanged by the model and
lir4_seaopt.lir2 equal to its hand derivation below.
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
def covered_at_if(recs, k, R):
    """L-bq (5.8 T4): R has a write on every path to the if at record k: R is a parameter, or an
    earlier write of R (record order) has an effective part (4.9.2, L-bh) containing the if."""
    if R in params_of(recs):
        return True
    st = St(recs)
    for j, reg, ep in eff_parts(recs, st):
        if j < k and reg == R and st.contains(ep, st.part[k]):
            return True
    return False


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
                # L-bq: the form reading its own destination needs R written on every path to
                # the if, or R read nowhere after the endif (then T10 deletes it, L-bn); the
                # records already converted stand in `out`, those after the block in recs
                cur = out + recs[k:]
                after = [y for y in recs[k + 3:] for kk in reads(y) if y[kk] == R]
                if not covered_at_if(cur, len(out), R) and after:
                    log.append(('T4', fn, 'kept', ' '.join(x)))
                    n = 0
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
        # L-bn: an instruction's read of its own destination does not count
        rd = {}
        for m, y in enumerate(recs):
            for kk in reads(y):
                rd.setdefault(y[kk], set()).add(m)
        dead = dead_mask(recs)
        out, k = [], 0
        while k < len(recs):
            x, op = recs[k], recs[k][0]
            n = 0
            if dead[k]:
                pass
            elif op == 'mov' and x[1] == x[2]:
                n, ev = 1, 'movRR'
            elif (op in PURE or op in LOADS) and not (rd.get(writes(x)[0], set()) - {k}):
                n = 1
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


# ================================================================ block structure and parts
OPENS = ('loop', 'do', 'if', 'ifz')
CLOSES = ('endloop', 'enddo', 'endif')
LOOPS = ('loop', 'do')


class St:
    """Block structure of one function: matching records, the innermost part of each record
    (4.9.2 "Parts": ('F',) the body, (o, 0) a loop body or an if's first part, (o, 1) an else
    part, o the opening record's index) and the blocks enclosing it."""

    def __init__(self, recs):
        self.recs = recs
        self.close, self.els = {}, {}
        self.part, self.encl = [], []
        self.pparent = {('F',): None}
        stack = []
        for k, x in enumerate(recs):
            op = x[0]
            if op in CLOSES:
                o = stack.pop()[0]
                self.close[o] = k
            if op == 'else':
                o = stack[-1][0]
                self.els[o] = k
                stack[-1] = (o, 1)
                self.pparent[(o, 1)] = self.part[o]
                self.part.append(self.part[o])
                self.encl.append([s[0] for s in stack[:-1]])
                continue
            self.part.append(tuple(stack[-1]) if stack else ('F',))
            self.encl.append([s[0] for s in stack])
            if op in OPENS:
                stack.append((k, 0))
                self.pparent[(k, 0)] = self.part[k]
        assert not stack

    def contains(self, a, b):
        while b is not None:
            if b == a:
                return True
            b = self.pparent[b]
        return False

    def find(self, bid):
        for k, x in enumerate(self.recs):
            if x[0] in OPENS and x[1] == bid:
                return k
        raise AssertionError(('no block', bid))

    def loops_in(self, k):
        """The loops enclosing record k, outermost first."""
        return [o for o in self.encl[k] if self.recs[o][0] in LOOPS]


def eff_parts(recs, st):
    """4.9.2 (L-bh): (record, register, effective part) of every write, the parameters at the
    entry with the body as their part."""
    out, last = [], {}
    for r in params_of(recs):
        out.append((0, r, ('F',)))
        last[r] = ('F',)
    for k, x in enumerate(recs):
        if k == 0:
            continue
        for r in writes(x):
            ep = st.part[k]
            if ep[0] != 'F' and ep[1] == 1 and last.get(r) == (ep[0], 0):
                ep = st.pparent[(ep[0], 0)]
            out.append((k, r, ep))
            last[r] = ep
    return out


# ================================================================ sealopt (5c-2): T5-T9, T10
class R(list):
    """A record of the sealopt model with its marks: `placed` (put before a loop's opening
    record by T5, T7 or T8: what "stands there" for T8's constant commoning) and `reduced` (an
    access T7 has rewritten, never reduced again)."""
    placed = False
    reduced = False


def rcopy(x):
    y = R(x)
    y.placed, y.reduced = getattr(x, 'placed', False), getattr(x, 'reduced', False)
    return y


def regs_of(x):
    return [x[k] for nm, kind, k in layout(x) if kind in REGK and x[k] != '-'] \
        if x[0] not in ('slot', 'endfunc') else []


class Fn:
    """One function while sealopt's model transforms it."""

    def __init__(self, recs, name, log):
        self.recs = [rcopy(x) for x in recs]
        self.name, self.log = name, log
        self.top = max([int(r[1:]) for x in recs for r in regs_of(x)] + [0])
        self.nblk = 0
        self.slow = set()           # block ids inside slow copies (T6): never versioned, no T9
        self.versioned = set()      # the block id of each fast copy (T6)

    def fresh(self, cls):
        """A register above the highest number in use (T6, L-bl)."""
        self.top += 1
        return '%s%d' % (cls, self.top)

    def fresh_block(self):
        self.nblk += 1
        return 'n%d' % self.nblk

    def ndefs(self, r):
        return sum((params_of(self.recs).count(r) if y[0] == 'func' else writes(y).count(r))
                   for y in self.recs)

    def defs(self, r):
        return [k for k, y in enumerate(self.recs)
                if (r in params_of(self.recs) if y[0] == 'func' else r in writes(y))]

    def readers(self, r):
        return [(m, k) for m, y in enumerate(self.recs) for k in reads(y) if y[k] == r]

    def written_in(self, r, a, b):
        """Some record a <= k <= b writes r (a loop's opening record writes its ind)."""
        return any(r in writes(self.recs[k]) for k in range(a, b + 1))

    def const_value(self, r, strict=False):
        """A constant (5.8 Terms: the only definition is one li). For a loop's step and start
        (T7, L-br): also a register whose only definition is a `mov` from such a constant, as
        T3 leaves `li 1` steps (`mov i12 i10`, the 1 shared with the start)."""
        ds = self.defs(r)
        if len(ds) != 1 or ds[0] == 0:
            return None
        x = self.recs[ds[0]]
        if x[0] == 'li':
            v = parse_i(x[2])
            return v if -FLIM <= v <= FLIM else None
        if x[0] == 'mov' and not strict and x[1][0] == 'i':
            return self.const_value(x[2])
        return None


def region_of(recs, j):
    s = j
    while s > 0 and recs[s - 1][0] not in CUT + ('func', 'slot'):
        s -= 1
    e = j
    while e < len(recs) and recs[e][0] not in CUT + ('endfunc',):
        e += 1
    return s, e


def copy_prop(F, j):
    """T3's copy propagation of the `mov D S` at record j: True when it was made."""
    recs = F.recs
    D, S = recs[j][1], recs[j][2]
    if F.ndefs(D) != 1:
        return False
    s, e = region_of(recs, j)
    rs = F.readers(D)
    if not all(j < m < e for m, _ in rs):
        return False
    last = max([m for m, _ in rs], default=j)
    if any(S in writes(recs[m]) for m in range(j + 1, last)):     # L-bb 2: not the last reader
        return False
    for m, k in rs:
        recs[m][k] = S
    del recs[j]
    return True


def dest_rewrite(F, j):
    """T5's destination rewriting of the `mov X V` at record j: True when it was made."""
    recs = F.recs
    X, V = recs[j][1], recs[j][2]
    ds = F.defs(V)
    if len(ds) != 1 or ds[0] == 0:
        return False
    d = ds[0]
    s, e = region_of(recs, j)
    if not s <= d < j:
        return False
    for m in range(d + 1, j):
        y = recs[m]
        if X in writes(y) or X in [y[k] for k in reads(y)]:
            return False
    if not all(s <= m < e for m, _ in F.readers(V)):
        return False
    y = recs[d]
    for nm, kind, k in layout(y):
        if kind in REGK and nm in ('d', 'e') and y[k] == V:
            y[k] = X
    for m, k in F.readers(V):
        recs[m][k] = X
    del recs[j]
    return True


def find_x(recs, obj):
    for k, x in enumerate(recs):
        if x is obj:
            return k
    raise AssertionError('record lost')


# ---------------------------------------------------------------- T5
def t5(F):
    done = {}
    for bid in [x[1] for x in F.recs if x[0] in LOOPS]:
        recs = F.recs
        st, info, dead = St(recs), Info(recs), dead_mask(recs)
        L = st.find(bid)
        C = st.close[L]
        anc = [recs[o][1] for o in st.loops_in(L)]
        excluded = set()
        for a in anc:
            excluded |= done.get(a, set())
        accs = [(k, recs[k]) for k in range(L + 1, C)
                if recs[k][0] in LOADS or recs[k][0] in STORES]
        locs = []
        for k, x in accs:
            if x[0] not in ('ldi', 'ldf', 'sti', 'stf') or x[3] != '-':
                continue
            P, off = x[2], int(x[5])
            if (P, off) in [l for l, _ in locs] or (P, off) in excluded:
                continue
            if P not in info.private or F.written_in(P, L, C):
                continue
            cls = 'i' if x[0] in ('ldi', 'sti') else 'f'
            same = ('ldi', 'sti') if cls == 'i' else ('ldf', 'stf')
            ok = True
            for k2, y in accs:
                if y[2] != P:
                    continue
                sz, o2 = (1 if y[0] in ('ldb', 'stb') else 8), int(y[5])
                if o2 < off + 8 and off < o2 + sz and not (o2 == off and y[0] in same):
                    ok = False
            if ok:
                locs.append(((P, off), cls))
        if not locs:
            continue
        done[bid] = {l for l, _ in locs}
        X = {l: F.fresh(cls) for l, cls in locs}
        made_ld, made_st, stored = [], [], set()
        for k in range(L + 1, C):
            x = recs[k]
            if x[0] in ('ldi', 'ldf', 'sti', 'stf') and x[3] == '-' and (x[2], int(x[5])) in X:
                assert not dead[k], ('T5 in records that never run', F.name)
                l = (x[2], int(x[5]))
                if x[0] in LOADS:
                    recs[k] = R(['mov', x[1], X[l]])
                    made_ld.append(recs[k])
                else:
                    recs[k] = R(['mov', X[l], x[1]])
                    made_st.append(recs[k])
                    stored.add(l)
        posts = [[('sti' if cls == 'i' else 'stf'), X[l], l[0], '-', '0', str(l[1])]
                 for l, cls in locs if l in stored]
        pre = [[('ldi' if cls == 'i' else 'ldf'), X[l], l[0], '-', '0', str(l[1])]
               for l, cls in locs]
        out = []
        for k, x in enumerate(recs):
            if k == L:
                for p in pre:
                    y = R(p)
                    y.placed = True
                    out.append(y)
            if L < k < C and (x[0] == 'ret' or (x[0] in ('exit', 'next') and x[1] in anc)):
                assert not dead[k]
                out += [R(p) for p in posts]
            out.append(x)
            if k == C:
                out += [R(p) for p in posts]
        F.recs = out
        for l, cls in locs:
            F.log.append(('T5', F.name, 'promote', bid, '%s %d' % l, l in stored))
        for m in made_ld:
            copy_prop(F, find_x(F.recs, m))
        for m in made_st:
            if dest_rewrite(F, find_x(F.recs, m)):
                F.log.append(('T5', F.name, 'dest', bid, m[2]))


# ---------------------------------------------------------------- T6
def find_cows(F, st, info):
    """Rule 19's sequences: (key, records of the cow, A, N); key ('reg', A) or ('mem', P, off)."""
    recs, out = F.recs, []
    for k, x in enumerate(recs):
        if x[0] != 'if':
            continue
        e = st.close[k]
        part = recs[k + 1:e]
        if not (len(part) in (2, 3) and part[0][0] == 'rcall' and part[0][1] == 'sea_arr_unique'
                and part[-1][0] == 'mov' and len(rcall_args(part[0])) == 1):
            continue
        A, N = rcall_args(part[0])[0], rcall_res(part[0])[0]
        if part[-1][1:] != [A, N] or k in st.els:
            continue
        mem = None
        if len(part) == 3:
            s = part[1]
            if not (s[0] == 'stp' and s[1] == N and s[3] == '-'):
                continue
            mem = (s[2], int(s[5]))
        ic = recs[k - 1]
        if not (ic[0] == 'icmp' and ic[1] == 'ne' and ic[2] == x[2]
                and info.consts.get(ic[4]) == 1):
            continue
        j = k - 2
        if recs[j][0] == 'li' and recs[j][1] == ic[4]:
            j -= 1
        ld = recs[j]
        if not (ld[0] == 'ldi' and ld[1] == ic[3] and ld[2] == A and ld[3] == '-'
                and int(ld[5]) == SEA_ARR_RC):
            raise AssertionError(('cow without its ldi', F.name, ' '.join(x)))
        key = ('mem',) + mem if mem else ('reg', A)
        # L-bs: the memory form's leading load of A (`ldp A P - 0 off`, or the `mov A V` T3
        # made of it) is part of the cow for T6's condition; deleting the cow keeps it
        lead = []
        if mem and j > 0:
            y = recs[j - 1]
            if (y[0] == 'ldp' and y[1] == A and y[2] == mem[0] and y[3] == '-'
                    and int(y[5]) == mem[1]) or (y[0] == 'mov' and y[1] == A):
                lead = [j - 1]
        out.append((key, [j, k - 1] + list(range(k, e + 1)), A, N, lead))
    return out


def copy_set(recs, start):
    cs, changed = set(start), True
    while changed:
        changed = False
        for x in recs:
            add = set()
            if x[0] == 'mov' and x[1][0] == 'p' and (x[1] in cs or x[2] in cs):
                add = {x[1], x[2]}
            if x[0] == 'psel':
                if x[3] in cs or x[4] in cs:
                    add.add(x[1])
                if x[1] in cs:
                    add |= {x[3], x[4]}
            if add - cs:
                cs |= add
                changed = True
    return cs


def local_regs(recs, a, b):
    """L-bl: the registers every reference to which lies in records a..b, the opening record a
    not reading them."""
    inside, outside = set(), set()
    for k, x in enumerate(recs):
        (inside if a <= k <= b else outside).update(regs_of(x))
    opening = {recs[a][k] for k in reads(recs[a])}
    return inside - outside - opening


def renamed_copy(F, seg, local):
    """A copy of the records seg with fresh numbers for the local registers (in order of first
    reference in the copy) and fresh block ids for the blocks it opens."""
    names, blocks, out = {}, {}, []
    for x in seg:
        y = rcopy(x)
        if y[0] in OPENS:
            blocks[y[1]] = F.fresh_block()
        if y[0] in BLOCK + ('exit', 'next') and y[1] in blocks:
            y[1] = blocks[y[1]]
        if y[0] not in ('slot', 'endfunc'):
            for nm, kind, k in layout(y):
                if kind in REGK and y[k] in local:
                    if y[k] not in names:
                        names[y[k]] = F.fresh(y[k][0])
                    y[k] = names[y[k]]
        out.append(y)
    return out, set(blocks.values())


def t6(F):
    for bid in [x[1] for x in F.recs if x[0] in LOOPS]:
        recs = F.recs
        st, info, dead = St(recs), Info(recs), dead_mask(recs)
        L = st.find(bid)
        C = st.close[L]
        anc = [recs[o][1] for o in st.loops_in(L)]
        if bid in F.slow or any(a in F.versioned or a in F.slow for a in anc):
            continue
        cows = [c for c in find_cows(F, st, info) if L < c[1][2] < C]
        if not cows:
            continue
        assert not any(dead[c[1][2]] for c in cows)
        keys = []
        for c in cows:
            if c[0] not in keys:
                keys.append(c[0])
        ok = True
        for key in keys:
            mine = [c for c in cows if c[0] == key]
            cowrecs = {k for c in mine for k in c[1] + c[4]}
            if key[0] == 'reg':
                A = key[1]
                movs = {c[1][-2] for c in mine}
                if any(A in writes(recs[k]) and k not in movs for k in range(L, C + 1)):
                    ok = False
                start = {A}
            else:
                P, off = key[1], key[2]
                if P not in info.private or F.written_in(P, L, C):
                    ok = False
                stps = {c[1][-3] for c in mine}
                for k in range(L + 1, C):
                    y = recs[k]
                    if y[0] in STORES and y[2] == P and k not in stps:
                        sz, o2 = (1 if y[0] == 'stb' else 8), int(y[5])
                        if o2 < off + 8 and off < o2 + sz:
                            ok = False
                start = {recs[k][1] for k in range(L + 1, C) if recs[k][0] == 'ldp'
                         and recs[k][2] == P and recs[k][3] == '-' and int(recs[k][5]) == off}
                start |= {c[2] for c in mine}
            members = copy_set(recs, start)
            for k in range(L, C + 1):
                y = recs[k]
                for kk in reads(y):
                    if y[kk] in members and not (
                            ((y[0] in LOADS or y[0] in STORES) and kk == 2) or k in cowrecs):
                        ok = False
        if not ok:
            F.log.append(('T6', F.name, 'kept', bid))
            continue
        pre, Cs = [], []
        for key in keys:
            if key[0] == 'mem':
                A1 = F.fresh('p')
                pre.append(['ldp', A1, key[1], '-', '0', str(key[2])])
            else:
                A1 = key[1]
            C1 = F.fresh('i')
            pre.append(['ldi', C1, A1, '-', '0', str(SEA_ARR_RC)])
            Cs.append(C1)
        O = F.fresh('i')
        pre.append(['li', O, '1'])
        Us = []
        for C1 in Cs:
            U = F.fresh('i')
            pre.append(['icmp', 'eq', U, C1, O])
            Us.append(U)
        V = Us[0]
        for U in Us[1:]:
            V2 = F.fresh('i')
            pre.append(['iand', V2, V, U])
            V = V2
        B = F.fresh_block()
        gone = {k for c in cows for k in c[1]}
        fast = [recs[k] for k in range(L, C + 1) if k not in gone]
        slow, sblocks = renamed_copy(F, recs[L:C + 1], local_regs(recs, L, C))
        F.recs = (recs[:L] + [R(p) for p in pre] + [R(['if', B, V])] + fast + [R(['else', B])]
                  + slow + [R(['endif', B])] + recs[C + 1:])
        F.versioned.add(bid)
        F.slow |= sblocks
        F.log.append(('T6', F.name, 'version', bid,
                      ', '.join(' '.join(str(v) for v in k[1:]) for k in keys)))


# ---------------------------------------------------------------- T8
def post_order(F):
    st = St(F.recs)
    loops = [k for k, x in enumerate(F.recs) if x[0] in LOOPS]
    out = []

    def visit(o):
        for c in loops:
            if st.loops_in(c) and st.loops_in(c)[-1] == o:
                visit(c)
        out.append(F.recs[o][1])
    for o in loops:
        if not st.loops_in(o):
            visit(o)
    return out


def may_change(info, ld, X):
    """5.8 Terms: a load may be changed by X."""
    base, off, opx = ld[2], int(ld[5]), X[0]
    if base in info.arrays and ld[3] == '-' and off in (SEA_ARR_ROWS, SEA_ARR_COLS, SEA_ARR_DATA):
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


def object_pointer(F, r, seen=()):
    if r in seen:
        return False
    for k in F.defs(r):
        x = F.recs[k]
        if x[0] in ('func', 'call', 'rcall', 'ldp', 'sa'):
            continue
        if x[0] == 'mov' and object_pointer(F, x[2], seen + (r,)):
            continue
        return False
    return True


def slot_size(F, P):
    sizes = {x[1]: int(x[2]) for x in F.recs if x[0] == 'slot'}
    return sizes[F.recs[F.defs(P)[0]][2]]


def t8(F, npass):
    for bid in post_order(F):
        recs = F.recs
        st, info, dead = St(recs), Info(recs), dead_mask(recs)
        L = st.find(bid)
        C = st.close[L]
        anc = [recs[o][1] for o in st.loops_in(L)]
        moved = set()

        def remaining():
            return [m for m in range(L, C + 1) if m not in moved]

        for k in range(L + 1, C):
            x = recs[k]
            if x[0] in CUT or dead[k] or not (x[0] in PURE or (x[0] in LOADS and x[3] == '-')):
                continue
            rem = remaining()
            if x[0] in LOADS and any(may_change(info, x, recs[m]) for m in rem):
                continue
            if any(r in writes(recs[m]) for r in [x[kk] for kk in reads(x)] for m in rem):
                continue
            D = writes(x)[0]
            if sum(writes(recs[m]).count(D) for m in rem) != 1:
                continue
            part_ok = block_ok = True
            inner = st.encl[k][-1]
            for m in rem:
                if D in [recs[m][kk] for kk in reads(recs[m])]:
                    if not (m > k and st.contains(st.part[k], st.part[m])):
                        part_ok = False
                    if not (m > k and inner < m < st.close[inner]):
                        block_ok = False
            # implementer reading: "I's block" is I's part (4.9.2); no case depends on it
            assert part_ok == block_ok, ('T8: block and part readings differ', F.name, x)
            if not part_ok:
                continue
            ant = st.part[k] == (L, 0) and not any(
                recs[m][0] in ('ret', 'release', 'call')
                or (recs[m][0] in ('exit', 'next') and (recs[m][1] == bid or recs[m][1] in anc))
                for m in range(L + 1, k))
            if not ant and any(D in [recs[m][kk] for kk in reads(recs[m])]
                               for m in range(len(recs)) if not L <= m <= C or m in moved):
                continue
            if x[0] in LOADS:
                P, off = x[2], int(x[5])
                sz = 1 if x[0] == 'ldb' else 8
                a = ant and object_pointer(F, P)
                b = P in info.arrays and off in (SEA_ARR_RC, SEA_ARR_ROWS, SEA_ARR_COLS,
                                                 SEA_ARR_DATA)
                c = False
                if P in info.private and off >= 0:
                    if recs[F.defs(P)[0]][0] == 'sa':
                        c = off + sz <= slot_size(F, P)
                    else:
                        c = any(off + sz <= int(y[5]) + (1 if y[0] in ('ldb', 'stb') else 8)
                                for y in recs if (y[0] in LOADS or y[0] in STORES)
                                and y[2] == P)
                if not (a or b or c):
                    continue
            moved.add(k)
        if moved:
            mv = [recs[k] for k in sorted(moved)]
            for y in mv:
                y.placed = True
            F.recs = recs[:L] + mv + [recs[m] for m in range(L, len(recs)) if m not in moved]
        ncom = common(F, bid)
        if moved or ncom:
            F.log.append(('T8', F.name, npass, bid, len(moved), ncom))


def common(F, bid):
    """T8's constant commoning among the instructions standing before the opening record."""
    recs = F.recs
    L = St(recs).find(bid)
    j = L
    while j > 0 and getattr(recs[j - 1], 'placed', False) and recs[j - 1][0] not in CUT:
        j -= 1
    run = list(range(j, L))
    # implementer reading: "standing there" is what T5, T7 and T8 placed; before a `do` the
    # region may hold other instructions, which no case lets an instruction equal
    s = j
    while s > 0 and recs[s - 1][0] not in CUT + ('func', 'slot'):
        s -= 1
    for a in range(s, j):
        if recs[a][0] in PURE or recs[a][0] in LOADS:
            for b in run:
                if key_of(recs[a]) == key_of(recs[b]) and F.ndefs(writes(recs[a])[0]) == 1 \
                        and F.ndefs(writes(recs[b])[0]) == 1 and not any(
                            r in writes(recs[m]) for r in [recs[b][kk] for kk in reads(recs[b])]
                            for m in range(a + 1, b)):
                    raise AssertionError(('T8 commoning: region reading differs', F.name,
                                          recs[a]))
    dele, n = set(), 0
    for b in run:
        x = recs[b]
        for a in range(b - 1, j - 1, -1):
            if a in dele or key_of(recs[a]) != key_of(x):
                continue
            ops = [x[kk] for kk in reads(x)]
            if any(r in writes(recs[m]) for r in ops for m in range(a + 1, b) if m not in dele):
                continue
            d0, d1 = writes(recs[a])[0], writes(x)[0]
            if F.ndefs(d0) != 1 or F.ndefs(d1) != 1:
                continue
            for m, kk in F.readers(d1):
                recs[m][kk] = d0
            dele.add(b)
            n += 1
            break
    F.recs = [x for m, x in enumerate(recs) if m not in dele]
    return n


# ---------------------------------------------------------------- T7
def t7(F):
    for bid in post_order(F):
        recs = F.recs
        st, dead = St(recs), dead_mask(recs)
        L = st.find(bid)
        C = st.close[L]
        lp = recs[L]
        if lp[0] != 'loop':
            continue
        J, Sreg, T = lp[2], lp[3], lp[5]
        stv = F.const_value(T)
        if stv is None:
            continue
        sv = F.const_value(Sreg)
        accs = [recs[k] for k in range(L + 1, C) if (recs[k][0] in LOADS or recs[k][0] in STORES)
                and recs[k][3] != '-' and not recs[k].reduced and not dead[k]]

        cl = recs[C]

        def span():
            return find_x(F.recs, lp), find_x(F.recs, cl)

        def inv(r):
            a, b = span()
            return not F.written_in(r, a, b)

        def lin(r):
            if r == J:
                return (1, 0, None)
            cv = F.const_value(r, True)
            if cv is not None:
                return (0, cv, None)
            if inv(r):
                return (0, 0, (1, r))
            ds = F.defs(r)
            a, b = span()
            if len(ds) != 1 or not a < ds[0] < b:
                return None
            y = F.recs[ds[0]]
            if y[0] in ('iadd', 'isub'):
                a, b = lin(y[2]), lin(y[3])
                if a is None or b is None:
                    return None
                if y[0] == 'isub':
                    if b[0] != 0:
                        return None
                    b = (0, -b[1], (-b[2][0], b[2][1]) if b[2] else None)
                if a[0] != 0 and b[0] != 0 or (a[2] and b[2]):
                    return None
                return (a[0] if a[0] != 0 else b[0], a[1] + b[1], a[2] or b[2])
            if y[0] == 'imul' and J in (y[2], y[3]):
                o = y[3] if y[2] == J else y[2]
                cv = F.const_value(o, True)
                if cv is not None:
                    return (cv, 0, None) if cv != 0 else None
                if inv(o):
                    return (o, 0, None)
            return None

        groups = []                 # [key, Q, Delta, pre-instructions]
        for acc in accs:
            X, z, o, D = acc[3], int(acc[4]), int(acc[5]), acc[2]
            if not inv(D):
                continue
            f = lin(X)
            if f is None or f[0] == 0:
                continue
            k, c, t = f
            new = []
            if k == 1:
                if X == J and o == 0:
                    continue
                e = c * z + o
                if t and not -FLIM <= t[0] * z <= FLIM or not -FLIM <= e <= FLIM:
                    continue
                D1 = D
                if t:
                    if t[0] * z == 1:
                        T1 = t[1]
                    else:
                        Z, T1 = F.fresh('i'), F.fresh('i')
                        new += [['li', Z, fmt_i(t[0] * z)], ['imul', T1, t[1], Z]]
                    D1 = F.fresh('p')
                    new.append(['padd', D1, D, T1])
                Dp = D1
                if e != 0:
                    E, Dp = F.fresh('i'), F.fresh('p')
                    new += [['li', E, fmt_i(e)], ['padd', Dp, D1, E]]
                at = find_x(F.recs, acc)
                acc[2:6] = [Dp, J, str(z), '0']
                acc.reduced = True
                F.recs[at:at] = [R(n) for n in new]
                F.log.append(('T7', F.name, bid, 'unit', ' '.join(acc)))
                continue
            key = (D, k, c, t)
            g = [g for g in groups if g[0] == key]
            if not g:
                cint = isinstance(k, int)
                folded = cint and sv is not None
                consts = [z, stv * z]
                pre, A = [], None
                if cint and not folded:
                    G, A = F.fresh('i'), F.fresh('i')
                    pre += [['li', G, fmt_i(k * z)], ['imul', A, Sreg, G]]
                    consts.append(k * z)
                elif not cint and sv is not None:
                    G, A = F.fresh('i'), F.fresh('i')
                    pre += [['li', G, fmt_i((sv - stv) * z)], ['imul', A, k, G]]
                    consts.append((sv - stv) * z)
                elif not cint:
                    G, A0, A1 = F.fresh('i'), F.fresh('i'), F.fresh('i')
                    pre += [['li', G, fmt_i(stv)], ['isub', A0, Sreg, G], ['imul', A1, A0, k]]
                    A = A1
                    if z != 1:
                        G2, A = F.fresh('i'), F.fresh('i')
                        pre += [['li', G2, fmt_i(z)], ['imul', A, A1, G2]]
                T1 = None
                if t:
                    consts.append(t[0] * z)
                    if t[0] * z == 1:
                        T1 = t[1]
                    else:
                        Z, T1 = F.fresh('i'), F.fresh('i')
                        pre += [['li', Z, fmt_i(t[0] * z)], ['imul', T1, t[1], Z]]
                if cint:
                    e = (c - stv * k) * z + (sv * k * z if folded else 0)
                    consts += [k * z, stv * k * z, c * z]
                else:
                    e = c * z
                consts.append(e)
                if not all(-FLIM <= v <= FLIM for v in consts):
                    continue
                cur = D
                if A:
                    Q1 = F.fresh('p')
                    pre.append(['padd', Q1, cur, A])
                    cur = Q1
                if T1:
                    Q2 = F.fresh('p')
                    pre.append(['padd', Q2, cur, T1])
                    cur = Q2
                if e != 0:
                    E, Q = F.fresh('i'), F.fresh('p')
                    pre += [['li', E, fmt_i(e)], ['padd', Q, cur, E]]
                    cur = Q
                assert cur != D, ('T7: Q would be D itself (5.8 gives no instruction)', F.name)
                if cint:
                    Dl = F.fresh('i')
                    pre.append(['li', Dl, fmt_i(stv * k * z)])
                else:
                    G3, Dl = F.fresh('i'), F.fresh('i')
                    pre += [['li', G3, fmt_i(stv * z)], ['imul', Dl, k, G3]]
                g = [[key, cur, Dl, pre]]
                groups += g
            g = g[0]
            acc[2:6] = [g[1], '-', '0', str(o)]
            acc.reduced = True
            F.log.append(('T7', F.name, bid, 'stride', ' '.join(acc)))
        if groups:
            L = find_x(F.recs, lp)
            ins = []
            for g in groups:
                for p in g[3]:
                    y = R(p)
                    y.placed = True
                    ins.append(y)
            tops = [R(['padd', g[1], g[1], g[2]]) for g in groups]
            F.recs = F.recs[:L] + ins + [F.recs[L]] + tops + F.recs[L + 1:]


# ---------------------------------------------------------------- T9
def specialize(seg, c, val):
    """L[c != 0] (val True) or L[c = 0]: each if on c by its first part, each ifz by its else
    part (and the opposite)."""
    st = St(seg)
    drop, out = set(), []
    for k, x in enumerate(seg):
        if x[0] in ('if', 'ifz') and x[2] == c:
            first = (x[0] == 'if') == val
            e, el = st.close[k], st.els.get(k)
            drop |= {k, e}
            if el is not None:
                drop.add(el)
                drop |= set(range(el + 1, e)) if first else set(range(k + 1, el))
            elif not first:
                drop |= set(range(k + 1, e))
    return [rcopy(x) for k, x in enumerate(seg) if k not in drop]


def split(F, bid, c):
    recs = F.recs
    st = St(recs)
    L = st.find(bid)
    C = st.close[L]
    seg = recs[L:C + 1]
    local = local_regs(recs, L, C)
    first = specialize(seg, c, True)
    second, sb = renamed_copy(F, specialize(seg, c, False), local)
    B = F.fresh_block()
    F.recs = recs[:L] + [R(['if', B, c])] + first + [R(['else', B])] + second \
        + [R(['endif', B])] + recs[C + 1:]
    return B, [x[1] for x in second if x[0] in LOOPS][0]


def t9(F):
    st = St(F.recs)
    inner = [F.recs[o][1] for o in range(len(F.recs)) if F.recs[o][0] in LOOPS
             and not any(F.recs[m][0] in LOOPS for m in range(o + 1, st.close[o]))
             and F.recs[o][1] not in F.slow]
    for bid in inner:
        recs = F.recs
        st, dead = St(recs), dead_mask(recs)
        L = st.find(bid)
        C = st.close[L]
        conds = []
        for k in range(L + 1, C):
            if recs[k][0] in ('if', 'ifz') and not dead[k]:
                c = recs[k][2]
                if not F.written_in(c, L, C) and c not in conds:
                    conds.append(c)
        conds = conds[:2]
        if not conds:
            continue
        B1, b2 = split(F, bid, conds[0])
        copies, outer = [bid, b2], B1
        if len(conds) == 2:
            # L-bt: a copy is split on c2 only when it still tests c2 after the first split
            copies = []
            for b in (bid, b2):
                s2 = St(F.recs)
                o = s2.find(b)
                if any(F.recs[m][0] in ('if', 'ifz') and F.recs[m][2] == conds[1]
                       for m in range(o + 1, s2.close[o])):
                    copies += [b, split(F, b, conds[1])[1]]
                else:
                    copies.append(b)
        F.log.append(('T9', F.name, bid, ' '.join(conds), len(copies)))
        place(F, outer, copies)


def place(F, outer, copies):
    """L-bm: the placement of T9's copies."""
    recs = F.recs
    st = St(recs)
    top = st.find(outer)
    where = st.part[top]
    spans = []
    for b in copies:
        o = st.find(b)
        spans.append((o, st.close[o]))

    def in_copy(m):
        return any(a <= m <= b for a, b in spans)

    dead = dead_mask(recs)
    cand = set()
    for k in range(1, top):
        x = recs[k]
        if x[0] in PURE and not dead[k] and st.contains(st.part[k], where) \
                and all(F.ndefs(d) == 1 for d in writes(x)):
            cand.add(k)
    changed = True
    while changed:
        changed = False
        dests = {d: k for k in cand for d in writes(recs[k])}
        for k in sorted(cand):
            x = recs[k]
            ok = all(in_copy(m) or m in cand for d in writes(x) for m, _ in F.readers(d))
            for r in [x[kk] for kk in reads(x)]:
                if r in dests:
                    continue
                if any(r in writes(recs[m]) for m in range(k + 1, top)):
                    ok = False
                for o in st.loops_in(top):
                    if not o < k < st.close[o] and F.written_in(r, o, st.close[o]):
                        ok = False
            if not ok:
                cand.discard(k)
                changed = True
    if not cand:
        return
    order = sorted(cand)
    orig = {k: rcopy(recs[k]) for k in order}
    dests = {d: k for k in order for d in writes(recs[k])}
    given, inserts, ndup = set(), [], 0
    for ci, (a, b) in enumerate(spans):
        need = set()
        work = [recs[m][kk] for m in range(a, b + 1) for kk in reads(recs[m])]
        while work:
            r = work.pop()
            if r in dests and dests[r] not in need:
                need.add(dests[r])
                work += [recs[dests[r]][kk] for kk in reads(recs[dests[r]])]
        ren, ins = {}, []
        for k in order:
            if k not in need:
                continue
            if k not in given:
                # the copy that needs I first receives I itself, reading this copy's
                # duplicates of the instructions earlier copies received
                given.add(k)
                for kk in reads(recs[k]):
                    recs[k][kk] = ren.get(orig[k][kk], orig[k][kk])
                ins.append(recs[k])
                continue
            y = rcopy(orig[k])
            for kk in reads(y):
                y[kk] = ren.get(y[kk], y[kk])
            for nm, kind, kk in layout(y):
                if kind in REGK and nm in ('d', 'e'):
                    ren[y[kk]] = F.fresh(y[kk][0])
                    y[kk] = ren[y[kk]]
            ins.append(y)
            ndup += 1
        for m in range(a, b + 1):
            for kk in reads(recs[m]):
                recs[m][kk] = ren.get(recs[m][kk], recs[m][kk])
        inserts.append((recs[a], ins))
    out = [x for k, x in enumerate(recs) if k not in cand]
    for obj, ins in inserts:
        at = find_x(out, obj)
        out[at:at] = ins
    F.recs = out
    F.log.append(('T9', F.name, 'place', len(cand), ndup))


def sealopt(text, log):
    """sea.lir2 -> sea.lir as 5c-2's sealopt writes it: T5, T6, T8, T7, T8, T9, T10, renumbered."""
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
                F = Fn(fn, fn[0][1], log)
                t5(F)
                t6(F)
                t8(F, 1)
                t7(F)
                t8(F, 2)
                t9(F)
                recs = t10([list(x) for x in F.recs], F.name, log)
                out += [' '.join(x) for x in renumber(recs)]
                fn = None
        else:
            out.append(ln)
    return '\n'.join(out + ['#end']) + '\n'


# ================================================================ the cases
# Each case: NAME.sea, its NAME.lir1 (the input, from the phase-4 passes), EVENTS[NAME] and
# EVENTS2[NAME], the transformations derived by hand (5.8) that the model must make.
# EVENTS (seaopt, sea.lir2): T1 checks deleted (del) and checked arithmetic made wrapping (wrap),
# T2 divisions, T3 loads replaced by a register (load, with the register), T4 ifs converted (and
# `kept` for an if L-bq leaves), T10 deletions of a mov R R, an empty if or a retain/release pair.
# (T3 rule 1 sharing, copy propagation and T10 deletions of unread values follow from these in
# each derivation note.) EVENTS2 (sealopt, sea.lir; registers and blocks named as in sea.lir2, a
# block of a copy as `nK`): T5 locations promoted per loop (`promote`, block, P off, stored)
# and destination rewritings (`dest`, the register V), T6 loops versioned (block, the cowed
# arrays: a register or P off) or `kept`, T8 per pass and loop the instructions moved and
# commoned, T7 each access reduced (as rewritten, `unit` or `stride`), T9 each loop split (the
# conditions, the number of copies) and its placement (instructions placed, duplicates), T10
# deletions as above. (Copy propagation of T5 and what T10 deletes follow in each note.)
CASES = {}
EVENTS = {}
EVENTS2 = {}


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
# sealopt (5c-2): each loop of fill and back versioned (T6, register form, on u and w); the
# fast copies' data addresses, extents and constants hoisted (T8), the slow copies' constants.
EVENTS2['opt5_bce_range'] = [
    ('T6', 'fill', 'version', '2', 'p4'),
    ('T6', 'fill', 'version', '5', 'p4'),
    ('T8', 'fill', 1, '2', 3, 0),
    ('T8', 'fill', 1, 'n2', 2, 0),
    ('T8', 'fill', 1, '5', 5, 1),
    ('T8', 'fill', 1, 'n5', 2, 0),
    ('T6', 'back', 'version', '2', 'p4'),
    ('T6', 'back', 'version', '5', 'p4'),
    ('T8', 'back', 1, '2', 2, 0),
    ('T8', 'back', 1, 'n2', 1, 0),
    ('T8', 'back', 1, '5', 3, 1),
    ('T8', 'back', 1, 'n5', 1, 0),
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
# sealopt: T8 hoists 18 invariant instructions of pick's loop (8 commoned: the repeated 0, 8,
# data address and k < 8); T9 splits it on k >= 0 and k < 8 into four copies and places k < 0, the
# 7, k <= 7 and the 3 (12 duplicates).
EVENTS2['opt5_bce_dom'] = [
    ('T8', 'pick', 1, '2', 18, 8),
    ('T9', 'pick', '2', 'i13 i15', 4),
    ('T9', 'pick', 'place', 4, 12),
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
# sealopt: T8 hoists 5 instructions out of the loop of `if n >= 8` (1 commoned); T9 splits the
# loop on n >= 8 (two copies).
EVENTS2['opt5_bce_sym'] = [
    ('T8', 'sym', 1, '7', 5, 1),
    ('T9', 'sym', '7', 'i30', 2),
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
# sealopt: (p1, 16) and (p2, 16) promoted (T5, read only); the data addresses and a constant
# hoisted.
EVENTS2['opt5_bce_passed'] = [
    ('T5', 'twice', 'promote', '2', 'p1 16', False),
    ('T5', 'twice', 'promote', '2', 'p2 16', False),
    ('T8', 'twice', 1, '2', 3, 0),
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
# sealopt: edges's (p1, 16) promoted in both loops; T7 reduces v[i + 1] and v[i - 1] (e = 8,
# -8) and T8's second pass hoists what it adds; grow's loop is versioned on the memory form at
# (p1, 0) (L-bs: T3's `mov p15 p9`, the cow's leading load, is part of the cow): in the fast copy
# T8 hoists the loads of u (no store to (p1, 0) is left), the `mov`, the data addresses ((a):
# anticipated, object pointers) and the extent (3 commoned); the slow copy's constants.
EVENTS2['opt5_bce_kept'] = [
    ('T5', 'edges', 'promote', '2', 'p1 16', False),
    ('T5', 'edges', 'promote', '4', 'p1 16', False),
    ('T8', 'edges', 1, '2', 2, 0),
    ('T8', 'edges', 1, '4', 1, 0),
    ('T7', 'edges', '2', 'unit', 'ldf f13 p28 i8 8 0'),
    ('T7', 'edges', '2', 'unit', 'ldf f16 p30 i8 8 0'),
    ('T8', 'edges', 2, '2', 4, 0),
    ('T6', 'grow', 'version', '2', 'p1 0'),
    ('T8', 'grow', 1, '2', 10, 3),
    ('T8', 'grow', 1, 'n2', 2, 0),
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
# sealopt: T8 hoists the data address out of loop 3 and `li 100`, `li 1`, `li 5`, `li 0` and
# the data address out of the do loop.
EVENTS2['opt5_bce_scope'] = [
    ('T8', 'scope', 1, '3', 1, 0),
    ('T8', 'scope', 1, '4', 5, 0),
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
# sealopt: T8 hoists 5 instructions out of eqs's loop (2 commoned).
EVENTS2['opt5_bce_eq'] = [
    ('T8', 'eqs', 1, '6', 5, 2),
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
# sealopt: T8 hoists the constants of each loop.
EVENTS2['opt5_ovf'] = [
    ('T8', 'ovf', 1, '2', 1, 0),
    ('T8', 'ovf', 1, '4', 2, 0),
    ('T8', 'ovf', 1, '6', 1, 0),
    ('T8', 'ovf', 1, '8', 1, 0),
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
# sealopt: T8 hoists 7 instructions; T9 splits the loop on k >= 0, then the k >= 0 copy on
# k < 10 (L-bt: the k < 0 copy tests k < 10 no more and is not split): three copies; the five
# constants and three adds placed into the first copy's arm.
EVENTS2['opt5_ovf_const'] = [
    ('T8', 'big', 1, '2', 7, 0),
    ('T9', 'big', '2', 'i15 i17', 3),
    ('T9', 'big', 'place', 8, 0),
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
# sealopt: T8 hoists the 48 invariant instructions (the sequences on a; 1 commoned); T9 splits
# the loop on b < 0 and places 45 of them into both arms.
EVENTS2['opt5_div'] = [
    ('T8', 'divs', 1, '2', 48, 1),
    ('T9', 'divs', '2', 'i67', 2),
    ('T9', 'divs', 'place', 45, 45),
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
# sealopt: T8 hoists the 14 invariant instructions.
EVENTS2['opt5_fdiv'] = [
    ('T8', 'fdivs', 1, '2', 14, 0),
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
# sealopt: T8 hoists the 5 invariant instructions.
EVENTS2['opt5_vn'] = [
    ('T8', 'vn', 1, '2', 5, 0),
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
# sealopt: (p1, 16) and m's (p2, 0) promoted (T5: m's iaddc writes the register, one post-store
# after the loop); T8 hoists the itof of the extent, the sa, la, data address and constants.
EVENTS2['opt5_rle'] = [
    ('T5', 'rle', 'promote', '2', 'p1 16', False),
    ('T5', 'rle', 'promote', '2', 'p2 0', True),
    ('T5', 'rle', 'dest', '2', 'i28'),
    ('T8', 'rle', 1, '2', 6, 0),
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
# sealopt: T8 hoists 10 instructions (1 commoned); T9 splits the loop on x < y (the test of the
# ifx whose else arm is an lf) and places 9 instructions into both arms.
EVENTS2['opt5_ifconv'] = [
    ('T8', 'sel', 1, '2', 10, 1),
    ('T9', 'sel', '2', 'i25', 2),
    ('T9', 'sel', 'place', 9, 9),
]


# ---------------------------------------------------------------- opt5_clean
# clean: x * 2.0 + v[0] unused: fadd, fmul, the lf, the element load and the data address
# deleted (the chkb and the extent load stay); a + 1 unused but checked (iaddc stays); `k = k`
# (mov i10 i10) deleted, then k's `mov i10 i2`; `if a > i { z = x + 1.0 }`: fadd and lf deleted,
# then the empty if and its icmp; `retain p8` / `release p8` before `ret 1 p8`. s (f9) is read
# only by its own add, which T10 does not count (L-bn, from 5c-2): the fadd is deleted, then s's
# `mov f9 f3`.
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
// the retain/release pair of `return u`; s, read only by its own add, is deleted with its
// initial mov (L-bn: an instruction's read of its own destination does not count)
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
# sealopt: (p1, 16) promoted (read only); T8 hoists 2 instructions.
EVENTS2['opt5_clean'] = [
    ('T5', 'clean', 'promote', '2', 'p1 16', False),
    ('T8', 'clean', 1, '2', 2, 0),
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
# sealopt: T8 hoists 3 instructions out of the loop; the records after exit and ret stay.
EVENTS2['opt5_dead'] = [
    ('T8', 'dead', 1, '2', 3, 0),
]


# ---------------------------------------------------------------- opt5_promote
# tally, loop 2: the private locations of the loop, in the order of their first access: (p1, 0)
# (the `ref` m: a parameter used only as a base without idx), (p4, 0) and (p4, 8) (a.sum, a.n: the
# slot s1, its `sa p4` outside the loop) and (p2, 16) (v's extent, read only): pre-loads before the
# loop; the loads become movs that copy propagation removes; the stores' movs are removed by
# destination rewriting (iaddc, fadd and iaddc write the registers); post-stores of the three
# stored locations after endloop 2. Loop 4 promotes (p1, 0) and (p4, 8), read only: pre-loads, no
# post-store. T8 hoists v's data address (p2 private, (c)) and the `li 1`. twice: x promoted, its
# iaddc rewritten. kept: m is a call argument (no private base): no T5; T8 hoists the `li 1` only
# (the load of m may be changed by the call).
CASES['opt5_promote'] = (r"""struct Acc {
    sum: f64
    n: i64
}
fn tally(ref m: i64, v: f64[], k: i64) -> f64 {
    var a = Acc { sum: 0.0, n: 0 }
    for i in 0..k {
        m = m + i
        a.sum = a.sum + v[i]
        a.n = a.n + 1
    }
    var t = 0
    for i in 0..k {
        t = t + m * a.n
    }
    return a.sum + f64(t)
}
fn twice(ref x: i64, k: i64) -> i64 {
    for i in 0..k {
        x = x + 2
    }
    return x
}
fn kept(ref m: i64, k: i64) -> i64 {
    var r = 0
    for i in 0..k {
        m = m + 1
        r = r + twice(ref m, i)
    }
    return r
}
var m = 3
let v = [0.5, 1.5, 2.5]
printf("%g %g %d\n", tally(ref m, v, 3), tally(ref m, v, 2), m)
printf("%d %d %d %d\n", kept(ref m, 2), kept(ref m, 3), twice(ref m, 1), m)
// opt5_promote -- DESIGN.md 5.8 T5: the `ref` scalar m and the struct fields a.sum (f64) and
// a.n of a slot promoted in tally's first loop (pre-loads, the updates written straight into
// the registers by destination rewriting, post-stores after the loop), read-only locations in
// its second loop (pre-loads only); in kept, m is passed to a call (not a private base): stays
""", r"""#sea 1
#target arm64-macos
#file opt5_promote.sea
func .main main 0:1:1 0 0
slot s1 24 8
slot s2 24 8
slot s3 8 8
slot s4 8 8
slot s5 24 8
slot s6 8 8
slot s7 8 8
slot s8 8 8
slot s9 32 8
li i1 3
sa p2 s1
sa p3 s2
lf f4 #3FE0000000000000
stf f4 p3 - 0 0
lf f5 #3FF8000000000000
stf f5 p3 - 0 8
lf f6 #4004000000000000
stf f6 p3 - 0 16
li i7 24
mcopy p2 p3 i7
sa p8 s3
sti i1 p8 - 0 0
li i9 3
li i10 1
li i11 1
li i12 1
rcall sea_arr_new_u 0:34 1 p13 4 i10 i11 i9 i12
ldp p14 p13 - 0 40
li i15 24
mcopy p14 p2 i15
li i16 3
call tally 1 f17 3 p8 p13 i16
ldi i1 p8 - 0 0
release p13
sa p18 s4
sti i1 p18 - 0 0
li i19 3
li i20 1
li i21 1
li i22 1
rcall sea_arr_new_u 0:34 1 p23 4 i20 i21 i19 i22
ldp p24 p23 - 0 40
li i25 24
mcopy p24 p2 i25
li i26 2
call tally 1 f27 3 p18 p23 i26
ldi i1 p18 - 0 0
release p23
sa p28 s5
stf f17 p28 - 0 0
stf f27 p28 - 0 8
sti i1 p28 - 0 16
la p29 d1
rcall sea_printf 0:34 0 2 p29 p28
sa p30 s6
sti i1 p30 - 0 0
li i31 2
call kept 1 i32 2 p30 i31
ldi i1 p30 - 0 0
sa p33 s7
sti i1 p33 - 0 0
li i34 3
call kept 1 i35 2 p33 i34
ldi i1 p33 - 0 0
sa p36 s8
sti i1 p36 - 0 0
li i37 1
call twice 1 i38 2 p36 i37
ldi i1 p36 - 0 0
sa p39 s9
sti i32 p39 - 0 0
sti i35 p39 - 0 8
sti i38 p39 - 0 16
sti i1 p39 - 0 24
la p40 d2
rcall sea_printf 0:35 0 2 p40 p39
ret 0
endfunc
func tally fn 0:5:1 3 p1 p2 i3 1 f
slot s1 16 8
sa p4 s1
lf f5 #0000000000000000
stf f5 p4 - 0 0
li i6 0
sti i6 p4 - 0 8
li i7 0
li i8 1
rcount i9 i10 i7 i3 i8 0 0:7
if 1 i10
loop 2 i11 i7 i9 i8
ldi i12 p1 - 0 0
iaddc i13 i12 i11 0:8
sti i13 p1 - 0 0
ldf f14 p4 - 0 0
ldi i15 p2 - 0 16
chkb i11 i15 0 0:9
ldp p16 p2 - 0 40
ldf f17 p16 i11 8 0
fadd f18 f14 f17
stf f18 p4 - 0 0
ldi i19 p4 - 0 8
li i20 1
iaddc i21 i19 i20 0:10
sti i21 p4 - 0 8
endloop 2
endif 1
li i22 0
li i23 0
li i24 1
rcount i25 i26 i23 i3 i24 0 0:13
if 3 i26
loop 4 i27 i23 i25 i24
ldi i28 p1 - 0 0
ldi i29 p4 - 0 8
imulc i30 i28 i29 0:14
iaddc i22 i22 i30 0:14
endloop 4
endif 3
ldf f31 p4 - 0 0
itof f32 i22
fadd f33 f31 f32
ret 1 f33
endfunc
func twice fn 0:18:1 2 p1 i2 1 i
li i3 0
li i4 1
rcount i5 i6 i3 i2 i4 0 0:19
if 1 i6
loop 2 i7 i3 i5 i4
ldi i8 p1 - 0 0
li i9 2
iaddc i10 i8 i9 0:20
sti i10 p1 - 0 0
endloop 2
endif 1
ldi i11 p1 - 0 0
ret 1 i11
endfunc
func kept fn 0:24:1 2 p1 i2 1 i
li i3 0
li i4 0
li i5 1
rcount i6 i7 i4 i2 i5 0 0:26
if 1 i7
loop 2 i8 i4 i6 i5
ldi i9 p1 - 0 0
li i10 1
iaddc i11 i9 i10 0:27
sti i11 p1 - 0 0
call twice 1 i12 2 p1 i8
iaddc i3 i3 i12 0:28
endloop 2
endif 1
ret 1 i3
endfunc
fmt d1 6
fconv - - - g f
ftext %20
fconv - - - g f
ftext %20
fconv - - - d i
ftext %0A
fmt d2 8
fconv - - - d i
ftext %20
fconv - - - d i
ftext %20
fconv - - - d i
ftext %20
fconv - - - d i
ftext %0A
#end
""")
EVENTS['opt5_promote'] = [
]
EVENTS2['opt5_promote'] = [
    ('T5', 'tally', 'promote', '2', 'p1 0', True),
    ('T5', 'tally', 'promote', '2', 'p4 0', True),
    ('T5', 'tally', 'promote', '2', 'p2 16', False),
    ('T5', 'tally', 'promote', '2', 'p4 8', True),
    ('T5', 'tally', 'dest', '2', 'i34'),
    ('T5', 'tally', 'dest', '2', 'f35'),
    ('T5', 'tally', 'dest', '2', 'i37'),
    ('T5', 'tally', 'promote', '4', 'p1 0', False),
    ('T5', 'tally', 'promote', '4', 'p4 8', False),
    ('T8', 'tally', 1, '2', 2, 0),
    ('T5', 'twice', 'promote', '2', 'p1 0', True),
    ('T5', 'twice', 'dest', '2', 'i12'),
    ('T8', 'twice', 1, '2', 1, 0),
    ('T8', 'kept', 1, '2', 1, 0),
]


# ---------------------------------------------------------------- opt5_promote_exit
# walk: (p1, 0) is promoted in the outer loop 2 (outermost first); its post-stores stand before
# the `ret` inside the inner loop 4 (a ret in L) and after endloop 2; loop 4 then stores (p1, 0)
# but does not promote it again (promoted in an enclosing loop). T8 hoists `li -1` out of loop
# 4's if part and, with `li 0` and `li 1`, out of loop 2. runs: the `sa p9` stands in loop 2, so
# (p9, 0) and (p9, 8) are promoted in loop 4 only (P invariant in L): the `exit 4` of the break
# and the normal end meet the post-stores after endloop 4; `next 4` names L itself (no store);
# loop 2's `next 2` follows them. T8 then hoists the `sa` (pure) and the constants out of loop 2.
# Sea's `continue` names the innermost loop (LANGUAGE.md 7), so no `next` in L names a loop
# enclosing L in source without prelude inlining.
CASES['opt5_promote_exit'] = (r"""struct Acc {
    sum: f64
    n: i64
}
fn walk(ref s: i64, n: i64, lim: i64) -> i64 {
    for i in 0..n {
        for j in 0..n {
            s = s + j
            if s > lim {
                return -1
            }
        }
    }
    return s
}
fn runs(n: i64, lim: f64) -> f64 {
    var t = 0.0
    for i in 0..n {
        var a = Acc { sum: 0.0, n: i }
        for j in 0..n {
            a.sum = a.sum + f64(j)
            if a.sum > lim {
                break
            }
            if j == i {
                continue
            }
            a.n = a.n + 1
        }
        if a.n > 2 {
            continue
        }
        t = t + a.sum + f64(a.n)
    }
    return t
}
var s = 0
printf("%d %d %d\n", walk(ref s, 3, 100), walk(ref s, 4, 20), s)
printf("%g %g\n", runs(3, 2.5), runs(4, 100.0))
// opt5_promote_exit -- DESIGN.md 5.8 T5 with exits: walk's s promoted in the outer loop, its
// post-store before the `return` inside the inner loop and after the outer loop (the inner loop,
// which then stores s, does not promote it again); runs's struct a (a slot whose `sa` stands in
// the outer loop) promoted in the inner loop only: a `break` (exit of that loop) arrives after
// its closing record with the post-stores, its `continue` stays inside it, and the outer
// loop's `continue` follows them
""", r"""#sea 1
#target arm64-macos
#file opt5_promote_exit.sea
func .main main 0:1:1 0 0
slot s1 8 8
slot s2 8 8
slot s3 24 8
slot s4 16 8
li i1 0
sa p2 s1
sti i1 p2 - 0 0
li i3 3
li i4 100
call walk 1 i5 3 p2 i3 i4
ldi i1 p2 - 0 0
sa p6 s2
sti i1 p6 - 0 0
li i7 4
li i8 20
call walk 1 i9 3 p6 i7 i8
ldi i1 p6 - 0 0
sa p10 s3
sti i5 p10 - 0 0
sti i9 p10 - 0 8
sti i1 p10 - 0 16
la p11 d1
rcall sea_printf 0:38 0 2 p11 p10
li i12 3
lf f13 #4004000000000000
call runs 1 f14 2 i12 f13
li i15 4
lf f16 #4059000000000000
call runs 1 f17 2 i15 f16
sa p18 s4
stf f14 p18 - 0 0
stf f17 p18 - 0 8
la p19 d2
rcall sea_printf 0:39 0 2 p19 p18
ret 0
endfunc
func walk fn 0:5:1 3 p1 i2 i3 1 i
li i4 0
li i5 1
rcount i6 i7 i4 i2 i5 0 0:6
if 1 i7
loop 2 i8 i4 i6 i5
li i9 0
li i10 1
rcount i11 i12 i9 i2 i10 0 0:7
if 3 i12
loop 4 i13 i9 i11 i10
ldi i14 p1 - 0 0
iaddc i15 i14 i13 0:8
sti i15 p1 - 0 0
ldi i16 p1 - 0 0
icmp gt i17 i16 i3
if 5 i17
li i18 -1
ret 1 i18
endif 5
endloop 4
endif 3
endloop 2
endif 1
ldi i19 p1 - 0 0
ret 1 i19
endfunc
func runs fn 0:16:1 2 i1 f2 1 f
slot s1 16 8
lf f3 #0000000000000000
li i4 0
li i5 1
rcount i6 i7 i4 i1 i5 0 0:18
if 1 i7
loop 2 i8 i4 i6 i5
sa p9 s1
lf f10 #0000000000000000
stf f10 p9 - 0 0
sti i8 p9 - 0 8
li i11 0
li i12 1
rcount i13 i14 i11 i1 i12 0 0:20
if 3 i14
loop 4 i15 i11 i13 i12
ldf f16 p9 - 0 0
itof f17 i15
fadd f18 f16 f17
stf f18 p9 - 0 0
ldf f19 p9 - 0 0
fcmp gt i20 f19 f2
if 5 i20
exit 4
endif 5
icmp eq i21 i15 i8
if 6 i21
next 4
endif 6
ldi i22 p9 - 0 8
li i23 1
iaddc i24 i22 i23 0:28
sti i24 p9 - 0 8
endloop 4
endif 3
ldi i25 p9 - 0 8
li i26 2
icmp gt i27 i25 i26
if 7 i27
next 2
endif 7
ldf f28 p9 - 0 0
fadd f29 f3 f28
ldi i30 p9 - 0 8
itof f31 i30
fadd f3 f29 f31
endloop 2
endif 1
ret 1 f3
endfunc
fmt d1 6
fconv - - - d i
ftext %20
fconv - - - d i
ftext %20
fconv - - - d i
ftext %0A
fmt d2 4
fconv - - - g f
ftext %20
fconv - - - g f
ftext %0A
#end
""")
EVENTS['opt5_promote_exit'] = [
    ('T3', 'walk', 'load', 'ldi i16 p1 - 0 0', 'i15'),
    ('T3', 'runs', 'load', 'ldf f19 p9 - 0 0', 'f18'),
]
EVENTS2['opt5_promote_exit'] = [
    ('T5', 'walk', 'promote', '2', 'p1 0', True),
    ('T5', 'walk', 'dest', '2', 'i19'),
    ('T8', 'walk', 1, '4', 1, 0),
    ('T8', 'walk', 1, '2', 3, 0),
    ('T5', 'runs', 'promote', '4', 'p9 0', True),
    ('T5', 'runs', 'promote', '4', 'p9 8', True),
    ('T5', 'runs', 'dest', '4', 'f31'),
    ('T5', 'runs', 'dest', '4', 'i32'),
    ('T8', 'runs', 1, '4', 1, 0),
    ('T8', 'runs', 1, '2', 6, 1),
]


# ---------------------------------------------------------------- opt5_cow
# pair: u (p4) and w (p5) are cowed in loop 2; u's copy set is p4, its cow's p17 and keep (p6,
# `mov p6 p4` before the loop), used in the loop only as bases; w's is p5 and p26: the loop is
# versioned on both (two counts, `icmp eq`, one `iand`); the fast copy has no cow, its data
# addresses and keep's extent hoisted by T8 (the second ldp of u commoned); the slow copy's
# registers renumbered (L-bl). table: the outer loop 2 is the outermost loop containing g's cow:
# versioned; in the fast copy T8 hoists the header loads and `imul i24 i10 i18` out of loop 4,
# T7 reduces g[i, j] (J + t, z = 8), T8's second pass hoists T7's li/imul/padd out of loop 4 and
# the `li 8` out of loop 2.
CASES['opt5_cow'] = (r"""fn pair(n: i64, k: f64) -> f64 {
    var u = zeros(n)
    var w = zeros(n)
    let keep = u
    for i in 0..n {
        u[i] = k * f64(i)
        w[i] = u[i] + keep[i]
    }
    return u[n - 1] + w[n - 1] + keep[n - 1]
}
fn table(n: i64, m: i64) -> f64 {
    var g = zeros(n, m)
    for j in 0..m {
        for i in 0..n {
            g[i, j] = f64(i + j)
        }
    }
    return g[n - 1, m - 1]
}
printf("%g %g\n", pair(3, 0.5), pair(4, 2.0))
printf("%g %g\n", table(2, 3), table(3, 4))
// opt5_cow -- DESIGN.md 5.8 T6, register form: pair's loop versioned on u and w (two counts
// tested, iand); keep shares u's buffer and is used only as a base in the loop, so the copy
// is made but the slow copy runs; table's outer loop is the outermost containing the cow and
// is versioned, its fast copy's header loads hoisted (T8) and g's column address reduced (T7)
""", r"""#sea 1
#target arm64-macos
#file opt5_cow.sea
func .main main 0:1:1 0 0
slot s1 16 8
slot s2 16 8
li i1 3
lf f2 #3FE0000000000000
call pair 1 f3 2 i1 f2
li i4 4
lf f5 #4000000000000000
call pair 1 f6 2 i4 f5
sa p7 s1
stf f3 p7 - 0 0
stf f6 p7 - 0 8
la p8 d1
rcall sea_printf 0:20 0 2 p8 p7
li i9 2
li i10 3
call table 1 f11 2 i9 i10
li i12 3
li i13 4
call table 1 f14 2 i12 i13
sa p15 s2
stf f11 p15 - 0 0
stf f14 p15 - 0 8
la p16 d2
rcall sea_printf 0:21 0 2 p16 p15
ret 0
endfunc
func pair fn 0:1:1 2 i1 f2 1 f
li i3 1
li i4 1
li i5 1
rcall sea_arr_new 0:2 1 p6 4 i3 i4 i1 i5
li i7 1
li i8 1
li i9 1
rcall sea_arr_new 0:3 1 p10 4 i7 i8 i1 i9
mov p11 p6
retain p11
li i12 0
li i13 1
rcount i14 i15 i12 i1 i13 0 0:5
if 1 i15
loop 2 i16 i12 i14 i13
itof f17 i16
fmul f18 f2 f17
ldi i19 p6 - 0 16
chkb i16 i19 0 0:6
ldi i20 p6 - 0 0
li i21 1
icmp ne i22 i20 i21
if 3 i22
rcall sea_arr_unique 0:6 1 p23 1 p6
mov p6 p23
endif 3
ldp p24 p6 - 0 40
stf f18 p24 i16 8 0
ldi i25 p6 - 0 16
chkb i16 i25 0 0:7
ldp p26 p6 - 0 40
ldf f27 p26 i16 8 0
ldi i28 p11 - 0 16
chkb i16 i28 0 0:7
ldp p29 p11 - 0 40
ldf f30 p29 i16 8 0
fadd f31 f27 f30
ldi i32 p10 - 0 16
chkb i16 i32 0 0:7
ldi i33 p10 - 0 0
li i34 1
icmp ne i35 i33 i34
if 4 i35
rcall sea_arr_unique 0:7 1 p36 1 p10
mov p10 p36
endif 4
ldp p37 p10 - 0 40
stf f31 p37 i16 8 0
endloop 2
endif 1
li i38 1
isubc i39 i1 i38 0:9
ldi i40 p6 - 0 16
chkb i39 i40 0 0:9
ldp p41 p6 - 0 40
ldf f42 p41 i39 8 0
li i43 1
isubc i44 i1 i43 0:9
ldi i45 p10 - 0 16
chkb i44 i45 0 0:9
ldp p46 p10 - 0 40
ldf f47 p46 i44 8 0
fadd f48 f42 f47
li i49 1
isubc i50 i1 i49 0:9
ldi i51 p11 - 0 16
chkb i50 i51 0 0:9
ldp p52 p11 - 0 40
ldf f53 p52 i50 8 0
fadd f54 f48 f53
release p11
release p10
release p6
ret 1 f54
endfunc
func table fn 0:11:1 2 i1 i2 1 f
li i3 1
li i4 2
rcall sea_arr_new 0:12 1 p5 4 i3 i4 i1 i2
li i6 0
li i7 1
rcount i8 i9 i6 i2 i7 0 0:13
if 1 i9
loop 2 i10 i6 i8 i7
li i11 0
li i12 1
rcount i13 i14 i11 i1 i12 0 0:14
if 3 i14
loop 4 i15 i11 i13 i12
iaddc i16 i15 i10 0:15
itof f17 i16
ldi i18 p5 - 0 16
chkb i15 i18 0 0:15
ldi i19 p5 - 0 24
chkb i10 i19 1 0:15
ldi i20 p5 - 0 0
li i21 1
icmp ne i22 i20 i21
if 5 i22
rcall sea_arr_unique 0:15 1 p23 1 p5
mov p5 p23
endif 5
ldp p24 p5 - 0 40
imul i25 i10 i18
iadd i26 i15 i25
stf f17 p24 i26 8 0
endloop 4
endif 3
endloop 2
endif 1
li i27 1
isubc i28 i1 i27 0:18
li i29 1
isubc i30 i2 i29 0:18
ldi i31 p5 - 0 16
chkb i28 i31 0 0:18
ldi i32 p5 - 0 24
chkb i30 i32 1 0:18
ldp p33 p5 - 0 40
imul i34 i30 i31
iadd i35 i28 i34
ldf f36 p33 i35 8 0
release p5
ret 1 f36
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
EVENTS['opt5_cow'] = [
    ('T1', 'pair', 'del', 'chkb i16 i19 0 0:6'),
    ('T1', 'pair', 'del', 'chkb i16 i25 0 0:7'),
    ('T1', 'pair', 'del', 'chkb i16 i32 0 0:7'),
    ('T1', 'pair', 'wrap', 'isubc i39 i1 i38 0:9'),
    ('T1', 'pair', 'wrap', 'isubc i44 i1 i43 0:9'),
    ('T1', 'pair', 'wrap', 'isubc i50 i1 i49 0:9'),
    ('T3', 'pair', 'load', 'ldp p26 p6 - 0 40', 'p24'),
    ('T3', 'pair', 'load', 'ldf f27 p24 i16 8 0', 'f18'),
    ('T1', 'table', 'wrap', 'iaddc i16 i15 i10 0:15'),
    ('T1', 'table', 'del', 'chkb i15 i18 0 0:15'),
    ('T1', 'table', 'del', 'chkb i10 i19 1 0:15'),
    ('T1', 'table', 'wrap', 'isubc i28 i1 i27 0:18'),
    ('T1', 'table', 'wrap', 'isubc i30 i2 i29 0:18'),
]
EVENTS2['opt5_cow'] = [
    ('T6', 'pair', 'version', '2', 'p4, p5'),
    ('T8', 'pair', 1, '2', 6, 1),
    ('T8', 'pair', 1, 'n2', 4, 1),
    ('T6', 'table', 'version', '2', 'p5'),
    ('T8', 'table', 1, '4', 4, 0),
    ('T8', 'table', 1, '2', 5, 1),
    ('T8', 'table', 1, 'n4', 1, 0),
    ('T8', 'table', 1, 'n2', 3, 1),
    ('T7', 'table', '4', 'unit', 'stf f17 p56 i15 8 0'),
    ('T8', 'table', 2, '4', 3, 0),
    ('T8', 'table', 2, '2', 1, 0),
]


# ---------------------------------------------------------------- opt5_cow_ref
# fill and scale: the cow of v is the memory form at (p1, 0); T3 (pass 3b) has replaced the cow's
# `ldp p12 p1 - 0 0` by `mov p12 p10` (the load of the bounds check before it), which L-bs counts
# as part of the cow: p10, p12 and the cow's result are used in the loop only as bases and by the
# cow, so each loop is versioned (`ldp A1 p1 - 0 0`, `ldi C1 A1 - 0 0`, li, icmp eq). In the fast
# copy no store to (p1, 0) is left: T8 hoists the loads of v ((c), p1 private), the `mov`, the
# extent and the data addresses ((a)); the slow copy hoists its `li 1`.
CASES['opt5_cow_ref'] = (r"""fn fill(ref v: f64[], k: f64) {
    for i in 0..len(v) {
        v[i] = k
    }
}
fn scale(ref v: f64[], k: f64) {
    for i in 0..len(v) {
        v[i] = v[i] * k
    }
}
var a = zeros(3)
let b = a
fill(ref a, 0.5)
scale(ref a, 4.0)
var c = zeros(2)
fill(ref c, 1.5)
scale(ref c, 3.0)
printf("%g %g %g %g\n", a[2], b[2], c[0], c[1])
// opt5_cow_ref -- DESIGN.md 5.8 T6, memory form at the private location (p1, 0) of a `ref`
// array: T3 has made the cow's load of v a `mov` of the load before the bounds check, part of
// the cow (L-bs); both loops are versioned, the fast copies' loads of v hoisted (T8)
""", r"""#sea 1
#target arm64-macos
#file opt5_cow_ref.sea
func .main main 0:1:1 0 0
slot s1 8 8
slot s2 8 8
slot s3 8 8
slot s4 8 8
slot s5 32 8
li i1 3
li i2 1
li i3 1
li i4 1
rcall sea_arr_new 0:11 1 p5 4 i2 i3 i1 i4
mov p6 p5
retain p6
sa p7 s1
stp p5 p7 - 0 0
lf f8 #3FE0000000000000
call fill 0 2 p7 f8
ldp p5 p7 - 0 0
sa p9 s2
stp p5 p9 - 0 0
lf f10 #4010000000000000
call scale 0 2 p9 f10
ldp p5 p9 - 0 0
li i11 2
li i12 1
li i13 1
li i14 1
rcall sea_arr_new 0:15 1 p15 4 i12 i13 i11 i14
sa p16 s3
stp p15 p16 - 0 0
lf f17 #3FF8000000000000
call fill 0 2 p16 f17
ldp p15 p16 - 0 0
sa p18 s4
stp p15 p18 - 0 0
lf f19 #4008000000000000
call scale 0 2 p18 f19
ldp p15 p18 - 0 0
li i20 2
ldi i21 p5 - 0 16
chkb i20 i21 0 0:18
ldp p22 p5 - 0 40
ldf f23 p22 i20 8 0
li i24 2
ldi i25 p6 - 0 16
chkb i24 i25 0 0:18
ldp p26 p6 - 0 40
ldf f27 p26 i24 8 0
li i28 0
ldi i29 p15 - 0 16
chkb i28 i29 0 0:18
ldp p30 p15 - 0 40
ldf f31 p30 i28 8 0
li i32 1
ldi i33 p15 - 0 16
chkb i32 i33 0 0:18
ldp p34 p15 - 0 40
ldf f35 p34 i32 8 0
sa p36 s5
stf f23 p36 - 0 0
stf f27 p36 - 0 8
stf f31 p36 - 0 16
stf f35 p36 - 0 24
la p37 d1
rcall sea_printf 0:18 0 2 p37 p36
release p15
release p6
release p5
ret 0
endfunc
func fill fn 0:1:1 2 p1 f2 0
li i3 0
ldp p4 p1 - 0 0
ldi i5 p4 - 0 16
li i6 1
rcount i7 i8 i3 i5 i6 0 0:2
if 1 i8
loop 2 i9 i3 i7 i6
ldp p10 p1 - 0 0
ldi i11 p10 - 0 16
chkb i9 i11 0 0:3
ldp p12 p1 - 0 0
ldi i13 p12 - 0 0
li i14 1
icmp ne i15 i13 i14
if 3 i15
rcall sea_arr_unique 0:3 1 p16 1 p12
stp p16 p1 - 0 0
mov p12 p16
endif 3
ldp p17 p12 - 0 40
stf f2 p17 i9 8 0
endloop 2
endif 1
ret 0
endfunc
func scale fn 0:6:1 2 p1 f2 0
li i3 0
ldp p4 p1 - 0 0
ldi i5 p4 - 0 16
li i6 1
rcount i7 i8 i3 i5 i6 0 0:7
if 1 i8
loop 2 i9 i3 i7 i6
ldp p10 p1 - 0 0
ldi i11 p10 - 0 16
chkb i9 i11 0 0:8
ldp p12 p10 - 0 40
ldf f13 p12 i9 8 0
fmul f14 f13 f2
ldp p15 p1 - 0 0
ldi i16 p15 - 0 16
chkb i9 i16 0 0:8
ldp p17 p1 - 0 0
ldi i18 p17 - 0 0
li i19 1
icmp ne i20 i18 i19
if 3 i20
rcall sea_arr_unique 0:8 1 p21 1 p17
stp p21 p1 - 0 0
mov p17 p21
endif 3
ldp p22 p17 - 0 40
stf f14 p22 i9 8 0
endloop 2
endif 1
ret 0
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
EVENTS['opt5_cow_ref'] = [
    ('T3', '.main', 'load', 'ldi i33 p15 - 0 16', 'i29'),
    ('T3', '.main', 'load', 'ldp p34 p15 - 0 40', 'p30'),
    ('T3', 'fill', 'load', 'ldp p12 p1 - 0 0', 'p10'),
    ('T3', 'scale', 'load', 'ldp p15 p1 - 0 0', 'p10'),
    ('T3', 'scale', 'load', 'ldi i16 p10 - 0 16', 'i11'),
    ('T3', 'scale', 'load', 'ldp p17 p1 - 0 0', 'p10'),
]
EVENTS2['opt5_cow_ref'] = [
    ('T6', 'fill', 'version', '2', 'p1 0'),
    ('T8', 'fill', 1, '2', 5, 0),
    ('T8', 'fill', 1, 'n2', 1, 0),
    ('T6', 'scale', 'version', '2', 'p1 0'),
    ('T8', 'scale', 1, '2', 6, 0),
    ('T8', 'scale', 1, 'n2', 1, 0),
]


# ---------------------------------------------------------------- opt5_cow_kept
# total: (p1, 16) promoted (read only), the data address hoisted. passed: v (p3) is passed to
# `call total` in the loop: kept. shared: c (`mov p? p3` before the loop) is in v's copy set and
# passed to the call: kept. outer: loop 2 passes v to the call: kept; loop 4 (inner) is then the
# outermost loop that qualifies: versioned; T8 hoists the data address in its fast copy, the
# `li 1` of its slow copy, and out of loop 2 the constants (T6's `li 1` and the copies' `li 1`
# commoned into one).
CASES['opt5_cow_kept'] = (r"""fn total(v: f64[]) -> f64 {
    var s = 0.0
    for i in 0..len(v) {
        s = s + v[i]
    }
    return s
}
fn passed(n: i64) -> f64 {
    var v = zeros(n)
    var s = 0.0
    for i in 0..n {
        v[i] = 1.5
        s = s + total(v)
    }
    return s
}
fn shared(n: i64) -> f64 {
    var v = zeros(n)
    let c = v
    var s = 0.0
    for i in 0..n {
        v[i] = 2.5
        s = s + total(c)
    }
    return s + v[0]
}
fn outer(n: i64) -> f64 {
    var v = zeros(n)
    var s = 0.0
    for i in 0..n {
        for j in 0..n {
            v[j] = f64(i + j)
        }
        s = s + total(v)
    }
    return s
}
printf("%g %g %g\n", passed(2), shared(2), outer(2))
printf("%g %g %g\n", passed(3), shared(3), outer(3))
// opt5_cow_kept -- DESIGN.md 5.8 T6's conditions: a loop that passes the array it stores into
// to a call, and one that passes a copy made before the loop, are not versioned (the cows
// stay); in outer the outer loop passes v to a call, so the inner loop is the outermost one
// that can be versioned
""", r"""#sea 1
#target arm64-macos
#file opt5_cow_kept.sea
func .main main 0:1:1 0 0
slot s1 24 8
slot s2 24 8
li i1 2
call passed 1 f2 1 i1
li i3 2
call shared 1 f4 1 i3
li i5 2
call outer 1 f6 1 i5
sa p7 s1
stf f2 p7 - 0 0
stf f4 p7 - 0 8
stf f6 p7 - 0 16
la p8 d1
rcall sea_printf 0:38 0 2 p8 p7
li i9 3
call passed 1 f10 1 i9
li i11 3
call shared 1 f12 1 i11
li i13 3
call outer 1 f14 1 i13
sa p15 s2
stf f10 p15 - 0 0
stf f12 p15 - 0 8
stf f14 p15 - 0 16
la p16 d2
rcall sea_printf 0:39 0 2 p16 p15
ret 0
endfunc
func total fn 0:1:1 1 p1 1 f
lf f2 #0000000000000000
li i3 0
ldi i4 p1 - 0 16
li i5 1
rcount i6 i7 i3 i4 i5 0 0:3
if 1 i7
loop 2 i8 i3 i6 i5
ldi i9 p1 - 0 16
chkb i8 i9 0 0:4
ldp p10 p1 - 0 40
ldf f11 p10 i8 8 0
fadd f2 f2 f11
endloop 2
endif 1
ret 1 f2
endfunc
func passed fn 0:8:1 1 i1 1 f
li i2 1
li i3 1
li i4 1
rcall sea_arr_new 0:9 1 p5 4 i2 i3 i1 i4
lf f6 #0000000000000000
li i7 0
li i8 1
rcount i9 i10 i7 i1 i8 0 0:11
if 1 i10
loop 2 i11 i7 i9 i8
lf f12 #3FF8000000000000
ldi i13 p5 - 0 16
chkb i11 i13 0 0:12
ldi i14 p5 - 0 0
li i15 1
icmp ne i16 i14 i15
if 3 i16
rcall sea_arr_unique 0:12 1 p17 1 p5
mov p5 p17
endif 3
ldp p18 p5 - 0 40
stf f12 p18 i11 8 0
call total 1 f19 1 p5
fadd f6 f6 f19
endloop 2
endif 1
release p5
ret 1 f6
endfunc
func shared fn 0:17:1 1 i1 1 f
li i2 1
li i3 1
li i4 1
rcall sea_arr_new 0:18 1 p5 4 i2 i3 i1 i4
mov p6 p5
retain p6
lf f7 #0000000000000000
li i8 0
li i9 1
rcount i10 i11 i8 i1 i9 0 0:21
if 1 i11
loop 2 i12 i8 i10 i9
lf f13 #4004000000000000
ldi i14 p5 - 0 16
chkb i12 i14 0 0:22
ldi i15 p5 - 0 0
li i16 1
icmp ne i17 i15 i16
if 3 i17
rcall sea_arr_unique 0:22 1 p18 1 p5
mov p5 p18
endif 3
ldp p19 p5 - 0 40
stf f13 p19 i12 8 0
call total 1 f20 1 p6
fadd f7 f7 f20
endloop 2
endif 1
li i21 0
ldi i22 p5 - 0 16
chkb i21 i22 0 0:25
ldp p23 p5 - 0 40
ldf f24 p23 i21 8 0
fadd f25 f7 f24
release p6
release p5
ret 1 f25
endfunc
func outer fn 0:27:1 1 i1 1 f
li i2 1
li i3 1
li i4 1
rcall sea_arr_new 0:28 1 p5 4 i2 i3 i1 i4
lf f6 #0000000000000000
li i7 0
li i8 1
rcount i9 i10 i7 i1 i8 0 0:30
if 1 i10
loop 2 i11 i7 i9 i8
li i12 0
li i13 1
rcount i14 i15 i12 i1 i13 0 0:31
if 3 i15
loop 4 i16 i12 i14 i13
iaddc i17 i11 i16 0:32
itof f18 i17
ldi i19 p5 - 0 16
chkb i16 i19 0 0:32
ldi i20 p5 - 0 0
li i21 1
icmp ne i22 i20 i21
if 5 i22
rcall sea_arr_unique 0:32 1 p23 1 p5
mov p5 p23
endif 5
ldp p24 p5 - 0 40
stf f18 p24 i16 8 0
endloop 4
endif 3
call total 1 f25 1 p5
fadd f6 f6 f25
endloop 2
endif 1
release p5
ret 1 f6
endfunc
fmt d1 6
fconv - - - g f
ftext %20
fconv - - - g f
ftext %20
fconv - - - g f
ftext %0A
fmt d2 6
fconv - - - g f
ftext %20
fconv - - - g f
ftext %20
fconv - - - g f
ftext %0A
#end
""")
EVENTS['opt5_cow_kept'] = [
    ('T1', 'passed', 'del', 'chkb i11 i13 0 0:12'),
    ('T1', 'shared', 'del', 'chkb i12 i14 0 0:22'),
    ('T1', 'outer', 'wrap', 'iaddc i17 i11 i16 0:32'),
    ('T1', 'outer', 'del', 'chkb i16 i19 0 0:32'),
]
EVENTS2['opt5_cow_kept'] = [
    ('T5', 'total', 'promote', '2', 'p1 16', False),
    ('T8', 'total', 1, '2', 1, 0),
    ('T6', 'passed', 'kept', '2'),
    ('T8', 'passed', 1, '2', 2, 0),
    ('T6', 'shared', 'kept', '2'),
    ('T8', 'shared', 1, '2', 2, 0),
    ('T6', 'outer', 'kept', '2'),
    ('T6', 'outer', 'version', '4', 'p3'),
    ('T8', 'outer', 1, '4', 2, 0),
    ('T8', 'outer', 1, 'n2', 1, 0),
    ('T8', 'outer', 1, '2', 5, 3),
]


# ---------------------------------------------------------------- opt5_sr_unit
# .main: the fill loop versioned on v (p3). diff, loop 2 (1..n-1): v[i + 1] and v[i - 1] (adds
# made wrapping by T1): unit stride with e = 8 and -8 (li E e, padd), v[i] unchanged (X = J, o =
# 0), v[i + k] keeps its iaddc (a checked chain: not reduced). Loop 6 under 0 <= k < 4 (T1 makes
# i + k and i - k wrapping): v[i + k] (li 8, imul, padd), v[i - k] (li -8), v[i + k + 1] kept
# (iaddc). plane: rows and cols of a and b promoted (T5, read only) in loop 2; in loop 4 the
# index terms i * rows hoisted (T8), then b[j, i] (z = 1: T1 is t, padd only), a[j, i] and
# a[j + 1, i] (e = 8) reduced; T8's second pass hoists the 9 new instructions and commons 4 of
# them (the `li 8`, the second imul and padd of a's column, its li E 8), and the `li 8` out of
# loop 2.
CASES['opt5_sr_unit'] = (r"""fn diff(v: f64[], k: i64, n: i64) -> f64 {
    var s = 0.0
    for i in 1..n-1 {
        s = s + v[i + 1] - v[i - 1] + v[i] + v[i + k]
    }
    if k >= 0 {
        if k < 4 {
            for i in 4..8 {
                s = s + v[i + k] - v[i - k] + v[i + k + 1]
            }
        }
    }
    return s
}
fn plane(a: f64[,], b: bool[,]) -> f64 {
    var s = 0.0
    for i in 0..cols(a) {
        for j in 0..rows(a) - 1 {
            if b[j, i] {
                s = s + a[j, i] * a[j + 1, i]
            }
        }
    }
    return s
}
var v = zeros(12)
for i in 0..12 {
    v[i] = f64(i * i)
}
var a = zeros(3, 2)
var b = filled(true, 3, 2)
a[1, 1] = 2.0
a[2, 1] = 3.0
printf("%g %g\n", diff(v, 2, 6), diff(v, 3, 9))
printf("%g %g\n", plane(a, b), plane(a, filled(false, 3, 2)))
// opt5_sr_unit -- DESIGN.md 5.8 T7, unit stride: v[i + 1] and v[i - 1] (the offset folded into
// the address, J the index), v[i] unchanged, v[i + k] with its checked add kept; under 0 <= k < 4
// v[i + k] and v[i - k] (an invariant term with the scale 8 and -8), v[i + k + 1] kept (a
// checked add in the chain); the bool and f64 columns of plane (the term i * rows, scale 1 and
// 8, and the row j + 1); T8's second pass hoists what T7 adds and commons its constants
""", r"""#sea 1
#target arm64-macos
#file opt5_sr_unit.sea
func .main main 0:1:1 0 0
slot s1 16 8
slot s2 16 8
li i1 12
li i2 1
li i3 1
li i4 1
rcall sea_arr_new 0:26 1 p5 4 i2 i3 i1 i4
li i6 0
li i7 12
li i8 1
rcount i9 i10 i6 i7 i8 0 0:27
if 1 i10
loop 2 i11 i6 i9 i8
imulc i12 i11 i11 0:28
itof f13 i12
ldi i14 p5 - 0 16
chkb i11 i14 0 0:28
ldi i15 p5 - 0 0
li i16 1
icmp ne i17 i15 i16
if 3 i17
rcall sea_arr_unique 0:28 1 p18 1 p5
mov p5 p18
endif 3
ldp p19 p5 - 0 40
stf f13 p19 i11 8 0
endloop 2
endif 1
li i20 3
li i21 2
li i22 1
li i23 2
rcall sea_arr_new 0:30 1 p24 4 i22 i23 i20 i21
li i25 1
li i26 3
li i27 2
li i28 3
li i29 2
rcall sea_arr_new_u 0:31 1 p30 4 i28 i29 i26 i27
imul i31 i26 i27
ldp p32 p30 - 0 40
li i33 0
icmp gt i34 i31 i33
if 4 i34
li i35 1
isub i36 i31 i35
loop 5 i37 i33 i36 i35
stb i25 p32 i37 1 0
endloop 5
endif 4
lf f38 #4000000000000000
li i39 1
li i40 1
ldi i41 p24 - 0 16
chkb i39 i41 0 0:32
ldi i42 p24 - 0 24
chkb i40 i42 1 0:32
ldi i43 p24 - 0 0
li i44 1
icmp ne i45 i43 i44
if 6 i45
rcall sea_arr_unique 0:32 1 p46 1 p24
mov p24 p46
endif 6
ldp p47 p24 - 0 40
imul i48 i40 i41
iadd i49 i39 i48
stf f38 p47 i49 8 0
lf f50 #4008000000000000
li i51 2
li i52 1
ldi i53 p24 - 0 16
chkb i51 i53 0 0:33
ldi i54 p24 - 0 24
chkb i52 i54 1 0:33
ldi i55 p24 - 0 0
li i56 1
icmp ne i57 i55 i56
if 7 i57
rcall sea_arr_unique 0:33 1 p58 1 p24
mov p24 p58
endif 7
ldp p59 p24 - 0 40
imul i60 i52 i53
iadd i61 i51 i60
stf f50 p59 i61 8 0
li i62 2
li i63 6
call diff 1 f64 3 p5 i62 i63
li i65 3
li i66 9
call diff 1 f67 3 p5 i65 i66
sa p68 s1
stf f64 p68 - 0 0
stf f67 p68 - 0 8
la p69 d1
rcall sea_printf 0:34 0 2 p69 p68
call plane 1 f70 2 p24 p30
li i71 0
li i72 3
li i73 2
li i74 3
li i75 2
rcall sea_arr_new_u 0:35 1 p76 4 i74 i75 i72 i73
imul i77 i72 i73
ldp p78 p76 - 0 40
li i79 0
icmp gt i80 i77 i79
if 8 i80
li i81 1
isub i82 i77 i81
loop 9 i83 i79 i82 i81
stb i71 p78 i83 1 0
endloop 9
endif 8
call plane 1 f84 2 p24 p76
release p76
sa p85 s2
stf f70 p85 - 0 0
stf f84 p85 - 0 8
la p86 d2
rcall sea_printf 0:35 0 2 p86 p85
release p30
release p24
release p5
ret 0
endfunc
func diff fn 0:1:1 3 p1 i2 i3 1 f
lf f4 #0000000000000000
li i5 1
li i6 1
isubc i7 i3 i6 0:3
li i8 1
rcount i9 i10 i5 i7 i8 0 0:3
if 1 i10
loop 2 i11 i5 i9 i8
li i12 1
iaddc i13 i11 i12 0:4
ldi i14 p1 - 0 16
chkb i13 i14 0 0:4
ldp p15 p1 - 0 40
ldf f16 p15 i13 8 0
fadd f17 f4 f16
li i18 1
isubc i19 i11 i18 0:4
ldi i20 p1 - 0 16
chkb i19 i20 0 0:4
ldp p21 p1 - 0 40
ldf f22 p21 i19 8 0
fsub f23 f17 f22
ldi i24 p1 - 0 16
chkb i11 i24 0 0:4
ldp p25 p1 - 0 40
ldf f26 p25 i11 8 0
fadd f27 f23 f26
iaddc i28 i11 i2 0:4
ldi i29 p1 - 0 16
chkb i28 i29 0 0:4
ldp p30 p1 - 0 40
ldf f31 p30 i28 8 0
fadd f4 f27 f31
endloop 2
endif 1
li i32 0
icmp ge i33 i2 i32
if 3 i33
li i34 4
icmp lt i35 i2 i34
if 4 i35
li i36 4
li i37 8
li i38 1
rcount i39 i40 i36 i37 i38 0 0:8
if 5 i40
loop 6 i41 i36 i39 i38
iaddc i42 i41 i2 0:9
ldi i43 p1 - 0 16
chkb i42 i43 0 0:9
ldp p44 p1 - 0 40
ldf f45 p44 i42 8 0
fadd f46 f4 f45
isubc i47 i41 i2 0:9
ldi i48 p1 - 0 16
chkb i47 i48 0 0:9
ldp p49 p1 - 0 40
ldf f50 p49 i47 8 0
fsub f51 f46 f50
iaddc i52 i41 i2 0:9
li i53 1
iaddc i54 i52 i53 0:9
ldi i55 p1 - 0 16
chkb i54 i55 0 0:9
ldp p56 p1 - 0 40
ldf f57 p56 i54 8 0
fadd f4 f51 f57
endloop 6
endif 5
endif 4
endif 3
ret 1 f4
endfunc
func plane fn 0:15:1 2 p1 p2 1 f
lf f3 #0000000000000000
li i4 0
ldi i5 p1 - 0 24
li i6 1
rcount i7 i8 i4 i5 i6 0 0:17
if 1 i8
loop 2 i9 i4 i7 i6
li i10 0
ldi i11 p1 - 0 16
li i12 1
isubc i13 i11 i12 0:18
li i14 1
rcount i15 i16 i10 i13 i14 0 0:18
if 3 i16
loop 4 i17 i10 i15 i14
ldi i18 p2 - 0 16
chkb i17 i18 0 0:19
ldi i19 p2 - 0 24
chkb i9 i19 1 0:19
ldp p20 p2 - 0 40
imul i21 i9 i18
iadd i22 i17 i21
ldb i23 p20 i22 1 0
if 5 i23
ldi i24 p1 - 0 16
chkb i17 i24 0 0:20
ldi i25 p1 - 0 24
chkb i9 i25 1 0:20
ldp p26 p1 - 0 40
imul i27 i9 i24
iadd i28 i17 i27
ldf f29 p26 i28 8 0
li i30 1
iaddc i31 i17 i30 0:20
ldi i32 p1 - 0 16
chkb i31 i32 0 0:20
ldi i33 p1 - 0 24
chkb i9 i33 1 0:20
ldp p34 p1 - 0 40
imul i35 i9 i32
iadd i36 i31 i35
ldf f37 p34 i36 8 0
fmul f38 f29 f37
fadd f3 f3 f38
endif 5
endloop 4
endif 3
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
EVENTS['opt5_sr_unit'] = [
    ('T1', '.main', 'wrap', 'imulc i12 i11 i11 0:28'),
    ('T1', '.main', 'del', 'chkb i11 i14 0 0:28'),
    ('T1', '.main', 'del', 'chkb i39 i41 0 0:32'),
    ('T1', '.main', 'del', 'chkb i40 i42 1 0:32'),
    ('T1', '.main', 'del', 'chkb i51 i53 0 0:33'),
    ('T1', '.main', 'del', 'chkb i52 i54 1 0:33'),
    ('T1', 'diff', 'wrap', 'iaddc i13 i11 i12 0:4'),
    ('T1', 'diff', 'wrap', 'isubc i19 i11 i18 0:4'),
    ('T1', 'diff', 'wrap', 'iaddc i42 i41 i2 0:9'),
    ('T1', 'diff', 'wrap', 'isubc i47 i41 i2 0:9'),
    ('T1', 'diff', 'wrap', 'iaddc i52 i41 i2 0:9'),
    ('T3', 'diff', 'load', 'ldi i20 p1 - 0 16', 'i14'),
    ('T3', 'diff', 'load', 'ldp p21 p1 - 0 40', 'p15'),
    ('T3', 'diff', 'load', 'ldi i24 p1 - 0 16', 'i14'),
    ('T3', 'diff', 'load', 'ldp p25 p1 - 0 40', 'p15'),
    ('T3', 'diff', 'load', 'ldi i29 p1 - 0 16', 'i14'),
    ('T3', 'diff', 'load', 'ldp p30 p1 - 0 40', 'p15'),
    ('T3', 'diff', 'load', 'ldi i48 p1 - 0 16', 'i43'),
    ('T3', 'diff', 'load', 'ldp p49 p1 - 0 40', 'p44'),
    ('T3', 'diff', 'load', 'ldi i55 p1 - 0 16', 'i43'),
    ('T3', 'diff', 'load', 'ldp p56 p1 - 0 40', 'p44'),
    ('T1', 'plane', 'wrap', 'isubc i13 i11 i12 0:18'),
    ('T1', 'plane', 'del', 'chkb i17 i24 0 0:20'),
    ('T1', 'plane', 'wrap', 'iaddc i31 i17 i30 0:20'),
    ('T1', 'plane', 'del', 'chkb i31 i32 0 0:20'),
    ('T3', 'plane', 'load', 'ldi i32 p1 - 0 16', 'i24'),
    ('T3', 'plane', 'load', 'ldi i33 p1 - 0 24', 'i25'),
    ('T3', 'plane', 'load', 'ldp p34 p1 - 0 40', 'p26'),
]
EVENTS2['opt5_sr_unit'] = [
    ('T6', '.main', 'version', '2', 'p3'),
    ('T8', '.main', 1, '2', 2, 0),
    ('T8', '.main', 1, 'n2', 1, 0),
    ('T5', 'diff', 'promote', '2', 'p1 16', False),
    ('T5', 'diff', 'promote', '6', 'p1 16', False),
    ('T8', 'diff', 1, '2', 2, 0),
    ('T8', 'diff', 1, '6', 2, 0),
    ('T7', 'diff', '2', 'unit', 'ldf f15 p48 i10 8 0'),
    ('T7', 'diff', '2', 'unit', 'ldf f18 p50 i10 8 0'),
    ('T7', 'diff', '6', 'unit', 'ldf f37 p53 i33 8 0'),
    ('T7', 'diff', '6', 'unit', 'ldf f40 p56 i33 8 0'),
    ('T8', 'diff', 2, '2', 4, 0),
    ('T8', 'diff', 2, '6', 6, 0),
    ('T5', 'plane', 'promote', '2', 'p1 16', False),
    ('T5', 'plane', 'promote', '2', 'p2 16', False),
    ('T5', 'plane', 'promote', '2', 'p2 24', False),
    ('T5', 'plane', 'promote', '2', 'p1 24', False),
    ('T8', 'plane', 1, '4', 5, 0),
    ('T8', 'plane', 1, '2', 7, 1),
    ('T7', 'plane', '4', 'unit', 'ldb i23 p39 i17 1 0'),
    ('T7', 'plane', '4', 'unit', 'ldf f29 p42 i17 8 0'),
    ('T7', 'plane', '4', 'unit', 'ldf f33 p47 i17 8 0'),
    ('T8', 'plane', 2, '4', 9, 4),
    ('T8', 'plane', 2, '2', 1, 0),
]


# ---------------------------------------------------------------- opt5_sr_stride
# .main: the fill loops versioned (v; a), a's three row stores in the fast copy reduced with an
# invariant stride (k = rows, a register; T8's second pass commons their equal start terms and
# deltas). odd, loop 2: v[2 * i] (k = 2, start 0 folded: e = -16, delta 16), v[2 * i + 1] kept
# (its iaddc); loop 4 (1..=3 step 2): v[3 * i] (e = -24, delta 48); loop 7 from b (two
# definitions: not a constant): li G 16, imul A start G, e = -16, delta li 16 commoned with G.
# row, loop 2: a[1, i] (k register, start 0: li G -8, imul A k G, e = 8) and a[r, i] (t = r,
# li 8, imul): two Q whose start terms T8's second pass commons; loop 4 from m: li G 1, isub,
# imul, li G2 8, imul; the deltas imul k (li 8).
CASES['opt5_sr_stride'] = (r"""fn odd(v: f64[], m: i64) -> f64 {
    var s = 0.0
    for i in 0..5 {
        s = s + v[2 * i] + v[2 * i + 1]
    }
    for i in 1..=3 step 2 {
        s = s + v[3 * i]
    }
    var b = 0
    if m > 1 {
        b = 1
    }
    for i in b..5 {
        s = s + v[2 * i]
    }
    return s
}
fn row(a: f64[,], r: i64, m: i64) -> f64 {
    var s = 0.0
    for i in 0..cols(a) {
        s = s + a[1, i] * a[r, i]
    }
    for i in m..cols(a) {
        s = s + a[0, i]
    }
    return s
}
var v = zeros(11)
for i in 0..11 {
    v[i] = f64(i)
}
var a = zeros(3, 4)
for i in 0..4 {
    a[0, i] = 1.0
    a[1, i] = f64(i)
    a[2, i] = 2.0
}
printf("%g %g\n", odd(v, 1), odd(v, 2))
printf("%g %g\n", row(a, 2, 1), row(a, 0, 3))
// opt5_sr_stride -- DESIGN.md 5.8 T7, invariant stride: v[2 * i] over 0..5 and v[3 * i] over
// 1..=3 step 2 (a constant k, the start folded), v[2 * i] from a start b that is not a constant
// (li G kz, imul A start G), v[2 * i + 1] kept (its add stays checked); a row of a matrix over
// its columns (k the rows, a register): a[1, i] and a[r, i] (two Q sharing their start term after
// commoning), a[0, i] from the start m (li G st, isub, imul, li G2 z, imul)
""", r"""#sea 1
#target arm64-macos
#file opt5_sr_stride.sea
func .main main 0:1:1 0 0
slot s1 16 8
slot s2 16 8
li i1 11
li i2 1
li i3 1
li i4 1
rcall sea_arr_new 0:28 1 p5 4 i2 i3 i1 i4
li i6 0
li i7 11
li i8 1
rcount i9 i10 i6 i7 i8 0 0:29
if 1 i10
loop 2 i11 i6 i9 i8
itof f12 i11
ldi i13 p5 - 0 16
chkb i11 i13 0 0:30
ldi i14 p5 - 0 0
li i15 1
icmp ne i16 i14 i15
if 3 i16
rcall sea_arr_unique 0:30 1 p17 1 p5
mov p5 p17
endif 3
ldp p18 p5 - 0 40
stf f12 p18 i11 8 0
endloop 2
endif 1
li i19 3
li i20 4
li i21 1
li i22 2
rcall sea_arr_new 0:32 1 p23 4 i21 i22 i19 i20
li i24 0
li i25 4
li i26 1
rcount i27 i28 i24 i25 i26 0 0:33
if 4 i28
loop 5 i29 i24 i27 i26
lf f30 #3FF0000000000000
li i31 0
ldi i32 p23 - 0 16
chkb i31 i32 0 0:34
ldi i33 p23 - 0 24
chkb i29 i33 1 0:34
ldi i34 p23 - 0 0
li i35 1
icmp ne i36 i34 i35
if 6 i36
rcall sea_arr_unique 0:34 1 p37 1 p23
mov p23 p37
endif 6
ldp p38 p23 - 0 40
imul i39 i29 i32
iadd i40 i31 i39
stf f30 p38 i40 8 0
itof f41 i29
li i42 1
ldi i43 p23 - 0 16
chkb i42 i43 0 0:35
ldi i44 p23 - 0 24
chkb i29 i44 1 0:35
ldi i45 p23 - 0 0
li i46 1
icmp ne i47 i45 i46
if 7 i47
rcall sea_arr_unique 0:35 1 p48 1 p23
mov p23 p48
endif 7
ldp p49 p23 - 0 40
imul i50 i29 i43
iadd i51 i42 i50
stf f41 p49 i51 8 0
lf f52 #4000000000000000
li i53 2
ldi i54 p23 - 0 16
chkb i53 i54 0 0:36
ldi i55 p23 - 0 24
chkb i29 i55 1 0:36
ldi i56 p23 - 0 0
li i57 1
icmp ne i58 i56 i57
if 8 i58
rcall sea_arr_unique 0:36 1 p59 1 p23
mov p23 p59
endif 8
ldp p60 p23 - 0 40
imul i61 i29 i54
iadd i62 i53 i61
stf f52 p60 i62 8 0
endloop 5
endif 4
li i63 1
call odd 1 f64 2 p5 i63
li i65 2
call odd 1 f66 2 p5 i65
sa p67 s1
stf f64 p67 - 0 0
stf f66 p67 - 0 8
la p68 d1
rcall sea_printf 0:38 0 2 p68 p67
li i69 2
li i70 1
call row 1 f71 3 p23 i69 i70
li i72 0
li i73 3
call row 1 f74 3 p23 i72 i73
sa p75 s2
stf f71 p75 - 0 0
stf f74 p75 - 0 8
la p76 d2
rcall sea_printf 0:39 0 2 p76 p75
release p23
release p5
ret 0
endfunc
func odd fn 0:1:1 2 p1 i2 1 f
lf f3 #0000000000000000
li i4 0
li i5 5
li i6 1
rcount i7 i8 i4 i5 i6 0 0:3
if 1 i8
loop 2 i9 i4 i7 i6
li i10 2
imulc i11 i10 i9 0:4
ldi i12 p1 - 0 16
chkb i11 i12 0 0:4
ldp p13 p1 - 0 40
ldf f14 p13 i11 8 0
fadd f15 f3 f14
li i16 2
imulc i17 i16 i9 0:4
li i18 1
iaddc i19 i17 i18 0:4
ldi i20 p1 - 0 16
chkb i19 i20 0 0:4
ldp p21 p1 - 0 40
ldf f22 p21 i19 8 0
fadd f3 f15 f22
endloop 2
endif 1
li i23 1
li i24 3
li i25 2
rcount i26 i27 i23 i24 i25 1 0:6
if 3 i27
loop 4 i28 i23 i26 i25
li i29 3
imulc i30 i29 i28 0:7
ldi i31 p1 - 0 16
chkb i30 i31 0 0:7
ldp p32 p1 - 0 40
ldf f33 p32 i30 8 0
fadd f3 f3 f33
endloop 4
endif 3
li i34 0
li i35 1
icmp gt i36 i2 i35
if 5 i36
li i34 1
endif 5
li i37 5
li i38 1
rcount i39 i40 i34 i37 i38 0 0:13
if 6 i40
loop 7 i41 i34 i39 i38
li i42 2
imulc i43 i42 i41 0:14
ldi i44 p1 - 0 16
chkb i43 i44 0 0:14
ldp p45 p1 - 0 40
ldf f46 p45 i43 8 0
fadd f3 f3 f46
endloop 7
endif 6
ret 1 f3
endfunc
func row fn 0:18:1 3 p1 i2 i3 1 f
lf f4 #0000000000000000
li i5 0
ldi i6 p1 - 0 24
li i7 1
rcount i8 i9 i5 i6 i7 0 0:20
if 1 i9
loop 2 i10 i5 i8 i7
li i11 1
ldi i12 p1 - 0 16
chkb i11 i12 0 0:21
ldi i13 p1 - 0 24
chkb i10 i13 1 0:21
ldp p14 p1 - 0 40
imul i15 i10 i12
iadd i16 i11 i15
ldf f17 p14 i16 8 0
ldi i18 p1 - 0 16
chkb i2 i18 0 0:21
ldi i19 p1 - 0 24
chkb i10 i19 1 0:21
ldp p20 p1 - 0 40
imul i21 i10 i18
iadd i22 i2 i21
ldf f23 p20 i22 8 0
fmul f24 f17 f23
fadd f4 f4 f24
endloop 2
endif 1
ldi i25 p1 - 0 24
li i26 1
rcount i27 i28 i3 i25 i26 0 0:23
if 3 i28
loop 4 i29 i3 i27 i26
li i30 0
ldi i31 p1 - 0 16
chkb i30 i31 0 0:24
ldi i32 p1 - 0 24
chkb i29 i32 1 0:24
ldp p33 p1 - 0 40
imul i34 i29 i31
iadd i35 i30 i34
ldf f36 p33 i35 8 0
fadd f4 f4 f36
endloop 4
endif 3
ret 1 f4
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
EVENTS['opt5_sr_stride'] = [
    ('T1', '.main', 'del', 'chkb i11 i13 0 0:30'),
    ('T1', '.main', 'del', 'chkb i31 i32 0 0:34'),
    ('T1', '.main', 'del', 'chkb i29 i33 1 0:34'),
    ('T1', '.main', 'del', 'chkb i42 i43 0 0:35'),
    ('T1', '.main', 'del', 'chkb i29 i44 1 0:35'),
    ('T1', '.main', 'del', 'chkb i53 i54 0 0:36'),
    ('T1', '.main', 'del', 'chkb i29 i55 1 0:36'),
    ('T1', 'odd', 'wrap', 'imulc i11 i10 i9 0:4'),
    ('T1', 'odd', 'wrap', 'imulc i17 i16 i9 0:4'),
    ('T1', 'odd', 'wrap', 'imulc i30 i29 i28 0:7'),
    ('T1', 'odd', 'wrap', 'imulc i43 i42 i41 0:14'),
    ('T3', 'odd', 'load', 'ldi i20 p1 - 0 16', 'i12'),
    ('T3', 'odd', 'load', 'ldp p21 p1 - 0 40', 'p13'),
    ('T3', 'row', 'load', 'ldi i18 p1 - 0 16', 'i12'),
    ('T3', 'row', 'load', 'ldi i19 p1 - 0 24', 'i13'),
    ('T3', 'row', 'load', 'ldp p20 p1 - 0 40', 'p14'),
]
EVENTS2['opt5_sr_stride'] = [
    ('T6', '.main', 'version', '2', 'p3'),
    ('T6', '.main', 'version', '5', 'p19'),
    ('T8', '.main', 1, '2', 2, 0),
    ('T8', '.main', 1, 'n2', 1, 0),
    ('T8', '.main', 1, '5', 13, 6),
    ('T8', '.main', 1, 'n5', 7, 2),
    ('T7', '.main', '5', 'stride', 'stf f25 p111 - 0 0'),
    ('T7', '.main', '5', 'stride', 'stf f35 p118 - 0 0'),
    ('T7', '.main', '5', 'stride', 'stf f44 p125 - 0 0'),
    ('T8', '.main', 2, '5', 0, 10),
    ('T5', 'odd', 'promote', '2', 'p1 16', False),
    ('T5', 'odd', 'promote', '4', 'p1 16', False),
    ('T5', 'odd', 'promote', '7', 'p1 16', False),
    ('T8', 'odd', 1, '2', 3, 0),
    ('T8', 'odd', 1, '4', 2, 0),
    ('T8', 'odd', 1, '7', 2, 0),
    ('T7', 'odd', '2', 'stride', 'ldf f14 p47 - 0 0'),
    ('T7', 'odd', '4', 'stride', 'ldf f29 p50 - 0 0'),
    ('T7', 'odd', '7', 'stride', 'ldf f42 p56 - 0 0'),
    ('T8', 'odd', 2, '7', 0, 1),
    ('T5', 'row', 'promote', '2', 'p1 16', False),
    ('T5', 'row', 'promote', '2', 'p1 24', False),
    ('T5', 'row', 'promote', '4', 'p1 16', False),
    ('T5', 'row', 'promote', '4', 'p1 24', False),
    ('T8', 'row', 1, '2', 2, 0),
    ('T8', 'row', 1, '4', 2, 0),
    ('T7', 'row', '2', 'stride', 'ldf f17 p41 - 0 0'),
    ('T7', 'row', '2', 'stride', 'ldf f19 p49 - 0 0'),
    ('T7', 'row', '4', 'stride', 'ldf f32 p57 - 0 0'),
    ('T8', 'row', 2, '2', 0, 7),
    ('T8', 'row', 2, '4', 0, 1),
]


# ---------------------------------------------------------------- opt5_licm_hdr
# hdr: u's extent and data address, loaded in the if part of loop 2, are hoisted by (b) (u an
# array register, written nowhere in the loop), with `itof` of the extent. moving: u is written in
# the loop (`mov p3 p11`): its header loads stay; only the `li 1` moves.
CASES['opt5_licm_hdr'] = (r"""fn hdr(n: i64, k: i64) -> f64 {
    let u = zeros(n)
    var s = 0.0
    for i in 0..n {
        if i > k {
            s = s + u[i] + f64(len(u))
        }
    }
    return s
}
fn moving(n: i64) -> f64 {
    var u = zeros(1)
    var s = 0.0
    for i in 1..n {
        u = zeros(i)
        s = s + f64(len(u)) + u[i - 1]
    }
    return s
}
printf("%g %g\n", hdr(3, 0), hdr(4, 1))
printf("%g %g\n", moving(3), moving(4))
// opt5_licm_hdr -- DESIGN.md 5.8 T8 (b): the extent and data address of the array register u,
// loaded in an if part, hoisted (a header is always readable), with the conversion of len(u);
// in moving u is written in the loop: its header loads stay
""", r"""#sea 1
#target arm64-macos
#file opt5_licm_hdr.sea
func .main main 0:1:1 0 0
slot s1 16 8
slot s2 16 8
li i1 3
li i2 0
call hdr 1 f3 2 i1 i2
li i4 4
li i5 1
call hdr 1 f6 2 i4 i5
sa p7 s1
stf f3 p7 - 0 0
stf f6 p7 - 0 8
la p8 d1
rcall sea_printf 0:20 0 2 p8 p7
li i9 3
call moving 1 f10 1 i9
li i11 4
call moving 1 f12 1 i11
sa p13 s2
stf f10 p13 - 0 0
stf f12 p13 - 0 8
la p14 d2
rcall sea_printf 0:21 0 2 p14 p13
ret 0
endfunc
func hdr fn 0:1:1 2 i1 i2 1 f
li i3 1
li i4 1
li i5 1
rcall sea_arr_new 0:2 1 p6 4 i3 i4 i1 i5
lf f7 #0000000000000000
li i8 0
li i9 1
rcount i10 i11 i8 i1 i9 0 0:4
if 1 i11
loop 2 i12 i8 i10 i9
icmp gt i13 i12 i2
if 3 i13
ldi i14 p6 - 0 16
chkb i12 i14 0 0:6
ldp p15 p6 - 0 40
ldf f16 p15 i12 8 0
fadd f17 f7 f16
ldi i18 p6 - 0 16
itof f19 i18
fadd f7 f17 f19
endif 3
endloop 2
endif 1
release p6
ret 1 f7
endfunc
func moving fn 0:11:1 1 i1 1 f
li i2 1
li i3 1
li i4 1
li i5 1
rcall sea_arr_new 0:12 1 p6 4 i3 i4 i2 i5
lf f7 #0000000000000000
li i8 1
li i9 1
rcount i10 i11 i8 i1 i9 0 0:14
if 1 i11
loop 2 i12 i8 i10 i9
li i13 1
li i14 1
li i15 1
rcall sea_arr_new 0:15 1 p16 4 i13 i14 i12 i15
release p6
mov p6 p16
ldi i17 p6 - 0 16
itof f18 i17
fadd f19 f7 f18
li i20 1
isubc i21 i12 i20 0:16
ldi i22 p6 - 0 16
chkb i21 i22 0 0:16
ldp p23 p6 - 0 40
ldf f24 p23 i21 8 0
fadd f7 f19 f24
endloop 2
endif 1
release p6
ret 1 f7
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
EVENTS['opt5_licm_hdr'] = [
    ('T1', 'hdr', 'del', 'chkb i12 i14 0 0:6'),
    ('T3', 'hdr', 'load', 'ldi i18 p6 - 0 16', 'i14'),
    ('T1', 'moving', 'wrap', 'isubc i21 i12 i20 0:16'),
    ('T3', 'moving', 'load', 'ldi i22 p6 - 0 16', 'i17'),
]
EVENTS2['opt5_licm_hdr'] = [
    ('T8', 'hdr', 1, '2', 3, 0),
    ('T8', 'moving', 1, '2', 1, 0),
]


# ---------------------------------------------------------------- opt5_licm_param
# scan: p (a struct parameter, an object pointer) is passed to `call norm1`, so it is no private
# base and not an array register: its loads are hoisted only when anticipated (a). Loop 2's p.x
# is anticipated: hoisted. Loop 4's p.y stands in an if part, loop 7's p.x and p.y after the
# `exit 7` of the break: not anticipated, they stay (only loop 4's `li 1` moves). norm1: p is a
# private base there: (p1, 0) and (p1, 8) promoted, read only.
CASES['opt5_licm_param'] = (r"""struct Pt {
    x: f64
    y: f64
}
fn norm1(p: Pt) -> f64 {
    var s = 0.0
    for i in 0..2 {
        s = s + abs(p.x) + abs(p.y)
    }
    return s
}
fn scan(p: Pt, n: i64, lim: f64) -> f64 {
    var s = 0.0
    for i in 0..n {
        s = s + p.x
    }
    for i in 0..n {
        if i > 1 {
            s = s + p.y
        }
    }
    for i in 0..n {
        if s > lim {
            break
        }
        s = s + p.x * p.y
    }
    return s + norm1(p)
}
let q = Pt { x: 1.5, y: -2.0 }
printf("%g %g %g\n", scan(q, 3, 100.0), scan(q, 4, 1.0), norm1(q))
// opt5_licm_param -- DESIGN.md 5.8 T8 (a): the struct parameter p is passed to a call, so it is
// no private base; p.x is hoisted from the first loop (anticipated, p an object pointer), p.y
// in an if part and p.x, p.y after the `break` test are not anticipated and stay; in norm1 p
// is a private base and T5 pre-loads its fields
""", r"""#sea 1
#target arm64-macos
#file opt5_licm_param.sea
func .main main 0:1:1 0 0
slot s1 16 8
slot s2 24 8
sa p1 s1
lf f2 #3FF8000000000000
stf f2 p1 - 0 0
lf f3 #C000000000000000
stf f3 p1 - 0 8
li i4 3
lf f5 #4059000000000000
call scan 1 f6 3 p1 i4 f5
li i7 4
lf f8 #3FF0000000000000
call scan 1 f9 3 p1 i7 f8
call norm1 1 f10 1 p1
sa p11 s2
stf f6 p11 - 0 0
stf f9 p11 - 0 8
stf f10 p11 - 0 16
la p12 d1
rcall sea_printf 0:31 0 2 p12 p11
ret 0
endfunc
func norm1 fn 0:5:1 1 p1 1 f
lf f2 #0000000000000000
li i3 0
li i4 2
li i5 1
rcount i6 i7 i3 i4 i5 0 0:7
if 1 i7
loop 2 i8 i3 i6 i5
ldf f9 p1 - 0 0
fabs f10 f9
fadd f11 f2 f10
ldf f12 p1 - 0 8
fabs f13 f12
fadd f2 f11 f13
endloop 2
endif 1
ret 1 f2
endfunc
func scan fn 0:12:1 3 p1 i2 f3 1 f
lf f4 #0000000000000000
li i5 0
li i6 1
rcount i7 i8 i5 i2 i6 0 0:14
if 1 i8
loop 2 i9 i5 i7 i6
ldf f10 p1 - 0 0
fadd f4 f4 f10
endloop 2
endif 1
li i11 0
li i12 1
rcount i13 i14 i11 i2 i12 0 0:17
if 3 i14
loop 4 i15 i11 i13 i12
li i16 1
icmp gt i17 i15 i16
if 5 i17
ldf f18 p1 - 0 8
fadd f4 f4 f18
endif 5
endloop 4
endif 3
li i19 0
li i20 1
rcount i21 i22 i19 i2 i20 0 0:22
if 6 i22
loop 7 i23 i19 i21 i20
fcmp gt i24 f4 f3
if 8 i24
exit 7
endif 8
ldf f25 p1 - 0 0
ldf f26 p1 - 0 8
fmul f27 f25 f26
fadd f4 f4 f27
endloop 7
endif 6
call norm1 1 f28 1 p1
fadd f29 f4 f28
ret 1 f29
endfunc
fmt d1 6
fconv - - - g f
ftext %20
fconv - - - g f
ftext %20
fconv - - - g f
ftext %0A
#end
""")
EVENTS['opt5_licm_param'] = [
]
EVENTS2['opt5_licm_param'] = [
    ('T5', 'norm1', 'promote', '2', 'p1 0', False),
    ('T5', 'norm1', 'promote', '2', 'p1 8', False),
    ('T8', 'norm1', 1, '2', 2, 0),
    ('T8', 'scan', 1, '2', 1, 0),
    ('T8', 'scan', 1, '4', 1, 0),
]


# ---------------------------------------------------------------- opt5_unswitch
# mix: T5 promotes v's extent; T8 hoists the 13 pure instructions and header loads (3 commoned).
# The invariant conditions of loop 2 in order of first use: i13 (a > 0), i24 (b > 0), i27 (a > 5);
# the first two split the loop into four copies (i27 and the variant test of v[i] stay); placement
# (L-bm): w * 2.0 with its lf, the lf 1.0, `li 5`, a > 5 and the lf 0.5 are read only by the
# copies: placed in each arm that reads them (12 duplicates); `li 0` is read by both T9 tests
# (not placeable). one: one invariant condition (a > 2): two copies; h is read after the loop and
# its definition stands before it anyway: nothing placed.
CASES['opt5_unswitch'] = (r"""fn mix(v: f64[], a: i64, b: i64, w: f64) -> f64 {
    var s = 0.0
    for i in 0..len(v) {
        if a > 0 {
            s = s + v[i] * (w * 2.0)
        } else {
            s = s - v[i]
        }
        if b > 0 {
            s = s + 1.0
        }
        if a > 5 {
            s = s * 0.5
        }
        if v[i] > w {
            s = s + w
        }
    }
    return s
}
fn one(v: f64[], a: i64) -> f64 {
    var s = 0.0
    let h = f64(a) * 0.25
    for i in 0..len(v) {
        if a > 2 {
            s = s + h
        } else {
            s = s + v[i] * h
        }
    }
    return s + h
}
var v = zeros(3)
v[1] = 2.0
v[2] = 3.0
printf("%g %g %g\n", mix(v, 1, 1, 1.5), mix(v, 0, 0, 1.5), mix(v, 6, 0, 0.5))
printf("%g %g\n", one(v, 3), one(v, 1))
// opt5_unswitch -- DESIGN.md 5.8 T9: mix's loop split on a > 0 and b > 0 into four copies (the
// third invariant test a > 5 and the test of v[i] stay in each), the copies' own registers
// renumbered (L-bl) and the hoisted w * 2.0, 1.0, a > 5 and 0.5 placed into the arms of the
// copies that read them (L-bm); one splits once and places nothing (h is read after the loop)
""", r"""#sea 1
#target arm64-macos
#file opt5_unswitch.sea
func .main main 0:1:1 0 0
slot s1 24 8
slot s2 16 8
li i1 3
li i2 1
li i3 1
li i4 1
rcall sea_arr_new 0:33 1 p5 4 i2 i3 i1 i4
lf f6 #4000000000000000
li i7 1
ldi i8 p5 - 0 16
chkb i7 i8 0 0:34
ldi i9 p5 - 0 0
li i10 1
icmp ne i11 i9 i10
if 1 i11
rcall sea_arr_unique 0:34 1 p12 1 p5
mov p5 p12
endif 1
ldp p13 p5 - 0 40
stf f6 p13 i7 8 0
lf f14 #4008000000000000
li i15 2
ldi i16 p5 - 0 16
chkb i15 i16 0 0:35
ldi i17 p5 - 0 0
li i18 1
icmp ne i19 i17 i18
if 2 i19
rcall sea_arr_unique 0:35 1 p20 1 p5
mov p5 p20
endif 2
ldp p21 p5 - 0 40
stf f14 p21 i15 8 0
li i22 1
li i23 1
lf f24 #3FF8000000000000
call mix 1 f25 4 p5 i22 i23 f24
li i26 0
li i27 0
lf f28 #3FF8000000000000
call mix 1 f29 4 p5 i26 i27 f28
li i30 6
li i31 0
lf f32 #3FE0000000000000
call mix 1 f33 4 p5 i30 i31 f32
sa p34 s1
stf f25 p34 - 0 0
stf f29 p34 - 0 8
stf f33 p34 - 0 16
la p35 d1
rcall sea_printf 0:36 0 2 p35 p34
li i36 3
call one 1 f37 2 p5 i36
li i38 1
call one 1 f39 2 p5 i38
sa p40 s2
stf f37 p40 - 0 0
stf f39 p40 - 0 8
la p41 d2
rcall sea_printf 0:37 0 2 p41 p40
release p5
ret 0
endfunc
func mix fn 0:1:1 4 p1 i2 i3 f4 1 f
lf f5 #0000000000000000
li i6 0
ldi i7 p1 - 0 16
li i8 1
rcount i9 i10 i6 i7 i8 0 0:3
if 1 i10
loop 2 i11 i6 i9 i8
li i12 0
icmp gt i13 i2 i12
if 3 i13
ldi i14 p1 - 0 16
chkb i11 i14 0 0:5
ldp p15 p1 - 0 40
ldf f16 p15 i11 8 0
lf f17 #4000000000000000
fmul f18 f4 f17
fmul f19 f16 f18
fadd f5 f5 f19
else 3
ldi i20 p1 - 0 16
chkb i11 i20 0 0:7
ldp p21 p1 - 0 40
ldf f22 p21 i11 8 0
fsub f5 f5 f22
endif 3
li i23 0
icmp gt i24 i3 i23
if 4 i24
lf f25 #3FF0000000000000
fadd f5 f5 f25
endif 4
li i26 5
icmp gt i27 i2 i26
if 5 i27
lf f28 #3FE0000000000000
fmul f5 f5 f28
endif 5
ldi i29 p1 - 0 16
chkb i11 i29 0 0:15
ldp p30 p1 - 0 40
ldf f31 p30 i11 8 0
fcmp gt i32 f31 f4
if 6 i32
fadd f5 f5 f4
endif 6
endloop 2
endif 1
ret 1 f5
endfunc
func one fn 0:21:1 2 p1 i2 1 f
lf f3 #0000000000000000
itof f4 i2
lf f5 #3FD0000000000000
fmul f6 f4 f5
li i7 0
ldi i8 p1 - 0 16
li i9 1
rcount i10 i11 i7 i8 i9 0 0:24
if 1 i11
loop 2 i12 i7 i10 i9
li i13 2
icmp gt i14 i2 i13
if 3 i14
fadd f3 f3 f6
else 3
ldi i15 p1 - 0 16
chkb i12 i15 0 0:28
ldp p16 p1 - 0 40
ldf f17 p16 i12 8 0
fmul f18 f17 f6
fadd f3 f3 f18
endif 3
endloop 2
endif 1
fadd f19 f3 f6
ret 1 f19
endfunc
fmt d1 6
fconv - - - g f
ftext %20
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
EVENTS['opt5_unswitch'] = [
    ('T1', '.main', 'del', 'chkb i7 i8 0 0:34'),
    ('T1', '.main', 'del', 'chkb i15 i16 0 0:35'),
]
EVENTS2['opt5_unswitch'] = [
    ('T5', 'mix', 'promote', '2', 'p1 16', False),
    ('T8', 'mix', 1, '2', 13, 3),
    ('T9', 'mix', '2', 'i13 i24', 4),
    ('T9', 'mix', 'place', 6, 12),
    ('T5', 'one', 'promote', '2', 'p1 16', False),
    ('T8', 'one', 1, '2', 3, 0),
    ('T9', 'one', '2', 'i14', 2),
]


# ---------------------------------------------------------------- opt5_lcg
# lcg_fill: (p1, 0) promoted (pre-load, the isel of T2's sequence writes it by destination
# rewriting, one post-store); the loop is versioned on u (p4); in the fast copy T8 hoists the
# constants 16807, 2147483647, M, 30, 63, 0, 2147483647.0, the dead `li 1` (T10 deletes it) and u's
# data address; the result is 5.8's W5 text (checked by check_w5).
CASES['opt5_lcg'] = (r"""fn lcg_fill(ref s: i64, n: i64) -> f64[] {
    var u = zeros(n)
    for i in 0..n {
        s = 16807 * s % 2147483647
        u[i] = s / 2147483647
    }
    return u
}
var s = 42
printf("%.17g %.17g %d\n", lcg_fill(ref s, 3)[2], lcg_fill(ref s, 2)[1], s)
// opt5_lcg -- DESIGN.md 5.8, "The W5 loop after T1-T10": W5's lcg_fill (tests/accept/w5_stats.sea)
// with a two-line main; the fast copy of its loop is the text of 5.8 (s promoted, the % by
// 2147483647 a magic sequence, u's count tested once, the constants and u's data hoisted)
""", r"""#sea 1
#target arm64-macos
#file opt5_lcg.sea
func .main main 0:1:1 0 0
slot s1 8 8
slot s2 8 8
slot s3 24 8
li i1 42
sa p2 s1
sti i1 p2 - 0 0
li i3 3
call lcg_fill 1 p4 2 p2 i3
ldi i1 p2 - 0 0
li i5 2
ldi i6 p4 - 0 16
chkb i5 i6 0 0:10
ldp p7 p4 - 0 40
ldf f8 p7 i5 8 0
release p4
sa p9 s2
sti i1 p9 - 0 0
li i10 2
call lcg_fill 1 p11 2 p9 i10
ldi i1 p9 - 0 0
li i12 1
ldi i13 p11 - 0 16
chkb i12 i13 0 0:10
ldp p14 p11 - 0 40
ldf f15 p14 i12 8 0
release p11
sa p16 s3
stf f8 p16 - 0 0
stf f15 p16 - 0 8
sti i1 p16 - 0 16
la p17 d1
rcall sea_printf 0:10 0 2 p17 p16
ret 0
endfunc
func lcg_fill fn 0:1:1 2 p1 i2 1 p
li i3 1
li i4 1
li i5 1
rcall sea_arr_new 0:2 1 p6 4 i3 i4 i2 i5
li i7 0
li i8 1
rcount i9 i10 i7 i2 i8 0 0:3
if 1 i10
loop 2 i11 i7 i9 i8
li i12 16807
ldi i13 p1 - 0 0
imulc i14 i12 i13 0:4
li i15 #000000007FFFFFFF
imodf i16 i14 i15 0:4
sti i16 p1 - 0 0
ldi i17 p1 - 0 0
itof f18 i17
lf f19 #41DFFFFFFFC00000
fdiv f20 f18 f19
ldi i21 p6 - 0 16
chkb i11 i21 0 0:5
ldi i22 p6 - 0 0
li i23 1
icmp ne i24 i22 i23
if 3 i24
rcall sea_arr_unique 0:5 1 p25 1 p6
mov p6 p25
endif 3
ldp p26 p6 - 0 40
stf f20 p26 i11 8 0
endloop 2
endif 1
retain p6
release p6
ret 1 p6
endfunc
fmt d1 6
fconv - - 17 g f
ftext %20
fconv - - 17 g f
ftext %20
fconv - - - d i
ftext %0A
#end
""")
EVENTS['opt5_lcg'] = [
    ('T1', 'lcg_fill', 'del', 'chkb i11 i21 0 0:5'),
    ('T2', 'lcg_fill', 'imodf i16 i14 i15 0:4'),
    ('T3', 'lcg_fill', 'load', 'ldi i17 p1 - 0 0', 'i16'),
    ('T10', 'lcg_fill', 'retain', 'retain p6'),
]
EVENTS2['opt5_lcg'] = [
    ('T5', 'lcg_fill', 'promote', '2', 'p1 0', True),
    ('T5', 'lcg_fill', 'dest', '2', 'i36'),
    ('T6', 'lcg_fill', 'version', '2', 'p4'),
    ('T8', 'lcg_fill', 1, '2', 9, 0),
    ('T8', 'lcg_fill', 1, 'n2', 8, 0),
]


# ---------------------------------------------------------------- opt5_sor
# .main: the fill loops versioned; the while loop (do 15) is the outermost loop containing T's
# cow: versioned on T (p31); T8 hoists, from the j loop (21) outwards, the bases, extents, index
# terms and constants (fixed's, src's and T's headers commoned); T7 reduces the j loop's 10
# accesses (unit stride: fixed[j, i], src[j, i], T's columns i - 1, i, i + 1, 1 and nx - 2, the
# rows j - 1 and j + 1, the store of T[j, i]) and, in the slow copy's j loop, fixed's and src's;
# T8's second pass hoists T7's instructions and commons them; T9 splits the
# fast j loop on i == 0 (i110) and i == nx - 1 (i127) into four copies and places the 29
# placeable instructions (55 duplicates): the interior copy's arm holds its seven pointers.
CASES['opt5_sor'] = (r"""let h = 0.05
let nx = i64(round(0.25 / h)) + 1
let ny = i64(round(0.2 / h)) + 1
let omega = 1.5
let tol = 1e-8
let maxIt = 200
var fixed = filled(false, ny, nx)
var src = zeros(ny, nx)
var T = filled(20.0, ny, nx)
for i in 0..nx {
    for j in 0..ny {
        fixed[j, i] = j == 0 || j == ny - 1 || (i == 3 && j == 2)
        src[j, i] = 0.125 * f64(i + j)
    }
    T[0, i] = 40.0 + 5.0 * f64(i)
}
var itSor = 0
var dMax = inf
while dMax > tol && itSor < maxIt {
    itSor += 1
    dMax = 0.0
    for i in 0..nx {
        for j in 1..ny-1 {
            if fixed[j, i] { continue }
            let tw = if i == 0 { T[j, 1] } else { T[j, i-1] }
            let te = if i == nx - 1 { T[j, nx-2] } else { T[j, i+1] }
            let tgs = (tw + te + T[j-1, i] + T[j+1, i] + src[j, i]) / 4.0
            let tn = T[j, i] + omega * (tgs - T[j, i])
            let d = abs(tn - T[j, i])
            if d > dMax { dMax = d }
            T[j, i] = tn
        }
    }
}
printf("%d %.17g %.17g\n", itSor, T[1, 2], T[3, 5])
// opt5_sor -- DESIGN.md 5.8 on W4's scalar SOR loop (tests/accept/w4_sor.sea, here over a 5 x 6
// grid): the while loop versioned on T (T6), the bases and index terms hoisted (T8), the
// accesses of the j loop reduced to pointers (T7), the j loop split on i == 0 and i == nx - 1
// into four copies (T9), each copy's pointers placed in its own arm: the interior copy holds
// its seven and no branch but the fixed test (L-bm)
""", r"""#sea 1
#target arm64-macos
#file opt5_sor.sea
func .main main 0:1:1 0 0
slot s1 24 8
lf f1 #3FA999999999999A
lf f2 #3FD0000000000000
fdiv f3 f2 f1
fround f4 f3
ftoi i5 f4 0:2
li i6 1
iaddc i7 i5 i6 0:2
lf f8 #3FC999999999999A
fdiv f9 f8 f1
fround f10 f9
ftoi i11 f10 0:3
li i12 1
iaddc i13 i11 i12 0:3
lf f14 #3FF8000000000000
lf f15 #3E45798EE2308C3A
li i16 200
li i17 0
li i18 3
li i19 2
rcall sea_arr_new_u 0:7 1 p20 4 i18 i19 i13 i7
imul i21 i13 i7
ldp p22 p20 - 0 40
li i23 0
icmp gt i24 i21 i23
if 1 i24
li i25 1
isub i26 i21 i25
loop 2 i27 i23 i26 i25
stb i17 p22 i27 1 0
endloop 2
endif 1
li i28 1
li i29 2
rcall sea_arr_new 0:8 1 p30 4 i28 i29 i13 i7
lf f31 #4034000000000000
li i32 1
li i33 2
rcall sea_arr_new_u 0:9 1 p34 4 i32 i33 i13 i7
imul i35 i13 i7
ldp p36 p34 - 0 40
li i37 0
icmp gt i38 i35 i37
if 3 i38
li i39 1
isub i40 i35 i39
loop 4 i41 i37 i40 i39
stf f31 p36 i41 8 0
endloop 4
endif 3
li i42 0
li i43 1
rcount i44 i45 i42 i7 i43 0 0:10
if 5 i45
loop 6 i46 i42 i44 i43
li i47 0
li i48 1
rcount i49 i50 i47 i13 i48 0 0:11
if 7 i50
loop 8 i51 i47 i49 i48
li i52 0
icmp eq i53 i51 i52
ifz 9 i53
li i54 1
isubc i55 i13 i54 0:12
icmp eq i53 i51 i55
endif 9
ifz 10 i53
li i56 3
icmp eq i53 i46 i56
if 11 i53
li i57 2
icmp eq i53 i51 i57
endif 11
endif 10
ldi i58 p20 - 0 16
chkb i51 i58 0 0:12
ldi i59 p20 - 0 24
chkb i46 i59 1 0:12
ldi i60 p20 - 0 0
li i61 1
icmp ne i62 i60 i61
if 12 i62
rcall sea_arr_unique 0:12 1 p63 1 p20
mov p20 p63
endif 12
ldp p64 p20 - 0 40
imul i65 i46 i58
iadd i66 i51 i65
stb i53 p64 i66 1 0
lf f67 #3FC0000000000000
iaddc i68 i46 i51 0:13
itof f69 i68
fmul f70 f67 f69
ldi i71 p30 - 0 16
chkb i51 i71 0 0:13
ldi i72 p30 - 0 24
chkb i46 i72 1 0:13
ldi i73 p30 - 0 0
li i74 1
icmp ne i75 i73 i74
if 13 i75
rcall sea_arr_unique 0:13 1 p76 1 p30
mov p30 p76
endif 13
ldp p77 p30 - 0 40
imul i78 i46 i71
iadd i79 i51 i78
stf f70 p77 i79 8 0
endloop 8
endif 7
lf f80 #4044000000000000
lf f81 #4014000000000000
itof f82 i46
fmul f83 f81 f82
fadd f84 f80 f83
li i85 0
ldi i86 p34 - 0 16
chkb i85 i86 0 0:15
ldi i87 p34 - 0 24
chkb i46 i87 1 0:15
ldi i88 p34 - 0 0
li i89 1
icmp ne i90 i88 i89
if 14 i90
rcall sea_arr_unique 0:15 1 p91 1 p34
mov p34 p91
endif 14
ldp p92 p34 - 0 40
imul i93 i46 i86
iadd i94 i85 i93
stf f84 p92 i94 8 0
endloop 6
endif 5
li i95 0
lf f96 #7FF0000000000000
do 15
fcmp gt i97 f96 f15
if 16 i97
icmp lt i97 i95 i16
endif 16
ifz 17 i97
exit 15
endif 17
li i98 1
iaddc i95 i95 i98 0:20
lf f96 #0000000000000000
li i99 0
li i100 1
rcount i101 i102 i99 i7 i100 0 0:22
if 18 i102
loop 19 i103 i99 i101 i100
li i104 1
li i105 1
isubc i106 i13 i105 0:23
li i107 1
rcount i108 i109 i104 i106 i107 0 0:23
if 20 i109
loop 21 i110 i104 i108 i107
ldi i111 p20 - 0 16
chkb i110 i111 0 0:24
ldi i112 p20 - 0 24
chkb i103 i112 1 0:24
ldp p113 p20 - 0 40
imul i114 i103 i111
iadd i115 i110 i114
ldb i116 p113 i115 1 0
if 22 i116
next 21
endif 22
li i117 0
icmp eq i118 i103 i117
if 23 i118
li i119 1
ldi i120 p34 - 0 16
chkb i110 i120 0 0:25
ldi i121 p34 - 0 24
chkb i119 i121 1 0:25
ldp p122 p34 - 0 40
imul i123 i119 i120
iadd i124 i110 i123
ldf f125 p122 i124 8 0
else 23
li i126 1
isubc i127 i103 i126 0:25
ldi i128 p34 - 0 16
chkb i110 i128 0 0:25
ldi i129 p34 - 0 24
chkb i127 i129 1 0:25
ldp p130 p34 - 0 40
imul i131 i127 i128
iadd i132 i110 i131
ldf f125 p130 i132 8 0
endif 23
mov f133 f125
li i134 1
isubc i135 i7 i134 0:26
icmp eq i136 i103 i135
if 24 i136
li i137 2
isubc i138 i7 i137 0:26
ldi i139 p34 - 0 16
chkb i110 i139 0 0:26
ldi i140 p34 - 0 24
chkb i138 i140 1 0:26
ldp p141 p34 - 0 40
imul i142 i138 i139
iadd i143 i110 i142
ldf f144 p141 i143 8 0
else 24
li i145 1
iaddc i146 i103 i145 0:26
ldi i147 p34 - 0 16
chkb i110 i147 0 0:26
ldi i148 p34 - 0 24
chkb i146 i148 1 0:26
ldp p149 p34 - 0 40
imul i150 i146 i147
iadd i151 i110 i150
ldf f144 p149 i151 8 0
endif 24
mov f152 f144
fadd f153 f133 f152
li i154 1
isubc i155 i110 i154 0:27
ldi i156 p34 - 0 16
chkb i155 i156 0 0:27
ldi i157 p34 - 0 24
chkb i103 i157 1 0:27
ldp p158 p34 - 0 40
imul i159 i103 i156
iadd i160 i155 i159
ldf f161 p158 i160 8 0
fadd f162 f153 f161
li i163 1
iaddc i164 i110 i163 0:27
ldi i165 p34 - 0 16
chkb i164 i165 0 0:27
ldi i166 p34 - 0 24
chkb i103 i166 1 0:27
ldp p167 p34 - 0 40
imul i168 i103 i165
iadd i169 i164 i168
ldf f170 p167 i169 8 0
fadd f171 f162 f170
ldi i172 p30 - 0 16
chkb i110 i172 0 0:27
ldi i173 p30 - 0 24
chkb i103 i173 1 0:27
ldp p174 p30 - 0 40
imul i175 i103 i172
iadd i176 i110 i175
ldf f177 p174 i176 8 0
fadd f178 f171 f177
lf f179 #4010000000000000
fdiv f180 f178 f179
ldi i181 p34 - 0 16
chkb i110 i181 0 0:28
ldi i182 p34 - 0 24
chkb i103 i182 1 0:28
ldp p183 p34 - 0 40
imul i184 i103 i181
iadd i185 i110 i184
ldf f186 p183 i185 8 0
ldi i187 p34 - 0 16
chkb i110 i187 0 0:28
ldi i188 p34 - 0 24
chkb i103 i188 1 0:28
ldp p189 p34 - 0 40
imul i190 i103 i187
iadd i191 i110 i190
ldf f192 p189 i191 8 0
fsub f193 f180 f192
fmul f194 f14 f193
fadd f195 f186 f194
ldi i196 p34 - 0 16
chkb i110 i196 0 0:29
ldi i197 p34 - 0 24
chkb i103 i197 1 0:29
ldp p198 p34 - 0 40
imul i199 i103 i196
iadd i200 i110 i199
ldf f201 p198 i200 8 0
fsub f202 f195 f201
fabs f203 f202
fcmp gt i204 f203 f96
if 25 i204
mov f96 f203
endif 25
ldi i205 p34 - 0 16
chkb i110 i205 0 0:31
ldi i206 p34 - 0 24
chkb i103 i206 1 0:31
ldi i207 p34 - 0 0
li i208 1
icmp ne i209 i207 i208
if 26 i209
rcall sea_arr_unique 0:31 1 p210 1 p34
mov p34 p210
endif 26
ldp p211 p34 - 0 40
imul i212 i103 i205
iadd i213 i110 i212
stf f195 p211 i213 8 0
endloop 21
endif 20
endloop 19
endif 18
enddo 15
li i214 1
li i215 2
ldi i216 p34 - 0 16
chkb i214 i216 0 0:35
ldi i217 p34 - 0 24
chkb i215 i217 1 0:35
ldp p218 p34 - 0 40
imul i219 i215 i216
iadd i220 i214 i219
ldf f221 p218 i220 8 0
li i222 3
li i223 5
ldi i224 p34 - 0 16
chkb i222 i224 0 0:35
ldi i225 p34 - 0 24
chkb i223 i225 1 0:35
ldp p226 p34 - 0 40
imul i227 i223 i224
iadd i228 i222 i227
ldf f229 p226 i228 8 0
sa p230 s1
sti i95 p230 - 0 0
stf f221 p230 - 0 8
stf f229 p230 - 0 16
la p231 d1
rcall sea_printf 0:35 0 2 p231 p230
release p34
release p30
release p20
ret 0
endfunc
fmt d1 6
fconv - - - d i
ftext %20
fconv - - 17 g f
ftext %20
fconv - - 17 g f
ftext %0A
#end
""")
EVENTS['opt5_sor'] = [
    ('T1', '.main', 'wrap', 'isubc i55 i13 i54 0:12'),
    ('T1', '.main', 'del', 'chkb i51 i58 0 0:12'),
    ('T1', '.main', 'del', 'chkb i46 i59 1 0:12'),
    ('T1', '.main', 'wrap', 'iaddc i68 i46 i51 0:13'),
    ('T1', '.main', 'del', 'chkb i51 i71 0 0:13'),
    ('T1', '.main', 'del', 'chkb i46 i72 1 0:13'),
    ('T1', '.main', 'del', 'chkb i46 i87 1 0:15'),
    ('T1', '.main', 'wrap', 'isubc i106 i13 i105 0:23'),
    ('T1', '.main', 'del', 'chkb i110 i111 0 0:24'),
    ('T1', '.main', 'del', 'chkb i103 i112 1 0:24'),
    ('T1', '.main', 'del', 'chkb i110 i120 0 0:25'),
    ('T1', '.main', 'wrap', 'isubc i127 i103 i126 0:25'),
    ('T1', '.main', 'del', 'chkb i110 i128 0 0:25'),
    ('T1', '.main', 'del', 'chkb i127 i129 1 0:25'),
    ('T1', '.main', 'wrap', 'isubc i135 i7 i134 0:26'),
    ('T1', '.main', 'wrap', 'isubc i138 i7 i137 0:26'),
    ('T1', '.main', 'del', 'chkb i110 i139 0 0:26'),
    ('T1', '.main', 'wrap', 'iaddc i146 i103 i145 0:26'),
    ('T1', '.main', 'del', 'chkb i110 i147 0 0:26'),
    ('T1', '.main', 'del', 'chkb i146 i148 1 0:26'),
    ('T1', '.main', 'wrap', 'isubc i155 i110 i154 0:27'),
    ('T1', '.main', 'del', 'chkb i155 i156 0 0:27'),
    ('T1', '.main', 'del', 'chkb i103 i157 1 0:27'),
    ('T1', '.main', 'wrap', 'iaddc i164 i110 i163 0:27'),
    ('T1', '.main', 'del', 'chkb i164 i165 0 0:27'),
    ('T1', '.main', 'del', 'chkb i103 i166 1 0:27'),
    ('T1', '.main', 'del', 'chkb i110 i172 0 0:27'),
    ('T1', '.main', 'del', 'chkb i103 i173 1 0:27'),
    ('T1', '.main', 'del', 'chkb i110 i181 0 0:28'),
    ('T1', '.main', 'del', 'chkb i103 i182 1 0:28'),
    ('T1', '.main', 'del', 'chkb i110 i187 0 0:28'),
    ('T1', '.main', 'del', 'chkb i103 i188 1 0:28'),
    ('T1', '.main', 'del', 'chkb i110 i196 0 0:29'),
    ('T1', '.main', 'del', 'chkb i103 i197 1 0:29'),
    ('T1', '.main', 'del', 'chkb i110 i205 0 0:31'),
    ('T1', '.main', 'del', 'chkb i103 i206 1 0:31'),
    ('T2', '.main', 'fdiv f180 f178 f179'),
    ('T3', '.main', 'load', 'ldi i165 p34 - 0 16', 'i156'),
    ('T3', '.main', 'load', 'ldi i166 p34 - 0 24', 'i157'),
    ('T3', '.main', 'load', 'ldp p167 p34 - 0 40', 'p158'),
    ('T3', '.main', 'load', 'ldi i181 p34 - 0 16', 'i156'),
    ('T3', '.main', 'load', 'ldi i182 p34 - 0 24', 'i157'),
    ('T3', '.main', 'load', 'ldp p183 p34 - 0 40', 'p158'),
    ('T3', '.main', 'load', 'ldi i187 p34 - 0 16', 'i156'),
    ('T3', '.main', 'load', 'ldi i188 p34 - 0 24', 'i157'),
    ('T3', '.main', 'load', 'ldp p189 p34 - 0 40', 'p158'),
    ('T3', '.main', 'load', 'ldf f192 p158 i185 8 0', 'f186'),
    ('T3', '.main', 'load', 'ldi i196 p34 - 0 16', 'i156'),
    ('T3', '.main', 'load', 'ldi i197 p34 - 0 24', 'i157'),
    ('T3', '.main', 'load', 'ldp p198 p34 - 0 40', 'p158'),
    ('T3', '.main', 'load', 'ldf f201 p158 i185 8 0', 'f186'),
    ('T3', '.main', 'load', 'ldi i224 p34 - 0 16', 'i216'),
    ('T3', '.main', 'load', 'ldi i225 p34 - 0 24', 'i217'),
    ('T3', '.main', 'load', 'ldp p226 p34 - 0 40', 'p218'),
    ('T4', '.main', 'if 25 i204'),
]
EVENTS2['opt5_sor'] = [
    ('T6', '.main', 'version', '6', 'p19, p29, p31'),
    ('T6', '.main', 'version', '15', 'p31'),
    ('T8', '.main', 1, '8', 14, 2),
    ('T8', '.main', 1, '6', 18, 4),
    ('T8', '.main', 1, 'n4', 8, 2),
    ('T8', '.main', 1, 'n2', 12, 4),
    ('T8', '.main', 1, '21', 41, 17),
    ('T8', '.main', 1, '19', 18, 1),
    ('T8', '.main', 1, '15', 20, 3),
    ('T8', '.main', 1, 'n18', 21, 5),
    ('T8', '.main', 1, 'n16', 13, 1),
    ('T8', '.main', 1, 'n12', 15, 3),
    ('T7', '.main', '8', 'unit', 'stb i50 p340 i48 1 0'),
    ('T7', '.main', '8', 'unit', 'stf f66 p343 i48 8 0'),
    ('T7', '.main', '6', 'stride', 'stf f79 p346 - 0 0'),
    ('T7', '.main', '21', 'unit', 'ldb i108 p349 i103 1 0'),
    ('T7', '.main', '21', 'unit', 'ldf f117 p352 i103 8 0'),
    ('T7', '.main', '21', 'unit', 'ldf f117 p355 i103 8 0'),
    ('T7', '.main', '21', 'unit', 'ldf f135 p358 i103 8 0'),
    ('T7', '.main', '21', 'unit', 'ldf f135 p361 i103 8 0'),
    ('T7', '.main', '21', 'unit', 'ldf f149 p366 i103 8 0'),
    ('T7', '.main', '21', 'unit', 'ldf f153 p371 i103 8 0'),
    ('T7', '.main', '21', 'unit', 'ldf f159 p374 i103 8 0'),
    ('T7', '.main', '21', 'unit', 'ldf f164 p377 i103 8 0'),
    ('T7', '.main', '21', 'unit', 'stf f167 p380 i103 8 0'),
    ('T7', '.main', 'n18', 'unit', 'ldb i269 p381 i264 1 0'),
    ('T7', '.main', 'n18', 'unit', 'ldf f320 p384 i264 8 0'),
    ('T8', '.main', 2, '8', 4, 0),
    ('T8', '.main', 2, '6', 1, 1),
    ('T8', '.main', 2, '21', 32, 15),
    ('T8', '.main', 2, '19', 6, 0),
    ('T8', '.main', 2, '15', 6, 0),
    ('T8', '.main', 2, 'n18', 4, 0),
    ('T8', '.main', 2, 'n16', 1, 0),
    ('T8', '.main', 2, 'n12', 1, 0),
    ('T9', '.main', '21', 'i110 i127', 4),
    ('T9', '.main', 'place', 29, 55),
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
        for ext, text in (('sea', sea), ('lir1', lir1), ('lir2', LIR2[nm]), ('lir', LIR[nm])):
            with open(os.path.join(PASSES, '%s.%s' % (nm, ext)), 'w') as fh:
                fh.write(text)
    # lx (3.6.7, phase 1): its seaopt output renamed .lir2, and its sealopt output, equal to it
    for ext in ('lir2', 'lir'):
        with open(os.path.join(PASSES, 'lx.%s' % ext), 'w') as fh:
            fh.write(LIR2['lx'])
    # lir4_seaopt (hand-written seaopt test, L-bj): .lir2 and no .lir
    with open(os.path.join(PASSES, 'lir4_seaopt.lir2'), 'w') as fh:
        fh.write(LIR4_SEAOPT_LIR)
    if os.path.exists(os.path.join(PASSES, 'lir4_seaopt.lir')):
        os.remove(os.path.join(PASSES, 'lir4_seaopt.lir'))


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
    # sea.lir2 and sea.lir keep every label and data record, referenced or not (3.6.2)
    assert (nlab == len(labels)) if strict else all(int(t[1:]) <= nlab for t in labels), \
        (name, 'labels')
    return len(body)


def no_ind_write(name, text):
    """3.6.5: no instruction inside a `loop` writes its ind (T5-T9 keep it so)."""
    stack = []
    for ln in text.split('\n'):
        rec = ln.split(' ')
        if rec[0] == 'loop':
            stack.append(rec[2])
        elif rec[0] == 'do':
            stack.append(None)
        elif rec[0] in ('endloop', 'enddo'):
            stack.pop()
        elif rec[0] in FMT and rec[0] not in ('func', 'slot', 'endfunc') and stack:
            assert not set(writes(rec)) & set(stack), (name, 'ind written', ln)


def outside(text):
    """The header, slot and data records: equal in sea.lir1, sea.lir2 and sea.lir (3.6.5)."""
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


def design_w5():
    """5.8's "The W5 loop after T1-T10": its instructions (the comments dropped)."""
    with open(os.path.join(ROOT, 'docs', 'DESIGN.md')) as fh:
        doc = fh.read()
    k = doc.index('**The W5 loop after T1')
    a = doc.index('```\n', k) + 4
    b = doc.index('```', a)
    out = []
    for ln in doc[a:b].strip('\n').split('\n'):
        m = re.match(r'^(\S+)\s+(.*?)(\s{2,}\S.*)?$', ln.strip())
        out.append([m.group(1)] + m.group(2).split())
    return out


W5_CONSTS = {'K1': ('li', '16807'), 'M': ('li', '#8000000100000003'), 'W': ('li', '30'),
             'K63': ('li', '63'), 'C': ('li', '#000000007FFFFFFF'),
             'F': ('lf', '#41DFFFFFFFC00000'), 'Z0': ('li', '0')}


def check_w5(text):
    """opt5_lcg.lir: the fast copy of lcg_fill's loop is 5.8's W5 text, the names bound
    one-to-one to registers: S the promoted s (loaded before the versioning test, stored once
    after it), U the data address of u and the constants, all in the fast copy's arm."""
    recs, on = [], False
    for ln in text.split('\n'):
        if ln.startswith('func lcg_fill '):
            on = True
        if on:
            recs.append(ln.split(' '))
        if on and ln == 'endfunc':
            break
    lo = [k for k, x in enumerate(recs) if x[0] == 'loop'][0]
    hi = [k for k, x in enumerate(recs) if x == ['endloop', recs[lo][1]]][0]
    want = design_w5()
    got = recs[lo:hi + 1]
    assert len(want) == len(got), ('W5 loop length', len(want), len(got))
    bind = {}
    for w, g in zip(want, got):
        assert w[0] == g[0] and len(w) == len(g), ('W5 record', w, g)
        for a, b in zip(w[1:], g[1:]):
            if a == 'site':
                assert re.match(r'^[0-9]+:[0-9]+$', b), (w, g)
            elif re.match(r'^[A-Z][A-Za-z0-9]*$', a):
                assert bind.setdefault(a, b) == b, ('W5 name bound twice', a, b)
            else:
                assert a == b, ('W5 field', w, g)
    assert len(set(bind.values())) == len(bind), 'W5 names not one-to-one'
    arm = recs[[k for k in range(lo) if recs[k][0] == 'if'][-1] + 1:lo]
    for nm, (op, v) in W5_CONSTS.items():
        assert [op, bind[nm], v] in arm, ('W5 constant', nm)
    assert ['ldp', bind['U'], 'p4', '-', '0', str(SEA_ARR_DATA)] in arm, 'W5 U'
    vtest = [k for k in range(lo) if recs[k][0] == 'if'][-1]
    assert ['ldi', bind['S'], 'p1', '-', '0', '0'] in recs[:vtest], 'W5 S pre-load'
    end = [k for k, x in enumerate(recs) if x == ['endif', recs[vtest][1]]][0]
    assert recs[end + 1] == ['sti', bind['S'], 'p1', '-', '0', '0'], 'W5 S post-store'
    assert sum(1 for x in recs if x[0] == 'sti') == 1, 'W5: one store of s'


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
        LIR2[nm] = optimize(lir1, log)
        assert log == EVENTS[nm], (nm, 'seaopt events', log)
        log2 = []
        LIR[nm] = sealopt(LIR2[nm], log2)
        assert log2 == EVENTS2[nm], (nm, 'sealopt events', log2)
        nev += len(log) + len(log2)
    src = os.path.join(os.path.dirname(HERE), 'passes')
    with open(os.path.join(src, 'lx.lir1')) as fh:
        lx1 = fh.read()
    lxlog = []
    LIR2['lx'] = optimize(lx1, lxlog)
    assert lxlog == [] and sealopt(LIR2['lx'], lxlog) == LIR2['lx'] and lxlog == [], \
        'lx is changed by T1-T10'
    with open(os.path.join(src, 'lir4_seaopt.lir1')) as fh:
        l4 = fh.read()
    l4log = []
    assert optimize(l4, l4log) == LIR4_SEAOPT_LIR, 'lir4_seaopt.lir2 != its hand derivation'
    assert l4log == [('T10', '.main', 'retain', 'retain p5')], l4log
    main_write()
    for nm, (sea, lir1) in CASES.items():
        for ext in ('lir1', 'lir2', 'lir'):
            with open(os.path.join(PASSES, '%s.%s' % (nm, ext))) as fh:
                t = fh.read()
            nrec += check_lir('%s.%s' % (nm, ext), t, ext == 'lir1')
            no_ind_write('%s.%s' % (nm, ext), t)
        assert outside(lir1) == outside(LIR2[nm]) == outside(LIR[nm]), \
            (nm, 'header, slots or data changed')
        assert lir1.split('\n')[2] == '#file %s.sea' % nm, nm
    check_w5(LIR['opt5_lcg'])
    for nm in ('lx.lir2', 'lx.lir', 'lir4_seaopt.lir2'):
        with open(os.path.join(PASSES, nm)) as fh:
            nrec += check_lir(nm, fh.read(), False)
    assert not os.path.exists(os.path.join(PASSES, 'lir4_seaopt.lir'))
    if CHECK_BUILD:
        check_build()
    print('dump5_cases: %d opt5 dumps (%d events as derived), lx.lir2 = lx.lir (unchanged), '
          'lir4_seaopt.lir2 re-derived; %d records checked; T2\'s magic numbers equal 5.8\'s; '
          'opt5_lcg.lir\'s loop is 5.8\'s W5 text%s'
          % (len(CASES), nev, nrec, '; embedded lir1 equal to the build' if CHECK_BUILD else ''))


LIR, LIR2 = {}, {}

if __name__ == '__main__':
    run()
