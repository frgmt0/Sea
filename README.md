# Sea

Sea is a fast matrix and numerical programming language, intended as an alternative to MATLAB,
with modern C/Rust-like syntax. It is the child project of
[Baysick](https://github.com/frgmt0/Baysick), a faithful rebuild of Dartmouth BASIC (1964) written
in assembly, and Sea is written in Baysick.

**Status: pre-design.** No Sea syntax, semantics or code exists yet.

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
Dartmouth editions:

* 2nd edition: MAT statements (in progress)
* 3rd edition: `INPUT`
* 4th edition: strings and `CHANGE`
* files, later

Baysick currently has two targets, `arm64-macos` (native) and `x86_64-linux` (cross-compiled and
tested on Linux), plus its own IR and plug-in backends.

## Status

Sea is in the pre-design phase. The current work is on the Baysick side: MAT (matrix) support,
which builds the matrix runtime that Sea will rely on.

## Roadmap

In order, without dates:

1. Finish Baysick's MAT statements and matrix runtime.
2. Grow Baysick with the other capabilities Sea needs (`INPUT`, strings and `CHANGE`, files).
3. Write the Sea language design document and agree on it.
4. Implement the Sea compiler in Baysick.
5. Write the SIMD kernels for arm64 and x86_64, with CPU-feature dispatch.
6. Add fused element-wise expression compilation.
7. Benchmark against Apple Accelerate and OpenBLAS, and publish the methodology and results.

## Getting it

Clone Baysick with its submodules:

```
git clone --recurse-submodules https://github.com/frgmt0/Baysick
```

Or clone Sea directly:

```
git clone https://github.com/frgmt0/Sea
```
