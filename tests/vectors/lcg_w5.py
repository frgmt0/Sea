"""lcg_w5.py -- W5's Park-Miller LCG, exactly, and the phase-1 acceptance test (WP12).

W5 (sea/workloads/w5_tolerance_mc.m) draws every random number from
    s <- mod(16807 * s, 2147483647),  u = s / 2147483647
starting at seed = 7340117, in this order (lcg_fill calls in the script):
    dim 1 normal      2 * nSample      dim 2 triangular  nSample
    dim 3 normal      2 * nSample      dim 4 uniform     nSample   (spacer, tol 0.030)
    dim 5 triangular  nSample          dim 6 normal      2 * nSample
    dim 7 uniform     nSample          (retaining ring, tol 0.030)
    operating temperatures            nSample   Top = Tlo + (Thi - Tlo) * u, Tlo 20, Thi 95
with nSample = 1 000 000: 11 000 000 steps in all; lcg_final is the state after the last one.
The values that depend only on the LCG and on + - * / are the uniform columns of first_dev
(dev = tol * (2 * u - 1)) and first_top; this script computes them with exact integer and
exact IEEE binary64 arithmetic (float_oracle.py), asserts that they equal
sea/workloads/reference/w5_tolerance_mc.json bit for bit, and writes
    tests/programs/op_lcg_w5.sea   (the Sea program, phase-1 subset only)
    tests/programs/op_lcg_w5.out   (its expected output, %.17g digits from progfmt.py)
    tests/vectors/lcg_w5.out       (a copy of the expected output, for the record)

Run:  uv run python tests/vectors/lcg_w5.py
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import float_oracle as fo  # noqa: E402
import progfmt as pf  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
SEA = os.path.dirname(os.path.dirname(HERE))
REF = os.path.join(SEA, "workloads", "reference", "w5_tolerance_mc.json")
PROGRAMS = os.path.join(os.path.dirname(HERE), "programs")

A = 16807
M = 2147483647
SEED = 7340117
N_SAMPLE = 1000000
TOTAL = 11 * N_SAMPLE

F_M = fo.f_from_int_exact(M)
F_TWO = fo.f_from_int_exact(2)
F_ONE = fo.f_from_int_exact(1)
TOL = fo.literal_bits("0.030")
TLO = fo.literal_bits("20.0")
THI = fo.literal_bits("95.0")


def uniform(s):
    """u = s / 2147483647: one IEEE division of two exactly converted integers."""
    return fo.f_div(fo.f_from_int_exact(s), F_M)


def dev_uniform(u):
    """dims(d).tol * (2 * u - 1)"""
    return fo.f_mul(TOL, fo.f_sub(fo.f_mul(F_TWO, u), F_ONE))


def top(u):
    """Tlo + (Thi - Tlo) * u"""
    return fo.f_add(TLO, fo.f_mul(fo.f_sub(THI, TLO), u))


def run():
    starts = {
        "spacer": 2 * N_SAMPLE + N_SAMPLE + 2 * N_SAMPLE,                    # 5 M steps before
        "ring": 2 * N_SAMPLE + N_SAMPLE + 2 * N_SAMPLE + N_SAMPLE + N_SAMPLE
        + 2 * N_SAMPLE,                                                        # 9 M
        "top": 10 * N_SAMPLE,
    }
    first_u, spacer, ring, tops = [], [], [], []
    s = SEED
    for step in range(TOTAL):            # step k (0-based) produces the (k+1)-th state
        s = (A * s) % M
        if step < 10:
            first_u.append(uniform(s))
        k = step - starts["spacer"]
        if 0 <= k < 10:
            spacer.append(dev_uniform(uniform(s)))
        k = step - starts["ring"]
        if 0 <= k < 10:
            ring.append(dev_uniform(uniform(s)))
        k = step - starts["top"]
        if 0 <= k < 10:
            tops.append(top(uniform(s)))
    return s, first_u, spacer, ring, tops


def json_bits(text):
    neg = text.startswith("-")
    t = text[1:] if neg else text
    t = t.replace("E", "e")
    if "." not in t.split("e")[0]:
        mant, _, ex = t.partition("e")
        t = mant + ".0" + ("e" + ex if ex else "")
    b = fo.literal_bits(t.replace("e+", "e"))
    return fo.f_neg(b) if neg else b


def check(final, spacer, ring, tops):
    with open(REF) as f:
        ref = json.load(f, parse_float=str, parse_int=str)
    assert json_bits(ref["lcg_final"]) == fo.f_from_int_exact(final), "lcg_final"
    assert final == 2145635252
    for i in range(10):
        assert json_bits(ref["first_top"][i]) == tops[i], ("first_top", i)
        assert json_bits(ref["first_dev"][i][3]) == spacer[i], ("first_dev spacer", i)
        assert json_bits(ref["first_dev"][i][6]) == ring[i], ("first_dev ring", i)


SEA_SRC = """\
// op_lcg_w5 -- W5's Park-Miller LCG (sea/workloads/w5_tolerance_mc.m, LANGUAGE.md 2.5) for
// exactly W5's 11 M steps, in W5's draw order, with the phase-1 subset only. Prints the first
// ten uniforms, the uniform columns of first_dev and first_top that the reference JSON pins,
// and lcg_final. Expected output: tests/vectors/lcg_w5.py (asserted against
// sea/workloads/reference/w5_tolerance_mc.json bit for bit).

