12430 REM ---- sc_emit: sea.hir1 (DESIGN 3.5): the type table, the constants, the functions. The
12435 REM records are produced twice: mode 1 (X(27) = 1) only numbers the types in order of first
12440 REM reference (3.5.1), mode 2 writes the table and then every record. ----------------------
12445 SUB "sc_emit": N(), M(), Y(), T(), W(), C(), S$(), X(), X$()
12450 LET X(28) = 0
12455 FOR H = 1 TO 2
12460 LET X(27) = H
12465 IF H = 1 THEN 12535
12470 FOR J = 1 TO X(28)
12475 LET Q = W(180000 + J)
12480 IF T(Q, 0) = 7 THEN 12500
12485 CALL "tyr": T(), W(), X(), T(Q, 1), A$
12490 CALL "wr": X(), "tvec " & STR$(9 + J) & " " & A$
12495 GOTO 12530
12500 LET L$ = "ttuple " & STR$(9 + J) & " " & STR$(T(Q, 1))
12505 FOR K = 1 TO T(Q, 1)
12510 CALL "tyr": T(), W(), X(), T(Q + 1 + INT((K - 1) / 9), K - 1 - 9 * INT((K - 1) / 9)), A$
12515 LET L$ = L$ & " " & A$
12520 NEXT K
12525 CALL "wr": X(), L$
12530 NEXT J
12535 FOR S = 2 TO X(33)
12540 IF Y(S, 0) <> 2 THEN 12650
12545 LET F = Y(S, 3)
12550 LET E = N(F, 7)
12555 IF N(F, 1) = 0 THEN 12565
12560 LET E = N(E, 8)
12565 REM the value as one leaf at the position of the expression's root (DESIGN 3.5.2)
12570 CALL "pos": N(), E, P$
12575 CALL "tyr": T(), W(), X(), Y(S, 2), A$
12580 LET R = Y(S, 8)
12585 IF Y(S, 7) = 3 THEN 12625
12590 IF Y(S, 7) = 2 THEN 12610
12595 CALL "lfmt": C(R, 1), C(R, 2), C(R, 3), C(R, 4), B$
12600 CALL "wr": X(), "ci " & P$ & " " & A$ & " " & B$
12605 GOTO 12630
12610 CALL "lhex": C(R, 1), C(R, 2), C(R, 3), C(R, 4), B$
12615 CALL "wr": X(), "cf " & P$ & " " & A$ & " " & B$
12620 GOTO 12630
12625 CALL "wr": X(), "cb " & P$ & " " & A$ & " " & STR$(R)
12630 CALL "tyr": T(), W(), X(), Y(S, 2), A$
12635 CALL "io_esc": S$(Y(S, 1)), 0, B$
12640 CALL "pos": N(), F, P$
12645 CALL "wr": X(), "cn " & STR$(Y(S, 5)) & " " & B$ & " " & A$ & " " & P$
12650 NEXT S
12655 CALL "em_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), 1
12660 FOR S = 2 TO X(33)
12665 IF Y(S, 0) <> 1 THEN 12675
12670 CALL "em_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
12675 NEXT S
12680 NEXT H
12685 SUBEND
12690 REM ---- wr: one record of sea.hir1 (mode 2 only) ---------------------------------------------
12695 SUB "wr": X(), L$
12700 IF X(27) <> 2 THEN 12710
12705 PRINT #2, L$
12710 SUBEND
12715 REM ---- tyr: R$ = the written id of type Q; in mode 1 a type not yet numbered gets the next id,
12720 REM after its components (DESIGN 3.5.1); W(180000+j) = the type with id 9+j ----------------
12725 SUB "tyr": T(), W(), X(), Q, R$
12730 IF Q >= 10 THEN 12745
12735 LET R$ = STR$(Q)
12740 GOTO 12800
12745 IF T(Q, 9) > 0 THEN 12795
12750 IF T(Q, 0) = 7 THEN 12765
12755 CALL "tyr": T(), W(), X(), T(Q, 1), A$
12760 GOTO 12780
12765 FOR J = 1 TO T(Q, 1)
12770 CALL "tyr": T(), W(), X(), T(Q + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9)), A$
12775 NEXT J
12780 LET X(28) = X(28) + 1
12785 LET T(Q, 9) = X(28) + 9
12790 LET W(180000 + X(28)) = Q
12795 LET R$ = STR$(T(Q, 9))
12800 SUBEND
12805 REM ---- em_fn: function S (1 = .main): fn, par and loc records, the body, end (DESIGN 3.5.4) ---
12810 SUB "em_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
12815 LET F = Y(S, 3)
12820 LET P0 = Y(S, 6)
12825 LET L0 = Y(S, 8) - Y(S, 9) + 1 - P0
12830 IF S > 1 THEN 12850
12835 LET P$ = STR$(X(18)) & ":1:1"
12840 CALL "wr": X(), "fn 1 .main main 1 0 " & STR$(L0) & " " & P$
12845 GOTO 12870
12850 CALL "tyr": T(), W(), X(), Y(S, 2), A$
12855 CALL "io_esc": S$(Y(S, 1)), 0, B$
12860 CALL "pos": N(), F, P$
12865 CALL "wr": X(), "fn " & STR$(Y(S, 5)) & " " & B$ & " fn " & A$ & " " & STR$(P0) & " " & STR$(L0) & " " & P$
12870 FOR R = Y(S, 9) TO Y(S, 8)
12875 CALL "tyr": T(), W(), X(), Y(R, 2), A$
12880 CALL "io_esc": S$(Y(R, 1)), 0, B$
12885 LET U = Y(R, 4)
12890 IF U < 4 THEN 12905
12895 CALL "wr": X(), "par " & B$ & " " & A$ & " " & SEG$("valref", 3 * U - 11, 3 * U - 9)
12900 GOTO 12940
12905 CALL "pos": N(), Y(R, 3), C$
12910 IF U <> 3 THEN 12935
12915 REM a loop variable: the npos of its for (N(i,1..2), DESIGN 3.4, 3.5.4)
12920 LET I = Y(R, 3)
12925 LET G = INT(N(I, 1) / 1E9)
12930 LET C$ = STR$(G) & ":" & STR$(N(I, 1) - G * 1E9) & ":" & STR$(N(I, 2))
12935 CALL "wr": X(), "loc " & B$ & " " & A$ & " " & SEG$("let var for", 4 * U - 3, 4 * U - 1) & " " & C$
12940 NEXT R
12945 IF S > 1 THEN 13005
12950 LET I = N(X(17), 7)
12955 IF I = 0 THEN 12995
12960 LET K = N(I, 0)
12965 IF K = 2 THEN 12985
12970 IF K = 3 THEN 12985
12975 IF K = 5 THEN 12985
12980 CALL "em_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
12985 LET I = N(I, 8)
12990 GOTO 12955
12995 CALL "wr": X(), "block " & P$ & " " & STR$(X(29))
13000 GOTO 13030
13005 LET I = N(F, 7)
13010 FOR J = 1 TO P0 + Y(S, 7)
13015 LET I = N(I, 8)
13020 NEXT J
13025 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
13030 CALL "wr": X(), "end"
13035 SUBEND
13040 REM ---- em_blk: block B and its statements ---------------------------------------------------
13045 SUB "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
13050 LET I = N(B, 7)
13055 IF I = 0 THEN 13075
13060 CALL "em_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
13065 LET I = N(I, 8)
13070 GOTO 13055
13075 CALL "pos": N(), B, P$
13080 CALL "wr": X(), "block " & P$ & " " & STR$(N(B, 1))
13085 SUBEND
13090 REM ---- em_st: statement I (DESIGN 3.5.5) -------------------------------------------------
13095 SUB "em_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
13100 LET K = N(I, 0)
13105 LET G = N(I, 7)
13110 IF K < 8 THEN 13595
13115 IF K > 24 THEN 13595
13120 ON K - 7 GOTO 13125, 13125, 13595, 13595, 13595, 13235, 13265, 13355, 13375, 13460, 13485, 13595, 13595, 13510, 13525, 13540, 13590
13125 LET E = N(G, 8)
13130 IF N(I, 1) = 0 THEN 13140
13135 LET E = N(E, 8)
13140 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
13145 CALL "pos": N(), I, P$
13150 IF N(G, 0) = 10 THEN 13215
13155 IF N(G, 0) = 11 THEN 13225
13160 LET L$ = "tbind " & P$ & " " & STR$(N(G, 1))
13165 LET Q = N(G, 7)
13170 IF Q = 0 THEN 13205
13175 IF N(Q, 0) = 10 THEN 13190
13180 LET L$ = L$ & " -"
13185 GOTO 13195
13190 LET L$ = L$ & " " & STR$(Y(M(Q, 2), 5))
13195 LET Q = N(Q, 8)
13200 GOTO 13170
13205 CALL "wr": X(), L$
13210 GOTO 13595
13215 CALL "wr": X(), "bind " & P$ & " " & STR$(Y(M(G, 2), 5))
13220 GOTO 13595
13225 CALL "wr": X(), "eval " & P$
13230 GOTO 13595
13235 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
13240 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(G, 8)
13245 CALL "pos": N(), I, P$
13250 LET O = N(I, 1)
13255 CALL "wr": X(), "asg " & P$ & " " & SEG$("set add sub mul div", 4 * O - 3, 4 * O - 1)
13260 GOTO 13595
13265 LET L$ = ""
13270 FOR J = 1 TO N(I, 1)
13275 REM the cv flag of each target: 1 converts an i64 result to an f64 target (DESIGN 3.5.5)
13280 LET L1 = 0
13285 IF N(G, 0) = 11 THEN 13295
13290 LET L1 = M(G, 4)
13295 LET L$ = L$ & " " & STR$(L1)
13300 IF N(G, 0) = 11 THEN 13315
13305 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
13310 GOTO 13325
13315 CALL "pos": N(), G, P$
13320 CALL "wr": X(), "skip " & P$ & " 1"
13325 LET G = N(G, 8)
13330 NEXT J
13335 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
13340 CALL "pos": N(), I, P$
13345 CALL "wr": X(), "tasg " & P$ & " " & STR$(N(I, 1)) & L$
13350 GOTO 13595
13355 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
13360 CALL "pos": N(), I, P$
13365 CALL "wr": X(), "eval " & P$
13370 GOTO 13595
13375 REM an else-if chain without recursion: each link's condition and block, the final else block,
13380 REM then the if records from the last link back to the first (post-order)
13385 LET L1 = I
13390 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(L1, 7)
13395 LET B = N(N(L1, 7), 8)
13400 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
13405 IF N(L1, 1) = 0 THEN 13435
13410 LET B = N(B, 8)
13415 IF N(B, 0) = 24 THEN 13430
13420 LET L1 = B
13425 GOTO 13390
13430 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
13435 CALL "pos": N(), L1, P$
13440 CALL "wr": X(), "if " & P$ & " " & STR$(N(L1, 1))
13445 IF L1 = I THEN 13595
13450 LET L1 = N(L1, 9)
13455 GOTO 13435
13460 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
13465 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(G, 8)
13470 CALL "pos": N(), I, P$
13475 CALL "wr": X(), "while " & P$
13480 GOTO 13595
13485 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
13490 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(G, 8)
13495 CALL "pos": N(), I, P$
13500 CALL "wr": X(), "forr " & P$ & " " & STR$(Y(M(I, 2), 5))
13505 GOTO 13595
13510 CALL "pos": N(), I, P$
13515 CALL "wr": X(), "break " & P$
13520 GOTO 13595
13525 CALL "pos": N(), I, P$
13530 CALL "wr": X(), "cont " & P$
13535 GOTO 13595
13540 FOR J = 1 TO N(I, 1)
13545 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
13550 LET G = N(G, 8)
13555 NEXT J
13560 CALL "pos": N(), I, P$
13565 IF M(I, 4) = 1 THEN 13580
13570 CALL "wr": X(), "ret " & P$ & " " & STR$(N(I, 1))
13575 GOTO 13595
13580 CALL "wr": X(), "tret " & P$
13585 GOTO 13595
13590 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
13595 SUBEND
13600 REM ---- em_expr: expression E in post-order (= node order); M(J,8) < 0 marks a node where the
13605 REM writing jumps past node -M(J,8): a powk exponent, the literal 2^63 under neg, or the callee
13610 REM of printf (whose arguments are written between the format pieces, em_printf) ----------
13615 SUB "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
13620 LET J = M(E, 0)
13625 IF J > E THEN 13690
13630 IF M(J, 8) >= 0 THEN 13660
13635 LET G = -M(J, 8)
13640 IF N(G, 0) <> 35 THEN 13650
13645 CALL "em_printf": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
13650 LET J = G + 1
13655 GOTO 13625
13660 IF N(J, 0) <> 30 THEN 13675
13665 IF N(N(J, 9), 0) <> 35 THEN 13675
13670 IF N(N(J, 9), 7) = J THEN 13680
13675 CALL "em_node": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
13680 LET J = J + 1
13685 GOTO 13625
13690 SUBEND
13695 REM ---- em_node: the record of expression node J, then its cvt if any (DESIGN 3.5.5) ---------
13700 SUB "em_node": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
13705 CALL "pos": N(), J, P$
13710 CALL "tyr": T(), W(), X(), M(J, 1), A$
13715 LET Q$ = " " & P$ & " " & A$
13720 LET K = N(J, 0)
13725 IF K < 25 THEN 14090
13730 ON K - 24 GOTO 13735, 13790, 13810, 13825, 13835, 13845, 14090, 13900, 13955, 13965, 14020, 14090, 14055, 14065, 14090, 14090, 14075, 14090, 14090, 14090, 14090, 14090, 14090, 14090, 14085
13735 LET H = M(J, 5)
13740 IF M(J, 1) = 4 THEN 13760
13745 CALL "lfmt": C(H, 1), C(H, 2), C(H, 3), C(H, 4), B$
13750 CALL "wr": X(), "ci" & Q$ & " " & B$
13755 GOTO 14090
13760 REM an int literal typed f64: the fv bits of its rint (exact, else NOT_EXACT_F64 was reported)
13765 LET R3 = INT(N(J, 1) / 65536)
13770 LET R1 = INT(N(J, 2) / 65536)
13775 CALL "lhex": R3, N(J, 1) - 65536 * R3, R1, N(J, 2) - 65536 * R1, B$
13780 CALL "wr": X(), "cf" & Q$ & " " & B$
13785 GOTO 14090
13790 LET H = M(J, 5)
13795 CALL "lhex": C(H, 1), C(H, 2), C(H, 3), C(H, 4), B$
13800 CALL "wr": X(), "cf" & Q$ & " " & B$
13805 GOTO 14090
13810 CALL "io_esc": S$(N(J, 6)), 0, B$
13815 CALL "wr": X(), "cs" & Q$ & " " & B$
13820 GOTO 14090
13825 CALL "wr": X(), "cb" & Q$ & " 1"
13830 GOTO 14090
13835 CALL "wr": X(), "cb" & Q$ & " 0"
13840 GOTO 14090
13845 LET S = M(J, 2)
13850 IF S < 0 THEN 13880
13855 IF Y(S, 0) = 2 THEN 13870
13860 CALL "wr": X(), "lv" & Q$ & " " & STR$(Y(S, 5))
13865 GOTO 14090
13870 CALL "wr": X(), "cref" & Q$ & " " & STR$(Y(S, 5))
13875 GOTO 14090
13880 REM pi inf nan eps (DESIGN 3.5.5)
13885 LET B$ = SEG$("400921FB54442D187FF00000000000007FF80000000000003CB0000000000000", 16 * (-S) - 15, 16 * (-S))
13890 CALL "wr": X(), "cf" & Q$ & " #" & B$
13895 GOTO 14090
13900 LET G = N(J, 7)
13905 IF M(G, 8) >= 0 THEN 13945
13910 IF N(G, 0) <> 25 THEN 13945
13915 REM -2^63 as one constant (DESIGN 3.5.5)
13920 IF M(J, 1) = 4 THEN 13935
13925 CALL "wr": X(), "ci" & Q$ & " #8000000000000000"
13930 GOTO 14090
13935 CALL "wr": X(), "cf" & Q$ & " #C3E0000000000000"
13940 GOTO 14090
13945 CALL "wr": X(), "un" & Q$ & " neg"
13950 GOTO 14090
13955 CALL "wr": X(), "un" & Q$ & " not"
13960 GOTO 14090
13965 IF M(J, 8) > 0 THEN 14010
13970 LET O = N(J, 1)
13975 LET L$ = "add    sub    mul    div    mod    pow    matmul eq     ne     lt     le     gt     ge     band   bor    and    or     "
13980 LET B$ = SEG$(L$, 7 * O - 6, 7 * O - 1)
13985 LET H = POS(B$, " ")
13990 IF H = 0 THEN 14000
13995 LET B$ = SEG$(B$, 1, H - 1)
14000 CALL "wr": X(), "bin" & Q$ & " " & B$
14005 GOTO 14090
14010 CALL "wr": X(), "powk" & Q$ & " " & STR$(M(J, 8) - 10)
14015 GOTO 14090
14020 LET S = M(N(J, 7), 2)
14025 IF S < 0 THEN 14040
14030 CALL "wr": X(), "call" & Q$ & " " & STR$(Y(S, 5)) & " " & STR$(N(J, 1))
14035 GOTO 14090
14040 CALL "io_esc": S$(N(N(J, 7), 6)), 0, B$
14045 CALL "wr": X(), "lib" & Q$ & " " & B$ & " " & STR$(N(J, 1))
14050 GOTO 14090
14055 CALL "wr": X(), "rarg" & Q$
14060 GOTO 14090
14065 CALL "wr": X(), "lib" & Q$ & " " & SEG$("f64i64", 3 * N(J, 1) - 2, 3 * N(J, 1)) & " 1"
14070 GOTO 14090
14075 CALL "wr": X(), "rng" & Q$ & " " & STR$(N(J, 1)) & " " & STR$(N(J, 2))
14080 GOTO 14090
14085 CALL "wr": X(), "ifx" & Q$
14090 IF M(J, 7) <> 1 THEN 14100
14095 CALL "wr": X(), "cvt " & P$ & " 4"
14100 SUBEND
14105 REM ---- em_printf: printf call G: its format as fmt/ftext/fconv pieces at the position of the
14110 REM format literal, each conversion over its argument, then lib printf (DESIGN 3.5.5) --------
14115 SUB "em_printf": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
14120 DIM P(4100, 6)
14125 LET F = N(N(G, 7), 8)
14130 LET F$ = S$(N(F, 6))
14135 CALL "fmtp": F$, P(), N0, E, E$, X(35)
14140 CALL "pos": N(), F, P$
14145 LET A = N(F, 8)
14150 FOR K = 1 TO P(0, 0)
14155 IF P(K, 0) = 2 THEN 14225
14160 REM a text piece, %% written as %
14165 LET T$ = ""
14170 LET I = P(K, 1)
14175 IF I > P(K, 2) THEN 14210
14180 LET C$ = SEG$(F$, I, I)
14185 LET T$ = T$ & C$
14190 LET I = I + 1
14195 IF C$ <> "%" THEN 14175
14200 LET I = I + 1
14205 GOTO 14175
14210 CALL "io_esc": T$, 0, B$
14215 CALL "wr": X(), "ftext " & P$ & " 1 " & B$
14220 GOTO 14315
14225 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), A
14230 LET A = N(A, 8)
14235 LET B$ = ""
14240 LET H = P(K, 3)
14245 FOR J = 1 TO 5
14250 IF H - 2 * INT(H / 2) = 0 THEN 14260
14255 LET B$ = B$ & SEG$("lpsza", J, J)
14260 LET H = INT(H / 2)
14265 NEXT J
14270 IF B$ <> "" THEN 14280
14275 LET B$ = "-"
14280 LET W$ = "-"
14285 IF P(K, 4) < 0 THEN 14295
14290 LET W$ = STR$(P(K, 4))
14295 LET R$ = "-"
14300 IF P(K, 5) < 0 THEN 14310
14305 LET R$ = STR$(P(K, 5))
14310 CALL "wr": X(), "fconv " & P$ & " 1 " & B$ & " " & W$ & " " & R$ & " " & SEG$(F$, P(K, 2), P(K, 2))
14315 NEXT K
14320 CALL "wr": X(), "fmt " & P$ & " 1 " & STR$(P(0, 0))
14325 CALL "pos": N(), G, P$
14330 CALL "wr": X(), "lib " & P$ & " 1 printf 1"
14335 SUBEND
