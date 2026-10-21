4860 REM ---- ck_blk: block B, a scope (LANGUAGE 7.2, 7.7); M(B,9) = 1 when a statement ends every path
4865 SUB "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
4870 LET M(B, 9) = 0
4875 CALL "sc_push": N(), W(), X(), X$(), B
4880 LET I = N(B, 7)
4885 IF I = 0 THEN 4915
4890 CALL "ck_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
4895 IF M(I, 9) = 0 THEN 4905
4900 LET M(B, 9) = 1
4905 LET I = N(I, 8)
4910 GOTO 4885
4915 CALL "sc_pop": W(), X()
4920 SUBEND
4925 REM ---- sc_push / sc_pop: open and close a scope (marker -1 on the scope stack in W) -----------
4930 SUB "sc_push": N(), W(), X(), X$(), I
4935 IF X(12) - 2 > X(11) THEN 4950
4940 CALL "fatal": N(), X(), X$(), I, "symbols"
4945 GOTO 4960
4950 LET X(12) = X(12) - 2
4955 LET W(X(12)) = -1
4960 SUBEND
4965 SUB "sc_pop": W(), X()
4970 IF X(12) >= 200000 THEN 4995
4975 IF W(X(12)) = -1 THEN 4990
4980 LET X(12) = X(12) + 2
4985 GOTO 4970
4990 LET X(12) = X(12) + 2
4995 SUBEND
5000 REM ---- fin: an untyped constant that no context typed is i64 (LANGUAGE 4.2) ------------------
5005 SUB "fin": N(), M(), C(), X(), X$(), I
5010 IF M(I, 1) <> -1 THEN 5020
5015 CALL "stl": N(), M(), C(), X(), X$(), I, 3
5020 SUBEND
5025 REM ---- ck_cond: condition I must be a scalar bool (LANGUAGE 4.3) -----------------------------
5030 SUB "ck_cond": N(), M(), T(), C(), X(), X$(), I
5035 CALL "vu": N(), M(), T(), X(), X$(), I, D
5040 IF D <> -1 THEN 5055
5045 CALL "stl": N(), M(), C(), X(), X$(), I, 3
5050 LET D = 3
5055 IF D = 2 THEN 5070
5060 IF D = 0 THEN 5070
5065 CALL "er": N(), X(), X$(), I, "COND_BOOL", "", "", "", 0
5070 SUBEND
5075 REM ---- ck_tgt: R = the local assigned by target G (a var or a ref parameter, LANGUAGE 7.3), or
5080 REM 0 after an error: immutable locals, constants, functions and other expressions ----------
5085 SUB "ck_tgt": N(), M(), Y(), S$(), X(), X$(), G, R
5090 LET R = 0
5095 IF N(G, 0) = 30 THEN 5115
5100 IF M(G, 1) = 0 THEN 5170
5105 CALL "er": N(), X(), X$(), G, "BAD_TARGET", "", "", "", 0
5110 GOTO 5170
5115 LET S = M(G, 2)
5120 IF S = 0 THEN 5170
5125 IF S < 0 THEN 5165
5130 IF Y(S, 0) <> 4 THEN 5165
5135 IF Y(S, 4) = 2 THEN 5155
5140 IF Y(S, 4) = 5 THEN 5155
5145 CALL "er": N(), X(), X$(), G, "ASSIGN_IMMUTABLE", S$(N(G, 6)), "", "", 1
5150 GOTO 5170
5155 LET R = S
5160 GOTO 5170
5165 CALL "er": N(), X(), X$(), G, "BAD_TARGET", "", "", "", 0
5170 SUBEND
5175 REM ---- ck_st: statement I (LANGUAGE 7.1-7.6) ---------------------------------------------
5180 SUB "ck_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5185 LET M(I, 9) = 0
5190 LET X(19) = I
5195 LET K = N(I, 0)
5200 IF K < 8 THEN 5540
5205 IF K > 24 THEN 5540
5210 ON K - 7 GOTO 5215, 5215, 5540, 5540, 5540, 5225, 5235, 5245, 5255, 5380, 5415, 5485, 5540, 5495, 5510, 5525, 5535
5215 CALL "ck_let": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5220 GOTO 5540
5225 CALL "ck_asg": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5230 GOTO 5540
5235 CALL "ck_tasg": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5240 GOTO 5540
5245 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(I, 7)
5250 GOTO 5540
5255 REM an else-if chain is walked here link by link (no recursion over its length); it ends
5260 REM every path when every block does and the chain ends with an else block
5265 LET L1 = I
5270 LET Z = 1
5275 LET X(19) = L1
5280 LET M(L1, 9) = 0
5285 LET E = N(L1, 7)
5290 LET B = N(E, 8)
5295 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
5300 CALL "ck_cond": N(), M(), T(), C(), X(), X$(), E
5305 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
5310 IF M(B, 9) = 1 THEN 5320
5315 LET Z = 0
5320 IF N(L1, 1) = 1 THEN 5335
5325 LET Z = 0
5330 GOTO 5370
5335 LET G = N(B, 8)
5340 IF N(G, 0) = 24 THEN 5355
5345 LET L1 = G
5350 GOTO 5275
5355 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
5360 IF M(G, 9) = 1 THEN 5370
5365 LET Z = 0
5370 LET M(I, 9) = Z
5375 GOTO 5540
5380 LET E = N(I, 7)
5385 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
5390 CALL "ck_cond": N(), M(), T(), C(), X(), X$(), E
5395 LET X(15) = X(15) + 1
5400 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(E, 8)
5405 LET X(15) = X(15) - 1
5410 GOTO 5540
5415 REM a range loop; any other iterable is an array (phase 1: not supported yet)
5420 LET E = N(I, 7)
5425 IF N(E, 0) = 41 THEN 5440
5430 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "arrays", "", "", 1
5435 GOTO 5540
5440 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
5445 CALL "sc_push": N(), W(), X(), X$(), I
5450 CALL "nloc": N(), Y(), W(), X(), X$(), S$(), N(I, 6), 3, 3, I, 1, R
5455 LET M(I, 2) = R
5460 LET X(15) = X(15) + 1
5465 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(E, 8)
5470 LET X(15) = X(15) - 1
5475 CALL "sc_pop": W(), X()
5480 GOTO 5540
5485 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "match", "", "", 1
5490 GOTO 5540
5495 IF X(15) > 0 THEN 5540
5500 CALL "er": N(), X(), X$(), I, "BREAK_OUTSIDE", "", "", "", 0
5505 GOTO 5540
5510 IF X(15) > 0 THEN 5540
5515 CALL "er": N(), X(), X$(), I, "CONTINUE_OUTSIDE", "", "", "", 0
5520 GOTO 5540
5525 CALL "ck_ret": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5530 GOTO 5540
5535 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5540 SUBEND
5545 REM ---- ck_let: let/var I: pattern, [type], value (LANGUAGE 7.2, 4.2, 8.4) --------------------
5550 SUB "ck_let": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5555 LET P = N(I, 7)
5560 LET E = N(P, 8)
5565 LET D = 0
5570 LET Z0 = 0
5575 LET A = N(I, 1)
5580 IF A = 0 THEN 5595
5585 LET G = E
5590 LET E = N(E, 8)
5595 LET U = N(I, 0) - 7
5600 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
5605 IF A = 0 THEN 5670
5610 CALL "tyof": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G, D
5615 IF N(P, 0) = 12 THEN 5670
5620 REM a multiple-result call for one name or _ is a result count error, before any conversion
5625 LET V = M(E, 1)
5630 IF V < 10 THEN 5650
5635 IF T(V, 0) <> 7 THEN 5650
5640 CALL "er": N(), X(), X$(), E, "RESULT_COUNT", STR$(T(V, 1)), "1", "", 2
5645 GOTO 5670
5650 IF D = 0 THEN 5665
5655 CALL "cv": N(), M(), T(), C(), X(), X$(), E, D
5660 GOTO 5670
5665 CALL "fin": N(), M(), C(), X(), X$(), E
5670 LET K = N(P, 0)
5675 IF K = 11 THEN 5810
5680 IF K = 12 THEN 5825
5685 REM one name: its type is the annotation, or the value's
5690 IF A = 1 THEN 5775
5695 LET D = M(E, 1)
5700 IF D < 10 THEN 5725
5705 IF T(D, 0) <> 7 THEN 5725
5710 CALL "er": N(), X(), X$(), E, "RESULT_COUNT", STR$(T(D, 1)), "1", "", 2
5715 LET D = 0
5720 GOTO 5775
5725 IF D <> -1 THEN 5770
5730 REM an untyped constant: i64, or for an unannotated var the candidate of the var rule
5735 LET D = 3
5740 IF U = 1 THEN 5760
5745 LET Z0 = 1
5750 IF M(P, 4) = 0 THEN 5760
5755 LET D = 4
5760 CALL "stl": N(), M(), C(), X(), X$(), E, D
5765 GOTO 5775
5770 CALL "vu": N(), M(), T(), X(), X$(), E, D
5775 CALL "nloc": N(), Y(), W(), X(), X$(), S$(), N(P, 6), D, U, P, 1, R
5780 LET M(P, 2) = R
5785 IF R = 0 THEN 6000
5790 IF Z0 = 0 THEN 6000
5795 REM the candidate of the var rule: an unannotated var whose initialiser was untyped
5800 LET Y(R, 6) = P
5805 GOTO 6000
5810 IF A = 1 THEN 6000
5815 CALL "fin": N(), M(), C(), X(), X$(), E
5820 GOTO 6000
5825 REM a tuple pattern: one name or _ per result of a multiple-result call
5830 LET H = N(P, 1)
5835 LET V = M(E, 1)
5840 LET V0 = 1
5845 IF V = 0 THEN 5895
5850 IF V = -1 THEN 5880
5855 IF V = 1 THEN 5890
5860 IF V < 10 THEN 5895
5865 IF T(V, 0) <> 7 THEN 5895
5870 LET V0 = T(V, 1)
5875 GOTO 5895
5880 CALL "fin": N(), M(), C(), X(), X$(), E
5885 GOTO 5895
5890 LET V0 = 0
5895 IF A = 0 THEN 5930
5900 IF D = 0 THEN 5930
5905 IF V = 0 THEN 5930
5910 CALL "tyn": T(), D, A$
5915 CALL "tyn": T(), V, B$
5920 CALL "er": N(), X(), X$(), E, "TYPE_MISMATCH", A$, B$, "", 2
5925 LET V = 0
5930 IF V = 0 THEN 5950
5935 IF V0 = H THEN 5950
5940 CALL "er": N(), X(), X$(), P, "RESULT_COUNT", STR$(V0), STR$(H), "", 2
5945 LET V = 0
5950 LET Q = N(P, 7)
5955 FOR J = 1 TO H
5960 IF N(Q, 0) <> 10 THEN 5990
5965 LET D = 0
5970 IF V < 10 THEN 5980
5975 LET D = T(V + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9))
5980 CALL "nloc": N(), Y(), W(), X(), X$(), S$(), N(Q, 6), D, U, Q, 1, R
5985 LET M(Q, 2) = R
5990 LET Q = N(Q, 8)
5995 NEXT J
6000 SUBEND
6005 REM ---- ck_asg: target op= value (LANGUAGE 7.3; x op= e is x = x op e) ------------------------
6010 SUB "ck_asg": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
6015 LET G = N(I, 7)
6020 LET E = N(G, 8)
6025 LET O = N(I, 1)
6030 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
6035 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
6040 CALL "ck_tgt": N(), M(), Y(), S$(), X(), X$(), G, R
6045 LET D = M(G, 1)
6050 IF R = 0 THEN 6300
6055 IF D = 0 THEN 6300
6060 IF O > 1 THEN 6135
6065 REM =: a multiple-result call to one target is a result count error (LANGUAGE 8.4)
6070 LET V = M(E, 1)
6075 IF V < 10 THEN 6095
6080 IF T(V, 0) <> 7 THEN 6095
6085 CALL "er": N(), X(), X$(), E, "RESULT_COUNT", STR$(T(V, 1)), "1", "", 2
6090 GOTO 6305
6095 REM a candidate var stores an f64 (Decision 8), else the value converts to the target
6100 IF Y(R, 6) = 0 THEN 6125
6105 IF D <> 3 THEN 6125
6110 IF M(E, 1) <> 4 THEN 6125
6115 CALL "cand": M(), Y(), X(), R
6120 GOTO 6305
6125 CALL "cv": N(), M(), T(), C(), X(), X$(), E, D
6130 GOTO 6305
6135 CALL "vu": N(), M(), T(), X(), X$(), E, V
6140 IF V = 0 THEN 6305
6145 IF D = 2 THEN 6270
6150 IF V = 2 THEN 6270
6155 IF V > 4 THEN 6270
6160 IF D > 4 THEN 6270
6165 IF V <> -1 THEN 6180
6170 CALL "stl": N(), M(), C(), X(), X$(), E, D
6175 LET V = M(E, 1)
6180 REM the result of x op e: f64 for / and beside an f64, else i64 (LANGUAGE 6.5)
6185 LET Z = 3
6190 IF O = 5 THEN 6210
6195 IF D = 4 THEN 6210
6200 IF V = 4 THEN 6210
6205 GOTO 6215
6210 LET Z = 4
6215 IF Z = 4 THEN 6225
6220 GOTO 6305
6225 IF D = 4 THEN 6255
6230 IF Y(R, 6) = 0 THEN 6245
6235 CALL "cand": M(), Y(), X(), R
6240 GOTO 6305
6245 CALL "er": N(), X(), X$(), E, "TYPE_MISMATCH", "i64", "f64", "", 2
6250 GOTO 6305
6255 IF V <> 3 THEN 6305
6260 LET M(E, 7) = 1
6265 GOTO 6305
6270 CALL "fin": N(), M(), C(), X(), X$(), E
6275 CALL "opn": O - 1, A$
6280 CALL "tyn": T(), D, B$
6285 CALL "tyn": T(), M(E, 1), C$
6290 CALL "er": N(), X(), X$(), I, "BAD_OPERANDS", A$ & "=", B$, C$, 3
6295 GOTO 6305
6300 CALL "fin": N(), M(), C(), X(), X$(), E
6305 SUBEND
6310 REM ---- ck_tasg: (t1, ..., tn) = call (LANGUAGE 7.3, 8.4, 4.2 (b)): each result to its target ---
6315 SUB "ck_tasg": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
6320 LET H = N(I, 1)
6325 LET G = N(I, 7)
6330 FOR J = 1 TO H
6335 IF N(G, 0) = 11 THEN 6345
6340 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
6345 LET G = N(G, 8)
6350 NEXT J
6355 LET E = G
6360 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
6365 LET V = M(E, 1)
6370 LET V0 = 1
6375 IF V = 0 THEN 6440
6380 IF V = 1 THEN 6420
6385 IF V = -1 THEN 6410
6390 IF V < 10 THEN 6425
6395 IF T(V, 0) <> 7 THEN 6425
6400 LET V0 = T(V, 1)
6405 GOTO 6425
6410 CALL "fin": N(), M(), C(), X(), X$(), E
6415 GOTO 6425
6420 LET V0 = 0
6425 IF V0 = H THEN 6440
6430 CALL "er": N(), X(), X$(), I, "RESULT_COUNT", STR$(V0), STR$(H), "", 2
6435 LET V = 0
6440 LET G = N(I, 7)
6445 FOR J = 1 TO H
6450 REM M(target,4) = 1: the i64 result is converted to the f64 target (the cv flag of tasg)
6455 LET M(G, 4) = 0
6460 IF N(G, 0) = 11 THEN 6560
6465 CALL "ck_tgt": N(), M(), Y(), S$(), X(), X$(), G, R
6470 IF R = 0 THEN 6560
6475 IF V < 10 THEN 6560
6480 LET D = T(V + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9))
6485 LET D0 = M(G, 1)
6490 IF D = D0 THEN 6560
6495 IF D0 = 0 THEN 6560
6500 IF D <> 3 THEN 6520
6505 IF D0 <> 4 THEN 6520
6510 LET M(G, 4) = 1
6515 GOTO 6560
6520 IF Y(R, 6) = 0 THEN 6545
6525 IF D <> 4 THEN 6545
6530 IF D0 <> 3 THEN 6545
6535 CALL "cand": M(), Y(), X(), R
6540 GOTO 6560
6545 CALL "tyn": T(), D0, A$
6550 CALL "tyn": T(), D, B$
6555 CALL "er": N(), X(), X$(), G, "TYPE_MISMATCH", A$, B$, "", 2
6560 LET G = N(G, 8)
6565 NEXT J
6570 SUBEND
6575 REM ---- ck_ret: return I of the current function X(14) (LANGUAGE 8.1, 8.4); M(I,4) = 1: tret --
6580 SUB "ck_ret": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
6585 LET M(I, 4) = 0
6590 LET M(I, 9) = 1
6595 LET F = X(14)
6600 LET R0 = Y(F, 7)
6605 LET D = Y(F, 2)
6610 LET H = N(I, 1)
6615 LET E = N(I, 7)
6620 FOR J = 1 TO H
6625 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
6630 LET E = N(E, 8)
6635 NEXT J
6640 LET E = N(I, 7)
6645 IF H = 0 THEN 6740
6650 IF H = 1 THEN 6750
6655 IF R0 = H THEN 6690
6660 LET J = 1
6665 IF J > H THEN 6850
6670 CALL "fin": N(), M(), C(), X(), X$(), E
6675 LET E = N(E, 8)
6680 LET J = J + 1
6685 GOTO 6665
6690 REM return (e1, ..., ek): each value to its result type
6695 FOR J = 1 TO H
6700 LET D0 = T(D + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9))
6705 IF D = 0 THEN 6720
6710 CALL "cv": N(), M(), T(), C(), X(), X$(), E, D0
6715 GOTO 6725
6720 CALL "fin": N(), M(), C(), X(), X$(), E
6725 LET E = N(E, 8)
6730 NEXT J
6735 GOTO 6855
6740 IF R0 = 0 THEN 6855
6745 GOTO 6850
6750 LET V = M(E, 1)
6755 IF V < 10 THEN 6825
6760 IF T(V, 0) <> 7 THEN 6825
6765 REM return f(...) of a multiple-result call: tret when the results are exactly the function's
6770 IF R0 = 0 THEN 6815
6775 IF V = D THEN 6805
6780 IF D = 0 THEN 6855
6785 CALL "tyn": T(), D, A$
6790 CALL "tyn": T(), V, B$
6795 CALL "er": N(), X(), X$(), E, "TYPE_MISMATCH", A$, B$, "", 2
6800 GOTO 6855
6805 LET M(I, 4) = 1
6810 GOTO 6855
6815 CALL "er": N(), X(), X$(), I, "RESULT_COUNT", "0", STR$(T(V, 1)), "", 2
6820 GOTO 6855
6825 IF R0 <> 1 THEN 6840
6830 CALL "cv": N(), M(), T(), C(), X(), X$(), E, D
6835 GOTO 6855
6840 CALL "fin": N(), M(), C(), X(), X$(), E
6845 IF V = 0 THEN 6855
6850 CALL "er": N(), X(), X$(), I, "RESULT_COUNT", STR$(R0), STR$(H), "", 2
6855 SUBEND
