# Sea acceptance workloads

Five MATLAB scripts that look like everyday engineering work. They are the acceptance targets
for Sea: a Sea port of each script must produce the same numbers and an equivalent text report,
and should run much faster than MATLAB does.

**Originality rule.** Every script here is original. The hardware, materials, loads, geometry,
tolerances and catalogs are invented for this benchmark. The methods are public textbook ones
(DE-Goodman fatigue, Marin factors, direct-stiffness truss FEM, RK4, finite differences, SOR,
Box-Muller, and so on). Nothing here is derived from any user-supplied, team-internal or
third-party script, and nothing may be added that is. The workloads are meant to be published
with Sea.

## The workloads

| Script | Engineering task | Method and size |
|---|---|---|
| `w1_shaft_design.m` | Size a gear shaft: fatigue and yield safety factors, critical speed, bearing selection for 5 named design cases; diameter-vs-material curves; required diameter over a power x speed grid | DE-Goodman with diameter-dependent Marin size factor and Peterson notch sensitivity, so the required diameter is found by **bisection** (tolerance 0.1 um). 5 cases, 4 x 2001 sweep, 90 x 120 grid solved by about 238k scalar bisection steps, then re-solved by a 40-step vectorized bisection over the whole grid |
| `w2_truss_fem.m` | Design and check a 60-panel X-braced bridge truss (122 nodes, 301 members, 241 free DOF) | Direct-stiffness assembly in loops, dense `K\f`. Fully stressed design with an Euler-buckling floor (about 96 re-assemble/re-solve iterations), snap to a section catalog, design check with FOS, a 1441-angle load sweep (one solve with 1441 right-hand sides), influence lines (61 RHS), and a single-member removal study (301 re-assemblies and solves with an `rcond` mechanism check) |
| `w3_quarter_car.m` | Choose suspension damping for a nonlinear quarter car | 2-DOF model with an asymmetric damper, a cubic bump stop, tire damping and tire lift-off. Hand-written fixed-step **RK4** (dt = 1 ms, 8000 steps), a bump run and a random-road run for each of 30 damping values (480k RK4 steps, 1.9M derivative calls). The road comes from 60 harmonics with LCG phases, evaluated vectorized on a 16001 x 60 grid. Metrics: peak and RMS acceleration, travel, tire load, lift-off, settling time, a cost minimum with parabolic refinement, and `eig` for the linear natural frequencies |
| `w4_heat_plate.m` | Steady temperature of a 300 x 200 mm aluminium plate with a heat source, a coolant channel, two fixed-temperature edges and two insulated edges | 241 x 161 grid (37,662 unknowns), 5-point finite differences. **Scalar-loop SOR** (lexicographic, about 830 sweeps, 31M point updates) and a **vectorized red-black SOR** (about 760 sweeps) to a 1e-8 K tolerance. Residuals, a conservative heat-flow balance, the flux field, and centerline profiles |
| `w5_tolerance_mc.m` | Axial end play of a bearing/gear stack in an aluminium housing, cold and at operating temperature | 7-member tolerance chain. Worst-case and RSS limits, then 1,000,000-sample **Monte Carlo** from an in-script Park-Miller LCG (11M scalar LCG steps), with Box-Muller normals, uniform and triangular (inverse-CDF) distributions, and thermal expansion. Reports mean/std/Cpk, rejects, a 60-bin histogram via `accumarray`, percentiles, variance shares, and a 25-step tolerance-scaling yield sweep |

Each script:

1. computes, timing its own numerical part with `tic`/`toc` (`computeSeconds`);
2. prints a readable text report with `fprintf` (tables, units, a summary);
3. draws figures with base graphics when `SEA_PLOT` is true (the default), and saves them
   with `exportgraphics` to `output/<name>.png` only when `SEA_SAVE_FIGURES` is true;
4. writes all key results (scalars and full vectors and matrices) to
   `reference/<name>.json` with `jsonencode` only when `SEA_EXPORT_REFERENCE` is true.

