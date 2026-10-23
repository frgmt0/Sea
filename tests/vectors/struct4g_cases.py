"""Sub-phase 4g-2 corpus: programs/ and errors/ tests of structs, records, projection and fixed-size
`str` and struct arrays (DESIGN.md 6.2 "4g-2", 8 row 4g-2, work package T1b).

Run with `timeout 120 uv run --no-project python tests/vectors/struct4g_cases.py` (after str4g_cases.py
and arr4e_cases.py, which still write two of the goldens retired here). It writes programs/struct_*,
programs/str_fixed, programs/records and programs/heap_struct_*, the 4g-2 errors/ tests (err_struct_*,
err_record_*: compile time; r_str_fix: run time), and deletes the four goldens 4g-2 retires
(err_ns_struct, err_ns_record, err_ns_str_fixed_type and err_ns_str_fixed_let: their constructs compile
from 4g-2 and are covered by the programs below). manualD_part1 and manualD_part1_badopt are written by
manualD_part1.py.

Every expected byte is derived here from LANGUAGE.md 4.5-4.7, 5.5, 5.6, 6.8 (rule 5, evaluation
order), 6.9, 6.10, 7.2, 7.3, 7.5, 8.2-8.4, 9.2, 10.2, 10.6, 11.1 and, for messages, positions and
orders, DESIGN.md 2.6.2 (the error table and its `at` column, the type spelling of `text`, "Readings
fixed by 4g", "Which program reports it"), 3.3 (a node's position is that of the first token of its
text, so a `dot` and a `bin` stand at their left operand), 3.4 (the AST node of each construct),
3.4.2 (the struct declaration checks) and 3.5.5 ("Evaluation order": literal values in source
order). The model is independent of the compiler: a struct or record value is a Python dict copied
deeply on every assignment, binding, argument and result (value semantics, 4.5, 4.6: copy on write is
invisible, so a deep copy is the meaning), a `ref` parameter is the caller's dict itself (8.3), arrays
are Python lists, strings bytes; `%g` is Python's `%g` (C99, correctly rounded, 11.1). The run-time
error line of an errors/ test is the line holding its marker; a compile error's column is that of its
marker text inside that line (both computed from the source text).

Printing (no `print` until phase 6): f64 vectors through `pf` (`n:` and ` %g` per element), i64
vectors through `pvi`, bool vectors through `pvb` (`%d` of a bool is 0 or 1), str vectors through `ps`
(` [s]` per element), str matrices through `pms` (`RxC`, ` |` per row).
"""

import copy
import os

HERE = os.path.dirname(os.path.abspath(__file__))
TESTS = os.path.dirname(HERE)
PROGRAMS = os.path.join(TESTS, 'programs')
ERRORS = os.path.join(TESTS, 'errors')
COUNT = {'programs': 0, 'errors': 0}


def write(path, data):
    if isinstance(data, str):
        data = data.encode('ascii')
    with open(path, 'wb') as f:
        f.write(data)


def remove(path):
    if os.path.exists(path):
        os.remove(path)


def source(name, comment, body):
    head = ''.join('// %s\n' % c for c in comment)
    head = '// %s -- ' % name + head[3:]
    src = head + body
    for ln in src.split('\n'):
        assert len(ln.encode('ascii')) <= 4096, ln[:40]           # 3.1 line limit
        assert all(c == '\t' or 0x20 <= ord(c) < 0x7F for c in ln), ln  # 3.1: ASCII outside escapes
    return src


# ---------------------------------------------------------------------------- the model
def g(x):
    """%g of an f64 (11.1: C99; Python's %g rounds correctly, as C99 does)."""
    assert isinstance(x, float)
    return ('%g' % x).encode('ascii')


def d(v):
    """%d of a bool or an i64 (11.1)."""
    if isinstance(v, bool):
        return b'1' if v else b'0'
    assert isinstance(v, int)
    return str(v).encode('ascii')


def pf(v):
    return b'%d:' % len(v) + b''.join(b' ' + g(x) for x in v)


def pvi(v):
    return b'%d:' % len(v) + b''.join(b' ' + d(x) for x in v)


def pvb(v):
    return b'%d:' % len(v) + b''.join(b' ' + d(x) for x in v)


def ps(v):
    return b'%d:' % len(v) + b''.join(b' [' + s + b']' for s in v)


def pms(rows):
    c = len(rows[0]) if rows else 0
    return b'%dx%d' % (len(rows), c) + b''.join(b' |' + b''.join(b' [' + s + b']' for s in r)
                                                 for r in rows)


def cp(v):
    """Value semantics (LANGUAGE.md 4.5, 4.6): every copy is independent."""
    return copy.deepcopy(v)


HELPERS = {
    'pf': r'''fn pf(v: f64[]) {
    printf("%d:", len(v))
    for x in v {
        printf(" %g", x)
    }
    printf("\n")
}
''',
    'pvi': r'''fn pvi(v: i64[]) {
    printf("%d:", len(v))
    for x in v {
        printf(" %d", x)
    }
    printf("\n")
}
''',
    'pvb': r'''fn pvb(v: bool[]) {
    printf("%d:", len(v))
    for x in v {
        printf(" %d", x)
    }
    printf("\n")
}
''',
    'ps': r'''fn ps(v: str[]) {
    printf("%d:", len(v))
    for s in v {
        printf(" [%s]", s)
    }
    printf("\n")
}
''',
    'pms': r'''fn pms(A: str[,]) {
    printf("%dx%d", rows(A), cols(A))
    for i in 0..rows(A) {
        printf(" |")
        for j in 0..cols(A) {
            printf(" [%s]", A[i, j])
        }
    }
    printf("\n")
}
''',
}


def prog(name, comment, helpers, steps, fns='', head=''):
    """A programs/ test. head: items before the helpers (struct declarations). steps: (code,
    expected) pairs in program order; expected is the bytes the code prints, lines separated by LF,
    without the final LF (None: prints nothing)."""
    body = head + ''.join(HELPERS[h] for h in helpers) + fns
    body += ''.join(code + '\n' for code, _ in steps)
    out = b''.join(o + b'\n' for _, o in steps if o is not None)
    write(os.path.join(PROGRAMS, name + '.sea'), source(name, comment, body))
    write(os.path.join(PROGRAMS, name + '.out'), out)
    remove(os.path.join(PROGRAMS, name + '.args'))
    COUNT['programs'] += 1


def line_of(src, marker):
    lines = src.split('\n')
    hits = [i for i, ln in enumerate(lines) if marker in ln and not ln.startswith('//')]
    assert len(hits) == 1, (marker, hits)
    return hits[0] + 1, lines[hits[0]]


def err_rt(name, comment, body, marker, msg, out=b''):
    """A run-time error: stderr `NAME.sea:LINE: error: MSG`, status 1, stdout `out`."""
    src = source(name, comment, body)
    ln, _ = line_of(src, marker)
    write(os.path.join(ERRORS, name + '.sea'), src)
    write(os.path.join(ERRORS, name + '.err'), b'%s.sea:%d: error: ' % (name.encode(), ln) + msg + b'\n')
    write(os.path.join(ERRORS, name + '.status'), '1\n')
    path = os.path.join(ERRORS, name + '.out')
    if out:
        write(path, out)
    else:
        remove(path)
    COUNT['errors'] += 1


def err_c(name, comment, body, marker, col_text, msg, last=False):
    """A compile error at the first (last=True: the last) occurrence of col_text in the marker's line."""
    src = source(name, comment, body)
    ln, text = line_of(src, marker)
    col = (text.rindex(col_text) if last else text.index(col_text)) + 1
    write(os.path.join(ERRORS, name + '.sea'), src)
    write(os.path.join(ERRORS, name + '.err'), '%s.sea:%d:%d: error: %s\n' % (name, ln, col, msg))
    write(os.path.join(ERRORS, name + '.status'), '1\n')
    remove(os.path.join(ERRORS, name + '.out'))
    COUNT['errors'] += 1


