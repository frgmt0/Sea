"""tests/plot_struct.py -- the structural check of a plot test's SVG files (docs/DESIGN.md 2.14.8,
"The `.struct` format" and "The runner"; Decision 137 (a)). Python standard library only.

usage: timeout 120 uv run --no-project python tests/plot_struct.py STRUCT RUNDIR

STRUCT is a `.struct` file (tests/plots/NAME.struct, ports/NAME.struct), RUNDIR the run directory
its `file` paths are relative to. The file is a list of lines; leading blanks are ignored, and so
are empty lines and lines whose first non-blank byte is `#`. Every other line is `KEY VALUE` (one
space; VALUE the rest of the line, possibly empty) or `KEY~ REGEX` (a Python `re.fullmatch`
pattern; the `~` follows the key with no space). The keys and what each checks:

  file PATH        starts the checks of one SVG file: it must exist, begin with the XML
                   declaration line `<?xml version="1.0" encoding="UTF-8"?>` (2.14.6, line 1), parse
                   as XML (ElementTree, the well-formedness oracle) with the root element
                   {http://www.w3.org/2000/svg}svg carrying class="sea-figure"
  canvas W H       the root's width and height attributes
  heading T        the text of the one `text` element of class heading; `-`: there is none
  panels N         the number of `g` elements of class panel
  panel K          starts the checks of the K-th panel (0-based, document order)
  title T, xlabel T, ylabel T, ylabel2 T
                   the text of the panel's one element of that class; `-`: there is none
  count CLASS N    the number of elements of class CLASS inside the panel
  subpaths I N     the `d` of the panel's I-th element of class line has N `M` commands
  xtick T, ytick T, ytick2 T, ctick T, legend T
                   repeated: the list of the panel's texts of that class (legend: legend-label),
                   all of them in document order, must equal the list of these lines exactly
  color CLASS I C  the stroke (line, xline, markers, contour-level) or fill (bars) of the panel's
                   I-th element of class CLASS is C

Elements are matched by their local name in the SVG namespace and by a class token. Texts are
compared after XML unescaping (ElementTree's), byte for byte. A `~` line matches the text with
re.fullmatch instead. `~` is allowed on every key (2.14.8's grammar); on a key whose value has
selector fields the selectors stay literal and the regex is the last field:
  file~ RX         the one file of RUNDIR (relative path, `/`-separated, any depth) that RX matches;
                   none or several is a FAIL
  panel~ RX        the one panel whose decimal index RX matches; none or several is a FAIL
  canvas~ RX       RX matches "W H" of the root; panels~ RX matches the decimal panel count
  count~ CLASS RX  RX matches the decimal count of CLASS; subpaths~ I RX the decimal M count;
  color~ CLASS I RX  RX matches the stroke or fill
  the text keys    RX matches the text (`-` is then an ordinary pattern, not "none")
A panel key before any `panel` of the current file, a `panel` before any `file`, an unknown key, a
malformed value (a count that is not a decimal number, a colour class other than the five above, a
regex that does not compile) or a `.struct` without a `file` line is a setup error.

Output: `PASS` and exit 0; `FAIL: STRUCT:LINE: <the first difference>` and exit 1; a setup error is
`plot_struct.py: <reason>` on standard error and exit 2.
"""

import os
import re
import sys
import xml.etree.ElementTree as ET

NS = 'http://www.w3.org/2000/svg'
SVG = '{%s}' % NS
XML_DECL = b'<?xml version="1.0" encoding="UTF-8"?>\n'

FILE_KEYS = ('canvas', 'heading', 'panels')
TEXT1_KEYS = ('title', 'xlabel', 'ylabel', 'ylabel2')
LIST_KEYS = {'xtick': 'xtick', 'ytick': 'ytick', 'ytick2': 'ytick2', 'ctick': 'ctick',
             'legend': 'legend-label'}
PANEL_KEYS = TEXT1_KEYS + tuple(LIST_KEYS) + ('count', 'subpaths', 'color')
COLOR_ATTR = {'line': 'stroke', 'xline': 'stroke', 'markers': 'stroke', 'contour-level': 'stroke',
              'bars': 'fill'}
KEY_RE = re.compile(r'[a-z][a-z0-9]*~?')
NUM_RE = re.compile(r'[0-9]+')
CLASS_RE = re.compile(r'[A-Za-z0-9_-]+')


class Setup(Exception):
    """A malformed .struct file (exit 2)."""


class Fail(Exception):
    """A check that does not hold (exit 1)."""


def has_class(el, cls):
    return cls in (el.get('class') or '').split()


