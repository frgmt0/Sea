100 REM ====================================================================================
105 REM seavec -- pass 3d: sea.lir3 -> sea.lir (DESIGN 2.1, 2.12.6; Decisions 78, 98, 99-102, 108,
110 REM 109, 113, 115-117). Lines 100-59999, SUBs none. Built as DESIGN 2.6.3 says: the files ve0main
115 REM ... ve8vec (in name order), io diag tables and the shared main-program part lirrw, the DATA
120 REM blocks errors exits consts entries records, then 99999 END (passes/seavec/build.list).
125 REM FLOW: lirrw (passes/lib/lirrw.bas, contract in passes/lib/API.md) reads and validates one
130 REM function of sea.lir3 (V8 = 2, so vector records are rejected in the input); this pass applies
135 REM T11 unrolling, T12 scalar replacement, T13 (P1 P2 P3, if-conversion, conditions 1-5, the
140 REM vector form of DESIGN 2.12.6 per #target) and lirrw's T10 (entry 69440, only when one of
145 REM T11-T13 changed the function: T10 is idempotent on sealopt's output), and lirrw writes it.
150 REM Errors: lirrw's (BAD_RECORD status 11, a capacity limit "program too large" status 10); a
155 REM transformation whose result would exceed a LIR limit or a table region below is not applied
160 REM (Decision 72). TABLES: the DIMs are lirrw's contract; this pass's own are S, V, the columns
165 REM 0 and 3-9 of R, W between lirrw's entries and I(n,0) (flags: 1 a T13 candidate's opening
170 REM record, 2 an invariant load (P3), 4 a record of a sum8 group, 8 a unit access).
175 REM   R(r,3) definitions, R(r,4) the last one (0 the func record), R(r,5) the slot of a register
180 REM     every definition of which is an sa of one slot (0 none, -1 several), R(r,6) T13's constant
185 REM     (N8 none), R(r,7) the Terms' constant (only definition one li), R(r,8) reads in the
190 REM     function; R(r,0) the stamp of "written in L", R(r,9) a renaming map (stamp W(r,0)).
195 REM   W(r,1) mask stamp, W(r,2) splat register (stamp W(r,3)), W(r,4) vector copies' stamp
200 REM     (V(4r+q) the copy q); W(100000+r,0..4) per-register scratch of T11 and T13; W builds a splice.
203 REM   S regions (disjoint while in use; n a record row <= 199999): S(n) block partners (T13) or T12's
204 REM     class rows S(100000+g) and register rows S(150000+g) (g <= 49999); S(200000+n) per record
205 REM     (LSCAN's else; T12 copy index and guard decision); S(400000+n) T13 flags and groups per record,
206 REM     or T12's walk frames S(400000+600f) (f <= 600) and do exit states S(760600+260f) (f <= 40);
207 REM     S(600000+4k) counters (k <= 9999), S(640000+20g) groups (g <= 399), S(650000+4i) P2 stack
208 REM     (i <= 190), S(651000+4t) terms (t <= 6), S(660000+4k) merges (k <= 9999), S(700000+8k) sum8
209 REM     groups (k <= 4999), S(740000+3e) entries (e <= 2999), S(750000+4k+q) sum8 homes; S(800000+b),
210 REM     S(810000+b) block maps, S(820000+d) stacks (b, d <= 9999); S(830000+s) T12 slots, T11 move
211 REM     list, S(840000+l) walk state (l <= 256), S(850000+r) S(851000+r) parameters (r <= 64),
212 REM     S(860000+s), S(880000+s), S(890000+s) slots (s <= 9999), S(970000+4c) slot copies (c <= 5999),
213 REM     S(999000..) staging, constants, codes and entries.
215 REM   A work list is a range of rows of I (and operands of O) above A0 and A1: the routines that
220 REM     walk instructions walk it as they walk the function; a splice copies it in place of L.
225 REM ====================================================================================
360 FILES "sea.lir3"; "sea.lir"
365 DIM E(299), E$(299,5), N(39,2), N$(39), W$(299), Q(399,9), Q$(399), F(1499,3), F$(1499), Z(8)
370 DIM J(299,4), J$(299), Y(399), Y$(399,5), D(39), D$(39), B(399), A(399)
375 DIM I(199999,4), O(799999), R(99999,9), K(19999,4), C(199999,4), S$(199999)
380 DIM X(131071), T(10000), G$(300), U(40), L(4), H$(100), A$(2)
382 DIM M(301), P(262143), H(199999), V$(49999), U$(131071), G(199999,3), W(199999,4)
384 DIM S(999999), V(999999)
385 LET P$ = "seavec"
386 LET V8 = 2
387 DEF FNB(X, K) = INT(X / K) - 2 * INT(X / (2 * K))
388 DEF FNC(N) = Q(I(N, 1), 6)
389 DEF FNO(N, K) = O(I(N, 2) + K)
390 REM ---- the main program: lirrw's entries (passes/lib/API.md) around OPT --------------------
395 GOSUB 69400
397 GOSUB 1000
400 GOSUB 69410
405 IF Y0 < 0 THEN 425
410 GOSUB 500
415 GOSUB 69430
420 GOTO 400
425 GOSUB 69420
430 STOP
495 REM ====================================================================================
500 REM OPT: T11, T12, T13 of DESIGN 2.12.6 in that order, then T10 when one of them changed the
505 REM function (D9 counts the changes)
510 REM ====================================================================================
515 LET D9 = 0
520 FOR N3 = 0 TO A0
525 LET I(N3, 0) = 0
530 NEXT N3
535 GOSUB 1900
540 GOSUB 10000
545 GOSUB 15000
550 GOSUB 20000
555 IF D9 = 0 THEN 565
560 GOSUB 69440
565 RETURN
