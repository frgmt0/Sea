# Sea Design

## 0. Status, scope and how this document is agreed

**Status: proposal, second draft (revised after the first review).** Nothing here is
implemented. This document proposes
the whole of Sea: the language, its standard library, its output and plotting model, the
compiler (written in Baysick), the runtime, the performance model, the tests and the plan. It
is written normatively ("must") so that every rule can become a test once it is agreed, but no
rule binds anyone until the user has agreed it.

**How it is agreed.** The user reads the document and either accepts each decision of §20
(Open decisions) or picks another option there. Every other rule is the architect's proposal
and is accepted with the document unless the user changes it. After agreement:

1. this file is split, as Baysick's documents are, into `sea/docs/LANGUAGE.md` (normative:
   what programs mean, their output bytes, errors, exit statuses; §3–§13 here) and
   `sea/docs/DESIGN.md` (normative: compiler passes, file formats, runtime ABI, tests, work
   packages; §14–§19 here). The compiler half gains, in that step, what this proposal
   deliberately leaves at the level of principles: the exact record formats of the
   intermediate files (`sea.ast`, `sea.hir1`, `sea.hir`, `sea.lir1`, `sea.lir`, §14.4), each
   with an `--emit` dump test, as Baysick's IR.md does for its IR;
2. the contract files of §14.6 (`sea/include/*.inc`) are written with the matching doc
   sections, under the same contract rule as Baysick's (`CLAUDE.md`: a shared layout, code,
   limit or symbol changes only in the include file and its doc section together);
3. implementation follows the milestones of §19.

**Scope of Sea v1.** What the five acceptance workloads (`sea/workloads/`) need, done well,
plus the small amount of generality that keeps the language coherent. Every feature in this
document is required by at least one workload or by the language's own consistency (where a
library function is included for consistency, §10 says why); features that no workload needs
are listed as non-goals (§1.3) or as later library work (§10.13), not half-specified.

**Sources.** `sea/README.md`, `sea/CLAUDE.md`, `sea/workloads/README.md` and the five
`w*.m` scripts; Baysick's `docs/LANGUAGE.md` (0.6.0), `docs/DESIGN.md`, `docs/IR.md`,
`docs/BENCH.md`, `docs/SEA_BOOTSTRAP.md`.

### 0.1 Glossary

| Term | Meaning |
|------|---------|
| **class E** | *Exact-reproducible.* A result that is bit-identical on every target and every kernel variant. The rule for everything except the class-R operations (§6.8). Same term and meaning as Baysick DESIGN.md §6.6.4 |
| **class R** | *Reassociating.* A result that may differ in the last bits between targets and kernel variants because summation order and fused multiply-add are free; deterministic for a given target and variant. Only matrix-matrix products and the factorizations of §10.8 are class R |
| **elemental function** | A function written for scalars that Sea applies element by element when called with arrays (§8.5), like Fortran's `ELEMENTAL` |
| **fusion** | Compiling a chain of element-wise operations (and an optional reduction) into one loop with no temporary arrays (§16.1) |
| **view** | A non-owning description of part of an array (slice, transpose, flattening) that the compiler uses instead of copying (§5.6) |
| **COW** | Copy-on-write: arrays have value semantics, implemented by sharing a buffer and copying only when a shared buffer is written (§15.2) |
| **prelude** | The small part of Sea's standard library written in Sea (`std/std.sea`), compiled together with every program (§14.5) |
| **intrinsic** | A library function the compiler expands itself (operators, reductions, `printf`, `write_json`, …, §14.5) |
| **handle type** | A runtime object with reference semantics (`Figure`, `Axes`, `Lu`, `Chol`, §4.1) |
| **pass** | One of the Baysick programs that make up the Sea compiler (§14.3) |
| **HIR / LIR** | The compiler's typed high-level and loop-level intermediate representations, written as text files between passes (§14.4) |
| **variant** | A set of SIMD kernels or fused-loop code for one instruction-set level (`neon`, `sse2`, `avx2`), chosen at startup (§15.4), as in Baysick DESIGN.md §6.6 |
| **port** | A Sea program that reproduces one MATLAB workload (`sea/ports/w*.sea`, §17.3) |
| **MATLAB baseline** | `sea/workloads/reference/baseline_timings_matlab.json` (§1.2) |

## 1. Goals and non-goals

### 1.1 Goals, in priority order (decided by the user)

1. **Raw speed.** Ahead-of-time native code; fused element-wise loops with no temporaries;
   hand-written SIMD kernels (NEON; SSE2/AVX2) behind CPU-feature dispatch; honest
   benchmarks against Accelerate/OpenBLAS, which are the bar and never a dependency.
2. **A cleaner language than MATLAB.** Modern C/Rust-like syntax, deliberately not
   MATLAB-compatible.
3. **Free, tiny, portable.** Standalone native binaries, no giant runtime; targets
   `arm64-macos` and `x86_64-linux`, mirroring Baysick.

### 1.2 Measured by the five workloads

Sea v1 is done when, for each of `w1_shaft_design` … `w5_tolerance_mc`, a Sea port (§17.3):

1. **reproduces the numbers**: its JSON export passes `compare.py`'s rules (`RULES` in
   `sea/workloads/reference_py/compare.py`) against the MATLAB reference
   `reference/<name>.json`, on both targets;
2. **prints an equivalent text report**: the same lines as the MATLAB report (§17.4 defines
   "equivalent");
3. **is faster than MATLAB**, on both measures below, on the machine that produced the MATLAB
   baseline;
4. **writes its figures** as SVG files (§12) when asked to.

