"""Sub-phase 9b (work package T1): the plot programs, the plotting error tests and the retirements of
phase 9 (DESIGN.md 2.14.8, 2.14.2, 2.14.4, 2.14.6; Decisions 131-142; lead decisions L-ke - L-lf;
LANGUAGE.md 9.2, 12).

Run (never `python3`):

    timeout 120 uv run --no-project python tests/vectors/plot9_cases.py [--out TESTS_DIR]
        writes tests/plots/plot_*.{sea,struct} (the 9b programs of 2.14.8 with their structural
        files; `.out` where a program prints), tests/errors/r_plot_* (run time: .sea .err .out
        .status) and tests/errors/err_plot_* (compile time: .sea .err .status), and deletes the
        retired errors/err_ns_lib_figure.*, errors/err_ns_handle.* and passes/res_err_handle.*
        (2.14.4, L-kx: the phase-rule table is empty from 9b; prel4h_cases.py and res_cases.py no
        longer write the first and the last). --out writes into another copy of tests/.
    timeout 120 uv run --no-project python tests/vectors/plot9_cases.py --check
        regenerates everything in memory and compares it with the files on disk (exit 0 and
        "plot9_cases: N files ok", else exit 1 and each difference); the retired files must be
        absent.

The 9c part (bars, contours, images, PNG and the known-answer files of 2.14.8) is added by 9c's T1.

HOW EVERY EXPECTED BYTE IS DERIVED (never from a run of the compiler or of the runtime):

* By Decision 13 the SVG bytes are not derived: a plot test checks well-formedness, the `.struct`
  file and (in the cross run) identical bytes on both targets and variants. Every `.struct` line is
  computed here by a model of LANGUAGE.md 12 and DESIGN.md 2.14.6 that each program's calls drive
  one for one (the `Case` methods below emit the Sea statement and apply the call to the model):
  the figure store of L-ke (axes records, the pair's properties in the base record, L-km), the
  style scan and colour rule of L-ki/L-kh (cycle per axes, a twin's starting at index 1, Decision
  135), the counts of the element grammar (one `line` per series with a line part, one `markers`
  per series with a marker, one `xline` per reference line, one `legend` group when a location is
  set and a line series of the pair has a label, L-kn; one `grid` path when the switch is on), the
  subpaths of a line (the maximal runs of points with finite x and y, 2.14.2), and the tick label
  texts of the limits rules 1-6.
* The limits and ticks (2.14.6 "Limits", L-kk) are transcribed into Python float operations one for
  one: d(k) by k multiplications by 10.0 (k >= 0) or 1.0 / (10.0 multiplied -k times); count(s) =
  ceil(hi / s) - floor(lo / s) with ceil/floor of a non-finite value left non-finite (so a count is
  NaN or infinite and every "count <= 7" is false); the two k loops bounded to -300 ... 300; the
  first of 1, 2, 5 times d(k); default limits floor(lo / s) * s and ceil(hi / s) * s with the ticks
  (floor(lo / s) + i) * s, i = 0 ... count; explicit limits with the ticks (c0 + i) * s, c0 =
  ceil(lo / s), i = 0 ... floor(hi / s) - c0; the zero range widened to v -+ |v| / 10 (-1, 1 at
  0), else v -+ 1, else 0 ... 1; category ticks 0 ... n - 1 inside the limits (rule 2); axis equal
  (rule 6) with pw and ph from the layout formulas (cw = W / ncols, ch = (H - hb) / nrows, mr 16 or
  68 with a twin); a tick equal to the one before or not finite is not drawn. Texts: v + 0.0 with
  `%.{p}f`, p = max(0, -k), or `%g` when s >= 1e6 or s < 1e-4; when two adjacent texts are equal,
  `%.{q}g` with q the smallest of 7 ... 17 that separates them (Decision 142 (a)). Python's `%`
  formatting is C's for these conversions (correctly rounded on both C libraries, as 2.14.6
  assumes).
* Run-time errors: the texts of LANGUAGE.md 9.2 / include/errors.inc (codes 2, 16, 19, 20, 22-27,
  29), the slots of 2.14.2's table (`%g` of NaN and +-Inf as `NaN`, `Inf`, `-Inf`, as _sea_err
  writes them), at the line of the call, output flushed first, status 1; each entry's checks in its
  parameter order (L-kg). Compile errors: DESIGN.md 2.6.2's texts at their `at` node (a call at its
  callee name, a `narg` at its name, a `ref` argument at `ref`, a type at its text, a `bin` at its
  left operand, a format argument at the argument), the types of 243 as pass 2a writes them
  (`Axes`, `Figure`, `f64[]`, `f64[,]`, `str`); lines and columns computed from a marker in the
  source text.
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
TESTS_DEFAULT = os.path.dirname(HERE)

OUT = {}        # relative path (to tests/) -> bytes, in generation order
RETIRED = (['errors/err_ns_lib_figure.' + x for x in ('sea', 'err', 'status')]
           + ['errors/err_ns_handle.' + x for x in ('sea', 'err', 'status')]
           + ['passes/res_err_handle.' + x for x in ('sea', 'ast', 'res')])

NAN = float('nan')
INF = float('inf')

CYCLE = ['#0072bd', '#d95319', '#edb120', '#7e2f8e', '#77ac30', '#4dbeee', '#a2142f']
LETTER = {'r': '#ff0000', 'g': '#00a000', 'b': '#0000ff', 'c': '#00bfbf', 'm': '#bf00bf',
          'y': '#bfbf00', 'k': '#000000', 'w': '#ffffff'}
MARKERS = 'osd^vx+*.'
LOCS = ['north', 'south', 'east', 'west', 'northeast', 'northwest', 'southeast', 'southwest']
INCLUDE = os.path.join(os.path.dirname(TESTS_DEFAULT), 'include')


def equiv(fname, name):
    """The value of `.equiv NAME, V` in include/FNAME (the contract files, never a copy)."""
    with open(os.path.join(INCLUDE, fname)) as f:
        for line in f:
            t = line.replace(',', ' ').split()
            if len(t) >= 3 and t[0] == '.equiv' and t[1] == name:
                return int(t[2])
    raise KeyError(name)


LIM_GRID = equiv('limits.inc', 'SEA_LIM_PLOT_GRID')
LIM_PX = equiv('limits.inc', 'SEA_LIM_PLOT_PX')
EXIT_RUN_ERROR = equiv('errors.inc', 'SEA_EXIT_RUN_ERROR')
EXIT_COMPILE = equiv('errors.inc', 'SEA_EXIT_COMPILE')


def emit(rel, text):
    assert rel not in OUT, rel
    OUT[rel] = text.encode('utf-8') if isinstance(text, str) else text


# ============================================================ the tick rules (2.14.6, L-kk)
def fin(x):
    return not (math.isnan(x) or math.isinf(x))


def fceil(x):
    return float(math.ceil(x)) if fin(x) else x


def ffloor(x):
    return float(math.floor(x)) if fin(x) else x


def dk(k):
    v = 1.0
    if k >= 0:
        for _ in range(k):
            v = v * 10.0
        return v
    for _ in range(-k):
        v = v * 10.0
    return 1.0 / v


def count(lo, hi, s):
    return fceil(hi / s) - ffloor(lo / s)


def le7(c):
    return c <= 7.0          # False for NaN and +Inf, as 2.14.6 rule 5 requires


def step(lo, hi):
    """(s, k) of rule 5, or None (no step)."""
    k = 0
    while k < 300 and not le7(count(lo, hi, 5.0 * dk(k))):
        k = k + 1
    while k > -300 and le7(count(lo, hi, 5.0 * dk(k - 1))):
        k = k - 1
    for m in (1.0, 2.0, 5.0):
        s = m * dk(k)
        if le7(count(lo, hi, s)):
            return s, k
    return None


def drawn(ticks):
    """Drop a tick equal to the one before it or not finite (rule 5)."""
    out = []
    for t in ticks:
        if not fin(t):
            continue
        if out and t == out[-1]:
            continue
        out.append(t)
    return out


def explicit_ticks(lo, hi):
    st = step(lo, hi)
    if st is None:
        return [], None
    s, k = st
    c0 = fceil(lo / s)
    n = ffloor(hi / s) - c0
    if not n >= 0:
        return [], st
    return drawn([(c0 + float(i)) * s for i in range(int(n) + 1)]), st


def default_limits(ext):
    """Rule 4: (lo, hi, ticks, step) from the extent (None or (lo, hi))."""
    if ext is None:
        lo, hi = 0.0, 1.0
    else:
        lo, hi = ext
        if lo == hi:
            v = lo
            if v == 0.0:
                lo, hi = -1.0, 1.0
            else:
                lo, hi = v - abs(v) / 10.0, v + abs(v) / 10.0
                if not (fin(lo) and fin(hi)):
                    lo, hi = v - 1.0, v + 1.0
                    if lo == hi:
                        lo, hi = 0.0, 1.0
    st = step(lo, hi)
    if st is None:
        return lo, hi, [], None
    s, k = st
    lo2 = ffloor(lo / s) * s
    hi2 = fceil(hi / s) * s
    if not (fin(lo2) and fin(hi2)):
        return lo, hi, [], None
    c = int(count(lo, hi, s))
    f0 = ffloor(lo / s)
    return lo2, hi2, drawn([(f0 + float(i)) * s for i in range(c + 1)]), st


def tick_texts(ticks, st):
    if not ticks:
        return []
    s, k = st
    if s >= 1e6 or s < 1e-4:
        texts = ['%g' % (v + 0.0) for v in ticks]
    else:
        p = max(0, -k)
        texts = ['%.*f' % (p, v + 0.0) for v in ticks]
    if any(texts[i] == texts[i + 1] for i in range(len(texts) - 1)):
        for q in range(7, 18):
            texts = ['%.*g' % (q, v + 0.0) for v in ticks]
            if all(texts[i] != texts[i + 1] for i in range(len(texts) - 1)):
                break
    return texts


# ============================================================ the figure model (L-ke, 2.14.6)
class Rec:
    def __init__(self, kind, base, row, col, rs, cs):
        self.kind, self.base, self.twin = kind, base, -1
        self.row, self.col, self.rs, self.cs = row, col, rs, cs
        self.title = self.xlabel = self.ylabel = ''
        self.grid = self.rev = self.equal = False
        self.xlim = self.ylim = None
        self.loc = 0
        self.xcats = []
        self.ycats = []
        self.cycle = 0 if kind == 0 else 1


class Series:
    def __init__(self, kind, ax, color, line, marker, label, x=None, y=None, pos=None):
        self.kind, self.ax, self.color, self.line, self.marker = kind, ax, color, line, marker
        self.label, self.x, self.y, self.pos = label, x, y, pos


class Fig:
    def __init__(self, nrows, ncols, name, w, h):
        assert 1 <= nrows <= LIM_GRID and 1 <= ncols <= LIM_GRID
        assert 1 <= w <= LIM_PX and 1 <= h <= LIM_PX
        self.nrows, self.ncols, self.name, self.w, self.h = nrows, ncols, name, w, h
        self.recs = []
        self.series = []
        self.cells = set()

    def snapshot(self):
        import copy
        return copy.deepcopy(self)


def parse_style(s, xline):
    """(line code, marker code, letter colour or None) by L-ki; raises ValueError."""
    line = marker = 0
    col = None
    i = 0
    while i < len(s):
        two = s[i:i + 2]
        if two in ('--', '-.'):
            if line:
                raise ValueError(s)
            line = 2 if two == '--' else 4
            i += 2
            continue
        ch = s[i]
        if ch in '-:':
            if line:
                raise ValueError(s)
            line = 1 if ch == '-' else 3
        elif ch in MARKERS:
            if marker or xline:
                raise ValueError(s)
            marker = MARKERS.index(ch) + 1
        elif ch in LETTER:
            if col is not None:
                raise ValueError(s)
            col = LETTER[ch]
        else:
            raise ValueError(s)
        i += 1
    if not line and not marker:
        line = 1
    return line, marker, col


def check_color(c):
    if c == '':
        return None
    if len(c) == 7 and c[0] == '#' and all(ch in '0123456789abcdefABCDEF' for ch in c[1:]):
        return c.lower()
    raise ValueError(c)


def resolve_color(rec, color, letter):
    if color is not None:
        return color
    if letter is not None:
        return letter
    c = CYCLE[rec.cycle % 7]
    rec.cycle += 1
    return c


# ============================================================ the struct of a figure
def extent(vals):
    v = [x for x in vals if fin(x)]
    if not v:
        return None
    return (min(v), max(v))


def axis(ext, explicit, cats):
    """(lo, hi, texts, ticks, st) of one axis by rules 1, 2 and 4, in numbered order (the lead's reading):
    explicit limits give numeric ticks even with category labels set; rule 6 recomputes later."""
    if explicit is not None:
        lo, hi = explicit
        ticks, st = explicit_ticks(lo, hi)
        return lo, hi, tick_texts(ticks, st), ticks, st
    if cats:
        n = len(cats)
        if ext is None:
            lo, hi = -0.5, float(n) - 0.5
        else:
            lo, hi = min(-0.5, ext[0]), max(float(n) - 0.5, ext[1])
        idx = [i for i in range(n) if lo <= float(i) <= hi]
        return lo, hi, [cats[i] for i in idx], [float(i) for i in idx], None
    lo, hi, ticks, st = default_limits(ext)
    return lo, hi, tick_texts(ticks, st), ticks, st


def runs(x, y):
    n = 0
    inrun = False
    for a, b in zip(x, y):
        if fin(a) and fin(b):
            if not inrun:
                n += 1
            inrun = True
        else:
            inrun = False
    return n


def struct_of(fig, path, comments):
    L = ['# %s' % c for c in comments]
    L.append('file %s' % path)
    L.append('canvas %d %d' % (fig.w, fig.h))
    L.append('heading %s' % (svg_text(fig.name) if fig.name != '' else '-'))
    bases = [i for i, r in enumerate(fig.recs) if r.kind == 0]
    L.append('panels %d' % len(bases))
    hb = 24.0 if fig.name != '' else 0.0
    cw = float(fig.w) / float(fig.ncols)
    ch = (float(fig.h) - hb) / float(fig.nrows)
    for k, bi in enumerate(bases):
        b = fig.recs[bi]
        t = fig.recs[b.twin] if b.twin >= 0 else None
        pair = [bi] + ([b.twin] if t is not None else [])
        sers = [s for s in fig.series if s.ax in pair]
        L.append('panel %d' % k)
        L.append('title %s' % (svg_text(b.title) or '-'))
        L.append('xlabel %s' % (svg_text(b.xlabel) or '-'))
        L.append('ylabel %s' % (svg_text(b.ylabel) or '-'))
        L.append('ylabel2 %s' % (svg_text(t.ylabel if t is not None else '') or '-'))
        lines = [s for s in sers if s.kind == 1 and s.line]
        marks = [s for s in sers if s.kind == 1 and s.marker]
        xls = [s for s in sers if s.kind == 2]
        labelled = [s for s in sers if s.kind == 1 and s.label != '']
        has_legend = b.loc != 0 and len(labelled) > 0
        L.append('count line %d' % len(lines))
        L.append('count markers %d' % len(marks))
        L.append('count xline %d' % len(xls))
        L.append('count grid %d' % (1 if b.grid else 0))
        L.append('count legend %d' % (1 if has_legend else 0))
        if has_legend:
            L.append('count legend-line %d' % len([s for s in labelled if s.line]))
            L.append('count legend-marker %d' % len([s for s in labelled if s.marker]))
            for s in labelled:
                L.append('legend %s' % svg_text(s.label))
        for i, s in enumerate(lines):
            L.append('subpaths %d %d' % (i, runs(s.x, s.y)))
        for i, s in enumerate(lines):
            L.append('color line %d %s' % (i, s.color))
        for i, s in enumerate(marks):
            L.append('color markers %d %s' % (i, s.color))
        for i, s in enumerate(xls):
            L.append('color xline %d %s' % (i, s.color))
        # limits and ticks: the x-axis of the pair, the base's y-axis, the twin's (rules 1-5)
        xs = [v for s in sers if s.kind == 1 for v in s.x]
        ybs = [v for s in sers if s.kind == 1 and s.ax == bi for v in s.y]
        x = list(axis(extent(xs), b.xlim, b.xcats))
        y = list(axis(extent(ybs), b.ylim, b.ycats))
        if b.equal:
            # rule 6 with the layout of 2.14.6
            w = float(b.cs) * cw
            h = float(b.rs) * ch
            mr = 68.0 if t is not None else 16.0
            pw = w - 56.0 - mr
            ph = h - 28.0 - 44.0
            pw = 1.0 if pw < 1.0 else pw
            ph = 1.0 if ph < 1.0 else ph
            ux = (x[1] - x[0]) / pw
            uy = (y[1] - y[0]) / ph
            if ux > uy:
                c = (y[0] + y[1]) / 2.0
                nlo, nhi = c - (ux * ph) / 2.0, c + (ux * ph) / 2.0
                if fin(nlo) and fin(nhi):
                    ticks, st = explicit_ticks(nlo, nhi)
                    y = [nlo, nhi, tick_texts(ticks, st), ticks, st]
            else:
                c = (x[0] + x[1]) / 2.0
                nlo, nhi = c - (uy * pw) / 2.0, c + (uy * pw) / 2.0
                if fin(nlo) and fin(nhi):
                    ticks, st = explicit_ticks(nlo, nhi)
                    x = [nlo, nhi, tick_texts(ticks, st), ticks, st]
        tick_lines(L, 'xtick', x[2])
        tick_lines(L, 'ytick', y[2])
        if t is not None:
            yts = [v for s in sers if s.kind == 1 and s.ax == b.twin for v in s.y]
            y2 = axis(extent(yts), t.ylim, t.ycats)
            tick_lines(L, 'ytick2', y2[2])
        else:
            L.append('count ytick2 0')
    return '\n'.join(L) + '\n'


def tick_lines(L, key, texts):
    L.append('count %s %d' % (key, len(texts)))
    for tx in texts:
        L.append('%s %s' % (key, svg_text(tx)))


# ============================================================ Sea text
def flit(v):
    if math.isnan(v):
        return 'nan'
    if math.isinf(v):
        return 'inf' if v > 0 else '-inf'
    r = repr(v)
    assert float(r) == v
    return r


def vlit(vals):
    return '[' + ', '.join(flit(v) for v in vals) + ']'


def slit(s):
    out = []
    for ch in s.encode('utf-8'):
        if ch == 0x22:
            out.append('\\"')
        elif ch == 0x5c:
            out.append('\\\\')
        elif ch == 0x09:
            out.append('\\t')
        elif ch == 0x0a:
            out.append('\\n')
        elif ch < 0x20 or ch == 0x7f:
            out.append('\\x%02x' % ch)
        else:
            out.append(chr(ch) if ch < 0x80 else None)
    if None in out:
        # a non-ASCII text: copy the UTF-8 characters themselves (the literal holds bytes, 3.5)
        out = []
        for c in s:
            b = c.encode('utf-8')
            if len(b) > 1:
                out.append(c)
            else:
                out.extend(slit_ascii(b[0]))
    return '"' + ''.join(out) + '"'


def slit_ascii(ch):
    if ch == 0x22:
        return ['\\"']
    if ch == 0x5c:
        return ['\\\\']
    if ch == 0x09:
        return ['\\t']
    if ch == 0x0a:
        return ['\\n']
    if ch < 0x20 or ch == 0x7f:
        return ['\\x%02x' % ch]
    return [chr(ch)]


def svg_text(s):
    """What a text of the SVG reads after XML unescaping (L-kp): control bytes but tab, LF, CR as
    spaces."""
    return ''.join(' ' if (ord(c) < 0x20 and c not in '\t\n\r') else c for c in s)


class Vec:
    def __init__(self, expr, vals):
        self.expr, self.vals = expr, list(vals)


class H:
    """A handle value in the program: its expression and the model object it refers to."""
    def __init__(self, expr, fig, rec=None):
        self.expr, self.fig, self.rec = expr, fig, rec


def arg(v):
    if isinstance(v, (Vec, H)):
        return v.expr
    if isinstance(v, list):
        return vlit(v)
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, str):
        return slit(v)
    if isinstance(v, int):
        return str(v)
    return flit(v)


def vals(v):
    return v.vals if isinstance(v, Vec) else list(v)


class Case:
    def __init__(self, name, doc):
        self.name = name
        self.doc = doc
        self.src = []
        self.saves = []      # (path, snapshot, comments)
        self.out = ''

    # --- statements
    def raw(self, text):
        self.src.append(text)

    def printf(self, text):
        self.src.append('printf(%s)' % slit(text))
        self.out += text

    def vec(self, name, values):
        self.src.append('let %s = %s' % (name, vlit(values)))
        return Vec(name, values)

    def empty(self, name):
        self.src.append('let %s: f64[] = []' % name)
        return Vec(name, [])

    def call(self, fn, args, opts, bind=None, stmt=True):
        text = '%s(%s)' % (fn, ', '.join([arg(a) for a in args] + ['%s: %s' % (k, arg(v)) for k, v in opts]))
        if stmt:
            self.src.append(('let %s = %s' % (bind, text)) if bind else text)
        return text

    # --- the calls, applied to the model
    def figure(self, bind, nrows, ncols, **o):
        name = o.get('name', '')
        fig = Fig(nrows, ncols, name, o.get('width', 960), o.get('height', 720))
        self.call('figure', [nrows, ncols], list(o.items()), bind)
        return H(bind, fig)

    def panel(self, bind, fig, row, col, stmt=True, **o):
        rs, cs = o.get('rowspan', 1), o.get('colspan', 1)
        f = fig.fig
        assert 0 <= row and 0 <= col and rs >= 1 and cs >= 1
        assert row + rs <= f.nrows and col + cs <= f.ncols
        cells = {(r, c) for r in range(row, row + rs) for c in range(col, col + cs)}
        assert not (cells & f.cells)
        f.cells |= cells
        f.recs.append(Rec(0, len(f.recs), row, col, rs, cs))
        text = self.call('panel', [fig, row, col], list(o.items()), bind, stmt)
        return H(bind if bind else text, f, len(f.recs) - 1)

    def twin_y(self, bind, ax):
        f = ax.fig
        b = f.recs[f.recs[ax.rec].base]
        if b.twin < 0:
            f.recs.append(Rec(1, f.recs[ax.rec].base, b.row, b.col, b.rs, b.cs))
            b.twin = len(f.recs) - 1
        self.call('twin_y', [ax], [], bind)
        return H(bind, f, b.twin)

    def base(self, ax):
        return ax.fig.recs[ax.fig.recs[ax.rec].base]

    def own(self, ax):
        return ax.fig.recs[ax.rec]

    def plot(self, ax, x, y, **o):
        xv, yv = vals(x), vals(y)
        assert len(xv) == len(yv)
        line, marker, letter = parse_style(o.get('style', '-'), False)
        w = o.get('width', 1.0)
        assert fin(w) and w > 0
        color = check_color(o.get('color', ''))
        c = resolve_color(self.own(ax), color, letter)
        ax.fig.series.append(Series(1, ax.rec, c, line, marker, o.get('label', ''), xv, yv))
        self.call('plot', [ax, x, y], list(o.items()))

    def xline(self, ax, x, **o):
        line, marker, letter = parse_style(o.get('style', '--'), True)
        color = check_color(o.get('color', ''))
        c = resolve_color(self.own(ax), color, letter)
        ax.fig.series.append(Series(2, ax.rec, c, line, 0, '', pos=x))
        self.call('xline', [ax, x], list(o.items()))

    def xlabel(self, ax, s):
        self.base(ax).xlabel = s
        self.call('xlabel', [ax, s], [])

    def ylabel(self, ax, s):
        self.own(ax).ylabel = s
        self.call('ylabel', [ax, s], [])

    def title(self, ax, s):
        self.base(ax).title = s
        self.call('title', [ax, s], [])

    def legend(self, ax, **o):
        loc = o.get('loc', 'northeast')
        self.base(ax).loc = 5 if loc == 'best' else LOCS.index(loc) + 1
        self.call('legend', [ax], list(o.items()))

    def grid(self, ax, **o):
        self.base(ax).grid = o.get('on', True)
        self.call('grid', [ax], list(o.items()))

    def xlim(self, ax, lo, hi):
        assert fin(lo) and fin(hi) and lo < hi
        self.base(ax).xlim = (lo, hi)
        self.call('xlim', [ax, lo, hi], [])

    def ylim(self, ax, lo, hi):
        assert fin(lo) and fin(hi) and lo < hi
        self.own(ax).ylim = (lo, hi)
        self.call('ylim', [ax, lo, hi], [])

    def x_ticks(self, ax, labels, expr=None):
        self.base(ax).xcats = list(labels)
        self.src.append('x_ticks(%s, %s)' % (ax.expr, expr or '[' + ', '.join(slit(s) for s in labels) + ']'))

    def y_ticks(self, ax, labels, expr=None):
        self.own(ax).ycats = list(labels)
        self.src.append('y_ticks(%s, %s)' % (ax.expr, expr or '[' + ', '.join(slit(s) for s in labels) + ']'))

    def y_reverse(self, ax):
        self.own(ax).rev = True
        self.call('y_reverse', [ax], [])

    def axis_equal(self, ax):
        self.base(ax).equal = True
        self.call('axis_equal', [ax], [])

    def save(self, fig, path, comments=(), stmt=True):
        self.saves.append((path, fig.fig.snapshot(), list(comments)))
        if stmt:
            self.call('save_svg', [fig, path], [])

    def write(self):
        head = ['// ' + d for d in self.doc]
        emit('plots/%s.sea' % self.name, '\n'.join(head + self.src) + '\n')
        if self.out:
            emit('plots/%s.out' % self.name, self.out)
        parts = []
        for path, fig, comments in self.saves:
            parts.append(struct_of(fig, path, comments))
        hdr = ('# %s.struct -- derived by tests/vectors/plot9_cases.py from LANGUAGE.md 12 and DESIGN.md 2.14.6\n'
               '# (the model of the calls in %s.sea; DESIGN.md 2.14.8 "The .struct format")\n' % (self.name, self.name))
        emit('plots/%s.struct' % self.name, hdr + ''.join(parts))


# ============================================================ the 9b plot programs (2.14.8)
def plot_minimal():
    p = Case('plot_minimal', [
        'plot_minimal -- a 1 x 1 figure, one 3-point line, default limits and ticks (DESIGN.md 2.14.6 rules 4-5:',
        'x 1 ... 3 with step 0.5, y 2 ... 4 with step 0.5), a title and both labels (LANGUAGE.md 12.2-12.5)'])
    fig = p.figure('fig', 1, 1)
    ax = p.panel('ax', fig, 0, 0)
    p.plot(ax, [1.0, 2.0, 3.0], [2.0, 4.0, 3.0])
    p.title(ax, 'Minimal')
    p.xlabel(ax, 'x [m]')
    p.ylabel(ax, 'y [m]')
    p.save(fig, 'plot_minimal.svg')
    p.printf('saved\n')
    p.write()


def plot_heading():
    p = Case('plot_heading', [
        'plot_heading -- the 24 px heading band with a name holding & < > " (escaped in the file, read back',
        'unescaped), a non-default canvas; a second figure without a name has no heading (LANGUAGE.md 12.2, 12.5, 12.8)'])
    f1 = p.figure('f1', 1, 1, name='Q & A <1> "x"', width=640, height=480)
    a1 = p.panel('a1', f1, 0, 0)
    p.plot(a1, [0.0, 1.0], [0.0, 1.0])
    p.save(f1, 'named.svg')
    f2 = p.figure('f2', 1, 1, width=320, height=240)
    p.panel('a2', f2, 0, 0)
    p.save(f2, 'plain.svg')
    p.write()


def plot_grid_span():
    p = Case('plot_grid_span', [
        'plot_grid_span -- a 2 x 3 grid with row and column spans; the panels are written in creation order',
        '(LANGUAGE.md 12.2; DESIGN.md 2.14.6 item 5), options in either order'])
    fig = p.figure('fig', 2, 3)
    a = p.panel('a', fig, 0, 0, colspan=1, rowspan=2)
    b = p.panel('b', fig, 0, 1, colspan=2)
    c = p.panel('c', fig, 1, 2)
    d = p.panel('d', fig, 1, 1, rowspan=1)
    for h, t in ((a, 'tall'), (b, 'wide'), (c, 'right'), (d, 'middle')):
        p.title(h, t)
    p.plot(b, [0.0, 10.0], [0.0, 20.0])
    p.save(fig, 'plot_grid_span.svg')
    p.write()


def plot_style():
    p = Case('plot_style', [
        'plot_style -- each line part, each marker, each colour letter, the empty style, #RRGGBB upper case written',
        'lower case, `color:` over a style letter (LANGUAGE.md 12.3; L-ki, L-kh); the cycle wraps after seven'])
    fig = p.figure('fig', 1, 1)
    ax = p.panel('ax', fig, 0, 0)
    x = p.vec('x', [0.0, 1.0, 2.0])
    styles = ['-', '--', ':', '-.', 'o', 's', 'd', '^', 'v', 'x', '+', '*', '.',
              'r', 'g-', 'b--', 'c:', 'm-.', 'yo', 'k-s', 'w*']
    for i, st in enumerate(styles):
        p.plot(ax, x, [float(i), float(i) + 1.0, float(i)], style=st)
    p.plot(ax, x, [30.0, 31.0, 30.0], style='')
    p.plot(ax, x, [31.0, 32.0, 31.0], width=2.5, color='#A1B2C3')
    p.plot(ax, x, [32.0, 33.0, 32.0], style='r', color='#00FF00')
    p.plot(ax, x, [33.0, 34.0, 33.0], style='o-')
    p.plot(ax, x, [34.0, 35.0, 34.0], style='--r')
    p.save(fig, 'plot_style.svg')
    p.write()


def plot_cycle():
    p = Case('plot_cycle', [
        'plot_cycle -- eight series without a colour take the cycle #0072bd ... #a2142f and wrap to #0072bd; series',
        'with `color:` or a style letter between them do not advance it (LANGUAGE.md 12.3; L-kh)'])
    fig = p.figure('fig', 1, 1)
    ax = p.panel('ax', fig, 0, 0)
    x = p.vec('x', [0.0, 1.0])
    for i in range(8):
        p.plot(ax, x, [float(i), float(i)])
        if i == 2:
            p.plot(ax, x, [-1.0, -1.0], color='#123456')
        if i == 5:
            p.plot(ax, x, [-2.0, -2.0], style='k:')
    p.save(fig, 'plot_cycle.svg')
    p.write()


def plot_nan():
    p = Case('plot_nan', [
        'plot_nan -- a line broken by NaN and +-Inf in y and in x: one subpath per maximal run of finite points;',
        'markers only at finite points; non-finite values ignored by the limits (LANGUAGE.md 12.3; 2.14.2; L-kj)'])
    fig = p.figure('fig', 1, 1)
    ax = p.panel('ax', fig, 0, 0)
    p.plot(ax, [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0], [1.0, NAN, 2.0, 3.0, INF, 4.0, 5.0, -INF], style='-o')
    p.plot(ax, [NAN, 1.0, 2.0, INF, 4.0], [1.0, 2.0, 3.0, 4.0, 5.0])
    p.plot(ax, [0.0, 1.0], [NAN, NAN], style='-x')
    p.save(fig, 'plot_nan.svg')
    p.write()


def plot_empty():
    p = Case('plot_empty', [
        'plot_empty -- an empty series (it takes a cycle colour, is listed in the legend, draws an empty path), a',
        'panel with nothing (limits 0 ... 1), a figure with no panel (LANGUAGE.md 12.3; 2.14.2 "Empty and non-finite data")'])
    e = p.empty('e')
    f0 = p.figure('f0', 1, 1)
    p.save(f0, 'nopanel.svg')
    fig = p.figure('fig', 1, 2)
    a = p.panel('a', fig, 0, 0)
    p.panel('b', fig, 0, 1)
    p.plot(a, e, e, label='none')
    p.legend(a)
    p.save(fig, 'empty.svg')
    p.write()


def tick_case(name, doc, panels, file_comment):
    """A figure of len(panels) rows of one panel each: each spec (title, x data, y data, xlim, ylim)."""
    p = Case(name, doc)
    fig = p.figure('fig', len(panels), 1, height=240 * len(panels))
    for i, (title, xs, ys, xl, yl) in enumerate(panels):
        ax = p.panel('a%d' % i, fig, i, 0)
        p.title(ax, title)
        if xs is not None:
            p.plot(ax, xs, ys)
        if xl is not None:
            p.xlim(ax, xl[0], xl[1])
        if yl is not None:
            p.ylim(ax, yl[0], yl[1])
    p.save(fig, name + '.svg', file_comment)
    p.write()


def plot_ticks():
    tick_case('plot_ticks_basic', [
        'plot_ticks_basic -- the step rule of DESIGN.md 2.14.6 rule 5 on 0 ... 6, 0.1 ... 0.95 and -3 ... 7, and the',
        'default limits of rule 4 (LANGUAGE.md 12.5); the tick texts from tests/vectors/plot9_cases.py'],
        [('zero to six', [0.0, 6.0], [0.1, 0.95], None, None),
         ('minus three to seven', [-3.0, 7.0], [-0.25, 0.3], None, None),
         ('fractions', [0.5, 2.25], [100.0, 940.0], None, None)],
        ['x 0 ... 6: step 1; y 0.1 ... 0.95: step 0.2, limits 0 ... 1; x -3 ... 7: step 2'])
    tick_case('plot_ticks_zero', [
        'plot_ticks_zero -- zero ranges: at 0 widened to -1 ... 1, at 5 to 4.5 ... 5.5 (v -+ |v|/10), at -40, then',
        'the default step (DESIGN.md 2.14.6 rule 4; LANGUAGE.md 12.5)'],
        [('at zero', [0.0, 0.0], [5.0, 5.0], None, None),
         ('negative', [-40.0, -40.0], [2.0, 2.0], None, None)],
        ['zero ranges by rule 4'])
    tick_case('plot_ticks_wide', [
        'plot_ticks_wide -- 1e6-wide and wider ranges: steps of 1e6 and more are written %g (DESIGN.md 2.14.6',
        '"Tick labels"; LANGUAGE.md 12.5)'],
        [('millions', [0.0, 3.5e6], [-2e7, 1.2e8], None, None),
         ('below a million', [0.0, 3.5e5], [1e9, 1e9], None, None)],
        ['steps >= 1e6 use %g'])
    tick_case('plot_ticks_tiny', [
        'plot_ticks_tiny -- 1e-5-wide ranges: steps below 1e-4 are written %g, 1e-4 itself %.4f (DESIGN.md 2.14.6',
        '"Tick labels")'],
        [('tiny', [0.0, 3e-5], [2e-4, 6e-4], None, None),
         ('offset tiny', [0.5, 0.50004], [-1e-5, 1e-5], None, None)],
        ['steps < 1e-4 use %g'])
    tick_case('plot_ticks_explicit', [
        'plot_ticks_explicit -- explicit limits keep their values and get only the ticks of the step inside them',
        '(DESIGN.md 2.14.6 rules 1 and 5: c0 = ceil(lo / s)); the data outside does not matter (LANGUAGE.md 12.5)'],
        [('explicit', [0.0, 100.0], [0.0, 1.0], (0.3, 2.7), (-0.15, 0.85)),
         ('explicit wide', None, None, (-17.0, 123.0), (0.001, 0.0042))],
        ['xlim/ylim: ticks inside only'])
    tick_case('plot_ticks_narrow', [
        'plot_ticks_narrow -- the narrow range 1 ... 1.00001 whose %g texts would repeat: every tick of that axis is',
        'written %.{q}g with the smallest q of 7 ... 17 that separates adjacent texts (Decision 142 (a); LANGUAGE.md 12.5)'],
        [('narrow', [1.0, 1.00001], [0.0, 1.0], None, None),
         ('narrow explicit', None, None, (1000.0, 1000.0005), (-1.0, 1.0))],
        ['Decision 142 (a)'])


def plot_twin():
    p = Case('plot_twin', [
        'plot_twin -- twin_y: the twin\'s cycle starts at #d95319, its ticks on the right (ytick2) and its ylabel2;',
        'twin_y twice and twin_y of the twin return the same axes; xlabel, title and grid of the twin act on the pair,',
        'ylabel and ylim on its own y-axis; the pair\'s x-axis takes both axes\' data (LANGUAGE.md 12.2-12.4; L-km)'])
    fig = p.figure('fig', 1, 2)
    ax = p.panel('ax', fig, 0, 0)
    p.plot(ax, [0.0, 1.0, 2.0], [0.0, 10.0, 20.0])
    t = p.twin_y('t', ax)
    p.plot(t, [0.0, 4.0], [0.5, 0.75])
    t2 = p.twin_y('t2', ax)
    t3 = p.twin_y('t3', t)
    p.plot(t3, [1.0, 3.0], [0.6, 0.7])
    p.xlabel(t, 'time [s]')
    p.title(t2, 'pair')
    p.ylabel(ax, 'left')
    p.ylabel(t3, 'right')
    p.grid(t)
    b = p.panel('b', fig, 0, 1)
    p.plot(b, [0.0, 1.0], [0.0, 1.0])
    tb = p.twin_y('tb', b)
    p.ylim(tb, 0.25, 0.75)
    p.ylabel(tb, 'limited')
    p.save(fig, 'plot_twin.svg')
    p.write()


def plot_legend():
    p = Case('plot_legend_loc', [
        'plot_legend_loc -- each legend location and best (northeast); the box lists the labelled series in call',
        'order, unlabelled ones not (LANGUAGE.md 12.4, 12.5; L-kn)'])
    fig = p.figure('fig', 3, 3)
    for i, loc in enumerate(LOCS + ['best']):
        ax = p.panel('a%d' % i, fig, i // 3, i % 3)
        p.plot(ax, [0.0, 1.0], [0.0, 1.0], label=loc)
        p.plot(ax, [0.0, 1.0], [1.0, 0.0])
        p.legend(ax, loc=loc)
    p.save(fig, 'plot_legend_loc.svg')
    p.write()

    p = Case('plot_legend_pair', [
        'plot_legend_pair -- a legend set before its series lists the labelled line series of both axes of a pair in',
        'call order (markers and lines sampled); a legend without labelled series and labelled series without a',
        'legend draw no box; the last location set is kept (LANGUAGE.md 12.4; L-kn, L-kg)'])
    fig = p.figure('fig', 1, 3)
    a = p.panel('a', fig, 0, 0)
    p.legend(a, loc='southwest')
    p.plot(a, [0.0, 1.0], [0.0, 1.0], label='first')
    t = p.twin_y('t', a)
    p.plot(t, [0.0, 1.0], [5.0, 6.0], style='o', label='second')
    p.plot(a, [0.0, 1.0], [1.0, 0.0])
    p.plot(a, [0.0, 1.0], [0.5, 0.5], style='-s', label='third')
    p.xline(a, 0.5)
    p.legend(t, loc='north')
    b = p.panel('b', fig, 0, 1)
    p.plot(b, [0.0, 1.0], [0.0, 1.0])
    p.legend(b)
    c = p.panel('c', fig, 0, 2)
    p.plot(c, [0.0, 1.0], [0.0, 1.0], label='unshown')
    p.save(fig, 'plot_legend_pair.svg')
    p.write()


def plot_category():
    p = Case('plot_category', [
        'plot_category -- category labels at 0 ... n - 1: x_ticks with no data (limits -0.5 ... n - 0.5), y_ticks with',
        'data beyond them (the limits widened, every label kept); an empty list returns to numeric ticks',
        '(LANGUAGE.md 12.4; DESIGN.md 2.14.6 rule 2)'])
    p.raw('let none: str[] = []')
    fig = p.figure('fig', 1, 3)
    a = p.panel('a', fig, 0, 0)
    p.x_ticks(a, ['low', 'mid', 'high'])
    b = p.panel('b', fig, 0, 1)
    p.plot(b, [0.0, 1.0], [-1.0, 4.0])
    p.y_ticks(b, ['A & B', 'C'])
    c = p.panel('c', fig, 0, 2)
    p.plot(c, [0.0, 4.0], [0.0, 1.0])
    p.x_ticks(c, ['p', 'q'])
    p.x_ticks(c, [], expr='none')
    p.save(fig, 'plot_category.svg')
    p.write()


def plot_category_limits():
    p = Case('plot_category_limits', [
        'plot_category_limits -- the limits rules in numbered order (DESIGN.md 2.14.6, the lead\'s reading): explicit',
        'limits (rule 1) give numeric step ticks although category labels are set, category ticks arise only',
        'under rule 2; axis_equal (rule 6) recomputes the changed axis with numeric explicit-limit ticks, a',
        'category axis included (LANGUAGE.md 12.4, 12.5)'])
    fig = p.figure('fig', 1, 2)
    a = p.panel('a', fig, 0, 0)
    p.plot(a, [0.0, 4.0], [0.0, 1.0])
    p.x_ticks(a, ['p', 'q', 'r'])
    p.xlim(a, 0.5, 2.5)
    b = p.panel('b', fig, 0, 1)
    p.plot(b, [0.0, 2.0], [0.0, 10.0])
    p.x_ticks(b, ['u', 'v', 'w'])
    p.axis_equal(b)
    p.save(fig, 'plot_category_limits.svg',
           ['a: xlim 0.5 ... 2.5 over the labels p q r: rule 1, numeric ticks 0.5 ... 2.5 step 0.5',
            'b: labels u v w give x -0.5 ... 2.5 (rule 2), y 0 ... 10; pw 408, ph 648: ux = 3/408 < uy = 10/648,',
            'so x widens about 1 to 1 -+ (10/648)*408/2 = -2.148 ... 4.148 with numeric ticks (rule 6)'])
    p.write()


def plot_cvt_order():
    p = Case('plot_cvt_order', [
        'plot_cvt_order -- i64 arrays for f64[] parameters in plotting calls whose options are given out of',
        'order: the fixed-size i64[3] x and the dynamic i64[] y are converted element by element (LANGUAGE.md',
        '4.2 (c)) and bound in source order with the other arguments (L-cp); before 9b such a reordered call',
        'with a converted array argument crashed sealoop ("bad record", seacheck\'s cty; a pre-existing defect',
        'fixed in 9b, the user-function form is programs/call6_named_cvt_*)'])
    p.raw('let k: i64[3] = [1, 2, 3]')
    p.raw('let m: i64[] = [3, 1, 2]')
    kx = Vec('k', [1.0, 2.0, 3.0])
    my = Vec('m', [3.0, 1.0, 2.0])
    fig = p.figure('fig', 1, 1, height=600, width=800)
    a = p.panel('a', fig, 0, 0)
    p.plot(a, kx, [2.0, 4.0, 5.0], color='#102030', width=2.0, label='fixed', style='o-')
    p.plot(a, [0.5, 1.5, 2.5], my, label='dyn', style='--')
    p.legend(a, loc='south')
    p.save(fig, 'plot_cvt_order.svg',
           ['x data 0.5 ... 3 (step 0.5), y data 1 ... 5 (step 1); the second line takes the first cycle',
            'colour, #0072bd, since the first gave color:'])
    p.write()


def plot_reverse():
    p = Case('plot_reverse', [
        'plot_reverse -- y_reverse turns the axis downward and keeps its ticks and texts; on a twin it acts on the',
        'twin\'s y-axis only; set twice it stays on (LANGUAGE.md 12.4; L-km)'])
    fig = p.figure('fig', 1, 2)
    a = p.panel('a', fig, 0, 0)
    p.plot(a, [0.0, 1.0, 2.0], [3.0, 1.0, 2.0])
    p.y_reverse(a)
    p.y_reverse(a)
    b = p.panel('b', fig, 0, 1)
    p.plot(b, [0.0, 1.0], [0.0, 1.0])
    t = p.twin_y('t', b)
    p.plot(t, [0.0, 1.0], [10.0, 30.0])
    p.y_reverse(t)
    p.save(fig, 'plot_reverse.svg')
    p.write()


def plot_equal():
    p = Case('plot_equal', [
        'plot_equal -- axis_equal on a wide and on a tall panel: the axis with the smaller unit is widened about its',
        'centre and its ticks recomputed as explicit-limit ticks (DESIGN.md 2.14.6 rule 6 with the layout of 2.14.6)'])
    fig = p.figure('wide', 1, 1, width=800, height=400)
    a = p.panel('a', fig, 0, 0)
    p.plot(a, [0.0, 1.0], [0.0, 1.0])
    p.axis_equal(a)
    p.save(fig, 'wide.svg', ['pw 728, ph 328: the x limits widen'])
    fig2 = p.figure('tall', 1, 1, width=400, height=800)
    b = p.panel('b', fig2, 0, 0)
    p.plot(b, [0.0, 2.0], [0.0, 1.0])
    p.axis_equal(b)
    p.save(fig2, 'tall.svg', ['pw 328, ph 728: the y limits widen'])
    p.write()


def plot_xline():
    p = Case('plot_xline', [
        'plot_xline -- reference lines are not data for the limits; their colours follow the series rule (cycle,',
        'letter, color:); a NaN position draws an empty path (LANGUAGE.md 12.3, 12.4; L-kh, L-kj)'])
    fig = p.figure('fig', 1, 1)
    ax = p.panel('ax', fig, 0, 0)
    p.plot(ax, [0.0, 1.0], [0.0, 2.0])
    p.xline(ax, 5.0)
    p.xline(ax, NAN, style='r:')
    p.xline(ax, 0.5, style='-', color='#ABCDEF')
    p.xline(ax, -INF)
    p.save(fig, 'plot_xline.svg')
    p.write()


def plot_handles():
    p = Case('plot_handles', [
        'plot_handles -- handles in a struct field, passed and returned; every Axes value is dropped (decorate\'s',
        'locals) before save_svg and the drawing stays (L-ke); a figure kept alive by an Axes value only; the heap',
        'check finds no live object (LANGUAGE.md 4.1, 12.1; DESIGN.md 2.14.8 "The heap check with handles")'])
    # the model: the same calls in the order the program makes them (decorate's body, then main);
    # `m` only drives the model, its statements are replaced by the program text below
    m = Case('model', [])
    fig = m.figure('fig', 1, 2, name='handles')
    a0 = m.panel(None, fig, 0, 0, stmt=False)
    m.plot(a0, [0.0, 1.0], [1.0, 2.0])
    s_ax = m.panel('s', fig, 0, 1)
    m.plot(s_ax, [0.0, 1.0], [3.0, 4.0])
    m.title(s_ax, 'kept')
    orphan = m.figure('f', 1, 1, name='orphan')
    o = m.panel('o', orphan, 0, 0)
    m.plot(o, [0.0, 1.0], [0.0, 1.0])
    p.raw('struct Slot {\n    ax: Axes\n    k: i64\n}')
    p.raw('fn draw(a: Axes, y: f64[]) -> Axes {\n    plot(a, [0.0, 1.0], y)\n    return a\n}')
    p.raw('fn lone() -> Axes {\n    let f = figure(1, 1, name: "orphan")\n    return panel(f, 0, 0)\n}')
    p.raw('fn decorate(fig: Figure) {\n'
          '    plot(panel(fig, 0, 0), [0.0, 1.0], [1.0, 2.0])\n'
          '    let s = Slot { ax: panel(fig, 0, 1), k: 1 }\n'
          '    let a2 = draw(s.ax, [3.0, 4.0])\n'
          '    title(a2, "kept")\n'
          '}')
    p.raw('let fig = figure(1, 2, name: "handles")')
    p.raw('decorate(fig)')
    p.raw('let o = lone()')
    p.raw('plot(o, [0.0, 1.0], [0.0, 1.0])')
    p.save(fig, 'plot_handles.svg', stmt=False)
    p.raw('save_svg(fig, "plot_handles.svg")')
    p.write()


def plot_save_twice():
    p = Case('plot_save_twice', [
        'plot_save_twice -- save_svg draws the state at that moment: the second file has the later series and title;',
        'a file in a directory made by make_dir (LANGUAGE.md 12.2, 2.14.2 "When things happen"; L-kg, L-la)'])
    fig = p.figure('fig', 1, 1)
    ax = p.panel('ax', fig, 0, 0)
    p.plot(ax, [0.0, 1.0], [0.0, 1.0])
    p.save(fig, 'first.svg')
    p.plot(ax, [0.0, 2.0], [1.0, 3.0])
    p.title(ax, 'later')
    p.raw('make_dir("out")')
    p.save(fig, 'out/second.svg')
    p.write()


def plot_text():
    p = Case('plot_text', [
        'plot_text -- text escaping: & < > " escaped, control bytes other than tab written as spaces, UTF-8 copied,',
        'in a title, the labels, a legend label and category labels (LANGUAGE.md 12.7, 12.8; L-kp)'])
    fig = p.figure('fig', 1, 1, name='a\x01b')
    ax = p.panel('ax', fig, 0, 0)
    p.title(ax, 'T\x00x\x1fy\tz')
    p.xlabel(ax, '<x> & "y"')
    p.ylabel(ax, 'temp µm')
    p.plot(ax, [0.0, 1.0], [0.0, 1.0], label='l\x07m')
    p.legend(ax)
    p.y_ticks(ax, ['\x02a', 'b'])
    p.save(fig, 'plot_text.svg')
    p.write()


def plot_extreme():
    p = Case('plot_extreme', [
        'plot_extreme -- data and explicit limits near +-1.7e308: an axis that admits no step has no ticks; NaN, +-Inf',
        'and huge coordinates are clamped (no number overflows the file); a zero range at 1.7e308 widens to v +- 1,',
        'which rounds to v, and so takes 0 ... 1 (DESIGN.md 2.14.6 rules 4-5, "Mapping"; L-kk, L-kl)'])
    fig = p.figure('fig', 3, 1)
    a = p.panel('a', fig, 0, 0)
    p.plot(a, [-1.7e308, 1.7e308], [0.0, 1.0], style='-o')
    b = p.panel('b', fig, 1, 0)
    p.plot(b, [0.0, 1.0, 2.0], [NAN, INF, -INF], style='-+')
    p.xlim(b, -1.7e308, 1.7e308)
    c = p.panel('c', fig, 2, 0)
    p.plot(c, [1.7e308, 1.7e308], [1.7e308, -1.7e308], style='s')
    p.save(fig, 'plot_extreme.svg')
    p.write()


# ============================================================ errors (2.14.8 "Errors")
def err_file(name, doc, code, marker, msg, out='', run_time=True, mline=None):
    head = ['// ' + d for d in doc]
    lines = code.rstrip('\n').split('\n')
    src = '\n'.join(head + lines) + '\n'
    if mline is None:
        hits = [i for i, l in enumerate(lines) if marker in l]
        assert len(hits) >= 1, (name, marker)
        li = hits[0]
    else:
        li = mline
    lno = len(head) + li + 1
    emit('errors/%s.sea' % name, src)
    if run_time:
        emit('errors/%s.err' % name, '%s.sea:%d: error: %s\n' % (name, lno, msg))
        emit('errors/%s.out' % name, out)
        emit('errors/%s.status' % name, '%d\n' % EXIT_RUN_ERROR)
    else:
        col = lines[li].index(marker) + 1
        emit('errors/%s.err' % name, '%s.sea:%d:%d: error: %s\n' % (name, lno, col, msg))
        emit('errors/%s.status' % name, '%d\n' % EXIT_COMPILE)


def r(name, doc, code, marker, msg):
    err_file(name, doc, 'printf("start\\n")\n' + code, marker, msg, out='start\n')


def errors():
    ax2 = 'let fig = figure(2, 2)\nlet ax = panel(fig, 0, 0)\n'
    r('r_plot_grid', ['r_plot_grid -- figure with nrows 0: invalid figure grid 0x2 (LANGUAGE.md 12.2, 9.2; FIGURE_GRID, 2.14.2)'],
      'let fig = figure(0, 2)\nprintf("never\\n")\n', 'figure(0', 'invalid figure grid 0x2')
    g = LIM_GRID + 1
    r('r_plot_grid_big', ['r_plot_grid_big -- figure with ncols %d > SEA_LIM_PLOT_GRID: invalid figure grid 2x%d (LANGUAGE.md 12.2)' % (g, g)],
      'let fig = figure(2, %d)\n' % g, 'figure(', 'invalid figure grid 2x%d' % g)
    r('r_plot_size', ['r_plot_size -- figure with width 0: invalid figure size 0x720 (LANGUAGE.md 12.2; FIGURE_SIZE)'],
      'let fig = figure(1, 1, width: 0)\n', 'figure(', 'invalid figure size 0x720')
    px = LIM_PX + 1
    r('r_plot_size_big', ['r_plot_size_big -- height %d > SEA_LIM_PLOT_PX: invalid figure size 960x%d (LANGUAGE.md 12.2)' % (px, px)],
      'let fig = figure(1, 1, height: %d)\n' % px, 'figure(', 'invalid figure size 960x%d' % px)
    cells = [('row', 'panel(fig, -1, 0)', 'panel at -1,0 spanning 1x1 is outside the 2x3 grid', 'row < 0'),
             ('col', 'panel(fig, 1, -2)', 'panel at 1,-2 spanning 1x1 is outside the 2x3 grid', 'col < 0'),
             ('rowspan', 'panel(fig, 0, 0, rowspan: 0)', 'panel at 0,0 spanning 0x1 is outside the 2x3 grid', 'rowspan < 1'),
             ('colspan', 'panel(fig, 0, 0, colspan: -1)', 'panel at 0,0 spanning 1x-1 is outside the 2x3 grid', 'colspan < 1'),
             ('rowend', 'panel(fig, 1, 0, rowspan: 2)', 'panel at 1,0 spanning 2x1 is outside the 2x3 grid', 'row + rowspan > nrows'),
             ('colend', 'panel(fig, 0, 1, colspan: 3)', 'panel at 0,1 spanning 1x3 is outside the 2x3 grid', 'col + colspan > ncols')]
    for suf, call, msg, cond in cells:
        r('r_plot_cell_' + suf, ['r_plot_cell_%s -- %s: PANEL_CELL with the slots row, col, rowspan, colspan, nrows, ncols' % (suf, cond),
                                 '(LANGUAGE.md 12.2; DESIGN.md 2.14.2)'],
          'let fig = figure(2, 3)\nlet ok = panel(fig, 1, 1)\nlet ax = %s\n' % call, 'let ax', msg)
    r('r_plot_taken', ['r_plot_taken -- a span over two earlier panels reports the first taken cell with rows ascending, then',
                       'columns: 1,2 (column order would give 2,0) (LANGUAGE.md 12.2; Decision 133 (b))'],
      'let fig = figure(3, 3)\nlet p = panel(fig, 1, 2)\nlet q = panel(fig, 2, 0)\nlet ax = panel(fig, 1, 0, rowspan: 2, colspan: 3)\n',
      'let ax', 'grid cell 1,2 already holds a panel')
    r('r_plot_limits', ['r_plot_limits -- xlim(ax, 1, 1): lo must be below hi (LANGUAGE.md 12.4; AXIS_LIMITS)'],
      ax2 + 'xlim(ax, 1, 1)\n', 'xlim', 'invalid axis limits 1, 1')
    r('r_plot_limits_nan', ['r_plot_limits_nan -- ylim with a NaN low limit: %g writes NaN (LANGUAGE.md 12.4, 9.2)'],
      ax2 + 'ylim(ax, nan, 1)\n', 'ylim', 'invalid axis limits NaN, 1')
    r('r_plot_limits_inf', ['r_plot_limits_inf -- xlim(ax, -inf, 0): limits must be finite (LANGUAGE.md 12.4)'],
      ax2 + 'xlim(ax, -inf, 0)\n', 'xlim', 'invalid axis limits -Inf, 0')
    r('r_plot_limits_order', ['r_plot_limits_order -- ylim(ax, 2, 1.5): lo above hi (LANGUAGE.md 12.4)'],
      ax2 + 'ylim(ax, 2, 1.5)\n', 'ylim', 'invalid axis limits 2, 1.5')
    r('r_plot_legend', ['r_plot_legend -- legend(ax, loc: "middle"): not a compass name or best (LANGUAGE.md 12.4; LEGEND_LOC)'],
      ax2 + 'legend(ax, loc: "middle")\n', 'legend', 'invalid legend location "middle"')
    xy = 'let x = [0.0, 1.0]\nlet y = [2.0, 3.0]\n'
    r('r_plot_width', ['r_plot_width -- plot with width 0: invalid width 0 (LANGUAGE.md 12.3; PLOT_WIDTH; bar\'s case is 9c\'s)'],
      ax2 + xy + 'plot(ax, x, y, width: 0)\n', 'plot(', 'invalid width 0')
    r('r_plot_width_nan', ['r_plot_width_nan -- plot with a NaN width (LANGUAGE.md 12.3; PLOT_WIDTH)'],
      ax2 + xy + 'plot(ax, x, y, width: nan)\n', 'plot(', 'invalid width NaN')
    r('r_plot_width_inf', ['r_plot_width_inf -- plot with an infinite width (LANGUAGE.md 12.3; PLOT_WIDTH: not finite)'],
      ax2 + xy + 'plot(ax, x, y, width: inf)\n', 'plot(', 'invalid width Inf')
    r('r_plot_style', ['r_plot_style -- an unknown letter in a style: the whole string (LANGUAGE.md 12.3; LINE_STYLE)'],
      ax2 + xy + 'plot(ax, x, y, style: "-q")\n', 'plot(', 'invalid line style "-q"')
    r('r_plot_style_two', ['r_plot_style_two -- two markers in a style (LANGUAGE.md 12.3: at most one marker; L-ki)'],
      ax2 + xy + 'plot(ax, x, y, style: "os")\n', 'plot(', 'invalid line style "os"')
    r('r_plot_style_lines', ['r_plot_style_lines -- two line parts ("-" then ":") in a style (LANGUAGE.md 12.3; L-ki)'],
      ax2 + xy + 'plot(ax, x, y, style: "-:")\n', 'plot(', 'invalid line style "-:"')
    r('r_plot_style_letters', ['r_plot_style_letters -- two colour letters in a style (LANGUAGE.md 12.3; L-ki)'],
      ax2 + xy + 'plot(ax, x, y, style: "rg")\n', 'plot(', 'invalid line style "rg"')
    r('r_plot_style_xline', ['r_plot_style_xline -- a marker in xline\'s style (LANGUAGE.md 12.3: xline takes no marker; L-ki)'],
      ax2 + 'xline(ax, 1.0, style: "--o")\n', 'xline', 'invalid line style "--o"')
    r('r_plot_color', ['r_plot_color -- color "#12345": five hex digits (LANGUAGE.md 12.3; COLOR)'],
      ax2 + xy + 'plot(ax, x, y, color: "#12345")\n', 'plot(', 'invalid color "#12345"')
    r('r_plot_color_name', ['r_plot_color_name -- color "red": a name is not a colour (LANGUAGE.md 12.3; COLOR)'],
      ax2 + 'xline(ax, 0.5, color: "red")\n', 'xline', 'invalid color "red"')
    r('r_plot_shape', ['r_plot_shape -- plot of a 5-vector against a 4-vector: the two shapes in argument order (LANGUAGE.md 12.3; SHAPE_MISMATCH)'],
      ax2 + 'let x = zeros(5)\nlet y = zeros(4)\nplot(ax, x, y)\n', 'plot(', 'shape mismatch: 5 vs 4')
    r('r_plot_open', ['r_plot_open -- save_svg into a missing directory creates none (LANGUAGE.md 12.2, 9.2; CANNOT_OPEN)'],
      ax2 + 'save_svg(fig, "missing/a.svg")\n', 'save_svg', "cannot open 'missing/a.svg': No such file or directory")
    # check order (L-kg): one test per entry whose checks can both fail
    r('r_plot_order_plot', ['r_plot_order_plot -- plot with a length mismatch and a bad style reports the shape (parameter order, L-kg)'],
      ax2 + 'plot(ax, zeros(3), zeros(2), style: "?")\n', 'plot(', 'shape mismatch: 3 vs 2')
    r('r_plot_order_style', ['r_plot_order_style -- plot with a bad style, width and colour reports the style (L-kg)'],
      ax2 + xy + 'plot(ax, x, y, color: "#zz0000", width: -1, style: "?")\n', 'plot(', 'invalid line style "?"')
    r('r_plot_order_width', ['r_plot_order_width -- plot with a bad width and colour reports the width (L-kg)'],
      ax2 + xy + 'plot(ax, x, y, color: "#zz0000", width: -1)\n', 'plot(', 'invalid width -1')
    r('r_plot_order_xline', ['r_plot_order_xline -- xline with a bad style and colour reports the style (L-kg)'],
      ax2 + 'xline(ax, 0.0, color: "x", style: "o")\n', 'xline', 'invalid line style "o"')
    r('r_plot_order_figure', ['r_plot_order_figure -- figure with a bad grid and size reports the grid (L-kg)'],
      'let fig = figure(%d, 1, width: 0)\n' % g, 'figure(', 'invalid figure grid %dx1' % g)
    r('r_plot_order_panel', ['r_plot_order_panel -- panel outside the grid and over an earlier panel reports PANEL_CELL (L-kg)'],
      'let fig = figure(1, 2)\nlet a = panel(fig, 0, 0)\nlet b = panel(fig, 0, 0, colspan: 3)\n', 'let b',
      'panel at 0,0 spanning 1x3 is outside the 1x2 grid')

    # compile time (2.14.4, the errors made reachable by L-kx)
    pre = 'let fig = figure(1, 1)\nlet ax = panel(fig, 0, 0)\nlet x = zeros(3)\nlet y = zeros(3)\n'

    def c(name, doc, code, marker, msg):
        err_file(name, doc, code, marker, msg, run_time=False)
    c('err_plot_args', ['err_plot_args -- plot with a matrix y: 243 at the call (DESIGN.md 2.14.2 "Signatures", 2.14.4)'],
      pre + 'let M = ones(2, 2)\nplot(ax, x, M)\n', 'plot(ax, x, M', "no overload of 'plot' accepts (Axes, f64[], f64[,])")
    c('err_plot_option_positional', ['err_plot_option_positional -- an option given positionally: one argument more, 243 (L-kg)'],
      pre + 'plot(ax, x, y, "-o")\n', 'plot(', "no overload of 'plot' accepts (Axes, f64[], f64[], str)")
    c('err_plot_unknown_option', ['err_plot_unknown_option -- a name plot does not take: 224 at the narg (DESIGN.md 2.14.4)'],
      pre + 'plot(ax, x, y, size: 2.0)\n', 'size:', 'unknown parameter')
    c('err_plot_twice', ['err_plot_twice -- an option given twice: 225 at the second narg (DESIGN.md 2.14.4)'],
      pre + 'plot(ax, x, y, style: "-", label: "a", style: "o")\n', 'style: "o"', 'parameter given twice')
    c('err_plot_missing', ['err_plot_missing -- a missing positional argument: 243 (DESIGN.md 2.14.4: plot(ax, x))'],
      pre + 'plot(ax, x)\n', 'plot(', "no overload of 'plot' accepts (Axes, f64[])")
    c('err_plot_kind', ['err_plot_kind -- a Figure where Axes is taken: 243 (DESIGN.md 2.14.4: handle parameters take exactly their type)'],
      pre + 'plot(fig, x, y)\n', 'plot(', "no overload of 'plot' accepts (Figure, f64[], f64[])")
    c('err_plot_ref', ['err_plot_ref -- a ref argument: 255 naming the parameter x (DESIGN.md 2.14.2; L-jm)'],
      'let fig = figure(1, 1)\nlet ax = panel(fig, 0, 0)\nvar v = zeros(3)\nplot(ax, ref v, v)\n', 'ref v', "'x' is not a ref parameter")
    c('err_plot_array', ['err_plot_array -- an array of Axes: 258 at the element type (LANGUAGE.md 4.1; DESIGN.md 2.14.4)'],
      'fn nax(v: Axes[]) -> i64 {\n    return len(v)\n}\n', 'Axes[]', 'arrays cannot hold Axes')
    c('err_plot_eq', ['err_plot_eq -- handles cannot be compared: 240 at the left operand (LANGUAGE.md 4.1)'],
      'let f = figure(1, 1)\nlet g = f\nlet same = f == g\n', 'f == g', "operator '==' cannot be applied to Figure and Figure")
    c('err_plot_printf', ['err_plot_printf -- an Axes formatted by printf: 210 at the argument (LANGUAGE.md 11.1)'],
      'let fig = figure(1, 1)\nlet ax = panel(fig, 0, 0)\nprintf("%g\\n", ax)\n', 'ax)', 'format "%g" expects an integer or f64, found Axes')
    c('err_plot_json', ['err_plot_json -- write_json of a Figure: 243 at the call (LANGUAGE.md 11.4)'],
      'let fig = figure(1, 1)\nwrite_json("f.json", fig)\n', 'write_json', "no overload of 'write_json' accepts (str, Figure)")
    c('err_plot_elemental', ['err_plot_elemental -- a plotting call has effects: 228 inside an elemental function, at the call (L-dj)'],
      'elemental fn mark(x: f64) -> f64 {\n    let fig = figure(1, 1)\n    return x\n}\n', 'figure(', 'effects in elemental function')


# ============================================================ driver
def generate():
    plot_minimal()
    plot_heading()
    plot_grid_span()
    plot_style()
    plot_cycle()
    plot_nan()
    plot_empty()
    plot_ticks()
    plot_twin()
    plot_legend()
    plot_category()
    plot_category_limits()
    plot_cvt_order()
    plot_reverse()
    plot_equal()
    plot_xline()
    plot_handles()
    plot_save_twice()
    plot_text()
    plot_extreme()
    errors()


def main(argv):
    out = TESTS_DEFAULT
    check = False
    while argv:
        if argv[0] == '--check':
            check = True
            argv = argv[1:]
        elif argv[0] == '--out' and len(argv) >= 2:
            out = argv[1]
            argv = argv[2:]
        else:
            print('usage: plot9_cases.py [--out TESTS_DIR] [--check]', file=sys.stderr)
            return 2
    generate()
    if check:
        bad = 0
        for rel, data in OUT.items():
            p = os.path.join(out, rel)
            try:
                with open(p, 'rb') as f:
                    have = f.read()
            except OSError:
                print('missing: %s' % rel)
                bad += 1
                continue
            if have != data:
                print('differs: %s' % rel)
                bad += 1
        for rel in RETIRED:
            if os.path.exists(os.path.join(out, rel)):
                print('retired file present: %s' % rel)
                bad += 1
        if bad:
            return 1
        print('plot9_cases: %d files ok' % len(OUT))
        return 0
    for rel, data in OUT.items():
        p = os.path.join(out, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, 'wb') as f:
            f.write(data)
    removed = 0
    for rel in RETIRED:
        p = os.path.join(out, rel)
        if os.path.exists(p):
            os.remove(p)
            removed += 1
    nplots = len([r for r in OUT if r.startswith('plots/') and r.endswith('.sea')])
    nerr = len([r for r in OUT if r.startswith('errors/') and r.endswith('.sea')])
    print('plot9_cases: wrote %d files (%d plot programs, %d errors); removed %d retired files'
          % (len(OUT), nplots, nerr, removed))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
