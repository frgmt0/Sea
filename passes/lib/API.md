# passes/lib -- API of the shared pass modules

Reference for `io.bas`, `diag.bas`, `tables.bas`, `layout.bas` and `ralloc.bas` (DESIGN §2.6.3), and for the
shared main-program part `lirrw.bas` (not a module of SUBs: its section below). The `.bas` files carry
only a one-line summary per SUB. Every module has no `DATA`, no `END` and no globals; a SUB
works on its parameters (at most 16 per SUB, Baysick limit). A pass is built as its own file,
the modules of its `build.list`, the generated `DATA` blocks and `99999 END`.

Common parameters:

| name | meaning |
|---|---|
| `K` | file number: 0 = standard input / output, k >= 1 = the pass's FILES names |
| `L$` | one record (a line without its LF) |
| `P$` | pass name for diagnostics, e.g. `"seaparse"` |
| `E() E$() E0` | the error table loaded by `tb_errors`: `E(i)` = code, `E$(i,1..5)` = name, phase, at, args, text, for `i = 1..E0`. `E$(0,1)` and `E$(0,2)` are reserved: the exit statuses `SEA_EXIT_PASS_INTERNAL` and `SEA_EXIT_PASS_COMPILE` as text, set by `tb_exits`. The caller DIMs `E$` from index 0. |
| `T` | status out: 0 = ok, otherwise the code named at each SUB |

## io.bas (lines 60000-62999)

Needs `diag.bas` (`dg_internal`) and, for `io_hdr`, `tables.bas` (`tb_enum`, `tb_word`).

### Record input and output (the end-of-input discipline of DESIGN §2.2 step 6)

* `io_read K, L$, L9, P$, E(), E$(), E0` -- `L$` = next record of file K, read with LINPUT
  after IF END; `L9` counts the lines read (+1 per record). If the input ends first: the
  internal error `TRUNCATED` (exactly one line, DESIGN §2.2), STOP 11.
* `io_end K, P$, E(), E$(), E0` -- call after the record `#end` was read: nothing may follow,
  else `BAD_RECORD`.
* `io_put K, L$` -- writes one record (`PRINT #K, L$`); the caller wrote `SCRATCH #K` once.
* `io_fin K` -- writes the last record, `#end`.
* `io_plain L$, O` -- `O` = 1 if every byte of `L$` is in 0x20-0x7E (DESIGN §3.1), else 0.
* `io_split L$, F$(), M, N` -- splits a record at single blanks into `F$(1..N)`. `N` = -1 if
  the record is empty, starts or ends with a blank, has two blanks in a row, or has more than
  `M` fields.

### Field encodings (DESIGN §3.1)

Decoders are strict: they accept exactly what the writers produce (upper-case hex, no needless
escapes), so a decoded field encodes back to itself.

* `io_unesc S$, M, R$, T` -- decode a string field. `M` = 0 record field, `M` = 1 DATA string
  (a quote must be written `%22`). `T` = 1 malformed (bad or short escape, empty field),
  `T` = 2 not canonical (a byte escaped that must not be, or written raw that must be
  escaped). The field `%` is the empty string.
* `io_esc S$, M, R$` -- encode a string field; the empty string gives `%`.
* `io_u F$, V, T` -- u field: 1 to 9 digits, no leading zero. `T` = 1 if not.
* `io_i F$, V, K, L(), T` -- i field. `L(1..4)` = the four 16-bit limbs of the two's
  complement pattern, most significant first (always set). `K` = 0: decimal, `V` = value;
  `K` = 1: hex (|v| >= 1E9), `V` = 0, use `L()`. Non-canonical forms (-0, hex for a value that
  must be decimal, lower case) give `T` = 1.
* `io_f F$, L(), T` -- f field: `#` and 16 upper-case hex digits; `L(1..4)` as above.
* `io_hex L(), R$` -- inverse: `R$` = `#` and 16 hex digits of the limbs `L(1..4)`.
* `io_pos F$, F, L, C, T` -- position `F:L:C` (file index >= 0, line >= 1, column >= 1).
* `io_site F$, F, L, T` -- site `F:L`.
* An i value with |v| < 1E9 and a u value are written with `STR$`.

### Header records (DESIGN §3.2)

`V` = `SEA_FILE_VERSION` from the consts table (not written here).

* `io_hdr K, P$, E(), E$(), E0, N(), N$(), W$(), N0, V, T$, F$(), M, N1, L$` -- reads
  `#sea V`, `#target T$` (a word of enum `target`; `N() N$() W$() N0` from `tb_records`), then
  the `#file` records that follow at once into `F$(1..N1)` (decoded paths, at most `M`).
  `L$` = the first record that is not a `#file` record (a body line, or `#end`); it is line
  `N1 + 3` of the file, so a pass counting lines sets its counter to `N1 + 3` before the next
  `io_read`. Any other shape: `BAD_HEADER`, STOP 11.
* `io_file P$, E(), E$(), E0, L$, F$(), M, N1, Y` -- one `#file` record. The pass-1 stream
  (DESIGN §3.2) carries the `#file` record of each source file followed by that file's source
  lines (`|`), so `io_hdr` returns after the first file. A pass-1 reader calls `io_file` for
  each later record it meets: `Y` = 1 if `L$` was a `#file` record, whose decoded path was
  appended (`N1` + 1, `F$(N1)`); `Y` = 0 if it is some other record (nothing changed). A
  `#file` record with the wrong shape, a bad path or more than `M` files: `BAD_HEADER`. `io_hdr`
  uses it for its own loop.
