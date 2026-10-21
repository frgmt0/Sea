11175 REM ---- sc_emit: sea.hir1 (DESIGN 3.5): the type table, the constants, the functions. The
11180 REM records are produced twice: mode 1 (X(27) = 1) only numbers the types in order of first
11185 REM reference (3.5.1), mode 2 writes the table and then every record. ----------------------
11190 SUB "sc_emit": N(), M(), Y(), T(), W(), C(), S$(), X(), X$()
11195 LET X(28) = 0
11200 FOR H = 1 TO 2
11205 LET X(27) = H
11210 IF H = 1 THEN 11280
11215 FOR J = 1 TO X(28)
11220 LET Q = W(180000 + J)
11225 IF T(Q, 0) = 7 THEN 11245
11230 CALL "tyr": T(), W(), X(), T(Q, 1), A$
11235 CALL "wr": X(), "tvec " & STR$(9 + J) & " " & A$
11240 GOTO 11275
11245 LET L$ = "ttuple " & STR$(9 + J) & " " & STR$(T(Q, 1))
11250 FOR K = 1 TO T(Q, 1)
11255 CALL "tyr": T(), W(), X(), T(Q + 1 + INT((K - 1) / 9), K - 1 - 9 * INT((K - 1) / 9)), A$
11260 LET L$ = L$ & " " & A$
11265 NEXT K
11270 CALL "wr": X(), L$
11275 NEXT J
11280 FOR S = 2 TO X(33)
11285 IF Y(S, 0) <> 2 THEN 11335
11290 LET F = Y(S, 3)
11295 LET E = N(F, 7)
11300 IF N(F, 1) = 0 THEN 11310
11305 LET E = N(E, 8)
11310 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
11315 CALL "tyr": T(), W(), X(), Y(S, 2), A$
11320 CALL "io_esc": S$(Y(S, 1)), 0, B$
11325 CALL "pos": N(), F, P$
11330 CALL "wr": X(), "cn " & STR$(Y(S, 5)) & " " & B$ & " " & A$ & " " & P$
11335 NEXT S
11340 CALL "em_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), 1
11345 FOR S = 2 TO X(33)
11350 IF Y(S, 0) <> 1 THEN 11360
11355 CALL "em_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
11360 NEXT S
11365 NEXT H
11370 SUBEND
11375 REM ---- wr: one record of sea.hir1 (mode 2 only) ---------------------------------------------
11380 SUB "wr": X(), L$
11385 IF X(27) <> 2 THEN 11395
11390 PRINT #2, L$
11395 SUBEND
11400 REM ---- tyr: R$ = the written id of type Q; in mode 1 a type not yet numbered gets the next id,
11405 REM after its components (DESIGN 3.5.1); W(180000+j) = the type with id 9+j ----------------
11410 SUB "tyr": T(), W(), X(), Q, R$
11415 IF Q >= 10 THEN 11430
11420 LET R$ = STR$(Q)
11425 GOTO 11485
11430 IF T(Q, 9) > 0 THEN 11480
11435 IF T(Q, 0) = 7 THEN 11450
11440 CALL "tyr": T(), W(), X(), T(Q, 1), A$
11445 GOTO 11465
11450 FOR J = 1 TO T(Q, 1)
11455 CALL "tyr": T(), W(), X(), T(Q + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9)), A$
11460 NEXT J
11465 LET X(28) = X(28) + 1
11470 LET T(Q, 9) = X(28) + 9
11475 LET W(180000 + X(28)) = Q
11480 LET R$ = STR$(T(Q, 9))
11485 SUBEND
11490 REM ---- em_fn: function S (1 = .main): fn, par and loc records, the body, end (DESIGN 3.5.4) ---
11495 SUB "em_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
11500 LET F = Y(S, 3)
11505 LET P0 = Y(S, 6)
11510 LET L0 = Y(S, 8) - Y(S, 9) + 1 - P0
11515 IF S > 1 THEN 11535
11520 LET P$ = STR$(X(18)) & ":1:1"
11525 CALL "wr": X(), "fn 1 .main main 1 0 " & STR$(L0) & " " & P$
11530 GOTO 11555
11535 CALL "tyr": T(), W(), X(), Y(S, 2), A$
11540 CALL "io_esc": S$(Y(S, 1)), 0, B$
11545 CALL "pos": N(), F, P$
11550 CALL "wr": X(), "fn " & STR$(Y(S, 5)) & " " & B$ & " fn " & A$ & " " & STR$(P0) & " " & STR$(L0) & " " & P$
11555 FOR R = Y(S, 9) TO Y(S, 8)
11560 CALL "tyr": T(), W(), X(), Y(R, 2), A$
11565 CALL "io_esc": S$(Y(R, 1)), 0, B$
11570 LET U = Y(R, 4)
11575 IF U < 4 THEN 11590
11580 CALL "wr": X(), "par " & B$ & " " & A$ & " " & SEG$("valref", 3 * U - 11, 3 * U - 9)
11585 GOTO 11625
11590 CALL "pos": N(), Y(R, 3), C$
11595 IF U <> 3 THEN 11620
11600 REM a loop variable: the npos of its for (N(i,1..2), DESIGN 3.4, 3.5.4)
11605 LET I = Y(R, 3)
11610 LET G = INT(N(I, 1) / 1E9)
11615 LET C$ = STR$(G) & ":" & STR$(N(I, 1) - G * 1E9) & ":" & STR$(N(I, 2))
11620 CALL "wr": X(), "loc " & B$ & " " & A$ & " " & SEG$("let var for", 4 * U - 3, 4 * U - 1) & " " & C$
11625 NEXT R
11630 IF S > 1 THEN 11690
11635 LET I = N(X(17), 7)
11640 IF I = 0 THEN 11680
11645 LET K = N(I, 0)
11650 IF K = 2 THEN 11670
11655 IF K = 3 THEN 11670
11660 IF K = 5 THEN 11670
11665 CALL "em_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
11670 LET I = N(I, 8)
11675 GOTO 11640
11680 CALL "wr": X(), "block " & P$ & " " & STR$(X(29))
11685 GOTO 11715
11690 LET I = N(F, 7)
11695 FOR J = 1 TO P0 + Y(S, 7)
11700 LET I = N(I, 8)
11705 NEXT J
11710 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
11715 CALL "wr": X(), "end"
11720 SUBEND
11725 REM ---- em_blk: block B and its statements ---------------------------------------------------
11730 SUB "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
11735 LET I = N(B, 7)
11740 IF I = 0 THEN 11760
11745 CALL "em_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
11750 LET I = N(I, 8)
11755 GOTO 11740
11760 CALL "pos": N(), B, P$
11765 CALL "wr": X(), "block " & P$ & " " & STR$(N(B, 1))
11770 SUBEND
11775 REM ---- em_st: statement I (DESIGN 3.5.5) -------------------------------------------------
11780 SUB "em_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
11785 LET K = N(I, 0)
11790 LET G = N(I, 7)
11795 IF K < 8 THEN 12280
11800 IF K > 24 THEN 12280
11805 ON K - 7 GOTO 11810, 11810, 12280, 12280, 12280, 11920, 11950, 12040, 12060, 12145, 12170, 12280, 12280, 12195, 12210, 12225, 12275
11810 LET E = N(G, 8)
11815 IF N(I, 1) = 0 THEN 11825
11820 LET E = N(E, 8)
11825 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
11830 CALL "pos": N(), I, P$
11835 IF N(G, 0) = 10 THEN 11900
11840 IF N(G, 0) = 11 THEN 11910
11845 LET L$ = "tbind " & P$ & " " & STR$(N(G, 1))
11850 LET Q = N(G, 7)
11855 IF Q = 0 THEN 11890
11860 IF N(Q, 0) = 10 THEN 11875
11865 LET L$ = L$ & " -"
11870 GOTO 11880
11875 LET L$ = L$ & " " & STR$(Y(M(Q, 2), 5))
11880 LET Q = N(Q, 8)
11885 GOTO 11855
11890 CALL "wr": X(), L$
11895 GOTO 12280
11900 CALL "wr": X(), "bind " & P$ & " " & STR$(Y(M(G, 2), 5))
11905 GOTO 12280
11910 CALL "wr": X(), "eval " & P$
11915 GOTO 12280
11920 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
11925 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(G, 8)
11930 CALL "pos": N(), I, P$
11935 LET O = N(I, 1)
11940 CALL "wr": X(), "asg " & P$ & " " & SEG$("set add sub mul div", 4 * O - 3, 4 * O - 1)
11945 GOTO 12280
11950 LET L$ = ""
11955 FOR J = 1 TO N(I, 1)
11960 REM the cv flag of each target: 1 converts an i64 result to an f64 target (DESIGN 3.5.5)
11965 LET L1 = 0
11970 IF N(G, 0) = 11 THEN 11980
11975 LET L1 = M(G, 4)
11980 LET L$ = L$ & " " & STR$(L1)
11985 IF N(G, 0) = 11 THEN 12000
11990 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
11995 GOTO 12010
12000 CALL "pos": N(), G, P$
12005 CALL "wr": X(), "skip " & P$ & " 1"
12010 LET G = N(G, 8)
12015 NEXT J
12020 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
12025 CALL "pos": N(), I, P$
12030 CALL "wr": X(), "tasg " & P$ & " " & STR$(N(I, 1)) & L$
12035 GOTO 12280
12040 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
12045 CALL "pos": N(), I, P$
12050 CALL "wr": X(), "eval " & P$
12055 GOTO 12280
12060 REM an else-if chain without recursion: each link's condition and block, the final else block,
12065 REM then the if records from the last link back to the first (post-order)
12070 LET L1 = I
12075 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(L1, 7)
12080 LET B = N(N(L1, 7), 8)
12085 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
12090 IF N(L1, 1) = 0 THEN 12120
12095 LET B = N(B, 8)
12100 IF N(B, 0) = 24 THEN 12115
12105 LET L1 = B
12110 GOTO 12075
12115 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
12120 CALL "pos": N(), L1, P$
12125 CALL "wr": X(), "if " & P$ & " " & STR$(N(L1, 1))
12130 IF L1 = I THEN 12280
12135 LET L1 = N(L1, 9)
12140 GOTO 12120
12145 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
12150 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(G, 8)
12155 CALL "pos": N(), I, P$
12160 CALL "wr": X(), "while " & P$
12165 GOTO 12280
12170 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
12175 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(G, 8)
12180 CALL "pos": N(), I, P$
12185 CALL "wr": X(), "forr " & P$ & " " & STR$(Y(M(I, 2), 5))
12190 GOTO 12280
12195 CALL "pos": N(), I, P$
12200 CALL "wr": X(), "break " & P$
12205 GOTO 12280
12210 CALL "pos": N(), I, P$
12215 CALL "wr": X(), "cont " & P$
12220 GOTO 12280
12225 FOR J = 1 TO N(I, 1)
12230 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
12235 LET G = N(G, 8)
12240 NEXT J
12245 CALL "pos": N(), I, P$
12250 IF M(I, 4) = 1 THEN 12265
12255 CALL "wr": X(), "ret " & P$ & " " & STR$(N(I, 1))
12260 GOTO 12280
12265 CALL "wr": X(), "tret " & P$
12270 GOTO 12280
12275 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
12280 SUBEND
12285 REM ---- em_expr: expression E in post-order (= node order); M(J,8) < 0 marks a node where the
12290 REM writing jumps past node -M(J,8): a powk exponent, the literal 2^63 under neg, or the callee
12295 REM of printf (whose arguments are written between the format pieces, em_printf) ----------
12300 SUB "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
12305 LET J = M(E, 0)
12310 IF J > E THEN 12375
12315 IF M(J, 8) >= 0 THEN 12345
12320 LET G = -M(J, 8)
12325 IF N(G, 0) <> 35 THEN 12335
12330 CALL "em_printf": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
12335 LET J = G + 1
12340 GOTO 12310
12345 IF N(J, 0) <> 30 THEN 12360
12350 IF N(N(J, 9), 0) <> 35 THEN 12360
12355 IF N(N(J, 9), 7) = J THEN 12365
12360 CALL "em_node": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
12365 LET J = J + 1
12370 GOTO 12310
12375 SUBEND
12380 REM ---- em_node: the record of expression node J, then its cvt if any (DESIGN 3.5.5) ---------
12385 SUB "em_node": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
12390 CALL "pos": N(), J, P$
12395 CALL "tyr": T(), W(), X(), M(J, 1), A$
12400 LET Q$ = " " & P$ & " " & A$
12405 LET K = N(J, 0)
12410 IF K < 25 THEN 12765
12415 ON K - 24 GOTO 12420, 12465, 12485, 12500, 12510, 12520, 12765, 12575, 12630, 12640, 12695, 12765, 12730, 12740, 12765, 12765, 12750, 12765, 12765, 12765, 12765, 12765, 12765, 12765, 12760
12420 LET H = M(J, 5)
12425 IF M(J, 1) = 4 THEN 12445
12430 CALL "LMFMT": C(H, 1), C(H, 2), C(H, 3), C(H, 4), B$
12435 CALL "wr": X(), "ci" & Q$ & " " & B$
12440 GOTO 12765
12445 CALL "FEFRI": C(H, 1), C(H, 2), C(H, 3), C(H, 4), R3, R2, R1, R0, Z
12450 CALL "LMHEX": R3, R2, R1, R0, B$
12455 CALL "wr": X(), "cf" & Q$ & " " & B$
12460 GOTO 12765
12465 LET H = M(J, 5)
12470 CALL "LMHEX": C(H, 1), C(H, 2), C(H, 3), C(H, 4), B$
12475 CALL "wr": X(), "cf" & Q$ & " " & B$
12480 GOTO 12765
12485 CALL "io_esc": S$(N(J, 6)), 0, B$
12490 CALL "wr": X(), "cs" & Q$ & " " & B$
12495 GOTO 12765
12500 CALL "wr": X(), "cb" & Q$ & " 1"
12505 GOTO 12765
12510 CALL "wr": X(), "cb" & Q$ & " 0"
12515 GOTO 12765
12520 LET S = M(J, 2)
12525 IF S < 0 THEN 12555
12530 IF Y(S, 0) = 2 THEN 12545
12535 CALL "wr": X(), "lv" & Q$ & " " & STR$(Y(S, 5))
12540 GOTO 12765
12545 CALL "wr": X(), "cref" & Q$ & " " & STR$(Y(S, 5))
12550 GOTO 12765
12555 REM pi inf nan eps (DESIGN 3.5.5)
12560 LET B$ = SEG$("400921FB54442D187FF00000000000007FF80000000000003CB0000000000000", 16 * (-S) - 15, 16 * (-S))
12565 CALL "wr": X(), "cf" & Q$ & " #" & B$
12570 GOTO 12765
12575 LET G = N(J, 7)
12580 IF M(G, 8) >= 0 THEN 12620
12585 IF N(G, 0) <> 25 THEN 12620
12590 REM -2^63 as one constant (DESIGN 3.5.5)
12595 IF M(J, 1) = 4 THEN 12610
12600 CALL "wr": X(), "ci" & Q$ & " #8000000000000000"
12605 GOTO 12765
12610 CALL "wr": X(), "cf" & Q$ & " #C3E0000000000000"
12615 GOTO 12765
12620 CALL "wr": X(), "un" & Q$ & " neg"
12625 GOTO 12765
12630 CALL "wr": X(), "un" & Q$ & " not"
12635 GOTO 12765
12640 IF M(J, 8) > 0 THEN 12685
12645 LET O = N(J, 1)
12650 LET L$ = "add    sub    mul    div    mod    pow    matmul eq     ne     lt     le     gt     ge     band   bor    and    or     "
12655 LET B$ = SEG$(L$, 7 * O - 6, 7 * O - 1)
12660 LET H = POS(B$, " ")
12665 IF H = 0 THEN 12675
12670 LET B$ = SEG$(B$, 1, H - 1)
12675 CALL "wr": X(), "bin" & Q$ & " " & B$
12680 GOTO 12765
12685 CALL "wr": X(), "powk" & Q$ & " " & STR$(M(J, 8) - 10)
12690 GOTO 12765
12695 LET S = M(N(J, 7), 2)
12700 IF S < 0 THEN 12715
12705 CALL "wr": X(), "call" & Q$ & " " & STR$(Y(S, 5)) & " " & STR$(N(J, 1))
12710 GOTO 12765
12715 CALL "io_esc": S$(N(N(J, 7), 6)), 0, B$
12720 CALL "wr": X(), "lib" & Q$ & " " & B$ & " " & STR$(N(J, 1))
12725 GOTO 12765
12730 CALL "wr": X(), "rarg" & Q$
12735 GOTO 12765
12740 CALL "wr": X(), "lib" & Q$ & " " & SEG$("f64i64", 3 * N(J, 1) - 2, 3 * N(J, 1)) & " 1"
12745 GOTO 12765
12750 CALL "wr": X(), "rng" & Q$ & " " & STR$(N(J, 1)) & " " & STR$(N(J, 2))
12755 GOTO 12765
12760 CALL "wr": X(), "ifx" & Q$
12765 IF M(J, 7) <> 1 THEN 12775
12770 CALL "wr": X(), "cvt " & P$ & " 4"
12775 SUBEND
12780 REM ---- em_printf: printf call G: its format as fmt/ftext/fconv pieces at the position of the
12785 REM format literal, each conversion over its argument, then lib printf (DESIGN 3.5.5) --------
12790 SUB "em_printf": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
12795 DIM P(4100, 6)
12800 LET F = N(N(G, 7), 8)
12805 LET F$ = S$(N(F, 6))
12810 CALL "fmtp": F$, P(), N0, E, E$, X(35)
12815 CALL "pos": N(), F, P$
12820 LET A = N(F, 8)
12825 FOR K = 1 TO P(0, 0)
12830 IF P(K, 0) = 2 THEN 12900
12835 REM a text piece, %% written as %
12840 LET T$ = ""
12845 LET I = P(K, 1)
12850 IF I > P(K, 2) THEN 12885
12855 LET C$ = SEG$(F$, I, I)
12860 LET T$ = T$ & C$
12865 LET I = I + 1
12870 IF C$ <> "%" THEN 12850
12875 LET I = I + 1
12880 GOTO 12850
12885 CALL "io_esc": T$, 0, B$
12890 CALL "wr": X(), "ftext " & P$ & " 1 " & B$
12895 GOTO 12990
12900 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), A
12905 LET A = N(A, 8)
12910 LET B$ = ""
12915 LET H = P(K, 3)
12920 FOR J = 1 TO 5
12925 IF H - 2 * INT(H / 2) = 0 THEN 12935
12930 LET B$ = B$ & SEG$("lpsza", J, J)
12935 LET H = INT(H / 2)
12940 NEXT J
12945 IF B$ <> "" THEN 12955
12950 LET B$ = "-"
12955 LET W$ = "-"
12960 IF P(K, 4) < 0 THEN 12970
12965 LET W$ = STR$(P(K, 4))
12970 LET R$ = "-"
12975 IF P(K, 5) < 0 THEN 12985
12980 LET R$ = STR$(P(K, 5))
12985 CALL "wr": X(), "fconv " & P$ & " 1 " & B$ & " " & W$ & " " & R$ & " " & SEG$(F$, P(K, 2), P(K, 2))
12990 NEXT K
12995 CALL "wr": X(), "fmt " & P$ & " 1 " & STR$(P(0, 0))
13000 CALL "pos": N(), G, P$
13005 CALL "wr": X(), "lib " & P$ & " 1 printf 1"
13010 SUBEND
