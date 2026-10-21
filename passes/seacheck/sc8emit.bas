10550 REM ---- sc_emit: sea.hir1 (DESIGN 3.5): the type table, the constants, the functions. The
10555 REM records are produced twice: mode 1 (X(27) = 1) only numbers the types in order of first
10560 REM reference (3.5.1), mode 2 writes the table and then every record. ----------------------
10565 SUB "sc_emit": N(), M(), Y(), T(), W(), C(), S$(), X(), X$()
10570 LET X(28) = 0
10575 FOR H = 1 TO 2
10580 LET X(27) = H
10585 IF H = 1 THEN 10655
10590 FOR J = 1 TO X(28)
10595 LET Q = W(180000 + J)
10600 IF T(Q, 0) = 7 THEN 10620
10605 CALL "tyr": T(), W(), X(), T(Q, 1), A$
10610 CALL "wr": X(), "tvec " & STR$(9 + J) & " " & A$
10615 GOTO 10650
10620 LET L$ = "ttuple " & STR$(9 + J) & " " & STR$(T(Q, 1))
10625 FOR K = 1 TO T(Q, 1)
10630 CALL "tyr": T(), W(), X(), T(Q + 1 + INT((K - 1) / 9), K - 1 - 9 * INT((K - 1) / 9)), A$
10635 LET L$ = L$ & " " & A$
10640 NEXT K
10645 CALL "wr": X(), L$
10650 NEXT J
10655 FOR S = 2 TO X(33)
10660 IF Y(S, 0) <> 2 THEN 10710
10665 LET F = Y(S, 3)
10670 LET E = N(F, 7)
10675 IF N(F, 1) = 0 THEN 10685
10680 LET E = N(E, 8)
10685 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
10690 CALL "tyr": T(), W(), X(), Y(S, 2), A$
10695 CALL "io_esc": S$(Y(S, 1)), 0, B$
10700 CALL "pos": N(), F, P$
10705 CALL "wr": X(), "cn " & STR$(Y(S, 5)) & " " & B$ & " " & A$ & " " & P$
10710 NEXT S
10715 CALL "em_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), 1
10720 FOR S = 2 TO X(33)
10725 IF Y(S, 0) <> 1 THEN 10735
10730 CALL "em_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
10735 NEXT S
10740 NEXT H
10745 SUBEND
10750 REM ---- wr: one record of sea.hir1 (mode 2 only) ---------------------------------------------
10755 SUB "wr": X(), L$
10760 IF X(27) <> 2 THEN 10770
10765 PRINT #2, L$
10770 SUBEND
10775 REM ---- tyr: R$ = the written id of type Q; in mode 1 a type not yet numbered gets the next id,
10780 REM after its components (DESIGN 3.5.1); W(180000+j) = the type with id 9+j ----------------
10785 SUB "tyr": T(), W(), X(), Q, R$
10790 IF Q >= 10 THEN 10805
10795 LET R$ = STR$(Q)
10800 GOTO 10860
10805 IF T(Q, 9) > 0 THEN 10855
10810 IF T(Q, 0) = 7 THEN 10825
10815 CALL "tyr": T(), W(), X(), T(Q, 1), A$
10820 GOTO 10840
10825 FOR J = 1 TO T(Q, 1)
10830 CALL "tyr": T(), W(), X(), T(Q + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9)), A$
10835 NEXT J
10840 LET X(28) = X(28) + 1
10845 LET T(Q, 9) = X(28) + 9
10850 LET W(180000 + X(28)) = Q
10855 LET R$ = STR$(T(Q, 9))
10860 SUBEND
10865 REM ---- em_fn: function S (1 = .main): fn, par and loc records, the body, end (DESIGN 3.5.4) ---
10870 SUB "em_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
10875 LET F = Y(S, 3)
10880 LET P0 = Y(S, 6)
10885 LET L0 = Y(S, 8) - Y(S, 9) + 1 - P0
10890 IF S > 1 THEN 10910
10895 LET P$ = STR$(X(18)) & ":1:1"
10900 CALL "wr": X(), "fn 1 .main main 1 0 " & STR$(L0) & " " & P$
10905 GOTO 10930
10910 CALL "tyr": T(), W(), X(), Y(S, 2), A$
10915 CALL "io_esc": S$(Y(S, 1)), 0, B$
10920 CALL "pos": N(), F, P$
10925 CALL "wr": X(), "fn " & STR$(Y(S, 5)) & " " & B$ & " fn " & A$ & " " & STR$(P0) & " " & STR$(L0) & " " & P$
10930 FOR R = Y(S, 9) TO Y(S, 8)
10935 CALL "tyr": T(), W(), X(), Y(R, 2), A$
10940 CALL "io_esc": S$(Y(R, 1)), 0, B$
10945 LET U = Y(R, 4)
10950 IF U < 4 THEN 10965
10955 CALL "wr": X(), "par " & B$ & " " & A$ & " " & SEG$("valref", 3 * U - 11, 3 * U - 9)
10960 GOTO 11000
10965 CALL "pos": N(), Y(R, 3), C$
10970 IF U <> 3 THEN 10995
10975 REM a loop variable: its name follows the for keyword and one blank (DESIGN 3.5.4)
10980 LET I = Y(R, 3)
10985 LET G = INT(N(I, 4) / 1E9)
10990 LET C$ = STR$(G) & ":" & STR$(N(I, 4) - G * 1E9) & ":" & STR$(N(I, 5) + 4)
10995 CALL "wr": X(), "loc " & B$ & " " & A$ & " " & SEG$("let var for", 4 * U - 3, 4 * U - 1) & " " & C$
11000 NEXT R
11005 IF S > 1 THEN 11065
11010 LET I = N(X(17), 7)
11015 IF I = 0 THEN 11055
11020 LET K = N(I, 0)
11025 IF K = 2 THEN 11045
11030 IF K = 3 THEN 11045
11035 IF K = 5 THEN 11045
11040 CALL "em_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
11045 LET I = N(I, 8)
11050 GOTO 11015
11055 CALL "wr": X(), "block " & P$ & " " & STR$(X(29))
11060 GOTO 11090
11065 LET I = N(F, 7)
11070 FOR J = 1 TO P0 + Y(S, 7)
11075 LET I = N(I, 8)
11080 NEXT J
11085 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
11090 CALL "wr": X(), "end"
11095 SUBEND
11100 REM ---- em_blk: block B and its statements ---------------------------------------------------
11105 SUB "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
11110 LET I = N(B, 7)
11115 IF I = 0 THEN 11135
11120 CALL "em_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
11125 LET I = N(I, 8)
11130 GOTO 11115
11135 CALL "pos": N(), B, P$
11140 CALL "wr": X(), "block " & P$ & " " & STR$(N(B, 1))
11145 SUBEND
11150 REM ---- em_st: statement I (DESIGN 3.5.5) -------------------------------------------------
11155 SUB "em_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
11160 LET K = N(I, 0)
11165 LET G = N(I, 7)
11170 IF K < 8 THEN 11600
11175 IF K > 24 THEN 11600
11180 ON K - 7 GOTO 11185, 11185, 11600, 11600, 11600, 11295, 11325, 11385, 11405, 11465, 11490, 11600, 11600, 11515, 11530, 11545, 11595
11185 LET E = N(G, 8)
11190 IF N(I, 1) = 0 THEN 11200
11195 LET E = N(E, 8)
11200 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
11205 CALL "pos": N(), I, P$
11210 IF N(G, 0) = 10 THEN 11275
11215 IF N(G, 0) = 11 THEN 11285
11220 LET L$ = "tbind " & P$ & " " & STR$(N(G, 1))
11225 LET Q = N(G, 7)
11230 IF Q = 0 THEN 11265
11235 IF N(Q, 0) = 10 THEN 11250
11240 LET L$ = L$ & " -"
11245 GOTO 11255
11250 LET L$ = L$ & " " & STR$(Y(M(Q, 2), 5))
11255 LET Q = N(Q, 8)
11260 GOTO 11230
11265 CALL "wr": X(), L$
11270 GOTO 11600
11275 CALL "wr": X(), "bind " & P$ & " " & STR$(Y(M(G, 2), 5))
11280 GOTO 11600
11285 CALL "wr": X(), "eval " & P$
11290 GOTO 11600
11295 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
11300 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(G, 8)
11305 CALL "pos": N(), I, P$
11310 LET O = N(I, 1)
11315 CALL "wr": X(), "asg " & P$ & " " & SEG$("set add sub mul div", 4 * O - 3, 4 * O - 1)
11320 GOTO 11600
11325 FOR J = 1 TO N(I, 1)
11330 IF N(G, 0) = 11 THEN 11345
11335 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
11340 GOTO 11355
11345 CALL "pos": N(), G, P$
11350 CALL "wr": X(), "skip " & P$ & " 1"
11355 LET G = N(G, 8)
11360 NEXT J
11365 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
11370 CALL "pos": N(), I, P$
11375 CALL "wr": X(), "tasg " & P$ & " " & STR$(N(I, 1))
11380 GOTO 11600
11385 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
11390 CALL "pos": N(), I, P$
11395 CALL "wr": X(), "eval " & P$
11400 GOTO 11600
11405 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
11410 LET B = N(G, 8)
11415 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
11420 IF N(I, 1) = 0 THEN 11450
11425 LET B = N(B, 8)
11430 IF N(B, 0) = 24 THEN 11445
11435 CALL "em_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
11440 GOTO 11450
11445 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
11450 CALL "pos": N(), I, P$
11455 CALL "wr": X(), "if " & P$ & " " & STR$(N(I, 1))
11460 GOTO 11600
11465 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
11470 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(G, 8)
11475 CALL "pos": N(), I, P$
11480 CALL "wr": X(), "while " & P$
11485 GOTO 11600
11490 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
11495 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(G, 8)
11500 CALL "pos": N(), I, P$
11505 CALL "wr": X(), "forr " & P$ & " " & STR$(Y(M(I, 2), 5))
11510 GOTO 11600
11515 CALL "pos": N(), I, P$
11520 CALL "wr": X(), "break " & P$
11525 GOTO 11600
11530 CALL "pos": N(), I, P$
11535 CALL "wr": X(), "cont " & P$
11540 GOTO 11600
11545 FOR J = 1 TO N(I, 1)
11550 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
11555 LET G = N(G, 8)
11560 NEXT J
11565 CALL "pos": N(), I, P$
11570 IF M(I, 4) = 1 THEN 11585
11575 CALL "wr": X(), "ret " & P$ & " " & STR$(N(I, 1))
11580 GOTO 11600
11585 CALL "wr": X(), "tret " & P$
11590 GOTO 11600
11595 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
11600 SUBEND
11605 REM ---- em_expr: expression E in post-order (= node order); M(J,8) < 0 marks a node where the
11610 REM writing jumps past node -M(J,8): a powk exponent, the literal 2^63 under neg, or the callee
11615 REM of printf (whose arguments are written between the format pieces, em_printf) ----------
11620 SUB "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
11625 LET J = M(E, 0)
11630 IF J > E THEN 11695
11635 IF M(J, 8) >= 0 THEN 11665
11640 LET G = -M(J, 8)
11645 IF N(G, 0) <> 35 THEN 11655
11650 CALL "em_printf": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
11655 LET J = G + 1
11660 GOTO 11630
11665 IF N(J, 0) <> 30 THEN 11680
11670 IF N(N(J, 9), 0) <> 35 THEN 11680
11675 IF N(N(J, 9), 7) = J THEN 11685
11680 CALL "em_node": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
11685 LET J = J + 1
11690 GOTO 11630
11695 SUBEND
11700 REM ---- em_node: the record of expression node J, then its cvt if any (DESIGN 3.5.5) ---------
11705 SUB "em_node": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
11710 CALL "pos": N(), J, P$
11715 CALL "tyr": T(), W(), X(), M(J, 1), A$
11720 LET Q$ = " " & P$ & " " & A$
11725 LET K = N(J, 0)
11730 IF K < 25 THEN 12085
11735 ON K - 24 GOTO 11740, 11785, 11805, 11820, 11830, 11840, 12085, 11895, 11950, 11960, 12015, 12085, 12050, 12060, 12085, 12085, 12070, 12085, 12085, 12085, 12085, 12085, 12085, 12085, 12080
11740 LET H = M(J, 5)
11745 IF M(J, 1) = 4 THEN 11765
11750 CALL "LMFMT": C(H, 1), C(H, 2), C(H, 3), C(H, 4), B$
11755 CALL "wr": X(), "ci" & Q$ & " " & B$
11760 GOTO 12085
11765 CALL "FEFRI": C(H, 1), C(H, 2), C(H, 3), C(H, 4), R3, R2, R1, R0, Z
11770 CALL "LMHEX": R3, R2, R1, R0, B$
11775 CALL "wr": X(), "cf" & Q$ & " " & B$
11780 GOTO 12085
11785 LET H = M(J, 5)
11790 CALL "LMHEX": C(H, 1), C(H, 2), C(H, 3), C(H, 4), B$
11795 CALL "wr": X(), "cf" & Q$ & " " & B$
11800 GOTO 12085
11805 CALL "io_esc": S$(N(J, 6)), 0, B$
11810 CALL "wr": X(), "cs" & Q$ & " " & B$
11815 GOTO 12085
11820 CALL "wr": X(), "cb" & Q$ & " 1"
11825 GOTO 12085
11830 CALL "wr": X(), "cb" & Q$ & " 0"
11835 GOTO 12085
11840 LET S = M(J, 2)
11845 IF S < 0 THEN 11875
11850 IF Y(S, 0) = 2 THEN 11865
11855 CALL "wr": X(), "lv" & Q$ & " " & STR$(Y(S, 5))
11860 GOTO 12085
11865 CALL "wr": X(), "cref" & Q$ & " " & STR$(Y(S, 5))
11870 GOTO 12085
11875 REM pi inf nan eps (DESIGN 3.5.5)
11880 LET B$ = SEG$("400921FB54442D187FF00000000000007FF80000000000003CB0000000000000", 16 * (-S) - 15, 16 * (-S))
11885 CALL "wr": X(), "cf" & Q$ & " #" & B$
11890 GOTO 12085
11895 LET G = N(J, 7)
11900 IF M(G, 8) >= 0 THEN 11940
11905 IF N(G, 0) <> 25 THEN 11940
11910 REM -2^63 as one constant (DESIGN 3.5.5)
11915 IF M(J, 1) = 4 THEN 11930
11920 CALL "wr": X(), "ci" & Q$ & " #8000000000000000"
11925 GOTO 12085
11930 CALL "wr": X(), "cf" & Q$ & " #C3E0000000000000"
11935 GOTO 12085
11940 CALL "wr": X(), "un" & Q$ & " neg"
11945 GOTO 12085
11950 CALL "wr": X(), "un" & Q$ & " not"
11955 GOTO 12085
11960 IF M(J, 8) > 0 THEN 12005
11965 LET O = N(J, 1)
11970 LET L$ = "add    sub    mul    div    mod    pow    matmul eq     ne     lt     le     gt     ge     band   bor    and    or     "
11975 LET B$ = SEG$(L$, 7 * O - 6, 7 * O - 1)
11980 LET H = POS(B$, " ")
11985 IF H = 0 THEN 11995
11990 LET B$ = SEG$(B$, 1, H - 1)
11995 CALL "wr": X(), "bin" & Q$ & " " & B$
12000 GOTO 12085
12005 CALL "wr": X(), "powk" & Q$ & " " & STR$(M(J, 8) - 10)
12010 GOTO 12085
12015 LET S = M(N(J, 7), 2)
12020 IF S < 0 THEN 12035
12025 CALL "wr": X(), "call" & Q$ & " " & STR$(Y(S, 5)) & " " & STR$(N(J, 1))
12030 GOTO 12085
12035 CALL "io_esc": S$(N(N(J, 7), 6)), 0, B$
12040 CALL "wr": X(), "lib" & Q$ & " " & B$ & " " & STR$(N(J, 1))
12045 GOTO 12085
12050 CALL "wr": X(), "rarg" & Q$
12055 GOTO 12085
12060 CALL "wr": X(), "lib" & Q$ & " " & SEG$("f64i64", 3 * N(J, 1) - 2, 3 * N(J, 1)) & " 1"
12065 GOTO 12085
12070 CALL "wr": X(), "rng" & Q$ & " " & STR$(N(J, 1)) & " " & STR$(N(J, 2))
12075 GOTO 12085
12080 CALL "wr": X(), "ifx" & Q$
12085 IF M(J, 7) <> 1 THEN 12095
12090 CALL "wr": X(), "cvt " & P$ & " 4"
12095 SUBEND
12100 REM ---- em_printf: printf call G: its format as fmt/ftext/fconv pieces at the position of the
12105 REM format literal, each conversion over its argument, then lib printf (DESIGN 3.5.5) --------
12110 SUB "em_printf": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
12115 DIM P(4100, 6)
12120 LET F = N(N(G, 7), 8)
12125 LET F$ = S$(N(F, 6))
12130 CALL "fmtp": F$, P(), N0, E, E$
12135 CALL "pos": N(), F, P$
12140 LET A = N(F, 8)
12145 FOR K = 1 TO P(0, 0)
12150 IF P(K, 0) = 2 THEN 12220
12155 REM a text piece, %% written as %
12160 LET T$ = ""
12165 LET I = P(K, 1)
12170 IF I > P(K, 2) THEN 12205
12175 LET C$ = SEG$(F$, I, I)
12180 LET T$ = T$ & C$
12185 LET I = I + 1
12190 IF C$ <> "%" THEN 12170
12195 LET I = I + 1
12200 GOTO 12170
12205 CALL "io_esc": T$, 0, B$
12210 CALL "wr": X(), "ftext " & P$ & " 1 " & B$
12215 GOTO 12310
12220 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), A
12225 LET A = N(A, 8)
12230 LET B$ = ""
12235 LET H = P(K, 3)
12240 FOR J = 1 TO 5
12245 IF H - 2 * INT(H / 2) = 0 THEN 12255
12250 LET B$ = B$ & SEG$("lpsza", J, J)
12255 LET H = INT(H / 2)
12260 NEXT J
12265 IF B$ <> "" THEN 12275
12270 LET B$ = "-"
12275 LET W$ = "-"
12280 IF P(K, 4) < 0 THEN 12290
12285 LET W$ = STR$(P(K, 4))
12290 LET R$ = "-"
12295 IF P(K, 5) < 0 THEN 12305
12300 LET R$ = STR$(P(K, 5))
12305 CALL "wr": X(), "fconv " & P$ & " 1 " & B$ & " " & W$ & " " & R$ & " " & SEG$(F$, P(K, 2), P(K, 2))
12310 NEXT K
12315 CALL "wr": X(), "fmt " & P$ & " 1 " & STR$(P(0, 0))
12320 CALL "pos": N(), G, P$
12325 CALL "wr": X(), "lib " & P$ & " 1 printf 1"
12330 SUBEND