* `io_hdr_put K, V, T$, F$(), N1` -- writes the same header records (a pass copies its input's).

## diag.bas (lines 63000-65999)

Messages come from the error table (`tb_errors`), never from literals; the exit statuses come
from the exits table (`tb_exits`). Bootstrap exception: `dg_boot`, `dg_bug` and the fallback of
`dg_exit` (used until `tb_exits` has run) hold the literals 11 and 10 of
`SEA_EXIT_PASS_INTERNAL` / `SEA_EXIT_PASS_COMPILE`; `tests/lib_check.sh` compares them with
`include/errors.inc`.

* `dg_compile P$, F$(), N1, F, L, C, Q$, A$(), N2, E(), E$(), E0` -- a Sea compile error
  (phase D, C1, C2, CX): writes `<file>:<line>:<col>: error: <message>` + LF to standard error
  (`PRINT #-1`) and ends the pass with `SEA_EXIT_PASS_COMPILE`. `F` is the file index of the
  position `F:L:C`. `Q$` = the error's name in `errors.inc`. `A$(1..N2)` = substitution values,
  as text, in the order of the `%s %d %g` marks (the caller formats numbers with `STR$` and f64
  values the way Sea's `%g` does). `F$() N1` = the source paths of the header.
* `dg_internal P$, Q$, E(), E$(), E0` -- a pass-internal check (phase P): writes
  `<P$>: <message>` + LF, ends with `SEA_EXIT_PASS_INTERNAL`.
* `dg_note P$, M$` -- writes `<P$>: <M$>` + LF, no stop. (The passes' own output must be the one
  line above; this is for tools such as `seaval`.)
* `dg_bug P$, M$` -- `<P$>: <M$>` + LF and STOP 11: misuse of these modules (unknown error
  name, wrong argument count), a bug in the pass and not in its input.
* `dg_boot P$` -- `<P$>: internal error: bad DATA table` + STOP 11, for the one case where the
  error table itself is malformed (text of code 504, `BAD_DATA`).
* `dg_find Q$, E$(), E0, R` -- `R` = row of `Q$` in the error table, or 0.
* `dg_fmt T$, A$(), N2, R$, T` -- `R$` = `T$` with the marks `%s %d %g` replaced by `A$(1..)` in
  order (values are inserted as they are, never re-scanned); `T` = 0, or 1 if the number of
  marks is not `N2`.
* `dg_exit E$(), K, S` -- `S` = exit status `K` (1 internal, 2 compile) from `E$(0,K)`.

## tables.bas (lines 66000-68999)

Needs `io.bas` and `diag.bas`. The blocks are generated by `tools/gendata` and follow the
pass's own DATA in line order. Numeric and string DATA are separate streams (Baysick LANGUAGE
§7.5), so the loaders are called in the canonical order errors, errno, exits, consts, entries,
records, and only for the blocks the pass includes (its `build.list`). A loader reads its block
with a counted loop of at most the capacity `M` rows plus the sentinel; a table with more rows
than `M`, a missing sentinel or a misaligned stream ends the pass: `BAD_DATA`, STOP 11.
(Baysick ends a program that READs past the last DATA value with status 0 and a message OUT OF
DATA; the generator always writes the sentinels.)

Error context of the loaders after `errors`: `P$` pass name, `E() E$() E0` the error table.
Strings are stored decoded. Row `i` is 1-based; the caller DIMs the arrays with the bound `M`
(and the second bounds shown).

* `tb_errors P$, E(), E$(), M, N` -- `E(M)`; `E$(M,5)` (and `E$` from index 0). `N` rows:
  `E(i)` = code, `E$(i,1)` = NAME, `E$(i,2)` = phase (R D C1 C2 CX P), `E$(i,3)` = at,
  `E$(i,4)` = args, `E$(i,5)` = text. Needs no error table: on failure it writes
  `<P$>: internal error: bad DATA table` (`dg_boot`).
* `tb_errno P$, E(), E$(), E0, R(), R$(), M, N` -- `R(M,3)`; `R$(M,2)`: `R(i,1)` = id,
  `R(i,2)` = darwin errno, `R(i,3)` = linux errno, `R$(i,1)` = NAME, `R$(i,2)` = text.
* `tb_exits P$, E(), E$(), E0, X(), X$(), M, N` -- `X(M)`; `X$(M)`: value and NAME (without
  `SEA_EXIT_`). Also stores the statuses `PASS_INTERNAL` and `PASS_COMPILE` in `E$(0,1)` and
  `E$(0,2)` for `dg_internal` and `dg_compile`; either one missing: `BAD_DATA`.
* `tb_consts P$, E(), E$(), E0, C(), C$(), M, N` -- `C(M,4)`; `C$(M)`: `C$(i)` = the name as
  the generator writes it (the `SEA_` prefix is removed: `FILE_VERSION`, `LIM_LIR_REGS`),
  `C(i,1..4)` = the 16-bit limbs of the 64-bit pattern, most significant first.
* `tb_entries P$, E(), E$(), E0, Y(), Y$(), M, N` -- `Y(M)`; `Y$(M,5)`: id, and NAME, symbol,
  site, args, results of a runtime entry (`rt.inc`).
* `tb_records P$, E(), E$(), E0, N(), N$(), W$(), R(), R$(), F(), F$(), Z()` -- `passes.txt`
  as tables. `Z(1..4)` = capacities (enums, enum words, records, fields) set by the caller
  before the call; `Z(5..8)` = the counts found.
  * enum row i: `N$(i)` name, `N(i,1)` = index of its first word in `W$()`, `N(i,2)` = count
    (`N(M1,2)`; `W$(M2)`); the words are `W$(N(i,1)) ... W$(N(i,1)+N(i,2)-1)`.
  * record row i (a head or a rec line): `R$(i)` = opcode name (head: the name without the
    `#`), `R(i,1)` = set (0 head, 1 A, 2 H, 3 H1, 4 HF, 5 L, 6 LF, 7 HL), `R(i,2)` = opcode number,
    `R(i,3)` = first field row in F, `R(i,4)` = number of fields, `R(i,5)` = number of pop
    terms (0..4), `R(i,6..9)` = the terms: a number >= 0 is a constant, -j means the value of
    the j-th field of the record (a u field). `R(M3,9)`.
  * field row k: `F$(k)` name, `F(k,1)` = type code, `F(k,2)` = 1 if the field may be `-`,
    `F(k,3)` = j > 0 if the field repeats as often as the j-th field of the record says (a u
    field), else 0. `F(M4,3)`.
  * type codes: 1 u, 2 i, 3 f, 4 s, 5 pos, 6 site, 7 fl, 8 ty, 9 lid, 10 fid, 11 cid, 12 iid,
    13 blk, 14 lab, 15 slot, 16 reg, 17 ri, 18 rf, 19 rp, 20 rx, 21 ry, 22 rm, and 100 + i for
    the enumeration of enum row i.

Lookups (no error context: a miss is a result):

* `tb_find K$(), N, S$, R` -- `R` = row of `S$` in the list `K$(1..N)`, or 0.
* `tb_enum N$(), N0, S$, R` -- `R` = enum row named `S$`, or 0.
* `tb_word N(), W$(), R1, S$, R` -- `R` = position (1..) of word `S$` in enum row `R1`, or 0.
* `tb_cval C(), C$(), N, Q$, V, T` -- `V` = the constant `Q$` as a number if it is an integer
  of magnitude below 2^53 (`T` = 0); `T` = 1 if absent or not representable.

Internal SUBs (not part of the API): `tb_fail`, `tb_dec`, `tb_fspec`, `tb_type`.

## lirrw.bas (lines 69000-81999)

Not a module of SUBs: the **shared main-program part** of the LIR passes (DESIGN §2.6.3, §2.7,
lead decisions L-bd, L-bi, L-bp; from sub-phase 5c-2, in the build lists of `seaopt` and
`sealopt`, from 7b also of `seavec`; the vector classes and the set-LF records from 7e, Decision 113:
section "Vector classes and set LF" below). It holds pass 3b's LIR reader, validator and writer (DESIGN §3.6.5: the whole
validation list, the capacity limits, the header records, the renumbering writer) and T10 of
DESIGN §5.8 (clean-up and renumbering), moved out of `seaopt` unchanged, so that both passes
read, check, clean and write LIR identically. Its lines are main-program lines, concatenated by
the build after `tables` like a module (Baysick passes control around the `SUB` blocks before
them); they work on the pass's own arrays and scalars, which a SUB could not share. It has no
`DATA`, no `END` and no `SUB`; it reaches `io`, `diag` and `tables` by `CALL` (it needs all three)
and never jumps to a line of the pass. Its lines overlap those of `limb` and `f64emu`: a
`build.list` naming `lirrw` with either is a build error (`make`: `lirrw cannot be loaded with
...`). **Line 69000 is a guard**: control falling into the part (a pass whose last line is not a
`STOP`, `GOTO` or `RETURN`) ends the pass with `dg_bug` (`<P$>: control fell into lirrw.bas,
which is entered only by GOSUB`, status 11).

### The contract: arrays

