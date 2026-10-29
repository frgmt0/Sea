100 REM ====================================================================================
105 REM seavec -- pass 3d: sea.lir3 -> sea.lir (DESIGN 2.1, 2.12.6; Decisions 78, 98, 109).
110 REM Lines 100-59999, SUBs none (the prefix ve_ is reserved for the ones 7e adds). Built as
115 REM DESIGN 2.6.3 says: the files ve0main ... (in name order), io diag tables and the shared
120 REM main-program part lirrw, the DATA blocks errors exits consts entries records, then
125 REM 99999 END (passes/seavec/build.list).
130 REM FLOW (sub-phase 7b): lirrw (passes/lib/lirrw.bas, contract in passes/lib/API.md) reads
135 REM and validates one function of sea.lir3 into the tables, exactly as sealopt reads
140 REM sea.lir2 (V8 = 2: the two lir1-only label rules are off), and writes it, renumbered,
145 REM to sea.lir. 7b is behaviour-neutral (Decision 109): no transformation is applied, so
150 REM sea.lir equals sea.lir3 byte for byte, as the DESIGN says of a function to which none
155 REM of T11-T13 applies (T10 is idempotent on sealopt's output and is not run). 7e adds T11
160 REM unrolling, T12 scalar replacement, T13 if-conversion and vectorization (DESIGN 2.12.6)
165 REM between lirrw's read and write entries. Errors: lirrw's (BAD_RECORD status 11, a
170 REM capacity limit "program too large" status 10).
175 REM TABLES: the DIMs below are lirrw's contract (24 numeric and 14 string array letters,
180 REM its reserved scalars). The numeric array letters S and V are free for 7e's tables.
185 REM ====================================================================================
360 FILES "sea.lir3"; "sea.lir"
365 DIM E(299), E$(299,5), N(39,2), N$(39), W$(299), Q(399,9), Q$(399), F(1499,3), F$(1499), Z(8)
370 DIM J(299,4), J$(299), Y(399), Y$(399,5), D(39), D$(39), B(399), A(399)
375 DIM I(199999,4), O(799999), R(99999,9), K(19999,4), C(199999,4), S$(199999)
380 DIM X(131071), T(10000), G$(300), U(40), L(4), H$(100), A$(2)
382 DIM M(301), P(262143), H(199999), V$(49999), U$(131071), G(199999,3), W(199999,4)
385 LET P$ = "seavec"
386 LET V8 = 2
390 REM ---- the main program: lirrw's entries (passes/lib/API.md), no transformation yet ----------
395 GOSUB 69400
400 GOSUB 69410
405 IF Y0 < 0 THEN 425
415 GOSUB 69430
420 GOTO 400
425 GOSUB 69420
430 STOP