# ============================================================ struct_basic (4.6, 3.5.5, 7.3, 8.2-8.4, L-h)
def struct_basic():
    head = r'''struct Lim { lo: f64, hi: f64 }
struct P {
    name: str
    x: f64
    n: i64
    ok: bool
    v: f64[]
    w: f64[3]
    tags: str[]
    lim: Lim
}
struct E {}
'''
    fns = r'''fn tf(x: f64) -> f64 {
    printf("f%g ", x)
    return x
}
fn ti(k: i64) -> i64 {
    printf("i%d ", k)
    return k
}
fn tr(s: str) -> str {
    printf("%s ", s)
    return s
}
fn pp(p: P) {
    printf("%s x=%g n=%d ok=%d v=", p.name, p.x, p.n, p.ok)
    for x in p.v {
        printf(" %g", x)
    }
    printf(" w=%g,%g,%g tags=", p.w[0], p.w[1], p.w[2])
    for t in p.tags {
        printf(" [%s]", t)
    }
    printf(" lim=%g..%g\n", p.lim.lo, p.lim.hi)
}
fn mk(name: str, k: i64) -> P {
    return P { name: name, x: f64(k) / 2.0, n: k, ok: k > 0, v: [f64(k)], w: [1.0, 2.0, 3.0], tags: [], lim: Lim { lo: 0.0, hi: 1.0 } }
}
fn swap2(a: P, b: P) -> (P, P) {
    return (b, a)
}
fn renamed(p: P, s: str) -> P {
    var r = p
    r.name = s
    r.v[0] = -1.0
    return r
}
fn bump(ref p: P) {
    p.n += 10
    p.name += "!"
    p.v[0] = -2.0
    p.lim.hi = 7.0
    p.w[2] *= 2.0
}
fn reset(ref p: P, k: i64) {
    p = mk("z", k)
}
fn takeE(e: E) -> E {
    return e
}
'''

    def P(name, x, n, ok, v, w, tags, lo, hi):
        return {'name': name, 'x': x, 'n': n, 'ok': ok, 'v': list(v), 'w': list(w), 'tags': list(tags),
                'lim': {'lo': lo, 'hi': hi}}

    def pp(p):
        return (p['name'] + b' x=' + g(p['x']) + b' n=' + d(p['n']) + b' ok=' + d(p['ok']) + b' v=' +
                b''.join(b' ' + g(x) for x in p['v']) + b' w=' + b','.join(g(x) for x in p['w']) +
                b' tags=' + b''.join(b' [' + t + b']' for t in p['tags']) +
                b' lim=' + g(p['lim']['lo']) + b'..' + g(p['lim']['hi']))

    def mk(name, k):
        return P(name, float(k) / 2.0, k, k > 0, [float(k)], [1.0, 2.0, 3.0], [], 0.0, 1.0)

    # the literal: values written in any order; their side effects run in source order (3.5.5):
    # the inner Lim literal first (hi before lo), then tags, w, n, x and name
    trace = b'f2 f1 b f3 i7 f0.5 p '
    p = P(b'p', 0.5, 7, True, [1.5, 2.5, 3.5, 4.5], [3.0, 4.0, 5.0], [b'a', b'b'], 1.0, 2.0)
    q = cp(p)
    q['x'] = -1.25
    q['n'] += 1
    q['ok'] = False
    q['name'] += b'x'
    q['name'] = q['name'] + b'y'
    i = 3
    q['v'][i] = 9.0
    q['v'][0:2] = [0.0, 0.0]
    q['w'][1] = 8.0
    q['w'][0] += 1.0
    q['tags'][1] = b'B'
    q['lim']['lo'] = -1.0
    q['lim'] = {'lo': q['lim']['lo'], 'hi': 3.5}
    a_, b_ = mk(b'b', 2), mk(b'a', 1)          # swap2(mk("a", 1), mk("b", 2))
    rn = cp(p)
    rn['name'] = b'rn'
    rn['v'][0] = -1.0
    r = mk(b'r', 3)
    r['n'] += 10
    r['name'] += b'!'
    r['v'][0] = -2.0
    r['lim']['hi'] = 7.0
    r['w'][2] *= 2.0
    k = 2
    c = cp(r) if k > 5 else cp(q)
    c2 = cp(c)
    c2['v'][0] = 100.0
    c2['lim']['hi'] = -3.0
    z = mk(b'z', 4)
    steps = [
        ('let p = P { lim: Lim { hi: tf(2.0), lo: tf(1.0) }, tags: ["a", tr("b")], w: [tf(3.0), 4.0, 5.0], '
         'v: [1.5, 2.5, 3.5, 4.5], ok: true, n: ti(7), x: tf(0.5), name: tr("p") }', None),
        (r'printf("\n")', trace),
        ('pp(p)', pp(p)),
        # field reads of every kind, a nested field, elements of array fields, len of fields
        (r'printf("%s %g %d %d %g %g %s %g %d %d\n", p.name, p.x, p.n, p.ok, p.v[1], p.w[2], p.tags[0], '
         r'p.lim.hi, len(p.v), len(p.tags))',
         b' '.join([p['name'], g(p['x']), d(p['n']), d(p['ok']), g(p['v'][1]), g(p['w'][2]), p['tags'][0],
                    g(p['lim']['hi']), d(len(p['v'])), d(len(p['tags']))])),
        # a var copy, written field by field: scalar, i64 +=, bool, str += and =, an element of a
        # dynamic array field by a variable index, a range of it (an L6 field root), an element of a
        # fixed array field (= and +=), an element of a str[] field, a nested field, a whole struct field
        ('var q = p', None),
        ('q.x = -1.25', None),
        ('q.n += 1', None),
        ('q.ok = false', None),
        ('q.name += "x"', None),
        ('q.name = q.name + "y"', None),
        ('let i = 3', None),
        ('q.v[i] = 9.0', None),
        ('q.v[0..2] = 0.0', None),
        ('q.w[1] = 8.0', None),
        ('q.w[0] += 1.0', None),
        ('q.tags[1] = "B"', None),
        ('q.lim.lo = -1.0', None),
        ('q.lim = Lim { lo: q.lim.lo, hi: 3.5 }', None),
        ('pp(q)', pp(q)),
        # value semantics: the original is unchanged (its array fields shared until written, 4.5)
        ('pp(p)', pp(p)),
        # struct parameters and results; two struct results; a parameter copied into a var
        ('let (a, b) = swap2(mk("a", 1), mk("b", 2))', None),
        ('pp(a)', pp(a_)),
        ('pp(b)', pp(b_)),
        ('pp(renamed(p, "rn"))', pp(rn)),
        (r'printf("%s %g\n", p.name, p.v[0])', p['name'] + b' ' + g(p['v'][0])),
        # a ref struct parameter: field stores change the caller's variable at once (8.3)
        ('var r = mk("r", 3)', None),
        ('bump(ref r)', None),
        ('pp(r)', pp(r)),
        # an if expression of a struct (6.10), then its copy written: the selected value unchanged
        ('let k = 2', None),
        ('let c = if k > 5 { r } else { q }', None),
        ('var c2 = c', None),
        ('c2.v[0] = 100.0', None),
        ('c2.lim.hi = -3.0', None),
        ('pp(c)', pp(c)),
        ('pp(c2)', pp(c2)),
        # a whole struct assigned through a ref parameter
        ('reset(ref r, 4)', None),
        ('pp(r)', pp(z)),
        # an empty struct (L-h): its literal, an E[] of 3 elements, filled, an element loop, a store
        ('let e = E {}', None),
        ('let es = [E {}, E {}, E {}]', None),
        ('var ne = 0', None),
        ('for x in es {\n    ne += 1\n}', None),
        ('let ef = filled(e, 2)', None),
        ('var ev = es', None),
        ('ev[1] = takeE(es[2])', None),
        ('ev = [ev, E {}]', None),
        (r'printf("%d %d %d %d\n", len(es), ne, len(ef), len(ev))', b'3 3 2 4'),
    ]
    prog('struct_basic', ['every field kind (f64, i64, bool, str, a dynamic array, a fixed array, a str[], a nested',
                          'struct); a literal in another order than the declaration, its values evaluated in source',
                          'order; field reads and writes (scalar, +=, str, nested, element, range, whole struct',
                          'field); struct parameters and results, two struct results, ref struct parameters, an if',
                          'expression of a struct, value semantics; an empty struct (LANGUAGE.md 4.6, 5.5, 6.8, 6.10,',
                          '7.3, 8.2-8.4; DESIGN.md 3.5.5; lead decision L-h)'], [], steps, fns, head)


struct_basic()


