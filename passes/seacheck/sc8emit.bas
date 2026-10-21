12310 REM ---- sc_emit: sea.hir1 (DESIGN 3.5): the type table, the constants, the functions. The
12315 REM records are produced twice: mode 1 (X(27) = 1) only numbers the types in order of first
12320 REM reference (3.5.1), mode 2 writes the table and then every record. ----------------------
12325 SUB "sc_emit": N(), M(), Y(), T(), W(), C(), S$(), X(), X$()
12330 LET X(28) = 0
12335 FOR H = 1 TO 2
12340 LET X(27) = H
12345 IF H = 1 THEN 12415
12350 FOR J = 1 TO X(28)
12355 LET Q = W(180000 + J)
12360 IF T(Q, 0) = 7 THEN 12380
12365 CALL "tyr": T(), W(), X(), T(Q, 1), A$
12370 CALL "wr": X(), "tvec " & STR$(9 + J) & " " & A$
12375 GOTO 12410
12380 LET L$ = "ttuple " & STR$(9 + J) & " " & STR$(T(Q, 1))
12385 FOR K = 1 TO T(Q, 1)
12390 CALL "tyr": T(), W(), X(), T(Q + 1 + INT((K - 1) / 9), K - 1 - 9 * INT((K - 1) / 9)), A$
12395 LET L$ = L$ & " " & A$
12400 NEXT K
12405 CALL "wr": X(), L$
12410 NEXT J
12415 FOR S = 2 TO X(33)
12420 IF Y(S, 0) <> 2 THEN 12530
12425 LET F = Y(S, 3)
12430 LET E = N(F, 7)
12435 IF N(F, 1) = 0 THEN 12445
12440 LET E = N(E, 8)
12445 REM the value as one leaf at the position of the expression's root (DESIGN 3.5.2)
12450 CALL "pos": N(), E, P$
12455 CALL "tyr": T(), W(), X(), Y(S, 2), A$
12460 LET R = Y(S, 8)
12465 IF Y(S, 7) = 3 THEN 12505
12470 IF Y(S, 7) = 2 THEN 12490
12475 CALL "LMFMT": C(R, 1), C(R, 2), C(R, 3), C(R, 4), B$
12480 CALL "wr": X(), "ci " & P$ & " " & A$ & " " & B$
12485 GOTO 12510
12490 CALL "LMHEX": C(R, 1), C(R, 2), C(R, 3), C(R, 4), B$
12495 CALL "wr": X(), "cf " & P$ & " " & A$ & " " & B$
12500 GOTO 12510
12505 CALL "wr": X(), "cb " & P$ & " " & A$ & " " & STR$(R)
12510 CALL "tyr": T(), W(), X(), Y(S, 2), A$
12515 CALL "io_esc": S$(Y(S, 1)), 0, B$
12520 CALL "pos": N(), F, P$
12525 CALL "wr": X(), "cn " & STR$(Y(S, 5)) & " " & B$ & " " & A$ & " " & P$
12530 NEXT S
12535 CALL "em_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), 1
12540 FOR S = 2 TO X(33)
12545 IF Y(S, 0) <> 1 THEN 12555
12550 CALL "em_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
12555 NEXT S
12560 NEXT H
12565 SUBEND
12570 REM ---- wr: one record of sea.hir1 (mode 2 only) ---------------------------------------------
12575 SUB "wr": X(), L$
12580 IF X(27) <> 2 THEN 12590
12585 PRINT #2, L$
12590 SUBEND
12595 REM ---- tyr: R$ = the written id of type Q; in mode 1 a type not yet numbered gets the next id,
12600 REM after its components (DESIGN 3.5.1); W(180000+j) = the type with id 9+j ----------------
12605 SUB "tyr": T(), W(), X(), Q, R$
12610 IF Q >= 10 THEN 12625
12615 LET R$ = STR$(Q)
12620 GOTO 12680
12625 IF T(Q, 9) > 0 THEN 12675
12630 IF T(Q, 0) = 7 THEN 12645
12635 CALL "tyr": T(), W(), X(), T(Q, 1), A$
12640 GOTO 12660
12645 FOR J = 1 TO T(Q, 1)
12650 CALL "tyr": T(), W(), X(), T(Q + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9)), A$
12655 NEXT J
12660 LET X(28) = X(28) + 1
12665 LET T(Q, 9) = X(28) + 9
12670 LET W(180000 + X(28)) = Q
12675 LET R$ = STR$(T(Q, 9))
12680 SUBEND
12685 REM ---- em_fn: function S (1 = .main): fn, par and loc records, the body, end (DESIGN 3.5.4) ---
12690 SUB "em_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
12695 LET F = Y(S, 3)
12700 LET P0 = Y(S, 6)
12705 LET L0 = Y(S, 8) - Y(S, 9) + 1 - P0
12710 IF S > 1 THEN 12730
12715 LET P$ = STR$(X(18)) & ":1:1"
12720 CALL "wr": X(), "fn 1 .main main 1 0 " & STR$(L0) & " " & P$
12725 GOTO 12750
12730 CALL "tyr": T(), W(), X(), Y(S, 2), A$
12735 CALL "io_esc": S$(Y(S, 1)), 0, B$
12740 CALL "pos": N(), F, P$
12745 CALL "wr": X(), "fn " & STR$(Y(S, 5)) & " " & B$ & " fn " & A$ & " " & STR$(P0) & " " & STR$(L0) & " " & P$
12750 FOR R = Y(S, 9) TO Y(S, 8)
12755 CALL "tyr": T(), W(), X(), Y(R, 2), A$
12760 CALL "io_esc": S$(Y(R, 1)), 0, B$
12765 LET U = Y(R, 4)
12770 IF U < 4 THEN 12785
12775 CALL "wr": X(), "par " & B$ & " " & A$ & " " & SEG$("valref", 3 * U - 11, 3 * U - 9)
12780 GOTO 12820
12785 CALL "pos": N(), Y(R, 3), C$
12790 IF U <> 3 THEN 12815
12795 REM a loop variable: the npos of its for (N(i,1..2), DESIGN 3.4, 3.5.4)
12800 LET I = Y(R, 3)
12805 LET G = INT(N(I, 1) / 1E9)
12810 LET C$ = STR$(G) & ":" & STR$(N(I, 1) - G * 1E9) & ":" & STR$(N(I, 2))
12815 CALL "wr": X(), "loc " & B$ & " " & A$ & " " & SEG$("let var for", 4 * U - 3, 4 * U - 1) & " " & C$
12820 NEXT R
12825 IF S > 1 THEN 12885
12830 LET I = N(X(17), 7)
12835 IF I = 0 THEN 12875
12840 LET K = N(I, 0)
12845 IF K = 2 THEN 12865
12850 IF K = 3 THEN 12865
12855 IF K = 5 THEN 12865
12860 CALL "em_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
12865 LET I = N(I, 8)
12870 GOTO 12835
12875 CALL "wr": X(), "block " & P$ & " " & STR$(X(29))
12880 GOTO 12910
12885 LET I = N(F, 7)
12890 FOR J = 1 TO P0 + Y(S, 7)
12895 LET I = N(I, 8)
12900 NEXT J
12905 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
12910 CALL "wr": X(), "end"
12915 SUBEND
12920 REM ---- em_blk: block B and its statements ---------------------------------------------------
12925 SUB "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
12930 LET I = N(B, 7)
12935 IF I = 0 THEN 12955
12940 CALL "em_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
12945 LET I = N(I, 8)
12950 GOTO 12935
12955 CALL "pos": N(), B, P$
12960 CALL "wr": X(), "block " & P$ & " " & STR$(N(B, 1))
12965 SUBEND
12970 REM ---- em_st: statement I (DESIGN 3.5.5) -------------------------------------------------
12975 SUB "em_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
12980 LET K = N(I, 0)
12985 LET G = N(I, 7)
12990 IF K < 8 THEN 13475
12995 IF K > 24 THEN 13475
13000 ON K - 7 GOTO 13005, 13005, 13475, 13475, 13475, 13115, 13145, 13235, 13255, 13340, 13365, 13475, 13475, 13390, 13405, 13420, 13470
13005 LET E = N(G, 8)
13010 IF N(I, 1) = 0 THEN 13020
13015 LET E = N(E, 8)
13020 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
13025 CALL "pos": N(), I, P$
13030 IF N(G, 0) = 10 THEN 13095
13035 IF N(G, 0) = 11 THEN 13105
13040 LET L$ = "tbind " & P$ & " " & STR$(N(G, 1))
13045 LET Q = N(G, 7)
13050 IF Q = 0 THEN 13085
13055 IF N(Q, 0) = 10 THEN 13070
13060 LET L$ = L$ & " -"
13065 GOTO 13075
13070 LET L$ = L$ & " " & STR$(Y(M(Q, 2), 5))
13075 LET Q = N(Q, 8)
13080 GOTO 13050
13085 CALL "wr": X(), L$
13090 GOTO 13475
13095 CALL "wr": X(), "bind " & P$ & " " & STR$(Y(M(G, 2), 5))
13100 GOTO 13475
13105 CALL "wr": X(), "eval " & P$
13110 GOTO 13475
13115 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
13120 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(G, 8)
13125 CALL "pos": N(), I, P$
13130 LET O = N(I, 1)
13135 CALL "wr": X(), "asg " & P$ & " " & SEG$("set add sub mul div", 4 * O - 3, 4 * O - 1)
13140 GOTO 13475
13145 LET L$ = ""
13150 FOR J = 1 TO N(I, 1)
13155 REM the cv flag of each target: 1 converts an i64 result to an f64 target (DESIGN 3.5.5)
13160 LET L1 = 0
13165 IF N(G, 0) = 11 THEN 13175
13170 LET L1 = M(G, 4)
13175 LET L$ = L$ & " " & STR$(L1)
13180 IF N(G, 0) = 11 THEN 13195
13185 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
13190 GOTO 13205
13195 CALL "pos": N(), G, P$
13200 CALL "wr": X(), "skip " & P$ & " 1"
13205 LET G = N(G, 8)
13210 NEXT J
13215 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
13220 CALL "pos": N(), I, P$
13225 CALL "wr": X(), "tasg " & P$ & " " & STR$(N(I, 1)) & L$
13230 GOTO 13475
13235 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
13240 CALL "pos": N(), I, P$
13245 CALL "wr": X(), "eval " & P$
13250 GOTO 13475
13255 REM an else-if chain without recursion: each link's condition and block, the final else block,
13260 REM then the if records from the last link back to the first (post-order)
13265 LET L1 = I
13270 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(L1, 7)
13275 LET B = N(N(L1, 7), 8)
13280 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
13285 IF N(L1, 1) = 0 THEN 13315
13290 LET B = N(B, 8)
13295 IF N(B, 0) = 24 THEN 13310
13300 LET L1 = B
13305 GOTO 13270
13310 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
13315 CALL "pos": N(), L1, P$
13320 CALL "wr": X(), "if " & P$ & " " & STR$(N(L1, 1))
13325 IF L1 = I THEN 13475
13330 LET L1 = N(L1, 9)
13335 GOTO 13315
13340 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
13345 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(G, 8)
13350 CALL "pos": N(), I, P$
13355 CALL "wr": X(), "while " & P$
13360 GOTO 13475
13365 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
13370 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(G, 8)
13375 CALL "pos": N(), I, P$
13380 CALL "wr": X(), "forr " & P$ & " " & STR$(Y(M(I, 2), 5))
13385 GOTO 13475
13390 CALL "pos": N(), I, P$
13395 CALL "wr": X(), "break " & P$
13400 GOTO 13475
13405 CALL "pos": N(), I, P$
13410 CALL "wr": X(), "cont " & P$
13415 GOTO 13475
13420 FOR J = 1 TO N(I, 1)
13425 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
13430 LET G = N(G, 8)
13435 NEXT J
13440 CALL "pos": N(), I, P$
13445 IF M(I, 4) = 1 THEN 13460
13450 CALL "wr": X(), "ret " & P$ & " " & STR$(N(I, 1))
13455 GOTO 13475
13460 CALL "wr": X(), "tret " & P$
13465 GOTO 13475
13470 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
13475 SUBEND
13480 REM ---- em_expr: expression E in post-order (= node order); M(J,8) < 0 marks a node where the
13485 REM writing jumps past node -M(J,8): a powk exponent, the literal 2^63 under neg, or the callee
13490 REM of printf (whose arguments are written between the format pieces, em_printf) ----------
13495 SUB "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
13500 LET J = M(E, 0)
13505 IF J > E THEN 13570
13510 IF M(J, 8) >= 0 THEN 13540
13515 LET G = -M(J, 8)
13520 IF N(G, 0) <> 35 THEN 13530
13525 CALL "em_printf": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
13530 LET J = G + 1
13535 GOTO 13505
13540 IF N(J, 0) <> 30 THEN 13555
13545 IF N(N(J, 9), 0) <> 35 THEN 13555
13550 IF N(N(J, 9), 7) = J THEN 13560
13555 CALL "em_node": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
13560 LET J = J + 1
13565 GOTO 13505
13570 SUBEND
13575 REM ---- em_node: the record of expression node J, then its cvt if any (DESIGN 3.5.5) ---------
13580 SUB "em_node": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
13585 CALL "pos": N(), J, P$
13590 CALL "tyr": T(), W(), X(), M(J, 1), A$
13595 LET Q$ = " " & P$ & " " & A$
13600 LET K = N(J, 0)
13605 IF K < 25 THEN 13960
13610 ON K - 24 GOTO 13615, 13660, 13680, 13695, 13705, 13715, 13960, 13770, 13825, 13835, 13890, 13960, 13925, 13935, 13960, 13960, 13945, 13960, 13960, 13960, 13960, 13960, 13960, 13960, 13955
13615 LET H = M(J, 5)
13620 IF M(J, 1) = 4 THEN 13640
13625 CALL "LMFMT": C(H, 1), C(H, 2), C(H, 3), C(H, 4), B$
13630 CALL "wr": X(), "ci" & Q$ & " " & B$
13635 GOTO 13960
13640 CALL "FEFRI": C(H, 1), C(H, 2), C(H, 3), C(H, 4), R3, R2, R1, R0, Z
13645 CALL "LMHEX": R3, R2, R1, R0, B$
13650 CALL "wr": X(), "cf" & Q$ & " " & B$
13655 GOTO 13960
13660 LET H = M(J, 5)
13665 CALL "LMHEX": C(H, 1), C(H, 2), C(H, 3), C(H, 4), B$
13670 CALL "wr": X(), "cf" & Q$ & " " & B$
13675 GOTO 13960
13680 CALL "io_esc": S$(N(J, 6)), 0, B$
13685 CALL "wr": X(), "cs" & Q$ & " " & B$
13690 GOTO 13960
13695 CALL "wr": X(), "cb" & Q$ & " 1"
13700 GOTO 13960
13705 CALL "wr": X(), "cb" & Q$ & " 0"
13710 GOTO 13960
13715 LET S = M(J, 2)
13720 IF S < 0 THEN 13750
13725 IF Y(S, 0) = 2 THEN 13740
13730 CALL "wr": X(), "lv" & Q$ & " " & STR$(Y(S, 5))
13735 GOTO 13960
13740 CALL "wr": X(), "cref" & Q$ & " " & STR$(Y(S, 5))
13745 GOTO 13960
13750 REM pi inf nan eps (DESIGN 3.5.5)
13755 LET B$ = SEG$("400921FB54442D187FF00000000000007FF80000000000003CB0000000000000", 16 * (-S) - 15, 16 * (-S))
13760 CALL "wr": X(), "cf" & Q$ & " #" & B$
13765 GOTO 13960
13770 LET G = N(J, 7)
13775 IF M(G, 8) >= 0 THEN 13815
13780 IF N(G, 0) <> 25 THEN 13815
13785 REM -2^63 as one constant (DESIGN 3.5.5)
13790 IF M(J, 1) = 4 THEN 13805
13795 CALL "wr": X(), "ci" & Q$ & " #8000000000000000"
13800 GOTO 13960
13805 CALL "wr": X(), "cf" & Q$ & " #C3E0000000000000"
13810 GOTO 13960
13815 CALL "wr": X(), "un" & Q$ & " neg"
13820 GOTO 13960
13825 CALL "wr": X(), "un" & Q$ & " not"
13830 GOTO 13960
13835 IF M(J, 8) > 0 THEN 13880
13840 LET O = N(J, 1)
13845 LET L$ = "add    sub    mul    div    mod    pow    matmul eq     ne     lt     le     gt     ge     band   bor    and    or     "
13850 LET B$ = SEG$(L$, 7 * O - 6, 7 * O - 1)
13855 LET H = POS(B$, " ")
13860 IF H = 0 THEN 13870
13865 LET B$ = SEG$(B$, 1, H - 1)
13870 CALL "wr": X(), "bin" & Q$ & " " & B$
13875 GOTO 13960
13880 CALL "wr": X(), "powk" & Q$ & " " & STR$(M(J, 8) - 10)
13885 GOTO 13960
13890 LET S = M(N(J, 7), 2)
13895 IF S < 0 THEN 13910
13900 CALL "wr": X(), "call" & Q$ & " " & STR$(Y(S, 5)) & " " & STR$(N(J, 1))
13905 GOTO 13960
13910 CALL "io_esc": S$(N(N(J, 7), 6)), 0, B$
13915 CALL "wr": X(), "lib" & Q$ & " " & B$ & " " & STR$(N(J, 1))
13920 GOTO 13960
13925 CALL "wr": X(), "rarg" & Q$
13930 GOTO 13960
13935 CALL "wr": X(), "lib" & Q$ & " " & SEG$("f64i64", 3 * N(J, 1) - 2, 3 * N(J, 1)) & " 1"
13940 GOTO 13960
13945 CALL "wr": X(), "rng" & Q$ & " " & STR$(N(J, 1)) & " " & STR$(N(J, 2))
13950 GOTO 13960
13955 CALL "wr": X(), "ifx" & Q$
13960 IF M(J, 7) <> 1 THEN 13970
13965 CALL "wr": X(), "cvt " & P$ & " 4"
13970 SUBEND
13975 REM ---- em_printf: printf call G: its format as fmt/ftext/fconv pieces at the position of the
13980 REM format literal, each conversion over its argument, then lib printf (DESIGN 3.5.5) --------
13985 SUB "em_printf": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
13990 DIM P(4100, 6)
13995 LET F = N(N(G, 7), 8)
14000 LET F$ = S$(N(F, 6))
14005 CALL "fmtp": F$, P(), N0, E, E$, X(35)
14010 CALL "pos": N(), F, P$
14015 LET A = N(F, 8)
14020 FOR K = 1 TO P(0, 0)
14025 IF P(K, 0) = 2 THEN 14095
14030 REM a text piece, %% written as %
14035 LET T$ = ""
14040 LET I = P(K, 1)
14045 IF I > P(K, 2) THEN 14080
14050 LET C$ = SEG$(F$, I, I)
14055 LET T$ = T$ & C$
14060 LET I = I + 1
14065 IF C$ <> "%" THEN 14045
14070 LET I = I + 1
14075 GOTO 14045
14080 CALL "io_esc": T$, 0, B$
14085 CALL "wr": X(), "ftext " & P$ & " 1 " & B$
14090 GOTO 14185
14095 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), A
14100 LET A = N(A, 8)
14105 LET B$ = ""
14110 LET H = P(K, 3)
14115 FOR J = 1 TO 5
14120 IF H - 2 * INT(H / 2) = 0 THEN 14130
14125 LET B$ = B$ & SEG$("lpsza", J, J)
14130 LET H = INT(H / 2)
14135 NEXT J
14140 IF B$ <> "" THEN 14150
14145 LET B$ = "-"
14150 LET W$ = "-"
14155 IF P(K, 4) < 0 THEN 14165
14160 LET W$ = STR$(P(K, 4))
14165 LET R$ = "-"
14170 IF P(K, 5) < 0 THEN 14180
14175 LET R$ = STR$(P(K, 5))
14180 CALL "wr": X(), "fconv " & P$ & " 1 " & B$ & " " & W$ & " " & R$ & " " & SEG$(F$, P(K, 2), P(K, 2))
14185 NEXT K
14190 CALL "wr": X(), "fmt " & P$ & " 1 " & STR$(P(0, 0))
14195 CALL "pos": N(), G, P$
14200 CALL "wr": X(), "lib " & P$ & " 1 printf 1"
14205 SUBEND
