# Sea Language Specification

**Status: normative. Agreed 2026-10-20** as part of the Sea design (DESIGN.md §0). This
document says what Sea programs mean: their lexical structure, types, expressions, statements and
functions, the standard library, the bytes they print and write, their errors and their exit
statuses. How the compiler and the runtime achieve it (passes, intermediate file formats, runtime
ABI, performance model, tests, milestones and the decisions behind them) is `docs/DESIGN.md`.
Every rule is written normatively ("must") so that it can become a test (DESIGN.md §6.1). A
change to a rule is made in this file together with the user's agreement, before the code that
depends on it.

**References.** "§N" is a section of this document; "DESIGN.md §N" a section of Sea's design
document; "Baysick LANGUAGE.md §N", "Baysick DESIGN.md §N" and "Baysick BENCH.md §N" are
sections of the Baysick documents in the parent repository's `docs/`. A list of sections after a
document name stays in that document up to a semicolon: `DESIGN.md §2.5, §4.2` are both sections
of DESIGN.md.

## 0. Conventions

### 0.1 Glossary

The terms of the language and its library. DESIGN.md §0.1 defines the implementation terms
(pass, HIR/LIR, fusion, variant, …).

| Term | Meaning |
|------|---------|
| **class E** | *Exact-reproducible.* A result that is bit-identical on every target and every kernel variant. The rule for everything except the class-R operations (§6.8). Same term and meaning as Baysick DESIGN.md §6.6.4 |
| **class R** | *Reassociating.* A result that may differ in the last bits between targets and kernel variants because summation order and fused multiply-add are free; deterministic for a given target and variant. Only matrix-matrix products and the factorizations of §10.8 are class R |
| **elemental function** | A function written for scalars that Sea applies element by element when called with arrays (§8.5), like Fortran's `ELEMENTAL` |
| **view** | A non-owning description of part of an array (slice, transpose, flattening) that the compiler uses instead of copying (§5.6) |
| **COW** | Copy-on-write: arrays have value semantics, implemented by sharing a buffer and copying only when a shared buffer is written (DESIGN.md §4.2) |
| **prelude** | The small part of Sea's standard library written in Sea (`std/std.sea`), compiled together with every program (DESIGN.md §2.5) |
| **intrinsic** | A library function the compiler expands itself (operators, reductions, `printf`, `write_json`, …, DESIGN.md §2.5) |
| **handle type** | A runtime object with reference semantics (`Figure`, `Axes`, `Lu`, `Chol`, §4.1) |
| **port** | A Sea program that reproduces one MATLAB workload (`sea/ports/w*.sea`, DESIGN.md §6.3) |

## 1. Scope

### 1.1 Goals

Sea's goals, in priority order (decided by the user; DESIGN.md §1 states them in full and how
they are measured): raw speed; a cleaner language than MATLAB, with modern C/Rust-like syntax
and deliberately not MATLAB-compatible; and free, tiny, portable native binaries for
`arm64-macos` and `x86_64-linux`.

### 1.2 Scope of Sea v1

What the five acceptance workloads (`sea/workloads/`) need, done well,
plus the small amount of generality that keeps the language coherent. Every feature in this
specification is required by at least one workload or by the language's own consistency (where a
library function is included for consistency, §10 says why); features that no workload needs
are listed as non-goals (§1.3) or as later library work (§10.13), not half-specified.

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
| Modules and imports, separate compilation of user code | each workload is one file; the prelude is implicit (DESIGN.md §2.5) |
| Threads, parallel loops | Baysick's kernels are single-threaded and the kernel benchmark rules compare single-threaded (Baysick BENCH.md §1); see DESIGN.md §5.6. The MATLAB workload baseline was multithreaded; DESIGN.md §5.7 states how that is handled |
| Interactive display, a REPL, a workspace | Sea is AOT; figures are files (§12) |
| PNG/PDF figure files, fonts, LaTeX labels | §12.9 |
| A debugger | the run-time error report names the source line (§9.2) |
| Self-hosting (the Sea compiler written in Sea) | DESIGN.md §2.9 |

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
apply it element by element and fuse into one loop (§8.5, DESIGN.md §5.1). The masks become ordinary
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

// vectorized bisection over the whole grid: one fused loop per iteration (DESIGN.md §5.1)
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
scatter-add compiles to 16 scalar updates (DESIGN.md §5.3). Node `a` (0-based) has the DOFs `2a` and
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
derivative evaluations make no calls and no allocations (DESIGN.md §5.3).

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
  (99 999 syntax-tree nodes, 49 999 symbols, …: DESIGN.md §2.7), which an estimated 10 000–16 000 lines
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
  (`local name shadows a predeclared name`). The prelude's own top-level declarations (DESIGN.md §2.5)
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
* Hexadecimal digits may be written in either case (`0xFF`, `0xff`, `0xFf`); the prefix is `0x`
  only.
* There is no `1.` and no `.5`: both are `invalid numeric literal` (so `a.b` field access and
  ranges `0..n` are never ambiguous).
* A literal is unsigned; `-` is an operator. An `int_lit` must be at most 2⁶³ − 1
  (`integer literal too large`), except that the operand of a unary minus may be 2⁶³, giving
  −2⁶³.
* A `float_lit` denotes the IEEE-754 binary64 value nearest to its exact decimal value, ties
  to even (what C `strtod` gives). A literal whose value overflows to infinity is
  `float literal out of range`; one that underflows is the nearest subnormal or zero. The
  compiler computes the bit pattern itself with exact integer arithmetic (DESIGN.md §2.8); it never
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

