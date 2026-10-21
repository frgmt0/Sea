5045 REM ---- ck_blk: block B, a scope (LANGUAGE 7.2, 7.7); M(B,9) = 1 when a statement ends every path
5050 SUB "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
5055 LET M(B, 9) = 0
5060 CALL "sc_push": N(), W(), X(), X$(), B
5065 LET I = N(B, 7)
5070 IF I = 0 THEN 5100
5075 CALL "ck_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5080 IF M(I, 9) = 0 THEN 5090
5085 LET M(B, 9) = 1
5090 LET I = N(I, 8)
5095 GOTO 5070
5100 CALL "sc_pop": W(), X()
5105 SUBEND
5110 REM ---- sc_push / sc_pop: open and close a scope (marker -1 on the scope stack in W) -----------
5115 SUB "sc_push": N(), W(), X(), X$(), I
5120 IF X(12) - 2 > X(11) THEN 5135
5125 CALL "fatal": N(), X(), X$(), I, "symbols"
5130 GOTO 5145
5135 LET X(12) = X(12) - 2
5140 LET W(X(12)) = -1
5145 SUBEND
5150 SUB "sc_pop": W(), X()
5155 IF X(12) >= 200000 THEN 5180
5160 IF W(X(12)) = -1 THEN 5175
5165 LET X(12) = X(12) + 2
5170 GOTO 5155
5175 LET X(12) = X(12) + 2
5180 SUBEND
5185 REM ---- fin: an untyped constant that no context typed is i64 (LANGUAGE 4.2) ------------------
5190 SUB "fin": N(), M(), C(), X(), X$(), I
5195 IF M(I, 1) <> -1 THEN 5205
5200 CALL "stl": N(), M(), C(), X(), X$(), I, 3
5205 SUBEND
5210 REM ---- ck_cond: condition I must be a scalar bool (LANGUAGE 4.3) -----------------------------
5215 SUB "ck_cond": N(), M(), T(), C(), X(), X$(), I
5220 CALL "vu": N(), M(), T(), X(), X$(), I, D
5225 IF D <> -1 THEN 5240
5230 CALL "stl": N(), M(), C(), X(), X$(), I, 3
5235 LET D = 3
5240 IF D = 2 THEN 5255
5245 IF D = 0 THEN 5255
5250 CALL "er": N(), X(), X$(), I, "COND_BOOL", "", "", "", 0
5255 SUBEND
5260 REM ---- ck_tgt: R = the local assigned by target G (a var or a ref parameter, LANGUAGE 7.3), or
5265 REM 0 after an error: immutable locals, constants, functions and other expressions ----------
5270 SUB "ck_tgt": N(), M(), Y(), S$(), X(), X$(), G, R
5275 LET R = 0
5280 IF N(G, 0) = 30 THEN 5300
5285 IF M(G, 1) = 0 THEN 5355
5290 CALL "er": N(), X(), X$(), G, "BAD_TARGET", "", "", "", 0
5295 GOTO 5355
5300 LET S = M(G, 2)
5305 IF S = 0 THEN 5355
5310 IF S < 0 THEN 5350
5315 IF Y(S, 0) <> 4 THEN 5350
5320 IF Y(S, 4) = 2 THEN 5340
5325 IF Y(S, 4) = 5 THEN 5340
5330 CALL "er": N(), X(), X$(), G, "ASSIGN_IMMUTABLE", S$(N(G, 6)), "", "", 1
5335 GOTO 5355
5340 LET R = S
5345 GOTO 5355
5350 CALL "er": N(), X(), X$(), G, "BAD_TARGET", "", "", "", 0
5355 SUBEND
5360 REM ---- ck_st: statement I (LANGUAGE 7.1-7.6) ---------------------------------------------
5365 SUB "ck_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5370 LET M(I, 9) = 0
5375 LET X(19) = I
5380 LET K = N(I, 0)
5385 IF K < 8 THEN 5725
5390 IF K > 24 THEN 5725
5395 ON K - 7 GOTO 5400, 5400, 5725, 5725, 5725, 5410, 5420, 5430, 5440, 5565, 5600, 5670, 5725, 5680, 5695, 5710, 5720
5400 CALL "ck_let": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5405 GOTO 5725
5410 CALL "ck_asg": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5415 GOTO 5725
5420 CALL "ck_tasg": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5425 GOTO 5725
5430 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(I, 7)
5435 GOTO 5725
5440 REM an else-if chain is walked here link by link (no recursion over its length); it ends
5445 REM every path when every block does and the chain ends with an else block
5450 LET L1 = I
5455 LET Z = 1
5460 LET X(19) = L1
5465 LET M(L1, 9) = 0
5470 LET E = N(L1, 7)
5475 LET B = N(E, 8)
5480 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
5485 CALL "ck_cond": N(), M(), T(), C(), X(), X$(), E
5490 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
5495 IF M(B, 9) = 1 THEN 5505
5500 LET Z = 0
5505 IF N(L1, 1) = 1 THEN 5520
5510 LET Z = 0
5515 GOTO 5555
5520 LET G = N(B, 8)
5525 IF N(G, 0) = 24 THEN 5540
5530 LET L1 = G
5535 GOTO 5460
5540 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
5545 IF M(G, 9) = 1 THEN 5555
5550 LET Z = 0
5555 LET M(I, 9) = Z
5560 GOTO 5725
5565 LET E = N(I, 7)
5570 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
5575 CALL "ck_cond": N(), M(), T(), C(), X(), X$(), E
5580 LET X(15) = X(15) + 1
5585 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(E, 8)
5590 LET X(15) = X(15) - 1
5595 GOTO 5725
5600 REM a range loop; any other iterable is an array (phase 1: not supported yet)
5605 LET E = N(I, 7)
5610 IF N(E, 0) = 41 THEN 5625
5615 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "arrays", "", "", 1
5620 GOTO 5725
5625 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
5630 CALL "sc_push": N(), W(), X(), X$(), I
5635 CALL "nloc": N(), Y(), W(), X(), X$(), S$(), N(I, 6), 3, 3, I, 1, R
5640 LET M(I, 2) = R
5645 LET X(15) = X(15) + 1
5650 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(E, 8)
5655 LET X(15) = X(15) - 1
5660 CALL "sc_pop": W(), X()
5665 GOTO 5725
5670 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "match", "", "", 1
5675 GOTO 5725
5680 IF X(15) > 0 THEN 5725
5685 CALL "er": N(), X(), X$(), I, "BREAK_OUTSIDE", "", "", "", 0
5690 GOTO 5725
5695 IF X(15) > 0 THEN 5725
5700 CALL "er": N(), X(), X$(), I, "CONTINUE_OUTSIDE", "", "", "", 0
5705 GOTO 5725
5710 CALL "ck_ret": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5715 GOTO 5725
5720 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5725 SUBEND
5730 REM ---- ck_let: let/var I: pattern, [type], value (LANGUAGE 7.2, 4.2, 8.4) --------------------
5735 SUB "ck_let": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5740 LET P = N(I, 7)
5745 LET E = N(P, 8)
5750 LET D = 0
5755 LET Z0 = 0
5760 LET A = N(I, 1)
5765 IF A = 0 THEN 5780
5770 LET G = E
5775 LET E = N(E, 8)
5780 LET U = N(I, 0) - 7
5785 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
5790 IF A = 0 THEN 5855
5795 CALL "tyof": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G, D
5800 IF N(P, 0) = 12 THEN 5855
5805 REM a multiple-result call for one name or _ is a result count error, before any conversion
5810 LET V = M(E, 1)
5815 IF V < 10 THEN 5835
5820 IF T(V, 0) <> 7 THEN 5835
5825 CALL "er": N(), X(), X$(), E, "RESULT_COUNT", STR$(T(V, 1)), "1", "", 2
5830 GOTO 5855
5835 IF D = 0 THEN 5850
5840 CALL "cv": N(), M(), T(), C(), X(), X$(), E, D
5845 GOTO 5855
5850 CALL "fin": N(), M(), C(), X(), X$(), E
5855 LET K = N(P, 0)
5860 IF K = 11 THEN 5995
5865 IF K = 12 THEN 6010
5870 REM one name: its type is the annotation, or the value's
5875 IF A = 1 THEN 5960
5880 LET D = M(E, 1)
5885 IF D < 10 THEN 5910
5890 IF T(D, 0) <> 7 THEN 5910
5895 CALL "er": N(), X(), X$(), E, "RESULT_COUNT", STR$(T(D, 1)), "1", "", 2
5900 LET D = 0
5905 GOTO 5960
5910 IF D <> -1 THEN 5955
5915 REM an untyped constant: i64, or for an unannotated var the candidate of the var rule
5920 LET D = 3
5925 IF U = 1 THEN 5945
5930 LET Z0 = 1
5935 IF M(P, 4) = 0 THEN 5945
5940 LET D = 4
5945 CALL "stl": N(), M(), C(), X(), X$(), E, D
5950 GOTO 5960
5955 CALL "vu": N(), M(), T(), X(), X$(), E, D
5960 CALL "nloc": N(), Y(), W(), X(), X$(), S$(), N(P, 6), D, U, P, 1, R
5965 LET M(P, 2) = R
5970 IF R = 0 THEN 6185
5975 IF Z0 = 0 THEN 6185
5980 REM the candidate of the var rule: an unannotated var whose initialiser was untyped
5985 LET Y(R, 6) = P
5990 GOTO 6185
5995 IF A = 1 THEN 6185
6000 CALL "fin": N(), M(), C(), X(), X$(), E
6005 GOTO 6185
6010 REM a tuple pattern: one name or _ per result of a multiple-result call
6015 LET H = N(P, 1)
6020 LET V = M(E, 1)
6025 LET V0 = 1
6030 IF V = 0 THEN 6080
6035 IF V = -1 THEN 6065
6040 IF V = 1 THEN 6075
6045 IF V < 10 THEN 6080
6050 IF T(V, 0) <> 7 THEN 6080
6055 LET V0 = T(V, 1)
6060 GOTO 6080
6065 CALL "fin": N(), M(), C(), X(), X$(), E
6070 GOTO 6080
6075 LET V0 = 0
6080 IF A = 0 THEN 6115
6085 IF D = 0 THEN 6115
6090 IF V = 0 THEN 6115
6095 CALL "tyn": T(), D, A$
6100 CALL "tyn": T(), V, B$
6105 CALL "er": N(), X(), X$(), E, "TYPE_MISMATCH", A$, B$, "", 2
6110 LET V = 0
6115 IF V = 0 THEN 6135
6120 IF V0 = H THEN 6135
6125 CALL "er": N(), X(), X$(), P, "RESULT_COUNT", STR$(V0), STR$(H), "", 2
6130 LET V = 0
6135 LET Q = N(P, 7)
6140 FOR J = 1 TO H
6145 IF N(Q, 0) <> 10 THEN 6175
6150 LET D = 0
6155 IF V < 10 THEN 6165
6160 LET D = T(V + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9))
6165 CALL "nloc": N(), Y(), W(), X(), X$(), S$(), N(Q, 6), D, U, Q, 1, R
6170 LET M(Q, 2) = R
6175 LET Q = N(Q, 8)
6180 NEXT J
6185 SUBEND
6190 REM ---- ck_asg: target op= value (LANGUAGE 7.3; x op= e is x = x op e) ------------------------
6195 SUB "ck_asg": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
6200 LET G = N(I, 7)
6205 LET E = N(G, 8)
6210 LET O = N(I, 1)
6215 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
6220 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
6225 CALL "ck_tgt": N(), M(), Y(), S$(), X(), X$(), G, R
6230 LET D = M(G, 1)
6235 IF R = 0 THEN 6485
6240 IF D = 0 THEN 6485
6245 IF O > 1 THEN 6320
6250 REM =: a multiple-result call to one target is a result count error (LANGUAGE 8.4)
6255 LET V = M(E, 1)
6260 IF V < 10 THEN 6280
6265 IF T(V, 0) <> 7 THEN 6280
6270 CALL "er": N(), X(), X$(), E, "RESULT_COUNT", STR$(T(V, 1)), "1", "", 2
6275 GOTO 6490
6280 REM a candidate var stores an f64 (Decision 8), else the value converts to the target
6285 IF Y(R, 6) = 0 THEN 6310
6290 IF D <> 3 THEN 6310
6295 IF M(E, 1) <> 4 THEN 6310
6300 CALL "cand": M(), Y(), X(), R
6305 GOTO 6490
6310 CALL "cv": N(), M(), T(), C(), X(), X$(), E, D
6315 GOTO 6490
6320 CALL "vu": N(), M(), T(), X(), X$(), E, V
6325 IF V = 0 THEN 6490
6330 IF D = 2 THEN 6455
6335 IF V = 2 THEN 6455
6340 IF V > 4 THEN 6455
6345 IF D > 4 THEN 6455
6350 IF V <> -1 THEN 6365
6355 CALL "stl": N(), M(), C(), X(), X$(), E, D
6360 LET V = M(E, 1)
6365 REM the result of x op e: f64 for / and beside an f64, else i64 (LANGUAGE 6.5)
6370 LET Z = 3
6375 IF O = 5 THEN 6395
6380 IF D = 4 THEN 6395
6385 IF V = 4 THEN 6395
6390 GOTO 6400
6395 LET Z = 4
6400 IF Z = 4 THEN 6410
6405 GOTO 6490
6410 IF D = 4 THEN 6440
6415 IF Y(R, 6) = 0 THEN 6430
6420 CALL "cand": M(), Y(), X(), R
6425 GOTO 6490
6430 CALL "er": N(), X(), X$(), E, "TYPE_MISMATCH", "i64", "f64", "", 2
6435 GOTO 6490
6440 IF V <> 3 THEN 6490
6445 LET M(E, 7) = 1
6450 GOTO 6490
6455 CALL "fin": N(), M(), C(), X(), X$(), E
6460 CALL "opn": O - 1, A$
6465 CALL "tyn": T(), D, B$
6470 CALL "tyn": T(), M(E, 1), C$
6475 CALL "er": N(), X(), X$(), I, "BAD_OPERANDS", A$ & "=", B$, C$, 3
6480 GOTO 6490
6485 CALL "fin": N(), M(), C(), X(), X$(), E
6490 SUBEND
6495 REM ---- ck_tasg: (t1, ..., tn) = call (LANGUAGE 7.3, 8.4, 4.2 (b)): each result to its target ---
6500 SUB "ck_tasg": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
6505 LET H = N(I, 1)
6510 LET G = N(I, 7)
6515 FOR J = 1 TO H
6520 IF N(G, 0) = 11 THEN 6530
6525 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
6530 LET G = N(G, 8)
6535 NEXT J
6540 LET E = G
6545 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
6550 LET V = M(E, 1)
6555 LET V0 = 1
6560 IF V = 0 THEN 6625
6565 IF V = 1 THEN 6605
6570 IF V = -1 THEN 6595
6575 IF V < 10 THEN 6610
6580 IF T(V, 0) <> 7 THEN 6610
6585 LET V0 = T(V, 1)
6590 GOTO 6610
6595 CALL "fin": N(), M(), C(), X(), X$(), E
6600 GOTO 6610
6605 LET V0 = 0
6610 IF V0 = H THEN 6625
6615 CALL "er": N(), X(), X$(), I, "RESULT_COUNT", STR$(V0), STR$(H), "", 2
6620 LET V = 0
6625 LET G = N(I, 7)
6630 FOR J = 1 TO H
6635 REM M(target,4) = 1: the i64 result is converted to the f64 target (the cv flag of tasg)
6640 LET M(G, 4) = 0
6645 IF N(G, 0) = 11 THEN 6745
6650 CALL "ck_tgt": N(), M(), Y(), S$(), X(), X$(), G, R
6655 IF R = 0 THEN 6745
6660 IF V < 10 THEN 6745
6665 LET D = T(V + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9))
6670 LET D0 = M(G, 1)
6675 IF D = D0 THEN 6745
6680 IF D0 = 0 THEN 6745
6685 IF D <> 3 THEN 6705
6690 IF D0 <> 4 THEN 6705
6695 LET M(G, 4) = 1
6700 GOTO 6745
6705 IF Y(R, 6) = 0 THEN 6730
6710 IF D <> 4 THEN 6730
6715 IF D0 <> 3 THEN 6730
6720 CALL "cand": M(), Y(), X(), R
6725 GOTO 6745
6730 CALL "tyn": T(), D0, A$
6735 CALL "tyn": T(), D, B$
6740 CALL "er": N(), X(), X$(), G, "TYPE_MISMATCH", A$, B$, "", 2
6745 LET G = N(G, 8)
6750 NEXT J
6755 SUBEND
6760 REM ---- ck_ret: return I of the current function X(14) (LANGUAGE 8.1, 8.4); M(I,4) = 1: tret --
6765 SUB "ck_ret": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
6770 LET M(I, 4) = 0
6775 LET M(I, 9) = 1
6780 LET F = X(14)
6785 LET R0 = Y(F, 7)
6790 LET D = Y(F, 2)
6795 LET H = N(I, 1)
6800 LET E = N(I, 7)
6805 FOR J = 1 TO H
6810 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
6815 LET E = N(E, 8)
6820 NEXT J
6825 LET E = N(I, 7)
6830 IF H = 0 THEN 6925
6835 IF H = 1 THEN 6935
6840 IF R0 = H THEN 6875
6845 LET J = 1
6850 IF J > H THEN 7035
6855 CALL "fin": N(), M(), C(), X(), X$(), E
6860 LET E = N(E, 8)
6865 LET J = J + 1
6870 GOTO 6850
6875 REM return (e1, ..., ek): each value to its result type
6880 FOR J = 1 TO H
6885 LET D0 = T(D + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9))
6890 IF D = 0 THEN 6905
6895 CALL "cv": N(), M(), T(), C(), X(), X$(), E, D0
6900 GOTO 6910
6905 CALL "fin": N(), M(), C(), X(), X$(), E
6910 LET E = N(E, 8)
6915 NEXT J
6920 GOTO 7040
6925 IF R0 = 0 THEN 7040
6930 GOTO 7035
6935 LET V = M(E, 1)
6940 IF V < 10 THEN 7010
6945 IF T(V, 0) <> 7 THEN 7010
6950 REM return f(...) of a multiple-result call: tret when the results are exactly the function's
6955 IF R0 = 0 THEN 7000
6960 IF V = D THEN 6990
6965 IF D = 0 THEN 7040
6970 CALL "tyn": T(), D, A$
6975 CALL "tyn": T(), V, B$
6980 CALL "er": N(), X(), X$(), E, "TYPE_MISMATCH", A$, B$, "", 2
6985 GOTO 7040
6990 LET M(I, 4) = 1
6995 GOTO 7040
7000 CALL "er": N(), X(), X$(), I, "RESULT_COUNT", "0", STR$(T(V, 1)), "", 2
7005 GOTO 7040
7010 IF R0 <> 1 THEN 7025
7015 CALL "cv": N(), M(), T(), C(), X(), X$(), E, D
7020 GOTO 7040
7025 CALL "fin": N(), M(), C(), X(), X$(), E
7030 IF V = 0 THEN 7040
7035 CALL "er": N(), X(), X$(), I, "RESULT_COUNT", STR$(R0), STR$(H), "", 2
7040 SUBEND
