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
3. implementation follows the milestones of §8: next is phase 1 (phase 0 is complete except
   the user's MATLAB rerun of Decision 7).

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
   `powk` (LANGUAGE.md §6.5).

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

The file records neither the CPU model nor the machine; §6.5 requires the Sea measurement
to name its machine, and the comparison is valid only on the same one (the user's).

**What "faster than MATLAB" means.** Two measures, both required:

* **Compute time**: the time the program measures around the same region as the MATLAB
  script's `tic`/`toc` (`computeSeconds`), with Sea's `now()` (LANGUAGE.md §13). Compared: Sea's best of 3
  consecutive runs against MATLAB's best compute time above (the same rule as the baseline,
  §5.7). Sea's first run is reported next to MATLAB's first run but is not a pass criterion.
* **Whole-process time**: wall time from `exec` of the compiled Sea binary to its exit, with
  the reference export enabled (MATLAB's `total_seconds` includes the `jsonencode` export) and
  figures disabled (as in `run_all`). Compared: Sea's best of 3 against MATLAB's best
  `total_seconds`. This is
  conservative in MATLAB's favour: MATLAB's total is measured inside an already running
  MATLAB session and excludes MATLAB's own start-up, while Sea's includes everything the
  operating system does to start the process.

Sea's compile time is reported next to these numbers but not counted: an AOT binary is
compiled once and run many times. The methodology is §6.5; its known asymmetries (MATLAB ran
multithreaded, three repetitions with visible variance) are stated in §5.7, and Decision 7 in
§9 adds a MATLAB rerun that removes them.

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
temporary directory (Baysick `FILES` names are fixed at compile time, Baysick LANGUAGE.md §7.21), and
report through their exit status and standard error. The number of passes (seven programs, plus
the second code generator) follows from the size calibration of §2.7; it is part of Decision 2
in §9.

### 2.2 The driver: `sea`

A POSIX `sh` script (name: Decision 15 in §9):

```
sea build <file.sea> [-o <out>] [--target arm64-macos|x86_64-linux] [-S]
                     [--emit ast|hir1|hir|lir1|lir] [--keep-temps] [--no-prelude]
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
   statuses from `errors.inc`.
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
   prelude's names are then not declared at all).
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
   * writes `#end` as the last record of its own output, after everything else;
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
8. `-S`: copy `sea.s` to the output. `--emit X` (X one of `ast`, `hir1`, `hir`, `lir1`,
   `lir`; formats in §3): stop after the pass that writes `sea.X` and copy it unchanged. Otherwise (arm64-macos): assemble and link exactly as Baysick does (Baysick DESIGN.md §4.3,
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
status 2); `unknown target '%s'`, `unknown emit kind '%s'`, `-S and --emit cannot be combined`
(2); `cannot read '%s': <reason>` for the program file (2); `cannot create temporary directory`,
`cannot write in '%s'`, `cannot write '%s'` (2); `cannot find '%s'` and `cannot find runtime
library '%s'` (4); `internal error: pass executable '%s' not found (run make)`, `internal error:
%s failed with exit status %d`, `internal error: %s wrote no complete %s (no final #end)`,
`internal error: %s wrote no %s` (4); `cannot determine macOS SDK path`, `cannot run '%s': not
found`, `'%s' failed with exit status %d` (3); with `--keep-temps`, `temporary files kept in %s`.

**Driver exit statuses** (the meanings of Baysick DESIGN.md §4.2): 0 success; 1 Sea compile
error; 2 usage or file error; 3 toolchain error (`as`/`ld`/`xcrun` missing or failing); 4
internal error (pass status 1 or 11, a missing `#end`, out of memory). Driver messages start with
`sea: `.

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
| `SEA_LIM_CONSTS` | 19999 | numeric constants (`… constants`) | §2.7 |
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
  pass (§2.2 step 2); `C1` pass 1; `C2` pass 2a or 2b; `CX` any pass (a capacity limit of §2.7);
  `P` a pass's internal consistency check (pass status 11, §2.2).
* `at` (LANGUAGE.md §9.1 requires a position but names none; this column names it): the
  position a compile-time diagnostic `<file>:<line>:<col>` reports (LANGUAGE.md §9.1); `-` for
  `R` and `P` (a run-time error reports the line of its LIR site, §3.6.4). The words:

| `at` | Position reported |
|------|-------------------|
| `byte` | the offending byte; for `invalid escape` the `\` that starts the escape |
| `token` | the first byte of the offending token: for `unterminated comment` the `/*`, for `unterminated string` the opening `"`, for `comparisons cannot be chained` the second comparison operator, for `'$' outside an index` the `$`; for `unexpected newline` the LF that ends the line, after any comment on it (column = the line's length in bytes after CR removal + 1; for the line break of a block comment that spans lines, the first LF inside the comment); for `unexpected end of file`, the position just after the last byte of the program file's last line (line 1, column 1 for an empty file) |
| `over` | column `SEA_LIM_LINE_BYTES` + 1 (the first byte beyond the limit) of the line |
| `stmt` | the first token of the statement |
| `here` | pass 1 (which enforces `nodes`, `strings`, `nesting`, `parameters`, `results` and `fields`, §2.7): the token whose addition exceeds the limit (the token that opens the 65th nesting level, starts the 65th parameter, result type or field); passes 2a, 2b and 3a: the position of the node being read, created or lowered when the limit is exceeded (for a record without a position, the next node of the same function or constant that has one); passes 3b and 4: the position of the `func` record (§3.6.3) of the function being processed |
| `expr` | the expression node at fault: for `type mismatch`, `condition must be bool`, `index must be i64`, `integer constant not exact in f64`, `not a constant expression`, `cannot iterate over`, the format errors and `argument for ref parameter …` the expression itself (the argument, condition, index, iterable, constant expression); for the operand errors (`cannot combine…`, `shape mismatch`, `vector @ vector…`, `operator … cannot be applied…`) the operator node (`bin`, `neg`, `not`, or the `call` of an elemental function or `where`); for `shape mismatch` of a value stored into a fixed-size type (initialisation, assignment, argument passing, return: `let a: f64[4] = [1.0, 2.0, 3.0]`), the value expression, and the text names the target's shape first (`shape mismatch: 4 vs 3`) |
| `name` `slit` `init` `match` `arm` `ref` `call` `narg` `dot` `index` `row` `struct` `fn` `param` `str` `break` `continue` | that node of `sea.ast` (§3.4): `init` the repeated (second) or unknown initializer; `arm` the arm with the repeated pattern; `ref` the first `ref` argument, in source order, whose root another argument shares (`ref argument aliases…`) or the offending `ref` argument; `row` the first row whose length differs or that mixes vectors and matrices; `str` the format string literal; `call` for `elemental function cannot be recursive` the first call, in source order, on a cycle of calls through an elemental function |
| `item` | the `const`, `struct` or `fn` node of the top-level item |
| `binding` | the node declaring the name: `pname`, `param`, the `for` node, a struct's `field`, or the `const`/`struct`/`fn` item; for `redefinition of '%s'` the later declaration |
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
  `unexpected token '%s'` the token's source text; in `format "%s" …` the format literal's source
  text between its quotes, escapes as written; in `format "%s" expects %s, found %s` the
  conversion as written (`%` through the conversion letter, e.g. `%8d`), then `an integer or f64`
  for `d i f F e E g G` or `str` for `s`, then the argument's type; in `invalid format
  conversion "%s"` the conversion as written from its `%` through the byte that makes it invalid
  (or the end of the string); in `operator '%s' …` the operator as written (`*`, `==`, `!`); in
  `no overload of '%s' accepts (%s)` the function's name and the argument types joined by `, `;
  in `view .%s …` the view name (`T`, `flat`, `col`, `row`); in `%s of an empty array` the
  function (`max`, `min`, `argmax`, `argmin`); in `program too large: %s` one of the words
  `nodes`, `symbols`, `types`, `constants`, `strings`, `nesting`, `parameters`, `fields`,
  `results`, `instructions`, `operands`, `registers`, `blocks`, `slots`, `immediates`, `labels`,
  `sites` (the capacity limits of §2.6.1, each limit's word in its "Meaning"); in `%s` (`USER`)
  the message formatted by `error` (LANGUAGE.md §9.3).

**Output.** A compile-time message is written by the pass (or the driver) as LANGUAGE.md §9.1
says; a `P` message as `<pass>: <text>` + LF on standard error, where `<pass>` is the program's
name (`seaparse`, `seacheck`, …), exactly one line, before the pass ends with `STOP 11`
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
| 400 | `TOO_LARGE` | CX | here | `s` | `program too large: %s` | LANGUAGE.md §3.1; §2.7 |
| 500 | `TRUNCATED` | P | - | - | `internal error: truncated input` | §2.2 |
| 501 | `BAD_HEADER` | P | - | - | `internal error: bad header` | defined here (§3.2) |
| 502 | `BAD_RECORD` | P | - | - | `internal error: bad record` | defined here (§3.1: unknown opcode, wrong fields) |
| 503 | `BAD_TREE` | P | - | - | `internal error: bad tree` | defined here (§3.3: a pop from an empty stack, a non-empty stack at a section end) |
| 504 | `BAD_DATA` | P | - | - | `internal error: bad DATA table` | defined here (§2.2: a `DATA` table count disagrees with its sentinel) |

**The phase rule: `not supported yet`.** While Sea v1 is built phase by phase (§8), a program that
uses a construct the current compiler does not implement yet stops with the compile error `not
supported yet: %s` (code 259, `NOT_SUPPORTED`; driver status 1), reported by pass 2a (pass 1
parses the whole grammar of LANGUAGE.md Appendix A from phase 1 on, so syntax errors are always
the real ones). It takes part in pass 2a's plain source order with every other pass-2 error: the
first error in source order is reported, whichever kind it is. Its position is the AST node that
the table's row names, and of several such nodes the first in source order: for a `str` local
its declaring `pname` (or `for` node), for a `str` parameter its `param` node, for a `str` result
the result's `type` node, for a default argument the `param` node, for a named argument the
`narg` node, for a library function the `call`. The format literal of `printf` is not a
`strings` construct. The `%s` is one of the words below. It is
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
| `^` that is not a `powk` (it needs `pow`, phase 3) | `pow` |
| a handle type | `handle types` |
| a call of a library function other than `printf`, `now`, `f64`, `i64` and `idiv` (LANGUAGE.md §10–§13) | its name, e.g. `sqrt` |

Included in phase 1, so not reported: `const` items, the constants `pi inf nan eps`, `i64`, `f64`
and `bool` scalars, every scalar operator except those above, `if`/`while`/`for` over ranges,
`break`/`continue`, functions with scalar parameters and results, `ref` parameters of scalar
locals, multiple results, and `printf` with `%d %i %f %F %e %E %g %G %s`. Each later phase of §8
removes the rows it implements from this table, together with its tests. Because named
arguments, struct literals and fixed-size arrays are reported first, the errors 204–208,
216–222, 224 and 225 cannot occur in phase 1.

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
`SEA_ERRNO_<NAME>`, `SEA_ERRNO_COUNT` = 18.

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
| `SEA_ERRNO_COUNT` | 18 | number of errno records (ids 0 … 17) |
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
`limits.inc`, 2 `errors.inc`, 3 `rt.inc`, 4 `passes.txt`. Its standard input is the selection:
one block name per line, each at most once, in the order `errors errno exits consts entries
records`. It writes the `DATA` lines of the selected blocks to standard output, numbered
consecutively from 89 000 across the blocks, each table followed by its sentinel. `errors` and
`errno` are the lists of `errors.inc`, `exits` its `SEA_EXIT_*` constants (NAME = the text after
`SEA_EXIT_`), `consts` the constants of `limits.inc` and then those of `rt.inc` in one table (NAME
= the text after `SEA_`; the other constants of `errors.inc` are not emitted), `entries` the
entry list of `rt.inc`, `records` the lines of `passes.txt`. A malformed record, a line over 255
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
  the field specifications); ending with `<line> DATA "end",0`.

Every generated line, line number included, is at most 255 bytes (Baysick's physical line
limit); the generator stops with status 1 and a message naming the record if one would be longer.

**How a pass is built.** Each pass program `build/gen/<pass>.bas` is the concatenation, in this
order, of: the pass's own files `passes/<pass>/*.bas` (in name order); the shared modules of
`passes/lib/` it uses, in the order `io diag tables limb f64emu fltlit`; the generated `DATA`
blocks it uses, among `errors`, `errno`, `exits`,
`consts`, `entries` and `records`, always in this order; and the line `99999 END`. The file
`passes/<pass>/build.list` names the modules and blocks: lines `lib <module>…` (among `io diag
tables limb f64emu fltlit`) and `data <block>…`, comment lines starting with `#`; the parts are
concatenated in the order above whatever the order of the list, and a name outside the two sets
is a build error. `tools/seaval.bas` is built the same way from `tools/seaval.build.list`. The
build regenerates `build/gen/` every time and compiles each result with `baysick`; nothing in
`build/` is committed. The modules' interfaces are internal to the compiler (not contract
files): `passes/lib/API.md` documents the `SUB`s of `io`, `diag` and `tables`, and
`passes/lib/API-arith.md` those of `limb`, `f64emu` and `fltlit` (each module's prerequisites
included); the `.bas` files carry one summary line per `SUB`. The line numbers keep the parts
apart:

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
tables; every other pass uses a subset of the same layout:

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
types, 19 999 numeric constants and 199 999 distinct strings per compilation (prelude included);
nesting depth ≤ 64, ≤ 64 parameters and ≤ 64 results per function, ≤ 64 fields per struct.
Pass 1 enforces the nesting, parameter, result and field limits as it parses (and the node and
string limits as it builds the tree); pass 2a the symbol, type and constant limits; passes 3a,
3b and 4 the LIR limits. **Nesting depth** counts the constructs that make pass 1 recurse: a
block `{ … }` (of any statement or function), a parenthesized expression, the argument list of a
call, an index list, an array literal, a struct or record literal, an `if` expression, a unary
operator and the right operand of `^`; the top level is depth 0, and each such construct
contained in another adds 1. A construct at depth 65 is `program too large: nesting`, reported
at its opening token (`{`, `(`, `[`, `if`, the unary operator, or the `^`). For the LIR limits,
the operand fields of an instruction are all its fields after the opcode except its `site`
(§3.6.4); the fields of `func`, `slot` and data records are not operands. The distinct sites are
the distinct `F:L` among the instructions' `site` fields and the `pos` of every `func` record
(§4.9), counted over the compilation.
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
| **total** | **≈ 26 000–42 000** | eight programs |

The uncertainty is large (±50 % on the later passes); the estimate is recalibrated when pass 1
exists (phase 1, §8). Passes 2a and 3a may approach the 10 000-line limit; the response is
Decision 2 in §9 (split further, or grow Baysick, by the policy of §7.3). Runtime assembly per target, by analogy with
Baysick's runtimes (9 000 and 11 000 lines): core runtime 8 000–12 000 lines, plotting and JSON
2 500–4 000, Sea's own kernels (GEMV, LU/Cholesky panels, triangular solves, eigenvalues, sort,
elementary functions in scalar and vector forms) 6 000–10 000 — all estimates.

### 2.8 Numbers inside the compiler

The passes run as Baysick programs, whose numbers are doubles, which cannot represent ∞ or NaN,
and whose arithmetic stops the program with `OVERFLOW` or `DIVISION BY ZERO` before any check of
the result could run (Baysick LANGUAGE.md §5.4); `SQR` takes `sqrt(|x|)`. Therefore:

* **Float literals** (LANGUAGE.md §3.4) are converted to their exact IEEE bit pattern by pass 1 with exact
  big-integer arithmetic (decimal digits × 10^e as a big integer or rational in arrays of 16-bit
  limbs, then rounding to 53 bits, ties to even), and carried as hex in every later file. The
  assembler only ever sees `.quad 0x…` patterns. Test vectors for the converter come from the
  IEEE definition (hard-rounding cases included), §6.2.
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

  These checks only decide **whether** to fold (the exponent of x is the e with 2^e ≤ |x| <
  2^(e+1); a zero operand passes every check). The folded value itself is computed with the exact
  IEEE emulation of `passes/lib/f64emu.bas` (the operations `FEADD`, `FESUB`, `FEMUL`, `FEDIV`,
  `FESQR` on bit patterns), never with Baysick's doubles, which cannot hold −0 (and `SQR` of −0
  gives +0): so `-0.0 * 1.0` folds to −0.0 and `sqrt(-0.0)` to −0.0, as at run time. Underflow is
  harmless (the emulation rounds to subnormals as IEEE does). Folding folds only subtrees that
  are constant on their own (`2 * pi * rpm / 60` folds `2 * pi` only, LANGUAGE.md §6.8).
* **NaN in the emulation.** The emulation's NaN result is always the canonical
  `#7FF8000000000000`, while hardware propagates an operand's payload. No folded value is ever a
  NaN (the checks above), and a NaN met while evaluating a constant exponent only decides that it
  is not integral (§3.5.5), so the difference is never visible.
* **`i64` arithmetic** beyond 2⁵³ (literals, overflow checks of folded constants, the magic
  numbers for division by a constant) uses multi-limb integer routines in the pass that needs it.
* **Constant exponents and extents** (pass 2a, §3.5.5) are evaluated, not folded: pass 2a computes
  their exact values with multi-limb arithmetic that emulates IEEE binary64 (and exact `i64`),
  never with Baysick's floating-point operations, so the rules above do not restrict it; it
  writes no folded value, only the decision `powk k` (or the extent of a type).

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
| `passes/seaparse/`, `seacheck/`, `seaexpand/`, `sealower/`, `seaopt/`, `seagen_a64/` (later `seagen_x64/`) | each pass's own Baysick files (§2.1), built as §2.6.3 says |
| `tools/gendata.bas` | the `DATA` generator (§2.6.3) |
| `tools/seaval.bas`, `tools/seaval.build.list` | a validator of intermediate files, used by the tests: the header, every record's fields against `passes.txt`, the pops and the tree stack (the non-node records are those §3.3 lists), and LIR register numbering and classes; it does not check the first-reference order of types, the ranges of `fid`/`cid`/`iid` references or `rcall` entry names |
| `passes/<pass>/build.list` | the modules and `DATA` blocks of each pass (§2.6.3) |
| `tools/passlines.sh` | the line count of each built pass against Baysick's limits (`make lines`) |
| `std/std.sea` | the prelude (§2.5) |
| `runtime/arm64_macos/`, `runtime/x86_64_linux/` | the runtimes (§4); in phase 1 `rt_main.s`, `rt_out.s`, `rt_err.s`, `rt_fmt.s`, `rt_clock.s` |
| `include/` | the contract files (§2.6) |
| `tests/` | the tests (§6.2) |
| `build/` | the build output and installation directory: the pass executables, `sea`, `std.sea`, `errors.inc`, `limits.inc`, `libsea.a` and `libbaysickrt.a` (one of each, for the build's target), and the generated `build/gen/`; never committed |

`make` builds `build/`; `make test` runs the tests of §6.2; `make test-rt`, `make test-stage`
and `make check-data` run single groups of them (§6.2); `make lines` reports each built pass's
line count against Baysick's 10 000 lines, and `make check-limits` checks each built pass against
Baysick's other per-program limits of §2.7 (1000 `FOR` statements, 65 536 bytes of string
constants outside `DATA`, 255-byte lines); `make check-includes` and `make check-contracts`
check the contract files (§2.6).

## 3. Intermediate files

The passes of §2.1 communicate through five text files in the temporary directory. This section
fixes their exact formats; `sea/include/passes.txt` (§3.9) is the same information in a form the
passes' generated `DATA` blocks are made from (§2.6), and the two change only together.

| File | Written by | Read by | Content |
|------|-----------|---------|---------|
| `sea.ast` | 1 `seaparse` | 2a | the syntax tree as parsed, untyped (§3.4) |
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
    (the patterns of an `arm` are child `str`/`cs` nodes, §3.4, §3.5.5);
  * the records with a variable number of fields (`ttuple`, `inst`, `tbind`, `func`, `call`,
    `rcall`, `ret`, `chk`) repeat numbers or registers, each at most 7 bytes with its separator,
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
refer to other nodes by number; the structure is given by the order alone. The header records
and the declaration records of §3.5 (`t…`, `fd`, `inst`, `fn`, `par`, `loc`) are not nodes and
do not touch the stack; this list, not `passes.txt`, says which records are not nodes, and tools
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
| `for` | `name:s` | `2` | iterable (a `range` for a range loop, else an expression), block | `for name in … { … }` |
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
for 0:10:1 i
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

One `cn` per `const` item, in stream order, numbered from 1, each preceded by its expression's
records; `pos` is that of the `const` keyword. A use of the constant is a `cref` node.

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
| `loc` | `name:s ty:ty mut:lmut pos:pos` | `0` | a local; mut `let`, `var` or `for` (a loop variable, LANGUAGE.md §7.5); `pos` its name in the declaration |
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
every implicit conversion, which pass 2a has made explicit (`cvt`, `dyn`, `fix`); untyped integer
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
| `tasg` | `n:u` | `n+1` | n targets (or `skip`), a multiple-result application | `(t1, …) = f(…)`; the last child as for `tbind` |
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

**Constant exponents** (pass 2a). For every `^` whose exponent is a constant
expression (LANGUAGE.md §7.2: literals, constants, operators, `pi inf nan eps`, `sqrt`), pass 2a
computes the exponent's value exactly as the run time would: `f64` operations by exact
multi-limb arithmetic emulating IEEE binary64 round-to-nearest-even (`+ − × ÷`, `%` by the
exact `fmod` rule of LANGUAGE.md §6.6, `cvt`, unary `−`), `i64` operations exactly with the range
check, on infinities and NaN as on any other value, and never with Baysick's floating-point
operations (§2.8), so nothing can stop the pass. If the value is an integer k with \|k\| ≤ 4
(`SEA_LIM_POWK`; `2`, `2.0`, `6 % 4`, `const K = 6 % 4`, `-0.0` as k = 0), the `^` becomes
`powk k`; otherwise it stays `bin pow` with its exponent. An exponent whose evaluation overflows
`i64` or divides an `i64` by zero is not integral here; it stays, and the run time reports the
error. An exponent that contains a call (`sqrt` or any other) or a `^` that is itself not a
`powk` is not integral, whatever its value (LANGUAGE.md §6.5), so it is not evaluated. Constant
extents (§3.5.1) and the `i64` values of constant
expressions use the same exact evaluator.

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

In this order:

1. **Constant substitution.** Every `cref` is replaced by a copy of its constant's expression
   (recursively, for constants defined by constants); the copied nodes take the position of the
   `cref`. The `cn` records are not written.
2. **Folding** (§2.8), bottom-up, of subtrees whose operands are constants (`ci`, `cf`) only:
   `f64` `add sub mul div` under the checks of §2.8, `un neg` of an `f64` (a sign flip), `lib sqrt`
   of an `f64` ≥ 0, `i64` `add sub mul` and `un neg` when the exact result is in the `i64` range
   (otherwise the node stays, and the overflow is reported at run time, LANGUAGE.md §6.5), and
   `cvt` of an `i64` constant (rounded to nearest, ties to even, exactly). Nothing else is folded
   (no comparison, logic, `%`, `pow`, transcendental function or conversion to `i64`; no
   operation on `inf` or `nan`). A folded subtree becomes one `ci`/`cf` at the position of its
   root. (`powk` is decided earlier, by pass 2a, with exact arithmetic: §3.5.5, "Constant
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
| `rcount` | `d:ri lo:ri hi:ri st:ri incl:u site:site` | the number of elements of `lo..hi step st` (incl 0) or `lo..=hi step st` (incl 1), LANGUAGE.md §5.1, exactly, as an unsigned 64-bit count; `st` = 0 is `range step is zero` |
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
| `loop` | `b:blk ind:ri start:ri count:ri step:ri` | a counted loop: start, count and step are read once on entry; for k = 0 … count − 1 (count unsigned) the body runs with `ind` = start + k·step; the body never writes `ind` |
| `endloop` | `b:blk` | the end of loop `b` |
| `do` / `enddo` | `b:blk` | a loop left only by `exit`, and its end |
| `if` / `ifz` | `b:blk c:ri` | the first part runs if the register is not 0 (`if`) or is 0 (`ifz`), the `else` part otherwise |
| `else` / `endif` | `b:blk` | the start of the `else` part, the end of the construct |
| `exit` / `next` | `b:blk` | leave loop `b` / start its next iteration (`loop`: k + 1; `do`: the top) |
| `ret` | `n:u v:reg*n` | return the results |
| `call` | `name:s nr:u d:reg*nr na:u a:reg*na` | call a Sea function; nr is the callee's result count, or 0 to discard its results |
| `rcall` | `entry:s site:site? nr:u d:reg*nr na:u a:reg*na` | call a runtime entry point, named as `rt.inc` lists it (§4.8); `site` for entries that can fail (allocation, I/O, the checks of library functions) |
| `chkb` | `idx:ri ext:ri dim:u site:site` | if idx < 0 or idx ≥ ext: `index … out of bounds for dimension … of extent …` (LANGUAGE.md §5.4) with idx, `dim` and ext; `dim` counts from 0 (LANGUAGE.md §5.4): 0 for the rows (or a vector's only dimension), 1 for the columns, printed as is |
| `chk` | `c:ri err:s site:site n:u a:reg*n` | if c ≠ 0, stop with the run-time error whose code name in `errors.inc` is `err`, the arguments substituted |
| `retain` / `release` | `a:rp` | count one more / one fewer reference to a runtime object; `release` frees it at zero (§4.2) |

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
unchanged as `sea.lir`; it transforms nothing. The transformations of §5.2–§5.3 and §5.1 arrive
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
`i64` and `idiv` and string constants as `printf` arguments) exactly as follows; pass 3a inlines
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
   `sti`/`stf V P - 0 0`. A `tasg` target that is a `ref` parameter gets a new result register,
   written through the parameter with `sti`/`stf` after the `call`, in target order.
3. `a && b` and `a || b`: a new register R; a with destination R; then `if B R` (for `&&`) or
   `ifz B R` (for `||`), b with destination R, `endif B`. `ifx c a b`: c, then `if B c`, a with a
   new destination R, `else B`, b with destination R, `endif B`. "With destination R" follows
   rule 2: an operand or arm whose root is a constant is its `li`/`lf` into R directly, one that is
   `lv M` is `mov R M`, any other root's instruction writes R.
4. `if c then [else]`: c, `if B c`, then, [`else B`, else], `endif B`. `while c body`: `do B`,
   c, `ifz B2 c`, `exit B`, `endif B2`, body, `enddo B`. `forr L (rng lo hi [st])`: lo, hi, then
   st or (if absent) `li` 1, then `rcount C lo hi st incl site` (the `for` line), `loop B L lo C
   st`, body, `endloop B`. `break` is `exit` and `cont` is `next` of the innermost loop.
5. Calls: the arguments left to right, then `call` with the result registers (rule 2); `eval` of
   a call with results uses nr 0. `ret k` is `ret k` of the values' registers. `tret`: the call
   with a new register for each result, then `ret` of those registers in order. `seq`: its `bind`
   nodes in order (rule 2), then its value, which is lowered as if it stood in the `seq`'s place.
6. A function whose result type is `void` ends with `ret 0` unless its last statement is a
   `ret`; `.main` always ends with `ret 0`. `block` emits nothing for scalar locals.
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
    assignment wins over the reload.
13. **Constant exponents.** `powk k` lowers its base x first, then into a new destination d (or
    the destination of rule 2): k = 0 `lf d 1.0`; k = 1 `mov d x`; k = 2 `fmul d x x`; k = 3
    `fmul t x x`, `fmul d t x`; k = 4 `fmul t x x`, `fmul d t t` (t a new register). For k < 0,
    x^|k| is computed as above into a new register t (t is x itself when |k| = 1), then `lf o
    1.0` into a new register o and `fdiv d o t`.

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
rcount i6 i4 i1 i5 0 0:3
loop 1 i7 i4 i6 i5
itof f8 i7
fmul f9 f2 f8
fadd f3 f3 f9
endloop 1
ret 1 f3
endfunc
#end
```

`sea build --emit lir --no-prelude lx.sea` is identical: there is no array access (no bounds
check to remove), no instruction in the loop whose operands are all defined outside it (each reads
`i7`, `f8`, `f9` or `f3`), no addressing to strength-reduce, no slot to scalar-replace and no array
loop to vectorize, and LANGUAGE.md §6.8 forbids rewriting `s + x * i` in any other form.

### 3.7 Numbers of records

Opcode numbers are fixed in `passes.txt` (§3.9), separately for `sea.ast`, for the HIR files and
for the LIR files. They do not appear in the files, which use the opcode names; a pass maps names
to numbers with its generated `DATA` table, so a pass dispatches on a number with `ON … GO TO`
(Baysick LANGUAGE.md §7.17).

### 3.8 Dump tests

`sea/tests/passes/NAME.sea` with `NAME.ast`, `NAME.hir1`, `NAME.hir`, `NAME.lir1` and/or
`NAME.lir` (§6.2): the runner, in `sea/tests/passes/`, runs `sea build --emit X --no-prelude
NAME.sea` for each expected file present and compares the output byte for byte. The examples of
§3.4, §3.5.8 and §3.6.7 are the first such tests (`ex`, `lx`). As for every test, the expected
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
  * `<set>`: `A` (`sea.ast`), `H` (both HIR files), `H1` (`sea.hir1` only), `HF` (`sea.hir`
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
| math | `log exp sin cos pow hypot`, scalar and vector forms with identical results (Decision 6): table-driven range reduction and polynomials, one algorithm for both targets, using only IEEE `+ − × ÷ sqrt` and exact integer operations (no FMA, which SSE2 lacks — the cost is part of Decision 1), verified ≤ 1 ulp against high-precision references (§6.2); `round` on x86_64 (LANGUAGE.md §6.7) |
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
`SEA_STACK_LEAF_MAX` bytes, compares sp minus its frame size with `_sea_stack_limit` (the top of
the guard page plus `SEA_STACK_MARGIN`, set by `main` before `_sea_main`); if it is lower, the
function calls `_sea_err(SEA_E_STACK_OVERFLOW, site)`, where site is the function's definition
line: the `F:L` of its LIR `func` record's `pos` (§3.6.3), which pass 4 adds to `_sea_sites`
(§4.8, §4.9). So `stack overflow` reports `<file>:<line>` of the `fn` whose call did not fit
(LANGUAGE.md §8.6, §9.2). The margin leaves room for unchecked leaf frames and for `_sea_err`
itself. The guard page stays as a safety net: an alternate signal stack and a `SIGSEGV`/`SIGBUS`
handler turn a fault in it into `stack overflow` with no location (`SEA_SITE_NONE`); a
`SIGSEGV`/`SIGBUS` at any other address, and any other signal, keeps its default action. Programs ignore `SIGPIPE` and report a failed write as `cannot write`
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
`sea_main`, `sea_err`, `sea_sites`, `sea_variant`), as Baysick's do.

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
results, mapped by the calling convention below. `SEA_ENT_<NAME>` is the id; `SEA_ENT_COUNT` = 2.

| Id | Name | Symbol | Site | Args | Results | Contract |
|---:|------|--------|------|------|---------|----------|
| 1 | `PRINTF` | `sea_printf` | `S` | `pp` | `-` | `_sea_printf(fmt, slots, site)`: arm64 `x0` / x86_64 `%rdi` = the address of a pre-parsed format (`SEA_FMT_*`, below), `x1` / `%rsi` = the address of its argument slots (one `SEA_SLOT_SIZE` slot per conversion, in order: an `i64` or `bool` value, the bits of an `f64`, or a string object pointer, by the conversion's `SEA_CLS_*`), `x2` / `%rdx` = the site index; formats as LANGUAGE.md §11.1 says into the standard-output buffer (an `i` slot of an `f`/`F`/`e`/`E`/`g`/`G` conversion is converted to `f64` with round-to-nearest-even: pass 2a writes no `cvt` for a typed `i64` argument of those conversions, so its `fconv` has class `i`; the runtime trusts the compiler's checks of LANGUAGE.md §11.1 and does not re-check flags or classes); a failed write of the buffer is `_sea_err(SEA_E_CANNOT_WRITE, site, slots "<stdout>", errno)` (§4.6); no result |
| 2 | `NOW` | `sea_now` | `-` | `-` | `f` | `_sea_now()`: the monotonic clock (`clock_gettime(CLOCK_MONOTONIC)`) in seconds as an `f64` in `d0` / `%xmm0` (LANGUAGE.md §13); cannot fail |

| Name | Value | Meaning |
|------|------:|---------|
| `SEA_ENT_COUNT` | 2 | number of entry records |
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
| further results | written by the callee to an area of 8-byte slots whose address the caller passes as a hidden parameter after the hidden result addresses of §3.6.3 | same |
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
with site `S` passes the site index as its last argument (§4.8).

**The phase-1 allocator** (§8; linear-scan allocation replaces it in phase 5, §5.2). Every virtual
register of a function has its own 8-byte slot in the frame; the frame holds the frame record,
the LIR `slot`s (§3.6.3) and the register slots, and its size is a multiple of 16. Each
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

| Workload | MATLAB best compute | Where Sea's time should go |
|----------|--------------------:|----------------------------|
| W1 | 0.528 s | ≈ 260 k scalar `shaft_safety` evaluations with one `pow` each (only one branch of `kb` runs); 40 fused grid iterations; well under 0.1 s expected |
| W2 | 1.053 s | ≈ 400 dense factorizations of 241 × 241 (Cholesky ≈ 4.7 MFLOP each) and the 1441-RHS triangular solves; dominated by GEMM-rate updates; a few tenths of a second expected |
| W3 | 0.650 s | 480 k RK4 steps at a few tens of ns each, plus ≈ 0.96 M `sin` for the road (16001 × 60); around 0.1 s expected |
| W4 | 0.901 s | 31 M latency-bound SOR updates (≈ 20 cycles each by the add-chain latency) plus ≈ 1500 fused half sweeps; roughly 0.2–0.4 s expected |
| W5 | 0.810 s | 11 M LCG steps, 3 M `log` and 3 M `cos`, two 1 M-element sorts, 26 fused stack-ups over 7 M elements; roughly 0.1–0.3 s expected |

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
  passes/NAME.sea     + NAME.ast | NAME.hir1 | NAME.hir | NAME.lir1 | NAME.lir (the --emit
                      dumps of §3, built with --no-prelude, §3.8; pinned like Baysick's tests/ir)
  plots/NAME.sea      + NAME.struct (the expected structure of each SVG it writes, LANGUAGE.md §12.8)
  math/               elementary-function accuracy and identity tests
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
                      cross.sh, cross_pack.sh, cross_run.sh: Linux, as Baysick's
  NAME.status         the expected exit status: a decimal number and LF
  harness/            Baysick test programs of the shared modules (limb, f64emu, fltlit) that
                      read the committed vectors
  arith_check.sh      runs harness/ on vectors/ (exact arithmetic and float literals)
  lib_check.sh        checks passes/lib against the contract (e.g. the BAD_DATA copy, §2.6.2)
  driver_check.sh     the driver's options, messages and statuses (§2.2)
  passes/NAME.out     (optional, beside a dump test) the program's expected standard output when
                      built and run
  NAME.meta           (optional, beside a programs/ or errors/ test) `key=value` lines for the
                      runner: `stdout=epipe` connects standard output to a pipe whose reading
                      end is closed before the program starts (for `cannot write '<stdout>':
                      Broken pipe`, LANGUAGE.md §9.2)
  rt/arm64_macos/NAME.s  (later rt/x86_64_linux/) a runtime test: an assembly program, in
                      Baysick's assembly style, that calls runtime entry points through rt.inc
                      and is linked with libsea.a; + NAME.out [+ NAME.err, NAME.status], the
                      expected bytes derived from LANGUAGE.md and §4 (`make test-rt`)
  stage.sh            runs one pass on the committed golden output of the previous pass
                      (passes/NAME.ast → seacheck → compare with NAME.hir1, and so on), so each
                      pass is tested on its own (`make test-stage`)
  protocol.sh         the pass-protocol tests (truncated inputs, missing #end, §2.2)
  check_data.sh       checks the generator (§2.6.3) on the contract files: every generated
                      line ≤ 255 bytes, every record present (`make check-data`)
  vectors/NAME.py     generators of exact test vectors (float-literal bits, printf digits),
                      run with `uv run`; their outputs are committed beside them, and the tests
                      read only the committed outputs (Python is never needed to run a test)
```

Test names carry the spec area: `lex_*`, `type_*`, `idx_*`, `op_*`, `stmt_*`, `fn_*`, `elem_*`,
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

**Reference text.** The MATLAB report text is not stored yet. Decision 7 in §9 adds a
`diary`-based capture to `run_all.m` (each script's report written to
`reference/<name>.txt` on the last repetition) and a one-time MATLAB rerun by the user.

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
* runs it 3 times, then 10 more times, each with `--export-reference` in a fresh directory,
  measuring whole-process wall time with a small exec-and-wait harness
  (`clock_gettime(CLOCK_MONOTONIC)` around `posix_spawn` + `waitpid`), and reading the program's
  own `Compute time` line;
* reports, per workload: the first run, the best of the first 3 (the pass/fail number, the same
  rule as MATLAB's baseline, §5.7), and the median and range of the 10 further runs; compute
  and whole-process; next to MATLAB's first and best from `baseline_timings_matlab.json`, and the
  ratios; plus machine model, macOS version, kernel variant, load average before and after
  (BENCH.md conventions);
* **passes** when, for every workload, Sea's best-of-3 whole-process time < MATLAB's best
  `total_seconds` and Sea's best-of-3 compute time < MATLAB's best `compute_seconds` (§1.2).

If the MATLAB rerun of Decision 7 happens, the same script also compares medians against the
new baseline's medians and reports the single-threaded MATLAB numbers; the pass criterion then
uses whichever baseline the user chose in that decision. The same script runs on the Linux host
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
  on the ssh host, default `desktop`).

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
| program size | 10 000 lines per program, 16 `SUB` parameters, no globals | **tight**: eight programs of an estimated 26 000–42 000 lines in all, two of them possibly near 10 000 (§2.7) |
| tables | arrays ≤ 10⁶ elements, 2-D string arrays, by-reference array parameters | yes, giving the capacity limits of §2.7 |
| message and template text | string constants ≤ 65 536 bytes outside `DATA` | yes, by keeping text in `DATA` |
| writing assembly text | `PRINT #` of strings writes bytes unchanged | yes |

**Conclusion.** No Baysick language change is needed to start, and none is proposed now. The
honest risk is size: the line limit and the absence of globals make the larger passes long and
repetitive, and the estimate of §2.7 could put a pass near 10 000 lines. §7.3 states the
policy for that case; Decision 2 in §9 agrees it in advance.

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
   intermediate file; move text to `DATA`; pack tables; build constants by arithmetic.
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
| 1000 `FOR` statements per program | larger limit | none; **Baysick extension** | not expected (estimate: a few hundred per pass) |
| two-character variable names | longer names | the later Dartmouth editions' long names are not verified against a primary source here; treat as a **Baysick extension** unless such a source is found | readability only; not expected to be needed |

### 7.4 Watch list

| Limit | Expected use | If reached |
|-------|--------------|------------|
| 10 000 lines per program | 2 000–9 000 per pass (estimate, §2.7) | §7.3 |
| 1000 `FOR` statements per program | a few hundred per pass (estimate) | split the pass |
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
| 3 | **Elementary functions.** Sea's own scalar `log exp sin cos pow hypot` on both targets (Decision 6) | `math/` tests pass on both targets: ≤ 1 ulp against the high-precision references, identical bits on both targets |
| 4 | **Arrays and structs.** Dynamic and fixed arrays of `f64`/`i64`/`bool`/`str`, indexing, slices, masks, `$`, views, bounds checks, COW, broadcasting, element-wise operators (one loop per operation at first), reductions in the pinned order, `linspace`, `zeros`…, `sort`/`argsort`, `find*`, `bincount`; structs, arrays of structs and projection, records, `str` and `match`, `error`, `args()` | W4's scalar SOR solver reproduces `it_sor` (±1 rule) and `T_max`; W5's sampling and statistics reproduce `first_dev`, `mean_cold`, `std_cold`, `hist_counts` using the `Dim` struct array of LANGUAGE.md Appendix D |
| 5 | **Scalar code quality.** Linear-scan allocation, invariant hoisting, strength reduction, bounds-check elimination, magic division | the W5 LCG and W4 SOR loops meet the §5.2 instruction shapes (checked on `-S` output); a micro-benchmark of each is recorded |
| 6 | **Functions and output.** Elemental functions, the inlining rule of LANGUAGE.md §8.6, named and default arguments, `format`, `write_json` (intrinsic and runtime emitter) | W1 and W5 complete (without figures): JSON passes `compare.py --candidate`, reports equivalent, outputs byte-identical across targets |
| 7 | **Fusion and SIMD.** Statement and adjacent-statement fusion, fused reductions, vectorized loops (NEON; SSE2 + AVX2 multiversioning), vector forms of the elementary functions (bit-identical to the scalar forms), buffer reuse | W1's grid bisection and W4's red-black solver run fused (no temporaries in `-S` output); W4 complete; every earlier output unchanged bit for bit |
| 8 | **Linear algebra.** `@` via Baysick's GEMM, Sea's GEMV, LU, Cholesky, triangular solves, `solve`, `rcond`, `eig_sym`; Sea kernel variants | W2 and W3 complete and accepted on both targets |
| 9 | **Plotting.** The runtime's `Figure`/`Axes` objects, SVG writer, contours, embedded PNG images | the plot tests pass; every port writes its figure with `--figures` and passes its structural check |
| 10 | **Benchmarks.** `sea/bench/` kernel and workload benchmarks, published methodology and results | §6.5 passes for all five workloads on the baseline machine; results and machine recorded in `sea/docs/BENCH.md` |

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
   nothing unmeasured and pre-agrees how a measured need is handled. Affects §2.1, §2.7, §7.
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
   MATLAB, with the single-threaded one reported. Affects §1.2, §5.7, §6.3–§6.5.
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