(Part of Decision 11 in DESIGN.md §9.) Consecutive NL tokens are equivalent to one. A line break inside
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
| `T[]` | dynamic vector of `T` | header + buffer (DESIGN.md §4.1) | value (COW) |
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
  (c) an element of an array literal that has an `f64` element, (d) an operand of `^` (§6.5),
  (e) the argument of an `f`, `F`, `e`, `E`, `g` or `G` conversion of `printf` or `format`
  (§11.1), or (f) an arm of an `if` expression (§6.10) whose other arm has an `f64` type;
  otherwise it is `i64` (also as the argument of `f64(…)` or `i64(…)`, §10.1). The value must
  be exactly representable in `f64` (`integer
  constant not exact in f64`, also in contexts (e) and (f): `printf("%f", 9007199254740993)` is
  that error). The check is per literal: in an `f64` context each `int_lit` of the constant
  expression must be exact, and the arithmetic is then `f64` arithmetic (`9007199254740992 + 1`
  in an `f64` context is the `f64` sum, 2⁵³, without an error). An untyped `-0` in an `f64`
  context is −0.0 (unary `-` of 0.0). So `let n = 5` is an `i64`, `if c { 0.5 } else { 2 }` is `f64` (the 2 is 2.0), `var Fbs = 0.0` is an `f64`,
  `4 * (Kf * Ma) ^ 2` multiplies by the `f64` 4, and `2 ^ 10` is the `f64` 1024.
* **A `var` initialised by an untyped constant** takes its type from all its uses in the
  function: if any assignment to it (`=`, `op=`, or as a `ref` argument to an `f64`
  parameter) stores an `f64`, the variable is `f64`; otherwise `i64`. So `var dMax = 0`
  followed by `if d > dMax { dMax = d }` with `d: f64` is an `f64` variable, as a MATLAB
  programmer expects, and `var count = 0` followed by `count += 1` is an `i64`. The rule is
  flow-insensitive (one type per variable, decided before code is generated) and applies only
  to a `var` without a type annotation whose initialiser is an untyped constant; `let` bindings
  and annotated variables follow the first rule. (Decision 8 in DESIGN.md §9.)
* **Implicit conversion `i64` → `f64`** happens, and only happens, (a) in an arithmetic or
  comparison operator with one `i64` and one `f64` operand (the `i64` operand is converted),
  (b) on assignment, initialisation, argument passing and return into an `f64` slot, and
  (c) element by element for arrays in the same positions (`i64[]` where `f64[]` is expected).
  The conversion rounds to nearest, ties to even (exact for |x| ≤ 2⁵³).
* **No implicit `f64` → `i64`**, ever. Explicit: `i64(x)` (§10.1) converts an integral
  finite `f64` and stops with the run-time error `conversion to i64: x is not an integer`
  otherwise; `i64(floor(x))` and `i64(round(x))` are the idioms.
* `bool` converts to neither implicitly. `f64(b)` and `i64(b)` give 1 or 0. `f64(x)` of an
  `f64` and `i64(x)` of an `i64` return x unchanged.

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
`rows × cols`. (Decision 9 in DESIGN.md §9.)

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
`i + j·r` of its buffer. A vector is contiguous. Buffers are 64-byte aligned (DESIGN.md §4.1).

**Rationale for column-major.** (1) The workloads' reference outputs depend on MATLAB's
column-major scan order wherever an index is reported from a linear scan: `max(dGrid(:))` in
W1 and `max(Thot(:))` and `max(qMag(:))` in W4 report the *first* maximum in column-major order,
and `find(hole)` in W4 fixes the summation order of `Qhole`. With column-major storage the
natural scans of `A.flat` (§5.6) reproduce these exactly; with row-major every such port would
need a transposed scan. (2) Linear algebra convention (LAPACK, and the column vector `A @ x`).
(3) Interop with Baysick's kernels costs nothing either way: Baysick's matrix views are
row-major with a leading dimension (Baysick DESIGN.md §6.6.1), and a column-major `r × c` matrix with
column stride `ld` *is* the row-major `c × r` view with the same `ld`; DESIGN.md §4.3 shows how every
kernel call maps.

**Element types.** `f64`, `i64`, `bool` (one byte, 0 or 1), `str` (handles), structs (inline,
fields in declaration order, §4.6). Arithmetic is defined on `f64` and `i64` arrays; logic on
`bool` arrays.

**Fixed-size arrays** (`f64[4]`, `f64[4,4]`, `i64[4]`) are plain values like scalars: the
compiler keeps them in registers or in the stack frame, never on the heap (DESIGN.md §5.3). They exist
for small state vectors and element matrices (W2's `ke` and `idx`, W3's RK4 state). An array
literal of `n` scalars has the fixed type `T[n]` when `n` ≤ 256, and the dynamic type `T[]`
otherwise (§6.9); the same for matrix literals by element count. Here and in §6.9 a *scalar* is
an `f64`, `i64` or `bool` value: an array literal whose elements are `str` or struct values is
always dynamic (`str[]`, `S[]`; Decision 20 in DESIGN.md §9), and a fixed-size array of `str` or
structs exists only by annotation (`let names: str[3] = …`, converted with the run-time check
below). A fixed-size array converts
implicitly to the dynamic type of the same rank and element type (a heap copy is made when
needed); a dynamic array is assigned to a fixed-size variable or parameter only after a
run-time shape check (`shape mismatch: expected 4, got 5`). The extents of a fixed-size type are
`i64` constant expressions (§7.2); a negative extent is the compile error `invalid array size %d`
with its value, at the first such extent (`f64[-1]` reports `invalid array size -1`).

**Value semantics.** Assigning an array, passing it as an ordinary argument or storing it in a
struct never makes two variables share mutable state: after `var B = A`, writing `B[0] = 1`
does not change `A`. The implementation shares the buffer and copies on the first write to a
shared buffer (COW, DESIGN.md §4.2), so passing and returning arrays is O(1). The one way to let a
function modify a caller's variable is a `ref` parameter (§8.3). Handle types (§4.1) are the
stated exception. (Decision 4 in DESIGN.md §9.)

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
compiler fuses it into its consumer when it can (DESIGN.md §5.1). Struct arrays are stored as arrays of
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
* **Typing is static and strict** (Decision 8 in DESIGN.md §9): every expression has one type at
  compile time; the only implicit conversions are those of §4.2 (integer literals,
  `i64 → f64`) and §4.5 (fixed-size → dynamic arrays). Dynamic extents are the only run-time
  shape information; their mismatches are run-time errors (§9.2) unless both extents are known
  constants, in which case they are compile errors.

## 5. Indexing

### 5.1 Base and ranges

* **Indices are 0-based** (Decision 3 in DESIGN.md §9): the elements of a vector of length `n` are
  `v[0]` … `v[n − 1]`, the elements of an `r × c` matrix are `A[0, 0]` … `A[r − 1, c − 1]`.