# ============================================================ struct_arrays (4.7, 5.2, 5.5, 7.5, 8.3, 10.2)
def struct_arrays():
    head = r'''struct Dim {
    name: str
    nom: f64
    tol: f64
    sign: i64
    v: f64[]
}
'''
    fns = r'''fn pd(q: Dim) {
    printf("%s %g %g %d", q.name, q.nom, q.tol, q.sign)
    for x in q.v {
        printf(" %g", x)
    }
    printf("\n")
}
fn scale(ref x: f64, k: f64) {
    x = x * k
}
fn app(ref s: str, t: str) {
    s += t
}
fn sumnom(ds: Dim[3]) -> f64 {
    return ds[0].nom + ds[1].nom + ds[2].nom
}
fn rename(ref ds: Dim[3], k: i64, s: str) {
    ds[k].name = s
}
fn top2(ds: Dim[]) -> Dim[2] {
    return [ds[1], ds[0]]
}
'''

    def D(name, nom, tol, sg, v):
        return {'name': name, 'nom': nom, 'tol': tol, 'sign': sg, 'v': list(v)}

    def pd(q):
        return (b' '.join([q['name'], g(q['nom']), g(q['tol']), d(q['sign'])]) +
                b''.join(b' ' + g(x) for x in q['v']))

    steps = []

    def S(code, out=None):
        steps.append((code, out))

    # Appendix D's literal style: one Dim per line, aligned, a trailing comma, an untyped 4 into an
    # f64 field (4.2 (b)), [] into a dynamic array field (6.9)
    dims = [D(b'housing', 1.5, 0.25, 1, [1.0, 2.0]),
            D(b'gasket', 2.5, 0.5, -1, [3.0]),
            D(b'ring', 4.0, 0.125, 1, [])]
    S('var dims = [\n'
      '    Dim { name: "housing", nom: 1.5,  tol: 0.25,  sign: 1,  v: [1.0, 2.0] },\n'
      '    Dim { name: "gasket",  nom: 2.5,  tol: 0.5,   sign: -1, v: [3.0] },\n'
      '    Dim { name: "ring",    nom: 4,    tol: 0.125, sign: 1,  v: [] },\n'
      ']')
    # the i64 sign converted in sign * nom (4.2 (a))
    S('for k in 0..len(dims) {\n    printf("%s %g\\n", dims[k].name, dims[k].sign * dims[k].nom)\n}',
      b'\n'.join(q['name'] + b' ' + g(float(q['sign']) * q['nom']) for q in dims))
    # writes through elements, while a copy shares the array (rule 19's copy-on-write chain through
    # the element and its array field: the copy is unchanged)
    snap = cp(dims)
    S('let snap = dims')
    dims[1]['nom'] = 3.25
    S('dims[1].nom = 3.25')
    dims[2]['name'] = b'RING'
    S('dims[2].name = "RING"')
    dims[0]['v'][1] = 7.0
    S('dims[0].v[1] = 7.0')
    S(r'printf("%g %g %s %s %g %g\n", snap[1].nom, dims[1].nom, snap[2].name, dims[2].name, snap[0].v[1], '
      r'dims[0].v[1])',
      b' '.join([g(snap[1]['nom']), g(dims[1]['nom']), snap[2]['name'], dims[2]['name'],
                 g(snap[0]['v'][1]), g(dims[0]['v'][1])]))
    # a whole element stored
    p = D(b'new', 0.75, 0.0625, -1, [5.0, 6.0])
    S('let p = Dim { name: "new", nom: 0.75, tol: 0.0625, sign: -1, v: [5.0, 6.0] }')
    dims[2] = cp(p)
    S('dims[2] = p')
    S('pd(dims[2])', pd(dims[2]))
    # projections (4.7): f64, str and i64 fields; of a selection (a range, an index vector)
    S('pf(dims.nom)', pf([q['nom'] for q in dims]))
    S('ps(dims.name)', ps([q['name'] for q in dims]))
    S('pvi(dims.sign)', pvi([q['sign'] for q in dims]))
    S('pf(dims[0..2].nom)', pf([q['nom'] for q in dims[0:2]]))
    S('ps(dims[[2, 0]].name)', ps([dims[2]['name'], dims[0]['name']]))
    S('pf(snap.tol)', pf([q['tol'] for q in snap]))
    # a fixed-size Dim[3] (by annotation, with its run-time check), its projection, a Dim[3]
    # parameter, a ref Dim[3] parameter, a Dim[2] result
    fd = cp(dims)
    S('let fd: Dim[3] = dims')
    S('pf(fd.tol)', pf([q['tol'] for q in fd]))
    S(r'printf("%g\n", sumnom(fd))', g(fd[0]['nom'] + fd[1]['nom'] + fd[2]['nom']))
    fv = cp(dims)
    S('var fv: Dim[3] = dims')
    fv[1]['name'] = b'B2'
    S('rename(ref fv, 1, "B2")')
    S('ps(fv.name)', ps([q['name'] for q in fv]))
    S('ps(dims.name)', ps([q['name'] for q in dims]))
    t2 = [cp(dims[1]), cp(dims[0])]
    S('let t2 = top2(dims)')
    S(r'printf("%d %s %s\n", len(t2), t2[0].name, t2[1].name)',
      b'%d ' % len(t2) + t2[0]['name'] + b' ' + t2[1]['name'])
    # filled with a struct value (10.2), element loops (7.5)
    fl = [D(b'f', 0.5, 0.0, 1, [1.0]) for _ in range(2)]
    S('let fl = filled(Dim { name: "f", nom: 0.5, tol: 0.0, sign: 1, v: [1.0] }, 2)')
    S('for q in fl {\n    pd(q)\n}', b'\n'.join(pd(q) for q in fl))
    S('for q in dims {\n    pd(q)\n}', b'\n'.join(pd(q) for q in dims))
    # a selection of elements is a Dim[] value (a copy)
    sel = cp(dims[0:2])
    S('let sel = dims[0..2]')
    S(r'printf("%d %s %g\n", len(sel), sel[1].name, sel[0].v[1])',
      b'%d ' % len(sel) + sel[1]['name'] + b' ' + g(sel[0]['v'][1]))
    # ref arguments: a field of an element, a field of a struct local (8.3)
    dims[1]['nom'] = dims[1]['nom'] * 2.0
    S('scale(ref dims[1].nom, 2.0)')
    dims[0]['name'] += b'!'
    S('app(ref dims[0].name, "!")')
    s = cp(dims[0])
    S('var s = dims[0]')
    s['name'] += b'?'
    S('app(ref s.name, "?")')
    S(r'printf("%g %s %s %g\n", dims[1].nom, dims[0].name, s.name, sel[1].nom)',
      b' '.join([g(dims[1]['nom']), dims[0]['name'], s['name'], g(sel[1]['nom'])]))
    prog('struct_arrays', ['arrays of structs: Appendix D\'s literal style, dims[k].f read and written, an array field\'s',
                           'element written while a copy shares the array, a whole element stored, projections',
                           '(f64, str, i64; of a range and an index-vector selection; of a fixed Dim[3]), Dim[3]',
                           'parameters (also ref) and a Dim[2] result, filled with a struct, element loops, a selection',
                           'of elements, ref arguments of fields (LANGUAGE.md 4.5, 4.7, 5.2, 5.5, 6.9, 7.5, 8.3, 10.2)'],
         ['pf', 'pvi', 'ps'], steps, fns, head)


struct_arrays()


# ============================================================ the two dump-adjacent programs of the review
def struct_cow_levels():
    # DESIGN.md 6.2 (4g-2 dumps, L17): two array-field levels whose cows each read the array the
    # cow before left. a and b share everything after `let b = a`; the store into a's innermost
    # element must copy each level on the way down, so b keeps 1 and a has 9 (LANGUAGE.md 4.5).
    head = 'struct T { v: f64[] }\nstruct S { w: T[] }\n'
    steps = [
        ('var a = [S { w: [T { v: [1.0] }] }]', None),
        ('let b = a', None),
        ('a[0].w[0].v[0] = 9.0', None),
        (r'printf("%g %g\n", b[0].w[0].v[0], a[0].w[0].v[0])', b'1 9'),
    ]
    prog('struct_cow_levels', ['two array-field levels under copy on write: a store through a[0].w[0].v[0] while b',
                               'shares a leaves b unchanged (DESIGN.md 6.2 4g-2, L17, R23; LANGUAGE.md 4.5)'],
         [], steps, '', head)


struct_cow_levels()


def struct_field_lim():
    # R19's example: dims[i].lim = Lim { lo: 0.0, hi: 1.0 } stores a struct literal into a struct field
    # of an element (an address that is not fresh); keep shares dims and stays unchanged.
    head = 'struct Lim { lo: f64, hi: f64 }\nstruct Dim { name: str, lim: Lim }\n'
    dims = [{'name': b'a', 'lim': {'lo': 2.0, 'hi': 3.0}}, {'name': b'b', 'lim': {'lo': 4.0, 'hi': 5.0}}]
    keep = cp(dims)
    for q in dims:
        q['lim'] = {'lo': 0.0, 'hi': 1.0}
    dims[1]['lim']['hi'] = 6.5
    out = b'\n'.join(b' '.join([dims[k]['name'], g(dims[k]['lim']['lo']), g(dims[k]['lim']['hi']),
                                g(keep[k]['lim']['lo']), g(keep[k]['lim']['hi'])]) for k in range(2))
    steps = [
        ('var dims = [Dim { name: "a", lim: Lim { lo: 2.0, hi: 3.0 } }, Dim { name: "b", lim: Lim { lo: 4.0, hi: 5.0 } }]',
         None),
        ('let keep = dims', None),
        ('for i in 0..len(dims) {\n    dims[i].lim = Lim { lo: 0.0, hi: 1.0 }\n}', None),
        ('dims[1].lim.hi = 6.5', None),
        ('for k in 0..2 {\n    printf("%s %g %g %g %g\\n", dims[k].name, dims[k].lim.lo, dims[k].lim.hi, '
         'keep[k].lim.lo, keep[k].lim.hi)\n}', out),
    ]
    prog('struct_field_lim', ['dims[i].lim = Lim { lo: 0.0, hi: 1.0 }: a struct literal stored into a struct field of an',
                              'element (DESIGN.md 3.5.9 R19\'s example), then a field of it; the shared copy unchanged'],
         [], steps, '', head)


struct_field_lim()


# ============================================================ str_fixed (4.5, 6.2-6.4, 10.6, Decisions 39, 45)
def str_fixed():
    head = 'struct Tri {\n    k: i64\n    names: str[3]\n}\n'
    fns = r'''fn first3(x: str[3]) -> str {
    return x[0] + x[1] + x[2]
}
fn mk3(a: str) -> str[3] {
    return [a, a + a, "z"]
}
fn setmid(ref x: str[3], s: str) {
    x[1] = s
}
fn pair() -> (str[3], i64) {
    return (["p", "q", "r"], 3)
}
'''
    base = [b'c', b'a', b'b']
    a = list(base)
    m = [b'x', b'y', b'w']
    m[0] = b'X'
    m[2] += b'!'
    m[1] = b'mid'
    srt = sorted(a)
    desc_m = sorted(m, reverse=True)       # no ties, so the stable descending order is the reverse
    assert len(set(m)) == 3
    arg = sorted(range(3), key=lambda i: a[i])
    mm = list(m)
    mm[0] = b'changed'
    t3 = [b'k', b'kk', b'z']
    tri = {'k': 1, 'names': list(a)}
    tri['names'][2] = b'Z'
    M = [[b'a', b'b'], [b'c', b'd']]
    MT = [[M[j][i] for j in range(2)] for i in range(2)]
    steps = [
        # str[3] by annotation from a dynamic str[] (fix, with its run-time check: 3 = 3)
        ('let base = ["c", "a", "b"]', None),
        ('let a: str[3] = base', None),
        ('ps(a)', ps(a)),
        # a var str[3] from a literal; element stores (=, +=), a ref str[3] parameter
        ('var m: str[3] = ["x", "y", "w"]', None),
        ('m[0] = "X"', None),
        ('m[2] += "!"', None),
        ('setmid(ref m, "mid")', None),
        ('ps(m)', ps(m)),
        # dyn: a str[3] into a str[] binding; an element loop over a str[3]
        ('let dd: str[] = m', None),
        ('ps(dd)', ps(m)),
        ('for s in m {\n    printf("<%s>", s)\n}\nprintf("\\n")', b''.join(b'<' + s + b'>' for s in m)),
        # sort and argsort of a fixed-size str[3]: a dynamic result (Decision 39), reassigned longer
        ('ps(sort(a))', ps(srt)),
        ('ps(sort(m, desc: true))', ps(desc_m)),
        ('pvi(argsort(a))', b'3:' + b''.join(b' %d' % k for k in arg)),
        ('var srt = sort(a)', None),
        ('srt = [srt, "d"]', None),
        ('ps(srt)', ps(srt + [b'd'])),
        # element-wise operators on a fixed-size operand (Decision 45): + with a str either side, ==
        # with a str, < of two str[3]
        ('ps(a + "!")', ps([s + b'!' for s in a])),
        ('ps("<" + m)', ps([b'<' + s for s in m])),
        ('pvb(a == "a")', pvb([s == b'a' for s in a])),
        ('pvb(a < m)', pvb([x < y for x, y in zip(a, m)])),
        # a str[3] parameter, a str[3] result (fix of the returned literal), a tuple component
        (r'printf("%s\n", first3(a))', b''.join(a)),
        ('let t3 = mk3("k")', None),
        ('ps(t3)', ps(t3)),
        ('let (pq, n) = pair()', None),
        (r'printf("%s %s %s %d\n", pq[0], pq[1], pq[2], n)', b'p q r 3'),
        # value semantics of a str[3] copy
        ('var mm = m', None),
        ('mm[0] = "changed"', None),
        ('ps(m)', ps(m)),
        ('ps(mm)', ps(mm)),
        # a str[3] struct field
        ('var tri = Tri { k: 1, names: a }', None),
        ('tri.names[2] = "Z"', None),
        ('ps(tri.names)', ps(tri['names'])),
        ('ps(a)', ps(a)),
        # a fixed-size str matrix: fix of a str[,] literal, dyn into a str[,] parameter, .T
        ('let M: str[2,2] = ["a", "b"; "c", "d"]', None),
        ('pms(M)', pms(M)),
        ('pms(M.T)', pms(MT)),
        (r'printf("%s %d\n", M[1, 0], len(M.flat))', b'c 4'),
    ]
    prog('str_fixed', ['fixed-size str arrays: str[3] by annotation (fix with its run-time check), element stores,',
                       'a ref str[3] parameter, dyn into str[], an element loop, sort and argsort of a str[3] (a',
                       'dynamic result, Decision 39), element-wise + == < on a str[3] (Decision 45), str[3]',
                       'parameters, results and tuple components, value semantics, a str[3] struct field, a',
                       'str[2,2] (LANGUAGE.md 4.5, 6.2-6.4, 10.6)'], ['ps', 'pvi', 'pvb', 'pms'], steps, fns, head)