The flags are plain workspace variables, read with `exist(...,'var')`. All three default to
"no files written". The scripts are deterministic: there is no `rand`/`randn` (the LCG is
written in the script), no clock-dependent value in any computed output, and all paths are
relative to the script (`mfilename('fullpath')`). They use base MATLAB only, with no toolboxes.
Percentiles come from the script's own midpoint rule, because `prctile` needs the Statistics
Toolbox.

## Feature matrix

This table is input to Sea's language design document. It lists what a Sea port of each
workload has to express, and what has to be fast.

| Feature | W1 | W2 | W3 | W4 | W5 |
|---|:-:|:-:|:-:|:-:|:-:|
| Many named scalar inputs, units in comments | **x** | x | **x** | x | x |
| Structs (scalar struct, fields as config) | **x** | | **x** | | |
| Struct arrays, `[s.field]`, `{s.field}` | **x** | | | | **x** |
| Cell arrays of strings (labels), `sprintf` into cells | **x** | x | | x | x |
| String `switch` / `otherwise` + `error()` validation | **x** | | | | **x** |
| `error()` on invalid configuration or geometry | x | x | | x | x |
| Multi-output local functions, `~` outputs | **x** | x | **x** | x | x |
| Scalar `while` loop with convergence test | **x** (bisection) | **x** (FSD) | | **x** (SOR) | |
| Tight scalar `for` loops (hot path) | **x** | **x** (assembly) | **x** (RK4) | **x** (SOR) | **x** (LCG) |
| Small fixed-size vectors in a hot loop (4x1 state, 4x4 `ke`) | | **x** | **x** | | |
| Many small function calls in a hot loop | **x** | x | **x** | | |
| `linspace`, `meshgrid`, ranges `a:b:c` | **x** | x | **x** | **x** | x |
| Element-wise expression chains (fusion targets) | **x** | x | **x** | **x** | **x** |
| Implicit expansion (column op row) | | x | **x** | | |
| Logical masks, `x(mask) = ...`, `any`, `nnz`, `find(...,1[,'last'])` | **x** | **x** | **x** | **x** | **x** |
| Whole-array shifted-slice stencils, `[A, B]` concatenation | | | | **x** | |
| Dense matrix assembly with index vectors `K(idx,idx) += ke` | | **x** | | | |
| Dense linear solve `A\b`, many RHS, `rcond` | | **x** | x (3x3) | | |
| `eig` (small) | | | x | | |
| Matrix-vector and matrix-matrix products | | **x** | **x** | | |
| Reductions `sum`/`mean`/`std`/`var`/`max`/`min` with index outputs | **x** | **x** | **x** | **x** | **x** |
| `sort` (1M elements; with index output, `'descend'`) | | | | | **x** |
| `accumarray`, `floor`-binning | | | | | **x** |
| `mod`, exact integer arithmetic in doubles (LCG) | | | x | | **x** |
| `log`, `cos`, `sin`, `sqrt`, `hypot`, `^` with real exponent | **x** | x | **x** | x | **x** |
| `ind2sub`/`sub2ind`, column-major linear indexing | **x** | | | **x** | |
| `round` (half away from zero) | x | | x | x | |
| Formatted text report (`fprintf`, `%-12s`, `%8.3f`, `%+d`, `%e`) | **x** | **x** | **x** | **x** | **x** |
| Figures: `plot`, `bar`, `barh`, `contour`, `imagesc`, `subplot`, `tiledlayout`, `yyaxis`, `legend` | x | x | x | x | x |
| File output: `mkdir`, `fopen`/`fprintf`/`fclose`, `jsonencode`, `exportgraphics` | x | x | x | x | x |

**x** = a central, performance-relevant use; x = used.

## Running in MATLAB

