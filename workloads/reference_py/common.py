"""Shared helpers for the independent NumPy cross-check of the Sea MATLAB workloads.

These helpers reproduce MATLAB semantics that NumPy does not share by default:

* ``mlinspace``  -- MATLAB R2026a ``linspace`` (toolbox/matlab/elmat/linspace.m): the general
  case is ``d1 + (0:n1).*(d2-d1)./n1`` (multiply, then divide), the symmetric case
  ``d1 == -d2`` is ``(-n1:2:n1).*(d2./n1)``, and both endpoints are set exactly.
* ``mround``     -- MATLAB ``round``: halves round away from zero (NumPy rounds half to even).
* ``ParkMiller`` -- the in-script LCG used by the workloads (exact in IEEE double).
* ``prctile_mid``-- the percentile definition the workloads implement themselves.
* ``write_reference`` -- JSON writer matching the layout MATLAB ``jsonencode`` produces
  (row vectors -> flat arrays, matrices -> arrays of rows, NaN/Inf -> null).

Run only through uv, e.g. ``uv run --no-project --with numpy python reference_py/run_all.py``.
"""

import json
import math
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
REF_DIR = os.path.join(os.path.dirname(HERE), "reference")


def mlinspace(d1, d2, n):
    """MATLAB linspace(d1, d2, n) for real double scalars."""
    n = int(math.floor(n))
    n1 = n - 1
    d1 = float(d1)
    d2 = float(d2)
    if n < 1:
        return np.zeros(0)
    if d1 == -d2 and n > 2:
        y = np.arange(-n1, n1 + 1, 2, dtype=float) * (d2 / n1)
        y[0] = d1
        y[-1] = d2
        if n1 % 2 == 0:
            y[n1 // 2] = 0.0
        return y
    if n == 1:
        return np.array([d2])
    k = np.arange(0, n1 + 1, dtype=float)
    y = d1 + (k * (d2 - d1)) / n1
    if d1 == d2:
        y[:] = d1
    else:
        y[0] = d1
        y[-1] = d2
    return y


def mround(x):
    """MATLAB round: half away from zero, exact for doubles."""
    if isinstance(x, np.ndarray):
        return np.vectorize(mround, otypes=[float])(x)
    x = float(x)
    if math.isnan(x) or math.isinf(x):
        return x
    a = abs(x)
    r = math.floor(a)
    if a - r >= 0.5:
        r += 1.0
    return math.copysign(r, x) if r != 0 else 0.0


class ParkMiller:
    """Park-Miller minimal-standard LCG: s <- mod(16807*s, 2^31-1), u = s/(2^31-1).

    16807*s < 2^46 < 2^53, so every step is exact in double precision and identical to the
    MATLAB loop ``s = mod(16807*s, 2147483647)``.
    """

    M = 2147483647.0
    A = 16807.0

    def __init__(self, seed):
        self.s = float(seed)

    def next(self):
        self.s = math.fmod(self.A * self.s, self.M)
        return self.s / self.M

    def fill(self, n):
        out = np.empty(n)
        s = self.s
        A = self.A
        M = self.M
        for i in range(n):
            s = math.fmod(A * s, M)
            out[i] = s / M
        self.s = s
        return out


def prctile_mid(xsorted, p):
    """Percentile with the midpoint rule used by the workloads.

    For sorted x(1..N) and p in percent: r = p/100*N + 0.5, clamped to [1, N];
    result = x(floor(r)) + (r - floor(r)) * (x(floor(r)+1) - x(floor(r))).
    """
    n = len(xsorted)
    r = p / 100.0 * n + 0.5
    if r <= 1.0:
        return float(xsorted[0])
    if r >= n:
        return float(xsorted[-1])
    k = int(math.floor(r))
    f = r - k
    return float(xsorted[k - 1] + f * (xsorted[k] - xsorted[k - 1]))


def _clean(v):
    if isinstance(v, dict):
        return {k: _clean(x) for k, x in v.items()}
    if isinstance(v, (list, tuple)):
        return [_clean(x) for x in v]
    if isinstance(v, np.ndarray):
        if v.ndim == 0:
            return _clean(v.item())
        if v.ndim == 1 or 1 in v.shape and v.ndim == 2:
            return [_clean(x) for x in v.ravel().tolist()]
        return [_clean(row) for row in v]
    if isinstance(v, (np.bool_, bool)):
        return bool(v)
    if isinstance(v, (np.integer,)):
        return int(v)
    if isinstance(v, (float, np.floating)):
        f = float(v)
        if math.isnan(f) or math.isinf(f):
            return None
        if f == math.floor(f) and abs(f) < 1e15:
            return int(f)
        return f
    if isinstance(v, int):
        return v
    return v


def write_reference(name, ref):
    """Write reference/<name>.py.json (independent NumPy cross-check values)."""
    os.makedirs(REF_DIR, exist_ok=True)
    out = {
        "_note": "Independent NumPy cross-check of the MATLAB workload. "
                 "MATLAB-generated reference/<name>.json is the authority once produced.",
    }
    out.update(_clean(ref))
    path = os.path.join(REF_DIR, name + ".py.json")
    with open(path, "w") as fh:
        json.dump(out, fh, indent=1)
        fh.write("\n")
    return path
