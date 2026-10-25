100 REM ====================================================================================
105 REM sealopt -- pass 3c: sea.lir2 -> sea.lir (DESIGN 2.1, 3.6.5 "Pass 3c", 5.8; Decision 74,
110 REM L-bc). Lines 100-59999, SUBs none. Built as DESIGN 2.6.3 says: the files lo0main ... lo6t9
115 REM (in name order), io diag tables and the shared main-program part lirrw, the DATA blocks
120 REM errors exits consts entries records, then 99999 END (passes/sealopt/build.list).
125 REM FLOW: lirrw (passes/lib/lirrw.bas, contract in passes/lib/API.md) reads and validates one
130 REM function of sea.lir2 into the tables, exactly as seaopt reads sea.lir1; this pass applies
135 REM T5 T6 T8 T7 T8 T9 of DESIGN 5.8 (L-ao, L-be, L-bl, L-bm, L-br, L-bs, L-bt) and lirrw's T10
140 REM (entry 69440), and lirrw writes it renumbered. A function none of T5-T9 changes is written
145 REM as read (T10 is idempotent on seaopt's output). Errors: lirrw's (BAD_RECORD status 11, a
150 REM capacity limit "program too large" status 10); a transformation whose result would exceed
155 REM a LIR capacity limit is not applied (Decision 72).
160 REM TABLES: the DIMs below are lirrw's contract (24 numeric and 14 string array letters, its 173
165 REM reserved scalars). This pass's own: S and V (the two free letters), the columns 0 and 3-9
170 REM of R, W between lirrw's entries and I(n,0):
175 REM   I(n,0) = id*4096 + flags of record n: 1 placed (stood before an opening record by T5, T7,
180 REM     T8: what "stands there" for T8's commoning), 2 reduced (T7), 4 slow (a loop of a slow
185 REM     copy, T6), 8 versioned (the fast copy's loop), 16 dead (L-bb 3), 32 64 marks of one
190 REM     step, 128-1024 the tag of T9's placement; id: the opening record's identity in a step.
195 REM   R(r,3) definitions, R(r,4) the last one (0 the func record), R(r,5) array register,
200 REM     R(r,6) the value of a constant (only definition one li, -2^52..2^52) else N8, R(r,7)
205 REM     private base, R(r,0) R(r,8) R(r,9) marks, maps and counts of one step.
210 REM   S(n) the part of record n (2*o + 0 the body or first part, 2*o + 1 the else part of the
215 REM     block opened at record o; 0 the function body); S(200000+n), S(400000+n) the records
220 REM     to put before and after snapshot record n, S(600000+w) the next one after W row w;
225 REM     S(800000..) the block stack, S(820000..) the loops of a step, S(830000..) small lists,
230 REM     S(840000..) the tables of one step (T5's promoted locations, T6's cows, T7's Q).
232 REM   Every table write is tested against its region first; a step whose table would overflow
233 REM   leaves that loop as it is (L-bv). Scratch between entries: W1 (T6, NEWC), W2 the overflow
234 REM   flag, W3-W6 T7's saved counts (lirrw's reserved scalars, never Z8 or its other state).
235 REM   W(w,0..4), V(k): the snapshot of I(n,0..4) and O(k), then the new records (REBUILD).
240 REM ====================================================================================
360 FILES "sea.lir2"; "sea.lir"
365 DIM E(299), E$(299,5), N(39,2), N$(39), W$(299), Q(399,9), Q$(399), F(1499,3), F$(1499), Z(8)
370 DIM J(299,4), J$(299), Y(399), Y$(399,5), D(39), D$(39), B(399), A(399)
375 DIM I(199999,4), O(799999), R(99999,9), K(19999,4), C(199999,4), S$(199999)
380 DIM X(131071), T(10000), G$(300), U(40), L(4), H$(100), A$(2)
382 DIM M(301), P(262143), H(199999), V$(49999), U$(131071), G(199999,3), W(199999,4)
384 DIM S(999999), V(999999)
385 LET P$ = "sealopt"
386 LET V8 = 2
388 DEF FNB(X, K) = INT(X / K) - 2 * INT(X / (2 * K))
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
500 REM OPT: the transformations of one function, in the order of DESIGN 5.8 for pass 3c (L-be)
505 REM ====================================================================================
510 FOR N3 = 1 TO A0
515 LET I(N3, 0) = 0
520 NEXT N3
525 LET G0 = 0
530 LET G1 = 0
535 GOSUB 10000
540 GOSUB 15000
545 LET P7 = 1
550 GOSUB 20000
555 GOSUB 25000
560 LET P7 = 2
565 GOSUB 20000
570 GOSUB 30000
575 GOSUB 69440
580 RETURN
