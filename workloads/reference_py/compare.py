"""Compare MATLAB reference JSON (reference/<name>.json) with the NumPy cross-check
(reference/<name>.py.json), or with a Sea port's export, key by key, using the tolerances below.

Usage (from sea/workloads):
    uv run --no-project --with numpy python reference_py/compare.py [name ...]
    uv run --no-project --with numpy python reference_py/compare.py --candidate DIR [name ...]
    uv run --no-project --with numpy python reference_py/compare.py --self-test

NumPy mode (default): MATLAB reference/<name>.json against reference/<name>.py.json; a workload
with no MATLAB file yet is reported MISSING and does not fail.

Candidate mode (--candidate DIR): MATLAB reference/<name>.json against DIR/<name>.json (a Sea
port's --export-reference output), with the same RULES except the near-tie keys (see below). A
missing MATLAB reference or a missing candidate file is a FAILURE here.

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
Exit status: 0 if every compared key passes, 1 otherwise.
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
    if ext_m == 0 or ext_p == 0:
        return False, "extremum is 0, relative rule undefined"
    gap_m = abs(amat[ip - 1] - ext_m) / abs(ext_m)
    gap_p = abs(anpy[ip - 1] - ext_p) / abs(ext_p)
    ok = bool(gap_m <= rel and gap_p <= rel)
    return ok, "matlab idx %d, numpy idx %d; numpy idx is %.2e (matlab arr) / %.2e (numpy arr) rel from the extremum (allowed %.0e)" % (
        im, ip, gap_m, gap_p, rel)


def json_index(v):
    """A JSON value as an integer index, or None: a JSON int, or a finite integral float.
    bool, str, null, NaN, Infinity and fractional numbers are rejected."""
    if isinstance(v, bool) or v is None:
        return None
    if isinstance(v, int):
        return v
    if isinstance(v, float) and math.isfinite(v) and v == math.floor(v):
        return int(v)
    return None


def check_arg_candidate(rule, key, mat, cand):
    """Argmax/argmin index key of a Sea port. Returns (ok, detail).

    Stricter than check_arg: the candidate's index must be exactly the first 1-based position of
    the extremum of the candidate's own array, and the MATLAB array's value at that index must be
    within rule's `rel` of the MATLAB extremum.
    """
    kind, arr, rel = rule
    if arr not in mat or arr not in cand:
        return False, "array key %s missing" % arr
    if key not in mat or key not in cand:
        return False, "index key %s missing" % key
    pick = np.nanmax if kind == "argmax_tol" else np.nanmin
    try:
        amat = np.array([as_float(x) for x in flatten(mat[arr])])
        acand = np.array([as_float(x) for x in flatten(cand[arr])])
    except (TypeError, ValueError):
        return False, "array %s has non-numeric entries" % arr
    ic = flatten(cand[key])
    if len(ic) != 1:
        return False, "index key is not a scalar"
    ic = json_index(ic[0])
    if ic is None:
        return False, "index is not an integer (JSON int or integral number required)"
    if amat.size == 0 or acand.size == 0 or np.all(np.isnan(amat)) or np.all(np.isnan(acand)):
        return False, "array %s is empty or all NaN" % arr
    if not (1 <= ic <= amat.size and 1 <= ic <= acand.size):
        return False, "index %d out of range" % ic
    ext_c = pick(acand)
    first = int(np.flatnonzero(acand == ext_c)[0]) + 1     # NaN never equals the extremum
    if ic != first:
        return False, "candidate idx %d is not the first position of its own %s of %s (%d)" % (
            ic, "maximum" if kind == "argmax_tol" else "minimum", arr, first)
    ext_m = pick(amat)
    if ext_m == 0:
        return False, "extremum is 0, relative rule undefined"
    gap_m = abs(amat[ic - 1] - ext_m) / abs(ext_m)
    ok = bool(gap_m <= rel)
    return ok, "candidate idx %d is its own extremum; matlab array is %.2e rel from its extremum there (allowed %.0e)" % (
        ic, gap_m, rel)


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
        ("argmax_tol zero extremum: relative rule undefined, fails", ("argmax_tol", "a", 1e-9),
         {"a": [0.0, -1.0], "i": 1}, {"a": [0.0, -1.0], "i": 1}, False),
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


def compare(name, mat_path, other_path, candidate=False, quiet=False):
    """Compare one workload. Returns the list of failed keys (empty = pass).

    candidate=False: other_path is the NumPy file; True: a Sea port's export (stricter near-tie
    rule). A missing file is reported as a failed key "(file)" in candidate mode.
    """
    def say(text):
        if not quiet:
            print(text)
    failed = []
    say("== %s" % name)
    for label, path in (("MATLAB reference", mat_path), ("candidate", other_path)):
        if candidate and not os.path.exists(path):
            say("  FAIL %s file missing: %s" % (label, path))
            return ["(file)"]
    with open(mat_path) as fh:
        mat = json.load(fh)
    with open(other_path) as fh:
        npy = json.load(fh)
    other = "candidate" if candidate else "NumPy"
    rules = RULES.get(name, {})
    for key in sorted(set(mat) | set(npy)):
        if key.startswith("_"):
            continue
        if key not in mat or key not in npy:
            say("  FAIL %-22s present only in %s" % (key, "MATLAB" if key in mat else other))
            failed.append(key)
            continue
        rule = rules.get(key, DEFAULT)
        if rule[0] in ("argmax_tol", "argmin_tol"):
            fn = check_arg_candidate if candidate else check_arg
            ok, detail = fn(rule, key, mat, npy)
        else:
            ok, detail = check(rule, mat[key], npy[key])
        if not ok:
            failed.append(key)
        say("  %s %-22s %s" % ("ok  " if ok else "FAIL", key, detail))
    return failed


def self_test_candidate():
    """Candidate-mode cases: synthetic near-tie cases and the real MATLAB reference files."""
    import shutil
    import tempfile
    rule = ("argmax_tol", "a", 1e-9)
    near = 5.0 * (1 + 1e-12)
    mat = {"a": [1.0, 5.0, near, 3.0], "i": 2}
    cases = [
        ("own extremum, near-tie of matlab (first of cand dup-free)", {"a": [1.0, 5.0, near, 3.0], "i": 3},
         None, True),
        ("own extremum, matlab extremum elsewhere within rel", {"a": [1.0, 4.0, 6.0, 3.0], "i": 3},
         {"a": [1.0, 6.0, 6.0 * (1 + 1e-12), 3.0], "i": 2}, True),
        ("forgot to add 1 (one before own extremum, near-tie in matlab)",
         {"a": [1.0, 2.0, 5.0, 3.0], "i": 2}, {"a": [1.0, 5.0, near, 3.0], "i": 2}, False),
        ("exact duplicate extremum must name the first position",
         {"a": [1.0, 5.0, 5.0, 3.0], "i": 3}, None, False),
        ("exact duplicate extremum, first position passes",
         {"a": [1.0, 5.0, 5.0, 3.0], "i": 2}, None, True),
        ("index not at own extremum", {"a": [1.0, 5.0, 4.0, 3.0], "i": 4}, None, False),
        ("matlab value at index outside rel", {"a": [1.0, 5.0, 7.0, 3.0], "i": 3},
         {"a": [1.0, 7.0, 5.0, 3.0], "i": 2}, False),
        ("NaN ignored in candidate extremum", {"a": [float("nan"), 2.0, 1.0], "i": 2},
         {"a": [float("nan"), 2.0, 1.0], "i": 2}, True),
        ("argmin: own minimum", {"a": [3.0, 1.0, 2.0], "i": 2}, {"a": [3.0, 1.0, 2.0], "i": 2}, True),
        ("index 2.7 (fractional) fails, not truncated", {"a": [1.0, 5.0, 4.0], "i": 2.7}, None, False),
        ("index 2.0 (integral float) passes", {"a": [1.0, 5.0, 4.0], "i": 2.0}, None, True),
        ("index true (bool) fails", {"a": [5.0, 1.0, 4.0], "i": True}, None, False),
        ("index \"2\" (string) fails", {"a": [1.0, 5.0, 4.0], "i": "2"}, None, False),
        ("index Infinity fails without crashing", {"a": [1.0, 5.0, 4.0], "i": float("inf")}, None, False),
        ("index NaN fails", {"a": [1.0, 5.0, 4.0], "i": float("nan")}, None, False),
        ("index null fails", {"a": [1.0, 5.0, 4.0], "i": None}, None, False),
        ("array with a string entry fails without crashing", {"a": [1.0, "x", 4.0], "i": 3}, None, False),
        ("matlab extremum 0: relative rule undefined", {"a": [0.0, -1.0, -2.0], "i": 1},
         {"a": [0.0, -1.0, -2.0], "i": 1}, False),
    ]
    bad = 0
    print("== candidate rule self-test")
    for label, cand, m, want in cases:
        r = ("argmin_tol", "a", 1e-9) if label.startswith("argmin") else rule
        ok, _ = check_arg_candidate(r, "i", m if m is not None else mat, cand)
        good = ok == want
        bad += 0 if good else 1
        print("  %s %-60s -> %s (expected %s)" % ("ok  " if good else "FAIL", label,
                                                   "pass" if ok else "fail",
                                                   "pass" if want else "fail"))
    # Real data: the MATLAB files used as the candidate must pass every key, then corrupted ones fail.
    tmp = tempfile.mkdtemp(prefix="compare_selftest_")
    try:
        have = [n for n in NAMES if os.path.exists(os.path.join(REF_DIR, n + ".json"))]
        for n in have:
            shutil.copy(os.path.join(REF_DIR, n + ".json"), os.path.join(tmp, n + ".json"))
        for n in have:
            failed = compare(n, os.path.join(REF_DIR, n + ".json"), os.path.join(tmp, n + ".json"),
                             candidate=True, quiet=True)
            good = not failed
            bad += 0 if good else 1
            print("  %s real data: MATLAB file as candidate passes %s%s" % (
                "ok  " if good else "FAIL", n, "" if good else " (failed: %s)" % failed))
        # corrupt one exact key (w3 i_best + 1) and decrement w2 r_worst
        def corrupt(n, key, fn):
            path = os.path.join(tmp, n + ".json")
            with open(path) as fh:
                d = json.load(fh)
            d[key] = fn(d[key])
            with open(path, "w") as fh:
                json.dump(d, fh)
            failed = compare(n, os.path.join(REF_DIR, n + ".json"), path, candidate=True, quiet=True)
            return failed
        for n, key, fn in (("w3_quarter_car", "i_best", lambda v: v + 1),
                           ("w2_truss_fem", "r_worst", lambda v: v - 1)):
            if n not in have:
                print("  FAIL real data corruption test needs reference/%s.json" % n)
                bad += 1
                continue
            failed = corrupt(n, key, fn)
            good = failed == [key]
            bad += 0 if good else 1
            print("  %s real data: corrupted %s.%s fails (failed keys: %s)" % (
                "ok  " if good else "FAIL", n, key, failed))
        # missing candidate file and missing MATLAB reference are failures
        os.remove(os.path.join(tmp, "w1_shaft_design.json"))
        failed = compare("w1_shaft_design", os.path.join(REF_DIR, "w1_shaft_design.json"),
                         os.path.join(tmp, "w1_shaft_design.json"), candidate=True, quiet=True)
        good = bool(failed)
        bad += 0 if good else 1
        print("  %s missing candidate file fails" % ("ok  " if good else "FAIL"))
        failed = compare("nonexistent", os.path.join(tmp, "nonexistent_matlab.json"),
                         os.path.join(tmp, "w2_truss_fem.json"), candidate=True, quiet=True)
        good = bool(failed)
        bad += 0 if good else 1
        print("  %s missing MATLAB reference fails in candidate mode" % ("ok  " if good else "FAIL"))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    return bad


def main(argv):
    self_test = False
    cand_dir = None
    names = []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--self-test":
            self_test = True
        elif a == "--candidate":
            if i + 1 >= len(argv):
                print("--candidate needs a directory", file=sys.stderr)
                return 2
            i += 1
            cand_dir = argv[i]
        elif a.startswith("--"):
            print("unknown option %s" % a, file=sys.stderr)
            return 2
        else:
            names.append(a)
        i += 1
    names = names or NAMES
    if self_test and cand_dir is not None:
        print("--self-test and --candidate cannot be combined", file=sys.stderr)
        return 2
    total_fail = 0
    if self_test:
        total_fail += self_test_arg() + self_test_candidate()
    for name in names:
        if name not in RULES:
            print("unknown workload %s" % name, file=sys.stderr)
            return 2
    for name in names:
        mat_ref = os.path.join(REF_DIR, name + ".json")
        if cand_dir is not None:
            total_fail += len(compare(name, mat_ref, os.path.join(cand_dir, name + ".json"),
                                      candidate=True))
            continue
        py_path = os.path.join(REF_DIR, name + ".py.json")
        mat_path = py_path if self_test else mat_ref
        if not os.path.exists(py_path):
            print("== %s: NumPy reference missing (run reference_py/run_all.py)" % name)
            total_fail += 1
            continue
        if not os.path.exists(mat_path):
            print("== %s: MISSING MATLAB reference %s (run run_all.m in MATLAB)" %
                  (name, os.path.relpath(mat_path, os.path.dirname(REF_DIR))))
            continue
        total_fail += len(compare(name, mat_path, py_path))
    print("\n%s" % ("ALL COMPARED KEYS PASS" if total_fail == 0 else
                    "%d key(s) FAILED" % total_fail))
    return 0 if total_fail == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