def local(el):
    """The local name of an element of the SVG namespace, None for any other element."""
    tag = el.tag
    if isinstance(tag, str) and tag.startswith(SVG):
        return tag[len(SVG):]
    return None


def text_of(el):
    return ''.join(el.itertext())


def of_class(root, cls, name=None, self_too=False):
    """Descendants of root (document order) of class cls, and of local name `name` if given."""
    out = []
    for el in root.iter():
        if el is root and not self_too:
            continue
        if local(el) is None:
            continue
        if name is not None and local(el) != name:
            continue
        if has_class(el, cls):
            out.append(el)
    return out


def parse_struct(path):
    """[(lineno, key, regex?, value)] of the meaningful lines; raises Setup."""
    try:
        with open(path, 'rb') as f:
            raw = f.read()
    except OSError as e:
        raise Setup('cannot read %s: %s' % (path, e.strerror))
    try:
        text = raw.decode('utf-8')
    except UnicodeDecodeError:
        raise Setup('%s is not UTF-8' % path)
    lines = text.split('\n')
    if lines and lines[-1] == '':
        lines.pop()
    out = []
    for i, line in enumerate(lines, 1):
        if line.endswith('\r'):
            raise Setup('%s:%d: carriage return in a line' % (path, i))
        s = line.lstrip(' \t')
        if s == '' or s.startswith('#'):
            continue
        sp = s.find(' ')
        if sp < 0:
            key, value = s, None
        else:
            key, value = s[:sp], s[sp + 1:]
        if not KEY_RE.fullmatch(key):
            raise Setup('%s:%d: malformed line %r' % (path, i, line))
        rx = key.endswith('~')
        if rx:
            key = key[:-1]
        if key not in ('file', 'panel') + FILE_KEYS + PANEL_KEYS:
            raise Setup('%s:%d: unknown key %r' % (path, i, key))
        if value is None:
            raise Setup('%s:%d: malformed line %r (no value)' % (path, i, line))
        out.append((i, key, rx, value))
    return out


def compile_rx(where, text):
    try:
        return re.compile(text)
    except re.error as e:
        raise Setup('%s: bad regular expression: %s' % (where, e))


def split_rx(where, key, v, nsel):
    """A `KEY~` value with nsel literal selector fields: (selectors, compiled regex)."""
    p = v.split(' ', nsel)
    if len(p) != nsel + 1:
        raise Setup('%s: %s~ wants %d selector field(s) and a regex' % (where, key, nsel))
    return p[:nsel], compile_rx(where, p[nsel])


def check_value_forms(path, recs):
    """The value forms of the non-text keys and the order of file/panel; raises Setup. A `~` value
    is replaced by its compiled form: a pattern, or (selectors, pattern) for count, subpaths and
    color."""
    seen_file = False
    in_panel = False
    for n, (i, key, rx, v) in enumerate(recs):
        where = '%s:%d' % (path, i)
        if rx:
            if key in ('count', 'subpaths', 'color'):
                nsel = 2 if key == 'color' else 1
                sel, pat = split_rx(where, key, v, nsel)
                if key == 'count' and not CLASS_RE.fullmatch(sel[0]):
                    raise Setup('%s: count~ wants "CLASS RX"' % where)
                if key == 'subpaths' and not NUM_RE.fullmatch(sel[0]):
                    raise Setup('%s: subpaths~ wants "I RX"' % where)
                if key == 'color' and (sel[0] not in COLOR_ATTR or not NUM_RE.fullmatch(sel[1])):
                    raise Setup('%s: color~ wants "CLASS I RX" with CLASS one of %s'
                                % (where, ' '.join(sorted(COLOR_ATTR))))
                recs[n] = (i, key, rx, (sel, pat))
            else:
                recs[n] = (i, key, rx, compile_rx(where, v))
            if key == 'file':
                seen_file = True
                in_panel = False
            elif not seen_file:
                raise Setup('%s: %r before any file' % (where, key))
            elif key == 'panel':
                in_panel = True
            elif key in PANEL_KEYS and not in_panel:
                raise Setup('%s: %r before any panel of this file' % (where, key))
            continue
        if key == 'file':
            if v == '' or v.startswith('/'):
                raise Setup('%s: file wants a relative path' % where)
            seen_file = True
            in_panel = False
            continue
        if not seen_file:
            raise Setup('%s: %r before any file' % (where, key))
        if key == 'panel':
            if not NUM_RE.fullmatch(v):
                raise Setup('%s: panel wants a decimal index' % where)
            in_panel = True
            continue
        if key in PANEL_KEYS and not in_panel:
            raise Setup('%s: %r before any panel of this file' % (where, key))
        if key == 'canvas':
            p = v.split(' ')
            if len(p) != 2 or not all(NUM_RE.fullmatch(x) for x in p):
                raise Setup('%s: canvas wants "W H"' % where)
        elif key == 'panels':
            if not NUM_RE.fullmatch(v):
                raise Setup('%s: panels wants a decimal count' % where)
        elif key == 'count':
            p = v.split(' ')
            if len(p) != 2 or not CLASS_RE.fullmatch(p[0]) or not NUM_RE.fullmatch(p[1]):
                raise Setup('%s: count wants "CLASS N"' % where)
        elif key == 'subpaths':
            p = v.split(' ')
            if len(p) != 2 or not all(NUM_RE.fullmatch(x) for x in p):
                raise Setup('%s: subpaths wants "I N"' % where)
        elif key == 'color':
            p = v.split(' ')
            if len(p) != 3 or p[0] not in COLOR_ATTR or not NUM_RE.fullmatch(p[1]):
                raise Setup('%s: color wants "CLASS I C" with CLASS one of %s'
                            % (where, ' '.join(sorted(COLOR_ATTR))))
    if not seen_file:
        raise Setup('%s: no file line' % path)