* **Ranges are half-open**: `a..b` is `a, a + 1, …, b − 1` (empty when `a >= b`); `a..=b` is
  `a … b` inclusive. A step is written `a..b step s` (`s ≠ 0`; with `s < 0` the range counts
  down: `9..=0 step -1` is `9, 8, …, 0`, and `a..b step -1` stops before `b`). The length of
  `a..b step s` is `max(0, ceil((b − a) / s))` computed exactly in integers; `step 0` is the
  run-time error `range step is zero`. Range bounds and steps are `i64`; there are no
  floating-point ranges (use `linspace`, §10.3, so the MATLAB colon's rounding subtleties
  cannot occur).
* A range used as a value (§6.1, item 11) is the `i64[]` of its positions in order. One with more
  than 2³¹ − 1 positions is the run-time error `invalid array size %d` with its length (or with
  9223372036854775807 when the length exceeds the `i64` range, as `-2^63..=2^63-1` does).

**Rationale for 0-based.** Sea's syntax family (C, Rust, Python/NumPy) is 0-based; half-open
ranges compose without `−1` corrections (`0..n`, `T[1..ny-1, :]` for the interior rows, a
split `0..k` + `k..n`); linear indices and DOF numbers are plain products (`i + j·r`,
`2a`, `2a + 1`); and red-black colouring is `(i + j) % 2`. The cost is that every port must
convert reported indices to MATLAB's 1-based numbering where the reference JSON holds them
(`rank: rnk + 1`, Appendix D), which the acceptance harness checks exactly (DESIGN.md §6.3).

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
order, exactly MATLAB's `x(mask)`. A mask of the wrong extent is `shape mismatch: %s vs %s` with
the shape of what it selects from first and the mask's shape second: for `v[m]` and for a mask
index of one dimension of a matrix (`A[m, :]`) the dimension's extent, as a vector shape, and
`len(m)` (`v[m]` with a 5-element `v` and a 4-element `m` reports `shape mismatch: 5 vs 4`); for
`A[M]` the shapes of `A` and `M` (`shape mismatch: 3x4 vs 4x3`). This check is the mask's bounds
check: it takes the mask's place among the index checks of §5.4.

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
A failure is the run-time error `index i out of bounds for dimension d of extent n` (§9.2), where
`i` is the offending index value, `n` the extent, and `d` the dimension **counted from 0**: 0 for
the rows of a matrix and for a vector's only dimension, 1 for the columns (`v[5]` on a 5-element
vector reports `index 5 out of bounds for dimension 0 of extent 5`).
There are no negative indices that count from the end (`v[-1]` is an error, not the last
element).

**Which index the message names, and in which order.** All the indices of an index expression
are evaluated (left to right, §6.8) before any of them is checked; then each index is checked
against its dimension, left to right, and the first failure is reported. Within one index the
value `i` in the message is: for a scalar index, its value; for an index vector, its first
element, in order, that is out of range; for a non-empty range, its first position `a` if that is
out of range, otherwise its last position `a + (n − 1)·s` (a range's positions are monotone, so it
is in range exactly when its first and last positions are). So `v[2..10]` on a 5-element vector
reports `index 9 out of bounds for dimension 0 of extent 5`, and `v[7..9]` reports 7. An empty
range, and `:`, never fail.

Checks are **always on** (Decision 12 in DESIGN.md §9). They cost almost nothing where it matters
because the compiler removes the checks it can prove (loop induction variables over
`0..len(v)`, `0..rows(A)`, and the like) and hoists the others out of loops (DESIGN.md §5.2); what
remains is a compare and a never-taken branch off the latency chain.

### 5.5 Indexed assignment

* `v[idx] = e` and `A[ri, ci] = e` assign the selected elements. `e` is a scalar (assigned to
  every selected element) or an array of exactly the selected shape (`shape mismatch`
  otherwise; a rank-reduced selection takes a vector).
