# Sea — notes for agents

Sea is a fast matrix/numerical language, an alternative to MATLAB, with modern C/Rust-like syntax
(not MATLAB-compatible). Child project of Baysick (https://github.com/frgmt0/Baysick), a Dartmouth
BASIC (1964) rebuild hand-written in assembly, with targets `arm64-macos` (native) and
`x86_64-linux` (cross-compiled, tested on Linux), its own IR and plug-in backends.

## Status
**Phase 0** (agreement and contracts, 2026-10-20) and **phase 1** (scalar core, arm64; complete
at sea commit e6e9873) of DESIGN.md §8 are done. The six passes (`seaparse` `seacheck` `seaexpand`
`sealower` `seaopt` `seagen_a64`), the driver, the arm64 runtime and the tools are written; the
W5 LCG acceptance test passes; the size estimate of DESIGN.md §2.7 is recalibrated from the real
passes. Decisions taken during phase 1 are recorded in DESIGN.md §0 ("Decided in phase 1").
**Next: phase 2** of DESIGN.md §8, the **x86_64 target**: `seagen_x64`, the x86_64 runtime for
the same subset and `cross*.sh`, done when the phase-1 tests pass byte-identically on the Linux
host. Still open from phase 0: the user's MATLAB rerun (Decision 7).

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
- Build: `make` (= `make all`: runtime, tools, passes, install). Each pass is built as
  `build/gen/<pass>.bas` (its own files, the modules and `DATA` blocks of its `build.list`,
  `99999 END`; DESIGN.md §2.6.3) and compiled with Baysick (`BAYSICK=<dir>`, default `..`; run
  `make` there first). `build/` is the installation directory (DESIGN.md §2.10).
- Use the compiler: `build/sea build <file.sea> [-o out] [-S] [--emit ast|hir1|hir|lir1|lir]
  [--no-prelude] [--keep-temps]`, `build/sea run <file.sea> [-- args…]` (DESIGN.md §2.2).
- Tests: `make test` runs, after `make all` and `make check-contracts`, every group even if one
  fails: `test-driver` (`tests/driver_check.sh`), `check-data` (`tests/check_data.sh`, the DATA
  generator), `test-lib` (`tests/lib_check.sh`), `test-arith` (`tests/arith_check.sh`, the exact
  arithmetic modules), `test-rt` (`tests/rt/`, runtime tests against `libsea.a`), `test-stage`
  (`tests/stage.sh`, each pass on the previous pass's golden), `test-protocol`
  (`tests/protocol.sh`, truncated input, missing `#end`), `test-programs` (`sh tests/run.sh [-v]
  [pattern]`: programs/, errors/ and the passes/ dumps). Each group is also its own target.
- Size: `make lines` (built lines per pass) and `make check-limits` (lines, `FOR`s, string
  bytes, 255-byte lines against Baysick's limits).
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

## Repo layout (DESIGN.md §2.10)
- `passes/<pass>/` each pass's Baysick files and `build.list`; `passes/lib/` the shared modules
  (`io diag tables limb f64emu fltlit`), interfaces in `passes/lib/API.md`, `API-arith.md`.
- `tools/` `gendata.bas` (the `DATA` generator), `seaval.bas` (intermediate-file validator),
  `passlines.sh`.
- `driver/sea` the driver (POSIX sh); `runtime/arm64_macos/` the runtime (`libsea.a`);
  `std/std.sea` the prelude.
- `tests/` programs/, errors/, passes/ (dump goldens), rt/, harness/, vectors/ and the scripts
  above; `tests/CORPUS.md` describes the corpus.

## Pass authors
- Baysick limits bite: 10 000 stored lines per built program (own files + modules + `DATA`), 255
  bytes per line, 1000 `FOR`s, 1024 active `CALL`s, 65 536 bytes of string constants outside
  `DATA`; numbers are doubles with no ∞, NaN or −0 (use `limb`/`f64emu`, DESIGN.md §2.8); string
  `=` ignores trailing blanks (compare lengths first, DESIGN.md §2.7).
- Edit the numbered `.bas` files directly and keep the numbering stable (insert between existing
  numbers; each part keeps its line range, DESIGN.md §2.6.3).
- When `make check-limits` shows a pass above 9 000 lines, split it into two programs with an
  intermediate file (DESIGN.md §2.7, §7.3) before adding more.

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
