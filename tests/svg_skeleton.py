"""tests/svg_skeleton.py -- Decision 138 (a)'s skeleton comparison of two SVG files (docs/DESIGN.md
2.14.8 "W2's class-R figure", 2.14.9 "Cross"). Python standard library only; run on the Mac by
tests/cross_accept.sh for a deferred port whose `// cross:` header has `svg=approx` (W2).

usage: timeout 120 uv run --no-project python tests/svg_skeleton.py EXPECTED ACTUAL

EXPECTED is the Mac's SVG (the bundle's NAME.expect/output/NAME.svg), ACTUAL the host's kept SVG.

The comparison, exactly as 2.14.8 words it:
  1. In both files every match of `-?[0-9]+(\\.[0-9]+)?` inside an attribute value of an element
     tag, the value of an attribute named `href` excepted, is replaced by `#`; the two results (the
     skeletons) must be byte-identical. Everything outside those attribute values (element text,
     `href` values, the XML declaration, comments, the markup itself) is thereby compared byte for
     byte.
  2. The replaced numbers, taken in order, must then agree pairwise (and be equally many): a number
     without a decimal point exactly (as written); a pair of numbers that both have exactly two
     fraction digits (every `%.2f` value) as the integer number of hundredths each spells (its
     digits with the point removed, negative with its `-`), the two integers differing by at most
     1; any other pair exactly (as written). No number is compared as a float.

The attribute values are found lexically: an element tag is `<` followed by a name byte (not `/`,
`!` or `?`) up to the first `>` outside a quoted value; its attributes are `NAME = "VALUE"` or
`NAME = 'VALUE'`. Comments, processing instructions, CDATA sections and end tags are copied to the
skeleton unchanged.

Output: `PASS` and exit 0; `FAIL: <the first difference>` (the byte offset, line and column of the
first differing skeleton byte with both contexts, or the index, positions and texts of the first
disagreeing number pair) and exit 1; a setup error (a file missing or unreadable, an unterminated
tag) is `svg_skeleton.py: <reason>` on standard error and exit 2.
"""

import re
import sys

NUM = re.compile(rb'-?[0-9]+(\.[0-9]+)?')
ATTR = re.compile(rb'([^\s=/>"\']+)(\s*=\s*)("([^"]*)"|\'([^\']*)\')')
TWO = re.compile(rb'-?[0-9]+\.[0-9]{2}')


class Setup(Exception):
    pass


def skeleton(data, path):
    """Return (skeleton bytes, [(number bytes, offset in the file)]) of one SVG file."""
    out = bytearray()
    nums = []
    i = 0
    n = len(data)
    while i < n:
        lt = data.find(b'<', i)
        if lt < 0:
            out += data[i:]
            break
        out += data[i:lt]
        if data.startswith(b'<!--', lt):
            end = data.find(b'-->', lt + 4)
            if end < 0:
                raise Setup('%s: unterminated comment at byte %d' % (path, lt))
            end += 3
            out += data[lt:end]
            i = end
            continue
        if data.startswith(b'<![CDATA[', lt):
            end = data.find(b']]>', lt + 9)
            if end < 0:
                raise Setup('%s: unterminated CDATA section at byte %d' % (path, lt))
            end += 3
            out += data[lt:end]
            i = end
            continue
        if data.startswith(b'<?', lt):
            end = data.find(b'?>', lt + 2)
            if end < 0:
                raise Setup('%s: unterminated processing instruction at byte %d' % (path, lt))
            end += 2
            out += data[lt:end]
            i = end
            continue
        if lt + 1 >= n or data[lt + 1:lt + 2] in (b'/', b'!'):
            end = data.find(b'>', lt + 1)
            if end < 0:
                raise Setup('%s: unterminated tag at byte %d' % (path, lt))
            end += 1
            out += data[lt:end]
            i = end
            continue
        # an element start tag: find its end outside quoted values
        j = lt + 1
        q = None
        while j < n:
            c = data[j:j + 1]
            if q:
                if c == q:
                    q = None
            elif c in (b'"', b"'"):
                q = c
            elif c == b'>':
                break
            j += 1
        if j >= n:
            raise Setup('%s: unterminated tag at byte %d' % (path, lt))
        tag = data[lt:j + 1]
        k = 0
        for m in ATTR.finditer(tag):
            out += tag[k:m.start()]
            name = m.group(1)
            vstart = m.start(4) if m.group(4) is not None else m.start(5)
            value = m.group(4) if m.group(4) is not None else m.group(5)
            out += tag[m.start():vstart]
            if name == b'href':
                out += value
            else:
                p = 0
                for nm in NUM.finditer(value):
                    out += value[p:nm.start()]
                    out += b'#'
                    nums.append((nm.group(0), lt + vstart + nm.start()))
                    p = nm.end()
                out += value[p:]
            out += tag[vstart + len(value):m.end()]
            k = m.end()
        out += tag[k:]
        i = j + 1
    return bytes(out), nums


def linecol(data, off):
    line = data.count(b'\n', 0, off) + 1
    col = off - (data.rfind(b'\n', 0, off) + 1) + 1
    return line, col


def context(data, off):
    s = data[max(0, off - 30):off + 30].decode('utf-8', 'replace')
    return repr(s)


def hundredths(t):
    return int(t.replace(b'.', b''))


def numbers_agree(a, b):
    if TWO.fullmatch(a) and TWO.fullmatch(b):
        return abs(hundredths(a) - hundredths(b)) <= 1
    return a == b


def compare(exp, act, epath, apath):
    """Return None when the files agree, else the first difference as a sentence."""
    es, en = skeleton(exp, epath)
    as_, an = skeleton(act, apath)
    if es != as_:
        m = min(len(es), len(as_))
        off = next((x for x in range(m) if es[x] != as_[x]), m)
        line, col = linecol(es, off)
        return ('skeletons differ at skeleton byte %d (skeleton line %d, column %d): expected %s, found %s'
                % (off, line, col, context(es, off), context(as_, off)))
    for idx, ((a, ao), (b, bo)) in enumerate(zip(en, an)):
        if not numbers_agree(a, b):
            el, ec = linecol(exp, ao)
            al, ac = linecol(act, bo)
            return ('number %d differs: expected %s (line %d, column %d), found %s (line %d, column %d)'
                    % (idx, a.decode(), el, ec, b.decode(), al, ac))
    if len(en) != len(an):
        return ('the attribute numbers are %d expected but %d found'
                % (len(en), len(an)))
    return None


def main(argv):
    if len(argv) != 2:
        print('usage: svg_skeleton.py EXPECTED ACTUAL', file=sys.stderr)
        return 2
    epath, apath = argv
    try:
        try:
            with open(epath, 'rb') as fh:
                exp = fh.read()
            with open(apath, 'rb') as fh:
                act = fh.read()
        except OSError as e:
            raise Setup('cannot read %s' % e)
        diff = compare(exp, act, epath, apath)
    except Setup as e:
        print('svg_skeleton.py: %s' % e, file=sys.stderr)
        return 2
    if diff is not None:
        print('FAIL: %s' % diff)
        return 1
    print('PASS')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