* **Evaluation order and checks** (`=`): the right side is evaluated completely; then the
  indices, left to right; then the checks, in this order: each index against its dimension, left
  to right (§5.4; a mask's extent is its check, §5.2), then the shape of the value against the
  shape of the selection, written `shape mismatch: %s vs %s` with the **selection's shape first**
  and the value's second (`v[0..3] = [1.0, 2.0]` with a dynamic `v` reports `shape mismatch: 3 vs
  2`); then the elements are stored in increasing linear order of the selection. With an index
  vector that repeats a position, the last store wins, as in MATLAB. An error stops the program
  before any element is stored.
* **Compound assignment** `x[sel] op= e` (`+= -= *= /=`) means `x[sel] = x[sel] op e` with the
  selection evaluated once, in this order: the indices (left to right); the read of the selected
  elements, with the checks of §5.4; `e`; the operation, with the broadcasting and shape check of
  §6.3 (the selection's shape as the left operand's); the store, with the checks above. This is
  the order of the scalar `x op= e`, which reads `x` before it evaluates `e` (§7.3, §8.3): a `ref`
  argument in `e` that changes `x` is seen by the store, not by the read. W2's `K[idx, idx] += ke`
  gathers the 4 × 4 block, adds `ke`, and scatters it back — exactly MATLAB's `K(idx,idx) =
  K(idx,idx) + ke`, including the case of a repeated index.
* Masked assignment `v[m] = e` assigns where `m` is true; `e` is a scalar or a vector of length
  `nnz(m)` (the selection's shape is the vector shape `nnz(m)`).
* **Aliasing**: an assignment behaves as if its right side were computed into a temporary
  first, whatever the overlap between the right side and the target (`T[1..ny-1, :] = …T…`).
  The compiler avoids the temporary when it can prove that every element is read before it is
  written (DESIGN.md §5.1).

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
   `2 ^ 3 ^ 2 = 2 ^ 9`. (Part of Decision 11 in DESIGN.md §9.)
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
* `A @ B` is the **matrix product** (part of Decision 11 in DESIGN.md §9): matrix @ matrix → matrix
  (`r×k @ k×c → r×c`), matrix @ vector → vector (`r×k @ k → r`), vector @ matrix → vector
  (`k @ k×c → c`). Inner extents must agree (`shape mismatch`). vector @ vector is a compile
  error (`sum(a * b)` is the dot product). `@` with a scalar operand is `operator '@' cannot be
  applied to …`. Element types `f64` (an `i64` operand is converted).
* **Transpose** is the view `A.T` (§5.6).
* **Solve** is the function `solve(A, B)` (§10.8), not an operator: `A \ b` reads as an escape
  in a C-like language, and the factorization-based forms (`lu`, `chol`) need names anyway.

### 6.3 Broadcasting (implicit expansion)

For an element-wise binary operator, an elemental function call (§8.5) or `where`:

| Operands | Result | Rule |
|----------|--------|------|
| scalar, any | the other's shape | the scalar applies to every element |
| vector `n`, vector `m` | vector `n` | `n == m` required |
| matrix `r1×c1`, matrix `r2×c2` | matrix: per dimension, the common extent if `r1 == r2` (`c1 == c2`), else the extent that is not 1 | per dimension: equal, or one of them 1, and the result is the other (MATLAB implicit expansion: `0×3` with `1×3` is `0×3`) |
| vector, matrix | — | compile error `cannot combine a vector with a matrix: use .col or .row` |

So MATLAB's `xh(:) * nk + phik` (column times row plus row) is `xh.col * nk.row + phik.row`.

With more than two operands (`where(c, a, b)`, an elemental call with several array arguments)
the shapes are combined left to right, scalars skipped: the first array operand's shape with the
second's by the table, the result with the third's, and so on; a mismatch reports the shape
combined so far, then the operand's (`where(c, a, b)` with `c` and `a` of 16001 elements and `b` of
60 reports `shape mismatch: 16001 vs 60`).
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
the sign bit exactly. Subnormals are kept (never flushed to zero). A NaN's sign bit and payload
are not observable: no operation exposes a value's bits, a NaN prints as `NaN` (§11.1) and is
written as `null` (§11.4), and comparisons and `isnan` treat every NaN alike; so the targets
(and constant folding) may produce different NaN bits for the same operation.

**`i64`**: `+ - *` and unary `-` are exact; a result outside the `i64` range is the run-time
error `integer overflow` (in the evaluation of a `const`, the compile error of §7.2). `/` on two `i64` operands converts both to `f64` and divides (so
`nnz(pass) / nSample` is a fraction, as in MATLAB). `idiv(a, b)` is the floored integer
quotient. `%` is the floored modulo (below). Division or modulo by zero: `integer division by
zero`.

**Power `x ^ y`.** The result is always `f64`; an `i64` operand (typed or untyped) is
converted (§4.2), so `2 ^ 10` is 1024.0 and `n ^ 2` with `n: i64` is an `f64`.

* If `y` is a **constant** (a literal, a `const`, or a constant expression, possibly with a
  unary minus) whose value is an integer `k` with `|k| <= 4` — whether written `2` or `2.0` —
  `x ^ y` is evaluated by multiplication in this pinned order (the value of `y` is computed
  exactly, as the run time would compute it; an exponent that contains a call of any function,
  such as `sqrt(4.0)`, or a `^` that is itself not evaluated by multiplication, such as
  `4 ^ 0.5`, does not count as an integer here, whatever its value; the rule is about the exponent as written, so a `const` name counts by its value however that const was defined: with `const K = pow(4.0, 0.5)`, `x ^ K` is the multiplication `x*x`, because the exponent expression `K` itself contains no call): `x^0 = 1`, `x^1 = x`,
  `x^2 = x*x`, `x^3 = (x*x)*x`, `x^4 = (x*x)*(x*x)`, `x^-k = 1/(x^k)`. So `x ^ 2` and `x ^ 2.0`
  are the same operation. (W1's `d ^ 3` and the squares in `shaft_safety` take this path.)
* Otherwise `x ^ y` is `pow(x, y)` of §10.4.

There is no integer power; `i64` results are computed with `*`.

### 6.6 Integer division and modulo

`a % b` is the **floored** modulo, whose result has the sign of `b` (MATLAB `mod`, Python
`%`), for `i64` and `f64`:

* `i64`: `a - b * floor(a / b)` computed exactly; `b == 0` → `integer division by zero` (in the
  evaluation of a `const`, a compile error, §7.2).
* `f64`, in this order: if `b == 0` the result is `a` (so `inf % 0` is `inf` and `nan % 0` is
  NaN); otherwise if `a` is infinite or either operand is NaN the result is NaN; otherwise
  `r = fmod(a, b)` (exact, with the sign of `a`); if `r != 0` and `r` and `b` have different signs
  then `r = r + b` (rounded once). A zero result keeps the sign `fmod` gives it, the sign of `a`:
  `-6.0 % 3.0` is −0.0 and `6.0 % -3.0` is +0.0. `b = ±Inf` falls out of the rule
  (`-1 % inf = inf`, `1 % inf = 1`). These are MATLAB's `mod` results.

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
adjust), specified with the runtime (DESIGN.md §4.5). All four return `f64` (`i64(round(x))` for an
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
   multiply-add from `a * b + c` (Sea v1 has no FMA at all; Decision 1 in DESIGN.md §9 considered an opt-in
   fast mode and rejected it for v1), never computes `x / c` as
   `x * (1 / c)` unless `c` is a constant power of two (then both are the same correctly
   rounded value), never uses flush-to-zero or approximate reciprocal instructions, and never
   evaluates an `f64` expression in a wider precision.
3. **Constant folding** uses the same IEEE operations (DESIGN.md §2.8), so a folded expression has the
   bits the run-time evaluation would have had.
4. **Vectorization changes nothing**: a SIMD lane does exactly the scalar operation sequence
   of its element (DESIGN.md §5.1). Reductions have a pinned order independent of the vector width
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
1 in DESIGN.md §9 states the options and the estimated cost; the rules above are the option decided.

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
* **Strings and structs.** A literal whose elements are `str` or struct values (and none is an
  array) is dynamic whatever its size: one row is a `str[]` or `S[]`, several rows a `str[,]` or
  `S[,]` (`["bottom chord", "top chord"]` is a `str[]`, Appendix D's `[Dim { … }, …]` a `Dim[]`).
  (Decision 20 in DESIGN.md §9.)
* **Concatenation.** If any element is an array, the literal concatenates. Within a row, the
  elements are joined horizontally: scalars and vectors join into a vector (`[mats.name,
  "target"]` is a `str[]`); matrices (and scalars, as 1 × 1) join into a matrix whose row counts
  must agree (`[T[1..ny-1, 1..2], T[1..ny-1, :], T[1..ny-1, $-2..$-1]]`). Rows are then stacked
  vertically; a vector row counts as a `1 × n` matrix row. A row that mixes vectors and matrices
  is a compile error (`use .row or .col`). The result is dynamic unless all parts are fixed.
* The element type is the common type of the elements (`i64` and `f64` → `f64`; struct
  elements must all be the same struct; `str` with `str`).
* `[]` is an empty array; it needs a type from context (`let names: str[] = []`): under a
  vector type it is the vector of length 0, under a matrix type the 0 × 0 matrix, under a
  fixed-size type without elements (`T[0]`, `T[0,c]`, `T[r,0]`) that type; under a fixed-size type
  with elements it is the compile error `shape mismatch` (§4.10, the target's shape first).

### 6.10 `if` expressions

`if c { a } else { b }` is an expression when it appears where a value is expected; its arms
are single expressions of the same type (after the conversions of §4.2), and `else` is
required. `else if` chains are allowed. Only the selected arm is evaluated. Inside an elemental
function applied to arrays the compiler may evaluate both arms and select (DESIGN.md §5.1) — this is
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
`expression statement has no effect`, reported at the statement's first token whatever follows
it: `x + y = 3` is this error (`x + y` is not an assignment target). A call statement must end
after the call: `f(x) = 3` is `unexpected token '='`.

### 7.2 Bindings, mutability, scope

* `let` binds an immutable name: it can be neither assigned nor modified element-wise, and it
  cannot be passed to a `ref` parameter. `var` binds a mutable one. Both require an
  initializer: there are no uninitialized variables.
* **Patterns**: a name, `_` (evaluate and discard; `let _ = f()` discards all results of a call,
  whatever their number, including none), or a tuple pattern `(p1, p2, …)` of names
  and `_` for destructuring a multiple-result call (`let (nfv, nyv, _, _, _) = shaft_safety(…)`).
  The names of a tuple pattern take the call's result types exactly (no conversion); a tuple
  pattern cannot be annotated, because no `type` names a tuple (`let (a, b): f64 = two()` is
  `type mismatch: expected f64, found (f64, f64)`, at the call).
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
  and the calls `sqrt` and `pow`; nothing else: conversions, `if` expressions and other calls,
  `log exp sin cos hypot` included, are not constant expressions).
  (`pow(x, y)` is admitted because `x ^ y` with a non-integer exponent is that same function,
  §6.5; DESIGN.md §9 Decision 16.) A constant whose expression refers back to itself, directly or through other
  constants, is `not a constant expression`, reported at the name that closes the cycle.
  Constants may size fixed arrays (`f64[N]`). A `const` without a type annotation
  whose expression is an untyped integer constant is `i64` (`const N = 4` is the `i64` 4); with an
  annotation it has the annotated type (`const G: f64 = 9` is 9.0).
* **Every `const` is evaluated once, at compile time, to one value** (Decision U2 in DESIGN.md
  §0), whether it is used or not, with exactly the semantics of §6 that the program would have at
  run time: `i64` `+ - *` and unary `-` exactly, `%` floored (§6.6); `f64` arithmetic, `%` and
  `sqrt` as IEEE binary64 (±∞ and NaN included); `^` as §6.5 says (the pinned multiplications,
  otherwise `pow` of §10.4 with the run time's bits), and a `pow(x, y)` call with the same bits; the implicit `i64` → `f64` conversion of
  §4.2; comparisons, `&&`, `||`, `!`, `&`, `|` on `bool`. A constant whose evaluation overflows
  `i64` or divides an `i64` by zero (`%` by 0) is the **compile error** `integer overflow` or
  `integer division by zero`, reported at the operator whose evaluation fails (as in Rust),
  instead of the run-time errors of §6.5 and §6.6. A use of the constant is that one value.
* **A constant without a value.** A constant has no value when it has a compile error, when its
  evaluation fails, or when it is not evaluated: a constant whose expression names a constant
  without a value, or any part of whose expression (the whole included) has a type that could
  not be determined because of another error, or that calls a function the program declares
  under a predeclared name (`fn pow`, itself an error), is **not evaluated**, also where `&&` or
  `||` would not reach that part (`const B: bool = false && f() == 1.0` with a faulty `f` has no
  value), so its own evaluation reports nothing (`const B = 9223372036854775807 + 1 + A`
  with a faulty `A` reports `A`'s error, not an overflow in `B`). A program with a compile
  error is not compiled, so a constant without a value is never used at run time (DESIGN.md §9
  Decision 25).
* `let _: T = e` (an annotated `_`) is a single-value binding: e must have one value of type T,
  and a multiple-result call there is `wrong number of results: expected n, found 1` (§8.4).

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
  values in order. The bounds and the step are `i64` (an untyped literal is `i64`; any other
  type is `type mismatch: expected i64, found …` at that bound or step). The bounds and step are evaluated **once**, before the first iteration
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
(their reference counts decremented, DESIGN.md §4.2) at the end of the block, on `break`, `continue` and
`return`. This is invisible to the program except as memory use.

## 8. Functions

### 8.1 Definitions

```
fn name(p1: T1, p2: T2 = default, ref p3: T3) -> R { … }
fn name(…) -> (R1, R2, …) { … }
fn name(…) { … }                         no result
elemental fn name(…) -> R { … }          §8.5
```

* Top-level items only; no nested functions, no closures, no function values: the name of a
  function, a struct or a library function used as a value (not called) is `undeclared name`,
  except as the argument of a `ref` parameter, where it (or a handle type's name) is `ref
  argument must be a mutable variable, element or field` (§8.3).
* Every parameter and result type is written (§4.10). A function with a result must end every
  path with `return` (`missing return`, at the `fn`). A statement ends every path when it is a
  `return`, a block one of whose statements ends every path, or an `if` with an `else` whose
  branches (every branch of an `else if` chain) all end every path; a loop never does, whatever
  its condition (`while true { return 1 }` as the last statement is `missing return`).
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
copy is ever needed, DESIGN.md §4.2); a `var` copy inside the callee (`var lo = lo`) copies only if it is
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
  vectors: `ref argument must be a mutable variable, element or field`). The name of a function,
  a struct, a library function or a handle type given as a `ref` argument is that error too, not
  `undeclared name`.
* A `ref` argument may not share its **root variable** with any other argument of the same
  call (`ref argument aliases another argument`). The root of an argument is the variable at
  the start of its path: `dims[0].name`, `dims[k].tol` and `dims` all have the root `dims`, so
  `f(ref dims[0].nom, dims[1].nom)` is rejected even though the two elements differ. Only an
  argument that is a path (a name, element or field) has a root; any other expression
  argument (`x + 1`, a call) shares no root with anything. The check
  is on names only, at compile time, and deliberately conservative: it needs no reasoning about
  index values. (Copy the other argument into a `let` first if this is ever in the way.) It is
  what lets the callee modify `T` in place while reading `src` (W4's
  `rb_half_sweep(ref T, src, redIn, omega)`).
* `ref` replaces MATLAB's copy-in/copy-out idiom `[T, d] = f(T, …)`, which MATLAB optimizes in
  place only sometimes; in Sea the in-place update is the semantics. (Returning the array, as
  MATLAB does, is also legal Sea and also free: COW, DESIGN.md §4.2.)

### 8.4 Multiple results

`-> (R1, R2, …)` declares several results; `return (e1, e2, …)` returns them; the caller must
destructure them (`let (a, b) = f()`, `(x, y) = f()`), discard the whole call as a statement
(`f()`), or return them unchanged: `return f(…)` in a function whose result types equal `f`'s
result types exactly, in order (no conversion applies), returns `f`'s results. Otherwise
`return f(…)` of a multiple-result call is `type mismatch: expected …, found …` (each side written
as a type or a tuple `(T1, T2, …)`), or `wrong number of results: expected 0, found n` in a
function without results. A multiple-result call cannot appear inside an expression (`two() + 1`,
`f(two())`): that is `multiple-result call used as a value`, reported at the call. Binding it to
one name (`let y = two()`), or destructuring or assigning it to a tuple of another number of
names, is `wrong number of results: expected n, found m`, with n the number of `f`'s results and
m the number of names; assigning it to one target (`y = two()`) is the same error, at the call.
A call of a function without results used as a value (bound, assigned, or inside an expression)
is `wrong number of results: expected 0, found 1`, at the call. MATLAB's "ask for fewer
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
  surrounding element-wise expression (DESIGN.md §5.1).
* All built-in scalar math functions (`sqrt`, `exp`, `log`, `cos`, `min(a, b)`, `round`, `where`,
  conversions, …) are elemental.

**Rationale.** MATLAB code is shape-polymorphic because everything is a matrix; W1's
`shaft_safety` is written with masks (`kb(m1) = …`) precisely so that it works for any shape.
An elemental function is that code written as plain scalar logic, which is clearer and is also
the form a compiler can fuse and vectorize. It covers every shape-polymorphic use in the five
workloads; full generics are a non-goal (§1.3). (Decision 10 in DESIGN.md §9.)

### 8.6 Recursion and inlining

* Ordinary functions may be recursive (directly or mutually). Recursion depth is limited by the
  run-time stack (DESIGN.md §4.6): `stack overflow` is a run-time error, not a crash.
* **Inlining is an optimization the language does not observe**, with one guarantee the
  performance model relies on (DESIGN.md §5.2–§5.3), stated on the source so a programmer can check
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
  text from the error table (contract file `sea/include/errors.inc`, DESIGN.md §2.6), with
  `%s`/`%d`-style substitutions.
* The compiler stops at the **first** error, in a deterministic order: lexical and syntax errors
  in source order (pass 1), then name and type errors in source order (pass 2), then the few
  errors only later passes detect (capacity limits). A capacity limit exceeded while a pass reads
  its input (the tree it is given, before checking it) is reported at once, before any error that
  pass would report in source order. Of two errors at the same position, the one
  of the inner construct (a child before its parent) is reported. The compiled output is not
  written.
* The driver's exit status is 1 for a compile error (DESIGN.md §2.2). There are no warnings in v1: a
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

If standard output cannot be written in step 1, the line of step 2 still reports the original
error (not `cannot write`), and the status is 1.

A failed write of standard output is the run-time error `cannot write '<stdout>': %s` (the path is
written `<stdout>`, the reason from the errno table): at the line of the output call whose write
failed, or, if the write that fails is the final flush after the last statement, with **no
location**: the line on standard error is then `error: cannot write '<stdout>': %s` + LF (for
example `error: cannot write '<stdout>': Broken pipe`). The exit status is 1 in both cases
(§9.4).

The run-time error messages (texts in `errors.inc`, with substitutions):

| Condition | Message |
|-----------|---------|
| index out of range | `index %d out of bounds for dimension %d of extent %d` (the index, the dimension counted from 0, the extent: §5.4) |
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
| out of memory (also a `str` of more than 2³¹ − 1 bytes, from `+`) | `out of memory` |
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
and is reported as §9.2 says (the Baysick rule, Baysick LANGUAGE.md §15.4: a status 0 always means
every byte arrived).

## 10. Standard library

The library is specified to the level the workloads need, with its exactness class (§6.8).
"Elemental" means the function accepts arrays with broadcasting (§8.5). Where a MATLAB function
is replaced, its name is given. Every function here is class E unless marked **R**.

**Scope rule (§1.2).** v1 contains what the five workloads use, plus a small core whose
inclusion is justified in the table where it is not obvious. Everything else that a numerical
language will eventually want is listed in §10.13 ("Later") and is not part of v1: no partial
specification of it exists in this document.

**Where each function lives** (DESIGN.md §2.5): *intrinsic* (expanded by the compiler), *runtime*
(assembly in `libsea.a`), or *prelude* (Sea source, marked **(P)**).

### 10.1 Conversions and constants

| Function | Result |
|----------|--------|
| `f64(x)` | `i64` or `bool` (or arrays) to `f64`; an `f64` x is returned unchanged; an untyped integer literal argument is `i64` (§4.2); elemental |
| `i64(x)` | `f64` → `i64` if integral and in range, else run-time error; `bool` → 0/1; an `i64` x is returned unchanged; an untyped integer literal argument is `i64` (§4.2); elemental |
| `pi`, `inf`, `nan`, `eps` | `f64` constants: the double nearest π, +∞, a quiet NaN, 2⁻⁵² |
| `isnan(x)` | `bool`; elemental. Core: the only readable test for the NaN values the workloads produce (`x != x` works but is obscure) |

### 10.2 Construction and shape

| Function | Result |
|----------|--------|
| `zeros(n)`, `zeros(r, c)` | `f64[]` / `f64[,]` of zeros (MATLAB `zeros(n,1)`, `zeros(r,c)`) |
| `ones(n)`, `ones(r, c)` | of ones |
| `filled(v, n)`, `filled(v, r, c)` | a vector / matrix with every element `v`, of `v`'s type: `f64`, `i64`, `bool`, `str` or a struct (`filled(false, n)`, `filled(0.005, r, c)`, `filled("", n)`; an untyped integer `v` is `i64`, §4.2, so `filled(0, n)` is an `i64[]`) |
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
(MATLAB). A fused consumer never materializes them (DESIGN.md §5.1).

### 10.4 Elementary functions (elemental)

| Function | Definition |
|----------|------------|
| `abs`, `sign` (`-1, 0, 1`; NaN → NaN), `sqrt` (correctly rounded), `floor`, `ceil`, `trunc`, `round` (§6.7) | exact (single instructions or exact sequences) |
| `min(a, b)`, `max(a, b)` | the smaller/larger; if one is NaN the other (MATLAB); `min(-0, +0)` is the first argument |
| `log`, `exp`, `sin`, `cos`, `pow`, `hypot` | Sea's own implementations (Decision 6 in DESIGN.md §9): error ≤ 1 ulp, special values as C99 Annex F, identical bits on every target and variant and in scalar and SIMD forms. `log sin cos pow hypot` are used by the workloads; `exp` is included because `pow` is built from the same `exp`/`log` kernels, so exposing it costs nothing |
| `x % y`, `idiv(a, b)` | §6.6 |
| `where(c, a, b)` | `a` where `c` is true, else `b`; all three are evaluated in full, then broadcast |

`log(0) = -inf`, `log(-1) = nan`, `sqrt(-1) = nan`: IEEE values, no errors (MATLAB would return
complex results, which Sea does not have; no workload takes these branches).

**Argument types.** `abs`, `sign`, `min` and `max` accept `i64` or `f64` and return that type
(`min` and `max` of an `i64` and an `f64` convert the `i64`, §4.2); on `i64`, `abs(-2⁶³)` is
`integer overflow` and `sign` is −1, 0 or 1. `sign(x)` of an `f64` is 1.0 for x > 0, −1.0 for
x < 0, and x itself otherwise (±0.0 and NaN). `sqrt`, `floor`, `ceil`, `trunc`, `round`, `isnan`
and the functions `log` … `hypot` accept `f64` (an `i64` argument is converted, §4.2). In
`where(c, a, b)`, `c` is `bool` and `a` and `b` are `f64`, `i64` or `bool` of one type after the
conversions of §4.2 (an `i64` with an `f64` converts). Each accepts arrays element by element
(elemental, §8.5).

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

On `i64` vectors `sum` is exact with an overflow check (order irrelevant). `mean` of an `i64`
vector divides that exact sum by `len(v)`, both converted (§6.5's `i64 / i64`); `variance` and
`std` of an `i64` vector use that mean and the converted elements in the `f64` rule above; `max`
and `min` of an `i64` vector are `i64`. `sum`, `mean`, `variance`, `std`, `max`, `min`, `argmax`
and `argmin` accept `f64` and `i64` vectors, `nnz`, `any` and `all` `bool` vectors.

The `dim:` option is a constant expression (§7.2) whose value is 0 or 1: anything else is the
compile error `not a constant expression` or `dim must be 0 or 1`, at the argument.

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

`sort` and `argsort` accept `f64`, `i64` and `str` vectors; `desc:` is any `bool` expression.
Order for `f64`: ascending numeric order with `-0 == +0` (equal values keep their input order);
NaN after every number ascending, before every number descending (MATLAB). `str`: byte-wise.
Sorting is exact (class E) whatever the algorithm; the runtime uses an LSD radix sort on the
order-preserving 64-bit key transform for large `f64`/`i64` vectors (DESIGN.md §4.5).

### 10.7 Index utilities

| Function | Result |
|----------|--------|
| `ind2sub(r, k)` | `(i64, i64)` = `(k % r, idiv(k, r))`, elemental (`[i, j] = ind2sub(size(T), k)`) |
| `sub2ind(r, i, j)` | `i + j * r`, elemental, with a bounds check against `r` |
| `bincount(idx, n)` (P) | an `i64[]` of length `n`: the count of each value `0 … n − 1` in `idx` (`accumarray(idx, 1, [n 1])`); a value outside → run-time error |

### 10.8 Dense linear algebra

| Function | Class | Result |
|----------|:-----:|--------|
| `A @ B`, matrix @ matrix | R | GEMM (DESIGN.md §4.3) |
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
(DESIGN.md §4.3), so their rounding follows GEMM's (class R). For a given target and kernel variant every
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
| `str(x)` | `i64`: decimal; `f64`: `%.17g` (§11.4) for a finite value, and `nan`, `inf`, `-inf` for the others (C's spelling; `printf` keeps its own, §11.1); `bool`: `true`/`false` |
| `lower(s)` | ASCII lower case (W1's `switch lower(finish)`) |

### 10.10 Program environment and files

| Function | Result |
|----------|--------|
| `args()` | `str[]`: the command-line arguments after the program name (Decision 14 in DESIGN.md §9) |
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
| `d`, `i` | `i64`; `f64`; `bool` | `i64`: decimal. `bool`: `0` or `1`. `f64` (MATLAB rule): an integral finite value prints as the integer it is (exactly, any magnitude; −0.0 is the integer 0, so it prints `0`, or `+0` with the `+` flag), with C's integer rules for the flags and the precision (`%.3d` of 7.0 is `007`, `%.0d` of 0.0 prints no digits); NaN, Inf, −Inf print as `NaN`, `Inf`, `-Inf` padded with spaces to the width (non-finite values below); a non-integral value prints as `%e` with the same flags and width and precision 6, whatever precision was given (MATLAB prints `1.500000e+00` for `sprintf('%d', 1.5)`; W1 prints `L10h`, which can be NaN, with `%8d`) |
| `f`, `F`, `e`, `E`, `g`, `G` | `f64`; `i64` (converted) | C99 semantics for finite values; NaN/Inf as for `d` (MATLAB spelling, not C's `nan`/`inf`) |
| `s` | `str` | the bytes; precision truncates to that many bytes; width pads with spaces (counts bytes) |
| `%%` | — | `%` |

Any other conversion, flag combination C leaves undefined (such as `0` with `%s`, or `#` with
`%d`, `%i` or `%s`), or argument type is a compile error. Width and precision are at most
999 999 999.

