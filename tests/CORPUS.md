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
* `passes/`: `sea build --emit X --no-prelude NAME.sea` for each `NAME.X` present (§3.8).

## How the expected outputs were derived

| Class | Derivation |
|-------|------------|
| f64 bits of literals and constant arithmetic | `vectors/float_oracle.py`: exact `Fraction` decimal-to-binary, round to nearest even, subnormals, overflow; `+ − × ÷` and i64→f64 the same way. Python floats only as a cross-check |
| printf output (`fmt_*`, `op_f64_arith`, `op_order`, `op_powk`, `lib_consts`) | `vectors/progfmt.py`: C99 `%d %i %f %F %e %E %g %G %s` from the exact decimal value of each argument (ties to even), plus the MATLAB `%d`-on-f64 rule and the non-finite rules of LANGUAGE.md §11.1. It writes both `.sea` and `.out` from one table; Python's `%` only as a cross-check |
| `op_lcg_w5` | `vectors/lcg_w5.py`: the LCG in exact integers in W5's draw order (11 M steps), the uniform `first_dev` columns and `first_top` with the oracle; asserted bit for bit against `workloads/reference/w5_tolerance_mc.json` (`lcg_final = 2145635252`) |
| wave-2 tests (`fold_*`, `stmt_else_if_2000`, `const_reverse_1000`, `fmt_prec_zeros`, `stmt_tasg_cvt`, `lib_conv_identity`, `stmt_for_blanks` and their `err_*`) | `vectors/wave2_gen.py`: each expected value derived in its comments; folded values with the exact oracles of `f64emu.py`/`float_oracle.py` |
| `vectors/f64emu.txt` NaN results | DESIGN.md §2.8 "NaN bits": a NaN operand propagates quieted (bit 51 set, sign and payload kept), the first NaN operand (A, then B) wins, an invalid operation gives `#7FF8000000000000`; no `grd` vectors (U1 removed the folding guards) |
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
| `lib_now` | §13 (difference ≥ 0; the value is never printed) |
| `lib_consts` | §10.1, §7.2; DESIGN.md §3.5.5 (bits of `pi inf nan eps`) |
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
| `lx` | ast hir1 hir lir1 lir | §3.6.7 example (lir1/lir verbatim); ast §3.4, hir1/hir §3.5 |
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
| `fn_ref` | ast hir1 hir lir1 | LANGUAGE.md §8.3; §3.5.4, §3.6.3, §3.6.6 rule 12 |
| `fn_multi` | ast hir1 hir lir1 | LANGUAGE.md §8.4; §3.5.1 `ttuple`, §3.5.5 `tbind`/`tret`, §3.6.6 rules 2, 5 |
| `fn_ref_order` | ast hir1 hir lir1 | LANGUAGE.md §6.8 rule 5; §3.6.6 rule 12 (copy at the evaluation point, reloads, `mov x R` last) |
| `fn_printf` | ast hir1 hir lir1 | LANGUAGE.md §11.1, §13, §10.1; §3.5.5 `fmt`, §3.6.2, §3.6.6 rules 7–10 |
| `type_ifx_arm` | ast hir1 hir lir1 | LANGUAGE.md §4.2 (f); §3.6.6 rules 2–3 (ifx and `&&` at the root of a stored value: new R, then `mov`) |
| `op_fold` | ast hir1 hir | §3.5.7 step 2, §2.8 (U1: overflow, `x / 0`, `inf`/`nan` operands fold; NaN bits) |
| `op_shortcircuit` | ast hir1 hir lir1 | §3.5.5 `ifx`; §3.6.6 rule 3 |
| `stmt_tasg` | ast hir1 hir lir1 (+ `.out`) | LANGUAGE.md §7.3, §4.2 (b); §3.5.5 `tasg` `cv` flags; §3.6.6 rule 2 `tasg` steps (a)–(d): cv 1 into a local (`itof`, `mov`), cv 0 straight into the target register, `skip` a new register, a `ref`-parameter target with cv 1 (`itof`, `stf`), a target local the call passes by `ref` (new register, reload, then `mov`) |
| `stmt_loops` | ast hir1 hir lir1 | §3.5.5 `while` `forr` `cont` `break`, §3.5.7 (step −2 folded); §3.6.6 rule 4 |
| `gen_arith` | lir (+ `.out`) | pass-4 input written as LIR; `.out` lines 3–4 derived from the spec: the `d`/`e` of 12 `rcount`s by DESIGN.md §3.6.4: n elements of the range (LANGUAGE.md §5.1), `d` = 0 for an empty range (n = 0), else (n−1) mod 2⁶⁴ printed as i64 (−1 for the full range n = 2⁶⁴), `e` = 1 iff n > 0 |
| `fn_reach` | ast hir1 hir | §3.5.7 step 5, §3.5.1 renumbering |

Every function in a `.lir1`/`.lir` test has a loop or is recursive and has two or more call
sites, so LANGUAGE.md §8.6 requires no inlining (§3.6.6). Only `lx.lir` is pinned for pass 3b
(§3.6.5: the other loop bodies hold constants that a later pass 3b may hoist).

## errors/