str_fixed()


# ============================================================ records (4.6 "Anonymous records", Decision 48)
def records():
    r = {'name': b'w5', 'n': 3, 'x': 0.5}
    rv = {'lo': 0.0, 'hi': 1.0}
    rv['hi'] = 2.5
    rv['lo'] += 0.25
    o1 = g(rv['lo']) + b' ' + g(rv['hi'])
    rv = {'lo': -1.0, 'hi': rv['hi']}
    nest = {'name': b'a', 'lim': {'lo': 0.0, 'hi': 1.0}}
    nv = cp(nest)
    nv['lim']['hi'] = 9.0
    nv['name'] += b'b'
    rs = [{'a': 1, 's': b'x'}, {'a': 2, 's': b'y'}, {'a': 3, 's': b'z'}]
    fr = [{'a': 7, 's': b'f'} for _ in range(2)]
    k = 1
    pick = {'a': 10, 's': b'pos'} if k > 0 else {'a': -10, 's': b'neg'}
    rw = cp(rs)
    rw[1]['a'] = 20
    rw[0] = {'a': 100, 's': b'h'}
    rr = {'v': [1.0, 2.0], 'tag': b't'}
    rr2 = cp(rr)
    rr2['v'][1] = 5.0
    steps = [
        # bound with let and read
        ('let r = { name: "w5", n: 3, x: 0.5 }', None),
        (r'printf("%s %d %g\n", r.name, r.n, r.x)', r['name'] + b' ' + d(r['n']) + b' ' + g(r['x'])),
        # a var record: fields assigned (=, +=), the whole record assigned a record of the same type
        ('var rv = { lo: 0.0, hi: 1.0 }', None),
        ('rv.hi = 2.5', None),
        ('rv.lo += 0.25', None),
        (r'printf("%g %g\n", rv.lo, rv.hi)', o1),
        ('rv = { lo: -1.0, hi: rv.hi }', None),
        (r'printf("%g %g\n", rv.lo, rv.hi)', g(rv['lo']) + b' ' + g(rv['hi'])),
        # a record as a field of a record; a copy's nested field written (value semantics)
        ('let nest = { name: "a", lim: { lo: 0.0, hi: 1.0 } }', None),
        ('var nv = nest', None),
        ('nv.lim.hi = 9.0', None),
        ('nv.name += "b"', None),
        (r'printf("%s %g %s %g %g\n", nest.name, nest.lim.hi, nv.name, nv.lim.hi, nv.lim.lo)',
         b' '.join([nest['name'], g(nest['lim']['hi']), nv['name'], g(nv['lim']['hi']), g(nv['lim']['lo'])])),
        # an array literal of records, filled, if arms, projections, an element loop
        ('let rs = [{ a: 1, s: "x" }, { a: 2, s: "y" }, { a: 3, s: "z" }]', None),
        ('let fr = filled({ a: 7, s: "f" }, 2)', None),
        ('let k = 1', None),
        ('let pick = if k > 0 { { a: 10, s: "pos" } } else { { a: -10, s: "neg" } }', None),
        ('pvi(rs.a)', pvi([e['a'] for e in rs])),
        ('ps(rs.s)', ps([e['s'] for e in rs])),
        ('pvi(fr.a)', pvi([e['a'] for e in fr])),
        ('ps(rs[1..3].s)', ps([e['s'] for e in rs[1:3]])),
        (r'printf("%d %s %d\n", pick.a, pick.s, len(rs))', d(pick['a']) + b' ' + pick['s'] + b' 3'),
        ('for e in rs {\n    printf("%d%s ", e.a, e.s)\n}\nprintf("\\n")',
         b''.join(d(e['a']) + e['s'] + b' ' for e in rs)),
        # element fields and whole elements of a var record array; the original unchanged
        ('var rw = rs', None),
        ('rw[1].a = 20', None),
        ('rw[0] = { a: 100, s: "h" }', None),
        ('pvi(rw.a)', pvi([e['a'] for e in rw])),
        ('pvi(rs.a)', pvi([e['a'] for e in rs])),
        # an array field of a record, written through a copy
        ('let rr = { v: [1.0, 2.0], tag: "t" }', None),
        ('var rr2 = rr', None),
        ('rr2.v[1] = 5.0', None),
        (r'printf("%g %g %s\n", rr.v[1], rr2.v[1], rr2.tag)', g(rr['v'][1]) + b' ' + g(rr2['v'][1]) + b' t'),
    ]
    prog('records', ['anonymous records (Decision 48): bound, read, a var record\'s fields assigned and the whole',
                     'record replaced, a nested record, an array literal of records, filled, if arms, projections',
                     '(also of a selection), an element loop, element stores into a record array, an array field',
                     '(LANGUAGE.md 4.6, 4.7, 6.9, 6.10, 7.5, 10.2)'], ['pvi', 'ps'], steps)


records()


# ============================================================ heap_struct_* (rules 15, 16, 19, 27, 31; heap 0)
def heap_struct_temps():
    head = 'struct P {\n    name: str\n    v: f64[]\n    k: i64\n}\n'
    fns = r'''fn mk(s: str, k: i64) -> P {
    return P { name: s + "#", v: filled(f64(k), k), k: k }
}
fn show(p: P) {
    printf("%s %d %d\n", p.name, len(p.v), p.k)
}
fn two(k: i64) -> (P, str) {
    return (mk("t", k), "s" + str(k))
}
fn pick(c: bool, a: P, b: P) -> P {
    return if c { a } else { b }
}
'''
    steps = [
        # a slit argument; a call's struct result used once (as an argument, and for one field)
        ('show(P { name: "lit", v: [1.0], k: 1 })', b'lit 1 1'),
        (r'printf("%d\n", mk("once", 3).k)', b'3'),
        ('show(mk("x", 2))', b'x# 2 2'),
        # f().name (rule 15 (f)) and an element of f().v
        (r'printf("%s %g\n", mk("nm", 1).name, mk("el", 4).v[3])', b'nm# 4'),
        # if expressions of structs in a loop, both arms owned calls; a struct result of an ifx
        ('for i in 0..3 {\n    let q = if i % 2 == 0 { mk("e", i) } else { mk("o", i) }\n    show(q)\n}',
         b'e# 0 0\no# 1 1\ne# 2 2'),
        ('show(pick(false, mk("a", 1), mk("b", 2)))', b'b# 2 2'),
        # a _ component of a struct result; a whole tuple call as a statement
        ('let (_, s1) = two(4)', None),
        (r'printf("%s\n", s1)', b's4'),
        ('two(5)', None),
        ('let _ = mk("gone", 2)', None),
        # filled of an owned struct; its elements share the array field
        ('let fl = filled(mk("fill", 2), 3)', None),
        (r'printf("%d %s %d\n", len(fl), fl[2].name, len(fl[1].v))', b'3 fill# 2'),
        # a struct local replaced in a loop, with break and continue holding struct locals
        ('var acc = mk("acc", 0)', None),
        ('for i in 0..6 {\n    let t = mk("t", i)\n    if i == 1 {\n        continue\n    }\n'
         '    if i == 4 {\n        break\n    }\n    acc = P { name: acc.name + t.name, v: [acc.v, t.v], k: acc.k + t.k }\n}',
         None),
        ('show(acc)', b'acc#t#t#t# 5 5'),
        # projections of owned temporaries
        (r'printf("%d %s\n", len([mk("p", 1), mk("q", 2)].name), [mk("p", 1), mk("q", 2)].name[1])', b'2 q#'),
    ]
    # acc: i = 0 joins t# (v of 0 elements, k 0); 1 skipped; 2 and 3 join (v 2 and 3 elements); 4 breaks
    prog('heap_struct_temps', ['struct temporaries under the heap check: a slit argument, call results used once',
                               '(an argument, a field, f().name, an element of f().v), if expressions of structs, a',
                               '_ component, discarded struct results, filled of an owned struct, a struct local',
                               'replaced in a loop with break and continue, projections of literals of owned values',
                               '(DESIGN.md 3.6.6 rules 15 (f), (g), (j), 16, 19, 27; heap check 0)'], [], steps, fns, head)


