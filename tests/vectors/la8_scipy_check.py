"""Sub-phase 8c (work package T1): the one-time check of la8_cases.py's RCOND transcription against SciPy.

DESIGN.md 2.13.8: "Its RCOND transcription is itself checked once at 8c against SciPy's `dgecon`
(relative difference <= 1e-3 on 3 000 random matrices; a check of the transcription, not an expected
value)". This script is that check and nothing else: no test file depends on it, and
`la8_cases.py --check` never imports SciPy.

Run (needs NumPy and SciPy, so it is kept out of the normal --check path):

    timeout 300 uv run --no-project --with numpy --with scipy python tests/vectors/la8_scipy_check.py

For each of 3 000 seeded random square matrices A (orders 1 .. 60; normal, uniform, column-scaled
and row-graded entries, so the estimate ranges over many decades), SciPy's `lu_factor` (LAPACK
dgetrf) gives the factor F and the interchanges; then

    mine   = la8_cases.rcond_est(F, n, la8_cases.la_norm1(A), zero pivot)     (2.13.6's steps)
    lapack = scipy.linalg.lapack.dgecon(F, ||A||_1, norm='1')                 (LAPACK dgecon)

on the same factor and the same norm, so the comparison isolates the estimator. It prints the
largest relative difference |mine - lapack| / |lapack|, how many agree bit for bit, and PASS when the
largest is at most 1e-3 (exit 0), else FAIL (exit 1). Differences below that come from LAPACK's
scaled triangular solves (dlatrs) and its BLAS's summation order, which the transcription
deliberately does not copy (2.13.6: unscaled solves, sums in index order).
"""

import os
import sys

import numpy as np
import scipy.linalg
from scipy.linalg import lapack

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import la8_cases  # noqa: E402

COUNT = 3000
LIMIT = 1e-3


def matrices(rng):
    for t in range(COUNT):
        n = int(rng.integers(1, 61))
        kind = t % 4
        if kind == 0:
            A = rng.standard_normal((n, n))
        elif kind == 1:
            A = rng.uniform(-1.0, 1.0, (n, n))
        elif kind == 2:
            A = rng.standard_normal((n, n)) * (10.0 ** rng.uniform(-4.0, 4.0, n))[None, :]
        else:
            A = rng.standard_normal((n, n)) * (10.0 ** np.linspace(0.0, -6.0, n))[:, None]
        yield A


def main():
    rng = np.random.default_rng(20261101)
    worst = 0.0
    worst_case = None
    same = 0
    lo, hi = 1.0, 0.0
    for A in matrices(rng):
        n = A.shape[0]
        lu, piv = scipy.linalg.lu_factor(A, check_finite=True)
        F = lu.tolist()
        zp = next((k for k in range(n) if F[k][k] == 0.0), -1)
        anorm = la8_cases.la_norm1(A.tolist())
        mine = la8_cases.rcond_est(F, n, anorm, zp)
        ref = float(lapack.dgecon(lu, anorm, norm='1')[0])
        rel = abs(mine - ref) / abs(ref)
        if mine == ref:
            same += 1
        if rel > worst:
            worst, worst_case = rel, (n, mine, ref)
        lo, hi = min(lo, ref), max(hi, ref)
    print('la8_scipy_check: %d matrices, rcond from %.3g to %.3g; largest relative difference %.3g%s; '
          '%d bit for bit' % (COUNT, lo, hi, worst,
                              '' if worst_case is None else ' (n = %d: %r vs %r)' % worst_case, same))
    if worst <= LIMIT:
        print('la8_scipy_check: PASS (<= %g)' % LIMIT)
        return 0
    print('la8_scipy_check: FAIL (> %g)' % LIMIT)
    return 1


if __name__ == '__main__':
    sys.exit(main())
