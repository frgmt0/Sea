# tools/math_tables.py -- generator of include/math_tables.inc (Sea DESIGN.md 4.10.3, 4.10.6).
#
# usage: uv run --with mpmath python tools/math_tables.py [--check] [--out FILE]
#
# Computes every constant and table entry of the elementary functions from its definition in
# DESIGN.md 4.10.3 and 4.10.4 with mpmath at 600 bits, rounds it as stated there (to nearest,
# ties to even), and writes include/math_tables.inc. With --check it writes nothing: it compares
# the recomputed file with the committed one and every value with the patterns written in
# DESIGN.md (the constant table, the spot values, the 2/pi words), and exits 1 on any
# difference. A developer tool: the build and the tests read only the committed file.
import os
import struct
import sys

import mpmath as mp

mp.mp.prec = 600
M64 = (1 << 64) - 1
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_OUT = os.path.join(ROOT, 'include', 'math_tables.inc')


def f2u(x):
    return struct.unpack('<Q', struct.pack('<d', x))[0]


def u2f(u):
    return struct.unpack('<d', struct.pack('<Q', u & M64))[0]


def rnb(v, bits):
    """v rounded to `bits` significant bits, nearest even (bits <= 53: exact as a float)."""
    with mp.workprec(bits):
        r = +mp.mpf(v)
    return float(r)


def rn53(v):
    return rnb(v, 53)


def rngrid(v, e):
    """v rounded to the nearest multiple of 2^-e, ties to even."""
    s = mp.mpf(v) * mp.mpf(2) ** e
    fl = mp.floor(s)
    d = s - fl
    n = int(fl)
    if d > mp.mpf(1) / 2 or (d == mp.mpf(1) / 2 and n % 2 == 1):
        n += 1
    return float(mp.mpf(n) / mp.mpf(2) ** e)


LN2 = mp.log(2)
PIO2 = mp.pi / 2


# ---- constants of DESIGN.md 4.10.4, in the order of the sea_mt_const words -------------
def constants():
    ln2hi_n = rnb(LN2 / 128, 35)
    ln2hi = rngrid(LN2, 42)
    p1 = rnb(PIO2, 30)
    p2 = rnb(PIO2 - mp.mpf(p1), 30)
    p3 = rnb(PIO2 - mp.mpf(p1) - mp.mpf(p2), 30)
    p4 = rn53(PIO2 - mp.mpf(p1) - mp.mpf(p2) - mp.mpf(p3))
    pio2hi = rn53(PIO2)
    one = mp.mpf(1)
    c = [
        ('EXP_INVLN2N', rn53(128 / LN2)),
        ('EXP_SHIFT', 1.5 * 2.0 ** 52),
        ('EXP_NLN2HI_N', -ln2hi_n),
        ('EXP_NLN2LO_N', -rn53(LN2 / 128 - mp.mpf(ln2hi_n))),
        ('EXP_C2', 0.5),
        ('EXP_C3', rn53(one / 6)),
        ('EXP_C4', rn53(one / 24)),
        ('EXP_C5', rn53(one / 120)),
        ('LOG_LN2HI', ln2hi),
        ('LOG_LN2LO', rn53(LN2 - mp.mpf(ln2hi))),
        ('LOG_A3', rn53(one / 3)),
        ('LOG_A4', -0.25),
        ('LOG_A5', rn53(one / 5)),
        ('LOG_A6', rn53(-one / 6)),
        ('LOG_A7', rn53(one / 7)),
        ('LOG_A8', -0.125),
        ('LOG_A9', rn53(one / 9)),
        ('TRIG_INVPIO2', rn53(2 / mp.pi)),
        ('TRIG_P1', p1),
        ('TRIG_P2', p2),
        ('TRIG_P3', p3),
        ('TRIG_P4', p4),
        ('TRIG_PIO2_HI', pio2hi),
        ('TRIG_PIO2_LO', rn53(PIO2 - mp.mpf(pio2hi))),
        ('TRIG_S3', rn53(-one / 6)),
        ('TRIG_S5', rn53(one / 120)),
        ('TRIG_S7', rn53(-one / 5040)),
        ('TRIG_C2', -0.5),
        ('TRIG_C4', rn53(one / 24)),
        ('TRIG_C6', rn53(-one / 720)),
        ('SPLIT', 134217729.0),
        ('NAN', None),
    ]
    out = []
    for name, v in c:
        out.append((name, 0x7FF8000000000000 if v is None else f2u(v)))
    return out


# ---- tables of DESIGN.md 4.10.3 -----------------------------------------------------------
LOG_OFF = 0x3FE5F00000000000


def exp_table():
    recs = []
    for i in range(128):
        t = mp.mpf(2) ** (mp.mpf(i) / 128)
        th = rn53(t)
        tail = rn53((t - mp.mpf(th)) / mp.mpf(th))
        recs.append((f2u(tail), (f2u(th) - (i << 45)) & M64))
    return recs


