# Sea phase-1 test corpus (WP12)

Spec-derived tests for the phase-1 scalar core (DESIGN.md §8 row 1). Every expected byte comes
from LANGUAGE.md and DESIGN.md, by hand or from the exact generators in `vectors/`, never from an
implementation (DESIGN.md §6.1). Layout and sidecars: DESIGN.md §6.2.

## Conventions the runner must follow

* Each test is built from its own directory with the bare file name (`sea build NAME.sea …`), so
  the `<file>` of every diagnostic is `NAME.sea` (LANGUAGE.md §9.1, §9.2).
* `NAME.status` holds the expected exit status in decimal and a LF. Compile errors and run-time
  errors both expect 1 (DESIGN.md §2.2 driver status 1; LANGUAGE.md §9.4).
* `errors/NAME.meta` with `stdout=epipe`: standard output is a pipe whose reading end is closed
  before the program starts (DESIGN.md §6.2); with `stdout=closed` the program starts with
  standard output closed (`>&-`, its writes fail with `EBADF`).
* From 4c every program runs with `SEA_HEAP_CHECK=1`: on status 0 its standard error must end with `heap: 0 live objects`, which the runner removes before comparing (DESIGN.md §6.2); `NAME.meta` with `heap=off` runs it without the variable, and `env=SEA_HEAP_CHECK=V` sets another value (the line is expected only for exactly `1`).
* `NAME.args` (from 4g-1): the program's arguments, one per line, read with `IFS= read -r`, so an empty line is an empty argument and leading and trailing blanks are kept (DESIGN.md §6.2); no `NAME.args` means no argument.
* `passes/`: `sea build --emit X --no-prelude NAME.sea` for each `NAME.X` present (§3.8). From 7b the kinds are `ast res hir1 hir hirf hirl lir1 lir2 lir3 lir`: `NAME.hirf` (`seafuse`, §2.12.3) exists only for a test with a construct `seafuse` rewrites (the `elem6_*` tests, whose L19 output it now is; from 7c also the `fuse7_*` dumps and `ew_colrow`, `sel_reads`, L-fb's list); a test without it has `sea.hirf` = `NAME.hir`, which `stage.sh` checks and feeds to `sealoop` (L-ek). `NAME.lir3` is the output of `sealopt` (the old `NAME.lir`); `NAME.lir` is `seavec`'s, equal to `NAME.lir3` in 7b (T11–T13 arrive in 7e). The 29 goldens with a `NAME.lir2` (`lx` and the 28 `opt5_*`) were renamed `.lir3` with `git mv` and each given a `.lir` equal to it; `lir4_seaopt` has `.lir2` only (no `.lir3`, L-bj).

## How the expected outputs were derived

| Class | Derivation |
|-------|------------|
| f64 bits of literals and constant arithmetic | `vectors/float_oracle.py`: exact `Fraction` decimal-to-binary, round to nearest even, subnormals, overflow; `+ − × ÷` and i64→f64 the same way. Python floats only as a cross-check |
| printf output (`fmt_*`, `op_f64_arith`, `op_order`, `op_powk`, `lib_consts`) | `vectors/progfmt.py`: C99 `%d %i %f %F %e %E %g %G %s` from the exact decimal value of each argument (ties to even), plus the MATLAB `%d`-on-f64 rule and the non-finite rules of LANGUAGE.md §11.1. It writes both `.sea` and `.out` from one table; Python's `%` only as a cross-check |
| `op_lcg_w5` | `vectors/lcg_w5.py`: the LCG in exact integers in W5's draw order (11 M steps), the uniform `first_dev` columns and `first_top` with the oracle; asserted bit for bit against `workloads/reference/w5_tolerance_mc.json` (`lcg_final = 2145635252`) |
| `.res` files and the `res_*` tests (phase 4a) | `vectors/res_gen.py`: an independent Python reading of DESIGN.md §3.4.1 (entered items, scopes of LANGUAGE.md §3.3/§7.2/§7.5, lids of §3.5.4, the constant order and the typed evaluation of §3.5.2 with `float_oracle.py` and `math_model.py`, `powk` of §3.5.5, the declaration errors of §2.6.2) applied to the hand-derived `.ast`; it reproduces the §3.4.1 `rs` example byte for byte and agrees with every `.hir1` golden; the `res_*` `.ast` files come from `vectors/res_cases.py`, written by hand with every position checked against the source |
| phase-3 elementary functions (`lib_math_*`, `passes/math_lower.lir1`, `passes/const_pow.hir1`, `err_const_log`, `err_const_sin`, `lib_const_sqrt`, `err_no_overload_hypot`) | `vectors/math_progs.py`: each result is the bits of the reference model `vectors/math_model.py` (DESIGN.md §4.10.6) for the argument bits of `float_oracle.py` (i64/untyped arguments converted exactly, §4.2), printed by `progfmt.py`; const results are the same model bits (FEPOW = the model, DESIGN.md §4.10.5) |
| wave-2 tests (`fold_*`, `stmt_else_if_2000`, `const_reverse_1000`, `fmt_prec_zeros`, `stmt_tasg_cvt`, `lib_conv_identity`, `stmt_for_blanks` and their `err_*`) | `vectors/wave2_gen.py`: each expected value derived in its comments; folded values with the exact oracles of `f64emu.py`/`float_oracle.py` |
| `vectors/f64emu.txt` NaN results | DESIGN.md §2.8 "NaN bits": a NaN operand propagates quieted (bit 51 set, sign and payload kept), the first NaN operand (A, then B) wins, an invalid operation gives `#7FF8000000000000`; no `grd` vectors (U1 removed the folding guards) |
| sub-phase 4d `programs/arr_*`, `programs/heap_*`, `errors/err_rt_arr_*`, `errors/err_ns_arr_str_elem`, `errors/err_ns_lib_{max1,min1}` | `vectors/arr4d_cases.py`: every expected output written out by hand from LANGUAGE.md §4.5, §5, §7.3, §7.5, §7.7, §8.3, §9.2, §10.2, §10.4, §10.7, §11.1, the derivation in a comment beside each case; error lines and columns computed from a marker in the source text |
| sub-phase 4d dump tests `passes/arr_rule{16,17,18,19,30,31,36}` | `vectors/dump4d_cases.py`: `.ast`, `.hir1` (= `.hir`), `.lir1` and `.out` written record by record from DESIGN.md §3.4, §3.5, §3.6 and §3.6.6 rules 1–19, 30, 31, 36 (each rule's example appears verbatim, with its registers and lines); `.res` from `res_gen.py`, which also checks the lids against the `.hir1` |
| sub-phase 4e-0 `.hirl` goldens (the 17 dump tests with a `.sea` and a `.lir1`) and the `passes/loop_*` tests | `vectors/hirl4e0_cases.py`: the 11 tests without a rewritten construct have `.hirl` = `.hir` byte for byte (§3.5.9 "Unchanged functions", asserted by the script); the 6 tests that use `zeros`, `ones`, `len` or a `for` over a vector (`arr_rule{16,17,18,19,30,31}`) have every record written by hand from §3.5.9 (L1–L4, types, locals, positions), never printed by a pass; the `loop_*` tests are written there in full (`.hirl` by hand from §3.5.9, `.lir1` by hand from §3.6.6 rules 1–17, 30 and "Lowering of the `sea.hirl` records", `.out` from LANGUAGE.md), each `.hirl` read back and checked against `passes.txt` (sets `H HF HL`) |
| sub-phase 4e dump tests `passes/arr_rule{20,21,22,25,28}`, `sel_{reads,ref_store,compound}`, `ew_{colrow,ind2sub}`, `arr_{lit_fixed,lit_dyn,lit_cat,lit_cat_fixed,views,dynfix,fixed,tasg_l12}` and `res_err_array` | `vectors/dump4e_cases.py`: `.ast` as pass 1 writes it (unchanged in 4e), checked against the source text; `.res` from `res_gen.py` with the phase-rule step 4e; `.hir1` (= `.hir`) by hand from §3.5.1–§3.5.5; `.hirl` from §3.5.9 (L5–L11, R1–R11) statement by statement; `.lir1` by hand from §3.6.6 (rules 1–28, "Lowering of the `sea.hirl` records"), the agreed examples of rules 20, 21, 22, 25 and 28 verbatim; `.out` from LANGUAGE.md; every file read back and checked against `passes.txt` (sets `H HF HL`, `L`) by the script's self-check, never printed by a pass |
| sub-phase 4e `programs/{sel,ew,arr,heap}_*` (the tests listed under programs/ from `sel_vec_read` on) and the 4e `errors/` tests (from `err_rt_sel_range_last` on) | `vectors/arr4e_cases.py`: every expected output written out by hand from LANGUAGE.md §4.5, §5, §6.3–§6.9, §7.3, §7.5, §8.3, §9.2, §10.1–§10.7, §11.1, and, where DESIGN.md defines the message order or position, from §2.6.2 (the error table, `at`), §3.3, §3.5.5 (static shapes, implicit `dyn`/`fix`) and §3.6.6 rules 20–28 (the order of the run-time checks); the derivation in a comment beside each case; arrays printed by small helper functions (`pf pvi pvb pmf pmi pmb`: `n:` and the elements, `RxC` and ` \|` per row), since `print` is phase 6 and the reductions 4f; error lines and columns computed from a marker in the source text |
| `programs/w4_sor_arrays` (4e, DESIGN.md §6.2) | `vectors/arr4e_cases.py`: `accept/w4_sor.sea` with the scalar set-up region replaced by §6.2's whole-array lines (the replaced region asserted line by line, everything else copied); expected output the line 4d's W4 program prints, `{"it_sor": 832, "T_max": 160.76267159277148}` (the `accept/w4_sor` row below: the IEEE mirror and `workloads/reference/w4_heat_plate.json`), because every set-up element is the same IEEE operations in the same order (LANGUAGE.md §6.8) |
| sub-phase 4f `programs/{red,sort,find,heap_red}_*`, `programs/w4_sor_reduce` and the 4f `errors/` tests (`r_red_*`, `err_red_*`, `err_sort_*`, `err_find_*`) | `vectors/arr4f_cases.py`: every expected output derived from LANGUAGE.md §8.1, §9.2, §10.5, §10.6, §11.1 and, for messages, positions and orders, DESIGN.md §2.6.2 ("Readings fixed by 4f", the error table, `at`), §3.3 and §3.6.6 rules 23, 24; floating results from a line-by-line model of §10.5 (the pinned 8-lane order with its −0.0 start and the empty +0, mean, the two-pass variance, std, the first extreme ignoring NaN) evaluated with IEEE binary64 operations in the specified order (Python floats as a calculator, never a run of the compiler); each `f64` sum vector of 4 or more elements chosen and asserted so the 8-lane result differs from left-to-right summation; `i64` sums checked in index order (Decision 42); sorting by a stable model of §10.6 (−0 == +0, NaN after every number ascending and before every number descending); the derivation in a comment beside each case; error lines and columns computed from a marker in the source text; `w4_sor_reduce` from `programs/w4_sor_arrays.sea` with its hot-spot loop replaced (the replaced region asserted), its `.out` copied byte for byte |
| sub-phase 4g-1 `programs/{str,match,args,heap_str}_*`, `programs/sort_str` and the 4g-1 `errors/` tests (`r_str_*`, `r_args_*`, `r_error_*`, `err_str_*`, `err_match_*`, `err_error_*`, `err_lower_*`, `err_args_*`, `err_const_str_*`; `err_ns_str_fixed_let` was retired by 4g-2), the re-derived `err_const_noval_{calltype,errtype,shortcircuit}` | `vectors/str4g_cases.py`: every expected byte derived from LANGUAGE.md §3.5, §4.4, §4.5, §4.8, §5, §6.2–§6.4, §6.9, §6.10, §7.2, §7.3, §7.5, §7.6, §8.1–§8.4, §9.1–§9.4, §10.2, §10.6, §10.9, §10.10, §11.1 and, for messages, positions and orders, DESIGN.md §2.6.2 (the error table, `at`, "Readings fixed by 4g", "Within one formatting call", the phase-rule row 4g-1), §3.3 and §3.4; an independent model with string values as bytes decoded from the literals as §3.5 says: `+` as concatenation, the comparisons byte-wise unsigned with a proper prefix the smaller (Python's bytes order), `str(f64)` as C's `%.17g` with `nan`, `inf`, `-inf`, `str(i64)` in decimal, ASCII `lower` (A–Z only), `%s` width and precision in bytes, a stable sort on bytes (descending with ties in input order); never a run of the compiler; error lines and columns computed from a marker in the source text |
| sub-phase 4g-2 `programs/{struct,heap_struct}_*`, `programs/str_fixed`, `programs/records` and the 4g-2 `errors/` tests (`err_struct_*`, `err_record_*`, `r_str_fix`, `r_struct_dollar_*`) | `vectors/struct4g_cases.py`: every expected byte derived from LANGUAGE.md §4.5–§4.7, §5.5, §5.6, §6.8 rule 5, §6.9, §6.10, §7.2, §7.3, §7.5, §8.2–§8.4, §9.2, §10.2, §10.6, §11.1 and, for messages, positions and orders, DESIGN.md §2.6.2 (the error table, `at`, the type spelling of `text` with a record as `{name: T, …}`, "Readings fixed by 4g"), §3.3 (a `dot` or `bin` stands at its left operand), §3.4, §3.4.2 (the struct declaration checks) and §3.5.5 ("Evaluation order": literal values in source order); an independent model with struct and record values as Python dicts copied deeply on every binding, assignment, argument and result (value semantics; copy on write is invisible), `$` the length of the innermost indexed list (a matrix: its row or column count), a `ref` parameter the caller's value itself, `%g` as C99; expected values computed step by step in program order; never a run of the compiler; error lines and columns computed from a marker in the source text |
| `programs/manualD_part1`, `errors/manualD_part1_badopt` (4g-2) | `vectors/manualD_part1.py`: the source is LANGUAGE.md Appendix D from `struct Dim {` through `let rssSigma = sqrt(rssVar)` verbatim without its `linspace` line, plus DESIGN.md §6.2's nine lines (no header comment, so the options loop's `_` arm is line 16, asserted); the 12 lines from an IEEE binary64 model of the program in its order (the Dim table parsed from the copied text, sums left to right, `sign * nom` with the `i64` converted, `tol / 3`, `tol / sqrt(3)`, `tol / sqrt(6)` with a correctly rounded `sqrt`, `^ 2` as one multiplication, `%.17g`), asserted equal to the 12 lines written in DESIGN.md §6.2 |
| sub-phase 4h `programs/{prel,heap_prel}_*`, the 4h `errors/` tests (`r_prel_*`, `err_prel_*`) and the close-out tests `err_ns_matmul`, `err_ns_lib_{format,solve,figure}` | `vectors/prel4h_cases.py`: an independent model of LANGUAGE.md §10.3, §10.6 and §10.7 in IEEE binary64 (Python floats as a calculator, never a run of the compiler): `linspace` by its three cases (n < 1 empty, n = 1 `[d2]`; `d1 == -d2` and n > 2: one quotient `d2 / n1`, `(-n1 + 2k)` converted exactly times it, the ends set and an even n1's middle set to +0; otherwise multiply, divide, add, then every element d1 when `d1 == d2`, else the two ends), `setdiff` as the sorted distinct values of a not in b, `bincount` by counting with the size check first (DESIGN.md §2.5) and the first value outside 0 … n − 1 in index order, `meshgrid` by indexing with i64 arguments converted ties to even (§4.2); printed as §11.1 says (`%.17g`, `%g` as C99, `NaN`, `Inf`, `-Inf`); evaluation order from §6.4, §6.8 rule 5, §6.10 and DESIGN.md §3.6.6 rule 12 with §3.5.9 R30 (`setdiff(v, grow(ref v))` sees the old v); messages, positions and lines from DESIGN.md §2.6.2 (the error table, `at`, "Readings fixed by 4h": L-s, L-t, L-y, L-z; the after-phase-4 table), §3.3 (a `bin` at its left operand); run-time errors at the line of the program's call; error lines and columns computed from a marker in the source text |
| sub-phases 5c-1 and 5c-2 `programs/opt_*` and `errors/r_opt_*` (DESIGN.md §6.2 "Phase-5 tests", the `opt_*` programs; 5c-2 adds the adversarial cases for T4–T9 and Decision 75) | `vectors/opt5c1_cases.py`: every expected byte derived from LANGUAGE.md, never from a run of the compiler: an independent model with `i64` arithmetic in exact integers (a result outside −2⁶³ … 2⁶³ − 1 is `integer overflow`, §6.5), floored `%` and `idiv` (Python's integer `%` and `//`, §6.6; a zero divisor `integer division by zero`, `idiv(-2⁶³, -1)` an overflow while `-2⁶³ % -1` is 0), `f64` as IEEE binary64 (Python floats as a calculator; the six comparisons false with a NaN operand except `!=`, §6.4), `printf` as §11.1 (`%d`, `%g`, `%.17g` as C99 with `NaN`, `Inf`, `-Inf`) and `str()` as §10.9 (`nan`, `inf`, `-inf`); evaluation left to right (§6.8 rule 5), index checks after the indices (§5.4), a compound assignment reading before it evaluates its right side (§5.5), range lengths by §5.1, value semantics of arrays (§4.5) and `ref` as the caller's variable (§8.3); the dividends of `opt_div_const` (−2⁶³, −2⁶³ + 1, −1, 0, 1, 2⁶³ − 1 and the divisor's multiples ± 1 near 0 and near both i64 bounds) generated from each divisor; error lines computed from a marker in the source text |
| sub-phase 5b pass-4 tests `passes/ra5_*` (`.lir`, `.out`, `.err`, `.status`) | `vectors/ra5_gen.py` with `vectors/lirkit.py`: the LIR is written with symbolic names that `lirkit.Test` renumbers per DESIGN.md §3.6.1–§3.6.3. Each expected output is computed by `lirkit.Interp`, an independent Python reading of the instruction semantics of §3.6.4: floored `idivf`/`imodf`, `rcount`'s n, IEEE `fcmp`, `fmin`/`fmax` of LANGUAGE.md §10.4, floor/ceil/trunc/round-away, `loop`/`next`/`exit`, `sea_arr_new` of §4.8, `retain`/`release`. It also implements LANGUAGE.md §11.1 printf (`%d` of i64 and f64, `%.17g`, MATLAB NaN/Inf) and the run-time error lines of `errors.inc`, working from the LIR text alone, never from a code generator. Implementer reading: `ind` after a normally ended `loop` holds start + last·step (L-ai's closing form). |
| sub-phases 5c-1/5c-2 `passes/opt5_*` dumps, `passes/lir4_seaopt.lir2`, `passes/lx.lir2`/`lx.lir3`/`lx.lir` (DESIGN.md §6.2 "Phase-5 tests", L-ak) | `vectors/dump5_cases.py`: `.lir1` from the phase-4 passes (the input); `.lir2` by §5.8's T1–T4 and T10 (L-bq, L-bn), `.lir3` by T5–T10 (L-bl, L-bm, L-br, L-bs, L-bt; `.lir` equal to it from 7b), both hand-derived with the event list each case must produce, never by running `seaopt` or `sealopt` |
| `accept/w5_stats` (4h acceptance, DESIGN.md §6.3, lead decision L-aa) | `vectors/prel4h_cases.py` copies LANGUAGE.md Appendix D's code verbatim for what the four keys need (each block asserted to be Appendix D's lines in Appendix D's order; `args()`, `now()`, the report, the figures, the export, `prctile_mid`, `lcgFinal` and the analytic limits asserted absent), then appends the `printf` JSON of §6.3; the expected values are the committed MATLAB reference `workloads/reference/w5_tolerance_mc.json`, compared by `accept4.sh` through `compare.py --candidate --keys first_dev,mean_cold,std_cold,hist_counts` (on the Linux host: byte identity with the Mac's output). A NumPy mirror of the copied program (scratch, not committed; its `log`, `cos`, `sqrt` are NumPy's, so it checks the selection and the JSON format, not Sea's bits) passes that comparison |
| `accept/w4_sor` (4d acceptance, DESIGN.md §6.3) | ported by hand from `workloads/w4_heat_plate.m` (inputs, scalar SOR); checked by `compare.py --candidate --keys it_sor,T_max` against `workloads/reference/w4_heat_plate.json`; a line-by-line IEEE mirror of the port in Python (scratch, not committed) prints `{"it_sor": 832, "T_max": 160.76267159277148}`, the reference values exactly |
| sub-phase 6b `programs/fmod_*` (DESIGN.md §6.2 "6b, calls", L-cm) | `vectors/fmod6_cases.py`: every expected value computed with `math.fmod` (the C library's exact `fmod`) and LANGUAGE.md §6.6's sign adjustment in this order: b = ±0 gives a unchanged, an infinite a or a NaN operand gives NaN, r = fmod(a, b), then r + b rounded once when r ≠ 0 and r and b differ in sign; never Python's `%` (it gives +0.0 for `-6.0 % 3.0` where §6.6 gives −0.0). Self-checks on every run: `math.fmod` equals the exact rational remainder (`fractions.Fraction`), the adjusted sum equals the exactly rounded rational, Python's `%` agrees on the value of every finite result. The same 403 vectors (special cases and 160 deterministic pseudo-random pairs) are the table `--emit-asm` prints for the runtime tests `rt_fmod_vec` (`--check-asm FILE` checks a test's copy). Printing by the exact printf oracle of `progfmt.py` (`%.17g`, `str()` as §10.9) |
| sub-phase 6b `programs/{call6,inl,fmt6,print,mkdir}_*` and `errors/{err_call6,r_inl6,r_mkdir}_*`, `r_print_flush`, `err_ns_lib_write_json`, the five re-derived L-by goldens and the retired `err_ns_*` goldens (DESIGN.md §6.2 "Phase-6 tests") | `vectors/call6_cases.py`: each program has a Python mirror beside it (exact integers for `i64`, IEEE binary64 for `f64`, `progfmt.format_all` for every printed `f64`), the clause that fixes each expected byte in its header comment; `fmt6_*` captures the cases of `progfmt.py`'s `fmt_{f,e,g,d,d_f64,s,pct,nonfinite}` generators and of `fmt_d_ext` and `fmt_prec_zeros`, each as `printf(F, …)` then `print(format(F, …))`, the expected output being the oracle's bytes twice; error positions from DESIGN.md §2.6.2 (`at`) and §3.3, checked against the AST of the source (`sea build --emit ast`: a call at its callee name, a `bin` at its left operand, a `param` and a `narg` at their names); run-time lines are the callee's (DESIGN.md §3.6.4 "Sites") except an argument, a deferred `ref` argument's recheck and `make_dir`. The `inl_*` programs that use no phase-6 construct and the `r_inl6_*` tests (but `r_inl6_default_arg`) were also run with the pre-phase-6 compiler, which does not inline: same bytes |
| sub-phase 6c `programs/{elem,ind2sub_arr}_*` and `errors/{r_elem6,err_elem6}_*`, the re-derived `err_merge_same_pos`, the retired `err_ns_elemental` and `err_ns_ind2sub_array` (DESIGN.md §6.2 "6c, elemental functions") | `vectors/elem6_cases.py`: every expected byte derived from LANGUAGE.md §4.5, §5, §6.3, §6.6, §7.3, §8.1, §8.5, §9.2, §9.3, §10.7, §11.1 and, for messages, positions and orders, DESIGN.md §2.6.2 (the error table, `at`, "Order across the two programs"), §2.11.2 (L-cq: 228, 232, 253; "Elemental calls": 201, 202, 217), §2.11.4 (L19, L-ck, L-cl) and §3.5.5 (static shapes); a Python mirror of each program (exact integers, IEEE binary64 operations in the programs' order, broadcasting by LANGUAGE.md §6.3, results in column-major order, printed through `progfmt.py`'s exact `%g` and `%.6f`), never a run of the compiler; every `_after` error test is the plain test behind an earlier error of the other program of pass 2a; error lines and columns computed from a marker in the source text |
| sub-phase 6d `programs/json_*` (with `NAME.expect/`) and `errors/r_json_*`, the retired `err_ns_lib_write_json` (DESIGN.md §6.2 "6d, `write_json`") | `vectors/json6_cases.py`: every expected file derived from LANGUAGE.md §11.4 and DESIGN.md §2.11.6 "Layout" by an independent Python mirror: the JSON tree is built in Python (exact integers for `i64`, IEEE binary64 for `f64`, bytes for `str`, pairs for structs and records, lists for arrays, `[]` for a matrix with a zero extent) and written by the layout (two spaces per level, one member or element per line, `{}` and `[]`, LF after the top value); finite `f64` through `progfmt.py`'s exact `%.17g` (also compared with Python's), NaN and ±∞ as `null`, `-0.0` as `-0`, strings escaped by §11.4 (`\\n`, `\\t`, other bytes below 0x20 as `\\u00xx` lowercase, every other byte unchanged); the Sea literals are generated from the same Python values; messages from `errors.inc` (`CANNOT_OPEN`, the errno table), run-time lines are the `write_json` call's line (pass 2b binds the path, then the value, before `jopen`, DESIGN.md §3.5.7 step 4). The programs were also compiled and run with `write_json(p, v)` replaced by `let p' = p; let v' = v` (the typing of every value and the non-JSON output; scratch check, not committed) |
| sub-phases 7b and 7c `passes/*.hirf`: the `elem6_*` L19 goldens (7b), the `fuse7_*` dumps and the goldens of L-fb's list (7c; DESIGN.md §6.2 "Phase-7 tests", Decision 97) | `vectors/dump7_cases.py`: part 1 scans every `.hir` golden for the constructs `seafuse` rewrites (L-ek); part 2 writes the 7b `elem6_*` `.hirf` by a transcription of §2.11.4 L19 with §2.12.3's rules (1)–(5); part 3 cross-checks them against the committed `.hirl` through a model of `sealoop`'s remaining rewrites; part 4 writes each `fuse7_*` `.hirf` from its `.hir` by a transcription of F1–F5 (§2.12.4), which rewrite applies to which statement decided by hand (its table `FUSE7`, readings R-a … R-j); the `.hirl` and `.lir1` of those tests follow from the `.hirf` by the unchanged `sealoop` and `sealower`, `.out` from LANGUAGE.md; the re-derived `ew_colrow`, `sel_reads` and `elem6_inst` goldens (T2b) by hand from §2.12.4 with the rules of L-fb's list under "passes/ rows of sub-phase 7c" |
| sub-phase 7c `programs/fuse_*` and `errors/r_fuse_*` (DESIGN.md §6.2 "Phase-7 tests", the `fuse_*` and `r_fuse_*` bullets) | `vectors/fuse7c_programs.py` (run with `--out DIR`, a scratch directory; it refuses the repo tree): fusion changes no behaviour (DESIGN.md §2.12.2), so every expected byte is the operator-by-operator meaning of LANGUAGE.md, computed by a Python mirror beside each program: exact integers for `i64` (overflow §6.5), IEEE binary64 for `f64` in the parse tree's order (§6.8; `sqrt` correctly rounded, `^ k` with \|k\| ≤ 4 the pinned multiplications of §6.5, `exp log sin cos pow hypot` from the bit-exact model `vectors/math_model.py`, DESIGN.md §4.10.6), two-argument `min`/`max` by §10.4, broadcasting by §6.3, masks and `.flat` in column-major order (§5.2, §5.6), the reductions of §10.5 (8 lanes from −0.0 with the pinned final tree, empty +0, two-pass `variance`, first extreme with NaN ignored, checked `i64` partial sums, positions within a selection), printed through `progfmt.py`'s exact `%.17g`; the values the bullets name are asserted (`argmax(v[m])` = 1, v[0] = 3, `max` with ties, NaN and ±0), and the `sum` data are asserted to give a different result under left-to-right summation and, for a selection, under lanes counted by the whole vector's position; the `r_fuse_*` errors follow the reference order of DESIGN.md §2.12.2 (2) (each tree node's operands left to right, then its shape check, then its loop; the store after the value, LANGUAGE.md §5.5; statements in order), messages from LANGUAGE.md §9.2, lines from a marker in the source text; never a run of the compiler. All 37 pass unchanged on the pre-fusion compiler (sea 3c35e89) on both targets, as DESIGN.md §2.12.2 requires |
| sub-phase 7e `programs/vec_*` (DESIGN.md §6.2 "Phase-7 tests", the `vec_*` bullet) | vectorization changes no behaviour (LANGUAGE.md §6.8 4.), so every expected byte is the operator-by-operator meaning of LANGUAGE.md computed by an independent Python mirror written beside each program (IEEE binary64 in the parse tree's order; two-argument `min`/`max` by §10.4's rule t = b < a, NaN first operand gives the second; comparisons and `where` per element; `sum` in §10.5's 8-lane order from −0.0 with the pinned final tree, asserted different from left-to-right for the 9- and 17-element data of `vec_sum8`; `%.17g` with the MATLAB spellings `NaN`, `Inf`, `-Inf`); `log exp sin cos pow hypot` results are never computed: each is the bit pattern of the committed reference row of `tests/math/NAME.vec` for the argument bits (the generator asserts every argument is a row), and the `vec_fn_*` programs print per-lane match counts against those bits beside the printed values. The programs were run on the pre-vectorization compiler (all pass) before `seavec` exists; each header names the loops meant to vectorize and the §2.12.6 conditions they rely on |
| other `programs/` | by hand (integer results, halves, short decimal values) |
| `errors/` | message texts from the error table (DESIGN.md §2.6.2), column from its `at` column; run-time lines from the LIR site rules (§3.6.4, §3.6.6, §4.6) |
| `passes/` (validated with `build/tools/seaval`, exit 0 for every dump) | by hand from DESIGN.md §3 record by record (post-order, positions §3.3/§3.5.5, numbering §3.5.1/§3.5.4/§3.6.1, canonical lowering §3.6.6). `ex.ast`, `lx.lir1`, `lx.lir` are the DESIGN examples verbatim |

## programs/

| Test | Spec |
|------|------|
| `op_int_arith` | LANGUAGE.md §6.5, §6.6, §6.1 (i64 exact ops, floored `idiv`/`%`, −2⁶³ % −1 = 0) |
| `op_f64_arith` | §6.5, §6.8 rule 1, §4.2 (`/` of i64), IEEE Inf/NaN/−0/subnormal results |
| `op_order` | §6.1, §6.8 rules 1–2 (left association, no reassociation, no FMA) |
| `op_powk` | §6.5 (pinned multiplications, x^−k = 1/x^k, `nan ^ 0` = 1, `-x ^ 2`) |
| `op_cmp` | §6.4, §4.2 (NaN comparisons, mixed i64/f64 converts the i64) |
| `op_logic` | §6.4, §6.1 (short circuit, `&` and `\|` evaluate both, precedence) |
| `op_cvt` | §4.2, §10.1 (`f64()`, `i64()`, implicit conversion, ties to even) |
| `op_lcg_w5` | §2.5, Appendix D; DESIGN.md §8 phase-1 acceptance |
| `stmt_if` | §7.4, §3.7 rule 3 (newline, blank and comment lines before `else`) |
| `stmt_while` | §7.4 |
| `stmt_ifx` | §6.10 (only the selected arm runs, arm type conversion) |
| `stmt_for` | §5.1, §7.5 (half-open, `..=`, negative step, empty ranges, bounds once, exact count at the i64 limits) |
| `stmt_break_continue` | §7.5 |
| `stmt_scope` | §7.2 (block scope, shadowing, `var lo = lo`) |
| `fn_call` | §8.1, §8.2, §6.8 rule 5, §7.2 (functions visible before declaration) |
| `fn_recursion` | §8.6 (direct, mutual, depth 100 000); DESIGN.md §4.6 |
| `fn_ref` | §8.3, §4.2 (var typed by a ref use) |
| `fn_ref_order` | §6.8 rule 5, §8.3 (reads before a `ref` call see the old value, reads after it the new one, `x = g(ref x)` keeps the result) |
| `fn_multi` | §8.4, §7.2, §7.3 (tuple patterns, `_`, tuple assignment, `return f()`) |
| `fn_many` | §8.1, §8.4 (10 + 10 parameters, 10 results) |
| `heap_env_unset` | DESIGN.md §4.5 `SEA_HEAP_CHECK`, §6.2: run with `heap=off` (the variable unset), standard error stays empty (no `heap:` line) |
| `heap_env_other` | DESIGN.md §4.5, §6.2: run with `env=SEA_HEAP_CHECK=2` (not exactly `1`), standard error stays empty |
| `lib_const_sqrt` | LANGUAGE.md §7.2, §10.4; DESIGN.md §2.6.2 step 4d: `sqrt` in a constant has its value from 4d (the correctly rounded √2, `%.17g`; replaces phase 3's `err_const_sqrt`) |
| `arr_construct` | LANGUAGE.md §10.2, §4.5: `zeros(0)`, `zeros(3)`, `zeros(3, 0)`, `zeros(0, 4)`, `ones`, `filled` of `f64`, `i64` (an untyped integer value, bound to an `i64` annotation) and `bool`, `len rows cols numel`, empty arrays |
| `arr_rw` | §5.1, §5.2, §5.5: element read and write of `f64[] i64[] bool[] f64[,] i64[,] bool[,]` |
| `arr_dollar` | §5.3: `$` in each dimension, in arithmetic, nested (`v[w[$ - 1]]` is `len(w)`), in a store and a compound store |
| `arr_compound` | §5.5, §7.3: `+= -= *= /=` on elements of `f64[]`, `i64[]` (checked), `f64[,]`, an index expression on both sides |
| `arr_compound_ref` | §5.5 C6, §8.3: `v[0] += g(ref v)` with g replacing v: the read sees the old array, the store the new |
| `arr_locals_params` | §4.5, §8.2, §8.4: arrays as `let`/`var` locals, parameters, one and several results (the same array twice), matrices |
| `arr_ref_param` | §8.3, §4.5: an element store through `ref` copies a shared array (`let b = a` unchanged), a whole-array store through `ref`, a `ref` passed on, a matrix |
| `arr_fore` | §7.5: the vector is held (reassigning it in the body keeps the iteration), `i64[]`, `bool[]`, empty and fresh vectors |
| `arr_cow` | §4.5, §8.2: `var b = a; b[0] = 1.0` leaves `a`; stores in a loop; a `var` copy of a parameter; a matrix |
| `arr_ref_nested_old` | §6.8 rule 5, §8.3; DESIGN.md §3.6.6 rule 12 (a): `f(a, g(ref a))`, f sees the old array, nothing leaks |
| `arr_ref_nested_var` | DESIGN.md §3.6.6 rule 31 (deferred `ref` arguments): `f(ref x, g(ref x))` for an `i64` (23, not the phase-1 3) and an `f64[]` local |
| `arr_ref_nested_elem` | rule 31: `f(ref v[0], g(ref v))` with g growing v (vector and matrix): f updates the new array's element |
| `arr_math_f64` | LANGUAGE.md §10.4, §6.7, §11.1: `abs sign sqrt floor ceil trunc round isnan min max where` on ±0, NaN, ±∞ (`sign(-0.0)` prints `-0`, NaN never signed, `min(-0, 0)` the first) |
| `arr_math_i64` | §10.4: `abs sign min max` on `i64` with ±(2⁶³ − 1) and −2⁶³ |
| `arr_index_util` | §10.7, §6.6: `ind2sub` (floored, negative k), `sub2ind`, their round trip |
| `arr_ref_in_target` | §5.5 C4, C6, §7.3; DESIGN.md §3.6.6 rule 12: a `ref` call in an assignment target's own index (`=`, `op=`, a tuple target, through a `ref` parameter) grows the array; the checks and the store use the new one, nothing leaks |
| `arr_tasg_lib` | §10.7, §7.3, §4.2: a tuple assignment from `ind2sub` to scalars, to elements (converted to `f64`) and with `_` |
| `heap_break` | §7.7; DESIGN.md §3.6.6 rule 16 (b): array locals of every block a `break` leaves (nested blocks, nested loops) |
| `heap_continue` | rule 16 (b): the same for `continue` (`for` and `while`) |
| `heap_return` | rule 16 (c): `return` from nested blocks and loops (`findpair`, `early`) |
| `heap_pick` | rules 15 (a), 16 (c): returning one of two array locals or parameters; temporaries as arguments |
| `heap_fore_exit` | rules 16 (f), 30: the held vector released after the loop, by a `return` inside it, once on `break`/`continue`, nested element loops |
| `heap_temps` | rule 15 (b), (h): call results indexed, measured, passed, discarded (`eval`, `let _`, `_` components) |
| `heap_reassign` | rules 15 (d), 31: reassignment (also `a = a`, in a loop, through `ref`) releases the old array |
| `heap_ifx` | rules 3, 15 (b): `if` expressions of an array type with fresh and borrowed arms |
| `arr_eval_order_ref` | §5.5, §7.3; DESIGN.md §3.5.5 G1, §3.6.6 rule 12: `v[bump(ref x)] = x` stores x as it was before the index's `ref` call (the value first); tuple targets after the call (`(a, w[bump(ref k)]) = h2(k)`, `(y, u[i]) = hr(ref i)`) |
| `heap_rule12_stale` | rules 12 (a), 15, 16 (c): `return (b, g(ref b))` returns the old array b held by its retained copy; the replacement is released, nothing leaks |
| `sel_vec_read` | LANGUAGE.md §5.1–§5.4 (4e): vector selections read from a fixed and a dynamic vector: `a..b`, `a..=b`, steps, negative steps, empty ranges (also past the extent: never checked), `:`, `$` in a range and in a literal inside an index, index vectors with repeats (fixed, dynamic, a range value, empty), masks (fixed, of a comparison, all false), nested selections |
| `sel_mat_read` | §5.2: matrix selections: row, column, block, `0..1` (a 1 × cols matrix), steps and negative steps in both dimensions, empty rows and columns (`0x4`, `3x0`), index vectors in both dimensions with repeats, a mask of the rows and of the columns, whole-matrix masks in column-major order, `$` per dimension, `i64` and `bool` matrices |
| `sel_vec_store` | §5.5: `=` to vector selections with a scalar and with an array: ranges, negative steps, empty selections (also `= []`), `:`, index vectors with repeats (the last store wins), masks with a scalar and with an `nnz`-element vector, `i64[]` and `bool[]` targets, a fixed-size target |
| `sel_mat_store` | §5.5: rows, columns, blocks, an index-vector selection with repeated positions (stored in the selection's column-major order), masks of the matrix and of the rows, negative steps, `:`, an `i64[,]`, a fixed `f64[2,2]` and a `bool[,]` target |
| `sel_compound_ops` | §5.5, §6.3: `+= -= *= /=` on ranges, `:`, masks and index vectors with repeats (gather, operate, scatter), on vectors and matrices, `.flat` with an index vector, a selection with a broadcast column and row, W2's `K[idx, idx] += ke` with a repeated index |
| `ew_compound` | §7.3, §6.3; DESIGN.md §3.6.6 rule 15 (i): `a += b` of whole arrays (`f64[]`, a fixed `f64[2]`, `i64[]`), a dynamic 1 × 3 matrix that becomes 2 × 3 by broadcasting (a whole assignment replaces the shape) |
| `sel_alias` | §5.5 "Aliasing": shifts right and left, an in-place reversal, a swap by index vectors, a value reading the target, a matrix row shift, `.flat` shift, `A = A.T`, a fixed-size target and a fixed-size value that is the target itself |
| `sel_alias_index` | §5.5; Decision 34 (DESIGN.md §6.2's case verbatim): `v[v] = 5` prints `5 5 5`, `w[w] += 10` prints `11 12 10`, on dynamic `i64[]` and on fixed `i64[3]` locals |
| `sel_ref_reads` | §5.5, §8.3; DESIGN.md §3.6.6 rule 12 across an L6 block (§6.2's cases): `v[0..g(ref k)] = k` stores the old `k`, `B[i, g(ref i)..3] = 0.0` uses the old row, `A.flat[m] += g(ref m)` updates the old element |
| `sel_mask_scalar` | §5.2, §5.5 (§6.2's case): `T[T > 100.0] = 100.0` on a dynamic and on a fixed matrix |
| `sel_order` | §5.5, §6.8 rule 5: `v[0..2] += grow(ref v)` (the read sees the old `v`, the store the new one); the value before the range bounds and the column index for `=`, the indices before the read and the value for `+=`; index-vector elements after the value |
| `sel_views` | §5.6, §7.3: `.T .flat .col .row` read, folded into an index and materialized, of fixed, dynamic and temporary operands, nested views (`A.T.flat[3]`, `M.T.T`, `v.row.T`), empty matrices; `.flat` written by an element, a range, a mask and a compound index-vector store |
| `sel_ref_param` | §8.3, §5.5, §4.5: selection stores through `ref` parameters (a range, a compound row, a mask); the caller's other variable sharing the array is unchanged |
| `ew_arith_f64` | §6.2, §6.3, §6.5: `+ - * / ^` and unary `-` element-wise, scalar with array both ways, pinned powers (2, 4, −1, 3, 0) and `pow`, `i64` elements converted, `i64 / i64`, −0, `Inf`, `NaN`, a 300-element range value, a matrix product element by element |
| `ew_arith_i64` | §6.3, §6.5, §6.6, §10.4: `+ - * %` (floored), unary `-`, `idiv`, `abs sign min max` on `i64` arrays, range values multiplied, `/` giving `f64`, `i64` matrices |
| `ew_cmp_logic` | §6.3, §6.4: the six comparisons with NaN and −0, mixed `i64`/`f64`, `bool` `==`/`!=`, `& \| !` on `bool` arrays and with scalars, `isnan`, matrix comparisons, broadcasting `.col < .row` |
| `ew_broadcast` | §6.3: column with row, matrix with row and with column, a 1 × 1 matrix, scalars, `0x3` with `1x3` (and both orders), `0x1` with `1x0`, dynamic with fixed, the outer product `u.col * u.row`, `i64` with `f64` |
| `ew_where` | §10.4, §6.3: `where` with array and scalar arms, `i64` with `f64` arms, `bool` arms, matrix broadcasting, all three arguments evaluated in order |
| `ew_math` | §10.4, §6.7, §10.1: the elemental functions on arrays with NaN, ±0 and ties (`round` away from zero, `sign(-0)`, `min(-0, 0)` the first), `sqrt` of `i64` elements, `log exp sin cos pow hypot` with exact results, array and scalar forms bit-identical |
| `ew_cvt` | §4.2, §10.1: `f64(a)`, `i64(a)` of `i64`, `f64` (−0, 1e15) and `bool` arrays, the identities, implicit `i64[]` → `f64[]` for a parameter and a binding, an empty conversion |
| `ew_index_util` | §10.7, §6.6; Decision 33: `ind2sub(3, k)` of a vector (floored, negative k), `sub2ind` on vectors with a broadcast scalar, the round trip, an empty `k`, a tuple assignment to `i64[]` variables, the scalar form |
| `arr_literals` | §6.9, §4.5: fixed literals of each scalar kind, untyped elements, trailing separators, newlines, 256 elements (fixed: an `i64[256]` binding) and 257 (dynamic), concatenation of scalars, vectors, range values and matrices (rows joined, vector rows stacked, a scalar as 1 × 1, empty parts), `[]` under a declared vector, matrix and fixed type, an assignment target, a selection, a parameter, a `return` and an `if` arm |
| `arr_ranges` | §5.1, §6.1: range values with steps, negative steps, empty, exact lengths at the `i64` limits (±2⁶³ bounds, a 2⁶² step), arithmetic on them, `for x in (range)` and over a range expression |
| `arr_fixed_vals` | §4.5; Decision 32: fixed-size locals, value semantics, parameters, results, tuple components (`let`, tuple assignment, `_`), a `ref` parameter, `f64[2,2]` results and parameters, `for`, `$`, `len rows cols numel`, `i64[3]` and `bool[2]` |
| `arr_fixdyn_conv` | §4.5; DESIGN.md §3.5.5 (implicit `dyn`/`fix`): at bindings, assignments, arguments and returns, from a selection, `if` expressions with arms of different fixed shapes, a dynamic arm and one fixed shape, matrices |
| `heap_sel_temps` | DESIGN.md §3.6.6 rules 15, 20, 28: selections of call results (ranges, temporary index vectors and masks, nested), views of temporaries, a selection held per iteration, a discarded one |
| `heap_sel_store` | rules 15, 19, 21: selection stores with temporary values, index vectors and masks, copy on write of a shared target, a compound store in a loop, matrix stores of views of temporaries |
| `heap_ew_temps` | rules 15, 22, 26: element-wise operations, broadcasting, conversions, concatenations, `where`, `sqrt` and `ind2sub` on temporaries; reassignment and whole-array compound assignment in a loop |
| `heap_early_exit` | rule 16: `return` from an element loop over a held selection, `break`/`continue` in a loop over a range-value expression, returns of a selection and of an element-wise result, `break` out of a `while` holding a temporary |
| `heap_fixed` | rule 27 (i), (j), (k): `fix` at a return from a selection, `dyn` at a return and a binding, `if` expressions with a dynamic arm, then `fix` |
| `w4_sor_arrays` | DESIGN.md §6.2 (4e), §6.3; LANGUAGE.md §6.8: `accept/w4_sor.sea` with its set-up as whole-array code (range values, `.row`/`.col` broadcasting, comparisons and `&`, a mask store, row stores, `fixed` sharing `hole`'s buffer); prints 4d's W4 line `{"it_sor": 832, "T_max": 160.76267159277148}` |
| `sel_tasg` | LANGUAGE.md §7.3 as amended by Decision 37, §4.2, §4.5, §5.5, §10.7 (DESIGN.md §3.5.9 L12): tuple assignment to a range selection, a `.flat` element, a matrix row from a fixed `f64[2]` result, fixed into dynamic, dynamic into fixed, an `i64[]` result into an `f64[]` target, `ind2sub` into dynamic targets, into a selection target not last and into two matrix rows, `(u[0..2], u[1]) = lw()` (the last store wins), `(u2[g(ref j)..3], w[j]) = lw()` (the second target reads the new `j`) |
| `heap_tasg` | §7.3; DESIGN.md §3.5.9 L12, §3.6.6 rules 15 (h), (j), 16: `_` components with a dynamic result, converted and selection targets in a loop, `let (_, y)` |
| `sel_ref_range` | §5.5, §8.3; DESIGN.md §3.6.6 rule 12 (§6.2's regressions): `v[k..k+2] += f64(g(ref k))` on a dynamic and a fixed vector (`2 2 0 0`), `A[k, 0..2] += f64(g(ref k))` (`2 2 \| 0 0`), `A[k..1, g(ref k)..3] = 9.0` (row 0, columns 1–2) |
| `sel_tasg_cvt` | §7.3 as amended by Decision 37, §4.2 (b), (c), §4.5, §5.5: a fixed `i64[3]` result into an `f64[]` target (element-by-element conversion and `dyn`), a dynamic `i64[]` result into an `f64[3]` target (conversion and the run-time shape check), scalar `f64` and `i64` results into range-selection targets (stored into every element, the `i64` converted) |
| `red_sum_f64` | §10.5 (4f): `f64` `sum` in the pinned 8-lane order on 7, 8, 9 and 17 elements (each differs from left to right: 2, 6, 7, 14), fixed and dynamic operands, compared with `==` to exact literals; 0 and 1 elements (`0`, `sum([-0.0])` = `-0`), zero signs, NaN, ±Inf, `Inf + -Inf` from four 1e308 terms, overflow to Inf |
| `red_sum_i64` | §10.5, Decision 42: `i64` `sum` with every partial sum fitting, totals at 2⁶³ − 1 and −2⁶³, empty 0, one element, 17 elements |
| `red_mean_var` | §10.5: `mean`, `variance` (two-pass, N − 1), `std` of `f64` and `i64` vectors; a case where the one-pass formula fails (1e8 + 1, + 2, + 3: variance exactly 1); empty NaN; one element 0 (also `variance([nan])`); an `i64` mean near 2⁶³ |
| `red_sizes` | §10.5: every vector reduction on 0, 1, 7, 8, 9, 17 elements: `f64` (lane-sensitive data) and `i64` `sum mean variance std max min argmax argmin`, `bool` `nnz any all` |
| `red_maxmin` | §10.5: `max min argmax argmin`: ties (first index), NaN first, middle, last and everywhere (NaN, index 0), −0/+0 in both orders (signs printed), infinities, `i64` at the limits, a dynamic 9-element operand; the two-argument `max`/`min` stay elemental (§10.4) |
| `red_bool` | §10.5: `nnz any all` of empty (0, false, true), all-true, all-false, mixed and comparison operands |
| `red_dim` | §10.5, Decision 39: `dim: 0` and `dim: 1` for the nine functions on 3 × 4 matrices (`f64` fixed and dynamic, `i64`, `bool`), a row of 4 and a column of 9 where the lane order matters, fixed-size results (`f64[4]`, `f64[3]`, `mean` of `i64` as `f64[4]`), NaN columns, a `.T` operand, the extents 0 × 3 and 3 × 0 (three +0 / NaN / 0 / false / true, or empty results) |
| `red_former_ns` | §10.5 (DESIGN.md §6.2 "4f"): the calls of the retired goldens `err_ns_lib_sum`, `err_ns_lib_max1`, `err_ns_lib_max1_fixed`, `err_ns_lib_min1`, which compile from 4f |
| `sort_f64` | §10.6: `sort`/`argsort` of `f64` ascending and descending: −0/+0 interleaved (input order kept, signs printed), ties (descending is not a reversed ascending order), `nan`, `-nan` and a run-time 0/0 (after every number ascending, before every number descending, in input order), ±Inf, a fixed-size operand, empty, one element |
| `sort_i64` | §10.6: `sort`/`argsort` of `i64`: −2⁶³ and 2⁶³ − 1, ties in both directions, empty, one element |
| `sort_misc` | §10.6, Decision 39: a fixed-size operand gives a dynamic result (reassigned with another length), `desc:` as run-time `bool` expressions, `f64` (with −0) and `i64` vectors of 31, 32 and 33 elements with many ties (both sides of the insertion-sort limit, DESIGN.md §4.8) |
| `sort_lcg` | §10.6; DESIGN.md §4.8: 1000-element vectors from an LCG (many ties and −0; wide `f64` and `i64` values for the radix path), checksums of every permutation and sorted vector in both directions and the first and last values, from the stable model |
| `find_basic` | §10.6, Decision 39: `find`, `find_first`, `find_last` with none true (−1), all true, mixed, empty, a comparison with NaN, `find(M.flat)` (column-major: `0 3 4 5`); `find` of a fixed vector is dynamic |
| `heap_red_temps` | DESIGN.md §3.6.6 rules 15, 23, 24: reductions, `sort`, `argsort` and `find` of owned operands (element-wise results, selections, masks, `.flat`, `.T`, call results, a fixed operand of `argsort`), in a loop and discarded; heap check 0 |
| `heap_red_store` | rule 21: `v[argsort(w, desc: true)] = 0.0` (an owned index vector released at the end of its block), a selection of it, in a loop, `f[find(…)]` on a fixed target, a compound store with copy on write of a shared target; heap check 0 |
| `w4_sor_reduce` | DESIGN.md §6.2 (4f); LANGUAGE.md §10.5: `programs/w4_sor_arrays.sea` with the hot-spot loop replaced by `var Thot = T`, `Thot[fixed] = -inf`, `let Tmax = max(Thot.flat)`; prints the bytes of `w4_sor_arrays.out` |
| `str_basic` | §4.4, §6.4, §7.2, §8.2–§8.4, §11.1 (4g-1): `str` locals, borrowed parameters, owned results, a `ref` parameter, tuple components (bound and assigned); `+`, `+=`; the six comparisons on 11 pairs (a proper prefix the smaller, bytes 0x80 and 0xFF above ASCII, empty strings, `"a" != "a "`, an embedded NUL); `len` in bytes (`\u{E9}` is 2); an `if` expression and a `while` on strings; shadowing in a block; `%s` of dynamic strings with width, precision, `-`, `%.0s`; `str` constants (`+`, one naming another, annotated, the `bool` constants of comparisons; L-f, L-g) |
| `str_conv` | §10.9, Decision 46: `str` of `i64` (0, −2⁶³, 2⁶³ − 1, a local), of `f64` (`%.17g`: `0.10000000000000001`, `-0`, `100`, `1.0000000000000001e+300`, `4.9406564584124654e-324`; `nan` of both signs, `inf`, `-inf`, also computed at run time), of `bool` and of a `str` (unchanged); `lower` (only A–Z; `@ [ \``, bytes ≥ 0x80 kept; the empty string; the operand unchanged) |
| `str_arrays` | §4.5, §4.8, §5.2, §5.5, §5.6, §6.9, §7.3, §7.5, §10.2: `str[]` and `str[,]` literals, element reads, replacing stores (`=`, `+=`, L17), copy on write of a shared `str[]` (the original unchanged), selections read (range, index vector, mask) and stored (a scalar, an array, a mask), concatenation with scalars, vectors and a selection, `filled` (vector, matrix, length 0), `.T`, `.flat`, `.col`, `.row`, element loops over a `str[]` and a `.flat` (the vector evaluated once), `[]` under a `str[]` annotation, `(v[1], kk) = two()` (L12, R25) |
| `str_ew` | §6.2–§6.4, Decision 45: the six comparisons and `+` of a `str[]` with a `str` (either side) and with another `str[]`, bytes ≥ 0x80, a `str[,]` broadcast against a `.col` and a `.row` (and the two against each other), `+=` of a `str[]` local with a `str` and a `str[]` (rule 15 (i)), empty operands |
| `sort_str` | §10.6, Decision 40: `sort`/`argsort` of a dynamic `str` vector of 11 elements ascending and descending (byte-wise: empty strings first, upper case before lower, a proper prefix first, 0x7F and 0x80 last), ties in input order in both directions, `desc:` as a run-time `bool`, one element, an empty vector, owned operands (an element-wise result, a call result); the operand unchanged |
| `match_basic` (`.args`) | §7.6: several patterns per arm, arms separated by `,`, an empty arm body, an escape in a pattern, `"a"` and `"a "` as distinct patterns, a `match` with only `_`, scrutinee a local, a `ref` parameter (assigned in its own match), a call's result (owned), an element, `args()[0]`; `break`, `continue` and `return` inside arms with an owned scrutinee (R22: heap check 0); nested matches |
| `args_basic`, `args_one`, `args_none` (`.args`) | §10.10: `len(args())`, `for s in args()`, indexing; six arguments including an empty one and ones with inner, leading and trailing blanks; one argument; none (no `.args`: the empty `str[]`) |
| `heap_str_args` (`.args`) | DESIGN.md §3.6.6 rules 15 (f), 33, 35: `printf("%s\n", args()[0])`, `let s = args()[0]`, `match args()[1]`, `match lower(args()[k])` and `args()[k] + str(i)` in loops; heap check 0 |
| `heap_str_misc` | rules 15, 31, L12, R25: calls returning a `str` (and a tuple with a `str`) as statements, `let _ = mk(5)`, a `_` component of a `str` result, `filled` of an owned `str`, `(v[i], x) = two()` with `str` results (also in a loop), `f(v[0], g(ref v))` (the element evaluated before `g` replaces it: `p! g`), `str` locals on `break` and `continue`; heap check 0 |
| `heap_str_temps` | rules 15, 16, 32: owned concatenations, `str()` and `lower` in loops and conditions, `str` locals on `return`, element-wise `str` results discarded, element stores of owned values into a shared vector, `sort` of an owned operand; heap check 0 |
| `heap_str_views` | LANGUAGE.md §4.5, §5.5, §5.6, §6.8 rule 5, §7.3, §8.3 (the use-after-free probes of the 4g-1 review): elements of views of owned temporaries (`(v + "3").col[1, 0]`, `(M + "1").T[0, 1]`, `(M + "2").flat[3]`, a `match` scrutinee, a comparison) used after other strings are made; compound stores `w[0] += g(ref w)`, `N[1, 0] += gm(ref N)`, `N.flat[2] += gm(ref N)` (the element read before `e`, the store into the root `g`/`gm` left: `aag`, `cgm`, `bbgm`); `.col`, `.row`, `.T`, `.flat`, `.T.T` element reads passed before a call that replaces the root by `ref` (the old element printed), also through a `ref` parameter root; `g`/`gm` reassign the root and then allocate and print new strings; heap check 0 |
| `struct_basic` | §4.6, §5.5, §6.8 rule 5, §6.10, §7.3, §8.2–§8.4; DESIGN.md §3.5.5, L-h (4g-2): every field kind (`f64`, `i64`, `bool`, `str`, `f64[]`, `f64[3]`, `str[]`, a nested struct); a literal in another order than the declaration whose values print their trace in source order (`f2 f1 b f3 i7 f0.5 p`, as `ev.sea`); field reads; a `var` copy written field by field (scalar, `+=`, `bool`, `str` `+=` and `=`, `q.v[i] = x`, `q.v[0..2] = 0.0` (an L6 field root), fixed field element `=` and `+=`, a `str[]` field element, a nested field, a whole struct field from a literal reading the old field); the original unchanged; struct parameters and results, two struct results, a parameter copied into a `var`; `ref` struct parameters (field stores, a whole struct); an `if` expression of a struct and its copy written; an empty struct `E {}`, an `E[]` of 3, `filled`, an element loop, an element store, a concatenation |
| `struct_arrays` | §4.5, §4.7, §5.2, §5.5, §6.9, §7.5, §8.3, §10.2 (4g-2): Appendix D's literal style (aligned, trailing comma, an untyped `4` into an `f64` field, `[]` into an `f64[]` field), `dims[k].f` read (`sign * nom` converted), `dims[k].f = x`, `dims[0].v[1] = 7.0` while a copy shares the array (rule 19's cow chain: the copy unchanged), `dims[2] = p`, projections (`f64`, `str`, `i64`; of a range and an index-vector selection; of a fixed `Dim[3]`), `Dim[3]` parameters (also `ref`) and a `Dim[2]` result, `filled` with a struct literal, element loops, `dims[0..2]` as a value, `scale(ref dims[1].nom, 2.0)`, `app(ref dims[0].name, …)`, `app(ref s.name, …)` |
| `struct_cow_levels` | §4.5; DESIGN.md §6.2 (4g-2 dumps, L17, R23): two array-field levels, `a[0].w[0].v[0] = 9.0` while `b` shares `a`: prints `1 9` |
| `struct_field_lim` | DESIGN.md §3.5.9 R19's example `dims[i].lim = Lim { lo: 0.0, hi: 1.0 }` in a loop (a struct literal into a struct field of an element), then `dims[1].lim.hi = 6.5`; the shared copy unchanged |
| `struct_dollar_paths` | §4.5, §5.3, §5.5, §7.3, §8.3 (4g-2): `$` in indices under fields of array elements in assignment targets (`=`, `+=`, `*=`), `$` the extent of the array its index indexes: a dynamic container (`a[i].v[$ - 1]`, `a[0].v[0..$]`, `a[i].names[$ - 1] += "!"`) with a copy unchanged; fixed `f64[3]` and `i64[2,2]` fields (`m[$ - 1, $ - 2]`: rows, then columns); a `ref` root (`ds[i].v[$ - 1] += 0.5`, `ds[$ - 1].v[0..$ - 1] = -1.0`); nested `s.items[$ - 1].v[$ - 1]`, `q[1].items[$ - 1].v[$ - 3]` and `q[0].items[$ - 2].v[$ - 1] +=` through two element containers, with copies unchanged |
| `str_fixed` | §4.5, §6.2–§6.4, §10.6, Decisions 39, 45 (4g-2): `str[3]` by annotation from a `str[]` (fix, its check passing), a `var str[3]` from a literal, element stores (`=`, `+=`), a `ref str[3]` parameter, dyn into `str[]`, an element loop, `sort`/`argsort` of a `str[3]` (a dynamic result, reassigned longer), `+` with a `str` either side, `== "a"`, `<` of two `str[3]`, `str[3]` parameters, results (fix of a returned literal) and tuple components, value semantics, a `str[3]` struct field, a `str[2,2]` with `.T` and `.flat` |
| `records` | §4.6 "Anonymous records", §4.7, §6.9, §6.10, §7.5, §10.2, Decision 48 (4g-2): bound and read, a `var` record's fields assigned (`=`, `+=`) and the whole record replaced, a nested record written through a copy, an array literal of records, `filled`, `if` arms, projections (also of a selection), an element loop, element field and whole element stores into a `var` record array (the original unchanged), an array field written through a copy |
| `heap_struct_temps` | DESIGN.md §3.6.6 rules 15 (f), (g), (j), 16, 19, 27 (4g-2): a `slit` argument, call results used once (an argument, `mk(…).k`, `f().name`, `f().v[3]`), `if` expressions of structs (owned arms, in a loop; a function returning one), a `_` component, discarded struct results, `filled` of an owned struct, a struct local replaced in a loop with `break` and `continue`, projections of literals of owned values; heap check 0 |
| `heap_struct_paths` | LANGUAGE.md §4.5, §6.8 rule 5, §7.3, §8.3; rules 15, 16, 19, 31, L12, R25 (4g-2): `(v[i], s.name) = two()` with owned `str` results (also in a loop), `f(s.name, g(ref s))` and `fv(s.v[0], g(ref s))` (the field read before `g` replaces it: `R g`, `9 g`), nested field paths written while shared, `f(q.p.name, g(ref q.p))`, elements of a struct array replaced in a loop, a record holding a struct array; heap check 0 |
| `heap_struct_ref_elem` | LANGUAGE.md §4.5, §8.3; DESIGN.md §3.6.6 rule 31 (4g-2 review): `ref` arguments that are elements of array fields: `upd(ref sf.v[1])` (`f64[2]` field), `upd(ref sd.v[1])` (`f64[]` field), `upd(ref arr[0].v[1])`, `rp(ref q.fp[1])` (an `E2[2]` field), `rp(ref q.ps[0])`, `rs(ref q.ps[i].s)`, `rs(ref qs[i].fp[0].s)`, every copy taken before unchanged; the deferred `rs2(ref arr[0].name, ga(ref arr))`: the index at its place, the element of the array `ga` left (`Ngj2`); heap check 0 |
| `heap_struct_rule12_elem` | LANGUAGE.md §5.5, §6.8 rule 5, §7.3, §8.2, §8.3; DESIGN.md §3.6.6 rule 12 (4g-2 review): reads through an element of a struct array before a call that replaces the root by `ref` and then allocates: `fs(a[0].name, gsa(ref a))`, `fs(a[0].name, gs(ref a[0]))`, `fs(a[0].q.t, gs(ref a[0]))`, `fp(a[1], gs(ref a[1]))`, `fsa(a[0].fs, gs(ref a[0]))`, `fq(a[0].q, g(ref a))` all see the old values; `a[1].name += gs(ref a[1])` (the old name read first, stored into the element `gs` left: `bgskk tW W0`); `a[0].name + gsa(ref a)` (`agaj1`); heap check 0 |
| `struct_tuple_targets` | LANGUAGE.md §4.5, §7.3, §8.4 (4g-2 review): tuple assignments to `(q.n, q.m)`, `(q.n, x)`, `(x, q.n)`, `(q.fx[0], x)` (a fixed field element), `(q.v[0], x)`, `(qa[0].n, x)`, `(q.n, q.fp) = r6()` (a `P[2]` field from a returned literal); three components with later targets `(_, _, sv[0])`, `(_, _, ps[0])`, `(_, _, ps[1].tag)`, `(_, _, vs[0].v)`, `(xi, y, ps[1])`, `(q.ps[0].tag, q.ps[0].v, q.ps[1]) = three()`; copies unchanged |
| `struct_str_field_cat` | LANGUAGE.md §4.5, §6.2, §6.3, Decision 45; DESIGN.md §2.6.2 "Readings fixed by 4g" (`x += e` of a `str` field) (4g-2 review): element-wise `+=` of `str` array fields: `p.fs += "z"` (`str[2]`), `p.ds += "z"` (`str[]`), `p.fs += m` (a `str[2]` local), `p.ds += "R"` in `fn rr(ref p: P)`, `a[1].ds += a[0].ds`, `a[0].fs += "z"`, `s.m += "y"` (`str[2,2]`); copies unchanged |
| `prel_linspace` | §10.3, §4.2 (4h): n = 0 and n < 0 empty, n = 1 `[d2]`, the symmetric branch with n1 even (`(-1.0, 1.0, 5)`) and odd (`(-1.0, 1.0, 4)`), `(0.0, 0.0, 4)` printing `0 -0 0 0`, `(-0.0, -0.0, 3)` printing `-0 0 -0`, `(-1.0, 1.0, 2)` by the general case, `d1 == d2` (also `inf`: no NaN), `(0.0, 1.0, 11)`, decreasing, `(-inf, inf, 3)` printing `-Inf 0 Inf`, W5's `(0.4, 1.6, 25)`, untyped and `i64` arguments converted; `%.17g` |
| `prel_bincount` | §10.7, §4.5 (4h): repeats, an empty `idx` written `[]`, n = 0, a fixed-size `i64[3]` argument converted, an owned argument (`setdiff(…)`), the result modified afterwards, W5's `i64(floor(v))`, 1000 values |
| `prel_setdiff` | §10.6 (4h): duplicates, negatives, unsorted input, an empty a, an empty b written `[]`, a range argument (`setdiff((0..6), [0, 5])` is `1 2 3 4`; the range written in its value form `"(" range ")"`, Appendix A), everything removed, i64 extremes, `setdiff(a, a)` |
| `prel_meshgrid` | §10.3, §4.2, §7.3, §8.4 (4h, Decision 54): `-0.0` and `nan` in x copied, an `i64[]` y converted (dynamic, fixed `[1, 2]`, and 2⁵³ + 1 rounding to 2⁵³), empty x and empty y, `(A, B) = meshgrid(…)` into existing `var`s of another shape, `return meshgrid(x, y)` from a user function, `_` components |
| `prel_ctx` | §6.4, §6.8 rule 5, §6.10, §7.3–§7.6; DESIGN.md §3.6.6 rule 12, §3.5.9 R30 (4h): a prelude call as an `eval` statement, an index base, a `for` vector, in `if`-expression arms (the unselected arm's `f()` never runs), in a `while` condition re-run each iteration, two in one expression, inside a user function, in a loop left by `break`, the argument order `linspace(f(), g(), h())` printing `f g h`, `setdiff(v, grow(ref v))` removing from the old v (`2: 1 3`, then v is `1 2 3 9`), short-circuit operands, a `match` scrutinee and arm, nested calls, `if` arms, a tuple assignment |
| `heap_prel_args` | DESIGN.md §3.5.9 R26, R27; §3.6.6 rules 15, 37 (4h): owned argument temporaries (nested `setdiff`, `i64(v * 2.0)`, two `linspace` arguments of `meshgrid`), an `eval` of each function, `_` components (`let (_, Y2)`, `let (_, _)`, `(_, B) =`), a result replaced in a loop; heap check 0 |
| `heap_prel_exits` | DESIGN.md §3.5.9 R29, rule 16 (4h): `linspace`'s early returns for n < 1 and n = 1 in a loop, prelude calls in loops left by `break` and `continue`, a `return` from inside a loop after a call; heap check 0 |
| `opt_div_const` | §6.6 (5c-1, DESIGN.md §5.8 T2): floored `%` and `idiv` by the constants 1, 2, 3, 6, 7, 10, 11, 2147483647, 2⁶², 2⁶² + 1 and by −1, −2, −7, −10, −2147483647, −2⁶² (negative divisors left unchanged by T2) on −2⁶³, −2⁶³ + 1, −1, 0, 1, 2⁶³ − 1 and multiples of the divisor ± 1; a `const` and a `let` divisor; `-2⁶³ % -1` = 0, `% 1` and `idiv(x, 1)` of the extremes; sweeps over −13 ..= 13 for 2, 3, 4, 6, 7, 8, −3, −4, −6 |
| `opt_fdiv_const` | §6.5, §6.8 rule 2, §10.9, §11.1 (5c-1, T2): `f64` division by 4.0, 0.5, −2.0, 2¹⁰²³, 2⁻¹⁰²², 3.0, 0.25, an untyped 4, −2¹⁰²³ and a `const` 0.5 of values giving normal, subnormal, overflowing and signed-zero results, ±Inf and NaN; `i64 / 4` (2⁵³ + 1, ±2⁶³ converted first); each printed with `%.17g` and `str()` |
| `opt_ifconv` | §6.4, §6.10, §7.4 (5c-1, T4): one assignment per arm and `if` expressions of `i64`, `f64`, `str` and `bool`, with NaN, −0.0 and Inf conditions, `!(f < 1.0)` against the plain test, a variable selected against its own old value |
| `opt_nan_cmp` | §6.4, §4.2 (5c-1): `== != < <= > >=` with NaN on the left, the right and both, −0.0 against 0.0, equal values: in an `if`, as a selected value, as a `bool`, as a `while` condition and as a `break` test (only `!=` holds with NaN); `!(a < b)` against `a >= b`; `i64` against `f64` |
| `opt_live_calls` | §6.5, §6.8, §8.1 (5c-1): eight `i64` and eight `f64` values computed before a loop and read after `printf` and a real call (a function with a loop and two call sites) inside it; three values of a function live across calls in its loop |
| `opt_ref_scalar` | §8.3, §7.5 (5c-1/5c-2, T5): a `ref` scalar updated in a loop and read by the caller: a `for`, `continue` of an inner `while` and of the outer `for`, a `return` inside the loop taken and not, a `break` (`f64`), passed on by `ref` inside the loop, a `return` from a nested loop, calls inside the caller's loops with `continue` |
| `opt_ref_elem` | §8.3, §4.5 (5c-1/5c-2): `f(ref v[3], v2)` with `v2` sharing `v`'s buffer, updating the element in a loop while reading `v2`; one `ref iv[i]` call per element against the shared copy; a matrix element; both arrays printed afterwards |
| `opt_cow_loops` | §4.5, §8.2, §8.3 (5c-1/5c-2, T6): a loop storing into an array another variable shares, a loop whose stores are all skipped, a `ref` array parameter updated in a loop while the caller keeps a copy, a loop storing into an array it passes to functions (one returns it and the result is kept), a copy made before a loop passed to a function inside it, a matrix row |
| `opt_dead_checks` | §5.4, §6.5, §6.6 (5c-1, T1, T8, T9): an index out of bounds, a division by zero and an overflow in `if` arms that never run, one condition false at every iteration and one loop-invariant and false, in `for` and `while` loops: no error |
| `opt_index_pm1` | §5.1, §5.4, §6.5, §7.5 (5c-1, T1): `j - 1` and `j + 1` over `1..n-1` and `1..=n-2`, steps −1, 2, −2 and 3, a function called with n = 6, 1 and 0 (an empty array), ranges ending at 2⁶³ − 1 and starting at −2⁶³ whose bodies stay in range |
| `opt_while_zero` | §7.4, §7.5, §5.1 (5c-1/5c-2, T8): loops run zero times assigning a loop-invariant value to a variable printed after them (the old value printed): `while` in functions and in the main program, an empty `for`, a `while` whose body reads an element of an empty array, empty and wrong-direction ranges |
| `opt_facts` | §5.4, §6.4 (5c-1, DESIGN.md §5.8 F5, F6): indices proved by dominating guards on parameters (nested `if`s, `else if`, early returns, `&&`, `||` with `continue`) followed by code their facts do not cover, indices on both sides of every bound |
| `opt_vn` | §4.5, §8.3 (5c-1, T3): a variable reassigned between two equal expressions, equal operands in one call, a load after a store to its element, a store into a shared array read through the other name, a `ref` array parameter and a value parameter sharing one buffer, two `ref` scalars, a struct field stored, passed by `ref` and reread, element loads and stores in a loop |
| `opt_fields` | §6.5, §4.5, §4.6, §8.2 (5c-1, T1; regression for a `seaopt` defect that dropped the check): `+ 1`, `- 1`, unary `-`, `* 2` and `+ i` in a loop on the `i64` field of a struct parameter and on an element of a fixed-size `i64[3]` parameter, in functions called for real and inlined, with results at the ends of the i64 range but inside it |
| `opt_eq_guards` | §5.4, §6.4, §6.5 (5c-1, DESIGN.md §5.8 F5; regression for the negated `==`/`!=` facts): the parts where an `==` or `!=` guard fails used for reads and adds that stay in range: an early return after `x == 0`, `k == 2` after `k < 0` on fixed and dynamic arrays, an explicit `else`, `!(k == 2)`, `k == 2 \|\| k < 0`, a `!=` whose `else` subtracts, a function with a loop and several call sites, `while true` loops left by `break` on `==` and loops continued after `!=` |
| `opt_promote_exits` | §8.3, §7.5, §4.5, §4.6 (5c-2, DESIGN.md §5.8 T5): `ref` scalars, `ref` struct fields and fixed-size array elements updated in loops: a `return` inside the loop taken and not, a `ref` element of a struct array (`filled` copies untouched), a `return` from an inner `while` and `continue` of the outer loop, a `ref i64[3]` updated at a constant and a variable index that meet, a local fixed-size array, the value passed to a call inside the loop, a `while` left at once by a NaN bound, a `ref` doubled after a nested loop with `break`, two `ref` parameters |
| `opt_cow_alias` | §4.5, §4.6, §8.2, §8.3 (5c-2, T6): a `var` copy of a parameter stored in a loop (the caller keeps its values), a parameter shadowed by `var`, a `ref` array and a value parameter sharing one buffer, a copy retained inside the loop at every iteration and at one, the array stored into a struct field inside the loop, returned inside the loop, loops run zero times, two arrays stored in one loop with either or neither shared, a `ref` array shared only at its second call, an array field shared by `filled()` elements, a `ref` struct's array field (memory form), a matrix stored column by column |
| `opt_hoist_guard` | §5.4, §6.5, §6.6, §7.4, §7.5 (5c-2, T8, L-at): loop-invariant failing operations that must not run: an index 10⁹, an overflow, a zero divisor and `i64(2.5)` in loops run zero times (`for`, `while`, an element loop over an empty slice), after a `break` taken at once, after a `continue` taken at every iteration, after a `return`; struct fields read through a parameter in loops run zero times with a count field the array does not cover; a `ref` struct whose fields change in the loop; an element read under an invariant guard on an empty array |
| `opt_unswitch_nan` | §6.4, §6.10, §4.5 (5c-2, T9, L-bm): two `bool` conditions (one negated) and a third invariant comparison in one loop with NaN, signed-zero and infinite operands; an `if` expression on an invariant `==`; an invariant `lim <= lim` (false for NaN) around a nested `if`; a stencil whose column tests `i == 0` and `i == nx - 1` guard index arms that would fail if evaluated (one column: both hold); empty matrices |
| `opt_sr_extents` | §4.5, §5.1, §5.4 (5c-2, T7): a matrix row (column stride `rows(A)`) and column (unit stride), `2j + 1`, `n - 1 - j`, `j + t` and `j - t` with an invariant t (0 and the whole length included), a range counting down by 3 to 0, an invariant register stride `j * k + c` in a `while` and a `for`, a transpose stored column by column, the diagonal, stores at `3j + 2`, `3j` and `j + 1` with step 2 reaching the last element, 1 × n, n × 1 and empty matrices |
| `opt_live_ifs` | §6.5, §7.4, §7.5 (5c-2, DESIGN.md §4.9.2, Decision 75): twelve `i64` and two `f64` variables carried around a loop with a `printf` in some iterations, temporaries local to each `if` part, a value written in both parts and read after them, values computed before the loop and read after it; a value carried around a `while` inside one part only (NaN takes the `else` part); an inner `while` in a `for` whose invariant values are printed every outer iteration |
| `opt_ifexpr_loops` | §6.4, §6.10, §7.4 (5c-2, T4, L-bq, L-bn): a running maximum from `-inf` over NaN elements, a variable declared in the body and assigned in an `if`, a variable written only in an `if` and read after a loop run zero times, `if` expressions whose unselected arm would fail an index check, an `else if` chain in a `while`, `f64` selections on NaN and infinities |
| `opt_dead_label` | §7.2, §7.7 (5c-2 regression, DESIGN.md §5.8 T10): unused `str` bindings at the end of a loop body, an `if` part, a block and the main program (the shape of `passes/lex_string` and `lex_column`), built with the prelude: `seaopt` deletes their retain/release pairs and loads, leaving `str` labels nothing references in `sea.lir2`, which `sealopt` once rejected with `internal error: bad record`; prints `14 0` and `done` |
| `opt_destrew_ref_i64` | §6.8, §7.1, §8.3 (T5 destination rewriting): `s = t*3; s = s+1; u = t*3` on a `ref` `i64` in a loop; the recomputed `u` is 15 although the promoted `s` was stored 16 in between; prints `16 15` |
| `opt_destrew_ref_later_store` | §6.8, §7.1, §8.3 (T5): `s = a+b; let t = s; s = 0; w += t` on a `ref` `i64`; `t` is 7 each of 5 iterations, `s` ends 0; prints `35 0` |
| `opt_destrew_ref_field_f64` | §6.8, §7.1, §8.3 (T5): `st.x = v[i]*2.0; st.x = st.x + 1.0; out += v[i]*2.0` on an `f64` field of a `ref` struct over 1, 2, 3; `out` is 12 and `st.x` ends 7; prints `12 7` |
| `opt_destrew_intervening_use` | §6.8, §7.1, §8.3 (T5): as `opt_destrew_ref_i64` with both `s` (16) and the recomputed `u` (15) added to an accumulator between the stores, 3 iterations; prints `93 16` |
| `opt_destrew_ref_f64` | §6.4, §6.8, §8.3 (T5): the `f64` form of `opt_destrew_ref_i64` with `t = 2.5`; prints `8.5 7.5` |
| `opt_destrew_ref_field_i64` | §6.8, §7.1, §8.3 (T5): `p.n = a+b; p.n = p.n*2; w += a+b` on an `i64` field of a `ref` struct, 4 iterations; prints `28 14` |
| `opt_many_stores` | §4.5, §5.5, §7.3 (sealopt scratch tables): 1700 stores `a[k] = a[k] + f64(i+k)` in one loop body over a dynamic array whose buffer `keep` shares, 3 iterations; every `a[k]` is 3 + 3k exactly, `keep` stays zero; prints the folded checksum `%.17g` (compiles in about 55 s: the compile time grows with the store count) |
| `manualD_part1` (`.args`) | LANGUAGE.md Appendix D (DESIGN.md §6.2, §8 row 4g-2): the first part of the W5 port (struct array, options `match` with `--figures`, validation `match`, the analytic limits) and nine print lines: 12 lines, every `%.17g` value from the exact binary result |
| `lib_now` | §13 (difference ≥ 0; the value is never printed) |
| `lib_consts` | §10.1, §7.2; DESIGN.md §3.5.5 (bits of `pi inf nan eps`) |
| `lib_math_log`, `lib_math_exp`, `lib_math_sin`, `lib_math_cos`, `lib_math_hypot` | §10.4, §4.2 (ordinary, i64 and untyped arguments, ±0, ±Inf, NaN, subnormals, overflow/underflow, huge sin/cos arguments); DESIGN.md §4.10 |
| `lib_math_pow` | §10.4, §6.5 (`pow` calls with the C99 Annex F special cases; `^` with a non-integral exponent, with \|k\| > 4, with an i64 or untyped base, and with an exponent containing a call) |
| `lib_math_const` | §7.2, §6.5; DESIGN.md §4.10.5 (`2.0 ^ 0.5`, `pow(10, -2)`, `2 ^ (3.0 / 2.0)` folded by FEPOW with the run time's bits; the powk `3.0 ^ 2`) |
| `lib_math_powk_vs_pow` | §6.5 (`x ^ 3`, `x ^ -2` are the pinned multiplications; `x ^ f64(k)`, whose exponent holds a call, and `pow(x, k)` are `pow`), for x = 1.3, 2.3, 1.2 where the bits differ (asserted by the generator); DESIGN.md §4.10.6 |
| `lib_math_const_powk` | §6.5, §7.2; DESIGN.md §3.5.5 "Constant exponents" (`const K = pow(9.0, 0.5)` = 3 and `const N = -pow(4.0, 0.5)` = −2 make `x ^ K`, `y ^ N` powks, printed next to `pow(x, K)`, `pow(y, N)` whose bits differ; k = 2 cannot discriminate, one rounding of x·x is the correctly rounded square) |
| `fmt_d_ext` | §11.1 (`%d` of bool, of −0.0, C precision on an integral f64) |
| `fmt_prec_zeros` | §11.1 (precision digits with leading zeros) |
| `fold_inf_chain` | DESIGN.md §2.8 U1 (16 constants squared: overflow folds, Inf) |
| `fold_a13_chain` | DESIGN.md §2.8 (13 doubling constants used 7 times fold to literals) |
| `fold_nonfinite` | DESIGN.md §2.8 U1, §11.1 (folded ±Inf, NaN, −0, underflow, a subnormal tie) |
| `stmt_else_if_2000` | DESIGN.md §2.7 (2000 else-if links add no nesting) |
| `const_reverse_1000` | §7.2 (1000 constants declared in reverse order) |
| `stmt_tasg_cvt` | §4.2 (b), §7.3 (tuple assignment converts i64 to an f64 target) |
| `lib_conv_identity` | §10.1 (`f64()` of f64, `i64()` of i64, untyped argument is i64) |
| `stmt_for_blanks` | §7.5 (two blanks after `for`) |
| `const_mod_chain` | §7.2 U2, §6.6 (18 constants, floored `%`, each evaluated once: 810) |
| `const_bool_chain` | §7.2 U2 (an 18-constant `&&` chain of bool constants) |
| `const_mixed` | §7.2, §4.2 (i64 constants converted inside f64 constants) |
| `const_mod_min` | §6.6, §7.2 (`-2^63 % -1` is 0 in a constant) |
| `const_shortcircuit` | §7.2 (`&&`/`||` in a constant skip the right operand) |
| `const_cvt_ties` | §4.2, §7.2 (i64 → f64 constants round ties to even; `%.17g`) |
| `const_cmp_ieee` | §7.2 (`-0.0 == 0.0`, NaN comparisons in constants) |
| `op_mod_idiv_edges` | §6.6 (floored `%` and `idiv`, every sign combination, −2⁶³ and 2⁶³−1 operands; run time on both targets) |
| `op_ftoi_edges` | §10.1, §4.2 (`i64()` of −2⁶³, 2⁶³−1024, −0.0, 2⁵³+2, −2⁶²) |
| `op_itof_round` | §4.2, §10.1 (`f64()` of i64 rounds ties to even; `%.17g`) |
| `op_cmp_nan_zero` | §6.5 (six comparisons with NaN on either side, ±0 equality) |
| `op_neg_zero` | §6.5 (unary `-` of ±0, IEEE zero signs at run time) |
| `fmt_d`, `fmt_d_f64`, `fmt_f`, `fmt_e`, `fmt_g`, `fmt_s`, `fmt_pct`, `fmt_nonfinite` | §11.1 |
| `lex_crlf` | §3.1 (CR before LF and at end of file removed) |
| `lex_long_line` | §3.1; DESIGN.md §2.2 step 2 (4096 bytes allowed, also followed by CR) |
| `err_flush` (`.out .err .status`) | §9.2 (stdout flushed without an extra newline, then the error) |
| `fmod_scalar` | §6.6, §6.5, §11.1; DESIGN.md §4.8 (`FMOD`, L-cm; 6b): `f64 %` at run time (operands read from arrays so nothing is folded) over the special cases: ±0 divisors (the result is a), ±∞ and NaN operands (NaN), `-6.0 % 3.0` is −0.0 and `6.0 % -3.0` is +0.0, `-1 % inf` is `inf` and `1 % inf` is 1, subnormals, quotients up to 2¹⁰²³ and DBL_MAX, one rounding of r + b (`-1e-20 % 1.0` is 1.0); `%.17g` |
| `fmod_str` | §6.6, §10.9 (6b): the pairs of `fmod_scalar` printed with `str()`: `-0`, `nan`, `inf`, `-inf` |
| `fmod_random` | §6.6 (6b): 120 pseudo-random pairs (`random.Random(61)`, both signs, exponents −1000 … 1000, divisor near and far) |
| `fmod_array` | §6.2, §6.3, §6.5, §6.6, §4.2; DESIGN.md §2.11.4 L7 (6b): element-wise `f64 %`: vector with vector, with a scalar either way, with an untyped integer literal and an `i64` variable, an `i64[]` with an `f64` scalar, matrix with matrix and with a scalar, `.row` and `.col` broadcasting, `2×1 % 1×3`, empty arrays (no element computed), a fixed-size array, inside a larger expression |
| `call6_named_order` | §8.1, §6.8 (6b): named arguments in all six orders and mixed with positional ones, argument expressions that print: evaluated in source order, bound by name (every result 123); named arguments inside named arguments |
| `call6_named_types` | §8.1, §4.2 (6b): named arguments of `f64`, `bool`, `str`, `i64`, array and struct parameters out of order; an untyped literal and an `i64` value for an `f64` parameter |
| `call6_defaults` | §8.1, §7.2 (6b): defaults of each scalar type and of `str`: constant names, `pi`, `2.0 * pi + 1.0` (`%.17g`), `K * 2 + 1`, `"x" + "y"`, `-0.5`, an untyped `2` for `f64`; omitted, positional and named arguments mixed |
| `call6_defaults_named` | §8.1 (6b): a parameter skipped by name keeps its default, the others in any order, expressions evaluated in source order |
| `call6_default_ref` | §8.1, §8.3 (6b): a `ref` parameter followed by parameters with defaults, given by name |
| `call6_defaults_const_late` | §8.1, §7.2 (6b): defaults naming constants declared after the function, a constant defined by another constant, an operator expression |
| `call6_default_recursive` | §8.1, §8.6 (6b): a recursive function with defaults calling itself with named arguments (stays a call) |
| `call6_prel_named` | §10.3, §8.1 (6b; moved from `errors/err_prel_named`): `linspace(0.0, 1.0, n: 3)` gives 0, 0.5, 1 |
| `call6_prel_named_order` | §10.3, §10.6, §10.7, §8.1 (6b): named arguments of `linspace` (all orders, evaluation order `tf(1) t(2) tf(3)`), `meshgrid(y:, x:)`, `bincount(n:, idx:)`, `setdiff(b:, a:)` with the names swapped and not |
| `inl_single_loop` | §8.6 (b), §7.5 (6b): functions with a loop called from one site: a `for`, a `while` with an early return, a return from inside a loop, `break` and `continue` |
| `inl_many_calls` | §8.6 (c) (6b): small functions called from many sites, in a loop of 1000 and outside, one calling another |
| `inl_nested` | §8.6 (c); DESIGN.md §2.11.4 L20 (6b): f1 calls f0 twice, f2 f1 twice, f3 f2 twice (8 copies of f0), a chain a → b → c, calls nested in arguments |
| `inl_recursive_stays` | §8.6 (6b): `fact`, `is_even`/`is_odd` and `depth` (20 000 deep) are recursive, so calls |
| `inl_mutual_single` | §8.6 (b) (6b): a mutual pair where `b` has one call site (inlined into `a`, the recursion going through the inlined body) and `a` has several |
| `inl_ref_scalar` | §8.3, §6.8; DESIGN.md §3.6.6 rules 12, 31, §3.5.9 R30, R31 (6b): `ref` scalar parameter of inlined functions; `y = a + bump(ref a)` (11 12), `a += bump(ref a)` (12), `show2(a, bump(ref a))` (1 11) and `show2(bump(ref a), a)` (11 11); the deferred `addto(ref a, bump(ref a))` (22 22); a `ref` parameter passed on |
| `inl_ref_elem` | §8.3; rule 31, R31 (6b): `ref` bound to an element, a field, an element's field, a struct whole; the deferred `addat(ref v[0], grow(ref v))` where `grow` replaces v (the element is addressed in the new array: `14 8 7 6 5`) |
| `inl_ref_array` | §8.3, §4.5; rules 12 (a), 31, R30 (6b): array `ref` parameters: store through `ref` copies a shared buffer, in-place reversal, whole replacement, `sum_with(a, zap(ref a))` sees the old array (104.5) |
| `inl_result_struct` | §8.4, §4.6; rule 27, R32 (6b): struct results (strings, arrays, nested struct fields), a result assigned over a `var`, a parameter returned unchanged, a tuple with a struct component |
| `inl_result_fixed` | §4.5, §8.4; rule 27, R32 (6b): `f64[3]`, `f64[2,2]`, `P[2]` and tuple results; `w = f3(w[1])` |
| `inl_return_multi` | §8.4 (6b): `return f(…)` of a multiple-result call inside an inlined function, bound, discarded as a statement, bound with `_` |
| `inl_calls_prelude` | §10.3, §10.6, §10.7, §8.6; rule 37 (6b): inlined functions calling `linspace`, `bincount`, `setdiff` |
| `inl_two_sites_unreachable` | §8.6 (6b): functions with a loop and two call sites, one in a function `.main` never reaches: not class (b), calls |
| `inl_stmt_forms` | §8.6 (c) (6b): an `if / else if / else` chain, a bare block, a `match` inside inlined functions |
| `inl_strings` | §4.4, §8.2, §8.3 (6b): `str` parameters, results and a `ref` parameter of inlined functions; heap check 0 |
| `inl_array_params` | §8.2, §4.5 (6b): array and matrix arguments and results of inlined functions; the argument unchanged |
| `inl_eval_order` | §8.1, §6.8 (6b): inlining evaluates every argument once, in source order, also an ignored or twice-read one |
| `inl_hygiene` | §7.2 (6b): the callee's parameter and locals named like the caller's variables, no capture |
| `inl_return_branches` | §8.1 (6b): returns from several branches and a nested `else` block, the call an operand |
| `inl_void` | §8.1 (6b): an inlined function without a result and an early `return` |
| `inl_conditional_context` | §6.4, §6.8, §6.10 (6b): an inlined call in a `while` condition (re-evaluated), the right operand of `&&` and `||`, `if` expression arms, a loop with `break` |
| `fmt6_d`, `fmt6_d_f64`, `fmt6_e`, `fmt6_f`, `fmt6_g`, `fmt6_pct`, `fmt6_s`, `fmt6_nonfinite`, `fmt6_d_ext`, `fmt6_prec_zeros` | §11.1, §10.9 (6b): the cases of `fmt_*` of the same name, each as `printf` and `print(format(…))`, byte-equal (each line twice) |
| `fmt6_basic` | §10.9, §11.1 (6b): `format` as a `str`: concatenation, `len`, `==`, a `printf` argument, a loop of `DG-%03d` labels, the empty format, `%%` |
| `fmt6_order` | §6.8 rule 5, §11.1 (6b): the arguments of `format` evaluate left to right, also nested |
| `fmt6_big` | §11.1 (6b): 2 KiB, 70 001 and 100 000-byte results, `%.5000f`, `%.3s` |
| `fmt6_empty` | §11.1 (6b): empty results and padding of nothing, precision 0, a width below the length |
| `fmt6_bytes` | §11.1, §3.5 (6b): `%s` of bytes 0x80–0xFF, UTF-8 and a NUL; width and precision count bytes |
| `print_basic` | §11.2, §10.9 (6b): no newline added, pieces join, `str()` of each type, no trailing newline at the end |
| `print_empty` | §11.2 (6b): empty strings write nothing |
| `print_bytes` | §11.2, §3.5, §3.1 (6b): bytes 0x80–0xFF, 0x01–0x1F, 0x7F, a NUL, `\u{…}` and raw UTF-8 |
| `print_mixed` | §11.2, §11.3; DESIGN.md §4.8 `PRINT`, L-cd (6b): `print` and `printf` interleave in one buffer across the 64 KiB flush (72 000 bytes) |
| `print_large` | §11.2, §11.3 (6b): one 70 000-byte `str` |
| `mkdir_twice` | §10.10 (6b): an existing directory is not an error |
| `mkdir_nested` | §10.10 (6b): `d`, `d/e`, `d/e/f`: each parent exists because the previous call created it |
| `mkdir_root_dot` | §10.10; DESIGN.md §4.8 `MAKE_DIR` (6b): `make_dir("/")` and `make_dir(".")` without error on both targets, `./sub` twice |
| `mkdir_existing_dir` | §10.10 (6b): a directory from a fixture (`dir/keep.txt`), also with a trailing `/`; the file untouched |
| `mkdir_many` | §10.10, §10.9 (6b): ten directories by `format`, a sub-directory in each, then again |
| `elem_scalar` | §8.5, §8.4, §6.6, §4.2 (6c): elemental functions called with scalars are ordinary calls: `f64`, `i64` and `bool` parameters and results, an untyped literal and an `i64` variable for an `f64` parameter, floored `idiv` and `%` of a two-result function |
| `elem_vector` | §8.5, §6.3 (6c): one, two and three vector arguments with scalars mixed in, an `f64`, a `bool` and an `i64` result vector, a range value and a fixed `i64` vector as arguments, a vector of length 1 |
| `elem_matrix` | §8.5, §6.3, §5.6 (6c): matrix arguments (one, two, three; a scalar on either side; `A.T`; a slice; a 1 × 1 matrix), a reduction of a `bool` matrix result |
| `elem_broadcast` | §6.3, §8.5 (6c): a scalar with a vector, `.col` with `.row` in both orders, `.col` or `.row` with a matrix, three operands combined left to right with the scalars skipped, 1 × 1 matrices from 1-element vectors |
| `elem_fixed` | §4.5, §8.5 (6c; DESIGN.md §2.11.2 "Elemental calls"): fixed-size arguments bound to fixed-size annotations (vectors and matrices, `.col` with `.row`), a fixed with a dynamic argument gives a dynamic result (proved by `r_elem6_mixed_dynamic`; the fixed result by `err_elem6_fixed_result`) |
| `elem_i64_to_f64` | §4.2 (c), §8.5 (6c): `i64` arrays (a range value, a fixed vector, matrices) for `f64` elemental parameters converted element by element; an `i64` parameter given an `i64` array |
| `elem_uniform` | §8.5, §4.6 (6c): uniform parameters passed unchanged: a struct with `str`, array and scalar fields (W1's `Params` shape; no parameter can be a record, §4.10), a `str`, a dynamic and a fixed-size array, a `str[]`; `$` in the body is the uniform array's extent |
| `elem_results` | §8.5, §2.1, §7.2 (6c; DESIGN.md §2.11.4 L19): one result and five (W1's `shaft_safety` shape) with scalars, vectors, matrices and a broadcast; results bound to `_` keep the others' values; all results bound to `_` print nothing and leave nothing live (the heap check) |
| `elem_tuple_assign` | §7.3, §5.5, §8.5 (6c): `(A[1, :], B[:, 2], _) = f(v, …)` into selection targets, element targets with a scalar call, whole-variable targets taking the results' shape and converting `i64` to `f64`, `_` skipping a result, a scalar result stored into every element of a selection |
| `elem_eval` | §7.1, §7.2, §8.5 (6c; DESIGN.md §2.11.4 L19, L-ck): an elemental call as a statement, or with every result bound to `_`, has no effect; an argument expression is evaluated exactly once, before the elements |
| `elem_nested` | §8.5 (6c): `sq(sq(v))`, an elemental call as another's argument with vectors, `.col`/`.row` and matrices; an elemental function calling another elemental function (`hyp2`, `tri_sq`) and an ordinary function |
| `elem_calls_recursive` | §8.5 as amended, §8.6 (6c): an elemental function calling ordinary recursive functions whose cycle it is not on: factorial and Fibonacci, an even/odd mutual pair; scalars and arrays |
| `elem_named_default` | §8.1, §8.5 (6c): defaults of `f64`, `str` and `i64` parameters of elemental functions, named arguments in any order with scalars and arrays, a default broadcast against an array; argument expressions evaluated once, in source order, before any element |
| `elem_empty` | §8.5, §6.3, §5.1 (6c; DESIGN.md §2.11.4 L19): empty vectors, 0 × 3 and 3 × 0 matrices, `0x1` with `1x3` broadcast to `0x3`, empty ranges, results bound to `_`, call statements, a function without results: no element runs, so a body that always raises `error` is never reached |
| `elem_noresult` | §8.5, §9.2, §9.3 (6c; Decision 92; `.out .err .status`): an elemental function without results called with scalars, vectors, matrices and empty arrays prints nothing; `error` stops at the first failing element in linear order (w[2] = -3, not -5), at the `error` call's line, status 1 |
| `elem_bisect` | §2.1, §8.5, §6.3 (6c): W1's vectorized bisection shape: a two-result elemental function in a loop with one result discarded, `where` choosing the bounds, 30 halvings of [0, 10] for √2, 3, 4, printed with `%.6f` (the mirror performs the same IEEE operations in the same order) |
| `elem_expr` | §8.5, §6.2, §10.5 (6c): an elemental call inside larger expressions: `sum`, `max`, an operand of `+` and `*`, `where`, a comparison, an element loop, a slice, `=` and `+=` into a variable |
| `ind2sub_arr_scalar_k` | §10.7, §6.6; DESIGN.md §2.11.4 L-cl (6c): `ind2sub` with an array `r` (fixed vector, dynamic vector, range value, matrix, empty) and a scalar `k`, negative and zero `k` (floored), a result bound to `_` |
| `ind2sub_arr_array_k` | §10.7, §6.3; DESIGN.md §2.11.4 L-cl (6c): `ind2sub` with an array `r` and an array `k`: element by element, `.col` with `.row`, two matrices, negative and zero `k`, a result bound to `_`, a tuple assignment into `var` vectors, both results discarded |
| `ind2sub_arr_eval` | §7.1, §10.7; DESIGN.md §2.11.4 L19 "under an eval every result is discarded", L-cl (6c): `ind2sub(r, k)` with array `r` and `k` as a call statement has no effect and prints nothing; the next line prints `ok` |
| `elem6_inl_emap_once` | §8 elemental application, §6.3 (7b review, hand-derived): an elemental application with an array argument (`let (a, _) = two(v, 1.0)`, then `sq(a)`) in a function with one call site, so it is inlined; prints `2: 4 9` |
| `elem6_inl_tret` | §8 elemental application, §6.3 (7b review): `return two(v, v)` (a tuple return of an elemental application) in a function called twice, inlined at both calls; `x + y` and `x - y` for `[1]` and `[2, 3]` |
| `elem6_inl_ind2sub_twice` | §10.7 (7b review): `ind2sub([3, 3], [1, 5])` (array `r`, array `k`: `(k % r, idiv(k, r))` = `[1, 2]`, `[0, 1]`) in a function called twice, inlined at both calls |
| `elem6_inl_elem_ind2sub` | §8 elemental functions, §10.7 (7b review): an elemental function whose body calls `ind2sub(d, [i, i + 1])` with a uniform `i64[]` `d`; `a[0] + b[1]` for `i` = 0, 1, 2 is `0 2 1` |
| `elem6_inl_tasg_fields` | §7.3 tuple assignment, §8 (7b review): the results of `two(v, 1.0)` and of `ind2sub` assigned to field paths of a `ref` struct parameter (`t.s.a`, `t.q[0].b`, `t.q[1].a`, elements `t.s.a[0]`, `t.q[0].a[0]`, `_`) in a loop, the function called twice with vectors of 2 and 3 elements; the same into a local struct and returned |
| `elem6_inl_tasg_ref` | §7.3, §8.3 (7b review): a tuple assignment of `two(v, 2.0)` and of `ind2sub([2, 2], [1, 2])` into `ref` array parameters and of `two(v, 1.0)` into the fields of a `ref` struct in a loop, each function called twice, the second time with the arguments swapped |
| `ind2sub_arr_zero_scalar_k` | §6.6, §10.7 (6c; `.out .err .status`): an `r` of 0 at element 1 with a scalar `k`: `integer division by zero` at the call's line, status 1, earlier output flushed |
| `ind2sub_arr_zero_array_k` | §6.6, §10.7 (6c; `.out .err .status`): the same with an array `k` |
| `json_top_scalar` | §11.4 (6d): a top-level scalar of each type, one file each: `%.17g` (0.1, 1/3, pi, `100`, `1e+22`, `-0`), NaN and ±∞ as `null`, i64 −2⁶³ and 2⁶³−1, bool, str, the empty str |
| `json_f64_values` | §11.4, §6.5 (6d): a record of 31 f64 fields: 17-digit values, integral values without a point, exponent forms (two-digit exponents), subnormals, the largest double, −0.0, NaN and ±∞ (literal and computed) as `null` |
| `json_i64_values` | §11.4, §4.2 (6d): a record of i64 fields in decimal: the extremes, 2⁵³ + 1 (never through f64), digit-grouped and hexadecimal literals, a computed product |
| `json_strings` | §11.4, §3.5, §4.4 (6d): `"`, `\`, LF, TAB, CR, NUL, 0x01, 0x1F, all of 0x00–0x1F, 0x7F, bytes 0x80–0xFF, UTF-8, strings built at run time; a top-level str and a `str[]` |
| `json_vectors` | §11.4, §4.5 (6d): dynamic vectors of f64, i64, bool and str, empty vectors of each (`[]`), a vector of one element, `zeros`/`ones`/`filled`, an elemental result; top level and as record fields |
| `json_matrices` | §11.4, §5.6 (6d): matrices as arrays of rows (2 × 3 f64, 3 × 2 i64, bool, str, NaN/∞, 1 × 1, the view `m23.T`, an elemental result) and the matrices with no element (0 × 3, 3 × 0, 0 × 0 of each type) as `[]` |
| `json_struct` | §11.4, §4.6 (6d): a struct of each scalar type, a literal in another field order (declaration order wins), three nested structs, a record with nested records |
| `json_record_arrays` | §11.4, Appendix D (6d): W5's export shape: a record of scalars, dynamic and fixed vectors, a matrix with a NaN, a `str[]`, a nested record, an `i64` expression, an empty vector and a 0 × 4 matrix |
| `json_struct_empty` | §11.4, §4.6 (6d; implementer reading): a struct with no fields is `{}`: top level, a member, the elements of a vector, an empty vector, a 2 × 2 matrix |
| `json_struct_arrays` | §11.4, §4.7 (6d): a vector of structs, a 2 × 3 matrix of structs (array of rows), a vector of one, empty ones, the 2 × 0 and 0 × 3 matrices of structs (both `[]`), structs with vector and matrix fields, a vector of records |
| `json_fixed` | §4.5, §11.4; DESIGN.md §3.5.7 step 4, L-ce (6d): fixed-size fields and values written like dynamic arrays: struct fields `f64[3]`, `i64[2]`, `bool[2]`, `f64[2,2]`, `str[2]`, `f64[0]`; literals, `str[3]`, `str[2,2]`, fixed arrays without elements |
| `json_fixed_structs` | §4.5, §11.4 (6d; implementer reading): a fixed `P[2]` and `P[2,2]` of structs written like the dynamic arrays of structs |
| `json_str_fields` | §4.4, §4.8, §11.4 (6d): `str`, dynamic `str[]` and fixed `str[3]` members, a fixed `str[3]` value, a `format` string, a vector of such structs in a record |
| `json_depth` | §11.4; DESIGN.md §2.11.6 (6d): eight nesting levels (records, an array of records, a fixed vector and a matrix at depth 7): indentation 2 per level |
| `json_replace` | §11.4, §11.3 (6d): a second `write_json` to one path replaces the first (a shorter value: truncation), a loop writing one path, a last shorter write |
| `json_two_paths` | §11.4 (6d): two paths, the first written again: both files complete and independent |
| `json_into_new_dir` | §10.10, §11.4 (6d): `make_dir` then `write_json` into the directory and below a second one; `make_dir` of the existing directory, a replaced file |
| `json_arg_forms` | §11.4; DESIGN.md §3.5.7 step 4 (6d): the path then the value evaluated once (`path 1`, `make 1`), a path from `format` in a loop, a vector parameter written in a function, an element, column and row slices, a reduction, a `str` concatenation, a matrix expression, a call inside an `if` |
| `json_big` | §11.4; DESIGN.md §2.11.6 (6d): a file of about 120 KB (4 000 i64 and 2 500 f64 of 17 digits): the 64 KiB buffer is flushed in the middle of the numbers |
| `json_big_str` | §11.4; DESIGN.md §2.11.6 (6d): one str of 40 960 bytes whose escaped form is 77 826 bytes (with the quotes): the buffer boundary falls inside the escapes |
| `fuse_f1_tree` | §6.2, §6.3, §6.8, §10.4, §8.5; DESIGN.md §2.12.4 F1 (7c): a vector tree and two matrix trees of every fusible node kind: scalars, dynamic and fixed-size vectors and matrices, `.row` and `.col` broadcast in each dimension (also both at once), `where`, `f64()` of `i64` arrays, `sqrt abs exp min hypot log cos`, `^ 2`, elemental functions with one of two results discarded; `u * 1e16 + f64(w)` shows any reassociation |
| `fuse_f2_group` | §6.8, §8.5; DESIGN.md §2.12.4 F2, F5 (7c): a vector group (a stored local read after it, unstored locals, an elemental application with a discarded result, `where` into a reused target) and a matrix group over broadcast inputs ending in a target and `sum` of a `.flat` tree |
| `fuse_f3_reduce` | §10.5; DESIGN.md §2.12.4 F3 (7c): `sum mean variance std max min argmax argmin` over an `f64` tree, over `.flat` of a matrix tree and over a same-mask selection tree (9 of 11 selected); the `i64` forms; `nnz any all` over `bool` trees; 8-lane sums that differ from left-to-right ones |
| `fuse_f4_views` | §5.2, §5.6; DESIGN.md §2.12.4 F4 (7c): folded leaves `.T`, `.flat`, `.row`, `.col`, a row, a column, a reversed range, ranges with a step, a view of a selection, an index vector with a repeat, same-mask selections of a vector and of a matrix and its transpose |
| `fuse_f5_elemental` | §8.5, §6.3; DESIGN.md §2.12.4 F5 (7c): elemental applications with either of two results discarded, an `i64` array for an `f64` parameter, a uniform struct, a `.row` against a matrix, `i64` scalar and `bool` matrix arguments, one-result applications inside larger trees |
| `fuse_group_locals` | DESIGN.md §2.12.4 F2, L-es (7c): four `let`s, two stored (read after the group) and two read only inside it |
| `fuse_group_reuse` | §4.5; DESIGN.md §2.12.4 F2 (6) (7c): a target reused in every loop iteration, a target of length 3 replaced by length 5 (the fallback allocation) then reused, a 2 × 2 matrix target replaced by 2 × 3 then updated |
| `fuse_group_shared` | §4.5; DESIGN.md §2.12.4 F2 (6) (7c): a target sharing its buffer with two other variables before the group; they keep the old values |
| `fuse_group_ref` | §8.3; DESIGN.md §2.12.4 F2 (1), (6) (7c): `ref` vector and matrix parameter targets in groups (twice), the caller's other copies unchanged, `sum` after the target |
| `fuse_group_fixed` | §4.5; DESIGN.md §2.12.4 F2 (2), (6) (7c): fixed-size `f64[4]` and `f64[2,2]` targets of groups whose roots have one static shape |
| `fuse_group_split_vec` | §6.3; DESIGN.md §2.12.4 F2 (2), L-eq (7c): `let a = x * 2.0; let b = y * 3.0` with lengths 3 and 4 and a third statement: no error, the split copy's values |
| `fuse_group_split_bcast` | §6.3; DESIGN.md §2.12.4 F2 (2), L-eq (7c): a group over a 1 × 3 operand and the same operand broadcast against a 2 × 3 matrix: the split copy's values |
| `fuse_w1_bisect` | §2.1, §8.5, §10.4; DESIGN.md §2.12.4 "Example" (7c): W1's grid bisection in miniature: a three-result elemental function (`if` expressions, `min`, `sqrt`, `^ -0.107`, `^ 3`) over a 3 × 4 grid, results discarded, `where` into reused targets, 40 iterations |
| `fuse_w4_rb` | §2.4, §8.3, §6.9; DESIGN.md §2.12.4 (7c): `rb_half_sweep` verbatim over a 6 × 5 plate (concatenated slices, shifted slices, `max` of a same-mask tree, `where` into a `ref` selection), three red and black sweeps |
| `fuse_red_sum_lanes` | §10.5; DESIGN.md §2.12.4 F3, L-et (7c): `sum` over trees of 1, 7, 8, 9, 15, 16, 17 elements and over same-mask selection trees with as many selected elements interleaved with unselected ones; data asserted to separate the 8 lanes from left-to-right summation and, for selections, from lanes counted by the position in the whole vector |
| `fuse_red_max_special` | §10.5; DESIGN.md §2.12.4 F3 (7c): `max min argmax argmin` over trees with ties (the first wins), NaN (ignored; all NaN gives NaN and 0), `-0` before `+0` and `+0` before `-0`, over a `.flat` matrix tree and a same-mask selection (the index in the selection) |
| `fuse_red_argmax_mask` | §5.2, §10.5; DESIGN.md §2.12.4 F3, L-et (7c): `argmax(v[m])` with v = [9, 1, 5], m = [false, true, true] is 1; argmin, max, min of selection trees, the `i64` forms, a matrix mask |
| `fuse_red_variance` | §10.5; DESIGN.md §2.12.4 F2 (1), F3 (7c): `variance` and `std` of trees standalone (two passes over `x * 1e9 + y`), of a `.flat` matrix tree, of an `i64` tree, of one element (0) and of none (NaN) |
| `fuse_cat_parts` | §6.9, §5.6; DESIGN.md §2.12.4 F4, L-eu (7c): concatenations of range selections with steps (also reversed), `.flat` of a matrix and of a transpose, a row, a column, a scalar; matrix parts side by side (slices, `.T`, `.col`) and stacked (`.row`); trees as parts |
| `fuse_cat_stack` | §6.9, §5.3, §5.6; DESIGN.md §2.12.4 F4, L-eu (7c): stacks of 2 and 3 rows whose parts are folded views (`.T`, `.col`, `.row`) and range and `:` selections (steps, reversed, `$`); a row vector stacked under matrices (1 × n); stacks of row vectors; rows mixing scalars with matrices; empty parts (0 × 4, 3 × 0, a 2 × 0 stack); `i64` elements; a fixed-size result |
| `fuse_cat_group` | §6.9, §6.3, §5.6, §10.5; DESIGN.md §2.12.4 F2, F4, L-eu (7c): a stack as a leaf of an F2 group statement, of a fused tree, and under `.flat` reduced by `sum`; vector concatenations with `:` selections and `.flat` parts; a `bool` stack |
| `fuse_alias_inplace` | §5.5; DESIGN.md §2.12.4 F1 (5) (7c): `x = x + 1.0`, `x = x * x - x * 0.5`, a matrix and a fixed-size vector updated from their own elements |
| `fuse_alias_shift` | §5.5; DESIGN.md §2.12.4 F1 (5) (7c): `v[1..n] = v[0..n-1] * 2` gives [1, 2, 4, 6, 8, 10] (the reference's temporary), a backward shift, a column shift of a matrix |
| `fuse_alias_rows` | §5.5, §8.5; DESIGN.md §2.12.4 F1 (5), F4 (7c): `T[1..r-1, :] = avg(T[0..r-2, :], T[2..r, :])` reads the old rows; then the rows above, at and below |
| `fuse_alias_index_vec` | §5.5; DESIGN.md §2.12.4 F1 (5) (i) (7c): `v[w] = v[w] * 2.0 + 1.0` with w = [0, 0] leaves v[0] = 3; `v[w3] = v[w3] * 10.0` with w3 = [1, 2, 1] reads every old element, the last store winning |
| `fuse_alias_field` | §5.5, §4.6; DESIGN.md §2.12.4 F1 (5), L-fe (7c): `s.v[1..3] = s.v[0..2] + 1.0` on a struct field (root path), a copy of the struct unchanged, `s.v = s.v * 2.0 - s2.v` |
| `fuse_alias_group_same` | DESIGN.md §2.12.4 F2 (3) (7c): later statements of a group read the target of an earlier one at the same element (the new value) |
| `fuse_alias_group_shift` | DESIGN.md §2.12.4 F2 (3), L-er (7c): a later statement reads the target of an earlier one shifted (the group ends before it); it sees the new value |
| `fuse_reg_dollar_selstore` | §5.2, §5.5; DESIGN.md §2.12.4 F1 (7c regression, found by the fuzz review): `V[1..$] = y * 2.0` (`$` is `len(V)` = 3, not the operand's length): [1, 10, 12] |
| `fuse_reg_dollar_mat` | §5.2, §5.5; DESIGN.md §2.12.4 F1 (7c regression): `T[:, 1..$] = A * 2.0` into a 3 × 4 matrix (`$` is `cols(T)`): T[0,1] = 2, T[2,3] = 18 |
| `fuse_reg_variance_i64` | §10.5; DESIGN.md §2.12.4 F3 (7c regression): `variance(k * 2)` of an `i64` tree = 91 / 3 = 30.333333333333332 |
| `fuse_reg_group_selfslice` | §5.5; DESIGN.md §2.12.4 F2 (3) (7c regression): `V = V[1..4] + 1.0` (a slice of the target, length 3 afterwards) followed by an independent `let`: [3, 4, 5], 2 |
| `fuse_reg_group_selfivec` | §5.5; DESIGN.md §2.12.4 F2 (3) (7c regression): `V = V[[3, 2, 1, 0]] + 1.0` (an index vector over the target) followed by an independent `let`: [5, 4, 3, 2], 2 |
| `fuse_reg_group_selfT_fixed` | §5.5; DESIGN.md §2.12.4 F2 (3) (7c regression): `F = F.T * 1.0` on a fixed-size 2 × 2 target followed by `let g = F + 1.0`: F[0,1] = 3, F[1,0] = 2, g[0,1] = 4 |
| `fuse_reg_slots_full` | §6.8; DESIGN.md §2.12.4 F1, F2 (7c regression): a 200-leaf tree and a 100-use tree that exhaust the fusion pass's slots, evaluated strictly left to right (values computed by an independent Python evaluation) |
| `fuse_reg_flat_red_group` | §10.5; DESIGN.md §2.12.4 F2, F3 (7c regression): `sum((A * 2.0).flat)` right after an unrelated matrix `let g = A + 1.0`: 42, 2 |
| `fuse_reg_two_tbinds` | §8.5; DESIGN.md §2.12.4 F2, F5 (7c regression): two consecutive tuple bindings of a two-result elemental function (`f2(x, x)`, `f2(x, 2.0)`) |
| `fuse_reg_i64x18_sum` | §10.5; DESIGN.md §2.12.4 F3 (7c regression): a fixed-size `i64` array of 18 elements beside the fused `sum(y * 2.0)` = 7 |
| `fuse_reg_group_masked_red_split` | §5.2, §10.5; DESIGN.md §2.12.4 F2, F3 (7c regression): `let g = y * 2.0` (5 elements) followed by `sum(x[mk] * 1.0)` over a selection of another length: 4, 2 |
| `vec_trip_arith` | §6.5, §6.8, §10.4, §10.5; DESIGN.md §2.12.6 T13 (7e T1): fused `f64` trees (`+ - * /`, `abs`, unary minus, `sqrt`, splat constants) over whole arrays and their `sum` at trip counts 0, 1, 7, 8, 9, 15, 16, 17 and 1000 (tails 0–7); all elements printed up to 17 |
| `vec_trip_mask` | §6.4, §10.4, §10.5; DESIGN.md §2.12.6 T13 (7e T1): `>`, `<`, `!=` masks stored as `bool` arrays, `\|`, `&`, `!`, `where` over a stored mask, `nnz` and `sum`, at the nine trip counts |
| `vec_matrix_plain` | §6.3, §5.6, §10.5; DESIGN.md §2.12.4 F1 (4), §2.12.6 T13 (7e T1): matrices of 0, 1, 7, 8, 9, 15, 16, 17 and 1000 elements (shapes 0 × 3 … 40 × 25) through F1's plain linear loop: a tree, a mask, `where` with a negated tree, `nnz` and `sum` of `.flat` in column-major order |
| `vec_sqrt_misc` | §6.5, §10.4; DESIGN.md §2.12.6 T13 (7e T1): `sqrt` (NaN for negatives, `sqrt(-0)` = −0), `abs`, unary minus, `1.0 / x` (±∞ at ±0) and `sqrt(x * x + 1.0) - abs(x)` on a 17-lane vector with 0, −0, ±∞, NaN, a subnormal and values whose square overflows or underflows, at lengths 0, 1, 7, 8, 9, 15, 16, 17 |
| `vec_minmax` | §10.4, §3.6.4 (`fmin`, `fmax`); DESIGN.md §2.12.6 T13 (7e T1): two-argument `min` and `max` with NaN in either operand or both, ±0 in every order (the first argument wins), ±∞, subnormals, a splat on either side and a clamp tree ending in `+ 0.0`, at lengths 0, 1, 7, 8, 9, 15, 16, 17 |
| `vec_where_cmp` | §6.4, §10.4; DESIGN.md §2.12.6 T13, §2.12.7 (7e T1): `where` with the masks `< <= > >= == !=` of two arrays (NaN lanes: ordered comparisons false, `!=` true; ±0 equal), of an array and a splat on either side and of two trees, at lengths 7, 9, 16, 17 |
| `vec_where_boolarr` | §6.4, §10.4; DESIGN.md §2.12.6 T13 (7e T1): `where` with `bool` array masks alone, negated, combined by `&` and `\|`, combined with a comparison and nested, at lengths 0, 1, 7, 8, 9, 15, 16, 17, then 1000 elements with a mask computed by a loop |
| `vec_bool_store` | §6.4, §10.5; DESIGN.md §2.12.6 T13, §3.6.4 (`stm2`, `stm4`: bytes 0 or 1) (7e T1): five stored `bool` results of comparisons and logic on NaN, ±0, ±∞ and subnormal lanes, counted with `nnz`, `any`, `all` and printed, at lengths 1, 9, 16, 17 and a 1000-element `nnz` case |
| `vec_ifexpr_w1` | §8.5, §6.10, §10.4; DESIGN.md §2.12.6 (if-conversion; "What the workloads get"), W1's `shaft_safety` shape (7e T1): elemental functions with an `if` expression (`&&` condition, else-if chain, quiet arms with `sqrt` and `min`) and a statement-form `if`/`else` assigning a local, with lanes on the boundaries 2.79, 51, 254, NaN, ±∞, negative values and zero; lengths 1, 7, 8, 9, 17 and 1000 |
| `vec_ifexpr_pow` | §8.5, §6.10, §10.4; DESIGN.md §2.12.6, §2.12.8 (7e T1): W1's if-converted chain with `d ^ e` in two arms (`pow` speculated in every lane: NaN, negative and zero bases, tiny and huge bases and exponents); every pair is a row of `tests/math/pow.vec`, the result its reference bits; lengths 1, 7, 8, 9, 17 |
| `vec_fn_sincos` | §10.4; DESIGN.md §2.12.6 T13, §2.12.8 (7e T1): `sin`, `cos` and `sin(x) * 2.0 - cos(x)` on a 13-entry cycle (rotated by an offset) with \|x\| ≥ 2²³ (2²³, 1.4e7, 5.7e30, 1.9e31), a subnormal, NaN, ±∞, ±0 among common arguments; results are rows of `tests/math/sin.vec`, `cos.vec`; per-lane match counts at lengths 0, 1, 7, 8, 9, 15, 16, 17, 1000, values printed up to 17 |
| `vec_fn_logexp` | §10.4; DESIGN.md §2.12.6 T13, §2.12.8 (7e T1): `log` of subnormals, the smallest normal, 0, −1, NaN, +∞, 2²³ and `exp` of 600.27, 709.78, −745.13 (subnormal result), −708.4, NaN, ±∞, 5e-324, plus `log(a) - exp(b)`; results are rows of `tests/math/log.vec`, `exp.vec`; same lengths and offsets as `vec_fn_sincos` |
| `vec_fn_powhypot` | §10.4; DESIGN.md §2.12.6 T13, §2.12.8 (7e T1): `pow` (NaN base, negative base, 2⁷⁵⁰, underflowing results, tiny and huge bases) and `hypot` (largest double, subnormals, ±∞, NaN, ±0, overflowing result) pairs on 13-entry cycles, plus `pow(a, b) + hypot(c, d) * 0.5`; results are rows of `tests/math/pow.vec`, `hypot.vec`; same lengths and offsets |
| `vec_sum8` | §10.5; DESIGN.md §2.12.6 T13 (5) (7e T1): `sum` in the pinned 8-lane order for a 9- and a 17-element vector whose sum8 result differs from the left-to-right result (both printed), the lengths 16, 15, 8, 7, 1, 0, `[-0.0]` and 1000 harmonic terms, with fused `sum(x * 1.0 + y)` and `sum(x * x)` |
| `vec_inplace` | §5.5, §6.8; DESIGN.md §2.12.4 F1 (5), §2.12.6 T13 (4) (7e T1): in-place updates `x = x * 1.5 + 0.25`, `x = where(x > 10.0, x * 0.5, x)`, `x = sqrt(x * x + 1.0)`, `a = a + b`, `a = min(a, b * 4.0)`, `m = m & (x > 1.5)` and a fixed-size `f64[9]` written in its home, at the nine trip counts |

## passes/

| Test | Files | Spec (DESIGN.md unless noted) |
|------|-------|------|
| `ex` | ast | §3.4 example, verbatim |
| `lx` | ast hir1 hir hirl lir1 lir2 lir3 lir | §3.6.7 example (lir1 verbatim; `.lir2`, `.lir3` and `.lir` all equal the §3.6.7 text); ast §3.4, hir1/hir §3.5 |
| `ev` | ast | §3.5.5 example program (its hir1 needs structs: phase ≥ 2) |
| `lex_int` | ast | LANGUAGE.md §3.4; §3.1 `i` field; §3.4 2⁶³ only under `neg` |
| `lex_float_easy` | ast | LANGUAGE.md §3.4; §3.1 `f` field |
| `lex_float_hard` | ast | LANGUAGE.md §3.4; §2.8 (bits: `vectors/float_oracle.py`, table `float_oracle.out`) |
| `lex_string` | ast | LANGUAGE.md §3.5; §3.1 string escaping |
| `lex_comment` | ast | LANGUAGE.md §3.2, §3.7 |
| `lex_for_blanks` | ast | §3.4 `for` `npos` (L1), two blanks after `for` |
| `lex_newline` | ast | LANGUAGE.md §3.7, Appendix A `sep` |
| `lex_column` | ast | LANGUAGE.md §3.1, §3.3 (63-byte identifier), §9.1 byte columns |
| `op_prec` | ast | LANGUAGE.md §6.1, Appendix B; §3.3 positions with parentheses |
| `stmt_header` | ast | LANGUAGE.md §6.11, Appendix A header mode |
| `stmt_grammar_full` | ast | Appendix A, every production; §2.6.2 (pass 1 parses the whole grammar) |
| `type_untyped` | ast hir1 hir | LANGUAGE.md §4.2, §6.5; §3.5.5, §3.5.7 folding |
| `type_var_rule` | ast hir1 hir | LANGUAGE.md §4.2 var rule (Decision 8) |
| `type_cvt` | ast hir1 hir | LANGUAGE.md §4.2; §3.5.5 `cvt` positions, `lib f64/i64` |
| `type_powk` | ast hir1 hir | LANGUAGE.md §6.5; §3.5.5 "Constant exponents"; §3.5.2 (`K = 6 % 4` is the leaf 2) |
| `type_const_neg` | ast hir1 hir (+ `.out`) | §3.1 field `i` (−10⁹ and −2⁶³ in hex, −999 999 999 in decimal); §3.5.2 leaf at the `neg`; §3.5.7 steps 1–2 |
| `type_const` | ast hir1 hir | LANGUAGE.md §7.2 U2; §3.5.2 (each `cn` child one leaf at the root's position), §3.5.7 steps 1–2 |
| `fn_ref` | ast hir1 hir hirl lir1 | LANGUAGE.md §8.3; §3.5.4, §3.6.3, §3.6.6 rule 12 |
| `fn_multi` | ast hir1 hir hirl lir1 | LANGUAGE.md §8.4; §3.5.1 `ttuple`, §3.5.5 `tbind`/`tret`, §3.6.6 rules 2, 5 |
| `fn_ref_order` | ast hir1 hir hirl lir1 | LANGUAGE.md §6.8 rule 5; §3.6.6 rule 12 (copy at the evaluation point, reloads, `mov x R` last) |
| `fn_printf` | ast hir1 hir hirl lir1 | LANGUAGE.md §11.1, §13, §10.1; §3.5.5 `fmt`, §3.6.2, §3.6.6 rules 7–10 |
| `type_ifx_arm` | ast hir1 hir hirl lir1 | LANGUAGE.md §4.2 (f); §3.6.6 rules 2–3 (ifx and `&&` at the root of a stored value: new R, then `mov`) |
| `op_fold` | ast hir1 hir | §3.5.7 step 2, §2.8 (U1: overflow, `x / 0`, `inf`/`nan` operands fold; NaN bits) |
| `op_shortcircuit` | ast hir1 hir hirl lir1 | §3.5.5 `ifx`; §3.6.6 rule 3 |
| `stmt_tasg` | ast hir1 hir hirl lir1 (+ `.out`) | LANGUAGE.md §7.3, §4.2 (b); §3.5.5 `tasg` `cv` flags; §3.6.6 rule 2 `tasg` steps (a)–(d): cv 1 into a local (`itof`, `mov`), cv 0 straight into the target register, `skip` a new register, a `ref`-parameter target with cv 1 (`itof`, `stf`), a target local the call passes by `ref` (new register, reload, then `mov`) |
| `stmt_loops` | ast hir1 hir hirl lir1 | §3.5.5 `while` `forr` `cont` `break`, §3.5.7 (step −2 folded); §3.6.6 rule 4 |
| `gen_arith` | lir (+ `.out`) | pass-4 input written as LIR; `.out` lines 3–4 derived from the spec: the `d`/`e` of 12 `rcount`s by DESIGN.md §3.6.4: n elements of the range (LANGUAGE.md §5.1), `d` = 0 for an empty range (n = 0), else (n−1) mod 2⁶⁴ printed as i64 (−1 for the full range n = 2⁶⁴), `e` = 1 iff n > 0 |
| `gen_calls` | lir (+ `.out`) | pass-4 input written as LIR (pre-6b, row added in 6b): a `call` with 20 `i` and 20 `f` arguments and results, the arguments passed through to a callee and printed back, a recursive factorial (2432902008176640000) |
| `lir4_retain_release` | lir (+ `.out`) | sub-phase 4c pass-4 test (§6.2): `retain`/`release` (§3.6.4, §4.9) on a fresh array (count 1 → 2 → 3, read with `ldi` at `SEA_OBJ_RC`), the same object shared (3 → 2 → 1), its last `release` freeing it (the next array of its 128-byte class is the same block, by the LIFO free lists of §4.1, again count 1 and zeroed), a static `str` object (count `SEA_RC_STATIC` 0 unchanged by `retain`/`release`), and a fresh `sea_str_i64` string (−2⁶³ in decimal, §4.8) |
| `lir4_release_leaf` | lir (+ `.out`) | a function whose only call-like instruction is `release` (non-leaf by §4.9: frame record, §4.6 check): it frees an `str[]` and a string through `sea_free` and still returns to its caller |
| `lir4_mcopy` | lir (+ `.out`) | `mcopy` of 0, 7, 8, 9 and 100 bytes from a `dat` buffer + 5 to a zeroed 128-byte slot + 3 (both unaligned); the 16 words of each slot printed with `%d` (little-endian, computed by `vectors/lir4_gen.py`), so bytes beyond n stay 0 |
| `lir4_slay` | lir (+ `.out`) | `slay`/`soff` with 0 and 3 offsets (§3.6.2, §4.9: `SEA_SL_*` words read back), `sea_arr_new_s` (§4.8: count 1, ek 5, rank, rows, cols, cap, esize = size, `SEA_ARR_SLAY` = the descriptor, data at header + 64, buffer zeroed); a string stored with a `retain` into two reference fields goes from count 3 back to 1 when the array is released (`sea_free` releases the non-null reference fields by the descriptor) |
| `lir4_entries` | lir (+ `.out`) | the other returning entries of ids 9–20 through pass 4 (§4.8): `sea_str_f64` (an `f` argument with the site the first integer argument: `%.17g` text, `nan` for both NaN signs, `inf`, `-inf`, LANGUAGE.md §10.9), `sea_str_cmp` (unsigned bytes, prefix, empty), `sea_str_cat` (also of two empty strings: a new string), `sea_str_lower` (only A–Z), `sea_arr_new_u` (header), `sea_arr_unique` (count 1: the same array; count 2: a copy with count 1, the old count 1, a store into the copy leaves the old), `sea_args` (no arguments: rank 1, length 0, LANGUAGE.md §10.10); everything released |
| `lir4_seaopt` | lir1 lir2 | stage test of pass 3b, hand-written (§3.6.5): `retain`, `release`, `mcopy`, two `slay` groups (0 and 2 `soff`), a `dat`, `sea_arr_new_s`; the 5c-1 `.lir` renamed `.lir2` by 5c-2, no `.lir` (L-bj); re-derived for 5c-1 (L-ak): T3 shares three `li`, T10 deletes `retain p5`/`release p5` |
| `ra5_spill_i` | lir (+ `.out`) | 5b pass-4 test (§4.9.2, §6.2): 40 live `i` and 30 live `p` values (more than 25/10 general registers), carried around a `loop`, used as spilled operands, destinations, load/store bases and indices; `.out` from the §3.6.4 semantics (generator `ra5_gen.py`) |
| `ra5_spill_f` | lir (+ `.out`) | 40 live `f` values (more than 29/14 FP registers) carried around a loop; spilled `fadd fsub fmul fdiv fcmp` operands and destinations |
| `ra5_calls` | lir (+ `.out`) | values live across `call`, `rcall` and the free path of `release` in caller-saved registers, carried around a loop that contains the call (16 `i`, 12 `f`); callee `clob` with 26 `i` + 30 `f` live (callee-saved registers in a leaf) |
| `ra5_callee` | lir (+ `.out`) | callee-saved registers in a recursive function with 12 `i` + 9 `f` live across its own call; the caller's values survive it |
| `ra5_pmove` | lir (+ `.out`) | parallel moves with cycles: argument/result swaps into the same registers, 3-rotations, 4-argument cycles under pressure (x86_64 `%rdx`/`%rcx` with spilled sources), 20 arguments and results (stack slots) permuted |
| `ra5_fcmp` | lir (+ `.out`) | every `fcmp` cc on NaN, ±0, ±Inf and same-register operands, materialized and fused (if/else, ifz, one branch to exit/next, isel, fsel); only `ne` holds with NaN (LANGUAGE.md §6.8; L-as) |
| `ra5_icmp` | lir (+ `.out`) | every `icmp` cc against constants at the immediate limits (0, ±4096, ±2³¹, −2⁶³, each ±1), both operand orders, if, isel, psel, exit; compare with 0, if/ifz on a register, `bnot` |
| `ra5_imm` | lir (+ `.out`) | immediates at the encoding limits (arm64 4095/4096/4097/−4095, 0xFFF000; x86_64 2³¹−1, 2³¹) in add/sub/mul/logic, checked forms and `padd`; logical immediates; shift amounts 0–63 |
| `ra5_chkb` | lir (+ `.out`, `.err`, `.status`) | `chkb` with the immediate indices 4095, 4096, 2³¹−1, 2³¹ in bounds, then 4096 against extent 4096: the index error at line 9 |
| `ra5_chkb_neg` | lir (+ `.out`, `.err`, `.status`) | `chkb` with the immediate index −1 (an unsigned compare in a register): the index error at line 6 |
| `ra5_staged` | lir (+ `.out`) | every staged template (`idivf imodf rcount ftoi fmin fmax ffloor fceil ftrunc fround mcopy`) with the destination sharing an operand's register, with free registers and under 30 `i` + 32 `f` pressure |
| `ra5_loops` | lir (+ `.out`) | both loop-closing forms (L-ai), `ind` read after the loop or not, a 2⁶⁴-iteration loop left by `exit`, step/start/last registers written in the body, wrapping induction, nested next/exit, rcount guard |
| `ra5_forms` | lir (+ `.out`) | x86_64 two-address cases (d = a, d = b commuting or not, both), `leaq`/`imulq $v`, `itof`, `fabs`, `fneg`, `fsqrt`, `isel`/`psel`/`fsel` with d = a/b and fused/unfused conditions (L-ah) |
| `ra5_addr` | lir (+ `.out`) | load/store address forms: offsets 0–32768, negative offsets, scales 1/2/3/8/16/24, offsets of 2³¹ − 8 and 2³¹ + 16, `ldb`/`stb`, `ldf`/`stf` |
| `ra5_ovf` | lir (+ `.out`, `.err`, `.status`) | `imulc` with d = a (high half first): in range, then `integer overflow` at line 5 |
| `ra5_live_ifs` | lir (+ `.out`) | 5c-2 WP-RA2 (Decision 75): `if`-part temporaries not extended over the loop; `.out` from lirkit's interpreter; the measured loop has no frame access on either target |
| `ra5_live_carry` | lir (+ `.out`) | 5c-2 WP-RA2: a loop-carried value inside an `if` part; `.out` from lirkit's interpreter; the measured loop has no frame access on either target |
| `ra5_live_both` | lir (+ `.out`) | 5c-2 WP-RA2: a value written in both parts and read after `endif` (L-bh); `.out` from lirkit's interpreter; the measured loop has no frame access on either target |
| `ra5_live_copies` | lir (+ `.out`) | 5c-2 WP-RA2: sibling loop copies with renamed locals (L-bg, L-bl); `.out` from lirkit's interpreter; the measured loop has no frame access on either target |
| `fn_reach` | ast hir1 hir | §3.5.7 step 5, §3.5.1 renumbering |
| `math_lower` | ast hir1 hir hirl lir1 | §3.6.6 rule 14 (`rcall sea_<fn> - 1 d n args`, no site) for `log exp sin cos pow hypot` and a non-powk `^`, rules 1, 2, 10 (`cvt` and `f64()` are `itof`, the rcall writes the bound local), §3.6.1 numbering; §3.5.7 (nothing folded) |
| `const_pow` | ast hir1 | §3.5.2 (each `cn` leaf at the root position), §4.10.5 (`^` non-powk and `pow` folded by FEPOW: the model's bits from `math_model.eval_bits`, NaN `#7FF8000000000000`), §3.5.5 (`x ^ K` with `K = pow(9.0, 0.5)` is `powk 3`, `x ^ C` stays `bin pow`) |

| `rs` | ast res hir1 | §3.4.1 example: `.res` verbatim (and reproduced by `vectors/res_gen.py`), `.ast` by §3.4, `.hir1` by hand from §3.5 (`ttuple`, `tbind`, `powk`, `cref`, `forr`, `fmt`) |
| `res_names` | ast res | §3.4.1: rname `loc` (a parameter, `var lo = lo`, a block-scope shadowing `let`, a loop variable, an outer local read by a shadowing `let n = i + n`), `cst`, `fn`, `pd`, `none`; lids numbered as §3.5.4 |
| `res_rint` | ast res | §3.4.1: `rint` `fv`: `-` for 2⁵³ + 1, `#C3E0000000000000` for the 2⁶³ literal under `neg`, an exact large value |
| `res_consts` | ast res | §3.4.1: `rcni`, `rcnf` (an `i64` value into an `f64` annotation), `rcnb`, `rcne ovf` (at the `mul`) and `rcne div0` (at the `%`), `rcn` for `now()` (not typable), for a constant naming one without a value (Decision 25), and for both constants of a cycle; the constant order |
| `res_powk_skip` | ast res | §3.4.1: `rpowk 2` from a constant, a plain `bin pow` where a local shadows it; `rtup 10` reused by two signatures; `rerr 235` at a not-entered `fn` copied unchanged; from 4g-1 the `match` is resolved (§3.4.2); from 4d (§3.4.2) the `for` over an array literal is resolved (`rfor`, its `pname` a lid) |
| `res_powk_mod` | ast res | §3.4.1, §3.5.5: the operands of an untyped `%` are `i64` (LANGUAGE.md §4.2), so `x ^ (6 % 4)` is `rpowk 2`; `x ^ (5.0 % 3.0)` is `rpowk 2` by the exact `f64` `%` of LANGUAGE.md §6.6 |
| `res_noval_calltype`, `res_noval_shortcircuit`, `res_noval_userpow` | ast res | §3.4.1 (Decision 25 refined): the programs of the three `err_const_noval_*` refinement tests (lines 1–3, comment after); every constant `rcn` (a call of a function item is not evaluated; `D` names `B` without a value; `pow` resolves to the entered `fn pow`, `rname fn`), with their `rerr` (229 `unknown struct type` at the undeclared result type `Q` twice, re-derived by 4g-1, L-i; 212) |
| `res_struct` | ast res | §3.4.2 (4g-2, L-i re-derived): `rtst`/`rtfd`, `rst`, `rname st`; no rerr (`let q = P` is seacheck's) |
| `res_arr_types` | ast res | §3.4.2 (4d): `rtype` with its type everywhere; `rtmat`/`rtvec`/`rtup` in the order of creation (signature types, the tuple after its components, then the `let` annotations in file order); an element loop resolved (`rfor`, its variable before the body's locals) |
| `res_err_dim` | ast res | §3.4.2: `rerr 200` at an undeclared dim name of a fixed-size type (the node's first error, before the phase rule; the dim an `rname none`, the type 0) |
| `arr_rule16` | ast res hir1 hir hirl lir1 (+ `.out`) | §3.6.6 rule 16: the example function verbatim (release on `break` and at the end of the loop body) |
| `arr_rule17` | ast res hir1 hir hirl lir1 (+ `.out`) | rule 17: `let u = ones(n)` (line 1, n in `i1`) verbatim; then rule 18 and `len` |
| `arr_rule18` | ast res hir1 hir hirl lir1 (+ `.out`) | rule 18: `T[j-1, i]` (line 7, g's parameters) verbatim; `$` in both dimensions (`dol`), rule 19 in `.main` |
| `arr_rule19` | ast res hir1 hir hirl lir1 (+ `.out`) | rule 19: `T[j, i] = tn` (line 12, T = `mk()` in `p1`) verbatim; a store in a loop; an array result (retain, release, `ret`) |
| `arr_rule30` | ast res hir1 hir hirl lir1 (+ `.out`) | rule 30: the second example (`for x in v`, line 3, v a parameter in `p1`) verbatim |
| `arr_rule31` | ast res hir1 hir hirl lir1 (+ `.out`) | rule 31: `f(ref v[i])` (line 4) verbatim; a compound store through an `f64` `ref` parameter (rule 12) |
| `arr_rule36` | ast res hir1 hir hirl lir1 (+ `.out`) | rule 36: `let d = abs(tn - t)` (line 6) verbatim |
| `loop_fore_exits` | ast res hir1 hir hirl lir1 (+ `.out`) | §3.5.9 L4 (a `for` over a vector made explicit by `sealoop`): `return`, `continue` and `break` inside element loops, nested element loops, a `for` over an owned vector (`ones(3)`), over a `ref` parameter of array type and over an `if` expression of two vectors; `.lir1` from the unchanged rules 17 and 30 |
| `loop_fill` | ast res hir1 hir hirl lir1 (+ `.out`) | §3.5.9 L1/L2 (`zeros`, `ones`, `filled` made explicit): `filled` of `f64`, `i64` and `bool` vectors and matrices, `ones` and `zeros` of a matrix, a count that is a `ref` parameter, `filled(k, grow(ref k))` (rule 12 copies `k`), `ones(if c {2} else {3})` and `filled(p && q, m)` (T1's `ifx`/`and` child) |
| `loop_ext` | ast res hir1 hir hirl lir1 (+ `.out`) | §3.5.9 L3 (`len rows cols numel` made explicit): of locals, of `ref` and value parameters and of temporaries (`ones`, `zeros`, an `if` expression of two matrices) |
| `arr_rule20` | ast res hir1 hir hirl lir1 (+ `.out`) | 4e, §3.6.6 rule 20 (selection read): the agreed example `let u1 = u[0..$ step 2]` as a whole program, its `.lir1` the rule's text exactly; `.hirl` from §3.5.9 L5 |
| `arr_rule21` | ast res hir1 hir hirl lir1 (+ `.out`) | 4e, rule 21 (selection store): the agreed example `v[m] = 0.0` (a `bool` mask of an `f64[]`), its `.lir1` the rule's text exactly; `.hirl` from L6 |
| `arr_rule22` | ast res hir1 hir hirl lir1 (+ `.out`) | 4e, rule 22 (element-wise): the agreed example `let z = x * 2.0`, its `.lir1` the rule's text exactly; `.hirl` from L7 |
| `arr_rule25` | ast res hir1 hir hirl lir1 (+ `.out`) | 4e, rule 25 (range value): the agreed example `(0..=nBin)` as a value, its `.lir1` the rule's text exactly (the two large `li` immediates in the `#` encoding of §3.1); `.hirl` from L8 |
| `arr_rule28` | ast res hir1 hir hirl lir1 (+ `.out`) | 4e, rule 28 (views): the agreed example `A.flat[k]` folded into the addressing, its `.lir1` the rule's text exactly |
| `sel_reads` | ast res hir1 hir hirf hirl lir1 (+ `.out`) | 4e, §3.5.9 L5, rule 20: a matrix selection with `:` and a scalar, an index vector, a whole-matrix mask read; 7c (Decision 97, L-fb list below): `.hirf` new (`let M = A > 5.5`, a one-node matrix tree, is F1's by Decision 111: plain copy over R·C, broadcast copy, L-eo, L-ep), `.hirl` and `.lir1` re-derived from it |
| `sel_ref_store` | ast res hir1 hir hirl lir1 (+ `.out`) | 4e, L6, rule 21: a selection store into a `ref` parameter (read afresh for each extent, the cow and the data) |
| `sel_compound` | ast res hir1 hir hirl lir1 (+ `.out`) | 4e, L6, rules 21, 22: a compound `x[sel] += e` (gather into a temporary, the operation, the store) |
| `ew_colrow` | ast res hir1 hir hirf hirl lir1 (+ `.out`) | 4e, L7, rule 22: matrix broadcasting of `.col` with `.row` (strides, the shape checks); 7c (Decision 97, L-fb list below): `.hirf` new (`a.col * b.row` is F1 with the `.col` and `.row` leaves folded by F4: plain and broadcast copies), `.hirl` and `.lir1` re-derived from it |
| `arr_lit_fixed` | ast res hir1 hir hirl lir1 (+ `.out`) | 4e, L9, rules 26 (a), (d), 27: fixed vector and matrix literals, `[]` dynamic and fixed |
| `arr_lit_dyn` | ast res hir1 hir hirl lir1 (+ `.out`) | 4e, L9, rule 26 (b): a dynamic constant literal (257 elements, `cdat`) and a dynamic non-constant literal |
| `arr_lit_cat` | ast res hir1 hir hirl lir1 (+ `.out`) | 4e, L9, rule 26 (c): vector and matrix concatenation (joined lengths, the row and stack checks) |
| `arr_views` | ast res hir1 hir hirl lir1 (+ `.out`) | 4e, L10, rule 28: `.T` and `.flat` materialized |
| `arr_dynfix` | ast res hir1 hir hirl lir1 (+ `.out`) | 4e, L10, rule 27 (i), (j): `dyn` and `fix` (the `SHAPE_EXPECTED` check) |
| `arr_fixed` | ast res hir1 hir hirl lir1 (+ `.out`) | 4e, rule 27 (a)–(d), (h), (l): a fixed-size local with element read and write, a fixed-size result through the hidden address |
| `ew_ind2sub` | ast res hir1 hir hirl lir1 (+ `.out`) | 4e, L11, rule 22 (Decision 33): `ind2sub` of a vector as two element-wise loops over held arguments |
| `arr_tasg_l12` | ast res hir1 hir hirl lir1 (+ `.out`) | 4e, §3.5.9 L12 (Decision 37): a tuple assignment with a selection target (an L6 store of a fixed-size result through a `.l` local) and a fixed → dynamic component (`cv` 2, the `dyn` of L10); one `tbind` of fixed-size `.l` locals passing their slots as hidden result addresses; two fixed-size results returned by copy |
| `arr_lit_cat_fixed` | ast res hir1 hir hirl lir1 (+ `.out`) | 4e, L9, rule 26 (c) with every part fixed-size: a vector join `[a, 4.0, a]` and a matrix row `[m, m]` with home slots, the length and column sums kept, no row check, static extents and offsets |
| `lib_rule23` | ast res hir1 hir hirl lir1 (+ `.out`) | 4f, §3.6.6 rule 23 (reductions): the agreed example `let s = sum(x)` (`x` an `f64[]` in `p1`) as a whole program, its `.lir1` the rule's text exactly; `.hirl` from §3.5.9 L13 (sum8 with the accumulator home of the appended type `f64[8]`, R14; the lane `K & 7` by `wbin and`, R13; the `ifx` taking the register of `s`, R12 (a)) (from 6b each function that LANGUAGE.md 8.6 would inline starts with `while false {}` on its header line, so it keeps its calls; Decision 90) |
| `lib_rule24` | ast res hir1 hir hirl lir1 (+ `.out`) | 4f, rule 24 (sorting and searching): the agreed example `let r = argsort(c, desc: true)` on line 8, its `.lir1` the rule's text exactly (`rcall sea_argsort` with the vector and the `desc` value); `.hirl` = `.hir` for that function (L14, R16: the `lib argsort` stays); `r[0]` read by rule 18, `r` released before the `ret` (from 6b each function that LANGUAGE.md 8.6 would inline starts with `while false {}` on its header line, so it keeps its calls; Decision 90) |
| `lib_mean_i64` | ast res hir1 hir hirl lir1 (+ `.out`) | 4f, L13 on a fixed-size `i64` vector: `sum` (isum, the extent loaded after the data, `iaddc` with the call's line, the accumulator taking the register of `t`, R12 (b)) and `mean` (the sum converted before n, rule 23) |
| `lib_variance` | ast res hir1 hir hirl lir1 (+ `.out`) | 4f, L13: `variance` (n = 0 NaN, n = 1 zero, else the two-pass mean and deviations, each sum8 with its own home slot; the outer `ifx` taking the register of `v`, R12 (a)) and `std` (the variance `xblk`, then `fsqrt`) (from 6b the function is inlined by L20: the .hirl/.lir1 show the construct inside the inline xblk/iblk at each call site; Decision 90) |
| `lib_max` | ast res hir1 hir hirl lir1 (+ `.out`) | 4f, L13 on fixed-size vectors: `max` of `f64` (`EMPTY_REDUCE` with the function's name, NaN ignored, the first maximum; R15's `where` values) and `argmin` of `i64` |
| `lib_nnz` | ast res hir1 hir hirl lir1 (+ `.out`) | 4f, L13: `nnz` (`wbin add` of a `bool`, R7), `any` and `all` of a fixed-size `bool` vector, each accumulator taking the register of its local (R12 (b)) |
| `lib_sum_dim0` | ast res hir1 hir hirl lir1 (+ `.out`) | 4f, L13 `dim:` form: `sum(A, dim: 0)` of a dynamic matrix (extents and data loaded once before the outer loop over the columns, one sum8 home slot for every column, the element at `I + J * rows`) (from 6b the function is inlined by L20: the .hirl/.lir1 show the construct inside the inline xblk/iblk at each call site; Decision 90) |
| `lib_sum_dim1` | ast res hir1 hir hirl lir1 (+ `.out`) | 4f, L13 `dim:` form: `sum(A, dim: 1)` of a fixed-size `f64[2,3]`, its result the fixed-size `f64[2]` (Decision 39: a home slot copied into the home of `s`), the lane `wbin and` of J (from 6b the function is inlined by L20: the .hirl/.lir1 show the construct inside the inline xblk/iblk at each call site; Decision 90) |
| `lib_find` | ast res hir1 hir hirl lir1 (+ `.out`) | 4f, L14: `find` of a fixed-size `bool` vector (the count, the new `i64[]` of that length, the indices stored in order); the result is dynamic (Decision 39) |
| `lib_find_first` | ast res hir1 hir hirl lir1 (+ `.out`) | 4f, L14: `find_first` (the first `true`: `where` of a counter, R15) and `find_last` of a fixed-size `bool` vector |
| `lib_sort_fixed` | ast res hir1 hir hirl lir1 (+ `.out`) | 4f, L14, R16, Decision 39: `sort` and `argsort` of a fixed-size vector (the `dyn` pass 2a writes at the call's position, rewritten by L10, released right after the `rcall`), `desc:` inserted as false and given as a run-time `bool` |
| `str_rule15` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-1, §3.6.6 rule 15: the example (`let s = a + b`, `let t = s`, `printf("%s\n", a + b)`) verbatim; `str(i64)` by rule 32; locals released by rule 16 (a) (from 6b each function that LANGUAGE.md 8.6 would inline starts with `while false {}` on its header line, so it keeps its calls; Decision 90) |
| `str_rule26` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-1, §3.6.6 rule 26: `let names = ["a", "bc"]` verbatim (L9 (b), R21's sea_arr_new); an element loop over it (L4, rule 30) |
| `str_rule30` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-1, §3.6.6 rule 30's first example `for a in args() {` verbatim, also rule 35's `rcall sea_args`; `len(args())` (L3) |
| `str_rule32` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-1, §3.6.6 rule 32: `if a < b {` verbatim; `lower`, `len` of a str (L3), `str(bool)` (from 6b each function that LANGUAGE.md 8.6 would inline starts with `while false {}` on its header line, so it keeps its calls; Decision 90) |
| `str_rule33` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-1, §3.6.6 rule 33 and §3.5.9 L16: the `"x" \| "y"` / `_` match verbatim (from 6b each function that LANGUAGE.md 8.6 would inline starts with `while false {}` on its header line, so it keeps its calls; Decision 90) |
| `match_l16` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-1, §3.5.9 L16: multi-pattern arms, `_`, a `_`-only match; owned scrutinees released after the last endif (R11) and before a `break`'s exit (R22) (from 6b the function is inlined by L20: the .hirl/.lir1 show the construct inside the inline xblk/iblk at each call site; Decision 90) |
| `str_l17` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-1, §3.5.9 L17 of a str element by a scalar index: `=` (R17 (a), retained at the store) and `+=` (`bin cat`, R17 (b) move) (from 6b the function is inlined by L20: the .hirl/.lir1 show the construct inside the inline xblk/iblk at each call site; Decision 90) |
| `str_fill_flat` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-1, L2 `filled` with a str value and L10 `.flat` of a `str[,]` with R20 (element count, retain loop) (from 6b the function is inlined by L20: the .hirl/.lir1 show the construct inside the inline xblk/iblk at each call site; Decision 90) |
| `str_ew` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-1, L7 with str operands (Decision 45): element-wise `bin cat` and comparison (sea_str_cmp, `bool[]`) (from 6b the function is inlined by L20: the .hirl/.lir1 show the construct inside the inline xblk/iblk at each call site; Decision 90) |
| `str_l12` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-1, L12 with an L17 target (`(names[i], k) = two(i + 5)`): no `tmp Vv`, est of `lv L1`, R25's move (from 6b each function that LANGUAGE.md 8.6 would inline starts with `while false {}` on its header line, so it keeps its calls; Decision 90) |
| `res_str_consts` | ast res hir1 hir (+ `.out`) | 4g-1, §3.4.2 `rcns` (L-f, L-g): str constants of `+`, one naming another, annotated, rcnb from str comparisons |
| `res_rt` | ast res (+ `.out`) | 4g-2, §3.4.2's example rt.sea verbatim: its documented sea.res (rtst/rtfd, rtfvec, rslit) |
| `res_rtst` | ast res | 4g-2, §3.4.2 type-table order (rtst in sid order with rtfd naming a later id, field/signature/other types); rslit sid 0 (undeclared `Q`, struct name hidden by a local) |
| `struct_rule27` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-2, §3.6.6 rule 27's example verbatim (slit bound in place, scalar field load) |
| `struct_rule18` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-2, rule 18's second example verbatim (`dims[d].nom`); L9 (b) of Dim elements (sea_arr_new_s, slay, R19 in place) (from 6b each function that LANGUAGE.md 8.6 would inline starts with `while false {}` on its header line, so it keeps its calls; Decision 90) |
| `struct_rule29` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-2, rule 29's example verbatim (L15 of an f64 field), L15 of a str field, L2 `filled` of a struct (R19 copy + retains) (from 6b each function that LANGUAGE.md 8.6 would inline starts with `while false {}` on its header line, so it keeps its calls; Decision 90) |
| `struct_l17` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-2, L17 on a struct local: scalar, compound, str field (R17), nested (R24), array-field element (R23), slit into a struct field (rule 27 (d)) (from 6b the function is inlined by L20: the .hirl/.lir1 show the construct inside the inline xblk/iblk at each call site; Decision 90) |
| `struct_l17_path` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-2, L17 through elements of a `ref` root: two-array path (cows, D'/E' from the cow's register, L-n), `ds[i].lim = T{…}` (sc 32 off 16), nested and str fields (from 6b each function that LANGUAGE.md 8.6 would inline starts with `while false {}` on its header line, so it keeps its calls; Decision 90) |
| `struct_cow2` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-2, `a[0].w[0].v[0] = 9.0` after `let b = a` prints `1 9`: three cows (R23) |
| `str_ref_ln` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-2, L-n: `v[i] = "x"` into `ref v: str[]`: the est address is the cow's A, no second ldp (from 6b each function that LANGUAGE.md 8.6 would inline starts with `while false {}` on its header line, so it keeps its calls; Decision 90) |
| `str_fixed_self` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-2, `str[3]`: L10 fix by R20 (`ci 3`), `a[:] = a` (L6 counted self-copy), element store (R17) (from 6b the function is inlined by L20: the .hirl/.lir1 show the construct inside the inline xblk/iblk at each call site; Decision 90) |
| `struct_l6_field` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-2, L6 with a field root `dims[p()].v[q()..3] = 0.0` (rule 19 order, DT from the last cow) (from 6b each function that LANGUAGE.md 8.6 would inline starts with `while false {}` on its header line, so it keeps its calls; Decision 90) |
| `struct_l12` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-2, L12 with `(s.name, k)` and `(ps[0], k)` targets (R25 moves, R19); slit into an existing element; struct tbind (from 6b each function that LANGUAGE.md 8.6 would inline starts with `while false {}` on its header line, so it keeps its calls; Decision 90) |
| `rec_slay` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-2, records (L-m): L9 (b) with the record's slay, L4 over records (R18 address) |
| `inl_half` | hir hirl lir1 (stage-only) | 4h, §3.6.6 rule 37's example as a hand-written two-file `sea.hir` (Decision 55); L18's `tmp`, `iblk`, `iret`, `xblk`; `half` dropped; `.lir1` body byte for byte rule 37's text |
| `inl_nested` | hir hirl lir1 (stage-only) | 4h, L18 (5): a prelude function calling another twice; `sq(hyp(…))`, an inline call as the argument of another (R27 under a `tmp`, no `mov`); blocks 1–7 |
| `inl_void` | hir hirl lir1 (stage-only) | 4h, k = 0 under `eval` (R26): an early `iret 0` in an `if`, the body's `exit B` before `enddo B`; `printf` in the copy with the call's line as site |
| `inl_multi` | hir hirl lir1 (stage-only) | 4h, k = 2 (R27): `tbind` with `_`, `tasg` with a cv 1 component (`itof`) and a `ref` parameter target (`sti`), `tret`; a call of a renumbered program function |
| `inl_loop_ret` | hir hirl lir1 (stage-only) | 4h, R29: an `iret` inside the copy's element loop releases L4's H and the copy's array local before `exit`; shared R1 for both irets; `.i` locals by bind and L4's tmp (R28) |
| `inl_owned_arg` | hir hirl lir1 (stage-only) | 4h, R26/R27: owned `zeros` arguments released after the `mov` of a `bind` and the `mov`s of a `tbind`; an owned result under `eval` (retain in the iret, argument released, then R1) |
| `inl_dest` | hir hirl lir1 (stage-only) | 4h, R27's destinations: `tmp` (nested call), `bind`, `asg set` to a scalar local, to a reference local (`release`, `mov`), to a scalar `ref` parameter (`stf`), an `ifx` arm register (rule 3) |
| `inl_rule12` | hir hirl lir1 (stage-only) | 4h, R30: `cnt(v, grow(ref v))`, v protected by rule 12 (a) (`mov T`, `retain T`, released with the owned tmps); `add(n, bump(ref n))` copies n (rule 12) |
| `inl_scope` | hir hirl lir1 (stage-only) | 4h, R26's `iblk` bound: L16's owned scrutinee tmp in a loop of the copy released at its block's end and by the `iret` leaving it (R11, R22); the enclosing inline `xblk` releases only its owned argument |
| `prel_bincount` | hir hirl lir1 (+ `.out`, `.prelude`) | 4h, Decision 57: one inlined `bincount` from the real prelude: the copy's `filled` (L2), element loop (L4), compound store `c[v] += 1` (rule 19) |
| `prel_meshgrid_tbind` | hirl lir1 (+ `.out`, `.prelude`) | 4h, Decision 57: `let (X, Y) = meshgrid(filled(2.5, 2), ones(3))`: a two-result inline call under `tbind` (R27), owned argument temporaries released after the movs (R26) |
| `res_noprelude_pnames` | ast res | 4h, L-s: with `--no-prelude` `linspace`, `meshgrid`, `setdiff`, `bincount` are `rname … none 0`; `printf`, `len`, `zeros` stay `pd` |
| `opt5_bce_range` | lir1 lir2 lir3 lir | 5c-1, §5.8 T1 with F2/F3: ind of `0..n` over `zeros(n)`, `9..=0 step -1`, `0..10 step 3`, a constant index of `zeros(10)` (deleted); `0..=m` and a repeated check whose F4 candidate is not comparable (kept); T10 retain/release; `.lir3` with T5–T10 (5c-2; renamed from `.lir` by 7b), `.lir` equal to it (7b: `seavec` copies) |
| `opt5_bce_dom` | lir1 lir2 lir3 lir | 5c-1, T1 with F5: `k >= 0`, `k < 8` on a parameter (L, U), the negation in an `else` part (deleted), `k < 8` alone (kept), a non-symbol `i * 3` narrowed by two tests (deleted); `.lir3` with T5–T10 (5c-2; renamed from `.lir` by 7b), `.lir` equal to it (7b: `seavec` copies) |
| `opt5_bce_sym` | lir1 lir2 lir3 lir | 5c-1, T1 with L-au (two symbols compared through their constant bounds): `0 <= k < 8` over `zeros(8)` with the extent loaded outside every loop (deleted); `k < 8` over `zeros(n)` (kept); `0 <= k < 7` in a loop against `n >= 8` from an `if` (deleted inside it, kept after it); `.lir3` with T5–T10 (5c-2; renamed from `.lir` by 7b), `.lir` equal to it (7b: `seavec` copies) |
| `opt5_bce_passed` | lir1 lir2 lir3 lir | 5c-1, T1 with F4: a passed check proves the same index on the same array (deleted), not on another (kept); T3 shares a private base's loads; `.lir3` with T5–T10 (5c-2; renamed from `.lir` by 7b), `.lir` equal to it (7b: `seavec` copies) |
| `opt5_bce_kept` | lir1 lir2 lir3 lir | 5c-1, T1: `v[i ± 1]` over `1..n` (adds made wrapping, checks kept), `0..=n`, the repeated checks of a `ref` array element (rule 19); `.lir` (5c-2): `edges`'s `v[i ± 1]` reduced (T7); `grow` versioned on the memory form (L-bs), its loads hoisted in the fast copy |
| `opt5_bce_scope` | lir1 lir2 lir3 lir | 5c-1, F3/F6: a guard's non-emptiness used inside its loop, not after its `endif`; two `break` tests narrowing j inside a `do`, unknown after it; `.lir3` with T5–T10 (5c-2; renamed from `.lir` by 7b), `.lir` equal to it (7b: `seavec` copies) |
| `opt5_ovf` | lir1 lir2 lir3 lir | 5c-1, T1: `iaddc`/`inegc`/`imulc`/`isubc` made wrapping (`i + 1`, `-i`, `i * 3`, `i - 1`, `n + 1` under `n < 100`) and kept (symbolic product, `0..=n`, up to 2⁶³ − 1, `n * 2`); `.lir3` with T5–T10 (5c-2; renamed from `.lir` by 7b), `.lir` equal to it (7b: `seavec` copies) |
| `opt5_div` | lir1 lir2 lir3 lir | 5c-1, T2: `%`/`idiv` by 1, 8, 10 (M < 2⁶³), 3 (s = 0), 2147483647 (M ≥ 2⁶³); −3, 0, b, `i + 1` unchanged; T3 shares the sequences; `.lir3` with T5–T10 (5c-2; renamed from `.lir` by 7b), `.lir` equal to it (7b: `seavec` copies) |
| `opt5_fdiv` | lir1 lir2 lir3 lir | 5c-1, T2: `f64` division by 4.0, 0.5, −2.0, 2¹⁰²³ (subnormal reciprocal), 2⁻¹⁰²² made `fmul`; 3.0, 2⁻¹⁰⁷⁴, a variable unchanged; `.lir3` with T5–T10 (5c-2; renamed from `.lir` by 7b), `.lir` equal to it (7b: `seavec` copies) |
| `opt5_vn` | lir1 lir2 lir3 lir | 5c-1, T3 rule 1 and copy propagation (a chain in one pass); an equal instruction whose result is overwritten between (not shared); `.lir3` with T5–T10 (5c-2; renamed from `.lir` by 7b), `.lir` equal to it (7b: `seavec` copies) |
| `opt5_rle` | lir1 lir2 lir3 lir | 5c-1, T3 rule 2: header loads, a `ref` scalar read back from its store and across a call (private location), an element load not shared across the call; `.lir3` with T5–T10 (5c-2; renamed from `.lir` by 7b), `.lir` equal to it (7b: `seavec` copies) |
| `opt5_ifconv` | lir1 lir2 lir3 lir | 5c-1, T4: `isel`/`fsel` from if/else, if and ifz (`\|\|`) of one `mov`; parts that are not one `mov` kept; `.lir3` with T5–T10 (5c-2; renamed from `.lir` by 7b), `.lir` equal to it (7b: `seavec` copies) |
| `opt5_clean` | lir1 lir2 lir3 lir | 5c-1, T10: unused pure values and loads, `mov R R`, an emptied `if`, retain/release; a check and a checked add kept; `s` read only by its own add deleted (L-bn); `.lir3` with T5–T10 (5c-2; renamed from `.lir` by 7b), `.lir` equal to it (7b: `seavec` copies) |
| `opt5_bce_eq` | lir1 lir2 lir3 lir | 5c-1, F5 `eq`/`ne` and their negations: `v[k]` under `k == 5` (deleted); after it, the missing else part's `k != 5` gives a symbol nothing (kept); the else part of `k != 5` (deleted); an `\|\|` evaluated in an `ifz` part where `k == 5` (deleted); `if j == 7 { break }` leaving j ≤ 6 from [0, 7] (deleted); `.lir3` with T5–T10 (5c-2; renamed from `.lir` by 7b), `.lir` equal to it (7b: `seavec` copies) |
| `opt5_ovf_const` | lir1 lir2 lir3 lir | 5c-1, T1 with L-bb 6: under `0 <= k < 10`, `m + k` becomes `iadd` for m = 80000000000, 2⁵², −2⁵²; for 2⁵² + 1 and −2⁵² − 1 (unknown interval) it stays `iaddc`; `.lir` (5c-2): T8 hoists; T9 splits on `k >= 0`, then only the `k >= 0` copy on `k < 10` (L-bt, three copies); constants and adds placed in the first copy's arm |
| `opt5_dead` | lir1 lir2 lir3 lir | 5c-1, L-bb 3: records after `break`, after a `return` in an `if` and after the last `return`, up to the end of their part, unchanged (no T3 sharing of the duplicates, no T10 deletion); the live duplicate before the last `return` shared by T3; `.lir3` with T5–T10 (5c-2; renamed from `.lir` by 7b), `.lir` equal to it (7b: `seavec` copies) |
| `opt5_promote` | lir1 lir2 lir3 lir | 5c-2, §5.8 T5: a `ref` scalar and struct slot fields promoted; read-only pre-loads; a `ref` passed to a call kept |
| `opt5_promote_exit` | lir1 lir2 lir3 lir | 5c-2, T5: post-stores before a `ret` in the inner loop and after the closing record (`break`); no re-promotion after promotion in the enclosing loop; a slot whose `sa` is in the outer loop |
| `opt5_cow` | lir1 lir2 lir3 lir | 5c-2, T6 register form: two arrays (`iand`), an alias used only as a base, an outer loop versioned |
| `opt5_cow_ref` | lir1 lir2 lir3 lir | 5c-2, T6 memory form at a `ref` array's (p1, 0); T3's `mov` counts as part of the cow (L-bs), so both loops are versioned and the fast copies' loads of v hoisted (T8) |
| `opt5_cow_kept` | lir1 lir2 lir3 lir | 5c-2, T6 kept when the array or a copy is passed to a call; the inner loop versioned |
| `opt5_sr_unit` | lir1 lir2 lir3 lir | 5c-2, T7 unit stride: offsets ±8, invariant terms ±, 2-D `bool` and `f64` columns; checked chains kept |
| `opt5_sr_stride` | lir1 lir2 lir3 lir | 5c-2, T7 invariant stride: constant k with the start folded (also `step 2`), a non-constant start, a register k from start 0 and from a register start; T8 commoning |
| `opt5_licm_hdr` | lir1 lir2 lir3 lir | 5c-2, T8 (b): header loads hoisted from an `if` part; an array written in the loop kept |
| `opt5_licm_param` | lir1 lir2 lir3 lir | 5c-2, T8 (a): a parameter base hoisted only when anticipated |
| `opt5_unswitch` | lir1 lir2 lir3 lir | 5c-2, T9: four copies, renumbering (L-bl), placement (L-bm) |
| `opt5_lcg` | lir1 lir2 lir3 lir | 5c-2: W5's `lcg_fill`; the `.lir` loop is §5.8's text |
| `opt5_sor` | lir1 lir2 lir3 lir | 5c-2: W4's SOR on a 5 × 6 grid; T6, T8, T7, T8, T9 with four copies, each copy's pointers placed in its own arm |
| `res_err_predeclared` | ast res | §3.4.1: `rerr 212`; the item is entered (`rfn`) and `sqrt` resolves to it (`rname fn`) |
| `res_err_redef_item` | ast res | §3.4.1: `rerr 235` at the later `const`; it is copied with its names unresolved |
| `res_err_elemental` | ast res | §3.4.1: `rerr 259 elemental functions` at `elemental`; `rfn` el 1 (6c: re-derived without the rerr, see the 6c passes rows below) |
| `res_err_param_redef` | ast res | §3.4.1: `rerr 235` at the second parameter `a` |
| `res_err_param_shadow` | ast res | §3.4.1: two errors at one `param` (213 and default arguments): the first found, 213, is the `rerr` |
| `res_err_default` | ast res | a default is a resolved region: K resolves to `rname cst 1` of the constant that follows; no rerr (Decision 91) |
| `res_err_str_param` | ast res | §3.4.1, re-derived by 4g-1: the `str` parameter is typed in its `rfn`; no `rerr` |
| `res_err_str_result` | ast res | §3.4.1, re-derived by 4g-1: the `str` result type is typed in its `rfn`; no `rerr` |
| `res_err_array` | ast res hir1 | §3.4.2, §2.6.2 step 4e: `fn f(v: f64[3], k: i64)`; in 4d the fixed-size type was `rerr 259 arrays`; from 4e `seaname` resolves it (`rtfvec`), so the `.res` holds no `rerr` and the test gains a `.hir1` (§6.2: a `.res` without `.hir1` is a program whose `sea.res` holds an `rerr`); rewritten by `vectors/dump4e_cases.py` |
| `res_err_handle` | ast res | §3.4.1: `rerr 259 handle types` at the `type` node |
| `res_err_unknown_struct` | ast res | §3.4.1: `rerr 229` at the `type` node of an undeclared type name |
| `res_err_first_pos` | ast res | §3.4.1: two `seaname` errors: the signature error, from 4g-1 (L-i) `rerr 229` at the `type` node of an undeclared struct type `Q`, found after the item error at 6:1, is first in source order and is the `rerr` |

Every test above that has a `.hir1` also has a `.res` (phase 4a, §6.2), the stage input of `seacheck` and the golden output of `seaname`; each is derived from its `.ast` by `vectors/res_gen.py`, which cross-checks it against the `.hir1` (the lids of the `loc` records, the constants' values, the `powk` positions).

From sub-phase 4e-0 every test above that has a `.sea` and a `.lir1` also has a `.hirl` (§6.2), the golden output of `sealoop` (`.hir` → `.hirl`) and the stage input of `sealower` (`.hirl` → `.lir1`); `stage.sh` checks each pair, so a hand-written `.hirl` is checked from both sides. A `.hirl` with neither `.sea` nor `.hir` would be a `sealower`-only test on hand-written `sea.hirl` (none yet; they come with 4e), skipped by the `sealoop` pair.

Every function in a `.lir1`/`.lir` test has a loop or is recursive and has two or more call
sites, so LANGUAGE.md §8.6 requires no inlining (§3.6.6). Only `lx.lir` is pinned for pass 3b
(§3.6.5: the other loop bodies hold constants that a later pass 3b may hoist).

## passes/ rows of sub-phase 6b (T2's tests, handed to T1)

T2 (`vectors/dump6_cases.py`, `passes/{inl6_,res6_}*`, the 21 lowering dump tests treated by Decision 90, `res_err_default.res`
and the `.res`, `.hir1` and `.hir` goldens that `el` 2 and the kind `inl` change; DESIGN.md §6.2, §8 row 6b) reports its
rows to T1, who alone edits this file; they are entered here, in the table format of `## passes/` above, when T2 hands them over.
T2 handed over its rows; they follow.

| Test | Files | Spec (DESIGN.md unless noted) |
|------|-------|-------------------------------|
| `res6_default` | .sea .ast .res | 6b: a parameter default is a resolved region (DESIGN 3.4.1, Decision 91): a constant name (`rname cst`), `pi` (`rname pd`), `pi ^ 2` as `rpowk 2`; no outcome record; the function el 2 (8.6 (c)) |
| `res6_class` | .sea .ast .res | 6b: rfn's el is the 8.6 class (DESIGN 2.11.3): el 1 elemental, el 2 one call site (with a loop), el 0 a loop with two sites one in a never-reached function, el 2 a function with no site, el 2 / el 0 at 50 / 51 statements (if-else-if-else chain 1, bare block 1), el 0 a recursive pair; carried rerr 259 `elemental functions` until 6c (re-derived without it, see the 6c passes rows below) |
| `inl6_count50` | .sea .ast .res .hir1 .hir .hirl .out | 6b: LANGUAGE.md 8.6 (c) at its limit: a function of 50 statements (if-else-if-else chain 1, bare block 1 plus its statement) with two call sites is kind inl and both calls are inlined by L20 in the .hirl (DESIGN 2.11.3, 2.11.4, L-ci) |
| `inl6_count51` | .sea .ast .res .hir1 .hir .hirl .out | 6b: the same function with 51 statements stays a call (kind fn; the .hirl is the .hir) |
| `inl6_basic` | .sea .ast .res .hir1 .hir .hirl .lir1 .out | 6b: el 2 / kind inl; L20's inline xblk with the copied nodes' own positions (sites of the callee's line), R27 (a bind destination's mov after enddo, an operand taking R1), the inlined function dropped and the next renumbered (L-cg) |
| `inl6_ref` | .sea .ast .res .hir1 .hir .hirl .lir1 .out | 6b: R31: a `ref` scalar parameter of an inlined function (the rarg's slot and store, reads and the compound store through the ref local, the reload after enddo), the rule-12 copy of a read before the inline call, the eval form |
| `inl6_agg` | .sea .ast .res .hir1 .hir .hirl .lir1 .out | 6b: R32: a struct result of an inlined function (the home H before do, the iret's store of the literal's home into H by rule 27 (d), the field read from H) |
| `inl6_seq_named` | .sea .ast .res .hir1 .hir .hirl .out | 6b: named arguments out of parameter order (3.5.5 "Evaluation order", L-cp): the seq of .t temporaries in source order, as the mask tmp of an L6 store (R11's seq case through sealoop) |

## passes/ rows of sub-phase 6c (T2's tests, handed to T1)

T2 (`vectors/dump6c_cases.py`, `passes/elem6_*`, `res_err_elemental.{sea,res}` and `res6_class.res`; DESIGN.md §6.2, §8 row 6c).

| Test | Files | Spec (DESIGN.md unless noted) |
|------|-------|-------------------------------|
| `elem6_vec` | .sea .ast .res .hir1 .hir .hirl .lir1 .out | 6c: an elemental function (el 1, kind `elem`) called with a vector and a scalar (an array-typed `call` in .hir1, an `emap` of `inst 1` in .hir, §3.5.3, §3.5.7 step 3) and with two scalars (an ordinary call); .hirl: L19 with k = 1 (the argument `tmp`s, the extent, the result's `anew`, the data loads, loop(N; I) whose body stores the L20 inline call by `est`, value `lv R1`) and L20 of the scalar call; the elemental function dropped (L-cg); .lir1 by hand (rule 22's loop, R26/R27's `do`/`enddo` in the loop body, R27's `mov` into a bind destination) |
| `elem6_k5` | .sea .ast .res .hir1 .hir .hirl .out | 6c: an elemental function of five results (W1's shape) applied to a vector: one instance shared by three emaps; .hirl: L19 with L11's statement forms for k = 5: a `tbind` with two `_` (no array allocated for them, the kept results bound from the Rj in place in the block), a `tasg` with three `skip` (a new block, the stores in target order), an `eval` (every result discarded: no allocation, the loop body the inline call as an `eval`); the k >= 2 loop body a block beginning with a `tbind` of `.l` locals then the `est`s (Decision 84) |
| `elem6_inst` | .sea .ast .res .hir1 .hir .hirf .out | 7c (Decision 97, L-fb list below): a subject test, its `.sea` gains a `printf` of one element after each of `r1` … `r4` (no F2 group forms) and `.out` the lines `4`, `6`, `0`, `3`; `.ast .res .hir1 .hir` regenerated by the unchanged passes; `.hirf` re-derived (`r2` and `r3` are F1 with an F5 root, `r3` with a folded `.col`; `r1`, `r4`, `r5` keep L19's form). 6c: pass 2b's step 3: four instances numbered by first use; an `i64[]` argument under a `cvt` to `f64[]` sharing instance 1 with an `f64[]` argument; a matrix with a `.col` view (a matrix result); a fixed-size vector with a scalar (a fixed-size result) and with a dynamic vector (a dynamic result); the uniform `str` argument unchanged; a scalar call kept as a call; an unreachable elemental function dropped (step 5); the instances' types numbered first in sea.hir's table (§3.5.1) |

Changed rows (6c):

| Test | Files | Spec |
|------|-------|------|
| `res_err_elemental` | ast res | 6c: an `elemental fn` item is accepted (§2.11.2): no `rerr`; `rfn` el 1 (§3.4.1); before 6c it carried `rerr 259 elemental functions` |
| `res6_class` | .sea .ast .res | (as in 6b, its last clause now) the rerr 259 `elemental functions` is gone from 6c (§2.11.2) |

## passes/ rows of sub-phase 6d (T2's tests, handed to T1)

T2 (`vectors/dump6d_cases.py`, `passes/json6_*`; DESIGN.md §6.2 "6d, write_json", §8 row 6d).

| Test | Files | Spec (DESIGN.md unless noted) |
|------|-------|-------------------------------|
| `json6_struct` | .sea .ast .res .hir1 .hir .hirl .out | 6d: `write_json` of a struct with `f64`, `i64`, `bool`, `str`, fixed `f64[3]` and dynamic `f64[,]` fields: .hir1 `lib P 1 write_json 2` under an `eval` (§2.11.2); .hir: §3.5.7 step 4's block (`bind .j1` the path, `bind .j2` the value, `jopen`, `jobj`, a `jkey` and a `jval (fld …)` per scalar field, `jvec (dyn (fld …))` for the fixed field (L-ce; the new `f64[]` type numbered by §3.5.1), `jmat`, `jend`, `jclose`); .hirl: the `j*` records kept, the `dyn` rewritten by L10 (`xblk` of `tmp S/R/A/D/N`, `mcpy`), L9 (a) of the fixed literal, `tptr` appended (§2.11.4, §3.5.9) |
| `json6_vecstruct` | .sea .ast .res .hir1 .hir .hirl .lir1 .out | 6d: `write_json` of a vector of structs: .hir `jarr`, `fore .j3` over the value whose body is the struct's `jobj … jend`, `jend`; .hirl: L4 of that `fore` (`bind H`, the loop variable `tmp .j3 = eld P S 48 0`, R18); .lir1 by hand: rule 39's rows for every `j*` record and every `jval` entry (`sea_json_open … sea_json_close`, entries 27–38: `rcall <sym> <site> 0 <na> …`, a `jkey`'s `la` of a new `str` record, borrowed field operands neither retained nor released), the `.j` locals' binds and releases (rules 2, 15 (a), 16 (a)), rule 30's held vector |
| `json6_matstruct` | .sea .ast .res .hir1 .hir .hirl .lir1 .out | 6d: `write_json` of a matrix of structs: .hir the guard of L-cv (`if (rows(e) == 0 \|\| cols(e) == 0) { jarr; jend } else { jarr; forr R { jarr; forr C { … idx e R C … }; jend }; jend }`), the inner `C` `.j3` and the outer `R` `.j4` (declaring records in file order, §3.5.4), the ranges' `i64[]` type; .hirl: `rows`/`cols` as `ext` (L3), the `forr`s and scalar `idx`es kept; .lir1 by hand: rule 3's `\|\|`, rule 4's `forr`s, rule 18's struct-element field reads (each `fld (idx …)` re-reading and re-checking the element), rule 39 |

## passes/ rows of sub-phase 7c (T2's tests, handed to T1)

T2a (`vectors/dump7_cases.py` part 4, `passes/fuse7_*`; DESIGN.md §6.2 "`fuse7_*` dumps", §2.12.3, §2.12.4, §8 row 7c): each `NAME.sea` written by hand, `.ast .res .hir1 .hir` from the unchanged passes 1–2b, `NAME.hirf` by `dump7_cases.py`'s transcription of F1–F5 (which rewrite applies to which statement decided by hand, its table `FUSE7`; readings R-a … R-j there), `NAME.hirl` and `NAME.lir1` by the unchanged `sealoop` and `sealower` from `NAME.hirf`, `.out` from LANGUAGE.md. `fuse7_prel` is built with the prelude (`NAME.prelude`) and has no `.ast` or `.res`.

| Test | Files | Spec (DESIGN.md unless noted) |
|------|-------|-------------------------------|
| `fuse7_f1_vec` | .sea .ast .res .hir1 .hir .hirf .hirl .lir1 .out | 7c, F1 on a vector tree of two fusible nodes (`x * 2.0 + x`): one leaf and check phase (each leaf a `tmp`, the add node's shape check), one result, one loop |
| `fuse7_f1_mat` | .sea .ast .res .hir1 .hir .hirf .hirl .lir1 .out | 7c, F1 (4) on a dynamic matrix tree (`A * 2.0 + A`): the plain copy (one linear loop over R·C, L-eo) and the broadcast copy (`mloop` with L7's strides) under the quiet test `Pl` (L-ep) |
| `fuse7_f1_fixed` | .sea .ast .res .hir1 .hir .hirf .hirl .lir1 .out | 7c, F1 (4) on a fixed-size matrix tree (`F * 2.0 + F`): no leaf can broadcast, so no test and no broadcast copy, only the plain copy into the home |
| `fuse7_f1_mat1` | .sea .ast .res .hir1 .hir .hirf .hirl .lir1 .out | 7c, "Which trees `seafuse` rewrites" (Decision 111): a matrix tree of one fusible node (`A * 2.0`) is rewritten (plain and broadcast copies), not left to L7 |
| `fuse7_f1_asg1` | .sea .ast .res .hir1 .hir .hirf .hirl .lir1 .out | 7c, F1 (3) with F2 (6) (Decision 111): a one-node `asg set` value to a whole array, `y = y * 2.0` written into y's own buffer after the reuse prologue (`cow` under the test E, the old value held in O and read through it, R33) |
| `fuse7_f1_sel_inplace` | .sea .ast .res .hir1 .hir .hirf .hirl .lir1 .out | 7c, F1 (3), (4), (5): a selection store whose tree does not read the target, stored in place (L6 steps 2–7 after the value's leaf and check phase, the element computed in the selection's nest, no result array) |
| `fuse7_f1_sel_res` | .sea .ast .res .hir1 .hir .hirf .hirl .lir1 .out | 7c, F1 (5): the tree reads the target's root shifted (`v[0..2]` stored to `v[1..3]`), so it is computed into RES first (fused, a folded range leaf, F4) and stored by L6 |
| `fuse7_f1_barrier` | .sea .ast .res .hir1 .hir .hirf .hirl .lir1 .out | 7c, F1 (2): the `i64` product `a * 2` is a failing node that is not the root, so a barrier (a leaf, rewritten by L7 later); the conversion and the add are fused |
| `fuse7_f2_group` | .sea .ast .res .hir1 .hir .hirf .hirl .lir1 .out | 7c, F2 (2), L-eq: a group of two independent statements over vectors of different lengths: no check added, the quiet space test fails at run time and the split copy runs each statement's own nest; both locals stored (read after the group) |
| `fuse7_f2_end` | .sea .ast .res .hir1 .hir .hirf .hirl .lir1 .out | 7c, F2 (3), (4), L-er, L-es: `a` and `b` form a group (`b` reads `a` at the same element from the scalar E1); `c` reads `b` through a selection, which ends the group (`c` fused alone); `a` never stored (its `bind` dropped, R34), `b` stored |
| `fuse7_f2_reuse` | .sea .ast .res .hir1 .hir .hirf .hirl .lir1 .out | 7c, F2 (6): a group whose second statement assigns a whole `var` array: its reuse prologue (the test E, `cow`, the old value O, the fallback `anew`) and the nest storing into y's buffer; `a` never stored |
| `fuse7_f3_sum` | .sea .ast .res .hir1 .hir .hirf .hirl .lir1 .out | 7c, F3: `sum` of a tree: the tree's leaf and check phase, then L13's sum8 with X(K) the element expression (no temporary array) |
| `fuse7_f3_max_mask` | .sea .ast .res .hir1 .hir .hirf .hirl .lir1 .out | 7c, F3, F4, L-et: `max` over a tree whose leaf is a mask selection `x[m]`: IX 1–3 of the mask (its count), `EMPTY_REDUCE`, then one loop under the mask's `if` |
| `fuse7_f3_argmax_mask` | .sea .ast .res .hir1 .hir .hirf .hirl .lir1 .out | 7c, F3, L-et: `argmax` over a same-mask selection returns the position in the selection, counted by Q (v = [9, 1, 5], m = [false, true, true]: 1) |
| `fuse7_f4_flat` | .sea .ast .res .hir1 .hir .hirf .hirl .lir1 .out | 7c, F4: `A.flat` folded into the nest (§3.5.9 "Folded views": the extent R·C, k mapped to k), no materialized view |
| `fuse7_f4_t` | .sea .ast .res .hir1 .hir .hirf .hirl .lir1 .out | 7c, F4, L-eo: `F.T` of a fixed-size matrix folded (the extents swapped, (i, j) read at lin(j, i, X1)); one copy, an `mloop` since a leaf is folded |
| `fuse7_f4_range` | .sea .ast .res .hir1 .hir .hirf .hirl .lir1 .out | 7c, F4: a range selection `x[1..4]` folded: IX 1 and IX 2 in the leaf phase, read at lo + I·st |
| `fuse7_f4_idxvec` | .sea .ast .res .hir1 .hir .hirf .hirl .lir1 .out | 7c, F4: an index vector `x[k]` folded: its `chkb` loop in the leaf phase, the element read through the vector's element (an indexed load) |
| `fuse7_f4_cat` | .sea .ast .res .hir1 .hir .hirf .hirl .lir1 .out | 7c, F4 "Concatenation parts", L-eu: the part `x[1..3]` copied from its base in L9 (c)'s copy pass (IX 1, IX 2 at the part's place), never materialized |
| `fuse7_f5_tree` | .sea .ast .res .hir1 .hir .hirf .hirl .lir1 .out | 7c, F5: an elemental application inside a tree (`f(x, 2.0) + 1.0`) is a fusible node: its element is the per-element call of L19 (4), inlined later by L20 |
| `fuse7_inl` | .sea .ast .res .hir1 .hir .hirf .hirl .lir1 .out | 7c, §2.12.3 (Decision 110 as amended, L-fo): `g` (one call site, inlined by L20) has its body fused by `seafuse`; L20 copies the `HL` records, each `.l` local of `g` a new `.l` local of the caller |
| `fuse7_prel` | .sea .hir .hirf .hirl .lir1 .out .prelude | 7c, §2.12.1, §2.12.4: a prelude call (`linspace`) is a leaf of the fused tree (no fusion through prelude calls); L18 inlines it inside the leaf's `tmp`; `linspace`'s body holds no construct `seafuse` rewrites |

**Goldens that phase 7 changes (L-fb, Decision 97; sub-phase 7c, T2b).** Only these existing dump goldens change in 7c, each by the rule named (DESIGN.md §2.12.4 unless noted); no `.lir2`, `.lir3` or `.lir` golden changes in 7c (T11–T13 are 7e's):

| Test | File | Change | Rule |
|------|------|--------|------|
| `ew_colrow` | `.hirf` (new) | `let P = a.col * b.row` rewritten by `seafuse`: `a` and `b` folded leaves (no L10 `anew`/`mcpy`); leaf and check phase with L7 (2)'s matrix checks at the `bin`; RES `anew` at the root; data loads; the plain test `Pl`; plain copy: `mloop` reading `.col` at I and `.row` at J; broadcast copy: L7 (4)'s strides, then `mloop` | F1 (1)–(4), (6); F4 (`.col`, `.row`, rule 28's maps); Decision 111 (folded leaf, matrix space); L-eo; L-ep |
| `ew_colrow` | `.hirl`, `.lir1` | re-derived from the `.hirf` by the unchanged `sealoop` (L2, L3 on the other statements; `.l` and `tptr` renumbered in file order) and the unchanged `sealower` | Decision 109, L-fn; §3.6.6 "Lowering of the `sea.hirl` records" |
| `ew_colrow` | `.sea` | trailing comment only (AST unchanged) | — |
| `sel_reads` | `.hirf` (new) | `let M = A > 5.5` (line 7) rewritten: plain copy `NN = R*C`, then loop(NN; I) (no folded leaf); broadcast copy: `tmp O`, L7 (4)'s strides, then `mloop` | F1; Decision 111 (one-node matrix tree); L-eo; L-ep |
| `sel_reads` | `.hirl`, `.lir1` | re-derived as for `ew_colrow` | Decision 109, L-fn; §3.6.6 |
| `sel_reads` | `.sea` | trailing comment only (AST unchanged) | — |
| `elem6_inst` | `.sea`, `.out` | a subject test (one of 6c's `elem6_*` L19 dumps): a `printf` of one element follows each of `r1` … `r4`, so no F2 group forms; `.out` gains the 4 lines `4`, `6`, `0`, `3` | Decision 97 / §2.12.10 subject rule; F2 (1) |
| `elem6_inst` | `.ast`, `.res`, `.hir1`, `.hir` | regenerated by the unchanged passes 1–2b (positions after line 17 shift) | — |
| `elem6_inst` | `.hirf` | `r1`, `r4`, `r5` keep L19's form as 7b wrote it; `r2 = h(k, 2.0, "u")` has two fusible nodes (`cvt`, `emap`): F1 with an F5 root, `cvt` and `call` in the element body; `r3 = h(m, a.col, "u")` has a matrix space and a folded `.col`: F1 with an F5 root, plain copy (`mloop`) and broadcast copy; a new `tptr 15 3` (the `i64` data of `k`) | F1, F4, F5; Decision 111; L-eo; L-ep |

Every other dump golden is unchanged, for these reasons (T2b's review of all 92 tests with a `NAME.hirl` and the other dump tests): no fusible node with an array operand, folded view or selection in a tree, reduction of a tree or `emap` (the scalar and leaf-only tests, `opt5_*` included); `dyn`, `fix` and `ifx` of arrays are leaves (`arr_dynfix json6_struct struct_cow2 lib_sort_fixed str_fixed_self loop_ext loop_fore_exits`); selection stores of a scalar value (`arr_rule21 sel_ref_store inl6_seq_named struct_l6_field`, the compound `sel_compound`); `arr_rule22` a one-node vector `let` left to L7 (L-em) with an ungroupable neighbour; `arr_rule28` a scalar element read through rule 28; `arr_rule20` a bare selection; `arr_views` two bare views of different ranks; `lib_rule23 lib_max lib_mean_i64 lib_nnz lib_variance` reductions of a whole-array `lv` (F3 needs a tree, a `.flat` or a mask selection), `lib_sum_dim0`/`lib_sum_dim1` with `dim:`, `lib_find lib_find_first lib_rule24` not fusible; `ew_ind2sub` (`ind2sub` with a scalar `r`, L11's form); `str_ew`, `str_fill_flat` (`str` nodes are not fusible); `elem6_vec`, `elem6_k5` (lone `emap`s keep L19's form, ungroupable neighbours); `prel_bincount`, `prel_meshgrid_tbind` (no tree in the prelude bodies). Implementer readings behind these (T2b's R-T2b-1 … R-T2b-6, agreeing with T2a's R-a, R-b, R-d, R-i in `dump7_cases.py`): a bare leaf is not an element-wise tree; a group has one rank; `ind2sub` with a scalar `r` is not a fusible node; each extent of a folded `.col`/`.row` is a `tmp` loaded at its node; a matrix space with a single dynamic leaf keeps the always-true `Pl` and the dead broadcast copy as written (`sel_reads`); `elem6_inst` is a subject test, rewritten rather than given F2 groups.

## accept/ (DESIGN.md §6.3, run by `tests/accept4.sh`)

| Test | Spec |
|------|------|
| `w4_sor` | `.keys` `it_sor,T_max`, `.wl` `w4_heat_plate`: W4's scalar SOR (grid, channel, source, boundary values, lexicographic SOR with the max-change test, the hot spot by a scalar loop over the unknown nodes), the JSON subset written with `%d`/`%.17g`; MATLAB's two configuration checks are not ported (`error` is 4g; this grid never trips them) |
| `w5_stats` | `.keys` `first_dev,mean_cold,std_cold,hist_counts`, `.wl` `w5_tolerance_mc` (4h, lead decision L-aa): LANGUAGE.md Appendix D verbatim for the four keys (the `Dim` struct and table, the inputs, the validation `match`, the sampling loop, `uTop` and `Top`, `stack_gap`, `lcg_fill`, `muC`, `sdC`, `binW`, `bin`, `inRange`, `counts` by `bincount`), then the JSON subset with `%.17g`/`%d`, `first_dev` as 10 rows of 7; generated by `vectors/prel4h_cases.py` |

## errors/

Every C1 code 101–114 (and the driver's 100), the C2 codes that phase 1 can reach (204–208,
216–222, 224, 225 cannot occur in phase 1, DESIGN.md §2.6.2), the phase rule (259) for every
construct word, capacity code 400 (`parameters`, `nesting` per the depth definition of §2.7),
and the phase-1 run-time errors (codes 4, 5, 6, 7, 15, 17). Pass-2 errors of all kinds are
reported in plain source order (§2.6.2). The column of each compile error is
the `at` position of DESIGN.md §2.6.2.
From sub-phase 4e (DESIGN.md §2.6.2 step 4e) the `arrays` word is gone: the ten 4d goldens that
expected it (`err_ns_arr_{all_index,cvt,elem_arg,ew,fixed_local,max2,range_index,view}`,
`err_ns_array_literal`, `err_ns_array_type`) are replaced by the 4e tests of the same constructs
(`programs/`) and of their v1 errors: run-time selection, shape, conversion, range and
concatenation errors, the static `shape mismatch` (217) of DESIGN.md §3.5.5, 201, 202, 218, 219,
220, 239, 252 and 257 at array constructs, and the words that remain (`strings` for a `str` literal
and a fixed-size `str` type, `max` of one argument, `ind2sub` with an array first argument). A
fixed-size type or literal of struct elements cannot be tested on its own before 4g: its `struct`
item is reported first (`structs` at the item, by `seaname`).
From sub-phase 4f (DESIGN.md §2.6.2 step 4f, "Readings fixed by 4f") the reductions, `sort`, `argsort`, `find`, `find_first`, `find_last` and the options `dim:` and `desc:` are implemented: the goldens `err_ns_lib_sum`, `err_ns_lib_max1`, `err_ns_lib_max1_fixed` and `err_ns_lib_min1` are retired (their calls are `programs/red_former_ns`), and the 4f tests below cover the run-time errors `integer overflow` of a checked `i64` sum (also inside `mean`, `variance` and a `dim:` form) and `%s of an empty array`, error 115 of pass 1 (also before an earlier pass-2 error), 225 at the second `narg`, a `dim:` value's 201, 237 and 262 in that order and before the call's 243, the `name: T` spelling of 243, the phase-rule word `named arguments` for a name the function does not take (`argmax(A, dim: 0)`; a repeated one at its first `narg`), and 217/201 for the fixed-size results of Decision 39. `err_ns_named_arg` (a named argument of a user function) stayed until 6b, which retired it.
From sub-phase 4g-1 (DESIGN.md §2.6.2 step 4g-1, "Readings fixed by 4g") strings, `match`, `error`, `args`, `str()` and `lower()` are implemented: the goldens `err_ns_string_let`, `err_ns_string_type`, `err_ns_str_literal`, `err_ns_arr_str_elem` and `err_ns_match` are retired (their constructs are `programs/str_basic`, `str_arrays` and `match_basic`), and `err_const_noval_calltype`, `err_const_noval_errtype` and `err_const_noval_shortcircuit` keep their intent with an undeclared struct type `Q` in place of `str` in the faulty result type (`unknown struct type`, 229, at the same `type` node, lead decision L-i). The 4g-1 tests below cover 201 (a `str` binding, a `match` scrutinee), 240 and 241 on `str` operands, 207 (no `_`, `_` not last, no arm, before a scrutinee error: L-a), 208 (within an arm, across arms, after `_`, a second `_`), 233, 210 and 211 for `error`, 243 for `lower`, `str` of an array and `args` (L-d), `missing return` after `error`, `program too large: strings` for a `str` constant value or part over 4 096 bytes (L-f), the word `strings` for a fixed-size `str` type, and the run-time errors of `error` (flushed output, a function, formatting, a `_` arm), `args()[0]` without arguments and an element-wise `str` shape mismatch. `str()` without an argument is a syntax error (`unexpected token ')'`, LANGUAGE.md Appendix A: `conv_type "(" expr ")"`). `err_ns_str_fixed_type`, `err_ns_struct` and `err_ns_record` stay until 4g-2.
From sub-phase 4g-2 (DESIGN.md §2.6.2 step 4g-2, "Readings fixed by 4g") structs, records, projection and fixed-size `str` and struct arrays are implemented: the goldens `err_ns_struct`, `err_ns_record`, `err_ns_str_fixed_type` and `err_ns_str_fixed_let` are retired (their constructs are `programs/struct_basic`, `records` and `str_fixed`). The 4g-2 tests below cover 204, 205, 206 at struct literals, 205 and 222 in a record literal (L-b, at the `init`), 221 (direct, through `P[]`, through `P[2]`, mutual: the first struct in source order), 222 and 235 in a declaration, 229 at a literal, 238 (a field of a `let` struct, an element's field of a `let` array, naming the root), 239 (a projection target), 240 (`p == q`), 249 (a struct, a record spelled `{a: i64, s: str}`, a matrix of structs `P[,]`, L-c), 256 (an array field, a struct field), 201 (a record where a struct is expected, also with the struct's field names), and the run-time check of a `str[3]` binding; positions as DESIGN.md §2.6.2 and §3.3 give them (a `dot` and a `bin` at their left operand, a `slit` at its type name, an `init` at its name, a `struct` at its keyword, a `field` at its name, a target at its text).
From sub-phase 4h (DESIGN.md §2.6.2 "Readings fixed by 4h", the after-phase-4 table) the prelude functions `linspace`, `meshgrid`, `setdiff` and `bincount` are implemented. No golden named one of the four removed words, so none is retired (L-z). The 4h tests below cover the prelude calls checked as user calls (L-t: 226, 242 and 201 at an argument, never 243; `expected i64[], found f64[1]` for a fixed-size literal; 255 naming LANGUAGE.md's parameter `idx`; `named arguments` at the `narg`), the prelude names (L-s: 212 for a program `fn` or `const`, 213 for a local, a parameter and a loop variable), the run-time errors of prelude code at the line of the program's call (L-y: `bincount`'s index errors, also inside a user function, `invalid array size` for `bincount` with n = −2 and n = 3 000 000 000 and for `linspace` with n = 3 000 000 000, `out of memory` for a too large `meshgrid` result), and one close-out test for each after-phase-4 row that had none (L-z: `@` of two matrices at its left operand, `format`, `solve`, `figure` at the call). `undeclared name 'linspace'` under `--no-prelude` needs a driver flag, which `errors/` tests cannot pass: it is the `tests/driver_check.sh` case of §6.2 (and the dump `passes/res_noprelude_pnames`).
From sub-phase 6b (DESIGN.md §2.11.2, §6.2 "Existing tests that phase 6 changes") named and default arguments, `f64 %`, `format`, `print` and `make_dir` are implemented: the goldens `err_ns_named_arg`, `err_ns_default_arg`, `err_ns_f64_mod` and `err_ns_lib_format` are retired with their phase-rule rows (their constructs are `programs/call6_*`, `fmod_*`, `fmt6_*`); `err_prel_named` moved to `programs/call6_prel_named` (`linspace(0.0, 1.0, n: 3)` is legal); `err_find_desc_unknown`, `err_red_argmax_dim`, `err_red_desc_unknown`, `err_red_desc_twice_unknown` and `err_sort_dim_unknown` are re-derived (a name a library function does not take is 224 `unknown parameter` at the `narg`, L-by, at the position the phase-rule word had); `err_ns_lib_write_json` kept the `write_json` row until 6d (retired there). The 6b tests below cover 224 (a user function, a library function's positional parameter, a prelude function), 225, 226 (a parameter without a default skipped by name), 236, 227 at a `ref` parameter's default, 254 at a named `ref` argument, 237, 201, 260, 261 and 200 at a default (in source order with a constant item's error: Decision 91), 243 for `print` and `make_dir`, 210, 211, 233 and 234 for `format`, the run-time line of an error inside an inlined function (the callee's, §3.6.4 "Sites"; an argument expression's and the deferred `ref` recheck's are the caller's), and the run-time errors of `make_dir`.
From sub-phase 6c (DESIGN.md §2.11.2 L-cq, §2.11.4 L19 and L-cl, §6.2 "6c, elemental functions") `elemental` functions and `ind2sub` with an array first argument are implemented: the goldens `err_ns_elemental` and `err_ns_ind2sub_array` are retired with their phase-rule rows (their constructs are `programs/elem_*` and `programs/ind2sub_arr_*`) and `err_merge_same_pos` is re-derived (a `str` result of an elemental function: 253 at the `fn` item and `missing return` at one position, 253 reported). The 6c tests cover 228 (a `ref` parameter, a `printf`, a call of a function with effects, a transitive one), 232 (direct and mutual, the first call in source order), 253, 202, 217 and 201 at the call or an argument, each plain and, where it is a `seaname` error, behind an earlier `seacheck` error and, where it is a `seacheck` error, behind an earlier `seaname` error (the `_after` tests: the earlier error in source order is reported); the 228 and 232 pre-pass errors against `seacheck`'s 226 at one call; and the run-time errors of an elemental call: the first failing element in linear order with the callee's line, the shape mismatch at the call's line before any element runs.
From sub-phase 6d (DESIGN.md §2.11.2, §3.5.7 step 4, §6.2 "6d, `write_json`") `write_json` is implemented: the golden `err_ns_lib_write_json` is retired with its phase-rule row (the construct is `programs/json_*`, each with its `NAME.expect/` files compared byte for byte; `tests/run.sh` also fails on a file that is not expected). The 6d error tests are the run-time `r_json_*` (open failures: a missing directory, a directory, `.`, the empty path, a path below a file; an error after a completed `write_json`; a failing second call; an error in the value or the path expression, which creates no file). A failure to write the file cannot be provoked byte-identically on both targets: the runtime tests of the Linux target (`/dev/full`) and review cover it; The 243 of a wrong number or type of arguments is tested by the compile-time `err_json_*`; 243 for a handle-typed value stays untestable before phase 8 (the `handle types` row reports first).
From sub-phase 7c (DESIGN.md §2.12.2, §2.12.4, §6.2 "Phase-7 tests") fusion adds no error and changes no diagnostic: the `r_fuse_*` tests fix the first failing check in reference order where a fusion could move a loop past a later check (a later leaf that would also fail, a failing inner node below a later shape check or an empty broadcast, a failing root before a selection store, two failing nodes, a failing reduction, an `error` inside an elemental function and an empty masked `max` in a group, an effect that ends a group, a bad index after a fused value), each with the output written before the error.


| Test | Message | What |
|------|---------|------|
| `err_assign_for` | `cannot assign to immutable 'i'` | a loop variable is immutable (LANGUAGE.md 7.5) |
| `err_assign_let` | `cannot assign to immutable 'a'` | a let cannot be assigned (LANGUAGE.md 7.2; at the target) |
| `err_assign_param` | `cannot assign to immutable 'x'` | an ordinary parameter is immutable (LANGUAGE.md 8.2) |
| `err_bad_escape` | `invalid escape` | \q is not an escape; reported at the backslash (LANGUAGE.md 3.5) |
| `err_bad_escape_big` | `invalid escape` | \u{110000} is above 10FFFF (LANGUAGE.md 3.5) |
| `err_bad_escape_digits` | `invalid escape` | \u{} with 7 hex digits (at most 6, LANGUAGE.md 3.5) |
| `err_bad_escape_hex` | `invalid escape` | \x needs two hex digits (LANGUAGE.md 3.5) |
| `err_bad_escape_surrogate` | `invalid escape` | \u{D800} is a surrogate (LANGUAGE.md 3.5; at the backslash) |
| `err_bad_number_dot` | `invalid numeric literal` | there is no 1. literal (LANGUAGE.md 3.4; at token) |
| `err_bad_number_hex` | `invalid numeric literal` | _ may not follow 0x (LANGUAGE.md 3.4; at token) |
| `err_bad_number_trailing` | `invalid numeric literal` | _ may not end a literal (LANGUAGE.md 3.4; at token) |
| `err_bad_number_us_dot` | `invalid numeric literal` | _ may not stand next to . (LANGUAGE.md 3.4; at token) |
| `err_bad_number_us_exp` | `invalid numeric literal` | _ may not stand next to the exponent letter (LANGUAGE.md 3.4) |
| `err_bad_operand_neg` | `operator '-' cannot be applied to bool` | unary - needs a number (Appendix B) |
| `err_bad_operand_not` | `operator '!' cannot be applied to i64` | ! needs a bool (LANGUAGE.md 6.4; at the operator node) |
| `err_bad_operands_add` | `operator '+' cannot be applied to bool and i64` | + on bool and i64 (Appendix B; at the operator node) |
| `err_bad_operands_and` | `operator '&&' cannot be applied to i64 and bool` | && needs bool operands (LANGUAGE.md 6.4) |
| `err_bad_operands_band` | `operator '&' cannot be applied to i64 and bool` | & needs bool operands (LANGUAGE.md 6.4) |
| `err_bad_operands_bor` | `operator '\|' cannot be applied to bool and f64` | \| needs bool operands (LANGUAGE.md 6.4) |
| `err_bad_operands_lt` | `operator '<' cannot be applied to bool and bool` | bool compares with == and != only (LANGUAGE.md 6.4) |
| `err_bad_target_const` | `invalid assignment target` | a constant is not an assignment target (DESIGN.md 2.6.2) |
| `err_bad_target_fn` | `invalid assignment target` | a function is not an assignment target (DESIGN.md 2.6.2) |
| `err_bool_conv` | `unexpected token 'bool'` | there is no bool(x) conversion (Appendix A; DESIGN.md 0) |
| `err_break_outside` | `break outside a loop` | break outside a loop (LANGUAGE.md 7.5) |
| `err_call_then_asg` | `unexpected token '='` | a call statement ends after the call: f(1) = 3 (LANGUAGE.md 7.1) |
| `err_chained_compare` | `comparisons cannot be chained` | comparisons are non-associative; at the second operator (LANGUAGE.md 6.1) |
| `err_chained_compare_eq` | `comparisons cannot be chained` | a == b != c is chained too (LANGUAGE.md 6.1) |
| `err_cond_bool_if` | `condition must be bool` | an if condition must be bool (LANGUAGE.md 4.3; at expr) |
| `err_cond_bool_ifx` | `condition must be bool` | an if-expression condition must be bool (LANGUAGE.md 4.3, 6.10) |
| `err_cond_bool_while` | `condition must be bool` | a while condition must be bool (LANGUAGE.md 4.3) |
| `err_const_band_eval` | `integer division by zero` | a constant & evaluates both operands: 1 % 0 fails (LANGUAGE.md 7.2, 6.6) |
| `err_const_log` | `not a constant expression` | log is not a constant expression (LANGUAGE.md 7.2; DESIGN.md 4.10.5; at expr, the whole initialiser) |
| `err_const_mod_chain` | `integer division by zero` | the reviewer's % chain: C3 = 0 % 0 divides by zero at compile time (LANGUAGE.md 7.2 U2; at the operator) |
| `err_const_mod_zero` | `integer division by zero` | a constant % by zero is a compile error (LANGUAGE.md 7.2 U2, 6.6) |
| `err_const_noval_calltype` | `unknown struct type` | `const A: f64 = f()` with a faulty `f`: its undeclared result type `Q` (2:11, 229 by `seaname` in the signature) only (DESIGN.md 6.2, Decision 25 refined; re-derived by 4g-1, L-i) |
| `err_const_noval_errtype` | `unknown struct type` | A has the error type and no value: B = A + 1 % 0 is not evaluated, f's undeclared result type `Q` (3:11) is the only error (LANGUAGE.md 7.2; DESIGN.md 3.5.2, Decision 25, 6.2; re-derived by 4g-1, L-i) |
| `err_const_noval_overflow` | `undeclared name 'x'` | A has an error, so B (which would overflow at 1:11) names a constant without a value and is not evaluated (LANGUAGE.md 7.2; Decision 25, 6.2) |
| `err_const_noval_pow` | `no overload of 'pow' accepts (f64)` | the same with A = pow(2.0): the call error at 2:16 only (LANGUAGE.md 7.2; Decision 25, 6.2) |
| `err_const_noval_shortcircuit` | `unknown struct type` | `B` holds a faulty call behind `false &&` and has no value, so `D` (line 1) is not evaluated: 3:11 (f's undeclared result type `Q`), not `D`'s overflow (Decision 25 refined; re-derived by 4g-1, L-i) |
| `err_const_noval_userpow` | `redefinition of predeclared name` | `C` calls the program's `fn pow` (2:1), so it is not evaluated (Decision 25 refined) |
| `err_const_overflow_inner` | `integer overflow` | the innermost failing operation in evaluation order is reported (DESIGN.md 2.6.2 expr; LANGUAGE.md 7.2) |
| `err_const_overflow_neg` | `integer overflow` | unary minus of -2^63 in a constant (LANGUAGE.md 7.2, 6.5) |
| `err_const_overflow_unused` | `integer overflow` | a constant that overflows i64 is a compile error even unused (LANGUAGE.md 7.2 U2; at the operator) |
| `err_const_poison_and` | `integer overflow` | a constant whose operand constant failed reports only that failure (LANGUAGE.md 7.2 U2) |
| `err_const_poison_pow` | `integer overflow` | a constant exponent whose evaluation overflows reports the overflow (LANGUAGE.md 7.2 U2) |
| `err_const_sin` | `not a constant expression` | sin inside a larger constant expression: at the whole initialiser (LANGUAGE.md 7.2; DESIGN.md 2.6.2 expr) |
| `err_continue_outside` | `continue outside a loop` | continue in a function called from a loop is still outside one |
| `err_conv_no_paren` | `unexpected token '+'` | a conversion keyword without ( names the next token (LANGUAGE.md App. A) |
| `err_dollar_array_literal` | `'$' outside an index` | array-literal brackets are not index brackets (LANGUAGE.md 5.3) |
| `err_dollar_outside` | `'$' outside an index` | $ outside an index (LANGUAGE.md 5.3; at the $) |
| `err_float_range` | `float literal out of range` | a float literal above the overflow midpoint (LANGUAGE.md 3.4; at token) |
| `err_float_range_exp` | `float literal out of range` | 1e309 overflows (LANGUAGE.md 3.4; at token) |
| `err_format_arg_bool` | `format "%8e" expects an integer or f64, found bool` | %8e of a bool: e takes f64 or i64 only (LANGUAGE.md 11.1; DESIGN.md 2.6.2) |
| `err_format_arg_bool_s` | `format "%s" expects str, found bool` | %s of a bool (LANGUAGE.md 11.1) |
| `err_format_arg_f` | `format "%.2f" expects an integer or f64, found bool` | %.2f of a bool (LANGUAGE.md 11.1) |
| `err_format_arg_str` | `format "%s" expects str, found i64` | %s of an i64 (LANGUAGE.md 11.1) |
| `err_format_bad_conv` | `invalid format conversion "%q"` | an unknown conversion letter (LANGUAGE.md 11.1; at the string) |
| `err_format_bad_end` | `invalid format conversion "%5"` | a conversion cut off by the end of the string (LANGUAGE.md 11.1) |
| `err_format_bad_flag` | `invalid format conversion "%#d"` | # with d is undefined in C (LANGUAGE.md 11.1) |
| `err_format_bad_length` | `invalid format conversion "%l"` | length modifiers do not exist (LANGUAGE.md 11.1) |
| `err_format_bad_star` | `invalid format conversion "%*"` | * width does not exist (LANGUAGE.md 11.1) |
| `err_format_bad_zero_s` | `invalid format conversion "%05s"` | 0 with s is undefined in C (LANGUAGE.md 11.1) |
| `err_format_count_few` | `format "%d %d\n" expects 2 arguments, found 1` | fewer arguments than conversions (LANGUAGE.md 11.1; at the call) |
| `err_format_count_many` | `format "%d%%\n" expects 1 arguments, found 2` | more arguments than conversions; %% is not a conversion (LANGUAGE.md 11.1) |
| `err_format_literal` | `format must be a string literal` | the format must be a string literal (LANGUAGE.md 11.1; at expr) |
| `err_format_order` | `format "%s %s\n" expects 2 arguments, found 1` | the count is checked before the argument types (DESIGN.md 2.6.2, formatting calls) |
| `err_fuse_reg2_cap_denials` | `program too large: nodes` | 7c regression (DESIGN.md §2.12.3 Capacity, L-el): padding near SEA_LIM_NODES then 150 fusible statements; a fusion over the limit and every later one are written unfused (the walk runs once more, never one walk per fusion) and the program is still too large: the pre-fusion compiler's message and position |
| `err_fuse_reg2_cap_selstore` | `program too large: nodes` | 7c regression (§2.12.3 Capacity, F1 (3)): the limit is passed while seafuse writes the in-place selection store `V[0..$] = …` (its target's index records); written unfused, the program is still too large (message as before; the position moves as §2.12.3 allows: the pre-fusion compiler reports 8:11) |
| `err_ident_too_long` | `identifier too long` | a 64-byte identifier (limit 63, LANGUAGE.md 3.3; at token) |
| `err_illegal_char` | `illegal character` | a byte outside printable ASCII in code is illegal (LANGUAGE.md 3.1; at byte) |
| `err_illegal_char_ctl` | `illegal character` | a control byte in code is illegal (LANGUAGE.md 3.1; at byte) |
| `err_int_too_large` | `integer literal too large` | 2^63 is too large except as the operand of a unary minus (LANGUAGE.md 3.4) |
| `err_int_too_large_binary` | `integer literal too large` | 2^63 as the operand of a binary minus (LANGUAGE.md 3.4) |
| `err_int_too_large_neg` | `integer literal too large` | -(2^63 + 1): the literal is too large (LANGUAGE.md 3.4; at token) |
| `err_keyword_ident` | `unexpected token 'if'` | a keyword is never an identifier (LANGUAGE.md 3.3) |
| `err_line_too_long` | `line too long` | line 3 has 4097 bytes: the driver reports column 4097 before any pass |
| `err_merge_check_first` | `undeclared name 'y'` | a `seacheck` error (2:9) before a `seaname` error (3:1) in source order (DESIGN.md 2.6.2 order across the two programs) |
| `err_merge_const_after` | `redefinition of predeclared name` | a `seaname` error (2:1) before a constant's `integer overflow` (5:11) |
| `err_merge_const_first` | `integer overflow` | a constant's `integer overflow` (an `rcne`, 2:11) before a `seaname` error (3:1) |
| `err_merge_name_first` | `redefinition of predeclared name` | a `seaname` error (2:1) before a `seacheck` error (5:9) |
| `err_merge_same_pos` | `elemental function result must be f64, i64 or bool` | two errors at one `fn` item (6c, re-derived): `seaname`'s 253 (a `str` result of an elemental function, found in the signature step, the `rerr`) and `seacheck`'s `missing return` at the same position; 253 is reported at 2:1 |
| `err_missing_arg` | `missing argument` | a parameter without a default must be given (LANGUAGE.md 8.1; at the call) |
| `err_missing_return` | `missing return` | a function with a result must end every path with return (LANGUAGE.md 8.1; at fn) |
| `err_missing_return_while` | `missing return` | a loop never ends every path, even while true (LANGUAGE.md 8.1) |
| `err_multi_value` | `multiple-result call used as a value` | a multiple-result call inside an expression (LANGUAGE.md 8.4; at the call) |
| `err_multi_value_arg` | `multiple-result call used as a value` | a multiple-result call as an argument (LANGUAGE.md 8.4; at the call) |
| `err_no_effect` | `expression statement has no effect` | a line starting with a binary operator is a new statement (LANGUAGE.md 3.7) |
| `err_no_effect_asg` | `expression statement has no effect` | x + y = 3 is an expression statement (LANGUAGE.md 7.1) |
| `err_no_effect_binop` | `expression statement has no effect` | an operator expression is not a call (LANGUAGE.md 7.1; at stmt) |
| `err_no_effect_name` | `expression statement has no effect` | a bare name is not a call (LANGUAGE.md 7.1; at stmt) |
| `err_no_overload_hypot` | `no overload of 'hypot' accepts (f64)` | hypot takes two arguments (LANGUAGE.md 10.4; at the call) |
| `err_no_overload_idiv` | `no overload of 'idiv' accepts (f64, i64)` | idiv takes two i64 (LANGUAGE.md 6.6; at the call) |
| `err_no_overload_now` | `no overload of 'now' accepts (i64)` | now takes no argument (LANGUAGE.md 13) |
| `err_not_constant` | `not a constant expression` | a const expression must be constant (LANGUAGE.md 7.2; at expr) |
| `err_not_constant_cycle` | `not a constant expression` | a constant cycle through another constant: at the name that closes it (LANGUAGE.md 7.2) |
| `err_not_exact_f64` | `integer constant not exact in f64` | an untyped integer that becomes f64 must be exact (LANGUAGE.md 4.2; at expr) |
| `err_not_exact_ifx` | `integer constant not exact in f64` | an untyped arm beside an f64 arm is f64 and must be exact (LANGUAGE.md 4.2 (f)) |
| `err_not_exact_printf_f` | `integer constant not exact in f64` | an untyped literal argument of %f is f64 and must be exact (LANGUAGE.md 4.2 (e)) |
| `err_not_function` | `'a' is not a function` | calling a local (DESIGN.md 2.6.2; at the call) |
| `err_not_function_const` | `'C' is not a function` | calling a constant (DESIGN.md 2.6.2; at the call) |
| `err_ns_handle` | `not supported yet: handle types` | phase 1: a handle type (at the type node) |
| `err_rt_arr_size_neg` | `invalid array size -1` | LANGUAGE.md 10.2, 9.2: a negative extent of `zeros`, after the output before it |
| `err_rt_arr_size_big` | `invalid array size 2147483648` | 4.5, 10.2: an extent of 2³¹ (`ones`) |
| `err_rt_arr_size_mat` | `invalid array size -3` | 10.2: a bad column extent of `filled` |
| `err_rt_arr_size_order` | `invalid array size -1` | rows before cols (DESIGN.md 4.8 `sea_arr_new`) |
| `err_rt_arr_oob_neg` | `index -1 out of bounds for dimension 0 of extent 3` | 5.4: `v[-1]` is an error |
| `err_rt_arr_oob_ext` | `index 3 out of bounds for dimension 0 of extent 3` | 5.4: the extent |
| `err_rt_arr_oob_row_neg` | `index -1 … dimension 0 of extent 2` | 5.4: a matrix's rows are dimension 0 |
| `err_rt_arr_oob_row_ext` | `index 2 … dimension 0 of extent 2` | 5.4 |
| `err_rt_arr_oob_col_neg` | `index -1 … dimension 1 of extent 3` | 5.4: the columns are dimension 1 |
| `err_rt_arr_oob_col_ext` | `index 3 … dimension 1 of extent 3` | 5.4, in a store |
| `err_rt_arr_oob_order` | `index 5 … dimension 0 of extent 2` | 5.4 C1: both indices evaluated (their output) before the first failing check |
| `err_rt_arr_oob_store_order` | `index 3 … dimension 1 of extent 3` | 5.5 C4: the value, then the indices, then the checks |
| `err_rt_arr_oob_compound_order` | `index 5 … dimension 0 of extent 3` | 5.5 C6, 7.3: the read's check comes before the value |
| `err_rt_arr_compound_ovf` | `integer overflow` | 6.5: a checked `i64` compound element store |
| `err_rt_arr_compound_ref_empty` | `index 0 … dimension 0 of extent 0` | DESIGN.md 3.6.6 rule 19: the store's repeated check after the value emptied the array |
| `err_rt_arr_ref_nested_empty` | `index 0 … dimension 0 of extent 0` | rule 31: `f(ref v[0], g(ref v))` with g emptying v, at the call's line |
| `err_rt_arr_abs_min` | `integer overflow` | LANGUAGE.md 10.4: `abs(-2^63)` |
| `err_rt_arr_sub2ind_oob` | `index 3 … dimension 0 of extent 3` | 10.7: sub2ind checks i against r |
| `err_rt_arr_ind2sub_zero` | `integer division by zero` | 10.7, 6.6: ind2sub(0, k) |
| `err_rt_arr_ref_in_target_shrink` | `index 1 … dimension 0 of extent 1` | 5.5 C4: a `ref` call in the target's index shrinks the array; the check uses the new extent |
| `err_rt_sel_range_last` | `index 9 out of bounds for dimension 0 of extent 5` | 4e: v[2..10] on a 5-element vector reports the last position 9 (LANGUAGE.md 5.4) |
| `err_rt_sel_range_first` | `index 7 out of bounds for dimension 0 of extent 5` | 4e: v[7..9] reports its first position 7 (LANGUAGE.md 5.4) |
| `err_rt_sel_range_step` | `index 5 out of bounds for dimension 0 of extent 5` | 4e: v[1..=5 step 2]: positions 1 3 5, the last is out of range (LANGUAGE.md 5.4) |
| `err_rt_sel_range_negstep` | `index -2 out of bounds for dimension 0 of extent 5` | 4e: v[4..=-2 step -3]: positions 4 1 -2, the last -2 (LANGUAGE.md 5.1, 5.4) |
| `err_rt_sel_dollar` | `index 5 out of bounds for dimension 0 of extent 5` | 4e: v[$ - 2..$ + 1] is 3..6: the last position 5 (LANGUAGE.md 5.3, 5.4) |
| `err_rt_sel_ivec` | `index 7 out of bounds for dimension 0 of extent 5` | 4e: an index vector reports its first element out of range, in order: 7 (LANGUAGE.md 5.4) |
| `err_rt_sel_ivec_dyn` | `index 5 out of bounds for dimension 0 of extent 5` | 4e: a dynamic index vector 3 4 5 6 7: the first bad element 5 (LANGUAGE.md 5.4) |
| `err_rt_sel_mat_col` | `index 4 out of bounds for dimension 1 of extent 3` | 4e: A[0..2, 1..5] on a 2 x 3 matrix: dimension 1, last position 4 (LANGUAGE.md 5.4) |
| `err_rt_sel_mat_order` | `index 4 out of bounds for dimension 0 of extent 2` | 4e: A[0..5, 0..9]: dimension 0 is checked before dimension 1 (LANGUAGE.md 5.4) |
| `err_rt_sel_check_order_mask` | `shape mismatch: 3 vs 2` | 4e: A[m, 9] with a mask of the wrong extent: the mask is dimension 0's check, made before dimension 1 (LANGUAGE.md 5.2, 5.4): 3 vs 2 |
| `err_rt_sel_check_order_idx` | `index 9 out of bounds for dimension 0 of extent 3` | 4e: A[9, m]: the scalar index of dimension 0 is checked before the mask (LANGUAGE.md 5.4) |
| `err_rt_sel_mask_vec` | `shape mismatch: 5 vs 4` | 4e: v[m] with a 5-element v and a 4-element m: shape mismatch: 5 vs 4 (LANGUAGE.md 5.2) |
| `err_rt_sel_mask_mat` | `shape mismatch: 3x4 vs 4x3` | 4e: A[M] with A 3 x 4 and M 4 x 3: shape mismatch: 3x4 vs 4x3 (LANGUAGE.md 5.2) |
| `err_rt_sel_mask_dim` | `shape mismatch: 3 vs 2` | 4e: A[m, :]: the dimension's extent as a vector shape, then len(m) (LANGUAGE.md 5.2) |
| `err_rt_sel_store_idx_first` | `index 8 out of bounds for dimension 0 of extent 5` | 4e: v[0..9] = val(): the value is evaluated first, then the index check fails before the shape check (LANGUAGE.md 5.5): index 8 |
| `err_rt_sel_store_shape` | `shape mismatch: 3 vs 2` | 4e: v[0..3] = [1.0, 2.0]: shape mismatch: 3 vs 2, the selection first (LANGUAGE.md 5.5) |
| `err_rt_sel_store_shape_fixed` | `shape mismatch: 3 vs 2` | 4e: a fixed-size v with a constant range: the selection's shape is a run-time value, so the check is made at run time (LANGUAGE.md 5.5) |
| `err_rt_sel_store_shape_mat` | `shape mismatch: 2x3 vs 3x3` | 4e: A[0..2, :] = zeros(3, 3) on a 2 x 3 matrix: shape mismatch: 2x3 vs 3x3 (LANGUAGE.md 5.5) |
| `err_rt_sel_mask_store_count` | `shape mismatch: 3 vs 2` | 4e: v[m] = [1.0, 2.0] with nnz(m) = 3: shape mismatch: 3 vs 2 (LANGUAGE.md 5.5) |
| `err_rt_sel_compound_order` | `index 8 out of bounds for dimension 0 of extent 5` | 4e: v[0..9] += val(): the read and its checks come before e, so val is never called (LANGUAGE.md 5.5) |
| `err_rt_sel_compound_shape` | `shape mismatch: 3 vs 2` | 4e: v[0..3] += [1.0, 2.0]: the operation's check, the selection as the left operand (LANGUAGE.md 5.5, 6.3): 3 vs 2 |
| `err_rt_sel_compound_bcast` | `shape mismatch: 1x3 vs 2x3` | 4e: A[0..1, :] += [1.0; 2.0]: 1x3 plus 2x1 broadcasts to 2x3, then the store's check, the selection first: 1x3 vs 2x3 (LANGUAGE.md 5.5, 6.3) |
| `err_rt_sel_step_zero` | `range step is zero` | 4e: a range index with step 0: range step is zero (LANGUAGE.md 5.1) |
| `err_rt_flat_oob` | `index 6 out of bounds for dimension 0 of extent 6` | 4e: A.flat[6] on a 2 x 3 matrix: the view's extent 6, dimension 0 (LANGUAGE.md 5.6, 5.4) |
| `err_rt_flat_store_oob` | `index 9 out of bounds for dimension 0 of extent 6` | 4e: A.flat[[0, 9]] = 1.0: the index vector's first bad element 9 (LANGUAGE.md 5.6) |
| `err_rt_ew_vec` | `shape mismatch: 3 vs 4` | 4e: vectors of 3 and 4 elements: shape mismatch: 3 vs 4 (LANGUAGE.md 6.3) |
| `err_rt_ew_mat` | `shape mismatch: 2x3 vs 3x2` | 4e: 2x3 with 3x2: neither extent is 1 in either dimension (LANGUAGE.md 6.3) |
| `err_rt_ew_zero_bcast` | `shape mismatch: 0x3 vs 2x3` | 4e: 0x3 with 2x3: 0 and 2 differ and neither is 1 (LANGUAGE.md 6.3) |
| `err_rt_ew_where_vec` | `shape mismatch: 3 vs 2` | 4e: where(c, a, b) with c and a of 3 and b of 2: the shape combined so far, then b's (LANGUAGE.md 6.3): 3 vs 2 |
| `err_rt_ew_where_mat` | `shape mismatch: 3x4 vs 2x4` | 4e: where(c, a, b) with c 1x4, a 3x1, b 2x4: c with a combine to 3x4, then b (LANGUAGE.md 6.3): 3x4 vs 2x4 |
| `err_rt_ew_elem_call` | `shape mismatch: 3 vs 2` | 4e: an elemental call with arrays of 3 and 2 elements (LANGUAGE.md 6.3, 10.4) |
| `err_rt_ew_i64_overflow` | `integer overflow` | 4e: element-wise i64 + overflows: integer overflow (LANGUAGE.md 6.5) |
| `err_rt_ew_i64_neg` | `integer overflow` | 4e: element-wise unary - of -2^63: integer overflow (LANGUAGE.md 6.5) |
| `err_rt_ew_i64_mod_zero` | `integer division by zero` | 4e: element-wise i64 % with a zero element: integer division by zero (LANGUAGE.md 6.6) |
| `err_rt_ew_idiv_zero` | `integer division by zero` | 4e: element-wise idiv with a zero divisor: integer division by zero (LANGUAGE.md 6.6) |
| `err_rt_cvt_first_bad` | `conversion to i64: 2.5 is not an integer` | 4e: i64 of 1.0 2.5 3.5: the first element that is not an integer, 2.5 (LANGUAGE.md 10.1, 9.2; %g spelling) |
| `err_rt_cvt_nan_elem` | `conversion to i64: NaN is not an integer` | 4e: i64 of 4.0 NaN: NaN is not an integer (LANGUAGE.md 10.1, 11.1 spelling) |
| `err_rt_fix_bind` | `shape mismatch: expected 4, got 5` | 4e: a dynamic array of 5 bound to f64[4]: shape mismatch: expected 4, got 5 (LANGUAGE.md 4.5) |
| `err_rt_fix_assign` | `shape mismatch: expected 4, got 5` | 4e: assignment from a dynamic array to a fixed-size variable (LANGUAGE.md 4.5) |
| `err_rt_fix_arg` | `shape mismatch: expected 4, got 3` | 4e: a dynamic argument for an f64[4] parameter (LANGUAGE.md 4.5) |
| `err_rt_fix_return` | `shape mismatch: expected 2, got 3` | 4e: a dynamic array returned as f64[2] (LANGUAGE.md 4.5) |
| `err_rt_fix_mat` | `shape mismatch: expected 2x2, got 3x2` | 4e: a 3 x 2 dynamic matrix bound to f64[2,2]: expected 2x2, got 3x2 (LANGUAGE.md 4.5) |
| `err_rt_fix_ew` | `shape mismatch: expected 2, got 3` | 4e: a fixed f64[3] times a dynamic vector is dynamic (DESIGN.md 3.5.5), so binding it to f64[2] is the run-time check (LANGUAGE.md 4.5) |
| `err_rt_fix_lit257` | `shape mismatch: expected 4, got 257` | 4e: a literal of 257 scalars is dynamic (LANGUAGE.md 4.5, 6.9): binding it to i64[4] is the run-time check, expected 4, got 257 |
| `err_rt_cat_rows` | `shape mismatch: 2x2 vs 3x1` | 4e: joining a 2x2 and a 3x1 dynamic matrix: the joined shape so far first (LANGUAGE.md 6.9; DESIGN.md 3.6.6 rule 26 (c)): 2x2 vs 3x1 |
| `err_rt_cat_stack` | `shape mismatch: 1x2 vs 1x3` | 4e: stacking vector rows of 2 and 3 elements: 1x2 vs 1x3 (LANGUAGE.md 6.9; DESIGN.md 3.6.6 rule 26 (c)) |
| `err_rt_range_size` | `invalid array size 3000000000` | 4e: a range value of 3000000000 positions: invalid array size 3000000000 (LANGUAGE.md 5.1) |
| `err_rt_range_size_sat` | `invalid array size 9223372036854775807` | 4e: -2^63..=2^63-1 has 2^64 positions, beyond i64: the saturated text invalid array size 9223372036854775807 (LANGUAGE.md 5.1) |
| `err_rt_range_size_sat2` | `invalid array size 9223372036854775807` | 4e: 0..=2^63-1 has 2^63 positions, beyond i64: the saturated text (LANGUAGE.md 5.1) |
| `err_rt_range_step_zero` | `range step is zero` | 4e: a range value with step 0: range step is zero (LANGUAGE.md 5.1) |
| `err_rt_ind2sub_zero_vec` | `integer division by zero` | 4e: ind2sub(0, k) with a vector k: integer division by zero at the call's line (LANGUAGE.md 10.7, 6.6; Decision 33) |
| `err_rt_sub2ind_vec_oob` | `index 3 out of bounds for dimension 0 of extent 3` | 4e: sub2ind(3, i, j) with i = 0 3 5: the first bad element 3, dimension 0, extent 3 (LANGUAGE.md 10.7; DESIGN.md 2.6.2) |
| `err_shape_static_ew` | `shape mismatch: 3 vs 2` | 4e: fixed operands of 3 and 2 elements: the compile-time shape mismatch at the operator node, its left operand's start (LANGUAGE.md 4.10, 6.3; DESIGN.md 3.5.5) |
| `err_shape_static_ew_mat` | `shape mismatch: 2x2 vs 3x2` | 4e: fixed 2x2 and 3x2 operands (DESIGN.md 3.5.5) |
| `err_shape_static_where` | `shape mismatch: 3x4 vs 2x4` | 4e: where(a, b, c) with fixed a 1x4, b 3x1, c 2x4: 3x4 vs 2x4 at the call (DESIGN.md 3.5.5, its example) |
| `err_shape_static_where_dyn` | `shape mismatch: 3 vs 4` | 4e: where(a3, c, b4) with a dynamic c: the combined extent 3 stays known, then b4 (DESIGN.md 3.5.5, its example): 3 vs 4 |
| `err_shape_static_ew_result` | `shape mismatch: 2 vs 3` | 4e: an element-wise result of fixed operands is fixed (f64[3]), so binding it to f64[2] is 217 at the value, the target first (DESIGN.md 3.5.5, 2.6.2) |
| `err_shape_static_mask` | `shape mismatch: 3 vs 2` | 4e: a fixed mask of 2 on a fixed vector of 3: at the mask index, what it selects from first (LANGUAGE.md 5.2; DESIGN.md 3.5.5) |
| `err_shape_static_mask_mat` | `shape mismatch: 2x3 vs 3x2` | 4e: a fixed 3x2 whole-matrix mask on a fixed 2x3 matrix (LANGUAGE.md 5.2) |
| `err_shape_static_mask_dim` | `shape mismatch: 2 vs 3` | 4e: a fixed mask of 3 for the 2 rows of a fixed matrix: the dimension's extent as a vector shape, then len(m) (LANGUAGE.md 5.2) |
| `err_shape_static_cat` | `shape mismatch: 2x2 vs 3x1` | 4e: joining fixed 2x2 and 3x1 matrices: at the part, the joined shape so far first (LANGUAGE.md 6.9; DESIGN.md 3.5.5) |
| `err_shape_static_bind` | `shape mismatch: 4 vs 3` | 4e: let a: f64[4] = [1.0, 2.0, 3.0]: at the value, the target's shape first (DESIGN.md 2.6.2 `expr`) |
| `err_shape_static_assign` | `shape mismatch: 2 vs 3` | 4e: a fixed value of 3 assigned to a fixed variable of 2 (DESIGN.md 3.5.5) |
| `err_shape_static_arg` | `shape mismatch: 2 vs 3` | 4e: a fixed argument of 3 for an f64[2] parameter (DESIGN.md 3.5.5) |
| `err_shape_static_return` | `shape mismatch: 2 vs 3` | 4e: a fixed value of 3 returned as f64[2] (DESIGN.md 3.5.5) |
| `err_shape_static_mat_bind` | `shape mismatch: 2x2 vs 2x3` | 4e: a fixed 2x3 literal bound to f64[2,2] (DESIGN.md 3.5.5) |
| `err_shape_static_empty` | `shape mismatch: 2 vs 0` | 4e: [] under a fixed-size type with elements: shape mismatch, the target's shape first, [] the vector of length 0 (LANGUAGE.md 6.9) |
| `err_shape_static_lit256` | `shape mismatch: 4 vs 256` | 4e: a literal of 256 scalars is fixed (i64[256], LANGUAGE.md 4.5): binding it to i64[4] is the compile error (compare err_rt_fix_lit257) |
| `err_type_mismatch_lit` | `type mismatch: expected bool, found i64` | 4e: [true, 1]: no common element type, at the first element that does not combine (LANGUAGE.md 6.9; DESIGN.md 3.5.5) |
| `err_vec_mat` | `cannot combine a vector with a matrix: use .col or .row` | 4e: a vector with a matrix operand (LANGUAGE.md 6.3): at the operator node |
| `err_cannot_infer_let` | `type cannot be inferred: add a type annotation` | 4e: let x = []: no type from the context, 252 at the [ (LANGUAGE.md 6.9; Decision 36) |
| `err_cannot_infer_len` | `type cannot be inferred: add a type annotation` | 4e: len([]): a library argument gives no type (LANGUAGE.md 6.9; Decision 36) |
| `err_cannot_infer_add` | `type cannot be inferred: add a type annotation` | 4e: [] + v with v an f64[]: an operand gives no type (LANGUAGE.md 6.9; Decision 36) |
| `err_no_transpose` | `vector has no transpose: use .row or .col` | 4e: .T of a vector, at the dot node (the operand's start; LANGUAGE.md 5.6) |
| `err_ragged` | `ragged matrix literal` | 4e: rows of 2 and 1 scalars: at the first row whose length differs (LANGUAGE.md 6.9) |
| `err_use_row_col` | `use .row or .col` | 4e: a row joining a vector and a matrix, at the row (its first element; LANGUAGE.md 6.9) |
| `err_bad_target_view_t` | `invalid assignment target` | 4e: an element of A.T as an assignment target (LANGUAGE.md 5.6, 7.3: only .flat is a target), at the target |
| `err_bad_target_view_row` | `invalid assignment target` | 4e: v.row as an assignment target (LANGUAGE.md 5.6, 7.3), at the target |
| `err_view_rank_col` | `view .col is not defined for f64[,]` | 4e: .col of a matrix (LANGUAGE.md 5.6), at the dot node |
| `err_view_rank_flat` | `view .flat is not defined for f64[]` | 4e: .flat of a vector (LANGUAGE.md 5.6), at the dot node |
| `err_view_rank_fixed` | `view .row is not defined for i64[2,2]` | 4e: .row of a fixed matrix: the type written as in Sea source (DESIGN.md 2.6.2) |
| `err_rt_tasg_fix` | `shape mismatch: expected 2, got 3` | 4e (Decision 37): a dynamic result of 3 into a fixed `f64[2]` target of a tuple assignment, the run-time check of §4.5 at the statement's line (LANGUAGE.md §7.3) |
| `err_tasg_shape_static` | `shape mismatch: 2 vs 3` | 4e (Decision 37): a fixed `f64[3]` result into a fixed `f64[2]` target, 217 at the target, the target's shape first (DESIGN.md §3.5.5) |
| `err_tasg_type` | `type mismatch: expected f64[], found bool[]` | 4e (Decision 37): a `bool[]` result into an `f64[]` target, 201 at the target (DESIGN.md §3.5.5) |
| `err_rt_tasg_fix_cvt` | `shape mismatch: expected 3, got 4` | 4e (Decision 37): a dynamic `i64[]` result of 4 into a fixed `f64[3]` target, the run-time shape check at the statement's line (the conversion cannot fail) |
| `err_find_desc_unknown` | `unknown parameter` | 4f, re-derived in 6b (224 at the narg, L-by): find(m, desc: true): find takes no named argument |
| `err_find_f64` | `no overload of 'find_last' accepts (f64[])` | 4f: find of an f64 vector (bool vectors only, LANGUAGE.md 10.6) |
| `err_red_argmax_dim` | `unknown parameter` | 4f, re-derived in 6b: argmax(A, dim: 0): argmax takes no dim:, so 224 at the narg, never 243 (LANGUAGE.md 10.5, DESIGN.md 2.11.2) |
| `err_red_desc_twice_unknown` | `unknown parameter` | 4f, re-derived in 6b: a repeated name the function does not take is 224 at its first narg, which precedes the second one's 225 |
| `err_red_desc_unknown` | `unknown parameter` | 4f, re-derived in 6b: sum(v, desc: true): desc is not a name of sum: 224 at the narg (DESIGN.md 2.11.2) |
| `err_red_dim_bool` | `type mismatch: expected i64, found bool` | 4f: dim: true: 201, expected i64, found bool |
| `err_red_dim_f64` | `type mismatch: expected i64, found f64` | 4f: dim: 0.0: type mismatch, expected i64 (201) at the value (LANGUAGE.md 10.5) |
| `err_red_dim_fixed_shape` | `shape mismatch: 3 vs 4` | 4f: sum(F, dim: 0) of a fixed f64[3,4] is an f64[4]: bound to f64[3] it is the static shape mismatch 3 vs 4 at the value (Decision 39, DESIGN.md 3.5.5) |
| `err_red_dim_fixed_type` | `type mismatch: expected i64[2], found f64[2]` | 4f: mean(I, dim: 1) of a fixed i64[2,3] is an f64[2]: bound to i64[2] it is 201 (Decision 39: the function's result element type) |
| `err_red_dim_not_const` | `not a constant expression` | 4f: dim: k with a local k (= 0): not a constant expression (237) at the value |
| `err_red_dim_order_201_237` | `type mismatch: expected i64, found f64` | 4f: dim: x with an f64 local x: not constant and not i64; the type (201) is checked first (LANGUAGE.md 10.5, DESIGN.md 2.6.2) |
| `err_red_dim_order_201_262` | `type mismatch: expected i64, found f64` | 4f: dim: 2.0: of the wrong type and value: 201 first |
| `err_red_dim_order_237_262` | `not a constant expression` | 4f: dim: k with a local k = 5: not constant and not 0 or 1: 237 before 262 |
| `err_red_dim_twice` | `parameter given twice` | 4f: a repeated dim: is parameter given twice (225) at the second narg (DESIGN.md 2.6.2) |
| `err_red_dim_twice_value_first` | `undeclared name 'qq'` | 4f: the arguments are checked in source order, each value before its narg: the second dim:'s value qq is undeclared (200) before that narg's 225 (DESIGN.md 2.6.2) |
| `err_red_dim_value` | `dim must be 0 or 1` | 4f: dim: 2 is dim must be 0 or 1 (262) at the value (LANGUAGE.md 10.5) |
| `err_red_dim_value_before_call` | `dim must be 0 or 1` | 4f: sum(v, dim: 2) of a vector: the arguments are checked before the call, so the value's 262 comes before the call's 243 (DESIGN.md 2.6.2) |
| `err_red_dim_value_const` | `dim must be 0 or 1` | 4f: dim: D with const D = -1: a constant expression of the wrong value, 262 |
| `err_red_dim_value_expr` | `dim must be 0 or 1` | 4f: dim: 1 + 1 is the constant 2: 262 at the value, the + node at its first token (DESIGN.md 3.3) |
| `err_red_dim_vector` | `no overload of 'sum' accepts (f64[], dim: i64)` | 4f: sum(v, dim: 0) of a vector: dim: goes with a matrix only (LANGUAGE.md 10.5) |
| `err_red_dim_vector_fixed` | `no overload of 'max' accepts (f64[3], dim: i64)` | 4f: max of a fixed f64[3] with dim: 1: the fixed type spelled f64[3] |
| `err_red_matrix_nodim` | `no overload of 'sum' accepts (f64[,])` | 4f: sum of a matrix without dim: (reduce it with dim: or through A.flat) |
| `err_red_nnz_f64` | `no overload of 'nnz' accepts (f64[])` | 4f: nnz of an f64 vector (bool vectors only) |
| `err_red_no_arg` | `no overload of 'any' accepts ()` | 4f: any(): no argument |
| `err_red_sum_bool` | `no overload of 'sum' accepts (bool[])` | 4f: sum of a bool vector (LANGUAGE.md 10.5: f64 and i64 vectors only) |
| `err_red_two_positional` | `no overload of 'mean' accepts (f64[], f64[])` | 4f: mean(v, v): a second positional argument |
| `err_sort_bool` | `no overload of 'argsort' accepts (bool[], desc: bool)` | 4f: argsort of a bool vector (f64, i64 and str vectors only, LANGUAGE.md 10.6) |
| `err_sort_desc_twice` | `parameter given twice` | 4f: a repeated desc: is 225 at the second narg |
| `err_sort_desc_type` | `type mismatch: expected bool, found i64` | 4f: desc: 1 is not a bool: 201 at the value (LANGUAGE.md 10.6, DESIGN.md 2.6.2) |
| `err_sort_dim_unknown` | `unknown parameter` | 4f, re-derived in 6b: sort(v, dim: 0): dim is not a name of sort |
| `err_sort_matrix` | `no overload of 'sort' accepts (f64[,])` | 4f: sort of a matrix (vectors only, LANGUAGE.md 10.6) |
| `err_sort_positional_after_named` | `positional argument after a named argument` | 4f: sort(desc: true, v): a positional argument after a named one, 115 of pass 1 at that argument (LANGUAGE.md 8.1, Decision 41) |
| `err_sort_positional_first` | `positional argument after a named argument` | 4f: 115 is pass 1's: reported before a pass-2 error earlier in the source (an undeclared name on line 3; LANGUAGE.md 9.1, DESIGN.md 2.6.2) |
| `err_sort_positional_option` | `no overload of 'sort' accepts (f64[], bool)` | 4f: sort(v, true): options are given only by name (LANGUAGE.md 8.1, Decision 43) |
| `r_red_argmax_empty` | `argmax of an empty array` | 4f: argmax of an empty vector made at run time (a selection of nothing) |
| `r_red_argmin_empty` | `argmin of an empty array` | 4f: argmin of an empty vector: the function's name in the message (DESIGN.md 2.6.2) |
| `r_red_max_dim_empty` | `max of an empty array` | 4f: max(Z, dim: 0) of a 0 x 3 matrix: each column has 0 elements, the vector rule's error (LANGUAGE.md 10.5) |
| `r_red_max_empty` | `max of an empty array` | 4f: max of an empty vector (LANGUAGE.md 10.5, 9.2): `max of an empty array` |
| `r_red_mean_ovf` | `integer overflow` | 4f: mean of the same i64 vector: its sum is checked the same way (LANGUAGE.md 10.5) |
| `r_red_min_dim1_empty` | `min of an empty array` | 4f: min(Z, dim: 1) of a 3 x 0 matrix: each row has 0 elements (LANGUAGE.md 10.5) |
| `r_red_min_empty` | `min of an empty array` | 4f: min of an empty i64 vector (LANGUAGE.md 10.5) |
| `r_red_sum_dim_ovf` | `integer overflow` | 4f: sum(I, dim: 1): row 0 fits (1), row 1 overflows at its second element; every element of a dim: result follows the vector rule (LANGUAGE.md 10.5) |
| `r_red_sum_ovf` | `integer overflow` | 4f: i64 sum of 2^62, 2^62, -2^62: the total 2^62 fits, but the second partial sum 2^63 overflows (LANGUAGE.md 10.5, Decision 42): integer overflow at the call's line, the line printed before it flushed |
| `r_red_sum_ovf_neg` | `integer overflow` | 4f: -2^62, -2^62, -1, 1: the partial sum -2^63 fits, the third -2^63 - 1 overflows (LANGUAGE.md 10.5) |
| `r_red_var_ovf` | `integer overflow` | 4f: variance of an i64 vector uses the i64 mean, whose checked sum overflows (LANGUAGE.md 10.5) |
| `err_args_arg` | `no overload of 'args' accepts (i64)` | 4g-1: args(1): args takes no argument (243, as now(1); L-d) |
| `err_const_str_part_too_long` | `program too large: strings` | 4g-1: a part of 4 200 bytes inside a `bool` constant (`"a…" + "b…" < "c"`) is 400 at the `const` (L-f covers every value computed while evaluating) |
| `err_const_str_too_long` | `program too large: strings` | 4g-1: a `str` constant joining two literals of 2 100 bytes each (4 200 > 4 096) is 400 at the `const` (LANGUAGE.md 7.2; L-f) |
| `err_error_fmt_arg` | `format "%d" expects an integer or f64, found str` | 4g-1: error("bad %d", "x"): 210 at the argument |
| `err_error_fmt_count` | `format "%s and %s" expects 2 arguments, found 1` | 4g-1: 211 at the error call |
| `err_error_fmt_literal` | `format must be a string literal` | 4g-1: error(f, 1) with a `str` local f: 233 at the argument |
| `err_error_missing_return` | `missing return` | 4g-1: `fn f() -> i64 { error("x") }`: error does not end a path (LANGUAGE.md 8.1; the information item of DESIGN.md §0) |
| `err_lower_array` | `no overload of 'lower' accepts (str[])` | 4g-1: lower of a str[] (scalars only, Decision 46) |
| `err_lower_int` | `no overload of 'lower' accepts (i64)` | 4g-1: lower(1) |
| `err_lower_none` | `no overload of 'lower' accepts ()` | 4g-1: lower() (L-d) |
| `err_lower_two` | `no overload of 'lower' accepts (str, str)` | 4g-1: lower("a", "b") (L-d) |
| `err_match_after_wild` | `unreachable pattern` | 4g-1: a string arm after a `_` arm in a match that ends with `_`: 208 at that arm (its first pattern) |
| `err_match_before_scrut` | `match is not exhaustive` | 4g-1: 207 at the `match` keyword is reported before an undeclared name in the scrutinee (L-a) |
| `err_match_dup_across` | `unreachable pattern` | 4g-1: a pattern of an earlier arm repeated: 208 at the later arm |
| `err_match_dup_in_arm` | `unreachable pattern` | 4g-1: `"a" \| "b" \| "a"`: 208 at that arm |
| `err_match_no_arms` | `match is not exhaustive` | 4g-1: a match with no arm (LANGUAGE.md 7.6) |
| `err_match_no_wild` | `match is not exhaustive` | 4g-1: no `_` arm: 207 at the match |
| `err_match_scrut_type` | `type mismatch: expected str, found i64` | 4g-1: an `i64` scrutinee: 201 at the scrutinee |
| `err_match_second_wild` | `unreachable pattern` | 4g-1: a second `_` arm: 208 at it |
| `err_match_wild_not_last` | `match is not exhaustive` | 4g-1: `_` followed by a string arm: 207 at the match, before the arm's 208 (LANGUAGE.md 7.6) |
| `err_str_add_int` | `operator '+' cannot be applied to str and i64` | 4g-1: "a" + 1 (240 at the operator node) |
| `err_str_array` | `no overload of 'str' accepts (f64[])` | 4g-1: str(v) of an array (243 at the conversion node; Decision 46) |
| `err_str_ew_cmp_f64` | `operator '==' cannot be applied to str[] and f64` | 4g-1: names == 1.0 (Decision 45) |
| `err_str_let_int` | `type mismatch: expected str, found i64` | 4g-1: let s: str = 1 (201 at the value) |
| `err_str_mul` | `operator '*' cannot be applied to str and i64` | 4g-1: s * 2 (240) |
| `err_str_neg` | `operator '-' cannot be applied to str` | 4g-1: -s (241 at the neg node) |
| `err_str_noarg` | `unexpected token ')'` | 4g-1: str(): `conv_type "(" expr ")"` needs an expression (LANGUAGE.md Appendix A; DESIGN.md 3.4: `conv` pops 1), a pass-1 syntax error at the `)` |
| `err_str_sub` | `operator '-' cannot be applied to str and str` | 4g-1: "a" - "b" (240) |
| `r_args_oob` | `index 0 out of bounds for dimension 0 of extent 0` | 4g-1: args()[0] without arguments, at its line, after flushed output |
| `r_error_after_output` | `stopped at 3` | 4g-1: error after printed output: `before\npartial` flushed with no extra newline, then the message (LANGUAGE.md 9.2, 9.3) |
| `r_error_fmt` | `bad abcdef [   ab\|x   ] -7 2.500 NaN 1.500000e+03 %` | 4g-1: error formats like format: `%s` of dynamic strings with width and `-`, `%d %.3f %g %e`, NaN, `%%` |
| `r_error_in_fn` | `negative: -3` | 4g-1: error inside a function: the line of the error call |
| `r_error_match_arm` | `unknown surface finish "polished"` | 4g-1: error in a `_` arm (LANGUAGE.md 7.6's example) |
| `r_error_plain` | `plain` | 4g-1: error with no argument, in a loop after output |
| `r_str_ew_shape` | `shape mismatch: 3 vs 2` | 4g-1: `a + b` of two `str[]` of lengths 3 and 2, at the operator's line (Decision 45) |
| `err_record_arg_struct` | `type mismatch: expected P, found {x: f64, y: f64}` | 4g-2: a record with P's field names passed to a `P` parameter (201 at the argument, Decision 48) |
| `err_record_dup_field` | `duplicate field` | 4g-2: `{ a: 1, b: 2, a: 3 }` (205 at the second init, L-b) |
| `err_record_into_struct` | `type mismatch: expected P, found {a: i64}` | 4g-2: `let p: P = { a: 1 }` (201 at the value) |
| `err_record_no_field` | `no field 'b' in {a: i64, s: str}` | 4g-2: a field a record lacks (249 at the dot) |
| `err_record_reserved` | `field name reserved for views` | 4g-2: `{ a: 1, flat: 2 }` (222 at the init, L-b) |
| `err_struct_assign_let` | `cannot assign to immutable 'p'` | 4g-2: `p.x = 3.0` of a `let` struct (238 at the target) |
| `err_struct_assign_let_elem` | `cannot assign to immutable 'a'` | 4g-2: `a[0].y = 3.0` of a `let` array (238 at the target, the root's name) |
| `err_struct_dup_field` | `duplicate field` | 4g-2: a field initialised twice in a struct literal (205 at the second init) |
| `err_struct_eq` | `operator '==' cannot be applied to P and P` | 4g-2: `p == q` (240 at the bin node, its left operand) |
| `err_struct_mat_field` | `no field 'x' in P[,]` | 4g-2: `.x` of a `P[,]` (249, L-c) |
| `err_struct_missing_field` | `missing field 'y' in P literal` | 4g-2: `P { x: 1.0 }` (204 at the slit) |
| `err_struct_no_field` | `no field 'z' in P` | 4g-2: `p.z` (249 at the dot) |
| `err_struct_proj_array` | `cannot project field 'v' of type f64[]` | 4g-2: projection of an array field (256) |
| `err_struct_proj_struct` | `cannot project field 'lim' of type Lim` | 4g-2: projection of a struct field (256) |
| `err_struct_proj_target` | `invalid assignment target` | 4g-2: `dims.nom = nv` (239 at the target) |
| `err_struct_recursive` | `recursive struct` | 4g-2: a field of the struct's own type (221 at the struct) |
| `err_struct_recursive_fixed` | `recursive struct` | 4g-2: through a `P[2]` field (221) |
| `err_struct_recursive_mutual` | `recursive struct` | 4g-2: `A` holds `B`, `B` holds `A[]`: both recursive, `A` reported (221) |
| `err_struct_recursive_vec` | `recursive struct` | 4g-2: through a `P[]` field (221) |
| `err_struct_redef_field` | `redefinition of 'x'` | 4g-2: two fields of one name (235 at the later field) |
| `err_struct_reserved` | `field name reserved for views` | 4g-2: a struct field named `T` (222 at the field) |
| `err_struct_unknown` | `unknown struct type` | 4g-2: `Q { }` (229 at the slit) |
| `err_struct_unknown_field` | `unknown field` | 4g-2: a literal naming a field P lacks (206 at that init) |
| `manualD_part1_badopt` (`.args`) | `unknown option "--bogus"` | 4g-2: `manualD_part1` with `--bogus`: the error at line 16 (the options loop's `_` arm), standard output empty |
| `r_str_fix` | `shape mismatch: expected 3, got 2` | 4g-2: a `str[]` of 2 bound to a `str[3]`, at its line, after flushed output |
| `r_struct_dollar_outer` | `index 5 out of bounds for dimension 0 of extent 2` | 4g-2: `a[5].v[$ - 1] = 1.0` on a `D[]` of 2: the outer index is checked before the inner `$` (which needs `a[5]`) is evaluated (LANGUAGE.md 5.3–5.5), after flushed output |
| `r_struct_dollar_inner` | `index 2 out of bounds for dimension 0 of extent 2` | 4g-2: `a[0].v[$] += 1.0`: `$` is `len(a[0].v)` = 2, the compound store's read fails (LANGUAGE.md 5.3–5.5), after flushed output |
| `err_prel_missing_arg` | `missing argument` | 4h: `linspace(0.0, 1.0)` (226 at the call, L-t) |
| `err_prel_too_many` | `too many arguments` | 4h: `linspace(0.0, 1.0, 2, 3)` (242 at the call, L-t) |
| `err_prel_linspace_n_f64` | `type mismatch: expected i64, found f64` | 4h: `linspace(0.0, 1.0, 2.5)` (201 at the argument, L-t) |
| `err_prel_bincount_f64` | `type mismatch: expected i64[], found f64[1]` | 4h: `bincount([1.0], 2)`, the literal fixed-size (201 at it, L-t) |
| `err_prel_setdiff_f64` | `type mismatch: expected i64[], found f64[1]` | 4h: `setdiff([1.5], [1])` (201 at the first argument, L-t) |
| `err_prel_meshgrid_matrix` | `type mismatch: expected f64[], found f64[,]` | 4h: `meshgrid(A, y)` with a matrix A (201 at A, L-t, Decision 54) |
| `err_prel_ref` | `'idx' is not a ref parameter` | 4h: `bincount(ref v, 2)` (255 at the `ref`, LANGUAGE.md's parameter name, L-t) |
| `err_prel_redef_fn` | `redefinition of predeclared name` | 4h: a program `fn bincount` (212 at the item; the prelude's items are exempt, L-s) |
| `err_prel_redef_const` | `redefinition of predeclared name` | 4h: a program `const linspace` (212 at the item, L-s) |
| `err_prel_shadow_local` | `local name shadows a predeclared name` | 4h: `let setdiff = 1` (213 at the name, L-s) |
| `err_prel_shadow_param` | `local name shadows a predeclared name` | 4h: a parameter named `meshgrid` (213 at the param, L-s) |
| `err_prel_shadow_for` | `local name shadows a predeclared name` | 4h: `for bincount in 0..3` (213 at the `for`, L-s) |
| `err_ns_matmul` | `not supported yet: @` | 4h close-out (L-z): `A @ B` of two matrices, at the operator node (its left operand) until phase 8 |
| `err_ns_lib_solve` | `not supported yet: solve` | 4h close-out (L-z): a call of `solve`, at the call, until phase 8 |
| `err_ns_lib_figure` | `not supported yet: figure` | 4h close-out (L-z): a call of `figure`, at the call, until phase 9 |
| `r_prel_bincount_oob` | `index 3 out of bounds for dimension 0 of extent 2` | 4h: a value outside 0 … n − 1 after printed output, at the call's line (L-y) |
| `r_prel_bincount_neg_idx` | `index -1 out of bounds for dimension 0 of extent 2` | 4h: the first bad value in index order is −1 |
| `r_prel_bincount_fn` | `index 2 out of bounds for dimension 0 of extent 2` | 4h: the call inside a user function: that call's line, never a prelude line |
| `r_prel_bincount_size` | `invalid array size -2` | 4h: n = −2, from the allocation of the result (L-y) |
| `r_prel_bincount_size_big` | `invalid array size 3000000000` | 4h: n above 2³¹ − 1, reported before the out-of-range value 5 (the result is allocated first, DESIGN.md §2.5) |
| `r_prel_linspace_size` | `invalid array size 3000000000` | 4h: `linspace` with n above 2³¹ − 1 (LANGUAGE.md §10.3, L-y) |
| `r_prel_meshgrid_oom` | `out of memory` | 4h: `meshgrid` of two 10⁷-element vectors (results of 8·10¹⁴ bytes), at the call's line (L-y) |
| `r_opt_oob_iter` | `index 4 out of bounds for dimension 1 of extent 4` | 5c-1: a loop printing a line per iteration, then `A[1, j]` out of bounds at j = 4: the lines before, then the error |
| `r_opt_oob_while` | `index 4 out of bounds for dimension 0 of extent 4` | 5c-1: a `while` loop storing `v[i]`, the store at i = 4 |
| `r_opt_ovf_then_oob` | `integer overflow` | 5c-1: an overflow and an index error in the same iteration, the overflow first in the body |
| `r_opt_oob_then_ovf` | `index 4 out of bounds for dimension 0 of extent 4` | 5c-1: the same with the index first |
| `r_opt_ovf_oob_expr` | `integer overflow` | 5c-1: `(x + i) + v[i]`: the left operand overflows before the index is evaluated |
| `r_opt_oob_ovf_expr` | `index 4 out of bounds for dimension 0 of extent 4` | 5c-1: `v[i] + (x + i)`: the index first |
| `r_opt_jp1_last` | `index 5 out of bounds for dimension 0 of extent 5` | 5c-1: `v[j + 1]` over `0..n` fails at its last iteration |
| `r_opt_jm1_first` | `index -1 out of bounds for dimension 0 of extent 3` | 5c-1: `v[j - 1]` over `0..n` (a parameter) fails at its first iteration, after an earlier call with n = 0 |
| `r_opt_range_max` | `integer overflow` | 5c-1: a range ending at 2⁶³ − 1 with `i + 1` in the body: the last iteration (T1 keeps the check) |
| `r_opt_range_min` | `integer overflow` | 5c-1: a range counting down to −2⁶³ with `i - 1`: the last iteration |
| `r_opt_mul_last` | `integer overflow` | 5c-1: `i * i` over 3037000498 ..= 3037000500: the last square |
| `r_opt_neg_min` | `integer overflow` | 5c-1: `-x` over elements, −2⁶³ the third |
| `r_opt_step2_last` | `index 6 out of bounds for dimension 0 of extent 6` | 5c-1: `0..=6 step 2` over 6 elements |
| `r_opt_stepneg_last` | `index -1 out of bounds for dimension 0 of extent 4` | 5c-1: `3..=-1 step -1`, after four lines |
| `r_opt_empty_fact` | `index -1 out of bounds for dimension 0 of extent 0` | 5c-1: `a[n - 1]` after an empty `for i in 0..n` with n = 0, in a function (F3, F6) |
| `r_opt_empty_fact0` | `index -1 out of bounds for dimension 0 of extent 0` | 5c-1: the same in the main program with the constant n = 0 |
| `r_opt_break_fact` | `index 3 out of bounds for dimension 0 of extent 3` | 5c-1: an index narrowed by two `break` tests in a `while true` loop, used after it with the excluded value |
| `r_opt_guard_fact` | `index 3 out of bounds for dimension 0 of extent 3` | 5c-1: a fact of nested guards on a parameter not used after their `endif`s; an early-return guard beside it |
| `r_opt_guard_wide` | `index 4 out of bounds for dimension 0 of extent 4` | 5c-1: a guard `k >= 0 && k < 10` around `v[k]` for a 4-element v: the check stays (F5) |
| `r_opt_loop_fact` | `index 5 out of bounds for dimension 0 of extent 5` | 5c-1: `j = i` inside a loop, `v[j + 1]` after it |
| `r_opt_inv_arm` | `index 5 out of bounds for dimension 0 of extent 3` | 5c-1/5c-2: a check in an arm whose condition is loop-invariant and true: after the first iteration's line, never before it (T8, T9) |
| `r_opt_ref_err` | `index 3 out of bounds for dimension 0 of extent 3` | 5c-1/5c-2: a `ref` scalar updated and printed in a loop, an index error part-way (T5, L-ag) |
| `r_opt_cow_err` | `index 3 out of bounds for dimension 0 of extent 3` | 5c-1/5c-2: a loop storing into a shared array and printing both, an index error at i = 3 |
| `r_opt_mod_zero` | `integer division by zero` | 5c-1: `x % 0` with a constant 0, at its line (T2 leaves it) |
| `r_opt_idiv_zero` | `integer division by zero` | 5c-1: `idiv(x, 0)` with a constant 0 |
| `r_opt_idiv_min` | `integer overflow` | 5c-1: `idiv(x, -1)` with x = −2⁶³ after `x % -1` gave 0 |
| `r_opt_vn_ovf` | `integer overflow` | 5c-1: two equal checked additions, the first overflows: its own line (T3) |
| `r_opt_struct_ovf` | `integer overflow` | 5c-1 (regression for a `seaopt` defect): `p.c + 1` on the `i64` field of a struct parameter holding 2⁶³ − 1, at that line, after a call that does not overflow |
| `r_opt_fixarr_ovf` | `integer overflow` | 5c-1 (the same defect): `v[2] + 1` on an element of a fixed-size `i64[3]` parameter holding 2⁶³ − 1 |
| `r_opt_eq_ovf` | `integer overflow` | 5c-1 (negated `==` facts): `x + 1` after an early return on `x == 0`, with x = 2⁶³ − 1 |
| `r_opt_eq_oob` | `index 7 out of bounds for dimension 0 of extent 3` | 5c-1: `v[k]` of a fixed `[10, 20, 30]` after the early returns `k < 0` and `k == 2` |
| `r_opt_eq_oob_dyn` | `index 3 out of bounds for dimension 0 of extent 3` | 5c-1: the same over `filled(10, 3)` |
| `r_opt_ne_ovf` | `integer overflow` | 5c-1: `x - 1` in the `else` part of `x != -2⁶³` |
| `r_opt_ne_oob` | `index -1 out of bounds for dimension 0 of extent 3` | 5c-1: `v[k]` after `k >= 3` and `k != -1` returned (k is −1 there) |
| `r_opt_eq_else` | `index 4 out of bounds for dimension 0 of extent 3` | 5c-1: `v[k]` in the explicit `else` part of `k == 2` |
| `r_opt_eq_ifz` | `index 4 out of bounds for dimension 0 of extent 3` | 5c-1: `v[k]` under `k >= 0` and `!(k == 2)` |
| `r_opt_eq_or` | `index 5 out of bounds for dimension 0 of extent 3` | 5c-1: `v[k]` after `k == 2 \|\| k < 0` returned |
| `r_opt_eq_call` | `index 5 out of bounds for dimension 0 of extent 3` | 5c-1: the `==` guard in a function with a loop and three call sites (a real call) |
| `r_opt_ne_loop` | `index 3 out of bounds for dimension 0 of extent 3` | 5c-1: a `while true` loop left by `break` on `k == 2`, `v[k]` under `k >= 0` with k = 1, 3 |
| `r_opt_eq_loop_else` | `index 3 out of bounds for dimension 0 of extent 3` | 5c-1: the same with the read in the explicit `else` part |
| `r_opt_ne_loop_else` | `index -1 out of bounds for dimension 0 of extent 3` | 5c-1: `while k < 3` reading `v[k]` in the `else` part of `k != -1` |
| `r_opt_ne_cont` | `index -1 out of bounds for dimension 0 of extent 3` | 5c-1: `k != -1` prints and continues, then `v[k]` with k = −1 |
| `r_opt_hoist_after` | `index 7 out of bounds for dimension 0 of extent 3` | 5c-2 (T8): `v[bad]` in a loop run zero times and again after it: the error after the loop, at its line |
| `r_opt_hoist_far` | `index 1000000000 out of bounds for dimension 0 of extent 3` | 5c-2 (T8): an invariant constant index 10⁹ after the iteration's line: `iter 0`, then the error (the load never precedes its check) |
| `r_opt_hoist_empty` | `index 2 out of bounds for dimension 0 of extent 0` | 5c-2 (T8, L-at): `e[k]` with an invariant k on a 4-element and then an empty parameter |
| `r_opt_hoist_ovf` | `integer overflow` | 5c-2 (T8): an invariant `big + 100` in a `while` after the iteration's line |
| `r_opt_hoist_div` | `integer division by zero` | 5c-2 (T8): invariant `idiv(a, z)` and `a % z`, z = 5 then z = 0 |
| `r_opt_hoist_ftoi` | `conversion to i64: 2.5 is not an integer` | 5c-2 (T8): an invariant `i64(x)`: 4.0 converts, 2.5 in a loop run zero times does not fail, then fails after the first line |
| `r_opt_hoist_field` | `index 5 out of bounds for dimension 0 of extent 3` | 5c-2 (T8, L-at): `b.vals[k]` through a `ref` struct whose other field the loop writes |
| `r_opt_hoist_order1` | `index 2 out of bounds for dimension 0 of extent 2` | 5c-2 (T8): two invariant failing operations, the index first: the index error |
| `r_opt_hoist_order2` | `integer overflow` | 5c-2 (T8): the same with the overflow first |
| `r_opt_unswitch_nan` | `index 4 out of bounds for dimension 0 of extent 4` | 5c-2 (T9): an `if` expression on an invariant `a == b`; with NaN the second arm runs and fails at i = 2 |
| `r_opt_unswitch_ne` | `index 3 out of bounds for dimension 0 of extent 3` | 5c-2 (T9): an invariant `a != b` (true for NaN) with a nested invariant flag; the arm with `w[i + k]` fails at i = 2 |
| `r_opt_ifexpr_arm` | `index 3 out of bounds for dimension 0 of extent 3` | 5c-2 (T4, T9): an `if` expression on an invariant `bool`: the wrapping arm works, the other fails at the last i |
| `r_opt_sr_stride` | `index 7 out of bounds for dimension 1 of extent 6` | 5c-2 (T7): `A[2, 2 * j + 1]` over a 3 × 6 matrix, at j = 3 |
| `r_opt_sr_rev` | `index -1 out of bounds for dimension 0 of extent 4` | 5c-2 (T7): `v[n - 1 - j]` over `0..=n`, at the last iteration |
| `r_opt_sr_wrap` | `integer overflow` | 5c-2 (T7): `w[j + t - t]` with t = 2⁶³ − 3: `j + t` overflows at j = 3 (a checked chain is not reduced) |
| `r_opt_sr_kstride` | `index 10 out of bounds for dimension 0 of extent 8` | 5c-2 (T7): `v[j * k + 1]` with an invariant register k = 3 |
| `r_opt_sr_step_neg` | `index -2 out of bounds for dimension 1 of extent 11` | 5c-2 (T7): `A[1, j]` for `j in 10..=-2 step -3` |
| `r_opt_sr_row` | `index 4 out of bounds for dimension 0 of extent 4` | 5c-2 (T7): `A[j + 1, i]` in nested loops, row 4 in the first column |
| `r_opt_sr_store` | `index 6 out of bounds for dimension 0 of extent 5` | 5c-2 (T7): the store `v[2 * j] = j` at j = 3, after that iteration's line |
| `r_opt_promote_struct` | `index 2 out of bounds for dimension 0 of extent 2` | 5c-2 (T5, L-ag): `ref` struct fields updated and printed in a loop, the second call failing part-way |
| `r_opt_promote_ovf` | `integer overflow` | 5c-2 (T5): a `ref` scalar doubled in a nested loop, printed after each inner loop, overflowing in the second call |
| `r_opt_cow_ver_err` | `index 3 out of bounds for dimension 0 of extent 3` | 5c-2 (T6): a `ref` array filled in a loop, unshared at the first call, shared with a `let` at the second, which prints both and fails at i = 3 |
| `err_predeclared_const` | `redefinition of predeclared name` | a constant may not take a predeclared name (LANGUAGE.md 3.3) |
| `err_predeclared_fn` | `redefinition of predeclared name` | a top-level function may not take a predeclared name (LANGUAGE.md 3.3) |
| `err_redefinition_const` | `redefinition of 'C'` | two constants of one name (DESIGN.md 2.6.2) |
| `err_redefinition_const_fn` | `redefinition of 'f'` | a function and a constant of one name; at the later one (DESIGN.md 2.6.2) |
| `err_redefinition_fn` | `redefinition of 'f'` | two functions of one name; at the later one (DESIGN.md 2.6.2) |
| `err_redefinition_fn_const` | `redefinition of 'g'` | a constant, then a function of the same name (DESIGN.md 2.6.2) |
| `err_redefinition_param` | `redefinition of 'a'` | two parameters of one name; at the second (DESIGN.md 2.6.2) |
| `err_ref_alias` | `ref argument aliases another argument` | two ref arguments with the same root (LANGUAGE.md 8.3; at the first ref) |
| `err_ref_alias_value` | `ref argument aliases another argument` | a ref argument whose root another argument shares (LANGUAGE.md 8.3) |
| `err_ref_needed` | `argument for ref parameter 'x' must be marked ref` | an argument for a ref parameter must say ref (DESIGN.md 2.6.2; at expr) |
| `err_ref_target_fn` | `ref argument must be a mutable variable, element or field` | a function name as a ref argument: at the ref (LANGUAGE.md 8.3) |
| `err_ref_target_let` | `ref argument must be a mutable variable, element or field` | a let cannot be passed to a ref parameter (LANGUAGE.md 7.2, 8.3; at the ref) |
| `err_ref_target_param` | `ref argument must be a mutable variable, element or field` | an ordinary parameter is immutable: not a ref argument (LANGUAGE.md 8.2, 8.3) |
| `err_ref_unexpected` | `'a' is not a ref parameter` | ref on an argument of an ordinary parameter (DESIGN.md 2.6.2; at the ref) |
| `err_result_count_annot` | `wrong number of results: expected 2, found 1` | an annotated let of a 2-result call: at the call, before any conversion (LANGUAGE.md 8.4) |
| `err_result_count_let` | `wrong number of results: expected 2, found 1` | a 2-result call bound to one name: at the call (LANGUAGE.md 8.4; DESIGN.md 2.6.2) |
| `err_result_count_ptuple` | `wrong number of results: expected 2, found 3` | three names for two results: at the ptuple (LANGUAGE.md 8.4) |
| `err_result_count_return` | `wrong number of results: expected 1, found 2` | two values returned from a function with one result: at the return |
| `err_result_count_skip_annot` | `wrong number of results: expected 2, found 1` | let _: f64 = two() binds one value: at the call (LANGUAGE.md 7.2 R9, 8.4) |
| `err_result_count_tasg` | `wrong number of results: expected 3, found 2` | a tuple assignment with one target too few: at the tasg (LANGUAGE.md 7.3, 8.4) |
| `err_result_count_void` | `wrong number of results: expected 0, found 2` | return f() of a 2-result call in a function without results (LANGUAGE.md 8.4) |
| `err_result_count_void_value` | `wrong number of results: expected 0, found 1` | a call without results used as a value: at the call (LANGUAGE.md 8.4) |
| `err_rt_conv_below` | `conversion to i64: -9.22337e+18 is not an integer` | i64() of the f64 just below -2^63 is out of range (LANGUAGE.md 9.2) |
| `err_rt_conv_frac` | `conversion to i64: 1.5 is not an integer` | i64() of a non-integral value (LANGUAGE.md 4.2; %g spelling) |
| `err_rt_conv_inf` | `conversion to i64: Inf is not an integer` | i64() of +Inf (LANGUAGE.md 9.2; Inf spelled as printf %g) |
| `err_rt_conv_nan` | `conversion to i64: NaN is not an integer` | i64() of NaN (LANGUAGE.md 4.2; NaN spelled as printf %g) |
| `err_rt_conv_neginf` | `conversion to i64: -Inf is not an integer` | i64() of -Inf (LANGUAGE.md 9.2) |
| `err_rt_conv_range` | `conversion to i64: 9.22337e+18 is not an integer` | i64() of 2^63, integral but out of range (LANGUAGE.md 9.2) |
| `err_rt_div_zero_idiv` | `integer division by zero` | idiv by zero (LANGUAGE.md 6.6) |
| `err_rt_div_zero_mod` | `integer division by zero` | i64 % by zero (LANGUAGE.md 6.5) |
| `err_rt_epipe_final` | `cannot write '<stdout>': Broken pipe` (.meta) | the final flush to a closed pipe fails: no location (LANGUAGE.md 9.2) |
| `err_rt_epipe_loop` | `cannot write '<stdout>': Broken pipe` (.meta) | a buffer flush during printf fails: at that printf's line (LANGUAGE.md 9.2) |
| `err_rt_idiv_zero_min` | `integer division by zero` | idiv(-2^63, 0) is a division by zero, not an overflow (LANGUAGE.md 6.6) |
| `err_rt_in_fn` | `integer division by zero` | a run-time error in a function reports the line of the failing expression |
| `err_rt_mod_zero_min` | `integer division by zero` | -2^63 % 0 is a division by zero (LANGUAGE.md 6.6) |
| `err_rt_overflow_add` | `integer overflow` | i64 + overflow (LANGUAGE.md 6.5) |
| `err_rt_overflow_compound` | `integer overflow` | x += 1 overflows like x + 1 (LANGUAGE.md 7.3, 6.5) |
| `err_rt_overflow_const` | `integer overflow` | a constant i64 sum that overflows is not folded: it fails at run time |
| `err_rt_overflow_idiv` | `integer overflow` | idiv(-2^63, -1) overflows (LANGUAGE.md 6.6) |
| `err_rt_overflow_mul` | `integer overflow` | i64 * overflow (LANGUAGE.md 6.5) |
| `err_rt_overflow_neg` | `integer overflow` | unary - of -2^63 overflows (LANGUAGE.md 6.5) |
| `err_rt_overflow_sub` | `integer overflow` | i64 - overflow (LANGUAGE.md 6.5) |
| `err_rt_stack_overflow` | `stack overflow` | unbounded recursion: reported at the fn's definition line (DESIGN.md 4.6) |
| `err_rt_stdout_closed` | `cannot write '<stdout>': Bad file descriptor` (.meta) | standard output closed (>&-): the final flush fails (LANGUAGE.md 9.2) |
| `err_rt_step_zero` | `range step is zero` | a range step of zero (LANGUAGE.md 5.1; at the for line) |
| `err_same_pos_priority` | `undeclared name 'q'` | two errors at one position: the inner one first (LANGUAGE.md 9.1) |
| `err_shadow_for` | `local name shadows a predeclared name` | a loop variable that shadows: reported at the for node (DESIGN.md 2.6.2, binding) |
| `err_shadow_for_blanks` | `local name shadows a predeclared name` | a loop variable shadowing a predeclared name, two blanks after for: at the for node (DESIGN.md 2.6.2 binding) |
| `err_shadow_let` | `local name shadows a predeclared name` | a local may not shadow a predeclared name (LANGUAGE.md 3.3; at the pname) |
| `err_shadow_param` | `local name shadows a predeclared name` | a parameter may not shadow a predeclared name (at the param) |
| `err_too_deep` | `program too large: nesting` | 65 nested parentheses: the 65th opening token (DESIGN.md 2.7 nesting depth) |
| `err_too_deep_blocks` | `program too large: nesting` | a block at depth 65: 64 nested blocks inside a function body (DESIGN.md 2.7) |
| `err_too_many_args` | `too many arguments` | more arguments than parameters (LANGUAGE.md 8.1; at the call) |
| `err_too_many_params` | `program too large: parameters` | 65 parameters (SEA_LIM_PARAMS 64; at the 65th parameter) |
| `err_type_mismatch_annot` | `type mismatch: expected i64, found f64` | an annotated var follows its annotation, not the var rule (LANGUAGE.md 4.2) |
| `err_type_mismatch_arg` | `type mismatch: expected i64, found f64` | an f64 argument for an i64 parameter (LANGUAGE.md 4.2) |
| `err_type_mismatch_assign` | `type mismatch: expected i64, found f64` | a var initialised by a typed value keeps its type (LANGUAGE.md 4.2) |
| `err_type_mismatch_bool` | `type mismatch: expected bool, found i64` | an untyped constant where bool is expected is i64 (LANGUAGE.md 4.2) |
| `err_type_mismatch_ifx_arm` | `type mismatch: expected i64, found f64` | typed if-expression arms of different types: at the else arm (LANGUAGE.md 6.10; DESIGN.md 2.6.2) |
| `err_type_mismatch_let` | `type mismatch: expected i64, found f64` | no implicit f64 -> i64 (LANGUAGE.md 4.2; at expr) |
| `err_type_mismatch_return` | `type mismatch: expected i64, found f64` | a return value of the wrong type (DESIGN.md 2.6.2) |
| `err_type_mismatch_tret` | `type mismatch: expected (f64, f64), found (i64, f64)` | return f() needs exactly the same result types (LANGUAGE.md 8.4; at the call) |
| `err_undeclared` | `undeclared name 'nTraget'` | a misspelt name (LANGUAGE.md 9.1) |
| `err_undeclared_before` | `undeclared name 'y'` | a binding is visible from the statement after it (LANGUAGE.md 7.2) |
| `err_undeclared_self` | `undeclared name 'w'` | a binding is not visible in its own initialiser (LANGUAGE.md 7.2) |
| `err_undeclared_toplevel` | `undeclared name 'k'` | top-level bindings are not visible inside functions (LANGUAGE.md 7.2) |
| `err_unexpected_eof` | `unexpected end of file` | the input ends inside an expression: just after the last byte of the last line |
| `err_unexpected_eof_block` | `unexpected end of file` | the input ends inside a block (DESIGN.md 2.6.2, at token) |
| `err_unexpected_newline` | `unexpected newline` | an NL token where the grammar allows none: at the line break (Appendix A) |
| `err_unexpected_newline_bcomment` | `unexpected newline` | a block comment spanning lines: its first LF (DESIGN.md 2.6.2) |
| `err_unexpected_newline_if` | `unexpected newline` | an NL token between an if condition and its block (Appendix A) |
| `err_unexpected_newline_lcomment` | `unexpected newline` | the NL token is the LF after a line comment (DESIGN.md 2.6.2, at token) |
| `err_unexpected_paren` | `unexpected token ')'` | a closing parenthesis where an expression is expected (Appendix A) |
| `err_unexpected_token` | `unexpected token '*'` | a binary operator where an operand is expected (Appendix A) |
| `err_unterminated_comment` | `unterminated comment` | an unterminated block comment, reported at its /* (LANGUAGE.md 3.2) |
| `err_unterminated_string` | `unterminated string` | a string literal may not contain a line break (LANGUAGE.md 3.5; at the ") |
| `err_call6_unknown_user` | `unknown parameter` | 6b: `f(1, zz: 2)`: 224 at the `narg` (LANGUAGE.md §8.1) |
| `err_call6_unknown_only_named` | `unknown parameter` | 6b: `f(zz: 2)`: 224 at the `narg`, before the call's missing argument |
| `err_call6_unknown_lib` | `unknown parameter` | 6b: `sqrt(x: 2.0)`: a library function's positional parameter is no name (L-by) |
| `err_call6_unknown_prel` | `unknown parameter` | 6b: `linspace(0.0, 1.0, m: 3)`: a prelude function takes the names of §10.3 only |
| `err_call6_twice_pos` | `parameter given twice` | 6b: `f(1, a: 2)`: 225 at the `narg` |
| `err_call6_twice_named` | `parameter given twice` | 6b: `f(a: 1, a: 2)`: 225 at the second `narg` |
| `err_call6_twice_prel` | `parameter given twice` | 6b: `linspace(0.0, 1.0, 3, n: 2)`: 225 at the `narg` |
| `err_call6_missing_skip` | `missing argument` | 6b: `f(1, c: 3)` with `b` neither given nor defaulted: 226 at the call |
| `err_call6_default_order` | `parameter needs a default value` | 6b: `fn f(a: i64 = 1, b: i64)`: 236 at the `param` (its name) |
| `err_call6_ref_default` | `ref argument must be a mutable variable, element or field` | 6b: `fn f(ref x: i64 = 1)`: 227 at the default (L-bw) |
| `err_call6_ref_named` | `argument for ref parameter 'x' must be marked ref` | 6b: `bump(x: v)` for a `ref` parameter: 254 at the value (Decision 93) |
| `err_call6_default_not_const` | `not a constant expression` | 6b: `a: f64 = now()`: 237 at the call (Decision 91) |
| `err_call6_default_type` | `type mismatch: expected i64, found f64` | 6b: `a: i64 = 1.5`: 201 at the default |
| `err_call6_default_type_str` | `type mismatch: expected str, found i64` | 6b: `s: str = 5`: 201 at the default |
| `err_call6_default_overflow` | `integer overflow` | 6b: `a: i64 = 9223372036854775807 + 1`: 260 at the operator (its left operand) |
| `err_call6_default_divzero` | `integer division by zero` | 6b: `a: i64 = 7 % (2 - 2)`: 261 at the operator (its left operand) |
| `err_call6_default_undeclared` | `undeclared name 'ZZ'` | 6b: a default naming an undeclared name: 200 at the name |
| `err_call6_default_const_order` | `integer overflow` | 6b, Decision 91: a constant's 260 on line 2 is reported before a default's 201 on line 3 |
| `err_call6_default_const_order2` | `type mismatch: expected i64, found f64` | 6b: the reverse: a default's 201 on line 2 before a constant's 260 on line 5 |
| `err_call6_order_value_first` | `type mismatch: expected i64, found str` | 6b: `f(a: "x", zz: 1)`: each value before its narg, in source order: 201 before 224 |
| `err_call6_order_narg_first` | `unknown parameter` | 6b: `f(zz: 1, a: "x")`: 224 at `zz` before the later mismatch |
| `err_call6_print_i64` | `no overload of 'print' accepts (i64)` | 6b: `print(5)`: 243 at the call |
| `err_call6_print_two` | `no overload of 'print' accepts (str, str)` | 6b: two arguments |
| `err_call6_print_none` | `no overload of 'print' accepts ()` | 6b: no argument |
| `err_call6_mkdir_i64` | `no overload of 'make_dir' accepts (i64)` | 6b: `make_dir(3)` |
| `err_call6_mkdir_two` | `no overload of 'make_dir' accepts (str, str)` | 6b: two arguments |
| `err_call6_format_arg` | `format "%d" expects an integer or f64, found str` | 6b: 210 at the argument of `format` (a formatting call, DESIGN.md §2.6.2) |
| `err_call6_format_count` | `format "%d %d" expects 2 arguments, found 1` | 6b: 211 at the call |
| `err_call6_format_literal` | `format must be a string literal` | 6b: 233 at the argument |
| `err_call6_format_bad` | `invalid format conversion "%q"` | 6b: 234 at the literal |
| `err_call6_format_bad_flag` | `invalid format conversion "%#d"` | 6b: `#` with `%d`, 234 at the literal |
| `r_inl6_single_site` | `index 3 out of bounds for dimension 0 of extent 3` | 6b: an error inside a single-site inlined function with a loop: the callee's line (DESIGN.md §3.6.4 "Sites") |
| `r_inl6_small_many` | `integer division by zero` | 6b: a small function with two sites: the callee's line |
| `r_inl6_nested` | `integer overflow` | 6b: the inner function of two nested inlined calls: its own line |
| `r_inl6_ref_param` | `index 2 out of bounds for dimension 0 of extent 2` | 6b: a store through a `ref` array parameter: the callee's line |
| `r_inl6_error_stmt` | `negative: -4` | 6b: `error(…)` inside an inlined function: its own line |
| `r_inl6_conv` | `conversion to i64: 2.5 is not an integer` | 6b: `i64(x)` in an inlined function |
| `r_inl6_arg_error` | `index 5 out of bounds for dimension 0 of extent 2` | 6b: an argument expression's error is the caller's line |
| `r_inl6_deferred_oob` | `index 2 out of bounds for dimension 0 of extent 1` | 6b: rule 31's deferred `ref` element recheck after the inner call shrank the array: the call's line |
| `r_inl6_multiline_call` | `integer division by zero` | 6b: a call over two lines: the callee's line |
| `r_inl6_default_arg` | `integer division by zero` | 6b: an omitted default and a named argument reach the inlined callee: its line |
| `r_inl6_loop_in_caller` | `integer division by zero` | 6b: a later iteration of the caller's loop fails; earlier output flushed first |
| `r_mkdir_file_exists` | `cannot create directory 'x': File exists` | 6b: an existing file (fixture `x`) at the path (LANGUAGE.md §10.10) |
| `r_mkdir_missing_parent` | `cannot create directory 'nodir/sub': No such file or directory` | 6b: no parent is created; earlier output flushed |
| `r_mkdir_parent_is_file` | `cannot create directory 'x/y': Not a directory` | 6b: the parent is a file |
| `r_mkdir_empty_path` | `cannot create directory '': No such file or directory` | 6b: `make_dir("")` (implementer reading: both libcs give ENOENT; the spec names no empty path) |
| `r_mkdir_second_fails` | `cannot create directory 'a/b/c': No such file or directory` | 6b: the first `make_dir` succeeds, the second names a missing grandparent |
| `r_print_flush` | `boom` | 6b: `print("partial")` then `error`: stdout flushed with no extra newline (§9.2 step 1) |
| `err_elem6_228_ref` | `effects in elemental function` | 6c: 228 at the `ref` keyword of a `ref` parameter of an elemental function (the signature step of `seaname`, L-cq) |
| `err_elem6_228_ref_after` | `type mismatch: expected i64, found f64` | 6c: the same program behind an earlier `seacheck` error (`let early: i64 = 1.5`, line 4): the earlier one is reported |
| `err_elem6_228_printf` | `effects in elemental function` | 6c: 228 at a `printf` in an elemental body (the call pre-pass, L-cq) |
| `err_elem6_228_printf_after` | `type mismatch: expected i64, found f64` | 6c: behind an earlier `seacheck` error |
| `err_elem6_228_call` | `effects in elemental function` | 6c: 228 at the first of two calls of a function with effects in an elemental body |
| `err_elem6_228_call_after` | `type mismatch: expected i64, found f64` | 6c: behind an earlier `seacheck` error |
| `err_elem6_228_transitive` | `effects in elemental function` | 6c: 228 at a call of `mid`, which has effects through `deep` (a fixpoint over the call graph, §8.1) |
| `err_elem6_228_transitive_after` | `type mismatch: expected i64, found f64` | 6c: behind an earlier `seacheck` error |
| `err_elem6_228_same_pos` | `effects in elemental function` | 6c: 228 and `seacheck`'s 226 (`missing argument`) at one call: the pre-pass is the first check at a call node, so 228 is reported (L-cq) |
| `err_elem6_232_direct` | `elemental function cannot be recursive` | 6c: 232 at the first call, in source order, of an elemental function to itself |
| `err_elem6_232_direct_after` | `type mismatch: expected i64, found f64` | 6c: behind an earlier `seacheck` error |
| `err_elem6_232_mutual` | `elemental function cannot be recursive` | 6c: 232 for the cycle `b` → elemental `a` → `b`: at the first call in source order on it, `b`'s call of `a` |
| `err_elem6_232_mutual_after` | `type mismatch: expected i64, found f64` | 6c: behind an earlier `seacheck` error |
| `err_elem6_232_same_pos` | `elemental function cannot be recursive` | 6c: 232 and 226 at one call: 232 is reported |
| `err_elem6_253_str` | `elemental function result must be f64, i64 or bool` | 6c: 253 at the `fn` item (its `elemental` keyword) for a `str` result |
| `err_elem6_253_str_after` | `type mismatch: expected i64, found f64` | 6c: behind an earlier `seacheck` error |
| `err_elem6_253_array` | `elemental function result must be f64, i64 or bool` | 6c: 253 for an `f64[]` result |
| `err_elem6_253_tuple` | `elemental function result must be f64, i64 or bool` | 6c: 253 for the result tuple `(f64, str)` |
| `err_elem6_202` | `cannot combine a vector with a matrix: use .col or .row` | 6c: 202 at the call of an elemental function with a vector and a matrix argument |
| `err_elem6_202_after` | `elemental function result must be f64, i64 or bool` | 6c: behind an earlier `seaname` error (253 at line 4) |
| `err_elem6_217` | `shape mismatch: 3 vs 2` | 6c: 217 at the call: fixed vectors of 3 and 2 with a scalar between them (scalars are skipped, §6.3) |
| `err_elem6_217_after` | `parameter needs a default value` | 6c: behind an earlier `seaname` error (236) |
| `err_elem6_217_matrix` | `shape mismatch: 2x2 vs 2x3` | 6c: 217 at the call: fixed matrices 2 × 2 and 2 × 3 |
| `err_elem6_fixed_result` | `shape mismatch: 4 vs 3` | 6c: fixed arguments give a fixed result: bound to `f64[4]` it is the static mismatch (target first) at the call |
| `err_elem6_201` | `type mismatch: expected f64, found str` | 6c: 201 at an argument: a `str` for an elemental `f64` parameter |
| `err_elem6_201_after` | `effects in elemental function` | 6c: behind an earlier `seaname` error (228 at a `ref` parameter, line 4) |
| `err_elem6_201_bool_array` | `type mismatch: expected f64, found bool[2]` | 6c: a `bool` array is not converted to `f64` |
| `err_elem6_201_f64_to_i64` | `type mismatch: expected i64, found f64[]` | 6c: an `f64` array for an `i64` elemental parameter |
| `err_elem6_201_uniform` | `type mismatch: expected f64[], found f64` | 6c: an `f64` scalar for a uniform `f64[]` parameter |
| `r_elem6_error_vector` | `too large: 3` | 6c: `error` in an elemental body: the first failing element (3 of 3, 4, 5), at the `error` call's line in the callee |
| `r_elem6_error_matrix_order` | `bad 3` | 6c: the first failing element in column-major order (3, where a row-major scan meets 2) |
| `r_elem6_error_broadcast_order` | `bad 2 10` | 6c: the same for `.col` with `.row`: (1, 0) before (0, 1) |
| `r_elem6_oob_index` | `index 7 out of bounds for dimension 0 of extent 3` | 6c: an out-of-bounds index inside the body at element 2: the callee's line |
| `r_elem6_scalar_call` | `too large: 3.5` | 6c: a scalar call is an ordinary call; the callee's line |
| `r_elem6_nested` | `inner 3` | 6c: the inner elemental function's line |
| `r_elem6_shape_vectors` | `shape mismatch: 3 vs 4` | 6c: two dynamic vectors: at the call's line |
| `r_elem6_shape_matrices` | `shape mismatch: 3x4 vs 3x5` | 6c: dynamic matrices: 4 vs 5 with neither 1 |
| `r_elem6_shape_three` | `shape mismatch: 5 vs 2` | 6c: three dynamic vectors: the combined shape so far, then the operand's (§6.3) |
| `r_elem6_shape_scalar_skipped` | `shape mismatch: 3 vs 4` | 6c: a scalar between two vectors is skipped |
| `r_elem6_shape_before_elements` | `shape mismatch: 3 vs 2` | 6c: the shape check comes before any element (L19 step 2): the body's own error is not reached |
| `r_elem6_args_before_elements` | `index 10 out of bounds for dimension 0 of extent 3` | 6c: an argument expression's error (the call's line) before any element (L19 step 1, L-ck) |
| `r_elem6_discard_all_error` | `two 2` | 6c: every result bound to `_`: the call still runs for its errors (Decision 84) |
| `r_elem6_eval_error` | `too large: 3` | 6c: an elemental call as a statement runs for its errors |
| `r_elem6_ind2sub_eval_zero` | `integer division by zero` | 6c: `ind2sub(r, k)` as a call statement with `r = [3, 4, 0]`: every result discarded, the call still runs for its errors (L19, Decision 84, §6.6, §10.7), at the call's line; `start` printed first |
| `r_elem6_mixed_dynamic` | `shape mismatch: expected 4, got 3` | 6c: a fixed with a dynamic argument gives a dynamic result: the run-time check of the binding to `f64[4]` |
| `r_elem6_tuple_target` | `three 1` | 6c: an error in the body behind a tuple assignment into selection targets: nothing stored, earlier output flushed |
| `r_json_missing_dir` | `cannot open 'nodir/a.json': No such file or directory` | 6d: a path in a missing directory, at the call's line; earlier output flushed (LANGUAGE.md §11.4, §9.2) |
| `r_json_is_dir` | `cannot open 'd': Is a directory` | 6d: a path that is a directory (fixture `d/keep.txt`, untouched) |
| `r_json_dot` | `cannot open '.': Is a directory` | 6d: `write_json(".", …)` (no fixture: git keeps no empty directory) |
| `r_json_empty_path` | `cannot open '': No such file or directory` | 6d: the empty path (unsure: the spec names none; both libcs give ENOENT) |
| `r_json_parent_is_file` | `cannot open 'x/y.json': Not a directory` | 6d: a path below a file (fixture `x`) |
| `r_json_after_write` | `boom 7` | 6d: `error` after a completed `write_json`: the file stays complete (`.expect/ok.json`), output flushed (LANGUAGE.md §9.2 steps 1–3) |
| `r_json_after_index` | `index 5 out of bounds for dimension 0 of extent 2` | 6d: an index error after a completed `write_json` (`.expect/v.json`) |
| `r_json_second_fails` | `cannot open 'missing/second.json': No such file or directory` | 6d: the first `write_json` completes (`.expect/first.json`), the second fails and names its own path |
| `r_json_value_error` | `index 5 out of bounds for dimension 0 of extent 2` | 6d: an error while the value is evaluated: no file is created (the value is bound before `jopen`, DESIGN.md §3.5.7 step 4) |
| `r_json_call_error` | `bad value` | 6d: `error` inside a function called as the value: its own line, no file |
| `r_json_path_error_first` | `index 3 out of bounds for dimension 0 of extent 1` | 6d: path and value both fail: the path's error (bound first), no file |
| `err_json_one_arg` | `no overload of 'write_json' accepts (str)` | 6d: `write_json("a.json")` without its value: 243 at the call (DESIGN.md §2.11.2 "Library calls of phase 6") |
| `err_json_no_arg` | `no overload of 'write_json' accepts ()` | 6d: `write_json()`: 243 at the call |
| `err_json_three_args` | `no overload of 'write_json' accepts (str, f64, bool)` | 6d: an extra argument: 243, the types in order |
| `err_json_path_i64` | `no overload of 'write_json' accepts (i64, i64)` | 6d: `write_json(1, 2)`: a path that is not a `str` |
| `err_json_path_array` | `no overload of 'write_json' accepts (str[], i64[2])` | 6d: a `str[]` path with a fixed-size vector value (a literal of two scalars is `i64[2]`) |
| `r_fuse_shape_before_index` | `shape mismatch: 3 vs 4` | 7c (DESIGN.md §2.12.2 (2)): `(a + b) * v[99]` with a, b of lengths 3 and 4: the shape check of a + b precedes the leaf v[99], so not the index error; `.out` the line before |
| `r_fuse_cat_part_first` | `index 98 out of bounds for dimension 0 of extent 5` | 7c (DESIGN.md §2.12.4 F4, L-eu; LANGUAGE.md §6.9): a fused stack evaluates every part (its IX 1 and IX 2) before the shapes, so `v[0..99]` fails before the row `v[1..4]` (1 × 3) meets the stack's 4 columns; `.out` the line before |
| `r_fuse_cat_row_first` | `shape mismatch: 2x3 vs 1x4` | 7c (F4, L-eu; §6.9): a row is joined and checked before it is stacked: the second row's `B[0..2, :]` and `A[0..1, :]` fail, not the stack |
| `r_fuse_cat_stack_cols` | `shape mismatch: 1x2 vs 2x4` | 7c (F4, L-eu; §6.9): the row vector `v[0..2]` stacks as 1 × 2 over `A[1..3, :]` (2 × 4) |
| `r_fuse_inner_overflow` | `integer overflow` | 7c (F1 (2): a failing inner node is a barrier): `(i + j) + k`, i + j overflowing at element 3, k of length 4 against 5 |
| `r_fuse_empty_bcast_overflow` | `integer overflow` | 7c (F1 (2)): `f64(a * 2) + z`, a an `i64[1,3]` whose first element overflows, z an `f64[0,1]` (an empty 0 × 3 result): the loop of a * 2 runs first |
| `r_fuse_root_before_sel` | `integer overflow` | 7c (F1 (2), L-en; LANGUAGE.md §5.5): `v[0..5] = f64(a + 1) * 2.0`, v of length 3, a + 1 overflowing at element 0: the value before the index check |
| `r_fuse_abs_min` | `integer overflow` | 7c (§2.12.2 "failing"; LANGUAGE.md §10.4): `abs` of the `i64` −2⁶³ in `f64(abs(a)) * 0.5 + x`, before the `+`'s shape mismatch (3 vs 4) |
| `r_fuse_group_isum` | `integer overflow` | 7c (F2 (4), F3; LANGUAGE.md §10.5): `sum(where(m, a, c))` of `i64`, a partial sum overflowing at the second element, before the next statement's shape mismatch |
| `r_fuse_two_failing` | `integer overflow` | 7c (§2.12.2 (2)): `idiv(a, b) + idiv(c, d)` over two lines: the first loop's overflow (`idiv(-2⁶³, -1)` at element 1) at its line, not the second's division by zero at element 0 |
| `r_fuse_elem_error_group` | `bad element 5` | 7c (F2 (4); LANGUAGE.md §8.5): an elemental function calling `error` at element 5 of a group, at the `error` call's line, before the next statement's shape mismatch |
| `r_fuse_group_printf` | `shape mismatch: 3 vs 2` | 7c (§2.12.2 (3), F2 (1)): a `printf` between two element-wise statements writes its line (`.out`) before the later statement's shape mismatch |
| `r_fuse_mask_empty_max` | `max of an empty array` | 7c (F3; LANGUAGE.md §10.5): `max(abs(Tn[m] - Tc[m]))` with an all-false mask inside a group, before the next statement's shape mismatch |
| `r_fuse_sel_bad_index` | `index 5 out of bounds for dimension 0 of extent 4` | 7c (LANGUAGE.md §5.4, §5.5): `v[2..6] = a * 2.0 + b` on a length-4 v: the fused value first, then the index check (the last position named), nothing stored |
| `r_fuse_reg2_variance_n1` | `integer division by zero` | 7c regression (DESIGN.md §2.12.4 F3: variance and std fuse a quiet tree only; LANGUAGE.md §10.4, §10.5): `variance(3 % z)` with z = [0]: n = 1, but its element is evaluated and fails; `.out` the line before |
| `r_fuse_reg2_std_masked_n1` | `integer division by zero` | 7c regression (F3, F4): `std(3 % (k[m] % k[m]))` over a one-element mask selection (12 % 12 = 0, then 3 % 0) |
| `r_fuse_reg2_variance_elem_n1` | `integer division by zero` | 7c regression (F3, F5; LANGUAGE.md §8.5): `variance(md(z))`, the elemental `md` computing 7 % 0 for the one element, at the line of the `%` in its body; `.out` the line before |

## vectors/ (WP12's generators; run with `uv run python tests/vectors/<name>.py`)

| Script | Writes |
|--------|--------|
| `float_oracle.py` | `float_oracle.out`, `passes/lex_float_hard.{sea,ast}`; also a module for the other two |
| `progfmt.py` | `programs/fmt_*.{sea,out}`, `op_f64_arith`, `op_order`, `op_powk`, `lib_consts` |
| `lcg_w5.py` | `programs/op_lcg_w5.{sea,out}`, `lcg_w5.out` |
| `f64emu.py` | `f64emu.txt`, `limb.txt` (read by `arith_check.sh` through `harness/f64emu_h.bas`, `harness/limb_h.bas`) |
| `wave2_gen.py` | the wave-2 and round-3 `programs/` and `errors/` tests listed above |
| `edges_gen.py` | the phase-2 edge tests `op_mod_idiv_edges`, `op_ftoi_edges`, `op_itof_round`, `op_cmp_nan_zero`, `op_neg_zero`, `err_rt_mod_zero_min`, `err_rt_idiv_zero_min`, `err_rt_conv_below` (min/max, floor/ceil/round/trunc, abs and sqrt are `not supported yet` in phases 1–2, Sea has no shifts) |
| `math_progs.py` | the phase-3 `programs/lib_math_*.{sea,out}`, `passes/math_lower.{sea,ast,hir1,hir,lir1}`, `passes/const_pow.{sea,ast,hir1}` and `errors/err_const_log`, `err_const_sin`, `err_no_overload_hypot`, `programs/lib_const_sqrt` |
| `res_gen.py` | `passes/NAME.res` for every `passes/NAME.hir1`, `rs` and the `res_*` tests (run `res_gen.py [NAME...]`); from 4d with `rtype` and the array types of §3.4.2; from 4g-1 it evaluates `str` constants (`rcns`, and `rcnb` from `str` comparisons; L-f, L-g); from 4g-2 it evaluates structs (`rtst`/`rtfd`, `rslit`, the declaration checks 235, 222 and 221); from 4h the four prelude names resolve only as entered items (`PRELUDE_NAMES`, L-s) |
| `lir4_gen.py` | the 4c pass-4 tests `passes/lir4_{retain_release,release_leaf,mcopy,slay,entries}.{lir,out}` |
| `res_cases.py` | `passes/res_*.{sea,ast}` (then their `.res` through `res_gen.py`) and `errors/err_merge_*`, `errors/err_const_noval_{calltype,shortcircuit,userpow}` (the two `err_const_noval_*` of these that use `str` are re-derived by `str4g_cases.py`); from 4g-1 its `NOVAL_*` sources use the undeclared struct type `Q`; from 6c it no longer writes `res_err_elemental` or `err_merge_same_pos` (re-derived by `dump6c_cases.py` and `elem6_cases.py`) |
| `arr4d_cases.py` | the 4d `programs/arr_*`, `programs/heap_*` (except `heap_env_*`), `errors/err_rt_arr_*`, `errors/err_ns_arr_str_elem`, `errors/err_ns_lib_{max1,min1}` (its eight `arrays` cases were retired by 4e; the two `err_ns_lib_*` goldens by 4f, deleted by `arr4f_cases.py`; `err_ns_arr_str_elem` by 4g-1, deleted by `str4g_cases.py`) |
| `arr4e_cases.py` | the 4e `programs/{sel,ew,arr,heap}_*` from `sel_vec_read` on, `programs/w4_sor_arrays` (from `accept/w4_sor.sea`), the 4e `errors/` tests from `err_rt_sel_range_last` on; it deletes the ten retired 4d goldens (`err_ns_lib_max1_fixed` is retired by 4f, deleted by `arr4f_cases.py`; `err_ns_str_literal` is retired by 4g-1, deleted by `str4g_cases.py`); from 6c it no longer writes `err_ns_ind2sub_array` (retired by `elem6_cases.py`, L-cl) |
| `arr4f_cases.py` | the 4f `programs/{red,sort,find,heap_red}_*`, `programs/w4_sor_reduce` (from `programs/w4_sor_arrays.sea`), the 4f `errors/` tests `r_red_*`, `err_red_*`, `err_sort_*`, `err_find_*`; it deletes the four retired `err_ns_lib_*` goldens |
| `str4g_cases.py` | the 4g-1 `programs/{str,match,args,heap_str}_*` (with their `.args`), `programs/sort_str`, `programs/heap_str_views`, the 4g-1 `errors/` tests `r_str_*`, `r_args_*`, `r_error_*`, `err_str_*`, `err_match_*`, `err_error_*`, `err_lower_*`, `err_args_*`, `err_const_str_*`, `err_ns_str_fixed_let` (retired by 4g-2, deleted by `struct4g_cases.py`); it re-derives `errors/err_const_noval_{calltype,errtype,shortcircuit}` (run it after `res_cases.py`) and deletes the five retired goldens `err_ns_{string_let,string_type,str_literal,arr_str_elem,match}` |
| `dump4g_cases.py` | the 4g-1 dump tests `passes/str_rule{15,26,30,32,33}`, `passes/match_l16`, `passes/str_{l17,fill_flat,ew,l12}`, `passes/res_str_consts`: `.ast` as pass 1 writes it, `.res` from `res_gen.py` (`rcns`, L-f, L-g), `.hir1`, `.hirl` and `.lir1` by hand from §3.5, §3.5.9 and §3.6.6 with the agreed examples of rules 15, 26, 30, 32 and 33 verbatim, `.out` from LANGUAGE.md; every file self-checked against `passes.txt`; 4g-2: `passes/struct_rule{18,27,29}`, `passes/struct_{l17,l17_path,cow2,l6_field,l12}`, `passes/str_{ref_ln,fixed_self}`, `passes/rec_slay`, `passes/res_{rt,rtst}`, changed `res_struct`; struct layouts by hand from §4.8; the agreed examples of rules 18 (second), 27 and 29 verbatim |
| `struct4g_cases.py` | the 4g-2 `programs/{struct,heap_struct}_*`, `programs/str_fixed`, `programs/records`, the 4g-2 `errors/` tests `err_struct_*`, `err_record_*`, `r_str_fix`, `r_struct_dollar_*`; it deletes the four retired goldens `err_ns_{struct,record,str_fixed_type,str_fixed_let}` (run it after `arr4e_cases.py` and `str4g_cases.py`) |
| `manualD_part1.py` | `programs/manualD_part1.{sea,args,out}` and `errors/manualD_part1_badopt.{sea,args,err,status}` from LANGUAGE.md Appendix D; prints the 12 lines |
| `prel4h_cases.py` | the 4h `programs/{prel,heap_prel}_*`, `errors/r_prel_*`, `errors/err_prel_*`, the close-out `errors/err_ns_matmul`, `errors/err_ns_lib_{format,solve,figure}` and `accept/w5_stats.{sea,keys,wl}` (from LANGUAGE.md Appendix D) |
| `dump4h_cases.py` | the 4h dumps: stage-only `passes/inl_{half,nested,void,multi,loop_ret,owned_arg,dest,rule12,scope}.{hir,hirl,lir1}` (hand-written two-file `sea.hir`, Decision 55), `passes/prel_bincount.{sea,hir,hirl,lir1,out,prelude}`, `passes/prel_meshgrid_tbind.{sea,hirl,lir1,out,prelude}` (positions from `std/std.sea`), `passes/res_noprelude_pnames.{sea,ast,res}` (`.res` through `res_gen.py`); self-checked against `passes.txt`, the source positions and rule 37's example |
| `opt5c1_cases.py` | the 5c-1 and 5c-2 `programs/opt_*` and `errors/r_opt_*` (DESIGN.md §6.2 "Phase-5 tests"; 30 programs, 64 errors) |
| `ra5_gen.py` | the 5b pass-4 tests `passes/ra5_*.{lir,out,err,status}` (19 tests, DESIGN.md §6.2 "Phase-5 tests"), written through `lirkit.py` |
| `lirkit.py` | a module for `ra5_gen.py`, not run on its own: `Test` renumbers symbolic LIR (DESIGN.md §3.6.1–§3.6.3), and `Interp` interprets it by §3.6.4 to compute each `.out`, `.err` and `.status` |
| `dump5_cases.py` | the 5c-1/5c-2 dumps: 28 `passes/opt5_*.{sea,lir1,lir2,lir3,lir}`, `passes/lir4_seaopt.lir2`, `passes/lx.lir2`/`lx.lir3`/`lx.lir`, the W5 loop checked against DESIGN.md §5.8; `--check-build BUILD` compares the embedded `.lir1` with the build |
| `dump4d_cases.py` | `passes/arr_rule{16,17,18,19,30,31,36}.{sea,ast,hir1,hir,lir1,out}` (and their `.res` through `res_gen.py`) |
| `hirl4e0_cases.py` | `passes/NAME.hirl` for the 17 dump tests with a `.sea` and a `.lir1`, and the `passes/loop_*.{sea,ast,res,hir1,hir,hirl,lir1,out}` tests (`.res` through `res_gen.py`) |
| `dump4e_cases.py` | the 4e dump tests `passes/arr_rule{20,21,22,25,28}`, `passes/sel_{reads,ref_store,compound}`, `passes/ew_{colrow,ind2sub}`, `passes/arr_{lit_fixed,lit_dyn,lit_cat,lit_cat_fixed,views,dynfix,fixed,tasg_l12}` (`.sea .ast .res .hir1 .hir .hirl .lir1 .out`), and the rewritten `passes/res_err_array.res` (+ its new `.hir1`) |
| `fmt.py` | `rt/arm64_macos/rt_fmt_*` and `rt/x86_64_linux/rt_fmt_*` from one table (identical `.out` files) |
| `fmod6_cases.py` | `programs/fmod_{scalar,str,random,array}.{sea,out}`; with `--emit-asm arm64_macos` or `--emit-asm x86_64_linux` the 403-vector table of `f64 %` (raw bit patterns of a, b and the expected result) as assembler data between the marker comments `FMOD6-VECTORS-BEGIN <target>` / `FMOD6-VECTORS-END` for `tests/rt/<target>/rt_fmod_vec.s`; with `--check-asm FILE` it checks a test's copy of the table (run `uv run --no-project python tests/vectors/fmod6_cases.py`, 6b) |
| `call6_cases.py` | the 6b `programs/{call6,inl,fmt6,print,mkdir}_*` (not `fmod_*`), `errors/{err_call6,r_inl6,r_mkdir}_*`, `r_print_flush`, `err_ns_lib_write_json`; it re-derives the five 224 goldens and deletes the retired `err_ns_{named_arg,default_arg,f64_mod,lib_format}` and the moved `err_prel_named` (run after `fmod6_cases.py` and `progfmt.py`, whose cases it imports; `fmt6_{d_ext,prec_zeros}` read `programs/fmt_{d_ext,prec_zeros}`) |
| `elem6_cases.py` | the 6c `programs/{elem,ind2sub_arr}_*`, `errors/{r_elem6,err_elem6}_*` and the re-derived `err_merge_same_pos`; it deletes the retired `err_ns_elemental` and `err_ns_ind2sub_array` (imports the helpers of `call6_cases.py` and the oracle of `progfmt.py`; run with `timeout 120 uv run --no-project python tests/vectors/elem6_cases.py`) |
| `json6_cases.py` | the 6d `programs/json_*` (with `NAME.expect/`) and `errors/{r,err}_json_*` (with `.expect/` and `.files/` where used); deletes the retired `err_ns_lib_write_json` (run after `call6_cases.py`, whose helpers it imports, and after `elem6_cases.py`) |
| `dump6d_cases.py` | the 6d `passes/json6_*` dumps and their `.out` (T2; run with the output directory of its own header, never into the repo tree by hand: it rewrites goldens) |
| `fuse7c_programs.py` | the 7c `programs/fuse_*` and `errors/r_fuse_*` (26 programs, 11 errors; DESIGN.md §6.2 "Phase-7 tests"); imports the helpers of `call6_cases.py`, the oracle of `progfmt.py` and the model `math_model.py`; run with `timeout 120 uv run --no-project python tests/vectors/fuse7c_programs.py --out DIR` into a scratch directory and copy the files (it refuses an output directory inside `tests/`) |
| `dump7_cases.py` | the 7b `passes/elem6_{inst,k5,vec}.hirf` (parts 1–3: scan, L19 transcription, cross-check with the committed `.hirl`) and the 7c `passes/fuse7_*.hirf` (part 4: F1–F5 transcription per its `FUSE7` table); run with `timeout 120 uv run --no-project python tests/vectors/dump7_cases.py --out DIR` into a scratch directory, or `--check` to compare with the committed files (T2; it rewrites goldens: never run it into the repo tree by hand) |