heap_struct_temps()


def heap_struct_paths():
    head = 'struct P {\n    name: str\n    v: f64[]\n}\nstruct Q {\n    p: P\n    tags: str[]\n}\n'
    fns = r'''fn two() -> (str, str) {
    return ("L" + "", "R" + "")
}
fn g(ref p: P) -> str {
    p.name = "new" + str(len(p.v))
    p.v = [9.0, 8.0, 7.0]
    return "g" + ""
}
fn f(a: str, b: str) {
    printf("%s %s\n", a, b)
}
fn fv(x: f64, b: str) {
    printf("%g %s\n", x, b)
}
'''
    steps = [
        # (v[i], s.name) = two(): an element target and a field target, both owned str results moved
        ('var v = ["a" + "", "b" + "", "c" + ""]', None),
        ('var s = P { name: "s" + "", v: [1.0, 2.0] }', None),
        ('let i = 1', None),
        ('(v[i], s.name) = two()', None),
        (r'printf("%s %s %s %s\n", v[0], v[1], v[2], s.name)', b'a L c R'),
        ('for k in 0..3 {\n    (v[k], s.name) = two()\n}', None),
        (r'printf("%s %s %s %s\n", v[0], v[1], v[2], s.name)', b'L L L R'),
        # f(s.name, g(ref s)): the field is evaluated before g replaces it (6.8 rule 5; rule 31)
        ('f(s.name, g(ref s))', b'R g'),
        (r'printf("%s %g\n", s.name, s.v[2])', b'new2 7'),
        ('fv(s.v[0], g(ref s))', b'9 g'),
        (r'printf("%s\n", s.name)', b'new3'),
        # nested paths: a struct field of a struct, its array field written while shared
        ('var q = Q { p: s, tags: ["t" + "1"] }', None),
        ('let q0 = q', None),
        ('q.p.v[0] = -1.0', None),
        ('q.p.name += "!"', None),
        ('q.tags[0] += "x"', None),
        ('q.p = P { name: q.p.name + "?", v: q.p.v }', None),
        (r'printf("%s %g %s | %s %g %s | %s %g\n", q.p.name, q.p.v[0], q.tags[0], q0.p.name, q0.p.v[0], '
         r'q0.tags[0], s.name, s.v[0])', b'new3!? -1 t1x | new3 9 t1 | new3 9'),
        # f(ref q.p) through a nested field path
        ('f(q.p.name, g(ref q.p))', b'new3!? g'),
        (r'printf("%s %s\n", q.p.name, q0.p.name)', b'new3 new3'),
        # a struct array whose elements are replaced in a loop, records of owned strings
        ('var ps = [s, s]', None),
        ('for k in 0..2 {\n    ps[k] = P { name: "e" + str(k), v: [f64(k)] }\n    ps[k].name += "!"\n}', None),
        (r'printf("%s %s %g\n", ps[0].name, ps[1].name, ps[1].v[0])', b'e0! e1! 1'),
        ('var rec = { a: "x" + "y", b: [s, s] }', None),
        ('rec.b[1].name = rec.a + "z"', None),
        ('rec.a = "w" + ""', None),
        (r'printf("%s %s %s\n", rec.a, rec.b[0].name, rec.b[1].name)', b'w new3 xyz'),
    ]
    prog('heap_struct_paths', ['struct and field paths under the heap check: (v[i], s.name) = two() with owned str',
                               'results (also in a loop), f(s.name, g(ref s)) and f(s.v[0], g(ref s)) (the field read',
                               'before g replaces it), nested field paths written while shared, a ref argument of a',
                               'nested field, elements of a struct array replaced in a loop, a record holding a struct',
                               'array (LANGUAGE.md 4.5, 6.8 rule 5, 7.3, 8.3; DESIGN.md 3.6.6 rules 15, 16, 19, 31,',
                               'L12, R25; heap check 0)'], [], steps, fns, head)


heap_struct_paths()


# ============================================================ struct_dollar_paths (5.3, 5.4, 5.5, 7.3, 8.3)
def struct_dollar_paths():
    # `$` inside an index of a field path is the extent of the array that index indexes (5.3): the
    # innermost index expression's array, so in a[i].v[$ - 1] it is len(a[i].v), and in
    # m[$ - 1, $ - 2] the row count, then the column count.
    head = r'''struct D {
    name: str
    v: f64[]
    names: str[]
}
struct F {
    w: f64[3]
    m: i64[2,2]
}
struct It {
    v: f64[]
}
struct S {
    items: It[]
}
'''
    fns = r'''fn bumpd(ref ds: D[], i: i64) {
    ds[i].v[$ - 1] += 0.5
    ds[$ - 1].v[0..$ - 1] = -1.0
}
fn pd(q: D) {
    printf("%s", q.name)
    for x in q.v {
        printf(" %g", x)
    }
    printf(" |")
    for s in q.names {
        printf(" [%s]", s)
    }
    printf("\n")
}
fn pit(s: S) {
    for it in s.items {
        printf(" |")
        for x in it.v {
            printf(" %g", x)
        }
    }
    printf("\n")
}
'''

    def D(name, v, names):
        return {'name': name, 'v': list(v), 'names': list(names)}

    def pd(q):
        return q['name'] + b''.join(b' ' + g(x) for x in q['v']) + b' |' + b''.join(b' [' + s + b']'
                                                                                   for s in q['names'])

    def pit(s):
        return b''.join(b' |' + b''.join(b' ' + g(x) for x in it['v']) for it in s['items'])

    steps = []

    def S_(code, out=None):
        steps.append((code, out))

    # a dynamic container (a D[] local), with a copy that must stay unchanged (4.5)
    a = [D(b'p', [1.0, 2.0, 3.0], [b'x', b'y']), D(b'q', [4.0, 5.0], [b'z'])]
    S_('var a = [D { name: "p", v: [1.0, 2.0, 3.0], names: ["x", "y"] }, D { name: "q", v: [4.0, 5.0], names: ["z"] }]')
    keep = cp(a)
    S_('let keep = a')
    i = 1
    S_('let i = 1')
    a[i]['v'][len(a[i]['v']) - 1] = 9.0
    S_('a[i].v[$ - 1] = 9.0')
    v0 = a[0]['v']
    v0[0:len(v0)] = [0.0] * len(v0)
    S_('a[0].v[0..$] = 0.0')
    a[i]['names'][len(a[i]['names']) - 1] += b'!'
    S_('a[i].names[$ - 1] += "!"')
    a[0]['names'][len(a[0]['names']) - 2] = b'X'
    S_('a[0].names[$ - 2] = "X"')
    S_('pd(a[0])', pd(a[0]))
    S_('pd(a[1])', pd(a[1]))
    S_('pd(keep[0])', pd(keep[0]))
    S_('pd(keep[1])', pd(keep[1]))
    # a fixed container: an f64[3] field and an i64[2,2] field ($ the row count, then the column count)
    w = [1.0, 2.0, 3.0]
    m = [[1, 2], [3, 4]]
    S_('var fs = [F { w: [1.0, 2.0, 3.0], m: [1, 2; 3, 4] }, F { w: [0.5, 0.5, 0.5], m: [0, 0; 0, 0] }]')
    fkeep_w, fkeep_m = list(w), [list(r) for r in m]
    S_('let fkeep = fs')
    w[3 - 1] = 30.0
    S_('fs[0].w[$ - 1] = 30.0')
    w[3 - 3] *= 4.0
    S_('fs[0].w[$ - 3] *= 4.0')
    m[2 - 1][2 - 2] = 40
    S_('fs[0].m[$ - 1, $ - 2] = 40')
    m[2 - 2][2 - 1] += 5
    S_('fs[0].m[$ - 2, $ - 1] += 5')
    S_(r'printf("%g %g %g | %d %d %d %d\n", fs[0].w[0], fs[0].w[1], fs[0].w[2], fs[0].m[0, 0], fs[0].m[0, 1], '
       r'fs[0].m[1, 0], fs[0].m[1, 1])',
       b'%s %s %s | %d %d %d %d' % (g(w[0]), g(w[1]), g(w[2]), m[0][0], m[0][1], m[1][0], m[1][1]))
    S_(r'printf("%g %g %g | %d %d %d %d\n", fkeep[0].w[0], fkeep[0].w[1], fkeep[0].w[2], fkeep[0].m[0, 0], '
       r'fkeep[0].m[0, 1], fkeep[0].m[1, 0], fkeep[0].m[1, 1])',
       b'%s %s %s | %d %d %d %d' % (g(fkeep_w[0]), g(fkeep_w[1]), g(fkeep_w[2]), fkeep_m[0][0], fkeep_m[0][1],
                                     fkeep_m[1][0], fkeep_m[1][1]))
    # a ref root (8.3): ds[i].v[$ - 1] += 0.5 and ds[$ - 1].v[0..$ - 1] = -1.0 change the caller's a
    ds = a
    ds[0]['v'][len(ds[0]['v']) - 1] += 0.5
    last = ds[len(ds) - 1]['v']
    last[0:len(last) - 1] = [-1.0] * (len(last) - 1)
    S_('bumpd(ref a, 0)')
    S_('pd(a[0])', pd(a[0]))
    S_('pd(a[1])', pd(a[1]))
    S_('pd(keep[1])', pd(keep[1]))
    # nested two levels: a struct local's element's array, then through two element containers
    s = {'items': [{'v': [1.0, 2.0]}, {'v': [3.0, 4.0, 5.0]}]}
    S_('var s = S { items: [It { v: [1.0, 2.0] }, It { v: [3.0, 4.0, 5.0] }] }')
    it = s['items'][len(s['items']) - 1]
    it['v'][len(it['v']) - 1] = 50.0
    S_('s.items[$ - 1].v[$ - 1] = 50.0')
    S_('pit(s)', pit(s))
    q = [cp(s), {'items': [{'v': [6.0]}, {'v': [7.0, 8.0, 9.0]}]}]
    S_('var q = [s, S { items: [It { v: [6.0] }, It { v: [7.0, 8.0, 9.0] }] }]')
    q0 = cp(q)
    S_('let q0 = q')
    it = q[1]['items'][len(q[1]['items']) - 1]
    it['v'][len(it['v']) - 3] = 70.0
    S_('q[1].items[$ - 1].v[$ - 3] = 70.0')
    it = q[0]['items'][len(q[0]['items']) - 2]
    it['v'][len(it['v']) - 1] += 0.25
    S_('q[0].items[$ - 2].v[$ - 1] += 0.25')
    S_('pit(q[0])', pit(q[0]))
    S_('pit(q[1])', pit(q[1]))
    S_('pit(q0[0])', pit(q0[0]))
    S_('pit(q0[1])', pit(q0[1]))
    S_('pit(s)', pit(s))
    prog('struct_dollar_paths', ['$ in indices under fields of array elements, in assignment targets (= += *=): a',
                                 'dynamic container (v[$ - 1], v[0..$], names[$ - 1] +=) with a copy unchanged; fixed',
                                 'f64[3] and i64[2,2] fields ([$ - 1, $ - 2]); a ref root (ds[i].v[$ - 1] +=,',
                                 'ds[$ - 1].v[0..$ - 1]); nested s.items[$ - 1].v[$ - 1] and q[1].items[$ - 1].v[$ - 3]',
                                 'through two element containers (LANGUAGE.md 4.5, 5.3, 5.5, 7.3, 8.3)'],
         [], steps, fns, head)