The pass `DIM`s exactly these 38 arrays with these bounds (`seaopt`'s, DESIGN §2.7), and gives
up their letters: the numeric arrays `A B C D E F G H I J K L M N O P Q R T U W X Y Z` (24) and
the string arrays `A$ D$ E$ F$ G$ H$ J$ N$ Q$ S$ U$ V$ W$ Y$` (14).

    DIM E(299), E$(299,5), N(39,2), N$(39), W$(299), Q(399,9), Q$(399), F(1499,3), F$(1499), Z(8)
    DIM J(299,4), J$(299), Y(399), Y$(399,5), D(39), D$(39), B(399), A(399)
    DIM I(199999,4), O(799999), R(99999,9), K(19999,4), C(199999,4), S$(199999)
    DIM X(131071), T(10000), G$(300), U(40), L(4), H$(100), A$(2)
    DIM M(301), P(262143), H(199999), V$(49999), U$(131071), G(199999,3), W(199999,4)

| array | use |
|---|---|
| `E E$` `D D$` `J J$` `Y Y$` | the tables of the `errors`, `exits`, `consts` and `entries` blocks (`tb_*`; counts `E0 N5 N6 N7`) |
| `Q Q$ F F$ N N$ W$ Z` | `passes.txt` (`tb_records`); the part adds `Q(row,6)` the internal opcode code (`li` 1 … `release` 72, the table at line 76115); for the rows of set LF 73 … 119, the table at line 76136, below), `Q(row,7)` the category (1 pure, 2 `iaddc isubc imulc inegc`, 3 load, 4 store), `Q(row,8)` the memory kind of a load or store (1 i64, 2 byte, 3 f64, 4 address; `ldx ldy stx sty` 3, `ldm2 ldm4 stm2 stm4` 2), `F(field,0)` the field's role (0 site, no operand; 1 register read; 2 register written; 3 an `i`/`f` immediate, a row of `C`; 4 an `off` field, a row of `G`; 5 a `u` count; 6 any other one-operand field; 7 a `pos`, two operands) |
| `A B` | the rows of set L (`A(1..A8)`; the rows of set LF are not among them: `Q(row,1)` = 6) and the special code of each record row (`B`; 0 for every LF row) |
| `I O M` | instruction n (1..`A0`, row 0 the func record): `I(n,1)` its row of `Q` (0: deleted until the next compaction), `I(n,2)` the index in `O` of its first operand, `I(n,3)` the operand count, `I(n,4)` the site (F·1E9+L, 0 none); `I(n,0)` the pass's between entries, but entries 69440 (T10) and 69460 (dead records) overwrite it for every record 1..`A0` (-1 dead, else 0). `O(1..A1)` the operands in record order; the func record's fields in `M(1..A5)` |
| `R` | register r (1..`M7`): `R(r,1)` the class (1 `i`, 2 `f`, 3 `p`, 4 `x`, 5 `y`, 6 `m`), owned by the reader (set by a pass for the registers it creates; the writer writes the letter of any class); `R(r,2)` T10's read count (entry 69440 resets it to 0 for registers 1..`M7` and recounts it, under the numbers before its renumbering, so after the entry it holds no meaning for the pass, which never keeps anything there; with `V8` = 3 the reader keeps an `m` register's lane count, 2 or 4, there until that entry); the reader zeroes columns 2..7 of a new register; every other column the pass's (entry 69440 and 69465 renumber the registers and move only column 1, so a pass column is stale after either) |
| `K` | block b (1..`B2`): `K(b,1)` kind (1 `loop`, 2 `do`, 3 `if`, 4 `ifz`), `K(b,2)` opening, `K(b,3)` `else` (0 none), `K(b,4)` closing instruction; `K(10000+s,1..2)` slot s (1..`S6`): size, alignment |
| `C G` | `C(r,1..4)` the limbs of an `i`/`f` immediate (1..`A2`); `G(r,0..3)` those of an `off` field (1..`A6`) |
| `S$ P` | the distinct strings of the compilation (1..`A3`), interned through the hash table `P` |
| `X H V$ U$` | per compilation: the site hash set (`A4` sites), the func of each name and its signature, the forward calls checked at `#end` |
| `T U L G$ H$ A$` | open blocks, the `u` fields of a record, four limbs, the fields of a line, the `#file` paths, the capacity word |
| `W` | scratch: entries 69440 and 69465 overwrite it; the pass may use it between entries |

Free for the pass: the numeric arrays `S` and `V` (2), the columns of `R` other than 1 and 2, `W`
between entries, string arrays outside the 14.

### The contract: scalars

The part reserves 173 scalar names, 149 numeric and 24 string (`V8` added by L-bu); any entry may change any of them,
so the pass keeps nothing of its own in them across an entry (it may use them as scratch between
entries, and reads or updates the state ones below as documented), except the reader's own state
below (`L$ L0`, the data-record state `M8 D8 X9 Z8`, and `A3 A4 F6 M6 Q6 R8`), which the pass
never writes, not even as scratch between entries (L-bv):

    A0 A1 A2 A3 A4 A5 A6 A8 A9 B0 B1 B2 B3 B4 B5 B7 B9 C0 C1 C3 C4 C5 C6 C7 C8 C9 D7 D8 E0 E2 E3
    E4 E5 E6 E7 E8 E9 F1 F6 F7 F8 F9 G2 G3 G4 G5 G6 G7 G8 H1 H2 H5 H8 H9 I0 I1 I2 I3 I9 J0 J1 J2
    J8 J9 K0 K1 K4 K5 K6 K7 K8 K9 L0 L1 M6 M7 M8 M9 N0 N1 N2 N3 N5 N6 N7 N8 N9 O1 O2 O9 P0 P1 P2
    P3 P4 Q0 Q1 Q2 Q3 Q4 Q5 Q6 Q9 R0 R2 R8 R9 S6 S8 S9 T T0 T1 T2 U9 V V0 V1 V9 W0 W1 W2 W3 W4 W5
    W6 W7 W8 W9 X0 X1 X2 X3 X4 X6 X9 Y0 Y2 Y3 Y4 Y5 Y6 Y7 Y8 Y9 Z6 Z7 Z8 V8
    B$ C0$ C1$ C2$ C3$ C4$ C5$ D$ E1$ G1$ K1$ K2$ K3$ L$ M$ P$ R1$ R2$ R3$ S1$ T$ Y1$ Y2$ Z$

(`H5` is reserved as DESIGN §2.7 measured it, though the part's lines do not use it now:
`seaopt` keeps its constant compaction, which writes `H5`.)

State carried between the pass and the part:

* set by the pass before entry 69400: `P$` (its name, in every message) and `V8`, the kind of its
  input (L-bu): 1 for `sea.lir1` (`seaopt`), which keeps the two `sea.lir1`-only label rules of
  DESIGN §3.6.2 (data labels numbered by first reference; no defined label unused), 2 for
  `sea.lir2` or `sea.lir3` (`sealopt`, `seavec`), which drops them (T10 may have deleted an `la`, and pass 3b
  keeps labels no instruction refers to any more), 3 for `sea.lir` (no pass reads it through `lirrw`
  so far; `tests/lib_check.sh` does), which drops them too and alone accepts the vector classes `x y m`
  and the set-LF records (DESIGN §2.12.6, Decision 113: below); a label used but not defined is an error for
  all three. A data label number above `Q9` (`SEA_LIM_LIR_LABELS`), defined or referenced, is the
  compile error `TOO_LARGE` (`labels`) only when `V8` = 1; when `V8` = 2 or 3 it is `BAD_RECORD` (no
  `sea.lir2` or `sea.lir` can hold one, since pass 3b keeps every label; DESIGN §3.6.2, L-bv). Any
  other value at entry 69400 is a `dg_bug`;