**Non-finite values** (every numeric conversion, MATLAB spelling): −∞ prints `-Inf`; +∞ prints
`Inf`, or `+Inf` with the `+` flag, or ` Inf` with the space flag (as C signs `inf`); NaN prints
`NaN` and is never signed, whatever its sign bit and flags. The result is padded with spaces to
the width (on the left, or on the right with the `-` flag); the `0` and `#` flags and the
precision are ignored for non-finite values. So `%+8.2f` of +∞ is `    +Inf` and `%08d` of NaN is
`     NaN`.

**Exact output.** For finite `f64` values the digits are the **correctly rounded** decimal
representation of the exact binary value, ties to even, which is what C99 `printf` produces on
both targets' C libraries (Apple libc and glibc both convert exactly). The runtime implements a
conversion by calling the host `snprintf` with a single-conversion C format it builds from the
pre-parsed one (DESIGN.md §4.5); the non-finite and `%d`-on-`f64` cases, where C and MATLAB differ, are
handled by the runtime before calling C. The exponent of `%e`/`%g` has at least two digits
(`1.0e+06`) on both targets. Outputs are therefore byte-identical across targets for the same
argument bits. Exact ties such as `%.2f` of 0.125 print `0.12` (the C rule). **Unverified:**
whether MATLAB's `fprintf` on macOS rounds exact ties the same way has not been checked (no
MATLAB is available to the author); a difference could only appear at an exact binary tie, and
the report comparison's last-digit rule (DESIGN.md §6.4) absorbs it.

