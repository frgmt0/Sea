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
**Phase 2** (the x86_64 target: `seagen_x64`, the x86_64 runtime, `cross*.sh`; DESIGN.md §4.7.1,
§4.9.1, §6.6.1) is complete at sea commit a87ca78: `make cross` passes every case on the Linux
host. Decision 7 (the user's MATLAB rerun) is done: the MATLAB baseline is committed at sea
commit c1736f7. **Phase 3** (elementary functions: Sea's own scalar `log exp sin cos pow hypot`
on both targets (Decision 6), and the compile-time `pow`; DESIGN.md §4.10) is complete at sea commit 98e1e14: the
`math/` tests pass on both targets (≤ 1 ulp against the high-precision references, identical bits
on both targets). **Phase 4** of DESIGN.md §8
(**arrays and structs**) is under way: sub-phases 4a (pass 2a split into `seaname` and `seacheck`,
sea commit 263ee1f), 4b (the phase-4 specification, 2dfe535), 4c (heap runtime, a59ca07) and 4d
(dynamic arrays core, W4 scalar SOR accepted by `make test-accept`) are done. The size gate after
4d (DESIGN.md §2.7) projected `sealower` to 9 665 lines, so sub-phase 4e-0 split pass 3a into
`sealoop` (`sea.hir` → `sea.hirl`, the array constructs made explicit as scalar loops) and
`sealower` (`sea.hirl` → `sea.lir1`, unchanged). **4e-0 is done** (built and tested, no change of
behaviour; Decisions 26–30; measured: `sealoop` 2 323 lines with 7 free array letters, `sealower`
5 164 lines with 4 free, DESIGN.md §2.7); **4e (array expressions) is done** (Decisions 31–37: the `sealoop` rewrites L5–L12 with the
`sea.hirl` refinements R1–R11, rule 27 for fixed-size numeric arrays, DESIGN.md §3.5.9, §3.6.6, §8;
measured: `sealoop` 4 129 lines, `sealower` 5 971, DESIGN.md §2.7); **4f (reductions, sorting,
searching, library options) is done** (Decisions 38–43: the `sealoop` rewrites L13–L14 with the
`sea.hirl` refinements R12–R16 and the `wop` word `and`, result types on fixed-size arguments,
`rt_sort.s` with `f64`, `i64` and `str` on both targets, error 115 for a positional argument after a
named one; DESIGN.md §0, §3.5.9, §4.8, §8). The size gate after 4f (Decision 35) passed with no
split: `sealoop` 4 400 built lines (projected v1 7 950, 4 free array letters), `sealower` 6 087
(7 987, 4 free), `seacheck` 5 830 (6 780, 14 free), DESIGN.md §2.7. **4g** (strings, structs,
records, `match`, `error`, `args`) **is done** (Decisions 44–48 and the lead decisions L-a … L-n:
the `sea.hirl` refinements R17–R25 with no new record kind, the `sealoop` rewrites L15 projection, L16
`match` and L17 reference, aggregate and field-path stores, element-wise `str` operators, scalar-only
`str()`/`lower()`, records as anonymous struct types, the shared module `passes/lib/layout.bas`; no
contract file changes; DESIGN.md §0, §2.6.2, §2.7, §3.5.9, §6.2, §8), built in two sub-steps
(Decision 47). **4g-1** (strings, `match`, `error`, `args`, `str` elements, `sort_str`; lead
decision L-n: an L17 `str` element store into a `ref` parameter root reads P afresh after the cow
until 4g-2). The size gate after 4g-1 passed with no relief: `sealower` 6 349 built lines (projected
after 4g-2 P = 6 956, 44 under 7 000; v1 8 056; 4 free array letters), `sealoop` 4 659 (5 114; 8 214;
4 free), `seacheck` 5 944 (6 081; 14 free), DESIGN.md §2.7. **4g-2** (structs, records, projection,
fixed-size `str` and struct arrays, the module `layout` of 123 lines, `manualD_part1`) measured
`sealower` 6 994 built lines (v1 8 394 with 4h counted, lead decision L-o; 3 free array letters), `sealoop` 5 433 (8 533, 3 free),
`seacheck` 6 424 (14 free), `seaname` 5 262 (DESIGN.md §2.7, "Measured after 4g-2"): `sealower` is
6 lines under its 7 000-line cap. The relief is agreed (Decisions 49–52, lead decisions L-o–L-r, DESIGN.md §0, §2.7, §8, §9): a
behaviour-neutral compaction of `sealower` (C1–C6, about 600 lines; reserves: `sea.hirl` validation
into `seaval`, rule 36's composites into `sealoop`, a middle HIR→HIR pass), the 7 000-line cap kept
through 4h, gates after 4h-0, 4h, phase 6 and phase 8. **4h-0 is done**: `sealower` 6 304 built
lines (690 saved; the multi-line `DEF` functions `FNQ`, `FNE`, `FNR$`; 3 free array letters),
proved neutral by byte-identical `sea.lir1`, and the gate after 4h-0 passed (6 604 ≤ 7 000 with
4h, v1 7 704, stress 8 254; reserve V not needed), DESIGN.md §2.7 "Measured after 4h-0". **4h**
(prelude inlining, `linspace`/`meshgrid`/`setdiff`/`bincount`, W5, the close-out of phase 4) **is
specified** (Decisions 53–57, lead decisions L-s–L-ab: rule 37 as the `sea.hirl` records `iblk` and
`iret` (`passes.txt` HL 88–89), `sealoop`'s rewrite L18 with the `.i` locals and recursive inlining,
the refinements R26–R30 in `sealower`, one signature per prelude function, `NAME.prelude` beside
`.hir`/`.hirl`/`.lir1`/`.out`, `sealoop` in the gate after 4h; DESIGN.md §0, §2.5, §2.6.2, §2.7,
§3.5.9, §3.6.6, §6.2, §8, §9). **Next is the 4h build.**

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
- Use the compiler: `build/sea build <file.sea> [-o out] [-S] [--emit ast|res|hir1|hir|hirl|lir1|lir]
  [--no-prelude] [--keep-temps]`, `build/sea run <file.sea> [-- args…]` (DESIGN.md §2.2).
- Tests: `make test` runs, after `make all` and `make check-contracts`, every group even if one
  fails: `test-driver` (`tests/driver_check.sh`), `check-data` (`tests/check_data.sh`, the DATA
  generator), `test-lib` (`tests/lib_check.sh`), `test-arith` (`tests/arith_check.sh`, the exact
  arithmetic modules), `test-rt` (`tests/rt/`, runtime tests against `libsea.a`), `test-stage`
  (`tests/stage.sh`, each pass on the previous pass's golden), `test-protocol`
  (`tests/protocol.sh`, truncated input, missing `#end`), `test-math`
  (`tests/math/math_check.c`, all six elementary functions bit for bit over `tests/math/*.vec`),
  `test-programs` (`sh tests/run.sh [-v] [pattern]`: programs/, errors/ and the passes/ dumps). Each group is also its own target.
- Math: `make test-math` (part of `make test`; `xcrun cc -O1 -ffp-contract=off` against
  `build/libsea.a`); `make math-tables` (developer check, not in `make test`: `timeout 120 uv run
  --with mpmath python tools/math_tables.py --check`); `uv run --with mpmath python tests/vectors/math_vectors.py --check-format` checks the vector files.
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
- x86_64 cross test (DESIGN.md §6.6.1): `make cross` / `sh tests/cross.sh [-v] [-H host]
  [pattern]` (packs on the Mac, one ssh to the host, default `$SEA_CROSS_HOST` else `desktop`);
  `make cross-pack` builds `build/x86_64-linux-bundle` only; on Linux: `sh tests/cross_run.sh
  [-v] BUNDLE_DIR`, `make -f Makefile.linux` (`build-x86_64-linux/libsea.a`), `make -f
  Makefile.linux test-rt` (`tests/rt/x86_64_linux/`), `make -f Makefile.linux test-math`. `make cross` also
  runs one extra case, `math/math_check`, on the host.
- Never set a bogus `SDKROOT`/`DEVELOPER_DIR` on the Mac. Python, if ever needed, via `uv` only.

## Repo layout (DESIGN.md §2.10)
- `passes/<pass>/` the Baysick files and `build.list` of each pass (`seaparse seaname seacheck seaexpand sealoop sealower seaopt seagen_a64 seagen_x64`); `passes/lib/` the shared modules
  (`io diag tables limb f64emu fltlit layout`), interfaces in `passes/lib/API.md`, `API-arith.md`.
- `tools/` `gendata.bas` (the `DATA` generator), `seaval.bas` (intermediate-file validator: formats `ast res hir1 hir hirl lir1 lir`),
  `passlines.sh`.
- `driver/sea` the driver (POSIX sh); `runtime/arm64_macos/`, `runtime/x86_64_linux/` the
  runtimes (`libsea.a`); `std/std.sea` the prelude.
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