def log_table():
    recs = []
    for i in range(128):
        lo = LOG_OFF + (i << 45)
        hi = LOG_OFF + ((i + 1) << 45)
        if lo <= 0x3FF0000000000000 < hi:
            recs.append((f2u(1.0), 0, 0))
            continue
        c = (mp.mpf(u2f(lo)) + mp.mpf(u2f(hi))) / 2
        invc = rnb(1 / c, 26)
        L = -mp.log(mp.mpf(invc))
        lh = rngrid(L, 42)
        ll = rn53(L - mp.mpf(lh))
        recs.append((f2u(invc), f2u(lh), f2u(ll)))
    return recs


def trig_table():
    recs = []
    for j in range(52):
        a = mp.mpf(j) / 64
        s, c = mp.sin(a), mp.cos(a)
        sh, ch = rn53(s), rn53(c)
        recs.append((f2u(sh), f2u(rn53(s - mp.mpf(sh))), f2u(ch), f2u(rn53(c - mp.mpf(ch)))))
    return recs


def tpi_table():
    with mp.workprec(1600):
        total = int(mp.floor(2 / mp.pi * mp.mpf(2) ** 1216))
    return [(total >> (64 * (19 - w))) & M64 for w in range(20)]


# ---- the patterns written in DESIGN.md 4.10.3 / 4.10.4 (checked by --check) ---------------
SPEC_CONST = {
    'EXP_INVLN2N': 0x40671547652B82FE, 'EXP_SHIFT': 0x4338000000000000,
    'EXP_NLN2HI_N': 0xBF762E42FEFC0000, 'EXP_NLN2LO_N': 0x3D3C610CA86C3899,
    'EXP_C2': 0x3FE0000000000000, 'EXP_C3': 0x3FC5555555555555, 'EXP_C4': 0x3FA5555555555555,
    'EXP_C5': 0x3F81111111111111, 'LOG_LN2HI': 0x3FE62E42FEFA3800, 'LOG_LN2LO': 0x3D2EF35793C76730,
    'LOG_A3': 0x3FD5555555555555, 'LOG_A4': 0xBFD0000000000000, 'LOG_A5': 0x3FC999999999999A,
    'LOG_A6': 0xBFC5555555555555, 'LOG_A7': 0x3FC2492492492492, 'LOG_A8': 0xBFC0000000000000,
    'LOG_A9': 0x3FBC71C71C71C71C, 'TRIG_INVPIO2': 0x3FE45F306DC9C883, 'TRIG_P1': 0x3FF921FB54800000,
    'TRIG_P2': 0xBE0DE973DC800000, 'TRIG_P3': 0xBC19D9CCEB800000, 'TRIG_P4': 0xBA21FC8F8CBB5BF7,
    'TRIG_PIO2_HI': 0x3FF921FB54442D18, 'TRIG_PIO2_LO': 0x3C91A62633145C07,
    'TRIG_S3': 0xBFC5555555555555, 'TRIG_S5': 0x3F81111111111111, 'TRIG_S7': 0xBF2A01A01A01A01A,
    'TRIG_C2': 0xBFE0000000000000, 'TRIG_C4': 0x3FA5555555555555, 'TRIG_C6': 0xBF56C16C16C16C17,
    'SPLIT': 0x41A0000002000000, 'NAN': 0x7FF8000000000000,
}
SPEC_EXP = {0: (0, 0x3FF0000000000000), 1: (0x3C9B3B4F1A88BF6E, 0x3FEFF63DA9FB3335),
            127: (0x3C5305C14160CC89, 0x3FEFF3C22B8F71F1)}
SPEC_LOG = {0: (0x3FF745D178000000, 0xBFD7FAFA45D81000, 0xBD346C979BF72820),
            79: (0x3FF0101010000000, 0xBF70080549580000, 0xBD2166AECB31C67A),
            80: (0x3FF0000000000000, 0, 0),
            81: (0x3FEFC07F00000000, 0x3F7FE02B6B100000, 0x3D19E43F0DDA563A),
            127: (0x3FE767DCE8000000, 0x3FD404307C26A000, 0x3D3F925150499AC3)}
SPEC_TRIG = {0: (0, 0, 0x3FF0000000000000, 0),
             1: (0x3F8FFFAAAAEEEED5, 0xBC02AB639A9F0776, 0x3FEFFF000155549F, 0x3C828A28A03A5EF3),
             51: (0x3FE6E2B77C40BDE1, 0xBC70E729857FAD53, 0x3FE65DC1FDEB8CBA, 0xBC597C1B47337C77)}
