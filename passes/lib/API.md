# passes/lib -- API of the shared pass modules

Reference for `io.bas`, `diag.bas`, `tables.bas` and `layout.bas` (DESIGN §2.6.3). The `.bas` files carry
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
