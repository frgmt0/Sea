5 REM ====================================================================================
10 REM seacheck -- pass 2a of the Sea compiler: sea.ast -> sea.hir1 (docs/DESIGN.md 2.1, 3.4, 3.5)
15 REM Phase-1 subset (DESIGN 8 row 1): names, scopes, i64/f64/bool, untyped integer constants and
20 REM the var rule (LANGUAGE 4.2), cvt, operators (6.1-6.8), const items, powk by exact evaluation
25 REM (DESIGN 3.5.5, 2.8), if/while/for/break/continue, functions, ref, multiple results, printf
30 REM formats (LANGUAGE 11.1), now f64 i64 idiv, log exp sin cos pow hypot (DESIGN 4.10.5), pow
35 REM in constants by FEPOW; everything else 'not supported yet' (DESIGN 2.6.2).
40 REM Errors: every pass-2 error is recorded with its position; the first in source order (file,
45 REM line, column; ties: the first found) is reported (DESIGN 2.6.2); a capacity overflow wins.
50 REM Files: 1 sea.ast (input), 2 sea.hir1 (output). Built with io diag tables limb f64emu.
55 REM Tables (passed to every SUB): N M nodes, Y symbols, T types, W work stack, C literal limbs,
60 REM S$ strings, X X$ state, H the hash of C, O that of S$; Q the mtab words of FEPOW. Layouts: see the REM block of sc2util.
65 REM ====================================================================================
70 DIM E(299), E$(299,5), J(20), J$(20), K(299,4), K$(299), F$(100), A$(3)
75 DIM N(99999,9), M(99999,9), Y(49999,9), T(51209,9), W(199999), C(19999,4)
80 DIM S$(199999), X(60), X$(20), H(39989), O(399989), Q(2688)
85 FILES "sea.ast"; "sea.hir1"
90 LET P$ = "seacheck"
95 CALL "tb_errors": P$, E(), E$(), 299, E0
100 CALL "tb_exits": P$, E(), E$(), E0, J(), J$(), 20, J0
105 CALL "tb_consts": P$, E(), E$(), E0, K(), K$(), 299, K0
110 CALL "sc_lim": P$, K(), K$(), K0, X()
115 CALL "sc_pd": X$()
120 CALL "pdx": X$(), "pow", P9
125 IF P9 > 0 THEN 135
130 CALL "dg_bug": P$, "pow is not a predeclared name"
135 LET X(39) = P9
140 CALL "sc_read": P$, E(), E$(), E0, N(), M(), C(), S$(), W(), X(), X$(), F$(), N1, T$, H(), O()
145 REM the mtab words of FEPOW (DESIGN 4.10.5): the last DATA block, after records (sc_read)
150 CALL "FEMTI": Q(), E9
155 IF E9 = 0 THEN 165
160 CALL "tb_fail": P$, E(), E$(), E0
165 LET X(18) = N1 - 1
170 CALL "sc_check": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), H(), Q()
175 IF X(6) = 0 THEN 250
180 REM the first error (or a capacity overflow): one diagnostic line, status of a compile error
185 LET I = X(7)
190 LET Q = N(I, 4)
195 LET Q1 = N(I, 5)
200 IF X(36) = 0 THEN 220
205 REM a loop variable that exceeds the symbols limit: its npos (fsym)
210 LET Q = X(36)
215 LET Q1 = X(37)
220 LET F = INT(Q / 1E9)
225 LET L = Q - F * 1E9
230 FOR J = 1 TO X(8)
235 LET A$(J) = X$(J + 1)
240 NEXT J
245 CALL "dg_compile": P$, F$(), N1, F, L, Q1, X$(1), A$(), X(8), E(), E$(), E0
250 SCRATCH #2
255 CALL "io_hdr_put": 2, X(34), T$, F$(), N1
260 CALL "sc_emit": N(), M(), Y(), T(), W(), C(), S$(), X(), X$()
265 CALL "io_fin": 2
270 GOTO 99999
275 REM ---- sc_lim: the limits of limits.inc this pass needs, checked against the table sizes ----
280 SUB "sc_lim": P$, K(), K$(), K0, X()
285 DIM Q$(9)
290 LET Q$(1) = "FILE_VERSION"
295 LET Q$(2) = "LIM_SYMBOLS"
300 LET Q$(3) = "LIM_TYPES"
305 LET Q$(4) = "LIM_CONSTS"
310 LET Q$(5) = "LIM_NODES"
315 LET Q$(6) = "LIM_STRINGS"
320 LET Q$(7) = "LIM_POWK"
325 LET Q$(8) = "LIM_DEC_FIELD"
330 FOR I = 1 TO 8
335 CALL "tb_cval": K(), K$(), K0, Q$(I), V, T
340 IF T = 0 THEN 350
345 CALL "dg_bug": P$, "constant " & Q$(I) & " is not in the consts table"
350 IF I = 1 THEN 380
355 IF I = 8 THEN 370
360 LET X(18 + I) = V
365 GOTO 385
370 LET X(35) = V
375 GOTO 385
380 LET X(34) = V
385 NEXT I
390 IF X(20) > 49999 THEN 425
395 IF 9 + 2 * X(21) + INT(X(23) / 9) + 1 > 51209 THEN 425
400 IF X(21) > 19999 THEN 425
405 IF X(22) > 19999 THEN 425
410 IF X(23) > 99999 THEN 425
415 IF X(24) > 199999 THEN 425
420 GOTO 430
425 CALL "dg_bug": P$, "a capacity limit is larger than the pass tables"
430 SUBEND
435 REM ---- sc_pd: the predeclared names (LANGUAGE 3.3, Appendix C) in X$(10), 12-byte slots ------
440 REM slots 1-4 constants, 5-8 handle types, 9- functions; a name is found as "|name " (pdx)
445 SUB "sc_pd": X$()
450 LET L$ = "pi inf nan eps Figure Axes Lu Chol abs all any args argmax argmin argsort axis_equal "
455 LET L$ = L$ & "bar barh bincount ceil chol cols contour cos eig_sym error exp figure filled find "
460 LET L$ = L$ & "find_first find_last floor format grid hypot idiv image ind2sub isnan legend len "
465 LET L$ = L$ & "linspace log lower lu make_dir max mean meshgrid min nnz now numel ones panel plot "
470 LET L$ = L$ & "pow print printf rcond round rows save_svg setdiff sign sin solve sort sqrt std str "
475 LET L$ = L$ & "sub2ind sum title trunc twin_y variance where write_json x_ticks xlabel xline xlim "
480 LET L$ = L$ & "y_reverse y_ticks ylabel ylim zeros "
485 LET R$ = ""
490 LET S = 1
495 LET P = POS(L$, " ", S)
500 IF P = 0 THEN 520
505 LET R$ = R$ & SEG$("|" & SEG$(L$, S, P - 1) & "            ", 1, 12)
510 LET S = P + 1
515 GOTO 495
520 LET X$(10) = R$
525 SUBEND
