5145 REM ---- ck_blk: block B, a scope (LANGUAGE 7.2, 7.7); M(B,9) = 1 when a statement ends every path
5150 SUB "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
5155 LET M(B, 9) = 0
5160 CALL "sc_push": N(), W(), X(), X$(), B
5165 LET I = N(B, 7)
5170 IF I = 0 THEN 5200
5175 CALL "ck_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5180 IF M(I, 9) = 0 THEN 5190
5185 LET M(B, 9) = 1
5190 LET I = N(I, 8)
5195 GOTO 5170
5200 CALL "sc_pop": W(), X()
5205 SUBEND
5210 REM ---- sc_push / sc_pop: open and close a scope (marker -1 on the scope stack in W) -----------
5215 SUB "sc_push": N(), W(), X(), X$(), I
5220 IF X(12) - 2 > X(11) THEN 5235
5225 CALL "fatal": N(), X(), X$(), I, "symbols"
5230 GOTO 5245
5235 LET X(12) = X(12) - 2
5240 LET W(X(12)) = -1
5245 SUBEND
5250 SUB "sc_pop": W(), X()
5255 IF X(12) >= 200000 THEN 5280
5260 IF W(X(12)) = -1 THEN 5275
5265 LET X(12) = X(12) + 2
5270 GOTO 5255
5275 LET X(12) = X(12) + 2
5280 SUBEND
5285 REM ---- fin: an untyped constant that no context typed is i64 (LANGUAGE 4.2) ------------------
5290 SUB "fin": N(), M(), C(), X(), X$(), I
5295 IF M(I, 1) <> -1 THEN 5305
5300 CALL "stl": N(), M(), C(), X(), X$(), I, 3
5305 SUBEND
5310 REM ---- ck_cond: condition I must be a scalar bool (LANGUAGE 4.3) -----------------------------
5315 SUB "ck_cond": N(), M(), T(), C(), X(), X$(), I
5320 CALL "vu": N(), M(), T(), X(), X$(), I, D
5325 IF D <> -1 THEN 5340
5330 CALL "stl": N(), M(), C(), X(), X$(), I, 3
5335 LET D = 3
5340 IF D = 2 THEN 5355
5345 IF D = 0 THEN 5355
5350 CALL "er": N(), X(), X$(), I, "COND_BOOL", "", "", "", 0
5355 SUBEND
5360 REM ---- ck_tgt: R = the local assigned by target G (a var or a ref parameter, LANGUAGE 7.3), or
5365 REM 0 after an error: immutable locals, constants, functions and other expressions ----------
5370 SUB "ck_tgt": N(), M(), Y(), S$(), X(), X$(), G, R
5375 LET R = 0
5380 IF N(G, 0) = 30 THEN 5400
5385 IF M(G, 1) = 0 THEN 5455
5390 CALL "er": N(), X(), X$(), G, "BAD_TARGET", "", "", "", 0
5395 GOTO 5455
5400 LET S = M(G, 2)
5405 IF S = 0 THEN 5455
5410 IF S < 0 THEN 5450
5415 IF Y(S, 0) <> 4 THEN 5450
5420 IF Y(S, 4) = 2 THEN 5440
5425 IF Y(S, 4) = 5 THEN 5440
5430 CALL "er": N(), X(), X$(), G, "ASSIGN_IMMUTABLE", S$(N(G, 6)), "", "", 1
5435 GOTO 5455
5440 LET R = S
5445 GOTO 5455
5450 CALL "er": N(), X(), X$(), G, "BAD_TARGET", "", "", "", 0
5455 SUBEND
5460 REM ---- ck_st: statement I (LANGUAGE 7.1-7.6) ---------------------------------------------
5465 SUB "ck_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5470 LET M(I, 9) = 0
5475 LET X(19) = I
5480 LET K = N(I, 0)
5485 IF K < 8 THEN 5825
5490 IF K > 24 THEN 5825
5495 ON K - 7 GOTO 5500, 5500, 5825, 5825, 5825, 5510, 5520, 5530, 5540, 5665, 5700, 5770, 5825, 5780, 5795, 5810, 5820
5500 CALL "ck_let": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5505 GOTO 5825
5510 CALL "ck_asg": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5515 GOTO 5825
5520 CALL "ck_tasg": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5525 GOTO 5825
5530 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(I, 7)
5535 GOTO 5825
5540 REM an else-if chain is walked here link by link (no recursion over its length); it ends
5545 REM every path when every block does and the chain ends with an else block
5550 LET L1 = I
5555 LET Z = 1
5560 LET X(19) = L1
5565 LET M(L1, 9) = 0
5570 LET E = N(L1, 7)
5575 LET B = N(E, 8)
5580 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
5585 CALL "ck_cond": N(), M(), T(), C(), X(), X$(), E
5590 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
5595 IF M(B, 9) = 1 THEN 5605
5600 LET Z = 0
5605 IF N(L1, 1) = 1 THEN 5620
5610 LET Z = 0
5615 GOTO 5655
5620 LET G = N(B, 8)
5625 IF N(G, 0) = 24 THEN 5640
5630 LET L1 = G
5635 GOTO 5560
5640 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
5645 IF M(G, 9) = 1 THEN 5655
5650 LET Z = 0
5655 LET M(I, 9) = Z
5660 GOTO 5825
5665 LET E = N(I, 7)
5670 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
5675 CALL "ck_cond": N(), M(), T(), C(), X(), X$(), E
5680 LET X(15) = X(15) + 1
5685 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(E, 8)
5690 LET X(15) = X(15) - 1
5695 GOTO 5825
5700 REM a range loop; any other iterable is an array (phase 1: not supported yet)
5705 LET E = N(I, 7)
5710 IF N(E, 0) = 41 THEN 5725
5715 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "arrays", "", "", 1
5720 GOTO 5825
5725 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
5730 CALL "sc_push": N(), W(), X(), X$(), I
5735 CALL "nloc": N(), Y(), W(), X(), X$(), S$(), N(I, 6), 3, 3, I, 1, R
5740 LET M(I, 2) = R
5745 LET X(15) = X(15) + 1
5750 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(E, 8)
5755 LET X(15) = X(15) - 1
5760 CALL "sc_pop": W(), X()
5765 GOTO 5825
5770 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "match", "", "", 1
5775 GOTO 5825
5780 IF X(15) > 0 THEN 5825
5785 CALL "er": N(), X(), X$(), I, "BREAK_OUTSIDE", "", "", "", 0
5790 GOTO 5825
5795 IF X(15) > 0 THEN 5825
5800 CALL "er": N(), X(), X$(), I, "CONTINUE_OUTSIDE", "", "", "", 0
5805 GOTO 5825
5810 CALL "ck_ret": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5815 GOTO 5825
5820 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5825 SUBEND
5830 REM ---- ck_let: let/var I: pattern, [type], value (LANGUAGE 7.2, 4.2, 8.4) --------------------
5835 SUB "ck_let": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5840 LET P = N(I, 7)
5845 LET E = N(P, 8)
5850 LET D = 0
5855 LET Z0 = 0
5860 LET A = N(I, 1)
5865 IF A = 0 THEN 5880
5870 LET G = E
5875 LET E = N(E, 8)
5880 LET U = N(I, 0) - 7
5885 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
5890 IF A = 0 THEN 5955
5895 CALL "tyof": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G, D
5900 IF N(P, 0) = 12 THEN 5955
5905 REM a multiple-result call for one name or _ is a result count error, before any conversion
5910 LET V = M(E, 1)
5915 IF V < 10 THEN 5935
5920 IF T(V, 0) <> 7 THEN 5935
5925 CALL "er": N(), X(), X$(), E, "RESULT_COUNT", STR$(T(V, 1)), "1", "", 2
5930 GOTO 5955
5935 IF D = 0 THEN 5950
5940 CALL "cv": N(), M(), T(), C(), X(), X$(), E, D
5945 GOTO 5955
5950 CALL "fin": N(), M(), C(), X(), X$(), E
5955 LET K = N(P, 0)
5960 IF K = 11 THEN 6095
5965 IF K = 12 THEN 6110
5970 REM one name: its type is the annotation, or the value's
5975 IF A = 1 THEN 6060
5980 LET D = M(E, 1)
5985 IF D < 10 THEN 6010
5990 IF T(D, 0) <> 7 THEN 6010
5995 CALL "er": N(), X(), X$(), E, "RESULT_COUNT", STR$(T(D, 1)), "1", "", 2
6000 LET D = 0
6005 GOTO 6060
6010 IF D <> -1 THEN 6055
6015 REM an untyped constant: i64, or for an unannotated var the candidate of the var rule
6020 LET D = 3
6025 IF U = 1 THEN 6045
6030 LET Z0 = 1
6035 IF M(P, 4) = 0 THEN 6045
6040 LET D = 4
6045 CALL "stl": N(), M(), C(), X(), X$(), E, D
6050 GOTO 6060
6055 CALL "vu": N(), M(), T(), X(), X$(), E, D
6060 CALL "nloc": N(), Y(), W(), X(), X$(), S$(), N(P, 6), D, U, P, 1, R
6065 LET M(P, 2) = R
6070 IF R = 0 THEN 6285
6075 IF Z0 = 0 THEN 6285
6080 REM the candidate of the var rule: an unannotated var whose initialiser was untyped
6085 LET Y(R, 6) = P
6090 GOTO 6285
6095 IF A = 1 THEN 6285
6100 CALL "fin": N(), M(), C(), X(), X$(), E
6105 GOTO 6285
6110 REM a tuple pattern: one name or _ per result of a multiple-result call
6115 LET H = N(P, 1)
6120 LET V = M(E, 1)
6125 LET V0 = 1
6130 IF V = 0 THEN 6180
6135 IF V = -1 THEN 6165
6140 IF V = 1 THEN 6175
6145 IF V < 10 THEN 6180
6150 IF T(V, 0) <> 7 THEN 6180
6155 LET V0 = T(V, 1)
6160 GOTO 6180
6165 CALL "fin": N(), M(), C(), X(), X$(), E
6170 GOTO 6180
6175 LET V0 = 0
6180 IF A = 0 THEN 6215
6185 IF D = 0 THEN 6215
6190 IF V = 0 THEN 6215
6195 CALL "tyn": T(), D, A$
6200 CALL "tyn": T(), V, B$
6205 CALL "er": N(), X(), X$(), E, "TYPE_MISMATCH", A$, B$, "", 2
6210 LET V = 0
6215 IF V = 0 THEN 6235
6220 IF V0 = H THEN 6235
6225 CALL "er": N(), X(), X$(), P, "RESULT_COUNT", STR$(V0), STR$(H), "", 2
6230 LET V = 0
6235 LET Q = N(P, 7)
6240 FOR J = 1 TO H
6245 IF N(Q, 0) <> 10 THEN 6275
6250 LET D = 0
6255 IF V < 10 THEN 6265
6260 LET D = T(V + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9))
6265 CALL "nloc": N(), Y(), W(), X(), X$(), S$(), N(Q, 6), D, U, Q, 1, R
6270 LET M(Q, 2) = R
6275 LET Q = N(Q, 8)
6280 NEXT J
6285 SUBEND
6290 REM ---- ck_asg: target op= value (LANGUAGE 7.3; x op= e is x = x op e) ------------------------
6295 SUB "ck_asg": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
6300 LET G = N(I, 7)
6305 LET E = N(G, 8)
6310 LET O = N(I, 1)
6315 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
6320 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
6325 CALL "ck_tgt": N(), M(), Y(), S$(), X(), X$(), G, R
6330 LET D = M(G, 1)
6335 IF R = 0 THEN 6585
6340 IF D = 0 THEN 6585
6345 IF O > 1 THEN 6420
6350 REM =: a multiple-result call to one target is a result count error (LANGUAGE 8.4)
6355 LET V = M(E, 1)
6360 IF V < 10 THEN 6380
6365 IF T(V, 0) <> 7 THEN 6380
6370 CALL "er": N(), X(), X$(), E, "RESULT_COUNT", STR$(T(V, 1)), "1", "", 2
6375 GOTO 6590
6380 REM a candidate var stores an f64 (Decision 8), else the value converts to the target
6385 IF Y(R, 6) = 0 THEN 6410
6390 IF D <> 3 THEN 6410
6395 IF M(E, 1) <> 4 THEN 6410
6400 CALL "cand": M(), Y(), X(), R
6405 GOTO 6590
6410 CALL "cv": N(), M(), T(), C(), X(), X$(), E, D
6415 GOTO 6590
6420 CALL "vu": N(), M(), T(), X(), X$(), E, V
6425 IF V = 0 THEN 6590
6430 IF D = 2 THEN 6555
6435 IF V = 2 THEN 6555
6440 IF V > 4 THEN 6555
6445 IF D > 4 THEN 6555
6450 IF V <> -1 THEN 6465
6455 CALL "stl": N(), M(), C(), X(), X$(), E, D
6460 LET V = M(E, 1)
6465 REM the result of x op e: f64 for / and beside an f64, else i64 (LANGUAGE 6.5)
6470 LET Z = 3
6475 IF O = 5 THEN 6495
6480 IF D = 4 THEN 6495
6485 IF V = 4 THEN 6495
6490 GOTO 6500
6495 LET Z = 4
6500 IF Z = 4 THEN 6510
6505 GOTO 6590
6510 IF D = 4 THEN 6540
6515 IF Y(R, 6) = 0 THEN 6530
6520 CALL "cand": M(), Y(), X(), R
6525 GOTO 6590
6530 CALL "er": N(), X(), X$(), E, "TYPE_MISMATCH", "i64", "f64", "", 2
6535 GOTO 6590
6540 IF V <> 3 THEN 6590
6545 LET M(E, 7) = 1
6550 GOTO 6590
6555 CALL "fin": N(), M(), C(), X(), X$(), E
6560 CALL "opn": O - 1, A$
6565 CALL "tyn": T(), D, B$
6570 CALL "tyn": T(), M(E, 1), C$
6575 CALL "er": N(), X(), X$(), I, "BAD_OPERANDS", A$ & "=", B$, C$, 3
6580 GOTO 6590
6585 CALL "fin": N(), M(), C(), X(), X$(), E
6590 SUBEND
6595 REM ---- ck_tasg: (t1, ..., tn) = call (LANGUAGE 7.3, 8.4, 4.2 (b)): each result to its target ---
6600 SUB "ck_tasg": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
6605 LET H = N(I, 1)
6610 LET G = N(I, 7)
6615 FOR J = 1 TO H
6620 IF N(G, 0) = 11 THEN 6630
6625 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
6630 LET G = N(G, 8)
6635 NEXT J
6640 LET E = G
6645 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
6650 LET V = M(E, 1)
6655 LET V0 = 1
6660 IF V = 0 THEN 6725
6665 IF V = 1 THEN 6705
6670 IF V = -1 THEN 6695
6675 IF V < 10 THEN 6710
6680 IF T(V, 0) <> 7 THEN 6710
6685 LET V0 = T(V, 1)
6690 GOTO 6710
6695 CALL "fin": N(), M(), C(), X(), X$(), E
6700 GOTO 6710
6705 LET V0 = 0
6710 IF V0 = H THEN 6725
6715 CALL "er": N(), X(), X$(), I, "RESULT_COUNT", STR$(V0), STR$(H), "", 2
6720 LET V = 0
6725 LET G = N(I, 7)
6730 FOR J = 1 TO H
6735 REM M(target,4) = 1: the i64 result is converted to the f64 target (the cv flag of tasg)
6740 LET M(G, 4) = 0
6745 IF N(G, 0) = 11 THEN 6845
6750 CALL "ck_tgt": N(), M(), Y(), S$(), X(), X$(), G, R
6755 IF R = 0 THEN 6845
6760 IF V < 10 THEN 6845
6765 LET D = T(V + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9))
6770 LET D0 = M(G, 1)
6775 IF D = D0 THEN 6845
6780 IF D0 = 0 THEN 6845
6785 IF D <> 3 THEN 6805
6790 IF D0 <> 4 THEN 6805
6795 LET M(G, 4) = 1
6800 GOTO 6845
6805 IF Y(R, 6) = 0 THEN 6830
6810 IF D <> 4 THEN 6830
6815 IF D0 <> 3 THEN 6830
6820 CALL "cand": M(), Y(), X(), R
6825 GOTO 6845
6830 CALL "tyn": T(), D0, A$
6835 CALL "tyn": T(), D, B$
6840 CALL "er": N(), X(), X$(), G, "TYPE_MISMATCH", A$, B$, "", 2
6845 LET G = N(G, 8)
6850 NEXT J
6855 SUBEND
6860 REM ---- ck_ret: return I of the current function X(14) (LANGUAGE 8.1, 8.4); M(I,4) = 1: tret --
6865 SUB "ck_ret": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
6870 LET M(I, 4) = 0
6875 LET M(I, 9) = 1
6880 LET F = X(14)
6885 LET R0 = Y(F, 7)
6890 LET D = Y(F, 2)
6895 LET H = N(I, 1)
6900 LET E = N(I, 7)
6905 FOR J = 1 TO H
6910 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
6915 LET E = N(E, 8)
6920 NEXT J
6925 LET E = N(I, 7)
6930 IF H = 0 THEN 7025
6935 IF H = 1 THEN 7035
6940 IF R0 = H THEN 6975
6945 LET J = 1
6950 IF J > H THEN 7135
6955 CALL "fin": N(), M(), C(), X(), X$(), E
6960 LET E = N(E, 8)
6965 LET J = J + 1
6970 GOTO 6950
6975 REM return (e1, ..., ek): each value to its result type
6980 FOR J = 1 TO H
6985 LET D0 = T(D + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9))
6990 IF D = 0 THEN 7005
6995 CALL "cv": N(), M(), T(), C(), X(), X$(), E, D0
7000 GOTO 7010
7005 CALL "fin": N(), M(), C(), X(), X$(), E
7010 LET E = N(E, 8)
7015 NEXT J
7020 GOTO 7140
7025 IF R0 = 0 THEN 7140
7030 GOTO 7135
7035 LET V = M(E, 1)
7040 IF V < 10 THEN 7110
7045 IF T(V, 0) <> 7 THEN 7110
7050 REM return f(...) of a multiple-result call: tret when the results are exactly the function's
7055 IF R0 = 0 THEN 7100
7060 IF V = D THEN 7090
7065 IF D = 0 THEN 7140
7070 CALL "tyn": T(), D, A$
7075 CALL "tyn": T(), V, B$
7080 CALL "er": N(), X(), X$(), E, "TYPE_MISMATCH", A$, B$, "", 2
7085 GOTO 7140
7090 LET M(I, 4) = 1
7095 GOTO 7140
7100 CALL "er": N(), X(), X$(), I, "RESULT_COUNT", "0", STR$(T(V, 1)), "", 2
7105 GOTO 7140
7110 IF R0 <> 1 THEN 7125
7115 CALL "cv": N(), M(), T(), C(), X(), X$(), E, D
7120 GOTO 7140
7125 CALL "fin": N(), M(), C(), X(), X$(), E
7130 IF V = 0 THEN 7140
7135 CALL "er": N(), X(), X$(), I, "RESULT_COUNT", STR$(R0), STR$(H), "", 2
7140 SUBEND
