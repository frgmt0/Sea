"""Sub-phase 9b (work package T2): the plotting dumps tests/passes/plot9_{check,hirl,rcall,release}
(DESIGN.md 2.14.4, 3.6.6 rule 39, Decision 39, L-ku; tests/CORPUS.md "passes/ rows of sub-phase 9b").

Run (never `python3`):

    timeout 120 uv run --no-project python tests/vectors/plot9_dumps.py [--out DIR]
        writes the dumps .ast .res .hir1 .hir .hirf .hirl .lir1 of the four tests into tests/passes
        (or DIR) from the inputs in tests/vectors/plot9_dumps/; the .sea and .out files are
        written by hand and not touched.
    timeout 120 uv run --no-project python tests/vectors/plot9_dumps.py --check
        builds every dump in memory and compares it with tests/passes (exit 0 and
        "plot9_dumps: N files ok", else exit 1 and each difference); writes nothing.
    timeout 120 uv run --no-project python tests/vectors/plot9_dumps.py --base BUILD [--check]
        first runs the pre-9b compiler BUILD/sea (sea e23b079 built in a scratch directory, the one
        the committed inputs come from) with `build --emit X --no-prelude` on the twin programs and
        on the four plotting programs, and writes those outputs as the inputs (with --check:
        compares them with the committed inputs instead, writing nothing).

Unknown arguments are an error (exit 2): nothing is written by accident.

HOW THE DUMPS ARE DERIVED. The authority is the hand check of every record against DESIGN.md 2.14.4
(seacheck's written form of a plotting call), 3.6.6 rule 39 and Decision 39; this script only
records, reproducibly, the mechanical part of that derivation:

* Inputs (tests/vectors/plot9_dumps/): for each test NAME a twin program twin_NAME.sea with the
  same lines as tests/passes/plot9_NAME.sea up to its first twin function, whose plotting calls
  are calls of recursive user functions of the same name lengths and parameter lists (figurf,
  panex, twin_z, plof/plog, xlinf, xlabex, ylabex, titlf, legenx, grix, xlif, ylif, x_tickz,
  y_tickz, y_reversf, axis_equax, save_svh), with `Figure` written as the struct type `Lu` padded
  to the same columns and `Axes` as `Chol` (checked by this script, line by line); the pre-9b
  compiler's dumps of each twin (twin_NAME.X); and that compiler's .ast and .res of each plotting
  program (base_plot9_NAME.ast / .res; its .res holds the phase rule's `rerr 259 handle types`).
* .ast: pass 1 is unchanged by 9b, so the base output is the golden.
* .res: the base output with the `rerr 259 handle types` record removed and the handle type nodes
  resolved as types 6 (Figure) and 7 (Axes) (2.14.4: seaname enters them as predeclared types).
* .hir1, .hir, .hirf, .hirl from the twin's: the twin's functions dropped; `call` of a twin
  function -> `lib <name> n` (2.14.4, every parameter written); every `ty` field (by the record
  formats of include/passes.txt) 8 -> 6 and 9 -> 7; an inserted default constant (a record at a
  position on a twin signature's line) at the position of the `lib` it belongs to (the call's
  name position, 2.14.4 "Written form"); the `dyn` of a fixed-size argument at the call's position
  (Decision 39; a `let` initializer's `dyn` keeps its own); per test: plot9_check's `cvt` of the
  i64[] argument at the argument (the twin's plog takes an i64[] and needs none), plot9_hirl's L10
  copy records and `.l` locals of the `dyn` at the call's position.
* .lir1 from the twin's: `call TWIN nr R na args` -> `rcall <sym> <site> nr R na args` with the
  entry's symbol (include/rt.inc) and site `0:LINE` (the call's line) for an S entry, `-` for
  XLABEL YLABEL TITLE GRID Y_REVERSE AXIS_EQUAL (rule 39); the twin's functions and the data
  records only they use dropped.
* plot9_rcall and plot9_release have no .hirf (equal to .hir, L-ek; asserted on the twins).
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
TESTS = os.path.dirname(HERE)
ROOT = os.path.dirname(TESTS)
INPUTS = os.path.join(HERE, 'plot9_dumps')
PASSES_TXT = os.path.join(ROOT, 'include', 'passes.txt')

# the twin function of each plotting name (the same length; plog is plot with an i64[] x)
TWIN = {'figurf': 'figure', 'panex': 'panel', 'twin_z': 'twin_y', 'plof': 'plot', 'plog': 'plot',
        'xlinf': 'xline', 'xlif': 'xlim', 'ylif': 'ylim', 'grix': 'grid', 'legenx': 'legend',
        'x_tickz': 'x_ticks', 'y_tickz': 'y_ticks', 'y_reversf': 'y_reverse',
        'axis_equax': 'axis_equal', 'xlabex': 'xlabel', 'ylabex': 'ylabel', 'titlf': 'title',
        'save_svh': 'save_svg'}
# rule 39: the entry symbol and site kind of each plotting call
ENT = {'figure': ('sea_figure', 'S'), 'panel': ('sea_panel', 'S'), 'twin_y': ('sea_twin_y', 'S'),
       'save_svg': ('sea_save_svg', 'S'), 'plot': ('sea_plot', 'S'), 'xline': ('sea_xline', 'S'),
       'xlabel': ('sea_xlabel', '-'), 'ylabel': ('sea_ylabel', '-'), 'title': ('sea_title', '-'),
       'legend': ('sea_legend', 'S'), 'grid': ('sea_grid', '-'), 'xlim': ('sea_xlim', 'S'),
       'ylim': ('sea_ylim', 'S'), 'x_ticks': ('sea_x_ticks', 'S'), 'y_ticks': ('sea_y_ticks', 'S'),
       'y_reverse': ('sea_y_reverse', '-'), 'axis_equal': ('sea_axis_equal', '-')}
TY = {'8': '6', '9': '7'}       # Lu -> Figure, Chol -> Axes
RERR = 'rerr %s 259 1 handle%%20types'

# per test: the kept functions, the twin dumps used, and the last data record of the program (.lir1)
TESTS_SPEC = {
    'check': {'fns': ['.main', 'g'], 'twin': ['hir1'], 'keep_data': None},
    'hirl': {'fns': ['.main'], 'twin': ['hir1', 'hir', 'hirf', 'hirl'], 'keep_data': None},
    'rcall': {'fns': ['.main'], 'twin': ['hir1', 'hir', 'hirf', 'hirl', 'lir1'], 'keep_data': 15},
    'release': {'fns': ['.main', 'g'], 'twin': ['hir1', 'hir', 'hirf', 'hirl', 'lir1'], 'keep_data': 5},
}
# the .res edits (2.14.4): (old record, new record) and the phase-rule record removed
RES_EDITS = {
    'check': ([('rtype 0:1:10 Axes s 0 0', 'rtype 0:1:10 Axes s 0 7'),
               ('rtype 0:1:49 Figure s 0 0', 'rtype 0:1:49 Figure s 0 6'),
               ('rtype 0:3:12 Axes s 0 0', 'rtype 0:3:12 Axes s 0 7'),
               ('rfn 0:1:1 g 2 4 1 2 0 0 10 11 12', 'rfn 0:1:1 g 2 4 1 2 6 7 10 11 12')], '0:1:10'),
    'hirl': ([], None),
    'rcall': ([], None),
    'release': ([('rtfd a 0', 'rtfd a 7'),
                 ('rtype 0:1:15 Axes s 0 0', 'rtype 0:1:15 Axes s 0 7'),
                 ('rtype 0:2:11 Figure s 0 0', 'rtype 0:2:11 Figure s 0 6'),
                 ('rfn 0:2:1 g 0 2 1 2 3 0 3', 'rfn 0:2:1 g 0 2 1 2 3 6 3')], '0:1:15'),
}


class Err(Exception):
    pass


def rd(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


# ------------------------------------------------------------ twin source check
def twin_first_line(src):
    """The 1-based line of the twin's first twin function (`fn <twin>(`)."""
    for i, l in enumerate(src.split('\n'), 1):
        m = re.match(r'fn (\w+)\(', l)
        if m and m.group(1) in TWIN:
            return i
    raise Err('no twin function')