struct_dollar_paths()

# `$` of an inner index needs the outer element, so the outer index is checked first (5.3, 5.4, 5.5)
DOL = ('struct D {\n    v: f64[]\n}\n'
       'var a = [D { v: [1.0, 2.0] }, D { v: [3.0] }]\n'
       'printf("start\\n")\n')
err_rt('r_struct_dollar_outer', ['a[5].v[$ - 1] = 1.0 on a D[] of 2: the outer index 5 is checked before the inner $',
                                 '(the extent of a[5].v) is evaluated (LANGUAGE.md 5.3, 5.4, 5.5)'],
       DOL + 'a[5].v[$ - 1] = 1.0\nprintf("%g\\n", a[0].v[0])\n', 'a[5].v',
       b'index 5 out of bounds for dimension 0 of extent 2', b'start\n')
err_rt('r_struct_dollar_inner', ['a[0].v[$] += 1.0: $ is len(a[0].v) = 2, one past the last index, so the read of the',
                                 'compound store fails (LANGUAGE.md 5.3, 5.4, 5.5)'],
       DOL + 'a[0].v[$] += 1.0\nprintf("%g\\n", a[0].v[0])\n', 'a[0].v[$]',
       b'index 2 out of bounds for dimension 0 of extent 2', b'start\n')


# ============================================================ the 4g-2 review's probes (heap check 0)
def heap_struct_ref_elem():
    # ref arguments that are elements of array fields (LANGUAGE.md 8.3: an element or a field, through
    # fields and elements; DESIGN.md 3.6.6 rule 31). Copies taken before must stay unchanged (4.5).
    # The deferred form rs2(ref arr[0].name, ga(ref arr)): the ref argument's index is evaluated at its
    # place, the rest after ga (rule 31 "Deferred ref arguments"): the callee's x names the element of
    # the array ga left in arr (8.3: another name for the caller's variable), so "N" + "gj2".
    head = r'''struct E2 {
    s: str
    v: f64[]
}
struct SF {
    v: f64[2]
    name: str
}
struct SD {
    v: f64[]
    name: str
}
struct Q {
    fp: E2[2]
    ps: E2[]
}
'''
    fns = r'''fn upd(ref x: f64) {
    x = x * 10.0 + 1.0
}
fn rp(ref e: E2) {
    e = E2 { s: e.s + "+", v: [e.v[0], 9.0] }
}
fn rs(ref t: str) {
    t += "#"
}
fn rs2(ref x: str, y: str) {
    x += y
}
fn ga(ref a: SD[]) -> str {
    a = [SD { v: [5.0], name: "N" + "" }]
    let junk = ["j" + "1", "j" + "2"]
    return "g" + junk[1]
}
fn pe(e: E2) {
    printf(" %s", e.s)
    for x in e.v {
        printf(" %g", x)
    }
    printf(" |")
}
fn pq(q: Q) {
    pe(q.fp[0])
    pe(q.fp[1])
    for e in q.ps {
        pe(e)
    }
    printf("\n")
}
'''
    steps = [
        # an element of a fixed f64[2] field, then of a dynamic f64[] field (copy on write: sd0 keeps 2)
        ('var sf = SF { v: [1.0, 2.0], name: "f" + "" }', None),
        ('let sf0 = sf', None),
        ('upd(ref sf.v[1])', None),
        (r'printf("%g %g | %g %g\n", sf.v[0], sf.v[1], sf0.v[0], sf0.v[1])', b'1 21 | 1 2'),
        ('var sd = SD { v: [1.0, 2.0], name: "d" + "" }', None),
        ('let sd0 = sd', None),
        ('upd(ref sd.v[1])', None),
        (r'printf("%g %g | %g %g\n", sd.v[0], sd.v[1], sd0.v[0], sd0.v[1])', b'1 21 | 1 2'),
        # an element of an array field of an element
        ('var arr = [sd0, SD { v: [3.0, 4.0], name: "e" + "" }]', None),
        ('let arr0 = arr', None),
        ('upd(ref arr[0].v[1])', None),
        (r'printf("%g %g | %g %g\n", arr[0].v[1], arr[1].v[1], arr0[0].v[1], arr0[1].v[1])', b'21 4 | 2 4'),
        # whole struct elements of a fixed E2[2] field and of a dynamic E2[] field
        ('var q = Q { fp: [E2 { s: "a" + "", v: [1.0] }, E2 { s: "b" + "", v: [2.0] }], ps: [E2 { s: "c" + "", v: [3.0] }] }',
         None),
        ('let q0 = q', None),
        ('rp(ref q.fp[1])', None),
        ('rp(ref q.ps[0])', None),
        # str fields of elements: q.ps[i].s, then qs[i].fp[0].s through an element container
        ('let i = 0', None),
        ('rs(ref q.ps[i].s)', None),
        ('var qs = [q, q0]', None),
        ('rs(ref qs[i].fp[0].s)', None),
        ('pq(q)', b' a 1 | b+ 2 9 | c+# 3 9 |'),
        ('pq(q0)', b' a 1 | b 2 | c 3 |'),
        ('pq(qs[0])', b' a# 1 | b+ 2 9 | c+# 3 9 |'),
        ('pq(qs[1])', b' a 1 | b 2 | c 3 |'),
        # the deferred form: ga replaces arr (and allocates) before rs2 receives arr[0].name
        ('rs2(ref arr[0].name, ga(ref arr))', None),
        (r'printf("%d %s %g | %s %s\n", len(arr), arr[0].name, arr[0].v[0], arr0[0].name, arr0[1].name)',
         b'1 Ngj2 5 | d e'),
    ]
    prog('heap_struct_ref_elem', ['ref arguments that are elements of array fields: upd(ref s.v[1]) of an f64[2] and of an',
                                  'f64[] field, upd(ref arr[0].v[1]), rp(ref q.fp[1]) and rp(ref q.ps[0]) (whole struct',
                                  'elements), rs(ref q.ps[i].s), rs(ref qs[i].fp[0].s), copies unchanged; the deferred',
                                  'rs2(ref arr[0].name, ga(ref arr)) names the element of the array ga left (LANGUAGE.md',
                                  '4.5, 8.3; DESIGN.md 3.6.6 rule 31; heap check 0)'], [], steps, fns, head)


heap_struct_ref_elem()


