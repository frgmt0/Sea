5 REM ====================================================================================
10 REM seacheck -- pass 2a of the Sea compiler: sea.ast -> sea.hir1 (docs/DESIGN.md 2.1, 3.4, 3.5)
15 REM Phase-1 subset (DESIGN 8 row 1): names, scopes, i64/f64/bool, untyped integer constants and
20 REM the var rule (LANGUAGE 4.2), cvt, operators (6.1-6.8), const items, powk by exact evaluation
25 REM (DESIGN 3.5.5, 2.8), if/while/for/break/continue, functions, ref, multiple results, printf
30 REM formats (LANGUAGE 11.1), now f64 i64 idiv; everything else 'not supported yet' (DESIGN 2.6.2).
35 REM Errors: every pass-2 error is recorded with its position; the first in source order (file,
40 REM line, column; ties: the first found) is reported (DESIGN 2.6.2); a capacity overflow wins.
45 REM Files: 1 sea.ast (input), 2 sea.hir1 (output). Built with io diag tables limb f64emu.
50 REM Tables (passed to every SUB): N M nodes, Y symbols, T types, W work stack, C literal limbs,
55 REM S$ strings, X X$ state. Layouts: see the REM block of sc2util.
60 REM ====================================================================================
65 DIM E(299), E$(299,5), J(20), J$(20), K(299,4), K$(299), F$(100), A$(3)
70 DIM N(99999,9), M(99999,9), Y(49999,9), T(20099,9), W(199999), C(19999,4)
75 DIM S$(199999), X(60), X$(20)
80 FILES "sea.ast"; "sea.hir1"
85 LET P$ = "seacheck"
90 CALL "tb_errors": P$, E(), E$(), 299, E0
95 CALL "tb_exits": P$, E(), E$(), E0, J(), J$(), 20, J0
100 CALL "tb_consts": P$, E(), E$(), E0, K(), K$(), 299, K0
105 CALL "sc_lim": P$, K(), K$(), K0, X()
110 CALL "sc_pd": X$()
115 CALL "sc_read": P$, E(), E$(), E0, N(), M(), C(), S$(), W(), X(), X$(), F$(), N1, T$
120 LET X(18) = N1 - 1
125 CALL "sc_check": N(), M(), Y(), T(), W(), C(), S$(), X(), X$()
130 IF X(6) = 0 THEN 175
135 REM the first error (or a capacity overflow): one diagnostic line, status of a compile error
140 LET I = X(7)
145 LET F = INT(N(I, 4) / 1E9)
150 LET L = N(I, 4) - F * 1E9
155 FOR J = 1 TO X(8)
160 LET A$(J) = X$(J + 1)
165 NEXT J
170 CALL "dg_compile": P$, F$(), N1, F, L, N(I, 5), X$(1), A$(), X(8), E(), E$(), E0
175 SCRATCH #2
180 CALL "io_hdr_put": 2, X(34), T$, F$(), N1
185 CALL "sc_emit": N(), M(), Y(), T(), W(), C(), S$(), X(), X$()
190 CALL "io_fin": 2
195 GOTO 99999
200 REM ---- sc_lim: the limits of limits.inc this pass needs, checked against the table sizes ----
205 SUB "sc_lim": P$, K(), K$(), K0, X()
210 DIM Q$(9)
215 LET Q$(1) = "FILE_VERSION"
220 LET Q$(2) = "LIM_SYMBOLS"
225 LET Q$(3) = "LIM_TYPES"
230 LET Q$(4) = "LIM_CONSTS"
235 LET Q$(5) = "LIM_NODES"
240 LET Q$(6) = "LIM_STRINGS"
245 LET Q$(7) = "LIM_POWK"
250 FOR I = 1 TO 7
255 CALL "tb_cval": K(), K$(), K0, Q$(I), V, T
260 IF T = 0 THEN 270
265 CALL "dg_bug": P$, "constant " & Q$(I) & " is not in the consts table"
270 IF I = 1 THEN 285
275 LET X(18 + I) = V
280 GOTO 290
285 LET X(34) = V
290 NEXT I
295 IF X(20) > 49999 THEN 325
300 IF X(21) > 20089 THEN 325
305 IF X(22) > 19999 THEN 325
310 IF X(23) > 99999 THEN 325
315 IF X(24) > 199999 THEN 325
320 GOTO 330
325 CALL "dg_bug": P$, "a capacity limit is larger than the pass tables"
330 SUBEND
335 REM ---- sc_pd: the predeclared names (LANGUAGE 3.3, Appendix C) in X$(10), 12-byte slots ------
340 REM slots 1-4 constants, 5-8 handle types, 9- functions; a name is found as "|name " (pdx)
345 SUB "sc_pd": X$()
350 LET L$ = "pi inf nan eps Figure Axes Lu Chol abs all any args argmax argmin argsort axis_equal "
355 LET L$ = L$ & "bar barh bincount ceil chol cols contour cos eig_sym error exp figure filled find "
360 LET L$ = L$ & "find_first find_last floor format grid hypot idiv image ind2sub isnan legend len "
365 LET L$ = L$ & "linspace log lower lu make_dir max mean meshgrid min nnz now numel ones panel plot "
370 LET L$ = L$ & "pow print printf rcond round rows save_svg setdiff sign sin solve sort sqrt std str "
375 LET L$ = L$ & "sub2ind sum title trunc twin_y variance where write_json x_ticks xlabel xline xlim "
380 LET L$ = L$ & "y_reverse y_ticks ylabel ylim zeros "
385 LET R$ = ""
390 LET S = 1
395 LET P = POS(L$, " ", S)
400 IF P = 0 THEN 420
405 LET R$ = R$ & SEG$("|" & SEG$(L$, S, P - 1) & "            ", 1, 12)
410 LET S = P + 1
415 GOTO 395
420 LET X$(10) = R$
425 SUBEND
