# passes/lib -- API of the shared pass modules

Reference for `io.bas`, `diag.bas`, `tables.bas`, `layout.bas` and `ralloc.bas` (DESIGN §2.6.3). The `.bas` files carry
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

## ralloc.bas (lines 87000-88999)

Needs no other module. From sub-phase 5b, in the build lists of `seagen_a64` and `seagen_x64`
(DESIGN §4.9.2, Decisions 59, 60, lead decisions L-ac, L-an, L-aq). The linear-scan register
allocator of DESIGN §4.9.2, the same on both targets: positions and intervals, the loop
extension, the hidden registers of `loop`s, call crossing, the scan with its hints and spill
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
| 1 .. `R9` | register r (LIR registers 1 .. M, then the hidden registers M+1, ...): `D(r,0)` the class, **the caller's** (1 `i`, 2 `f`, 3 `p`, as the decoder sets it today; the module writes it only for the hidden registers); `D(r,1..7)` the module's; `D(r,8)` the location after `ra_end` (below) |
| `R9`+1 .. `X` | block b at row `R9`+b: the module's |
| `X`+1 .. `X`+546 | the module's: scalars, the register table (64 rows), the save list, the moves |

The caller may read `D(r,0)` and, after `ra_end`, `D(r,8)`; every other cell is the module's.
**Location** of register r (`D(r,8)`, fixed for the whole function: no interval is split):
P >= 1 the machine register P of the caller's numbering (`ra_tab`); -s the spill slot s (s >= 1,
8 bytes each; the caller places slot s at its spill area + 8(s-1), DESIGN §4.9.2 "Frame"); 0 the
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
  general, for `i` and `p`; 2 floating point, for `f`), N its rank (1 = first) in its class's row
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
  5. `ra_open D(), K, B, Y, I, S` if it opens a block; `ra_close D(), K, B` if it closes one
     (`endloop`, `enddo`, `endif`; nothing for `else`, `exit`, `next`).

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
  start (which is exactly when the operand's interval ends at record K).
* `ra_open D(), K, B, Y, I, S` -- record K opens block B (blocks numbered 1, 2, ... by opening
  record, as validated by the caller) of kind Y: 1 `loop`, 2 `do`, 3 `if` or `ifz`. For a `loop`:
  I its `ind` register and S its step register, or S = 0 when the caller writes the step as an
  immediate (DESIGN §4.9.2 "Loop closing"); I = S = 0 otherwise. Called after the record's own
  references (the `loop` record reads start, last and step and writes `ind` before the loop
  starts; `if` reads its condition outside its block).
* `ra_close D(), K, B` -- record K closes block B, the innermost open one. For a `loop` the
  module adds the references of its closing sequence itself: `ind` read at 2K and written at
  2K+1, and the step register read at 2K unless the step is an immediate or has a hidden
  register. The caller reports nothing for a closing record.

### Per function: allocation

* `ra_end D(), M, S8, T` -- after the last record: M = the number of LIR registers of the function
  (the decoder's highest register number). Numbers the hidden registers (below), completes the
  intervals, sorts them by start (ties: register number), runs the scan of DESIGN §4.9.2 and
  gives the slots. Out: `D(r,8)` for r = 1 .. M (and the hidden registers), `S8` = the number of
  spill slots of the function (the frame's spill area is 8·`S8` bytes), `T` = 1 if a block is
  still open (a caller bug), else 0.
* `ra_blk D(), B, C, S, F` -- for `loop` block B after `ra_end`: C = the location of its hidden
  count register (P, or -s: either the hidden register was spilled, or it would have been
  numbered above `SEA_LIM_LIR_REGS` and lives in a spill slot of its own, L-aq; the caller reads
  and writes it through the scratch registers exactly as a spilled register); S = the location of
  its hidden step register, or 0 when it has none (the step register, or the immediate, serves);
  F = 1 if `ind` is referenced after the `endloop` (then the closing sequence is the `cbz`/`je`
  form of DESIGN §4.9.2 "Loop closing"), else 0.
* `ra_used D(), P, U` -- U = 1 if machine register P was given to an interval of this function
  (for a callee-saved P: the prologue saves it, in the caller's table order), else 0.

Interval rules (DESIGN §4.9.2, as the module applies them): an interval runs from the first to the
last reported reference; for each loop (`loop`, `do`) a register referenced inside it is extended
to cover the loop, from the opening record's write position 2o+1 to the closing record's 2c+1,
when it is also referenced outside the loop or when its first reference inside the loop is not a
write at the loop body's own block level. Each `loop` has a hidden count register (interval
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
spilled interval at its first reference, an interval in a caller-saved register that crosses a
call (its **save slot**) at the first call it crosses; then the L-aq counts and steps, by block.
A spilled interval's slot is `-D(r,8)`; save slots are returned by `ra_sv`.

### Per function: the code sweeps

* `ra_rew D()` -- at the start of every sweep that calls `ra_sv` (each of the caller's sweeps over
  the records: the line count and the code).
* `ra_sv D(), K, N, T` -- at the `call`/`rcall` K, or at the free path of the `release` K, records
  K in increasing order within a sweep: N = the number of intervals in a caller-saved register
  that cross K (start <= 2K, end > 2K+1), listed by `ra_svi` in increasing machine-register
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