def check_twin(name, twin_src, real_src):
    """The twin's lines before its first twin function, with the twin names and padded types
    mapped back, are the plotting program's first lines."""
    n = twin_first_line(twin_src) - 1
    tl = twin_src.split('\n')[:n]
    rl = real_src.split('\n')[:n]
    for i, (t, r) in enumerate(zip(tl, rl), 1):
        m = re.sub(r'\b(%s)\(' % '|'.join(TWIN), lambda g: TWIN[g.group(1)] + '(', t)
        m = re.sub(r'\bLu    ', 'Figure', m)
        m = re.sub(r'\bChol\b', 'Axes', m)
        if m != r:
            raise Err('twin_%s.sea:%d does not map to plot9_%s.sea:%d:\n  %s\n  %s' % (name, i, name, i, m, r))
    if len(rl) < n:
        raise Err('plot9_%s.sea is shorter than its twin' % name)
    return n + 1


# ------------------------------------------------------------ HIR conversion
def formats():
    F = {}
    for l in open(PASSES_TXT, encoding='utf-8'):
        t = l.split()
        if len(t) >= 5 and t[0] == 'rec' and t[1].startswith('H'):
            F[t[3]] = t[5:]
    return F


def remap(vals, fmt):
    """The fields after the opcode with every `ty` field mapped by TY."""
    vals = list(vals)
    i = 0
    counts = {}
    for f in fmt:
        name, _, typ = f.partition(':')
        rep = 1
        if '*' in typ:
            typ, _, cnt = typ.partition('*')
            rep = int(counts[cnt])
        typ = typ.rstrip('?')
        for _ in range(rep):
            if i >= len(vals):
                return vals
            if typ == 'ty':
                vals[i] = TY.get(vals[i], vals[i])
            if typ == 'u':
                counts[name] = vals[i]
            i += 1
    return vals


