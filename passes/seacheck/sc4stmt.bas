4300 REM ---- ck_blk: block B, a scope (LANGUAGE 7.2, 7.7); M(B,9) = 1 when a statement ends every path
4305 SUB "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
4310 LET M(B, 9) = 0
4315 CALL "sc_push": N(), W(), X(), X$(), B
4320 LET I = N(B, 7)
4325 IF I = 0 THEN 4355
4330 CALL "ck_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
4335 IF M(I, 9) = 0 THEN 4345
4340 LET M(B, 9) = 1
4345 LET I = N(I, 8)
4350 GOTO 4325
4355 CALL "sc_pop": W(), X()
4360 SUBEND
4365 REM ---- sc_push / sc_pop: open and close a scope (marker -1 on the scope stack in W) -----------
4370 SUB "sc_push": N(), W(), X(), X$(), I
4375 IF X(12) - 2 > X(11) THEN 4390
4380 CALL "fatal": N(), X(), X$(), I, "symbols"
4385 GOTO 4400
4390 LET X(12) = X(12) - 2
4395 LET W(X(12)) = -1
4400 SUBEND
4405 SUB "sc_pop": W(), X()
4410 IF X(12) >= 200000 THEN 4435
4415 IF W(X(12)) = -1 THEN 4430
4420 LET X(12) = X(12) + 2
4425 GOTO 4410
4430 LET X(12) = X(12) + 2
4435 SUBEND
4440 REM ---- fin: an untyped constant that no context typed is i64 (LANGUAGE 4.2) ------------------
4445 SUB "fin": N(), M(), C(), X(), X$(), I
4450 IF M(I, 1) <> -1 THEN 4460
4455 CALL "stl": N(), M(), C(), X(), X$(), I, 3
4460 SUBEND
4465 REM ---- ck_cond: condition I must be a scalar bool (LANGUAGE 4.3) -----------------------------
4470 SUB "ck_cond": N(), M(), T(), C(), X(), X$(), I
4475 CALL "vu": N(), M(), T(), X(), X$(), I, D
4480 IF D <> -1 THEN 4495
4485 CALL "stl": N(), M(), C(), X(), X$(), I, 3
4490 LET D = 3
4495 IF D = 2 THEN 4510
4500 IF D = 0 THEN 4510
4505 CALL "er": N(), X(), X$(), I, "COND_BOOL", "", "", "", 0
4510 SUBEND
4515 REM ---- ck_tgt: R = the local assigned by target G (a var or a ref parameter, LANGUAGE 7.3), or
4520 REM 0 after an error: immutable locals, constants, functions and other expressions ----------
4525 SUB "ck_tgt": N(), M(), Y(), S$(), X(), X$(), G, R
4530 LET R = 0
4535 IF N(G, 0) = 30 THEN 4555
4540 IF M(G, 1) = 0 THEN 4610
4545 CALL "er": N(), X(), X$(), G, "BAD_TARGET", "", "", "", 0
4550 GOTO 4610
4555 LET S = M(G, 2)
4560 IF S = 0 THEN 4610
4565 IF S < 0 THEN 4605
4570 IF Y(S, 0) <> 4 THEN 4605
4575 IF Y(S, 4) = 2 THEN 4595
4580 IF Y(S, 4) = 5 THEN 4595
4585 CALL "er": N(), X(), X$(), G, "ASSIGN_IMMUTABLE", S$(N(G, 6)), "", "", 1
4590 GOTO 4610
4595 LET R = S
4600 GOTO 4610
4605 CALL "er": N(), X(), X$(), G, "BAD_TARGET", "", "", "", 0
4610 SUBEND
4615 REM ---- ck_st: statement I (LANGUAGE 7.1-7.6) ---------------------------------------------
4620 SUB "ck_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
4625 LET M(I, 9) = 0
4630 LET X(19) = I
4635 LET K = N(I, 0)
4640 IF K < 8 THEN 4930
4645 IF K > 24 THEN 4930
4650 ON K - 7 GOTO 4655, 4655, 4930, 4930, 4930, 4665, 4675, 4685, 4695, 4770, 4805, 4875, 4930, 4885, 4900, 4915, 4925
4655 CALL "ck_let": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
4660 GOTO 4930
4665 CALL "ck_asg": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
4670 GOTO 4930
4675 CALL "ck_tasg": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
4680 GOTO 4930
4685 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(I, 7)
4690 GOTO 4930
4695 LET E = N(I, 7)
4700 LET B = N(E, 8)
4705 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
4710 CALL "ck_cond": N(), M(), T(), C(), X(), X$(), E
4715 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), B
4720 IF N(I, 1) = 0 THEN 4930
4725 LET G = N(B, 8)
4730 IF N(G, 0) = 24 THEN 4745
4735 CALL "ck_st": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
4740 GOTO 4750
4745 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
4750 IF M(B, 9) = 0 THEN 4930
4755 IF M(G, 9) = 0 THEN 4930
4760 LET M(I, 9) = 1
4765 GOTO 4930
4770 LET E = N(I, 7)
4775 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
4780 CALL "ck_cond": N(), M(), T(), C(), X(), X$(), E
4785 LET X(15) = X(15) + 1
4790 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(E, 8)
4795 LET X(15) = X(15) - 1
4800 GOTO 4930
4805 REM a range loop; any other iterable is an array (phase 1: not supported yet)
4810 LET E = N(I, 7)
4815 IF N(E, 0) = 41 THEN 4830
4820 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "arrays", "", "", 1
4825 GOTO 4930
4830 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
4835 CALL "sc_push": N(), W(), X(), X$(), I
4840 CALL "nloc": N(), Y(), W(), X(), X$(), S$(), N(I, 6), 3, 3, I, 1, R
4845 LET M(I, 2) = R
4850 LET X(15) = X(15) + 1
4855 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), N(E, 8)
4860 LET X(15) = X(15) - 1
4865 CALL "sc_pop": W(), X()
4870 GOTO 4930
4875 CALL "er": N(), X(), X$(), I, "NOT_SUPPORTED", "match", "", "", 1
4880 GOTO 4930
4885 IF X(15) > 0 THEN 4930
4890 CALL "er": N(), X(), X$(), I, "BREAK_OUTSIDE", "", "", "", 0
4895 GOTO 4930
4900 IF X(15) > 0 THEN 4930
4905 CALL "er": N(), X(), X$(), I, "CONTINUE_OUTSIDE", "", "", "", 0
4910 GOTO 4930
4915 CALL "ck_ret": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
4920 GOTO 4930
4925 CALL "ck_blk": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
4930 SUBEND
4935 REM ---- ck_let: let/var I: pattern, [type], value (LANGUAGE 7.2, 4.2, 8.4) --------------------
4940 SUB "ck_let": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
4945 LET P = N(I, 7)
4950 LET E = N(P, 8)
4955 LET D = 0
4960 LET Z0 = 0
4965 LET A = N(I, 1)
4970 IF A = 0 THEN 4985
4975 LET G = E
4980 LET E = N(E, 8)
4985 LET U = N(I, 0) - 7
4990 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
4995 IF A = 0 THEN 5030
5000 CALL "tyof": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G, D
5005 IF N(P, 0) = 12 THEN 5030
5010 IF D = 0 THEN 5025
5015 CALL "cv": N(), M(), T(), C(), X(), X$(), E, D
5020 GOTO 5030
5025 CALL "fin": N(), M(), C(), X(), X$(), E
5030 LET K = N(P, 0)
5035 IF K = 11 THEN 5170
5040 IF K = 12 THEN 5185
5045 REM one name: its type is the annotation, or the value's
5050 IF A = 1 THEN 5135
5055 LET D = M(E, 1)
5060 IF D < 10 THEN 5085
5065 IF T(D, 0) <> 7 THEN 5085
5070 CALL "er": N(), X(), X$(), E, "RESULT_COUNT", STR$(T(D, 1)), "1", "", 2
5075 LET D = 0
5080 GOTO 5135
5085 IF D <> -1 THEN 5130
5090 REM an untyped constant: i64, or for an unannotated var the candidate of the var rule
5095 LET D = 3
5100 IF U = 1 THEN 5120
5105 LET Z0 = 1
5110 IF M(P, 4) = 0 THEN 5120
5115 LET D = 4
5120 CALL "stl": N(), M(), C(), X(), X$(), E, D
5125 GOTO 5135
5130 CALL "vu": N(), M(), T(), X(), X$(), E, D
5135 CALL "nloc": N(), Y(), W(), X(), X$(), S$(), N(P, 6), D, U, P, 1, R
5140 LET M(P, 2) = R
5145 IF R = 0 THEN 5360
5150 IF Z0 = 0 THEN 5360
5155 REM the candidate of the var rule: an unannotated var whose initialiser was untyped
5160 LET Y(R, 6) = P
5165 GOTO 5360
5170 IF A = 1 THEN 5360
5175 CALL "fin": N(), M(), C(), X(), X$(), E
5180 GOTO 5360
5185 REM a tuple pattern: one name or _ per result of a multiple-result call
5190 LET H = N(P, 1)
5195 LET V = M(E, 1)
5200 LET V0 = 1
5205 IF V = 0 THEN 5255
5210 IF V = -1 THEN 5240
5215 IF V = 1 THEN 5250
5220 IF V < 10 THEN 5255
5225 IF T(V, 0) <> 7 THEN 5255
5230 LET V0 = T(V, 1)
5235 GOTO 5255
5240 CALL "fin": N(), M(), C(), X(), X$(), E
5245 GOTO 5255
5250 LET V0 = 0
5255 IF A = 0 THEN 5290
5260 IF D = 0 THEN 5290
5265 IF V = 0 THEN 5290
5270 CALL "tyn": T(), D, A$
5275 CALL "tyn": T(), V, B$
5280 CALL "er": N(), X(), X$(), E, "TYPE_MISMATCH", A$, B$, "", 2
5285 LET V = 0
5290 IF V = 0 THEN 5310
5295 IF V0 = H THEN 5310
5300 CALL "er": N(), X(), X$(), P, "RESULT_COUNT", STR$(V0), STR$(H), "", 2
5305 LET V = 0
5310 LET Q = N(P, 7)
5315 FOR J = 1 TO H
5320 IF N(Q, 0) <> 10 THEN 5350
5325 LET D = 0
5330 IF V < 10 THEN 5340
5335 LET D = T(V + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9))
5340 CALL "nloc": N(), Y(), W(), X(), X$(), S$(), N(Q, 6), D, U, Q, 1, R
5345 LET M(Q, 2) = R
5350 LET Q = N(Q, 8)
5355 NEXT J
5360 SUBEND
5365 REM ---- ck_asg: target op= value (LANGUAGE 7.3; x op= e is x = x op e) ------------------------
5370 SUB "ck_asg": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5375 LET G = N(I, 7)
5380 LET E = N(G, 8)
5385 LET O = N(I, 1)
5390 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
5395 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
5400 CALL "ck_tgt": N(), M(), Y(), S$(), X(), X$(), G, R
5405 LET D = M(G, 1)
5410 IF R = 0 THEN 5660
5415 IF D = 0 THEN 5660
5420 IF O > 1 THEN 5495
5425 REM =: a multiple-result call to one target is a result count error (LANGUAGE 8.4)
5430 LET V = M(E, 1)
5435 IF V < 10 THEN 5455
5440 IF T(V, 0) <> 7 THEN 5455
5445 CALL "er": N(), X(), X$(), E, "RESULT_COUNT", STR$(T(V, 1)), "1", "", 2
5450 GOTO 5665
5455 REM a candidate var stores an f64 (Decision 8), else the value converts to the target
5460 IF Y(R, 6) = 0 THEN 5485
5465 IF D <> 3 THEN 5485
5470 IF M(E, 1) <> 4 THEN 5485
5475 CALL "cand": M(), Y(), X(), R
5480 GOTO 5665
5485 CALL "cv": N(), M(), T(), C(), X(), X$(), E, D
5490 GOTO 5665
5495 CALL "vu": N(), M(), T(), X(), X$(), E, V
5500 IF V = 0 THEN 5665
5505 IF D = 2 THEN 5630
5510 IF V = 2 THEN 5630
5515 IF V > 4 THEN 5630
5520 IF D > 4 THEN 5630
5525 IF V <> -1 THEN 5540
5530 CALL "stl": N(), M(), C(), X(), X$(), E, D
5535 LET V = M(E, 1)
5540 REM the result of x op e: f64 for / and beside an f64, else i64 (LANGUAGE 6.5)
5545 LET Z = 3
5550 IF O = 5 THEN 5570
5555 IF D = 4 THEN 5570
5560 IF V = 4 THEN 5570
5565 GOTO 5575
5570 LET Z = 4
5575 IF Z = 4 THEN 5585
5580 GOTO 5665
5585 IF D = 4 THEN 5615
5590 IF Y(R, 6) = 0 THEN 5605
5595 CALL "cand": M(), Y(), X(), R
5600 GOTO 5665
5605 CALL "er": N(), X(), X$(), E, "TYPE_MISMATCH", "i64", "f64", "", 2
5610 GOTO 5665
5615 IF V <> 3 THEN 5665
5620 LET M(E, 7) = 1
5625 GOTO 5665
5630 CALL "fin": N(), M(), C(), X(), X$(), E
5635 CALL "opn": O - 1, A$
5640 CALL "tyn": T(), D, B$
5645 CALL "tyn": T(), M(E, 1), C$
5650 CALL "er": N(), X(), X$(), I, "BAD_OPERANDS", A$ & "=", B$, C$, 3
5655 GOTO 5665
5660 CALL "fin": N(), M(), C(), X(), X$(), E
5665 SUBEND
5670 REM ---- ck_tasg: (t1, ..., tn) = call (LANGUAGE 7.3, 8.4): each result to its target exactly ---
5675 SUB "ck_tasg": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5680 LET H = N(I, 1)
5685 LET G = N(I, 7)
5690 FOR J = 1 TO H
5695 IF N(G, 0) = 11 THEN 5705
5700 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), G
5705 LET G = N(G, 8)
5710 NEXT J
5715 LET E = G
5720 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
5725 LET V = M(E, 1)
5730 LET V0 = 1
5735 IF V = 0 THEN 5800
5740 IF V = 1 THEN 5780
5745 IF V = -1 THEN 5770
5750 IF V < 10 THEN 5785
5755 IF T(V, 0) <> 7 THEN 5785
5760 LET V0 = T(V, 1)
5765 GOTO 5785
5770 CALL "fin": N(), M(), C(), X(), X$(), E
5775 GOTO 5785
5780 LET V0 = 0
5785 IF V0 = H THEN 5800
5790 CALL "er": N(), X(), X$(), I, "RESULT_COUNT", STR$(V0), STR$(H), "", 2
5795 LET V = 0
5800 LET G = N(I, 7)
5805 FOR J = 1 TO H
5810 IF N(G, 0) = 11 THEN 5890
5815 CALL "ck_tgt": N(), M(), Y(), S$(), X(), X$(), G, R
5820 IF R = 0 THEN 5890
5825 IF V < 10 THEN 5890
5830 LET D = T(V + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9))
5835 LET D0 = M(G, 1)
5840 IF D = D0 THEN 5890
5845 IF D0 = 0 THEN 5890
5850 IF Y(R, 6) = 0 THEN 5875
5855 IF D <> 4 THEN 5875
5860 IF D0 <> 3 THEN 5875
5865 CALL "cand": M(), Y(), X(), R
5870 GOTO 5890
5875 CALL "tyn": T(), D0, A$
5880 CALL "tyn": T(), D, B$
5885 CALL "er": N(), X(), X$(), G, "TYPE_MISMATCH", A$, B$, "", 2
5890 LET G = N(G, 8)
5895 NEXT J
5900 SUBEND
5905 REM ---- ck_ret: return I of the current function X(14) (LANGUAGE 8.1, 8.4); M(I,4) = 1: tret --
5910 SUB "ck_ret": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), I
5915 LET M(I, 4) = 0
5920 LET M(I, 9) = 1
5925 LET F = X(14)
5930 LET R0 = Y(F, 7)
5935 LET D = Y(F, 2)
5940 LET H = N(I, 1)
5945 LET E = N(I, 7)
5950 FOR J = 1 TO H
5955 CALL "ck_expr": N(), M(), Y(), T(), W(), C(), S$(), X(), X$(), E
5960 LET E = N(E, 8)
5965 NEXT J
5970 LET E = N(I, 7)
5975 IF H = 0 THEN 6070
5980 IF H = 1 THEN 6080
5985 IF R0 = H THEN 6020
5990 LET J = 1
5995 IF J > H THEN 6180
6000 CALL "fin": N(), M(), C(), X(), X$(), E
6005 LET E = N(E, 8)
6010 LET J = J + 1
6015 GOTO 5995
6020 REM return (e1, ..., ek): each value to its result type
6025 FOR J = 1 TO H
6030 LET D0 = T(D + 1 + INT((J - 1) / 9), J - 1 - 9 * INT((J - 1) / 9))
6035 IF D = 0 THEN 6050
6040 CALL "cv": N(), M(), T(), C(), X(), X$(), E, D0
6045 GOTO 6055
6050 CALL "fin": N(), M(), C(), X(), X$(), E
6055 LET E = N(E, 8)
6060 NEXT J
6065 GOTO 6185
6070 IF R0 = 0 THEN 6185
6075 GOTO 6180
6080 LET V = M(E, 1)
6085 IF V < 10 THEN 6155
6090 IF T(V, 0) <> 7 THEN 6155
6095 REM return f(...) of a multiple-result call: tret when the results are exactly the function's
6100 IF R0 = 0 THEN 6145
6105 IF V = D THEN 6135
6110 IF D = 0 THEN 6185
6115 CALL "tyn": T(), D, A$
6120 CALL "tyn": T(), V, B$
6125 CALL "er": N(), X(), X$(), E, "TYPE_MISMATCH", A$, B$, "", 2
6130 GOTO 6185
6135 LET M(I, 4) = 1
6140 GOTO 6185
6145 CALL "er": N(), X(), X$(), I, "RESULT_COUNT", "0", STR$(T(V, 1)), "", 2
6150 GOTO 6185
6155 IF R0 <> 1 THEN 6170
6160 CALL "cv": N(), M(), T(), C(), X(), X$(), E, D
6165 GOTO 6185
6170 CALL "fin": N(), M(), C(), X(), X$(), E
6175 IF V = 0 THEN 6185
6180 CALL "er": N(), X(), X$(), I, "RESULT_COUNT", STR$(R0), STR$(H), "", 2
6185 SUBEND