* set by entry 69400, read-only for the pass: the limits `I9 O9 R9 B9 S9 M9 Q9 S8`
  (`SEA_LIM_LIR_INSTRS OPERANDS REGS BLOCKS SLOTS IMMS LABELS SITES`) and `V9`
  (`SEA_FILE_VERSION`); `T$` the target; `N1` the number of `#file` records; `E0 N5 N6 N7 A8`
  the table counts; the opcode rows `E2` li, `E3` lf, `E4` mov, `E5` iadd, `E6` isub, `E7` imul,
  `E8` ineg, `E9` iand, `G2` isar, `G3` imulh, `G4` icmp, `G5` isel, `G6` fsel, `G7` psel, `G8`
  fmul; the `cc` words `C4 C5 C6 C7 C8 C9` (eq ne lt le gt ge); `K6 K7 K8 K9` the header offsets
  `SEA_ARR_ROWS COLS DATA RC`, `K0` `SEA_LIM_EXTENT`; `Y3 … Y9` the rows of `S$` holding the
  symbols of the entries `ARR_NEW ARR_NEW_U ARR_NEW_S SORT ARGSORT ARGS ARR_UNIQUE`; `N8` = 1E30
  (an unknown bound), `U9` = 2^52;
* `Y2`: 0 after entry 69400; the pass may count its functions in it (`seaopt` does);
* the current function after entry 69410 returns with `Y0` = 39: `A0` instructions, `A1`
  operands, `A2` immediates, `A5` func-record fields, `A6` `off` rows, `M7` registers, `B2`
  blocks, `S6` slots, `F7 F8 F9` the func record's position; a transformation keeps `A0 A1 A2
  M7` up to date (entries 69440, 69450 and 69465 update them themselves);
* the reader's own state (file position `L$ L0`; the data-record state `M8` (where the input
  stands: 0 between functions, 1 after a `func`, 2 in its instructions, 3 in the data records), `D8` (the last data label defined), `X9` (the sub-records still due)
  and `Z8` (their kind); the per-compilation counts `A3 A4 F6 M6 Q6 R8`): the pass never writes any
  of them, at any time, although they are among the reserved scalars (L-bv);

### Entries

Each is a `GOSUB` target ending in `RETURN`. A malformed input ends the pass inside the part:
the internal error `BAD_RECORD` (`dg_internal`, status 11), a capacity limit the compile error
`TOO_LARGE` at the func record (`dg_compile`, status 10), an inconsistency between the contract
files and the part `dg_bug` (status 11); a truncated input `TRUNCATED` (`io_read`).

* `69400` **header**, once, first (after `P$` and `V8` are set): loads the contract tables (`tb_errors tb_exits tb_consts
  tb_entries tb_records`), the limits (a limit above the bounds above is a `dg_bug`), the rows
  of set L and their codes, the opcode codes, categories and field roles and the scalars listed
  above; reads the header records of file 1 (`io_hdr`), writes them to file 2 (`SCRATCH #2`,
  `io_hdr_put`); `L$` = the first record after them, `Y0` = 0.
* `69410` **read**: validates records until a function is complete: returns with `Y0` = 39 and
  the function in the tables (its `endfunc` validated, not yet written); or until `#end`: returns
  with `Y0` = -1. Data records (`str fmt dat slay` and their sub-records) are validated and copied
  to file 2 as read. Called again only after `Y0` = 39 (and the write).
* `69420` **end of input**, after `Y0` = -1: the checks of `#end` (nothing open, every data label
  used and defined, one `main`, every forward call matched), nothing after it (`io_end`), `#end`
  written (`io_fin`). The pass then stops (`STOP`).
* `69430` **write** the function held in the tables: the func record, its slots, instructions
  1..`A0` in record order, `endfunc`, every field rebuilt from the tables (call 69440 first).
* `69440` **T10** (DESIGN §5.8): clean-up repeated until nothing changes (a pure instruction or
  load whose destination nothing but itself reads is deleted, L-bn), then the registers
  renumbered by first appearance (parameters first) and the blocks in order of their opening
  records (`K` rebuilt). It overwrites `I(n,0)` for every record (entry 69460's dead-record marking, line 79510, which T10 runs first), resets and recounts `R(r,2)`, and overwrites `W` (L-bv).
* `69450` **compaction**: the deleted instructions (`I(n,1)` = 0) dropped, the operands kept in
  record order (`A0 A1` updated), then 69455. `69455` **blocks**: `K(b,1..4)` of every block
  from the records. `69460` **dead records**: `I(n,0)` = -1 for every record after an `exit`,
  `next` or `ret` up to the end of its part (L-bb reading 3), else 0. `69465` **registers
  renumbered** by first appearance, parameters first (`M7` updated, `W` overwritten).

The part's operand visitor (lines 77160-77290) has only T10's modes and the renumbering's
(9 count a read, 10 uncount it, 11 renumber, 12 count an instruction's reads of its own
destination, which T10 does not count, L-bn); a pass's visitor, with its own modes, stays in the
pass (`seaopt`: line 7175).

### Vector classes and set LF (sub-phase 7e; DESIGN §2.12.6, §3.6.1, §3.6.4, §3.6.5; Decision 113)

**Where they are accepted.** The register classes `x` (`v2f64`), `y` (`v4f64`) and `m` (a lane
mask) and the records of set LF (`pdiff`, `ldx ldy ldm2 ldm4`, `stx sty stm2 stm4`, the 17 `x…`
and 17 `y…` instructions, `mand mor mnot`, `vfeat`: 47 records) are accepted by the reader only
with `V8` = 3 (`sea.lir`). With `V8` = 1 or 2 — the inputs `sea.lir1`, `sea.lir2`, `sea.lir3` of
`seaopt`, `sealopt` and `seavec` — an LF opcode is `BAD_RECORD` (the opcode is not among the rows
`A(1..A8)` of set L; the message is unchanged, "unknown opcode ... for format lir1") and so is a
register written with the letter `x`, `y` or `m` in any field (line 72882), also in an L record
such as `mov x4 x4` or `rcall sea_log_x - 1 x4 1 x4`. These rejections leave every `seaopt`,
`sealopt` and `seavec` output on a valid input byte for byte as before.

**The text forms accepted** (`V8` = 3), each record exactly as `passes.txt` gives its fields (§3.6.4's
table; `idx` may be `-`):

    pdiff i p p                     ldx x p i? u i     ldy y p i? u i     ldm2 m p i? u i    ldm4 m p i? u i
    stx x p i? u i    sty y p i? u i     stm2 m p i? u i    stm4 m p i? u i
    xadd|xsub|xmul|xdiv|xmin|xmax x x x       xneg|xabs|xsqrt|xfloor|xceil|xtrunc|xround x x
    xcmp cc m x x     xsel x m x x      xsplat x f        xlane f x u
    yadd|ysub|ymul|ydiv|ymin|ymax y y y       yneg|yabs|ysqrt|yfloor|yceil|ytrunc|yround y y
    ycmp cc m y y     ysel y m y y      ysplat y f        ylane f y u
    mand|mor m m m    mnot m m          vfeat i avx2

(a letter stands for a register of that class, `cc` a word of enumeration `cc`, `u` and `i` the
`u` and `i` fields; for example `xcmp lt m20 x19 x3`, `ldm4 m6 p1 - 1 8`, `xlane f24 x23 1`). Besides,
`mov` of two registers of one vector class, and `rcall` of the entries 39–50 of `rt.inc`
(`sea_log_x … sea_hypot_y`, whose argument and result classes are `x` or `y`), are valid.

**What is validated** (`V8` = 3), beyond the field types (a typed field `rx ry rm` takes only its
class, so `xadd x7 x3 y4` is `BAD_RECORD`) and the numbering by first appearance, which counts
vector registers like the others:

* a mask has the lane count of the instruction that writes it and is read only with that lane count
  (§3.6.1): 2 for `ldm2 stm2 xcmp xsel`, 4 for `ldm4 stm4 ycmp ysel`; `mand mor mnot` and a `mov` of
  masks take the lane count of their (first) source, and every other mask operand must have it. A
  mask's first write fixes its count, a later write must agree, and a read of a mask that no
  earlier record (in record order) wrote is `BAD_RECORD` (DESIGN §3.6.4 property 2 makes the first
  reference of a register a write). The count is kept in `R(r,2)` from the reader until T10;
* `vfeat` only when the `#target` is `x86_64-linux` (§3.6.4);
* no vector or mask register is a `func` parameter, a `call` argument or result, a `chk` argument
  or a `ret` value (Sea functions pass and return `i f p` only, §3.6.3: `cls` is of enumeration
  `rcls`).

The 4-lane forms (`y`, `ldm4`, `stm4`) are accepted on `arm64-macos` too: §2.12.7 makes them
`BAD_RECORD` in `seagen_a64`, not in `sea.lir` as such (implementer reading of 7e WP-LIB).

**Writing and T10** need no `V8`: the writer (69430) writes every class letter and every LF row a
pass puts into the tables (so `seavec`, reading `sea.lir3` with `V8` = 2, writes its vector code
through it). Each LF row has, from entry 69400, its internal code in `Q(row,6)`, its category in
`Q(row,7)` and memory kind in `Q(row,8)`, and the roles of its fields in `F(field,0)` (`d` written,
every other register field read, `k` of `xlane`/`ylane` a `u` field, `cc` and `f` one-operand
fields), exactly as the L rows have them, so T10 (69440) deletes a vector load or pure vector
instruction whose destination nothing reads and keeps vector stores, and the renumbering (69440,
69465) keeps each register's class. Internal codes (`Q(row,6)`; a pass finds an LF row by its code
or by `Q$(row)`; an LF record of `passes.txt` missing from the table is a `dg_bug` at entry 69400):

