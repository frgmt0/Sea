12360 REM ---- sc_emit: sea.hir1 (DESIGN 3.5): the type table, the constants, the functions. The
12365 REM records are produced twice: mode 1 (X(27) = 1) only numbers the types in order of first
12370 REM reference (3.5.1), mode 2 writes the table and then every record. ----------------------
12375 SUB "sc_emit": N(), M(), Y(), T(), W(), C(), S$(), X(), X$()
12380 LET X(28) = 0
12385 FOR H = 1 TO 2
12390 LET X(27) = H
12395 IF H = 1 THEN 12465
12400 FOR J = 1 TO X(28)
12405 LET Q = W(180000 + J)
12410 IF T(Q, 0) = 7 THEN 12430
12415 CALL "tyr": T(), W(), X(), T(Q, 1), A$
12420 CALL "wr": X(), "tvec " & STR$(9 + J) & " " & A$
12425 GOTO 12460
12430 LET L$ = "ttuple " & STR$(9 + J) & " " & STR$(T(Q, 1))
12435 FOR K = 1 TO T(Q, 1)
12440 CALL "tyr": T(), W(), X(), T(Q + 1 + INT((K - 1) / 9), K - 1 - 9 * INT((K - 1) / 9)), A$
12445 LET L$ = L$ & " " & A$
12450 NEXT K
12455 CALL "wr": X(), L$
12460 NEXT J
12465 FOR S = 2 TO X(33)
12470 IF Y(S, 0) <> 2 THEN 12580
12475 LET F = Y(S, 3)
12480 LET E = N(F, 7)
12485 IF N(F, 1) = 0 THEN 12495
12490 LET E = N(E, 8)
12495 REM the value as one leaf at the position of the expression's root (DESIGN 3.5.2)
12500 CALL "pos": N(), E, P$
12505 CALL "tyr": T(), W(), X(), Y(S, 2), A$
12510 LET R = Y(S, 8)
12515 IF Y(S, 7) = 3 THEN 12555
12520 IF Y(S, 7) = 2 THEN 12540
12525 CALL "LMFMT": C(R, 1), C(R, 2), C(R, 3), C(R, 4), B$
12530 CALL "wr": X(), "ci " & P$ & " " & A$ & " " & B$
12535 GOTO 12560
12540 CALL "LMHEX": C(R, 1), C(R, 2), C(R, 3), C(R, 4), B$
12545 CALL "wr": X(), "cf " & P$ & " " & A$ & " " & B$
12550 GOTO 12560
12555 CALL "wr": X(), "cb " & P$ & " " & A$ & " " & STR$(R)
12560 CALL "tyr": T(), W(), X(), Y(S, 2), A$
12565 CALL "io_esc": S$(Y(S, 1)), 0, B$
12570 CALL "pos": N(), F, P$
12575 CALL "wr": X(), "cn " & STR$(Y(S, 5)) & " " & B$ & " " & A$ & " " & P$
12580 NEXT S
12585 CALL "em_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), 1
12590 FOR S = 2 TO X(33)
12595 IF Y(S, 0) <> 1 THEN 12605
12600 CALL "em_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
12605 NEXT S
12610 NEXT H
12615 SUBEND
12620 REM ---- wr: one record of sea.hir1 (mode 2 only) ---------------------------------------------
12625 SUB "wr": X(), L$
12630 IF X(27) <> 2 THEN 12640
12635 PRINT #2, L$
12640 SUBEND
12645 REM ---- tyr: R$ = the written id of type Q; in mode 1 a type not yet numbered gets the next id,
12650 REM after its components (DESIGN 3.5.1); W(180000+j) = the type with id 9+j ----------------
12655 SUB "tyr": T(), W(), X(), Q, R$
12660 IF Q >= 10 THEN 12675
12665 LET R$ = STR$(Q)
12670 GOTO 12730
12675 IF T(Q, 9) > 0 THEN 12725
12680 IF T(Q, 0) = 7 THEN 12695
12685 CALL "tyr": T(), W(), X(), T(Q, 1), A$
12690 GOTO 12710
12695 FOR J = 1 TO T(Q, 1)
12700 CALL "tyr": T(), W(), X(), T(Q + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9)), A$
12705 NEXT J
12710 LET X(28) = X(28) + 1
12715 LET T(Q, 9) = X(28) + 9
12720 LET W(180000 + X(28)) = Q
12725 LET R$ = STR$(T(Q, 9))
12730 SUBEND
12735 REM ---- em_fn: function S (1 = .main): fn, par and loc records, the body, end (DESIGN 3.5.4) ---
12740 SUB "em_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
12745 LET F = Y(S, 3)
12750 LET P0 = Y(S, 6)
12755 LET L0 = Y(S, 8) - Y(S, 9) + 1 - P0
12760 IF S > 1 THEN 12780
12765 LET P$ = STR$(X(18)) & ":1:1"
12770 CALL "wr": X(), "fn 1 .main main 1 0 " & STR$(L0) & " " & P$
12775 GOTO 12800
12780 CALL "tyr": T(), W(), X(), Y(S, 2), A$
12785 CALL "io_esc": S$(Y(S, 1)), 0, B$
12790 CALL "pos": N(), F, P$
12795 CALL "wr": X(), "fn " & STR$(Y(S, 5)) & " " & B$ & " fn " & A$ & " " & STR$(P0) & " " & STR$(L0) & " " & P$
12800 FOR R = Y(S, 9) TO Y(S, 8)
12805 CALL "tyr": T(), W(), X(), Y(R, 2), A$
12810 CALL "io_esc": S$(Y(R, 1)), 0, B$
12815 LET U = Y(R, 4)
12820 IF U < 4 THEN 12835
12825 CALL "wr": X(), "par " & B$ & " " & A$ & " " & SEG$("valref", 3 * U - 11, 3 * U - 9)
12830 GOTO 12870
12835 CALL "pos": N(), Y(R, 3), C$
12840 IF U <> 3 THEN 12865
12845 REM a loop variable: the npos of its for (N(i,1..2), DESIGN 3.4, 3.5.4)
12850 LET I = Y(R, 3)
12855 LET G = INT(N(I, 1) / 1E9)
12860 LET C$ = STR$(G) & ":" & STR$(N(I, 1) - G * 1E9) & ":" & STR$(N(I, 2))
12865 CALL "wr": X(), "loc " & B$ & " " & A$ & " " & SEG$("let var for", 4 * U - 3, 4 * U - 1) & " " & C$
12870 NEXT R
12875 IF S > 1 THEN 12935
12880 LET I = N(X(17), 7)
12885 IF I = 0 THEN 12925
12890 LET K = N(I, 0)
12895 IF K = 2 THEN 12915
12900 IF K = 3 THEN 12915
12905 IF K = 5 THEN 12915
12910 CALL "em_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
12915 LET I = N(I, 8)
12920 GOTO 12885
12925 CALL "wr": X(), "block " & P$ & " " & STR$(X(29))
12930 GOTO 12960
12935 LET I = N(F, 7)
12940 FOR J = 1 TO P0 + Y(S, 7)
12945 LET I = N(I, 8)
12950 NEXT J
12955 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
12960 CALL "wr": X(), "end"
12965 SUBEND
12970 REM ---- em_blk: block B and its statements ---------------------------------------------------
12975 SUB "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
12980 LET I = N(B, 7)
12985 IF I = 0 THEN 13005
12990 CALL "em_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
12995 LET I = N(I, 8)
13000 GOTO 12985
13005 CALL "pos": N(), B, P$
13010 CALL "wr": X(), "block " & P$ & " " & STR$(N(B, 1))
13015 SUBEND
13020 REM ---- em_st: statement I (DESIGN 3.5.5) -------------------------------------------------
13025 SUB "em_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
13030 LET K = N(I, 0)
13035 LET G = N(I, 7)
13040 IF K < 8 THEN 13525
13045 IF K > 24 THEN 13525
13050 ON K - 7 GOTO 13055, 13055, 13525, 13525, 13525, 13165, 13195, 13285, 13305, 13390, 13415, 13525, 13525, 13440, 13455, 13470, 13520
13055 LET E = N(G, 8)
13060 IF N(I, 1) = 0 THEN 13070
13065 LET E = N(E, 8)
13070 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
13075 CALL "pos": N(), I, P$
13080 IF N(G, 0) = 10 THEN 13145
13085 IF N(G, 0) = 11 THEN 13155
13090 LET L$ = "tbind " & P$ & " " & STR$(N(G, 1))
13095 LET Q = N(G, 7)
13100 IF Q = 0 THEN 13135
13105 IF N(Q, 0) = 10 THEN 13120
13110 LET L$ = L$ & " -"
13115 GOTO 13125
13120 LET L$ = L$ & " " & STR$(Y(M(Q, 2), 5))
13125 LET Q = N(Q, 8)
13130 GOTO 13100
13135 CALL "wr": X(), L$
13140 GOTO 13525
13145 CALL "wr": X(), "bind " & P$ & " " & STR$(Y(M(G, 2), 5))
13150 GOTO 13525
13155 CALL "wr": X(), "eval " & P$
13160 GOTO 13525
13165 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
13170 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(G, 8)
13175 CALL "pos": N(), I, P$
13180 LET O = N(I, 1)
13185 CALL "wr": X(), "asg " & P$ & " " & SEG$("set add sub mul div", 4 * O - 3, 4 * O - 1)
13190 GOTO 13525
13195 LET L$ = ""
13200 FOR J = 1 TO N(I, 1)
13205 REM the cv flag of each target: 1 converts an i64 result to an f64 target (DESIGN 3.5.5)
13210 LET L1 = 0
13215 IF N(G, 0) = 11 THEN 13225
13220 LET L1 = M(G, 4)
13225 LET L$ = L$ & " " & STR$(L1)
13230 IF N(G, 0) = 11 THEN 13245
13235 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
13240 GOTO 13255
13245 CALL "pos": N(), G, P$
13250 CALL "wr": X(), "skip " & P$ & " 1"
13255 LET G = N(G, 8)
13260 NEXT J
13265 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
13270 CALL "pos": N(), I, P$
13275 CALL "wr": X(), "tasg " & P$ & " " & STR$(N(I, 1)) & L$
13280 GOTO 13525
13285 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
13290 CALL "pos": N(), I, P$
13295 CALL "wr": X(), "eval " & P$
13300 GOTO 13525
13305 REM an else-if chain without recursion: each link's condition and block, the final else block,
13310 REM then the if records from the last link back to the first (post-order)
13315 LET L1 = I
13320 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(L1, 7)
13325 LET B = N(N(L1, 7), 8)
13330 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
13335 IF N(L1, 1) = 0 THEN 13365
13340 LET B = N(B, 8)
13345 IF N(B, 0) = 24 THEN 13360
13350 LET L1 = B
13355 GOTO 13320
13360 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
13365 CALL "pos": N(), L1, P$
13370 CALL "wr": X(), "if " & P$ & " " & STR$(N(L1, 1))
13375 IF L1 = I THEN 13525
13380 LET L1 = N(L1, 9)
13385 GOTO 13365
13390 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
13395 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(G, 8)
13400 CALL "pos": N(), I, P$
13405 CALL "wr": X(), "while " & P$
13410 GOTO 13525
13415 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
13420 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(G, 8)
13425 CALL "pos": N(), I, P$
13430 CALL "wr": X(), "forr " & P$ & " " & STR$(Y(M(I, 2), 5))
13435 GOTO 13525
13440 CALL "pos": N(), I, P$
13445 CALL "wr": X(), "break " & P$
13450 GOTO 13525
13455 CALL "pos": N(), I, P$
13460 CALL "wr": X(), "cont " & P$
13465 GOTO 13525
13470 FOR J = 1 TO N(I, 1)
13475 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
13480 LET G = N(G, 8)
13485 NEXT J
13490 CALL "pos": N(), I, P$
13495 IF M(I, 4) = 1 THEN 13510
13500 CALL "wr": X(), "ret " & P$ & " " & STR$(N(I, 1))
13505 GOTO 13525
13510 CALL "wr": X(), "tret " & P$
13515 GOTO 13525
13520 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
13525 SUBEND
13530 REM ---- em_expr: expression E in post-order (= node order); M(J,8) < 0 marks a node where the
13535 REM writing jumps past node -M(J,8): a powk exponent, the literal 2^63 under neg, or the callee
13540 REM of printf (whose arguments are written between the format pieces, em_printf) ----------
13545 SUB "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
13550 LET J = M(E, 0)
13555 IF J > E THEN 13620
13560 IF M(J, 8) >= 0 THEN 13590
13565 LET G = -M(J, 8)
13570 IF N(G, 0) <> 35 THEN 13580
13575 CALL "em_printf": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
13580 LET J = G + 1
13585 GOTO 13555
13590 IF N(J, 0) <> 30 THEN 13605
13595 IF N(N(J, 9), 0) <> 35 THEN 13605
13600 IF N(N(J, 9), 7) = J THEN 13610
13605 CALL "em_node": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
13610 LET J = J + 1
13615 GOTO 13555
13620 SUBEND
13625 REM ---- em_node: the record of expression node J, then its cvt if any (DESIGN 3.5.5) ---------
13630 SUB "em_node": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
13635 CALL "pos": N(), J, P$
13640 CALL "tyr": T(), W(), X(), M(J, 1), A$
13645 LET Q$ = " " & P$ & " " & A$
13650 LET K = N(J, 0)
13655 IF K < 25 THEN 14010
13660 ON K - 24 GOTO 13665, 13710, 13730, 13745, 13755, 13765, 14010, 13820, 13875, 13885, 13940, 14010, 13975, 13985, 14010, 14010, 13995, 14010, 14010, 14010, 14010, 14010, 14010, 14010, 14005
13665 LET H = M(J, 5)
13670 IF M(J, 1) = 4 THEN 13690
13675 CALL "LMFMT": C(H, 1), C(H, 2), C(H, 3), C(H, 4), B$
13680 CALL "wr": X(), "ci" & Q$ & " " & B$
13685 GOTO 14010
13690 CALL "FEFRI": C(H, 1), C(H, 2), C(H, 3), C(H, 4), R3, R2, R1, R0, Z
13695 CALL "LMHEX": R3, R2, R1, R0, B$
13700 CALL "wr": X(), "cf" & Q$ & " " & B$
13705 GOTO 14010
13710 LET H = M(J, 5)
13715 CALL "LMHEX": C(H, 1), C(H, 2), C(H, 3), C(H, 4), B$
13720 CALL "wr": X(), "cf" & Q$ & " " & B$
13725 GOTO 14010
13730 CALL "io_esc": S$(N(J, 6)), 0, B$
13735 CALL "wr": X(), "cs" & Q$ & " " & B$
13740 GOTO 14010
13745 CALL "wr": X(), "cb" & Q$ & " 1"
13750 GOTO 14010
13755 CALL "wr": X(), "cb" & Q$ & " 0"
13760 GOTO 14010
13765 LET S = M(J, 2)
13770 IF S < 0 THEN 13800
13775 IF Y(S, 0) = 2 THEN 13790
13780 CALL "wr": X(), "lv" & Q$ & " " & STR$(Y(S, 5))
13785 GOTO 14010
13790 CALL "wr": X(), "cref" & Q$ & " " & STR$(Y(S, 5))
13795 GOTO 14010
13800 REM pi inf nan eps (DESIGN 3.5.5)
13805 LET B$ = SEG$("400921FB54442D187FF00000000000007FF80000000000003CB0000000000000", 16 * (-S) - 15, 16 * (-S))
13810 CALL "wr": X(), "cf" & Q$ & " #" & B$
13815 GOTO 14010
13820 LET G = N(J, 7)
13825 IF M(G, 8) >= 0 THEN 13865
13830 IF N(G, 0) <> 25 THEN 13865
13835 REM -2^63 as one constant (DESIGN 3.5.5)
13840 IF M(J, 1) = 4 THEN 13855
13845 CALL "wr": X(), "ci" & Q$ & " #8000000000000000"
13850 GOTO 14010
13855 CALL "wr": X(), "cf" & Q$ & " #C3E0000000000000"
13860 GOTO 14010
13865 CALL "wr": X(), "un" & Q$ & " neg"
13870 GOTO 14010
13875 CALL "wr": X(), "un" & Q$ & " not"
13880 GOTO 14010
13885 IF M(J, 8) > 0 THEN 13930
13890 LET O = N(J, 1)
13895 LET L$ = "add    sub    mul    div    mod    pow    matmul eq     ne     lt     le     gt     ge     band   bor    and    or     "
13900 LET B$ = SEG$(L$, 7 * O - 6, 7 * O - 1)
13905 LET H = POS(B$, " ")
13910 IF H = 0 THEN 13920
13915 LET B$ = SEG$(B$, 1, H - 1)
13920 CALL "wr": X(), "bin" & Q$ & " " & B$
13925 GOTO 14010
13930 CALL "wr": X(), "powk" & Q$ & " " & STR$(M(J, 8) - 10)
13935 GOTO 14010
13940 LET S = M(N(J, 7), 2)
13945 IF S < 0 THEN 13960
13950 CALL "wr": X(), "call" & Q$ & " " & STR$(Y(S, 5)) & " " & STR$(N(J, 1))
13955 GOTO 14010
13960 CALL "io_esc": S$(N(N(J, 7), 6)), 0, B$
13965 CALL "wr": X(), "lib" & Q$ & " " & B$ & " " & STR$(N(J, 1))
13970 GOTO 14010
13975 CALL "wr": X(), "rarg" & Q$
13980 GOTO 14010
13985 CALL "wr": X(), "lib" & Q$ & " " & SEG$("f64i64", 3 * N(J, 1) - 2, 3 * N(J, 1)) & " 1"
13990 GOTO 14010
13995 CALL "wr": X(), "rng" & Q$ & " " & STR$(N(J, 1)) & " " & STR$(N(J, 2))
14000 GOTO 14010
14005 CALL "wr": X(), "ifx" & Q$
14010 IF M(J, 7) <> 1 THEN 14020
14015 CALL "wr": X(), "cvt " & P$ & " 4"
14020 SUBEND
14025 REM ---- em_printf: printf call G: its format as fmt/ftext/fconv pieces at the position of the
14030 REM format literal, each conversion over its argument, then lib printf (DESIGN 3.5.5) --------
14035 SUB "em_printf": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
14040 DIM P(4100, 6)
14045 LET F = N(N(G, 7), 8)
14050 LET F$ = S$(N(F, 6))
14055 CALL "fmtp": F$, P(), N0, E, E$, X(35)
14060 CALL "pos": N(), F, P$
14065 LET A = N(F, 8)
14070 FOR K = 1 TO P(0, 0)
14075 IF P(K, 0) = 2 THEN 14145
14080 REM a text piece, %% written as %
14085 LET T$ = ""
14090 LET I = P(K, 1)
14095 IF I > P(K, 2) THEN 14130
14100 LET C$ = SEG$(F$, I, I)
14105 LET T$ = T$ & C$
14110 LET I = I + 1
14115 IF C$ <> "%" THEN 14095
14120 LET I = I + 1
14125 GOTO 14095
14130 CALL "io_esc": T$, 0, B$
14135 CALL "wr": X(), "ftext " & P$ & " 1 " & B$
14140 GOTO 14235
14145 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), A
14150 LET A = N(A, 8)
14155 LET B$ = ""
14160 LET H = P(K, 3)
14165 FOR J = 1 TO 5
14170 IF H - 2 * INT(H / 2) = 0 THEN 14180
14175 LET B$ = B$ & SEG$("lpsza", J, J)
14180 LET H = INT(H / 2)
14185 NEXT J
14190 IF B$ <> "" THEN 14200
14195 LET B$ = "-"
14200 LET W$ = "-"
14205 IF P(K, 4) < 0 THEN 14215
14210 LET W$ = STR$(P(K, 4))
14215 LET R$ = "-"
14220 IF P(K, 5) < 0 THEN 14230
14225 LET R$ = STR$(P(K, 5))
14230 CALL "wr": X(), "fconv " & P$ & " 1 " & B$ & " " & W$ & " " & R$ & " " & SEG$(F$, P(K, 2), P(K, 2))
14235 NEXT K
14240 CALL "wr": X(), "fmt " & P$ & " 1 " & STR$(P(0, 0))
14245 CALL "pos": N(), G, P$
14250 CALL "wr": X(), "lib " & P$ & " 1 printf 1"
14255 SUBEND