### 11.2 `print`

`print(s)` writes the bytes of `s` to standard output, nothing added. There is no implicit
newline anywhere: newlines are written by the program (`\n`).

### 11.3 Files and streams

Sea v1 writes files only through `write_json` (§11.4) and `save_svg` (§12), and creates
directories with `make_dir`; general file output is in §10.13. Paths are host paths, relative to
the process's working directory (the ports write `output/…` and `<name>.json` relative to it;
the acceptance harness chooses the directory, DESIGN.md §6.3). Standard output is buffered (64 KiB) and
flushed when full, before anything is written to standard error, and at exit. Standard error is
unbuffered and is written only by run-time errors (§9.2).

### 11.4 JSON export: `write_json(path, value)`

`write_json` is a **compiler intrinsic** (Decision recorded in DESIGN.md §2.5): pass 2 expands each call,
for the static type of `value`, into a sequence of calls to the runtime's JSON emitter
(`object begin`, `key`, `f64`, `i64`, `bool`, `str`, `array begin`, …), recursively over struct
and record fields in declaration order and over array elements. No generics or reflection are
needed in the language, and any struct, record or array type can be written. The file is
written through a 64 KiB buffer, followed by LF. A value whose type is or contains a handle type
(`Figure`, `Axes`, `Lu`, `Chol`, §4.1) cannot be written: it is the compile error `no overload of
'write_json' accepts (%s)` (the argument types, §9.1).

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
a `Figure` with library calls and writes it to an **SVG** file (Decision 13 in DESIGN.md §9). Nothing is
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
lines per target, an estimate; DESIGN.md §2.7).

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

