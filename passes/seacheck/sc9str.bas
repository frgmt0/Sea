21000 REM ==== sc9str: match, lower and args of sub-phase 4g-1 (DESIGN 2.6.2 step 4g-1, "Readings fixed by
21005 REM 4g"; LANGUAGE 7.6, 10.9, 10.10; Decision 46, lead decisions L-a and L-d) =====================
21010 REM ---- ck_match: match I. 207 at the match when its last arm is not a _ arm (no arm included),
21015 REM found first; the scrutinee a str (201 at it); 208 once at every arm after a _ arm and at every
21020 REM arm with a pattern equal byte for byte to an earlier pattern of the match (interned: one S$
21025 REM index per byte string); each arm's block in order. A match ends no path (LANGUAGE 8.1) -----
21030 SUB "ck_match": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
21035 LET E = N(I, 7)
21040 LET A = E
21045 FOR H = 1 TO N(I, 1)
21050 LET A = N(A, 8)
21055 NEXT H
21060 IF N(I, 1) = 0 THEN 21070
21065 IF N(A, 1) = 0 THEN 21075
21070 CALL "er": N(), X(), X$(), I, "NOT_EXHAUSTIVE", "", "", "", 0
21075 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
21080 CALL "vu": N(), M(), T(), X(), X$(), E, D
21085 CALL "fin": N(), M(), C(), X(), X$(), E
21090 LET D = M(E, 1) * SGN(D * D)
21095 IF D * (D - 5) = 0 THEN 21110
21100 CALL "tyn": T(), D, A$
21105 CALL "er": N(), X(), X$(), E, "TYPE_MISMATCH", "str", A$, "", 2
21110 REM U = 1 once a _ arm is seen; Z = 1 when the arm is unreachable
21115 LET U = 0
21120 LET A = N(E, 8)
21125 FOR H = 1 TO N(I, 1)
21130 LET Z = U
21135 LET P = N(A, 7)
21140 FOR K = 1 TO N(A, 1)
21145 REM the patterns are str leaves, written as cs (DESIGN 3.5.5)
21150 LET M(P, 1) = 5
21155 LET M(P, 4) = 0
21160 LET M(P, 5) = 0
21165 LET M(P, 7) = 0
21170 LET M(P, 8) = 0
21175 REM an earlier pattern of the same bytes: the arms from the first, up to P
21180 LET B = N(E, 8)
21185 LET Q = N(B, 7)
21190 LET G = 1
21195 IF Q = P THEN 21240
21200 IF G > N(B, 1) THEN 21225
21205 IF N(Q, 6) = N(P, 6) THEN 21235
21210 LET Q = N(Q, 8)
21215 LET G = G + 1
21220 GOTO 21195
21225 LET B = N(B, 8)
21230 GOTO 21185
21235 LET Z = 1
21240 LET P = N(P, 8)
21245 NEXT K
21250 IF Z = 0 THEN 21260
21255 CALL "er": N(), X(), X$(), A, "UNREACHABLE_PATTERN", "", "", "", 0
21260 IF N(A, 1) > 0 THEN 21270
21265 LET U = 1
21270 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), P
21275 LET A = N(A, 8)
21280 NEXT H
21285 SUBEND
21290 REM ---- lstr: the overloads of lower (Z 25: one str, result str) and args (Z 26: no argument,
21295 REM result str[]) for call J with H1 positional arguments (the named ones were reported by
21300 REM ck_narg); D the result type, Z9 = 1 for no overload (243; lerr keeps the result type) ------
21305 SUB "lstr": N(), M(), T(), X(), X$(), J, Z, H1, D, Z9
21310 LET Z9 = 1
21315 IF Z = 25 THEN 21340
21320 IF H1 > 0 THEN 21360
21325 CALL "tarr": T(), N(), X(), X$(), 1, 5, 0, 0, D
21330 LET Z9 = 0
21335 GOTO 21360
21340 IF H1 <> 1 THEN 21360
21345 IF M(N(N(J, 7), 8), 1) <> 5 THEN 21360
21350 LET D = 5
21355 LET Z9 = 0
21360 SUBEND
21365 REM ---- em_mt: match I (DESIGN 3.5.5): the scrutinee, then each arm (its cs patterns, its block,
21370 REM arm k), then match n; every node at its own position ------------------------------------
21375 SUB "em_mt": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
21380 LET E = N(I, 7)
21385 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
21390 LET A = N(E, 8)
21395 FOR H = 1 TO N(I, 1)
21400 LET P = N(A, 7)
21405 FOR K = 1 TO N(A, 1)
21410 CALL "em_node": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), P
21415 LET P = N(P, 8)
21420 NEXT K
21425 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), P
21430 CALL "pos": N(), A, P$
21435 CALL "wr": X(), "arm " & P$ & " " & STR$(N(A, 1))
21440 LET A = N(A, 8)
21445 NEXT H
21450 CALL "pos": N(), I, P$
21455 CALL "wr": X(), "match " & P$ & " " & STR$(N(I, 1))
21460 SUBEND
