"""Round-off sensitivity of the W6 keys: the evidence behind compare.py's RULES["w6_topopt"].

Runs one W6 case (w6_topopt.CASES[k]) as the workload does, then again under perturbations of
the order of round-off, and prints how far each exported key moves:

    solver-rev   the block Cholesky eliminates the node columns right to left
    filter-rev   the filter sums its kernel offsets in the opposite order
    E0+1ulp      E0 = 1 + 2^-52
    nu+1ulp      nu = the next double above 0.3
    load+1ulp    the load is -(1 + 2^-52)
    vf+1ulp      the volume fraction is the next double above 0.5
    noiseX       every displacement of every solve is multiplied by (1 + X*r), r uniform in
                 [-1, 1] (fixed seed): an inexact, e.g. iterative, solver of relative accuracy X
    stop-k/+k    the run stops k = 1 or 2 design updates earlier or later than the base run,
                 as if the convergence test had flipped (what a changed iteration count costs)

The first six change the exact problem by at most one ulp of one input; a Sea port (its own
solver and summation orders) differs from MATLAB by perturbations of that kind. The noise
variants bound how accurate a Sea solver must be.

Usage (from sea/workloads), one case per process:
    uv run --no-project --with numpy python reference_py/w6_roundoff.py CASE [VARIANT ...]
CASE is 1, 2 or 3 (w6_topopt.CASES); with no VARIANT every variant runs.
"""

import math
import os
import sys
import time

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import w6_topopt as w  # noqa: E402

VARIANTS = {
    "solver-rev": dict(reverse_solver=True),
    "filter-rev": dict(reverse_filter=True),
    "E0+1ulp": dict(e0=1.0 + 2.0 ** -52),
    "nu+1ulp": dict(nu=float(np.nextafter(w.NU, 1.0))),
    "load+1ulp": dict(load=-(1.0 + 2.0 ** -52)),
    "vf+1ulp": dict(volfrac=float(np.nextafter(w.VOLFRAC, 1.0))),
    "noise1e-12": dict(noise=1e-12),
    "noise1e-10": dict(noise=1e-10),
    "noise1e-8": dict(noise=1e-8),
    "noise1e-6": dict(noise=1e-6),
    "noise1e-4": dict(noise=1e-4),
    "stop-1": None,     # stop one design update earlier than the base run
    "stop+1": None,     # ... one later (the convergence test flipped by rounding)
    "stop-2": None,
    "stop+2": None,
}


def first_divergence(ha, hb, thr):
    """First 1-based iteration at which the two xPhys histories differ by more than thr in
    max norm, or 0 if never."""
    for k, (a, b) in enumerate(zip(ha, hb), start=1):
        if np.max(np.abs(a - b)) > thr:
            return k
    return 0


def main(argv):
    if not argv or argv[0] not in ("1", "2", "3"):
        print(__doc__)
        return 2
    k = int(argv[0]) - 1
    names = argv[1:] or list(VARIANTS)
    name, kind, ft, nelx, nely, rmin = w.CASES[k]
    t0 = time.perf_counter()
    base = w.run_case(kind, ft, nelx, nely, rmin, keep_history=True)
    print("case %d: %s, %dx%d, rmin %.2f -- base: iters %d, c_first %.15g, c_final %.15g, "
          "vol %.12f, gray %.6f, n_solid %d, final change %.6f (%.1f s)" % (
              k + 1, name, nelx, nely, rmin, base["iters"], base["c_first"], base["c_final"],
              base["vol"], base["gray"], base["n_solid"], base["change"],
              time.perf_counter() - t0))
    hdr = ("variant", "d_iters", "rel_c1", "rel_cfin", "max_rel_early", "rel_c50", "d_vol", "d_gray",
           "d_nsolid", "thr_frac", "mean|dx|", "max|dx|", "div1e-6", "div1e-2")
    print("  " + " ".join("%-12s" % h for h in hdr))
    for v in names:
        t0 = time.perf_counter()
        opts = VARIANTS[v]
        if v.startswith("stop"):
            opts = dict(tol_change=0.0, max_iter=base["iters"] + int(v[4:]))
        r = w.run_case(kind, ft, nelx, nely, rmin, keep_history=True, **opts)
        n = min(w.N_EARLY, len(base["c_hist"]), len(r["c_hist"]))
        early = max(abs(a - b) / abs(a) for a, b in zip(base["c_hist"][:n], r["c_hist"][:n]))
        # The load and E0 variants scale the compliance; compare the design-relevant ratio.
        scale = 1.0
        if v == "load+1ulp":
            scale = (1.0 + 2.0 ** -52) ** 2
        elif v == "E0+1ulp":
            scale = 1.0 / (1.0 + 2.0 ** -52)
        xa, xb = base["xPhys"], r["xPhys"]
        row = (v, r["iters"] - base["iters"],
               abs(r["c_first"] - base["c_first"] * scale) / base["c_first"],
               abs(r["c_final"] - base["c_final"] * scale) / base["c_final"],
               early, abs(r["c_hist"][w.N_MID - 1] - base["c_hist"][w.N_MID - 1] * scale)
               / base["c_hist"][w.N_MID - 1], abs(r["vol"] - base["vol"]), abs(r["gray"] - base["gray"]),
               r["n_solid"] - base["n_solid"],
               float(np.mean((xa > 0.5) != (xb > 0.5))),
               float(np.mean(np.abs(xa - xb))), float(np.max(np.abs(xa - xb))),
               first_divergence(base["xhist"], r["xhist"], 1e-6),
               first_divergence(base["xhist"], r["xhist"], 1e-2))
        print("  %-12s %-12d %-12.2e %-12.2e %-12.2e %-12.2e %-12.2e %-12.2e %-12d %-12.5f %-12.2e "
              "%-12.2e %-12d %-12d (%.1f s)" % (row + (time.perf_counter() - t0,)))
        sys.stdout.flush()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