**The MATLAB baseline exists.** `reference/baseline_timings_matlab.json` was found, written by
`run_all.m` with MATLAB `26.1.0.3346908 (R2026a) Update 5`, `arch` = `maca64`, three repetitions
per workload. Its values (seconds; the first run includes MATLAB's JIT warm-up):

| Workload | compute, runs 1/2/3 | best compute | total, runs 1/2/3 | best total |
|----------|---------------------|-------------:|-------------------|-----------:|
| w1_shaft_design | 0.613 / 0.528 / 0.532 | 0.528 | 0.738 / 0.591 / 0.594 | 0.591 |
| w2_truss_fem | 1.444 / 1.053 / 1.740 | 1.053 | 1.473 / 1.097 / 1.770 | 1.097 |
| w3_quarter_car | 0.717 / 0.661 / 0.650 | 0.650 | 0.813 / 0.752 / 0.743 | 0.743 |
| w4_heat_plate | 1.146 / 0.914 / 0.901 | 0.901 | 1.157 / 0.919 / 0.906 | 0.906 |
| w5_tolerance_mc | 0.978 / 0.825 / 0.810 | 0.810 | 0.987 / 0.829 / 0.815 | 0.815 |

The file records neither the CPU model nor the machine; §17.5 requires the Sea measurement
to name its machine, and the comparison is valid only on the same one (the user's).

**What "faster than MATLAB" means.** Two measures, both required:

* **Compute time**: the time the program measures around the same region as the MATLAB
  script's `tic`/`toc` (`computeSeconds`), with Sea's `now()` (§13). Compared: Sea's best of 3
  consecutive runs against MATLAB's best compute time above (the same rule as the baseline,
  §16.7). Sea's first run is reported next to MATLAB's first run but is not a pass criterion.
* **Whole-process time**: wall time from `exec` of the compiled Sea binary to its exit, with
  the reference export enabled (MATLAB's `total_seconds` includes the `jsonencode` export) and
  figures disabled (as in `run_all`). Compared: Sea's best of 3 against MATLAB's best
  `total_seconds`. This is
  conservative in MATLAB's favour: MATLAB's total is measured inside an already running
  MATLAB session and excludes MATLAB's own start-up, while Sea's includes everything the
  operating system does to start the process.

Sea's compile time is reported next to these numbers but not counted: an AOT binary is
compiled once and run many times. The methodology is §17.5; its known asymmetries (MATLAB ran
multithreaded, three repetitions with visible variance) are stated in §16.7, and Decision 7 in
§20 proposes a MATLAB rerun that removes them.

### 1.3 Non-goals for v1

Each with the reason. A later version may take any of them up through a new design document.

| Non-goal | Reason |
|----------|--------|
| MATLAB compatibility (syntax or library names) | decided by the user; Sea follows MATLAB **numerics** where the workloads need them (linspace, round, mod, std, sort, column-major scan order) |
| Complex numbers | no workload needs them: w3's `eig(Mlin \ Klin)` is a symmetric-definite generalized problem with real eigenvalues, which Sea solves with `eig_sym(K, M)` (§10.8) |
| Library functions no workload uses (`tan`, `cumsum`, `inv`, `split`, general file I/O, …) | v1 is scoped by the workloads; §10.13 lists them as later library work |
| `f32`, integer widths other than `i64`, unsigned types | no workload needs them; `f32` would change every result |
| N-dimensional arrays (rank > 2) | no workload uses them |
| Sparse matrices | w2 and w4 are dense-solve and stencil problems; sparse support is a separate design |
| Least squares / QR / SVD / nonsymmetric `eig` | not used; `solve` requires a square matrix |
| Closures, function values, generics beyond `elemental` | not needed; `elemental` covers every shape-polymorphic use in the workloads (§8.5) |
| Modules and imports, separate compilation of user code | each workload is one file; the prelude is implicit (§14.5) |
| Threads, parallel loops | Baysick's kernels are single-threaded and the kernel benchmark rules compare single-threaded (BENCH.md §1); see §16.6. The MATLAB workload baseline was multithreaded; §16.7 states how that is handled |
| Interactive display, a REPL, a workspace | Sea is AOT; figures are files (§12) |
| PNG/PDF figure files, fonts, LaTeX labels | §12.9 |
| A debugger | the run-time error report names the source line (§9.2) |
| Self-hosting (the Sea compiler written in Sea) | §14.9 |

## 2. Language overview by example

Each sample below ports a hot section of one workload. The MATLAB lines come first, then the
Sea lines that replace them. The samples use only syntax defined in §3–§13 and parse under the
grammar of Appendix A; names they do not define (`geo`, `cfg`, …) are defined elsewhere in
the port. Indices are 0-based and ranges half-open (§5); `*` is element-wise and `@` is the
matrix product (§6); arrays are values (§4.5).

### 2.1 W1: an elemental safety-factor function and a vectorized bisection

MATLAB (`shaft_safety`, mask-based vector code, called with scalars, vectors and matrices):

```matlab
function [nf, ny, Se, Kf, Kfs] = shaft_safety(d, Mmax, T, p)
dmm = d * 1e3;
kb = ones(size(dmm));
m1 = dmm > 2.79 & dmm <= 51;
kb(m1) = 1.24 * dmm(m1).^(-0.107);
m2 = dmm > 51;
kb(m2) = 1.51 * min(dmm(m2), 254).^(-0.157);
Se = p.ka .* kb .* p.ke .* p.SePrime;
...
for it = 1:40
    mid = 0.5 * (lo + hi);
    [nfv, nyv] = shaft_safety(mid, MG, TG, pGrid);
    up = min(nfv, nyv) < cfg.nTarget;
    lo(up) = mid(up);
    hi(~up) = mid(~up);
end
```

Sea: the function is written once, for scalars, and declared `elemental`; calls with arrays
apply it element by element and fuse into one loop (§8.5, §16.1). The masks become ordinary
scalar control flow.

```sea
elemental fn shaft_safety(d: f64, Mmax: f64, T: f64, p: Params) -> (f64, f64, f64, f64, f64) {
    let dmm = d * 1e3
    let kb = if dmm > 2.79 && dmm <= 51 { 1.24 * dmm ^ -0.107 }
             else if dmm > 51 { 1.51 * min(dmm, 254) ^ -0.157 }
             else { 1.0 }
    let Se = p.ka * kb * p.ke * p.SePrime
    let r = p.rRatio * d
    let q = 1 / (1 + p.aPeterson / r)
    let qs = 1 / (1 + 0.6 * p.aPeterson / r)
    let Kf = 1 + q * (p.Kt - 1)
    let Kfs = 1 + qs * (p.Kts - 1)
    let Ma = Mmax          // rotating shaft: fully reversed bending
    let Mm = 0.0
    let Tm = T
    let Ta = p.ripple * T
    let c16 = 16 / (pi * d ^ 3)
    let alt = sqrt(4 * (Kf * Ma) ^ 2 + 3 * (Kfs * Ta) ^ 2)
    let mmean = sqrt(4 * (Kf * Mm) ^ 2 + 3 * (Kfs * Tm) ^ 2)
    let nf = 1 / (c16 * (alt / Se + mmean / p.Sut))
    let sigMax = sqrt((32 * Kf * (Mm + Ma) / (pi * d ^ 3)) ^ 2
                      + 3 * (16 * Kfs * (Tm + Ta) / (pi * d ^ 3)) ^ 2)
    let ny = p.Sy / sigMax
    return (nf, ny, Se, Kf, Kfs)
}

// vectorized bisection over the whole grid: one fused loop per iteration (§16.1)
for it in 0..40 {
    let mid = 0.5 * (lo + hi)
    let (nfv, nyv, _, _, _) = shaft_safety(mid, MG, TG, pGrid)
    let up = min(nfv, nyv) < cfg.nTarget
    lo = where(up, mid, lo)
    hi = where(up, hi, mid)
}
```

The line break inside `sqrt(…)` is legal because newlines inside parentheses do not end a
statement (§3.7). The `if … else if … else` expression continues over lines because a newline
before `else` is dropped (§3.7).

### 2.2 W2: direct-stiffness assembly and a solve on the free DOFs

MATLAB:

```matlab
for e = 1:size(conn, 1)
    k = EA(e) / L(e);
    cc = c(e) * c(e) * k;  cs = c(e) * s(e) * k;  ss = s(e) * s(e) * k;
    ke = [cc cs -cc -cs; cs ss -cs -ss; -cc -cs cc cs; -cs -ss cs ss];
    idx = [2*conn(e, 1) - 1, 2*conn(e, 1), 2*conn(e, 2) - 1, 2*conn(e, 2)];
    K(idx, idx) = K(idx, idx) + ke;
end
...
U(freeDof, :) = K(freeDof, freeDof) \ F(freeDof, :);
```

Sea: `ke` and `idx` are fixed-size arrays (`f64[4,4]`, `i64[4]`) that live in registers; the
scatter-add compiles to 16 scalar updates (§16.3). Node `a` (0-based) has the DOFs `2a` and
`2a + 1`.

```sea
fn assemble_truss(conn: i64[,], c: f64[], s: f64[], L: f64[], EA: f64[], nDof: i64) -> f64[,] {
    var K = zeros(nDof, nDof)
    for e in 0..rows(conn) {
        let k = EA[e] / L[e]
        let cc = c[e] * c[e] * k
        let cs = c[e] * s[e] * k
        let ss = s[e] * s[e] * k
        let ke = [ cc,  cs, -cc, -cs;
                   cs,  ss, -cs, -ss;
                  -cc, -cs,  cc,  cs;
                  -cs, -ss,  cs,  ss]
        let a = conn[e, 0]
        let b = conn[e, 1]
        let idx = [2 * a, 2 * a + 1, 2 * b, 2 * b + 1]
        K[idx, idx] += ke
    }
    return K
}

fn solve_free(K: f64[,], F: f64[,], freeDof: i64[], nDof: i64) -> f64[,] {
    var U = zeros(nDof, cols(F))
    U[freeDof, :] = solve(K[freeDof, freeDof], F[freeDof, :])
    return U
}
```

The member-removal study factors each reduced matrix and estimates its condition before
using it (§10.8):

```sea
let Kff = Kr[freeDof, freeDof]
if rcond(lu(Kff)) < 1e-12 {
    mechanism[r] = true
    utilRemoved[r] = nan
    continue
}
```

### 2.3 W3: the RK4 inner loop with 4-element state vectors

MATLAB:

```matlab
x = zeros(4, 1);
for k = 1:nStep
    j = 2*k - 1;
    [k1, Ft(k), Fbs] = qc_deriv(x, zr(j), vr(j), c, p);
    k2 = qc_deriv(x + h2*k1, zr(j + 1), vr(j + 1), c, p);
    k3 = qc_deriv(x + h2*k2, zr(j + 1), vr(j + 1), c, p);
    k4 = qc_deriv(x + dt*k3, zr(j + 2), vr(j + 2), c, p);
    Y(:, k) = x;
    acc(k) = k1(3);
    bsOn(k) = Fbs > 0;
    x = x + h6*(k1 + 2*k2 + 2*k3 + k4);
end
```

Sea: `f64[4]` is a value type kept in registers; `qc_deriv` is inlined (§8.6), so the 1.9M
derivative evaluations make no calls and no allocations (§16.3).

```sea
var x: f64[4] = [0, 0, 0, 0]
for k in 0..nStep {
    let j = 2 * k
    let (k1, ft, fbs) = qc_deriv(x, zr[j], vr[j], c, p)
    let (k2, _, _) = qc_deriv(x + h2 * k1, zr[j + 1], vr[j + 1], c, p)
    let (k3, _, _) = qc_deriv(x + h2 * k2, zr[j + 1], vr[j + 1], c, p)
    let (k4, _, _) = qc_deriv(x + dt * k3, zr[j + 2], vr[j + 2], c, p)
    Ft[k] = ft
    Y[:, k] = x
    acc[k] = k1[2]
    bsOn[k] = fbs > 0
    x = x + h6 * (k1 + 2 * k2 + 2 * k3 + k4)
}

fn qc_deriv(x: f64[4], zr: f64, vr: f64, c: f64, p: Car) -> (f64[4], f64, f64) {
    let zs = x[0]; let zu = x[1]; let vs = x[2]; let vu = x[3]
    let vrel = vs - vu
    let cdamp = if vrel > 0 { c * p.rebRatio } else { c }
    var Fsusp = -p.ks * (zs - zu) - cdamp * vrel
    let dc = zu - zs - p.gap
    var Fbs = 0.0
    if dc > 0 { Fbs = p.kbs * dc + p.kbs3 * (dc * dc * dc) }
    Fsusp = Fsusp + Fbs
    var Ft = p.Wtot + p.kt * (zr - zu) + p.ct * (vr - vu)
    if Ft < 0 { Ft = 0 }
    return ([vs, vu, Fsusp / p.ms, (-Fsusp + Ft - p.Wtot) / p.mu], Ft, Fbs)
}
```

The road on a 16001 × 60 grid uses explicit orientation for implicit expansion (§6.3):

```matlab
argR = 2*pi * xh(:) * nk + phik;
zRough0 = sin(argR) * Ak(:);
```

```sea
let argR = 2 * pi * xh.col * nk.row + phik.row
let zRough0 = sin(argR) @ Ak
```

A matrix-vector product is class E (§10.8): its summation order is pinned, so the road
profile, and everything W3 computes from it, has the same bits on both targets.

### 2.4 W4: scalar SOR and a whole-array red-black half sweep

MATLAB (inner loops of the scalar solver):

```matlab
for i = 1:nx
    for j = 2:ny-1
        if fixed(j, i)
            continue;
        end
        if i == 1, tw = T(j, 2); else, tw = T(j, i-1); end
        if i == nx, te = T(j, nx-1); else, te = T(j, i+1); end
        tgs = (tw + te + T(j-1, i) + T(j+1, i) + src(j, i)) / 4;
        tn = T(j, i) + omega * (tgs - T(j, i));
        d = abs(tn - T(j, i));
        if d > dMax, dMax = d; end
        T(j, i) = tn;
    end
end
```

Sea (the same operation order, so the same sweep count, §6.8):

```sea
for i in 0..nx {
    for j in 1..ny-1 {
        if fixed[j, i] { continue }
        let tw = if i == 0 { T[j, 1] } else { T[j, i-1] }
        let te = if i == nx - 1 { T[j, nx-2] } else { T[j, i+1] }
        let tgs = (tw + te + T[j-1, i] + T[j+1, i] + src[j, i]) / 4
        let tn = T[j, i] + omega * (tgs - T[j, i])
        let d = abs(tn - T[j, i])
        if d > dMax { dMax = d }
        T[j, i] = tn
    }
}
```

The vectorized half sweep, with `$` for the extent of a dimension (§5.3) and a `ref` parameter
instead of MATLAB's copy-in/copy-out `[T, d] = f(T, …)` (§8.3):

```sea
fn rb_half_sweep(ref T: f64[,], src: f64[,], colorIn: bool[,], omega: f64) -> f64 {
    let ny = rows(T)
    let Tp = [T[1..ny-1, 1..2], T[1..ny-1, :], T[1..ny-1, $-2..$-1]]
    let Tc = T[1..ny-1, :]
    let tgs = (Tp[:, 0..$-2] + Tp[:, 2..$] + T[0..ny-2, :] + T[2..ny, :] + src[1..ny-1, :]) / 4
    let Tn = Tc + omega * (tgs - Tc)
    let dMax = max(abs(Tn[colorIn] - Tc[colorIn]))
    T[1..ny-1, :] = where(colorIn, Tn, Tc)
    return dMax
}
```

### 2.5 W5: the LCG and the stack-up

MATLAB:

```matlab
function [u, s] = lcg_fill(s, n)
u = zeros(n, 1);
for i = 1:n
    s = mod(16807 * s, 2147483647);
    u(i) = s / 2147483647;
end
end
```

Sea: `s` is an exact 64-bit integer; `%` is the floored modulo (§6.6); `/` of two integers is
the real division (§6.5), so `u[i]` is the same IEEE quotient MATLAB computes.

```sea
fn lcg_fill(ref s: i64, n: i64) -> f64[] {
    var u = zeros(n)
    for i in 0..n {
        s = 16807 * s % 2147483647
        u[i] = s / 2147483647
    }
    return u
}
```

The complete port of W5 is Appendix D.

## 3. Lexical structure

### 3.1 Source text

* A source file is a sequence of bytes, by convention UTF-8. Lines are separated by LF; one CR
  immediately before an LF, or at the very end of the file, is removed. The last line need not
  end with LF.
* Outside string literals and comments only these bytes may appear: space, TAB, LF, and the
  printable ASCII bytes `0x21`–`0x7E`. Any other byte there is the compile error
  `illegal character`. Inside comments and string literals any byte except LF (and, in a
  string, except an unescaped `"`) may appear, so UTF-8 text in labels and comments works.
* A line may hold at most **4096 bytes** (after CR removal): `line too long`. The size of a
  compilation unit (prelude plus program) is bounded by the compiler's table capacities
  (99 999 syntax-tree nodes, 49 999 symbols, …: §14.7), which an estimated 10 000–16 000 lines
  of ordinary code fit; exceeding one is the compile error `program too large: %s`.
* Space and TAB separate tokens and are otherwise ignored.

### 3.2 Comments

* `//` starts a comment that runs to the end of the line.
* `/*` starts a comment that ends at the next `*/`, possibly on a later line. Block comments
  do not nest. An unterminated block comment is `unterminated comment`.
* A comment is equivalent to a space, except that a block comment containing a line break is
  equivalent to one line break (§3.7).

**Units convention.** Sea has no unit system. The house style, used by the ports, is the
workloads' own: a trailing comment with the unit in brackets, `let L = 0.420  // bearing span [m]`.

### 3.3 Identifiers and keywords

```
ident := ( letter | "_" ) { letter | digit | "_" }      letter := A–Z | a–z
```

* At most **63 bytes**; longer is `identifier too long`. Identifiers are case-sensitive.
* `_` alone is not an identifier: it is the discard pattern (§7.2).
* **Keywords** (reserved, never identifiers):

  `break const continue elemental else false fn for if in let match ref return step struct
  true var while`

  and the scalar type names `bool f64 i64 str`.
* **Predeclared names** (Appendix C) are the standard library's functions, the constants
  `pi inf nan eps`, and the handle types `Figure Axes Lu Chol`. They live in an outer
  scope: a program may not declare a top-level function, struct or constant with a predeclared
  name (`redefinition of predeclared name`), and a local binding may not shadow one
  (`local name shadows a predeclared name`). The prelude's own top-level declarations (§14.5)
  define a few of these names, so the first rule applies to the user's file only; the
  second applies to the prelude too. The reason is readability: `len`, `max`, `sum`
  always mean the library function. Struct field names and parameter names used as named
  arguments are not bindings and may equal predeclared names (W5's `Dim` has a field `sign`).

### 3.4 Numeric literals

```
int_lit   := digit { digit | "_" } | "0x" hexdigit { hexdigit | "_" }
float_lit := digits "." digits [ exponent ] | digits exponent
digits    := digit { digit | "_" }
exponent  := ( "e" | "E" ) [ "+" | "-" ] digit { digit }
```

* `_` separates digit groups (`1_000_000`) and is ignored; it may not start the literal, end
  it, follow `0x`, or stand next to `.` or the exponent letter (`invalid numeric literal`).
* There is no `1.` and no `.5`: both are `invalid numeric literal` (so `a.b` field access and
  ranges `0..n` are never ambiguous).
* A literal is unsigned; `-` is an operator. An `int_lit` must be at most 2⁶³ − 1
  (`integer literal too large`), except that the operand of a unary minus may be 2⁶³, giving
  −2⁶³.
* A `float_lit` denotes the IEEE-754 binary64 value nearest to its exact decimal value, ties
  to even (what C `strtod` gives). A literal whose value overflows to infinity is
  `float literal out of range`; one that underflows is the nearest subnormal or zero. The
  compiler computes the bit pattern itself with exact integer arithmetic (§14.8); it never
  depends on the assembler's conversion.
* The **type** of an `int_lit` is decided by context (§4.2); a `float_lit` is `f64`.

### 3.5 String literals

```
str_lit := '"' { char | escape } '"'
escape  := "\\" ( '"' | "\\" | "n" | "t" | "r" | "0" | "x" hexdigit hexdigit
                | "u{" hexdigit { hexdigit } "}" )
```

* A string literal holds bytes. `\n` LF, `\t` TAB, `\r` CR, `\0` NUL, `\xHH` the byte HH,
  `\u{H…}` the UTF-8 encoding of the code point H… (at most 6 hex digits, at most `10FFFF`,
  not a surrogate `D800`–`DFFF`). Any other `\` sequence is `invalid escape`.
* A string literal may not contain an LF: `unterminated string`. There are no multi-line or
  raw strings and no interpolation; formatting is `format` and `printf` (§11).
* In a format string (§11.1) `%` is interpreted by the formatting functions, not by the lexer.

### 3.6 Operators and punctuation

```
+  -  *  /  %  ^  @  ==  !=  <  <=  >  >=  !  &  |  &&  ||
=  +=  -=  *=  /=  (  )  [  ]  {  }  ,  ;  :  .  ..  ..=  ->  =>  $
```

The lexer takes the longest match (`..=` before `..` before `.`; `==` before `=`; `&&` before
`&`). `$` is legal only inside index brackets (§5.3).

### 3.7 Statement separation: newlines

Statements are separated by newlines or by `;`. The lexer turns each line break into a
**NL token**, except in three cases, so long expressions and argument lists can be broken
across lines without any continuation mark:

1. **Inside brackets.** The lexer keeps a stack of open `(`, `[` and `{`. While the innermost
   open bracket is `(` or `[`, line breaks produce no NL.
2. **After a continuing token.** A line break produces no NL when the last token before it is
   one that cannot end a statement: a binary or unary operator (`+ - * / % ^ @ == != < <= > >=
   ! & | && ||`), an assignment operator (`= += -= *= /=`), `,`, `:`, `.`, `..`, `..=`, `->`,
   `=>`, `(`, `[`, `{`, or the keyword `step`.
3. **Before `else`.** NL tokens directly followed (after blank lines and comment-only lines)
   by the keyword `else` are dropped, so `} else {` may start a new line.

(Part of Decision 11 in §20.) Consecutive NL tokens are equivalent to one. A line break inside
a block comment counts as one line break. Consequently a line may not *start* with a binary operator that continues the
previous line: `x = a` NL `- b` is two statements, and the second (`-b`, an expression that is
not a call) is the compile error `expression statement has no effect` (§7.1), so the mistake
cannot pass silently.

## 4. Types

### 4.1 Overview

| Type | Values | Size / representation | Semantics |
|------|--------|-----------------------|-----------|
| `f64` | IEEE-754 binary64 | 8 bytes | value |
| `i64` | integers −2⁶³ … 2⁶³ − 1 | 8 bytes, two's complement | value; overflow is a run-time error (§6.5) |
| `bool` | `true`, `false` | 1 byte in arrays | value |
| `str` | immutable byte strings, 0 … 2³¹ − 1 bytes | refcounted buffer | value |
| `T[]` | dynamic vector of `T` | header + buffer (§15.1) | value (COW) |
| `T[,]` | dynamic matrix of `T`, column-major | header + buffer | value (COW) |
| `T[n]`, `T[r,c]` | fixed-size vector / matrix, `n`, `r·c` ≤ 256 | inline (registers or stack) | value |
| `struct` types | records with named fields (§4.6) | inline fields | value |
| tuples | function results only (§8.4) | registers | value |
| `Figure`, `Axes`, `Lu`, `Chol` | opaque runtime objects (§12.1, §10.8) | refcounted handle | **handle** (reference) |

Element types `T` of arrays: `f64`, `i64`, `bool`, `str`, and struct types. Arrays of arrays do
not exist (a matrix is the 2-D type). There is no `null`, no pointer type, no union.

**Handle types** are the one place where Sea has reference semantics, and only for objects
whose state lives in the runtime: copying a handle copies the reference, so `plot(ax, …)`
changes the axes every copy refers to (that is what a figure under construction needs), and an
`Lu` factorization is shared, never copied. Handles cannot be declared by programs, compared,
or stored in arrays; they may be struct fields, parameters, results and locals.

### 4.2 Numbers: `f64` and `i64`

**Rationale.** All five workloads compute in `f64`, and their integers (counts, indices, the
LCG state, grid sizes) are exact integers that MATLAB keeps in doubles. Sea gives integers
their own type because indices and counts are integers by nature, integer loops and address
arithmetic are faster than conversions, the LCG is exact in `i64` without relying on the
2⁵³ bound, and a type error catches an index computed as a non-integer. Both choices keep
every workload result bit-identical to the MATLAB arithmetic (§6.8).

* **Integer literals are untyped until used.** An `int_lit`, or a constant expression built only
  from `int_lit`s with `+ - *` and unary `-`, takes the type `f64` when it is (a) an operand of
  an arithmetic or comparison operator whose other operand has an `f64` element type,
  (b) assigned, initialised, passed or returned where `f64` (or an `f64` array) is expected,
  (c) an element of an array literal that has an `f64` element, or (d) an operand of `^`
  (§6.5); otherwise it is `i64`. The value must be exactly representable in `f64` (`integer
  constant not exact in f64`). So `let n = 5` is an `i64`, `var Fbs = 0.0` is an `f64`,
  `4 * (Kf * Ma) ^ 2` multiplies by the `f64` 4, and `2 ^ 10` is the `f64` 1024.
* **A `var` initialised by an untyped constant** takes its type from all its uses in the
  function: if any assignment to it (`=`, `op=`, or as a `ref` argument to an `f64`
  parameter) stores an `f64`, the variable is `f64`; otherwise `i64`. So `var dMax = 0`
  followed by `if d > dMax { dMax = d }` with `d: f64` is an `f64` variable, as a MATLAB
  programmer expects, and `var count = 0` followed by `count += 1` is an `i64`. The rule is
  flow-insensitive (one type per variable, decided before code is generated) and applies only
  to a `var` without a type annotation whose initialiser is an untyped constant; `let` bindings
  and annotated variables follow the first rule. (Decision 8 in §20.)
* **Implicit conversion `i64` → `f64`** happens, and only happens, (a) in an arithmetic or
  comparison operator with one `i64` and one `f64` operand (the `i64` operand is converted),
  (b) on assignment, initialisation, argument passing and return into an `f64` slot, and
  (c) element by element for arrays in the same positions (`i64[]` where `f64[]` is expected).
  The conversion rounds to nearest, ties to even (exact for |x| ≤ 2⁵³).
* **No implicit `f64` → `i64`**, ever. Explicit: `i64(x)` (§10.1) converts an integral
  finite `f64` and stops with the run-time error `conversion to i64: x is not an integer`
  otherwise; `i64(floor(x))` and `i64(round(x))` are the idioms.
* `bool` converts to neither implicitly. `f64(b)` and `i64(b)` give 1 or 0.

### 4.3 `bool`

`true` and `false`. Comparisons produce `bool` (or `bool` arrays, §6.4). `if` and `while`
conditions must be scalar `bool` (`condition must be bool`; an array condition is a compile
error, unlike MATLAB's implicit `all`: write `any(m)` or `all(m)`).

### 4.4 `str`

An immutable sequence of bytes, by convention UTF-8 (Sea never decodes it except in the JSON
and SVG writers, §11.4, §12.8, which escape bytes as specified there). Operations: `+`
concatenation, `==` `!=` `<` `<=` `>` `>=` (byte-wise lexicographic, unsigned; no blank
padding: `"a" != "a "`), `len(s)` (bytes), and the functions of §10.9. No mutation; building is
`+` and `format`. Substrings and splitting are later library work (§10.13).

### 4.5 Arrays

**Rank.** Sea has vectors (rank 1, `T[]`, `T[n]`) and matrices (rank 2, `T[,]`, `T[r,c]`) as
distinct static types. A vector has a length `n`; it is neither a row nor a column. A matrix has
`rows × cols`. (Decision 9 in §20.)

**Rationale.** MATLAB's "everything is a matrix" makes `x(k)` work on both orientations, but it
also makes the orientation of every vector a run-time property, a classic source of
`[1×n] vs [n×1]` bugs, and it forces the compiler to keep two extents for every vector. With a
static rank the compiler knows the loop nest of every expression, and the single place where
orientation matters, implicit expansion of a column against a row, is written explicitly with
`v.col` and `v.row` (§5.6, §6.3).

**Shapes.** The extents of dynamic arrays (`T[]`, `T[,]`) are run-time values, fixed when the
array is created and changed only by assigning a new array to the variable. Extents are `i64` in `0 … 2³¹ − 1`; empty arrays (an extent 0) are legal. The extents of
fixed-size arrays are compile-time constants (an integer literal or a `const`), with at most
256 elements (`fixed-size array too large: use a dynamic array`).

**Layout.** Column-major (decided here, not left open: every reason below points the same
way and no workload argues for row-major): element `(i, j)` of an `r × c` matrix is element
`i + j·r` of its buffer. A vector is contiguous. Buffers are 64-byte aligned (§15.1).

**Rationale for column-major.** (1) The workloads' reference outputs depend on MATLAB's
column-major scan order wherever an index is reported from a linear scan: `max(dGrid(:))` in
W1 and `max(Thot(:))` and `max(qMag(:))` in W4 report the *first* maximum in column-major order,
and `find(hole)` in W4 fixes the summation order of `Qhole`. With column-major storage the
natural scans of `A.flat` (§5.6) reproduce these exactly; with row-major every such port would
need a transposed scan. (2) Linear algebra convention (LAPACK, and the column vector `A @ x`).
(3) Interop with Baysick's kernels costs nothing either way: Baysick's matrix views are
row-major with a leading dimension (DESIGN.md §6.6.1), and a column-major `r × c` matrix with
column stride `ld` *is* the row-major `c × r` view with the same `ld`; §15.3 shows how every
kernel call maps.

**Element types.** `f64`, `i64`, `bool` (one byte, 0 or 1), `str` (handles), structs (inline,
fields in declaration order, §4.6). Arithmetic is defined on `f64` and `i64` arrays; logic on
`bool` arrays.

**Fixed-size arrays** (`f64[4]`, `f64[4,4]`, `i64[4]`) are plain values like scalars: the
compiler keeps them in registers or in the stack frame, never on the heap (§16.3). They exist
for small state vectors and element matrices (W2's `ke` and `idx`, W3's RK4 state). An array
literal of `n` scalars has the fixed type `T[n]` when `n` ≤ 256, and the dynamic type `T[]`
otherwise (§6.9); the same for matrix literals by element count. A fixed-size array converts
implicitly to the dynamic type of the same rank and element type (a heap copy is made when
needed); a dynamic array is assigned to a fixed-size variable or parameter only after a
run-time shape check (`shape mismatch: expected 4, got 5`).

**Value semantics.** Assigning an array, passing it as an ordinary argument or storing it in a
struct never makes two variables share mutable state: after `var B = A`, writing `B[0] = 1`
does not change `A`. The implementation shares the buffer and copies on the first write to a
shared buffer (COW, §15.2), so passing and returning arrays is O(1). The one way to let a
function modify a caller's variable is a `ref` parameter (§8.3). Handle types (§4.1) are the
stated exception. (Decision 4 in §20.)

### 4.6 Structs

```sea
struct Material {
    name: str
    Sut: f64      // ultimate strength [Pa]
    Sy: f64       // yield strength [Pa]
    E: f64        // Young's modulus [Pa]
    rho: f64      // density [kg/m^3]
}

let m = Material { name: "CS-low", Sut: 470e6, Sy: 380e6, E: 205e9, rho: 7860 }
```

* A struct declaration is a top-level item; fields are separated by newlines or `,`; field
  types are any type of §4.1 except tuples and other structs that would make the type
  recursive (`recursive struct`).
* The field names `T`, `flat`, `col` and `row` are reserved (`field name reserved for views`),
  in struct declarations and record literals alike, so that `a.T` on an array of structs is
  always the view of §5.6 and never a projection (§4.7).
* A **struct literal** names the type and initialises **every** field exactly once, in any
  order (`missing field`, `duplicate field`, `unknown field`).
* Fields are read with `s.f` and, when `s` is a `var` (or a `ref` parameter), assigned with
  `s.f = …`; `s.f[i] = …` assigns an element of an array field.
* Structs are values (copied on assignment; array fields share by COW).
* Structs compare with neither `==` nor `<`; there are no methods. Functions take structs as
  parameters (W1's `p`, W3's `p`).

**Anonymous records.** A record literal without a type name, `{ workload: "w5", n_sample:
nSample }`, has an anonymous struct type whose fields are the listed names, in the listed
order, with the types of the initialisers. It can be bound with `let`/`var`, read with `.f`, and
passed to `write_json` (§11.4), which is what it is for: MATLAB's `ref.key = value` export
structs. Two record literals have the same type when they have the same field names in the
same order with the same types. Anonymous record types cannot be named in signatures.

### 4.7 Arrays of structs, and struct-of-arrays projection

MATLAB's struct arrays (`dims(d).nom`, `[dims.nom]`, `{dims.name}`) become **arrays of
structs** (`Dim[]`), indexed like any array: `dims[d].nom`. **Field projection**: when `a` has
type `S[]` or `S[n]` and `f` is a field of `S` with scalar or `str` type `F`, the expression
`a.f` is the vector `F[]` of that field of every element, in order (`[dims.nom]` → `dims.nom`,
`{mats.name}` → `mats.name`). A projection is a value (a copy), so it cannot be assigned to; the
compiler fuses it into its consumer when it can (§16.1). Struct arrays are stored as arrays of
structs: Sea does not transpose them to a struct of arrays behind the program's back. Hot
loops in the ports project once before the loop (`let nom = dims.nom`, Appendix D).

### 4.8 Lists of strings

MATLAB cell arrays of strings become `str[]`: `let groupName = ["bottom chord", "top chord",
"vertical", "diagonal"]`. They index, project and concatenate like any vector, and
`format` fills them (`brgLabel[i] = format("DG-%03d", brgBore[i])`). Sea has no general cell
array: a heterogeneous list is a struct.

### 4.9 Tuples and multiple results

A function may return several values: `-> (f64, f64)`, `return (T, Mmax, F)`. The caller
destructures them with `let (T, Mmax, F) = shaft_loads(…)`, discarding any with `_`. Tuples
exist only as function results: there are no tuple variables, tuple parameters or tuple
fields (§8.4). Ignored results cost nothing after inlining (§8.6).

### 4.10 Type inference and annotations

* **Function signatures are always annotated**: every parameter type and the result type
  (`-> T` or `-> (T, …)`; none for no result). This keeps every function separately
  type-checkable and every error message local.
* **Local bindings are inferred** from their initialiser: `let x = 2 * pi * rpm / 60` is an
  `f64`. An annotation `let x: T = e` is allowed anywhere and required where the initialiser's
  type is not determined (`let empty: str[] = []`).
* **Typing is static and strict** (Decision 8 in §20): every expression has one type at
  compile time; the only implicit conversions are those of §4.2 (integer literals,
  `i64 → f64`) and §4.5 (fixed-size → dynamic arrays). Dynamic extents are the only run-time
  shape information; their mismatches are run-time errors (§9.2) unless both extents are known
  constants, in which case they are compile errors.

## 5. Indexing

### 5.1 Base and ranges

* **Indices are 0-based** (Decision 3 in §20): the elements of a vector of length `n` are
  `v[0]` … `v[n − 1]`, the elements of an `r × c` matrix are `A[0, 0]` … `A[r − 1, c − 1]`.
* **Ranges are half-open**: `a..b` is `a, a + 1, …, b − 1` (empty when `a >= b`); `a..=b` is
  `a … b` inclusive. A step is written `a..b step s` (`s ≠ 0`; with `s < 0` the range counts
  down: `9..=0 step -1` is `9, 8, …, 0`, and `a..b step -1` stops before `b`). The length of
  `a..b step s` is `max(0, ceil((b − a) / s))` computed exactly in integers; `step 0` is the
  run-time error `range step is zero`. Range bounds and steps are `i64`; there are no
  floating-point ranges (use `linspace`, §10.3, so the MATLAB colon's rounding subtleties
  cannot occur).

**Rationale for 0-based.** Sea's syntax family (C, Rust, Python/NumPy) is 0-based; half-open
ranges compose without `−1` corrections (`0..n`, `T[1..ny-1, :]` for the interior rows, a
split `0..k` + `k..n`); linear indices and DOF numbers are plain products (`i + j·r`,
`2a`, `2a + 1`); and red-black colouring is `(i + j) % 2`. The cost is that every port must
convert reported indices to MATLAB's 1-based numbering where the reference JSON holds them
(`rank: rnk + 1`, Appendix D), which the acceptance harness checks exactly (§17.3).

### 5.2 Index expressions

`v[e]` and `A[e1, e2]`; each index `e` is one of:

| Index | Meaning | Rank contribution |
|-------|---------|-------------------|
| an `i64` scalar | one position | removes the dimension |
| a range `a..b`, `a..=b`, with optional `step` | those positions in order | keeps it |
| `:` | the whole dimension (`0..$`) | keeps it |
| an `i64` vector (`i64[]`, `i64[n]`) | those positions in order (repeats allowed) | keeps it |
| a `bool` vector of the dimension's extent | the positions where it is `true`, ascending | keeps it |

So `A[i, :]` and `A[:, j]` are vectors, `A[1..ny-1, :]` is a matrix, `A[i, j]` a scalar,
`A[0..1, :]` a `1 × cols` matrix. An `f64` index is a compile error (`index must be i64`).

**Masks.** `v[m]` with `m: bool[]` and `A[M]` with `M: bool[,]` of the same shape as `A` select
the elements where the mask is true, as a **vector**, in increasing linear (column-major)
order, exactly MATLAB's `x(mask)`. A mask of the wrong extent is `shape mismatch`.

**Linear indexing** of a matrix is written through its flat view, `A.flat[k]` (§5.6), with
`k = i + j·rows(A)`; `A[k]` with one index on a matrix is a compile error. `ind2sub` and
`sub2ind` (§10.7) convert.

### 5.3 `$`: the extent

Inside the brackets of an index expression, `$` is the extent of the dimension being indexed:
`v[$ - 1]` is the last element, `T[1..ny-1, $-2..$-1]` the second-to-last column (MATLAB
`T(2:ny-1, end-1)`), `u[0..$ step 2]` every other element (MATLAB `u(1:2:end)`). In nested
index brackets `$` refers to the innermost index expression: in `v[w[$ - 1]]` it is `len(w)`.
Array-literal brackets do not count as index brackets: in `v[[0, $ - 1]]` (the first and last
elements) `$` is `len(v)`. A `$` outside every index expression is the compile error
`'$' outside an index`. `$` is not `end` because with 0-based indices the extent
is one past the last index, and a symbol that means "one past the end" should not read as
"the end".

### 5.4 Bounds checks

Every index is checked: a scalar index must satisfy `0 <= i < extent`; a range must be empty
or have every position in `0 … extent − 1`; every element of an index vector must be in range.
A failure is the run-time error `index i out of bounds for dimension d of extent n` (§9.2).
There are no negative indices that count from the end (`v[-1]` is an error, not the last
element).

Checks are **always on** (Decision 12 in §20). They cost almost nothing where it matters
because the compiler removes the checks it can prove (loop induction variables over
`0..len(v)`, `0..rows(A)`, and the like) and hoists the others out of loops (§16.2); what
remains is a compare and a never-taken branch off the latency chain.

### 5.5 Indexed assignment

* `v[idx] = e` and `A[ri, ci] = e` assign the selected elements. `e` is a scalar (assigned to
  every selected element) or an array of exactly the selected shape (`shape mismatch`
  otherwise; a rank-reduced selection takes a vector).
* **Evaluation order**: the right side is evaluated completely, then the indices, then the
  elements are stored in increasing linear order of the selection. With an index vector that
  repeats a position, the last store wins, as in MATLAB.
* **Compound assignment** `x[sel] op= e` (`+= -= *= /=`) means `x[sel] = x[sel] op e` with the
  selection evaluated once: W2's `K[idx, idx] += ke` gathers the 4 × 4 block, adds `ke`, and
  scatters it back — exactly MATLAB's `K(idx,idx) = K(idx,idx) + ke`, including the case of a
  repeated index.
* Masked assignment `v[m] = e` assigns where `m` is true; `e` is a scalar or a vector of length
  `nnz(m)`.
* **Aliasing**: an assignment behaves as if its right side were computed into a temporary
  first, whatever the overlap between the right side and the target (`T[1..ny-1, :] = …T…`).
  The compiler avoids the temporary when it can prove that every element is read before it is
  written (§16.1).

### 5.6 Views: `.T`, `.flat`, `.col`, `.row`

Four postfix *view suffixes* reinterpret an array without copying it:

| Suffix | Operand | Result | Meaning |
|--------|---------|--------|---------|
| `A.T` | `T[,]` / `T[r,c]` | `T[,]` / `T[c,r]` | transpose |
| `A.flat` | `T[,]` / `T[r,c]` | `T[]` / `T[r·c]` | the elements in column-major (linear-index) order |
| `v.col` | `T[]` / `T[n]` | `T[,]` / `T[n,1]` | `v` as an `n × 1` matrix |
| `v.row` | `T[]` / `T[n]` | `T[,]` / `T[1,n]` | `v` as a `1 × n` matrix |

They are names, not functions, because they cost nothing: the compiler folds them into the
addressing of whatever uses them. They are values like any expression; `A.flat[k] = e` and
`A.flat[m] = e` are also legal assignment targets (they assign `A`'s elements). `.T` on a
vector is a compile error (`vector has no transpose: use .row or .col`). The four suffix names
cannot be struct field names (§4.6), so after a `.` on any array — including an array of
structs, where `.f` would otherwise be a projection (§4.7) — they always mean the view. They
are ordinary identifiers elsewhere (`let row = 3` is legal).

## 6. Expressions and operators

### 6.1 Precedence

Highest first; Appendix B repeats it as a table with associativity.

1. Postfix: call `f(…)`, index `x[…]`, field and view `x.f`.
2. Power `^`, **right**-associative; its right operand may carry a unary sign: `a ^ -b`,
   `2 ^ 3 ^ 2 = 2 ^ 9`. (Part of Decision 11 in §20.)
3. Unary `-`, `!`. `-x ^ 2` is `-(x ^ 2)`.
4. Multiplicative `*` `/` `%` `@`, left-associative.
5. Additive `+` `-`, left-associative.
6. Comparison `==` `!=` `<` `<=` `>` `>=`, **non-associative** (`a < b < c` is a compile error).
7. Element-wise and `&`.
8. Element-wise or `|`.
9. Short-circuit and `&&`.
10. Short-circuit or `||`.
11. Range `..`, `..=` (with optional `step`), only where a range is allowed: a `for` header, an
    index, or an expression whose value is used as an `i64` vector (`(0..=nBin) * binW`).

**Rationale.** Comparisons bind tighter than `&` and `|` (unlike C, like MATLAB), so
`gc >= LSL & gc <= USL & gh <= hotMax` needs no parentheses. `^` is right-associative as in
mathematics (MATLAB's left-associative `2^3^2 = 64` is a trap). `@` shares the precedence of
`*` as in Python.

### 6.2 Element-wise and matrix operators

* `+ - * / ^ %` are **element-wise** on arrays, with broadcasting (§6.3). There is no separate
  `.*`: `*` never means the matrix product. This removes MATLAB's most common bug
  (`*` for `.*`).
* `A @ B` is the **matrix product** (part of Decision 11 in §20): matrix @ matrix → matrix
  (`r×k @ k×c → r×c`), matrix @ vector → vector (`r×k @ k → r`), vector @ matrix → vector
  (`k @ k×c → c`). Inner extents must agree (`shape mismatch`). vector @ vector is a compile
  error (`sum(a * b)` is the dot product). Element types `f64` (an `i64` operand is converted).
* **Transpose** is the view `A.T` (§5.6).
* **Solve** is the function `solve(A, B)` (§10.8), not an operator: `A \ b` reads as an escape
  in a C-like language, and the factorization-based forms (`lu`, `chol`) need names anyway.

### 6.3 Broadcasting (implicit expansion)

For an element-wise binary operator, an elemental function call (§8.5) or `where`:

| Operands | Result | Rule |
|----------|--------|------|
| scalar, any | the other's shape | the scalar applies to every element |
| vector `n`, vector `m` | vector `n` | `n == m` required |
| matrix `r1×c1`, matrix `r2×c2` | matrix `max(r1,r2) × max(c1,c2)` | per dimension: equal, or one of them 1 (MATLAB implicit expansion) |
| vector, matrix | — | compile error `cannot combine a vector with a matrix: use .col or .row` |

So MATLAB's `xh(:) * nk + phik` (column times row plus row) is `xh.col * nk.row + phik.row`.
Mismatched dynamic extents are the run-time error `shape mismatch: 16001x60 vs 60x1`; if both
extents are compile-time constants it is a compile error. The result element type is the
scalar operator's result type (§6.5): `bool` for comparisons and logic; `f64` for `/` and `^`
always, and for `+ - * %` when any operand is `f64`; otherwise `i64`.

### 6.4 Comparison and logic

* `== != < <= > >=` compare `f64` (IEEE: every comparison with NaN is false except `!=`),
  `i64`, mixed `i64`/`f64` (the `i64` converted, §4.2), `bool` (`==`, `!=` only), and `str`
  (byte-wise). On arrays they are element-wise and produce `bool` arrays.
* `!` negates `bool` and `bool` arrays. `&` and `|` are element-wise and/or on `bool` and
  `bool` arrays; both operands are always evaluated.
* `&&` and `||` are short-circuit on scalar `bool` only (an array operand is a compile error).

### 6.5 Arithmetic

**`f64`**: IEEE-754 binary64 with round-to-nearest-even; no traps. Infinities and NaN are
ordinary values (the workloads use `Inf`, `-Inf` and `NaN` as data: `dMax = Inf`,
`Thot(~unknown) = -Inf`, `settle = NaN`). Division by zero gives ±Inf or NaN. Unary `-` flips
the sign bit exactly. Subnormals are kept (never flushed to zero).

**`i64`**: `+ - *` and unary `-` are exact; a result outside the `i64` range is the run-time
error `integer overflow`. `/` on two `i64` operands converts both to `f64` and divides (so
`nnz(pass) / nSample` is a fraction, as in MATLAB). `idiv(a, b)` is the floored integer
quotient. `%` is the floored modulo (below). Division or modulo by zero: `integer division by
zero`.

**Power `x ^ y`.** The result is always `f64`; an `i64` operand (typed or untyped) is
converted (§4.2), so `2 ^ 10` is 1024.0 and `n ^ 2` with `n: i64` is an `f64`.

* If `y` is a **constant** (a literal, a `const`, or a constant expression, possibly with a
  unary minus) whose value is an integer `k` with `|k| <= 4` — whether written `2` or `2.0` —
  `x ^ y` is evaluated by multiplication in this pinned order: `x^0 = 1`, `x^1 = x`,
  `x^2 = x*x`, `x^3 = (x*x)*x`, `x^4 = (x*x)*(x*x)`, `x^-k = 1/(x^k)`. So `x ^ 2` and `x ^ 2.0`
  are the same operation. (W1's `d ^ 3` and the squares in `shaft_safety` take this path.)
* Otherwise `x ^ y` is `pow(x, y)` of §10.4.

There is no integer power; `i64` results are computed with `*`.

### 6.6 Integer division and modulo

`a % b` is the **floored** modulo, whose result has the sign of `b` (MATLAB `mod`, Python
`%`), for `i64` and `f64`:

* `i64`: `a - b * floor(a / b)` computed exactly; `b == 0` → `integer division by zero`.
* `f64`: `r = fmod(a, b)` (exact); if `r != 0` and `r` and `b` have different signs then
  `r = r + b`. Special cases as MATLAB: `b == 0` → `a`; `a` infinite or NaN → NaN; `b = ±Inf`
  falls out of the rule (`-1 % inf = inf`).

`idiv(a, b)` (`i64`) is `floor(a / b)` exactly, with the same overflow (`idiv(-2⁶³, -1)`) and
zero-divisor errors. A truncated remainder (MATLAB `rem`) is later library work (§10.13): for
the workloads' uses (`mod(16807*s, 2147483647)` with `s > 0`, `mod(I + J, 2)`,
`mod(nPanel, 2)`) every definition agrees.

### 6.7 Rounding functions

`floor`, `ceil`, `trunc` are IEEE roundings to integral values. **`round(x)` rounds to the
nearest integer with ties away from zero**, exactly (MATLAB `round`; C `round`): `round(2.5) =
3`, `round(-2.5) = -3`, `round(0.49999999999999994) = 0`. It must never be computed as
`floor(x + 0.5)` (wrong for that last value). arm64 uses `frinta`; x86_64 (no ties-away mode in
SSE2) uses an exact sequence (truncate, compare the exact difference `|x − t|` with 0.5,
adjust), specified with the runtime (§15.5). All four return `f64` (`i64(round(x))` for an
integer). They are elemental.

### 6.8 Exact operation order (the reproducibility contract)

The workloads reproduce MATLAB's iteration counts only if Sea computes the same IEEE operations
in the same order (README, "Scalar loops … are written with the same operation order").
Sea therefore guarantees, for everything that is not class R:

1. **One operator, one IEEE operation.** Each `+ - * /` on `f64` is exactly one binary64
   operation, rounded to nearest-even, in the order of the parse tree (§6.1: `a + b + c` is
   `(a + b) + c`; `2 * pi * rpm / 60` is `((2 * pi) * rpm) / 60`). `sqrt` is the correctly
   rounded square root.
2. **No reassociation, no contraction.** The compiler never reassociates, never forms a fused
   multiply-add from `a * b + c` (Sea v1 has no FMA at all; Decision 1 in §20 weighs an opt-in
   fast mode), never computes `x / c` as
   `x * (1 / c)` unless `c` is a constant power of two (then both are the same correctly
   rounded value), never uses flush-to-zero or approximate reciprocal instructions, and never
   evaluates an `f64` expression in a wider precision.
3. **Constant folding** uses the same IEEE operations (§14.8), so a folded expression has the
   bits the run-time evaluation would have had.
4. **Vectorization changes nothing**: a SIMD lane does exactly the scalar operation sequence
   of its element (§16.1). Reductions have a pinned order independent of the vector width
   (§10.5).
5. **Evaluation order** of operands and arguments is left to right. It matters only for calls
   with effects (output, `error`, `ref` arguments).

**Class R** (may differ in the last bits between targets and kernel variants, deterministic for
a given target and variant): the matrix @ matrix product on dynamic matrices, and the
factorizations of §10.8 and everything computed from them (`lu`, `chol`, `solve`, `rcond`,
`eig_sym`). **Everything else is class E**: element-wise arithmetic, the elementary functions
(§10.4, given Decision 6), reductions, sorting, `linspace`, formatting, JSON and SVG output, and
the matrix @ vector and vector @ matrix products, whose order is pinned (§10.8). `@` on
fixed-size matrices whose every extent is at most 8 is class E too: it is evaluated as
`c[i,j] = (…((a[i,0]*b[0,j] + a[i,1]*b[1,j]) + a[i,2]*b[2,j]) …)` with separate roundings.

**What this costs** is a design decision, not a free property: forbidding contraction and
using FMA-free elementary functions gives up some speed on compute-bound scalar chains. Decision
1 in §20 states the options and the estimated cost; the rules above are its recommended answer.

### 6.9 Array literals and concatenation

```
[e00, e01, …; e10, e11, …; …]
```

* Elements of a row are separated by `,`, rows by `;`. Newlines inside the brackets are
  ignored (§3.7). Trailing `,` before `]` or `;` is allowed.
* **One row of scalars** is a fixed-size vector `T[n]`: `[0.135, 2.5, 50, 97.5, 99.865]` is an
  `f64[5]` (the untyped `50` becomes `f64`, §4.2); `[2 * a, 2 * a + 1, 2 * b, 2 * b + 1]` is an
  `i64[4]`.
* **Several rows of scalars** are a fixed-size matrix `T[r,c]`; every row must have the same
  length (`ragged matrix literal`).
* A literal of scalars with more than 256 elements is dynamic (`T[]`, `T[,]`) instead (§4.5),
  so a long table of constants never hits the fixed-size limit.
* **Concatenation.** If any element is an array, the literal concatenates. Within a row, the
  elements are joined horizontally: scalars and vectors join into a vector (`[mats.name,
  "target"]` is a `str[]`); matrices (and scalars, as 1 × 1) join into a matrix whose row counts
  must agree (`[T[1..ny-1, 1..2], T[1..ny-1, :], T[1..ny-1, $-2..$-1]]`). Rows are then stacked
  vertically; a vector row counts as a `1 × n` matrix row. A row that mixes vectors and matrices
  is a compile error (`use .row or .col`). The result is dynamic unless all parts are fixed.
* The element type is the common type of the elements (`i64` and `f64` → `f64`; struct
  elements must all be the same struct; `str` with `str`).
* `[]` is the empty vector; it needs a type from context (`let names: str[] = []`).

### 6.10 `if` expressions

`if c { a } else { b }` is an expression when it appears where a value is expected; its arms
are single expressions of the same type (after the conversions of §4.2), and `else` is
required. `else if` chains are allowed. Only the selected arm is evaluated. Inside an elemental
function applied to arrays the compiler may evaluate both arms and select (§16.1) — this is
invisible because `f64` arithmetic has no traps. An arm containing anything that can fail is
**never speculated**: an index (bounds check), a call that may `error`, `i64` `+ - *` and unary
`-` (overflow), `i64` `%` and `idiv` (zero divisor, overflow), `i64(x)` (conversion error), a
shape check of a broadcast, and an allocation.

### 6.11 Struct and record literals in conditions

In the **header** of `if`, `while`, `match` and `for` — everything between the keyword and the
`{` of its block, including both bounds and the `step` of a `for` range (`for k in 0..nStep {`)
and the condition of an `else if` — a `{` that is not inside parentheses or brackets always
starts the block, never a struct or record literal; such a literal there must be
parenthesized. A literal inside a call's parentheses in a header (`if ok(Limits { lo: 0.0, hi:
1.0 }, x) {`) needs nothing extra. This is the only grammar rule that depends on context (Rust
has the same one).

## 7. Statements and control flow

### 7.1 Statement kinds

A block `{ … }` holds statements separated by NL or `;` (§3.7). The statements are:

| Statement | Form |
|-----------|------|
| immutable binding | `let pattern [: type] = expr` |
| mutable binding | `var pattern [: type] = expr` |
| assignment | `target = expr`, `target op= expr` (`+= -= *= /=`), `(t1, t2, …) = call` |
| call | `f(…)`: a call whose result, if any, is discarded |
| `if` | `if c { … } else if c2 { … } else { … }` |
| `while` | `while c { … }` |
| `for` | `for x in iterable { … }` |
| `match` | `match e { pattern => { … } … }` |
| `break`, `continue` | innermost loop |
| `return` | `return`, `return e`, `return (e1, e2, …)` |
| block | `{ … }` (a new scope) |

An expression that is not a call, used as a statement, is the compile error
`expression statement has no effect`.

### 7.2 Bindings, mutability, scope

* `let` binds an immutable name: it can be neither assigned nor modified element-wise, and it
  cannot be passed to a `ref` parameter. `var` binds a mutable one. Both require an
  initializer: there are no uninitialized variables.
* **Patterns**: a name, `_` (evaluate and discard), or a tuple pattern `(p1, p2, …)` of names
  and `_` for destructuring a multiple-result call (`let (nfv, nyv, _, _, _) = shaft_safety(…)`).
* **Scope** is lexical, per block. A binding is visible from the statement after it to the end
  of its block. A new binding may **shadow** an earlier one in the same or an enclosing scope
  (`var lo = lo` turns a parameter into a mutable local); it may not shadow a predeclared name
  (§3.3).
* **Top level.** A program is a sequence of items (`fn`, `elemental fn`, `struct`, `const`) and
  statements. The top-level statements, in file order, are the body of the program's implicit
  main function; their bindings are locals of that function and are **not visible inside
  functions** (as MATLAB scripts and local functions). Functions, structs and constants are
  visible everywhere in the file, before and after their declaration.
* **`const NAME [: type] = expr`** declares a compile-time constant at top level; `expr` must be
  a constant expression (literals, other constants, operators, the constants `pi inf nan eps`,
  and `sqrt`). Constants may size fixed arrays (`f64[N]`).

### 7.3 Assignment

* Targets: a `var` name; an element or selection `x[…]` (§5.5); a field `s.f`, `s.f[…]` of a
  `var` struct; `A.flat[…]` (§5.6); a `ref` parameter and its elements and fields.
* `x op= e` is `x = x op e` with `x`'s address computed once.
* `(t1, t2, …) = f(…)` assigns the results of a multiple-result call to existing targets, in
  order, after the call; `_` discards. (`(T, d1) = …` is the MATLAB `[T, d1] = …`.) There is
  one target or `_` per result. Each target may be any assignment target
  (`(nfCurve[m, :], nyCurve[m, :], _, _, _) = shaft_safety(dSweep, M1, T1, p)`).
* Assigning a whole array to a `var` replaces its value (and shape); assigning a selection keeps
  the shape (§5.5).

### 7.4 `if` and `while`

The condition is a scalar `bool` (§4.3). Braces are required; parentheses are not
(`if d > dMax { dMax = d }`). `while` tests before each iteration.

### 7.5 `for`

```
for name in a..b [step s] { … }      for name in a..=b [step s] { … }      for name in v { … }
```

* **Range loops**: `name` is an immutable `i64` local of the loop body taking the range's
  values in order. The bounds and step are evaluated **once**, before the first iteration
  (changing a variable used in them inside the loop does not change the iteration count).
* **Element loops**: `for x in v` iterates over the elements of a vector (`T[]`, `T[n]`,
  including `str[]` and struct arrays) in index order; `x` is an immutable copy of the element.
  The vector is evaluated once; assigning to the vector's variable inside the loop does not
  change the elements visited. A matrix is iterated with `for x in A.flat`.
* `break` leaves the innermost loop; `continue` starts its next iteration.

### 7.6 `match`

```sea
match finish {
    "ground" => { a = 1.58; b = -0.085 }
    "machined" => { a = 4.51; b = -0.265 }
    "hot-rolled" | "rolled" => { a = 57.7; b = -0.718 }
    _ => { error("unknown surface finish \"%s\"", finish) }
}
```

* The scrutinee is a `str` (the only use in the workloads: W1's surface finish; `match` on
  `i64` is later work, §10.13). Each arm has one or more string-literal patterns separated by
  `|`, or `_`; arms are separated by NL or `,`; each arm body is a block.
* The first arm with an equal pattern runs (strings compare byte for byte). A pattern that
  repeats an earlier one is `unreachable pattern`.
* A match must end with a `_` arm (`match is not exhaustive`). This replaces MATLAB's
  `switch … otherwise error(…)` with a compile-time guarantee.
* `match` is a statement, not an expression; it does not fall through.

### 7.7 Blocks and lifetimes

Every block is a scope. Arrays and strings held by bindings that go out of scope are released
(their reference counts decremented, §15.2) at the end of the block, on `break`, `continue` and
`return`. This is invisible to the program except as memory use.

## 8. Functions

### 8.1 Definitions

```
fn name(p1: T1, p2: T2 = default, ref p3: T3) -> R { … }
fn name(…) -> (R1, R2, …) { … }
fn name(…) { … }                         no result
elemental fn name(…) -> R { … }          §8.5
```

* Top-level items only; no nested functions, no closures, no function values.
* Every parameter and result type is written (§4.10). A function with a result must end every
  path with `return` (`missing return`).
* **Default values**: a parameter may have a constant default; all parameters after it must
  have one too.
* **Calls**: positional arguments first, then named ones `name: value` in any order; a name
  must match a parameter not already given (`unknown parameter`, `parameter given twice`); a
  parameter without a default must be given (`missing argument`). The standard library uses
  named arguments for options (`sort(v, desc: true)`, `plot(ax, x, y, style: "r--")`).
* **Effects.** A function **has effects** if it writes output (`printf`, `print`, `write_json`,
  `make_dir`, `save_svg`, the plotting calls), has a `ref` parameter, or calls a function with
  effects. `error` is not an effect in this sense. Elemental functions may not have effects
  (§8.5).
* **Overloading**: none for user functions (one name, one function). Library functions are
  overloaded by arity and argument types as listed in §10.

### 8.2 Parameters: value semantics

An ordinary parameter is an **immutable binding** of the argument's value. For arrays, strings
and structs the callee receives the caller's buffer without a copy (it cannot modify it, so no
copy is ever needed, §15.2); a `var` copy inside the callee (`var lo = lo`) copies only if it is
then written while still shared.

### 8.3 `ref` parameters

`ref name: T` makes the parameter another name for the caller's variable: assignments to it
(whole, element-wise or field-wise) change the caller's variable at once. The call site must
say so with `ref` and pass a mutable target (`lcg_fill` is defined in §2.5):

```sea
var s = seed
let u = lcg_fill(ref s, 2 * nSample)       // advances the caller's s
```

* The argument of a `ref` parameter must be a `var` name, an element, a field, or a `ref`
  parameter of the caller (not a `let`, not an expression, not a selection with ranges or index
  vectors: `ref argument must be a mutable variable, element or field`).
* A `ref` argument may not share its **root variable** with any other argument of the same
  call (`ref argument aliases another argument`). The root of an argument is the variable at
  the start of its path: `dims[0].name`, `dims[k].tol` and `dims` all have the root `dims`, so
  `f(ref dims[0].nom, dims[1].nom)` is rejected even though the two elements differ. The check
  is on names only, at compile time, and deliberately conservative: it needs no reasoning about
  index values. (Copy the other argument into a `let` first if this is ever in the way.) It is
  what lets the callee modify `T` in place while reading `src` (W4's
  `rb_half_sweep(ref T, src, redIn, omega)`).
* `ref` replaces MATLAB's copy-in/copy-out idiom `[T, d] = f(T, …)`, which MATLAB optimizes in
  place only sometimes; in Sea the in-place update is the semantics. (Returning the array, as
  MATLAB does, is also legal Sea and also free: COW, §15.2.)

### 8.4 Multiple results

`-> (R1, R2, …)` declares several results; `return (e1, e2, …)` returns them; the caller must
destructure them (`let (a, b) = f()`, `(x, y) = f()`) or discard the whole call as a statement
(`f()`). A multiple-result call cannot appear inside an expression. MATLAB's "ask for fewer
outputs" (`k2 = qc_deriv(…)`) is `let (k2, _, _) = qc_deriv(…)`.

### 8.5 Elemental functions (shape polymorphism)

`elemental fn` declares a function written for scalars that may also be called with arrays:

* Its **elemental parameters** are those of type `f64`, `i64` or `bool`; its results must be
  scalars of those types (one result or a tuple). Other parameters (structs, strings, arrays)
  are **uniform**: passed unchanged.
* A call where every elemental argument is a scalar is an ordinary call. If one or more
  elemental arguments are arrays, all elemental arguments are broadcast together (§6.3) and
  the function is applied to each element position; each result becomes an array of the
  broadcast shape. W1 calls `shaft_safety` with scalars (bisection), with a 2001-element vector
  (the material sweep) and with 90 × 120 matrices (the grid bisection).
* The body may use any statements (loops, `if`, `match`, calls), but may not have effects
  (§8.1): no `ref` parameters, no output, and only calls of functions without effects
  (`effects in elemental function`). Recursion is not allowed in or through an
  elemental function. `error` is allowed (it stops the program at the first failing element in
  increasing linear order).
* Elemental calls are always inlined into the loop that applies them, and fuse with the
  surrounding element-wise expression (§16.1).
* All built-in scalar math functions (`sqrt`, `exp`, `log`, `cos`, `min(a, b)`, `round`, `where`,
  conversions, …) are elemental.

**Rationale.** MATLAB code is shape-polymorphic because everything is a matrix; W1's
`shaft_safety` is written with masks (`kb(m1) = …`) precisely so that it works for any shape.
An elemental function is that code written as plain scalar logic, which is clearer and is also
the form a compiler can fuse and vectorize. It covers every shape-polymorphic use in the five
workloads; full generics are a non-goal (§1.3). (Decision 10 in §20.)

### 8.6 Recursion and inlining

* Ordinary functions may be recursive (directly or mutually). Recursion depth is limited by the
  run-time stack (§15.6): `stack overflow` is a run-time error, not a crash.
* **Inlining is an optimization the language does not observe**, with one guarantee the
  performance model relies on (§16.2–§16.3), stated on the source so a programmer can check
  it: a function is inlined at every call site if it is (a) elemental, or (b) called from
  exactly one call site, or (c) not recursive (directly or through other functions), contains
  no loop, and has at most 50 statements, counting the statements of nested blocks. The
  compiler may inline more. W3's `qc_deriv` (no loop, 16 statements; called 1.9M times) and
  W1's `shaft_safety` (elemental; called ~260k times on scalars) are therefore not calls at all
  in the compiled loops; their unused results are dead code.

## 9. Errors

### 9.1 Compile-time errors

* Format, on standard error, one line:
  `<file>:<line>:<col>: error: <message>` + LF, where `<file>` is the source file name as given
  to `sea`, `<line>` and `<col>` are 1-based (the column counts bytes), and `<message>` is the
  text from the error table (contract file `sea/include/errors.inc`, §14.6), with
  `%s`/`%d`-style substitutions.
* The compiler stops at the **first** error, in a deterministic order: lexical and syntax errors
  in source order (pass 1), then name and type errors in source order (pass 2), then the few
  errors only later passes detect (capacity limits). The compiled output is not written.
* The driver's exit status is 1 for a compile error (§14.2). There are no warnings in v1: a
  rule is either an error or allowed.

Examples of messages (the full list is the error table): `undeclared name 'nTraget'`,
`type mismatch: expected f64, found str`, `cannot combine a vector with a matrix: use .col or
.row`, `index must be i64`, `missing field 'rho' in Material literal`, `match is not
exhaustive`, `expression statement has no effect`, `ref argument aliases another argument`,
`format "%d" expects an integer or f64, found str`.

### 9.2 Run-time errors

A run-time error stops the program:

1. standard output is flushed (with no extra newline: Sea output has no column state);
2. one line goes to standard error: `<file>:<line>: error: <message>` + LF (`<line>` is the
   1-based line of the expression or statement that failed);
3. open output files are flushed and closed;
4. the process exits with status **1**.

The run-time error messages (texts in `errors.inc`, with substitutions):

| Condition | Message |
|-----------|---------|
| index out of range | `index %d out of bounds for dimension %d of extent %d` |
| extent mismatch | `shape mismatch: %s vs %s` (shapes written `16001x60`, `60`) |
| `i64` overflow | `integer overflow` |
| `i64` division or `%` by zero | `integer division by zero` |
| `i64(x)` of a non-integral or out-of-range value | `conversion to i64: %g is not an integer` |
| range step 0 | `range step is zero` |
| negative or too large extent in a constructor | `invalid array size %d` |
| `max`/`min`/`argmax`/`argmin` of an empty array | `%s of an empty array` |
| singular matrix in `solve` (an exactly zero pivot) | `matrix is singular` |
| `chol` of a matrix that is not positive definite | `matrix is not positive definite` |
| `eig_sym` of a non-symmetric matrix | `matrix is not symmetric` |
| non-square matrix where square required | `matrix is not square (%s)` |
| out of memory | `out of memory` |
| stack overflow | `stack overflow` |
| file or directory cannot be created/written (`write_json`, `save_svg`, `make_dir`) | `cannot open '%s': %s`, `cannot write '%s': %s`, `cannot create directory '%s': %s` (reason from a fixed table of errno texts so both targets print the same bytes) |
| invalid plot argument (§12.3) | `invalid line style "%s"`, `invalid color "%s"` |
| user `error(fmt, …)` | the formatted message |

### 9.3 `error`

`error(fmt, args…)` formats like `format` (§11.1) and stops with that message (§9.2). The
location is the `error` call. There is no MATLAB-style identifier (`'w5:config'`): the message
says what failed. (`assert` and an explicit `exit(code)` are later library work, §10.13; no
workload ends with a status other than 0 or 1.)

### 9.4 Exit statuses of a compiled program

| Status | Meaning |
|-------:|---------|
| 0 | normal end: the last top-level statement completed |
| 1 | run-time error, including `error` |

A write error on standard output at any time (including the final flush) makes the status 1
(the Baysick rule, LANGUAGE.md §15.4: a status 0 always means every byte arrived).


## 10. Standard library

The library is specified to the level the workloads need, with its exactness class (§6.8).
"Elemental" means the function accepts arrays with broadcasting (§8.5). Where a MATLAB function
is replaced, its name is given. Every function here is class E unless marked **R**.

**Scope rule (§0).** v1 contains what the five workloads use, plus a small core whose
inclusion is justified in the table where it is not obvious. Everything else that a numerical
language will eventually want is listed in §10.13 ("Later") and is not part of v1: no partial
specification of it exists in this document.

**Where each function lives** (§14.5): *intrinsic* (expanded by the compiler), *runtime*
(assembly in `libsea.a`), or *prelude* (Sea source, marked **(P)**).

### 10.1 Conversions and constants

| Function | Result |
|----------|--------|
| `f64(x)` | `i64` or `bool` (or arrays) to `f64`; elemental |
| `i64(x)` | `f64` → `i64` if integral and in range, else run-time error; `bool` → 0/1; elemental |
| `pi`, `inf`, `nan`, `eps` | `f64` constants: the double nearest π, +∞, a quiet NaN, 2⁻⁵² |
| `isnan(x)` | `bool`; elemental. Core: the only readable test for the NaN values the workloads produce (`x != x` works but is obscure) |

### 10.2 Construction and shape

| Function | Result |
|----------|--------|
| `zeros(n)`, `zeros(r, c)` | `f64[]` / `f64[,]` of zeros (MATLAB `zeros(n,1)`, `zeros(r,c)`) |
| `ones(n)`, `ones(r, c)` | of ones |
| `filled(v, n)`, `filled(v, r, c)` | a vector / matrix with every element `v`, of `v`'s type (`filled(false, n)`, `filled(0.005, r, c)`, `filled("", n)`) |
| `len(v)` | `i64` length of a vector or `str` |
| `rows(A)`, `cols(A)` | `i64` extents of a matrix |
| `numel(A)` | `i64` element count of a vector or matrix |

A negative extent is the run-time error `invalid array size`.

### 10.3 `linspace` and `meshgrid` (P)

**`linspace(d1, d2, n)`** → `f64[]`, bit-exact to MATLAB R2026a (`toolbox/matlab/elmat/
linspace.m`, as reproduced by `common.mlinspace`), with `n1 = n − 1` and all arithmetic in
`f64` (`n` is an `i64`):

1. `n < 1` → empty. `n == 1` → `[d2]`.
2. If `d1 == -d2` and `n > 2`: `y[k] = (-n1 + 2k) * (d2 / n1)` for `k = 0 … n1` (the integer
   `-n1 + 2k` converted exactly, then one multiplication by the one quotient `d2 / n1`); then
   `y[0] = d1`, `y[n1] = d2`, and if `n1` is even `y[n1 / 2] = 0`.
3. Otherwise `y[k] = d1 + (k * (d2 - d1)) / n1` (multiply, then divide, then add — this order
   matters); then if `d1 == d2` every `y[k] = d1`, else `y[0] = d1` and `y[n1] = d2`.

**`meshgrid(x, y)`** → `(X, Y)`, both `len(y) × len(x)`: `X[i, j] = x[j]`, `Y[i, j] = y[i]`
(MATLAB). A fused consumer never materializes them (§16.1).

### 10.4 Elementary functions (elemental)

| Function | Definition |
|----------|------------|
| `abs`, `sign` (`-1, 0, 1`; NaN → NaN), `sqrt` (correctly rounded), `floor`, `ceil`, `trunc`, `round` (§6.7) | exact (single instructions or exact sequences) |
| `min(a, b)`, `max(a, b)` | the smaller/larger; if one is NaN the other (MATLAB); `min(-0, +0)` is the first argument |
| `log`, `exp`, `sin`, `cos`, `pow`, `hypot` | Sea's own implementations (Decision 6 in §20): error ≤ 1 ulp, special values as C99 Annex F, identical bits on every target and variant and in scalar and SIMD forms. `log sin cos pow hypot` are used by the workloads; `exp` is included because `pow` is built from the same `exp`/`log` kernels, so exposing it costs nothing |
| `x % y`, `idiv(a, b)` | §6.6 |
| `where(c, a, b)` | `a` where `c` is true, else `b`; all three are evaluated in full, then broadcast |

`log(0) = -inf`, `log(-1) = nan`, `sqrt(-1) = nan`: IEEE values, no errors (MATLAB would return
complex results, which Sea does not have; no workload takes these branches).

### 10.5 Reductions

On vectors (`T[]`, `T[n]`); a matrix is reduced with `dim:` or through `A.flat`.

| Function | Result |
|----------|--------|
| `sum(v)` | pinned 8-lane order (below); empty → +0 |
| `mean(v)` | `sum(v) / len(v)`; empty → NaN |
| `variance(v)` | two-pass: `m = mean(v)`; `s` = 8-lane sum of `(v[i] - m) * (v[i] - m)`; `s / (n − 1)` (MATLAB `var`, N − 1 normalization); n = 1 → 0; n = 0 → NaN |
| `std(v)` | `sqrt(variance(v))` |
| `max(v)`, `min(v)` | the first maximal/minimal element in index order, NaN ignored; all NaN → NaN; empty → run-time error |
| `argmax(v)`, `argmin(v)` | its `i64` index (first occurrence; all NaN → 0) |
| `nnz(m)`, `any(m)`, `all(m)` | count of `true` (`i64`), or-, and-reduction of a `bool` vector |
| `sum(A, dim: 0)`, `max(A, dim: 0)`, … | reduce each column (result: vector of `cols(A)`); `dim: 1` reduces each row (vector of `rows(A)`); each in the vector rule's order. Implemented for `sum mean variance std max min any all nnz` (W2 uses `max(…, [], 1)`) |

On `i64` vectors `sum` is exact with an overflow check (order irrelevant).

**The pinned 8-lane order.** For a non-empty `f64` `sum` (and the sums inside `mean`,
`variance` and the vector @ matrix product, §6.8): eight accumulators `a[0..8]` start at −0.0;
for `i = 0, 1, …, n − 1` in order, `a[i % 8] = a[i % 8] + x[i]`; the result is
`((a[0] + a[1]) + (a[2] + a[3])) + ((a[4] + a[5]) + (a[6] + a[7]))`. The empty sum is +0
(MATLAB's `sum([])`), stated separately because the −0.0 start would otherwise give −0. The
order is fast on every target (NEON and SSE2: four 2-lane registers; AVX2: two 4-lane
registers) and independent of the vector width, so the result is class E; starting at −0.0
makes `sum([x]) = x` exactly, including `x = -0.0`. Results differ from MATLAB's summation order
in the last bits only. The tightest tolerances on summed quantities in `compare.py` are 1e-12
relative (W3 `road_rough`, a 60-term matrix-vector sum, and W4 `Q_gen`, a sum of a few hundred
terms of equal size); reordering such sums changes them by about 1e-15 relative (an estimate:
a few ulps times the number of terms, far below 1e-12).

### 10.6 Sorting and searching

| Function | Result |
|----------|--------|
| `sort(v, desc: false)` | the sorted values, **stable** |
| `argsort(v, desc: false)` | the stable sorting permutation (`i64[]`), MATLAB's `[~, idx] = sort(v)` |
| `find(m)` | `i64[]` of the indices where the `bool` vector is true, ascending; for a `bool[,]` use `find(M.flat)` (column-major linear indices, MATLAB `find`) |
| `find_first(m)`, `find_last(m)` | `i64` index of the first/last `true`, **−1** if none (MATLAB `find(m, 1)`, `find(m, 1, 'last')`, `isempty`) |
| `setdiff(a, b)` (P) | sorted unique `i64` values of `a` not in `b` (W2's free DOFs) |

Order for `f64`: ascending numeric order with `-0 == +0` (equal values keep their input order);
NaN after every number ascending, before every number descending (MATLAB). `str`: byte-wise.
Sorting is exact (class E) whatever the algorithm; the runtime uses an LSD radix sort on the
order-preserving 64-bit key transform for large `f64`/`i64` vectors (§15.5).

### 10.7 Index utilities

| Function | Result |
|----------|--------|
| `ind2sub(r, k)` | `(i64, i64)` = `(k % r, idiv(k, r))`, elemental (`[i, j] = ind2sub(size(T), k)`) |
| `sub2ind(r, i, j)` | `i + j * r`, elemental, with a bounds check against `r` |
| `bincount(idx, n)` (P) | an `i64[]` of length `n`: the count of each value `0 … n − 1` in `idx` (`accumarray(idx, 1, [n 1])`); a value outside → run-time error |

### 10.8 Dense linear algebra

| Function | Class | Result |
|----------|:-----:|--------|
| `A @ B`, matrix @ matrix | R | GEMM (§15.3) |
| `A @ x`, matrix @ vector | E | `y[i] = (…((A[i,0]·x[0] + A[i,1]·x[1]) + A[i,2]·x[2]) …)`, each product and sum rounded separately, `j` ascending (Sea's GEMV kernel, vectorized across `i`) |
| `x @ A`, vector @ matrix | E | `y[j]` = the pinned 8-lane sum (§10.5) of the rounded products `x[k]·A[k,j]` |
| `lu(A)` | R | an `Lu` handle: LU with partial pivoting of a square matrix (`P A = L U`), plus `‖A‖₁` |
| `chol(A)` | R | a `Chol` handle: Cholesky `A = Rᵀ R` of a symmetric positive definite matrix; run-time error if not positive definite |
| `solve(F, B)` | R | for `F` an `Lu` or `Chol`: the solution of `A X = B`; `B` a vector → vector, a matrix → matrix (many right-hand sides, W2's 1441) |
| `solve(A, B)` | R | `A` square: if `A` is exactly symmetric with a positive diagonal, try `chol`; if that succeeds use it, else `lu` (MATLAB `\`'s choice for these matrices). An exactly zero pivot → `matrix is singular`. No warning for ill-conditioning (call `rcond`) |
| `rcond(F)` | R | for an `Lu`: the reciprocal 1-norm condition estimate, Hager/Higham's estimator as in LAPACK `dgecon` (MATLAB `rcond`); 0 for an exactly singular factor |
| `eig_sym(A)` | R | eigenvalues of a symmetric matrix, ascending (`f64[]`) |
| `eig_sym(K, M)` | R | eigenvalues of the symmetric-definite pencil `K x = λ M x`, ascending (via `chol(M)`); W3's `sort(eig(Mlin \ Klin))` |

**Why matrix-vector products are class E.** A matrix-vector product is memory-bound: each
element of `A` is used once, so a pinned order costs nothing measurable (the loop above
vectorizes across `i` with one multiply and one add per element, exactly the work of any other
order), while it keeps W3's road (`sin(argR) @ Ak`, a 16001 × 60 times 60 product) and W2's
reactions (`K @ u0`) bit-identical across targets. Only matrix-matrix products and
factorizations, whose speed depends on register blocking, are class R.

The factorizations are blocked and their trailing updates use the GEMM kernel's update form
(§15.3), so their rounding follows GEMM's (class R). For a given target and kernel variant every
result is deterministic. `rcond`'s threshold use in W2 (`< 1e-12`, smallest value seen 3.8e-8)
is far from any rounding effect. **Empty and non-finite operands**: an empty product gives the
zero matrix of the result shape (without calling a kernel); `Inf` and `NaN` propagate by IEEE
rules in every operation of this table.

### 10.9 Strings

| Function | Result |
|----------|--------|
| `a + b`, `==`, `!=`, `<`, … | §4.4 |
| `len(s)` | bytes |
| `format(fmt, args…)` | the formatted `str` (§11.1; MATLAB `sprintf`; W1's `DG-%03d` labels, W1/W2's legend strings) |
| `str(x)` | `i64`: decimal; `f64`: `%.17g` (§11.4); `bool`: `true`/`false` |
| `lower(s)` | ASCII lower case (W1's `switch lower(finish)`) |

### 10.10 Program environment and files

| Function | Result |
|----------|--------|
| `args()` | `str[]`: the command-line arguments after the program name (Decision 14 in §20) |
| `now()` | §13 |
| `make_dir(path)` | create a directory if it does not exist (MATLAB `if ~exist(d,'dir'), mkdir(d)`) |
| `write_json(path, value)` | §11.4 |
| `save_svg(fig, path)` | §12 |

Paths are host paths relative to the working directory (§11.3).

### 10.11 Random numbers

None. The workloads write their own LCG (README: "there is no `rand`/`randn`"), which Sea
expresses exactly in `i64` (§2.5).

### 10.12 Errors

`error(fmt, args…)` (§9.3).

### 10.13 Later (not in v1)

Each of these is ordinary library work that no workload needs; adding one later is a new
library section with its own tests, and changes nothing above.

| Area | Candidates |
|------|-----------|
| elementary functions | `log2 log10 tan asin acos atan atan2 sinh cosh tanh fma isinf isfinite clamp rem` |
| reductions and scans | `prod dot norm cumsum cumprod diff` |
| linear algebra | `inv det eye diag`, QR/least squares, nonsymmetric `eig` |
| arrays | `push reverse zeros_like accumulate` |
| strings | `upper join split starts_with ends_with find_str parse_f64 parse_i64 byte`, substrings `s[a..b]` |
| files and environment | `create fprintf write close read_lines is_dir is_file getenv eprintf exit assert` |
| language | `match` on `i64`; `printf` conversions `%x %X %c`; i64 bitwise operations |
| plotting | `yline`, log axes, PNG files (§12.9) |

## 11. Text output

### 11.1 Formatting: `printf` and `format`

```
printf(fmt, args…)          to standard output
format(fmt, args…)          to a str
```

**The format must be a string literal.** The compiler parses it, checks every argument
against its conversion, and emits a pre-parsed format (no format parsing at run time). This
catches MATLAB's silent `%d`-with-a-string mistakes at compile time and is faster. Arguments
do not cycle through the format (MATLAB's format recycling): the number of arguments must equal
the number of conversions (`format "…" expects 3 arguments, found 2`); loops print tables.

**Conversion syntax**: `%[flags][width][.precision]conv`, with

* flags: any of `-` (left-justify), `+` (always a sign), space (space for a positive sign),
  `0` (zero padding), `#` (alternate form);
* width, precision: decimal digits (no `*`);
* conv:

| conv | Argument types | Output |
|------|----------------|--------|
| `d`, `i` | `i64`; `f64` | `i64`: decimal. `f64` (MATLAB rule): an integral finite value prints as the integer it is (exactly, any magnitude); NaN, Inf, −Inf print as `NaN`, `Inf`, `-Inf` padded to the width (the `0` flag ignored); a non-integral value prints as `%e` with the same flags and width and precision 6 (MATLAB prints `1.500000e+00` for `sprintf('%d', 1.5)`; W1 prints `L10h`, which can be NaN, with `%8d`) |
| `f`, `F`, `e`, `E`, `g`, `G` | `f64`; `i64` (converted) | C99 semantics for finite values; NaN/Inf as for `d` (MATLAB spelling, not C's `nan`/`inf`) |
| `s` | `str` | the bytes; precision truncates to that many bytes; width pads with spaces (counts bytes) |
| `%%` | — | `%` |

Any other conversion, flag combination C leaves undefined, or argument type is a compile error.

**Exact output.** For finite `f64` values the digits are the **correctly rounded** decimal
representation of the exact binary value, ties to even, which is what C99 `printf` produces on
both targets' C libraries (Apple libc and glibc both convert exactly). The runtime implements a
conversion by calling the host `snprintf` with a single-conversion C format it builds from the
pre-parsed one (§15.5); the non-finite and `%d`-on-`f64` cases, where C and MATLAB differ, are
handled by the runtime before calling C. The exponent of `%e`/`%g` has at least two digits
(`1.0e+06`) on both targets. Outputs are therefore byte-identical across targets for the same
argument bits. Exact ties such as `%.2f` of 0.125 print `0.12` (the C rule). **Unverified:**
whether MATLAB's `fprintf` on macOS rounds exact ties the same way has not been checked (no
MATLAB is available to the author); a difference could only appear at an exact binary tie, and
the report comparison's last-digit rule (§17.4) absorbs it.

### 11.2 `print`

`print(s)` writes the bytes of `s` to standard output, nothing added. There is no implicit
newline anywhere: newlines are written by the program (`\n`).

### 11.3 Files and streams

Sea v1 writes files only through `write_json` (§11.4) and `save_svg` (§12), and creates
directories with `make_dir`; general file output is in §10.13. Paths are host paths, relative to
the process's working directory (the ports write `output/…` and `<name>.json` relative to it;
the acceptance harness chooses the directory, §17.3). Standard output is buffered (64 KiB) and
flushed when full, before anything is written to standard error, and at exit. Standard error is
unbuffered and is written only by run-time errors (§9.2).

### 11.4 JSON export: `write_json(path, value)`

`write_json` is a **compiler intrinsic** (Decision recorded in §14.5): pass 2 expands each call,
for the static type of `value`, into a sequence of calls to the runtime's JSON emitter
(`object begin`, `key`, `f64`, `i64`, `bool`, `str`, `array begin`, …), recursively over struct
and record fields in declaration order and over array elements. No generics or reflection are
needed in the language, and any struct, record or array type can be written. The file is
written through a 64 KiB buffer, followed by LF.

| Sea value | JSON |
|-----------|------|
| struct or anonymous record | object, keys = field names in declaration order |
| `f64` finite | C `%.17g` (one `snprintf` per number; 17 significant digits always round-trip to the same double) |
| `f64` NaN, ±Inf | `null` (MATLAB writes `null` for NaN) |
| `i64` | decimal |
| `bool` | `true` / `false` |
| `str` | string, with `"`, `\`, and bytes below 0x20 escaped (`\n`, `\t`, `\u00XX`); other bytes as they are |
| vector (any element type) | flat array |
| matrix | array of rows |
| empty vector or matrix | `[]` |

**Layout promised**: two-space indentation per level, one element or member per line,
`"key": value` with one space after the colon, LF line ends, the same bytes on every target for
the same values. **Not promised**: textual agreement with MATLAB's `jsonencode`, which writes
other number forms (`1.0E+6`, `2.145635252E+9`) and its own spacing. Nothing depends on the
text: `compare.py` parses both files as numbers and flattens arrays before comparing.

**Why `%.17g` and not a shortest-round-trip form.** It is one exact conversion per number
(fast enough for W1 and W3, which export about 1 MB each: ~70 000 numbers), it is the precision
MATLAB itself writes (17 significant digits), and it needs no Ryu-style algorithm in the
runtime. A shortest-form writer would make the files smaller but not more exact.

## 12. Plotting and reports

### 12.1 Model

A figure is a grid of panels; each panel is a set of axes with data series. The program builds
a `Figure` with library calls and writes it to an **SVG** file (Decision 13 in §20). Nothing is
drawn on a screen; there is no global "current figure" or `hold` state: every call names the
axes it draws on.

**Where it lives.** `Figure` and `Axes` are **runtime handle types** (§4.1): reference-counted
objects whose state lives in the runtime, so `plot(ax, …)` changes the axes that every copy of
the handle refers to — reference semantics that Sea values cannot express, provided by the
runtime instead of a new language feature. The calls of §12.2–§12.4 append series (with copies
of their data) and set properties in that state. `save_svg` is in the runtime too: it lays out
the figure and writes the file through a growing byte buffer (so building a large file is
linear, not the quadratic cost of repeated immutable `str` concatenation), and it contains the
PNG writer for images (CRC-32, Adler-32, stored deflate blocks, base64), which needs bit
operations that Sea v1 does not have. The plotting library is therefore runtime assembly on
both targets, written once per target like the rest of the runtime (estimated at 2 500–4 000
lines per target, an estimate; §14.7).

### 12.2 Figures and panels

| Function | Meaning (MATLAB equivalent) |
|----------|-----------------------------|
| `figure(nrows, ncols, name: "", width: 960, height: 720)` | a new `Figure` with an `nrows × ncols` grid and an overall heading `name` (`figure('Name', …)`, `subplot`/`tiledlayout` grid) |
| `panel(fig, row, col, rowspan: 1, colspan: 1)` | an `Axes` occupying grid cells `row … row+rowspan−1`, `col … col+colspan−1` (0-based); `subplot(2,2,[1 3])` is `panel(fig, 0, 0, rowspan: 2)` |
| `twin_y(ax)` | a second `Axes` sharing `ax`'s x-axis with its own y-axis on the right (`yyaxis right`) |
| `save_svg(fig, path)` | write the file (`exportgraphics`) |

### 12.3 Series

| Function | Meaning |
|----------|---------|
| `plot(ax, x, y, style: "-", label: "", width: 1.0, color: "")` | a polyline and/or markers |
| `xline(ax, x, style: "--", color: "")` | a full-height vertical reference line (W5's LSL/USL lines) |
| `bar(ax, x, h, width: 0.8, label: "", color: "")` | vertical bars centred on `x`, `width` in units of the smallest x spacing (`bar(x, h, 1)` is `width: 1`) |
| `barh(ax, h, width: 0.8, label: "", color: "")` | horizontal bars at y = 0, 1, … |
| `contour(ax, x, y, Z, levels: 10, labels: false, color: "")` | iso-lines of `Z` (`len(y) × len(x)`) |
| `image(ax, x, y, Z, colorbar: false)` | `imagesc`: cell colours from `Z` scaled to its min … max |

* **`style`** follows MATLAB's line specification: line `-` (solid), `--` (dash pattern 6 4),
  `:` (2 3), `-.` (6 3 2 3), or none; marker `o` (circle), `s` (square), `d` (diamond), `^`, `v`
  (triangles), `x`, `+`, `*`, `.` (dot), drawn 6 px wide; colour letter `r g b c m y k w`
  (`#ff0000 #00a000 #0000ff #00bfbf #bf00bf #bfbf00 #000000 #ffffff`). An unknown letter is a
  run-time error `invalid line style "%s"`.
* **`color`** is `""` (use the style letter, else the axes' next cycle colour) or `#rrggbb`
  (W2's MATLAB `[0.75 0.75 0.75]` is `"#bfbfbf"`); anything else is a run-time error.
* **Colour cycle**, per axes, in this order: `#0072bd #d95319 #edb120 #7e2f8e #77ac30 #4dbeee
  #a2142f`.
* **Non-finite data**: a NaN or ±Inf `x` or `y` breaks a polyline (the segment is not drawn, as
  in MATLAB); a bar whose height is NaN is not drawn (W2's `bar(utilRemoved)`, which has NaN for
  mechanisms); NaN cells of an image are drawn white; contour cells with a NaN corner produce no
  segment. Non-finite values are ignored when the automatic axis limits are computed.
* `x`, `y` are `f64` vectors of equal length (or `i64`, converted); mismatched lengths are
  `shape mismatch`.

### 12.4 Axes decoration

`xlabel(ax, s)`, `ylabel(ax, s)`, `title(ax, s)`, `legend(ax, loc: "northeast")` (shows the
series that have a `label`, in call order; `loc` one of the eight compass names or `"best"`,
which is `"northeast"` in v1), `grid(ax, on: true)`, `xlim(ax, lo, hi)`, `ylim(ax, lo, hi)`,
`x_ticks(ax, labels)` / `y_ticks(ax, labels)` (category labels at 0, 1, …; `set(gca,
'YTickLabel', …)`), `y_reverse(ax)` (`'YDir','reverse'`), `axis_equal(ax)` (equal data units on
both axes, `axis equal`). Images are drawn with y up (MATLAB's `axis xy`) and the axes fitted to
the image (`axis tight`).

### 12.5 Geometry and scales

* **Canvas**: the SVG is `width × height` px with a white background. An overall heading, if
  `name` is set, takes a 24 px band at the top. The rest is divided into equal grid cells; each
  panel's plot area is its cell (or span of cells) minus margins of 56 px left, 16 px right, 28 px
  top and 44 px bottom (68 px right when it has a `twin_y` axis or a colorbar).
* **Limits**: by default the data range extended to "nice" ticks. The tick step is the smallest
  of `{1, 2, 5} × 10^k` that gives at most 7 intervals over the data range, computed by
  repeated multiplication and division by 10 (no `log10`); the limits are the multiples of the
  step that enclose the data. A zero data range is widened to ±1 (or ±|v|/10). Explicit
  `xlim`/`ylim` replace the default.
* **Tick labels**: the value at each tick printed with `%.{p}f`, where `p` is the number of
  decimals of the step (0 for steps ≥ 1), except that steps of 10⁶ or more, or below 10⁻⁴, use
  `%g`.
* **Coordinates** are written with `%.2f`. All layout arithmetic uses only `+ − × ÷`,
  comparisons, `floor` and `ceil`, so it is class E.
* **Legend**: a box in the requested corner, 8 px from the plot area's edges, one row of 16 px
  per labelled series (a 20 px line or marker sample, then the label), box width = 40 px + the
  widest label (§12.7).

### 12.6 Contours and images

* **Contour levels**: `levels: n` gives `n` levels equally spaced strictly inside
  `[min(Z), max(Z)]`: `min + k (max − min) / (n + 1)`, `k = 1 … n` (MATLAB chooses "nice" levels;
  Sea's are simpler and documented). Segments come from marching squares over each grid cell
  with linear interpolation along cell edges; the ambiguous saddle case is resolved by the
  cell's centre value (the mean of its four corners). Each cell's segments are written as
  separate `<line>` elements, cells in column-major order — no joining into polylines, so the
  output is simple to specify and to reproduce. With `labels: true` each level's value (`%g`)
  is written once, at the midpoint of the first segment of that level in that order.
* **Images** are embedded in the SVG as a PNG data URI (`<image href="data:image/png;base64,…">`)
  with one pixel per cell, scaled without smoothing (`image-rendering: pixelated`). The PNG uses
  uncompressed ("stored") deflate blocks, so the runtime needs no compressor. The colour map is
  Sea's own 256-entry map, defined by linear interpolation between five anchors (`#30123b`,
  `#4686fb`, `#1ae4b6`, `#faba39`, `#7a0403`), each channel rounded with `round`. A `colorbar` is a
  vertical strip with the same map and ticks.

### 12.7 Text in figures

SVG text uses `font-family="sans-serif"` and fixed sizes (heading and titles 14 px, labels
12 px, ticks 10 px). Layout that depends on text width (legend boxes) estimates it as
0.6 × font size per byte. No font metrics are read, so the output does not depend on installed
fonts; a viewer's font may make text slightly narrower or wider than the estimate.

### 12.8 Determinism and what is tested

`save_svg` writes byte-identical files on every target for identical data: element order is
the order of the calls, there are no timestamps, random ids or locale effects, and the layout
arithmetic is class E (§12.5). Text is XML-escaped (`& < > "`). A figure whose data came from
class-R computations (W2's sweep) may differ in its coordinates where those data differ.

**Plot fidelity in v1** (Decision 13 in §20): §12.5–§12.7 fix the geometry well enough to
implement and to keep stable, but the v1 tests do not pin SVG bytes derived by hand: plot tests
check that the file is well-formed XML, that it has the expected structure (one plot area per
panel, one `<polyline>`/`<path>` per line series, one `<rect>` per finite bar, one `<image>` per
image, the axis labels, titles and legend texts present), and that the bytes are identical on
both targets and every kernel variant (§17.6). A byte-exact plot specification can be added
later without changing the API.

### 12.9 Out of scope

PNG/PDF/EPS figure files (would need a rasterizer or a PDF writer), interactive figures, 3-D
plots, surfaces, log axes, annotations other than titles, labels and legends, LaTeX, font
embedding, and HTML report bundling. MATLAB's `exportgraphics(…, 'Resolution', 150)` PNGs are
replaced by SVG files in `output/`.

## 13. Timing

* `now()` returns an `f64` number of seconds from an unspecified fixed origin, from a monotonic
  clock: `clock_gettime(CLOCK_MONOTONIC)` on both targets (available in libSystem and glibc),
  converted as `sec + nsec / 1e9`. Differences of two `now()` values measure elapsed wall time
  with nanosecond resolution (an `f64` holds a nanosecond count exactly for 104 days of uptime;
  the conversion keeps sub-microsecond precision for any realistic uptime).
* The workloads' `tCompute = tic; … computeSeconds = toc(tCompute)` becomes
  `let tCompute = now()` … `let computeSeconds = now() - tCompute`.
* **Determinism caveat.** `now()` is the one library function whose value differs from run to
  run, so any output derived from it differs. The ports print it only in the report line
  `Compute time: %.3f s`, which the report comparison and the cross-target byte comparison
  exclude (§17.4). Tests never print `now()`-derived values otherwise.
* Baysick has no clock and does not need one: timing is a property of the compiled Sea program,
  implemented in Sea's runtime (§15.5), not of the compiler.

## 14. Compilation model and toolchain

### 14.1 Pipeline

```
 prog.sea ─┐
 std.sea ──┴─► sea (POSIX sh driver): header + tagged source lines on stdin
                  │   temporary directory, all passes run with it as working directory
                  ▼
   1   seaparse    stdin   ─► sea.ast   lex, parse
   2a  seacheck    sea.ast ─► sea.hir1  names, scopes, types, ranks, untyped constants,
                                        library overloads, format strings, match, ref aliasing
   2b  seaexpand   sea.hir1 ─► sea.hir  elemental instantiation per call shape, write_json
                                        expansion, constant folding, reachability
   3a  sealower    sea.hir ─► sea.lir1  inlining, fusion into loop nests, views to strided
                                        addressing, bounds checks, COW checks, temporaries
   3b  seaopt      sea.lir1 ─► sea.lir  bounds-check elimination and hoisting, invariant
                                        hoisting, strength reduction, scalar replacement,
                                        vectorization (width 2, plus width 4 for avx2)
   4   seagen_a64 | seagen_x64          sea.lir ─► sea.s: instruction selection, register
                                        allocation, frames, assembly text
                  │
   arm64-macos:   as -arch arm64 … sea.s ; ld … libsea.a libbaysickrt.a -lSystem
   x86_64-linux:  stops at sea.s (cross target, as Baysick); on Linux: as --64 ; gcc (link only)
                  ▼
            native executable (runtime's main → the program's sea_main)
```

Each pass is an ordinary Baysick program (Baysick 0.6.0), compiled once with `baysick` into a
native executable. Passes communicate only through text files with fixed names in the
temporary directory (Baysick `FILES` names are fixed at compile time, LANGUAGE.md §7.21), and
report through their exit status and standard error. The number of passes (seven programs, plus
the second code generator) follows from the size calibration of §14.7; it is part of Decision 2
in §20.

### 14.2 The driver: `sea`

A POSIX `sh` script (name: Decision 15 in §20):

```
sea build <file.sea> [-o <out>] [--target arm64-macos|x86_64-linux] [-S]
                     [--emit ast|hir|lir] [--keep-temps]
sea run <file.sea> [-- program arguments…]          build into the temporary directory, run
sea --version | --help
```

**Why a shell script.** A Baysick program cannot start processes, and Sea's compiler needs
several passes plus the system assembler and linker; the driver only sequences them. `/bin/sh`
exists on both hosts, and the script needs nothing beyond POSIX utilities (`mktemp`, `sed`,
`awk`, `tail`, `rm`).

**Steps of `sea build`:**

1. Locate the installation directory (the script's own directory, resolved) holding the pass
   executables, `std.sea`, and per target `libsea.a` and `libbaysickrt.a`.
2. Check the source lines (`LC_ALL=C awk`): a line over 4096 bytes is reported as the compile
   error `line too long` (§3.1) before any pass runs, because a Baysick `LINPUT` of a line over
   65 536 bytes would stop pass 1 with a Baysick error instead of a Sea diagnostic.
3. `mktemp -d` a temporary directory; `cd` into it.
4. Write the **pass-1 input stream** to the standard input of `seaparse`:

   ```
   #sea 1
   #target arm64-macos
   #file <path of std.sea>
   |<line 1 of std.sea>
   …
   #file <file.sea as given>
   |<line 1 of the program>
   …
   #end
   ```

   Every source line is prefixed with `|`, so no source text can be mistaken for a header line,
   and an empty source line is still a line (`|`). This is the "options on stdin" protocol
   (Baysick has no command-line arguments, by decision, LANGUAGE.md §15.1).
5. Run the passes in order. Each pass copies the header records to the start of its output
   file, so every later pass knows the target and the file names for diagnostics.
6. **End-of-input discipline.** Baysick ends a program with exit status 0 on `OUT OF DATA` and
   on the end of input met by a plain `INPUT` or `LINPUT` (LANGUAGE.md §7.15, §15.2), so a pass
   bug could otherwise look like success. Therefore every pass:
   * reads its input only with `LINPUT #k` after an `IF END #k` test (`k` = 0 for pass 1's
     standard input, else its input file), never with plain `INPUT`/`LINPUT`;
   * requires the final record `#end` of its input, and stops with status 11 (`internal error:
     truncated input`) if the input ends without it;
   * writes `#end` as the last record of its own output, after everything else;
   * reads its `DATA` tables with counted loops whose counts are checked against a sentinel
     value at the end of each table.

   The driver additionally checks that each output file ends with the line `#end` before it
   starts the next pass.
7. Pass exit statuses: **0** success; **10** a Sea compile error (the pass has written the one
   diagnostic line of §9.1 to standard error with `PRINT #-1` and ended with `STOP 10`);
   **11** an internal consistency check failed (message on standard error); **1** a Baysick
   run-time error inside the pass (a compiler bug or a Baysick limit; Baysick's message is on
   standard error). Status 0 without a final `#end` in the output is treated like 11. The driver
   stops at the first failure.
8. `-S`: copy `sea.s` to the output. `--emit X`: stop after the pass that writes `sea.X` and
   copy it. Otherwise (arm64-macos): assemble and link exactly as Baysick does (DESIGN.md §4.3,
   §5.2: `as -arch arm64 -mmacosx-version-min=11.0`, `ld … -lSystem -syslibroot <sdk> -e _main`,
   the SDK from `xcrun --show-sdk-path`, never a made-up `SDKROOT`, and `SDKROOT` removed from
   the tools' environment). `x86_64-linux` is a cross target: `sea build` writes the `.s`, and
   `sea/tests/cross*.sh` assemble and link it on the Linux host (§17.6).
9. Remove the temporary directory unless `--keep-temps`.

**Driver exit statuses** (same meanings as Baysick's, DESIGN.md §4.2): 0 success; 1 Sea compile
error; 2 usage or file error; 3 toolchain error (`as`/`ld`/`xcrun` missing or failing); 4
internal error (pass status 1 or 11, a missing `#end`, out of memory). Driver messages start with
`sea: `.

### 14.3 What the compiler emits, and why

**Decision: the compiler emits target assembly text directly, one code generator pass per
target; it does not reuse Baysick's IR or backends, and it does not emit C.**

* **Not Baysick IR.** Baysick's IR (`docs/IR.md`) is an in-memory binary structure inside the
  Baysick compiler, with a dump format but no reader; every value in it is a double, it has no
  integers, vectors, pointers or loops, and its opcodes are BASIC statements. Making Baysick
  read a Sea-shaped IR would mean writing a second compiler inside Baysick's assembly.
* **Not C.** A C compiler is a giant dependency (priority 3) and would take the exact
  operation-order guarantee (§6.8) out of Sea's hands (contraction defaults, vectorizer
  reassociation flags).
* **Assembly text from a Baysick program is practical.** Baysick 0.6.0 reads lines verbatim
  (`LINPUT`), slices and builds strings (`SEG$`, `POS`, `&`, `STR$`, `CHANGE`), structures a
  program into recursive subprograms (`SUB`/`CALL`), keeps tables in arrays of up to 10⁶
  elements, and writes text files (`PRINT #`). The calibration programs of §14.7 do exactly this.
  The system assemblers do the encoding.
* **Speed does not need a sophisticated backend in the first place.** The hot paths of the
  workloads are (a) dense kernels (GEMM, factorizations, sort), which are hand-written assembly
  in the runtime and called; (b) fused element-wise loops, which pass 3 builds as simple
  counted loops whose bodies pass 4 maps to SIMD instructions one to one; and (c) scalar loops
  (SOR, LCG, RK4, bisection), which need a register allocator and decent instruction selection,
  not global optimizations. §16 states what code each must become.

### 14.4 Intermediate files

All intermediate files are line-oriented text: one record per line, fields separated by one
space, an opcode first, the header records first and `#end` last (§14.2). Numbers in records are
written so that a Baysick program reads them without precision loss: integers below 10⁹ in
decimal (Baysick's `VAL` reads at most 9 digits, LANGUAGE.md §6.1), larger integers and every
`f64` as 16 hexadecimal digits of the 64-bit pattern (`#3FB999999999999A`), strings as
`%`-escaped bytes. The exact record formats (`passes.txt`, §14.6) are written in phase 0 (§19)
as part of the compiler half of the document split (§0, step 1), with an `--emit` dump test for
each, like Baysick's IR.md §5.

**LIR** is a linear, typed, three-address code over virtual registers (`i64`, `f64`, `ptr`,
`v2f64`/`v4f64`, `mask`) with explicit structured loops (`loop` / `endloop` with an induction
register), loads and stores with base + index·scale + offset addressing, calls to runtime entry
points, and the reproducibility rules of §6.8 built in (no reassociation, no FMA opcode). It
plays the role Baysick's IR plays for Baysick's backends, but is lower level.

### 14.5 The standard library: intrinsics, runtime, prelude

| Part | Contents |
|------|----------|
| **Compiler intrinsics** (passes 2–3) | operators, views, indexing, `len rows cols numel`, conversions, `where`, reductions (fused into loops), the elemental math functions (inline code or runtime calls), `printf`/`format` (pre-parsed formats), and **`write_json`**, which pass 2b expands per static type into calls of the runtime's JSON emitter (§11.4) — so no generics or reflection are needed |
| **Runtime** (assembly, `libsea.a`, §15) | memory, strings, number-to-text conversion, I/O, clock, the elementary functions, sorting, linear-algebra kernels, the JSON emitter, and the **plotting library**: the `Figure`/`Axes` handle objects, layout, SVG writer and PNG/base64 encoder (§12.1) |
| **Prelude** `std/std.sea` | what is naturally written in Sea with value semantics: `linspace`, `meshgrid`, `setdiff`, `bincount` (marked **(P)** in §10) |

**Decision: the prelude is Sea source streamed to pass 1 ahead of the program on every
compilation**, and pass 2b drops every function the program does not reach. It is small (an
estimated 100–200 lines once plotting and JSON live in the runtime), its functions are inlined
and fused into the program's loops (which needs their source in the same compilation), and the
compiler then needs no separate-compilation, interface-file or library machinery. This is an
implementation decision, not a language one: the user sees only the predeclared names.

**Why plotting and JSON are not prelude code.** The first draft put them in the prelude, but Sea
v1 cannot express them: `Figure`/`Axes` need reference semantics (Sea has values and no
globals); `write_json` takes any struct type (Sea has no generics or reflection); the PNG
encoder needs bit operations (Sea has none); and building a 150 KB file by repeated immutable
`str` concatenation is quadratic. Each could be solved by a language feature (handle types
definable in Sea, generics, `i64` bitwise operators, a byte-buffer type), but none is otherwise
needed by any workload, so v1 keeps the language small and puts these pieces in the runtime and
the compiler. The cost is runtime assembly on two targets (§14.7 estimates it).

### 14.6 Contract files

As in Baysick, everything shared between separately written components is pinned in files that
change only together with the matching doc section:

| File | Contents | Shared by |
|------|----------|-----------|
| `sea/include/limits.inc` | the limits of §3.1 and the capacity limits of §14.7 | passes, runtime, tests |
| `sea/include/errors.inc` | every compile-time and run-time error text, with codes | passes (messages), runtime (`_sea_err`) |
| `sea/include/rt.inc` | array, string and handle layouts, entry-point names, error-site table layout, kernel variant ids | pass 4 (both), runtime (both targets) |
| `sea/include/passes.txt` | the record opcodes and fields of every intermediate file | all passes |
| **Baysick's `include/runtime.inc`** (cross-repository) | `MV_*` (matrix views), `KS_*` (kernel statuses), `KV_*` (variant records), `KF_*` (feature bits), and the `_bsk_kern_*` entry points of Baysick DESIGN.md §6.6 | Sea's runtime, which `.include`s it from the Baysick checkout; a change there is a change to Sea's contract too, so Baysick's contract rule (CLAUDE.md) covers it, and a Sea test assembles Sea's runtime against the current file |

The `.inc` files follow Baysick's dual-assembler rules (DESIGN.md §3.4). Baysick programs
cannot `.include`, so the passes get the same numbers and texts from `passes.txt` and
`errors.inc` through generated `DATA` blocks: `sea/tools/` contains a small Baysick program that
reads the contract files and writes the `DATA` lines, and a test checks that every pass's `DATA`
block is current. (Error texts must be `DATA`, not string constants: §14.7.)

### 14.7 Living within Baysick's limits, and the size of the compiler

**Baysick facts that shape the compiler** (Baysick LANGUAGE.md):

| Baysick rule or limit | Consequence |
|-----------------------|-------------|
| 10 000 stored lines per program; one statement per line; `REM` lines count | the compiler is several programs (§14.1); comments are kept short and dense |
| `IF … THEN` only jumps to a line number | every conditional action costs a jump and a line; control flow is the main line cost (measured below) |
| scalar names are a letter plus at most one digit (286 per unit); 26 array letters per unit; no global variables | each pass keeps its state in a few 2-D tables, passed to every `SUB`; scalars are local to each `SUB` |
| at most 16 parameters per `SUB`/`CALL` | at most 8 tables per pass are passed everywhere (below), leaving 8 parameters for scalars; related arrays are packed into one 2-D table |
| arrays: ≤ 10⁶ elements, bounds inclusive (`DIM N(99999,8)` is 100 000 × 9 = 900 000 elements), `DIM` bounds constant | the capacity limits below |
| numeric constants: at most 9 mantissa digits (`2147483647` is `ILLEGAL CONSTANT`) | larger constants are built by arithmetic (`214748364 * 10 + 7`) or carried as hex limbs |
| string constants outside `DATA`: ≤ 65 536 bytes in the whole program (`TOO MANY LABELS`) | error texts, instruction templates and keyword tables are `DATA` strings (which do not count); string constants are kept to short delimiters |
| string `=` ignores trailing blanks, and `SEG$` past the end returns `""`, which then equals `" "` | the passes never compare a possibly blank-terminated string with `=`: they compare lengths first, or work on character codes from `CHANGE` (as the calibration lexer does) |
| `OUT OF DATA` and the end of input on a plain `INPUT`/`LINPUT` end the program with status 0 | the end-of-input discipline of §14.2 |
| `FILES`: ≤ 8 names, fixed at compile time | each pass uses ≤ 2: its input file (pass 1 reads standard input as file 0) and its output |
| 1024 active `CALL`s, 2 097 152 words of activations | recursion only in the parser, bounded by the nesting limit 64; later passes iterate over post-order records |
| 1000 `FOR` statements per program | counted in each pass by a build check; a pass near it is split |

**Table layout and the capacity limits derived from it.** The largest pass (2a) needs these
tables; every other pass uses a subset of the same layout:

| Table | `DIM` | Elements | Rows | Fields |
|-------|-------|---------:|-----:|--------|
| `N` nodes | `N(99999,8)` | 900 000 | 99 999 | kind, operator, first child, next sibling, type, line, column, symbol, flags |
| `Y` symbols | `Y(49999,9)` | 500 000 | 49 999 | name string, kind, type, scope, declaring node, flags, offset, … |
| `T` types | `T(19999,7)` | 160 000 | 19 999 | kind, element type, rank, extent 1, extent 2, struct id, field list, flags |
| `W` work stack | `W(199999)` | 200 000 | — | scope stack, worklists |
| `C` constants | `C(19999,4)` | 100 000 | 19 999 | four 16-bit limbs of an `f64`/`i64` bit pattern |
| `S$` strings | `S$(199999)` | 200 000 | 199 999 | identifiers, string literals, file names (interned) |

Six tables, passed to every `SUB` (6 of 16 parameters). Hence the **capacity limits**
(compile errors `program too large: %s`): at most 99 999 AST nodes, 49 999 symbols, 19 999
types, 19 999 numeric constants and 199 999 distinct strings per compilation (prelude included);
expression nesting ≤ 64, ≤ 64 parameters per function, ≤ 64 fields per struct. At an estimated
6–10 nodes per source line, about 10 000–16 000 source lines fit. The workloads are 300–440 lines
of MATLAB each and the prelude an estimated 100–200 lines.

**Size calibration (item measured, not guessed).** Two representative pieces were written in
Baysick and run (scratch programs, not part of the repository):

* **Lexer core** (`lex.bas`, 188 lines, 12 of them `REM`): reads the `|`-tagged stream with
  `IF END #0`/`LINPUT #0`, works on `CHANGE` codes, recognises identifiers, keywords (table in
  `DATA`), integer and float literals with `_` and exponents, strings with five escapes, all
  operators with longest match, `//` comments, and the newline rules 1 and 2 of §3.7; writes one
  token per line; reports errors with `PRINT #-1` and `STOP 10`. It lexed the 442 lines of Sea in
  this document's examples (4 304 tokens), and the same repeated 20 times (8 840 lines, 86 000
  tokens) in 0.02 s on the
  development Mac. Missing for a complete §3 lexer: block comments, hex literals, `\x`/`\u`/`\r`
  escapes, literal validity rules, column numbers, rule 3 (`else`), token records with
  positions. Judged to be about 60 % of the lexer.
* **Expression parser** (`expr.bas`, 145 lines): precedence climbing over the 8 binary levels
  of §6.1 with non-associative comparisons, unary `-`/`!`, right-associative `^` with a signed
  right operand, parentheses, calls, indexing with argument counts, field access, error
  messages; recursive `SUB`s sharing 4 arrays and a cursor; writes postfix. Missing: ranges,
  `:` and `$`, named and `ref` arguments, array/struct/record literals, `if` expressions, AST
  records with positions. Judged to be about 25 % of the expression parser.

From these: the full lexer ≈ 300–350 lines, the expression parser ≈ 550–700, statements, items,
types and patterns ≈ 700–1 000, the header protocol, error handling and record output ≈ 200–300;
**pass 1 ≈ 1 800–2 400 lines**. The measured density is about 1.5–2 Baysick lines for each line
an equivalent C implementation would have (jump-only `IF`, one statement per line), which is the
factor applied to the later passes, sized by the rules they implement in this document:

| Pass | Estimate (Baysick lines) | Basis |
|------|-------------------------:|-------|
| 1 `seaparse` | 1 800–2 400 | measured pieces above |
| 2a `seacheck` | 6 000–9 000 | §4–§9 and §11.1 rules: scopes, types, ranks, conversions, overloads of ~80 library functions, format checking |
| 2b `seaexpand` | 2 500–4 000 | elemental instantiation, `write_json` expansion, folding with exact arithmetic (§14.8), reachability |
| 3a `sealower` | 5 000–8 000 | inlining, fusion, views, checks, COW, temporaries |
| 3b `seaopt` | 3 000–5 000 | the §16.2 optimizations, scalar replacement, vectorization |
| 4 `seagen_a64`, `seagen_x64` | 4 000–7 000 each | instruction selection (templates in `DATA`), linear-scan allocation, frames, error-site tables |
| **total** | **≈ 26 000–42 000** | eight programs |

The uncertainty is large (±50 % on the later passes); the estimate is recalibrated when pass 1
exists (phase 1, §19). Passes 2a and 3a may approach the 10 000-line limit; the response is
Decision 2 in §20 (split further, or grow Baysick). Runtime assembly per target, by analogy with
Baysick's runtimes (9 000 and 11 000 lines): core runtime 8 000–12 000 lines, plotting and JSON
2 500–4 000, Sea's own kernels (GEMV, LU/Cholesky panels, triangular solves, eigenvalues, sort,
elementary functions in scalar and vector forms) 6 000–10 000 — all estimates.

### 14.8 Numbers inside the compiler

The passes run as Baysick programs, whose numbers are doubles, which cannot represent ∞ or NaN,
and whose arithmetic stops the program with `OVERFLOW` or `DIVISION BY ZERO` before any check of
the result could run (LANGUAGE.md §5.4); `SQR` takes `sqrt(|x|)`. Therefore:

* **Float literals** (§3.4) are converted to their exact IEEE bit pattern by pass 1 with exact
  big-integer arithmetic (decimal digits × 10^e as a big integer or rational in arrays of 16-bit
  limbs, then rounding to 53 bits, ties to even), and carried as hex in every later file. The
  assembler only ever sees `.quad 0x…` patterns. Test vectors for the converter come from the
  IEEE definition (hard-rounding cases included), §17.2.
* **Constant folding** (pass 2b) folds an `f64` operation only when its operands are finite
  constants that a Baysick number can hold, and only after checking, **before** the operation,
  that it cannot fail in Baysick or produce a non-finite result:
  * `a + b`, `a − b`: both exponents (computed exactly by scaling by powers of two) at most 1022;
  * `a × b`: the sum of the exponents at most 1022;
  * `a ÷ b`: `b ≠ 0` and the difference of the exponents at most 1022;
  * `sqrt(a)`: `a ≥ 0` (folded with Baysick's `SQR`, which is the correctly rounded root for
    `a ≥ 0`);
  * the constants `inf` and `nan`, and any operation whose operand is one of them, are never
    folded; neither are transcendental functions, `pow`, or `%`.

  Underflow is harmless (Baysick produces subnormals silently, as IEEE does). Folding uses
  Baysick's own IEEE operations, which are exactly the run-time operations, and folds only
  subtrees that are constant on their own (`2 * pi * rpm / 60` folds `2 * pi` only, §6.8).
* **`i64` arithmetic** beyond 2⁵³ (literals, overflow checks of folded constants, the magic
  numbers for division by a constant) uses multi-limb integer routines in the pass that needs it.

### 14.9 Self-hosting is not a goal

The Sea compiler stays a Baysick program. Sea is a numerical language: it has no recursive data
structures, no maps, no pointer types — the things a compiler is made of — and adding them for
the compiler's sake would work against the language's purpose. Writing the compiler in Baysick
is also the point of the Baysick project.

## 15. Runtime

`libsea.a`, hand-written assembly per target (`sea/runtime/arm64_macos/`,
`sea/runtime/x86_64_linux/`), in Baysick's style (CLAUDE.md "Assembly style"; module prefix
`_sea_`), linked with libSystem / glibc for the system interface (`write`, `open`, `mmap`,
`clock_gettime`, `snprintf` for exact number conversion), and with Baysick's runtime archive for
the GEMM kernel (§15.3). No other dependency.

### 15.1 Memory layout and allocation

* **Arrays.** A dynamic array value is a pointer to a header (layout in `rt.inc`): reference
  count (u64), element kind (u8), rank (u8), rows (u64), cols (u64; 1 for vectors), capacity in
  elements (u64), data pointer (64-byte aligned, `rows × cols` elements, column-major).
* **Strings**: reference count, length, bytes (not NUL-terminated).
* **Handles** (`Figure`, `Axes`, `Lu`, `Chol`): reference-counted runtime objects with private
  layouts.
* **Small blocks** (≤ 4 KiB) come from per-size-class free lists refilled from 1 MiB chunks.
* **Large blocks** (> 4 KiB) come from `mmap`. A freed large block goes to a cache keyed by its
  size rounded up to a power of two (at most 8 blocks per size and 256 MiB in all; beyond that it
  is unmapped), and an allocation takes a cached block of its size class first. So W2's
  `zeros(242, 242)` (468 KB) in each FSD iteration reuses the previous iteration's block and
  costs one fill.
* Allocation failure → `out of memory` (§9.2).
* **Fixed-size arrays and structs** are inline: in registers, in the stack frame, or inside a
  containing array or struct.

### 15.2 Ownership and the cost model

* **Reference counting**, non-atomic (programs are single-threaded). A count changes when an
  array is stored into a variable, a struct field or an array of structs, returned, or goes out
  of scope — never per element.
* **Borrowing** removes most count traffic: an ordinary (non-`ref`) parameter is a borrow (the
  caller holds the value for the duration of the call), so calls cost no count operations;
  temporaries consumed by one operation are moved, not counted.
* **Copy-on-write**: before the first write to an array through a variable (an element store or
  a `ref` parameter write), the code checks that the count is 1 and otherwise copies the buffer
  and drops one reference. Pass 3 hoists this check out of loops when the variable is not
  reassigned or shared inside the loop, so an element store in a hot loop is a plain store.
* **Cost model** for the programmer: assignment, argument passing, returning and field storage
  of arrays are O(1); the first write after sharing copies once; element access is a load or
  store (plus a bounds check where not eliminated); fixed-size arrays never allocate.

### 15.3 Kernels, and what is shared with Baysick

**Linking.** Sea programs link Baysick's own `libbaysickrt.a`. Its kernel files (`rt_kinit.s`,
`rt_k*.s`) reference no symbol outside themselves except libc (Baysick DESIGN.md §6.6.1, "link
isolation"), and the linker pulls an archive member only for an undefined symbol: Sea's runtime
defines its own `main`, so only `rt_kinit.o` and the `rt_k*.o` objects are loaded (plus `getenv`,
`strcmp`, `sysctlbyname` from libc). No separate kernel archive is needed. A Sea build test
checks the link map, so a future Baysick change that broke this would be caught.

**What Sea uses from Baysick: the GEMM kernel only**, through `_bsk_kern_gemm`, plus the
dispatch entry points (`_bsk_kern_init`, `_bsk_kern_features`, `_bsk_kern_use`,
`_bsk_kern_variants`). Element-wise operations, copies, fills and transposes are Sea's own fused
loops (§16.1), so Baysick's `add`/`sub`/`scale`/`copy`/`fill`/`trn` kernels are not used, and
neither is its Gauss–Jordan `inv`.

**Why GEMM cannot be used unchanged** (Baysick DESIGN.md §6.6.1): `_bsk_kern_gemm` computes only
`C = A·B` (no accumulation, no α/β), so it cannot do the trailing update `C ← C − A·B` of a
blocked LU or Cholesky; its preconditions require every input element to be finite and every
extent ≥ 1, while Sea arrays may hold ∞/NaN and may be empty. Sea handles this as follows
(Decision 5 in §20 chooses between this and owning a GEMM in Sea):

* **Empty operands** never reach a kernel: Sea's runtime returns the zero matrix of the result
  shape for an empty inner dimension, and an empty result for an empty outer one.
* **Baysick's kernel contract grows** (a runtime change in Baysick, not a language change,
  §18): (a) an update entry `_bsk_kern_gemm_sub(C, A, B)` computing `C ← C − A·B` with the same
  blocking and class-R rules (the micro-kernel loads `C` instead of starting from zero; the
  packing is shared); (b) the finite-input precondition of both GEMM entries is replaced by
  "non-finite inputs propagate by IEEE rules", which requires that no kernel path skip a
  multiplication because a factor is zero and that padding never mixes with real lanes in a
  stored result — to be verified on Baysick's three variants by tests with ∞/NaN inputs. Baysick's
  MAT layer keeps its own `KS_NONFINITE` handling unchanged.
* **Column-major mapping.** A Baysick view `MV` (`runtime.inc`) is `rows × cols` with row stride
  `ld`. A Sea `r × c` column-major matrix with column stride `ld` is exactly the view `c × r` with
  stride `ld`, i.e. `Aᵀ`. So `C = A @ B` is `_bsk_kern_gemm(C', B', A')`, where `X'` is the
  row-major view of `Xᵀ`: it computes `Cᵀ = Bᵀ Aᵀ`, which is `C` in column-major.

**Sea's own kernels** (in Sea's runtime, following Baysick's kernel rules — views, statuses, no
allocation, no printing, FPCR/MXCSR untouched — and its variant discipline): GEMV in the pinned
class-E order (§10.8); LU with partial pivoting and Cholesky (panel factorization in Sea's
kernel, trailing updates through `_bsk_kern_gemm_sub`); triangular solves with many right-hand
sides; the `rcond` estimator; symmetric eigenvalues (tridiagonal reduction + implicit QL, small
sizes); radix sort with an index permutation; the scalar and vector forms of the elementary
functions.

### 15.4 CPU-feature dispatch

At startup the runtime calls `_bsk_kern_init`, which detects the CPU features and selects a
Baysick variant — reading `BAYSICK_KERNELS` (Baysick DESIGN.md §6.6.3). A Sea program must not
depend on a Baysick variable, so the runtime then **always re-selects**: if `SEA_KERNELS` names a
usable variant or is `baseline`, it calls `_bsk_kern_use` with that name; otherwise (unset,
empty, `auto`, unknown) it calls `_bsk_kern_use` with the first name of `_bsk_kern_variants()`,
the best usable variant. `BAYSICK_KERNELS` therefore has no effect on Sea programs. The chosen
variant also selects:

* Sea's own kernel variants (a variant table of the same shape as Baysick's, keyed by the same
  feature bits from `_bsk_kern_features`);
* the **fused-loop variant** of compiled code on x86_64: pass 3b emits each vectorized loop twice
  (2-wide SSE2 and 4-wide AVX2) and the loop's entry tests a runtime flag. On arm64 there is one
  NEON form (2-wide, unrolled).

Because every class-E operation gives the same bits in every variant (§6.8, §10.5), the variant
changes speed, never output, except for class-R results.

### 15.5 Runtime services

| Area | Contents |
|------|----------|
| start-up | `main`: stack (§15.6), kernel selection (§15.4), stdout buffer, then the program's `_sea_main`; exit flushes |
| memory | allocate / free / count operations / COW copy; array constructors |
| errors | `_sea_err(code, site)`: §9.2, with a site table (source file, line) emitted by pass 4 |
| strings | concatenation, comparison, `lower` |
| formatting | the pre-parsed `printf` engine (§11.1): integers by own code; finite `f64` through `snprintf` with a built single-conversion format; NaN/Inf and `%d`-on-`f64` per MATLAB |
| JSON | the emitter that `write_json` expands into (§11.4), with `%.17g` numbers, a 64 KiB buffer |
| plotting | `Figure`/`Axes` objects, layout, SVG writer, PNG (stored deflate, CRC-32, Adler-32) and base64 (§12) |
| I/O | buffered stdout/stderr; `make_dir`; errno → fixed message table |
| clock | `now()` via `clock_gettime(CLOCK_MONOTONIC)` |
| math | `log exp sin cos pow hypot`, scalar and vector forms with identical results (Decision 6): table-driven range reduction and polynomials, one algorithm for both targets, using only IEEE `+ − × ÷ sqrt` and exact integer operations (no FMA, which SSE2 lacks — the cost is part of Decision 1), verified ≤ 1 ulp against high-precision references (§17.2); `round` on x86_64 (§6.7) |
| sort | radix sort of `f64`/`i64`/`str` keys with stable permutation |
| linear algebra | §15.3 |

### 15.6 Stack and process

`main` runs the program on a 64 MiB stack mapped with a guard page (Baysick's program-stack
technique, DESIGN.md §6.9), with an alternate signal stack and a `SIGSEGV`/`SIGBUS` handler that
turns a fault in the guard page into the run-time error `stack overflow`. Any other signal keeps
its default action. Programs ignore `SIGPIPE` and report a failed write as `cannot write`
(status 1).

### 15.7 Two targets, one behaviour

The two runtimes implement the same entry points with the same results, as Baysick's do
(arm64-macos native, x86_64-linux cross-compiled and tested on the Linux host). Everything a
program prints is byte-identical on both targets except class-R values (§17.6).

## 16. Performance model

### 16.1 Fusion

**What fuses.** Pass 3a turns each statement whose right side is an **element-wise tree** into
one loop nest over the result shape, with no temporary arrays. An element-wise tree is built
from: element-wise operators and comparisons; broadcasts of scalars and of `.col`/`.row`/size-1
dimensions (as stride-0 addressing); elemental library functions; elemental user functions
(inlined); `where`; conversions; views (`.T`, `.flat`, `.col`, `.row`); slices with constant or
loop-invariant strides; index-vector gathers (as indexed loads); masked selections on the same
mask (`Tn[colorIn] - Tc[colorIn]` iterates the mask once); ranges as values; `meshgrid` and
`linspace` results consumed element-wise (their formulas are inlined); struct-array projections.

**Reductions fuse with their producer**: `max(abs(Tn[colorIn] - Tc[colorIn]))`,
`nnz(gc >= LSL & gc <= USL & gh <= hotMax)`, `mean(gc)`, `sum(wEdge * (T[0, :] - T[1, :]))` each
become one pass with no temporary, keeping the pinned reduction order (§10.5).

**Multi-output elemental calls** fuse into one loop writing several arrays (W1's
`shaft_safety` on the grid computes `nf` and `ny` in one pass; unused outputs are not computed).

**Adjacent statements fuse** when they are element-wise over the same iteration space in the
same block, and no statement reads another's result at a different element: W1's bisection
iteration (`mid`, the safety factors, `up`, `lo`, `hi`, §2.1) becomes one loop per iteration,
and `mid`, `nfv`, `nyv`, `up` are never stored (they are dead after the sequence).

**Barriers** (operands are materialized first): `@`, `solve` and the other §10.8 functions;
sorting and searching; concatenation (`[A, B]` is built in one copy pass); calls of
non-elemental functions.

**Aliasing.** When the target of an assignment is also read by the right side, the loop writes
in place only if every element is read before it is written in the loop's order — always true
when the right side reads the target only at the same element (`lo = where(up, mid, lo)`) — and
otherwise a temporary is used (`T[1..ny-1, :] = …` reading shifted `T`).

**Vectorization.** A fused loop over contiguous (unit-stride) data is emitted with vector
registers: 2 × f64 (NEON `v` registers, SSE2 `xmm`) unrolled ×4, and 4 × f64 (AVX2 `ymm`) in the
x86_64 AVX2 copy, plus a scalar tail. Each lane performs the scalar operation sequence of its
element (§6.8), so vector and scalar code give identical bits. Elementary functions in a vector
loop call the runtime's vector forms (§15.5). `if` expressions and `where` become selects
(`bsl`; `andpd`-`andnpd`-`orpd`) when both arms are cheap and cannot fail (§6.10); otherwise the
loop is scalar with branches.

### 16.2 Scalar loop code quality

The scalar hot loops of the workloads must compile to tight register code. Requirements on
passes 3 and 4:

* every scalar local of an inner loop lives in a register when the loop's live values fit
  (arm64: 28 usable general and 32 FP registers; x86_64: 14 and 16);
* loop-invariant loads (array headers, data pointers, extents, struct fields) are hoisted;
* 2-D addressing is strength-reduced (`T[j, i]` → pointer increments of 8 and `8·ld`);
* bounds checks are removed for induction variables ranging within `0..extent` of the indexed
  dimension (including `j ± 1` when the range is `1..ny-1`), for indices proven by a dominating
  comparison (`if i == 0 { … } else { T[j, i-1] }`), and the remaining checks are a compare and a
  never-taken branch to a cold block;
* `i64` multiply/add overflow checks are a flag test (`adds`/`b.vs`, `jo`); `% c` and `idiv` by a
  positive constant use multiply-high sequences;
* division of `f64` by a constant is a true division unless the constant is a power of two
  (§6.8); `x / 4` becomes `x * 0.25`.

**What the hot loops must become** (instruction counts are design targets, checked by
inspecting the `-S` output in phase 5 of §19; not measurements):

* **W5 `lcg_fill`**: one loop of ≈ 10 instructions: the multiply, the modulo by 2147483647 via
  multiply-high and shifts, one overflow check (`s < 2³¹` is not provable), `scvtf`/`cvtsi2sd`,
  one `fdiv`/`divsd` by the constant, one store, the loop branch. The dependency chain per step
  is the integer multiply and modulo only.
* **W4 scalar SOR**: the inner `j` loop keeps `dMax`, `omega`, the column pointers and the loop
  bounds in registers; per point ≈ 20–25 instructions: one byte load of `fixed`, five `f64`
  loads, the additions in source order, `×0.25`, one subtraction, one multiplication, one
  addition, `fabs`, compare-and-select for `dMax`, one store. The loop is latency-bound by the
  dependency on `T[j-1, i]` written in the previous iteration; that is inherent in the
  lexicographic SOR the workload specifies, and Sea must not reorder it.
* **W3 RK4**: `qc_deriv` inlined four times (it satisfies §8.6's inlining rule); the state `x`,
  `k1`…`k4` (16 doubles) in FP registers; no calls and no memory traffic except the road samples
  and the output stores.
* **W1 scalar bisection**: `shaft_safety` inlined into the bisection loop; `pow` is the only call.
* **W2 assembly**: `ke` and `idx` in registers, the 4 index checks hoisted per element, 16
  load-add-store updates.

### 16.3 Small fixed-size values

`T[n]` and `T[r,c]` (≤ 256 elements) and structs are scalar-replaced by pass 3b when every
access uses constant indices after inlining and unrolling: each element becomes its own virtual
register (W3's `f64[4]` state; W2's `f64[4,4]` `ke`). Otherwise they live in the stack frame.
They never touch the heap. Fixed-size arithmetic (`x + h2 * k1`) is unrolled; pass 4 may pair
lanes into 2-wide vector operations when that does not change the operation sequence.

### 16.4 Allocation in hot loops

* Fused loops allocate nothing except their result.
* **Buffer reuse**: assigning a new array value to a variable whose current buffer has the same
  shape and a count of 1 writes into that buffer (`mid = 0.5 * (lo + hi)` in a loop allocates
  once). Pass 3a applies it whenever the old value is dead at the assignment.
* Temporaries that must be materialized inside a loop (barrier operands) get a buffer hoisted
  out of the loop and reused when the shape is loop-invariant.
* Remaining per-iteration allocations come from the small-block free lists or the large-block
  cache (§15.1): W2's `zeros(nDof, nDof)` per FSD iteration is a cache hit plus a 468 KB fill.

### 16.5 Estimated effect on the workloads (estimates, not measurements)

Planning estimates from instruction counts and kernel rates, to be replaced by the measurements
of §17.5. They show where the time should go, not a promise:

| Workload | MATLAB best compute | Where Sea's time should go |
|----------|--------------------:|----------------------------|
| W1 | 0.528 s | ≈ 260 k scalar `shaft_safety` evaluations with one `pow` each (only one branch of `kb` runs); 40 fused grid iterations; well under 0.1 s expected |
| W2 | 1.053 s | ≈ 400 dense factorizations of 241 × 241 (Cholesky ≈ 4.7 MFLOP each) and the 1441-RHS triangular solves; dominated by GEMM-rate updates; a few tenths of a second expected |
| W3 | 0.650 s | 480 k RK4 steps at a few tens of ns each, plus ≈ 0.96 M `sin` for the road (16001 × 60); around 0.1 s expected |
| W4 | 0.901 s | 31 M latency-bound SOR updates (≈ 20 cycles each by the add-chain latency) plus ≈ 1500 fused half sweeps; roughly 0.2–0.4 s expected |
| W5 | 0.810 s | 11 M LCG steps, 3 M `log` and 3 M `cos`, two 1 M-element sorts, 26 fused stack-ups over 7 M elements; roughly 0.1–0.3 s expected |

W4 and W5 are the workloads where Sea's margin over MATLAB is expected to be smallest, because
their dominant costs (a sequential dependency chain; memory traffic) are not things a compiler
can remove. Decision 1 in §20 states what the exactness rules cost on top.

### 16.6 What is not done

No automatic parallelism (single-threaded, like the kernels and the benchmark rules); no
reassociation or contraction for speed (§6.8, Decision 1); no loop interchange or tiling of user
loops (the programmer's loop order is the operation order); no profile-guided or link-time
optimization beyond pass 2b's whole-program reachability.

### 16.7 Benchmark methodology

**Kernels** (`sea/bench/`): Baysick's methodology (`docs/BENCH.md`) unchanged — single-threaded
on both sides, a monotonic clock, untimed warm-up, ≥ 5 repetitions and ≥ 1 s per measurement,
the median reported with min and max, validation before timing, the vendor library (Accelerate /
OpenBLAS / the vendor libm) as one bar and the measured instruction-set peak as the other, machine,
load and variant recorded. Sea's own kernels (GEMV, LU, Cholesky, triangular solve, sort, vector
`log`/`exp`/`sin`/`cos`/`pow`) are measured this way, in Baysick's TSV format. The harness may be C
(built with `xcrun cc` / `gcc`), as Baysick's `bench/` is, because it is a measuring tool and
never part of Sea.

**Workloads versus MATLAB** (§17.5) cannot follow the kernel rules exactly, and the differences
are stated rather than hidden:

* **Threads.** The MATLAB baseline ran with MATLAB's default thread count (`run_all.m` does not
  call `maxNumCompThreads`), so its BLAS/LAPACK calls (W2's solves) may use several cores; Sea is
  single-threaded. The comparison is "Sea against MATLAB as users run it", which favours MATLAB.
  A single-threaded MATLAB run is requested as part of Decision 7, to report alongside.
* **Repetitions.** The baseline is the best of 3 runs (first run included), with visible
  variance (W2 compute 1.05 / 1.44 / 1.74 s). Sea is therefore compared with the **same rule:
  best of 3** consecutive runs (the first included); the median and spread of 10 further runs
  are reported next to it but not used for the pass/fail. Decision 7 asks for a MATLAB rerun
  with more repetitions so both sides can be compared on medians.
* **Same machine**: the comparison is valid only on the machine that produced the baseline,
  which must be recorded (§17.5).

## 17. Testing and conformance

### 17.1 Principles (Baysick's, unchanged)

* **Expected outputs are derived from the specification, never from what the implementation
  prints.** If they disagree, the implementation is wrong unless the spec is changed on purpose.
* Every normative rule of §3–§13 has at least one test; every error message has a test that
  produces it.
* Both targets must pass the same tests byte for byte (§17.6).
* No placeholder expected files: a test whose expected output cannot be derived by hand from the
  spec is not added until the spec says enough. (This is why v1 plot tests are structural,
  §12.8.)

### 17.2 Test layout

```
sea/tests/
  programs/NAME.sea   + NAME.out (expected stdout)  [+ NAME.in (stdin), NAME.args (one argument
                      per line), NAME.err (expected stderr), NAME.status (expected exit status),
                      NAME.files/ (fixtures copied into the working directory),
                      NAME.expect/ (files that must exist afterwards, byte-exact)]
  errors/NAME.sea     + NAME.err (the expected compile-time or run-time diagnostic) + NAME.status
  passes/NAME.sea     + NAME.ast | NAME.hir | NAME.lir (the --emit dumps, pinned like Baysick's
                      tests/ir)
  plots/NAME.sea      + NAME.struct (the expected structure of each SVG it writes, §12.8)
  math/               elementary-function accuracy and identity tests
  link/               the link-map check of §15.3
  run.sh              Mac runner;  cross.sh, cross_pack.sh, cross_run.sh: Linux, as Baysick's
```

Test names carry the spec area: `lex_*`, `type_*`, `idx_*`, `op_*`, `stmt_*`, `fn_*`, `elem_*`,
`err_*`, `lib_*`, `fmt_*`, `json_*`, `plot_*`, `la_*`, `perf_*`.

* **Format tests** compare `printf` output for chosen values against the bytes the C99 rules give
  (the expected bytes are worked out from the exact binary values, including tie cases).
* **Literal-conversion tests** pin the bits of hard decimal-to-binary cases.
* **Folding tests** check that expressions near the limits of §14.8 (overflowing products,
  division by zero, `sqrt` of a negative constant, `inf`/`nan` operands) compile, are not
  folded, and give the IEEE results at run time.
* **Elementary-function tests** (`math/`) check the ≤ 1 ulp bound against reference values
  computed at high precision (the reference generator is a script run with `uv run --with
  mpmath`; Python is only ever run through `uv`), check that results which are exactly
  representable (`pow(2, 10)`, `exp(0)`, `log(1)`) are exact, and check that scalar and vector
  forms and both targets give identical bits.
* **Plot tests** (`plots/`): a `.struct` file lists, per SVG, the expected counts of plot areas,
  polylines, markers, bars, images and `<line>` contour segments, and the exact texts (titles,
  labels, legend entries, tick labels) — all derivable from §12 by hand for tiny figures — and
  the runner checks well-formed XML, the structure, and identical bytes on both targets.
* **Linear-algebra tests** use exact data (small integer matrices with exact factorizations and
  solutions), as Baysick's product tests do, so even class-R results are exact and identical,
  plus ∞/NaN propagation tests and empty-operand tests.
* **Pass-protocol tests** feed each pass a truncated input (no `#end`) and check status 11, and
  check that the driver rejects a pass output without `#end` (§14.2).

### 17.3 Workload acceptance

`sea/ports/w1_shaft_design.sea` … `w5_tolerance_mc.sea` are the ports. `sea/tests/accept.sh`
(both targets) for each port:

1. builds it; runs it in a fresh directory with `--export-reference`, capturing stdout;
2. checks the JSON against `sea/workloads/reference/<name>.json` with `compare.py`'s rules, run
   as `uv run --no-project --with numpy python reference_py/compare.py --candidate <dir>
   <name>`. The `--candidate` option (a change to the workload repository, Decision 7 in §20)
   compares `<dir>/<name>.json` instead of the NumPy file with the same `RULES`, with one
   stricter rule for the near-tie keys: for an `argmax_tol`/`argmin_tol` key (W2's `r_worst`,
   `e_crit0`), the candidate's index must be **exactly** the first 1-based position of the
   extremum of the candidate's own exported array (`util_removed`, `fos0`), NaN ignored, and the
   MATLAB array's value at that index must be within the rule's `rel` of the MATLAB extremum.
   The first condition is structural: a port that forgot to add 1 points at the element before
   its own extremum and fails even if that element is a near-tie of MATLAB's;
3. checks the report (§17.4);
4. with `--figures`, checks that the SVG files exist, are well-formed XML and have the panels and
   series of the MATLAB figure (one structural file per port, written from the MATLAB script);
   their content is not compared with MATLAB's PNGs.

Indices in the JSON must be MATLAB's 1-based numbers (the port adds 1, Appendix D); the keys
with `exact` rules (`rank`, `k_worst`, `i_best`, `lcg_final`, counts, …) check this.

### 17.4 Report equivalence

**Reference text.** The MATLAB report text is not stored yet. Decision 7 in §20 adds a
`diary`-based capture to `run_all.m` (each script's report written to
`reference/<name>.txt` on the last repetition) and asks the user to rerun MATLAB once.

**Token map.** Each port has a file `sea/ports/<name>.tokens` that says how each numeric token
of the report is judged. One line per report-line pattern:

```
<line regex>  <token number>  <rule>
```

where the regex matches the report line (POSIX extended, anchored), the token number counts
blank-separated tokens from 1, and the rule is one of `compare.py`'s rule kinds applied to the
two tokens read as numbers. A token is **numeric** if it parses as a number after removing at
most one trailing `,`, `;` or `:` (the removed character must be the same on both sides).
The rules are: `exact`, `int n`, `num atol rtol`, or `json <key>` (use the rule of
that JSON key; for a key whose rule is relative to the key's largest magnitude, the scale is
taken from the reference JSON). A numeric token not listed is judged by the **default rule**:
equal as text, or differing only by ±1 in the last printed digit (a value within rounding of a
print boundary). Example (W5; the report lines are those of Appendix D):

```
^Rejects:              2   int 2
^Rejects:              5   int 2
^Rejects:              8   int 2
^Rejects:             14   num 4e-4 0
^Histogram:            8   int 2
^Histogram:           10   int 2
^Histogram:           13   int 2
```

(`Rejects:` token 14 is the yield in percent, whose JSON rule `yield` is 4e-6 absolute on the
fraction; `Histogram:` tokens 8, 10 and 13 are the underflow, overflow and fullest-bin counts,
judged like `hist_counts`.)

**Equivalence.** A Sea report is equivalent to the MATLAB report when both have the same number
of lines and, line by line: the line `Compute time: … s` is skipped on both sides; the lines
have the same number of tokens; non-numeric tokens are identical; numeric tokens pass their
rule. The token maps are written from the MATLAB scripts' `fprintf` formats and the JSON rules,
never from Sea output (§17.1), and reviewed with the port.

### 17.5 Workload benchmarks

`sea/bench/workloads.sh`, on the machine of the MATLAB baseline:

* builds each port once (compile time reported separately);
* runs it 3 times, then 10 more times, each with `--export-reference` in a fresh directory,
  measuring whole-process wall time with a small exec-and-wait harness
  (`clock_gettime(CLOCK_MONOTONIC)` around `posix_spawn` + `waitpid`), and reading the program's
  own `Compute time` line;
* reports, per workload: the first run, the best of the first 3 (the pass/fail number, the same
  rule as MATLAB's baseline, §16.7), and the median and range of the 10 further runs; compute
  and whole-process; next to MATLAB's first and best from `baseline_timings_matlab.json`, and the
  ratios; plus machine model, macOS version, kernel variant, load average before and after
  (BENCH.md conventions);
* **passes** when, for every workload, Sea's best-of-3 whole-process time < MATLAB's best
  `total_seconds` and Sea's best-of-3 compute time < MATLAB's best `compute_seconds` (§1.2).

If the MATLAB rerun of Decision 7 happens, the same script also compares medians against the
new baseline's medians and reports the single-threaded MATLAB numbers; the pass criterion then
uses whichever baseline the user chose in that decision. The same script runs on the Linux host
for the x86_64 numbers (reported, not compared with MATLAB, which has no Linux baseline).

### 17.6 Cross-target identity

* **Spec tests**: standard output, standard error, exit status and written files are
  byte-identical on `arm64-macos` and `x86_64-linux` (and for every kernel variant, run with
  `SEA_KERNELS=<variant>`). Tests involving class-R operations use exact data (§17.2).
* **Ports W1, W4, W5** use no class-R operation: their reports (except the compute-time line),
  JSON and SVG files must be byte-identical across targets and variants.
* **Port W3** uses class-R operations in exactly two places: `eig_sym` for the natural
  frequencies (`f_nat`) and the 3 × 3 `solve` of the parabolic refinement (`c_best`). Its road
  (`sin(argR) @ Ak`, a class-E matrix-vector product) and its whole RK4 simulation are class E.
  So all of W3's outputs except `f_nat` and `c_best` (and the report tokens that print them)
  must be byte-identical across targets; those two are compared with the acceptance rules.
* **Port W2** solves with `chol`/`lu` (class R) throughout; its outputs are compared across
  targets with the acceptance rules (§17.3–§17.4), not byte for byte. Its `K @ u0` reactions
  are class E given the same `u0`.
* `x86_64-linux` output is produced by the cross scripts as Baysick's are (`sea/tests/cross*.sh`
  on the ssh host, default `desktop`).

## 18. What Baysick must grow

### 18.1 Needs of the compiler, against Baysick 0.6.0

Every need of the compiler, checked against Baysick 0.6.0 (`docs/SEA_BOOTSTRAP.md` §2 rows and
LANGUAGE.md), with the calibration of §14.7:

| Compiler need | Baysick 0.6.0 | Sufficient? |
|---------------|---------------|-------------|
| read the source verbatim, detect end of input | `LINPUT #0` + `IF END #0` | yes, with the `#end` discipline (§14.2), because plain end of input exits with status 0 |
| options, file names | stdin header (§14.2) | yes, by the no-argv decision |
| input/output files per pass | `FILES` (≤ 8, fixed names), `PRINT #`, `LINPUT #` | yes: ≤ 2 per pass |
| diagnostics and failure status | `PRINT #-1`, `STOP e` | yes |
| strings: length, substring, search, concatenation, codes | `LEN SEG$ POS & ASC CHANGE STR$` | yes, avoiding the blank-padding traps (§14.7) |
| numbers to text | `STR$` (exact for integers < 10⁹) and digit arithmetic | yes |
| exact `f64` bit patterns, big integers | doubles exact below 2⁵³, arrays as limbs (§14.8) | yes |
| constants above 9 digits | built by arithmetic or read from `DATA` | yes, awkward |
| program size | 10 000 lines per program, 16 `SUB` parameters, no globals | **tight**: eight programs of an estimated 26 000–42 000 lines in all, two of them possibly near 10 000 (§14.7) |
| tables | arrays ≤ 10⁶ elements, 2-D string arrays, by-reference array parameters | yes, giving the capacity limits of §14.7 |
| message and template text | string constants ≤ 65 536 bytes outside `DATA` | yes, by keeping text in `DATA` |
| writing assembly text | `PRINT #` of strings writes bytes unchanged | yes |

**Conclusion.** No Baysick language change is needed to start, and none is proposed now. The
honest risk is size: the line limit and the absence of globals make the larger passes long and
repetitive, and the estimate of §14.7 could put a pass near 10 000 lines. §18.3 states the
policy for that case; Decision 2 in §20 asks the user to agree it in advance.

### 18.2 Changes to Baysick's runtime kernel contract

The GEMM reuse of §15.3 needs a **runtime contract change in Baysick** (no language change):

1. a new entry point `_bsk_kern_gemm_sub(C, A, B)`: `C ← C − A·B`, same view rules, statuses,
   blocking and class-R rules as `_bsk_kern_gemm`, implemented in all three variants
   (`baseline`/`neon` on arm64, `sse2`/`avx2` on x86_64);
2. the finite-input precondition of `_bsk_kern_gemm` and the new entry is replaced by IEEE
   propagation of non-finite inputs, with tests on every variant (Baysick's own MAT statements
   keep their `KS_NONFINITE` checks);
3. Baysick's `include/runtime.inc` and DESIGN.md §6.6 change together (Baysick's contract rule),
   and Sea's `rt.inc` names the Baysick version it was built against.

The link-isolation property Sea relies on (`rt_kinit.o` + `rt_k*.o` pulled alone from
`libbaysickrt.a`, §15.3) is already a Baysick rule; a Sea link test watches it. No new archive
or build target is needed. Decision 5 in §20 offers the alternatives (Sea owns its GEMM, or a
shared kernel repository).

### 18.3 Growth policy for the language

If a measured need appears (a pass that cannot be written within a limit), the response is, in
this order:

1. **Restructure without Baysick changes**: split the pass into two programs with an
   intermediate file; move text to `DATA`; pack tables; build constants by arithmetic.
2. **Grow Baysick only on a measured need**, one change at a time, through Baysick's own
   process (spec first in LANGUAGE.md, `include/*.inc` with its doc section, tests on both
   targets), preferring a feature from a later Dartmouth edition where one exists, and
   otherwise a clearly labelled Baysick extension (LANGUAGE.md §15).

**Candidates**, with their status (none is proposed now):

| Limit | Candidate change | Dartmouth precedent | When |
|-------|------------------|---------------------|------|
| 10 000 lines per program | raise the 10 000-line limit (line numbers already go to 99 999) | none in the editions implemented (Second–Sixth); a **Baysick extension** | only if a pass cannot be split cleanly (its tables would have to be written and re-read) |
| no global variables; 16 `SUB` parameters | a `COMMON`-style shared block between the main program and its subprograms | Dartmouth's Fifth Edition `CHAIN`/`COMMON` concerns separate programs, not subprograms; this would be a **Baysick extension** | if table-passing overhead or parameter count becomes a measured problem |
| 16 parameters per `SUB` | more parameters | none; **Baysick extension** | only with the previous row rejected |
| 65 536 bytes of string constants | larger limit | none; **Baysick extension** | not expected: text lives in `DATA` |
| 1000 `FOR` statements per program | larger limit | none; **Baysick extension** | not expected (estimate: a few hundred per pass) |
| two-character variable names | longer names | the later Dartmouth editions' long names are not verified against a primary source here; treat as a **Baysick extension** unless such a source is found | readability only; not expected to be needed |

### 18.4 Watch list

| Limit | Expected use | If reached |
|-------|--------------|------------|
| 10 000 lines per program | 2 000–9 000 per pass (estimate, §14.7) | §18.3 |
| 1000 `FOR` statements per program | a few hundred per pass (estimate) | split the pass |
| 26 array letters per program unit | 6–8 tables per pass | pack tables into 2-D arrays |
| 10⁶ elements per array | the tables of §14.7 | lower a capacity limit or split the table |
| 1024 active `CALL`s | parser recursion ≤ nesting 64 × about 5 levels | iterative parsing of operator chains |

## 19. Milestones

Each phase ends with its "done when" checked by tests on **both targets** (the x86_64 side
through the cross scripts), spec text before code (the house workflow), and nothing left
half-built. Phases 0–2 build the skeleton end to end on the smallest real program.

| # | Phase | Done when |
|---|-------|-----------|
| 0 | **Agreement and contracts.** The decisions of §20 are taken; the document is split into LANGUAGE.md and DESIGN.md with the intermediate record formats (§0); `sea/include/*.inc`, `passes.txt`; the Baysick kernel contract change of §18.2 (in Baysick, by its own process); `compare.py --candidate`, the token maps' format, and `run_all.m` report capture, with the MATLAB rerun if chosen (Decision 7) | the user has agreed the documents; include checks pass on both assemblers; Baysick's tests pass with the new GEMM entry |
| 1 | **Scalar core, arm64.** Driver with the `#end` discipline; passes 1–4 for: `i64`/`f64`/`bool`, `let`/`var`, arithmetic with the §6.8 rules, `if`/`while`/`for` ranges, functions with scalar parameters, `ref`, multiple results, `printf` with `%d %f %e %g %s`, `now()`; runtime start-up, formatting, errors; float-literal conversion; **recalibration** of the size estimate of §14.7 from the real pass 1 | a Sea program running W5's LCG for 11 M steps prints `lcg_final` = 2145635252 (the reference value) and the first uniforms bit-exact; spec tests for this subset pass; the estimate is updated in the document |
| 2 | **x86_64 target.** `seagen_x64`, the x86_64 runtime for the same subset, `cross*.sh` | the phase-1 tests pass byte-identically on the Linux host |
| 3 | **Elementary functions.** Sea's own scalar `log exp sin cos pow hypot` on both targets (Decision 6) | `math/` tests pass on both targets: ≤ 1 ulp against the high-precision references, identical bits on both targets |
| 4 | **Arrays and structs.** Dynamic and fixed arrays of `f64`/`i64`/`bool`/`str`, indexing, slices, masks, `$`, views, bounds checks, COW, broadcasting, element-wise operators (one loop per operation at first), reductions in the pinned order, `linspace`, `zeros`…, `sort`/`argsort`, `find*`, `bincount`; structs, arrays of structs and projection, records, `str` and `match`, `error`, `args()` | W4's scalar SOR solver reproduces `it_sor` (±1 rule) and `T_max`; W5's sampling and statistics reproduce `first_dev`, `mean_cold`, `std_cold`, `hist_counts` using the `Dim` struct array of Appendix D |
| 5 | **Scalar code quality.** Linear-scan allocation, invariant hoisting, strength reduction, bounds-check elimination, magic division | the W5 LCG and W4 SOR loops meet the §16.2 instruction shapes (checked on `-S` output); a micro-benchmark of each is recorded |
| 6 | **Functions and output.** Elemental functions, the inlining rule of §8.6, named and default arguments, `format`, `write_json` (intrinsic and runtime emitter) | W1 and W5 complete (without figures): JSON passes `compare.py --candidate`, reports equivalent, outputs byte-identical across targets |
| 7 | **Fusion and SIMD.** Statement and adjacent-statement fusion, fused reductions, vectorized loops (NEON; SSE2 + AVX2 multiversioning), vector forms of the elementary functions (bit-identical to the scalar forms), buffer reuse | W1's grid bisection and W4's red-black solver run fused (no temporaries in `-S` output); W4 complete; every earlier output unchanged bit for bit |
| 8 | **Linear algebra.** `@` via Baysick's GEMM, Sea's GEMV, LU, Cholesky, triangular solves, `solve`, `rcond`, `eig_sym`; Sea kernel variants | W2 and W3 complete and accepted on both targets |
| 9 | **Plotting.** The runtime's `Figure`/`Axes` objects, SVG writer, contours, embedded PNG images | the plot tests pass; every port writes its figure with `--figures` and passes its structural check |
| 10 | **Benchmarks.** `sea/bench/` kernel and workload benchmarks, published methodology and results | §17.5 passes for all five workloads on the baseline machine; results and machine recorded in `sea/docs/BENCH.md` |

## 20. Open decisions for the user

Each item: the options, the recommendation, and what it affects. Everything else in this
document follows from the recommendations; choosing another option changes the sections named.
Ordered by impact. (Column-major layout and the prelude's delivery are decided in the body,
§4.5 and §14.5, because no option argued otherwise.)

1. **Exactness versus speed.**
   Options: (a) **exact only**: no FMA contraction, no reassociation outside class R, Sea's own
   FMA-free elementary functions, every class-E result bit-identical on both targets (§6.8);
   (b) exact by default plus an opt-in `--fast` build mode that allows FMA contraction and FMA-
   based elementary functions (results then differ between targets and from the exact mode);
   (c) a target-dependent class: arm64 always contracts `a * b + c` (as its compilers do by
   default), x86_64 SSE2 cannot, so outputs differ by target.
   **Cost of (a), estimated (not measured):** about 0 % on memory-bound fused loops (W1 grid,
   W4 half sweeps, W5 stack-ups); up to 10–20 % on compute-bound scalar chains (W4's SOR update
   has two candidate contractions, an estimated ~15 % on that loop; W3's RK4 several); and
   elementary functions without FMA about 10–30 % slower per call than FMA-based ones. Whether
   MATLAB's own JIT contracts is not known, so (a) does not necessarily reproduce MATLAB
   better; it reproduces *itself* across targets.
   **Recommendation: (a) for v1**, and revisit (b) with phase-10 measurements: the speed goal
   has an estimated margin on every workload (§16.5), byte-identical outputs on both targets
   make every test simpler and stronger, and (b) can be added later without changing any
   program. Affects §6.8, §10.4, §15.5, §16, §17.6.
2. **Baysick growth policy and the number of passes.**
   Options: (a) the policy of §18.3 (restructure first, grow Baysick only on a measured need,
   prefer Dartmouth precedent, else a labelled extension), with eight compiler programs (§14.1)
   and no Baysick language change now; (b) raise Baysick's line limit and add a `COMMON` block
   now, before the compiler exists, so passes can be fewer and larger; (c) forbid any Baysick
   change: the compiler must fit Baysick 0.6.0 as it is, whatever the number of passes.
   **Recommendation: (a).** The calibration (§14.7) says Baysick 0.6.0 is sufficient with an
   estimated 26 000–42 000 lines in eight programs, but the estimate is ±50 %; (a) commits to
   nothing unmeasured and pre-agrees how a measured need is handled. Affects §14.1, §14.7, §18.
3. **Index base.**
   Options: (a) 0-based with half-open ranges `a..b`; (b) 1-based with inclusive ranges, like
   MATLAB and Baysick's MAT. **Recommendation: (a).** It matches the C/Rust family Sea's syntax
   comes from, half-open ranges compose without `±1`, linear and DOF indices are plain products.
   Cost: ports add 1 to exported indices, which the acceptance checks catch structurally
   (§17.3). Affects §5, every example, Appendix D.
4. **Array semantics.**
   Options: (a) values (copy-on-write) with explicit `ref` parameters for in-place updates, and
   runtime handle types for figures and factorizations; (b) references (NumPy-like aliasing);
   (c) ownership and borrowing (Rust-like moves). **Recommendation: (a).** MATLAB users'
   expectations, no aliasing bugs, O(1) passing, and `ref` makes in-place updates explicit and
   checkable. (c) is the fastest in theory but adds a borrow checker to a compiler written in
   BASIC. Affects §4.1, §4.5, §8.2–§8.3, §15.2.
5. **Kernel sharing and Baysick's GEMM contract.**
   Options: (a) link Baysick's `libbaysickrt.a` for GEMM and grow Baysick's kernel contract by
   the update entry and IEEE propagation of §18.2; Sea owns every other kernel; (b) Sea writes
   and owns its own GEMM (both targets, all variants), no Baysick change; (c) move all matrix
   kernels into a third shared repository used by both. **Recommendation: (a).** One copy of the
   hardest kernel (the register-blocked GEMM in three variants), a small and testable change to
   Baysick (the micro-kernel loading `C` instead of zero), no new repository. Cost: a
   cross-repository contract (`include/runtime.inc`, §14.6) and a Baysick change before phase 8.
   (b) costs an estimated 2 000–4 000 assembly lines per target. Affects §14.6, §15.3–§15.4,
   §18.2.
6. **Elementary functions: own or host, and which in v1.**
   Options: (a) Sea's own `log exp sin cos pow hypot` (≤ 1 ulp, identical bits on every target,
   scalar and SIMD), only these in v1 (§10.4, §10.13); (b) the host libm (Apple libm, glibc),
   like Baysick; (c) (a) with the full C set (`tan asin … tanh log2 log10`) in v1.
   **Recommendation: (a).** It makes every output except linear algebra byte-identical across
   targets (W1, W4, W5 entirely), and fused SIMD loops need vector forms, which the host libms do
   not provide on both targets. Six functions are what the workloads use; each further function
   is weeks of careful work and is added when a program needs it. With (b), §6.8 gains a
   host-dependent class and §17.6 loses the byte identity of W1/W5. Affects §10.4, §15.5, §17.6,
   §19 phase 3.
7. **Workload-repository changes and a MATLAB rerun.**
   Options: (a) change `sea/workloads/`: `compare.py --candidate` with the own-extremum rule
   (§17.3); `run_all.m` writes each report to `reference/<name>.txt` with `diary` on the last
   repetition, takes `nRepeat` ≥ 5, and records `maxNumCompThreads` and the machine model; then
   the **user reruns MATLAB once** (with the default thread count, and once more with
   `maxNumCompThreads(1)` for a single-threaded comparison), regenerating the reference files;
   (b) only `compare.py --candidate`, no rerun: reports are compared by hand, timings against the
   current 3-run multithreaded baseline. **Recommendation: (a).** Without stored MATLAB reports
   §17.4 cannot be automated, and the current baseline's variance (W2: 1.05–1.74 s) makes a
   best-of-3 comparison noisy. Which baseline (default or single-threaded) is the pass
   criterion is part of this decision; recommended: the default-threaded one, as users run
   MATLAB, with the single-threaded one reported. Affects §1.2, §16.7, §17.3–§17.5.
8. **Typing strictness and untyped integer literals.**
   Options: (a) static, signatures annotated, locals inferred, only `i64 → f64` implicit, untyped
   integer constants typed by context and a `var` initialised by one typed by its assignments
   (§4.2); (b) as (a) but untyped integer constants always `i64` unless used directly with an
   `f64` (so `var dMax = 0` followed by `dMax = d` is a type error asking for `0.0`); (c) all
   numbers `f64`, no `i64` (MATLAB's model). **Recommendation: (a).** It gives MATLAB
   programmers the obvious meaning of `var dMax = 0` and still keeps integer counters `i64`; the
   cost is one flow-insensitive pass over each function's assignments. Affects §4.2, §4.10, §9.1.
9. **Vectors as their own rank.**
   Options: (a) rank-1 `T[]` distinct from rank-2 `T[,]`, orientation written with `.col`/`.row`
   where broadcasting needs it; (b) MATLAB's model, everything 2-D. **Recommendation: (a).**
   Static loop shapes, no orientation bugs; the price is writing `.col`/`.row` in the rare
   outer-product broadcasts (W3's road grid). Affects §4.5, §5, §6.3, §6.9.
10. **Shape polymorphism.**
    Options: (a) `elemental fn`; (b) generic functions over array shapes; (c) every scalar
    function implicitly elemental. **Recommendation: (a).** Covers every workload use, keeps
    type checking simple, and is the form fusion needs; (c) hides allocation and loops behind
    ordinary-looking calls. Affects §8.5, §16.1.
11. **Surface syntax.**
    Options, as a package: (a) `*` element-wise, `@` matrix product, `.T` transpose,
    `solve(A, B)`; `^` right-associative binding tighter than unary minus; newline-terminated
    statements with the three rules of §3.7; (b) MATLAB's `.*` / `*` / `'` / `\`, left-associative
    `^`, `;` required. Individual items can be changed. **Recommendation: (a).** One meaning per
    symbol removes MATLAB's commonest bug (`*` for `.*`); `\` reads as an escape in a C-like
    language; right-associative `^` is the mathematical convention; newline statements read
    cleanly in long engineering scripts, and the one trap (a line starting with a binary
    operator) is a compile error. Affects §3.7, §6.1–§6.2, Appendix A.
12. **Can bounds checks be disabled?**
    Options: (a) no: always on, eliminated by analysis; (b) a `--unchecked` build option;
    (c) a per-block `unchecked { }` construct. **Recommendation: (a)** for v1. The checks that
    survive elimination are a compare and an untaken branch off the critical path; an option
    would create a second behaviour to test. If phase 10 shows a workload losing more than 5 %
    to checks, revisit with that measurement. Affects §5.4, §16.2.
13. **Plot format and fidelity.**
    Options: (a) SVG with embedded PNG images, geometry specified (§12.5) but v1 tests structural
    plus cross-target byte identity; (b) as (a) with every SVG byte specified and hand-derived
    byte-exact plot tests; (c) PNG files through a rasterizer. **Recommendation: (a).** It
    tests what matters for v1 (the right figure, deterministic on both targets) without
    freezing layout details before anyone has looked at the figures; (b) can follow without an
    API change. Affects §12, §17.2.
14. **Program arguments for the workloads' flags.**
    Options: (a) `args()` returns the command-line arguments, and the ports take
    `--export-reference` and `--figures` (Appendix D); (b) `getenv`, keeping the workloads'
    environment variables `SEA_EXPORT_REFERENCE`, `SEA_PLOT`, `SEA_SAVE_FIGURES`; (c) both.
    **Recommendation: (a).** Arguments are explicit at the call site and need one tiny library
    function; environment variables leak into child processes and are invisible in a command
    line. The acceptance and benchmark scripts pass the flags. Affects §10.10, §17.3, §17.5,
    Appendix D.
15. **File extension and command name.**
    Options: (a) `.sea` and `sea`; (b) `.sea` and `seac`; (c) another name.
    **Recommendation: (a).** Short and obvious; check for a clash with an existing `sea` command
    on the user's systems before release. Affects §14.2, tests, docs.

## 21. Appendices

### Appendix A. Grammar

EBNF over the tokens of §3: `{ x }` zero or more, `[ x ]` optional, `|` alternatives, terminals
in quotes, `IDENT`, `INT`, `FLOAT`, `STRING` the literal tokens, `NL` the newline token of §3.7.
`sep` separates statements; `nl` is optional newlines.

```
sep          = ( NL | ";" ) { NL | ";" } .
nl           = { NL } .

program      = nl { item sep } [ item ] nl EOF .
item         = const_decl | struct_decl | fn_decl | statement .

const_decl   = "const" IDENT [ ":" type ] "=" expr .
struct_decl  = "struct" IDENT "{" nl [ field { ( sep | "," nl ) field } [ "," ] ] nl "}" .
field        = IDENT ":" type .
fn_decl      = [ "elemental" ] "fn" IDENT "(" [ param { "," param } [ "," ] ] ")"
               [ "->" result ] block .
param        = [ "ref" ] IDENT ":" type [ "=" expr ] .
result       = type | "(" type "," type { "," type } ")" .

type         = base_type [ shape ] .
base_type    = "f64" | "i64" | "bool" | "str" | IDENT .
shape        = "[" "]" | "[" "," "]" | "[" dim "]" | "[" dim "," dim "]" .
dim          = INT | IDENT .

block        = "{" nl [ statement { sep statement } ] [ sep ] "}" .
statement    = let_stmt | var_stmt | assign_stmt | call_stmt | if_stmt | while_stmt
             | for_stmt | match_stmt | "break" | "continue" | return_stmt | block .
let_stmt     = "let" pattern [ ":" type ] "=" expr .
var_stmt     = "var" pattern [ ":" type ] "=" expr .
pattern      = IDENT | "_" | "(" pat_elem "," pat_elem { "," pat_elem } ")" .
pat_elem     = IDENT | "_" .
assign_stmt  = target assign_op expr
             | "(" tgt_elem "," tgt_elem { "," tgt_elem } ")" "=" expr .
tgt_elem     = target | "_" .
target       = IDENT { "[" index_list "]" | "." IDENT } .
assign_op    = "=" | "+=" | "-=" | "*=" | "/=" .
call_stmt    = postfix .                       (must end in a call: §7.1)
if_stmt      = "if" head_expr block { "else" "if" head_expr block } [ "else" block ] .
while_stmt   = "while" head_expr block .
for_stmt     = "for" IDENT "in" ( head_range | head_expr ) block .
match_stmt   = "match" head_expr "{" nl { arm ( sep | "," nl ) } [ arm ] nl "}" .
arm          = ( STRING { "|" STRING } | "_" ) "=>" block .
return_stmt  = "return" [ expr | "(" expr "," expr { "," expr } ")" ] .

head_expr    = expr .                          (header mode: §6.11)
head_range   = range .                         (header mode: §6.11)
range        = or_expr ( ".." | "..=" ) or_expr [ "step" or_expr ] .
expr         = or_expr .
or_expr      = and_expr { "||" and_expr } .
and_expr     = bor_expr { "&&" bor_expr } .
bor_expr     = band_expr { "|" band_expr } .
band_expr    = cmp_expr { "&" cmp_expr } .
cmp_expr     = add_expr [ cmp_op add_expr ] .
cmp_op       = "==" | "!=" | "<" | "<=" | ">" | ">=" .
add_expr     = mul_expr { ( "+" | "-" ) mul_expr } .
mul_expr     = unary { ( "*" | "/" | "%" | "@" ) unary } .
unary        = ( "-" | "!" ) unary | power .
power        = postfix [ "^" unary ] .
postfix      = primary { call_args | "[" index_list "]" | "." IDENT } .
call_args    = "(" [ arg { "," arg } [ "," ] ] ")" .
arg          = [ IDENT ":" ] expr | "ref" target .
index_list   = index [ "," index ] .
index        = ":" | range | expr .
primary      = INT | FLOAT | STRING | "true" | "false" | IDENT | "$"
             | "(" expr ")" | "(" range ")"
             | scalar_type "(" expr ")"
             | array_lit | struct_lit | record_lit | if_expr .
scalar_type  = "f64" | "i64" | "bool" | "str" .
array_lit    = "[" [ row { ";" row } [ ";" ] ] "]" .
row          = expr { "," expr } [ "," ] .
struct_lit   = IDENT "{" nl [ init { "," nl init } [ "," ] ] nl "}" .
record_lit   = "{" nl init { "," nl init } [ "," ] nl "}" .
init         = IDENT ":" expr .
if_expr      = "if" head_expr "{" nl expr nl "}" "else" ( if_expr | "{" nl expr nl "}" ) .
```

**Disambiguation rules** (each stated where it applies):

* `statement` starting with `IDENT`: an assignment if an `assign_op` follows the `target`,
  otherwise a `call_stmt`. A statement starting with `(` is a tuple assignment.
* `if` at the start of a statement is an `if_stmt`; elsewhere it is an `if_expr`.
* **Header mode** (§6.11): while parsing a `head_expr` or `head_range` — the whole header of an
  `if`, `else if`, `while`, `for` (both range bounds and the `step` expression included) or
  `match`, and the condition of an `if_expr` — the parser keeps a flag that is cleared inside
  `( )` and `[ ]` and restored after them. While it is set, `IDENT "{"` is not a `struct_lit`
  (the `{` starts the block) and `"{"` does not start a `record_lit`. Outside header mode,
  `IDENT "{"` in expression position is a `struct_lit` (pass 1 decides this from the tokens
  alone; pass 2 reports `unknown struct type` if `IDENT` is not one) and `"{"` in expression
  position is a `record_lit`. So `for k in 0..nStep {` parses `nStep` as the bound.
* `"$"` is legal only inside an `index_list`, and refers to the innermost enclosing
  `index_list`; array-literal brackets do not count (§5.3). `"(" range ")"` is the
  range-as-value form (`(0..=nBin) * binW`), a vector of `i64`.
* In `power`, the right operand is a `unary`, so `a ^ -b` parses and `a ^ b ^ c` is
  `a ^ (b ^ c)`.
* The keyword `step` ends the upper bound of a range.
* `"." IDENT` is a field access, a struct-array projection (§4.7), or one of the view suffixes
  `T flat col row` (§5.6) — the suffixes on any array, since they cannot be field names (§4.6) —
  decided by the operand's type in pass 2.
* `scalar_type "(" expr ")"` is a conversion (`f64(b)`, `i64(x)`, `str(x)`).

### Appendix B. Operator precedence

| Level | Operators | Associativity | Operand types |
|------:|-----------|---------------|---------------|
| 1 (highest) | `f(…)` `x[…]` `x.f` | left | — |
| 2 | `^` | right (right operand may be signed) | `f64` and `i64` in any combination, `i64` operands converted; result always `f64`; a constant integral exponent with \|k\| ≤ 4 is multiplication (§6.5) |
| 3 | unary `-` `!` | prefix | numeric / `bool` |
| 4 | `*` `/` `%` `@` | left | numeric (`/` always gives `f64`); `@` `f64` matrices/vectors |
| 5 | `+` `-` | left | numeric; `+` also `str` |
| 6 | `==` `!=` `<` `<=` `>` `>=` | none | numeric, `bool` (`==` `!=`), `str` |
| 7 | `&` | left | `bool` (element-wise) |
| 8 | `\|` | left | `bool` (element-wise) |
| 9 | `&&` | left | scalar `bool`, short-circuit |
| 10 | `\|\|` | left | scalar `bool`, short-circuit |
| 11 (lowest) | `..` `..=` [`step`] | none | `i64`; only in `for`, indices, `( … )` |

Assignment (`=` and compound forms) is a statement, not an operator.

### Appendix C. Keywords and predeclared names

**Keywords:** `break const continue elemental else false fn for if in let match ref return
step struct true var while`, and the type names `bool f64 i64 str`.

**Predeclared constants:** `pi inf nan eps`. **Predeclared handle types:** `Figure Axes Lu Chol`.

**Predeclared functions** (§10–§13), v1:
`abs all any args argmax argmin argsort axis_equal bar barh bincount ceil chol cols contour cos
eig_sym error exp figure filled find find_first find_last floor format grid hypot idiv image
ind2sub isnan legend len linspace log lower lu make_dir max mean meshgrid min nnz now numel ones
panel plot pow print printf rcond round rows save_svg setdiff sign sin solve sort sqrt std str
sub2ind sum title trunc twin_y variance where write_json x_ticks xlabel xline xlim y_reverse
y_ticks ylabel ylim zeros`.

(`str` is both a type name and the conversion `str(x)`; `f64`, `i64`, `bool` are conversions
through the `scalar_type "(" expr ")"` form. The later library of §10.13 adds names to this
list; adding a predeclared name can break a program that uses it as a local, which is why
§10.13 lists the planned names now.)

### Appendix D. A complete port: W5 (Monte Carlo tolerance stack-up)

W5 is the smallest workload and touches most of the language: a struct array with string
fields, string `match` validation, an exact integer LCG with a `ref` parameter, multiple results,
masks, `where`, reductions, sorting with an index permutation, binning, a formatted report,
figures, and the JSON export. The port follows `w5_tolerance_mc.m` statement by statement and
keeps its operation order (§6.8). Differences that are not just syntax are listed after the
code.

```sea
// w5_tolerance_mc.sea -- Monte Carlo tolerance stack-up of a bearing/gear axial stack
//
// Sea port of sea/workloads/w5_tolerance_mc.m (Sea acceptance workload 5). Same model, same
// numbers. Options:
//   --export-reference   write w5_tolerance_mc.json to the working directory
//   --figures            write output/w5_tolerance_mc.svg

struct Dim {
    name: str
    nom: f64      // nominal length [mm]
    tol: f64      // symmetric tolerance [mm]
    dist: str     // "normal" | "uniform" | "triangular"
    sign: i64     // +1 opens the gap, -1 closes it
    alpha: f64    // thermal expansion coefficient [1/K]
}

var exportRef = false
var figures = false
for a in args() {
    match a {
        "--export-reference" => { exportRef = true }
        "--figures" => { figures = true }
        _ => { error("unknown option \"%s\"", a) }
    }
}
let tCompute = now()

// ---------------------------------------------------------------- inputs
let dims = [
    Dim { name: "housing depth",  nom: 84.00, tol: 0.050, dist: "normal",     sign: 1,  alpha: 23.1e-6 },
    Dim { name: "gasket",         nom: 0.25,  tol: 0.040, dist: "triangular", sign: 1,  alpha: 80e-6 },
    Dim { name: "bearing 1",      nom: 19.00, tol: 0.012, dist: "normal",     sign: -1, alpha: 11.5e-6 },
    Dim { name: "spacer",         nom: 24.75, tol: 0.030, dist: "uniform",    sign: -1, alpha: 11.5e-6 },
    Dim { name: "gear hub",       nom: 22.00, tol: 0.040, dist: "triangular", sign: -1, alpha: 11.5e-6 },
    Dim { name: "bearing 2",      nom: 17.00, tol: 0.012, dist: "normal",     sign: -1, alpha: 11.5e-6 },
    Dim { name: "retaining ring", nom: 1.20,  tol: 0.030, dist: "uniform",    sign: -1, alpha: 12.0e-6 },
]
let nSample = 1_000_000      // Monte Carlo samples [-]
let seed = 7_340_117         // LCG seed [-]
let Tref = 20.0              // reference (inspection) temperature [degC]
let Tlo = 20.0               // operating temperature range, uniform [degC]
let Thi = 95.0
let LSL = 0.20               // cold end-play lower limit [mm]
let USL = 0.42               // cold end-play upper limit [mm]
let hotMax = 0.45            // hot end-play upper limit [mm]
let histLo = 0.0             // histogram range for the cold gap [mm]
let histHi = 0.6
let nBin = 60
let pct = [0.135, 2.5, 50, 97.5, 99.865]   // percentiles to report [%]
let scale = linspace(0.4, 1.6, 25)         // tolerance scaling factors for the sweep [-]
let yieldTarget = 0.9973

let nDim = len(dims)
for d in 0..nDim {
    match dims[d].dist {
        "normal" | "uniform" | "triangular" => {}
        _ => { error("dimension \"%s\": unknown distribution \"%s\"", dims[d].name, dims[d].dist) }
    }
    if dims[d].tol <= 0 {
        error("dimension \"%s\": tolerance must be positive", dims[d].name)
    }
}

// ---------------------------------------------------------------- analytic limits
var nomGap = 0.0
var wcHalf = 0.0
var rssVar = 0.0
var sigmaDim = zeros(nDim)
for d in 0..nDim {
    nomGap = nomGap + dims[d].sign * dims[d].nom
    wcHalf = wcHalf + dims[d].tol
    match dims[d].dist {
        "normal" => { sigmaDim[d] = dims[d].tol / 3 }
        "uniform" => { sigmaDim[d] = dims[d].tol / sqrt(3) }
        "triangular" => { sigmaDim[d] = dims[d].tol / sqrt(6) }
        _ => {}
    }
    rssVar = rssVar + sigmaDim[d] ^ 2
}
let rssSigma = sqrt(rssVar)

// ---------------------------------------------------------------- sampling
var s = seed
var dev = zeros(nSample, nDim)        // deviation of each dimension from nominal [mm]
for d in 0..nDim {
    match dims[d].dist {
        "normal" => {
            let u = lcg_fill(ref s, 2 * nSample)
            let u1 = u[0..$ step 2]
            let u2 = u[1..$ step 2]
            let z = sqrt(-2 * log(u1)) * cos(2 * pi * u2)
            dev[:, d] = z * (dims[d].tol / 3)
        }
        "uniform" => {
            let u = lcg_fill(ref s, nSample)
            dev[:, d] = dims[d].tol * (2 * u - 1)
        }
        "triangular" => {
            let u = lcg_fill(ref s, nSample)
            let t = dims[d].tol
            dev[:, d] = where(u < 0.5, -t + t * sqrt(2 * u), t - t * sqrt(2 * (1 - u)))
        }
        _ => {}
    }
}
let uTop = lcg_fill(ref s, nSample)
let Top = Tlo + (Thi - Tlo) * uTop
let lcgFinal = s

let nom = dims.nom
let sgn = dims.sign
let alpha = dims.alpha
let (gapCold, gapHot) = stack_gap(dev, 1, nom, sgn, alpha, Top, Tref)

// ---------------------------------------------------------------- statistics
let muC = mean(gapCold)
let sdC = std(gapCold)
let muH = mean(gapHot)
let sdH = std(gapHot)
let cpk = min(USL - muC, muC - LSL) / (3 * sdC)
let nLow = nnz(gapCold < LSL)
let nHigh = nnz(gapCold > USL)
let nHot = nnz(gapHot > hotMax)
let pass = gapCold >= LSL & gapCold <= USL & gapHot <= hotMax
let yieldMC = nnz(pass) / nSample

let binW = (histHi - histLo) / nBin
let bin = floor((gapCold - histLo) / binW)          // 0-based bin number, as f64
let inRange = bin >= 0 & bin < nBin
let counts = bincount(i64(bin[inRange]), nBin)
let underflow = nnz(bin < 0)
let overflow = nnz(bin >= nBin)
let edges = histLo + (0..=nBin) * binW

let sortedC = sort(gapCold)
let sortedH = sort(gapHot)
var pC = zeros(len(pct))
var pH = zeros(len(pct))
for k in 0..len(pct) {
    pC[k] = prctile_mid(sortedC, pct[k])
    pH[k] = prctile_mid(sortedH, pct[k])
}

var contrib = zeros(nDim)
for d in 0..nDim {
    contrib[d] = variance(dev[:, d]) / variance(gapCold)
}
let rnk = argsort(contrib, desc: true)

// ---------------------------------------------------------------- tolerance scaling sweep
var yieldScale = zeros(len(scale))
var cpkScale = zeros(len(scale))
for k in 0..len(scale) {
    let (gc, gh) = stack_gap(dev, scale[k], nom, sgn, alpha, Top, Tref)
    let ok = gc >= LSL & gc <= USL & gh <= hotMax
    yieldScale[k] = nnz(ok) / nSample
    let m = mean(gc)
    cpkScale[k] = min(USL - m, m - LSL) / (3 * std(gc))
}
let kOk = find_last(yieldScale >= yieldTarget)
let scaleMax = if kOk < 0 { nan } else { scale[kOk] }

let computeSeconds = now() - tCompute

// ---------------------------------------------------------------- report
printf("\n=== W5  Monte Carlo tolerance stack-up (%d samples) ===\n", nSample)
printf("%-15s %8s %7s %-10s %4s %9s\n", "Dimension", "nom[mm]", "tol", "dist", "sgn",
    "var share")
for d in 0..nDim {
    printf("%-15s %8.3f %7.3f %-10s %+4d %8.2f%%\n", dims[d].name, dims[d].nom,
        dims[d].tol, dims[d].dist, dims[d].sign, 100 * contrib[d])
}
printf("\nNominal gap %.4f mm; worst case %.4f .. %.4f mm; RSS 3-sigma %.4f .. %.4f mm\n",
    nomGap, nomGap - wcHalf, nomGap + wcHalf, nomGap - 3 * rssSigma, nomGap + 3 * rssSigma)
printf("Cold gap: mean %.5f, std %.5f, min %.5f, max %.5f mm, Cpk %.3f\n", muC, sdC,
    sortedC[0], sortedC[$ - 1], cpk)
printf("Hot gap : mean %.5f, std %.5f, min %.5f, max %.5f mm\n", muH, sdH, sortedH[0],
    sortedH[$ - 1])
printf("Rejects: %d below LSL, %d above USL, %d too loose when hot; yield %.4f %%\n",
    nLow, nHigh, nHot, 100 * yieldMC)
printf("Percentiles (cold / hot) [mm]:\n")
for k in 0..len(pct) {
    printf("  P%-7.3f %9.5f %9.5f\n", pct[k], pC[k], pH[k])
}
printf("Largest contributors: %s, %s, %s\n", dims[rnk[0]].name, dims[rnk[1]].name,
    dims[rnk[2]].name)
printf("Histogram: %d bins of %.3f mm, underflow %d, overflow %d, fullest bin %d\n",
    nBin, binW, underflow, overflow, max(counts))
printf("Largest tolerance scale with yield >= %.2f %%: %.2f\n", 100 * yieldTarget, scaleMax)
printf("Compute time: %.3f s\n", computeSeconds)

// ---------------------------------------------------------------- figures
if figures {
    let fig = figure(2, 2, name: "W5 tolerance stack-up")

    let a1 = panel(fig, 0, 0)
    bar(a1, edges[0..$-1] + binW / 2, counts, width: 1)
    xline(a1, LSL, style: "r--")
    xline(a1, USL, style: "r--")
    xlabel(a1, "Cold end play [mm]"); ylabel(a1, "Count")
    title(a1, "Cold end-play histogram")

    let a2 = panel(fig, 0, 1)
    barh(a2, 100 * contrib[rnk])
    y_ticks(a2, dims[rnk].name)
    y_reverse(a2)
    xlabel(a2, "Variance share [%]")
    title(a2, "Contributors")

    let a3 = panel(fig, 1, 0)
    plot(a3, scale, 100 * yieldScale, style: "-o")
    grid(a3); xlabel(a3, "Tolerance scale [-]"); ylabel(a3, "Yield [%]")
    title(a3, "Yield vs tolerance scale")

    let a4 = panel(fig, 1, 1)
    plot(a4, scale, cpkScale, style: "-s")
    grid(a4); xlabel(a4, "Tolerance scale [-]"); ylabel(a4, "Cpk [-]")
    title(a4, "Cpk vs tolerance scale")

    make_dir("output")
    save_svg(fig, "output/w5_tolerance_mc.svg")
}

// ---------------------------------------------------------------- reference export
if exportRef {
    let out = {
        workload: "w5_tolerance_mc",
        n_sample: nSample,
        lcg_final: lcgFinal,
        first_dev: dev[0..10, :],
        first_top: Top[0..10],
        nom_gap: nomGap,
        wc_half: wcHalf,
        rss_sigma: rssSigma,
        mean_cold: muC,
        std_cold: sdC,
        mean_hot: muH,
        std_hot: sdH,
        min_cold: sortedC[0],
        max_cold: sortedC[$ - 1],
        min_hot: sortedH[0],
        max_hot: sortedH[$ - 1],
        cpk: cpk,
        n_low: nLow,
        n_high: nHigh,
        n_hot: nHot,
        yield: yieldMC,
        hist_counts: counts,
        hist_underflow: underflow,
        hist_overflow: overflow,
        pct: pct,
        pct_cold: pC,
        pct_hot: pH,
        contrib: contrib,
        rank: rnk + 1,               // MATLAB's 1-based ranks
        scale: scale,
        yield_scale: yieldScale,
        cpk_scale: cpkScale,
        scale_max: scaleMax,
    }
    write_json("w5_tolerance_mc.json", out)
}

// ================================================================ functions

// n uniforms in (0,1) from the Park-Miller minimal-standard LCG (exact in i64).
fn lcg_fill(ref s: i64, n: i64) -> f64[] {
    var u = zeros(n)
    for i in 0..n {
        s = 16807 * s % 2147483647
        u[i] = s / 2147483647
    }
    return u
}

// End play at the reference temperature and at the operating temperature, with the
// deviations scaled by k. Terms are summed in chain order.
fn stack_gap(dev: f64[,], k: f64, nom: f64[], sgn: i64[], alpha: f64[], Top: f64[],
             Tref: f64) -> (f64[], f64[]) {
    let n = rows(dev)
    var gapCold = zeros(n)
    var gapHot = zeros(n)
    let dT = Top - Tref
    for d in 0..len(nom) {
        let L = nom[d] + k * dev[:, d]
        gapCold = gapCold + sgn[d] * L
        gapHot = gapHot + sgn[d] * (L * (1 + alpha[d] * dT))
    }
    return (gapCold, gapHot)
}

// Percentile of sorted data by the midpoint rule: r = p/100*N + 0.5 (a 1-based rank),
// linear interpolation, clamped to the first and last samples.
fn prctile_mid(xs: f64[], p: f64) -> f64 {
    let n = len(xs)
    let r = p / 100 * n + 0.5
    if r <= 1 { return xs[0] }
    if r >= n { return xs[n - 1] }
    let k = floor(r)                 // 1-based rank of the lower sample, as f64
    let f = r - k
    let i = i64(k) - 1               // its 0-based index
    return xs[i] + f * (xs[i + 1] - xs[i])
}
```

**Faithfulness notes** (each checked against the MATLAB script):

* **Operation order.** Every arithmetic line keeps MATLAB's association: `16807 * s %
  2147483647` is `mod(16807 * s, 2147483647)`; `s / 2147483647` is one IEEE division of exactly
  representable values (MATLAB: `s / 2147483647` on doubles); `sqrt(-2 * log(u1)) * cos(2 * pi *
  u2)`; `dims[d].tol * (2 * u - 1)`; `-t + t * sqrt(2 * u)`; `Tlo + (Thi - Tlo) * u`;
  `nom[d] + k * dev[:, d]`; `gapHot + sgn[d] * (L * (1 + alpha[d] * dT))`;
  `p / 100 * n + 0.5`. `sigmaDim[d] ^ 2` is `sigmaDim[d] * sigmaDim[d]` (§6.5).
* **Integers.** The LCG state is `i64`: `16807 · s < 2⁴⁶`, so every step is exact, as it is in
  MATLAB's doubles; `lcg_final` must match exactly. `sign` is `i64`; `sign * nom` converts ±1
  exactly, so `nomGap` has MATLAB's bits. `nnz(…) / nSample` divides two exactly converted
  integers.
* **Box–Muller pairing.** MATLAB `u(1:2:end)` and `u(2:2:end)` (1-based odd and even positions)
  are `u[0..$ step 2]` and `u[1..$ step 2]`.
* **Names.** MATLAB reuses `u` at the top level for the operating temperatures; the port calls
  that vector `uTop` because the sampling `u`s are block-scoped. MATLAB's `idx` is `bin`, and
  the export struct `ref` is `out` (`ref` is a Sea keyword).
* **Triangular samples.** MATLAB assigns the two halves through `lowHalf` and `~lowHalf`; `where`
  computes both formulas for every sample and selects, which gives the same value per element
  (both formulas are finite for `u` in (0, 1); there are no traps, §6.5).
* **Histogram.** MATLAB's 1-based `idx = floor(…) + 1` with `1 <= idx <= nBin` is the 0-based
  `bin = floor(…)` with `0 <= bin < nBin`; underflow `idx < 1` is `bin < 0`; overflow
  `idx > nBin` is `bin >= nBin`. `bincount` is `accumarray(idx(inRange), 1, [nBin 1])`.
  `edges = histLo + (0:nBin) * binW` is `histLo + (0..=nBin) * binW`.
* **Ranks.** `[~, rnk] = sort(contrib, 'descend')` is the stable `argsort(contrib, desc: true)`;
  the export adds 1 for MATLAB's numbering; the report uses the 0-based `rnk` directly.
* **`find(…, 1, 'last')`** with `isempty` is `find_last` returning −1.
* **Percentiles.** `prctile_mid` computes `k = floor(r)` and `f = r - k` in `f64` exactly as
  MATLAB does, and indexes `k − 1` and `k` (0-based for MATLAB's `k`, `k + 1`).
* **Statistics.** `mean`, `std`, `variance` use Sea's pinned summation order (§10.5); the
  differences from MATLAB's order are within the W5 tolerances (1e-11 relative for means,
  1e-10 for standard deviations).
* **Report.** The format strings are MATLAB's; `%+4d` receives the `i64` sign; `%d` receives
  `i64` counts. `scaleMax` NaN would print `NaN`, as MATLAB does (§11.1).
* **Flags.** `SEA_EXPORT_REFERENCE` → `--export-reference`; `SEA_PLOT`/`SEA_SAVE_FIGURES` →
  `--figures`, read with `args()` (§10.10, Decision 14 in §20). The JSON goes to the working
  directory (§11.3), and
  `ylim`-spanning reference lines (`plot([LSL LSL], yl, 'r--')`) are `xline`.
