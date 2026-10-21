63000 REM ====================================================================================
63005 REM diag.bas -- shared pass module: diagnostics (DESIGN 2.2, 2.6.2). API: passes/lib/API.md
63010 REM Lines 63000-65999 (DESIGN 2.6.3); no DATA, END or globals. Messages come from the error
63015 REM table (tb_errors); exit statuses from the exits table (tb_exits, kept in E$(0,1) internal
63020 REM and E$(0,2) compile). Bootstrap exception: dg_boot, dg_bug and dg_exit's fallback, which
63025 REM run without a table, hold the literals 11 / 10 of SEA_EXIT_PASS_INTERNAL / _COMPILE;
63030 REM tests/lib_check.sh compares them with errors.inc.
63035 REM ====================================================================================
63040 REM ---- dg_find -----------------------------------------------------------------------
63045 SUB "dg_find": Q$, E$(), E0, R
63050 LET R = 0
63055 FOR I = 1 TO E0
63060 REM names contain no blank, so = is an exact comparison here
63065 IF E$(I, 1) <> Q$ THEN 63080
63070 LET R = I
63075 GOTO 63085
63080 NEXT I
63085 SUBEND
63090 REM ---- dg_fmt ------------------------------------------------------------------------
63095 REM locals: S start of the text not yet copied, P next percent sign, K marks seen
63100 SUB "dg_fmt": T$, A$(), N2, R$, T
63105 LET R$ = ""
63110 LET K = 0
63115 LET S = 1
63120 LET L0 = LEN(T$)
63125 LET P = POS(T$, "%", S)
63130 IF P = 0 THEN 63210
63135 IF P = L0 THEN 63210
63140 LET C$ = SEG$(T$, P + 1, P + 1)
63145 IF C$ = "s" THEN 63180
63150 IF C$ = "d" THEN 63180
63155 IF C$ = "g" THEN 63180
63160 REM a percent sign that starts no mark stays as it is
63165 LET R$ = R$ & SEG$(T$, S, P)
63170 LET S = P + 1
63175 GOTO 63125
63180 LET K = K + 1
63185 LET R$ = R$ & SEG$(T$, S, P - 1)
63190 IF K > N2 THEN 63200
63195 LET R$ = R$ & A$(K)
63200 LET S = P + 2
63205 GOTO 63125
63210 LET R$ = R$ & SEG$(T$, S, L0)
63215 LET T = 0
63220 IF K <> N2 THEN 63230
63225 GOTO 63235
63230 LET T = 1
63235 SUBEND
63240 REM ---- dg_exit: the exit status for E$(0,K), K = 1 internal, 2 compile ---------------
63245 REM bootstrap fallback (exits table not loaded yet): the literals 11 and 10
63250 SUB "dg_exit": E$(), K, S
63255 IF LEN(E$(0, K)) = 0 THEN 63270
63260 LET S = VAL(E$(0, K))
63265 GOTO 63285
63270 LET S = 11
63275 IF K = 1 THEN 63285
63280 LET S = 10
63285 SUBEND
63290 REM ---- dg_note / dg_bug / dg_boot (no table: literal status 11, bootstrap exception) -----
63295 SUB "dg_note": P$, M$
63300 PRINT #-1, P$ & ": " & M$
63305 SUBEND
63310 SUB "dg_bug": P$, M$
63315 PRINT #-1, P$ & ": " & M$
63320 STOP 11
63325 SUBEND
63330 SUB "dg_boot": P$
63335 PRINT #-1, P$ & ": internal error: bad DATA table"
63340 STOP 11
63345 SUBEND
63350 REM ---- dg_internal -------------------------------------------------------------------
63355 REM locals: R row of the name, T$ message, T status of dg_fmt
63360 SUB "dg_internal": P$, Q$, E(), E$(), E0
63365 DIM A$(1)
63370 CALL "dg_find": Q$, E$(), E0, R
63375 IF R > 0 THEN 63385
63380 CALL "dg_bug": P$, "error name '" & Q$ & "' is not in the error table"
63385 IF E$(R, 2) = "P" THEN 63395
63390 CALL "dg_bug": P$, "error '" & Q$ & "' is not an internal check (phase P)"
63395 CALL "dg_fmt": E$(R, 5), A$(), 0, T$, T
63400 IF T = 0 THEN 63410
63405 CALL "dg_bug": P$, "error '" & Q$ & "' takes arguments"
63410 PRINT #-1, P$ & ": " & T$
63415 CALL "dg_exit": E$(), 1, S
63420 STOP S
63425 SUBEND
63430 REM ---- dg_compile --------------------------------------------------------------------
63435 REM locals: R row, T$ message text, T status, M$ the finished line
63440 SUB "dg_compile": P$, F$(), N1, F, L, C, Q$, A$(), N2, E(), E$(), E0
63445 CALL "dg_find": Q$, E$(), E0, R
63450 IF R > 0 THEN 63465
63455 CALL "dg_bug": P$, "error name '" & Q$ & "' is not in the error table"
63460 REM a run-time (R) or internal (P) error is no compile error
63465 IF E$(R, 2) <> "R" THEN 63475
63470 CALL "dg_bug": P$, "error '" & Q$ & "' is a run-time error, not a compile error"
63475 IF E$(R, 2) <> "P" THEN 63485
63480 CALL "dg_bug": P$, "error '" & Q$ & "' is an internal check, not a compile error"
63485 IF F >= 0 THEN 63495
63490 CALL "dg_bug": P$, "position with a negative file index"
63495 IF F < N1 THEN 63505
63500 CALL "dg_bug": P$, "position names file " & STR$(F) & " but the header has " & STR$(N1)
63505 CALL "dg_fmt": E$(R, 5), A$(), N2, T$, T
63510 IF T = 0 THEN 63520
63515 CALL "dg_bug": P$, "error '" & Q$ & "': " & STR$(N2) & " values for " & E$(R, 4)
63520 LET M$ = F$(F + 1) & ":" & STR$(L) & ":" & STR$(C) & ": error: " & T$
63525 PRINT #-1, M$
63530 CALL "dg_exit": E$(), 2, S
63535 STOP S
63540 SUBEND