def text_matches(want, rx, got):
    if rx:
        return want.fullmatch(got) is not None
    return want == got


def show(want, rx):
    return ('~ %s' % want.pattern) if rx else repr(want)


class Checker:
    def __init__(self, path, rundir):
        self.path = path
        self.rundir = rundir
        self.root = None
        self.panels = []
        self.panel = None
        self.lists = {}

    def fail(self, line, msg):
        raise Fail('%s:%d: %s' % (self.path, line, msg))

    def open_file(self, line, rel):
        p = os.path.join(self.rundir, rel)
        try:
            with open(p, 'rb') as f:
                data = f.read()
        except OSError as e:
            self.fail(line, 'file %s: %s' % (rel, e.strerror or 'cannot be read'))
        if not data.startswith(XML_DECL):
            self.fail(line, 'file %s: the first line is not the XML declaration %r'
                      % (rel, XML_DECL.decode().rstrip('\n')))
        try:
            root = ET.fromstring(data)
        except ET.ParseError as e:
            self.fail(line, 'file %s: not well-formed XML: %s' % (rel, e))
        if root.tag != SVG + 'svg':
            self.fail(line, 'file %s: the root element is %r, not %ssvg' % (rel, root.tag, SVG))
        if root.get('class') != 'sea-figure':
            self.fail(line, 'file %s: the root element has class %r, not "sea-figure"'
                      % (rel, root.get('class')))
        self.root = root
        self.panels = of_class(root, 'panel', 'g')
        self.panel = None
        self.lists = {}

    def end_panel(self):
        """Compare the accumulated list keys of the panel just ended."""
        if self.panel is None:
            return
        for key, entries in self.lists.items():
            cls = LIST_KEYS[key]
            got = [text_of(e) for e in of_class(self.panel, cls)]
            for j, (line, rx, want) in enumerate(entries):
                if j >= len(got):
                    self.fail(line, '%s %d: expected %s, the panel has only %d %s text(s): %r'
                              % (key, j, show(want, rx), len(got), cls, got))
                if not text_matches(want, rx, got[j]):
                    self.fail(line, '%s %d: expected %s, found %r (all: %r)'
                              % (key, j, show(want, rx), got[j], got))
            if len(got) != len(entries):
                self.fail(entries[-1][0], '%s: %d text(s) expected, the panel has %d: %r'
                          % (key, len(entries), len(got), got))
        self.lists = {}

    def one_text(self, line, scope, cls, name, rx, want, what):
        els = of_class(scope, cls, name)
        if not rx and want == '-':
            if els:
                self.fail(line, '%s: expected none, found %r' % (what, text_of(els[0])))
            return
        if len(els) != 1:
            self.fail(line, '%s: expected one element of class %s, found %d'
                      % (what, cls, len(els)))
        got = text_of(els[0])
        if not text_matches(want, rx, got):
            self.fail(line, '%s: expected %s, found %r' % (what, show(want, rx), got))

    def run(self, recs):
        for line, key, rx, v in recs:
            if rx and key not in ('heading',) + TEXT1_KEYS + tuple(LIST_KEYS):
                self.run_rx(line, key, v)
            elif key == 'file':
                self.end_panel()
                self.open_file(line, v)
            elif key == 'panel':
                self.end_panel()
                k = int(v)
                if k >= len(self.panels):
                    self.fail(line, 'panel %d: the file has %d panel(s)' % (k, len(self.panels)))
                self.panel = self.panels[k]
            elif key == 'canvas':
                w, h = v.split(' ')
                got = (self.root.get('width'), self.root.get('height'))
                if got != (w, h):
                    self.fail(line, 'canvas: expected %s %s, found width=%r height=%r'
                              % (w, h, got[0], got[1]))
            elif key == 'heading':
                self.one_text(line, self.root, 'heading', 'text', rx, v, 'heading')
            elif key == 'panels':
                if len(self.panels) != int(v):
                    self.fail(line, 'panels: expected %s, found %d' % (v, len(self.panels)))
            elif key in TEXT1_KEYS:
                self.one_text(line, self.panel, key, None, rx, v, key)
            elif key in LIST_KEYS:
                self.lists.setdefault(key, []).append((line, rx, v))
            elif key == 'count':
                cls, n = v.split(' ')
                got = len(of_class(self.panel, cls))
                if got != int(n):
                    self.fail(line, 'count %s: expected %s, found %d' % (cls, n, got))
            elif key == 'subpaths':
                i, n = (int(x) for x in v.split(' '))
                lines = of_class(self.panel, 'line')
                if i >= len(lines):
                    self.fail(line, 'subpaths %d: the panel has %d line element(s)' % (i, len(lines)))
                d = lines[i].get('d')
                if d is None:
                    self.fail(line, 'subpaths %d: the line element has no d attribute' % i)
                got = d.count('M')
                if got != n:
                    self.fail(line, 'subpaths %d: expected %d M commands, found %d in %r'
                              % (i, n, got, d))
            elif key == 'color':
                cls, i, c = v.split(' ')
                i = int(i)
                els = of_class(self.panel, cls)
                if i >= len(els):
                    self.fail(line, 'color %s %d: the panel has %d element(s) of class %s'
                              % (cls, i, len(els), cls))
                attr = COLOR_ATTR[cls]
                got = els[i].get(attr)
                if got != c:
                    self.fail(line, 'color %s %d: expected %s=%r, found %r' % (cls, i, attr, c, got))
        self.end_panel()


    def run_rx(self, line, key, v):
        """A `KEY~` line of a non-text key (v compiled by check_value_forms)."""
        if key == 'file':
            self.end_panel()
            found = []
            for d, dirs, files in os.walk(self.rundir):
                dirs.sort()
                for f in sorted(files):
                    rel = os.path.relpath(os.path.join(d, f), self.rundir).replace(os.sep, '/')
                    if v.fullmatch(rel):
                        found.append(rel)
            if len(found) != 1:
                self.fail(line, 'file~ %s: expected one matching file, found %d: %r'
                          % (v.pattern, len(found), found))
            self.open_file(line, found[0])
            return
        if key == 'panel':
            self.end_panel()
            ks = [k for k in range(len(self.panels)) if v.fullmatch(str(k))]
            if len(ks) != 1:
                self.fail(line, 'panel~ %s: expected one matching panel index of %d, found %r'
                          % (v.pattern, len(self.panels), ks))
            self.panel = self.panels[ks[0]]
            return
        if key == 'canvas':
            got = '%s %s' % (self.root.get('width'), self.root.get('height'))
            what = 'canvas'
        elif key == 'panels':
            got = str(len(self.panels))
            what = 'panels'
        elif key == 'count':
            (cls,), v = v
            got = str(len(of_class(self.panel, cls)))
            what = 'count %s' % cls
        elif key == 'subpaths':
            (i,), v = v
            i = int(i)
            lines = of_class(self.panel, 'line')
            if i >= len(lines):
                self.fail(line, 'subpaths %d: the panel has %d line element(s)' % (i, len(lines)))
            got = str((lines[i].get('d') or '').count('M'))
            what = 'subpaths %d' % i
        else:
            (cls, i), v = v
            i = int(i)
            els = of_class(self.panel, cls)
            if i >= len(els):
                self.fail(line, 'color %s %d: the panel has %d element(s) of class %s'
                          % (cls, i, len(els), cls))
            got = els[i].get(COLOR_ATTR[cls]) or ''
            what = 'color %s %d' % (cls, i)
        if not v.fullmatch(got):
            self.fail(line, '%s: expected ~ %s, found %r' % (what, v.pattern, got))


def main(argv):
    if len(argv) != 2:
        print('usage: plot_struct.py STRUCT RUNDIR', file=sys.stderr)
        return 2
    struct, rundir = argv
    try:
        if not os.path.isdir(rundir):
            raise Setup('run directory %s not found' % rundir)
        recs = parse_struct(struct)
        check_value_forms(struct, recs)
    except Setup as e:
        print('plot_struct.py: %s' % e, file=sys.stderr)
        return 2
    try:
        Checker(struct, rundir).run(recs)
    except Fail as e:
        print('FAIL: %s' % e)
        return 1
    print('PASS')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