**Plot fidelity in v1** (Decision 13 in DESIGN.md §9): §12.5–§12.7 fix the geometry well enough to
implement and to keep stable, but the v1 tests do not pin SVG bytes derived by hand: plot tests
check that the file is well-formed XML, that it has the expected structure (one plot area per
panel, one `<polyline>`/`<path>` per line series, one `<rect>` per finite bar, one `<image>` per
image, the axis labels, titles and legend texts present), and that the bytes are identical on
both targets and every kernel variant (DESIGN.md §6.6). A byte-exact plot specification can be added
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
  exclude (DESIGN.md §6.4). Tests never print `now()`-derived values otherwise.
* Baysick has no clock and does not need one: timing is a property of the compiled Sea program,
  implemented in Sea's runtime (DESIGN.md §4.5), not of the compiler.

## Appendices

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
             | conv_type "(" expr ")"
             | array_lit | struct_lit | record_lit | if_expr .
conv_type    = "f64" | "i64" | "str" .
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
  (the `{` starts the block) and `"{"` does not start a `record_lit`. The flag stays set inside
  the arms `{ … }` of an `if_expr` that is itself in a header. Outside header mode,
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
* `conv_type "(" expr ")"` is a conversion (`f64(b)`, `i64(x)`, `str(x)`). `bool` is only a type
  name: there is no `bool(x)`, and `bool` where an expression is expected is `unexpected token
  'bool'`. A `conv_type` other than `bool` not followed by `(` is `unexpected token` naming the
  token after it (`let x = f64 + 1` is `unexpected token '+'`).

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

(`str` is both a type name and the conversion `str(x)`; `f64` and `i64` are conversions through
the `conv_type "(" expr ")"` form; `bool` is only a type name, with no conversion. The later library of §10.13 adds names to this
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
  `--figures`, read with `args()` (§10.10, Decision 14 in DESIGN.md §9). The JSON goes to the working
  directory (§11.3), and
  `ylim`-spanning reference lines (`plot([LSL LSL], yl, 'r--')`) are `xline`.
