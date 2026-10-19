"""Compare MATLAB reference JSON (reference/<name>.json) with the NumPy cross-check
(reference/<name>.py.json), key by key, using the tolerances below.

Usage (from sea/workloads):
    uv run --no-project --with numpy python reference_py/compare.py [name ...]
    uv run --no-project --with numpy python reference_py/compare.py --self-test

Rules (a key not listed uses DEFAULT):
    ("exact",)         strings, booleans, indices: must be identical
    ("int", n)         integer counts: |a - b| <= n
    ("num", atol, rtol) floats: |a - b| <= atol + rtol * max|reference value| (per key; the
                        scale is the largest magnitude in that key, so vectors with values
                        crossing zero are judged relative to their size). NaN/null positions
                        must match.
    ("argmax_tol", arr, rel) / ("argmin_tol", arr, rel)
                       1-based index of the maximum / minimum of the array key `arr`. Two
                       members can tie to within rounding (symmetric structures), so the
                       winner depends on last-bit arithmetic. The NumPy index passes if
                       (a) the MATLAB array's value at that index is within `rel` (relative
                       to the MATLAB extremum) of the MATLAB extremum and (b) the NumPy
                       array's value at its own index is within `rel` of the NumPy extremum.
                       NaN entries are ignored. Use "exact" where the winner is well separated.
    ("small", bound)   noise-level quantities (residuals, balance errors, solver
                        differences): both values must be finite and <= bound in magnitude.
Exit status: 0 if every compared key passes, 1 otherwise. A workload whose MATLAB file does
not exist yet is reported as MISSING and does not fail the run.
"""

import json
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REF_DIR = os.path.join(os.path.dirname(HERE), "reference")

DEFAULT = ("num", 0.0, 1e-9)

RULES = {
    "w1_shaft_design": {
        "workload": ("exact",), "case_label": ("exact",), "case_bearing": ("exact",),
        "case_dReq": ("num", 2e-7, 0.0), "case_iters": ("int", 1),
        "case_dStd": ("exact",), "case_L10h": ("int", 1),
        "mat_dMin": ("num", 3.6e-5, 0.0),          # one sweep step (35 um)
        "grid_d": ("num", 2e-7, 0.0), "grid_d_max": ("num", 2e-7, 0.0),
        "grid_d_min": ("num", 2e-7, 0.0), "grid_iters_total": ("int", 20),
        "grid_yield_fraction": ("num", 3.0 / 10800, 0.0),
        "grid_vec_maxdiff": ("small", 1e-7),
    },
    "w2_truss_fem": {
        "workload": ("exact",), "n_node": ("exact",), "n_elem": ("exact",),
        "fsd_iters": ("int", 2), "fsd_converged": ("exact",),
        "A_fsd": ("num", 0.0, 1e-7), "A_cat": ("exact",),
        "e_crit0": ("argmin_tol", "fos0", 1e-9), "k_worst": ("exact",), "k_fos_worst": ("exact",),
        "r_worst": ("argmax_tol", "util_removed", 1e-9), "mechanism_count": ("exact",),
        "overstressed_count": ("exact",),
        "u0": ("num", 0.0, 1e-8), "N0": ("num", 0.0, 1e-8), "fos0": ("num", 0.0, 1e-8),
        "reactions": ("num", 0.0, 1e-8), "util_removed": ("num", 0.0, 1e-8),
        "infl_defl": ("num", 0.0, 1e-8), "infl_chord": ("num", 0.0, 1e-8),
        "infl_diag": ("num", 0.0, 1e-8),
    },
    "w3_quarter_car": {
        "workload": ("exact",), "i_best": ("exact",), "k_ref": ("exact",),
        "settle": ("num", 1.001e-3, 0.0),          # quantised to the 1 ms step
        "lift_frac": ("num", 2.0 / 7001, 0.0), "bumpstop_frac": ("num", 2.0 / 7001, 0.0),
        "lift_time_bump": ("num", 2.001e-3, 0.0),
        "c_best": ("num", 0.0, 1e-7),
        "ref_zs": ("num", 0.0, 1e-8), "ref_acc": ("num", 0.0, 1e-8),
        "ref_tire": ("num", 0.0, 1e-8), "ref_rough_acc": ("num", 0.0, 1e-8),
        "peak_acc": ("num", 0.0, 1e-8), "max_comp": ("num", 0.0, 1e-8),
        "max_ext": ("num", 0.0, 1e-8), "peak_tire": ("num", 0.0, 1e-8),
        "overshoot": ("num", 0.0, 1e-8), "rms_acc": ("num", 0.0, 1e-8),
        "rms_tire": ("num", 0.0, 1e-8), "travel_rough": ("num", 0.0, 1e-8),
        "J": ("num", 0.0, 1e-8), "road_rough": ("num", 0.0, 1e-12),
    },
    "w4_heat_plate": {
        "workload": ("exact",), "nx": ("exact",), "ny": ("exact",),
        "n_unknown": ("exact",), "n_hole": ("exact",),
        "it_sor": ("int", 1), "it_rb": ("int", 1),
        "res_sor": ("small", 1e-7), "res_rb": ("small", 1e-7),
        "diff_solvers": ("small", 1e-5), "Q_balance": ("small", 1e-5),
        "T_max": ("num", 1e-6, 0.0), "T_mean": ("num", 1e-6, 0.0),
        "x_Tmax": ("exact",), "y_Tmax": ("exact",), "x_qmax": ("exact",),
        "y_qmax": ("exact",),
        "Q_bottom": ("num", 1e-4, 0.0), "Q_top": ("num", 1e-4, 0.0),
        "Q_hole": ("num", 1e-4, 0.0), "Q_gen": ("num", 0.0, 1e-12),
        "q_max": ("num", 0.0, 1e-7),
        "profile_x": ("num", 1e-6, 0.0), "profile_y": ("num", 1e-6, 0.0),
        "T_sub": ("num", 1e-6, 0.0),
    },
    "w5_tolerance_mc": {
        "workload": ("exact",), "n_sample": ("exact",), "lcg_final": ("exact",),
        "first_top": ("num", 0.0, 1e-15), "first_dev": ("num", 1e-15, 0.0),
        "n_low": ("int", 2), "n_high": ("int", 2), "n_hot": ("int", 2),
        "yield": ("num", 4e-6, 0.0), "hist_counts": ("int", 2),
        "hist_underflow": ("int", 2), "hist_overflow": ("int", 2),
        "rank": ("exact",), "scale_max": ("exact",), "pct": ("exact",),
        "yield_scale": ("num", 4e-6, 0.0),
        "mean_cold": ("num", 0.0, 1e-11), "mean_hot": ("num", 0.0, 1e-11),
        "std_cold": ("num", 0.0, 1e-10), "std_hot": ("num", 0.0, 1e-10),
        "cpk": ("num", 0.0, 1e-9), "cpk_scale": ("num", 0.0, 1e-9),
        "contrib": ("num", 0.0, 1e-9),
        "min_cold": ("num", 1e-14, 0.0), "max_cold": ("num", 1e-14, 0.0),
        "min_hot": ("num", 1e-14, 0.0), "max_hot": ("num", 1e-14, 0.0),
        "pct_cold": ("num", 1e-14, 0.0), "pct_hot": ("num", 1e-14, 0.0),
    },
}

