5 REM ====================================================================================
10 REM seacheck -- pass 2a, second program: sea.res -> sea.hir1 (docs/DESIGN.md 2.1, 3.4.1, 3.5)
15 REM From phase 4a (Decision 17) seaname resolves the names, checks the declarations and evaluates
20 REM the constants (sea.res); this program checks and types the rest: i64/f64/bool, untyped
25 REM integer constants and the var rule (LANGUAGE 4.2), cvt, operators (6.1-6.8), the const items
30 REM and the value of each by Decision 25 (DESIGN 3.4.1 "Constants"), powk where sea.res has an
35 REM rpowk, if/while/for/break/continue, functions, ref, multiple results, printf formats
40 REM (LANGUAGE 11.1), now f64 i64 idiv log exp sin cos pow hypot; everything else 'not supported
45 REM yet' (DESIGN 2.6.2). It takes every lid, fid, cid, sid and declared type from sea.res and
50 REM validates sea.res first (3.4.1 "What seacheck validates": BAD_RECORD).
55 REM Errors: every error is recorded with its position; the first in source order (file, line,
60 REM column; ties: the first found) is reported, starting with seaname's rerr as the first found
65 REM (DESIGN 2.6.2 "Order across the two programs"); a capacity overflow wins.
70 REM Files: 1 sea.res (input), 2 sea.hir1 (output). Built with io diag tables.
75 REM Tables (passed to every SUB): N M nodes, Y symbols, T types, W work stack, C literal limbs,
80 REM S$ strings, X X$ state, H the hash of C, O that of S$. Layouts: the REM block of sc2util.
85 REM ====================================================================================
90 DIM E(299), E$(299,5), J(20), J$(20), K(299,4), K$(299), F$(100), A$(3)
95 DIM N(99999,9), M(99999,9), Y(49999,9), T(51209,9), W(199999), C(19999,4)
100 DIM S$(199999), X(60), X$(20), H(39989), O(399989)
105 FILES "sea.res"; "sea.hir1"
110 LET P$ = "seacheck"
115 CALL "tb_errors": P$, E(), E$(), 299, E0
120 CALL "tb_exits": P$, E(), E$(), E0, J(), J$(), 20, J0
125 CALL "tb_consts": P$, E(), E$(), E0, K(), K$(), 299, K0
130 CALL "sc_lim": P$, K(), K$(), K0, X()
135 CALL "sc_pd": X$()
140 REM the T rows of the rtup records are made while reading: the types count starts with them
145 LET X(4) = 9
150 LET X(38) = 0
155 CALL "sc_read": P$, E(), E$(), E0, N(), M(), C(), S$(), W(), T(), X(), X$(), F$(), N1, H(), O()
160 LET X(18) = N1 - 1
165 CALL "sc_check": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), H()
170 IF X(26) = 0 THEN 180
175 CALL "dg_internal": P$, "BAD_RECORD", E(), E$(), E0
180 IF X(6) = 0 THEN 255
185 REM the first error (or a capacity overflow): one diagnostic line, status of a compile error
190 LET I = X(7)
195 LET Q = N(I, 4)
200 LET Q1 = N(I, 5)
205 IF X(36) = 0 THEN 225
210 REM seaname's error (rerr): its own position
215 LET Q = X(36)
220 LET Q1 = X(37)
225 LET F = INT(Q / 1E9)
230 LET L = Q - F * 1E9
235 FOR J = 1 TO X(8)
240 LET A$(J) = X$(J + 1)
245 NEXT J
250 CALL "dg_compile": P$, F$(), N1, F, L, Q1, X$(1), A$(), X(8), E(), E$(), E0
255 SCRATCH #2
260 CALL "io_hdr_put": 2, X(34), X$(11), F$(), N1
265 CALL "sc_emit": N(), M(), Y(), T(), W(), C(), S$(), X(), X$()
270 CALL "io_fin": 2
275 GOTO 99999
280 REM ---- sc_lim: the limits of limits.inc this pass needs, checked against the table sizes ----
285 SUB "sc_lim": P$, K(), K$(), K0, X()
290 DIM Q$(9)
295 LET Q$(1) = "FILE_VERSION"
300 LET Q$(2) = "LIM_SYMBOLS"
305 LET Q$(3) = "LIM_TYPES"
310 LET Q$(4) = "LIM_CONSTS"
315 LET Q$(5) = "LIM_NODES"
320 LET Q$(6) = "LIM_STRINGS"
325 LET Q$(7) = "LIM_POWK"
330 LET Q$(8) = "LIM_DEC_FIELD"
335 FOR I = 1 TO 8
340 CALL "tb_cval": K(), K$(), K0, Q$(I), V, T
345 IF T = 0 THEN 355
350 CALL "dg_bug": P$, "constant " & Q$(I) & " is not in the consts table"
355 IF I = 1 THEN 385
360 IF I = 8 THEN 375
365 LET X(18 + I) = V
370 GOTO 390
375 LET X(35) = V
380 GOTO 390
385 LET X(34) = V
390 NEXT I
395 IF X(20) > 49999 THEN 430
400 IF 9 + 2 * X(21) + INT(X(23) / 9) + 1 > 51209 THEN 430
405 IF X(21) > 19999 THEN 430
410 IF X(22) > 19999 THEN 430
415 IF X(23) > 99999 THEN 430
420 IF X(24) > 199999 THEN 430
425 GOTO 435
430 CALL "dg_bug": P$, "a capacity limit is larger than the pass tables"
435 SUBEND
440 REM ---- sc_pd: the predeclared names (LANGUAGE 3.3, Appendix C) in X$(10), 12-byte slots ------
445 REM slots 1-4 constants, 5-8 handle types, 9- functions; a name is found as "|name " (pdx)
450 SUB "sc_pd": X$()
455 LET L$ = "pi inf nan eps Figure Axes Lu Chol abs all any args argmax argmin argsort axis_equal "
460 LET L$ = L$ & "bar barh bincount ceil chol cols contour cos eig_sym error exp figure filled find "
465 LET L$ = L$ & "find_first find_last floor format grid hypot idiv image ind2sub isnan legend len "
470 LET L$ = L$ & "linspace log lower lu make_dir max mean meshgrid min nnz now numel ones panel plot "
475 LET L$ = L$ & "pow print printf rcond round rows save_svg setdiff sign sin solve sort sqrt std str "
480 LET L$ = L$ & "sub2ind sum title trunc twin_y variance where write_json x_ticks xlabel xline xlim "
485 LET L$ = L$ & "y_reverse y_ticks ylabel ylim zeros "
490 LET R$ = ""
495 LET S = 1
500 LET P = POS(L$, " ", S)
505 IF P = 0 THEN 525
510 LET R$ = R$ & SEG$("|" & SEG$(L$, S, P - 1) & "            ", 1, 12)
515 LET S = P + 1
520 GOTO 500
525 LET X$(10) = R$
530 SUBEND