fn next_u(ref s: i64) -> f64 {
    s = 16807 * s % 2147483647
    return s / 2147483647
}

fn skip(ref s: i64, n: i64) {
    for i in 0..n {
        s = 16807 * s % 2147483647
    }
}

let nSample = 1_000_000
let tol = 0.030               // spacer and retaining ring tolerance [mm]
let Tlo = 20.0
let Thi = 95.0
var s = 7_340_117

// dim 1, normal: 2 * nSample draws; the first ten uniforms
for k in 0..10 {
    printf("u[%d] = %.17g\\n", k, next_u(ref s))
}
skip(ref s, 2 * nSample - 10)
skip(ref s, nSample)          // dim 2, triangular
skip(ref s, 2 * nSample)      // dim 3, normal
// dim 4, spacer, uniform: dev = tol * (2 * u - 1)
for k in 0..10 {
    let u = next_u(ref s)
    printf("first_dev[%d][3] = %.17g\\n", k, tol * (2 * u - 1))
}
skip(ref s, nSample - 10)
skip(ref s, nSample)          // dim 5, triangular
skip(ref s, 2 * nSample)      // dim 6, normal
// dim 7, retaining ring, uniform
for k in 0..10 {
    let u = next_u(ref s)
    printf("first_dev[%d][6] = %.17g\\n", k, tol * (2 * u - 1))
}
skip(ref s, nSample - 10)
// operating temperatures
for k in 0..10 {
    let u = next_u(ref s)
    printf("first_top[%d] = %.17g\\n", k, Tlo + (Thi - Tlo) * u)
}
skip(ref s, nSample - 10)
printf("lcg_final = %d\\n", s)
"""


def main():
    final, first_u, spacer, ring, tops = run()
    check(final, spacer, ring, tops)
    lines = []
    g = pf.Spec("%.17g")
    for k, u in enumerate(first_u):
        lines.append("u[%d] = %s" % (k, pf.fmt_float_bits(g, u)))
    for k, v in enumerate(spacer):
        lines.append("first_dev[%d][3] = %s" % (k, pf.fmt_float_bits(g, v)))
    for k, v in enumerate(ring):
        lines.append("first_dev[%d][6] = %s" % (k, pf.fmt_float_bits(g, v)))
    for k, v in enumerate(tops):
        lines.append("first_top[%d] = %s" % (k, pf.fmt_float_bits(g, v)))
    lines.append("lcg_final = %d" % final)
    out = "\n".join(lines) + "\n"
    with open(os.path.join(PROGRAMS, "op_lcg_w5.sea"), "w") as f:
        f.write(SEA_SRC)
    with open(os.path.join(PROGRAMS, "op_lcg_w5.out"), "w") as f:
        f.write(out)
    with open(os.path.join(HERE, "lcg_w5.out"), "w") as f:
        f.write(out)
    print("lcg_w5: lcg_final = %d; first_top and uniform first_dev columns match the "
          "reference JSON bit for bit" % final)


if __name__ == "__main__":
    main()
