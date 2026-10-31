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
(**arrays and structs**) is complete: sub-phases 4a (pass 2a split into `seaname` and `seacheck`,
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
4h, v1 7 704, stress 8 254; reserve V not needed), DESIGN.md §2.7 "Measured after 4h-0". **4h is
done** (Decisions 53–57, lead decisions L-s–L-ab: prelude inlining by `sealoop`'s rewrite L18 into
the `sea.hirl` records `iblk`/`iret` (`passes.txt` HL 88–89), lowered by `sealower` (R26–R30);
`std.sea`'s `linspace`, `meshgrid`, `setdiff`, `bincount`; W5 accepted). The gate after 4h passed:
`sealower` 6 473 built lines (v1 7 573, stress 8 123; free letters `C S X`), `sealoop` 5 829 (v1
8 429; `B X Y`), `seacheck` 6 426 (14 free), `seaname` 5 281 (DESIGN.md §2.7 "Measured after 4h").
**Phase 4 is complete.** **Phase 5** (scalar code quality) is specified and agreed (5a; Decisions
58–73, lead decisions L-ac–L-at (L-an–L-at after a review of the text): `seaopt`'s T1–T10 of
DESIGN.md §5.8, the shared allocator `passes/lib/ralloc.bas` of §4.9.2, the shape tests and
micro-benchmarks of §6.2, §5.9). **5b** (allocator and code selection, both targets) and **5c-1**
(`seaopt`'s T1–T4, T10) **are done**: `make test` and `make cross` (555) pass; `seaopt` 5 316 built
lines, `seagen_a64` 4 958, `seagen_x64` 5 294 (DESIGN.md §2.7 "Measured after 5b and 5c-1", with the
gate arithmetic that showed `seaopt` could not take T5–T9). The user then decided Decision 74 (the
loop transformations T5–T9 move to a new pass 3c `sealopt`, `sea.lir2` → `sea.lir`, sharing
`seaopt`'s reader, validator, writer and T10 through the shared main-program part `passes/lib/lirrw.bas`, L-bi; phase 7's
vectorizer goes there too, revised by Decision 78) and Decision 75 (the allocator extends an interval over a loop only when
it may be live at the loop's top), lead decisions L-bc–L-bf; after their review, L-bg–L-bk (liveness tested after a loop as
inside it, coverage by effective part, `lirrw` as a main-program part, golden lists, sizes) and
L-bl–L-bp (fresh registers for each copy of a versioned or unswitched loop, T9 placing copy-only
values back into each copy's arm, T10 deleting dead selections, §5.2's register counts re-derived,
`lirrw`'s reserved names: 2 free array letters in `seaopt` and `sealopt`) and L-bq (T4's
self-reading selection only where its register is written on every path or dead). **5c-2 is done** (`sealopt` 5 411 built
lines, `seaopt` 5 491; `make test` and `make cross` (596) pass; lead decisions L-br–L-bv, DESIGN.md
§2.7 "Measured after 5c-2"). **5d is done** (Decisions 76–77, the `seagen_x64` `imulh` fix): the
W5 and W4 loops meet DESIGN.md §5.2's shapes on both targets (20/23 and 24/27 instructions, no
frame access); micro-benchmarks (§5.9): `sor` ≈ C on both targets, `lcg` 1.19× (M2 Pro) and 1.35×
(i7-4790) C. **Phase 5 is complete** (shapes met on both targets, `sor` ≈ C, `lcg` 1.19/1.35× C;
Decisions 76–78): the gate after phase 5 passed with Decision 78 (phase 7's scalar replacement
and vectorization get their own pass 3d after `sealopt`, sharing `lirrw`, name and files at phase
7's spec; `sealopt` takes fixes only, its letter condition waived; DESIGN.md §2.7 "Measured after
5d"). **Phase 6** (functions and output) **is specified** (6a, agreed 2026-10-26: Decisions 80–93,
lead decisions L-bw–L-cx; DESIGN.md §2.11, §2.7, §6.2, §6.3, §8): named and default arguments,
§8.6 inlining (`sealoop` L20, `sealower` R31/R32), elemental functions (L19), `format`, `print`,
`make_dir`, `f64 %`, `write_json` (rule 39, runtime entries 23–38), the W1 and W5 ports without
figures; `seacheck` gated as `sealower` is (Decision 82). **6b is done** (2026-10-28: named and
default arguments, §8.6 inlining, `f64` `%`, `format`, `print`, `make_dir`, runtime entries 23–38;
lead decisions L-cy–L-dh; `make test` and `make cross` (700) pass; `seacheck` 6 798 built lines,
`sealoop` 5 936, `sealower` 6 637, `seaname` 5 424, DESIGN.md §2.7 "Measured after 6b"). **6c is
done** (2026-10-28: elemental functions, `ind2sub` with an array `r`; lead decisions L-di–L-dq;
`make test` and `make cross` (742) pass; `seacheck` 6 863 built lines, `sealoop` 6 438, `seaexpand` 4 359, `seaname` 5 555, DESIGN.md §2.7
"Measured after 6c"; the measurement after 6c calls for no relief, so 6b-0 is not run, Decision 87).
**6d is done** (2026-10-28: `write_json`; lead decisions L-dr–L-ec; `make test` and `make cross`
(776) pass; `seacheck` 6 919 built lines, `seaexpand` 4 796, `sealoop` 6 512, `sealower` 6 729,
DESIGN.md §2.7 "Measured after 6d"). **6e is done** (2026-10-29: the ports `ports/w1_shaft_design.sea`
and `ports/w5_tolerance_mc.sea` without figures, their token maps, `tests/accept.sh`, the cross case
kind `ports`; lead decisions L-ed–L-eg; `tests/accept.sh` passes both, every JSON key and both reports;
`make test` and `make cross` (778) pass, the ports byte-identical on the host but for the `Compute
time` line; DESIGN.md §6.3 "Measured at 6e"). The gate after phase 6 passes every program with no
relief (`sealoop` 6 512 built lines, 8 762 at the stress line with phase 7's fusion, 3 free letters:
fusion stays in `sealoop`; DESIGN.md §2.7 "Measured at the gate after phase 6"). **Phase 6 is
complete.** **Phase 7** (fusion and SIMD, DESIGN.md §8 row 7) **is specified** (7a, agreed
2026-10-29 after two independent reviews: Decisions 94–113, each option (a), lead decisions
L-eh–L-fl; DESIGN.md §2.12, §2.7, §6.2, §6.3, §6.6.1, §8): fusion F1–F5 in a new pass-3a program
`seafuse` (`sea.hir` → `sea.hirf`, ahead of `sealoop`, also doing L19), pass 3d `seavec`
(`sea.lir3` → `sea.lir`: T11 unrolling, T12 scalar replacement, T13 if-conversion and
vectorization), NEON/SSE2/AVX2 code in pass 4, runtime entries 39–50 (vector elementary
functions), the W4 port, a run-time allocation count (`SEA_HEAP_CHECK=count`), and LANGUAGE.md
§9.2's out-of-memory sentence (added by WP-CONTRACT). **7b is done** (2026-10-29: the
contract changes, the new programs `seafuse` and `seavec`, `sealopt` writing `sea.lir3`, L19
rewritten in `seafuse`, `sealoop` reading `sea.hirf`; neutral by Decision 109 over the whole corpus;
lead decisions L-fm–L-fu; `seafuse` 3 164 built lines with 5 free letters, `sealoop` 6 396;
DESIGN.md §2.7 "Measured after 7b"). **7d is done** (2026-10-29: the vector forms of the
elementary functions, entries 39–50, `rt_vmath.s` per runtime; DESIGN.md §2.12.8). **7c is done**
(2026-10-30: fusion F1–F5 in `seafuse`, with buffer reuse, in-place selection stores, `tbind`
groups, fused masked and `.flat` reductions and folded concatenation parts in stacks and mixed
rows; the user's D1–D3 and the concatenation decision, lead decisions L-fv–L-gj, DESIGN.md
§2.12.3, §2.12.4 "Readings fixed by 7c"; `make test` and `make cross` (876) pass; two independent
reviews with differential fuzzing against the pre-7c compiler, every defect fixed; the measurement
after 7c passes with no relief: `seafuse` 6 427 built lines with 5 free letters, `sealoop` 6 431
with 3, DESIGN.md §2.7 "Measured after 7c"). **Next:** 7e (`seavec` and vector code in pass 4).
Versions 0.y.z are alpha; 1.0.0 = v1
(Decision 79).

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
- Use the compiler: `build/sea build <file.sea> [-o out] [-S] [--emit ast|res|hir1|hir|hirf|hirl|lir1|lir2|lir3|lir]
  [--no-prelude] [--keep-temps]`, `build/sea run <file.sea> [-- args…]` (DESIGN.md §2.2).
