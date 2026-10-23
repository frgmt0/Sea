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
* `passes/`: `sea build --emit X --no-prelude NAME.sea` for each `NAME.X` present (§3.8).

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
| `accept/w4_sor` (4d acceptance, DESIGN.md §6.3) | ported by hand from `workloads/w4_heat_plate.m` (inputs, scalar SOR); checked by `compare.py --candidate --keys it_sor,T_max` against `workloads/reference/w4_heat_plate.json`; a line-by-line IEEE mirror of the port in Python (scratch, not committed) prints `{"it_sor": 832, "T_max": 160.76267159277148}`, the reference values exactly |
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

## passes/

| Test | Files | Spec (DESIGN.md unless noted) |
|------|-------|------|
| `ex` | ast | §3.4 example, verbatim |
| `lx` | ast hir1 hir hirl lir1 lir | §3.6.7 example (lir1/lir verbatim); ast §3.4, hir1/hir §3.5 |
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
| `lir4_retain_release` | lir (+ `.out`) | sub-phase 4c pass-4 test (§6.2): `retain`/`release` (§3.6.4, §4.9) on a fresh array (count 1 → 2 → 3, read with `ldi` at `SEA_OBJ_RC`), the same object shared (3 → 2 → 1), its last `release` freeing it (the next array of its 128-byte class is the same block, by the LIFO free lists of §4.1, again count 1 and zeroed), a static `str` object (count `SEA_RC_STATIC` 0 unchanged by `retain`/`release`), and a fresh `sea_str_i64` string (−2⁶³ in decimal, §4.8) |
| `lir4_release_leaf` | lir (+ `.out`) | a function whose only call-like instruction is `release` (non-leaf by §4.9: frame record, §4.6 check): it frees an `str[]` and a string through `sea_free` and still returns to its caller |
| `lir4_mcopy` | lir (+ `.out`) | `mcopy` of 0, 7, 8, 9 and 100 bytes from a `dat` buffer + 5 to a zeroed 128-byte slot + 3 (both unaligned); the 16 words of each slot printed with `%d` (little-endian, computed by `vectors/lir4_gen.py`), so bytes beyond n stay 0 |
| `lir4_slay` | lir (+ `.out`) | `slay`/`soff` with 0 and 3 offsets (§3.6.2, §4.9: `SEA_SL_*` words read back), `sea_arr_new_s` (§4.8: count 1, ek 5, rank, rows, cols, cap, esize = size, `SEA_ARR_SLAY` = the descriptor, data at header + 64, buffer zeroed); a string stored with a `retain` into two reference fields goes from count 3 back to 1 when the array is released (`sea_free` releases the non-null reference fields by the descriptor) |
| `lir4_entries` | lir (+ `.out`) | the other returning entries of ids 9–20 through pass 4 (§4.8): `sea_str_f64` (an `f` argument with the site the first integer argument: `%.17g` text, `nan` for both NaN signs, `inf`, `-inf`, LANGUAGE.md §10.9), `sea_str_cmp` (unsigned bytes, prefix, empty), `sea_str_cat` (also of two empty strings: a new string), `sea_str_lower` (only A–Z), `sea_arr_new_u` (header), `sea_arr_unique` (count 1: the same array; count 2: a copy with count 1, the old count 1, a store into the copy leaves the old), `sea_args` (no arguments: rank 1, length 0, LANGUAGE.md §10.10); everything released |
| `lir4_seaopt` | lir1 lir | stage test of pass 3b (§3.6.5 "Pass 3b from phase 4"): `retain`, `release`, `mcopy`, two `slay` groups (0 and 2 `soff`), a `dat` and `sea_arr_new_s` copied unchanged (`.lir` = `.lir1`), hand-written |
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
| `sel_reads` | ast res hir1 hir hirl lir1 (+ `.out`) | 4e, §3.5.9 L5, rule 20: a matrix selection with `:` and a scalar, an index vector, a whole-matrix mask read |
| `sel_ref_store` | ast res hir1 hir hirl lir1 (+ `.out`) | 4e, L6, rule 21: a selection store into a `ref` parameter (read afresh for each extent, the cow and the data) |
| `sel_compound` | ast res hir1 hir hirl lir1 (+ `.out`) | 4e, L6, rules 21, 22: a compound `x[sel] += e` (gather into a temporary, the operation, the store) |
| `ew_colrow` | ast res hir1 hir hirl lir1 (+ `.out`) | 4e, L7, rule 22: matrix broadcasting of `.col` with `.row` (strides, the shape checks) |
| `arr_lit_fixed` | ast res hir1 hir hirl lir1 (+ `.out`) | 4e, L9, rules 26 (a), (d), 27: fixed vector and matrix literals, `[]` dynamic and fixed |
| `arr_lit_dyn` | ast res hir1 hir hirl lir1 (+ `.out`) | 4e, L9, rule 26 (b): a dynamic constant literal (257 elements, `cdat`) and a dynamic non-constant literal |
| `arr_lit_cat` | ast res hir1 hir hirl lir1 (+ `.out`) | 4e, L9, rule 26 (c): vector and matrix concatenation (joined lengths, the row and stack checks) |
| `arr_views` | ast res hir1 hir hirl lir1 (+ `.out`) | 4e, L10, rule 28: `.T` and `.flat` materialized |
| `arr_dynfix` | ast res hir1 hir hirl lir1 (+ `.out`) | 4e, L10, rule 27 (i), (j): `dyn` and `fix` (the `SHAPE_EXPECTED` check) |
| `arr_fixed` | ast res hir1 hir hirl lir1 (+ `.out`) | 4e, rule 27 (a)–(d), (h), (l): a fixed-size local with element read and write, a fixed-size result through the hidden address |
| `ew_ind2sub` | ast res hir1 hir hirl lir1 (+ `.out`) | 4e, L11, rule 22 (Decision 33): `ind2sub` of a vector as two element-wise loops over held arguments |
| `arr_tasg_l12` | ast res hir1 hir hirl lir1 (+ `.out`) | 4e, §3.5.9 L12 (Decision 37): a tuple assignment with a selection target (an L6 store of a fixed-size result through a `.l` local) and a fixed → dynamic component (`cv` 2, the `dyn` of L10); one `tbind` of fixed-size `.l` locals passing their slots as hidden result addresses; two fixed-size results returned by copy |
| `arr_lit_cat_fixed` | ast res hir1 hir hirl lir1 (+ `.out`) | 4e, L9, rule 26 (c) with every part fixed-size: a vector join `[a, 4.0, a]` and a matrix row `[m, m]` with home slots, the length and column sums kept, no row check, static extents and offsets |
| `lib_rule23` | ast res hir1 hir hirl lir1 (+ `.out`) | 4f, §3.6.6 rule 23 (reductions): the agreed example `let s = sum(x)` (`x` an `f64[]` in `p1`) as a whole program, its `.lir1` the rule's text exactly; `.hirl` from §3.5.9 L13 (sum8 with the accumulator home of the appended type `f64[8]`, R14; the lane `K & 7` by `wbin and`, R13; the `ifx` taking the register of `s`, R12 (a)) |
| `lib_rule24` | ast res hir1 hir hirl lir1 (+ `.out`) | 4f, rule 24 (sorting and searching): the agreed example `let r = argsort(c, desc: true)` on line 8, its `.lir1` the rule's text exactly (`rcall sea_argsort` with the vector and the `desc` value); `.hirl` = `.hir` for that function (L14, R16: the `lib argsort` stays); `r[0]` read by rule 18, `r` released before the `ret` |
| `lib_mean_i64` | ast res hir1 hir hirl lir1 (+ `.out`) | 4f, L13 on a fixed-size `i64` vector: `sum` (isum, the extent loaded after the data, `iaddc` with the call's line, the accumulator taking the register of `t`, R12 (b)) and `mean` (the sum converted before n, rule 23) |
| `lib_variance` | ast res hir1 hir hirl lir1 (+ `.out`) | 4f, L13: `variance` (n = 0 NaN, n = 1 zero, else the two-pass mean and deviations, each sum8 with its own home slot; the outer `ifx` taking the register of `v`, R12 (a)) and `std` (the variance `xblk`, then `fsqrt`) |
| `lib_max` | ast res hir1 hir hirl lir1 (+ `.out`) | 4f, L13 on fixed-size vectors: `max` of `f64` (`EMPTY_REDUCE` with the function's name, NaN ignored, the first maximum; R15's `where` values) and `argmin` of `i64` |
| `lib_nnz` | ast res hir1 hir hirl lir1 (+ `.out`) | 4f, L13: `nnz` (`wbin add` of a `bool`, R7), `any` and `all` of a fixed-size `bool` vector, each accumulator taking the register of its local (R12 (b)) |
| `lib_sum_dim0` | ast res hir1 hir hirl lir1 (+ `.out`) | 4f, L13 `dim:` form: `sum(A, dim: 0)` of a dynamic matrix (extents and data loaded once before the outer loop over the columns, one sum8 home slot for every column, the element at `I + J * rows`) |
| `lib_sum_dim1` | ast res hir1 hir hirl lir1 (+ `.out`) | 4f, L13 `dim:` form: `sum(A, dim: 1)` of a fixed-size `f64[2,3]`, its result the fixed-size `f64[2]` (Decision 39: a home slot copied into the home of `s`), the lane `wbin and` of J |
| `lib_find` | ast res hir1 hir hirl lir1 (+ `.out`) | 4f, L14: `find` of a fixed-size `bool` vector (the count, the new `i64[]` of that length, the indices stored in order); the result is dynamic (Decision 39) |
| `lib_find_first` | ast res hir1 hir hirl lir1 (+ `.out`) | 4f, L14: `find_first` (the first `true`: `where` of a counter, R15) and `find_last` of a fixed-size `bool` vector |
| `lib_sort_fixed` | ast res hir1 hir hirl lir1 (+ `.out`) | 4f, L14, R16, Decision 39: `sort` and `argsort` of a fixed-size vector (the `dyn` pass 2a writes at the call's position, rewritten by L10, released right after the `rcall`), `desc:` inserted as false and given as a run-time `bool` |
| `str_rule15` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-1, §3.6.6 rule 15: the example (`let s = a + b`, `let t = s`, `printf("%s\n", a + b)`) verbatim; `str(i64)` by rule 32; locals released by rule 16 (a) |
| `str_rule26` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-1, §3.6.6 rule 26: `let names = ["a", "bc"]` verbatim (L9 (b), R21's sea_arr_new); an element loop over it (L4, rule 30) |
| `str_rule30` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-1, §3.6.6 rule 30's first example `for a in args() {` verbatim, also rule 35's `rcall sea_args`; `len(args())` (L3) |
| `str_rule32` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-1, §3.6.6 rule 32: `if a < b {` verbatim; `lower`, `len` of a str (L3), `str(bool)` |
| `str_rule33` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-1, §3.6.6 rule 33 and §3.5.9 L16: the `"x" \| "y"` / `_` match verbatim |
| `match_l16` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-1, §3.5.9 L16: multi-pattern arms, `_`, a `_`-only match; owned scrutinees released after the last endif (R11) and before a `break`'s exit (R22) |
| `str_l17` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-1, §3.5.9 L17 of a str element by a scalar index: `=` (R17 (a), retained at the store) and `+=` (`bin cat`, R17 (b) move) |
| `str_fill_flat` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-1, L2 `filled` with a str value and L10 `.flat` of a `str[,]` with R20 (element count, retain loop) |
| `str_ew` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-1, L7 with str operands (Decision 45): element-wise `bin cat` and comparison (sea_str_cmp, `bool[]`) |
| `str_l12` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-1, L12 with an L17 target (`(names[i], k) = two(i + 5)`): no `tmp Vv`, est of `lv L1`, R25's move |
| `res_str_consts` | ast res hir1 hir (+ `.out`) | 4g-1, §3.4.2 `rcns` (L-f, L-g): str constants of `+`, one naming another, annotated, rcnb from str comparisons |
| `res_rt` | ast res (+ `.out`) | 4g-2, §3.4.2's example rt.sea verbatim: its documented sea.res (rtst/rtfd, rtfvec, rslit) |
| `res_rtst` | ast res | 4g-2, §3.4.2 type-table order (rtst in sid order with rtfd naming a later id, field/signature/other types); rslit sid 0 (undeclared `Q`, struct name hidden by a local) |
| `struct_rule27` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-2, §3.6.6 rule 27's example verbatim (slit bound in place, scalar field load) |
| `struct_rule18` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-2, rule 18's second example verbatim (`dims[d].nom`); L9 (b) of Dim elements (sea_arr_new_s, slay, R19 in place) |
| `struct_rule29` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-2, rule 29's example verbatim (L15 of an f64 field), L15 of a str field, L2 `filled` of a struct (R19 copy + retains) |
| `struct_l17` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-2, L17 on a struct local: scalar, compound, str field (R17), nested (R24), array-field element (R23), slit into a struct field (rule 27 (d)) |
| `struct_l17_path` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-2, L17 through elements of a `ref` root: two-array path (cows, D'/E' from the cow's register, L-n), `ds[i].lim = T{…}` (sc 32 off 16), nested and str fields |
| `struct_cow2` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-2, `a[0].w[0].v[0] = 9.0` after `let b = a` prints `1 9`: three cows (R23) |
| `str_ref_ln` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-2, L-n: `v[i] = "x"` into `ref v: str[]`: the est address is the cow's A, no second ldp |
| `str_fixed_self` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-2, `str[3]`: L10 fix by R20 (`ci 3`), `a[:] = a` (L6 counted self-copy), element store (R17) |
| `struct_l6_field` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-2, L6 with a field root `dims[p()].v[q()..3] = 0.0` (rule 19 order, DT from the last cow) |
| `struct_l12` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-2, L12 with `(s.name, k)` and `(ps[0], k)` targets (R25 moves, R19); slit into an existing element; struct tbind |
| `rec_slay` | ast res hir1 hir hirl lir1 (+ `.out`) | 4g-2, records (L-m): L9 (b) with the record's slay, L4 over records (R18 address) |
| `res_err_predeclared` | ast res | §3.4.1: `rerr 212`; the item is entered (`rfn`) and `sqrt` resolves to it (`rname fn`) |
| `res_err_redef_item` | ast res | §3.4.1: `rerr 235` at the later `const`; it is copied with its names unresolved |
| `res_err_elemental` | ast res | §3.4.1: `rerr 259 elemental functions` at `elemental`; `rfn` el 1 |
| `res_err_param_redef` | ast res | §3.4.1: `rerr 235` at the second parameter `a` |
| `res_err_param_shadow` | ast res | §3.4.1: two errors at one `param` (213 and default arguments): the first found, 213, is the `rerr` |
| `res_err_default` | ast res | §3.4.1: `rerr 259 default arguments`; the default `K` is copied as `name` |
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

## accept/ (DESIGN.md §6.3, run by `tests/accept4.sh`)

| Test | Spec |
|------|------|
| `w4_sor` | `.keys` `it_sor,T_max`, `.wl` `w4_heat_plate`: W4's scalar SOR (grid, channel, source, boundary values, lexicographic SOR with the max-change test, the hot spot by a scalar loop over the unknown nodes), the JSON subset written with `%d`/`%.17g`; MATLAB's two configuration checks are not ported (`error` is 4g; this grid never trips them) |

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
From sub-phase 4f (DESIGN.md §2.6.2 step 4f, "Readings fixed by 4f") the reductions, `sort`, `argsort`, `find`, `find_first`, `find_last` and the options `dim:` and `desc:` are implemented: the goldens `err_ns_lib_sum`, `err_ns_lib_max1`, `err_ns_lib_max1_fixed` and `err_ns_lib_min1` are retired (their calls are `programs/red_former_ns`), and the 4f tests below cover the run-time errors `integer overflow` of a checked `i64` sum (also inside `mean`, `variance` and a `dim:` form) and `%s of an empty array`, error 115 of pass 1 (also before an earlier pass-2 error), 225 at the second `narg`, a `dim:` value's 201, 237 and 262 in that order and before the call's 243, the `name: T` spelling of 243, the phase-rule word `named arguments` for a name the function does not take (`argmax(A, dim: 0)`; a repeated one at its first `narg`), and 217/201 for the fixed-size results of Decision 39. `err_ns_named_arg` (a named argument of a user function) stays.
From sub-phase 4g-1 (DESIGN.md §2.6.2 step 4g-1, "Readings fixed by 4g") strings, `match`, `error`, `args`, `str()` and `lower()` are implemented: the goldens `err_ns_string_let`, `err_ns_string_type`, `err_ns_str_literal`, `err_ns_arr_str_elem` and `err_ns_match` are retired (their constructs are `programs/str_basic`, `str_arrays` and `match_basic`), and `err_const_noval_calltype`, `err_const_noval_errtype` and `err_const_noval_shortcircuit` keep their intent with an undeclared struct type `Q` in place of `str` in the faulty result type (`unknown struct type`, 229, at the same `type` node, lead decision L-i). The 4g-1 tests below cover 201 (a `str` binding, a `match` scrutinee), 240 and 241 on `str` operands, 207 (no `_`, `_` not last, no arm, before a scrutinee error: L-a), 208 (within an arm, across arms, after `_`, a second `_`), 233, 210 and 211 for `error`, 243 for `lower`, `str` of an array and `args` (L-d), `missing return` after `error`, `program too large: strings` for a `str` constant value or part over 4 096 bytes (L-f), the word `strings` for a fixed-size `str` type, and the run-time errors of `error` (flushed output, a function, formatting, a `_` arm), `args()[0]` without arguments and an element-wise `str` shape mismatch. `str()` without an argument is a syntax error (`unexpected token ')'`, LANGUAGE.md Appendix A: `conv_type "(" expr ")"`). `err_ns_str_fixed_type`, `err_ns_struct` and `err_ns_record` stay until 4g-2.
From sub-phase 4g-2 (DESIGN.md §2.6.2 step 4g-2, "Readings fixed by 4g") structs, records, projection and fixed-size `str` and struct arrays are implemented: the goldens `err_ns_struct`, `err_ns_record`, `err_ns_str_fixed_type` and `err_ns_str_fixed_let` are retired (their constructs are `programs/struct_basic`, `records` and `str_fixed`). The 4g-2 tests below cover 204, 205, 206 at struct literals, 205 and 222 in a record literal (L-b, at the `init`), 221 (direct, through `P[]`, through `P[2]`, mutual: the first struct in source order), 222 and 235 in a declaration, 229 at a literal, 238 (a field of a `let` struct, an element's field of a `let` array, naming the root), 239 (a projection target), 240 (`p == q`), 249 (a struct, a record spelled `{a: i64, s: str}`, a matrix of structs `P[,]`, L-c), 256 (an array field, a struct field), 201 (a record where a struct is expected, also with the struct's field names), and the run-time check of a `str[3]` binding; positions as DESIGN.md §2.6.2 and §3.3 give them (a `dot` and a `bin` at their left operand, a `slit` at its type name, an `init` at its name, a `struct` at its keyword, a `field` at its name, a target at its text).

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
| `err_merge_same_pos` | `not supported yet: elemental functions` | two errors at one `fn` keyword: `seaname`'s (the `rerr`, found first) wins over `seacheck`'s `missing return` |
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
| `err_ns_default_arg` | `not supported yet: default arguments` | phase 1: a parameter default, reported at the param node (DESIGN.md 2.6.2) |
| `err_ns_elemental` | `not supported yet: elemental functions` | phase 1: an elemental fn (at the item, its elemental keyword) |
| `err_ns_f64_mod` | `not supported yet: f64 %` | phase 1: % with an f64 operand (at the bin node) |
| `err_ns_handle` | `not supported yet: handle types` | phase 1: a handle type (at the type node) |
| `err_ns_named_arg` | `not supported yet: named arguments` | phase 1: a named argument (at the narg) |
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
| `err_ns_ind2sub_array` | `not supported yet: ind2sub` | 4e: ind2sub with an array first argument stays the word ind2sub until phase 6, at the call (DESIGN.md 2.6.2 step 4e; Decision 33) |
| `err_rt_tasg_fix` | `shape mismatch: expected 2, got 3` | 4e (Decision 37): a dynamic result of 3 into a fixed `f64[2]` target of a tuple assignment, the run-time check of §4.5 at the statement's line (LANGUAGE.md §7.3) |
| `err_tasg_shape_static` | `shape mismatch: 2 vs 3` | 4e (Decision 37): a fixed `f64[3]` result into a fixed `f64[2]` target, 217 at the target, the target's shape first (DESIGN.md §3.5.5) |
| `err_tasg_type` | `type mismatch: expected f64[], found bool[]` | 4e (Decision 37): a `bool[]` result into an `f64[]` target, 201 at the target (DESIGN.md §3.5.5) |
| `err_rt_tasg_fix_cvt` | `shape mismatch: expected 3, got 4` | 4e (Decision 37): a dynamic `i64[]` result of 4 into a fixed `f64[3]` target, the run-time shape check at the statement's line (the conversion cannot fail) |
| `err_find_desc_unknown` | `not supported yet: named arguments` | 4f: find(m, desc: true): find takes no named argument |
| `err_find_f64` | `no overload of 'find_last' accepts (f64[])` | 4f: find of an f64 vector (bool vectors only, LANGUAGE.md 10.6) |
| `err_red_argmax_dim` | `not supported yet: named arguments` | 4f: argmax(A, dim: 0): argmax takes no dim:, so the phase rule's word at the narg, never 243 (LANGUAGE.md 10.5, DESIGN.md 2.6.2) |
| `err_red_desc_twice_unknown` | `not supported yet: named arguments` | 4f: a repeated name the function does not take is the phase rule's word at its first narg (DESIGN.md 2.6.2) |
| `err_red_desc_unknown` | `not supported yet: named arguments` | 4f: sum(v, desc: true): desc is not a name of sum: not supported yet: named arguments at the narg (DESIGN.md 2.6.2 step 4f) |
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
| `err_sort_dim_unknown` | `not supported yet: named arguments` | 4f: sort(v, dim: 0): dim is not a name of sort |
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
| `res_gen.py` | `passes/NAME.res` for every `passes/NAME.hir1`, `rs` and the `res_*` tests (run `res_gen.py [NAME...]`); from 4d with `rtype` and the array types of §3.4.2; from 4g-1 it evaluates `str` constants (`rcns`, and `rcnb` from `str` comparisons; L-f, L-g); from 4g-2 it evaluates structs (`rtst`/`rtfd`, `rslit`, the declaration checks 235, 222 and 221) |
| `lir4_gen.py` | the 4c pass-4 tests `passes/lir4_{retain_release,release_leaf,mcopy,slay,entries}.{lir,out}` |
| `res_cases.py` | `passes/res_*.{sea,ast}` (then their `.res` through `res_gen.py`) and `errors/err_merge_*`, `errors/err_const_noval_{calltype,shortcircuit,userpow}` (the two `err_const_noval_*` of these that use `str` are re-derived by `str4g_cases.py`); from 4g-1 its `NOVAL_*` sources use the undeclared struct type `Q` |
| `arr4d_cases.py` | the 4d `programs/arr_*`, `programs/heap_*` (except `heap_env_*`), `errors/err_rt_arr_*`, `errors/err_ns_arr_str_elem`, `errors/err_ns_lib_{max1,min1}` (its eight `arrays` cases were retired by 4e; the two `err_ns_lib_*` goldens by 4f, deleted by `arr4f_cases.py`; `err_ns_arr_str_elem` by 4g-1, deleted by `str4g_cases.py`) |
| `arr4e_cases.py` | the 4e `programs/{sel,ew,arr,heap}_*` from `sel_vec_read` on, `programs/w4_sor_arrays` (from `accept/w4_sor.sea`), the 4e `errors/` tests from `err_rt_sel_range_last` on; it deletes the ten retired 4d goldens (`err_ns_lib_max1_fixed` is retired by 4f, deleted by `arr4f_cases.py`; `err_ns_str_literal` is retired by 4g-1, deleted by `str4g_cases.py`) |
| `arr4f_cases.py` | the 4f `programs/{red,sort,find,heap_red}_*`, `programs/w4_sor_reduce` (from `programs/w4_sor_arrays.sea`), the 4f `errors/` tests `r_red_*`, `err_red_*`, `err_sort_*`, `err_find_*`; it deletes the four retired `err_ns_lib_*` goldens |
| `str4g_cases.py` | the 4g-1 `programs/{str,match,args,heap_str}_*` (with their `.args`), `programs/sort_str`, `programs/heap_str_views`, the 4g-1 `errors/` tests `r_str_*`, `r_args_*`, `r_error_*`, `err_str_*`, `err_match_*`, `err_error_*`, `err_lower_*`, `err_args_*`, `err_const_str_*`, `err_ns_str_fixed_let` (retired by 4g-2, deleted by `struct4g_cases.py`); it re-derives `errors/err_const_noval_{calltype,errtype,shortcircuit}` (run it after `res_cases.py`) and deletes the five retired goldens `err_ns_{string_let,string_type,str_literal,arr_str_elem,match}` |
| `dump4g_cases.py` | the 4g-1 dump tests `passes/str_rule{15,26,30,32,33}`, `passes/match_l16`, `passes/str_{l17,fill_flat,ew,l12}`, `passes/res_str_consts`: `.ast` as pass 1 writes it, `.res` from `res_gen.py` (`rcns`, L-f, L-g), `.hir1`, `.hirl` and `.lir1` by hand from §3.5, §3.5.9 and §3.6.6 with the agreed examples of rules 15, 26, 30, 32 and 33 verbatim, `.out` from LANGUAGE.md; every file self-checked against `passes.txt`; 4g-2: `passes/struct_rule{18,27,29}`, `passes/struct_{l17,l17_path,cow2,l6_field,l12}`, `passes/str_{ref_ln,fixed_self}`, `passes/rec_slay`, `passes/res_{rt,rtst}`, changed `res_struct`; struct layouts by hand from §4.8; the agreed examples of rules 18 (second), 27 and 29 verbatim |
| `struct4g_cases.py` | the 4g-2 `programs/{struct,heap_struct}_*`, `programs/str_fixed`, `programs/records`, the 4g-2 `errors/` tests `err_struct_*`, `err_record_*`, `r_str_fix`, `r_struct_dollar_*`; it deletes the four retired goldens `err_ns_{struct,record,str_fixed_type,str_fixed_let}` (run it after `arr4e_cases.py` and `str4g_cases.py`) |
| `manualD_part1.py` | `programs/manualD_part1.{sea,args,out}` and `errors/manualD_part1_badopt.{sea,args,err,status}` from LANGUAGE.md Appendix D; prints the 12 lines |
| `dump4d_cases.py` | `passes/arr_rule{16,17,18,19,30,31,36}.{sea,ast,hir1,hir,lir1,out}` (and their `.res` through `res_gen.py`) |
| `hirl4e0_cases.py` | `passes/NAME.hirl` for the 17 dump tests with a `.sea` and a `.lir1`, and the `passes/loop_*.{sea,ast,res,hir1,hir,hirl,lir1,out}` tests (`.res` through `res_gen.py`) |
| `dump4e_cases.py` | the 4e dump tests `passes/arr_rule{20,21,22,25,28}`, `passes/sel_{reads,ref_store,compound}`, `passes/ew_{colrow,ind2sub}`, `passes/arr_{lit_fixed,lit_dyn,lit_cat,lit_cat_fixed,views,dynfix,fixed,tasg_l12}` (`.sea .ast .res .hir1 .hir .hirl .lir1 .out`), and the rewritten `passes/res_err_array.res` (+ its new `.hir1`) |
| `fmt.py` | `rt/arm64_macos/rt_fmt_*` and `rt/x86_64_linux/rt_fmt_*` from one table (identical `.out` files) |