| code | records | category (`Q(row,7)`), kind (`Q(row,8)`) |
|---|---|---|
| 73 | `pdiff` | 1 pure |
| 74 75 76 77 | `ldx ldy ldm2 ldm4` | 3 load; kinds 3 3 2 2 |
| 78 79 80 81 | `stx sty stm2 stm4` | 4 store; kinds 3 3 2 2 |
| 82 … 98 | `xadd xsub xmul xdiv xmin xmax xneg xabs xsqrt xfloor xceil xtrunc xround xcmp xsel xsplat xlane` | 1 pure |
| 99 … 115 | `yadd … ylane`, in the same order (the `x` code + 17) | 1 pure |
| 116 117 118 | `mand mor mnot` | 1 pure |
| 119 | `vfeat` | 1 pure |

A pass's own visitor (with its modes) walks LF rows as it walks L rows: every LF field is one
operand (no `site` or `pos` field).

## layout.bas (lines 86000-88999)

Needs `diag.bas` (`dg_bug`) and `tables.bas` (`tb_cval`). From sub-step 4g-2, in the build lists
of `sealoop` and `sealower` (DESIGN §2.6.3, lead decision L-k). The struct layout rule of DESIGN
§4.8 computed once for both programs: sizes and alignments, field offsets, and the ascending byte
offsets of the reference values (`str`, dynamic arrays, handles) a type holds, those inside nested
structs, records and fixed-size arrays included (rule 15 (g)'s and rule 38's list). A record type
(`trec`) is an anonymous struct type (Decision 48) and is laid out the same way (`slay` too,
lead decision L-m). An empty struct has size 0 and alignment 1 (lead decision L-h; its home is
still an 8-byte slot, its arrays have element size 0: both the caller's).

The module keeps its results in one numeric table the caller DIMs and passes, written `Q()` here
(the caller picks the letter; it is the only array the module needs). The caller registers each
type record as it reads the type table (§3.5.1: ids in order, a type's components always have
smaller ids, so every component is registered first), then reads the results.

`Q(M,6)` -- `T9` = the highest type id (9 + `SEA_LIM_TYPES`), `M` > `T9`:

| rows | columns |
|---|---|
| 0 (header) | `Q(0,2)` = the last field row used (`T9` when none); `Q(0,3)` = `M`; `Q(0,4)` = the id of the struct or record whose `fd` records are still expected, 0 when none (a caller reading another record while it is not 0 has a missing `fd`); `Q(0,5)` = `SEA_ESIZE_PTR` |
| type id t, 1..`T9` | `Q(t,0)` kind: 0 no layout (`void`, `ttuple`, `tptr`, not registered), 1 scalar value (`bool` `i64` `f64`), 2 reference (`str`, the handles, `tvec`, `tmat`), 3 fixed-size array, 4 struct or record; `Q(t,1)` size in bytes; `Q(t,2)` alignment; `Q(t,3)` the number of reference values (0: holds no counts); `Q(t,4)` kind 3: the element type, kind 4: the row of field 0; `Q(t,5)` kind 3: the element count (n, or r·c), kind 4: the number of fields; `Q(t,6)` the caller's (never used by the module: e.g. `sealower`'s `slay` label) |
| field rows `T9`+1..`M` | `Q(r,0)` the field's type; `Q(r,1)` its byte offset in its struct; `Q(r,2)` the number of reference values in the fields before it |

Type ids passed to the SUBs (I, E, F, S) are ids the caller has already checked to lie in
1..`T9` (the module does not range-check them); each id is registered once. `Q(t,0..5)` may be
read directly; the field rows through `ly_fld`. Every SUB below is cheap
(no list is stored: the reference offsets are computed on demand) and no SUB recurses.

* `ly_init Q(), C(), C$(), C0, T9, M, P$` -- call once, on a freshly DIMmed (all 0) `Q`; sets the
  predefined types: 2 `bool`, 3 `i64`, 4 `f64` (kind 1) and 5 `str`, 6-9 the handles (kind 2,
  one reference at offset 0), each with alignment = size = `SEA_ESIZE_BOOL`, `SEA_ESIZE_I64`,
  `SEA_ESIZE_F64`, `SEA_ESIZE_PTR` from the consts table `C() C$() C0` (`tb_consts`; never written
  numbers). Type 1 `void` has kind 0. `M` <= `T9` or a missing constant: `dg_bug`
  (`<P$>: ly_init: ...`, STOP 11).
* `ly_dyn Q(), I` -- type I is a dynamic array (`tvec`, `tmat`): kind 2, size and alignment
  `SEA_ESIZE_PTR`, one reference at offset 0.
* `ly_fix Q(), I, E, N, T` -- type I is N elements of type E inline, column-major (`tfvec` with
  N = n, `tfmat` with N = r·c): kind 3, size N·size(E), E's alignment, N·refs(E) references.
  `T` = 1 (nothing set) if E has no layout or a struct is still open (its `fd` records missing).
* `ly_st Q(), I, N, T` -- opens the struct or record type I with N fields (`tstruct`, `trec`);
  N = 0 completes it at once (size 0, alignment 1). `T` = 1 (nothing set) if another struct is
  still open or the N fields do not fit the field rows (`Q(0,2)` + N > `M`; the caller's
  capacity error).