Open MATLAB R2026a and set the current folder to `sea/workloads` (any folder works, because
paths are taken from the files' own locations). Then:

```matlab
run_all            % each workload 3 times, no figures; writes reference/*.json + timings
run_all(true)      % same, plus figures saved to output/
run_all(false, 5)  % 5 repetitions for timing
w3_quarter_car     % one workload on its own: report + figures, writes nothing
```

`run_all` runs each script in its own function workspace with
`SEA_EXPORT_REFERENCE = true`. It prints a timing table (total wall time and the script's own
compute time, first run and best of N; the first run includes JIT warm-up) and the folder it
wrote to. It writes `reference/<name>.json` for each workload and
`reference/baseline_timings_matlab.json` (MATLAB version, architecture, all timings).

To export from a single script by hand: `SEA_EXPORT_REFERENCE = true; w2_truss_fem`.

## Reference values

There are two sets of reference values:

* **`reference/<name>.json`**, written by MATLAB (`run_all.m`). **These are the authority.**
  A Sea port is accepted against them.
* **`reference/<name>.py.json`**, written by an independent NumPy re-implementation of each
  workload in `reference_py/`. They are cross-checks, produced before MATLAB could be run
  here. They should be read as a cross-check, not as the specification.

Produce or refresh the NumPy values, and compare them with MATLAB's:

```sh
cd sea/workloads
uv run --no-project --with numpy python reference_py/run_all.py   # writes *.py.json
uv run --no-project --with numpy python reference_py/compare.py   # MATLAB vs NumPy
```

`compare.py` reports every key as `ok` or `FAIL` and exits non-zero on any failure. A
workload with no MATLAB file yet is reported as `MISSING`. `--self-test` compares the NumPy
files with themselves, which checks the tooling.

### MATLAB semantics reproduced in the NumPy versions

* `linspace`: the R2026a algorithm, read from `toolbox/matlab/elmat/linspace.m`:
  `d1 + (0:n1).*(d2-d1)./n1` (multiply, then divide), a separate symmetric `d1 == -d2`
  branch, and both endpoints set exactly (`common.mlinspace`).
* 1-based indices: every exported index (members, sweep positions, ranks) is in MATLAB's
  1-based numbering. Linear indexing and `find`/`max` scans run in column-major order.
* `max`/`min` return the first extreme value; `max` ignores NaN; `sort(...,'descend')` is
  stable.
* `round`: half away from zero (`common.mround`). NumPy's `round` is half-to-even.
* `std`/`var`: N-1 normalisation (`ddof=1`).
* `K\f`: NumPy uses LU with partial pivoting. MATLAB's backslash detects the symmetric
  positive definite `K(free,free)` and uses Cholesky, so the two agree to rounding, not bit
  for bit.
* `rcond`: MATLAB gives the LAPACK 1-norm estimate; NumPy computes the exact 1-norm
  reciprocal condition number. Only the threshold decision is used. The smallest value seen
  is 3.8e-8, against a threshold of 1e-12.
* Scalar loops (bisection, SOR, RK4, LCG) are written with the same operation order as the
  MATLAB code, so convergence decisions and iteration counts are reproduced.
* `jsonencode` layout: row and column vectors become flat arrays, matrices become arrays of
  rows, NaN becomes `null`. `compare.py` flattens both sides before comparing, so layout
  differences cannot hide value differences.

### Comparison tolerances

The rule for each key is in `reference_py/compare.py` (`RULES`). In summary:

| Quantity | Tolerance | Why |
|---|---|---|
| Strings, labels, indices, catalog picks, counts of mechanisms, LCG state, grid sizes, positions | exact | Discrete results; the LCG is exact in double precision |
| Worst-member index in a near-tie (W2 `r_worst`, `e_crit0`) | near-tie rule, 1e-9 relative | Symmetric members have equal values to rounding (`util_removed` members 60 to 62 agree to ~1e-11 relative), so the winning index depends on last-bit arithmetic (MATLAB backslash vs NumPy LU). The index passes if its value is within 1e-9 relative of the true extremum in both the MATLAB and the NumPy arrays (`argmax_tol` / `argmin_tol` in `compare.py`). Indices with a well-separated winner (`k_worst`, `k_fos_worst`, `i_best`, `rank`) stay exact; any port, including Sea, should be compared this way |
| Smooth floating results (stresses, forces, safety factors, deflections, statistics) | relative 1e-8 to 1e-11 of the key's largest magnitude | Different BLAS/LAPACK summation order and Cholesky vs LU |
| Bisection diameters (W1) | 2e-7 m absolute | Bisection tolerance is 1e-7 m |
| First diameter meeting the target on the W1 sweep | one sweep step (35 um) | A last-bit difference can move the crossing by one sample |
| Iteration counts (bisection, FSD, SOR) | +-1 (FSD +-2) | A last-bit difference can flip a convergence test at the boundary |
| Settling time, lift-off time (W3) | one or two 1 ms steps | Quantised to the time step |
| Temperatures (W4) | 1e-6 K absolute | Both solutions converge to 1e-8 K per sweep; the direct-solve check below shows a true error under 1e-7 K |
| Heat flows (W4) | 1e-4 W absolute | |
| Residuals, solver differences, energy balance | below a stated bound only | They are noise-level by construction |
| Monte Carlo counts (W5) | +-2 samples | `log`/`cos` can differ in the last bit between math libraries, which matters only for a sample within ~1e-16 of a limit |
| Monte Carlo statistics and percentiles (W5) | 1e-14 mm absolute or about 1e-11 relative | |

### Verification already done

Done without MATLAB:

* All five NumPy cross-checks run (`reference_py/run_all.py`) and pass the `compare.py`
  self-test.
* W4: the discrete system was also solved directly with a sparse LU solver (SciPy, in a
  scratch script outside the repo). The maximum difference from the SOR solution was 8.3e-8 K
  over the exported field, and the hot spot agreed to 2e-8 K.
* W2: the support reactions balance the applied load (847.70 + 847.70 = 1695.39 kN), and the
  horizontal reaction is at rounding level.
* W5: the Monte Carlo standard deviation (0.037967 mm) matches the analytic RSS sigma
  (0.037990 mm) within sampling error.
* W1: the scalar and vectorized bisections agree to 7e-8 m, inside the 1e-7 m tolerance.

The MATLAB scripts themselves have **not yet been run** (there is no MATLAB command-line
launcher on the development machine). The first `run_all` in the MATLAB desktop produces the
authoritative JSON. Then run `compare.py`.

## Expected timings

These are rough **estimates**, not measurements. The real baseline is whatever `run_all`
prints in `reference/baseline_timings_matlab.json`. For a recent Apple Silicon Mac running
MATLAB R2026a, compute time per workload is expected to be about 0.5-5 s:

| Workload | Dominant cost | Estimate |
|---|---|---|
| W1 | ~260k calls to a small vectorized-style function on scalars | 1-3 s |
| W2 | ~120k member assemblies in loops, ~400 dense 241x241 solves | 0.5-2 s |
| W3 | 1.9M calls to the derivative function, 4x1 vector arithmetic | 2-5 s |
| W4 | 31M scalar SOR updates plus ~1500 vectorized half-sweeps | 1-3 s |
| W5 | 11M scalar LCG steps, 1M-element sort and vector arithmetic | 0.5-2 s |

For comparison, the NumPy cross-checks take 0.5-4 s each on an M2 Pro (Python 3.12,
NumPy 2.5). Those times are not a baseline for Sea.

## Files

```
workloads/
  README.md               this file
  run_all.m               MATLAB driver: export references, time everything
  w1_shaft_design.m       ... w5_tolerance_mc.m: the workloads
  reference/              <name>.json (MATLAB, authority), <name>.py.json (NumPy cross-check),
                          baseline_timings_matlab.json (from run_all.m)
  reference_py/           common.py, w1..w5 *.py, run_all.py, compare.py
  output/                 figures, only when SEA_SAVE_FIGURES is true (not committed)
```