def hir_convert(text, name, keep_fns, first_twin_line, F):
    lines = text.split('\n')
    fid = {}
    for l in lines:
        t = l.split(' ')
        if t[0] == 'fn':
            fid[t[1]] = t[2]
    out = []
    keep = True
    for l in lines:
        t = l.split(' ')
        if t[0] == '#file':
            out.append(['#file', 'plot9_%s.sea' % name])
            continue
        if t[0] == 'fn':
            keep = t[2] in keep_fns
        if not keep:
            if t[0] == 'end':
                keep = True
            continue
        if t[0] in F:
            t = [t[0]] + remap(t[1:], F[t[0]])
        if t[0] == 'call' and fid.get(t[3]) in TWIN:
            t = ['lib', t[1], t[2], TWIN[fid[t[3]]], t[4]]
        out.append(t)
    # an inserted default (a position on a twin signature's line) goes to its lib's position
    for i, t in enumerate(out):
        if len(t) > 1 and t[1].startswith('0:') and int(t[1].split(':')[1]) >= first_twin_line:
            j = i + 1
            while out[j][0] not in ('lib', 'call'):
                j += 1
            if out[j][0] != 'lib':
                raise Err('plot9_%s: a twin-line record %r not followed by a lib' % (name, ' '.join(t)))
            t[1] = out[j][1]
    # Decision 39: a lib argument's dyn at the call's position; a let initializer's keeps its own
    for i, t in enumerate(out):
        if t[0] == 'dyn':
            j = i + 1
            while out[j][0] not in ('lib', 'call', 'bind', 'eval', 'ret', 'set'):
                j += 1
            if out[j][0] == 'call':
                raise Err('plot9_%s: a dyn of a user call' % name)
            if out[j][0] == 'lib':
                t[1] = out[j][1]
    return '\n'.join(' '.join(t) for t in out)


