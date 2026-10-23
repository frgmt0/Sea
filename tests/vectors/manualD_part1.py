"""manualD_part1 (DESIGN.md 6.2 "4g-2", 8 row 4g-2): the first part of LANGUAGE.md Appendix D as a
programs/ test, and its bad-option twin errors/manualD_part1_badopt.

Run with `timeout 120 uv run --no-project python tests/vectors/manualD_part1.py`. It builds
manualD_part1.sea from Appendix D's code in docs/LANGUAGE.md, from the line `struct Dim {` through
the line `let rssSigma = sqrt(rssVar)`, verbatim, with exactly one line removed (`let scale =
linspace(...)`, a prelude function of 4h), followed by the nine lines DESIGN.md 6.2 lists; no
header comment is added (the copy starts with `struct Dim {` on line 1, so the `_ => { error(...) }`
arm of the options loop is line 16). It writes:

* programs/manualD_part1.{sea,args,out}: `.args` the one argument `--figures`; `.out` the 12 lines;
* errors/manualD_part1_badopt.{sea,args,err,status}: the same program with `--bogus`: standard
  output empty, `manualD_part1_badopt.sea:16: error: unknown option "--bogus"`, status 1
  (LANGUAGE.md 7.6, 9.3).

The 12 lines are computed by an independent IEEE binary64 model of the program (Python floats are
binary64, `+ - * /` correctly rounded to nearest even, `math.sqrt` correctly rounded, LANGUAGE.md
6.8): the Dim table parsed from the copied source text (each literal converted by Python's correctly
rounded decimal-to-binary conversion, LANGUAGE.md 3.4), the sums left to right in index order,
`dims[d].sign * dims[d].nom` with the i64 sign converted exactly (4.2), `tol / 3`, `tol / sqrt(3)`,
`tol / sqrt(6)` with the untyped 3 and 6 converted (4.2), `sigmaDim[d] ^ 2` as one multiplication
(6.5), and `%.17g` as C99 (Python's `%` rounds correctly, 11.1). The result is asserted equal to the
12 lines written in DESIGN.md 6.2 during the specification.
"""

import math
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
TESTS = os.path.dirname(HERE)
ROOT = os.path.dirname(TESTS)
PROGRAMS = os.path.join(TESTS, 'programs')
ERRORS = os.path.join(TESTS, 'errors')

TAIL = r'''printf("nDim %d\n", nDim)
for d in 0..nDim {
    printf("%s %s %.17g\n", dims[d].name, dims[d].dist, sigmaDim[d])
}
printf("nomGap %.17g\n", nomGap)
printf("wcHalf %.17g\n", wcHalf)
printf("rssSigma %.17g\n", rssSigma)
if exportRef { printf("export\n") }
if figures { printf("figures\n") }
'''

# DESIGN.md 6.2, the expected .out agreed in the specification (an independent derivation)
DESIGN_OUT = '''nDim 7
housing depth normal 0.016666666666666666
gasket triangular 0.016329931618554522
bearing 1 normal 0.0040000000000000001
spacer uniform 0.017320508075688773
gear hub triangular 0.016329931618554522
bearing 2 normal 0.0040000000000000001
retaining ring uniform 0.017320508075688773
nomGap 0.30000000000000004
wcHalf 0.21400000000000002
rssSigma 0.037988302293088999
figures
'''


def write(path, data):
    with open(path, 'wb') as f:
        f.write(data.encode('ascii'))


def appendix_d_code():
    with open(os.path.join(ROOT, 'docs', 'LANGUAGE.md'), encoding='utf-8') as f:
        text = f.read()
    start = text.index('### Appendix D.')
    body = text[start:]
    open_ = body.index('```sea\n') + len('```sea\n')
    close = body.index('\n```', open_)
    return body[open_:close + 1].split('\n')[:-1]


def build_source():
    lines = appendix_d_code()
    first = lines.index('struct Dim {')
    last = lines.index('let rssSigma = sqrt(rssVar)')
    part = lines[first:last + 1]
    lin = [ln for ln in part if ln.startswith('let scale = linspace(')]
    assert len(lin) == 1, lin
    part.remove(lin[0])
    assert all(ln.isascii() for ln in part)
    src = '\n'.join(part) + '\n' + TAIL
    assert src.split('\n')[15].strip().startswith('_ => { error("unknown option'), src.split('\n')[15]
    assert src.split('\n')[8] == ''          # Appendix D's blank line after the struct is kept
    return src


def model(src):
    """The arithmetic of the program in its order, on the Dim table parsed from the copied source."""
    rows = re.findall(r'Dim \{ name: "([^"]*)",\s*nom: ([0-9.]+),\s*tol: ([0-9.]+),\s*dist: "([^"]*)",\s*'
                      r'sign: (-?[0-9]+),\s*alpha: ([0-9.e-]+) \}', src)
    assert len(rows) == 7, rows
    dims = [{'name': n, 'nom': float(nom), 'tol': float(tol), 'dist': dist, 'sign': int(sg)}
            for n, nom, tol, dist, sg, _ in rows]
    nDim = len(dims)
    nomGap = 0.0
    wcHalf = 0.0
    rssVar = 0.0
    sigmaDim = [0.0] * nDim
    for d in range(nDim):
        nomGap = nomGap + float(dims[d]['sign']) * dims[d]['nom']
        wcHalf = wcHalf + dims[d]['tol']
        dist = dims[d]['dist']
        if dist == 'normal':
            sigmaDim[d] = dims[d]['tol'] / 3.0
        elif dist == 'uniform':
            sigmaDim[d] = dims[d]['tol'] / math.sqrt(3.0)
        elif dist == 'triangular':
            sigmaDim[d] = dims[d]['tol'] / math.sqrt(6.0)
        rssVar = rssVar + sigmaDim[d] * sigmaDim[d]
    rssSigma = math.sqrt(rssVar)
    out = 'nDim %d\n' % nDim
    for d in range(nDim):
        out += '%s %s %.17g\n' % (dims[d]['name'], dims[d]['dist'], sigmaDim[d])
    out += 'nomGap %.17g\n' % nomGap
    out += 'wcHalf %.17g\n' % wcHalf
    out += 'rssSigma %.17g\n' % rssSigma
    exportRef, figures = False, True            # the one argument --figures
    if exportRef:
        out += 'export\n'
    if figures:
        out += 'figures\n'
    return out


def main():
    src = build_source()
    out = model(src)
    assert out == DESIGN_OUT, out
    assert len(out.split('\n')) - 1 == 12
    write(os.path.join(PROGRAMS, 'manualD_part1.sea'), src)
    write(os.path.join(PROGRAMS, 'manualD_part1.args'), '--figures\n')
    write(os.path.join(PROGRAMS, 'manualD_part1.out'), out)
    write(os.path.join(ERRORS, 'manualD_part1_badopt.sea'), src)
    write(os.path.join(ERRORS, 'manualD_part1_badopt.args'), '--bogus\n')
    write(os.path.join(ERRORS, 'manualD_part1_badopt.err'),
          'manualD_part1_badopt.sea:16: error: unknown option "--bogus"\n')
    write(os.path.join(ERRORS, 'manualD_part1_badopt.status'), '1\n')
    print(out, end='')


main()
