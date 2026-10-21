# Exact arithmetic modules: SUB reference

These are the shared pass modules `limb.bas`, `f64emu.bas` and `fltlit.bas` (DESIGN.md §2.6.3,
§2.8, §2.10). Each `.bas` file has one header `REM` line, and each `SUB` line carries a one-line
`'` remark. This file holds the full interface.

| Module | Lines (DESIGN.md §2.6.3) | Needs |
|--------|--------------------------|-------|
| `limb.bas` | 69 000 – 74 999 | — |
| `f64emu.bas` | 75 000 – 81 999 | `limb.bas` |
| `fltlit.bas` | 82 000 – 88 999 | `limb.bas` |

None of these modules contains `DATA` or `END`. No SUB can stop the program (none raises a Baysick
`OVERFLOW`, `DIVISION BY ZERO` or `SUBSCRIPT ERROR` within the stated capacities). Together they
use 40 `FOR` statements.

## Conventions

* An **i64** or **f64** value is four numeric scalars `X3,X2,X1,X0`, each 0 … 65 535. They hold
  the 64-bit pattern (two's complement for i64, IEEE-754 binary64 with the sign bit first for f64),
  most significant limb first. This is the order of the generated consts `DATA` and of table `C`
  (DESIGN.md §2.6.3, §2.7), so `C(I,1),C(I,2),C(I,3),C(I,4)` can be passed directly.
* Scalars are passed **by reference**. Every SUB reads all its inputs before it writes an output,
  so an output may be the same variable as an input. A constant or expression argument is passed
  by value.
* A **bignum** is a numeric list `B()`: `B(0)` holds the number of limbs n, and `B(1)` … `B(n)`
  hold 16-bit limbs, least significant first, with `B(n) > 0` (n = 0 is zero). The caller
  dimensions the list.
* SUB names begin with `LM` (i64), `LB` (bignum), `FE` (f64) or `FL` (literals). SUBs marked
  *internal* are not for passes to call.

## limb.bas — i64

| SUB | Parameters | Result |
|-----|-----------|--------|
| `LMINT` | `S$,X3,X2,X1,X0,E` | `S$` is an `int_lit` as written (LANGUAGE.md §3.4: decimal or `0x` hex in either case, `_` separators). E = 0: ok (≤ 2⁶³ − 1). E = 1: the value is 2⁶³, X = `#8000000000000000`, legal only as the operand of unary `-`. E = 2: `integer literal too large`, X = 0. E = 3: not an `int_lit`, X = 0. |
| `LMADD` `LMSUB` `LMMUL` | `A3,A2,A1,A0,B3,B2,B1,B0,R3,R2,R1,R0,V` | R = A+B, A−B, A·B. V = 1 if the exact result is outside i64; R is then the result mod 2⁶⁴. |
| `LMNEG` | `A3..A0,R3..R0,V` | R = −A; V = 1 for A = −2⁶³. |
| `LMDIV` | `A3..A0,B3..B0,R3..R0,E` | floored `idiv(A,B)` (LANGUAGE.md §6.5). E = 1: overflow, `idiv(-2⁶³,-1)` (R = −2⁶³). E = 2: division by zero (R = 0). |
| `LMMOD` | `A3..A0,B3..B0,R3..R0,E` | floored `A % B`, which has the sign of B (LANGUAGE.md §6.6). E = 2: division by zero (R = 0). `-2⁶³ % -1` = 0. |
| `LMCMP` | `A3..A0,B3..B0,C` | signed: C = −1 if A < B, 0 if A = B, 1 if A > B. |
| `LMFMT` | `X3..X0,S$` | the `i` field (DESIGN.md §3.1): decimal if −10⁹ < v < 10⁹, else `#` and 16 hex digits. |
| `LMHEX` | `X3..X0,S$` | `#` and 16 upper-case hex digits (the `f` field). |
| `LMRD` | `S$,X3..X0,E` | reads an `i` field, accepting only the form `LMFMT` writes: `-`? and 1–9 digits without leading zeros (never `-0`), or `#` and 16 upper-case hex digits for \|v\| ≥ 10⁹. E = 1: anything else (X = 0). |
| `LMRF` | `S$,X3..X0,E` | reads an `f` field: `#` and 16 upper-case hex digits. E = 1: anything else (X = 0). |
| `LMFRN` | `N,X3..X0,E` | X = the integer Baysick number N, for \|N\| ≤ 2⁵³. E = 1 otherwise (X = 0). |
| `LMTON` | `X3..X0,N,E` | N = v when \|v\| ≤ 2⁵³. E = 1 otherwise (N = 0). |
| `LMDVM` | *internal* | floored quotient and remainder for B ≠ 0. |

## limb.bas — bignums

| SUB | Parameters | Result |
|-----|-----------|--------|
| `LBSET` | `B(),N` | B = N (integer, 0 ≤ N < 2⁵³). |
| `LBCPY` | `A(),B()` | B = A. |
| `LBMAD` | `B(),M,C` | B = B·M + C (integers, 0 ≤ M, C ≤ 10⁹). |
| `LBADD` | `A(),B()` | A = A + B. |
| `LBSUB` | `A(),B()` | A = A − B. Requires A ≥ B. |
| `LBMUL` | `A(),B(),C()` | C = A·B. C must be a different array from A and B. |
| `LBSHL` | `B(),K` | B = B·2^K. |
| `LBSHR` | `B(),K,T` | B = ⌊B / 2^K⌋. T = 1 if a 1 bit was shifted out. |
| `LBCMP` | `A(),B(),C` | C = −1, 0 or 1. |
| `LBLEN` | `B(),N` | N = the bit length (0 for zero). |
| `LBDIV` | `A(),B(),Q()` | Q = ⌊A / B⌋ and A = A mod B. Requires B > 0, Q different from A and B, and at most 1400 limbs. Bitwise: the work is proportional to the number of quotient bits. |
| `LBSQR` | `A(),Q()` | Q = ⌊√A⌋ and A = A − Q². At most 200 limbs. |
| `LBFLD` | `B(),P,W,F` | F = bits P … P+W−1 of B, for 1 ≤ W ≤ 53. |
| `LBLOW` | `B(),P,T` | T = 1 if any bit below position P is 1. |
| `LBLMB` | `X3..X0,B()` | B = the unsigned 64-bit pattern X. |
| `LBTOL` | `B(),X3..X0` | X = the low 64 bits of B. |
| `LBTOF` | `B(),X,G,T,R3,R2,R1,R0,V` | R = (−1)^G·(B + t)·2^X rounded to binary64: nearest, ties to even, with subnormals. Here t ∈ [0, 1), and t > 0 exactly when T = 1; T = 1 requires B's last bit to lie below the result's last place. V = 0: exact. V = 1: inexact. V = 2: overflow (R = ±∞). |
| `LBNRM` | *internal* | drops leading zero limbs. |

## f64emu.bas — binary64

Results are rounded to nearest, ties to even, with subnormals, signed zeros and infinities, as
IEEE-754 specifies, for every operand, finite or not. NaN results have arm64's bits (DESIGN.md
§2.8, "NaN bits"; FPCR.DN = 0): if an operand of `FEADD` `FESUB` `FEMUL` `FEDIV` `FESQR` `FEFMD`
`FEMOD` is a NaN, the result is the first NaN operand in operand order (A, then B) with its
quiet bit (bit 51) set, sign and payload kept (`FESUB` takes a NaN B before flipping its sign);
otherwise an invalid operation (∞ − ∞, 0 × ∞, 0 ÷ 0, ∞ ÷ ∞, √ of a number below zero, `fmod`
of an infinite A or by a zero B, `%` of an infinite A) gives the default NaN
`#7FF8000000000000` (DESIGN.md §3.5.5's `nan`). There are two exceptions: `FENEG` flips the sign
bit of any value, a NaN included (LANGUAGE.md §6.5), and `FEMOD` with B = ±0 returns A
unchanged, a NaN A included and not quieted (LANGUAGE.md §6.6).

| SUB | Parameters | Result |
|-----|-----------|--------|
| `FEADD` `FESUB` `FEMUL` `FEDIV` | `A3,A2,A1,A0,B3,B2,B1,B0,R3,R2,R1,R0` | R = A op B. x − x = +0, −0 + −0 = −0, x/±0 = ±∞, 0/0 = NaN, ∞ − ∞ = NaN, ∞·0 = NaN. |
| `FEFMD` | (same) | R = fmod(A, B), exact (C `fmod`: B = 0, A = ±∞ or A or B NaN give NaN; B = ±∞ gives A; a zero result has A's sign). |
| `FEMOD` | (same) | R = A % B (LANGUAGE.md §6.6): B = ±0 gives A; then A infinite or NaN, or B NaN, gives NaN; otherwise r = fmod(A, B), and if r ≠ 0 and r and B differ in sign, r = r + B (one rounded addition). A zero r keeps fmod's sign (`-6.0 % 3.0` is −0). |
| `FESQR` | `A3..A0,R3..R0` | the correctly rounded square root: √±0 = ±0, √(x < 0) = NaN, √+∞ = +∞. |
| `FENEG` | `A3..A0,R3..R0` | flips the sign bit. |
| `FECMP` | `A3..A0,B3..B0,C` | C = −1 (A < B), 0 (A = B; +0 = −0), 1 (A > B), 2 (unordered: a NaN). |
| `FECLS` | `A3..A0,K,S` | K = 0 zero, 1 subnormal, 2 normal, 3 infinity, 4 NaN; S = the sign bit. |
| `FEFRI` | `I3..I0,R3..R0,X` | converts i64 to f64, nearest, ties to even (2⁵³+1 gives 2⁵³). X = 1 if inexact (`integer constant not exact in f64`). |
| `FETOI` | `A3..A0,R3..R0,E` | converts f64 to i64. E = 1: not an integer, or not finite. E = 2: an integer outside i64. R = 0 unless E = 0. |
| `FETON` | `A3..A0,N,E` | N = the finite value as a Baysick number (exact; −0 gives −0). E = 1 for ±∞ or NaN (N = 0). |
| `FEFRN` | `N,R3..R0` | R = the bit pattern of the Baysick number N (exact), except that **a zero always gives +0**: a Baysick program cannot tell −0 from +0. |
| `FEUNP` | `A3..A0,S,K,M,E` | sign S, class K (as `FECLS`), and \|A\| = M·2^E with M an integer below 2⁵³ (M = 0 for zeros, infinities and NaN). |
| `FEMTI` | `MT(),E` | reads the `mtab` `DATA` block (DESIGN.md §2.6.3) from the current `DATA` position into `MT()`, which the caller dimensions with 2689 elements: `MT(0)` = 672, word w (0-based: 32 constants, the `exp` table, the `log` table) at `MT(4w+1)` … `MT(4w+4)`, most significant limb first. E = 0: ok. E = 1: a count, limb or the sentinel disagrees (the caller reports `BAD_DATA`). |
| `FEPOW` | `MT(),X3..X0,Y3..Y0,R3..R0` | R = `pow(X, Y)` with exactly the runtime's bits: the operation sequence of DESIGN.md §4.10.4 (`pow` steps 1–12, `log_core`, `exp_core`), every IEEE operation through `FEADD` `FESUB` `FEMUL` `FEDIV` `FENEG` in the order written there, every integer step exact on the limbs; special cases as C99 Annex F; every NaN result `#7FF8000000000000` (not the NaN-propagation rule above). `MT()` as `FEMTI` filled it. |
| `FELGC` `FEEXC` `FE2SM` `FEF2S` `FESPL` `FE2PR` | *internal* | `log_core`, `exp_core`, `two_sum`, `fast_two_sum`, `split`, `two_prod` of DESIGN.md §4.10.2–§4.10.4, used only by `FEPOW`. |
| `FEPCK` `FEADS` `FEMDS` `FEQNP` | *internal* | pack M·2^E, the signed add, an exact modulo, and the propagated NaN (`FEQNP: A3..A0,B3..B0,N,R3..R0,Y`: Y = 1 and R = the first NaN among the N operands, quieted; Y = 0 and R untouched if none). |

**Folding.** Folding is not guarded (DESIGN.md §2.8, §3.5.7): pass 2b folds a foldable operation
whatever its operands' values, and the folded **value** is always computed with `FEADD`,
`FESUB`, `FEMUL`, `FEDIV` or `FESQR` (and a sign flip with `FENEG`); this gives the run time's
bits exactly, signed zeros, infinities and arm64's NaN bits included (−1.0 × +0.0 = −0, √−0 = −0,
−10⁻²⁰⁰ × 10⁻²⁰⁰ = −0, 10³⁰⁰ × 10³⁰⁰ = +∞). **`FETON` and `FEFRN` must never be used to produce a
folded result.** The round trip through a Baysick number loses the sign of a zero, and Baysick's
`SQR` takes √\|x\|, so `SQR(-0)` is +0.

## fltlit.bas — float literals

| SUB | Parameters | Result |
|-----|-----------|--------|
| `FLCVT` | `S$,R3,R2,R1,R0,E` | `S$` is a `float_lit` as written: digits, `_`, `.`, `e`/`E`, sign, digits. R = the binary64 value nearest the exact decimal value, ties to even; an underflow gives the nearest subnormal or +0. E = 0: ok. E = 1: `float literal out of range`, because the value rounds to ∞ (R = `#7FF0000000000000`). E = 2: `invalid numeric literal`, meaning not a `float_lit` of LANGUAGE.md §3.4, `_` rules included; an `int_lit` such as `123` is invalid here (R = 0). E = 3: `S$` is longer than 4096 bytes, a source line's limit (R = 0). |

Method: the digits form an exact bignum M, with trailing zeros moved into the decimal exponent D.
For D ≥ 0, M·10^D is rounded directly. For D < 0, the quotient M·2^s / 10^−D is taken with at
least 55 bits plus a sticky remainder, then rounded with `LBTOF`. A 4096-byte literal needs at
most about 930 limbs.

## Tests

`sh tests/arith_check.sh` builds the harnesses in `tests/harness/` together with these modules
and checks them against `tests/vectors/limb.txt`, `f64emu.txt` and `float.txt`. Those files are
generated by `uv run python tests/vectors/f64emu.py` and `float.py` from exact definitions.
`FEPOW` is checked against `tests/vectors/fepow.txt` (`pow #X #Y #R` lines, written by
`tests/vectors/math_vectors.py` from the bit-exact model, DESIGN.md §4.10.6); the `f64emu`
harness is built with the generated `mtab` block appended for it.
