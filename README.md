# Sea

Sea is a fast matrix and numerical programming language, intended as an alternative to MATLAB,
with modern C/Rust-like syntax. It is the child project of
[Baysick](https://github.com/frgmt0/Baysick), a faithful rebuild of Dartmouth BASIC (1964) written
in assembly, and Sea is written in Baysick.

**Status: design and contracts agreed (phase 0); implementation not started.** The language is specified in
docs/LANGUAGE.md, the compiler, runtime, tests and plan in docs/DESIGN.md.

## Why

MATLAB is the default tool for matrix work, and it has problems Sea sets out to address:

* **Speed.** Sea programs are compiled ahead of time to native code. Element-wise expressions are
  fused so they run without temporary arrays. The numeric kernels are hand-written SIMD (NEON on
  arm64, SSE2/AVX2 on x86_64), selected at run time by CPU-feature dispatch. Speed is judged by
  honest benchmarks against Apple Accelerate and OpenBLAS. They are the measuring bar, not
  dependencies.
* **Language design.** Sea uses a modern C/Rust-like syntax. It is not MATLAB-compatible, which
  leaves room for a cleaner language than MATLAB's.
* **Cost and size.** Sea is meant to be free, tiny and portable: standalone native binaries and
  no giant runtime.

The priorities, in order: raw speed, a cleaner language, then free, tiny and portable.

## Relationship to Baysick

Sea is bootstrapped: it is written in Baysick. Sea lives in its own repository and is included in
the Baysick repository as a git submodule at `sea/`.

When Sea needs something Baysick lacks, Baysick grows it. Where possible that follows the later
Dartmouth editions. Baysick now implements the Second through Sixth Editions (MAT statements,
`INPUT`, strings and `CHANGE`, sequential files, string functions, `CALL`/`SUB`) plus its own
labelled extensions (version 0.6.0).

Baysick currently has two targets, `arm64-macos` (native) and `x86_64-linux` (cross-compiled and
tested on Linux), plus its own IR and plug-in backends.

## Status

Phase 0 is agreed and complete (2026-10-20), except a MATLAB rerun by the user: the design is
split into docs/LANGUAGE.md and docs/DESIGN.md, and the compiler's intermediate file formats
(docs/DESIGN.md §3, include/passes.txt) and contract files (include/limits.inc, errors.inc,
rt.inc) are written and agreed. Baysick has the matrix runtime and language growth Sea needs to
start. Next is phase 1, the scalar core on arm64; implementation has not started.

## Workloads

`workloads/` holds five original MATLAB engineering scripts (shaft sizing, truss FEM, quarter-car
RK4, plate heat conduction, Monte Carlo tolerance stack-up). They are Sea's acceptance targets: a
Sea port of each must reproduce the reference numbers and report, faster. `workloads/README.md`
describes them, the language features they stress, and how the reference values are produced and
compared.

## Roadmap

In order, without dates:

1. Done: Baysick's MAT statements and matrix runtime.
2. Done: Baysick grown through the Sixth Edition plus extensions (v0.6.0).
3. Done: the Sea design, agreed, and split into the language specification and the design document.

The rest follows the milestones in docs/DESIGN.md §8.

## Getting it

Clone Baysick with its submodules:

```
git clone --recurse-submodules https://github.com/frgmt0/Baysick
```

Or clone Sea directly:

```
git clone https://github.com/frgmt0/Sea
```