NAMES = list(RULES)


def flatten(v):
    if isinstance(v, list):
        out = []
        for x in v:
            out.extend(flatten(x))
        return out
    return [v]


def as_float(x):
    if x is None:
        return math.nan
    if isinstance(x, bool):
        return float(x)
    return float(x)


def check(rule, a, b):
    """Return (ok, detail). a = MATLAB value, b = NumPy value."""
    fa, fb = flatten(a), flatten(b)
    if len(fa) != len(fb):
        return False, "length %d vs %d" % (len(fa), len(fb))
    kind = rule[0]
    if kind == "exact":
        if any(isinstance(x, str) for x in fa + fb):
            ok = fa == fb
        else:
            ok = all((as_float(x) == as_float(y)) or (math.isnan(as_float(x)) and
                                                       math.isnan(as_float(y)))
                     for x, y in zip(fa, fb))
        return ok, "identical" if ok else "differs"
    xa = np.array([as_float(x) for x in fa])
    xb = np.array([as_float(x) for x in fb])
    if kind == "small":
        bound = rule[1]
        ok = bool(np.all(np.isfinite(xa)) and np.all(np.isfinite(xb))
                  and np.all(np.abs(xa) <= bound) and np.all(np.abs(xb) <= bound))
        return ok, "max |matlab| %.2e, |numpy| %.2e (bound %.0e)" % (
            np.max(np.abs(xa)) if xa.size else 0, np.max(np.abs(xb)) if xb.size else 0, bound)
    nan_a, nan_b = np.isnan(xa), np.isnan(xb)
    if not np.array_equal(nan_a, nan_b):
        return False, "NaN positions differ"
    m = ~nan_a
    if not m.any():
        return True, "all NaN"
    err = np.abs(xa[m] - xb[m])
    if kind == "int":
        ok = bool(np.all(err <= rule[1]))
        return ok, "max |diff| %g (allowed %g)" % (err.max(), rule[1])
    atol, rtol = rule[1], rule[2]
    scale = np.max(np.abs(xa[m]))
    allowed = atol + rtol * scale
    ok = bool(np.all(err <= allowed))
    rel = err.max() / scale if scale > 0 else 0.0
    return ok, "max |diff| %.3e (rel %.2e, allowed %.2e)" % (err.max(), rel, allowed)


