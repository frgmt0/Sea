5095 REM ---- ck_blk: block B, a scope (LANGUAGE 7.2, 7.7); M(B,9) = 1 when a statement ends every path
5100 SUB "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
5105 LET M(B, 9) = 0
5110 CALL "sc_push": N(), W(), X(), X$(), B
5115 LET I = N(B, 7)
5120 IF I = 0 THEN 5150
5125 CALL "ck_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5130 IF M(I, 9) = 0 THEN 5140
5135 LET M(B, 9) = 1
5140 LET I = N(I, 8)
5145 GOTO 5120
5150 CALL "sc_pop": W(), X()
5155 SUBEND
5160 REM ---- sc_push / sc_pop: open and close a scope (marker -1 on the scope stack in W) -----------
5165 SUB "sc_push": N(), W(), X(), X$(), I
5170 IF X(12) - 2 > X(11) THEN 5185
5175 CALL "fatal": N(), X(), X$(), I, "symbols"
5180 GOTO 5195
5185 LET X(12) = X(12) - 2
5190 LET W(X(12)) = -1
5195 SUBEND
5200 SUB "sc_pop": W(), X()
5205 IF X(12) >= 200000 THEN 5230
5210 IF W(X(12)) = -1 THEN 5225
5215 LET X(12) = X(12) + 2
5220 GOTO 5205
5225 LET X(12) = X(12) + 2
5230 SUBEND
5235 REM ---- fin: an untyped constant that no context typed is i64 (LANGUAGE 4.2) ------------------
5240 SUB "fin": N(), M(), C(), X(), X$(), I
5245 IF M(I, 1) <> -1 THEN 5255
5250 CALL "stl": N(), M(), C(), X(), X$(), I, 3
5255 SUBEND
5260 REM ---- ck_cond: condition I must be a scalar bool (LANGUAGE 4.3) -----------------------------
5265 SUB "ck_cond": N(), M(), T(), C(), X(), X$(), I
5270 CALL "vu": N(), M(), T(), X(), X$(), I, D
5275 IF D <> -1 THEN 5290
5280 CALL "stl": N(), M(), C(), X(), X$(), I, 3
5285 LET D = 3
5290 IF D = 2 THEN 5305
5295 IF D = 0 THEN 5305
5300 CALL "er": N(), X(), X$(), I, "COND_BOOL", "", "", "", 0
5305 SUBEND
5310 REM ---- ck_tgt: R = the local assigned by target G (a var or a ref parameter, LANGUAGE 7.3), or
5315 REM 0 after an error: immutable locals, constants, functions and other expressions ----------
5320 SUB "ck_tgt": N(), M(), Y(), S$(), X(), X$(), G, R
5325 LET R = 0
5330 IF N(G, 0) = 30 THEN 5350
5335 IF M(G, 1) = 0 THEN 5405
5340 CALL "er": N(), X(), X$(), G, "BAD_TARGET", "", "", "", 0
5345 GOTO 5405
5350 LET S = M(G, 2)
5355 IF S = 0 THEN 5405
5360 IF S < 0 THEN 5400
5365 IF Y(S, 0) <> 4 THEN 5400
5370 IF Y(S, 4) = 2 THEN 5390
5375 IF Y(S, 4) = 5 THEN 5390
5380 CALL "er": N(), X(), X$(), G, "ASSIGN_IMMUTABLE", S$(N(G, 6)), "", "", 1
5385 GOTO 5405
5390 LET R = S
5395 GOTO 5405
5400 CALL "er": N(), X(), X$(), G, "BAD_TARGET", "", "", "", 0
5405 SUBEND
5410 REM ---- ck_st: statement I (LANGUAGE 7.1-7.6) ---------------------------------------------
5415 SUB "ck_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5420 LET M(I, 9) = 0
5425 LET X(19) = I
5430 LET K = N(I, 0)
5435 IF K < 8 THEN 5775
5440 IF K > 24 THEN 5775
5445 ON K - 7 GOTO 5450, 5450, 5775, 5775, 5775, 5460, 5470, 5480, 5490, 5615, 5650, 5720, 5775, 5730, 5745, 5760, 5770
5450 CALL "ck_let": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5455 GOTO 5775
5460 CALL "ck_asg": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5465 GOTO 5775
5470 CALL "ck_tasg": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5475 GOTO 5775
5480 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(I, 7)
5485 GOTO 5775
5490 REM an else-if chain is walked here link by link (no recursion over its length); it ends
5495 REM every path when every block does and the chain ends with an else block
5500 LET L1 = I
5505 LET Z = 1
5510 LET X(19) = L1
5515 LET M(L1, 9) = 0
5520 LET E = N(L1, 7)
5525 LET B = N(E, 8)
5530 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
5535 CALL "ck_cond": N(), M(), T(), C(), X(), X$(), E
5540 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
5545 IF M(B, 9) = 1 THEN 5555
5550 LET Z = 0
5555 IF N(L1, 1) = 1 THEN 5570
5560 LET Z = 0
5565 GOTO 5605
5570 LET G = N(B, 8)
5575 IF N(G, 0) = 24 THEN 5590
5580 LET L1 = G
5585 GOTO 5510
5590 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
5595 IF M(G, 9) = 1 THEN 5605
5600 LET Z = 0
5605 LET M(I, 9) = Z
5610 GOTO 5775
5615 LET E = N(I, 7)
5620 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
5625 CALL "ck_cond": N(), M(), T(), C(), X(), X$(), E
5630 LET X(15) = X(15) + 1
5635 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(E, 8)
5640 LET X(15) = X(15) - 1
5645 GOTO 5775
5650 REM a range loop; any other iterable is an array (phase 1: not supported yet)
5655 LET E = N(I, 7)
5660 IF N(E, 0) = 41 THEN 5675
5665 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "arrays", "", "", 1
5670 GOTO 5775
5675 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
5680 CALL "sc_push": N(), W(), X(), X$(), I
5685 CALL "nloc": N(), Y(), W(), X(), X$(), S$(), N(I, 6), 3, 3, I, 1, R
5690 LET M(I, 2) = R
5695 LET X(15) = X(15) + 1
5700 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(E, 8)
5705 LET X(15) = X(15) - 1
5710 CALL "sc_pop": W(), X()
5715 GOTO 5775
5720 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "match", "", "", 1
5725 GOTO 5775
5730 IF X(15) > 0 THEN 5775
5735 CALL "er": N(), X(), X$(), I, "BREAK_OUTSIDE", "", "", "", 0
5740 GOTO 5775
5745 IF X(15) > 0 THEN 5775
5750 CALL "er": N(), X(), X$(), I, "CONTINUE_OUTSIDE", "", "", "", 0
5755 GOTO 5775
5760 CALL "ck_ret": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5765 GOTO 5775
5770 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5775 SUBEND
5780 REM ---- ck_let: let/var I: pattern, [type], value (LANGUAGE 7.2, 4.2, 8.4) --------------------
5785 SUB "ck_let": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5790 LET P = N(I, 7)
5795 LET E = N(P, 8)
5800 LET D = 0
5805 LET Z0 = 0
5810 LET A = N(I, 1)
5815 IF A = 0 THEN 5830
5820 LET G = E
5825 LET E = N(E, 8)
5830 LET U = N(I, 0) - 7
5835 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
5840 IF A = 0 THEN 5905
5845 CALL "tyof": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G, D
5850 IF N(P, 0) = 12 THEN 5905
5855 REM a multiple-result call for one name or _ is a result count error, before any conversion
5860 LET V = M(E, 1)
5865 IF V < 10 THEN 5885
5870 IF T(V, 0) <> 7 THEN 5885
5875 CALL "er": N(), X(), X$(), E, "RESULT_COUNT", STR$(T(V, 1)), "1", "", 2
5880 GOTO 5905
5885 IF D = 0 THEN 5900
5890 CALL "cv": N(), M(), T(), C(), X(), X$(), E, D
5895 GOTO 5905
5900 CALL "fin": N(), M(), C(), X(), X$(), E
5905 LET K = N(P, 0)
5910 IF K = 11 THEN 6045
5915 IF K = 12 THEN 6060
5920 REM one name: its type is the annotation, or the value's
5925 IF A = 1 THEN 6010
5930 LET D = M(E, 1)
5935 IF D < 10 THEN 5960
5940 IF T(D, 0) <> 7 THEN 5960
5945 CALL "er": N(), X(), X$(), E, "RESULT_COUNT", STR$(T(D, 1)), "1", "", 2
5950 LET D = 0
5955 GOTO 6010
5960 IF D <> -1 THEN 6005
5965 REM an untyped constant: i64, or for an unannotated var the candidate of the var rule
5970 LET D = 3
5975 IF U = 1 THEN 5995
5980 LET Z0 = 1
5985 IF M(P, 4) = 0 THEN 5995
5990 LET D = 4
5995 CALL "stl": N(), M(), C(), X(), X$(), E, D
6000 GOTO 6010
6005 CALL "vu": N(), M(), T(), X(), X$(), E, D
6010 CALL "nloc": N(), Y(), W(), X(), X$(), S$(), N(P, 6), D, U, P, 1, R
6015 LET M(P, 2) = R
6020 IF R = 0 THEN 6235
6025 IF Z0 = 0 THEN 6235
6030 REM the candidate of the var rule: an unannotated var whose initialiser was untyped
6035 LET Y(R, 6) = P
6040 GOTO 6235
6045 IF A = 1 THEN 6235
6050 CALL "fin": N(), M(), C(), X(), X$(), E
6055 GOTO 6235
6060 REM a tuple pattern: one name or _ per result of a multiple-result call
6065 LET H = N(P, 1)
6070 LET V = M(E, 1)
6075 LET V0 = 1
6080 IF V = 0 THEN 6130
6085 IF V = -1 THEN 6115
6090 IF V = 1 THEN 6125
6095 IF V < 10 THEN 6130
6100 IF T(V, 0) <> 7 THEN 6130
6105 LET V0 = T(V, 1)
6110 GOTO 6130
6115 CALL "fin": N(), M(), C(), X(), X$(), E
6120 GOTO 6130
6125 LET V0 = 0
6130 IF A = 0 THEN 6165
6135 IF D = 0 THEN 6165
6140 IF V = 0 THEN 6165
6145 CALL "tyn": T(), D, A$
6150 CALL "tyn": T(), V, B$
6155 CALL "er": N(), X(), X$(), E, "TYPE_MISMATCH", A$, B$, "", 2
6160 LET V = 0
6165 IF V = 0 THEN 6185
6170 IF V0 = H THEN 6185
6175 CALL "er": N(), X(), X$(), P, "RESULT_COUNT", STR$(V0), STR$(H), "", 2
6180 LET V = 0
6185 LET Q = N(P, 7)
6190 FOR J = 1 TO H
6195 IF N(Q, 0) <> 10 THEN 6225
6200 LET D = 0
6205 IF V < 10 THEN 6215
6210 LET D = T(V + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9))
6215 CALL "nloc": N(), Y(), W(), X(), X$(), S$(), N(Q, 6), D, U, Q, 1, R
6220 LET M(Q, 2) = R
6225 LET Q = N(Q, 8)
6230 NEXT J
6235 SUBEND
6240 REM ---- ck_asg: target op= value (LANGUAGE 7.3; x op= e is x = x op e) ------------------------
6245 SUB "ck_asg": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
6250 LET G = N(I, 7)
6255 LET E = N(G, 8)
6260 LET O = N(I, 1)
6265 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
6270 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
6275 CALL "ck_tgt": N(), M(), Y(), S$(), X(), X$(), G, R
6280 LET D = M(G, 1)
6285 IF R = 0 THEN 6535
6290 IF D = 0 THEN 6535
6295 IF O > 1 THEN 6370
6300 REM =: a multiple-result call to one target is a result count error (LANGUAGE 8.4)
6305 LET V = M(E, 1)
6310 IF V < 10 THEN 6330
6315 IF T(V, 0) <> 7 THEN 6330
6320 CALL "er": N(), X(), X$(), E, "RESULT_COUNT", STR$(T(V, 1)), "1", "", 2
6325 GOTO 6540
6330 REM a candidate var stores an f64 (Decision 8), else the value converts to the target
6335 IF Y(R, 6) = 0 THEN 6360
6340 IF D <> 3 THEN 6360
6345 IF M(E, 1) <> 4 THEN 6360
6350 CALL "cand": M(), Y(), X(), R
6355 GOTO 6540
6360 CALL "cv": N(), M(), T(), C(), X(), X$(), E, D
6365 GOTO 6540
6370 CALL "vu": N(), M(), T(), X(), X$(), E, V
6375 IF V = 0 THEN 6540
6380 IF D = 2 THEN 6505
6385 IF V = 2 THEN 6505
6390 IF V > 4 THEN 6505
6395 IF D > 4 THEN 6505
6400 IF V <> -1 THEN 6415
6405 CALL "stl": N(), M(), C(), X(), X$(), E, D
6410 LET V = M(E, 1)
6415 REM the result of x op e: f64 for / and beside an f64, else i64 (LANGUAGE 6.5)
6420 LET Z = 3
6425 IF O = 5 THEN 6445
6430 IF D = 4 THEN 6445
6435 IF V = 4 THEN 6445
6440 GOTO 6450
6445 LET Z = 4
6450 IF Z = 4 THEN 6460
6455 GOTO 6540
6460 IF D = 4 THEN 6490
6465 IF Y(R, 6) = 0 THEN 6480
6470 CALL "cand": M(), Y(), X(), R
6475 GOTO 6540
6480 CALL "er": N(), X(), X$(), E, "TYPE_MISMATCH", "i64", "f64", "", 2
6485 GOTO 6540
6490 IF V <> 3 THEN 6540
6495 LET M(E, 7) = 1
6500 GOTO 6540
6505 CALL "fin": N(), M(), C(), X(), X$(), E
6510 CALL "opn": O - 1, A$
6515 CALL "tyn": T(), D, B$
6520 CALL "tyn": T(), M(E, 1), C$
6525 CALL "er": N(), X(), X$(), I, "BAD_OPERANDS", A$ & "=", B$, C$, 3
6530 GOTO 6540
6535 CALL "fin": N(), M(), C(), X(), X$(), E
6540 SUBEND
6545 REM ---- ck_tasg: (t1, ..., tn) = call (LANGUAGE 7.3, 8.4, 4.2 (b)): each result to its target ---
6550 SUB "ck_tasg": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
6555 LET H = N(I, 1)
6560 LET G = N(I, 7)
6565 FOR J = 1 TO H
6570 IF N(G, 0) = 11 THEN 6580
6575 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
6580 LET G = N(G, 8)
6585 NEXT J
6590 LET E = G
6595 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
6600 LET V = M(E, 1)
6605 LET V0 = 1
6610 IF V = 0 THEN 6675
6615 IF V = 1 THEN 6655
6620 IF V = -1 THEN 6645
6625 IF V < 10 THEN 6660
6630 IF T(V, 0) <> 7 THEN 6660
6635 LET V0 = T(V, 1)
6640 GOTO 6660
6645 CALL "fin": N(), M(), C(), X(), X$(), E
6650 GOTO 6660
6655 LET V0 = 0
6660 IF V0 = H THEN 6675
6665 CALL "er": N(), X(), X$(), I, "RESULT_COUNT", STR$(V0), STR$(H), "", 2
6670 LET V = 0
6675 LET G = N(I, 7)
6680 FOR J = 1 TO H
6685 REM M(target,4) = 1: the i64 result is converted to the f64 target (the cv flag of tasg)
6690 LET M(G, 4) = 0
6695 IF N(G, 0) = 11 THEN 6795
6700 CALL "ck_tgt": N(), M(), Y(), S$(), X(), X$(), G, R
6705 IF R = 0 THEN 6795
6710 IF V < 10 THEN 6795
6715 LET D = T(V + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9))
6720 LET D0 = M(G, 1)
6725 IF D = D0 THEN 6795
6730 IF D0 = 0 THEN 6795
6735 IF D <> 3 THEN 6755
6740 IF D0 <> 4 THEN 6755
6745 LET M(G, 4) = 1
6750 GOTO 6795
6755 IF Y(R, 6) = 0 THEN 6780
6760 IF D <> 4 THEN 6780
6765 IF D0 <> 3 THEN 6780
6770 CALL "cand": M(), Y(), X(), R
6775 GOTO 6795
6780 CALL "tyn": T(), D0, A$
6785 CALL "tyn": T(), D, B$
6790 CALL "er": N(), X(), X$(), G, "TYPE_MISMATCH", A$, B$, "", 2
6795 LET G = N(G, 8)
6800 NEXT J
6805 SUBEND
6810 REM ---- ck_ret: return I of the current function X(14) (LANGUAGE 8.1, 8.4); M(I,4) = 1: tret --
6815 SUB "ck_ret": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
6820 LET M(I, 4) = 0
6825 LET M(I, 9) = 1
6830 LET F = X(14)
6835 LET R0 = Y(F, 7)
6840 LET D = Y(F, 2)
6845 LET H = N(I, 1)
6850 LET E = N(I, 7)
6855 FOR J = 1 TO H
6860 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
6865 LET E = N(E, 8)
6870 NEXT J
6875 LET E = N(I, 7)
6880 IF H = 0 THEN 6975
6885 IF H = 1 THEN 6985
6890 IF R0 = H THEN 6925
6895 LET J = 1
6900 IF J > H THEN 7085
6905 CALL "fin": N(), M(), C(), X(), X$(), E
6910 LET E = N(E, 8)
6915 LET J = J + 1
6920 GOTO 6900
6925 REM return (e1, ..., ek): each value to its result type
6930 FOR J = 1 TO H
6935 LET D0 = T(D + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9))
6940 IF D = 0 THEN 6955
6945 CALL "cv": N(), M(), T(), C(), X(), X$(), E, D0
6950 GOTO 6960
6955 CALL "fin": N(), M(), C(), X(), X$(), E
6960 LET E = N(E, 8)
6965 NEXT J
6970 GOTO 7090
6975 IF R0 = 0 THEN 7090
6980 GOTO 7085
6985 LET V = M(E, 1)
6990 IF V < 10 THEN 7060
6995 IF T(V, 0) <> 7 THEN 7060
7000 REM return f(...) of a multiple-result call: tret when the results are exactly the function's
7005 IF R0 = 0 THEN 7050
7010 IF V = D THEN 7040
7015 IF D = 0 THEN 7090
7020 CALL "tyn": T(), D, A$
7025 CALL "tyn": T(), V, B$
7030 CALL "er": N(), X(), X$(), E, "TYPE_MISMATCH", A$, B$, "", 2
7035 GOTO 7090
7040 LET M(I, 4) = 1
7045 GOTO 7090
7050 CALL "er": N(), X(), X$(), I, "RESULT_COUNT", "0", STR$(T(V, 1)), "", 2
7055 GOTO 7090
7060 IF R0 <> 1 THEN 7075
7065 CALL "cv": N(), M(), T(), C(), X(), X$(), E, D
7070 GOTO 7090
7075 CALL "fin": N(), M(), C(), X(), X$(), E
7080 IF V = 0 THEN 7090
7085 CALL "er": N(), X(), X$(), I, "RESULT_COUNT", STR$(R0), STR$(H), "", 2
7090 SUBEND