* `ly_fd Q(), F, T` -- the next field, of type F, of the open struct (one call per `fd` record,
  in order): placed at the next multiple of its alignment; the struct's alignment is the largest
  of its fields'; after the N-th field the size is rounded up to the alignment and the struct is
  closed (`Q(0,4)` = 0). `T` = 1 (nothing set) if no struct is open, F has no
  layout, or is the open struct itself.
* `ly_fld Q(), S, I, F, O` -- `F` = the type and `O` = the byte offset of field I (from 0, the
  `i` of a `fld` record) of the struct or record S. A nested field's offset is the sum along
  the path (the caller adds them up while it walks a `fld` chain).
* `ly_ref Q(), S, K, O` -- `O` = the byte offset in S of the K-th of its `Q(S,3)` reference
  values, in ascending order (K from 1): `ly_ref` for K = 1 .. `Q(S,3)` lists the `soff` records
  of rule 38 and the releases and retains of rules 15 (g), 16, 27, 28 and R19-R20. For a
  reference type S it is 0 (K = 1). `O` = -1 if K is outside 1..`Q(S,3)` (also for a type
  holding no reference).
* `ly_at Q(), S, O, F, Y` -- `Y` = 1 if the struct or record S has a field of type F at byte
  offset O, or a field of a struct or record field at that total offset, at any depth (R24's
  test: sc the size of S, off the offset of a field whose type is the value's); else 0 (also
  when S is not a struct or record). Fields inside fixed-size array fields are not field paths.

## ralloc.bas (lines 87000-88999)

Needs `diag.bas` (`dg_bug`, for `ra_else`'s precondition only, L-bv; both code generators load
it already; since no `ralloc` SUB receives the pass name, it passes `"ralloc"` as `P$`). From sub-phase 5b, in the build lists of `seagen_a64` and `seagen_x64`
(DESIGN §4.9.2, Decisions 59, 60, lead decisions L-ac, L-an, L-aq; from 5c-2 Decision 75, L-bf,
L-bg, L-bh). The linear-scan register allocator of DESIGN §4.9.2, the same on both targets:
positions and intervals, the loop extension by liveness, the hidden registers of `loop`s, call crossing, the scan with its hints and spill
choice, the spill and save slots, the saves around calls, and the three-step parallel move. The
templates, immediates, fusion and the machine code stay in the code generator; the target enters
only through the register table the caller declares (`ra_tab`).

**One table, no array of its own (L-ac).** The module keeps all its state in the code
generator's register table `D`, widened from `D(99999)` to **`DIM D(111110,8)`** (999 999
elements, under Baysick's 10^6); it has no SUB-local array, so it adds nothing to the activation
words (a SUB's own arrays are allocated and zeroed at every activation and count one word per
numeric element against Baysick's 2 097 152 words of activations, Baysick LANGUAGE §7.27) and
no array letter. With `R9` = `SEA_LIM_LIR_REGS` and `B9` = `SEA_LIM_LIR_BLOCKS` (from the
consts table, never written numbers) and `X` = `R9` + `B9`:

| rows | use |
|---|---|
| 0 | the module's scalars |
| 1 .. `R9` | register r (LIR registers 1 .. M, then the hidden registers M+1, ...): `D(r,0)` the class, **the caller's** (1 `i`, 2 `f`, 3 `p`, as the decoder sets it today; from 7e 4 `x`, 5 `y`, 6 an `m` of 2 lanes, 7 an `m` of 4 lanes (the lane count of the instruction that writes it, DESIGN §3.6.1), set before `ra_end`; the module writes it only for the hidden registers); `D(r,1..7)` the module's (after `ra_end`, `D(s,4)` of row s holds the offset of slot s, read through `ra_so`); `D(r,8)` the location after `ra_end` (below) |
| `R9`+1 .. `X` | block b at row `R9`+b: the module's |
| `X`+1 .. `X`+546 | the module's: scalars, the register table (64 rows), the save list, the moves |

The caller may read `D(r,0)` and, after `ra_end`, `D(r,8)`; every other cell is the module's.
**Location** of register r (`D(r,8)`, fixed for the whole function: no interval is split):
P >= 1 the machine register P of the caller's numbering (`ra_tab`); -s the spill slot s (s >= 1;
8 bytes for `i f p`, 16 for `x` and a 2-lane `m`, 32 for `y` and a 4-lane `m`, DESIGN §2.12.7, L-fh;
the caller places slot s at its spill area + the offset `ra_so` gives, which is 8(s-1) in a function
with no vector slot, DESIGN §4.9.2 "Frame"); 0 the
register has no reference the caller reported (no interval: e.g. an `li` all of whose uses are
immediates, or the result of a fused comparison).

**Machine registers** are numbered by the caller, 1 .. 64, one number per register of either
class (arm64 x0-x30 and d0-d31; x86_64 the 16 general and 16 `xmm`); the same numbers name
registers in the moves below, so the scratch registers, the §4.8 argument and result registers
and the frame registers get numbers too, but only the registers declared with `ra_tab` are
allocated. The caller keeps the names (its templates); the module never sees them.

### Set-up (once per pass)

* `ra_init D(), R9, B9, Z9, T` -- on a freshly DIMmed (all 0) `D`: records `R9`, `B9` and `Z9`
  (the first bound of the caller's `DIM D(Z9,8)`, 111110). `T` = 1 if `X` + 546 > `Z9` (the table
  is too small), else 0.
* `ra_tab D(), P, C, N, K, S` -- declares machine register P (1 .. 64) allocatable: class C (1
  general, for `i` and `p`; 2 floating point, for `f` and, from 7e, `x y m`, which share the
  floating-point register file: arm64 `v0`-`v31`, whose low halves are `d0`-`d31`; x86_64 `xmm`/`ymm`), N its rank (1 = first) in its class's row
  "crossing no call" of the DESIGN §4.9.2 register table, K its rank in the row "crossing a
  call", S = 1 if it is callee-saved (the prologue saves it when it is used), else 0. One call per
  allocatable register of the target (arm64 25 general and 29 floating-point registers, x86_64 10
  and 14), after `ra_init` and before the first `ra_fn`; never changed afterwards. Ranks are
  1 .. the class's count, each once per row.

### Per function: the reference walk (during the analysis sweep)

* `ra_fn D()` -- starts a function: clears every row the previous function used, **column 0
  included** (the caller's own clearing loop of `D` becomes unnecessary; the module also clears
  the hidden rows, whose class it wrote), the blocks and the per-function scalars. Call it before
  the first register of the function is decoded.
* `ra_par D(), R` -- parameter register R, written at position 0 (DESIGN §4.9.2). One call per
  parameter, before any record's references.
* Then, for each record k = 1, 2, ... of the function (the caller's record index: `func` is record
  1, then the `slot` records, the instructions, `endfunc`; block and closing records included), in
  increasing k, exactly in this order:
  1. `ra_ref D(), K, R, 0` for each register the record reads (position 2K), any order;
  2. `ra_call D(), K` if the record is a `call`, an `rcall` or a `release`;
  3. `ra_ref D(), K, R, 1` for each register the record writes (position 2K+1);
  4. `ra_hint D(), K, R, A, B` if the record is a `mov`, or (x86_64) a two-address instruction;
     then (x86_64) `ra_avoid D(), K, R, V` if it is a two-address instruction of a non-commuting
     operation whose second operand is a register other than its first;
  5. `ra_open D(), K, B, Y, I, S` if it opens a block; `ra_else D(), K, B` if it is the `else`
     of block B; `ra_close D(), K, B` if it closes one (`endloop`, `enddo`, `endif`; nothing for
     `exit`, `next`).

  The registers written are the fields named `d` (every `d` of `call`/`rcall`), `e` (`rcount`) and
  `ind` (`loop`); every other register field is read. Report each reference that will exist in a
  register or a spill slot in the code: a use the caller writes as an immediate (DESIGN §4.9.2
  "Immediates") is not reported, nor an `li` that is not emitted (then none of its register's
  references is reported), nor the register of a comparison fused into its `if`/selection.
  Duplicates are harmless.