SPEC_TPI = [
    0x0000000000000000, 0xA2F9836E4E441529, 0xFC2757D1F534DDC0, 0xDB6295993C439041,
    0xFE5163ABDEBBC561, 0xB7246E3A424DD2E0, 0x06492EEA09D1921C, 0xFE1DEB1CB129A73E,
    0xE88235F52EBB4484, 0xE99C7026B45F7E41, 0x3991D639835339F4, 0x9C845F8BBDF9283B,
    0x1FF897FFDE05980F, 0xEF2F118B5A0A6D1F, 0x6D367ECF27CB09B7, 0x4F463F669E5FEA2D,
    0x7527BAC7EBE5F17B, 0x3D0739F78A5292EA, 0x6BFB5FB11F8D5D08, 0x56033046FC7B6BAB,
]

HEADER = """\
// =====================================================================
// sea/include/math_tables.inc -- constants and tables of the elementary
// functions log exp sin cos pow hypot (Sea DESIGN.md 4.10).
//
// GENERATED by tools/math_tables.py from the definitions of DESIGN.md
// 4.10.3 and 4.10.4; do not edit. `uv run --with mpmath python
// tools/math_tables.py --check` verifies this file.
//
// Shared by Apple as (arm64) and GNU as (x86_64): `//` comments only at
// the start of a line (Baysick DESIGN.md 3.4). Defines the guard and one
// macro, SEA_EMIT_MATH_TABLES, which the including file invokes once in
// its read-only data section. It emits .p2align 6 and then, in order:
//   sea_mt_const   32 words: the constants of DESIGN.md 4.10.4, in order
//   sea_mt_exp     128 records x 2 words: EXP_TAIL, EXP_SBITS
//   sea_mt_log     128 records x 3 words: LOG_INVC, LOG_LOGC_HI, LOG_LOGC_LO
//   sea_mt_trig    52 records x 4 words: TRIG_SH, TRIG_SL, TRIG_CH, TRIG_CL
//   sea_mt_tpi     20 words: floor(2/pi * 2^1216), most significant first
// LINE SHAPES (read by tools/gendata.bas for the mtab block, DESIGN.md
// 2.6.3): a label line is "sea_mt_<name>:" from column 1; a word line is
// four spaces, ".quad 0x" and 16 upper-case hexadecimal digits.
// =====================================================================
"""


def build():
    consts = constants()
    exp, log, trig, tpi = exp_table(), log_table(), trig_table(), tpi_table()
    lines = [HEADER.rstrip('\n'), '.ifndef SEA_MATH_TABLES_INC', '.equiv SEA_MATH_TABLES_INC, 1', '',
             '.macro SEA_EMIT_MATH_TABLES', '    .p2align 6']

    def table(label, words):
        lines.append(label + ':')
        for w in words:
            lines.append('    .quad 0x%016X' % w)

    table('sea_mt_const', [v for _, v in consts])
    table('sea_mt_exp', [w for r in exp for w in r])
    table('sea_mt_log', [w for r in log for w in r])
    table('sea_mt_trig', [w for r in trig for w in r])
    table('sea_mt_tpi', tpi)
    lines += ['.endm', '', '.endif']
    text = '\n'.join(lines) + '\n'
    return text, consts, exp, log, trig, tpi


def check_spec(consts, exp, log, trig, tpi):
    bad = []
    if [n for n, _ in consts] != list(SPEC_CONST):
        bad.append('constant order differs from DESIGN.md 4.10.4')
    for n, v in consts:
        if SPEC_CONST.get(n) != v:
            bad.append('constant %s: computed #%016X, DESIGN.md #%016X' % (n, v, SPEC_CONST.get(n, 0)))
    for name, tab, spec in (('exp', exp, SPEC_EXP), ('log', log, SPEC_LOG), ('trig', trig, SPEC_TRIG)):
        for i, rec in spec.items():
            if tuple(tab[i]) != rec:
                bad.append('%s record %d: computed %s, DESIGN.md %s' % (
                    name, i, ' '.join('#%016X' % w for w in tab[i]), ' '.join('#%016X' % w for w in rec)))
    if tpi != SPEC_TPI:
        bad.append('2/pi words differ from DESIGN.md 4.10.3')
    return bad


def main(argv):
    check = '--check' in argv
    out = DEFAULT_OUT
    if '--out' in argv:
        out = argv[argv.index('--out') + 1]
    text, consts, exp, log, trig, tpi = build()
    bad = check_spec(consts, exp, log, trig, tpi)
    if check:
        try:
            with open(out) as f:
                cur = f.read()
        except OSError as e:
            bad.append('cannot read %s: %s' % (out, e))
            cur = None
        if cur is not None and cur != text:
            bad.append('%s differs from the generator output' % out)
        for b in bad:
            print('math_tables.py: ' + b, file=sys.stderr)
        if bad:
            return 1
        print('math_tables.py: %s matches its definitions and DESIGN.md 4.10' % os.path.relpath(out, ROOT))
        return 0
    if bad:
        for b in bad:
            print('math_tables.py: ' + b, file=sys.stderr)
        return 1
    with open(out, 'w') as f:
        f.write(text)
    print('math_tables.py: wrote %s' % os.path.relpath(out, ROOT))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