def heap_struct_rule12_elem():
    # Reads through an element of a struct array, then a call that replaces the root by ref and then
    # allocates new strings (so a stale read would show freed or reused bytes). Arguments are evaluated
    # left to right (6.8 rule 5) and an ordinary parameter binds the argument's value (8.2), so every
    # callee prints the old value. a[1].name += gs(ref a[1]) reads the old name first and stores into
    # the a[1] that gs left (5.5, 7.3: x op= e reads x before e; the store sees the ref change); the
    # left operand of + is evaluated before the call in its right operand.
    head = r'''struct In {
    t: str
    w: f64[]
}
struct A {
    name: str
    q: In
    fs: str[2]
    v: f64[]
}
'''
    fns = r'''fn mk(n: str) -> A {
    return A { name: n + "", q: In { t: "t" + n, w: [1.0] }, fs: [n + "0", n + "1"], v: [2.0] }
}
fn gsa(ref a: A[]) -> str {
    a = [mk("Z"), mk("Y")]
    let junk = ["j" + "1", "j" + "2", mk("J").name]
    return "ga" + junk[0]
}
fn gs(ref x: A) -> str {
    x = mk("W")
    let junk = "k" + "k"
    return "gs" + junk
}
fn g(ref a: A[]) -> str {
    a[0] = mk("V")
    a = [a[0], mk("U")]
    return "g" + ["h" + "", "i" + ""][1]
}
fn fs(s: str, r: str) {
    printf("%s %s\n", s, r)
}
fn fp(x: A, r: str) {
    printf("%s %s %s %s %g %s\n", x.name, x.q.t, x.fs[0], x.fs[1], x.v[0], r)
}
fn fsa(x: str[2], r: str) {
    printf("%s %s %s\n", x[0], x[1], r)
}
fn fq(x: In, r: str) {
    printf("%s %g %s\n", x.t, x.w[0], r)
}
'''
    reset = 'a = [mk("a"), mk("b")]'
    steps = [
        ('var a = [mk("a"), mk("b")]', None),
        ('fs(a[0].name, gsa(ref a))', b'a gaj1'),
        (r'printf("%s %s\n", a[0].name, a[1].name)', b'Z Y'),
        (reset, None),
        ('fs(a[0].name, gs(ref a[0]))', b'a gskk'),
        (reset, None),
        ('fs(a[0].q.t, gs(ref a[0]))', b'ta gskk'),
        (r'printf("%s %s\n", a[0].name, a[0].q.t)', b'W tW'),
        (reset, None),
        ('fp(a[1], gs(ref a[1]))', b'b tb b0 b1 2 gskk'),
        (reset, None),
        ('fsa(a[0].fs, gs(ref a[0]))', b'a0 a1 gskk'),
        (r'printf("%s %s\n", a[0].fs[0], a[0].fs[1])', b'W0 W1'),
        (reset, None),
        ('fq(a[0].q, g(ref a))', b'ta 1 gi'),
        (r'printf("%s %s %d\n", a[0].name, a[1].name, len(a))', b'V U 2'),
        (reset, None),
        ('a[1].name += gs(ref a[1])', None),
        (r'printf("%s %s %s %s\n", a[0].name, a[1].name, a[1].q.t, a[1].fs[0])', b'a bgskk tW W0'),
        (reset, None),
        ('let t = a[0].name + gsa(ref a)', None),
        (r'printf("%s %s\n", t, a[0].name)', b'agaj1 Z'),
    ]
    prog('heap_struct_rule12_elem', ['reads through an element of a struct array before a call that replaces the root by',
                                     'ref (and then allocates): fs(a[0].name, gsa(ref a)), fs(a[0].name, gs(ref a[0])),',
                                     'fs(a[0].q.t, ...), fp(a[1], gs(ref a[1])), fsa(a[0].fs, ...), fq(a[0].q, g(ref a)),',
                                     'a[1].name += gs(ref a[1]), a[0].name + gsa(ref a): the old values are seen',
                                     '(LANGUAGE.md 5.5, 6.8 rule 5, 7.3, 8.2, 8.3; DESIGN.md 3.6.6 rule 12; heap check 0)'],
         [], steps, fns, head)


heap_struct_rule12_elem()


def struct_tuple_targets():
    # (t1, t2, ...) = f(...): the call first, then each target in order, stored as ti = ri (7.3);
    # targets may be fields, elements of array fields and elements of struct arrays; _ discards.
    head = r'''struct P {
    tag: str
    v: f64[]
}
struct Q {
    n: i64
    m: f64
    fx: f64[2]
    v: f64[]
    fp: P[2]
    ps: P[]
}
'''
    fns = r'''fn r(k: i64) -> (i64, f64) {
    return (k, f64(k) + 0.5)
}
fn rfi(k: i64) -> (f64, i64) {
    return (f64(k) * 2.0, k + 100)
}
fn rff(k: i64) -> (f64, f64) {
    return (f64(k), f64(k) + 0.25)
}
fn r6(k: i64) -> (i64, P[2]) {
    return (k, [P { tag: "f" + str(k), v: [1.0] }, P { tag: "g" + str(k), v: [2.0, 3.0] }])
}
fn t3s(k: i64) -> (i64, str, str) {
    return (k, "s" + str(k), "t" + str(k))
}
fn t3p(k: i64) -> (i64, str, P) {
    return (k, "y" + str(k), P { tag: "p" + str(k), v: [f64(k)] })
}
fn t3v(k: i64) -> (i64, str, f64[]) {
    return (k, "u", [f64(k), f64(k)])
}
fn three() -> (str, f64[], P) {
    return ("T" + "", [7.0, 8.0], P { tag: "W" + "", v: [9.0] })
}
fn pp(p: P) {
    printf(" %s", p.tag)
    for x in p.v {
        printf(" %g", x)
    }
    printf(" |")
}
fn pq(q: Q) {
    printf("%d %g %g %g", q.n, q.m, q.fx[0], q.fx[1])
    for x in q.v {
        printf(" %g", x)
    }
    printf(" :")
    pp(q.fp[0])
    pp(q.fp[1])
    for p in q.ps {
        pp(p)
    }
    printf("\n")
}
'''
    steps = [
        ('var q = Q { n: 0, m: 0.0, fx: [0.0, 0.0], v: [0.0, 0.0], fp: [P { tag: "a", v: [] }, P { tag: "b", v: [] }], '
         'ps: [P { tag: "c", v: [] }, P { tag: "d", v: [] }] }', None),
        ('let q0 = q', None),
        ('var x = 0.0', None),
        ('var xi = 0', None),
        ('(q.n, q.m) = r(3)', None),
        ('pq(q)', b'3 3.5 0 0 0 0 : a | b | c | d |'),
    ]
    steps += [
        ('(q.n, x) = r(4)', None),
        (r'printf("%d %g\n", q.n, x)', b'4 4.5'),
        ('(x, q.n) = rfi(5)', None),
        (r'printf("%g %d\n", x, q.n)', b'10 105'),
        ('(q.fx[0], x) = rff(6)', None),
        ('(q.v[0], x) = rff(7)', None),
        (r'printf("%g %g %g %g\n", q.fx[0], q.fx[1], q.v[0], x)', b'6 0 7 7.25'),
        ('var qa = [q, q0]', None),
        ('(qa[0].n, x) = r(8)', None),
        (r'printf("%d %d %d %g\n", qa[0].n, qa[1].n, q.n, x)', b'8 0 105 8.5'),
        ('(q.n, q.fp) = r6(9)', None),
        ('pq(q)', b'9 3.5 6 0 7 0 : f9 1 | g9 2 3 | c | d |'),
        ('pq(q0)', b'0 0 0 0 0 0 : a | b | c | d |'),
        # three components, the later ones targets: a str element, a struct element, a field of one
        ('var sv = ["e" + "", "f" + ""]', None),
        ('(_, _, sv[0]) = t3s(1)', None),
        (r'printf("%s %s\n", sv[0], sv[1])', b't1 f'),
        ('var ps = [P { tag: "h" + "", v: [1.0] }, P { tag: "i" + "", v: [2.0] }]', None),
        ('let ps0 = ps', None),
        ('(_, _, ps[0]) = t3p(2)', None),
        ('(_, _, ps[1].tag) = t3s(3)', None),
        ('var vs = ps', None),
        ('(_, _, vs[0].v) = t3v(4)', None),
        ('var y = ""', None),
        ('(xi, y, ps[1]) = t3p(5)', None),
        (r'printf("%d %s\n", xi, y)', b'5 y5'),
        ('for p in ps {\n    pp(p)\n}\nprintf("\\n")', b' p2 2 | p5 5 |'),
        ('for p in vs {\n    pp(p)\n}\nprintf("\\n")', b' p2 4 4 | t3 2 |'),
        ('for p in ps0 {\n    pp(p)\n}\nprintf("\\n")', b' h 1 | i 2 |'),
        ('(q.ps[0].tag, q.ps[0].v, q.ps[1]) = three()', None),
        ('pq(q)', b'9 3.5 6 0 7 0 : f9 1 | g9 2 3 | T 7 8 | W 9 |'),
        ('pq(qa[1])', b'0 0 0 0 0 0 : a | b | c | d |'),
    ]
    prog('struct_tuple_targets', ['tuple assignments to field and element targets: (q.n, q.m), (q.n, x), (x, q.n),',
                                  '(q.fx[0], x), (q.v[0], x), (qa[0].n, x), (q.n, q.fp) = r6(); three components with',
                                  'later targets (_, _, sv[0]), (_, _, ps[0]), (_, _, ps[1].tag), (_, _, vs[0].v),',
                                  '(xi, y, ps[1]), (q.ps[0].tag, q.ps[0].v, q.ps[1]) = three(); copies unchanged',
                                  '(LANGUAGE.md 4.5, 7.3, 8.4)'], [], steps, fns, head)


struct_tuple_targets()


def struct_str_field_cat():
    # x += e of a str array field is element-wise + (DESIGN.md 2.6.2 "Readings fixed by 4g": `x += e`
    # of a str ... field is + as above; Decision 45): a str[2], a str[], a str[2,2], with a str or a
    # str array of the same shape; through elements and a ref parameter; copies unchanged (4.5).
    head = r'''struct P {
    fs: str[2]
    ds: str[]
}
struct S2 {
    m: str[2,2]
}
'''
    fns = r'''fn rr(ref p: P) {
    p.ds += "R"
}
'''
    steps = [
        ('var p = P { fs: ["a", "b"], ds: ["c", "d", "e"] }', None),
        ('let p0 = p', None),
        ('p.fs += "z"', None),
        ('p.ds += "z"', None),
        ('var m: str[2] = ["1", "2"]', None),
        ('p.fs += m', None),
        ('rr(ref p)', None),
        ('ps(p.fs)', ps([b'az1', b'bz2'])),
        ('ps(p.ds)', ps([b'czR', b'dzR', b'ezR'])),
        ('ps(p0.fs)', ps([b'a', b'b'])),
        ('ps(p0.ds)', ps([b'c', b'd', b'e'])),
        ('var a = [P { fs: ["x", "y"], ds: ["p", "q"] }, P { fs: ["u", "v"], ds: ["r", "s"] }]', None),
        ('let a0 = a', None),
        ('a[1].ds += a[0].ds', None),
        ('a[0].fs += "z"', None),
        ('ps(a[0].fs)', ps([b'xz', b'yz'])),
        ('ps(a[1].ds)', ps([b'rp', b'sq'])),
        ('ps(a[0].ds)', ps([b'p', b'q'])),
        ('ps(a0[0].fs)', ps([b'x', b'y'])),
        ('ps(a0[1].ds)', ps([b'r', b's'])),
        ('var s = S2 { m: ["a", "b"; "c", "d"] }', None),
        ('let s0 = s', None),
        ('s.m += "y"', None),
        ('pms(s.m)', pms([[b'ay', b'by'], [b'cy', b'dy']])),
        ('pms(s0.m)', pms([[b'a', b'b'], [b'c', b'd']])),
    ]
    prog('struct_str_field_cat', ['element-wise += of str array fields: p.fs += "z" (str[2]), p.ds += "z" (str[]),',
                                  'p.fs += m (a str[2]), p.ds += "R" in fn rr(ref p: P), a[1].ds += a[0].ds,',
                                  'a[0].fs += "z", s.m += "y" (str[2,2]); copies unchanged (LANGUAGE.md 4.5, 6.2, 6.3;',
                                  'Decision 45)'], ['ps', 'pms'], steps, fns, head)


