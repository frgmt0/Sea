# Sea

Sea is a matrix and numerical programming language meant as an alternative to MATLAB. It has a
C/Rust-like syntax and is not MATLAB-compatible. It is the child project of
[Baysick](https://github.com/frgmt0/Baysick), a rebuild of Dartmouth BASIC (1964) written in
assembly, and the Sea compiler is itself written in Baysick.

Sea is alpha software (versions 0.y.z; 1.0.0 is v1). The language is specified in
docs/LANGUAGE.md. The compiler, runtime, tests and plan are in docs/DESIGN.md.

## Goals

In priority order:

1. Speed. Programs are compiled ahead of time to native code. Element-wise expressions are fused so
   they run without temporary arrays. The numeric kernels are hand-written SIMD (NEON on arm64,
   SSE2 and AVX2 on x86_64), chosen at run time by CPU feature. Apple Accelerate and OpenBLAS are
   the benchmark baselines, not dependencies.
2. A cleaner language than MATLAB.
3. Free, small and portable: standalone native binaries and no large runtime.

No performance claim goes in without a measurement behind it.

## Status

Phases 0 to 7 are done, and phase 8 (linear algebra) is done through 8c. DESIGN.md §8 has the
full milestone table.

- The compiler is a chain of passes: `seaparse`, `seaname`, `seacheck`, `seaexpand`, `seafuse`,
  `sealoop`, `sealower`, `seaopt`, `sealopt`, `seavec`, then a code generator per target
  (`seagen_a64` or `seagen_x64`).
- Two targets work: arm64 macOS natively, and x86_64 Linux, cross-compiled on the Mac and tested
  on a Linux host. The runtime is in assembly for each target.
- The language covers scalars, dynamic and fixed-size arrays, structs, strings, functions with
  named and default arguments, formatted output, `write_json`, fusion and SIMD code
  generation, and the matrix product `@`.
- Phase 8c added `lu`, `chol`, `solve`, `rcond` and `eig_sym`, with the `Lu` and `Chol` handle
  types. Next are the ports of W2 and W3 (phase 8d).
- Not done: the last two ports (phase 8d) and plotting (phase 9). Benchmarks against Accelerate
  and OpenBLAS are phase 10.

## Workloads

`workloads/` has seven MATLAB scripts that look like ordinary engineering work: shaft sizing,
truss FEM, a quarter-car model, plate heat conduction, a Monte Carlo tolerance stack-up, topology
optimisation and a buggy drivetrain. W1 to W5 and W7 are the acceptance targets for v1. A Sea port
of each has to reproduce the MATLAB numbers and report, and run faster. W6 is an extra reference
for later.

`ports/` has the Sea ports of W1, W4, W5 and W7. `tests/accept.sh` runs them and compares every
output key and the text report with the MATLAB reference. W2 and W3 need the linear algebra from
phase 8c and are not ported yet. `workloads/README.md` describes the scripts and how the reference
values are produced and compared.

One recorded number: on an Apple M2 Pro the W7 port computes in 0.134 to 0.135 s, against 8.602 s
for MATLAB's best compute time. DESIGN.md §6.3 notes this is a record and not a measurement under
the benchmark methodology. W7 compiles in 17.4 to 20.8 s.

## Relationship to Baysick

Sea lives in its own repository and is a git submodule of the Baysick repository at `sea/`. When
Sea needs something Baysick lacks, the feature is added to Baysick, following the later Dartmouth
editions where it can. Baysick (version 0.6.0) now covers the Second through Sixth Editions plus
a few extensions of its own, and has the two targets `arm64-macos` and `x86_64-linux`.

## Getting it

Clone Baysick with its submodules:

```bash
git clone --recurse-submodules https://github.com/frgmt0/Baysick
```

Or clone Sea directly:

```bash
git clone https://github.com/frgmt0/Sea
```

## Building and testing

The passes are compiled with Baysick, so build Baysick first (`make` in the Baysick directory, or
set `BAYSICK=<dir>`; the default is `..`). Then, in the Sea directory:

```bash
make                         # runtime, tools, passes, install into build/
build/sea build prog.sea -o prog
build/sea run prog.sea
make test                    # every test group, even if one fails
make cross                   # x86_64 Linux tests over ssh
```

`make test` needs the Apple toolchain (`as`, `ld`, `xcrun cc`) and `uv`, which the acceptance
comparison uses. `make cross` packs a bundle on the Mac and runs it on a Linux host over ssh. The
host defaults to `$SEA_CROSS_HOST`, else `desktop`, and needs GNU `as`, `gcc` and `make`.
CLAUDE.md lists the rest of the commands.
