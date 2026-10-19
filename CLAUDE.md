# Sea — notes for agents

Sea is a fast matrix/numerical language, an alternative to MATLAB, with modern C/Rust-like syntax
(not MATLAB-compatible). Child project of Baysick (https://github.com/frgmt0/Baysick), a Dartmouth
BASIC (1964) rebuild hand-written in assembly, with targets `arm64-macos` (native) and
`x86_64-linux` (cross-compiled, tested on Linux), its own IR and plug-in backends.

## Status
**Pre-design.** No Sea syntax, semantics or code exists. The current work is Baysick's MAT
(2nd edition matrix) support, which builds the matrix runtime Sea will rely on.

## Goals, in priority order
1. Raw speed: ahead-of-time compiled to native code; fused element-wise expressions without
   temporaries; hand-written SIMD kernels (NEON on arm64, SSE2/AVX2 on x86_64) chosen by
   CPU-feature dispatch; benchmarked honestly against Apple Accelerate and OpenBLAS (the measuring
   bar, not dependencies).
2. A cleaner language than MATLAB.
3. Free, tiny and portable: standalone native binaries, no giant runtime.

## Repo layout
Sea is its own repo and is a git submodule of the Baysick repo at `sea/`. Baysick is the
authority on the toolchain Sea is built with.

## Invariants
- **Sea is written in Baysick.** If Sea needs a language feature Baysick lacks, add it to Baysick
  (in its repo) rather than working around it in Sea. Prefer following later Dartmouth editions:
  2nd MAT (in progress), 3rd INPUT, 4th strings/CHANGE, files later.
- **Design before code.** Sea's language design is not decided. Write it as a design doc and
  agree it with the user before any implementation.
- **Performance claims need benchmarks** with stated methodology (hardware, sizes, baselines,
  how timed). No claim without a measurement behind it.
- **Follow Baysick's workflow:** spec/contract first (normative docs, shared contract files), then
  implementation, then tests. Expected test outputs come from the spec, never from what the
  implementation prints. See Baysick's `CLAUDE.md` and `docs/`.
- No TODOs, stubs, placeholder or fake data.
- Do not add a license or badges until the user decides on them.
