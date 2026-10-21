11995 REM ---- sc_emit: sea.hir1 (DESIGN 3.5): the type table, the constants, the functions. The
12000 REM records are produced twice: mode 1 (X(27) = 1) only numbers the types in order of first
12005 REM reference (3.5.1), mode 2 writes the table and then every record. ----------------------
12010 SUB "sc_emit": N(), M(), Y(), T(), W(), C(), S$(), X(), X$()
12015 LET X(28) = 0
12020 FOR H = 1 TO 2
12025 LET X(27) = H
12030 IF H = 1 THEN 12100
12035 FOR J = 1 TO X(28)
12040 LET Q = W(180000 + J)
12045 IF T(Q, 0) = 7 THEN 12065
12050 CALL "tyr": T(), W(), X(), T(Q, 1), A$
12055 CALL "wr": X(), "tvec " & STR$(9 + J) & " " & A$
12060 GOTO 12095
12065 LET L$ = "ttuple " & STR$(9 + J) & " " & STR$(T(Q, 1))
12070 FOR K = 1 TO T(Q, 1)
12075 CALL "tyr": T(), W(), X(), T(Q + 1 + INT((K - 1) / 9), K - 1 - 9 * INT((K - 1) / 9)), A$
12080 LET L$ = L$ & " " & A$
12085 NEXT K
12090 CALL "wr": X(), L$
12095 NEXT J
12100 FOR S = 2 TO X(33)
12105 IF Y(S, 0) <> 2 THEN 12215
12110 LET F = Y(S, 3)
12115 LET E = N(F, 7)
12120 IF N(F, 1) = 0 THEN 12130
12125 LET E = N(E, 8)
12130 REM the value as one leaf at the position of the expression's root (DESIGN 3.5.2)
12135 CALL "pos": N(), E, P$
12140 CALL "tyr": T(), W(), X(), Y(S, 2), A$
12145 LET R = Y(S, 8)
12150 IF Y(S, 7) = 3 THEN 12190
12155 IF Y(S, 7) = 2 THEN 12175
12160 CALL "LMFMT": C(R, 1), C(R, 2), C(R, 3), C(R, 4), B$
12165 CALL "wr": X(), "ci " & P$ & " " & A$ & " " & B$
12170 GOTO 12195
12175 CALL "LMHEX": C(R, 1), C(R, 2), C(R, 3), C(R, 4), B$
12180 CALL "wr": X(), "cf " & P$ & " " & A$ & " " & B$
12185 GOTO 12195
12190 CALL "wr": X(), "cb " & P$ & " " & A$ & " " & STR$(R)
12195 CALL "tyr": T(), W(), X(), Y(S, 2), A$
12200 CALL "io_esc": S$(Y(S, 1)), 0, B$
12205 CALL "pos": N(), F, P$
12210 CALL "wr": X(), "cn " & STR$(Y(S, 5)) & " " & B$ & " " & A$ & " " & P$
12215 NEXT S
12220 CALL "em_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), 1
12225 FOR S = 2 TO X(33)
12230 IF Y(S, 0) <> 1 THEN 12240
12235 CALL "em_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
12240 NEXT S
12245 NEXT H
12250 SUBEND
12255 REM ---- wr: one record of sea.hir1 (mode 2 only) ---------------------------------------------
12260 SUB "wr": X(), L$
12265 IF X(27) <> 2 THEN 12275
12270 PRINT #2, L$
12275 SUBEND
12280 REM ---- tyr: R$ = the written id of type Q; in mode 1 a type not yet numbered gets the next id,
12285 REM after its components (DESIGN 3.5.1); W(180000+j) = the type with id 9+j ----------------
12290 SUB "tyr": T(), W(), X(), Q, R$
12295 IF Q >= 10 THEN 12310
12300 LET R$ = STR$(Q)
12305 GOTO 12365
12310 IF T(Q, 9) > 0 THEN 12360
12315 IF T(Q, 0) = 7 THEN 12330
12320 CALL "tyr": T(), W(), X(), T(Q, 1), A$
12325 GOTO 12345
12330 FOR J = 1 TO T(Q, 1)
12335 CALL "tyr": T(), W(), X(), T(Q + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9)), A$
12340 NEXT J
12345 LET X(28) = X(28) + 1
12350 LET T(Q, 9) = X(28) + 9
12355 LET W(180000 + X(28)) = Q
12360 LET R$ = STR$(T(Q, 9))
12365 SUBEND
12370 REM ---- em_fn: function S (1 = .main): fn, par and loc records, the body, end (DESIGN 3.5.4) ---
12375 SUB "em_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
12380 LET F = Y(S, 3)
12385 LET P0 = Y(S, 6)
12390 LET L0 = Y(S, 8) - Y(S, 9) + 1 - P0
12395 IF S > 1 THEN 12415
12400 LET P$ = STR$(X(18)) & ":1:1"
12405 CALL "wr": X(), "fn 1 .main main 1 0 " & STR$(L0) & " " & P$
12410 GOTO 12435
12415 CALL "tyr": T(), W(), X(), Y(S, 2), A$
12420 CALL "io_esc": S$(Y(S, 1)), 0, B$
12425 CALL "pos": N(), F, P$
12430 CALL "wr": X(), "fn " & STR$(Y(S, 5)) & " " & B$ & " fn " & A$ & " " & STR$(P0) & " " & STR$(L0) & " " & P$
12435 FOR R = Y(S, 9) TO Y(S, 8)
12440 CALL "tyr": T(), W(), X(), Y(R, 2), A$
12445 CALL "io_esc": S$(Y(R, 1)), 0, B$
12450 LET U = Y(R, 4)
12455 IF U < 4 THEN 12470
12460 CALL "wr": X(), "par " & B$ & " " & A$ & " " & SEG$("valref", 3 * U - 11, 3 * U - 9)
12465 GOTO 12505
12470 CALL "pos": N(), Y(R, 3), C$
12475 IF U <> 3 THEN 12500
12480 REM a loop variable: the npos of its for (N(i,1..2), DESIGN 3.4, 3.5.4)
12485 LET I = Y(R, 3)
12490 LET G = INT(N(I, 1) / 1E9)
12495 LET C$ = STR$(G) & ":" & STR$(N(I, 1) - G * 1E9) & ":" & STR$(N(I, 2))
12500 CALL "wr": X(), "loc " & B$ & " " & A$ & " " & SEG$("let var for", 4 * U - 3, 4 * U - 1) & " " & C$
12505 NEXT R
12510 IF S > 1 THEN 12570
12515 LET I = N(X(17), 7)
12520 IF I = 0 THEN 12560
12525 LET K = N(I, 0)
12530 IF K = 2 THEN 12550
12535 IF K = 3 THEN 12550
12540 IF K = 5 THEN 12550
12545 CALL "em_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
12550 LET I = N(I, 8)
12555 GOTO 12520
12560 CALL "wr": X(), "block " & P$ & " " & STR$(X(29))
12565 GOTO 12595
12570 LET I = N(F, 7)
12575 FOR J = 1 TO P0 + Y(S, 7)
12580 LET I = N(I, 8)
12585 NEXT J
12590 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
12595 CALL "wr": X(), "end"
12600 SUBEND
12605 REM ---- em_blk: block B and its statements ---------------------------------------------------
12610 SUB "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
12615 LET I = N(B, 7)
12620 IF I = 0 THEN 12640
12625 CALL "em_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
12630 LET I = N(I, 8)
12635 GOTO 12620
12640 CALL "pos": N(), B, P$
12645 CALL "wr": X(), "block " & P$ & " " & STR$(N(B, 1))
12650 SUBEND
12655 REM ---- em_st: statement I (DESIGN 3.5.5) -------------------------------------------------
12660 SUB "em_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
12665 LET K = N(I, 0)
12670 LET G = N(I, 7)
12675 IF K < 8 THEN 13160
12680 IF K > 24 THEN 13160
12685 ON K - 7 GOTO 12690, 12690, 13160, 13160, 13160, 12800, 12830, 12920, 12940, 13025, 13050, 13160, 13160, 13075, 13090, 13105, 13155
12690 LET E = N(G, 8)
12695 IF N(I, 1) = 0 THEN 12705
12700 LET E = N(E, 8)
12705 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
12710 CALL "pos": N(), I, P$
12715 IF N(G, 0) = 10 THEN 12780
12720 IF N(G, 0) = 11 THEN 12790
12725 LET L$ = "tbind " & P$ & " " & STR$(N(G, 1))
12730 LET Q = N(G, 7)
12735 IF Q = 0 THEN 12770
12740 IF N(Q, 0) = 10 THEN 12755
12745 LET L$ = L$ & " -"
12750 GOTO 12760
12755 LET L$ = L$ & " " & STR$(Y(M(Q, 2), 5))
12760 LET Q = N(Q, 8)
12765 GOTO 12735
12770 CALL "wr": X(), L$
12775 GOTO 13160
12780 CALL "wr": X(), "bind " & P$ & " " & STR$(Y(M(G, 2), 5))
12785 GOTO 13160
12790 CALL "wr": X(), "eval " & P$
12795 GOTO 13160
12800 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
12805 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(G, 8)
12810 CALL "pos": N(), I, P$
12815 LET O = N(I, 1)
12820 CALL "wr": X(), "asg " & P$ & " " & SEG$("set add sub mul div", 4 * O - 3, 4 * O - 1)
12825 GOTO 13160
12830 LET L$ = ""
12835 FOR J = 1 TO N(I, 1)
12840 REM the cv flag of each target: 1 converts an i64 result to an f64 target (DESIGN 3.5.5)
12845 LET L1 = 0
12850 IF N(G, 0) = 11 THEN 12860
12855 LET L1 = M(G, 4)
12860 LET L$ = L$ & " " & STR$(L1)
12865 IF N(G, 0) = 11 THEN 12880
12870 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
12875 GOTO 12890
12880 CALL "pos": N(), G, P$
12885 CALL "wr": X(), "skip " & P$ & " 1"
12890 LET G = N(G, 8)
12895 NEXT J
12900 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
12905 CALL "pos": N(), I, P$
12910 CALL "wr": X(), "tasg " & P$ & " " & STR$(N(I, 1)) & L$
12915 GOTO 13160
12920 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
12925 CALL "pos": N(), I, P$
12930 CALL "wr": X(), "eval " & P$
12935 GOTO 13160
12940 REM an else-if chain without recursion: each link's condition and block, the final else block,
12945 REM then the if records from the last link back to the first (post-order)
12950 LET L1 = I
12955 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(L1, 7)
12960 LET B = N(N(L1, 7), 8)
12965 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
12970 IF N(L1, 1) = 0 THEN 13000
12975 LET B = N(B, 8)
12980 IF N(B, 0) = 24 THEN 12995
12985 LET L1 = B
12990 GOTO 12955
12995 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
13000 CALL "pos": N(), L1, P$
13005 CALL "wr": X(), "if " & P$ & " " & STR$(N(L1, 1))
13010 IF L1 = I THEN 13160
13015 LET L1 = N(L1, 9)
13020 GOTO 13000
13025 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
13030 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(G, 8)
13035 CALL "pos": N(), I, P$
13040 CALL "wr": X(), "while " & P$
13045 GOTO 13160
13050 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
13055 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(G, 8)
13060 CALL "pos": N(), I, P$
13065 CALL "wr": X(), "forr " & P$ & " " & STR$(Y(M(I, 2), 5))
13070 GOTO 13160
13075 CALL "pos": N(), I, P$
13080 CALL "wr": X(), "break " & P$
13085 GOTO 13160
13090 CALL "pos": N(), I, P$
13095 CALL "wr": X(), "cont " & P$
13100 GOTO 13160
13105 FOR J = 1 TO N(I, 1)
13110 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
13115 LET G = N(G, 8)
13120 NEXT J
13125 CALL "pos": N(), I, P$
13130 IF M(I, 4) = 1 THEN 13145
13135 CALL "wr": X(), "ret " & P$ & " " & STR$(N(I, 1))
13140 GOTO 13160
13145 CALL "wr": X(), "tret " & P$
13150 GOTO 13160
13155 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
13160 SUBEND
13165 REM ---- em_expr: expression E in post-order (= node order); M(J,8) < 0 marks a node where the
13170 REM writing jumps past node -M(J,8): a powk exponent, the literal 2^63 under neg, or the callee
13175 REM of printf (whose arguments are written between the format pieces, em_printf) ----------
13180 SUB "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
13185 LET J = M(E, 0)
13190 IF J > E THEN 13255
13195 IF M(J, 8) >= 0 THEN 13225
13200 LET G = -M(J, 8)
13205 IF N(G, 0) <> 35 THEN 13215
13210 CALL "em_printf": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
13215 LET J = G + 1
13220 GOTO 13190
13225 IF N(J, 0) <> 30 THEN 13240
13230 IF N(N(J, 9), 0) <> 35 THEN 13240
13235 IF N(N(J, 9), 7) = J THEN 13245
13240 CALL "em_node": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
13245 LET J = J + 1
13250 GOTO 13190
13255 SUBEND
13260 REM ---- em_node: the record of expression node J, then its cvt if any (DESIGN 3.5.5) ---------
13265 SUB "em_node": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
13270 CALL "pos": N(), J, P$
13275 CALL "tyr": T(), W(), X(), M(J, 1), A$
13280 LET Q$ = " " & P$ & " " & A$
13285 LET K = N(J, 0)
13290 IF K < 25 THEN 13645
13295 ON K - 24 GOTO 13300, 13345, 13365, 13380, 13390, 13400, 13645, 13455, 13510, 13520, 13575, 13645, 13610, 13620, 13645, 13645, 13630, 13645, 13645, 13645, 13645, 13645, 13645, 13645, 13640
13300 LET H = M(J, 5)
13305 IF M(J, 1) = 4 THEN 13325
13310 CALL "LMFMT": C(H, 1), C(H, 2), C(H, 3), C(H, 4), B$
13315 CALL "wr": X(), "ci" & Q$ & " " & B$
13320 GOTO 13645
13325 CALL "FEFRI": C(H, 1), C(H, 2), C(H, 3), C(H, 4), R3, R2, R1, R0, Z
13330 CALL "LMHEX": R3, R2, R1, R0, B$
13335 CALL "wr": X(), "cf" & Q$ & " " & B$
13340 GOTO 13645
13345 LET H = M(J, 5)
13350 CALL "LMHEX": C(H, 1), C(H, 2), C(H, 3), C(H, 4), B$
13355 CALL "wr": X(), "cf" & Q$ & " " & B$
13360 GOTO 13645
13365 CALL "io_esc": S$(N(J, 6)), 0, B$
13370 CALL "wr": X(), "cs" & Q$ & " " & B$
13375 GOTO 13645
13380 CALL "wr": X(), "cb" & Q$ & " 1"
13385 GOTO 13645
13390 CALL "wr": X(), "cb" & Q$ & " 0"
13395 GOTO 13645
13400 LET S = M(J, 2)
13405 IF S < 0 THEN 13435
13410 IF Y(S, 0) = 2 THEN 13425
13415 CALL "wr": X(), "lv" & Q$ & " " & STR$(Y(S, 5))
13420 GOTO 13645
13425 CALL "wr": X(), "cref" & Q$ & " " & STR$(Y(S, 5))
13430 GOTO 13645
13435 REM pi inf nan eps (DESIGN 3.5.5)
13440 LET B$ = SEG$("400921FB54442D187FF00000000000007FF80000000000003CB0000000000000", 16 * (-S) - 15, 16 * (-S))
13445 CALL "wr": X(), "cf" & Q$ & " #" & B$
13450 GOTO 13645
13455 LET G = N(J, 7)
13460 IF M(G, 8) >= 0 THEN 13500
13465 IF N(G, 0) <> 25 THEN 13500
13470 REM -2^63 as one constant (DESIGN 3.5.5)
13475 IF M(J, 1) = 4 THEN 13490
13480 CALL "wr": X(), "ci" & Q$ & " #8000000000000000"
13485 GOTO 13645
13490 CALL "wr": X(), "cf" & Q$ & " #C3E0000000000000"
13495 GOTO 13645
13500 CALL "wr": X(), "un" & Q$ & " neg"
13505 GOTO 13645
13510 CALL "wr": X(), "un" & Q$ & " not"
13515 GOTO 13645
13520 IF M(J, 8) > 0 THEN 13565
13525 LET O = N(J, 1)
13530 LET L$ = "add    sub    mul    div    mod    pow    matmul eq     ne     lt     le     gt     ge     band   bor    and    or     "
13535 LET B$ = SEG$(L$, 7 * O - 6, 7 * O - 1)
13540 LET H = POS(B$, " ")
13545 IF H = 0 THEN 13555
13550 LET B$ = SEG$(B$, 1, H - 1)
13555 CALL "wr": X(), "bin" & Q$ & " " & B$
13560 GOTO 13645
13565 CALL "wr": X(), "powk" & Q$ & " " & STR$(M(J, 8) - 10)
13570 GOTO 13645
13575 LET S = M(N(J, 7), 2)
13580 IF S < 0 THEN 13595
13585 CALL "wr": X(), "call" & Q$ & " " & STR$(Y(S, 5)) & " " & STR$(N(J, 1))
13590 GOTO 13645
13595 CALL "io_esc": S$(N(N(J, 7), 6)), 0, B$
13600 CALL "wr": X(), "lib" & Q$ & " " & B$ & " " & STR$(N(J, 1))
13605 GOTO 13645
13610 CALL "wr": X(), "rarg" & Q$
13615 GOTO 13645
13620 CALL "wr": X(), "lib" & Q$ & " " & SEG$("f64i64", 3 * N(J, 1) - 2, 3 * N(J, 1)) & " 1"
13625 GOTO 13645
13630 CALL "wr": X(), "rng" & Q$ & " " & STR$(N(J, 1)) & " " & STR$(N(J, 2))
13635 GOTO 13645
13640 CALL "wr": X(), "ifx" & Q$
13645 IF M(J, 7) <> 1 THEN 13655
13650 CALL "wr": X(), "cvt " & P$ & " 4"
13655 SUBEND
13660 REM ---- em_printf: printf call G: its format as fmt/ftext/fconv pieces at the position of the
13665 REM format literal, each conversion over its argument, then lib printf (DESIGN 3.5.5) --------
13670 SUB "em_printf": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
13675 DIM P(4100, 6)
13680 LET F = N(N(G, 7), 8)
13685 LET F$ = S$(N(F, 6))
13690 CALL "fmtp": F$, P(), N0, E, E$, X(35)
13695 CALL "pos": N(), F, P$
13700 LET A = N(F, 8)
13705 FOR K = 1 TO P(0, 0)
13710 IF P(K, 0) = 2 THEN 13780
13715 REM a text piece, %% written as %
13720 LET T$ = ""
13725 LET I = P(K, 1)
13730 IF I > P(K, 2) THEN 13765
13735 LET C$ = SEG$(F$, I, I)
13740 LET T$ = T$ & C$
13745 LET I = I + 1
13750 IF C$ <> "%" THEN 13730
13755 LET I = I + 1
13760 GOTO 13730
13765 CALL "io_esc": T$, 0, B$
13770 CALL "wr": X(), "ftext " & P$ & " 1 " & B$
13775 GOTO 13870
13780 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), A
13785 LET A = N(A, 8)
13790 LET B$ = ""
13795 LET H = P(K, 3)
13800 FOR J = 1 TO 5
13805 IF H - 2 * INT(H / 2) = 0 THEN 13815
13810 LET B$ = B$ & SEG$("lpsza", J, J)
13815 LET H = INT(H / 2)
13820 NEXT J
13825 IF B$ <> "" THEN 13835
13830 LET B$ = "-"
13835 LET W$ = "-"
13840 IF P(K, 4) < 0 THEN 13850
13845 LET W$ = STR$(P(K, 4))
13850 LET R$ = "-"
13855 IF P(K, 5) < 0 THEN 13865
13860 LET R$ = STR$(P(K, 5))
13865 CALL "wr": X(), "fconv " & P$ & " 1 " & B$ & " " & W$ & " " & R$ & " " & SEG$(F$, P(K, 2), P(K, 2))
13870 NEXT K
13875 CALL "wr": X(), "fmt " & P$ & " 1 " & STR$(P(0, 0))
13880 CALL "pos": N(), G, P$
13885 CALL "wr": X(), "lib " & P$ & " 1 printf 1"
13890 SUBEND
