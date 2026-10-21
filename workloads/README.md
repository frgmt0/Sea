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
run_all               % each workload 5 times, no figures; writes reference/* + timings
run_all(true)         % same, plus figures saved to output/
run_all(false, 5)     % 5 repetitions for timing (the default)
run_all(false, 5, 1)  % the same with MATLAB limited to one computational thread
w3_quarter_car        % one workload on its own: report + figures, writes nothing
```

`run_all(makePlots, nRepeat, threads)` runs each script in its own function workspace with
`SEA_EXPORT_REFERENCE = true`. Arguments: `makePlots` (default `false`), `nRepeat` (default
`5`), `threads` (`'default'`, or `1` for `maxNumCompThreads(1)` during the run, restored
afterwards, also on error). Outputs, all under `reference/`:

* `<name>.json`, written on every repetition (the results are deterministic);
* `<name>.txt`, the printed report of the script, captured with `diary` on the **last**
  repetition only (an existing file is deleted first, so the file holds only that script's
  output and not `run_all`'s own prints);
* the timing file: `baseline_timings_matlab.json` (default threads) or
  `baseline_timings_matlab_1thread.json` (`threads = 1`). It records MATLAB version,
  architecture, `max_num_comp_threads` (the value in effect during the run), `machine_model`
  (`sysctl -n hw.model` on macOS, the `/proc/cpuinfo` model name on Linux, else an empty string
  with a `machine_note`), `cpu_brand`, and the total and compute times of every repetition
  plus their medians and bests. The printed table shows first, median and best. Runs with
  fewer than 5 repetitions (a quick figure run, say) are allowed but write **no** timing
  file; `run_all` prints a note.
* The report capture never shares a repetition with figure drawing (plot warnings would leak
  into the text): with `makePlots` true it is made on repetition `nRepeat - 1`, and with
  `makePlots` true and `nRepeat == 1` no report is captured (a note is printed). The user's
  own `diary` state is saved and restored.

The first repetition includes JIT warm-up.

### Regenerating the MATLAB references

Run both, in this order, in the MATLAB desktop, then commit the regenerated `reference/` files:

```matlab
run_all(false, 5, 1)   % single-threaded timings -> baseline_timings_matlab_1thread.json
run_all(false, 5)      % default threads: the JSON and report texts written last
```

The second call comes last so that `reference/<name>.json` and `reference/<name>.txt` come from
the default-threaded run (the single-threaded run also writes them, and is overwritten).
Afterwards `compare.py` (NumPy mode) should still report no failure, and the self-tests below
should pass.

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

### Comparing a Sea port

`compare.py --candidate <dir> [name ...]` compares `<dir>/<name>.json` (a port's
`--export-reference` output) with the MATLAB `reference/<name>.json`, with the same `RULES`
except for the near-tie keys:

```sh
uv run --no-project --with numpy python reference_py/compare.py --candidate OUT_DIR w2_truss_fem
```

* For an `argmax_tol` / `argmin_tol` key (W2 `r_worst` over `util_removed`, `e_crit0` over
  `fos0`) the candidate's index must be **exactly** the first 1-based position of the extremum
  of the candidate's own exported array (NaN ignored; with an exact duplicate extremum, the
  first position), and the MATLAB array's value at that index must be within the rule's `rel` of
  the MATLAB extremum. A port that forgot to add 1 points at the element before its own extremum
  and fails even if that element is a near-tie of MATLAB's.
* A missing MATLAB reference or a missing candidate file is a **failure** (in NumPy mode a
  missing MATLAB file is only reported `MISSING`).

`compare_report.py` judges a candidate text report against the MATLAB report
`reference/<name>.txt` with a token map:

```sh
uv run --no-project --with numpy python reference_py/compare_report.py \
    w5_tolerance_mc OUT/report.txt ../ports/w5_tolerance_mc.tokens \
    --candidate-json OUT/w5_tolerance_mc.json
```

Exit status: 0 equivalent, 1 not equivalent (one diagnostic per failing token or line),
2 usage or token-map error. The reference JSON `reference/<name>.json` is read for `json` rules;
`--candidate-json` is only needed for the `argmax_tol`/`argmin_tol` keys.

**Equivalence.** Same number of lines; the line `Compute time: ... s` (`^Compute time: .* s$`)
is skipped on both sides (at the same line position); per line, the same number of
blank-separated tokens; non-numeric tokens identical; numeric tokens pass their rule.

*Token layers.* Before a token is parsed as a number, **one trailing `,` `;` or `:` is stripped,
then one trailing `)`, then one leading `(`**. Each stripped character (or none) must be the same
on both sides, else the token fails (`1.2345),` is the number `1.2345` with layers `,` `)`).
A core containing `..` is split there into two parts (`0.30..12.00`), and each part is judged as
a numeric token of its own; a token-map entry naming such a token applies its rule to both
parts, and a candidate with a range where MATLAB has none (or the reverse) fails. A token is
numeric if every part parses as a number (Python float syntax including `inf`/`nan`, and forms
like `+3`); otherwise the whole token must be identical on both sides. `%` is not stripped.

In the current scripts this leaves exactly two report tokens non-numeric, both compared as text
(a port must print them with the same digits as MATLAB, and no map rule can relax them):

| Script, line | Format fragment | Example text |
|---|---|---|
| W5, 175 | `%8.2f%%` (contribution table) | `12.50%` |
| W5, 188 | `P%-7.3f` (percentile label) | `P2.500` |

(The examples show the shape, not the values.) The tokens that carry brackets or `..` are
numeric under the layer rule: W1 line 200 `(ke = %.3f)` and line 222 `(%d x %d points`; W2
lines 211 and 213 `left (%.2f, %.2f) kN` and `(%d angles`; W3 line 155 `%.2f..%.2f cycles/m`
and line 166 `(J = %.4f),`; W4 lines 186 and 194 `(x, y) = (%.4f, %.4f) m`; W5 line 171
`(%d samples)`. Percentages written with a blank before the sign (W1's `%.2f %%` and `%.0f %%`,
W5's `yield %.4f %%`) have a numeric number token.

*Default rule.* A numeric token (or part) without a map entry passes if the two texts are equal,
or if `|a - b| <= u`, where `u` is one unit in the last printed digit of the **coarser** of the
two tokens: the unit of a token is `10^(e - d)`, `e` its printed exponent (0 if none) and `d` its
number of fractional digits in the mantissa. The arithmetic is exact decimal, so boundary cases
are exact. `9.99e-05` vs `1.00e-04`, `9.9999` vs `10`, `0.999` vs `1.000`, `1.5` vs `1.50` and
`1E+05` vs `1e+05` pass; `1.5` vs `1.7` and `10` vs `12` fail. A coarse token tolerates more
than a fine one (`1.0` vs `1.04` passes). `inf`/`nan` tokens pass only if equal as text.

**Token map file.** One entry per line, fields separated by runs of blanks:

```
<line regex>  <token number>  <rule>
```

* The regex dialect is Python `re` (not a full POSIX ERE engine) with POSIX bracket classes
  added: `[:alpha:]`, `[:digit:]`, `[:alnum:]`, `[:upper:]`, `[:lower:]`, `[:space:]`,
  `[:blank:]`, `[:xdigit:]`, `[:word:]`, `[:punct:]`, `[:print:]`, `[:graph:]`, `[:cntrl:]` are
  translated **only inside a bracket expression** (`[[:digit:]x]` becomes `[0-9x]`; a bare
  `[:digit:]` is an ordinary set of the characters `:digit`). It is matched with `re.match`,
  i.e. anchored at the start of the line only, not the end (`^Rejects:` and `Rejects:` are
  the same; add `$` to anchor the end). It **may not contain blanks** (the fields are split on
  blanks): write `[ ]` or `[[:space:]]`.
* The token number counts blank-separated tokens of the line from 1 and must name a numeric
  token of the reference line.
* Blank lines and lines starting with `#` are comments.
* Rules: `exact` (identical numbers); `int n` (`|a-b| <= n`); `num atol rtol`
  (`|a-b| <= atol + rtol*|a|`, `a` the MATLAB value); `json <key>` (the rule of that key in
  `RULES[name]`: for `num` the scale for `rtol` is the largest magnitude of that key in the
  reference JSON; `int`, `exact`, `small` apply directly to the two token values; for
  `argmax_tol`/`argmin_tol` the reference token must equal the MATLAB JSON value, the candidate
  token must equal the candidate JSON value, and the candidate JSON must pass the
  own-extremum rule above).
* **Default rule** for a numeric token (or `..` part) without an entry: see *Default rule*
  above.
* The map is validated against all lines of the reference report (the `Compute time` line
  included) before any candidate comparison, so a broken map is exit status 2 whatever the
  candidate looks like. Exit status 2 is: a malformed entry, a bad token number or rule
  argument, an unknown rule, an unknown `json` key, an invalid regex, an unknown POSIX class
  inside brackets, two entries giving different rules to the same token of the same line, a
  token number beyond the line's token count, a token that is not numeric, a missing reference
  report `reference/<name>.txt`, candidate report, token map or `--candidate-json` file, a
  `json` rule whose reference JSON `reference/<name>.json` is missing or lacks the key, and a
  `json` rule on an `argmax_tol`/`argmin_tol` key when `--candidate-json` was not given. An
  entry that matches no reference line only prints a warning. When `--candidate-json` is given
  but lacks the key or has a bad index, that is a judgement failure (exit 1), not a map error.

Both tools have self-tests (no MATLAB needed; `compare.py --self-test` also checks the
candidate mode against the real MATLAB JSON files, then corrupts some of them):

```sh
uv run --no-project --with numpy python reference_py/compare.py --self-test
uv run --no-project --with numpy python reference_py/compare_report.py --self-test
```

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

The MATLAB reference JSON comes from a `run_all` run in the MATLAB desktop (there is no MATLAB
command-line launcher on the development machine). The report texts `reference/<name>.txt`
exist only after the rerun described under "Regenerating the MATLAB references".

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
  run_all.m               MATLAB driver: export references and report texts, time everything
  w1_shaft_design.m       ... w5_tolerance_mc.m: the workloads
  reference/              <name>.json (MATLAB, authority), <name>.txt (MATLAB report),
                          <name>.py.json (NumPy cross-check), baseline_timings_matlab.json and
                          baseline_timings_matlab_1thread.json (from run_all.m)
  reference_py/           common.py, w1..w5 *.py, run_all.py, compare.py (also --candidate),
                          compare_report.py (report comparison with token maps)
  output/                 figures, only when SEA_SAVE_FIGURES is true (not committed)
```
