# Sea Design

## 0. Status, scope and how this document is agreed

**Status: Agreed 2026-10-20: the user accepted every recommendation of §9.** Nothing here is
implemented. Sea is specified by two normative documents, split as Baysick's are:

* `docs/LANGUAGE.md`: what Sea programs mean: syntax, types, semantics, the standard library,
  output and plotting, the bytes programs print and write, errors and exit statuses;
* `docs/DESIGN.md`, this document: how they are compiled and run: the goals and how they are
  measured (§1), the compiler passes and the driver (§2), the exact formats of the intermediate
  files (§3), the runtime and its ABI (§4), the performance model (§5), tests and conformance
  (§6), what Baysick must grow (§7), the milestones (§8) and the decisions behind it all (§9).

Both are written normatively ("must") so that every rule can become a test. "§N" is a section
of this document, "LANGUAGE.md §N" one of the language specification, and "Baysick
LANGUAGE.md §N", "Baysick DESIGN.md §N", "Baysick IR.md §N", "Baysick BENCH.md §N" sections of
the Baysick documents in the parent repository's `docs/`. A list of sections after a document
name stays in that document up to a semicolon: in "Affects LANGUAGE.md §8.5; §5.1" the first is a
section of LANGUAGE.md and the second one of this document.

**How it was agreed.** The user read the design, then a single document, and accepted each
decision of §9 (Decisions), choosing the option recommended there. Every other rule was accepted
with the document. A change to the design is made in LANGUAGE.md or in this file together with
the user's agreement. Phase 0 (§8) did:

1. the single document is split into LANGUAGE.md and DESIGN.md, and the compiler half gains what
   the agreed text deliberately left at the level of principles: the exact record formats of the
   intermediate files (`sea.ast`, `sea.hir1`, `sea.hir`, `sea.lir1`, `sea.lir`, §3), each with
   an `--emit` dump example that becomes its dump test (§3.8), as Baysick's IR.md does for its
   IR, and their machine-readable form `sea/include/passes.txt` (§3.9). The split moves and
   renumbers the agreed text; the rules it adds or changes are listed below and were agreed
   with the user on 2026-10-20;
2. the contract files of §2.6 (`sea/include/*.inc`) are written with the matching doc
   sections, under the same contract rule as Baysick's (`CLAUDE.md`: a shared layout, code,
   limit or symbol changes only in the include file and its doc section together);
3. implementation follows the milestones of §8: phases 0, 1, 2 and 3 are complete (the MATLAB
   rerun of Decision 7 is done: sea commit c1736f7); next is phase 4, arrays and structs, built in
   the sub-phases 4a–4h of §8, starting with 4a, the split of pass 2a.

**Agreed in phase 0 (2026-10-20).** The user agreed, as written, everything steps 1 and 2 added
to the design:

1. the intermediate record formats, all of §3 and `passes.txt`;
2. the driver details of §2.2 (`--emit` for all five files; `--no-prelude`, under which the
   prelude's names are not declared; `#file` paths as escaped strings; the line check counting
   4096 bytes after removing a trailing CR, as LANGUAGE.md §3.1 says; the `line too long` text
   read from the installed `errors.inc`);
3. evaluation order kept with `seq` and `.t` temporaries (§3.5.5);
4. constant exponents decided by pass 2a with exact evaluation (§3.5.5, §2.8);
5. the positions of the nodes pass 2a writes, the −2⁶³ constant rule, and
   `-(9223372036854775808)` accepted (§3.4, §3.5.5);
6. prelude calls always inlined, with run-time errors in prelude code reported at the program's
   call site (§3.6.4);
7. `nan` = `#7FF8000000000000` (§3.5.5);
8. `limits.inc` (§2.6.1), including `SEA_LIM_RESULTS` and the `SEA_LIM_LIR_*` limits;
9. the table layout of the LIR passes and the file index in table `N` (§2.7);
10. `errors.inc` (§2.6.2): the texts defined there, the `at` column, the spellings of
    substituted values, the errno table, the uses of existing messages, and the `DATA` line
    shapes and escaping;
11. `rt.inc` (§4.8): every layout, symbol and convention of that section;
12. report equivalence (§6.4), with the token reading and the default rule as decided below.

The user also decided the language questions that phase 0 raised:

1. `bool(x)` is not a conversion: only `f64()`, `i64()` and `str()` are; `bool` stays a type name,
   and `bool` in expression position is `unexpected token 'bool'` (LANGUAGE.md Appendix A).
2. `write_json` of a value whose type contains a handle type is the compile error `no overload of
   'write_json' accepts (…)` (LANGUAGE.md §11.4).
3. The dimension in the bounds message counts from 0 (LANGUAGE.md §5.4).
4. `return f(…)` of a multiple-result call is allowed when `f`'s result types equal the function's
   exactly; otherwise `type mismatch` (LANGUAGE.md §8.4; HIR `tret`, §3.5.5).
5. A failed final flush of standard output reports `cannot write '<stdout>': %s` with no location,
   exit status 1 (LANGUAGE.md §9.2; §4.6; `SEA_SITE_NONE`, §4.8).
6. Report tokens are read after stripping one trailing `,`/`;`/`:`, one trailing `)` and one
   leading `(`, and are split at `..` (§6.4).
7. The default report rule is "within one unit of the last printed digit of the coarser token"
   (§6.4).
8. An exponent that contains a call or a non-multiplicative `^` is not a constant integer for
   `powk` (LANGUAGE.md §6.5), judged on the exponent as written: a `const` name counts by its value, however defined (`const K = pow(4.0, 0.5)` makes `x ^ K` a `powk 2`).

**Decided in phase 1.**

1. Full-range loops: `rcount` yields last + non-empty flag; d = 0 for an empty range (user
   decision 2026-10-21; the d = 0 detail a lead decision; §3.6.4, §3.6.6).
2. `f64(x)` accepts an `f64` and `i64(x)` an `i64`, returning x unchanged; an untyped literal
   argument of either is `i64` (user decision 2026-10-21; LANGUAGE.md §4.2, §10.1).
3. Constant folding covers non-finite values: every `f64` operation folds with the exact IEEE
   emulation, ±∞ and NaN included, with arm64's NaN bits (user decision 2026-10-21; §2.8,
   §3.5.7).
4. The AST `for` record carries the loop variable's position `npos` (lead decision; §3.4).
5. A format literal in a message is rendered canonically from its bytes (lead decision; §2.6.2).
6. `SEA_LIM_CONSTS` counts distinct constant values (lead decision; §2.6.1, §2.7).
7. The driver reads its input once and refuses an output that is the input file (lead decision;
   §2.2).
8. The errno table gains `EBADF`, `ENXIO`, `ECONNRESET`, `ENOTCONN`, `ETIMEDOUT` (lead decision;
   §2.6.2).
9. A capacity error reported for a record with a `pos` field takes that position; capacity
   errors found while a pass reads its input are reported at once (lead decisions; §2.6.2,
   LANGUAGE.md §9.1).
10. Passes 2b, 3b and 4 validate their input as §3.5.7, §3.6.5 and §4.9 list (lead decision).
11. The stack check compares without wrapping, and the signal handler ends with `_exit` (lead
    decision; §4.6, §4.9).
12. Behaviour of the phase-1 passes written down as the rule (lead decision): the reads before
    a `ref` call copied in every arm, `&&`/`||`/`ifx` writing a non-local destination directly,
    nothing after a final returning `if` (§3.6.6); a `-` site is no operand (§2.7); `sea run`
    status overlap, installation files checked when needed, usage after option errors (§2.2);
    the per-literal exactness check and untyped `-0` (LANGUAGE.md §4.2), `let _ = f()`
    (LANGUAGE.md §7.2), roots only for path arguments (LANGUAGE.md §8.3), header mode in
    `if_expr` arms (LANGUAGE.md Appendix A), the NL token of a last line without LF (§2.6.2).
13. Tuple assignment converts each component as LANGUAGE.md §4.2 (b) and §7.3 require: the HIR
    `tasg` carries a conversion flag per target (lead decision; §3.5.5, §3.6.6). `tbind` needs
    none: a tuple pattern takes the result types exactly (LANGUAGE.md §7.2).
14. Every `const` is evaluated once at compile time to one literal; a constant whose evaluation
    overflows `i64` or divides an `i64` by zero is a compile error at the operation (user
    decision U2, 2026-10-21; LANGUAGE.md §7.2; §3.5.2; errors 260, 261).
15. Round-3 rules (lead decisions R1–R9): the `stdout=closed` test key (§6.2); driver input
    examples and the `-ef` check for every output file `sea build` writes, not for `sea run`
    (§2.2); limits read from `limits.inc`, the
    look-ahead of `here` and type records (§2.6.2); `off` any `i64` (§3.6.4); `la d0` and
    duplicate function names rejected, a `-` site no operand (§3.6.5, §2.7); positions of the
    symbols limit and what the types and constants limits count (§2.6.2, §2.7); `let _: T = f()`
    (LANGUAGE.md §7.2).

**Specified for phase 3 (elementary functions, §8).** §4.10 defines `log exp sin cos pow hypot`
operation by operation (constants, the generated `include/math_tables.inc`, special values with
every NaN result `#7FF8000000000000`, the ABI of the six `rt.inc` entries 3–8), their lowering
(§3.6.6 rule 14), the `math/` tests and the measured accuracy (≤ 0.512 ulp on the model). The
user decided Decision 16 (a) on 2026-10-21: a `const` may use `^` and `pow` (LANGUAGE.md §7.2),
evaluated by pass 2a with `FEPOW` of `f64emu.bas` and the generated `mtab` `DATA` block
(§4.10.5, §2.6.3); `log exp sin cos hypot` stay outside constant expressions.

**Decided for phase 4 (2026-10-21).** The user took Decisions 17–24 of §9 (each the recommended
option): the split of pass 2a into `seaname` and `seacheck` (17), prelude calls inlined by pass 3a
from phase 4 (18), the phase-4 acceptance by a `printf` JSON subset and `compare.py --keys` (19),
`str` and struct array literals dynamic (20), the library's named options in phase 4 (21), inline
loops with a small runtime (22), the scope edges with `f64 %` left to phase 6 (23) and
`SEA_HEAP_CHECK=1` (24); phase 4 is built in the sub-phases 4a–4h of §8. On review of the 4a
specification the user also decided Decision 25 (2026-10-21): a constant that names a constant
without a value, or whose type is an error type, is not evaluated and gives no further error
(LANGUAGE.md §7.2, §3.5.2); it lands in the single `seacheck` first, as sub-phase 4a-0. **Specified for 4a**
(lead decisions within Decision 17): `sea.res` (§3.4.1) is set `A` of `passes.txt` with codes
50–63, its own records occurring only in `sea.res` (so the record tables of every pass stay as
they are, §3.9); its `rerr` record is the one record with more than one string field (§3.1); the
errors `seaname` reports are exactly the declaration checks a single program found first, and
`seacheck` reports every other one, those of `const` items included (§2.6.2, "Which program
reports it"); `seaname` evaluates constants on the well-typed path only and checks no rule,
`seacheck` checks every constant and accepts `seaname`'s value only where Decision 25 gives the
constant one, a missing or impossible outcome there being `BAD_RECORD` (§3.4.1); `seacheck`
counts the values of constants for the `constants` limit; a compilation exceeding a limit of
`seaname` and the `types` limit, or the `constants` limit through values of constants, in
`seacheck` reports `seaname`'s (§2.6.2); the regions the single program never walks (a
`match`, a `for` over anything but a range) are copied unresolved and count no symbol (§3.4.1); `sealower.bas` is cut into two files without changing a line (§2.7).
**Left open for 4b** (to be settled with the phase-4 specification): which index the bounds
message names for a range index out of bounds; `str(x)` of NaN and ±∞; the order of the two shapes
in `shape mismatch` for an indexed or masked assignment, and the pair reported for a 3-operand
`where`; the order of the checks of an indexed assignment (value, indices, shapes); the type of
`[]` under a matrix context and `filled` with `str` and struct values; the evaluation order of
`x[sel] op= e`.

**Scope of Sea v1.** LANGUAGE.md §1.2: what the five acceptance workloads (`sea/workloads/`)
need, done well, plus the generality that keeps the language coherent; the non-goals are
LANGUAGE.md §1.3.

**Sources.** `sea/README.md`, `sea/CLAUDE.md`, `sea/workloads/README.md` and the five
`w*.m` scripts; Baysick's `docs/LANGUAGE.md` (0.6.0), `docs/DESIGN.md`, `docs/IR.md`,
`docs/BENCH.md`, `docs/SEA_BOOTSTRAP.md`.

### 0.1 Glossary

The implementation terms. LANGUAGE.md §0.1 defines the terms of the language (class E, class R,
elemental function, view, COW, prelude, intrinsic, handle type, port).

| Term | Meaning |
|------|---------|
| **fusion** | Compiling a chain of element-wise operations (and an optional reduction) into one loop with no temporary arrays (§5.1) |
| **pass** | One of the Baysick programs that make up the Sea compiler (§2.3) |
| **HIR / LIR** | The compiler's typed high-level and loop-level intermediate representations, written as text files between passes (§2.4) |
| **variant** | A set of SIMD kernels or fused-loop code for one instruction-set level (`neon`, `sse2`, `avx2`), chosen at startup (§4.4), as in Baysick DESIGN.md §6.6 |
| **MATLAB baseline** | `sea/workloads/reference/baseline_timings_matlab.json` (§1.2) |
| **record** | One line of an intermediate file: an opcode and its fields (§3.1) |
| **header record** | A record whose opcode starts with `#` (`#sea`, `#target`, `#file`, `#end`, §3.2) |
| **position** | `F:L:C`, a source file, line and column carried by every syntax-tree node (§3.1, §3.3) |
| **virtual register** | A typed variable of LIR (`i`, `f`, `p`, `x`, `y`, `m` classes, §3.6.1), mapped to machine registers or stack by pass 4 |
| **site** | `F:L`, the source line a run-time error check reports (§3.1, §4.5) |

## 1. Goals and how they are measured

### 1.1 Goals, in priority order (decided by the user)

1. **Raw speed.** Ahead-of-time native code; fused element-wise loops with no temporaries;
   hand-written SIMD kernels (NEON; SSE2/AVX2) behind CPU-feature dispatch; honest
   benchmarks against Accelerate/OpenBLAS, which are the bar and never a dependency.
2. **A cleaner language than MATLAB.** Modern C/Rust-like syntax, deliberately not
   MATLAB-compatible.
3. **Free, tiny, portable.** Standalone native binaries, no giant runtime; targets
   `arm64-macos` and `x86_64-linux`, mirroring Baysick.

### 1.2 Measured by the five workloads

Sea v1 is done when, for each of `w1_shaft_design` … `w5_tolerance_mc`, a Sea port (§6.3):

1. **reproduces the numbers**: its JSON export passes `compare.py`'s rules (`RULES` in
   `sea/workloads/reference_py/compare.py`) against the MATLAB reference
   `reference/<name>.json`, on both targets;
2. **prints an equivalent text report**: the same lines as the MATLAB report (§6.4 defines
   "equivalent");
3. **is faster than MATLAB**, on both measures below, on the machine that produced the MATLAB
   baseline;
4. **writes its figures** as SVG files (LANGUAGE.md §12) when asked to.

**The MATLAB baseline.** `reference/baseline_timings_matlab.json` (Decision 7, sea commit
c1736f7) was written by `run_all.m` with MATLAB `26.1.0.3346908 (R2026a) Update 5`, `arch` =
`maca64`, on an Apple M2 Pro (`Mac14,9`), with MATLAB's default thread count
(`maxNumCompThreads` = 10), five repetitions per workload. Its values (seconds; the first run
includes MATLAB's JIT warm-up; median and best over all five runs):

| Workload | total, first | total, median | **total, best** | compute, first | compute, median | **compute, best** |
|----------|-------------:|--------------:|----------------:|---------------:|----------------:|------------------:|
| w1_shaft_design | 0.595 | 0.583 | 0.573 | 0.527 | 0.522 | 0.511 |
| w2_truss_fem | 1.022 | 1.129 | 0.956 | 1.000 | 1.108 | 0.936 |
| w3_quarter_car | 0.733 | 0.729 | 0.720 | 0.641 | 0.640 | 0.631 |
| w4_heat_plate | 0.912 | 0.918 | 0.907 | 0.906 | 0.912 | 0.902 |
| w5_tolerance_mc | 0.862 | 0.808 | 0.768 | 0.858 | 0.805 | 0.764 |

The bests are the pass criterion (below). `reference/baseline_timings_matlab_1thread.json`
holds the same five-run measurement with `maxNumCompThreads(1)` on the same machine; it is
reported next to Sea's numbers (§6.5), not compared:

| Workload | total, first | total, median | total, best | compute, first | compute, median | compute, best |
|----------|-------------:|--------------:|------------:|---------------:|----------------:|--------------:|
| w1_shaft_design | 0.683 | 0.634 | 0.588 | 0.602 | 0.571 | 0.526 |
| w2_truss_fem | 0.571 | 0.391 | 0.379 | 0.543 | 0.369 | 0.358 |
| w3_quarter_car | 0.806 | 0.744 | 0.737 | 0.710 | 0.651 | 0.646 |
| w4_heat_plate | 1.104 | 0.861 | 0.851 | 1.091 | 0.856 | 0.846 |
| w5_tolerance_mc | 1.627 | 1.565 | 1.539 | 1.617 | 1.561 | 1.533 |

The comparison is valid only on the machine the files name (the user's M2 Pro); §6.5 requires
the Sea measurement to name its machine.

**What "faster than MATLAB" means.** Two measures, both required:

* **Compute time**: the time the program measures around the same region as the MATLAB
  script's `tic`/`toc` (`computeSeconds`), with Sea's `now()` (LANGUAGE.md §13). Compared: Sea's best of 5
  consecutive runs against MATLAB's best compute time above (also a best of 5, §5.7). Sea's
  first run is reported next to MATLAB's first run but is not a pass criterion.
* **Whole-process time**: wall time from `exec` of the compiled Sea binary to its exit, with
  the reference export enabled (MATLAB's `total_seconds` includes the `jsonencode` export) and
  figures disabled (as in `run_all`). Compared: Sea's best of 5 against MATLAB's best
  `total_seconds`. This is
  conservative in MATLAB's favour: MATLAB's total is measured inside an already running
  MATLAB session and excludes MATLAB's own start-up, while Sea's includes everything the
  operating system does to start the process.

Sea's compile time is reported next to these numbers but not counted: an AOT binary is
compiled once and run many times. The methodology is §6.5; its known asymmetries (MATLAB ran
multithreaded, Sea single-threaded) are stated in §5.7; the MATLAB rerun of Decision 7 in §9
supplied the five-run and single-threaded baselines above.

### 1.3 Non-goals

The non-goals of v1, each with its reason, are LANGUAGE.md §1.3.

## 2. Compilation model and toolchain

### 2.1 Pipeline

```
 prog.sea ─┐
 std.sea ──┴─► sea (POSIX sh driver): header + tagged source lines on stdin
                  │   temporary directory, all passes run with it as working directory
                  ▼
   1   seaparse    stdin   ─► sea.ast   lex, parse
   2a  seaname     sea.ast ─► sea.res   names and scopes, items and signatures, the values of
                                        constants, constant exponents (§3.4.1)
       seacheck    sea.res ─► sea.hir1  types, ranks, untyped constants, library overloads,
                                        format strings, match, ref aliasing; writes the HIR
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
temporary directory (Baysick `FILES` names are fixed at compile time, Baysick LANGUAGE.md §7.21), and
report through their exit status and standard error. The number of passes (eight programs, plus
the second code generator) follows from the size calibration of §2.7; it is part of Decision 2
in §9. Pass 2a is two programs from phase 4a on (Decision 17, §2.7, §8): `seaname` resolves and checks
the declarations and evaluates the constants, `seacheck` checks and types the rest and writes
`sea.hir1`; "pass 2a" in this document means the two together, and §2.6.2 says which of them
reports each error.

### 2.2 The driver: `sea`

A POSIX `sh` script (name: Decision 15 in §9):

```
sea build <file.sea> [-o <out>] [--target arm64-macos|x86_64-linux] [-S]
                     [--emit ast|res|hir1|hir|lir1|lir] [--keep-temps] [--no-prelude]
sea run <file.sea> [-- program arguments…]          build into the temporary directory, run
sea --version | --help
```

**Why a shell script.** A Baysick program cannot start processes, and Sea's compiler needs
several passes plus the system assembler and linker; the driver only sequences them. `/bin/sh`
exists on both hosts, and the script needs nothing beyond POSIX utilities (`mktemp`, `sed`,
`awk`, `tail`, `rm`).

**Steps of `sea build`:**

1. Locate the installation directory (the script's own directory with symbolic links resolved,
   or `$SEA_HOME`, which the test runners set) holding the pass executables, `std.sea`,
   `errors.inc`, `limits.inc`, `libsea.a` and `libbaysickrt.a` (§2.10; run from the source tree,
   the driver takes `errors.inc` and `limits.inc` from `../include` when the directory has no
   copy). A file the build needs that is missing (`std.sea` unless `--no-prelude`, a pass
   executable, `errors.inc`, `limits.inc`, and for a linked program `libsea.a` and
   `libbaysickrt.a`) is an incomplete installation: driver status 4 (`SEA_EXIT_INTERNAL`). The
   driver reads `SEA_LIM_LINE_BYTES` and `SEA_FILE_VERSION` from `limits.inc` and the exit
   statuses from `errors.inc`. Each file is checked when the build first needs it (a pass
   executable just before that pass runs, the libraries before linking), so a build that stops
   earlier (a compile error, `--emit`, `-S`) does not report a missing later file.

   **Input read once.** The driver copies the program file into the temporary directory before
   anything else reads it, and every later step (the line check, pass 1's input) reads that copy,
   so the input may be a pipe or another non-regular file (`sea run /dev/stdin`, `sea build -o
   prog /dev/stdin`; without `-o` the default output `/dev/stdin.out` is not writable). Whenever
   the command writes an output file (`sea build`, with or without `-o`: the linked program, the
   `-S` assembly, or an `--emit` dump written to a file), the driver checks that file against the
   input before anything is written: if it is the input file itself (the same file, `test -ef`,
   also through a link, as `sea build -S a.sea` when `a.s` is a link to `a.sea`), the build is
   refused with `sea: output file '<path>' is the input file`, status 2. `sea run` writes no
   output file, so it makes no such check.
2. Check the source lines (`LC_ALL=C awk`) of the program's file: one CR at the end of a line
   (before its LF, or at the very end of the file) is removed first, as LANGUAGE.md §3.1 says,
   and a line that then has more than `SEA_LIM_LINE_BYTES` (4096) bytes is reported as the
   compile error `line too long` at its column 4097 (`<file>:<line>:4097: error: line too long`,
   LANGUAGE.md §9.1) before any pass runs, because a Baysick `LINPUT` of a line over 65 536 bytes
   would stop pass 1 with a Baysick error instead of a Sea diagnostic. The message text is read
   from the installed `errors.inc`, never written into the script: `awk` takes the error record
   (§2.6.2, "Line shapes") whose second field is `LINE_TOO_LONG`, and its text between the quotes,
   with `\"` read as `"` and `\\` as `\`.
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
   and an empty source line is still a line (`|`). Each `#file` record holds its path as an
   escaped string field (§3.1, §3.2), so any path, including one with blanks, reaches the
   diagnostics unchanged. This is the "options on stdin" protocol (Baysick has no command-line
   arguments, by decision, Baysick LANGUAGE.md §15.1). With `--no-prelude` the `std.sea` file
   and its lines are left out; the option exists for the dump tests of §3.8, whose programs then
   cannot use the prelude's functions (a use is the compile error `undeclared name`, because the
   prelude's names are then not declared at all). Pass 1 reads the files as one token stream:
   tokens and open brackets continue across a `#file` record, a block comment still open at a
   `#file` record is `unterminated comment` (at its `/*`), and `unexpected end of file` occurs
   only at the end of the program file, the last.
5. Run the passes in order. Pass 1 writes the header records of §3.2 at the start of its
   output and every later pass copies those of its input, so every pass knows the target and the
   file names for diagnostics.
6. **End-of-input discipline.** Baysick ends a program with exit status 0 on `OUT OF DATA` and
   on the end of input met by a plain `INPUT` or `LINPUT` (Baysick LANGUAGE.md §7.15, §15.2), so a pass
   bug could otherwise look like success. Therefore every pass:
   * reads its input only with `LINPUT #k` after an `IF END #k` test (`k` = 0 for pass 1's
     standard input, else its input file), never with plain `INPUT`/`LINPUT`;
   * requires the final record `#end` of its input, and if the input ends without it writes
     `<pass>: internal error: truncated input` (`TRUNCATED`, §2.6.2) and stops with status 11;
   * writes `#end` as the last record of its own output, after everything else (pass 1 reads
     its input as it parses, so a compile error found before the input ends is reported, status
     10, even when the input is truncated);
   * reads its `DATA` tables with counted loops whose counts are checked against a sentinel
     value at the end of each table.

   The driver additionally checks that each output file ends with the line `#end` before it
   starts the next pass.
7. Pass exit statuses: **0** success; **10** a Sea compile error (the pass has written the one
   diagnostic line of LANGUAGE.md §9.1 to standard error with `PRINT #-1` and ended with `STOP 10`);
   **11** an internal consistency check failed (message on standard error); **1** a Baysick
   run-time error inside the pass (a compiler bug or a Baysick limit; Baysick's message is on
   standard error). Status 0 without a final `#end` in the output is treated like 11. The driver
   stops at the first failure.
8. `-S`: copy `sea.s` to the output. `--emit X` (X one of `ast`, `res`, `hir1`, `hir`, `lir1`,
   `lir`; formats in §3): stop after the pass that writes `sea.X` and copy it unchanged. `seaname`
   ends with status 0 also when it found an error (it hands the error to `seacheck` in the
   `rerr` record, §3.4.1), so `--emit res` writes such a file and exits 0, as `--emit ast` does
   for a program with a type error: an error is reported only by the program that reports it. Otherwise (arm64-macos): assemble and link exactly as Baysick does (Baysick DESIGN.md §4.3,
   §5.2: `as -arch arm64 -mmacosx-version-min=11.0`, `ld … -lSystem -syslibroot <sdk> -e _main`,
   the SDK from `xcrun --show-sdk-path`, never a made-up `SDKROOT`, and `SDKROOT` removed from
   the tools' environment). `x86_64-linux` is a cross target: `sea build` writes the `.s`, and
   `sea/tests/cross*.sh` assemble and link it on the Linux host (§6.6).
9. Remove the temporary directory unless `--keep-temps`.

**Driver output and messages.** `--emit X` without `-o` writes the dump to standard output; `-S`
without `-o` writes `<stem>.s` and a linked program goes to `<stem>`, where `<stem>` is the
program's path without its `.sea` suffix (or the path followed by `.out` if it has none); `-S` and
`--emit` cannot be combined. `sea run <file.sea> [--keep-temps] [--no-prelude] [-- arguments…]`
builds into the temporary directory and runs the program with the arguments. The `#file` record
of `std.sea` holds its absolute installed path, that of the program the path as given (so
diagnostics read as the user wrote the path). A pass's standard output is sent to the driver's
standard error (a pass writes nothing there); its standard error passes through. `sea
--version` prints `sea 0.1.0`. The driver's own messages, each `sea: ` + text + LF on standard
error: the usage text (`usage: sea build <file.sea> …`, after a message naming the bad option,
status 2), which also follows `unknown command '%s'`, `unknown option '%s'`, `missing argument
for '%s'`, `unexpected argument '%s'`, `missing input file`, `-S and --emit cannot be combined`
and `run needs the native target`; `unknown target '%s'`, `unknown emit kind '%s'` (2); `output
file '%s' is the input file` (2); `cannot read '%s': <reason>` for the program file (2); `cannot create temporary directory`,
`cannot write in '%s'`, `cannot write '%s'` (2); `cannot find '%s'` and `cannot find runtime
library '%s'` (4); `internal error: pass executable '%s' not found (run make)`, `internal error:
%s failed with exit status %d`, `internal error: %s wrote no complete %s (no final #end)`,
`internal error: %s wrote no %s` (4); `cannot determine macOS SDK path`, `cannot run '%s': not
found`, `'%s' failed with exit status %d` (3); with `--keep-temps`, `temporary files kept in %s`.

**Driver exit statuses** (the meanings of Baysick DESIGN.md §4.2): 0 success; 1 Sea compile
error; 2 usage or file error; 3 toolchain error (`as`/`ld`/`xcrun` missing or failing); 4
internal error (pass status 1 or 11, a missing `#end`, out of memory). Driver messages start with
`sea: `. `sea run` exits with the program's own status once the program runs, so its statuses
overlap the driver's (a run-time error and a compile error are both 1); a caller that must tell
them apart uses `sea build` and runs the program itself.

### 2.3 What the compiler emits, and why

**Decision: the compiler emits target assembly text directly, one code generator pass per
target; it does not reuse Baysick's IR or backends, and it does not emit C.**

* **Not Baysick IR.** Baysick's IR (`docs/IR.md`) is an in-memory binary structure inside the
  Baysick compiler, with a dump format but no reader; every value in it is a double, it has no
  integers, vectors, pointers or loops, and its opcodes are BASIC statements. Making Baysick
  read a Sea-shaped IR would mean writing a second compiler inside Baysick's assembly.
* **Not C.** A C compiler is a giant dependency (priority 3) and would take the exact
  operation-order guarantee (LANGUAGE.md §6.8) out of Sea's hands (contraction defaults, vectorizer
  reassociation flags).
* **Assembly text from a Baysick program is practical.** Baysick 0.6.0 reads lines verbatim
  (`LINPUT`), slices and builds strings (`SEG$`, `POS`, `&`, `STR$`, `CHANGE`), structures a
  program into recursive subprograms (`SUB`/`CALL`), keeps tables in arrays of up to 10⁶
  elements, and writes text files (`PRINT #`). The calibration programs of §2.7 do exactly this.
  The system assemblers do the encoding.
* **Speed does not need a sophisticated backend in the first place.** The hot paths of the
  workloads are (a) dense kernels (GEMM, factorizations, sort), which are hand-written assembly
  in the runtime and called; (b) fused element-wise loops, which pass 3 builds as simple
  counted loops whose bodies pass 4 maps to SIMD instructions one to one; and (c) scalar loops
  (SOR, LCG, RK4, bisection), which need a register allocator and decent instruction selection,
  not global optimizations. §5 states what code each must become.

### 2.4 Intermediate files

All intermediate files are line-oriented text: one record per line, fields separated by one
space, an opcode first, the header records first and `#end` last (§2.2). Numbers in records are
written so that a Baysick program reads them without precision loss: integers below 10⁹ in
decimal (Baysick's `VAL` reads at most 9 digits, Baysick LANGUAGE.md §6.1), larger integers and every
`f64` as 16 hexadecimal digits of the 64-bit pattern (`#3FB999999999999A`), strings as
`%`-escaped bytes. The exact record formats are §3 (machine-readable in `passes.txt`, §2.6,
§3.9), each with an `--emit` dump example that is also its dump test, like Baysick IR.md §5.

**LIR** is a linear, typed, three-address code over virtual registers (`i64`, `f64`, `ptr`,
`v2f64`/`v4f64`, `mask`) with explicit structured loops (`loop` / `endloop` with an induction
register), loads and stores with base + index·scale + offset addressing, calls to runtime entry
points, and the reproducibility rules of LANGUAGE.md §6.8 built in (no reassociation, no FMA opcode). It
plays the role Baysick's IR plays for Baysick's backends, but is lower level.

### 2.5 The standard library: intrinsics, runtime, prelude

| Part | Contents |
|------|----------|
| **Compiler intrinsics** (passes 2–3) | operators, views, indexing, `len rows cols numel`, conversions, `where`, reductions (fused into loops), the elemental math functions (inline code or runtime calls), `printf`/`format` (pre-parsed formats), and **`write_json`**, which pass 2b expands per static type into calls of the runtime's JSON emitter (LANGUAGE.md §11.4) — so no generics or reflection are needed |
| **Runtime** (assembly, `libsea.a`, §4) | memory, strings, number-to-text conversion, I/O, clock, the elementary functions, sorting, linear-algebra kernels, the JSON emitter, and the **plotting library**: the `Figure`/`Axes` handle objects, layout, SVG writer and PNG/base64 encoder (LANGUAGE.md §12.1) |
| **Prelude** `std/std.sea` | what is naturally written in Sea with value semantics: `linspace`, `meshgrid`, `setdiff`, `bincount` (marked **(P)** in LANGUAGE.md §10); until phase 4 (§8), which brings the arrays these functions need, it holds comments only, and the driver streams it as usual |

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
the compiler. The cost is runtime assembly on two targets (§2.7 estimates it).

### 2.6 Contract files

As in Baysick, everything shared between separately written components is pinned in files that
change only together with the matching doc section:

| File | Contents | Shared by |
|------|----------|-----------|
| `sea/include/limits.inc` | the capacity limits of §2.7, the limits of the intermediate files (§3.1) and the language limits of LANGUAGE.md §3.1 | passes, runtime, tests |
| `sea/include/errors.inc` | every compile-time and run-time error text, with codes | passes (messages), runtime (`_sea_err`) |
| `sea/include/rt.inc` | array, string and handle layouts, entry-point names, error-site table layout, kernel variant ids | pass 4 (both), runtime (both targets) |
| `sea/include/passes.txt` | the record opcodes and fields of every intermediate file | all passes |
| `sea/include/math_tables.inc` | the constants and tables of the elementary functions (§4.10.3), **generated** by `tools/math_tables.py` from their definitions in §4.10 and committed; no contract names (`SEA_*` `.equiv`s) other than its guard, so `make check-contracts` does not read it, while `make check-includes` assembles it on both assemblers | both runtimes (`rt_math.s`); `tools/gendata.bas`, for the `mtab` `DATA` block of `seaname` (pass 2a, §2.6.3) |
| **Baysick's `include/runtime.inc`** (cross-repository) | `MV_*` (matrix views), `KS_*` (kernel statuses), `KV_*` (variant records), `KF_*` (feature bits), and the `_bsk_kern_*` entry points of Baysick DESIGN.md §6.6 | Sea's runtime, which `.include`s it from the Baysick checkout; a change there is a change to Sea's contract too, so Baysick's contract rule (CLAUDE.md) covers it, and a Sea test assembles Sea's runtime against the current file |

The `.inc` files follow Baysick's dual-assembler rules (Baysick DESIGN.md §3.4). Baysick programs
cannot `.include`, so the passes get the same numbers and texts from the contract files through
generated `DATA` blocks: `sea/tools/gendata.bas`, a Baysick program, reads the contract files and
writes the `DATA` lines, and every build regenerates them, so a pass's `DATA` is current by
construction (§2.6.3). (Error texts must be `DATA`, not string constants: §2.7.) The entry points
of `rt.inc` that passes 3a and 3b write into `rcall` records (§3.6.4) and the layout values pass
3a addresses with reach them the same way. `passes.txt` is not an assembler file; its format is
§3.9.

The `.inc` files define every name with `.equiv` (an error if the name is already defined), so
a clash between Sea's names and Baysick's `include/runtime.inc`, which Sea's runtime includes
too, is an assembly error; the include checks of §6.2 assemble Sea's three files after
Baysick's `include/limits.inc` and `include/runtime.inc` on both assemblers to prove there is
none (`make check-includes` on the Mac, `make cross-includes` on the Linux host), and `make
check-contracts` (§6.2) checks that the files and the tables of this document say the same in both
directions. Every name of
Sea's files begins with `SEA_` (or `sea_` for the labels the table macros emit). Baysick's
`include/runtime.inc` needs nothing else and assembles on its own with both assemblers; Sea's
runtime includes it after Sea's own include directory in the search path, because Baysick's
`limits.inc` and `errors.inc` share Sea's file names (the include check names Baysick's two
files by absolute path for the same reason).

#### 2.6.1 `limits.inc`

| Name | Value | Meaning | Source |
|------|------:|---------|--------|
| `SEA_LIM_LINE_BYTES` | 4096 | bytes per source line after CR removal (`line too long`) | LANGUAGE.md §3.1 |
| `SEA_LIM_IDENT_BYTES` | 63 | bytes per identifier (`identifier too long`) | LANGUAGE.md §3.3 |
| `SEA_LIM_UESC_DIGITS` | 6 | hexadecimal digits in `\u{…}` (`invalid escape`) | LANGUAGE.md §3.5 |
| `SEA_LIM_UESC_MAX` | `0x10FFFF` | largest code point of `\u{…}` (`invalid escape`) | LANGUAGE.md §3.5 |
| `SEA_LIM_FIXED_ELEMS` | 256 | elements of a fixed-size array; larger literals are dynamic | LANGUAGE.md §4.5, §6.9 |
| `SEA_LIM_EXTENT` | 2147483647 | largest extent of a dynamic array (2³¹ − 1) | LANGUAGE.md §4.5 |
| `SEA_LIM_STR_BYTES` | 2147483647 | largest `str` length in bytes (2³¹ − 1) | LANGUAGE.md §4.1 |
| `SEA_LIM_POWK` | 4 | `x ^ k` by the pinned multiplications for a constant integral \|k\| ≤ 4 | LANGUAGE.md §6.5 |
| `SEA_LIM_FIXED_MATMUL_E` | 8 | fixed-size `@` is class E when every extent is ≤ 8 | LANGUAGE.md §6.8 |
| `SEA_LIM_INLINE_STMTS` | 50 | statements of a function inlined by rule (c) | LANGUAGE.md §8.6 |
| `SEA_SUM_LANES` | 8 | accumulators of the pinned summation order | LANGUAGE.md §10.5 |
| `SEA_LIM_NODES` | 99999 | syntax-tree nodes per compilation, prelude included (`program too large: nodes`) | §2.7 |
| `SEA_LIM_SYMBOLS` | 49999 | symbols (`… symbols`) | §2.7 |
| `SEA_LIM_TYPES` | 19999 | types (`… types`) | §2.7 |
| `SEA_LIM_CONSTS` | 19999 | distinct numeric constant values (`… constants`) | §2.7 |
| `SEA_LIM_STRINGS` | 199999 | distinct strings (`… strings`) | §2.7 |
| `SEA_LIM_NESTING` | 64 | nesting depth of blocks and expressions, §2.7 (`… nesting`) | §2.7 |
| `SEA_LIM_PARAMS` | 64 | parameters per function (`… parameters`) | §2.7 |
| `SEA_LIM_FIELDS` | 64 | fields per struct (`… fields`) | §2.7 |
| `SEA_LIM_RESULTS` | 64 | results per function (`… results`) | §2.7 |
| `SEA_LIM_LIR_INSTRS` | 199999 | LIR instructions per function; pass 3a's buffered records per function (`… instructions`) | §2.7 |
| `SEA_LIM_LIR_OPERANDS` | 799999 | operand fields of one function's LIR instructions (`… operands`) | §2.7 |
| `SEA_LIM_LIR_REGS` | 99999 | virtual registers per function (`… registers`) | §2.7 |
| `SEA_LIM_LIR_BLOCKS` | 9999 | structured LIR constructs (`loop`, `do`, `if`, `ifz`) per function (`… blocks`) | §2.7 |
| `SEA_LIM_LIR_SLOTS` | 9999 | stack slots per function (`… slots`) | §2.7 |
| `SEA_LIM_LIR_IMMS` | 199999 | `li`/`lf` constants per function (`… immediates`) | §2.7 |
| `SEA_LIM_LIR_LABELS` | 49999 | LIR data labels per compilation (`… labels`) | §2.7 |
| `SEA_LIM_LIR_SITES` | 49999 | distinct run-time error sites per compilation (`… sites`) | §2.7 |
| `SEA_FILE_VERSION` | 1 | the version field of the `#sea` header record | §3.2 |
| `SEA_LIM_RECORD_BYTES` | 65536 | bytes per intermediate-file line, LF excluded (one Baysick `LINPUT`) | §3.1 |
| `SEA_LIM_DEC_FIELD` | 999999999 | largest `u` field; an `i` field is decimal exactly when \|v\| ≤ this | §2.4, §3.1 |
| `SEA_LIM_PASSES_LINE` | 255 | bytes per line of `passes.txt`, LF excluded | §3.9 |
| `SEA_STDOUT_BUF_BYTES` | 65536 | standard-output buffer | LANGUAGE.md §11.3 |
| `SEA_JSON_BUF_BYTES` | 65536 | `write_json` file buffer | LANGUAGE.md §11.4 |
| `SEA_STACK_BYTES` | 67108864 | program stack (64 MiB), plus a guard page | §4.6 |
| `SEA_SMALL_MAX_BYTES` | 4096 | largest small block; larger blocks come from `mmap` | §4.1 |
| `SEA_CHUNK_BYTES` | 1048576 | chunk refilling the small-block free lists (1 MiB) | §4.1 |
| `SEA_LCACHE_PER_CLASS` | 8 | cached free large blocks per power-of-two size class | §4.1 |
| `SEA_LCACHE_MAX_BYTES` | 268435456 | cached free large blocks in all (256 MiB) | §4.1 |

#### 2.6.2 `errors.inc`

**Contents.** The error table (every message of the compiler, the driver's `line too long`, the
passes' internal checks and the runtime), the errno text table, the exit statuses, the layout of
the two tables the runtime emits, and two macros that emit them. Texts are byte-identical to
LANGUAGE.md wherever LANGUAGE.md gives the text (column "Source" below); the texts whose
Source is "defined here" are defined by this table: LANGUAGE.md states the condition as an error, or the condition follows from
the grammar or the type rules, but gives no text, and LANGUAGE.md §9.1 delegates "the full list"
to this table. A code is never reused or renumbered; a new message is appended in its range.

**Fields of an error record.**

* `code`: run-time codes are dense from 1 (`_sea_err` accepts 1 … `SEA_E_RT_END` − 1 = 21,
  `SEA_E_RT_END` = 22) because the runtime's table is indexed by them; the driver's and pass 1's
  codes are 100 … 199, pass 2's 200 … 399, the capacity code 400 … 499, the passes' internal
  checks 500 … 599. The assembler name is `SEA_E_<NAME>`; LIR's `chk` record names the code by
  `<NAME>` (§3.6.4), and pass 4 turns it into `SEA_E_<NAME>`.
* `phase`: `R` a run-time error (`_sea_err`, exit status 1); `D` reported by the driver before any
  pass (§2.2 step 2); `C1` pass 1; `C2` pass 2a (`seaname` or `seacheck`: "Which program reports it" below) or 2b; `CX` any pass (a capacity limit of §2.7);
  `P` a pass's internal consistency check (pass status 11, §2.2).
* `at` (LANGUAGE.md §9.1 requires a position but names none; this column names it): the
  position a compile-time diagnostic `<file>:<line>:<col>` reports (LANGUAGE.md §9.1); `-` for
  `R` and `P` (a run-time error reports the line of its LIR site, §3.6.4). The words:

| `at` | Position reported |
|------|-------------------|
| `byte` | the offending byte; for `invalid escape` the `\` that starts the escape |
| `token` | the first byte of the offending token: for `unterminated comment` the `/*`, for `unterminated string` the opening `"`, for `comparisons cannot be chained` the second comparison operator, for `'$' outside an index` the `$`; for `unexpected newline` the LF that ends the line, after any comment on it (column = the line's length in bytes after CR removal + 1; for the line break of a block comment that spans lines, the first LF inside the comment); for `unexpected end of file`, the position just after the last byte of the program file's last line (line 1, column 1 for an empty file); a last line without a final LF still ends with an NL token, at the position just after its last byte (so `unexpected newline` there reports that position) |
| `over` | column `SEA_LIM_LINE_BYTES` + 1 (the first byte beyond the limit) of the line |
| `stmt` | the first token of the statement |
| `here` | pass 1 (which enforces `nodes`, `strings`, `nesting`, `parameters`, `results` and `fields`, §2.7): the token whose addition exceeds the limit (the token that opens the 65th nesting level, starts the 65th parameter, result type or field); passes 2a (`seaname`: `symbols`, the types of signatures, and while reading `nodes`, `strings` and the `constants` of literals; `seacheck`: the other types and the `constants` of the values of constants), 2b and 3a: the position of the record being read, created or lowered when the limit is exceeded, if it has a `pos` field anywhere among its fields (a node, or a `cn`, `fn` or `loc` record; for the `symbols` limit, the position of the declaration being entered: an item (`fn`, `const`, `struct`) at its keyword node, a local at its name, a loop variable at its `npos`, a parameter at its `param` node; for the `constants` limit, a literal at its node and a constant's value at its item; for a type of a signature, the `fn` item); for a record without one (a type record, §3.5.1), the `pos` of the next record that has one, the look-ahead stopping at the next `fn` or `cn` record (whose `pos` is then used) and at `#end` (then line 1, column 1 of the program file); passes 3b and 4: the position of the `func` record (§3.6.3) of the function being processed |
| `expr` | the expression node at fault: for `type mismatch`, `condition must be bool`, `index must be i64`, `integer constant not exact in f64`, `not a constant expression`, `cannot iterate over`, the format errors and `argument for ref parameter …` the expression itself (the argument, condition, index, iterable, constant expression; for the arms of an `if` expression whose types differ, the `else` arm, with `expected` the then-arm's type and `found` the else-arm's); for `integer overflow` and `integer division by zero` in a constant (codes 260, 261) the operator node (`bin`, `neg`) whose evaluation fails, the innermost first in evaluation order; for the operand errors (`cannot combine…`, `shape mismatch`, `vector @ vector…`, `operator … cannot be applied…`) the operator node (`bin`, `neg`, `not`, or the `call` of an elemental function or `where`); for `shape mismatch` of a value stored into a fixed-size type (initialisation, assignment, argument passing, return: `let a: f64[4] = [1.0, 2.0, 3.0]`), the value expression, and the text names the target's shape first (`shape mismatch: 4 vs 3`) |
| `name` `slit` `init` `match` `arm` `ref` `call` `narg` `dot` `index` `row` `struct` `fn` `param` `str` `break` `continue` | that node of `sea.ast` (§3.4): `init` the repeated (second) or unknown initializer; `arm` the arm with the repeated pattern; `ref` the first `ref` argument, in source order, whose root another argument shares (`ref argument aliases…`) or the offending `ref` argument; `row` the first row whose length differs or that mixes vectors and matrices; `str` the format string literal; `call` for `elemental function cannot be recursive` the first call, in source order, on a cycle of calls through an elemental function |
| `item` | the `const`, `struct` or `fn` node of the top-level item |
| `binding` | the node declaring the name: `pname`, `param`, the `for` node (for a loop variable every error is reported at the `for` node; the AST `npos` field is used only for the `loc` record's position, §3.4, §3.5.4), a struct's `field`, or the `const`/`struct`/`fn` item; for `redefinition of '%s'` the later declaration |
| `fieldname` | the `field` or `init` node of the reserved name |
| `effect` | the `param` node of a `ref` parameter, or the `call` that has effects |
| `type` | the `type` node; for a literal, its `slit` (`unknown struct type`) or `array` (`arrays cannot hold %s`) node |
| `target` | the assignment target (the position of its text) |
| `results` | the `return` node (also for `return f(…)` of a multiple-result call in a function without results), the `call` bound to a single name (`let y = two()`), or the `ptuple`/`tasg` node whose count differs; the texts read `expected` the number of the call's results (or the function's, at a `return`) and `found` the number of names (or values) |
| `construct` | the AST node (§3.4) of the first construct, in source order, that the compiler does not implement yet (`not supported yet: %s`, the phase rule below) |

* `args`: one letter per substitution, in text order, or `-` for none: `i` a decimal integer
  (`%d`), `f` an `f64` printed as Sea's `printf("%g")` prints it (LANGUAGE.md §11.1: `NaN`,
  `Inf`, `-Inf` for the non-finite values), `s` a byte string (`%s`), `h` a shape (`%s`: a matrix
  `RxC`, a vector `N`, in decimal, e.g. `16001x60`, `60`), `e` the errno reason (`%s`, from the
  errno table). In `_sea_err`'s argument slots (§4.8) `i` and `e` take one slot (an `i64`; `e` the
  host errno value), `f` one (the bits), `s` one (a string object), `h` two (rows; cols, or −1 for
  a vector).
* `text`: the message. Substituted values, where the text has
  `%s`/`%d` and LANGUAGE.md does not say what they are: a **type** is written as in Sea source
  (`f64`, `i64[]`, `f64[,]`, `f64[4]`, `f64[4,4]` — no spaces inside brackets —, a struct's name, `Figure`, an anonymous record as
  `{name: T, …}` with `, ` between fields, a tuple as `(T1, T2, …)`); a **name** as written;
  `unexpected token '%s'` the token's source text; in `format "%s" …` the format literal's bytes
  rendered canonically (not as written): `"` as `\"`, `\` as `\\`, LF as `\n`, TAB as `\t`, CR
  as `\r`, NUL as `\0`, every other byte below 0x20 and 0x7F as `\x` and two upper-case hex
  digits (`\x1B`), every other byte (0x20–0x7E, and 0x80–0xFF) as itself; in `format "%s" expects %s, found %s` the
  conversion as written (`%` through the conversion letter, e.g. `%8d`), then `an integer or f64`
  for `d i f F e E g G` or `str` for `s`, then the argument's type; in `invalid format
  conversion "%s"` the conversion as written from its `%` through the byte that makes it invalid
  (or the end of the string); in `operator '%s' …` the operator as written (`*`, `==`, `!`; for a
  compound assignment the compound operator, `+=`); in `'%s' is not a function` the callee's name
  when the callee is a name (a local, constant or struct), else its type; in `'%s' is not a ref
  parameter` the parameter's name, or the function's name for a library function (which has no
  `ref` parameters); in
  `no overload of '%s' accepts (%s)` the function's name and the argument types joined by `, `;
  in `view .%s …` the view name (`T`, `flat`, `col`, `row`); in `%s of an empty array` the
  function (`max`, `min`, `argmax`, `argmin`); in `program too large: %s` one of the words
  `nodes`, `symbols`, `types`, `constants`, `strings`, `nesting`, `parameters`, `fields`,
  `results`, `instructions`, `operands`, `registers`, `blocks`, `slots`, `immediates`, `labels`,
  `sites` (the capacity limits of §2.6.1, each limit's word in its "Meaning"); in `%s` (`USER`)
  the message formatted by `error` (LANGUAGE.md §9.3).

**Output.** A compile-time message is written by the pass (or the driver) as LANGUAGE.md §9.1
says; a `P` message as `<pass>: <text>` + LF on standard error, where `<pass>` is the program's
name (`seaparse`, `seaname`, `seacheck`, …), exactly one line, before the pass ends with `STOP 11`
(`SEA_EXIT_PASS_INTERNAL`); this holds for every `P` message, `TRUNCATED` and `BAD_HEADER`
included; a run-time message by `_sea_err` as LANGUAGE.md §9.2 says. One text is copied
outside `errors.inc`: the text of `BAD_DATA` is needed before a pass has read its `DATA`
tables, so `passes/lib/diag.bas` holds it as a constant, and `tests/lib_check.sh` checks that
it equals the error record.

**The error table.**

| Code | Name | Phase | `at` | Args | Text | Source |
|-----:|------|-------|------|------|------|--------|
| 1 | `INDEX_OOB` | R | - | `iii` | `index %d out of bounds for dimension %d of extent %d` | LANGUAGE.md §5.4, §9.2 |
| 2 | `SHAPE_MISMATCH` | R | - | `hh` | `shape mismatch: %s vs %s` | LANGUAGE.md §6.3, §9.2 |
| 3 | `SHAPE_EXPECTED` | R | - | `hh` | `shape mismatch: expected %s, got %s` | LANGUAGE.md §4.5 (a dynamic array to a fixed-size type) |
| 4 | `INT_OVERFLOW` | R | - | - | `integer overflow` | LANGUAGE.md §6.5, §9.2 |
| 5 | `INT_DIV_ZERO` | R | - | - | `integer division by zero` | LANGUAGE.md §6.5, §9.2 |
| 6 | `CONV_I64` | R | - | `f` | `conversion to i64: %g is not an integer` | LANGUAGE.md §9.2 |
| 7 | `RANGE_STEP_ZERO` | R | - | - | `range step is zero` | LANGUAGE.md §5.1, §9.2 |
| 8 | `ARRAY_SIZE` | R | - | `i` | `invalid array size %d` | LANGUAGE.md §9.2 |
| 9 | `EMPTY_REDUCE` | R | - | `s` | `%s of an empty array` | LANGUAGE.md §9.2 |
| 10 | `SINGULAR` | R | - | - | `matrix is singular` | LANGUAGE.md §9.2 |
| 11 | `NOT_POSDEF` | R | - | - | `matrix is not positive definite` | LANGUAGE.md §9.2 |
| 12 | `NOT_SYMMETRIC` | R | - | - | `matrix is not symmetric` | LANGUAGE.md §9.2 |
| 13 | `NOT_SQUARE` | R | - | `h` | `matrix is not square (%s)` | LANGUAGE.md §9.2 |
| 14 | `OUT_OF_MEMORY` | R | - | - | `out of memory` | LANGUAGE.md §9.2 |
| 15 | `STACK_OVERFLOW` | R | - | - | `stack overflow` | LANGUAGE.md §9.2 |
| 16 | `CANNOT_OPEN` | R | - | `se` | `cannot open '%s': %s` | LANGUAGE.md §9.2 |
| 17 | `CANNOT_WRITE` | R | - | `se` | `cannot write '%s': %s` | LANGUAGE.md §9.2 |
| 18 | `CANNOT_MKDIR` | R | - | `se` | `cannot create directory '%s': %s` | LANGUAGE.md §9.2 |
| 19 | `LINE_STYLE` | R | - | `s` | `invalid line style "%s"` | LANGUAGE.md §9.2, §12.3 |
| 20 | `COLOR` | R | - | `s` | `invalid color "%s"` | LANGUAGE.md §9.2 |
| 21 | `USER` | R | - | `s` | `%s` | LANGUAGE.md §9.2 ("the formatted message"); the text `%s` is defined here |
| 100 | `LINE_TOO_LONG` | D | over | - | `line too long` | LANGUAGE.md §3.1 |
| 101 | `ILLEGAL_CHAR` | C1 | byte | - | `illegal character` | LANGUAGE.md §3.1 |
| 102 | `UNTERMINATED_COMMENT` | C1 | token | - | `unterminated comment` | LANGUAGE.md §3.2 |
| 103 | `IDENT_TOO_LONG` | C1 | token | - | `identifier too long` | LANGUAGE.md §3.3 |
| 104 | `BAD_NUMBER` | C1 | token | - | `invalid numeric literal` | LANGUAGE.md §3.4 |
| 105 | `INT_TOO_LARGE` | C1 | token | - | `integer literal too large` | LANGUAGE.md §3.4 |
| 106 | `FLOAT_RANGE` | C1 | token | - | `float literal out of range` | LANGUAGE.md §3.4 |
| 107 | `BAD_ESCAPE` | C1 | byte | - | `invalid escape` | LANGUAGE.md §3.5 |
| 108 | `UNTERMINATED_STRING` | C1 | token | - | `unterminated string` | LANGUAGE.md §3.5 |
| 109 | `CHAINED_COMPARE` | C1 | token | - | `comparisons cannot be chained` | defined here (LANGUAGE.md §6.1: `a < b < c` is a compile error) |
| 110 | `DOLLAR_OUTSIDE` | C1 | token | - | `'$' outside an index` | LANGUAGE.md §5.3 |
| 111 | `NO_EFFECT` | C1 | stmt | - | `expression statement has no effect` | LANGUAGE.md §3.7, §7.1 |
| 112 | `UNEXPECTED_TOKEN` | C1 | token | `s` | `unexpected token '%s'` | defined here (any other violation of LANGUAGE.md Appendix A) |
| 113 | `UNEXPECTED_NEWLINE` | C1 | token | - | `unexpected newline` | defined here (an NL token where LANGUAGE.md Appendix A allows none) |
| 114 | `UNEXPECTED_EOF` | C1 | token | - | `unexpected end of file` | defined here (the input ends inside a construct) |
| 200 | `UNDECLARED` | C2 | name | `s` | `undeclared name '%s'` | LANGUAGE.md §9.1 |
| 201 | `TYPE_MISMATCH` | C2 | expr | `ss` | `type mismatch: expected %s, found %s` | LANGUAGE.md §9.1 |
| 202 | `VEC_MAT` | C2 | expr | - | `cannot combine a vector with a matrix: use .col or .row` | LANGUAGE.md §6.3, §9.1 |
| 203 | `INDEX_I64` | C2 | expr | - | `index must be i64` | LANGUAGE.md §5.2, §9.1 |
| 204 | `MISSING_FIELD` | C2 | slit | `ss` | `missing field '%s' in %s literal` | LANGUAGE.md §9.1 (§4.6 names it `missing field`) |
| 205 | `DUPLICATE_FIELD` | C2 | init | - | `duplicate field` | LANGUAGE.md §4.6 |
| 206 | `UNKNOWN_FIELD` | C2 | init | - | `unknown field` | LANGUAGE.md §4.6 |
| 207 | `NOT_EXHAUSTIVE` | C2 | match | - | `match is not exhaustive` | LANGUAGE.md §7.6, §9.1 |
| 208 | `UNREACHABLE_PATTERN` | C2 | arm | - | `unreachable pattern` | LANGUAGE.md §7.6 |
| 209 | `REF_ALIAS` | C2 | ref | - | `ref argument aliases another argument` | LANGUAGE.md §8.3, §9.1 |
| 210 | `FORMAT_ARG` | C2 | expr | `sss` | `format "%s" expects %s, found %s` | LANGUAGE.md §9.1 (`format "%d" expects an integer or f64, found str`) |
| 211 | `FORMAT_COUNT` | C2 | call | `sii` | `format "%s" expects %d arguments, found %d` | LANGUAGE.md §11.1 |
| 212 | `PREDECLARED` | C2 | item | - | `redefinition of predeclared name` | LANGUAGE.md §3.3 |
| 213 | `SHADOWS_PREDECLARED` | C2 | binding | - | `local name shadows a predeclared name` | LANGUAGE.md §3.3 |
| 214 | `NOT_EXACT_F64` | C2 | expr | - | `integer constant not exact in f64` | LANGUAGE.md §4.2 |
| 215 | `COND_BOOL` | C2 | expr | - | `condition must be bool` | LANGUAGE.md §4.3 |
| 216 | `FIXED_TOO_LARGE` | C2 | type | - | `fixed-size array too large: use a dynamic array` | LANGUAGE.md §4.5 |
| 217 | `SHAPE_MISMATCH_C` | C2 | expr | `hh` | `shape mismatch: %s vs %s` | LANGUAGE.md §4.10, §6.3 (both extents constant) |
| 218 | `NO_TRANSPOSE` | C2 | dot | - | `vector has no transpose: use .row or .col` | LANGUAGE.md §5.6 |
| 219 | `RAGGED` | C2 | row | - | `ragged matrix literal` | LANGUAGE.md §6.9 |
| 220 | `USE_ROW_COL` | C2 | row | - | `use .row or .col` | LANGUAGE.md §6.9 |
| 221 | `RECURSIVE_STRUCT` | C2 | struct | - | `recursive struct` | LANGUAGE.md §4.6 |
| 222 | `RESERVED_FIELD` | C2 | fieldname | - | `field name reserved for views` | LANGUAGE.md §4.6 |
| 223 | `MISSING_RETURN` | C2 | fn | - | `missing return` | LANGUAGE.md §8.1 |
| 224 | `UNKNOWN_PARAM` | C2 | narg | - | `unknown parameter` | LANGUAGE.md §8.1 |
| 225 | `PARAM_TWICE` | C2 | narg | - | `parameter given twice` | LANGUAGE.md §8.1 |
| 226 | `MISSING_ARG` | C2 | call | - | `missing argument` | LANGUAGE.md §8.1 |
| 227 | `REF_TARGET` | C2 | ref | - | `ref argument must be a mutable variable, element or field` | LANGUAGE.md §8.3 |
| 228 | `ELEM_EFFECTS` | C2 | effect | - | `effects in elemental function` | LANGUAGE.md §8.5 |
| 229 | `UNKNOWN_STRUCT` | C2 | type | - | `unknown struct type` | LANGUAGE.md Appendix A |
| 230 | `MATMUL_VECTORS` | C2 | expr | - | `vector @ vector is not defined: use sum(a * b)` | defined here (LANGUAGE.md §6.2) |
| 231 | `INDEX_COUNT` | C2 | index | `ii` | `wrong number of indices: expected %d, found %d` | defined here (LANGUAGE.md §5.2: `A[k]` on a matrix) |
| 232 | `ELEM_RECURSIVE` | C2 | call | - | `elemental function cannot be recursive` | defined here (LANGUAGE.md §8.5) |
| 233 | `FORMAT_LITERAL` | C2 | expr | - | `format must be a string literal` | defined here (LANGUAGE.md §11.1) |
| 234 | `FORMAT_BAD` | C2 | str | `s` | `invalid format conversion "%s"` | defined here (LANGUAGE.md §11.1: other conversions, undefined flag combinations) |
| 235 | `REDEFINITION` | C2 | binding | `s` | `redefinition of '%s'` | defined here (two items, parameters or struct fields of one name, LANGUAGE.md §4.6, §8.1) |
| 236 | `DEFAULT_MISSING` | C2 | param | - | `parameter needs a default value` | defined here (LANGUAGE.md §8.1) |
| 237 | `NOT_CONSTANT` | C2 | expr | - | `not a constant expression` | defined here (LANGUAGE.md §4.5, §7.2, §8.1: `const`, fixed extents, defaults) |
| 238 | `ASSIGN_IMMUTABLE` | C2 | target | `s` | `cannot assign to immutable '%s'` | defined here (LANGUAGE.md §7.2, §7.5, §8.2: `let`, loop variables, parameters) |
| 239 | `BAD_TARGET` | C2 | target | - | `invalid assignment target` | defined here (LANGUAGE.md §4.7, §7.3: projections, constants, functions) |
| 240 | `BAD_OPERANDS` | C2 | expr | `sss` | `operator '%s' cannot be applied to %s and %s` | defined here (LANGUAGE.md §4.1, §4.6, §6.4, Appendix B) |
| 241 | `BAD_OPERAND` | C2 | expr | `ss` | `operator '%s' cannot be applied to %s` | defined here (LANGUAGE.md §6.4, Appendix B) |
| 242 | `TOO_MANY_ARGS` | C2 | call | - | `too many arguments` | defined here (LANGUAGE.md §8.1) |
| 243 | `NO_OVERLOAD` | C2 | call | `ss` | `no overload of '%s' accepts (%s)` | defined here (LANGUAGE.md §8.1, §10) |
| 244 | `NOT_FUNCTION` | C2 | call | `s` | `'%s' is not a function` | defined here |
| 245 | `MULTI_VALUE` | C2 | call | - | `multiple-result call used as a value` | defined here (LANGUAGE.md §8.4) |
| 246 | `RESULT_COUNT` | C2 | results | `ii` | `wrong number of results: expected %d, found %d` | defined here (LANGUAGE.md §7.3, §8.4) |
| 247 | `BREAK_OUTSIDE` | C2 | break | - | `break outside a loop` | defined here (LANGUAGE.md §7.5) |
| 248 | `CONTINUE_OUTSIDE` | C2 | continue | - | `continue outside a loop` | defined here (LANGUAGE.md §7.5) |
| 249 | `NO_FIELD` | C2 | dot | `ss` | `no field '%s' in %s` | defined here (LANGUAGE.md §4.6) |
| 250 | `NOT_INDEXABLE` | C2 | index | `s` | `%s cannot be indexed` | defined here (LANGUAGE.md §5.2) |
| 251 | `NOT_ITERABLE` | C2 | expr | `s` | `cannot iterate over %s` | defined here (LANGUAGE.md §7.5) |
| 252 | `CANNOT_INFER` | C2 | binding | - | `type cannot be inferred: add a type annotation` | defined here (LANGUAGE.md §4.10) |
| 253 | `ELEM_RESULT` | C2 | fn | - | `elemental function result must be f64, i64 or bool` | defined here (LANGUAGE.md §8.5) |
| 254 | `REF_NEEDED` | C2 | expr | `s` | `argument for ref parameter '%s' must be marked ref` | defined here (LANGUAGE.md §8.3) |
| 255 | `REF_UNEXPECTED` | C2 | ref | `s` | `'%s' is not a ref parameter` | defined here (LANGUAGE.md §8.3) |
| 256 | `PROJECTION` | C2 | dot | `ss` | `cannot project field '%s' of type %s` | defined here (LANGUAGE.md §4.7) |
| 257 | `VIEW_RANK` | C2 | dot | `ss` | `view .%s is not defined for %s` | defined here (LANGUAGE.md §5.6) |
| 258 | `ELEMENT_TYPE` | C2 | type | `s` | `arrays cannot hold %s` | defined here (LANGUAGE.md §4.1: handles) |
| 259 | `NOT_SUPPORTED` | C2 | construct | `s` | `not supported yet: %s` | defined here (the phase rule below and §8; retired once v1 is complete) |
| 260 | `INT_OVERFLOW_C` | C2 | expr | - | `integer overflow` | LANGUAGE.md §7.2 (a `const` whose evaluation overflows `i64`) |
| 261 | `INT_DIV_ZERO_C` | C2 | expr | - | `integer division by zero` | LANGUAGE.md §7.2 (a `const` whose evaluation divides an `i64` by zero) |
| 400 | `TOO_LARGE` | CX | here | `s` | `program too large: %s` | LANGUAGE.md §3.1; §2.7 |
| 500 | `TRUNCATED` | P | - | - | `internal error: truncated input` | §2.2 |
| 501 | `BAD_HEADER` | P | - | - | `internal error: bad header` | defined here (§3.2) |
| 502 | `BAD_RECORD` | P | - | - | `internal error: bad record` | defined here (§3.1: unknown opcode, wrong fields) |
| 503 | `BAD_TREE` | P | - | - | `internal error: bad tree` | defined here (§3.3: a pop from an empty stack, a non-empty stack at a section end) |
| 504 | `BAD_DATA` | P | - | - | `internal error: bad DATA table` | defined here (§2.2: a `DATA` table count disagrees with its sentinel) |

**The phase rule: `not supported yet`.** While Sea v1 is built phase by phase (§8), a program that
uses a construct the current compiler does not implement yet stops with the compile error `not
supported yet: %s` (code 259, `NOT_SUPPORTED`; driver status 1), reported by pass 2a (by `seaname` at
an item or in a signature, by `seacheck` elsewhere: "Which program reports it" below; pass 1
parses the whole grammar of LANGUAGE.md Appendix A from phase 1 on, so syntax errors are always
the real ones). It takes part in pass 2a's plain source order with every other pass-2 error: the
first error in source order is reported, whichever kind it is. Its position is the AST node that
the table's row names, and of several such nodes the first in source order: for a `str` local
its declaring `pname` (or `for` node), for a `str` parameter its `param` node, for a `str` result
the result's `type` node, for a default argument the `param` node, for a named argument the
`narg` node, for a library function the `call`, for a `for` over anything but a range the
`for` node, for `+` or a comparison on `str` operands the operator node. The format literal of
`printf` is not a `strings` construct, and neither is a string literal argument of `printf`: a
misplaced one is reported by the format checks (`format "%d" expects an integer or f64, found
str`). The `%s` is one of the words below. It is
not a rule of the language: LANGUAGE.md describes v1 complete, and a phase's compiler is a
conforming v1 compiler for the programs it accepts. When v1 is complete (phase 10) no construct is
reported any more; the message is retired and its code stays reserved, never reused. In phase 1
(the scalar core, §8) these constructs are reported, with these words:

| Construct (phase 1) | `%s` |
|---------------------|------|
| an array type, array literal, indexing, `$`, a range used as a value, a `for` over anything but a range, a view | `arrays` |
| a `struct` item, a struct type, a struct literal, a field access or projection | `structs` |
| a record literal or record type | `records` |
| a `match` statement | `match` |
| a `str` other than a string literal that is the argument of a `%s` conversion of `printf`: the `str` type, a `str` local, parameter or result, `+`, comparisons or `str(x)` on strings, a string literal anywhere else | `strings` |
| an `elemental fn` | `elemental functions` |
| a named argument | `named arguments` |
| a parameter default (reported at the `param` node) | `default arguments` |
| `%` with an `f64` operand (it needs the exact `fmod` of LANGUAGE.md §6.6) | `f64 %` |
| a handle type | `handle types` |
| a call of a library function other than `printf`, `now`, `f64`, `i64` and `idiv` (LANGUAGE.md §10–§13), and from phase 3 `log`, `exp`, `sin`, `cos`, `pow` and `hypot` (§4.10.5) | its name, e.g. `sqrt` |

Included in phase 1, so not reported: `const` items, the constants `pi inf nan eps`, `i64`, `f64`
and `bool` scalars, every scalar operator except those above, `if`/`while`/`for` over ranges,
`break`/`continue`, functions with scalar parameters and results, `ref` parameters of scalar
locals, multiple results, and `printf` with `%d %i %f %F %e %E %g %G %s`. Each later phase of §8
removes the rows it implements from this table, together with its tests. Because named
arguments, struct literals and fixed-size arrays are reported first, the errors 204–208,
216–222, 224 and 225 cannot occur in phase 1.

**Which program reports it** (phase 4a on, Decision 17: pass 2a is `seaname` and then
`seacheck`, §2.1, §3.4.1). `seaname` reports the errors of the declaration checks, which a
single pass-2a program finds before all others:

* of the items, in stream order: `redefinition of predeclared name` (212), `redefinition of
  '%s'` (235) of two items, and `not supported yet` (259) at an item (`elemental functions`,
  `structs`);
* then of the signatures of the entered functions (§3.4.1), in item order, each function's
  parameters in order and then its result types: `redefinition of '%s'` (235) of two parameters,
  `local name shadows a predeclared name` (213) at a parameter, `not supported yet` (259) for a
  parameter default (`default arguments`), for a `str` parameter or result type (`strings`) and
  for a type of a signature (`arrays`, `structs`, `handle types`), and `unknown struct type`
  (229) in a signature;
* the capacity limits (400) `symbols` (§3.4.1), `types` for the types it creates, and, while
  it reads `sea.ast`, `nodes`, `strings` and `constants` for the literals (§2.7).

`seacheck` reports every other pass-2a error: every code of 200–261 at every other place,
among them `undeclared name` (at an `rname none`), `local name shadows a predeclared name` at a
local or loop variable, `not a constant expression` (also at the name that closes a cycle), all
errors of `const` items (it checks every constant, §3.4.1; 260 and 261 from an `rcne` outcome),
those of the type annotations of `const` items and of `let`/`var`, `missing return`, the
`types` limit for the types it adds and the `constants` limit for the values of constants. The
limits `nesting`, `parameters`, `results` and `fields` are pass 1's alone (§2.7): neither
program of pass 2a reports them, and both size their stacks and records from them (a tree
nested at most `SEA_LIM_NESTING` deep, at most `SEA_LIM_PARAMS` parameters and
`SEA_LIM_RESULTS` results).

**Order across the two programs.** The rule is that of one program: the first error in source
order (file, line, column), of two at one position the first found, and a capacity error before
every other. `seaname` hands its first error to `seacheck` in the `rerr` record (§3.4.1), and
`seacheck` starts its search with that error as the first one found. Because `seaname`'s errors
are exactly those a single program finds first (items and signatures come before constants and
bodies), and an `rcne` outcome is reported by `seacheck` where a single program evaluated the
constant, the error reported is the one a single program reports. A capacity error of `seaname`
is reported by `seaname` at once (status 10), before `seacheck` runs; a capacity error of
`seacheck` wins over every other error, the `rerr` one included. The two differences from a
single program, both only for a compilation over two capacity limits at once: one that exceeds
a limit `seaname` enforces and the `types` limit in `seacheck` reports `seaname`'s, and one that
exceeds a limit `seaname` enforces and the `constants` limit through the values of constants
(counted by `seacheck`, §3.4.1) reports `seaname`'s, wherever the two lie. A later phase may move an error into
`seaname` only if a single program finds it before every error that stays in `seacheck` at the
same position (or no other error can occur at its position), so that this rule keeps holding.

**Within one formatting call** (`printf`, `format`, `error`) pass 2a first parses the format
literal (`format must be a string literal`, `invalid format conversion`), then compares the
number of arguments with the number of conversions (`format "%s" expects %d arguments, found
%d`), then checks each argument against its conversion in order (`format "%s" expects %s, found
%s`); an argument's own errors come before all three, in source order.

Uses of an existing message, so no further text is needed: `&&`/`||` with an array
operand, a `match` scrutinee that is not `str`, and a `return` value of the wrong type are `type
mismatch`; an out-of-range `bincount` value v (prelude code) is `INDEX_OOB` with v, dimension 0
and extent n, at the site of the program's call (§3.6.4, "Sites"); `sub2ind(r, i, j)` checks only
i against r (LANGUAGE.md §10.7) and reports `INDEX_OOB` with i, dimension 0 and extent r
(dimensions count from 0, LANGUAGE.md §5.4).

**The errno table** (LANGUAGE.md §9.2:
"a fixed table of errno texts so both targets print the same bytes"). A host errno value that is not in the table prints the text of id 0. Names
`SEA_ERRNO_<NAME>`, `SEA_ERRNO_COUNT` = 23.

| Id | Name | arm64-macos | x86_64-linux | Text |
|---:|------|------------:|-------------:|------|
| 0 | `UNKNOWN` | -1 | -1 | `unknown error` |
| 1 | `EPERM` | 1 | 1 | `Operation not permitted` |
| 2 | `ENOENT` | 2 | 2 | `No such file or directory` |
| 3 | `EIO` | 5 | 5 | `Input/output error` |
| 4 | `EACCES` | 13 | 13 | `Permission denied` |
| 5 | `EEXIST` | 17 | 17 | `File exists` |
| 6 | `ENOTDIR` | 20 | 20 | `Not a directory` |
| 7 | `EISDIR` | 21 | 21 | `Is a directory` |
| 8 | `EINVAL` | 22 | 22 | `Invalid argument` |
| 9 | `ENFILE` | 23 | 23 | `Too many open files in system` |
| 10 | `EMFILE` | 24 | 24 | `Too many open files` |
| 11 | `EFBIG` | 27 | 27 | `File too large` |
| 12 | `ENOSPC` | 28 | 28 | `No space left on device` |
| 13 | `EROFS` | 30 | 30 | `Read-only file system` |
| 14 | `EPIPE` | 32 | 32 | `Broken pipe` |
| 15 | `ENAMETOOLONG` | 63 | 36 | `File name too long` |
| 16 | `ELOOP` | 62 | 40 | `Too many levels of symbolic links` |
| 17 | `EDQUOT` | 69 | 122 | `Disk quota exceeded` |
| 18 | `EBADF` | 9 | 9 | `Bad file descriptor` |
| 19 | `ENXIO` | 6 | 6 | `Device not configured` |
| 20 | `ECONNRESET` | 54 | 104 | `Connection reset by peer` |
| 21 | `ENOTCONN` | 57 | 107 | `Socket is not connected` |
| 22 | `ETIMEDOUT` | 60 | 110 | `Operation timed out` |


**Exit statuses** (LANGUAGE.md §9.4; §2.2):

| Name | Value | Meaning |
|------|------:|---------|
| `SEA_EXIT_RUN_OK` | 0 | compiled program: normal end |
| `SEA_EXIT_RUN_ERROR` | 1 | compiled program: run-time error, including `error` and a failed write |
| `SEA_EXIT_PASS_OK` | 0 | pass: success, the output ends with `#end` |
| `SEA_EXIT_PASS_BAYSICK` | 1 | pass: a Baysick run-time error inside the pass |
| `SEA_EXIT_PASS_COMPILE` | 10 | pass: a Sea compile error (`STOP 10`) |
| `SEA_EXIT_PASS_INTERNAL` | 11 | pass: a phase `P` check failed (`STOP 11`) |
| `SEA_EXIT_OK` | 0 | driver: success |
| `SEA_EXIT_COMPILE` | 1 | driver: Sea compile error |
| `SEA_EXIT_USAGE` | 2 | driver: usage or file error |
| `SEA_EXIT_TOOLCHAIN` | 3 | driver: `as`/`ld`/`xcrun` missing or failing |
| `SEA_EXIT_INTERNAL` | 4 | driver: pass status 1 or 11, a missing `#end`, out of memory |

**Runtime tables.** `SEA_EMIT_ERRMSG_TABLE name` emits, in the current section (Mach-O
`__DATA,__const`, ELF `.data.rel.ro`), an 8-byte aligned table of `SEA_E_RT_END` records indexed
by run-time code (record 0 is zero) and then the strings; `SEA_EMIT_ERRNO_TABLE name, host`
(`host` `darwin` or `linux`) emits `SEA_ERRNO_COUNT` records indexed by id, holding that host's
errno values, and then the texts. Their labels other than `name` are `sea_errmsg_<code>`,
`sea_errargs_<code>` and `sea_errno_text_<id>`, so each macro is instantiated at most once per
object file (by each runtime's `_sea_err`).

| Name | Value | Meaning |
|------|------:|---------|
| `SEA_E_RT_END` | 22 | one past the last run-time code: records 0 … 21 |
| `SEA_ERRNO_COUNT` | 23 | number of errno records (ids 0 … 22) |
| `SEA_ERRTAB_MSG` | 0 | ptr: NUL-terminated message text |
| `SEA_ERRTAB_ARGS` | 8 | ptr: NUL-terminated `args` letters (empty for `-`) |
| `SEA_ERRTAB_SIZE` | 16 | record size; record k at table + 16·k |
| `SEA_ERRNO_HOST` | 0 | i64: host errno value (−1 in record 0) |
| `SEA_ERRNO_TEXT` | 8 | ptr: NUL-terminated text |
| `SEA_ERRNO_SIZE` | 16 | record size; record id at table + 16·id |

**Line shapes for the `DATA` generator.** Baysick programs read `errors.inc` with `LINPUT`, so its
records have fixed shapes (they are also valid assembler):

* an **error record** is a line between `.macro SEA_ERROR_LIST m` and the next `.endm` of the
  form: four spaces, `\m`, one space, then `code, NAME, phase, at, args, "text"`;
* an **errno record** is a line between `.macro SEA_ERRNO_LIST m` and the next `.endm` of the
  form: four spaces, `\m`, one space, then `id, NAME, darwin, linux, "text"`;
* an **exit status** is a line `.equiv SEA_EXIT_<NAME>, <decimal>`, optionally followed by spaces
  and a `/* … */` comment;
* fields are separated by a comma and one space; `code`, `id`, `darwin`, `linux` are decimal
  (with a leading `-` only for −1); inside `"text"`, `\"` stands for `"` and `\\` for `\`, and no
  other escape occurs; `code`, `id`, `darwin`, `linux` are canonical decimal numbers of at most 9
  digits (no leading zeros, no `+`); in an `.equiv` line the comma may be followed by one or more
  blanks. A line between a `SEA_*_LIST` macro and its `.endm` that is neither a record of the
  shape above nor a comment (`//`) is an error of the generator; every other line outside those
  lists is ignored.

**The generated `DATA` lines.** A Baysick string constant cannot contain `"` (Baysick
LANGUAGE.md §4.3), and texts 19, 20, 210, 211 and 234 do. So every string the generator writes into
a `DATA` statement is a quoted Baysick string holding the **`DATA` escaping** of its bytes: the
escaping of §3.1 in which `"` is written `%22` as well (so a `DATA` string holds only `%`-escapes
and bytes `0x21`–`0x7E` other than `%` and `"`; the empty string is `%`). A pass decodes it with
the decoding of §3.1, which reads `%22` as `"`. The generator writes one `DATA` line per record:

* error record: `<line> DATA <code>,"<NAME>","<phase>","<at>","<args>","<text>"`, e.g.
  `DATA 19,"LINE_STYLE","R","-","s","invalid%20line%20style%20%22%25s%22"`;
* errno record: `<line> DATA <id>,"<NAME>",<darwin>,<linux>,"<text>"`;
* exit status: `<line> DATA <value>,"<NAME>"`;

numbers in decimal, and each table followed by its sentinel (§2.2): the line `<line> DATA -1`,
read where the next record's first number would be.

#### 2.6.3 The `DATA` generator and how a pass is built

**Input line shapes of `limits.inc`, `rt.inc` and `passes.txt`** (those of `errors.inc` are in
§2.6.2; every other line is ignored by the generator):

* a **constant** is a line of `limits.inc` or `rt.inc` of the form `.equiv SEA_<NAME>, <value>`,
  optionally followed by spaces and a `/* … */` comment, where `<value>` is decimal (with a
  leading `-` for a negative value) or `0x` and upper-case hexadecimal digits; the include guards
  `SEA_*_INC` are not constants;
* an **entry record** is a line between `.macro SEA_ENTRY_LIST m` and the next `.endm` of
  `rt.inc`: four spaces, `\m`, one space, then `id, NAME, symbol, site, args, results` (§4.8);
* a **`passes.txt` line** is an `enum`, `head` or `rec` line of §3.9.

**The generator's protocol** (`tools/gendata.bas`). It runs with `include/` as working
directory and opens the contract files under their fixed names (Baysick `FILES`): 1
`limits.inc`, 2 `errors.inc`, 3 `rt.inc`, 4 `passes.txt`, 5 `math_tables.inc`. Its standard
input is the selection: one block name per line, each at most once, in the order `errors errno
exits consts entries records mtab`. It writes the `DATA` lines of the selected blocks to standard output, numbered
consecutively from 89 000 across the blocks, each table followed by its sentinel. `errors` and
`errno` are the lists of `errors.inc`, `exits` its `SEA_EXIT_*` constants (NAME = the text after
`SEA_EXIT_`), `consts` the constants of `limits.inc` and then those of `rt.inc` in one table (NAME
= the text after `SEA_`; the other constants of `errors.inc` are not emitted), `entries` the
entry list of `rt.inc`, `records` the lines of `passes.txt`, `mtab` the `pow` tables of
`math_tables.inc` (below). A malformed record, a line over 255
bytes, a bad selection or a missing file is reported on standard error as `gendata: <file>:<line>:
<message> (record <id>)` (or without the parts that do not apply), and the generator stops with
status 1.

**Generated `DATA` lines** (in addition to those of §2.6.2), one per record, numbers in decimal,
strings quoted in the `DATA` escaping of §2.6.2:

* constant: `<line> DATA "<NAME>",<l3>,<l2>,<l1>,<l0>`, the value's 64-bit two's-complement
  pattern as four 16-bit limbs, most significant first (each 0 … 65 535), so a value of more
  than 9 digits (`2147483647`), a hexadecimal one (`0x10FFFF`) or a negative one (`-1`) arrives
  exactly (§2.8); the table ends with the sentinel `<line> DATA "-"`;
* entry record: `<line> DATA <id>,"<NAME>","<symbol>","<site>","<args>","<results>"`, ending with
  `<line> DATA -1`;
* `passes.txt` line: `<line> DATA "<kind>",<n>,"<f1>",…,"<fn>"`, where kind is `enum`, `head` or
  `rec` and f1 … fn are the line's other fields in order (for `rec`: set, code, opcode, pops, then
  the field specifications); ending with `<line> DATA "end",0`;
* `mtab` (the words `FEPOW` needs, §4.10.5): first `<line> DATA 32,128,128` (the counts of the
  `sea_mt_const` words, `sea_mt_exp` records and `sea_mt_log` records), then the 672 words of
  `sea_mt_const` (32), `sea_mt_exp` (128 × 2) and `sea_mt_log` (128 × 3) in file order, each as
  its four 16-bit limbs `<l3>,<l2>,<l1>,<l0>` (most significant first, each 0 … 65 535), **eight
  words (32 numbers) per line**, so 84 lines (4, 32 and 48 per table: no line mixes two
  tables), then the sentinel `<line> DATA -1`: 86 lines, each at most 11 + 32·5 + 31 = 202
  bytes. The `sea_mt_trig` and `sea_mt_tpi` tables are not emitted (no constant expression
  needs them). Input line shapes of `math_tables.inc` (§4.10.3): a label line is exactly
  `sea_mt_<name>:` from column 1; a word line is four spaces, `.quad 0x` and 16 upper-case
  hexadecimal digits; every other line is ignored; a table with a word count other than
  §4.10.3's is reported like a malformed record.

Every generated line, line number included, is at most 255 bytes (Baysick's physical line
limit); the generator stops with status 1 and a message naming the record if one would be longer.

**How a pass is built.** Each pass program `build/gen/<pass>.bas` is the concatenation, in this
order, of: the pass's own files `passes/<pass>/*.bas` (in name order); the shared modules of
`passes/lib/` it uses, in the order `io diag tables limb f64emu fltlit`; the generated `DATA`
blocks it uses, among `errors`, `errno`, `exits`,
`consts`, `entries`, `records` and `mtab`, always in this order; and the line `99999 END`. The file
`passes/<pass>/build.list` names the modules and blocks: lines `lib <module>…` (among `io diag
tables limb f64emu fltlit`) and `data <block>…` (among `errors errno exits consts entries records
mtab`; only `seaname` lists `mtab`, §4.10.5), comment lines starting with `#`; the parts are
concatenated in the order above whatever the order of the list, and a name outside the two sets
is a build error. `tools/seaval.bas` is built the same way from `tools/seaval.build.list`. The
build regenerates `build/gen/` every time and compiles each result with `baysick`; nothing in
`build/` is committed. The modules' interfaces are internal to the compiler (not contract
files): `passes/lib/API.md` documents the `SUB`s of `io`, `diag` and `tables`, and
`passes/lib/API-arith.md` those of `limb`, `f64emu` and `fltlit` (each module's prerequisites
included); the `.bas` files carry one summary line per `SUB`.

**The build lists** (each `passes/<pass>/build.list`; the parts in the order above):

| Program | `lib` | `data` |
|---------|-------|--------|
| `seaparse` | `io diag tables limb fltlit` | `errors exits consts records` |
| `seaname` | `io diag tables limb f64emu` | `errors exits consts records mtab` |
| `seacheck` | `io diag tables` | `errors exits consts records` |
| `seaexpand` | `io diag tables limb f64emu` | `errors exits consts records` |
| `sealower`, `seaopt`, `seagen_a64`, `seagen_x64` | `io diag tables` | `errors exits consts entries records` |
| `tools/seaval.bas` (`tools/seaval.build.list`) | `io diag tables` | `errors consts records` |

So from phase 4a on the exact arithmetic of constants (`limb`, `f64emu`, `FEPOW` and `mtab`, §2.8,
§4.10.5) lives in `seaname`, and `seacheck` holds none: it takes every value it writes from its
input (literals as written, the `f64` bits of integer literals from `rint`, the values of
constants from the `rcn…` records, §3.4.1). The line numbers keep the parts apart:

| Part | Line numbers |
|------|--------------|
| the pass's own files | 1 – 59 999 |
| `passes/lib/io.bas`, `diag.bas`, `tables.bas` | 60 000 – 62 999, 63 000 – 65 999, 66 000 – 68 999 |
| `passes/lib/limb.bas`, `f64emu.bas`, `fltlit.bas` | 69 000 – 74 999, 75 000 – 81 999, 82 000 – 88 999 |
| generated `DATA`, numbered consecutively | 89 000 – 99 998 |
| `END` | 99 999 |

The pass's own files and the modules contain no `END`, and the modules contain no `DATA`; a pass
reads its own `DATA` (keyword tables and the like) before the generated blocks, which follow in
line order (Baysick reads `DATA` in line order). All parts together count against Baysick's
10 000 lines per program (§2.7; `make lines` reports each pass's count).

### 2.7 Living within Baysick's limits, and the size of the compiler

**Baysick facts that shape the compiler** (Baysick LANGUAGE.md):

| Baysick rule or limit | Consequence |
|-----------------------|-------------|
| 10 000 stored lines per program; one statement per line; `REM` lines count | the compiler is several programs (§2.1); comments are kept short and dense |
| `IF … THEN` only jumps to a line number | every conditional action costs a jump and a line; control flow is the main line cost (measured below) |
| scalar names are a letter plus at most one digit (286 per unit); 26 array letters per unit; no global variables | each pass keeps its state in a few 2-D tables, passed to every `SUB`; scalars are local to each `SUB` |
| at most 16 parameters per `SUB`/`CALL` | at most 8 tables per pass are passed everywhere (below), leaving 8 parameters for scalars; related arrays are packed into one 2-D table |
| arrays: ≤ 10⁶ elements, bounds inclusive (`DIM N(99999,8)` is 100 000 × 9 = 900 000 elements), `DIM` bounds constant | the capacity limits below |
| numeric constants: at most 9 mantissa digits (`2147483647` is `ILLEGAL CONSTANT`) | larger constants are built by arithmetic (`214748364 * 10 + 7`) or carried as hex limbs |
| string constants outside `DATA`: ≤ 65 536 bytes in the whole program (`TOO MANY LABELS`) | error texts, instruction templates and keyword tables are `DATA` strings (which do not count); string constants are kept to short delimiters |
| string `=` ignores trailing blanks, and `SEG$` past the end returns `""`, which then equals `" "` | the passes never compare a possibly blank-terminated string with `=`: they compare lengths first, or work on character codes from `CHANGE` (as the calibration lexer does) |
| `OUT OF DATA` and the end of input on a plain `INPUT`/`LINPUT` end the program with status 0 | the end-of-input discipline of §2.2 |
| `FILES`: ≤ 8 names, fixed at compile time | each pass uses ≤ 2: its input file (pass 1 reads standard input as file 0) and its output |
| 1024 active `CALL`s, 2 097 152 words of activations | recursion only in the parser, bounded by the nesting limit 64; later passes iterate over post-order records |
| 1000 `FOR` statements per program | counted in each pass by a build check; a pass near it is split |

**Table layout and the capacity limits derived from it.** The largest pass (2a) needs these
tables (from phase 4a both its programs, `seaname` and `seacheck`, keep this layout and read the
same tree into `N`, §3.4.1); every other pass uses a subset of the same layout:

| Table | `DIM` | Elements | Rows | Fields |
|-------|-------|---------:|-----:|--------|
| `N` nodes | `N(99999,8)` | 900 000 | 99 999 | kind, operator, first child, next sibling, type, file and line (F·10⁹ + L), column, symbol, flags |
| `Y` symbols | `Y(49999,9)` | 500 000 | 49 999 | name string, kind, type, scope, declaring node, flags, offset, … |
| `T` types | `T(19999,7)` | 160 000 | 19 999 | kind, element type, rank, extent 1, extent 2, struct id, field list, flags |
| `W` work stack | `W(199999)` | 200 000 | — | scope stack, worklists |
| `C` constants | `C(19999,4)` | 100 000 | 19 999 | four 16-bit limbs of an `f64`/`i64` bit pattern |
| `S$` strings | `S$(199999)` | 200 000 | 199 999 | identifiers, string literals, file names (interned) |

Six tables, passed to every `SUB` (6 of 16 parameters). Hence the **capacity limits**
(compile errors `program too large: %s`): at most 99 999 AST nodes, 49 999 symbols, 19 999
types (types, not rows of `T`: the continuation rows of a tuple or struct type do not count),
19 999 distinct numeric constant values (a literal counts once per kind as written, `ci` or `cf`,
and value, however often it occurs; each `const` item's value is one value) and 199 999 distinct
strings per compilation (prelude included); every pass compares with the `SEA_LIM_*` values it
reads from the generated consts table (§2.6.3), never with a written number;
nesting depth ≤ 64, ≤ 64 parameters and ≤ 64 results per function, ≤ 64 fields per struct.
Pass 1 enforces the nesting, parameter, result and field limits as it parses (and the node and
string limits as it builds the tree; the `prog` root is not counted as a node, and the `#file`
paths count as strings); pass 2a the symbol, type and constant limits (`seaname` the symbol limit,
the constant limit for literals and the types it creates, `seacheck` the types it adds and the
constant limit for the values of constants, §2.6.2); passes 3a,
3b and 4 the LIR limits. **Nesting depth** counts the constructs that make pass 1 recurse: a
block `{ … }` (of any statement or function), a parenthesized expression, the argument list of a
call, an index list, an array literal, a struct or record literal, an `if` expression, a unary
operator and the right operand of `^`; the top level is depth 0, and each such construct
contained in another adds 1. The `{ … }` of a `match` (its arm list) does not count (the arms'
blocks do); a parenthesized expression counts also after `return`; a conversion `f64(x)` counts
once (its parentheses are its argument list); the `if` after `else` in an `if` statement adds
nothing (its blocks are at the depth of the first `if`'s), while in an `if` expression it is a
nested `if` expression and adds 1. A construct at depth 65 is `program too large: nesting`, reported
at its opening token (`{`, `(`, `[`, `if`, the unary operator, or the `^`). For the LIR limits,
the operand fields of an instruction are all its fields after the opcode except its `site`
(§3.6.4), also when the site is `-` (an `rcall` of an entry that cannot fail); the fields of `func`, `slot` and data records are not operands. The distinct sites are
the distinct `F:L` among the instructions' `site` fields and the `pos` of every `func` record
(§4.9), counted over the compilation. No record of any format has more than 300 fields (the
longest are `func` and `call` with 64 parameters, hidden result addresses and 64 results), and
passes 3a and 4 split a LIR record into at most 300 fields (a longer one is `BAD_RECORD`).
(A node's position needs its file, §3.1: the sixth field of `N` holds the file index and the line
as F·10⁹ + L, exact in a Baysick number.)

**Tables of the LIR passes.** Pass 3a keeps the HIR of the whole program in the
six tables above and, in two more, the current function's LIR and the data items it collects
(it writes each function when the function is lowered, because its `slot` records come first,
and the data records at the end of the file, §3.6). Passes 3b and 4 hold one LIR function at a
time, plus the per-compilation tables:

| Table | `DIM` | Elements | Rows | Fields | Pass |
|-------|-------|---------:|-----:|--------|------|
| `L$` LIR records | `L$(199999)` | 200 000 | 199 999 | one record of the current function, as text | 3a |
| `D` data items | `D(49999,3)` | 200 000 | 49 999 | kind, source HIR node, count | 3a |
| `I` instructions | `I(199999,4)` | 1 000 000 | 199 999 | opcode, first operand in `O`, operand count, site in `X` | 3b, 4 |
| `O` operands | `O(799999)` | 800 000 | — | the operand fields: register, immediate in `C`, label, slot, block or string number | 3b, 4 |
| `R` registers | `R(99999,7)` | 800 000 | 99 999 | class, first definition, last use, interval start, interval end, machine register, spill slot | 3b, 4 |
| `K` blocks and slots | `K(19999,4)` | 100 000 | 19 999 | rows 1–9 999 blocks: kind, opening, `else`, closing instruction; rows 10 000–19 999 slots: size, alignment, frame offset | 3b, 4 |
| `C` immediates | `C(199999,4)` | 1 000 000 | 199 999 | four 16-bit limbs of an `li`/`lf` value | 3b, 4 |
| `X` sites | `X(49999,1)` | 100 000 | 49 999 | file index, line (`_sea_sites`, §4.8) | 4 |
| `S$` strings | `S$(199999)` | 200 000 | 199 999 | names, entry points, file paths (interned) | 3a, 3b, 4 |

Pass 3a passes 8 tables (`N Y T W C S$`, with the `C` of §2.7 above, and `L$`, `D`), pass 3b 6
(`I O R K C S$`) and pass 4 7 (`I O R K X C S$`) to every `SUB`, leaving at least 8 parameters for
scalars. Hence the
limits `SEA_LIM_LIR_*` of §2.6.1: per function 199 999 instructions (or buffered records),
799 999 operand fields, 99 999 registers, 9 999 blocks, 9 999 slots and 199 999 immediates; per
compilation 49 999 data labels and 49 999 distinct sites. Pass 4 copies the data records from its
input to `sea.s` as it reads them, so it stores none of their elements. At an estimated
6–10 nodes per source line, about 10 000–16 000 source lines fit. The workloads are 300–440 lines
of MATLAB each and the prelude an estimated 100–200 lines.

**Size calibration (item measured, not guessed).** Two representative pieces were written in
Baysick and run (scratch programs, not part of the repository):

* **Lexer core** (`lex.bas`, 188 lines, 12 of them `REM`): reads the `|`-tagged stream with
  `IF END #0`/`LINPUT #0`, works on `CHANGE` codes, recognises identifiers, keywords (table in
  `DATA`), integer and float literals with `_` and exponents, strings with five escapes, all
  operators with longest match, `//` comments, and the newline rules 1 and 2 of LANGUAGE.md §3.7; writes one
  token per line; reports errors with `PRINT #-1` and `STOP 10`. It lexed the 442 lines of Sea in
  the agreed design's examples (now LANGUAGE.md; 4 304 tokens), and the same repeated 20 times (8 840 lines, 86 000
  tokens) in 0.02 s on the
  development Mac. Missing for a complete LANGUAGE.md §3 lexer: block comments, hex literals, `\x`/`\u`/`\r`
  escapes, literal validity rules, column numbers, rule 3 (`else`), token records with
  positions. Judged to be about 60 % of the lexer.
* **Expression parser** (`expr.bas`, 145 lines): precedence climbing over the 8 binary levels
  of LANGUAGE.md §6.1 with non-associative comparisons, unary `-`/`!`, right-associative `^` with a signed
  right operand, parentheses, calls, indexing with argument counts, field access, error
  messages; recursive `SUB`s sharing 4 arrays and a cursor; writes postfix. Missing: ranges,
  `:` and `$`, named and `ref` arguments, array/struct/record literals, `if` expressions, AST
  records with positions. Judged to be about 25 % of the expression parser.

From these: the full lexer ≈ 300–350 lines, the expression parser ≈ 550–700, statements, items,
types and patterns ≈ 700–1 000, the header protocol, error handling and record output ≈ 200–300;
**pass 1 ≈ 1 800–2 400 lines**. The measured density is about 1.5–2 Baysick lines for each line
an equivalent C implementation would have (jump-only `IF`, one statement per line), which is the
factor applied to the later passes, sized by the rules they implement (LANGUAGE.md and this document):

| Pass | Estimate (Baysick lines) | Basis |
|------|-------------------------:|-------|
| 1 `seaparse` | 1 800–2 400 | measured pieces above |
| 2a `seacheck` | 6 000–9 000 | LANGUAGE.md §4–§9 and LANGUAGE.md §11.1 rules: scopes, types, ranks, conversions, overloads of ~80 library functions, format checking |
| 2b `seaexpand` | 2 500–4 000 | elemental instantiation, `write_json` expansion, folding with exact arithmetic (§2.8), reachability |
| 3a `sealower` | 5 000–8 000 | inlining, fusion, views, checks, COW, temporaries |
| 3b `seaopt` | 3 000–5 000 | the §5.2 optimizations, scalar replacement, vectorization |
| 4 `seagen_a64`, `seagen_x64` | 4 000–7 000 each | instruction selection (templates in `DATA`), linear-scan allocation, frames, error-site tables |
| **total** | **≈ 26 000–42 000** | eight programs (original estimate of phase 0; recalibrated below) |

The uncertainty was large (±50 % on the later passes); the estimate above is the original one of
phase 0, kept for comparison, and is recalibrated below from the real phase-1 passes (§8).
Runtime assembly per target, by analogy with
Baysick's runtimes (9 000 and 11 000 lines): core runtime 8 000–12 000 lines, plotting and JSON
2 500–4 000, Sea's own kernels (GEMV, LU/Cholesky panels, triangular solves, eigenvalues, sort,
elementary functions in scalar and vector forms) 6 000–10 000 — all estimates.

**Recalibration from the phase-1 passes (measured with phase 1 complete, on the tree of the
round-3 fixes that follow sea commit 3f07e31).** `make lines
check-limits` counts the stored lines of each built program `build/gen/<pass>.bas` (§2.6.3: the
pass's own files, the shared modules of its `build.list`, the generated `DATA`, and `99999
END`); the split comes from the line-number ranges of §2.6.3. FORs and string bytes are the
counts Baysick's limits apply to (§2.7 table above).

| Pass | Own | Lib modules | `DATA` | Total | FORs | String bytes | Original estimate (whole v1 pass) |
|------|----:|------------:|-------:|------:|-----:|-------------:|-----------------------------------|
| 1 `seaparse` | 1 528 | 1 845 (io diag tables limb fltlit) | 501 | 3 875 | 74 | 2 511 | 1 800–2 400 |
| 2a `seacheck` | 2 778 | 2 123 (io diag tables limb f64emu) | 501 | 5 403 | 127 | 4 276 | 6 000–9 000 |
| 2b `seaexpand` | 852 | 2 123 (io diag tables limb f64emu) | 501 | 3 477 | 90 | 3 512 | 2 500–4 000 |
| 3a `sealower` | 1 649 | 892 (io diag tables) | 504 | 3 046 | 67 | 2 351 | 5 000–8 000 |
| 3b `seaopt` | 952 | 892 (io diag tables) | 504 | 2 349 | 55 | 4 172 | 3 000–5 000 |
| 4 `seagen_a64` | 1 935 | 892 (io diag tables) | 504 | 3 332 | 88 | 3 104 | 4 000–7 000 |

(Totals include the `END` line. Limits: 10 000 lines, 1000 `FOR`s, 65 536 string bytes.)

**How far off the original estimate was.** Pass 1 parses the whole grammar from phase 1 on
(§2.6.2), so it is the one pass that can be compared whole: its own code (1 528 lines) is 15 %
below the low end of the estimate, so the density factor of 1.5–2 Baysick lines per C line held
for the code itself. The estimate missed the shared part: the modules and the generated `DATA`
that every pass carries add 1 396 (passes 3a, 3b, 4) to 2 624 (passes 2a, 2b) lines to each
pass, so pass 1's total is 1.6–2.2 times its estimate. The other passes are incomplete in
phase 1, so their totals are compared with the estimate only through the re-estimate below.

**Re-estimate for v1** (an estimate, not a measurement). Method: each pass's v1 size is its
measured phase-1 size plus, for each later phase of §8, an increment for the features that phase
adds to that pass, sized by comparing the work it adds with the measured phase-1 own lines of
the same pass and the share of that pass's v1 features phase 1 already covers (pass 1 nearly all;
passes 2a, 4 about a third; pass 3a about a quarter; pass 2b and 3b mostly their input
validation); the modules and `DATA` stay as measured, except `DATA` growing to about 600–700 lines
in the passes that load the runtime entries (3a, 3b, 4) as phases add entries. Own-line
increments per phase:

| Pass | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | v1 total (with modules and `DATA`) |
|------|--:|--:|--:|--:|--:|--:|--:|--:|------------------------------------|
| 1 `seaparse` | — | — | 0–100 | — | 0–100 | — | — | 0–100 | 3 900–4 200 |
| 2a `seacheck` | — | 100–300 | 2 500–3 500 | — | 800–1 200 | — | 150–250 | 300–600 | **9 300–11 300** |
| 2b `seaexpand` | — | — | 200–400 | — | 700–1 200 | — | — | — | 4 400–5 100 |
| 3a `sealower` | — | 100–200 | 2 500–3 500 | — | 1 000–1 500 | 800–1 500 | 200–400 | 200–300 | **7 900–10 600** |
| 3b `seaopt` | — | — | 200–300 | 1 500–2 500 | — | 1 000–2 000 | — | — | 5 200–7 300 |
| 4 `seagen_a64` | — | 50–100 | 800–1 200 | 600–1 000 | — | 600–1 000 | 100–200 | — | 5 600–7 000 |
| 4 `seagen_x64` | 1 900–2 300 (new pass, as `seagen_a64` in phase 1) | 50–100 | 800–1 200 | 600–1 000 | — | 600–1 000 | 100–200 | — | 5 600–7 400 |
| **all passes** | | | | | | | | | **≈ 42 000–53 000** |

The increments are judged, not measured: ±30 % on each, which the ranges carry. FORs grow with
the code at the phase-1 ratio (one per 25–45 lines), so no pass approaches 1000; string bytes
stay small because text lives in `DATA`.

**Passes at risk of the 10 000-line limit.** Pass 2a: about 8 000–9 200 lines after phase 4 and
8 800–10 400 after phase 6, so it is the first pass likely to reach the limit, in phase 6 (and
above 9 000 already after phase 4 at the high end). Pass 3a: about 5 700–6 900 after phase 4, 6 700–8 400 after
phase 6 and 7 500–9 900 after phase 7, reaching the limit only at the high end, in phases 8–9. No
other pass comes near it. **Phase 3 adds to pass 2a** (Decision 16 (a), §4.10.5): `FEPOW` and its
cores in `f64emu.bas`, an estimated 400–600 lines (counted in pass 2b too, which loads `f64emu`
but never calls `FEPOW`; 2b stays far below the limit), and the 86 `mtab` `DATA` lines, so pass
2a's v1 estimate becomes about 9 800–12 000 lines and the split described next is expected
during phase 4 rather than phase 6. The
response is the one §7.3 orders first and Decision 2 in §9 pre-agrees: **split the pass into two
programs with an intermediate file** (pass 2a, for example, into name resolution and typing of
statements and expressions, then the library-call and format checks; pass 3a into the lowering of
statements and calls, then fusion and inlining), done when `make check-limits` first reports a
pass above 9 000 lines, so that the split is made before a phase's work is blocked; Baysick is
grown only if a pass cannot be split cleanly (§7.3, step 2).

**The split of pass 2a (phase 4a, Decision 17).** Phase 4 adds an estimated 3 000–4 300 own lines
to pass 2a (struct and record items and literals, array types and their extents, indexing and
`$`, array literals, broadcasting, views and projections, `ref` paths, `dyn`/`fix`, `str`,
`match`, about 40 library overloads with their options, and their emission), which would take the
one program from about 5 900 lines to 8 900–10 200, across the 9 000-line trigger. So phase 4
starts by splitting it (sub-phase 4a, before any phase-4 code goes in): `seaname` (`sea.ast` →
`sea.res`) resolves names and scopes, checks items and signatures and owns the exact arithmetic
(constant values, constant exponents, the `f64` bits of integer literals, `limb`, `f64emu`,
`FEPOW` and `mtab`); `seacheck` (`sea.res` → `sea.hir1`) keeps typing, every other check and the
emission, and no arithmetic module (§2.6.3, §3.4.1). Estimates (judged from the phase-1 files;
±30 % on own lines; modules and `DATA` as built):

| Program | Own lines | Modules | `DATA` | After 4a | After phase 4 | v1 |
|---------|----------:|--------:|-------:|---------:|--------------:|---:|
| `seaname` | 1 850–2 200 (reading, items and signatures, scopes and the resolution walk, the constant order, the typing of constant expressions on their well-typed path, the evaluator moved from `seacheck`, writing `sea.res`) | 2 452 (io diag tables limb f64emu) | about 600 (with `mtab`) | **4 900–5 250** | 5 700–6 200 (struct declarations, extents of type nodes, literal field sets, syntactic checks of paths: 750–900) | 5 900–6 600 |
| `seacheck` | 2 300–2 600 (the phase-1 code without items, signatures, scopes and the evaluator; reading `sea.res`, the constant outcomes) | 892 (io diag tables) | about 515 | **3 700–4 000** | 5 950–7 400 (the typing side of phase 4: 2 250–3 400) | 7 000–9 250 (phases 6, 8 and 9: 1 050–1 850) |

Both stay below 9 000 after phase 4 with a margin of at least 1 600 lines; `seacheck` reaches
the trigger at v1 only at the high end of every range, so the measurement after phase 4 (§8,
phase 4h) decides whether its library-overload checks move to a third program then. 4a is done
when `make check-limits` reports the two programs and their measured sizes replace these
estimates here.

**`sealower` in phase 4, and its seam.** Phase 4 adds an estimated 3 000–4 500 own lines to pass 3a
(allocation and addressing, five index kinds read and written, `$`, bounds checks, element-wise
loops with broadcasting, reductions, literals, fixed arrays, structs and hidden results,
projections, reference counts on every exit, copy on write, strings, `match`, `error`, `args`,
`fore`, and the inlining of prelude calls, Decision 18), more than the 2 500–3 500 above, which
counted neither the prelude inlining nor reference counts on every exit: about 6 100–7 600 lines
after phase 4, below the trigger, and 7 900–10 600 after phases 6 and 7. It is not split in
phase 4. Sub-phase 4a cuts its one file `sealower.bas` into files by area without changing any
line or line number (§2.6.3 builds a pass from its files in name order, so the files are named in
line order): `sl0main.bas`, its lines 100–3125 (the header, the tables, reading `sea.hir`, writing functions
and data, the frame machine), and `sl1scal.bas`, its lines 3130–8745 (the nodes and their
rules, §3.6.6); the files later phases add take line ranges after 8745 (or free ranges between,
keeping name order equal to line order). When it reaches
9 000 (expected in phase 7, possibly 6) the planned seam is a pass **`sealoop`** (`sea.hir` →
`sea.hir`: every array expression made explicit as scalar loops over element accesses, its
checks, temporaries and reference-count and copy-on-write points as new HIR statements, and the
fusion grouping of phase 7) before **`sealower`** (that HIR → LIR: the scalar rules plus the
explicit points); it needs new HIR records, so it is specified with the phase that needs it.

### 2.8 Numbers inside the compiler

The passes run as Baysick programs, whose numbers are doubles, which cannot represent ∞ or NaN,
and whose arithmetic stops the program with `OVERFLOW` or `DIVISION BY ZERO` before any check of
the result could run (Baysick LANGUAGE.md §5.4); `SQR` takes `sqrt(|x|)`. Therefore:

* **Float literals** (LANGUAGE.md §3.4) are converted to their exact IEEE bit pattern by pass 1 with exact
  big-integer arithmetic (decimal digits × 10^e as a big integer or rational in arrays of 16-bit
  limbs, then rounding to 53 bits, ties to even), and carried as hex in every later file. The
  assembler only ever sees `.quad 0x…` patterns. Test vectors for the converter come from the
  IEEE definition (hard-rounding cases included), §6.2.
* **Constant folding** (pass 2b, §3.5.7) and the evaluation of constants and constant exponents
  (pass 2a, §3.5.5) compute every `f64` operation with the exact IEEE emulation of
  `passes/lib/f64emu.bas` (`FEADD`, `FESUB`, `FEMUL`, `FEDIV`, `FESQR` on bit patterns held in
  16-bit limbs), never with Baysick's doubles. The emulation is integer arithmetic on limbs, so it
  cannot overflow or divide by zero in Baysick, and it gives the IEEE binary64 result
  (round to nearest, ties to even) for every operand, finite or not: overflow to ±∞, underflow
  to subnormals or ±0, `x ÷ 0` → ±∞ (or NaN for `0 ÷ 0`), every operation on ±∞ or NaN, −0 kept
  (`-0.0 * 1.0` folds to −0.0, `sqrt(-0.0)` to −0.0, as at run time). So no operation is
  guarded: a foldable operation (§3.5.7) folds whatever its operands' values, and every `f64`
  constant expression built from foldable operations folds to one `cf` (constant substitution
  therefore never makes the tree larger than one literal per constant use). No guard is needed
  for exactness either: the emulation is exact by construction, and the only rounding is the
  one IEEE prescribes. (Until phase 1's review the folding was guarded by exponent checks
  because Baysick's doubles could not hold the results; with the emulation those checks are
  gone.) Folding folds only subtrees that are constant on their own (`2 * pi * rpm / 60` folds
  `2 * pi` only, LANGUAGE.md §6.8).
* **NaN bits.** A folded NaN has the bits arm64 produces for the same operation (FPCR.DN = 0,
  the macOS default): if an operand is a NaN, the result is that operand with its quiet bit
  (bit 51) set, the first NaN operand in operand order (a, then b) when both are; otherwise (an
  invalid operation: ∞ − ∞, 0 × ∞, 0 ÷ 0, ∞ ÷ ∞, `sqrt` of a negative number) the default NaN
  `#7FF8000000000000`. Sea's `nan` is `#7FF8000000000000` (§3.5.5), and unary `-` flips the sign
  bit exactly, so the NaNs that occur in folding are `#7FF8000000000000` and
  `#FFF8000000000000`, and every compile-time NaN is quiet. x86_64 (SSE2/AVX2) produces the
  default NaN `#FFF8000000000000` for an invalid operation (and propagates the first NaN
  operand), so run-time NaN bits can differ between the targets and from the folded ones. This is
  never visible: a NaN prints as `NaN`, never signed (LANGUAGE.md §11.1), `write_json` writes
  `null`, comparisons and `isnan` ignore sign and payload, and no Sea operation exposes a value's
  bits (LANGUAGE.md §6.5).
* **`i64` arithmetic** beyond 2⁵³ (literals, overflow checks of folded constants, the magic
  numbers for division by a constant) uses multi-limb integer routines in the pass that needs it.
* **Constant exponents and extents** (pass 2a, §3.5.5) are evaluated with the same emulation
  (and exact `i64`), never with Baysick's floating-point operations; pass 2a writes no folded
  value, only the decision `powk k` (or the extent of a type). A NaN or ∞ exponent is not
  integral, so it is no `powk`.

### 2.9 Self-hosting is not a goal

The Sea compiler stays a Baysick program. Sea is a numerical language: it has no recursive data
structures, no maps, no pointer types — the things a compiler is made of — and adding them for
the compiler's sake would work against the language's purpose. Writing the compiler in Baysick
is also the point of the Baysick project.

### 2.10 Repository layout

| Path | Contents |
|------|----------|
| `driver/sea` | the driver (§2.2), a POSIX `sh` script |
| `passes/lib/io.bas`, `diag.bas`, `tables.bas` | shared pass modules: the header protocol and record reading and writing (§2.2, §3.1–§3.3), diagnostics (§2.6.2), the tables of §2.7 |
| `passes/lib/limb.bas`, `f64emu.bas`, `fltlit.bas` | multi-limb integers, the exact IEEE binary64 emulation and the float-literal conversion (§2.8) |
| `passes/lib/API.md`, `API-arith.md` | the interfaces of the shared modules (§2.6.3): `io`, `diag`, `tables`; `limb`, `f64emu`, `fltlit` |
| `passes/seaparse/`, `seaname/`, `seacheck/`, `seaexpand/`, `sealower/`, `seaopt/`, `seagen_a64/`, `seagen_x64/` | each pass's own Baysick files (§2.1; `seaname/` from phase 4a), built as §2.6.3 says |
| `tools/gendata.bas` | the `DATA` generator (§2.6.3) |
| `tools/seaval.bas`, `tools/seaval.build.list` | a validator of intermediate files, used by the tests: its standard input names the format (`ast`, `res`, `hir1`, `hir`, `lir1`, `lir`; a file of format `ast` may hold only the records of §3.4's table, one of format `res` also those of §3.4.1); the header, every record's fields against `passes.txt`, the pops and the tree stack (the non-node records are those §3.3 lists), and LIR register numbering and classes; it does not check the first-reference order of types, the ranges of `fid`/`cid`/`iid` references or `rcall` entry names |
| `passes/<pass>/build.list` | the modules and `DATA` blocks of each pass (§2.6.3) |
| `tools/passlines.sh` | the line count of each built pass against Baysick's limits (`make lines`) |
| `tools/math_tables.py` | the generator of `include/math_tables.inc` (§4.10.3, §4.10.6), run with `uv run --with mpmath`; `--check` verifies the committed file |
| `std/std.sea` | the prelude (§2.5) |
| `runtime/arm64_macos/`, `runtime/x86_64_linux/` | the runtimes (§4, §4.7.1); in phases 1 and 2 `rt_main.s`, `rt_out.s`, `rt_err.s`, `rt_fmt.s`, `rt_clock.s`; phase 3 adds `rt_math.s` (§4.10) |
| `Makefile.linux` | on the Linux host: `check-includes`, `all` (`build-x86_64-linux/libsea.a`), `test-rt` (§4.7.1, §6.6.1), `test-math` (`all`, then `tests/math/math_check.c` built with `gcc -O1 -ffp-contract=off` against `build-x86_64-linux/libsea.a` and run on `tests/math`, §4.10.6) |
| `include/` | the contract files (§2.6) |
| `tests/` | the tests (§6.2) |
| `build/` | the build output and installation directory: the pass executables, `sea`, `std.sea`, `errors.inc`, `limits.inc`, `libsea.a` and `libbaysickrt.a` (one of each, for the build's target), and the generated `build/gen/`; never committed |

`make` builds `build/`; `make test` runs the tests of §6.2; `make test-rt`, `make test-stage`,
`make test-math` and `make check-data` run single groups of them (§6.2); `make test-math` builds
`tests/math/math_check.c` with `xcrun cc -O1 -ffp-contract=off` against `build/libsea.a` and
compares all six elementary functions bit for bit over `tests/math/*.vec` (§4.10.6);
`make math-tables` is a developer check that is not part of `make test`: `timeout 120 uv run
--with mpmath python tools/math_tables.py --check`, which verifies the committed
`include/math_tables.inc` against its definitions (§4.10.6); `make lines` reports each built pass's
line count against Baysick's 10 000 lines, and `make check-limits` checks each built pass against
Baysick's other per-program limits of §2.7 (1000 `FOR` statements, 65 536 bytes of string
constants outside `DATA`, 255-byte lines); `make check-includes` and `make check-contracts`
check the contract files (§2.6).

## 3. Intermediate files

The passes of §2.1 communicate through six text files in the temporary directory. This section
fixes their exact formats; `sea/include/passes.txt` (§3.9) is the same information in a form the
passes' generated `DATA` blocks are made from (§2.6), and the two change only together.

| File | Written by | Read by | Content |
|------|-----------|---------|---------|
| `sea.ast` | 1 `seaparse` | 2a `seaname` | the syntax tree as parsed, untyped (§3.4) |
| `sea.res` | 2a `seaname` | 2a `seacheck` | the same tree with names resolved, declarations checked and constants evaluated (§3.4.1) |
| `sea.hir1` | 2a `seacheck` | 2b | the resolved, typed tree (§3.5) |
| `sea.hir` | 2b `seaexpand` | 3a | the same after constant substitution and folding, elemental instantiation, `write_json` expansion and reachability (§3.5) |
| `sea.lir1` | 3a `sealower` | 3b | loop-level code over virtual registers (§3.6) |
| `sea.lir` | 3b `seaopt` | 4 | the same after the §5.2–§5.3 optimizations and vectorization (§3.6) |

The pass-1 input stream (§2.2) uses the header records of §3.2; pass 4 writes `sea.s`, which is
assembly text and has no records. `sea build --emit X` copies `sea.X` unchanged (§2.2), so a
dump is the file itself; §3.8 says how dumps are tested.

### 3.1 Lines, fields and field encodings

* A file is a sequence of **records**, one per line, each line ended by LF. Every byte of a file
  is LF or in `0x20`–`0x7E`: strings are escaped (below), so no other byte occurs.
* A record is a sequence of **fields** separated by exactly one space, with no leading or
  trailing space and no empty field. The first field is the record's **opcode** (lower-case
  letters and digits, or `#` + a name for a header record, §3.2); the fields after it are fixed
  by the opcode, in the order of the tables below and of `passes.txt`.
* A line is at most 65 536 bytes (`SEA_LIM_RECORD_BYTES`), Baysick's input-line limit
  (Baysick LANGUAGE.md §12, §15.2), so every record is read with one `LINPUT #k`. Every record
  stays far below it:
  * a record holds at most one string field, and a string field is at most 12 288 bytes: a
    string literal lies on one source line of at most 4096 bytes (LANGUAGE.md §3.1, §3.5), its
    value has at most as many bytes as its source text, and escaping writes each byte as at most
    3 bytes; a `#file` path is at most 4096 bytes (the operating systems' path limit); names and
    keys are identifiers of at most 63 bytes. No record carries a variable number of strings
    (the patterns of an `arm` are child `str`/`cs` nodes, §3.4, §3.5.5), except `rerr` of
    `sea.res` (§3.4.1): at most three substitutions of one error, each at most 4 096 bytes;
  * the records with a variable number of fields (`rtup`, `rfn`, `ttuple`, `inst`, `tbind`,
    `func`, `call`, `rcall`, `ret`, `chk`) repeat numbers or registers, each at most 7 bytes with its separator,
    and their counts are bounded by the limits of §2.6.1: at most `SEA_LIM_PARAMS` parameters
    and `SEA_LIM_RESULTS` results per function, plus one hidden address per result (§3.6.3),
    and the fixed arities of the runtime entry points and error codes (§4.8, §2.6.2); so such a
    record has fewer than 200 fields and 1 400 bytes.
* The last record of every file is `#end` (§2.2, end-of-input discipline).

**Field types.** Each field has one of these types (the names are those of `passes.txt`):

| Type | Written as | Read by a Baysick pass with |
|------|-----------|-----------------------------|
| `u` | an unsigned integer 0 … 999 999 999 in decimal, no sign, no leading zeros (`0` for zero) | `VAL` (at most 9 digits, Baysick LANGUAGE.md §6.1) |
| `i` | an `i64` value: if −10⁹ < v < 10⁹, an optional `-` and decimal digits as for `u` (zero is `0`, never `-0`); otherwise `#` and the 16 upper-case hexadecimal digits of its two's-complement 64-bit pattern (`#FFFFFFFFC4653600` is −1 000 000 000) | `VAL`, or four 16-bit limbs of 4 hex digits |
| `f` | always `#` and the 16 upper-case hexadecimal digits of the IEEE-754 binary64 pattern, sign bit first (`#3FB999999999999A` is 0.1, `#8000000000000000` is −0.0) | four 16-bit limbs (§2.7, table `C`) |
| `s` | a byte string, escaped (below) | `CHANGE` to codes, then decoding |
| `pos` | a source position `F:L:C`: `F` the index of the `#file` record (0 for the first, in header order), `L` the line in that file (from 1), `C` the column (from 1, counting bytes), each a `u` | `POS` of `:`, `VAL` |
| `site` | a run-time error site `F:L`: file index and line as in `pos` | as `pos` |
| an enumeration | one of the words `passes.txt` lists for it (`add`, `f64`, `arm64-macos`, …) | comparison with `DATA` words |
| a reference | a `u` number naming a table entry of the same file: `ty` a type (§3.5), `lid` a local, `fid` a function, `cid` a constant, `iid` an elemental instance, `blk` a structured LIR construct; or a prefixed token: `d`*n* a LIR data label, `s`*n* a stack slot, and the LIR registers `i`*n*, `f`*n*, `p`*n*, `x`*n*, `y`*n*, `m`*n* (§3.6) | `SEG$`, `VAL` |
| `fl` | `printf` flags: `-` for none, else the letters `l` (flag `-`), `p` (`+`), `s` (space), `z` (`0`), `a` (`#`), each at most once, in this order | codes |

A field is written `name:type`, then optionally `?`, then optionally `*` and a count. With `?`
(`u?`, `lid?`) the field may instead be the single character `-`, meaning "absent". With
`*count` (`ty*n`) the field is repeated as many times as the value of the earlier `u` field
`count`, each repetition a field of its own; both may be combined (`lid:lid?*n`: n fields, each a
local or `-`). In the tables of this section a bare reference type (`ty`, `lid`, `fid`, `cid`,
`iid`, `lab`, `slot`, `blk`), possibly with `?` or `*count`, stands for the field of that name and
type (`lid?*n` is `lid:lid?*n`); `passes.txt` writes every field as `name:type`.

**String escaping.** A string field holds the bytes of the string, each byte `b` written as the
character `b` itself if `0x21 ≤ b ≤ 0x7E` and `b ≠ 0x25` (`%`), and otherwise as `%` followed by
two upper-case hexadecimal digits: space is `%20`, `%` is `%25`, LF is `%0A`, the UTF-8 bytes of
`é` are `%C3%A9`. The **empty string** is the field `%` alone (a `%` not followed by two
hexadecimal digits occurs nowhere else). `#` and `-` in a string are ordinary characters: a field's
type is known from its position, and only the first field of a record can be a header opcode.

**Why these encodings.** Numbers are exact for Baysick: `VAL` reads at most 9 digits and doubles
cannot carry an `f64` pattern or an `i64` beyond 2⁵³, so everything else travels as hexadecimal
limbs (§2.8). A field never contains a blank and is never empty, so records split with `POS` on
`" "` and `SEG$`, Baysick's `PRINT #` writes every field unchanged (its lazy spaces never drop a
trailing blank, because there is none: Baysick LANGUAGE.md §8), and `=` compares two whole fields
exactly: the trailing-blank rule of §2.7 cannot apply to strings that contain no blank. A decoded
string value (which may contain blanks, or be empty) is never compared with `=`; passes compare
its codes or its length first (§2.7).

### 3.2 Header records

| Record | Fields | Meaning |
|--------|--------|---------|
| `#sea` | `ver:u` | the format version; `1` for the formats of this section |
| `#target` | `t:target` | the compilation target (enumeration `target`: `arm64-macos`, `x86_64-linux`) (`--target`, §2.2) |
| `#file` | `path:s` | one source file, in stream order: `std.sea` first (absent with `--no-prelude`, §2.2), then the program, its path as given to `sea`. File index `F` of positions counts these records from 0 |
| `#end` | — | the last record of the stream or file |

* **Pass-1 input stream** (written by the driver, §2.2): `#sea 1`, `#target`, then for each file
  its `#file` record followed by its source lines, then `#end`. A source line is written as `|`
  and its bytes, unescaped, then LF; a last line without LF is written the same way. Baysick's
  `LINPUT` removes one CR before the LF (Baysick LANGUAGE.md §15.2), which is the CR rule of
  LANGUAGE.md §3.1.
* **Intermediate files**: `#sea 1`, `#target`, all `#file` records in stream order, then the body
  records, then `#end`. Pass 1 writes this header (it writes its output after reading its whole
  input); every later pass copies the header records of its input unchanged.
* A pass stops with status 11 (§2.2) if its input lacks a header record, has them out of order,
  has a version other than 1 or an unknown target, or has a body record before the header ends.

### 3.3 Trees in post-order

`sea.ast` and `sea.hir*` hold trees. A tree is written in **post-order**: every node is one
record, written after the records of all its children, the children in source order (left to
right). Each node record **pops** a number of nodes, fixed by its opcode or given by one of its
fields (the "pops" column below and in `passes.txt`): those nodes are its children, the
earliest-written first. A reader therefore needs one stack: for each node record it pops that
many entries, builds the node with them as children in order, and pushes the node. Records never
refer to other nodes by number; the structure is given by the order alone. The header records,
the declaration records of §3.4.1 (`rerr`, `rtup`) and those of §3.5 (`t…`, `fd`, `inst`, `fn`,
`par`, `loc`) are not nodes and do not touch the stack; this list, not `passes.txt`, says which records are not nodes, and tools
take it from here. The records that end a section (`prog`, `cn`, `end`) pop their nodes and
push nothing, and the stack must then be empty; anything else is an internal error (status 11).

**Positions.** Every node of `sea.ast` and `sea.hir*` carries a `pos`: the position of the first
token of its source text. Parentheses are not nodes and are not part of the text of the node they
enclose, but they are part of the text of an enclosing node that starts with them: in
`(a + b) * c` the `+` node is at `a` and the `*` node at `(`. A node that a later pass creates
takes the position its rule names. Diagnostics (LANGUAGE.md §9.1, §9.2) report the position or
line of a node; which node each message reports is part of the error table (§2.6).

**Why post-order.** A pass reads its whole input into its tables (§2.7) and builds every tree
with one stack, without forward references; the stack never holds more entries than there are
nodes. The parser's recursion (bounded by the nesting limit 64, §2.7) produces post-order
naturally, and later passes iterate over post-order records (§2.7).

### 3.4 `sea.ast`

The syntax tree of the whole compilation unit, prelude first, exactly as parsed by the grammar of
LANGUAGE.md Appendix A: no names are resolved and nothing is typed. The body is the post-order of
each top-level item and statement in stream order, followed by `prog n`, the last record before
`#end`, which pops all n of them and is the one record without a position.

**Records** (every record except `prog` has `pos` as its first field after the opcode; the
"Pops" column is the number of child nodes as `passes.txt` writes it, §3.9, and "Children" names
them in order):

| Record | Fields after `pos` | Pops | Children (in order) | Source |
|--------|--------------------|------|---------------------|--------|
| `prog` | `n:u` (no `pos`) | `n` | n items and statements | the compilation unit |
| `const` | `name:s t:u` | `1+t` | [type if t = 1], expr | `const name [: type] = expr` |
| `struct` | `name:s n:u` | `n` | n `field` | `struct name { … }` |
| `field` | `name:s` | `1` | type | `name: type` in a struct |
| `fn` | `name:s el:u np:u nr:u` | `np+nr+1` | np `param`, nr types, block | `[elemental] fn name(…) [-> result] { … }`; el = 1 for `elemental`; nr = 0 (no result), 1 (`-> T`) or the number of types of a tuple result |
| `param` | `name:s rf:u d:u` | `1+d` | type, [default expr if d = 1] | `[ref] name: type [= expr]`; rf = 1 for `ref` |
| `type` | `base:s shape:shape nd:u` | `nd` | nd dims (each an `int` or `name`) | `base` is `f64`, `i64`, `bool`, `str` or an identifier; shape `s` (no brackets, nd 0), `v` `[]` (0), `m` `[,]` (0), `fv` `[d]` (1), `fm` `[d, d]` (2) |
| `let`, `var` | `t:u` | `2+t` | pattern, [type if t = 1], expr | `let`/`var pattern [: type] = expr` |
| `pname` | `name:s` | `0` | — | a name in a pattern |
| `pskip` | — | `0` | — | `_` in a pattern or as a tuple-assignment target |
| `ptuple` | `n:u` | `n` | n `pname`/`pskip` | `(p1, p2, …)` |
| `asg` | `op:asgop` | `2` | target, expr | `target op expr`; op `set add sub mul div` for `= += -= *= /=` |
| `tasg` | `n:u` | `n+1` | n targets (expressions or `pskip`), expr | `(t1, …, tn) = expr` |
| `cstmt` | — | `1` | a `call` | a call statement |
| `if` | `e:u` | `2+e` | cond, block, [else if e = 1: a `block`, or an `if` for `else if`] | `if` statement |
| `while` | — | `2` | cond, block | |
| `for` | `name:s npos:pos` | `2` | iterable (a `range` for a range loop, else an expression), block | `for name in … { … }`; `pos` is that of `for`, `npos` that of `name` (the loop variable); fields in this order |
| `match` | `n:u` | `n+1` | scrutinee, n `arm` | |
| `arm` | `k:u` | `k+1` | k `str` patterns, block | `"a" \| "b" => { … }`; k = 0 for `_` |
| `break`, `continue` | — | `0` | — | |
| `return` | `k:u` | `k` | k expressions | k = 0 `return`, 1 `return e`, ≥ 2 `return (e1, …, ek)` |
| `block` | `n:u` | `n` | n statements | `{ … }`, at the `{` |
| `int` | `v:i` | `0` | — | an integer literal's value (unsigned, ≤ 2⁶³; 2⁶³ is `#8000000000000000` and occurs only as the operand of `neg`) |
| `float` | `v:f` | `0` | — | a float literal, converted by pass 1 (§2.8) |
| `str` | `v:s` | `0` | — | a string literal's bytes after escape processing (LANGUAGE.md §3.5) |
| `true`, `false` | — | `0` | — | |
| `name` | `name:s` | `0` | — | an identifier |
| `dollar` | — | `0` | — | `$` |
| `neg`, `not` | — | `1` | operand | unary `-`, `!` |
| `bin` | `op:binop` | `2` | left, right | op `add sub mul div mod pow matmul eq ne lt le gt ge band bor and or` for `+ - * / % ^ @ == != < <= > >= & \| && \|\|` |
| `call` | `n:u` | `n+1` | callee, n arguments | `callee(a1, …, an)` |
| `narg` | `name:s` | `1` | expr | a named argument `name: expr` |
| `ref` | — | `1` | target | a `ref target` argument |
| `conv` | `t:cvtype` | `1` | expr | `f64(e)`, `i64(e)`, `str(e)` (there is no `bool(e)`: LANGUAGE.md Appendix A) |
| `index` | `n:u` | `n+1` | base, n indices (each an expression, `all` or `range`) | `base[i]`, `base[i, j]` |
| `all` | — | `0` | — | `:` as an index |
| `range` | `incl:u st:u` | `2+st` | lo, hi, [step if st = 1] | `lo..hi` (incl 0), `lo..=hi` (incl 1), `step` |
| `rangev` | — | `1` | a `range` | `( range )`, a range used as a value |
| `dot` | `name:s` | `1` | operand | `x.name`: field, projection or view, decided in pass 2a |
| `array` | `r:u` | `r` | r `row` | `[ … ]`, at the `[`; r = 0 for `[]` |
| `row` | `n:u` | `n` | n expressions | one row of an array literal |
| `slit` | `name:s n:u` | `n` | n `init` | `Name { … }` |
| `rlit` | `n:u` | `n` | n `init` | `{ … }` |
| `init` | `name:s` | `1` | expr | `name: expr` in a struct or record literal |
| `ifx` | — | `3` | cond, then-expr, else-expr (an `ifx` for `else if`) | `if` expression |

**What pass 1 has checked.** Every error of LANGUAGE.md §3 and every violation of the grammar of
LANGUAGE.md Appendix A and its disambiguation rules is reported by pass 1, so a written `sea.ast` is
syntactically valid: the child of `cstmt` is a `call` (otherwise `expression statement has no
effect`), `dollar` occurs only inside the index list of an `index` node (array-literal brackets
do not count, LANGUAGE.md §5.3), the operand `#8000000000000000` of `int` occurs only directly
under `neg` (parentheses produce no node, so `-(9223372036854775808)` is accepted too),
and
`a < b < c` has been rejected (comparisons are non-associative; a parenthesized comparison is an
ordinary operand). Everything that depends on names or types is reported by pass 2a.

**Example** (`ex.sea`, compiled with `--no-prelude`, so the program is file 0):

```sea
struct P {
    x: f64
    n: i64
}
fn scale(p: P, k: f64 = 2.0) -> f64 {
    return p.x * k ^ 2 * (0.5 * 3)
}
let p = P { n: 3, x: 1.5 }
var t = 0
for i in 0..p.n {
    t += scale(p, k: i)
}
t += scale(p)
printf("%.3f\n", t)
```

`sea build --emit ast --no-prelude ex.sea`:

```
#sea 1
#target arm64-macos
#file ex.sea
type 0:2:8 f64 s 0
field 0:2:5 x
type 0:3:8 i64 s 0
field 0:3:5 n
struct 0:1:1 P 2
type 0:5:13 P s 0
param 0:5:10 p 0 0
type 0:5:19 f64 s 0
float 0:5:25 #4000000000000000
param 0:5:16 k 0 1
type 0:5:33 f64 s 0
name 0:6:12 p
dot 0:6:12 x
name 0:6:18 k
int 0:6:22 2
bin 0:6:18 pow
bin 0:6:12 mul
float 0:6:27 #3FE0000000000000
int 0:6:33 3
bin 0:6:27 mul
bin 0:6:12 mul
return 0:6:5 1
block 0:5:37 1
fn 0:5:1 scale 0 2 1
pname 0:8:5 p
int 0:8:16 3
init 0:8:13 n
float 0:8:22 #3FF8000000000000
init 0:8:19 x
slit 0:8:9 P 2
let 0:8:1 0
pname 0:9:5 t
int 0:9:9 0
var 0:9:1 0
int 0:10:10 0
name 0:10:13 p
dot 0:10:13 n
range 0:10:10 0 0
name 0:11:5 t
name 0:11:10 scale
name 0:11:16 p
name 0:11:22 i
narg 0:11:19 k
call 0:11:10 2
asg 0:11:5 add
block 0:10:17 1
for 0:10:1 i 0:10:5
name 0:13:1 t
name 0:13:6 scale
name 0:13:12 p
call 0:13:6 1
asg 0:13:1 add
name 0:14:1 printf
str 0:14:8 %25.3f%0A
name 0:14:18 t
call 0:14:1 2
cstmt 0:14:1
prog 7
#end
```

`k ^ 2` binds tighter than `*` and `*` is left-associative (LANGUAGE.md §6.1), so the
`return` expression is `(p.x * (k ^ 2)) * (0.5 * 3)`; both outer `*` nodes start at `p`
(column 12), the parenthesized product at `0.5` (column 27). The float literals are 2.0
(`#4000000000000000`), 0.5 (`#3FE0000000000000`) and 1.5 (`#3FF8000000000000`); the format
string's bytes are `%.3f` and LF.

#### 3.4.1 `sea.res`

The syntax tree of `sea.ast` with its names resolved and its declarations checked: the output of
`seaname` and the input of `seacheck`, the two programs of pass 2a (§2.1, Decision 17). Nothing
in it is typed except what the declarations fix. Its records are those of `sea.ast` (§3.4) and
the records of this section (codes 50–63 of set `A` in `passes.txt`, §3.9), which occur only in
`sea.res`.

**Body**, in this order: at most one `rerr`; the `rtup` records, in id order; then the tree: the
records of the body of `sea.ast`, in the same order, each copied unchanged except the
replacements below. A replacement record is a node at the same position with the same children
(the same pops); its fields are those of the record it replaces, in the same order, followed by
its new fields (`rpowk` drops the operator field, always `pow`). So both programs build the same
tree and number its nodes alike, and every position, child count and error position of `sea.ast`
is unchanged in `sea.res`.

**Entered items and resolved regions.** An *entered* item is a top-level item that becomes a
symbol: every `fn`, `const` and `struct` item except one whose name an earlier item already has
(the later one is `redefinition of '%s'` and is not entered; an item with a predeclared name is
entered, after its `redefinition of predeclared name`). The *resolved regions* are the body block
of every entered `fn`, the top-level statements of the program's file (the body of `.main`),
and the expression (not the type annotation) of every entered `const`, without the *skipped
regions*: every `match` statement and every `for` whose iterable is not a `range` (each whole
statement, the iterable and the body included), which the single program never walks while the
phase rule reports them (`not supported yet: match`, and `not supported yet: arrays` at the
`for`; until phase 4 implements them, which then removes them from this list). Then:

* every entered `fn`, `struct` and `const` item record is replaced by `rfn`, `rst`, or one of
  `rcni rcnf rcnb rcne rcn` respectively; a not-entered item is copied unchanged;
* every `int` record of the file becomes `rint`;
* in the resolved regions, every `name` becomes `rname`, every `pname` `rpname`, every `for`
  `rfor`, and every `bin` with operator `pow` that is a `powk` by the rule below becomes `rpowk`;
* nothing else changes: `type` records (also those of signatures), parameter defaults, struct
  fields, and everything outside the resolved regions (the bodies of not-entered functions
  among it) are copied unchanged apart from their `int` records.

**Declaration records** (not nodes, §3.3):

| Record | Fields | Meaning |
|--------|--------|---------|
| `rerr` | `pos:pos code:u k:u a:s*k` | the first error `seaname` found ("Errors" below): its position, its code (§2.6.2) and its k substitutions in text order, spelled as §2.6.2 says (k ≤ 3, the most `args` letters an error has; each a name, a word or a type, at most 4 096 bytes); the one record with more than one string field (§3.1) |
| `rtup` | `id:u n:u t:ty*n` | a tuple type (§3.5.1 `ttuple`): the results of a function with n ≥ 2 results; ids from 10, dense, in order of creation (the signatures of the entered functions in item order, a tuple already created reused) |

A `ty` field of `sea.res` is 0 (a type that has an error, already reported), 1–9 (the predefined
types of §3.5.1) or the id of an `rtup` of the same file. `seacheck` adds the types it infers and
numbers all types again when it writes `sea.hir1` (§3.5.1).

**Replacement records:**

| Record | Fields after `pos` | Pops | Replaces | Meaning |
|--------|--------------------|------|----------|---------|
| `rfn` | `name:s el:u np:u nr:u fid:u rty:ty t:ty*np` | `np+nr+1` | `fn` | an entered function: its `fid` (§3.5.4: `.main` is 1, the entered `fn` items follow from 2 in stream order), its result type `rty` (1 for none, the type of one result, the `rtup` of several; 0 when a result type has an error) and its parameters' types `t` in order (0 for a parameter whose type has an error, among them a `str` parameter while strings are `not supported yet`, §2.6.2) |
| `rst` | `name:s n:u sid:u` | `n` | `struct` | an entered struct: its number `sid`, from 1 in stream order among the entered structs |
| `rcni` | `name:s t:u cid:u v:i` | `1+t` | `const` | an entered constant (`cid` from 1 in stream order among the entered constants, as `cn`, §3.5.2) whose value is the `i64` v |
| `rcnf` | `name:s t:u cid:u v:f` | `1+t` | `const` | … whose value is the `f64` v |
| `rcnb` | `name:s t:u cid:u v:u` | `1+t` | `const` | … whose value is the `bool` v (0 or 1) |
| `rcne` | `name:s t:u cid:u e:cerr epos:pos` | `1+t` | `const` | … whose evaluation fails: e `ovf` (`integer overflow`, code 260) or `div0` (`integer division by zero`, 261) at the operator node at `epos` |
| `rcn` | `name:s t:u cid:u` | `1+t` | `const` | … for which `seaname` has no value ("Constants" below) |
| `rpname` | `name:s lid:lid` | `0` | `pname` | the local the name declares |
| `rfor` | `name:s npos:pos lid:lid` | `2` | `for` | the local of the loop variable |
| `rint` | `v:i fv:f?` | `0` | `int` | `fv`: the bits of the literal's value as an `f64` when that value is exact in `f64`, else `-`; for the literal 2⁶³ (only the operand of a `neg`, §3.4) the bits of −2⁶³, `#C3E0000000000000`, because the two are written as one constant (§3.5.5) |
| `rname` | `name:s k:nkind ref:u` | `0` | `name` | what the name denotes where it stands: k `loc` a local or parameter of the current function (ref its lid), `cst` an entered constant (its cid), `fn` an entered function (its fid), `st` an entered struct (its sid), `pd` a predeclared name (LANGUAGE.md Appendix C; ref 0), `none` nothing (ref 0) |
| `rpowk` | `k:i` | `2` | `bin` (`pow`) | a `^` whose exponent is a constant integer k with \|k\| ≤ `SEA_LIM_POWK` (below); both children are kept |

**Names.** Each name is looked up by the scope rules of LANGUAGE.md §3.3, §7.2 and §7.7: the
locals and parameters of the current function that are in scope (innermost first), then the
entered items, then the predeclared names. Locals are numbered as §3.5.4 says (the parameters
1 … np, then the declared names in source order; a shadowing declaration is a new local), and
the lids of `rpname`, `rfor` and `rname loc` are those numbers, so they are the lids of the
`loc` records `seacheck` writes. The expression of a constant sees no locals. A skipped
region keeps its `sea.ast` records: it declares no local, so its `pname`s and its `for` carry no
lid and take no number, and the locals after it are numbered as if it were absent (as the single
program numbered them). `seacheck` takes every lid from `sea.res`; it never derives a lid from a
counter of its own and never compares such a counter with the lids of `sea.res` (it checks only
what "What `seacheck` validates" lists).

**The `symbols` limit** is `seaname`'s. It counts cumulatively, as the single program entered its
symbols: 1 for `.main`, then each entered item in stream order, then for each entered function
in fid order its parameters and then the locals of its body, then the locals of `.main`, each
function's locals in the order of their lids; skipped regions count nothing. The declaration
that would make the count exceed `SEA_LIM_SYMBOLS` is reported (`program too large: symbols`,
at the position §2.6.2 gives for it).

**Reading `sea.res` in `seacheck`.** Its reader is that of the single program with these
requirements: a record has up to 72 fields with its opcode (`rfn` with 64 parameters: 71 after
the opcode; `rtup` with 64 components: 66), and every `u`, reference and enumerated field of a
record is kept (up to 69 for `rfn`, 66 for `rtup`), not only the first three, so the splitting
of a record into at most 12 fields and the three `u` slots of a node row must change; `rerr` and
`rtup` are not nodes and are never pushed on the tree stack; the strings of `rerr` are not
interned (they count against no limit); an `fv` creates no row of the constants table (a
literal's row comes from its `v`, as for `sea.ast`); and the count of types for the `types`
limit starts at the number of `rtup` records.

**Constants.** Both programs take the entered constants in one *constant order*: for each
entered constant in stream order that is not yet visited, it is visited: marked *waiting*, then
the nodes of its expression are scanned in file order, and each `rname cst` among them that
names a constant not yet visited is visited first, recursively (an explicit stack, no Baysick
recursion); when a constant's scan ends it is *checked* (`seacheck`) or *evaluated*
(`seaname`) and marked done. In `seacheck`, a name of a waiting constant met during a check
closes a cycle: it is `not a constant expression` (code 237) at that name.

`seaname` evaluates each entered constant, in the constant order, on the well-typed path only:
it types the expression by the rules of LANGUAGE.md §4.2 and §6 (untyped integer constants,
the conversion to an annotated `f64`, `i64` → `f64` where an operator converts), decides the
`powk` of every `^` in it (below), and evaluates it as §3.5.2 says (`FEPOW` for the other `^`
and for `pow`). It reports no error and checks no rule: where it cannot type or evaluate the
expression (a node other than a literal, `true`, `false`, `neg`, `not`, `bin`, `rpowk`, a name
of a constant or of `pi inf nan eps`, or a call of `pow` or `sqrt` with positional arguments;
operand types the rules do not accept; an annotation it cannot use; a name of a waiting
constant), and wherever the rule of LANGUAGE.md §7.2 leaves a constant unevaluated (it names a
constant without a value, Decision 25), it writes `rcn`. Its outcome is written in the item's
record: `rcni`, `rcnf`, `rcnb` a value; `rcne` an evaluation that fails (the first failing
operation in evaluation order); `rcn` none of these (no value). A constant with an `rcne` or
`rcn` outcome has no value for the constants after it.

`seacheck` checks every entered constant itself, in the constant order, as the single program
does, reports its errors, and then decides its value (§3.5.2, Decision 25):

1. if the check found an error, the constant has no value, and the outcome is ignored;
2. otherwise, if its expression names a constant without a value, or its type is the error type
   (0), it has no value and no error, and the outcome is ignored;
3. otherwise the outcome must be a value of the kind of its derived type (`rcni` for `i64`,
   `rcnf` for `f64`, `rcnb` for `bool`), which becomes its value, or an `rcne` whose `epos` is
   the position of a `bin` or `neg` node of that constant's expression, `ovf` only at an `add`,
   `sub`, `mul` or `neg` and `div0` only at a `mod`: `seacheck` then reports `integer overflow`
   or `integer division by zero` at `epos` at that moment, so it takes its place in its find
   order, and the constant has no value. Any other outcome (`rcn` among them) is `BAD_RECORD`
   (status 11).

So a program without errors has a value for every constant, and `seacheck` reports
`BAD_RECORD` if it would write `sea.hir1` with a constant that has none. `seacheck` adds each
value to its constants table (`C` rows, §2.7) and enforces the `constants` limit for the
values of constants, at the constant's item (§2.6.2); `seaname` does not count them. A constant
without a value is read as a poisoned value (§3.5.2): it makes no `powk` and no further error.

**Constant exponents.** A `^` in a resolved region becomes `rpowk k` when, were it well typed,
§3.5.5's rule ("Constant exponents") would make it `powk k`: the exponent typed by the rules of
LANGUAGE.md §4.2 and §6 as `seacheck` types it (an untyped exponent taken as `f64`, an `i64` one
converted), its names resolved as above, and evaluated exactly; an exponent that names a
constant without a value is not constant. `seacheck` writes `powk k` for an `rpowk` whose `^` it
finds well typed, exactly where the phase-1 rule did (§3.5.5), and checks and writes nothing of
the exponent's value itself.

**Errors.** `seaname` reports the errors of the declaration checks only: those of the items (in
stream order) and then those of the signatures of the entered functions (in item order), the
codes §2.6.2 assigns to it ("Which program reports it"). It keeps the first of them in source
order (of two at one position, the first found), writes it as the `rerr` record, and still
writes the whole file and ends with status 0, so that `seacheck` checks the rest; with no such
error there is no `rerr`. A capacity limit `seaname` enforces (§2.7) is reported by `seaname`
itself at once, status 10 (the driver then uses no output). `seacheck` starts its own search
with the `rerr` error as the first error found, so of two errors at one position `seaname`'s is
reported (it was found first, by the order of §2.6.2).

**Protocol** (§2.2 steps 5–7). `seaname` reads `sea.ast` (Baysick file 1) and writes `sea.res`
(file 2); `seacheck` reads `sea.res` (file 1) and writes `sea.hir1` (file 2). Each copies the
header records of its input (§3.2), reads its input only with `LINPUT #1` after `IF END #1`,
requires the final `#end` (else `<program>: internal error: truncated input`, status 11, where
`<program>` is `seaname` or `seacheck`), writes `#end` last, and writes nothing to standard output.
The driver runs `seacheck` only on a `sea.res` that ends with `#end` (§2.2 step 6), and also when
it holds an `rerr`. `seaname` validates `sea.ast` as the single program did (a record of codes
50–63 in `sea.ast` is `BAD_RECORD`), and reports its errors and capacity errors as §2.6.2 says.

**What `seacheck` validates** (before checking anything; any violation is `BAD_RECORD`, status
11): every record against `passes.txt` (every enumerated field one of its words, every `pos`
well formed, only bytes 0x20–0x7E); `rerr` and `rtup` only before the tree, at most one `rerr`,
its `code` a code of phase `C2` with k equal to the number of its `args` letters; `rtup` ids
dense from 10 and every `ty` field 0, 1–9 or a defined id; no record of codes 50–63 outside the
places listed above, and none of `fn`, `const`, `struct`, `name`, `pname`, `for` or `int` where a
replacement is required; `fid`, `sid` and `cid` dense from 2, 1 and 1 in stream order; in each
function the lids of `rpname` and `rfor` dense from np + 1 in the source order of their
declarations (a loop variable before the locals of its body, although post-order writes its
`rfor` after them) and every `rname loc` naming a lid of that function; every `rname cst`, `fn` and `st` naming an entered item. The
constant guards above.

**Example** (`rs.sea`, compiled with `--no-prelude`):

```sea
const N = 2 * 3
fn split(x: f64) -> (f64, i64) {
    let k = i64(x)
    return (x ^ 2, k + N)
}
let (a, b) = split(pi)
for i in 0..b {
    printf("%g\n", a)
}
```

`sea build --emit res --no-prelude rs.sea`:

```
#sea 1
#target arm64-macos
#file rs.sea
rtup 10 2 4 3
rint 0:1:11 2 #4000000000000000
rint 0:1:15 3 #4008000000000000
bin 0:1:11 mul
rcni 0:1:1 N 0 1 6
type 0:2:13 f64 s 0
param 0:2:10 x 0 0
type 0:2:22 f64 s 0
type 0:2:27 i64 s 0
rpname 0:3:9 k 2
rname 0:3:17 x loc 1
conv 0:3:13 i64
let 0:3:5 0
rname 0:4:13 x loc 1
rint 0:4:17 2 #4000000000000000
rpowk 0:4:13 2
rname 0:4:20 k loc 2
rname 0:4:24 N cst 1
bin 0:4:20 add
return 0:4:5 2
block 0:2:32 2
rfn 0:2:1 split 0 1 2 2 10 4
rpname 0:6:6 a 1
rpname 0:6:9 b 2
ptuple 0:6:5 2
rname 0:6:14 split fn 2
rname 0:6:20 pi pd 0
call 0:6:14 1
let 0:6:1 0
rint 0:7:10 0 #0000000000000000
rname 0:7:13 b loc 2
range 0:7:10 0 0
rname 0:8:5 printf pd 0
str 0:8:12 %25g%0A
rname 0:8:20 a loc 1
call 0:8:5 2
cstmt 0:8:5
block 0:7:15 1
rfor 0:7:1 i 0:7:5 3
prog 4
#end
```

`split` is function 2 with the result type `(f64, i64)`, the tuple type 10, and one parameter of
type 4 (`f64`); `N` is constant 1, of value 6, evaluated in `i64`.
In `split`, `x` is local 1 (the parameter) and `k` local 2; in `.main`, `a`, `b` and `i` are
locals 1, 2 and 3. The exponent `2` of `x ^ 2` is an untyped constant, taken as `f64` and
integral, so the `^` is `rpowk 2`. The `type` records of the signature stay as they are. The
`int` values 2, 3 and 0 are exact in `f64` (`#4000000000000000`, `#4008000000000000`,
`#0000000000000000`).

### 3.5 `sea.hir1` and `sea.hir`

Both files have the same records; §3.5.6 lists what may appear in which. The body has up to four
parts, in this order: the **type table**, the **constants** (`sea.hir1` only), the **elemental
instances** (`sea.hir` only) and the **functions**.

#### 3.5.1 Types

Every type of the program has one id. Ids 1–9 are predefined and never written: 1 `void` (no
value: statements, functions without a result, format pieces), 2 `bool`, 3 `i64`, 4 `f64`,
5 `str`, 6 `Figure`, 7 `Axes`, 8 `Lu`, 9 `Chol`. Every other type has one record, ids from 10:

| Record | Fields | Type |
|--------|--------|------|
| `tvec` | `id:u elt:ty` | `T[]` |
| `tmat` | `id:u elt:ty` | `T[,]` |
| `tfvec` | `id:u elt:ty n:u` | `T[n]` |
| `tfmat` | `id:u elt:ty r:u c:u` | `T[r,c]` |
| `tstruct` | `id:u name:s n:u`, followed by n `fd` records | a declared struct, fields in declaration order |
| `trec` | `id:u n:u`, followed by n `fd` records | an anonymous record type (LANGUAGE.md §4.6) |
| `fd` | `name:s ty:ty` | one field |
| `ttuple` | `id:u n:u t:ty*n` | the results of a multiple-result function (n ≥ 2) |

Two types have the same id exactly when they are the same type: arrays, records and tuples
structurally (LANGUAGE.md §4.6 for records), structs by declaration. Fixed extents are the values
pass 2a computed for them (a `const` extent is evaluated exactly in integers by pass 2a, because
types need it; LANGUAGE.md §4.5). The range nodes of loops, indices and range values all have the
type `i64[]` (`tvec` of 3).

**Numbering.** Ids from 10 are given in order of first reference in the records after the type
table (file order, fields left to right); when a type is numbered, its component types that are
not yet numbered are numbered first, in order (element type; field types in declaration order;
tuple components), recursively. Types no record after the table refers to (directly or as a
component) are not written. The table is written in id order.

#### 3.5.2 Constants (`sea.hir1`)

| Record | Fields | Pops | Children |
|--------|--------|------|----------|
| `cn` | `cid:u name:s ty:ty pos:pos` | `1` | the constant's expression |

One `cn` per `const` item, in stream order, numbered from 1, each preceded by its value: pass 2a
evaluates every constant (LANGUAGE.md §7.2) exactly, as it evaluates constant exponents (§3.5.5,
with the emulation of §2.8 for `f64` and exact `i64`), and writes the result as **one leaf**: a
`ci`, `cf`, `cb` or `cs` of the constant's type, at the position of the expression's root. So the
child of a `cn` is always a single leaf, and constant substitution (§3.5.7) puts one leaf in place
of each `cref`. An evaluation that overflows `i64` or divides an `i64` by zero is the compile
error 260 or 261 (§2.6.2) and writes nothing. A constant that names a constant without a value
(one with an error, a failed evaluation or none of its own), or whose type is the error type
(after another error), is not evaluated at all and reports nothing of its evaluation
(LANGUAGE.md §7.2, Decision 25); a use of a constant without a value reads a poisoned value
(no `powk`, no further error). `pos` is that of the `const` keyword. A use of the
constant is a `cref` node. From phase 4a `seaname` evaluates the constants and hands each value, or
the outcome without one, to `seacheck` in the constant's `sea.res` record (`rcni` … `rcn`,
§3.4.1); `seacheck` writes the `cn` leaf from it.

#### 3.5.3 Elemental instances (`sea.hir`)

| Record | Fields |
|--------|--------|
| `inst` | `iid:u fid:fid rty:ty n:u t:ty*n` |

An instance is an elemental function (`fid`) applied with one particular list of argument types
(`t`, one per parameter, after the conversions of LANGUAGE.md §4.2; at least one of the
elemental parameters has an array type); `rty` is the type of the application's value (an array
of the broadcast shape, LANGUAGE.md §6.3, or a tuple of such arrays). Applications with the same
`fid` and argument types share one instance. Instances are numbered from 1 in order of first
reference by an `emap` record and written in id order.

#### 3.5.4 Functions

```
fn <fid> <name> <kind> <rty> <np> <nl> <pos>
par <name> <ty> <mode>                       np records: locals 1 … np
loc <name> <ty> <mut> <pos>                  nl records: locals np+1 … np+nl
<the body's records>
end                                          pops the body (one block)
```

| Record | Fields | Pops | Meaning |
|--------|--------|------|---------|
| `fn` | `fid:u name:s kind:fkind rty:ty np:u nl:u pos:pos` | `0` | kind `main` (the implicit main function of the top-level statements, LANGUAGE.md §7.2, named `.main`), `fn`, or `elem` (an `elemental fn`); `rty` the result type (1 for none, a `ttuple` for several); `pos` the `fn` or `elemental` keyword, for `.main` line 1, column 1 of the program's file |
| `par` | `name:s ty:ty mode:pmode` | `0` | a parameter; mode `val` or `ref` |
| `loc` | `name:s ty:ty mut:lmut pos:pos` | `0` | a local; mut `let`, `var` or `for` (a loop variable, LANGUAGE.md §7.5); `pos` its name in the declaration (for a loop variable the `npos` of its AST `for`) |
| `end` | — | `1` | the end of the function; pops its body block |

Functions are numbered from 1: `.main` first, then every `fn` item in stream order (the prelude's
first). Locals are numbered per function: the parameters in order, then the locals in the order
of their declaring names in the source (the names of a `let`/`var` pattern from left to right, a
loop variable at its `for`), then the temporaries `.t1`, `.t2`, … that pass 2a creates
("Evaluation order", §3.5.5), then the locals `.j1`, `.j2`, … that pass 2b creates (§3.5.7).
Each group is numbered in the order of its declaring records in the function's body (file order:
the `bind` of a `.t` local, the `bind`, `forr` or `fore` of a `.j` local), and the names count
from 1 in each function. A shadowing declaration (`var lo = lo`) is a new local. The body of
`.main` is a `block`, at the position of `.main`, holding the top-level statements of the
program's file in order (the prelude has items only). Default arguments, named arguments and the
`ref` marks of calls are resolved: a call's arguments are written in parameter order (their
evaluation order is kept by the rule "Evaluation order" of §3.5.5), a missing argument is a copy
of the parameter's default expression with the default's own positions, and a `ref` argument is
an `rarg` node.

#### 3.5.5 Nodes

Expression records have the fields `pos ty` first: `ty` is the expression's static type after
every implicit conversion, which pass 2a has made explicit (`cvt`, `dyn`, `fix`, and for the
components of a tuple assignment the `cv` flags of `tasg`, which pass 2a sets and passes 2b and
3a carry unchanged, since a component has no expression node to put a `cvt` on); untyped integer
constants (LANGUAGE.md §4.2) are written with their decided type (`ci` for `i64`, `cf` for
`f64`). Statement records have `pos` first and no type.

| Record | Fields after `pos` | Pops | Children | Meaning |
|--------|--------------------|------|----------|---------|
| `ci` | `ty v:i` | `0` | — | an `i64` constant |
| `cf` | `ty v:f` | `0` | — | an `f64` constant (also `pi` `#400921FB54442D18`, `inf` `#7FF0000000000000`, `nan` `#7FF8000000000000` (the quiet NaN that LANGUAGE.md §10.1 leaves unspecified), `eps` `#3CB0000000000000`, LANGUAGE.md §10.1) |
| `cb` | `ty v:u` | `0` | — | `false` (0) or `true` (1) |
| `cs` | `ty v:s` | `0` | — | a `str` constant |
| `lv` | `ty lid` | `0` | — | a local or parameter of the current function |
| `cref` | `ty cid` | `0` | — | a named constant (`sea.hir1`) |
| `dol` | `ty dim:u` | `0` | — | `$`: the extent of dimension `dim` (0 or 1) of the base of the innermost enclosing `idx` (LANGUAGE.md §5.3) |
| `cvt` | `ty` | `1` | operand | `i64` → `f64`, of a scalar or element by element (LANGUAGE.md §4.2) |
| `dyn` | `ty` | `1` | operand | a fixed-size array to the dynamic type of the same rank (LANGUAGE.md §4.5) |
| `fix` | `ty` | `1` | operand | a dynamic array to a fixed-size type, with the run-time shape check (LANGUAGE.md §4.5) |
| `un` | `ty op:unop` | `1` | operand | `neg`, `not` |
| `bin` | `ty op:hbinop` | `2` | left, right | the AST operators plus `cat` (`+` of two `str`); `div` and `pow` always have `f64` operands (pass 2a converts `i64` operands, LANGUAGE.md §6.5); `pow` only when the exponent is not a constant integral \|k\| ≤ 4 (then `powk`) |
| `powk` | `ty k:i` | `1` | base | `base ^ k` for a constant exponent whose value is an integer k with \|k\| ≤ 4, evaluated by the pinned multiplications of LANGUAGE.md §6.5; written by pass 2a (§3.5.5, "Constant exponents") |
| `call` | `ty fid n:u` | `n` | n arguments | a call of a Sea function (also of an elemental function with scalar arguments); `ty` a `ttuple` for several results |
| `rarg` | `ty` | `1` | target | a `ref` argument (LANGUAGE.md §8.3) |
| `emap` | `ty iid n:u` | `n` | n arguments | an elemental function applied element by element (instance `iid`, `sea.hir`) |
| `lib` | `ty name:s n:u` | `n` | n arguments | a library function (LANGUAGE.md §10–§13): `name` is its predeclared name, or `f64`, `i64` or `str` for those conversions; a reduction called with `dim:` is written `name.dim` (`max.dim`); arguments in the order of the signature in LANGUAGE.md §10–§13, named options included, defaults inserted |
| `fmt` | `ty k:u` | `k` | k pieces | a pre-parsed format string (LANGUAGE.md §11.1); `ty` is 1; the only argument of `lib printf`, `lib format` and `lib error` |
| `ftext` | `ty v:s` | `0` | — | literal bytes of a format (`%%` already turned into `%`); `ty` is 1 |
| `fconv` | `ty fl:fl w:u? p:u? conv:conv` | `1` | the argument | one conversion: flags, width, precision, conversion letter (`d i f F e E g G s`); `ty` is 1 |
| `view` | `ty k:view` | `1` | operand | `.T`, `.flat`, `.col`, `.row` (LANGUAGE.md §5.6) |
| `fld` | `ty i:u` | `1` | operand | field i (from 0, declaration order) of a struct or record value |
| `proj` | `ty i:u` | `1` | operand | the projection of field i of an array of structs (LANGUAGE.md §4.7) |
| `idx` | `ty n:u` | `n+1` | base, n indices | `base[…]`; each index is a scalar `i64`, an `i64` vector, a `bool` mask, an `rng` or `all` (LANGUAGE.md §5.2), told apart by type and record |
| `all` | `ty` | `0` | — | `:` (`ty` 1) |
| `rng` | `ty incl:u st:u` | `2+st` | lo, hi, [step] | a range (`ty` is `i64[]`) |
| `arr` | `ty r:u` | `r` | r `row` | an array literal; `ty` its type (LANGUAGE.md §6.9) |
| `row` | `ty n:u` | `n` | n elements | one row; `ty` the type of the row's horizontal join (for a row of n scalars `T[n]`) |
| `slit` | `ty n:u` | `n` | n field values | a struct or record literal, values in **declaration** order (evaluation order: "Evaluation order" below) |
| `ifx` | `ty` | `3` | cond, then, else | an `if` expression |
| `skip` | `ty` | `0` | — | `_` as a tuple-assignment target (`ty` 1) |
| `seq` | `ty n:u` | `n+1` | n `bind`, value | evaluate the n bindings in order, then the value, which is the `seq`'s value (`ty` the value's type, a `ttuple` for a multiple-result call); written by pass 2a only to keep source evaluation order ("Evaluation order" below) |
| `bind` | `lid` | `1` | value | `let`/`var` of one name (the local `lid`) |
| `tbind` | `n:u lid?*n` | `1` | a multiple-result application | `let (…) = f(…)`; `-` for `_`; the child is a `call`, in `sea.hir` also an `emap` of a multiple-result elemental function (§3.5.7), either possibly as the value of a `seq` |
| `eval` | — | `1` | expression | a call statement, or `let _ = e` |
| `asg` | `op:asgop` | `2` | target, value | assignment; the target is an `lv`, `idx`, `fld` or `view flat` tree (LANGUAGE.md §7.3) |
| `tasg` | `n:u cv:u*n` | `n+1` | n targets (or `skip`), a multiple-result application | `(t1, …) = f(…)`; the last child as for `tbind`; fields in the order n, then one `cv` per target in target order: 1 if result i is an `i64` stored into an `f64` target (converted, LANGUAGE.md §4.2 (b)), else 0 (also for `skip`) |
| `if` | `e:u` | `2+e` | cond, block, [else: `block` or `if`] | |
| `while` | — | `2` | cond, block | |
| `forr` | `lid` | `2` | `rng`, block | a range loop; `lid` the loop variable |
| `fore` | `lid` | `2` | vector, block | an element loop (also `for x in (range)`) |
| `match` | `n:u` | `n+1` | scrutinee, n `arm` | |
| `arm` | `k:u` | `k+1` | k `cs` patterns, block | the arm's string patterns, in source order; k = 0 for `_` |
| `break`, `cont` | — | `0` | — | |
| `ret` | `k:u` | `k` | k values | |
| `tret` | — | `1` | a multiple-result application | `return f(…)` of a call whose results are returned unchanged (LANGUAGE.md §8.4); the child as for `tbind`, its type the function's result `ttuple` exactly |
| `block` | `n:u` | `n` | n statements | a scope (LANGUAGE.md §7.7) |
| `jopen` | — | `1` | path | start a JSON file (`sea.hir`, §3.5.7) |
| `jclose` | — | `0` | — | end the JSON file: final LF, flush, close |
| `jobj`, `jarr`, `jend` | — | `0` | — | begin an object, begin an array, end the innermost one |
| `jkey` | `v:s` | `0` | — | the next member's key |
| `jval` | — | `1` | a scalar | one `f64`, `i64`, `bool` or `str` value (LANGUAGE.md §11.4) |
| `jvec`, `jmat` | — | `1` | an array | a vector (flat array) or matrix (array of rows) of scalars |

**Positions of the nodes pass 2a writes** (§3.3: a node takes the position its rule names).
A node made from one AST node takes that node's position: `lv`, `cref`, `call` and `lib` take the
position of the `name` or `call` node they come from (for a call, the callee's first token), `fld`,
`proj` and `view` that of the `dot`, `rarg` that of the `ref`, `dol` that of the `dollar`, `slit`
that of the `slit` or `rlit`, `forr`/`fore` that of the `for`, `bind`, `tbind`, `asg` and `tasg`
that of the `let`, `var`, `asg` or `tasg` statement, `eval` that of the `cstmt`, `ret` and `tret`
that of the `return`, `cs` patterns those of the `str` patterns, and a `lib f64`, `lib i64` or
`lib str` made from a `conv` node that of the `conv` (its type keyword). Nodes that pass 2a adds:

* `cvt`, `dyn`, `fix`: the position of the operand they convert;
* `fmt`, and each of its `ftext` and `fconv` pieces: the position of the format string literal
  (its opening `"`);
* a `neg` whose operand is the `int` 2⁶³ becomes one constant at the position of the `neg`:
  `ci` −2⁶³ (`#8000000000000000`), or `cf` −2⁶³ (`#C3E0000000000000`) where the untyped constant
  is `f64` (LANGUAGE.md §4.2);
* a copied default argument: the default expression's own positions (§3.5.4);
* untyped integer constants keep their own shape: a `/` whose operands are untyped constants
  writes each as a `ci` under a `cvt` (they are `i64` by LANGUAGE.md §4.2, and `/` converts both),
  and a unary minus of an untyped constant stays `un neg` of the `ci` (or of the `cf` in an `f64`
  context), except the 2⁶³ case below; pass 2b folds them (§3.5.7);
* `powk`: the position of the `bin pow` it replaces; the exponent's nodes are not written;
* `seq`: the position of the `call`, `lib` or `slit` it wraps; each of its `bind` nodes, the
  `loc` record of its `.t` local and the `lv` written in the expression's place: the position of
  the bound expression;
* the body `block` of `.main`: line 1, column 1 of the program's file.

**Evaluation order.** LANGUAGE.md §6.8 rule 5 evaluates operands and arguments left to right, in
source order. Where pass 2a writes the children of a `call`, `lib` or `slit` in another order
than the source (named arguments in parameter order, named options in signature order, literal
values in declaration order), it keeps the source order with temporaries:

* if the written order of the source's argument (or value) expressions differs from their source
  order, every such expression that is not a constant (`ci`, `cf`, `cb`, `cs`) or a `rarg` is
  bound, in source order, to a new local `.t`*n* (mut `let`, the expression's type) by a `bind`,
  and is written in its place as `lv .t`*n*; inside a `rarg`, every index expression of the target
  that is not a constant is bound the same way, in source order among the others;
* the node is then the value of a `seq` that holds those `bind` nodes (§3.5.5 table);
* inserted default arguments are constant expressions without effects (LANGUAGE.md §8.1) and are
  evaluated in their parameter position, after the temporaries;
* when the written order equals the source order, nothing is added.

Example (`ev.sea`, `--no-prelude`): the struct literal on line 13 evaluates `f()` before `g()`,
so the program prints `f` and then `g`:

```sea
struct P {
    x: f64
    n: i64
}
fn f() -> i64 {
    printf("f\n")
    return 1
}
fn g() -> f64 {
    printf("g\n")
    return 2.0
}
let p = P { n: f(), x: g() }
```

The `.main` function of its `sea.hir1` (`P` is type 10; `f` and `g` are functions 2 and 3):

```
fn 1 .main main 1 0 3 0:1:1
loc p 10 let 0:13:5
loc .t1 3 let 0:13:16
loc .t2 4 let 0:13:24
call 0:13:16 3 2 0
bind 0:13:16 2
call 0:13:24 4 3 0
bind 0:13:24 3
lv 0:13:24 4 3
lv 0:13:16 3 2
slit 0:13:9 10 2
seq 0:13:9 10 2
bind 0:13:1 1
block 0:1:1 1
end
```

The program of §3.4 needs no temporary: its struct literal's values are
constants, and its named argument `k: i` is already in parameter order.

**Constant exponents** (pass 2a). (From phase 4a `seaname` decides it and marks the `^` `rpowk k` in
`sea.res`; `seacheck` writes the `powk` for a well-typed `^`, §3.4.1.) For every `^` whose exponent is a constant
expression (LANGUAGE.md §7.2: literals, constants, operators, `pi inf nan eps`, `sqrt`, `pow`), pass 2a
computes the exponent's value exactly as the run time would: `f64` operations by exact
multi-limb arithmetic emulating IEEE binary64 round-to-nearest-even (`+ − × ÷`, `%` by the
exact `fmod` rule of LANGUAGE.md §6.6, `cvt`, unary `−`), `i64` operations exactly with the range
check, on infinities and NaN as on any other value, and never with Baysick's floating-point
operations (§2.8), so nothing can stop the pass. If the value is an integer k with \|k\| ≤ 4
(`SEA_LIM_POWK`; `2`, `2.0`, `6 % 4`, `const K = 6 % 4`, `-0.0` as k = 0), the `^` becomes
`powk k`; otherwise it stays `bin pow` with its exponent. An exponent whose evaluation overflows
`i64` or divides an `i64` by zero is not integral here; it stays, and the run time reports the
error. An exponent that contains a call (`sqrt` or any other) or a `^` that is itself not a
`powk` is not integral, whatever its value (LANGUAGE.md §6.5), so it is not evaluated. This is judged on the exponent as written: a `const` name counts by its value, however that const was defined (`const K = pow(4.0, 0.5)` gives `x ^ K` as `powk 2`, since `K` contains no call). Constant
extents (§3.5.1) and the `i64` values of constant
expressions use the same exact evaluator. In a `const` item's expression, a `^` that is not a `powk` and a call `pow(x, y)` are
evaluated with `FEPOW` (§4.10.5; Decision 16), which gives the run time's bits.

**Decided language rules that pass 2a applies** (LANGUAGE.md): `write_json` of a value whose
type is or contains a handle type is `no overload of 'write_json' accepts (…)`, at the `call`
(LANGUAGE.md §11.4); `return f(…)` of a multiple-result call is a `tret` when `f`'s result
types equal the function's result types exactly, otherwise `type mismatch` (expected the
function's results, found `f`'s, at the call) or `wrong number of results: expected 0, found n`
(at the `return`) in a function without results (LANGUAGE.md §8.4). (`bool(x)` does not parse:
pass 1 reports `unexpected token 'bool'`, LANGUAGE.md Appendix A.)

**What pass 2a has checked.** Every rule of LANGUAGE.md §3–§13 that is not lexical or
syntactic: names, scopes, types, ranks, untyped constants and the `var` typing rule (Decision 8,
§9), library overloads, format strings against their arguments, `match` exhaustiveness and
duplicates, `ref` arguments and aliasing, effects in elemental functions, missing returns. Shape
mismatches between dynamic extents remain run-time checks (LANGUAGE.md §4.10).

#### 3.5.6 `sea.hir1` and `sea.hir` compared

| Only in `sea.hir1` | Only in `sea.hir` |
|--------------------|-------------------|
| `cn` and `cref` | `inst`, `emap` |
| `call` of an elemental function with array arguments | the `j*` records and the locals `.j1`, `.j2`, … they use |
| `lib write_json` | folded constants (§3.5.7) |
| every function | only the reachable functions, renumbered |

In both files the type table holds exactly the types the file's other records refer to (§3.5.1),
so `sea.hir` usually has fewer types than `sea.hir1`.

#### 3.5.7 What pass 2b does

**What pass 2b validates.** Before it transforms anything, pass 2b checks every record of
`sea.hir1` against `passes.txt` and in addition: every enumerated field is one of its enum's
words (`tb_word`), every `pos` field is a well-formed position (`io_pos`), every record holds only
bytes 0x20–0x7E (`io_plain`, §3.1), the operand and result types of every node it folds are
those of the operation (an `f64` `add` has two `f64` operands, …) before it folds, and every
`cref` has the type of its `cn`. Any violation is `BAD_RECORD` (§2.6.2).

In this order:

1. **Constant substitution.** Every `cref` is replaced by a copy of its constant's leaf (§3.5.2:
   one `ci`, `cf`, `cb` or `cs`), which takes the position of the `cref`. The `cn` records are
   not written. Constants never need folding here; step 2 folds what the program's own constant
   subtrees still hold.
2. **Folding** (§2.8), bottom-up, of subtrees whose operands are constants (`ci`, `cf`) only:
   `f64` `add sub mul div` (any operand values, ±∞ and NaN included, §2.8), `powk k` of an `f64`
   constant (the multiplications of LANGUAGE.md §6.5 in their pinned order, each rounded),
   `un neg` of an `f64` (a sign flip), `lib sqrt` of an `f64` (any value: a negative operand
   gives the default NaN, §2.8), `i64` `add sub mul` and `un neg` when the exact result is in the
   `i64` range (otherwise the node stays, and the overflow is reported at run time, LANGUAGE.md
   §6.5), and `cvt` of an `i64` constant (rounded to nearest, ties to even, exactly). Nothing
   else is folded (no comparison, logic, `%`, `pow`, transcendental function or conversion to
   `i64`). A folded subtree becomes one `ci`/`cf` at the position of its root. (`powk` is decided earlier, by pass 2a, with exact arithmetic: §3.5.5, "Constant
   exponents".)
3. **Elemental instantiation.** A `call` of an elemental function with at least one array
   argument becomes an `emap` of the instance for its argument types (§3.5.3), with the same
   position, type and arguments.
4. **`write_json` expansion.** An `eval` of `lib write_json(path, value)` at position P becomes
   the following block, every new node at P. The new locals are named `.j1`, `.j2`, … and
   numbered per function, after the parameters, the source locals and the `.t` temporaries,
   in the order of their declaring records in the body (§3.5.4); below, `J1` is the `.j` local
   of the path (mut `let`, the path's type), `J2` that of the value (mut `let`), and `K`, `R`,
   `C` stand for the next `.j` locals in the order they are declared (mut `for`):

   ```
   block P: bind J1 = path; bind J2 = value; jopen (lv J1); emit(lv J2); jclose
   ```

   where emit(e), by the type of e: a scalar → `jval e`; a struct or record → `jobj`, then for
   each field i in declaration order `jkey <name>` and emit(`fld e i`), then `jend`; a vector or
   fixed vector of scalars → `jvec e`; a matrix or fixed matrix of scalars → `jmat e`; a vector of
   structs or records → `jarr`, `fore K in e { emit(lv K) }`, `jend`; a matrix of structs or
   records → `jarr`, `forr R in 0..rows(e) { jarr; forr C in 0..cols(e) { emit(idx e
   (lv R) (lv C)) }; jend }`, `jend`. Every loop body is one `block`. A handle type has no
   case: pass 2a has rejected it (LANGUAGE.md §11.4). The runtime writes
   the layout of LANGUAGE.md §11.4 (indentation, one member or element per line, `[]` for an
   empty array).
5. **Reachability.** Functions reachable from `.main` through `call` records and through the
   instances of `emap` records are kept; the others, and instances no kept function uses, are
   dropped. Functions and instances are renumbered densely in their previous order, and types by
   §3.5.1.

#### 3.5.8 Example

The program of §3.4. `sea build --emit hir1 --no-prelude ex.sea`:

```
#sea 1
#target arm64-macos
#file ex.sea
tstruct 10 P 2
fd x 4
fd n 3
tvec 11 3
fn 1 .main main 1 0 3 0:1:1
loc p 10 let 0:8:5
loc t 4 var 0:9:5
loc i 3 for 0:10:5
cf 0:8:22 4 #3FF8000000000000
ci 0:8:16 3 3
slit 0:8:9 10 2
bind 0:8:1 1
cf 0:9:9 4 #0000000000000000
bind 0:9:1 2
ci 0:10:10 3 0
lv 0:10:13 10 1
fld 0:10:13 3 1
rng 0:10:10 11 0 0
lv 0:11:5 4 2
lv 0:11:16 10 1
lv 0:11:22 3 3
cvt 0:11:22 4
call 0:11:10 4 2 2
asg 0:11:5 add
block 0:10:17 1
forr 0:10:1 3
lv 0:13:1 4 2
lv 0:13:12 10 1
cf 0:5:25 4 #4000000000000000
call 0:13:6 4 2 2
asg 0:13:1 add
lv 0:14:18 4 2
fconv 0:14:8 1 - - 3 f
ftext 0:14:8 1 %0A
fmt 0:14:8 1 2
lib 0:14:1 1 printf 1
eval 0:14:1
block 0:1:1 5
end
fn 2 scale fn 4 2 0 0:5:1
par p 10 val
par k 4 val
lv 0:6:12 10 1
fld 0:6:12 4 0
lv 0:6:18 4 2
powk 0:6:18 4 2
bin 0:6:12 4 mul
cf 0:6:27 4 #3FE0000000000000
cf 0:6:33 4 #4008000000000000
bin 0:6:27 4 mul
bin 0:6:12 4 mul
ret 0:6:5 1
block 0:5:37 1
end
#end
```

`P` is the first type referred to after the table (by `loc p`), `i64[]` the next (by the
`rng`). `var t = 0` is `f64` because `t += scale(…)` stores an `f64` (LANGUAGE.md §4.2), so
its initialiser is the `f64` 0. The struct literal's values are in declaration order (`x`, then
`n`). The named argument `k: i` is converted (`cvt`); the call `scale(p)` gets a copy of the
default `2.0` with the default's position. The untyped `2` and `3` in `scale` are `f64` (the
operand of `^`, and the operand of `*` beside `0.5`); `k ^ 2` has the constant exponent 2, so
pass 2a writes `powk 2` at the position of the `^` node (column 18) and no exponent node.

`sea build --emit hir --no-prelude ex.sea` differs only in the body of `scale`, where `0.5 * 3`
is folded to 1.5:

```
fn 2 scale fn 4 2 0 0:5:1
par p 10 val
par k 4 val
lv 0:6:12 10 1
fld 0:6:12 4 0
lv 0:6:18 4 2
powk 0:6:18 4 2
bin 0:6:12 4 mul
cf 0:6:27 4 #3FF8000000000000
bin 0:6:12 4 mul
ret 0:6:5 1
block 0:5:37 1
end
#end
```

(The records before `fn 2` are those of the `sea.hir1` dump above.)

### 3.6 `sea.lir1` and `sea.lir`

LIR (§2.4) is a linear, typed three-address code. The body of a LIR file is the **functions**,
then the **data records** (after the functions, so that pass 3a can write each function as soon
as it is lowered and the data it collected at the end, §2.7).

#### 3.6.1 Registers and values

A virtual register is written as a class letter and a number: `i` (`i64`), `f` (`f64`), `p`
(`ptr`, an address), `x` (`v2f64`), `y` (`v4f64`), `m` (a lane mask). Numbers are unique within a
function across all classes and given from 1 in order of first appearance in the function's
records (record order, fields left to right; the parameters, in the `func` record, come first).
A register is a variable: several instructions may write it (LIR is not in SSA form), and it is
local to its function. A mask has the lane count (2 or 4) of the instruction that defines it and
is used only with vectors of that lane count.

Sea values in registers: `i64` and `bool` (0 or 1) in `i`; `f64` in `f`; `str` values, dynamic
arrays and handles as `p` (the address of the runtime object, layouts in `rt.inc`, §4.8). Structs
and fixed-size arrays live in memory (stack slots, or inside arrays and structs) and are
addressed with `p` registers; pass 3b scalar-replaces them into registers where §5.3 allows.

#### 3.6.2 Data records

| Record | Fields | Meaning |
|--------|--------|---------|
| `str` | `lab v:s` | a static, never-freed string object with the bytes v |
| `fmt` | `lab k:u`, then k `ftext`/`fconv` records | a pre-parsed format (LANGUAGE.md §11.1) |
| `ftext` | `v:s` | literal bytes |
| `fconv` | `fl:fl w:u? p:u? conv:conv cls:rcls` | a conversion and the register class of its argument (`i`, `f`; `p` for `%s`) |
| `dat` | `lab elt:delt n:u`, then n `dvi` (elt `i64`, `bool`) or `dvf` (elt `f64`) records | a read-only element buffer (constant array data) |
| `dvi` | `v:i` | one `i64` or `bool` element |
| `dvf` | `v:f` | one `f64` element |

Labels are `d1`, `d2`, … in order of first reference by an instruction of `sea.lir1` (file
order); every occurrence in the source has its own label (no sharing). Pass 3b keeps the labels
and every data record of its input, even one no instruction refers to any more. The data records
come in label order, after the last function. How pass 4 lays them out is fixed in `rt.inc`
(§4.8).

#### 3.6.3 Functions

```
func <name> <kind> <pos> <np> <params…> <nr> <classes…>
slot <s> <size> <align>                      0 or more stack slots
<instructions>
endfunc
```

| Record | Fields | Meaning |
|--------|--------|---------|
| `func` | `name:s kind:lkind pos:pos np:u par:reg*np nr:u cls:rcls*nr` | kind `main` (named `.main`, called by the runtime as `_sea_main`, §4.5) or `fn`; `pos` that of the HIR `fn` record (§3.5.4), which passes 3b and 4 report for a capacity limit (§2.6.2, `at` word `here`); parameters as registers; the classes of the results |
| `slot` | `id:slot size:u align:u` | a stack slot of `size` bytes, `align` a power of two; `s1`, `s2`, … in order |
| `endfunc` | — | the end of the function |

Functions come in the order of `sea.hir`, without those that pass 3a inlined completely
(elemental functions are always inlined, LANGUAGE.md §8.5, so no instance or elemental function
is ever a LIR function; neither is a prelude function, §3.6.4, "Sites"). Pass 4 chooses each function's assembler symbol (local to `sea.s`) except
for `.main`.

**Calling convention between Sea functions** (pass 4 maps it to AAPCS64 or the System V ABI):
`i64` and `bool` parameters and results are `i`, `f64` are `f`, `str`, arrays and handles are `p`
(the callee borrows them: it neither retains nor releases them, §4.2). A struct or fixed-size
array parameter is a `p` to the caller's memory, read-only for the callee. A `ref` parameter is a
`p` to the caller's variable in memory (a scalar `ref` argument lives in a stack slot of the caller
for the call). A struct or fixed-size array result is written by the callee to memory whose
address the caller passes as an extra parameter in front of the others, one per such result in
result order; it is not a register result. Several results are several result registers. A
`tret` (§3.5.5) is a `call` whose register results are returned by a `ret` of the same
registers; for results returned in memory, the function passes its own hidden result addresses
on to the callee in their place. LIR needs no record of its own for it.

#### 3.6.4 Instructions

The destination comes first. Operands are registers; constants are loaded with `li`/`lf`.
"site" is the `site` field (§3.1) of the source line an instruction's run-time error reports.

| Instruction | Operands | Meaning |
|-------------|----------|---------|
| `li` | `d:ri v:i` | load an `i64` constant |
| `lf` | `d:rf v:f` | load an `f64` constant (its exact bits) |
| `la` | `d:rp lab:lab` | the address of a data item |
| `sa` | `d:rp slot:slot` | the address of a stack slot |
| `mov` | `d:reg a:reg` | copy; both of the same class |
| `iadd isub imul` | `d:ri a:ri b:ri` | wrapping (mod 2⁶⁴); only where no overflow can occur (addresses, induction values) or wrapping is intended (magic division) |
| `iaddc isubc imulc` | `d:ri a:ri b:ri site:site` | exact; a result outside `i64` is `integer overflow` (LANGUAGE.md §6.5) |
| `ineg` | `d:ri a:ri` | negation, wrapping |
| `inegc` | `d:ri a:ri site:site` | negation, checked (`integer overflow`) |
| `idivf imodf` | `d:ri a:ri b:ri site:site` | floored quotient and modulo (LANGUAGE.md §6.6): a zero divisor is `integer division by zero`; `idivf` of −2⁶³ by −1 is `integer overflow` |
| `imulh` | `d:ri a:ri b:ri` | the high 64 bits of the signed 128-bit product |
| `iand ior ixor` | `d:ri a:ri b:ri` | bitwise |
| `ishl ishr isar` | `d:ri a:ri b:ri` | shift left, logical right, arithmetic right by the second operand (0 … 63) |
| `bnot` | `d:ri a:ri` | 1 if the operand is 0, else 0 |
| `icmp` | `cc:cc d:ri a:ri b:ri` | 1 if the signed comparison holds, else 0; cc `eq ne lt le gt ge` |
| `isel` | `d:ri c:ri a:ri b:ri` | d = a if c ≠ 0, else b |
| `fsel` | `d:rf c:ri a:rf b:rf` | the same for `f64` |
| `psel` | `d:rp c:ri a:rp b:rp` | the same for addresses |
| `rcount` | `d:ri e:ri lo:ri hi:ri st:ri incl:u site:site` | for the range `lo..hi step st` (incl 0) or `lo..=hi step st` (incl 1), LANGUAGE.md §5.1, whose exact number of elements n is 0 … 2⁶⁴: `e` = 1 if n > 0, else 0; `d` = (n − 1) mod 2⁶⁴ as an unsigned 64-bit value when n > 0 (the `last` of a `loop` over the range; a full-range loop such as `-2^63..=2^63-1` has n = 2⁶⁴ and `d` = 2⁶⁴ − 1), and `d` = 0 when n = 0 (the empty range); `st` = 0 is `range step is zero`, checked before anything is written |
| `fadd fsub fmul fdiv` | `d:rf a:rf b:rf` | one IEEE binary64 operation, round to nearest even (LANGUAGE.md §6.8) |
| `fneg fabs` | `d:rf a:rf` | flip / clear the sign bit |
| `fsqrt` | `d:rf a:rf` | correctly rounded square root |
| `fmin fmax` | `d:rf a:rf b:rf` | LANGUAGE.md §10.4: if one operand is NaN the other; of equal operands the first (`fmin(-0, +0)` is −0) |
| `ffloor fceil ftrunc fround` | `d:rf a:rf` | LANGUAGE.md §6.7; `fround` ties away from zero |
| `fcmp` | `cc:cc d:ri a:rf b:rf` | IEEE comparison: with a NaN operand only `ne` gives 1 |
| `fnan` | `d:ri a:rf` | 1 if the operand is NaN |
| `itof` | `d:rf a:ri` | `i64` → `f64`, round to nearest even |
| `ftoi` | `d:ri a:rf site:site` | `f64` → `i64` if integral and in range, else `conversion to i64` (LANGUAGE.md §4.2) |
| `padd` | `d:rp a:rp b:ri` | address plus a byte offset |
| `ldi ldb` | `d:ri base:rp idx:ri? scale:u off:i` | load from base + idx·scale + off (idx `-`: 0): 8-byte `i64`; 1 byte zero-extended |
| `ldf` | `d:rf base:rp idx:ri? scale:u off:i` | load an `f64` |
| `ldp` | `d:rp base:rp idx:ri? scale:u off:i` | load an address |
| `ldx` | `d:rx base:rp idx:ri? scale:u off:i` | 2 consecutive `f64`, lane 0 at the lowest address |
| `ldy` | `d:ry base:rp idx:ri? scale:u off:i` | 4 consecutive `f64` |
| `ldm2 ldm4` | `d:rm base:rp idx:ri? scale:u off:i` | 2 or 4 consecutive `bool` bytes as mask lanes |
| `sti stb` | `s:ri base:rp idx:ri? scale:u off:i` | store 8 bytes; store the low byte |
| `stf` | `s:rf base:rp idx:ri? scale:u off:i` | store an `f64` |
| `stp` | `s:rp base:rp idx:ri? scale:u off:i` | store an address |
| `stx` | `s:rx base:rp idx:ri? scale:u off:i` | store 2 lanes |
| `sty` | `s:ry base:rp idx:ri? scale:u off:i` | store 4 lanes |
| `stm2 stm4` | `s:rm base:rp idx:ri? scale:u off:i` | store mask lanes as bytes 0/1 |
| `xadd xsub xmul xdiv xmin xmax` | `d:rx a:rx b:rx` | lane by lane, each lane exactly the scalar instruction of the same name |
| `xneg xabs xsqrt xfloor xceil xtrunc xround` | `d:rx a:rx` | lane by lane |
| `xcmp` | `cc:cc d:rm a:rx b:rx` | lane by lane `fcmp` into a 2-lane mask |
| `xsel` | `d:rx m:rm a:rx b:rx` | per lane: the first vector where the mask lane is set, else the second |
| `xsplat` | `d:rx a:rf` | every lane = the scalar |
| `xlane` | `d:rf a:rx k:u` | lane k |
| `yadd ysub ymul ydiv ymin ymax` | `d:ry a:ry b:ry` | as the `x` forms, with 4 lanes |
| `yneg yabs ysqrt yfloor yceil ytrunc yround` | `d:ry a:ry` | as the `x` forms, with 4 lanes |
| `ycmp` | `cc:cc d:rm a:ry b:ry` | into a 4-lane mask |
| `ysel` | `d:ry m:rm a:ry b:ry` | as `xsel` |
| `ysplat` | `d:ry a:rf` | as `xsplat` |
| `ylane` | `d:rf a:ry k:u` | as `xlane` |
| `mand mor` | `d:rm a:rm b:rm` | lane-wise mask logic |
| `mnot` | `d:rm a:rm` | lane-wise negation |
| `vfeat` | `d:ri f:feat` | 1 if the selected kernel variant (§4.4) is `avx2` (feat `avx2`; `x86_64-linux` only) |
| `loop` | `b:blk ind:ri start:ri last:ri step:ri` | a counted loop that runs at least once: start, last and step are read once on entry; for k = 0 … last inclusive, k and last compared as unsigned 64-bit values (last + 1 iterations, up to 2⁶⁴), the body runs with `ind` = start + k·step computed modulo 2⁶⁴ (two's complement); the body never writes `ind`; an empty range is excluded by an enclosing `if` on `rcount`'s flag (§3.6.6 rule 4) |
| `endloop` | `b:blk` | the end of loop `b`: if k = last the loop ends, else k + 1 and the body runs again |
| `do` / `enddo` | `b:blk` | a loop left only by `exit`, and its end |
| `if` / `ifz` | `b:blk c:ri` | the first part runs if the register is not 0 (`if`) or is 0 (`ifz`), the `else` part otherwise |
| `else` / `endif` | `b:blk` | the start of the `else` part, the end of the construct |
| `exit` / `next` | `b:blk` | leave loop `b` / start its next iteration (`loop`: as at `endloop`, so `next` after k = last ends the loop; `do`: the top) |
| `ret` | `n:u v:reg*n` | return the results |
| `call` | `name:s nr:u d:reg*nr na:u a:reg*na` | call a Sea function; nr is the callee's result count, or 0 to discard its results |
| `rcall` | `entry:s site:site? nr:u d:reg*nr na:u a:reg*na` | call a runtime entry point, named as `rt.inc` lists it (§4.8); `site` for entries that can fail (allocation, I/O, the checks of library functions) |
| `chkb` | `idx:ri ext:ri dim:u site:site` | if idx < 0 or idx ≥ ext: `index … out of bounds for dimension … of extent …` (LANGUAGE.md §5.4) with idx, `dim` and ext; `dim` counts from 0 (LANGUAGE.md §5.4): 0 for the rows (or a vector's only dimension), 1 for the columns, printed as is |
| `chk` | `c:ri err:s site:site n:u a:reg*n` | if c ≠ 0, stop with the run-time error whose code name in `errors.inc` is `err`, the arguments substituted |
| `retain` / `release` | `a:rp` | count one more / one fewer reference to a runtime object; `release` frees it at zero (§4.2) |

The `off` field of the loads and stores is any `i64` value (field kind `i`, §3.1); passes 3b and
4 hold it as four 16-bit limbs, not as an entry of the `C` table (which holds only the `li`/`lf`
constants that the immediates limit counts, §2.7), so no 2⁵³ bound applies to it.

Blocks (`loop`, `do`, `if`, `ifz`) are numbered per function from 1 in the order of their opening
records and nest properly; `exit`/`next` name an enclosing `loop` or `do`.

**Sites.** An instruction's site is the file index and line of the position of the
HIR node whose check or call it implements. **Code from the prelude** never reports a prelude
line: pass 3a inlines every call of a prelude function, at every call site and recursively (the
prelude has no recursion), in addition to the calls LANGUAGE.md §8.6 requires, so no prelude
function is a LIR function; and in code inlined from the prelude every site is the site of the
call in the program's file into which it was (transitively) inlined. A run-time error inside
`bincount`, for instance, reports the line of the program's `bincount(…)` call, as
LANGUAGE.md §9.2 requires (`<file>` is the program's file). Code inlined from the program's own functions
keeps its own sites.

**Reproducibility is in the instruction set** (LANGUAGE.md §6.8): there is no fused multiply-add
and no instruction that rounds twice or not at all; every `fadd fsub fmul fdiv fsqrt` and vector
lane is one correctly rounded IEEE operation; no pass reorders `f64` operations except by moving
whole instructions without changing which operands they read; pass 4 maps each such instruction
to exactly one machine instruction of the same operation (never contracting two into an FMA).

#### 3.6.5 `sea.lir1` and `sea.lir` compared

Both use the records above. `sea.lir1` (pass 3a) uses only the classes `i`, `f`, `p` and no
`ldx ldy ldm2 ldm4 stx sty stm2 stm4 x… y… m… vfeat`; it keeps every bounds check, COW check and
stack slot pass 3a emits. `sea.lir` (pass 3b) may in addition contain the vector classes and
instructions (vectorized loops, §5.1; on `x86_64-linux` each vectorized loop in an `if` on
`vfeat` with the 4-lane form first and the 2-lane form in the `else` part, §4.4), and it has
fewer or hoisted checks, fewer slots (scalar replacement) and hoisted or strength-reduced
instructions (§5.2–§5.3).

**Pass 3b in phase 1** (§8). Pass 3b reads `sea.lir1` completely and validates it (the header
records and `#end`, every record against `passes.txt`, register classes and the numbering of
§3.6.1, block numbering and nesting, slots, data labels and their records) and writes it
unchanged as `sea.lir`; it transforms nothing. The validation also covers: the parameter
registers of each `func` record (numbered 1 … np in order, §3.6.1); every `ret` against its
`func` (n = the function's nr, each value of the result's class; `.main` returns 0); every
`call` (a `func` of that name exists, na = its np with each argument of its parameter's class,
nr = its nr or 0, each result register of the result's class); the `u` fields that encode a
choice (`incl` of `rcount` and `dim` of `chkb`: 0 or 1); each `chk` (n = the number of argument
slots that the `args` letters of the error `err` need, §2.6.2); no instruction inside a `loop`
writes its `ind`; exactly one `func` of kind `main`, named `.main`; each `fconv` (class `p`
exactly for `s`, `i` or `f` for the numeric conversions); every `la` names a data label the
file defines (labels are `d1`, `d2`, …: `d0` is never one); no two `func` records have the same
name. Any violation is `BAD_RECORD`. The transformations of §5.2–§5.3 and §5.1 arrive
in phases 5 and 7. So that the phase-1 `.lir` dump tests stay valid after them, they use only
programs on which the complete pass 3b changes nothing either: no loop-invariant instruction in a
loop, no array access or removable check, no slot that §5.3 could scalar-replace (the slots of
phase 1, rules 8 and 12 below, escape to a call), no address to strength-reduce and nothing to
vectorize.

#### 3.6.6 Canonical lowering of scalar code

So that LIR dumps are reproducible, pass 3a lowers the scalar subset (scalar `i64`, `f64` and
`bool` parameters, locals and results; constants, `lv`, `cvt`, `un`, `bin` on scalars, `ifx`,
`seq`, calls, `rarg` of a scalar local, `bind`, `tbind`, `eval` of a call, `asg` to a local, `if`,
`while`, `forr`, `break`, `cont`, `ret`, `tret`, `block`; the library calls `printf`, `now`, `f64`,
`i64` and `idiv` and string constants as `printf` arguments; from phase 3 the elementary functions
`log exp sin cos pow hypot` and `bin pow`, rule 14) exactly as follows; pass 3a inlines
exactly the calls LANGUAGE.md §8.6 requires and the calls of prelude functions (§3.6.4, "Sites"),
and no others.

**Inlining is deferred to phase 6** (§8). The phase-1 to phase-5 pass 3a inlines no call (the
performance guarantee of LANGUAGE.md §8.6 is not observable in a program's output, and the prelude
has no functions before phase 4, §2.5). The canonical LIR form of an inlined call is fixed in this
section, with its dump tests, by phase 6; until then the dump tests use only programs in which
LANGUAGE.md §8.6 requires no inlining (no function called from exactly one call site, none that
rule (c) covers, no elemental function).

1. Each local and parameter has one register of its class. Expressions are lowered in post-order,
   left operand first, one instruction per node, except: `lv` emits nothing (its register is the
   operand); `ci`/`cb` emit `li` and `cf` emits `lf`, a new register for every occurrence; `cvt`
   is `itof`; `i64` `add sub mul` are `iaddc isubc imulc` and `un neg` is `inegc`, with the
   node's line as site; `f64` arithmetic and `un neg` are `fadd fsub fmul fdiv fneg`;
   comparisons are `icmp`/`fcmp`; `un not` is `bnot`; `bin band` and `bin bor` (`&`, `|` on
   `bool`) are `iand` and `ior`.
2. **Destinations.** An instruction's destination is a new register, except that when a value is
   stored into a local L (`bind`, `tbind`, `asg` to `lv L`), the instruction computing the root
   of the value writes L's register directly; a root that is `lv M` becomes `mov L M`. `asg op`
   with op ≠ `set` to `lv L` is the instruction for `L op value` with L's register as
   destination and first operand. A root that is an `ifx`, `and` or `or` is the exception: it is
   computed into its new register R (rule 3) and then copied with `mov L R`, so that L still
   holds its old value while the operands are evaluated. `tbind` and `tasg` give the call the
   registers of their target locals as result registers, and a new register for each `-` or
   `skip` (`_`). A read of a `ref` parameter P (rule 12) whose value is stored straight into a
   local L, or is an operand or arm with destination R (rule 3), is its `ldi`/`ldf` with L or R
   as destination. An `asg` with op `set` to a `ref` parameter P computes the value into a new
   register V by the same rule (a root that is `lv M` of a plain local becomes `mov V M`), then
   `sti`/`stf V P - 0 0`. **`tasg`** `(t1, …, tn) = call` is lowered exactly as: (a) the call's
   arguments left to right (rules 5 and 12); (b) `call` with one result register Ri per component
   i: the register of the target local L when ti is a local, its `cv` is 0 and the call does not
   pass L by `ref`, otherwise a new register of result i's class (for `skip`, for a target that
   is a `ref` parameter, for a component with `cv` 1 (an `i` register), and for a local the call
   passes by `ref`); (c) the reloads of rule 12, in argument order; (d) for each component i in
   order that got a new register, except `skip`: if its `cv` is 1, `itof F Ri` into a new
   register F and V = F, else V = Ri; then `mov L V` for a local L, or `sti`/`stf V P - 0 0` (by
   V's class) for a `ref` parameter P. So in `.main`, `var a = 0.0`, `var b = 0`, `(a, b) =
   two()` with `two` returning `(i64, i64)` is `lf f1 #0000000000000000`, `li i2 0`, `call two 2
   i3 i2 0`, `itof f4 i3`, `mov f1 f4`.
3. `a && b` and `a || b`: a new register R; a with destination R; then `if B R` (for `&&`) or
   `ifz B R` (for `||`), b with destination R, `endif B`. `ifx c a b`: c, then `if B c`, a with a
   new destination R, `else B`, b with destination R, `endif B`. "With destination R" follows
   rule 2: an operand or arm whose root is a constant is its `li`/`lf` into R directly, one that is
   `lv M` is `mov R M`, any other root's instruction writes R. An `&&`, `||` or `ifx` that itself
   has a destination which is not a local (it is an operand or arm with destination R′ of an
   enclosing `&&`, `||` or `ifx`) uses R′ as its R: no new register and no `mov`.
4. `if c then [else]`: c, `if B c`, then, [`else B`, else], `endif B`. `while c body`: `do B`,
   c, `ifz B2 c`, `exit B`, `endif B2`, body, `enddo B`. `forr L (rng lo hi [st])`: lo, hi, then
   st or (if absent) `li` 1, then `rcount C E lo hi st incl site` (C and E new registers, in that
   order; site the `for` line), `if B E`, `loop B2 L lo C st`, body, `endloop B2`, `endif B`, so
   the `if` is block B and the `loop` block B2 = B + 1. `break` is `exit` and `cont` is `next` of
   the innermost loop (B2 of its `forr`).
5. Calls: the arguments left to right, then `call` with the result registers (rule 2); `eval` of
   a call with results uses nr 0. `ret k` is `ret k` of the values' registers. `tret`: the call
   with a new register for each result, then `ret` of those registers in order. `seq`: its `bind`
   nodes in order (rule 2), then its value, which is lowered as if it stood in the `seq`'s place.
6. A function whose result type is `void` ends with `ret 0` unless its last statement is a
   `ret`; `.main` always ends with `ret 0`. A function with results gets nothing after its last
   statement (LANGUAGE.md §8.1 guarantees that every path returns): when that statement is an
   `if` with `else` whose branches all return, the body ends with its `endif` and the `endfunc`
   follows, and pass 4 emits no code after the construct. `block` emits nothing for scalar
   locals.
7. **String constants.** A `cs` (in phase 1 only as the argument of a `%s` conversion of
   `printf`, §8) is a `str` data record `str dN v` (a new label for every occurrence, §3.6.2) and
   `la P dN` into a new register P.
8. **`printf`.** `lib printf` with its `fmt` of n conversions: the arguments of the conversions,
   left to right, each by rule 1; then `sa S s` of a new slot s of 8·max(n, 1) bytes, alignment
   8; then for each argument j (from 0) its store into slot word j: `sti`, `stf` or `stp` (by the
   argument's class) `value S - 0 8j`; then `la F dM` of a `fmt dM k` data record, k the number
   of the format's pieces (`ftext` and `fconv` records, §3.6.2), whose records are those pieces in
   order (each `fconv` with the class of its
   argument: `i` for `i64` and `bool`, `f` for `f64`, `p` for `str`); then `rcall sea_printf
   site 0 2 F S`, with the `printf` call's line as site (§4.8: pass 4 adds the site index as the
   entry's last argument).
9. **`now`.** `lib now` is `rcall sea_now - 1 R 0` into a new register R (`f`).
10. **Conversions.** `lib f64(x)`: `itof` for an `i64` or `bool` x, `mov` for an `f64` x; `lib
    i64(x)`: `ftoi` with the call's line as site for an `f64` x, `mov` for an `i64` or `bool` x.
11. **Integer division.** `lib idiv(a, b)` is `idivf` and `bin mod` of two `i64` is `imodf`, each
    with the node's line as site.
12. **`ref` arguments.** A `rarg` of a local L of the caller that is not itself a `ref` parameter:
    when the argument is reached in the left-to-right order, `sa A s` of a new slot s of 8 bytes,
    alignment 8, and `sti`/`stf L A - 0 0` (L's current value); A is the argument; after the
    `call`, for each such argument in argument order, `ldi`/`ldf L A - 0 0` reloads L. A `rarg` of
    a local that is a `ref` parameter of the caller passes that parameter's `p` register
    unchanged (no slot, no store, no reload). In the callee a `ref` parameter's register is a `p`
    (§3.6.3): a use of it is `ldi`/`ldf` into a new register from `P - 0 0`, and a store into it
    (`asg`, rule 2) computes the value into a new register and writes it with `sti`/`stf V P - 0
    0`. For `asg op` the parameter's current value is loaded first (it is the left operand,
    LANGUAGE.md §6.8 rule 5), then the value is computed, then the operation into a new register,
    then the store.

    **Reads before a `ref` call.** Within one statement, a read of a local L that is evaluated
    (in the order of LANGUAGE.md §6.8 rule 5) before a `call` that passes L by `ref`, or passes
    a `ref` parameter that aliases L, is copied at its evaluation point into a new register T
    (`mov T L`; for a `ref` parameter, its `ldi`/`ldf` writes T), and the later use reads T.
    This covers `y = x + g(ref x)`, `f(x, g(ref x))` and `x += g(ref x)` (the read of x by `+=`
    precedes the call). A read evaluated after the call sees the updated value. In `x = g(ref
    x)` (an `asg`, `bind` or `tbind` whose value is a call that passes the target by `ref`) the
    call writes a new result register R, then the reloads above follow, then `mov x R`, so the
    assignment wins over the reload. The copy is made for every such read of the statement,
    whichever `&&`, `||` or `ifx` arm it is in and whichever arm holds the call.
13. **Constant exponents.** `powk k` lowers its base x first, then into a new destination d (or
    the destination of rule 2): k = 0 `lf d 1.0`; k = 1 `mov d x`; k = 2 `fmul d x x`; k = 3
    `fmul t x x`, `fmul d t x`; k = 4 `fmul t x x`, `fmul d t t` (t a new register). For k < 0,
    x^|k| is computed as above into a new register t (t is x itself when |k| = 1), then `lf o
    1.0` into a new register o and `fdiv d o t`.
14. **Elementary functions** (phase 3, §4.10.5). The arguments are lowered left to right by rule
    1, then one `rcall` into a new register d of class `f` (or the destination of rule 2), with no
    site: `lib log(x)` is `rcall sea_log - 1 d 1 x`, and `lib exp`, `lib sin`, `lib cos` the same
    with `sea_exp`, `sea_sin`, `sea_cos`; `lib pow(x, y)` and `bin pow x y` (a `^` that is not a
    `powk`) are `rcall sea_pow - 1 d 2 x y`; `lib hypot(x, y)` is `rcall sea_hypot - 1 d 2 x y`.

Slots are numbered `s1`, `s2`, … in the order of their `sa` (rules 8 and 12), and their `slot`
records come at the start of the function in that order (§3.6.3).

The lowering of arrays, strings beyond rule 7, structs, the rest of the output library and
fusion is given by §4 and §5; its dumps are fixed when the phases that implement them add their
tests (§6.2, §8).

#### 3.6.7 Example

```sea
fn tri(n: i64, x: f64) -> f64 {
    var s = 0.0
    for i in 0..n {
        s = s + x * i
    }
    return s
}
let a = tri(10, 0.5)
let b = tri(4, a)
```

`tri` has two call sites and a loop, so it is not inlined (LANGUAGE.md §8.6).
`sea build --emit lir1 --no-prelude lx.sea`:

```
#sea 1
#target arm64-macos
#file lx.sea
func .main main 0:1:1 0 0
li i1 10
lf f2 #3FE0000000000000
call tri 1 f3 2 i1 f2
li i4 4
call tri 1 f5 2 i4 f3
ret 0
endfunc
func tri fn 0:1:1 2 i1 f2 1 f
lf f3 #0000000000000000
li i4 0
li i5 1
rcount i6 i7 i4 i1 i5 0 0:3
if 1 i7
loop 2 i8 i4 i6 i5
itof f9 i8
fmul f10 f2 f9
fadd f3 f3 f10
endloop 2
endif 1
ret 1 f3
endfunc
#end
```

`sea build --emit lir --no-prelude lx.sea` is identical: there is no array access (no bounds
check to remove), no instruction in the loop whose operands are all defined outside it (each reads
`i8`, `f9`, `f10` or `f3`), no addressing to strength-reduce, no slot to scalar-replace and no array
loop to vectorize, and LANGUAGE.md §6.8 forbids rewriting `s + x * i` in any other form.

### 3.7 Numbers of records

Opcode numbers are fixed in `passes.txt` (§3.9), separately for `sea.ast`, for the HIR files and
for the LIR files. They do not appear in the files, which use the opcode names; a pass maps names
to numbers with its generated `DATA` table, so a pass dispatches on a number with `ON … GO TO`
(Baysick LANGUAGE.md §7.17).

### 3.8 Dump tests

`sea/tests/passes/NAME.sea` with `NAME.ast`, `NAME.res`, `NAME.hir1`, `NAME.hir`, `NAME.lir1` and/or
`NAME.lir` (§6.2): the runner, in `sea/tests/passes/`, runs `sea build --emit X --no-prelude
NAME.sea` for each expected file present and compares the output byte for byte. The examples of
§3.4, §3.4.1, §3.5.8 and §3.6.7 are the first such tests (`ex`, `rs`, `lx`). As for every test, the expected
dumps are derived by hand from this section, never from what a pass writes (§6.1).

### 3.9 `passes.txt`

`sea/include/passes.txt` lists every header record and every record of the three formats with its
opcode number, the number of nodes it pops and its fields. It is a contract file (§2.6): it
changes only together with this section, and a test checks that the two agree in every record
name, pop count and field (the opcode numbers exist only in `passes.txt`, §3.7): `make
check-contracts` (§6.2) compares every `head` and `rec` line with the tables of §3.2–§3.6, whose
"Fields" cell (its first `code` span) is the field list in the notation of §3.1 and whose "Pops"
cell (where the table has one; else 0) starts with the pop expression below. Its format:

* Lines of at most 255 bytes, each ended by LF, only bytes `0x20`–`0x7E`, fields separated by
  one space, no leading or trailing space (so a Baysick program reads it with `LINPUT #k` and
  splits it with `POS`).
* An empty line, or a line whose first byte is `;`, is a comment. No other comment form exists;
  in particular `#` never starts a comment (it is the header-record prefix of the formats
  themselves, and occurs in `passes.txt` nowhere).
* `enum <name> <word> …` defines an enumeration: a field of type `<name>` holds one of the words.
* `head <name> <field> …` defines the header record written `#<name>` (§3.2).
* `rec <set> <code> <op> <pops> <field> …` defines a record:
  * `<set>`: `A` (`sea.ast` and `sea.res`: codes 1–49 in both, codes 50–63 only in `sea.res`,
    §3.4.1), `H` (both HIR files), `H1` (`sea.hir1` only), `HF` (`sea.hir`
    only), `L` (both LIR files), `LF` (`sea.lir` only);
  * `<code>`: its opcode number, unique within `A`, within `H H1 HF`, and within `L LF`;
  * `<pops>`: the number of nodes it pops: a sum of terms joined by `+` (no spaces), each a
    decimal number or the name of one of its `u` fields; `0` for LIR records and records that are
    not nodes;
  * `<field>`: `name:type`, where type is a field type of §3.1 (`u i f s pos site fl`, a reference
    type `ty lid fid cid iid blk lab slot`, a register type `reg` (any class) or `ri rf rp rx ry
    rm`, or an enumeration name), then optionally `?` (the field may be `-`), then optionally `*`
    and the name of an earlier `u` field (the field is repeated that many times); both may occur
    together, in this order (`lid:lid?*n`).
* Records are listed per file in the order of the tables of §3.4–§3.6. The sub-records that
  follow another record (`fd`, `par`, `loc`, `ftext`, `fconv`, `dvi`, `dvf`) are ordinary `rec`
  lines; where they may appear is stated in this section.

## 4. Runtime

`libsea.a`, hand-written assembly per target (`sea/runtime/arm64_macos/`,
`sea/runtime/x86_64_linux/`), in Baysick's style (CLAUDE.md "Assembly style"; module prefix
`_sea_`), linked with libSystem / glibc for the system interface (`write`, `open`, `mmap`,
`clock_gettime`, `snprintf` for exact number conversion), and with Baysick's runtime archive for
the GEMM kernel (§4.3). No other dependency.

### 4.1 Memory layout and allocation

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
* Allocation failure → `out of memory` (LANGUAGE.md §9.2).
* **Fixed-size arrays and structs** are inline: in registers, in the stack frame, or inside a
  containing array or struct.

### 4.2 Ownership and the cost model

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

### 4.3 Kernels, and what is shared with Baysick

**Linking.** Sea programs link Baysick's own `libbaysickrt.a`. Its kernel files (`rt_kinit.s`,
`rt_k*.s`) reference no symbol outside themselves except libc (Baysick DESIGN.md §6.6.1, "link
isolation"), and the linker pulls an archive member only for an undefined symbol: Sea's runtime
defines its own `main`, so only `rt_kinit.o` and the `rt_k*.o` objects are loaded (plus `getenv`,
`strcmp`, `sysctlbyname` from libc). No separate kernel archive is needed. A Sea build test
checks the link map, so a future Baysick change that broke this would be caught.

**What Sea uses from Baysick: the GEMM kernel only**, through `_bsk_kern_gemm`, plus the
dispatch entry points (`_bsk_kern_init`, `_bsk_kern_features`, `_bsk_kern_use`,
`_bsk_kern_variants`). Element-wise operations, copies, fills and transposes are Sea's own fused
loops (§5.1), so Baysick's `add`/`sub`/`scale`/`copy`/`fill`/`trn` kernels are not used, and
neither is its Gauss–Jordan `inv`.

**Why GEMM cannot be used unchanged** (Baysick DESIGN.md §6.6.1): `_bsk_kern_gemm` computes only
`C = A·B` (no accumulation, no α/β), so it cannot do the trailing update `C ← C − A·B` of a
blocked LU or Cholesky; its preconditions require every input element to be finite and every
extent ≥ 1, while Sea arrays may hold ∞/NaN and may be empty. Sea handles this as follows
(Decision 5 in §9 chose this over owning a GEMM in Sea):

* **Empty operands** never reach a kernel: Sea's runtime returns the zero matrix of the result
  shape for an empty inner dimension, and an empty result for an empty outer one.
* **Baysick's kernel contract grows** (a runtime change in Baysick, not a language change,
  §7): (a) an update entry `_bsk_kern_gemm_sub(C, A, B)` computing `C ← C − A·B` with the same
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
class-E order (LANGUAGE.md §10.8); LU with partial pivoting and Cholesky (panel factorization in Sea's
kernel, trailing updates through `_bsk_kern_gemm_sub`); triangular solves with many right-hand
sides; the `rcond` estimator; symmetric eigenvalues (tridiagonal reduction + implicit QL, small
sizes); radix sort with an index permutation; the scalar and vector forms of the elementary
functions.

### 4.4 CPU-feature dispatch

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

Because every class-E operation gives the same bits in every variant (LANGUAGE.md §6.8, LANGUAGE.md §10.5), the variant
changes speed, never output, except for class-R results.

### 4.5 Runtime services

| Area | Contents |
|------|----------|
| start-up | `main`: stack (§4.6), kernel selection (§4.4), stdout buffer, then the program's `_sea_main`; exit flushes |
| memory | allocate / free / count operations / COW copy; array constructors |
| errors | `_sea_err(code, site, argument slots)` (§4.8): LANGUAGE.md §9.2, with a site table (source file, line) emitted by pass 4 |
| strings | concatenation, comparison, `lower` |
| formatting | the pre-parsed `printf` engine (LANGUAGE.md §11.1): integers by own code; finite `f64` through `snprintf` with a built single-conversion format; NaN/Inf and `%d`-on-`f64` per MATLAB |
| JSON | the emitter that `write_json` expands into (LANGUAGE.md §11.4), with `%.17g` numbers, a 64 KiB buffer |
| plotting | `Figure`/`Axes` objects, layout, SVG writer, PNG (stored deflate, CRC-32, Adler-32) and base64 (LANGUAGE.md §12) |
| I/O | buffered stdout/stderr; `make_dir`; errno → fixed message table |
| clock | `now()` via `clock_gettime(CLOCK_MONOTONIC)` |
| math | `log exp sin cos pow hypot`, scalar and vector forms with identical results (Decision 6): table-driven range reduction and polynomials, one algorithm for both targets, using only IEEE `+ − × ÷ sqrt` and exact integer operations (no FMA, which SSE2 lacks — the cost is part of Decision 1), verified ≤ 1 ulp against high-precision references (§6.2); the exact algorithms, tables and entry points are §4.10; `round` on x86_64 (LANGUAGE.md §6.7) |
| sort | radix sort of `f64`/`i64`/`str` keys with stable permutation |
| linear algebra | §4.3 |

**Internal runtime symbols (not contract).** Inside `libsea.a` the runtime files share helper
symbols with the `_sea_` prefix that compiled code never calls: in the phase-1 arm64 runtime
`_sea_out_write`, `_sea_out_repeat`, `_sea_out_bytes`, `_sea_out_flush` and `_sea_out_fail` (the
standard-output buffer), `_sea_write_all` (a complete `write`), `_sea_fmt_g` (`%g` text for
`_sea_err`'s `f` arguments) and `_sea_stdout_name` (the static string `<stdout>`). They are
documented in the runtime files' headers, may change without a contract change, and never
appear in `rt.inc` or in `sea.s`.

### 4.6 Stack and process

`main` runs the program on a 64 MiB stack mapped with a guard page (Baysick's program-stack
technique, Baysick DESIGN.md §6.9). **Stack overflow is detected by the compiled code**: before it
allocates its frame, every non-leaf function, and every leaf function whose frame is larger than
`SEA_STACK_LEAF_MAX` bytes, checks that its frame fits above `_sea_stack_limit` (the top of
the guard page plus `SEA_STACK_MARGIN`, set by `main` before `_sea_main`) without wrapping: it
computes sp − `_sea_stack_limit` and compares it with its frame size as unsigned values, a
borrow in the subtraction (sp already below the limit) counting as overflow; if the frame does
not fit, the
function calls `_sea_err(SEA_E_STACK_OVERFLOW, site)`, where site is the function's definition
line: the `F:L` of its LIR `func` record's `pos` (§3.6.3), which pass 4 adds to `_sea_sites`
(§4.8, §4.9). So `stack overflow` reports `<file>:<line>` of the `fn` whose call did not fit
(LANGUAGE.md §8.6, §9.2). The margin leaves room for unchecked leaf frames and for `_sea_err`
itself. The guard page stays as a safety net: an alternate signal stack and a `SIGSEGV`/`SIGBUS`
handler turn a fault in it into `stack overflow` with no location (`SEA_SITE_NONE`). Only a
fault counts: a `SIGSEGV`/`SIGBUS` whose `si_code` says it was sent by `kill`, `raise`,
`sigqueue` or the like (Linux: `si_code` ≤ 0; macOS: `si_code` ≤ 0 or ≥ `SI_USER` = 0x10001) is
never `stack overflow`, whatever its address. Such a signal, and a fault at any other address,
gets the default action at once: the handler resets the signal to `SIG_DFL`, unblocks it
(`sigprocmask(SIG_UNBLOCK, {sig}, NULL)`; it is blocked while its handler runs) and calls
`raise(sig)`, so the process dies by the signal (status 128 + sig through a shell, 139 for
`SIGSEGV`); should it survive the raise, the handler returns. Any other signal keeps its
default action. The rt tests `rt_main_segv_raise` (`raise(SIGSEGV)`),
`rt_main_segv_kill` (`kill(getpid(), SIGSEGV)`) and `rt_main_segv_other` (a fault outside the
guard page) expect status 139 with no output, on both targets. After
reporting `stack overflow`, the handler path ends the process with `_exit` (status 1), never
`exit`, so no `atexit` handler or library flush runs inside a signal handler. Programs ignore `SIGPIPE` and report a failed write as `cannot write`
(status 1): a failed write of standard output as `cannot write '<stdout>': <reason>`, at the site
of the output call whose buffer flush failed, or with no site (`SEA_SITE_NONE`, §4.8) when the
final flush after `_sea_main` returns fails (LANGUAGE.md §9.2). A write that fails with `EAGAIN`
(standard output set non-blocking by the caller) is not a failure: the runtime waits with
`poll(POLLOUT)` and retries. While `_sea_err` reports a run-time error, a failure of the flush of
step 1 of LANGUAGE.md §9.2 is ignored: the original error's line is written and the status is 1.

### 4.7 Two targets, one behaviour

The two runtimes implement the same entry points with the same results, as Baysick's do
(arm64-macos native, x86_64-linux cross-compiled and tested on the Linux host). Everything a
program prints is byte-identical on both targets except class-R values (§6.6).

#### 4.7.1 The x86_64-linux runtime

`runtime/x86_64_linux/` holds the same files as the arm64 runtime (in phase 2 `rt_main.s`,
`rt_out.s`, `rt_err.s`, `rt_fmt.s`, `rt_clock.s`) with the same entry points, the same internal
helpers (§4.5, under their ELF names), the same algorithms, buffers and texts, so every byte a
program writes and every exit status are those of the arm64 runtime (§4.7). Its style is
Baysick's x86_64 runtime style (Baysick DESIGN.md §6.4.4): GNU `as` ≥ 2.38, AT&T syntax, `#`
comments, 4-space indent, assembled with `as --64 --fatal-warnings -I include -I
<baysick>/include` (Sea's contract files, then Baysick's `runtime.inc` for the kernel entry
points); every file starts with its `.include` lines and ends with `.section
.note.GNU-stack,"",@progbits`; entry points are `.globl` + `.type <name>, @function`; the
internal helpers shared between files are `.globl` + `.hidden`; file-local labels are
`.Lrt_<file>_<function>_<what>`; the function header block of CLAUDE.md "Assembly style", in
System V terms. Code `.text` (`.p2align 4` per function), constants `.section .rodata`, tables
of pointers `.section .data.rel.ro,"aw",@progbits`, mutable state `.data`/`.bss`. Instruction set:
the x86-64 baseline (SSE2) only — no SSE3/SSE4.1 (`roundsd`), AVX, BMI or FMA — so the runtime
runs on any x86_64 machine (later kernel variant files may use what their variant guarantees,
§4.4). The calling convention is System V AMD64 (§4.8); the direction flag is clear and MXCSR
and the x87 control word are never changed.

**System interface.** glibc only (Sea's runtime calls no libm function),
always called through the PLT (`call write@PLT`), as Baysick's x86_64 runtime does
(Baysick DESIGN.md §6.4.3). The Linux values below are private to the runtime files (they are not
contract values and are not in `rt.inc`):

| Need | Call and Linux values |
|------|-----------------------|
| output | `write(fd, buf, len)`; errno through `__errno_location()` (returns `int *`); `EINTR` 4, `EAGAIN` 11; `poll(&pfd, 1, -1)` with `struct pollfd` {fd i32 at 0, events i16 at 4, revents i16 at 6}, `POLLOUT` 4 |
| termination | `_exit(status)` |
| number digits | `snprintf(buf, n, fmt, x)`: variadic, so `%al` = the number of vector registers used (`movl $1, %eax` for one `f64` in `%xmm0`) immediately before the call |
| clock | `clock_gettime(1, &ts)` (`CLOCK_MONOTONIC` 1; `struct timespec` {tv_sec i64 at 0, tv_nsec i64 at 8}) |
| program stack | `sysconf(30)` (`_SC_PAGESIZE`); `mmap(NULL, n, 3, 0x22, -1, 0)` (`PROT_READ\|PROT_WRITE`, `MAP_PRIVATE\|MAP_ANONYMOUS`), failure `(void *) -1`; `mprotect(base, G, 0)` |
| signals | `signal(13, (void *) 1)` (`SIGPIPE`, `SIG_IGN`); `sigaltstack(&ss, NULL)` with `stack_t` {ss_sp ptr at 0, ss_flags i32 at 8, ss_size u64 at 16; 24 bytes}; `sigaction(sig, &sa, NULL)` with glibc's `struct sigaction` {sa_sigaction ptr at 0, sa_mask 128 bytes at 8, sa_flags i32 at 136, sa_restorer ptr at 144; 152 bytes}, `sa_flags` = `SA_ONSTACK\|SA_SIGINFO` = 0x08000004, `sa_mask` empty; `SIGSEGV` 11, `SIGBUS` 7; the handler receives (sig, `siginfo_t *`, context) and finds `si_code` (i32) at offset 8 and the fault address `si_addr` at offset 16 of `siginfo_t`; `SIG_DFL` 0; `sigprocmask(1, &set, NULL)` (`SIG_UNBLOCK` 1; macOS 2) with a 128-byte `sigset_t` holding bit sig − 1; `raise(sig)` |
| kernels | `getenv("SEA_KERNELS")`; Baysick's `bsk_kern_init`, `bsk_kern_use`, `bsk_kern_variants` (§4.4), linked from Baysick's x86_64 `libbaysickrt.a` |
| memory | `memcpy`, `strlen` |

**Start-up** follows the arm64 `main` step by step (§4.5, §4.6): `main` is entered from glibc's
start code with `%rsp` ≡ 8 (mod 16) and pushes `%rbp` before its first call; it switches to the
new program stack by setting `%rsp` to its top (page-aligned), clears `%rbp` (`xorl %ebp,
%ebp`) and calls `sea_main` with `%rsp` ≡ 0 (mod 16). The `SIGSEGV`/`SIGBUS` handler runs on
the alternate stack; a fault address inside the guard page is `stack overflow` with no location
(`sea_err`, which flushes and ends with `_exit`); a sent signal (`si_code` ≤ 0) or a fault at
any other address is reset to `SIG_DFL`, unblocked and raised again, as §4.6 states.

**No `madvise`.** Baysick's x86_64 runtime calls `madvise(base, size + G, MADV_NOHUGEPAGE)` on its
program stack (Baysick DESIGN.md §6.9); Sea's runtime deliberately does not in phase 2. The call
changes only resident memory and start-up time on hosts with transparent huge pages set to
`always`, never output; it is revisited with benchmarks in phase 10 (§8).

**Kernel variant.** After the selection of §4.4 the runtime sets `sea_variant` from the selected
Baysick variant's name: `avx2` → `SEA_VAR_AVX2`; `sse2` and `baseline` (Baysick's x86_64
baseline is SSE2 code) → `SEA_VAR_SSE2`. Phase 2 emits no `vfeat`, so the value changes no
output.

**Identical output.** The digits of finite `f64` conversions come from glibc's `snprintf`
exactly as from libSystem's on the Mac: both print the exact decimal value of the binary64
argument, correctly rounded for every precision (ties by the default rounding mode), in the C
locale (the program never calls `setlocale`); the integer paths are Sea's own code on both
targets. Error texts come from `errors.inc` and errno texts from the errno table (§2.6.2), whose
`x86_64-linux` column maps the host value; a host errno outside the table prints id 0's text.
The cross corpus (§6.6.1) checks every byte.

**Build and tests on Linux.** `make -f Makefile.linux` builds `build-x86_64-linux/libsea.a` from
`runtime/x86_64_linux/*.s` (objects in `build-x86_64-linux/obj/`, `ar rcs`); Baysick's x86_64
runtime is built in the Baysick tree (or the bundle's copy of it) with Baysick's `make -f
Makefile.linux` (`build-x86_64-linux/libbaysickrt.a`). Runtime tests are
`tests/rt/x86_64_linux/NAME.s`: the x86_64 counterparts of `tests/rt/arm64_macos/` (an assembly
program defining `sea_main` and `sea_sites`), with the same sidecars and the same expected bytes,
except for these tests, whose subject is target-dependent by this section and §4.4:

* `rt_err_errno_darwin`, `rt_err_errno_linux` (in both directories): the errno table is the
  host's column (§2.6.2), so the host's own value prints its text and the other host's value
  for the same error, absent from this column, prints record 0's text (`unknown error`);
* `rt_main_kernel_baseline` (`SEA_KERNELS=baseline`): the selected variant's name and
  `sea_variant`, `kernel neon variant 1` on arm64 and `kernel sse2 variant 2` on x86_64
  (Baysick's x86_64 baseline reports `sse2`, mapped as above);
* `rt_main_kernel_default`, `rt_main_kernel_bogus` (no / an unknown `SEA_KERNELS`): arm64 has one
  variant and prints `kernel neon variant 1`; on x86_64 the best usable variant depends on the
  host CPU (`avx2` or `sse2`), so the test checks that the variant in use is the first of
  `bsk_kern_variants` and that `sea_variant` is its mapped id, and prints `kernel best variant ok`;
* `rt_main_state`: `sea_variant` must be `SEA_VAR_SSE2` or `SEA_VAR_AVX2` on x86_64
  (`SEA_VAR_NEON` on arm64); the output `state ok` is the same.

A `.meta` of an x86_64 runtime test holds only `stdout=epipe`, `stdout=slowpipe` and
`env=NAME=VALUE` lines, never `requires=fmt_g`: that key marks the arm64 tests that `run_rt.sh`
skips while `rt_fmt.s` lacks a real `_sea_fmt_g`, and the Linux archive always contains
`sea_fmt_g` (its absence is a setup error of `run_rt_linux.sh`), so `cross_run.sh` rejects any
other line (§6.6.1). They are assembled with the runtime flags,
linked as `gcc -no-pie -o prog NAME.o build-x86_64-linux/obj/rt_main.o build-x86_64-linux/libsea.a
<libbaysickrt.a> -lm` (`rt_main.o` explicit and first, as on the Mac) and run by
`tests/rt/run_rt_linux.sh` (`make -f Makefile.linux test-rt`), and by the cross run (§6.6.1).

### 4.8 Runtime ABI: what `rt.inc` holds

`sea/include/rt.inc` (§2.6) pins everything pass 4 (both code generators) and the two runtimes
share: the object layouts of §4.1, the layouts pass 4 emits for LIR data records (§3.6.2), the
symbols that connect a program to the runtime, the error-site table, the argument slots of
`_sea_err`, the kernel variant ids (§4.4), the Baysick version (§7.2), and the mapping of the
LIR calling convention (§3.6.3) to AAPCS64 and the System V AMD64 ABI. The entry points that
LIR `rcall` records name (§3.6.4: memory and array constructors, COW, strings, formatting, the
JSON emitter the `j*` records of §3.5 lower to, I/O, the clock, the elementary functions in
scalar and vector forms, sorting, linear algebra, plotting) are added to `rt.inc` and to this
section, under the contract rule, by the phase of §8 that implements each one, with their
arguments and failure codes.

§4.1 fixes the fields of the array and string headers in words; this section fixes every value
(agreed with `rt.inc` in phase 0, §0).

**Symbols.** Mach-O names; on `x86_64-linux` the ELF names drop the leading `_` (`main`,
`sea_main`, `sea_err`, `sea_sites`, `sea_variant`, `sea_stack_limit`, and the entry points
`sea_printf`, `sea_now`, `sea_log`, `sea_exp`, `sea_sin`, `sea_cos`, `sea_pow`, `sea_hypot`), as
Baysick's do.

| Symbol | Defined by | Contract |
|--------|------------|----------|
| `main` | runtime | process entry (§4.5): stack (§4.6), kernel selection (§4.4), stdout buffer, then `_sea_main`; when it returns, flushes and exits with `SEA_EXIT_RUN_OK`; if that final flush fails, it calls `_sea_err` with `SEA_E_CANNOT_WRITE`, site `SEA_SITE_NONE`, and the slots `<stdout>` (a static string) and the errno (LANGUAGE.md §9.2, §9.4) |
| `_sea_main` | program | the LIR function `.main`: no parameters, no result |
| `_sea_err` | runtime | noreturn run-time error (LANGUAGE.md §9.2): arm64 `x0` / x86_64 `%rdi` = the code (`SEA_E_*`, 1 … `SEA_E_RT_END` − 1), `x1` / `%rsi` = the site index into `_sea_sites`, or `SEA_SITE_NONE` for an error with no location (the line is then `error: <message>`, LANGUAGE.md §9.2), `x2` / `%rdx` = the address of the argument slots that the code's `args` letters describe (§2.6.2), unused when it has none; a code outside 1 … `SEA_E_RT_END` − 1 (a compiler bug) prints nothing and exits with status 1 |
| `_sea_sites` | program | the error-site table (below) |
| `_sea_variant` | runtime | u64: the `SEA_VAR_*` id of the selected kernel variant, set before `_sea_main`; LIR `vfeat avx2` is `_sea_variant == SEA_VAR_AVX2`; on `arm64-macos` always `SEA_VAR_NEON` (Baysick's `baseline` variant has no Sea id: Sea's own arm64 code is NEON only) |
| `_sea_stack_limit` | runtime | u64: the lowest address sp may reach, the top of the guard page plus `SEA_STACK_MARGIN`, set before `_sea_main`; read by the prologue check of §4.6 |

**Runtime entry points** (`SEA_ENTRY_LIST` in `rt.inc`; LIR `rcall` records name them by their
ELF symbol, and pass 4 writes the Mach-O name with a leading `_` on `arm64-macos`). "Site" `S`
means the entry can fail and pass 4 passes the site index of the `rcall` (§4.9) as one more, last,
integer argument; "Args" and "Results" are the LIR classes of the `rcall`'s arguments and
results, mapped by the calling convention below. `SEA_ENT_<NAME>` is the id; `SEA_ENT_COUNT` = 8.

| Id | Name | Symbol | Site | Args | Results | Contract |
|---:|------|--------|------|------|---------|----------|
| 1 | `PRINTF` | `sea_printf` | `S` | `pp` | `-` | `_sea_printf(fmt, slots, site)`: arm64 `x0` / x86_64 `%rdi` = the address of a pre-parsed format (`SEA_FMT_*`, below), `x1` / `%rsi` = the address of its argument slots (one `SEA_SLOT_SIZE` slot per conversion, in order: an `i64` or `bool` value, the bits of an `f64`, or a string object pointer, by the conversion's `SEA_CLS_*`), `x2` / `%rdx` = the site index; formats as LANGUAGE.md §11.1 says into the standard-output buffer (an `i` slot of an `f`/`F`/`e`/`E`/`g`/`G` conversion is converted to `f64` with round-to-nearest-even: pass 2a writes no `cvt` for a typed `i64` argument of those conversions, so its `fconv` has class `i`; the runtime trusts the compiler's checks of LANGUAGE.md §11.1 and does not re-check flags or classes); a failed write of the buffer is `_sea_err(SEA_E_CANNOT_WRITE, site, slots "<stdout>", errno)` (§4.6); no result |
| 2 | `NOW` | `sea_now` | `-` | `-` | `f` | `_sea_now()`: the monotonic clock (`clock_gettime(CLOCK_MONOTONIC)`) in seconds as an `f64` in `d0` / `%xmm0` (LANGUAGE.md §13); cannot fail |
| 3 | `LOG` | `sea_log` | `-` | `f` | `f` | `_sea_log(x)`: the natural logarithm, §4.10 (argument and result in `d0` / `%xmm0`, the clobbers of §4.10.1); cannot fail |
| 4 | `EXP` | `sea_exp` | `-` | `f` | `f` | `_sea_exp(x)`: eˣ, §4.10; as `LOG` |
| 5 | `SIN` | `sea_sin` | `-` | `f` | `f` | `_sea_sin(x)`: §4.10; as `LOG` |
| 6 | `COS` | `sea_cos` | `-` | `f` | `f` | `_sea_cos(x)`: §4.10; as `LOG` |
| 7 | `POW` | `sea_pow` | `-` | `ff` | `f` | `_sea_pow(x, y)`: xʸ, §4.10 (x in `d0` / `%xmm0`, y in `d1` / `%xmm1`, result in `d0` / `%xmm0`); cannot fail |
| 8 | `HYPOT` | `sea_hypot` | `-` | `ff` | `f` | `_sea_hypot(x, y)`: √(x² + y²) without undue overflow or underflow, §4.10; as `POW` |

| Name | Value | Meaning |
|------|------:|---------|
| `SEA_ENT_COUNT` | 8 | number of entry records |
| `SEA_STACK_MARGIN` | 65536 | bytes kept above the guard page: `_sea_stack_limit` = its top + this (§4.6) |
| `SEA_STACK_LEAF_MAX` | 4096 | a leaf function whose frame is larger is checked too (§4.6) |

**Reference-counted objects.** Every
array, string and handle begins with the same 16-byte header, so `retain`/`release` (§3.6.4) work on any of them. A count of `SEA_RC_STATIC` (0) marks a
static object (the string objects of LIR `str` records): `retain` and `release` leave it unchanged,
it is never freed, and it may live in read-only data; a dynamic object starts at count 1, and
`release` frees it at 0 (after releasing the objects it refers to: string elements, the reference
fields of struct elements, a handle's private references).

| Name | Value | Meaning |
|------|------:|---------|
| `SEA_OBJ_RC` | 0 | u64: reference count |
| `SEA_OBJ_TAG` | 8 | u8: `SEA_TAG_*` |
| `SEA_OBJ_HDR` | 16 | bytes of the common header; a handle's private layout follows it |
| `SEA_RC_STATIC` | 0 | the count of a static object |
| `SEA_TAG_ARRAY` | 1 | dynamic array |
| `SEA_TAG_STR` | 2 | string |
| `SEA_TAG_FIGURE` | 3 | `Figure` handle |
| `SEA_TAG_AXES` | 4 | `Axes` handle |
| `SEA_TAG_LU` | 5 | `Lu` handle |
| `SEA_TAG_CHOL` | 6 | `Chol` handle |

**Dynamic array header**, 64 bytes (§4.1). Element (i, j) of an r × c matrix is element i + j·r of
the buffer, at `DATA + ESIZE·(i + j·r)`; a vector has `COLS` = 1. Unused header bytes are 0.

| Name | Value | Meaning |
|------|------:|---------|
| `SEA_ARR_RC` | 0 | u64: reference count |
| `SEA_ARR_TAG` | 8 | u8: `SEA_TAG_ARRAY` |
| `SEA_ARR_EK` | 9 | u8: element kind `SEA_EK_*` |
| `SEA_ARR_RANK` | 10 | u8: 1 (vector) or 2 (matrix); bytes 11 … 15 are 0 |
| `SEA_ARR_ROWS` | 16 | u64: rows (a vector's length) |
| `SEA_ARR_COLS` | 24 | u64: cols; 1 for a vector |
| `SEA_ARR_CAP` | 32 | u64: capacity in elements, ≥ rows · cols |
| `SEA_ARR_DATA` | 40 | ptr: the buffer, `SEA_DATA_ALIGN`-aligned, column-major |
| `SEA_ARR_ESIZE` | 48 | u64: element size in bytes |
| `SEA_ARR_SLAY` | 56 | ptr: the struct layout descriptor for `SEA_EK_STRUCT`, else 0 |
| `SEA_ARR_SIZE` | 64 | header size |
| `SEA_DATA_ALIGN` | 64 | alignment of array buffers and of `dat` buffers |
| `SEA_EK_F64` | 1 | `f64` elements |
| `SEA_EK_I64` | 2 | `i64` elements |
| `SEA_EK_BOOL` | 3 | `bool` elements, one byte, 0 or 1 |
| `SEA_EK_STR` | 4 | `str` elements: string object pointers |
| `SEA_EK_STRUCT` | 5 | struct elements, inline (layout rule below) |
| `SEA_ESIZE_F64` | 8 | size of an `f64` |
| `SEA_ESIZE_I64` | 8 | size of an `i64` |
| `SEA_ESIZE_BOOL` | 1 | size of a `bool` |
| `SEA_ESIZE_PTR` | 8 | size of a `str`, dynamic array or handle value |

**Struct layout rule** (pass 3a's addressing, pass 4's descriptors and the runtime's copies agree
on it): fields in declaration order, each at the next offset that is a multiple of its alignment;
`f64`, `i64` and reference values (`str`, dynamic arrays, handles) have size 8 and alignment 8,
`bool` size 1 and alignment 1; a fixed-size array `T[n]` or `T[r,c]` is n or r·c elements of `T`
inline, column-major, with `T`'s alignment; a nested struct has its own size and alignment. A
struct's alignment is the largest of its fields' (1 if it has none) and its size is rounded up to
it. The same layout holds in stack slots and inside arrays.

**Struct layout descriptor**, read-only, emitted by pass 4 once per struct type that is the
element type of a dynamic array:

| Name | Value | Meaning |
|------|------:|---------|
| `SEA_SL_SIZE` | 0 | u64: struct size in bytes (= the array's `SEA_ARR_ESIZE`) |
| `SEA_SL_NREF` | 8 | u64: number of reference fields, those of nested structs and fixed-size arrays included |
| `SEA_SL_REFS` | 16 | u64 × `SEA_SL_NREF`: their byte offsets in the struct, ascending |

**String object** (§4.1). The static string objects pass 4 emits for LIR `str` records have count
`SEA_RC_STATIC` and live in read-only data, 8-byte aligned.

| Name | Value | Meaning |
|------|------:|---------|
| `SEA_STR_RC` | 0 | u64: reference count |
| `SEA_STR_TAG` | 8 | u8: `SEA_TAG_STR`; bytes 9 … 15 are 0 |
| `SEA_STR_LEN` | 16 | u64: length in bytes, 0 … `SEA_LIM_STR_BYTES` |
| `SEA_STR_BYTES` | 24 | the bytes, not NUL-terminated |

**Handles** (`Figure`, `Axes`, `Lu`, `Chol`): the common header (tag `SEA_TAG_FIGURE` …
`SEA_TAG_CHOL`), then a layout private to each runtime.

**Constant buffers** (LIR `dat` records): the n elements, contiguous, 8 bytes each for `i64` and
`f64` (the record's bit patterns) and 1 byte (0 or 1) for `bool`, in read-only data aligned to
`SEA_DATA_ALIGN`; no header.

**Pre-parsed formats** (LIR `fmt` records, LANGUAGE.md §11.1), read-only: a header and one piece
per `ftext`/`fconv` record, in order. A text piece points at its bytes (read-only, no NUL); a
conversion piece carries the letter, flags, width, precision and argument class of its `fconv`.

| Name | Value | Meaning |
|------|------:|---------|
| `SEA_FMT_NPIECE` | 0 | u64: number of pieces |
| `SEA_FMT_NCONV` | 8 | u64: number of conversion pieces (= arguments) |
| `SEA_FMT_PIECES` | 16 | offset of the first piece |
| `SEA_FP_KIND` | 0 | u8: `SEA_FPK_*` |
| `SEA_FP_CONV` | 1 | u8: the ASCII conversion letter (`d i f F e E g G s`); 0 for text |
| `SEA_FP_FLAGS` | 2 | u8: `SEA_FF_*` bits; 0 for text |
| `SEA_FP_CLS` | 3 | u8: `SEA_CLS_*` of the argument; 0 for text |
| `SEA_FP_WIDTH` | 4 | i32: width, −1 if absent (and for text) |
| `SEA_FP_PREC` | 8 | i32: precision, −1 if absent (and for text); bytes 12 … 15 are 0 |
| `SEA_FP_TEXT` | 16 | ptr: the text bytes (text pieces), else 0 |
| `SEA_FP_TLEN` | 24 | u64: number of text bytes (text pieces), else 0 |
| `SEA_FP_SIZE` | 32 | piece size |
| `SEA_FPK_TEXT` | 0 | a text piece (`ftext`) |
| `SEA_FPK_CONV` | 1 | a conversion piece (`fconv`) |
| `SEA_FF_LEFT` | `0x01` | flag `-` (`fl` letter `l`) |
| `SEA_FF_PLUS` | `0x02` | flag `+` (`p`) |
| `SEA_FF_SPACE` | `0x04` | flag space (`s`) |
| `SEA_FF_ZERO` | `0x08` | flag `0` (`z`) |
| `SEA_FF_ALT` | `0x10` | flag `#` (`a`) |
| `SEA_CLS_I` | 0 | LIR class `i` (`i64`, `bool`) |
| `SEA_CLS_F` | 1 | LIR class `f` (`f64`) |
| `SEA_CLS_P` | 2 | LIR class `p` (`str`) |

**Argument slots.** `_sea_err`, and every entry point that takes a variable list of arguments
(formatting), receives them as consecutive 8-byte slots in argument order, which the caller
builds in its frame: an `i64` value, the bits of an `f64`, or an object pointer. A shape (`args`
letter `h`) takes two slots: the rows, then the cols of a matrix or `SEA_SHAPE_VEC` for a vector.

| Name | Value | Meaning |
|------|------:|---------|
| `SEA_SLOT_SIZE` | 8 | bytes per slot |
| `SEA_SHAPE_VEC` | -1 | the second slot of a vector's shape |

**Error-site table** `_sea_sites`, read-only, emitted by pass 4: one record per distinct LIR site
`F:L` (§3.1), numbered from 0 in order of first occurrence in `sea.lir`; that number is the site
index passed to `_sea_err`, which prints `<file>:<line>: error: …` from the record.

| Name | Value | Meaning |
|------|------:|---------|
| `SEA_SITE_FILE` | 0 | ptr: a static string object holding the `#file` path of `F` (§3.2) |
| `SEA_SITE_LINE` | 8 | u64: the line `L`, from 1 |
| `SEA_SITE_SIZE` | 16 | record size |
| `SEA_SITE_NONE` | -1 | the site index of an error with no location (all bits set); `_sea_err` then prints `error: <message>` without `<file>:<line>: ` |

**Kernel variants** (§4.4). The ids of the variants Sea's runtime can select; their names are
Baysick's `KV_NAME`s, which `SEA_KERNELS` and `_bsk_kern_use` take.

| Name | Value | Variant | Target |
|------|------:|---------|--------|
| `SEA_VAR_NEON` | 1 | `neon` | arm64-macos |
| `SEA_VAR_SSE2` | 2 | `sse2` | x86_64-linux |
| `SEA_VAR_AVX2` | 3 | `avx2` | x86_64-linux |

**Baysick version** (§4.3, §7.2): Baysick 0.6.0, whose `libbaysickrt.a` and `include/runtime.inc` the
runtime is built and checked against. The GEMM update entry `_bsk_kern_gemm_sub` and IEEE
propagation of §7.2 landed in Baysick 0.6.0 (Baysick commit `4c9b87a`, 2026-10-20) without a
version change, so 0.6.0 with that commit or later is the version `rt.inc` names.

| Name | Value | Meaning |
|------|------:|---------|
| `SEA_BAYSICK_MAJOR` | 0 | Baysick major version |
| `SEA_BAYSICK_MINOR` | 6 | Baysick minor version |
| `SEA_BAYSICK_PATCH` | 0 | Baysick patch version |

**Calling convention** (§3.6.3) on each target. Runtime entry points follow the platform ABI
exactly (AAPCS64 in its Darwin variant; System V AMD64), whose register assignments are those
of the table where the ABI has them; calls between Sea functions in `sea.s` use the whole table,
which extends the ABI's result registers (the `i`/`p` result registers beyond `x0`–`x1` and
`%rax %rdx`, the `f` result registers beyond `d0`–`d3` and `%xmm0`–`%xmm1`, and the area for
further results):

| LIR | arm64-macos | x86_64-linux |
|-----|-------------|--------------|
| `i` and `p` parameters, in order (hidden result addresses first, §3.6.3) | `x0`–`x7` | `%rdi %rsi %rdx %rcx %r8 %r9` |
| `f`, `x` and `y` parameters, in order, one register each (`x`, `y`: runtime vector forms only; `y` on x86_64 only) | `v0`–`v7` (`d0`–`d7` for `f`) | `%xmm0`–`%xmm7` (`%ymm0`–`%ymm7` for `y`) |
| further parameters | 8-byte stack slots in parameter order at `[sp]` at the call | 8-byte stack slots in parameter order at `0(%rsp)` at the call |
| `i` and `p` results, in order | `x0`–`x7` | `%rax %rdx %rcx %rsi %rdi %r8 %r9` |
| `f` results, in order | `d0`–`d7` | `%xmm0`–`%xmm7` |
| further results | written by the callee to an area of 8-byte slots whose address the caller passes as a hidden parameter after the hidden result addresses of §3.6.3: one slot per result that gets no register, in result order, whatever its class | same |
| callee-saved | `x19`–`x28`, `d8`–`d15` (low 64 bits); `x18` never used; frame record `x29`/`x30` in every non-leaf function | `%rbx %rbp %r12`–`%r15` |
| stack | 16-byte aligned at every call | 16-byte aligned at every call |

### 4.9 Code generation (pass 4)

Pass 4 (`seagen_a64`, `seagen_x64`) turns `sea.lir` into `sea.s` for the target of the `#target`
record, under the calling convention of §4.8 and the style rules of Baysick's runtime assembly
(frame record in every non-leaf function, `x18` never used, 16-byte aligned `sp`).

**Sites.** `_sea_sites` (§4.8) holds one record per distinct `F:L` in this order of first
occurrence in `sea.lir`: the `site` fields of the instructions, and the definition line of every
function, taken at its `func` record. Every function's line is a site, not only those of the
functions that check the stack limit (§4.6), because whether a function is checked depends on its
frame size, which only pass 4 knows, while pass 3b counts the sites (§2.7). A run-time check branches to an out-of-line
call of `_sea_err` with its code, the site index and its argument slots; an `rcall` of an entry
with site `S` passes the site index as its last argument (§4.8). That out-of-line call does not
make a function non-leaf (`_sea_err` never returns, so no frame record is needed for it); a
function is non-leaf when it contains a `call` or `rcall`. In phase 1 pass 4 rejects the vector,
mask, `vfeat`, `retain` and `release` records with `BAD_RECORD` (no phase-1 pass 3 writes them).

**What pass 4 validates.** Pass 4 checks its input as pass 3b does (§3.6.5, the whole list,
including `la` labels and `chk` argument counts), because it is the last pass before the
assembler and an unchecked record would become wrong machine code; any violation is
`BAD_RECORD`.

**The phase-1 allocator** (§8; linear-scan allocation replaces it in phase 5, §5.2). Every virtual
register of a function has its own 8-byte slot in the frame; the frame holds the frame record,
the LIR `slot`s (§3.6.3) and the register slots, and its size is a multiple of 16. When the
largest alignment A of the function's `slot`s exceeds 16, the prologue rounds the stack pointer
down to a multiple of A after allocating the body (arm64 `mov x16, sp` / `and sp, x16, #-A`,
x86_64 `andq $-A, %rsp`), which moves it by up to A − 16 further bytes. **The checked frame
size** S of §4.6 covers every byte the prologue can move the stack pointer by, the worst-case
realignment included: S = 16 + B + R, where B is the body (every area below the frame record,
a multiple of 16) and R = A − 16 if A > 16, else 0. arm64 compares S (frame record 16 + B + R);
x86_64 compares S − 8 (`pushq %rbp` 8 + B + R; the other 8 bytes of the 16 are the return
address its caller's `call` already pushed). Both compare S with `SEA_STACK_LEAF_MAX` to decide
whether a leaf needs the check. Each
instruction loads its register operands from their slots into fixed scratch registers, computes
into a scratch register and stores the result to the destination's slot:

| Use | arm64-macos | x86_64-linux |
|-----|-------------|--------------|
| `i`/`p` operands, in operand order; result in the first | `x9`, `x10`, `x11` | `%rax`, `%rcx`, `%rdx` |
| `f` operands, in operand order; result in the first | `d16`, `d17`, `d18` | `%xmm8`, `%xmm9`, `%xmm10` |
| addresses of slots and data, the stack-limit check | `x16`, `x17` | `%r10`, `%r11` |

Calls load their arguments from the slots into the argument registers of §4.8 and store the
results back; no callee-saved register is used except the frame record (`x29`/`x30`;
`%rbp`), so none is saved. Structured LIR constructs become compares and branches to local labels
`L<function number>_<block>_<what>`. The phase-1 code is deliberately simple; §5.2 states what
phase 5 must reach.

#### 4.9.1 x86_64-linux code (`seagen_x64`)

`seagen_x64` (`passes/seagen_x64/`, built like every pass, §2.6.3, with the same modules and
`DATA` blocks as `seagen_a64`) is `seagen_a64` with the target changed: it reads `sea.lir` the
same way, validates the same things, lays out the same frame areas, numbers sites, constants,
cold blocks and labels the same way and emits the same data layouts (`rt.inc`, §4.8). Only what
this section says differs. As on arm64, the dump tests do not compare `sea.s`: the behaviour of
the program is what the tests check (§6.6), so the instruction sequences below are normative in
their results, and the named sequences are the ones to use.

**Syntax and naming.** GNU `as`, AT&T syntax (Baysick DESIGN.md §5.4.2: never
`.intel_syntax`), x86_64 ELF, `#` comments, 4-space indent, labels in column 0; first line `#
sea.s -- written by seagen_x64 from sea.lir (Sea DESIGN.md 4.8, 4.9)`. Symbols carry no leading
`_` (§4.8): the output defines `sea_main` (`.globl sea_main`, `.type sea_main, @function`) and
`sea_sites` (`.globl sea_sites`, `.type sea_sites, @object`) and refers to `sea_err`,
`sea_stack_limit` and the entry points by their ELF symbols (`sea_printf`, `sea_now`, `sea_log`, …). Every
arm64 local label `L…` is the assembler-local `.L…` (`.Lfn_<name>` for a function other than
`.main`, `.L<f>_ret`, `.L<f>_so`, `.L<f>_c<k>`, `.L<f>_e<k>`, `.L<f>_<b>_<what>`, `.Ld<N>` and
`.Ld<N>_t<k>` for data, `.Lsf<k>` for the site file strings); numeric labels `1:` … only inside
one instruction's sequence.

**Sections.** Code in `.text`, `.p2align 4` before each function; a function's cold blocks and
then its `f64` constants follow it in `.text` (`.p2align 3`, `.quad 0x<16 hex digits>`), as on
arm64. The data records and `sea_sites` go to `.section .data.rel.ro,"aw",@progbits` (they hold
absolute addresses), with `.quad`, `.long`, `.byte` and `.zero` (arm64's `.space`). The last line
is `.section .note.GNU-stack,"",@progbits` (a non-executable stack; without it GNU `ld` warns).

**Addressing and linking.** Data, constants and runtime variables are addressed RIP-relative
(`leaq .Ld1(%rip), %rax`, `movsd .L1_c3(%rip), %xmm8`, `movq sea_stack_limit(%rip), %r11`);
calls are direct (`call .Lfn_tri`, `call sea_err`, `call sea_printf`). The program is linked
non-PIE, exactly as Baysick's x86_64 programs (Baysick DESIGN.md §5.4.1): `as --64 -o prog.o
sea.s`, then `gcc -no-pie -o prog prog.o libsea.a libbaysickrt.a -lm` (Baysick's flags; Sea's
own code calls no libm function, `-lm` serves Baysick archive members), so the absolute addresses in `.data.rel.ro` are resolved at static link time. The driver does not run
these commands (x86_64-linux is a cross target, §2.2); the cross run does (§6.6.1).

**Frame.** A function is entered with `%rsp` ≡ 8 (mod 16). Its prologue is the stack check (when
§4.6 requires one), then `pushq %rbp`, `movq %rsp, %rbp`, `subq $F, %rsp`, where F is the size of
the arm64 frame's body (every area below the frame record, rounded up to 16), so `%rsp` ≡ 0
(mod 16) at every call; when the realignment of §4.9 applies, `andq $-A, %rsp` follows the
`subq` (the epilogue's `leave` undoes it). The areas lie from `%rsp` upwards exactly as on
arm64: outgoing stack arguments and the `sea_err` argument slots at offset 0, the results area
of calls, the LIR slots, 16 bytes per loop block, the saved address of the function's own
results area, the register slots. Every function has this `%rbp` frame (as every `seagen_a64` function has its frame
record); no other callee-saved register is used, so none is saved. The parameters are stored
from the §4.8 registers into their slots after the prologue; a parameter passed on the stack is
at `16+8k(%rbp)`. The epilogue is `leave`, `ret`. The scratch registers are those of the
phase-1 allocator table above; `%rdx` and `%rcx` double as the operands that x86 instructions
fix (`idivq`, shift counts in `%cl`).

**Stack check** (§4.6), before `pushq %rbp`, with N = S − 8 = 8 + F + R, every byte the
prologue can move `%rsp` by (S and R as in §4.9; F = B):

```
    movq sea_stack_limit(%rip), %r11
    movq %rsp, %r10
    subq %r11, %r10          # borrow (CF = 1): rsp already below the limit
    jb .L<f>_so
    cmpq $N, %r10            # N > 2^31 - 1: movabsq $N, %r11 / cmpq %r11, %r10
    jb .L<f>_so
```

and the cold block, reached with `%rsp` ≡ 8 (mod 16) and nothing allocated:

```
.L<f>_so:
    subq $8, %rsp            # realign for the call
    movl $15, %edi           # STACK_OVERFLOW (errors.inc)
    movq $<site index of the function's definition line>, %rsi
    movq %rsp, %rdx
    call sea_err
```

**Run-time error calls.** A check's cold block is `movl $<code>, %edi`, `movq $<site index>,
%rsi`, `movq %rsp, %rdx` (the argument slots at offset 0 of the frame, stored before the jump as
on arm64), `call sea_err`; `%rsp` ≡ 0 there. An `rcall` of an entry with site `S` passes the site
index as its last integer argument (§4.8).

**Instructions whose x86_64 form differs** (every LIR instruction keeps exactly its §3.6.4
meaning; operands are in the scratch registers in operand order, the result in the first):

| LIR | x86_64 |
|-----|--------|
| `li` | `movq $v, %rax` for −2³¹ ≤ v < 2³¹, else `movabsq $v, %rax` |
| `lf` | `movsd .L<f>_c<k>(%rip), %xmm8` (the function's constant, as arm64's `L<f>_c<k>`) |
| `la`, `sa` | `leaq .Ld<N>(%rip), %rax`; `leaq <offset>(%rsp), %rax` |
| `iaddc` `isubc` `inegc` | `addq %rcx, %rax` / `subq %rcx, %rax` / `negq %rax`, then `jo` to the `INT_OVERFLOW` cold block |
| `imulc` | `imulq %rcx, %rax`, then `jo` (OF is set exactly when the signed product does not fit) |
| `imulh` | `imulq %rcx` (one-operand form: `%rdx:%rax` = `%rax`·`%rcx`), then `movq %rdx, %rax` |
| `idivf` | `idivq` raises a divide error (`SIGFPE`) for a zero divisor and for −2⁶³ ÷ −1, so the checks come first: divisor 0 → `INT_DIV_ZERO`; divisor −1 and dividend −2⁶³ → `INT_OVERFLOW`; then `cqto`, `idivq %rcx` (quotient `%rax`, remainder `%rdx`) and the floored correction of arm64 (remainder ≠ 0 with a sign different from the divisor's: quotient − 1) |
| `imodf` | divisor 0 → `INT_DIV_ZERO`; divisor −1 → result 0 without `idivq` (the floored modulo by −1 is 0 for every dividend, −2⁶³ included, where `idivq` would fault and arm64's `sdiv` does not); otherwise `cqto`, `idivq %rcx`, and the floored correction (remainder ≠ 0 with a sign different from the divisor's: remainder + divisor) |
| `rcount` | the arm64 sequence with `divq` for its unsigned divisions (`xorl %edx, %edx` first; the zero-step check comes before) |
| `ishl` `ishr` `isar` | `shlq %cl, %rax` / `shrq %cl, %rax` / `sarq %cl, %rax` (the hardware masks the count to 6 bits, which changes nothing for the counts 0 … 63 the instruction allows) |
| `icmp`, `bnot` | `cmpq %rcx, %rax` (`testq %rax, %rax` for `bnot`), `set<cc> %al`, `movzbl %al, %eax`; cc `eq` `e`, `ne` `ne`, `lt` `l`, `le` `le`, `gt` `g`, `ge` `ge` (`bnot`: `e`) |
| `isel` `psel` | `testq %rax, %rax`, `movq %rdx, %rax`, `cmovneq %rcx, %rax` |
| `fsel` | `testq %rax, %rax`, `jne 1f`, `movapd %xmm9, %xmm8`, `1:` |
| `fcmp` | `ucomisd` (flags of D − S for `ucomisd S, D`; an unordered pair sets ZF, PF and CF): `eq` `ucomisd %xmm9, %xmm8`, `sete %al`, `setnp %cl`, `andb %cl, %al`; `ne` the same with `setne`, `setp`, `orb`; `gt` `ucomisd %xmm9, %xmm8`, `seta`; `ge` the same with `setae`; `lt` `ucomisd %xmm8, %xmm9`, `seta`; `le` the same with `setae`; then `movzbl %al, %eax`. With a NaN operand only `ne` gives 1 |
| `fnan` | `ucomisd %xmm8, %xmm8`, `setp %al`, `movzbl %al, %eax` |
| `fneg` `fabs` | flip / clear bit 63 through `%rax`: `movq %xmm8, %rax`, `btcq $63, %rax` / `btrq $63, %rax`, `movq %rax, %xmm8` (never `0 − x`, which gives +0 for −(+0)) |
| `fsqrt` | `sqrtsd %xmm8, %xmm8` |
| `fmin` `fmax` | not `minsd`/`maxsd`, which return their second (source) operand when either is NaN and when the operands are equal (±0 included); the result is arm64's: `fmin` gives b if b < a (an ordered comparison), else a, and then b if a is NaN; `fmax` the same with b > a |
| `ffloor` `fceil` `ftrunc` `fround` | SSE2 has no `roundsd`, so: if x is NaN or \|x\| ≥ 2⁵², the result is x (NaN, or already integral); otherwise t = `cvttsd2si` then `cvtsi2sdq` (exact for \|x\| < 2⁵²), and `ftrunc` gives t; `ffloor` t − 1.0 if t > x, else t; `fceil` t + 1.0 if t < x, else t; `fround` t + 1.0·sign(x) if \|x − t\| ≥ 0.5 (x − t is exact), else t; a zero result takes x's sign bit (`ftrunc(-0.5)`, `fceil(-0.5)`, `fround(-0.4)` and `ffloor(-0.0)` are −0.0), which gives exactly arm64's `frintz`/`frintm`/`frintp`/`frinta` results |
| `itof` | `cvtsi2sdq %rax, %xmm8` (round to nearest even: MXCSR is never changed) |
| `ftoi` | the checks come first, as on arm64: NaN, a non-integral x (the `ftrunc` above differs from x) and x < −2⁶³ or x ≥ 2⁶³ go to the `CONV_I64` cold block (x's bits in the argument slot); then `cvttsd2si %xmm8, %rax`. (`cvttsd2si` returns 0x8000000000000000, the "integer indefinite", for NaN and out-of-range inputs, so the conversion cannot be checked afterwards; −2⁶³ itself converts to that pattern correctly) |
| `ldi` `ldb` `ldf` `ldp`, `sti` `stb` `stf` `stp` | `movq`, `movzbl`, `movsd`, `movq`; `movq %rax`, `movb %al`, `movsd %xmm8`, `movq %rax`, on `off(base, idx, scale)` when scale is 1, 2, 4 or 8 and −2³¹ ≤ off < 2³¹; otherwise the address is computed into `%r10` first (`imulq`/`addq`, `movabsq` for a large offset), as arm64 computes it into `x16` |
| `chkb` | `cmpq %rcx, %rax`, `jae` to the `INDEX_OOB` cold block (unsigned, so idx < 0 fails too) |
| `chk` | `testq %rax, %rax`, `jne` to the cold block |
| branches | `jmp` and `j<cc>`: GNU `as` chooses the short or near form, and a near branch reaches any distance, so arm64's far form (and the mode-0 line count it needs) has no counterpart |
| `call`, `rcall` | arguments loaded into the §4.8 registers (stack arguments stored at `0(%rsp)`, `8(%rsp)`, …), `call`, results stored from `%rax %rdx %rcx %rsi %rdi %r8 %r9` and `%xmm0`–`%xmm7` (and the results area); no entry point is variadic, so generated code never sets `%al` |
| `ret` | the results into the §4.8 result registers (and the caller's results area), then the epilogue |

The vector, mask and `vfeat` instructions and `retain`/`release` are `BAD_RECORD` in phase 2, as
in phase 1 (§4.9).

### 4.10 Elementary functions

`log exp sin cos pow hypot` (LANGUAGE.md §10.4, Decision 6 in §9) are Sea's own, in
`runtime/<target>/rt_math.s` of each runtime. This section is their complete definition: every
operation, constant and table entry is given exactly, so that the two runtimes, the vector forms
of phase 7 and the compile-time evaluation of `pow` in constants (§4.10.5) compute **the same
bits for every input**. Whatever an implementation does differently from the text below (register
use, scheduling, branches turned into selects, which of two independent values it computes
first) must not change a single result bit.

**Rules every step obeys** (Decision 1, LANGUAGE.md §6.8):

* the only floating-point operations are IEEE binary64 `+ − × ÷` and `sqrt`, each correctly
  rounded to nearest, ties to even, plus the exact operations: sign flip and sign clear on the bit
  pattern, reinterpretation of a pattern, and conversion of an integer of at most 53 significant
  bits to `f64` (exact; `scvtf` / `cvtsi2sdq`). **No FMA** (SSE2 has none, and arm64 must not
  contract: every `×` followed by `+` below is two instructions), no x87, no long double, no
  approximate reciprocal, no flush-to-zero (FPCR and MXCSR are never changed; their exception
  flags may be set and are never read);
* integer operations are exact operations on 64-bit patterns: `+ − ×` modulo 2⁶⁴, the 128-bit
  unsigned product of two 64-bit values (arm64 `mul`/`umulh`, x86_64 `mulq`), `& | ^`, shifts by
  0 … 63 (`<<`, `>>` logical, `>>ₐ` arithmetic), unsigned and signed comparisons;
* results are within **1 ulp** of the correctly rounded value, and are **< 1 ulp** from the
  exact value everywhere (measured: §4.10.7), which also makes every exactly representable result
  exact (`exp(0)`, `log(1)`, `pow(2, 10)`, `pow(9, 0.5)`, `hypot(3, 4)`);
* special values follow C99 Annex F (F.9.1.6, F.9.3.1, F.9.3.7, F.9.4.3, F.9.4.4): ±0, ±∞,
  NaN and subnormals; **every NaN result is the pattern `#7FF8000000000000`** (Sea's `nan`),
  whatever the inputs' NaN payloads, so even the unobservable NaN bits (LANGUAGE.md §6.5) agree
  between the targets and with constant evaluation;
* the functions never fail, never trap, never write memory outside their own stack frame, read
  only their arguments and the tables, and call nothing outside `rt_math.s`.

#### 4.10.1 Entry points and ABI

The scalar entries are the `rt.inc` entries 3–8 of §4.8 (`SEA_ENT_LOG` … `SEA_ENT_HYPOT`;
symbols `_sea_log` … on `arm64-macos`, `sea_log` … on `x86_64-linux`). They follow the platform
ABI exactly, so they are also callable from C as `double sea_log(double)` and `double
sea_pow(double, double)` (the test harness of §4.10.6 does so):

| Entry | arm64-macos | x86_64-linux |
|-------|-------------|--------------|
| `sea_log` `sea_exp` `sea_sin` `sea_cos` | x in `d0`, result in `d0` | x in `%xmm0`, result in `%xmm0` |
| `sea_pow` `sea_hypot` | x in `d0`, y in `d1`, result in `d0` | x in `%xmm0`, y in `%xmm1`, result in `%xmm0` |
| may clobber | `x0`–`x17`, `v0`–`v7`, `v16`–`v31`, the upper 64 bits of `v8`–`v15`, NZCV, the FPSR flags | `%rax %rcx %rdx %rsi %rdi %r8`–`%r11`, `%xmm0`–`%xmm15`, the status flags, the MXCSR exception flags |
| preserves | `x19`–`x29`, `sp`, `d8`–`d15`, FPCR; never touches `x18` | `%rbx %rbp %r12`–`%r15`, `%rsp`, the MXCSR control bits, the x87 state; the direction flag stays clear |
| stack | at most 256 bytes below the incoming `sp`, so the call fits inside `SEA_STACK_MARGIN` (§4.6) | the same, below the return address |

The entries are leaf code in `rt_math.s`, which references no symbol of another runtime file, so
a program that links `libsea.a` pulls in only `rt_math.o` for them. They share internal helpers
(the logarithm and exponential cores below) under `_sea_`/`sea_` names that are not contract
(§4.5, "Internal runtime symbols").

**Vector forms** (phase 7, §5.1) compute, in each lane, exactly the scalar sequence of this
section: the branches of the scalar text become per-lane selects, table lookups become per-lane
loads, and the paths marked *rare* below (special inputs, `exp` with |x| ≥ 512, the Payne–Hanek
reduction of `sin`/`cos` for |x| ≥ 2²³, subnormal inputs) may be done by calling the scalar
entry for the lanes that need them (NEON and SSE2 have no 64 × 64-bit vector multiply). Their
entry points and register conventions are added to `rt.inc` and §4.8 by phase 7; their results
are bit-identical to the scalar entries for every input, which the tests of §4.10.6 check.

#### 4.10.2 Notation and shared primitives

`bits(x)` is the 64-bit pattern of `f64` x, `f64(u)` the `f64` with pattern u; `neg(x)` flips
and `abs(x)` clears bit 63; `itof(i)` converts a signed integer (every use is exact). `RN` is the
rounding of one operation; every `+ − × ÷` written below is one rounded operation, evaluated in
the order the parentheses give (without parentheses, left to right: `a + b + c` is `(a + b) +
c`). A hexadecimal number written `#…` is a 64-bit pattern; `2^k` is the exact power of two.

```
two_sum(a, b):      s = a + b;  bb = s - a;  e = (a - (s - bb)) + (b - bb);  return (s, e)
fast_two_sum(a, b): s = a + b;  e = b - (s - a);  return (s, e)
split(a):           g = 134217729.0 * a;  h = g - (g - a);  l = a - h;  return (h, l)
two_prod(a, b):     p = a * b;  (ah, al) = split(a);  (bh, bl) = split(b)
                    e = (((ah * bh - p) + ah * bl) + al * bh) + al * bl;  return (p, e)
```

`two_sum` gives s + e = a + b exactly for any finite a, b; `fast_two_sum` the same when a = 0 or
the exponent of a is at least that of b (each use below says why that holds); `two_prod` gives
p + e = a·b exactly when |a|, |b| < 2⁹⁹⁵ and no partial product underflows (each use is in that
range, or its error term is negligible where noted). `134217729.0` is 2²⁷ + 1 (`#41A0000002000000`).

The constants are given below as patterns; the column "definition" says what each one is, so
that the generator (§4.10.6) can recompute and check them. `RN₅₃(v)` is v rounded to the nearest
`f64`, `RNb(v)` to b significant bits, `RNgrid(v, e)` to the nearest multiple of 2⁻ᵉ, all ties to
even; v is the exact mathematical value.

#### 4.10.3 The tables: `include/math_tables.inc`

The tables are generated by `tools/math_tables.py` (§4.10.6), which computes every entry from
its definition with mpmath at 600 bits and rounds it as stated, and writes
`include/math_tables.inc`. The file is committed and is included by both runtimes'
`rt_math.s`; it is shared by Apple `as` and GNU `as` under the rules of §2.6 (Baysick DESIGN.md
§3.4: `//` comments only at the start of a line, no trailing comments, guarded by
`.ifndef SEA_MATH_TABLES_INC` / `.equiv SEA_MATH_TABLES_INC, 1` / `.endif`). It defines one
macro, `SEA_EMIT_MATH_TABLES`, which the including file invokes once in its read-only data
section (`__TEXT,__const` / `.section .rodata`); the macro emits `.p2align 6`, then the labels
and `.quad` lines below in this order, every value as `.quad 0x` and 16 upper-case hexadecimal
digits, one per line (a record of several words is several lines). Exact line shapes, which
`tools/gendata.bas` reads for the `mtab` block (§2.6.3): a label line is `sea_mt_<name>:` from
column 1 with nothing after it; a word line is four spaces, `.quad 0x` and the 16 digits. The labels are file-local
(`sea_mt_…`, never `.globl`); the macro defines no `.equiv` name other than the guard (the
counts below are fixed by this section, not by the contract tables of §2.6).

| Label | Records | Words per record | Record i |
|-------|--------:|-----------------:|----------|
| `sea_mt_const` | 1 | 32 | the constants of §4.10.4, in the order of the constant table there |
| `sea_mt_exp` | 128 | 2 | `EXP_TAIL[i]`, `EXP_SBITS[i]` |
| `sea_mt_log` | 128 | 3 | `LOG_INVC[i]`, `LOG_LOGC_HI[i]`, `LOG_LOGC_LO[i]` |
| `sea_mt_trig` | 52 | 4 | `TRIG_SH[j]`, `TRIG_SL[j]`, `TRIG_CH[j]`, `TRIG_CL[j]` |
| `sea_mt_tpi` | 20 | 1 | `TPI[w]` |

**`exp` table** (i = 0 … 127): T = 2^(i/128); `EXP_TAIL[i]` = `bits(RN₅₃((T − Tₕ)/Tₕ))` with Tₕ =
`RN₅₃(T)`; `EXP_SBITS[i]` = `bits(Tₕ) − (i << 45)` (mod 2⁶⁴). Spot values: record 0 = `#0`,
`#3FF0000000000000`; record 1 = `#3C9B3B4F1A88BF6E`, `#3FEFF63DA9FB3335`; record 127 =
`#3C5305C14160CC89`, `#3FEFF3C22B8F71F1`.

**`log` table** (i = 0 … 127). Block i is the set of patterns
[`LOG_OFF` + i·2⁴⁵, `LOG_OFF` + (i+1)·2⁴⁵) with `LOG_OFF` = `#3FE5F00000000000`, i.e. the values
z of that range; c is the arithmetic midpoint (a + b)/2 of the block's first value a and the
first value b after it. For the block that contains `#3FF0000000000000` (i = 80) `LOG_INVC` =
1.0 and both `LOGC` words are 0; otherwise `LOG_INVC[i]` = `RN26(1/c)` (26 significant bits),
and with L = −ln(`LOG_INVC[i]`) (exactly, from the rounded value), `LOG_LOGC_HI[i]` =
`RNgrid(L, 42)` and `LOG_LOGC_LO[i]` = `RN₅₃(L − LOG_LOGC_HI[i])`. Spot values: record 0 =
`#3FF745D178000000`, `#BFD7FAFA45D81000`, `#BD346C979BF72820`; record 79 = `#3FF0101010000000`,
`#BF70080549580000`, `#BD2166AECB31C67A`; record 81 = `#3FEFC07F00000000`, `#3F7FE02B6B100000`,
`#3D19E43F0DDA563A`; record 127 = `#3FE767DCE8000000`, `#3FD404307C26A000`,
`#3D3F925150499AC3`.

**`sin`/`cos` table** (j = 0 … 51): a = j/64; `TRIG_SH[j]` = `RN₅₃(sin a)`, `TRIG_SL[j]` =
`RN₅₃(sin a − TRIG_SH[j])`, `TRIG_CH[j]` = `RN₅₃(cos a)`, `TRIG_CL[j]` = `RN₅₃(cos a −
TRIG_CH[j])`. Spot values: record 0 = `#0`, `#0`, `#3FF0000000000000`, `#0`; record 1 =
`#3F8FFFAAAAEEEED5`, `#BC02AB639A9F0776`, `#3FEFFF000155549F`, `#3C828A28A03A5EF3`; record 51 =
`#3FE6E2B77C40BDE1`, `#BC70E729857FAD53`, `#3FE65DC1FDEB8CBA`, `#BC597C1B47337C77`.

**The 2/π table** (w = 0 … 19): the 1280-bit integer ⌊2/π · 2¹²¹⁶⌋, as 20 64-bit words, most
significant first; word 0 is zero, so bit g (counting from 0 at the most significant bit of word
0) is bit g − 63 after the binary point of 2/π. 1216 bits of 2/π are enough for every finite
argument (§4.10.4, `sin`/`cos`, step R2). The words, in order:

```
0000000000000000 A2F9836E4E441529 FC2757D1F534DDC0 DB6295993C439041
FE5163ABDEBBC561 B7246E3A424DD2E0 06492EEA09D1921C FE1DEB1CB129A73E
E88235F52EBB4484 E99C7026B45F7E41 3991D639835339F4 9C845F8BBDF9283B
1FF897FFDE05980F EF2F118B5A0A6D1F 6D367ECF27CB09B7 4F463F669E5FEA2D
7527BAC7EBE5F17B 3D0739F78A5292EA 6BFB5FB11F8D5D08 56033046FC7B6BAB
```

#### 4.10.4 The algorithms

**Constants** (the 32 words of `sea_mt_const`, in this order):

| Name | Word | Pattern | Definition |
|------|-----:|---------|------------|
| `EXP_INVLN2N` | 0 | `#40671547652B82FE` | `RN₅₃(128/ln 2)` |
| `EXP_SHIFT` | 1 | `#4338000000000000` | 1.5·2⁵² (also the shift of `sin`/`cos`) |
| `EXP_NLN2HI_N` | 2 | `#BF762E42FEFC0000` | −`RN35(ln 2/128)` (35 significant bits) |
| `EXP_NLN2LO_N` | 3 | `#3D3C610CA86C3899` | −`RN₅₃(ln 2/128 − RN35(ln 2/128))` |
| `EXP_C2` | 4 | `#3FE0000000000000` | 1/2 |
| `EXP_C3` | 5 | `#3FC5555555555555` | `RN₅₃(1/6)` |
| `EXP_C4` | 6 | `#3FA5555555555555` | `RN₅₃(1/24)` |
| `EXP_C5` | 7 | `#3F81111111111111` | `RN₅₃(1/120)` |
| `LOG_LN2HI` | 8 | `#3FE62E42FEFA3800` | `RNgrid(ln 2, 42)` |
| `LOG_LN2LO` | 9 | `#3D2EF35793C76730` | `RN₅₃(ln 2 − LOG_LN2HI)` |
| `LOG_A3` | 10 | `#3FD5555555555555` | `RN₅₃(1/3)` |
| `LOG_A4` | 11 | `#BFD0000000000000` | −1/4 |
| `LOG_A5` | 12 | `#3FC999999999999A` | `RN₅₃(1/5)` |
| `LOG_A6` | 13 | `#BFC5555555555555` | `RN₅₃(−1/6)` |
| `LOG_A7` | 14 | `#3FC2492492492492` | `RN₅₃(1/7)` |
| `LOG_A8` | 15 | `#BFC0000000000000` | −1/8 |
| `LOG_A9` | 16 | `#3FBC71C71C71C71C` | `RN₅₃(1/9)` |
| `TRIG_INVPIO2` | 17 | `#3FE45F306DC9C883` | `RN₅₃(2/π)` |
| `TRIG_P1` | 18 | `#3FF921FB54800000` | `RN30(π/2)` |
| `TRIG_P2` | 19 | `#BE0DE973DC800000` | `RN30(π/2 − P1)` |
| `TRIG_P3` | 20 | `#BC19D9CCEB800000` | `RN30(π/2 − P1 − P2)` |
| `TRIG_P4` | 21 | `#BA21FC8F8CBB5BF7` | `RN₅₃(π/2 − P1 − P2 − P3)` |
| `TRIG_PIO2_HI` | 22 | `#3FF921FB54442D18` | `RN₅₃(π/2)` |
| `TRIG_PIO2_LO` | 23 | `#3C91A62633145C07` | `RN₅₃(π/2 − PIO2_HI)` |
| `TRIG_S3` | 24 | `#BFC5555555555555` | `RN₅₃(−1/6)` |
| `TRIG_S5` | 25 | `#3F81111111111111` | `RN₅₃(1/120)` |
| `TRIG_S7` | 26 | `#BF2A01A01A01A01A` | `RN₅₃(−1/5040)` |
| `TRIG_C2` | 27 | `#BFE0000000000000` | −1/2 |
| `TRIG_C4` | 28 | `#3FA5555555555555` | `RN₅₃(1/24)` |
| `TRIG_C6` | 29 | `#BF56C16C16C16C17` | `RN₅₃(−1/720)` |
| `SPLIT` | 30 | `#41A0000002000000` | 2²⁷ + 1 |
| `NAN` | 31 | `#7FF8000000000000` | the NaN result |

The other constants are powers of two and small integers, written in the text (`2^1009` is
`#7F00000000000000`, `2^-1022` is `#0010000000000000`, `2^52` is `#4330000000000000`, `2^-422`
is `#2590000000000000`, `2^±600` are `#6570000000000000` and `#1A70000000000000`, `2^-53`,
`2^-106`, `2^-159` are `#3CA0000000000000`, `#3950000000000000`, `#3600000000000000`).

The polynomials are truncated Taylor series with the coefficients rounded to nearest (no
minimax fitting, so every coefficient is defined by the table above alone); their truncation
errors are below 2⁻⁶⁰ relative on the reduced intervals, far inside the budget of §4.10.7.

---

**`exp(x)`**

1. If x is NaN, the result is `NAN`.
2. Otherwise the result is `exp_core(x, 0.0)`.

`exp_core(x, xt)` computes e^(x + xt) for any x that is not NaN and a tail xt with |xt| ≤
2⁻²⁵·|x| (it is 0.0 for `exp`); `pow` calls it too. With `top` = (`bits(x)` >> 52) & `#7FF`:

1. If `top` < `#3C9` (|x| < 2⁻⁵⁴): the result is `1.0 + x`.
2. If `top` ≥ `#409` (|x| ≥ 1024, ±∞ included): the result is +0.0 if bit 63 of `bits(x)` is
   set, else +∞.
3. Reduction: `z = EXP_INVLN2N * x`; `kd = z + EXP_SHIFT`; `ki = bits(kd)`;
   `kd = kd - EXP_SHIFT` (kd is now the integer nearest x·128/ln 2, ties to even, |kd| < 2¹⁸);
   `r = (x + kd * EXP_NLN2HI_N) + kd * EXP_NLN2LO_N` (the product with the 35-bit constant and the
   first sum are exact); `r = r + xt`.
4. Table: `i = ki & 127`; `tail = f64(EXP_TAIL[i])`; `sbits = EXP_SBITS[i] + (ki << 45)`
   (mod 2⁶⁴; this adds k = ki >>ₐ 7 to the exponent field).
5. Polynomial: `r2 = r * r`;
   `tmp = ((tail + r) + r2 * (EXP_C2 + r * EXP_C3)) + (r2 * r2) * (EXP_C4 + r * EXP_C5)`.
6. If `top` < `#408` (|x| < 512): `scale = f64(sbits)`; the result is `scale + scale * tmp`.
7. Otherwise (*rare*, 512 ≤ |x| < 1024), by bit 31 of `ki` (the sign of k):
   * clear (k > 0): `scale = f64(sbits − (1009 << 52))`; the result is
     `2^1009 * (scale + scale * tmp)` (the final product overflows to +∞ exactly when the
     result does);
   * set (k < 0): `scale = f64(sbits + (1022 << 52))`; `y = scale + scale * tmp`; if `y < 1.0`
     (the result is subnormal or zero), round once at the subnormal precision:
     `lo = (scale - y) + scale * tmp`; `hi = 1.0 + y`; `lo = ((1.0 - hi) + y) + lo`;
     `y = (hi + lo) - 1.0`; then (in both cases) the result is `2^-1022 * y`.

---

**`log(x)`**, in this order, with `ix = bits(x)`:

1. x is NaN: `NAN`. x = ±0: −∞. x < 0 (bit 63 set, x ≠ −0, −∞ included): `NAN`. x = +∞: +∞.
2. x subnormal (*rare*; `ix` >> 52 = 0): `ix = bits(x * 2^52) − (52 << 52)` (mod 2⁶⁴).
3. The result is h of `(h, l) = log_core(ix)`.

`log_core(ix)`, for the pattern of a positive normal value (an unbiased exponent may be below
−1022 after step 2), returns h + l ≈ ln x with h = `RN(h + l)` and |error| below 2⁻⁶⁸·|ln x|
(`pow` uses l; `log` returns h; measured 2⁻⁶⁹·⁴):

1. `t = ix − LOG_OFF` (mod 2⁶⁴, `LOG_OFF` = `#3FE5F00000000000`); `i = (t >> 45) & 127`;
   `k = t >>ₐ 52`; `iz = ix − (t & #FFF0000000000000)`; `z = f64(iz)`
   (so x = 2ᵏ·z with z in [`f64(LOG_OFF)`, 2·`f64(LOG_OFF)`) ≈ [0.6855, 1.371), and z = 1 for
   x = 1 lies in the middle of block 80).
2. `invc = f64(LOG_INVC[i])`; `zhi = f64(iz & #FFFFFFFFFC000000)`; `zlo = z - zhi`;
   `rhi = zhi * invc - 1.0`; `rlo = zlo * invc` (zhi has 27 and zlo at most 26 significant bits,
   `invc` 26, so both products and the subtraction are exact);
   `(rh, rl) = two_sum(rhi, rlo)` (r = z·invc − 1 = rh + rl exactly, |r| < 2⁻⁸).
3. `kd = itof(k)`; `t1 = kd * LOG_LN2HI + f64(LOG_LOGC_HI[i])` (exact: both terms are multiples
   of 2⁻⁴², |t1| < 2¹⁰); `(t2, e1) = two_sum(t1, rh)`.
4. `(s, se) = two_prod(rh, rh)`; `hs = -0.5 * s`; `(t3, e2) = two_sum(t2, hs)`.
5. `r2 = rh * rh`;
   `p = (rh * r2) * (LOG_A3 + rh * (LOG_A4 + rh * (LOG_A5 + rh * (LOG_A6 + rh * (LOG_A7 + rh * (LOG_A8 + rh * LOG_A9))))))`.
6. `lo = (kd * LOG_LN2LO + f64(LOG_LOGC_LO[i])) + rl`; `lo = lo + (e1 + e2)`;
   `lo = lo + ((-0.5 * se) - rh * rl)`; `lo = lo + p`.
7. `(h, l) = fast_two_sum(t3, lo)` (|lo| < 2⁻⁵⁰·|t3| unless both are 0).

---

**`pow(x, y)`**, in this order (C99 F.9.4.4), with `ix = bits(x)`, `iy = bits(y)`:

1. y = ±0: 1.0 (even for a NaN x).
2. x = +1.0: 1.0 (even for a NaN y).
3. x or y NaN: `NAN`.
4. y = ±∞: if x = −1, 1.0; else if (|x| < 1 and y = −∞) or (|x| > 1 and y = +∞), +∞; else
   +0.0.
5. Classify y (finite, non-zero) with e = (`iy` >> 52) & `#7FF`: e < 1023 → *not an integer*;
   e > 1075 → *even integer*; otherwise with b = 1075 − e: bits 0 … b−1 of `iy` not all zero →
   *not an integer*, else bit b set → *odd integer*, else *even integer*.
6. x = ±0: if y < 0: −∞ if x = −0 and y is an odd integer, else +∞; if y > 0: x itself (±0)
   if y is an odd integer, else +0.0.
7. x = ±∞: x = +∞: +0.0 if y < 0, else +∞; x = −∞: if y < 0, −0.0 for an odd integer y, else
   +0.0; if y > 0, −∞ for an odd integer y, else +∞.
8. x < 0 (finite): if y is not an integer, `NAN`; otherwise remember *negate* = (y is an odd
   integer) and clear bit 63 of `ix`.
9. x subnormal (*rare*; `ix` >> 52 = 0): `ix = bits(f64(ix) * 2^52) − (52 << 52)`.
10. `(lh, lt) = log_core(ix)`;
    `yhi = f64(iy & #FFFFFFFFF8000000)`; `ylo = y - yhi`;
    `lhi = f64(bits(lh) & #FFFFFFFFF8000000)`; `llo = (lh - lhi) + lt`;
    `ehi = yhi * lhi` (exact: 26 × 26 significant bits); `elo = ylo * lhi + y * llo`
    (`(ylo * lhi) + (y * llo)`).
11. `v = exp_core(ehi, elo)` (ehi is never NaN: lhi ≠ 0 because x ≠ 1; when |ehi| ≥ 1024
    `exp_core` returns from its step 2 before it reads elo, which may then be infinite).
12. The result is `neg(v)` if *negate*, else v (an overflow gives −∞, an underflow −0.0).

---

**`sin(x)` and `cos(x)`**, with `ix = bits(x)` and `ax = f64(ix & #7FFFFFFFFFFFFFFF)`:

1. |x| is ∞ or NaN (`bits(ax)` ≥ `#7FF0000000000000`): `NAN`.
2. |x| < 2⁻²⁷ (`bits(ax)` < `#3E40000000000000`): `sin` gives x (±0 and subnormals included),
   `cos` gives 1.0.
3. `(q, rh, rl) = reduce(ax)`: ax = q·π/2 + r (mod 2π) with q in 0 … 3 and r = rh + rl,
   |r| ≤ π/4 (+ a few ulps in R1).
4. `sin`: *use_cos* = q & 1. `cos`: *use_cos* = 1 − (q & 1).
   `(v, sr) = trig_core(rh, rl, use_cos)`.
5. With *odd* = sr ∧ ¬*use_cos* (sin is odd, cos even): `sin`: *negate* = (q >> 1) ⊕ *odd* ⊕
   (bit 63 of `ix`); `cos`: *negate* = (((q + 1) >> 1) & 1) ⊕ *odd*. The result is `neg(v)` if
   *negate*, else v.

`reduce(ax)` (ax ≥ 2⁻²⁷, finite):

* **R1, Cody–Waite**, if `bits(ax)` < `#4160000000000000` (ax < 2²³):
  `z = ax * TRIG_INVPIO2`; `kd = z + EXP_SHIFT`; `q = bits(kd) & 3`; `kd = kd - EXP_SHIFT`;
  `t1 = ax - kd * TRIG_P1` (product and difference exact: kd < 2²³);
  `(s, e) = two_sum(t1, neg(kd * TRIG_P2))`; `(h, l1) = two_sum(s, neg(kd * TRIG_P3))`;
  `l = l1 + (e - kd * TRIG_P4)`; `(rh, rl) = two_sum(h, l)`.
  (P1 + P2 + P3 + P4 is π/2 to 2⁻¹⁴³; the products with P1–P3 are exact.)
* **R2, Payne–Hanek** (*rare*), otherwise (ax ≥ 2²³):
  1. `m = (bits(ax) & #000FFFFFFFFFFFFF) | #0010000000000000`;
     `E = ((bits(ax) >> 52) & #7FF) − 1075` (ax = m·2ᴱ, −29 ≤ E ≤ 971);
     `G = E + 62`; `w = G >> 6`; `sh = G & 63`.
  2. The 192-bit window of 2/π starting at bit G of the table:
     `word(n) = (TPI[n] << sh) | ((TPI[n+1] >> 1) >> (63 − sh))` (the double shift avoids a
     shift by 64 when sh = 0); `W2 = word(w)`, `W1 = word(w+1)`, `W0 = word(w+2)` (w ≤ 16, so
     n + 1 ≤ 19).
  3. 64 × 64 → 128-bit unsigned products: (hi, lo) of m·W0 = (c0, a0); of m·W1 = (c1, a1); the
     low half of m·W2 = a2. `P0 = a0`; `P1 = c0 + a1` (mod 2⁶⁴), `k1 = 1` if `P1 < a1` (unsigned)
     else 0; `P2 = c1 + a2 + k1` (mod 2⁶⁴). P2:P1:P0 is m·window mod 2¹⁹², whose bits 191–190 are
     the quadrant and bits 189–0 the fraction of x·2/π (error < 2⁻¹³⁶; the earlier bits of 2/π
     contribute multiples of 4).
  4. `q = ((P2 >> 62) + ((P2 >> 61) & 1)) & 3` (rounded to the nearest quadrant);
     `T2 = (P2 << 2) | (P1 >> 62)`; `T1 = (P1 << 2) | (P0 >> 62)`; `T0 = P0 << 2`
     (T2 read as a signed integer is the fraction f ∈ [−1/2, 1/2) times 2⁶⁴).
  5. `A = T2 >>ₐ 11`; `B = ((T2 & #7FF) << 42) | (T1 >> 22)`;
     `C = ((T1 & #3FFFFF) << 31) | (T0 >> 33)` (53 bits each);
     `a = itof(A) * 2^-53`; `b = itof(B) * 2^-106`; `c = itof(C) * 2^-159`;
     `(h, l) = two_sum(a, b)`; `(h, t) = two_sum(h, c)`; `l = l + t`.
  6. r = f·π/2: `(p, pe) = two_prod(h, TRIG_PIO2_HI)`;
     `pl = pe + ((h * TRIG_PIO2_LO) + (l * TRIG_PIO2_HI))`; `(rh, rl) = fast_two_sum(p, pl)`.

`trig_core(rh, rl, use_cos)` returns (v, sr), v = sin |r| (use_cos = 0) or cos |r|
(use_cos = 1), sr = bit 63 of `bits(rh)`:

1. `ar = abs(rh)`; `al = neg(rl)` if sr, else `rl`.
2. `jd = ar * 64.0 + EXP_SHIFT`; `j = bits(jd) & #FF` (0 … 51); `jd = jd - EXP_SHIFT`;
   `th = ar - jd * 0.015625` (exact; |th| ≤ 1/128).
3. `t2 = th * th`; `sinp = (th * t2) * (TRIG_S3 + t2 * (TRIG_S5 + t2 * TRIG_S7))`;
   `cosp = t2 * (TRIG_C2 + t2 * (TRIG_C4 + t2 * TRIG_C6))`.
4. For use_cos = 0: (A, AL, B, BL) = (`TRIG_SH[j]`, `TRIG_SL[j]`, `TRIG_CH[j]`, `TRIG_CL[j]`);
   for use_cos = 1: (A, AL, B, BL) = (`TRIG_CH[j]`, `TRIG_CL[j]`, `neg(TRIG_SH[j])`,
   `neg(TRIG_SL[j])`). (sin(a + t) = sin a + cos a·t + …, cos(a + t) = cos a − sin a·t + …: one
   sequence serves both, which the vector forms use.)
5. `(p, pe) = two_prod(B, th)`; `(h, e) = fast_two_sum(A, p)` (A = 0 or |A| ≥ sin(1/64) >
   |p|); `lo = (e + pe) + (AL + BL * th)`; `lo = lo + B * (sinp + al)`;
   `lo = lo + A * (cosp - al * th)`; v = `h + lo`.

---

**`hypot(x, y)`**:

1. x or y is ±∞: +∞ (even if the other is NaN). Otherwise x or y NaN: `NAN`.
2. `ax = abs(x)`, `ay = abs(y)`; if `bits(ax) < bits(ay)` swap them (so ax ≥ ay).
   If ay = 0: the result is ax.
3. Scale: if `bits(ax)` > `#5F30000000000000` (ax > 2⁵⁰⁰): `ax = ax * 2^-600`,
   `ay = ay * 2^-600`, *scale* = 2⁶⁰⁰; else if `bits(ax)` < `#20B0000000000000` (ax < 2⁻⁵⁰⁰):
   `ax = ax * 2^600`, `ay = ay * 2^600`, *scale* = 2⁻⁶⁰⁰; else *scale* = 1.0.
4. `(p, pe) = two_prod(ax, ax)`; `(q, qe) = two_prod(ay, ay)`; `(sh, sl) = two_sum(p, q)`;
   `sl = sl + (pe + qe)`; `(sh, sl) = fast_two_sum(sh, sl)`.
5. `h = sqrt(sh)`; `(hh, he) = two_prod(h, h)`; `d = ((sh - hh) - he) + sl`;
   `corr = d / (h + h)`.
6. If *scale* = 2⁻⁶⁰⁰ and `bits(h)` < `#2590000000000000` (the result is subnormal; *rare*),
   round once at the subnormal precision: `(u, ue) = two_sum(2^-422, h)`; `lo = ue + corr`;
   the result is `((u + lo) - 2^-422) * 2^-600`. Otherwise the result is `(h + corr) * scale`.

#### 4.10.5 Compiler support

**Pass 2a.** The library table of pass 2a gains `log(f64) -> f64`, `exp`, `sin`, `cos` (the same
signature), `pow(f64, f64) -> f64` and `hypot(f64, f64) -> f64` (their scalar overloads; the
elemental array overloads arrive with arrays in phase 4 and are `arrays` under the phase rule
until then). An `i64` argument is converted (`cvt`) and an untyped integer constant is typed
`f64`, as for every `f64` parameter (LANGUAGE.md §4.2). Phase 3 removes the row "`^` that is not
a `powk`" from the phase-rule table of §2.6.2 and the six names from its library row. A `^`
that is not a `powk` stays `bin pow` (§3.5.5), whose two operands pass 2a has already converted
to `f64`; a call `pow(x, y)` is `lib pow`. Neither is folded by pass 2b (§3.5.7: no
transcendental function is folded), so outside `const` items they are always evaluated at run
time.

**Pass 3a** lowers them by the canonical rules (§3.6.6, rule 14): `lib log(x)` is `rcall sea_log
- 1 d 1 a`, and likewise `lib exp`, `lib sin`, `lib cos`; `lib pow(x, y)` and `bin pow x y` are
`rcall sea_pow - 1 d 2 a b`; `lib hypot(x, y)` is `rcall sea_hypot - 1 d 2 a b` (arguments
lowered left to right first, d a new register of class `f` or the destination of rule 2; no
site: the entries cannot fail). §3.6.4 has no LIR instruction for any of them, and none is added:
an instruction would only save the call, and pass 4 would then have to expand 60–150
instructions inline. **Passes 3b and 4** need no change: they validate and emit `rcall` from the
`entries` block generated from `rt.inc` (§2.6.3), which now holds the six records; the calling
convention of §4.8 already maps `f` arguments and results to `d0`/`d1` and `%xmm0`/`%xmm1`.

**`pow` in constants (pass 2a; Decision 16 (a), decided by the user 2026-10-21).** LANGUAGE.md
§7.2 lets a `const` use `^` and `pow`, evaluated with the run time's bits, and pass 2a evaluates
every constant to one literal (§3.5.2). In a constant expression a `^` that is not a `powk` (its
operands converted to `f64` as §6.5 says) and a call `pow(x, y)` (an `i64` or untyped argument
converted to `f64`) are evaluated with **`FEPOW`** of `passes/lib/f64emu.bas`: the operation
sequence of `pow` in §4.10.4 (steps 1–12, with `log_core` and `exp_core`) on f64emu bit
patterns. `log exp sin cos hypot` stay outside constant expressions (LANGUAGE.md §7.2 keeps
listing only `sqrt` and now `pow` among calls): `pow` is admitted because `x ^ y` already is
`pow`, so refusing the call while accepting the operator would be arbitrary; the others have no
such tie, would need the `sin`/`cos` tables and the Payne–Hanek integer path in pass 2a, and no
program needs them. They are `not a constant expression` (code 237) as before.

* **Exactly the same sequence.** Every `+ − × ÷` of §4.10.4 is the corresponding `FEADD FESUB
  FEMUL FEDIV` call with the same operands in the same order (a negated constant is the stored
  negative constant, `neg` is `FENEG`, `abs` clears bit 15 of the top limb), the primitives
  `two_sum`, `fast_two_sum`, `split` and `two_prod` are internal SUBs built from those calls in
  the order of §4.10.2, and each integer step (the `>>`, `>>ₐ`, `<<`, `&`, `+`/`−` mod 2⁶⁴ on
  patterns, the table index, `itof(k)`) is done exactly on the four 16-bit limbs (`LMADD`/`LMSUB`
  for the wrapping sums, new internal limb helpers for shifts and masks, `FEFRI` for `itof(k)`,
  which is exact). No step may be replaced by a Baysick floating-point operation or by an
  "equivalent" shortcut: the result must be the runtime's bits for every input, NaN results
  included (`#7FF8000000000000`, step 3 of `pow`).
* **Tables.** `FEMTI` reads the `mtab` block (§2.6.3) into a list `MT()` that the caller
  dimensions with 4·672 + 1 = 2689 elements: `MT(0)` = 672, word w (0-based, in the block's order:
  the 32 constants, then the `exp` table, then the `log` table) at `MT(4w+1)` … `MT(4w+4)`, most
  significant limb first. `FEPOW` takes `MT()` as its first parameter. Pass 2a (from phase 4a its program `seaname`,
  §2.6.3) lists `data … mtab` in its `build.list`, reads its other `DATA` blocks first and calls `FEMTI` once at start-up; a
  count, limb or sentinel that disagrees is `BAD_DATA` (code 504, §2.6.2).
* **Pass 2b does not fold `pow`.** Outside `const` items, a `^` that is not a `powk` and a call
  `pow` with constant operands stay run-time `rcall`s (§3.5.7 keeps folding only the operations it
  lists): the result has the same bits either way, folding them would make pass 2b load `mtab` too,
  and the workloads' `pow` calls have run-time operands. So `mtab` is loaded by pass 2a only (`seaname`); pass
  2b carries the `FEPOW` code in its copy of `f64emu.bas` without calling it.
* **Cost**: about 400–600 lines in `f64emu.bas` (75 000 – 81 999 has room) and 86 `DATA` lines,
  counted against pass 2a's 10 000 lines (§2.7).
* **Tests**: `tests/vectors/fepow.txt` (written by `math_vectors.py`, §4.10.6) holds `pow #X #Y
  #R` lines in the shape of `f64emu.txt`; the `f64emu` harness of `tests/harness/` reads it with
  the `mtab` block appended to its build, and `arith_check.sh` compares every result bit for bit;
  `tests/programs/` gets `const` tests whose printed values are the model's bits (`%.17g`), and
  `tests/errors/` a `const` using `log` (`not a constant expression`).

#### 4.10.6 Tests (`tests/math/`)

Two oracles: **mpmath is the oracle for accuracy, the Python model is the oracle for identity.**

* `tools/math_tables.py` (run with `uv run --with mpmath`) writes `include/math_tables.inc` from
  the definitions of §4.10.3 and §4.10.4; with `--check` it recomputes everything, compares it
  with the committed file and with the patterns written in this section, and exits 1 on any
  difference. It is a developer tool: the build and the tests read only the committed file.
* `tests/vectors/math_model.py` is the bit-exact model: §4.10.2–§4.10.4 transcribed operation
  by operation with Python floats (IEEE binary64, round to nearest, no FMA) and Python integers
  masked to 64 bits, importing its tables by parsing `include/math_tables.inc`. It is the oracle
  for the expected bits.
* `tests/vectors/math_vectors.py` (run with `uv run --with mpmath`) writes the committed vector
  files `tests/math/<fn>.vec` for fn in `log exp sin cos pow hypot`: one case per line, the
  argument patterns and the expected result pattern as 16 upper-case hexadecimal digits each,
  separated by one space (`3FF0000000000000 0000000000000000` for `log 1`; `pow` and `hypot`
  lines have three fields), then LF. Before it writes a case it checks, at 320 bits (sin/cos
  with 1100 more for the large arguments) with mpmath, that the model's result is within 1 ulp
  of the exact value (the ulp of the binade of the exact value, 2⁻¹⁰⁷⁴ below 2⁻¹⁰²²; an exact
  value ≥ 2¹⁰²⁴(1 − 2⁻⁵⁴) must give ∞), that every special case of §4.10.4 gives the Annex F
  value, and that exactly representable results are exact; any failure stops it with status 1.
  Each file holds exactly 10 000 cases (`math_check` rejects any other count, exit status 2, so a truncated file is caught): every special value of the function, the exact cases
  (`pow(2, k)` for every k from −1074 to 1023 that `pow` covers, `pow(10, k)` for 0 ≤ k ≤ 22,
  `exp(0)`, `log(1)`, `log(2^k)`, Pythagorean `hypot`s), the hard cases of §4.10.7 (log near 1;
  exp near the overflow, underflow and subnormal thresholds; sin/cos at the continued-fraction
  nearest multiples of π/2 in every binade and on both sides of the R1/R2 boundary 2²³; pow with
  huge exponents, near 1, integer exponents, subnormal and near-overflow results; hypot at the
  scaling thresholds and with subnormal results), and seeded random cases over the whole
  range, with every *rare* path of §4.10.4 represented. With `--accuracy N` it instead measures
  the maximum error of the model on N random cases per function and the hard-case sets (the
  measurement of §4.10.7); that run is never part of `make test`.
* `tests/math/math_check.c` is the runtime harness (C, built with `xcrun cc` on the Mac and `gcc`
  on Linux, like Baysick's `tests/kern/kern_check.c`; a test tool, never part of Sea): it links
  `libsea.a`, reads each `.vec` file, calls the scalar entry through its C prototype and compares
  the result's pattern with the expected one, every bit, NaN included (`#7FF8000000000000`). It
  prints `math <fn>: <n> cases ok` per file, or each mismatch as `math <fn>: <args> expected <e>
  got <g>` and exits 1. `make test-math` (part of `make test`) runs it on the Mac; the cross
  bundle carries the `.vec` files and the harness source, and `cross_run.sh` runs it on the
  Linux host against `build-x86_64-linux/libsea.a` (§6.6.1). Phase 7 extends the harness to
  call every vector form (every lane position, with the vector lanes holding different cases)
  under each kernel variant (`SEA_KERNELS`), with the same expected bits.
* **Identity** is checked by the harness: both runtimes must reproduce the model's bits for
  every case, so they agree with each other. **Accuracy** is checked by the generator against
  mpmath for every committed case, and by the `--accuracy` measurement for the model. **The
  compiler path** is checked by Sea programs in `tests/programs/` (`lib_math_*.sea`): calls of
  each function, `^` with a non-`powk` exponent, `i64` and untyped arguments, special values,
  each result printed with `%.17g` (which identifies every `f64` except a NaN's payload),
  expected output from the model's bits formatted by `vectors/progfmt.py`; they run on both
  targets through `run.sh` and the cross run, so both code generators' `rcall`s are covered;
  plus `passes/` dumps of the canonical `rcall` lowering (`.lir1`, §3.8) and `const` tests whose
  literals (`FEPOW`, §4.10.5) are the model's bits.
* `math_vectors.py` also writes `tests/vectors/fepow.txt` for the compile-time `pow` (§4.10.5):
  `pow #X #Y #R` lines (the shape of `f64emu.txt`): every special case of `pow.vec`, its exact
  cases except that of the 2 098 `pow(2, k)` only those with k ≡ 0 (mod 16), k = −1074 and
  k = 1023 are taken, and 500 of its other cases (seeded choice, every *rare* path of `pow`
  represented), at most 1 500 lines because each `FEPOW` costs a few hundred limb operations in
  Baysick;
  `arith_check.sh` checks them bit for bit (§6.2, `tests/harness/`).
* `math_vectors.py --check-format` (it writes no file) checks the committed
  vector files: every field of each `tests/math/*.vec` line and of `tests/vectors/fepow.txt`
  must be exactly 16 upper-case hexadecimal digits, each line must have the right field count
  (two for `log exp sin cos`, three for `pow` and `hypot`; `pow #X #Y #R` for `fepow.txt`),
  and the line ends must be LF.

#### 4.10.7 Measured accuracy

Measured on the Python model of §4.10.6 against mpmath (320 bits; 1420 bits for `sin`/`cos`),
as the maximum over the cases of |result − exact| in ulps of the exact value (definition in
§4.10.6). Random cases are drawn per function over the whole range with emphasis on the
regions named; hard cases are the sets of §4.10.6.

| Function | Random cases | Max error | Hard cases | Max error |
|----------|-------------:|----------:|-----------:|----------:|
| `exp` | 2 000 000 | 0.5100 ulp | 24 538 | 0.5000 ulp |
| `log` | 2 000 000 | 0.5000 ulp | 8 616 | 0.5000 ulp |
| `sin` | 2 000 000 | 0.5000 ulp | 1 947 | 0.4998 ulp |
| `cos` | 1 000 000 | 0.5000 ulp | 1 947 | 0.4999 ulp |
| `pow` | 2 000 000 | 0.5116 ulp | 35 465 | 0.5049 ulp |
| `hypot` | 2 000 000 | 0.5000 ulp | 17 196 | 0.4999 ulp |

(0.5000 means 0.5 plus less than 0.0001: these functions are correctly rounded except in
near-ties.) The bound of LANGUAGE.md §10.4 is 1 ulp; the design keeps a margin of almost half an
ulp because the cores carry 2⁻⁶⁶ … 2⁻¹⁰⁰ relative accuracy in double-double before the one final
rounding. The worst inputs found: `exp(#C08504512C2C4AF6)` (x ≈ −672.54, 0.5100 ulp) and
`pow(#3FFCF498194B378A, #C0913D26A9D53182)` (x ≈ 1.8097, y ≈ −1103.29, 0.5116 ulp).

**Cost** (estimates, not measurements, to be measured in phase 10 with the methodology of §5.7):
about 30 operations for `exp`, 60 for `log` (its double-double core is shared with `pow`, so
`log` is correctly rounded almost always, at about twice the cost of a 0.52-ulp `log`; one core
instead of two is less code to keep identical on two targets), 90 for `pow`, 70 for `sin`/`cos`
with |x| < 2²³, 40 for `hypot`.

## 5. Performance model

### 5.1 Fusion

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
become one pass with no temporary, keeping the pinned reduction order (LANGUAGE.md §10.5).

**Multi-output elemental calls** fuse into one loop writing several arrays (W1's
`shaft_safety` on the grid computes `nf` and `ny` in one pass; unused outputs are not computed).

**Adjacent statements fuse** when they are element-wise over the same iteration space in the
same block, and no statement reads another's result at a different element: W1's bisection
iteration (`mid`, the safety factors, `up`, `lo`, `hi`, LANGUAGE.md §2.1) becomes one loop per iteration,
and `mid`, `nfv`, `nyv`, `up` are never stored (they are dead after the sequence).

**Barriers** (operands are materialized first): `@`, `solve` and the other LANGUAGE.md §10.8 functions;
sorting and searching; concatenation (`[A, B]` is built in one copy pass); calls of
non-elemental functions.

**Aliasing.** When the target of an assignment is also read by the right side, the loop writes
in place only if every element is read before it is written in the loop's order — always true
when the right side reads the target only at the same element (`lo = where(up, mid, lo)`) — and
otherwise a temporary is used (`T[1..ny-1, :] = …` reading shifted `T`).

**Vectorization.** A fused loop over contiguous (unit-stride) data is emitted with vector
registers: 2 × f64 (NEON `v` registers, SSE2 `xmm`) unrolled ×4, and 4 × f64 (AVX2 `ymm`) in the
x86_64 AVX2 copy, plus a scalar tail. Each lane performs the scalar operation sequence of its
element (LANGUAGE.md §6.8), so vector and scalar code give identical bits. Elementary functions in a vector
loop call the runtime's vector forms (§4.5). `if` expressions and `where` become selects
(`bsl`; `andpd`-`andnpd`-`orpd`) when both arms are cheap and cannot fail (LANGUAGE.md §6.10); otherwise the
loop is scalar with branches.

### 5.2 Scalar loop code quality

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
  (LANGUAGE.md §6.8); `x / 4` becomes `x * 0.25`.

**What the hot loops must become** (instruction counts are design targets, checked by
inspecting the `-S` output in phase 5 of §8; not measurements):

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
* **W3 RK4**: `qc_deriv` inlined four times (it satisfies LANGUAGE.md §8.6's inlining rule); the state `x`,
  `k1`…`k4` (16 doubles) in FP registers; no calls and no memory traffic except the road samples
  and the output stores.
* **W1 scalar bisection**: `shaft_safety` inlined into the bisection loop; `pow` is the only call.
* **W2 assembly**: `ke` and `idx` in registers, the 4 index checks hoisted per element, 16
  load-add-store updates.

### 5.3 Small fixed-size values

`T[n]` and `T[r,c]` (≤ 256 elements) and structs are scalar-replaced by pass 3b when every
access uses constant indices after inlining and unrolling: each element becomes its own virtual
register (W3's `f64[4]` state; W2's `f64[4,4]` `ke`). Otherwise they live in the stack frame.
They never touch the heap. Fixed-size arithmetic (`x + h2 * k1`) is unrolled; pass 4 may pair
lanes into 2-wide vector operations when that does not change the operation sequence.

### 5.4 Allocation in hot loops

* Fused loops allocate nothing except their result.
* **Buffer reuse**: assigning a new array value to a variable whose current buffer has the same
  shape and a count of 1 writes into that buffer (`mid = 0.5 * (lo + hi)` in a loop allocates
  once). Pass 3a applies it whenever the old value is dead at the assignment.
* Temporaries that must be materialized inside a loop (barrier operands) get a buffer hoisted
  out of the loop and reused when the shape is loop-invariant.
* Remaining per-iteration allocations come from the small-block free lists or the large-block
  cache (§4.1): W2's `zeros(nDof, nDof)` per FSD iteration is a cache hit plus a 468 KB fill.

### 5.5 Estimated effect on the workloads (estimates, not measurements)

Planning estimates from instruction counts and kernel rates, to be replaced by the measurements
of §6.5. They show where the time should go, not a promise:

| Workload | MATLAB best compute (§1.2) | Where Sea's time should go |
|----------|--------------------:|----------------------------|
| W1 | 0.511 s | ≈ 260 k scalar `shaft_safety` evaluations with one `pow` each (only one branch of `kb` runs); 40 fused grid iterations; well under 0.1 s expected |
| W2 | 0.936 s | ≈ 400 dense factorizations of 241 × 241 (Cholesky ≈ 4.7 MFLOP each) and the 1441-RHS triangular solves; dominated by GEMM-rate updates; a few tenths of a second expected |
| W3 | 0.631 s | 480 k RK4 steps at a few tens of ns each, plus ≈ 0.96 M `sin` for the road (16001 × 60); around 0.1 s expected |
| W4 | 0.902 s | 31 M latency-bound SOR updates (≈ 20 cycles each by the add-chain latency) plus ≈ 1500 fused half sweeps; roughly 0.2–0.4 s expected |
| W5 | 0.764 s | 11 M LCG steps, 3 M `log` and 3 M `cos`, two 1 M-element sorts, 26 fused stack-ups over 7 M elements; roughly 0.1–0.3 s expected |

W4 and W5 are the workloads where Sea's margin over MATLAB is expected to be smallest, because
their dominant costs (a sequential dependency chain; memory traffic) are not things a compiler
can remove. Decision 1 in §9 states what the exactness rules cost on top.

### 5.6 What is not done

No automatic parallelism (single-threaded, like the kernels and the benchmark rules); no
reassociation or contraction for speed (LANGUAGE.md §6.8, Decision 1); no loop interchange or tiling of user
loops (the programmer's loop order is the operation order); no profile-guided or link-time
optimization beyond pass 2b's whole-program reachability.

### 5.7 Benchmark methodology

**Kernels** (`sea/bench/`): Baysick's methodology (`docs/BENCH.md`) unchanged — single-threaded
on both sides, a monotonic clock, untimed warm-up, ≥ 5 repetitions and ≥ 1 s per measurement,
the median reported with min and max, validation before timing, the vendor library (Accelerate /
OpenBLAS / the vendor libm) as one bar and the measured instruction-set peak as the other, machine,
load and variant recorded. Sea's own kernels (GEMV, LU, Cholesky, triangular solve, sort, vector
`log`/`exp`/`sin`/`cos`/`pow`) are measured this way, in Baysick's TSV format. The harness may be C
(built with `xcrun cc` / `gcc`), as Baysick's `bench/` is, because it is a measuring tool and
never part of Sea.

**Workloads versus MATLAB** (§6.5) cannot follow the kernel rules exactly, and the differences
are stated rather than hidden:

* **Threads.** The MATLAB baseline (`baseline_timings_matlab.json`, §1.2) ran with MATLAB's
  default thread count (`maxNumCompThreads` = 10), so its BLAS/LAPACK calls (W2's solves) may use
  several cores; Sea is single-threaded. The comparison is "Sea against MATLAB as users run it",
  which favours MATLAB. The single-threaded MATLAB run (`baseline_timings_matlab_1thread.json`)
  is reported alongside, not compared.
* **Repetitions.** The baseline is the best of 5 runs (first run included), still with visible
  variance (W2 compute 0.94–1.96 s). Sea is therefore compared with the **same rule: best of 5**
  consecutive runs (the first included). The median of those 5 runs is compared with MATLAB's
  five-run median, and the median and spread of 10 further Sea runs are reported next to them;
  neither is used for the pass/fail.
* **Same machine**: the comparison is valid only on the machine that produced the baseline,
  which must be recorded (§6.5).

## 6. Testing and conformance

### 6.1 Principles (Baysick's, unchanged)

* **Expected outputs are derived from the specification, never from what the implementation
  prints.** If they disagree, the implementation is wrong unless the spec is changed on purpose.
* Every normative rule of LANGUAGE.md §3–§13 has at least one test; every error message has a test that
  produces it.
* Both targets must pass the same tests byte for byte (§6.6).
* No placeholder expected files: a test whose expected output cannot be derived by hand from the
  spec is not added until the spec says enough. (This is why v1 plot tests are structural,
  LANGUAGE.md §12.8.)

### 6.2 Test layout

```
sea/tests/
  programs/NAME.sea   + NAME.out (expected stdout)  [+ NAME.in (stdin), NAME.args (one argument
                      per line), NAME.err (expected stderr), NAME.status (expected exit status),
                      NAME.files/ (fixtures copied into the working directory),
                      NAME.expect/ (files that must exist afterwards, byte-exact)]
  errors/NAME.sea     + NAME.err (the expected compile-time or run-time diagnostic) + NAME.status
  passes/NAME.sea     + NAME.ast | NAME.res | NAME.hir1 | NAME.hir | NAME.lir1 | NAME.lir (the
                      --emit dumps of §3, built with --no-prelude, §3.8; pinned like Baysick's
                      tests/ir); every NAME.hir1 has a NAME.res (the input of seacheck in
                      stage.sh), and a NAME.res without NAME.hir1 is a program whose sea.res
                      holds an rerr (seaname hands an error on, §3.4.1)
  plots/NAME.sea      + NAME.struct (the expected structure of each SVG it writes, LANGUAGE.md §12.8)
  math/               elementary-function identity tests (§4.10.6): <fn>.vec vectors written by
                      vectors/math_vectors.py from the model vectors/math_model.py, and the
                      C harness math_check.c that checks libsea.a against them (`make
                      test-math`, also in the cross run)
  link/               the link-map check of §4.3
  include_check.s, include_check_x86_64.s, include_asserts.inc
                      the contract-file checks of §2.6: Sea's .inc files assembled after
                      Baysick's include/limits.inc and include/runtime.inc, with the layout,
                      code-range and table-size assertions (`make check-includes`, Apple as;
                      `make -f Makefile.linux check-includes`, GNU as)
  cross_includes.sh   copies those files to the Linux host and runs the GNU as check there
                      (`make cross-includes`)
  check_contracts.sh  the drift check (`make check-contracts`, run first by `make
                      check-includes`; POSIX sh and awk): every SEA_* name and value and every
                      error, errno and entry record of the .inc files equals the tables of §2.6.1,
                      §2.6.2 and §4.8, and every record format of passes.txt equals the tables
                      of §3.2–§3.6 (§3.9), in both directions
  run.sh              Mac runner of programs/, errors/ and the passes/ dumps (it compiles with
                      the test's directory as working directory, so diagnostics name NAME.sea);
                      cross.sh, cross_pack.sh, cross_run.sh: the x86_64-linux cases on the
                      Linux host (§6.6.1, `make cross`, `make cross-pack`)
  NAME.status         the expected exit status: a decimal number and LF
  harness/            Baysick test programs of the shared modules (limb, f64emu, fltlit) that
                      read the committed vectors
  arith_check.sh      runs harness/ on vectors/ (exact arithmetic and float literals)
  lib_check.sh        checks passes/lib against the contract (e.g. the BAD_DATA copy, §2.6.2)
  driver_check.sh     the driver's options, messages and statuses (§2.2)
  passes/NAME.out     (optional, beside a dump test) the program's expected standard output when
                      built and run
  passes/NAME.lir     with neither NAME.sea nor NAME.lir1: a pass-4 test, LIR written by hand
                      (the input of seagen_a64, §3.6); + NAME.out (the expected standard output)
                      [+ NAME.err, NAME.status]. stage.sh runs seagen_a64 on it, assembles the
                      sea.s with `as`, links it with libsea.a and libbaysickrt.a as the driver
                      does, runs the program with standard input /dev/null and compares
                      standard output with NAME.out, standard error with NAME.err (else empty)
                      and the exit status with NAME.status (else 0)
  NAME.meta           (optional, beside a programs/ or errors/ test) `key=value` lines for the
                      runner: `stdout=epipe` connects standard output to a pipe whose reading
                      end is closed before the program starts (for `cannot write '<stdout>':
                      Broken pipe`, LANGUAGE.md §9.2); `stdout=closed` starts the program
                      with standard output closed (`>&-`, for `cannot write '<stdout>': Bad
                      file descriptor`); with either key NAME.out is not compared
  rt/arm64_macos/NAME.s, rt/x86_64_linux/NAME.s (§4.7.1) a runtime test: an assembly program, in
                      Baysick's assembly style, that calls runtime entry points through rt.inc
                      and is linked with libsea.a; + NAME.out [+ NAME.err, NAME.status], the
                      expected bytes derived from LANGUAGE.md and §4 (`make test-rt`)
  stage.sh            runs one pass on the committed golden output of the previous pass
                      (passes/NAME.ast → seaname → compare with NAME.res, NAME.res → seacheck →
                      compare with NAME.hir1, and so on), so each pass is tested on its own (`make test-stage`); a passes/NAME.lir with
                      neither NAME.sea nor NAME.lir1 is the input of a pass-4 test (above)
  protocol.sh         the pass-protocol tests (truncated inputs, missing #end, §2.2), for every
                      pass program (seaname on a truncated sea.ast, seacheck on a truncated
                      sea.res, …)
  check_data.sh       checks the generator (§2.6.3) on the contract files: every generated
                      line ≤ 255 bytes, every record present (`make check-data`)
  vectors/NAME.py     generators of exact test vectors (float-literal bits, printf digits),
                      run with `uv run`; their outputs are committed beside them, and the tests
                      read only the committed outputs (Python is never needed to run a test)
```

Test names carry the spec area: `lex_*`, `res_*` (`sea.res`, §3.4.1), `type_*`, `idx_*`, `op_*`, `stmt_*`, `fn_*`, `elem_*`,
`err_*`, `lib_*`, `fmt_*`, `json_*`, `plot_*`, `la_*`, `perf_*`.

* **Format tests** compare `printf` output for chosen values against the bytes the C99 rules give
  (the expected bytes are worked out from the exact binary values, including tie cases).
* **Literal-conversion tests** pin the bits of hard decimal-to-binary cases.
* **Folding tests** check that expressions near the limits of §2.8 (overflowing products,
  division by zero, `sqrt` of a negative constant, `inf`/`nan` operands) compile, are not
  folded, and give the IEEE results at run time.
* **Elementary-function tests** (`math/`) check the ≤ 1 ulp bound against reference values
  computed at high precision (the reference generator is a script run with `uv run --with
  mpmath`; Python is only ever run through `uv`), check that results which are exactly
  representable (`pow(2, 10)`, `exp(0)`, `log(1)`) are exact, and check that scalar and vector
  forms and both targets give identical bits.
* **Plot tests** (`plots/`): a `.struct` file lists, per SVG, the expected counts of plot areas,
  polylines, markers, bars, images and `<line>` contour segments, and the exact texts (titles,
  labels, legend entries, tick labels) — all derivable from LANGUAGE.md §12 by hand for tiny figures — and
  the runner checks well-formed XML, the structure, and identical bytes on both targets.
* **Linear-algebra tests** use exact data (small integer matrices with exact factorizations and
  solutions), as Baysick's product tests do, so even class-R results are exact and identical,
  plus ∞/NaN propagation tests and empty-operand tests.
* **Pass-protocol tests** feed each pass a truncated input (no `#end`) and check status 11 and
  the one line `<pass>: internal error: truncated input` on standard error, and check that the
  driver rejects a pass output without `#end` (§2.2).
* **Tests of the pass-2a split** (phase 4a, §3.4.1, §2.6.2 "Which program reports it"): a
  `NAME.res` beside every `NAME.hir1` dump test, hand-derived from §3.4.1; the example `rs` of
  §3.4.1 (`rs.sea`, `.ast`, `.res`, `.hir1`); `res_*` dump tests (`NAME.sea`, `.ast`, `.res`) for
  every replacement record and every outcome: `rname` of each kind (a local shadowing an outer one,
  `var lo = lo`, a loop variable, a block scope, a struct name, an undeclared name), `rint` with
  `fv` `-` and the 2⁶³ literal, `rcni rcnf rcnb`, `rcne` (`ovf`, `div0`), `rcn` (an expression
  `seaname` cannot type or evaluate, and a constant naming one without a value), a cycle, a
  skipped region (a `match`, a `for` over an array) copied unresolved, `rpowk` from a constant and none
  where a local shadows the constant, a not-entered function copied unchanged, `rtup` reused;
  and an `rerr` of each error `seaname` reports, the first of two by position, and the first
  found of two at one position; `errors/` tests of the merge: a `seaname` error after and before
  a `seacheck` error in source order, two at one position (`not supported yet: elemental
  functions` and `missing return` at one `fn` keyword: the first is reported), a constant's
  `integer overflow` before and after another error. Every test of the corpus (`programs/`,
  `errors/`, the dumps, `rt/`, `math/`) passes unchanged; the scripts `driver_check.sh`,
  `protocol.sh` and `stage.sh` change as §8 (4a) lists.
* **Constants without a value** (Decision 25, sub-phase 4a-0; LANGUAGE.md §7.2): `errors/` tests,
  the lines below are lines 1, 2 (and 3) of each file (a comment, if any, follows them), and
  the expected output is derived from the rule:
  `err_const_noval_overflow`: `const B = 9223372036854775807 + 1 + A` / `const A: i64 = 1 + x`
  prints `err_const_noval_overflow.sea:2:20: error: undeclared name 'x'` (before the rule
  `1:11: integer overflow`); `err_const_noval_pow`: the same with `const A: i64 = pow(2.0)`,
  `…:2:16: error: no overload of 'pow' accepts (f64)`; `err_const_noval_errtype`: `const B = A +
  1 % 0` / `const A = f()` / `fn f() -> str { return 1 }`, `…:3:11: error: not supported yet:
  strings` (`A` has the error type and no value, so `B` is not evaluated and its `1 % 0` reports
  nothing; before the rule `1:15: integer division by zero`); all with status 1.

### 6.3 Workload acceptance

`sea/ports/w1_shaft_design.sea` … `w5_tolerance_mc.sea` are the ports. `sea/tests/accept.sh`
(both targets) for each port:

1. builds it; runs it in a fresh directory with `--export-reference`, capturing stdout;
2. checks the JSON against `sea/workloads/reference/<name>.json` with `compare.py`'s rules, run
   as `uv run --no-project --with numpy python reference_py/compare.py --candidate <dir>
   <name>`. The `--candidate` option (a change to the workload repository, Decision 7 in §9)
   compares `<dir>/<name>.json` instead of the NumPy file with the same `RULES`, with one
   stricter rule for the near-tie keys: for an `argmax_tol`/`argmin_tol` key (W2's `r_worst`,
   `e_crit0`), the candidate's index must be **exactly** the first 1-based position of the
   extremum of the candidate's own exported array (`util_removed`, `fos0`), NaN ignored, and the
   MATLAB array's value at that index must be within the rule's `rel` of the MATLAB extremum.
   The first condition is structural: a port that forgot to add 1 points at the element before
   its own extremum and fails even if that element is a near-tie of MATLAB's;
3. checks the report (§6.4);
4. with `--figures`, checks that the SVG files exist, are well-formed XML and have the panels and
   series of the MATLAB figure (one structural file per port, written from the MATLAB script);
   their content is not compared with MATLAB's PNGs.

Indices in the JSON must be MATLAB's 1-based numbers (the port adds 1, LANGUAGE.md Appendix D); the keys
with `exact` rules (`rank`, `k_worst`, `i_best`, `lcg_final`, counts, …) check this.

### 6.4 Report equivalence

**Reference text.** The MATLAB report texts are stored (Decision 7 in §9, sea commit c1736f7):
`run_all.m` captures each script's report with `diary` on the last repetition into
`sea/workloads/reference/<name>.txt`, committed for the five workloads from the user's rerun
(M2 Pro, MATLAB R2026a).

**Token map.** Each port has a file `sea/ports/<name>.tokens` that says how each numeric token
of the report is judged. One line per report-line pattern:

```
<line regex>  <token number>  <rule>
```

where the regex matches the report line (POSIX extended, anchored), the token number counts
blank-separated tokens from 1, and the rule is one of `compare.py`'s rule kinds applied to the
two tokens read as numbers.

**Reading a token.** Before a token is parsed, three characters are stripped, in this order: one
trailing `,`, `;` or `:`; then one trailing `)`; then one leading `(`. Each stripped character, or
its absence, must be the same on both sides (otherwise the lines differ). A stripped token that
contains `..` is split at its first `..` into two parts, each judged as a token of its own (so
`(0.1000,` is the number `0.1000`, and `0..5` the numbers `0` and `5`). A token or part is
**numeric** if it then parses as a decimal number (optional sign, digits with an optional
decimal point, optional exponent `e`/`E` with sign); a non-numeric token or part must be identical
as text on both sides. A token-map entry that names a token split at `..` applies its rule to
both parts.

The rules are: `exact`, `int n`, `num atol rtol`, or `json <key>`. A `num atol rtol` rule
passes when |c − r| ≤ atol + rtol·|r|, where r is the reference token's number and c the
candidate's (`rtol` is scaled by the magnitude of the reference token). A `json <key>` rule uses
the rule of that JSON key; for a key whose rule is relative to the key's largest magnitude, the
scale is taken from the reference JSON; for a key whose JSON rule is `argmax_tol` or
`argmin_tol`, the token passes when the reference token equals the MATLAB JSON value of that key,
the candidate token equals the candidate JSON value of that key, and the candidate JSON passes the
own-extremum rule of §6.3. A numeric token not listed is judged by the **default rule** (a value
within one unit of the last printed digit): the two tokens pass if they are equal as text, or if
|a − b| ≤ u, where a and b are their values and u is the larger of their two **units**; the unit of
a token is 10^(e − d), where e is its printed exponent (0 if it has none) and d the number of
digits after its decimal point (0 if it has none). The comparison is exact decimal arithmetic on
the printed digits, never floating point. So `9.99e-05` against `1.00e-04` (u = 10⁻⁶),
`9.9999` against `10` (u = 1) and `0.999` against `1.000` (u = 10⁻³) pass, and `1.5` against
`1.7` (u = 0.1) fails. Example (W5; the report lines are those of LANGUAGE.md Appendix D):

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
never from Sea output (§6.1), and reviewed with the port.

### 6.5 Workload benchmarks

`sea/bench/workloads.sh`, on the machine of the MATLAB baseline:

* builds each port once (compile time reported separately);
* runs it 5 times, then 10 more times, each with `--export-reference` in a fresh directory,
  measuring whole-process wall time with a small exec-and-wait harness
  (`clock_gettime(CLOCK_MONOTONIC)` around `posix_spawn` + `waitpid`), and reading the program's
  own `Compute time` line;
* reports, per workload: the first run, the best of the first 5 (the pass/fail number, the same
  rule as MATLAB's baseline, §5.7) and their median, and the median and range of the 10 further
  runs; compute and whole-process; next to MATLAB's
  first, median and best from `baseline_timings_matlab.json` (§1.2) and the single-threaded
  first, median and best from `baseline_timings_matlab_1thread.json`, and the ratios; plus machine model, macOS version, kernel variant, load average before and after
  (BENCH.md conventions);
* **passes** when, for every workload, Sea's best-of-5 whole-process time < MATLAB's best
  `total_seconds` and Sea's best-of-5 compute time < MATLAB's best `compute_seconds` (§1.2).

The MATLAB rerun of Decision 7 is committed (sea commit c1736f7): `baseline_timings_matlab.json`
(default thread count, the pass criterion, as Decision 7 chose) and
`baseline_timings_matlab_1thread.json` (`maxNumCompThreads(1)`, reported), five repetitions
each. The same script also compares Sea's medians with the default baseline's medians and
reports the single-threaded MATLAB numbers beside them. The same script runs on the Linux host
for the x86_64 numbers (reported, not compared with MATLAB, which has no Linux baseline).

### 6.6 Cross-target identity

* **Spec tests**: standard output, standard error, exit status and written files are
  byte-identical on `arm64-macos` and `x86_64-linux` (and for every kernel variant, run with
  `SEA_KERNELS=<variant>`). Tests involving class-R operations use exact data (§6.2).
* **Ports W1, W4, W5** use no class-R operation: their reports (except the compute-time line),
  JSON and SVG files must be byte-identical across targets and variants.
* **Port W3** uses class-R operations in exactly two places: `eig_sym` for the natural
  frequencies (`f_nat`) and the 3 × 3 `solve` of the parabolic refinement (`c_best`). Its road
  (`sin(argR) @ Ak`, a class-E matrix-vector product) and its whole RK4 simulation are class E.
  So all of W3's outputs except `f_nat` and `c_best` (and the report tokens that print them)
  must be byte-identical across targets; those two are compared with the acceptance rules.
* **Port W2** solves with `chol`/`lu` (class R) throughout; its outputs are compared across
  targets with the acceptance rules (§6.3–§6.4), not byte for byte. Its `K @ u0` reactions
  are class E given the same `u0`.
* `x86_64-linux` output is produced by the cross scripts as Baysick's are (`sea/tests/cross*.sh`
  on the ssh host, default `desktop`; §6.6.1).

#### 6.6.1 Cross testing x86_64-linux

As in Baysick (Baysick DESIGN.md §8.3), compiling happens only on the Mac (the passes are macOS
Baysick programs) and the run half on the Linux host. Three POSIX `sh` scripts and two make
targets do it; every spec test that runs a program is a cross case, and the expected files are
the same files the Mac uses (one set for both targets).

**Cases.**

* `programs/NAME`: every program test.
* `errors/NAME` whose program compiles: the run-time error tests. A test whose `sea build`
  fails with status 1 and exactly `NAME.err` on standard error (and `NAME.status` 1) is a
  compile-time test, target-independent (it never reaches pass 4), checked on the Mac only, and
  skipped silently; any other failure is a pack failure.
* `passes/NAME` with a `NAME.out`: the program built with `--no-prelude` and run (§6.2).
* `passes/NAME.lir` pass-4 tests (hand-written LIR, §6.2): the file with its `#target` record
  replaced by `#target x86_64-linux`, run through `seagen_x64` on the Mac.
* `rt/NAME`: every `tests/rt/x86_64_linux/NAME.s` (§4.7.1). Its `.meta` may hold
  `stdout=epipe`, `stdout=slowpipe` and `env=NAME=VALUE` lines (`SEA_KERNELS` and
  `BAYSICK_KERNELS` otherwise unset) and nothing else: no `requires=` (§4.7.1). A program case's
  `.meta` may hold only `stdout=epipe` and `stdout=closed` (§6.2). `cross_run.sh` stops with
  exit 2 on any other line, an empty line excepted.

**An extra case, `math/math_check`.** Besides the program cases, `make cross` runs one case on the
host: `cross_pack.sh` copies `tests/math/math_check.c` and `tests/math/*.vec` into
`<bundle>/tests/math/` (a setup error if there is no `.vec` file), and `cross_run.sh` builds the
harness there with ` -O1 -ffp-contract=off` against `build-x86_64-linux/libsea.a` (`-lm`;
any compiler output is a FAIL) and runs it on `<bundle>/tests/math` under the case timeout
(60 seconds); it passes when the exit status is 0 and standard error is empty (§4.10.6). The
pattern `math/math_check` selects it.

The dump tests (`--emit`) and the other Mac groups (`stage.sh` dumps, `protocol.sh`,
`lib_check.sh`, `arith_check.sh`, `driver_check.sh`, `check_data.sh`) are target-independent and
run only on the Mac (`make test`).

**Bundle** (a self-contained directory made on the Mac, consumed on Linux):

```
<bundle>/BUNDLE                       one line: "sea-x86_64-linux-bundle 1"
<bundle>/Makefile.linux               Sea's
<bundle>/include/limits.inc errors.inc rt.inc
<bundle>/runtime/x86_64_linux/*.s
<bundle>/tests/cross_run.sh
<bundle>/tests/include_check_x86_64.s tests/include_asserts.inc
<bundle>/tests/rt/run_rt_linux.sh     tests/rt/x86_64_linux/NAME.s + sidecars
<bundle>/baysick/Makefile.linux       Baysick's, with its include/*.inc and
<bundle>/baysick/include/*.inc        src/runtime_x86_64_linux/*.s (the x86_64
<bundle>/baysick/src/runtime_x86_64_linux/*.s   libbaysickrt.a is built from them)
<bundle>/cases/<kind>/NAME.s          the program as compiled on the Mac, kind programs,
                                      errors or passes
<bundle>/cases/<kind>/NAME.out .err .status .in .args .meta, NAME.files/, NAME.expect/
                                      copies of the sidecars present
<bundle>/cases/<kind>/NAME.packfail   instead of NAME.s when compiling failed: "status <n>",
                                      then the compiler's standard error
```

**`tests/cross_pack.sh -o BUNDLE_DIR [PATTERN...]`** (Mac). `BUNDLE_DIR` must not exist or be
empty (else exit 2); PATTERN selects cases whose name contains it, as in `tests/run.sh`.
Environment: `SEA` (the driver, default `build/sea`), `BAYSICK` (the Baysick checkout, default
the parent of the Sea repository). Each case is compiled with the driver run in the test's own
directory with the bare file name, exactly as `tests/run.sh` does (so the site table names
`NAME.sea`): `sea build --target x86_64-linux -S -o <bundle>/cases/<kind>/NAME.s NAME.sea`
(`--no-prelude` for passes/); a pass-4 test runs `seagen_x64` on the retargeted LIR in a scratch
directory (the pass's file protocol, §2.2). The compile must exit 0 with empty standard output
and standard error, else `NAME.packfail` is written (the errors/ rule above decides first). It
prints `packed: <n> cases (<m> failed to compile)` and exits 0 when the bundle is complete, 2
on a setup error (driver or `seagen_x64` missing, bad `-o`, copy failure). `make cross-pack`
writes `build/x86_64-linux-bundle` (removed first).

**`tests/cross_run.sh [-v] [BUNDLE_DIR]`** (Linux; default the directory above the script).
Environment: `SEA_TEST_TIMEOUT` (seconds per run, default 10), `AS` (default `as`), `CC`
(default `gcc`), `SEA_KERNELS` (passed to the programs when set). Setup (failure → message,
exit 2): the `BUNDLE` line; `make -C BUNDLE_DIR/baysick -f Makefile.linux all AS="$AS"`; `make
-C BUNDLE_DIR -f Makefile.linux check-includes all BAYSICK=baysick AS="$AS"`. Per case, in a
`mktemp -d` directory: a `NAME.packfail` is a FAIL (`compile (on the Mac) failed`); otherwise
`$AS --64 -o prog.o NAME.s` and `$CC -no-pie -o prog prog.o <libsea.a> <libbaysickrt.a> -lm` (an
`rt/` case also links `obj/rt_main.o` first, §4.7.1), each of which must exit 0 with **empty
standard error** (a warning is a FAIL: `assemble failed` / `link failed`); then the program runs
exactly as `tests/run.sh` runs it on the Mac: in a fresh working directory holding the copied
`NAME.files/`, standard input `NAME.in` or `/dev/null`, the arguments of `NAME.args`, the
`NAME.meta` keys (`stdout=epipe`, `stdout=closed`, with the same mechanisms), the timeout.

**What "byte-identical" compares.** For each case, against the same expected files as on the
Mac: standard output with `NAME.out` (not compared under a `stdout=` key; empty when absent for
errors/), standard error with `NAME.err` (empty when absent), the exit status with
`NAME.status` (0 when absent), every file of `NAME.expect/` byte for byte, and that the working
directory holds nothing else but unchanged fixtures. The output format and exit status of the
script are those of `tests/run.sh` (`FAIL <name>: <reason>`, `----`, `passed: P  failed: F`,
`failed tests: …`; 0, 1, or 2 on a setup error).

**`tests/cross.sh [-v] [-H HOST] [PATTERN...]`** (Mac, the one command; `make cross`). Host:
`-H`, else `$SEA_CROSS_HOST`, else `desktop`, reached with `ssh -o BatchMode=yes --`. It packs
into a local `mktemp -d` directory, streams it as `tar -C <bundle> -cf - .` into one `ssh` call
whose remote `sh -c` script (no single quote in it) unpacks into a remote `mktemp -d` directory,
removed on exit and on HUP/INT/TERM/PIPE, and runs `SEA_TEST_TIMEOUT=<value> [SEA_KERNELS=<value>]
sh "$d/tests/cross_run.sh" [-v] "$d"`; `SEA_KERNELS`, when set, must be letters, digits and
underscores (else exit 2). Exit: the status of `cross_run.sh`; 2 if packing or `ssh` fails or
the remote status is anything else. Nothing is left on the host. All three scripts treat
HUP/INT/TERM/PIPE by removing their temporary directory and exiting 2, and match patterns
literally.

Phase 2 is done (§8) when `make cross` passes every case and `make cross-includes` passes, with
`make test` still passing on the Mac.

Phase 3 is done (§8) when, in addition, `make test-math` passes on the Mac (part of `make test`) and the
`math/math_check` case of `make cross` passes on the host (§4.10.6), with the `lib_math_*` programs
passing in `run.sh` and in the cross run.

## 7. What Baysick must grow

### 7.1 Needs of the compiler, against Baysick 0.6.0

Every need of the compiler, checked against Baysick 0.6.0 (`docs/SEA_BOOTSTRAP.md` §2 rows and
LANGUAGE.md), with the calibration of §2.7:

| Compiler need | Baysick 0.6.0 | Sufficient? |
|---------------|---------------|-------------|
| read the source verbatim, detect end of input | `LINPUT #0` + `IF END #0` | yes, with the `#end` discipline (§2.2), because plain end of input exits with status 0 |
| options, file names | stdin header (§2.2) | yes, by the no-argv decision |
| input/output files per pass | `FILES` (≤ 8, fixed names), `PRINT #`, `LINPUT #` | yes: ≤ 2 per pass |
| diagnostics and failure status | `PRINT #-1`, `STOP e` | yes |
| strings: length, substring, search, concatenation, codes | `LEN SEG$ POS & ASC CHANGE STR$` | yes, avoiding the blank-padding traps (§2.7) |
| numbers to text | `STR$` (exact for integers < 10⁹) and digit arithmetic | yes |
| exact `f64` bit patterns, big integers | doubles exact below 2⁵³, arrays as limbs (§2.8) | yes |
| constants above 9 digits | built by arithmetic or read from `DATA` | yes, awkward |
| program size | 10 000 lines per program, 16 `SUB` parameters, no globals | **tight**: the passes measure 2 349–5 403 lines each in phase 1 and are re-estimated at about 42 000–53 000 lines in all for v1, with pass 2a reaching 10 000 around phase 6 and pass 3a near it from phase 7 (§2.7) |
| tables | arrays ≤ 10⁶ elements, 2-D string arrays, by-reference array parameters | yes, giving the capacity limits of §2.7 |
| message and template text | string constants ≤ 65 536 bytes outside `DATA` | yes, by keeping text in `DATA` |
| writing assembly text | `PRINT #` of strings writes bytes unchanged | yes |

**Conclusion.** No Baysick language change is needed to start, and none is proposed now. The
honest risk is size: the line limit and the absence of globals make the larger passes long and
repetitive, and the phase-1 recalibration of §2.7 puts pass 2a at the 10 000-line limit around
phase 6 and pass 3a near it from phase 7. §7.3 states the policy for that case (split the pass first);
Decision 2 in §9 agrees it in advance.

### 7.2 Changes to Baysick's runtime kernel contract

The GEMM reuse of §4.3 needs a **runtime contract change in Baysick** (no language change):

1. a new entry point `_bsk_kern_gemm_sub(C, A, B)`: `C ← C − A·B`, same view rules, statuses,
   blocking and class-R rules as `_bsk_kern_gemm`, implemented in all three variants
   (`baseline`/`neon` on arm64, `sse2`/`avx2` on x86_64);
2. the finite-input precondition of `_bsk_kern_gemm` and the new entry is replaced by IEEE
   propagation of non-finite inputs, with tests on every variant (Baysick's own MAT statements
   keep their `KS_NONFINITE` checks);
3. Baysick's `include/runtime.inc` and Baysick DESIGN.md §6.6 change together (Baysick's contract rule),
   and Sea's `rt.inc` names the Baysick version it was built against.

The link-isolation property Sea relies on (`rt_kinit.o` + `rt_k*.o` pulled alone from
`libbaysickrt.a`, §4.3) is already a Baysick rule; a Sea link test watches it. No new archive
or build target is needed. Decision 5 in §9 rejected the alternatives (Sea owns its GEMM, or a
shared kernel repository).

### 7.3 Growth policy for the language

If a measured need appears (a pass that cannot be written within a limit), the response is, in
this order:

1. **Restructure without Baysick changes**: split the pass into two programs with an
   intermediate file; move text to `DATA`; pack tables; build constants by arithmetic. (Applied
   first in phase 4a: pass 2a becomes `seaname` and `seacheck` with the file `sea.res`, Decision
   17, §2.7; the planned next seam is `sealoop` before `sealower`, §2.7.)
2. **Grow Baysick only on a measured need**, one change at a time, through Baysick's own
   process (spec first in LANGUAGE.md, `include/*.inc` with its doc section, tests on both
   targets), preferring a feature from a later Dartmouth edition where one exists, and
   otherwise a clearly labelled Baysick extension (Baysick LANGUAGE.md §15).

**Candidates**, with their status (none is proposed now):

| Limit | Candidate change | Dartmouth precedent | When |
|-------|------------------|---------------------|------|
| 10 000 lines per program | raise the 10 000-line limit (line numbers already go to 99 999) | none in the editions implemented (Second–Sixth); a **Baysick extension** | only if a pass cannot be split cleanly (its tables would have to be written and re-read) |
| no global variables; 16 `SUB` parameters | a `COMMON`-style shared block between the main program and its subprograms | Dartmouth's Fifth Edition `CHAIN`/`COMMON` concerns separate programs, not subprograms; this would be a **Baysick extension** | if table-passing overhead or parameter count becomes a measured problem |
| 16 parameters per `SUB` | more parameters | none; **Baysick extension** | only with the previous row rejected |
| 65 536 bytes of string constants | larger limit | none; **Baysick extension** | not expected: text lives in `DATA` |
| 1000 `FOR` statements per program | larger limit | none; **Baysick extension** | not expected (measured 55–127 per pass in phase 1; at most about 450 in v1, §2.7) |
| two-character variable names | longer names | the later Dartmouth editions' long names are not verified against a primary source here; treat as a **Baysick extension** unless such a source is found | readability only; not expected to be needed |

### 7.4 Watch list

| Limit | Expected use | If reached |
|-------|--------------|------------|
| 10 000 lines per program | 2 349–5 403 per pass measured in phase 1; pass 2a split in phase 4a before it reaches the limit (`seaname` 4 900–5 250 and `seacheck` 3 700–4 000 estimated after 4a, 5 900–6 600 and 7 000–9 250 at v1), pass 3a near it from phase 7 (§2.7) | §7.3: split the pass |
| 1000 `FOR` statements per program | 55–127 per pass measured in phase 1; at most about 450 in v1 (§2.7) | split the pass |
| 26 array letters per program unit | 6–8 tables per pass | pack tables into 2-D arrays |
| 10⁶ elements per array | the tables of §2.7 | lower a capacity limit or split the table |
| 1024 active `CALL`s | parser recursion ≤ nesting 64 × about 5 levels | iterative parsing of operator chains |

## 8. Milestones

Each phase ends with its "done when" checked by tests on **both targets** (the x86_64 side
through the cross scripts), spec text before code (the house workflow), and nothing left
half-built. Phases 0–2 build the skeleton end to end on the smallest real program.

| # | Phase | Done when |
|---|-------|-----------|
| 0 | **Agreement and contracts.** The decisions of §9 are taken; the document is split into LANGUAGE.md and DESIGN.md with the intermediate record formats (§0, §3); `sea/include/*.inc`, `passes.txt`; the Baysick kernel contract change of §7.2 (in Baysick, by its own process); `compare.py --candidate`, the token maps' format, and `run_all.m` report capture, with the MATLAB rerun (Decision 7) | the user has agreed the documents; include checks pass on both assemblers; Baysick's tests pass with the new GEMM entry |
| 1 | **Scalar core, arm64.** Driver with the `#end` discipline; passes 1–4 for: `i64`/`f64`/`bool`, `let`/`var`, arithmetic with the LANGUAGE.md §6.8 rules, `if`/`while`/`for` ranges, functions with scalar parameters, `ref`, multiple results, `const` items and `pi inf nan eps`, `printf` with `%d %i %f %F %e %E %g %G %s` (string literals only as `%s` arguments), `now()`, `f64()`, `i64()`, `idiv`; every other construct is `not supported yet` (§2.6.2, phase rule); no inlining (§3.6.6), pass 3b validates and copies (§3.6.5), the phase-1 allocator and the stack check (§4.9, §4.6), `std.sea` comments only (§2.5); runtime start-up, formatting, errors (`sea_printf`, `sea_now`, §4.8); float-literal conversion; the build of §2.6.3 and the layout of §2.10; **recalibration** of the size estimate of §2.7 from the real passes | a Sea program running W5's LCG for 11 M steps prints `lcg_final` = 2145635252 (the reference value) and the first uniforms bit-exact; spec tests for this subset pass; the estimate is updated in §2.7 |
| 2 | **x86_64 target.** `seagen_x64`, the x86_64 runtime for the same subset, `cross*.sh` | the phase-1 tests pass byte-identically on the Linux host |
| 3 | **Elementary functions.** Sea's own scalar `log exp sin cos pow hypot` on both targets (Decision 6) | `math/` tests pass on both targets: ≤ 1 ulp against the high-precision references, identical bits on both targets (§4.10.6: the runtimes reproduce the model's bits for every committed vector on both targets; the generator has checked each vector against mpmath; the `lib_math_*` programs pass in `run.sh` and the cross run) |
| 4 | **Arrays and structs.** Dynamic and fixed arrays of `f64`/`i64`/`bool`/`str`, indexing, slices, masks, `$`, views, bounds checks, COW, broadcasting, element-wise operators (one loop per operation at first), reductions in the pinned order, `linspace`, `zeros`…, `sort`/`argsort`, `find*`, `bincount`; structs, arrays of structs and projection, records, `str` and `match`, `error`, `args()`, and the exact math functions, `ind2sub`, `sub2ind`, `lower`, `str(x)`, `meshgrid`, `setdiff` (Decision 23); built in the serial sub-phases 4a–4h below (Decisions 17–24) | W4's scalar SOR solver reproduces `it_sor` (±1 rule) and `T_max`; W5's sampling and statistics reproduce `first_dev`, `mean_cold`, `std_cold`, `hist_counts` using the `Dim` struct array of LANGUAGE.md Appendix D; checked by `compare.py --keys` on the Mac and byte identity on the Linux host (Decision 19) |
| 5 | **Scalar code quality.** Linear-scan allocation, invariant hoisting, strength reduction, bounds-check elimination, magic division | the W5 LCG and W4 SOR loops meet the §5.2 instruction shapes (checked on `-S` output); a micro-benchmark of each is recorded |
| 6 | **Functions and output.** Elemental functions, the inlining rule of LANGUAGE.md §8.6, named and default arguments, `format`, `write_json` (intrinsic and runtime emitter) | W1 and W5 complete (without figures): JSON passes `compare.py --candidate`, reports equivalent, outputs byte-identical across targets |
| 7 | **Fusion and SIMD.** Statement and adjacent-statement fusion, fused reductions, vectorized loops (NEON; SSE2 + AVX2 multiversioning), vector forms of the elementary functions (bit-identical to the scalar forms), buffer reuse | W1's grid bisection and W4's red-black solver run fused (no temporaries in `-S` output); W4 complete; every earlier output unchanged bit for bit |
| 8 | **Linear algebra.** `@` via Baysick's GEMM, Sea's GEMV, LU, Cholesky, triangular solves, `solve`, `rcond`, `eig_sym`; Sea kernel variants | W2 and W3 complete and accepted on both targets |
| 9 | **Plotting.** The runtime's `Figure`/`Axes` objects, SVG writer, contours, embedded PNG images | the plot tests pass; every port writes its figure with `--figures` and passes its structural check |
| 10 | **Benchmarks.** `sea/bench/` kernel and workload benchmarks, published methodology and results | §6.5 passes for all five workloads on the baseline machine; results and machine recorded in `sea/docs/BENCH.md` |

**Phase 4 sub-phases** (decided 2026-10-21, Decisions 17–24). They run in this order, because each
touches the passes the next one extends; inside a sub-phase the passes are written in parallel
against hand-written goldens (stage.sh). Each starts from its specification text and ends with
`make test` and `make cross` passing.

| Sub-phase | Contents | Done when |
|-----------|----------|-----------|
| 4a-0 | **Decision 25 in the single `seacheck`** (precondition of 4a, its own change): a constant that names a constant without a value, or whose type is the error type, is not evaluated (LANGUAGE.md §7.2, §3.5.2); the `errors/` tests of §6.2 ("Constants without a value") | every earlier test passes unchanged (the existing tests of constants, `err_const_*`, `err_not_constant_cycle` and the overflow and `%` tests, keep their output under the rule) and the three new tests print their derived output |
| 4a | **Split of pass 2a and scaffolding; no change of behaviour.** `seaname` and `seacheck` as §2.1, §2.6.2 ("Which program reports it"), §2.6.3 and §3.4.1 say; `--emit res` and the driver's pass sequence (§2.2); `Makefile`, `tools/passlines.sh`, `tools/seaval.bas` (format `res`), `tests/run.sh` (dumps `res`), and these test scripts: `tests/stage.sh` (the pair `seacheck ast hir1` becomes `seaname ast res` and `seacheck res hir1`), `tests/protocol.sh` (a truncated `sea.ast` for `seaname`, a truncated `sea.res` for `seacheck`, `seaname` in the pass lists, files and fake-pass chain), `tests/driver_check.sh` (the usage line with `--emit ast\|res\|hir1\|hir\|lir1\|lir`, the pass logs with `seaname`, the fake passes, `--emit res`), the `--emit` list and the pass list in `CLAUDE.md`; the tests of §6.2 ("Tests of the pass-2a split"); `sealower.bas` cut into `sl0main.bas` and `sl1scal.bas` (§2.7). Not changed: LANGUAGE.md (beyond 4a-0's rule), every other intermediate format, `sea.hir1` byte for byte, every message, position and exit status of every compilation that exceeds at most one capacity limit (§2.6.2 states the two orders that differ for a compilation over two limits at once), `errors.inc`, `limits.inc`, `rt.inc`, the runtimes, passes 1, 2b, 3a (other than the file cut), 3b and 4 | every test of the corpus passes unchanged (all `programs/`, all `errors/` with byte-identical diagnostics, every dump, `tests/rt`, `tests/math`), the edited scripts pass, and so do the new tests; `make cross` passes; `make check-limits` reports `seaname` and `seacheck` below 9 000 lines and their measured sizes replace the estimates of §2.7 |
| 4b | **Phase-4 specification** (documents and contracts only): LANGUAGE.md (Decision 20's sentence, the clarifications left open in §0), §0, the phase-rule table after phase 4 (§2.6.2), `sea.res` extensions for phase 4 (the extents of type nodes, struct declarations and literal field sets, §3.4.1), the HIR and LIR records and lowering rules of arrays, structs, strings, reference counts and copy on write (§3.5, §3.6), prelude inlining (Decision 18), the runtime ABI (§4.1, §4.2, §4.8, §4.9; Decision 22's split between inline code and the runtime; Decision 24's heap check), the phase-4 acceptance (§6.3, Decision 19); `rt.inc`, `passes.txt`; in the workload repository `compare.py --keys` | `make check-contracts`, `make check-includes` and `make cross-includes` pass; the user has agreed the text |
| 4c | **Runtime foundation and pass-4 support**: allocation, arrays (new, unique, free), strings, `args`, `error` on both targets; `retain`/`release` and the new data records in `seagen_a64`/`seagen_x64`; `seaopt` accepts the new records; `SEA_HEAP_CHECK` (Decision 24) | `make test-rt` and the Linux `test-rt` pass (allocation across size classes and the large-block cache, copy on write of shared and static objects, release of `str[]` and struct arrays, string operations byte-exact, `args`, `error`); the hand-written LIR tests of the new records pass on both targets |
| 4d | **Dynamic arrays core** (`f64`/`i64`/`bool`): array types, `zeros ones filled len rows cols numel`, scalar indexing read and write with bounds checks, `$`, arrays as locals, parameters, results and `ref` parameters, copy on write, reference counts on every exit, `for` over vectors, the scalar exact math functions (Decision 23) | W4's scalar SOR prints `it_sor` 832 ± 1 and `T_max` within 1e-6 (`compare.py --keys` on the Mac) and the same bytes on the Linux host; the sub-phase's tests pass on both targets with no leak under `SEA_HEAP_CHECK=1` |
| 4e | **Array expressions**: ranges, `:`, steps, index vectors and masks (read, assignment, compound assignment), views, range values, array literals and concatenation (Decision 20), fixed-size arrays, `dyn`/`fix`, element-wise operators and comparisons with broadcasting, array `cvt`, `where` and the math functions element-wise | its tests pass on both targets; a W4 program whose set-up uses whole-array code prints the same bytes as 4d's |
| 4f | **Reductions, sorting, searching, library options**: `sum mean variance std max min argmax argmin nnz any all` (with `dim:`), `sort`/`argsort` (with `desc:`), `find find_first find_last`, the named options of library calls (Decision 21) | its tests pass on both targets (summation order, NaN, −0, ties, stability, empty inputs); W4's `T_max` by `max(Thot.flat)` prints the same bytes |
| 4g | **Strings, structs, records, `match`, `error`, `args`** | its tests pass on both targets; the first part of LANGUAGE.md Appendix D (options loop with `match`, the `Dim` array, validation, analytic limits) prints its hand-derived output |
| 4h | **Prelude and W5; close-out**: prelude inlining (Decision 18), `linspace`, `bincount`, `meshgrid`, `setdiff` in `std.sea`, the W5 acceptance program (JSON subset by `printf("%.17g")`, Decision 19), the sizes of §2.7 measured, the retired phase-rule rows removed | the phase-4 "done when" above holds on both targets; `make test` and `make cross` pass; the measured sizes are recorded in §2.7 |

## 9. Decisions (agreed)

Agreed 2026-10-20: the user accepted every recommendation. Each item: the options, the option
decided, and what it affects. Everything else in LANGUAGE.md and this document follows from the
decisions; changing one changes the sections named, and is made in those documents with the
user's agreement.
Ordered by impact. (Column-major layout and the prelude's delivery are decided in the body,
LANGUAGE.md §4.5; §2.5, because no option argued otherwise.)

1. **Exactness versus speed.**
   Options: (a) **exact only**: no FMA contraction, no reassociation outside class R, Sea's own
   FMA-free elementary functions, every class-E result bit-identical on both targets (LANGUAGE.md §6.8);
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
   **Decided: (a) for v1**, and revisit (b) with phase-10 measurements: the speed goal
   has an estimated margin on every workload (§5.5), byte-identical outputs on both targets
   make every test simpler and stronger, and (b) can be added later without changing any
   program. Affects LANGUAGE.md §6.8, §10.4; §4.5, §5, §6.6.
2. **Baysick growth policy and the number of passes.**
   Options: (a) the policy of §7.3 (restructure first, grow Baysick only on a measured need,
   prefer Dartmouth precedent, else a labelled extension), with eight compiler programs (§2.1)
   and no Baysick language change now; (b) raise Baysick's line limit and add a `COMMON` block
   now, before the compiler exists, so passes can be fewer and larger; (c) forbid any Baysick
   change: the compiler must fit Baysick 0.6.0 as it is, whatever the number of passes.
   **Decided: (a).** The calibration (§2.7) says Baysick 0.6.0 is sufficient with an
   estimated 26 000–42 000 lines in eight programs, but the estimate is ±50 %; (a) commits to
   nothing unmeasured and pre-agrees how a measured need is handled. (Recalibrated in phase 1
   from the real passes: about 42 000–53 000 lines, with pass 2a reaching the 10 000-line
   limit around phase 6 and pass 3a near it from phase 7, §2.7; the pre-agreed response is to
   split them, §7.3.) Affects §2.1, §2.7, §7.
3. **Index base.**
   Options: (a) 0-based with half-open ranges `a..b`; (b) 1-based with inclusive ranges, like
   MATLAB and Baysick's MAT. **Decided: (a).** It matches the C/Rust family Sea's syntax
   comes from, half-open ranges compose without `±1`, linear and DOF indices are plain products.
   Cost: ports add 1 to exported indices, which the acceptance checks catch structurally
   (§6.3). Affects LANGUAGE.md §5, every example, LANGUAGE.md Appendix D.
4. **Array semantics.**
   Options: (a) values (copy-on-write) with explicit `ref` parameters for in-place updates, and
   runtime handle types for figures and factorizations; (b) references (NumPy-like aliasing);
   (c) ownership and borrowing (Rust-like moves). **Decided: (a).** MATLAB users'
   expectations, no aliasing bugs, O(1) passing, and `ref` makes in-place updates explicit and
   checkable. (c) is the fastest in theory but adds a borrow checker to a compiler written in
   BASIC. Affects LANGUAGE.md §4.1, §4.5, §8.2–§8.3; §4.2.
5. **Kernel sharing and Baysick's GEMM contract.**
   Options: (a) link Baysick's `libbaysickrt.a` for GEMM and grow Baysick's kernel contract by
   the update entry and IEEE propagation of §7.2; Sea owns every other kernel; (b) Sea writes
   and owns its own GEMM (both targets, all variants), no Baysick change; (c) move all matrix
   kernels into a third shared repository used by both. **Decided: (a).** One copy of the
   hardest kernel (the register-blocked GEMM in three variants), a small and testable change to
   Baysick (the micro-kernel loading `C` instead of zero), no new repository. Cost: a
   cross-repository contract (`include/runtime.inc`, §2.6) and a Baysick change before phase 8.
   (b) costs an estimated 2 000–4 000 assembly lines per target. Affects §2.6, §4.3–§4.4,
   §7.2.
6. **Elementary functions: own or host, and which in v1.**
   Options: (a) Sea's own `log exp sin cos pow hypot` (≤ 1 ulp, identical bits on every target,
   scalar and SIMD), only these in v1 (LANGUAGE.md §10.4, LANGUAGE.md §10.13); (b) the host libm (Apple libm, glibc),
   like Baysick; (c) (a) with the full C set (`tan asin … tanh log2 log10`) in v1.
   **Decided: (a).** It makes every output except linear algebra byte-identical across
   targets (W1, W4, W5 entirely), and fused SIMD loops need vector forms, which the host libms do
   not provide on both targets. Six functions are what the workloads use; each further function
   is weeks of careful work and is added when a program needs it. With (b), §6.6 loses the byte identity of W1/W5 and
   LANGUAGE.md §6.8 gains a host-dependent class. Affects LANGUAGE.md §10.4; §4.5, §6.6,
   §8 phase 3.
7. **Workload-repository changes and a MATLAB rerun.**
   Options: (a) change `sea/workloads/`: `compare.py --candidate` with the own-extremum rule
   (§6.3); `run_all.m` writes each report to `reference/<name>.txt` with `diary` on the last
   repetition, takes `nRepeat` ≥ 5, and records `maxNumCompThreads` and the machine model; then
   the **user reruns MATLAB once** (with the default thread count, and once more with
   `maxNumCompThreads(1)` for a single-threaded comparison), regenerating the reference files;
   (b) only `compare.py --candidate`, no rerun: reports are compared by hand, timings against the
   current 3-run multithreaded baseline. **Decided: (a).** Without stored MATLAB reports
   §6.4 cannot be automated, and the current baseline's variance (W2: 1.05–1.74 s) makes a
   best-of-3 comparison noisy. Which baseline (default or single-threaded) is the pass
   criterion is part of this decision; decided: the default-threaded one, as users run
   MATLAB, with the single-threaded one reported. Affects §1.2, §5.7, §6.3–§6.5. **Done**
   (2026-10-21, sea commit c1736f7): the user's rerun on an M2 Pro with MATLAB R2026a committed
   `workloads/reference/<name>.txt` for the five workloads, `baseline_timings_matlab.json`
   (default threads) and `baseline_timings_matlab_1thread.json`.
8. **Typing strictness and untyped integer literals.**
   Options: (a) static, signatures annotated, locals inferred, only `i64 → f64` implicit, untyped
   integer constants typed by context and a `var` initialised by one typed by its assignments
   (LANGUAGE.md §4.2); (b) as (a) but untyped integer constants always `i64` unless used directly with an
   `f64` (so `var dMax = 0` followed by `dMax = d` is a type error asking for `0.0`); (c) all
   numbers `f64`, no `i64` (MATLAB's model). **Decided: (a).** It gives MATLAB
   programmers the obvious meaning of `var dMax = 0` and still keeps integer counters `i64`; the
   cost is one flow-insensitive pass over each function's assignments. Affects LANGUAGE.md §4.2, §4.10, §9.1.
9. **Vectors as their own rank.**
   Options: (a) rank-1 `T[]` distinct from rank-2 `T[,]`, orientation written with `.col`/`.row`
   where broadcasting needs it; (b) MATLAB's model, everything 2-D. **Decided: (a).**
   Static loop shapes, no orientation bugs; the price is writing `.col`/`.row` in the rare
   outer-product broadcasts (W3's road grid). Affects LANGUAGE.md §4.5, §5, §6.3, §6.9.
10. **Shape polymorphism.**
    Options: (a) `elemental fn`; (b) generic functions over array shapes; (c) every scalar
    function implicitly elemental. **Decided: (a).** Covers every workload use, keeps
    type checking simple, and is the form fusion needs; (c) hides allocation and loops behind
    ordinary-looking calls. Affects LANGUAGE.md §8.5; §5.1.
11. **Surface syntax.**
    Options, as a package: (a) `*` element-wise, `@` matrix product, `.T` transpose,
    `solve(A, B)`; `^` right-associative binding tighter than unary minus; newline-terminated
    statements with the three rules of LANGUAGE.md §3.7; (b) MATLAB's `.*` / `*` / `'` / `\`, left-associative
    `^`, `;` required. Individual items can be changed. **Decided: (a).** One meaning per
    symbol removes MATLAB's commonest bug (`*` for `.*`); `\` reads as an escape in a C-like
    language; right-associative `^` is the mathematical convention; newline statements read
    cleanly in long engineering scripts, and the one trap (a line starting with a binary
    operator) is a compile error. Affects LANGUAGE.md §3.7, §6.1–§6.2, Appendix A.
12. **Can bounds checks be disabled?**
    Options: (a) no: always on, eliminated by analysis; (b) a `--unchecked` build option;
    (c) a per-block `unchecked { }` construct. **Decided: (a)** for v1. The checks that
    survive elimination are a compare and an untaken branch off the critical path; an option
    would create a second behaviour to test. If phase 10 shows a workload losing more than 5 %
    to checks, revisit with that measurement. Affects LANGUAGE.md §5.4; §5.2.
13. **Plot format and fidelity.**
    Options: (a) SVG with embedded PNG images, geometry specified (LANGUAGE.md §12.5) but v1 tests structural
    plus cross-target byte identity; (b) as (a) with every SVG byte specified and hand-derived
    byte-exact plot tests; (c) PNG files through a rasterizer. **Decided: (a).** It
    tests what matters for v1 (the right figure, deterministic on both targets) without
    freezing layout details before anyone has looked at the figures; (b) can follow without an
    API change. Affects LANGUAGE.md §12; §6.2.
14. **Program arguments for the workloads' flags.**
    Options: (a) `args()` returns the command-line arguments, and the ports take
    `--export-reference` and `--figures` (LANGUAGE.md Appendix D); (b) `getenv`, keeping the workloads'
    environment variables `SEA_EXPORT_REFERENCE`, `SEA_PLOT`, `SEA_SAVE_FIGURES`; (c) both.
    **Decided: (a).** Arguments are explicit at the call site and need one tiny library
    function; environment variables leak into child processes and are invisible in a command
    line. The acceptance and benchmark scripts pass the flags. Affects LANGUAGE.md §10.10, Appendix D; §6.3, §6.5.
15. **File extension and command name.**
    Options: (a) `.sea` and `sea`; (b) `.sea` and `seac`; (c) another name.
    **Decided: (a).** Short and obvious; check for a clash with an existing `sea` command
    on the user's systems before release. Affects §2.2, tests, docs.
16. **`pow` in `const` items** (raised by phase 3's design, §4.10.5). LANGUAGE.md §7.2 lets a constant use `^` with the run time's bits, and pass 2a
    evaluates every constant to one literal, so a `^` that is not a `powk` needs `pow` at compile
    time. Options: (a) `FEPOW` in `f64emu.bas`: the operation sequence of §4.10.4 on the exact
    IEEE emulation, with the tables from a generated `DATA` block `mtab`; bit-identical to the
    runtimes by construction and tested against the same vectors; about 400–600 Baysick lines
    and 110 `DATA` lines in pass 2a (and 2b, unless it is a separate module), bringing pass 2a's
    pre-agreed split (§2.7) forward by about a phase; no language change; (b) such a `^` is
    `not a constant expression` (LANGUAGE.md §7.2 changes; constants keep `powk`, `sqrt` and
    the arithmetic operators), no compiler cost, and a program writes a `let` (not visible inside
    functions) or `sqrt` instead; (c) evaluate such constants at program start (changes "every
    `const` is evaluated at compile time", Decision U2 in §0, and needs a new kind of global).
    **Decided: (a)** (the user, 2026-10-21): it keeps the language as agreed, and its cost lands
    where pass 2a's split is already planned. A `const` may use `^` and the call `pow`
    (LANGUAGE.md §7.2 now lists `pow` beside `sqrt`); `log exp sin cos hypot` stay outside
    constant expressions; pass 2b still folds no `pow` (§3.5.7). Affects LANGUAGE.md §7.2;
    §2.6.3, §2.7, §3.5.2, §3.5.5, §4.10.5, §4.10.6.
17. **Shape of the split of pass 2a** (raised by phase 4's plan, §2.7: phase 4 takes the one
    program to 8 900–10 200 lines). Options: (a) **resolve, then type**: a new program `seaname`
    (`sea.ast` → `sea.res`) resolves names and scopes, checks items and signatures and evaluates
    constants and constant exponents, and `seacheck` (`sea.res` → `sea.hir1`) types, checks the
    rest and emits; `seacheck` sheds the exact arithmetic (`limb`, `f64emu`, `FEPOW`, `mtab`), and
    both stay below 9 000 lines after phase 4; it costs a new intermediate format, `--emit res`,
    `.res` goldens and an error hand-over between the programs; (b) **declarations, then bodies**:
    a smaller format, but the body checker keeps the arithmetic modules and reaches the limit
    again around v1; (c) **typing, then the late checks and emission**: moves about 1 000 lines,
    too few. **Decided: (a)** (the user, 2026-10-21). Affects §2.1, §2.2, §2.6.2, §2.6.3, §2.7,
    §2.10, §3, §3.4.1, §6.2, §8.
18. **Prelude functions in phase 4** (`linspace`, `bincount`, and `meshgrid`, `setdiff`).
    Options: (a) **inline prelude calls in pass 3a in phase 4**: the inlined-call form (a return
    becomes the exit of a block, parameters bound to the arguments, run-time error sites mapped to
    the program's call, §3.6.4) is brought forward from phase 6 for prelude calls only; phase 6
    reuses it for the inlining rule of LANGUAGE.md §8.6, and the inlining of user functions stays
    in phase 6; (b) move them into the runtime on both targets, changing their (P) marks in
    LANGUAGE.md §10; (c) compile prelude functions as LIR functions with a hidden call-site
    argument, changing the "Sites" rule of §3.6.4. **Decided: (a)** (the user, 2026-10-21).
    Affects §3.6.6 (in 4b), §2.7, §8.
19. **How phase 4's numeric "done when" is checked** (no `write_json` before phase 6). Options:
    (a) **the acceptance programs print a JSON subset with `printf("%.17g")`, and the workload
    repository's `compare.py` gains `--keys k1,k2,…`** (the same rules, restricted to those keys);
    the Linux host is checked by byte identity with the Mac's output; (b) a shell checker in
    `tests/` that re-implements the rules for the listed keys; (c) only hand-derived spec tests in
    phase 4, the workload numbers moved to phase 6. **Decided: (a)** (the user, 2026-10-21).
    Affects §6.3 (in 4b), §8; the workload repository.
20. **Array literals of `str` or struct elements.** LANGUAGE.md §6.9 makes a row of scalars a
    fixed-size array, and `str` and structs are not scalars. Options: (a) **such literals are
    dynamic** (`str[]`, `S[]`); fixed-size `str` and struct arrays exist by annotation; (b) they
    are fixed-size like numbers; (c) fixed up to 256 elements of any kind, dynamic beyond.
    **Decided: (a)** (the user, 2026-10-21). LANGUAGE.md §4.5 and §6.9 gain one sentence in 4b.
21. **Named options of library functions in phase 4.** Options: (a) **the library options
    (`desc:`, `dim:`) in phase 4**; named and default arguments of user functions stay in phase 6
    (the phase-rule row becomes "a named argument of a user function"); (b) all named arguments in
    phase 6, so phase 4 has ascending sorts only and no `dim:` reductions; (c) all named and
    default arguments in phase 4. **Decided: (a)** (the user, 2026-10-21). Affects §2.6.2 (in
    4b), §8.
22. **Which whole-array operations are runtime calls.** Options: (a) **inline LIR for element-wise
    loops, reductions, indexing, gathers and scatters, mask compaction, `find*`, concatenation
    and projections; the runtime only for memory, copy on write and freeing, strings,
    `sort`/`argsort`, `args` and `error`**: the inline loops are what phase 7 fuses and
    vectorizes, and the pinned orders are exact in LIR by construction; (b) a generic runtime
    layer of strided descriptors and per-operation entries; (c) (a) with the variable-length
    results (`find`, `x[m]`, concatenation) in the runtime. **Decided: (a)** (the user,
    2026-10-21). Affects §3.6.6, §4.8 (in 4b).
23. **Scope edges of phase 4.** Options: (a) **include the exact math functions `abs sign sqrt
    floor ceil trunc round min max where isnan`, `ind2sub`/`sub2ind`, `lower`, `str(x)`,
    `meshgrid` and `setdiff`; leave `%` with an `f64` operand (the exact `fmod`) to phase 6** as
    a phase-rule row; (b) only what the "done when" needs (the math functions), the rest in phase
    6; (c) everything, `f64 %` included. **Decided: (a)** (the user, 2026-10-21). Affects §2.6.2
    (in 4b), §8.
24. **A heap-leak check for tests.** Options: (a) **`SEA_HEAP_CHECK=1` in the environment makes
    the runtime write the number of live dynamic objects to standard error at a normal exit**, a
    test aid, not a language feature; tests set it through a `.meta` line; (b) no leak check.
    **Decided: (a)** (the user, 2026-10-21). Affects §4.5, §4.8, §6.2 (in 4b).
25. **Constants that read a constant without a value** (raised by the review of 4a's
    specification). The single program evaluated a constant whose check found no error even when
    it named a constant whose check or evaluation had failed, and reported an `integer overflow`
    of that evaluation if the overflow came, in evaluation order, before the read of the failed
    constant (`const B = 9223372036854775807 + 1 + A` with `const A: i64 = 1 + x` reported
    `1:11: integer overflow`, not `A`'s `undeclared name 'x'`). Splitting pass 2a would have to
    reproduce that order in two programs. Options: (a) **a constant that names a constant without
    a value, or whose type is an error type, is not evaluated and gives no further error**: the
    error reported is the one that caused the missing value, and `seaname` needs to replicate no
    check (§3.4.1); (b) keep the evaluation order and replicate the checks of constants in
    `seaname`. **Decided: (a)** (the user, 2026-10-21). It is made in the single `seacheck`
    first, as its own change (sub-phase 4a-0, §8), with its tests (§6.2). Affects LANGUAGE.md
    §7.2; §3.4.1, §3.5.2, §6.2, §8.
