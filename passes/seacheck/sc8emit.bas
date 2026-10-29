14520 REM ---- sc_emit: sea.hir1 (DESIGN 3.5): the type table, the constants, the functions. The
14525 REM records are produced twice: mode 1 (X(27) = 1) only numbers the types in order of first
14530 REM reference (3.5.1), mode 2 writes the table and then every record. ----------------------
14535 SUB "sc_emit": N(), M(), Y(), T(), W(), C(), S$(), X(), X$()
14540 LET X(28) = 0
14542 LET X(41) = 0
14545 FOR H = 1 TO 2
14550 LET X(27) = H
14555 IF H = 1 THEN 14625
14560 FOR J = 1 TO X(28)
14565 LET Q = W(180000 + J)
14570 IF T(Q, 0) = 7 THEN 14590
14572 IF ABS(T(Q, 0) - 5.5) > 1 THEN 14575
14573 CALL "emtst": T(), W(), X(), S$(), Q, J
14574 GOTO 14620
14575 CALL "tyr": T(), W(), X(), T(Q, 1), A$
14577 IF T(Q, 0) > 2 THEN 14582
14580 CALL "wr": X(), SEG$("tvectmat", 4 * T(Q, 0) - 3, 4 * T(Q, 0)) & " " & STR$(9 + J) & " " & A$
14581 GOTO 14620
14582 REM a fixed-size array: its extents (n; r c)
14583 LET L$ = SEG$("tfvectfmat", 5 * T(Q, 0) - 14, 5 * T(Q, 0) - 10) & " " & STR$(9 + J) & " " & A$
14584 CALL "wr": X(), L$ & " " & STR$(T(Q, 2)) & SEG$(" " & STR$(T(Q, 3)), 1, 99 * (T(Q, 0) - 3))
14585 GOTO 14620
14590 LET L$ = "ttuple " & STR$(9 + J) & " " & STR$(T(Q, 1))
14595 FOR K = 1 TO T(Q, 1)
14600 CALL "tyr": T(), W(), X(), T(Q + 1 + INT((K - 1) / 9), K - 1 - 9 * INT((K - 1) / 9)), A$
14605 LET L$ = L$ & " " & A$
14610 NEXT K
14615 CALL "wr": X(), L$
14620 NEXT J
14625 FOR S = 2 TO X(33)
14630 IF Y(S, 0) <> 2 THEN 14740
14635 LET F = Y(S, 3)
14640 LET E = N(F, 7)
14645 IF N(F, 1) = 0 THEN 14655
14650 LET E = N(E, 8)
14655 REM the value as one leaf at the position of the expression's root (DESIGN 3.5.2)
14660 CALL "pos": N(), E, P$
14665 CALL "tyr": T(), W(), X(), Y(S, 2), A$
14670 LET R = Y(S, 8)
14675 IF Y(S, 7) = 3 THEN 14715
14677 IF Y(S, 7) = 5 THEN 14717
14680 IF Y(S, 7) = 2 THEN 14700
14685 CALL "lfmt": C(R, 1), C(R, 2), C(R, 3), C(R, 4), B$
14690 CALL "wr": X(), "ci " & P$ & " " & A$ & " " & B$
14695 GOTO 14720
14700 CALL "lhex": C(R, 1), C(R, 2), C(R, 3), C(R, 4), B$
14705 CALL "wr": X(), "cf " & P$ & " " & A$ & " " & B$
14710 GOTO 14720
14715 CALL "wr": X(), "cb " & P$ & " " & A$ & " " & STR$(R)
14716 GOTO 14720
14717 CALL "io_esc": S$(R), 0, B$
14718 CALL "wr": X(), "cs " & P$ & " " & A$ & " " & B$
14720 CALL "tyr": T(), W(), X(), Y(S, 2), A$
14725 CALL "io_esc": S$(Y(S, 1)), 0, B$
14730 CALL "pos": N(), F, P$
14735 CALL "wr": X(), "cn " & STR$(Y(S, 5)) & " " & B$ & " " & A$ & " " & P$
14740 NEXT S
14745 CALL "em_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), 1
14750 FOR S = 2 TO X(33)
14755 IF Y(S, 0) <> 1 THEN 14765
14760 CALL "em_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
14765 NEXT S
14770 NEXT H
14775 SUBEND
14780 REM ---- wr: one record of sea.hir1 (mode 2 only) ---------------------------------------------
14785 SUB "wr": X(), L$
14790 IF X(27) <> 2 THEN 14800
14795 PRINT #2, L$
14800 SUBEND
14805 REM ---- tyr: R$ = the written id of type Q; in mode 1 a type not yet numbered gets the next id,
14810 REM after its components (DESIGN 3.5.1); W(180000+j) = the type with id 9+j ----------------
14815 SUB "tyr": T(), W(), X(), Q, R$
14820 IF Q >= 10 THEN 14835
14825 LET R$ = STR$(Q)
14830 GOTO 14890
14835 IF T(Q, 9) > 0 THEN 14885
14840 IF T(Q, 0) = 7 THEN 14855
14842 IF ABS(T(Q, 0) - 5.5) > 1 THEN 14845
14843 CALL "tyrf": T(), W(), X(), Q
14844 GOTO 14870
14845 CALL "tyr": T(), W(), X(), T(Q, 1), A$
14850 GOTO 14870
14855 FOR J = 1 TO T(Q, 1)
14860 CALL "tyr": T(), W(), X(), T(Q + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9)), A$
14865 NEXT J
14870 LET X(28) = X(28) + 1
14875 LET T(Q, 9) = X(28) + 9
14880 LET W(180000 + X(28)) = Q
14885 LET R$ = STR$(T(Q, 9))
14890 SUBEND
14895 REM ---- em_fn: function S (1 = .main): fn, par and loc records, the body, end (DESIGN 3.5.4) ---
14900 SUB "em_fn": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S
14905 LET F = Y(S, 3)
14910 LET P0 = Y(S, 6)
14915 LET L0 = Y(S, 8) - Y(S, 9) + 1 - P0
14916 REM the .t locals of ck_slit follow the declared ones (emtmp)
14917 LET X(40) = P0 + L0
14918 CALL "emtmp": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S, 0, K
14919 LET L0 = L0 + K
14920 IF S > 1 THEN 14940
14925 LET P$ = STR$(X(18)) & ":1:1"
14930 CALL "wr": X(), "fn 1 .main main 1 0 " & STR$(L0) & " " & P$
14935 GOTO 14960
14940 CALL "tyr": T(), W(), X(), Y(S, 2), A$
14945 CALL "io_esc": S$(Y(S, 1)), 0, B$
14950 CALL "pos": N(), F, P$
14951 REM the kind (DESIGN 3.5.4): fn, elem (rfn el 1) or inl (el 2, Decision 81)
14952 LET K$ = " fn "
14953 IF Y(S, 4) = 0 THEN 14955
14954 LET K$ = SEG$(" elem inl ", 5 * Y(S, 4) - 4, 4 * Y(S, 4) + 2)
14955 CALL "wr": X(), "fn " & STR$(Y(S, 5)) & " " & B$ & K$ & A$ & " " & STR$(P0) & " " & STR$(L0) & " " & P$
14960 FOR R = Y(S, 9) TO Y(S, 8)
14965 CALL "tyr": T(), W(), X(), Y(R, 2), A$
14970 CALL "io_esc": S$(Y(R, 1)), 0, B$
14975 LET U = Y(R, 4)
14980 IF U < 4 THEN 14995
14985 CALL "wr": X(), "par " & B$ & " " & A$ & " " & SEG$("valref", 3 * U - 11, 3 * U - 9)
14990 GOTO 15030
14995 CALL "pos": N(), Y(R, 3), C$
15000 IF U <> 3 THEN 15025
15005 REM a loop variable: the npos of its for (N(i,1..2), DESIGN 3.4, 3.5.4)
15010 LET I = Y(R, 3)
15015 LET G = INT(N(I, 1) / 1E9)
15020 LET C$ = STR$(G) & ":" & STR$(N(I, 1) - G * 1E9) & ":" & STR$(N(I, 2))
15025 CALL "wr": X(), "loc " & B$ & " " & A$ & " " & SEG$("let var for", 4 * U - 3, 4 * U - 1) & " " & C$
15030 NEXT R
15032 CALL "emtmp": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), S, 1, K
15035 IF S > 1 THEN 15095
15040 LET I = N(X(17), 7)
15045 IF I = 0 THEN 15085
15050 LET K = N(I, 0)
15055 IF K = 2 THEN 15075
15060 IF K = 3 THEN 15075
15065 IF K = 5 THEN 15075
15070 CALL "em_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
15075 LET I = N(I, 8)
15080 GOTO 15045
15085 CALL "wr": X(), "block " & P$ & " " & STR$(X(29))
15090 GOTO 15120
15095 LET I = N(F, 7)
15100 FOR J = 1 TO P0 + Y(S, 7)
15105 LET I = N(I, 8)
15110 NEXT J
15115 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
15120 CALL "wr": X(), "end"
15125 SUBEND
15130 REM ---- em_blk: block B and its statements ---------------------------------------------------
15135 SUB "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
15140 LET I = N(B, 7)
15145 IF I = 0 THEN 15165
15150 CALL "em_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
15155 LET I = N(I, 8)
15160 GOTO 15145
15165 CALL "pos": N(), B, P$
15170 CALL "wr": X(), "block " & P$ & " " & STR$(N(B, 1))
15175 SUBEND
15180 REM ---- em_st: statement I (DESIGN 3.5.5) -------------------------------------------------
15185 SUB "em_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
15190 LET K = N(I, 0)
15195 LET G = N(I, 7)
15200 IF K < 8 THEN 15705
15205 IF K > 24 THEN 15705
15210 ON K - 7 GOTO 15215, 15215, 15705, 15705, 15705, 15325, 15355, 15445, 15465, 15550, 15575, 15702, 15705, 15620, 15635, 15650, 15700
15215 LET E = N(G, 8)
15220 IF N(I, 1) = 0 THEN 15230
15225 LET E = N(E, 8)
15230 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
15235 CALL "pos": N(), I, P$
15240 IF N(G, 0) = 10 THEN 15305
15245 IF N(G, 0) = 11 THEN 15315
15250 LET L$ = "tbind " & P$ & " " & STR$(N(G, 1))
15255 LET Q = N(G, 7)
15260 IF Q = 0 THEN 15295
15265 IF N(Q, 0) = 10 THEN 15280
15270 LET L$ = L$ & " -"
15275 GOTO 15285
15280 LET L$ = L$ & " " & STR$(Y(M(Q, 2), 5))
15285 LET Q = N(Q, 8)
15290 GOTO 15260
15295 CALL "wr": X(), L$
15300 GOTO 15705
15305 CALL "wr": X(), "bind " & P$ & " " & STR$(Y(M(G, 2), 5))
15310 GOTO 15705
15315 CALL "wr": X(), "eval " & P$
15320 GOTO 15705
15325 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
15330 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(G, 8)
15335 CALL "pos": N(), I, P$
15340 LET O = N(I, 1)
15345 CALL "wr": X(), "asg " & P$ & " " & SEG$("set add sub mul div", 4 * O - 3, 4 * O - 1)
15350 GOTO 15705
15355 LET L$ = ""
15360 FOR J = 1 TO N(I, 1)
15365 REM the cv of each target: 1 i64 to f64, 2 dyn, 4 fix, their sum (DESIGN 3.5.5, Decision 37)
15370 LET L1 = 0
15375 IF N(G, 0) = 11 THEN 15385
15380 LET L1 = M(G, 4)
15385 LET L$ = L$ & " " & STR$(L1)
15390 IF N(G, 0) = 11 THEN 15405
15395 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
15400 GOTO 15415
15405 CALL "pos": N(), G, P$
15410 CALL "wr": X(), "skip " & P$ & " 1"
15415 LET G = N(G, 8)
15420 NEXT J
15425 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
15430 CALL "pos": N(), I, P$
15435 CALL "wr": X(), "tasg " & P$ & " " & STR$(N(I, 1)) & L$
15440 GOTO 15705
15445 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
15450 CALL "pos": N(), I, P$
15455 CALL "wr": X(), "eval " & P$
15460 GOTO 15705
15465 REM an else-if chain without recursion: each link's condition and block, the final else block,
15470 REM then the if records from the last link back to the first (post-order)
15475 LET L1 = I
15480 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(L1, 7)
15485 LET B = N(N(L1, 7), 8)
15490 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
15495 IF N(L1, 1) = 0 THEN 15525
15500 LET B = N(B, 8)
15505 IF N(B, 0) = 24 THEN 15520
15510 LET L1 = B
15515 GOTO 15480
15520 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
15525 CALL "pos": N(), L1, P$
15530 CALL "wr": X(), "if " & P$ & " " & STR$(N(L1, 1))
15535 IF L1 = I THEN 15705
15540 LET L1 = N(L1, 9)
15545 GOTO 15525
15550 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
15555 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(G, 8)
15560 CALL "pos": N(), I, P$
15565 CALL "wr": X(), "while " & P$
15570 GOTO 15705
15575 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
15580 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(G, 8)
15585 CALL "pos": N(), I, P$
15590 LET B$ = "forr "
15595 IF N(G, 0) = 41 THEN 15610
15600 REM an element loop (DESIGN 3.5.5 fore)
15605 LET B$ = "fore "
15610 CALL "wr": X(), B$ & P$ & " " & STR$(Y(M(I, 2), 5))
15615 GOTO 15705
15620 CALL "pos": N(), I, P$
15625 CALL "wr": X(), "break " & P$
15630 GOTO 15705
15635 CALL "pos": N(), I, P$
15640 CALL "wr": X(), "cont " & P$
15645 GOTO 15705
15650 FOR J = 1 TO N(I, 1)
15655 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
15660 LET G = N(G, 8)
15665 NEXT J
15670 CALL "pos": N(), I, P$
15675 IF M(I, 4) = 1 THEN 15690
15680 CALL "wr": X(), "ret " & P$ & " " & STR$(N(I, 1))
15685 GOTO 15705
15690 CALL "wr": X(), "tret " & P$
15695 GOTO 15705
15700 CALL "em_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
15701 GOTO 15705
15702 CALL "em_mt": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
15705 SUBEND
15710 REM ---- em_expr: expression E in post-order (= node order); M(J,8) < 0 marks a node where the
15715 REM writing jumps past node -M(J,8): a powk exponent, the literal 2^63 under neg, or the callee
15720 REM of printf (whose arguments are written between the format pieces, em_printf), or the value of a
15722 REM dim: option (narg -M(J,8), written as one ci of the value M(narg,5); DESIGN 3.5.5), or the
15723 REM callee of a Sea function called with a named or an omitted argument (em_uarg, then the call) --
15725 SUB "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
15730 LET J = M(E, 0)
15735 IF J > E THEN 15800
15736 IF X(41) = 0 THEN 15740
15737 CALL "erep": N(), M(), T(), W(), X(), J, E, G
15738 IF G = 0 THEN 15740
15739 GOTO 15760
15740 IF M(J, 8) >= 0 THEN 15770
15745 LET G = -M(J, 8)
15747 IF N(G, 0) <> 36 THEN 15750
15748 CALL "pos": N(), N(G, 7), P$
15749 CALL "wr": X(), "ci " & P$ & " 3 " & STR$(M(G, 5))
15750 IF N(G, 0) <> 35 THEN 15760
15751 IF M(N(G, 7), 2) < 1 THEN 15755
15752 CALL "em_uarg": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
15753 CALL "em_node": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
15754 GOTO 15756
15755 CALL "em_printf": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
15756 CALL "embd": N(), M(), X(), G
15760 LET J = G + 1
15765 GOTO 15735
15770 IF N(J, 0) <> 30 THEN 15785
15775 IF N(N(J, 9), 0) <> 35 THEN 15785
15780 IF N(N(J, 9), 7) = J THEN 15790
15785 CALL "em_node": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
15786 CALL "embd": N(), M(), X(), J
15790 LET J = J + 1
15795 GOTO 15735
15800 SUBEND
15805 REM ---- em_node: the record of expression node J, then its cvt, dyn or fix (DESIGN 3.5.5) ------
15810 SUB "em_node": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J
15815 CALL "pos": N(), J, P$
15820 CALL "tyr": T(), W(), X(), M(J, 1), A$
15825 LET Q$ = " " & P$ & " " & A$
15830 LET K = N(J, 0)
15835 IF K < 25 THEN 16220
15840 ON K - 24 GOTO 15845, 15900, 15920, 15935, 15945, 15955, 16205, 16010, 16065, 16075, 16130, 16220, 16165, 16172, 16195, 16211, 16185, 16220, 16213, 16217, 16217, 16207, 16207, 16220, 16215
15845 LET H = M(J, 5)
15850 IF M(J, 1) = 4 THEN 15870
15855 CALL "lfmt": C(H, 1), C(H, 2), C(H, 3), C(H, 4), B$
15860 CALL "wr": X(), "ci" & Q$ & " " & B$
15865 GOTO 16220
15870 REM an int literal typed f64: the fv bits of its rint (exact, else NOT_EXACT_F64 was reported)
15875 LET R3 = INT(N(J, 1) / 65536)
15880 LET R1 = INT(N(J, 2) / 65536)
15885 CALL "lhex": R3, N(J, 1) - 65536 * R3, R1, N(J, 2) - 65536 * R1, B$
15890 CALL "wr": X(), "cf" & Q$ & " " & B$
15895 GOTO 16220
15900 LET H = M(J, 5)
15905 CALL "lhex": C(H, 1), C(H, 2), C(H, 3), C(H, 4), B$
15910 CALL "wr": X(), "cf" & Q$ & " " & B$
15915 GOTO 16220
15920 CALL "io_esc": S$(N(J, 6)), 0, B$
15925 CALL "wr": X(), "cs" & Q$ & " " & B$
15930 GOTO 16220
15935 CALL "wr": X(), "cb" & Q$ & " 1"
15940 GOTO 16220
15945 CALL "wr": X(), "cb" & Q$ & " 0"
15950 GOTO 16220
15955 LET S = M(J, 2)
15960 IF S < 0 THEN 15990
15965 IF Y(S, 0) = 2 THEN 15980
15970 CALL "wr": X(), "lv" & Q$ & " " & STR$(Y(S, 5))
15975 GOTO 16220
15980 CALL "wr": X(), "cref" & Q$ & " " & STR$(Y(S, 5))
15985 GOTO 16220
15990 REM pi inf nan eps (DESIGN 3.5.5)
15995 LET B$ = SEG$("400921FB54442D187FF00000000000007FF80000000000003CB0000000000000", 16 * (-S) - 15, 16 * (-S))
16000 CALL "wr": X(), "cf" & Q$ & " #" & B$
16005 GOTO 16220
16010 LET G = N(J, 7)
16015 IF M(G, 8) >= 0 THEN 16055
16020 IF N(G, 0) <> 25 THEN 16055
16025 REM -2^63 as one constant (DESIGN 3.5.5)
16030 IF M(J, 1) = 4 THEN 16045
16035 CALL "wr": X(), "ci" & Q$ & " #8000000000000000"
16040 GOTO 16220
16045 CALL "wr": X(), "cf" & Q$ & " #C3E0000000000000"
16050 GOTO 16220
16055 CALL "wr": X(), "un" & Q$ & " neg"
16060 GOTO 16220
16065 CALL "wr": X(), "un" & Q$ & " not"
16070 GOTO 16220
16075 IF M(J, 8) > 0 THEN 16120
16080 LET O = N(J, 1)
16085 LET L$ = "add    sub    mul    div    mod    pow    matmul eq     ne     lt     le     gt     ge     band   bor    and    or     "
16090 LET B$ = SEG$(L$, 7 * O - 6, 7 * O - 1)
16095 LET H = POS(B$, " ")
16100 IF H = 0 THEN 16110
16105 LET B$ = SEG$(B$, 1, H - 1)
16106 REM + of str operands (or str elements) is cat (DESIGN 3.5.5)
16107 CALL "elt": T(), M(J, 1), E, H
16108 IF E * 10 + O <> 51 THEN 16110
16109 LET B$ = "cat"
16110 CALL "wr": X(), "bin" & Q$ & " " & B$
16115 GOTO 16220
16120 CALL "wr": X(), "powk" & Q$ & " " & STR$(M(J, 8) - 10)
16125 GOTO 16220
16130 LET S = M(N(J, 7), 2)
16135 IF S < 0 THEN 16150
16136 REM written by em_uarg (its callee jumps here): np arguments, then the seq of a reordered one
16137 LET H = N(J, 1)
16138 IF M(N(J, 7), 8) >= 0 THEN 16140
16139 LET H = Y(S, 6)
16140 CALL "wr": X(), "call" & Q$ & " " & STR$(Y(S, 5)) & " " & STR$(H)
16141 IF M(J, 9) = 0 THEN 16220
16142 CALL "wr": X(), "seq" & Q$ & " " & STR$(M(J, 9) - 1)
16145 GOTO 16220
16150 CALL "io_esc": S$(N(N(J, 7), 6)), 0, B$
16151 REM a dim: form is name.dim; sort and argsort without desc: take the inserted cb 0 (sc9red lred)
16152 IF M(J, 9) <> 1 THEN 16154
16153 LET B$ = B$ & ".dim"
16154 IF M(J, 9) <> 2 THEN 16156
16155 CALL "wr": X(), "cb " & P$ & " 2 0"
16156 CALL "wr": X(), "lib" & Q$ & " " & B$ & " " & STR$(N(J, 1) + INT(M(J, 9) / 2))
16160 GOTO 16220
16165 CALL "wr": X(), "rarg" & Q$
16170 GOTO 16220
16171 REM str(s) of a str is s itself (Decision 46, DESIGN 3.5.5): no record of its own
16172 IF N(J, 1) <> 3 THEN 16175
16173 IF M(N(J, 7), 1) = 5 THEN 16234
16175 CALL "wr": X(), "lib" & Q$ & " " & SEG$("f64i64str", 3 * N(J, 1) - 2, 3 * N(J, 1)) & " 1"
16180 GOTO 16220
16185 CALL "wr": X(), "rng" & Q$ & " " & STR$(N(J, 1)) & " " & STR$(N(J, 2))
16190 GOTO 16220
16195 CALL "wr": X(), "idx" & Q$ & " " & STR$(N(J, 1))
16200 GOTO 16220
16205 CALL "wr": X(), "dol" & Q$ & " " & STR$(M(J, 5))
16206 GOTO 16220
16207 CALL "emslit": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), J, Q$
16208 GOTO 16220
16210 GOTO 16220
16211 CALL "wr": X(), "all" & Q$
16212 GOTO 16220
16213 CALL "emdot": N(), S$(), X(), J, Q$
16214 GOTO 16220
16215 CALL "wr": X(), "ifx" & Q$
16216 GOTO 16220
16217 CALL "wr": X(), SEG$("arr row", 4 * K - 175, 4 * K - 173) & Q$ & " " & STR$(N(J, 1))
16220 REM the conversions after the node (rangev writes none of its own): cvt, of a scalar (M(J,7) 1)
16221 REM or element by element to the type M(J,7); then a dyn or fix to the type M(J,5)
16222 IF M(J, 7) = 0 THEN 16227
16223 LET A$ = "4"
16224 IF M(J, 7) = 1 THEN 16226
16225 CALL "tyr": T(), W(), X(), M(J, 7), A$
16226 CALL "wr": X(), "cvt " & P$ & " " & A$
16227 IF K < 27 THEN 16234
16228 IF K = 31 THEN 16234
16229 IF M(J, 5) < 10 THEN 16234
16230 CALL "tyr": T(), W(), X(), M(J, 5), A$
16231 LET Q = 3 * INT((T(M(J, 5), 0) - 1) / 2)
16232 CALL "lpos": N(), M(), J, P$
16233 CALL "wr": X(), SEG$("dynfix", Q + 1, Q + 3) & " " & P$ & " " & A$
16234 SUBEND
16235 REM ---- em_printf: printf or error call G: its format as fmt/ftext/fconv pieces at the position of the
16240 REM format literal, each conversion over its argument, then lib printf or lib error (DESIGN 3.5.5) --------
16245 SUB "em_printf": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
16250 DIM P(4100, 6)
16255 LET F = N(N(G, 7), 8)
16260 LET F$ = S$(N(F, 6))
16265 CALL "fmtp": F$, P(), N0, E, E$, X(35)
16270 CALL "pos": N(), F, P$
16275 LET A = N(F, 8)
16280 FOR K = 1 TO P(0, 0)
16285 IF P(K, 0) = 2 THEN 16355
16290 REM a text piece, %% written as %
16295 LET T$ = ""
16300 LET I = P(K, 1)
16305 IF I > P(K, 2) THEN 16340
16310 LET C$ = SEG$(F$, I, I)
16315 LET T$ = T$ & C$
16320 LET I = I + 1
16325 IF C$ <> "%" THEN 16305
16330 LET I = I + 1
16335 GOTO 16305
16340 CALL "io_esc": T$, 0, B$
16345 CALL "wr": X(), "ftext " & P$ & " 1 " & B$
16350 GOTO 16445
16355 CALL "em_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), A
16360 LET A = N(A, 8)
16365 LET B$ = ""
16370 LET H = P(K, 3)
16375 FOR J = 1 TO 5
16380 IF H - 2 * INT(H / 2) = 0 THEN 16390
16385 LET B$ = B$ & SEG$("lpsza", J, J)
16390 LET H = INT(H / 2)
16395 NEXT J
16400 IF B$ <> "" THEN 16410
16405 LET B$ = "-"
16410 LET W$ = "-"
16415 IF P(K, 4) < 0 THEN 16425
16420 LET W$ = STR$(P(K, 4))
16425 LET R$ = "-"
16430 IF P(K, 5) < 0 THEN 16440
16435 LET R$ = STR$(P(K, 5))
16440 CALL "wr": X(), "fconv " & P$ & " 1 " & B$ & " " & W$ & " " & R$ & " " & SEG$(F$, P(K, 2), P(K, 2))
16445 NEXT K
16450 CALL "wr": X(), "fmt " & P$ & " 1 " & STR$(P(0, 0))
16455 CALL "pos": N(), G, P$
16457 CALL "io_esc": S$(N(N(G, 7), 6)), 0, B$
16458 CALL "tyr": T(), W(), X(), M(G, 1), A$
16460 CALL "wr": X(), "lib " & P$ & " " & A$ & " " & B$ & " 1"
16465 SUBEND