# ------------------------------------------------------------ LIR conversion
def lir_convert(lir, src, name, keep_data):
    srcl = src.split('\n')
    ranges = {}
    cur = None
    for i, l in enumerate(srcl, 1):
        m = re.match(r'fn (\w+)', l)
        if m and not l.rstrip().endswith('}'):
            cur = m.group(1)
            ranges[cur] = [i, None]
        elif cur and l == '}':
            ranges[cur][1] = i
            cur = None

    def in_fn(i):
        for nm, (a, b) in ranges.items():
            if a <= i <= b:
                return nm
        return '.main'

    def line_of(twin, fn, nth):
        hits = [i + 1 for i, l in enumerate(srcl) if re.search(r'\b%s\(' % twin, l)
                and not l.startswith('fn ') and in_fn(i + 1) == fn]
        return hits[nth]

    seen = {}
    func = None
    out = []
    keep = True
    for l in lir.split('\n'):
        t = l.split(' ')
        if t[0] == '#file':
            out.append('#file plot9_%s.sea' % name)
            continue
        if t[0] == 'func':
            keep = t[1] not in TWIN
            func = t[1]
        if not keep:
            if t[0] == 'endfunc':
                keep = True
            continue
        if t[0] in ('str', 'fmt') and int(t[1][1:]) > keep_data:
            keep = 'data'
            continue
        if keep == 'data':
            if t[0] in ('fconv', 'ftext'):
                continue
            keep = True
        if t[0] == 'call' and t[1] in TWIN:
            sym, s = ENT[TWIN[t[1]]]
            n = seen.get((func, t[1]), 0)
            seen[(func, t[1])] = n + 1
            site = '0:%d' % line_of(t[1], func, n) if s == 'S' else '-'
            t = ['rcall', sym, site] + t[2:]
        out.append(' '.join(t))
    return '\n'.join(out)


# ------------------------------------------------------------ per-test edits
def res_edit(name, text):
    edits, rerr = RES_EDITS[name]
    L = text.split('\n')
    for a, b in edits:
        if L.count(a) != 1:
            raise Err('plot9_%s.res: %r not found once' % (name, a))
        L[L.index(a)] = b
    if rerr is not None:
        drop = RERR % rerr
        if L.count(drop) != 1:
            raise Err('plot9_%s.res: %r not found once' % (name, drop))
        L.remove(drop)
    if any(l.startswith('rerr ') for l in L):
        raise Err('plot9_%s.res: a rerr record is left' % name)
    return '\n'.join(L)


def edit_check_hir1(text):
    """The i64[] argument k of plot(p, k, [1.0, 2.0]): its cvt at the argument (Decision 39)."""
    h = text.split('\n')
    k = h.index('lv 0:6:13 11 3')
    h.insert(k + 1, 'cvt 0:6:13 10')
    return '\n'.join(h)


def edit_hirl_hirl(text):
    """L10's copy of the fixed-size [4.0, 5.0] and its .l locals at the call's position."""
    L = text.split('\n')
    a = L.index('xblk 0:5:19 13 4')
    b = L.index('xblk 0:5:19 10 6')
    for i in range(a + 1, b + 1):
        f = L[i].split(' ')
        if f[1] != '0:5:19':
            raise Err('plot9_hirl.hirl: unexpected record %r in the L10 copy' % L[i])
        f[1] = '0:5:1'
        L[i] = ' '.join(f)
    for m in range(38, 43):
        old = [x for x in L if x.startswith('loc .l%d ' % m)]
        if len(old) != 1 or not old[0].endswith(' 0:5:19'):
            raise Err('plot9_hirl.hirl: local .l%d not as expected' % m)
        L[L.index(old[0])] = old[0][:-len('0:5:19')] + '0:5:1'
    return '\n'.join(L)


def build(inputs):
    """{file name: content} of every dump."""
    F = formats()
    out = {}
    for name, spec in TESTS_SPEC.items():
        nm = 'plot9_' + name
        twin_src = rd(os.path.join(inputs, 'twin_%s.sea' % name))
        real_src = rd(os.path.join(TESTS, 'passes', nm + '.sea'))
        first = check_twin(name, twin_src, real_src)
        tw = {x: rd(os.path.join(inputs, 'twin_%s.%s' % (name, x))) for x in spec['twin']}
        out[nm + '.ast'] = rd(os.path.join(inputs, 'base_%s.ast' % nm))
        out[nm + '.res'] = res_edit(name, rd(os.path.join(inputs, 'base_%s.res' % nm)))
        if 'hirf' in tw and name != 'hirl' and tw['hirf'] != tw['hir']:
            raise Err('twin_%s: .hirf differs from .hir, so plot9_%s needs a .hirf' % (name, name))
        for x in ('hir1', 'hir', 'hirf', 'hirl'):
            if x not in tw or (x == 'hirf' and name != 'hirl'):
                continue
            out[nm + '.' + x] = hir_convert(tw[x], name, spec['fns'], first, F)
        if 'lir1' in tw:
            out[nm + '.lir1'] = lir_convert(tw['lir1'], twin_src, name, spec['keep_data'])
    out['plot9_check.hir1'] = edit_check_hir1(out['plot9_check.hir1'])
    out['plot9_hirl.hirl'] = edit_hirl_hirl(out['plot9_hirl.hirl'])
    return out