* `ra_ref D(), K, R, W` -- register R is read (W = 0, position 2K) or written (W = 1, 2K+1) by
  record K. The module records the first and last reference, the loop extension of DESIGN §4.9.2
  (a loop's opening record and its own reads and `ind` write are outside the loop, see
  "Readings"), the loop depth of the deepest reference, and whether the interval crosses a call.
* `ra_call D(), K` -- record K is a `call`, `rcall` or `release`: an interval crosses it when it
  starts at or before 2K and ends after 2K+1.
* `ra_hint D(), K, R, A, B` -- R, written by record K, prefers A's register, else B's (0: none):
  `mov R A` gives `ra_hint K, R, A, 0`; an x86_64 two-address `d = a op b` gives `K, d, a, b` for
  a commuting operation (`iadd imul iand ior ixor fadd fmul`) and `K, d, a, 0` otherwise. Kept only
  when record K is R's first reference; applied by the scan when that register is free at R's
  start (which is exactly when the operand's interval ends at record K). Independent of
  `ra_avoid`: neither call changes what the other recorded.
* `ra_avoid D(), K, R, V` -- R, written by record K, *avoids* V's register (DESIGN §4.9.2 "The
  scan", Decision 77): when R's hint is not free, the scan gives R the first free register of its
  row other than the one V holds, and V's register only when no other register of R's class is
  free (V's interval has then ended at record K, or the register would not be free). x86_64 calls
  it with `K, d, b` for a two-address `d = a op b` of an operation that is not commuting (`isub
  isubc iaddc imulc padd fsub fdiv`) when b is a register (no immediate) other than a; arm64 never
  calls it. V = 0 records nothing. Kept only when record K is R's first reference, like a hint; a
  spilled V (no register) avoids nothing.
* `ra_open D(), K, B, Y, I, S` -- record K opens block B (blocks numbered 1, 2, ... by opening
  record, as validated by the caller) of kind Y: 1 `loop`, 2 `do`, 3 `if` or `ifz`. For a `loop`:
  I its `ind` register and S its step register, or S = 0 when the caller writes the step as an
  immediate (DESIGN §4.9.2 "Loop closing": a step whose only definition is an `li`, or a `mov` from
  a register whose only definition is an `li`, Decision 76, that the closing `add` encodes); I = S = 0 otherwise. Called after the record's own
  references (the `loop` record reads start, last and step and writes `ind` before the loop
  starts; `if` reads its condition outside its block). For an `if`/`ifz` it opens the block's
  first part; for a `loop`/`do`, its body.
* `ra_else D(), K, B` -- record K is the `else` of the `if`/`ifz` block B, the innermost open
  one (5c-2, Decision 75): closes B's first part and opens its `else` part. Precondition (L-bv):
  B is the innermost open block, of kind 3 (`if`/`ifz`, as given to `ra_open`), with its first
  part current, which is exactly `D(0,7)` = B (after `ra_else` it is -B); any other call (B not
  the innermost open block, B a `loop` or `do`, or a second `ra_else` for B) is a caller bug that
  `ra_else` reports through `dg_bug` (internal error, status 11) before changing anything, never
  leaving the part state silently corrupted. The record has no references; `ra_close` of the `endif` then closes the `else` part. Without it the module would
  treat the whole block as its first part, which is not the rule: every `else` must be reported.
* `ra_close D(), K, B` -- record K closes block B, the innermost open one. For a `loop` the
  module adds the references of its closing sequence itself: `ind` read at 2K and written at
  2K+1, and the step register read at 2K unless the step is an immediate or has a hidden
  register. The caller reports nothing for a closing record.

### Per function: allocation

* `ra_end D(), M, S8, T` -- after the last record: M = the number of LIR registers of the function
  (the decoder's highest register number). Numbers the hidden registers (below), completes the
  intervals, sorts them by start (ties: register number), runs the scan of DESIGN §4.9.2 and
  gives the slots. Out: `D(r,8)` for r = 1 .. M (and the hidden registers), `S8` = the number of
  spill slots of the function (the frame's spill area is `ra_sa`'s A bytes: 8·`S8` in a function
  with no vector slot), `T` = 1 if a block is still open (a caller bug), else 0.
* `ra_blk D(), B, C, S, F` -- for `loop` block B after `ra_end`: C = the location of its hidden
  count register (P, or -s: either the hidden register was spilled, or it would have been
  numbered above `SEA_LIM_LIR_REGS` and lives in a spill slot of its own, L-aq; the caller reads
  and writes it through the scratch registers exactly as a spilled register); S = the location of
  its hidden step register, or 0 when it has none (the step register, or the immediate, serves);
  F = 1 if `ind` is referenced after the `endloop` (then the closing sequence is the `cbz`/`je`
  form of DESIGN §4.9.2 "Loop closing"), else 0.
* `ra_used D(), P, U` -- U = 1 if machine register P was given to an interval of this function
  (for a callee-saved P: the prologue saves it, in the caller's table order), else 0.
* `ra_so D(), S, O` -- after `ra_end`: O = the byte offset of spill slot S (1 .. `S8`) from the start
  of the function's spill area (7e, L-fh). The slots before L-aq's are laid out in slot order, an
  8-byte slot right after the previous one, a 16- or 32-byte slot (an `x`, `y` or `m` value, spilled
  or saved) at the next multiple of 16; L-aq's slots (8 bytes) follow them. With no vector slot O =
  8(S-1), as before 7e.
* `ra_sa D(), A, V` -- after `ra_end`: A = the size in bytes of the spill area (the end of its last
  slot; 8·`S8` with no vector slot), V = 1 if it holds a 16- or 32-byte slot, else 0. When V = 1
  the caller places the area at a frame offset that is a multiple of 16, so that each vector slot is
  16-byte aligned (L-fh: it is accessed with unaligned vector moves, `str q`/`ldr q`, `movupd`,
  `vmovupd`, and no frame is realigned; the frame's body stays a multiple of 16, DESIGN §4.9.2).

Interval rules (DESIGN §4.9.2, as the module applies them): an interval runs from the first to the
last reported reference; for each loop (`loop`, `do`) a register referenced inside it is extended
to cover the loop, from the opening record's write position 2o+1 to the closing record's 2c+1,
when it may be live at the loop's top (Decision 75): some read of it inside the loop is
*uncovered in the loop*, or some read after the loop's closing record is *uncovered after the
loop*. Parts are the function body, each loop's body and each `if`'s first and `else` parts
(announced by `ra_open`, `ra_else`, `ra_close`); a write's *effective part* is the part it stands
in, except that a write in B's `else` part (directly) whose register's previous write has B's
first part as its effective part has the part containing B (L-bh). A read at record k is covered
in loop L when the latest write before it lies after L's opening record and its effective part
is still open at k; covered after L when that write lies after L's closing record and its
effective part is still open. The module keeps per register the record and effective part of
its latest write, the block of its first reference and the outermost open loop over which it
must be extended (its end applied by `ra_end`, its start at once); a read uncovered after closed
loops extends the interval back to 2o+1 of the outermost closed loop that contains the first
reference (a write inside a nested loop thus never covers a read after it, L-bf). Each `loop` has a hidden count register (interval
2o+1 .. 2c+1, class `i`), and a hidden step register (same interval) when its step register S is
written inside the loop; hidden registers are numbered M+1, M+2, ... in the order of their
loops' opening records, the count before the step; one numbered above `R9` is not created (L-aq).
Their deepest reference has the loop's depth. The scan: intervals by start; before placing one,
every active interval ending below its start is expired; the register is the hint's if free,
else the first free register of the interval's row (its class; "crossing a call" if it crosses
any call); with none free, the spill victim among the class's active intervals and the new one is
the one whose deepest reference has the smallest loop depth, then the one ending last, then the
highest register number; a victim that held a register gives it to the new interval.

**Slots.** Spill slots are numbered 1 .. `S8` in order of first use (ties: register number): a
spilled interval at its first reference, an interval in a caller-saved register (or, from 7e, a
vector interval in any register) that crosses a call (its **save slot**) at the first call it crosses; then the L-aq counts and steps, by block.
A spilled interval's slot is `-D(r,8)`; save slots are returned by `ra_sv`.

**The vector classes** (7e; DESIGN §2.12.7, L-ez, L-fh). An interval of class 4 `x`, 5 `y`, 6 or 7
`m` is allocated as an `f` interval is, from the machine registers of class 2 (`f` and vector values
compete for them, and the spill choice above compares them alike), with two differences: (1) it
takes its register from the row "crossing no call" even when it crosses a call, since no register
keeps a vector value across a call (on arm64 only the low 64 bits of `v8`–`v15` survive one, so
preferring them would only add prologue saves); (2) when it crosses a call and holds a register,
it is saved around every call it crosses — it gets a save slot and `ra_sv` lists it — whether or
not that register is callee-saved (every vector register is caller-saved across a `call`, an
`rcall` and the free path of a `release`; L-ez's "spilled" is read as this save, as §4.9.2 "Calls"
saves a caller-saved register). A callee-saved register given to a vector interval (arm64
`d8`–`d15`, only when the other rows' registers are taken) is reported by `ra_used` like any other,
so the prologue still saves its low 64 bits for the function's caller. Its spill or save slot has
16 (`x`, a 2-lane `m`) or 32 bytes (`y`, a 4-lane `m`) at a 16-byte-aligned offset (`ra_so`, `ra_sa`).

### Per function: the code sweeps

* `ra_rew D()` -- at the start of every sweep that calls `ra_sv` (each of the caller's sweeps over
  the records: the line count and the code).
* `ra_sv D(), K, N, T` -- at the `call`/`rcall` K, or at the free path of the `release` K, records
  K in increasing order within a sweep: N = the number of intervals in a caller-saved register
  (or, from 7e, of a vector class in any register: L-ez) that cross K (start <= 2K, end > 2K+1), listed by `ra_svi` in increasing machine-register
  number. **The caller skips the registers record K writes** (its results: their values before
  the call are dead, and a reload would overwrite the result; with the loop extension a result's
  interval can start before 2K): it stores the others to their save slots before the argument
  move and loads them after the result move (DESIGN §4.9.2 "Calls"). Such a result (for instance
  `call fswap 2 f8 f9 2 f8 f9`, whose arguments are its results) may be listed with save slot 0:
  no value of it is live across the call. `T` = 1 if a listed interval has no save slot and is not
  written by record K (K was not reported by `ra_call`: a caller bug); an interval written by two
  or more calls is accepted at each of them without this check. Else `T` = 0.
* `ra_svi D(), I, P, S, R` -- the I-th entry of the last `ra_sv` list (1 .. N): machine register
  P, save slot S, register R.

### Parallel moves (DESIGN §4.9.2 "Moves", L-an)

Parameters into their locations, the arguments and results of a `call`/`rcall`, the values of a
`ret`, the operands and results of a staged template and the entry of a `loop` (`ind` <- start,
the hidden count <- last, the hidden step <- step) are each one parallel move. The caller lists
its moves in **destination order** (the order of the §4.8 registers, of the operands, or of the
parameters), then sequences them:

* `ra_mv D(), S, E, C, T` -- appends the move S -> E of class C (1 general, 2 floating point;
  it selects the cycle scratch). `T` = 1 if the list already holds 320 moves (nothing appended),
  else 0.
* `ra_pm D(), N` -- sequences the listed moves and empties the list: N steps, read by `ra_st`
  until the next `ra_pm`. Moves with S = E are dropped (a `mov` between equal locations emits
  nothing). The steps, in order: (1) every move to a memory destination, ordered by destination
  (spill slots by number, then the outgoing stack slots upwards, then the results-area slots
  upwards); (2) the register-to-register moves, repeatedly the first in destination order whose
  destination is no remaining move's source; when every remaining one is in a cycle, a step
  copies the first one's source to the cycle scratch (E = 0), and from then on every remaining
  move from that source reads the scratch (S = 0); (3) every move from a memory or immediate
  source to a register, in destination order.
* `ra_st D(), I, S, E, C, J` -- step I (1 .. N): source S, destination E, class C, and J the
  index (1 ..) of the listed move it belongs to (the cycle copy carries the index of the move
  whose source it saves).

Codes of S and E (the module only compares them, except for ordering memory destinations):

| code | location | as |
|---|---|---|
| 1 .. 64 | machine register (the caller's numbering) | source, destination |
| 0 | the cycle scratch of class C (arm64 `x17`/`d31`, x86_64 `%r11`/`%xmm15`) | only in `ra_st` output |
| -s | spill slot s | source, destination |
| 1000 + j | outgoing stack-argument slot j (j >= 0, at 8j from the stack pointer) | destination |
| 2000 + j | results-area slot j (the results of a call; a `ret`'s results beyond the registers) | source, destination |
| 3000 + j | any other source that is not a register (an immediate, an incoming stack parameter, the results-area address), j the caller's tag | source |

Step (1) stores a register source directly and moves a memory or immediate source through the
cycle scratch; step (3) loads straight into the destination; the cycle scratch is never a listed
move's source or destination, so a staged template's scratch registers (arm64 `x15 x16 x17`,
`d29 d30 d31`; x86_64 `%rax %rcx %rdx`, `%xmm14 %xmm15`), which are never sources of the moves
into them, never form a cycle.

### Readings (where DESIGN §4.9.2 leaves a choice)

* Loop positions: a loop covers 2o+1 .. 2c+1 (o its opening record, c its closing record); the
  opening record's reads (2o) and its `ind` write (2o+1) are outside the loop, the closing
  record's references inside it. So `start`, `last` and a step read only by the `loop` record do
  not stay live through the loop, and the entry move's destinations may reuse their registers.
* `ind` and the step register are referenced by the closing sequence (added by `ra_close`), so
  both keep their registers through the loop; `ra_blk`'s F is "referenced after `endloop`" (a
  later write counts; the `cbz` form is then used, which is correct in every case).
* A hint is recorded from the record that first references the destination; a call result whose
  interval starts before its call (loop extension) is not saved around that call (`ra_sv`).
* Spill slots of L-aq counts and steps come after all other slots, by block, count first.
* Effective parts (L-bh): "the previous write stood in B's first part" is read as "its effective
  part is B's first part", so a write that is itself promoted by this rule in a nested `if`'s
  `else` part counts (the same reading as `seaopt`'s T4, L-bq). A register read before any
  write counts as written at record 0 in the function body, as a parameter is.
