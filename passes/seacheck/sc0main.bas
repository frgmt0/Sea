5 REM ====================================================================================
10 REM seacheck -- pass 2a, second program: sea.res -> sea.hir1 (docs/DESIGN.md 2.1, 3.4.1, 3.5)
15 REM From phase 4a (Decision 17) seaname resolves the names, checks the declarations and evaluates
20 REM the constants (sea.res); this program checks and types the rest: i64/f64/bool, untyped
25 REM integer constants and the var rule (LANGUAGE 4.2), cvt, operators (6.1-6.8), the const items
30 REM and the value of each by Decision 25 (DESIGN 3.4.1 "Constants"), powk where sea.res has an
35 REM rpowk, if/while/for/break/continue, functions, ref, multiple results, printf formats
40 REM (LANGUAGE 11.1), now f64 i64 idiv log exp sin cos pow hypot; from 4d the dynamic arrays of
45 REM f64 i64 bool, scalar indexing, $, for over a vector, zeros ones filled len rows cols numel
50 REM and the elemental functions (from 6c with arrays too, sc9call ebc); from 4e (sc9arr) fixed-size arrays, selections, views,
55 REM literals, dyn/fix, broadcasting (DESIGN 2.6.2 step 4e); from 4f (sc9red) the reductions, sort,
57 REM argsort, find*, the options dim: and desc: (step 4f); the rest 'not supported yet'. It takes every
60 REM lid, fid, cid, sid and every declared type (the type table, rtype) from sea.res and validates
65 REM sea.res first (3.4.1, 3.4.2 "What seacheck validates": BAD_RECORD).
70 REM Errors: every error is recorded with its position; the first in source order (file, line,
75 REM column; ties: the first found) is reported, starting with seaname's rerr as the first found
80 REM (DESIGN 2.6.2 "Order across the two programs"); a capacity overflow wins.
85 REM Files: 1 sea.res (input), 2 sea.hir1 (output). Built with io diag tables.
90 REM Tables (passed to every SUB): N M nodes, Y symbols, T types, W work stack, C literal limbs,
95 REM S$ strings, X X$ state, H the hash of C, O that of S$. Layouts: the REM block of sc2util.
100 REM ====================================================================================
105 DIM E(299), E$(299,5), J(20), J$(20), K(299,4), K$(299), F$(100), A$(3)
110 DIM N(99999,9), M(99999,9), Y(49999,9), T(65009,9), W(199999), C(19999,4)
115 DIM S$(199999), X(60), X$(20), H(39989), O(399989)
120 FILES "sea.res"; "sea.hir1"
125 LET P$ = "seacheck"
130 CALL "tb_errors": P$, E(), E$(), 299, E0
135 CALL "tb_exits": P$, E(), E$(), E0, J(), J$(), 20, J0
140 CALL "tb_consts": P$, E(), E$(), E0, K(), K$(), 299, K0
145 CALL "sc_lim": P$, K(), K$(), K0, X()
150 CALL "sc_pd": X$()
155 REM the T rows of the rtup records are made while reading: the types count starts with them
160 LET X(4) = 9
165 LET X(38) = 0
170 CALL "sc_read": P$, E(), E$(), E0, N(), M(), C(), S$(), W(), T(), X(), X$(), F$(), N1, H(), O()
175 LET X(18) = N1 - 1
180 CALL "sc_check": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), H()
185 IF X(26) = 0 THEN 195
190 CALL "dg_internal": P$, "BAD_RECORD", E(), E$(), E0
195 IF X(6) = 0 THEN 270
200 REM the first error (or a capacity overflow): one diagnostic line, status of a compile error
205 LET I = X(7)
210 LET Q = N(I, 4)
215 LET Q1 = N(I, 5)
220 IF X(36) = 0 THEN 240
225 REM seaname's error (rerr): its own position
230 LET Q = X(36)
235 LET Q1 = X(37)
240 LET F = INT(Q / 1E9)
245 LET L = Q - F * 1E9
250 FOR J = 1 TO X(8)
255 CALL "tyx": S$(), X$(J + 1), A$(J)
260 NEXT J
265 CALL "dg_compile": P$, F$(), N1, F, L, Q1, X$(1), A$(), X(8), E(), E$(), E0
270 SCRATCH #2
275 CALL "io_hdr_put": 2, X(34), X$(11), F$(), N1
280 CALL "sc_emit": N(), M(), Y(), T(), W(), C(), S$(), X(), X$()
285 CALL "io_fin": 2
290 GOTO 99999
295 REM ---- sc_lim: the limits of limits.inc this pass needs, checked against the table sizes ----
300 SUB "sc_lim": P$, K(), K$(), K0, X()
305 DIM Q$(9)
310 LET Q$(1) = "FILE_VERSION"
315 LET Q$(2) = "LIM_SYMBOLS"
320 LET Q$(3) = "LIM_TYPES"
325 LET Q$(4) = "LIM_CONSTS"
330 LET Q$(5) = "LIM_NODES"
335 LET Q$(6) = "LIM_STRINGS"
340 LET Q$(7) = "LIM_POWK"
345 LET Q$(8) = "LIM_DEC_FIELD"
347 LET Q$(9) = "LIM_FIXED_ELEMS"
350 FOR I = 1 TO 9
355 CALL "tb_cval": K(), K$(), K0, Q$(I), V, T
360 IF T = 0 THEN 370
365 CALL "dg_bug": P$, "constant " & Q$(I) & " is not in the consts table"
370 IF I = 1 THEN 400
372 IF I = 9 THEN 397
375 IF I = 8 THEN 390
380 LET X(18 + I) = V
385 GOTO 405
390 LET X(35) = V
395 GOTO 405
397 LET X(39) = V
398 GOTO 405
400 LET X(34) = V
405 NEXT I
410 IF X(20) > 49999 THEN 445
415 IF 9 + 2 * X(21) + INT(X(23) / 4) + 1 > 65009 THEN 445
420 IF X(21) > 19999 THEN 445
425 IF X(22) > 19999 THEN 445
430 IF X(23) > 99999 THEN 445
435 IF X(24) > 199999 THEN 445
440 GOTO 450
445 CALL "dg_bug": P$, "a capacity limit is larger than the pass tables"
450 SUBEND
455 REM ---- sc_pd: the predeclared names (LANGUAGE 3.3, Appendix C) in X$(10), 12-byte slots ------
460 REM slots 1-4 constants, 5-8 handle types, 9- functions; a name is found as "|name " (pdx)
465 SUB "sc_pd": X$()
470 LET L$ = "pi inf nan eps Figure Axes Lu Chol abs all any args argmax argmin argsort axis_equal "
475 LET L$ = L$ & "bar barh bincount ceil chol cols contour cos eig_sym error exp figure filled find "
480 LET L$ = L$ & "find_first find_last floor format grid hypot idiv image ind2sub isnan legend len "
485 LET L$ = L$ & "linspace log lower lu make_dir max mean meshgrid min nnz now numel ones panel plot "
490 LET L$ = L$ & "pow print printf rcond round rows save_svg setdiff sign sin solve sort sqrt std str "
495 LET L$ = L$ & "sub2ind sum title trunc twin_y variance where write_json x_ticks xlabel xline xlim "
500 LET L$ = L$ & "y_reverse y_ticks ylabel ylim zeros "
505 LET R$ = ""
510 LET S = 1
515 LET P = POS(L$, " ", S)
520 IF P = 0 THEN 540
525 LET R$ = R$ & SEG$("|" & SEG$(L$, S, P - 1) & "            ", 1, 12)
530 LET S = P + 1
535 GOTO 515
540 LET X$(10) = R$
545 SUBEND