def check_arg(rule, key, mat, npy):
    """Argmax/argmin index key judged by near-tie rule. Returns (ok, detail)."""
    kind, arr, rel = rule
    if arr not in mat or arr not in npy:
        return False, "array key %s missing" % arr
    pick = np.nanmax if kind == "argmax_tol" else np.nanmin
    vals = []
    for d in (mat, npy):
        a = np.array([as_float(x) for x in flatten(d[arr])])
        vals.append(a)
    im, ip = flatten(mat[key]), flatten(npy[key])
    if len(im) != 1 or len(ip) != 1:
        return False, "index key is not a scalar"
    im, ip = int(im[0]), int(ip[0])
    amat, anpy = vals
    if not (1 <= ip <= amat.size and 1 <= ip <= anpy.size):
        return False, "index %d out of range" % ip
    ext_m, ext_p = pick(amat), pick(anpy)
    gap_m = abs(amat[ip - 1] - ext_m) / abs(ext_m)
    gap_p = abs(anpy[ip - 1] - ext_p) / abs(ext_p)
    ok = bool(gap_m <= rel and gap_p <= rel)
    return ok, "matlab idx %d, numpy idx %d; numpy idx is %.2e (matlab arr) / %.2e (numpy arr) rel from the extremum (allowed %.0e)" % (
        im, ip, gap_m, gap_p, rel)


def self_test_arg():
    """Synthetic pass/fail cases for the argmax_tol / argmin_tol rules."""
    base = [1.0, 5.0, 5.0 * (1 + 1e-12), 3.0]
    cases = [
        ("argmax_tol near-tie pass", ("argmax_tol", "a", 1e-9),
         {"a": base, "i": 2}, {"a": base, "i": 3}, True),
        ("argmax_tol real mismatch fail", ("argmax_tol", "a", 1e-9),
         {"a": base, "i": 2}, {"a": base, "i": 4}, False),
        ("argmax_tol candidate array not at its max fail", ("argmax_tol", "a", 1e-9),
         {"a": base, "i": 2}, {"a": [1.0, 5.0, 5.0 * (1 + 1e-6), 3.0], "i": 2}, False),
        ("argmin_tol near-tie pass", ("argmin_tol", "a", 1e-9),
         {"a": [2.0, 1.0, 1.0 * (1 + 1e-12)], "i": 2},
         {"a": [2.0, 1.0, 1.0 * (1 + 1e-12)], "i": 3}, True),
        ("argmin_tol real mismatch fail", ("argmin_tol", "a", 1e-9),
         {"a": [2.0, 1.0, 1.5], "i": 2}, {"a": [2.0, 1.0, 1.5], "i": 3}, False),
    ]
    bad = 0
    print("== argmax/argmin rule self-test")
    for label, rule, m, p, want in cases:
        ok, detail = check_arg(rule, "i", {"a": m["a"], "i": m["i"]}, {"a": p["a"], "i": p["i"]})
        good = ok == want
        bad += 0 if good else 1
        print("  %s %-48s -> %s (expected %s)" % ("ok  " if good else "FAIL", label,
                                                   "pass" if ok else "fail",
                                                   "pass" if want else "fail"))
    return bad


def compare(name, mat_path, py_path):
    with open(mat_path) as fh:
        mat = json.load(fh)
    with open(py_path) as fh:
        npy = json.load(fh)
    rules = RULES.get(name, {})
    failures = 0
    print("== %s" % name)
    for key in sorted(set(mat) | set(npy)):
        if key.startswith("_"):
            continue
        if key not in mat or key not in npy:
            print("  FAIL %-22s present only in %s" % (key, "MATLAB" if key in mat else "NumPy"))
            failures += 1
            continue
        rule = rules.get(key, DEFAULT)
        if rule[0] in ("argmax_tol", "argmin_tol"):
            ok, detail = check_arg(rule, key, mat, npy)
        else:
            ok, detail = check(rule, mat[key], npy[key])
        failures += 0 if ok else 1
        print("  %s %-22s %s" % ("ok  " if ok else "FAIL", key, detail))
    return failures


def main(argv):
    self_test = "--self-test" in argv
    names = [a for a in argv if not a.startswith("--")] or NAMES
    total_fail = self_test_arg() if self_test else 0
    for name in names:
        py_path = os.path.join(REF_DIR, name + ".py.json")
        mat_path = py_path if self_test else os.path.join(REF_DIR, name + ".json")
        if not os.path.exists(py_path):
            print("== %s: NumPy reference missing (run reference_py/run_all.py)" % name)
            total_fail += 1
            continue
        if not os.path.exists(mat_path):
            print("== %s: MISSING MATLAB reference %s (run run_all.m in MATLAB)" %
                  (name, os.path.relpath(mat_path, os.path.dirname(REF_DIR))))
            continue
        total_fail += compare(name, mat_path, py_path)
    print("\n%s" % ("ALL COMPARED KEYS PASS" if total_fail == 0 else
                    "%d key(s) FAILED" % total_fail))
    return 0 if total_fail == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