Every C1 code 101–114 (and the driver's 100), the C2 codes that phase 1 can reach (204–208,
216–222, 224, 225 cannot occur in phase 1, DESIGN.md §2.6.2), the phase rule (259) for every
construct word, capacity code 400 (`parameters`, `nesting` per the depth definition of §2.7),
and the phase-1 run-time errors (codes 4, 5, 6, 7, 15, 17). Pass-2 errors of all kinds are
reported in plain source order (§2.6.2). The column of each compile error is
the `at` position of DESIGN.md §2.6.2.

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
| `err_const_mod_chain` | `integer division by zero` | the reviewer's % chain: C3 = 0 % 0 divides by zero at compile time (LANGUAGE.md 7.2 U2; at the operator) |
| `err_const_mod_zero` | `integer division by zero` | a constant % by zero is a compile error (LANGUAGE.md 7.2 U2, 6.6) |
| `err_const_overflow_inner` | `integer overflow` | the innermost failing operation in evaluation order is reported (DESIGN.md 2.6.2 expr; LANGUAGE.md 7.2) |
| `err_const_overflow_neg` | `integer overflow` | unary minus of -2^63 in a constant (LANGUAGE.md 7.2, 6.5) |
| `err_const_overflow_unused` | `integer overflow` | a constant that overflows i64 is a compile error even unused (LANGUAGE.md 7.2 U2; at the operator) |
| `err_const_poison_and` | `integer overflow` | a constant whose operand constant failed reports only that failure (LANGUAGE.md 7.2 U2) |
| `err_const_poison_pow` | `integer overflow` | a constant exponent whose evaluation overflows reports the overflow (LANGUAGE.md 7.2 U2) |
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
| `err_missing_arg` | `missing argument` | a parameter without a default must be given (LANGUAGE.md 8.1; at the call) |
| `err_missing_return` | `missing return` | a function with a result must end every path with return (LANGUAGE.md 8.1; at fn) |
| `err_missing_return_while` | `missing return` | a loop never ends every path, even while true (LANGUAGE.md 8.1) |
| `err_multi_value` | `multiple-result call used as a value` | a multiple-result call inside an expression (LANGUAGE.md 8.4; at the call) |
| `err_multi_value_arg` | `multiple-result call used as a value` | a multiple-result call as an argument (LANGUAGE.md 8.4; at the call) |
| `err_no_effect` | `expression statement has no effect` | a line starting with a binary operator is a new statement (LANGUAGE.md 3.7) |
| `err_no_effect_asg` | `expression statement has no effect` | x + y = 3 is an expression statement (LANGUAGE.md 7.1) |
| `err_no_effect_binop` | `expression statement has no effect` | an operator expression is not a call (LANGUAGE.md 7.1; at stmt) |
| `err_no_effect_name` | `expression statement has no effect` | a bare name is not a call (LANGUAGE.md 7.1; at stmt) |
| `err_no_overload_idiv` | `no overload of 'idiv' accepts (f64, i64)` | idiv takes two i64 (LANGUAGE.md 6.6; at the call) |
| `err_no_overload_now` | `no overload of 'now' accepts (i64)` | now takes no argument (LANGUAGE.md 13) |
| `err_not_constant` | `not a constant expression` | a const expression must be constant (LANGUAGE.md 7.2; at expr) |
| `err_not_constant_cycle` | `not a constant expression` | a constant cycle through another constant: at the name that closes it (LANGUAGE.md 7.2) |
| `err_not_exact_f64` | `integer constant not exact in f64` | an untyped integer that becomes f64 must be exact (LANGUAGE.md 4.2; at expr) |
| `err_not_exact_ifx` | `integer constant not exact in f64` | an untyped arm beside an f64 arm is f64 and must be exact (LANGUAGE.md 4.2 (f)) |
| `err_not_exact_printf_f` | `integer constant not exact in f64` | an untyped literal argument of %f is f64 and must be exact (LANGUAGE.md 4.2 (e)) |
| `err_not_function` | `'a' is not a function` | calling a local (DESIGN.md 2.6.2; at the call) |
| `err_not_function_const` | `'C' is not a function` | calling a constant (DESIGN.md 2.6.2; at the call) |
| `err_ns_array_literal` | `not supported yet: arrays` | phase 1: an array literal (at the array node) |
| `err_ns_array_type` | `not supported yet: arrays` | phase 1: an array type (at the type node) |
| `err_ns_default_arg` | `not supported yet: default arguments` | phase 1: a parameter default, reported at the param node (DESIGN.md 2.6.2) |
| `err_ns_elemental` | `not supported yet: elemental functions` | phase 1: an elemental fn (at the item, its elemental keyword) |
| `err_ns_f64_mod` | `not supported yet: f64 %` | phase 1: % with an f64 operand (at the bin node) |
| `err_ns_handle` | `not supported yet: handle types` | phase 1: a handle type (at the type node) |
| `err_ns_lib_abs` | `not supported yet: abs` | phase 1: abs is a library function not yet supported |
| `err_ns_lib_sqrt` | `not supported yet: sqrt` | phase 1: a library function other than printf now f64 i64 idiv |
| `err_ns_match` | `not supported yet: match` | phase 1: a match statement (at the match node) |
| `err_ns_named_arg` | `not supported yet: named arguments` | phase 1: a named argument (at the narg) |
| `err_ns_pow` | `not supported yet: pow` | phase 1: ^ that is not a powk (at the bin node) |
| `err_ns_pow_call` | `not supported yet: pow` | an exponent that contains a call is never integral (LANGUAGE.md 6.5) |
| `err_ns_record` | `not supported yet: records` | phase 1: a record literal (at the rlit) |
| `err_ns_string_let` | `not supported yet: strings` | phase 1: a string literal that is not a printf %s argument |
| `err_ns_string_type` | `not supported yet: strings` | phase 1: the str type (at the type node) |
| `err_ns_struct` | `not supported yet: structs` | phase 1: a struct item (at the item) |
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
| `fmt.py` | `rt/arm64_macos/rt_fmt_*` and `rt/x86_64_linux/rt_fmt_*` from one table (identical `.out` files) |