struct_str_field_cat()


# ============================================================ run-time error (4.5)
err_rt('r_str_fix', ['a str[] of 2 elements bound to a str[3]: the run-time check of fix (LANGUAGE.md 4.5)'],
       'let v = ["a", "b"]\nprintf("before\\n")\nlet a: str[3] = v\nprintf("%s\\n", a[0])\n', 'let a:',
       b'shape mismatch: expected 3, got 2', b'before\n')

# ============================================================ compile errors (DESIGN.md 2.6.2)
TM = 'type mismatch: expected %s, found %s'
SP = 'struct P {\n    x: f64\n    y: f64\n}\n'
DIMS = ('struct Lim { lo: f64, hi: f64 }\n'
        'struct Dim {\n    name: str\n    nom: f64\n    v: f64[]\n    lim: Lim\n}\n'
        'var dims = [Dim { name: "a", nom: 1.0, v: [1.0], lim: Lim { lo: 0.0, hi: 1.0 } }]\n')

err_c('err_struct_missing_field', ['a struct literal without a field: missing field (204) at the slit, the type name',
                                   '(LANGUAGE.md 4.6; DESIGN.md 2.6.2)'],
      SP + 'let p = P { x: 1.0 }\n', 'let p', 'P {', "missing field 'y' in P literal")
err_c('err_struct_dup_field', ['a field initialised twice in a struct literal: duplicate field (205) at the second init',
                               '(LANGUAGE.md 4.6)'],
      SP + 'let p = P { x: 1.0, y: 2.0, x: 3.0 }\n', 'let p', 'x:', 'duplicate field', last=True)
err_c('err_struct_unknown_field', ['a struct literal naming no field of the struct: unknown field (206) at that init',
                                   '(LANGUAGE.md 4.6)'],
      SP + 'let p = P { x: 1.0, y: 2.0, z: 3.0 }\n', 'let p', 'z:', 'unknown field')
err_c('err_record_dup_field', ['a name given twice in a record literal: duplicate field (205) at the second init (lead',
                               'decision L-b)'],
      'let r = { a: 1, b: 2, a: 3 }\n', 'let r', 'a:', 'duplicate field', last=True)
err_c('err_record_reserved', ['a record literal field named flat: field name reserved for views (222) at its init',
                              '(LANGUAGE.md 4.6; lead decision L-b)'],
      'let r = { a: 1, flat: 2 }\n', 'let r', 'flat', 'field name reserved for views')
err_c('err_struct_recursive', ['a struct with a field of its own type: recursive struct (221) at the struct item',
                               '(LANGUAGE.md 4.6; DESIGN.md 3.4.2)'],
      'struct P {\n    x: f64\n    q: P\n}\n', 'struct P', 'struct', 'recursive struct')
err_c('err_struct_recursive_vec', ['recursion through a dynamic array field P[]: recursive struct (221; DESIGN.md 3.4.2)'],
      'struct P {\n    x: f64\n    kids: P[]\n}\n', 'struct P', 'struct', 'recursive struct')
err_c('err_struct_recursive_fixed', ['recursion through a fixed array field P[2]: recursive struct (221; DESIGN.md',
                                     '3.4.2)'],
      'struct P {\n    pair: P[2]\n}\n', 'struct P', 'struct', 'recursive struct')
err_c('err_struct_recursive_mutual', ['two structs containing each other (B through an A[] field): both are recursive;',
                                      'the first in source order is reported (221; DESIGN.md 3.4.2)'],
      'struct A {\n    b: B\n}\nstruct B {\n    as: A[]\n}\n', 'struct A', 'struct', 'recursive struct')
err_c('err_struct_reserved', ['a struct field named T: field name reserved for views (222) at the field (LANGUAGE.md',
                              '4.6)'],
      'struct P {\n    x: f64\n    T: f64\n}\n', 'T: f64', 'T', 'field name reserved for views')
err_c('err_struct_redef_field', ['two fields of one name: redefinition (235) at the later field (DESIGN.md 2.6.2, 3.4.2)'],
      'struct P {\n    x: f64\n    y: i64\n    x: str\n}\n', 'x: str', 'x', "redefinition of 'x'")
err_c('err_struct_unknown', ['a literal of an undeclared struct type: unknown struct type (229) at the slit (LANGUAGE.md',
                             'Appendix A; DESIGN.md 3.4.2)'],
      'let q = Q { }\n', 'let q', 'Q', 'unknown struct type')
err_c('err_struct_assign_let', ['a field of a let struct assigned: cannot assign to immutable (238) at the target',
                                '(DESIGN.md 2.6.2 "Readings fixed by 4g")'],
      SP + 'let p = P { x: 1.0, y: 2.0 }\np.x = 3.0\n', 'p.x =', 'p', "cannot assign to immutable 'p'")
err_c('err_struct_assign_let_elem', ['an element\'s field of a let array assigned: 238 at the target, naming the root',
                                     '(DESIGN.md 2.6.2 "Readings fixed by 4g")'],
      SP + 'let a = [P { x: 1.0, y: 2.0 }]\na[0].y = 3.0\n', 'a[0].y', 'a', "cannot assign to immutable 'a'")
err_c('err_struct_proj_target', ['a projection as an assignment target: invalid assignment target (239) at the target',
                                 '(LANGUAGE.md 4.7)'],
      DIMS + 'let nv = [2.0]\ndims.nom = nv\n', 'dims.nom =', 'dims', 'invalid assignment target')
err_c('err_struct_eq', ['two structs compared with ==: operator cannot be applied (240) at the operator node, its left',
                        'operand (LANGUAGE.md 4.6; DESIGN.md 3.3)'],
      SP + 'let p = P { x: 1.0, y: 2.0 }\nlet q = p\nlet same = p == q\n', 'let same', 'p ==',
      "operator '==' cannot be applied to P and P")
err_c('err_struct_no_field', ['a field the struct does not have: no field (249) at the dot, its operand (DESIGN.md 3.3)'],
      SP + 'let p = P { x: 1.0, y: 2.0 }\nlet z = p.z\n', 'p.z', 'p.z', "no field 'z' in P")
err_c('err_struct_mat_field', ['.x of a matrix of structs: no field with the matrix type (249; LANGUAGE.md 4.7, lead',
                               'decision L-c)'],
      SP + 'let M = [P { x: 1.0, y: 2.0 }, P { x: 3.0, y: 4.0 }; P { x: 5.0, y: 6.0 }, P { x: 7.0, y: 8.0 }]\n'
      'let xs = M.x\n', 'let xs', 'M.x', "no field 'x' in P[,]")
err_c('err_record_no_field', ['a field a record does not have: no field (249), the record type spelled {name: T, ...}',
                              '(DESIGN.md 2.6.2 text)'],
      'let r = { a: 1, s: "x" }\nlet b = r.b\n', 'let b', 'r.b', "no field 'b' in {a: i64, s: str}")
err_c('err_struct_proj_array', ['the projection of a field of array type: cannot project (256; LANGUAGE.md 4.7)'],
      DIMS + 'let vs = dims.v\n', 'let vs', 'dims', "cannot project field 'v' of type f64[]")
err_c('err_struct_proj_struct', ['the projection of a field of struct type: cannot project (256; LANGUAGE.md 4.7)'],
      DIMS + 'let ls = dims.lim\n', 'let ls', 'dims', "cannot project field 'lim' of type Lim")
err_c('err_record_into_struct', ['a record where a struct is expected: type mismatch (201) at the value, the record spelled',
                                 '{a: i64} (DESIGN.md 2.6.2 "Readings fixed by 4g", Decision 48)'],
      SP + 'let p: P = { a: 1 }\n', 'let p', '{', TM % ('P', '{a: i64}'))
err_c('err_record_arg_struct', ['a record passed to a struct parameter, even with the struct\'s field names and types:',
                                'type mismatch (201) at the argument (Decision 48: records are not structs)'],
      SP + 'fn f(p: P) -> f64 {\n    return p.x\n}\nprintf("%g\\n", f({ x: 1.0, y: 2.0 }))\n', 'printf',
      '{', TM % ('P', '{x: f64, y: f64}'))

# ============================================================ the goldens step 4g-2 retires (DESIGN.md 6.2)
for old in ('err_ns_struct', 'err_ns_record', 'err_ns_str_fixed_type', 'err_ns_str_fixed_let'):
    for ext_ in ('.sea', '.err', '.status', '.out'):
        remove(os.path.join(ERRORS, old + ext_))

print('struct4g_cases: %d programs, %d errors' % (COUNT['programs'], COUNT['errors']))