- Tests: `make test` runs, after `make all` and `make check-contracts`, every group even if one
  fails: `test-driver` (`tests/driver_check.sh`), `check-data` (`tests/check_data.sh`, the DATA
  generator), `test-lib` (`tests/lib_check.sh`), `test-arith` (`tests/arith_check.sh`, the exact
  arithmetic modules), `test-rt` (`tests/rt/`, runtime tests against `libsea.a`), `test-stage`
  (`tests/stage.sh`, each pass on the previous pass's golden), `test-shape` (`tests/shape.sh`, the
  instruction-count shape of the W5 and W4 hot loops on both targets, DESIGN.md §5.2, §6.2), `test-protocol`
  (`tests/protocol.sh`, truncated input, missing `#end`), `test-math`
  (`tests/math/math_check.c`, all six elementary functions bit for bit over `tests/math/*.vec`, and their vector entries against the scalar ones in every lane position and on random inputs),
  `test-programs` (`sh tests/run.sh [-v] [pattern]`: programs/, errors/ and the passes/ dumps), `test-accept` (`tests/accept4.sh` then `tests/accept.sh`: the phase-4 acceptance programs and the phase-6 ports W1 and W5 against `compare.py` and `compare_report.py`; needs `uv`). Each group is also its own target.
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
- `passes/<pass>/` the Baysick files and `build.list` of each pass (`seaparse seaname seacheck seaexpand seafuse sealoop sealower seaopt sealopt seavec seagen_a64 seagen_x64`); `passes/lib/` the shared modules
  (`io diag tables lirrw limb f64emu fltlit layout ralloc`), interfaces in `passes/lib/API.md`, `API-arith.md`.
- `tools/` `gendata.bas` (the `DATA` generator), `seaval.bas` (intermediate-file validator: formats `ast res hir1 hir hirf hirl lir1 lir2 lir3 lir`; `lir2` and `lir3` checked as `lir1` except its two lir1-only label rules, L-bu; `hirf` as `hirl` without `inst emap cdat iblk iret`),
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
