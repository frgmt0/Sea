# Sea — notes for agents

Sea is a fast matrix/numerical language, an alternative to MATLAB, with modern C/Rust-like syntax
(not MATLAB-compatible). Child project of Baysick (https://github.com/frgmt0/Baysick), a Dartmouth
BASIC (1964) rebuild hand-written in assembly, with targets `arm64-macos` (native) and
`x86_64-linux` (cross-compiled, tested on Linux), its own IR and plug-in backends.

## Status
**Design agreed** (2026-10-20) and split into `docs/LANGUAGE.md` and `docs/DESIGN.md`; the
intermediate record formats (DESIGN.md §3, `include/passes.txt`) are written. The contract
files `include/limits.inc`, `errors.inc`, `rt.inc` are written with their tables (DESIGN.md
§2.6.1, §2.6.2, §4.8); their include checks pass on both assemblers and the drift check passes.
Everything marked **pinned** in DESIGN.md awaits the user's agreement (consolidated list in
DESIGN.md §0, with the open language questions). Next: the
milestones of DESIGN.md §8. No compiler or runtime code exists yet.

## Read first
- `docs/LANGUAGE.md` — what Sea programs mean (syntax, types, library, output bytes, errors,
  exit statuses). Normative.
- `docs/DESIGN.md` — goals and their measurement, compiler passes and driver, intermediate file
  formats (§3), runtime ABI, performance model, tests, Baysick growth, milestones, decisions.
  Normative.
- `include/` — the contract files: `passes.txt` (record formats of every intermediate file),
  `limits.inc` (limits), `errors.inc` (error texts and codes, exit statuses) and `rt.inc`
  (runtime layouts and symbols).
- Baysick's `CLAUDE.md` and `docs/` (the toolchain Sea is written in).

## Commands
- Include check (Mac, Apple `as`): `make check-includes` — first `make check-contracts`, then
  Sea's `include/*.inc` assembled after Baysick's `include/limits.inc` and `include/runtime.inc`
  (`BAYSICK=<dir>`, default `..`), with the assertions of `tests/include_asserts.inc`.
- Contract drift check: `make check-contracts` (`sh tests/check_contracts.sh`, sh + awk, no
  Python) — every `SEA_*` name and value, error and errno record of `include/*.inc` and every
  record format of `include/passes.txt` equals the tables of `docs/DESIGN.md`, both ways.
- Include check on the Linux host (GNU `as`): `make cross-includes` / `sh tests/cross_includes.sh
  [-H host] [-B baysick_dir]` (ssh host, default `desktop`); on Linux itself:
  `make -f Makefile.linux check-includes`.
- Never set a bogus `SDKROOT`/`DEVELOPER_DIR` on the Mac. Python, if ever needed, via `uv` only.

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
  (in its repo) rather than working around it in Sea. Prefer following later Dartmouth editions;
  Baysick implements Editions 2-6 plus extensions (v0.6.0).
- **Design before code.** Sea's design is agreed (`docs/LANGUAGE.md`, `docs/DESIGN.md`).
  Changes to it are made in those documents together with the user's agreement, before the code
  that depends on them.
- **Contract rule:** a layout, code, limit, symbol or record format shared between separately
  written parts (passes, runtimes, tests) changes only by editing its contract file
  (`include/*.inc` or `include/passes.txt`) AND the matching doc section in the same change.
  Never hard-code a value that has a name in a contract file.
- **Performance claims need benchmarks** with stated methodology (hardware, sizes, baselines,
  how timed). No claim without a measurement behind it.
- **Follow Baysick's workflow:** spec/contract first (normative docs, shared contract files), then
  implementation, then tests. Expected test outputs come from the spec, never from what the
  implementation prints. See Baysick's `CLAUDE.md` and `docs/`.
- No TODOs, stubs, placeholder or fake data.
- Do not add a license or badges until the user decides on them.