# ------------------------------------------------------------ --base: regenerate the inputs
def base_inputs(build_dir, scratch):
    """{input file name: content} from the pre-9b compiler BUILD/sea."""
    sea = os.path.join(build_dir, 'sea')
    if not os.access(sea, os.X_OK):
        raise Err('%s is not an executable compiler' % sea)
    out = {}

    def emit(src_path, base, kind):
        dst = os.path.join(scratch, base + '.sea')
        with open(dst, 'w', encoding='utf-8') as f:
            f.write(rd(src_path))
        r = subprocess.run([sea, 'build', '--emit', kind, '--no-prelude', base + '.sea'],
                           cwd=scratch, capture_output=True, timeout=120)
        if r.returncode != 0:
            raise Err('%s --emit %s %s.sea: status %d: %s'
                      % (sea, kind, base, r.returncode, r.stderr.decode('utf-8', 'replace')[:300]))
        return r.stdout.decode('utf-8')

    for name, spec in TESTS_SPEC.items():
        for x in spec['twin']:
            out['twin_%s.%s' % (name, x)] = emit(os.path.join(INPUTS, 'twin_%s.sea' % name),
                                                'twin_' + name, x)
        nm = 'plot9_' + name
        for x in ('ast', 'res'):
            out['base_%s.%s' % (nm, x)] = emit(os.path.join(TESTS, 'passes', nm + '.sea'), nm, x)
    return out


def compare(files, where):
    bad = 0
    for fn in sorted(files):
        p = os.path.join(where, fn)
        try:
            have = rd(p)
        except OSError:
            print('missing: %s' % p)
            bad += 1
            continue
        if have != files[fn]:
            print('differs: %s' % p)
            bad += 1
    return bad


def write(files, where):
    os.makedirs(where, exist_ok=True)
    for fn, text in sorted(files.items()):
        with open(os.path.join(where, fn), 'w', encoding='utf-8') as f:
            f.write(text)


def main(argv):
    out = os.path.join(TESTS, 'passes')
    check = False
    base = None
    while argv:
        if argv[0] == '--check':
            check = True
            argv = argv[1:]
        elif argv[0] == '--out' and len(argv) >= 2:
            out = argv[1]
            argv = argv[2:]
        elif argv[0] == '--base' and len(argv) >= 2:
            base = argv[1]
            argv = argv[2:]
        else:
            print('usage: plot9_dumps.py [--base BUILD] [--out DIR | --check]', file=sys.stderr)
            return 2
    try:
        inputs = INPUTS
        if base is not None:
            scratch = tempfile.mkdtemp(prefix='plot9_dumps.')
            try:
                ins = base_inputs(base, scratch)
            finally:
                shutil.rmtree(scratch, ignore_errors=True)
            if check:
                bad = compare(ins, INPUTS)
                if bad:
                    print('plot9_dumps: %d input file(s) differ from the base compiler' % bad)
                    return 1
                print('plot9_dumps: %d input files reproduced by %s' % (len(ins), base))
            else:
                write(ins, INPUTS)
                print('plot9_dumps: wrote %d input files' % len(ins))
        files = build(inputs)
    except (Err, OSError, ValueError, IndexError, subprocess.TimeoutExpired) as e:
        print('plot9_dumps: %s' % e, file=sys.stderr)
        return 1
    if check:
        bad = compare(files, out)
        if bad:
            print('plot9_dumps: %d file(s) differ' % bad)
            return 1
        print('plot9_dumps: %d files ok' % len(files))
        return 0
    write(files, out)
    print('plot9_dumps: wrote %d files into %s' % (len(files), out))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
